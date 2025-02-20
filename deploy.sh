#!/bin/bash
# deploy.sh

# Exit on error
set -e

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

# Function to generate a random alphanumeric string (no special characters)
generate_random_string() {
  local length=${1:-12}
  tr -dc 'A-Za-z0-9' </dev/urandom | head -c "$length"
}

# Ensure required environment variables are set
required_vars=(
  "MONGO_INITDB_ROOT_USERNAME"
  "MONGO_INITDB_ROOT_PASSWORD"
  "KEYCLOAK_ADMIN_PASSWORD"
  "KEYCLOAK_DB_PASSWORD"
  "GRAFANA_ADMIN_PASSWORD"
)

# Check and update both environment and .env.production file
env_updated=false
for var in "${required_vars[@]}"; do
  if [ -z "${!var}" ]; then
    value=$(generate_random_string 12)
    export $var=$value
    echo "$var was not set. Generated random value."
    if grep -q "^${var}=" .env.production; then
        sed -i.bak "s/^${var}=.*/${var}=${value}/" .env.production
    else
        echo "${var}=${value}" >> .env.production
    fi
    env_updated=true
  fi
done

if [ "$env_updated" = true ]; then
    echo "Environment variables were updated. Restarting services..."
    docker-compose down
    source .env.production
else
    docker-compose down
fi

# Pull latest images
docker-compose pull

# Build services
echo "Building services..."
docker-compose build --no-cache api frontend || {
    echo "Error: Build failed"
    exit 1
}

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

# Wait for Keycloak
if ! wait_for_keycloak; then
  echo "Failed to start Keycloak. Exiting."
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