# Best Practices: Nx Managed Deployment

## 🎯 Overview

This document outlines production-ready best practices for deploying Nx monorepo projects to managed cloud platforms, focusing on performance, security, maintainability, and client handover optimization.

---

## 🏗️ Architecture Best Practices

### Monorepo Organization

#### Optimal Directory Structure
```
nx-workspace/
├── apps/
│   ├── web/                   # React frontend
│   ├── api/                   # Express.js backend
│   ├── admin/                 # Admin dashboard (optional)
│   └── mobile/                # React Native app (future)
├── libs/
│   ├── shared/
│   │   ├── types/             # TypeScript interfaces
│   │   ├── utils/             # Common utilities
│   │   ├── constants/         # Application constants
│   │   └── validation/        # Schema validation
│   ├── ui/
│   │   ├── components/        # Reusable UI components
│   │   └── themes/            # Styling and themes
│   └── data-access/
│       ├── api/               # API client logic
│       └── database/          # Database utilities
├── tools/
│   ├── deployment/            # Custom deployment scripts
│   ├── testing/               # Test utilities
│   └── generators/            # Custom Nx generators
└── docs/
    ├── deployment/            # Deployment documentation
    └── api/                   # API documentation
```

#### Library Boundaries and Dependencies
```typescript
// nx.json - Enforce proper dependency boundaries
{
  "namedInputs": {
    "default": ["{projectRoot}/**/*", "sharedGlobals"],
    "production": ["default", "!{projectRoot}/**/?(*.)+(spec|test).[jt]s?(x)?(.snap)", "!{projectRoot}/tsconfig.spec.json", "!{projectRoot}/jest.config.[jt]s"]
  },
  "targetDefaults": {
    "build": {
      "dependsOn": ["^build"],
      "inputs": ["production", "^production"]
    }
  },
  "generators": {
    "@nrwl/angular:application": {
      "style": "scss",
      "linter": "eslint",
      "unitTestRunner": "jest",
      "e2eTestRunner": "cypress"
    }
  }
}
```

#### Tagging Strategy
```json
// project.json tagging for better organization
{
  "name": "web",
  "tags": ["scope:web", "type:app", "platform:browser"],
  "targets": {...}
}

{
  "name": "api", 
  "tags": ["scope:api", "type:app", "platform:node"],
  "targets": {...}
}

{
  "name": "shared-types",
  "tags": ["scope:shared", "type:lib", "platform:universal"],
  "targets": {...}
}
```

### Service Separation Strategy

#### Frontend-Backend Separation (Recommended)
```yaml
# Advantages:
# - Independent scaling
# - Technology flexibility
# - Easier maintenance
# - Better security isolation

Frontend Service:
  - Static site deployment
  - CDN optimization
  - Client-side routing
  - Environment-specific builds

Backend Service:
  - API-only deployment
  - Database connections
  - Authentication logic
  - File uploads/processing
```

#### Monolithic Deployment (Simple Projects)
```yaml
# Use when:
# - Small teams (1-3 developers)
# - Simple applications
# - Limited deployment complexity requirements
# - Tight coupling between frontend/backend

Single Service:
  - Nx full-stack build
  - Express.js serves both API and static files
  - Simplified deployment process
  - Single domain/SSL certificate
```

---

## 🔧 Build Optimization

### Production Build Configuration

#### Frontend Build Optimization (Vite)
```typescript
// apps/web/vite.config.ts
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { resolve } from 'path';

export default defineConfig({
  plugins: [react()],
  build: {
    target: 'es2015',
    outDir: '../../dist/apps/web',
    rollupOptions: {
      output: {
        manualChunks: {
          // Vendor chunks for better caching
          vendor: ['react', 'react-dom'],
          router: ['react-router-dom'],
          ui: ['@mui/material', '@emotion/react'],
          utils: ['lodash', 'date-fns']
        },
        // Consistent chunk naming
        chunkFileNames: 'assets/js/[name]-[hash].js',
        entryFileNames: 'assets/js/[name]-[hash].js',
        assetFileNames: 'assets/[ext]/[name]-[hash].[ext]'
      }
    },
    // Bundle analysis
    reportCompressedSize: true,
    chunkSizeWarningLimit: 1000
  },
  // Development optimizations
  server: {
    proxy: {
      '/api': {
        target: 'http://localhost:3333',
        changeOrigin: true,
        secure: false
      }
    }
  }
});
```

