// /frontend/src/app/documents/page.tsx
'use client'

import { useEffect, useState } from 'react'
import { useAuth } from '@/hooks/useAuth'
import { documentService, type Document } from '@/services/api'
import { DocumentList } from '@/components/DocumentList'

export default function DocumentsPage() {
  return <DocumentList />
}