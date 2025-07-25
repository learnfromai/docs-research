# Best Practices for Nx Development

Proven patterns and recommendations for React Vite applications, Express.js backend services, and shared libraries in Nx monorepos.

## 🏗️ Architecture Best Practices

### Project Structure Organization

#### Apps vs Libraries Philosophy
```
✅ GOOD: Separate concerns clearly
apps/
  web-app/           # Deployable React application
  mobile-app/        # React Native application  
  admin-dashboard/   # Admin interface
  api-server/        # Express.js API
  auth-service/      # Authentication microservice

libs/
  shared-ui/         # Reusable React components
  shared-utils/      # Common utilities
  api-interfaces/    # TypeScript interfaces
  feature-auth/      # Authentication logic
  data-access/       # API clients and state management

❌ AVOID: Mixing applications with libraries
apps/
  everything-app/    # Monolithic application
  utility-functions/ # Should be in libs/
```

#### Recommended Folder Structure
```
my-workspace/
├── apps/
│   ├── web-app/                    # Main customer-facing app
│   │   ├── src/
│   │   │   ├── app/
│   │   │   │   ├── components/     # App-specific components
│   │   │   │   ├── pages/          # Route components
│   │   │   │   ├── hooks/          # App-specific hooks
│   │   │   │   └── services/       # App-specific services
│   │   │   ├── assets/
│   │   │   └── styles/
│   │   ├── project.json
│   │   └── vite.config.ts
│   ├── admin-dashboard/            # Internal admin interface
│   └── api-server/                 # Backend services
│       ├── src/
│       │   ├── app/
│       │   ├── routes/             # API route handlers
│       │   ├── middleware/         # Express middleware
│       │   ├── services/           # Business logic
│       │   └── utils/
│       └── project.json
├── libs/
│   ├── shared-ui/                  # UI component library
│   │   ├── src/
│   │   │   ├── lib/
│   │   │   │   ├── button/
│   │   │   │   ├── card/
│   │   │   │   ├── modal/
│   │   │   │   └── index.ts
│   │   │   └── index.ts
│   │   ├── .storybook/             # Storybook configuration
│   │   └── project.json
│   ├── api-interfaces/             # Shared TypeScript definitions
│   ├── shared-utils/               # Common utilities
│   ├── feature-auth/               # Authentication feature
│   └── data-access/                # API clients
└── tools/                          # Custom build tools and scripts
```

### Library Categories and Naming Conventions

#### 1. **Feature Libraries** - `feature-*`
```bash
# Business logic and smart components
nx g @nx/react:lib feature-auth --directory=libs/feature-auth
nx g @nx/react:lib feature-products --directory=libs/feature-products
nx g @nx/react:lib feature-checkout --directory=libs/feature-checkout
```

#### 2. **Data Access Libraries** - `data-access-*`
```bash  
# API clients and state management
nx g @nx/js:lib data-access-users --directory=libs/data-access-users
nx g @nx/js:lib data-access-products --directory=libs/data-access-products
```

#### 3. **UI Libraries** - `ui-*` or `shared-ui`
```bash
# Presentational components
nx g @nx/react:lib shared-ui --directory=libs/shared-ui
nx g @nx/react:lib ui-admin --directory=libs/ui-admin
```

#### 4. **Utility Libraries** - `util-*` or `shared-utils`
```bash
# Pure functions and helpers
nx g @nx/js:lib shared-utils --directory=libs/shared-utils
nx g @nx/js:lib util-testing --directory=libs/util-testing
```

### Dependency Management and Import Boundaries

#### Configure Module Boundaries
```json
// .eslintrc.json
{
  "overrides": [
    {
      "files": ["*.ts", "*.tsx"],
      "rules": {
        "@nx/enforce-module-boundaries": [
          "error",
          {
            "enforceBuildableLibDependency": true,
            "allow": [],
            "depConstraints": [
              {
                "sourceTag": "scope:web-app",
                "onlyDependOnLibsWithTags": [
                  "scope:shared",
                  "scope:feature",
                  "type:ui",
                  "type:util"
                ]
              },
              {
                "sourceTag": "scope:api",
                "onlyDependOnLibsWithTags": [
                  "scope:shared", 
                  "type:util",
                  "type:data-access"
                ]
              },
              {
                "sourceTag": "type:ui",
                "onlyDependOnLibsWithTags": [
                  "type:ui",
                  "type:util"
                ]
              }
            ]
          }
        ]
      }
    }
  ]
}
```

