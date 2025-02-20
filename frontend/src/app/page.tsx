// /frontend/src/app/page.tsx
'use client'

import { useEffect, useState } from 'react'
import { useRouter } from 'next/navigation'
import { useAuth } from '@/contexts/AuthContext'

export default function Home() {
  const router = useRouter()
  const { isAuthenticated, loading: authLoading, login } = useAuth()
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    if (!authLoading) {
      if (isAuthenticated) {
        router.push('/documents')
      }
      setLoading(false)
    }
  }, [isAuthenticated, authLoading, router])

  if (loading || authLoading) {
    return (
      <main style={{ 
        padding: '2rem',
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        minHeight: '100vh'
      }}>
        <p>Loading...</p>
      </main>
    )
  }

  return (
    <main style={{ 
      padding: '2rem',
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      justifyContent: 'center',
      minHeight: '100vh'
    }}>
      <h1 style={{ marginBottom: '1rem' }}>DIVE25</h1>
      <p style={{ marginBottom: '2rem' }}>Welcome to DIVE25</p>
      <button
        onClick={login}
        style={{
          padding: '0.5rem 1rem',
          backgroundColor: '#0070f3',
          color: 'white',
          border: 'none',
          borderRadius: '4px',
          cursor: 'pointer'
        }}
      >
        Login
      </button>
    </main>
  );
}