#### Backend Build Optimization (Webpack)
```typescript
// apps/api/webpack.config.js
const { composePlugins, withNx } = require('@nrwl/webpack');

module.exports = composePlugins(withNx(), (config) => {
  // Production optimizations
  if (process.env.NODE_ENV === 'production') {
    config.optimization = {
      ...config.optimization,
      minimize: true,
      usedExports: true,
      sideEffects: false
    };
    
    // External dependencies (don't bundle)
    config.externals = {
      'express': 'commonjs express',
      'pg': 'commonjs pg',
      'bcryptjs': 'commonjs bcryptjs'
    };
  }

  return config;
});
```

#### Nx Project Configuration
```json
// apps/web/project.json
{
  "targets": {
    "build": {
      "executor": "@nrwl/vite:build",
      "outputs": ["{options.outputPath}"],
      "options": {
        "outputPath": "dist/apps/web"
      },
      "configurations": {
        "production": {
          "fileReplacements": [
            {
              "replace": "apps/web/src/environments/environment.ts",
              "with": "apps/web/src/environments/environment.prod.ts"
            }
          ],
          "optimization": true,
          "outputHashing": "all",
          "sourceMap": false,
          "namedChunks": false,
          "extractLicenses": true,
          "vendorChunk": false,
          "budgets": [
            {
              "type": "initial",
              "maximumWarning": "500kb",
              "maximumError": "1mb"
            },
            {
              "type": "anyComponentStyle",
              "maximumWarning": "2kb",
              "maximumError": "4kb"
            }
          ]
        }
      }
    }
  }
}
```

### Environment Management

#### Environment File Structure
```
environments/
├── environment.ts                 # Development
├── environment.prod.ts           # Production
├── environment.staging.ts        # Staging
└── environment.local.ts          # Local development
```

#### Type-Safe Environment Configuration
```typescript
// libs/shared/config/src/lib/environment.ts
export interface Environment {
  production: boolean;
  apiUrl: string;
  databaseUrl: string;
  jwtSecret: string;
  corsOrigins: string[];
  logLevel: 'error' | 'warn' | 'info' | 'debug';
  features: {
    authentication: boolean;
    fileUploads: boolean;
    analytics: boolean;
  };
}

// Environment validation
import { z } from 'zod';

const EnvironmentSchema = z.object({
  NODE_ENV: z.enum(['development', 'production', 'staging']),
  API_URL: z.string().url(),
  DATABASE_URL: z.string().url(),
  JWT_SECRET: z.string().min(32),
  LOG_LEVEL: z.enum(['error', 'warn', 'info', 'debug']).default('info')
});

export const validateEnvironment = () => {
  try {
    return EnvironmentSchema.parse(process.env);
  } catch (error) {
    console.error('Environment validation failed:', error);
    process.exit(1);
  }
};
```

#### Platform-Specific Environment Handling
```typescript
// apps/api/src/main.ts
import { validateEnvironment } from '@myapp/shared/config';

// Validate environment on startup
const env = validateEnvironment();

// Platform-specific configuration
const config = {
  port: process.env.PORT || 3333,
  cors: {
    origin: process.env.CORS_ORIGINS?.split(',') || ['http://localhost:4200'],
    credentials: true
  },
  database: {
    url: process.env.DATABASE_URL,
    ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false
  }
};
```

---

## 🔒 Security Best Practices

### API Security

