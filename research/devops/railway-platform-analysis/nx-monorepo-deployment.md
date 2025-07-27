# Nx Monorepo Deployment Guide for Railway.com

## 🎯 Overview

This guide provides comprehensive instructions for deploying Nx monorepo projects to Railway.com, covering both frontend and backend applications with shared libraries and optimized build processes.

## 🏗 Nx Monorepo Architecture on Railway

### Project Structure Best Practices

```
clinic-management/
├── apps/
│   ├── web/                    # React frontend application
│   │   ├── src/
│   │   ├── project.json
│   │   └── vite.config.ts
│   └── api/                    # Express.js backend application
│       ├── src/
│       │   ├── main.ts
│       │   └── app/
│       └── project.json
├── libs/
│   ├── shared/                 # Shared utilities and types
│   │   ├── types/
│   │   ├── utils/
│   │   └── validations/
│   └── ui/                     # Shared UI components
│       ├── components/
│       └── styles/
├── tools/
├── nx.json
├── package.json
├── railway.toml                # Root Railway configuration
└── .railway/
    ├── web.toml               # Frontend service config
    └── api.toml               # Backend service config
```

## 🚀 Service Configuration Strategy

### 1. Root Configuration (`railway.toml`)

```toml
# Root configuration for shared settings
[build]
builder = "nixpacks"

[deploy]
numReplicas = 1
restartPolicyType = "ON_FAILURE"
restartPolicyMaxRetries = 10
```

### 2. Frontend Service Configuration

**File: `.railway/web.toml`**

```toml
[build]
builder = "nixpacks"
buildCommand = "npx nx build web --prod"
buildPhase = "build"

[deploy]
startCommand = "npx serve dist/apps/web -s -p $PORT"
healthcheckPath = "/"
healthcheckTimeout = 300
```

**Environment Variables for Frontend:**
```bash
# Production build optimization
NODE_ENV=production
PORT=3000

# API endpoint configuration
VITE_API_URL=https://${{api.RAILWAY_PUBLIC_DOMAIN}}
VITE_APP_VERSION=${{RAILWAY_GIT_COMMIT_SHA}}

# Feature flags for production
VITE_ENABLE_ANALYTICS=true
VITE_ENABLE_ERROR_REPORTING=true
```

### 3. Backend Service Configuration

**File: `.railway/api.toml`**

```toml
[build]
builder = "nixpacks"
buildCommand = "npx nx build api --prod"
buildPhase = "build"

[deploy]
startCommand = "node dist/apps/api/main.js"
healthcheckPath = "/health"
healthcheckTimeout = 300
```

**Environment Variables for Backend:**
```bash
# Runtime configuration
NODE_ENV=production
PORT=8080

# Database connection
DATABASE_URL=${{MySQL.DATABASE_URL}}

# CORS configuration
CORS_ORIGIN=https://${{web.RAILWAY_PUBLIC_DOMAIN}}
CORS_CREDENTIALS=true

# JWT configuration
JWT_SECRET=${{JWT_SECRET}}
JWT_EXPIRES_IN=24h

# Application settings
LOG_LEVEL=info
RATE_LIMIT_WINDOW_MS=900000
RATE_LIMIT_MAX_REQUESTS=100
```

## 🔧 Advanced Nx Build Configuration

### 1. Optimized Build Commands

**Frontend Build (React/Vite):**
```json
// apps/web/project.json
{
  "name": "web",
  "targets": {
    "build": {
      "executor": "@nx/vite:build",
      "outputs": ["{options.outputPath}"],
      "defaultConfiguration": "production",
      "options": {
        "outputPath": "dist/apps/web"
      },
      "configurations": {
        "production": {
          "mode": "production",
          "sourcemap": false,
          "minify": true
        }
      }
    }
  }
}
```

**Backend Build (Express.js):**
```json
// apps/api/project.json
{
  "name": "api",
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
        "assets": ["apps/api/src/assets"]
      },
      "configurations": {
        "production": {
          "optimization": true,
          "extractLicenses": false,
          "sourceMap": false
        }
      }
    }
  }
}
```

### 2. Shared Libraries Configuration

**Shared Types Library:**
```typescript
// libs/shared/types/src/index.ts
export interface Patient {
  id: string;
  name: string;
  email: string;
  phone: string;
  dateOfBirth: Date;
  createdAt: Date;
  updatedAt: Date;
}

export interface Appointment {
  id: string;
  patientId: string;
  doctorId: string;
  scheduledAt: Date;
  status: 'scheduled' | 'completed' | 'cancelled';
  notes?: string;
}

export interface ApiResponse<T> {
  success: boolean;
  data?: T;
  error?: string;
  message?: string;
}
```

