// /backend/src/tests/setup.ts
import { MongoMemoryServer } from 'mongodb-memory-server'
import mongoose from 'mongoose'
import { config } from '../config/config'
import { LoggerService } from '../services/LoggerService'

const logger = LoggerService.getInstance()

// This creates an in-memory MongoDB instance for testing
export async function setupTestDatabase() {
    try {
        const mongoServer = await MongoMemoryServer.create()
        const mongoUri = mongoServer.getUri()

        await mongoose.connect(mongoUri)

        logger.info('Connected to in-memory test database')

        return {
            mongoServer,
            cleanup: async () => {
                await mongoose.disconnect()
                await mongoServer.stop()
                logger.info('Test database connection closed')
            }
        }
    } catch (error) {
        logger.error('Failed to setup test database:', error)
        throw error
    }
}

// Mock service implementations for testing
export const mockOPAService = {
    evaluateAccess: jest.fn().mockResolvedValue({ allow: true }),
    validateAttributes: jest.fn().mockResolvedValue({ valid: true }),
    evaluateClearanceAccess: jest.fn().mockResolvedValue({ allow: true })
}

export const mockKeycloakService = {
    verifyToken: jest.fn().mockResolvedValue({
        sub: 'test-user',
        clearance: 'NATO SECRET',
        coiTags: ['OpAlpha']
    })
}