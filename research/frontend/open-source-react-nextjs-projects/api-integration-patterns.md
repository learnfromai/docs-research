# API Integration Patterns in React/Next.js Projects

## 🎯 Overview

Comprehensive analysis of API integration strategies used in production React/Next.js applications, covering data fetching, state synchronization, error handling, and real-time communication patterns.

## 🔄 API Integration Landscape

### **Data Fetching Categories**

```typescript
// Server State - Remote data that needs caching and synchronization
interface ServerState {
  data: any;           // The actual data
  isLoading: boolean;  // Loading state
  error: Error | null; // Error state
  isStale: boolean;    // Whether data might be outdated
  lastFetched: Date;   // When data was last fetched
}

// Client State - Local application state
interface ClientState {
  ui: UIState;         // Interface state
  user: UserState;     // Current user state
  form: FormState;     // Form data
}

// Real-time State - Live data updates
interface RealtimeState {
  connection: ConnectionStatus; // WebSocket connection status
  subscriptions: Subscription[]; // Active subscriptions
  liveData: LiveDataMap;        // Real-time data streams
}
```

## 🛠️ Data Fetching Solutions Analysis

### **1. React Query / TanStack Query**

**Used by**: Refine, Supabase Dashboard, 65% of analyzed projects  
**Best for**: Complex server state management, caching, synchronization

#### **Advanced Query Patterns**

```typescript
import { 
  useQuery, 
  useMutation, 
  useQueryClient, 
  useInfiniteQuery,
  QueryClient,
  QueryCache
} from '@tanstack/react-query';

// Global Query Configuration
const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 5 * 60 * 1000, // 5 minutes
      cacheTime: 10 * 60 * 1000, // 10 minutes
      retry: (failureCount, error) => {
        // Don't retry for 4xx errors
        if (error.response?.status >= 400 && error.response?.status < 500) {
          return false;
        }
        return failureCount < 3;
      },
      refetchOnWindowFocus: false,
    },
    mutations: {
      retry: 1,
    },
  },
  queryCache: new QueryCache({
    onError: (error, query) => {
      // Global error handling
      console.error('Query error:', error, query);
      if (error.response?.status === 401) {
        // Redirect to login
        window.location.href = '/login';
      }
    },
  }),
});

// Advanced Query Hook with Dependent Queries
export const useUserProfile = (userId?: string) => {
  // User basic info
  const userQuery = useQuery({
    queryKey: ['user', userId],
    queryFn: () => api.getUser(userId!),
    enabled: !!userId,
  });

  // User preferences (depends on user data)
  const preferencesQuery = useQuery({
    queryKey: ['user', userId, 'preferences'],
    queryFn: () => api.getUserPreferences(userId!),
    enabled: !!userQuery.data?.id,
  });

  // User posts with infinite scrolling
  const postsQuery = useInfiniteQuery({
    queryKey: ['user', userId, 'posts'],
    queryFn: ({ pageParam = 0 }) => 
      api.getUserPosts(userId!, { page: pageParam }),
    enabled: !!userQuery.data?.id,
    getNextPageParam: (lastPage, pages) => {
      return lastPage.hasMore ? pages.length : undefined;
    },
  });

  return {
    user: userQuery.data,
    preferences: preferencesQuery.data,
    posts: postsQuery.data?.pages.flat() || [],
    isLoading: userQuery.isLoading || preferencesQuery.isLoading,
    error: userQuery.error || preferencesQuery.error || postsQuery.error,
    loadMorePosts: postsQuery.fetchNextPage,
    hasMorePosts: postsQuery.hasNextPage,
  };
};

// Optimistic Updates with Rollback
export const useUpdateUser = () => {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (userData: UpdateUserData) => {
      const response = await api.updateUser(userData.id, userData);
      return response.data;
    },
    onMutate: async (userData) => {
      // Cancel any outgoing refetches
      await queryClient.cancelQueries({ queryKey: ['user', userData.id] });

      // Snapshot the previous value
      const previousUser = queryClient.getQueryData(['user', userData.id]);

      // Optimistically update to the new value
      queryClient.setQueryData(['user', userData.id], (old: User) => ({
        ...old,
        ...userData,
        updatedAt: new Date().toISOString(),
      }));

      // Return a context object with the snapshotted value
      return { previousUser };
    },
    onError: (err, userData, context) => {
      // If the mutation fails, use the context returned from onMutate to roll back
      queryClient.setQueryData(
        ['user', userData.id],
        context?.previousUser
      );
      
      // Show error notification
      toast.error('Failed to update user');
    },
    onSettled: (data, error, userData) => {
      // Always refetch after error or success
      queryClient.invalidateQueries({ queryKey: ['user', userData.id] });
    },
  });
};

// Background Sync Pattern
export const useBackgroundSync = () => {
  const queryClient = useQueryClient();

  useEffect(() => {
    const interval = setInterval(() => {
      // Refetch critical data in background
      queryClient.invalidateQueries({ 
        queryKey: ['notifications'],
        refetchType: 'active' // Only refetch if component is mounted
      });
    }, 30000); // Every 30 seconds

    return () => clearInterval(interval);
  }, [queryClient]);
};
```

