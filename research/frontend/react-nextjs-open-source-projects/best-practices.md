# Best Practices for Production React/Next.js Applications

## 🎯 Overview

Consolidated best practices derived from analyzing 25+ production-ready React and Next.js open source projects. These guidelines represent proven patterns used by successful applications in production environments.

## 🏗️ Project Structure & Organization

### Recommended Folder Structure

```
src/
├── app/                    # Next.js 13+ App Router
│   ├── (auth)/            # Route groups
│   │   ├── signin/
│   │   └── signup/
│   ├── dashboard/
│   │   ├── layout.tsx
│   │   ├── page.tsx
│   │   └── loading.tsx
│   ├── globals.css
│   ├── layout.tsx
│   └── page.tsx
├── components/            # Reusable UI components
│   ├── ui/               # Base components (Button, Input, etc.)
│   ├── forms/            # Form-specific components
│   ├── layout/           # Layout components
│   └── common/           # Shared components
├── features/             # Feature-based modules
│   ├── auth/
│   │   ├── components/
│   │   ├── hooks/
│   │   ├── services/
│   │   └── types.ts
│   └── dashboard/
├── hooks/                # Custom React hooks
├── lib/                  # Utility functions and configurations
├── stores/               # State management
├── types/                # TypeScript type definitions
├── utils/                # Helper functions
└── constants/            # Application constants
```

### Feature-Based Organization

**✅ Do**: Organize by features, not by file types
```
features/
├── auth/
│   ├── components/
│   │   ├── LoginForm.tsx
│   │   └── SignupForm.tsx
│   ├── hooks/
│   │   └── useAuth.ts
│   ├── services/
│   │   └── authService.ts
│   └── types.ts
```

**❌ Don't**: Organize by file types only
```
components/
├── LoginForm.tsx
├── SignupForm.tsx
├── ProjectCard.tsx
└── TaskList.tsx
hooks/
├── useAuth.ts
├── useProjects.ts
└── useTasks.ts
```

## 💻 Component Design Patterns

### Component Composition Patterns

#### 1. Compound Components (Pattern from React Hook Form)

```typescript
// Compound component pattern for forms
interface FormProps {
  onSubmit: (data: any) => void;
  children: React.ReactNode;
}

interface FormFieldProps {
  name: string;
  label: string;
  children: React.ReactNode;
}

interface FormErrorProps {
  name: string;
}

// Main Form component
export function Form({ onSubmit, children }: FormProps) {
  const methods = useForm();
  
  return (
    <FormProvider {...methods}>
      <form onSubmit={methods.handleSubmit(onSubmit)}>
        {children}
      </form>
    </FormProvider>
  );
}

// Field component
Form.Field = function FormField({ name, label, children }: FormFieldProps) {
  return (
    <div className="form-field">
      <label htmlFor={name}>{label}</label>
      {children}
    </div>
  );
};

// Error component
Form.Error = function FormError({ name }: FormErrorProps) {
  const { formState } = useFormContext();
  const error = formState.errors[name];
  
  if (!error) return null;
  
  return <span className="error">{error.message}</span>;
};

// Usage
<Form onSubmit={handleSubmit}>
  <Form.Field name="email" label="Email">
    <Input {...register('email')} />
    <Form.Error name="email" />
  </Form.Field>
  
  <Form.Field name="password" label="Password">
    <Input type="password" {...register('password')} />
    <Form.Error name="password" />
  </Form.Field>
</Form>
```

#### 2. Render Props Pattern

```typescript
// Data fetcher with render props
interface DataFetcherProps<T> {
  url: string;
  children: (data: {
    data: T | null;
    loading: boolean;
    error: string | null;
    refetch: () => void;
  }) => React.ReactNode;
}

export function DataFetcher<T>({ url, children }: DataFetcherProps<T>) {
  const { data, isLoading, error, refetch } = useQuery({
    queryKey: [url],
    queryFn: () => fetch(url).then(res => res.json()),
  });
  
  return (
    <>
      {children({
        data: data || null,
        loading: isLoading,
        error: error?.message || null,
        refetch,
      })}
    </>
  );
}

// Usage
<DataFetcher<User[]> url="/api/users">
  {({ data, loading, error, refetch }) => {
    if (loading) return <LoadingSpinner />;
    if (error) return <ErrorMessage error={error} onRetry={refetch} />;
    return <UserList users={data} />;
  }}
</DataFetcher>
```

