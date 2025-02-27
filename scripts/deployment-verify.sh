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
        "POSTGRES_PASSWORD"
        "LDAP_ADMIN_PASSWORD"
        "LDAP_CONFIG_PASSWORD"
        "LDAP_READONLY_PASSWORD"
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
    
    # Determine certificate directory based on environment
    local cert_dir
    if [ "${NODE_ENV}" = "production" ] || [ "${NODE_ENV}" = "prod" ]; then
        cert_dir="./certificates/prod/config/live/dive25.com"
        cert_file="fullchain.pem"
        key_file="privkey.pem"
    else
        cert_dir="./certificates/dev"
        cert_file="server.crt"
        key_file="server.key"
    fi

    if [ ! -f "$cert_dir/$cert_file" ] || [ ! -f "$cert_dir/$key_file" ]; then
        log "${RED}Error: SSL certificates not found in $cert_dir${NC}"
        exit 1
    fi
    
    if ! openssl x509 -in "$cert_dir/$cert_file" -noout -checkend 0; then
        log "${RED}Error: SSL certificate is expired${NC}"
        exit 1
    fi
    
    log "${GREEN}SSL certificates verified${NC}"
}

verify_docker() {
    log "${YELLOW}Verifying Docker configuration...${NC}"
    
    if ! docker info >/dev/null 2>&1; then
        log "${RED}Error: Docker is not running${NC}"
        exit 1
    fi
    
    if ! docker-compose version >/dev/null 2>&1; then
        log "${RED}Error: Docker Compose is not installed${NC}"
        exit 1
    fi
    
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
        "postgres"
        "opa"
        "openldap"
        "phpldapadmin"
        "ldap-exporter"
        "nginx"
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
        3001
        3002
        8080
        8181
        8444
        9090
        9100
        9330
    )

    for port in "${required_ports[@]}"; do
        if netstat -tln | grep -q ":$port " && ! docker-compose ps | grep -q ":$port->"; then
            log "${RED}Error: Port $port is already in use by a non-Docker process${NC}"
            exit 1
        fi
    done
    
    log "${GREEN}Port availability verified${NC}"
}

verify_files() {
    log "${YELLOW}Verifying required files...${NC}"
    
    required_files=(
        "docker-compose.yml"
        ".env"
        "nginx/nginx.conf"
        "nginx/conf.d/default.conf"
        "config/kong/declarative/kong.yml"
        "config/keycloak/dive25-realm-full.json"
        "config/postgres/init-keycloak-db.sh"
        "config/postgres/init-users.sql"
        "config/postgres/init-schema.sql"
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
        ".env"
        ".env.ssl"
        "certificates/dev/server.key"
        "certificates/prod/config/live/dive25.com/privkey.pem"
    )

    for file in "${files_640[@]}"; do
        if [ -f "$file" ]; then
            chmod 640 "$file"
        fi
    done
    
    log "${GREEN}File permissions verified${NC}"
}

# Add new helper function for dependency checking
check_dependencies() {
    local deps=("curl" "docker" "docker-compose" "jq" "openssl" "netstat")
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
                else
                    log "${YELLOW}Got expected status code but content pattern not found. Content: ${content:0:100}...${NC}"
                fi
            else
                log "${GREEN}✓ $service is healthy${NC}"
                return 0
            fi
        fi
        
        if [ "$http_code" != "$expected_code" ]; then
            log "${YELLOW}Waiting for $service (got $http_code, expected $expected_code)...${NC}"
        else
            log "${YELLOW}Waiting for $service (waiting for content pattern match)...${NC}"
        fi
        
        sleep 5
        elapsed=$((elapsed + 5))
    done

    log "${RED}✗ $service failed to respond correctly${NC}"
    if [ -n "$content_pattern" ]; then
        log "${RED}Expected status code $expected_code (got $http_code) and content pattern '$content_pattern'${NC}"
        log "${YELLOW}Last response content: ${content:0:200}...${NC}"
    else
        log "${RED}Expected status code $expected_code (got $http_code)${NC}"
    fi
    return 1
}

