# Project Architecture Analysis: React & Next.js Open Source Applications

## 🎯 Overview

Detailed architectural analysis of folder structures, code organization patterns, and scalability strategies used in production React and Next.js open source projects.

## 🏗️ Common Architecture Patterns

### **Monorepo vs Single Repo Analysis**

| Project | Structure | Tools | Reasoning |
|---------|-----------|-------|-----------|
| **Cal.com** | Monorepo | Turborepo | Multiple apps (web, mobile, docs) |
| **Plane** | Single Repo | Standard Next.js | Focused web application |
| **Novel** | Single Repo | Standard Next.js | Library + demo app |
| **Dub** | Monorepo | Turborepo | Web app + API + packages |
| **Langfuse** | Monorepo | Turborepo | Web + worker + packages |

### **Monorepo Architecture Deep Dive**

```
cal.com/ (Turborepo Example)
├── apps/
│   ├── web/                    # Main Next.js application
│   │   ├── app/               # Next.js 13+ App Router
│   │   ├── components/        # App-specific components
│   │   ├── lib/              # App-specific utilities
│   │   ├── pages/            # Legacy pages (migration)
│   │   └── public/           # Static assets
│   ├── storybook/            # Component documentation
│   ├── docs/                 # Documentation site
│   └── console/              # Admin console app
├── packages/
│   ├── ui/                   # Shared UI components
│   │   ├── components/       # Reusable components
│   │   ├── hooks/           # Shared hooks
│   │   ├── lib/             # UI utilities
│   │   └── styles/          # Shared styles
│   ├── lib/                 # Shared business logic
│   │   ├── auth/            # Authentication utilities
│   │   ├── database/        # Database utilities
│   │   ├── emails/          # Email templates
│   │   └── utils/           # Common utilities
│   ├── prisma/              # Database schema
│   ├── trpc/                # API layer
│   ├── config/              # Shared configurations
│   │   ├── eslint/          # ESLint configs
│   │   ├── tailwind/        # Tailwind configs
│   │   └── typescript/      # TypeScript configs
│   └── types/               # Shared TypeScript types
├── tools/
│   ├── deploy/              # Deployment scripts
│   └── scripts/             # Build scripts
├── turbo.json               # Turborepo configuration
├── package.json             # Root package.json
└── tsconfig.json           # Root TypeScript config
```

### **Single Repo Architecture (Feature-Based)**

```
plane/ (Feature-Based Organization)
├── components/
│   ├── ui/                  # Base UI components
│   │   ├── avatar/
│   │   ├── button/
│   │   ├── input/
│   │   └── modal/
│   ├── core/               # Core business components
│   │   ├── sidebar/
│   │   ├── header/
│   │   └── breadcrumbs/
│   ├── issues/             # Issue management
│   │   ├── board-view/
│   │   ├── list-view/
│   │   ├── create-issue/
│   │   └── issue-detail/
│   ├── projects/           # Project management
│   │   ├── project-card/
│   │   ├── project-settings/
│   │   └── project-sidebar/
│   ├── workspace/          # Workspace features
│   │   ├── workspace-sidebar/
│   │   ├── workspace-settings/
│   │   └── member-management/
│   └── analytics/          # Analytics components
│       ├── charts/
│       ├── reports/
│       └── dashboards/
├── constants/              # Application constants
│   ├── api.ts
│   ├── colors.ts
│   ├── routes.ts
│   └── workspace.ts
├── contexts/               # React contexts
│   ├── app-provider.tsx
│   ├── issue-provider.tsx
│   └── project-provider.tsx
├── helpers/                # Utility functions
│   ├── date.ts
│   ├── string.ts
│   ├── array.ts
│   └── common.ts
├── hooks/                  # Custom React hooks
│   ├── use-issues.ts
│   ├── use-projects.ts
│   ├── use-workspace.ts
│   └── use-local-storage.ts
├── layouts/                # Page layouts
│   ├── app-layout/
│   ├── auth-layout/
│   └── onboarding-layout/
├── lib/                    # Core utilities
│   ├── auth.ts
│   ├── api.ts
│   ├── utils.ts
│   └── validations.ts
├── pages/                  # Next.js pages
│   ├── api/                # API routes
│   ├── [workspaceSlug]/    # Dynamic workspace routes
│   ├── auth/               # Authentication pages
│   └── onboarding/         # Onboarding flow
├── services/               # API service layer
│   ├── issues/
│   ├── projects/
│   ├── workspace/
│   └── auth/
├── store/                  # State management
│   ├── issue.store.ts
│   ├── project.store.ts
│   ├── user.store.ts
│   └── workspace.store.ts
└── types/                  # TypeScript definitions
    ├── api.d.ts
    ├── issues.d.ts
    ├── projects.d.ts
    └── workspace.d.ts
```

