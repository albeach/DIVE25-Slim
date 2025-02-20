// /backend/src/middleware/errorHandler.ts
import { Request, Response, NextFunction } from 'express';
import { LoggerService } from '../services/LoggerService';
import { MetricsService } from '../services/MetricsService';

interface ErrorResponse {
    message: string;
    status: number;
    code: string;
    details?: any;
}

class ApplicationError extends Error {
    constructor(
        public message: string,
        public statusCode: number,
        public code: string,
        public details?: any
    ) {
        super(message);
        this.name = 'ApplicationError';
    }
}

export class ErrorHandler {
    private static instance: ErrorHandler;
    private readonly logger: LoggerService;
    private readonly metrics: MetricsService;

    private constructor() {
        this.logger = LoggerService.getInstance();
        this.metrics = MetricsService.getInstance();
    }

    public static getInstance(): ErrorHandler {
        if (!ErrorHandler.instance) {
            ErrorHandler.instance = new ErrorHandler();
        }
        return ErrorHandler.instance;
    }

    public handleError(error: any, req: Request, res: Response, next: NextFunction): void {
        const errorResponse = this.createErrorResponse(error);

        // Log error details
        this.logger.error('Request error:', {
            error: errorResponse,
            path: req.path,
            method: req.method,
            requestId: req.headers['x-request-id']
        });

        // Record error metrics
        this.metrics.recordError(errorResponse.code, errorResponse.status);

        res.status(errorResponse.status).json(errorResponse);
    }

    private createErrorResponse(error: any): ErrorResponse {
        if (error instanceof ApplicationError) {
            return {
                message: error.message,
                status: error.statusCode,
                code: error.code,
                details: error.details
            };
        }

        // Handle specific error types
        switch (error.name) {
            case 'TokenExpiredError':
                return {
                    message: 'Authentication token expired',
                    status: 401,
                    code: 'AUTH003'
                };
            case 'JsonWebTokenError':
                return {
                    message: 'Invalid authentication token',
                    status: 401,
                    code: 'AUTH004'
                };
            case 'MongoError':
                if (error.code === 11000) {
                    return {
                        message: 'Duplicate entry found',
                        status: 409,
                        code: 'DB001'
                    };
                }
                break;
            case 'ValidationError':
                return {
                    message: 'Validation failed',
                    status: 400,
                    code: 'VAL001',
                    details: error.details
                };
            case 'OPAError':
                return {
                    message: 'Access policy evaluation failed',
                    status: 403,
                    code: 'OPA001',
                    details: error.details
                };
        }

        // Default error response
        return {
            message: 'Internal server error',
            status: 500,
            code: 'INT001'
        };
    }
}

export const errorHandler = ErrorHandler.getInstance();
export { ApplicationError };