verify_mongodb() {
    log "${YELLOW}Verifying MongoDB...${NC}"
    
    # Check if MongoDB container is running
    if ! docker-compose ps mongodb | grep -q "Up"; then
        log "${RED}✗ MongoDB container is not running${NC}"
        docker-compose logs --tail=20 mongodb
        return 1
    fi
    
    # Give MongoDB more time to initialize
    log "${YELLOW}Waiting for MongoDB to initialize (15s)...${NC}"
    sleep 15
    
    # Try to connect to MongoDB using mongosh with authentication
    log "${YELLOW}Attempting to connect with credentials...${NC}"
    if ! docker-compose exec -T mongodb mongosh \
        "mongodb://${MONGO_INITDB_ROOT_USERNAME}:${MONGO_INITDB_ROOT_PASSWORD}@localhost:27017/admin" \
        --quiet \
        --eval 'try { db.runCommand({ ping: 1 }) } catch(e) { print(e); }'; then
        
        log "${RED}✗ MongoDB connection failed${NC}"
        log "${YELLOW}Checking MongoDB status...${NC}"
        
        # Check if authentication is enabled
        log "${YELLOW}Checking MongoDB configuration...${NC}"
        docker-compose exec -T mongodb ps aux | grep mongod
        
        # Try to connect without authentication as a test
        log "${YELLOW}Attempting connection without auth...${NC}"
        if docker-compose exec -T mongodb mongosh \
            --quiet \
            --eval 'try { db.runCommand({ ping: 1 }) } catch(e) { print(e) }'; then
            log "${YELLOW}MongoDB responds without authentication${NC}"
            log "${RED}✗ Authentication may not be properly configured${NC}"
            
            # Show current users
            log "${YELLOW}Checking MongoDB users...${NC}"
            docker-compose exec -T mongodb mongosh \
                --quiet \
                --eval 'try { db.getSiblingDB("admin").getUsers() } catch(e) { print(e) }'
        else
            log "${RED}✗ MongoDB is not responding at all${NC}"
            log "${YELLOW}Recent MongoDB logs:${NC}"
            docker-compose logs --tail=50 mongodb
        fi
        
        return 1
    fi
    
    log "${GREEN}✓ MongoDB is healthy${NC}"
    return 0
}

verify_postgres() {
    log "${YELLOW}Verifying PostgreSQL...${NC}"
    
    # Check if PostgreSQL container is running
    if ! docker-compose ps postgres | grep -q "Up"; then
        log "${RED}✗ PostgreSQL container is not running${NC}"
        return 1
    fi
    
    # Try to connect to PostgreSQL
    if ! docker-compose exec -T postgres pg_isready -U postgres; then
        log "${RED}✗ PostgreSQL is not responding${NC}"
        return 1
    fi
    
    # Check if Keycloak database exists
    if ! docker-compose exec -T postgres psql -U postgres -lqt | cut -d \| -f 1 | grep -qw keycloak; then
        log "${RED}✗ Keycloak database does not exist in PostgreSQL${NC}"
        return 1
    fi
    
    log "${GREEN}✓ PostgreSQL is healthy${NC}"
    return 0
}

verify_keycloak() {
    log "${YELLOW}Verifying Keycloak...${NC}"
    
    # Check if Keycloak container is running
    if ! docker-compose ps keycloak | grep -q "Up"; then
        log "${RED}✗ Keycloak container is not running${NC}"
        docker-compose logs --tail=20 keycloak
        return 1
    fi
    
    # Give Keycloak time to initialize
    log "${YELLOW}Waiting for Keycloak to initialize...${NC}"
    
    local timeout=90
    local interval=5
    local elapsed=0
    
    while [ $elapsed -lt $timeout ]; do
        # Try both with and without /auth prefix as per docker-compose.yml configuration
        if curl -s -f "http://localhost:8080/auth/health/ready" > /dev/null 2>&1; then
            log "${GREEN}✓ Keycloak is healthy (using /auth prefix)${NC}"
            return 0
        elif curl -s -f "http://localhost:8080/health/ready" > /dev/null 2>&1; then
            log "${GREEN}✓ Keycloak is healthy (without /auth prefix)${NC}"
            return 0
        elif curl -s -f "http://localhost:8080/auth/realms/master" > /dev/null 2>&1; then
            log "${GREEN}✓ Keycloak is healthy (master realm accessible)${NC}"
            return 0
        elif curl -s -f "http://localhost:8080/realms/master" > /dev/null 2>&1; then
            log "${GREEN}✓ Keycloak is healthy (master realm accessible, no /auth)${NC}"
            return 0
        fi
        
        log "${YELLOW}Waiting for Keycloak to be ready... (${elapsed}s/${timeout}s)${NC}"
        sleep $interval
        elapsed=$((elapsed + interval))
        
        # Show logs periodically during the wait
        if [ $((elapsed % 20)) -eq 0 ]; then
            log "${YELLOW}Recent Keycloak logs:${NC}"
            docker-compose logs --tail=20 keycloak
        fi
    done
    
    log "${RED}✗ Keycloak failed to become ready within ${timeout} seconds${NC}"
    log "${YELLOW}Final Keycloak logs:${NC}"
    docker-compose logs --tail=50 keycloak
    return 1
}