## 🔍 Component Organization Strategies

### **Strategy 1: Atomic Design (Radix UI Projects)**

```
components/
├── atoms/                  # Basic building blocks
│   ├── Button/
│   │   ├── Button.tsx
│   │   ├── Button.test.tsx
│   │   ├── Button.stories.tsx
│   │   └── index.ts
│   ├── Input/
│   ├── Badge/
│   └── Icon/
├── molecules/              # Combinations of atoms
│   ├── SearchInput/        # Input + Icon + Button
│   ├── FormField/          # Label + Input + Error
│   ├── CardHeader/         # Title + Subtitle + Actions
│   └── Navigation/
├── organisms/              # Complex UI sections
│   ├── Header/
│   ├── Sidebar/
│   ├── DataTable/
│   └── ProjectCard/
├── templates/              # Page-level components
│   ├── DashboardTemplate/
│   ├── ProjectTemplate/
│   └── SettingsTemplate/
└── pages/                  # Complete pages
    ├── Dashboard/
    ├── ProjectDetail/
    └── Settings/
```

### **Strategy 2: Feature-Based Organization (Plane, Cal.com)**

```
components/
├── ui/                     # Generic, reusable components
│   ├── button/
│   ├── input/
│   ├── modal/
│   ├── dropdown/
│   └── index.ts           # Barrel exports
├── layout/                 # Layout components
│   ├── app-layout/
│   ├── sidebar/
│   ├── header/
│   └── footer/
├── features/               # Feature-specific components
│   ├── authentication/
│   │   ├── SignInForm/
│   │   ├── SignUpForm/
│   │   ├── ForgotPassword/
│   │   └── index.ts
│   ├── projects/
│   │   ├── ProjectList/
│   │   ├── ProjectCard/
│   │   ├── CreateProject/
│   │   ├── EditProject/
│   │   └── ProjectSettings/
│   ├── issues/
│   │   ├── IssueBoard/
│   │   ├── IssueList/
│   │   ├── IssueDetail/
│   │   └── CreateIssue/
│   └── analytics/
│       ├── Charts/
│       ├── Reports/
│       └── Dashboard/
└── shared/                 # Shared across features
    ├── ErrorBoundary/
    ├── LoadingSpinner/
    ├── ErrorMessage/
    └── ConfirmDialog/
```

### **Strategy 3: Domain-Driven Design (Enterprise Projects)**

```
src/
├── domains/
│   ├── user/
│   │   ├── components/
│   │   │   ├── UserProfile/
│   │   │   ├── UserList/
│   │   │   └── UserSettings/
│   │   ├── hooks/
│   │   │   ├── useUser.ts
│   │   │   └── useUsersList.ts
│   │   ├── services/
│   │   │   └── userService.ts
│   │   ├── types/
│   │   │   └── user.types.ts
│   │   └── utils/
│   │       └── userUtils.ts
│   ├── project/
│   │   ├── components/
│   │   ├── hooks/
│   │   ├── services/
│   │   ├── types/
│   │   └── utils/
│   └── workspace/
│       ├── components/
│       ├── hooks/
│       ├── services/
│       ├── types/
│       └── utils/
├── shared/
│   ├── components/         # Cross-domain components
│   ├── hooks/             # Cross-domain hooks
│   ├── services/          # Cross-domain services
│   ├── types/             # Cross-domain types
│   └── utils/             # Cross-domain utilities
└── app/
    ├── layout.tsx
    ├── page.tsx
    └── globals.css
```

