# Best Practices: Production React/Next.js Development

## Overview

This document compiles essential best practices extracted from successful open source React and Next.js projects. These patterns and recommendations are proven in production environments and contribute to maintainable, scalable, and performant applications.

## Code Organization and Architecture

### 1. Project Structure Best Practices

**Scalable Folder Organization** (Based on Cal.com and Plane patterns):

```
src/
├── app/                    # Next.js App Router (if using Next.js 13+)
│   ├── (auth)/            # Route groups for authentication
│   ├── dashboard/         # Protected dashboard routes
│   ├── api/              # API routes
│   ├── globals.css       # Global styles
│   ├── layout.tsx        # Root layout
│   └── page.tsx          # Home page
├── components/            # Reusable UI components
│   ├── ui/               # Base components (Button, Input, etc.)
│   ├── forms/            # Form-specific components
│   ├── layout/           # Layout components
│   └── features/         # Business logic components
├── hooks/                # Custom React hooks
├── lib/                  # Utility functions and configurations
│   ├── auth.ts           # Authentication utilities
│   ├── db.ts             # Database configuration
│   ├── utils.ts          # General utilities
│   └── validations.ts    # Schema validations
├── stores/               # State management
├── types/                # TypeScript type definitions
└── utils/                # Helper functions
```

**Import Organization Standards**:
```typescript
// 1. External library imports
import React, { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { useMutation, useQuery } from '@tanstack/react-query';

// 2. Internal imports (components)
import { Button } from '@/components/ui/button';
import { Modal } from '@/components/ui/modal';

// 3. Internal imports (utilities)
import { cn } from '@/lib/utils';
import { useAuth } from '@/hooks/use-auth';

// 4. Type imports (last)
import type { User, Project } from '@/types';
```

### 2. Component Design Principles

**Single Responsibility Principle**:
```typescript
// ❌ Bad: Component doing too many things
function UserDashboard({ userId }: { userId: string }) {
  const [user, setUser] = useState<User | null>(null);
  const [projects, setProjects] = useState<Project[]>([]);
  const [notifications, setNotifications] = useState<Notification[]>([]);
  
  // Fetching logic, UI rendering, state management all mixed
  useEffect(() => {
    fetchUser(userId).then(setUser);
    fetchProjects(userId).then(setProjects);
    fetchNotifications(userId).then(setNotifications);
  }, [userId]);

  return (
    <div>
      {/* Complex rendering logic */}
      <UserProfile user={user} />
      <ProjectList projects={projects} />
      <NotificationCenter notifications={notifications} />
    </div>
  );
}

// ✅ Good: Separated concerns
function UserDashboard({ userId }: { userId: string }) {
  return (
    <DashboardLayout>
      <UserProfileSection userId={userId} />
      <ProjectsSection userId={userId} />
      <NotificationsSection userId={userId} />
    </DashboardLayout>
  );
}

function UserProfileSection({ userId }: { userId: string }) {
  const { data: user, isLoading } = useUser(userId);
  
  if (isLoading) return <UserProfileSkeleton />;
  if (!user) return <UserNotFound />;
  
  return <UserProfile user={user} />;
}
```

**Composition over Props Drilling**:
```typescript
// ❌ Bad: Props drilling
function App() {
  const theme = useTheme();
  const user = useUser();
  
  return <Dashboard theme={theme} user={user} />;
}

function Dashboard({ theme, user }: { theme: Theme; user: User }) {
  return <Sidebar theme={theme} user={user} />;
}

function Sidebar({ theme, user }: { theme: Theme; user: User }) {
  return <UserMenu theme={theme} user={user} />;
}

// ✅ Good: Context and composition
function App() {
  return (
    <ThemeProvider>
      <AuthProvider>
        <Dashboard />
      </AuthProvider>
    </ThemeProvider>
  );
}

function Dashboard() {
  return <Sidebar />;
}

function Sidebar() {
  return <UserMenu />;
}

function UserMenu() {
  const theme = useTheme();
  const user = useAuth();
  
  return (
    <Menu style={{ color: theme.colors.text }}>
      Welcome, {user.name}
    </Menu>
  );
}
```

## Performance Optimization Patterns

