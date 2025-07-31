# Implementation Guide: Railway.com Deployment for Nx React/Express Apps

## 🎯 Overview

This guide provides step-by-step implementation instructions for both deployment strategies on Railway.com, with specific focus on Nx monorepo configurations and clinic management system requirements.

## 🏗️ Prerequisites

### System Requirements
- **Node.js**: 18+ LTS version
- **Nx CLI**: Latest version (`npm install -g nx`)
- **Railway CLI**: Latest version (`npm install -g @railway/cli`)
- **Git**: Version control setup

### Nx Project Structure
```
clinic-management/
├── apps/
│   ├── frontend/          # React + Vite app
│   └── backend/           # Express.js API
├── libs/                  # Shared libraries
├── nx.json
├── package.json
└── workspace.json
```

### Railway Account Setup
1. Create account at [railway.app](https://railway.app)
2. Connect GitHub repository
3. Install Railway CLI: `npm install -g @railway/cli`
4. Login: `railway login`

## 🚀 Strategy 1: Unified Deployment (Recommended)

### Step 1: Express.js Configuration for Static Serving

#### 1.1 Update Express App (`apps/backend/src/main.ts`)

```typescript
import express from 'express';
import path from 'path';
import cors from 'cors';

const app = express();
const port = process.env.PORT || 3000;

// Basic middleware
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// CORS for development (not needed in production unified deployment)
if (process.env.NODE_ENV !== 'production') {
  app.use(cors({
    origin: 'http://localhost:4200',
    credentials: true
  }));
}

// API routes
app.use('/api', /* your API routes */);

// Serve static files in production
if (process.env.NODE_ENV === 'production') {
  const frontendPath = path.join(__dirname, '../frontend');
  
  // Serve static files
  app.use(express.static(frontendPath));
  
  // Handle client-side routing (SPA)
  app.get('*', (req, res) => {
    res.sendFile(path.join(frontendPath, 'index.html'));
  });
}

app.listen(port, () => {
  console.log(`Server running on port ${port}`);
});
```

#### 1.2 Update Build Configuration (`project.json` for backend)

```json
{
  "name": "backend",
  "targets": {
    "build": {
      "executor": "@nx/webpack:webpack",
      "outputs": ["{options.outputPath}"],
      "options": {
        "outputPath": "dist/apps/backend",
        "main": "apps/backend/src/main.ts",
        "tsConfig": "apps/backend/tsconfig.app.json",
        "target": "node",
        "compiler": "tsc",
        "assets": [
          {
            "glob": "**/*",
            "input": "dist/apps/frontend",
            "output": "frontend"
          }
        ]
      }
    },
    "production-build": {
      "executor": "nx:run-commands",
      "options": {
        "parallel": false,
        "commands": [
          "nx build frontend --configuration=production",
          "nx build backend --configuration=production"
        ]
      }
    }
  }
}
```

### Step 2: Railway Configuration

#### 2.1 Create `railway.toml`

```toml
[build]
builder = "nixpacks"
buildCommand = "npm run build:prod"

[deploy]
startCommand = "node dist/apps/backend/main.js"
restartPolicyType = "always"
restartPolicyMaxRetries = 10

[[services]]
name = "clinic-management"

[services.variables]
NODE_ENV = "production"
PORT = "3000"
```

#### 2.2 Create `Dockerfile` (Alternative to nixpacks)

```dockerfile
# Use Node.js LTS
FROM node:18-alpine

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./
COPY nx.json ./
COPY workspace.json ./
COPY tsconfig.base.json ./

# Install dependencies
RUN npm ci --only=production

# Copy source code
COPY . .

# Build frontend first, then backend
RUN npm run build:frontend:prod
RUN npm run build:backend:prod

# Expose port
EXPOSE 3000

# Start the server
CMD ["node", "dist/apps/backend/main.js"]
```

#### 2.3 Update `package.json` Scripts

```json
{
  "scripts": {
    "build:frontend:prod": "nx build frontend --configuration=production",
    "build:backend:prod": "nx build backend --configuration=production",
    "build:prod": "npm run build:frontend:prod && npm run build:backend:prod",
    "start:prod": "node dist/apps/backend/main.js"
  }
}
```

### Step 3: Railway Deployment

#### 3.1 Initialize Railway Project

```bash
# Connect to Railway
railway login

# Create new project
railway new clinic-management

# Link to existing project (if already exists)
railway link [project-id]

# Set environment variables
railway variables set NODE_ENV=production
railway variables set DATABASE_URL=your_database_url
```

#### 3.2 Deploy to Railway

```bash
# Deploy directly
railway up

# Or deploy from GitHub (recommended)
# 1. Connect GitHub repository in Railway dashboard
# 2. Enable auto-deploy on push to main branch
# 3. Set build command: npm run build:prod
# 4. Set start command: npm start:prod
```

### Step 4: PWA Configuration

#### 4.1 Update Vite Config (`apps/frontend/vite.config.ts`)

```typescript
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { VitePWA } from 'vite-plugin-pwa';

export default defineConfig({
  plugins: [
    react(),
    VitePWA({
      registerType: 'autoUpdate',
      includeAssets: ['favicon.ico', 'apple-touch-icon.png', 'masked-icon.svg'],
      manifest: {
        name: 'Clinic Management System',
        short_name: 'ClinicMS',
        description: 'Efficient clinic management for healthcare professionals',
        theme_color: '#ffffff',
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
      },
      workbox: {
        globPatterns: ['**/*.{js,css,html,ico,png,svg}'],
        runtimeCaching: [
          {
            urlPattern: /^https:\/\/api\./,
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
      }
    })
  ],
  base: '/',
  build: {
    outDir: '../../dist/apps/frontend',
    emptyOutDir: true
  }
});
```

## 🔄 Strategy 2: Separate Deployment (Alternative)

### Step 1: Frontend Static Deployment

#### 1.1 Frontend Railway Configuration

Create `apps/frontend/railway.toml`:

```toml
[build]
builder = "nixpacks"
buildCommand = "nx build frontend --configuration=production"

[deploy]
staticPublishPath = "dist/apps/frontend"

[[services]]
name = "clinic-frontend"

[services.variables]
NODE_ENV = "production"
```

#### 1.2 Frontend Environment Configuration

Create `apps/frontend/.env.production`:

```env
VITE_API_URL=https://clinic-backend.railway.app
VITE_APP_NAME=Clinic Management System
```

### Step 2: Backend API Service

#### 2.1 Update CORS Configuration

```typescript
// apps/backend/src/main.ts
import cors from 'cors';

const allowedOrigins = [
  'https://clinic-frontend.railway.app',
  process.env.FRONTEND_URL
].filter(Boolean);

app.use(cors({
  origin: allowedOrigins,
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));
```

#### 2.2 Backend Railway Configuration

Create `apps/backend/railway.toml`:

```toml
[build]
builder = "nixpacks"
buildCommand = "nx build backend --configuration=production"

[deploy]
startCommand = "node dist/apps/backend/main.js"

[[services]]
name = "clinic-backend"

[services.variables]
NODE_ENV = "production"
PORT = "3000"
FRONTEND_URL = "https://clinic-frontend.railway.app"
```

### Step 3: Deployment Process

#### 3.1 Deploy Backend First

```bash
cd apps/backend
railway login
railway new clinic-backend
railway up
```

#### 3.2 Deploy Frontend

```bash
cd apps/frontend
railway login
railway new clinic-frontend
railway variables set VITE_API_URL=https://clinic-backend.railway.app
railway up
```

## 🔧 Production Optimizations

### Caching Headers for Static Assets

```typescript
// For unified deployment
app.use(express.static(frontendPath, {
  maxAge: '1y',
  etag: false,
  setHeaders: (res, path) => {
    if (path.includes('.html')) {
      res.setHeader('Cache-Control', 'no-cache');
    }
  }
}));
```

### Health Check Endpoint

```typescript
// Add to Express app
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    environment: process.env.NODE_ENV,
    version: process.env.npm_package_version
  });
});
```

### Environment Variables Setup

```bash
# Railway environment variables
railway variables set NODE_ENV=production
railway variables set DATABASE_URL=postgresql://...
railway variables set JWT_SECRET=your_jwt_secret
railway variables set ALLOWED_ORIGINS=https://clinic-management.railway.app
```

## 🚀 CI/CD Pipeline

### GitHub Actions (Optional Enhancement)

Create `.github/workflows/deploy.yml`:

```yaml
name: Deploy to Railway

on:
  push:
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
      
      - name: Build applications
        run: npm run build:prod
      
      - name: Deploy to Railway
        uses: railway/action@v1
        with:
          token: ${{ secrets.RAILWAY_TOKEN }}
```

## 📊 Monitoring Setup

### Basic Monitoring

```typescript
// Add request logging middleware
app.use((req, res, next) => {
  console.log(`${new Date().toISOString()} - ${req.method} ${req.path}`);
  next();
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error(`Error: ${err.message}`);
  res.status(500).json({ error: 'Internal server error' });
});
```

### Railway Monitoring

1. **Built-in Metrics**: Access via Railway dashboard
2. **Custom Metrics**: Implement using Railway's metrics API
3. **Alerts**: Set up via Railway dashboard for service health

## ✅ Deployment Checklist

### Pre-Deployment
- [ ] Nx build commands configured
- [ ] Environment variables set
- [ ] Database connection tested
- [ ] CORS configuration updated (if separate deployment)
- [ ] PWA manifest and service worker configured

### Railway Setup
- [ ] Railway project created
- [ ] GitHub repository connected
- [ ] Build and start commands configured
- [ ] Environment variables set in Railway
- [ ] Custom domain configured (optional)

### Post-Deployment
- [ ] Health check endpoint responding
- [ ] PWA installation working
- [ ] Offline functionality tested
- [ ] API endpoints accessible
- [ ] Frontend-backend communication verified

### Production Hardening
- [ ] HTTPS enforced
- [ ] Security headers configured
- [ ] Rate limiting implemented
- [ ] Monitoring and alerting active
- [ ] Backup procedures documented

## 🔗 Navigation

- **Previous**: [Comparison Analysis](./comparison-analysis.md) - Detailed scoring methodology
- **Next**: [Performance Analysis](./performance-analysis.md) - PWA optimization strategies
- **Related**: [Best Practices](./best-practices.md) - Production recommendations

---

*Implementation guide tailored for Railway.com deployment of Nx monorepos in healthcare environments.*