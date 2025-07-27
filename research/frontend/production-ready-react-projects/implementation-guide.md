# Implementation Guide - Production-Ready React/Next.js Patterns

## 🚀 Getting Started with Production Patterns

This guide provides step-by-step implementation of patterns identified from analyzing 25+ production React/Next.js applications. Each pattern includes real-world examples from the analyzed projects.

## 🛠️ Core Technology Stack Setup

### 1. Project Initialization (Modern Stack)

#### Next.js 14+ with TypeScript
```bash
# Create Next.js project with TypeScript
npx create-next-app@latest my-app --typescript --tailwind --app --use-npm

# Essential dependencies from analyzed projects
npm install @tanstack/react-query zustand
npm install @clerk/nextjs  # or next-auth for custom auth
npm install @radix-ui/react-dialog @radix-ui/react-dropdown-menu
npm install class-variance-authority clsx tailwind-merge
npm install lucide-react @heroicons/react

# Development dependencies
npm install -D @types/node @next/bundle-analyzer
npm install -D jest @testing-library/react @testing-library/jest-dom
```

#### Project Structure (Based on Formbricks & SigNoz)
```
src/
├── app/                    # Next.js 14 App Router
│   ├── (auth)/            # Route groups
│   ├── dashboard/         # Main application
│   ├── api/              # API routes
│   └── globals.css       # Global styles
├── components/           # Reusable components
│   ├── ui/              # shadcn/ui components
│   ├── forms/           # Form components
│   └── layout/          # Layout components
├── lib/                 # Utility functions
│   ├── utils.ts         # General utilities
│   ├── auth.ts          # Auth configuration
│   └── db.ts           # Database configuration
├── stores/              # State management
├── types/               # TypeScript definitions
└── hooks/               # Custom React hooks
```

## 📊 State Management Implementation

### 1. Zustand Store Pattern (Formbricks, Open Resume)

#### Basic Store Setup
```typescript
// stores/auth-store.ts
import { create } from 'zustand'
import { persist } from 'zustand/middleware'

interface User {
  id: string
  email: string
  name: string
  avatar?: string
}

interface AuthStore {
  user: User | null
  isLoading: boolean
  isAuthenticated: boolean
  
  // Actions
  setUser: (user: User) => void
  logout: () => void
  setLoading: (loading: boolean) => void
}

export const useAuthStore = create<AuthStore>()(
  persist(
    (set, get) => ({
      user: null,
      isLoading: false,
      isAuthenticated: false,

      setUser: (user) => set({ 
        user, 
        isAuthenticated: true,
        isLoading: false 
      }),
      
      logout: () => set({ 
        user: null, 
        isAuthenticated: false,
        isLoading: false 
      }),
      
      setLoading: (isLoading) => set({ isLoading })
    }),
    {
      name: 'auth-storage',
      partialize: (state) => ({ 
        user: state.user,
        isAuthenticated: state.isAuthenticated 
      })
    }
  )
)
```

#### Advanced Zustand Pattern (Multi-Store)
```typescript
// stores/app-store.ts - Global application state
interface AppStore {
  theme: 'light' | 'dark'
  sidebar: { isOpen: boolean }
  notifications: Notification[]
  
  toggleTheme: () => void
  toggleSidebar: () => void
  addNotification: (notification: Notification) => void
  removeNotification: (id: string) => void
}

export const useAppStore = create<AppStore>()((set) => ({
  theme: 'light',
  sidebar: { isOpen: true },
  notifications: [],

  toggleTheme: () => set((state) => ({ 
    theme: state.theme === 'light' ? 'dark' : 'light' 
  })),
  
  toggleSidebar: () => set((state) => ({
    sidebar: { isOpen: !state.sidebar.isOpen }
  })),
  
  addNotification: (notification) => set((state) => ({
    notifications: [...state.notifications, notification]
  })),
  
  removeNotification: (id) => set((state) => ({
    notifications: state.notifications.filter(n => n.id !== id)
  }))
}))
```

### 2. Redux Toolkit Pattern (SigNoz, Reactive Resume)

