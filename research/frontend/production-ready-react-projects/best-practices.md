# Best Practices - Production-Ready React/Next.js Development

## 🎯 Overview

This document consolidates best practices extracted from analyzing 25+ production React/Next.js applications. These patterns represent battle-tested approaches used by successful open source projects with thousands of stars and active production usage.

## 🏗️ Architecture & Project Structure

### 1. Folder Organization (Based on SigNoz, Formbricks)

#### Recommended Structure
```
src/
├── app/                    # Next.js App Router (recommended)
│   ├── (auth)/            # Route groups for organization
│   │   ├── sign-in/       # Authentication pages
│   │   └── sign-up/
│   ├── (dashboard)/       # Protected application routes
│   │   ├── projects/
│   │   ├── settings/
│   │   └── analytics/
│   ├── api/               # API routes
│   │   ├── auth/
│   │   ├── projects/
│   │   └── webhooks/
│   ├── globals.css        # Global styles
│   ├── layout.tsx         # Root layout
│   └── page.tsx          # Homepage
├── components/            # Reusable UI components
│   ├── ui/               # Base UI components (shadcn/ui)
│   ├── forms/            # Form-specific components
│   ├── layout/           # Layout components
│   └── feature/          # Feature-specific components
├── lib/                  # Utility functions and configurations
│   ├── utils.ts          # General utilities
│   ├── auth.ts           # Authentication setup
│   ├── db.ts            # Database configuration
│   ├── validations.ts    # Zod schemas
│   └── constants.ts      # Application constants
├── stores/               # State management
├── hooks/                # Custom React hooks
├── types/                # TypeScript type definitions
└── styles/               # Additional stylesheets
```

### 2. Component Organization Patterns

#### Feature-Based Components (Preferred by Enterprise Apps)
```typescript
// components/projects/
├── project-card.tsx           # Individual project display
├── project-list.tsx           # Project listing
├── project-form.tsx           # Create/edit forms
├── project-settings.tsx       # Project-specific settings
├── project-analytics.tsx      # Analytics display
└── index.ts                   # Barrel exports

// Barrel export pattern
export { ProjectCard } from './project-card'
export { ProjectList } from './project-list'
export { ProjectForm } from './project-form'
// ... other exports
```

#### UI Component Standards (shadcn/ui Pattern)
```typescript
// components/ui/button.tsx
import * as React from 'react'
import { cn } from '@/lib/utils'

interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'default' | 'destructive' | 'outline' | 'secondary' | 'ghost' | 'link'
  size?: 'default' | 'sm' | 'lg' | 'icon'
}

const Button = React.forwardRef<HTMLButtonElement, ButtonProps>(
  ({ className, variant = 'default', size = 'default', ...props }, ref) => {
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

export { Button }
```

## 🧠 State Management Best Practices

### 1. Zustand Implementation (Recommended for Most Projects)

#### Store Organization by Feature
```typescript
// stores/auth-store.ts - Authentication state
interface AuthStore {
  user: User | null
  isLoading: boolean
  isAuthenticated: boolean
  permissions: string[]
  
  // Actions grouped by functionality
  setUser: (user: User) => void
  logout: () => void
  updatePermissions: (permissions: string[]) => void
  
  // Computed values
  hasPermission: (permission: string) => boolean
}

export const useAuthStore = create<AuthStore>()((set, get) => ({
  user: null,
  isLoading: false,
  isAuthenticated: false,
  permissions: [],

  setUser: (user) => set({ 
    user, 
    isAuthenticated: true,
    permissions: user.permissions || []
  }),
  
  logout: () => set({ 
    user: null, 
    isAuthenticated: false,
    permissions: []
  }),
  
  updatePermissions: (permissions) => set({ permissions }),
  
  // Computed getter
  hasPermission: (permission) => {
    const { permissions } = get()
    return permissions.includes(permission)
  }
}))
```

