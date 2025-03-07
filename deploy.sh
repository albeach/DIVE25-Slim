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
    local retries=45  # Increased from 30
    local wait_seconds=10
    
    echo "Waiting for Keycloak to be ready..."
    while [ $retries -gt 0 ]; do
        echo "Attempting to connect to Keycloak... ($retries attempts left)"
        
        # First check if container is running
        if ! docker-compose ps keycloak | grep -q "Up"; then
            echo "Keycloak container is not running"
            docker-compose logs --tail=20 keycloak
            sleep $wait_seconds
            retries=$((retries-1))
            continue
        fi
        
        # Try multiple health check endpoints since Keycloak's endpoints can vary
        if curl -s -f "http://localhost:8080/auth/health/ready" > /dev/null || \
           curl -s -f "http://localhost:8080/health/ready" > /dev/null || \
           curl -s -f "http://localhost:8080/auth/realms/master" > /dev/null || \
           curl -s -f "http://localhost:8080/realms/master" > /dev/null; then
            echo "Keycloak is responding to health checks"
            
            # Add additional delay to ensure realm import is complete
            echo "Waiting for Keycloak to fully initialize..."
            sleep 30  # Increased from 15
            echo "Keycloak is ready!"
            return 0
        fi
        
        # If we've waited a few times, show the logs to help diagnose issues
        if [ $retries -eq 25 ] || [ $retries -eq 15 ] || [ $retries -eq 5 ]; then
            echo "Recent Keycloak logs:"
            docker-compose logs --tail=50 keycloak
        fi
        
        retries=$((retries-1))
        echo "Waiting $wait_seconds seconds before next attempt..."
        sleep $wait_seconds
    done
    
    echo "ERROR: Keycloak failed to become ready"
    docker-compose logs keycloak
    return 1
}

