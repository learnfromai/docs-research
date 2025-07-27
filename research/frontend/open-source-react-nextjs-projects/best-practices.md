# Best Practices

Comprehensive compilation of best practices for React/Next.js development based on analysis of production open source projects, covering code organization, performance, security, and maintainability.

## Project Organization Best Practices

### Directory Structure

**Recommended Project Structure**
```
src/
├── app/                    # Next.js App Router pages
│   ├── (auth)/            # Route groups
│   ├── dashboard/         # Feature-based routing
│   ├── api/              # API routes
│   ├── globals.css       # Global styles
│   └── layout.tsx        # Root layout
├── components/           # Reusable components
│   ├── ui/              # Base UI components
│   ├── forms/           # Form components
│   ├── layout/          # Layout components
│   └── features/        # Feature-specific components
├── hooks/               # Custom React hooks
├── lib/                 # Utility functions and configurations
│   ├── auth.ts         # Authentication setup
│   ├── db.ts           # Database client
│   ├── utils.ts        # Utility functions
│   └── validations/    # Zod schemas
├── store/              # State management
│   ├── index.ts        # Main store
│   └── slices/         # Store slices
├── types/              # TypeScript type definitions
│   ├── api.ts          # API types
│   ├── auth.ts         # Auth types
│   └── database.ts     # Database types
└── middleware.ts       # Next.js middleware
```

### File Naming Conventions

**Component Files**
```typescript
// ✅ PascalCase for components
UserCard.tsx
DataTable.tsx
AuthProvider.tsx

// ✅ kebab-case for non-component files
user-card.styles.ts
api-client.ts
query-keys.ts

// ✅ Descriptive test files
UserCard.test.tsx
user-service.test.ts
```

**Export Patterns**
```typescript
// ✅ Named exports for components
export function UserCard({ user }) {
  return <div>{user.name}</div>;
}

// ✅ Default exports for pages
export default function UsersPage() {
  return <div>Users</div>;
}

// ✅ Barrel exports for clean imports
// components/index.ts
export { Button } from './ui/button';
export { Input } from './ui/input';
export { UserCard } from './users/user-card';

// Usage
import { Button, Input, UserCard } from '@/components';
```

## Code Quality Best Practices

### TypeScript Usage

**Strict Type Safety**
```typescript
// ✅ Use strict TypeScript configuration
// tsconfig.json
{
  "compilerOptions": {
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "exactOptionalPropertyTypes": true
  }
}

// ✅ Proper type definitions
interface User {
  id: string;
  name: string;
  email: string;
  role: 'USER' | 'ADMIN' | 'MODERATOR';
  createdAt: Date;
}

// ✅ Generic utilities
type Optional<T, K extends keyof T> = Omit<T, K> & Partial<Pick<T, K>>;
type CreateUser = Optional<User, 'id' | 'createdAt'>;

// ✅ Utility types for API responses
interface ApiResponse<T> {
  data: T;
  message: string;
  status: 'success' | 'error';
}

interface PaginatedResponse<T> {
  data: T[];
  pagination: {
    page: number;
    limit: number;
    total: number;
    totalPages: number;
  };
}
```

**Type Guards and Assertions**
```typescript
// ✅ Type guards for runtime safety
function isUser(value: unknown): value is User {
  return (
    typeof value === 'object' &&
    value !== null &&
    'id' in value &&
    'name' in value &&
    'email' in value
  );
}

// ✅ Custom assertion functions
function assertIsUser(value: unknown): asserts value is User {
  if (!isUser(value)) {
    throw new Error('Value is not a valid User');
  }
}

// Usage
const data: unknown = await fetchUser();
assertIsUser(data);
// data is now typed as User
console.log(data.name);
```

### Error Handling Patterns

**Comprehensive Error Handling**
```typescript
// ✅ Custom error classes
export class ApiError extends Error {
  constructor(
    message: string,
    public statusCode: number,
    public code?: string
  ) {
    super(message);
    this.name = 'ApiError';
  }
}

export class ValidationError extends Error {
  constructor(
    message: string,
    public field: string,
    public value: unknown
  ) {
    super(message);
    this.name = 'ValidationError';
  }
}

// ✅ Result pattern for error handling
type Result<T, E = Error> = 
  | { success: true; data: T }
  | { success: false; error: E };

async function safeApiCall<T>(
  apiCall: () => Promise<T>
): Promise<Result<T, ApiError>> {
  try {
    const data = await apiCall();
    return { success: true, data };
  } catch (error) {
    if (error instanceof ApiError) {
      return { success: false, error };
    }
    return { 
      success: false, 
      error: new ApiError('Unknown error', 500) 
    };
  }
}

// Usage
const result = await safeApiCall(() => fetchUsers());
if (result.success) {
  console.log(result.data); // Type: User[]
} else {
  console.error(result.error.message); // Type: ApiError
}
```

