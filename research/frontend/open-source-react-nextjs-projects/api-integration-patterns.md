# API Integration Patterns in Open Source React/Next.js Projects

## 🎯 Overview

This document analyzes API integration strategies, data fetching patterns, and backend communication approaches used in production-ready open source React and Next.js applications. It examines how successful projects handle server state, optimize data fetching, and implement reliable API communication.

## 🌐 API Integration Landscape

### Data Fetching Solutions (2024)

| Solution | Adoption Rate | Type Safety | Caching | Learning Curve | Best For |
|----------|---------------|-------------|---------|----------------|----------|
| **React Query + REST** | 40% | Manual | Advanced | ⭐⭐⭐ | Existing APIs, microservices |
| **tRPC + React Query** | 35% | Automatic | Advanced | ⭐⭐⭐⭐ | Full-stack TypeScript |
| **SWR + REST** | 15% | Manual | Basic | ⭐⭐ | Simple applications |
| **Apollo + GraphQL** | 8% | Generated | Advanced | ⭐⭐⭐⭐⭐ | GraphQL APIs |
| **Native fetch** | 2% | None | None | ⭐ | Basic use cases |

### The tRPC Revolution

**Why tRPC is gaining massive adoption**:
- ✅ End-to-end type safety without codegen
- ✅ Built-in React Query integration
- ✅ Procedure-based API design
- ✅ Automatic serialization/deserialization
- ✅ Built-in error handling
- ✅ Real-time subscriptions support

## 🔗 tRPC Implementation Patterns

### 1. Basic tRPC Setup

**Used in**: Cal.com, T3 Stack applications

```typescript
// server/api/root.ts - Main router
import { createTRPCRouter } from "./trpc";
import { userRouter } from "./routers/user";
import { projectRouter } from "./routers/project";
import { authRouter } from "./routers/auth";

export const appRouter = createTRPCRouter({
  auth: authRouter,
  user: userRouter,
  project: projectRouter,
});

export type AppRouter = typeof appRouter;

// server/api/trpc.ts - tRPC configuration
import { initTRPC, TRPCError } from "@trpc/server";
import { type CreateNextContextOptions } from "@trpc/server/adapters/next";
import { getServerSession } from "next-auth";
import { authOptions } from "@/lib/auth";
import { prisma } from "@/lib/db";

interface CreateContextOptions {
  session: Session | null;
}

export const createInnerTRPCContext = (opts: CreateContextOptions) => {
  return {
    session: opts.session,
    prisma,
  };
};

export const createTRPCContext = async (opts: CreateNextContextOptions) => {
  const session = await getServerSession(opts.req, opts.res, authOptions);

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
          error.code === "BAD_REQUEST" && error.cause instanceof ZodError
            ? error.cause.flatten()
            : null,
      },
    };
  },
});

// Base router and procedure helpers
export const createTRPCRouter = t.router;
export const publicProcedure = t.procedure;

// Protected procedure with authentication
export const protectedProcedure = t.procedure.use(({ ctx, next }) => {
  if (!ctx.session || !ctx.session.user) {
    throw new TRPCError({ code: "UNAUTHORIZED" });
  }
  return next({
    ctx: {
      session: { ...ctx.session, user: ctx.session.user },
    },
  });
});
```

### 2. Advanced tRPC Router with Validation

**Used in**: Complex business applications

