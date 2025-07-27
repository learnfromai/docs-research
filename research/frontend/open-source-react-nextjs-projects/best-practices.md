# Best Practices: React/Next.js Development

## 🎯 Overview

This document consolidates best practices extracted from analyzing 15+ production-ready open source React and Next.js applications. These practices are proven in real-world applications serving millions of users and represent the current industry standards for building scalable, maintainable, and performant frontend applications.

## 🏗️ Project Architecture

### 1. Feature-Based Folder Structure

**Best Practice**: Organize code by features rather than technical layers.

```
src/
├── components/           # Shared/reusable components
│   ├── ui/              # Basic UI components (Button, Input, etc.)
│   ├── layout/          # Layout components (Header, Sidebar, etc.)
│   └── forms/           # Form-specific components
├── features/            # Feature-specific modules
│   ├── auth/           
│   │   ├── components/  # Auth-specific components
│   │   ├── hooks/       # Auth-specific hooks
│   │   ├── api/         # Auth API calls
│   │   └── types/       # Auth type definitions
│   ├── dashboard/       
│   └── profile/         
├── hooks/               # Global custom hooks
├── lib/                 # Utility libraries and configurations
├── stores/              # State management
├── types/               # Global type definitions
└── constants/           # Application constants
```

**Why This Works**:
- ✅ Easier to locate related code
- ✅ Better code organization for teams
- ✅ Clearer dependencies between features
- ✅ Easier to delete unused features

### 2. Consistent Import Organization

```typescript
// 1. React and Next.js imports
import React from 'react';
import { NextPage } from 'next';
import Link from 'next/link';

// 2. Third-party library imports
import { useQuery } from '@tanstack/react-query';
import { Button } from '@/components/ui/button';

// 3. Internal imports (absolute paths)
import { useAuth } from '@/hooks/use-auth';
import { apiClient } from '@/lib/api';

// 4. Relative imports
import './component.styles.css';

// 5. Type imports (last)
import type { User } from '@/types';
```

## 🧠 State Management

### 1. Choose the Right Tool for the Job

**Client State**: Use Zustand for complex client state, React Context for simple state.

```typescript
// ✅ Good: Simple state with Context
const ThemeContext = createContext<{
  theme: 'light' | 'dark';
  toggleTheme: () => void;
}>({
  theme: 'light',
  toggleTheme: () => {},
});

// ✅ Good: Complex state with Zustand
interface AppState {
  user: User | null;
  sidebar: { isOpen: boolean; activeTab: string };
  notifications: Notification[];
  // ... multiple related state pieces
}
```

**Server State**: Always use React Query (TanStack Query) for server state management.

```typescript
// ✅ Excellent: Proper server state management
export function useUsers(filters: UserFilters) {
  return useQuery({
    queryKey: ['users', filters],
    queryFn: () => fetchUsers(filters),
    staleTime: 5 * 60 * 1000, // 5 minutes
    retry: (failureCount, error) => {
      if (error.status === 404) return false;
      return failureCount < 3;
    },
  });
}
```

### 2. State Management Patterns

**Zustand Best Practices**:

```typescript
// ✅ Use slices for large stores
const createUserSlice = (set: any, get: any) => ({
  user: null,
  setUser: (user: User) => set({ user }),
  updateUser: (updates: Partial<User>) => 
    set((state: any) => ({ 
      user: state.user ? { ...state.user, ...updates } : null 
    })),
});

const createUISlice = (set: any) => ({
  sidebarOpen: false,
  setSidebarOpen: (open: boolean) => set({ sidebarOpen: open }),
});

// Combine slices
export const useAppStore = create()((...a) => ({
  ...createUserSlice(...a),
  ...createUISlice(...a),
}));

// ✅ Use selectors for performance
export const useUser = () => useAppStore(state => state.user);
export const useSidebarOpen = () => useAppStore(state => state.sidebarOpen);
```

**React Query Patterns**:

```typescript
// ✅ Custom hooks for API calls
export function useCreateUser() {
  const queryClient = useQueryClient();
  
  return useMutation({
    mutationFn: createUser,
    onSuccess: (newUser) => {
      // Update cache
      queryClient.setQueryData(['user', newUser.id], newUser);
      
      // Invalidate lists
      queryClient.invalidateQueries({ queryKey: ['users'] });
      
      // Show success notification
      toast.success('User created successfully');
    },
    onError: (error) => {
      toast.error(error.message);
    },
  });
}
```

## 🔐 Authentication & Security

### 1. Authentication Implementation

**Use NextAuth.js for most applications**:

```typescript
// ✅ Comprehensive auth configuration
export const authOptions: NextAuthOptions = {
  providers: [
    GoogleProvider({
      clientId: process.env.GOOGLE_CLIENT_ID!,
      clientSecret: process.env.GOOGLE_CLIENT_SECRET!,
    }),
    CredentialsProvider({
      // ... credential validation
    }),
  ],
  session: { strategy: "jwt" },
  callbacks: {
    async jwt({ token, user, account }) {
      if (user) {
        token.role = user.role;
        token.permissions = user.permissions;
      }
      return token;
    },
    async session({ session, token }) {
      session.user.role = token.role;
      session.user.permissions = token.permissions;
      return session;
    },
  },
  pages: {
    signIn: '/auth/signin',
    error: '/auth/error',
  },
};
```

### 2. Security Best Practices

**Token Storage**:

```typescript
// ✅ HTTP-only cookies (NextAuth.js default)
// ❌ Never store sensitive tokens in localStorage
localStorage.setItem('token', token); // DON'T DO THIS

// ✅ Use secure, HTTP-only cookies
// NextAuth.js handles this automatically
```

**Route Protection**:

```typescript
// ✅ Middleware-based protection
// middleware.ts
export function middleware(request: NextRequest) {
  const token = request.nextUrl.pathname.startsWith('/dashboard')
    ? getToken({ req: request })
    : null;

  if (!token && request.nextUrl.pathname.startsWith('/dashboard')) {
    return NextResponse.redirect(new URL('/auth/signin', request.url));
  }
}

export const config = {
  matcher: ['/dashboard/:path*', '/admin/:path*'],
};
```

**Role-Based Access Control**:

```typescript
// ✅ Reusable permission hook
export function usePermissions() {
  const { data: session } = useSession();
  
  const hasPermission = useCallback((permission: string) => {
    return session?.user?.permissions?.includes(permission) ?? false;
  }, [session]);

  const hasRole = useCallback((role: string) => {
    return session?.user?.role === role;
  }, [session]);

  return { hasPermission, hasRole };
}

// Usage in components
function AdminPanel() {
  const { hasRole } = usePermissions();
  
  if (!hasRole('admin')) {
    return <AccessDenied />;
  }
  
  return <AdminContent />;
}
```

## 🎨 Component Design

### 1. Component Patterns

**Compound Components**:

```typescript
// ✅ Flexible, reusable component API
interface DropdownProps {
  children: React.ReactNode;
}

export function Dropdown({ children }: DropdownProps) {
  const [isOpen, setIsOpen] = useState(false);
  
  return (
    <DropdownContext.Provider value={{ isOpen, setIsOpen }}>
      <div className="relative">{children}</div>
    </DropdownContext.Provider>
  );
}

Dropdown.Trigger = function DropdownTrigger({ children }: { children: React.ReactNode }) {
  const { isOpen, setIsOpen } = useDropdownContext();
  return (
    <button onClick={() => setIsOpen(!isOpen)}>
      {children}
    </button>
  );
};

Dropdown.Content = function DropdownContent({ children }: { children: React.ReactNode }) {
  const { isOpen } = useDropdownContext();
  return isOpen ? <div className="dropdown-content">{children}</div> : null;
};

// Usage
<Dropdown>
  <Dropdown.Trigger>
    <Button>Options</Button>
  </Dropdown.Trigger>
  <Dropdown.Content>
    <MenuItem>Edit</MenuItem>
    <MenuItem>Delete</MenuItem>
  </Dropdown.Content>
</Dropdown>
```

**Variant-Based Components with CVA**:

```typescript
// ✅ Type-safe variant system
import { cva, type VariantProps } from 'class-variance-authority';

const buttonVariants = cva(
  'inline-flex items-center justify-center rounded-md font-medium transition-colors',
  {
    variants: {
      variant: {
        default: 'bg-primary text-primary-foreground hover:bg-primary/90',
        destructive: 'bg-destructive text-destructive-foreground hover:bg-destructive/90',
        outline: 'border border-input hover:bg-accent hover:text-accent-foreground',
      },
      size: {
        default: 'h-10 px-4 py-2',
        sm: 'h-9 px-3',
        lg: 'h-11 px-8',
      },
    },
    defaultVariants: {
      variant: 'default',
      size: 'default',
    },
  }
);

interface ButtonProps 
  extends React.ButtonHTMLAttributes<HTMLButtonElement>,
    VariantProps<typeof buttonVariants> {}

export const Button = ({ className, variant, size, ...props }: ButtonProps) => {
  return (
    <button
      className={cn(buttonVariants({ variant, size, className }))}
      {...props}
    />
  );
};
```

### 2. Performance Optimization

**React.memo and useMemo**:

```typescript
// ✅ Memo for expensive components
export const ExpensiveComponent = React.memo(function ExpensiveComponent({
  data,
  onUpdate,
}: {
  data: ComplexData;
  onUpdate: (id: string) => void;
}) {
  const processedData = useMemo(() => {
    return expensiveDataProcessing(data);
  }, [data]);

  const handleUpdate = useCallback((id: string) => {
    onUpdate(id);
  }, [onUpdate]);

  return <ComplexVisualization data={processedData} onUpdate={handleUpdate} />;
});
```

**Lazy Loading**:

```typescript
// ✅ Lazy load heavy components
const AdminPanel = lazy(() => import('./AdminPanel'));
const ReportsModule = lazy(() => import('./ReportsModule'));

function Dashboard() {
  const { hasRole } = usePermissions();
  
  return (
    <div>
      <Header />
      <Suspense fallback={<Loading />}>
        {hasRole('admin') && <AdminPanel />}
        {hasRole('manager') && <ReportsModule />}
      </Suspense>
    </div>
  );
}
```

## 🌐 API Integration

### 1. Error Handling

**Consistent Error Handling**:

```typescript
// ✅ Centralized error handling
class ApiError extends Error {
  constructor(
    message: string,
    public status: number,
    public code?: string
  ) {
    super(message);
    this.name = 'ApiError';
  }
}

export async function apiRequest<T>(
  url: string,
  options: RequestInit = {}
): Promise<T> {
  try {
    const response = await fetch(url, {
      headers: {
        'Content-Type': 'application/json',
        ...options.headers,
      },
      ...options,
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new ApiError(
        errorData.message || `HTTP ${response.status}`,
        response.status,
        errorData.code
      );
    }

    return response.json();
  } catch (error) {
    if (error instanceof ApiError) throw error;
    throw new ApiError('Network error', 0);
  }
}
```

**React Query Error Handling**:

```typescript
// ✅ Global error handling with React Query
export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      retry: (failureCount, error) => {
        if (error instanceof ApiError && error.status === 404) {
          return false; // Don't retry 404s
        }
        return failureCount < 3;
      },
      throwOnError: (error) => {
        // Global error handling
        if (error instanceof ApiError && error.status === 401) {
          // Redirect to login
          window.location.href = '/auth/signin';
          return false;
        }
        return true;
      },
    },
  },
});
```

### 2. Data Fetching Patterns

**Optimistic Updates**:

```typescript
// ✅ Optimistic updates for better UX
export function useUpdateUser() {
  const queryClient = useQueryClient();
  
  return useMutation({
    mutationFn: updateUser,
    onMutate: async (newUserData) => {
      // Cancel outgoing refetches
      await queryClient.cancelQueries({ queryKey: ['user', newUserData.id] });
      
      // Snapshot the previous value
      const previousUser = queryClient.getQueryData(['user', newUserData.id]);
      
      // Optimistically update
      queryClient.setQueryData(['user', newUserData.id], {
        ...previousUser,
        ...newUserData,
      });
      
      return { previousUser };
    },
    onError: (err, newUserData, context) => {
      // Rollback on error
      queryClient.setQueryData(
        ['user', newUserData.id],
        context?.previousUser
      );
    },
    onSettled: (data, error, variables) => {
      // Always refetch
      queryClient.invalidateQueries({ queryKey: ['user', variables.id] });
    },
  });
}
```

## 🚀 Performance

### 1. Bundle Optimization

**Dynamic Imports**:

```typescript
// ✅ Route-based code splitting
const DashboardPage = dynamic(() => import('./Dashboard'), {
  loading: () => <PageSkeleton />,
});

// ✅ Component-based splitting
const ChartComponent = dynamic(() => import('./Chart'), {
  ssr: false, // Don't render on server if not needed
  loading: () => <ChartSkeleton />,
});
```

**Tree Shaking**:

```typescript
// ✅ Import only what you need
import { debounce } from 'lodash-es/debounce';
// ❌ Don't import entire library
import _ from 'lodash';

// ✅ Use barrel exports carefully
export { Button } from './Button';
export { Input } from './Input';
// Only export what's actually used
```

### 2. Image Optimization

```typescript
// ✅ Next.js Image component
import Image from 'next/image';

function ProfileImage({ user }: { user: User }) {
  return (
    <Image
      src={user.avatar || '/default-avatar.png'}
      alt={`${user.name}'s avatar`}
      width={40}
      height={40}
      className="rounded-full"
      placeholder="blur"
      blurDataURL="data:image/jpeg;base64,..."
    />
  );
}
```

## 🧪 Testing

### 1. Testing Strategies

**Component Testing**:

```typescript
// ✅ Comprehensive component tests
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { UserProfile } from './UserProfile';

