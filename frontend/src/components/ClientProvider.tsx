'use client'

import { ReactNode } from 'react'
import KeycloakProvider from './KeycloakProvider'

export default function ClientProvider({ children }: { children: ReactNode }) {
  return <KeycloakProvider>{children}</KeycloakProvider>
} 