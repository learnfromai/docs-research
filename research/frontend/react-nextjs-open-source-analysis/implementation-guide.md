# Implementation Guide: Production-Ready React & Next.js Applications

## 🎯 Overview

Step-by-step guide for implementing production-ready React and Next.js applications using patterns and best practices learned from successful open source projects.

## 🚀 Project Setup

### **Phase 1: Initial Setup (Day 1)**

```bash
# 1. Create Next.js project with TypeScript
npx create-next-app@latest my-app --typescript --tailwind --eslint --app --src-dir --import-alias "@/*"

cd my-app

# 2. Install essential dependencies
npm install @next-auth/prisma-adapter next-auth prisma @prisma/client
npm install @radix-ui/react-dialog @radix-ui/react-dropdown-menu @radix-ui/react-select
npm install class-variance-authority clsx tailwind-merge lucide-react
npm install @tanstack/react-query @tanstack/react-query-devtools
npm install zod react-hook-form @hookform/resolvers
npm install zustand immer

# 3. Install development dependencies
npm install -D @types/node @typescript-eslint/eslint-plugin @typescript-eslint/parser
npm install -D prettier prettier-plugin-tailwindcss eslint-config-prettier
npm install -D husky lint-staged @commitlint/cli @commitlint/config-conventional
npm install -D vitest @vitejs/plugin-react jsdom @testing-library/react @testing-library/jest-dom
npm install -D @playwright/test
npm install -D prisma-erd-generator

# 4. Initialize Git and set up hooks
git init
npx husky install
npm set-script prepare "husky install"
npx husky add .husky/pre-commit "npx lint-staged"
npx husky add .husky/commit-msg "npx --no -- commitlint --edit ${1}"
```

### **Configuration Files Setup**

```typescript
// tsconfig.json
{
  "compilerOptions": {
    "target": "ES2017",
    "lib": ["dom", "dom.iterable", "es6"],
    "allowJs": true,
    "skipLibCheck": true,
    "strict": true,
    "noEmit": true,
    "esModuleInterop": true,
    "module": "esnext",
    "moduleResolution": "node",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "jsx": "preserve",
    "incremental": true,
    "plugins": [{ "name": "next" }],
    "paths": {
      "@/*": ["./src/*"]
    },
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "noImplicitReturns": true,
    "noFallthroughCasesInSwitch": true
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx", ".next/types/**/*.ts"],
  "exclude": ["node_modules"]
}

// next.config.js
/** @type {import('next').NextConfig} */
const nextConfig = {
  experimental: {
    serverComponentsExternalPackages: ['@prisma/client'],
  },
  images: {
    domains: ['localhost'],
    formats: ['image/webp', 'image/avif'],
  },
  async headers() {
    return [
      {
        source: '/_next/static/:path*',
        headers: [
          {
            key: 'Cache-Control',
            value: 'public, max-age=31536000, immutable',
          },
        ],
      },
    ];
  },
};

module.exports = nextConfig;

// tailwind.config.js
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

## 🗄️ Database & Backend Setup

### **Phase 2: Database Schema (Day 2)**

```prisma
// prisma/schema.prisma
generator client {
  provider = "prisma-client-js"
}

generator erd {
  provider = "prisma-erd-generator"
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
  @@map("accounts")
}

model Session {
  id           String   @id @default(cuid())
  sessionToken String   @unique
  userId       String
  expires      DateTime
  user         User     @relation(fields: [userId], references: [id], onDelete: Cascade)

  @@map("sessions")
}

model User {
  id            String    @id @default(cuid())
  name          String?
  email         String    @unique
  emailVerified DateTime?
  image         String?
  role          UserRole  @default(USER)
  createdAt     DateTime  @default(now())
  updatedAt     DateTime  @updatedAt

  accounts Account[]
  sessions Session[]
  projects Project[]

  @@map("users")
}

model VerificationToken {
  identifier String
  token      String   @unique
  expires    DateTime

  @@unique([identifier, token])
  @@map("verificationtokens")
}

model Project {
  id          String          @id @default(cuid())
  name        String
  description String?
  status      ProjectStatus   @default(DRAFT)
  priority    ProjectPriority @default(MEDIUM)
  dueDate     DateTime?
  createdAt   DateTime        @default(now())
  updatedAt   DateTime        @updatedAt
  
  userId String
  user   User   @relation(fields: [userId], references: [id], onDelete: Cascade)

  @@map("projects")
}

enum UserRole {
  USER
  ADMIN
  MODERATOR
}

