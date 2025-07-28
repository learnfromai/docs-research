# Implementation Guide: Railway Deployment Strategies

## 🎯 Overview

This guide provides step-by-step instructions for deploying Nx React/Express applications to Railway.com using both deployment strategies, with detailed focus on the recommended **Single Deployment** approach.

## 🏆 Recommended: Strategy 2 - Single Deployment

### Prerequisites

- Nx workspace with React frontend and Express backend
- Railway account with CLI installed
- Git repository with your project
- Node.js 18+ and npm/yarn

### Step 1: Prepare Nx Workspace for Single Deployment

#### 1.1 Update Express Application Structure

```typescript
// apps/api/src/main.ts
import express from 'express';
import path from 'path';
import cors from 'cors';

const app = express();
const port = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

// API routes (before static serving)
app.use('/api', apiRoutes);

// Serve static files from React build
const staticPath = path.join(__dirname, '../../../dist/apps/client');
app.use(express.static(staticPath));

// Handle client-side routing (SPA fallback)
app.get('*', (req, res) => {
  res.sendFile(path.join(staticPath, 'index.html'));
});

app.listen(port, () => {
  console.log(`🚀 Server running on port ${port}`);
});
```

#### 1.2 Configure Build Scripts

```json
// package.json
{
  "scripts": {
    "build:prod": "nx build client --prod && nx build api --prod",
    "start:prod": "node dist/apps/api/main.js",
    "railway:build": "npm run build:prod",
    "railway:start": "npm run start:prod"
  }
}
```

#### 1.3 Update Nx Project Configuration

```json
// apps/api/project.json
{
  "targets": {
    "build": {
      "executor": "@nrwl/webpack:webpack",
      "options": {
        "outputPath": "dist/apps/api",
        "main": "apps/api/src/main.ts",
        "tsConfig": "apps/api/tsconfig.app.json",
        "target": "node",
        "compiler": "tsc",
        "generatePackageJson": true,
        "assets": ["apps/api/src/assets"]
      }
    }
  }
}
```

### Step 2: Railway Configuration

#### 2.1 Create Railway Project

```bash
# Install Railway CLI
npm install -g @railway/cli

# Login to Railway
railway login

# Initialize project
railway init

# Link to existing project (if created via web)
railway link
```

#### 2.2 Configure Environment Variables

```bash
# Set production environment variables
railway variables set NODE_ENV=production
railway variables set PORT=3000

# Database configuration (if using Railway database)
railway variables set DATABASE_URL=${{Postgres.DATABASE_URL}}
```

#### 2.3 Create railway.json Configuration

```json
{
  "$schema": "https://railway.app/railway.schema.json",
  "build": {
    "builder": "NIXPACKS",
    "buildCommand": "npm run railway:build"
  },
  "deploy": {
    "startCommand": "npm run railway:start",
    "healthcheckPath": "/api/health",
    "healthcheckTimeout": 100,
    "restartPolicyType": "ON_FAILURE",
    "restartPolicyMaxRetries": 10
  }
}
```

### Step 3: Configure PWA Support

#### 3.1 Update Express for PWA Headers

```typescript
// apps/api/src/main.ts - Add PWA headers
app.use((req, res, next) => {
  // PWA caching headers
  if (req.url.match(/\.(js|css|png|jpg|jpeg|gif|ico|svg)$/)) {
    res.setHeader('Cache-Control', 'public, max-age=31536000');
  }
  
  // Service worker should not be cached
  if (req.url === '/sw.js') {
    res.setHeader('Cache-Control', 'no-cache');
  }
  
  next();
});
```

#### 3.2 Configure Vite for PWA in React App

```typescript
// apps/client/vite.config.ts
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { VitePWA } from 'vite-plugin-pwa';

export default defineConfig({
  plugins: [
    react(),
    VitePWA({
      registerType: 'autoUpdate',
      workbox: {
        globPatterns: ['**/*.{js,css,html,ico,png,svg}'],
        runtimeCaching: [
          {
            urlPattern: /^https:\/\/[^\/]+\/api\/.*/i,
            handler: 'NetworkFirst',
            options: {
              cacheName: 'api-cache',
              networkTimeoutSeconds: 10,
              cacheableResponse: {
                statuses: [0, 200]
              }
            }
          }
        ]
      },
      manifest: {
        name: 'Clinic Management System',
        short_name: 'CMS',
        description: 'Professional clinic management application',
        theme_color: '#1976d2',
        background_color: '#ffffff',
        display: 'standalone',
        scope: '/',
        start_url: '/',
        icons: [
          {
            src: 'pwa-192x192.png',
            sizes: '192x192',
            type: 'image/png'
          },
          {
            src: 'pwa-512x512.png',
            sizes: '512x512',
            type: 'image/png'
          }
        ]
      }
    })
  ],
  build: {
    outDir: '../../dist/apps/client'
  }
});
```

### Step 4: Deploy to Railway

#### 4.1 Initial Deployment

```bash
# Deploy from current directory
railway up

# Or deploy specific service
railway up --service your-service-name
```

#### 4.2 Set Up Database (if needed)

```bash
# Add PostgreSQL database
railway add postgresql

# Or MySQL database
railway add mysql

# Get database URL
railway variables
```

#### 4.3 Configure Custom Domain (Optional)

```bash
# Add custom domain via Railway dashboard or CLI
railway domain
```

