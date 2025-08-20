#!/bin/bash
# Script to verify complete replication of tables from primary to replica

echo "===== PostgreSQL Replication Verification Report ====="
echo "Date: $(date)"
echo

# Get list of all tables in primary database
echo "Getting list of tables from primary database..."
TABLES=$(docker exec primary_container psql -U postgres -t -c "SELECT tablename FROM pg_tables WHERE schemaname='public' ORDER BY tablename;")

if [ -z "$TABLES" ]; then
  echo "Error: No tables found in primary database!"
  exit 1
fi

echo "Found $(echo "$TABLES" | wc -l | xargs) tables in primary database."
echo

# Initialize counters
TOTAL_TABLES=0
MATCHED_STRUCTURE=0
MATCHED_DATA=0
MISMATCHED_STRUCTURE=0
MISMATCHED_DATA=0

echo "===== Detailed Table Verification ====="
echo

# Create a report file
REPORT_FILE="replication_verification_report.txt"
echo "===== PostgreSQL Replication Verification Report =====" > $REPORT_FILE
echo "Date: $(date)" >> $REPORT_FILE
echo >> $REPORT_FILE

# Process each table
for TABLE in $TABLES; do
  TABLE=$(echo $TABLE | xargs)  # Trim whitespace
  if [ -z "$TABLE" ]; then
    continue
  fi
  
  TOTAL_TABLES=$((TOTAL_TABLES+1))
  echo "[$TOTAL_TABLES/$(echo "$TABLES" | wc -l | xargs)] Verifying table: $TABLE"
  echo "[$TOTAL_TABLES/$(echo "$TABLES" | wc -l | xargs)] Verifying table: $TABLE" >> $REPORT_FILE
  
  # Compare table structure
  PRIMARY_COLUMNS=$(docker exec primary_container psql -U postgres -t -c "SELECT column_name, data_type, character_maximum_length FROM information_schema.columns WHERE table_name = '$TABLE' AND table_schema = 'public' ORDER BY ordinal_position;")
  REPLICA_COLUMNS=$(docker exec replica_container psql -U postgres -t -c "SELECT column_name, data_type, character_maximum_length FROM information_schema.columns WHERE table_name = '$TABLE' AND table_schema = 'public' ORDER BY ordinal_position;")
  
  if [ "$PRIMARY_COLUMNS" = "$REPLICA_COLUMNS" ]; then
    echo "  ✓ Table structure matches"
    echo "  ✓ Table structure matches" >> $REPORT_FILE
    MATCHED_STRUCTURE=$((MATCHED_STRUCTURE+1))
  else
    echo "  ✗ Table structure mismatch!"
    echo "  ✗ Table structure mismatch!" >> $REPORT_FILE
    echo "    Primary columns:" >> $REPORT_FILE
    echo "$PRIMARY_COLUMNS" >> $REPORT_FILE
    echo "    Replica columns:" >> $REPORT_FILE
    echo "$REPLICA_COLUMNS" >> $REPORT_FILE
    MISMATCHED_STRUCTURE=$((MISMATCHED_STRUCTURE+1))
  fi
  
  # Compare row counts
  PRIMARY_COUNT=$(docker exec primary_container psql -U postgres -t -c "SELECT COUNT(*) FROM $TABLE;")
  REPLICA_COUNT=$(docker exec replica_container psql -U postgres -t -c "SELECT COUNT(*) FROM $TABLE;")
  
  PRIMARY_COUNT=$(echo $PRIMARY_COUNT | xargs)
  REPLICA_COUNT=$(echo $REPLICA_COUNT | xargs)
  
  echo "  • Primary count: $PRIMARY_COUNT rows"
  echo "  • Replica count: $REPLICA_COUNT rows"
  echo "  • Primary count: $PRIMARY_COUNT rows" >> $REPORT_FILE
  echo "  • Replica count: $REPLICA_COUNT rows" >> $REPORT_FILE
  
  if [ "$PRIMARY_COUNT" = "$REPLICA_COUNT" ]; then
    echo "  ✓ Row count matches"
    echo "  ✓ Row count matches" >> $REPORT_FILE
    MATCHED_DATA=$((MATCHED_DATA+1))
  else
    echo "  ✗ Row count mismatch!"
    echo "  ✗ Row count mismatch!" >> $REPORT_FILE
    MISMATCHED_DATA=$((MISMATCHED_DATA+1))
  fi
  
  # If table has data and counts match, verify a sample of data by checking primary keys
  if [ "$PRIMARY_COUNT" != "0" ] && [ "$PRIMARY_COUNT" = "$REPLICA_COUNT" ]; then
    # Get primary key columns
    PK_COLUMNS=$(docker exec primary_container psql -U postgres -t -c "
      SELECT a.attname
      FROM pg_index i
      JOIN pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = ANY(i.indkey)
      WHERE i.indrelid = '$TABLE'::regclass AND i.indisprimary;
    ")
    
    if [ -n "$PK_COLUMNS" ]; then
      # Sample a few rows using primary key
      SAMPLE_SIZE=5
      if [ "$PRIMARY_COUNT" -lt "$SAMPLE_SIZE" ]; then
        SAMPLE_SIZE=$PRIMARY_COUNT
      fi
      
      # Format primary key columns for query
      PK_FORMATTED=$(echo "$PK_COLUMNS" | xargs | tr ' ' ',')
      
      # Get sample primary keys
      SAMPLE_PKS=$(docker exec primary_container psql -U postgres -t -c "
        SELECT $PK_FORMATTED FROM $TABLE ORDER BY $PK_FORMATTED LIMIT $SAMPLE_SIZE;
      ")
      
      MATCH_COUNT=0
      MISMATCH_COUNT=0
      
      echo "  • Verifying sample data using primary keys..." 
      echo "  • Verifying sample data using primary keys..." >> $REPORT_FILE
      
      # For each primary key, compare data between primary and replica
      while read -r PK_VALUE; do
        if [ -z "$PK_VALUE" ]; then
          continue
        fi
        
        # Format PK value for WHERE clause
        WHERE_CLAUSE=""
        IFS='|' read -ra PK_PARTS <<< "$PK_VALUE"
        PK_ARRAY=($PK_COLUMNS)
        
        for i in "${!PK_ARRAY[@]}"; do
          COL_NAME=$(echo "${PK_ARRAY[$i]}" | xargs)
          COL_VALUE=$(echo "${PK_PARTS[$i]}" | xargs)
          
          if [ -n "$WHERE_CLAUSE" ]; then
            WHERE_CLAUSE="$WHERE_CLAUSE AND "
          fi
          
          WHERE_CLAUSE="$WHERE_CLAUSE$COL_NAME = '$COL_VALUE'"
        done
        
        # Compare row data
        PRIMARY_ROW=$(docker exec primary_container psql -U postgres -t -c "
          SELECT * FROM $TABLE WHERE $WHERE_CLAUSE;
        ")
        
        REPLICA_ROW=$(docker exec replica_container psql -U postgres -t -c "
          SELECT * FROM $TABLE WHERE $WHERE_CLAUSE;
        ")
        
        if [ "$PRIMARY_ROW" = "$REPLICA_ROW" ]; then
          MATCH_COUNT=$((MATCH_COUNT+1))
        else
          MISMATCH_COUNT=$((MISMATCH_COUNT+1))
        fi
      done <<< "$SAMPLE_PKS"
      
      if [ "$MISMATCH_COUNT" -eq 0 ]; then
        echo "  ✓ Sample data matches ($MATCH_COUNT/$SAMPLE_SIZE rows verified)"
        echo "  ✓ Sample data matches ($MATCH_COUNT/$SAMPLE_SIZE rows verified)" >> $REPORT_FILE
      else
        echo "  ✗ Sample data mismatch! ($MISMATCH_COUNT/$SAMPLE_SIZE rows differ)"
        echo "  ✗ Sample data mismatch! ($MISMATCH_COUNT/$SAMPLE_SIZE rows differ)" >> $REPORT_FILE
        MATCHED_DATA=$((MATCHED_DATA-1))
        MISMATCHED_DATA=$((MISMATCHED_DATA+1))
      fi
    else
      echo "  • No primary key found, skipping detailed data verification"
      echo "  • No primary key found, skipping detailed data verification" >> $REPORT_FILE
    fi
  fi
  
  echo
  echo >> $REPORT_FILE
done

echo "===== Summary ====="
echo "Total tables: $TOTAL_TABLES"
echo "Tables with matching structure: $MATCHED_STRUCTURE"
echo "Tables with matching data: $MATCHED_DATA"
echo "Tables with structure mismatches: $MISMATCHED_STRUCTURE"
echo "Tables with data mismatches: $MISMATCHED_DATA"
echo

echo "===== Summary =====" >> $REPORT_FILE
echo "Total tables: $TOTAL_TABLES" >> $REPORT_FILE
echo "Tables with matching structure: $MATCHED_STRUCTURE" >> $REPORT_FILE
echo "Tables with matching data: $MATCHED_DATA" >> $REPORT_FILE
echo "Tables with structure mismatches: $MISMATCHED_STRUCTURE" >> $REPORT_FILE
echo "Tables with data mismatches: $MISMATCHED_DATA" >> $REPORT_FILE
echo >> $REPORT_FILE

if [ $MISMATCHED_STRUCTURE -eq 0 ] && [ $MISMATCHED_DATA -eq 0 ]; then
  echo "✅ VERIFICATION SUCCESSFUL: All tables and data have been replicated correctly!"
  echo "✅ VERIFICATION SUCCESSFUL: All tables and data have been replicated correctly!" >> $REPORT_FILE
else
  echo "❌ VERIFICATION FAILED: Some tables or data have not been replicated correctly!"
  echo "❌ VERIFICATION FAILED: Some tables or data have not been replicated correctly!" >> $REPORT_FILE
fi

echo
echo "Detailed report saved to: $REPORT_FILE"
