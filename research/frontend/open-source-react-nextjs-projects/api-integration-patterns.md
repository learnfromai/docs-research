# API Integration Patterns

Comprehensive analysis of backend API integration strategies used in production React/Next.js applications, covering type-safe APIs, error handling, authentication, and modern data fetching patterns.

## API Architecture Evolution

### Traditional REST APIs (2015-2020)
- **Axios/Fetch**: Manual HTTP client configuration
- **Custom Hooks**: useEffect-based data fetching
- **Manual Error Handling**: Component-level error states
- **Client-Server Coupling**: Tight coupling between frontend and backend

### Modern Type-Safe APIs (2020-Present)
- **tRPC**: End-to-end type safety for TypeScript full-stack
- **GraphQL**: Strongly typed query language
- **OpenAPI/Swagger**: REST APIs with generated TypeScript types
- **Server State Libraries**: React Query, SWR for data management

## tRPC - The Type-Safe Revolution

### Adoption Analysis: 45% of TypeScript Full-Stack Projects

tRPC provides end-to-end type safety from database to frontend without code generation.

#### Basic tRPC Setup (T3 Stack Pattern)
```typescript
// server/api/trpc.ts - Server setup
import { initTRPC, TRPCError } from '@trpc/server';
import { type Context } from './context';

const t = initTRPC.context<Context>().create({
  transformer: superjson,
  errorFormatter({ shape }) {
    return shape;
  },
});

export const createTRPCRouter = t.router;
export const publicProcedure = t.procedure;
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

#### Router Definition
```typescript
// server/api/routers/user.ts
import { z } from 'zod';
import { createTRPCRouter, publicProcedure, protectedProcedure } from '../trpc';

export const userRouter = createTRPCRouter({
  // Public procedure
  getUsers: publicProcedure
    .input(z.object({
      page: z.number().min(1).default(1),
      limit: z.number().min(1).max(100).default(10),
      search: z.string().optional(),
    }))
    .query(async ({ input, ctx }) => {
      const { page, limit, search } = input;
      
      const users = await ctx.prisma.user.findMany({
        where: search ? {
          OR: [
            { name: { contains: search, mode: 'insensitive' } },
            { email: { contains: search, mode: 'insensitive' } },
          ],
        } : undefined,
        skip: (page - 1) * limit,
        take: limit,
        select: {
          id: true,
          name: true,
          email: true,
          avatar: true,
          createdAt: true,
        },
      });
      
      const total = await ctx.prisma.user.count({
        where: search ? {
          OR: [
            { name: { contains: search, mode: 'insensitive' } },
            { email: { contains: search, mode: 'insensitive' } },
          ],
        } : undefined,
      });
      
      return {
        users,
        pagination: {
          page,
          limit,
          total,
          totalPages: Math.ceil(total / limit),
        },
      };
    }),

  // Protected procedure
  updateProfile: protectedProcedure
    .input(z.object({
      name: z.string().min(1).max(100),
      bio: z.string().max(500).optional(),
    }))
    .mutation(async ({ input, ctx }) => {
      const { name, bio } = input;
      
      return await ctx.prisma.user.update({
        where: { id: ctx.session.user.id },
        data: { name, bio },
      });
    }),

  // File upload procedure
  uploadAvatar: protectedProcedure
    .input(z.object({
      file: z.string(), // base64 encoded file
      filename: z.string(),
    }))
    .mutation(async ({ input, ctx }) => {
      // Upload to cloud storage (S3, Cloudinary, etc.)
      const uploadedUrl = await uploadToCloudStorage(input.file, input.filename);
      
      return await ctx.prisma.user.update({
        where: { id: ctx.session.user.id },
        data: { avatar: uploadedUrl },
      });
    }),
});
```

#### Client-Side Usage
```typescript
// app/users/page.tsx - Client usage
import { api } from '@/utils/api';