**Shared Utilities:**
```typescript
// libs/shared/utils/src/index.ts
export const formatDate = (date: Date): string => {
  return date.toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'short',
    day: 'numeric'
  });
};

export const validateEmail = (email: string): boolean => {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(email);
};

export const generateId = (): string => {
  return Math.random().toString(36).substr(2, 9);
};
```

## 🔄 Deployment Workflows

### 1. Single Command Deployment

```bash
# Deploy all services from monorepo root
railway up --service web --service api

# Deploy specific service
railway up --service web
railway up --service api
```

### 2. Environment-Specific Deployments

**Development Environment:**
```bash
# Create development project
railway project create clinic-dev

# Set development environment variables
railway variables set NODE_ENV=development --service api
railway variables set VITE_API_URL=http://localhost:8080 --service web
railway variables set DATABASE_URL=${{MySQL-Dev.DATABASE_URL}} --service api
```

**Production Environment:**
```bash
# Create production project
railway project create clinic-prod

# Set production environment variables
railway variables set NODE_ENV=production --service api
railway variables set VITE_API_URL=https://${{api.RAILWAY_PUBLIC_DOMAIN}} --service web
railway variables set DATABASE_URL=${{MySQL-Prod.DATABASE_URL}} --service api
```

### 3. Automated CI/CD Pipeline

**GitHub Actions Workflow:**
```yaml
# .github/workflows/deploy-railway.yml
name: Deploy to Railway

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

env:
  NX_CLOUD_ACCESS_TOKEN: ${{ secrets.NX_CLOUD_ACCESS_TOKEN }}

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
        with:
          fetch-depth: 0
      
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'
          cache: 'npm'
      
      - name: Install dependencies
        run: npm ci
      
      - name: Run tests
        run: npx nx run-many --target=test --all --parallel
      
      - name: Lint code
        run: npx nx run-many --target=lint --all --parallel
      
      - name: Build applications
        run: npx nx run-many --target=build --all --parallel

  deploy-staging:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/develop'
    steps:
      - uses: actions/checkout@v3
      
      - name: Deploy to Railway Staging
        uses: railway/cli-action@v1
        with:
          token: ${{ secrets.RAILWAY_TOKEN_STAGING }}
          command: up --service web --service api

  deploy-production:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v3
      
      - name: Deploy to Railway Production
        uses: railway/cli-action@v1
        with:
          token: ${{ secrets.RAILWAY_TOKEN_PRODUCTION }}
          command: up --service web --service api
```

## 🗄 Database Integration with Nx

### 1. Database Service Setup

```bash
# Create MySQL service
railway service create mysql

# Get database connection string
railway variables get DATABASE_URL --service mysql
```

### 2. Database Configuration in Nx

**Database Connection Service:**
```typescript
// libs/shared/database/src/connection.ts
import mysql from 'mysql2/promise';

export class DatabaseService {
  private pool: mysql.Pool;

  constructor() {
    this.pool = mysql.createPool({
      uri: process.env.DATABASE_URL,
      connectionLimit: 10,
      queueLimit: 0,
      acquireTimeout: 60000,
      timeout: 60000,
      reconnect: true
    });
  }

  async query<T>(sql: string, params?: any[]): Promise<T[]> {
    const [rows] = await this.pool.execute(sql, params);
    return rows as T[];
  }

  async close(): Promise<void> {
    await this.pool.end();
  }
}

export const db = new DatabaseService();
```

### 3. Migration System

**Migration Runner:**
```typescript
// apps/api/src/migrations/runner.ts
import { db } from '@clinic/shared/database';
import fs from 'fs/promises';
import path from 'path';

export class MigrationRunner {
  private migrationsPath = path.join(__dirname, 'migrations');

  async runMigrations(): Promise<void> {
    // Create migrations table if it doesn't exist
    await db.query(`
      CREATE TABLE IF NOT EXISTS migrations (
        id INT AUTO_INCREMENT PRIMARY KEY,
        filename VARCHAR(255) NOT NULL UNIQUE,
        executed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    // Get executed migrations
    const executed = await db.query<{filename: string}>(
      'SELECT filename FROM migrations'
    );
    const executedFiles = new Set(executed.map(m => m.filename));

    // Get migration files
    const files = await fs.readdir(this.migrationsPath);
    const migrationFiles = files
      .filter(f => f.endsWith('.sql'))
      .sort();

    // Run pending migrations
    for (const file of migrationFiles) {
      if (!executedFiles.has(file)) {
        console.log(`Running migration: ${file}`);
        
        const sql = await fs.readFile(
          path.join(this.migrationsPath, file), 
          'utf-8'
        );
        
        await db.query(sql);
        await db.query(
          'INSERT INTO migrations (filename) VALUES (?)', 
          [file]
        );
        
        console.log(`Migration completed: ${file}`);
      }
    }
  }
}
```

**Sample Migration:**
```sql
-- apps/api/src/migrations/001_create_patients_table.sql
CREATE TABLE patients (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  email VARCHAR(255) UNIQUE NOT NULL,
  phone VARCHAR(20),
  date_of_birth DATE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  INDEX idx_email (email),
  INDEX idx_name (name)
);
```

## 📊 Performance Optimization for Nx on Railway

### 1. Build Optimization

**Nx Configuration:**
```json
// nx.json
{
  "tasksRunnerOptions": {
    "default": {
      "runner": "nx/tasks-runners/default",
      "options": {
        "cacheableOperations": ["build", "test", "lint"],
        "parallel": 3
      }
    }
  },
  "targetDefaults": {
    "build": {
      "cache": true,
      "dependsOn": ["^build"]
    }
  }
}
```

**Dockerfile for Optimized Builds:**
```dockerfile
# Dockerfile.api
FROM node:18-alpine AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./
COPY nx.json ./
COPY tsconfig.base.json ./

