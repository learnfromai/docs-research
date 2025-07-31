# Template Examples and Configuration Files

## Overview

This document provides ready-to-use configuration files, code templates, and deployment scripts for Railway.com deployments, specifically tailored for Nx monorepo applications with React frontend, Express.js backend, and MySQL database.

## Railway Configuration Templates

### 1. Basic Railway.toml Configuration

```toml
# railway.toml - Basic Nx monorepo configuration
[build]
builder = "NIXPACKS"
buildCommand = "npm run build"

[deploy]
startCommand = "npm run start"
healthcheckPath = "/health"
healthcheckTimeout = 300
restartPolicyType = "ON_FAILURE"
restartPolicyMaxRetries = 10

# Production environment services
[environments.production.services.web]
source = "."
buildCommand = "npx nx build web --prod"
startCommand = "npx nx serve web --prod --port=$PORT"
variables = { 
  NODE_ENV = "production",
  VITE_API_URL = "${{API_URL}}"
}

[environments.production.services.api]
source = "."
buildCommand = "npx nx build api --prod"
startCommand = "node dist/apps/api/main.js"
variables = { 
  NODE_ENV = "production",
  FRONTEND_URL = "${{WEB_URL}}"
}

[environments.production.services.mysql]
image = "mysql:8.0"
variables = { 
  MYSQL_ROOT_PASSWORD = "${{MYSQL_ROOT_PASSWORD}}",
  MYSQL_DATABASE = "clinic_db",
  MYSQL_USER = "clinic_user",
  MYSQL_PASSWORD = "${{MYSQL_PASSWORD}}"
}

# Staging environment (inherits from production with overrides)
[environments.staging.services.web]
variables = { 
  NODE_ENV = "staging",
  VITE_API_URL = "${{STAGING_API_URL}}"
}

[environments.staging.services.api]
variables = { 
  NODE_ENV = "staging",
  DEBUG = "true",
  LOG_LEVEL = "debug"
}
```

### 2. Advanced Railway.toml with Multiple Services

```toml
# railway.toml - Advanced multi-service configuration
[build]
builder = "NIXPACKS"

# Frontend service (React/Vite)
[environments.production.services.frontend]
source = "."
buildCommand = "npx nx build web --prod"
startCommand = "npx nx serve web --prod --port=$PORT --host=0.0.0.0"
variables = { 
  NODE_ENV = "production",
  VITE_API_URL = "${{API_URL}}",
  VITE_APP_NAME = "Clinic Management System"
}

# Backend API service (Express.js)
[environments.production.services.api]
source = "."
buildCommand = "npx nx build api --prod"
startCommand = "node dist/apps/api/main.js"
variables = { 
  NODE_ENV = "production",
  PORT = "$PORT",
  FRONTEND_URL = "${{FRONTEND_URL}}",
  DATABASE_URL = "${{DATABASE_URL}}",
  JWT_SECRET = "${{JWT_SECRET}}",
  SESSION_SECRET = "${{SESSION_SECRET}}"
}

# Background worker service
[environments.production.services.worker]
source = "."
buildCommand = "npx nx build worker --prod"
startCommand = "node dist/apps/worker/main.js"
variables = { 
  NODE_ENV = "production",
  DATABASE_URL = "${{DATABASE_URL}}",
  REDIS_URL = "${{REDIS_URL}}"
}

# MySQL database
[environments.production.services.mysql]
image = "mysql:8.0"
variables = { 
  MYSQL_ROOT_PASSWORD = "${{MYSQL_ROOT_PASSWORD}}",
  MYSQL_DATABASE = "clinic_db",
  MYSQL_USER = "clinic_user",
  MYSQL_PASSWORD = "${{MYSQL_PASSWORD}}"
}

# Redis cache
[environments.production.services.redis]
image = "redis:7-alpine"
variables = {
  REDIS_PASSWORD = "${{REDIS_PASSWORD}}"
}
```

## Package.json Templates

### 1. Root Package.json with Railway Scripts

