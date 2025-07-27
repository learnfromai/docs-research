# Implementation Guide: Modern React/Next.js Application

## 🎯 Overview

This implementation guide provides step-by-step instructions for building a production-ready React/Next.js application using patterns and best practices identified from analyzing successful open source projects. The guide follows a progressive enhancement approach, starting with a solid foundation and adding complexity as needed.

## 🚀 Phase 1: Project Foundation

### Step 1: Next.js Project Setup

```bash
# Create Next.js project with TypeScript
npx create-next-app@latest my-app --typescript --tailwind --eslint --app --src-dir --import-alias "@/*"

cd my-app

# Install essential dependencies
npm install @tanstack/react-query @tanstack/react-query-devtools
npm install zustand
npm install next-auth
npm install @next-auth/prisma-adapter prisma @prisma/client
npm install lucide-react class-variance-authority clsx tailwind-merge

# Install development dependencies
npm install -D @types/node @types/react @types/react-dom
npm install -D jest @testing-library/react @testing-library/jest-dom
npm install -D eslint-config-prettier prettier
npm install -D husky lint-staged
```

### Step 2: TypeScript Configuration

Create or update `tsconfig.json`:

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
    "plugins": [{ "name": "next" }],
    "baseUrl": ".",
    "paths": {
      "@/*": ["./src/*"],
      "@/components/*": ["./src/components/*"],
      "@/lib/*": ["./src/lib/*"],
      "@/hooks/*": ["./src/hooks/*"],
      "@/types/*": ["./src/types/*"]
    }
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx", ".next/types/**/*.ts"],
  "exclude": ["node_modules"]
}
```

### Step 3: Project Structure Setup

```bash
# Create folder structure
mkdir -p src/{components,features,hooks,lib,stores,types}
mkdir -p src/components/{ui,layout}
mkdir -p src/features/{auth,dashboard,profile}
mkdir -p src/lib/{auth,db,utils}

# Create core files
touch src/lib/utils.ts
touch src/types/index.ts
touch src/stores/index.ts
```

## 🏗️ Phase 2: Core Architecture

### Step 4: Utility Functions

Create `src/lib/utils.ts`:

```typescript
import { type ClassValue, clsx } from "clsx";
import { twMerge } from "tailwind-merge";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

export function formatDate(date: Date | string): string {
  return new Intl.DateTimeFormat("en-US", {
    year: "numeric",
    month: "long",
    day: "numeric",
  }).format(new Date(date));
}

export function slugify(text: string): string {
  return text
    .toLowerCase()
    .replace(/[^\w ]+/g, "")
    .replace(/ +/g, "-");
}

// API response type
export interface ApiResponse<T = any> {
  data?: T;
  error?: string;
  success: boolean;
}

// Async error handler
export async function handleAsync<T>(
  promise: Promise<T>
): Promise<[T | null, Error | null]> {
  try {
    const data = await promise;
    return [data, null];
  } catch (error) {
    return [null, error as Error];
  }
}
```

### Step 5: Type Definitions

Create `src/types/index.ts`:

```typescript
// User types
export interface User {
  id: string;
  email: string;
  name: string;
  avatar?: string;
  role: "user" | "admin" | "moderator";
  createdAt: Date;
  updatedAt: Date;
}

// API types
export interface PaginatedResponse<T> {
  data: T[];
  pagination: {
    page: number;
    limit: number;
    total: number;
    totalPages: number;
  };
}

// Component types
export interface BaseComponentProps {
  className?: string;
  children?: React.ReactNode;
}

// Form types
export interface FormState<T = any> {
  data: T;
  errors: Record<string, string>;
  isLoading: boolean;
  isValid: boolean;
}

// Theme types
export type Theme = "light" | "dark" | "system";

// Navigation types
export interface NavItem {
  title: string;
  href: string;
  icon?: React.ComponentType;
  children?: NavItem[];
}
```

## 🧠 Phase 3: State Management

### Step 6: Zustand Store Setup

Create `src/stores/index.ts`:

```typescript
import { create } from "zustand";
import { persist, createJSONStorage } from "zustand/middleware";
import { User, Theme } from "@/types";

// App State Interface
interface AppState {
  // User state
  user: User | null;
  setUser: (user: User | null) => void;
  
  // Theme state
  theme: Theme;
  setTheme: (theme: Theme) => void;
  
  // UI state
  sidebarOpen: boolean;
  setSidebarOpen: (open: boolean) => void;
  
  // Loading states
  isLoading: boolean;
  setIsLoading: (loading: boolean) => void;
  
