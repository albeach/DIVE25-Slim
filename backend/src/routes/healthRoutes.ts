import { Router } from 'express';
import { DatabaseService } from '../services/DatabaseService';
import { LoggerService } from '../services/LoggerService';

export class HealthRoutes {
    private static instance: HealthRoutes;
    private readonly router: Router;
    private readonly db: DatabaseService;
    private readonly logger: LoggerService;

    private constructor() {
        this.router = Router();
        this.db = DatabaseService.getInstance();
        this.logger = LoggerService.getInstance();
        this.initializeRoutes();
    }

    public static getInstance(): HealthRoutes {
        if (!HealthRoutes.instance) {
            HealthRoutes.instance = new HealthRoutes();
        }
        return HealthRoutes.instance;
    }

    private initializeRoutes(): void {
        this.router.get('/', async (req, res) => {
            try {
                await this.db.getDb().command({ ping: 1 });
                res.json({
                    status: 'healthy',
                    timestamp: new Date().toISOString(),
                    version: process.env.npm_package_version,
                    environment: process.env.NODE_ENV
                });
            } catch (error) {
                this.logger.error('Health check failed:', error);
                res.status(500).json({
                    status: 'unhealthy',
                    error: error.message
                });
            }
        });
    }

    public getRouter(): Router {
        return this.router;
    }
}

export const healthRoutes = HealthRoutes.getInstance();
export default HealthRoutes;