### 1. Rendering Optimization

**Memoization Best Practices**:
```typescript
// ❌ Bad: Unnecessary re-renders
function TodoList({ todos, onToggle }: TodoListProps) {
  return (
    <div>
      {todos.map(todo => (
        <TodoItem
          key={todo.id}
          todo={todo}
          onToggle={() => onToggle(todo.id)} // New function every render
        />
      ))}
    </div>
  );
}

// ✅ Good: Memoized components and callbacks
const TodoItem = React.memo(({ todo, onToggle }: TodoItemProps) => {
  return (
    <div onClick={onToggle}>
      {todo.text}
    </div>
  );
});

function TodoList({ todos, onToggle }: TodoListProps) {
  const handleToggle = useCallback((id: string) => {
    onToggle(id);
  }, [onToggle]);

  return (
    <div>
      {todos.map(todo => (
        <TodoItem
          key={todo.id}
          todo={todo}
          onToggle={() => handleToggle(todo.id)}
        />
      ))}
    </div>
  );
}

// Even better: Extract to custom hook
function useTodoActions(onToggle: (id: string) => void) {
  return useCallback((id: string) => {
    onToggle(id);
  }, [onToggle]);
}
```

**Lazy Loading and Code Splitting**:
```typescript
// Component lazy loading
const AdminPanel = lazy(() => import('./AdminPanel'));
const UserSettings = lazy(() => import('./UserSettings'));
const Analytics = lazy(() => import('./Analytics'));

function Dashboard() {
  const [activeTab, setActiveTab] = useState('overview');
  
  return (
    <div>
      <TabNavigation activeTab={activeTab} onTabChange={setActiveTab} />
      
      <Suspense fallback={<TabContentSkeleton />}>
        {activeTab === 'admin' && <AdminPanel />}
        {activeTab === 'settings' && <UserSettings />}
        {activeTab === 'analytics' && <Analytics />}
      </Suspense>
    </div>
  );
}

// Route-based code splitting with Next.js
// app/dashboard/admin/page.tsx
import dynamic from 'next/dynamic';

const AdminPanel = dynamic(() => import('@/components/AdminPanel'), {
  loading: () => <AdminPanelSkeleton />,
  ssr: false, // Client-side only if needed
});

export default function AdminPage() {
  return <AdminPanel />;
}
```

### 2. Data Fetching Optimization

**Efficient Query Patterns**:
```typescript
// ❌ Bad: Multiple queries, waterfalls
function UserProfile({ userId }: { userId: string }) {
  const { data: user } = useQuery(['user', userId], () => fetchUser(userId));
  const { data: posts } = useQuery(['posts', userId], () => fetchUserPosts(userId));
  const { data: followers } = useQuery(['followers', userId], () => fetchUserFollowers(userId));
  
  return (
    <div>
      <UserInfo user={user} />
      <UserPosts posts={posts} />
      <UserFollowers followers={followers} />
    </div>
  );
}

// ✅ Good: Parallel queries with prefetching
function UserProfile({ userId }: { userId: string }) {
  // Parallel queries
  const queries = useQueries({
    queries: [
      { queryKey: ['user', userId], queryFn: () => fetchUser(userId) },
      { queryKey: ['posts', userId], queryFn: () => fetchUserPosts(userId) },
      { queryKey: ['followers', userId], queryFn: () => fetchUserFollowers(userId) },
    ],
  });

  const [userQuery, postsQuery, followersQuery] = queries;
  
  return (
    <div>
      <UserInfo user={userQuery.data} isLoading={userQuery.isLoading} />
      <UserPosts posts={postsQuery.data} isLoading={postsQuery.isLoading} />
      <UserFollowers followers={followersQuery.data} isLoading={followersQuery.isLoading} />
    </div>
  );
}

// Even better: Custom hook with prefetching
function useUserProfileData(userId: string) {
  const queryClient = useQueryClient();
  
  // Prefetch related data
  useEffect(() => {
    queryClient.prefetchQuery(['user', userId], () => fetchUser(userId));
    queryClient.prefetchQuery(['posts', userId], () => fetchUserPosts(userId));
  }, [userId, queryClient]);
  
  return useQueries({
    queries: [
      { queryKey: ['user', userId], queryFn: () => fetchUser(userId) },
      { queryKey: ['posts', userId], queryFn: () => fetchUserPosts(userId) },
      { queryKey: ['followers', userId], queryFn: () => fetchUserFollowers(userId) },
    ],
  });
}
```