  // Notifications
  notifications: Notification[];
  addNotification: (notification: Notification) => void;
  removeNotification: (id: string) => void;
}

interface Notification {
  id: string;
  type: "success" | "error" | "warning" | "info";
  title: string;
  message?: string;
  duration?: number;
}

// Create store with persistence
export const useAppStore = create<AppState>()(
  persist(
    (set, get) => ({
      // User state
      user: null,
      setUser: (user) => set({ user }),
      
      // Theme state
      theme: "system",
      setTheme: (theme) => set({ theme }),
      
      // UI state
      sidebarOpen: false,
      setSidebarOpen: (sidebarOpen) => set({ sidebarOpen }),
      
      // Loading states
      isLoading: false,
      setIsLoading: (isLoading) => set({ isLoading }),
      
      // Notifications
      notifications: [],
      addNotification: (notification) => set((state) => ({
        notifications: [...state.notifications, notification],
      })),
      removeNotification: (id) => set((state) => ({
        notifications: state.notifications.filter((n) => n.id !== id),
      })),
    }),
    {
      name: "app-storage",
      storage: createJSONStorage(() => localStorage),
      partialize: (state) => ({
        theme: state.theme,
        sidebarOpen: state.sidebarOpen,
      }),
    }
  )
);

// Selectors for performance optimization
export const useUser = () => useAppStore((state) => state.user);
export const useTheme = () => useAppStore((state) => state.theme);
export const useNotifications = () => useAppStore((state) => state.notifications);
```

### Step 7: React Query Setup

Create `src/lib/react-query.ts`:

```typescript
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { ReactQueryDevtools } from "@tanstack/react-query-devtools";

export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 60 * 1000, // 1 minute
      retry: (failureCount, error: any) => {
        if (error?.status === 404) return false;
        return failureCount < 3;
      },
    },
    mutations: {
      retry: false,
    },
  },
});

// Query Provider Component
export function QueryProvider({ children }: { children: React.ReactNode }) {
  return (
    <QueryClientProvider client={queryClient}>
      {children}
      <ReactQueryDevtools initialIsOpen={false} />
    </QueryClientProvider>
  );
}
```

## 🔐 Phase 4: Authentication

### Step 8: NextAuth.js Configuration

Create `src/lib/auth.ts`:

```typescript
import { NextAuthOptions } from "next-auth";
import { PrismaAdapter } from "@next-auth/prisma-adapter";
import GoogleProvider from "next-auth/providers/google";
import GitHubProvider from "next-auth/providers/github";
import CredentialsProvider from "next-auth/providers/credentials";
import { prisma } from "@/lib/db";
import bcrypt from "bcryptjs";

export const authOptions: NextAuthOptions = {
  adapter: PrismaAdapter(prisma),
  providers: [
    GoogleProvider({
      clientId: process.env.GOOGLE_CLIENT_ID!,
      clientSecret: process.env.GOOGLE_CLIENT_SECRET!,
    }),
    GitHubProvider({
      clientId: process.env.GITHUB_CLIENT_ID!,
      clientSecret: process.env.GITHUB_CLIENT_SECRET!,
    }),
    CredentialsProvider({
      name: "credentials",
      credentials: {
        email: { label: "Email", type: "email" },
        password: { label: "Password", type: "password" },
      },
      async authorize(credentials) {
        if (!credentials?.email || !credentials?.password) {
          return null;
        }

        const user = await prisma.user.findUnique({
          where: { email: credentials.email },
        });

        if (!user || !user.password) {
          return null;
        }

        const isPasswordValid = await bcrypt.compare(
          credentials.password,
          user.password
        );

        if (!isPasswordValid) {
          return null;
        }

        return {
          id: user.id,
          email: user.email,
          name: user.name,
          role: user.role,
        };
      },
    }),
  ],
  session: {
    strategy: "jwt",
  },
  pages: {
    signIn: "/auth/signin",
    signUp: "/auth/signup",
  },
  callbacks: {
    async jwt({ token, user }) {
      if (user) {
        token.role = user.role;
      }
      return token;
    },
    async session({ session, token }) {
      if (token) {
        session.user.id = token.sub!;
        session.user.role = token.role as string;
      }
      return session;
    },
  },
};
```

### Step 9: Authentication Hooks

Create `src/hooks/use-auth.ts`:

```typescript
import { useSession, signIn, signOut } from "next-auth/react";
import { useRouter } from "next/navigation";
import { useAppStore } from "@/stores";

