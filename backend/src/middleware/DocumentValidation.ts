// /backend/src/middleware/DocumentValidation.ts
import { Request, Response, NextFunction } from 'express';
import { LoggerService } from '../services/LoggerService';
import { MetricsService } from '../services/MetricsService';

export class DocumentValidation {
    private static instance: DocumentValidation;
    private readonly logger: LoggerService;
    private readonly metrics: MetricsService;

    private readonly VALID_CLEARANCE_LEVELS = [
        'UNCLASSIFIED',
        'RESTRICTED',
        'CONFIDENTIAL',
        'SECRET',
        'TOP SECRET'
    ];

    private readonly VALID_NATO_CLEARANCE_LEVELS = [
        'NATO UNCLASSIFIED',
        'NATO RESTRICTED',
        'NATO CONFIDENTIAL',
        'NATO SECRET',
        'COSMIC TOP SECRET'
    ];

    private readonly VALID_COI_TAGS = [
        'OpAlpha',
        'OpBravo',
        'OpGamma',
        'MissionX',
        'MissionZ'
    ];

    private readonly VALID_LACV_CODES = [
        'LACV001',
        'LACV002',
        'LACV003',
        'LACV004'
    ];

    private constructor() {
        this.logger = LoggerService.getInstance();
        this.metrics = MetricsService.getInstance();
    }

    public static getInstance(): DocumentValidation {
        if (!DocumentValidation.instance) {
            DocumentValidation.instance = new DocumentValidation();
        }
        return DocumentValidation.instance;
    }

    public validateCreate = (req: Request, res: Response, next: NextFunction): void => {
        try {
            const document = req.body;
            const errors = this.validateDocumentFields(document);

            if (errors.length > 0) {
                this.metrics.recordValidationError('document_create', errors.join(', '));
                res.status(400).json({ errors });
                return;
            }

            next();
        } catch (error) {
            this.logger.error('Document validation error:', error);
            res.status(500).json({ error: 'Validation processing error' });
        }
    };

    public validateUpdate = (req: Request, res: Response, next: NextFunction): void => {
        try {
            const document = req.body;
            const errors = this.validateDocumentFields(document, true);

            if (errors.length > 0) {
                this.metrics.recordValidationError('document_update', errors.join(', '));
                res.status(400).json({ errors });
                return;
            }

            next();
        } catch (error) {
            this.logger.error('Document validation error:', error);
            res.status(500).json({ error: 'Validation processing error' });
        }
    };

    private validateDocumentFields(document: any, isUpdate: boolean = false): string[] {
        const errors: string[] = [];

        // Required fields check (skip for updates)
        if (!isUpdate) {
            if (!document.title || typeof document.title !== 'string') {
                errors.push('Valid title is required');
            }

            if (!document.content || typeof document.content !== 'string') {
                errors.push('Valid content is required');
            }
        }

        // Clearance level validation
        if (document.clearance) {
            if (!this.VALID_CLEARANCE_LEVELS.includes(document.clearance) &&
                !this.VALID_NATO_CLEARANCE_LEVELS.includes(document.clearance)) {
                errors.push('Invalid clearance level');
            }
        } else if (!isUpdate) {
            errors.push('Clearance level is required');
        }

        // ReleasableTo validation
        if (document.releasableTo) {
            if (!Array.isArray(document.releasableTo)) {
                errors.push('ReleasableTo must be an array');
            } else {
                const invalidMarkers = document.releasableTo.filter(
                    marker => !this.isValidReleasabilityMarker(marker)
                );
                if (invalidMarkers.length > 0) {
                    errors.push(`Invalid releasability markers: ${invalidMarkers.join(', ')}`);
                }
            }
        }

        // COI Tags validation
        if (document.coiTags) {
            if (!Array.isArray(document.coiTags)) {
                errors.push('CoiTags must be an array');
            } else {
                const invalidTags = document.coiTags.filter(
                    tag => !this.VALID_COI_TAGS.includes(tag)
                );
                if (invalidTags.length > 0) {
                    errors.push(`Invalid COI tags: ${invalidTags.join(', ')}`);
                }
            }
        }

        // LACV Code validation
        if (document.lacvCode && !this.VALID_LACV_CODES.includes(document.lacvCode)) {
            errors.push('Invalid LACV code');
        }

        return errors;
    }

    private isValidReleasabilityMarker(marker: string): boolean {
        const validMarkers = ['NATO', 'EU', 'FVEY', 'PARTNERX'];
        return validMarkers.includes(marker);
    }
}

export const documentValidation = DocumentValidation.getInstance();