verify_kong() {
    log "${YELLOW}Verifying Kong...${NC}"
    
    # Check if Kong container is running
    if ! docker-compose ps kong | grep -q "Up"; then
        log "${RED}✗ Kong container is not running${NC}"
        docker-compose logs --tail=20 kong
        return 1
    fi
    
    # Check Kong migration status
    local migration_output=$(docker-compose logs kong-migration)
    if echo "$migration_output" | grep -q "Database is up-to-date"; then
        log "${GREEN}✓ Kong migration completed successfully${NC}"
    else
        log "${RED}✗ Kong database migration status unclear${NC}"
        docker-compose logs --tail=20 kong-migration
        return 1
    fi

    # Give Kong time to initialize
    log "${YELLOW}Waiting for Kong to initialize...${NC}"
    local timeout=45
    local elapsed=0
    local interval=5

    while [ $elapsed -lt $timeout ]; do
        # Use kong health command to check status
        if docker-compose exec -T kong kong health > /dev/null 2>&1; then
            log "${GREEN}✓ Kong is healthy${NC}"
            return 0
        fi
        
        log "${YELLOW}Waiting for Kong to be ready... (${elapsed}s/${timeout}s)${NC}"
        sleep $interval
        elapsed=$((elapsed + interval))
        
        # Show logs periodically during the wait
        if [ $((elapsed % 15)) -eq 0 ]; then
            log "${YELLOW}Recent Kong logs:${NC}"
            docker-compose logs --tail=20 kong
        fi
    done
    
    log "${RED}✗ Kong failed to become ready within ${timeout} seconds${NC}"
    log "${YELLOW}Final Kong status:${NC}"
    docker-compose exec -T kong kong health || true
    log "${YELLOW}Final Kong logs:${NC}"
    docker-compose logs --tail=50 kong
    return 1
}