```typescript
// server/api/routers/user.ts - User router with validation
import { z } from "zod";
import { createTRPCRouter, protectedProcedure, publicProcedure } from "../trpc";
import { TRPCError } from "@trpc/server";

// Input validation schemas
const getUserSchema = z.object({
  id: z.string().uuid(),
});

const updateUserSchema = z.object({
  id: z.string().uuid(),
  name: z.string().min(1).max(100).optional(),
  email: z.string().email().optional(),
  role: z.enum(["user", "admin", "moderator"]).optional(),
});

const getUsersSchema = z.object({
  cursor: z.string().optional(),
  limit: z.number().min(1).max(100).default(10),
  search: z.string().optional(),
  role: z.enum(["user", "admin", "moderator"]).optional(),
});

export const userRouter = createTRPCRouter({
  // Public procedures
  getPublicProfile: publicProcedure
    .input(getUserSchema)
    .query(async ({ ctx, input }) => {
      const user = await ctx.prisma.user.findUnique({
        where: { id: input.id },
        select: {
          id: true,
          name: true,
          image: true,
          createdAt: true,
          // Don't expose sensitive data
        },
      });

      if (!user) {
        throw new TRPCError({
          code: "NOT_FOUND",
          message: "User not found",
        });
      }

      return user;
    }),

  // Protected procedures
  getProfile: protectedProcedure.query(async ({ ctx }) => {
    return await ctx.prisma.user.findUnique({
      where: { id: ctx.session.user.id },
      include: {
        accounts: {
          select: { provider: true, providerAccountId: true },
        },
      },
    });
  }),

  updateProfile: protectedProcedure
    .input(updateUserSchema)
    .mutation(async ({ ctx, input }) => {
      const { id, ...updateData } = input;

      // Check if user can update this profile
      if (id !== ctx.session.user.id && ctx.session.user.role !== "admin") {
        throw new TRPCError({
          code: "FORBIDDEN",
          message: "You can only update your own profile",
        });
      }

      // Check if email is already taken
      if (updateData.email) {
        const existingUser = await ctx.prisma.user.findFirst({
          where: {
            email: updateData.email,
            NOT: { id },
          },
        });

        if (existingUser) {
          throw new TRPCError({
            code: "CONFLICT",
            message: "Email is already taken",
          });
        }
      }

      const updatedUser = await ctx.prisma.user.update({
        where: { id },
        data: updateData,
      });

      return updatedUser;
    }),

  // Infinite query for large datasets
  getUsers: protectedProcedure
    .input(getUsersSchema)
    .query(async ({ ctx, input }) => {
      const { cursor, limit, search, role } = input;

      // Only admins can view all users
      if (ctx.session.user.role !== "admin") {
        throw new TRPCError({
          code: "FORBIDDEN",
          message: "Admin access required",
        });
      }

      const where = {
        ...(search && {
          OR: [
            { name: { contains: search, mode: "insensitive" as const } },
            { email: { contains: search, mode: "insensitive" as const } },
          ],
        }),
        ...(role && { role }),
      };

      const users = await ctx.prisma.user.findMany({
        where,
        take: limit + 1, // Take one extra to determine if there's a next page
        cursor: cursor ? { id: cursor } : undefined,
        orderBy: { createdAt: "desc" },
        select: {
          id: true,
          name: true,
          email: true,
          role: true,
          image: true,
          createdAt: true,
          lastActiveAt: true,
        },
      });

      let nextCursor: string | undefined = undefined;
      if (users.length > limit) {
        const nextItem = users.pop();
        nextCursor = nextItem!.id;
      }

      return {
        users,
        nextCursor,
        hasMore: !!nextCursor,
      };
    }),

  // Real-time subscription
  onUserUpdate: protectedProcedure
    .input(z.object({ userId: z.string().uuid() }))
    .subscription(async function* ({ input, ctx }) {
      // This would integrate with your real-time solution (Pusher, Socket.io, etc.)
      yield {
        type: "connected" as const,
        userId: input.userId,
      };

      // Example: Listen to database changes or events
      // In practice, you'd integrate with your real-time infrastructure
    }),
});
```

### 3. Client-Side tRPC Usage

**Used in**: Frontend components

