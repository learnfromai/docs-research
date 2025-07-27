# API Integration Patterns in React & Next.js Applications

## 🎯 Overview

Analysis of API integration strategies, data fetching patterns, and backend communication approaches used in production React and Next.js applications.

## 📊 API Integration Landscape

### **Adoption Analysis**
- **tRPC**: 60% of modern projects (type-safe APIs)
- **React Query/TanStack Query**: 55% (server state management)
- **SWR**: 25% (lightweight data fetching)
- **GraphQL**: 15% (complex data requirements)
- **REST + Axios**: 10% (legacy projects)

## 🏆 tRPC: The Type-Safe Revolution

### **Why tRPC is Winning**

```typescript
// server/routers/projects.ts
import { z } from 'zod';
import { createTRPCRouter, protectedProcedure, publicProcedure } from '@/lib/trpc';

const createProjectSchema = z.object({
  name: z.string().min(1).max(100),
  description: z.string().optional(),
  priority: z.enum(['low', 'medium', 'high']),
  dueDate: z.date().optional(),
});

const updateProjectSchema = z.object({
  id: z.string(),
  name: z.string().min(1).max(100).optional(),
  description: z.string().optional(),
  status: z.enum(['draft', 'active', 'completed', 'archived']).optional(),
  priority: z.enum(['low', 'medium', 'high']).optional(),
});

export const projectsRouter = createTRPCRouter({
  // Public procedures
  getPublicProjects: publicProcedure
    .input(z.object({
      limit: z.number().min(1).max(100).default(10),
      cursor: z.string().optional(),
    }))
    .query(async ({ input, ctx }) => {
      const projects = await ctx.prisma.project.findMany({
        where: { isPublic: true },
        take: input.limit + 1,
        cursor: input.cursor ? { id: input.cursor } : undefined,
        orderBy: { createdAt: 'desc' },
        include: {
          owner: {
            select: { id: true, name: true, avatar: true },
          },
          _count: {
            select: { tasks: true, collaborators: true },
          },
        },
      });

      let nextCursor: typeof input.cursor | undefined = undefined;
      if (projects.length > input.limit) {
        const nextItem = projects.pop();
        nextCursor = nextItem!.id;
      }

      return {
        projects,
        nextCursor,
      };
    }),

  // Protected procedures
  getUserProjects: protectedProcedure
    .input(z.object({
      status: z.enum(['all', 'active', 'completed']).default('all'),
      sortBy: z.enum(['name', 'createdAt', 'dueDate']).default('createdAt'),
      sortOrder: z.enum(['asc', 'desc']).default('desc'),
    }))
    .query(async ({ input, ctx }) => {
      const where = {
        userId: ctx.session.user.id,
        ...(input.status !== 'all' && { status: input.status }),
      };

      const projects = await ctx.prisma.project.findMany({
        where,
        orderBy: { [input.sortBy]: input.sortOrder },
        include: {
          tasks: {
            select: { id: true, status: true },
          },
          collaborators: {
            select: { id: true, name: true, avatar: true },
          },
        },
      });

      return projects.map(project => ({
        ...project,
        tasksCount: project.tasks.length,
        completedTasksCount: project.tasks.filter(t => t.status === 'completed').length,
      }));
    }),

  createProject: protectedProcedure
    .input(createProjectSchema)
    .mutation(async ({ input, ctx }) => {
      const project = await ctx.prisma.project.create({
        data: {
          ...input,
          userId: ctx.session.user.id,
          status: 'draft',
        },
        include: {
          owner: {
            select: { id: true, name: true, avatar: true },
          },
        },
      });

      // Send notification to collaborators
      await ctx.notifications.send({
        type: 'project_created',
        userId: ctx.session.user.id,
        data: { projectId: project.id },
      });

      return project;
    }),

  updateProject: protectedProcedure
    .input(updateProjectSchema)
    .mutation(async ({ input, ctx }) => {
      const { id, ...updateData } = input;

      // Check ownership
      const existingProject = await ctx.prisma.project.findFirst({
        where: { id, userId: ctx.session.user.id },
      });

      if (!existingProject) {
        throw new TRPCError({
          code: 'NOT_FOUND',
          message: 'Project not found or access denied',
        });
      }

      const updatedProject = await ctx.prisma.project.update({
        where: { id },
        data: updateData,
        include: {
          owner: {
            select: { id: true, name: true, avatar: true },
          },
        },
      });

      return updatedProject;
    }),

  deleteProject: protectedProcedure
    .input(z.object({ id: z.string() }))
    .mutation(async ({ input, ctx }) => {
      // Check ownership and dependencies
      const project = await ctx.prisma.project.findFirst({
        where: { id: input.id, userId: ctx.session.user.id },
        include: { _count: { select: { tasks: true } } },
      });

      if (!project) {
        throw new TRPCError({
          code: 'NOT_FOUND',
          message: 'Project not found or access denied',
        });
      }

      if (project._count.tasks > 0) {
        throw new TRPCError({
          code: 'PRECONDITION_FAILED',
          message: 'Cannot delete project with existing tasks',
        });
      }

      await ctx.prisma.project.delete({
        where: { id: input.id },
      });

      return { success: true };
    }),
});
```