#### Store Composition Pattern
```typescript
// stores/app-store.ts - Combining multiple stores
import { create } from 'zustand'
import { subscribeWithSelector } from 'zustand/middleware'

interface AppStore {
  // UI State
  theme: 'light' | 'dark'
  sidebar: { isOpen: boolean; width: number }
  modals: { [key: string]: boolean }
  
  // App State
  currentPage: string
  breadcrumbs: BreadcrumbItem[]
  
  // Actions
  setTheme: (theme: 'light' | 'dark') => void
  toggleSidebar: () => void
  openModal: (modalId: string) => void
  closeModal: (modalId: string) => void
  updateBreadcrumbs: (breadcrumbs: BreadcrumbItem[]) => void
}

export const useAppStore = create<AppStore>()(
  subscribeWithSelector((set) => ({
    theme: 'light',
    sidebar: { isOpen: true, width: 240 },
    modals: {},
    currentPage: '',
    breadcrumbs: [],

    setTheme: (theme) => set({ theme }),
    toggleSidebar: () => set((state) => ({
      sidebar: { ...state.sidebar, isOpen: !state.sidebar.isOpen }
    })),
    openModal: (modalId) => set((state) => ({
      modals: { ...state.modals, [modalId]: true }
    })),
    closeModal: (modalId) => set((state) => ({
      modals: { ...state.modals, [modalId]: false }
    })),
    updateBreadcrumbs: (breadcrumbs) => set({ breadcrumbs })
  }))
)
```

### 2. Redux Toolkit Best Practices (For Complex State)

#### Feature Slice Pattern
```typescript
// stores/slices/projects-slice.ts
import { createSlice, createAsyncThunk, createSelector } from '@reduxjs/toolkit'

// Async thunks with proper error handling
export const fetchProjects = createAsyncThunk(
  'projects/fetchProjects',
  async (params: { userId: string; page?: number }, { rejectWithValue }) => {
    try {
      const response = await projectsApi.getProjects(params)
      return response.data
    } catch (error) {
      return rejectWithValue(error.response?.data || 'Failed to fetch projects')
    }
  }
)

interface ProjectsState {
  projects: Project[]
  currentProject: Project | null
  filters: ProjectFilters
  pagination: {
    page: number
    limit: number
    total: number
  }
  loading: {
    fetch: boolean
    create: boolean
    update: boolean
    delete: boolean
  }
  error: string | null
}

const projectsSlice = createSlice({
  name: 'projects',
  initialState,
  reducers: {
    // Synchronous reducers
    setCurrentProject: (state, action) => {
      state.currentProject = action.payload
    },
    updateFilters: (state, action) => {
      state.filters = { ...state.filters, ...action.payload }
    },
    clearError: (state) => {
      state.error = null
    }
  },
  extraReducers: (builder) => {
    builder
      .addCase(fetchProjects.pending, (state) => {
        state.loading.fetch = true
        state.error = null
      })
      .addCase(fetchProjects.fulfilled, (state, action) => {
        state.loading.fetch = false
        state.projects = action.payload.projects
        state.pagination = action.payload.pagination
      })
      .addCase(fetchProjects.rejected, (state, action) => {
        state.loading.fetch = false
        state.error = action.payload as string
      })
  }
})

// Selectors with memoization
export const selectProjects = (state: RootState) => state.projects.projects
export const selectCurrentProject = (state: RootState) => state.projects.currentProject
export const selectProjectsLoading = (state: RootState) => state.projects.loading.fetch

// Complex selectors
export const selectFilteredProjects = createSelector(
  [selectProjects, (state: RootState) => state.projects.filters],
  (projects, filters) => {
    return projects.filter(project => {
      if (filters.status && project.status !== filters.status) return false
      if (filters.search && !project.name.toLowerCase().includes(filters.search.toLowerCase())) return false
      return true
    })
  }
)
```

## 🔐 Authentication & Security Best Practices

### 1. Clerk Integration Best Practices