```json
{
  "name": "clinic-management-system",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "build": "nx run-many --target=build --all --prod",
    "build:web": "nx build web --prod",
    "build:api": "nx build api --prod",
    "build:worker": "nx build worker --prod",
    "start": "node dist/apps/api/main.js",
    "start:web": "nx serve web --prod --port=$PORT --host=0.0.0.0",
    "start:api": "node dist/apps/api/main.js",
    "start:worker": "node dist/apps/worker/main.js",
    "dev": "nx run-many --target=serve --all --parallel",
    "test": "nx run-many --target=test --all",
    "lint": "nx run-many --target=lint --all",
    "railway:build": "npm ci --omit=dev && npm run build",
    "railway:start": "npm run start",
    "railway:web": "npm run start:web",
    "railway:api": "npm run start:api",
    "railway:worker": "npm run start:worker",
    "db:migrate": "node scripts/migrate.js",
    "db:seed": "node scripts/seed.js",
    "db:backup": "node scripts/backup.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "mysql2": "^3.6.0",
    "cors": "^2.8.5",
    "helmet": "^7.0.0",
    "bcrypt": "^5.1.0",
    "jsonwebtoken": "^9.0.0",
    "winston": "^3.8.2",
    "react": "^18.2.0",
    "react-dom": "^18.2.0"
  },
  "devDependencies": {
    "@nx/vite": "^16.0.0",
    "@nx/express": "^16.0.0",
    "@nx/webpack": "^16.0.0",
    "@types/express": "^4.17.17",
    "@types/cors": "^2.8.13",
    "@types/bcrypt": "^5.0.0",
    "@types/jsonwebtoken": "^9.0.2",
    "typescript": "^5.0.0",
    "vite": "^4.3.0"
  }
}
```

### 2. Web App Package.json (Frontend)

```json
{
  "name": "clinic-web",
  "version": "1.0.0",
  "private": true,
  "type": "module",
  "scripts": {
    "build": "vite build",
    "dev": "vite",
    "preview": "vite preview",
    "serve": "vite preview --port=$PORT --host=0.0.0.0"
  },
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-router-dom": "^6.8.0",
    "axios": "^1.3.0",
    "date-fns": "^2.29.0"
  },
  "devDependencies": {
    "@types/react": "^18.0.0",
    "@types/react-dom": "^18.0.0",
    "@vitejs/plugin-react": "^4.0.0",
    "vite": "^4.3.0"
  }
}
```

## Nx Project Configuration Templates

### 1. Frontend Project Configuration (apps/web/project.json)

```json
{
  "name": "web",
  "$schema": "../../node_modules/nx/schemas/project-schema.json",
  "projectType": "application",
  "sourceRoot": "apps/web/src",
  "prefix": "clinic",
  "targets": {
    "build": {
      "executor": "@nx/vite:build",
      "outputs": ["{options.outputPath}"],
      "defaultConfiguration": "production",
      "options": {
        "outputPath": "dist/apps/web"
      },
      "configurations": {
        "development": {
          "mode": "development",
          "sourcemap": true
        },
        "production": {
          "mode": "production",
          "optimization": true,
          "buildLibsFromSource": false,
          "sourcemap": false
        }
      }
    },
    "serve": {
      "executor": "@nx/vite:dev-server",
      "defaultConfiguration": "development",
      "options": {
        "buildTarget": "web:build",
        "port": 3000,
        "host": "localhost"
      },
      "configurations": {
        "development": {
          "buildTarget": "web:build:development",
          "hmr": true
        },
        "production": {
          "buildTarget": "web:build:production",
          "hmr": false,
          "port": 3000,
          "host": "0.0.0.0"
        }
      }
    },
    "preview": {
      "executor": "@nx/vite:preview-server",
      "defaultConfiguration": "development",
      "options": {
        "buildTarget": "web:build",
        "port": 4300
      }
    },
    "test": {
      "executor": "@nx/vite:test",
      "outputs": ["{options.reportsDirectory}"],
      "options": {
        "passWithNoTests": true,
        "reportsDirectory": "../../coverage/apps/web"
      }
    },
    "lint": {
      "executor": "@nx/linter:eslint",
      "outputs": ["{options.outputFile}"],
      "options": {
        "lintFilePatterns": ["apps/web/**/*.{ts,tsx,js,jsx}"]
      }
    }
  },
  "tags": ["scope:web", "type:app"]
}
```

