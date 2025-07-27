# Nx Deployment Guide for Railway.com

## Overview

This guide provides step-by-step instructions for deploying Nx monorepo applications to Railway.com, specifically covering how to deploy separate `apps/api` (Express.js backend) and `apps/web` (React/Vite frontend) applications from a single repository.

## Prerequisites

### Nx Workspace Structure
```
nx-workspace/
├── apps/
│   ├── web/                 # React/Vite frontend
│   │   ├── src/
│   │   ├── project.json
│   │   └── vite.config.ts
│   └── api/                 # Express.js backend
│       ├── src/
│       ├── project.json
│       └── webpack.config.js
├── libs/                    # Shared libraries
├── nx.json
├── package.json
└── railway.toml            # Railway configuration
```

### Required Tools
- **Node.js** 18+ and npm/yarn
- **Nx CLI**: `npm install -g nx`
- **Railway CLI**: `npm install -g @railway/cli`
- **Git** repository connected to GitHub/GitLab

## Railway Multi-Service Configuration

### 1. Create Railway Configuration File

Create `railway.toml` in your workspace root:

```toml
[build]
builder = "NIXPACKS"
buildCommand = "npm run build"

[deploy]
startCommand = "npm run start"
healthcheckPath = "/"
healthcheckTimeout = 300
restartPolicyType = "ON_FAILURE"
restartPolicyMaxRetries = 10

# Frontend Service (React/Vite)
[environments.production.services.web]
source = "."
buildCommand = "npx nx build web --prod"
startCommand = "npx nx serve web --prod --port=$PORT"
variables = { NODE_ENV = "production" }

# Backend Service (Express.js)
[environments.production.services.api]
source = "."
buildCommand = "npx nx build api --prod"
startCommand = "npx nx serve api --prod --port=$PORT"
variables = { NODE_ENV = "production" }

# Database Service
[environments.production.services.database]
image = "mysql:8.0"
variables = { MYSQL_ROOT_PASSWORD = "${{MYSQL_ROOT_PASSWORD}}" }
```

### 2. Alternative Approach: Separate Services

Instead of `railway.toml`, you can create separate Railway services manually:

#### Service 1: Frontend (apps/web)
```bash
# Create new Railway project for frontend
railway login
railway new nx-frontend
railway link

# Configure build settings
railway variables set NODE_ENV=production
railway variables set BUILD_COMMAND="npx nx build web --prod"
railway variables set START_COMMAND="npx nx serve web --prod --port=$PORT"
```

#### Service 2: Backend (apps/api)
```bash
# Create new Railway service for backend
railway service create api

# Configure build settings  
railway variables set NODE_ENV=production
railway variables set BUILD_COMMAND="npx nx build api --prod"
railway variables set START_COMMAND="npx nx serve api --prod --port=$PORT"
```

## Nx Configuration Updates

### 1. Update Frontend Project Configuration

Update `apps/web/project.json`:

```json
{
  "name": "web",
  "targets": {
    "build": {
      "executor": "@nx/vite:build",
      "options": {
        "outputPath": "dist/apps/web"
      },
      "configurations": {
        "production": {
          "mode": "production",
          "optimization": true,
          "buildLibsFromSource": false
        }
      }
    },
    "serve": {
      "executor": "@nx/vite:dev-server",
      "options": {
        "buildTarget": "web:build",
        "port": 3000
      },
      "configurations": {
        "production": {
          "buildTarget": "web:build:production",
          "mode": "production"
        }
      }
    }
  }
}
```

### 2. Update Backend Project Configuration

Update `apps/api/project.json`:

```json
{
  "name": "api",
  "targets": {
    "build": {
      "executor": "@nx/webpack:webpack",
      "options": {
        "outputPath": "dist/apps/api",
        "main": "apps/api/src/main.ts",
        "tsConfig": "apps/api/tsconfig.app.json",
        "target": "node",
        "compiler": "tsc"
      },
      "configurations": {
        "production": {
          "optimization": true,
          "extractLicenses": true,
          "inspect": false,
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
      "options": {
        "buildTarget": "api:build",
        "port": 3333
      },
      "configurations": {
        "production": {
          "buildTarget": "api:build:production"
        }
      }
    }
  }
}
```