#### Tagging Strategy
```json
// libs/shared-ui/project.json
{
  "name": "shared-ui",
  "tags": ["scope:shared", "type:ui"],
  // ...
}

// libs/feature-auth/project.json  
{
  "name": "feature-auth",
  "tags": ["scope:feature", "type:feature"],
  // ...
}

// apps/web-app/project.json
{
  "name": "web-app", 
  "tags": ["scope:web-app", "type:app"],
  // ...
}
```

## ⚛️ React Vite Best Practices

### Component Architecture

#### 1. **Smart vs Dumb Components**
```tsx
// ✅ GOOD: Smart component in feature library
// libs/feature-products/src/lib/product-list/product-list.tsx
import { useState, useEffect } from 'react';
import { ProductCard } from '@my-workspace/shared-ui';
import { productService } from '@my-workspace/data-access-products';
import { Product } from '@my-workspace/api-interfaces';

export function ProductList() {
  const [products, setProducts] = useState<Product[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    productService.getProducts()
      .then(setProducts)
      .finally(() => setLoading(false));
  }, []);

  if (loading) return <div>Loading...</div>;

  return (
    <div className="product-list">
      {products.map(product => (
        <ProductCard 
          key={product.id} 
          product={product}
          onAddToCart={(id) => console.log('Add to cart:', id)}
        />
      ))}
    </div>
  );
}
```

```tsx
// ✅ GOOD: Dumb component in UI library
// libs/shared-ui/src/lib/product-card/product-card.tsx
import { Product } from '@my-workspace/api-interfaces';
import { Button } from '../button/button';

export interface ProductCardProps {
  product: Product;
  onAddToCart: (id: number) => void;
}

export function ProductCard({ product, onAddToCart }: ProductCardProps) {
  return (
    <div className="product-card">
      <img src={product.image} alt={product.name} />
      <h3>{product.name}</h3>
      <p>{product.description}</p>
      <span className="price">${product.price}</span>
      <Button onClick={() => onAddToCart(product.id)}>
        Add to Cart
      </Button>
    </div>
  );
}
```

#### 2. **Custom Hooks Pattern**
```tsx
// libs/shared-utils/src/lib/hooks/use-api.ts
import { useState, useEffect } from 'react';

export function useApi<T>(fetcher: () => Promise<T>) {
  const [data, setData] = useState<T | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);

  useEffect(() => {
    fetcher()
      .then(setData)
      .catch(setError)
      .finally(() => setLoading(false));
  }, [fetcher]);

  return { data, loading, error };
}

// Usage in components
export function UserProfile({ userId }: { userId: number }) {
  const { data: user, loading, error } = useApi(() => 
    userService.getUser(userId)
  );

  if (loading) return <div>Loading...</div>;
  if (error) return <div>Error: {error.message}</div>;
  if (!user) return <div>User not found</div>;

  return <div>Welcome, {user.name}!</div>;
}
```

### Vite Configuration Best Practices

#### Optimized Vite Configuration
```typescript
// apps/web-app/vite.config.ts
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { nxViteTsPaths } from '@nx/vite/plugins/nx-tsconfig-paths.plugin';
import path from 'path';

export default defineConfig({
  root: __dirname,
  cacheDir: '../../node_modules/.vite/apps/web-app',
  
  server: {
    port: 4200,
    host: 'localhost',
    // Proxy API calls to backend
    proxy: {
      '/api': {
        target: 'http://localhost:3000',
        changeOrigin: true,
      },
    },
  },

  preview: {
    port: 4300,
    host: 'localhost',
  },

  plugins: [
    react({
      // Enable React Fast Refresh
      fastRefresh: true,
    }),
    nxViteTsPaths(),
  ],

  // Build optimization
  build: {
    outDir: '../../dist/apps/web-app',
    reportCompressedSize: true,
    commonjsOptions: {
      transformMixedEsModules: true,
    },
    rollupOptions: {
      output: {
        manualChunks: {
          vendor: ['react', 'react-dom'],
          router: ['react-router-dom'],
        },
      },
    },
  },

  // Environment variables
  define: {
    __APP_VERSION__: JSON.stringify(process.env.npm_package_version),
  },

  // CSS configuration
  css: {
    modules: {
      localsConvention: 'camelCase',
    },
    preprocessorOptions: {
      scss: {
        additionalData: `@import "${path.resolve(__dirname, 'src/styles/variables.scss')}";`,
      },
    },
  },
});
```

