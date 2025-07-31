# Nx Monorepo Deployment Guide for Railway.com

This guide provides step-by-step instructions for deploying Nx monorepo projects on Railway.com, specifically focusing on projects with separate frontend (React/Vite) and backend (Express.js) applications.

## Prerequisites

### Required Tools
- [Node.js](https://nodejs.org/) 18+ installed
- [Nx CLI](https://nx.dev/getting-started/installation) installed globally
- [Railway CLI](https://docs.railway.app/develop/cli) installed
- Git repository with your Nx workspace
- Railway account with appropriate subscription

### Nx Workspace Structure
```
my-clinic-app/
├── apps/
│   ├── web/                 # React/Vite frontend application
│   │   ├── src/
│   │   ├── vite.config.ts
│   │   └── project.json
│   └── api/                 # Express.js backend application
│       ├── src/
│       ├── webpack.config.js
│       └── project.json
├── libs/                    # Shared libraries
│   ├── shared-types/        # TypeScript interfaces
│   ├── shared-utils/        # Common utilities
│   └── ui-components/       # Reusable UI components
├── nx.json
├── package.json
└── workspace.json
```

## Railway Project Setup

### 1. Initialize Railway Project
```bash
# Login to Railway
railway login

# Create new Railway project
railway init

# Link to existing project (if already created)
railway link [project-id]
```

### 2. Create Railway Services
You'll need to create separate Railway services for each application:

1. **Frontend Service** (`apps/web`)
2. **Backend Service** (`apps/api`)
3. **Database Service** (MySQL)

## Frontend Deployment (React/Vite)

### 1. Configure Build Process

#### Update `apps/web/vite.config.ts`
```typescript
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { nxViteTsPaths } from '@nx/vite/plugins/nx-tsconfig-paths.plugin';

export default defineConfig({
  root: __dirname,
  cacheDir: '../../node_modules/.vite/web',
  
  server: {
    port: 4200,
    host: 'localhost',
  },

  preview: {
    port: 4300,
    host: 'localhost',
  },

  plugins: [react(), nxViteTsPaths()],

  // Build configuration for Railway
  build: {
    outDir: '../../dist/apps/web',
    reportCompressedSize: true,
    commonjsOptions: {
      transformMixedEsModules: true,
    },
  },

  // Environment variables for API connection
  define: {
    'process.env.VITE_API_URL': JSON.stringify(
      process.env.VITE_API_URL || 'http://localhost:3333/api'
    ),
  },
});
```

#### Update `apps/web/project.json`
```json
{
  "name": "web",
  "$schema": "../../node_modules/nx/schemas/project-schema.json",
  "projectType": "application",
  "sourceRoot": "apps/web/src",
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
          "mode": "development"
        },
        "production": {
          "mode": "production"
        }
      }
    }
  }
}
```

### 2. Create Railway Configuration for Frontend

#### Create `railway.json` in project root
```json
{
  "deploy": {
    "startCommand": "npx nx build web && npx serve -s dist/apps/web -p $PORT",
    "restartPolicyType": "ON_FAILURE",
    "restartPolicyMaxRetries": 10
  }
}
```

#### Alternative: Create `Dockerfile` for Frontend
```dockerfile
# Frontend Dockerfile (apps/web/Dockerfile)
FROM node:18-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./
COPY nx.json ./
COPY workspace.json ./

# Install dependencies
RUN npm ci --only=production

# Copy source code
COPY apps/web ./apps/web
COPY libs ./libs

# Build the application
RUN npx nx build web

# Install serve for static hosting
RUN npm install -g serve

# Expose port
EXPOSE $PORT

# Start the application
CMD ["serve", "-s", "dist/apps/web", "-p", "$PORT"]
```

### 3. Deploy Frontend to Railway

```bash
# Create and deploy frontend service
railway up --detach

# Set environment variables
railway variables set VITE_API_URL=https://your-api-service.railway.app/api

# Deploy
railway deploy
```

## Backend Deployment (Express.js)

### 1. Configure Backend Application

#### Update `apps/api/src/main.ts`
```typescript
import express from 'express';
import cors from 'cors';
import { json, urlencoded } from 'express';

const app = express();

// Middleware
app.use(cors({
  origin: process.env.FRONTEND_URL || 'http://localhost:4200',
  credentials: true
}));

app.use(json());
app.use(urlencoded({ extended: true }));

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'OK', timestamp: new Date().toISOString() });
});

// API routes
app.use('/api', require('./routes'));

// Start server
const port = process.env.PORT || 3333;
app.listen(port, () => {
  console.log(`Listening at http://localhost:${port}/api`);
});
```

#### Update `apps/api/project.json`
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
        "buildTarget": "api:build"
      }
    }
  }
}
```

### 2. Create Railway Configuration for Backend

#### Create separate `railway.json` for API
```json
{
  "deploy": {
    "startCommand": "npx nx build api && node dist/apps/api/main.js",
    "restartPolicyType": "ON_FAILURE",
    "restartPolicyMaxRetries": 10
  }
}
```

#### Alternative: Create `Dockerfile` for Backend
```dockerfile
# Backend Dockerfile (apps/api/Dockerfile)
FROM node:18-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./
COPY nx.json ./
COPY workspace.json ./

# Install dependencies
RUN npm ci --only=production

# Copy source code
COPY apps/api ./apps/api
COPY libs ./libs

# Build the application
RUN npx nx build api

# Expose port
EXPOSE $PORT

# Start the application
CMD ["node", "dist/apps/api/main.js"]
```

### 3. Deploy Backend to Railway

```bash
# Create separate service for backend
railway service create api

# Deploy backend
railway up --service api

# Set environment variables
railway variables set NODE_ENV=production
railway variables set DATABASE_URL=${{MySQL.DATABASE_URL}}
railway variables set FRONTEND_URL=https://your-frontend-service.railway.app
```

## Database Setup (MySQL)

### 1. Create MySQL Database Service

```bash
# Add MySQL database to project
railway add mysql

# Get database credentials
railway variables
```

### 2. Configure Database Connection

#### Create Database Configuration
```typescript
// libs/shared-config/src/lib/database.ts
import mysql from 'mysql2/promise';

export const createConnection = async () => {
  const connection = await mysql.createConnection({
    host: process.env.MYSQLHOST,
    port: parseInt(process.env.MYSQLPORT || '3306'),
    user: process.env.MYSQLUSER,
    password: process.env.MYSQLPASSWORD,
    database: process.env.MYSQLDATABASE,
    ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false
  });

  return connection;
};

// Database initialization
export const initializeDatabase = async () => {
  const connection = await createConnection();
  
  // Create tables if they don't exist
  await connection.execute(`
    CREATE TABLE IF NOT EXISTS patients (
      id INT AUTO_INCREMENT PRIMARY KEY,
      name VARCHAR(255) NOT NULL,
      email VARCHAR(255) UNIQUE,
      phone VARCHAR(20),
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  `);

  await connection.end();
};
```

#### Update Backend to Use Database
```typescript
// apps/api/src/routes/patients.ts
import { Router } from 'express';
import { createConnection } from '@my-clinic-app/shared-config';

const router = Router();

router.get('/patients', async (req, res) => {
  try {
    const connection = await createConnection();
    const [rows] = await connection.execute('SELECT * FROM patients');
    await connection.end();
    
    res.json(rows);
  } catch (error) {
    console.error('Database error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/patients', async (req, res) => {
  try {
    const { name, email, phone } = req.body;
    const connection = await createConnection();
    
    const [result] = await connection.execute(
      'INSERT INTO patients (name, email, phone) VALUES (?, ?, ?)',
      [name, email, phone]
    );
    
    await connection.end();
    res.json({ id: (result as any).insertId, name, email, phone });
  } catch (error) {
    console.error('Database error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

export default router;
```

## Environment Variables Management

### 1. Frontend Environment Variables
```bash
# Frontend service variables
railway variables set VITE_API_URL=https://your-api-service.railway.app
railway variables set VITE_APP_NAME="Clinic Management System"
```

### 2. Backend Environment Variables
```bash
# Backend service variables
railway variables set NODE_ENV=production
railway variables set PORT=3333
railway variables set FRONTEND_URL=https://your-frontend-service.railway.app

# Database connection (automatically provided by Railway)
# DATABASE_URL, MYSQLHOST, MYSQLPORT, MYSQLUSER, MYSQLPASSWORD, MYSQLDATABASE
```

### 3. Shared Environment Configuration
Create environment-specific configuration in your Nx workspace:

```typescript
// libs/shared-config/src/lib/environment.ts
export const environment = {
  production: process.env.NODE_ENV === 'production',
  apiUrl: process.env.VITE_API_URL || process.env.API_URL,
  databaseUrl: process.env.DATABASE_URL,
  frontendUrl: process.env.FRONTEND_URL,
};
```

## Deployment Workflows

### 1. Automated Deployment with GitHub

#### Set up GitHub Integration
```bash
# Connect Railway to GitHub repository
railway connect github

# Enable automatic deployments
railway settings
```

#### Create GitHub Actions Workflow (Optional)
```yaml
# .github/workflows/deploy.yml
name: Deploy to Railway

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Use Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'
          cache: 'npm'
      
      - name: Install dependencies
        run: npm ci
      
      - name: Build applications
        run: |
          npx nx build web
          npx nx build api
      
      - name: Deploy to Railway
        uses: railwayapp/railway-deploy-action@v1
        with:
          railway-token: ${{ secrets.RAILWAY_TOKEN }}
```

### 2. Manual Deployment Process

```bash
# Build and deploy frontend
railway service select frontend
npx nx build web
railway up

# Build and deploy backend
railway service select api  
npx nx build api
railway up

# Check deployment status
railway status
railway logs
```

## Scaling and Performance Considerations

### 1. Resource Allocation

#### Frontend Scaling
- **Static Assets**: Automatically cached by Railway's CDN
- **Build Time**: Optimize Nx build caching for faster deployments
- **Bundle Size**: Use code splitting and lazy loading

#### Backend Scaling
- **Horizontal Scaling**: Railway automatically scales based on traffic
- **Connection Pooling**: Implement database connection pooling
- **Caching**: Add Redis for session and API response caching

### 2. Database Optimization

#### Connection Management
```typescript
// Implement connection pooling
import mysql from 'mysql2/promise';

const pool = mysql.createPool({
  host: process.env.MYSQLHOST,
  port: parseInt(process.env.MYSQLPORT || '3306'),
  user: process.env.MYSQLUSER,
  password: process.env.MYSQLPASSWORD,
  database: process.env.MYSQLDATABASE,
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0
});

export { pool };
```

#### Query Optimization
```typescript
// Use prepared statements and indexes
const getPatientsByClinic = async (clinicId: number) => {
  const [rows] = await pool.execute(
    'SELECT * FROM patients WHERE clinic_id = ? ORDER BY created_at DESC',
    [clinicId]
  );
  return rows;
};
```

## Monitoring and Debugging

### 1. Railway Dashboard
- **Service Status**: Monitor service health and uptime
- **Resource Usage**: Track CPU, memory, and storage consumption
- **Logs**: Real-time application logs and error tracking

### 2. Application Logging
```typescript
// Structured logging for better debugging
import winston from 'winston';

const logger = winston.createLogger({
  level: 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
  ),
  transports: [
    new winston.transports.Console(),
  ],
});

// Use in application
logger.info('Patient created', { patientId: 123, clinicId: 456 });
logger.error('Database connection failed', { error: error.message });
```

### 3. Health Checks
```typescript
// Implement comprehensive health checks
app.get('/health', async (req, res) => {
  try {
    // Check database connection
    const connection = await createConnection();
    await connection.ping();
    await connection.end();
    
    res.json({
      status: 'healthy',
      timestamp: new Date().toISOString(),
      database: 'connected',
      memory: process.memoryUsage(),
      uptime: process.uptime()
    });
  } catch (error) {
    res.status(503).json({
      status: 'unhealthy',
      error: error.message,
      timestamp: new Date().toISOString()
    });
  }
});
```

## Cost Optimization for Nx Deployments

### 1. Build Optimization
```bash
# Use Nx caching to reduce build times
npx nx build web --prod
npx nx build api --prod

# Enable remote caching (optional)
npx nx connect-to-nx-cloud
```

### 2. Resource Management
- **Development Environments**: Use Railway's environment branching sparingly
- **Staging Deployments**: Deploy only when necessary for testing
- **Production Optimization**: Right-size resources based on actual usage

### 3. Database Cost Management
- **Connection Limits**: Limit database connections to reduce resource usage
- **Query Optimization**: Optimize database queries to reduce CPU usage
- **Data Archival**: Archive old patient data to reduce storage costs

---

## Troubleshooting Common Issues

### Build Failures
```bash
# Clear Nx cache
npx nx reset

# Rebuild with verbose output
npx nx build web --verbose
npx nx build api --verbose
```

### Database Connection Issues
```typescript
// Add connection retry logic
const connectWithRetry = async (retries = 3) => {
  for (let i = 0; i < retries; i++) {
    try {
      return await createConnection();
    } catch (error) {
      if (i === retries - 1) throw error;
      await new Promise(resolve => setTimeout(resolve, 1000 * Math.pow(2, i)));
    }
  }
};
```

### Environment Variable Issues
```bash
# Check current variables
railway variables

# Verify in application
console.log('Environment:', {
  NODE_ENV: process.env.NODE_ENV,
  DATABASE_URL: process.env.DATABASE_URL ? 'SET' : 'NOT SET',
  FRONTEND_URL: process.env.FRONTEND_URL
});
```

---

## References

- [Railway.com Documentation](https://docs.railway.app/)
- [Nx Monorepo Documentation](https://nx.dev/getting-started/intro)
- [Railway CLI Reference](https://docs.railway.app/develop/cli)
- [Railway GitHub Integration](https://docs.railway.app/deploy/github-integration)
- [MySQL on Railway](https://docs.railway.app/databases/mysql)

---

← [Back to Pricing Analysis](./pricing-analysis.md) | [Next: Implementation Guide](./implementation-guide.md) →