export function useAuth() {
  const { data: session, status } = useSession();
  const router = useRouter();
  const { setUser } = useAppStore();

  const isLoading = status === "loading";
  const isAuthenticated = !!session?.user;
  const user = session?.user;

  const login = async (email: string, password: string) => {
    const result = await signIn("credentials", {
      email,
      password,
      redirect: false,
    });

    if (result?.error) {
      throw new Error(result.error);
    }

    if (result?.ok) {
      router.push("/dashboard");
    }
  };

  const logout = async () => {
    setUser(null);
    await signOut({ redirect: false });
    router.push("/");
  };

  const loginWithProvider = async (provider: "google" | "github") => {
    await signIn(provider, { callbackUrl: "/dashboard" });
  };

  return {
    user,
    isLoading,
    isAuthenticated,
    login,
    logout,
    loginWithProvider,
  };
}
```

## 🎨 Phase 5: UI Components

### Step 10: Base UI Components

Create `src/components/ui/button.tsx`:

```typescript
import * as React from "react";
import { Slot } from "@radix-ui/react-slot";
import { cva, type VariantProps } from "class-variance-authority";
import { cn } from "@/lib/utils";

const buttonVariants = cva(
  "inline-flex items-center justify-center whitespace-nowrap rounded-md text-sm font-medium ring-offset-background transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:pointer-events-none disabled:opacity-50",
  {
    variants: {
      variant: {
        default: "bg-primary text-primary-foreground hover:bg-primary/90",
        destructive: "bg-destructive text-destructive-foreground hover:bg-destructive/90",
        outline: "border border-input bg-background hover:bg-accent hover:text-accent-foreground",
        secondary: "bg-secondary text-secondary-foreground hover:bg-secondary/80",
        ghost: "hover:bg-accent hover:text-accent-foreground",
        link: "text-primary underline-offset-4 hover:underline",
      },
      size: {
        default: "h-10 px-4 py-2",
        sm: "h-9 rounded-md px-3",
        lg: "h-11 rounded-md px-8",
        icon: "h-10 w-10",
      },
    },
    defaultVariants: {
      variant: "default",
      size: "default",
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
    const Comp = asChild ? Slot : "button";
    return (
      <Comp
        className={cn(buttonVariants({ variant, size, className }))}
        ref={ref}
        {...props}
      />
    );
  }
);
Button.displayName = "Button";

export { Button, buttonVariants };
```

## 🌐 Phase 6: API Integration

### Step 11: API Client Setup

Create `src/lib/api.ts`:

```typescript
import { ApiResponse } from "@/lib/utils";

class ApiClient {
  private baseURL: string;

  constructor(baseURL: string = "/api") {
    this.baseURL = baseURL;
  }

  private async request<T>(
    endpoint: string,
    options: RequestInit = {}
  ): Promise<ApiResponse<T>> {
    const url = `${this.baseURL}${endpoint}`;

    const config: RequestInit = {
      headers: {
        "Content-Type": "application/json",
        ...options.headers,
      },
      ...options,
    };

    try {
      const response = await fetch(url, config);
      
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }

      const data = await response.json();
      return { data, success: true };
    } catch (error) {
      return {
        error: error instanceof Error ? error.message : "Unknown error",
        success: false,
      };
    }
  }

  async get<T>(endpoint: string): Promise<ApiResponse<T>> {
    return this.request<T>(endpoint, { method: "GET" });
  }

  async post<T>(endpoint: string, data: any): Promise<ApiResponse<T>> {
    return this.request<T>(endpoint, {
      method: "POST",
      body: JSON.stringify(data),
    });
  }

  async put<T>(endpoint: string, data: any): Promise<ApiResponse<T>> {
    return this.request<T>(endpoint, {
      method: "PUT",
      body: JSON.stringify(data),
    });
  }

  async delete<T>(endpoint: string): Promise<ApiResponse<T>> {
    return this.request<T>(endpoint, { method: "DELETE" });
  }
}

export const apiClient = new ApiClient();
```

### Step 12: React Query Hooks

Create `src/hooks/use-api.ts`:

```typescript
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { apiClient } from "@/lib/api";
import { User, PaginatedResponse } from "@/types";

// User queries
export function useUsers(page = 1, limit = 10) {
  return useQuery({
    queryKey: ["users", { page, limit }],
    queryFn: () => apiClient.get<PaginatedResponse<User>>(`/users?page=${page}&limit=${limit}`),
  });
}

export function useUser(id: string) {
  return useQuery({
    queryKey: ["user", id],
    queryFn: () => apiClient.get<User>(`/users/${id}`),
    enabled: !!id,
  });
}