**React Error Boundaries**
```typescript
// ✅ Comprehensive error boundary
interface ErrorBoundaryState {
  hasError: boolean;
  error: Error | null;
  errorInfo: ErrorInfo | null;
}

export class ErrorBoundary extends Component<
  PropsWithChildren<{
    fallback?: ComponentType<{ error: Error; reset: () => void }>;
    onError?: (error: Error, errorInfo: ErrorInfo) => void;
  }>,
  ErrorBoundaryState
> {
  constructor(props: any) {
    super(props);
    this.state = { hasError: false, error: null, errorInfo: null };
  }

  static getDerivedStateFromError(error: Error): Partial<ErrorBoundaryState> {
    return { hasError: true, error };
  }

  componentDidCatch(error: Error, errorInfo: ErrorInfo) {
    this.setState({ errorInfo });
    this.props.onError?.(error, errorInfo);
    
    // Log to error reporting service
    console.error('Error caught by boundary:', error, errorInfo);
  }

  render() {
    if (this.state.hasError) {
      const FallbackComponent = this.props.fallback || DefaultErrorFallback;
      return (
        <FallbackComponent
          error={this.state.error!}
          reset={() => this.setState({ hasError: false, error: null })}
        />
      );
    }

    return this.props.children;
  }
}

// ✅ Usage with React Query error boundary
function App() {
  return (
    <QueryErrorResetBoundary>
      {({ reset }) => (
        <ErrorBoundary
          onError={(error, errorInfo) => {
            // Log to monitoring service
            reportError(error, errorInfo);
          }}
          fallback={({ error, reset: resetError }) => (
            <div>
              <h2>Something went wrong:</h2>
              <details>{error.message}</details>
              <button onClick={() => { reset(); resetError(); }}>
                Try again
              </button>
            </div>
          )}
        >
          <QueryClient>
            <Router />
          </QueryClient>
        </ErrorBoundary>
      )}
    </QueryErrorResetBoundary>
  );
}
```

## Component Best Practices

### Component Design Principles

**Single Responsibility Principle**
```typescript
// ❌ Component doing too many things
function UserDashboard({ userId }) {
  const [user, setUser] = useState(null);
  const [posts, setPosts] = useState([]);
  const [analytics, setAnalytics] = useState(null);
  
  // Fetching logic, analytics logic, rendering logic all mixed
  
  return (
    <div>
      {/* Complex rendering logic */}
    </div>
  );
}

// ✅ Separated responsibilities
function UserDashboard({ userId }) {
  return (
    <div className="space-y-6">
      <UserProfile userId={userId} />
      <UserPosts userId={userId} />
      <UserAnalytics userId={userId} />
    </div>
  );
}

function UserProfile({ userId }) {
  const { data: user, isLoading } = useUser(userId);
  
  if (isLoading) return <UserProfileSkeleton />;
  
  return (
    <Card>
      <CardContent>
        <h2>{user.name}</h2>
        <p>{user.email}</p>
      </CardContent>
    </Card>
  );
}
```

**Composition over Inheritance**
```typescript
// ✅ Compound component pattern
const Card = ({ children, className, ...props }) => (
  <div className={cn('rounded-lg border bg-card', className)} {...props}>
    {children}
  </div>
);

const CardHeader = ({ children, className, ...props }) => (
  <div className={cn('flex flex-col space-y-1.5 p-6', className)} {...props}>
    {children}
  </div>
);

const CardContent = ({ children, className, ...props }) => (
  <div className={cn('p-6 pt-0', className)} {...props}>
    {children}
  </div>
);

// Attach sub-components
Card.Header = CardHeader;
Card.Content = CardContent;

// Usage
function UserCard({ user }) {
  return (
    <Card>
      <Card.Header>
        <h3>{user.name}</h3>
      </Card.Header>
      <Card.Content>
        <p>{user.email}</p>
      </Card.Content>
    </Card>
  );
}
```