verify_nginx() {
    log "${YELLOW}Verifying Nginx...${NC}"
    
    # Check if Nginx container is running
    if ! docker-compose ps nginx | grep -q "Up"; then
        log "${RED}✗ Nginx container is not running${NC}"
        docker-compose logs --tail=20 nginx
        return 1
    fi

    # First check HTTPS (primary protocol)
    local https_response=$(curl -sk -I https://localhost 2>&1)
    if echo "$https_response" | grep -q "HTTP/1.[01] [23]"; then
        log "${GREEN}✓ Nginx is responding correctly on HTTPS${NC}"
        return 0
    fi

    # If HTTPS failed, check HTTP with redirect
    local http_response=$(curl -sI -L http://localhost 2>&1)
    if echo "$http_response" | grep -q "HTTP/1.[01] [23]"; then
        if echo "$http_response" | grep -q "Location: https://"; then
            log "${GREEN}✓ Nginx is correctly redirecting HTTP to HTTPS${NC}"
            return 0
        fi
        log "${GREEN}✓ Nginx is responding correctly on HTTP${NC}"
        return 0
    fi

    # If both checks failed, show detailed error
    log "${RED}✗ Nginx is not responding correctly${NC}"
    log "${YELLOW}HTTPS Response:${NC}"
    echo "$https_response"
    log "${YELLOW}HTTP Response:${NC}"
    echo "$http_response"
    log "${YELLOW}Nginx logs:${NC}"
    docker-compose logs --tail=20 nginx
    return 1
}

verify_ldap() {
    log "${YELLOW}Verifying OpenLDAP...${NC}"
    
    # Check if OpenLDAP container is running
    if ! docker-compose ps openldap | grep -q "Up"; then
        log "${RED}✗ OpenLDAP container is not running${NC}"
        return 1
    fi
    
    # Check if phpLDAPadmin container is running
    if ! docker-compose ps phpldapadmin | grep -q "Up"; then
        log "${RED}✗ phpLDAPadmin container is not running${NC}"
        return 1
    fi
    
    log "${GREEN}✓ LDAP services are healthy${NC}"
    return 0
}

verify_monitoring() {
    log "${YELLOW}Verifying monitoring services...${NC}"
    
    # Check if Prometheus container is running
    if ! docker-compose ps prometheus | grep -q "Up"; then
        log "${RED}✗ Prometheus container is not running${NC}"
        docker-compose logs --tail=20 prometheus
        return 1
    fi

    # Give Prometheus time to initialize
    local timeout=30
    local elapsed=0
    local interval=5

    while [ $elapsed -lt $timeout ]; do
        # Check Prometheus API health
        if curl -s "http://localhost:9090/-/healthy" | grep -q "Prometheus Server is Healthy"; then
            # Verify targets are being scraped
            local targets_output=$(curl -s "http://localhost:9090/api/v1/targets" | grep -o '"health":"up"' | wc -l)
            if [ "$targets_output" -gt 0 ]; then
                log "${GREEN}✓ Prometheus is healthy and scraping targets${NC}"
                
                # Check if Grafana is running (if configured)
                if docker-compose ps grafana | grep -q "Up"; then
                    # Use admin credentials from environment variable (fallback to admin:admin if not set)
                    local grafana_pass="${GRAFANA_ADMIN_PASSWORD:-admin}"
                    # Try multiple health endpoints with proper credentials
                    if curl -s -f -u "admin:${grafana_pass}" "http://localhost:3000/api/health" > /dev/null; then
                        log "${GREEN}✓ Grafana is healthy (using /api/health)${NC}"
                    elif curl -s -f "http://localhost:3000/healthz" > /dev/null; then
                        log "${GREEN}✓ Grafana is healthy (using /healthz)${NC}"
                    elif curl -s -f -u "admin:${grafana_pass}" "http://localhost:3000/api/health/db" > /dev/null; then
                        log "${GREEN}✓ Grafana is healthy (using /api/health/db)${NC}"
                    elif curl -s -o /dev/null -w "%{http_code}" "http://localhost:3000" | grep -q -E "200|302"; then
                        log "${GREEN}✓ Grafana is responsive (returns HTTP 200/302)${NC}"
                    else
                        # Wait a bit more for Grafana to initialize if needed
                        sleep 5
                        # Final check with status code output for debugging
                        local status_code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:3000")
                        if [[ "$status_code" =~ ^(200|302)$ ]]; then
                            log "${GREEN}✓ Grafana is responsive after delay (HTTP $status_code)${NC}"
                        else
                            log "${YELLOW}Warning: Grafana is running but health check failed (HTTP $status_code)${NC}"
                            log "${YELLOW}Grafana logs:${NC}"
                            docker-compose logs --tail=20 grafana
                        fi
                    fi
                fi
                
                return 0
            else
                log "${YELLOW}Prometheus is running but no targets are up${NC}"
            fi
        fi
        
        log "${YELLOW}Waiting for Prometheus to be ready... (${elapsed}s/${timeout}s)${NC}"
        sleep $interval
        elapsed=$((elapsed + interval))
        
        # Show logs periodically during the wait
        if [ $((elapsed % 15)) -eq 0 ]; then
            log "${YELLOW}Recent Prometheus logs:${NC}"
            docker-compose logs --tail=20 prometheus
        fi
    done
    
    log "${RED}✗ Prometheus API is not responding correctly${NC}"
    log "${YELLOW}Prometheus configuration:${NC}"
    docker-compose exec -T prometheus cat /etc/prometheus/prometheus.yml || true
    log "${YELLOW}Prometheus targets:${NC}"
    curl -s "http://localhost:9090/api/v1/targets" || true
    log "${YELLOW}Final Prometheus logs:${NC}"
    docker-compose logs --tail=50 prometheus
    return 1
}

main() {
    log "Starting deployment verification for ${NODE_ENV:-development} environment"

    # Check dependencies first
    check_dependencies || exit 1
    
    # Verify environment and configuration
    verify_env || exit 1
    verify_certificates || exit 1
    verify_docker || exit 1
    verify_services || exit 1
    verify_network || exit 1
    verify_ports || exit 1
    verify_files || exit 1
    verify_permissions || exit 1
    
    # Verify individual services
    verify_mongodb || exit 1
    verify_postgres || exit 1
    verify_keycloak || exit 1
    verify_kong || exit 1
    verify_service "API" "3000" "/health" 30 200 '"status":"ok"' || exit 1
    verify_service "Frontend" "3002" "/" 30 200 "<html" || exit 1
    verify_nginx || exit 1
    verify_ldap || exit 1
    verify_monitoring || exit 1

    log "${GREEN}All verifications passed successfully!${NC}"
}

# Run main function
main "$@"