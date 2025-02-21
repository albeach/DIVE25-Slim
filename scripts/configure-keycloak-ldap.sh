#!/bin/bash
set -e

# Wait for Keycloak
until curl -s http://keycloak:8080/health/ready; do
    echo "Waiting for Keycloak..."
    sleep 2
done

# Get admin token
TOKEN=$(curl -X POST http://keycloak:8080/realms/master/protocol/openid-connect/token \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "username=admin" \
    -d "password=$KEYCLOAK_ADMIN_PASSWORD" \
    -d "grant_type=password" \
    -d "client_id=admin-cli" | jq -r '.access_token')

# Configure LDAP federation
curl -X POST http://keycloak:8080/admin/realms/dive25/user-storage \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d @/config/keycloak/ldap-federation.json

# Trigger sync
curl -X POST http://keycloak:8080/admin/realms/dive25/user-storage/dive25-ldap/sync?action=triggerFullSync \
    -H "Authorization: Bearer $TOKEN"