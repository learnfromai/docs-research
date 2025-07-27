# Best Practices - React/Next.js Development

## 🎯 Overview

Consolidated best practices and recommendations derived from analyzing production-ready open source React/Next.js projects. These practices have been proven effective across multiple high-quality applications.

## 🏗️ Architecture Best Practices

### **1. Folder Structure Principles**

```
✅ Good: Feature-based organization for large apps
src/
├── features/
│   ├── auth/
│   │   ├── components/
│   │   ├── hooks/
│   │   ├── api/
│   │   └── types/
│   └── dashboard/
│       ├── components/
│       ├── hooks/
│       └── api/
└── shared/
    ├── components/
    ├── hooks/
    └── utils/

❌ Avoid: Type-based organization for large apps
src/
├── components/
├── hooks/
├── utils/
└── types/
```

### **2. Component Design Principles**

```typescript
// ✅ Good: Single Responsibility Principle
interface UserCardProps {
  user: User;
  onEdit?: (user: User) => void;
}

export const UserCard: React.FC<UserCardProps> = ({ user, onEdit }) => {
  return (
    <Card>
      <CardHeader>
        <UserAvatar user={user} />
        <UserInfo user={user} />
      </CardHeader>
      {onEdit && (
        <CardFooter>
          <Button onClick={() => onEdit(user)}>Edit</Button>
        </CardFooter>
      )}
    </Card>
  );
};

// ❌ Avoid: Components that do too much
export const UserManagement: React.FC = () => {
  // Contains user list, user form, user details, API calls, etc.
  // This should be split into multiple components
};
```

### **3. Custom Hooks for Logic Separation**

```typescript
// ✅ Good: Extract complex logic to custom hooks
export const useUserManagement = () => {
  const [selectedUser, setSelectedUser] = useState<User | null>(null);
  const { data: users, isLoading } = useUsers();
  const createMutation = useCreateUser();
  const updateMutation = useUpdateUser();
  const deleteMutation = useDeleteUser();

  const handleCreateUser = useCallback(async (userData: CreateUserData) => {
    try {
      await createMutation.mutateAsync(userData);
      toast.success('User created successfully');
    } catch (error) {
      toast.error('Failed to create user');
    }
  }, [createMutation]);

  const handleUpdateUser = useCallback(async (id: string, userData: UpdateUserData) => {
    try {
      await updateMutation.mutateAsync({ id, data: userData });
      toast.success('User updated successfully');
    } catch (error) {
      toast.error('Failed to update user');
    }
  }, [updateMutation]);

  return {
    users,
    isLoading,
    selectedUser,
    setSelectedUser,
    handleCreateUser,
    handleUpdateUser,
    isCreating: createMutation.isLoading,
    isUpdating: updateMutation.isLoading,
  };
};

// Component becomes much cleaner
export const UserManagementPage: React.FC = () => {
  const {
    users,
    isLoading,
    selectedUser,
    setSelectedUser,
    handleCreateUser,
    handleUpdateUser,
  } = useUserManagement();

  if (isLoading) return <LoadingSpinner />;

  return (
    <div>
      <UserList users={users} onSelectUser={setSelectedUser} />
      {selectedUser && (
        <UserDetails user={selectedUser} onUpdate={handleUpdateUser} />
      )}
    </div>
  );
};
```

## 📊 State Management Best Practices

### **1. State Management Selection Guide**

```typescript
// ✅ Good: Use the right tool for the right job

// Server state - Use React Query/SWR
const useUsers = () => {
  return useQuery({
    queryKey: ['users'],
    queryFn: fetchUsers,
    staleTime: 5 * 60 * 1000, // 5 minutes
  });
};

// Global client state - Use Zustand
interface AppStore {
  theme: 'light' | 'dark';
  sidebarOpen: boolean;
  toggleTheme: () => void;
  toggleSidebar: () => void;
}

const useAppStore = create<AppStore>((set) => ({
  theme: 'light',
  sidebarOpen: true,
  toggleTheme: () => set((state) => ({ 
    theme: state.theme === 'light' ? 'dark' : 'light' 
  })),
  toggleSidebar: () => set((state) => ({ 
    sidebarOpen: !state.sidebarOpen 
  })),
}));

// Local component state - Use useState
const SearchInput: React.FC = () => {
  const [query, setQuery] = useState('');
  const [isOpen, setIsOpen] = useState(false);
  
  return (
    <div>
      <input 
        value={query} 
        onChange={(e) => setQuery(e.target.value)}
        onFocus={() => setIsOpen(true)}
      />
      {isOpen && <SearchResults query={query} />}
    </div>
  );
};
```

