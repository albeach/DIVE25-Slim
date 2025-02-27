import Keycloak, { KeycloakInstance } from 'keycloak-js';

class KeycloakService {
    private keycloak: KeycloakInstance | null = null;
    private initialized = false;

    public async initialize(): Promise<KeycloakInstance | null> {
        if (typeof window === 'undefined') return null;
        if (this.initialized) return this.keycloak;

        try {
            const keycloakConfig = {
                url: process.env.NEXT_PUBLIC_KEYCLOAK_URL || 'http://localhost:8080/auth',
                realm: 'dive25',
                clientId: 'dive25-frontend'
            };

            console.log('Initializing Keycloak with config:', keycloakConfig);
            this.keycloak = new Keycloak(keycloakConfig);

            // Add event listeners for debugging
            this.keycloak.onAuthSuccess = () => console.log('Auth Success');
            this.keycloak.onAuthError = (error) => console.log('Auth Error:', error);
            this.keycloak.onAuthRefreshSuccess = () => console.log('Auth Refresh Success');
            this.keycloak.onAuthRefreshError = () => console.log('Auth Refresh Error');
            this.keycloak.onTokenExpired = () => console.log('Token Expired');

            const authenticated = await this.keycloak.init({
                onLoad: 'check-sso',
                silentCheckSsoRedirectUri: window.location.origin + '/silent-check-sso.html',
                pkceMethod: 'S256',
                checkLoginIframe: false,
                checkLoginIframeInterval: 0,
                enableLogging: true,
                scope: 'openid',
                responseMode: 'fragment',
                redirectUri: window.location.origin
            });

            console.log('Keycloak initialization result:', authenticated);

            if (authenticated) {
                console.log('User is authenticated');
                this.setupTokenRefresh();
            } else {
                console.log('User is not authenticated');
            }

            this.initialized = true;
            return this.keycloak;
        } catch (error) {
            console.error('Failed to initialize Keycloak:', error);
            return null;
        }
    }

    public login(): void {
        console.log('Initiating login...');
        this.keycloak?.login({
            redirectUri: window.location.origin
        });
    }

    public logout(): void {
        console.log('Initiating logout...');
        this.keycloak?.logout({
            redirectUri: window.location.origin
        });
    }

    private setupTokenRefresh() {
        if (!this.keycloak) return;

        // Refresh token if it's valid for less than 70 seconds
        setInterval(() => {
            this.keycloak?.updateToken(70)
                .then((refreshed) => {
                    if (refreshed) {
                        console.log('Token refreshed');
                    }
                })
                .catch(() => {
                    console.log('Failed to refresh token, logging out...');
                    this.logout();
                });
        }, 60000);
    }

    public getToken(): string | undefined {
        return this.keycloak?.token;
    }

    public isAuthenticated(): boolean {
        return this.keycloak?.authenticated ?? false;
    }

    public getUsername(): string | undefined {
        return this.keycloak?.tokenParsed?.preferred_username;
    }
}

const keycloakService = new KeycloakService();
export default keycloakService; 