#### Authentication & Authorization
```typescript
// libs/shared/auth/src/lib/auth.middleware.ts
import jwt from 'jsonwebtoken';
import { Request, Response, NextFunction } from 'express';

export interface AuthenticatedRequest extends Request {
  user?: {
    id: string;
    email: string;
    roles: string[];
  };
}

export const authenticateToken = (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
) => {
  const authHeader = req.headers.authorization;
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ error: 'Access token required' });
  }

  jwt.verify(token, process.env.JWT_SECRET!, (err, decoded) => {
    if (err) {
      return res.status(403).json({ error: 'Invalid or expired token' });
    }
    
    req.user = decoded as any;
    next();
  });
};

// Role-based authorization
export const requireRole = (roles: string[]) => {
  return (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
    if (!req.user || !roles.some(role => req.user!.roles.includes(role))) {
      return res.status(403).json({ error: 'Insufficient permissions' });
    }
    next();
  };
};
```

#### Input Validation & Sanitization
```typescript
// libs/shared/validation/src/lib/schemas.ts
import { z } from 'zod';

export const CreateUserSchema = z.object({
  email: z.string().email().max(255),
  password: z.string().min(8).max(128).regex(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/),
  firstName: z.string().min(1).max(100).trim(),
  lastName: z.string().min(1).max(100).trim()
});

export const validateRequest = (schema: z.ZodSchema) => {
  return (req: Request, res: Response, next: NextFunction) => {
    try {
      req.body = schema.parse(req.body);
      next();
    } catch (error) {
      if (error instanceof z.ZodError) {
        return res.status(400).json({
          error: 'Validation failed',
          details: error.errors.map(err => ({
            field: err.path.join('.'),
            message: err.message
          }))
        });
      }
      next(error);
    }
  };
};
```

#### Security Headers & CORS
```typescript
// apps/api/src/main.ts
import helmet from 'helmet';
import cors from 'cors';
import rateLimit from 'express-rate-limit';

const app = express();

// Security headers
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      scriptSrc: ["'self'"],
      imgSrc: ["'self'", "data:", "https:"]
    }
  },
  hsts: {
    maxAge: 31536000,
    includeSubDomains: true,
    preload: true
  }
}));

// CORS configuration
const corsOptions = {
  origin: (origin: string | undefined, callback: Function) => {
    const allowedOrigins = process.env.CORS_ORIGINS?.split(',') || [];
    if (!origin || allowedOrigins.includes(origin)) {
      callback(null, true);
    } else {
      callback(new Error('Not allowed by CORS'));
    }
  },
  credentials: true,
  optionsSuccessStatus: 200
};

app.use(cors(corsOptions));

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // Limit each IP to 100 requests per windowMs
  message: 'Too many requests from this IP',
  standardHeaders: true,
  legacyHeaders: false
});

app.use('/api/', limiter);

// Stricter rate limiting for auth endpoints
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 5,
  skipSuccessfulRequests: true
});

app.use('/api/auth/login', authLimiter);
app.use('/api/auth/register', authLimiter);
```

### Frontend Security

#### Secure API Communication
```typescript
// libs/shared/api/src/lib/api-client.ts
import axios, { AxiosInstance, AxiosRequestConfig } from 'axios';

class ApiClient {
  private client: AxiosInstance;

  constructor(baseURL: string) {
    this.client = axios.create({
      baseURL,
      timeout: 10000,
      withCredentials: true,
      headers: {
        'Content-Type': 'application/json'
      }
    });

    // Request interceptor for auth tokens
    this.client.interceptors.request.use((config) => {
      const token = localStorage.getItem('accessToken');
      if (token) {
        config.headers.Authorization = `Bearer ${token}`;
      }
      return config;
    });

    // Response interceptor for error handling
    this.client.interceptors.response.use(
      (response) => response,
      async (error) => {
        if (error.response?.status === 401) {
          // Handle token refresh or redirect to login
          await this.refreshToken();
          return this.client.request(error.config);
        }
        return Promise.reject(error);
      }
    );
  }

  private async refreshToken() {
    try {
      const response = await this.client.post('/auth/refresh');
      const { accessToken } = response.data;
      localStorage.setItem('accessToken', accessToken);
    } catch (error) {
      // Redirect to login
      window.location.href = '/login';
    }
  }
}
```

