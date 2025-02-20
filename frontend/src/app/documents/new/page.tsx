// /frontend/src/app/documents/new/page.tsx
'use client';

import { DocumentForm } from '@/components/DocumentForm';
import { useRouter } from 'next/navigation';

export default function NewDocumentPage() {
    const router = useRouter();

    return (
        <div className="max-w-3xl mx-auto">
            <h1 className="text-2xl font-bold mb-6">Create New Document</h1>
            <DocumentForm 
                onSuccess={() => router.push('/documents')}
                onCancel={() => router.push('/documents')}
            />
        </div>
    );
}