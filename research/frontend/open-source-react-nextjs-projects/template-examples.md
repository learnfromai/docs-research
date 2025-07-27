# Template Examples: Production-Ready React/Next.js Code

## Overview

This document provides working code examples and templates extracted from successful open source React and Next.js projects. These templates demonstrate real-world implementation patterns and can be used as starting points for new projects or features.

## Project Setup Templates

### 1. Next.js 14 with App Router Template

**Project Structure**:
```
my-nextjs-app/
├── app/
│   ├── (auth)/
│   │   ├── login/
│   │   │   └── page.tsx
│   │   └── register/
│   │       └── page.tsx
│   ├── dashboard/
│   │   ├── layout.tsx
│   │   ├── page.tsx
│   │   └── projects/
│   │       ├── page.tsx
│   │       └── [id]/
│   │           └── page.tsx
│   ├── api/
│   │   ├── auth/
│   │   │   └── route.ts
│   │   └── projects/
│   │       └── route.ts
│   ├── globals.css
│   ├── layout.tsx
│   └── page.tsx
├── components/
├── lib/
├── hooks/
└── stores/
```

**Root Layout Template** (`app/layout.tsx`):
```typescript
import type { Metadata } from 'next';
import { Inter } from 'next/font/google';
import { Providers } from '@/components/providers';
import { Toaster } from '@/components/ui/toaster';
import './globals.css';

const inter = Inter({ subsets: ['latin'] });

export const metadata: Metadata = {
  title: {
    default: 'My App',
    template: '%s | My App',
  },
  description: 'Production-ready Next.js application',
  keywords: ['Next.js', 'React', 'TypeScript'],
  authors: [{ name: 'Your Name' }],
  creator: 'Your Name',
  metadataBase: new URL(process.env.NEXT_PUBLIC_APP_URL || 'http://localhost:3000'),
  openGraph: {
    type: 'website',
    locale: 'en_US',
    url: '/',
    title: 'My App',
    description: 'Production-ready Next.js application',
    siteName: 'My App',
  },
  twitter: {
    card: 'summary_large_image',
    title: 'My App',
    description: 'Production-ready Next.js application',
    creator: '@yourusername',
  },
  robots: {
    index: true,
    follow: true,
    googleBot: {
      index: true,
      follow: true,
      'max-video-preview': -1,
      'max-image-preview': 'large',
      'max-snippet': -1,
    },
  },
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body className={inter.className}>
        <Providers>
          {children}
          <Toaster />
        </Providers>
      </body>
    </html>
  );
}
```

**Providers Template** (`components/providers.tsx`):
```typescript
'use client';

import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { ReactQueryDevtools } from '@tanstack/react-query-devtools';
import { ThemeProvider } from 'next-themes';
import { SessionProvider } from 'next-auth/react';
import { useState } from 'react';

interface ProvidersProps {
  children: React.ReactNode;
}

export function Providers({ children }: ProvidersProps) {
  const [queryClient] = useState(
    () =>
      new QueryClient({
        defaultOptions: {
          queries: {
            staleTime: 5 * 60 * 1000, // 5 minutes
            gcTime: 10 * 60 * 1000, // 10 minutes
            retry: (failureCount, error: any) => {
              if (error?.status >= 400 && error?.status < 500) {
                return false;
              }
              return failureCount < 3;
            },
          },
        },
      })
  );

  return (
    <QueryClientProvider client={queryClient}>
      <SessionProvider>
        <ThemeProvider
          attribute="class"
          defaultTheme="system"
          enableSystem
          disableTransitionOnChange
        >
          {children}
          <ReactQueryDevtools initialIsOpen={false} />
        </ThemeProvider>
      </SessionProvider>
    </QueryClientProvider>
  );
}
```

### 2. React + Vite Template

**Vite Configuration** (`vite.config.ts`):
```typescript
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react-swc';
import path from 'path';

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
  server: {
    port: 3000,
    proxy: {
      '/api': {
        target: 'http://localhost:8000',
        changeOrigin: true,
        rewrite: (path) => path.replace(/^\/api/, ''),
      },
    },
  },
  build: {
    rollupOptions: {
      output: {
        manualChunks: {
          vendor: ['react', 'react-dom'],
          ui: ['@radix-ui/react-dialog', '@radix-ui/react-dropdown-menu'],
        },
      },
    },
  },
});
```

**Main App Component** (`src/App.tsx`):
```typescript
import { BrowserRouter } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { ReactQueryDevtools } from '@tanstack/react-query-devtools';
import { Toaster } from 'react-hot-toast';
import { AppRoutes } from './routes';
import { AuthProvider } from './contexts/AuthContext';
import { ThemeProvider } from './contexts/ThemeContext';
import { ErrorBoundary } from './components/ErrorBoundary';
import './App.css';

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 5 * 60 * 1000,
      retry: false,
    },
  },
});

function App() {
  return (
    <ErrorBoundary>
      <QueryClientProvider client={queryClient}>
        <BrowserRouter>
          <ThemeProvider>
            <AuthProvider>
              <AppRoutes />
              <Toaster position="top-right" />
              <ReactQueryDevtools initialIsOpen={false} />
            </AuthProvider>
          </ThemeProvider>
        </BrowserRouter>
      </QueryClientProvider>
    </ErrorBoundary>
  );
}

export default App;
```