**Props Interface Design**
```typescript
// ✅ Well-designed props interface
interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'primary' | 'secondary' | 'destructive';
  size?: 'sm' | 'md' | 'lg';
  isLoading?: boolean;
  leftIcon?: React.ReactNode;
  rightIcon?: React.ReactNode;
  asChild?: boolean;
}

// ✅ Use discriminated unions for complex props
type ModalProps = 
  | {
      mode: 'controlled';
      open: boolean;
      onOpenChange: (open: boolean) => void;
    }
  | {
      mode: 'uncontrolled';
      defaultOpen?: boolean;
    };

function Modal(props: ModalProps & { children: React.ReactNode }) {
  if (props.mode === 'controlled') {
    // props.open and props.onOpenChange are available
  } else {
    // props.defaultOpen is available
  }
}
```

### Performance Optimization

**Memoization Strategies**
```typescript
// ✅ Strategic use of React.memo
const UserCard = React.memo(({ 
  user, 
  onEdit, 
  onDelete 
}: {
  user: User;
  onEdit: (id: string) => void;
  onDelete: (id: string) => void;
}) => {
  // Memoize callbacks to prevent re-renders
  const handleEdit = useCallback(() => onEdit(user.id), [onEdit, user.id]);
  const handleDelete = useCallback(() => onDelete(user.id), [onDelete, user.id]);
  
  return (
    <Card>
      <CardContent>
        <h3>{user.name}</h3>
        <p>{user.email}</p>
        <div>
          <Button onClick={handleEdit}>Edit</Button>
          <Button onClick={handleDelete}>Delete</Button>
        </div>
      </CardContent>
    </Card>
  );
});

// ✅ Custom equality function for complex props
const ComplexComponent = React.memo(({ 
  data, 
  filters 
}: {
  data: ComplexData[];
  filters: FilterConfig;
}) => {
  return <div>{/* Complex rendering */}</div>;
}, (prevProps, nextProps) => {
  // Custom comparison logic
  return (
    prevProps.data.length === nextProps.data.length &&
    prevProps.data.every((item, index) => 
      item.id === nextProps.data[index]?.id &&
      item.updatedAt === nextProps.data[index]?.updatedAt
    ) &&
    JSON.stringify(prevProps.filters) === JSON.stringify(nextProps.filters)
  );
});
```

**Expensive Operations Optimization**
```typescript
// ✅ useMemo for expensive calculations
function DataVisualization({ data, filters, sortConfig }) {
  const processedData = useMemo(() => {
    console.log('Processing data...'); // Should only log when dependencies change
    
    return data
      .filter(item => filters.every(filter => filter.fn(item)))
      .sort((a, b) => {
        const key = sortConfig.key;
        const direction = sortConfig.direction;
        
        if (direction === 'asc') {
          return a[key] > b[key] ? 1 : -1;
        }
        return a[key] < b[key] ? 1 : -1;
      })
      .map(item => ({
        ...item,
        processedValue: complexCalculation(item.value),
      }));
  }, [data, filters, sortConfig]);

  const chartConfig = useMemo(() => ({
    type: 'line',
    responsive: true,
    plugins: {
      legend: { display: true },
    },
  }), []); // Empty deps - config never changes

  return (
    <Chart data={processedData} config={chartConfig} />
  );
}

// ✅ Custom hooks for reusable expensive operations
function useFilteredAndSortedData<T>(
  data: T[],
  filters: FilterConfig[],
  sortConfig: SortConfig
) {
  return useMemo(() => {
    return data
      .filter(item => filters.every(filter => filter.fn(item)))
      .sort((a, b) => {
        const key = sortConfig.key;
        const direction = sortConfig.direction;
        return direction === 'asc' 
          ? (a[key] > b[key] ? 1 : -1)
          : (a[key] < b[key] ? 1 : -1);
      });
  }, [data, filters, sortConfig]);
}
```

## State Management Best Practices

### Zustand Patterns

