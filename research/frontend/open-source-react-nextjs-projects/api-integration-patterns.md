# API Integration Patterns in Open Source React/Next.js Projects

## Overview

This document analyzes backend API integration strategies used in production React and Next.js applications. It covers data fetching patterns, API layer architecture, error handling, caching strategies, and real-time communication patterns extracted from successful open source projects.

## Data Fetching Architecture Patterns

### 1. TanStack Query Integration (Cal.com Pattern)

**Query Factory Pattern**:
```typescript
// lib/query-factory.ts
export const createQueryFactory = <T extends Record<string, any>>(entityName: string) => ({
  all: [entityName] as const,
  lists: () => [...createQueryFactory(entityName).all, 'list'] as const,
  list: (filters: T) => [...createQueryFactory(entityName).lists(), { filters }] as const,
  details: () => [...createQueryFactory(entityName).all, 'detail'] as const,
  detail: (id: string) => [...createQueryFactory(entityName).details(), id] as const,
  infinite: (filters: T) => [...createQueryFactory(entityName).all, 'infinite', { filters }] as const,
});

// Usage examples
export const bookingKeys = createQueryFactory<{ 
  userId?: string; 
  status?: string; 
  dateRange?: [Date, Date] 
}>('bookings');

export const userKeys = createQueryFactory<{ 
  role?: string; 
  search?: string 
}>('users');

// Hook implementation with advanced patterns
export function useBookings(filters?: BookingFilters) {
  return useQuery({
    queryKey: bookingKeys.list(filters || {}),
    queryFn: ({ signal }) => 
      apiClient.get<Booking[]>('/bookings', { 
        params: filters,
        signal, // Abort signal for cleanup
      }),
    staleTime: 2 * 60 * 1000, // 2 minutes
    gcTime: 5 * 60 * 1000, // 5 minutes
    retry: (failureCount, error: any) => {
      // Don't retry on client errors
      if (error?.status >= 400 && error?.status < 500) return false;
      return failureCount < 3;
    },
    retryDelay: (attemptIndex) => Math.min(1000 * 2 ** attemptIndex, 30000),
    refetchOnWindowFocus: false,
    refetchOnReconnect: true,
  });
}
```

**Optimistic Updates with Rollback**:
```typescript
// Advanced mutation with optimistic updates
export function useCreateBooking() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (data: CreateBookingData) => {
      const response = await apiClient.post<Booking>('/bookings', data);
      
      // Send confirmation email in background
      apiClient.post('/bookings/send-confirmation', { bookingId: response.id })
        .catch(error => console.warn('Failed to send confirmation:', error));
      
      return response;
    },
    onMutate: async (newBooking) => {
      // Cancel outgoing refetches
      await queryClient.cancelQueries({ queryKey: bookingKeys.lists() });
      await queryClient.cancelQueries({ queryKey: bookingKeys.detail(newBooking.eventId) });

      // Snapshot previous values
      const previousBookings = queryClient.getQueryData(bookingKeys.lists());
      const previousEvent = queryClient.getQueryData(bookingKeys.detail(newBooking.eventId));

      // Optimistic update - add new booking
      const optimisticBooking: Booking = {
        id: `temp-${Date.now()}`,
        ...newBooking,
        status: 'confirmed',
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      };

      queryClient.setQueriesData(
        { queryKey: bookingKeys.lists() },
        (old: Booking[] = []) => [optimisticBooking, ...old]
      );

      // Update available slots if event data is cached
      if (previousEvent) {
        queryClient.setQueryData(
          bookingKeys.detail(newBooking.eventId),
          (old: Event) => ({
            ...old,
            availableSlots: old.availableSlots.filter(
              slot => slot.time !== newBooking.timeSlot
            ),
          })
        );
      }

      return { previousBookings, previousEvent, optimisticBooking };
    },
    onError: (err, newBooking, context) => {
      // Rollback optimistic updates
      if (context?.previousBookings) {
        queryClient.setQueriesData(
          { queryKey: bookingKeys.lists() },
          context.previousBookings
        );
      }
      if (context?.previousEvent) {
        queryClient.setQueryData(
          bookingKeys.detail(newBooking.eventId),
          context.previousEvent
        );
      }
      
      // Show error notification
      toast.error('Failed to create booking. Please try again.');
    },
    onSuccess: (data, variables, context) => {
      // Replace optimistic data with real data
      queryClient.setQueriesData(
        { queryKey: bookingKeys.lists() },
        (old: Booking[] = []) => 
          old.map(booking => 
            booking.id === context?.optimisticBooking.id ? data : booking
          )
      );
      
      // Show success notification
      toast.success('Booking created successfully!');
    },
    onSettled: (data, error, variables) => {
      // Always refetch to ensure consistency
      queryClient.invalidateQueries({ queryKey: bookingKeys.lists() });
      queryClient.invalidateQueries({ queryKey: bookingKeys.detail(variables.eventId) });
    },
  });
}
```

