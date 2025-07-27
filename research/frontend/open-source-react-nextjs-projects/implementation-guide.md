# Implementation Guide: Building Production-Ready React Applications

Step-by-step guide to implementing patterns and best practices discovered from analyzing 15+ production-ready open source React and Next.js projects.

## 🎯 Project Setup & Architecture

### 1. Initial Project Setup

#### Option A: Next.js 14+ (Recommended for Most Projects)

```bash
# Create Next.js project with TypeScript
npx create-next-app@latest my-app --typescript --tailwind --eslint --app --src-dir --import-alias "@/*"

cd my-app

# Install essential dependencies
npm install zustand @tanstack/react-query @tanstack/react-query-devtools
npm install @hookform/resolvers react-hook-form zod
npm install @radix-ui/react-toast @radix-ui/react-dialog @radix-ui/react-dropdown-menu
npm install lucide-react class-variance-authority clsx tailwind-merge

# Install development dependencies
npm install -D @types/node prettier prettier-plugin-tailwindcss
npm install -D husky lint-staged @commitlint/cli @commitlint/config-conventional
```

#### Option B: Vite + React (For Non-SSR Applications)

```bash
# Create Vite project
npm create vite@latest my-app -- --template react-ts
cd my-app

# Install dependencies (same as above)
npm install
npm install zustand @tanstack/react-query @tanstack/react-query-devtools
# ... (rest of dependencies)
```

### 2. Project Structure Setup

Create the following folder structure based on production patterns:

```
src/
├── app/                    # Next.js App Router (or pages/)
│   ├── globals.css
│   ├── layout.tsx
│   └── page.tsx
├── components/
│   ├── ui/                 # Reusable UI components (buttons, inputs, etc.)
│   ├── forms/              # Form-specific components
│   ├── layouts/            # Page layouts
│   └── features/           # Feature-specific components
├── hooks/                  # Custom React hooks
├── lib/                    # Utilities and configurations
│   ├── api.ts             # API client configuration
│   ├── auth.ts            # Authentication utilities
│   ├── constants.ts       # Application constants
│   ├── types.ts           # Shared TypeScript types
│   ├── utils.ts           # General utilities
│   └── validations.ts     # Zod schemas
├── stores/                 # State management
│   ├── auth-store.ts      # Authentication state
│   ├── theme-store.ts     # Theme/UI state
│   └── feature-stores/    # Feature-specific stores
└── styles/                 # Global styles and Tailwind config
```

### 3. TypeScript Configuration

```json
// tsconfig.json
{
  "compilerOptions": {
    "target": "es5",
    "lib": ["dom", "dom.iterable", "es6"],
    "allowJs": true,
    "skipLibCheck": true,
    "strict": true,
    "noEmit": true,
    "esModuleInterop": true,
    "module": "esnext",
    "moduleResolution": "bundler",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "jsx": "preserve",
    "incremental": true,
    "plugins": [
      {
        "name": "next"
      }
    ],
    "baseUrl": ".",
    "paths": {
      "@/*": ["./src/*"],
      "@/components/*": ["./src/components/*"],
      "@/hooks/*": ["./src/hooks/*"],
      "@/lib/*": ["./src/lib/*"],
      "@/stores/*": ["./src/stores/*"]
    }
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx", ".next/types/**/*.ts"],
  "exclude": ["node_modules"]
}
```

---

## 🔧 State Management Implementation

### 1. Zustand Store Setup

