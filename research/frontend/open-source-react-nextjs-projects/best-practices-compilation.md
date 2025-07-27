# Best Practices Compilation

## Overview

This document compiles the most effective best practices identified from analyzing production-ready open source React and Next.js projects. These practices have been proven in real-world applications and represent the current industry standards for building scalable, maintainable, and performant React applications.

## 🏗️ Project Architecture Best Practices

### Directory Structure and Organization

#### ✅ Recommended Structure
Based on successful projects like Cal.com, Vercel Dashboard, and Supabase:

```
src/
├── app/                 # Next.js App Router (if using App Router)
├── components/          # Reusable UI components
│   ├── ui/             # Base design system components
│   ├── forms/          # Form-specific components
│   ├── layout/         # Layout components (header, sidebar, etc.)
│   └── features/       # Feature-specific components
├── hooks/              # Custom React hooks
├── stores/             # State management (Zustand stores or Redux slices)
├── lib/                # Utility functions and configurations
│   ├── utils.ts        # General utilities
│   ├── api.ts          # API client configuration
│   ├── auth.ts         # Authentication utilities
│   └── validations.ts  # Schema validations
├── types/              # TypeScript type definitions
├── constants/          # Application constants
├── styles/             # Global styles and CSS
└── __tests__/          # Test files and utilities
```

#### 🎯 Key Principles
1. **Feature-based organization** for larger applications
2. **Separation of concerns** between UI, logic, and data
3. **Consistent naming conventions** across the project
4. **Clear import/export patterns** with barrel exports

### Component Architecture

#### ✅ Component Composition Patterns
```typescript
// ✅ Good: Composable button component
interface ButtonProps {
  variant?: 'primary' | 'secondary' | 'outline';
  size?: 'sm' | 'md' | 'lg';
  children: React.ReactNode;
  onClick?: () => void;
  disabled?: boolean;
  loading?: boolean;
}

export const Button: React.FC<ButtonProps> = ({
  variant = 'primary',
  size = 'md',
  children,
  loading,
  disabled,
  ...props
}) => {
  return (
    <button
      className={cn(buttonVariants({ variant, size }))}
      disabled={disabled || loading}
      {...props}
    >
      {loading ? <Spinner /> : children}
    </button>
  );
};

// ✅ Usage with compound components
<Button variant="primary" size="lg" loading={isSubmitting}>
  Submit Form
</Button>
```

#### ❌ Anti-patterns to Avoid
```typescript
// ❌ Bad: Monolithic component with too many responsibilities
const UserDashboard = () => {
  // Don't mix data fetching, UI logic, and business logic
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(false);
  const [filter, setFilter] = useState('');
  
  useEffect(() => {
    // Complex data fetching logic
    fetchUsers().then(setUsers);
  }, []);
  
  const filteredUsers = users.filter(/* complex filtering logic */);
  const exportData = () => { /* complex export logic */ };
  
  return (
    <div>
      {/* 200+ lines of JSX */}
    </div>
  );
};

// ✅ Better: Split into focused components
const UserDashboard = () => {
  return (
    <div>
      <UserFilters />
      <UserList />
      <UserActions />
    </div>
  );
};
```

## 🔄 State Management Best Practices

### Zustand Best Practices

#### ✅ Store Organization
```typescript
// ✅ Good: Feature-based store with clear separation
interface AuthState {
  user: User | null;
  isAuthenticated: boolean;
  isLoading: boolean;
}

interface AuthActions {
  login: (credentials: LoginCredentials) => Promise<void>;
  logout: () => void;
  refreshToken: () => Promise<void>;
}

export const useAuthStore = create<AuthState & AuthActions>()(
  devtools(
    persist(
      immer((set, get) => ({
        // State
        user: null,
        isAuthenticated: false,
        isLoading: false,
        
        // Actions
        login: async (credentials) => {
          set((state) => { state.isLoading = true; });
          try {
            const { user, token } = await authApi.login(credentials);
            set((state) => {
              state.user = user;
              state.isAuthenticated = true;
              state.isLoading = false;
            });
          } catch (error) {
            set((state) => { state.isLoading = false; });
            throw error;
          }
        },
        
        logout: () => {
          set((state) => {
            state.user = null;
            state.isAuthenticated = false;
          });
        },
      })),
      { name: 'auth-storage' }
    ),
    { name: 'auth-store' }
  )
);
```