```typescript
// hooks/use-users.ts - Custom hooks wrapping tRPC
import { api } from "@/utils/api";
import { useInfiniteQuery } from "@tanstack/react-query";

export function useUsers(filters: {
  search?: string;
  role?: "user" | "admin" | "moderator";
} = {}) {
  return api.user.getUsers.useInfiniteQuery(
    {
      limit: 20,
      ...filters,
    },
    {
      getNextPageParam: (lastPage) => lastPage.nextCursor,
      staleTime: 5 * 60 * 1000, // 5 minutes
    }
  );
}

export function useUser(userId: string) {
  return api.user.getPublicProfile.useQuery(
    { id: userId },
    {
      enabled: !!userId,
      staleTime: 2 * 60 * 1000, // 2 minutes
    }
  );
}

export function useUpdateUser() {
  const utils = api.useContext();

  return api.user.updateProfile.useMutation({
    onMutate: async (newData) => {
      // Cancel outgoing refetches
      await utils.user.getProfile.cancel();

      // Snapshot the previous value
      const previousUser = utils.user.getProfile.getData();

      // Optimistically update
      utils.user.getProfile.setData(undefined, (old) => ({
        ...old!,
        ...newData,
      }));

      return { previousUser };
    },

    onError: (err, newData, context) => {
      // Rollback on error
      utils.user.getProfile.setData(undefined, context?.previousUser);
    },

    onSettled: () => {
      // Always refetch after error or success
      utils.user.getProfile.invalidate();
    },

    onSuccess: (data) => {
      // Update related queries
      utils.user.getUsers.invalidate();
      
      // Show success notification
      toast.success("Profile updated successfully");
    },
  });
}

// components/UserProfile.tsx - Component usage
export function UserProfile({ userId }: { userId: string }) {
  const { data: user, isLoading, error } = useUser(userId);
  const updateUser = useUpdateUser();

  if (isLoading) return <UserProfileSkeleton />;
  if (error) return <ErrorMessage error={error.message} />;
  if (!user) return <UserNotFound />;

  const handleUpdate = (updates: Partial<User>) => {
    updateUser.mutate({
      id: userId,
      ...updates,
    });
  };

  return (
    <div className="user-profile">
      <UserAvatar src={user.image} name={user.name} />
      <h1>{user.name}</h1>
      <p>{user.email}</p>
      
      <EditUserForm 
        user={user} 
        onSubmit={handleUpdate}
        isLoading={updateUser.isPending}
      />
    </div>
  );
}
```

## 🔄 React Query Patterns for REST APIs

### 1. Custom API Client

**Used in**: Supabase Dashboard, REST-based applications

```typescript
// lib/api-client.ts - Robust API client
class ApiClient {
  private baseURL: string;
  private defaultHeaders: Record<string, string>;

  constructor(baseURL: string = "/api") {
    this.baseURL = baseURL;
    this.defaultHeaders = {
      "Content-Type": "application/json",
    };
  }

  private async request<T>(
    endpoint: string,
    options: RequestInit = {}
  ): Promise<T> {
    const url = `${this.baseURL}${endpoint}`;
    
    const config: RequestInit = {
      headers: {
        ...this.defaultHeaders,
        ...options.headers,
      },
      ...options,
    };

    // Add authentication header if available
    const token = await this.getAuthToken();
    if (token) {
      config.headers = {
        ...config.headers,
        Authorization: `Bearer ${token}`,
      };
    }

    try {
      const response = await fetch(url, config);
      
      if (!response.ok) {
        const errorData = await response.json().catch(() => ({}));
        throw new ApiError(
          errorData.message || `HTTP ${response.status}`,
          response.status,
          errorData
        );
      }

      // Handle empty responses
      if (response.status === 204) {
        return undefined as unknown as T;
      }

      return await response.json();
    } catch (error) {
      if (error instanceof ApiError) throw error;
      throw new ApiError("Network error", 0, { originalError: error });
    }
  }

  private async getAuthToken(): Promise<string | null> {
    // Integration with NextAuth or your auth solution
    const session = await getSession();
    return session?.accessToken || null;
  }

  // HTTP methods
  async get<T>(endpoint: string, params?: Record<string, any>): Promise<T> {
    const searchParams = params ? `?${new URLSearchParams(params)}` : "";
    return this.request<T>(`${endpoint}${searchParams}`, {
      method: "GET",
    });
  }

  async post<T>(endpoint: string, data?: any): Promise<T> {
    return this.request<T>(endpoint, {
      method: "POST",
      body: data ? JSON.stringify(data) : undefined,
    });
  }

  async put<T>(endpoint: string, data?: any): Promise<T> {
    return this.request<T>(endpoint, {
      method: "PUT",
      body: data ? JSON.stringify(data) : undefined,
    });
  }

  async patch<T>(endpoint: string, data?: any): Promise<T> {
    return this.request<T>(endpoint, {
      method: "PATCH",
      body: data ? JSON.stringify(data) : undefined,
    });
  }

  async delete<T>(endpoint: string): Promise<T> {
    return this.request<T>(endpoint, {
      method: "DELETE",
    });
  }

  // File upload
  async uploadFile<T>(endpoint: string, file: File, onProgress?: (progress: number) => void): Promise<T> {
    return new Promise((resolve, reject) => {
      const formData = new FormData();
      formData.append("file", file);

      const xhr = new XMLHttpRequest();

      if (onProgress) {
        xhr.upload.addEventListener("progress", (event) => {
          if (event.lengthComputable) {
            const progress = (event.loaded / event.total) * 100;
            onProgress(progress);
          }
        });
      }

      xhr.addEventListener("load", () => {
        if (xhr.status >= 200 && xhr.status < 300) {
          resolve(JSON.parse(xhr.responseText));
        } else {
          reject(new ApiError(`Upload failed: ${xhr.status}`, xhr.status));
        }
      });

      xhr.addEventListener("error", () => {
        reject(new ApiError("Upload failed", 0));
      });

      xhr.open("POST", `${this.baseURL}${endpoint}`);
      
      // Add auth header if available
      this.getAuthToken().then(token => {
        if (token) {
          xhr.setRequestHeader("Authorization", `Bearer ${token}`);
        }
        xhr.send(formData);
      });
    });
  }
}

// Custom error class
export class ApiError extends Error {
  constructor(
    message: string,
    public status: number,
    public data?: any
  ) {
    super(message);
    this.name = "ApiError";
  }
}

export const apiClient = new ApiClient();
```