#### Middleware Configuration
```typescript
// middleware.ts
import { authMiddleware } from '@clerk/nextjs'

export default authMiddleware({
  // Public routes that don't require authentication
  publicRoutes: [
    '/',
    '/about',
    '/pricing',
    '/blog',
    '/blog/(.*)',
    '/api/webhooks/(.*)'
  ],
  
  // Routes to ignore completely
  ignoredRoutes: [
    '/api/health',
    '/api/metrics',
    '/_next/(.*)',
    '/favicon.ico'
  ],
  
  // Redirect after sign in
  afterAuth(auth, req) {
    // Handle users who aren't authenticated
    if (!auth.userId && !auth.isPublicRoute) {
      const signInUrl = new URL('/sign-in', req.url)
      signInUrl.searchParams.set('redirect_url', req.url)
      return Response.redirect(signInUrl)
    }

    // Redirect authenticated users away from auth pages
    if (auth.userId && ['/sign-in', '/sign-up'].includes(req.nextUrl.pathname)) {
      return Response.redirect(new URL('/dashboard', req.url))
    }
  }
})

export const config = {
  matcher: ['/((?!.+\\.[\\w]+$|_next).*)', '/', '/(api|trpc)(.*)']
}
```

#### Protected Route Pattern
```typescript
// app/dashboard/layout.tsx
import { auth } from '@clerk/nextjs'
import { redirect } from 'next/navigation'

export default async function DashboardLayout({
  children
}: {
  children: React.ReactNode
}) {
  const { userId } = auth()
  
  if (!userId) {
    redirect('/sign-in')
  }

  return (
    <div className="min-h-screen bg-background">
      <DashboardHeader />
      <div className="flex">
        <DashboardSidebar />
        <main className="flex-1 p-6">
          {children}
        </main>
      </div>
    </div>
  )
}
```

### 2. Permission-Based Access Control

#### Role-Based Component Protection
```typescript
// components/auth/protected-component.tsx
import { useAuth } from '@clerk/nextjs'

interface ProtectedComponentProps {
  children: React.ReactNode
  permissions?: string[]
  roles?: string[]
  fallback?: React.ReactNode
}

export function ProtectedComponent({ 
  children, 
  permissions = [], 
  roles = [], 
  fallback = null 
}: ProtectedComponentProps) {
  const { has } = useAuth()
  
  const hasPermission = permissions.length === 0 || 
    permissions.some(permission => has({ permission }))
  
  const hasRole = roles.length === 0 || 
    roles.some(role => has({ role }))

  if (!hasPermission || !hasRole) {
    return <>{fallback}</>
  }

  return <>{children}</>
}

// Usage
<ProtectedComponent 
  permissions={['projects:write']} 
  fallback={<div>You don't have permission to create projects</div>}
>
  <CreateProjectButton />
</ProtectedComponent>
```

## 🎨 Component & UI Best Practices

### 1. Component Composition Patterns

#### Compound Components (Advanced Pattern)
```typescript
// components/ui/card.tsx
interface CardContextType {
  size: 'sm' | 'md' | 'lg'
  variant: 'default' | 'outlined' | 'elevated'
}

const CardContext = createContext<CardContextType | undefined>(undefined)

const Card = ({ 
  children, 
  size = 'md', 
  variant = 'default',
  className,
  ...props 
}: CardProps) => {
  return (
    <CardContext.Provider value={{ size, variant }}>
      <div className={cn(cardVariants({ size, variant }), className)} {...props}>
        {children}
      </div>
    </CardContext.Provider>
  )
}

const CardHeader = ({ children, className, ...props }: CardHeaderProps) => {
  const context = useContext(CardContext)
  return (
    <div className={cn(headerVariants(context), className)} {...props}>
      {children}
    </div>
  )
}

const CardContent = ({ children, className, ...props }: CardContentProps) => {
  const context = useContext(CardContext)
  return (
    <div className={cn(contentVariants(context), className)} {...props}>
      {children}
    </div>
  )
}

// Export compound component
Card.Header = CardHeader
Card.Content = CardContent
Card.Footer = CardFooter

export { Card }
```

### 2. Form Handling Best Practices

