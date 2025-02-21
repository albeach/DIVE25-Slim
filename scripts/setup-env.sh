#!/bin/bash
set -e

# Function to generate a secure random string
generate_secure_string() {
    openssl rand -base64 32 | tr -dc 'A-Za-z0-9' | head -c 24
}

# Required environment variables
required_vars=(
    "MONGO_INITDB_ROOT_USERNAME"
    "MONGO_INITDB_ROOT_PASSWORD"
    "KEYCLOAK_ADMIN_PASSWORD"
    "KEYCLOAK_DB_PASSWORD"
    "KEYCLOAK_CLIENT_SECRET"
    "POSTGRES_PASSWORD"
    "JWT_SECRET"
    "API_KEY"
    "GRAFANA_ADMIN_PASSWORD"
    "LDAP_ADMIN_PASSWORD"
    "LDAP_READONLY_PASSWORD"
)

# Create or update .env file
ENV_FILE=".env"
touch "$ENV_FILE"

# Check and generate environment variables
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        value=$(generate_secure_string)
        # Export to current shell
        export "$var=$value"
        echo "Generated $var"
        
        # Update .env file
        if grep -q "^${var}=" "$ENV_FILE"; then
            sed -i.bak "s/^${var}=.*/${var}=${value}/" "$ENV_FILE"
        else
            echo "${var}=${value}" >> "$ENV_FILE"
        fi
    fi
done

# Source the .env file to ensure all variables are available
set -a
source "$ENV_FILE"
set +a

echo "Environment variables have been set and exported" 