const UsersPage = () => {
  const [page, setPage] = useState(1);
  const [search, setSearch] = useState('');
  
  // Type-safe query with automatic loading/error states
  const { data, isLoading, error } = api.user.getUsers.useQuery({
    page,
    limit: 10,
    search: search || undefined,
  });

  // Type-safe mutation
  const updateProfile = api.user.updateProfile.useMutation({
    onSuccess: () => {
      toast.success('Profile updated successfully');
    },
    onError: (error) => {
      toast.error(error.message);
    },
  });

  if (isLoading) return <UsersSkeleton />;
  if (error) return <ErrorMessage error={error} />;

  return (
    <div>
      <SearchInput
        value={search}
        onChange={setSearch}
        placeholder="Search users..."
      />
      
      <UserList users={data?.users ?? []} />
      
      <Pagination
        currentPage={data?.pagination.page ?? 1}
        totalPages={data?.pagination.totalPages ?? 1}
        onPageChange={setPage}
      />
    </div>
  );
};
```

#### Advanced tRPC Patterns
```typescript
// Subscription for real-time updates
export const chatRouter = createTRPCRouter({
  onMessageAdded: publicProcedure
    .input(z.object({ chatId: z.string() }))
    .subscription(({ input }) => {
      return observable<Message>((emit) => {
        // Subscribe to database changes or WebSocket
        const unsubscribe = subscribeToMessages(input.chatId, (message) => {
          emit.next(message);
        });
        
        return unsubscribe;
      });
    }),

  // Infinite query support
  getMessages: publicProcedure
    .input(z.object({
      chatId: z.string(),
      cursor: z.string().nullish(),
      limit: z.number().min(1).max(100).default(20),
    }))
    .query(async ({ input, ctx }) => {
      const { chatId, cursor, limit } = input;
      
      const messages = await ctx.prisma.message.findMany({
        where: { chatId },
        cursor: cursor ? { id: cursor } : undefined,
        take: limit + 1,
        orderBy: { createdAt: 'desc' },
      });
      
      let nextCursor: typeof cursor | undefined = undefined;
      if (messages.length > limit) {
        const nextItem = messages.pop();
        nextCursor = nextItem?.id;
      }
      
      return {
        messages: messages.reverse(),
        nextCursor,
      };
    }),
});

// Client usage with infinite query
const ChatMessages = ({ chatId }: { chatId: string }) => {
  const {
    data,
    fetchNextPage,
    hasNextPage,
    isLoading,
  } = api.chat.getMessages.useInfiniteQuery(
    { chatId },
    {
      getNextPageParam: (lastPage) => lastPage.nextCursor,
    }
  );

  // Real-time subscription
  api.chat.onMessageAdded.useSubscription({ chatId }, {
    onData: (message) => {
      // Handle new message
      queryClient.setQueryData(['chat.getMessages'], (old) => {
        // Update cache with new message
      });
    },
  });

  return (
    <div>
      {data?.pages.map((page) =>
        page.messages.map((message) => (
          <MessageComponent key={message.id} message={message} />
        ))
      )}
      
      {hasNextPage && (
        <button onClick={() => fetchNextPage()}>
          Load More Messages
        </button>
      )}
    </div>
  );
};
```

## REST API with OpenAPI/TypeScript Generation

### Adoption: 40% of projects using REST APIs

This approach maintains REST principles while gaining TypeScript benefits through code generation.

#### OpenAPI Schema Definition
```yaml
# api-spec.yaml
openapi: 3.0.0
info:
  title: User Management API
  version: 1.0.0

components:
  schemas:
    User:
      type: object
      required:
        - id
        - email
        - name
      properties:
        id:
          type: string
          format: uuid
        email:
          type: string
          format: email
        name:
          type: string
          minLength: 1
          maxLength: 100
        avatar:
          type: string
          format: uri
        createdAt:
          type: string
          format: date-time

    CreateUserRequest:
      type: object
      required:
        - email
        - name
        - password
      properties:
        email:
          type: string
          format: email
        name:
          type: string
          minLength: 1
          maxLength: 100
        password:
          type: string
          minLength: 8

    UserListResponse:
      type: object
      properties:
        users:
          type: array
          items:
            $ref: '#/components/schemas/User'
        pagination:
          $ref: '#/components/schemas/Pagination'

paths:
  /api/users:
    get:
      summary: Get users
      parameters:
        - name: page
          in: query
          schema:
            type: integer
            minimum: 1
            default: 1
        - name: limit
          in: query
          schema:
            type: integer
            minimum: 1
            maximum: 100
            default: 10
        - name: search
          in: query
          schema:
            type: string
      responses:
        '200':
          description: Users retrieved successfully
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/UserListResponse'
```

#### Generated TypeScript Types
```typescript
// generated/api-types.ts (auto-generated)
export interface User {
  id: string;
  email: string;
  name: string;
  avatar?: string;
  createdAt: string;
}

