# Railway.com Deployment Guide for Nx Applications

## 🚀 Quick Start

This guide provides detailed Railway.com platform-specific instructions for deploying Nx React/Express applications, with focus on clinic management system requirements.

## 🏗️ Railway.com Platform Overview

### Railway Services Architecture
```
Railway Platform Services:
├── 🌐 Static Sites (Frontend)
│   ├── CDN Distribution
│   ├── Automatic HTTPS
│   └── Custom Domains
├── ⚡ Web Services (Backend)
│   ├── Node.js Runtime
│   ├── Auto-scaling
│   └── Health Monitoring
├── 🗄️ Databases
│   ├── PostgreSQL
│   ├── MySQL
│   └── Redis
└── 🔧 Environment Management
    ├── Variables & Secrets
    ├── Service Linking
    └── Deployment Hooks
```

---

## 📋 Pre-deployment Setup

### Step 1: Railway Account Setup
```bash
# Install Railway CLI
npm install -g @railway/cli

# Login to Railway
railway login

# Verify authentication
railway whoami
```

### Step 2: Project Structure Verification
```bash
# Verify Nx workspace structure
nx list
nx show project frontend
nx show project backend

# Test local builds
nx build frontend --prod
nx build backend --prod
```

### Step 3: Environment Configuration
```bash
# Create environment files
touch apps/frontend/.env.production
touch apps/backend/.env.production
```

---

## 🎯 Deployment Approach 1: Separate Services (Recommended)

### Frontend Static Site Deployment

#### 1.1 Prepare React App for Railway Static
```typescript
// apps/frontend/vite.config.ts
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import { VitePWA } from 'vite-plugin-pwa'

export default defineConfig({
  plugins: [
    react(),
    VitePWA({
      registerType: 'autoUpdate',
      workbox: {
        globPatterns: ['**/*.{js,css,html,ico,png,svg,woff2}']
      }
    })
  ],
  build: {
    outDir: 'dist',
    assetsDir: 'assets',
    sourcemap: false,        // Disable in production
    minify: 'esbuild',
    target: 'es2020',
    rollupOptions: {
      output: {
        manualChunks: {
          vendor: ['react', 'react-dom'],
          clinic: ['./src/modules/patient', './src/modules/appointment']
        }
      }
    }
  },
  base: '/',                 // Important for Railway static hosting
  server: {
    port: 4200,
    host: true
  }
})
```

#### 1.2 Railway Static Site Configuration
```json
// apps/frontend/railway.json
{
  "builder": "NIXPACKS",
  "buildCommand": "npm run build:frontend:prod",
  "staticPublishPath": "dist/apps/frontend",
  "headers": {
    "/*": {
      "Cache-Control": "public, max-age=31536000, immutable"
    },
    "/index.html": {
      "Cache-Control": "public, max-age=0, must-revalidate"
    },
    "/sw.js": {
      "Cache-Control": "public, max-age=0, must-revalidate"
    }
  }
}
```

#### 1.3 Deploy Frontend to Railway
```bash
# Navigate to project root
cd /path/to/your/nx-workspace

# Create Railway project for frontend
railway project create clinic-frontend

# Set build configuration
railway env set NIXPACKS_BUILD_CMD="npm run build:frontend:prod"
railway env set NIXPACKS_INSTALL_CMD="npm ci"

# Deploy static site
railway up --service frontend

# Get deployment URL
railway domain
```

### Backend Web Service Deployment

