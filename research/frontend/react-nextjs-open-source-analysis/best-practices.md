# Best Practices Guide: React & Next.js Production Applications

## 🎯 Overview

Comprehensive best practices compilation derived from analysis of production React and Next.js open source applications, covering architecture, code quality, security, and development workflows.

## 🏗️ Project Architecture

### **Folder Structure Best Practices**

```
my-nextjs-app/
├── app/                          # Next.js 13+ App Router
│   ├── (auth)/                   # Route groups
│   │   ├── signin/
│   │   └── signup/
│   ├── dashboard/
│   │   ├── loading.tsx           # Loading UI
│   │   ├── error.tsx             # Error UI
│   │   ├── page.tsx              # Page component
│   │   └── layout.tsx            # Layout component
│   ├── api/                      # API routes
│   │   ├── auth/
│   │   └── projects/
│   ├── globals.css               # Global styles
│   ├── layout.tsx                # Root layout
│   └── page.tsx                  # Home page
├── components/                   # Reusable components
│   ├── ui/                       # Base UI components
│   │   ├── button.tsx
│   │   ├── input.tsx
│   │   ├── modal.tsx
│   │   └── index.ts              # Barrel exports
│   ├── forms/                    # Form components
│   ├── layouts/                  # Layout components
│   └── features/                 # Feature-specific components
├── hooks/                        # Custom hooks
│   ├── use-projects.ts
│   ├── use-auth.ts
│   └── use-local-storage.ts
├── lib/                          # Utilities and configurations
│   ├── auth.ts                   # Auth configuration
│   ├── database.ts               # Database setup
│   ├── utils.ts                  # Utility functions
│   ├── validations.ts            # Zod schemas
│   └── constants.ts              # App constants
├── stores/                       # State management
│   ├── auth-store.ts
│   ├── project-store.ts
│   └── ui-store.ts
├── types/                        # TypeScript definitions
│   ├── auth.ts
│   ├── project.ts
│   └── global.d.ts
├── middleware.ts                 # Next.js middleware
├── next.config.js                # Next.js configuration
├── tailwind.config.js            # Tailwind configuration
├── tsconfig.json                 # TypeScript configuration
└── package.json
```

### **Component Organization Patterns**

```typescript
// ✅ Good: Feature-based organization
components/
├── ui/                           # Generic UI components
│   ├── Button/
│   │   ├── Button.tsx
│   │   ├── Button.test.tsx
│   │   ├── Button.stories.tsx    # Storybook stories
│   │   └── index.ts
├── features/                     # Feature-specific components
│   ├── authentication/
│   │   ├── SignInForm/
│   │   ├── SignUpForm/
│   │   └── UserProfile/
│   ├── projects/
│   │   ├── ProjectCard/
│   │   ├── ProjectList/
│   │   ├── CreateProjectForm/
│   │   └── EditProjectModal/
└── layouts/                      # Layout components
    ├── AppLayout/
    ├── AuthLayout/
    └── DashboardLayout/

// ✅ Component structure template
// components/ui/Button/Button.tsx
import * as React from 'react';
import { Slot } from '@radix-ui/react-slot';
import { cva, type VariantProps } from 'class-variance-authority';
import { cn } from '@/lib/utils';

// 1. Define variants with CVA
const buttonVariants = cva(
  'inline-flex items-center justify-center whitespace-nowrap rounded-md text-sm font-medium transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:pointer-events-none disabled:opacity-50',
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

// 2. Define props interface
export interface ButtonProps
  extends React.ButtonHTMLAttributes<HTMLButtonElement>,
    VariantProps<typeof buttonVariants> {
  asChild?: boolean;
  loading?: boolean;
}

// 3. Component implementation with forwardRef
const Button = React.forwardRef<HTMLButtonElement, ButtonProps>(
  ({ className, variant, size, asChild = false, loading, disabled, children, ...props }, ref) => {
    const Comp = asChild ? Slot : 'button';
    
    return (
      <Comp
        className={cn(buttonVariants({ variant, size, className }))}
        ref={ref}
        disabled={disabled || loading}
        aria-busy={loading}
        {...props}
      >
        {loading ? (
          <>
            <Loader2 className="mr-2 h-4 w-4 animate-spin" />
            Loading...
          </>
        ) : (
          children
        )}
      </Comp>
    );
  }
);

Button.displayName = 'Button';

export { Button, buttonVariants };
```

