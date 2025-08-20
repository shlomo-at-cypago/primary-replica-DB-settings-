#!/bin/sh
set -e

# Wait for the primary to be up and running
until pg_isready -h primary -p 5432; do
  echo "Waiting for primary database to be ready..."
  sleep 2
done

# Perform base backup if the data directory is not yet initialized
if [ ! -s "/var/lib/postgresql/data/postgresql.conf" ]; then
  echo "Initializing replica from primary..."
  gosu postgres pg_basebackup -h primary -D /var/lib/postgresql/data -U replica_user -P -v -R
fi

echo "Starting replica..."

# Start the PostgreSQL server as the correct user
exec "$@"
