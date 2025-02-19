// /frontend/src/app/page.tsx
'use client'

import { useEffect, useState } from 'react'
import { useRouter } from 'next/navigation'
import { useAuth } from '@/hooks/useAuth'

export default function Home() {
  const router = useRouter()
  const { isAuthenticated, login } = useAuth()
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    if (isAuthenticated) {
      router.push('/documents')
    } else {
      setLoading(false)
    }
  }, [isAuthenticated, router])

  if (loading) {
    return <div>Loading...</div>
  }

  return (
    <main className="flex min-h-screen flex-col items-center justify-center p-24">
      <div className="max-w-5xl w-full">
        <h1 className="text-4xl font-bold mb-8 text-center">
          Welcome to DIVE25
        </h1>
        <div className="flex justify-center">
          <button
            onClick={() => login()}
            className="bg-blue-600 text-white px-6 py-3 rounded-lg hover:bg-blue-700"
          >
            Sign In
          </button>
        </div>
      </div>
    </main>
  )
}