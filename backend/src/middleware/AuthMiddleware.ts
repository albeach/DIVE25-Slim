// src/middleware/AuthMiddleware.ts
// Add to existing imports:
import jwt from 'jsonwebtoken';
import jwksClient from 'jwks-rsa';

export class AuthMiddleware {
    private readonly jwksClient: jwksClient.JwksClient;

    constructor() {
        // Initialize existing services...

        // Add JWKS client for Keycloak token verification
        this.jwksClient = jwksClient({
            jwksUri: `${config.keycloak.baseUrl}/realms/${config.keycloak.realm}/protocol/openid-connect/certs`,
            cache: true,
            rateLimit: true,
        });
    }

    private async getSigningKey(kid: string): Promise<string> {
        try {
            const key = await this.jwksClient.getSigningKey(kid);
            return key.getPublicKey();
        } catch (error) {
            this.logger.error('Failed to get signing key:', error);
            throw this.createAuthError(
                'Invalid token signature',
                401,
                'AUTH011'
            );
        }
    }

    public authenticate: RequestHandler = async (
        req: Request,
        res: Response,
        next: NextFunction
    ): Promise<void> => {
        const startTime = Date.now();

        try {
            // Get token from Kong-proxied header
            const token = req.headers['x-access-token'] || req.headers.authorization?.split(' ')[1];

            if (!token) {
                throw this.createAuthError('No token provided', 401, 'AUTH001');
            }

            // Decode token to get key ID
            const decoded = jwt.decode(token, { complete: true });
            if (!decoded || !decoded.header.kid) {
                throw this.createAuthError('Invalid token format', 401, 'AUTH012');
            }

            // Get public key and verify token
            const publicKey = await this.getSigningKey(decoded.header.kid);
            const verified = jwt.verify(token, publicKey, {
                algorithms: ['RS256'],
                audience: config.keycloak.clientId,
                issuer: `${config.keycloak.baseUrl}/realms/${config.keycloak.realm}`
            });

            // Extract user attributes from verified token
            const userAttributes = this.extractUserAttributes(verified);

            // Validate security attributes
            await this.validateSecurityAttributes(userAttributes);

            // Add user attributes to request
            (req as AuthenticatedRequest).userAttributes = userAttributes;

            // Record metrics
            await this.metrics.recordOperationMetrics('authentication', {
                duration: Date.now() - startTime,
                success: true
            });

            next();
        } catch (error) {
            const authError = asAuthError(error);

            // Record failed authentication metric
            await this.metrics.recordOperationMetrics('authentication_failure', {
                duration: Date.now() - startTime,
                error: authError.code
            });

            res.status(authError.statusCode).json({
                error: authError.message,
                code: authError.code
            });
        }
    };

    private extractUserAttributes(token: any): UserAttributes {
        return {
            uniqueIdentifier: token.sub,
            clearance: token.clearance,
            countryOfAffiliation: token.country,
            coiTags: token.coiTags,
            lacvCode: token.lacvCode,
            organizationalAffiliation: token.organization
        };
    }
}