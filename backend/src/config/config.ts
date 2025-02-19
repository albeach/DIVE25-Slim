// src/config/config.ts - Add to existing config
export const config = {
    // ... existing config ...
    keycloak: {
        realm: 'dive25',
        baseUrl: process.env.KEYCLOAK_URL || 'http://keycloak:8080',
        clientId: process.env.KEYCLOAK_CLIENT_ID || 'dive25-api',
        tokenEndpoint: '/realms/dive25/protocol/openid-connect/token',
        jwksEndpoint: '/realms/dive25/protocol/openid-connect/certs'
    }
};