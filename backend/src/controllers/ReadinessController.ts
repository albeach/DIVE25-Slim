// /backend/src/controllers/ReadinessController.ts

import { Request, Response } from 'express';
import { DatabaseService } from '../services/DatabaseService';

export class ReadinessController {
    private static instance: ReadinessController;
    private readonly db: DatabaseService;

    private constructor() {
        this.db = DatabaseService.getInstance();
    }

    public static getInstance(): ReadinessController {
        if (!ReadinessController.instance) {
            ReadinessController.instance = new ReadinessController();
        }
        return ReadinessController.instance;
    }

    public async checkReadiness(req: Request, res: Response): Promise<void> {
        try {
            await this.db.getDb().command({ ping: 1 });
            res.status(200).json({ status: 'ready' });
        } catch (error) {
            res.status(503).json({ status: 'not ready' });
        }
    }
}

export default ReadinessController.getInstance();