## Component Templates

### 1. Form Component with Validation

**User Registration Form** (Based on Cal.com patterns):
```typescript
'use client';

import { useState } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Icons } from '@/components/ui/icons';
import { useAuth } from '@/hooks/use-auth';

const registerSchema = z.object({
  name: z.string().min(2, 'Name must be at least 2 characters'),
  email: z.string().email('Invalid email address'),
  password: z
    .string()
    .min(8, 'Password must be at least 8 characters')
    .regex(
      /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]/,
      'Password must contain uppercase, lowercase, number, and special character'
    ),
  confirmPassword: z.string(),
}).refine((data) => data.password === data.confirmPassword, {
  message: "Passwords don't match",
  path: ['confirmPassword'],
});

type RegisterFormData = z.infer<typeof registerSchema>;

export function RegisterForm() {
  const [isLoading, setIsLoading] = useState(false);
  const { register: registerUser } = useAuth();

  const form = useForm<RegisterFormData>({
    resolver: zodResolver(registerSchema),
    defaultValues: {
      name: '',
      email: '',
      password: '',
      confirmPassword: '',
    },
  });

  const onSubmit = async (data: RegisterFormData) => {
    setIsLoading(true);
    try {
      await registerUser({
        name: data.name,
        email: data.email,
        password: data.password,
      });
    } catch (error) {
      form.setError('root', {
        message: error instanceof Error ? error.message : 'Registration failed',
      });
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <Card className="w-full max-w-md mx-auto">
      <CardHeader className="space-y-1">
        <CardTitle className="text-2xl font-bold">Create an account</CardTitle>
        <CardDescription>
          Enter your information to create your account
        </CardDescription>
      </CardHeader>
      <CardContent>
        <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-4">
          <div className="space-y-2">
            <Label htmlFor="name">Full Name</Label>
            <Input
              id="name"
              {...form.register('name')}
              placeholder="John Doe"
              disabled={isLoading}
            />
            {form.formState.errors.name && (
              <p className="text-sm text-destructive">
                {form.formState.errors.name.message}
              </p>
            )}
          </div>

          <div className="space-y-2">
            <Label htmlFor="email">Email</Label>
            <Input
              id="email"
              type="email"
              {...form.register('email')}
              placeholder="john@example.com"
              disabled={isLoading}
            />
            {form.formState.errors.email && (
              <p className="text-sm text-destructive">
                {form.formState.errors.email.message}
              </p>
            )}
          </div>

          <div className="space-y-2">
            <Label htmlFor="password">Password</Label>
            <Input
              id="password"
              type="password"
              {...form.register('password')}
              disabled={isLoading}
            />
            {form.formState.errors.password && (
              <p className="text-sm text-destructive">
                {form.formState.errors.password.message}
              </p>
            )}
          </div>

          <div className="space-y-2">
            <Label htmlFor="confirmPassword">Confirm Password</Label>
            <Input
              id="confirmPassword"
              type="password"
              {...form.register('confirmPassword')}
              disabled={isLoading}
            />
            {form.formState.errors.confirmPassword && (
              <p className="text-sm text-destructive">
                {form.formState.errors.confirmPassword.message}
              </p>
            )}
          </div>

          {form.formState.errors.root && (
            <p className="text-sm text-destructive">
              {form.formState.errors.root.message}
            </p>
          )}

          <Button type="submit" className="w-full" disabled={isLoading}>
            {isLoading && <Icons.spinner className="mr-2 h-4 w-4 animate-spin" />}
            Create Account
          </Button>
        </form>

        <div className="mt-4 text-center text-sm">
          Already have an account?{' '}
          <Button variant="link" className="p-0">
            Sign in
          </Button>
        </div>
      </CardContent>
    </Card>
  );
}
```

### 2. Data Table with Filtering and Sorting