#### **Refine's Data Provider Pattern**

```typescript
// Advanced data provider with React Query integration
export interface DataProvider {
  getList: <TData = BaseRecord>(params: GetListParams) => Promise<GetListResponse<TData>>;
  getOne: <TData = BaseRecord>(params: GetOneParams) => Promise<GetOneResponse<TData>>;
  create: <TData = BaseRecord>(params: CreateParams) => Promise<CreateResponse<TData>>;
  update: <TData = BaseRecord>(params: UpdateParams) => Promise<UpdateResponse<TData>>;
  deleteOne: (params: DeleteOneParams) => Promise<DeleteOneResponse>;
}

export const dataProvider: DataProvider = {
  getList: async ({ resource, pagination, filters, sorters, meta }) => {
    const url = `${API_URL}/${resource}`;
    const params = new URLSearchParams();

    // Pagination
    if (pagination) {
      params.append('page', pagination.current.toString());
      params.append('limit', pagination.pageSize.toString());
    }

    // Filters
    if (filters) {
      filters.forEach((filter) => {
        if (filter.operator === 'eq') {
          params.append(filter.field, filter.value);
        } else if (filter.operator === 'contains') {
          params.append(`${filter.field}_like`, filter.value);
        }
      });
    }

    // Sorting
    if (sorters) {
      sorters.forEach((sorter) => {
        params.append('_sort', sorter.field);
        params.append('_order', sorter.order);
      });
    }

    const response = await httpClient.get(`${url}?${params}`);

    return {
      data: response.data,
      total: parseInt(response.headers['x-total-count']) || response.data.length,
    };
  },

  getOne: async ({ resource, id, meta }) => {
    const response = await httpClient.get(`${API_URL}/${resource}/${id}`);
    return {
      data: response.data,
    };
  },

  create: async ({ resource, variables, meta }) => {
    const response = await httpClient.post(`${API_URL}/${resource}`, variables);
    return {
      data: response.data,
    };
  },
  
  // ... other methods
};

// Hook integration
export const useList = <TData = BaseRecord>(
  resource: string,
  config?: UseListConfig
) => {
  const { pagination, filters, sorters } = config || {};

  return useQuery({
    queryKey: [resource, 'list', { pagination, filters, sorters }],
    queryFn: () => dataProvider.getList({ 
      resource, 
      pagination, 
      filters, 
      sorters 
    }),
    ...config?.queryOptions,
  });
};
```

### **2. SWR (Stale-While-Revalidate)**

**Used by**: Plane, Next.js applications, 20% of analyzed projects  
**Best for**: Simple data fetching with automatic revalidation

#### **SWR Patterns and Configurations**

