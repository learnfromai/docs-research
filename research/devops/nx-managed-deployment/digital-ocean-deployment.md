# Digital Ocean App Platform Deployment Guide

## 🎯 Overview

This guide provides comprehensive instructions for deploying full-stack Nx monorepo projects to Digital Ocean App Platform, the recommended solution for production deployments and client handovers.

---

## 📋 Prerequisites

### Required Accounts & Tools
- Digital Ocean account with billing enabled
- GitHub repository containing your Nx workspace
- `doctl` CLI tool (optional but recommended)
- Domain name (optional, for custom domains)

### Nx Project Requirements
```bash
# Verify your Nx workspace structure
nx-workspace/
├── apps/
│   ├── frontend/          # React + Vite application
│   └── backend/           # Express.js application
├── libs/                  # Shared libraries
├── package.json           # Root package.json
├── nx.json               # Nx configuration
└── .do/
    └── app.yaml          # Digital Ocean app specification
```

---

## 🚀 Step 1: Prepare Your Nx Project

### Optimize Build Configuration

#### Update package.json Scripts
```json
{
  "name": "my-nx-app",
  "scripts": {
    "build": "nx build --parallel",
    "build:frontend": "nx build frontend --configuration=production",
    "build:backend": "nx build backend --configuration=production",
    "build:all": "npm run build:frontend && npm run build:backend",
    "start:frontend": "npx serve dist/apps/frontend -s -n -L -p $PORT",
    "start:backend": "node dist/apps/backend/main.js",
    "test": "nx test",
    "lint": "nx lint"
  },
  "dependencies": {
    "serve": "^14.2.0",
    "express": "^4.18.2",
    "@nrwl/devkit": "latest"
  }
}
```

#### Frontend Build Optimization (apps/frontend/project.json)
```json
{
  "name": "frontend",
  "targets": {
    "build": {
      "executor": "@nrwl/vite:build",
      "outputs": ["{options.outputPath}"],
      "options": {
        "outputPath": "dist/apps/frontend"
      },
      "configurations": {
        "production": {
          "mode": "production",
          "optimization": true,
          "outputHashing": "all",
          "sourceMap": false,
          "namedChunks": false,
          "extractLicenses": true,
          "vendorChunk": false,
          "buildLibsFromSource": false
        }
      }
    }
  }
}
```

#### Backend Build Optimization (apps/backend/project.json)
```json
{
  "name": "backend",
  "targets": {
    "build": {
      "executor": "@nrwl/webpack:webpack",
      "outputs": ["{options.outputPath}"],
      "options": {
        "target": "node",
        "compiler": "tsc",
        "outputPath": "dist/apps/backend",
        "main": "apps/backend/src/main.ts",
        "tsConfig": "apps/backend/tsconfig.app.json",
        "optimization": false,
        "extractLicenses": false,
        "inspect": false
      },
      "configurations": {
        "production": {
          "optimization": true,
          "extractLicenses": true,
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
}
```

### Add Health Check Endpoints

#### Backend Health Check (apps/backend/src/main.ts)
```typescript
import express from 'express';
import cors from 'cors';
import { pool } from './database/connection'; // Your database connection

const app = express();

// CORS configuration for production
const corsOptions = {
  origin: process.env.FRONTEND_URL || ['http://localhost:4200'],
  credentials: true,
  optionsSuccessStatus: 200
};

app.use(cors(corsOptions));
app.use(express.json());

// Health check endpoint (required for DO App Platform)
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    version: process.env.npm_package_version || '1.0.0',
    environment: process.env.NODE_ENV || 'development'
  });
});

// Database health check
app.get('/health/db', async (req, res) => {
  try {
    const result = await pool.query('SELECT NOW()');
    res.status(200).json({
      status: 'healthy',
      database: 'connected',
      timestamp: result.rows[0].now
    });
  } catch (error) {
    res.status(503).json({
      status: 'unhealthy',
      database: 'disconnected',
      error: error.message
    });
  }
});

// Your API routes
app.get('/api', (req, res) => {
  res.json({ message: 'API is running' });
});

// Error handling middleware
app.use((error: Error, req: express.Request, res: express.Response, next: express.NextFunction) => {
  console.error('Unhandled error:', error);
  res.status(500).json({
    error: 'Internal server error',
    message: process.env.NODE_ENV === 'development' ? error.message : 'Something went wrong'
  });
});

const port = process.env.PORT || 8080;
app.listen(port, () => {
  console.log(`Backend server running on port ${port}`);
  console.log(`Environment: ${process.env.NODE_ENV}`);
  console.log(`Health check available at /health`);
});
```