### 2. Backend Project Configuration (apps/api/project.json)

```json
{
  "name": "api",
  "$schema": "../../node_modules/nx/schemas/project-schema.json",
  "projectType": "application",
  "sourceRoot": "apps/api/src",
  "targets": {
    "build": {
      "executor": "@nx/webpack:webpack",
      "outputs": ["{options.outputPath}"],
      "defaultConfiguration": "production",
      "options": {
        "target": "node",
        "compiler": "tsc",
        "outputPath": "dist/apps/api",
        "main": "apps/api/src/main.ts",
        "tsConfig": "apps/api/tsconfig.app.json",
        "assets": ["apps/api/src/assets"],
        "isolatedConfig": true,
        "webpackConfig": "apps/api/webpack.config.js"
      },
      "configurations": {
        "development": {
          "optimization": false,
          "extractLicenses": false,
          "inspect": false,
          "sourceMap": true
        },
        "production": {
          "optimization": true,
          "extractLicenses": true,
          "inspect": false,
          "sourceMap": false,
          "fileReplacements": [
            {
              "replace": "apps/api/src/environments/environment.ts",
              "with": "apps/api/src/environments/environment.prod.ts"
            }
          ]
        }
      }
    },
    "serve": {
      "executor": "@nx/js:node",
      "defaultConfiguration": "development",
      "options": {
        "buildTarget": "api:build",
        "inspect": false,
        "port": 3333
      },
      "configurations": {
        "development": {
          "buildTarget": "api:build:development"
        },
        "production": {
          "buildTarget": "api:build:production"
        }
      }
    },
    "lint": {
      "executor": "@nx/linter:eslint",
      "outputs": ["{options.outputFile}"],
      "options": {
        "lintFilePatterns": ["apps/api/**/*.ts"]
      }
    },
    "test": {
      "executor": "@nx/jest:jest",
      "outputs": ["{workspaceRoot}/coverage/{projectRoot}"],
      "options": {
        "jestConfig": "apps/api/jest.config.ts",
        "passWithNoTests": true
      },
      "configurations": {
        "ci": {
          "ci": true,
          "coverage": true
        }
      }
    }
  },
  "tags": ["scope:api", "type:app"]
}
```

## Vite Configuration Templates

### 1. Frontend Vite Config (apps/web/vite.config.ts)

```typescript
/// <reference types='vitest' />
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { nxViteTsPaths } from '@nx/vite/plugins/nx-tsconfig-paths.plugin';

export default defineConfig({
  root: __dirname,
  cacheDir: '../../node_modules/.vite/apps/web',

  server: {
    port: 3000,
    host: 'localhost',
    cors: true
  },

  preview: {
    port: 4300,
    host: 'localhost',
  },

  plugins: [react(), nxViteTsPaths()],

  // Uncomment this if you are using workers.
  // worker: {
  //  plugins: [ nxViteTsPaths() ],
  // },

  build: {
    outDir: '../../dist/apps/web',
    reportCompressedSize: true,
    commonjsOptions: {
      transformMixedEsModules: true,
    },
    rollupOptions: {
      output: {
        manualChunks: {
          vendor: ['react', 'react-dom'],
          router: ['react-router-dom'],
          utils: ['date-fns', 'axios']
        }
      }
    },
    target: 'esnext',
    minify: 'terser',
    terserOptions: {
      compress: {
        drop_console: true,
        drop_debugger: true
      }
    }
  },

  define: {
    'import.meta.vitest': undefined,
  },

  test: {
    globals: true,
    cache: {
      dir: '../../node_modules/.vitest',
    },
    environment: 'jsdom',
    include: ['src/**/*.{test,spec}.{js,mjs,cjs,ts,mts,cts,jsx,tsx}'],
    reporters: ['default'],
    coverage: {
      reportsDirectory: '../../coverage/apps/web',
      provider: 'v8'
    },
  },
});
```