## State Management Best Practices

### 1. State Placement Strategy

**Local vs Global State Decision Tree**:
```typescript
// Decision framework for state placement
const StateDecisionTree = {
  // 1. Is the state shared between components?
  isShared: {
    yes: {
      // 2. Is it server data or UI state?
      type: {
        serverData: 'Use TanStack Query/SWR',
        uiState: {
          // 3. How complex is the state?
          complexity: {
            simple: 'Use Context API',
            complex: 'Use Zustand/Redux',
          },
        },
      },
    },
    no: {
      // 4. Does the state persist between unmounts?
      persist: {
        yes: 'Use global store with persistence',
        no: 'Use local useState/useReducer',
      },
    },
  },
};

// Examples of proper state placement

// ✅ Local state: Form data, UI interactions
function ContactForm() {
  const [formData, setFormData] = useState({ name: '', email: '' });
  const [isSubmitting, setIsSubmitting] = useState(false);
  
  // This state doesn't need to be global
}

// ✅ Context: Theme, authentication status
const AuthContext = createContext<AuthState | null>(null);
export function AuthProvider({ children }) {
  const [user, setUser] = useState<User | null>(null);
  // Authentication state is shared across the app
}

// ✅ Global store: Complex UI state
const useUIStore = create((set) => ({
  sidebarOpen: false,
  activeModal: null,
  notifications: [],
  // Complex UI state that affects multiple components
}));

// ✅ Server state: API data
function useProjects() {
  return useQuery(['projects'], fetchProjects);
  // Server data with caching, background updates, etc.
}
```

### 2. State Update Patterns

**Immutable Updates**:
```typescript
// ❌ Bad: Mutating state
function TodoList() {
  const [todos, setTodos] = useState<Todo[]>([]);
  
  const addTodo = (text: string) => {
    todos.push({ id: Date.now(), text, completed: false }); // Mutation!
    setTodos(todos);
  };
  
  const toggleTodo = (id: number) => {
    const todo = todos.find(t => t.id === id);
    if (todo) {
      todo.completed = !todo.completed; // Mutation!
      setTodos(todos);
    }
  };
}

// ✅ Good: Immutable updates
function TodoList() {
  const [todos, setTodos] = useState<Todo[]>([]);
  
  const addTodo = useCallback((text: string) => {
    setTodos(prev => [...prev, { id: Date.now(), text, completed: false }]);
  }, []);
  
  const toggleTodo = useCallback((id: number) => {
    setTodos(prev => prev.map(todo => 
      todo.id === id ? { ...todo, completed: !todo.completed } : todo
    ));
  }, []);
  
  const removeTodo = useCallback((id: number) => {
    setTodos(prev => prev.filter(todo => todo.id !== id));
  }, []);
}

// Complex state with useReducer
interface TodoState {
  todos: Todo[];
  filter: 'all' | 'active' | 'completed';
  loading: boolean;
}

type TodoAction = 
  | { type: 'ADD_TODO'; payload: string }
  | { type: 'TOGGLE_TODO'; payload: number }
  | { type: 'SET_FILTER'; payload: TodoState['filter'] }
  | { type: 'SET_LOADING'; payload: boolean };

function todoReducer(state: TodoState, action: TodoAction): TodoState {
  switch (action.type) {
    case 'ADD_TODO':
      return {
        ...state,
        todos: [...state.todos, { 
          id: Date.now(), 
          text: action.payload, 
          completed: false 
        }],
      };
    case 'TOGGLE_TODO':
      return {
        ...state,
        todos: state.todos.map(todo =>
          todo.id === action.payload
            ? { ...todo, completed: !todo.completed }
            : todo
        ),
      };
    case 'SET_FILTER':
      return { ...state, filter: action.payload };
    case 'SET_LOADING':
      return { ...state, loading: action.payload };
    default:
      return state;
  }
}
```