const renderWithProviders = (ui: React.ReactElement) => {
  const queryClient = new QueryClient({
    defaultOptions: { queries: { retry: false } },
  });
  
  return render(
    <QueryClientProvider client={queryClient}>
      {ui}
    </QueryClientProvider>
  );
};

describe('UserProfile', () => {
  it('displays user information correctly', async () => {
    const mockUser = { id: '1', name: 'John Doe', email: 'john@example.com' };
    
    renderWithProviders(<UserProfile userId="1" />);
    
    await waitFor(() => {
      expect(screen.getByText('John Doe')).toBeInTheDocument();
      expect(screen.getByText('john@example.com')).toBeInTheDocument();
    });
  });

  it('handles edit mode correctly', async () => {
    renderWithProviders(<UserProfile userId="1" />);
    
    fireEvent.click(screen.getByRole('button', { name: /edit/i }));
    
    expect(screen.getByRole('textbox', { name: /name/i })).toBeInTheDocument();
  });
});
```

**Custom Hook Testing**:

```typescript
// ✅ Test custom hooks
import { renderHook, act } from '@testing-library/react';
import { useCounter } from './useCounter';

describe('useCounter', () => {
  it('increments counter', () => {
    const { result } = renderHook(() => useCounter(0));
    
    act(() => {
      result.current.increment();
    });
    
    expect(result.current.count).toBe(1);
  });
});
```

## 📝 Type Safety

### 1. TypeScript Best Practices

**Strict Configuration**:

```json
// tsconfig.json
{
  "compilerOptions": {
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "exactOptionalPropertyTypes": true,
    "noImplicitReturns": true,
    "noFallthroughCasesInSwitch": true
  }
}
```

**API Type Safety**:

```typescript
// ✅ Generate types from API schema
interface ApiResponse<T> {
  data: T;
  success: boolean;
  message?: string;
}

interface User {
  id: string;
  name: string;
  email: string;
  role: 'user' | 'admin' | 'moderator';
  createdAt: string;
  updatedAt: string;
}

// ✅ Type-safe API functions
export async function getUser(id: string): Promise<ApiResponse<User>> {
  const response = await apiRequest<ApiResponse<User>>(`/users/${id}`);
  return response;
}
```

## 🔧 Development Workflow

### 1. Code Quality Tools

**ESLint Configuration**:

```json
// .eslintrc.json
{
  "extends": [
    "next/core-web-vitals",
    "@typescript-eslint/recommended",
    "prettier"
  ],
  "rules": {
    "prefer-const": "error",
    "no-unused-vars": "off",
    "@typescript-eslint/no-unused-vars": "error",
    "@typescript-eslint/no-explicit-any": "warn"
  }
}
```

**Pre-commit Hooks**:

```json
// package.json
{
  "lint-staged": {
    "*.{ts,tsx}": ["eslint --fix", "prettier --write"],
    "*.{md,json}": ["prettier --write"]
  }
}
```

## 📚 Documentation

### 1. Component Documentation

```typescript
/**
 * Button component with multiple variants and sizes
 * 
 * @example
 * ```tsx
 * <Button variant="primary" size="lg" onClick={handleClick}>
 *   Click me
 * </Button>
 * ```
 */
interface ButtonProps {
  /** Button variant styling */
  variant?: 'primary' | 'secondary' | 'destructive';
  /** Button size */
  size?: 'sm' | 'md' | 'lg';
  /** Click handler */
  onClick?: () => void;
  /** Button content */
  children: React.ReactNode;
}
```

## ✅ Checklist for Production-Ready Applications

### Architecture
- [ ] Feature-based folder structure
- [ ] Consistent import organization
- [ ] Proper separation of concerns
- [ ] Reusable component library

### State Management
- [ ] Appropriate state management tools (Zustand + React Query)
- [ ] Optimistic updates for mutations
- [ ] Proper error handling and loading states
- [ ] Performance optimizations with selectors

### Security
- [ ] Secure authentication implementation
- [ ] HTTP-only cookie token storage
- [ ] Route protection middleware
- [ ] Role-based access control

### Performance
- [ ] Code splitting and lazy loading
- [ ] Image optimization
- [ ] Bundle size monitoring
- [ ] Caching strategies

### Testing
- [ ] Component unit tests
- [ ] Custom hook tests
- [ ] Integration tests for critical flows
- [ ] E2E tests for user journeys

### Developer Experience
- [ ] TypeScript strict mode
- [ ] ESLint and Prettier configuration
- [ ] Pre-commit hooks
- [ ] Comprehensive documentation

These best practices represent the collective wisdom of the React/Next.js community and have been proven in production environments. Implementing them will result in more maintainable, performant, and scalable applications.