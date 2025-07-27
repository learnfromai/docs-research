# Implementation Guide

Step-by-step guide for implementing modern React/Next.js applications using best practices identified from production open source projects.

## Getting Started: Project Setup

### Modern React/Next.js Stack Setup

#### 1. Project Initialization
```bash
# Create Next.js project with TypeScript
npx create-next-app@latest my-app --typescript --tailwind --eslint --app --src-dir

# Navigate to project
cd my-app

# Install essential dependencies
npm install @tanstack/react-query zustand @radix-ui/react-dialog @radix-ui/react-button
npm install class-variance-authority clsx tailwind-merge lucide-react
npm install zod react-hook-form @hookform/resolvers
npm install next-auth prisma @prisma/client

# Install development dependencies
npm install -D @types/node prisma @next/bundle-analyzer
```

#### 2. Project Structure Setup
```bash
# Create recommended directory structure
mkdir -p src/{components,hooks,lib,store,types,app}
mkdir -p src/components/{ui,forms,layout}
mkdir -p src/lib/{auth,db,utils,validations}
mkdir -p src/store/{slices}
mkdir -p src/types/{api,auth,database}

# Create essential files
touch src/lib/utils.ts
touch src/lib/db.ts
touch src/store/index.ts
touch src/types/index.ts
```

#### 3. Configuration Files

**TypeScript Configuration (tsconfig.json)**
```json
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
      "@/lib/*": ["./src/lib/*"],
      "@/hooks/*": ["./src/hooks/*"],
      "@/store/*": ["./src/store/*"],
      "@/types/*": ["./src/types/*"]
    }
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx", ".next/types/**/*.ts"],
  "exclude": ["node_modules"]
}
```

**Next.js Configuration (next.config.js)**
```javascript
/** @type {import('next').NextConfig} */
const nextConfig = {
  experimental: {
    typedRoutes: true,
  },
  images: {
    domains: ['localhost', 'your-domain.com'],
    formats: ['image/webp', 'image/avif'],
  },
  async headers() {
    return [
      {
        source: '/(.*)',
        headers: [
          {
            key: 'X-Frame-Options',
            value: 'DENY',
          },
          {
            key: 'X-Content-Type-Options',
            value: 'nosniff',
          },
          {
            key: 'Referrer-Policy',
            value: 'origin-when-cross-origin',
          },
        ],
      },
    ];
  },
};

// Bundle analyzer for production builds
const withBundleAnalyzer = require('@next/bundle-analyzer')({
  enabled: process.env.ANALYZE === 'true',
});

module.exports = withBundleAnalyzer(nextConfig);
```

**Environment Variables (.env.local)**
```bash
# Database
DATABASE_URL="postgresql://username:password@localhost:5432/myapp"

# Auth
NEXTAUTH_URL="http://localhost:3000"
NEXTAUTH_SECRET="your-secret-key-here"

# OAuth Providers
GOOGLE_CLIENT_ID="your-google-client-id"
GOOGLE_CLIENT_SECRET="your-google-client-secret"
GITHUB_ID="your-github-client-id"
GITHUB_SECRET="your-github-client-secret"

# API Keys
NEXT_PUBLIC_API_URL="http://localhost:3000/api"
```

## Core Setup Implementation

### 1. Utility Functions Setup

**src/lib/utils.ts**
```typescript
import { type ClassValue, clsx } from "clsx";
import { twMerge } from "tailwind-merge";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

export function formatDate(date: Date | string): string {
  return new Intl.DateTimeFormat('en-US', {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
  }).format(new Date(date));
}

export function formatCurrency(
  amount: number,
  currency: string = 'USD'
): string {
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency,
  }).format(amount);
}

export function sleep(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms));
}

export function debounce<T extends (...args: any[]) => any>(
  func: T,
  wait: number
): (...args: Parameters<T>) => void {
  let timeout: NodeJS.Timeout;
  return (...args: Parameters<T>) => {
    clearTimeout(timeout);
    timeout = setTimeout(() => func(...args), wait);
  };
}
```

### 2. Database Setup with Prisma