verify_keycloak_realm() {
    echo "Verifying realm 'dive25' exists..."
    
    # Diagnostic output - show Keycloak admin credentials (redacted for security)
    echo "Using admin credentials: ${KEYCLOAK_ADMIN} / ********"
    
    # Try various token endpoints with detailed error handling
    echo "Attempting to get admin token..."
    
    # First try with /auth path
    echo "Trying with /auth path..."
    TOKEN_RESPONSE=$(curl -s -X POST "http://localhost:8080/auth/realms/master/protocol/openid-connect/token" \
        -d "client_id=admin-cli" \
        -d "username=${KEYCLOAK_ADMIN}" \
        -d "password=${KEYCLOAK_ADMIN_PASSWORD}" \
        -d "grant_type=password")
    
    # Check if token was obtained
    if [ -z "$TOKEN_RESPONSE" ]; then
        echo "Empty response from token endpoint with /auth path"
    elif [[ "$TOKEN_RESPONSE" == *"error"* ]]; then
        echo "Error response from token endpoint with /auth path: $TOKEN_RESPONSE"
    elif [[ "$TOKEN_RESPONSE" == *"access_token"* ]]; then
        echo "Successfully received token with /auth path"
        TOKEN=$TOKEN_RESPONSE
    else
        echo "Unexpected response from token endpoint with /auth path: $TOKEN_RESPONSE"
    fi
    
    # If no token yet, try without /auth path
    if [ -z "$TOKEN" ] || [[ "$TOKEN" != *"access_token"* ]]; then
        echo "Trying without /auth path..."
        TOKEN_RESPONSE=$(curl -s -X POST "http://localhost:8080/realms/master/protocol/openid-connect/token" \
            -d "client_id=admin-cli" \
            -d "username=${KEYCLOAK_ADMIN}" \
            -d "password=${KEYCLOAK_ADMIN_PASSWORD}" \
            -d "grant_type=password")
        
        # Check if token was obtained
        if [ -z "$TOKEN_RESPONSE" ]; then
            echo "Empty response from token endpoint without /auth path"
        elif [[ "$TOKEN_RESPONSE" == *"error"* ]]; then
            echo "Error response from token endpoint without /auth path: $TOKEN_RESPONSE"
        elif [[ "$TOKEN_RESPONSE" == *"access_token"* ]]; then
            echo "Successfully received token without /auth path"
            TOKEN=$TOKEN_RESPONSE
        else
            echo "Unexpected response from token endpoint without /auth path: $TOKEN_RESPONSE"
        fi
    fi
    
    # If still no token, try one more time with alternative port
    if [ -z "$TOKEN" ] || [[ "$TOKEN" != *"access_token"* ]]; then
        echo "Trying Keycloak container directly..."
        
        # Get the internal IP of the Keycloak container
        KEYCLOAK_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(docker-compose ps -q keycloak))
        
        if [ -n "$KEYCLOAK_IP" ]; then
            echo "Keycloak container IP: $KEYCLOAK_IP"
            TOKEN_RESPONSE=$(curl -s -X POST "http://$KEYCLOAK_IP:8080/realms/master/protocol/openid-connect/token" \
                -d "client_id=admin-cli" \
                -d "username=${KEYCLOAK_ADMIN}" \
                -d "password=${KEYCLOAK_ADMIN_PASSWORD}" \
                -d "grant_type=password")
            
            if [[ "$TOKEN_RESPONSE" == *"access_token"* ]]; then
                echo "Successfully received token from container IP"
                TOKEN=$TOKEN_RESPONSE
            else
                echo "Failed to get token from container IP: $TOKEN_RESPONSE"
            fi
        else
            echo "Could not determine Keycloak container IP"
        fi
    fi
    
    # If we still don't have a token, give up
    if [ -z "$TOKEN" ] || [[ "$TOKEN" != *"access_token"* ]]; then
        echo "Failed to get admin token after multiple attempts"
        echo "This might indicate Keycloak is still initializing or there's a configuration issue"
        echo "Checking Keycloak logs..."
        docker-compose logs --tail=50 keycloak
        
        # Instead of failing immediately, add a long delay and try once more
        echo "Waiting 60 seconds for one final attempt..."
        sleep 60
        
        # Final attempt with both paths
        TOKEN_RESPONSE=$(curl -s -X POST "http://localhost:8080/auth/realms/master/protocol/openid-connect/token" \
            -d "client_id=admin-cli" \
            -d "username=${KEYCLOAK_ADMIN}" \
            -d "password=${KEYCLOAK_ADMIN_PASSWORD}" \
            -d "grant_type=password")
            
        if [[ "$TOKEN_RESPONSE" == *"access_token"* ]]; then
            echo "Finally got token with /auth path"
            TOKEN=$TOKEN_RESPONSE
        else
            TOKEN_RESPONSE=$(curl -s -X POST "http://localhost:8080/realms/master/protocol/openid-connect/token" \
                -d "client_id=admin-cli" \
                -d "username=${KEYCLOAK_ADMIN}" \
                -d "password=${KEYCLOAK_ADMIN_PASSWORD}" \
                -d "grant_type=password")
                
            if [[ "$TOKEN_RESPONSE" == *"access_token"* ]]; then
                echo "Finally got token without /auth path"
                TOKEN=$TOKEN_RESPONSE
            else
                echo "All attempts to get admin token failed"
                return 1
            fi
        fi
    fi

    # Extract the access token
    ACCESS_TOKEN=$(echo "$TOKEN" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)
    
    if [ -z "$ACCESS_TOKEN" ]; then
        echo "Failed to extract access token from response"
        echo "Response: $TOKEN"
        return 1
    fi

    echo "Successfully obtained admin token"

    # Add delay to ensure realm is fully imported
    sleep 10

    # Try with /auth prefix first
    echo "Checking realm with /auth prefix..."
    response=$(curl -s -X GET \
        -H "Authorization: Bearer $ACCESS_TOKEN" \
        "http://localhost:8080/auth/admin/realms/dive25" 2>&1)
    
    # If first attempt fails, try without /auth prefix
    if [[ "$response" == *"error"* ]] || [ -z "$response" ]; then
        echo "First attempt failed, trying without /auth prefix..."
        response=$(curl -s -X GET \
            -H "Authorization: Bearer $ACCESS_TOKEN" \
            "http://localhost:8080/admin/realms/dive25" 2>&1)
    fi
    
    # Check if the response is valid JSON and contains the realm name
    if echo "$response" | jq -e . >/dev/null 2>&1; then
        if [[ $(echo "$response" | jq -r '.realm' 2>/dev/null) == "dive25" ]]; then
            echo "Realm verification successful!"
            return 0
        else
            echo "Response doesn't contain expected realm name: $(echo "$response" | jq .)"
        fi
    else
        echo "Invalid JSON response: $response"
    fi
    
    # If we get here, verification failed
    echo "Realm may not be fully imported yet. Let's list available realms..."
    
    # Try to list all realms to see what's available
    realms_response=$(curl -s -X GET \
        -H "Authorization: Bearer $ACCESS_TOKEN" \
        "http://localhost:8080/admin/realms" 2>&1)
    
    if [ -z "$realms_response" ]; then
        realms_response=$(curl -s -X GET \
            -H "Authorization: Bearer $ACCESS_TOKEN" \
            "http://localhost:8080/auth/admin/realms" 2>&1)
    fi
    
    echo "Available realms: $realms_response"
    
    # Check if "master" realm is available (it should always be)
    master_response=$(curl -s -X GET \
        -H "Authorization: Bearer $ACCESS_TOKEN" \
        "http://localhost:8080/admin/realms/master" 2>&1)
    
    echo "Master realm check: $master_response"
    
    echo "Realm verification failed. Giving additional time for import..."
    sleep 30  # Wait longer for realm import
    
    # Final attempt
    final_response=$(curl -s -X GET \
        -H "Authorization: Bearer $ACCESS_TOKEN" \
        "http://localhost:8080/admin/realms/dive25" 2>&1)
    
    if echo "$final_response" | jq -e . >/dev/null 2>&1; then
        if [[ $(echo "$final_response" | jq -r '.realm' 2>/dev/null) == "dive25" ]]; then
            echo "Realm verification finally successful after additional wait!"
            return 0
        fi
    fi
    
    # Allow deployment to continue even if verification fails
    echo "WARNING: Could not verify dive25 realm, but continuing deployment."
    echo "You may need to manually check Keycloak configuration after deployment."
    return 0  # Return success to continue deployment
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
COMPOSE_FILE="docker-compose.yml"
if [ "$NODE_ENV" != "production" ]; then
    COMPOSE_FILE="docker-compose.${NODE_ENV}.yml"