### **2. Optimistic Updates Pattern**

```typescript
// ✅ Good: Optimistic updates with rollback
export const useUpdateUser = () => {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: ({ id, data }: { id: string; data: UpdateUserData }) =>
      userAPI.updateUser(id, data),
    
    onMutate: async ({ id, data }) => {
      // Cancel outgoing refetches
      await queryClient.cancelQueries({ queryKey: ['users', id] });

      // Snapshot previous value
      const previousUser = queryClient.getQueryData(['users', id]);

      // Optimistically update
      queryClient.setQueryData(['users', id], (old: User) => ({
        ...old,
        ...data,
        updatedAt: new Date().toISOString(),
      }));

      return { previousUser };
    },
    
    onError: (err, { id }, context) => {
      // Rollback on error
      queryClient.setQueryData(['users', id], context?.previousUser);
      toast.error('Update failed');
    },
    
    onSettled: (data, error, { id }) => {
      // Always refetch to ensure consistency
      queryClient.invalidateQueries({ queryKey: ['users', id] });
    },
  });
};
```

## 🎨 UI/UX Best Practices

### **1. Component Composition Patterns**

```typescript
// ✅ Good: Compound components for flexibility
export const Modal = {
  Root: ({ open, onClose, children }: ModalRootProps) => (
    <Dialog open={open} onOpenChange={onClose}>
      {children}
    </Dialog>
  ),
  
  Trigger: ({ children }: ModalTriggerProps) => (
    <DialogTrigger asChild>
      {children}
    </DialogTrigger>
  ),
  
  Content: ({ children, className }: ModalContentProps) => (
    <DialogContent className={cn('sm:max-w-md', className)}>
      {children}
    </DialogContent>
  ),
  
  Header: ({ title, description }: ModalHeaderProps) => (
    <DialogHeader>
      <DialogTitle>{title}</DialogTitle>
      {description && <DialogDescription>{description}</DialogDescription>}
    </DialogHeader>
  ),
  
  Footer: ({ children }: ModalFooterProps) => (
    <DialogFooter>
      {children}
    </DialogFooter>
  ),
};

// Usage
<Modal.Root open={isOpen} onClose={setIsOpen}>
  <Modal.Trigger>
    <Button>Open Modal</Button>
  </Modal.Trigger>
  <Modal.Content>
    <Modal.Header 
      title="Confirm Action" 
      description="This action cannot be undone." 
    />
    <Modal.Footer>
      <Button variant="outline" onClick={() => setIsOpen(false)}>
        Cancel
      </Button>
      <Button onClick={handleConfirm}>
        Confirm
      </Button>
    </Modal.Footer>
  </Modal.Content>
</Modal.Root>
```

### **2. Loading States and Error Handling**

```typescript
// ✅ Good: Comprehensive state handling
export const UserList: React.FC = () => {
  const { data: users, isLoading, error, refetch } = useUsers();

  if (isLoading) {
    return (
      <div className="space-y-4">
        {Array.from({ length: 5 }).map((_, i) => (
          <UserCardSkeleton key={i} />
        ))}
      </div>
    );
  }

  if (error) {
    return (
      <ErrorState
        title="Failed to load users"
        description="We couldn't fetch the user list. Please try again."
        action={
          <Button onClick={() => refetch()}>
            Try Again
          </Button>
        }
      />
    );
  }

  if (!users?.length) {
    return (
      <EmptyState
        title="No users found"
        description="Get started by creating your first user."
        action={
          <Button onClick={() => setShowCreateModal(true)}>
            Create User
          </Button>
        }
      />
    );
  }

  return (
    <div className="grid gap-4">
      {users.map((user) => (
        <UserCard key={user.id} user={user} />
      ))}
    </div>
  );
};

// ❌ Avoid: Poor state handling
export const BadUserList: React.FC = () => {
  const { data: users } = useUsers();
  
  return (
    <div>
      {users?.map((user) => (
        <UserCard key={user.id} user={user} />
      ))}
    </div>
  );
  // No loading, error, or empty states!
};
```

### **3. Form Validation Patterns**