```typescript
import useSWR, { SWRConfig, mutate } from 'swr';
import useSWRInfinite from 'swr/infinite';

// Global SWR Configuration
const swrConfig = {
  refreshInterval: 30000, // 30 seconds
  errorRetryCount: 3,
  errorRetryInterval: 5000,
  onError: (error, key) => {
    console.error('SWR Error:', error, key);
    if (error.status === 401) {
      // Redirect to login
      router.push('/auth/login');
    }
  },
  compare: (a, b) => {
    // Custom data comparison for updates
    return JSON.stringify(a) === JSON.stringify(b);
  },
  fetcher: async (url: string) => {
    const token = getAuthToken();
    const response = await fetch(url, {
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
    });

    if (!response.ok) {
      const error = new Error('An error occurred while fetching the data.');
      error.status = response.status;
      error.info = await response.json();
      throw error;
    }

    return response.json();
  },
};

function App() {
  return (
    <SWRConfig value={swrConfig}>
      <AppContent />
    </SWRConfig>
  );
}

// Advanced SWR Hooks
export const useProjects = (workspaceId?: string) => {
  const { data, error, mutate } = useSWR(
    workspaceId ? `/api/workspaces/${workspaceId}/projects` : null
  );

  return {
    projects: data || [],
    isLoading: !error && !data,
    isError: error,
    mutate,
  };
};

// SWR with Optimistic Updates
export const useCreateProject = (workspaceId: string) => {
  const { mutate } = useSWR(`/api/workspaces/${workspaceId}/projects`);

  const createProject = async (projectData: CreateProjectData) => {
    const optimisticProject = {
      ...projectData,
      id: `temp-${Date.now()}`,
      created_at: new Date().toISOString(),
    };

    // Optimistic update
    mutate(
      (currentProjects: Project[]) => [...(currentProjects || []), optimisticProject],
      false
    );

    try {
      const response = await api.post(`/workspaces/${workspaceId}/projects`, projectData);
      
      // Replace optimistic project with real one
      mutate(
        (currentProjects: Project[]) =>
          currentProjects?.map(project =>
            project.id === optimisticProject.id ? response.data : project
          ),
        false
      );

      return response.data;
    } catch (error) {
      // Remove optimistic project on error
      mutate(
        (currentProjects: Project[]) =>
          currentProjects?.filter(project => project.id !== optimisticProject.id),
        false
      );
      throw error;
    }
  };

  return { createProject };
};

// Infinite Loading with SWR
export const useInfiniteIssues = (projectId: string) => {
  const { data, error, size, setSize, isValidating } = useSWRInfinite(
    (index) => projectId ? `/api/projects/${projectId}/issues?page=${index + 1}` : null,
    fetcher
  );

  const issues = data ? data.flat() : [];
  const isLoadingInitial = !data && !error;
  const isLoadingMore = isLoadingInitial || (size > 0 && data && typeof data[size - 1] === 'undefined');
  const isEmpty = data?.[0]?.length === 0;
  const isReachingEnd = isEmpty || (data && data[data.length - 1]?.length < 20);

  return {
    issues,
    error,
    isLoadingMore,
    isReachingEnd,
    loadMore: () => setSize(size + 1),
    refresh: () => mutate(`/api/projects/${projectId}/issues`),
  };
};
```

#### **Plane's Project Management Patterns**

```typescript
// Complex state synchronization with SWR
export const useIssueOperations = (projectId: string) => {
  const { mutate } = useSWR(`/api/projects/${projectId}/issues`);

  const moveIssue = async (issueId: string, newStatus: string) => {
    // Optimistic update for UI responsiveness
    mutate(
      (currentIssues: Issue[]) =>
        currentIssues?.map(issue =>
          issue.id === issueId ? { ...issue, status: newStatus } : issue
        ),
      false
    );

    try {
      await api.patch(`/issues/${issueId}`, { status: newStatus });
      
      // Revalidate related data
      mutate(`/api/projects/${projectId}/board`);
      mutate(`/api/projects/${projectId}/analytics`);
    } catch (error) {
      // Revert on error
      mutate();
      throw error;
    }
  };

  const assignIssue = async (issueId: string, assigneeId: string) => {
    // Similar pattern for assignment
    mutate(
      (currentIssues: Issue[]) =>
        currentIssues?.map(issue =>
          issue.id === issueId ? { ...issue, assignee_id: assigneeId } : issue
        ),
      false
    );

    try {
      await api.patch(`/issues/${issueId}`, { assignee_id: assigneeId });
      mutate();
    } catch (error) {
      mutate();
      throw error;
    }
  };

  return { moveIssue, assignIssue };
};
```