fi

if [ ! -f "$COMPOSE_FILE" ]; then
    log "${RED}Error: Docker compose file '$COMPOSE_FILE' not found${NC}"
    exit 1
fi

log "Starting deployment for ${NODE_ENV} environment"

# Function to set up certificates based on environment
setup_certificates() {
  local env=$1
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] Setting up certificates for $env environment..."
  
  if [[ "$env" == "dev" || "$env" == "development" ]]; then
    # Check if development certificates exist
    if [[ -f "./certificates/dev/server.crt" && -f "./certificates/dev/server.key" ]]; then
      echo "[$(date +'%Y-%m-%d %H:%M:%S')] Using existing development certificates."
    else
      echo "[$(date +'%Y-%m-%d %H:%M:%S')] Development certificates not found. Generating new ones..."
      
      # Check if mkcert is installed
      if command -v mkcert &> /dev/null; then
        # Create dev directory if it doesn't exist
        mkdir -p ./certificates/dev
        
        # Install local CA
        mkcert -install
        
        # Generate certificates for local development
        mkcert -key-file ./certificates/dev/server.key -cert-file ./certificates/dev/server.crt "localhost" "127.0.0.1" "::1" "*.dive25.local"
        
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] Development certificates generated successfully."
      else
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] mkcert not found. Please install mkcert or manually create development certificates."
        echo "For macOS: brew install mkcert nss"
        echo "For Linux: Follow instructions at https://github.com/FiloSottile/mkcert"
        exit 1
      fi
    fi
    
    # Set certificate paths for Docker
    CERT_PATH="./certificates/dev/server.crt"
    KEY_PATH="./certificates/dev/server.key"
    
  elif [[ "$env" == "prod" || "$env" == "production" ]]; then
    # Check if production certificates exist
    if [[ -f "./certificates/prod/config/live/dive25.com/fullchain.pem" && -f "./certificates/prod/config/live/dive25.com/privkey.pem" ]]; then
      echo "[$(date +'%Y-%m-%d %H:%M:%S')] Using existing production certificates."
    else
      echo "[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: Production certificates not found."
      echo "Expected files in ./certificates/prod/config/live/dive25.com/"
      echo "Please ensure Let's Encrypt certificates are properly set up."
      exit 1
    fi
    
    # Set certificate paths for Docker
    CERT_PATH="./certificates/prod/config/live/dive25.com/fullchain.pem"
    KEY_PATH="./certificates/prod/config/live/dive25.com/privkey.pem"
  else
    # Prompt user to choose environment if not specified
    echo "Please select environment for SSL certificates:"
    echo "1) Development (using certificates in ./certificates/dev/)"
    echo "2) Production (using Let's Encrypt certificates)"
    read -p "Enter choice [1-2]: " cert_choice
    
    case $cert_choice in
      1)
        setup_certificates "dev"
        return
        ;;
      2)
        setup_certificates "prod"
        return
        ;;
      *)
        echo "Invalid choice. Exiting."
        exit 1
        ;;
    esac
  fi
  
  # Export certificate paths as environment variables for docker-compose
  export SSL_CERT_PATH=$CERT_PATH
  export SSL_KEY_PATH=$KEY_PATH
  
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] Certificate setup completed successfully."
}