#### Secure Token Storage
```typescript
// libs/shared/auth/src/lib/token-storage.ts
export class SecureTokenStorage {
  private static readonly ACCESS_TOKEN_KEY = 'accessToken';
  private static readonly REFRESH_TOKEN_KEY = 'refreshToken';

  static setTokens(accessToken: string, refreshToken: string) {
    // Use secure storage for production
    if (this.isSecureContext()) {
      this.setSecureCookie(this.ACCESS_TOKEN_KEY, accessToken, 15); // 15 minutes
      this.setSecureCookie(this.REFRESH_TOKEN_KEY, refreshToken, 7 * 24 * 60); // 7 days
    } else {
      // Fallback to localStorage for development
      localStorage.setItem(this.ACCESS_TOKEN_KEY, accessToken);
      localStorage.setItem(this.REFRESH_TOKEN_KEY, refreshToken);
    }
  }

  private static setSecureCookie(name: string, value: string, minutes: number) {
    const expires = new Date(Date.now() + minutes * 60 * 1000).toUTCString();
    document.cookie = `${name}=${value}; expires=${expires}; path=/; secure; samesite=strict; httponly`;
  }

  private static isSecureContext(): boolean {
    return window.isSecureContext && location.protocol === 'https:';
  }
}
```

---

## 📊 Performance Optimization

### Database Optimization

#### Connection Pooling
```typescript
// libs/shared/database/src/lib/connection.ts
import { Pool, PoolConfig } from 'pg';

const poolConfig: PoolConfig = {
  connectionString: process.env.DATABASE_URL,
  max: 20, // Maximum number of connections
  min: 5,  // Minimum number of connections
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
  acquireTimeoutMillis: 60000,
  // SSL configuration for production
  ssl: process.env.NODE_ENV === 'production' ? {
    rejectUnauthorized: false
  } : false
};

export const pool = new Pool(poolConfig);

// Graceful shutdown
process.on('SIGINT', async () => {
  console.log('Closing database connections...');
  await pool.end();
  process.exit(0);
});
```

#### Query Optimization
```typescript
// libs/shared/database/src/lib/queries.ts
import { pool } from './connection';

export class UserRepository {
  // Use prepared statements and indexing
  static async findByEmail(email: string) {
    const query = `
      SELECT id, email, first_name, last_name, created_at
      FROM users 
      WHERE email = $1 AND active = true
      LIMIT 1
    `;
    const result = await pool.query(query, [email]);
    return result.rows[0];
  }

  // Batch operations for better performance
  static async createUsers(users: Array<{email: string, firstName: string, lastName: string}>) {
    const values = users.map((_, index) => 
      `($${index * 3 + 1}, $${index * 3 + 2}, $${index * 3 + 3})`
    ).join(', ');
    
    const query = `
      INSERT INTO users (email, first_name, last_name)
      VALUES ${values}
      RETURNING id, email, first_name, last_name
    `;
    
    const flatValues = users.flatMap(user => [user.email, user.firstName, user.lastName]);
    const result = await pool.query(query, flatValues);
    return result.rows;
  }
}
```

### Frontend Performance

#### Code Splitting & Lazy Loading
```typescript
// apps/web/src/app/App.tsx
import { lazy, Suspense } from 'react';
import { Routes, Route } from 'react-router-dom';
import { LoadingSpinner } from '@myapp/ui/components';

// Lazy load components
const Dashboard = lazy(() => import('./pages/Dashboard'));
const Profile = lazy(() => import('./pages/Profile'));
const Settings = lazy(() => import('./pages/Settings'));

export function App() {
  return (
    <Suspense fallback={<LoadingSpinner />}>
      <Routes>
        <Route path="/" element={<Dashboard />} />
        <Route path="/profile" element={<Profile />} />
        <Route path="/settings" element={<Settings />} />
      </Routes>
    </Suspense>
  );
}
```

