// /frontend/src/components/Navbar.tsx
'use client';

import { useAuth } from '@/contexts/AuthContext';
import Link from 'next/link';

export const Navbar = () => {
    const { user, isAuthenticated, logout } = useAuth();

    return (
        <nav className="bg-gray-800 text-white p-4">
            <div className="container mx-auto flex justify-between items-center">
                <Link href="/" className="text-xl font-bold">DIVE25</Link>
                {isAuthenticated && user && (
                    <div className="flex items-center gap-4">
                        <span className="text-sm">
                            {user.preferred_username}
                        </span>
                        {user.securityAttributes && (
                            <span className="px-2 py-1 text-xs bg-red-700 rounded">
                                {user.securityAttributes.clearance}
                            </span>
                        )}
                        <button
                            onClick={logout}
                            className="text-sm bg-red-600 px-3 py-1 rounded hover:bg-red-700"
                        >
                            Logout
                        </button>
                    </div>
                )}
            </div>
        </nav>
    );
};