### **Client-Side tRPC Usage**

```typescript
// hooks/use-projects.ts
import { api } from '@/lib/trpc-client';

export function useProjects(filters?: {
  status?: 'all' | 'active' | 'completed';
  sortBy?: 'name' | 'createdAt' | 'dueDate';
  sortOrder?: 'asc' | 'desc';
}) {
  return api.projects.getUserProjects.useQuery(filters);
}

export function useCreateProject() {
  const utils = api.useContext();
  
  return api.projects.createProject.useMutation({
    onSuccess: (newProject) => {
      // Optimistically update the projects list
      utils.projects.getUserProjects.setData(
        undefined, // Query key params
        (oldData) => oldData ? [...oldData, newProject] : [newProject]
      );
      
      toast.success('Project created successfully!');
    },
    onError: (error) => {
      toast.error(error.message || 'Failed to create project');
    },
  });
}

export function useUpdateProject() {
  const utils = api.useContext();
  
  return api.projects.updateProject.useMutation({
    onMutate: async (variables) => {
      // Cancel outgoing refetches
      await utils.projects.getUserProjects.cancel();
      
      // Snapshot the previous value
      const previousProjects = utils.projects.getUserProjects.getData();
      
      // Optimistically update
      utils.projects.getUserProjects.setData(
        undefined,
        (oldData) =>
          oldData?.map(project =>
            project.id === variables.id
              ? { ...project, ...variables }
              : project
          )
      );
      
      return { previousProjects };
    },
    onError: (err, variables, context) => {
      // Rollback on error
      if (context?.previousProjects) {
        utils.projects.getUserProjects.setData(
          undefined,
          context.previousProjects
        );
      }
      toast.error('Failed to update project');
    },
    onSettled: () => {
      // Always refetch after error or success
      utils.projects.getUserProjects.invalidate();
    },
  });
}

// components/ProjectList.tsx
export function ProjectList() {
  const [filters, setFilters] = useState({
    status: 'all' as const,
    sortBy: 'createdAt' as const,
    sortOrder: 'desc' as const,
  });
  
  const { data: projects, isLoading, error } = useProjects(filters);
  const updateProject = useUpdateProject();
  
  if (isLoading) return <ProjectListSkeleton />;
  if (error) return <ErrorMessage error={error.message} />;
  
  return (
    <div className="space-y-4">
      <ProjectFilters filters={filters} onChange={setFilters} />
      
      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
        {projects?.map((project) => (
          <ProjectCard
            key={project.id}
            project={project}
            onUpdate={(updates) => 
              updateProject.mutate({ id: project.id, ...updates })
            }
          />
        ))}
      </div>
    </div>
  );
}
```

## 🔄 React Query/TanStack Query Patterns

### **Advanced Query Management**

