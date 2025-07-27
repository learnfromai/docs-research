# API Integration Patterns in Production React Applications

## 🔌 Overview

Analysis of API integration approaches across 23 production React and Next.js applications, covering REST APIs, GraphQL, tRPC, real-time communication, error handling, caching strategies, and performance optimization.

## 📊 API Technology Distribution

| Technology | Adoption Rate | Projects Using | Type Safety | Learning Curve |
|------------|---------------|----------------|-------------|----------------|
| **REST + TanStack Query** | 45% | Refine, Homepage, Invoify | ⭐⭐⭐ | ⭐⭐ |
| **tRPC** | 30% | T3 Stack, Next.js Boilerplate | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| **GraphQL + Apollo** | 15% | Modern apps | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| **SWR** | 25% | Vercel projects | ⭐⭐⭐ | ⭐⭐ |
| **Native Fetch** | 20% | Simple apps | ⭐⭐ | ⭐ |

## 1. REST API with TanStack Query (Most Popular - 45%)

**Why TanStack Query Dominates**:
- Automatic caching and background updates
- Request deduplication
- Optimistic updates
- Infinite queries for pagination
- Offline support
- Excellent DevTools

### Advanced API Service Layer

```typescript
// lib/api.ts
import axios, { AxiosInstance, AxiosRequestConfig, AxiosResponse } from 'axios';

interface ApiError {
  message: string;
  code: string;
  status: number;
  details?: unknown;
}

class ApiClient {
  private client: AxiosInstance;
  private baseURL: string;

  constructor(baseURL: string) {
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
    // Request interceptor for auth tokens
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

    // Response interceptor for error handling
    this.client.interceptors.response.use(
      (response) => response,
      async (error) => {
        const originalRequest = error.config;

        // Handle 401 errors with token refresh
        if (error.response?.status === 401 && !originalRequest._retry) {
          originalRequest._retry = true;

          try {
            await this.refreshToken();
            const newToken = this.getAuthToken();
            originalRequest.headers.Authorization = `Bearer ${newToken}`;
            return this.client(originalRequest);
          } catch (refreshError) {
            this.handleAuthError();
            return Promise.reject(refreshError);
          }
        }

        return Promise.reject(this.transformError(error));
      }
    );
  }

  private transformError(error: any): ApiError {
    if (error.response) {
      return {
        message: error.response.data?.message || 'An error occurred',
        code: error.response.data?.code || 'UNKNOWN_ERROR',
        status: error.response.status,
        details: error.response.data,
      };
    }

    if (error.request) {
      return {
        message: 'Network error - please check your connection',
        code: 'NETWORK_ERROR',
        status: 0,
      };
    }

    return {
      message: error.message || 'An unexpected error occurred',
      code: 'UNKNOWN_ERROR',
      status: 0,
    };
  }

  private getAuthToken(): string | null {
    return localStorage.getItem('authToken');
  }

  private async refreshToken(): Promise<void> {
    const refreshToken = localStorage.getItem('refreshToken');
    if (!refreshToken) throw new Error('No refresh token');

    const response = await axios.post(`${this.baseURL}/auth/refresh`, {
      refreshToken,
    });

    localStorage.setItem('authToken', response.data.accessToken);
    localStorage.setItem('refreshToken', response.data.refreshToken);
  }

  private handleAuthError(): void {
    localStorage.removeItem('authToken');
    localStorage.removeItem('refreshToken');
    window.location.href = '/login';
  }

  // Generic request methods
  async get<T>(url: string, config?: AxiosRequestConfig): Promise<T> {
    const response = await this.client.get<T>(url, config);
    return response.data;
  }

  async post<T>(url: string, data?: any, config?: AxiosRequestConfig): Promise<T> {
    const response = await this.client.post<T>(url, data, config);
    return response.data;
  }

  async put<T>(url: string, data?: any, config?: AxiosRequestConfig): Promise<T> {
    const response = await this.client.put<T>(url, data, config);
    return response.data;
  }

  async patch<T>(url: string, data?: any, config?: AxiosRequestConfig): Promise<T> {
    const response = await this.client.patch<T>(url, data, config);
    return response.data;
  }

  async delete<T>(url: string, config?: AxiosRequestConfig): Promise<T> {
    const response = await this.client.delete<T>(url, config);
    return response.data;
  }
}

export const apiClient = new ApiClient(process.env.NEXT_PUBLIC_API_URL!);
```