## 📁 File Naming Conventions

### **Next.js App Router Conventions**

```
app/
├── (auth)/                 # Route groups (no URL segment)
│   ├── signin/
│   │   └── page.tsx       # /signin
│   └── signup/
│       └── page.tsx       # /signup
├── dashboard/
│   ├── loading.tsx        # Loading UI
│   ├── error.tsx          # Error UI
│   ├── not-found.tsx      # 404 UI
│   ├── page.tsx           # /dashboard
│   └── projects/
│       ├── [id]/
│       │   ├── page.tsx   # /dashboard/projects/[id]
│       │   └── edit/
│       │       └── page.tsx # /dashboard/projects/[id]/edit
│       └── page.tsx       # /dashboard/projects
├── api/
│   ├── auth/
│   │   └── route.ts       # Auth API endpoints
│   └── projects/
│       ├── route.ts       # /api/projects
│       └── [id]/
│           └── route.ts   # /api/projects/[id]
├── globals.css
├── layout.tsx             # Root layout
└── page.tsx              # Home page
```

### **Component File Conventions**

```
Button/
├── Button.tsx             # Main component
├── Button.test.tsx        # Unit tests
├── Button.stories.tsx     # Storybook stories
├── Button.module.css      # Component styles (if needed)
├── index.ts              # Barrel export
└── types.ts              # Component-specific types

# Alternative naming (some projects prefer)
button.tsx                 # kebab-case
button.test.tsx
button.stories.tsx
index.ts

# For complex components with sub-components
Dialog/
├── Dialog.tsx             # Main component
├── DialogContent.tsx      # Sub-component
├── DialogHeader.tsx       # Sub-component
├── DialogFooter.tsx       # Sub-component
├── Dialog.test.tsx        # Tests
├── index.ts              # Exports all sub-components
└── types.ts              # Shared types
```

## 🔧 Configuration Architecture

### **Multi-Environment Configuration**

```typescript
// lib/config/index.ts
import { z } from 'zod';

const configSchema = z.object({
  app: z.object({
    name: z.string(),
    version: z.string(),
    url: z.string().url(),
    environment: z.enum(['development', 'test', 'staging', 'production']),
  }),
  database: z.object({
    url: z.string(),
    maxConnections: z.number().default(10),
  }),
  auth: z.object({
    secret: z.string().min(32),
    providers: z.object({
      google: z.object({
        clientId: z.string(),
        clientSecret: z.string(),
      }).optional(),
      github: z.object({
        clientId: z.string(),
        clientSecret: z.string(),
      }).optional(),
    }),
  }),
  integrations: z.object({
    stripe: z.object({
      publicKey: z.string(),
      secretKey: z.string(),
      webhookSecret: z.string(),
    }).optional(),
    resend: z.object({
      apiKey: z.string(),
    }).optional(),
  }),
  features: z.object({
    analytics: z.boolean().default(false),
    aiAssistant: z.boolean().default(false),
    betaFeatures: z.boolean().default(false),
  }),
});

const config = configSchema.parse({
  app: {
    name: process.env.NEXT_PUBLIC_APP_NAME || 'My App',
    version: process.env.NEXT_PUBLIC_APP_VERSION || '1.0.0',
    url: process.env.NEXT_PUBLIC_APP_URL || 'http://localhost:3000',
    environment: process.env.NODE_ENV || 'development',
  },
  database: {
    url: process.env.DATABASE_URL!,
    maxConnections: parseInt(process.env.DATABASE_MAX_CONNECTIONS || '10'),
  },
  auth: {
    secret: process.env.NEXTAUTH_SECRET!,
    providers: {
      google: process.env.GOOGLE_CLIENT_ID ? {
        clientId: process.env.GOOGLE_CLIENT_ID,
        clientSecret: process.env.GOOGLE_CLIENT_SECRET!,
      } : undefined,
      github: process.env.GITHUB_CLIENT_ID ? {
        clientId: process.env.GITHUB_CLIENT_ID,
        secretKey: process.env.GITHUB_CLIENT_SECRET!,
      } : undefined,
    },
  },
  integrations: {
    stripe: process.env.STRIPE_SECRET_KEY ? {
      publicKey: process.env.NEXT_PUBLIC_STRIPE_PUBLIC_KEY!,
      secretKey: process.env.STRIPE_SECRET_KEY,
      webhookSecret: process.env.STRIPE_WEBHOOK_SECRET!,
    } : undefined,
    resend: process.env.RESEND_API_KEY ? {
      apiKey: process.env.RESEND_API_KEY,
    } : undefined,
  },
  features: {
    analytics: process.env.NEXT_PUBLIC_FEATURE_ANALYTICS === 'true',
    aiAssistant: process.env.NEXT_PUBLIC_FEATURE_AI === 'true',
    betaFeatures: process.env.NEXT_PUBLIC_FEATURE_BETA === 'true',
  },
});

export { config };
export type Config = z.infer<typeof configSchema>;

// lib/config/database.ts
export const databaseConfig = {
  url: config.database.url,
  connectionLimit: config.database.maxConnections,
  ssl: config.app.environment === 'production',
  logging: config.app.environment === 'development',
};

// lib/config/auth.ts
export const authConfig = {
  secret: config.auth.secret,
  providers: config.auth.providers,
  session: {
    strategy: 'database' as const,
    maxAge: 30 * 24 * 60 * 60, // 30 days
  },
  cookies: {
    secure: config.app.environment === 'production',
    sameSite: 'lax' as const,
  },
};
```

