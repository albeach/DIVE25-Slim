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
                clientId: 'dive25-frontend'
            };

            this.keycloak = new Keycloak(keycloakConfig);

            const authenticated = await this.keycloak.init({
                onLoad: 'check-sso',
                silentCheckSsoRedirectUri: window.location.origin + '/silent-check-sso.html',
                pkceMethod: 'S256',
                checkLoginIframe: false,
                flow: 'standard'  // Use standard flow
            });

            // Set up token refresh
            if (authenticated) {
                this.setupTokenRefresh();
            }

            this.initialized = true;
            return this.keycloak;
        } catch (error) {
            console.error('Failed to initialize Keycloak:', error);
            return null;
        }
    }

    private setupTokenRefresh() {
        if (!this.keycloak) return;

        // Refresh token 1 minute before it expires
        setInterval(() => {
            this.keycloak?.updateToken(70)
                .catch(() => {
                    console.log('Failed to refresh token, logging out...');
                    this.keycloak?.logout();
                });
        }, 60000);
    }

    public getKeycloak(): KeycloakInstance | null {
        return this.keycloak;
    }

    public login(): void {
        this.keycloak?.login({
            redirectUri: window.location.origin
        });
    }

    public logout(): void {
        this.keycloak?.logout({
            redirectUri: window.location.origin
        });
    }
}

export default KeycloakService.getInstance(); 