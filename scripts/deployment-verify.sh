#!/bin/bash
# /scripts/deployment-verify.sh

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

verify_env() {
    log "${YELLOW}Verifying environment variables...${NC}"
    
    required_vars=(
        "MONGO_INITDB_ROOT_USERNAME"
        "MONGO_INITDB_ROOT_PASSWORD"
        "KEYCLOAK_ADMIN_PASSWORD"
        "KEYCLOAK_DB_PASSWORD"
        "KEYCLOAK_CLIENT_SECRET"
        "JWT_SECRET"
        "API_KEY"
        "GRAFANA_ADMIN_PASSWORD"
    )

    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            log "${RED}Error: $var is not set${NC}"
            exit 1
        fi
    done
    
    log "${GREEN}Environment variables verified${NC}"
}

verify_certificates() {
    log "${YELLOW}Verifying SSL certificates...${NC}"
    
    CERT_DIR="certificates/prod"
    if [ ! -f "$CERT_DIR/fullchain.pem" ] || [ ! -f "$CERT_DIR/privkey.pem" ]; then
        log "${RED}Error: SSL certificates not found in $CERT_DIR${NC}"
        exit 1
    fi
    
    if ! openssl x509 -in "$CERT_DIR/fullchain.pem" -noout -checkend 0; then
        log "${RED}Error: SSL certificate is expired${NC}"
        exit 1
    }
    
    log "${GREEN}SSL certificates verified${NC}"
}

verify_docker() {
    log "${YELLOW}Verifying Docker configuration...${NC}"
    
    if ! docker info >/dev/null 2>&1; then
        log "${RED}Error: Docker is not running${NC}"
        exit 1
    }
    
    if ! docker-compose version >/dev/null 2>&1; then
        log "${RED}Error: Docker Compose is not installed${NC}"
        exit 1
    }
    
    log "${GREEN}Docker configuration verified${NC}"
}

verify_services() {
    log "${YELLOW}Verifying service configurations...${NC}"
    
    services=(
        "api"
        "frontend"
        "mongodb"
        "redis"
        "keycloak"
        "kong"
        "prometheus"
        "grafana"
    )

    for service in "${services[@]}"; do
        if ! docker-compose config --services | grep -q "^$service\$"; then
            log "${RED}Error: Service $service not found in docker-compose config${NC}"
            exit 1
        fi
    done
    
    log "${GREEN}Service configurations verified${NC}"
}

verify_network() {
    log "${YELLOW}Verifying network connectivity...${NC}"
    
    # Check if network exists
    if ! docker network ls | grep -q "dive25-net"; then
        log "${RED}Error: dive25-net network not found${NC}"
        exit 1
    fi
    
    log "${GREEN}Network configuration verified${NC}"
}

verify_ports() {
    log "${YELLOW}Verifying port availability...${NC}"
    
    required_ports=(
        80
        443
        3000
        8080
        27017
        6379
        9090
        3001
    )

    for port in "${required_ports[@]}"; do
        if netstat -tln | grep -q ":$port "; then
            log "${RED}Error: Port $port is already in use${NC}"
            exit 1
        fi
    done
    
    log "${GREEN}Port availability verified${NC}"
}

verify_files() {
    log "${YELLOW}Verifying required files...${NC}"
    
    required_files=(
        "docker-compose.yml"
        "docker-compose.production.yml"
        ".env.production"
        "nginx/conf.d/default.conf"
        "kong/declarative/kong.yml"
        "config/keycloak/keycloak-realm.json"
    )

    for file in "${required_files[@]}"; do
        if [ ! -f "$file" ]; then
            log "${RED}Error: Required file $file not found${NC}"
            exit 1
        fi
    done
    
    log "${GREEN}Required files verified${NC}"
}

verify_permissions() {
    log "${YELLOW}Verifying file permissions...${NC}"
    
    # Ensure sensitive files have restricted permissions
    files_640=(
        ".env.production"
        "certificates/prod/privkey.pem"
    )

    for file in "${files_640[@]}"; do
        if [ -f "$file" ]; then
            chmod 640 "$file"
        fi
    done
    
    log "${GREEN}File permissions verified${NC}"
}

deploy() {
    log "${YELLOW}Starting deployment...${NC}"
    
    # Pull latest images
    docker-compose -f docker-compose.production.yml pull
    
    # Start services
    docker-compose -f docker-compose.production.yml up -d
    
    # Wait for services to be healthy
    sleep 30
    
    # Verify services are running
    if ! curl -sf http://localhost/health > /dev/null; then
        log "${RED}Error: Health check failed${NC}"
        exit 1
    fi
    
    log "${GREEN}Deployment completed successfully${NC}"
}