#### 3. Headless Component Pattern

```typescript
// Headless dropdown component
interface UseDropdownProps {
  defaultOpen?: boolean;
  onOpenChange?: (open: boolean) => void;
}

export function useDropdown({ defaultOpen = false, onOpenChange }: UseDropdownProps = {}) {
  const [isOpen, setIsOpen] = useState(defaultOpen);
  const dropdownRef = useRef<HTMLDivElement>(null);
  
  const toggle = useCallback(() => {
    const newState = !isOpen;
    setIsOpen(newState);
    onOpenChange?.(newState);
  }, [isOpen, onOpenChange]);
  
  const close = useCallback(() => {
    setIsOpen(false);
    onOpenChange?.(false);
  }, [onOpenChange]);
  
  // Click outside to close
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (dropdownRef.current && !dropdownRef.current.contains(event.target as Node)) {
        close();
      }
    };
    
    if (isOpen) {
      document.addEventListener('mousedown', handleClickOutside);
      return () => document.removeEventListener('mousedown', handleClickOutside);
    }
  }, [isOpen, close]);
  
  return {
    isOpen,
    toggle,
    close,
    dropdownRef,
    getToggleProps: () => ({
      onClick: toggle,
      'aria-expanded': isOpen,
      'aria-haspopup': true,
    }),
    getMenuProps: () => ({
      ref: dropdownRef,
      style: { display: isOpen ? 'block' : 'none' },
    }),
  };
}

// Usage with any UI
function CustomDropdown() {
  const { isOpen, getToggleProps, getMenuProps } = useDropdown();
  
  return (
    <div>
      <button {...getToggleProps()}>
        Menu {isOpen ? '▲' : '▼'}
      </button>
      <div {...getMenuProps()}>
        <MenuItem>Option 1</MenuItem>
        <MenuItem>Option 2</MenuItem>
      </div>
    </div>
  );
}
```

### Component Prop Patterns

#### Prop Spreading with TypeScript

```typescript
// Extend native HTML props
interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'primary' | 'secondary' | 'danger';
  size?: 'sm' | 'md' | 'lg';
  loading?: boolean;
}

export const Button = forwardRef<HTMLButtonElement, ButtonProps>(
  ({ variant = 'primary', size = 'md', loading, children, className, disabled, ...props }, ref) => {
    return (
      <button
        ref={ref}
        className={cn(
          buttonVariants({ variant, size }),
          className
        )}
        disabled={disabled || loading}
        {...props}
      >
        {loading && <Spinner className="mr-2" />}
        {children}
      </button>
    );
  }
);
```

#### Polymorphic Components

```typescript
// Component that can render as different elements
type PolymorphicProps<E extends React.ElementType> = {
  as?: E;
  children?: React.ReactNode;
  className?: string;
} & Omit<React.ComponentPropsWithoutRef<E>, keyof { as?: E; children?: React.ReactNode; className?: string }>;

export function Polymorphic<E extends React.ElementType = 'div'>({
  as,
  children,
  className,
  ...props
}: PolymorphicProps<E>) {
  const Component = as || 'div';
  
  return (
    <Component className={cn('base-styles', className)} {...props}>
      {children}
    </Component>
  );
}

// Usage
<Polymorphic as="button" onClick={handleClick}>Button</Polymorphic>
<Polymorphic as="a" href="/link">Link</Polymorphic>
<Polymorphic as="h1">Heading</Polymorphic>
```

## 🔧 TypeScript Best Practices

### Type Definitions

#### Domain-Driven Types

```typescript
// types/user.ts - Domain types
export interface User {
  readonly id: string;
  email: string;
  name: string;
  avatar?: string;
  role: UserRole;
  preferences: UserPreferences;
  readonly createdAt: string;
  readonly updatedAt: string;
}

export type UserRole = 'admin' | 'user' | 'guest';

export interface UserPreferences {
  theme: 'light' | 'dark';
  notifications: {
    email: boolean;
    push: boolean;
    marketing: boolean;
  };
  language: string;
}

// API-specific types
export type CreateUserRequest = Omit<User, 'id' | 'createdAt' | 'updatedAt'>;
export type UpdateUserRequest = Partial<Pick<User, 'name' | 'avatar' | 'preferences'>>;
export type UserResponse = User;
export type UsersListResponse = {
  users: User[];
  total: number;
  page: number;
  limit: number;
};
```