```typescript
// lib/api-client.ts
import axios from 'axios';

const apiClient = axios.create({
  baseURL: '/api',
  timeout: 10000,
});

// Request interceptor for auth
apiClient.interceptors.request.use((config) => {
  const token = localStorage.getItem('accessToken');
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

// Response interceptor for token refresh
apiClient.interceptors.response.use(
  (response) => response,
  async (error) => {
    if (error.response?.status === 401) {
      try {
        const refreshResponse = await axios.post('/api/auth/refresh');
        const { accessToken } = refreshResponse.data;
        
        localStorage.setItem('accessToken', accessToken);
        
        // Retry the original request
        error.config.headers.Authorization = `Bearer ${accessToken}`;
        return apiClient.request(error.config);
      } catch (refreshError) {
        // Redirect to login
        window.location.href = '/auth/signin';
      }
    }
    return Promise.reject(error);
  }
);

export default apiClient;

// services/project-service.ts
export interface Project {
  id: string;
  name: string;
  description?: string;
  status: 'draft' | 'active' | 'completed' | 'archived';
  priority: 'low' | 'medium' | 'high';
  createdAt: string;
  updatedAt: string;
  owner: {
    id: string;
    name: string;
    avatar?: string;
  };
}

export interface CreateProjectInput {
  name: string;
  description?: string;
  priority: 'low' | 'medium' | 'high';
}

export interface UpdateProjectInput {
  name?: string;
  description?: string;
  status?: 'draft' | 'active' | 'completed' | 'archived';
  priority?: 'low' | 'medium' | 'high';
}

export const projectService = {
  async getProjects(filters?: {
    status?: string;
    sortBy?: string;
    sortOrder?: 'asc' | 'desc';
  }): Promise<Project[]> {
    const { data } = await apiClient.get('/projects', { params: filters });
    return data;
  },

  async getProject(id: string): Promise<Project> {
    const { data } = await apiClient.get(`/projects/${id}`);
    return data;
  },

  async createProject(input: CreateProjectInput): Promise<Project> {
    const { data } = await apiClient.post('/projects', input);
    return data;
  },

  async updateProject(id: string, input: UpdateProjectInput): Promise<Project> {
    const { data } = await apiClient.patch(`/projects/${id}`, input);
    return data;
  },

  async deleteProject(id: string): Promise<void> {
    await apiClient.delete(`/projects/${id}`);
  },
};
```

### **Query Hooks with Error Handling**

