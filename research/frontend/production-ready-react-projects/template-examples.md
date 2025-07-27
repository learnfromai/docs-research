# Template Examples - Production React/Next.js Code Patterns

## 🎯 Overview

This document provides copy-paste ready code templates extracted from the top production React/Next.js projects analyzed. These templates represent proven patterns used by applications with 10K+ stars and active maintenance.

## 🚀 Project Setup Templates

### 1. Next.js 14 Project Template (Based on Formbricks)

#### package.json
```json
{
  "name": "production-nextjs-app",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "lint": "next lint",
    "lint:fix": "next lint --fix",
    "type-check": "tsc --noEmit",
    "test": "jest",
    "test:watch": "jest --watch",
    "test:coverage": "jest --coverage"
  },
  "dependencies": {
    "@clerk/nextjs": "^4.29.1",
    "@hookform/resolvers": "^3.3.2",
    "@radix-ui/react-dialog": "^1.0.5",
    "@radix-ui/react-dropdown-menu": "^2.0.6",
    "@radix-ui/react-select": "^2.0.0",
    "@tanstack/react-query": "^5.8.4",
    "class-variance-authority": "^0.7.0",
    "clsx": "^2.0.0",
    "lucide-react": "^0.294.0",
    "next": "14.0.3",
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-hook-form": "^7.48.2",
    "tailwind-merge": "^2.0.0",
    "tailwindcss-animate": "^1.0.7",
    "zod": "^3.22.4",
    "zustand": "^4.4.7"
  },
  "devDependencies": {
    "@next/bundle-analyzer": "^14.0.3",
    "@types/node": "^20.9.0",
    "@types/react": "^18.2.37",
    "@types/react-dom": "^18.2.15",
    "autoprefixer": "^10.4.16",
    "eslint": "^8.54.0",
    "eslint-config-next": "14.0.3",
    "postcss": "^8.4.31",
    "tailwindcss": "^3.3.5",
    "typescript": "^5.2.2"
  }
}
```

#### next.config.js
```javascript
/** @type {import('next').NextConfig} */
const nextConfig = {
  experimental: {
    serverComponentsExternalPackages: ['@prisma/client']
  },
  images: {
    domains: ['images.unsplash.com', 'avatars.githubusercontent.com'],
    formats: ['image/avif', 'image/webp']
  },
  webpack: (config) => {
    config.externals.push('@node-rs/argon2', '@node-rs/bcrypt')
    return config
  }
}

const withBundleAnalyzer = require('@next/bundle-analyzer')({
  enabled: process.env.ANALYZE === 'true'
})

module.exports = withBundleAnalyzer(nextConfig)
```

#### tailwind.config.js
```javascript
/** @type {import('tailwindcss').Config} */
module.exports = {
  darkMode: ["class"],
  content: [
    './pages/**/*.{ts,tsx}',
    './components/**/*.{ts,tsx}',
    './app/**/*.{ts,tsx}',
    './src/**/*.{ts,tsx}',
  ],
  theme: {
    container: {
      center: true,
      padding: "2rem",
      screens: {
        "2xl": "1400px",
      },
    },
    extend: {
      colors: {
        border: "hsl(var(--border))",
        input: "hsl(var(--input))",
        ring: "hsl(var(--ring))",
        background: "hsl(var(--background))",
        foreground: "hsl(var(--foreground))",
        primary: {
          DEFAULT: "hsl(var(--primary))",
          foreground: "hsl(var(--primary-foreground))",
        },
        secondary: {
          DEFAULT: "hsl(var(--secondary))",
          foreground: "hsl(var(--secondary-foreground))",
        },
        destructive: {
          DEFAULT: "hsl(var(--destructive))",
          foreground: "hsl(var(--destructive-foreground))",
        },
        muted: {
          DEFAULT: "hsl(var(--muted))",
          foreground: "hsl(var(--muted-foreground))",
        },
        accent: {
          DEFAULT: "hsl(var(--accent))",
          foreground: "hsl(var(--accent-foreground))",
        },
        popover: {
          DEFAULT: "hsl(var(--popover))",
          foreground: "hsl(var(--popover-foreground))",
        },
        card: {
          DEFAULT: "hsl(var(--card))",
          foreground: "hsl(var(--card-foreground))",
        },
      },
      borderRadius: {
        lg: "var(--radius)",
        md: "calc(var(--radius) - 2px)",
        sm: "calc(var(--radius) - 4px)",
      },
      keyframes: {
        "accordion-down": {
          from: { height: 0 },
          to: { height: "var(--radix-accordion-content-height)" },
        },
        "accordion-up": {
          from: { height: "var(--radix-accordion-content-height)" },
          to: { height: 0 },
        },
      },
      animation: {
        "accordion-down": "accordion-down 0.2s ease-out",
        "accordion-up": "accordion-up 0.2s ease-out",
      },
    },
  },
  plugins: [require("tailwindcss-animate")],
}
```

