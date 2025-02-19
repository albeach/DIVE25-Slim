// /backend/src/middleware/metricsMiddleware.ts
import { Request, Response, NextFunction } from 'express';
import { MetricsService } from '../services/MetricsService';

export function metricsMiddleware(req: Request, res: Response, next: NextFunction) {
    const startTime = Date.now();
    const metrics = MetricsService.getInstance();

    // Track request counts
    metrics.totalRequests.inc({
        method: req.method,
        path: req.path
    });

    // Track active connections
    metrics.activeConnections.inc();

    // When response finishes, record metrics
    res.on('finish', () => {
        const duration = Date.now() - startTime;

        // Record response time
        metrics.httpRequestDuration.observe(
            {
                method: req.method,
                path: req.path,
                status: res.statusCode.toString()
            },
            duration / 1000
        );

        // Record errors if any
        if (res.statusCode >= 400) {
            metrics.errorResponses.inc({
                status: res.statusCode.toString(),
                path: req.path
            });
        }

        // Decrease active connections
        metrics.activeConnections.dec();
    });

    next();
}