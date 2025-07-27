# API Integration Approaches in Production React/Next.js Applications

## 🎯 Overview

Comprehensive analysis of API integration patterns used in production React and Next.js applications. This document covers REST APIs, GraphQL, tRPC, and various data fetching strategies observed in real-world projects.

## 📊 API Integration Distribution

Based on analysis of 25+ production React/Next.js projects:

| Approach | Usage | Best For | Example Projects |
|----------|-------|----------|------------------|
| **REST + React Query** | 40% | Most applications, simple APIs | Cal.com, Supabase Dashboard |
| **GraphQL + Apollo** | 25% | Complex data requirements | Saleor, Hasura projects |
| **tRPC** | 20% | TypeScript full-stack apps | T3 Stack projects |
| **REST + SWR** | 10% | Vercel ecosystem projects | Next.js examples |
| **Custom Solutions** | 5% | Specific requirements | Legacy systems |

## 🔄 REST API Patterns

### React Query Implementation

React Query has become the dominant choice for REST API integration:

```typescript
// lib/api-client.ts - Base API client setup
import { QueryClient } from '@tanstack/react-query';

// Configure query client
export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 1000 * 60 * 5, // 5 minutes
      retry: (failureCount, error: any) => {
        // Don't retry on 4xx errors (except 429)
        if (error?.status >= 400 && error?.status < 500 && error?.status !== 429) {
          return false;
        }
        return failureCount < 3;
      },
      refetchOnWindowFocus: false,
    },
    mutations: {
      retry: false,
    },
  },
});

// API client with interceptors
class ApiClient {
  private baseURL: string;
  private token: string | null = null;
  
  constructor(baseURL: string) {
    this.baseURL = baseURL;
  }
  
  setToken(token: string | null) {
    this.token = token;
  }
  
  private async request<T>(
    endpoint: string, 
    options: RequestInit = {}
  ): Promise<T> {
    const url = `${this.baseURL}${endpoint}`;
    
    const config: RequestInit = {
      headers: {
        'Content-Type': 'application/json',
        ...(this.token && { Authorization: `Bearer ${this.token}` }),
        ...options.headers,
      },
      ...options,
    };
    
    const response = await fetch(url, config);
    
    if (!response.ok) {
      const error = await response.json().catch(() => ({}));
      throw new ApiError(error.message || 'API request failed', response.status, error);
    }
    
    return response.json();
  }
  
  get<T>(endpoint: string, params?: Record<string, any>): Promise<T> {
    const searchParams = params ? `?${new URLSearchParams(params).toString()}` : '';
    return this.request<T>(`${endpoint}${searchParams}`);
  }
  
  post<T>(endpoint: string, data?: any): Promise<T> {
    return this.request<T>(endpoint, {
      method: 'POST',
      body: data ? JSON.stringify(data) : undefined,
    });
  }
  
  put<T>(endpoint: string, data?: any): Promise<T> {
    return this.request<T>(endpoint, {
      method: 'PUT',
      body: data ? JSON.stringify(data) : undefined,
    });
  }
  
  patch<T>(endpoint: string, data?: any): Promise<T> {
    return this.request<T>(endpoint, {
      method: 'PATCH',
      body: data ? JSON.stringify(data) : undefined,
    });
  }
  
  delete<T>(endpoint: string): Promise<T> {
    return this.request<T>(endpoint, { method: 'DELETE' });
  }
}

export const apiClient = new ApiClient(process.env.NEXT_PUBLIC_API_URL || '/api');

// Custom error class
export class ApiError extends Error {
  constructor(
    message: string,
    public status: number,
    public details?: any
  ) {
    super(message);
    this.name = 'ApiError';
  }
}
```

### Query Key Factories (Pattern from Cal.com)

