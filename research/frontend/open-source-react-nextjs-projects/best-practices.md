# Best Practices: Production-Ready React & Next.js Development

Consolidated best practices and guidelines derived from analyzing 15+ production-ready open source React and Next.js projects.

## 🏗️ Architecture & Code Organization

### 1. Folder Structure Best Practices

#### Feature-Based Organization (Recommended for Medium-Large Apps)
```
src/
├── app/                    # Next.js App Router
├── components/
│   ├── ui/                # Reusable UI primitives
│   └── features/          # Feature-specific components
│       ├── auth/
│       ├── dashboard/
│       └── products/
├── hooks/                 # Custom React hooks
│   ├── api/              # API-specific hooks
│   ├── auth/             # Authentication hooks
│   └── ui/               # UI-specific hooks
├── lib/                  # Utilities and configurations
├── stores/               # State management
│   ├── slices/           # Redux slices (if using Redux)
│   └── providers/        # Context providers
└── types/                # TypeScript definitions
    ├── api.ts
    ├── auth.ts
    └── global.ts
```

#### Component-Based Organization (Suitable for Smaller Apps)
```
src/
├── components/
│   ├── forms/            # Form components
│   ├── layouts/          # Layout components
│   ├── tables/           # Table components
│   └── ui/              # Base UI components
├── hooks/               # Custom hooks
├── lib/                 # Utilities
├── pages/               # Page components
└── stores/              # State management
```

### 2. Component Design Principles

#### Compound Components Pattern
```typescript
// ✅ Good: Compound component for flexibility
<Card>
  <Card.Header>
    <Card.Title>Product Details</Card.Title>
    <Card.Description>Manage your product information</Card.Description>
  </Card.Header>
  <Card.Content>
    <ProductForm />
  </Card.Content>
  <Card.Footer>
    <Button variant="outline">Cancel</Button>
    <Button>Save Changes</Button>
  </Card.Footer>
</Card>

// ❌ Bad: Monolithic component with too many props
<ProductCard
  title="Product Details"
  description="Manage your product information"
  showCancel={true}
  showSave={true}
  onCancel={handleCancel}
  onSave={handleSave}
  cancelText="Cancel"
  saveText="Save Changes"
/>
```

#### Component Composition Over Configuration
```typescript
// ✅ Good: Composition pattern
function UserProfile({ user }: { user: User }) {
  return (
    <div className="user-profile">
      <Avatar src={user.avatar} alt={user.name} />
      <UserInfo user={user} />
      <UserActions user={user} />
    </div>
  )
}

// ❌ Bad: Too many configuration props
function UserProfile({
  user,
  showAvatar = true,
  avatarSize = 'md',
  showInfo = true,
  showActions = true,
  actionTypes = ['edit', 'delete'],
}: UserProfileProps) {
  // Complex conditional rendering logic
}
```

### 3. TypeScript Best Practices

#### Strict Type Definitions
```typescript
// ✅ Good: Strict typing with proper interfaces
interface User {
  readonly id: string
  name: string
  email: string
  role: 'admin' | 'user' | 'moderator'
  permissions: Permission[]
  createdAt: Date
  updatedAt: Date
}

interface Permission {
  readonly id: string
  name: string
  resource: string
  actions: ('create' | 'read' | 'update' | 'delete')[]
}

// ✅ Good: Generic types for reusability
interface ApiResponse<T> {
  data: T
  message: string
  success: boolean
  timestamp: string
}

interface PaginatedResponse<T> extends ApiResponse<T[]> {
  pagination: {
    page: number
    limit: number
    total: number
    hasMore: boolean
  }
}

// ❌ Bad: Using 'any' or overly loose types
interface User {
  id: any
  data: any
  metadata?: any
}
```

#### Utility Types for Better DX
```typescript
// ✅ Good: Utility types for common patterns
type CreateUserData = Omit<User, 'id' | 'createdAt' | 'updatedAt'>
type UpdateUserData = Partial<Pick<User, 'name' | 'email' | 'role'>>
type UserResponse = ApiResponse<User>
type UsersResponse = PaginatedResponse<User>

// Branded types for better type safety
type UserId = string & { readonly brand: unique symbol }
type Email = string & { readonly brand: unique symbol }

function createUser(data: CreateUserData): Promise<UserResponse> {
  // Implementation
}

function updateUser(id: UserId, data: UpdateUserData): Promise<UserResponse> {
  // Implementation
}
```