#### Advanced Form Pattern with Validation
```typescript
// components/forms/advanced-form.tsx
import { useForm, useFieldArray } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'

const formSchema = z.object({
  title: z.string().min(1, 'Title is required'),
  description: z.string().optional(),
  tags: z.array(z.string()).min(1, 'At least one tag is required'),
  settings: z.object({
    isPublic: z.boolean(),
    allowComments: z.boolean(),
    notifyByEmail: z.boolean()
  }),
  collaborators: z.array(z.object({
    email: z.string().email(),
    role: z.enum(['viewer', 'editor', 'admin'])
  }))
})

type FormData = z.infer<typeof formSchema>

export function AdvancedForm({ onSubmit, defaultValues }: AdvancedFormProps) {
  const form = useForm<FormData>({
    resolver: zodResolver(formSchema),
    defaultValues: {
      title: '',
      description: '',
      tags: [],
      settings: {
        isPublic: false,
        allowComments: true,
        notifyByEmail: true
      },
      collaborators: [],
      ...defaultValues
    }
  })

  const { fields, append, remove } = useFieldArray({
    control: form.control,
    name: 'collaborators'
  })

  const handleSubmit = async (data: FormData) => {
    try {
      await onSubmit(data)
      form.reset()
    } catch (error) {
      form.setError('root', { 
        message: 'Failed to submit form. Please try again.' 
      })
    }
  }

  return (
    <Form {...form}>
      <form onSubmit={form.handleSubmit(handleSubmit)} className="space-y-6">
        {/* Basic fields */}
        <FormField
          control={form.control}
          name="title"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Title</FormLabel>
              <FormControl>
                <Input placeholder="Enter title" {...field} />
              </FormControl>
              <FormMessage />
            </FormItem>
          )}
        />

        {/* Dynamic array fields */}
        <div className="space-y-4">
          <Label>Collaborators</Label>
          {fields.map((field, index) => (
            <div key={field.id} className="flex items-end space-x-2">
              <FormField
                control={form.control}
                name={`collaborators.${index}.email`}
                render={({ field }) => (
                  <FormItem className="flex-1">
                    <FormControl>
                      <Input placeholder="Email" {...field} />
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
                onClick={() => remove(index)}
              >
                <Trash2 className="h-4 w-4" />
              </Button>
            </div>
          ))}
          <Button
            type="button"
            variant="outline"
            onClick={() => append({ email: '', role: 'viewer' })}
          >
            Add Collaborator
          </Button>
        </div>

        <Button type="submit" disabled={form.formState.isSubmitting}>
          {form.formState.isSubmitting ? 'Saving...' : 'Save'}
        </Button>
      </form>
    </Form>
  )
}
```

## 🌐 API Integration Best Practices

### 1. React Query Configuration

#### Advanced Query Client Setup
```typescript
// lib/react-query.tsx
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { ReactQueryDevtools } from '@tanstack/react-query-devtools'
import { toast } from 'sonner'

export function createQueryClient() {
  return new QueryClient({
    defaultOptions: {
      queries: {
        staleTime: 60 * 1000, // 1 minute
        gcTime: 1000 * 60 * 60 * 24, // 24 hours
        retry: (failureCount, error) => {
          // Don't retry on 4xx errors except 408, 429
          if (error instanceof Error) {
            const status = (error as any).status
            if (status >= 400 && status < 500 && ![408, 429].includes(status)) {
              return false
            }
          }
          return failureCount < 3
        },
        retryDelay: (attemptIndex) => Math.min(1000 * 2 ** attemptIndex, 30000)
      },
      mutations: {
        onError: (error) => {
          toast.error(error.message || 'Something went wrong')
        }
      }
    }
  })
}
```

#### Custom Hooks with Error Handling
```typescript
// hooks/use-projects.ts
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { toast } from 'sonner'

export function useProjects(filters?: ProjectFilters) {
  return useQuery({
    queryKey: ['projects', filters],
    queryFn: () => projectsApi.getProjects(filters),
    select: (data) => data.projects, // Transform data
    placeholderData: (previousData) => previousData, // Keep previous data while loading
    meta: {
      errorMessage: 'Failed to load projects'
    }
  })
}

export function useCreateProject() {
  const queryClient = useQueryClient()
  
  return useMutation({
    mutationFn: projectsApi.createProject,
    onMutate: async (newProject) => {
      // Optimistic update
      await queryClient.cancelQueries({ queryKey: ['projects'] })
      
      const previousProjects = queryClient.getQueryData(['projects'])
      
      queryClient.setQueryData(['projects'], (old: any) => ({
        ...old,
        projects: [...(old?.projects || []), { ...newProject, id: 'temp-id' }]
      }))
      
      return { previousProjects }
    },
    onError: (err, variables, context) => {
      // Revert optimistic update
      if (context?.previousProjects) {
        queryClient.setQueryData(['projects'], context.previousProjects)
      }
      toast.error('Failed to create project')
    },
    onSuccess: (data) => {
      // Invalidate and refetch
      queryClient.invalidateQueries({ queryKey: ['projects'] })
      toast.success('Project created successfully')
    }
  })
}
```

