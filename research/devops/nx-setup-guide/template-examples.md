# Template Examples and Working Code

Complete working examples for React Vite applications, Express.js APIs, and shared libraries in Nx workspaces.

## 📋 Table of Contents

- [Complete Workspace Setup](#complete-workspace-setup)
- [React Vite Application Templates](#react-vite-application-templates)
- [Express.js API Templates](#expressjs-api-templates)
- [Shared Library Templates](#shared-library-templates)
- [Configuration Examples](#configuration-examples)
- [Testing Templates](#testing-templates)
- [Real-world Integration Examples](#real-world-integration-examples)

## 🏗️ Complete Workspace Setup

### Full Stack E-commerce Template

This example demonstrates a complete setup for an e-commerce application with React frontend, Express.js backend, and shared libraries.

#### Initial Workspace Creation
```bash
# Create workspace
npx create-nx-workspace@latest ecommerce-workspace \
  --preset=react \
  --bundler=vite \
  --style=scss \
  --packageManager=npm \
  --nx-cloud=true

cd ecommerce-workspace

# Install additional dependencies
npm install -D @nx/express @nx/node @nx/storybook
npm install express cors helmet morgan bcryptjs jsonwebtoken
npm install -D @types/express @types/cors @types/morgan @types/bcryptjs @types/jsonwebtoken
```

#### Generate Projects Structure
```bash
# Generate frontend application
nx g @nx/react:app customer-portal --bundler=vite --routing=true --style=scss

# Generate admin dashboard
nx g @nx/react:app admin-dashboard --bundler=vite --routing=true --style=scss

# Generate API server
nx g @nx/express:app api-server --frontendProject=customer-portal

# Generate shared libraries
nx g @nx/js:lib api-interfaces --bundler=tsc
nx g @nx/react:lib shared-ui --bundler=rollup
nx g @nx/js:lib shared-utils --bundler=tsc
nx g @nx/js:lib data-access-products --bundler=tsc
nx g @nx/js:lib data-access-auth --bundler=tsc
nx g @nx/react:lib feature-auth --bundler=rollup
nx g @nx/react:lib feature-products --bundler=rollup
```

#### Project Tags Configuration
```json
// Update project.json files with appropriate tags
// apps/customer-portal/project.json
{
  "name": "customer-portal",
  "tags": ["scope:customer", "type:app", "platform:web"]
}

// apps/admin-dashboard/project.json  
{
  "name": "admin-dashboard",
  "tags": ["scope:admin", "type:app", "platform:web"]
}

// apps/api-server/project.json
{
  "name": "api-server", 
  "tags": ["scope:api", "type:app", "platform:node"]
}

// libs/shared-ui/project.json
{
  "name": "shared-ui",
  "tags": ["scope:shared", "type:ui"]
}
```

## ⚛️ React Vite Application Templates

### Modern React App with TypeScript

#### App Structure
```tsx
// apps/customer-portal/src/app/app.tsx
import React, { Suspense } from 'react';
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { ReactQueryDevtools } from '@tanstack/react-query-devtools';
import { Toaster } from 'react-hot-toast';

import { AuthProvider } from '@ecommerce/feature-auth';
import { LoadingSpinner, Layout } from '@ecommerce/shared-ui';
import { HomePage } from './pages/home/home';
import { ProductsPage } from './pages/products/products';
import { CartPage } from './pages/cart/cart';
import { ProfilePage } from './pages/profile/profile';
import { ErrorBoundary } from './components/error-boundary';

// Create QueryClient instance
const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      retry: 1,
      refetchOnWindowFocus: false,
      staleTime: 5 * 60 * 1000, // 5 minutes
    },
  },
});

export function App() {
  return (
    <ErrorBoundary>
      <QueryClientProvider client={queryClient}>
        <AuthProvider>
          <Router>
            <Layout>
              <Suspense fallback={<LoadingSpinner />}>
                <Routes>
                  <Route path="/" element={<HomePage />} />
                  <Route path="/products/*" element={<ProductsPage />} />
                  <Route path="/cart" element={<CartPage />} />
                  <Route path="/profile/*" element={<ProfilePage />} />
                </Routes>
              </Suspense>
            </Layout>
            <Toaster position="top-right" />
          </Router>
        </AuthProvider>
        <ReactQueryDevtools initialIsOpen={false} />
      </QueryClientProvider>
    </ErrorBoundary>
  );
}

export default App;
```

#### Error Boundary Component
```tsx
// apps/customer-portal/src/app/components/error-boundary.tsx
import React, { Component, ReactNode } from 'react';
import { Button } from '@ecommerce/shared-ui';

interface Props {
  children: ReactNode;
}

interface State {
  hasError: boolean;
  error?: Error;
}

export class ErrorBoundary extends Component<Props, State> {
  constructor(props: Props) {
    super(props);
    this.state = { hasError: false };
  }

  static getDerivedStateFromError(error: Error): State {
    return { hasError: true, error };
  }

  componentDidCatch(error: Error, errorInfo: React.ErrorInfo) {
    console.error('Error caught by boundary:', error, errorInfo);
    // You can also log the error to an error reporting service
  }

  render() {
    if (this.state.hasError) {
      return (
        <div className="error-boundary">
          <div className="error-content">
            <h2>Something went wrong</h2>
            <p>We're sorry for the inconvenience. Please try refreshing the page.</p>
            <details>
              <summary>Error Details</summary>
              <pre>{this.state.error?.message}</pre>
            </details>
            <Button onClick={() => window.location.reload()}>
              Refresh Page
            </Button>
          </div>
        </div>
      );
    }

    return this.props.children;
  }
}
```

#### Products Page with React Query
```tsx
// apps/customer-portal/src/app/pages/products/products.tsx
import React, { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { ProductCard, Pagination, LoadingSpinner, ErrorMessage } from '@ecommerce/shared-ui';
import { useProducts } from '@ecommerce/data-access-products';
import { Product, ProductFilters } from '@ecommerce/api-interfaces';

export function ProductsPage() {
  const [filters, setFilters] = useState<ProductFilters>({
    page: 1,
    limit: 12,
    category: '',
    priceRange: { min: 0, max: 1000 },
    sortBy: 'name',
    sortOrder: 'asc'
  });

  const {
    data: productsResponse,
    isLoading,
    error,
    isError
  } = useQuery({
    queryKey: ['products', filters],
    queryFn: () => useProducts.getProducts(filters),
    keepPreviousData: true,
  });

  const handleFilterChange = (newFilters: Partial<ProductFilters>) => {
    setFilters(prev => ({ ...prev, ...newFilters, page: 1 }));
  };

  const handlePageChange = (page: number) => {
    setFilters(prev => ({ ...prev, page }));
  };

  if (isLoading) {
    return <LoadingSpinner />;
  }

  if (isError) {
    return (
      <ErrorMessage
        title="Failed to load products"
        message={error instanceof Error ? error.message : 'Unknown error'}
        onRetry={() => window.location.reload()}
      />
    );
  }

  const { products, pagination } = productsResponse || { products: [], pagination: null };

  return (
    <div className="products-page">
      <div className="products-header">
        <h1>Products</h1>
        <ProductFilters
          filters={filters}
          onFiltersChange={handleFilterChange}
        />
      </div>
      
      <div className="products-grid">
        {products.map((product: Product) => (
          <ProductCard
            key={product.id}
            product={product}
            onAddToCart={(productId) => {
              // Handle add to cart
              console.log('Add to cart:', productId);
            }}
          />
        ))}
      </div>

      {pagination && (
        <Pagination
          currentPage={pagination.page}
          totalPages={pagination.totalPages}
          onPageChange={handlePageChange}
        />
      )}
    </div>
  );
}
```

#### Optimized Vite Configuration
```typescript
// apps/customer-portal/vite.config.ts
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { nxViteTsPaths } from '@nx/vite/plugins/nx-tsconfig-paths.plugin';
import { resolve } from 'path';

export default defineConfig({
  root: __dirname,
  cacheDir: '../../node_modules/.vite/apps/customer-portal',
  
  server: {
    port: 4200,
    host: 'localhost',
    proxy: {
      '/api': {
        target: 'http://localhost:3000',
        changeOrigin: true,
        secure: false,
      },
    },
  },

  preview: {
    port: 4300,
    host: 'localhost',
  },

  plugins: [
    react({
      fastRefresh: true,
      babel: {
        plugins: [
          ['@babel/plugin-transform-react-jsx', { runtime: 'automatic' }]
        ],
      },
    }),
    nxViteTsPaths(),
  ],

  build: {
    outDir: '../../dist/apps/customer-portal',
    reportCompressedSize: true,
    sourcemap: false,
    rollupOptions: {
      output: {
        manualChunks: {
          vendor: ['react', 'react-dom'],
          router: ['react-router-dom'],
          query: ['@tanstack/react-query'],
        },
      },
    },
  },

  define: {
    __APP_VERSION__: JSON.stringify(process.env.npm_package_version),
    __DEV__: process.env.NODE_ENV === 'development',
  },

  css: {
    preprocessorOptions: {
      scss: {
        additionalData: `
          @import "${resolve(__dirname, 'src/styles/_variables.scss')}";
          @import "${resolve(__dirname, 'src/styles/_mixins.scss')}";
        `,
      },
    },
  },

  optimizeDeps: {
    include: ['react', 'react-dom', 'react-router-dom', '@tanstack/react-query'],
  },
});
```

## 🖥️ Express.js API Templates

### RESTful API with TypeScript

#### Main Application Setup
```typescript
// apps/api-server/src/main.ts
import { app } from './app/app';
import { connectDatabase } from './app/database';
import { logger } from './app/utils/logger';

const port = process.env['PORT'] || 3000;
const host = process.env['HOST'] || 'localhost';

async function bootstrap() {
  try {
    // Connect to database
    await connectDatabase();
    logger.info('Database connected successfully');

    // Start server
    const server = app.listen(port, host, () => {
      logger.info(`🚀 Server ready at http://${host}:${port}`);
    });

    // Graceful shutdown
    process.on('SIGTERM', () => {
      logger.info('SIGTERM received, shutting down gracefully');
      server.close(() => {
        logger.info('Server closed');
        process.exit(0);
      });
    });

    process.on('SIGINT', () => {
      logger.info('SIGINT received, shutting down gracefully');
      server.close(() => {
        logger.info('Server closed');
        process.exit(0);
      });
    });

  } catch (error) {
    logger.error('Failed to start server:', error);
    process.exit(1);
  }
}

bootstrap();
```

#### Express App Configuration
```typescript
// apps/api-server/src/app/app.ts
import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import compression from 'compression';
import rateLimit from 'express-rate-limit';
import { config } from './config';
import { logger } from './utils/logger';

// Route imports
import authRoutes from './routes/auth.routes';
import userRoutes from './routes/user.routes';
import productRoutes from './routes/product.routes';
import orderRoutes from './routes/order.routes';

// Middleware imports
import { errorHandler } from './middleware/error-handler';
import { notFoundHandler } from './middleware/not-found-handler';
import { requestLogger } from './middleware/request-logger';
import { authenticate } from './middleware/auth.middleware';

const app = express();

// Trust proxy for rate limiting behind reverse proxy
app.set('trust proxy', 1);

// Security middleware
app.use(helmet({
  crossOriginResourcePolicy: { policy: 'cross-origin' },
}));

app.use(cors({
  origin: config.cors.origin,
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // limit each IP to 100 requests per windowMs
  message: {
    error: 'Too many requests from this IP, please try again later.',
  },
  standardHeaders: true,
  legacyHeaders: false,
});

app.use('/api', limiter);

// General middleware
app.use(compression());
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Logging
app.use(morgan('combined', { stream: { write: (msg) => logger.info(msg.trim()) } }));
app.use(requestLogger);

// Health check
app.get('/health', (req, res) => {
  res.json({
    status: 'OK',
    timestamp: new Date().toISOString(),
    uptime: Math.floor(process.uptime()),
    version: process.env['npm_package_version'] || '1.0.0',
  });
});

// API routes
app.use('/api/auth', authRoutes);
app.use('/api/users', authenticate, userRoutes);
app.use('/api/products', productRoutes);
app.use('/api/orders', authenticate, orderRoutes);

// Error handling
app.use(notFoundHandler);
app.use(errorHandler);

export { app };
```

#### User Routes with Validation
```typescript
// apps/api-server/src/app/routes/user.routes.ts
import { Router } from 'express';
import { userController } from '../controllers/user.controller';
import { validateRequest } from '../middleware/validate-request';
import { authorize } from '../middleware/authorize.middleware';
import { createUserSchema, updateUserSchema, getUsersQuerySchema } from '../schemas/user.schema';
import { UserRole } from '@ecommerce/api-interfaces';

const router = Router();

// GET /api/users - Get all users (admin only)
router.get(
  '/',
  authorize([UserRole.ADMIN]),
  validateRequest({ query: getUsersQuerySchema }),
  userController.getUsers
);

// GET /api/users/:id - Get user by ID
router.get('/:id', userController.getUserById);

// POST /api/users - Create new user (admin only)
router.post(
  '/',
  authorize([UserRole.ADMIN]),
  validateRequest({ body: createUserSchema }),
  userController.createUser
);

// PUT /api/users/:id - Update user
router.put(
  '/:id',
  validateRequest({ body: updateUserSchema }),
  userController.updateUser
);

// DELETE /api/users/:id - Delete user (admin only)
router.delete(
  '/:id',
  authorize([UserRole.ADMIN]),
  userController.deleteUser
);

// GET /api/users/profile/me - Get current user profile
router.get('/profile/me', userController.getCurrentUser);

// PUT /api/users/profile/me - Update current user profile
router.put(
  '/profile/me',
  validateRequest({ body: updateUserSchema }),
  userController.updateCurrentUser
);

export default router;
```

#### Controller with Error Handling
```typescript
// apps/api-server/src/app/controllers/user.controller.ts
import { Request, Response, NextFunction } from 'express';
import { userService } from '../services/user.service';
import { 
  CreateUserRequest, 
  UpdateUserRequest, 
  User, 
  ApiResponse,
  PaginatedResponse 
} from '@ecommerce/api-interfaces';
import { asyncHandler } from '../utils/async-handler';
import { AppError } from '../utils/app-error';
import { logger } from '../utils/logger';

class UserController {
  getUsers = asyncHandler(async (req: Request, res: Response) => {
    const { page = 1, limit = 10, search, role } = req.query;
    
    const result = await userService.getUsers({
      page: Number(page),
      limit: Number(limit),
      search: search as string,
      role: role as string,
    });

    const response: PaginatedResponse<User> = {
      success: true,
      data: result.users,
      pagination: result.pagination,
      message: 'Users retrieved successfully',
    };

    res.json(response);
  });

  getUserById = asyncHandler(async (req: Request, res: Response) => {
    const { id } = req.params;
    const user = await userService.getUserById(Number(id));

    if (!user) {
      throw new AppError('User not found', 404);
    }

    const response: ApiResponse<User> = {
      success: true,
      data: user,
      message: 'User retrieved successfully',
    };

    res.json(response);
  });

  createUser = asyncHandler(async (req: Request<{}, {}, CreateUserRequest>, res: Response) => {
    const userData = req.body;
    const user = await userService.createUser(userData);

    logger.info(`User created: ${user.email}`, { userId: user.id });

    const response: ApiResponse<User> = {
      success: true,
      data: user,
      message: 'User created successfully',
    };

    res.status(201).json(response);
  });

  updateUser = asyncHandler(async (req: Request<{ id: string }, {}, UpdateUserRequest>, res: Response) => {
    const { id } = req.params;
    const updateData = req.body;
    
    const user = await userService.updateUser(Number(id), updateData);
    
    logger.info(`User updated: ${user.email}`, { userId: user.id });

    const response: ApiResponse<User> = {
      success: true,
      data: user,
      message: 'User updated successfully',
    };

    res.json(response);
  });

  deleteUser = asyncHandler(async (req: Request, res: Response) => {
    const { id } = req.params;
    await userService.deleteUser(Number(id));

    logger.info(`User deleted: ${id}`);

    const response: ApiResponse<null> = {
      success: true,
      data: null,
      message: 'User deleted successfully',
    };

    res.json(response);
  });

  getCurrentUser = asyncHandler(async (req: Request, res: Response) => {
    // User is attached to request by auth middleware
    const userId = (req as any).user?.id;
    const user = await userService.getUserById(userId);

    if (!user) {
      throw new AppError('User not found', 404);
    }

    const response: ApiResponse<User> = {
      success: true,
      data: user,
      message: 'Current user retrieved successfully',
    };

    res.json(response);
  });

  updateCurrentUser = asyncHandler(async (req: Request<{}, {}, UpdateUserRequest>, res: Response) => {
    const userId = (req as any).user?.id;
    const updateData = req.body;
    
    const user = await userService.updateUser(userId, updateData);

    const response: ApiResponse<User> = {
      success: true,
      data: user,
      message: 'Profile updated successfully',
    };

    res.json(response);
  });
}

export const userController = new UserController();
```

#### Service Layer with Repository Pattern
```typescript
// apps/api-server/src/app/services/user.service.ts
import { User, CreateUserRequest, UpdateUserRequest } from '@ecommerce/api-interfaces';
import { userRepository } from '../repositories/user.repository';
import { hashPassword } from '@ecommerce/shared-utils';
import { AppError } from '../utils/app-error';
import { logger } from '../utils/logger';

interface GetUsersOptions {
  page: number;
  limit: number;
  search?: string;
  role?: string;
}

interface GetUsersResult {
  users: User[];
  pagination: {
    page: number;
    limit: number;
    total: number;
    totalPages: number;
  };
}

class UserService {
  async getUsers(options: GetUsersOptions): Promise<GetUsersResult> {
    const { page, limit, search, role } = options;
    
    const offset = (page - 1) * limit;
    
    const { users, total } = await userRepository.findMany({
      offset,
      limit,
      search,
      role,
    });

    return {
      users,
      pagination: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
      },
    };
  }

  async getUserById(id: number): Promise<User | null> {
    return userRepository.findById(id);
  }

  async getUserByEmail(email: string): Promise<User | null> {
    return userRepository.findByEmail(email);
  }

  async createUser(userData: CreateUserRequest): Promise<User> {
    // Check if user already exists
    const existingUser = await this.getUserByEmail(userData.email);
    if (existingUser) {
      throw new AppError('User with this email already exists', 400);
    }

    // Hash password
    const hashedPassword = await hashPassword(userData.password);
    
    const userToCreate = {
      ...userData,
      password: hashedPassword,
    };

    const user = await userRepository.create(userToCreate);
    logger.info(`New user created: ${user.email}`, { userId: user.id });
    
    return user;
  }

  async updateUser(id: number, updateData: UpdateUserRequest): Promise<User> {
    const existingUser = await this.getUserById(id);
    if (!existingUser) {
      throw new AppError('User not found', 404);
    }

    // If email is being updated, check for conflicts
    if (updateData.email && updateData.email !== existingUser.email) {
      const emailExists = await this.getUserByEmail(updateData.email);
      if (emailExists) {
        throw new AppError('Email is already in use', 400);
      }
    }

    // Hash password if provided
    if (updateData.password) {
      updateData.password = await hashPassword(updateData.password);
    }

    const updatedUser = await userRepository.update(id, updateData);
    logger.info(`User updated: ${updatedUser.email}`, { userId: id });
    
    return updatedUser;
  }

  async deleteUser(id: number): Promise<void> {
    const user = await this.getUserById(id);
    if (!user) {
      throw new AppError('User not found', 404);
    }

    await userRepository.delete(id);
    logger.info(`User deleted: ${user.email}`, { userId: id });
  }

  async changePassword(id: number, oldPassword: string, newPassword: string): Promise<void> {
    const user = await userRepository.findByIdWithPassword(id);
    if (!user) {
      throw new AppError('User not found', 404);
    }

    // Verify old password (implementation depends on your auth strategy)
    // const isValidPassword = await verifyPassword(oldPassword, user.password);
    // if (!isValidPassword) {
    //   throw new AppError('Invalid old password', 400);
    // }

    const hashedNewPassword = await hashPassword(newPassword);
    await userRepository.updatePassword(id, hashedNewPassword);
    
    logger.info(`Password changed for user: ${user.email}`, { userId: id });
  }
}

export const userService = new UserService();
```

## 📚 Shared Library Templates

### API Interfaces Library

#### Base Interfaces
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
  errors?: Record<string, string[]>;
}

export interface PaginatedResponse<T> extends Omit<ApiResponse<T[]>, 'data'> {
  data: T[];
  pagination: {
    page: number;
    limit: number;
    total: number;
    totalPages: number;
    hasNextPage: boolean;
    hasPreviousPage: boolean;
  };
}

export interface QueryOptions {
  page?: number;
  limit?: number;
  sortBy?: string;
  sortOrder?: 'asc' | 'desc';
  search?: string;
}
```

#### User Interfaces
```typescript
// libs/api-interfaces/src/lib/user.interface.ts
import { BaseEntity } from './base.interface';

export enum UserRole {
  ADMIN = 'admin',
  CUSTOMER = 'customer',
  MODERATOR = 'moderator'
}

export enum UserStatus {
  ACTIVE = 'active',
  INACTIVE = 'inactive',
  SUSPENDED = 'suspended'
}

export interface User extends BaseEntity {
  email: string;
  username: string;
  firstName: string;
  lastName: string;
  avatar?: string;
  role: UserRole;
  status: UserStatus;
  lastLoginAt?: Date;
  emailVerifiedAt?: Date;
  preferences: UserPreferences;
}

export interface UserPreferences {
  theme: 'light' | 'dark' | 'system';
  language: string;
  timezone: string;
  notifications: {
    email: boolean;
    push: boolean;
    marketing: boolean;
  };
}

export interface CreateUserRequest {
  email: string;
  username: string;
  firstName: string;
  lastName: string;
  password: string;
  role?: UserRole;
}

export interface UpdateUserRequest {
  email?: string;
  username?: string;
  firstName?: string;
  lastName?: string;
  avatar?: string;
  preferences?: Partial<UserPreferences>;
}

export interface LoginRequest {
  email: string;
  password: string;
  rememberMe?: boolean;
}

export interface LoginResponse {
  user: Omit<User, 'password'>;
  accessToken: string;
  refreshToken: string;
  expiresIn: number;
}

export interface RefreshTokenRequest {
  refreshToken: string;
}

export interface ChangePasswordRequest {
  oldPassword: string;
  newPassword: string;
  confirmPassword: string;
}
```

#### Product Interfaces
```typescript
// libs/api-interfaces/src/lib/product.interface.ts
import { BaseEntity, QueryOptions } from './base.interface';

export enum ProductStatus {
  ACTIVE = 'active',
  INACTIVE = 'inactive',
  OUT_OF_STOCK = 'out_of_stock',
  DISCONTINUED = 'discontinued'
}

export interface Product extends BaseEntity {
  name: string;
  description: string;
  sku: string;
  price: number;
  salePrice?: number;
  category: ProductCategory;
  images: ProductImage[];
  stock: number;
  status: ProductStatus;
  tags: string[];
  attributes: ProductAttribute[];
  seo: ProductSEO;
}

export interface ProductCategory extends BaseEntity {
  name: string;
  slug: string;
  description?: string;
  parentId?: number;
  imageUrl?: string;
}

export interface ProductImage {
  id: number;
  url: string;
  alt: string;
  isPrimary: boolean;
  order: number;
}

export interface ProductAttribute {
  name: string;
  value: string;
  type: 'text' | 'number' | 'boolean' | 'select';
}

export interface ProductSEO {
  title?: string;
  description?: string;
  keywords?: string[];
}

export interface ProductFilters extends QueryOptions {
  category?: string;
  priceMin?: number;
  priceMax?: number;
  status?: ProductStatus;
  inStock?: boolean;
  tags?: string[];
}

export interface CreateProductRequest {
  name: string;
  description: string;
  sku: string;
  price: number;
  salePrice?: number;
  categoryId: number;
  images: Omit<ProductImage, 'id'>[];
  stock: number;
  tags: string[];
  attributes: ProductAttribute[];
  seo: ProductSEO;
}

export interface UpdateProductRequest extends Partial<CreateProductRequest> {
  status?: ProductStatus;
}
```

### Shared UI Component Library

#### Button Component with Variants
```tsx
// libs/shared-ui/src/lib/button/button.tsx
import React, { forwardRef } from 'react';
import { clsx } from 'clsx';
import './button.scss';

export type ButtonVariant = 'primary' | 'secondary' | 'outline' | 'ghost' | 'danger';
export type ButtonSize = 'xs' | 'sm' | 'md' | 'lg' | 'xl';

export interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: ButtonVariant;
  size?: ButtonSize;
  loading?: boolean;
  leftIcon?: React.ReactNode;
  rightIcon?: React.ReactNode;
  fullWidth?: boolean;
  children: React.ReactNode;
}

export const Button = forwardRef<HTMLButtonElement, ButtonProps>(
  ({
    variant = 'primary',
    size = 'md',
    loading = false,
    leftIcon,
    rightIcon,
    fullWidth = false,
    disabled,
    className,
    children,
    ...props
  }, ref) => {
    const isDisabled = disabled || loading;

    return (
      <button
        ref={ref}
        className={clsx(
          'btn',
          `btn--${variant}`,
          `btn--${size}`,
          {
            'btn--loading': loading,
            'btn--full-width': fullWidth,
          },
          className
        )}
        disabled={isDisabled}
        {...props}
      >
        {loading && <span className="btn__spinner" />}
        {leftIcon && !loading && <span className="btn__left-icon">{leftIcon}</span>}
        <span className="btn__text">{children}</span>
        {rightIcon && !loading && <span className="btn__right-icon">{rightIcon}</span>}
      </button>
    );
  }
);

Button.displayName = 'Button';
```

#### Modal Component with Portal
```tsx
// libs/shared-ui/src/lib/modal/modal.tsx
import React, { useEffect, useRef } from 'react';
import { createPortal } from 'react-dom';
import { clsx } from 'clsx';
import { X } from 'lucide-react';
import { Button } from '../button/button';
import './modal.scss';

export interface ModalProps {
  isOpen: boolean;
  onClose: () => void;
  title?: string;
  children: React.ReactNode;
  size?: 'sm' | 'md' | 'lg' | 'xl' | 'full';
  closeOnOverlayClick?: boolean;
  closeOnEscape?: boolean;
  showCloseButton?: boolean;
  className?: string;
}

export function Modal({
  isOpen,
  onClose,
  title,
  children,
  size = 'md',
  closeOnOverlayClick = true,
  closeOnEscape = true,
  showCloseButton = true,
  className
}: ModalProps) {
  const modalRef = useRef<HTMLDivElement>(null);
  const previousActiveElement = useRef<HTMLElement | null>(null);

  useEffect(() => {
    if (isOpen) {
      // Store previously focused element
      previousActiveElement.current = document.activeElement as HTMLElement;
      
      // Focus modal
      modalRef.current?.focus();
      
      // Prevent body scroll
      document.body.style.overflow = 'hidden';
    } else {
      // Restore body scroll
      document.body.style.overflow = '';
      
      // Restore focus
      previousActiveElement.current?.focus();
    }

    return () => {
      document.body.style.overflow = '';
    };
  }, [isOpen]);

  useEffect(() => {
    const handleEscape = (event: KeyboardEvent) => {
      if (event.key === 'Escape' && closeOnEscape) {
        onClose();
      }
    };

    if (isOpen) {
      document.addEventListener('keydown', handleEscape);
    }

    return () => {
      document.removeEventListener('keydown', handleEscape);
    };
  }, [isOpen, closeOnEscape, onClose]);

  const handleOverlayClick = (event: React.MouseEvent) => {
    if (event.target === event.currentTarget && closeOnOverlayClick) {
      onClose();
    }
  };

  if (!isOpen) {
    return null;
  }

  const modalContent = (
    <div className="modal-overlay" onClick={handleOverlayClick}>
      <div
        ref={modalRef}
        className={clsx('modal', `modal--${size}`, className)}
        role="dialog"
        aria-modal="true"
        aria-labelledby={title ? 'modal-title' : undefined}
        tabIndex={-1}
      >
        {(title || showCloseButton) && (
          <div className="modal__header">
            {title && (
              <h2 id="modal-title" className="modal__title">
                {title}
              </h2>
            )}
            {showCloseButton && (
              <Button
                variant="ghost"
                size="sm"
                onClick={onClose}
                className="modal__close"
                aria-label="Close modal"
              >
                <X size={20} />
              </Button>
            )}
          </div>
        )}
        <div className="modal__content">
          {children}
        </div>
      </div>
    </div>
  );

  return createPortal(modalContent, document.body);
}
```

### Data Access Library

#### API Client with Interceptors
```typescript
// libs/data-access-products/src/lib/api-client.ts
import { ApiResponse } from '@ecommerce/api-interfaces';

export interface RequestConfig extends RequestInit {
  timeout?: number;
}

export class ApiClient {
  private baseURL: string;
  private defaultTimeout: number = 10000;

  constructor(baseURL: string = '/api') {
    this.baseURL = baseURL;
  }

  private async request<T>(
    endpoint: string,
    config: RequestConfig = {}
  ): Promise<ApiResponse<T>> {
    const { timeout = this.defaultTimeout, ...requestConfig } = config;
    
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), timeout);

    const url = `${this.baseURL}${endpoint}`;
    const token = this.getAuthToken();

    const headers = {
      'Content-Type': 'application/json',
      ...(token && { Authorization: `Bearer ${token}` }),
      ...requestConfig.headers,
    };

    try {
      const response = await fetch(url, {
        ...requestConfig,
        headers,
        signal: controller.signal,
      });

      clearTimeout(timeoutId);

      if (!response.ok) {
        throw new ApiError(
          response.statusText,
          response.status,
          await this.parseErrorResponse(response)
        );
      }

      const data = await response.json();
      return data;
    } catch (error) {
      clearTimeout(timeoutId);
      
      if (error instanceof ApiError) {
        throw error;
      }
      
      if (error.name === 'AbortError') {
        throw new ApiError('Request timeout', 408);
      }
      
      throw new ApiError('Network error', 0, error.message);
    }
  }

  private getAuthToken(): string | null {
    return localStorage.getItem('auth_token');
  }

  private async parseErrorResponse(response: Response) {
    try {
      const errorData = await response.json();
      return errorData.message || errorData.error || 'An error occurred';
    } catch {
      return response.statusText;
    }
  }

  async get<T>(endpoint: string, config?: RequestConfig): Promise<ApiResponse<T>> {
    return this.request<T>(endpoint, { ...config, method: 'GET' });
  }

  async post<T>(
    endpoint: string,
    data?: unknown,
    config?: RequestConfig
  ): Promise<ApiResponse<T>> {
    return this.request<T>(endpoint, {
      ...config,
      method: 'POST',
      body: data ? JSON.stringify(data) : undefined,
    });
  }

  async put<T>(
    endpoint: string,
    data?: unknown,
    config?: RequestConfig
  ): Promise<ApiResponse<T>> {
    return this.request<T>(endpoint, {
      ...config,
      method: 'PUT',
      body: data ? JSON.stringify(data) : undefined,
    });
  }

  async delete<T>(endpoint: string, config?: RequestConfig): Promise<ApiResponse<T>> {
    return this.request<T>(endpoint, { ...config, method: 'DELETE' });
  }
}

export class ApiError extends Error {
  constructor(
    message: string,
    public status: number,
    public details?: string
  ) {
    super(message);
    this.name = 'ApiError';
  }
}

export const apiClient = new ApiClient();
```

#### Products Service with React Query Integration
```typescript
// libs/data-access-products/src/lib/products.service.ts
import { 
  Product, 
  CreateProductRequest, 
  UpdateProductRequest, 
  ProductFilters,
  PaginatedResponse,
  ApiResponse 
} from '@ecommerce/api-interfaces';
import { apiClient } from './api-client';

class ProductsService {
  async getProducts(filters: ProductFilters = {}): Promise<PaginatedResponse<Product>> {
    const queryParams = new URLSearchParams();
    
    Object.entries(filters).forEach(([key, value]) => {
      if (value !== undefined && value !== null && value !== '') {
        queryParams.append(key, String(value));
      }
    });

    const queryString = queryParams.toString();
    const endpoint = `/products${queryString ? `?${queryString}` : ''}`;
    
    return apiClient.get<Product[]>(endpoint);
  }

  async getProductById(id: number): Promise<ApiResponse<Product>> {
    return apiClient.get<Product>(`/products/${id}`);
  }

  async createProduct(data: CreateProductRequest): Promise<ApiResponse<Product>> {
    return apiClient.post<Product>('/products', data);
  }

  async updateProduct(id: number, data: UpdateProductRequest): Promise<ApiResponse<Product>> {
    return apiClient.put<Product>(`/products/${id}`, data);
  }

  async deleteProduct(id: number): Promise<ApiResponse<null>> {
    return apiClient.delete<null>(`/products/${id}`);
  }

  async getProductsByCategory(categoryId: number): Promise<ApiResponse<Product[]>> {
    return apiClient.get<Product[]>(`/products?category=${categoryId}`);
  }

  async searchProducts(query: string): Promise<ApiResponse<Product[]>> {
    return apiClient.get<Product[]>(`/products/search?q=${encodeURIComponent(query)}`);
  }
}

export const productsService = new ProductsService();
```

This comprehensive template collection provides working examples for all major components of an Nx workspace, from React applications to Express.js APIs and shared libraries. Use these templates as starting points and customize them according to your specific requirements.

---

**Previous**: [← CLI Commands Reference](./cli-commands-reference.md) | **Next**: [Troubleshooting Guide →](./troubleshooting.md)