#### 2.1 Configure Express for Railway
```typescript
// apps/backend/src/main.ts
import express from 'express'
import cors from 'cors'
import helmet from 'helmet'
import compression from 'compression'

const app = express()

// Security middleware
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      scriptSrc: ["'self'"],
      imgSrc: ["'self'", "data:", "https:"],
      connectSrc: ["'self'", process.env.FRONTEND_URL]
    }
  }
}))

// Compression middleware
app.use(compression())

// CORS configuration for Railway deployment
app.use(cors({
  origin: function (origin, callback) {
    const allowedOrigins = [
      'http://localhost:4200',                    // Development
      process.env.FRONTEND_URL,                   // Production frontend
      /^https:\/\/.*\.railway\.app$/             // Railway preview deployments
    ]
    
    if (!origin || allowedOrigins.some(allowed => 
      typeof allowed === 'string' ? allowed === origin : allowed.test(origin)
    )) {
      callback(null, true)
    } else {
      callback(new Error('Not allowed by CORS'))
    }
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Clinic-ID']
}))

app.use(express.json({ limit: '10mb' }))
app.use(express.urlencoded({ extended: true, limit: '10mb' }))

// Health check endpoint (required for Railway)
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    memory: process.memoryUsage(),
    version: process.env.npm_package_version || '1.0.0'
  })
})

// API routes
app.use('/api', apiRoutes)

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({ error: 'Route not found' })
})

// Error handler
app.use((error, req, res, next) => {
  console.error('Error:', error)
  res.status(500).json({ 
    error: process.env.NODE_ENV === 'production' 
      ? 'Internal server error' 
      : error.message 
  })
})

const port = process.env.PORT || 3000
app.listen(port, '0.0.0.0', () => {
  console.log(`🚀 Server running on port ${port}`)
  console.log(`📊 Health check: http://localhost:${port}/health`)
})
```

#### 2.2 Railway Backend Configuration
```json
// apps/backend/railway.json
{
  "builder": "NIXPACKS",
  "buildCommand": "npm run build:backend:prod",
  "startCommand": "node dist/apps/backend/main.js",
  "healthcheckPath": "/health",
  "healthcheckTimeout": 30,
  "restartPolicy": "on-failure"
}
```

#### 2.3 Deploy Backend to Railway
```bash
# Create Railway project for backend
railway project create clinic-backend

# Set environment variables
railway env set NODE_ENV=production
railway env set PORT=3000
railway env set FRONTEND_URL=https://clinic-frontend.railway.app

# Add database if needed
railway add postgresql

# Deploy backend service
railway up --service backend

# Monitor deployment
railway logs
```

---

## 🔄 Deployment Approach 2: Unified Service

### Unified Express + React Deployment

#### 1.1 Configure Express to Serve React Build
```typescript
// apps/backend/src/main.ts (unified version)
import express from 'express'
import path from 'path'
import compression from 'compression'

const app = express()

// Middleware
app.use(compression())
app.use(express.json())

// Serve static files from React build
const frontendPath = path.join(__dirname, '../../../dist/apps/frontend')
console.log('Serving static files from:', frontendPath)

app.use(express.static(frontendPath, {
  maxAge: '1y',
  etag: true,
  lastModified: true,
  setHeaders: (res, filePath) => {
    if (filePath.endsWith('index.html') || filePath.endsWith('sw.js')) {
      res.setHeader('Cache-Control', 'public, max-age=0, must-revalidate')
    }
  }
}))

// API routes (must come before catch-all)
app.use('/api', apiRoutes)

// Health check
app.get('/health', (req, res) => {
  res.json({ 
    status: 'healthy',
    services: ['frontend', 'backend'],
    timestamp: new Date().toISOString()
  })
})

// Catch-all handler for React Router (SPA routing)
app.get('*', (req, res) => {
  res.sendFile(path.join(frontendPath, 'index.html'))
})

const port = process.env.PORT || 3000
app.listen(port, '0.0.0.0', () => {
  console.log(`🚀 Unified app running on port ${port}`)
})
```

#### 1.2 Unified Build Configuration
```json
// package.json (root level)
{
  "scripts": {
    "build:unified": "nx build frontend --prod && nx build backend --prod",
    "build:frontend:prod": "nx build frontend --configuration=production",
    "build:backend:prod": "nx build backend --configuration=production",
    "start:unified": "node dist/apps/backend/main.js"
  }
}
```

#### 1.3 Deploy Unified Application
```bash
# Create single Railway project
railway project create clinic-app-unified

# Set build and start commands
railway env set NIXPACKS_BUILD_CMD="npm run build:unified"
railway env set NIXPACKS_START_CMD="npm run start:unified"
railway env set NODE_ENV=production

# Deploy unified service
railway up

# Monitor deployment
railway logs --tail
```

---

## 🗄️ Database Setup

### PostgreSQL Database Configuration

#### 1.1 Add PostgreSQL to Railway Project
```bash
# Add PostgreSQL service
railway add postgresql

# Get database connection string
railway variables

# The DATABASE_URL will be automatically set
```

#### 1.2 Database Migration Setup
```typescript
// apps/backend/src/database/migrate.ts
import { Pool } from 'pg'

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false
})

