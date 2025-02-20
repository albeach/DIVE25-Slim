// /backend/src/routes/documentRoutes.ts
import { Router } from 'express';
import DocumentController from '../controllers/DocumentController';
import { AuthMiddleware } from '../middleware/AuthMiddleware';
import { documentValidation } from '../middleware/DocumentValidation';
import { asyncHandler } from '../middleware/asyncHandler';

export class DocumentRoutes {
    private static instance: DocumentRoutes;
    private readonly router: Router;
    private readonly auth: AuthMiddleware;
    private readonly controller: DocumentController;

    private constructor() {
        this.router = Router();
        this.auth = AuthMiddleware.getInstance();
        this.controller = DocumentController.getInstance();
        this.initializeRoutes();
    }

    public static getInstance(): DocumentRoutes {
        if (!DocumentRoutes.instance) {
            DocumentRoutes.instance = new DocumentRoutes();
        }
        return DocumentRoutes.instance;
    }

    private initializeRoutes(): void {
        // Create document
        this.router.post('/',
            this.auth.authenticate,
            documentValidation.validateCreate,
            asyncHandler(this.controller.createDocument.bind(this.controller))
        );

        // Get document by ID
        this.router.get('/:id',
            this.auth.authenticate,
            asyncHandler(this.controller.getDocument.bind(this.controller))
        );

        // Update document
        this.router.put('/:id',
            this.auth.authenticate,
            documentValidation.validateUpdate,
            asyncHandler(this.controller.updateDocument.bind(this.controller))
        );

        // Delete document
        this.router.delete('/:id',
            this.auth.authenticate,
            asyncHandler(this.controller.deleteDocument.bind(this.controller))
        );

        // List documents (with filtering)
        this.router.get('/',
            this.auth.authenticate,
            asyncHandler(this.controller.listDocuments.bind(this.controller))
        );
    }

    public getRouter(): Router {
        return this.router;
    }
}

export const documentRoutes = DocumentRoutes.getInstance();
export default DocumentRoutes;