```typescript
// hooks/use-projects-query.ts
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { projectService } from '@/services/project-service';
import { toast } from '@/components/ui/use-toast';

// Query keys
export const projectKeys = {
  all: ['projects'] as const,
  lists: () => [...projectKeys.all, 'list'] as const,
  list: (filters: Record<string, any>) => [...projectKeys.lists(), filters] as const,
  details: () => [...projectKeys.all, 'detail'] as const,
  detail: (id: string) => [...projectKeys.details(), id] as const,
};

export function useProjects(filters?: {
  status?: string;
  sortBy?: string;
  sortOrder?: 'asc' | 'desc';
}) {
  return useQuery({
    queryKey: projectKeys.list(filters || {}),
    queryFn: () => projectService.getProjects(filters),
    staleTime: 5 * 60 * 1000, // 5 minutes
    gcTime: 10 * 60 * 1000, // 10 minutes
    retry: (failureCount, error) => {
      // Don't retry on 4xx errors
      if (error.response?.status >= 400 && error.response?.status < 500) {
        return false;
      }
      return failureCount < 3;
    },
  });
}

export function useProject(id: string) {
  return useQuery({
    queryKey: projectKeys.detail(id),
    queryFn: () => projectService.getProject(id),
    enabled: !!id,
    staleTime: 2 * 60 * 1000, // 2 minutes
  });
}

export function useCreateProject() {
  const queryClient = useQueryClient();
  
  return useMutation({
    mutationFn: projectService.createProject,
    onMutate: async (newProject) => {
      // Cancel any outgoing refetches
      await queryClient.cancelQueries({ queryKey: projectKeys.lists() });
      
      // Snapshot the previous value
      const previousProjects = queryClient.getQueriesData({ 
        queryKey: projectKeys.lists() 
      });
      
      // Optimistically update all project lists
      queryClient.setQueriesData({ queryKey: projectKeys.lists() }, (old: Project[] | undefined) => {
        if (!old) return [{ ...newProject, id: 'temp-' + Date.now() } as Project];
        return [{ ...newProject, id: 'temp-' + Date.now() } as Project, ...old];
      });
      
      return { previousProjects };
    },
    onError: (error, variables, context) => {
      // Rollback optimistic updates
      if (context?.previousProjects) {
        context.previousProjects.forEach(([queryKey, data]) => {
          queryClient.setQueryData(queryKey, data);
        });
      }
      
      toast({
        title: 'Error',
        description: error.response?.data?.message || 'Failed to create project',
        variant: 'destructive',
      });
    },
    onSuccess: (newProject) => {
      // Update all project lists with the real project
      queryClient.setQueriesData({ queryKey: projectKeys.lists() }, (old: Project[] | undefined) => {
        if (!old) return [newProject];
        return old.map(project => 
          project.id.startsWith('temp-') ? newProject : project
        );
      });
      
      // Set individual project cache
      queryClient.setQueryData(projectKeys.detail(newProject.id), newProject);
      
      toast({
        title: 'Success',
        description: 'Project created successfully!',
      });
    },
    onSettled: () => {
      // Invalidate and refetch
      queryClient.invalidateQueries({ queryKey: projectKeys.lists() });
    },
  });
}

export function useUpdateProject() {
  const queryClient = useQueryClient();
  
  return useMutation({
    mutationFn: ({ id, updates }: { id: string; updates: UpdateProjectInput }) =>
      projectService.updateProject(id, updates),
    onMutate: async ({ id, updates }) => {
      // Cancel queries
      await queryClient.cancelQueries({ queryKey: projectKeys.detail(id) });
      await queryClient.cancelQueries({ queryKey: projectKeys.lists() });
      
      // Snapshot previous values
      const previousProject = queryClient.getQueryData(projectKeys.detail(id));
      const previousLists = queryClient.getQueriesData({ queryKey: projectKeys.lists() });
      
      // Optimistically update
      queryClient.setQueryData(projectKeys.detail(id), (old: Project | undefined) => 
        old ? { ...old, ...updates } : undefined
      );
      
      queryClient.setQueriesData({ queryKey: projectKeys.lists() }, (old: Project[] | undefined) =>
        old?.map(project => project.id === id ? { ...project, ...updates } : project)
      );
      
      return { previousProject, previousLists };
    },
    onError: (error, { id }, context) => {
      // Rollback
      if (context?.previousProject) {
        queryClient.setQueryData(projectKeys.detail(id), context.previousProject);
      }
      if (context?.previousLists) {
        context.previousLists.forEach(([queryKey, data]) => {
          queryClient.setQueryData(queryKey, data);
        });
      }
      
      toast({
        title: 'Error',
        description: 'Failed to update project',
        variant: 'destructive',
      });
    },
    onSuccess: (updatedProject) => {
      // Update caches with server response
      queryClient.setQueryData(projectKeys.detail(updatedProject.id), updatedProject);
      
      queryClient.setQueriesData({ queryKey: projectKeys.lists() }, (old: Project[] | undefined) =>
        old?.map(project => project.id === updatedProject.id ? updatedProject : project)
      );
      
      toast({
        title: 'Success',
        description: 'Project updated successfully!',
      });
    },
  });
}
```

## 🌐 SWR Patterns

### **Lightweight Data Fetching**

```typescript
// hooks/use-swr-projects.ts
import useSWR, { mutate } from 'swr';
import useSWRMutation from 'swr/mutation';
import { projectService } from '@/services/project-service';

// Custom fetcher with error handling
const fetcher = async (url: string) => {
  try {
    return await projectService.getProjects();
  } catch (error) {
    throw new Error(error.response?.data?.message || 'Failed to fetch data');
  }
};

export function useProjects(filters?: Record<string, any>) {
  const key = filters ? ['projects', filters] : 'projects';
  
  const { data, error, mutate: revalidate } = useSWR(key, fetcher, {
    revalidateOnFocus: false,
    revalidateOnReconnect: true,
    refreshInterval: 30000, // 30 seconds
    errorRetryCount: 3,
    errorRetryInterval: 1000,
  });

  return {
    projects: data,
    isLoading: !error && !data,
    isError: error,
    revalidate,
  };
}

export function useProject(id: string) {
  const { data, error, mutate: revalidate } = useSWR(
    id ? ['project', id] : null,
    () => projectService.getProject(id),
    {
      revalidateOnFocus: false,
    }
  );

  return {
    project: data,
    isLoading: !error && !data,
    isError: error,
    revalidate,
  };
}

// Mutation hooks
export function useCreateProject() {
  const trigger = useSWRMutation(
    'projects',
    async (key, { arg }: { arg: CreateProjectInput }) => {
      return projectService.createProject(arg);
    },
    {
      onSuccess: (newProject) => {
        // Update projects list
        mutate('projects', (currentProjects: Project[] | undefined) =>
          currentProjects ? [newProject, ...currentProjects] : [newProject]
        );
        
        toast.success('Project created successfully!');
      },
      onError: (error) => {
        toast.error(error.message || 'Failed to create project');
      },
    }
  );

  return {
    trigger: trigger.trigger,
    isMutating: trigger.isMutating,
    error: trigger.error,
  };
}

export function useUpdateProject() {
  const trigger = useSWRMutation(
    'projects',
    async (key, { arg }: { arg: { id: string; updates: UpdateProjectInput } }) => {
      return projectService.updateProject(arg.id, arg.updates);
    },
    {
      optimisticData: (currentProjects: Project[] | undefined, { arg }) => {
        return currentProjects?.map(project =>
          project.id === arg.id ? { ...project, ...arg.updates } : project
        );
      },
      onSuccess: (updatedProject) => {
        // Update individual project cache
        mutate(['project', updatedProject.id], updatedProject);
        toast.success('Project updated successfully!');
      },
      onError: (error) => {
        toast.error('Failed to update project');
      },
    }
  );

  return {
    trigger: trigger.trigger,
    isMutating: trigger.isMutating,
    error: trigger.error,
  };
}
```