### 2. SWR Integration (Vercel Commerce Pattern)

**Global Configuration with Middleware**:
```typescript
// lib/swr-config.ts
import useSWR, { SWRConfig, mutate } from 'swr';
import { apiClient } from './api-client';

// Global SWR configuration
export const swrConfig = {
  refreshInterval: 0,
  revalidateOnFocus: false,
  revalidateOnReconnect: true,
  shouldRetryOnError: (error: any) => {
    // Don't retry on 4xx errors
    return error?.status >= 500;
  },
  errorRetryCount: 3,
  errorRetryInterval: 5000,
  fetcher: (url: string) => apiClient.get(url),
  onError: (error: any, key: string) => {
    if (error?.status === 401) {
      // Redirect to login on unauthorized
      window.location.href = '/auth/login';
    }
    
    // Log error for monitoring
    console.error(`SWR Error for ${key}:`, error);
  },
};

// SWR Provider wrapper
export function SWRProvider({ children }: { children: React.ReactNode }) {
  return <SWRConfig value={swrConfig}>{children}</SWRConfig>;
}

// Custom hooks with SWR
export function useProducts(filters?: ProductFilters) {
  const searchParams = new URLSearchParams(filters as any).toString();
  const key = `/products${searchParams ? `?${searchParams}` : ''}`;
  
  const { data, error, mutate: revalidate } = useSWR<Product[]>(
    key,
    (url) => apiClient.get<Product[]>(url),
    {
      dedupingInterval: 10000, // Dedupe requests within 10 seconds
      focusThrottleInterval: 5000, // Throttle revalidation on focus
    }
  );

  return {
    products: data,
    isLoading: !error && !data,
    isError: error,
    isEmpty: data && data.length === 0,
    revalidate,
  };
}

// Infinite loading with SWR
export function useInfiniteProducts(filters?: ProductFilters) {
  const getKey = (pageIndex: number, previousPageData: Product[]) => {
    // Reached the end
    if (previousPageData && !previousPageData.length) return null;
    
    // First page
    if (pageIndex === 0) {
      const searchParams = new URLSearchParams(filters as any).toString();
      return `/products${searchParams ? `?${searchParams}` : ''}`;
    }
    
    // Add page parameter
    const params = new URLSearchParams({
      ...filters,
      page: (pageIndex + 1).toString(),
    } as any);
    return `/products?${params.toString()}`;
  };

  const { data, error, size, setSize, mutate } = useSWRInfinite<Product[]>(
    getKey,
    (url) => apiClient.get<Product[]>(url)
  );

  const products = data ? data.flat() : [];
  const isLoadingInitial = !data && !error;
  const isLoadingMore = data && typeof data[size - 1] === 'undefined';
  const isEmpty = data?.[0]?.length === 0;
  const isReachingEnd = isEmpty || (data && data[data.length - 1]?.length < 20);
  const isRefreshing = data && data.length === size;

  return {
    products,
    error,
    isLoadingInitial,
    isLoadingMore,
    isEmpty,
    isReachingEnd,
    isRefreshing,
    loadMore: () => setSize(size + 1),
    refresh: () => mutate(),
  };
}
```

### 3. GraphQL Integration (Twenty CRM Pattern)