**Project Data Table** (Based on Plane patterns):
```typescript
'use client';

import { useState, useMemo } from 'react';
import {
  useReactTable,
  getCoreRowModel,
  getFilteredRowModel,
  getPaginationRowModel,
  getSortedRowModel,
  createColumnHelper,
  flexRender,
} from '@tanstack/react-table';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Badge } from '@/components/ui/badge';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import { Icons } from '@/components/ui/icons';
import { formatDate } from '@/lib/utils';

interface Project {
  id: string;
  name: string;
  description: string;
  status: 'active' | 'inactive' | 'archived';
  createdAt: Date;
  updatedAt: Date;
  memberCount: number;
  owner: {
    name: string;
    email: string;
  };
}

interface ProjectTableProps {
  projects: Project[];
  onEdit: (project: Project) => void;
  onDelete: (projectId: string) => void;
}

const columnHelper = createColumnHelper<Project>();

export function ProjectTable({ projects, onEdit, onDelete }: ProjectTableProps) {
  const [globalFilter, setGlobalFilter] = useState('');
  const [statusFilter, setStatusFilter] = useState<Project['status'] | 'all'>('all');

  const filteredProjects = useMemo(() => {
    return projects.filter(project => {
      const matchesSearch = 
        project.name.toLowerCase().includes(globalFilter.toLowerCase()) ||
        project.description.toLowerCase().includes(globalFilter.toLowerCase()) ||
        project.owner.name.toLowerCase().includes(globalFilter.toLowerCase());
      
      const matchesStatus = statusFilter === 'all' || project.status === statusFilter;
      
      return matchesSearch && matchesStatus;
    });
  }, [projects, globalFilter, statusFilter]);

  const columns = useMemo(() => [
    columnHelper.accessor('name', {
      header: 'Project',
      cell: ({ row }) => (
        <div>
          <div className="font-medium">{row.original.name}</div>
          <div className="text-sm text-muted-foreground">
            {row.original.description}
          </div>
        </div>
      ),
    }),
    columnHelper.accessor('status', {
      header: 'Status',
      cell: ({ getValue }) => {
        const status = getValue();
        const variant = {
          active: 'default',
          inactive: 'secondary',
          archived: 'outline',
        }[status] as 'default' | 'secondary' | 'outline';
        
        return (
          <Badge variant={variant} className="capitalize">
            {status}
          </Badge>
        );
      },
    }),
    columnHelper.accessor('owner', {
      header: 'Owner',
      cell: ({ getValue }) => {
        const owner = getValue();
        return (
          <div>
            <div className="font-medium">{owner.name}</div>
            <div className="text-sm text-muted-foreground">{owner.email}</div>
          </div>
        );
      },
    }),
    columnHelper.accessor('memberCount', {
      header: 'Members',
      cell: ({ getValue }) => (
        <div className="text-center">{getValue()}</div>
      ),
    }),
    columnHelper.accessor('updatedAt', {
      header: 'Last Updated',
      cell: ({ getValue }) => formatDate(getValue()),
    }),
    columnHelper.display({
      id: 'actions',
      header: 'Actions',
      cell: ({ row }) => (
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <Button variant="ghost" size="sm">
              <Icons.moreHorizontal className="h-4 w-4" />
            </Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end">
            <DropdownMenuItem onClick={() => onEdit(row.original)}>
              <Icons.edit className="mr-2 h-4 w-4" />
              Edit
            </DropdownMenuItem>
            <DropdownMenuItem
              onClick={() => onDelete(row.original.id)}
              className="text-destructive"
            >
              <Icons.trash className="mr-2 h-4 w-4" />
              Delete
            </DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>
      ),
    }),
  ], [onEdit, onDelete]);

  const table = useReactTable({
    data: filteredProjects,
    columns,
    getCoreRowModel: getCoreRowModel(),
    getFilteredRowModel: getFilteredRowModel(),
    getPaginationRowModel: getPaginationRowModel(),
    getSortedRowModel: getSortedRowModel(),
    state: {
      globalFilter,
    },
    onGlobalFilterChange: setGlobalFilter,
  });

  return (
    <div className="space-y-4">
      {/* Filters */}
      <div className="flex items-center justify-between">
        <div className="flex items-center space-x-2">
          <Input
            placeholder="Search projects..."
            value={globalFilter}
            onChange={(e) => setGlobalFilter(e.target.value)}
            className="max-w-sm"
          />
          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button variant="outline" className="capitalize">
                {statusFilter === 'all' ? 'All Status' : statusFilter}
                <Icons.chevronDown className="ml-2 h-4 w-4" />
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent>
              <DropdownMenuItem onClick={() => setStatusFilter('all')}>
                All Status
              </DropdownMenuItem>
              <DropdownMenuItem onClick={() => setStatusFilter('active')}>
                Active
              </DropdownMenuItem>
              <DropdownMenuItem onClick={() => setStatusFilter('inactive')}>
                Inactive
              </DropdownMenuItem>
              <DropdownMenuItem onClick={() => setStatusFilter('archived')}>
                Archived
              </DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
        </div>
        <div className="text-sm text-muted-foreground">
          {table.getFilteredRowModel().rows.length} of {projects.length} projects
        </div>
      </div>

      {/* Table */}
      <div className="rounded-md border">
        <Table>
          <TableHeader>
            {table.getHeaderGroups().map((headerGroup) => (
              <TableRow key={headerGroup.id}>
                {headerGroup.headers.map((header) => (
                  <TableHead
                    key={header.id}
                    className={header.column.getCanSort() ? 'cursor-pointer' : ''}
                    onClick={header.column.getToggleSortingHandler()}
                  >
                    {header.isPlaceholder
                      ? null
                      : flexRender(header.column.columnDef.header, header.getContext())}
                    {header.column.getCanSort() && (
                      <Icons.arrowUpDown className="ml-2 h-4 w-4 inline" />
                    )}
                  </TableHead>
                ))}
              </TableRow>
            ))}
          </TableHeader>
          <TableBody>
            {table.getRowModel().rows?.length ? (
              table.getRowModel().rows.map((row) => (
                <TableRow key={row.id}>
                  {row.getVisibleCells().map((cell) => (
                    <TableCell key={cell.id}>
                      {flexRender(cell.column.columnDef.cell, cell.getContext())}
                    </TableCell>
                  ))}
                </TableRow>
              ))
            ) : (
              <TableRow>
                <TableCell colSpan={columns.length} className="h-24 text-center">
                  No projects found.
                </TableCell>
              </TableRow>
            )}
          </TableBody>
        </Table>
      </div>

      {/* Pagination */}
      <div className="flex items-center justify-between">
        <div className="text-sm text-muted-foreground">
          Page {table.getState().pagination.pageIndex + 1} of {table.getPageCount()}
        </div>
        <div className="flex items-center space-x-2">
          <Button
            variant="outline"
            size="sm"
            onClick={() => table.previousPage()}
            disabled={!table.getCanPreviousPage()}
          >
            Previous
          </Button>
          <Button
            variant="outline"
            size="sm"
            onClick={() => table.nextPage()}
            disabled={!table.getCanNextPage()}
          >
            Next
          </Button>
        </div>
      </div>
    </div>
  );
}
```

