#!/bin/sh
set -e


docker network create postgres_network

docker build -f Dockerfile.primary -t my-primary-image .
docker build -f Dockerfile.replica -t my-replica-image .
docker build -f Dockerfile.migration -t my-migration-image .

docker run -d --name primary --network postgres_network \
  -p 5432:5432 \
  -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=changeme \
  -v primary_data:/var/lib/postgresql/data \
  -v archive_data:/var/lib/postgresql/archive \
  my-primary-image

docker run -d --name replica --network postgres_network \
  --volumes-from primary \
  -e POSTGRES_USER=postgres -e POSTGRES_DB=postgres \
  -v replica_data:/var/lib/postgresql/data \
  my-replica-image

docker run --name migration --network postgres_network \
  -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=changeme \
  -e POSTGRES_ADDR=primary -e POSTGRES_DB=postgres \
  -v /path/to/your/migrations:/migrations \
  my-migration-image