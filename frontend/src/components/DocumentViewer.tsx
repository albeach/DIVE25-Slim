// /frontend/src/components/DocumentViewer.tsx
import { useEffect, useState } from 'react';
import { useAuth } from '@/contexts/AuthContext';
import { documentService } from '@/services/api';

interface DocumentViewerProps {
    documentId: string;
}

interface Document {
    _id: string;
    title: string;
    content: string;
    clearance: string;
    releasableTo: string[];
    coiTags?: string[];
    metadata: {
        createdAt: string;
        createdBy: string;
        lastModified: string;
        version: number;
    };
}

export const DocumentViewer = ({ documentId }: DocumentViewerProps) => {
    const { isAuthenticated } = useAuth();
    const [document, setDocument] = useState<Document | null>(null);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState<string | null>(null);

    useEffect(() => {
        const fetchDocument = async () => {
            try {
                const doc = await documentService.getDocument(documentId);
                setDocument(doc);
            } catch (err: any) {
                if (err.response?.status === 403) {
                    setError('Access denied: Insufficient clearance');
                } else {
                    setError('Failed to load document');
                }
                console.error(err);
            } finally {
                setLoading(false);
            }
        };

        if (isAuthenticated && documentId) {
            fetchDocument();
        }
    }, [documentId, isAuthenticated]);

    if (!isAuthenticated) {
        return <div>Please log in to view this document</div>;
    }

    if (loading) {
        return <div>Loading document...</div>;
    }

    if (error) {
        return <div>Error: {error}</div>;
    }

    if (!document) {
        return <div>Document not found</div>;
    }

    return (
        <div className="container mx-auto p-4">
            <div className="bg-white rounded-lg shadow-lg p-6">
                <div className="flex justify-between items-start mb-4">
                    <h1 className="text-2xl font-bold">{document.title}</h1>
                    <div className="flex flex-col items-end">
                        <span className="px-3 py-1 rounded bg-red-100 text-red-800 font-semibold">
                            {document.clearance}
                        </span>
                        {document.coiTags && document.coiTags.length > 0 && (
                            <div className="mt-2">
                                {document.coiTags.map(tag => (
                                    <span 
                                        key={tag}
                                        className="ml-2 px-2 py-1 bg-blue-100 text-blue-800 rounded text-sm"
                                    >
                                        {tag}
                                    </span>
                                ))}
                            </div>
                        )}
                    </div>
                </div>

                <div className="prose max-w-none">
                    {document.content}
                </div>

                <div className="mt-6 pt-4 border-t text-sm text-gray-600">
                    <div>Created by: {document.metadata.createdBy}</div>
                    <div>Created: {new Date(document.metadata.createdAt).toLocaleString()}</div>
                    <div>Last modified: {new Date(document.metadata.lastModified).toLocaleString()}</div>
                    <div>Version: {document.metadata.version}</div>
                    <div>Releasable to: {document.releasableTo.join(', ')}</div>
                </div>
            </div>
        </div>
    );
};