```typescript
// src/stores/auth-store.ts
import { create } from 'zustand'
import { devtools, persist } from 'zustand/middleware'
import { immer } from 'zustand/middleware/immer'
import type { User } from '@/lib/types'

interface AuthState {
  user: User | null
  isAuthenticated: boolean
  accessToken: string | null
  isLoading: boolean
  error: string | null
}

interface AuthActions {
  login: (credentials: LoginCredentials) => Promise<void>
  logout: () => void
  setUser: (user: User) => void
  setError: (error: string | null) => void
  clearError: () => void
}

type AuthStore = AuthState & AuthActions

export const useAuthStore = create<AuthStore>()(
  devtools(
    persist(
      immer((set, get) => ({
        // Initial state
        user: null,
        isAuthenticated: false,
        accessToken: null,
        isLoading: false,
        error: null,

        // Actions
        login: async (credentials) => {
          set((state) => {
            state.isLoading = true
            state.error = null
          })

          try {
            const response = await fetch('/api/auth/login', {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify(credentials),
            })

            if (!response.ok) {
              throw new Error('Login failed')
            }

            const { user, accessToken } = await response.json()

            set((state) => {
              state.user = user
              state.accessToken = accessToken
              state.isAuthenticated = true
              state.isLoading = false
            })
          } catch (error) {
            set((state) => {
              state.error = error instanceof Error ? error.message : 'Login failed'
              state.isLoading = false
            })
          }
        },

        logout: () => {
          set((state) => {
            state.user = null
            state.accessToken = null
            state.isAuthenticated = false
            state.error = null
          })
          // Clear persisted data
          localStorage.removeItem('auth-storage')
        },

        setUser: (user) => {
          set((state) => {
            state.user = user
          })
        },

        setError: (error) => {
          set((state) => {
            state.error = error
          })
        },

        clearError: () => {
          set((state) => {
            state.error = null
          })
        },
      })),
      {
        name: 'auth-storage',
        partialize: (state) => ({
          user: state.user,
          accessToken: state.accessToken,
          isAuthenticated: state.isAuthenticated,
        }),
      }
    ),
    { name: 'auth-store' }
  )
)

// Selectors for better performance
export const useUser = () => useAuthStore((state) => state.user)
export const useIsAuthenticated = () => useAuthStore((state) => state.isAuthenticated)
export const useAuthActions = () => useAuthStore((state) => ({
  login: state.login,
  logout: state.logout,
  setUser: state.setUser,
  setError: state.setError,
  clearError: state.clearError,
}))
```

### 2. React Query Setup

```typescript
// src/lib/query-client.ts
import { QueryClient } from '@tanstack/react-query'

export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 5 * 60 * 1000, // 5 minutes
      cacheTime: 10 * 60 * 1000, // 10 minutes
      retry: (failureCount, error: any) => {
        // Don't retry on 4xx errors
        if (error?.status >= 400 && error?.status < 500) {
          return false
        }
        return failureCount < 3
      },
      refetchOnWindowFocus: false,
    },
    mutations: {
      retry: 1,
    },
  },
})

// src/app/layout.tsx (Next.js) or src/main.tsx (Vite)
'use client'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { ReactQueryDevtools } from '@tanstack/react-query-devtools'
import { queryClient } from '@/lib/query-client'

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en">
      <body>
        <QueryClientProvider client={queryClient}>
          {children}
          <ReactQueryDevtools initialIsOpen={false} />
        </QueryClientProvider>
      </body>
    </html>
  )
}
```

### 3. API Client Configuration

```typescript
// src/lib/api.ts
import { useAuthStore } from '@/stores/auth-store'

const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3000/api'

class ApiClient {
  private baseURL: string

  constructor(baseURL: string) {
    this.baseURL = baseURL
  }

  private getHeaders(): Record<string, string> {
    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
    }

    const token = useAuthStore.getState().accessToken
    if (token) {
      headers.Authorization = `Bearer ${token}`
    }

    return headers
  }

  private async request<T>(
    endpoint: string,
    options: RequestInit = {}
  ): Promise<T> {
    const url = `${this.baseURL}${endpoint}`
    const config: RequestInit = {
      headers: this.getHeaders(),
      ...options,
    }

    const response = await fetch(url, config)

    if (!response.ok) {
      // Handle authentication errors
      if (response.status === 401) {
        useAuthStore.getState().logout()
        throw new Error('Authentication required')
      }

      const errorData = await response.json().catch(() => ({}))
      throw new Error(errorData.message || `HTTP ${response.status}`)
    }

    return response.json()
  }

  // GET request
  async get<T>(endpoint: string): Promise<T> {
    return this.request<T>(endpoint, { method: 'GET' })
  }

  // POST request
  async post<T>(endpoint: string, data?: any): Promise<T> {
    return this.request<T>(endpoint, {
      method: 'POST',
      body: data ? JSON.stringify(data) : undefined,
    })
  }

  // PUT request
  async put<T>(endpoint: string, data?: any): Promise<T> {
    return this.request<T>(endpoint, {
      method: 'PUT',
      body: data ? JSON.stringify(data) : undefined,
    })
  }

  // PATCH request
  async patch<T>(endpoint: string, data?: any): Promise<T> {
    return this.request<T>(endpoint, {
      method: 'PATCH',
      body: data ? JSON.stringify(data) : undefined,
    })
  }

  // DELETE request
  async delete<T>(endpoint: string): Promise<T> {
    return this.request<T>(endpoint, { method: 'DELETE' })
  }
}

export const api = new ApiClient(API_BASE_URL)

// API hooks for specific endpoints
export const useApiQuery = <T>(
  key: string[],
  endpoint: string,
  options?: any
) => {
  return useQuery({
    queryKey: key,
    queryFn: () => api.get<T>(endpoint),
    ...options,
  })
}

export const useApiMutation = <T, V>(
  endpoint: string,
  method: 'POST' | 'PUT' | 'PATCH' | 'DELETE' = 'POST'
) => {
  return useMutation({
    mutationFn: (data: V) => {
      switch (method) {
        case 'POST':
          return api.post<T>(endpoint, data)
        case 'PUT':
          return api.put<T>(endpoint, data)
        case 'PATCH':
          return api.patch<T>(endpoint, data)
        case 'DELETE':
          return api.delete<T>(endpoint)
        default:
          throw new Error(`Unsupported method: ${method}`)
      }
    },
  })
}
```

