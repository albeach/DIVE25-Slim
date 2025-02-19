// /frontend/src/app/documents/page.tsx
'use client'

import { useEffect, useState } from 'react'
import { useAuth } from '@/hooks/useAuth'
import { documentService } from '@/services/api'

interface Document {
  _id: string
  title: string
  clearance: string
  metadata: {
    createdAt: string
    createdBy: string
  }
}

export default function Documents() {
  const { isAuthenticated, user } = useAuth()
  const [documents, setDocuments] = useState<Document[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const fetchDocuments = async () => {
      try {
        const response = await documentService.getDocuments({})
        setDocuments(response.data)
      } catch (error) {
        console.error('Failed to fetch documents:', error)
      } finally {
        setLoading(false)
      }
    }

    if (isAuthenticated) {
      fetchDocuments()
    }
  }, [isAuthenticated])

  if (!isAuthenticated) {
    return <div>Please log in to access documents.</div>
  }

  if (loading) {
    return <div>Loading documents...</div>
  }

  return (
    <div className="container mx-auto px-4 py-8">
      <h1 className="text-2xl font-bold mb-6">Documents</h1>
      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
        {documents.map((doc) => (
          <div 
            key={doc._id} 
            className="p-4 border rounded-lg shadow bg-white"
          >
            <h2 className="text-lg font-semibold">{doc.title}</h2>
            <p className="text-sm text-gray-600">
              Classification: {doc.clearance}
            </p>
            <p className="text-sm text-gray-500">
              Created: {new Date(doc.metadata.createdAt).toLocaleDateString()}
            </p>
          </div>
        ))}
      </div>
    </div>
  )
}