**Apollo Client Setup with Type Safety**:
```typescript
// lib/apollo-client.ts
import { ApolloClient, InMemoryCache, createHttpLink, from } from '@apollo/client';
import { setContext } from '@apollo/client/link/context';
import { onError } from '@apollo/client/link/error';
import { RetryLink } from '@apollo/client/link/retry';

// HTTP Link
const httpLink = createHttpLink({
  uri: process.env.NEXT_PUBLIC_GRAPHQL_ENDPOINT,
});

// Auth Link
const authLink = setContext((_, { headers }) => {
  const token = localStorage.getItem('access_token');
  
  return {
    headers: {
      ...headers,
      authorization: token ? `Bearer ${token}` : '',
    },
  };
});

// Error Link
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
      localStorage.removeItem('access_token');
      window.location.href = '/auth/login';
    }
  }
});

// Retry Link
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

// Cache configuration
const cache = new InMemoryCache({
  typePolicies: {
    User: {
      fields: {
        projects: {
          merge(existing = [], incoming: any[]) {
            return [...existing, ...incoming];
          },
        },
      },
    },
    Project: {
      fields: {
        tasks: {
          merge(existing = [], incoming: any[]) {
            return [...existing, ...incoming];
          },
        },
      },
    },
  },
});

export const apolloClient = new ApolloClient({
  link: from([errorLink, retryLink, authLink, httpLink]),
  cache,
  defaultOptions: {
    watchQuery: {
      errorPolicy: 'all',
    },
    query: {
      errorPolicy: 'all',
    },
  },
});

// Generated GraphQL hooks with codegen
// hooks/graphql.ts (generated)
import { gql } from '@apollo/client';
import * as Apollo from '@apollo/client';

export const GetProjectsDocument = gql`
  query GetProjects($filter: ProjectFilter, $sort: ProjectSort) {
    projects(filter: $filter, sort: $sort) {
      id
      name
      description
      status
      createdAt
      updatedAt
      owner {
        id
        name
        email
      }
      members {
        id
        user {
          id
          name
          email
        }
        role
      }
      tasks {
        id
        title
        status
        assignee {
          id
          name
        }
      }
    }
  }
`;

export function useGetProjectsQuery(
  baseOptions?: Apollo.QueryHookOptions<GetProjectsQuery, GetProjectsQueryVariables>
) {
  const options = { ...defaultOptions, ...baseOptions };
  return Apollo.useQuery<GetProjectsQuery, GetProjectsQueryVariables>(
    GetProjectsDocument,
    options
  );
}

// Custom hook with enhanced functionality
export function useProjects(filters?: ProjectFilters) {
  const { data, loading, error, refetch, fetchMore } = useGetProjectsQuery({
    variables: { filter: filters },
    notifyOnNetworkStatusChange: true,
    errorPolicy: 'all',
  });

  const loadMore = useCallback(() => {
    return fetchMore({
      variables: {
        filter: {
          ...filters,
          offset: data?.projects?.length || 0,
        },
      },
      updateQuery: (prev, { fetchMoreResult }) => {
        if (!fetchMoreResult) return prev;
        
        return {
          projects: [...(prev.projects || []), ...(fetchMoreResult.projects || [])],
        };
      },
    });
  }, [fetchMore, data?.projects?.length, filters]);

  return {
    projects: data?.projects || [],
    loading,
    error,
    refetch,
    loadMore,
  };
}
```

## Real-time Communication Patterns

### 1. WebSocket Integration (Plane Pattern)

