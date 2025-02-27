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

# Get the LDAP component ID
LDAP_ID="dive25-ldap"

# Add clearance mapper
echo "Adding clearance attribute mapper..."
curl -X POST http://keycloak:8080/admin/realms/dive25/user-storage/$LDAP_ID/mappers \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
        "name": "clearance",
        "providerId": "user-attribute-ldap-mapper",
        "providerType": "org.keycloak.storage.ldap.mappers.LDAPStorageMapper",
        "parentId": "dive25-ldap",
        "config": {
            "ldap.attribute": ["natoClearance"],
            "user.model.attribute": ["clearance"],
            "read.only": ["true"],
            "always.read.value.from.ldap": ["true"],
            "is.mandatory.in.ldap": ["false"]
        }
    }'

# Add COI mapper
echo "Adding COI mapper..."
curl -X POST http://keycloak:8080/admin/realms/dive25/user-storage/$LDAP_ID/mappers \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
        "name": "coiAccess",
        "providerId": "user-attribute-ldap-mapper",
        "providerType": "org.keycloak.storage.ldap.mappers.LDAPStorageMapper",
        "parentId": "dive25-ldap",
        "config": {
            "ldap.attribute": ["natoCoi"],
            "user.model.attribute": ["coiAccess"],
            "read.only": ["true"],
            "always.read.value.from.ldap": ["true"],
            "is.mandatory.in.ldap": ["false"],
            "is.binary.attribute": ["false"],
            "is.multivalued.attribute": ["true"]
        }
    }'

# Add releasable to mapper
echo "Adding releasableTo mapper..."
curl -X POST http://keycloak:8080/admin/realms/dive25/user-storage/$LDAP_ID/mappers \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
        "name": "releasableTo",
        "providerId": "user-attribute-ldap-mapper",
        "providerType": "org.keycloak.storage.ldap.mappers.LDAPStorageMapper",
        "parentId": "dive25-ldap",
        "config": {
            "ldap.attribute": ["natoReleasableTo"],
            "user.model.attribute": ["releasableTo"],
            "read.only": ["true"],
            "always.read.value.from.ldap": ["true"],
            "is.mandatory.in.ldap": ["false"],
            "is.binary.attribute": ["false"],
            "is.multivalued.attribute": ["true"]
        }
    }'

# Add role mapper for admin role based on clearance
echo "Adding role mapper..."
curl -X POST http://keycloak:8080/admin/realms/dive25/user-storage/$LDAP_ID/mappers \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
        "name": "admin-role-mapper",
        "providerId": "role-ldap-mapper",
        "providerType": "org.keycloak.storage.ldap.mappers.LDAPStorageMapper",
        "parentId": "dive25-ldap",
        "config": {
            "roles.dn": ["ou=security,ou=groups,dc=dive25,dc=local"],
            "membership.ldap.attribute": ["member"],
            "membership.attribute.type": ["DN"],
            "membership.user.ldap.attribute": ["uid"],
            "user.roles.retrieve.strategy": ["LOAD_ROLES_BY_MEMBER_ATTRIBUTE"],
            "role.name.ldap.attribute": ["cn"],
            "use.realm.roles.mapping": ["true"],
            "client.id": [""],
            "role.object.classes": ["groupOfNames"]
        }
    }'

# Trigger sync
echo "Triggering user sync..."
curl -X POST http://keycloak:8080/admin/realms/dive25/user-storage/$LDAP_ID/sync?action=triggerFullSync \
    -H "Authorization: Bearer $TOKEN"

echo "LDAP configuration complete!"