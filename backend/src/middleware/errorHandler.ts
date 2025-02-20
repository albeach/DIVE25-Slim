// /backend/src/middleware/errorHandler.ts
import { Request, Response, NextFunction } from 'express';
import { LoggerService } from '../services/LoggerService';
import { MetricsService } from '../services/MetricsService';

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

    public handleError = (
        error: any,
        req: Request,
        res: Response,
        next: NextFunction
    ): void => {
        const errorResponse = this.createErrorResponse(error);

        // Log error
        this.logger.error('Application error:', {
            error: errorResponse,
            path: req.path,
            method: req.method,
            requestId: req.headers['x-request-id']
        });

        // Record metric
        this.metrics.recordApiError(req.method, req.path, errorResponse.code);

        // Send response
        res.status(errorResponse.status).json({
            error: errorResponse.message,
            code: errorResponse.code
        });
    };

    private createErrorResponse(error: any): {
        message: string;
        status: number;
        code: string;
    } {
        // Handle known error types
        if (error.name === 'UnauthorizedError') {
            return {
                message: 'Authentication required',
                status: 401,
                code: 'AUTH001'
            };
        }

        if (error.name === 'ValidationError') {
            return {
                message: 'Invalid request data',
                status: 400,
                code: 'VAL001'
            };
        }

        if (error.name === 'DocumentNotFoundError') {
            return {
                message: 'Document not found',
                status: 404,
                code: 'DOC001'
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

export const errorHandler = ErrorHandler.getInstance().handleError;