#### ✅ Selective State Subscriptions
```typescript
// ✅ Good: Selective subscriptions for performance
export const useAuth = () => {
  return useAuthStore(
    useShallow((state) => ({
      user: state.user,
      isAuthenticated: state.isAuthenticated,
      login: state.login,
      logout: state.logout,
    }))
  );
};

// ✅ Computed selectors with memoization
export const useUserPermissions = () => {
  return useAuthStore(
    useCallback(
      (state) => state.user?.roles?.flatMap(role => role.permissions) ?? [],
      []
    )
  );
};
```

### Redux Toolkit Best Practices

#### ✅ Slice Organization
```typescript
// ✅ Good: Feature-based slice with RTK Query
export const projectsApi = createApi({
  reducerPath: 'projectsApi',
  baseQuery: fetchBaseQuery({
    baseUrl: '/api/projects',
    prepareHeaders: (headers, { getState }) => {
      const token = (getState() as RootState).auth.token;
      if (token) headers.set('Authorization', `Bearer ${token}`);
      return headers;
    },
  }),
  tagTypes: ['Project'],
  endpoints: (builder) => ({
    getProjects: builder.query<Project[], void>({
      query: () => '',
      providesTags: ['Project'],
    }),
    createProject: builder.mutation<Project, CreateProjectRequest>({
      query: (newProject) => ({
        url: '',
        method: 'POST',
        body: newProject,
      }),
      invalidatesTags: ['Project'],
    }),
  }),
});
```

## 🎨 UI/UX Best Practices

### Component Design System

#### ✅ Design Token Implementation
```typescript
// ✅ Good: Consistent design tokens
export const designTokens = {
  colors: {
    primary: {
      50: '#eff6ff',
      500: '#3b82f6',
      900: '#1e3a8a',
    },
    gray: {
      50: '#f9fafb',
      500: '#6b7280',
      900: '#111827',
    },
  },
  spacing: {
    xs: '0.5rem',
    sm: '1rem',
    md: '1.5rem',
    lg: '2rem',
    xl: '3rem',
  },
  typography: {
    fontFamily: {
      sans: ['Inter', 'system-ui', 'sans-serif'],
      mono: ['Fira Code', 'monospace'],
    },
    fontSize: {
      xs: '0.75rem',
      sm: '0.875rem',
      base: '1rem',
      lg: '1.125rem',
      xl: '1.25rem',
    },
  },
} as const;
```

#### ✅ Accessible Component Patterns
```typescript
// ✅ Good: Accessible form component
interface FormFieldProps {
  label: string;
  error?: string;
  required?: boolean;
  children: React.ReactNode;
}

export const FormField: React.FC<FormFieldProps> = ({
  label,
  error,
  required,
  children,
}) => {
  const id = useId();
  const errorId = error ? `${id}-error` : undefined;
  
  return (
    <div className="form-field">
      <label htmlFor={id} className="form-label">
        {label}
        {required && <span aria-label="required">*</span>}
      </label>
      {React.cloneElement(children as React.ReactElement, {
        id,
        'aria-describedby': errorId,
        'aria-invalid': !!error,
      })}
      {error && (
        <div id={errorId} role="alert" className="form-error">
          {error}
        </div>
      )}
    </div>
  );
};
```

### Responsive Design

#### ✅ Mobile-First Approach
```typescript
// ✅ Good: Mobile-first responsive design
const responsiveClasses = {
  container: 'w-full px-4 sm:px-6 lg:px-8 max-w-7xl mx-auto',
  grid: 'grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 lg:gap-6',
  card: 'p-4 sm:p-6 rounded-lg shadow-sm border',
  button: 'px-4 py-2 sm:px-6 sm:py-3 text-sm sm:text-base',
};
```

## 🚀 Performance Best Practices

### Code Splitting and Lazy Loading

