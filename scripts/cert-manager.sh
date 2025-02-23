#!/bin/bash
# scripts/cert-manager.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV="${NODE_ENV:-development}"

# Certificate directories
DEV_CERT_DIR="${PROJECT_ROOT}/certificates/dev"
PROD_CERT_DIR="${PROJECT_ROOT}/certificates/prod"
CERT_DIR="${ENV,,}" == "production" ? "$PROD_CERT_DIR" : "$DEV_CERT_DIR"

# Create certificate directories if they don't exist
mkdir -p "$DEV_CERT_DIR" "$PROD_CERT_DIR"

check_cert_validity() {
    local cert_file="$1"
    if [ ! -f "$cert_file" ]; then
        echo "Certificate file not found: $cert_file"
        return 1
    }

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
    local target_dir="$1"
    
    # For development, generate self-signed certificates if they don't exist
    if [ "${ENV,,}" == "development" ] && [ ! -f "$target_dir/fullchain.pem" ]; then
        echo "Generating self-signed certificates for development..."
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout "$target_dir/privkey.pem" \
            -out "$target_dir/fullchain.pem" \
            -subj "/CN=localhost/O=DIVE25 Development"
    fi

    # Verify certificates
    if check_cert_validity "$target_dir/fullchain.pem"; then
        echo "Certificates validated successfully"
    else
        echo "Certificate validation failed"
        return 1
    fi

    # Update Kong and nginx configurations with correct paths
    sed -i "s|ssl_certificate .*|ssl_certificate $target_dir/fullchain.pem;|" \
        "${PROJECT_ROOT}/nginx/conf.d/default.conf"
    
    sed -i "s|\"ssl_cert\": \".*\"|\"ssl_cert\": \"$target_dir/fullchain.pem\"|" \
        "${PROJECT_ROOT}/kong/declarative/kong.yml"
}

main() {
    echo "Setting up certificates for ${ENV} environment..."
    setup_certificates "$CERT_DIR"
}

main "$@"