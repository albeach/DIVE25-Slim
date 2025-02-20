// /frontend/src/components/DocumentList.tsx
import { useEffect, useState } from 'react';
import { useAuth } from '@/contexts/AuthContext';
import { documentService } from '@/services/api';

interface Document {
    _id: string;
    title: string;
    clearance: string;
    metadata: {
        createdAt: string;
        createdBy: string;
    };
}

export const DocumentList = () => {
    const { isAuthenticated, user } = useAuth();
    const [documents, setDocuments] = useState<Document[]>([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState<string | null>(null);

    useEffect(() => {
        const fetchDocuments = async () => {
            try {
                const docs = await documentService.getDocuments();
                setDocuments(docs);
            } catch (err) {
                setError('Failed to load documents');
                console.error(err);
            } finally {
                setLoading(false);
            }
        };

        if (isAuthenticated) {
            fetchDocuments();
        }
    }, [isAuthenticated]);

    if (!isAuthenticated) {
        return <div>Please log in to view documents</div>;
    }

    if (loading) {
        return <div>Loading documents...</div>;
    }

    if (error) {
        return <div>Error: {error}</div>;
    }

    return (
        <div className="container mx-auto p-4">
            <h1 className="text-2xl font-bold mb-4">Documents</h1>
            <div className="grid gap-4">
                {documents.map(doc => (
                    <div 
                        key={doc._id}
                        className="border p-4 rounded-lg shadow hover:shadow-md transition-shadow"
                    >
                        <div className="flex justify-between items-start">
                            <h2 className="text-xl font-semibold">{doc.title}</h2>
                            <span className="px-2 py-1 text-sm rounded bg-gray-200">
                                {doc.clearance}
                            </span>
                        </div>
                        <div className="mt-2 text-sm text-gray-600">
                            Created by: {doc.metadata.createdBy}
                        </div>
                        <div className="mt-1 text-sm text-gray-600">
                            Date: {new Date(doc.metadata.createdAt).toLocaleDateString()}
                        </div>
                    </div>
                ))}
            </div>
        </div>
    );
};