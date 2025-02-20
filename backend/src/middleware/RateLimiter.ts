// /backend/src/middleware/RateLimiter.ts
import rateLimit from 'express-rate-limit';
import RedisStore from 'rate-limit-redis';
import { LoggerService } from '../services/LoggerService';
import { MetricsService } from '../services/MetricsService';
import { createClient } from 'redis';

export class RateLimiter {
    private static instance: RateLimiter;
    private readonly logger: LoggerService;
    private readonly metrics: MetricsService;
    private readonly redisClient: ReturnType<typeof createClient>;

    private constructor() {
        this.logger = LoggerService.getInstance();
        this.metrics = MetricsService.getInstance();
        this.redisClient = createClient({
            url: process.env.REDIS_URL || 'redis://localhost:6379'
        });

        this.redisClient.on('error', (err) => {
            this.logger.error('Redis client error:', err);
        });
    }

    public static getInstance(): RateLimiter {
        if (!RateLimiter.instance) {
            RateLimiter.instance = new RateLimiter();
        }
        return RateLimiter.instance;
    }

    public getDocumentLimiter() {
        return rateLimit({
            store: new RedisStore({
                prefix: 'rate_limit_doc:',
                // @ts-ignore - Type mismatch in library
                sendCommand: (...args: string[]) => this.redisClient.sendCommand(args),
            }),
            windowMs: 15 * 60 * 1000, // 15 minutes
            max: 100, // Limit each IP to 100 requests per windowMs
            standardHeaders: true,
            legacyHeaders: false,
            handler: (req, res) => {
                this.metrics.recordRateLimitExceeded(req.ip);
                res.status(429).json({
                    error: 'Too many requests',
                    code: 'RATE001'
                });
            }
        });
    }

    public getAuthLimiter() {
        return rateLimit({
            store: new RedisStore({
                prefix: 'rate_limit_auth:',
                // @ts-ignore - Type mismatch in library
                sendCommand: (...args: string[]) => this.redisClient.sendCommand(args),
            }),
            windowMs: 60 * 60 * 1000, // 1 hour
            max: 5, // 5 failed attempts per hour
            skipSuccessfulRequests: true,
            standardHeaders: true,
            legacyHeaders: false,
            handler: (req, res) => {
                this.metrics.recordAuthRateLimitExceeded(req.ip);
                res.status(429).json({
                    error: 'Too many failed attempts',
                    code: 'RATE002'
                });
            }
        });
    }
}

export const rateLimiter = RateLimiter.getInstance();