### 2. Production Optimized Vite Config

```typescript
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { nxViteTsPaths } from '@nx/vite/plugins/nx-tsconfig-paths.plugin';

export default defineConfig(({ mode }) => ({
  root: __dirname,
  cacheDir: '../../node_modules/.vite/apps/web',

  server: {
    port: parseInt(process.env.PORT) || 3000,
    host: '0.0.0.0', // Important for Railway deployment
    cors: {
      origin: process.env.VITE_API_URL || 'http://localhost:3333',
      credentials: true
    }
  },

  preview: {
    port: parseInt(process.env.PORT) || 4300,
    host: '0.0.0.0',
  },

  plugins: [
    react({
      // Enable React Fast Refresh in development
      fastRefresh: mode === 'development',
    }),
    nxViteTsPaths()
  ],

  build: {
    outDir: '../../dist/apps/web',
    reportCompressedSize: false, // Disable for faster builds
    commonjsOptions: {
      transformMixedEsModules: true,
    },
    rollupOptions: {
      output: {
        manualChunks: {
          vendor: ['react', 'react-dom'],
          router: ['react-router-dom'],
          utils: ['date-fns', 'axios'],
          ui: ['@mui/material', '@emotion/react', '@emotion/styled']
        },
        chunkFileNames: 'chunks/[name]-[hash].js',
        entryFileNames: 'entries/[name]-[hash].js',
        assetFileNames: 'assets/[name]-[hash].[ext]'
      }
    },
    target: 'esnext',
    minify: mode === 'production' ? 'terser' : false,
    terserOptions: mode === 'production' ? {
      compress: {
        drop_console: true,
        drop_debugger: true,
        pure_funcs: ['console.log', 'console.info']
      },
      mangle: true
    } : undefined,
    sourcemap: mode === 'development',
    cssCodeSplit: true
  },

  define: {
    'process.env.NODE_ENV': JSON.stringify(mode),
    'import.meta.vitest': undefined,
  },

  optimizeDeps: {
    include: ['react', 'react-dom', 'react-router-dom'],
    exclude: ['@nx/nx-dev-build']
  }
}));
```

## Express.js Backend Templates

### 1. Main Application File (apps/api/src/main.ts)