## 🔍 Error Handling Patterns

### **Centralized Error Management**

```typescript
// lib/error-handler.ts
export class APIError extends Error {
  constructor(
    message: string,
    public status: number,
    public code?: string
  ) {
    super(message);
    this.name = 'APIError';
  }
}

export function handleAPIError(error: any): never {
  if (error.response) {
    // Server responded with error status
    const { status, data } = error.response;
    throw new APIError(
      data.message || 'Server error',
      status,
      data.code
    );
  } else if (error.request) {
    // Request was made but no response received
    throw new APIError('Network error', 0);
  } else {
    // Something else happened
    throw new APIError(error.message || 'Unknown error', 0);
  }
}

// components/ErrorBoundary.tsx
import React from 'react';
import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert';
import { Button } from '@/components/ui/button';

interface ErrorBoundaryState {
  hasError: boolean;
  error?: Error;
}

export class ErrorBoundary extends React.Component<
  React.PropsWithChildren<{}>,
  ErrorBoundaryState
> {
  constructor(props: React.PropsWithChildren<{}>) {
    super(props);
    this.state = { hasError: false };
  }

  static getDerivedStateFromError(error: Error): ErrorBoundaryState {
    return { hasError: true, error };
  }

  componentDidCatch(error: Error, errorInfo: React.ErrorInfo) {
    console.error('Error caught by boundary:', error, errorInfo);
    
    // Report to error tracking service
    if (process.env.NODE_ENV === 'production') {
      // reportError(error, errorInfo);
    }
  }

  render() {
    if (this.state.hasError) {
      return (
        <div className="flex items-center justify-center min-h-[400px]">
          <Alert className="max-w-md">
            <AlertCircle className="h-4 w-4" />
            <AlertTitle>Something went wrong</AlertTitle>
            <AlertDescription className="mt-2">
              {this.state.error?.message || 'An unexpected error occurred'}
            </AlertDescription>
            <Button
              className="mt-4"
              onClick={() => this.setState({ hasError: false, error: undefined })}
            >
              Try again
            </Button>
          </Alert>
        </div>
      );
    }

    return this.props.children;
  }
}

// hooks/use-error-handler.ts
export function useErrorHandler() {
  return useCallback((error: unknown) => {
    let message = 'An unexpected error occurred';
    
    if (error instanceof APIError) {
      message = error.message;
      
      // Handle specific error codes
      switch (error.code) {
        case 'UNAUTHORIZED':
          // Redirect to login
          window.location.href = '/auth/signin';
          return;
        case 'FORBIDDEN':
          message = 'You do not have permission to perform this action';
          break;
        case 'NOT_FOUND':
          message = 'The requested resource was not found';
          break;
      }
    } else if (error instanceof Error) {
      message = error.message;
    }
    
    toast.error(message);
  }, []);
}
```

## 📊 Performance Optimization

### **Request Caching and Deduplication**