#### Frontend Health Check (Optional)
Create `apps/frontend/public/health.json`:
```json
{
  "status": "healthy",
  "service": "frontend",
  "version": "1.0.0"
}
```

---

## 🔧 Step 2: Create Digital Ocean App Specification

### Create .do/app.yaml Configuration

Create the directory and file:
```bash
mkdir -p .do
touch .do/app.yaml
```

#### Complete App Specification
```yaml
name: my-nx-fullstack-app
region: nyc1

# Services configuration
services:
  # Frontend Service (React + Vite)
  - name: frontend
    source_dir: /
    github:
      repo: your-username/your-nx-repo
      branch: main
      deploy_on_push: true
    
    # Build configuration
    build_command: |
      echo "Installing dependencies..."
      npm ci --only=production --silent
      echo "Building frontend application..."
      npm run build:frontend
      echo "Build completed successfully"
    
    # Runtime configuration
    run_command: npx serve dist/apps/frontend -s -n -L -p $PORT
    
    # Service settings
    environment_slug: node-js
    instance_count: 1
    instance_size_slug: basic-xxs
    http_port: 8080
    
    # Health check configuration
    health_check:
      http_path: /health.json
      initial_delay_seconds: 30
      period_seconds: 10
      timeout_seconds: 5
      success_threshold: 1
      failure_threshold: 3
    
    # Routing configuration
    routes:
      - path: /
        preserve_path_prefix: false
    
    # Environment variables
    envs:
      - key: NODE_ENV
        value: "production"
      - key: VITE_API_URL
        value: "${backend.PUBLIC_URL}"
      - key: VITE_APP_VERSION
        value: "1.0.0"

  # Backend Service (Express.js API)
  - name: backend
    source_dir: /
    github:
      repo: your-username/your-nx-repo
      branch: main
      deploy_on_push: true
    
    # Build configuration
    build_command: |
      echo "Installing dependencies..."
      npm ci --only=production --silent
      echo "Building backend application..."
      npm run build:backend
      echo "Build completed successfully"
    
    # Runtime configuration
    run_command: node dist/apps/backend/main.js
    
    # Service settings
    environment_slug: node-js
    instance_count: 1
    instance_size_slug: basic-xxs
    http_port: 8080
    
    # Health check configuration
    health_check:
      http_path: /health
      initial_delay_seconds: 60
      period_seconds: 10
      timeout_seconds: 5
      success_threshold: 1
      failure_threshold: 3
    
    # Routing configuration
    routes:
      - path: /api
        preserve_path_prefix: true
      - path: /health
        preserve_path_prefix: true
    
    # Environment variables
    envs:
      - key: NODE_ENV
        value: "production"
      - key: PORT
        value: "8080"
      - key: DATABASE_URL
        value: "${db.DATABASE_URL}"
      - key: JWT_SECRET
        value: "${JWT_SECRET}"
      - key: CORS_ORIGIN
        value: "${frontend.PUBLIC_URL}"

# Database configuration
databases:
  - name: db
    engine: PG
    version: "15"
    production: true
    num_nodes: 1
    size: db-s-1vcpu-1gb

# Global environment variables
envs:
  - key: JWT_SECRET
    value: "your-super-secret-jwt-key-change-in-production"
    type: SECRET
  - key: APP_NAME
    value: "My Nx Fullstack App"
    type: GENERAL

# Domain configuration (optional)
domains:
  - domain: yourdomain.com
    type: PRIMARY
    zone: yourdomain.com
  - domain: www.yourdomain.com
    type: ALIAS
    zone: yourdomain.com

# Static site configuration (alternative to service for frontend)
static_sites:
  - name: frontend-static
    source_dir: /
    github:
      repo: your-username/your-nx-repo
      branch: main
    build_command: |
      npm ci --only=production
      npm run build:frontend
    output_dir: dist/apps/frontend
    catchall_document: index.html
    error_document: 404.html
    cors:
      allow_origins:
        - exact: "https://yourdomain.com"
        - regex: "^https://.*\\.yourdomain\\.com$"
      allow_methods:
        - GET
        - POST
        - PUT
        - DELETE
      allow_headers:
        - Content-Type
        - Authorization
    envs:
      - key: NODE_ENV
        value: "production"
      - key: VITE_API_URL
        value: "${backend.PUBLIC_URL}"
```

