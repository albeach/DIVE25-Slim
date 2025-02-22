import Keycloak, { KeycloakInstance } from 'keycloak-js';

class KeycloakService {
    private static instance: KeycloakService;
    private keycloak: KeycloakInstance | null = null;
    private initialized = false;

    private constructor() { }

    public static getInstance(): KeycloakService {
        if (!KeycloakService.instance) {
            KeycloakService.instance = new KeycloakService();
        }
        return KeycloakService.instance;
    }

    public async initialize(): Promise<KeycloakInstance | null> {
        if (typeof window === 'undefined') return null;
        if (this.initialized) return this.keycloak;

        try {
            const keycloakConfig = {
                url: process.env.NEXT_PUBLIC_KEYCLOAK_URL || 'http://localhost:8080',
                realm: 'dive25',
                clientId: 'dive25-frontend',
                redirectUri: window.location.origin
            };

            this.keycloak = new Keycloak(keycloakConfig);
            await this.keycloak.init({
                onLoad: 'login-required',
                silentCheckSsoRedirectUri: window.location.origin + '/silent-check-sso.html',
                pkceMethod: 'S256',
                checkLoginIframe: false,
                enableLogging: true
            });

            this.initialized = true;
            return this.keycloak;
        } catch (error) {
            console.error('Failed to initialize Keycloak:', error);
            return null;
        }
    }

    public getKeycloak(): KeycloakInstance | null {
        return this.keycloak;
    }
}

export default KeycloakService.getInstance(); 