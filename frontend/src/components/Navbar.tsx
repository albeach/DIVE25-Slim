// /frontend/src/components/Navbar.tsx
import { useAuth } from '@/contexts/AuthContext';
import Link from 'next/link';

export const Navbar = () => {
    const { user, logout } = useAuth();

    return (
        <nav className="bg-gray-800 text-white">
            <div className="max-w-7xl mx-auto px-4">
                <div className="flex items-center justify-between h-16">
                    <div className="flex items-center">
                        <Link href="/" className="text-xl font-bold">
                            DIVE25
                        </Link>
                        <div className="ml-10 flex items-baseline space-x-4">
                            <Link 
                                href="/documents" 
                                className="px-3 py-2 rounded-md text-sm font-medium hover:bg-gray-700"
                            >
                                Documents
                            </Link>
                        </div>
                    </div>
                    
                    <div className="flex items-center">
                        {user && (
                            <div className="flex items-center space-x-4">
                                <span className="text-sm">
                                    {user.preferred_username}
                                </span>
                                <span className="px-2 py-1 text-xs bg-red-700 rounded">
                                    {user.clearance}
                                </span>
                                <button
                                    onClick={logout}
                                    className="px-3 py-2 rounded-md text-sm font-medium hover:bg-gray-700"
                                >
                                    Logout
                                </button>
                            </div>
                        )}
                    </div>
                </div>
            </div>
        </nav>
    );
}