### 2. React Query Hooks for REST APIs

**Used in**: Applications with RESTful backends

```typescript
// hooks/api/use-users.ts - React Query hooks
import { useQuery, useMutation, useInfiniteQuery, useQueryClient } from "@tanstack/react-query";
import { apiClient } from "@/lib/api-client";

// Query keys for consistency
export const userKeys = {
  all: ["users"] as const,
  lists: () => [...userKeys.all, "list"] as const,
  list: (filters: UserFilters) => [...userKeys.lists(), filters] as const,
  details: () => [...userKeys.all, "detail"] as const,
  detail: (id: string) => [...userKeys.details(), id] as const,
  search: (query: string) => [...userKeys.all, "search", query] as const,
};

// Interfaces
interface User {
  id: string;
  name: string;
  email: string;
  role: string;
  createdAt: string;
  updatedAt: string;
}

interface UserFilters {
  role?: string;
  search?: string;
  page?: number;
  limit?: number;
}

interface PaginatedResponse<T> {
  data: T[];
  meta: {
    page: number;
    limit: number;
    total: number;
    totalPages: number;
  };
}

// Query hooks
export function useUsers(filters: UserFilters = {}) {
  return useQuery({
    queryKey: userKeys.list(filters),
    queryFn: () => apiClient.get<PaginatedResponse<User>>("/users", filters),
    staleTime: 5 * 60 * 1000, // 5 minutes
    gcTime: 10 * 60 * 1000, // 10 minutes
  });
}

export function useUser(id: string) {
  return useQuery({
    queryKey: userKeys.detail(id),
    queryFn: () => apiClient.get<User>(`/users/${id}`),
    enabled: !!id,
    staleTime: 2 * 60 * 1000, // 2 minutes
  });
}

export function useInfiniteUsers(filters: Omit<UserFilters, 'page'> = {}) {
  return useInfiniteQuery({
    queryKey: userKeys.list({ ...filters, page: undefined }),
    queryFn: ({ pageParam = 1 }) =>
      apiClient.get<PaginatedResponse<User>>("/users", {
        ...filters,
        page: pageParam,
        limit: 20,
      }),
    initialPageParam: 1,
    getNextPageParam: (lastPage) => {
      const { page, totalPages } = lastPage.meta;
      return page < totalPages ? page + 1 : undefined;
    },
    staleTime: 5 * 60 * 1000,
  });
}

export function useSearchUsers(query: string) {
  return useQuery({
    queryKey: userKeys.search(query),
    queryFn: () => apiClient.get<User[]>("/users/search", { q: query }),
    enabled: query.length >= 2, // Only search when query is 2+ characters
    staleTime: 30 * 1000, // 30 seconds for search results
  });
}

// Mutation hooks
export function useCreateUser() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (userData: Omit<User, "id" | "createdAt" | "updatedAt">) =>
      apiClient.post<User>("/users", userData),

    onMutate: async (newUser) => {
      // Cancel outgoing refetches
      await queryClient.cancelQueries({ queryKey: userKeys.lists() });

      // Snapshot previous value
      const previousUsers = queryClient.getQueriesData({
        queryKey: userKeys.lists(),
      });

      // Optimistically update all user lists
      queryClient.setQueriesData<PaginatedResponse<User>>(
        { queryKey: userKeys.lists() },
        (old) => {
          if (!old) return old;
          
          const optimisticUser: User = {
            id: `temp-${Date.now()}`,
            createdAt: new Date().toISOString(),
            updatedAt: new Date().toISOString(),
            ...newUser,
          };

          return {
            ...old,
            data: [optimisticUser, ...old.data],
            meta: {
              ...old.meta,
              total: old.meta.total + 1,
            },
          };
        }
      );

      return { previousUsers };
    },

    onError: (err, variables, context) => {
      // Restore previous values on error
      if (context?.previousUsers) {
        context.previousUsers.forEach(([queryKey, data]) => {
          queryClient.setQueryData(queryKey, data);
        });
      }
    },

    onSuccess: (newUser) => {
      // Update caches with real data
      queryClient.setQueryData(userKeys.detail(newUser.id), newUser);
      
      // Invalidate and refetch lists
      queryClient.invalidateQueries({ queryKey: userKeys.lists() });
      
      // Show success notification
      toast.success("User created successfully");
    },

    onSettled: () => {
      // Always refetch to ensure consistency
      queryClient.invalidateQueries({ queryKey: userKeys.lists() });
    },
  });
}

export function useUpdateUser() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: ({ id, ...updates }: Partial<User> & { id: string }) =>
      apiClient.put<User>(`/users/${id}`, updates),

    onMutate: async ({ id, ...updates }) => {
      await queryClient.cancelQueries({ queryKey: userKeys.detail(id) });

      const previousUser = queryClient.getQueryData(userKeys.detail(id));

      queryClient.setQueryData(userKeys.detail(id), (old: User) => ({
        ...old,
        ...updates,
        updatedAt: new Date().toISOString(),
      }));

      return { previousUser, id };
    },

    onError: (err, variables, context) => {
      if (context?.previousUser) {
        queryClient.setQueryData(
          userKeys.detail(context.id),
          context.previousUser
        );
      }
    },

    onSuccess: (updatedUser) => {
      queryClient.setQueryData(userKeys.detail(updatedUser.id), updatedUser);
      queryClient.invalidateQueries({ queryKey: userKeys.lists() });
      toast.success("User updated successfully");
    },
  });
}

export function useDeleteUser() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (id: string) => apiClient.delete(`/users/${id}`),

    onMutate: async (id) => {
      await queryClient.cancelQueries({ queryKey: userKeys.all });

      const previousData = {
        user: queryClient.getQueryData(userKeys.detail(id)),
        lists: queryClient.getQueriesData({ queryKey: userKeys.lists() }),
      };

      // Remove from all caches
      queryClient.removeQueries({ queryKey: userKeys.detail(id) });
      
      queryClient.setQueriesData<PaginatedResponse<User>>(
        { queryKey: userKeys.lists() },
        (old) => {
          if (!old) return old;
          return {
            ...old,
            data: old.data.filter(user => user.id !== id),
            meta: {
              ...old.meta,
              total: old.meta.total - 1,
            },
          };
        }
      );

      return { previousData, id };
    },

    onError: (err, id, context) => {
      // Restore previous data
      if (context?.previousData.user) {
        queryClient.setQueryData(userKeys.detail(id), context.previousData.user);
      }
      
      if (context?.previousData.lists) {
        context.previousData.lists.forEach(([queryKey, data]) => {
          queryClient.setQueryData(queryKey, data);
        });
      }
    },

    onSuccess: (_, id) => {
      queryClient.invalidateQueries({ queryKey: userKeys.lists() });
      toast.success("User deleted successfully");
    },
  });
}
```

