# Implementation Guide: Nx Managed Deployment

## 🎯 Overview

This guide provides step-by-step instructions for deploying full-stack Nx monorepo projects to managed cloud platforms, covering both development simulation (free platforms) and production deployment (Digital Ocean App Platform).

---

## 📋 Prerequisites

### System Requirements
- Node.js 18+ installed locally
- Git repository with Nx workspace
- GitHub account for CI/CD integration
- Basic understanding of Nx workspace structure

### Nx Project Structure
```
my-nx-workspace/
├── apps/
│   ├── frontend/          # React + Vite application
│   ├── backend/           # Express.js application
│   └── shared-ui/         # Shared component library (optional)
├── libs/
│   ├── shared-types/      # TypeScript interfaces
│   └── shared-utils/      # Common utilities
├── tools/
│   └── deployment/        # Custom deployment scripts
├── nx.json
├── package.json
└── project.json
```

---

## 🚀 Phase 1: Development Setup (Free Platforms)

### Option A: Railway Deployment (Recommended for Full-Stack)

#### Step 1: Prepare Your Nx Project

1. **Install Railway CLI**
```bash
npm install -g @railway/cli
railway login
```

2. **Configure Build Scripts in package.json**
```json
{
  "scripts": {
    "build:frontend": "nx build frontend --prod",
    "build:backend": "nx build backend --prod",
    "start:frontend": "nx serve frontend",
    "start:backend": "nx serve backend",
    "deploy:frontend": "railway up --service frontend",
    "deploy:backend": "railway up --service backend"
  }
}
```

3. **Create Railway Configuration Files**

**Frontend Service (`railway-frontend.toml`):**
```toml
[build]
builder = "NIXPACKS"
buildCommand = "npm ci && npm run build:frontend"

[deploy]
startCommand = "npx serve dist/apps/frontend -s -n -L -p $PORT"
healthcheckPath = "/"
healthcheckTimeout = 100
restartPolicyType = "ON_FAILURE"
restartPolicyMaxRetries = 10

[env]
NODE_ENV = "production"
PORT = "3000"
```

**Backend Service (`railway-backend.toml`):**
```toml
[build]
builder = "NIXPACKS"
buildCommand = "npm ci && npm run build:backend"

[deploy]
startCommand = "node dist/apps/backend/main.js"
healthcheckPath = "/health"
healthcheckTimeout = 100
restartPolicyType = "ON_FAILURE"
restartPolicyMaxRetries = 10

[env]
NODE_ENV = "production"
PORT = "8080"
```

#### Step 2: Deploy to Railway

1. **Initialize Railway Project**
```bash
railway init
railway link
```

2. **Create Separate Services**
```bash
# Create frontend service
railway service create frontend
railway service create backend

# Deploy frontend
railway up --service frontend --config railway-frontend.toml

# Deploy backend  
railway up --service backend --config railway-backend.toml
```

3. **Configure Environment Variables**
```bash
# Set frontend environment variables
railway variables set VITE_API_URL=https://your-backend.railway.app --service frontend

# Set backend environment variables  
railway variables set DATABASE_URL=${{DATABASE_URL}} --service backend
railway variables set JWT_SECRET=your-jwt-secret --service backend
```

#### Step 3: Add Database (Optional)
```bash
# Add PostgreSQL database
railway add postgresql

# Get database URL
railway variables
```

### Option B: Vercel + Railway Combo

#### Frontend to Vercel

1. **Install Vercel CLI**
```bash
npm i -g vercel
vercel login
```

2. **Configure vercel.json**
```json
{
  "version": 2,
  "builds": [
    {
      "src": "apps/frontend/package.json",
      "use": "@vercel/static-build",
      "config": {
        "distDir": "../../dist/apps/frontend"
      }
    }
  ],
  "routes": [
    {
      "src": "/(.*)",
      "dest": "/apps/frontend/$1"
    }
  ],
  "env": {
    "VITE_API_URL": "https://your-backend.railway.app"
  }
}
```

3. **Build Configuration in apps/frontend/package.json**
```json
{
  "scripts": {
    "build": "cd ../.. && nx build frontend --prod"
  }
}
```

4. **Deploy to Vercel**
```bash
cd apps/frontend
vercel --prod
```