export const runMigrations = async () => {
  const client = await pool.connect()
  
  try {
    // Create tables for clinic management
    await client.query(`
      CREATE TABLE IF NOT EXISTS patients (
        id SERIAL PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        phone VARCHAR(20),
        email VARCHAR(255),
        date_of_birth DATE,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `)
    
    await client.query(`
      CREATE TABLE IF NOT EXISTS appointments (
        id SERIAL PRIMARY KEY,
        patient_id INTEGER REFERENCES patients(id),
        appointment_date DATE NOT NULL,
        appointment_time TIME NOT NULL,
        status VARCHAR(50) DEFAULT 'scheduled',
        notes TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `)
    
    // Create indexes for performance
    await client.query(`
      CREATE INDEX IF NOT EXISTS idx_patients_name ON patients(name);
      CREATE INDEX IF NOT EXISTS idx_patients_phone ON patients(phone);
      CREATE INDEX IF NOT EXISTS idx_appointments_date ON appointments(appointment_date);
    `)
    
    console.log('✅ Database migrations completed successfully')
  } catch (error) {
    console.error('❌ Migration failed:', error)
    throw error
  } finally {
    client.release()
  }
}
```

#### 1.3 Run Migrations on Deployment
```bash
# Set migration command in Railway
railway env set NIXPACKS_BUILD_CMD="npm run build:backend:prod && npm run migrate"

# Add migration script to package.json
{
  "scripts": {
    "migrate": "node dist/apps/backend/migrate.js"
  }
}
```

---

## 🔐 Environment Variables & Secrets

### Production Environment Setup

#### Frontend Environment Variables
```bash
# Set in Railway frontend project
railway env set VITE_API_URL=https://clinic-backend.railway.app
railway env set VITE_APP_NAME="Clinic Management System"
railway env set VITE_PWA_NAME="Clinic App"
railway env set VITE_ENVIRONMENT=production
```

#### Backend Environment Variables
```bash
# Set in Railway backend project
railway env set NODE_ENV=production
railway env set PORT=3000
railway env set FRONTEND_URL=https://clinic-frontend.railway.app

# Database (automatically set by Railway)
# DATABASE_URL=postgresql://user:pass@host:port/db

# JWT and security
railway env set JWT_SECRET=$(openssl rand -base64 32)
railway env set SESSION_SECRET=$(openssl rand -base64 32)
railway env set ENCRYPTION_KEY=$(openssl rand -base64 32)

# API keys and external services
railway env set SENDGRID_API_KEY=your_sendgrid_key
railway env set TWILIO_AUTH_TOKEN=your_twilio_token
```

### Secrets Management
```typescript
// apps/backend/src/config/secrets.ts
export const secrets = {
  jwtSecret: process.env.JWT_SECRET || 'dev-secret',
  sessionSecret: process.env.SESSION_SECRET || 'dev-session',
  encryptionKey: process.env.ENCRYPTION_KEY || 'dev-encryption',
  
  // External API keys
  sendgridKey: process.env.SENDGRID_API_KEY,
  twilioToken: process.env.TWILIO_AUTH_TOKEN,
  
  // Database
  databaseUrl: process.env.DATABASE_URL || 'postgresql://localhost:5432/clinic_dev'
}

// Validate required secrets in production
if (process.env.NODE_ENV === 'production') {
  const requiredSecrets = ['JWT_SECRET', 'SESSION_SECRET', 'DATABASE_URL']
  
  for (const secret of requiredSecrets) {
    if (!process.env[secret]) {
      console.error(`❌ Missing required secret: ${secret}`)
      process.exit(1)
    }
  }
}
```

---

## 🚀 CI/CD with GitHub Actions

### Complete GitHub Actions Workflow

#### Separate Deployment Workflow
```yaml
# .github/workflows/railway-deployment.yml
name: Deploy to Railway

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