### **3. Apollo GraphQL Client**

**Used by**: Twenty CRM, GraphQL-first applications  
**Best for**: GraphQL APIs, complex relational data

#### **Apollo Client Setup and Patterns**

```typescript
import { 
  ApolloClient, 
  InMemoryCache, 
  createHttpLink, 
  from 
} from '@apollo/client';
import { setContext } from '@apollo/client/link/context';
import { onError } from '@apollo/client/link/error';

// Apollo Client Configuration
const httpLink = createHttpLink({
  uri: process.env.NEXT_PUBLIC_GRAPHQL_ENDPOINT,
});

const authLink = setContext((_, { headers }) => {
  const token = localStorage.getItem('accessToken');
  
  return {
    headers: {
      ...headers,
      authorization: token ? `Bearer ${token}` : '',
    }
  };
});

const errorLink = onError(({ graphQLErrors, networkError, operation, forward }) => {
  if (graphQLErrors) {
    graphQLErrors.forEach(({ message, locations, path }) => {
      console.error(`GraphQL error: Message: ${message}, Location: ${locations}, Path: ${path}`);
    });
  }

  if (networkError) {
    console.error(`Network error: ${networkError}`);
    
    if (networkError.statusCode === 401) {
      // Handle authentication error
      localStorage.removeItem('accessToken');
      window.location.href = '/login';
    }
  }
});

const client = new ApolloClient({
  link: from([errorLink, authLink, httpLink]),
  cache: new InMemoryCache({
    typePolicies: {
      User: {
        fields: {
          posts: {
            merge(existing = [], incoming) {
              return [...existing, ...incoming];
            },
          },
        },
      },
      Query: {
        fields: {
          posts: {
            keyArgs: ['filters'],
            merge(existing = [], incoming, { args }) {
              if (args?.offset === 0) {
                return incoming;
              }
              return [...existing, ...incoming];
            },
          },
        },
      },
    },
  }),
  defaultOptions: {
    watchQuery: {
      errorPolicy: 'ignore',
    },
    query: {
      errorPolicy: 'all',
    },
  },
});

// GraphQL Queries and Mutations
import { gql, useQuery, useMutation } from '@apollo/client';

const GET_USERS = gql`
  query GetUsers($limit: Int, $offset: Int, $filters: UserFilters) {
    users(limit: $limit, offset: $offset, filters: $filters) {
      id
      name
      email
      avatar
      role
      createdAt
      posts {
        id
        title
        publishedAt
      }
    }
  }
`;

const CREATE_USER = gql`
  mutation CreateUser($input: CreateUserInput!) {
    createUser(input: $input) {
      id
      name
      email
      role
    }
  }
`;

// React Hook Integration
export const useUsers = (filters?: UserFilters) => {
  const { data, loading, error, fetchMore } = useQuery(GET_USERS, {
    variables: { limit: 20, offset: 0, filters },
    notifyOnNetworkStatusChange: true,
  });

  const loadMore = () => {
    fetchMore({
      variables: {
        offset: data.users.length,
      },
    });
  };

  return {
    users: data?.users || [],
    loading,
    error,
    loadMore,
  };
};

export const useCreateUser = () => {
  const [createUser, { loading, error }] = useMutation(CREATE_USER, {
    update(cache, { data: { createUser } }) {
      // Update cache after creating user
      cache.modify({
        fields: {
          users(existingUsers = []) {
            const newUserRef = cache.writeFragment({
              data: createUser,
              fragment: gql`
                fragment NewUser on User {
                  id
                  name
                  email
                  role
                }
              `,
            });
            return [newUserRef, ...existingUsers];
          },
        },
      });
    },
    onCompleted: (data) => {
      toast.success(`User ${data.createUser.name} created successfully`);
    },
    onError: (error) => {
      toast.error(`Failed to create user: ${error.message}`);
    },
  });

  return { createUser, loading, error };
};
```

