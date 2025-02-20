// /backend/src/middleware/RequestSanitizer.ts
import { Request, Response, NextFunction } from 'express';
import sanitizeHtml from 'sanitize-html';
import { LoggerService } from '../services/LoggerService';

export class RequestSanitizer {
    private static instance: RequestSanitizer;
    private readonly logger: LoggerService;

    private constructor() {
        this.logger = LoggerService.getInstance();
    }

    public static getInstance(): RequestSanitizer {
        if (!RequestSanitizer.instance) {
            RequestSanitizer.instance = new RequestSanitizer();
        }
        return RequestSanitizer.instance;
    }

    public sanitizeRequest = (req: Request, res: Response, next: NextFunction): void => {
        try {
            if (req.body) {
                req.body = this.sanitizeObject(req.body);
            }
            if (req.query) {
                req.query = this.sanitizeObject(req.query);
            }
            if (req.params) {
                req.params = this.sanitizeObject(req.params);
            }
            next();
        } catch (error) {
            this.logger.error('Request sanitization failed:', error);
            res.status(400).json({
                error: 'Invalid request data',
                code: 'SAN001'
            });
        }
    };

    private sanitizeObject(obj: any): any {
        if (Array.isArray(obj)) {
            return obj.map(item => this.sanitizeObject(item));
        }

        if (obj !== null && typeof obj === 'object') {
            const sanitized: any = {};
            for (const [key, value] of Object.entries(obj)) {
                sanitized[this.sanitizeString(key)] = this.sanitizeObject(value);
            }
            return sanitized;
        }

        if (typeof obj === 'string') {
            return this.sanitizeString(obj);
        }

        return obj;
    }

    private sanitizeString(str: string): string {
        return sanitizeHtml(str, {
            allowedTags: [],
            allowedAttributes: {},
            disallowedTagsMode: 'recursiveEscape'
        });
    }
}

export const requestSanitizer = RequestSanitizer.getInstance();