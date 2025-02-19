// /backend/src/tests/integration/DocumentController.test.ts
import { setupTestDatabase } from '../setup'
import { DocumentController } from '../../controllers/DocumentController'
import { DatabaseService } from '../../services/DatabaseService'
import { AuthenticatedRequest } from '../../types'
import { Response } from 'express'

describe('DocumentController Integration Tests', () => {
    let cleanup: () => Promise<void>
    let controller: DocumentController
    let db: DatabaseService

    beforeAll(async () => {
        // Set up test database and services
        const testDb = await setupTestDatabase()
        cleanup = testDb.cleanup
        db = DatabaseService.getInstance()
        controller = DocumentController.getInstance()
    })

    afterAll(async () => {
        await cleanup()
    })

    describe('getDocument', () => {
        it('should retrieve a document when user has proper clearance', async () => {
            // Create test document
            const testDoc = await db.createDocument({
                title: 'Test Document',
                clearance: 'NATO CONFIDENTIAL',
                releasableTo: ['NATO'],
                metadata: {
                    createdAt: new Date(),
                    createdBy: 'test-user',
                    lastModified: new Date(),
                    version: 1
                }
            })

            // Mock request with proper clearance
            const req = {
                params: { id: testDoc._id.toString() },
                userAttributes: {
                    uniqueIdentifier: 'test-user',
                    clearance: 'NATO SECRET',
                    countryOfAffiliation: 'USA',
                    coiTags: ['OpAlpha']
                }
            } as unknown as AuthenticatedRequest

            const res = {
                json: jest.fn(),
                status: jest.fn().mockReturnThis()
            } as unknown as Response

            await controller.getDocument(req, res)

            expect(res.json).toHaveBeenCalledWith(
                expect.objectContaining({
                    title: 'Test Document',
                    clearance: 'NATO CONFIDENTIAL'
                })
            )
        })
    })
})