**Database Schema (prisma/schema.prisma)**
```prisma
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

model Account {
  id                String  @id @default(cuid())
  userId            String
  type              String
  provider          String
  providerAccountId String
  refresh_token     String? @db.Text
  access_token      String? @db.Text
  expires_at        Int?
  token_type        String?
  scope             String?
  id_token          String? @db.Text
  session_state     String?

  user User @relation(fields: [userId], references: [id], onDelete: Cascade)

  @@unique([provider, providerAccountId])
}

model Session {
  id           String   @id @default(cuid())
  sessionToken String   @unique
  userId       String
  expires      DateTime
  user         User     @relation(fields: [userId], references: [id], onDelete: Cascade)
}

model User {
  id            String    @id @default(cuid())
  name          String?
  email         String    @unique
  emailVerified DateTime?
  image         String?
  role          Role      @default(USER)
  accounts      Account[]
  sessions      Session[]
  posts         Post[]
  createdAt     DateTime  @default(now())
  updatedAt     DateTime  @updatedAt
}

model Post {
  id        String   @id @default(cuid())
  title     String
  content   String?
  published Boolean  @default(false)
  author    User     @relation(fields: [authorId], references: [id])
  authorId  String
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
}

enum Role {
  USER
  ADMIN
  MODERATOR
}
```

**Database Client (src/lib/db.ts)**
```typescript
import { PrismaClient } from '@prisma/client';

const globalForPrisma = globalThis as unknown as {
  prisma: PrismaClient | undefined;
};

export const prisma = globalForPrisma.prisma ?? new PrismaClient();

if (process.env.NODE_ENV !== 'production') globalForPrisma.prisma = prisma;

// Database initialization
export async function initializeDatabase() {
  try {
    await prisma.$connect();
    console.log('✅ Database connected successfully');
  } catch (error) {
    console.error('❌ Database connection failed:', error);
    process.exit(1);
  }
}

// Graceful shutdown
export async function disconnectDatabase() {
  await prisma.$disconnect();
}
```

### 3. Authentication Setup

**NextAuth Configuration (src/lib/auth.ts)**
```typescript
import { NextAuthOptions } from 'next-auth';
import { PrismaAdapter } from '@next-auth/prisma-adapter';
import GoogleProvider from 'next-auth/providers/google';
import GitHubProvider from 'next-auth/providers/github';
import { prisma } from '@/lib/db';

export const authOptions: NextAuthOptions = {
  adapter: PrismaAdapter(prisma),
  providers: [
    GoogleProvider({
      clientId: process.env.GOOGLE_CLIENT_ID!,
      clientSecret: process.env.GOOGLE_CLIENT_SECRET!,
    }),
    GitHubProvider({
      clientId: process.env.GITHUB_ID!,
      clientSecret: process.env.GITHUB_SECRET!,
    }),
  ],
  callbacks: {
    async session({ session, user }) {
      if (session.user) {
        session.user.id = user.id;
        session.user.role = user.role;
      }
      return session;
    },
    async jwt({ token, user }) {
      if (user) {
        token.role = user.role;
      }
      return token;
    },
  },
  pages: {
    signIn: '/auth/signin',
    error: '/auth/error',
  },
  session: {
    strategy: 'database',
  },
};
```

**Auth API Route (src/app/api/auth/[...nextauth]/route.ts)**
```typescript
import NextAuth from 'next-auth';
import { authOptions } from '@/lib/auth';

const handler = NextAuth(authOptions);

export { handler as GET, handler as POST };
```

### 4. State Management Setup

