// /frontend/src/app/layout.tsx
import { Inter } from 'next/font/google'
import ClientProvider from '@/components/ClientProvider'
import './globals.css'

const inter = Inter({ subsets: ['latin'] })

export const metadata = {
  title: 'DIVE25',
  description: 'DIVE25 Application',
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en">
      <body className={inter.className}>
        <ClientProvider>
          <main className="min-h-screen">
            {children}
          </main>
        </ClientProvider>
      </body>
    </html>
  )
}