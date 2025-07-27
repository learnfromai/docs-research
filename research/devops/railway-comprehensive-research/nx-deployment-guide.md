# Nx Deployment Guide: Deploying Monorepo with Separate Frontend and Backend

## 🎯 Overview

This guide covers deploying an Nx monorepo to Railway with separate `apps/web` (React/Vite frontend) and `apps/api` (Express.js backend) applications, along with shared libraries and proper CI/CD configuration.

## 🏗️ Nx Workspace Structure

### Typical Clinic Management Nx Workspace
```
clinic-management/
├── apps/
│   ├── web/                 # React frontend (Vite)
│   │   ├── src/
│   │   ├── project.json
│   │   └── vite.config.ts
│   ├── api/                 # Express.js backend
│   │   ├── src/
│   │   ├── project.json
│   │   └── webpack.config.js
│   └── mobile/              # Future React Native app
├── libs/
│   ├── shared/
│   │   ├── types/           # TypeScript interfaces
│   │   ├── utils/           # Utility functions
│   │   └── constants/       # Shared constants
│   ├── ui/                  # Shared UI components
│   └── data-access/         # API client libraries
├── tools/
├── nx.json
├── package.json
└── tsconfig.base.json
```

## 🚀 Railway Deployment Strategy

### Multi-Service Architecture
Deploy each Nx application as a separate Railway service:

```mermaid
graph LR
    A[GitHub Repo] --> B[Railway Project]
    B --> C[Frontend Service]
    B --> D[Backend Service]
    B --> E[Database Service]
    C --> F[web.clinic.com]
    D --> G[api.clinic.com]
```

### Service Configuration Overview
| Service | Nx App | Railway Role | Domain |
|---------|--------|--------------|--------|
| Frontend | `apps/web` | Static/SPA hosting | `web.clinic.com` |
| Backend | `apps/api` | API server | `api.clinic.com` |
| Database | N/A | MySQL service | Internal |

## 📁 Step-by-Step Deployment Process

### Step 1: Prepare Nx Workspace for Railway

#### 1.1 Configure Build Outputs
Update your `nx.json` to ensure clean build outputs:

```json
{
  "targetDefaults": {
    "build": {
      "cache": true,
      "dependsOn": ["^build"],
      "inputs": ["production", "^production"]
    }
  },
  "namedInputs": {
    "production": [
      "default",
      "!{projectRoot}/**/?(*.)+(spec|test).[jt]s?(x)?(.snap)",
      "!{projectRoot}/tsconfig.spec.json",
      "!{projectRoot}/jest.config.[jt]s",
      "!{projectRoot}/.eslintrc.json"
    ]
  }
}
```

#### 1.2 Frontend Configuration (`apps/web`)
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
          "mode": "production"
        }
      }
    },
    "serve": {
      "executor": "@nx/vite:dev-server",
      "defaultConfiguration": "development",
      "options": {
        "buildTarget": "web:build"
      }
    }
  }
}
```

#### 1.3 Backend Configuration (`apps/api`)
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
        "tsConfig": "apps/api/tsconfig.app.json"
      },
      "configurations": {
        "production": {
          "optimization": true,
          "extractLicenses": true,
          "inspect": false
        }
      }
    },
    "serve": {
      "executor": "@nx/js:node",
      "defaultConfiguration": "development",
      "options": {
        "buildTarget": "api:build"
      }
    }
  }
}
```

### Step 2: Create Railway Services

#### 2.1 Initialize Railway Project
```bash
# Install Railway CLI
npm install -g @railway/cli

# Login to Railway
railway login

# Create new project
railway init
# Choose: "Empty Project"
# Name: "clinic-management"
```

#### 2.2 Create Frontend Service
```bash
# Create frontend service
railway service create web

# Link to the service
railway link --service web

# Set build configuration
railway variables set NODE_ENV=production
railway variables set NX_APP_NAME=web
```

#### 2.3 Create Backend Service  
```bash
# Create backend service
railway service create api

# Link to the service  
railway link --service api

# Set build configuration
railway variables set NODE_ENV=production
railway variables set NX_APP_NAME=api
```