**Zustand Store (src/store/index.ts)**
```typescript
import { create } from 'zustand';
import { devtools, persist } from 'zustand/middleware';
import { immer } from 'zustand/middleware/immer';

interface User {
  id: string;
  name: string;
  email: string;
  role: string;
}

interface AppState {
  // State
  user: User | null;
  theme: 'light' | 'dark';
  sidebarOpen: boolean;
  
  // Actions
  setUser: (user: User | null) => void;
  setTheme: (theme: 'light' | 'dark') => void;
  toggleSidebar: () => void;
  
  // Computed
  isAuthenticated: boolean;
}

export const useAppStore = create<AppState>()(
  devtools(
    persist(
      immer((set, get) => ({
        // Initial state
        user: null,
        theme: 'light',
        sidebarOpen: false,

        // Actions
        setUser: (user) =>
          set((state) => {
            state.user = user;
          }),

        setTheme: (theme) =>
          set((state) => {
            state.theme = theme;
          }),

        toggleSidebar: () =>
          set((state) => {
            state.sidebarOpen = !state.sidebarOpen;
          }),

        // Computed properties
        get isAuthenticated() {
          return get().user !== null;
        },
      })),
      {
        name: 'app-store',
        partialize: (state) => ({ 
          theme: state.theme,
          sidebarOpen: state.sidebarOpen 
        }),
      }
    ),
    { name: 'app-store' }
  )
);

// Selectors for optimal re-rendering
export const useUser = () => useAppStore((state) => state.user);
export const useTheme = () => useAppStore((state) => state.theme);
export const useSidebarOpen = () => useAppStore((state) => state.sidebarOpen);
export const useIsAuthenticated = () => useAppStore((state) => state.isAuthenticated);
```

**React Query Setup (src/lib/query-client.ts)**
```typescript
import { QueryClient } from '@tanstack/react-query';

export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 5 * 60 * 1000, // 5 minutes
      cacheTime: 10 * 60 * 1000, // 10 minutes
      retry: (failureCount, error) => {
        // Don't retry on 4xx errors
        if (error instanceof Error && error.message.includes('4')) {
          return false;
        }
        return failureCount < 3;
      },
      refetchOnWindowFocus: false,
    },
    mutations: {
      retry: 1,
      onError: (error) => {
        console.error('Mutation error:', error);
      },
    },
  },
});

// Query key factory
export const queryKeys = {
  users: {
    all: ['users'] as const,
    lists: () => [...queryKeys.users.all, 'list'] as const,
    list: (filters: string) => [...queryKeys.users.lists(), { filters }] as const,
    details: () => [...queryKeys.users.all, 'detail'] as const,
    detail: (id: string) => [...queryKeys.users.details(), id] as const,
  },
  posts: {
    all: ['posts'] as const,
    lists: () => [...queryKeys.posts.all, 'list'] as const,
    list: (filters: string) => [...queryKeys.posts.lists(), { filters }] as const,
    details: () => [...queryKeys.posts.all, 'detail'] as const,
    detail: (id: string) => [...queryKeys.posts.details(), id] as const,
  },
};
```

## Component Library Implementation

### 1. Base UI Components

**Button Component (src/components/ui/button.tsx)**
```typescript
import * as React from 'react';
import { Slot } from '@radix-ui/react-slot';
import { cva, type VariantProps } from 'class-variance-authority';
import { cn } from '@/lib/utils';

const buttonVariants = cva(
  'inline-flex items-center justify-center whitespace-nowrap rounded-md text-sm font-medium ring-offset-background transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:pointer-events-none disabled:opacity-50',
  {
    variants: {
      variant: {
        default: 'bg-primary text-primary-foreground hover:bg-primary/90',
        destructive: 'bg-destructive text-destructive-foreground hover:bg-destructive/90',
        outline: 'border border-input bg-background hover:bg-accent hover:text-accent-foreground',
        secondary: 'bg-secondary text-secondary-foreground hover:bg-secondary/80',
        ghost: 'hover:bg-accent hover:text-accent-foreground',
        link: 'text-primary underline-offset-4 hover:underline',
      },
      size: {
        default: 'h-10 px-4 py-2',
        sm: 'h-9 rounded-md px-3',
        lg: 'h-11 rounded-md px-8',
        icon: 'h-10 w-10',
      },
    },
    defaultVariants: {
      variant: 'default',
      size: 'default',
    },
  }
);

export interface ButtonProps
  extends React.ButtonHTMLAttributes<HTMLButtonElement>,
    VariantProps<typeof buttonVariants> {
  asChild?: boolean;
}

const Button = React.forwardRef<HTMLButtonElement, ButtonProps>(
  ({ className, variant, size, asChild = false, ...props }, ref) => {
    const Comp = asChild ? Slot : 'button';
    return (
      <Comp
        className={cn(buttonVariants({ variant, size, className }))}
        ref={ref}
        {...props}
      />
    );
  }
);
Button.displayName = 'Button';

export { Button, buttonVariants };
```

