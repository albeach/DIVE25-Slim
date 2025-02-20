'use client';

import { useState, useEffect } from 'react';

interface AuthState {
    isAuthenticated: boolean;
    loading: boolean;
    user: any | null;
}

export function useAuth() {
    const [authState, setAuthState] = useState<AuthState>({
        isAuthenticated: false,
        loading: true,
        user: null
    });

    useEffect(() => {
        async function checkAuthStatus() {
            try {
                const token = localStorage.getItem('token');
                if (token) {
                    // TODO: Validate token with backend
                    setAuthState({
                        isAuthenticated: true,
                        loading: false,
                        user: { token } // Replace with actual user data
                    });
                } else {
                    setAuthState({
                        isAuthenticated: false,
                        loading: false,
                        user: null
                    });
                }
            } catch (error) {
                console.error('Auth check failed:', error);
                setAuthState({
                    isAuthenticated: false,
                    loading: false,
                    user: null
                });
            }
        }

        checkAuthStatus();
    }, []);

    return authState;
} 