enum ProjectStatus {
  DRAFT
  ACTIVE
  COMPLETED
  ARCHIVED
}

enum ProjectPriority {
  LOW
  MEDIUM
  HIGH
}
```

```bash
# Database setup commands
npx prisma generate
npx prisma db push
npx prisma studio  # Optional: view data
```

## 🏗️ Core Architecture Implementation

### **Phase 3: Foundation Components (Day 3-4)**

```typescript
// lib/utils.ts
import { type ClassValue, clsx } from 'clsx';
import { twMerge } from 'tailwind-merge';

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

// lib/validations.ts
import { z } from 'zod';

export const createProjectSchema = z.object({
  name: z.string().min(1, 'Name is required').max(100, 'Name too long'),
  description: z.string().max(500, 'Description too long').optional(),
  priority: z.enum(['LOW', 'MEDIUM', 'HIGH']),
  dueDate: z.string().datetime().optional(),
});

export const updateProjectSchema = createProjectSchema.partial();

export type CreateProjectInput = z.infer<typeof createProjectSchema>;
export type UpdateProjectInput = z.infer<typeof updateProjectSchema>;

// lib/auth.ts
import { NextAuthOptions } from 'next-auth';
import { PrismaAdapter } from '@next-auth/prisma-adapter';
import GoogleProvider from 'next-auth/providers/google';
import { prisma } from '@/lib/prisma';

export const authOptions: NextAuthOptions = {
  adapter: PrismaAdapter(prisma),
  providers: [
    GoogleProvider({
      clientId: process.env.GOOGLE_CLIENT_ID!,
      clientSecret: process.env.GOOGLE_CLIENT_SECRET!,
    }),
  ],
  callbacks: {
    session: async ({ session, user }) => {
      if (session?.user) {
        session.user.id = user.id;
        session.user.role = user.role;
      }
      return session;
    },
  },
  pages: {
    signIn: '/auth/signin',
  },
};

// lib/prisma.ts
import { PrismaClient } from '@prisma/client';

const globalForPrisma = globalThis as unknown as {
  prisma: PrismaClient | undefined;
};

export const prisma = globalForPrisma.prisma ?? new PrismaClient();

if (process.env.NODE_ENV !== 'production') globalForPrisma.prisma = prisma;
```

### **UI Components Implementation**

```typescript
// components/ui/button.tsx
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