### State Management Patterns

#### 1. **Local State with Context**
```tsx
// libs/feature-auth/src/lib/auth-context.tsx
import React, { createContext, useContext, useReducer, ReactNode } from 'react';
import { User } from '@my-workspace/api-interfaces';

interface AuthState {
  user: User | null;
  isAuthenticated: boolean;
  loading: boolean;
}

type AuthAction = 
  | { type: 'LOGIN_START' }
  | { type: 'LOGIN_SUCCESS'; payload: User }
  | { type: 'LOGIN_FAILURE' }
  | { type: 'LOGOUT' };

const AuthContext = createContext<{
  state: AuthState;
  dispatch: React.Dispatch<AuthAction>;
} | null>(null);

function authReducer(state: AuthState, action: AuthAction): AuthState {
  switch (action.type) {
    case 'LOGIN_START':
      return { ...state, loading: true };
    case 'LOGIN_SUCCESS':
      return { user: action.payload, isAuthenticated: true, loading: false };
    case 'LOGIN_FAILURE':
      return { user: null, isAuthenticated: false, loading: false };
    case 'LOGOUT':
      return { user: null, isAuthenticated: false, loading: false };
    default:
      return state;
  }
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [state, dispatch] = useReducer(authReducer, {
    user: null,
    isAuthenticated: false,
    loading: false,
  });

  return (
    <AuthContext.Provider value={{ state, dispatch }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
}
```

## 🖥️ Express.js Backend Best Practices

### Application Structure

#### 1. **Clean Architecture Setup**
```typescript
// apps/api-server/src/app/app.ts
import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import compression from 'compression';
import rateLimit from 'express-rate-limit';

// Routes
import authRoutes from '../routes/auth';
import userRoutes from '../routes/users';
import productRoutes from '../routes/products';

// Middleware
import { errorHandler } from '../middleware/error-handler';
import { notFound } from '../middleware/not-found';
import { requestLogger } from '../middleware/request-logger';

export function createApp() {
  const app = express();

  // Security middleware
  app.use(helmet());
  app.use(cors({
    origin: process.env['FRONTEND_URL'] || 'http://localhost:4200',
    credentials: true,
  }));

  // Rate limiting
  app.use('/api', rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 100, // limit each IP to 100 requests per windowMs
  }));

  // General middleware
  app.use(compression());
  app.use(express.json({ limit: '10mb' }));
  app.use(express.urlencoded({ extended: true }));
  app.use(morgan('combined'));
  app.use(requestLogger);

  // Health check
  app.get('/health', (req, res) => {
    res.json({ 
      status: 'OK', 
      timestamp: new Date().toISOString(),
      uptime: process.uptime()
    });
  });

  // API routes
  app.use('/api/auth', authRoutes);
  app.use('/api/users', userRoutes);
  app.use('/api/products', productRoutes);

  // Error handling
  app.use(notFound);
  app.use(errorHandler);

  return app;
}
```

#### 2. **Route Organization**
```typescript
// apps/api-server/src/routes/users.ts
import { Router } from 'express';
import { userController } from '../controllers/user.controller';
import { authenticate } from '../middleware/auth';
import { validateRequest } from '../middleware/validate-request';
import { createUserSchema, updateUserSchema } from '../schemas/user.schema';

const router = Router();

// Public routes
router.get('/', userController.getUsers);
router.get('/:id', userController.getUserById);

// Protected routes
router.use(authenticate);
router.post('/', validateRequest(createUserSchema), userController.createUser);
router.put('/:id', validateRequest(updateUserSchema), userController.updateUser);
router.delete('/:id', userController.deleteUser);

export default router;
```