**Input Component (src/components/ui/input.tsx)**
```typescript
import * as React from 'react';
import { cn } from '@/lib/utils';

export interface InputProps
  extends React.InputHTMLAttributes<HTMLInputElement> {}

const Input = React.forwardRef<HTMLInputElement, InputProps>(
  ({ className, type, ...props }, ref) => {
    return (
      <input
        type={type}
        className={cn(
          'flex h-10 w-full rounded-md border border-input bg-background px-3 py-2 text-sm ring-offset-background file:border-0 file:bg-transparent file:text-sm file:font-medium placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50',
          className
        )}
        ref={ref}
        {...props}
      />
    );
  }
);
Input.displayName = 'Input';

export { Input };
```

### 2. Form Components

**Form Hook (src/hooks/useForm.ts)**
```typescript
import { useForm as useHookForm, UseFormProps } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { ZodSchema } from 'zod';

interface UseFormOptions<T> extends Omit<UseFormProps<T>, 'resolver'> {
  schema: ZodSchema<T>;
}

export function useForm<T>({ schema, ...options }: UseFormOptions<T>) {
  return useHookForm<T>({
    resolver: zodResolver(schema),
    ...options,
  });
}
```

**Form Components (src/components/forms/form.tsx)**
```typescript
import * as React from 'react';
import { useFormContext, Controller } from 'react-hook-form';
import { cn } from '@/lib/utils';

interface FormFieldProps {
  name: string;
  label?: string;
  description?: string;
  required?: boolean;
  children: React.ReactNode;
}

export function FormField({ 
  name, 
  label, 
  description, 
  required, 
  children 
}: FormFieldProps) {
  const { formState: { errors } } = useFormContext();
  const error = errors[name];

  return (
    <div className="space-y-2">
      {label && (
        <label htmlFor={name} className="text-sm font-medium leading-none">
          {label}
          {required && <span className="text-destructive ml-1">*</span>}
        </label>
      )}
      {children}
      {description && (
        <p className="text-sm text-muted-foreground">{description}</p>
      )}
      {error && (
        <p className="text-sm text-destructive">{error.message as string}</p>
      )}
    </div>
  );
}

interface FormInputProps {
  name: string;
  placeholder?: string;
  type?: string;
  className?: string;
}

export function FormInput({ name, ...props }: FormInputProps) {
  const { register } = useFormContext();
  
  return (
    <input
      {...register(name)}
      {...props}
      className={cn(
        'flex h-10 w-full rounded-md border border-input bg-background px-3 py-2 text-sm ring-offset-background placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50',
        props.className
      )}
    />
  );
}
```

## API Integration Implementation

### 1. API Client Setup

**API Client (src/lib/api-client.ts)**
```typescript
import { z } from 'zod';

export class ApiError extends Error {
  constructor(
    message: string,
    public status: number,
    public code?: string
  ) {
    super(message);
    this.name = 'ApiError';
  }
}

class ApiClient {
  private baseUrl: string;

  constructor(baseUrl: string) {
    this.baseUrl = baseUrl;
  }

  private async request<T>(
    endpoint: string,
    options: RequestInit = {}
  ): Promise<T> {
    const url = `${this.baseUrl}${endpoint}`;
    
    const response = await fetch(url, {
      headers: {
        'Content-Type': 'application/json',
        ...options.headers,
      },
      ...options,
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new ApiError(
        errorData.message || 'An error occurred',
        response.status,
        errorData.code
      );
    }

    return response.json();
  }

  // Generic CRUD operations
  async get<T>(endpoint: string): Promise<T> {
    return this.request<T>(endpoint, { method: 'GET' });
  }

  async post<T>(endpoint: string, data: any): Promise<T> {
    return this.request<T>(endpoint, {
      method: 'POST',
      body: JSON.stringify(data),
    });
  }

  async put<T>(endpoint: string, data: any): Promise<T> {
    return this.request<T>(endpoint, {
      method: 'PUT',
      body: JSON.stringify(data),
    });
  }

  async delete<T>(endpoint: string): Promise<T> {
    return this.request<T>(endpoint, { method: 'DELETE' });
  }
}

export const apiClient = new ApiClient(process.env.NEXT_PUBLIC_API_URL!);
```