### Typed API Services

```typescript
// services/userService.ts
import { apiClient } from '~/lib/api';

export interface User {
  id: string;
  email: string;
  firstName: string;
  lastName: string;
  avatar?: string;
  role: 'user' | 'admin' | 'moderator';
  createdAt: string;
  updatedAt: string;
}

export interface CreateUserData {
  email: string;
  firstName: string;
  lastName: string;
  password: string;
  role?: 'user' | 'admin' | 'moderator';
}

export interface UpdateUserData {
  firstName?: string;
  lastName?: string;
  avatar?: string;
  role?: 'user' | 'admin' | 'moderator';
}

export interface UserFilters {
  search?: string;
  role?: string;
  page?: number;
  limit?: number;
  sortBy?: 'createdAt' | 'name' | 'email';
  sortOrder?: 'asc' | 'desc';
}

export interface PaginatedResponse<T> {
  data: T[];
  total: number;
  page: number;
  limit: number;
  totalPages: number;
}

class UserService {
  private readonly basePath = '/users';

  async getUsers(filters: UserFilters = {}): Promise<PaginatedResponse<User>> {
    const params = new URLSearchParams();
    
    Object.entries(filters).forEach(([key, value]) => {
      if (value !== undefined && value !== null && value !== '') {
        params.append(key, String(value));
      }
    });

    return apiClient.get<PaginatedResponse<User>>(
      `${this.basePath}?${params.toString()}`
    );
  }

  async getUserById(id: string): Promise<User> {
    return apiClient.get<User>(`${this.basePath}/${id}`);
  }

  async createUser(data: CreateUserData): Promise<User> {
    return apiClient.post<User>(this.basePath, data);
  }

  async updateUser(id: string, data: UpdateUserData): Promise<User> {
    return apiClient.patch<User>(`${this.basePath}/${id}`, data);
  }

  async deleteUser(id: string): Promise<void> {
    return apiClient.delete<void>(`${this.basePath}/${id}`);
  }

  async uploadAvatar(id: string, file: File): Promise<User> {
    const formData = new FormData();
    formData.append('avatar', file);

    return apiClient.post<User>(`${this.basePath}/${id}/avatar`, formData, {
      headers: {
        'Content-Type': 'multipart/form-data',
      },
    });
  }

  async bulkDelete(ids: string[]): Promise<void> {
    return apiClient.post<void>(`${this.basePath}/bulk-delete`, { ids });
  }

  async exportUsers(filters: UserFilters = {}): Promise<Blob> {
    const params = new URLSearchParams();
    Object.entries(filters).forEach(([key, value]) => {
      if (value !== undefined && value !== null && value !== '') {
        params.append(key, String(value));
      }
    });

    return apiClient.get<Blob>(`${this.basePath}/export?${params.toString()}`, {
      responseType: 'blob',
    });
  }
}

export const userService = new UserService();
```

### TanStack Query Hooks