## 🧠 State Management Templates

### 1. Zustand Store Template (Production Pattern)

#### stores/auth-store.ts
```typescript
import { create } from 'zustand'
import { persist, createJSONStorage } from 'zustand/middleware'

export interface User {
  id: string
  email: string
  name: string
  avatar?: string
  role: 'admin' | 'user' | 'guest'
  permissions: string[]
}

interface AuthState {
  // State
  user: User | null
  isLoading: boolean
  isAuthenticated: boolean
  
  // Actions
  setUser: (user: User) => void
  updateUser: (updates: Partial<User>) => void
  logout: () => void
  setLoading: (loading: boolean) => void
  
  // Computed
  hasPermission: (permission: string) => boolean
  isAdmin: () => boolean
}

export const useAuthStore = create<AuthState>()(
  persist(
    (set, get) => ({
      // Initial state
      user: null,
      isLoading: false,
      isAuthenticated: false,

      // Actions
      setUser: (user) => set({ 
        user, 
        isAuthenticated: true,
        isLoading: false 
      }),

      updateUser: (updates) => set((state) => ({
        user: state.user ? { ...state.user, ...updates } : null
      })),

      logout: () => set({ 
        user: null, 
        isAuthenticated: false,
        isLoading: false 
      }),

      setLoading: (isLoading) => set({ isLoading }),

      // Computed getters
      hasPermission: (permission) => {
        const { user } = get()
        return user?.permissions.includes(permission) ?? false
      },

      isAdmin: () => {
        const { user } = get()
        return user?.role === 'admin'
      }
    }),
    {
      name: 'auth-storage',
      storage: createJSONStorage(() => localStorage),
      partialize: (state) => ({ 
        user: state.user,
        isAuthenticated: state.isAuthenticated 
      })
    }
  )
)
```

