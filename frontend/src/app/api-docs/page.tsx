'use client'

import { useEffect, useState } from 'react'
import dynamic from 'next/dynamic'
import { useAuth } from '@/contexts/AuthContext'

// Dynamically import the protected component
const ProtectedApiDocs = dynamic(
  () => import('@/components/ProtectedApiDocs'),
  { ssr: false }
)

export default function ApiDoc() {
  const [spec, setSpec] = useState(null)
  const { isAuthenticated, token } = useAuth()

  useEffect(() => {
    if (isAuthenticated && token) {
      fetch('/api/docs', {
        headers: {
          'Authorization': `Bearer ${token}`
        }
      })
        .then(res => res.json())
        .then(data => setSpec(data))
        .catch(err => console.error('Failed to fetch API docs:', err))
    }
  }, [isAuthenticated, token])

  if (!spec) {
    return <div className="p-8">Loading API documentation...</div>
  }

  return <ProtectedApiDocs spec={spec} />
} 