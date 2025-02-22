#!/bin/bash

# Load environment variables
source .env

# Wait for Keycloak to be ready
echo "Waiting for Keycloak to be ready..."
until curl -s http://localhost:8080 > /dev/null; do
    sleep 5
done

echo "Getting admin token..."
echo "Using admin credentials: ${KEYCLOAK_ADMIN} / ${KEYCLOAK_ADMIN_PASSWORD}"

# Get admin token with better error handling
TOKEN_RESPONSE=$(curl -s -X POST "http://localhost:8080/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=admin-cli" \
  -d "username=${KEYCLOAK_ADMIN}" \
  -d "password=${KEYCLOAK_ADMIN_PASSWORD}" \
  -d "grant_type=password")

echo "Token response: $TOKEN_RESPONSE"

TOKEN=$(echo $TOKEN_RESPONSE | jq -r '.access_token')

if [ "$TOKEN" = "null" ] || [ -z "$TOKEN" ]; then
    echo "Failed to get admin token. Response: $TOKEN_RESPONSE"
    exit 1
fi

echo "Successfully obtained admin token"

# Configure the client
echo "Configuring dive25-frontend client..."
CLIENT_ID="dive25-frontend"

# Check if client exists
CLIENTS_RESPONSE=$(curl -s -H "Authorization: Bearer $TOKEN" \
  "http://localhost:8080/admin/realms/dive25/clients")

echo "Clients response: $CLIENTS_RESPONSE"

CLIENT_UUID=$(echo $CLIENTS_RESPONSE | jq -r '.[] | select(.clientId=="'$CLIENT_ID'") | .id')

# Client configuration
CLIENT_CONFIG='{
  "clientId": "'$CLIENT_ID'",
  "enabled": true,
  "publicClient": true,
  "standardFlowEnabled": true,
  "implicitFlowEnabled": false,
  "directAccessGrantsEnabled": true,
  "serviceAccountsEnabled": false,
  "redirectUris": ["http://localhost:3002/*"],
  "webOrigins": ["http://localhost:3002"],
  "rootUrl": "http://localhost:3002",
  "baseUrl": "/",
  "adminUrl": "http://localhost:3002",
  "protocol": "openid-connect",
  "attributes": {
    "pkce.code.challenge.method": "S256"
  }
}'

if [ -n "$CLIENT_UUID" ]; then
    echo "Updating existing client with UUID: $CLIENT_UUID"
    UPDATE_RESPONSE=$(curl -s -X PUT "http://localhost:8080/admin/realms/dive25/clients/$CLIENT_UUID" \
      -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/json" \
      -d "$CLIENT_CONFIG")
    echo "Update response: $UPDATE_RESPONSE"
else
    echo "Creating new client..."
    CREATE_RESPONSE=$(curl -s -X POST "http://localhost:8080/admin/realms/dive25/clients" \
      -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/json" \
      -d "$CLIENT_CONFIG")
    echo "Create response: $CREATE_RESPONSE"
fi

echo "Keycloak client configuration complete!" 