---

## ⚡ Performance Optimization

### 1. React Performance Patterns

#### Memoization Best Practices
```typescript
// ✅ Good: Strategic memoization
const ProductCard = React.memo(({ product, onUpdate }: ProductCardProps) => {
  const handleUpdate = useCallback((updates: Partial<Product>) => {
    onUpdate(product.id, updates)
  }, [product.id, onUpdate])

  const formattedPrice = useMemo(() => 
    new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD',
    }).format(product.price)
  , [product.price])

  return (
    <div className="product-card">
      <h3>{product.name}</h3>
      <p>{formattedPrice}</p>
      <Button onClick={handleUpdate}>Update</Button>
    </div>
  )
}, (prevProps, nextProps) => {
  // Custom comparison for performance
  return (
    prevProps.product.id === nextProps.product.id &&
    prevProps.product.name === nextProps.product.name &&
    prevProps.product.price === nextProps.product.price
  )
})

// ❌ Bad: Over-memoization
const SimpleComponent = React.memo(() => {
  const value = useMemo(() => 'static string', []) // Unnecessary
  const handler = useCallback(() => console.log('click'), []) // Unnecessary
  
  return <button onClick={handler}>{value}</button>
})
```

#### Efficient List Rendering
```typescript
// ✅ Good: Virtualized lists for large datasets
import { useVirtualizer } from '@tanstack/react-virtual'

function VirtualizedProductList({ products }: { products: Product[] }) {
  const parentRef = useRef<HTMLDivElement>(null)

  const rowVirtualizer = useVirtualizer({
    count: products.length,
    getScrollElement: () => parentRef.current,
    estimateSize: () => 100,
    overscan: 5,
  })

  return (
    <div ref={parentRef} className="h-96 overflow-auto">
      <div
        style={{
          height: `${rowVirtualizer.getTotalSize()}px`,
          width: '100%',
          position: 'relative',
        }}
      >
        {rowVirtualizer.getVirtualItems().map((virtualItem) => (
          <div
            key={virtualItem.index}
            style={{
              position: 'absolute',
              top: 0,
              left: 0,
              width: '100%',
              height: `${virtualItem.size}px`,
              transform: `translateY(${virtualItem.start}px)`,
            }}
          >
            <ProductCard product={products[virtualItem.index]} />
          </div>
        ))}
      </div>
    </div>
  )
}

// ❌ Bad: Rendering large lists without virtualization
function ProductList({ products }: { products: Product[] }) {
  return (
    <div>
      {products.map(product => (
        <ProductCard key={product.id} product={product} />
      ))}
    </div>
  )
}
```

### 2. Bundle Optimization

#### Code Splitting Strategies
```typescript
// ✅ Good: Route-based code splitting
const Dashboard = lazy(() => import('@/pages/dashboard'))
const Settings = lazy(() => import('@/pages/settings'))
const Reports = lazy(() => 
  import('@/pages/reports').then(module => ({
    default: module.ReportsPage
  }))
)

// ✅ Good: Component-based code splitting
const ChartComponent = lazy(() => 
  import('@/components/charts/advanced-chart')
)

function Dashboard() {
  return (
    <div>
      <h1>Dashboard</h1>
      <Suspense fallback={<ChartSkeleton />}>
        <ChartComponent data={chartData} />
      </Suspense>
    </div>
  )
}

// ✅ Good: Library code splitting
// Instead of importing entire lodash
import debounce from 'lodash/debounce'
// Or better yet, use a smaller alternative
import { debounce } from '@/lib/utils'
```

### 3. Next.js Specific Optimizations

