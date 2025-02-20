// /backend/src/app.ts
import express, { Application } from 'express';
import helmet from 'helmet';
import cors from 'cors';
import { v4 as uuid } from 'uuid';
import { LoggerService } from './services/LoggerService';
import { MetricsService } from './services/MetricsService';
import { securityHeaders } from './middleware/SecurityHeaders';
import { requestSanitizer } from './middleware/RequestSanitizer';
import { rateLimiter } from './middleware/RateLimiter';
import { errorHandler } from './middleware/ErrorHandler';
import { documentRoutes } from './routes/DocumentRoutes';

export class App {
    private static instance: App;
    private readonly app: Application;
    private readonly logger: LoggerService;
    private readonly metrics: MetricsService;

    private constructor() {
        this.app = express();
        this.logger = LoggerService.getInstance();
        this.metrics = MetricsService.getInstance();
        this.initializeMiddleware();
        this.initializeRoutes();
        this.initializeErrorHandling();
    }

    public static getInstance(): App {
        if (!App.instance) {
            App.instance = new App();
        }
        return App.instance;
    }

    private initializeMiddleware(): void {
        // Basic middleware
        this.app.use(express.json({ limit: '1mb' }));
        this.app.use(express.urlencoded({ extended: true, limit: '1mb' }));

        // Security middleware
        this.app.use(helmet({
            contentSecurityPolicy: {
                directives: {
                    defaultSrc: ["'self'"],
                    scriptSrc: ["'self'", "'unsafe-inline'"],
                    styleSrc: ["'self'", "'unsafe-inline'"],
                    imgSrc: ["'self'", 'data:', 'https:'],
                    connectSrc: ["'self'", process.env.FRONTEND_URL || 'http://localhost:3000']
                }
            }
        }));

        this.app.use(cors({
            origin: process.env.FRONTEND_URL || 'http://localhost:3000',
            credentials: true,
            methods: ['GET', 'POST', 'PUT', 'DELETE'],
            allowedHeaders: ['Content-Type', 'Authorization', 'x-request-id']
        }));

        this.app.use(securityHeaders);
        this.app.use(requestSanitizer.sanitizeRequest);

        // Rate limiting
        this.app.use('/api/documents', rateLimiter.getDocumentLimiter());
        this.app.use('/api/auth', rateLimiter.getAuthLimiter());

        // Request tracking
        this.app.use((req, res, next) => {
            const requestId = uuid();
            req.headers['x-request-id'] = requestId;

            const startTime = Date.now();
            res.on('finish', () => {
                const duration = Date.now() - startTime;
                const path = req.baseUrl + req.path;

                // Record metrics
                this.metrics.recordResponseTime(req.method, path, duration);
                if (res.statusCode >= 400) {
                    this.metrics.recordError(path, res.statusCode);
                }

                // Log request details
                this.logger.info('Request completed', {
                    requestId,
                    method: req.method,
                    path,
                    status: res.statusCode,
                    duration,
                    userAgent: req.headers['user-agent'],
                    ip: req.ip,
                    auth: req.headers.authorization ? 'present' : 'none'
                });
            });

            // Add request context
            res.locals.requestId = requestId;
            res.locals.startTime = startTime;

            next();
        });
    }

    private initializeRoutes(): void {
        this.app.use('/api/documents', documentRoutes.getRouter());
        // Add health check endpoint
        this.app.get('/health', (req, res) => {
            res.json({ status: 'healthy' });
        });
    }

    private initializeErrorHandling(): void {
        this.app.use(errorHandler.handleError);
    }

    public getApp(): Application {
        return this.app;
    }
}

export default App.getInstance();