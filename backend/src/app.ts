// /backend/src/app.ts
import express from 'express';
import cors from 'cors';
import { securityHeaders } from './middleware/securityHeaders';
import { errorHandler } from './middleware/errorHandler';
import { documentRoutes } from './routes/documentRoutes';
import { healthRoutes } from './routes/healthRoutes';
import { MetricsService } from './services/MetricsService';
import { LoggerService } from './services/LoggerService';

export class App {
    private static instance: App;
    private readonly app: express.Application;
    private readonly metrics: MetricsService;
    private readonly logger: LoggerService;

    private constructor() {
        this.app = express();
        this.metrics = MetricsService.getInstance();
        this.logger = LoggerService.getInstance();
        this.initializeMiddleware();
        this.initializeRoutes();
    }

    public static getInstance(): App {
        if (!App.instance) {
            App.instance = new App();
        }
        return App.instance;
    }

    private initializeMiddleware(): void {
        // Basic middleware
        this.app.use(express.json());
        this.app.use(express.urlencoded({ extended: true }));

        // Security
        this.app.use(cors({
            origin: process.env.FRONTEND_URL || 'http://localhost:3000',
            credentials: true
        }));
        this.app.use(securityHeaders);

        // Monitoring
        this.app.use((req, res, next) => {
            const startTime = Date.now();
            res.on('finish', () => {
                const duration = Date.now() - startTime;
                this.metrics.recordResponseTime(req.method, req.path, duration);
            });
            next();
        });
    }

    private initializeRoutes(): void {
        this.app.use('/api/health', healthRoutes.getRouter());
        this.app.use('/api/documents', documentRoutes.getRouter());

        // Error handling should be last
        this.app.use(errorHandler);
    }

    public getApp(): express.Application {
        return this.app;
    }
}

export default App.getInstance();