## 🔐 Security Best Practices

### **Authentication & Authorization**

```typescript
// ✅ Secure authentication setup
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
    session: async ({ session, token, user }) => {
      if (session?.user && user) {
        session.user.id = user.id;
        session.user.role = user.role;
      }
      return session;
    },
    
    jwt: async ({ token, user, account }) => {
      if (user) {
        token.id = user.id;
        token.role = user.role;
      }
      return token;
    },
    
    signIn: async ({ user, account, profile }) => {
      // Add custom sign-in logic
      if (account?.provider === 'google') {
        // Verify domain whitelist
        const allowedDomains = process.env.ALLOWED_DOMAINS?.split(',') || [];
        const userDomain = user.email?.split('@')[1];
        
        if (allowedDomains.length > 0 && !allowedDomains.includes(userDomain!)) {
          return false; // Reject sign-in
        }
      }
      return true;
    },
  },
  
  pages: {
    signIn: '/auth/signin',
    error: '/auth/error',
  },
  
  session: {
    strategy: 'database',
    maxAge: 30 * 24 * 60 * 60, // 30 days
  },
  
  // Security configurations
  useSecureCookies: process.env.NODE_ENV === 'production',
  secret: process.env.NEXTAUTH_SECRET,
};

// middleware.ts - Route protection
import { withAuth } from 'next-auth/middleware';
import { NextResponse } from 'next/server';

export default withAuth(
  function middleware(req) {
    const { pathname } = req.nextUrl;
    const { token } = req.nextauth;
    
    // Admin route protection
    if (pathname.startsWith('/admin') && token?.role !== 'ADMIN') {
      return NextResponse.rewrite(new URL('/unauthorized', req.url));
    }
    
    // API route protection
    if (pathname.startsWith('/api/admin') && token?.role !== 'ADMIN') {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }
    
    return NextResponse.next();
  },
  {
    callbacks: {
      authorized: ({ token, req }) => {
        const { pathname } = req.nextUrl;
        
        // Allow public routes
        if (pathname.startsWith('/auth') || pathname === '/') {
          return true;
        }
        
        // Require authentication for protected routes
        return !!token;
      },
    },
  }
);

export const config = {
  matcher: [
    '/((?!api/auth|_next/static|_next/image|favicon.ico).*)',
  ],
};
```

### **Input Validation & Sanitization**

