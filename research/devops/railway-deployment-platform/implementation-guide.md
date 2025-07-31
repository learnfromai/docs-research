# Railway.com Implementation Guide

## 🎯 Overview

This guide provides step-by-step instructions for deploying Nx monorepo projects on Railway.com, specifically focusing on deploying separate API and web applications with a shared database.

## 🏗️ Prerequisites

### Required Tools
```bash
# Install Railway CLI
npm install -g @railway/cli

# Install Nx CLI (if not already installed)
npm install -g @nrwl/cli

# Verify installations
railway --version
nx --version
```

### Project Structure
```
clinic-management-nx/
├── apps/
│   ├── api/                 # Express.js backend
│   │   ├── src/
│   │   ├── package.json
│   │   └── project.json
│   └── web/                 # React/Vite frontend
│       ├── src/
│       ├── package.json
│       └── project.json
├── libs/                    # Shared libraries
├── nx.json
├── package.json
└── railway.json             # Railway configuration
```

## 🚀 Step 1: Create Railway Project

### 1.1 Initialize Railway Project
```bash
# Login to Railway
railway login

# Create new project
railway init

# Follow prompts to connect GitHub repository
```

### 1.2 Project Configuration
```json
// railway.json - Root project configuration
{
  "build": {
    "builder": "@nrwl/node:build"
  },
  "serve": {
    "builder": "@nrwl/node:serve"
  }
}
```

## 🗄️ Step 2: Setup Database Service

### 2.1 Create MySQL Database
```bash
# In Railway dashboard or CLI
railway add mysql

# Note the connection details:
# - MYSQL_URL
# - MYSQL_HOST
# - MYSQL_PORT
# - MYSQL_DATABASE
# - MYSQL_USER
# - MYSQL_PASSWORD
```

### 2.2 Database Configuration
```typescript
// apps/api/src/config/database.ts
export const databaseConfig = {
  host: process.env.MYSQL_HOST || 'localhost',
  port: parseInt(process.env.MYSQL_PORT || '3306'),
  username: process.env.MYSQL_USER || 'root',
  password: process.env.MYSQL_PASSWORD || '',
  database: process.env.MYSQL_DATABASE || 'clinic_db',
  synchronize: process.env.NODE_ENV !== 'production',
  logging: process.env.NODE_ENV === 'development'
};
```

## 🖥️ Step 3: Deploy API Service

### 3.1 API Service Configuration
```json
// apps/api/railway.json
{
  "build": {
    "builder": "@nrwl/node:build",
    "options": {
      "outputPath": "dist/apps/api",
      "main": "apps/api/src/main.ts",
      "tsConfig": "apps/api/tsconfig.app.json"
    }
  },
  "serve": {
    "builder": "@nrwl/node:serve",
    "options": {
      "buildTarget": "api:build"
    }
  }
}
```

### 3.2 Package.json Scripts
```json
// apps/api/package.json
{
  "name": "clinic-api",
  "scripts": {
    "build": "nx build api",
    "start": "node dist/apps/api/main.js",
    "start:dev": "nx serve api"
  },
  "dependencies": {
    "express": "^4.18.0",
    "mysql2": "^3.6.0",
    "typeorm": "^0.3.0"
  }
}
```

### 3.3 Deploy API Service
```bash
# Create API service
railway service create clinic-api

# Set service context
railway service clinic-api

# Deploy from monorepo root
railway up --service clinic-api

# Configure build command
railway variables set BUILD_COMMAND="nx build api"
railway variables set START_COMMAND="node dist/apps/api/main.js"
```

### 3.4 API Environment Variables
```bash
# Set environment variables for API service
railway variables set NODE_ENV=production
railway variables set PORT=3000
railway variables set API_URL=https://clinic-api-production.up.railway.app

# Database variables (automatically set by Railway MySQL service)
# MYSQL_URL, MYSQL_HOST, MYSQL_PORT, etc.
```

## 🌐 Step 4: Deploy Web Application

### 4.1 Web App Configuration
```json
// apps/web/railway.json
{
  "build": {
    "builder": "@nrwl/vite:build",
    "options": {
      "outputPath": "dist/apps/web"
    }
  }
}
```

### 4.2 Vite Configuration
```typescript
// apps/web/vite.config.ts
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  build: {
    outDir: '../../dist/apps/web'
  },
  define: {
    'process.env.VITE_API_URL': JSON.stringify(
      process.env.VITE_API_URL || 'http://localhost:3000'
    )
  }
});
```

### 4.3 Deploy Web Service
```bash
# Create web service
railway service create clinic-web

# Set service context
railway service clinic-web

# Deploy web application
railway up --service clinic-web

# Configure build commands
railway variables set BUILD_COMMAND="nx build web"
railway variables set START_COMMAND="npx serve dist/apps/web -s"
```

### 4.4 Web Environment Variables
```bash
# Set environment variables for web service
railway variables set VITE_API_URL=https://clinic-api-production.up.railway.app
railway variables set NODE_ENV=production
```

## 🔧 Step 5: Service Communication

### 5.1 API Service Setup
```typescript
// apps/api/src/main.ts
import express from 'express';
import cors from 'cors';

const app = express();
const port = process.env.PORT || 3000;

// CORS configuration for Railway services
app.use(cors({
  origin: [
    'https://clinic-web-production.up.railway.app',
    'http://localhost:4200' // Development
  ],
  credentials: true
}));

app.use(express.json());

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'healthy', timestamp: new Date().toISOString() });
});

app.listen(port, () => {
  console.log(`API server running on port ${port}`);
});
```

