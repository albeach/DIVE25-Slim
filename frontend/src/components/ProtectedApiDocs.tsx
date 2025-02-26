import { useAuth } from '@/contexts/AuthContext';
import SwaggerUI from 'swagger-ui-react';
import 'swagger-ui-react/swagger-ui.css';

export default function ProtectedApiDocs({ spec }: { spec: any }) {
  const { isAuthenticated, token } = useAuth();

  if (!isAuthenticated) {
    return (
      <div className="p-8 text-center">
        <h2 className="text-xl mb-4">Authentication Required</h2>
        <p>Please log in to view the API documentation.</p>
      </div>
    );
  }

  const requestInterceptor = (req: any) => {
    if (token) {
      req.headers.Authorization = `Bearer ${token}`;
    }
    return req;
  };

  return (
    <SwaggerUI 
      spec={spec} 
      requestInterceptor={requestInterceptor}
    />
  );
} 