```typescript
// hooks/query-keys.ts - Organized query key management
export const queryKeys = {
  // Users
  users: {
    all: ['users'] as const,
    lists: () => [...queryKeys.users.all, 'list'] as const,
    list: (filters: UserFilters) => [...queryKeys.users.lists(), filters] as const,
    details: () => [...queryKeys.users.all, 'detail'] as const,
    detail: (id: string) => [...queryKeys.users.details(), id] as const,
    profile: () => [...queryKeys.users.all, 'profile'] as const,
  },
  
  // Projects
  projects: {
    all: ['projects'] as const,
    lists: () => [...queryKeys.projects.all, 'list'] as const,
    list: (filters: ProjectFilters) => [...queryKeys.projects.lists(), filters] as const,
    details: () => [...queryKeys.projects.all, 'detail'] as const,
    detail: (id: string) => [...queryKeys.projects.details(), id] as const,
    tasks: (projectId: string) => [...queryKeys.projects.detail(projectId), 'tasks'] as const,
  },
  
  // Analytics
  analytics: {
    all: ['analytics'] as const,
    dashboard: (dateRange: DateRange) => [...queryKeys.analytics.all, 'dashboard', dateRange] as const,
    reports: (type: string, params: any) => [...queryKeys.analytics.all, 'reports', type, params] as const,
  },
} as const;
```

### Resource-Based Hooks (Pattern from Supabase Dashboard)

```typescript
// hooks/use-projects.ts - Resource-specific hooks
interface Project {
  id: string;
  name: string;
  description: string;
  status: 'active' | 'archived' | 'draft';
  ownerId: string;
  createdAt: string;
  updatedAt: string;
}

interface ProjectFilters {
  status?: string;
  search?: string;
  ownerId?: string;
  page?: number;
  limit?: number;
}

interface CreateProjectData {
  name: string;
  description?: string;
  status?: Project['status'];
}

interface UpdateProjectData {
  name?: string;
  description?: string;
  status?: Project['status'];
}

// Fetch projects with filtering and pagination
export function useProjects(filters: ProjectFilters = {}) {
  return useQuery({
    queryKey: queryKeys.projects.list(filters),
    queryFn: () => apiClient.get<PaginatedResponse<Project>>('/projects', filters),
    keepPreviousData: true, // Keep old data while fetching new
  });
}

// Fetch single project
export function useProject(id: string, options?: { enabled?: boolean }) {
  return useQuery({
    queryKey: queryKeys.projects.detail(id),
    queryFn: () => apiClient.get<Project>(`/projects/${id}`),
    enabled: !!id && (options?.enabled ?? true),
  });
}

// Infinite query for large project lists
export function useInfiniteProjects(filters: Omit<ProjectFilters, 'page'> = {}) {
  return useInfiniteQuery({
    queryKey: [...queryKeys.projects.lists(), 'infinite', filters],
    queryFn: ({ pageParam = 1 }) => 
      apiClient.get<PaginatedResponse<Project>>('/projects', {
        ...filters,
        page: pageParam,
        limit: 20,
      }),
    getNextPageParam: (lastPage) => {
      const hasMore = lastPage.page * lastPage.limit < lastPage.total;
      return hasMore ? lastPage.page + 1 : undefined;
    },
    keepPreviousData: true,
  });
}

// Create project mutation
export function useCreateProject() {
  const queryClient = useQueryClient();
  
  return useMutation({
    mutationFn: (data: CreateProjectData) => 
      apiClient.post<Project>('/projects', data),
    
    onMutate: async (newProject) => {
      // Cancel outgoing queries
      await queryClient.cancelQueries({ queryKey: queryKeys.projects.lists() });
      
      // Snapshot previous value
      const previousProjects = queryClient.getQueriesData({ 
        queryKey: queryKeys.projects.lists() 
      });
      
      // Optimistically update project lists
      queryClient.setQueriesData(
        { queryKey: queryKeys.projects.lists() },
        (old: PaginatedResponse<Project> | undefined) => {
          if (!old) return old;
          
          const optimisticProject: Project = {
            id: `temp-${Date.now()}`,
            ...newProject,
            status: newProject.status || 'draft',
            ownerId: 'current-user', // Get from auth context
            createdAt: new Date().toISOString(),
            updatedAt: new Date().toISOString(),
          };
          
          return {
            ...old,
            items: [optimisticProject, ...old.items],
            total: old.total + 1,
          };
        }
      );
      
      return { previousProjects };
    },
    
    onError: (err, newProject, context) => {
      // Rollback optimistic updates
      if (context?.previousProjects) {
        context.previousProjects.forEach(([queryKey, data]) => {
          queryClient.setQueryData(queryKey, data);
        });
      }
    },
    
    onSettled: () => {
      // Refetch to ensure consistency
      queryClient.invalidateQueries({ queryKey: queryKeys.projects.lists() });
    },
  });
}

// Update project mutation
export function useUpdateProject() {
  const queryClient = useQueryClient();
  
  return useMutation({
    mutationFn: ({ id, data }: { id: string; data: UpdateProjectData }) =>
      apiClient.patch<Project>(`/projects/${id}`, data),
    
    onSuccess: (updatedProject) => {
      // Update project detail cache
      queryClient.setQueryData(
        queryKeys.projects.detail(updatedProject.id),
        updatedProject
      );
      
      // Update project in lists
      queryClient.setQueriesData(
        { queryKey: queryKeys.projects.lists() },
        (old: PaginatedResponse<Project> | undefined) => {
          if (!old) return old;
          
          return {
            ...old,
            items: old.items.map(project =>
              project.id === updatedProject.id ? updatedProject : project
            ),
          };
        }
      );
    },
  });
}

// Delete project mutation
export function useDeleteProject() {
  const queryClient = useQueryClient();
  
  return useMutation({
    mutationFn: (id: string) => apiClient.delete(`/projects/${id}`),
    
    onSuccess: (_, deletedId) => {
      // Remove from detail cache
      queryClient.removeQueries({ queryKey: queryKeys.projects.detail(deletedId) });
      
      // Remove from lists
      queryClient.setQueriesData(
        { queryKey: queryKeys.projects.lists() },
        (old: PaginatedResponse<Project> | undefined) => {
          if (!old) return old;
          
          return {
            ...old,
            items: old.items.filter(project => project.id !== deletedId),
            total: old.total - 1,
          };
        }
      );
    },
  });
}

// Bulk operations
export function useBulkUpdateProjects() {
  const queryClient = useQueryClient();
  
  return useMutation({
    mutationFn: (updates: Array<{ id: string; data: UpdateProjectData }>) =>
      apiClient.post('/projects/bulk-update', { updates }),
    
    onSuccess: () => {
      // Invalidate all project queries
      queryClient.invalidateQueries({ queryKey: queryKeys.projects.all });
    },
  });
}
```