#### 3. **Controller Pattern**
```typescript
// apps/api-server/src/controllers/user.controller.ts
import { Request, Response, NextFunction } from 'express';
import { userService } from '../services/user.service';
import { CreateUserRequest, UpdateUserRequest } from '@my-workspace/api-interfaces';
import { asyncHandler } from '../utils/async-handler';

class UserController {
  getUsers = asyncHandler(async (req: Request, res: Response) => {
    const users = await userService.getAllUsers();
    res.json({
      success: true,
      data: users,
      count: users.length
    });
  });

  getUserById = asyncHandler(async (req: Request, res: Response) => {
    const { id } = req.params;
    const user = await userService.getUserById(Number(id));
    
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }
    
    res.json({
      success: true,
      data: user
    });
  });

  createUser = asyncHandler(async (req: Request<{}, {}, CreateUserRequest>, res: Response) => {
    const user = await userService.createUser(req.body);
    res.status(201).json({
      success: true,
      data: user,
      message: 'User created successfully'
    });
  });
}

export const userController = new UserController();
```

#### 4. **Service Layer Pattern**
```typescript
// apps/api-server/src/services/user.service.ts
import { User, CreateUserRequest, UpdateUserRequest } from '@my-workspace/api-interfaces';
import { userRepository } from '../repositories/user.repository';
import { hashPassword, comparePassword } from '@my-workspace/shared-utils';
import { AppError } from '../utils/app-error';

class UserService {
  async getAllUsers(): Promise<User[]> {
    return userRepository.findAll();
  }

  async getUserById(id: number): Promise<User | null> {
    return userRepository.findById(id);
  }

  async createUser(userData: CreateUserRequest): Promise<User> {
    // Check if user already exists
    const existingUser = await userRepository.findByEmail(userData.email);
    if (existingUser) {
      throw new AppError('User with this email already exists', 400);
    }

    // Hash password if provided
    if (userData.password) {
      userData.password = await hashPassword(userData.password);
    }

    return userRepository.create(userData);
  }

  async updateUser(id: number, userData: UpdateUserRequest): Promise<User> {
    const existingUser = await userRepository.findById(id);
    if (!existingUser) {
      throw new AppError('User not found', 404);
    }

    if (userData.password) {
      userData.password = await hashPassword(userData.password);
    }

    return userRepository.update(id, userData);
  }

  async deleteUser(id: number): Promise<void> {
    const user = await userRepository.findById(id);
    if (!user) {
      throw new AppError('User not found', 404);
    }

    await userRepository.delete(id);
  }
}

export const userService = new UserService();
```

### Error Handling Best Practices

#### 1. **Custom Error Classes**
```typescript
// apps/api-server/src/utils/app-error.ts
export class AppError extends Error {
  public readonly statusCode: number;
  public readonly isOperational: boolean;

  constructor(
    message: string,
    statusCode: number = 500,
    isOperational: boolean = true
  ) {
    super(message);
    this.statusCode = statusCode;
    this.isOperational = isOperational;

    Error.captureStackTrace(this, this.constructor);
  }
}

// Common error types
export class ValidationError extends AppError {
  constructor(message: string) {
    super(message, 400);
  }
}

export class NotFoundError extends AppError {
  constructor(resource: string = 'Resource') {
    super(`${resource} not found`, 404);
  }
}

export class UnauthorizedError extends AppError {
  constructor(message: string = 'Unauthorized') {
    super(message, 401);
  }
}
```

#### 2. **Error Handler Middleware**
```typescript
// apps/api-server/src/middleware/error-handler.ts
import { Request, Response, NextFunction } from 'express';
import { AppError } from '../utils/app-error';

export function errorHandler(
  err: Error,
  req: Request,
  res: Response,
  next: NextFunction
) {
  let error = { ...err };
  error.message = err.message;

  // Log error
  console.error(err);

  // Mongoose bad ObjectId
  if (err.name === 'CastError') {
    const message = 'Resource not found';
    error = new AppError(message, 404);
  }

  // Mongoose duplicate key
  if ((err as any).code === 11000) {
    const message = 'Duplicate field value entered';
    error = new AppError(message, 400);
  }

  // Mongoose validation error
  if (err.name === 'ValidationError') {
    const message = Object.values((err as any).errors).map((val: any) => val.message).join(', ');
    error = new AppError(message, 400);
  }

  res.status((error as AppError).statusCode || 500).json({
    success: false,
    error: (error as AppError).message || 'Server Error',
    ...(process.env['NODE_ENV'] === 'development' && { stack: err.stack })
  });
}
```