```typescript
import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import compression from 'compression';
import rateLimit from 'express-rate-limit';
import { json, urlencoded } from 'express';
import { createServer } from 'http';

// Import environment configuration
import { environment } from './environments/environment';

// Import routes
import { patientsRouter } from './routes/patients';
import { appointmentsRouter } from './routes/appointments';
import { authRouter } from './routes/auth';
import { healthRouter } from './routes/health';

// Import middleware
import { errorHandler } from './middleware/error-handler';
import { requestLogger } from './middleware/request-logger';
import { authMiddleware } from './middleware/auth';

// Import database connection
import { initDatabase } from './database/connection';

const app = express();
const PORT = process.env.PORT || 3333;

// Security middleware
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      scriptSrc: ["'self'"],
      imgSrc: ["'self'", "data:", "https:"],
      connectSrc: ["'self'"],
      fontSrc: ["'self'"],
      objectSrc: ["'none'"],
      mediaSrc: ["'self'"],
      frameSrc: ["'none'"]
    }
  },
  crossOriginEmbedderPolicy: false
}));

// CORS configuration
app.use(cors({
  origin: [
    environment.frontendUrl,
    'http://localhost:3000',
    'http://localhost:4200'
  ],
  credentials: true,
  optionsSuccessStatus: 200,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With']
}));

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: environment.production ? 100 : 1000, // limit each IP
  message: {
    error: 'Too many requests from this IP, please try again later.',
    retryAfter: '15 minutes'
  },
  standardHeaders: true,
  legacyHeaders: false
});

app.use('/api/', limiter);

// Body parsing middleware
app.use(compression());
app.use(json({ limit: '10mb' }));
app.use(urlencoded({ extended: true, limit: '10mb' }));

// Request logging
app.use(requestLogger);

// Health check (no auth required)
app.use('/health', healthRouter);

// API routes
app.use('/api/auth', authRouter);
app.use('/api/patients', authMiddleware, patientsRouter);
app.use('/api/appointments', authMiddleware, appointmentsRouter);

// Default route
app.get('/', (req, res) => {
  res.json({
    message: 'Clinic Management API',
    version: '1.0.0',
    environment: process.env.NODE_ENV,
    timestamp: new Date().toISOString()
  });
});

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({
    error: 'Route not found',
    path: req.originalUrl,
    method: req.method,
    timestamp: new Date().toISOString()
  });
});

// Global error handler
app.use(errorHandler);

// Graceful shutdown
const server = createServer(app);

process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully');
  server.close(() => {
    console.log('Process terminated');
    process.exit(0);
  });
});

process.on('SIGINT', () => {
  console.log('SIGINT received, shutting down gracefully');
  server.close(() => {
    console.log('Process terminated');
    process.exit(0);
  });
});

// Start server
async function startServer() {
  try {
    // Initialize database connection
    await initDatabase();
    
    server.listen(PORT, '0.0.0.0', () => {
      console.log(`🚀 Server running on http://0.0.0.0:${PORT}`);
      console.log(`📊 Environment: ${process.env.NODE_ENV}`);
      console.log(`🔗 Frontend URL: ${environment.frontendUrl}`);
    });
    
  } catch (error) {
    console.error('Failed to start server:', error);
    process.exit(1);
  }
}

startServer();
```

### 2. Environment Configuration Templates

```typescript
// apps/api/src/environments/environment.ts
export const environment = {
  production: false,
  frontendUrl: process.env.FRONTEND_URL || 'http://localhost:3000',
  database: {
    host: process.env.MYSQL_HOST || 'localhost',
    port: parseInt(process.env.MYSQL_PORT || '3306'),
    user: process.env.MYSQL_USER || 'root',
    password: process.env.MYSQL_PASSWORD || '',
    database: process.env.MYSQL_DATABASE || 'clinic_db',
    ssl: false,
    connectionLimit: 5
  },
  jwt: {
    secret: process.env.JWT_SECRET || 'dev-secret-key',
    expiresIn: '24h'
  },
  session: {
    secret: process.env.SESSION_SECRET || 'dev-session-secret',
    maxAge: 24 * 60 * 60 * 1000 // 24 hours
  },
  logging: {
    level: 'debug'
  }
};

// apps/api/src/environments/environment.prod.ts
export const environment = {
  production: true,
  frontendUrl: process.env.FRONTEND_URL!,
  database: {
    host: process.env.MYSQL_HOST!,
    port: parseInt(process.env.MYSQL_PORT || '3306'),
    user: process.env.MYSQL_USER!,
    password: process.env.MYSQL_PASSWORD!,
    database: process.env.MYSQL_DATABASE!,
    ssl: {
      rejectUnauthorized: false
    },
    connectionLimit: 10
  },
  jwt: {
    secret: process.env.JWT_SECRET!,
    expiresIn: '24h'
  },
  session: {
    secret: process.env.SESSION_SECRET!,
    maxAge: 24 * 60 * 60 * 1000
  },
  logging: {
    level: 'error'
  }
};
```

## Database Connection Templates

### 1. Database Connection Service

```typescript
// apps/api/src/database/connection.ts
import mysql from 'mysql2/promise';
import { environment } from '../environments/environment';

let pool: mysql.Pool;