#### Backend to Railway
Follow Railway backend deployment steps from Option A.

### Option C: Render Deployment

#### Step 1: Prepare Render Configuration

**Frontend (render-frontend.yaml):**
```yaml
services:
  - type: web
    name: my-app-frontend
    env: static
    buildCommand: npm ci && npm run build:frontend
    staticPublishPath: dist/apps/frontend
    routes:
      - type: rewrite
        source: /*
        destination: /index.html
    envVars:
      - key: NODE_ENV
        value: production
```

**Backend (render-backend.yaml):**
```yaml
services:
  - type: web
    name: my-app-backend
    env: node
    buildCommand: npm ci && npm run build:backend
    startCommand: node dist/apps/backend/main.js
    healthCheckPath: /health
    envVars:
      - key: NODE_ENV
        value: production
      - key: PORT
        value: 10000
```

#### Step 2: Deploy via Git Integration
1. Connect your GitHub repository to Render
2. Create separate services for frontend and backend
3. Configure build and start commands through Render dashboard
4. Set environment variables through Render UI

---

## 🏢 Phase 2: Production Deployment (Digital Ocean App Platform)

### Step 1: Prepare Digital Ocean App Spec

Create `.do/app.yaml` in your repository root:

```yaml
name: my-nx-fullstack-app
services:
  # Frontend Service
  - name: frontend
    source_dir: /
    github:
      repo: your-username/your-repo
      branch: main
    run_command: npx serve dist/apps/frontend -s -n -L -p $PORT
    build_command: npm ci --only=production && npm run build:frontend
    environment_slug: node-js
    instance_count: 1
    instance_size_slug: basic-xxs
    http_port: 8080
    routes:
      - path: /
    envs:
      - key: NODE_ENV
        value: "production"
      - key: VITE_API_URL
        value: "${backend.PUBLIC_URL}"

  # Backend Service  
  - name: backend
    source_dir: /
    github:
      repo: your-username/your-repo
      branch: main
    run_command: node dist/apps/backend/main.js
    build_command: npm ci --only=production && npm run build:backend
    environment_slug: node-js
    instance_count: 1
    instance_size_slug: basic-xxs
    http_port: 8080
    health_check:
      http_path: /health
    routes:
      - path: /api
    envs:
      - key: NODE_ENV
        value: "production"
      - key: PORT
        value: "8080"
      - key: DATABASE_URL
        value: "${db.DATABASE_URL}"
      - key: JWT_SECRET
        value: "${JWT_SECRET}"

# Database
databases:
  - name: db
    engine: PG
    version: "13"
    production: true
    
# Environment Variables (to be set in DO dashboard)
envs:
  - key: JWT_SECRET
    value: "your-secret-key"
    type: SECRET
```

### Step 2: Optimize Nx Build Configuration

**Update nx.json for production builds:**
```json
{
  "targetDefaults": {
    "build": {
      "dependsOn": ["^build"],
      "outputs": ["{projectRoot}/dist"]
    }
  },
  "generators": {
    "@nrwl/react": {
      "application": {
        "babel": true
      }
    }
  }
}
```

**Frontend project.json optimization:**
```json
{
  "targets": {
    "build": {
      "executor": "@nrwl/vite:build",
      "options": {
        "outputPath": "dist/apps/frontend"
      },
      "configurations": {
        "production": {
          "mode": "production",
          "sourcemap": false,
          "optimization": true,
          "extractCss": true,
          "namedChunks": false,
          "extractLicenses": true,
          "vendorChunk": false,
          "budgets": [
            {
              "type": "initial",
              "maximumWarning": "2mb",
              "maximumError": "5mb"
            }
          ]
        }
      }
    }
  }
}
```

**Backend project.json optimization:**
```json
{
  "targets": {
    "build": {
      "executor": "@nrwl/webpack:webpack",
      "options": {
        "outputPath": "dist/apps/backend",
        "main": "apps/backend/src/main.ts",
        "tsConfig": "apps/backend/tsconfig.app.json",
        "optimization": true,
        "extractLicenses": false,
        "inspect": false,
        "fileReplacements": [
          {
            "replace": "apps/backend/src/environments/environment.ts",
            "with": "apps/backend/src/environments/environment.prod.ts"
          }
        ]
      }
    }
  }
}
```

