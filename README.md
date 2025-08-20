# 
Here are the key files involved in the PostgreSQL replication process:
1. Docker Compose Configuration:
    - 4_cyp-10552-docker-compose.yml - Main docker-compose file defining primary, replica, and migration services
2. PostgreSQL Configuration Files:
    - config/primary/postgresql.conf - Primary database configuration
    - config/primary/pg_hba.conf - Primary database authentication configuration
    - config/replica/postgresql.conf - Replica database configuration
    - config/replica/pg_hba.conf - Replica database authentication configuration
3. User Creation Script:
    - config/01_create_replica_user.sh - Script to create the replica user on the primary
4. Docker Entry Point Scripts:
    - docker-entrypoint-replica.sh - Custom entrypoint script for replica container
    - init-primary.sh - Initialization script for primary database
5. Dockerfiles:
    - Dockerfile.primary - Dockerfile for primary database
    - Dockerfile.replica - Dockerfile for replica database
    - Dockerfile.migration - Dockerfile for migration service
6. Migration Files:
    - migrations/ directory containing SQL migration files
7. Verification Scripts:
    - verify_replication.sh - Script to verify replication
    - verify_replication_improved.sh - Improved script to verify replication

These files together create a PostgreSQL replication setup with a primary database for write operations, a replica database for read operations, and a migration service that applies database migrations.