## State Management Templates

### 1. Zustand Store Template

**Feature-based Store Structure**:
```typescript
// stores/useAuthStore.ts
import { create } from 'zustand';
import { devtools, persist, subscribeWithSelector } from 'zustand/middleware';

interface User {
  id: string;
  email: string;
  name: string;
  role: 'admin' | 'user';
  avatar?: string;
}

interface AuthState {
  user: User | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  error: string | null;
}

interface AuthActions {
  setUser: (user: User | null) => void;
  setLoading: (loading: boolean) => void;
  setError: (error: string | null) => void;
  login: (email: string, password: string) => Promise<void>;
  logout: () => Promise<void>;
  checkAuth: () => Promise<void>;
}

type AuthStore = AuthState & AuthActions;

export const useAuthStore = create<AuthStore>()(
  devtools(
    persist(
      subscribeWithSelector((set, get) => ({
        // Initial state
        user: null,
        isAuthenticated: false,
        isLoading: false,
        error: null,

        // Actions
        setUser: (user) =>
          set({ user, isAuthenticated: !!user }, false, 'setUser'),

        setLoading: (isLoading) =>
          set({ isLoading }, false, 'setLoading'),

        setError: (error) =>
          set({ error }, false, 'setError'),

        login: async (email, password) => {
          set({ isLoading: true, error: null }, false, 'login/start');
          
          try {
            const response = await fetch('/api/auth/login', {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ email, password }),
            });

            if (!response.ok) {
              throw new Error('Invalid credentials');
            }

            const { user } = await response.json();
            set(
              { user, isAuthenticated: true, isLoading: false, error: null },
              false,
              'login/success'
            );
          } catch (error) {
            set(
              {
                error: error instanceof Error ? error.message : 'Login failed',
                isLoading: false,
              },
              false,
              'login/error'
            );
            throw error;
          }
        },

        logout: async () => {
          set({ isLoading: true }, false, 'logout/start');
          
          try {
            await fetch('/api/auth/logout', { method: 'POST' });
          } catch (error) {
            console.error('Logout error:', error);
          } finally {
            set(
              {
                user: null,
                isAuthenticated: false,
                isLoading: false,
                error: null,
              },
              false,
              'logout/complete'
            );
          }
        },

        checkAuth: async () => {
          set({ isLoading: true }, false, 'checkAuth/start');
          
          try {
            const response = await fetch('/api/auth/me');
            
            if (response.ok) {
              const { user } = await response.json();
              set(
                { user, isAuthenticated: true, isLoading: false },
                false,
                'checkAuth/success'
              );
            } else {
              set(
                { user: null, isAuthenticated: false, isLoading: false },
                false,
                'checkAuth/unauthenticated'
              );
            }
          } catch (error) {
            set(
              {
                user: null,
                isAuthenticated: false,
                isLoading: false,
                error: 'Authentication check failed',
              },
              false,
              'checkAuth/error'
            );
          }
        },
      })),
      {
        name: 'auth-storage',
        partialize: (state) => ({ user: state.user, isAuthenticated: state.isAuthenticated }),
      }
    ),
    { name: 'auth-store' }
  )
);

// Selectors for optimized component subscriptions
export const useUser = () => useAuthStore((state) => state.user);
export const useIsAuthenticated = () => useAuthStore((state) => state.isAuthenticated);
export const useAuthError = () => useAuthStore((state) => state.error);
export const useAuthLoading = () => useAuthStore((state) => state.isLoading);

// Auth actions hook
export const useAuthActions = () => useAuthStore((state) => ({
  login: state.login,
  logout: state.logout,
  checkAuth: state.checkAuth,
}));
```

