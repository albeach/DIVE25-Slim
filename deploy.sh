#!/bin/bash
# deploy.sh

# Exit on error
set -e

# Load environment variables
if [ -f .env.production ]; then
  source .env.production
else
  echo "Error: .env.production file not found"
  exit 1
fi

# Function to generate a random alphanumeric string (no special characters)
generate_random_string() {
  local length=${1:-12}
  tr -dc 'A-Za-z0-9' </dev/urandom | head -c "$length"
}

# Ensure required environment variables are set
required_vars=(
  "MONGO_ROOT_USER"
  "MONGO_ROOT_PASSWORD"
  "KEYCLOAK_ADMIN_PASSWORD"
  "KEYCLOAK_DB_PASSWORD"
  "GRAFANA_ADMIN_PASSWORD"
)

for var in "${required_vars[@]}"; do
  if [ -z "${!var}" ]; then
    export $var=$(generate_random_string 12)
    echo "$var was not set. Generated random value."
    echo "$var=${!var}" >> .env.production
  fi
done

# Check required tools
command -v docker >/dev/null 2>&1 || { echo "Docker is required but not installed. Aborting." >&2; exit 1; }
command -v docker-compose >/dev/null 2>&1 || { echo "Docker Compose is required but not installed. Aborting." >&2; exit 1; }

# Check if Dockerfiles exist
if [ ! -f "backend/Dockerfile" ]; then
    echo "Error: backend/Dockerfile not found"
    exit 1
fi

if [ ! -f "frontend/Dockerfile" ]; then
    echo "Error: frontend/Dockerfile not found"
    exit 1
fi

# Bring down existing services
docker-compose down

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

echo "Deployment completed successfully"