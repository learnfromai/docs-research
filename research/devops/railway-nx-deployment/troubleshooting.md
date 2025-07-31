# Troubleshooting: Railway.com Deployment for Nx Applications

## 🚨 Common Issues & Solutions

This guide covers the most frequent problems encountered when deploying Nx React/Express applications to Railway.com and their proven solutions.

## 🏗️ Build & Deployment Issues

### Issue 1: Build Command Not Found

#### Problem
```bash
Error: npm run build:frontend:prod not found
Exit code: 1
```

#### Solution
```json
// package.json - Add missing build scripts
{
  "scripts": {
    "build:frontend": "nx build frontend",
    "build:frontend:prod": "nx build frontend --configuration=production",
    "build:backend": "nx build backend", 
    "build:backend:prod": "nx build backend --configuration=production",
    "build:unified": "npm run build:frontend:prod && npm run build:backend:prod"
  }
}
```

#### Railway Configuration
```bash
# Set correct build command in Railway
railway env set NIXPACKS_BUILD_CMD="npm run build:frontend:prod"

# For unified deployment
railway env set NIXPACKS_BUILD_CMD="npm run build:unified"
```

### Issue 2: Nx Command Not Found During Build

#### Problem
```bash
Error: nx: command not found
sh: 1: nx: not found
```

#### Solution
```json
// package.json - Ensure nx is in dependencies
{
  "dependencies": {
    "@nx/workspace": "^21.0.0"
  },
  "devDependencies": {
    "nx": "^21.0.0"
  }
}
```

#### Alternative Build Script
```json
// Use npx to run nx
{
  "scripts": {
    "build:frontend:prod": "npx nx build frontend --configuration=production",
    "build:backend:prod": "npx nx build backend --configuration=production"
  }
}
```

### Issue 3: Wrong Output Directory

#### Problem
```bash
Error: Static files not found at dist/apps/frontend
```

#### Solution
```json
// apps/frontend/project.json - Verify output path
{
  "targets": {
    "build": {
      "executor": "@nx/vite:build",
      "options": {
        "outputPath": "dist/apps/frontend"
      }
    }
  }
}
```

#### Railway Static Configuration
```json
// apps/frontend/railway.json
{
  "builder": "NIXPACKS",
  "buildCommand": "npm run build:frontend:prod",
  "staticPublishPath": "dist/apps/frontend"
}
```

---

## 🌐 CORS & Network Issues

### Issue 4: CORS Errors in Production

#### Problem
```javascript
Access to fetch at 'https://backend.railway.app/api/patients' 
from origin 'https://frontend.railway.app' has been blocked by CORS policy
```

#### Solution
```typescript
// apps/backend/src/main.ts - Comprehensive CORS setup
import cors from 'cors'

app.use(cors({
  origin: function (origin, callback) {
    const allowedOrigins = [
      'http://localhost:4200',                    // Development
      'https://clinic-frontend.railway.app',     // Production frontend
      /^https:\/\/.*-clinic-frontend\.railway\.app$/, // Preview deployments
      /^https:\/\/clinic-frontend-.*\.railway\.app$/  // Alternative naming
    ]
    
    // Allow requests with no origin (mobile apps, Postman, etc.)
    if (!origin) return callback(null, true)
    
    const isAllowed = allowedOrigins.some(allowed => 
      typeof allowed === 'string' 
        ? allowed === origin 
        : allowed.test(origin)
    )
    
    if (isAllowed) {
      callback(null, true)
    } else {
      console.log('CORS blocked origin:', origin)
      callback(new Error('Not allowed by CORS'))
    }
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
  allowedHeaders: [
    'Content-Type', 
    'Authorization', 
    'X-Requested-With',
    'X-Clinic-ID'
  ]
}))
```

#### Environment Variable Setup
```bash
# Set frontend URL in backend
railway env set FRONTEND_URL=https://clinic-frontend.railway.app

# Multiple origins support
railway env set CORS_ORIGINS="https://clinic-frontend.railway.app,http://localhost:4200"
```

### Issue 5: API Base URL Configuration

#### Problem
```javascript
// Frontend trying to call localhost in production
fetch('http://localhost:3000/api/patients')
```

#### Solution
```typescript
// apps/frontend/src/config/api.ts
const getApiBaseUrl = (): string => {
  // Check for Vite environment variable
  if (import.meta.env.VITE_API_URL) {
    return import.meta.env.VITE_API_URL
  }
  
  // Production fallback
  if (import.meta.env.PROD) {
    return 'https://clinic-backend.railway.app'
  }
  
  // Development fallback
  return 'http://localhost:3000'
}

export const API_BASE_URL = getApiBaseUrl()

// Usage in API calls
export const apiClient = axios.create({
  baseURL: API_BASE_URL,
  withCredentials: true,
  timeout: 10000
})
```