### 2. TanStack Query Hooks Template

**API Layer with React Query**:
```typescript
// hooks/useProjects.ts
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { apiClient } from '@/lib/api-client';

export interface Project {
  id: string;
  name: string;
  description: string;
  status: 'active' | 'inactive' | 'archived';
  createdAt: string;
  updatedAt: string;
  ownerId: string;
}

export interface CreateProjectData {
  name: string;
  description: string;
  status?: Project['status'];
}

export interface UpdateProjectData extends Partial<CreateProjectData> {
  id: string;
}

// Query keys factory
export const projectKeys = {
  all: ['projects'] as const,
  lists: () => [...projectKeys.all, 'list'] as const,
  list: (filters: Record<string, any>) => [...projectKeys.lists(), { filters }] as const,
  details: () => [...projectKeys.all, 'detail'] as const,
  detail: (id: string) => [...projectKeys.details(), id] as const,
};

// Queries
export function useProjects(filters?: { status?: Project['status']; search?: string }) {
  return useQuery({
    queryKey: projectKeys.list(filters || {}),
    queryFn: () => apiClient.get<Project[]>('/projects', { params: filters }),
    staleTime: 5 * 60 * 1000, // 5 minutes
  });
}

export function useProject(id: string) {
  return useQuery({
    queryKey: projectKeys.detail(id),
    queryFn: () => apiClient.get<Project>(`/projects/${id}`),
    enabled: !!id,
  });
}

// Mutations
export function useCreateProject() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (data: CreateProjectData) =>
      apiClient.post<Project>('/projects', data),
    onMutate: async (newProject) => {
      // Cancel outgoing refetches
      await queryClient.cancelQueries({ queryKey: projectKeys.lists() });

      // Snapshot previous value
      const previousProjects = queryClient.getQueryData(projectKeys.lists());

      // Optimistically update
      queryClient.setQueriesData(
        { queryKey: projectKeys.lists() },
        (old: Project[] = []) => [
          ...old,
          {
            ...newProject,
            id: `temp-${Date.now()}`,
            createdAt: new Date().toISOString(),
            updatedAt: new Date().toISOString(),
            ownerId: 'current-user', // Replace with actual user ID
          } as Project,
        ]
      );

      return { previousProjects };
    },
    onError: (err, newProject, context) => {
      // Rollback on error
      queryClient.setQueriesData(
        { queryKey: projectKeys.lists() },
        context?.previousProjects
      );
    },
    onSettled: () => {
      // Always refetch after error or success
      queryClient.invalidateQueries({ queryKey: projectKeys.lists() });
    },
  });
}

export function useUpdateProject() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: ({ id, ...data }: UpdateProjectData) =>
      apiClient.put<Project>(`/projects/${id}`, data),
    onMutate: async (updatedProject) => {
      const { id } = updatedProject;

      // Cancel queries for this project
      await queryClient.cancelQueries({ queryKey: projectKeys.detail(id) });
      await queryClient.cancelQueries({ queryKey: projectKeys.lists() });

      // Snapshot previous values
      const previousProject = queryClient.getQueryData(projectKeys.detail(id));
      const previousProjects = queryClient.getQueryData(projectKeys.lists());

      // Optimistically update detail
      queryClient.setQueryData(projectKeys.detail(id), (old: Project) => ({
        ...old,
        ...updatedProject,
        updatedAt: new Date().toISOString(),
      }));

      // Optimistically update lists
      queryClient.setQueriesData(
        { queryKey: projectKeys.lists() },
        (old: Project[] = []) =>
          old.map((project) =>
            project.id === id
              ? { ...project, ...updatedProject, updatedAt: new Date().toISOString() }
              : project
          )
      );

      return { previousProject, previousProjects };
    },
    onError: (err, { id }, context) => {
      // Rollback on error
      if (context?.previousProject) {
        queryClient.setQueryData(projectKeys.detail(id), context.previousProject);
      }
      if (context?.previousProjects) {
        queryClient.setQueriesData(
          { queryKey: projectKeys.lists() },
          context.previousProjects
        );
      }
    },
    onSettled: (data, error, { id }) => {
      // Refetch affected queries
      queryClient.invalidateQueries({ queryKey: projectKeys.detail(id) });
      queryClient.invalidateQueries({ queryKey: projectKeys.lists() });
    },
  });
}

export function useDeleteProject() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (id: string) => apiClient.delete(`/projects/${id}`),
    onMutate: async (deletedId) => {
      // Cancel queries
      await queryClient.cancelQueries({ queryKey: projectKeys.lists() });

      // Snapshot previous value
      const previousProjects = queryClient.getQueryData(projectKeys.lists());

      // Optimistically remove
      queryClient.setQueriesData(
        { queryKey: projectKeys.lists() },
        (old: Project[] = []) => old.filter((project) => project.id !== deletedId)
      );

      return { previousProjects };
    },
    onError: (err, deletedId, context) => {
      // Rollback on error
      queryClient.setQueriesData(
        { queryKey: projectKeys.lists() },
        context?.previousProjects
      );
    },
    onSettled: (data, error, deletedId) => {
      // Clean up detail query
      queryClient.removeQueries({ queryKey: projectKeys.detail(deletedId) });
      // Refetch lists
      queryClient.invalidateQueries({ queryKey: projectKeys.lists() });
    },
  });
}

// Prefetching hook
export function usePrefetchProject() {
  const queryClient = useQueryClient();

  return (id: string) => {
    queryClient.prefetchQuery({
      queryKey: projectKeys.detail(id),
      queryFn: () => apiClient.get<Project>(`/projects/${id}`),
      staleTime: 5 * 60 * 1000,
    });
  };
}
```

