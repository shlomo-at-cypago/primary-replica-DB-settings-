#!/bin/bash
set -e

# Create a dedicated user for replication if it doesn't exist
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    DO \$\$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'replica_user') THEN
            CREATE USER replica_user WITH REPLICATION ENCRYPTED PASSWORD 'changeme';
        END IF;
    END
    \$\$;
EOSQL