#### Image Optimization
```typescript
// ✅ Good: Optimized images with Next.js
import Image from 'next/image'

function ProductImage({ product }: { product: Product }) {
  return (
    <Image
      src={product.imageUrl}
      alt={product.name}
      width={400}
      height={300}
      priority={product.featured} // Load immediately for above-fold images
      sizes="(max-width: 768px) 100vw, (max-width: 1200px) 50vw, 33vw"
      placeholder="blur"
      blurDataURL="data:image/jpeg;base64,..."
      className="object-cover"
    />
  )
}

// ❌ Bad: Regular img tag without optimization
function ProductImage({ product }: { product: Product }) {
  return (
    <img 
      src={product.imageUrl} 
      alt={product.name}
      className="w-full h-auto"
    />
  )
}
```

#### Server Component Optimization
```typescript
// ✅ Good: Server component with proper data fetching
export default async function ProductsPage({
  searchParams,
}: {
  searchParams: { search?: string; category?: string }
}) {
  // Fetch data on the server
  const products = await getProducts({
    search: searchParams.search,
    category: searchParams.category,
  })

  return (
    <div>
      <ProductsHeader />
      <Suspense fallback={<ProductsSkeleton />}>
        <ProductsList products={products} />
      </Suspense>
    </div>
  )
}

// ✅ Good: Client component for interactivity
'use client'
function ProductsFilter() {
  const [filters, setFilters] = useState({})
  const searchParams = useSearchParams()
  const router = useRouter()

  const updateFilters = (newFilters: any) => {
    const params = new URLSearchParams(searchParams)
    Object.entries(newFilters).forEach(([key, value]) => {
      if (value) {
        params.set(key, value as string)
      } else {
        params.delete(key)
      }
    })
    router.push(`?${params.toString()}`)
  }

  return (
    <FilterForm onFiltersChange={updateFilters} />
  )
}
```

---

## 🔐 Security Best Practices

### 1. Authentication & Authorization

#### Secure Token Handling
```typescript
// ✅ Good: Secure token storage and handling
export const useAuth = () => {
  const [user, setUser] = useState<User | null>(null)
  
  // Store refresh token in httpOnly cookie (server-side)
  // Store access token in memory only
  const [accessToken, setAccessToken] = useState<string | null>(null)

  const login = async (credentials: LoginCredentials) => {
    const response = await fetch('/api/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(credentials),
      credentials: 'include', // Include httpOnly cookies
    })

    if (response.ok) {
      const { user, accessToken } = await response.json()
      setUser(user)
      setAccessToken(accessToken) // Store in memory only
    }
  }

  const logout = async () => {
    await fetch('/api/auth/logout', {
      method: 'POST',
      credentials: 'include',
    })
    setUser(null)
    setAccessToken(null)
  }

  return { user, accessToken, login, logout }
}

// ❌ Bad: Storing sensitive tokens in localStorage
const login = async (credentials: LoginCredentials) => {
  const { user, accessToken, refreshToken } = await authApi.login(credentials)
  localStorage.setItem('accessToken', accessToken) // Vulnerable to XSS
  localStorage.setItem('refreshToken', refreshToken) // Vulnerable to XSS
}
```

#### Role-Based Access Control
```typescript
// ✅ Good: Proper RBAC implementation
interface Permission {
  resource: string
  action: 'create' | 'read' | 'update' | 'delete'
}

interface Role {
  name: string
  permissions: Permission[]
}

export const usePermissions = () => {
  const { user } = useAuth()

  const hasPermission = useCallback((resource: string, action: string) => {
    if (!user?.role?.permissions) return false

    return user.role.permissions.some(
      (permission: Permission) =>
        permission.resource === resource && permission.action === action
    )
  }, [user])

  const canAccess = useCallback((requiredPermissions: Permission[]) => {
    return requiredPermissions.every(({ resource, action }) =>
      hasPermission(resource, action)
    )
  }, [hasPermission])

  return { hasPermission, canAccess }
}

// Usage in components
function DeleteProductButton({ productId }: { productId: string }) {
  const { hasPermission } = usePermissions()
  
  if (!hasPermission('products', 'delete')) {
    return null
  }

  return (
    <Button 
      variant="destructive" 
      onClick={() => deleteProduct(productId)}
    >
      Delete
    </Button>
  )
}
```