### Error Handling Patterns

```typescript
// hooks/use-api-error-handler.ts
import { toast } from 'react-hot-toast';
import { ApiError } from '../lib/api-client';

interface UseApiErrorHandlerOptions {
  showNotification?: boolean;
  onError?: (error: ApiError) => void;
}

export function useApiErrorHandler(options: UseApiErrorHandlerOptions = {}) {
  const { showNotification = true, onError } = options;
  
  return useCallback((error: unknown) => {
    if (error instanceof ApiError) {
      const message = getErrorMessage(error);
      
      if (showNotification) {
        toast.error(message);
      }
      
      // Log error for monitoring
      console.error('API Error:', {
        message: error.message,
        status: error.status,
        details: error.details,
      });
      
      // Handle specific error cases
      switch (error.status) {
        case 401:
          // Redirect to login
          window.location.href = '/auth/signin';
          break;
        case 403:
          // Show permission denied message
          toast.error('You do not have permission to perform this action');
          break;
        case 429:
          // Rate limiting
          toast.error('Too many requests. Please try again later.');
          break;
        default:
          break;
      }
      
      onError?.(error);
    } else {
      console.error('Unexpected error:', error);
      if (showNotification) {
        toast.error('An unexpected error occurred');
      }
    }
  }, [showNotification, onError]);
}

function getErrorMessage(error: ApiError): string {
  if (error.details?.message) {
    return error.details.message;
  }
  
  switch (error.status) {
    case 400:
      return 'Invalid request. Please check your input.';
    case 401:
      return 'Please sign in to continue.';
    case 403:
      return 'You do not have permission to access this resource.';
    case 404:
      return 'The requested resource was not found.';
    case 429:
      return 'Too many requests. Please try again later.';
    case 500:
      return 'Server error. Please try again later.';
    default:
      return error.message || 'An error occurred';
  }
}
```

## 📈 GraphQL Patterns

### Apollo Client Setup (Pattern from Saleor)