---

## 🎨 UI Component System Implementation

### 1. Base UI Components with Radix + Tailwind

```typescript
// src/components/ui/button.tsx
import * as React from 'react'
import { cva, type VariantProps } from 'class-variance-authority'
import { cn } from '@/lib/utils'

const buttonVariants = cva(
  'inline-flex items-center justify-center rounded-md text-sm font-medium transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:opacity-50 disabled:pointer-events-none ring-offset-background',
  {
    variants: {
      variant: {
        default: 'bg-primary text-primary-foreground hover:bg-primary/90',
        destructive: 'bg-destructive text-destructive-foreground hover:bg-destructive/90',
        outline: 'border border-input hover:bg-accent hover:text-accent-foreground',
        secondary: 'bg-secondary text-secondary-foreground hover:bg-secondary/80',
        ghost: 'hover:bg-accent hover:text-accent-foreground',
        link: 'underline-offset-4 hover:underline text-primary',
      },
      size: {
        default: 'h-10 py-2 px-4',
        sm: 'h-9 px-3 rounded-md',
        lg: 'h-11 px-8 rounded-md',
        icon: 'h-10 w-10',
      },
    },
    defaultVariants: {
      variant: 'default',
      size: 'default',
    },
  }
)

export interface ButtonProps
  extends React.ButtonHTMLAttributes<HTMLButtonElement>,
    VariantProps<typeof buttonVariants> {
  asChild?: boolean
}

const Button = React.forwardRef<HTMLButtonElement, ButtonProps>(
  ({ className, variant, size, asChild = false, ...props }, ref) => {
    return (
      <button
        className={cn(buttonVariants({ variant, size, className }))}
        ref={ref}
        {...props}
      />
    )
  }
)
Button.displayName = 'Button'

export { Button, buttonVariants }

// src/components/ui/input.tsx
import * as React from 'react'
import { cn } from '@/lib/utils'

export interface InputProps
  extends React.InputHTMLAttributes<HTMLInputElement> {}

const Input = React.forwardRef<HTMLInputElement, InputProps>(
  ({ className, type, ...props }, ref) => {
    return (
      <input
        type={type}
        className={cn(
          'flex h-10 w-full rounded-md border border-input bg-transparent px-3 py-2 text-sm ring-offset-background file:border-0 file:bg-transparent file:text-sm file:font-medium placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50',
          className
        )}
        ref={ref}
        {...props}
      />
    )
  }
)
Input.displayName = 'Input'

export { Input }
```

### 2. Form Components with React Hook Form + Zod