### 2. Data Validation Schemas

**Validation Schemas (src/lib/validations/user.ts)**
```typescript
import { z } from 'zod';

export const userSchema = z.object({
  id: z.string().cuid(),
  name: z.string().min(1, 'Name is required').max(100),
  email: z.string().email('Invalid email address'),
  role: z.enum(['USER', 'ADMIN', 'MODERATOR']),
  image: z.string().url().optional(),
  createdAt: z.string().datetime(),
  updatedAt: z.string().datetime(),
});

export const createUserSchema = userSchema.omit({
  id: true,
  createdAt: true,
  updatedAt: true,
});

export const updateUserSchema = createUserSchema.partial();

export type User = z.infer<typeof userSchema>;
export type CreateUser = z.infer<typeof createUserSchema>;
export type UpdateUser = z.infer<typeof updateUserSchema>;
```

### 3. React Query Hooks

**User Hooks (src/hooks/useUsers.ts)**
```typescript
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { apiClient } from '@/lib/api-client';
import { queryKeys } from '@/lib/query-client';
import { User, CreateUser, UpdateUser } from '@/lib/validations/user';

interface UsersResponse {
  users: User[];
  total: number;
  page: number;
  limit: number;
}

interface UsersParams {
  page?: number;
  limit?: number;
  search?: string;
}

export function useUsers(params: UsersParams = {}) {
  return useQuery({
    queryKey: queryKeys.users.list(JSON.stringify(params)),
    queryFn: () => apiClient.get<UsersResponse>(`/users?${new URLSearchParams(params)}`),
  });
}

export function useUser(id: string) {
  return useQuery({
    queryKey: queryKeys.users.detail(id),
    queryFn: () => apiClient.get<User>(`/users/${id}`),
    enabled: !!id,
  });
}

export function useCreateUser() {
  const queryClient = useQueryClient();
  
  return useMutation({
    mutationFn: (data: CreateUser) => apiClient.post<User>('/users', data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: queryKeys.users.all });
    },
  });
}

export function useUpdateUser() {
  const queryClient = useQueryClient();
  
  return useMutation({
    mutationFn: ({ id, ...data }: { id: string } & UpdateUser) =>
      apiClient.put<User>(`/users/${id}`, data),
    onSuccess: (updatedUser) => {
      queryClient.setQueryData(queryKeys.users.detail(updatedUser.id), updatedUser);
      queryClient.invalidateQueries({ queryKey: queryKeys.users.lists() });
    },
  });
}

export function useDeleteUser() {
  const queryClient = useQueryClient();
  
  return useMutation({
    mutationFn: (id: string) => apiClient.delete(`/users/${id}`),
    onSuccess: (_, deletedId) => {
      queryClient.removeQueries({ queryKey: queryKeys.users.detail(deletedId) });
      queryClient.invalidateQueries({ queryKey: queryKeys.users.lists() });
    },
  });
}
```

## Application Layout Implementation

### 1. Root Layout

**Root Layout (src/app/layout.tsx)**
```typescript
import './globals.css';
import { Inter } from 'next/font/google';
import { Providers } from '@/components/providers';

const inter = Inter({ subsets: ['latin'] });

export const metadata = {
  title: 'My App',
  description: 'A modern React/Next.js application',
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en" className={inter.className}>
      <body>
        <Providers>
          {children}
        </Providers>
      </body>
    </html>
  );
}
```

**Providers Component (src/components/providers.tsx)**
```typescript
'use client';

import { QueryClientProvider } from '@tanstack/react-query';
import { ReactQueryDevtools } from '@tanstack/react-query-devtools';
import { SessionProvider } from 'next-auth/react';
import { ThemeProvider } from 'next-themes';
import { queryClient } from '@/lib/query-client';

interface ProvidersProps {
  children: React.ReactNode;
}

export function Providers({ children }: ProvidersProps) {
  return (
    <SessionProvider>
      <QueryClientProvider client={queryClient}>
        <ThemeProvider attribute="class" defaultTheme="system" enableSystem>
          {children}
          <ReactQueryDevtools initialIsOpen={false} />
        </ThemeProvider>
      </QueryClientProvider>
    </SessionProvider>
  );
}
```

