#!/bin/bash
# scripts/cert-manager.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV="${NODE_ENV:-development}"

# Certificate directories
DEV_CERT_DIR="${PROJECT_ROOT}/certificates/dev"
PROD_CERT_DIR="${PROJECT_ROOT}/certificates/prod"
# Use tr for lowercase conversion instead of ${ENV,,}
ENV_LOWER=$(echo "$ENV" | tr '[:upper:]' '[:lower:]')
CERT_DIR=$([ "$ENV_LOWER" = "production" ] && echo "$PROD_CERT_DIR" || echo "$DEV_CERT_DIR")

# Create certificate directories if they don't exist
mkdir -p "$DEV_CERT_DIR" "$PROD_CERT_DIR"

check_cert_validity() {
    local cert_file="$1"
    if [ ! -f "$cert_file" ]; then
        echo "Certificate file not found: $cert_file"
        return 1
    fi

    # Check certificate expiration
    local end_date=$(openssl x509 -enddate -noout -in "$cert_file" | cut -d= -f2)
    local end_epoch=$(date -d "$end_date" +%s)
    local now_epoch=$(date +%s)
    local days_left=$(( ($end_epoch - $now_epoch) / 86400 ))

    if [ $days_left -lt 30 ]; then
        echo "WARNING: Certificate will expire in $days_left days"
        return 2
    fi
    
    return 0
}

setup_certificates() {
    local env=$1
    # Convert to lowercase using a more compatible approach
    env=$(echo "$env" | tr '[:upper:]' '[:lower:]')
    
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
    local env=$1
    
    # Get absolute paths for certificates
    CERT_PATH_ABS="$(cd "$(dirname "$CERT_PATH")" && pwd)/$(basename "$CERT_PATH")"
    KEY_PATH_ABS="$(cd "$(dirname "$KEY_PATH")" && pwd)/$(basename "$KEY_PATH")"
    
    # Create or update .env file with certificate paths
    echo "SSL_CERT_PATH=$CERT_PATH_ABS" > .env.ssl
    echo "SSL_KEY_PATH=$KEY_PATH_ABS" >> .env.ssl
    
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] Updated Docker configuration with certificate paths."
}

# Main function
main() {
    local env=${1:-""}
    
    # Setup certificates
    setup_certificates "$env"
    
    # Update Docker configuration
    update_docker_compose_config "$env"
}

# Run the main function with the provided environment
main "$1"