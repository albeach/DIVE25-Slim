-- Create admin users
DO $$
BEGIN
   IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'mike') THEN
      CREATE USER mike WITH PASSWORD 'Mike2025!' SUPERUSER;
   END IF;
   IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'aubrey') THEN
      CREATE USER aubrey WITH PASSWORD 'Aubrey2025!' SUPERUSER;
   END IF;
   IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'keycloak') THEN
      CREATE USER keycloak WITH PASSWORD '${KEYCLOAK_DB_PASSWORD}';
   END IF;
END
$$;

-- Create database if not exists
SELECT 'CREATE DATABASE keycloak'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'keycloak')\gexec

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE keycloak TO keycloak;
GRANT ALL PRIVILEGES ON DATABASE keycloak TO mike;
GRANT ALL PRIVILEGES ON DATABASE keycloak TO aubrey; 