**WebSocket Manager with Reconnection**:
```typescript
// lib/websocket-manager.ts
export class WebSocketManager {
  private ws: WebSocket | null = null;
  private url: string;
  private reconnectAttempts = 0;
  private maxReconnectAttempts = 5;
  private reconnectInterval = 1000;
  private heartbeatInterval: NodeJS.Timeout | null = null;
  private isConnecting = false;
  private listeners = new Map<string, Set<Function>>();

  constructor(url: string) {
    this.url = url;
  }

  connect(): Promise<void> {
    if (this.ws?.readyState === WebSocket.OPEN || this.isConnecting) {
      return Promise.resolve();
    }

    this.isConnecting = true;

    return new Promise((resolve, reject) => {
      try {
        const token = localStorage.getItem('access_token');
        const wsUrl = `${this.url}?token=${token}`;
        
        this.ws = new WebSocket(wsUrl);

        this.ws.onopen = () => {
          console.log('WebSocket connected');
          this.isConnecting = false;
          this.reconnectAttempts = 0;
          this.startHeartbeat();
          resolve();
        };

        this.ws.onmessage = (event) => {
          try {
            const data = JSON.parse(event.data);
            this.handleMessage(data);
          } catch (error) {
            console.error('Failed to parse WebSocket message:', error);
          }
        };

        this.ws.onclose = (event) => {
          console.log('WebSocket disconnected:', event.code, event.reason);
          this.isConnecting = false;
          this.stopHeartbeat();
          
          // Attempt reconnection unless it was a normal closure
          if (event.code !== 1000) {
            this.attemptReconnect();
          }
        };

        this.ws.onerror = (error) => {
          console.error('WebSocket error:', error);
          this.isConnecting = false;
          reject(error);
        };
      } catch (error) {
        this.isConnecting = false;
        reject(error);
      }
    });
  }

  private handleMessage(data: any) {
    const { type, payload } = data;
    const eventListeners = this.listeners.get(type);
    
    if (eventListeners) {
      eventListeners.forEach(callback => {
        try {
          callback(payload);
        } catch (error) {
          console.error('Error in WebSocket event listener:', error);
        }
      });
    }
  }

  private attemptReconnect() {
    if (this.reconnectAttempts >= this.maxReconnectAttempts) {
      console.error('Max reconnection attempts reached');
      return;
    }

    this.reconnectAttempts++;
    const delay = this.reconnectInterval * Math.pow(2, this.reconnectAttempts - 1);
    
    console.log(`Attempting to reconnect in ${delay}ms (attempt ${this.reconnectAttempts})`);
    
    setTimeout(() => {
      this.connect().catch(error => {
        console.error('Reconnection failed:', error);
      });
    }, delay);
  }

  private startHeartbeat() {
    this.heartbeatInterval = setInterval(() => {
      if (this.ws?.readyState === WebSocket.OPEN) {
        this.ws.send(JSON.stringify({ type: 'ping' }));
      }
    }, 30000); // 30 seconds
  }

  private stopHeartbeat() {
    if (this.heartbeatInterval) {
      clearInterval(this.heartbeatInterval);
      this.heartbeatInterval = null;
    }
  }

  subscribe(event: string, callback: Function): () => void {
    if (!this.listeners.has(event)) {
      this.listeners.set(event, new Set());
    }
    
    this.listeners.get(event)!.add(callback);
    
    // Return unsubscribe function
    return () => {
      const eventListeners = this.listeners.get(event);
      if (eventListeners) {
        eventListeners.delete(callback);
        if (eventListeners.size === 0) {
          this.listeners.delete(event);
        }
      }
    };
  }

  send(type: string, payload: any) {
    if (this.ws?.readyState === WebSocket.OPEN) {
      this.ws.send(JSON.stringify({ type, payload }));
    } else {
      console.warn('WebSocket is not connected');
    }
  }

  disconnect() {
    this.stopHeartbeat();
    if (this.ws) {
      this.ws.close(1000, 'Manual disconnect');
      this.ws = null;
    }
  }
}

// React hook for WebSocket
export function useWebSocket(url: string) {
  const [manager] = useState(() => new WebSocketManager(url));
  const [isConnected, setIsConnected] = useState(false);

  useEffect(() => {
    manager.connect().then(() => {
      setIsConnected(true);
    }).catch(error => {
      console.error('Failed to connect WebSocket:', error);
      setIsConnected(false);
    });

    return () => {
      manager.disconnect();
      setIsConnected(false);
    };
  }, [manager]);

  const subscribe = useCallback((event: string, callback: Function) => {
    return manager.subscribe(event, callback);
  }, [manager]);

  const send = useCallback((type: string, payload: any) => {
    manager.send(type, payload);
  }, [manager]);

  return { isConnected, subscribe, send };
}

// Usage in components
export function useRealTimeUpdates(projectId: string) {
  const { isConnected, subscribe } = useWebSocket(
    process.env.NEXT_PUBLIC_WS_URL || 'ws://localhost:8080'
  );
  const queryClient = useQueryClient();

  useEffect(() => {
    if (!isConnected) return;

    const unsubscribes = [
      subscribe('task_created', (task: Task) => {
        queryClient.setQueryData(['tasks', projectId], (old: Task[] = []) => [
          task,
          ...old,
        ]);
      }),

      subscribe('task_updated', (task: Task) => {
        queryClient.setQueryData(['tasks', projectId], (old: Task[] = []) =>
          old.map(t => t.id === task.id ? task : t)
        );
      }),

      subscribe('task_deleted', (taskId: string) => {
        queryClient.setQueryData(['tasks', projectId], (old: Task[] = []) =>
          old.filter(t => t.id !== taskId)
        );
      }),
    ];

    return () => {
      unsubscribes.forEach(unsubscribe => unsubscribe());
    };
  }, [isConnected, subscribe, projectId, queryClient]);

  return { isConnected };
}
```

### 2. Server-Sent Events (Supabase Pattern)

