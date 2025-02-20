// /frontend/src/app/documents/[id]/page.tsx
'use client';

import { DocumentViewer } from '@/components/DocumentViewer';

export default function DocumentPage({ params }: { params: { id: string } }) {
    return <DocumentViewer documentId={params.id} />;
}