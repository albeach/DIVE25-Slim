#!/bin/bash
set -e

# Replace the password placeholder in the SQL file
sed "s/\${KEYCLOAK_DB_PASSWORD}/$KEYCLOAK_DB_PASSWORD/g" /docker-entrypoint-initdb.d/init-users.sql > /tmp/init-users.sql

# Execute the SQL files
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -f /tmp/init-users.sql
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "keycloak" -f /docker-entrypoint-initdb.d/init-schema.sql

# Clean up
rm -f /tmp/init-users.sql