## 🎯 State Management Architecture

### **Zustand Store Organization**

```typescript
// stores/index.ts - Store composition
import { create } from 'zustand';
import { devtools, subscribeWithSelector } from 'zustand/middleware';
import { createAuthSlice, type AuthSlice } from './slices/auth';
import { createUISlice, type UISlice } from './slices/ui';
import { createProjectSlice, type ProjectSlice } from './slices/project';

export type AppStore = AuthSlice & UISlice & ProjectSlice;

export const useAppStore = create<AppStore>()(
  devtools(
    subscribeWithSelector(
      (...a) => ({
        ...createAuthSlice(...a),
        ...createUISlice(...a),
        ...createProjectSlice(...a),
      })
    ),
    { name: 'app-store' }
  )
);

// Slice selectors for better performance
export const useAuth = () => useAppStore((state) => ({
  user: state.user,
  isAuthenticated: state.isAuthenticated,
  login: state.login,
  logout: state.logout,
}));

export const useUI = () => useAppStore((state) => ({
  sidebar: state.sidebar,
  theme: state.theme,
  toggleSidebar: state.toggleSidebar,
  setTheme: state.setTheme,
}));

export const useProjects = () => useAppStore((state) => ({
  projects: state.projects,
  currentProject: state.currentProject,
  setProjects: state.setProjects,
  setCurrentProject: state.setCurrentProject,
}));

// stores/slices/auth.ts
import { StateCreator } from 'zustand';

export interface AuthSlice {
  user: User | null;
  isAuthenticated: boolean;
  login: (user: User) => void;
  logout: () => void;
  updateUser: (updates: Partial<User>) => void;
}

export const createAuthSlice: StateCreator<
  AppStore,
  [],
  [],
  AuthSlice
> = (set, get) => ({
  user: null,
  isAuthenticated: false,
  
  login: (user) => set({ user, isAuthenticated: true }),
  
  logout: () => set({ user: null, isAuthenticated: false }),
  
  updateUser: (updates) => set((state) => ({
    user: state.user ? { ...state.user, ...updates } : null,
  })),
});

// stores/slices/project.ts
export interface ProjectSlice {
  projects: Project[];
  currentProject: Project | null;
  filters: ProjectFilters;
  setProjects: (projects: Project[]) => void;
  addProject: (project: Project) => void;
  updateProject: (id: string, updates: Partial<Project>) => void;
  removeProject: (id: string) => void;
  setCurrentProject: (project: Project | null) => void;
  setFilters: (filters: Partial<ProjectFilters>) => void;
  getFilteredProjects: () => Project[];
}

export const createProjectSlice: StateCreator<
  AppStore,
  [],
  [],
  ProjectSlice
> = (set, get) => ({
  projects: [],
  currentProject: null,
  filters: { status: 'all', priority: 'all', search: '' },
  
  setProjects: (projects) => set({ projects }),
  
  addProject: (project) => set((state) => ({
    projects: [project, ...state.projects],
  })),
  
  updateProject: (id, updates) => set((state) => ({
    projects: state.projects.map((p) =>
      p.id === id ? { ...p, ...updates } : p
    ),
    currentProject: state.currentProject?.id === id
      ? { ...state.currentProject, ...updates }
      : state.currentProject,
  })),
  
  removeProject: (id) => set((state) => ({
    projects: state.projects.filter((p) => p.id !== id),
    currentProject: state.currentProject?.id === id
      ? null
      : state.currentProject,
  })),
  
  setCurrentProject: (currentProject) => set({ currentProject }),
  
  setFilters: (newFilters) => set((state) => ({
    filters: { ...state.filters, ...newFilters },
  })),
  
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
});
```