#### Store Configuration
```typescript
// stores/store.ts
import { configureStore } from '@reduxjs/toolkit'
import { authSlice } from './slices/auth-slice'
import { projectsSlice } from './slices/projects-slice'

export const store = configureStore({
  reducer: {
    auth: authSlice.reducer,
    projects: projectsSlice.reducer
  },
  middleware: (getDefaultMiddleware) =>
    getDefaultMiddleware({
      serializableCheck: {
        ignoredActions: ['persist/PERSIST']
      }
    })
})

export type RootState = ReturnType<typeof store.getState>
export type AppDispatch = typeof store.dispatch
```

#### Feature Slice Pattern
```typescript
// stores/slices/projects-slice.ts
import { createSlice, createAsyncThunk } from '@reduxjs/toolkit'

interface Project {
  id: string
  name: string
  description: string
  createdAt: string
}

interface ProjectsState {
  projects: Project[]
  currentProject: Project | null
  isLoading: boolean
  error: string | null
}

// Async thunk for API calls
export const fetchProjects = createAsyncThunk(
  'projects/fetchProjects',
  async (userId: string) => {
    const response = await fetch(`/api/projects?userId=${userId}`)
    return response.json()
  }
)

const initialState: ProjectsState = {
  projects: [],
  currentProject: null,
  isLoading: false,
  error: null
}

export const projectsSlice = createSlice({
  name: 'projects',
  initialState,
  reducers: {
    setCurrentProject: (state, action) => {
      state.currentProject = action.payload
    },
    clearError: (state) => {
      state.error = null
    }
  },
  extraReducers: (builder) => {
    builder
      .addCase(fetchProjects.pending, (state) => {
        state.isLoading = true
        state.error = null
      })
      .addCase(fetchProjects.fulfilled, (state, action) => {
        state.isLoading = false
        state.projects = action.payload
      })
      .addCase(fetchProjects.rejected, (state, action) => {
        state.isLoading = false
        state.error = action.error.message || 'Failed to fetch projects'
      })
  }
})
```

## 🔐 Authentication Implementation

### 1. Clerk Integration (Recommended for New Projects)

#### Setup and Configuration
```typescript
// app/layout.tsx
import { ClerkProvider } from '@clerk/nextjs'

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <ClerkProvider>
      <html lang="en">
        <body>{children}</body>
      </html>
    </ClerkProvider>
  )
}
```

#### Protected Routes with Middleware
```typescript
// middleware.ts
import { authMiddleware } from '@clerk/nextjs'

export default authMiddleware({
  publicRoutes: ['/', '/about', '/pricing'],
  ignoredRoutes: ['/api/webhook']
})

export const config = {
  matcher: ['/((?!.+\\.[\\w]+$|_next).*)', '/', '/(api|trpc)(.*)']
}
```

#### Server Component Authentication
```typescript
// app/dashboard/page.tsx
import { auth } from '@clerk/nextjs'
import { redirect } from 'next/navigation'

export default async function DashboardPage() {
  const { userId } = auth()
  
  if (!userId) {
    redirect('/sign-in')
  }

  // Fetch user-specific data
  const projects = await getProjectsForUser(userId)

  return (
    <div>
      <h1>Dashboard</h1>
      <ProjectsList projects={projects} />
    </div>
  )
}
```

#### Client Component Authentication
```typescript
// components/user-profile.tsx
'use client'

import { useUser } from '@clerk/nextjs'

export function UserProfile() {
  const { user, isLoaded } = useUser()

  if (!isLoaded) return <div>Loading...</div>
  if (!user) return <div>Not signed in</div>

  return (
    <div className="flex items-center space-x-2">
      <img 
        src={user.imageUrl} 
        alt={user.fullName || 'User'} 
        className="w-8 h-8 rounded-full"
      />
      <span>{user.fullName}</span>
    </div>
  )
}
```

### 2. NextAuth.js Implementation (Self-hosted)