### 2. Input Validation & Sanitization

#### Form Validation with Zod
```typescript
// ✅ Good: Comprehensive validation schemas
const createProductSchema = z.object({
  name: z
    .string()
    .min(1, 'Product name is required')
    .max(100, 'Product name must be less than 100 characters')
    .regex(/^[a-zA-Z0-9\s-]+$/, 'Invalid characters in product name'),
  
  description: z
    .string()
    .max(500, 'Description must be less than 500 characters')
    .optional(),
  
  price: z
    .number()
    .min(0.01, 'Price must be greater than 0')
    .max(999999.99, 'Price is too high'),
  
  category: z.enum(['electronics', 'clothing', 'books', 'home']),
  
  tags: z
    .array(z.string())
    .max(10, 'Maximum 10 tags allowed')
    .optional(),
  
  email: z
    .string()
    .email('Invalid email format')
    .transform(email => email.toLowerCase()),
})

// Server-side validation
export async function POST(request: Request) {
  try {
    const body = await request.json()
    const validatedData = createProductSchema.parse(body)
    
    // Process validated data
    const product = await createProduct(validatedData)
    return NextResponse.json(product)
  } catch (error) {
    if (error instanceof z.ZodError) {
      return NextResponse.json(
        { error: 'Validation failed', details: error.errors },
        { status: 400 }
      )
    }
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}
```

---

## 🗄️ State Management Best Practices

### 1. Zustand Patterns

#### Store Organization
```typescript
// ✅ Good: Feature-based store slices
interface AuthSlice {
  user: User | null
  accessToken: string | null
  login: (credentials: LoginCredentials) => Promise<void>
  logout: () => void
}

interface UISlice {
  theme: 'light' | 'dark'
  sidebarOpen: boolean
  toggleTheme: () => void
  setSidebarOpen: (open: boolean) => void
}

interface ProductSlice {
  products: Product[]
  selectedProduct: Product | null
  filters: ProductFilters
  setProducts: (products: Product[]) => void
  selectProduct: (id: string) => void
  updateFilters: (filters: Partial<ProductFilters>) => void
}

// Combine slices
type StoreState = AuthSlice & UISlice & ProductSlice

export const useStore = create<StoreState>()(
  devtools(
    persist(
      (...args) => ({
        ...createAuthSlice(...args),
        ...createUISlice(...args),
        ...createProductSlice(...args),
      }),
      {
        name: 'app-storage',
        partialize: (state) => ({
          user: state.user,
          theme: state.theme,
        }),
      }
    )
  )
)

// Individual slice creators
const createAuthSlice: StateCreator<StoreState, [], [], AuthSlice> = (set, get) => ({
  user: null,
  accessToken: null,
  login: async (credentials) => {
    // Implementation
  },
  logout: () => {
    set({ user: null, accessToken: null })
  },
})
```

### 2. React Query Patterns

#### Query Key Management
```typescript
// ✅ Good: Centralized query key management
export const queryKeys = {
  all: ['app'] as const,
  users: () => [...queryKeys.all, 'users'] as const,
  user: (id: string) => [...queryKeys.users(), id] as const,
  userPosts: (userId: string) => [...queryKeys.user(userId), 'posts'] as const,
  
  products: () => [...queryKeys.all, 'products'] as const,
  product: (id: string) => [...queryKeys.products(), id] as const,
  productsByCategory: (category: string) => 
    [...queryKeys.products(), 'category', category] as const,
}

// Usage
export const useProducts = (filters?: ProductFilters) => {
  return useQuery({
    queryKey: [...queryKeys.products(), filters],
    queryFn: () => api.getProducts(filters),
    staleTime: 5 * 60 * 1000,
  })
}

export const useProduct = (id: string) => {
  return useQuery({
    queryKey: queryKeys.product(id),
    queryFn: () => api.getProduct(id),
    enabled: !!id,
  })
}
```

