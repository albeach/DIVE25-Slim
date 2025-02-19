#!/bin/bash
# scripts/setup.sh

# Exit on any error
set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Print with timestamp
log() {
    echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] ${1}"
}

# Check for required tools
check_prerequisites() {
    log "${YELLOW}Checking prerequisites...${NC}"
    
    command -v docker >/dev/null 2>&1 || { 
        log "${RED}Docker is required but not installed.${NC}" 
        exit 1
    }
    
    command -v docker-compose >/dev/null 2>&1 || {
        log "${RED}Docker Compose is required but not installed.${NC}"
        exit 1
    }
}

# Generate secure random string
generate_secure_string() {
    openssl rand -base64 32 | tr -d '/+=' | cut -c1-32
}

# Set up environment variables
setup_environment() {
    log "${YELLOW}Setting up environment variables...${NC}"
    
    if [ ! -f .env ]; then
        cp .env.template .env
        
        # Generate secure passwords and keys
        sed -i "s/MONGO_ROOT_PASSWORD=.*/MONGO_ROOT_PASSWORD=$(generate_secure_string)/" .env
        sed -i "s/KEYCLOAK_ADMIN_PASSWORD=.*/KEYCLOAK_ADMIN_PASSWORD=$(generate_secure_string)/" .env
        sed -i "s/JWT_SECRET=.*/JWT_SECRET=$(generate_secure_string)/" .env
        sed -i "s/API_KEY=.*/API_KEY=$(generate_secure_string)/" .env
        
        log "${GREEN}Environment file created with secure credentials${NC}"
    else
        log "${YELLOW}Environment file already exists, skipping...${NC}"
    fi
}

# Import SSL certificates
import_certificates() {
    log "${YELLOW}Importing SSL certificates...${NC}"
    
    CERT_DIR="certificates/prod"
    mkdir -p $CERT_DIR
    
    # Check if certificates exist in common locations
    COMMON_LOCATIONS=(
        "/etc/letsencrypt/live/dive25.com"
        "/etc/ssl/dive25.com"
    )
    
    for location in "${COMMON_LOCATIONS[@]}"; do
        if [ -f "$location/fullchain.pem" ] && [ -f "$location/privkey.pem" ]; then
            cp "$location/fullchain.pem" "$CERT_DIR/"
            cp "$location/privkey.pem" "$CERT_DIR/"
            log "${GREEN}Certificates imported from $location${NC}"
            return 0
        fi
    done
    
    log "${RED}No certificates found in common locations${NC}"
    log "${YELLOW}Please place your SSL certificates in $CERT_DIR${NC}"
    exit 1
}

# Initialize MongoDB
init_mongodb() {
    log "${YELLOW}Initializing MongoDB...${NC}"
    
    # Wait for MongoDB to be ready
    until docker-compose exec -T mongodb mongosh --eval "db.adminCommand('ping')" >/dev/null 2>&1; do
        log "Waiting for MongoDB to be ready..."
        sleep 2
    done
    
    # Create initial collections and indexes
    docker-compose exec -T mongodb mongosh \
        --file /docker-entrypoint-initdb.d/init-db.js
    
    log "${GREEN}MongoDB initialized successfully${NC}"
}

# Import Keycloak users
import_users() {
    log "${YELLOW}Importing users to Keycloak...${NC}"
    
    # Wait for Keycloak to be ready
    until curl -s http://localhost:8080/auth/health >/dev/null; do
        log "Waiting for Keycloak to be ready..."
        sleep 5
    done
    
    # Import realm and users
    docker-compose exec -T keycloak /opt/jboss/keycloak/bin/standalone.sh \
        -Djboss.socket.binding.port-offset=100 -Dkeycloak.migration.action=import \
        -Dkeycloak.migration.provider=singleFile \
        -Dkeycloak.migration.file=/config/realm-export.json \
        -Dkeycloak.migration.strategy=OVERWRITE_EXISTING
    
    log "${GREEN}Keycloak users imported successfully${NC}"
}

# Main setup function
main() {
    log "${YELLOW}Starting DIVE25 MVP setup...${NC}"
    
    check_prerequisites
    setup_environment
    import_certificates
    
    log "${YELLOW}Starting services...${NC}"
    docker-compose -f docker-compose.production.yml up -d
    
    init_mongodb
    import_users
    
    log "${GREEN}DIVE25 MVP setup completed successfully!${NC}"
    log "${YELLOW}Access the application at https://dive25.com${NC}"
    log "${YELLOW}Grafana dashboard: https://dive25.com:3001${NC}"
    log "${YELLOW}Admin credentials can be found in .env${NC}"
}

# Run main function
main "$@"