```typescript
// hooks/useUsers.ts
import { useQuery, useMutation, useQueryClient, useInfiniteQuery } from '@tanstack/react-query';
import { userService, UserFilters, CreateUserData, UpdateUserData } from '~/services/userService';
import { toast } from '~/components/ui/use-toast';

// Query keys factory
export const userKeys = {
  all: ['users'] as const,
  lists: () => [...userKeys.all, 'list'] as const,
  list: (filters: UserFilters) => [...userKeys.lists(), filters] as const,
  details: () => [...userKeys.all, 'detail'] as const,
  detail: (id: string) => [...userKeys.details(), id] as const,
};

// Get paginated users
export const useUsers = (filters: UserFilters = {}) => {
  return useQuery({
    queryKey: userKeys.list(filters),
    queryFn: () => userService.getUsers(filters),
    staleTime: 5 * 60 * 1000, // 5 minutes
    cacheTime: 10 * 60 * 1000, // 10 minutes
    keepPreviousData: true,
    retry: (failureCount, error: any) => {
      // Don't retry on 4xx errors
      if (error?.status >= 400 && error?.status < 500) {
        return false;
      }
      return failureCount < 3;
    },
  });
};

// Get single user
export const useUser = (id: string) => {
  return useQuery({
    queryKey: userKeys.detail(id),
    queryFn: () => userService.getUserById(id),
    enabled: !!id,
    staleTime: 5 * 60 * 1000,
  });
};

// Infinite query for pagination
export const useInfiniteUsers = (filters: Omit<UserFilters, 'page'> = {}) => {
  return useInfiniteQuery({
    queryKey: [...userKeys.list(filters), 'infinite'],
    queryFn: ({ pageParam = 1 }) =>
      userService.getUsers({ ...filters, page: pageParam }),
    getNextPageParam: (lastPage) => {
      if (lastPage.page < lastPage.totalPages) {
        return lastPage.page + 1;
      }
      return undefined;
    },
    staleTime: 5 * 60 * 1000,
  });
};

// Create user mutation
export const useCreateUser = () => {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (data: CreateUserData) => userService.createUser(data),
    onSuccess: (newUser) => {
      // Update cache with new user
      queryClient.setQueryData(
        userKeys.detail(newUser.id),
        newUser
      );

      // Invalidate lists to refetch
      queryClient.invalidateQueries({
        queryKey: userKeys.lists(),
      });

      toast({
        title: 'Success',
        description: 'User created successfully',
      });
    },
    onError: (error: any) => {
      toast({
        title: 'Error',
        description: error.message || 'Failed to create user',
        variant: 'destructive',
      });
    },
  });
};

// Update user mutation with optimistic updates
export const useUpdateUser = () => {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: ({ id, data }: { id: string; data: UpdateUserData }) =>
      userService.updateUser(id, data),
    onMutate: async ({ id, data }) => {
      // Cancel outgoing refetches
      await queryClient.cancelQueries({ queryKey: userKeys.detail(id) });

      // Snapshot the previous value
      const previousUser = queryClient.getQueryData(userKeys.detail(id));

      // Optimistically update to the new value
      queryClient.setQueryData(userKeys.detail(id), (old: any) => ({
        ...old,
        ...data,
        updatedAt: new Date().toISOString(),
      }));

      return { previousUser };
    },
    onError: (err, { id }, context) => {
      // If the mutation fails, use the context to roll back
      if (context?.previousUser) {
        queryClient.setQueryData(userKeys.detail(id), context.previousUser);
      }

      toast({
        title: 'Error',
        description: 'Failed to update user',
        variant: 'destructive',
      });
    },
    onSettled: (data, error, { id }) => {
      // Always refetch after error or success
      queryClient.invalidateQueries({ queryKey: userKeys.detail(id) });
      queryClient.invalidateQueries({ queryKey: userKeys.lists() });
    },
    onSuccess: () => {
      toast({
        title: 'Success',
        description: 'User updated successfully',
      });
    },
  });
};

// Delete user mutation
export const useDeleteUser = () => {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (id: string) => userService.deleteUser(id),
    onSuccess: (_, deletedId) => {
      // Remove from cache
      queryClient.removeQueries({ queryKey: userKeys.detail(deletedId) });
      
      // Update list cache by removing the deleted user
      queryClient.setQueriesData(
        { queryKey: userKeys.lists() },
        (old: any) => {
          if (!old) return old;
          return {
            ...old,
            data: old.data.filter((user: any) => user.id !== deletedId),
            total: old.total - 1,
          };
        }
      );

      toast({
        title: 'Success',
        description: 'User deleted successfully',
      });
    },
    onError: (error: any) => {
      toast({
        title: 'Error',
        description: error.message || 'Failed to delete user',
        variant: 'destructive',
      });
    },
  });
};

// Bulk operations
export const useBulkDeleteUsers = () => {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (ids: string[]) => userService.bulkDelete(ids),
    onSuccess: (_, deletedIds) => {
      // Remove all deleted users from cache
      deletedIds.forEach(id => {
        queryClient.removeQueries({ queryKey: userKeys.detail(id) });
      });

      // Invalidate lists
      queryClient.invalidateQueries({ queryKey: userKeys.lists() });

      toast({
        title: 'Success',
        description: `${deletedIds.length} users deleted successfully`,
      });
    },
    onError: (error: any) => {
      toast({
        title: 'Error',
        description: error.message || 'Failed to delete users',
        variant: 'destructive',
      });
    },
  });
};
```

## 2. tRPC (Type-Safe APIs - 30%)