// User mutations
export function useCreateUser() {
  const queryClient = useQueryClient();
  
  return useMutation({
    mutationFn: (userData: Partial<User>) => apiClient.post<User>("/users", userData),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["users"] });
    },
  });
}

export function useUpdateUser() {
  const queryClient = useQueryClient();
  
  return useMutation({
    mutationFn: ({ id, data }: { id: string; data: Partial<User> }) =>
      apiClient.put<User>(`/users/${id}`, data),
    onSuccess: (_, { id }) => {
      queryClient.invalidateQueries({ queryKey: ["user", id] });
      queryClient.invalidateQueries({ queryKey: ["users"] });
    },
  });
}

export function useDeleteUser() {
  const queryClient = useQueryClient();
  
  return useMutation({
    mutationFn: (id: string) => apiClient.delete(`/users/${id}`),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["users"] });
    },
  });
}
```

## 🧪 Phase 7: Testing Setup

### Step 13: Testing Configuration

Create `jest.config.js`:

```javascript
const nextJest = require("next/jest");

const createJestConfig = nextJest({
  dir: "./",
});

const customJestConfig = {
  setupFilesAfterEnv: ["<rootDir>/jest.setup.js"],
  testEnvironment: "jest-environment-jsdom",
  moduleNameMapping: {
    "^@/(.*)$": "<rootDir>/src/$1",
  },
  testPathIgnorePatterns: ["<rootDir>/.next/", "<rootDir>/node_modules/"],
  collectCoverageFrom: [
    "src/**/*.{js,jsx,ts,tsx}",
    "!src/**/*.d.ts",
    "!src/**/*.stories.{js,jsx,ts,tsx}",
  ],
};

module.exports = createJestConfig(customJestConfig);
```

Create `jest.setup.js`:

```javascript
import "@testing-library/jest-dom";

// Mock next/navigation
jest.mock("next/navigation", () => ({
  useRouter() {
    return {
      push: jest.fn(),
      replace: jest.fn(),
      back: jest.fn(),
      forward: jest.fn(),
      refresh: jest.fn(),
      prefetch: jest.fn(),
    };
  },
  useSearchParams() {
    return new URLSearchParams();
  },
  usePathname() {
    return "";
  },
}));

// Mock next-auth
jest.mock("next-auth/react", () => ({
  useSession() {
    return { data: null, status: "unauthenticated" };
  },
  signIn: jest.fn(),
  signOut: jest.fn(),
}));
```

## 🚀 Phase 8: Deployment

### Step 14: Environment Configuration

Create `.env.example`:

```bash
# Database
DATABASE_URL="postgresql://user:password@localhost:5432/myapp"

# NextAuth.js
NEXTAUTH_URL="http://localhost:3000"
NEXTAUTH_SECRET="your-secret-key"

# OAuth Providers
GOOGLE_CLIENT_ID="your-google-client-id"
GOOGLE_CLIENT_SECRET="your-google-client-secret"
GITHUB_CLIENT_ID="your-github-client-id"
GITHUB_CLIENT_SECRET="your-github-client-secret"

# API Keys
OPENAI_API_KEY="your-openai-api-key"
STRIPE_SECRET_KEY="your-stripe-secret-key"
```

### Step 15: Deployment Scripts

Update `package.json`:

```json
{
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "lint": "next lint",
    "type-check": "tsc --noEmit",
    "test": "jest",
    "test:watch": "jest --watch",
    "test:coverage": "jest --coverage",
    "db:push": "prisma db push",
    "db:migrate": "prisma migrate dev",
    "db:generate": "prisma generate",
    "prepare": "husky install"
  }
}
```

## ✅ Verification Checklist

- [ ] Project structure follows feature-based organization
- [ ] TypeScript configured with strict mode
- [ ] Zustand store implemented for client state
- [ ] React Query configured for server state
- [ ] NextAuth.js authentication setup
- [ ] UI components with proper TypeScript types
- [ ] API client with error handling
- [ ] Testing environment configured
- [ ] Environment variables documented
- [ ] Deployment scripts ready

## 📚 Next Steps

1. **Feature Development**: Implement specific features using the established patterns
2. **Performance Optimization**: Add bundle analysis and performance monitoring
3. **Security Hardening**: Implement CSRF protection and security headers
4. **Monitoring**: Add error tracking and analytics
5. **Documentation**: Create component documentation and API docs

For detailed implementations of specific patterns, see:
- [State Management Patterns](./state-management-patterns.md)
- [Authentication Patterns](./authentication-patterns.md)
- [Performance Optimization](./performance-optimization.md)