```typescript
// ✅ Good: Comprehensive form validation with Zod
const userSchema = z.object({
  name: z.string()
    .min(2, 'Name must be at least 2 characters')
    .max(50, 'Name must be less than 50 characters'),
  email: z.string()
    .email('Invalid email address')
    .min(1, 'Email is required'),
  age: z.number()
    .min(18, 'Must be at least 18 years old')
    .max(120, 'Must be less than 120 years old'),
  role: z.enum(['USER', 'ADMIN'], {
    required_error: 'Please select a role',
  }),
}).refine((data) => {
  // Custom validation logic
  if (data.role === 'ADMIN' && data.age < 21) {
    return false;
  }
  return true;
}, {
  message: 'Admins must be at least 21 years old',
  path: ['age'],
});

export const UserForm: React.FC<UserFormProps> = ({ onSubmit }) => {
  const form = useForm<UserFormData>({
    resolver: zodResolver(userSchema),
    defaultValues: {
      name: '',
      email: '',
      age: 18,
      role: 'USER',
    },
  });

  return (
    <Form {...form}>
      <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-4">
        <FormField
          control={form.control}
          name="name"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Name</FormLabel>
              <FormControl>
                <Input {...field} placeholder="Enter name" />
              </FormControl>
              <FormMessage />
            </FormItem>
          )}
        />
        
        {/* More fields... */}
        
        <Button type="submit" disabled={form.formState.isSubmitting}>
          {form.formState.isSubmitting ? 'Creating...' : 'Create User'}
        </Button>
      </form>
    </Form>
  );
};
```

## 🔐 Security Best Practices

### **1. Input Validation and Sanitization**

```typescript
// ✅ Good: Validate all inputs
// Backend validation
const createUserSchema = z.object({
  name: z.string().trim().min(1).max(100),
  email: z.string().email().toLowerCase(),
  password: z.string().min(8).regex(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/),
});

export async function createUser(req: Request, res: Response) {
  try {
    const validatedData = createUserSchema.parse(req.body);
    
    // Additional security checks
    const existingUser = await User.findOne({ email: validatedData.email });
    if (existingUser) {
      return res.status(409).json({ error: 'User already exists' });
    }
    
    // Hash password
    const hashedPassword = await bcrypt.hash(validatedData.password, 12);
    
    const user = await User.create({
      ...validatedData,
      password: hashedPassword,
    });
    
    // Remove password from response
    const { password, ...userResponse } = user.toObject();
    res.status(201).json(userResponse);
  } catch (error) {
    if (error instanceof z.ZodError) {
      return res.status(400).json({ errors: error.errors });
    }
    res.status(500).json({ error: 'Internal server error' });
  }
}

// Frontend validation (same schema)
const UserForm: React.FC = () => {
  const form = useForm({
    resolver: zodResolver(createUserSchema),
  });
  
  // Form implementation...
};
```

### **2. Authentication Security**

```typescript
// ✅ Good: Secure token handling
class TokenService {
  private static readonly ACCESS_TOKEN_KEY = 'accessToken';
  private static readonly REFRESH_TOKEN_KEY = 'refreshToken';

  static setTokens(accessToken: string, refreshToken: string) {
    // Store access token in memory (most secure for SPA)
    sessionStorage.setItem(this.ACCESS_TOKEN_KEY, accessToken);
    
    // Store refresh token in httpOnly cookie (ideal but requires server-side)
    // Or secure localStorage with additional protection
    localStorage.setItem(this.REFRESH_TOKEN_KEY, refreshToken);
  }

  static getAccessToken(): string | null {
    return sessionStorage.getItem(this.ACCESS_TOKEN_KEY);
  }

  static clearTokens() {
    sessionStorage.removeItem(this.ACCESS_TOKEN_KEY);
    localStorage.removeItem(this.REFRESH_TOKEN_KEY);
  }
}

// API client with automatic token refresh
const apiClient = axios.create({
  baseURL: process.env.NEXT_PUBLIC_API_URL,
});

apiClient.interceptors.request.use((config) => {
  const token = TokenService.getAccessToken();
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

apiClient.interceptors.response.use(
  (response) => response,
  async (error) => {
    const originalRequest = error.config;
    
    if (error.response?.status === 401 && !originalRequest._retry) {
      originalRequest._retry = true;
      
      try {
        const refreshToken = localStorage.getItem('refreshToken');
        const response = await axios.post('/auth/refresh', { refreshToken });
        const { accessToken } = response.data;
        
        TokenService.setTokens(accessToken, refreshToken);
        originalRequest.headers.Authorization = `Bearer ${accessToken}`;
        
        return apiClient(originalRequest);
      } catch (refreshError) {
        // Refresh failed, redirect to login
        TokenService.clearTokens();
        window.location.href = '/auth/login';
        return Promise.reject(refreshError);
      }
    }
    
    return Promise.reject(error);
  }
);
```

## 🚀 Performance Best Practices

### **1. React Performance Optimization**

