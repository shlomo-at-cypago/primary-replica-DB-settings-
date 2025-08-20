# This file is used to build migration docker.
# This container is to be used both in cloud environments and for local dev.
FROM migrate/migrate:latest
RUN apk add --no-cache postgresql-client
RUN mkdir /migrations
COPY services/backend/deployment/postgres/migrations/* /migrations/
ENTRYPOINT [ "sh" ]
CMD [ "-c", "migrate -verbose -source file:///migrations -database \"postgresql://$POSTGRES_ADDR/$POSTGRES_DB?user=$POSTGRES_USER&password=$POSTGRES_PASSWORD\" up" ]