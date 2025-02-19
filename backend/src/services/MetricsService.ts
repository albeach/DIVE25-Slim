// src/services/MetricsService.ts

export class MetricsService {
    private readonly metrics: {
        // Track overall API health
        apiRequests: prometheus.Counter;
        apiErrors: prometheus.Counter;
        responseTime: prometheus.Histogram;

        // Track authentication status
        authAttempts: prometheus.Counter;
        authFailures: prometheus.Counter;

        // Track document operations
        documentOperations: prometheus.Counter;
        documentErrors: prometheus.Counter;
    };

    private constructor() {
        // Initialize with only essential metrics
        this.metrics = {
            apiRequests: new prometheus.Counter({
                name: 'dive25_api_requests_total',
                help: 'Total number of API requests',
                labelNames: ['method', 'path']
            }),

            apiErrors: new prometheus.Counter({
                name: 'dive25_api_errors_total',
                help: 'Total number of API errors',
                labelNames: ['method', 'path', 'error_code']
            }),

            responseTime: new prometheus.Histogram({
                name: 'dive25_response_time_seconds',
                help: 'API response time in seconds',
                labelNames: ['method', 'path'],
                buckets: [0.1, 0.5, 1, 2, 5]
            }),

            authAttempts: new prometheus.Counter({
                name: 'dive25_auth_attempts_total',
                help: 'Total number of authentication attempts',
                labelNames: ['status']
            }),

            authFailures: new prometheus.Counter({
                name: 'dive25_auth_failures_total',
                help: 'Total number of authentication failures',
                labelNames: ['reason']
            }),

            documentOperations: new prometheus.Counter({
                name: 'dive25_document_operations_total',
                help: 'Total number of document operations',
                labelNames: ['operation', 'clearance_level']
            }),

            documentErrors: new prometheus.Counter({
                name: 'dive25_document_errors_total',
                help: 'Total number of document operation errors',
                labelNames: ['operation', 'error_type']
            })
        };
    }

    // Simple method to record API requests
    public recordApiRequest(method: string, path: string): void {
        this.metrics.apiRequests.inc({
            method,
            path
        });
    }

    // Record API errors
    public recordApiError(method: string, path: string, errorCode: string): void {
        this.metrics.apiErrors.inc({
            method,
            path,
            error_code: errorCode
        });
    }

    // Record response times
    public recordResponseTime(method: string, path: string, timeMs: number): void {
        this.metrics.responseTime.observe(
            {
                method,
                path
            },
            timeMs / 1000
        );
    }

    // Record document operations
    public recordDocumentOperation(operation: string, clearanceLevel: string): void {
        this.metrics.documentOperations.inc({
            operation,
            clearance_level: clearanceLevel
        });
    }
}