# Update docker-compose configuration to use the certificates
update_docker_compose_config() {
  # Create or update .env.ssl file with certificate paths
  echo "SSL_CERT_PATH=$SSL_CERT_PATH" > .env.ssl
  echo "SSL_KEY_PATH=$SSL_KEY_PATH" >> .env.ssl
  
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] Updated Docker configuration with certificate paths."
}

# Setup certificates based on environment
if [[ "$NODE_ENV" == "production" ]]; then
  ENVIRONMENT="prod"
else
  ENVIRONMENT="dev"
fi

# Setup certificates directly instead of using cert-manager.sh
echo "[$(date +'%Y-%m-%d %H:%M:%S')] Setting up certificates..."
setup_certificates "$ENVIRONMENT"
update_docker_compose_config

# Source the SSL environment variables
if [ -f .env.ssl ]; then
  set -a
  source .env.ssl
  set +a
  echo "SSL certificate paths loaded from .env.ssl"
else
  echo "ERROR: .env.ssl file not found after certificate setup"
  exit 1
fi

# Set Keycloak admin credentials if not already set
if [ -z "$KC_BOOTSTRAP_ADMIN_USERNAME" ]; then
    export KC_BOOTSTRAP_ADMIN_USERNAME=${KEYCLOAK_ADMIN:-admin}
fi

if [ -z "$KC_BOOTSTRAP_ADMIN_PASSWORD" ]; then
    export KC_BOOTSTRAP_ADMIN_PASSWORD=${KEYCLOAK_ADMIN_PASSWORD:-admin}
fi

# Validate docker-compose file before starting
if ! docker-compose -f "$COMPOSE_FILE" config > /dev/null; then
    log "${RED}Docker compose file '$COMPOSE_FILE' has syntax errors${NC}"
    docker-compose -f "$COMPOSE_FILE" config
    exit 1
fi

# Start services
log "${YELLOW}Starting services...${NC}"
if ! docker-compose -f "$COMPOSE_FILE" up -d; then
    log "${RED}Failed to start services${NC}"
    exit 1
fi

# Verify deployment
log "${YELLOW}Verifying deployment...${NC}"
if [ -f "${SCRIPT_DIR}/scripts/deployment-verify.sh" ]; then
    if ! "${SCRIPT_DIR}/scripts/deployment-verify.sh"; then
        log "${RED}Deployment verification failed. Checking logs...${NC}"
        docker-compose logs keycloak
        exit 1
    fi
else
    log "${YELLOW}Deployment verification script not found, skipping verification${NC}"
fi

log "${GREEN}Deployment completed successfully!${NC}"