#### ✅ Strategic Code Splitting
```typescript
// ✅ Good: Route-based code splitting
import { lazy, Suspense } from 'react';
import { LoadingSpinner } from '@/components/ui/loading-spinner';

// Lazy load heavy pages
const Dashboard = lazy(() => import('@/pages/Dashboard'));
const Analytics = lazy(() => import('@/pages/Analytics'));
const Settings = lazy(() => import('@/pages/Settings'));

// Component-based lazy loading for modals
const CreateProjectModal = lazy(() => import('@/components/modals/CreateProjectModal'));

export const AppRoutes = () => {
  return (
    <Routes>
      <Route 
        path="/dashboard" 
        element={
          <Suspense fallback={<LoadingSpinner />}>
            <Dashboard />
          </Suspense>
        } 
      />
    </Routes>
  );
};
```

#### ✅ Image Optimization
```typescript
// ✅ Good: Optimized image component (Next.js)
import Image from 'next/image';

interface OptimizedImageProps {
  src: string;
  alt: string;
  width: number;
  height: number;
  priority?: boolean;
  className?: string;
}

export const OptimizedImage: React.FC<OptimizedImageProps> = ({
  src,
  alt,
  width,
  height,
  priority = false,
  className,
}) => {
  return (
    <Image
      src={src}
      alt={alt}
      width={width}
      height={height}
      priority={priority}
      className={className}
      placeholder="blur"
      blurDataURL="data:image/jpeg;base64,..."
      sizes="(max-width: 768px) 100vw, (max-width: 1200px) 50vw, 33vw"
    />
  );
};
```

### Memoization and Optimization

#### ✅ Strategic Memoization
```typescript
// ✅ Good: Memoize expensive computations
const ExpensiveList: React.FC<{ items: Item[]; filter: string }> = ({
  items,
  filter,
}) => {
  const filteredItems = useMemo(() => {
    return items.filter(item => 
      item.name.toLowerCase().includes(filter.toLowerCase())
    );
  }, [items, filter]);
  
  const sortedItems = useMemo(() => {
    return filteredItems.sort((a, b) => a.priority - b.priority);
  }, [filteredItems]);
  
  return (
    <div>
      {sortedItems.map(item => (
        <ListItem key={item.id} item={item} />
      ))}
    </div>
  );
};

// ✅ Memoize stable callback functions
const ParentComponent: React.FC = () => {
  const [count, setCount] = useState(0);
  const [name, setName] = useState('');
  
  // Memoize callback to prevent unnecessary re-renders
  const handleIncrement = useCallback(() => {
    setCount(prev => prev + 1);
  }, []);
  
  return (
    <div>
      <input value={name} onChange={(e) => setName(e.target.value)} />
      <ChildComponent onIncrement={handleIncrement} />
    </div>
  );
};
```

## 🔒 Security Best Practices

### Authentication and Authorization

#### ✅ Secure Token Handling
```typescript
// ✅ Good: Secure token storage and management
class AuthTokenManager {
  private static readonly TOKEN_KEY = 'auth_token';
  private static readonly REFRESH_KEY = 'refresh_token';
  
  static setTokens(accessToken: string, refreshToken: string) {
    // Store access token in memory or secure httpOnly cookie
    // Never store sensitive tokens in localStorage for production
    if (typeof window !== 'undefined') {
      // For demo purposes - use httpOnly cookies in production
      sessionStorage.setItem(this.TOKEN_KEY, accessToken);
      // Refresh token should be in httpOnly cookie
      document.cookie = `${this.REFRESH_KEY}=${refreshToken}; httpOnly; secure; sameSite=strict`;
    }
  }
  
  static getAccessToken(): string | null {
    if (typeof window !== 'undefined') {
      return sessionStorage.getItem(this.TOKEN_KEY);
    }
    return null;
  }
  
  static clearTokens() {
    if (typeof window !== 'undefined') {
      sessionStorage.removeItem(this.TOKEN_KEY);
      document.cookie = `${this.REFRESH_KEY}=; expires=Thu, 01 Jan 1970 00:00:00 GMT; path=/`;
    }
  }
}
```

#### ✅ Input Validation and Sanitization
```typescript
// ✅ Good: Client-side validation with Zod
import { z } from 'zod';

export const createUserSchema = z.object({
  email: z.string().email('Invalid email format'),
  password: z.string()
    .min(8, 'Password must be at least 8 characters')
    .regex(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/, 'Password must contain uppercase, lowercase, and number'),
  name: z.string()
    .min(2, 'Name must be at least 2 characters')
    .max(50, 'Name must be less than 50 characters')
    .regex(/^[a-zA-Z\s]+$/, 'Name can only contain letters and spaces'),
  role: z.enum(['user', 'admin', 'moderator']),
});

// Component usage
const CreateUserForm: React.FC = () => {
  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<CreateUserFormData>({
    resolver: zodResolver(createUserSchema),
  });
  
  const onSubmit = async (data: CreateUserFormData) => {
    // Data is already validated on client side
    // Always validate again on server side
    try {
      await createUser(data);
    } catch (error) {
      // Handle server validation errors
    }
  };
  
  return (/* form JSX */);
};
```