export async function initDatabase(): Promise<mysql.Pool> {
  try {
    pool = mysql.createPool({
      host: environment.database.host,
      port: environment.database.port,
      user: environment.database.user,
      password: environment.database.password,
      database: environment.database.database,
      ssl: environment.database.ssl,
      connectionLimit: environment.database.connectionLimit,
      acquireTimeout: 60000,
      timeout: 60000,
      reconnect: true,
      multipleStatements: false
    });

    // Test connection
    const connection = await pool.getConnection();
    await connection.ping();
    connection.release();

    console.log('✅ Database connected successfully');
    return pool;
    
  } catch (error) {
    console.error('❌ Database connection failed:', error);
    throw error;
  }
}

export function getDatabase(): mysql.Pool {
  if (!pool) {
    throw new Error('Database not initialized. Call initDatabase() first.');
  }
  return pool;
}

export async function closeDatabase(): Promise<void> {
  if (pool) {
    await pool.end();
    console.log('✅ Database connection closed');
  }
}

// Query helper function
export async function query<T = any>(sql: string, params?: any[]): Promise<T[]> {
  const db = getDatabase();
  const [rows] = await db.execute(sql, params);
  return rows as T[];
}

// Transaction helper
export async function transaction<T>(
  callback: (connection: mysql.PoolConnection) => Promise<T>
): Promise<T> {
  const db = getDatabase();
  const connection = await db.getConnection();
  
  try {
    await connection.beginTransaction();
    const result = await callback(connection);
    await connection.commit();
    return result;
  } catch (error) {
    await connection.rollback();
    throw error;
  } finally {
    connection.release();
  }
}
```

## Docker Templates (Optional)

### 1. Multi-Stage Dockerfile for API

```dockerfile
# Dockerfile.api
FROM node:18-alpine AS builder

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./
COPY nx.json ./
COPY tsconfig*.json ./

# Install dependencies
RUN npm ci --only=production && npm cache clean --force

# Copy source code
COPY apps/api ./apps/api
COPY libs ./libs

# Build the application
RUN npx nx build api --prod

# Production stage
FROM node:18-alpine AS runtime

# Install dumb-init for proper signal handling
RUN apk add --no-cache dumb-init

# Create app user
RUN addgroup -g 1001 -S nodejs && adduser -S app -u 1001

# Set working directory
WORKDIR /app

# Copy built application
COPY --from=builder --chown=app:nodejs /app/dist/apps/api ./
COPY --from=builder --chown=app:nodejs /app/node_modules ./node_modules

# Switch to app user
USER app

# Expose port
EXPOSE 3333

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3333/health || exit 1

# Start the application
ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "main.js"]
```

### 2. Docker Compose for Local Development

```yaml
# docker-compose.yml
version: '3.8'

services:
  mysql:
    image: mysql:8.0
    environment:
      MYSQL_ROOT_PASSWORD: root_password
      MYSQL_DATABASE: clinic_db
      MYSQL_USER: clinic_user
      MYSQL_PASSWORD: clinic_password
    ports:
      - "3306:3306"
    volumes:
      - mysql_data:/var/lib/mysql
      - ./database/schema.sql:/docker-entrypoint-initdb.d/01-schema.sql
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      timeout: 20s
      retries: 10

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    command: redis-server --requirepass redis_password
    volumes:
      - redis_data:/data

  api:
    build:
      context: .
      dockerfile: Dockerfile.api
    ports:
      - "3333:3333"
    environment:
      NODE_ENV: development
      MYSQL_HOST: mysql
      MYSQL_PORT: 3306
      MYSQL_USER: clinic_user
      MYSQL_PASSWORD: clinic_password
      MYSQL_DATABASE: clinic_db
      REDIS_URL: redis://redis:6379
      FRONTEND_URL: http://localhost:3000
      JWT_SECRET: dev-jwt-secret
    depends_on:
      mysql:
        condition: service_healthy
      redis:
        condition: service_started
    volumes:
      - ./apps/api/src:/app/src:ro
    command: npm run start:dev

  web:
    build:
      context: .
      dockerfile: Dockerfile.web
    ports:
      - "3000:3000"
    environment:
      VITE_API_URL: http://localhost:3333
    volumes:
      - ./apps/web/src:/app/src:ro
    command: npm run dev

