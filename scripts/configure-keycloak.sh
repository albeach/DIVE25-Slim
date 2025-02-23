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

TOKEN=$(echo $TOKEN_RESPONSE | jq -r '.access_token')

if [ "$TOKEN" = "null" ] || [ -z "$TOKEN" ]; then
    echo "Failed to get admin token. Response: $TOKEN_RESPONSE"
    exit 1
fi

echo "Successfully obtained admin token"

# Configure the client
echo "Configuring dive25-frontend client..."
CLIENT_ID="dive25-frontend"

# Create test user in dive25 realm
echo "Creating test user in dive25 realm..."
USER_CONFIG='{
  "username": "testuser",
  "enabled": true,
  "emailVerified": true,
  "firstName": "Test",
  "lastName": "User",
  "email": "testuser@dive25.local",
  "credentials": [{
    "type": "password",
    "value": "testpassword123",
    "temporary": false
  }],
  "realmRoles": ["user"]
}'

# Create user
CREATE_USER_RESPONSE=$(curl -s -X POST "http://localhost:8080/admin/realms/dive25/users" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "$USER_CONFIG")

echo "User creation response: $CREATE_USER_RESPONSE"

# Rest of your existing client configuration code...
CLIENT_CONFIG='{
  "clientId": "'$CLIENT_ID'",
  "enabled": true,
  "publicClient": true,
  "standardFlowEnabled": true,
  "implicitFlowEnabled": false,
  "directAccessGrantsEnabled": true,
  "serviceAccountsEnabled": false,
  "redirectUris": [
    "http://localhost:3002/*",
    "http://localhost:3002/silent-check-sso.html"
  ],
  "webOrigins": ["+"],
  "rootUrl": "http://localhost:3002",
  "baseUrl": "/",
  "adminUrl": "http://localhost:3002",
  "protocol": "openid-connect",
  "attributes": {
    "pkce.code.challenge.method": "S256",
    "post.logout.redirect.uris": "http://localhost:3002/*"
  }
}'

# Check if client exists and update/create as before...
CLIENTS_RESPONSE=$(curl -s -H "Authorization: Bearer $TOKEN" \
  "http://localhost:8080/admin/realms/dive25/clients")

CLIENT_UUID=$(echo $CLIENTS_RESPONSE | jq -r '.[] | select(.clientId=="'$CLIENT_ID'") | .id')

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

echo "Configuration complete!"
echo ""
echo "You can now log in with:"
echo "Username: testuser"
echo "Password: testpassword123" 