# Install dependencies
RUN npm ci --only=production && npm cache clean --force

# Copy source code
COPY apps/api apps/api
COPY libs libs

# Build the application
RUN npx nx build api --prod

# Production image
FROM node:18-alpine

WORKDIR /app

# Copy built application
COPY --from=builder /app/dist/apps/api ./
COPY --from=builder /app/node_modules ./node_modules

# Expose port
EXPOSE 8080

# Start application
CMD ["node", "main.js"]
```

### 2. Shared Dependencies Optimization

**Package.json Organization:**
```json
{
  "dependencies": {
    "@clinic/shared": "workspace:*",
    "express": "^4.18.2",
    "mysql2": "^3.6.0",
    "cors": "^2.8.5",
    "helmet": "^7.0.0"
  },
  "devDependencies": {
    "@nx/node": "^16.5.0",
    "@types/express": "^4.17.17",
    "typescript": "^5.1.6"
  }
}
```

### 3. Monitoring and Debugging

**Health Check Implementation:**
```typescript
// apps/api/src/health/health.controller.ts
import { Router, Request, Response } from 'express';
import { db } from '@clinic/shared/database';

const router = Router();

router.get('/health', async (req: Request, res: Response) => {
  try {
    // Check database connectivity
    await db.query('SELECT 1');
    
    const health = {
      status: 'healthy',
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
      memory: process.memoryUsage(),
      environment: process.env.NODE_ENV,
      version: process.env.npm_package_version
    };
    
    res.status(200).json(health);
  } catch (error) {
    res.status(503).json({
      status: 'unhealthy',
      error: error.message,
      timestamp: new Date().toISOString()
    });
  }
});

export { router as healthRouter };
```

## 🚦 Troubleshooting Nx Deployments

### Common Issues and Solutions

#### 1. Build Path Issues

**Problem:** Nx can't find built assets
```bash
Error: Cannot find module './dist/apps/api/main.js'
```

**Solution:**
```toml
# Ensure correct build paths in railway.toml
[build]
buildCommand = "npx nx build api --prod --outputPath=dist/apps/api"

[deploy]
startCommand = "node dist/apps/api/main.js"
```

#### 2. Shared Library Resolution

**Problem:** Shared libraries not found during build
```bash
Error: Cannot resolve '@clinic/shared/types'
```

**Solution:**
```json
// tsconfig.base.json
{
  "compilerOptions": {
    "paths": {
      "@clinic/shared/types": ["libs/shared/types/src/index.ts"],
      "@clinic/shared/utils": ["libs/shared/utils/src/index.ts"],
      "@clinic/shared/database": ["libs/shared/database/src/index.ts"]
    }
  }
}
```

#### 3. Environment Variable Access

**Problem:** Environment variables not accessible in Nx apps

**Solution:**
```typescript
// apps/web/vite.config.ts
export default defineConfig({
  define: {
    'process.env.VITE_API_URL': JSON.stringify(process.env.VITE_API_URL)
  }
});
```

---

## 🔗 Navigation

**← Previous:** [Pricing Model Analysis](./pricing-model-analysis.md) | **Next:** [Resource Consumption Analysis](./resource-consumption-analysis.md) →

---

## 📚 Additional Resources

- [Nx Documentation](https://nx.dev/)
- [Railway Monorepo Guide](https://docs.railway.app/guides/monorepo)
- [Nx and Railway Integration](https://blog.railway.app/p/deploying-nx-monorepos)
- [Nx Build Optimization](https://nx.dev/concepts/more-concepts/build-caching)