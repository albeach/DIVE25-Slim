'use client'

import { useEffect, useState } from 'react'
import { useAuth } from '@/hooks/useAuth'
import { documentService } from '@/services/api'
import { DocumentList } from '@/components/DocumentList'
import type { Document } from '@/services/api'

export default function DocumentsPage() {
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
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="text-center">
          <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-gray-900 mx-auto"></div>
          <p className="mt-2">Loading...</p>
        </div>
      </div>
    )
  }

  if (!isAuthenticated) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="text-center">
          <h1 className="text-2xl font-bold text-gray-900">Access Denied</h1>
          <p className="mt-2 text-gray-600">Please log in to view documents.</p>
        </div>
      </div>
    )
  }

  return <DocumentList />
}