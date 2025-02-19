#!/bin/bash
# deploy-mvp.sh

# Exit on error
set -e

echo "Starting DIVE25 MVP Deployment..."

# 1. Ensure directories exist
mkdir -p kong prometheus certificates/prod

# 2. Check for SSL certificates
if [ ! -f "certificates/prod/fullchain.pem" ] || [ ! -f "certificates/prod/privkey.pem" ]; then
    echo "Error: SSL certificates not found in certificates/prod/"
    exit 1
fi

# 3. Start core services
echo "Starting core services..."
docker-compose -f docker-compose.production.yml up -d kong keycloak mongodb redis

# 4. Wait for databases and Keycloak to initialize
echo "Waiting for services to initialize..."
sleep 30

# 5. Start application
echo "Starting application services..."
docker-compose -f docker-compose.production.yml up -d api frontend

# 6. Basic health check
echo "Performing health check..."
curl -k https://localhost/api/health || {
    echo "Health check failed"
    exit 1
}

echo "DIVE25 MVP deployment completed successfully"
echo "Access the application at https://dive25.com"