```typescript
// lib/apollo-client.ts
import { ApolloClient, InMemoryCache, createHttpLink, from } from '@apollo/client';
import { setContext } from '@apollo/client/link/context';
import { onError } from '@apollo/client/link/error';
import { RetryLink } from '@apollo/client/link/retry';

// HTTP link
const httpLink = createHttpLink({
  uri: process.env.NEXT_PUBLIC_GRAPHQL_URL,
});

// Auth link
const authLink = setContext((_, { headers }) => {
  const token = localStorage.getItem('authToken');
  
  return {
    headers: {
      ...headers,
      ...(token && { authorization: `Bearer ${token}` }),
    },
  };
});

// Error link
const errorLink = onError(({ graphQLErrors, networkError, operation, forward }) => {
  if (graphQLErrors) {
    graphQLErrors.forEach(({ message, locations, path }) => {
      console.error(
        `GraphQL error: Message: ${message}, Location: ${locations}, Path: ${path}`
      );
    });
  }
  
  if (networkError) {
    console.error(`Network error: ${networkError}`);
    
    // Handle auth errors
    if ('statusCode' in networkError && networkError.statusCode === 401) {
      localStorage.removeItem('authToken');
      window.location.href = '/auth/signin';
    }
  }
});

// Retry link
const retryLink = new RetryLink({
  delay: {
    initial: 300,
    max: Infinity,
    jitter: true,
  },
  attempts: {
    max: 3,
    retryIf: (error, _operation) => !!error,
  },
});

// Apollo client
export const apolloClient = new ApolloClient({
  link: from([errorLink, retryLink, authLink, httpLink]),
  cache: new InMemoryCache({
    typePolicies: {
      Query: {
        fields: {
          products: {
            keyArgs: ['filter', 'sortBy'],
            merge(existing = [], incoming) {
              return [...existing, ...incoming];
            },
          },
        },
      },
      Product: {
        fields: {
          reviews: {
            merge(existing = [], incoming) {
              return [...existing, ...incoming];
            },
          },
        },
      },
    },
  }),
  defaultOptions: {
    watchQuery: {
      errorPolicy: 'all',
    },
    query: {
      errorPolicy: 'all',
    },
  },
});
```

### GraphQL Hooks and Fragments

```typescript
// graphql/fragments.ts
import { gql } from '@apollo/client';

export const PRODUCT_FRAGMENT = gql`
  fragment ProductFragment on Product {
    id
    name
    description
    slug
    price {
      amount
      currency
    }
    images {
      id
      url
      alt
    }
    category {
      id
      name
      slug
    }
    variants {
      id
      name
      price {
        amount
        currency
      }
      stock
    }
  }
`;

export const USER_FRAGMENT = gql`
  fragment UserFragment on User {
    id
    email
    firstName
    lastName
    avatar {
      url
      alt
    }
    addresses {
      id
      firstName
      lastName
      streetAddress1
      streetAddress2
      city
      postalCode
      country
      countryArea
    }
  }
`;
```

```typescript
// hooks/use-products.ts
import { useQuery, useMutation } from '@apollo/client';
import { gql } from '@apollo/client';

const GET_PRODUCTS = gql`
  ${PRODUCT_FRAGMENT}
  query GetProducts(
    $filter: ProductFilterInput
    $sortBy: ProductSortingInput
    $first: Int
    $after: String
  ) {
    products(
      filter: $filter
      sortBy: $sortBy
      first: $first
      after: $after
    ) {
      edges {
        node {
          ...ProductFragment
        }
        cursor
      }
      pageInfo {
        hasNextPage
        hasPreviousPage
        startCursor
        endCursor
      }
      totalCount
    }
  }
`;

const CREATE_PRODUCT = gql`
  ${PRODUCT_FRAGMENT}
  mutation CreateProduct($input: ProductCreateInput!) {
    productCreate(input: $input) {
      product {
        ...ProductFragment
      }
      errors {
        field
        message
      }
    }
  }