### 2. Server Actions Best Practices

#### Type-Safe Server Actions
```typescript
// lib/actions/project-actions.ts
'use server'

import { auth } from '@clerk/nextjs'
import { z } from 'zod'
import { revalidatePath } from 'next/cache'

// Define action result type
type ActionResult<T> = {
  success: true
  data: T
} | {
  success: false
  error: string
  fieldErrors?: Record<string, string[]>
}

const createProjectSchema = z.object({
  name: z.string().min(1, 'Name is required').max(100, 'Name too long'),
  description: z.string().max(500, 'Description too long').optional()
})

export async function createProject(
  formData: FormData
): Promise<ActionResult<Project>> {
  try {
    // Authentication check
    const { userId } = auth()
    if (!userId) {
      return { success: false, error: 'Unauthorized' }
    }

    // Validation
    const result = createProjectSchema.safeParse({
      name: formData.get('name'),
      description: formData.get('description')
    })

    if (!result.success) {
      return {
        success: false,
        error: 'Validation failed',
        fieldErrors: result.error.flatten().fieldErrors
      }
    }

    // Business logic
    const project = await prisma.project.create({
      data: {
        ...result.data,
        userId,
        createdAt: new Date()
      }
    })

    // Revalidate relevant paths
    revalidatePath('/dashboard/projects')
    
    return { success: true, data: project }

  } catch (error) {
    console.error('Failed to create project:', error)
    return { 
      success: false, 
      error: 'Failed to create project. Please try again.' 
    }
  }
}
```

## 🚀 Performance Best Practices

### 1. Component Optimization

#### React.memo and useMemo Usage
```typescript
// Memoize expensive components
const ProjectCard = React.memo(({ project, onUpdate }: ProjectCardProps) => {
  // Memoize expensive calculations
  const projectStats = useMemo(() => {
    return calculateProjectStats(project)
  }, [project.id, project.lastUpdated])

  // Memoize callback functions
  const handleUpdate = useCallback((updates: Partial<Project>) => {
    onUpdate(project.id, updates)
  }, [project.id, onUpdate])

  return (
    <Card>
      <CardHeader>
        <h3>{project.name}</h3>
      </CardHeader>
      <CardContent>
        <ProjectStats stats={projectStats} />
        <ProjectActions onUpdate={handleUpdate} />
      </CardContent>
    </Card>
  )
})
```

#### Lazy Loading and Code Splitting
```typescript
// Lazy load heavy components
const ProjectAnalytics = lazy(() => import('./project-analytics'))
const ProjectSettings = lazy(() => import('./project-settings'))

function ProjectTabs({ activeTab }: ProjectTabsProps) {
  return (
    <Tabs value={activeTab}>
      <TabsContent value="overview">
        <ProjectOverview />
      </TabsContent>
      <TabsContent value="analytics">
        <Suspense fallback={<AnalyticsLoader />}>
          <ProjectAnalytics />
        </Suspense>
      </TabsContent>
      <TabsContent value="settings">
        <Suspense fallback={<SettingsLoader />}>
          <ProjectSettings />
        </Suspense>
      </TabsContent>
    </Tabs>
  )
}
```

### 2. Next.js Performance Optimization