#### Optimized Asset Loading
```typescript
// apps/web/src/hooks/useImageOptimization.ts
import { useState, useEffect } from 'react';

export function useOptimizedImage(src: string, fallback?: string) {
  const [imageSrc, setImageSrc] = useState<string>(fallback || '');
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const img = new Image();
    
    img.onload = () => {
      setImageSrc(src);
      setIsLoading(false);
    };
    
    img.onerror = () => {
      setError('Failed to load image');
      setIsLoading(false);
      if (fallback) setImageSrc(fallback);
    };
    
    img.src = src;
  }, [src, fallback]);

  return { imageSrc, isLoading, error };
}
```

#### Caching Strategies
```typescript
// libs/shared/api/src/lib/cache.ts
import { LRUCache } from 'lru-cache';

class ApiCache {
  private cache = new LRUCache<string, any>({
    max: 500,
    ttl: 1000 * 60 * 5 // 5 minutes
  });

  set(key: string, data: any, ttl?: number) {
    this.cache.set(key, data, { ttl });
  }

  get(key: string) {
    return this.cache.get(key);
  }

  invalidate(pattern: string) {
    for (const key of this.cache.keys()) {
      if (key.includes(pattern)) {
        this.cache.delete(key);
      }
    }
  }
}

export const apiCache = new ApiCache();
```

---

## 🚀 Deployment Best Practices

### Platform-Specific Optimizations

#### Digital Ocean App Platform
```yaml
# .do/app.yaml - Production-optimized configuration
name: my-nx-app
services:
  - name: web
    source_dir: /
    build_command: |
      npm ci --only=production
      npm run build:web -- --configuration=production
    run_command: npx serve dist/apps/web -s -n -L -p $PORT
    environment_slug: node-js
    instance_count: 2
    instance_size_slug: basic-s
    http_port: 8080
    health_check:
      http_path: /
      initial_delay_seconds: 60
      period_seconds: 10
      timeout_seconds: 5
      success_threshold: 1
      failure_threshold: 3
    routes:
      - path: /
    envs:
      - key: NODE_ENV
        value: "production"
      - key: VITE_API_URL
        value: "${api.PUBLIC_URL}"

  - name: api
    source_dir: /
    build_command: |
      npm ci --only=production
      npm run build:api -- --configuration=production
    run_command: node dist/apps/api/main.js
    environment_slug: node-js
    instance_count: 2
    instance_size_slug: basic-s
    http_port: 8080
    health_check:
      http_path: /api/health
      initial_delay_seconds: 30
      period_seconds: 10
      timeout_seconds: 5
    routes:
      - path: /api
    envs:
      - key: NODE_ENV
        value: "production"
      - key: DATABASE_URL
        value: "${db.DATABASE_URL}"

databases:
  - name: db
    engine: PG
    version: "15"
    production: true
    num_nodes: 1
    size: db-s-1vcpu-1gb
```

#### Railway Optimization
```toml
# railway.toml
[build]
builder = "NIXPACKS"
buildCommand = "npm ci && npm run build:api"

[deploy]
startCommand = "node dist/apps/api/main.js"
healthcheckPath = "/api/health"
healthcheckTimeout = 60
restartPolicyType = "ON_FAILURE"
restartPolicyMaxRetries = 3

[env]
NODE_ENV = "production"
PORT = "8080"

# Nixpacks configuration
[nixpacks]
aptPkgs = []
nixPkgs = ["nodejs-18_x", "npm"]
```

### CI/CD Pipeline Optimization

#### Optimized GitHub Actions
```yaml
# .github/workflows/deploy.yml
name: Deploy to Production

on:
  push:
    branches: [main]

env:
  NODE_VERSION: '18'

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: 'npm'

      # Install dependencies with caching
      - name: Install dependencies
        run: npm ci --prefer-offline --no-audit

      # Run affected tests only
      - name: Run affected tests
        run: npx nx affected:test --base=origin/main~1 --head=HEAD --parallel=3

      # Run affected lint
      - name: Lint affected projects
        run: npx nx affected:lint --base=origin/main~1 --head=HEAD --parallel=3

      # Build affected projects
      - name: Build affected projects
        run: npx nx affected:build --base=origin/main~1 --head=HEAD --configuration=production --parallel=3

  deploy:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: 'npm'

      - name: Install dependencies
        run: npm ci --prefer-offline --no-audit

      # Build for production
      - name: Build applications
        run: |
          npx nx build web --configuration=production
          npx nx build api --configuration=production

      # Deploy to Digital Ocean
      - name: Deploy to Digital Ocean
        uses: digitalocean/app_action@v1.1.5
        with:
          app_name: my-nx-app
          token: ${{ secrets.DIGITALOCEAN_ACCESS_TOKEN }}
          images: |
            [
              {
                "name": "api",
                "image": {
                  "registry_type": "DOCR",
                  "repository": "my-nx-app",
                  "tag": "latest"
                }
              }
            ]
```

