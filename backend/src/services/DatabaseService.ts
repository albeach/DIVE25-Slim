// /backend/src/services/DatabaseService.ts
import { MongoClient, Db, Collection } from 'mongodb';
import { LoggerService } from './LoggerService';
import { MetricsService } from './MetricsService';

export class DatabaseService {
    private static instance: DatabaseService;
    private client: MongoClient;
    private db: Db;
    private readonly logger: LoggerService;
    private readonly metrics: MetricsService;

    private constructor() {
        this.logger = LoggerService.getInstance();
        this.metrics = MetricsService.getInstance();
        this.initialize();
    }

    public static getInstance(): DatabaseService {
        if (!DatabaseService.instance) {
            DatabaseService.instance = new DatabaseService();
        }
        return DatabaseService.instance;
    }

    private async initialize(): Promise<void> {
        try {
            const uri = process.env.MONGODB_URI || 'mongodb://localhost:27017/dive25';
            this.client = await MongoClient.connect(uri);
            this.db = this.client.db();

            await this.createIndexes();

            this.logger.info('Database connection established');
        } catch (error) {
            this.logger.error('Database connection failed:', error);
            throw error;
        }
    }

    private async createIndexes(): Promise<void> {
        try {
            await this.db.collection('documents').createIndexes([
                { key: { 'metadata.createdAt': 1 } },
                { key: { clearance: 1 } },
                { key: { 'metadata.createdBy': 1 } },
                { key: { releasableTo: 1 } }
            ]);
        } catch (error) {
            this.logger.error('Failed to create indexes:', error);
        }
    }

    public getDb(): Db {
        if (!this.db) {
            throw new Error('Database not initialized');
        }
        return this.db;
    }

    public collection(name: string): Collection {
        return this.getDb().collection(name);
    }

    public async findDocumentById(id: string): Promise<any> {
        try {
            const startTime = Date.now();
            const result = await this.collection('documents').findOne({ _id: id });

            this.metrics.recordDatabaseOperation('findById', Date.now() - startTime);
            return result;
        } catch (error) {
            this.logger.error('Database find operation failed:', error);
            this.metrics.recordDatabaseError('findById', error.message);
            throw error;
        }
    }

    public async createDocument(document: any): Promise<any> {
        try {
            const startTime = Date.now();
            const result = await this.collection('documents').insertOne(document);

            this.metrics.recordDatabaseOperation('create', Date.now() - startTime);
            return result;
        } catch (error) {
            this.logger.error('Database create operation failed:', error);
            this.metrics.recordDatabaseError('create', error.message);
            throw error;
        }
    }

    public async updateDocument(id: string, update: any): Promise<any> {
        try {
            const startTime = Date.now();
            const result = await this.collection('documents').updateOne(
                { _id: id },
                { $set: update }
            );

            this.metrics.recordDatabaseOperation('update', Date.now() - startTime);
            return result;
        } catch (error) {
            this.logger.error('Database update operation failed:', error);
            this.metrics.recordDatabaseError('update', error.message);
            throw error;
        }
    }

    public async deleteDocument(id: string): Promise<any> {
        try {
            const startTime = Date.now();
            const result = await this.collection('documents').deleteOne({ _id: id });

            this.metrics.recordDatabaseOperation('delete', Date.now() - startTime);
            return result;
        } catch (error) {
            this.logger.error('Database delete operation failed:', error);
            this.metrics.recordDatabaseError('delete', error.message);
            throw error;
        }
    }
}

export default DatabaseService.getInstance();