### 2. Dashboard Layout

**Dashboard Layout (src/app/dashboard/layout.tsx)**
```typescript
import { Sidebar } from '@/components/layout/sidebar';
import { Header } from '@/components/layout/header';

export default function DashboardLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <div className="flex h-screen">
      <Sidebar />
      <div className="flex-1 flex flex-col overflow-hidden">
        <Header />
        <main className="flex-1 overflow-auto p-6">
          {children}
        </main>
      </div>
    </div>
  );
}
```

**Sidebar Component (src/components/layout/sidebar.tsx)**
```typescript
'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { cn } from '@/lib/utils';
import { useSidebarOpen } from '@/store';
import { 
  Home, 
  Users, 
  Settings, 
  BarChart3,
  Menu,
  X 
} from 'lucide-react';
import { Button } from '@/components/ui/button';

const navigation = [
  { name: 'Dashboard', href: '/dashboard', icon: Home },
  { name: 'Users', href: '/dashboard/users', icon: Users },
  { name: 'Analytics', href: '/dashboard/analytics', icon: BarChart3 },
  { name: 'Settings', href: '/dashboard/settings', icon: Settings },
];

export function Sidebar() {
  const pathname = usePathname();
  const sidebarOpen = useSidebarOpen();
  const { toggleSidebar } = useAppStore();

  return (
    <>
      {/* Mobile overlay */}
      {sidebarOpen && (
        <div 
          className="fixed inset-0 bg-black bg-opacity-50 z-40 lg:hidden"
          onClick={toggleSidebar}
        />
      )}
      
      {/* Sidebar */}
      <aside className={cn(
        'fixed inset-y-0 left-0 z-50 w-64 bg-background border-r transform transition-transform duration-200 ease-in-out lg:translate-x-0 lg:static lg:inset-0',
        sidebarOpen ? 'translate-x-0' : '-translate-x-full'
      )}>
        <div className="flex items-center justify-between p-4 border-b">
          <h1 className="text-xl font-bold">My App</h1>
          <Button
            variant="ghost"
            size="icon"
            onClick={toggleSidebar}
            className="lg:hidden"
          >
            <X className="h-4 w-4" />
          </Button>
        </div>
        
        <nav className="p-4 space-y-2">
          {navigation.map((item) => {
            const isActive = pathname === item.href;
            return (
              <Link
                key={item.name}
                href={item.href}
                className={cn(
                  'flex items-center px-3 py-2 rounded-md text-sm font-medium transition-colors',
                  isActive
                    ? 'bg-accent text-accent-foreground'
                    : 'text-muted-foreground hover:bg-accent hover:text-accent-foreground'
                )}
              >
                <item.icon className="mr-3 h-4 w-4" />
                {item.name}
              </Link>
            );
          })}
        </nav>
      </aside>
    </>
  );
}
```

## Feature Implementation Examples

### 1. User Management Feature

**User List Page (src/app/dashboard/users/page.tsx)**
```typescript
'use client';

import { useState } from 'react';
import { useUsers, useDeleteUser } from '@/hooks/useUsers';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { UserCard } from '@/components/users/user-card';
import { CreateUserModal } from '@/components/users/create-user-modal';
import { LoadingSpinner } from '@/components/ui/loading-spinner';
import { ErrorMessage } from '@/components/ui/error-message';
import { Plus, Search } from 'lucide-react';

export default function UsersPage() {
  const [search, setSearch] = useState('');
  const [createModalOpen, setCreateModalOpen] = useState(false);
  
  const { data, isLoading, error } = useUsers({ search: search || undefined });
  const deleteUser = useDeleteUser();

  const handleDeleteUser = async (id: string) => {
    if (confirm('Are you sure you want to delete this user?')) {
      await deleteUser.mutateAsync(id);
    }
  };

  if (isLoading) return <LoadingSpinner />;
  if (error) return <ErrorMessage error={error} />;

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-3xl font-bold">Users</h1>
          <p className="text-muted-foreground">
            Manage your application users
          </p>
        </div>
        <Button onClick={() => setCreateModalOpen(true)}>
          <Plus className="mr-2 h-4 w-4" />
          Add User
        </Button>
      </div>

      <div className="flex items-center space-x-2">
        <div className="relative flex-1 max-w-sm">
          <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-muted-foreground" />
          <Input
            placeholder="Search users..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="pl-10"
          />
        </div>
      </div>

      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
        {data?.users.map((user) => (
          <UserCard
            key={user.id}
            user={user}
            onDelete={() => handleDeleteUser(user.id)}
          />
        ))}
      </div>

      <CreateUserModal
        open={createModalOpen}
        onOpenChange={setCreateModalOpen}
      />
    </div>
  );
}
```