## Error Handling and Resilience

### 1. Error Boundaries and Recovery

**Comprehensive Error Handling**:
```typescript
// Error boundary with recovery options
interface ErrorBoundaryState {
  hasError: boolean;
  error: Error | null;
  errorId: string | null;
}

class ErrorBoundary extends Component<
  { children: ReactNode; fallback?: ComponentType<ErrorFallbackProps> },
  ErrorBoundaryState
> {
  constructor(props: any) {
    super(props);
    this.state = { hasError: false, error: null, errorId: null };
  }

  static getDerivedStateFromError(error: Error): ErrorBoundaryState {
    return {
      hasError: true,
      error,
      errorId: `error-${Date.now()}-${Math.random()}`,
    };
  }

  componentDidCatch(error: Error, errorInfo: ErrorInfo) {
    // Log error to monitoring service
    console.error('Error caught by boundary:', error, errorInfo);
    
    // Send to error tracking
    if (window.gtag) {
      window.gtag('event', 'exception', {
        description: error.message,
        fatal: false,
      });
    }
  }

  handleReset = () => {
    this.setState({ hasError: false, error: null, errorId: null });
  };

  render() {
    if (this.state.hasError) {
      const FallbackComponent = this.props.fallback || DefaultErrorFallback;
      return (
        <FallbackComponent
          error={this.state.error}
          resetError={this.handleReset}
          errorId={this.state.errorId}
        />
      );
    }

    return this.props.children;
  }
}

// Error fallback component
interface ErrorFallbackProps {
  error: Error | null;
  resetError: () => void;
  errorId: string | null;
}

function DefaultErrorFallback({ error, resetError, errorId }: ErrorFallbackProps) {
  return (
    <div className="error-fallback">
      <h2>Something went wrong</h2>
      <p>We apologize for the inconvenience. Please try again.</p>
      
      <div className="error-actions">
        <button onClick={resetError}>Try again</button>
        <button onClick={() => window.location.reload()}>Reload page</button>
      </div>
      
      {process.env.NODE_ENV === 'development' && (
        <details className="error-details">
          <summary>Error details (development only)</summary>
          <pre>{error?.message}</pre>
          <pre>{error?.stack}</pre>
          <p>Error ID: {errorId}</p>
        </details>
      )}
    </div>
  );
}

// Usage with granular boundaries
function App() {
  return (
    <ErrorBoundary>
      <Header />
      <main>
        <ErrorBoundary fallback={SidebarErrorFallback}>
          <Sidebar />
        </ErrorBoundary>
        
        <ErrorBoundary fallback={ContentErrorFallback}>
          <MainContent />
        </ErrorBoundary>
      </main>
    </ErrorBoundary>
  );
}
```

### 2. Async Error Handling

**Query Error Handling with Recovery**:
```typescript
// Global error handling for queries
function GlobalErrorHandler({ children }: { children: ReactNode }) {
  const queryClient = useQueryClient();
  
  useEffect(() => {
    const unsubscribe = queryClient.getQueryCache().subscribe((event) => {
      if (event.type === 'observerResultsUpdated') {
        const { query } = event;
        const error = query.state.error as any;
        
        if (error) {
          // Handle specific error types
          if (error.status === 401) {
            // Redirect to login
            window.location.href = '/auth/login';
          } else if (error.status >= 500) {
            // Show global error message
            toast.error('Server error. Please try again later.');
          }
        }
      }
    });
    
    return unsubscribe;
  }, [queryClient]);
  
  return <>{children}</>;
}

// Component-level error handling with retry
function ProjectList() {
  const {
    data: projects,
    error,
    isLoading,
    isError,
    refetch,
  } = useQuery({
    queryKey: ['projects'],
    queryFn: fetchProjects,
    retry: (failureCount, error) => {
      // Don't retry on 4xx errors
      if (error.status >= 400 && error.status < 500) {
        return false;
      }
      return failureCount < 3;
    },
    retryDelay: (attemptIndex) => Math.min(1000 * 2 ** attemptIndex, 30000),
  });

  if (isLoading) return <ProjectListSkeleton />;
  
  if (isError) {
    return (
      <ErrorState
        title="Failed to load projects"
        message={error.message}
        action={
          <button onClick={() => refetch()}>
            Try again
          </button>
        }
      />
    );
  }

  return <ProjectGrid projects={projects} />;
}
```