## 🔄 API Architecture Patterns

### **Service Layer Organization**

```typescript
// services/base/api-client.ts
import axios, { AxiosInstance, AxiosRequestConfig } from 'axios';

class ApiClient {
  private client: AxiosInstance;

  constructor(baseURL: string) {
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
        const token = this.getAuthToken();
        if (token) {
          config.headers.Authorization = `Bearer ${token}`;
        }
        return config;
      },
      (error) => Promise.reject(error)
    );

    // Response interceptor
    this.client.interceptors.response.use(
      (response) => response,
      async (error) => {
        if (error.response?.status === 401) {
          await this.handleTokenRefresh();
          return this.client.request(error.config);
        }
        return Promise.reject(error);
      }
    );
  }

  private getAuthToken(): string | null {
    return localStorage.getItem('accessToken');
  }

  private async handleTokenRefresh(): Promise<void> {
    // Token refresh logic
  }

  async get<T>(url: string, config?: AxiosRequestConfig): Promise<T> {
    const response = await this.client.get(url, config);
    return response.data;
  }

  async post<T>(url: string, data?: any, config?: AxiosRequestConfig): Promise<T> {
    const response = await this.client.post(url, data, config);
    return response.data;
  }

  async put<T>(url: string, data?: any, config?: AxiosRequestConfig): Promise<T> {
    const response = await this.client.put(url, data, config);
    return response.data;
  }

  async delete<T>(url: string, config?: AxiosRequestConfig): Promise<T> {
    const response = await this.client.delete(url, config);
    return response.data;
  }
}

export const apiClient = new ApiClient('/api');

// services/projects/project.service.ts
export class ProjectService {
  async getProjects(filters?: ProjectFilters): Promise<Project[]> {
    const params = new URLSearchParams();
    if (filters?.status && filters.status !== 'all') {
      params.append('status', filters.status);
    }
    if (filters?.priority && filters.priority !== 'all') {
      params.append('priority', filters.priority);
    }
    if (filters?.search) {
      params.append('search', filters.search);
    }

    return apiClient.get(`/projects?${params.toString()}`);
  }

  async getProject(id: string): Promise<Project> {
    return apiClient.get(`/projects/${id}`);
  }

  async createProject(data: CreateProjectInput): Promise<Project> {
    return apiClient.post('/projects', data);
  }

  async updateProject(id: string, data: UpdateProjectInput): Promise<Project> {
    return apiClient.put(`/projects/${id}`, data);
  }

  async deleteProject(id: string): Promise<void> {
    return apiClient.delete(`/projects/${id}`);
  }
}

export const projectService = new ProjectService();

// services/index.ts
export { projectService } from './projects/project.service';
export { userService } from './users/user.service';
export { authService } from './auth/auth.service';
```

## 📊 Scaling Considerations

### **Performance Architecture**