#### Generic Utility Types

```typescript
// types/api.ts - Generic API types
export interface ApiResponse<T> {
  data: T;
  message?: string;
  success: boolean;
}

export interface ApiError {
  error: string;
  details?: Record<string, string[]>;
  statusCode: number;
}

export interface PaginatedResponse<T> {
  items: T[];
  total: number;
  page: number;
  limit: number;
  hasMore: boolean;
}

export interface ApiFilters {
  search?: string;
  page?: number;
  limit?: number;
  sortBy?: string;
  sortOrder?: 'asc' | 'desc';
}

// Hook result types
export interface UseQueryResult<T> {
  data: T | undefined;
  loading: boolean;
  error: ApiError | null;
  refetch: () => void;
}

export interface UseMutationResult<TData, TVariables> {
  mutate: (variables: TVariables) => Promise<TData>;
  loading: boolean;
  error: ApiError | null;
}
```

#### Strict Component Props

```typescript
// Component prop validation with strict types
interface BaseProps {
  children?: React.ReactNode;
  className?: string;
  testId?: string;
}

interface CardProps extends BaseProps {
  title: string;
  description?: string;
  actions?: React.ReactNode;
  variant?: 'default' | 'outlined' | 'elevated';
}

// Use satisfies for strict object validation
const cardVariants = {
  default: 'bg-white border border-gray-200',
  outlined: 'border-2 border-gray-300',
  elevated: 'shadow-lg bg-white',
} as const satisfies Record<NonNullable<CardProps['variant']>, string>;

export function Card({ 
  title, 
  description, 
  actions, 
  variant = 'default', 
  children, 
  className,
  testId 
}: CardProps) {
  return (
    <div 
      className={cn(cardVariants[variant], className)}
      data-testid={testId}
    >
      <div className="p-4">
        <h3 className="text-lg font-semibold">{title}</h3>
        {description && <p className="text-gray-600">{description}</p>}
        {children}
      </div>
      {actions && <div className="p-4 border-t">{actions}</div>}
    </div>
  );
}
```

## 🎣 Custom Hooks Patterns

### Data Fetching Hooks

```typescript
// hooks/use-api.ts - Generic API hook
interface UseApiOptions<T> {
  enabled?: boolean;
  refetchInterval?: number;
  onSuccess?: (data: T) => void;
  onError?: (error: ApiError) => void;
}

export function useApi<T>(
  url: string | null, 
  options: UseApiOptions<T> = {}
) {
  const { enabled = true, refetchInterval, onSuccess, onError } = options;
  
  return useQuery({
    queryKey: [url],
    queryFn: async () => {
      if (!url) throw new Error('URL is required');
      
      const response = await fetch(url);
      if (!response.ok) {
        const error: ApiError = await response.json();
        throw error;
      }
      
      return response.json() as Promise<T>;
    },
    enabled: enabled && !!url,
    refetchInterval,
    onSuccess,
    onError,
  });
}

// Specialized hooks
export function useUser(id: string) {
  return useApi<User>(`/api/users/${id}`, {
    enabled: !!id,
    onSuccess: (user) => {
      // Update global user state if needed
      console.log('User loaded:', user.name);
    },
  });
}

export function useProjects(filters?: ProjectFilters) {
  const params = filters ? `?${new URLSearchParams(filters).toString()}` : '';
  
  return useApi<PaginatedResponse<Project>>(`/api/projects${params}`, {
    refetchInterval: 30000, // Refetch every 30 seconds
  });
}
```

### Business Logic Hooks