### Data Protection

#### ✅ Environment Variable Management
```typescript
// ✅ Good: Environment variable validation
import { z } from 'zod';

const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'production', 'test']),
  NEXT_PUBLIC_API_URL: z.string().url(),
  JWT_SECRET: z.string().min(32),
  DATABASE_URL: z.string().url(),
  STRIPE_PUBLIC_KEY: z.string().startsWith('pk_'),
  STRIPE_SECRET_KEY: z.string().startsWith('sk_'),
});

export const env = envSchema.parse(process.env);

// Usage in components
const apiClient = new ApiClient(env.NEXT_PUBLIC_API_URL);
```

## 🧪 Testing Best Practices

### Unit Testing

#### ✅ Component Testing Patterns
```typescript
// ✅ Good: Comprehensive component testing
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { LoginForm } from '../LoginForm';

describe('LoginForm', () => {
  it('renders all form elements', () => {
    render(<LoginForm />);
    
    expect(screen.getByLabelText(/email/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/password/i)).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /sign in/i })).toBeInTheDocument();
  });
  
  it('validates required fields', async () => {
    const user = userEvent.setup();
    render(<LoginForm />);
    
    const submitButton = screen.getByRole('button', { name: /sign in/i });
    await user.click(submitButton);
    
    expect(await screen.findByText(/email is required/i)).toBeInTheDocument();
    expect(await screen.findByText(/password is required/i)).toBeInTheDocument();
  });
  
  it('submits form with valid data', async () => {
    const mockOnSubmit = jest.fn();
    const user = userEvent.setup();
    
    render(<LoginForm onSubmit={mockOnSubmit} />);
    
    await user.type(screen.getByLabelText(/email/i), 'test@example.com');
    await user.type(screen.getByLabelText(/password/i), 'password123');
    await user.click(screen.getByRole('button', { name: /sign in/i }));
    
    await waitFor(() => {
      expect(mockOnSubmit).toHaveBeenCalledWith({
        email: 'test@example.com',
        password: 'password123',
      });
    });
  });
});
```

### Integration Testing

#### ✅ API Integration Testing
```typescript
// ✅ Good: Mock service worker for API testing
import { rest } from 'msw';
import { setupServer } from 'msw/node';

const server = setupServer(
  rest.post('/api/auth/login', (req, res, ctx) => {
    return res(
      ctx.status(200),
      ctx.json({
        user: { id: '1', email: 'test@example.com', name: 'Test User' },
        token: 'mock-jwt-token',
      })
    );
  }),
  
  rest.get('/api/projects', (req, res, ctx) => {
    return res(
      ctx.status(200),
      ctx.json([
        { id: '1', name: 'Project 1', status: 'active' },
        { id: '2', name: 'Project 2', status: 'inactive' },
      ])
    );
  })
);

beforeAll(() => server.listen());
afterEach(() => server.resetHandlers());
afterAll(() => server.close());
```

## 📱 Accessibility Best Practices

### Semantic HTML and ARIA

#### ✅ Accessible Component Implementation
```typescript
// ✅ Good: Accessible modal component
interface ModalProps {
  isOpen: boolean;
  onClose: () => void;
  title: string;
  children: React.ReactNode;
}

export const Modal: React.FC<ModalProps> = ({
  isOpen,
  onClose,
  title,
  children,
}) => {
  const titleId = useId();
  const descriptionId = useId();
  
  useEffect(() => {
    if (isOpen) {
      document.body.style.overflow = 'hidden';
      return () => {
        document.body.style.overflow = 'unset';
      };
    }
  }, [isOpen]);
  
  if (!isOpen) return null;
  
  return (
    <div
      className="modal-overlay"
      onClick={onClose}
      role="dialog"
      aria-modal="true"
      aria-labelledby={titleId}
      aria-describedby={descriptionId}
    >
      <div
        className="modal-content"
        onClick={(e) => e.stopPropagation()}
      >
        <header className="modal-header">
          <h2 id={titleId}>{title}</h2>
          <button
            onClick={onClose}
            aria-label="Close modal"
            className="modal-close"
          >
            ×
          </button>
        </header>
        <div id={descriptionId} className="modal-body">
          {children}
        </div>
      </div>
    </div>
  );
};
```