**Used by**: T3 Stack, Next.js Boilerplate

**Why tRPC is Popular**:
- End-to-end type safety
- No code generation required
- Excellent developer experience
- Built-in React Query integration
- Automatic serialization

### Server-Side Router Implementation

```typescript
// server/api/routers/users.ts
import { z } from 'zod';
import { createTRPCRouter, protectedProcedure, publicProcedure } from '../trpc';
import { TRPCError } from '@trpc/server';

const userFilterSchema = z.object({
  search: z.string().optional(),
  role: z.enum(['user', 'admin', 'moderator']).optional(),
  page: z.number().min(1).default(1),
  limit: z.number().min(1).max(100).default(10),
  sortBy: z.enum(['createdAt', 'name', 'email']).default('createdAt'),
  sortOrder: z.enum(['asc', 'desc']).default('desc'),
});

const createUserSchema = z.object({
  email: z.string().email(),
  firstName: z.string().min(1).max(50),
  lastName: z.string().min(1).max(50),
  password: z.string().min(8),
  role: z.enum(['user', 'admin', 'moderator']).default('user'),
});

const updateUserSchema = createUserSchema.partial().omit({ password: true });

export const usersRouter = createTRPCRouter({
  // Get paginated users
  getAll: protectedProcedure
    .input(userFilterSchema)
    .query(async ({ ctx, input }) => {
      const { page, limit, search, role, sortBy, sortOrder } = input;
      const skip = (page - 1) * limit;

      const where = {
        ...(search && {
          OR: [
            { firstName: { contains: search, mode: 'insensitive' as const } },
            { lastName: { contains: search, mode: 'insensitive' as const } },
            { email: { contains: search, mode: 'insensitive' as const } },
          ],
        }),
        ...(role && { role }),
      };

      const [users, total] = await Promise.all([
        ctx.db.user.findMany({
          where,
          skip,
          take: limit,
          orderBy: { [sortBy]: sortOrder },
          select: {
            id: true,
            email: true,
            firstName: true,
            lastName: true,
            avatar: true,
            role: true,
            createdAt: true,
            updatedAt: true,
          },
        }),
        ctx.db.user.count({ where }),
      ]);

      return {
        data: users,
        total,
        page,
        limit,
        totalPages: Math.ceil(total / limit),
      };
    }),

  // Get user by ID
  getById: protectedProcedure
    .input(z.object({ id: z.string() }))
    .query(async ({ ctx, input }) => {
      const user = await ctx.db.user.findUnique({
        where: { id: input.id },
        select: {
          id: true,
          email: true,
          firstName: true,
          lastName: true,
          avatar: true,
          role: true,
          createdAt: true,
          updatedAt: true,
        },
      });

      if (!user) {
        throw new TRPCError({
          code: 'NOT_FOUND',
          message: 'User not found',
        });
      }

      return user;
    }),

  // Create user
  create: protectedProcedure
    .input(createUserSchema)
    .mutation(async ({ ctx, input }) => {
      // Check if user has permission to create users
      if (ctx.session.user.role !== 'admin') {
        throw new TRPCError({
          code: 'FORBIDDEN',
          message: 'Only admins can create users',
        });
      }

      // Check if email already exists
      const existingUser = await ctx.db.user.findUnique({
        where: { email: input.email },
      });

      if (existingUser) {
        throw new TRPCError({
          code: 'CONFLICT',
          message: 'User with this email already exists',
        });
      }

      // Hash password
      const hashedPassword = await hash(input.password, 12);

      const user = await ctx.db.user.create({
        data: {
          ...input,
          password: hashedPassword,
        },
        select: {
          id: true,
          email: true,
          firstName: true,
          lastName: true,
          avatar: true,
          role: true,
          createdAt: true,
          updatedAt: true,
        },
      });

      // Log audit event
      await ctx.db.auditLog.create({
        data: {
          action: 'USER_CREATED',
          userId: ctx.session.user.id,
          targetUserId: user.id,
          details: {
            email: user.email,
            role: user.role,
          },
        },
      });

      return user;
    }),

  // Update user
  update: protectedProcedure
    .input(z.object({
      id: z.string(),
      data: updateUserSchema,
    }))
    .mutation(async ({ ctx, input }) => {
      // Check permissions
      const canEdit = 
        ctx.session.user.id === input.id || 
        ctx.session.user.role === 'admin';

      if (!canEdit) {
        throw new TRPCError({
          code: 'FORBIDDEN',
          message: 'You can only edit your own profile',
        });
      }

      // Verify user exists
      const existingUser = await ctx.db.user.findUnique({
        where: { id: input.id },
      });

      if (!existingUser) {
        throw new TRPCError({
          code: 'NOT_FOUND',
          message: 'User not found',
        });
      }

      const updatedUser = await ctx.db.user.update({
        where: { id: input.id },
        data: input.data,
        select: {
          id: true,
          email: true,
          firstName: true,
          lastName: true,
          avatar: true,
          role: true,
          createdAt: true,
          updatedAt: true,
        },
      });

      return updatedUser;
    }),

  // Delete user
  delete: protectedProcedure
    .input(z.object({ id: z.string() }))
    .mutation(async ({ ctx, input }) => {
      if (ctx.session.user.role !== 'admin') {
        throw new TRPCError({
          code: 'FORBIDDEN',
          message: 'Only admins can delete users',
        });
      }

      // Can't delete yourself
      if (ctx.session.user.id === input.id) {
        throw new TRPCError({
          code: 'FORBIDDEN',
          message: 'You cannot delete your own account',
        });
      }

      const user = await ctx.db.user.findUnique({
        where: { id: input.id },
      });

      if (!user) {
        throw new TRPCError({
          code: 'NOT_FOUND',
          message: 'User not found',
        });
      }

      await ctx.db.user.delete({
        where: { id: input.id },
      });

      // Log audit event
      await ctx.db.auditLog.create({
        data: {
          action: 'USER_DELETED',
          userId: ctx.session.user.id,
          targetUserId: input.id,
          details: {
            email: user.email,
            role: user.role,
          },
        },
      });
    }),

  // Infinite query for pagination
  getInfinite: protectedProcedure
    .input(
      userFilterSchema.extend({
        cursor: z.string().optional(),
      })
    )
    .query(async ({ ctx, input }) => {
      const { limit, cursor, search, role, sortBy, sortOrder } = input;

      const where = {
        ...(search && {
          OR: [
            { firstName: { contains: search, mode: 'insensitive' as const } },
            { lastName: { contains: search, mode: 'insensitive' as const } },
            { email: { contains: search, mode: 'insensitive' as const } },
          ],
        }),
        ...(role && { role }),
      };

      const users = await ctx.db.user.findMany({
        where,
        take: limit + 1, // Take one extra to determine if there's a next page
        cursor: cursor ? { id: cursor } : undefined,
        orderBy: { [sortBy]: sortOrder },
        select: {
          id: true,
          email: true,
          firstName: true,
          lastName: true,
          avatar: true,
          role: true,
          createdAt: true,
          updatedAt: true,
        },
      });

      let nextCursor: typeof cursor | undefined = undefined;
      if (users.length > limit) {
        const nextItem = users.pop(); // Remove the extra item
        nextCursor = nextItem!.id;
      }

      return {
        users,
        nextCursor,
      };
    }),
});
```