## 📚 Shared Libraries Best Practices

### TypeScript Interface Design

#### 1. **Comprehensive Type Definitions**
```typescript
// libs/api-interfaces/src/lib/base.interface.ts
export interface BaseEntity {
  id: number;
  createdAt: Date;
  updatedAt: Date;
}

export interface ApiResponse<T> {
  success: boolean;
  data?: T;
  message?: string;
  errors?: string[];
}

export interface PaginatedResponse<T> extends ApiResponse<T[]> {
  pagination: {
    page: number;
    limit: number;
    total: number;
    totalPages: number;
  };
}

export interface CreateRequest<T> {
  data: Omit<T, keyof BaseEntity>;
}

export interface UpdateRequest<T> {
  data: Partial<Omit<T, keyof BaseEntity>>;
}
```

```typescript
// libs/api-interfaces/src/lib/user.interface.ts
import { BaseEntity } from './base.interface';

export interface User extends BaseEntity {
  email: string;
  username: string;
  firstName: string;
  lastName: string;
  avatar?: string;
  isActive: boolean;
  role: UserRole;
  preferences: UserPreferences;
}

export enum UserRole {
  ADMIN = 'admin',
  USER = 'user',
  MODERATOR = 'moderator'
}

export interface UserPreferences {
  theme: 'light' | 'dark';
  notifications: {
    email: boolean;
    push: boolean;
    sms: boolean;
  };
  language: string;
}

// Request/Response types
export interface CreateUserRequest {
  email: string;
  username: string;
  firstName: string;
  lastName: string;
  password: string;
}

export interface LoginRequest {
  email: string;
  password: string;
}

export interface LoginResponse {
  user: Omit<User, 'password'>;
  accessToken: string;
  refreshToken: string;
}
```

### Utility Library Organization

#### 1. **Modular Utility Functions**
```typescript
// libs/shared-utils/src/lib/validation/index.ts
export const validation = {
  email: (email: string): boolean => {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return emailRegex.test(email);
  },

  password: (password: string): { valid: boolean; errors: string[] } => {
    const errors: string[] = [];
    
    if (password.length < 8) {
      errors.push('Password must be at least 8 characters long');
    }
    if (!/(?=.*[a-z])/.test(password)) {
      errors.push('Password must contain at least one lowercase letter');
    }
    if (!/(?=.*[A-Z])/.test(password)) {
      errors.push('Password must contain at least one uppercase letter');
    }
    if (!/(?=.*\d)/.test(password)) {
      errors.push('Password must contain at least one number');
    }

    return { valid: errors.length === 0, errors };
  },

  required: <T>(value: T | null | undefined): value is T => {
    return value !== null && value !== undefined && value !== '';
  }
};
```

```typescript
// libs/shared-utils/src/lib/formatting/index.ts
export const formatters = {
  currency: (amount: number, currency = 'USD'): string => {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency,
    }).format(amount);
  },

  date: (date: Date | string, format: 'short' | 'long' | 'relative' = 'short'): string => {
    const dateObj = typeof date === 'string' ? new Date(date) : date;
    
    switch (format) {
      case 'long':
        return dateObj.toLocaleDateString('en-US', {
          year: 'numeric',
          month: 'long',
          day: 'numeric'
        });
      case 'relative':
        return new Intl.RelativeTimeFormat('en-US').format(
          Math.round((dateObj.getTime() - Date.now()) / (1000 * 60 * 60 * 24)),
          'day'
        );
      default:
        return dateObj.toLocaleDateString();
    }
  },

  truncate: (text: string, maxLength: number): string => {
    if (text.length <= maxLength) return text;
    return text.slice(0, maxLength - 3) + '...';
  }
};
```

## 🧪 Testing Best Practices

### Component Testing Strategy

