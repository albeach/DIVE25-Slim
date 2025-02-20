// /backend/src/controllers/LivenessController.ts

import { Request, Response } from 'express';

export class LivenessController {
    private static instance: LivenessController;
    private startTime: number;

    private constructor() {
        this.startTime = Date.now();
    }

    public static getInstance(): LivenessController {
        if (!LivenessController.instance) {
            LivenessController.instance = new LivenessController();
        }
        return LivenessController.instance;
    }

    public checkLiveness(req: Request, res: Response): void {
        const uptime = Date.now() - this.startTime;
        res.status(200).json({
            status: 'alive',
            uptime: uptime,
            timestamp: new Date().toISOString()
        });
    }
}

export default LivenessController.getInstance();