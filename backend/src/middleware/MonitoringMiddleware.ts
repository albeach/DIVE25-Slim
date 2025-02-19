// src/middleware/MonitoringMiddleware.ts
import { Request, Response, NextFunction } from 'express';
import { MetricsService } from '../services/MetricsService';

export function monitoringMiddleware(req: Request, res: Response, next: NextFunction) {
    const metrics = MetricsService.getInstance();
    const startTime = Date.now();

    // Capture Kong-provided headers
    const kongService = req.headers['x-kong-service'] as string;
    const kongRoute = req.headers['x-kong-route'] as string;
    const kongLatencyStart = req.headers['x-kong-start-time'];

    // Track response
    res.on('finish', () => {
        const duration = Date.now() - startTime;

        // Record basic metrics
        metrics.httpRequestDuration.observe(
            {
                method: req.method,
                path: req.path,
                status: res.statusCode.toString()
            },
            duration / 1000
        );

        // Record Kong-specific metrics
        if (kongService && kongRoute) {
            metrics.kongLatency.observe(
                {
                    service: kongService,
                    route: kongRoute
                },
                duration / 1000
            );

            if (res.getHeader('content-length')) {
                metrics.kongResponseSize.observe(
                    {
                        service: kongService,
                        route: kongRoute
                    },
                    parseInt(res.getHeader('content-length') as string)
                );
            }
        }
    });

    next();
}