### Alternative Simplified Configuration

For simpler projects, use this minimal configuration:
```yaml
name: my-nx-app
region: nyc1

services:
  - name: app
    source_dir: /
    github:
      repo: your-username/your-repo
      branch: main
    build_command: npm ci && npm run build:all
    run_command: npm start
    environment_slug: node-js
    instance_count: 1
    instance_size_slug: basic-xxs
    routes:
      - path: /
    envs:
      - key: NODE_ENV
        value: "production"

databases:
  - name: db
    engine: PG
    version: "15"
```

---

## 🌐 Step 3: Deploy to Digital Ocean

### Method 1: Using Digital Ocean Web Console (Recommended for Beginners)

#### Create New App
1. Navigate to [Digital Ocean App Platform](https://cloud.digitalocean.com/apps)
2. Click **"Create App"**
3. Choose **"GitHub"** as your source
4. Authorize Digital Ocean to access your GitHub repositories
5. Select your Nx monorepo repository
6. Choose your deployment branch (typically `main`)

#### Import App Specification
1. In the app creation wizard, click **"Edit App Spec"**
2. Replace the generated spec with your `.do/app.yaml` content
3. Review the configuration:
   - Verify service names and build commands
   - Check environment variables
   - Confirm database settings
4. Click **"Create Resources"**

#### Monitor Deployment
1. Digital Ocean will begin the build process
2. Monitor the build logs in real-time
3. Typical deployment time: 8-15 minutes for initial deployment
4. Verify successful deployment in the dashboard

### Method 2: Using doctl CLI (Recommended for Developers)

#### Install doctl CLI
```bash
# macOS
brew install doctl

# Windows
# Download from https://github.com/digitalocean/doctl/releases

# Linux
curl -OL https://github.com/digitalocean/doctl/releases/latest/download/doctl-linux-amd64.tar.gz
tar xf doctl-linux-amd64.tar.gz
sudo mv doctl /usr/local/bin
```

#### Authenticate with Digital Ocean
```bash
# Create API token at https://cloud.digitalocean.com/account/api/tokens
doctl auth init

# Verify authentication
doctl account get
```

#### Deploy Application
```bash
# Validate app specification
doctl apps spec validate .do/app.yaml

# Create the application
doctl apps create --spec .do/app.yaml

# Monitor deployment
doctl apps list
doctl apps get <app-id>

# View logs
doctl apps logs <app-id> --follow
```

#### Update Existing Application
```bash
# Update app with new specification
doctl apps update <app-id> --spec .do/app.yaml

# Check deployment status
doctl apps get <app-id> --format json | jq '.status'
```

---

## ⚙️ Step 4: Environment Configuration

### Set Environment Variables

#### Through Digital Ocean Dashboard
1. Navigate to your app in the App Platform dashboard
2. Go to **Settings** → **App-Level Environment Variables**
3. Add required variables:

```yaml
Production Environment Variables:
JWT_SECRET: "your-production-jwt-secret-32-characters-minimum"
DATABASE_URL: "automatically-provided-by-managed-database"
NODE_ENV: "production"
CORS_ORIGIN: "https://your-frontend-domain.com"
LOG_LEVEL: "info"
```

#### Through doctl CLI
```bash
# Set environment variables
doctl apps update <app-id> --spec .do/app.yaml

# Or update individual variables
doctl apps env set <app-id> JWT_SECRET=your-secret-key
doctl apps env set <app-id> LOG_LEVEL=info

# View current environment variables
doctl apps env list <app-id>
```

### Database Connection Configuration

#### Access Database Credentials
```bash
# Get database connection details
doctl apps get <app-id> --format json | jq '.spec.databases[0]'

# Database URL is automatically injected as ${db.DATABASE_URL}
```

#### Database Migration Setup
Create a migration script in your backend:
```typescript
// apps/backend/src/database/migrate.ts
import { Pool } from 'pg';

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false
});

export async function runMigrations() {
  try {
    // Example migration
    await pool.query(`
      CREATE TABLE IF NOT EXISTS users (
        id SERIAL PRIMARY KEY,
        email VARCHAR(255) UNIQUE NOT NULL,
        password_hash VARCHAR(255) NOT NULL,
        first_name VARCHAR(100),
        last_name VARCHAR(100),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    `);
    
    console.log('Database migrations completed successfully');
  } catch (error) {
    console.error('Migration failed:', error);
    throw error;
  }
}

// Run migrations on startup in production
if (process.env.NODE_ENV === 'production' && require.main === module) {
  runMigrations()
    .then(() => process.exit(0))
    .catch(() => process.exit(1));
}
```

---

## 🔒 Step 5: Security Configuration

### SSL and Domain Setup

#### Add Custom Domain
1. In the App Platform dashboard, go to **Settings** → **Domains**
2. Click **"Add Domain"**
3. Enter your domain name (e.g., `yourdomain.com`)
4. Configure DNS records:
   ```
   Type: CNAME
   Name: www
   Value: your-app.ondigitalocean.app
   
   Type: A
   Name: @
   Value: [Digital Ocean IP provided]
   ```

#### SSL Certificate Configuration
```yaml
# In your app.yaml, domains are automatically secured with Let's Encrypt
domains:
  - domain: yourdomain.com
    type: PRIMARY
    zone: yourdomain.com
    certificate_id: null  # Auto-generated Let's Encrypt certificate
```

### Environment Security

#### Secrets Management
```bash
# Add sensitive environment variables as secrets
doctl apps env set <app-id> JWT_SECRET=your-jwt-secret-here --type=SECRET
doctl apps env set <app-id> DATABASE_PASSWORD=your-db-password --type=SECRET

# Regular environment variables
doctl apps env set <app-id> APP_NAME="My Nx App" --type=GENERAL
```

#### CORS Configuration for Production
```typescript
// apps/backend/src/main.ts
const corsOptions = {
  origin: [
    process.env.FRONTEND_URL,
    process.env.CORS_ORIGIN,
    'https://yourdomain.com',
    'https://www.yourdomain.com'
  ].filter(Boolean),
  credentials: true,
  optionsSuccessStatus: 200,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With']
};

app.use(cors(corsOptions));
```

---

## 📊 Step 6: Monitoring and Optimization

### Application Monitoring

#### Built-in Monitoring Dashboard
1. Navigate to your app in Digital Ocean dashboard
2. Go to **Insights** tab to view:
   - Request volume and response times
   - Error rates and status codes
   - Resource utilization (CPU, memory)
   - Build and deployment history

#### Custom Monitoring Setup
```typescript
// apps/backend/src/middleware/monitoring.ts
import { Request, Response, NextFunction } from 'express';

interface RequestMetrics {
  method: string;
  url: string;
  statusCode: number;
  responseTime: number;
  timestamp: Date;
}

const metrics: RequestMetrics[] = [];

export const monitoringMiddleware = (req: Request, res: Response, next: NextFunction) => {
  const startTime = Date.now();
  
  res.on('finish', () => {
    const responseTime = Date.now() - startTime;
    
    metrics.push({
      method: req.method,
      url: req.url,
      statusCode: res.statusCode,
      responseTime,
      timestamp: new Date()
    });
    
    // Log slow requests
    if (responseTime > 1000) {
      console.warn(`Slow request detected: ${req.method} ${req.url} - ${responseTime}ms`);
    }
  });
  
  next();
};

// Metrics endpoint for monitoring
export const getMetrics = (req: Request, res: Response) => {
  const recentMetrics = metrics.slice(-100); // Last 100 requests
  const averageResponseTime = recentMetrics.reduce((sum, m) => sum + m.responseTime, 0) / recentMetrics.length;
  
  res.json({
    totalRequests: metrics.length,
    recentRequests: recentMetrics.length,
    averageResponseTime: Math.round(averageResponseTime),
    errorRate: recentMetrics.filter(m => m.statusCode >= 400).length / recentMetrics.length
  });
};
```

### Performance Optimization

#### Build Performance
```yaml
# Optimize app.yaml for faster builds
services:
  - name: backend
    build_command: |
      # Use npm ci for faster, reliable installs
      npm ci --only=production --silent
      
      # Enable build caching
      export NODE_OPTIONS="--max-old-space-size=4096"
      
      # Build with production optimizations
      npm run build:backend
    
    # Enable build caching
    environment_slug: node-js
    instance_size_slug: basic-s  # Use more powerful instance for builds
```

#### Runtime Optimization
```typescript
// apps/backend/src/main.ts - Production optimizations
import compression from 'compression';
import helmet from 'helmet';

const app = express();

// Security middleware
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      scriptSrc: ["'self'"],
      imgSrc: ["'self'", "data:", "https:"]
    }
  }
}));

// Compression middleware
app.use(compression({
  filter: (req, res) => {
    if (req.headers['x-no-compression']) {
      return false;
    }
    return compression.filter(req, res);
  }
}));

// Cache static assets
app.use('/static', express.static('public', {
  maxAge: '1d',
  etag: false
}));
```

---

## 🔄 Step 7: CI/CD Integration

### GitHub Actions Workflow

Create `.github/workflows/deploy-do.yml`:
```yaml
name: Deploy to Digital Ocean

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

env:
  NODE_VERSION: '18'

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Run tests
        run: npm run test -- --passWithNoTests

      - name: Run linting
        run: npm run lint

      - name: Build applications
        run: |
          npm run build:frontend
          npm run build:backend

  deploy:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    
    steps:
      - uses: actions/checkout@v4

      - name: Install doctl
        uses: digitalocean/action-doctl@v2
        with:
          token: ${{ secrets.DIGITALOCEAN_ACCESS_TOKEN }}

      - name: Deploy to Digital Ocean
        run: |
          # Update the app with latest spec
          doctl apps update ${{ secrets.DO_APP_ID }} --spec .do/app.yaml
          
          # Wait for deployment to complete
          doctl apps get ${{ secrets.DO_APP_ID }} --wait
          
      - name: Verify deployment
        run: |
          # Get app URL
          APP_URL=$(doctl apps get ${{ secrets.DO_APP_ID }} --format json | jq -r '.live_url')
          
          # Health check
          curl -f $APP_URL/health || exit 1
          
          echo "Deployment successful: $APP_URL"
```

### Required GitHub Secrets
```bash
# Add these secrets to your GitHub repository settings
DIGITALOCEAN_ACCESS_TOKEN: "your-do-api-token"
DO_APP_ID: "your-app-id-from-doctl-apps-list"
```

---

## 🐛 Troubleshooting Common Issues

### Build Failures

#### "Module not found" Errors
```yaml
# Solution: Ensure all dependencies are in package.json
Problem: Missing dependencies in production build

Fix in package.json:
{
  "dependencies": {
    "@nrwl/devkit": "latest",
    "serve": "^14.2.0",
    "express": "^4.18.2"
  }
}
```

#### "Out of memory" During Build
```yaml
# Solution: Increase build instance size
Problem: Build fails with heap out of memory

Fix in app.yaml:
services:
  - name: backend
    instance_size_slug: basic-s  # Upgrade from basic-xxs
    build_command: |
      export NODE_OPTIONS="--max-old-space-size=4096"
      npm ci && npm run build:backend
```

### Runtime Issues

#### Health Check Failures
```typescript
// Ensure health check endpoint is accessible
app.get('/health', (req, res) => {
  // Must return 200 status
  res.status(200).json({ status: 'healthy' });
});

// Check health check configuration in app.yaml
health_check:
  http_path: /health
  initial_delay_seconds: 30  # Allow time for app to start
  timeout_seconds: 10        # Increase if app is slow to respond
```

#### Database Connection Issues
```typescript
// Check database connection configuration
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: {
    rejectUnauthorized: false  // Required for managed databases
  },
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000
});
```

#### CORS Errors
```typescript
// Ensure CORS is properly configured for production
const corsOptions = {
  origin: [
    process.env.FRONTEND_URL,
    'https://your-app.ondigitalocean.app'
  ],
  credentials: true
};
```

### Deployment Troubleshooting

#### Check Application Logs
```bash
# View real-time logs
doctl apps logs <app-id> --follow

# View specific service logs
doctl apps logs <app-id> --service backend --follow

# View build logs
doctl apps logs <app-id> --type=build
```

#### Monitor Deployment Status
```bash
# Check deployment status
doctl apps get <app-id>

# Check service health
doctl apps get <app-id> --format json | jq '.services[].health'

# View deployment history
doctl apps list-deployments <app-id>
```

---

## 📈 Scaling and Optimization

### Horizontal Scaling Configuration

#### Auto-scaling Setup
```yaml
# app.yaml configuration for auto-scaling
services:
  - name: backend
    instance_count: 2          # Start with 2 instances
    instance_size_slug: basic-s
    autoscaling:
      min_instance_count: 1    # Minimum instances
      max_instance_count: 5    # Maximum instances
      metrics:
        cpu_threshold: 70      # Scale when CPU > 70%
        memory_threshold: 80   # Scale when memory > 80%
```

### Database Scaling

#### Database Upgrade Path
```bash
# Upgrade database size through doctl
doctl apps update <app-id> --spec .do/app.yaml

# In app.yaml, update database configuration:
databases:
  - name: db
    engine: PG
    version: "15"
    num_nodes: 1
    size: db-s-2vcpu-2gb  # Upgraded from db-s-1vcpu-1gb
    production: true
```

### Performance Monitoring

#### Set Up Alerts
```bash
# Create monitoring alerts through Digital Ocean dashboard
# Go to Monitoring → Alerting → Create Alert Policy

# Sample alert configurations:
# - CPU usage > 80% for 5 minutes
# - Memory usage > 85% for 5 minutes
# - Error rate > 5% for 10 minutes
# - Response time > 2 seconds for 10 minutes
```

---

## ✅ Deployment Checklist

### Pre-Deployment
- [ ] All tests passing locally
- [ ] Build commands optimized in app.yaml
- [ ] Health check endpoints implemented
- [ ] Environment variables configured
- [ ] Database migration scripts ready
- [ ] CORS settings updated for production domains

### During Deployment
- [ ] Monitor build logs for errors
- [ ] Verify environment variables loaded correctly
- [ ] Test health check endpoints
- [ ] Confirm database connectivity
- [ ] Validate frontend/backend communication

### Post-Deployment
- [ ] Run end-to-end tests against production
- [ ] Verify SSL certificate installation
- [ ] Test custom domain configuration (if applicable)
- [ ] Set up monitoring alerts
- [ ] Document deployment process for client
- [ ] Update DNS records if needed

---

## 📚 Next Steps

After successful deployment:
- **[Client Handover Strategy](./client-handover-strategy.md)** - Prepare for client management
- **[Maintenance Guidelines](./maintenance-guidelines.md)** - Long-term maintenance procedures
- **[Cost Analysis](./cost-analysis.md)** - Optimize costs and monitor usage

---

*This Digital Ocean App Platform deployment guide provides comprehensive steps for production-ready Nx monorepo deployments. For troubleshooting or advanced configurations, refer to the [troubleshooting guide](./troubleshooting-guide.md).*