```typescript
// lib/performance/code-splitting.ts
import dynamic from 'next/dynamic';

// Feature-based code splitting
export const DynamicComponents = {
  Analytics: dynamic(() => import('@/features/analytics/AnalyticsDashboard'), {
    loading: () => <AnalyticsSkeleton />,
    ssr: false,
  }),
  
  ProjectBoard: dynamic(() => import('@/features/projects/ProjectBoard'), {
    loading: () => <BoardSkeleton />,
  }),
  
  AdminPanel: dynamic(() => import('@/features/admin/AdminPanel'), {
    loading: () => <AdminSkeleton />,
  }),
  
  Settings: dynamic(() => import('@/features/settings/SettingsPanel'), {
    loading: () => <SettingsSkeleton />,
  }),
};

// Conditional loading based on user permissions
export function ConditionalComponent({ 
  user, 
  component: Component,
  fallback 
}: {
  user: User;
  component: string;
  fallback?: React.ComponentType;
}) {
  const hasPermission = checkUserPermission(user, component);
  
  if (!hasPermission) {
    return fallback ? <fallback /> : null;
  }
  
  const DynamicComponent = DynamicComponents[component];
  return DynamicComponent ? <DynamicComponent /> : null;
}

// lib/performance/virtual-scrolling.ts
export function useVirtualizedList<T>(
  items: T[],
  itemHeight: number,
  containerHeight: number
) {
  const [scrollTop, setScrollTop] = useState(0);
  
  const visibleStart = Math.floor(scrollTop / itemHeight);
  const visibleEnd = Math.min(
    visibleStart + Math.ceil(containerHeight / itemHeight) + 1,
    items.length
  );
  
  const visibleItems = items.slice(visibleStart, visibleEnd);
  
  return {
    visibleItems,
    scrollTop,
    setScrollTop,
    totalHeight: items.length * itemHeight,
    offsetY: visibleStart * itemHeight,
  };
}
```

## 🎯 Architecture Decision Matrix

| Pattern | Small App | Medium App | Large App | Team Size | Complexity |
|---------|-----------|------------|-----------|-----------|------------|
| **Single Repo + Features** | ✅ | ✅ | ⚠️ | 1-5 | Low |
| **Monorepo + Packages** | ⚠️ | ✅ | ✅ | 3-15 | Medium |
| **Micro-Frontend** | ❌ | ⚠️ | ✅ | 10+ | High |
| **Domain-Driven** | ❌ | ✅ | ✅ | 5-20 | High |

### **Decision Framework**

**Choose Single Repo when:**
- Team size < 5 developers
- Single product focus
- Rapid prototyping/MVP
- Limited external integrations

**Choose Monorepo when:**
- Multiple related applications
- Shared component library needed
- Team size 3-15 developers
- Code sharing across projects

**Choose Micro-Frontend when:**
- Large, distributed teams
- Independent deployment needs
- Different technology stacks
- Complex domain boundaries

## 🏆 Architecture Best Practices

### **✅ Recommended Patterns**
1. **Start simple** - begin with single repo, evolve to monorepo
2. **Feature-based organization** for most projects
3. **Shared UI package** when multiple apps exist
4. **Domain-driven design** for complex business logic
5. **Consistent naming conventions** across all projects
6. **Barrel exports** for clean import statements
7. **Configuration layers** for environment management

### **❌ Anti-Patterns to Avoid**
1. **Premature optimization** - don't start with complex architecture
2. **Deep nesting** - keep folder depth < 4 levels
3. **Circular dependencies** - maintain unidirectional data flow
4. **Monolithic components** - break down large components
5. **Inconsistent organization** - establish and follow patterns
6. **Missing abstractions** - don't repeat yourself
7. **Tight coupling** - maintain loose coupling between modules

---

## Navigation

- ← Previous: [Implementation Guide](./implementation-guide.md)
- → Back to: [Research Overview](./README.md)

| [📋 Overview](./README.md) | [🚀 Implementation](./implementation-guide.md) | [🏗️ Architecture](#) | [📊 Executive Summary](./executive-summary.md) |
|---|---|---|---|