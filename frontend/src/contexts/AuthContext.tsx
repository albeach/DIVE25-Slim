// /frontend/src/contexts/AuthContext.tsx
'use client';

import { createContext, useContext, useState, useEffect, ReactNode } from 'react'
import type Keycloak from 'keycloak-js'

interface User {
  sub?: string;
  email?: string;
  name?: string;
  preferred_username?: string;
  securityAttributes?: {
    clearance: string;
    releasableTo?: string[];
    coiAccess?: string[];
  };
}

interface AuthContextType {
  isAuthenticated: boolean;
  user: User | null;
  token: string | null;
  loading: boolean;
  login: () => Promise<void>;
  logout: () => Promise<void>;
}

const AuthContext = createContext<AuthContextType>({
  isAuthenticated: false,
  user: null,
  token: null,
  loading: true,
  login: async () => {},
  logout: async () => {},
});

let keycloak: Keycloak;

export function AuthProvider({ children }: { children: ReactNode }) {
  const [isAuthenticated, setIsAuthenticated] = useState(false)
  const [user, setUser] = useState<User | null>(null)
  const [token, setToken] = useState<string | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const initializeKeycloak = async () => {
      try {
        // Dynamically import Keycloak only on client side
        const Keycloak = (await import('keycloak-js')).default;
        keycloak = new Keycloak({
          url: process.env.NEXT_PUBLIC_KEYCLOAK_URL || 'http://localhost:8080',
          realm: 'dive25',
          clientId: 'dive25-frontend'
        });

        const authenticated = await keycloak.init({
          onLoad: 'check-sso',
          silentCheckSsoRedirectUri: window.location.origin + '/silent-check-sso.html'
        })

        setIsAuthenticated(authenticated)
        if (authenticated && keycloak.tokenParsed) {
          setUser({
            sub: keycloak.tokenParsed.sub,
            email: keycloak.tokenParsed.email,
            name: keycloak.tokenParsed.name,
            preferred_username: keycloak.tokenParsed.preferred_username,
            securityAttributes: {
              clearance: keycloak.tokenParsed.clearance,
              releasableTo: keycloak.tokenParsed.releasableTo,
              coiAccess: keycloak.tokenParsed.coiAccess
            }
          })
          if (keycloak.token) {
            setToken(keycloak.token)
          }
        }
      } catch (error) {
        console.error('Failed to initialize Keycloak:', error)
      } finally {
        setLoading(false)
      }
    }

    initializeKeycloak()
  }, [])

  const login = async () => {
    try {
      if (keycloak) {
        await keycloak.login()
      }
    } catch (error) {
      console.error('Failed to login:', error)
    }
  }

  const logout = async () => {
    try {
      if (keycloak) {
        await keycloak.logout()
        setUser(null)
        setToken(null)
        setIsAuthenticated(false)
      }
    } catch (error) {
      console.error('Failed to logout:', error)
    }
  }

  return (
    <AuthContext.Provider value={{ isAuthenticated, user, token, loading, login, logout }}>
      {children}
    </AuthContext.Provider>
  )
}

export function useAuth() {
  const context = useContext(AuthContext)
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider')
  }
  return context
}