// components/ui/index.ts - Barrel exports
export { Button } from './button';
export { Input } from './input';
export { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from './card';
export { Badge } from './badge';
export { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle, DialogTrigger } from './dialog';
```

## 🔄 State Management Setup

### **Phase 4: State Management (Day 5)**

```typescript
// stores/auth-store.ts
import { create } from 'zustand';
import { devtools } from 'zustand/middleware';

interface User {
  id: string;
  email: string;
  name: string;
  role: string;
}

interface AuthState {
  user: User | null;
  isLoading: boolean;
  setUser: (user: User | null) => void;
  setLoading: (loading: boolean) => void;
  logout: () => void;
}

export const useAuthStore = create<AuthState>()(
  devtools(
    (set) => ({
      user: null,
      isLoading: false,
      setUser: (user) => set({ user }),
      setLoading: (isLoading) => set({ isLoading }),
      logout: () => set({ user: null }),
    }),
    { name: 'auth-store' }
  )
);

// stores/project-store.ts
import { create } from 'zustand';
import { devtools, persist } from 'zustand/middleware';
import { immer } from 'zustand/middleware/immer';

interface Project {
  id: string;
  name: string;
  description?: string;
  status: 'DRAFT' | 'ACTIVE' | 'COMPLETED' | 'ARCHIVED';
  priority: 'LOW' | 'MEDIUM' | 'HIGH';
  createdAt: string;
}

interface ProjectState {
  projects: Project[];
  filters: {
    status: string;
    priority: string;
    search: string;
  };
  setProjects: (projects: Project[]) => void;
  addProject: (project: Project) => void;
  updateProject: (id: string, updates: Partial<Project>) => void;
  removeProject: (id: string) => void;
  setFilters: (filters: Partial<ProjectState['filters']>) => void;
  getFilteredProjects: () => Project[];
}

export const useProjectStore = create<ProjectState>()(
  devtools(
    persist(
      immer((set, get) => ({
        projects: [],
        filters: {
          status: 'all',
          priority: 'all',
          search: '',
        },
        
        setProjects: (projects) =>
          set((state) => {
            state.projects = projects;
          }),
          
        addProject: (project) =>
          set((state) => {
            state.projects.unshift(project);
          }),
          
        updateProject: (id, updates) =>
          set((state) => {
            const index = state.projects.findIndex((p) => p.id === id);
            if (index !== -1) {
              Object.assign(state.projects[index], updates);
            }
          }),
          
        removeProject: (id) =>
          set((state) => {
            state.projects = state.projects.filter((p) => p.id !== id);
          }),
          
        setFilters: (newFilters) =>
          set((state) => {
            Object.assign(state.filters, newFilters);
          }),
          
        getFilteredProjects: () => {
          const { projects, filters } = get();
          return projects.filter((project) => {
            if (filters.status !== 'all' && project.status !== filters.status) {
              return false;
            }
            if (filters.priority !== 'all' && project.priority !== filters.priority) {
              return false;
            }
            if (filters.search) {
              const search = filters.search.toLowerCase();
              return (
                project.name.toLowerCase().includes(search) ||
                project.description?.toLowerCase().includes(search)
              );
            }
            return true;
          });
        },
      })),
      { name: 'project-store' }
    ),
    { name: 'project-store' }
  )
);

// hooks/use-projects.ts
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { toast } from 'sonner';

const projectKeys = {
  all: ['projects'] as const,
  lists: () => [...projectKeys.all, 'list'] as const,
  list: (filters: Record<string, any>) => [...projectKeys.lists(), filters] as const,
  details: () => [...projectKeys.all, 'detail'] as const,
  detail: (id: string) => [...projectKeys.details(), id] as const,
};

export function useProjects(filters?: Record<string, any>) {
  return useQuery({
    queryKey: projectKeys.list(filters || {}),
    queryFn: async () => {
      const params = new URLSearchParams(filters);
      const response = await fetch(`/api/projects?${params}`);
      if (!response.ok) throw new Error('Failed to fetch projects');
      return response.json();
    },
  });
}

export function useCreateProject() {
  const queryClient = useQueryClient();
  
  return useMutation({
    mutationFn: async (data: CreateProjectInput) => {
      const response = await fetch('/api/projects', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data),
      });
      if (!response.ok) throw new Error('Failed to create project');
      return response.json();
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: projectKeys.lists() });
      toast.success('Project created successfully!');
    },
    onError: (error) => {
      toast.error(error.message || 'Failed to create project');
    },
  });
}
```

## 🎨 Frontend Implementation

### **Phase 5: Pages and Components (Day 6-8)**

```typescript
// app/layout.tsx
import { Inter } from 'next/font/google';
import { Providers } from '@/components/providers';
import './globals.css';

const inter = Inter({ subsets: ['latin'] });

export const metadata = {
  title: 'My App',
  description: 'Production-ready Next.js application',
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body className={inter.className}>
        <Providers>{children}</Providers>
      </body>
    </html>
  );
}

// components/providers.tsx
'use client';

import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { ReactQueryDevtools } from '@tanstack/react-query-devtools';
import { SessionProvider } from 'next-auth/react';
import { ThemeProvider } from 'next-themes';
import { Toaster } from 'sonner';
import { useState } from 'react';

export function Providers({ children }: { children: React.ReactNode }) {
  const [queryClient] = useState(
    () =>
      new QueryClient({
        defaultOptions: {
          queries: {
            staleTime: 60 * 1000, // 1 minute
            refetchOnWindowFocus: false,
          },
        },
      })
  );

  return (
    <SessionProvider>
      <QueryClientProvider client={queryClient}>
        <ThemeProvider
          attribute="class"
          defaultTheme="system"
          enableSystem
          disableTransitionOnChange
        >
          {children}
          <Toaster />
          <ReactQueryDevtools initialIsOpen={false} />
        </ThemeProvider>
      </QueryClientProvider>
    </SessionProvider>
  );
}

// app/dashboard/page.tsx
import { Suspense } from 'react';
import { ProjectList } from '@/components/projects/project-list';
import { CreateProjectButton } from '@/components/projects/create-project-button';
import { ProjectFilters } from '@/components/projects/project-filters';

export default function DashboardPage() {
  return (
    <div className="container mx-auto py-6">
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-3xl font-bold">Dashboard</h1>
        <CreateProjectButton />
      </div>
      
      <div className="space-y-6">
        <ProjectFilters />
        <Suspense fallback={<ProjectListSkeleton />}>
          <ProjectList />
        </Suspense>
      </div>
    </div>
  );
}