#### Error Handling Patterns
```typescript
// ✅ Good: Centralized error handling
export const useGlobalErrorHandler = () => {
  const queryClient = useQueryClient()

  useEffect(() => {
    const handleError = (error: any) => {
      if (error?.status === 401) {
        // Handle authentication errors
        useAuthStore.getState().logout()
        queryClient.clear()
        toast.error('Session expired. Please log in again.')
      } else if (error?.status >= 500) {
        // Handle server errors
        toast.error('Something went wrong. Please try again later.')
      }
    }

    // Set global error handler
    queryClient.setDefaultOptions({
      queries: {
        onError: handleError,
      },
      mutations: {
        onError: handleError,
      },
    })
  }, [queryClient])
}
```

---

## 🎨 UI/UX Best Practices

### 1. Accessibility

#### Keyboard Navigation
```typescript
// ✅ Good: Proper keyboard navigation
function Modal({ isOpen, onClose, children }: ModalProps) {
  const dialogRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    if (isOpen) {
      dialogRef.current?.focus()
    }
  }, [isOpen])

  const handleKeyDown = (event: KeyboardEvent) => {
    if (event.key === 'Escape') {
      onClose()
    }
  }

  return (
    <Dialog open={isOpen} onOpenChange={onClose}>
      <DialogContent
        ref={dialogRef}
        onKeyDown={handleKeyDown}
        aria-labelledby="modal-title"
        aria-describedby="modal-description"
      >
        {children}
      </DialogContent>
    </Dialog>
  )
}

// ✅ Good: Focus management
function SearchInput() {
  const [query, setQuery] = useState('')
  const [results, setResults] = useState([])
  const [selectedIndex, setSelectedIndex] = useState(-1)

  const handleKeyDown = (event: KeyboardEvent) => {
    switch (event.key) {
      case 'ArrowDown':
        event.preventDefault()
        setSelectedIndex(prev => 
          prev < results.length - 1 ? prev + 1 : prev
        )
        break
      case 'ArrowUp':
        event.preventDefault()
        setSelectedIndex(prev => prev > 0 ? prev - 1 : -1)
        break
      case 'Enter':
        if (selectedIndex >= 0) {
          selectResult(results[selectedIndex])
        }
        break
    }
  }

  return (
    <div className="search-container">
      <input
        type="text"
        value={query}
        onChange={(e) => setQuery(e.target.value)}
        onKeyDown={handleKeyDown}
        aria-expanded={results.length > 0}
        aria-autocomplete="list"
        role="combobox"
      />
      {results.length > 0 && (
        <ul role="listbox" className="search-results">
          {results.map((result, index) => (
            <li
              key={result.id}
              role="option"
              aria-selected={index === selectedIndex}
              className={index === selectedIndex ? 'selected' : ''}
            >
              {result.name}
            </li>
          ))}
        </ul>
      )}
    </div>
  )
}
```

### 2. Loading States and Error Boundaries

#### Comprehensive Loading States
```typescript
// ✅ Good: Meaningful loading states
function ProductList() {
  const { data: products, isLoading, error } = useProducts()

  if (isLoading) {
    return (
      <div className="space-y-4">
        {Array.from({ length: 6 }).map((_, i) => (
          <ProductCardSkeleton key={i} />
        ))}
      </div>
    )
  }

  if (error) {
    return (
      <ErrorState
        title="Failed to load products"
        description="Please try again or contact support if the problem persists."
        action={<Button onClick={() => window.location.reload()}>Retry</Button>}
      />
    )
  }

  if (!products?.length) {
    return (
      <EmptyState
        title="No products found"
        description="Create your first product to get started."
        action={<Button href="/products/new">Create Product</Button>}
      />
    )
  }

  return (
    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
      {products.map(product => (
        <ProductCard key={product.id} product={product} />
      ))}
    </div>
  )
}
```

