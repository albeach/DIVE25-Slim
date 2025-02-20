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

main() {
    log "Starting deployment verification"
    
    verify_env
    verify_certificates
    verify_docker
    verify_services
    verify_network
    verify_ports
    verify_files
    verify_permissions
    
    read -p "All verifications passed. Proceed with deployment? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        deploy
        log "${GREEN}MVP deployment completed successfully!${NC}"
        log "${YELLOW}Access the application at https://dive25.com${NC}"
        log "${YELLOW}Grafana dashboard: https://dive25.com:3001${NC}"
    else
        log "${YELLOW}Deployment cancelled${NC}"
    fi
}

# Run main function
main "$@"