```typescript
// ✅ Good: Optimize re-renders with React.memo and useMemo
interface UserCardProps {
  user: User;
  onEdit: (user: User) => void;
}

export const UserCard = React.memo<UserCardProps>(({ user, onEdit }) => {
  const handleEdit = useCallback(() => {
    onEdit(user);
  }, [user, onEdit]);

  const userStatus = useMemo(() => {
    return calculateUserStatus(user);
  }, [user.lastActive, user.status]);

  return (
    <Card>
      <CardHeader>
        <h3>{user.name}</h3>
        <Badge variant={userStatus.variant}>{userStatus.label}</Badge>
      </CardHeader>
      <CardFooter>
        <Button onClick={handleEdit}>Edit</Button>
      </CardFooter>
    </Card>
  );
});

// ✅ Good: Virtualize large lists
import { FixedSizeList as List } from 'react-window';

const UserListItem = React.memo(({ index, style, data }) => (
  <div style={style}>
    <UserCard user={data[index]} onEdit={data.onEdit} />
  </div>
));

export const VirtualizedUserList: React.FC<{ users: User[] }> = ({ users }) => {
  const onEdit = useCallback((user: User) => {
    // Handle edit
  }, []);

  const itemData = useMemo(() => 
    users.map(user => ({ ...user, onEdit })), 
    [users, onEdit]
  );

  return (
    <List
      height={600}
      itemCount={users.length}
      itemSize={120}
      itemData={itemData}
    >
      {UserListItem}
    </List>
  );
};
```

### **2. Bundle Optimization**

```typescript
// ✅ Good: Code splitting and dynamic imports
// pages/admin/users.tsx
import dynamic from 'next/dynamic';
import { Suspense } from 'react';

// Lazy load admin components
const UserManagement = dynamic(() => import('@/components/admin/user-management'), {
  loading: () => <AdminPageSkeleton />,
  ssr: false, // Admin pages don't need SSR
});

const AdminAnalytics = dynamic(() => import('@/components/admin/analytics'), {
  loading: () => <AnalyticsSkeleton />,
});

export default function AdminUsersPage() {
  return (
    <AdminLayout>
      <Suspense fallback={<PageSkeleton />}>
        <UserManagement />
        <AdminAnalytics />
      </Suspense>
    </AdminLayout>
  );
}

// ✅ Good: Bundle analysis script in package.json
{
  "scripts": {
    "analyze": "cross-env ANALYZE=true next build",
    "bundle-analyzer": "npx @next/bundle-analyzer"
  }
}
```

## 🧪 Testing Best Practices

### **1. Testing Strategy**

```typescript
// ✅ Good: Test user behavior, not implementation
// user-form.test.tsx
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { UserForm } from '@/components/forms/user-form';

describe('UserForm', () => {
  it('creates a user when form is submitted with valid data', async () => {
    const user = userEvent.setup();
    const mockOnSubmit = jest.fn();
    
    render(<UserForm onSubmit={mockOnSubmit} />);
    
    // User interactions
    await user.type(screen.getByLabelText(/name/i), 'John Doe');
    await user.type(screen.getByLabelText(/email/i), 'john@example.com');
    await user.type(screen.getByLabelText(/password/i), 'SecurePass123!');
    await user.click(screen.getByRole('button', { name: /create/i }));
    
    // Assertions
    await waitFor(() => {
      expect(mockOnSubmit).toHaveBeenCalledWith({
        name: 'John Doe',
        email: 'john@example.com',
        password: 'SecurePass123!',
      });
    });
  });

  it('shows validation errors for invalid data', async () => {
    const user = userEvent.setup();
    
    render(<UserForm onSubmit={jest.fn()} />);
    
    // Submit without filling required fields
    await user.click(screen.getByRole('button', { name: /create/i }));
    
    // Check for validation errors
    expect(screen.getByText(/name is required/i)).toBeInTheDocument();
    expect(screen.getByText(/email is required/i)).toBeInTheDocument();
  });
});

// ✅ Good: Mock external dependencies
// api hooks test
jest.mock('@/lib/api/users');
const mockUserAPI = userAPI as jest.Mocked<typeof userAPI>;

describe('useUsers', () => {
  it('fetches and returns users', async () => {
    const mockUsers = [
      { id: '1', name: 'John', email: 'john@example.com' },
    ];
    
    mockUserAPI.getUsers.mockResolvedValue(mockUsers);
    
    const { result } = renderHook(() => useUsers(), {
      wrapper: createQueryWrapper(),
    });
    
    await waitFor(() => {
      expect(result.current.isSuccess).toBe(true);
    });
    
    expect(result.current.data).toEqual(mockUsers);
  });
});
```

### **2. Integration Testing**