volumes:
  mysql_data:
  redis_data:
```

## GitHub Actions Templates

### 1. Basic CI/CD Pipeline

```yaml
# .github/workflows/deploy.yml
name: Deploy to Railway

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

env:
  NODE_VERSION: '18'

jobs:
  test:
    runs-on: ubuntu-latest
    
    services:
      mysql:
        image: mysql:8.0
        env:
          MYSQL_ROOT_PASSWORD: test_password
          MYSQL_DATABASE: clinic_test
        ports:
          - 3306:3306
        options: >-
          --health-cmd="mysqladmin ping"
          --health-interval=10s
          --health-timeout=5s
          --health-retries=3

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Run linting
        run: npm run lint

      - name: Run tests
        run: npm run test
        env:
          MYSQL_HOST: localhost
          MYSQL_PORT: 3306
          MYSQL_USER: root
          MYSQL_PASSWORD: test_password
          MYSQL_DATABASE: clinic_test

      - name: Build applications
        run: |
          npx nx build web --prod
          npx nx build api --prod

      - name: Upload build artifacts
        uses: actions/upload-artifact@v3
        with:
          name: build-files
          path: dist/

  deploy-staging:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/develop'
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Install Railway CLI
        run: npm install -g @railway/cli

      - name: Deploy to Railway Staging
        run: railway up --detach --environment staging
        env:
          RAILWAY_TOKEN: ${{ secrets.RAILWAY_STAGING_TOKEN }}

  deploy-production:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Install Railway CLI
        run: npm install -g @railway/cli

      - name: Deploy to Railway Production
        run: railway up --detach --environment production
        env:
          RAILWAY_TOKEN: ${{ secrets.RAILWAY_PRODUCTION_TOKEN }}

      - name: Notify deployment success
        uses: 8398a7/action-slack@v3
        with:
          status: success
          text: 'Production deployment successful! 🚀'
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
        if: success()

      - name: Notify deployment failure
        uses: 8398a7/action-slack@v3
        with:
          status: failure
          text: 'Production deployment failed! ❌'
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
        if: failure()
```

## Utility Scripts Templates

### 1. Database Migration Script

```javascript
// scripts/migrate.js
const mysql = require('mysql2/promise');
const fs = require('fs');
const path = require('path');