## API Layer Templates

### 1. Type-Safe API Client

**Axios-based API Client**:
```typescript
// lib/api-client.ts
import axios, { AxiosInstance, AxiosRequestConfig, AxiosResponse } from 'axios';
import { z } from 'zod';

// API Response schemas
const ApiErrorSchema = z.object({
  message: z.string(),
  code: z.string().optional(),
  details: z.record(z.any()).optional(),
});

const ApiSuccessSchema = z.object({
  data: z.any(),
  message: z.string().optional(),
  meta: z.record(z.any()).optional(),
});

export type ApiError = z.infer<typeof ApiErrorSchema>;
export type ApiSuccess<T = any> = Omit<z.infer<typeof ApiSuccessSchema>, 'data'> & {
  data: T;
};

class ApiClient {
  private client: AxiosInstance;
  private baseURL: string;

  constructor(baseURL: string = '/api') {
    this.baseURL = baseURL;
    this.client = axios.create({
      baseURL,
      timeout: 10000,
      headers: {
        'Content-Type': 'application/json',
      },
    });

    this.setupInterceptors();
  }

  private setupInterceptors() {
    // Request interceptor
    this.client.interceptors.request.use(
      (config) => {
        // Add auth token if available
        const token = this.getAuthToken();
        if (token) {
          config.headers.Authorization = `Bearer ${token}`;
        }

        // Add request timestamp for debugging
        config.metadata = { startTime: Date.now() };
        
        return config;
      },
      (error) => Promise.reject(error)
    );

    // Response interceptor
    this.client.interceptors.response.use(
      (response) => {
        // Log response time in development
        if (process.env.NODE_ENV === 'development') {
          const duration = Date.now() - response.config.metadata?.startTime;
          console.log(`API ${response.config.method?.toUpperCase()} ${response.config.url}: ${duration}ms`);
        }

        return response;
      },
      async (error) => {
        const originalRequest = error.config;

        // Handle 401 errors
        if (error.response?.status === 401 && !originalRequest._retry) {
          originalRequest._retry = true;
          
          try {
            await this.refreshToken();
            const token = this.getAuthToken();
            if (token) {
              originalRequest.headers.Authorization = `Bearer ${token}`;
              return this.client(originalRequest);
            }
          } catch (refreshError) {
            // Redirect to login or handle refresh failure
            this.handleAuthFailure();
            return Promise.reject(refreshError);
          }
        }

        // Transform error response
        const apiError: ApiError = {
          message: error.response?.data?.message || error.message,
          code: error.response?.data?.code,
          details: error.response?.data?.details,
        };

        return Promise.reject(apiError);
      }
    );
  }

  private getAuthToken(): string | null {
    // Get token from localStorage, cookies, or auth store
    return localStorage.getItem('access_token');
  }

  private async refreshToken(): Promise<void> {
    const refreshToken = localStorage.getItem('refresh_token');
    if (!refreshToken) {
      throw new Error('No refresh token available');
    }

    const response = await axios.post(`${this.baseURL}/auth/refresh`, {
      refreshToken,
    });

    const { accessToken, refreshToken: newRefreshToken } = response.data;
    localStorage.setItem('access_token', accessToken);
    localStorage.setItem('refresh_token', newRefreshToken);
  }

  private handleAuthFailure(): void {
    localStorage.removeItem('access_token');
    localStorage.removeItem('refresh_token');
    window.location.href = '/auth/login';
  }

  // Generic request method
  private async request<T>(
    method: 'GET' | 'POST' | 'PUT' | 'DELETE' | 'PATCH',
    url: string,
    data?: any,
    config?: AxiosRequestConfig
  ): Promise<T> {
    try {
      const response: AxiosResponse<ApiSuccess<T>> = await this.client.request({
        method,
        url,
        data,
        ...config,
      });

      return response.data.data;
    } catch (error) {
      throw error;
    }
  }

  // HTTP methods
  async get<T>(url: string, config?: AxiosRequestConfig): Promise<T> {
    return this.request<T>('GET', url, undefined, config);
  }

  async post<T>(url: string, data?: any, config?: AxiosRequestConfig): Promise<T> {
    return this.request<T>('POST', url, data, config);
  }

  async put<T>(url: string, data?: any, config?: AxiosRequestConfig): Promise<T> {
    return this.request<T>('PUT', url, data, config);
  }

  async patch<T>(url: string, data?: any, config?: AxiosRequestConfig): Promise<T> {
    return this.request<T>('PATCH', url, data, config);
  }

  async delete<T>(url: string, config?: AxiosRequestConfig): Promise<T> {
    return this.request<T>('DELETE', url, undefined, config);
  }

  // File upload method
  async uploadFile<T>(
    url: string,
    file: File,
    onUploadProgress?: (progressEvent: any) => void
  ): Promise<T> {
    const formData = new FormData();
    formData.append('file', file);

    return this.request<T>('POST', url, formData, {
      headers: {
        'Content-Type': 'multipart/form-data',
      },
      onUploadProgress,
    });
  }
}

export const apiClient = new ApiClient();
```