```typescript
// lib/validations.ts
import { z } from 'zod';

// ✅ Comprehensive validation schemas
export const createProjectSchema = z.object({
  name: z
    .string()
    .min(1, 'Name is required')
    .max(100, 'Name must be less than 100 characters')
    .regex(/^[a-zA-Z0-9\s\-_]+$/, 'Name contains invalid characters'),
    
  description: z
    .string()
    .max(500, 'Description must be less than 500 characters')
    .optional(),
    
  priority: z.enum(['low', 'medium', 'high'], {
    errorMap: () => ({ message: 'Priority must be low, medium, or high' }),
  }),
  
  dueDate: z
    .string()
    .datetime()
    .refine(
      (date) => new Date(date) > new Date(),
      'Due date must be in the future'
    )
    .optional(),
    
  tags: z
    .array(z.string().min(1).max(20))
    .max(10, 'Maximum 10 tags allowed')
    .optional(),
});

export const updateProjectSchema = createProjectSchema.partial().extend({
  id: z.string().uuid('Invalid project ID'),
});

// ✅ API route validation
// app/api/projects/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { createProjectSchema } from '@/lib/validations';
import { getServerSession } from 'next-auth/next';
import { authOptions } from '@/lib/auth';

export async function POST(request: NextRequest) {
  try {
    // 1. Authentication check
    const session = await getServerSession(authOptions);
    if (!session?.user) {
      return NextResponse.json(
        { error: 'Authentication required' },
        { status: 401 }
      );
    }
    
    // 2. Parse and validate input
    const body = await request.json();
    const validatedData = createProjectSchema.parse(body);
    
    // 3. Authorization check (if needed)
    if (session.user.role !== 'ADMIN' && validatedData.priority === 'high') {
      return NextResponse.json(
        { error: 'Insufficient permissions for high priority projects' },
        { status: 403 }
      );
    }
    
    // 4. Sanitize and process data
    const projectData = {
      ...validatedData,
      name: validatedData.name.trim(),
      description: validatedData.description?.trim(),
      userId: session.user.id,
    };
    
    // 5. Database operation
    const project = await prisma.project.create({
      data: projectData,
      include: {
        owner: {
          select: { id: true, name: true, email: true },
        },
      },
    });
    
    return NextResponse.json(project, { status: 201 });
    
  } catch (error) {
    if (error instanceof z.ZodError) {
      return NextResponse.json(
        { 
          error: 'Validation failed',
          details: error.errors.map(err => ({
            field: err.path.join('.'),
            message: err.message,
          })),
        },
        { status: 400 }
      );
    }
    
    console.error('Project creation error:', error);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
```

### **Environment Variables & Secrets**

```typescript
// lib/env.ts
import { z } from 'zod';

// ✅ Environment variable validation
const envSchema = z.object({
  // Database
  DATABASE_URL: z.string().url(),
  
  // Authentication
  NEXTAUTH_SECRET: z.string().min(32),
  NEXTAUTH_URL: z.string().url(),
  
  // OAuth providers
  GOOGLE_CLIENT_ID: z.string().min(1),
  GOOGLE_CLIENT_SECRET: z.string().min(1),
  
  // External services
  STRIPE_SECRET_KEY: z.string().startsWith('sk_'),
  STRIPE_PUBLIC_KEY: z.string().startsWith('pk_'),
  
  // Email
  SMTP_HOST: z.string().min(1),
  SMTP_PORT: z.coerce.number().min(1).max(65535),
  SMTP_USER: z.string().email(),
  SMTP_PASSWORD: z.string().min(1),
  
  // Storage
  S3_BUCKET_NAME: z.string().min(1),
  S3_ACCESS_KEY_ID: z.string().min(1),
  S3_SECRET_ACCESS_KEY: z.string().min(1),
  S3_REGION: z.string().min(1),
  
  // Feature flags
  FEATURE_ANALYTICS: z.enum(['true', 'false']).default('false'),
  FEATURE_AI_ASSISTANCE: z.enum(['true', 'false']).default('false'),
  
  // Environment
  NODE_ENV: z.enum(['development', 'test', 'production']),
});

// Validate environment variables at startup
export const env = envSchema.parse(process.env);

// Type-safe environment variables
declare global {
  namespace NodeJS {
    interface ProcessEnv extends z.infer<typeof envSchema> {}
  }
}
```

## 🎨 Code Quality Standards

### **TypeScript Best Practices**