## Testing Best Practices

### 1. Testing Strategy

**Testing Pyramid Implementation**:
```typescript
// Unit tests: Test individual functions and hooks
// utils/formatDate.test.ts
import { formatDate } from './formatDate';

describe('formatDate', () => {
  it('formats date correctly', () => {
    const date = new Date('2024-01-15');
    expect(formatDate(date)).toBe('Jan 15, 2024');
  });
  
  it('handles invalid dates', () => {
    expect(formatDate(null)).toBe('Invalid date');
  });
});

// Component tests: Test component behavior
// components/Button.test.tsx
import { render, screen, userEvent } from '@testing-library/react';
import { Button } from './Button';

describe('Button', () => {
  it('calls onClick when clicked', async () => {
    const handleClick = vi.fn();
    render(<Button onClick={handleClick}>Click me</Button>);
    
    await userEvent.click(screen.getByRole('button'));
    expect(handleClick).toHaveBeenCalledTimes(1);
  });
  
  it('shows loading state', () => {
    render(<Button loading>Loading button</Button>);
    expect(screen.getByText('Loading button')).toBeInTheDocument();
    expect(screen.getByRole('button')).toBeDisabled();
  });
});

// Integration tests: Test component interactions
// features/auth/LoginForm.test.tsx
import { render, screen, userEvent, waitFor } from '@testing-library/react';
import { LoginForm } from './LoginForm';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';

const createTestQueryClient = () => new QueryClient({
  defaultOptions: { queries: { retry: false }, mutations: { retry: false } },
});

function renderWithProviders(ui: ReactElement) {
  const queryClient = createTestQueryClient();
  return render(
    <QueryClientProvider client={queryClient}>
      {ui}
    </QueryClientProvider>
  );
}

describe('LoginForm Integration', () => {
  it('submits form with valid data', async () => {
    const mockLogin = vi.fn().mockResolvedValue({ user: { id: '1', email: 'test@example.com' } });
    
    renderWithProviders(<LoginForm onSubmit={mockLogin} />);
    
    await userEvent.type(screen.getByLabelText(/email/i), 'test@example.com');
    await userEvent.type(screen.getByLabelText(/password/i), 'password123');
    await userEvent.click(screen.getByRole('button', { name: /sign in/i }));
    
    await waitFor(() => {
      expect(mockLogin).toHaveBeenCalledWith({
        email: 'test@example.com',
        password: 'password123',
      });
    });
  });
});

// E2E tests: Test complete user flows
// e2e/auth.spec.ts
import { test, expect } from '@playwright/test';

test.describe('Authentication Flow', () => {
  test('user can sign in and access dashboard', async ({ page }) => {
    await page.goto('/auth/login');
    
    await page.fill('[data-testid="email-input"]', 'test@example.com');
    await page.fill('[data-testid="password-input"]', 'password123');
    await page.click('[data-testid="login-button"]');
    
    await expect(page).toHaveURL('/dashboard');
    await expect(page.locator('[data-testid="user-menu"]')).toBeVisible();
  });
});
```

### 2. Test Utilities and Helpers