**SSE Implementation with Auto-Reconnection**:
```typescript
// lib/sse-client.ts
export class SSEClient {
  private eventSource: EventSource | null = null;
  private url: string;
  private listeners = new Map<string, Set<(data: any) => void>>();
  private reconnectAttempts = 0;
  private maxReconnectAttempts = 5;
  private reconnectDelay = 1000;

  constructor(url: string) {
    this.url = url;
  }

  connect(): Promise<void> {
    return new Promise((resolve, reject) => {
      try {
        const token = localStorage.getItem('access_token');
        const urlWithAuth = `${this.url}?token=${encodeURIComponent(token || '')}`;
        
        this.eventSource = new EventSource(urlWithAuth);

        this.eventSource.onopen = () => {
          console.log('SSE connected');
          this.reconnectAttempts = 0;
          resolve();
        };

        this.eventSource.onmessage = (event) => {
          try {
            const data = JSON.parse(event.data);
            this.handleEvent(data.type, data.payload);
          } catch (error) {
            console.error('Failed to parse SSE message:', error);
          }
        };

        this.eventSource.onerror = (error) => {
          console.error('SSE error:', error);
          
          if (this.eventSource?.readyState === EventSource.CLOSED) {
            this.attemptReconnect();
          }
        };

        // Handle custom events
        this.eventSource.addEventListener('custom-event', (event) => {
          try {
            const data = JSON.parse(event.data);
            this.handleEvent('custom-event', data);
          } catch (error) {
            console.error('Failed to parse custom SSE event:', error);
          }
        });

      } catch (error) {
        reject(error);
      }
    });
  }

  private handleEvent(type: string, payload: any) {
    const listeners = this.listeners.get(type);
    if (listeners) {
      listeners.forEach(callback => {
        try {
          callback(payload);
        } catch (error) {
          console.error('Error in SSE event listener:', error);
        }
      });
    }
  }

  private attemptReconnect() {
    if (this.reconnectAttempts >= this.maxReconnectAttempts) {
      console.error('Max SSE reconnection attempts reached');
      return;
    }

    this.reconnectAttempts++;
    const delay = this.reconnectDelay * Math.pow(2, this.reconnectAttempts - 1);

    setTimeout(() => {
      this.connect().catch(error => {
        console.error('SSE reconnection failed:', error);
      });
    }, delay);
  }

  on(event: string, callback: (data: any) => void): () => void {
    if (!this.listeners.has(event)) {
      this.listeners.set(event, new Set());
    }
    
    this.listeners.get(event)!.add(callback);
    
    return () => {
      const eventListeners = this.listeners.get(event);
      if (eventListeners) {
        eventListeners.delete(callback);
        if (eventListeners.size === 0) {
          this.listeners.delete(event);
        }
      }
    };
  }

  disconnect() {
    if (this.eventSource) {
      this.eventSource.close();
      this.eventSource = null;
    }
    this.listeners.clear();
  }
}

// React hook for SSE
export function useServerSentEvents(endpoint: string) {
  const [client] = useState(() => new SSEClient(endpoint));
  const [isConnected, setIsConnected] = useState(false);

  useEffect(() => {
    client.connect()
      .then(() => setIsConnected(true))
      .catch(() => setIsConnected(false));

    return () => {
      client.disconnect();
      setIsConnected(false);
    };
  }, [client]);

  const subscribe = useCallback((event: string, callback: (data: any) => void) => {
    return client.on(event, callback);
  }, [client]);

  return { isConnected, subscribe };
}
```

## Error Handling and Retry Strategies

### 1. Comprehensive Error Boundary for API Errors

```typescript
// components/ApiErrorBoundary.tsx
interface ApiErrorBoundaryState {
  hasError: boolean;
  error: Error | null;
  errorInfo: ErrorInfo | null;
  errorId: string | null;
}

export class ApiErrorBoundary extends Component<
  { children: ReactNode; fallback?: ComponentType<any> },
  ApiErrorBoundaryState
> {
  private retryTimeouts = new Set<NodeJS.Timeout>();

  constructor(props: any) {
    super(props);
    this.state = {
      hasError: false,
      error: null,
      errorInfo: null,
      errorId: null,
    };
  }

  static getDerivedStateFromError(error: Error): Partial<ApiErrorBoundaryState> {
    return {
      hasError: true,
      error,
      errorId: `error-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
    };
  }

  componentDidCatch(error: Error, errorInfo: ErrorInfo) {
    this.setState({ errorInfo });

    // Log error to monitoring service
    this.logError(error, errorInfo);
  }

  componentWillUnmount() {
    // Clear any pending retry timeouts
    this.retryTimeouts.forEach(timeout => clearTimeout(timeout));
  }

  private logError = (error: Error, errorInfo: ErrorInfo) => {
    const errorReport = {
      message: error.message,
      stack: error.stack,
      componentStack: errorInfo.componentStack,
      errorId: this.state.errorId,
      url: window.location.href,
      userAgent: navigator.userAgent,
      timestamp: new Date().toISOString(),
    };

    // Send to error tracking service
    if (window.gtag) {
      window.gtag('event', 'exception', {
        description: error.message,
        fatal: false,
        custom_map: { error_id: this.state.errorId },
      });
    }

    console.error('API Error Boundary caught an error:', errorReport);
  };

  private handleRetry = () => {
    this.setState({
      hasError: false,
      error: null,
      errorInfo: null,
      errorId: null,
    });
  };

  private handleAutoRetry = (delay: number = 5000) => {
    const timeout = setTimeout(() => {
      this.handleRetry();
      this.retryTimeouts.delete(timeout);
    }, delay);
    
    this.retryTimeouts.add(timeout);
  };

  render() {
    if (this.state.hasError) {
      const FallbackComponent = this.props.fallback || DefaultApiErrorFallback;
      
      return (
        <FallbackComponent
          error={this.state.error}
          errorInfo={this.state.errorInfo}
          errorId={this.state.errorId}
          onRetry={this.handleRetry}
          onAutoRetry={this.handleAutoRetry}
        />
      );
    }

    return this.props.children;
  }
}