### Step 5: Production Optimizations

#### 5.1 Enable Compression

```typescript
// apps/api/src/main.ts
import compression from 'compression';

app.use(compression({
  level: 6,
  threshold: 100 * 1000, // Only compress if larger than 100KB
  filter: (req, res) => {
    if (req.headers['x-no-compression']) {
      return false;
    }
    return compression.filter(req, res);
  }
}));
```

#### 5.2 Configure Security Headers

```typescript
// apps/api/src/main.ts
import helmet from 'helmet';

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
```

#### 5.3 Add Health Check Endpoint

```typescript
// apps/api/src/routes/health.ts
import express from 'express';
const router = express.Router();

router.get('/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    environment: process.env.NODE_ENV || 'development'
  });
});

export default router;
```

---

## 🔄 Alternative: Strategy 1 - Separate Deployments

### When to Use Separate Deployments

- High traffic applications requiring independent scaling
- Different teams managing frontend and backend
- Need for CDN optimization for global users
- Microservices architecture requirements

### Step 1: Prepare Frontend (Static Site)

#### 1.1 Configure React App for Static Deployment

```typescript
// apps/client/src/environments/environment.prod.ts
export const environment = {
  production: true,
  apiUrl: 'https://your-api-service.railway.app/api'
};
```

#### 1.2 Build Configuration

```json
// apps/client/project.json
{
  "targets": {
    "build": {
      "executor": "@nrwl/vite:build",
      "options": {
        "outputPath": "dist/apps/client"
      },
      "configurations": {
        "production": {
          "mode": "production",
          "sourcemap": false
        }
      }
    }
  }
}
```

### Step 2: Deploy Frontend to Railway

#### 2.1 Create Static Site Service

```bash
# Create new Railway project for frontend
railway init frontend-service

# Deploy static files
railway up
```

#### 2.2 Configure Static Site Settings

```json
// railway.json for frontend service
{
  "build": {
    "builder": "NIXPACKS",
    "buildCommand": "nx build client --prod"
  },
  "deploy": {
    "staticFilesPath": "dist/apps/client"
  }
}
```

### Step 3: Deploy Backend API Service

#### 3.1 Prepare API Service

```typescript
// apps/api/src/main.ts
import express from 'express';
import cors from 'cors';

const app = express();
const port = process.env.PORT || 3000;

// Configure CORS for frontend domain
app.use(cors({
  origin: process.env.FRONTEND_URL || 'https://your-frontend.railway.app',
  credentials: true
}));

app.use(express.json());
app.use('/api', apiRoutes);

app.listen(port, () => {
  console.log(`🚀 API Server running on port ${port}`);
});
```

#### 3.2 Deploy API Service

```bash
# Create new Railway project for backend
railway init api-service

# Set environment variables
railway variables set FRONTEND_URL=https://your-frontend.railway.app
railway variables set DATABASE_URL=${{Postgres.DATABASE_URL}}

# Deploy API service
railway up
```

### Step 4: Configure Cross-Service Communication

#### 4.1 Update Frontend API Configuration

```typescript
// apps/client/src/services/api.ts
const API_BASE_URL = process.env.NODE_ENV === 'production' 
  ? 'https://your-api-service.railway.app/api'
  : 'http://localhost:3000/api';

export const apiClient = axios.create({
  baseURL: API_BASE_URL,
  withCredentials: true
});
```

#### 4.2 Configure API CORS

```typescript
// apps/api/src/middleware/cors.ts
export const corsConfig = {
  origin: [
    'https://your-frontend.railway.app',
    'http://localhost:4200' // For development
  ],
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH'],
  allowedHeaders: ['Content-Type', 'Authorization']
};
```

---

## 🧪 Testing Deployment

### Local Testing

```bash
# Test production build locally
npm run build:prod
npm run start:prod

# Test on different port
PORT=3001 npm run start:prod
```

### Railway Testing

```bash
# Check deployment status
railway status

# View logs
railway logs

# Open deployed application
railway open
```

### PWA Testing Checklist

- [ ] Service worker registers correctly
- [ ] App works offline after initial load
- [ ] App can be installed (Add to Home Screen)
- [ ] Lighthouse PWA score > 90
- [ ] Performance score > 90

### Performance Verification

```bash
# Test with Lighthouse CI
npm install -g @lhci/cli
lhci autorun --upload.target=temporary-public-storage
```

---

## 🚨 Troubleshooting Common Issues

### Build Failures

```bash
# Clear Railway cache
railway run bash
rm -rf node_modules package-lock.json
npm install

# Check build logs
railway logs --tail
```

### Static File Serving Issues

```typescript
// Verify static path is correct
console.log('Static path:', path.join(__dirname, '../../../dist/apps/client'));
console.log('Files in static dir:', fs.readdirSync(staticPath));
```

### PWA Registration Issues

```typescript
// Check service worker registration
if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('/sw.js')
      .then(registration => console.log('SW registered'))
      .catch(error => console.log('SW registration failed'));
  });
}
```

---

## 🔗 Navigation

**← Previous:** [Executive Summary](./executive-summary.md) | **Next:** [Best Practices](./best-practices.md) →

**Related Sections:**
- [Template Examples](./template-examples.md) - Complete configuration files
- [Troubleshooting](./troubleshooting.md) - Common deployment issues