### 2. Next.js API Route Template

**Type-Safe API Route Handler**:
```typescript
// app/api/projects/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import { auth } from '@/lib/auth';
import { prisma } from '@/lib/prisma';
import { createApiResponse, handleApiError } from '@/lib/api-utils';

// Request/Response schemas
const CreateProjectSchema = z.object({
  name: z.string().min(1).max(100),
  description: z.string().max(500).optional(),
  status: z.enum(['active', 'inactive', 'archived']).default('active'),
});

const GetProjectsSchema = z.object({
  page: z.coerce.number().min(1).default(1),
  limit: z.coerce.number().min(1).max(100).default(20),
  status: z.enum(['active', 'inactive', 'archived']).optional(),
  search: z.string().optional(),
});

export async function GET(request: NextRequest) {
  try {
    // Authenticate user
    const session = await auth();
    if (!session?.user) {
      return NextResponse.json(
        { message: 'Unauthorized' },
        { status: 401 }
      );
    }

    // Parse and validate query parameters
    const searchParams = request.nextUrl.searchParams;
    const queryParams = GetProjectsSchema.parse({
      page: searchParams.get('page'),
      limit: searchParams.get('limit'),
      status: searchParams.get('status'),
      search: searchParams.get('search'),
    });

    // Build where clause
    const where: any = {
      ownerId: session.user.id,
    };

    if (queryParams.status) {
      where.status = queryParams.status;
    }

    if (queryParams.search) {
      where.OR = [
        { name: { contains: queryParams.search, mode: 'insensitive' } },
        { description: { contains: queryParams.search, mode: 'insensitive' } },
      ];
    }

    // Fetch projects with pagination
    const [projects, totalCount] = await Promise.all([
      prisma.project.findMany({
        where,
        skip: (queryParams.page - 1) * queryParams.limit,
        take: queryParams.limit,
        orderBy: { updatedAt: 'desc' },
        include: {
          owner: {
            select: { id: true, name: true, email: true },
          },
          _count: {
            select: { members: true },
          },
        },
      }),
      prisma.project.count({ where }),
    ]);

    // Transform data
    const transformedProjects = projects.map(project => ({
      id: project.id,
      name: project.name,
      description: project.description,
      status: project.status,
      createdAt: project.createdAt,
      updatedAt: project.updatedAt,
      owner: project.owner,
      memberCount: project._count.members,
    }));

    return createApiResponse({
      data: transformedProjects,
      meta: {
        pagination: {
          page: queryParams.page,
          limit: queryParams.limit,
          total: totalCount,
          pages: Math.ceil(totalCount / queryParams.limit),
        },
      },
    });
  } catch (error) {
    return handleApiError(error);
  }
}

export async function POST(request: NextRequest) {
  try {
    // Authenticate user
    const session = await auth();
    if (!session?.user) {
      return NextResponse.json(
        { message: 'Unauthorized' },
        { status: 401 }
      );
    }

    // Parse and validate request body
    const body = await request.json();
    const validatedData = CreateProjectSchema.parse(body);

    // Create project
    const project = await prisma.project.create({
      data: {
        ...validatedData,
        ownerId: session.user.id,
      },
      include: {
        owner: {
          select: { id: true, name: true, email: true },
        },
        _count: {
          select: { members: true },
        },
      },
    });

    // Transform response
    const transformedProject = {
      id: project.id,
      name: project.name,
      description: project.description,
      status: project.status,
      createdAt: project.createdAt,
      updatedAt: project.updatedAt,
      owner: project.owner,
      memberCount: project._count.members,
    };

    return createApiResponse({
      data: transformedProject,
      message: 'Project created successfully',
    }, { status: 201 });
  } catch (error) {
    return handleApiError(error);
  }
}
```

