import Keycloak, { KeycloakInstance } from 'keycloak-js';

class KeycloakService {
    private keycloak: KeycloakInstance | null = null;
    private initialized = false;
    private static instance: KeycloakService;

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
                flow: 'standard'
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

    private setupTokenRefresh(): void {
        if (!this.keycloak) return;

        this.keycloak.onTokenExpired = () => {
            this.keycloak?.updateToken(70)
                .catch(() => {
                    console.warn('Failed to refresh token, logging out...');
                    this.logout();
                });
        };
    }

    public async login(): Promise<void> {
        await this.keycloak?.login({
            redirectUri: window.location.origin + '/api-docs'
        });
    }

    public async logout(): Promise<void> {
        await this.keycloak?.logout({
            redirectUri: window.location.origin
        });
    }

    public getToken(): string | undefined {
        return this.keycloak?.token;
    }
}

export default KeycloakService.getInstance(); 