```typescript
// hooks/use-shopping-cart.ts - Business logic hook
interface CartItem {
  id: string;
  productId: string;
  name: string;
  price: number;
  quantity: number;
  image?: string;
}

export function useShoppingCart() {
  const [items, setItems] = useState<CartItem[]>([]);
  
  // Load cart from localStorage on mount
  useEffect(() => {
    const savedCart = localStorage.getItem('shopping-cart');
    if (savedCart) {
      try {
        setItems(JSON.parse(savedCart));
      } catch (error) {
        console.error('Failed to parse saved cart:', error);
      }
    }
  }, []);
  
  // Save cart to localStorage when items change
  useEffect(() => {
    localStorage.setItem('shopping-cart', JSON.stringify(items));
  }, [items]);
  
  const addItem = useCallback((product: Omit<CartItem, 'id' | 'quantity'>) => {
    setItems(current => {
      const existingItem = current.find(item => item.productId === product.productId);
      
      if (existingItem) {
        return current.map(item =>
          item.productId === product.productId
            ? { ...item, quantity: item.quantity + 1 }
            : item
        );
      }
      
      return [...current, { ...product, id: crypto.randomUUID(), quantity: 1 }];
    });
  }, []);
  
  const removeItem = useCallback((itemId: string) => {
    setItems(current => current.filter(item => item.id !== itemId));
  }, []);
  
  const updateQuantity = useCallback((itemId: string, quantity: number) => {
    if (quantity <= 0) {
      removeItem(itemId);
      return;
    }
    
    setItems(current =>
      current.map(item =>
        item.id === itemId ? { ...item, quantity } : item
      )
    );
  }, [removeItem]);
  
  const clearCart = useCallback(() => {
    setItems([]);
  }, []);
  
  // Computed values
  const totalItems = useMemo(() => 
    items.reduce((sum, item) => sum + item.quantity, 0), 
    [items]
  );
  
  const totalPrice = useMemo(() => 
    items.reduce((sum, item) => sum + (item.price * item.quantity), 0), 
    [items]
  );
  
  const isEmpty = items.length === 0;
  
  return {
    items,
    addItem,
    removeItem,
    updateQuantity,
    clearCart,
    totalItems,
    totalPrice,
    isEmpty,
  };
}
```

### Form Handling Hooks

```typescript
// hooks/use-form-with-validation.ts - Advanced form handling
interface UseFormWithValidationProps<T> {
  initialValues: T;
  validationSchema: z.ZodSchema<T>;
  onSubmit: (values: T) => Promise<void> | void;
}

export function useFormWithValidation<T extends Record<string, any>>({
  initialValues,
  validationSchema,
  onSubmit,
}: UseFormWithValidationProps<T>) {
  const [values, setValues] = useState<T>(initialValues);
  const [errors, setErrors] = useState<Partial<Record<keyof T, string>>>({});
  const [touched, setTouched] = useState<Partial<Record<keyof T, boolean>>>({});
  const [isSubmitting, setIsSubmitting] = useState(false);
  
  const validateField = useCallback((name: keyof T, value: any) => {
    try {
      // Validate single field
      const fieldSchema = validationSchema.shape[name as string];
      if (fieldSchema) {
        fieldSchema.parse(value);
        setErrors(current => ({ ...current, [name]: undefined }));
      }
    } catch (error) {
      if (error instanceof z.ZodError) {
        setErrors(current => ({ 
          ...current, 
          [name]: error.errors[0]?.message || 'Invalid value' 
        }));
      }
    }
  }, [validationSchema]);
  
  const setValue = useCallback((name: keyof T, value: any) => {
    setValues(current => ({ ...current, [name]: value }));
    
    // Validate if field has been touched
    if (touched[name]) {
      validateField(name, value);
    }
  }, [touched, validateField]);
  
  const setFieldTouched = useCallback((name: keyof T) => {
    setTouched(current => ({ ...current, [name]: true }));
    validateField(name, values[name]);
  }, [values, validateField]);
  
  const validateForm = useCallback(() => {
    try {
      validationSchema.parse(values);
      setErrors({});
      return true;
    } catch (error) {
      if (error instanceof z.ZodError) {
        const formErrors: Partial<Record<keyof T, string>> = {};
        error.errors.forEach(err => {
          if (err.path[0]) {
            formErrors[err.path[0] as keyof T] = err.message;
          }
        });
        setErrors(formErrors);
      }
      return false;
    }
  }, [values, validationSchema]);
  
  const handleSubmit = useCallback(async (e?: React.FormEvent) => {
    e?.preventDefault();
    
    if (!validateForm()) return;
    
    setIsSubmitting(true);
    try {
      await onSubmit(values);
    } catch (error) {
      console.error('Form submission error:', error);
    } finally {
      setIsSubmitting(false);
    }
  }, [values, validateForm, onSubmit]);
  
  const reset = useCallback(() => {
    setValues(initialValues);
    setErrors({});
    setTouched({});
    setIsSubmitting(false);
  }, [initialValues]);
  
  const hasErrors = Object.values(errors).some(error => !!error);
  const isValid = !hasErrors && Object.keys(touched).length > 0;
  
  return {
    values,
    errors,
    touched,
    isSubmitting,
    isValid,
    hasErrors,
    setValue,
    setFieldTouched,
    handleSubmit,
    reset,
    validateForm,
  };
}
```