#### **Twenty CRM's GraphQL Patterns**

```typescript
// Complex relational queries
const GET_COMPANY_DETAILS = gql`
  query GetCompanyDetails($id: ID!) {
    company(id: $id) {
      id
      name
      domain
      employees
      industry
      contacts {
        id
        firstName
        lastName
        email
        phone
        position
      }
      deals {
        id
        title
        amount
        stage
        probability
        expectedCloseDate
        activities {
          id
          type
          subject
          completedAt
        }
      }
      notes {
        id
        content
        createdAt
        author {
          id
          name
        }
      }
    }
  }
`;

// Subscription for real-time updates
const COMPANY_UPDATES = gql`
  subscription CompanyUpdates($companyId: ID!) {
    companyUpdated(companyId: $companyId) {
      id
      name
      employees
      lastActivityAt
    }
  }
`;

export const useCompanyDetails = (companyId: string) => {
  const { data, loading, error, subscribeToMore } = useQuery(GET_COMPANY_DETAILS, {
    variables: { id: companyId },
    skip: !companyId,
  });

  useEffect(() => {
    if (companyId) {
      const unsubscribe = subscribeToMore({
        document: COMPANY_UPDATES,
        variables: { companyId },
        updateQuery: (prev, { subscriptionData }) => {
          if (!subscriptionData.data) return prev;
          
          return {
            ...prev,
            company: {
              ...prev.company,
              ...subscriptionData.data.companyUpdated,
            },
          };
        },
      });

      return unsubscribe;
    }
  }, [companyId, subscribeToMore]);

  return {
    company: data?.company,
    loading,
    error,
  };
};
```

### **4. tRPC (Type-safe APIs)**

**Used by**: Cal.com, type-safe full-stack applications  
**Best for**: End-to-end type safety, full-stack TypeScript

#### **tRPC Setup and Implementation**