#### Configuration
```typescript
// lib/auth.ts
import NextAuth from 'next-auth'
import GoogleProvider from 'next-auth/providers/google'
import { PrismaAdapter } from '@auth/prisma-adapter'
import { prisma } from './db'

export const authOptions = {
  adapter: PrismaAdapter(prisma),
  providers: [
    GoogleProvider({
      clientId: process.env.GOOGLE_CLIENT_ID!,
      clientSecret: process.env.GOOGLE_CLIENT_SECRET!
    })
  ],
  callbacks: {
    session: ({ session, token }) => ({
      ...session,
      user: {
        ...session.user,
        id: token.sub
      }
    })
  },
  pages: {
    signIn: '/auth/signin',
    error: '/auth/error'
  }
}

export default NextAuth(authOptions)
```

## 🎨 Component Library Implementation

### 1. shadcn/ui Setup (Most Popular Choice)

#### Installation and Configuration
```bash
# Initialize shadcn/ui
npx shadcn-ui@latest init

# Add commonly used components
npx shadcn-ui@latest add button
npx shadcn-ui@latest add input
npx shadcn-ui@latest add dialog
npx shadcn-ui@latest add dropdown-menu
npx shadcn-ui@latest add form
npx shadcn-ui@latest add table
```

#### Custom Component Pattern
```typescript
// components/ui/custom-button.tsx
import * as React from 'react'
import { Slot } from '@radix-ui/react-slot'
import { cva, type VariantProps } from 'class-variance-authority'
import { cn } from '@/lib/utils'

const buttonVariants = cva(
  'inline-flex items-center justify-center rounded-md text-sm font-medium transition-colors focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring disabled:pointer-events-none disabled:opacity-50',
  {
    variants: {
      variant: {
        default: 'bg-primary text-primary-foreground shadow hover:bg-primary/90',
        destructive: 'bg-destructive text-destructive-foreground shadow-sm hover:bg-destructive/90',
        outline: 'border border-input bg-background shadow-sm hover:bg-accent hover:text-accent-foreground',
        secondary: 'bg-secondary text-secondary-foreground shadow-sm hover:bg-secondary/80',
        ghost: 'hover:bg-accent hover:text-accent-foreground',
        link: 'text-primary underline-offset-4 hover:underline'
      },
      size: {
        default: 'h-9 px-4 py-2',
        sm: 'h-8 rounded-md px-3 text-xs',
        lg: 'h-10 rounded-md px-8',
        icon: 'h-9 w-9'
      }
    },
    defaultVariants: {
      variant: 'default',
      size: 'default'
    }
  }
)

export interface ButtonProps
  extends React.ButtonHTMLAttributes<HTMLButtonElement>,
    VariantProps<typeof buttonVariants> {
  asChild?: boolean
}

const Button = React.forwardRef<HTMLButtonElement, ButtonProps>(
  ({ className, variant, size, asChild = false, ...props }, ref) => {
    const Comp = asChild ? Slot : 'button'
    return (
      <Comp
        className={cn(buttonVariants({ variant, size, className }))}
        ref={ref}
        {...props}
      />
    )
  }
)
Button.displayName = 'Button'

export { Button, buttonVariants }
```

### 2. Form Handling with React Hook Form

#### Advanced Form Pattern (Used in Formbricks, Open SaaS)
```typescript
// components/forms/project-form.tsx
'use client'

import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import {
  Form,
  FormControl,
  FormField,
  FormItem,
  FormLabel,
  FormMessage
} from '@/components/ui/form'

const projectSchema = z.object({
  name: z.string().min(1, 'Project name is required'),
  description: z.string().optional(),
  isPublic: z.boolean().default(false)
})

type ProjectFormData = z.infer<typeof projectSchema>

interface ProjectFormProps {
  onSubmit: (data: ProjectFormData) => Promise<void>
  defaultValues?: Partial<ProjectFormData>
  isLoading?: boolean
}

export function ProjectForm({ onSubmit, defaultValues, isLoading }: ProjectFormProps) {
  const form = useForm<ProjectFormData>({
    resolver: zodResolver(projectSchema),
    defaultValues: {
      name: '',
      description: '',
      isPublic: false,
      ...defaultValues
    }
  })

  return (
    <Form {...form}>
      <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-4">
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
                <Input placeholder="Project description" {...field} />
              </FormControl>
              <FormMessage />
            </FormItem>
          )}
        />

        <Button type="submit" disabled={isLoading}>
          {isLoading ? 'Creating...' : 'Create Project'}
        </Button>
      </form>
    </Form>
  )
}
```