### Step 3: Deploy to Digital Ocean

#### Option A: Using doctl CLI
```bash
# Install doctl
brew install doctl  # macOS
# or download from GitHub releases

# Authenticate
doctl auth init

# Create app from spec file
doctl apps create --spec .do/app.yaml

# Monitor deployment
doctl apps list
doctl apps get <app-id>
```

#### Option B: Using Digital Ocean Web Console
1. Go to [Digital Ocean App Platform](https://cloud.digitalocean.com/apps)
2. Click "Create App"
3. Connect your GitHub repository
4. Import app spec from `.do/app.yaml`
5. Review configuration and deploy

### Step 4: Configure Custom Domain (Optional)
```bash
# Add domain to app
doctl apps update <app-id> --spec .do/app.yaml

# Update DNS settings:
# CNAME: www -> your-app.ondigitalocean.app
# A: @ -> Digital Ocean IP (provided in console)
```

---

## ⚙️ Phase 3: CI/CD Integration

### GitHub Actions Workflow

Create `.github/workflows/deploy.yml`:

```yaml
name: Deploy to Managed Platforms

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
        with:
          node-version: 18
          cache: 'npm'
      
      - run: npm ci
      - run: npm run test
      - run: npm run lint

  deploy-staging:
    if: github.ref == 'refs/heads/develop'
    needs: test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
        with:
          node-version: 18
          cache: 'npm'
      
      # Deploy to Railway (staging)
      - name: Deploy to Railway
        uses: railway-deploy/railway-github-action@v1
        with:
          service: 'staging'
          railway-token: ${{ secrets.RAILWAY_TOKEN }}

  deploy-production:
    if: github.ref == 'refs/heads/main'
    needs: test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
        with:
          node-version: 18
          cache: 'npm'
      
      # Deploy to Digital Ocean
      - name: Deploy to Digital Ocean
        uses: digitalocean/app_action@v1.1.5
        with:
          app_name: my-nx-fullstack-app
          token: ${{ secrets.DIGITALOCEAN_ACCESS_TOKEN }}
```

### Environment Variable Management

**GitHub Secrets Configuration:**
```bash
# Required secrets:
RAILWAY_TOKEN=your-railway-token
DIGITALOCEAN_ACCESS_TOKEN=your-do-token
JWT_SECRET=your-jwt-secret
DATABASE_URL=your-database-url
```

**Platform-Specific Environment Variables:**

**Railway:**
```bash
railway variables set NODE_ENV=production
railway variables set JWT_SECRET=$JWT_SECRET
railway variables set VITE_API_URL=https://backend.railway.app
```

**Digital Ocean:**
- Configure in App Platform dashboard
- Use encrypted environment variables for sensitive data
- Reference database connection via `${db.DATABASE_URL}`

---

## 🔧 Advanced Configuration

### Custom Nginx Configuration (Digital Ocean)

Create `nginx.conf` for custom routing:
```nginx
server {
    listen 8080;
    root /app/dist/apps/frontend;
    index index.html;

    # Handle client-side routing
    location / {
        try_files $uri $uri/ /index.html;
    }

    # Proxy API requests to backend
    location /api {
        proxy_pass http://backend:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    # Gzip compression
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml;
}
```

### Health Check Endpoints

**Backend health check (apps/backend/src/main.ts):**
```typescript
import express from 'express';

const app = express();

// Health check endpoint required for managed platforms
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    version: process.env.npm_package_version || '1.0.0'
  });
});

// Database health check
app.get('/health/db', async (req, res) => {
  try {
    // Add your database connection check here
    await database.query('SELECT 1');
    res.status(200).json({ database: 'connected' });
  } catch (error) {
    res.status(503).json({ database: 'disconnected', error: error.message });
  }
});

const port = process.env.PORT || 8080;
app.listen(port, () => {
  console.log(`Backend running on port ${port}`);
});
```

### Build Optimization

**Production Dockerfile (optional for advanced scenarios):**
```dockerfile
FROM node:18-alpine AS builder

WORKDIR /app
COPY package*.json ./
COPY nx.json ./
COPY tsconfig.base.json ./

# Install dependencies
RUN npm ci --only=production

# Copy source code
COPY apps/ apps/
COPY libs/ libs/

# Build applications
RUN npm run build:frontend
RUN npm run build:backend

# Production stage
FROM node:18-alpine AS production

WORKDIR /app

# Copy built applications
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./

# Install serve for frontend
RUN npm install -g serve

EXPOSE 8080

# Start script that runs both frontend and backend
CMD ["sh", "-c", "serve -s dist/apps/frontend -l 3000 & node dist/apps/backend/main.js"]
```

---

## 🐛 Troubleshooting Common Issues

### Build Failures

**Issue**: "Module not found" errors during build
```bash
# Solution: Ensure all dependencies are in package.json
npm install --save-dev @types/node @types/express
nx build backend --verbose
```

**Issue**: "Out of memory" during build
```bash
# Solution: Increase Node.js memory limit
export NODE_OPTIONS="--max-old-space-size=4096"
npm run build:frontend
```

### Deployment Failures

**Issue**: Railway deployment timeout
```bash
# Solution: Optimize build process
# Add to package.json:
{
  "scripts": {
    "build:quick": "nx build frontend --skip-nx-cache"
  }
}
```

**Issue**: Digital Ocean health check failures
```typescript
// Ensure health check endpoint returns 200
app.get('/health', (req, res) => {
  res.status(200).send('OK');
});
```

### Runtime Issues

**Issue**: Environment variables not loading
```bash
# Railway: Check variable names match exactly
railway variables list

# Digital Ocean: Verify in app dashboard
doctl apps get <app-id> --format json | jq '.spec.envs'
```

**Issue**: CORS errors between frontend and backend
```typescript
// Backend CORS configuration
import cors from 'cors';

const corsOptions = {
  origin: [
    'https://your-frontend.vercel.app',
    'https://frontend.railway.app',
    'http://localhost:3000'  // for development
  ],
  credentials: true
};

app.use(cors(corsOptions));
```

---

## 📊 Performance Optimization

### Frontend Optimizations

**Vite Configuration (apps/frontend/vite.config.ts):**
```typescript
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  build: {
    rollupOptions: {
      output: {
        manualChunks: {
          vendor: ['react', 'react-dom'],
          router: ['react-router-dom']
        }
      }
    }
  },
  server: {
    proxy: {
      '/api': {
        target: 'http://localhost:8080',
        changeOrigin: true
      }
    }
  }
});
```

### Backend Optimizations

**Express.js Production Configuration:**
```typescript
import compression from 'compression';
import helmet from 'helmet';

const app = express();

// Security middleware
app.use(helmet());

// Compression middleware
app.use(compression());

// Cache static assets
app.use(express.static('public', {
  maxAge: '1d',
  etag: false
}));

// Request logging in production
if (process.env.NODE_ENV === 'production') {
  app.use(morgan('combined'));
}
```

### Database Optimizations

**Connection Pool Configuration:**
```typescript
import { Pool } from 'pg';

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});
```

---

## ✅ Deployment Checklist

### Pre-Deployment
- [ ] All tests passing locally
- [ ] Environment variables configured
- [ ] Build scripts optimized
- [ ] Health check endpoints implemented
- [ ] CORS configuration updated
- [ ] Database migrations ready (if applicable)

### During Deployment
- [ ] Monitor build logs for errors
- [ ] Verify environment variables loaded correctly
- [ ] Test health check endpoints
- [ ] Confirm database connections
- [ ] Validate frontend/backend communication

### Post-Deployment
- [ ] Run end-to-end tests
- [ ] Performance testing completed
- [ ] SSL certificates validated
- [ ] Custom domain configured (if applicable)
- [ ] Monitoring and alerting setup
- [ ] Documentation updated for client handover

---

## 🔗 Next Steps

After successful deployment, proceed to:
- **[Best Practices](./best-practices.md)** - Production optimization strategies
- **[Client Handover Strategy](./client-handover-strategy.md)** - Preparing for client management
- **[Maintenance Guidelines](./maintenance-guidelines.md)** - Long-term maintenance procedures

---

*This implementation guide provides comprehensive steps for deploying Nx monorepos to managed platforms. For platform-specific optimizations and advanced configurations, refer to the detailed documentation sections.*