**User Card Component (src/components/users/user-card.tsx)**
```typescript
import { User } from '@/lib/validations/user';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardFooter, CardHeader } from '@/components/ui/card';
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar';
import { Badge } from '@/components/ui/badge';
import { Edit, Trash2, Mail } from 'lucide-react';

interface UserCardProps {
  user: User;
  onEdit?: () => void;
  onDelete?: () => void;
}

export function UserCard({ user, onEdit, onDelete }: UserCardProps) {
  const roleColors = {
    USER: 'bg-blue-100 text-blue-800',
    ADMIN: 'bg-red-100 text-red-800',
    MODERATOR: 'bg-yellow-100 text-yellow-800',
  };

  return (
    <Card>
      <CardHeader className="pb-3">
        <div className="flex items-center space-x-3">
          <Avatar>
            <AvatarImage src={user.image} alt={user.name} />
            <AvatarFallback>
              {user.name.split(' ').map(n => n[0]).join('')}
            </AvatarFallback>
          </Avatar>
          <div className="flex-1 min-w-0">
            <h3 className="font-medium truncate">{user.name}</h3>
            <Badge 
              variant="secondary" 
              className={roleColors[user.role]}
            >
              {user.role}
            </Badge>
          </div>
        </div>
      </CardHeader>
      
      <CardContent>
        <div className="flex items-center text-sm text-muted-foreground">
          <Mail className="mr-2 h-4 w-4" />
          {user.email}
        </div>
      </CardContent>
      
      <CardFooter className="flex justify-end space-x-2">
        <Button variant="outline" size="sm" onClick={onEdit}>
          <Edit className="mr-2 h-3 w-3" />
          Edit
        </Button>
        <Button variant="destructive" size="sm" onClick={onDelete}>
          <Trash2 className="mr-2 h-3 w-3" />
          Delete
        </Button>
      </CardFooter>
    </Card>
  );
}
```

### 2. Form Implementation

**Create User Modal (src/components/users/create-user-modal.tsx)**
```typescript
'use client';

import { useState } from 'react';
import { FormProvider } from 'react-hook-form';
import { useForm } from '@/hooks/useForm';
import { useCreateUser } from '@/hooks/useUsers';
import { createUserSchema, CreateUser } from '@/lib/validations/user';
import { Dialog, DialogContent, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Button } from '@/components/ui/button';
import { FormField, FormInput } from '@/components/forms/form';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';

interface CreateUserModalProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
}

export function CreateUserModal({ open, onOpenChange }: CreateUserModalProps) {
  const [isSubmitting, setIsSubmitting] = useState(false);
  const createUser = useCreateUser();
  
  const form = useForm({
    schema: createUserSchema,
    defaultValues: {
      name: '',
      email: '',
      role: 'USER' as const,
    },
  });

  const onSubmit = async (data: CreateUser) => {
    setIsSubmitting(true);
    try {
      await createUser.mutateAsync(data);
      form.reset();
      onOpenChange(false);
    } catch (error) {
      console.error('Failed to create user:', error);
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Create New User</DialogTitle>
        </DialogHeader>
        
        <FormProvider {...form}>
          <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-4">
            <FormField name="name" label="Name" required>
              <FormInput name="name" placeholder="Enter user name" />
            </FormField>
            
            <FormField name="email" label="Email" required>
              <FormInput 
                name="email" 
                type="email" 
                placeholder="Enter email address" 
              />
            </FormField>
            
            <FormField name="role" label="Role" required>
              <Select 
                onValueChange={(value) => form.setValue('role', value as any)}
                defaultValue="USER"
              >
                <SelectTrigger>
                  <SelectValue placeholder="Select role" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="USER">User</SelectItem>
                  <SelectItem value="ADMIN">Admin</SelectItem>
                  <SelectItem value="MODERATOR">Moderator</SelectItem>
                </SelectContent>
              </Select>
            </FormField>
            
            <div className="flex justify-end space-x-2">
              <Button 
                type="button" 
                variant="outline" 
                onClick={() => onOpenChange(false)}
              >
                Cancel
              </Button>
              <Button type="submit" disabled={isSubmitting}>
                {isSubmitting ? 'Creating...' : 'Create User'}
              </Button>
            </div>
          </form>
        </FormProvider>
      </DialogContent>
    </Dialog>
  );
}
```

