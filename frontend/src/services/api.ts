// /frontend/src/services/api.ts
import axios, { AxiosError, AxiosRequestConfig } from 'axios'

// Extend AxiosRequestConfig to include metadata
interface RequestConfigWithMetadata extends AxiosRequestConfig {
    metadata?: {
        startTime: Date;
    };
}

interface DocumentMetadata {
    createdAt: Date;
    createdBy: string;
    lastModified: Date;
    version: number;
}

interface Document {
    _id?: string;
    title: string;
    content: string;
    clearance: string;
    releasableTo: string[];
    coiTags?: string[];
    lacvCode?: string;
    metadata: DocumentMetadata;
}

interface CreateDocumentDTO {
    title: string;
    content: string;
    clearance: string;
    releasableTo: string[];
    coiTags?: string[];
    lacvCode?: string;
}

interface UpdateDocumentDTO extends Partial<CreateDocumentDTO> { }

const api = axios.create({
    baseURL: process.env.NEXT_PUBLIC_API_URL,
    headers: {
        'Content-Type': 'application/json'
    }
})

// Add auth token and timing information to requests
api.interceptors.request.use((config: RequestConfigWithMetadata) => {
    const token = localStorage.getItem('token')
    if (token) {
        config.headers.Authorization = `Bearer ${token}`
    }
    config.metadata = { startTime: new Date() }
    return config
})

// Handle responses, timing metrics, and errors
api.interceptors.response.use(
    (response) => {
        const config = response.config as RequestConfigWithMetadata
        if (config.metadata?.startTime) {
            const duration = new Date().getTime() - config.metadata.startTime.getTime()
            // Send timing metric to backend
            api.post('/api/metrics/timing', {
                endpoint: config.url,
                duration,
                status: response.status
            }).catch(() => { }) // Silent fail for metrics
        }
        return response
    },
    (error: AxiosError) => {
        const config = error.config as RequestConfigWithMetadata
        if (config?.metadata?.startTime) {
            const duration = new Date().getTime() - config.metadata.startTime.getTime()
            // Send error metric to backend
            api.post('/api/metrics/error', {
                endpoint: config.url,
                duration,
                status: error.response?.status,
                error: error.message
            }).catch(() => { }) // Silent fail for metrics
        }

        if (error.response?.status === 401) {
            // Trigger Keycloak refresh or redirect to login
            window.location.href = '/api/auth/login'
        } else if (error.response?.status === 403) {
            // Handle forbidden access
            console.error('Access denied:', error.response.data)
        } else if (error.response?.status === 404) {
            // Handle not found
            console.error('Resource not found:', error.response.data)
        } else {
            // Handle other errors
            console.error('API error:', error.response?.data || error.message)
        }
        return Promise.reject(error)
    }
)

export const documentService = {
    async getDocuments(): Promise<Document[]> {
        const response = await api.get<Document[]>('/api/documents')
        return response.data
    },

    async getDocument(id: string): Promise<Document> {
        const response = await api.get<Document>(`/api/documents/${id}`)
        return response.data
    },

    async createDocument(data: CreateDocumentDTO): Promise<{ id: string; message: string }> {
        const response = await api.post('/api/documents', data)
        return response.data
    },

    async updateDocument(id: string, data: UpdateDocumentDTO): Promise<{ message: string }> {
        const response = await api.put(`/api/documents/${id}`, data)
        return response.data
    },

    async deleteDocument(id: string): Promise<{ message: string }> {
        const response = await api.delete(`/api/documents/${id}`)
        return response.data
    }
}

export type { Document, CreateDocumentDTO, UpdateDocumentDTO }