#### Error Boundary Implementation
```typescript
// ✅ Good: Comprehensive error boundary
class ErrorBoundary extends Component<
  { children: ReactNode; fallback?: ComponentType<{ error: Error }> },
  { hasError: boolean; error?: Error }
> {
  constructor(props: any) {
    super(props)
    this.state = { hasError: false }
  }

  static getDerivedStateFromError(error: Error) {
    return { hasError: true, error }
  }

  componentDidCatch(error: Error, errorInfo: ErrorInfo) {
    // Log error to monitoring service
    console.error('Error caught by boundary:', error, errorInfo)
    
    // Send to error reporting service
    if (process.env.NODE_ENV === 'production') {
      // reportError(error, errorInfo)
    }
  }

  render() {
    if (this.state.hasError) {
      const FallbackComponent = this.props.fallback || DefaultErrorFallback
      return <FallbackComponent error={this.state.error!} />
    }

    return this.props.children
  }
}

function DefaultErrorFallback({ error }: { error: Error }) {
  return (
    <div className="error-boundary">
      <h2>Something went wrong</h2>
      <p>{error.message}</p>
      <Button onClick={() => window.location.reload()}>
        Reload Page
      </Button>
    </div>
  )
}
```

---

## 🧪 Testing Best Practices

### 1. Testing Strategy

#### Testing Pyramid
```typescript
// ✅ Good: Unit tests for utilities
// src/lib/__tests__/utils.test.ts
import { formatCurrency, debounce, validateEmail } from '@/lib/utils'

describe('formatCurrency', () => {
  it('formats USD currency correctly', () => {
    expect(formatCurrency(1234.56, 'USD')).toBe('$1,234.56')
  })

  it('handles zero values', () => {
    expect(formatCurrency(0, 'USD')).toBe('$0.00')
  })
})

// ✅ Good: Component integration tests
// src/components/__tests__/product-form.test.tsx
import { render, screen, fireEvent, waitFor } from '@/lib/test-utils'
import { ProductForm } from '@/components/forms/product-form'

describe('ProductForm', () => {
  it('submits form with valid data', async () => {
    const onSubmit = jest.fn()
    render(<ProductForm onSubmit={onSubmit} />)

    fireEvent.change(screen.getByLabelText(/name/i), {
      target: { value: 'Test Product' },
    })
    fireEvent.change(screen.getByLabelText(/price/i), {
      target: { value: '29.99' },
    })

    fireEvent.click(screen.getByRole('button', { name: /submit/i }))

    await waitFor(() => {
      expect(onSubmit).toHaveBeenCalledWith({
        name: 'Test Product',
        price: 29.99,
      })
    })
  })
})
```

### 2. Mock Strategies

#### API Mocking
```typescript
// ✅ Good: MSW for API mocking
// src/mocks/handlers.ts
import { rest } from 'msw'

export const handlers = [
  rest.get('/api/products', (req, res, ctx) => {
    return res(
      ctx.json([
        {
          id: '1',
          name: 'Test Product',
          price: 29.99,
          category: 'electronics',
        },
      ])
    )
  }),

  rest.post('/api/products', (req, res, ctx) => {
    return res(
      ctx.json({
        id: '2',
        ...req.body,
        createdAt: new Date().toISOString(),
      })
    )
  }),
]

// src/mocks/server.ts
import { setupServer } from 'msw/node'
import { handlers } from './handlers'

export const server = setupServer(...handlers)

// jest.setup.js
import { server } from './src/mocks/server'

beforeAll(() => server.listen())
afterEach(() => server.resetHandlers())
afterAll(() => server.close())
```

---

## 📈 Monitoring and Analytics

### 1. Performance Monitoring

#### Core Web Vitals Tracking
```typescript
// ✅ Good: Performance monitoring
export function reportWebVitals(metric: any) {
  // Send to analytics service
  if (typeof window !== 'undefined') {
    switch (metric.name) {
      case 'CLS':
      case 'FID':
      case 'FCP':
      case 'LCP':
      case 'TTFB':
        // analytics.track('Web Vital', metric)
        console.log(metric)
        break
      default:
        break
    }
  }
}

// app/layout.tsx
import { reportWebVitals } from '@/lib/web-vitals'

export default function RootLayout() {
  useEffect(() => {
    if (typeof window !== 'undefined') {
      import('web-vitals').then(({ getCLS, getFID, getFCP, getLCP, getTTFB }) => {
        getCLS(reportWebVitals)
        getFID(reportWebVitals)
        getFCP(reportWebVitals)
        getLCP(reportWebVitals)
        getTTFB(reportWebVitals)
      })
    }
  }, [])

  return (
    // Layout content
  )
}
```