**Store Organization**
```typescript
// ✅ Slice pattern for large stores
interface UserSlice {
  users: User[];
  selectedUser: User | null;
  setUsers: (users: User[]) => void;
  selectUser: (user: User | null) => void;
}

interface UISlice {
  theme: 'light' | 'dark';
  sidebarOpen: boolean;
  setTheme: (theme: 'light' | 'dark') => void;
  toggleSidebar: () => void;
}

const createUserSlice: StateCreator<UserSlice & UISlice, [], [], UserSlice> = (set) => ({
  users: [],
  selectedUser: null,
  setUsers: (users) => set({ users }),
  selectUser: (user) => set({ selectedUser: user }),
});

const createUISlice: StateCreator<UserSlice & UISlice, [], [], UISlice> = (set) => ({
  theme: 'light',
  sidebarOpen: false,
  setTheme: (theme) => set({ theme }),
  toggleSidebar: () => set((state) => ({ sidebarOpen: !state.sidebarOpen })),
});

export const useAppStore = create<UserSlice & UISlice>()(
  devtools(
    persist(
      (...a) => ({
        ...createUserSlice(...a),
        ...createUISlice(...a),
      }),
      {
        name: 'app-store',
        partialize: (state) => ({ 
          theme: state.theme,
          sidebarOpen: state.sidebarOpen 
        }),
      }
    )
  )
);

// ✅ Selective subscriptions
export const useUsers = () => useAppStore((state) => state.users);
export const useSelectedUser = () => useAppStore((state) => state.selectedUser);
export const useTheme = () => useAppStore((state) => state.theme);
```

### React Query Best Practices

**Query Key Management**
```typescript
// ✅ Centralized query key factory
export const queryKeys = {
  users: {
    all: ['users'] as const,
    lists: () => [...queryKeys.users.all, 'list'] as const,
    list: (filters: string) => [...queryKeys.users.lists(), { filters }] as const,
    details: () => [...queryKeys.users.all, 'detail'] as const,
    detail: (id: string) => [...queryKeys.users.details(), id] as const,
  },
  posts: {
    all: ['posts'] as const,
    lists: () => [...queryKeys.posts.all, 'list'] as const,
    list: (filters: string) => [...queryKeys.posts.lists(), { filters }] as const,
    details: () => [...queryKeys.posts.all, 'detail'] as const,
    detail: (id: string) => [...queryKeys.posts.details(), id] as const,
  },
} as const;

// ✅ Usage in hooks
export function useUsers(filters = {}) {
  return useQuery({
    queryKey: queryKeys.users.list(JSON.stringify(filters)),
    queryFn: () => fetchUsers(filters),
    staleTime: 5 * 60 * 1000,
  });
}
```

**Optimistic Updates Pattern**
```typescript
// ✅ Comprehensive optimistic updates
export function useUpdateUser() {
  const queryClient = useQueryClient();
  
  return useMutation({
    mutationFn: updateUser,
    
    onMutate: async (variables) => {
      const { id, updates } = variables;
      
      // Cancel outgoing refetches
      await queryClient.cancelQueries({ queryKey: queryKeys.users.detail(id) });
      
      // Snapshot previous value
      const previousUser = queryClient.getQueryData(queryKeys.users.detail(id));
      
      // Optimistically update detail
      queryClient.setQueryData(queryKeys.users.detail(id), (old: User) => ({
        ...old,
        ...updates,
      }));
      
      // Optimistically update lists
      queryClient.setQueriesData(
        { queryKey: queryKeys.users.lists() },
        (old: any) => {
          if (!old?.users) return old;
          
          return {
            ...old,
            users: old.users.map((user: User) =>
              user.id === id ? { ...user, ...updates } : user
            ),
          };
        }
      );
      
      return { previousUser };
    },
    
    onError: (err, variables, context) => {
      // Rollback optimistic updates
      if (context?.previousUser) {
        queryClient.setQueryData(
          queryKeys.users.detail(variables.id),
          context.previousUser
        );
      }
      
      // Invalidate lists to refetch
      queryClient.invalidateQueries({ queryKey: queryKeys.users.lists() });
    },
    
    onSuccess: (updatedUser, variables) => {
      // Update with server response
      queryClient.setQueryData(queryKeys.users.detail(variables.id), updatedUser);
      
      // Update lists with fresh data
      queryClient.setQueriesData(
        { queryKey: queryKeys.users.lists() },
        (old: any) => {
          if (!old?.users) return old;
          
          return {
            ...old,
            users: old.users.map((user: User) =>
              user.id === updatedUser.id ? updatedUser : user
            ),
          };
        }
      );
    },
    
    onSettled: () => {
      // Always refetch to ensure consistency
      queryClient.invalidateQueries({ queryKey: queryKeys.users.all });
    },
  });
}
```

