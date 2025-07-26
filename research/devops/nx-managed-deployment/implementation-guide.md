# Implementation Guide: Deploying Nx Projects to Managed Platforms

## 🎯 Overview

This guide provides step-by-step instructions for deploying full-stack Nx projects to managed cloud platforms. We'll cover the most cost-effective approaches for React Vite frontends, Express.js backends, and MySQL databases.

## 🏗 Pre-Deployment Setup

### Nx Project Structure Preparation

First, ensure your Nx project follows the deployment-ready structure:

```bash
# Generate production-ready apps if not already created
npx nx g @nx/react:app frontend --bundler=vite --routing --style=css
npx nx g @nx/express:app backend
npx nx g @nx/js:lib shared-types
```

### Build Configuration

**Frontend Build Setup (React + Vite)**
```typescript
// apps/frontend/vite.config.ts
export default defineConfig({
  base: './', // Important for deployment
  build: {
    outDir: '../../dist/apps/frontend',
    reportCompressedSize: true,
    commonjsOptions: {
      transformMixedEsModules: true,
    },
  },
  server: {
    port: 3000,
    host: '0.0.0.0'
  },
  preview: {
    port: 3000,
    host: '0.0.0.0'
  }
});
```

**Backend Configuration (Express.js)**
```typescript
// apps/backend/src/main.ts
import express from 'express';
import cors from 'cors';

const app = express();
const port = process.env.PORT || 3001;

app.use(cors({
  origin: process.env.FRONTEND_URL || 'http://localhost:3000',
  credentials: true
}));

app.use(express.json());

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'OK', timestamp: new Date().toISOString() });
});

app.listen(port, '0.0.0.0', () => {
  console.log(`🚀 Backend running on port ${port}`);
});
```

## 🚂 Option 1: Railway Deployment (Most Cost-Effective)

### Step 1: Create Railway Account & Project