### Keyboard Navigation

#### ✅ Focus Management
```typescript
// ✅ Good: Focus trap for modals
import { useEffect, useRef } from 'react';

export const useFocusTrap = (isActive: boolean) => {
  const containerRef = useRef<HTMLDivElement>(null);
  
  useEffect(() => {
    if (!isActive || !containerRef.current) return;
    
    const container = containerRef.current;
    const focusableElements = container.querySelectorAll(
      'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
    );
    
    const firstElement = focusableElements[0] as HTMLElement;
    const lastElement = focusableElements[focusableElements.length - 1] as HTMLElement;
    
    const handleTabKey = (e: KeyboardEvent) => {
      if (e.key === 'Tab') {
        if (e.shiftKey) {
          if (document.activeElement === firstElement) {
            e.preventDefault();
            lastElement.focus();
          }
        } else {
          if (document.activeElement === lastElement) {
            e.preventDefault();
            firstElement.focus();
          }
        }
      }
    };
    
    container.addEventListener('keydown', handleTabKey);
    firstElement?.focus();
    
    return () => {
      container.removeEventListener('keydown', handleTabKey);
    };
  }, [isActive]);
  
  return containerRef;
};
```

## 🔧 Development Workflow Best Practices

### Code Quality

#### ✅ ESLint and Prettier Configuration
```json
// .eslintrc.json
{
  "extends": [
    "next/core-web-vitals",
    "@typescript-eslint/recommended",
    "prettier"
  ],
  "parser": "@typescript-eslint/parser",
  "plugins": ["@typescript-eslint"],
  "rules": {
    "@typescript-eslint/no-unused-vars": "error",
    "@typescript-eslint/no-explicit-any": "warn",
    "@typescript-eslint/prefer-nullish-coalescing": "error",
    "@typescript-eslint/prefer-optional-chain": "error",
    "prefer-const": "error",
    "react-hooks/exhaustive-deps": "error",
    "react/jsx-boolean-value": ["error", "never"],
    "react/jsx-curly-brace-presence": ["error", "never"]
  }
}
```

#### ✅ Git Hooks and Pre-commit Checks
```json
// package.json
{
  "husky": {
    "hooks": {
      "pre-commit": "lint-staged",
      "pre-push": "npm run type-check && npm run test"
    }
  },
  "lint-staged": {
    "*.{ts,tsx}": [
      "eslint --fix",
      "prettier --write"
    ],
    "*.{json,md}": [
      "prettier --write"
    ]
  }
}
```

### Documentation

#### ✅ Component Documentation
```typescript
/**
 * Button component with multiple variants and states
 * 
 * @example
 * ```tsx
 * <Button variant="primary" size="lg" onClick={handleClick}>
 *   Click me
 * </Button>
 * ```
 */
interface ButtonProps {
  /** Button visual style variant */
  variant?: 'primary' | 'secondary' | 'outline' | 'ghost';
  /** Button size */
  size?: 'sm' | 'md' | 'lg';
  /** Whether button is in loading state */
  loading?: boolean;
  /** Button content */
  children: React.ReactNode;
  /** Click handler */
  onClick?: () => void;
}

export const Button: React.FC<ButtonProps> = ({ ... }) => {
  // Implementation
};
```

## 🚫 Common Anti-Patterns to Avoid

### State Management Anti-Patterns

#### ❌ Prop Drilling
```typescript
// ❌ Bad: Excessive prop drilling
const App = () => {
  const [user, setUser] = useState(null);
  return <Dashboard user={user} setUser={setUser} />;
};

const Dashboard = ({ user, setUser }) => {
  return <Sidebar user={user} setUser={setUser} />;
};

const Sidebar = ({ user, setUser }) => {
  return <UserProfile user={user} setUser={setUser} />;
};

// ✅ Better: Use context or state management library
const App = () => {
  return (
    <AuthProvider>
      <Dashboard />
    </AuthProvider>
  );
};
```