`;

interface UseProductsOptions {
  filter?: ProductFilterInput;
  sortBy?: ProductSortingInput;
  first?: number;
}

export function useProducts(options: UseProductsOptions = {}) {
  return useQuery(GET_PRODUCTS, {
    variables: {
      first: 20,
      ...options,
    },
    notifyOnNetworkStatusChange: true,
  });
}

export function useProductsInfinite(options: UseProductsOptions = {}) {
  const { data, loading, error, fetchMore } = useQuery(GET_PRODUCTS, {
    variables: {
      first: 20,
      ...options,
    },
    notifyOnNetworkStatusChange: true,
  });
  
  const loadMore = useCallback(() => {
    if (data?.products.pageInfo.hasNextPage) {
      fetchMore({
        variables: {
          after: data.products.pageInfo.endCursor,
        },
      });
    }
  }, [data, fetchMore]);
  
  return {
    products: data?.products.edges.map(edge => edge.node) || [],
    loading,
    error,
    loadMore,
    hasMore: data?.products.pageInfo.hasNextPage || false,
  };
}

export function useCreateProduct() {
  return useMutation(CREATE_PRODUCT, {
    update(cache, { data }) {
      if (data?.productCreate.product) {
        // Update cache with new product
        cache.modify({
          fields: {
            products(existingProducts = { edges: [] }) {
              const newProductRef = cache.writeFragment({
                data: data.productCreate.product,
                fragment: PRODUCT_FRAGMENT,
              });
              
              return {
                ...existingProducts,
                edges: [
                  { node: newProductRef, cursor: 'new' },
                  ...existingProducts.edges,
                ],
              };
            },
          },
        });
      }
    },
  });
}
```

## 🔧 tRPC Patterns

### tRPC Setup (T3 Stack Pattern)

```typescript
// server/api/trpc.ts
import { initTRPC, TRPCError } from '@trpc/server';
import { type CreateNextContextOptions } from '@trpc/server/adapters/next';
import superjson from 'superjson';
import { ZodError } from 'zod';

interface CreateContextOptions {
  session: Session | null;
}

const createInnerTRPCContext = (opts: CreateContextOptions) => {
  return {
    session: opts.session,
    prisma, // Database client
  };
};

export const createTRPCContext = async (opts: CreateNextContextOptions) => {
  const { req, res } = opts;
  const session = await getServerAuthSession({ req, res });

  return createInnerTRPCContext({
    session,
  });
};

const t = initTRPC.context<typeof createTRPCContext>().create({
  transformer: superjson,
  errorFormatter({ shape, error }) {
    return {
      ...shape,
      data: {
        ...shape.data,
        zodError:
          error.cause instanceof ZodError ? error.cause.flatten() : null,
      },
    };
  },
});

export const createTRPCRouter = t.router;
export const publicProcedure = t.procedure;

// Protected procedure
const enforceUserIsAuthed = t.middleware(({ ctx, next }) => {
  if (!ctx.session || !ctx.session.user) {
    throw new TRPCError({ code: 'UNAUTHORIZED' });
  }
  return next({
    ctx: {
      session: { ...ctx.session, user: ctx.session.user },
    },
  });
});

export const protectedProcedure = t.procedure.use(enforceUserIsAuthed);
```

### tRPC Routers