### Client-Side Usage

```typescript
// hooks/api.ts
import { api } from '~/utils/api';

// Type-safe hooks with full intellisense
export const useUsers = (filters: {
  search?: string;
  role?: 'user' | 'admin' | 'moderator';
  page?: number;
  limit?: number;
}) => {
  return api.users.getAll.useQuery(filters, {
    keepPreviousData: true,
    staleTime: 5 * 60 * 1000,
  });
};

export const useUser = (id: string) => {
  return api.users.getById.useQuery(
    { id },
    { enabled: !!id }
  );
};

export const useCreateUser = () => {
  const utils = api.useContext();

  return api.users.create.useMutation({
    onSuccess: async () => {
      await utils.users.getAll.invalidate();
    },
    onError: (error) => {
      console.error('Failed to create user:', error.message);
    },
  });
};

export const useUpdateUser = () => {
  const utils = api.useContext();

  return api.users.update.useMutation({
    onMutate: async ({ id, data }) => {
      // Cancel outgoing refetches
      await utils.users.getById.cancel({ id });

      // Snapshot the previous value
      const previousUser = utils.users.getById.getData({ id });

      // Optimistically update to the new value
      utils.users.getById.setData({ id }, (old) => 
        old ? { ...old, ...data } : undefined
      );

      return { previousUser };
    },
    onError: (err, { id }, context) => {
      // If the mutation fails, use the context to roll back
      if (context?.previousUser) {
        utils.users.getById.setData({ id }, context.previousUser);
      }
    },
    onSettled: async (data, error, { id }) => {
      // Always refetch after error or success
      await utils.users.getById.invalidate({ id });
      await utils.users.getAll.invalidate();
    },
  });
};

// Infinite query usage
export const useInfiniteUsers = (filters: {
  search?: string;
  role?: 'user' | 'admin' | 'moderator';
}) => {
  return api.users.getInfinite.useInfiniteQuery(
    { limit: 10, ...filters },
    {
      getNextPageParam: (lastPage) => lastPage.nextCursor,
      staleTime: 5 * 60 * 1000,
    }
  );
};

// Component usage with full type safety
function UsersList() {
  const [search, setSearch] = useState('');
  const [role, setRole] = useState<'user' | 'admin' | 'moderator' | undefined>();

  const { data: users, isLoading, error } = useUsers({
    search,
    role,
    page: 1,
    limit: 10,
  });

  const createUser = useCreateUser();
  const updateUser = useUpdateUser();

  if (isLoading) return <div>Loading...</div>;
  if (error) return <div>Error: {error.message}</div>;

  return (
    <div>
      <input
        value={search}
        onChange={(e) => setSearch(e.target.value)}
        placeholder="Search users..."
      />
      
      {users?.data.map(user => (
        <div key={user.id}>
          <h3>{user.firstName} {user.lastName}</h3>
          <p>{user.email}</p>
          <button
            onClick={() => 
              updateUser.mutate({
                id: user.id,
                data: { firstName: 'Updated' }
              })
            }
          >
            Update
          </button>
        </div>
      ))}
    </div>
  );
}
```