## Security Best Practices

### Authentication Security

**Secure Token Handling**
```typescript
// ✅ Secure token storage and management
class TokenManager {
  private static readonly ACCESS_TOKEN_KEY = 'accessToken';
  private static readonly REFRESH_TOKEN_KEY = 'refreshToken';
  
  static setTokens(accessToken: string, refreshToken: string) {
    // Store access token in memory (less secure but accessible)
    sessionStorage.setItem(this.ACCESS_TOKEN_KEY, accessToken);
    
    // Store refresh token in HTTP-only cookie (more secure)
    document.cookie = `${this.REFRESH_TOKEN_KEY}=${refreshToken}; HttpOnly; Secure; SameSite=Strict; Max-Age=${7 * 24 * 60 * 60}`;
  }
  
  static getAccessToken(): string | null {
    return sessionStorage.getItem(this.ACCESS_TOKEN_KEY);
  }
  
  static clearTokens() {
    sessionStorage.removeItem(this.ACCESS_TOKEN_KEY);
    document.cookie = `${this.REFRESH_TOKEN_KEY}=; expires=Thu, 01 Jan 1970 00:00:00 UTC; path=/;`;
  }
  
  static async refreshAccessToken(): Promise<string> {
    const response = await fetch('/api/auth/refresh', {
      method: 'POST',
      credentials: 'include', // Include HTTP-only cookies
    });
    
    if (!response.ok) {
      this.clearTokens();
      throw new Error('Token refresh failed');
    }
    
    const { accessToken } = await response.json();
    sessionStorage.setItem(this.ACCESS_TOKEN_KEY, accessToken);
    
    return accessToken;
  }
}
```

**Input Validation and Sanitization**
```typescript
// ✅ Comprehensive input validation with Zod
import { z } from 'zod';
import DOMPurify from 'isomorphic-dompurify';

// Server-side validation schema
export const createPostSchema = z.object({
  title: z.string()
    .min(1, 'Title is required')
    .max(200, 'Title must be less than 200 characters')
    .transform(title => DOMPurify.sanitize(title.trim())),
  
  content: z.string()
    .min(1, 'Content is required')
    .max(10000, 'Content must be less than 10,000 characters')
    .transform(content => DOMPurify.sanitize(content)),
  
  tags: z.array(z.string())
    .max(10, 'Maximum 10 tags allowed')
    .transform(tags => tags.map(tag => DOMPurify.sanitize(tag.trim()))),
  
  published: z.boolean().default(false),
});

// API route with validation
export async function POST(request: Request) {
  try {
    const body = await request.json();
    
    // Validate and sanitize input
    const validatedData = createPostSchema.parse(body);
    
    // Create post with validated data
    const post = await createPost(validatedData);
    
    return NextResponse.json(post);
  } catch (error) {
    if (error instanceof z.ZodError) {
      return NextResponse.json(
        { error: 'Validation failed', details: error.errors },
        { status: 400 }
      );
    }
    
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
```

**CSRF Protection**
```typescript
// ✅ CSRF token implementation
import { headers } from 'next/headers';
import { NextRequest, NextResponse } from 'next/server';

export async function middleware(request: NextRequest) {
  // Only check CSRF for state-changing methods
  if (['POST', 'PUT', 'DELETE', 'PATCH'].includes(request.method)) {
    const csrfToken = request.headers.get('x-csrf-token');
    const sessionToken = request.cookies.get('session-token')?.value;
    
    if (!csrfToken || !sessionToken) {
      return NextResponse.json(
        { error: 'CSRF token required' },
        { status: 403 }
      );
    }
    
    // Verify CSRF token
    const isValidCSRF = await verifyCSRFToken(csrfToken, sessionToken);
    if (!isValidCSRF) {
      return NextResponse.json(
        { error: 'Invalid CSRF token' },
        { status: 403 }
      );
    }
  }
  
  return NextResponse.next();
}

// Helper function to generate CSRF token
export function generateCSRFToken(sessionId: string): string {
  const hmac = crypto.createHmac('sha256', process.env.CSRF_SECRET!);
  hmac.update(sessionId);
  return hmac.digest('hex');
}
```

## Testing Best Practices

### Unit Testing Patterns