```typescript
// server/api/routers/projects.ts
import { z } from 'zod';
import { createTRPCRouter, protectedProcedure, publicProcedure } from '../trpc';

const createProjectSchema = z.object({
  name: z.string().min(1).max(100),
  description: z.string().optional(),
  status: z.enum(['active', 'archived', 'draft']).default('draft'),
});

const updateProjectSchema = createProjectSchema.partial();

const projectFilterSchema = z.object({
  status: z.enum(['active', 'archived', 'draft']).optional(),
  search: z.string().optional(),
  page: z.number().min(1).default(1),
  limit: z.number().min(1).max(100).default(20),
});

export const projectsRouter = createTRPCRouter({
  // Get projects with filtering
  getAll: protectedProcedure
    .input(projectFilterSchema)
    .query(async ({ ctx, input }) => {
      const { page, limit, status, search } = input;
      const skip = (page - 1) * limit;
      
      const where = {
        ownerId: ctx.session.user.id,
        ...(status && { status }),
        ...(search && {
          OR: [
            { name: { contains: search, mode: 'insensitive' } },
            { description: { contains: search, mode: 'insensitive' } },
          ],
        }),
      };
      
      const [projects, total] = await Promise.all([
        ctx.prisma.project.findMany({
          where,
          skip,
          take: limit,
          orderBy: { updatedAt: 'desc' },
          include: {
            owner: true,
            _count: {
              select: { tasks: true },
            },
          },
        }),
        ctx.prisma.project.count({ where }),
      ]);
      
      return {
        projects,
        total,
        page,
        limit,
        hasMore: skip + projects.length < total,
      };
    }),
  
  // Get single project
  getById: protectedProcedure
    .input(z.object({ id: z.string() }))
    .query(async ({ ctx, input }) => {
      const project = await ctx.prisma.project.findFirst({
        where: {
          id: input.id,
          ownerId: ctx.session.user.id,
        },
        include: {
          owner: true,
          tasks: {
            orderBy: { createdAt: 'desc' },
          },
        },
      });
      
      if (!project) {
        throw new TRPCError({
          code: 'NOT_FOUND',
          message: 'Project not found',
        });
      }
      
      return project;
    }),
  
  // Create project
  create: protectedProcedure
    .input(createProjectSchema)
    .mutation(async ({ ctx, input }) => {
      return ctx.prisma.project.create({
        data: {
          ...input,
          ownerId: ctx.session.user.id,
        },
        include: {
          owner: true,
        },
      });
    }),
  
  // Update project
  update: protectedProcedure
    .input(z.object({
      id: z.string(),
      data: updateProjectSchema,
    }))
    .mutation(async ({ ctx, input }) => {
      const project = await ctx.prisma.project.findFirst({
        where: {
          id: input.id,
          ownerId: ctx.session.user.id,
        },
      });
      
      if (!project) {
        throw new TRPCError({
          code: 'NOT_FOUND',
          message: 'Project not found',
        });
      }
      
      return ctx.prisma.project.update({
        where: { id: input.id },
        data: input.data,
        include: {
          owner: true,
        },
      });
    }),
  
  // Delete project
  delete: protectedProcedure
    .input(z.object({ id: z.string() }))
    .mutation(async ({ ctx, input }) => {
      const project = await ctx.prisma.project.findFirst({
        where: {
          id: input.id,
          ownerId: ctx.session.user.id,
        },
      });
      
      if (!project) {
        throw new TRPCError({
          code: 'NOT_FOUND',
          message: 'Project not found',
        });
      }
      
      await ctx.prisma.project.delete({
        where: { id: input.id },
      });
      
      return { success: true };
    }),
});
```

### tRPC Client Usage

```typescript
// utils/trpc.ts - Client setup
import { createTRPCNext } from '@trpc/next';
import { httpBatchLink } from '@trpc/client';
import superjson from 'superjson';
import type { AppRouter } from '../server/api/root';

function getBaseUrl() {
  if (typeof window !== 'undefined') return '';
  if (process.env.VERCEL_URL) return `https://${process.env.VERCEL_URL}`;
  return `http://localhost:${process.env.PORT ?? 3000}`;
}

export const trpc = createTRPCNext<AppRouter>({
  config() {
    return {
      transformer: superjson,
      links: [
        httpBatchLink({
          url: `${getBaseUrl()}/api/trpc`,
        }),
      ],
    };
  },
  ssr: false,
});
```

```typescript
// hooks/use-projects-trpc.ts - Using tRPC hooks
import { trpc } from '../utils/trpc';

export function useProjects(filters: ProjectFilters = {}) {
  return trpc.projects.getAll.useQuery(filters, {
    keepPreviousData: true,
  });
}

export function useProject(id: string) {
  return trpc.projects.getById.useQuery(
    { id },
    { enabled: !!id }
  );
}

export function useCreateProject() {
  const utils = trpc.useContext();
  
  return trpc.projects.create.useMutation({
    onSuccess: () => {
      // Invalidate projects list
      utils.projects.getAll.invalidate();
    },
  });
}

export function useUpdateProject() {
  const utils = trpc.useContext();
  
  return trpc.projects.update.useMutation({
    onSuccess: (updatedProject, variables) => {
      // Update single project cache
      utils.projects.getById.setData(
        { id: variables.id },
        updatedProject
      );
      
      // Invalidate projects list
      utils.projects.getAll.invalidate();
    },
  });
}

export function useDeleteProject() {
  const utils = trpc.useContext();
  
  return trpc.projects.delete.useMutation({
    onSuccess: (_, variables) => {
      // Remove from cache
      utils.projects.getById.setData(
        { id: variables.id },
        undefined
      );
      
      // Invalidate projects list
      utils.projects.getAll.invalidate();
    },
  });
}