```typescript
// src/components/forms/login-form.tsx
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { useAuthActions } from '@/stores/auth-store'
import { toast } from '@/hooks/use-toast'

const loginSchema = z.object({
  email: z.string().email('Invalid email address'),
  password: z.string().min(6, 'Password must be at least 6 characters'),
})

type LoginFormData = z.infer<typeof loginSchema>

export function LoginForm() {
  const { login } = useAuthActions()
  
  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<LoginFormData>({
    resolver: zodResolver(loginSchema),
  })

  const onSubmit = async (data: LoginFormData) => {
    try {
      await login(data)
      toast({
        title: 'Success',
        description: 'You have been logged in successfully.',
      })
    } catch (error) {
      toast({
        title: 'Error',
        description: error instanceof Error ? error.message : 'Login failed',
        variant: 'destructive',
      })
    }
  }

  return (
    <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
      <div className="space-y-2">
        <label htmlFor="email" className="text-sm font-medium">
          Email
        </label>
        <Input
          id="email"
          type="email"
          placeholder="Enter your email"
          {...register('email')}
        />
        {errors.email && (
          <p className="text-sm text-destructive">{errors.email.message}</p>
        )}
      </div>

      <div className="space-y-2">
        <label htmlFor="password" className="text-sm font-medium">
          Password
        </label>
        <Input
          id="password"
          type="password"
          placeholder="Enter your password"
          {...register('password')}
        />
        {errors.password && (
          <p className="text-sm text-destructive">{errors.password.message}</p>
        )}
      </div>

      <Button type="submit" className="w-full" disabled={isSubmitting}>
        {isSubmitting ? 'Signing in...' : 'Sign in'}
      </Button>
    </form>
  )
}
```

### 3. Data Fetching Hooks

```typescript
// src/hooks/use-products.ts
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { api } from '@/lib/api'
import { toast } from '@/hooks/use-toast'

export interface Product {
  id: string
  name: string
  description: string
  price: number
  category: string
  status: 'active' | 'inactive'
  created_at: string
  updated_at: string
}

export interface ProductFilters {
  search?: string
  category?: string
  status?: 'all' | 'active' | 'inactive'
}

export const useProducts = (filters?: ProductFilters) => {
  return useQuery({
    queryKey: ['products', filters],
    queryFn: () => api.get<Product[]>('/products'),
    staleTime: 5 * 60 * 1000, // 5 minutes
  })
}

export const useProduct = (id: string) => {
  return useQuery({
    queryKey: ['products', id],
    queryFn: () => api.get<Product>(`/products/${id}`),
    enabled: !!id,
  })
}

export const useCreateProduct = () => {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: (data: Omit<Product, 'id' | 'created_at' | 'updated_at'>) =>
      api.post<Product>('/products', data),
    onSuccess: (newProduct) => {
      // Update the products list with the new product
      queryClient.setQueryData(['products'], (oldData: Product[] | undefined) => {
        return oldData ? [...oldData, newProduct] : [newProduct]
      })
      
      toast({
        title: 'Success',
        description: 'Product created successfully.',
      })
    },
    onError: (error) => {
      toast({
        title: 'Error',
        description: error instanceof Error ? error.message : 'Failed to create product',
        variant: 'destructive',
      })
    },
  })
}

export const useUpdateProduct = () => {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: ({ id, data }: { id: string; data: Partial<Product> }) =>
      api.patch<Product>(`/products/${id}`, data),
    onMutate: async ({ id, data }) => {
      // Cancel outgoing refetches
      await queryClient.cancelQueries(['products'])
      await queryClient.cancelQueries(['products', id])

      // Snapshot previous values
      const previousProducts = queryClient.getQueryData(['products'])
      const previousProduct = queryClient.getQueryData(['products', id])

      // Optimistically update
      queryClient.setQueryData(['products'], (oldData: Product[] | undefined) => {
        return oldData?.map(product =>
          product.id === id ? { ...product, ...data } : product
        ) || []
      })

      queryClient.setQueryData(['products', id], (oldData: Product | undefined) => {
        return oldData ? { ...oldData, ...data } : undefined
      })

      return { previousProducts, previousProduct }
    },
    onError: (error, variables, context) => {
      // Rollback on error
      if (context?.previousProducts) {
        queryClient.setQueryData(['products'], context.previousProducts)
      }
      if (context?.previousProduct) {
        queryClient.setQueryData(['products', variables.id], context.previousProduct)
      }
      
      toast({
        title: 'Error',
        description: error instanceof Error ? error.message : 'Failed to update product',
        variant: 'destructive',
      })
    },
    onSettled: () => {
      queryClient.invalidateQueries(['products'])
    },
    onSuccess: () => {
      toast({
        title: 'Success',
        description: 'Product updated successfully.',
      })
    },
  })
}

export const useDeleteProduct = () => {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: (id: string) => api.delete(`/products/${id}`),
    onSuccess: (_, deletedId) => {
      // Remove from products list
      queryClient.setQueryData(['products'], (oldData: Product[] | undefined) => {
        return oldData?.filter(product => product.id !== deletedId) || []
      })
      
      // Remove individual product cache
      queryClient.removeQueries(['products', deletedId])
      
      toast({
        title: 'Success',
        description: 'Product deleted successfully.',
      })
    },
    onError: (error) => {
      toast({
        title: 'Error',
        description: error instanceof Error ? error.message : 'Failed to delete product',
        variant: 'destructive',
      })
    },
  })
}
```

