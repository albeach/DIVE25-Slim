'use client'

import { useEffect, useState } from 'react'
import keycloakService from '@/utils/keycloak'

export default function Home() {
  const [isLoading, setIsLoading] = useState(true)
  const [username, setUsername] = useState<string | undefined>()

  useEffect(() => {
    const initAuth = async () => {
      try {
        const keycloak = await keycloakService.initialize()
        if (keycloak?.authenticated) {
          setUsername(keycloak.tokenParsed?.preferred_username)
        }
      } catch (error) {
        console.error('Auth initialization error:', error)
      } finally {
        setIsLoading(false)
      }
    }

    initAuth()
  }, [])

  const handleLogin = () => {
    keycloakService.login()
  }

  const handleLogout = () => {
    keycloakService.logout()
  }

  if (isLoading) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="text-lg">Loading...</div>
      </div>
    )
  }

  return (
    <div className="p-8">
      <div className="max-w-4xl mx-auto">
        <h1 className="text-3xl font-bold mb-4">DIVE25 Dashboard</h1>
        {username ? (
          <div>
            <p>Welcome, {username}!</p>
            <button
              onClick={handleLogout}
              className="mt-4 px-4 py-2 bg-red-500 text-white rounded hover:bg-red-600"
            >
              Logout
            </button>
          </div>
        ) : (
          <div>
            <p>Please log in to continue</p>
            <button
              onClick={handleLogin}
              className="mt-4 px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-600"
            >
              Login
            </button>
          </div>
        )}
      </div>
    </div>
  )
}