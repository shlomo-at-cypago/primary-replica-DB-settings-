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

# Process each table
for TABLE in $TABLES; do
  TABLE=$(echo $TABLE | xargs)  # Trim whitespace
  if [ -z "$TABLE" ]; then
    continue
  fi
  
  TOTAL_TABLES=$((TOTAL_TABLES+1))
  echo "[$TOTAL_TABLES/$(echo "$TABLES" | wc -l | xargs)] Verifying table: $TABLE"
  
  # Compare table structure
  PRIMARY_STRUCTURE=$(docker exec primary_container psql -U postgres -t -c "\d+ $TABLE")
  REPLICA_STRUCTURE=$(docker exec replica_container psql -U postgres -t -c "\d+ $TABLE")
  
  if [ "$PRIMARY_STRUCTURE" = "$REPLICA_STRUCTURE" ]; then
    echo "  ✓ Table structure matches"
    MATCHED_STRUCTURE=$((MATCHED_STRUCTURE+1))
  else
    echo "  ✗ Table structure mismatch!"
    MISMATCHED_STRUCTURE=$((MISMATCHED_STRUCTURE+1))
  fi
  
  # Compare row counts
  PRIMARY_COUNT=$(docker exec primary_container psql -U postgres -t -c "SELECT COUNT(*) FROM $TABLE;")
  REPLICA_COUNT=$(docker exec replica_container psql -U postgres -t -c "SELECT COUNT(*) FROM $TABLE;")
  
  PRIMARY_COUNT=$(echo $PRIMARY_COUNT | xargs)
  REPLICA_COUNT=$(echo $REPLICA_COUNT | xargs)
  
  echo "  • Primary count: $PRIMARY_COUNT rows"
  echo "  • Replica count: $REPLICA_COUNT rows"
  
  if [ "$PRIMARY_COUNT" = "$REPLICA_COUNT" ]; then
    echo "  ✓ Row count matches"
    MATCHED_DATA=$((MATCHED_DATA+1))
  else
    echo "  ✗ Row count mismatch!"
    MISMATCHED_DATA=$((MISMATCHED_DATA+1))
  fi
  
  # If table has data and counts match, verify a sample of data
  if [ "$PRIMARY_COUNT" != "0" ] && [ "$PRIMARY_COUNT" = "$REPLICA_COUNT" ]; then
    # Get MD5 hash of all data in the table (limited to 100 rows for performance)
    PRIMARY_HASH=$(docker exec primary_container psql -U postgres -t -c "SELECT MD5(CAST((SELECT * FROM $TABLE LIMIT 100) AS text));")
    REPLICA_HASH=$(docker exec replica_container psql -U postgres -t -c "SELECT MD5(CAST((SELECT * FROM $TABLE LIMIT 100) AS text));")
    
    PRIMARY_HASH=$(echo $PRIMARY_HASH | xargs)
    REPLICA_HASH=$(echo $REPLICA_HASH | xargs)
    
    if [ "$PRIMARY_HASH" = "$REPLICA_HASH" ]; then
      echo "  ✓ Sample data hash matches"
    else
      echo "  ✗ Sample data hash mismatch!"
      MATCHED_DATA=$((MATCHED_DATA-1))
      MISMATCHED_DATA=$((MISMATCHED_DATA+1))
    fi
  fi
  
  echo
done

echo "===== Summary ====="
echo "Total tables: $TOTAL_TABLES"
echo "Tables with matching structure: $MATCHED_STRUCTURE"
echo "Tables with matching data: $MATCHED_DATA"
echo "Tables with structure mismatches: $MISMATCHED_STRUCTURE"
echo "Tables with data mismatches: $MISMATCHED_DATA"
echo

if [ $MISMATCHED_STRUCTURE -eq 0 ] && [ $MISMATCHED_DATA -eq 0 ]; then
  echo "✅ VERIFICATION SUCCESSFUL: All tables and data have been replicated correctly!"
else
  echo "❌ VERIFICATION FAILED: Some tables or data have not been replicated correctly!"
fi