// Default error fallback component
function DefaultApiErrorFallback({ 
  error, 
  errorId, 
  onRetry, 
  onAutoRetry 
}: {
  error: Error | null;
  errorId: string | null;
  onRetry: () => void;
  onAutoRetry: (delay?: number) => void;
}) {
  const [autoRetryEnabled, setAutoRetryEnabled] = useState(false);
  const [countdown, setCountdown] = useState(0);

  useEffect(() => {
    if (autoRetryEnabled && countdown > 0) {
      const timer = setTimeout(() => setCountdown(countdown - 1), 1000);
      return () => clearTimeout(timer);
    } else if (autoRetryEnabled && countdown === 0) {
      onRetry();
    }
  }, [autoRetryEnabled, countdown, onRetry]);

  const handleAutoRetry = () => {
    setAutoRetryEnabled(true);
    setCountdown(5);
    onAutoRetry(5000);
  };

  return (
    <div className="flex flex-col items-center justify-center min-h-[400px] p-8">
      <div className="text-center max-w-md">
        <div className="mb-4">
          <ExclamationTriangleIcon className="h-12 w-12 text-red-500 mx-auto" />
        </div>
        
        <h2 className="text-xl font-semibold text-gray-900 mb-2">
          Something went wrong
        </h2>
        
        <p className="text-gray-600 mb-6">
          We encountered an unexpected error. Please try again.
        </p>
        
        <div className="flex flex-col sm:flex-row gap-3 justify-center">
          <button
            onClick={onRetry}
            className="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700"
          >
            Try Again
          </button>
          
          <button
            onClick={handleAutoRetry}
            disabled={autoRetryEnabled}
            className="px-4 py-2 bg-gray-600 text-white rounded-md hover:bg-gray-700 disabled:opacity-50"
          >
            {autoRetryEnabled 
              ? `Auto retry in ${countdown}s...` 
              : 'Auto Retry'
            }
          </button>
          
          <button
            onClick={() => window.location.reload()}
            className="px-4 py-2 border border-gray-300 text-gray-700 rounded-md hover:bg-gray-50"
          >
            Reload Page
          </button>
        </div>
        
        {process.env.NODE_ENV === 'development' && error && (
          <details className="mt-6 text-left">
            <summary className="cursor-pointer text-sm text-gray-500">
              Error Details (Development)
            </summary>
            <pre className="mt-2 text-xs bg-gray-100 p-3 rounded overflow-auto">
              {error.message}
              {'\n\n'}
              {error.stack}
            </pre>
            <p className="text-xs text-gray-500 mt-2">
              Error ID: {errorId}
            </p>
          </details>
        )}
      </div>
    </div>
  );
}
```

### 2. Smart Retry Logic with Exponential Backoff

```typescript
// lib/retry-strategies.ts
export interface RetryConfig {
  maxAttempts: number;
  baseDelay: number;
  maxDelay: number;
  backoffFactor: number;
  jitter: boolean;
  retryCondition?: (error: any) => boolean;
}

export const defaultRetryConfig: RetryConfig = {
  maxAttempts: 3,
  baseDelay: 1000,
  maxDelay: 30000,
  backoffFactor: 2,
  jitter: true,
  retryCondition: (error) => {
    // Retry on network errors and 5xx server errors
    return !error.response || error.response.status >= 500;
  },
};