**Custom Testing Utilities**:
```typescript
// test-utils/render.tsx
import { render as rtlRender, RenderOptions } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { BrowserRouter } from 'react-router-dom';
import { ThemeProvider } from '@/components/ThemeProvider';

interface CustomRenderOptions extends Omit<RenderOptions, 'wrapper'> {
  initialEntries?: string[];
  queryClient?: QueryClient;
}

function createTestQueryClient() {
  return new QueryClient({
    defaultOptions: {
      queries: { retry: false, gcTime: 0 },
      mutations: { retry: false },
    },
  });
}

export function render(
  ui: React.ReactElement,
  {
    initialEntries = ['/'],
    queryClient = createTestQueryClient(),
    ...renderOptions
  }: CustomRenderOptions = {}
) {
  function Wrapper({ children }: { children: React.ReactNode }) {
    return (
      <BrowserRouter>
        <QueryClientProvider client={queryClient}>
          <ThemeProvider>
            {children}
          </ThemeProvider>
        </QueryClientProvider>
      </BrowserRouter>
    );
  }

  return rtlRender(ui, { wrapper: Wrapper, ...renderOptions });
}

// test-utils/factories.ts
import { faker } from '@faker-js/faker';

export const userFactory = (overrides = {}) => ({
  id: faker.string.uuid(),
  email: faker.internet.email(),
  name: faker.person.fullName(),
  avatar: faker.image.avatar(),
  role: 'user' as const,
  createdAt: faker.date.past(),
  ...overrides,
});

export const projectFactory = (overrides = {}) => ({
  id: faker.string.uuid(),
  name: faker.lorem.words(3),
  description: faker.lorem.sentence(),
  status: faker.helpers.arrayElement(['active', 'inactive', 'archived']),
  createdAt: faker.date.past(),
  updatedAt: faker.date.recent(),
  ...overrides,
});

// Usage in tests
describe('UserProfile', () => {
  it('displays user information', () => {
    const user = userFactory({ name: 'John Doe', email: 'john@example.com' });
    render(<UserProfile user={user} />);
    
    expect(screen.getByText('John Doe')).toBeInTheDocument();
    expect(screen.getByText('john@example.com')).toBeInTheDocument();
  });
});
```

## Security Best Practices

### 1. Input Validation and Sanitization

**Comprehensive Validation Strategy**:
```typescript
// Schema-based validation with Zod
import { z } from 'zod';
import DOMPurify from 'dompurify';

// Base validation schemas
const emailSchema = z
  .string()
  .email('Invalid email format')
  .max(254, 'Email too long')
  .transform(email => email.toLowerCase().trim());

const passwordSchema = z
  .string()
  .min(8, 'Password must be at least 8 characters')
  .max(128, 'Password too long')
  .regex(
    /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]/,
    'Password must contain uppercase, lowercase, number, and special character'
  );

const htmlContentSchema = z
  .string()
  .transform(content => DOMPurify.sanitize(content, {
    ALLOWED_TAGS: ['p', 'br', 'strong', 'em', 'ul', 'ol', 'li'],
    ALLOWED_ATTR: [],
  }));

// Form validation with security
export const createPostSchema = z.object({
  title: z
    .string()
    .min(1, 'Title is required')
    .max(200, 'Title too long')
    .transform(title => DOMPurify.sanitize(title.trim())),
  content: htmlContentSchema,
  tags: z
    .array(z.string().max(50))
    .max(10, 'Too many tags')
    .transform(tags => tags.map(tag => DOMPurify.sanitize(tag.trim()))),
  isPublic: z.boolean(),
});

// Server-side validation middleware
export function validateRequest<T>(schema: z.ZodSchema<T>) {
  return (req: Request, res: Response, next: NextFunction) => {
    try {
      const validatedData = schema.parse(req.body);
      req.body = validatedData;
      next();
    } catch (error) {
      if (error instanceof z.ZodError) {
        return res.status(400).json({
          error: 'Validation failed',
          details: error.errors,
        });
      }
      next(error);
    }
  };
}
```

### 2. XSS and CSRF Protection

**Content Security Policy and XSS Prevention**:
```typescript
// next.config.js
const nextConfig = {
  async headers() {
    return [
      {
        source: '/(.*)',
        headers: [
          {
            key: 'Content-Security-Policy',
            value: [
              "default-src 'self'",
              "script-src 'self' 'unsafe-eval' 'unsafe-inline' https://vercel.live",
              "style-src 'self' 'unsafe-inline'",
              "img-src 'self' data: https:",
              "font-src 'self'",
              "connect-src 'self' https:",
              "frame-ancestors 'none'",
            ].join('; '),
          },
          {
            key: 'X-Frame-Options',
            value: 'DENY',
          },
          {
            key: 'X-Content-Type-Options',
            value: 'nosniff',
          },
          {
            key: 'Referrer-Policy',
            value: 'origin-when-cross-origin',
          },
          {
            key: 'Permissions-Policy',
            value: 'camera=(), microphone=(), geolocation=()',
          },
        ],
      },
    ];
  },
};

// CSRF token implementation
import { getCsrfToken } from 'next-auth/react';

export function useCSRFProtection() {
  const [csrfToken, setCsrfToken] = useState<string>('');
  
  useEffect(() => {
    getCsrfToken().then(token => {
      if (token) setCsrfToken(token);
    });
  }, []);
  
  const makeSecureRequest = useCallback(async (url: string, options: RequestInit = {}) => {
    const headers = {
      'Content-Type': 'application/json',
      'X-CSRF-Token': csrfToken,
      ...options.headers,
    };
    
    return fetch(url, {
      ...options,
      headers,
      credentials: 'same-origin',
    });
  }, [csrfToken]);
  
  return { makeSecureRequest, csrfToken };
}
```

