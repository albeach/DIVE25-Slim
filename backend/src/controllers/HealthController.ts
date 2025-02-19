// /backend/src/controllers/HealthController.ts
import { Request, Response } from 'express';
import { DatabaseService } from '../services/DatabaseService';
import { MetricsService } from '../services/MetricsService';

export class HealthController {
    private static instance: HealthController;
    private readonly db: DatabaseService;
    private readonly metrics: MetricsService;

    private constructor() {
        this.db = DatabaseService.getInstance();
        this.metrics = MetricsService.getInstance();
    }

    public static getInstance(): HealthController {
        if (!HealthController.instance) {
            HealthController.instance = new HealthController();
        }
        return HealthController.instance;
    }

    public async checkHealth(req: Request, res: Response): Promise<void> {
        try {
            // Check database connection
            await this.db.getDb().command({ ping: 1 });

            // Get basic metrics
            const metrics = {
                activeConnections: await this.metrics.getActiveConnections(),
                averageResponseTime: await this.metrics.calculateAverageResponseTime()
            };

            res.json({
                status: 'healthy',
                timestamp: new Date().toISOString(),
                version: process.env.npm_package_version,
                environment: process.env.NODE_ENV,
                metrics
            });
        } catch (error) {
            res.status(503).json({
                status: 'unhealthy',
                error: error.message,
                timestamp: new Date().toISOString()
            });
        }
    }
}

export default HealthController.getInstance();