// components/projects/project-list.tsx
'use client';

import { useProjects } from '@/hooks/use-projects';
import { useProjectStore } from '@/stores/project-store';
import { ProjectCard } from './project-card';
import { ProjectListSkeleton } from './project-list-skeleton';

export function ProjectList() {
  const filters = useProjectStore((state) => state.filters);
  const { data: projects, isLoading, error } = useProjects(filters);

  if (isLoading) return <ProjectListSkeleton />;
  if (error) return <div>Error loading projects</div>;
  if (!projects?.length) return <EmptyState />;

  return (
    <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
      {projects.map((project) => (
        <ProjectCard key={project.id} project={project} />
      ))}
    </div>
  );
}

function EmptyState() {
  return (
    <div className="text-center py-12">
      <h3 className="text-lg font-semibold">No projects found</h3>
      <p className="text-muted-foreground">
        Get started by creating your first project.
      </p>
    </div>
  );
}
```

## 🔌 API Implementation

### **Phase 6: API Routes (Day 9)**

```typescript
// app/api/projects/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { getServerSession } from 'next-auth/next';
import { authOptions } from '@/lib/auth';
import { prisma } from '@/lib/prisma';
import { createProjectSchema } from '@/lib/validations';

export async function GET(request: NextRequest) {
  try {
    const session = await getServerSession(authOptions);
    if (!session?.user) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const { searchParams } = new URL(request.url);
    const status = searchParams.get('status');
    const priority = searchParams.get('priority');

    const where = {
      userId: session.user.id,
      ...(status && status !== 'all' && { status }),
      ...(priority && priority !== 'all' && { priority }),
    };

    const projects = await prisma.project.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      include: {
        user: {
          select: { id: true, name: true, email: true },
        },
      },
    });

    return NextResponse.json(projects);
  } catch (error) {
    console.error('Error fetching projects:', error);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}