env:
  NODE_VERSION: '18'

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        
      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: 'npm'
          
      - name: Install dependencies
        run: npm ci
        
      - name: Run linting
        run: npm run lint
        
      - name: Run tests
        run: npm run test:ci
        
      - name: Build applications
        run: |
          npm run build:frontend:prod
          npm run build:backend:prod

  deploy-staging:
    if: github.event_name == 'pull_request'
    needs: test
    runs-on: ubuntu-latest
    environment: staging
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        
      - name: Deploy Frontend to Staging
        run: |
          npm install -g @railway/cli
          echo "${{ secrets.RAILWAY_TOKEN_STAGING }}" | railway login --stdin
          railway environment staging
          railway up --service frontend
        env:
          RAILWAY_TOKEN: ${{ secrets.RAILWAY_TOKEN_STAGING }}
          
      - name: Deploy Backend to Staging
        run: |
          railway environment staging
          railway up --service backend
        env:
          RAILWAY_TOKEN: ${{ secrets.RAILWAY_TOKEN_STAGING }}

  deploy-production:
    if: github.ref == 'refs/heads/main'
    needs: test
    runs-on: ubuntu-latest
    environment: production
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        
      - name: Deploy Frontend to Production
        run: |
          npm install -g @railway/cli
          echo "${{ secrets.RAILWAY_TOKEN_PRODUCTION }}" | railway login --stdin
          railway environment production
          railway up --service frontend
        env:
          RAILWAY_TOKEN: ${{ secrets.RAILWAY_TOKEN_PRODUCTION }}
          
      - name: Deploy Backend to Production
        run: |
          railway environment production
          railway up --service backend
        env:
          RAILWAY_TOKEN: ${{ secrets.RAILWAY_TOKEN_PRODUCTION }}
          
      - name: Health Check
        run: |
          sleep 30  # Wait for deployment
          curl -f https://clinic-backend.railway.app/health
          curl -f https://clinic-frontend.railway.app

  notify:
    if: always()
    needs: [deploy-production]
    runs-on: ubuntu-latest
    steps:
      - name: Notify Deployment Status
        run: |
          if [ "${{ needs.deploy-production.result }}" == "success" ]; then
            echo "✅ Deployment successful"
          else
            echo "❌ Deployment failed"
          fi
```

---

## 📊 Monitoring & Health Checks

### Application Monitoring Setup

#### 1.1 Health Check Endpoints
```typescript
// apps/backend/src/routes/health.ts
import { Router } from 'express'
import { Pool } from 'pg'

const router = Router()

// Basic health check
router.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    memory: process.memoryUsage(),
    version: process.env.npm_package_version
  })
})

// Detailed health check
router.get('/health/detailed', async (req, res) => {
  const health = {
    status: 'healthy',
    timestamp: new Date().toISOString(),
    checks: {
      database: await checkDatabase(),
      memory: checkMemory(),
      disk: await checkDisk()
    }
  }
  
  const allHealthy = Object.values(health.checks)
    .every(check => check.status === 'healthy')
  
  res.status(allHealthy ? 200 : 503).json(health)
})

async function checkDatabase() {
  try {
    const pool = new Pool({ connectionString: process.env.DATABASE_URL })
    await pool.query('SELECT 1')
    await pool.end()
    return { status: 'healthy', message: 'Database connection successful' }
  } catch (error) {
    return { status: 'unhealthy', error: error.message }
  }
}

function checkMemory() {
  const usage = process.memoryUsage()
  const maxMemory = 512 * 1024 * 1024 // 512MB limit for Railway
  
  return {
    status: usage.heapUsed < maxMemory * 0.9 ? 'healthy' : 'warning',
    heapUsed: Math.round(usage.heapUsed / 1024 / 1024),
    heapTotal: Math.round(usage.heapTotal / 1024 / 1024),
    external: Math.round(usage.external / 1024 / 1024)
  }
}

export default router
```

#### 1.2 Railway Monitoring Configuration
```bash
# Configure Railway health checks
railway env set RAILWAY_HEALTHCHECK_PATH=/health
railway env set RAILWAY_HEALTHCHECK_TIMEOUT=30
railway env set RAILWAY_RESTART_POLICY=on-failure
```

---

## 🔧 Troubleshooting Common Issues

### Deployment Issues

#### CORS Problems
```typescript
// Fix CORS issues with Railway deployments
app.use(cors({
  origin: [
    'http://localhost:4200',
    'https://clinic-frontend.railway.app',
    /^https:\/\/.*-clinic-frontend\.railway\.app$/  // Preview deployments
  ],
  credentials: true
}))
```

#### Build Failures
```bash
# Debug Railway build issues
railway logs --deployment <deployment-id>

# Check build command
railway env set NIXPACKS_BUILD_CMD="npm run build:frontend:prod"

# Verify Node.js version
railway env set NODE_VERSION=18
```

#### Memory Issues
```typescript
// Optimize Node.js memory usage
railway env set NODE_OPTIONS="--max-old-space-size=512"

// Monitor memory usage
const checkMemoryUsage = () => {
  const usage = process.memoryUsage()
  console.log({
    rss: Math.round(usage.rss / 1024 / 1024),
    heapTotal: Math.round(usage.heapTotal / 1024 / 1024),
    heapUsed: Math.round(usage.heapUsed / 1024 / 1024),
    external: Math.round(usage.external / 1024 / 1024)
  })
}

setInterval(checkMemoryUsage, 60000) // Log every minute
```

---

## 🔗 Navigation

← [Back: Performance Analysis](./performance-analysis.md) | [Next: Troubleshooting](./troubleshooting.md) →