## 📡 Real-time Data Patterns

### 1. WebSocket Integration

**Used in**: Collaborative applications like Plane

```typescript
// hooks/use-websocket.ts - WebSocket hook
import { useEffect, useRef, useState } from "react";
import { useQueryClient } from "@tanstack/react-query";

interface WebSocketMessage {
  type: string;
  payload: any;
  timestamp: number;
}

export function useWebSocket(url: string, options: {
  onMessage?: (message: WebSocketMessage) => void;
  onConnect?: () => void;
  onDisconnect?: () => void;
  reconnectAttempts?: number;
  reconnectInterval?: number;
} = {}) {
  const {
    onMessage,
    onConnect,
    onDisconnect,
    reconnectAttempts = 3,
    reconnectInterval = 5000,
  } = options;

  const ws = useRef<WebSocket | null>(null);
  const reconnectCount = useRef(0);
  const [isConnected, setIsConnected] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const connect = useCallback(() => {
    try {
      ws.current = new WebSocket(url);

      ws.current.onopen = () => {
        setIsConnected(true);
        setError(null);
        reconnectCount.current = 0;
        onConnect?.();
      };

      ws.current.onmessage = (event) => {
        try {
          const message: WebSocketMessage = JSON.parse(event.data);
          onMessage?.(message);
        } catch (err) {
          console.error("Failed to parse WebSocket message:", err);
        }
      };

      ws.current.onclose = () => {
        setIsConnected(false);
        onDisconnect?.();

        // Attempt to reconnect
        if (reconnectCount.current < reconnectAttempts) {
          reconnectCount.current++;
          setTimeout(connect, reconnectInterval);
        } else {
          setError("Max reconnection attempts reached");
        }
      };

      ws.current.onerror = (event) => {
        setError("WebSocket error occurred");
        console.error("WebSocket error:", event);
      };
    } catch (err) {
      setError("Failed to connect to WebSocket");
    }
  }, [url, onMessage, onConnect, onDisconnect, reconnectAttempts, reconnectInterval]);

  const disconnect = useCallback(() => {
    if (ws.current) {
      ws.current.close();
      ws.current = null;
    }
  }, []);

  const sendMessage = useCallback((message: any) => {
    if (ws.current && ws.current.readyState === WebSocket.OPEN) {
      ws.current.send(JSON.stringify(message));
    } else {
      console.warn("WebSocket is not connected");
    }
  }, []);

  useEffect(() => {
    connect();
    return disconnect;
  }, [connect, disconnect]);

  return {
    isConnected,
    error,
    sendMessage,
    disconnect,
  };
}

// hooks/use-realtime-users.ts - Real-time user updates
export function useRealtimeUsers() {
  const queryClient = useQueryClient();
  const { sendMessage } = useWebSocket(
    process.env.NEXT_PUBLIC_WS_URL || "ws://localhost:3001",
    {
      onMessage: (message) => {
        switch (message.type) {
          case "USER_CREATED":
            handleUserCreated(message.payload);
            break;
          case "USER_UPDATED":
            handleUserUpdated(message.payload);
            break;
          case "USER_DELETED":
            handleUserDeleted(message.payload);
            break;
        }
      },
      onConnect: () => {
        // Subscribe to user updates
        sendMessage({
          type: "SUBSCRIBE",
          channel: "users",
        });
      },
    }
  );

  const handleUserCreated = (user: User) => {
    // Update user lists
    queryClient.setQueriesData<PaginatedResponse<User>>(
      { queryKey: userKeys.lists() },
      (old) => {
        if (!old) return old;
        return {
          ...old,
          data: [user, ...old.data],
          meta: {
            ...old.meta,
            total: old.meta.total + 1,
          },
        };
      }
    );

    // Set individual user cache
    queryClient.setQueryData(userKeys.detail(user.id), user);
  };

  const handleUserUpdated = (user: User) => {
    // Update individual user cache
    queryClient.setQueryData(userKeys.detail(user.id), user);

    // Update in lists
    queryClient.setQueriesData<PaginatedResponse<User>>(
      { queryKey: userKeys.lists() },
      (old) => {
        if (!old) return old;
        return {
          ...old,
          data: old.data.map(u => u.id === user.id ? user : u),
        };
      }
    );
  };

  const handleUserDeleted = (userId: string) => {
    // Remove from individual cache
    queryClient.removeQueries({ queryKey: userKeys.detail(userId) });

    // Remove from lists
    queryClient.setQueriesData<PaginatedResponse<User>>(
      { queryKey: userKeys.lists() },
      (old) => {
        if (!old) return old;
        return {
          ...old,
          data: old.data.filter(u => u.id !== userId),
          meta: {
            ...old.meta,
            total: old.meta.total - 1,
          },
        };
      }
    );
  };
}
```