## 🌐 API Integration Patterns

### 1. React Query Setup (Most Common Pattern)

#### Query Client Configuration
```typescript
// lib/react-query.tsx
'use client'

import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { ReactQueryDevtools } from '@tanstack/react-query-devtools'
import { useState } from 'react'

export function QueryProvider({ children }: { children: React.ReactNode }) {
  const [queryClient] = useState(
    () => new QueryClient({
      defaultOptions: {
        queries: {
          staleTime: 60 * 1000, // 1 minute
          retry: (failureCount, error) => {
            // Don't retry on 4xx errors
            if (error instanceof Error && error.message.includes('4')) {
              return false
            }
            return failureCount < 3
          }
        }
      }
    })
  )

  return (
    <QueryClientProvider client={queryClient}>
      {children}
      <ReactQueryDevtools initialIsOpen={false} />
    </QueryClientProvider>
  )
}
```

#### Custom Hooks Pattern
```typescript
// hooks/use-projects.ts
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { api } from '@/lib/api'

export interface Project {
  id: string
  name: string
  description: string
  createdAt: string
  updatedAt: string
}

// Fetch projects
export function useProjects() {
  return useQuery({
    queryKey: ['projects'],
    queryFn: async () => {
      const response = await api.get('/projects')
      return response.data as Project[]
    }
  })
}

// Create project mutation
export function useCreateProject() {
  const queryClient = useQueryClient()
  
  return useMutation({
    mutationFn: async (project: Omit<Project, 'id' | 'createdAt' | 'updatedAt'>) => {
      const response = await api.post('/projects', project)
      return response.data
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['projects'] })
    }
  })
}

// Update project mutation
export function useUpdateProject() {
  const queryClient = useQueryClient()
  
  return useMutation({
    mutationFn: async ({ id, ...updates }: Partial<Project> & { id: string }) => {
      const response = await api.patch(`/projects/${id}`, updates)
      return response.data
    },
    onSuccess: (data) => {
      queryClient.setQueryData(['projects'], (old: Project[] | undefined) => 
        old?.map(project => project.id === data.id ? data : project)
      )
    }
  })
}
```

### 2. Server Actions (Next.js 14+)

#### Server Action Implementation
```typescript
// lib/actions/project-actions.ts
'use server'

import { auth } from '@clerk/nextjs'
import { prisma } from '@/lib/db'
import { revalidatePath } from 'next/cache'
import { z } from 'zod'

const createProjectSchema = z.object({
  name: z.string().min(1),
  description: z.string().optional()
})

export async function createProject(formData: FormData) {
  const { userId } = auth()
  
  if (!userId) {
    throw new Error('Unauthorized')
  }

  const validatedFields = createProjectSchema.safeParse({
    name: formData.get('name'),
    description: formData.get('description')
  })

  if (!validatedFields.success) {
    return {
      errors: validatedFields.error.flatten().fieldErrors
    }
  }

  const { name, description } = validatedFields.data

  try {
    const project = await prisma.project.create({
      data: {
        name,
        description,
        userId
      }
    })

    revalidatePath('/dashboard/projects')
    
    return { 
      success: true, 
      project 
    }
  } catch (error) {
    return {
      errors: { _form: ['Failed to create project'] }
    }
  }
}
```

## 🔗 Navigation

**← Previous**: [Executive Summary](./executive-summary.md)  
**→ Next**: [Best Practices](./best-practices.md)

---

**Related Implementation Guides:**
- [Express.js Implementation Guide](../../backend/express-testing-frameworks-comparison/implementation-guide.md)
- [Nx Setup Guide](../../devops/nx-setup-guide/implementation-guide.md)