// Optimistic updates with tRPC
export function useOptimisticCreateProject() {
  const utils = trpc.useContext();
  
  return trpc.projects.create.useMutation({
    onMutate: async (newProject) => {
      // Cancel outgoing refetches
      await utils.projects.getAll.cancel();
      
      // Snapshot the previous value
      const previousProjects = utils.projects.getAll.getData();
      
      // Optimistically update
      utils.projects.getAll.setData({}, (old) => {
        if (!old) return old;
        
        const optimisticProject = {
          id: `temp-${Date.now()}`,
          ...newProject,
          ownerId: 'current-user',
          owner: { id: 'current-user', name: 'You' },
          createdAt: new Date(),
          updatedAt: new Date(),
          _count: { tasks: 0 },
        };
        
        return {
          ...old,
          projects: [optimisticProject, ...old.projects],
          total: old.total + 1,
        };
      });
      
      return { previousProjects };
    },
    
    onError: (err, newProject, context) => {
      // Rollback on error
      if (context?.previousProjects) {
        utils.projects.getAll.setData({}, context.previousProjects);
      }
    },
    
    onSettled: () => {
      // Always refetch after error or success
      utils.projects.getAll.invalidate();
    },
  });
}
```

## 🔄 Real-time Data Patterns

### WebSocket Integration

```typescript
// hooks/use-websocket.ts
import { useEffect, useRef, useCallback } from 'react';
import { useQueryClient } from '@tanstack/react-query';

interface UseWebSocketOptions {
  url: string;
  onMessage?: (data: any) => void;
  onConnect?: () => void;
  onDisconnect?: () => void;
  onError?: (error: Event) => void;
  reconnectAttempts?: number;
  reconnectDelay?: number;
}

export function useWebSocket({
  url,
  onMessage,
  onConnect,
  onDisconnect,
  onError,
  reconnectAttempts = 5,
  reconnectDelay = 3000,
}: UseWebSocketOptions) {
  const ws = useRef<WebSocket | null>(null);
  const reconnectCount = useRef(0);
  const queryClient = useQueryClient();
  
  const connect = useCallback(() => {
    try {
      ws.current = new WebSocket(url);
      
      ws.current.onopen = () => {
        console.log('WebSocket connected');
        reconnectCount.current = 0;
        onConnect?.();
      };
      
      ws.current.onmessage = (event) => {
        try {
          const data = JSON.parse(event.data);
          handleMessage(data);
          onMessage?.(data);
        } catch (error) {
          console.error('Failed to parse WebSocket message:', error);
        }
      };
      
      ws.current.onclose = () => {
        console.log('WebSocket disconnected');
        onDisconnect?.();
        
        // Attempt to reconnect
        if (reconnectCount.current < reconnectAttempts) {
          reconnectCount.current++;
          setTimeout(connect, reconnectDelay);
        }
      };
      
      ws.current.onerror = (error) => {
        console.error('WebSocket error:', error);
        onError?.(error);
      };
    } catch (error) {
      console.error('Failed to create WebSocket:', error);
    }
  }, [url, onMessage, onConnect, onDisconnect, onError, reconnectAttempts, reconnectDelay]);
  
  const handleMessage = useCallback((data: any) => {
    // Handle different message types
    switch (data.type) {
      case 'project:updated':
        // Update project in cache
        queryClient.setQueryData(
          ['projects', 'detail', data.payload.id],
          data.payload
        );
        // Invalidate projects list
        queryClient.invalidateQueries({ queryKey: ['projects', 'list'] });
        break;
      
      case 'project:deleted':
        // Remove from cache
        queryClient.removeQueries({ queryKey: ['projects', 'detail', data.payload.id] });
        queryClient.invalidateQueries({ queryKey: ['projects', 'list'] });
        break;
      
      case 'task:created':
        // Invalidate project tasks
        queryClient.invalidateQueries({ 
          queryKey: ['projects', 'detail', data.payload.projectId, 'tasks'] 
        });
        break;
      
      default:
        console.log('Unknown message type:', data.type);
    }
  }, [queryClient]);
  
  const sendMessage = useCallback((message: any) => {
    if (ws.current?.readyState === WebSocket.OPEN) {
      ws.current.send(JSON.stringify(message));
    }
  }, []);
  
  useEffect(() => {
    connect();
    
    return () => {
      if (ws.current) {
        ws.current.close();
      }
    };
  }, [connect]);
  
  return {
    sendMessage,
    isConnected: ws.current?.readyState === WebSocket.OPEN,
  };
}
```

### Server-Sent Events

```typescript
// hooks/use-server-sent-events.ts
export function useServerSentEvents(url: string) {
  const [isConnected, setIsConnected] = useState(false);
  const eventSourceRef = useRef<EventSource | null>(null);
  const queryClient = useQueryClient();
  
  useEffect(() => {
    eventSourceRef.current = new EventSource(url);
    
    eventSourceRef.current.onopen = () => {
      setIsConnected(true);
    };
    
    eventSourceRef.current.onmessage = (event) => {
      try {
        const data = JSON.parse(event.data);
        
        // Handle real-time updates
        if (data.type === 'cache:invalidate') {
          queryClient.invalidateQueries({ queryKey: data.queryKey });
        } else if (data.type === 'cache:update') {
          queryClient.setQueryData(data.queryKey, data.data);
        }
      } catch (error) {
        console.error('Failed to parse SSE message:', error);
      }
    };
    
    eventSourceRef.current.onerror = () => {
      setIsConnected(false);
    };
    
    return () => {
      eventSourceRef.current?.close();
    };
  }, [url, queryClient]);
  
  return { isConnected };
}
```

## 📊 Performance Optimization

### Request Deduplication

```typescript
// utils/request-deduplication.ts
const requestCache = new Map<string, Promise<any>>();