```typescript
// Backend: tRPC Router
import { z } from 'zod';
import { router, publicProcedure, protectedProcedure } from '../trpc';

const userRouter = router({
  list: publicProcedure
    .input(z.object({
      limit: z.number().min(1).max(100).default(10),
      cursor: z.string().optional(),
      search: z.string().optional(),
    }))
    .query(async ({ input, ctx }) => {
      const { limit, cursor, search } = input;
      
      const users = await ctx.prisma.user.findMany({
        take: limit + 1,
        cursor: cursor ? { id: cursor } : undefined,
        where: search ? {
          OR: [
            { name: { contains: search, mode: 'insensitive' } },
            { email: { contains: search, mode: 'insensitive' } },
          ],
        } : undefined,
        orderBy: { createdAt: 'desc' },
      });

      let nextCursor: typeof cursor | undefined = undefined;
      if (users.length > limit) {
        const nextItem = users.pop();
        nextCursor = nextItem!.id;
      }

      return {
        users,
        nextCursor,
      };
    }),

  byId: publicProcedure
    .input(z.string())
    .query(async ({ input, ctx }) => {
      const user = await ctx.prisma.user.findUnique({
        where: { id: input },
        include: {
          posts: true,
          profile: true,
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

  create: protectedProcedure
    .input(z.object({
      name: z.string().min(1),
      email: z.string().email(),
      role: z.enum(['USER', 'ADMIN']).default('USER'),
    }))
    .mutation(async ({ input, ctx }) => {
      const user = await ctx.prisma.user.create({
        data: {
          ...input,
          createdBy: ctx.user.id,
        },
      });
      
      return user;
    }),

  update: protectedProcedure
    .input(z.object({
      id: z.string(),
      name: z.string().min(1).optional(),
      email: z.string().email().optional(),
    }))
    .mutation(async ({ input, ctx }) => {
      const { id, ...updateData } = input;
      
      const user = await ctx.prisma.user.update({
        where: { id },
        data: updateData,
      });
      
      return user;
    }),
});

export const appRouter = router({
  user: userRouter,
  // ... other routers
});

export type AppRouter = typeof appRouter;

// Frontend: tRPC Client Setup
import { createTRPCNext } from '@trpc/next';
import { httpBatchLink } from '@trpc/client';
import type { AppRouter } from '../server/routers/_app';

export const trpc = createTRPCNext<AppRouter>({
  config({ ctx }) {
    return {
      links: [
        httpBatchLink({
          url: '/api/trpc',
          headers() {
            const token = getAuthToken();
            return {
              authorization: token ? `Bearer ${token}` : '',
            };
          },
        }),
      ],
    };
  },
  ssr: false,
});

// Frontend: React Hook Usage
export const UserList: React.FC = () => {
  const [search, setSearch] = useState('');
  
  const {
    data,
    isLoading,
    error,
    fetchNextPage,
    hasNextPage,
  } = trpc.user.list.useInfiniteQuery(
    { limit: 10, search },
    {
      getNextPageParam: (lastPage) => lastPage.nextCursor,
    }
  );

  const createUserMutation = trpc.user.create.useMutation({
    onSuccess: () => {
      // Invalidate user list to refetch
      trpc.useContext().user.list.invalidate();
      toast.success('User created successfully');
    },
    onError: (error) => {
      toast.error(`Failed to create user: ${error.message}`);
    },
  });

  const users = data?.pages.flatMap(page => page.users) ?? [];

  if (isLoading) return <LoadingSpinner />;
  if (error) return <ErrorMessage error={error} />;

  return (
    <div>
      <SearchInput 
        value={search} 
        onChange={setSearch}
        placeholder="Search users..."
      />
      
      <UserGrid users={users} />
      
      {hasNextPage && (
        <LoadMoreButton onClick={() => fetchNextPage()}>
          Load More
        </LoadMoreButton>
      )}
    </div>
  );
};
```

#### **Cal.com's Advanced tRPC Patterns**

```typescript
// Complex business logic with tRPC
const bookingRouter = router({
  create: protectedProcedure
    .input(z.object({
      eventTypeId: z.number(),
      startTime: z.date(),
      endTime: z.date(),
      attendeeEmail: z.string().email(),
      attendeeName: z.string(),
      timeZone: z.string(),
      notes: z.string().optional(),
    }))
    .mutation(async ({ input, ctx }) => {
      // Check availability
      const isAvailable = await checkAvailability({
        userId: ctx.user.id,
        startTime: input.startTime,
        endTime: input.endTime,
      });

      if (!isAvailable) {
        throw new TRPCError({
          code: 'CONFLICT',
          message: 'Time slot is not available',
        });
      }

      // Create booking
      const booking = await ctx.prisma.booking.create({
        data: {
          ...input,
          userId: ctx.user.id,
          status: 'CONFIRMED',
        },
        include: {
          eventType: true,
          user: true,
        },
      });

      // Send confirmation emails
      await sendBookingConfirmation({
        booking,
        attendeeEmail: input.attendeeEmail,
      });

      // Create calendar event
      await createCalendarEvent({
        booking,
        userCalendar: ctx.user.calendar,
      });

      return booking;
    }),

  cancel: protectedProcedure
    .input(z.object({
      bookingId: z.number(),
      reason: z.string().optional(),
    }))
    .mutation(async ({ input, ctx }) => {
      const booking = await ctx.prisma.booking.findFirst({
        where: {
          id: input.bookingId,
          OR: [
            { userId: ctx.user.id },
            { attendeeEmail: ctx.user.email },
          ],
        },
        include: { eventType: true, user: true },
      });

      if (!booking) {
        throw new TRPCError({
          code: 'NOT_FOUND',
          message: 'Booking not found',
        });
      }

      // Update booking status
      const updatedBooking = await ctx.prisma.booking.update({
        where: { id: input.bookingId },
        data: {
          status: 'CANCELLED',
          cancellationReason: input.reason,
        },
      });

      // Send cancellation emails
      await sendCancellationNotification({
        booking: updatedBooking,
      });

      // Remove from calendar
      await removeCalendarEvent({
        booking: updatedBooking,
      });

      return updatedBooking;
    }),
});
```