# Add new helper function for dependency checking
check_dependencies() {
    local deps=("curl" "docker" "docker-compose" "jq" "openssl")
    local missing=()

    log "${YELLOW}Checking dependencies...${NC}"
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing+=("$dep")
        fi
    done

    if [ ${#missing[@]} -ne 0 ]; then
        log "${RED}✗ Missing required dependencies: ${missing[*]}${NC}"
        return 1
    fi
    
    log "${GREEN}✓ All dependencies present${NC}"
    return 0
}

# Enhance verify_service with response code and content checking
verify_service() {
    local service=$1
    local port=$2
    local endpoint=$3
    local timeout=${4:-30}
    local expected_code=${5:-200}
    local content_pattern=${6:-""}

    log "${YELLOW}Verifying $service...${NC}"
    
    local elapsed=0
    while [ $elapsed -lt $timeout ]; do
        local response=$(curl -s -w "\n%{http_code}" "http://localhost:$port$endpoint")
        local http_code=$(echo "$response" | tail -n1)
        local content=$(echo "$response" | sed \$d)

        if [ "$http_code" = "$expected_code" ]; then
            if [ -n "$content_pattern" ]; then
                if echo "$content" | grep -q "$content_pattern"; then
                    log "${GREEN}✓ $service is healthy (matched content pattern)${NC}"
                    return 0
                fi
            else
                log "${GREEN}✓ $service is healthy${NC}"
                return 0
            fi
        fi
        sleep 2
        elapsed=$((elapsed + 2))
    done

    log "${RED}✗ $service failed to respond (expected $expected_code, got $http_code)${NC}"
    return 1
}

# Fix certificate directory ternary syntax
verify_certificates() {
    local cert_dir
    if [ "${ENV,,}" = "production" ]; then
        cert_dir="${PROJECT_ROOT}/certificates/prod"
    else
        cert_dir="${PROJECT_ROOT}/certificates/dev"
    fi

    # ... existing code ...
}

verify_keycloak() {
    log "${YELLOW}Verifying Keycloak...${NC}"
    
    # Wait for Keycloak to be ready with longer timeout
    verify_service "Keycloak" "8080" "/health" 90 || return 1

    log "${YELLOW}Obtaining Keycloak admin token...${NC}"
    
    # Check for both old and new environment variables
    local admin_user=${KC_BOOTSTRAP_ADMIN_USERNAME:-${KEYCLOAK_ADMIN:-""}}
    local admin_pass=${KC_BOOTSTRAP_ADMIN_PASSWORD:-${KEYCLOAK_ADMIN_PASSWORD:-""}}

    if [ -z "$admin_user" ] || [ -z "$admin_pass" ]; then
        log "${RED}✗ Keycloak admin credentials not set${NC}"
        log "${YELLOW}Please set either:${NC}"
        log "  - KC_BOOTSTRAP_ADMIN_USERNAME and KC_BOOTSTRAP_ADMIN_PASSWORD (recommended)"
        log "  - KEYCLOAK_ADMIN and KEYCLOAK_ADMIN_PASSWORD (deprecated)"
        return 1
    }

    # Add longer delay to ensure Keycloak is fully initialized
    log "${YELLOW}Waiting for Keycloak to fully initialize...${NC}"
    sleep 10

    # Get admin token with verbose curl output for debugging
    log "${YELLOW}Attempting login with username: $admin_user${NC}"
    local token_response
    token_response=$(curl -v -X POST \
        "http://localhost:8080/realms/master/protocol/openid-connect/token" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "client_id=admin-cli" \
        -d "username=$admin_user" \
        -d "password=$admin_pass" \
        -d "grant_type=password" 2>&1)

    # Extract the token from the response
    local token
    token=$(echo "$token_response" | grep -o '"access_token":"[^"]*' | cut -d'"' -f4)

    if [ -z "$token" ]; then
        log "${RED}✗ Failed to obtain Keycloak admin token${NC}"
        log "${RED}Full response:${NC}"
        echo "$token_response"
        
        log "${YELLOW}Checking Keycloak container status...${NC}"
        docker-compose ps keycloak
        
        log "${YELLOW}Checking Keycloak logs...${NC}"
        docker-compose logs --tail=50 keycloak
        return 1
    fi

    log "${GREEN}✓ Successfully obtained admin token${NC}"
    log "${YELLOW}Verifying realm 'dive25'...${NC}"
    
    # Check realm with updated API endpoint
    local realm_response
    realm_response=$(curl -s -w "\n%{http_code}" \
        -H "Authorization: Bearer $token" \
        "http://localhost:8080/admin/realms/dive25")
    
    local http_code=$(echo "$realm_response" | tail -n1)
    local content=$(echo "$realm_response" | sed \$d)

    if [ "$http_code" = "200" ]; then
        log "${GREEN}✓ Keycloak realm 'dive25' verified${NC}"
        return 0
    else
        log "${RED}✗ Keycloak realm verification failed (HTTP $http_code)${NC}"
        log "${RED}Response: $content${NC}"
        
        log "${YELLOW}Attempting to list all realms...${NC}"
        curl -s -H "Authorization: Bearer $token" \
            "http://localhost:8080/admin/realms" | jq -r '.[].realm'
        
        log "${YELLOW}Checking realm import status in logs...${NC}"
        docker-compose logs --tail=100 keycloak | grep -i "realm.*import"
        return 1
    fi
}

main() {
    log "Starting deployment verification for ${ENV} environment"

    # Check dependencies first
    check_dependencies || exit 1

    # ... existing code ...

    # Enhanced service verifications with content patterns
    verify_mongodb || exit 1
    verify_keycloak || exit 1
    verify_service "Kong" "8001" "/status" 30 200 '"database":{"reachable":true}' || exit 1
    verify_service "API" "3000" "/health" 30 200 '"status":"healthy"' || exit 1
    verify_service "Frontend" "3002" "/" 30 200 "<html" || exit 1

    log "${GREEN}All verifications passed successfully!${NC}"
}

# Run main function
main "$@"