---

## 🔐 Authentication Implementation

### 1. NextAuth.js Setup (Recommended)

```bash
npm install next-auth
```

```typescript
// src/app/api/auth/[...nextauth]/route.ts
import NextAuth from 'next-auth'
import { NextAuthOptions } from 'next-auth'
import CredentialsProvider from 'next-auth/providers/credentials'
import GoogleProvider from 'next-auth/providers/google'

export const authOptions: NextAuthOptions = {
  providers: [
    GoogleProvider({
      clientId: process.env.GOOGLE_CLIENT_ID!,
      clientSecret: process.env.GOOGLE_CLIENT_SECRET!,
    }),
    CredentialsProvider({
      name: 'credentials',
      credentials: {
        email: { label: 'Email', type: 'email' },
        password: { label: 'Password', type: 'password' },
      },
      async authorize(credentials) {
        if (!credentials?.email || !credentials?.password) {
          return null
        }

        try {
          const response = await fetch(`${process.env.NEXTAUTH_URL}/api/auth/login`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(credentials),
          })

          if (!response.ok) {
            return null
          }

          const user = await response.json()
          return user
        } catch (error) {
          return null
        }
      },
    }),
  ],
  session: {
    strategy: 'jwt',
  },
  callbacks: {
    async jwt({ token, user }) {
      if (user) {
        token.id = user.id
        token.role = user.role
      }
      return token
    },
    async session({ session, token }) {
      if (token) {
        session.user.id = token.id as string
        session.user.role = token.role as string
      }
      return session
    },
  },
  pages: {
    signIn: '/auth/signin',
    error: '/auth/error',
  },
}

const handler = NextAuth(authOptions)
export { handler as GET, handler as POST }

// src/hooks/use-auth.ts
import { useSession, signIn, signOut } from 'next-auth/react'

export const useAuth = () => {
  const { data: session, status } = useSession()

  return {
    user: session?.user,
    isLoading: status === 'loading',
    isAuthenticated: !!session,
    login: signIn,
    logout: signOut,
  }
}

// src/components/auth/auth-provider.tsx
'use client'
import { SessionProvider } from 'next-auth/react'

export function AuthProvider({ children }: { children: React.ReactNode }) {
  return <SessionProvider>{children}</SessionProvider>
}
```

### 2. Protected Routes Implementation

```typescript
// src/components/auth/auth-guard.tsx
import { useAuth } from '@/hooks/use-auth'
import { useRouter } from 'next/navigation'
import { useEffect } from 'react'

interface AuthGuardProps {
  children: React.ReactNode
  requireAuth?: boolean
  redirectTo?: string
}

export function AuthGuard({ 
  children, 
  requireAuth = true, 
  redirectTo = '/auth/signin' 
}: AuthGuardProps) {
  const { isAuthenticated, isLoading } = useAuth()
  const router = useRouter()

  useEffect(() => {
    if (!isLoading && requireAuth && !isAuthenticated) {
      router.push(redirectTo)
    }
  }, [isLoading, requireAuth, isAuthenticated, router, redirectTo])

  if (isLoading) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="animate-spin rounded-full h-32 w-32 border-b-2 border-primary"></div>
      </div>
    )
  }

  if (requireAuth && !isAuthenticated) {
    return null
  }

  return <>{children}</>
}

// src/app/dashboard/layout.tsx
import { AuthGuard } from '@/components/auth/auth-guard'

export default function DashboardLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <AuthGuard requireAuth>
      <div className="dashboard-layout">
        {children}
      </div>
    </AuthGuard>
  )
}
```

---

## 🚀 Performance Optimization

### 1. Code Splitting and Lazy Loading

