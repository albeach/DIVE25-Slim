// /frontend/src/components/Sidebar.tsx
'use client';

import { useAuth } from '@/contexts/AuthContext';
import Link from 'next/link';

export const Sidebar = () => {
    const { user, isAuthenticated } = useAuth();

    return (
        <div className="w-64 bg-gray-100 min-h-screen p-4">
            {isAuthenticated && user && (
                <div>
                    <h2 className="text-lg font-semibold">User Info</h2>
                    <div className="mt-2 space-y-1">
                        <div className="text-sm">
                            <span className="font-medium">Clearance:</span> {user.securityAttributes?.clearance}
                        </div>
                        <div className="text-sm">
                            <span className="font-medium">Country:</span> {user.securityAttributes?.releasableTo?.[0]}
                        </div>
                    </div>
                    <hr className="my-4" />
                    <nav>
                        <ul className="space-y-2">
                            <li>
                                <Link href="/documents" className="text-blue-600 hover:text-blue-800">
                                    Documents
                                </Link>
                            </li>
                        </ul>
                    </nav>
                </div>
            )}
        </div>
    );
};