#### stores/app-store.ts
```typescript
import { create } from 'zustand'
import { subscribeWithSelector } from 'zustand/middleware'

interface Toast {
  id: string
  type: 'success' | 'error' | 'warning' | 'info'
  title: string
  description?: string
  duration?: number
}

interface AppState {
  // UI State
  theme: 'light' | 'dark' | 'system'
  sidebar: {
    isOpen: boolean
    isCollapsed: boolean
  }
  
  // Global UI
  toasts: Toast[]
  modals: Record<string, boolean>
  isPageLoading: boolean
  
  // Actions
  setTheme: (theme: 'light' | 'dark' | 'system') => void
  toggleSidebar: () => void
  collapseSidebar: (collapsed: boolean) => void
  
  // Toast management
  addToast: (toast: Omit<Toast, 'id'>) => void
  removeToast: (id: string) => void
  clearToasts: () => void
  
  // Modal management
  openModal: (modalId: string) => void
  closeModal: (modalId: string) => void
  toggleModal: (modalId: string) => void
  
  // Loading states
  setPageLoading: (loading: boolean) => void
}

export const useAppStore = create<AppState>()(
  subscribeWithSelector((set, get) => ({
    // Initial state
    theme: 'system',
    sidebar: {
      isOpen: true,
      isCollapsed: false
    },
    toasts: [],
    modals: {},
    isPageLoading: false,

    // Theme actions
    setTheme: (theme) => set({ theme }),

    // Sidebar actions
    toggleSidebar: () => set((state) => ({
      sidebar: { ...state.sidebar, isOpen: !state.sidebar.isOpen }
    })),

    collapseSidebar: (isCollapsed) => set((state) => ({
      sidebar: { ...state.sidebar, isCollapsed }
    })),

    // Toast actions
    addToast: (toast) => {
      const id = Math.random().toString(36).slice(2)
      const newToast = { ...toast, id }
      
      set((state) => ({
        toasts: [...state.toasts, newToast]
      }))

      // Auto remove after duration
      const duration = toast.duration ?? 5000
      setTimeout(() => {
        get().removeToast(id)
      }, duration)
    },

    removeToast: (id) => set((state) => ({
      toasts: state.toasts.filter(toast => toast.id !== id)
    })),

    clearToasts: () => set({ toasts: [] }),

    // Modal actions
    openModal: (modalId) => set((state) => ({
      modals: { ...state.modals, [modalId]: true }
    })),

    closeModal: (modalId) => set((state) => ({
      modals: { ...state.modals, [modalId]: false }
    })),

    toggleModal: (modalId) => set((state) => ({
      modals: { ...state.modals, [modalId]: !state.modals[modalId] }
    })),

    // Loading actions
    setPageLoading: (isPageLoading) => set({ isPageLoading })
  }))
)

// Subscribe to theme changes
useAppStore.subscribe(
  (state) => state.theme,
  (theme) => {
    if (typeof window !== 'undefined') {
      if (theme === 'system') {
        const isDark = window.matchMedia('(prefers-color-scheme: dark)').matches
        document.documentElement.classList.toggle('dark', isDark)
      } else {
        document.documentElement.classList.toggle('dark', theme === 'dark')
      }
    }
  }
)
```

### 2. React Query Setup Template

#### lib/react-query.tsx
```typescript
'use client'

import { QueryClient, QueryClientProvider, isServer } from '@tanstack/react-query'
import { ReactQueryDevtools } from '@tanstack/react-query-devtools'
import { ReactNode, useState } from 'react'

function makeQueryClient() {
  return new QueryClient({
    defaultOptions: {
      queries: {
        staleTime: 60 * 1000, // 1 minute
        gcTime: 1000 * 60 * 60 * 24, // 24 hours
        retry: (failureCount, error) => {
          // Don't retry on 4xx errors except 408, 429
          if (error instanceof Error && 'status' in error) {
            const status = (error as any).status
            if (status >= 400 && status < 500 && ![408, 429].includes(status)) {
              return false
            }
          }
          return failureCount < 3
        },
        retryDelay: (attemptIndex) => Math.min(1000 * 2 ** attemptIndex, 30000),
      },
      mutations: {
        retry: 1,
        onError: (error) => {
          console.error('Mutation error:', error)
        }
      }
    }
  })
}

let browserQueryClient: QueryClient | undefined = undefined

function getQueryClient() {
  if (isServer) {
    return makeQueryClient()
  } else {
    if (!browserQueryClient) browserQueryClient = makeQueryClient()
    return browserQueryClient
  }
}

interface QueryProviderProps {
  children: ReactNode
}

export function QueryProvider({ children }: QueryProviderProps) {
  const queryClient = getQueryClient()

  return (
    <QueryClientProvider client={queryClient}>
      {children}
      <ReactQueryDevtools initialIsOpen={false} />
    </QueryClientProvider>
  )
}
```