```typescript
// src/components/lazy-imports.ts
import { lazy } from 'react'

// Lazy load heavy components
export const ChartComponent = lazy(() => 
  import('./charts/chart-component').then(module => ({
    default: module.ChartComponent
  }))
)

export const DataTable = lazy(() => 
  import('./tables/data-table').then(module => ({
    default: module.DataTable
  }))
)

// Usage with Suspense
import { Suspense } from 'react'
import { ChartComponent } from '@/components/lazy-imports'

function Dashboard() {
  return (
    <div>
      <h1>Dashboard</h1>
      <Suspense fallback={<div>Loading chart...</div>}>
        <ChartComponent />
      </Suspense>
    </div>
  )
}
```

### 2. Image Optimization

```typescript
// src/components/optimized-image.tsx
import Image from 'next/image'

interface OptimizedImageProps {
  src: string
  alt: string
  width?: number
  height?: number
  priority?: boolean
  className?: string
}

export function OptimizedImage({
  src,
  alt,
  width = 400,
  height = 300,
  priority = false,
  className,
}: OptimizedImageProps) {
  return (
    <Image
      src={src}
      alt={alt}
      width={width}
      height={height}
      priority={priority}
      className={className}
      sizes="(max-width: 768px) 100vw, (max-width: 1200px) 50vw, 33vw"
      placeholder="blur"
      blurDataURL="data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAYEBQYFBAYGBQYHBwYIChAKCgkJChQODwwQFxQYGBcUFhYaHSUfGhsjHBYWICwgIyYnKSopGR8tMC0oMCUoKSj/2wBDAQcHBwoIChMKChMoGhYaKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCj/wAARCAAIAAoDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAv/xAAhEAACAQMDBQAAAAAAAAAAAAABAgMABAUGIWGRkbHB0f/EABUBAQEAAAAAAAAAAAAAAAAAAAMF/8QAGhEAAgIDAAAAAAAAAAAAAAAAAAECEgMRkf/aAAwDAQACEQMRAD8AltJagyeH0AthI5xdrLcNM91BF5pX2HaH9bcfaSXWGaRmknyJckliyjqTzSlT54b6bk+h0R//2Q=="
    />
  )
}
```

### 3. Bundle Analysis and Optimization

```json
// package.json scripts
{
  "scripts": {
    "analyze": "ANALYZE=true next build",
    "build": "next build",
    "dev": "next dev",
    "start": "next start"
  }
}
```

```typescript
// next.config.js
/** @type {import('next').NextConfig} */
const nextConfig = {
  experimental: {
    appDir: true,
  },
  images: {
    domains: ['example.com'],
    formats: ['image/webp', 'image/avif'],
  },
  // Bundle analyzer
  ...(process.env.ANALYZE === 'true' && {
    webpack: (config) => {
      config.plugins.push(
        new (require('@next/bundle-analyzer'))({
          enabled: true,
        })
      )
      return config
    },
  }),
}

module.exports = nextConfig
```

---

## 🧪 Testing Setup

### 1. Jest and React Testing Library Configuration

```bash
npm install -D jest jest-environment-jsdom @testing-library/react @testing-library/jest-dom
```

```typescript
// jest.config.js
const nextJest = require('next/jest')

const createJestConfig = nextJest({
  dir: './',
})

const customJestConfig = {
  setupFilesAfterEnv: ['<rootDir>/jest.setup.js'],
  moduleNameMapping: {
    '^@/(.*)$': '<rootDir>/src/$1',
  },
  testEnvironment: 'jest-environment-jsdom',
}

module.exports = createJestConfig(customJestConfig)

// jest.setup.js
import '@testing-library/jest-dom'

// src/lib/test-utils.tsx
import { render, RenderOptions } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { ReactElement, ReactNode } from 'react'

const createTestQueryClient = () =>
  new QueryClient({
    defaultOptions: {
      queries: {
        retry: false,
      },
      mutations: {
        retry: false,
      },
    },
  })

const AllTheProviders = ({ children }: { children: ReactNode }) => {
  const testQueryClient = createTestQueryClient()

  return (
    <QueryClientProvider client={testQueryClient}>
      {children}
    </QueryClientProvider>
  )
}

const customRender = (
  ui: ReactElement,
  options?: Omit<RenderOptions, 'wrapper'>
) => render(ui, { wrapper: AllTheProviders, ...options })

export * from '@testing-library/react'
export { customRender as render }
```

### 2. Component Testing Examples