export async function withRetry<T>(
  operation: () => Promise<T>,
  config: Partial<RetryConfig> = {}
): Promise<T> {
  const finalConfig = { ...defaultRetryConfig, ...config };
  let lastError: any;

  for (let attempt = 1; attempt <= finalConfig.maxAttempts; attempt++) {
    try {
      return await operation();
    } catch (error) {
      lastError = error;

      // Don't retry if condition is not met
      if (finalConfig.retryCondition && !finalConfig.retryCondition(error)) {
        throw error;
      }

      // Don't retry on last attempt
      if (attempt === finalConfig.maxAttempts) {
        throw error;
      }

      // Calculate delay with exponential backoff
      let delay = finalConfig.baseDelay * Math.pow(finalConfig.backoffFactor, attempt - 1);
      delay = Math.min(delay, finalConfig.maxDelay);

      // Add jitter to prevent thundering herd
      if (finalConfig.jitter) {
        delay = delay * (0.5 + Math.random() * 0.5);
      }

      console.warn(
        `Operation failed (attempt ${attempt}/${finalConfig.maxAttempts}). Retrying in ${delay}ms...`,
        error
      );

      await new Promise(resolve => setTimeout(resolve, delay));
    }
  }

  throw lastError;
}

// Usage with API calls
export const apiClientWithRetry = {
  async get<T>(url: string, config?: AxiosRequestConfig): Promise<T> {
    return withRetry(
      () => apiClient.get<T>(url, config),
      {
        maxAttempts: 3,
        retryCondition: (error) => {
          // Retry on network errors and server errors, but not client errors
          return !error.response || (error.response.status >= 500);
        },
      }
    );
  },

  async post<T>(url: string, data?: any, config?: AxiosRequestConfig): Promise<T> {
    return withRetry(
      () => apiClient.post<T>(url, data, config),
      {
        maxAttempts: 2, // Fewer retries for mutations
        retryCondition: (error) => {
          // Only retry on network errors for mutations
          return !error.response;
        },
      }
    );
  },
};
```

## Performance Optimization Patterns

### 1. Request Deduplication and Caching

```typescript
// lib/request-cache.ts
class RequestCache {
  private cache = new Map<string, Promise<any>>();
  private results = new Map<string, { data: any; timestamp: number; ttl: number }>();

  async get<T>(
    key: string,
    fetcher: () => Promise<T>,
    ttl: number = 5 * 60 * 1000 // 5 minutes default
  ): Promise<T> {
    // Check if we have a fresh cached result
    const cached = this.results.get(key);
    if (cached && Date.now() - cached.timestamp < cached.ttl) {
      return cached.data;
    }

    // Check if there's an ongoing request
    let promise = this.cache.get(key);
    
    if (!promise) {
      // Create new request
      promise = fetcher()
        .then(data => {
          // Cache the result
          this.results.set(key, {
            data,
            timestamp: Date.now(),
            ttl,
          });
          return data;
        })
        .finally(() => {
          // Remove from pending requests
          this.cache.delete(key);
        });
      
      this.cache.set(key, promise);
    }

    return promise;
  }

  invalidate(pattern?: string | RegExp) {
    if (!pattern) {
      // Clear all
      this.cache.clear();
      this.results.clear();
      return;
    }

    const keys = Array.from(this.results.keys());
    
    for (const key of keys) {
      const shouldInvalidate = typeof pattern === 'string' 
        ? key.includes(pattern)
        : pattern.test(key);
        
      if (shouldInvalidate) {
        this.cache.delete(key);
        this.results.delete(key);
      }
    }
  }

  // Cleanup expired entries
  cleanup() {
    const now = Date.now();
    for (const [key, value] of this.results.entries()) {
      if (now - value.timestamp > value.ttl) {
        this.results.delete(key);
      }
    }
  }
}

export const requestCache = new RequestCache();

// Cleanup expired entries every 5 minutes
setInterval(() => requestCache.cleanup(), 5 * 60 * 1000);

// Enhanced API client with caching
export const apiClientCached = {
  async get<T>(url: string, options?: { ttl?: number; skipCache?: boolean }): Promise<T> {
    const { ttl = 5 * 60 * 1000, skipCache = false } = options || {};
    
    if (skipCache) {
      return apiClient.get<T>(url);
    }
    
    return requestCache.get(
      `GET:${url}`,
      () => apiClient.get<T>(url),
      ttl
    );
  },

  async post<T>(url: string, data?: any): Promise<T> {
    const result = await apiClient.post<T>(url, data);
    
    // Invalidate related cache entries
    requestCache.invalidate(url.split('?')[0]);
    
    return result;
  },

  invalidateCache(pattern?: string | RegExp) {
    requestCache.invalidate(pattern);
  },
};
```

### 2. Background Sync and Offline Support

```typescript
// lib/background-sync.ts
export class BackgroundSyncManager {
  private queue: Array<{
    id: string;
    operation: () => Promise<any>;
    retryCount: number;
    maxRetries: number;
    createdAt: number;
  }> = [];
  