#### hooks/use-api.ts
```typescript
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { useAuthStore } from '@/stores/auth-store'
import { useAppStore } from '@/stores/app-store'

// Types
export interface Project {
  id: string
  name: string
  description: string
  userId: string
  createdAt: string
  updatedAt: string
}

export interface CreateProjectData {
  name: string
  description?: string
}

// API functions
const api = {
  getProjects: async (): Promise<Project[]> => {
    const response = await fetch('/api/projects')
    if (!response.ok) throw new Error('Failed to fetch projects')
    return response.json()
  },

  getProject: async (id: string): Promise<Project> => {
    const response = await fetch(`/api/projects/${id}`)
    if (!response.ok) throw new Error('Failed to fetch project')
    return response.json()
  },

  createProject: async (data: CreateProjectData): Promise<Project> => {
    const response = await fetch('/api/projects', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data)
    })
    if (!response.ok) throw new Error('Failed to create project')
    return response.json()
  },

  updateProject: async (id: string, data: Partial<CreateProjectData>): Promise<Project> => {
    const response = await fetch(`/api/projects/${id}`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data)
    })
    if (!response.ok) throw new Error('Failed to update project')
    return response.json()
  },

  deleteProject: async (id: string): Promise<void> => {
    const response = await fetch(`/api/projects/${id}`, {
      method: 'DELETE'
    })
    if (!response.ok) throw new Error('Failed to delete project')
  }
}

// Custom hooks
export function useProjects() {
  const { isAuthenticated } = useAuthStore()
  
  return useQuery({
    queryKey: ['projects'],
    queryFn: api.getProjects,
    enabled: isAuthenticated,
    staleTime: 5 * 60 * 1000, // 5 minutes
  })
}

export function useProject(id: string) {
  return useQuery({
    queryKey: ['projects', id],
    queryFn: () => api.getProject(id),
    enabled: !!id,
  })
}

export function useCreateProject() {
  const queryClient = useQueryClient()
  const { addToast } = useAppStore()
  
  return useMutation({
    mutationFn: api.createProject,
    onMutate: async (newProject) => {
      // Cancel outgoing queries
      await queryClient.cancelQueries({ queryKey: ['projects'] })
      
      // Snapshot previous value
      const previousProjects = queryClient.getQueryData(['projects'])
      
      // Optimistically update
      queryClient.setQueryData(['projects'], (old: Project[] | undefined) => [
        ...(old ?? []),
        { ...newProject, id: `temp-${Date.now()}`, userId: 'temp', createdAt: new Date().toISOString(), updatedAt: new Date().toISOString() }
      ])
      
      return { previousProjects }
    },
    onError: (err, variables, context) => {
      // Revert on error
      if (context?.previousProjects) {
        queryClient.setQueryData(['projects'], context.previousProjects)
      }
      addToast({
        type: 'error',
        title: 'Failed to create project',
        description: err.message
      })
    },
    onSuccess: (data) => {
      queryClient.invalidateQueries({ queryKey: ['projects'] })
      addToast({
        type: 'success',
        title: 'Project created',
        description: `${data.name} has been created successfully`
      })
    }
  })
}

export function useUpdateProject() {
  const queryClient = useQueryClient()
  const { addToast } = useAppStore()
  
  return useMutation({
    mutationFn: ({ id, ...data }: { id: string } & Partial<CreateProjectData>) =>
      api.updateProject(id, data),
    onSuccess: (data) => {
      queryClient.setQueryData(['projects', data.id], data)
      queryClient.invalidateQueries({ queryKey: ['projects'] })
      addToast({
        type: 'success',
        title: 'Project updated',
        description: `${data.name} has been updated successfully`
      })
    },
    onError: (error) => {
      addToast({
        type: 'error',
        title: 'Failed to update project',
        description: error.message
      })
    }
  })
}

export function useDeleteProject() {
  const queryClient = useQueryClient()
  const { addToast } = useAppStore()
  
  return useMutation({
    mutationFn: api.deleteProject,
    onSuccess: (_, deletedId) => {
      queryClient.invalidateQueries({ queryKey: ['projects'] })
      queryClient.removeQueries({ queryKey: ['projects', deletedId] })
      addToast({
        type: 'success',
        title: 'Project deleted',
        description: 'Project has been deleted successfully'
      })
    },
    onError: (error) => {
      addToast({
        type: 'error',
        title: 'Failed to delete project',
        description: error.message
      })
    }
  })
}
```

