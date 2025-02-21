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



if [ "$env_updated" = true ]; then
    echo "Environment variables were updated. Restarting services..."
    docker-compose down
    source .env.production
else
    docker-compose down
fi

echo "Pulling Docker images..."
docker-compose pull --ignore-pull-failures

echo "Building local images..."
docker-compose build

echo "Starting services..."
docker-compose up -d

echo "Waiting for services to be healthy..."
sleep 10

echo "Checking service health..."
docker-compose ps

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