```typescript
// ✅ Strict TypeScript configuration
// tsconfig.json
{
  "compilerOptions": {
    "target": "ES2017",
    "lib": ["dom", "dom.iterable", "es6"],
    "allowJs": true,
    "skipLibCheck": true,
    "strict": true,
    "forceConsistentCasingInFileNames": true,
    "noEmit": true,
    "esModuleInterop": true,
    "module": "esnext",
    "moduleResolution": "node",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "jsx": "preserve",
    "incremental": true,
    "plugins": [
      {
        "name": "next"
      }
    ],
    "paths": {
      "@/*": ["./src/*"]
    },
    
    // Additional strict checks
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "exactOptionalPropertyTypes": true,
    "noImplicitReturns": true,
    "noFallthroughCasesInSwitch": true,
    "noUncheckedIndexedAccess": true
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx", ".next/types/**/*.ts"],
  "exclude": ["node_modules"]
}

// ✅ Type definitions and utilities
// types/global.d.ts
export interface User {
  id: string;
  email: string;
  name: string;
  avatar?: string;
  role: UserRole;
  createdAt: Date;
  updatedAt: Date;
}

export interface Project {
  id: string;
  name: string;
  description?: string;
  status: ProjectStatus;
  priority: ProjectPriority;
  dueDate?: Date;
  createdAt: Date;
  updatedAt: Date;
  owner: Pick<User, 'id' | 'name' | 'email'>;
  collaborators: Pick<User, 'id' | 'name' | 'avatar'>[];
  _count: {
    tasks: number;
    collaborators: number;
  };
}

export type UserRole = 'USER' | 'ADMIN' | 'MODERATOR';
export type ProjectStatus = 'DRAFT' | 'ACTIVE' | 'COMPLETED' | 'ARCHIVED';
export type ProjectPriority = 'LOW' | 'MEDIUM' | 'HIGH';

// Utility types
export type CreateProjectInput = Pick<Project, 'name' | 'description' | 'priority'> & {
  dueDate?: string;
};

export type UpdateProjectInput = Partial<CreateProjectInput> & {
  status?: ProjectStatus;
};

// ✅ Generic type utilities
// lib/types.ts
export type ApiResponse<T> = {
  data: T;
  message?: string;
  success: boolean;
};

export type PaginatedResponse<T> = {
  data: T[];
  pagination: {
    page: number;
    limit: number;
    total: number;
    totalPages: number;
    hasNext: boolean;
    hasPrevious: boolean;
  };
};

export type AsyncState<T> = {
  data: T | null;
  loading: boolean;
  error: string | null;
};

// Form field types
export type FormFieldConfig<T> = {
  name: keyof T;
  label: string;
  type: 'text' | 'email' | 'password' | 'select' | 'textarea';
  placeholder?: string;
  required?: boolean;
  validation?: z.ZodType<any>;
  options?: { label: string; value: string }[];
};
```

### **ESLint & Prettier Configuration**

```json
// .eslintrc.json
{
  "extends": [
    "next/core-web-vitals",
    "@typescript-eslint/recommended",
    "prettier"
  ],
  "plugins": ["@typescript-eslint"],
  "rules": {
    // TypeScript specific
    "@typescript-eslint/no-unused-vars": "error",
    "@typescript-eslint/no-explicit-any": "warn",
    "@typescript-eslint/prefer-const": "error",
    "@typescript-eslint/no-non-null-assertion": "warn",
    
    // React specific
    "react/jsx-no-target-blank": "error",
    "react/jsx-key": "error",
    "react-hooks/exhaustive-deps": "warn",
    
    // General code quality
    "prefer-const": "error",
    "no-console": "warn",
    "no-debugger": "error",
    "no-duplicate-imports": "error",
    "no-unused-expressions": "error",
    
    // Accessibility
    "jsx-a11y/alt-text": "error",
    "jsx-a11y/aria-props": "error",
    "jsx-a11y/aria-proptypes": "error",
    "jsx-a11y/aria-unsupported-elements": "error",
    "jsx-a11y/role-has-required-aria-props": "error",
    "jsx-a11y/role-supports-aria-props": "error"
  },
  "overrides": [
    {
      "files": ["**/*.test.ts", "**/*.test.tsx"],
      "rules": {
        "@typescript-eslint/no-explicit-any": "off"
      }
    }
  ]
}

// prettier.config.js
module.exports = {
  semi: true,
  singleQuote: true,
  tabWidth: 2,
  trailingComma: 'es5',
  printWidth: 80,
  bracketSpacing: true,
  arrowParens: 'avoid',
  endOfLine: 'lf',
  
  // Plugin configurations
  plugins: ['prettier-plugin-tailwindcss'],
  
  // File type specific overrides
  overrides: [
    {
      files: '*.json',
      options: {
        printWidth: 200,
      },
    },
  ],
};
```