## 🧪 Testing Best Practices

### Component Testing Patterns

```typescript
// __tests__/components/UserProfile.test.tsx
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { UserProfile } from '../UserProfile';

// Test utilities
function createTestQueryClient() {
  return new QueryClient({
    defaultOptions: {
      queries: {
        retry: false,
        staleTime: Infinity,
      },
    },
  });
}

function renderWithProviders(ui: React.ReactElement) {
  const queryClient = createTestQueryClient();
  
  return render(
    <QueryClientProvider client={queryClient}>
      {ui}
    </QueryClientProvider>
  );
}

// Mock data
const mockUser = {
  id: '1',
  name: 'John Doe',
  email: 'john@example.com',
  avatar: 'https://example.com/avatar.jpg',
};

// Mock API
beforeEach(() => {
  global.fetch = jest.fn();
});

afterEach(() => {
  jest.resetAllMocks();
});

describe('UserProfile', () => {
  it('displays user information correctly', async () => {
    (global.fetch as jest.Mock).mockResolvedValueOnce({
      ok: true,
      json: async () => mockUser,
    });
    
    renderWithProviders(<UserProfile userId="1" />);
    
    // Check loading state
    expect(screen.getByText('Loading...')).toBeInTheDocument();
    
    // Wait for data to load
    await waitFor(() => {
      expect(screen.getByText('John Doe')).toBeInTheDocument();
    });
    
    expect(screen.getByText('john@example.com')).toBeInTheDocument();
    expect(screen.getByRole('img', { name: /john doe/i })).toHaveAttribute(
      'src',
      'https://example.com/avatar.jpg'
    );
  });
  
  it('handles edit mode correctly', async () => {
    (global.fetch as jest.Mock).mockResolvedValueOnce({
      ok: true,
      json: async () => mockUser,
    });
    
    const user = userEvent.setup();
    renderWithProviders(<UserProfile userId="1" />);
    
    // Wait for data to load
    await waitFor(() => {
      expect(screen.getByText('John Doe')).toBeInTheDocument();
    });
    
    // Enter edit mode
    await user.click(screen.getByRole('button', { name: /edit profile/i }));
    
    // Check edit form appears
    expect(screen.getByRole('textbox', { name: /name/i })).toHaveValue('John Doe');
    expect(screen.getByRole('textbox', { name: /email/i })).toHaveValue('john@example.com');
    
    // Update name
    await user.clear(screen.getByRole('textbox', { name: /name/i }));
    await user.type(screen.getByRole('textbox', { name: /name/i }), 'Jane Doe');
    
    // Mock update API call
    (global.fetch as jest.Mock).mockResolvedValueOnce({
      ok: true,
      json: async () => ({ ...mockUser, name: 'Jane Doe' }),
    });
    
    // Save changes
    await user.click(screen.getByRole('button', { name: /save/i }));
    
    // Verify API call
    expect(global.fetch).toHaveBeenCalledWith('/api/users/1', {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ name: 'Jane Doe' }),
    });
    
    // Check updated name appears
    await waitFor(() => {
      expect(screen.getByText('Jane Doe')).toBeInTheDocument();
    });
  });
  
  it('handles API errors gracefully', async () => {
    (global.fetch as jest.Mock).mockRejectedValueOnce(
      new Error('Failed to fetch user')
    );
    
    renderWithProviders(<UserProfile userId="1" />);
    
    await waitFor(() => {
      expect(screen.getByText(/error loading user/i)).toBeInTheDocument();
    });
    
    // Check retry button works
    const user = userEvent.setup();
    const retryButton = screen.getByRole('button', { name: /retry/i });
    
    (global.fetch as jest.Mock).mockResolvedValueOnce({
      ok: true,
      json: async () => mockUser,
    });
    
    await user.click(retryButton);
    
    await waitFor(() => {
      expect(screen.getByText('John Doe')).toBeInTheDocument();
    });
  });
});
```