#### ❌ Overusing useEffect
```typescript
// ❌ Bad: Unnecessary useEffect
const UserProfile = ({ userId }) => {
  const [user, setUser] = useState(null);
  
  useEffect(() => {
    if (userId) {
      fetchUser(userId).then(setUser);
    }
  }, [userId]);
  
  return <div>{user?.name}</div>;
};

// ✅ Better: Use React Query or SWR
const UserProfile = ({ userId }) => {
  const { data: user } = useQuery(['user', userId], () => fetchUser(userId));
  return <div>{user?.name}</div>;
};
```

### Performance Anti-Patterns

#### ❌ Unnecessary Re-renders
```typescript
// ❌ Bad: Creating objects in render
const Component = () => {
  return (
    <ChildComponent 
      style={{ margin: 10 }} // New object every render
      data={items.filter(item => item.active)} // New array every render
    />
  );
};

// ✅ Better: Memoize or move outside render
const Component = () => {
  const style = useMemo(() => ({ margin: 10 }), []);
  const activeItems = useMemo(() => items.filter(item => item.active), [items]);
  
  return <ChildComponent style={style} data={activeItems} />;
};
```

## 📈 Monitoring and Analytics

### Performance Monitoring

#### ✅ Core Web Vitals Tracking
```typescript
// ✅ Good: Performance monitoring
export const performanceMonitor = {
  trackWebVitals: () => {
    if (typeof window !== 'undefined') {
      import('web-vitals').then(({ getCLS, getFID, getFCP, getLCP, getTTFB }) => {
        getCLS(console.log);
        getFID(console.log);
        getFCP(console.log);
        getLCP(console.log);
        getTTFB(console.log);
      });
    }
  },
  
  trackUserInteraction: (action: string, category: string) => {
    // Track user interactions for analytics
    if (typeof gtag !== 'undefined') {
      gtag('event', action, {
        event_category: category,
        event_label: window.location.pathname,
      });
    }
  },
};
```

### Error Tracking

#### ✅ Error Boundary Implementation
```typescript
// ✅ Good: Comprehensive error boundary
interface ErrorBoundaryState {
  hasError: boolean;
  error?: Error;
  errorInfo?: ErrorInfo;
}

export class ErrorBoundary extends Component<
  { children: ReactNode; fallback?: ComponentType<any> },
  ErrorBoundaryState
> {
  constructor(props: any) {
    super(props);
    this.state = { hasError: false };
  }
  
  static getDerivedStateFromError(error: Error): ErrorBoundaryState {
    return { hasError: true, error };
  }
  
  componentDidCatch(error: Error, errorInfo: ErrorInfo) {
    console.error('Error boundary caught an error:', error, errorInfo);
    
    // Send error to monitoring service
    if (process.env.NODE_ENV === 'production') {
      // Example: Sentry, LogRocket, etc.
      errorMonitoringService.captureException(error, {
        extra: errorInfo,
        tags: { component: 'ErrorBoundary' },
      });
    }
    
    this.setState({ errorInfo });
  }
  
  render() {
    if (this.state.hasError) {
      const Fallback = this.props.fallback || DefaultErrorFallback;
      return <Fallback error={this.state.error} errorInfo={this.state.errorInfo} />;
    }
    
    return this.props.children;
  }
}
```

## 🎯 Conclusion

These best practices represent proven patterns from successful production React applications. Key takeaways:

1. **Architecture**: Organize code by features, maintain clear separation of concerns
2. **State Management**: Choose the right tool for the job, avoid over-engineering
3. **Performance**: Implement strategic optimizations, measure what matters
4. **Security**: Validate inputs, protect sensitive data, follow security principles
5. **Testing**: Test user behavior, not implementation details
6. **Accessibility**: Build for all users from the start
7. **Development Workflow**: Automate quality checks, document decisions

Remember that best practices evolve with the ecosystem. Regularly review and update your practices based on new tools, techniques, and community standards.

---

**Navigation**
- ← Back to: [Implementation Guide](implementation-guide.md)
- → Next: [Comparison Analysis](comparison-analysis.md)
- → Related: [Redux Implementation Patterns](redux-implementation-patterns.md)
- → Related: [Zustand State Management Analysis](zustand-state-management-analysis.md)