## 🔐 Authentication Templates

### 1. Clerk Integration Template

#### middleware.ts
```typescript
import { authMiddleware } from '@clerk/nextjs'

export default authMiddleware({
  publicRoutes: [
    '/',
    '/about',
    '/pricing',
    '/blog',
    '/blog/(.*)',
    '/api/webhooks/(.*)',
    '/api/health'
  ],
  ignoredRoutes: [
    '/api/health',
    '/api/metrics',
    '/_next/(.*)',
    '/favicon.ico',
    '/robots.txt',
    '/sitemap.xml'
  ],
  afterAuth(auth, req) {
    // Redirect unauthenticated users to sign in
    if (!auth.userId && !auth.isPublicRoute) {
      const signInUrl = new URL('/sign-in', req.url)
      signInUrl.searchParams.set('redirect_url', req.url)
      return Response.redirect(signInUrl)
    }

    // Redirect authenticated users away from auth pages
    if (auth.userId && ['/sign-in', '/sign-up'].includes(req.nextUrl.pathname)) {
      return Response.redirect(new URL('/dashboard', req.url))
    }

    // Handle organization selection
    if (auth.userId && !auth.orgId && req.nextUrl.pathname.startsWith('/dashboard')) {
      const orgSelection = new URL('/org-selection', req.url)
      return Response.redirect(orgSelection)
    }
  }
})

export const config = {
  matcher: ['/((?!.+\\.[\\w]+$|_next).*)', '/', '/(api|trpc)(.*)']
}
```

#### app/layout.tsx
```typescript
import { ClerkProvider } from '@clerk/nextjs'
import { Inter } from 'next/font/google'
import { ThemeProvider } from '@/components/theme-provider'
import { QueryProvider } from '@/lib/react-query'
import { Toaster } from '@/components/ui/sonner'
import './globals.css'

const inter = Inter({ subsets: ['latin'] })

export const metadata = {
  title: 'Production App',
  description: 'Production-ready Next.js application'
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <ClerkProvider>
      <html lang="en" suppressHydrationWarning>
        <body className={inter.className}>
          <ThemeProvider
            attribute="class"
            defaultTheme="system"
            enableSystem
            disableTransitionOnChange
          >
            <QueryProvider>
              {children}
              <Toaster />
            </QueryProvider>
          </ThemeProvider>
        </body>
      </html>
    </ClerkProvider>
  )
}
```

#### components/auth/protected-route.tsx
```typescript
'use client'

import { useAuth } from '@clerk/nextjs'
import { useRouter } from 'next/navigation'
import { useEffect } from 'react'
import { LoadingSpinner } from '@/components/ui/loading-spinner'

interface ProtectedRouteProps {
  children: React.ReactNode
  requiredPermissions?: string[]
  requiredRole?: string
  fallback?: React.ReactNode
}

export function ProtectedRoute({ 
  children, 
  requiredPermissions = [],
  requiredRole,
  fallback 
}: ProtectedRouteProps) {
  const { isLoaded, userId, has } = useAuth()
  const router = useRouter()

  useEffect(() => {
    if (isLoaded && !userId) {
      router.push('/sign-in')
    }
  }, [isLoaded, userId, router])

  if (!isLoaded) {
    return <LoadingSpinner />
  }

  if (!userId) {
    return null // Will redirect in useEffect
  }

  // Check permissions
  const hasPermissions = requiredPermissions.length === 0 || 
    requiredPermissions.every(permission => has({ permission }))

  const hasRole = !requiredRole || has({ role: requiredRole })

  if (!hasPermissions || !hasRole) {
    return fallback || (
      <div className="flex items-center justify-center min-h-screen">
        <div className="text-center">
          <h2 className="text-2xl font-bold text-gray-900 dark:text-gray-100">
            Access Denied
          </h2>
          <p className="mt-2 text-gray-600 dark:text-gray-400">
            You don't have permission to access this page.
          </p>
        </div>
      </div>
    )
  }

  return <>{children}</>
}
```