### 2. Server-Sent Events (SSE)

**Used in**: Real-time dashboards, notifications

```typescript
// hooks/use-server-sent-events.ts
export function useServerSentEvents(url: string, options: {
  onMessage?: (data: any) => void;
  onError?: (error: Event) => void;
  enabled?: boolean;
} = {}) {
  const { onMessage, onError, enabled = true } = options;
  const eventSourceRef = useRef<EventSource | null>(null);
  const [isConnected, setIsConnected] = useState(false);

  useEffect(() => {
    if (!enabled) return;

    const eventSource = new EventSource(url);
    eventSourceRef.current = eventSource;

    eventSource.onopen = () => {
      setIsConnected(true);
    };

    eventSource.onmessage = (event) => {
      try {
        const data = JSON.parse(event.data);
        onMessage?.(data);
      } catch (err) {
        console.error("Failed to parse SSE message:", err);
      }
    };

    eventSource.onerror = (error) => {
      setIsConnected(false);
      onError?.(error);
    };

    return () => {
      eventSource.close();
      setIsConnected(false);
    };
  }, [url, onMessage, onError, enabled]);

  return { isConnected };
}

// Example usage for real-time notifications
export function useRealtimeNotifications() {
  const queryClient = useQueryClient();
  const { addNotification } = useAppStore();

  const { isConnected } = useServerSentEvents("/api/notifications/stream", {
    onMessage: (notification) => {
      // Add to UI notification system
      addNotification({
        id: notification.id,
        type: notification.type,
        title: notification.title,
        message: notification.message,
      });

      // Update notifications cache
      queryClient.setQueryData(
        ["notifications"],
        (old: Notification[] = []) => [notification, ...old]
      );
    },
  });

  return { isConnected };
}
```