#### Image Optimization
```typescript
// Optimized image component
import Image from 'next/image'

function ProjectThumbnail({ project }: { project: Project }) {
  return (
    <div className="relative w-full h-48">
      <Image
        src={project.thumbnail || '/placeholder-project.jpg'}
        alt={project.name}
        fill
        className="object-cover rounded-lg"
        sizes="(max-width: 768px) 100vw, (max-width: 1200px) 50vw, 33vw"
        priority={project.featured} // Only for above-the-fold images
        placeholder="blur"
        blurDataURL="data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAYEBQYFBAYGBQYHBwYIChAKCgkJChQODwwQFxQYGBcUFhYaHSUfGhsjHBYWICwgIyYnKSopGR8tMC0oMCUoKSj/2wBDAQcHBwoIChMKChMoGhYaKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCj/wAARCAAIAAoDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAv/xAAhEAACAQMDBQAAAAAAAAAAAAABAgMABAUGIWGRkqGx0f/EABUBAQEAAAAAAAAAAAAAAAAAAAMF/8QAGhEAAgIDAAAAAAAAAAAAAAAAAAECEgMRkf/aAAwDAQACEQMRAD8AltJagyeH0AthI5xdrLcNM91BF5pX2HaH9bcfaSXWGaRmknyJckliyjqTzSlT54b6bk+h0R//2Q=="
      />
    </div>
  )
}
```

#### Bundle Analysis and Optimization
```typescript
// next.config.js
const withBundleAnalyzer = require('@next/bundle-analyzer')({
  enabled: process.env.ANALYZE === 'true'
})

module.exports = withBundleAnalyzer({
  experimental: {
    optimizePackageImports: ['@radix-ui/react-icons', 'lucide-react']
  },
  images: {
    domains: ['images.unsplash.com', 'avatars.githubusercontent.com'],
    formats: ['image/avif', 'image/webp']
  },
  webpack: (config) => {
    // Optimize bundle size
    config.module.rules.push({
      test: /\.svg$/,
      use: ['@svgr/webpack']
    })
    return config
  }
})
```

## 🧪 Testing Best Practices

### 1. Component Testing
```typescript
// __tests__/components/project-card.test.tsx
import { render, screen, fireEvent } from '@testing-library/react'
import { ProjectCard } from '@/components/project-card'

const mockProject = {
  id: '1',
  name: 'Test Project',
  description: 'Test Description',
  createdAt: '2024-01-01'
}

describe('ProjectCard', () => {
  it('renders project information correctly', () => {
    render(<ProjectCard project={mockProject} />)
    
    expect(screen.getByText('Test Project')).toBeInTheDocument()
    expect(screen.getByText('Test Description')).toBeInTheDocument()
  })

  it('calls onUpdate when edit button is clicked', () => {
    const onUpdate = jest.fn()
    render(<ProjectCard project={mockProject} onUpdate={onUpdate} />)
    
    fireEvent.click(screen.getByRole('button', { name: /edit/i }))
    expect(onUpdate).toHaveBeenCalledWith(mockProject.id)
  })
})
```

### 2. Integration Testing
```typescript
// __tests__/integration/project-workflow.test.tsx
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { ProjectDashboard } from '@/components/project-dashboard'

const createTestQueryClient = () => new QueryClient({
  defaultOptions: {
    queries: { retry: false },
    mutations: { retry: false }
  }
})

describe('Project Workflow', () => {
  it('creates and displays a new project', async () => {
    const queryClient = createTestQueryClient()
    
    render(
      <QueryClientProvider client={queryClient}>
        <ProjectDashboard />
      </QueryClientProvider>
    )

    // Create project
    fireEvent.click(screen.getByRole('button', { name: /create project/i }))
    fireEvent.change(screen.getByLabelText(/project name/i), {
      target: { value: 'New Project' }
    })
    fireEvent.click(screen.getByRole('button', { name: /save/i }))

    // Verify project appears
    await waitFor(() => {
      expect(screen.getByText('New Project')).toBeInTheDocument()
    })
  })
})
```

## 🔗 Navigation

**← Previous**: [Implementation Guide](./implementation-guide.md)  
**→ Next**: [Comparison Analysis](./comparison-analysis.md)

---

**Related Best Practices:**
- [Express.js Testing Best Practices](../../backend/express-testing-frameworks-comparison/best-practices.md)
- [Clean Architecture Best Practices](../../architecture/clean-architecture-analysis/best-practices.md)