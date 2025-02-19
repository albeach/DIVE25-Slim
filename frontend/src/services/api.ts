// /frontend/src/services/api.ts
import axios from 'axios'

const api = axios.create({
    baseURL: process.env.NEXT_PUBLIC_API_URL,
    headers: {
        'Content-Type': 'application/json'
    }
})

api.interceptors.request.use((config) => {
    const token = localStorage.getItem('token')
    if (token) {
        config.headers.Authorization = `Bearer ${token}`
    }
    return config
})

export const documentService = {
    async getDocuments(params: any) {
        const response = await api.get('/api/documents', { params })
        return response.data
    },

    async getDocument(id: string) {
        const response = await api.get(`/api/documents/${id}`)
        return response.data
    },

    async createDocument(data: any) {
        const response = await api.post('/api/documents', data)
        return response.data
    },

    async updateDocument(id: string, data: any) {
        const response = await api.put(`/api/documents/${id}`, data)
        return response.data
    },

    async deleteDocument(id: string) {
        const response = await api.delete(`/api/documents/${id}`)
        return response.data
    }
}