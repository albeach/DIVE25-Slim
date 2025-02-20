// /backend/src/types/errors.ts
export class ApplicationError extends Error {
    constructor(
        message: string,
        public code: string,
        public statusCode: number,
        public details?: any
    ) {
        super(message);
        this.name = 'ApplicationError';
    }
}

export class AuthenticationError extends ApplicationError {
    constructor(message: string = 'Authentication failed', code: string = 'AUTH001') {
        super(message, code, 401);
        this.name = 'AuthenticationError';
    }
}

export class AuthorizationError extends ApplicationError {
    constructor(message: string = 'Access denied', code: string = 'AUTH002') {
        super(message, code, 403);
        this.name = 'AuthorizationError';
    }
}

export class ValidationError extends ApplicationError {
    constructor(message: string, details?: any) {
        super(message, 'VAL001', 400, details);
        this.name = 'ValidationError';
    }
}

export class DocumentError extends ApplicationError {
    constructor(message: string, code: string = 'DOC001', statusCode: number = 400) {
        super(message, code, statusCode);
        this.name = 'DocumentError';
    }
}