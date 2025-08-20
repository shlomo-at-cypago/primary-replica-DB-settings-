CREATE USER activityloguser with encrypted password 'localhostactivitylog';
CREATE USER authuser with encrypted password 'localhostauth';

-- Create replication user
CREATE USER replica_user WITH REPLICATION ENCRYPTED PASSWORD 'changeme';

-- Optional: tune replication-related settings if not already in postgresql.conf
ALTER SYSTEM SET wal_level = 'replica';
ALTER SYSTEM SET max_wal_senders = 10;
ALTER SYSTEM SET max_replication_slots = 10;
ALTER SYSTEM SET hot_standby = 'on';