1. Visit [railway.app](https://railway.app) and sign up with GitHub
2. Click "New Project" → "Deploy from GitHub repo"
3. Select your Nx repository

### Step 2: Configure Backend Service

**Create `railway.toml` in project root:**
```toml
# railway.toml
[build]
builder = "nixpacks"

[deploy]
startCommand = "nx serve backend --prod"
healthcheckPath = "/health"
healthcheckTimeout = 300
restartPolicyType = "on_failure"

[[services]]
[services.backend]
source = "apps/backend"
buildCommand = "nx build backend --prod"
startCommand = "node dist/apps/backend/main.js"

[services.backend.variables]
NODE_ENV = "production"
PORT = "3001"
```

**Package.json scripts:**
```json
{
  "scripts": {
    "build:backend": "nx build backend --prod",
    "start:backend": "node dist/apps/backend/main.js",
    "build:frontend": "nx build frontend --prod",
    "start:frontend": "nx serve frontend --prod"
  }
}
```

### Step 3: Deploy Frontend Static Site

1. In Railway dashboard: "New Service" → "Empty Service"
2. Connect to same GitHub repo
3. Configure build settings:
   - **Build Command**: `nx build frontend --prod`
   - **Output Directory**: `dist/apps/frontend`
   - **Install Command**: `npm install`

### Step 4: Add MySQL Database

1. Railway dashboard → "New Service" → "Database" → "MySQL"
2. Note connection credentials automatically provided
3. Update backend environment variables:

```typescript
// apps/backend/src/config/database.ts
export const databaseConfig = {
  host: process.env.MYSQLHOST,
  port: parseInt(process.env.MYSQLPORT || '3306'),
  user: process.env.MYSQLUSER,
  password: process.env.MYSQLPASSWORD,
  database: process.env.MYSQLDATABASE,
  ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false
};
```

### Step 5: Environment Variables Setup

**Backend variables in Railway:**
```bash
NODE_ENV=production
MYSQLHOST=${{MySQL.MYSQLHOST}}
MYSQLPORT=${{MySQL.MYSQLPORT}}
MYSQLUSER=${{MySQL.MYSQLUSER}}
MYSQLPASSWORD=${{MySQL.MYSQLPASSWORD}}
MYSQLDATABASE=${{MySQL.MYSQLDATABASE}}
FRONTEND_URL=https://your-frontend.railway.app
```

**Frontend variables:**
```bash
VITE_API_URL=https://your-backend.railway.app
```

## 🎨 Option 2: Render Deployment (Production-Ready)

### Step 1: Render Account Setup

1. Sign up at [render.com](https://render.com) with GitHub
2. Click "New" → "Web Service"
3. Connect your Nx repository

### Step 2: Backend Service Configuration

**Create `render.yaml` in project root:**
```yaml
# render.yaml
services:
  - type: web
    name: nx-backend
    env: node
    buildCommand: nx build backend --prod
    startCommand: node dist/apps/backend/main.js
    envVars:
      - key: NODE_ENV
        value: production
      - key: PORT
        value: 10000
      - key: DATABASE_URL
        fromDatabase:
          name: nx-mysql
          property: connectionString

  - type: web
    name: nx-frontend
    env: static
    buildCommand: nx build frontend --prod
    staticPublishPath: ./dist/apps/frontend
    headers:
      - path: /*
        name: X-Frame-Options
        value: DENY
    routes:
      - type: rewrite
        source: /*
        destination: /index.html

databases:
  - name: nx-mysql
    databaseName: nx_production
    user: nx_user
```

### Step 3: Manual Service Setup (Alternative)

**Backend Service:**
1. Render → "New Web Service"
2. **Environment**: Node
3. **Build Command**: `nx build backend --prod`
4. **Start Command**: `node dist/apps/backend/main.js`
5. **Auto-Deploy**: Yes

**Frontend Service:**
1. Render → "New Static Site"  
2. **Build Command**: `nx build frontend --prod`
3. **Publish Directory**: `dist/apps/frontend`
4. **Auto-Deploy**: Yes

### Step 4: Database Setup

1. Render → "New PostgreSQL" (MySQL via external provider)
2. For MySQL: Use PlanetScale or AWS RDS
3. Add connection string to backend environment variables

## 🌊 Option 3: Digital Ocean App Platform

### Step 1: App Platform Setup

1. Digital Ocean → "App Platform" → "Create App"
2. Connect GitHub repository
3. Select "Monorepo" deployment type

### Step 2: App Spec Configuration

**Create `.do/app.yaml`:**
```yaml
# .do/app.yaml
name: nx-fullstack-app
services:
- name: backend
  source_dir: apps/backend
  build_command: cd ../.. && nx build backend --prod
  run_command: node ../../dist/apps/backend/main.js
  environment_slug: node-js
  instance_count: 1
  instance_size_slug: basic-xxs
  http_port: 8080
  envs:
  - key: NODE_ENV
    value: "production"
  - key: DATABASE_URL
    value: "${nx-mysql.DATABASE_URL}"

- name: frontend
  source_dir: apps/frontend
  build_command: cd ../.. && nx build frontend --prod
  run_command: cp -r ../../dist/apps/frontend/* .
  environment_slug: node-js
  instance_count: 1
  instance_size_slug: basic-xxs
  routes:
  - path: /
  envs:
  - key: VITE_API_URL
    value: "${backend.PUBLIC_URL}"

databases:
- name: nx-mysql
  engine: MYSQL
  version: "8"
  size: db-s-1vcpu-1gb
```

### Step 3: Managed Database

1. Digital Ocean → "Databases" → "Create Database Cluster"
2. Select MySQL 8.0
3. Choose appropriate sizing (starts at $15/month)
4. Add connection details to app environment

## 🔄 Continuous Deployment Setup

### GitHub Actions for Railway

**Create `.github/workflows/deploy.yml`:**
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
        run: |
          nx build backend --prod
          nx build frontend --prod
      
      - name: Deploy to Railway
        run: |
          npm install -g @railway/cli
          railway login --browserless
          railway up --service backend
          railway up --service frontend
        env:
          RAILWAY_TOKEN: ${{ secrets.RAILWAY_TOKEN }}
```

### Auto-deployment Configuration

**All platforms support auto-deployment via:**
- GitHub webhook integration
- Automatic builds on git push
- Branch-specific deployments
- Pull request previews (Vercel, Netlify)

## 🔧 Environment Configuration

### Development vs Production

**Development (Local):**
```bash
# .env.local
VITE_API_URL=http://localhost:3001
DATABASE_URL=mysql://user:pass@localhost:3306/nx_dev
NODE_ENV=development
```

**Production (Platform-specific):**
```bash
# Production environment variables
VITE_API_URL=https://api.yourapp.com
DATABASE_URL=mysql://user:pass@host:3306/nx_prod
NODE_ENV=production
CORS_ORIGIN=https://yourapp.com
```

## 📦 Build Optimization

### Dockerfile (Optional for Railway/Render)

```dockerfile
# Dockerfile
FROM node:18-alpine AS builder

WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

COPY . .
RUN nx build backend --prod
RUN nx build frontend --prod

FROM node:18-alpine AS runner
WORKDIR /app

COPY --from=builder /app/dist/apps/backend ./backend
COPY --from=builder /app/dist/apps/frontend ./frontend
COPY --from=builder /app/node_modules ./node_modules

EXPOSE 3001
CMD ["node", "backend/main.js"]
```

### Bundle Analysis

```bash
# Analyze bundle sizes
nx build frontend --prod --analyze
nx build backend --prod --verbose

# Check build outputs
ls -la dist/apps/frontend
ls -la dist/apps/backend
```

## ✅ Deployment Checklist

### Pre-deployment
- [ ] Build commands tested locally
- [ ] Environment variables configured
- [ ] Database connection string available
- [ ] CORS origins set correctly
- [ ] Health check endpoint working

### Post-deployment
- [ ] Frontend loads correctly
- [ ] API endpoints responding
- [ ] Database connectivity verified
- [ ] Custom domain configured
- [ ] SSL certificate active
- [ ] Monitoring/logging enabled

## 🚨 Common Issues & Solutions

### Build Failures
```bash
# Clear Nx cache
nx reset

# Verify build locally
nx build frontend --prod
nx build backend --prod

# Check package.json scripts
npm run build:frontend
npm run build:backend
```

### Database Connection Issues
```typescript
// Add connection retry logic
const connectWithRetry = () => {
  return mysql.createConnection({
    ...databaseConfig,
    acquireTimeout: 15000,
    timeout: 60000,
    reconnect: true
  });
};
```

### CORS Errors
```typescript
// Configure CORS properly  
app.use(cors({
  origin: [
    'http://localhost:3000',
    'https://yourapp.com',
    process.env.FRONTEND_URL
  ],
  credentials: true
}));
```

## 🔗 Next Steps

- **[Best Practices](./best-practices.md)**: Production deployment patterns
- **[Database Deployment Guide](./database-deployment-guide.md)**: MySQL hosting strategies
- **[Troubleshooting](./troubleshooting.md)**: Common issues and solutions

---

*Implementation Guide | Nx Managed Deployment | Step-by-step deployment instructions*