## 🎨 Component Templates

### 1. Advanced Form Template

#### components/forms/project-form.tsx
```typescript
'use client'

import { useState } from 'react'
import { useForm, useFieldArray } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Textarea } from '@/components/ui/textarea'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Switch } from '@/components/ui/switch'
import { Label } from '@/components/ui/label'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { X, Plus } from 'lucide-react'
import {
  Form,
  FormControl,
  FormDescription,
  FormField,
  FormItem,
  FormLabel,
  FormMessage,
} from '@/components/ui/form'

const projectSchema = z.object({
  name: z.string().min(1, 'Project name is required').max(100, 'Name too long'),
  description: z.string().max(500, 'Description too long').optional(),
  category: z.enum(['web', 'mobile', 'desktop', 'api']),
  priority: z.enum(['low', 'medium', 'high']),
  isPublic: z.boolean().default(false),
  tags: z.array(z.string()).min(1, 'At least one tag is required'),
  collaborators: z.array(z.object({
    email: z.string().email('Invalid email'),
    role: z.enum(['viewer', 'editor', 'admin'])
  })),
  settings: z.object({
    notifications: z.boolean().default(true),
    allowComments: z.boolean().default(true),
    autoSave: z.boolean().default(true)
  })
})

type ProjectFormData = z.infer<typeof projectSchema>

interface ProjectFormProps {
  defaultValues?: Partial<ProjectFormData>
  onSubmit: (data: ProjectFormData) => Promise<void>
  isLoading?: boolean
}

export function ProjectForm({ defaultValues, onSubmit, isLoading }: ProjectFormProps) {
  const [tagInput, setTagInput] = useState('')

  const form = useForm<ProjectFormData>({
    resolver: zodResolver(projectSchema),
    defaultValues: {
      name: '',
      description: '',
      category: 'web',
      priority: 'medium',
      isPublic: false,
      tags: [],
      collaborators: [],
      settings: {
        notifications: true,
        allowComments: true,
        autoSave: true
      },
      ...defaultValues
    }
  })

  const { fields: collaboratorFields, append: addCollaborator, remove: removeCollaborator } = useFieldArray({
    control: form.control,
    name: 'collaborators'
  })

  const handleSubmit = async (data: ProjectFormData) => {
    try {
      await onSubmit(data)
      form.reset()
    } catch (error) {
      form.setError('root', { 
        message: error instanceof Error ? error.message : 'Failed to save project' 
      })
    }
  }

  const addTag = () => {
    if (tagInput.trim()) {
      const currentTags = form.getValues('tags')
      if (!currentTags.includes(tagInput.trim())) {
        form.setValue('tags', [...currentTags, tagInput.trim()])
      }
      setTagInput('')
    }
  }

  const removeTag = (tagToRemove: string) => {
    const currentTags = form.getValues('tags')
    form.setValue('tags', currentTags.filter(tag => tag !== tagToRemove))
  }

  return (
    <Form {...form}>
      <form onSubmit={form.handleSubmit(handleSubmit)} className="space-y-8">
        {/* Basic Information */}
        <Card>
          <CardHeader>
            <CardTitle>Basic Information</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <FormField
              control={form.control}
              name="name"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Project Name</FormLabel>
                  <FormControl>
                    <Input placeholder="Enter project name" {...field} />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />

            <FormField
              control={form.control}
              name="description"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Description</FormLabel>
                  <FormControl>
                    <Textarea 
                      placeholder="Describe your project"
                      className="min-h-[100px]"
                      {...field}
                    />
                  </FormControl>
                  <FormDescription>
                    Optional description of your project (max 500 characters)
                  </FormDescription>
                  <FormMessage />
                </FormItem>
              )}
            />

            <div className="grid grid-cols-2 gap-4">
              <FormField
                control={form.control}
                name="category"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Category</FormLabel>
                    <Select onValueChange={field.onChange} defaultValue={field.value}>
                      <FormControl>
                        <SelectTrigger>
                          <SelectValue placeholder="Select category" />
                        </SelectTrigger>
                      </FormControl>
                      <SelectContent>
                        <SelectItem value="web">Web Application</SelectItem>
                        <SelectItem value="mobile">Mobile App</SelectItem>
                        <SelectItem value="desktop">Desktop App</SelectItem>
                        <SelectItem value="api">API Service</SelectItem>
                      </SelectContent>
                    </Select>
                    <FormMessage />
                  </FormItem>
                )}
              />

              <FormField
                control={form.control}
                name="priority"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Priority</FormLabel>
                    <Select onValueChange={field.onChange} defaultValue={field.value}>
                      <FormControl>
                        <SelectTrigger>
                          <SelectValue placeholder="Select priority" />
                        </SelectTrigger>
                      </FormControl>
                      <SelectContent>
                        <SelectItem value="low">Low</SelectItem>
                        <SelectItem value="medium">Medium</SelectItem>
                        <SelectItem value="high">High</SelectItem>
                      </SelectContent>
                    </Select>
                    <FormMessage />
                  </FormItem>
                )}
              />
            </div>

            <FormField
              control={form.control}
              name="isPublic"
              render={({ field }) => (
                <FormItem className="flex flex-row items-center justify-between rounded-lg border p-4">
                  <div className="space-y-0.5">
                    <FormLabel className="text-base">Public Project</FormLabel>
                    <FormDescription>
                      Make this project visible to everyone
                    </FormDescription>
                  </div>
                  <FormControl>
                    <Switch 
                      checked={field.value}
                      onCheckedChange={field.onChange}
                    />
                  </FormControl>
                </FormItem>
              )}
            />
          </CardContent>
        </Card>

        {/* Tags */}
        <Card>
          <CardHeader>
            <CardTitle>Tags</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="flex space-x-2">
              <Input
                placeholder="Add a tag"
                value={tagInput}
                onChange={(e) => setTagInput(e.target.value)}
                onKeyDown={(e) => {
                  if (e.key === 'Enter') {
                    e.preventDefault()
                    addTag()
                  }
                }}
              />
              <Button type="button" onClick={addTag} variant="outline">
                <Plus className="h-4 w-4" />
              </Button>
            </div>
            
            <div className="flex flex-wrap gap-2">
              {form.watch('tags').map((tag) => (
                <Badge key={tag} variant="secondary" className="text-sm">
                  {tag}
                  <Button
                    type="button"
                    variant="ghost"
                    size="sm"
                    className="ml-2 h-auto p-0 text-muted-foreground hover:text-foreground"
                    onClick={() => removeTag(tag)}
                  >
                    <X className="h-3 w-3" />
                  </Button>
                </Badge>
              ))}
            </div>
            <FormMessage>{form.formState.errors.tags?.message}</FormMessage>
          </CardContent>
        </Card>

        {/* Collaborators */}
        <Card>
          <CardHeader>
            <CardTitle>Collaborators</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            {collaboratorFields.map((field, index) => (
              <div key={field.id} className="flex items-end space-x-2">
                <FormField
                  control={form.control}
                  name={`collaborators.${index}.email`}
                  render={({ field }) => (
                    <FormItem className="flex-1">
                      <FormControl>
                        <Input placeholder="Email address" {...field} />
                      </FormControl>
                      <FormMessage />
                    </FormItem>
                  )}
                />
                
                <FormField
                  control={form.control}
                  name={`collaborators.${index}.role`}
                  render={({ field }) => (
                    <FormItem className="w-32">
                      <Select onValueChange={field.onChange} defaultValue={field.value}>
                        <FormControl>
                          <SelectTrigger>
                            <SelectValue placeholder="Role" />
                          </SelectTrigger>
                        </FormControl>
                        <SelectContent>
                          <SelectItem value="viewer">Viewer</SelectItem>
                          <SelectItem value="editor">Editor</SelectItem>
                          <SelectItem value="admin">Admin</SelectItem>
                        </SelectContent>
                      </Select>
                      <FormMessage />
                    </FormItem>
                  )}
                />
                
                <Button 
                  type="button" 
                  variant="outline" 
                  size="icon"
                  onClick={() => removeCollaborator(index)}
                >
                  <X className="h-4 w-4" />
                </Button>
              </div>
            ))}
            
            <Button
              type="button"
              variant="outline"
              onClick={() => addCollaborator({ email: '', role: 'viewer' })}
            >
              <Plus className="mr-2 h-4 w-4" />
              Add Collaborator
            </Button>
          </CardContent>
        </Card>

        {/* Settings */}
        <Card>
          <CardHeader>
            <CardTitle>Project Settings</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <FormField
              control={form.control}
              name="settings.notifications"
              render={({ field }) => (
                <FormItem className="flex flex-row items-center justify-between rounded-lg border p-4">
                  <div className="space-y-0.5">
                    <FormLabel className="text-base">Email Notifications</FormLabel>
                    <FormDescription>
                      Receive email updates about this project
                    </FormDescription>
                  </div>
                  <FormControl>
                    <Switch 
                      checked={field.value}
                      onCheckedChange={field.onChange}
                    />
                  </FormControl>
                </FormItem>
              )}
            />

            <FormField
              control={form.control}
              name="settings.allowComments"
              render={({ field }) => (
                <FormItem className="flex flex-row items-center justify-between rounded-lg border p-4">
                  <div className="space-y-0.5">
                    <FormLabel className="text-base">Allow Comments</FormLabel>
                    <FormDescription>
                      Let collaborators comment on this project
                    </FormDescription>
                  </div>
                  <FormControl>
                    <Switch 
                      checked={field.value}
                      onCheckedChange={field.onChange}
                    />
                  </FormControl>
                </FormItem>
              )}
            />

            <FormField
              control={form.control}
              name="settings.autoSave"
              render={({ field }) => (
                <FormItem className="flex flex-row items-center justify-between rounded-lg border p-4">
                  <div className="space-y-0.5">
                    <FormLabel className="text-base">Auto Save</FormLabel>
                    <FormDescription>
                      Automatically save changes as you work
                    </FormDescription>
                  </div>
                  <FormControl>
                    <Switch 
                      checked={field.value}
                      onCheckedChange={field.onChange}
                    />
                  </FormControl>
                </FormItem>
              )}
            />
          </CardContent>
        </Card>

        {/* Error Display */}
        {form.formState.errors.root && (
          <div className="rounded-md bg-red-50 border border-red-200 p-4">
            <p className="text-sm text-red-800">
              {form.formState.errors.root.message}
            </p>
          </div>
        )}

        {/* Submit Button */}
        <div className="flex justify-end space-x-4">
          <Button type="button" variant="outline" onClick={() => form.reset()}>
            Reset
          </Button>
          <Button type="submit" disabled={isLoading || form.formState.isSubmitting}>
            {isLoading || form.formState.isSubmitting ? 'Saving...' : 'Save Project'}
          </Button>
        </div>
      </form>
    </Form>
  )
}
```

## 🔗 Navigation

**← Previous**: [Comparison Analysis](./comparison-analysis.md)  
**→ Next**: [State Management Patterns](./state-management-patterns.md)

---

**Related Templates:**
- [Express.js Template Examples](../../backend/express-testing-frameworks-comparison/template-examples.md)
- [Nx Template Examples](../../devops/nx-setup-guide/template-examples.md)