```typescript
// ✅ Good: End-to-end user flows with Playwright
// e2e/user-management.spec.ts
import { test, expect } from '@playwright/test';

test.describe('User Management', () => {
  test.beforeEach(async ({ page }) => {
    // Login as admin
    await page.goto('/auth/login');
    await page.fill('[data-testid="email"]', 'admin@example.com');
    await page.fill('[data-testid="password"]', 'password');
    await page.click('[data-testid="login-button"]');
    
    // Navigate to user management
    await page.goto('/admin/users');
  });

  test('admin can create a new user', async ({ page }) => {
    // Open create user modal
    await page.click('[data-testid="create-user-button"]');
    
    // Fill form
    await page.fill('[data-testid="user-name"]', 'New User');
    await page.fill('[data-testid="user-email"]', 'newuser@example.com');
    await page.selectOption('[data-testid="user-role"]', 'USER');
    
    // Submit form
    await page.click('[data-testid="submit-button"]');
    
    // Verify user was created
    await expect(page.locator('[data-testid="success-message"]')).toBeVisible();
    await expect(page.locator('text=New User')).toBeVisible();
  });

  test('displays validation errors for invalid data', async ({ page }) => {
    await page.click('[data-testid="create-user-button"]');
    
    // Try to submit empty form
    await page.click('[data-testid="submit-button"]');
    
    // Check for validation errors
    await expect(page.locator('text=Name is required')).toBeVisible();
    await expect(page.locator('text=Email is required')).toBeVisible();
  });
});
```

## 📝 Code Quality Best Practices

### **1. TypeScript Best Practices**

```typescript
// ✅ Good: Strict TypeScript configuration
// tsconfig.json
{
  "compilerOptions": {
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "exactOptionalPropertyTypes": true,
    "noImplicitReturns": true,
    "noFallthroughCasesInSwitch": true,
    "noImplicitOverride": true
  }
}

// ✅ Good: Proper type definitions
interface User {
  readonly id: string;
  name: string;
  email: string;
  role: 'USER' | 'ADMIN';
  createdAt: Date;
  updatedAt: Date;
}

// Use branded types for IDs
type UserId = string & { readonly brand: unique symbol };
type CompanyId = string & { readonly brand: unique symbol };

interface CreateUserData {
  name: string;
  email: string;
  password: string;
  role?: User['role'];
}

interface UpdateUserData extends Partial<Omit<CreateUserData, 'password'>> {
  password?: string;
}

// ✅ Good: Generic type utilities
type ApiResponse<T> = {
  data: T;
  message: string;
  success: boolean;
};

type PaginatedResponse<T> = ApiResponse<T[]> & {
  pagination: {
    page: number;
    limit: number;
    total: number;
    totalPages: number;
  };
};

// Usage
const users: PaginatedResponse<User> = await userAPI.getUsers();
```

### **2. ESLint and Prettier Configuration**

```json
// .eslintrc.json
{
  "extends": [
    "next/core-web-vitals",
    "@typescript-eslint/recommended",
    "prettier"
  ],
  "parser": "@typescript-eslint/parser",
  "plugins": ["@typescript-eslint", "import"],
  "rules": {
    "@typescript-eslint/no-unused-vars": "error",
    "@typescript-eslint/no-explicit-any": "warn",
    "@typescript-eslint/prefer-const": "error",
    "import/order": [
      "error",
      {
        "groups": [
          "builtin",
          "external",
          "internal",
          "parent",
          "sibling",
          "index"
        ],
        "newlines-between": "always",
        "alphabetize": {
          "order": "asc",
          "caseInsensitive": true
        }
      }
    ]
  }
}

// package.json scripts
{
  "scripts": {
    "lint": "next lint",
    "lint:fix": "next lint --fix",
    "type-check": "tsc --noEmit",
    "format": "prettier --write .",
    "format:check": "prettier --check ."
  }
}
```

## 🔗 Navigation

← [Implementation Guide](./implementation-guide.md) | [Comparison Analysis →](./comparison-analysis.md)

---

## 📚 References

1. [React Best Practices](https://react.dev/learn/thinking-in-react)
2. [Next.js Best Practices](https://nextjs.org/docs/pages/building-your-application/deploying/production-checklist)
3. [TypeScript Best Practices](https://typescript-eslint.io/rules/)
4. [React Query Best Practices](https://tkdodo.eu/blog/practical-react-query)
5. [Testing Best Practices](https://kentcdodds.com/blog/common-mistakes-with-react-testing-library)
6. [Security Best Practices](https://owasp.org/www-project-top-ten/)

*Last updated: January 2025*