### 5.2 Web App API Integration
```typescript
// apps/web/src/config/api.ts
const API_BASE_URL = import.meta.env.VITE_API_URL || 'http://localhost:3000';

export const apiClient = {
  get: async (endpoint: string) => {
    const response = await fetch(`${API_BASE_URL}${endpoint}`);
    return response.json();
  },
  post: async (endpoint: string, data: any) => {
    const response = await fetch(`${API_BASE_URL}${endpoint}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data)
    });
    return response.json();
  }
};
```

## 🌍 Step 6: Domain Configuration

### 6.1 Custom Domains
```bash
# Add custom domain to API service
railway service clinic-api
railway domain add api.clinicapp.com

# Add custom domain to web service  
railway service clinic-web
railway domain add clinicapp.com
```

### 6.2 SSL Certificates
- Railway automatically provisions SSL certificates
- HTTPS is enabled by default for all custom domains
- Certificates auto-renew before expiration

## 📊 Step 7: Monitoring & Logging

### 7.1 Application Metrics
```bash
# View service metrics
railway service clinic-api
railway status

# View logs
railway logs --follow
```

### 7.2 Custom Logging
```typescript
// apps/api/src/utils/logger.ts
export const logger = {
  info: (message: string, meta?: any) => {
    console.log(JSON.stringify({
      level: 'info',
      message,
      timestamp: new Date().toISOString(),
      ...meta
    }));
  },
  error: (message: string, error?: Error) => {
    console.error(JSON.stringify({
      level: 'error',
      message,
      error: error?.message,
      stack: error?.stack,
      timestamp: new Date().toISOString()
    }));
  }
};
```

## 🚀 Step 8: CI/CD Pipeline

### 8.1 Automatic Deployments
```yaml
# .github/workflows/railway-deploy.yml
name: Deploy to Railway
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Install Railway CLI
        run: npm install -g @railway/cli
        
      - name: Deploy API
        run: railway up --service clinic-api
        env:
          RAILWAY_TOKEN: ${{ secrets.RAILWAY_TOKEN }}
          
      - name: Deploy Web
        run: railway up --service clinic-web  
        env:
          RAILWAY_TOKEN: ${{ secrets.RAILWAY_TOKEN }}
```

### 8.2 Environment-Specific Deployments
```bash
# Create staging environment
railway environment create staging

# Deploy to staging
railway up --environment staging

# Promote to production
railway environment promote staging production
```

## 🔒 Step 9: Security Configuration

### 9.1 Environment Variables Security
```bash
# Use Railway's secure environment variables
railway variables set JWT_SECRET=$(openssl rand -base64 32)
railway variables set DATABASE_ENCRYPTION_KEY=$(openssl rand -base64 32)
```

### 9.2 API Security Middleware
```typescript
// apps/api/src/middleware/security.ts
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';

export const securityMiddleware = [
  helmet(),
  rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 100, // Limit each IP to 100 requests per windowMs
    message: 'Too many requests from this IP'
  })
];
```

## 📈 Step 10: Performance Optimization

### 10.1 Caching Strategy
```typescript
// apps/api/src/middleware/cache.ts
import Redis from 'ioredis';

const redis = new Redis(process.env.REDIS_URL);

export const cacheMiddleware = (duration: number) => {
  return async (req: Request, res: Response, next: NextFunction) => {
    const key = `cache:${req.originalUrl}`;
    const cached = await redis.get(key);
    
    if (cached) {
      return res.json(JSON.parse(cached));
    }
    
    // Store original send function
    const originalSend = res.json;
    res.json = function(data) {
      redis.setex(key, duration, JSON.stringify(data));
      return originalSend.call(this, data);
    };
    
    next();
  };
};
```

### 10.2 Database Optimization
```typescript
// apps/api/src/config/database.ts
import { DataSource } from 'typeorm';

export const AppDataSource = new DataSource({
  // ... configuration
  extra: {
    // Connection pool settings
    max: 10,
    min: 2,
    acquire: 30000,
    idle: 10000
  },
  cache: {
    duration: 30000 // 30 seconds
  }
});
```

## 🧪 Step 11: Testing Strategy

### 11.1 E2E Testing with Railway
```typescript
// apps/api-e2e/src/api.spec.ts
describe('API Integration Tests', () => {
  const apiUrl = process.env.RAILWAY_API_URL || 'http://localhost:3000';
  
  it('should connect to database', async () => {
    const response = await fetch(`${apiUrl}/health`);
    const data = await response.json();
    expect(data.status).toBe('healthy');
  });
});
```

### 11.2 Load Testing
```bash
# Install k6 for load testing
npm install -g k6

# Run load tests against Railway deployment
k6 run --vus 10 --duration 30s load-test.js
```

## 📋 Deployment Checklist

### Pre-Deployment
- [ ] Repository connected to Railway
- [ ] Environment variables configured
- [ ] Database service created and connected
- [ ] Build commands verified locally
- [ ] Custom domains configured (if needed)

### API Service Deployment
- [ ] API service created in Railway
- [ ] Build command: `nx build api`
- [ ] Start command: `node dist/apps/api/main.js`
- [ ] Environment variables set
- [ ] Database connection tested
- [ ] Health endpoint responding

### Web Service Deployment  
- [ ] Web service created in Railway
- [ ] Build command: `nx build web`
- [ ] Start command: `npx serve dist/apps/web -s`
- [ ] API URL environment variable set
- [ ] Static assets serving correctly
- [ ] CORS configuration verified

### Post-Deployment
- [ ] Services communicating correctly
- [ ] SSL certificates active
- [ ] Monitoring and logging configured
- [ ] Performance baseline established
- [ ] Backup strategy implemented

---

## 🔗 Navigation

- **Previous**: [Executive Summary](./executive-summary.md)
- **Next**: [Best Practices](./best-practices.md)