### Step 3: Configure Railway Build Settings

#### 3.1 Frontend Service Configuration
Create `railway.toml` in project root:

```toml
# railway.toml
[environments.production.services.web]
  build = """
    npm ci
    npx nx build web --prod
  """
  start = """
    npx serve dist/apps/web -s -l 3000
  """
  variables = { NODE_ENV = "production" }

[environments.production.services.api]  
  build = """
    npm ci
    npx nx build api --prod
  """
  start = """
    node dist/apps/api/main.js
  """
  variables = { NODE_ENV = "production" }
```

#### 3.2 Alternative: Individual Service Configuration
For more granular control, create separate configs:

**Frontend (`railway-web.json`):**
```json
{
  "$schema": "https://railway.app/railway.schema.json",
  "build": {
    "builder": "NIXPACKS",
    "buildCommand": "npm ci && npx nx build web --prod"
  },
  "deploy": {
    "startCommand": "npx serve dist/apps/web -s -l $PORT",
    "healthcheckPath": "/",
    "healthcheckTimeout": 100,
    "restartPolicyType": "ON_FAILURE"
  }
}
```

**Backend (`railway-api.json`):**
```json
{
  "$schema": "https://railway.app/railway.schema.json", 
  "build": {
    "builder": "NIXPACKS",
    "buildCommand": "npm ci && npx nx build api --prod"
  },
  "deploy": {
    "startCommand": "node dist/apps/api/main.js",
    "healthcheckPath": "/health",
    "healthcheckTimeout": 300,
    "restartPolicyType": "ON_FAILURE"
  }
}
```

### Step 4: Environment Configuration

#### 4.1 Frontend Environment Variables
```bash
# Railway frontend service variables
railway variables set VITE_API_URL=${{ api.RAILWAY_PUBLIC_DOMAIN }}
railway variables set VITE_APP_ENV=production
railway variables set VITE_APP_NAME="Clinic Management"
```

#### 4.2 Backend Environment Variables
```bash
# Railway backend service variables
railway variables set DATABASE_URL=${{ MySQL.DATABASE_URL }}
railway variables set FRONTEND_URL=${{ web.RAILWAY_PUBLIC_DOMAIN }}
railway variables set JWT_SECRET=${{ JWT_SECRET }}
railway variables set PORT=${{ PORT }}
```

#### 4.3 Shared Environment Configuration
Create `.env.railway` for Railway-specific variables:
```bash
# .env.railway
NODE_ENV=production
RAILWAY_ENVIRONMENT=production

# Frontend specific
VITE_API_URL=https://api-production.up.railway.app
VITE_APP_ENV=production

# Backend specific  
DATABASE_URL=mysql://user:pass@host:port/clinic_db
CORS_ORIGIN=https://web-production.up.railway.app
```

### Step 5: Database Integration

#### 5.1 Add MySQL Service
```bash
# Create MySQL database service
railway service create mysql
railway service connect mysql

# Database will auto-generate DATABASE_URL variable
```

#### 5.2 Database Configuration in Backend
```typescript
// apps/api/src/database/config.ts
import { DataSource } from 'typeorm';

export const AppDataSource = new DataSource({
  type: 'mysql',
  url: process.env.DATABASE_URL,
  synchronize: process.env.NODE_ENV !== 'production',
  logging: process.env.NODE_ENV === 'development',
  entities: ['dist/**/*.entity.js'],
  migrations: ['dist/migrations/*.js'],
  ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false
});
```

#### 5.3 Database Migrations
```typescript
// apps/api/src/migrations/run-migrations.ts
import { AppDataSource } from '../database/config';

async function runMigrations() {
  await AppDataSource.initialize();
  await AppDataSource.runMigrations();
  console.log('Migrations completed');
  process.exit(0);
}

if (process.env.RUN_MIGRATIONS === 'true') {
  runMigrations();
}
```

### Step 6: Nx Build Optimization for Railway

#### 6.1 Optimize Build Performance
```json
// nx.json - Railway-specific optimizations
{
  "tasksRunnerOptions": {
    "default": {
      "runner": "nx/tasks-runners/default",
      "options": {
        "cacheableOperations": ["build", "lint", "test"],
        "parallel": 2,
        "maxParallel": 3
      }
    }
  }
}
```