#### 1. **React Component Tests**
```typescript
// libs/shared-ui/src/lib/button/button.spec.tsx
import { render, fireEvent, screen } from '@testing-library/react';
import { Button } from './button';

describe('Button Component', () => {
  it('renders with correct text', () => {
    render(<Button>Click me</Button>);
    expect(screen.getByText('Click me')).toBeInTheDocument();
  });

  it('applies correct variant class', () => {
    render(<Button variant="secondary">Test</Button>);
    const button = screen.getByRole('button');
    expect(button).toHaveClass('btn--secondary');
  });

  it('calls onClick handler when clicked', () => {
    const handleClick = jest.fn();
    render(<Button onClick={handleClick}>Click me</Button>);
    
    fireEvent.click(screen.getByText('Click me'));
    expect(handleClick).toHaveBeenCalledTimes(1);
  });

  it('is disabled when disabled prop is true', () => {
    render(<Button disabled>Disabled</Button>);
    expect(screen.getByRole('button')).toBeDisabled();
  });

  it('matches snapshot', () => {
    const { container } = render(
      <Button variant="primary" size="lg">
        Snapshot Test
      </Button>
    );
    expect(container.firstChild).toMatchSnapshot();
  });
});
```

#### 2. **API Service Tests**
```typescript
// libs/data-access-users/src/lib/user.service.spec.ts
import { userService } from './user.service';
import { ApiClient } from '@my-workspace/shared-utils';

// Mock the API client
jest.mock('@my-workspace/shared-utils');
const mockApiClient = ApiClient as jest.Mocked<typeof ApiClient>;

describe('UserService', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('getUsers', () => {
    it('returns users list', async () => {
      const mockUsers = [
        { id: 1, name: 'John Doe', email: 'john@example.com' },
        { id: 2, name: 'Jane Smith', email: 'jane@example.com' }
      ];
      
      mockApiClient.prototype.get.mockResolvedValue({ data: mockUsers });

      const result = await userService.getUsers();
      
      expect(result).toEqual(mockUsers);
      expect(mockApiClient.prototype.get).toHaveBeenCalledWith('/users');
    });

    it('handles API errors gracefully', async () => {
      const errorMessage = 'Network error';
      mockApiClient.prototype.get.mockRejectedValue(new Error(errorMessage));

      await expect(userService.getUsers()).rejects.toThrow(errorMessage);
    });
  });
});
```

### End-to-End Testing Strategy

#### 1. **Cypress E2E Tests**
```typescript
// apps/web-app-e2e/src/e2e/user-flow.cy.ts
describe('User Authentication Flow', () => {
  beforeEach(() => {
    // Mock API responses
    cy.intercept('POST', '/api/auth/login', { 
      fixture: 'auth/login-success.json' 
    }).as('loginRequest');
    
    cy.intercept('GET', '/api/users/profile', { 
      fixture: 'users/user-profile.json' 
    }).as('profileRequest');
  });

  it('should allow user to login and view profile', () => {
    cy.visit('/login');

    // Login form
    cy.get('[data-cy=email-input]').type('user@example.com');
    cy.get('[data-cy=password-input]').type('password123');
    cy.get('[data-cy=login-button]').click();

    // Wait for login API call
    cy.wait('@loginRequest');

    // Should redirect to dashboard
    cy.url().should('include', '/dashboard');
    cy.get('[data-cy=welcome-message]').should('contain', 'Welcome back');

    // Navigate to profile
    cy.get('[data-cy=profile-link]').click();
    cy.wait('@profileRequest');

    // Verify profile information
    cy.get('[data-cy=user-name]').should('contain', 'John Doe');
    cy.get('[data-cy=user-email]').should('contain', 'user@example.com');
  });

  it('should handle login errors', () => {
    cy.intercept('POST', '/api/auth/login', { 
      statusCode: 401,
      body: { message: 'Invalid credentials' }
    }).as('failedLogin');

    cy.visit('/login');
    cy.get('[data-cy=email-input]').type('invalid@example.com');
    cy.get('[data-cy=password-input]').type('wrongpassword');
    cy.get('[data-cy=login-button]').click();

    cy.wait('@failedLogin');
    cy.get('[data-cy=error-message]').should('contain', 'Invalid credentials');
  });
});
```

## 🚀 Performance Optimization

### Build and Bundle Optimization