## 🚀 Performance Guidelines

### **Bundle Optimization**

```javascript
// next.config.js
/** @type {import('next').NextConfig} */
const nextConfig = {
  // Compiler optimizations
  swcMinify: true,
  compiler: {
    removeConsole: process.env.NODE_ENV === 'production',
  },
  
  // Experimental features
  experimental: {
    optimizeCss: true,
    gzipSize: true,
  },
  
  // Bundle analyzer (development only)
  ...(process.env.ANALYZE === 'true' && {
    webpack: (config, { isServer }) => {
      if (!isServer) {
        const { BundleAnalyzerPlugin } = require('webpack-bundle-analyzer');
        config.plugins.push(
          new BundleAnalyzerPlugin({
            analyzerMode: 'static',
            openAnalyzer: false,
          })
        );
      }
      return config;
    },
  }),
  
  // Image optimization
  images: {
    domains: ['example.com', 'cdn.example.com'],
    formats: ['image/webp', 'image/avif'],
  },
  
  // Headers for caching
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
```

### **Code Splitting Strategy**

```typescript
// ✅ Strategic dynamic imports
// components/LazyComponents.tsx
import dynamic from 'next/dynamic';

// Heavy chart library - load only when needed
const Chart = dynamic(() => import('./Chart'), {
  loading: () => <ChartSkeleton />,
  ssr: false,
});

// Admin panel - role-based loading
const AdminPanel = dynamic(() => import('./AdminPanel'), {
  loading: () => <div>Loading admin panel...</div>,
});

// Modal - load only when opened
const Modal = dynamic(() => import('./Modal'), {
  ssr: false,
});

// Feature-flag based components
const BetaFeature = dynamic(() => import('./BetaFeature'), {
  loading: () => null,
  ssr: false,
});

export function ConditionalLoader({ user, showModal }: Props) {
  return (
    <>
      {user.role === 'admin' && <AdminPanel />}
      {showModal && <Modal />}
      {process.env.NEXT_PUBLIC_FEATURE_BETA === 'true' && <BetaFeature />}
      <Chart data={chartData} />
    </>
  );
}
```

## 🧪 Testing Strategy

### **Test Organization**

```typescript
// ✅ Comprehensive testing setup
// vitest.config.ts
import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    environment: 'jsdom',
    setupFiles: ['./src/test/setup.ts'],
    coverage: {
      thresholds: {
        global: {
          branches: 80,
          functions: 80,
          lines: 80,
          statements: 80,
        },
      },
    },
  },
});

// src/test/test-utils.tsx
import { render, RenderOptions } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { SessionProvider } from 'next-auth/react';

// Test wrapper with providers
function TestWrapper({ children }: { children: React.ReactNode }) {
  const queryClient = new QueryClient({
    defaultOptions: {
      queries: { retry: false },
      mutations: { retry: false },
    },
  });

  const mockSession = {
    user: { id: '1', email: 'test@example.com', name: 'Test User' },
    expires: '2024-12-31',
  };

  return (
    <SessionProvider session={mockSession}>
      <QueryClientProvider client={queryClient}>
        {children}
      </QueryClientProvider>
    </SessionProvider>
  );
}

// Custom render function
export function renderWithProviders(
  ui: React.ReactElement,
  options?: Omit<RenderOptions, 'wrapper'>
) {
  return render(ui, { wrapper: TestWrapper, ...options });
}

// Re-export everything
export * from '@testing-library/react';
export { renderWithProviders as render };
```

## 🔄 Development Workflow

### **Git Workflow & Conventions**