### Custom Hook Testing

```typescript
// __tests__/hooks/useShoppingCart.test.ts
import { renderHook, act } from '@testing-library/react';
import { useShoppingCart } from '../useShoppingCart';

const mockProduct = {
  productId: '1',
  name: 'Test Product',
  price: 10.99,
  image: 'test-image.jpg',
};

// Mock localStorage
const localStorageMock = {
  getItem: jest.fn(),
  setItem: jest.fn(),
  removeItem: jest.fn(),
  clear: jest.fn(),
};
global.localStorage = localStorageMock as any;

describe('useShoppingCart', () => {
  beforeEach(() => {
    localStorageMock.getItem.mockReturnValue(null);
    localStorageMock.setItem.mockClear();
  });
  
  it('starts with empty cart', () => {
    const { result } = renderHook(() => useShoppingCart());
    
    expect(result.current.items).toEqual([]);
    expect(result.current.totalItems).toBe(0);
    expect(result.current.totalPrice).toBe(0);
    expect(result.current.isEmpty).toBe(true);
  });
  
  it('adds items to cart correctly', () => {
    const { result } = renderHook(() => useShoppingCart());
    
    act(() => {
      result.current.addItem(mockProduct);
    });
    
    expect(result.current.items).toHaveLength(1);
    expect(result.current.items[0]).toMatchObject({
      ...mockProduct,
      quantity: 1,
    });
    expect(result.current.totalItems).toBe(1);
    expect(result.current.totalPrice).toBe(10.99);
    expect(result.current.isEmpty).toBe(false);
  });
  
  it('increases quantity for existing items', () => {
    const { result } = renderHook(() => useShoppingCart());
    
    act(() => {
      result.current.addItem(mockProduct);
      result.current.addItem(mockProduct);
    });
    
    expect(result.current.items).toHaveLength(1);
    expect(result.current.items[0].quantity).toBe(2);
    expect(result.current.totalItems).toBe(2);
    expect(result.current.totalPrice).toBe(21.98);
  });
  
  it('saves to localStorage when items change', () => {
    const { result } = renderHook(() => useShoppingCart());
    
    act(() => {
      result.current.addItem(mockProduct);
    });
    
    expect(localStorageMock.setItem).toHaveBeenCalledWith(
      'shopping-cart',
      JSON.stringify(result.current.items)
    );
  });
  
  it('loads from localStorage on mount', () => {
    const savedCart = [{ ...mockProduct, id: 'test-id', quantity: 2 }];
    localStorageMock.getItem.mockReturnValue(JSON.stringify(savedCart));
    
    const { result } = renderHook(() => useShoppingCart());
    
    expect(result.current.items).toEqual(savedCart);
    expect(result.current.totalItems).toBe(2);
  });
});
```

## 🚀 Performance Optimization

### Code Splitting Strategies

```typescript
// Lazy loading with error boundaries
import { lazy, Suspense } from 'react';
import { ErrorBoundary } from 'react-error-boundary';

// Route-level splitting
const DashboardPage = lazy(() => import('../pages/Dashboard'));
const SettingsPage = lazy(() => import('../pages/Settings'));

// Component-level splitting for heavy components
const DataVisualization = lazy(() => import('../components/DataVisualization'));
const ReportGenerator = lazy(() => import('../components/ReportGenerator'));

// Feature-level splitting
const AdminPanel = lazy(() => import('../features/admin/AdminPanel'));

function App() {
  return (
    <Router>
      <Routes>
        <Route path="/dashboard" element={
          <ErrorBoundary fallback={<ErrorPage />}>
            <Suspense fallback={<PageSkeleton />}>
              <DashboardPage />
            </Suspense>
          </ErrorBoundary>
        } />
        <Route path="/settings" element={
          <ErrorBoundary fallback={<ErrorPage />}>
            <Suspense fallback={<PageSkeleton />}>
              <SettingsPage />
            </Suspense>
          </ErrorBoundary>
        } />
      </Routes>
    </Router>
  );
}
```