#### 6.2 Build Scripts Optimization
```json
// package.json
{
  "scripts": {
    "build:web": "nx build web --prod",
    "build:api": "nx build api --prod", 
    "build:all": "nx run-many --target=build --projects=web,api --prod",
    "railway:build:web": "npm ci && npm run build:web",
    "railway:build:api": "npm ci && npm run build:api"
  }
}
```

#### 6.3 Dockerfile Alternative (Optional)
For more control, use multi-stage Docker builds:

```dockerfile
# Dockerfile.web
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
COPY nx.json ./
COPY tsconfig*.json ./
COPY apps/web apps/web
COPY libs libs
RUN npm ci
RUN npx nx build web --prod

FROM nginx:alpine
COPY --from=builder /app/dist/apps/web /usr/share/nginx/html
COPY apps/web/nginx.conf /etc/nginx/nginx.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

```dockerfile
# Dockerfile.api
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
COPY nx.json ./
COPY tsconfig*.json ./
COPY apps/api apps/api
COPY libs libs
RUN npm ci
RUN npx nx build api --prod

FROM node:18-alpine
WORKDIR /app
COPY --from=builder /app/dist/apps/api ./
COPY --from=builder /app/package*.json ./
RUN npm ci --only=production
EXPOSE 3000
CMD ["node", "main.js"]
```

## 🔄 CI/CD Pipeline Integration

### GitHub Actions with Railway
```yaml
# .github/workflows/railway-deploy.yml
name: Deploy to Railway

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Setup Node.js
      uses: actions/setup-node@v3
      with:
        node-version: '18'
        cache: 'npm'
    
    - name: Install dependencies
      run: npm ci
    
    - name: Run tests
      run: |
        npx nx run-many --target=test --projects=web,api
        npx nx run-many --target=lint --projects=web,api
    
    - name: Build applications
      run: |
        npx nx build web --prod
        npx nx build api --prod
    
    - name: Deploy to Railway
      uses: railway/railway@v1
      with:
        railway-token: ${{ secrets.RAILWAY_TOKEN }}
        service: web
        project-id: ${{ secrets.RAILWAY_PROJECT_ID }}
        
    - name: Deploy API to Railway  
      uses: railway/railway@v1
      with:
        railway-token: ${{ secrets.RAILWAY_TOKEN }}
        service: api
        project-id: ${{ secrets.RAILWAY_PROJECT_ID }}
```

## 🔧 Troubleshooting Common Issues

### Issue 1: Build Failures
```bash
# Check Nx cache and dependencies
nx reset
rm -rf node_modules package-lock.json
npm install

# Test builds locally
nx build web --prod
nx build api --prod
```

### Issue 2: Service Communication
```typescript
// Ensure proper CORS configuration
app.use(cors({
  origin: process.env.FRONTEND_URL || 'http://localhost:4200',
  credentials: true
}));
```

### Issue 3: Database Connection Issues
```typescript
// Check connection and retry logic
const connectWithRetry = async () => {
  try {
    await AppDataSource.initialize();
    console.log('Database connected successfully');
  } catch (error) {
    console.error('Database connection failed, retrying in 5s...', error);
    setTimeout(connectWithRetry, 5000);
  }
};
```

## 📊 Performance Optimization

### Build Performance
```json
// nx.json - Optimize for Railway builds
{
  "targetDefaults": {
    "build": {
      "cache": true,
      "inputs": ["production", "^production"],
      "outputs": ["{workspaceRoot}/dist"]
    }
  }
}
```

### Runtime Performance
```typescript
// apps/api/src/main.ts - Production optimizations
if (process.env.NODE_ENV === 'production') {
  app.use(compression());
  app.use(helmet());
  app.use(rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 100 // limit each IP to 100 requests per windowMs
  }));
}
```

---

## 🔗 Navigation

← [Previous: Resource Management](./resource-management.md) | [Next: Clinic Management Case Study](./clinic-management-case-study.md) →