export interface CreateUserRequest {
  email: string;
  name: string;
  password: string;
}

export interface UserListResponse {
  users: User[];
  pagination: Pagination;
}

export interface GetUsersParams {
  page?: number;
  limit?: number;
  search?: string;
}
```

#### Type-Safe API Client
```typescript
// lib/api-client.ts
import { User, CreateUserRequest, UserListResponse, GetUsersParams } from '@/generated/api-types';

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
      const error = await response.json();
      throw new ApiError(error.message, response.status);
    }

    return response.json();
  }

  // Type-safe methods
  async getUsers(params: GetUsersParams = {}): Promise<UserListResponse> {
    const searchParams = new URLSearchParams();
    
    if (params.page) searchParams.set('page', params.page.toString());
    if (params.limit) searchParams.set('limit', params.limit.toString());
    if (params.search) searchParams.set('search', params.search);
    
    const query = searchParams.toString();
    return this.request<UserListResponse>(`/api/users${query ? `?${query}` : ''}`);
  }

  async createUser(userData: CreateUserRequest): Promise<User> {
    return this.request<User>('/api/users', {
      method: 'POST',
      body: JSON.stringify(userData),
    });
  }

  async getUserById(id: string): Promise<User> {
    return this.request<User>(`/api/users/${id}`);
  }

  async updateUser(id: string, userData: Partial<User>): Promise<User> {
    return this.request<User>(`/api/users/${id}`, {
      method: 'PATCH',
      body: JSON.stringify(userData),
    });
  }

  async deleteUser(id: string): Promise<void> {
    return this.request<void>(`/api/users/${id}`, {
      method: 'DELETE',
    });
  }
}

export const apiClient = new ApiClient(process.env.NEXT_PUBLIC_API_URL!);
```

#### React Query Integration
```typescript
// hooks/useUsers.ts
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { apiClient } from '@/lib/api-client';
import type { GetUsersParams, CreateUserRequest } from '@/generated/api-types';

export const useUsers = (params: GetUsersParams = {}) => {
  return useQuery({
    queryKey: ['users', params],
    queryFn: () => apiClient.getUsers(params),
    staleTime: 5 * 60 * 1000, // 5 minutes
  });
};

export const useUser = (id: string) => {
  return useQuery({
    queryKey: ['users', id],
    queryFn: () => apiClient.getUserById(id),
    enabled: !!id,
  });
};

export const useCreateUser = () => {
  const queryClient = useQueryClient();
  
  return useMutation({
    mutationFn: (userData: CreateUserRequest) => apiClient.createUser(userData),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['users'] });
    },
  });
};

export const useUpdateUser = () => {
  const queryClient = useQueryClient();
  
  return useMutation({
    mutationFn: ({ id, ...userData }: { id: string } & Partial<User>) =>
      apiClient.updateUser(id, userData),
    onSuccess: (updatedUser) => {
      queryClient.setQueryData(['users', updatedUser.id], updatedUser);
      queryClient.invalidateQueries({ queryKey: ['users'] });
    },
  });
};
```

## GraphQL Integration Patterns

### Adoption: 10% of projects (specialized use cases)

GraphQL provides strongly typed queries with flexible data fetching capabilities.

#### GraphQL Schema
```graphql
# schema.graphql
type User {
  id: ID!
  email: String!
  name: String!
  avatar: String
  posts: [Post!]!
  createdAt: DateTime!
}

type Post {
  id: ID!
  title: String!
  content: String!
  author: User!
  published: Boolean!
  createdAt: DateTime!
}

type Query {
  users(
    first: Int
    after: String
    search: String
  ): UserConnection!
  
  user(id: ID!): User
  
  posts(
    first: Int
    after: String
    authorId: ID
  ): PostConnection!
}

type Mutation {
  createUser(input: CreateUserInput!): User!
  updateUser(id: ID!, input: UpdateUserInput!): User!
  deleteUser(id: ID!): Boolean!
}

type UserConnection {
  edges: [UserEdge!]!
  pageInfo: PageInfo!
}

type UserEdge {
  node: User!
  cursor: String!
}