### Memoization Patterns

```typescript
// Proper use of React.memo
interface UserCardProps {
  user: User;
  onEdit: (userId: string) => void;
  onDelete: (userId: string) => void;
}

export const UserCard = React.memo(({ user, onEdit, onDelete }: UserCardProps) => {
  // Memoize handlers to prevent re-renders
  const handleEdit = useCallback(() => onEdit(user.id), [onEdit, user.id]);
  const handleDelete = useCallback(() => onDelete(user.id), [onDelete, user.id]);
  
  // Memoize expensive calculations
  const userDisplayName = useMemo(() => {
    return `${user.firstName} ${user.lastName}`.trim() || user.email;
  }, [user.firstName, user.lastName, user.email]);
  
  return (
    <div className="user-card">
      <h3>{userDisplayName}</h3>
      <p>{user.email}</p>
      <button onClick={handleEdit}>Edit</button>
      <button onClick={handleDelete}>Delete</button>
    </div>
  );
}, (prevProps, nextProps) => {
  // Custom comparison function
  return (
    prevProps.user.id === nextProps.user.id &&
    prevProps.user.firstName === nextProps.user.firstName &&
    prevProps.user.lastName === nextProps.user.lastName &&
    prevProps.user.email === nextProps.user.email &&
    prevProps.onEdit === nextProps.onEdit &&
    prevProps.onDelete === nextProps.onDelete
  );
});
```

### Virtual Scrolling for Large Lists

```typescript
// Virtual scrolling implementation
import { FixedSizeList as List } from 'react-window';

interface VirtualizedListProps {
  items: any[];
  height: number;
  itemHeight: number;
  renderItem: (props: { index: number; style: React.CSSProperties }) => React.ReactNode;
}

export function VirtualizedList({ items, height, itemHeight, renderItem }: VirtualizedListProps) {
  const Row = ({ index, style }: { index: number; style: React.CSSProperties }) => (
    <div style={style}>
      {renderItem({ index, style })}
    </div>
  );
  
  return (
    <List
      height={height}
      itemCount={items.length}
      itemSize={itemHeight}
      overscanCount={5} // Render 5 extra items for smooth scrolling
    >
      {Row}
    </List>
  );
}

// Usage
function UserList({ users }: { users: User[] }) {
  const renderUser = ({ index }: { index: number; style: React.CSSProperties }) => (
    <UserCard user={users[index]} onEdit={handleEdit} onDelete={handleDelete} />
  );
  
  return (
    <VirtualizedList
      items={users}
      height={400}
      itemHeight={80}
      renderItem={renderUser}
    />
  );
}
```

## 🔐 Security Best Practices

### Input Validation and Sanitization

```typescript
// Input sanitization hooks
import DOMPurify from 'dompurify';

export function useSafeHTML(html: string) {
  return useMemo(() => {
    return DOMPurify.sanitize(html, {
      ALLOWED_TAGS: ['p', 'br', 'strong', 'em', 'u', 'ol', 'ul', 'li'],
      ALLOWED_ATTR: [],
    });
  }, [html]);
}

// Form validation with security in mind
const userSchema = z.object({
  email: z.string()
    .email('Invalid email format')
    .max(254, 'Email too long')
    .transform(email => email.toLowerCase().trim()),
  
  password: z.string()
    .min(8, 'Password must be at least 8 characters')
    .max(128, 'Password too long')
    .regex(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]/, 
      'Password must contain uppercase, lowercase, number, and special character'),
  
  name: z.string()
    .min(1, 'Name is required')
    .max(100, 'Name too long')
    .regex(/^[a-zA-Z\s'-]+$/, 'Name contains invalid characters')
    .transform(name => name.trim()),
});
```

