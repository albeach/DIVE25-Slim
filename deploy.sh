#!/bin/bash
# deploy.sh

# Exit on error
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Logging function
log() {
    echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Load environment variables
if [ -f .env.production ]; then
  source .env.production
else
  if [ -f .env.template ]; then
    cp .env.template .env.production
    echo "Created .env.production from template"
  else
    echo "Error: .env.template file not found"
    exit 1
  fi
fi

# Source the environment setup script
source ./scripts/setup-env.sh

# Verify environment variables are set
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        echo "Error: Required environment variable $var is not set"
        exit 1
    fi
done

# Function to generate a random alphanumeric string (no special characters)
generate_random_string() {
  local length=${1:-12}
  tr -dc 'A-Za-z0-9' </dev/urandom | head -c "$length"
}

# Function to generate a secure password
generate_password() {
    openssl rand -base64 24 | tr -d '/+=' | cut -c1-20
}

# Function to set env variable if not exists
set_env_var() {
    local var_name=$1
    local current_value=$(grep "^${var_name}=" .env 2>/dev/null | cut -d '=' -f2)
    
    if [[ -z "$current_value" ]]; then
        local new_value=$(generate_password)
        echo "${var_name}=${new_value}" >> .env
        echo "Generated ${var_name}"
    else
        echo "${var_name} already set"
    fi
}

# Create .env file if it doesn't exist
touch .env

# Required environment variables
declare -a required_vars=(
    "MONGO_INITDB_ROOT_USERNAME"
    "MONGO_INITDB_ROOT_PASSWORD"
    "KEYCLOAK_ADMIN"
    "KEYCLOAK_ADMIN_PASSWORD"
    "KEYCLOAK_DB_PASSWORD"
    "KEYCLOAK_CLIENT_SECRET"
    "JWT_SECRET"
    "API_KEY"
    "GRAFANA_ADMIN_PASSWORD"
    "LDAP_ADMIN_PASSWORD"
    "LDAP_CONFIG_PASSWORD"
    "LDAP_READONLY_PASSWORD"
    "POSTGRES_PASSWORD"
)

# Default values for non-password variables
echo "Setting default values for non-password variables..."
grep -q "^KEYCLOAK_ADMIN=" .env || echo "KEYCLOAK_ADMIN=admin" >> .env
grep -q "^NODE_ENV=" .env || echo "NODE_ENV=production" >> .env
grep -q "^MONGODB_URI=" .env || echo "MONGODB_URI=mongodb://mongodb:27017/dive25" >> .env
grep -q "^REDIS_HOST=" .env || echo "REDIS_HOST=redis" >> .env
grep -q "^OPA_URL=" .env || echo "OPA_URL=http://opa:8181" >> .env
grep -q "^KEYCLOAK_URL=" .env || echo "KEYCLOAK_URL=http://keycloak:8080" >> .env
grep -q "^NEXT_PUBLIC_API_URL=" .env || echo "NEXT_PUBLIC_API_URL=http://api:3000" >> .env
grep -q "^NEXT_PUBLIC_KEYCLOAK_URL=" .env || echo "NEXT_PUBLIC_KEYCLOAK_URL=http://keycloak:8080" >> .env

# Generate passwords for required variables
echo "Checking and generating passwords for required variables..."
for var in "${required_vars[@]}"; do
    set_env_var "$var"
done

# Export all variables from .env
echo "Exporting environment variables..."
set -a
source .env
set +a

echo "Environment setup complete. Proceeding with deployment..."

# Start the services
docker-compose down -v
docker volume prune -f
docker-compose build --no-cache
docker-compose up -d

# Wait for services to be ready
echo "Waiting for services to start..."
sleep 10

# Check service health
echo "Checking service health..."
docker-compose ps

echo "Deployment complete! Check the service status above."

# Enable debug output for curl
export CURL_VERBOSE=1

echo "Starting databases..."
docker-compose up -d mongodb redis postgres
echo "Waiting for databases to initialize..."
sleep 15

echo "Starting Keycloak..."
docker-compose up -d keycloak

# Function to check if Keycloak is ready
wait_for_keycloak() {
  local retries=30
  local wait_seconds=10  # Increased wait time
  local keycloak_url="http://localhost:8080/realms/master"  # Changed to a more reliable endpoint

  echo "Checking Keycloak health..."
  while [ $retries -gt 0 ]; do
    echo "Attempting to connect to Keycloak... ($retries attempts left)"
    
    # Show Keycloak logs
    echo "Recent Keycloak logs:"
    docker-compose logs --tail=20 keycloak
    
    # Check if container is running
    container_status=$(docker-compose ps keycloak | grep "Up" || echo "not running")
    echo "Keycloak container status: $container_status"
    
    # Try to connect to Keycloak
    if curl -s -f "$keycloak_url" > /dev/null 2>&1; then
      echo "Keycloak is ready!"
      return 0
    else
      echo "Curl failed, Keycloak not ready yet"
    fi
    
    retries=$((retries-1))
    echo "Waiting $wait_seconds seconds before next attempt..."
    sleep $wait_seconds
  done
  
  echo "ERROR: Keycloak failed to become ready"
  echo "Final Keycloak logs:"
  docker-compose logs keycloak
  return 1
}

# Add after the existing wait_for_keycloak function
verify_keycloak_realm() {
    echo "Verifying realm 'dive25' exists..."
    # Get admin token
    TOKEN=$(curl -s -X POST "http://localhost:8080/realms/master/protocol/openid-connect/token" \
        -d "client_id=admin-cli" \
        -d "username=admin" \
        -d "password=admin" \
        -d "grant_type=password" | jq -r '.access_token')

    if [ -z "$TOKEN" ]; then
        echo "Failed to get admin token"
        return 1
    fi

    response=$(curl -s -X GET \
        -H "Authorization: Bearer $TOKEN" \
        "http://localhost:8080/admin/realms/dive25")
    
    if [[ $response != *"error"* ]]; then
        echo "Realm verification successful!"
        return 0
    else
        echo "Realm verification failed!"
        return 1
    fi
}

# Wait for Keycloak
if ! wait_for_keycloak; then
  echo "Failed to start Keycloak. Exiting."
  exit 1
fi

# Add realm verification
if ! verify_keycloak_realm; then
  echo "Failed to verify Keycloak realm. Exiting."
  exit 1
fi

echo "Starting infrastructure services..."
docker-compose up -d opa kong
sleep 10

echo "Starting application services..."
docker-compose up -d api frontend

echo "Performing final health checks..."
check_health() {
  local service=$1
  local url=$2
  local retries=5
  local wait_seconds=3

  while [ $retries -gt 0 ]; do
    if curl -s -f "$url" > /dev/null 2>&1; then
      echo "$service is healthy"
      return 0
    fi
    retries=$((retries-1))
    echo "Waiting for $service to be healthy... ($retries attempts left)"
    sleep $wait_seconds
  done
  echo "$service health check failed"
  return 1
}

# Check health of services
check_health "API" "http://localhost:3000/health"
check_health "Frontend" "http://localhost:3001"

# After environment variables setup and before starting services

# Setup Kong configuration with verification
setup_kong_config() {
    echo "Setting up Kong configuration..."
    
    # Create Kong directory with proper permissions
    mkdir -p kong/declarative
    
    # Copy existing Kong configuration
    if [ -f "config/kong/declarative/kong.yml" ]; then
        cp config/kong/declarative/kong.yml kong/declarative/kong.yml
        echo "Copied Kong configuration from config directory"
    fi

    # Verify Kong configuration exists
    if [ ! -f "kong/declarative/kong.yml" ]; then
        echo "Error: Kong configuration not found"
        exit 1
    fi

    # Set permissions
    chmod 644 kong/declarative/kong.yml
    
    echo "Kong configuration is ready"
}

# Call setup function before starting Kong
setup_kong_config

# Start Kong with proper volume mount verification
echo "Starting Kong..."
docker-compose up -d kong

# Verify Kong configuration is accessible
docker-compose exec kong cat /usr/local/kong/declarative/kong.yml > /dev/null 2>&1 || {
    echo "Error: Kong configuration not properly mounted"
    docker-compose logs kong
    exit 1
}

echo "Deployment completed successfully"

# Environment validation
if [ -z "$NODE_ENV" ]; then
    log "${YELLOW}NODE_ENV not set, defaulting to development${NC}"
    export NODE_ENV=development
fi

# Validate docker-compose file exists
COMPOSE_FILE="docker-compose.${NODE_ENV}.yml"
if [ ! -f "$COMPOSE_FILE" ]; then
    log "${RED}Error: Docker compose file '$COMPOSE_FILE' not found${NC}"
    exit 1
fi

log "Starting deployment for ${NODE_ENV} environment"

# Setup certificates
log "${YELLOW}Setting up certificates...${NC}"
if ! "${SCRIPT_DIR}/scripts/cert-manager.sh"; then
    log "${RED}Certificate setup failed${NC}"
    exit 1
fi

# Set Keycloak admin credentials if not already set
if [ -z "$KC_BOOTSTRAP_ADMIN_USERNAME" ]; then
    export KC_BOOTSTRAP_ADMIN_USERNAME=${KEYCLOAK_ADMIN:-admin}
fi

if [ -z "$KC_BOOTSTRAP_ADMIN_PASSWORD" ]; then
    export KC_BOOTSTRAP_ADMIN_PASSWORD=${KEYCLOAK_ADMIN_PASSWORD:-admin}
fi

# Start services
log "${YELLOW}Starting services...${NC}"
if ! docker-compose -f "$COMPOSE_FILE" up -d; then
    log "${RED}Failed to start services${NC}"
    exit 1
fi

# Verify deployment
log "${YELLOW}Verifying deployment...${NC}"
if ! "${SCRIPT_DIR}/scripts/deployment-verify.sh"; then
    log "${RED}Deployment verification failed. Checking logs...${NC}"
    docker-compose logs keycloak
    exit 1
fi

log "${GREEN}Deployment completed successfully!${NC}"