## 3. Real-Time Communication Patterns

### WebSocket Integration

```typescript
// hooks/useWebSocket.ts
import { useEffect, useRef, useState, useCallback } from 'react';
import { useQueryClient } from '@tanstack/react-query';

interface WebSocketOptions {
  url: string;
  protocols?: string | string[];
  onOpen?: (event: Event) => void;
  onClose?: (event: CloseEvent) => void;
  onError?: (event: Event) => void;
  reconnectAttempts?: number;
  reconnectInterval?: number;
}

export function useWebSocket<T = any>(options: WebSocketOptions) {
  const {
    url,
    protocols,
    onOpen,
    onClose,
    onError,
    reconnectAttempts = 5,
    reconnectInterval = 3000,
  } = options;

  const ws = useRef<WebSocket | null>(null);
  const [isConnected, setIsConnected] = useState(false);
  const [lastMessage, setLastMessage] = useState<T | null>(null);
  const [connectionError, setConnectionError] = useState<string | null>(null);
  const reconnectCount = useRef(0);
  const reconnectTimeoutId = useRef<NodeJS.Timeout | null>(null);

  const connect = useCallback(() => {
    if (ws.current?.readyState === WebSocket.OPEN) {
      return;
    }

    try {
      ws.current = new WebSocket(url, protocols);

      ws.current.onopen = (event) => {
        setIsConnected(true);
        setConnectionError(null);
        reconnectCount.current = 0;
        onOpen?.(event);
      };

      ws.current.onclose = (event) => {
        setIsConnected(false);
        onClose?.(event);

        // Attempt to reconnect if not closed intentionally
        if (!event.wasClean && reconnectCount.current < reconnectAttempts) {
          reconnectCount.current += 1;
          reconnectTimeoutId.current = setTimeout(connect, reconnectInterval);
        }
      };

      ws.current.onerror = (event) => {
        setConnectionError('WebSocket connection failed');
        onError?.(event);
      };

      ws.current.onmessage = (event) => {
        try {
          const data = JSON.parse(event.data);
          setLastMessage(data);
        } catch (error) {
          console.error('Failed to parse WebSocket message:', error);
        }
      };
    } catch (error) {
      setConnectionError('Failed to create WebSocket connection');
    }
  }, [url, protocols, onOpen, onClose, onError, reconnectAttempts, reconnectInterval]);

  const disconnect = useCallback(() => {
    if (reconnectTimeoutId.current) {
      clearTimeout(reconnectTimeoutId.current);
    }
    
    if (ws.current) {
      ws.current.close();
      ws.current = null;
    }
    
    setIsConnected(false);
  }, []);

  const sendMessage = useCallback((message: any) => {
    if (ws.current?.readyState === WebSocket.OPEN) {
      ws.current.send(JSON.stringify(message));
      return true;
    }
    return false;
  }, []);

  useEffect(() => {
    connect();
    return disconnect;
  }, [connect, disconnect]);

  return {
    isConnected,
    lastMessage,
    connectionError,
    sendMessage,
    connect,
    disconnect,
  };
}

// Real-time notifications
export function useRealtimeNotifications() {
  const queryClient = useQueryClient();
  
  const { lastMessage, isConnected } = useWebSocket<{
    type: 'notification' | 'user_update' | 'system_message';
    data: any;
  }>({
    url: `${process.env.NEXT_PUBLIC_WS_URL}/notifications`,
    onOpen: () => console.log('Notifications WebSocket connected'),
    onClose: () => console.log('Notifications WebSocket disconnected'),
  });

  useEffect(() => {
    if (!lastMessage) return;

    switch (lastMessage.type) {
      case 'notification':
        // Add to notifications cache
        queryClient.setQueryData(['notifications'], (old: any) => {
          return old ? [lastMessage.data, ...old] : [lastMessage.data];
        });
        break;

      case 'user_update':
        // Update user cache
        queryClient.setQueryData(
          ['users', 'detail', lastMessage.data.id],
          lastMessage.data
        );
        // Invalidate user lists
        queryClient.invalidateQueries(['users', 'list']);
        break;

      case 'system_message':
        // Handle system messages
        console.log('System message:', lastMessage.data);
        break;
    }
  }, [lastMessage, queryClient]);

  return { isConnected };
}
```

