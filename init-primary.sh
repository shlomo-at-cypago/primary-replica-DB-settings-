#!/bin/sh
set -e

# Create postgres user and group if they don't exist (idempotent)
addgroup -g 999 postgres 2>/dev/null || true
adduser -D -s /bin/bash -u 999 -G postgres postgres 2>/dev/null || true

mkdir -p /var/run/postgresql
chown -R postgres:postgres /var/run/postgresql
chown -R postgres:postgres /var/lib/postgresql/data

cp /etc/postgresql/postgresql.conf /var/lib/postgresql/data/postgresql.conf
cp /etc/postgresql/pg_hba.conf /var/lib/postgresql/data/pg_hba.conf

if [ -s /var/lib/postgresql/data/PG_VERSION ]; then
  echo "Existing database, starting..."
  exec su-exec postgres postgres -c config_file=/var/lib/postgresql/data/postgresql.conf
else
  echo "Fresh database, running initdb..."
  su-exec postgres sh -c "
    initdb -D /var/lib/postgresql/data &&
    postgres -D /var/lib/postgresql/data &
    TEMP_PID=\$! &&
    until pg_isready -h localhost -p 5432 -U postgres; do sleep 1; done &&
    psql -h localhost -p 5432 -U postgres -d postgres -f /docker-entrypoint-initdb.d/init.sql &&
    kill \$TEMP_PID &&
    wait \$TEMP_PID
  "
  exec su-exec postgres postgres -c config_file=/var/lib/postgresql/data/postgresql.conf
fi
