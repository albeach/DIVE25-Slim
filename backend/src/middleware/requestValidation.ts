// /backend/src/middleware/requestValidation.ts
import { Request, Response, NextFunction } from 'express';
import { LoggerService } from '../services/LoggerService';

export class RequestValidation {
    private static instance: RequestValidation;
    private readonly logger: LoggerService;

    private constructor() {
        this.logger = LoggerService.getInstance();
    }

    public static getInstance(): RequestValidation {
        if (!RequestValidation.instance) {
            RequestValidation.instance = new RequestValidation();
        }
        return RequestValidation.instance;
    }

    public validateDocument = (req: Request, res: Response, next: NextFunction): void => {
        const { title, content, clearance, releasableTo } = req.body;

        const errors = [];

        if (!title || typeof title !== 'string') {
            errors.push('Title is required and must be a string');
        }

        if (!content || typeof content !== 'string') {
            errors.push('Content is required and must be a string');
        }

        if (!clearance || !this.isValidClearanceLevel(clearance)) {
            errors.push('Valid clearance level is required');
        }

        if (releasableTo && !Array.isArray(releasableTo)) {
            errors.push('ReleasableTo must be an array');
        }

        if (errors.length > 0) {
            this.logger.warn('Document validation failed', { errors });
            res.status(400).json({ errors });
            return;
        }

        next();
    };

    private isValidClearanceLevel(clearance: string): boolean {
        const validLevels = [
            'UNCLASSIFIED',
            'RESTRICTED',
            'NATO CONFIDENTIAL',
            'NATO SECRET',
            'COSMIC TOP SECRET'
        ];
        return validLevels.includes(clearance);
    }
}

export const requestValidation = RequestValidation.getInstance();