export async function POST(request: NextRequest) {
  try {
    const session = await getServerSession(authOptions);
    if (!session?.user) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const body = await request.json();
    const validatedData = createProjectSchema.parse(body);

    const project = await prisma.project.create({
      data: {
        ...validatedData,
        userId: session.user.id,
      },
      include: {
        user: {
          select: { id: true, name: true, email: true },
        },
      },
    });

    return NextResponse.json(project, { status: 201 });
  } catch (error) {
    if (error instanceof z.ZodError) {
      return NextResponse.json(
        { error: 'Validation failed', details: error.errors },
        { status: 400 }
      );
    }
    
    console.error('Error creating project:', error);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}

// app/api/projects/[id]/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { getServerSession } from 'next-auth/next';
import { authOptions } from '@/lib/auth';
import { prisma } from '@/lib/prisma';
import { updateProjectSchema } from '@/lib/validations';

export async function PUT(
  request: NextRequest,
  { params }: { params: { id: string } }
) {
  try {
    const session = await getServerSession(authOptions);
    if (!session?.user) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const body = await request.json();
    const validatedData = updateProjectSchema.parse(body);

    // Verify ownership
    const existingProject = await prisma.project.findUnique({
      where: { id: params.id },
    });

    if (!existingProject || existingProject.userId !== session.user.id) {
      return NextResponse.json({ error: 'Project not found' }, { status: 404 });
    }

    const project = await prisma.project.update({
      where: { id: params.id },
      data: validatedData,
      include: {
        user: {
          select: { id: true, name: true, email: true },
        },
      },
    });

    return NextResponse.json(project);
  } catch (error) {
    console.error('Error updating project:', error);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}

export async function DELETE(
  request: NextRequest,
  { params }: { params: { id: string } }
) {
  try {
    const session = await getServerSession(authOptions);
    if (!session?.user) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    // Verify ownership
    const existingProject = await prisma.project.findUnique({
      where: { id: params.id },
    });

    if (!existingProject || existingProject.userId !== session.user.id) {
      return NextResponse.json({ error: 'Project not found' }, { status: 404 });
    }

    await prisma.project.delete({
      where: { id: params.id },
    });

    return NextResponse.json({ success: true });
  } catch (error) {
    console.error('Error deleting project:', error);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
```

## 🧪 Testing Implementation

### **Phase 7: Testing Setup (Day 10)**

```typescript
// vitest.config.ts
import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';
import path from 'path';

export default defineConfig({
  plugins: [react()],
  test: {
    environment: 'jsdom',
    setupFiles: ['./src/test/setup.ts'],
    globals: true,
  },
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
});

// src/test/setup.ts
import '@testing-library/jest-dom';
import { vi } from 'vitest';

// Mock Next.js router
vi.mock('next/router', () => ({
  useRouter: () => ({
    push: vi.fn(),
    replace: vi.fn(),
    back: vi.fn(),
    query: {},
    pathname: '/',
  }),
}));

// Mock next-auth
vi.mock('next-auth/react', () => ({
  useSession: () => ({
    data: {
      user: { id: '1', email: 'test@example.com', name: 'Test User' },
    },
    status: 'authenticated',
  }),
}));

// __tests__/projects.test.tsx
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { ProjectList } from '@/components/projects/project-list';

const createWrapper = () => {
  const queryClient = new QueryClient({
    defaultOptions: { queries: { retry: false } },
  });
  return ({ children }: { children: React.ReactNode }) => (
    <QueryClientProvider client={queryClient}>
      {children}
    </QueryClientProvider>
  );
};

describe('ProjectList', () => {
  it('renders projects correctly', async () => {
    render(<ProjectList />, { wrapper: createWrapper() });
    
    await waitFor(() => {
      expect(screen.getByText('My Project')).toBeInTheDocument();
    });
  });
});
```

## 🚀 Deployment Setup

### **Phase 8: Production Deployment (Day 11)**

```yaml
# .github/workflows/ci.yml
name: CI/CD Pipeline

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    
    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_PASSWORD: postgres
          POSTGRES_DB: test
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 5432:5432

    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '18'
          cache: 'npm'
          
      - name: Install dependencies
        run: npm ci
        
      - name: Run linting
        run: npm run lint
        
      - name: Run type checking
        run: npm run type-check
        
      - name: Run tests
        run: npm run test
        env:
          DATABASE_URL: postgresql://postgres:postgres@localhost:5432/test
          
      - name: Run E2E tests
        run: npm run test:e2e
        
      - name: Build application
        run: npm run build

  deploy:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    
    steps:
      - uses: actions/checkout@v4
      - name: Deploy to Vercel
        uses: amondnet/vercel-action@v25
        with:
          vercel-token: ${{ secrets.VERCEL_TOKEN }}
          vercel-args: '--prod'
          vercel-org-id: ${{ secrets.ORG_ID }}
          vercel-project-id: ${{ secrets.PROJECT_ID }}
```

## 📊 Performance Monitoring

### **Phase 9: Monitoring & Analytics (Day 12)**

```typescript
// lib/analytics.ts
import { NextWebVitalsMetric } from 'next/app';

export function reportWebVitals(metric: NextWebVitalsMetric) {
  if (process.env.NODE_ENV === 'production') {
    // Send to your analytics service
    fetch('/api/analytics', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(metric),
    });
  }
}

// app/layout.tsx - Add web vitals reporting
export function reportWebVitals(metric: NextWebVitalsMetric) {
  reportWebVitals(metric);
}
```

## 🎯 Implementation Timeline

### **Week 1: Foundation**
- **Day 1**: Project setup, dependencies, configuration
- **Day 2**: Database schema, Prisma setup
- **Day 3-4**: Core components, UI library
- **Day 5**: State management setup
- **Day 6-8**: Pages and features implementation
- **Day 9**: API routes and backend logic
- **Day 10**: Testing implementation
- **Day 11**: Deployment setup
- **Day 12**: Monitoring and optimization

### **Week 2: Polish & Features**
- Error handling improvements
- Performance optimization
- Additional features
- Documentation
- Security audit

### **Week 3: Production Readiness**
- Load testing
- Security testing
- Performance monitoring
- Bug fixes
- Final deployment

## 🎯 Success Metrics

### **Technical Metrics**
- [ ] Lighthouse score >90
- [ ] Test coverage >80%
- [ ] Bundle size <1MB initial load
- [ ] API response time <200ms
- [ ] Error rate <1%

### **Development Metrics**
- [ ] TypeScript strict mode enabled
- [ ] ESLint/Prettier configured
- [ ] Git hooks implemented
- [ ] CI/CD pipeline working
- [ ] Documentation complete

---

## Navigation

- ← Previous: [Best Practices Guide](./best-practices.md)
- → Next: [Project Architecture Analysis](./project-architecture-analysis.md)

| [📋 Overview](./README.md) | [⚡ Best Practices](./best-practices.md) | [🚀 Implementation](#) | [🏗️ Architecture](./project-architecture-analysis.md) |
|---|---|---|---|