## 🔄 Data Synchronization Patterns

### 1. Optimistic Updates with Rollback

```typescript
// Advanced optimistic update pattern
export function useOptimisticUpdate<T, TVariables>(
  mutationFn: (variables: TVariables) => Promise<T>,
  options: {
    queryKey: QueryKey;
    updateFn: (old: T | undefined, variables: TVariables) => T;
    onSuccess?: (data: T, variables: TVariables) => void;
    onError?: (error: Error, variables: TVariables) => void;
  }
) {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn,
    onMutate: async (variables) => {
      await queryClient.cancelQueries({ queryKey: options.queryKey });

      const previousData = queryClient.getQueryData<T>(options.queryKey);

      if (previousData) {
        const optimisticData = options.updateFn(previousData, variables);
        queryClient.setQueryData(options.queryKey, optimisticData);
      }

      return { previousData };
    },
    onError: (error, variables, context) => {
      if (context?.previousData) {
        queryClient.setQueryData(options.queryKey, context.previousData);
      }
      options.onError?.(error, variables);
    },
    onSuccess: (data, variables) => {
      queryClient.setQueryData(options.queryKey, data);
      options.onSuccess?.(data, variables);
    },
    onSettled: () => {
      queryClient.invalidateQueries({ queryKey: options.queryKey });
    },
  });
}

// Usage
export function useUpdateProjectName() {
  return useOptimisticUpdate(
    ({ projectId, name }: { projectId: string; name: string }) =>
      apiClient.patch(`/projects/${projectId}`, { name }),
    {
      queryKey: ["project", projectId],
      updateFn: (old, { name }) => old ? { ...old, name } : old,
      onSuccess: () => toast.success("Project name updated"),
      onError: () => toast.error("Failed to update project name"),
    }
  );
}
```