  private isProcessing = false;
  private syncInterval: NodeJS.Timeout | null = null;

  constructor() {
    this.loadQueueFromStorage();
    this.startSyncProcess();
    this.setupOnlineListener();
  }

  private loadQueueFromStorage() {
    try {
      const stored = localStorage.getItem('background-sync-queue');
      if (stored) {
        const parsed = JSON.parse(stored);
        // Only restore operations that are less than 24 hours old
        const dayAgo = Date.now() - 24 * 60 * 60 * 1000;
        this.queue = parsed.filter((item: any) => item.createdAt > dayAgo);
        this.saveQueueToStorage();
      }
    } catch (error) {
      console.error('Failed to load sync queue from storage:', error);
    }
  }

  private saveQueueToStorage() {
    try {
      localStorage.setItem('background-sync-queue', JSON.stringify(this.queue));
    } catch (error) {
      console.error('Failed to save sync queue to storage:', error);
    }
  }

  private setupOnlineListener() {
    window.addEventListener('online', () => {
      console.log('Network connection restored, processing sync queue');
      this.processQueue();
    });
  }

  private startSyncProcess() {
    this.syncInterval = setInterval(() => {
      if (navigator.onLine && this.queue.length > 0) {
        this.processQueue();
      }
    }, 30000); // Check every 30 seconds
  }

  async addToQueue(
    id: string,
    operation: () => Promise<any>,
    maxRetries: number = 3
  ) {
    this.queue.push({
      id,
      operation,
      retryCount: 0,
      maxRetries,
      createdAt: Date.now(),
    });
    
    this.saveQueueToStorage();
    
    // Try to process immediately if online
    if (navigator.onLine) {
      this.processQueue();
    }
  }

  private async processQueue() {
    if (this.isProcessing || this.queue.length === 0 || !navigator.onLine) {
      return;
    }

    this.isProcessing = true;

    const toProcess = [...this.queue];
    this.queue = [];

    for (const item of toProcess) {
      try {
        await item.operation();
        console.log(`Successfully synced operation: ${item.id}`);
      } catch (error) {
        console.error(`Failed to sync operation ${item.id}:`, error);
        
        item.retryCount++;
        if (item.retryCount < item.maxRetries) {
          // Add back to queue for retry
          this.queue.push(item);
        } else {
          console.error(`Operation ${item.id} exceeded max retries, discarding`);
        }
      }
    }

    this.saveQueueToStorage();
    this.isProcessing = false;
  }

  getQueueStatus() {
    return {
      pending: this.queue.length,
      isProcessing: this.isProcessing,
      isOnline: navigator.onLine,
    };
  }

  clearQueue() {
    this.queue = [];
    this.saveQueueToStorage();
  }

  destroy() {
    if (this.syncInterval) {
      clearInterval(this.syncInterval);
    }
  }
}

export const backgroundSync = new BackgroundSyncManager();

// Hook for using background sync
export function useBackgroundSync() {
  const [status, setStatus] = useState(backgroundSync.getQueueStatus());

  useEffect(() => {
    const updateStatus = () => setStatus(backgroundSync.getQueueStatus());
    
    const interval = setInterval(updateStatus, 1000);
    
    // Update on network status change
    const handleOnline = () => updateStatus();
    const handleOffline = () => updateStatus();
    
    window.addEventListener('online', handleOnline);
    window.addEventListener('offline', handleOffline);

    return () => {
      clearInterval(interval);
      window.removeEventListener('online', handleOnline);
      window.removeEventListener('offline', handleOffline);
    };
  }, []);

  const addToQueue = useCallback(
    (id: string, operation: () => Promise<any>, maxRetries?: number) => {
      return backgroundSync.addToQueue(id, operation, maxRetries);
    },
    []
  );

  return { status, addToQueue };
}
```

---

## Navigation

- ← Back to: [Component Library Management](component-library-management.md)
- → Next: [Performance Optimization](performance-optimization.md)
- 🏠 Home: [Research Overview](../../README.md)