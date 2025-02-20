// /backend/src/controllers/DocumentController.ts
import { Request, Response } from 'express';
import { DatabaseService } from '../services/DatabaseService';
import { MetricsService } from '../services/MetricsService';
import { LoggerService } from '../services/LoggerService';
import { DocumentService } from '../services/DocumentService';
import { OPAService } from '../services/OPAService';

interface DocumentMetadata {
    createdAt: Date;
    createdBy: string;
    lastModified: Date;
    version: number;
}

interface Document {
    _id?: string;
    title: string;
    content: string;
    clearance: string;
    releasableTo: string[];
    coiTags?: string[];
    lacvCode?: string;
    metadata: DocumentMetadata;
}

export class DocumentController {
    private static instance: DocumentController;
    private readonly db: DatabaseService;
    private readonly metrics: MetricsService;
    private readonly logger: LoggerService;
    private readonly opa: OPAService = OPAService.getInstance();
    private readonly documentService: DocumentService;

    private constructor() {
        this.db = DatabaseService.getInstance();
        this.metrics = MetricsService.getInstance();
        this.logger = LoggerService.getInstance();
        this.documentService = DocumentService.getInstance();
    }

    public static getInstance(): DocumentController {
        if (!DocumentController.instance) {
            DocumentController.instance = new DocumentController();
        }
        return DocumentController.instance;
    }

    public async getDocument(req: Request, res: Response): Promise<void> {
        const startTime = Date.now();
        try {
            const userAttributes = (req as any).userAttributes;
            const documentId = req.params.id;

            if (!userAttributes) {
                res.status(401).json({ error: 'Unauthorized' });
                return;
            }

            const document = await this.db.findDocumentById(documentId);

            if (!document) {
                res.status(404).json({ error: 'Document not found' });
                return;
            }

            // Evaluate access using both access_policy and partner_policies
            const hasAccess = await this.opa.evaluateAccess(
                userAttributes,
                {
                    clearance: document.clearance,
                    releasableTo: document.releasableTo,
                    coiTags: document.coiTags,
                    lacvCode: document.lacvCode
                }
            );

            if (!hasAccess) {
                this.metrics.recordAccessDenial(
                    userAttributes.countryOfAffiliation,
                    document.clearance
                );
                res.status(403).json({ error: 'Access denied' });
                return;
            }

            this.metrics.recordDocumentOperation('read', document.clearance, Date.now() - startTime);
            this.metrics.recordResponseTime('get_document', Date.now() - startTime);

            res.json(document);
        } catch (error) {
            this.logger.error('Failed to retrieve document:', error);
            this.metrics.recordDocumentError('read', error.message);
            res.status(500).json({ error: 'Internal server error' });
        }
    }

    public async createDocument(req: Request, res: Response): Promise<void> {
        const startTime = Date.now();
        try {
            const userAttributes = (req as any).userAttributes;

            if (!userAttributes) {
                res.status(401).json({ error: 'Unauthorized' });
                return;
            }

            const document: Document = {
                title: req.body.title,
                content: req.body.content,
                clearance: req.body.clearance,
                releasableTo: req.body.releasableTo || [],
                coiTags: req.body.coiTags || [],
                lacvCode: req.body.lacvCode,
                metadata: {
                    createdAt: new Date(),
                    createdBy: userAttributes.uniqueIdentifier,
                    lastModified: new Date(),
                    version: 1
                }
            };

            // Validate document attributes
            const attributesValid = await this.opa.validateAttributes(userAttributes);
            if (!attributesValid) {
                res.status(400).json({ error: 'Invalid document attributes' });
                return;
            }

            const result = await this.db.createDocument(document);

            this.metrics.recordDocumentOperation('create', document.clearance, Date.now() - startTime);
            this.metrics.recordResponseTime('create_document', Date.now() - startTime);

            res.status(201).json({
                id: result.insertedId,
                message: 'Document created successfully'
            });
        } catch (error) {
            this.logger.error('Failed to create document:', error);
            this.metrics.recordDocumentError('create', error.message);
            res.status(500).json({ error: 'Internal server error' });
        }
    }

    public async updateDocument(req: Request, res: Response): Promise<void> {
        const startTime = Date.now();
        try {
            const userAttributes = (req as any).userAttributes;
            const documentId = req.params.id;

            if (!userAttributes) {
                res.status(401).json({ error: 'Unauthorized' });
                return;
            }

            const document = await this.db.collection('documents').findOne({ _id: documentId });

            if (!document) {
                res.status(404).json({ error: 'Document not found' });
                return;
            }

            if (!this.hasRequiredClearance(userAttributes.clearance, document.clearance)) {
                res.status(403).json({ error: 'Insufficient clearance' });
                return;
            }

            const updateData = {
                ...req.body,
                metadata: {
                    ...document.metadata,
                    lastModified: new Date(),
                    version: document.metadata.version + 1
                }
            };

            await this.db.collection('documents').updateOne(
                { _id: documentId },
                { $set: updateData }
            );

            this.metrics.recordDocumentOperation('update', document.clearance, Date.now() - startTime);
            this.metrics.recordResponseTime('update_document', Date.now() - startTime);

            res.json({ message: 'Document updated successfully' });
        } catch (error) {
            this.logger.error('Failed to update document:', error);
            this.metrics.recordDocumentError('update', error.message);
            res.status(500).json({ error: 'Internal server error' });
        }
    }

    public async deleteDocument(req: Request, res: Response): Promise<void> {
        const startTime = Date.now();
        try {
            const userAttributes = (req as any).userAttributes;
            const documentId = req.params.id;

            if (!userAttributes) {
                res.status(401).json({ error: 'Unauthorized' });
                return;
            }

            const document = await this.db.collection('documents').findOne({ _id: documentId });

            if (!document) {
                res.status(404).json({ error: 'Document not found' });
                return;
            }

            if (!this.hasRequiredClearance(userAttributes.clearance, document.clearance)) {
                res.status(403).json({ error: 'Insufficient clearance' });
                return;
            }

            await this.db.collection('documents').deleteOne({ _id: documentId });

            this.metrics.recordDocumentOperation('delete', document.clearance, Date.now() - startTime);
            this.metrics.recordResponseTime('delete_document', Date.now() - startTime);

            res.json({ message: 'Document deleted successfully' });
        } catch (error) {
            this.logger.error('Failed to delete document:', error);
            this.metrics.recordDocumentError('delete', error.message);
            res.status(500).json({ error: 'Internal server error' });
        }
    }

    private hasRequiredClearance(userClearance: string, documentClearance: string): boolean {
        const clearanceLevels = {
            'UNCLASSIFIED': 0,
            'RESTRICTED': 1,
            'NATO CONFIDENTIAL': 2,
            'NATO SECRET': 3,
            'COSMIC TOP SECRET': 4
        };

        return clearanceLevels[userClearance] >= clearanceLevels[documentClearance];
    }
}

export default DocumentController.getInstance();