async function runMigrations() {
  const connection = await mysql.createConnection({
    host: process.env.MYSQL_HOST,
    port: process.env.MYSQL_PORT || 3306,
    user: process.env.MYSQL_USER,
    password: process.env.MYSQL_PASSWORD,
    database: process.env.MYSQL_DATABASE,
    multipleStatements: true
  });

  try {
    console.log('🔄 Running database migrations...');

    // Create migrations table if not exists
    await connection.execute(`
      CREATE TABLE IF NOT EXISTS migrations (
        id INT AUTO_INCREMENT PRIMARY KEY,
        filename VARCHAR(255) UNIQUE NOT NULL,
        executed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    // Get executed migrations
    const [executedMigrations] = await connection.execute(
      'SELECT filename FROM migrations'
    );
    const executed = executedMigrations.map(m => m.filename);

    // Read migration files
    const migrationsDir = path.join(__dirname, '../database/migrations');
    const migrationFiles = fs.readdirSync(migrationsDir)
      .filter(file => file.endsWith('.sql'))
      .sort();

    // Run pending migrations
    for (const file of migrationFiles) {
      if (!executed.includes(file)) {
        console.log(`📄 Running migration: ${file}`);
        
        const sqlContent = fs.readFileSync(
          path.join(migrationsDir, file), 
          'utf8'
        );
        
        await connection.execute(sqlContent);
        await connection.execute(
          'INSERT INTO migrations (filename) VALUES (?)', 
          [file]
        );
        
        console.log(`✅ Migration completed: ${file}`);
      }
    }

    console.log('🎉 All migrations completed successfully!');
    
  } catch (error) {
    console.error('❌ Migration failed:', error);
    process.exit(1);
  } finally {
    await connection.end();
  }
}

if (require.main === module) {
  runMigrations();
}

module.exports = { runMigrations };
```

### 2. Database Seeding Script

```javascript
// scripts/seed.js
const mysql = require('mysql2/promise');
const bcrypt = require('bcrypt');

async function seedDatabase() {
  const connection = await mysql.createConnection({
    host: process.env.MYSQL_HOST,
    port: process.env.MYSQL_PORT || 3306,
    user: process.env.MYSQL_USER,
    password: process.env.MYSQL_PASSWORD,
    database: process.env.MYSQL_DATABASE
  });

  try {
    console.log('🌱 Seeding database...');

    // Create admin user
    const hashedPassword = await bcrypt.hash('admin123', 10);
    await connection.execute(`
      INSERT IGNORE INTO users (username, email, password_hash, first_name, last_name, role)
      VALUES (?, ?, ?, ?, ?, ?)
    `, ['admin', 'admin@clinic.com', hashedPassword, 'Admin', 'User', 'Admin']);

    // Create sample patients
    const patients = [
      ['PAT001', 'John', 'Doe', '1985-05-15', '555-0101', 'john.doe@email.com'],
      ['PAT002', 'Jane', 'Smith', '1990-08-22', '555-0102', 'jane.smith@email.com'],
      ['PAT003', 'Bob', 'Johnson', '1978-12-10', '555-0103', 'bob.johnson@email.com']
    ];

    for (const patient of patients) {
      await connection.execute(`
        INSERT IGNORE INTO patients (patient_id, first_name, last_name, date_of_birth, phone, email)
        VALUES (?, ?, ?, ?, ?, ?)
      `, patient);
    }

    // Create sample appointments
    const tomorrow = new Date();
    tomorrow.setDate(tomorrow.getDate() + 1);
    const tomorrowStr = tomorrow.toISOString().split('T')[0];

    await connection.execute(`
      INSERT IGNORE INTO appointments (patient_id, appointment_date, appointment_time, appointment_type, status)
      VALUES 
        (1, ?, '09:00:00', 'Consultation', 'Scheduled'),
        (2, ?, '10:30:00', 'Follow-up', 'Scheduled'),
        (3, ?, '14:00:00', 'Consultation', 'Scheduled')
    `, [tomorrowStr, tomorrowStr, tomorrowStr]);

    console.log('✅ Database seeded successfully!');
    console.log('📋 Default admin credentials: admin / admin123');
    
  } catch (error) {
    console.error('❌ Seeding failed:', error);
    process.exit(1);
  } finally {
    await connection.end();
  }
}

if (require.main === module) {
  seedDatabase();
}

module.exports = { seedDatabase };
```

---

## Usage Instructions

### 1. Quick Start
```bash
# Copy templates to your project
cp railway.toml.template railway.toml
cp package.json.template package.json

# Install dependencies
npm install

# Configure environment variables
railway variables set MYSQL_ROOT_PASSWORD=$(openssl rand -base64 32)

# Deploy to Railway
railway up
```

### 2. Customization
- Modify service configurations in `railway.toml`
- Update environment variables for your specific needs
- Adjust build and start commands based on your project structure
- Configure database schema and seed data

### 3. Production Deployment
- Use production environment configurations
- Set up proper monitoring and logging
- Configure backup strategies
- Implement security best practices

---

## Next Steps

1. **[Follow Implementation Guide](./implementation-guide.md)** - Step-by-step deployment
2. **[Review Best Practices](./best-practices.md)** - Production optimization
3. **[Check Troubleshooting](./troubleshooting.md)** - Common issues and solutions

---

*Template Examples and Configuration Files | Railway.com Deployment | January 2025*