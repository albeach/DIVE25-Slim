// /frontend/src/components/Sidebar.tsx
import { useAuth } from '@/contexts/AuthContext';

export const Sidebar = () => {
    const { user } = useAuth();

    return (
        <div className="w-64 bg-white shadow-md p-6">
            <div className="space-y-6">
                <div>
                    <h3 className="text-xs font-semibold text-gray-500 uppercase tracking-wider">
                        Security Attributes
                    </h3>
                    <div className="mt-2 space-y-1">
                        <div className="text-sm">
                            <span className="font-medium">Clearance:</span> {user?.clearance}
                        </div>
                        <div className="text-sm">
                            <span className="font-medium">Country:</span> {user?.countryOfAffiliation}
                        </div>
                        {user?.coiTags && (
                            <div className="text-sm">
                                <span className="font-medium">COI Tags:</span>
                                <div className="mt-1 space-y-1">
                                    {user.coiTags.map(tag => (
                                        <span 
                                            key={tag}
                                            className="inline-block px-2 py-1 text-xs bg-blue-100 text-blue-800 rounded mr-1"
                                        >
                                            {tag}
                                        </span>
                                    ))}
                                </div>
                            </div>
                        )}
                    </div>
                </div>

                <div>
                    <h3 className="text-xs font-semibold text-gray-500 uppercase tracking-wider">
                        Quick Actions
                    </h3>
                    <div className="mt-2 space-y-1">
                        <button 
                            className="w-full text-left px-2 py-1 text-sm text-blue-600 hover:bg-blue-50 rounded"
                            onClick={() => window.location.href = '/documents/new'}
                        >
                            Create New Document
                        </button>
                    </div>
                </div>
            </div>
        </div>
    );
};