#### 1. **Nx Target Configuration**
```json
// nx.json - Optimized build targets
{
  "targetDefaults": {
    "build": {
      "cache": true,
      "dependsOn": ["^build"],
      "inputs": ["production", "^production"],
      "options": {
        "outputHashing": "all",
        "optimization": true,
        "sourceMap": false,
        "extractCss": true,
        "namedChunks": false,
        "aot": true,
        "extractLicenses": true,
        "vendorChunk": false,
        "buildOptimizer": true
      }
    },
    "test": {
      "cache": true,
      "inputs": ["default", "^production", "{workspaceRoot}/jest.preset.js"]
    },
    "lint": {
      "cache": true,
      "inputs": ["default", "{workspaceRoot}/.eslintrc.json"]
    }
  }
}
```

#### 2. **Lazy Loading and Code Splitting**
```tsx
// apps/web-app/src/app/app.tsx
import { Suspense, lazy } from 'react';
import { Routes, Route } from 'react-router-dom';
import { LoadingSpinner } from '@my-workspace/shared-ui';

// Lazy load route components
const HomePage = lazy(() => import('./pages/home/home'));
const ProductsPage = lazy(() => import('./pages/products/products'));
const ProfilePage = lazy(() => import('./pages/profile/profile'));
const AdminDashboard = lazy(() => 
  import('./pages/admin/admin-dashboard').then(module => ({
    default: module.AdminDashboard
  }))
);

export function App() {
  return (
    <Suspense fallback={<LoadingSpinner />}>
      <Routes>
        <Route path="/" element={<HomePage />} />
        <Route path="/products" element={<ProductsPage />} />
        <Route path="/profile" element={<ProfilePage />} />
        <Route 
          path="/admin/*" 
          element={<AdminDashboard />} 
        />
      </Routes>
    </Suspense>
  );
}
```

### Caching Strategies

#### 1. **Nx Cloud Setup**
```bash
# Connect to Nx Cloud for remote caching
nx connect-to-nx-cloud

# Verify cache is working
nx build my-app
nx build my-app  # Should use cache on second run
```

#### 2. **Local Caching Optimization**
```json
// nx.json - Cache configuration
{
  "tasksRunnerOptions": {
    "default": {
      "runner": "@nx/nx-cloud",
      "options": {
        "cacheableOperations": ["build", "lint", "test", "e2e"],
        "accessToken": "your-nx-cloud-token"
      }
    }
  },
  "namedInputs": {
    "default": ["{projectRoot}/**/*", "sharedGlobals"],
    "production": [
      "default",
      "!{projectRoot}/**/?(*.)+(spec|test).[jt]s?(x)?(.snap)",
      "!{projectRoot}/tsconfig.spec.json"
    ],
    "sharedGlobals": [
      "{workspaceRoot}/babel.config.json",
      "{workspaceRoot}/.browserslistrc"
    ]
  }
}
```

## 🔄 Development Workflow

### Git Workflow with Nx

#### 1. **Feature Branch Development**
```bash
# Create feature branch
git checkout -b feature/user-authentication

# Make changes to specific projects
# Only run affected commands for efficiency
nx affected:test
nx affected:lint
nx affected:build

# Check what will be affected
nx affected:graph
```

#### 2. **Pre-commit Hooks**
```json
// package.json - Add husky and lint-staged
{
  "scripts": {
    "prepare": "husky install"
  },
  "lint-staged": {
    "*.{ts,tsx}": [
      "nx affected:lint --fix",
      "nx format:write"
    ],
    "*.{js,jsx,ts,tsx}": [
      "nx affected:test --passWithNoTests"
    ]
  }
}
```

### Continuous Integration Best Practices

#### 1. **GitHub Actions Workflow**
```yaml
# .github/workflows/ci.yml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  main:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
        with:
          fetch-depth: 0

      - uses: actions/setup-node@v3
        with:
          node-version: '18'
          cache: 'npm'

      - run: npm ci

      - uses: nrwl/nx-set-shas@v3

      - run: nx format:check
      - run: nx affected --target=lint --parallel=3
      - run: nx affected --target=test --parallel=3 --ci --code-coverage
      - run: nx affected --target=build --parallel=3
      - run: nx affected --target=e2e --parallel=1
```

This comprehensive best practices guide covers the essential patterns and recommendations for successful Nx development. The key is to start simple and gradually adopt more advanced patterns as your team and codebase grow.

---

**Previous**: [← Implementation Guide](./implementation-guide.md) | **Next**: [CLI Commands Reference →](./cli-commands-reference.md)