**Component Testing Strategy**
```typescript
// ✅ Comprehensive component testing
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { UserCard } from '../UserCard';

const createTestQueryClient = () => new QueryClient({
  defaultOptions: {
    queries: { retry: false },
    mutations: { retry: false },
  },
});

const TestWrapper = ({ children }: { children: React.ReactNode }) => {
  const queryClient = createTestQueryClient();
  return (
    <QueryClientProvider client={queryClient}>
      {children}
    </QueryClientProvider>
  );
};

const mockUser = {
  id: '1',
  name: 'John Doe',
  email: 'john@example.com',
  role: 'USER' as const,
  createdAt: new Date('2023-01-01'),
  updatedAt: new Date('2023-01-01'),
};

describe('UserCard', () => {
  it('renders user information correctly', () => {
    render(<UserCard user={mockUser} />, { wrapper: TestWrapper });
    
    expect(screen.getByText('John Doe')).toBeInTheDocument();
    expect(screen.getByText('john@example.com')).toBeInTheDocument();
    expect(screen.getByText('USER')).toBeInTheDocument();
  });

  it('calls onEdit when edit button is clicked', async () => {
    const user = userEvent.setup();
    const onEdit = jest.fn();
    
    render(
      <UserCard user={mockUser} onEdit={onEdit} />,
      { wrapper: TestWrapper }
    );
    
    await user.click(screen.getByRole('button', { name: /edit/i }));
    
    expect(onEdit).toHaveBeenCalledTimes(1);
    expect(onEdit).toHaveBeenCalledWith(mockUser.id);
  });

  it('shows loading state when user is being deleted', async () => {
    const onDelete = jest.fn(() => new Promise(resolve => setTimeout(resolve, 100)));
    
    render(
      <UserCard user={mockUser} onDelete={onDelete} />,
      { wrapper: TestWrapper }
    );
    
    fireEvent.click(screen.getByRole('button', { name: /delete/i }));
    
    expect(screen.getByText(/deleting/i)).toBeInTheDocument();
    
    await waitFor(() => {
      expect(screen.queryByText(/deleting/i)).not.toBeInTheDocument();
    });
  });
});
```

**Custom Hook Testing**
```typescript
// ✅ Testing custom hooks
import { renderHook, waitFor } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { useUsers } from '../useUsers';

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

    expect(result.current.data).toHaveLength(2);
    expect(result.current.data[0].name).toBe('John Doe');
  });

  it('handles search parameters correctly', async () => {
    const { result } = renderHook(
      () => useUsers({ search: 'john' }),
      { wrapper: createWrapper() }
    );

    await waitFor(() => {
      expect(result.current.isSuccess).toBe(true);
    });

    expect(result.current.data).toHaveLength(1);
    expect(result.current.data[0].name).toBe('John Doe');
  });
});
```

### Integration Testing

**API Route Testing**
```typescript
// ✅ API route testing
import { createMocks } from 'node-mocks-http';
import handler from '../api/users';

describe('/api/users', () => {
  it('returns users list for GET request', async () => {
    const { req, res } = createMocks({
      method: 'GET',
      query: { page: '1', limit: '10' },
    });

    await handler(req, res);

    expect(res._getStatusCode()).toBe(200);
    
    const data = JSON.parse(res._getData());
    expect(data).toHaveProperty('users');
    expect(data).toHaveProperty('pagination');
    expect(Array.isArray(data.users)).toBe(true);
  });

  it('validates input for POST request', async () => {
    const { req, res } = createMocks({
      method: 'POST',
      body: {
        name: '', // Invalid: empty name
        email: 'invalid-email', // Invalid: bad email format
      },
    });

    await handler(req, res);

    expect(res._getStatusCode()).toBe(400);
    
    const data = JSON.parse(res._getData());
    expect(data).toHaveProperty('error');
    expect(data.error).toBe('Validation failed');
  });
});
```

## Performance Best Practices

### Bundle Optimization

**Tree Shaking Configuration**
```javascript
// ✅ Optimized imports for tree shaking
// Instead of importing entire libraries
import * as lodash from 'lodash'; // ❌
import { Button, Card, Table } from 'antd'; // ❌

// Import specific functions/components
import debounce from 'lodash/debounce'; // ✅
import { Button } from 'antd/es/button'; // ✅

// Use ES modules when available
import { format } from 'date-fns/format'; // ✅
import { debounce } from 'lodash-es'; // ✅

// next.config.js optimization
module.exports = {
  experimental: {
    optimizePackageImports: [
      'lucide-react',
      'date-fns',
      'lodash-es',
    ],
  },
  webpack: (config) => {
    config.optimization.usedExports = true;
    config.optimization.sideEffects = false;
    return config;
  },
};
```