## Testing Templates

### 1. Component Testing Template

**Complete Component Test Suite**:
```typescript
// components/__tests__/ProjectCard.test.tsx
import { render, screen, userEvent, waitFor } from '@testing-library/react';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { ProjectCard } from '../ProjectCard';
import { projectFactory } from '@/test-utils/factories';

// Test wrapper
function TestWrapper({ children }: { children: React.ReactNode }) {
  const queryClient = new QueryClient({
    defaultOptions: { queries: { retry: false }, mutations: { retry: false } },
  });

  return (
    <QueryClientProvider client={queryClient}>
      {children}
    </QueryClientProvider>
  );
}

describe('ProjectCard', () => {
  const mockOnEdit = vi.fn();
  const mockOnDelete = vi.fn();
  const mockProject = projectFactory({
    name: 'Test Project',
    description: 'A test project description',
    status: 'active',
  });

  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('renders project information correctly', () => {
    render(
      <ProjectCard
        project={mockProject}
        onEdit={mockOnEdit}
        onDelete={mockOnDelete}
      />,
      { wrapper: TestWrapper }
    );

    expect(screen.getByText('Test Project')).toBeInTheDocument();
    expect(screen.getByText('A test project description')).toBeInTheDocument();
    expect(screen.getByText('Active')).toBeInTheDocument();
  });

  it('calls onEdit when edit button is clicked', async () => {
    const user = userEvent.setup();
    
    render(
      <ProjectCard
        project={mockProject}
        onEdit={mockOnEdit}
        onDelete={mockOnDelete}
      />,
      { wrapper: TestWrapper }
    );

    const editButton = screen.getByRole('button', { name: /edit/i });
    await user.click(editButton);

    expect(mockOnEdit).toHaveBeenCalledWith(mockProject);
  });

  it('shows confirmation dialog before deletion', async () => {
    const user = userEvent.setup();
    
    render(
      <ProjectCard
        project={mockProject}
        onEdit={mockOnEdit}
        onDelete={mockOnDelete}
      />,
      { wrapper: TestWrapper }
    );

    const deleteButton = screen.getByRole('button', { name: /delete/i });
    await user.click(deleteButton);

    expect(screen.getByText(/are you sure you want to delete/i)).toBeInTheDocument();
    
    const confirmButton = screen.getByRole('button', { name: /confirm/i });
    await user.click(confirmButton);

    expect(mockOnDelete).toHaveBeenCalledWith(mockProject.id);
  });

  it('applies correct status styling', () => {
    const archivedProject = projectFactory({ status: 'archived' });
    
    render(
      <ProjectCard
        project={archivedProject}
        onEdit={mockOnEdit}
        onDelete={mockOnDelete}
      />,
      { wrapper: TestWrapper }
    );

    const statusBadge = screen.getByText('Archived');
    expect(statusBadge).toHaveClass('badge-outline');
  });

  it('handles loading state during operations', async () => {
    const user = userEvent.setup();
    
    // Mock a slow operation
    mockOnDelete.mockImplementation(() => 
      new Promise(resolve => setTimeout(resolve, 100))
    );

    render(
      <ProjectCard
        project={mockProject}
        onEdit={mockOnEdit}
        onDelete={mockOnDelete}
      />,
      { wrapper: TestWrapper }
    );

    const deleteButton = screen.getByRole('button', { name: /delete/i });
    await user.click(deleteButton);

    const confirmButton = screen.getByRole('button', { name: /confirm/i });
    await user.click(confirmButton);

    expect(screen.getByText(/deleting/i)).toBeInTheDocument();
    
    await waitFor(() => {
      expect(screen.queryByText(/deleting/i)).not.toBeInTheDocument();
    });
  });

  it('is accessible', async () => {
    const { container } = render(
      <ProjectCard
        project={mockProject}
        onEdit={mockOnEdit}
        onDelete={mockOnDelete}
      />,
      { wrapper: TestWrapper }
    );

    // Check for proper heading hierarchy
    expect(screen.getByRole('heading', { level: 3 })).toHaveTextContent('Test Project');
    
    // Check for accessible buttons
    expect(screen.getByRole('button', { name: /edit test project/i })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /delete test project/i })).toBeInTheDocument();

    // Check for ARIA labels
    const card = container.querySelector('[role="article"]');
    expect(card).toHaveAttribute('aria-labelledby');
  });
});
```

---

## Navigation

- ← Back to: [Best Practices](best-practices.md)
- → Next: [Testing Strategies](testing-strategies.md)
- 🏠 Home: [Research Overview](../../README.md)