```typescript
// src/components/__tests__/login-form.test.tsx
import { render, screen, fireEvent, waitFor } from '@/lib/test-utils'
import { LoginForm } from '@/components/forms/login-form'

jest.mock('@/stores/auth-store', () => ({
  useAuthActions: () => ({
    login: jest.fn(),
  }),
}))

describe('LoginForm', () => {
  it('renders login form correctly', () => {
    render(<LoginForm />)
    
    expect(screen.getByLabelText(/email/i)).toBeInTheDocument()
    expect(screen.getByLabelText(/password/i)).toBeInTheDocument()
    expect(screen.getByRole('button', { name: /sign in/i })).toBeInTheDocument()
  })

  it('validates form fields', async () => {
    render(<LoginForm />)
    
    const submitButton = screen.getByRole('button', { name: /sign in/i })
    fireEvent.click(submitButton)

    await waitFor(() => {
      expect(screen.getByText(/invalid email address/i)).toBeInTheDocument()
    })
  })

  it('submits form with valid data', async () => {
    const mockLogin = jest.fn()
    jest.mocked(useAuthActions).mockReturnValue({ login: mockLogin })

    render(<LoginForm />)
    
    fireEvent.change(screen.getByLabelText(/email/i), {
      target: { value: 'test@example.com' },
    })
    fireEvent.change(screen.getByLabelText(/password/i), {
      target: { value: 'password123' },
    })
    
    fireEvent.click(screen.getByRole('button', { name: /sign in/i }))

    await waitFor(() => {
      expect(mockLogin).toHaveBeenCalledWith({
        email: 'test@example.com',
        password: 'password123',
      })
    })
  })
})
```

---

## 🔧 Development Tools Configuration

### 1. ESLint and Prettier

```json
// .eslintrc.json
{
  "extends": [
    "next/core-web-vitals",
    "@typescript-eslint/recommended"
  ],
  "rules": {
    "@typescript-eslint/no-unused-vars": "error",
    "@typescript-eslint/no-explicit-any": "warn",
    "prefer-const": "error",
    "no-var": "error"
  }
}

// .prettierrc
{
  "semi": false,
  "trailingComma": "es5",
  "singleQuote": true,
  "tabWidth": 2,
  "useTabs": false,
  "printWidth": 80,
  "plugins": ["prettier-plugin-tailwindcss"]
}
```

### 2. Husky and lint-staged

```bash
npx husky-init && npm install
npm install -D lint-staged
```

```json
// package.json
{
  "lint-staged": {
    "*.{js,jsx,ts,tsx}": [
      "eslint --fix",
      "prettier --write"
    ],
    "*.{json,md,yml,yaml}": [
      "prettier --write"
    ]
  }
}

// .husky/pre-commit
#!/usr/bin/env sh
. "$(dirname -- "$0")/_/husky.sh"

npx lint-staged
```

---

## 📚 Key Implementation Checklist

### ✅ Project Setup
- [ ] Initialize project with TypeScript and Tailwind CSS
- [ ] Configure folder structure following production patterns
- [ ] Set up TypeScript with proper path aliases
- [ ] Configure ESLint, Prettier, and pre-commit hooks

### ✅ State Management
- [ ] Set up Zustand stores for client state
- [ ] Configure React Query for server state
- [ ] Implement authentication store with persistence
- [ ] Create API client with error handling

### ✅ UI Components
- [ ] Implement base UI components with Radix and CVA
- [ ] Create form components with React Hook Form and Zod
- [ ] Set up toast notifications and error handling
- [ ] Configure responsive design with Tailwind CSS

### ✅ Authentication
- [ ] Implement NextAuth.js or custom authentication
- [ ] Create protected route components
- [ ] Set up JWT token handling and refresh logic
- [ ] Add role-based access control

### ✅ Performance
- [ ] Implement code splitting and lazy loading
- [ ] Optimize images with Next.js Image component
- [ ] Set up bundle analysis and monitoring
- [ ] Configure caching strategies

### ✅ Testing
- [ ] Set up Jest and React Testing Library
- [ ] Create test utilities with providers
- [ ] Write component and integration tests
- [ ] Configure coverage reporting

### ✅ Development Experience
- [ ] Configure TypeScript strict mode
- [ ] Set up hot reload and development server
- [ ] Add debugging tools and DevTools extensions
- [ ] Create development scripts and commands

This implementation guide provides a solid foundation for building production-ready React applications based on patterns observed in successful open source projects.