**Code Splitting Strategy**
```typescript
// ✅ Strategic code splitting
// Route-level splitting (automatic with Next.js App Router)
const DashboardPage = lazy(() => import('./pages/dashboard'));
const UsersPage = lazy(() => import('./pages/users'));
const SettingsPage = lazy(() => import('./pages/settings'));

// Component-level splitting for heavy components
const DataVisualization = lazy(() => 
  import('./components/DataVisualization')
);

const RichTextEditor = lazy(() => 
  import('./components/RichTextEditor')
);

// Conditional imports for features
const AdminPanel = lazy(() => 
  import('./components/AdminPanel').then(module => ({
    default: module.AdminPanel
  }))
);

// Library splitting for large dependencies
const PDFViewer = lazy(() => 
  import('react-pdf').then(module => ({
    default: module.Document
  }))
);

// Usage with proper loading states
function App() {
  return (
    <Router>
      <Routes>
        <Route path="/dashboard" element={
          <Suspense fallback={<DashboardSkeleton />}>
            <DashboardPage />
          </Suspense>
        } />
        <Route path="/users" element={
          <Suspense fallback={<UsersPageSkeleton />}>
            <UsersPage />
          </Suspense>
        } />
      </Routes>
    </Router>
  );
}
```

### Memory Management

**Cleanup Patterns**
```typescript
// ✅ Proper cleanup in useEffect
function useWebSocket(url: string) {
  const [socket, setSocket] = useState<WebSocket | null>(null);
  const [messages, setMessages] = useState<Message[]>([]);

  useEffect(() => {
    const ws = new WebSocket(url);
    
    ws.onopen = () => {
      console.log('WebSocket connected');
      setSocket(ws);
    };
    
    ws.onmessage = (event) => {
      const message = JSON.parse(event.data);
      setMessages(prev => [...prev, message]);
    };
    
    ws.onerror = (error) => {
      console.error('WebSocket error:', error);
    };
    
    // Cleanup function
    return () => {
      if (ws.readyState === WebSocket.OPEN) {
        ws.close();
      }
      setSocket(null);
    };
  }, [url]);

  return { socket, messages };
}

// ✅ Cleanup for event listeners
function useResizeObserver(
  elementRef: RefObject<HTMLElement>,
  callback: (entry: ResizeObserverEntry) => void
) {
  useEffect(() => {
    const element = elementRef.current;
    if (!element) return;

    const resizeObserver = new ResizeObserver((entries) => {
      callback(entries[0]);
    });

    resizeObserver.observe(element);

    return () => {
      resizeObserver.disconnect();
    };
  }, [callback]);
}

// ✅ Cleanup for async operations
function useAsyncOperation<T>(
  asyncFunction: () => Promise<T>,
  dependencies: any[]
) {
  const [data, setData] = useState<T | null>(null);
  const [error, setError] = useState<Error | null>(null);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    let isCancelled = false;

    const execute = async () => {
      setLoading(true);
      setError(null);

      try {
        const result = await asyncFunction();
        
        if (!isCancelled) {
          setData(result);
        }
      } catch (err) {
        if (!isCancelled) {
          setError(err instanceof Error ? err : new Error('Unknown error'));
        }
      } finally {
        if (!isCancelled) {
          setLoading(false);
        }
      }
    };

    execute();

    return () => {
      isCancelled = true;
    };
  }, dependencies);

  return { data, error, loading };
}
```

## Accessibility Best Practices

### Semantic HTML and ARIA

**Proper HTML Structure**
```typescript
// ✅ Semantic HTML with proper ARIA labels
function UserList({ users, onUserSelect }) {
  return (
    <section aria-labelledby="users-heading">
      <h2 id="users-heading">Users</h2>
      
      <div role="search" className="mb-4">
        <label htmlFor="user-search" className="sr-only">
          Search users
        </label>
        <input
          id="user-search"
          type="search"
          placeholder="Search users..."
          aria-describedby="search-help"
        />
        <div id="search-help" className="sr-only">
          Enter a name or email to filter the user list
        </div>
      </div>
      
      <ul role="list" aria-label="User list">
        {users.map((user) => (
          <li key={user.id}>
            <button
              onClick={() => onUserSelect(user)}
              aria-describedby={`user-${user.id}-details`}
              className="w-full text-left p-4 hover:bg-gray-50 focus:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-blue-500"
            >
              <div>
                <h3>{user.name}</h3>
                <p id={`user-${user.id}-details`} className="text-gray-600">
                  {user.email} • {user.role}
                </p>
              </div>
            </button>
          </li>
        ))}
      </ul>
    </section>
  );
}
```

