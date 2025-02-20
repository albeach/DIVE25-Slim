import { Router } from 'express';
import { asyncHandler } from '../middleware/asyncHandler';
import HealthController from '../controllers/HealthController';
import ReadinessController from '../controllers/ReadinessController';
import LivenessController from '../controllers/LivenessController';
import { rateLimiter } from '../middleware/RateLimiter';

export class HealthRoutes {
    private static instance: HealthRoutes;
    private readonly router: Router;
    private readonly healthController: HealthController;
    private readonly readinessController: ReadinessController;
    private readonly livenessController: LivenessController;

    private constructor() {
        this.router = Router();
        this.healthController = HealthController.getInstance();
        this.readinessController = ReadinessController.getInstance();
        this.livenessController = LivenessController.getInstance();
        this.initializeRoutes();
    }

    public static getInstance(): HealthRoutes {
        if (!HealthRoutes.instance) {
            HealthRoutes.instance = new HealthRoutes();
        }
        return HealthRoutes.instance;
    }

    private initializeRoutes(): void {
        // Apply rate limiting to health endpoints
        this.router.use(rateLimiter.getHealthLimiter());

        // Health check endpoint
        this.router.get('/health',
            asyncHandler(this.healthController.checkHealth.bind(this.healthController))
        );

        // Readiness probe endpoint
        this.router.get('/ready',
            asyncHandler(this.readinessController.checkReadiness.bind(this.readinessController))
        );

        // Liveness probe endpoint
        this.router.get('/alive',
            asyncHandler(this.livenessController.checkLiveness.bind(this.livenessController))
        );

        // Quick status endpoint (no DB checks)
        this.router.get('/ping', (_, res) => {
            res.status(200).json({ status: 'ok' });
        });
    }

    public getRouter(): Router {
        return this.router;
    }
}

export const healthRoutes = HealthRoutes.getInstance();
export default HealthRoutes;

// Add to app.ts routes initialization:
// this.app.use('/api', healthRoutes.getRouter());