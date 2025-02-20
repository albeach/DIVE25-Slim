// /frontend/src/app/documents/page.tsx
'use client'

import { useEffect, useState } from 'react'
import { useAuth } from '@/contexts/AuthContext'
import { documentService } from '@/services/api'

interface Document {
  id: string
  title: string
  content: string
}

export default function Documents() {
  const { isAuthenticated, loading: authLoading } = useAuth()
  const [documents, setDocuments] = useState<Document[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    async function loadDocuments() {
      if (isAuthenticated) {
        try {
          const docs = await documentService.getDocuments()
          setDocuments(docs)
        } catch (error) {
          console.error('Failed to load documents:', error)
        } finally {
          setLoading(false)
        }
      }
    }

    loadDocuments()
  }, [isAuthenticated])

  if (authLoading || loading) {
    return <div>Loading...</div>
  }

  if (!isAuthenticated) {
    return <div>Please log in to view documents</div>
  }

  return (
    <div style={{ padding: '2rem' }}>
      <h1>Documents</h1>
      <div style={{ marginTop: '2rem' }}>
        {documents.map(doc => (
          <div key={doc.id} style={{ marginBottom: '1rem', padding: '1rem', border: '1px solid #ccc' }}>
            <h2>{doc.title}</h2>
            <p>{doc.content}</p>
          </div>
        ))}
      </div>
    </div>
  )
}