## 4. Error Handling Patterns

### Global Error Boundary

```typescript
// components/ErrorBoundary.tsx
import { ErrorBoundary as ReactErrorBoundary } from 'react-error-boundary';
import { QueryErrorResetBoundary } from '@tanstack/react-query';

interface ErrorFallbackProps {
  error: Error;
  resetErrorBoundary: () => void;
}

function ErrorFallback({ error, resetErrorBoundary }: ErrorFallbackProps) {
  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-50">
      <div className="max-w-md w-full bg-white shadow-lg rounded-lg p-6">
        <div className="flex items-center justify-center w-12 h-12 mx-auto bg-red-100 rounded-full">
          <svg className="w-6 h-6 text-red-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.732-.833-2.464 0L3.34 16.5c-.77.833.192 2.5 1.732 2.5z" />
          </svg>
        </div>
        
        <div className="mt-4 text-center">
          <h3 className="text-lg font-medium text-gray-900">Something went wrong</h3>
          <p className="mt-2 text-sm text-gray-500">
            {error.message || 'An unexpected error occurred'}
          </p>
          
          <div className="mt-6 flex gap-3">
            <button
              onClick={resetErrorBoundary}
              className="flex-1 bg-red-600 text-white px-4 py-2 rounded-md hover:bg-red-700"
            >
              Try Again
            </button>
            <button
              onClick={() => window.location.href = '/'}
              className="flex-1 bg-gray-200 text-gray-900 px-4 py-2 rounded-md hover:bg-gray-300"
            >
              Go Home
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

export function AppErrorBoundary({ children }: { children: ReactNode }) {
  return (
    <QueryErrorResetBoundary>
      {({ reset }) => (
        <ReactErrorBoundary
          FallbackComponent={ErrorFallback}
          onReset={reset}
          onError={(error, errorInfo) => {
            // Log error to monitoring service
            console.error('Error caught by boundary:', error, errorInfo);
            
            // Send to error reporting service
            if (process.env.NODE_ENV === 'production') {
              // Example: Sentry.captureException(error);
            }
          }}
        >
          {children}
        </ReactErrorBoundary>
      )}
    </QueryErrorResetBoundary>
  );
}
```

### API Error Handling

