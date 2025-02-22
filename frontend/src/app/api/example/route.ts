import { NextResponse } from 'next/server'

/**
 * @swagger
 * /api/example:
 *   get:
 *     summary: Get example data
 *     description: Retrieves example data from the API
 *     responses:
 *       200:
 *         description: Success
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 */
export async function GET() {
    return NextResponse.json({ message: 'Example API response' })
} 