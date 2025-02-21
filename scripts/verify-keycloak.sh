#!/bin/bash

# Wait for Keycloak to be ready
wait_for_keycloak() {
    echo "Waiting for Keycloak to be ready..."
    timeout=300
    while [ $timeout -gt 0 ]; do
        if curl -s -f "http://localhost:8080/health/ready" > /dev/null; then
            echo "Keycloak is ready!"
            return 0
        fi
        echo "Waiting for Keycloak... ($timeout seconds left)"
        sleep 5
        timeout=$((timeout-5))
    done
    echo "Timeout waiting for Keycloak"
    return 1
}

# Verify realm exists
verify_realm() {
    echo "Verifying realm 'dive25' exists..."
    response=$(curl -s -X GET \
        -H "Authorization: Bearer $TOKEN" \
        "http://localhost:8080/admin/realms/dive25")
    
    if [[ $response != *"error"* ]]; then
        echo "Realm verification successful!"
        return 0
    else
        echo "Realm verification failed!"
        return 1
    fi
}

# Main verification process
main() {
    if ! wait_for_keycloak; then
        exit 1
    fi

    # Get admin token
    echo "Getting admin token..."
    TOKEN=$(curl -s -X POST "http://localhost:8080/realms/master/protocol/openid-connect/token" \
        -d "client_id=admin-cli" \
        -d "username=admin" \
        -d "password=admin" \
        -d "grant_type=password" | jq -r '.access_token')

    if [ -z "$TOKEN" ]; then
        echo "Failed to get admin token"
        exit 1
    fi

    if ! verify_realm; then
        exit 1
    fi

    echo "Keycloak verification completed successfully!"
}

main 