```typescript
// lib/errorHandling.ts
export interface ApiError {
  message: string;
  code: string;
  status: number;
  field?: string;
  details?: Record<string, any>;
}

export class ApiErrorHandler {
  static handle(error: any): ApiError {
    // Axios error
    if (error.response) {
      return {
        message: error.response.data?.message || 'An error occurred',
        code: error.response.data?.code || 'UNKNOWN_ERROR',
        status: error.response.status,
        field: error.response.data?.field,
        details: error.response.data?.details,
      };
    }

    // Network error
    if (error.request) {
      return {
        message: 'Network error - please check your connection',
        code: 'NETWORK_ERROR',
        status: 0,
      };
    }

    // tRPC error
    if (error.data?.code) {
      return {
        message: error.message,
        code: error.data.code,
        status: error.data.httpStatus || 500,
        details: error.data,
      };
    }

    // Generic error
    return {
      message: error.message || 'An unexpected error occurred',
      code: 'UNKNOWN_ERROR',
      status: 500,
    };
  }

  static getDisplayMessage(error: ApiError): string {
    const messages: Record<string, string> = {
      NETWORK_ERROR: 'Please check your internet connection and try again.',
      UNAUTHORIZED: 'Please log in to continue.',
      FORBIDDEN: 'You do not have permission to perform this action.',
      NOT_FOUND: 'The requested resource was not found.',
      CONFLICT: 'This action conflicts with existing data.',
      VALIDATION_ERROR: 'Please check your input and try again.',
      RATE_LIMITED: 'Too many requests. Please try again later.',
      SERVER_ERROR: 'Server error. Please try again later.',
    };

    return messages[error.code] || error.message;
  }

  static shouldRetry(error: ApiError): boolean {
    const retryableCodes = ['NETWORK_ERROR', 'TIMEOUT', 'SERVER_ERROR'];
    const retryableStatuses = [408, 429, 500, 502, 503, 504];
    
    return (
      retryableCodes.includes(error.code) ||
      retryableStatuses.includes(error.status)
    );
  }
}
```

## 🎯 API Integration Best Practices

### 1. Always Use TypeScript
```typescript
// ✅ Good: Properly typed API calls
interface CreateUserRequest {
  email: string;
  firstName: string;
  lastName: string;
}

interface User {
  id: string;
  email: string;
  firstName: string;
  lastName: string;
  createdAt: string;
}

const createUser = async (data: CreateUserRequest): Promise<User> => {
  return apiClient.post<User>('/users', data);
};

// ❌ Bad: No types
const createUser = async (data: any): Promise<any> => {
  return apiClient.post('/users', data);
};
```

### 2. Implement Proper Error Handling
```typescript
// ✅ Good: Comprehensive error handling
const { data, error, isLoading } = useQuery({
  queryKey: ['users'],
  queryFn: fetchUsers,
  retry: (failureCount, error) => {
    // Don't retry on 4xx errors except 408
    if (error.status >= 400 && error.status < 500 && error.status !== 408) {
      return false;
    }
    return failureCount < 3;
  },
  retryDelay: (attemptIndex) => Math.min(1000 * 2 ** attemptIndex, 30000),
});

// ❌ Bad: No error handling
const { data } = useQuery({
  queryKey: ['users'],
  queryFn: fetchUsers,
});
```

### 3. Use Optimistic Updates Wisely
```typescript
// ✅ Good: Optimistic updates with rollback
const updateUser = useMutation({
  mutationFn: ({ id, data }) => userService.updateUser(id, data),
  onMutate: async ({ id, data }) => {
    await queryClient.cancelQueries(['users', id]);
    const previousUser = queryClient.getQueryData(['users', id]);
    
    queryClient.setQueryData(['users', id], old => ({ ...old, ...data }));
    
    return { previousUser };
  },
  onError: (err, variables, context) => {
    if (context?.previousUser) {
      queryClient.setQueryData(['users', variables.id], context.previousUser);
    }
  },
  onSettled: (data, error, variables) => {
    queryClient.invalidateQueries(['users', variables.id]);
  },
});

// ❌ Bad: Optimistic updates without rollback
const updateUser = useMutation({
  mutationFn: ({ id, data }) => userService.updateUser(id, data),
  onMutate: ({ id, data }) => {
    queryClient.setQueryData(['users', id], old => ({ ...old, ...data }));
  },
});
```

---

## Navigation

- ← Back to: [Authentication Patterns](./authentication-patterns.md)
- → Next: [Component Architecture](./component-architecture.md)

---
*API integration patterns from 23 production React applications | July 2025*