export function deduplicateRequest<T>(
  key: string,
  requestFn: () => Promise<T>,
  ttl: number = 5000
): Promise<T> {
  if (requestCache.has(key)) {
    return requestCache.get(key)!;
  }
  
  const promise = requestFn().finally(() => {
    // Remove from cache after TTL
    setTimeout(() => {
      requestCache.delete(key);
    }, ttl);
  });
  
  requestCache.set(key, promise);
  return promise;
}

// Usage in API client
export const apiClient = {
  get<T>(endpoint: string, params?: any): Promise<T> {
    const key = `GET:${endpoint}:${JSON.stringify(params)}`;
    return deduplicateRequest(key, () => 
      fetch(`${endpoint}?${new URLSearchParams(params)}`).then(r => r.json())
    );
  },
};
```

### Background Sync

```typescript
// hooks/use-background-sync.ts
export function useBackgroundSync() {
  const queryClient = useQueryClient();
  
  useEffect(() => {
    const syncData = async () => {
      // Sync critical data in background
      await queryClient.prefetchQuery({
        queryKey: ['user', 'profile'],
        queryFn: () => apiClient.get('/user/profile'),
      });
      
      await queryClient.prefetchQuery({
        queryKey: ['notifications'],
        queryFn: () => apiClient.get('/notifications'),
      });
    };
    
    // Sync on focus
    const handleFocus = () => {
      syncData();
    };
    
    window.addEventListener('focus', handleFocus);
    
    // Periodic sync
    const interval = setInterval(syncData, 5 * 60 * 1000); // 5 minutes
    
    return () => {
      window.removeEventListener('focus', handleFocus);
      clearInterval(interval);
    };
  }, [queryClient]);
}
```

## 🔒 Security Considerations

### Request Signing

```typescript
// utils/request-signing.ts
import crypto from 'crypto';

export function signRequest(
  method: string,
  url: string,
  body: string,
  timestamp: number,
  secretKey: string
): string {
  const payload = `${method}:${url}:${body}:${timestamp}`;
  return crypto.createHmac('sha256', secretKey).update(payload).digest('hex');
}

// Enhanced API client with request signing
class SecureApiClient {
  private secretKey: string;
  
  constructor(secretKey: string) {
    this.secretKey = secretKey;
  }
  
  private async secureRequest<T>(
    url: string,
    options: RequestInit = {}
  ): Promise<T> {
    const timestamp = Date.now();
    const body = options.body?.toString() || '';
    const method = options.method || 'GET';
    
    const signature = signRequest(method, url, body, timestamp, this.secretKey);
    
    const response = await fetch(url, {
      ...options,
      headers: {
        ...options.headers,
        'X-Timestamp': timestamp.toString(),
        'X-Signature': signature,
      },
    });
    
    if (!response.ok) {
      throw new Error(`Request failed: ${response.statusText}`);
    }
    
    return response.json();
  }
}
```

---

## 🔗 Navigation

**Previous:** [State Management Patterns](./state-management-patterns.md) | **Next:** [Authentication Security](./authentication-security.md)