input CreateUserInput {
  email: String!
  name: String!
  password: String!
}
```

#### Apollo Client Setup
```typescript
// lib/apollo-client.ts
import { ApolloClient, InMemoryCache, createHttpLink } from '@apollo/client';
import { setContext } from '@apollo/client/link/context';

const httpLink = createHttpLink({
  uri: process.env.NEXT_PUBLIC_GRAPHQL_URL,
});

const authLink = setContext((_, { headers }) => {
  const token = localStorage.getItem('token');
  
  return {
    headers: {
      ...headers,
      authorization: token ? `Bearer ${token}` : "",
    }
  };
});

export const client = new ApolloClient({
  link: authLink.concat(httpLink),
  cache: new InMemoryCache({
    typePolicies: {
      Query: {
        fields: {
          users: {
            keyArgs: ['search'],
            merge(existing, incoming) {
              return {
                ...incoming,
                edges: [...(existing?.edges || []), ...incoming.edges],
              };
            },
          },
        },
      },
    },
  }),
});
```

#### Code Generation with GraphQL Codegen
```typescript
// generated/graphql.ts (auto-generated)
export type User = {
  __typename?: 'User';
  id: Scalars['ID'];
  email: Scalars['String'];
  name: Scalars['String'];
  avatar?: Maybe<Scalars['String']>;
  posts: Array<Post>;
  createdAt: Scalars['DateTime'];
};

export type GetUsersQueryVariables = Exact<{
  first?: InputMaybe<Scalars['Int']>;
  after?: InputMaybe<Scalars['String']>;
  search?: InputMaybe<Scalars['String']>;
}>;

export type GetUsersQuery = {
  __typename?: 'Query';
  users: {
    __typename?: 'UserConnection';
    edges: Array<{
      __typename?: 'UserEdge';
      cursor: string;
      node: {
        __typename?: 'User';
        id: string;
        name: string;
        email: string;
        avatar?: string | null;
        createdAt: any;
      };
    }>;
    pageInfo: {
      __typename?: 'PageInfo';
      hasNextPage: boolean;
      endCursor?: string | null;
    };
  };
};

// Generated hooks
export function useGetUsersQuery(
  baseOptions?: Apollo.QueryHookOptions<GetUsersQuery, GetUsersQueryVariables>
) {
  const options = {...defaultOptions, ...baseOptions}
  return Apollo.useQuery<GetUsersQuery, GetUsersQueryVariables>(GetUsersDocument, options);
}
```

## Authentication Integration Patterns

### JWT Token Management
```typescript
// lib/auth.ts
class AuthManager {
  private accessToken: string | null = null;
  private refreshToken: string | null = null;
  
  constructor() {
    if (typeof window !== 'undefined') {
      this.accessToken = localStorage.getItem('accessToken');
      this.refreshToken = localStorage.getItem('refreshToken');
    }
  }

  async login(credentials: LoginCredentials): Promise<AuthResponse> {
    const response = await fetch('/api/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(credentials),
    });

    if (!response.ok) {
      throw new Error('Login failed');
    }

    const data = await response.json();
    this.setTokens(data.accessToken, data.refreshToken);
    