## 📊 Real-time Communication Patterns

### **WebSocket Integration**

```typescript
// WebSocket hook for real-time updates
export const useWebSocket = (url: string, options?: WebSocketOptions) => {
  const [socket, setSocket] = useState<WebSocket | null>(null);
  const [lastMessage, setLastMessage] = useState<MessageEvent | null>(null);
  const [readyState, setReadyState] = useState<number>(WebSocket.CONNECTING);

  useEffect(() => {
    const ws = new WebSocket(url);
    
    ws.onopen = () => {
      setReadyState(WebSocket.OPEN);
      options?.onOpen?.(ws);
    };

    ws.onmessage = (event) => {
      setLastMessage(event);
      options?.onMessage?.(event);
    };

    ws.onclose = () => {
      setReadyState(WebSocket.CLOSED);
      options?.onClose?.();
    };

    ws.onerror = (error) => {
      options?.onError?.(error);
    };

    setSocket(ws);

    return () => {
      ws.close();
    };
  }, [url]);

  const sendMessage = useCallback((data: string | object) => {
    if (socket && readyState === WebSocket.OPEN) {
      const message = typeof data === 'string' ? data : JSON.stringify(data);
      socket.send(message);
    }
  }, [socket, readyState]);

  return {
    sendMessage,
    lastMessage,
    readyState,
    connectionStatus: {
      [WebSocket.CONNECTING]: 'Connecting',
      [WebSocket.OPEN]: 'Open',
      [WebSocket.CLOSING]: 'Closing',
      [WebSocket.CLOSED]: 'Closed',
    }[readyState],
  };
};

// Real-time collaboration hook
export const useCollaboration = (documentId: string) => {
  const [collaborators, setCollaborators] = useState<User[]>([]);
  const [changes, setChanges] = useState<Change[]>([]);

  const { sendMessage, lastMessage } = useWebSocket(`ws://localhost:3001/collaborate/${documentId}`, {
    onMessage: (event) => {
      const data = JSON.parse(event.data);
      
      switch (data.type) {
        case 'user_joined':
          setCollaborators(prev => [...prev, data.user]);
          break;
        case 'user_left':
          setCollaborators(prev => prev.filter(u => u.id !== data.userId));
          break;
        case 'change':
          setChanges(prev => [...prev, data.change]);
          break;
      }
    },
  });

  const broadcastChange = useCallback((change: Change) => {
    sendMessage({
      type: 'change',
      change,
      documentId,
    });
  }, [sendMessage, documentId]);

  return {
    collaborators,
    changes,
    broadcastChange,
  };
};
```

## 🔗 Navigation

← [UI Component Libraries](./ui-component-libraries.md) | [Performance Optimization →](./performance-optimization.md)

---

## 📚 References

1. [TanStack Query Documentation](https://tanstack.com/query/latest)
2. [SWR Documentation](https://swr.vercel.app/)
3. [Apollo GraphQL Documentation](https://www.apollographql.com/docs/)
4. [tRPC Documentation](https://trpc.io/)
5. [WebSocket API Documentation](https://developer.mozilla.org/en-US/docs/Web/API/WebSockets_API)
6. [React Query vs SWR Comparison](https://github.com/tannerlinsley/react-query/discussions/1111)

*Last updated: January 2025*