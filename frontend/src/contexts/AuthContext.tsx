// /frontend/src/contexts/AuthContext.tsx
import { createContext, useContext, useState, useEffect } from 'react'
import Keycloak from 'keycloak-js'

const keycloak = new Keycloak({
  url: process.env.NEXT_PUBLIC_KEYCLOAK_URL,
  realm: 'dive25',
  clientId: 'dive25-api'
})

interface AuthContextType {
  isAuthenticated: boolean
  user: any
  login: () => Promise<void>
  logout: () => Promise<void>
  token: string | null
}

const AuthContext = createContext<AuthContextType | undefined>(undefined)

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [isAuthenticated, setIsAuthenticated] = useState(false)
  const [user, setUser] = useState(null)
  const [token, setToken] = useState<string | null>(null)

  useEffect(() => {
    const initKeycloak = async () => {
      try {
        const authenticated = await keycloak.init({
          onLoad: 'check-sso',
          silentCheckSsoRedirectUri: window.location.origin + '/silent-check-sso.html'
        })

        setIsAuthenticated(authenticated)
        if (authenticated) {
          setUser(keycloak.tokenParsed)
          setToken(keycloak.token)
        }
      } catch (error) {
        console.error('Failed to initialize Keycloak:', error)
      }
    }

    initKeycloak()
  }, [])

  const login = async () => {
    try {
      await keycloak.login()
    } catch (error) {
      console.error('Login failed:', error)
    }
  }

  const logout = async () => {
    try {
      await keycloak.logout()
    } catch (error) {
      console.error('Logout failed:', error)
    }
  }

  return (
    <AuthContext.Provider value={{ isAuthenticated, user, login, logout, token }}>
      {children}
    </AuthContext.Provider>
  )
}

export function useAuth() {
  const context = useContext(AuthContext)
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider')
  }
  return context
}