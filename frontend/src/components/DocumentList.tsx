// /frontend/src/components/DocumentList.tsx
'use client';

import { useEffect, useState } from 'react';
import { useAuth } from '@/contexts/AuthContext';
import { documentService, type Document } from '@/services/api';
import Link from 'next/link';

export function DocumentList() {
    const { isAuthenticated } = useAuth();
    const [documents, setDocuments] = useState<Document[]>([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState<string | null>(null);

    useEffect(() => {
        async function fetchDocuments() {
            if (!isAuthenticated) return;

            try {
                setLoading(true);
                setError(null);
                const docs = await documentService.getDocuments();
                setDocuments(docs);
            } catch (err: any) {
                setError(err.response?.data?.error || 'Failed to load documents');
                console.error('Error fetching documents:', err);
            } finally {
                setLoading(false);
            }
        }

        fetchDocuments();
    }, [isAuthenticated]);

    if (loading) {
        return (
            <div className="flex justify-center items-center py-8">
                <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
            </div>
        );
    }

    if (error) {
        return (
            <div className="bg-red-50 border border-red-200 rounded-md p-4 my-4">
                <p className="text-red-700">{error}</p>
            </div>
        );
    }

    if (documents.length === 0) {
        return (
            <div className="text-center py-8">
                <p className="text-gray-600">No documents available.</p>
                <Link 
                    href="/documents/new"
                    className="inline-block mt-4 px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 transition-colors"
                >
                    Create New Document
                </Link>
            </div>
        );
    }

    return (
        <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-3">
            {documents.map((doc) => (
                <Link 
                    key={doc._id} 
                    href={`/documents/${doc._id}`}
                    className="block"
                >
                    <div className="border rounded-lg shadow-sm hover:shadow-md transition-shadow p-4 bg-white">
                        <div className="flex justify-between items-start mb-2">
                            <h2 className="text-lg font-semibold text-gray-900 truncate">
                                {doc.title}
                            </h2>
                            <span className="px-2 py-1 text-xs rounded bg-red-100 text-red-800 font-medium">
                                {doc.clearance}
                            </span>
                        </div>
                        
                        {doc.coiTags && doc.coiTags.length > 0 && (
                            <div className="flex flex-wrap gap-1 mb-2">
                                {doc.coiTags.map(tag => (
                                    <span 
                                        key={tag}
                                        className="px-2 py-1 text-xs bg-blue-100 text-blue-800 rounded"
                                    >
                                        {tag}
                                    </span>
                                ))}
                            </div>
                        )}
                        
                        <div className="text-sm text-gray-600">
                            <p>Created by: {doc.metadata.createdBy}</p>
                            <p>Last modified: {new Date(doc.metadata.lastModified).toLocaleDateString()}</p>
                            <p>Version: {doc.metadata.version}</p>
                        </div>
                        
                        <div className="mt-2 text-sm">
                            <span className="text-gray-600">Releasable to: </span>
                            <span className="text-gray-900">{doc.releasableTo.join(', ')}</span>
                        </div>
                    </div>
                </Link>
            ))}
        </div>
    );
}