## Package.json Scripts Configuration

Add Railway-specific scripts to your root `package.json`:

```json
{
  "scripts": {
    "build": "nx run-many --target=build --all --prod",
    "build:web": "nx build web --prod",
    "build:api": "nx build api --prod",
    "start": "node dist/apps/api/main.js",
    "start:web": "nx serve web --prod --port=$PORT",
    "start:api": "nx serve api --prod --port=$PORT",
    "railway:build": "npm install && nx build api --prod",
    "railway:start": "node dist/apps/api/main.js"
  }
}
```

## Environment Variables Configuration

### 1. Shared Variables
Set these environment variables for both frontend and backend services:

```bash
# Database connection
DATABASE_URL=mysql://user:password@host:port/database
MYSQL_HOST=railway-mysql-host
MYSQL_PORT=3306
MYSQL_DATABASE=clinic_db
MYSQL_USER=root
MYSQL_PASSWORD=${{MYSQL_ROOT_PASSWORD}}

# Application settings
NODE_ENV=production
PORT=$PORT
API_URL=https://your-api-service.railway.app
```

### 2. Frontend-Specific Variables

```bash
# apps/web environment variables
VITE_API_URL=https://your-api-service.railway.app
VITE_APP_NAME=Clinic Management System
```

### 3. Backend-Specific Variables

```bash
# apps/api environment variables
CORS_ORIGIN=https://your-frontend-service.railway.app
JWT_SECRET=${{JWT_SECRET}}
SESSION_SECRET=${{SESSION_SECRET}}
```

## Deployment Process

### Method 1: Automatic Deployment via Git

1. **Connect Repository to Railway**
   ```bash
   railway login
   railway new nx-clinic-app
   railway link
   ```

2. **Configure Services**
   ```bash
   # Create frontend service
   railway service create web
   railway service create api
   railway service create mysql
   ```

3. **Set Build Commands**
   ```bash
   # For frontend service
   railway variables set BUILD_COMMAND="npx nx build web --prod"
   railway variables set START_COMMAND="npx nx serve web --prod --port=\$PORT"
   
   # For backend service
   railway variables set BUILD_COMMAND="npx nx build api --prod"
   railway variables set START_COMMAND="node dist/apps/api/main.js"
   ```

4. **Deploy**
   ```bash
   git add .
   git commit -m "Configure Railway deployment"
   git push origin main
   ```

### Method 2: Manual Deployment via Railway CLI

1. **Build Applications Locally**
   ```bash
   nx build web --prod
   nx build api --prod
   ```

2. **Deploy Frontend**
   ```bash
   railway service select web
   railway up --detach
   ```

3. **Deploy Backend**
   ```bash
   railway service select api
   railway up --detach
   ```

## Database Setup

### 1. Create MySQL Service
```bash
railway service create mysql
railway variables set MYSQL_ROOT_PASSWORD=$(openssl rand -base64 32)
railway variables set MYSQL_DATABASE=clinic_db
```

### 2. Configure Database Connection

Create `libs/database/src/config.ts`:

```typescript
import { createConnection } from 'mysql2/promise';

export const databaseConfig = {
  host: process.env.MYSQL_HOST,
  port: parseInt(process.env.MYSQL_PORT || '3306'),
  user: process.env.MYSQL_USER,
  password: process.env.MYSQL_PASSWORD,
  database: process.env.MYSQL_DATABASE,
  ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false
};

export async function createDatabaseConnection() {
  try {
    const connection = await createConnection(databaseConfig);
    console.log('Database connected successfully');
    return connection;
  } catch (error) {
    console.error('Database connection failed:', error);
    throw error;
  }
}
```

### 3. Update Backend to Use Database

Update `apps/api/src/main.ts`:

```typescript
import express from 'express';
import cors from 'cors';
import { createDatabaseConnection } from '@nx-clinic/database';

const app = express();
const PORT = process.env.PORT || 3333;

// Middleware
app.use(cors({
  origin: process.env.CORS_ORIGIN || 'http://localhost:3000'
}));
app.use(express.json());

// Initialize database connection
let db: any;
createDatabaseConnection().then(connection => {
  db = connection;
  console.log('Database initialized');
});

// Routes
app.get('/api/health', (req, res) => {
  res.json({ status: 'OK', timestamp: new Date().toISOString() });
});

app.get('/api/patients', async (req, res) => {
  try {
    const [rows] = await db.execute('SELECT * FROM patients');
    res.json(rows);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
```