#### Environment Variable for Frontend
```bash
# Set in Railway frontend project
railway env set VITE_API_URL=https://clinic-backend.railway.app
```

---

## 🗄️ Database Connection Issues

### Issue 6: Database Connection Failed

#### Problem
```bash
Error: connect ECONNREFUSED 127.0.0.1:5432
```

#### Solution
```typescript
// apps/backend/src/database/connection.ts
import { Pool } from 'pg'

const createPool = () => {
  const config = {
    connectionString: process.env.DATABASE_URL,
    ssl: process.env.NODE_ENV === 'production' 
      ? { rejectUnauthorized: false } 
      : false,
    max: 20,
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 2000,
  }
  
  return new Pool(config)
}

export const pool = createPool()

// Test connection
export const testConnection = async () => {
  try {
    const client = await pool.connect()
    await client.query('SELECT NOW()')
    client.release()
    console.log('✅ Database connection successful')
    return true
  } catch (error) {
    console.error('❌ Database connection failed:', error.message)
    return false
  }
}
```

#### Railway Database Setup
```bash
# Add PostgreSQL to Railway project
railway add postgresql

# Check database URL is set
railway env

# Should show: DATABASE_URL=postgresql://username:password@host:port/database
```

### Issue 7: Migration Failures

#### Problem
```bash
Error: relation "patients" does not exist
```