**Keyboard Navigation**
```typescript
// ✅ Comprehensive keyboard navigation
function Modal({ isOpen, onClose, children }) {
  const modalRef = useRef<HTMLDivElement>(null);
  const previousFocusRef = useRef<HTMLElement | null>(null);

  useEffect(() => {
    if (isOpen) {
      // Store previously focused element
      previousFocusRef.current = document.activeElement as HTMLElement;
      
      // Focus the modal
      modalRef.current?.focus();
      
      // Trap focus within modal
      const handleKeyDown = (event: KeyboardEvent) => {
        if (event.key === 'Escape') {
          onClose();
        }
        
        if (event.key === 'Tab') {
          trapFocus(event, modalRef.current!);
        }
      };
      
      document.addEventListener('keydown', handleKeyDown);
      
      return () => {
        document.removeEventListener('keydown', handleKeyDown);
        
        // Restore focus to previously focused element
        previousFocusRef.current?.focus();
      };
    }
  }, [isOpen, onClose]);

  if (!isOpen) return null;

  return (
    <div
      className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50"
      onClick={onClose}
    >
      <div
        ref={modalRef}
        role="dialog"
        aria-modal="true"
        aria-labelledby="modal-title"
        className="bg-white rounded-lg p-6 max-w-md w-full mx-4 focus:outline-none"
        onClick={(e) => e.stopPropagation()}
        tabIndex={-1}
      >
        {children}
        <button
          onClick={onClose}
          className="absolute top-4 right-4 p-2 hover:bg-gray-100 rounded focus:outline-none focus:ring-2 focus:ring-blue-500"
          aria-label="Close modal"
        >
          <X className="h-4 w-4" />
        </button>
      </div>
    </div>
  );
}

function trapFocus(event: KeyboardEvent, container: HTMLElement) {
  const focusableElements = container.querySelectorAll(
    'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
  );
  
  const firstElement = focusableElements[0] as HTMLElement;
  const lastElement = focusableElements[focusableElements.length - 1] as HTMLElement;

  if (event.shiftKey) {
    if (document.activeElement === firstElement) {
      lastElement.focus();
      event.preventDefault();
    }
  } else {
    if (document.activeElement === lastElement) {
      firstElement.focus();
      event.preventDefault();
    }
  }
}
```

## Summary Checklist

### Code Quality
- [ ] Strict TypeScript configuration enabled
- [ ] Comprehensive error handling implemented
- [ ] Input validation and sanitization in place
- [ ] Proper component composition patterns used
- [ ] Performance optimizations applied (memoization, code splitting)

### Security
- [ ] Secure authentication implementation
- [ ] CSRF protection enabled
- [ ] Input validation on both client and server
- [ ] Secure token storage and management
- [ ] Environment variables properly configured

### Performance
- [ ] Bundle size analysis and optimization
- [ ] Code splitting strategy implemented
- [ ] Proper memoization techniques used
- [ ] Memory leak prevention measures
- [ ] Core Web Vitals optimization

### Testing
- [ ] Unit tests for components and hooks
- [ ] Integration tests for API routes
- [ ] Error boundary testing
- [ ] Accessibility testing
- [ ] Performance testing

### Accessibility
- [ ] Semantic HTML structure
- [ ] Proper ARIA labels and roles
- [ ] Keyboard navigation support
- [ ] Focus management
- [ ] Screen reader compatibility

### Development Workflow
- [ ] Consistent code formatting (Prettier)
- [ ] Linting rules configured (ESLint)
- [ ] Git commit conventions followed
- [ ] Documentation maintained
- [ ] CI/CD pipeline configured

Following these best practices ensures the development of maintainable, secure, performant, and accessible React/Next.js applications that can scale from MVP to enterprise-level solutions.

---

**Navigation**
- ← Back to: [Implementation Guide](./implementation-guide.md)
- → Next: [Comparison Analysis](./comparison-analysis.md)
- → Related: [Executive Summary](./executive-summary.md)