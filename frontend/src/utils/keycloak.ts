import Keycloak from 'keycloak-js';

const keycloakConfig = {
    url: process.env.NEXT_PUBLIC_KEYCLOAK_URL,
    realm: 'dive25',  // make sure this matches your realm name
    clientId: 'dive25-frontend', // make sure this matches your client ID
};

const keycloak = new Keycloak(keycloakConfig);

export default keycloak; 