### Monitoring & Logging

#### Application Monitoring
```typescript
// libs/shared/monitoring/src/lib/metrics.ts
import { createPrometheusMetrics } from 'prom-client';

export class AppMetrics {
  private static httpRequestDuration = new prometheus.Histogram({
    name: 'http_request_duration_seconds',
    help: 'Duration of HTTP requests in seconds',
    labelNames: ['method', 'route', 'status_code']
  });

  private static activeConnections = new prometheus.Gauge({
    name: 'active_connections',
    help: 'Number of active connections',
    labelNames: ['type']
  });

  static recordHttpRequest(method: string, route: string, statusCode: number, duration: number) {
    this.httpRequestDuration
      .labels(method, route, statusCode.toString())
      .observe(duration);
  }

  static setActiveConnections(type: string, count: number) {
    this.activeConnections.labels(type).set(count);
  }
}

// Middleware for Express
export const metricsMiddleware = (req: Request, res: Response, next: NextFunction) => {
  const start = Date.now();
  
  res.on('finish', () => {
    const duration = (Date.now() - start) / 1000;
    AppMetrics.recordHttpRequest(req.method, req.route?.path || req.path, res.statusCode, duration);
  });
  
  next();
};
```

#### Structured Logging
```typescript
// libs/shared/logging/src/lib/logger.ts
import winston from 'winston';

const logFormat = winston.format.combine(
  winston.format.timestamp(),
  winston.format.errors({ stack: true }),
  winston.format.json(),
  winston.format.printf(({ timestamp, level, message, ...meta }) => {
    return JSON.stringify({
      timestamp,
      level,
      message,
      ...meta,
      service: process.env.SERVICE_NAME || 'unknown'
    });
  })
);

export const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: logFormat,
  transports: [
    new winston.transports.Console(),
    // Add file transport for production
    ...(process.env.NODE_ENV === 'production' ? [
      new winston.transports.File({ filename: 'logs/error.log', level: 'error' }),
      new winston.transports.File({ filename: 'logs/combined.log' })
    ] : [])
  ]
});

// Request logging middleware
export const requestLogger = (req: Request, res: Response, next: NextFunction) => {
  const start = Date.now();
  
  res.on('finish', () => {
    const duration = Date.now() - start;
    logger.info('HTTP Request', {
      method: req.method,
      url: req.url,
      statusCode: res.statusCode,
      duration,
      userAgent: req.get('User-Agent'),
      ip: req.ip
    });
  });
  
  next();
};
```

---

## 🔄 Maintenance & Updates

### Automated Dependency Updates

#### Renovate Configuration
```json
// renovate.json
{
  "extends": ["config:base"],
  "packageRules": [
    {
      "matchPackagePatterns": ["^@nrwl/", "^@nx/"],
      "groupName": "Nx packages",
      "schedule": ["before 10am on monday"]
    },
    {
      "matchPackagePatterns": ["^@types/"],
      "groupName": "Type definitions",
      "automerge": true
    },
    {
      "matchDepTypes": ["devDependencies"],
      "schedule": ["before 10am on monday"],
      "automerge": true,
      "automergeType": "pr"
    }
  ],
  "prHourlyLimit": 2,
  "prConcurrentLimit": 5,
  "timezone": "America/New_York"
}
```