## Testing Setup

### 1. Testing Configuration

**Jest Configuration (jest.config.js)**
```javascript
const nextJest = require('next/jest');

const createJestConfig = nextJest({
  dir: './',
});

const customJestConfig = {
  setupFilesAfterEnv: ['<rootDir>/jest.setup.js'],
  moduleNameMapping: {
    '^@/(.*)$': '<rootDir>/src/$1',
  },
  testEnvironment: 'jest-environment-jsdom',
};

module.exports = createJestConfig(customJestConfig);
```

**Jest Setup (jest.setup.js)**
```javascript
import '@testing-library/jest-dom';
import { server } from './src/mocks/server';

beforeAll(() => server.listen());
afterEach(() => server.resetHandlers());
afterAll(() => server.close());
```

### 2. Example Tests

**Component Test (src/components/users/__tests__/user-card.test.tsx)**
```typescript
import { render, screen, fireEvent } from '@testing-library/react';
import { UserCard } from '../user-card';

const mockUser = {
  id: '1',
  name: 'John Doe',
  email: 'john@example.com',
  role: 'USER' as const,
  image: 'https://example.com/avatar.jpg',
  createdAt: '2023-01-01T00:00:00Z',
  updatedAt: '2023-01-01T00:00:00Z',
};

describe('UserCard', () => {
  it('renders user information correctly', () => {
    render(<UserCard user={mockUser} />);
    
    expect(screen.getByText('John Doe')).toBeInTheDocument();
    expect(screen.getByText('john@example.com')).toBeInTheDocument();
    expect(screen.getByText('USER')).toBeInTheDocument();
  });

  it('calls onEdit when edit button is clicked', () => {
    const onEdit = jest.fn();
    render(<UserCard user={mockUser} onEdit={onEdit} />);
    
    fireEvent.click(screen.getByText('Edit'));
    expect(onEdit).toHaveBeenCalledTimes(1);
  });

  it('calls onDelete when delete button is clicked', () => {
    const onDelete = jest.fn();
    render(<UserCard user={mockUser} onDelete={onDelete} />);
    
    fireEvent.click(screen.getByText('Delete'));
    expect(onDelete).toHaveBeenCalledTimes(1);
  });
});
```

## Deployment Setup

### 1. Build Configuration

**Package.json Scripts**
```json
{
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "lint": "next lint",
    "test": "jest",
    "test:watch": "jest --watch",
    "test:coverage": "jest --coverage",
    "db:push": "prisma db push",
    "db:migrate": "prisma migrate dev",
    "db:studio": "prisma studio",
    "analyze": "ANALYZE=true npm run build"
  }
}
```

### 2. Environment Configuration

**Production Environment (.env.production)**
```bash
# Database
DATABASE_URL="postgresql://user:pass@prod-db:5432/myapp"

# Auth
NEXTAUTH_URL="https://myapp.com"
NEXTAUTH_SECRET="production-secret-key"

# OAuth
GOOGLE_CLIENT_ID="prod-google-client-id"
GOOGLE_CLIENT_SECRET="prod-google-client-secret"

# Monitoring
NEXT_PUBLIC_SENTRY_DSN="your-sentry-dsn"
```

This implementation guide provides a solid foundation for building modern React/Next.js applications using the best practices identified from successful open source projects. Each section can be expanded based on specific project requirements.

---

**Navigation**
- ← Back to: [Performance Optimization](./performance-optimization.md)
- → Next: [Best Practices](./best-practices.md)
- → Related: [Project Analysis](./project-analysis.md)