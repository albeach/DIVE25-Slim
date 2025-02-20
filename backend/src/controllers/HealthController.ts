// /backend/src/controllers/HealthController.ts
import { Request, Response } from 'express';
import { DatabaseService } from '../services/DatabaseService';
import { MetricsService } from '../services/MetricsService';
import { OPAService } from '../services/OPAService';
import { RedisService } from '../services/RedisService';
import { LoggerService } from '../services/LoggerService';

interface HealthStatus {
    status: 'healthy' | 'degraded' | 'unhealthy';
    timestamp: string;
    version: string;
    services: {
        [key: string]: {
            status: 'healthy' | 'unhealthy';
            latency?: number;
            error?: string;
        };
    };
    metrics?: {
        activeConnections: number;
        averageResponseTime: number;
        errorRate: number;
        memoryUsage: {
            heapUsed: number;
            heapTotal: number;
            external: number;
        };
    };
}

export class HealthController {
    private static instance: HealthController;
    private readonly db: DatabaseService;
    private readonly metrics: MetricsService;
    private readonly opa: OPAService;
    private readonly redis: RedisService;
    private readonly logger: LoggerService;

    private constructor() {
        this.db = DatabaseService.getInstance();
        this.metrics = MetricsService.getInstance();
        this.opa = OPAService.getInstance();
        this.redis = RedisService.getInstance();
        this.logger = LoggerService.getInstance();
    }

    public static getInstance(): HealthController {
        if (!HealthController.instance) {
            HealthController.instance = new HealthController();
        }
        return HealthController.instance;
    }

    public async checkHealth(req: Request, res: Response): Promise<void> {
        const startTime = Date.now();
        const status: HealthStatus = {
            status: 'healthy',
            timestamp: new Date().toISOString(),
            version: process.env.npm_package_version || '1.0.0',
            services: {}
        };

        try {
            // Check MongoDB
            const dbStartTime = Date.now();
            await this.db.getDb().command({ ping: 1 });
            status.services['mongodb'] = {
                status: 'healthy',
                latency: Date.now() - dbStartTime
            };
        } catch (error) {
            status.services['mongodb'] = {
                status: 'unhealthy',
                error: error.message
            };
            status.status = 'degraded';
            this.logger.error('MongoDB health check failed:', error);
        }

        try {
            // Check OPA
            const opaStartTime = Date.now();
            await this.opa.ping();
            status.services['opa'] = {
                status: 'healthy',
                latency: Date.now() - opaStartTime
            };
        } catch (error) {
            status.services['opa'] = {
                status: 'unhealthy',
                error: error.message
            };
            status.status = 'degraded';
            this.logger.error('OPA health check failed:', error);
        }

        try {
            // Check Redis
            const redisStartTime = Date.now();
            await this.redis.ping();
            status.services['redis'] = {
                status: 'healthy',
                latency: Date.now() - redisStartTime
            };
        } catch (error) {
            status.services['redis'] = {
                status: 'unhealthy',
                error: error.message
            };
            status.status = 'degraded';
            this.logger.error('Redis health check failed:', error);
        }

        // Add metrics
        status.metrics = {
            activeConnections: await this.metrics.getActiveConnections(),
            averageResponseTime: await this.metrics.calculateAverageResponseTime(),
            errorRate: await this.metrics.getErrorRate(),
            memoryUsage: {
                heapUsed: process.memoryUsage().heapUsed,
                heapTotal: process.memoryUsage().heapTotal,
                external: process.memoryUsage().external
            }
        };

        // Record health check metrics
        this.metrics.recordHealthCheck({
            status: status.status,
            duration: Date.now() - startTime,
            services: Object.entries(status.services).map(([name, info]) => ({
                name,
                status: info.status,
                latency: info.latency
            }))
        });

        // Determine response status code
        const statusCode = status.status === 'healthy' ? 200 : 503;
        res.status(statusCode).json(status);
    }
}

export default HealthController.getInstance();