#### Health Check Automation
```typescript
// tools/health-check/src/health-check.ts
import axios from 'axios';
import { logger } from '@myapp/shared/logging';

interface HealthCheckConfig {
  url: string;
  timeout: number;
  retries: number;
  expectedStatus: number;
}

export async function performHealthCheck(config: HealthCheckConfig): Promise<boolean> {
  for (let attempt = 1; attempt <= config.retries; attempt++) {
    try {
      const response = await axios.get(config.url, {
        timeout: config.timeout,
        validateStatus: (status) => status === config.expectedStatus
      });
      
      logger.info('Health check passed', {
        url: config.url,
        attempt,
        statusCode: response.status
      });
      
      return true;
    } catch (error) {
      logger.warn('Health check failed', {
        url: config.url,
        attempt,
        error: error.message
      });
      
      if (attempt === config.retries) {
        logger.error('Health check failed after all retries', {
          url: config.url,
          retries: config.retries
        });
        return false;
      }
      
      // Wait before retry
      await new Promise(resolve => setTimeout(resolve, 1000 * attempt));
    }
  }
  
  return false;
}
```

### Client Handover Preparation

#### Documentation Templates
```markdown
# Client Deployment Guide

## Application Overview
- **Frontend URL**: https://your-app.com
- **API URL**: https://api.your-app.com
- **Admin Dashboard**: https://admin.your-app.com (if applicable)

## Platform Access
- **Digital Ocean Account**: [Client will receive invitation]
- **Database Access**: Available through DO dashboard
- **Domain Management**: [DNS provider details]

## Common Tasks
1. **View Application Logs**: App Platform → Your App → Runtime Logs
2. **Monitor Performance**: App Platform → Your App → Insights
3. **Update Environment Variables**: App Platform → Your App → Settings → Environment Variables
4. **Scale Application**: App Platform → Your App → Settings → Resources

## Emergency Contacts
- **Development Team**: [Contact information]
- **Platform Support**: DigitalOcean Support (24/7)
- **Domain Support**: [DNS provider support]

## Monthly Maintenance Checklist
- [ ] Review application metrics and performance
- [ ] Check error logs for any issues
- [ ] Verify SSL certificate status
- [ ] Review resource usage and scaling needs
- [ ] Update dependencies (if comfortable, otherwise contact dev team)
```

---

## ✅ Quality Assurance Checklist

### Pre-Deployment Checklist
```markdown
## Build & Test
- [ ] All unit tests passing
- [ ] Integration tests passing
- [ ] E2E tests passing (critical paths)
- [ ] Linting passes with no errors
- [ ] TypeScript compilation successful
- [ ] Bundle size within acceptable limits

## Security
- [ ] Environment variables properly configured
- [ ] No sensitive data in source code
- [ ] Authentication/authorization working
- [ ] CORS properly configured
- [ ] Rate limiting in place
- [ ] Input validation implemented

## Performance
- [ ] Database queries optimized
- [ ] Images optimized and compressed
- [ ] Code splitting implemented
- [ ] Caching strategies in place
- [ ] CDN configured (if applicable)

## Monitoring
- [ ] Health check endpoints responding
- [ ] Logging configured and working
- [ ] Error tracking setup
- [ ] Performance monitoring active
- [ ] Alerts configured

## Client Handover
- [ ] Documentation complete and reviewed
- [ ] Client training completed
- [ ] Access credentials transferred
- [ ] Emergency procedures documented
- [ ] Maintenance schedule established
```

---

## 📚 Additional Resources

### Further Reading
- **[Comparison Analysis](./comparison-analysis.md)** - Detailed platform comparison
- **[Client Handover Strategy](./client-handover-strategy.md)** - Complete handover process
- **[Troubleshooting Guide](./troubleshooting-guide.md)** - Common issues and solutions

### External Resources
- [Nx Documentation](https://nx.dev/getting-started/intro)
- [Digital Ocean App Platform Docs](https://docs.digitalocean.com/products/app-platform/)
- [Railway Documentation](https://docs.railway.app/)
- [Vercel Documentation](https://vercel.com/docs)

---

*These best practices ensure robust, secure, and maintainable Nx deployments optimized for managed cloud platforms and client handovers.*