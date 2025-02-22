'use client'

import { ReactNode, useEffect, useState } from 'react'
import keycloakService from '@/utils/keycloak'

interface KeycloakProviderProps {
  children: ReactNode
}

export default function KeycloakProvider({ children }: KeycloakProviderProps) {
  const [isInitialized, setIsInitialized] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    const initKeycloak = async () => {
      try {
        const keycloak = await keycloakService.initialize()
        if (keycloak) {
          console.log('Keycloak initialized:', keycloak.authenticated ? 'Authenticated' : 'Not authenticated')
        } else {
          console.log('Keycloak initialization skipped (SSR or already initialized)')
        }
        setIsInitialized(true)
      } catch (err) {
        console.error('Failed to initialize Keycloak:', err)
        setError('Authentication service unavailable')
        setIsInitialized(true)
      }
    }

    initKeycloak()
  }, [])

  // During SSR or initialization, render a minimal layout
  if (!isInitialized) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="text-center">
          <div className="text-lg">Loading...</div>
        </div>
      </div>
    )
  }

  if (error) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="text-center">
          <div className="text-lg text-red-600">{error}</div>
          <button 
            onClick={() => window.location.reload()}
            className="mt-4 px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-600"
          >
            Retry
          </button>
        </div>
      </div>
    )
  }

  return <>{children}</>
} 