## 📊 Performance Optimization

### 1. Request Deduplication and Batching

```typescript
// lib/request-batcher.ts - Request batching utility
class RequestBatcher {
  private batches = new Map<string, {
    requests: Array<{ resolve: Function; reject: Function; data: any }>;
    timeout: NodeJS.Timeout;
  }>();

  batch<T>(
    key: string,
    requestData: any,
    batchFn: (requests: any[]) => Promise<T[]>,
    delay = 50
  ): Promise<T> {
    return new Promise((resolve, reject) => {
      if (!this.batches.has(key)) {
        this.batches.set(key, {
          requests: [],
          timeout: setTimeout(() => this.executeBatch(key, batchFn), delay),
        });
      }

      const batch = this.batches.get(key)!;
      batch.requests.push({ resolve, reject, data: requestData });
    });
  }

  private async executeBatch<T>(key: string, batchFn: (requests: any[]) => Promise<T[]>) {
    const batch = this.batches.get(key);
    if (!batch) return;

    this.batches.delete(key);

    try {
      const requestsData = batch.requests.map(r => r.data);
      const results = await batchFn(requestsData);

      batch.requests.forEach((request, index) => {
        request.resolve(results[index]);
      });
    } catch (error) {
      batch.requests.forEach(request => {
        request.reject(error);
      });
    }
  }
}

export const requestBatcher = new RequestBatcher();

// Usage in API hooks
export function useBatchedUsers(userIds: string[]) {
  return useQuery({
    queryKey: ["users", "batch", userIds.sort()],
    queryFn: () => Promise.all(
      userIds.map(id => 
        requestBatcher.batch(
          "users",
          id,
          (ids: string[]) => apiClient.post("/users/batch", { ids })
        )
      )
    ),
    enabled: userIds.length > 0,
  });
}
```

### 2. Smart Cache Management

```typescript
// lib/cache-manager.ts - Advanced cache management
export class CacheManager {
  constructor(private queryClient: QueryClient) {}

  // Prefetch related data
  prefetchRelated(user: User) {
    // Prefetch user's projects
    this.queryClient.prefetchQuery({
      queryKey: ["projects", { userId: user.id }],
      queryFn: () => apiClient.get(`/users/${user.id}/projects`),
      staleTime: 5 * 60 * 1000,
    });

    // Prefetch user's team
    if (user.teamId) {
      this.queryClient.prefetchQuery({
        queryKey: ["team", user.teamId],
        queryFn: () => apiClient.get(`/teams/${user.teamId}`),
        staleTime: 10 * 60 * 1000,
      });
    }
  }

  // Cleanup old cache entries
  cleanupCache() {
    this.queryClient.getQueryCache().findAll().forEach(query => {
      const lastUpdated = query.state.dataUpdatedAt;
      const oneHourAgo = Date.now() - 60 * 60 * 1000;

      if (lastUpdated < oneHourAgo && !query.getObserversCount()) {
        this.queryClient.removeQueries({ queryKey: query.queryKey });
      }
    });
  }

  // Update related caches when user changes
  updateUserRelatedCaches(updatedUser: User) {
    // Update user in team member lists
    this.queryClient.setQueriesData<Team>(
      { queryKey: ["team"] },
      (old) => {
        if (!old) return old;
        return {
          ...old,
          members: old.members.map(member =>
            member.id === updatedUser.id 
              ? { ...member, ...updatedUser }
              : member
          ),
        };
      }
    );

    // Update user in project member lists
    this.queryClient.setQueriesData<Project>(
      { queryKey: ["projects"] },
      (old) => {
        if (!old) return old;
        return {
          ...old,
          members: old.members?.map(member =>
            member.id === updatedUser.id
              ? { ...member, ...updatedUser }
              : member
          ),
        };
      }
    );
  }
}
```

API integration in modern React/Next.js applications requires careful consideration of type safety, performance, and user experience. The trend is clearly moving toward tRPC for full-stack TypeScript applications, while React Query remains essential for any API integration strategy due to its powerful caching and synchronization capabilities.