```bash
# ✅ Semantic commit messages
git commit -m "feat: add project filtering functionality"
git commit -m "fix: resolve authentication redirect issue"
git commit -m "docs: update API documentation"
git commit -m "test: add unit tests for project service"
git commit -m "refactor: optimize project list rendering"
git commit -m "style: format code with prettier"
git commit -m "perf: implement virtual scrolling for large lists"

# Commit types:
# feat: new feature
# fix: bug fix
# docs: documentation changes
# test: adding or updating tests
# refactor: code refactoring
# style: code formatting
# perf: performance improvements
# chore: maintenance tasks
```

### **Pre-commit Hooks**

```json
// package.json
{
  "husky": {
    "hooks": {
      "pre-commit": "lint-staged",
      "commit-msg": "commitlint -E HUSKY_GIT_PARAMS"
    }
  },
  "lint-staged": {
    "*.{js,jsx,ts,tsx}": [
      "eslint --fix",
      "prettier --write",
      "git add"
    ],
    "*.{json,md,yml,yaml}": [
      "prettier --write",
      "git add"
    ]
  }
}

// .commitlintrc.js
module.exports = {
  extends: ['@commitlint/config-conventional'],
  rules: {
    'type-enum': [
      2,
      'always',
      ['feat', 'fix', 'docs', 'style', 'refactor', 'test', 'chore', 'perf'],
    ],
    'subject-max-length': [2, 'always', 100],
    'body-max-line-length': [2, 'always', 100],
  },
};
```

## 📊 Monitoring & Analytics

### **Performance Monitoring**

```typescript
// lib/analytics.ts
import { NextWebVitalsMetric } from 'next/app';

export function reportWebVitals(metric: NextWebVitalsMetric) {
  // Send to analytics service
  if (process.env.NODE_ENV === 'production') {
    switch (metric.name) {
      case 'FCP':
      case 'LCP':
      case 'CLS':
      case 'FID':
      case 'TTFB':
        // Send to your analytics service
        analytics.track('web_vitals', {
          metric: metric.name,
          value: metric.value,
          page: window.location.pathname,
        });
        break;
    }
  }
}

// Error monitoring
export function reportError(error: Error, errorInfo?: any) {
  if (process.env.NODE_ENV === 'production') {
    // Send to error reporting service (Sentry, Bugsnag, etc.)
    console.error('Application error:', error, errorInfo);
  }
}
```

## 🎯 Production Checklist

### **Pre-deployment Checklist**

- [ ] **Security**
  - [ ] Environment variables properly configured
  - [ ] Authentication/authorization implemented
  - [ ] Input validation and sanitization
  - [ ] HTTPS enabled
  - [ ] CORS properly configured
  - [ ] Rate limiting implemented

- [ ] **Performance**
  - [ ] Bundle size optimized (<1MB initial load)
  - [ ] Images optimized (WebP/AVIF)
  - [ ] Code splitting implemented
  - [ ] Lighthouse score >90
  - [ ] Core Web Vitals passing

- [ ] **Testing**
  - [ ] Unit test coverage >80%
  - [ ] Integration tests for critical paths
  - [ ] E2E tests for user journeys
  - [ ] Error scenarios tested

- [ ] **Monitoring**
  - [ ] Error tracking configured
  - [ ] Performance monitoring setup
  - [ ] Analytics implemented
  - [ ] Health checks configured

- [ ] **Documentation**
  - [ ] README with setup instructions
  - [ ] API documentation updated
  - [ ] Deployment guide available
  - [ ] Troubleshooting guide created

---

## Navigation

- ← Previous: [Testing Strategies](./testing-strategies.md)
- → Next: [Implementation Guide](./implementation-guide.md)

| [📋 Overview](./README.md) | [🧪 Testing](./testing-strategies.md) | [⚡ Best Practices](#) | [🚀 Implementation](./implementation-guide.md) |
|---|---|---|---|