## Performance Monitoring and Optimization

### 1. Core Web Vitals Monitoring

```typescript
// lib/performance.ts
import { getCLS, getFID, getFCP, getLCP, getTTFB } from 'web-vitals';

interface PerformanceMetric {
  name: string;
  value: number;
  rating: 'good' | 'needs-improvement' | 'poor';
  delta: number;
  id: string;
}

export function initPerformanceMonitoring() {
  function sendToAnalytics(metric: PerformanceMetric) {
    // Send to your analytics service
    if (window.gtag) {
      window.gtag('event', metric.name, {
        value: Math.round(metric.name === 'CLS' ? metric.value * 1000 : metric.value),
        metric_rating: metric.rating,
        metric_delta: Math.round(metric.delta),
        metric_id: metric.id,
      });
    }
    
    // Log to console in development
    if (process.env.NODE_ENV === 'development') {
      console.log(`${metric.name}: ${metric.value} (${metric.rating})`);
    }
  }

  getCLS(sendToAnalytics);
  getFID(sendToAnalytics);
  getFCP(sendToAnalytics);
  getLCP(sendToAnalytics);
  getTTFB(sendToAnalytics);
}

// Component performance monitoring
export function usePerformanceMonitor(componentName: string) {
  useEffect(() => {
    const startTime = performance.now();
    
    return () => {
      const endTime = performance.now();
      const renderTime = endTime - startTime;
      
      if (renderTime > 16) { // Slower than 60fps
        console.warn(`Slow component render: ${componentName} took ${renderTime.toFixed(2)}ms`);
        
        // Send to monitoring service
        if (window.gtag) {
          window.gtag('event', 'slow_component_render', {
            component_name: componentName,
            render_time: Math.round(renderTime),
          });
        }
      }
    };
  });
}

// Usage in components
function ExpensiveComponent() {
  usePerformanceMonitor('ExpensiveComponent');
  
  // Component logic...
  return <div>...</div>;
}
```

### 2. Bundle Size Optimization

```typescript
// Bundle analyzer configuration
// scripts/analyze-bundle.js
const { BundleAnalyzerPlugin } = require('webpack-bundle-analyzer');

function createBundleAnalyzer() {
  return new BundleAnalyzerPlugin({
    analyzerMode: process.env.ANALYZE === 'server' ? 'server' : 'static',
    openAnalyzer: process.env.ANALYZE === 'server',
    reportFilename: 'bundle-report.html',
  });
}

// Tree shaking optimization
// lib/utils.ts
// ❌ Bad: Importing entire library
import _ from 'lodash';
import * as date from 'date-fns';

// ✅ Good: Importing specific functions
import { debounce } from 'lodash/debounce';
import { format } from 'date-fns/format';
import { isValid } from 'date-fns/isValid';

// Dynamic imports for code splitting
async function loadChartLibrary() {
  const { Chart } = await import('chart.js');
  return Chart;
}

// Conditional polyfills
async function loadPolyfills() {
  if (typeof window !== 'undefined' && !window.IntersectionObserver) {
    await import('intersection-observer');
  }
  
  if (!Array.prototype.flatMap) {
    await import('core-js/features/array/flat-map');
  }
}
```

---

## Navigation

- ← Back to: [Component Library Management](component-library-management.md)
- → Next: [Template Examples](template-examples.md)
- 🏠 Home: [Research Overview](../../README.md)