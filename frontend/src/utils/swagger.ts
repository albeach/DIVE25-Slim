import { createSwaggerSpec } from 'next-swagger-doc'

export const getApiDocs = async () => {
    const spec = createSwaggerSpec({
        title: 'DIVE25 API Documentation',
        version: '1.0.0',
        openapi: '3.0.0',
        apiFolder: 'src/pages/api', // Path to API folder
        definition: {
            openapi: '3.0.0',
            info: {
                title: 'DIVE25 API Documentation',
                version: '1.0.0',
                description: 'Documentation for the DIVE25 API',
            },
            servers: [
                {
                    url: process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3000',
                    description: 'API Server',
                },
            ],
            components: {
                securitySchemes: {
                    bearerAuth: {
                        type: 'http',
                        scheme: 'bearer',
                        bearerFormat: 'JWT',
                    },
                },
            },
            security: [
                {
                    bearerAuth: [],
                },
            ],
        },
    })
    return spec
} 