#### Solution
```typescript
// apps/backend/src/database/migrate.ts
import { pool } from './connection'

export const runMigrations = async () => {
  const client = await pool.connect()
  
  try {
    // Create migrations table if it doesn't exist
    await client.query(`
      CREATE TABLE IF NOT EXISTS migrations (
        id SERIAL PRIMARY KEY,
        name VARCHAR(255) NOT NULL UNIQUE,
        executed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `)
    
    // Check which migrations have been run
    const { rows: executedMigrations } = await client.query(
      'SELECT name FROM migrations'
    )
    const executedNames = executedMigrations.map(row => row.name)
    
    // Define all migrations
    const migrations = [
      {
        name: '001_create_patients_table',
        sql: `
          CREATE TABLE IF NOT EXISTS patients (
            id SERIAL PRIMARY KEY,
            name VARCHAR(255) NOT NULL,
            phone VARCHAR(20),
            email VARCHAR(255),
            date_of_birth DATE,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
          )
        `
      },
      {
        name: '002_create_appointments_table',
        sql: `
          CREATE TABLE IF NOT EXISTS appointments (
            id SERIAL PRIMARY KEY,
            patient_id INTEGER REFERENCES patients(id),
            appointment_date DATE NOT NULL,
            appointment_time TIME NOT NULL,
            status VARCHAR(50) DEFAULT 'scheduled',
            notes TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
          )
        `
      },
      {
        name: '003_create_indexes',
        sql: `
          CREATE INDEX IF NOT EXISTS idx_patients_name ON patients(name);
          CREATE INDEX IF NOT EXISTS idx_patients_phone ON patients(phone);
          CREATE INDEX IF NOT EXISTS idx_appointments_date ON appointments(appointment_date);
        `
      }
    ]
    
    // Run pending migrations
    for (const migration of migrations) {
      if (!executedNames.includes(migration.name)) {
        console.log(`Running migration: ${migration.name}`)
        await client.query(migration.sql)
        await client.query(
          'INSERT INTO migrations (name) VALUES ($1)',
          [migration.name]
        )
      }
    }
    
    console.log('✅ All migrations completed successfully')
  } catch (error) {
    console.error('❌ Migration failed:', error)
    throw error
  } finally {
    client.release()
  }
}
```

#### Add Migration to Deployment
```json
// package.json - Run migrations after build
{
  "scripts": {
    "migrate": "node dist/apps/backend/migrate.js",
    "build:backend:prod": "nx build backend --configuration=production",
    "postbuild": "npm run migrate"
  }
}
```

---

## 🔐 Environment & Security Issues

### Issue 8: Missing Environment Variables

#### Problem
```bash
Error: JWT_SECRET is required in production
```

#### Solution
```typescript
// apps/backend/src/config/validate-env.ts
const requiredEnvVars = [
  'NODE_ENV',
  'DATABASE_URL',
  'JWT_SECRET',
  'FRONTEND_URL'
]

export const validateEnvironment = () => {
  const missing = requiredEnvVars.filter(envVar => !process.env[envVar])
  
  if (missing.length > 0) {
    console.error('❌ Missing required environment variables:')
    missing.forEach(envVar => console.error(`  - ${envVar}`))
    process.exit(1)
  }
  
  console.log('✅ All required environment variables are set')
}

// Call at app startup
if (process.env.NODE_ENV === 'production') {
  validateEnvironment()
}
```

#### Set Environment Variables in Railway
```bash
# Essential variables for backend
railway env set NODE_ENV=production
railway env set JWT_SECRET=$(openssl rand -base64 32)
railway env set SESSION_SECRET=$(openssl rand -base64 32)
railway env set FRONTEND_URL=https://clinic-frontend.railway.app

# Essential variables for frontend
railway env set VITE_API_URL=https://clinic-backend.railway.app
railway env set VITE_APP_NAME="Clinic Management System"
```

### Issue 9: HTTPS Mixed Content Warnings

#### Problem
```javascript
Mixed Content: The page at 'https://frontend.railway.app' was loaded over HTTPS, 
but requested an insecure resource 'http://backend.railway.app/api'
```

#### Solution
```typescript
// Ensure all API calls use HTTPS in production
const API_BASE_URL = import.meta.env.PROD 
  ? 'https://clinic-backend.railway.app'  // Always HTTPS in production
  : 'http://localhost:3000'               // HTTP for local development

// Force HTTPS in production
if (import.meta.env.PROD && API_BASE_URL.startsWith('http://')) {
  console.warn('Forcing HTTPS for production API calls')
  API_BASE_URL = API_BASE_URL.replace('http://', 'https://')
}
```

---

## 📱 PWA & Service Worker Issues

### Issue 10: Service Worker Not Registering

#### Problem
```javascript
Error: Failed to register service worker: TypeError: Failed to fetch
```

#### Solution
```typescript
// apps/frontend/src/main.tsx - Proper SW registration
import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './app/App'

// Register service worker only in production
if ('serviceWorker' in navigator && import.meta.env.PROD) {
  window.addEventListener('load', async () => {
    try {
      const registration = await navigator.serviceWorker.register('/sw.js', {
        scope: '/'
      })
      
      console.log('✅ Service Worker registered successfully:', registration.scope)
      
      // Listen for updates
      registration.addEventListener('updatefound', () => {
        const newWorker = registration.installing
        newWorker?.addEventListener('statechange', () => {
          if (newWorker.state === 'installed' && navigator.serviceWorker.controller) {
            // New content available
            console.log('🔄 New content available, refresh to update')
          }
        })
      })
    } catch (error) {
      console.error('❌ Service Worker registration failed:', error)
    }
  })
}

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
)
```

#### PWA Configuration Fix
```typescript
// apps/frontend/vite.config.ts - Fix service worker issues
import { VitePWA } from 'vite-plugin-pwa'

VitePWA({
  registerType: 'autoUpdate',
  workbox: {
    globPatterns: ['**/*.{js,css,html,ico,png,svg,woff2}'],
    // Fix caching issues
    runtimeCaching: [
      {
        urlPattern: ({ request }) => request.destination === 'document',
        handler: 'NetworkFirst',
        options: {
          cacheName: 'html-cache',
          expiration: {
            maxEntries: 10,
            maxAgeSeconds: 60 * 60 * 24 * 7 // 1 week
          }
        }
      }
    ],
    // Fix scope issues
    navigateFallback: '/index.html',
    navigateFallbackDenylist: [/^\/api\//]
  },
  // Ensure proper manifest
  manifest: {
    name: 'Clinic Management System',
    short_name: 'Clinic App',
    scope: '/',
    start_url: '/',
    display: 'standalone'
  }
})
```

---

## 🚀 Performance Issues

### Issue 11: Slow Loading in Production

#### Problem
```bash
Page load time: 8+ seconds
Large bundle sizes
```

#### Solution
```typescript
// apps/frontend/vite.config.ts - Optimize build
export default defineConfig({
  build: {
    rollupOptions: {
      output: {
        manualChunks: {
          vendor: ['react', 'react-dom'],
          ui: ['@mui/material'],
          utils: ['axios', 'date-fns']
        }
      }
    },
    minify: 'esbuild',
    target: 'es2020',
    sourcemap: false // Disable sourcemaps in production
  },
  // Enable compression
  plugins: [
    react(),
    // Add compression plugin if needed
  ]
})
```

#### Code Splitting
```typescript
// Implement route-based code splitting
import { lazy, Suspense } from 'react'

const PatientManagement = lazy(() => import('./modules/PatientManagement'))
const Appointments = lazy(() => import('./modules/Appointments'))

const App = () => (
  <Suspense fallback={<div>Loading...</div>}>
    <Routes>
      <Route path="/patients" element={<PatientManagement />} />
      <Route path="/appointments" element={<Appointments />} />
    </Routes>
  </Suspense>
)
```

### Issue 12: Memory Leaks in Production

#### Problem
```bash
Error: JavaScript heap out of memory
Process killed with signal SIGKILL
```

#### Solution
```typescript
// apps/backend/src/main.ts - Memory management
process.on('warning', (warning) => {
  console.warn('Warning:', warning.name, warning.message)
})

// Graceful shutdown
const gracefulShutdown = (signal: string) => {
  console.log(`Received ${signal}, shutting down gracefully...`)
  
  // Close database connections
  pool.end(() => {
    console.log('Database connections closed')
    process.exit(0)
  })
}

process.on('SIGTERM', () => gracefulShutdown('SIGTERM'))
process.on('SIGINT', () => gracefulShutdown('SIGINT'))

// Memory monitoring
setInterval(() => {
  const usage = process.memoryUsage()
  const memoryUsageMB = Math.round(usage.heapUsed / 1024 / 1024)
  
  if (memoryUsageMB > 400) { // Alert if using >400MB
    console.warn(`High memory usage: ${memoryUsageMB}MB`)
  }
}, 60000) // Check every minute
```

#### Railway Memory Configuration
```bash
# Set memory limits
railway env set NODE_OPTIONS="--max-old-space-size=512"
```

---

## 🔧 Development & Debugging

### Issue 13: Local Development CORS Issues

#### Problem
```javascript
CORS error when testing locally with Railway backend
```

#### Solution
```typescript
// apps/backend/src/main.ts - Development CORS
const isDevelopment = process.env.NODE_ENV === 'development'

app.use(cors({
  origin: isDevelopment 
    ? ['http://localhost:4200', 'http://127.0.0.1:4200']
    : [process.env.FRONTEND_URL],
  credentials: true
}))
```

#### Local Environment Setup
```bash
# apps/frontend/.env.local
VITE_API_URL=http://localhost:3000

# apps/backend/.env.local  
NODE_ENV=development
FRONTEND_URL=http://localhost:4200
DATABASE_URL=postgresql://localhost:5432/clinic_dev
```

### Issue 14: Debug Production Issues

#### Debugging Tools
```typescript
// apps/backend/src/middleware/debug.ts
export const debugMiddleware = (req, res, next) => {
  if (process.env.NODE_ENV === 'development') {
    console.log(`${req.method} ${req.path}`, {
      headers: req.headers,
      body: req.body,
      query: req.query
    })
  }
  next()
}

// Enhanced error handling
export const errorHandler = (error, req, res, next) => {
  console.error('Error details:', {
    message: error.message,
    stack: error.stack,
    url: req.url,
    method: req.method,
    headers: req.headers
  })
  
  res.status(500).json({
    error: process.env.NODE_ENV === 'production' 
      ? 'Internal server error' 
      : error.message,
    timestamp: new Date().toISOString()
  })
}
```

#### Railway Logging
```bash
# View live logs
railway logs --tail

# View specific deployment logs
railway logs --deployment <deployment-id>

# View logs for specific service
railway logs --service backend
```

---

## 📋 Quick Troubleshooting Checklist

### Before Deployment
- [ ] All build scripts are defined in package.json
- [ ] Environment variables are set in Railway
- [ ] CORS is configured for production URLs
- [ ] Database migrations are included
- [ ] Health check endpoints are implemented

### After Deployment Issues
- [ ] Check Railway deployment logs
- [ ] Verify environment variables are set
- [ ] Test API endpoints directly
- [ ] Check browser console for client-side errors
- [ ] Verify database connection
- [ ] Test CORS with different origins

### Performance Issues
- [ ] Check bundle sizes with `npm run build`
- [ ] Verify code splitting is working
- [ ] Monitor memory usage in Railway dashboard
- [ ] Test on different network conditions
- [ ] Verify PWA caching is active

---

## 🆘 Getting Help

### Railway Support Resources
```bash
# Railway CLI help
railway help

# Check service status
railway status

# View project info
railway info

# Connect to database
railway connect postgresql
```

### Community Resources
- [Railway Discord](https://discord.gg/railway)
- [Railway Documentation](https://docs.railway.app)
- [Railway GitHub Issues](https://github.com/railwayapp/railway/issues)

### Debugging Commands
```bash
# Test API endpoints
curl -I https://clinic-backend.railway.app/health

# Check PWA manifest
curl https://clinic-frontend.railway.app/manifest.json

# Test CORS
curl -H "Origin: https://clinic-frontend.railway.app" \
     -H "Access-Control-Request-Method: GET" \
     -X OPTIONS https://clinic-backend.railway.app/api/patients
```

---

## 🔗 Navigation

← [Back: Deployment Guide](./deployment-guide.md) | [Back to Overview](./README.md) →