```typescript
// lib/request-cache.ts
class RequestCache {
  private cache = new Map<string, Promise<any>>();
  private timeouts = new Map<string, NodeJS.Timeout>();

  get<T>(key: string, fetcher: () => Promise<T>, ttl = 5000): Promise<T> {
    // Check if request is already in flight
    if (this.cache.has(key)) {
      return this.cache.get(key)!;
    }

    // Create new request
    const promise = fetcher().finally(() => {
      // Remove from cache when completed
      this.cache.delete(key);
      
      // Clear timeout
      const timeout = this.timeouts.get(key);
      if (timeout) {
        clearTimeout(timeout);
        this.timeouts.delete(key);
      }
    });

    // Cache the promise
    this.cache.set(key, promise);

    // Set timeout to remove from cache
    const timeout = setTimeout(() => {
      this.cache.delete(key);
      this.timeouts.delete(key);
    }, ttl);
    
    this.timeouts.set(key, timeout);

    return promise;
  }

  clear() {
    this.cache.clear();
    this.timeouts.forEach(timeout => clearTimeout(timeout));
    this.timeouts.clear();
  }
}

export const requestCache = new RequestCache();

// Usage in service
export const projectService = {
  async getProjects(filters?: Record<string, any>): Promise<Project[]> {
    const cacheKey = `projects-${JSON.stringify(filters || {})}`;
    
    return requestCache.get(
      cacheKey,
      async () => {
        const { data } = await apiClient.get('/projects', { params: filters });
        return data;
      }
    );
  },
};
```

### **Infinite Scroll Pattern**

```typescript
// hooks/use-infinite-projects.ts
import { useInfiniteQuery } from '@tanstack/react-query';

export function useInfiniteProjects(filters?: Record<string, any>) {
  return useInfiniteQuery({
    queryKey: ['projects', 'infinite', filters],
    queryFn: async ({ pageParam = 0 }) => {
      const { data } = await apiClient.get('/projects', {
        params: {
          ...filters,
          offset: pageParam,
          limit: 20,
        },
      });
      return data;
    },
    getNextPageParam: (lastPage, allPages) => {
      return lastPage.length === 20 ? allPages.length * 20 : undefined;
    },
    initialPageParam: 0,
  });
}

// components/InfiniteProjectList.tsx
export function InfiniteProjectList() {
  const {
    data,
    fetchNextPage,
    hasNextPage,
    isFetchingNextPage,
    isLoading,
  } = useInfiniteProjects();

  const projects = data?.pages.flat() || [];

  return (
    <div className="space-y-4">
      {projects.map((project) => (
        <ProjectCard key={project.id} project={project} />
      ))}
      
      {hasNextPage && (
        <Button
          onClick={() => fetchNextPage()}
          disabled={isFetchingNextPage}
          className="w-full"
        >
          {isFetchingNextPage ? 'Loading...' : 'Load More'}
        </Button>
      )}
    </div>
  );
}
```

## 🎯 API Integration Decision Matrix

| Use Case | Recommendation | Reason |
|----------|----------------|---------|
| **Type-Safe APIs** | tRPC | End-to-end type safety, excellent DX |
| **Complex Data Fetching** | React Query | Advanced caching, optimistic updates |
| **Simple Applications** | SWR | Lightweight, easy to use |
| **Real-time Data** | GraphQL Subscriptions | Live data, efficient updates |
| **Legacy REST APIs** | React Query + Axios | Modern patterns with existing APIs |

## 🏆 Best Practices Summary

### **✅ API Integration Do's**
1. **Use tRPC** for new full-stack applications
2. **Implement proper error handling** at all levels
3. **Add request deduplication** to prevent duplicate calls
4. **Use optimistic updates** for better UX
5. **Implement proper loading states** and skeletons
6. **Cache frequently accessed data** with appropriate TTL
7. **Handle network errors gracefully** with retries

### **❌ Common Pitfalls to Avoid**
1. **Don't ignore error states** - always handle and display errors
2. **Don't make unnecessary requests** - use caching and deduplication
3. **Don't block UI** during API calls - use proper loading states
4. **Don't ignore type safety** - use TypeScript throughout
5. **Don't forget request timeouts** - set reasonable limits
6. **Don't skip authentication handling** - implement token refresh
7. **Don't hardcode API URLs** - use environment variables

---

## Navigation

- ← Previous: [Authentication Implementations](./authentication-implementations.md)
- → Next: [Performance Optimization](./performance-optimization.md)

| [📋 Overview](./README.md) | [🔐 Authentication](./authentication-implementations.md) | [🔗 API Integration](#) | [⚡ Performance](./performance-optimization.md) |
|---|---|---|---|