### CSRF Protection

```typescript
// CSRF token handling
export function useCSRFToken() {
  const [token, setToken] = useState<string>('');
  
  useEffect(() => {
    // Get CSRF token on mount
    fetch('/api/csrf-token')
      .then(res => res.json())
      .then(data => setToken(data.token))
      .catch(console.error);
  }, []);
  
  const fetchWithCSRF = useCallback(async (url: string, options: RequestInit = {}) => {
    return fetch(url, {
      ...options,
      headers: {
        ...options.headers,
        'X-CSRF-Token': token,
      },
    });
  }, [token]);
  
  return { token, fetchWithCSRF };
}
```

### Content Security Policy Headers

```typescript
// middleware.ts - Next.js middleware for security headers
import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';

export function middleware(request: NextRequest) {
  const response = NextResponse.next();
  
  // Content Security Policy
  response.headers.set(
    'Content-Security-Policy',
    [
      "default-src 'self'",
      "script-src 'self' 'unsafe-inline' 'unsafe-eval'",
      "style-src 'self' 'unsafe-inline'",
      "img-src 'self' data: https:",
      "font-src 'self'",
      "connect-src 'self'",
      "frame-ancestors 'none'",
    ].join('; ')
  );
  
  // Other security headers
  response.headers.set('X-Frame-Options', 'DENY');
  response.headers.set('X-Content-Type-Options', 'nosniff');
  response.headers.set('Referrer-Policy', 'strict-origin-when-cross-origin');
  response.headers.set('Permissions-Policy', 'camera=(), microphone=(), geolocation=()');
  
  return response;
}

export const config = {
  matcher: [
    '/((?!api|_next/static|_next/image|favicon.ico).*)',
  ],
};
```

## 📊 Monitoring and Analytics

### Error Tracking

```typescript
// utils/error-tracking.ts
import * as Sentry from '@sentry/nextjs';

export function initErrorTracking() {
  Sentry.init({
    dsn: process.env.NEXT_PUBLIC_SENTRY_DSN,
    environment: process.env.NODE_ENV,
    beforeSend(event, hint) {
      // Don't send errors in development
      if (process.env.NODE_ENV === 'development') {
        console.error('Error caught by Sentry:', hint.originalException || event);
        return null;
      }
      return event;
    },
  });
}

// Error boundary with logging
export class ErrorBoundary extends React.Component<
  { children: React.ReactNode; fallback: React.ComponentType<{ error: Error }> },
  { hasError: boolean; error: Error | null }
> {
  constructor(props: any) {
    super(props);
    this.state = { hasError: false, error: null };
  }
  
  static getDerivedStateFromError(error: Error) {
    return { hasError: true, error };
  }
  
  componentDidCatch(error: Error, errorInfo: React.ErrorInfo) {
    console.error('Error boundary caught error:', error, errorInfo);
    
    // Send to error tracking service
    Sentry.captureException(error, {
      contexts: {
        react: {
          componentStack: errorInfo.componentStack,
        },
      },
    });
  }
  
  render() {
    if (this.state.hasError && this.state.error) {
      return <this.props.fallback error={this.state.error} />;
    }
    
    return this.props.children;
  }
}
```

### Performance Monitoring

```typescript
// hooks/use-performance.ts
export function usePerformanceMonitoring() {
  useEffect(() => {
    // Web Vitals monitoring
    import('web-vitals').then(({ getCLS, getFID, getFCP, getLCP, getTTFB }) => {
      getCLS(metric => console.log('CLS:', metric));
      getFID(metric => console.log('FID:', metric));
      getFCP(metric => console.log('FCP:', metric));
      getLCP(metric => console.log('LCP:', metric));
      getTTFB(metric => console.log('TTFB:', metric));
    });
  }, []);
  
  const trackEvent = useCallback((eventName: string, properties?: Record<string, any>) => {
    // Send to analytics service
    if (typeof window !== 'undefined' && window.gtag) {
      window.gtag('event', eventName, properties);
    }
  }, []);
  
  return { trackEvent };
}
```

---

## 🔗 Navigation

**Previous:** [Implementation Guide](./implementation-guide.md) | **Next:** [State Management Patterns](./state-management-patterns.md)