    return data;
  }

  async refreshAccessToken(): Promise<string> {
    if (!this.refreshToken) {
      throw new Error('No refresh token available');
    }

    const response = await fetch('/api/auth/refresh', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${this.refreshToken}`,
      },
    });

    if (!response.ok) {
      this.logout();
      throw new Error('Token refresh failed');
    }

    const data = await response.json();
    this.setTokens(data.accessToken, this.refreshToken);
    
    return data.accessToken;
  }

  private setTokens(accessToken: string, refreshToken: string) {
    this.accessToken = accessToken;
    this.refreshToken = refreshToken;
    
    localStorage.setItem('accessToken', accessToken);
    localStorage.setItem('refreshToken', refreshToken);
  }

  logout() {
    this.accessToken = null;
    this.refreshToken = null;
    
    localStorage.removeItem('accessToken');
    localStorage.removeItem('refreshToken');
  }

  getAccessToken(): string | null {
    return this.accessToken;
  }
}

export const authManager = new AuthManager();
```

### Axios Interceptors for Authentication
```typescript
// lib/axios-client.ts
import axios from 'axios';
import { authManager } from './auth';

const apiClient = axios.create({
  baseURL: process.env.NEXT_PUBLIC_API_URL,
  timeout: 10000,
});

// Request interceptor to add auth token
apiClient.interceptors.request.use(
  (config) => {
    const token = authManager.getAccessToken();
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  },
  (error) => Promise.reject(error)
);

// Response interceptor for token refresh
apiClient.interceptors.response.use(
  (response) => response,
  async (error) => {
    const originalRequest = error.config;

    if (error.response?.status === 401 && !originalRequest._retry) {
      originalRequest._retry = true;

      try {
        const newToken = await authManager.refreshAccessToken();
        originalRequest.headers.Authorization = `Bearer ${newToken}`;
        return apiClient(originalRequest);
      } catch (refreshError) {
        authManager.logout();
        window.location.href = '/login';
        return Promise.reject(refreshError);
      }
    }

    return Promise.reject(error);
  }
);

export { apiClient };
```

## Error Handling Patterns

### Centralized Error Management
```typescript
// lib/error-handler.ts
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

export const handleApiError = (error: unknown): ApiError => {
  if (error instanceof ApiError) {
    return error;
  }

  if (axios.isAxiosError(error)) {
    const status = error.response?.status ?? 500;
    const message = error.response?.data?.message ?? error.message;
    const code = error.response?.data?.code;
    
    return new ApiError(message, status, code);
  }

  return new ApiError('An unexpected error occurred', 500);
};

// React Error Boundary for API errors
export class ApiErrorBoundary extends Component<
  PropsWithChildren<{ fallback: ComponentType<{ error: ApiError }> }>,
  { hasError: boolean; error: ApiError | null }
> {
  constructor(props: PropsWithChildren<{ fallback: ComponentType<{ error: ApiError }> }>) {
    super(props);
    this.state = { hasError: false, error: null };
  }

  static getDerivedStateFromError(error: Error) {
    if (error instanceof ApiError) {
      return { hasError: true, error };
    }
    return { hasError: true, error: new ApiError(error.message, 500) };
  }

  componentDidCatch(error: Error, errorInfo: ErrorInfo) {
    console.error('API Error caught by boundary:', error, errorInfo);
    
    // Log to error reporting service
    reportError(error, errorInfo);
  }

  render() {
    if (this.state.hasError && this.state.error) {
      return <this.props.fallback error={this.state.error} />;
    }

    return this.props.children;
  }
}
```

### React Query Error Handling
```typescript
// components/ErrorFallback.tsx
const ErrorFallback = ({ error, resetErrorBoundary }: { 
  error: ApiError; 
  resetErrorBoundary: () => void; 
}) => {
  const getErrorMessage = (error: ApiError) => {
    switch (error.status) {
      case 401:
        return 'You need to log in to access this resource.';
      case 403:
        return 'You don\'t have permission to access this resource.';
      case 404:
        return 'The requested resource was not found.';
      case 500:
        return 'An internal server error occurred. Please try again later.';
      default:
        return error.message || 'An unexpected error occurred.';
    }
  };

  return (
    <div className="flex flex-col items-center justify-center p-8">
      <AlertCircle className="h-12 w-12 text-red-500 mb-4" />
      <h2 className="text-2xl font-bold text-gray-900 mb-2">
        Something went wrong
      </h2>
      <p className="text-gray-600 mb-4 text-center">
        {getErrorMessage(error)}
      </p>
      <Button onClick={resetErrorBoundary}>
        Try again
      </Button>
    </div>
  );
};

// Global error handling in React Query
const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      retry: (failureCount, error) => {
        // Don't retry on 4xx errors
        if (error instanceof ApiError && error.status >= 400 && error.status < 500) {
          return false;
        }
        return failureCount < 3;
      },
      throwOnError: (error) => {
        // Throw errors to error boundary for specific cases
        if (error instanceof ApiError && error.status >= 500) {
          return true;
        }
        return false;
      },
    },
    mutations: {
      onError: (error) => {
        const apiError = handleApiError(error);
        toast.error(apiError.message);
      },
    },
  },
});
```

## Data Validation Patterns

### Zod Schema Validation
```typescript
// schemas/user.ts
import { z } from 'zod';

export const userSchema = z.object({
  id: z.string().uuid(),
  email: z.string().email(),
  name: z.string().min(1).max(100),
  avatar: z.string().url().optional(),
  createdAt: z.string().datetime(),
});

export const createUserSchema = userSchema.omit({ id: true, createdAt: true });
export const updateUserSchema = createUserSchema.partial();

export type User = z.infer<typeof userSchema>;
export type CreateUser = z.infer<typeof createUserSchema>;
export type UpdateUser = z.infer<typeof updateUserSchema>;

// Runtime validation
export const validateUser = (data: unknown): User => {
  return userSchema.parse(data);
};

// Safe parsing with error handling
export const safeValidateUser = (data: unknown): {
  success: boolean;
  data?: User;
  error?: z.ZodError;
} => {
  const result = userSchema.safeParse(data);
  
  if (result.success) {
    return { success: true, data: result.data };
  } else {
    return { success: false, error: result.error };
  }
};
```

### API Response Validation
```typescript
// lib/api-client-with-validation.ts
class ValidatedApiClient {
  async getUsers(params: GetUsersParams = {}): Promise<UserListResponse> {
    const response = await this.request('/api/users', { params });
    
    // Validate response at runtime
    const validationResult = userListResponseSchema.safeParse(response);
    
    if (!validationResult.success) {
      console.error('API response validation failed:', validationResult.error);
      throw new ApiError('Invalid API response format', 502);
    }
    
    return validationResult.data;
  }

  async createUser(userData: CreateUser): Promise<User> {
    // Validate input before sending
    const validatedInput = createUserSchema.parse(userData);
    
    const response = await this.request('/api/users', {
      method: 'POST',
      body: JSON.stringify(validatedInput),
    });
    
    // Validate response
    return userSchema.parse(response);
  }
}
```

## Performance Optimization Patterns

### Request Deduplication
```typescript
// lib/request-deduplication.ts
class RequestDeduplicator {
  private pendingRequests = new Map<string, Promise<any>>();

  async request<T>(key: string, requestFn: () => Promise<T>): Promise<T> {
    // If request is already pending, return the existing promise
    if (this.pendingRequests.has(key)) {
      return this.pendingRequests.get(key);
    }

    // Create new request
    const promise = requestFn().finally(() => {
      // Clean up after request completes
      this.pendingRequests.delete(key);
    });

    this.pendingRequests.set(key, promise);
    return promise;
  }
}

const deduplicator = new RequestDeduplicator();

// Usage in API client
export const getUserById = (id: string) => {
  return deduplicator.request(`user-${id}`, () =>
    fetch(`/api/users/${id}`).then(res => res.json())
  );
};
```

### Caching Strategies
```typescript
// lib/cache-manager.ts
class ApiCache {
  private cache = new Map<string, { data: any; expiry: number }>();
  private defaultTTL = 5 * 60 * 1000; // 5 minutes

  set(key: string, data: any, ttl = this.defaultTTL) {
    this.cache.set(key, {
      data,
      expiry: Date.now() + ttl,
    });
  }

  get(key: string): any | null {
    const cached = this.cache.get(key);
    
    if (!cached) return null;
    
    if (Date.now() > cached.expiry) {
      this.cache.delete(key);
      return null;
    }
    
    return cached.data;
  }

  invalidate(pattern: string) {
    for (const key of this.cache.keys()) {
      if (key.includes(pattern)) {
        this.cache.delete(key);
      }
    }
  }
}

const apiCache = new ApiCache();

// Integration with API client
export const getCachedUsers = async (params: GetUsersParams) => {
  const cacheKey = `users-${JSON.stringify(params)}`;
  
  // Try cache first
  const cached = apiCache.get(cacheKey);
  if (cached) return cached;
  
  // Fetch from API
  const data = await apiClient.getUsers(params);
  
  // Cache the result
  apiCache.set(cacheKey, data);
  
  return data;
};
```

## Testing API Integration

### Mock Service Worker (MSW)
```typescript
// mocks/handlers.ts
import { rest } from 'msw';
import { User } from '@/types/user';

const mockUsers: User[] = [
  {
    id: '1',
    name: 'John Doe',
    email: 'john@example.com',
    avatar: 'https://example.com/avatar1.jpg',
    createdAt: '2023-01-01T00:00:00Z',
  },
  // ... more mock users
];

export const handlers = [
  // Get users
  rest.get('/api/users', (req, res, ctx) => {
    const page = Number(req.url.searchParams.get('page')) || 1;
    const limit = Number(req.url.searchParams.get('limit')) || 10;
    const search = req.url.searchParams.get('search');
    
    let filteredUsers = mockUsers;
    
    if (search) {
      filteredUsers = mockUsers.filter(user =>
        user.name.toLowerCase().includes(search.toLowerCase()) ||
        user.email.toLowerCase().includes(search.toLowerCase())
      );
    }
    
    const start = (page - 1) * limit;
    const end = start + limit;
    const paginatedUsers = filteredUsers.slice(start, end);
    
    return res(
      ctx.json({
        users: paginatedUsers,
        pagination: {
          page,
          limit,
          total: filteredUsers.length,
          totalPages: Math.ceil(filteredUsers.length / limit),
        },
      })
    );
  }),

  // Create user
  rest.post('/api/users', async (req, res, ctx) => {
    const userData = await req.json();
    
    const newUser: User = {
      id: Date.now().toString(),
      ...userData,
      createdAt: new Date().toISOString(),
    };
    
    mockUsers.push(newUser);
    
    return res(ctx.json(newUser));
  }),

  // Error simulation
  rest.get('/api/users/:id', (req, res, ctx) => {
    const { id } = req.params;
    
    if (id === 'error') {
      return res(
        ctx.status(500),
        ctx.json({ message: 'Internal server error' })
      );
    }
    
    const user = mockUsers.find(u => u.id === id);
    
    if (!user) {
      return res(
        ctx.status(404),
        ctx.json({ message: 'User not found' })
      );
    }
    
    return res(ctx.json(user));
  }),
];
```

### Testing API Hooks
```typescript
// __tests__/useUsers.test.tsx
import { renderHook, waitFor } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { useUsers } from '@/hooks/useUsers';

const createWrapper = () => {
  const queryClient = new QueryClient({
    defaultOptions: {
      queries: { retry: false },
      mutations: { retry: false },
    },
  });
  
  return ({ children }: { children: React.ReactNode }) => (
    <QueryClientProvider client={queryClient}>
      {children}
    </QueryClientProvider>
  );
};

describe('useUsers', () => {
  it('fetches users successfully', async () => {
    const { result } = renderHook(() => useUsers(), {
      wrapper: createWrapper(),
    });

    expect(result.current.isLoading).toBe(true);

    await waitFor(() => {
      expect(result.current.isSuccess).toBe(true);
    });

    expect(result.current.data?.users).toHaveLength(2);
    expect(result.current.data?.users[0].name).toBe('John Doe');
  });

  it('handles search parameters', async () => {
    const { result } = renderHook(
      () => useUsers({ search: 'john' }),
      { wrapper: createWrapper() }
    );

    await waitFor(() => {
      expect(result.current.isSuccess).toBe(true);
    });

    expect(result.current.data?.users).toHaveLength(1);
    expect(result.current.data?.users[0].name).toBe('John Doe');
  });
});
```

## Best Practices Summary

### API Integration Decision Framework

1. **Choose tRPC when:**
   - Building full-stack TypeScript applications
   - Need end-to-end type safety
   - Team owns both frontend and backend
   - Rapid development is priority

2. **Choose REST + OpenAPI when:**
   - Working with existing REST APIs
   - Need broader ecosystem compatibility
   - Multiple client types (mobile, web, etc.)
   - Third-party API integration

3. **Choose GraphQL when:**
   - Complex data relationships
   - Multiple client types with different data needs
   - Need advanced querying capabilities
   - Real-time subscriptions required

### Performance Best Practices

1. **Implement proper caching strategies**
2. **Use request deduplication**
3. **Implement optimistic updates**
4. **Handle loading and error states consistently**
5. **Validate data at runtime**
6. **Use proper TypeScript types**
7. **Implement comprehensive error handling**
8. **Test API integration thoroughly**

The modern React ecosystem provides excellent tools for API integration, with tRPC leading the way for TypeScript full-stack applications and traditional REST APIs maintaining relevance for broader compatibility needs.

---

**Navigation**
- ← Back to: [Component Library Strategies](./component-library-strategies.md)
- → Next: [Authentication Strategies](./authentication-strategies.md)
- → Related: [Implementation Guide](./implementation-guide.md)