## Service Communication

### 1. Private Networking
Railway provides private networking between services in the same project:

```typescript
// In your frontend, use the Railway service URL
const API_BASE_URL = process.env.VITE_API_URL || 'http://localhost:3333';

// API calls
async function fetchPatients() {
  const response = await fetch(`${API_BASE_URL}/api/patients`);
  return response.json();
}
```

### 2. Service Discovery

Railway automatically provides internal URLs for service communication:
- Frontend: `https://web-production.railway.app`
- Backend: `https://api-production.railway.app`
- Database: `mysql://user:pass@host:port/db`

## Production Optimizations

### 1. Build Optimizations

Create `apps/web/vite.config.ts`:

```typescript
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { nxViteTsPaths } from '@nx/vite/plugins/nx-tsconfig-paths.plugin';

export default defineConfig({
  plugins: [react(), nxViteTsPaths()],
  build: {
    outDir: '../../dist/apps/web',
    minify: true,
    sourcemap: false,
    rollupOptions: {
      output: {
        manualChunks: {
          vendor: ['react', 'react-dom'],
          utils: ['lodash', 'date-fns']
        }
      }
    }
  },
  server: {
    port: 3000,
    host: '0.0.0.0'
  }
});
```

### 2. Dockerfile for Advanced Configuration

Create `Dockerfile` for custom build process:

```dockerfile
FROM node:18-alpine AS builder

WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

COPY . .
RUN npx nx build api --prod

FROM node:18-alpine AS runtime

WORKDIR /app
COPY --from=builder /app/dist/apps/api ./
COPY --from=builder /app/node_modules ./node_modules

EXPOSE 3333

CMD ["node", "main.js"]
```

## Monitoring and Logging

### 1. Health Check Endpoints

Add to `apps/api/src/main.ts`:

```typescript
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    memory: process.memoryUsage(),
    environment: process.env.NODE_ENV
  });
});
```

### 2. Error Handling and Logging

```typescript
import winston from 'winston';

const logger = winston.createLogger({
  level: 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
  ),
  transports: [
    new winston.transports.Console(),
    new winston.transports.File({ filename: 'error.log', level: 'error' }),
    new winston.transports.File({ filename: 'combined.log' })
  ]
});

// Use in your routes
app.use((error, req, res, next) => {
  logger.error('Unhandled error:', error);
  res.status(500).json({ error: 'Internal server error' });
});
```

## Troubleshooting Common Issues

### 1. Build Failures
```bash
# Clear Nx cache
nx reset

# Check build locally
nx build web --prod
nx build api --prod

# Verify output directories
ls -la dist/apps/
```

### 2. Service Communication Issues
```bash
# Check environment variables
railway variables

# Test API connectivity
curl https://your-api-service.railway.app/health

# Check service logs
railway logs --tail
```

### 3. Database Connection Issues
```bash
# Verify database variables
railway variables | grep MYSQL

# Test database connection
railway run mysql -h $MYSQL_HOST -u $MYSQL_USER -p$MYSQL_PASSWORD
```

## Cost Optimization for Nx Deployments

### 1. Shared Dependencies
- Use Nx's shared libraries to reduce bundle sizes
- Implement code splitting for frontend applications
- Share database connections between API endpoints

### 2. Efficient Builds
- Enable Nx build caching: `"cacheDirectory": ".nx/cache"`
- Use affected builds: `nx affected:build --prod`
- Optimize Docker layers for faster deployments

### 3. Resource Right-sizing
- Monitor CPU and memory usage via Railway dashboard
- Adjust service resources based on actual usage
- Use auto-scaling for variable traffic patterns

---

## Next Steps

1. **[Set Up MySQL Database](./mysql-database-deployment.md)** - Database configuration details
2. **[Review Best Practices](./best-practices.md)** - Production deployment strategies
3. **[Check Troubleshooting Guide](./troubleshooting.md)** - Common issues and solutions

---

*Nx Deployment Guide | Railway.com Platform | January 2025*