### 2. Error Tracking

#### Comprehensive Error Logging
```typescript
// ✅ Good: Error tracking service
class ErrorTracker {
  private static instance: ErrorTracker
  
  static getInstance() {
    if (!ErrorTracker.instance) {
      ErrorTracker.instance = new ErrorTracker()
    }
    return ErrorTracker.instance
  }

  logError(error: Error, context?: Record<string, any>) {
    const errorInfo = {
      message: error.message,
      stack: error.stack,
      timestamp: new Date().toISOString(),
      url: window.location.href,
      userAgent: navigator.userAgent,
      ...context,
    }

    // Send to error tracking service
    if (process.env.NODE_ENV === 'production') {
      // Sentry.captureException(error, { extra: errorInfo })
    } else {
      console.error('Error logged:', errorInfo)
    }
  }

  logEvent(event: string, properties?: Record<string, any>) {
    // Send to analytics service
    // analytics.track(event, properties)
  }
}

export const errorTracker = ErrorTracker.getInstance()
```

---

## 🔧 Development Workflow

### 1. Git Conventions

#### Commit Message Standards
```bash
# ✅ Good: Conventional commits
feat(auth): add OAuth2 authentication flow
fix(api): resolve race condition in data fetching
docs(readme): update installation instructions
style(ui): improve button component accessibility
refactor(state): migrate from Redux to Zustand
test(auth): add integration tests for login flow
chore(deps): update React to version 18.2

# ❌ Bad: Unclear commit messages
updated stuff
fix
working version
changes
```

#### Branch Naming
```bash
# ✅ Good: Descriptive branch names
feature/user-authentication
bugfix/payment-validation-error
hotfix/security-vulnerability
chore/update-dependencies
docs/api-documentation
```

### 2. Code Review Guidelines

#### Pull Request Best Practices
```markdown
## Pull Request Template

### Description
Brief description of changes and motivation.

### Type of Change
- [ ] Bug fix (non-breaking change that fixes an issue)
- [ ] New feature (non-breaking change that adds functionality)
- [ ] Breaking change (fix or feature that causes existing functionality to not work as expected)
- [ ] Documentation update

### Testing
- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Manual testing completed

### Screenshots (if applicable)
Include screenshots for UI changes.

### Checklist
- [ ] Code follows project style guidelines
- [ ] Self-review completed
- [ ] Comments added for complex logic
- [ ] Documentation updated
- [ ] No console.log statements in production code
```

---

## 📚 Key Takeaways

### ✅ Essential Practices
1. **Type Safety**: Use TypeScript strictly with proper type definitions
2. **Performance**: Implement memoization, code splitting, and optimization strategically
3. **Security**: Follow secure authentication patterns and input validation
4. **Testing**: Maintain good test coverage with unit, integration, and e2e tests
5. **Accessibility**: Ensure keyboard navigation and screen reader support
6. **Error Handling**: Implement comprehensive error boundaries and logging
7. **Code Organization**: Use consistent folder structure and naming conventions
8. **State Management**: Choose appropriate tools for different types of state
9. **Documentation**: Maintain clear code comments and project documentation
10. **Monitoring**: Track performance metrics and errors in production

### 🚫 Common Pitfalls to Avoid
1. **Over-optimization**: Don't memoize everything
2. **Poor Error Handling**: Avoid generic error messages
3. **Inconsistent Patterns**: Stick to established conventions
4. **Security Oversights**: Never store sensitive data in localStorage
5. **Accessibility Neglect**: Don't forget keyboard users
6. **Bundle Bloat**: Be mindful of bundle size
7. **State Mismanagement**: Use the right tool for the right job
8. **Testing Gaps**: Don't skip testing critical paths
9. **Performance Ignorance**: Monitor and optimize continuously
10. **Documentation Debt**: Keep documentation up to date

These best practices represent the collective wisdom of production-ready React applications and should serve as guidelines for building maintainable, secure, and performant applications.