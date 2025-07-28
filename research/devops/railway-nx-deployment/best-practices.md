# Best Practices: Railway.com Deployment for Nx Applications

## 🎯 Overview

This guide outlines proven patterns and best practices for deploying Nx React/Express applications on Railway.com, with specific focus on clinic management systems and PWA optimization.

## 🏗️ Architecture Best Practices

### Separate Deployment Architecture (Recommended)

```mermaid
graph TB
    A[Client Browser] --> B[Railway Static Site - React PWA]
    A --> C[Railway Web Service - Express API]
    B --> D[CDN Edge Locations]
    C --> E[PostgreSQL Database]
    C --> F[Redis Cache]
    
    subgraph "Railway Platform"
        B
        C
        E
        F
    end
```

#### Key Principles
1. **Separation of Concerns** - Frontend and backend serve distinct purposes
2. **Independent Scaling** - Scale frontend and backend based on usage patterns
3. **Optimized Caching** - Leverage CDN for static assets, API for dynamic content
4. **Security Isolation** - Reduce attack surface through service separation

---

## 🚀 Performance Optimization

### Frontend Performance (React + Vite)

#### 1. Build Optimization
```typescript
// apps/frontend/vite.config.ts
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import { VitePWA } from 'vite-plugin-pwa'

export default defineConfig({
  plugins: [react(), VitePWA(pwaConfig)],
  build: {
    target: 'es2020',
    outDir: 'dist',
    sourcemap: process.env.NODE_ENV === 'development',
    minify: 'esbuild',
    rollupOptions: {
      output: {
        manualChunks: {
          vendor: ['react', 'react-dom'],
          ui: ['@mui/material', '@mui/icons-material'],
          utils: ['axios', 'date-fns']
        }
      }
    }
  },
  optimizeDeps: {
    include: ['react', 'react-dom', 'axios']
  }
})
```

#### 2. Code Splitting Strategy
```typescript
// Lazy load clinic modules
const PatientManagement = React.lazy(() => import('./modules/PatientManagement'))
const AppointmentScheduler = React.lazy(() => import('./modules/AppointmentScheduler'))
const Billing = React.lazy(() => import('./modules/Billing'))

// Route-based code splitting
const AppRoutes = () => (
  <Suspense fallback={<LoadingSpinner />}>
    <Routes>
      <Route path="/patients" element={<PatientManagement />} />
      <Route path="/appointments" element={<AppointmentScheduler />} />
      <Route path="/billing" element={<Billing />} />
    </Routes>
  </Suspense>
)
```

#### 3. PWA Caching Strategy
```typescript
// Optimized caching for clinic environment
const pwaConfig = {
  registerType: 'autoUpdate',
  workbox: {
    runtimeCaching: [
      // Critical app shell - cache first
      {
        urlPattern: ({ request }) => 
          request.destination === 'document' || 
          request.url.includes('/assets/'),
        handler: 'CacheFirst',
        options: {
          cacheName: 'app-shell',
          expiration: {
            maxEntries: 100,
            maxAgeSeconds: 60 * 60 * 24 * 30 // 30 days
          }
        }
      },
      // API calls - network first with fallback
      {
        urlPattern: /^https:\/\/.*\.railway\.app\/api\/.*/,
        handler: 'NetworkFirst',
        options: {
          cacheName: 'api-cache',
          networkTimeoutSeconds: 3,
          expiration: {
            maxEntries: 50,
            maxAgeSeconds: 60 * 60 * 24 // 1 day
          }
        }
      },
      // Patient images and documents - cache first
      {
        urlPattern: /\.(png|jpg|jpeg|pdf)$/,
        handler: 'CacheFirst',
        options: {
          cacheName: 'patient-files',
          expiration: {
            maxEntries: 200,
            maxAgeSeconds: 60 * 60 * 24 * 7 // 1 week
          }
        }
      }
    ]
  }
}
```

### Backend Performance (Express.js)

#### 1. Optimized Express Configuration
```typescript
// apps/backend/src/main.ts
import express from 'express'
import compression from 'compression'
import helmet from 'helmet'
import rateLimit from 'express-rate-limit'

const app = express()

// Security middleware
app.use(helmet())

// Compression for API responses
app.use(compression({
  level: 6,
  threshold: 1000,
  filter: (req, res) => {
    if (req.headers['x-no-compression']) return false
    return compression.filter(req, res)
  }
}))

// Rate limiting for clinic API
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 1000, // Generous limit for clinic staff
  message: 'Too many requests from this IP'
})
app.use('/api', limiter)

// Request logging for clinic compliance
app.use((req, res, next) => {
  console.log(`${new Date().toISOString()} - ${req.method} ${req.path}`)
  next()
})
```

#### 2. Database Optimization
```typescript
// Optimized database queries for clinic data
import { Pool } from 'pg'

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
})

// Efficient patient search with pagination
export const searchPatients = async (query: string, page = 1, limit = 20) => {
  const offset = (page - 1) * limit
  
  const result = await pool.query(`
    SELECT p.id, p.name, p.phone, p.last_visit
    FROM patients p
    WHERE p.name ILIKE $1 OR p.phone ILIKE $1
    ORDER BY p.last_visit DESC NULLS LAST
    LIMIT $2 OFFSET $3
  `, [`%${query}%`, limit, offset])
  
  return result.rows
}

// Connection pooling for clinic workload
export const getConnection = () => pool.connect()
```

#### 3. Caching Strategy
```typescript
// Redis caching for frequent clinic queries
import Redis from 'ioredis'

const redis = new Redis(process.env.REDIS_URL)

// Cache appointment schedules
export const getCachedSchedule = async (date: string) => {
  const cacheKey = `schedule:${date}`
  const cached = await redis.get(cacheKey)
  
  if (cached) {
    return JSON.parse(cached)
  }
  
  const schedule = await getScheduleFromDB(date)
  await redis.setex(cacheKey, 3600, JSON.stringify(schedule)) // 1 hour cache
  
  return schedule
}
```

---

## 🔒 Security Best Practices

### Environment Variables Management
```bash
# Railway environment variables for clinic security
NODE_ENV=production
JWT_SECRET=your-256-bit-secret
DATABASE_URL=postgresql://user:pass@host:port/clinic_db
ENCRYPTION_KEY=your-encryption-key-for-patient-data
CORS_ORIGINS=https://clinic-app.railway.app
RATE_LIMIT_MAX=1000
SESSION_SECRET=your-session-secret
```

### CORS Configuration
```typescript
// Secure CORS setup for clinic environment
app.use(cors({
  origin: function (origin, callback) {
    const allowedOrigins = process.env.CORS_ORIGINS?.split(',') || []
    
    // Allow requests with no origin (mobile apps, etc.)
    if (!origin) return callback(null, true)
    
    if (allowedOrigins.includes(origin)) {
      callback(null, true)
    } else {
      callback(new Error('Not allowed by CORS'))
    }
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Clinic-ID']
}))
```

### Patient Data Protection
```typescript
// HIPAA-compliant data handling
import crypto from 'crypto'

const encryptPatientData = (data: string): string => {
  const cipher = crypto.createCipher('aes-256-cbc', process.env.ENCRYPTION_KEY)
  let encrypted = cipher.update(data, 'utf8', 'hex')
  encrypted += cipher.final('hex')
  return encrypted
}

const decryptPatientData = (encryptedData: string): string => {
  const decipher = crypto.createDecipher('aes-256-cbc', process.env.ENCRYPTION_KEY)
  let decrypted = decipher.update(encryptedData, 'hex', 'utf8')
  decrypted += decipher.final('utf8')
  return decrypted
}
```

---

## 📱 PWA Optimization for Clinic Environment

### Offline Functionality
```typescript
// Critical clinic features that work offline
const offlineCapableFeatures = {
  // View recent patients (cached data)
  viewRecentPatients: true,
  
  // Record basic patient notes
  recordPatientNotes: true,
  
  // View appointment schedule
  viewTodaySchedule: true,
  
  // Emergency contact information
  viewEmergencyContacts: true
}

// Service worker for offline data sync
self.addEventListener('sync', (event) => {
  if (event.tag === 'background-sync') {
    event.waitUntil(syncOfflineData())
  }
})

const syncOfflineData = async () => {
  try {
    const offlineData = await getOfflineData()
    await syncToServer(offlineData)
    await clearOfflineData()
  } catch (error) {
    console.error('Background sync failed:', error)
  }
}
```

### Mobile-First Design
```css
/* Optimized for clinic tablets and phones */
.clinic-interface {
  /* Touch-friendly minimum sizes */
  min-height: 44px;
  min-width: 44px;
  
  /* Easy-to-read fonts for medical staff */
  font-size: 16px;
  line-height: 1.5;
  
  /* High contrast for clinical environment */
  color: #1a1a1a;
  background: #ffffff;
}

/* Large touch targets for quick access */
.patient-card {
  padding: 16px;
  margin: 8px 0;
  border-radius: 8px;
  border: 1px solid #e5e5e5;
  cursor: pointer;
  transition: background-color 0.2s;
}

.patient-card:hover,
.patient-card:focus {
  background-color: #f8f9fa;
  border-color: #2563eb;
}

/* Responsive layout for different devices */
@media (max-width: 768px) {
  .clinic-layout {
    grid-template-columns: 1fr;
  }
  
  .navigation {
    position: fixed;
    bottom: 0;
    width: 100%;
  }
}
```

### Push Notifications for Appointments
```typescript
// Push notification setup for appointment reminders
const subscribeToNotifications = async () => {
  if ('serviceWorker' in navigator && 'PushManager' in window) {
    const registration = await navigator.serviceWorker.ready
    
    const subscription = await registration.pushManager.subscribe({
      userVisibleOnly: true,
      applicationServerKey: process.env.VAPID_PUBLIC_KEY
    })
    
    // Send subscription to backend
    await fetch('/api/notifications/subscribe', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(subscription)
    })
  }
}
```

---

## 🔄 CI/CD Best Practices

### GitHub Actions Workflow
```yaml
# .github/workflows/clinic-deployment.yml
name: Clinic App Deployment

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
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: 'npm'
          
      - name: Install dependencies
        run: npm ci
        
      - name: Run tests
        run: npm run test:ci
        
      - name: Run E2E tests
        run: npm run e2e:ci

  deploy-staging:
    if: github.event_name == 'pull_request'
    needs: test
    runs-on: ubuntu-latest
    environment: staging
    
    steps:
      - uses: actions/checkout@v4
      - name: Deploy to staging
        run: |
          # Deploy to Railway staging environment
          railway up --service frontend --environment staging
          railway up --service backend --environment staging

  deploy-production:
    if: github.ref == 'refs/heads/main'
    needs: test
    runs-on: ubuntu-latest
    environment: production
    
    steps:
      - uses: actions/checkout@v4
      - name: Deploy to production
        run: |
          # Deploy to Railway production
          railway up --service frontend --environment production
          railway up --service backend --environment production
          
      - name: Health check
        run: |
          curl -f https://clinic-backend.railway.app/health
          curl -f https://clinic-frontend.railway.app
```

### Database Migrations
```typescript
// Database migration strategy for clinic data
import { Pool } from 'pg'

const runMigrations = async () => {
  const pool = new Pool({ connectionString: process.env.DATABASE_URL })
  
  try {
    // Check current schema version
    const version = await getCurrentSchemaVersion(pool)
    
    // Run pending migrations
    const migrations = await getPendingMigrations(version)
    
    for (const migration of migrations) {
      console.log(`Running migration: ${migration.name}`)
      await pool.query(migration.sql)
      await updateSchemaVersion(pool, migration.version)
    }
    
    console.log('Migrations completed successfully')
  } catch (error) {
    console.error('Migration failed:', error)
    process.exit(1)
  } finally {
    await pool.end()
  }
}

// Run migrations before app start
if (process.env.NODE_ENV === 'production') {
  runMigrations().then(() => {
    // Start the application
    require('./main')
  })
}
```

---

## 📊 Monitoring & Analytics

### Application Monitoring
```typescript
// Basic monitoring for clinic application
import { createLogger, format, transports } from 'winston'

const logger = createLogger({
  level: 'info',
  format: format.combine(
    format.timestamp(),
    format.errors({ stack: true }),
    format.json()
  ),
  transports: [
    new transports.Console(),
    new transports.File({ filename: 'clinic-app.log' })
  ]
})

// Track clinic-specific metrics
export const trackPatientAction = (action: string, patientId: string) => {
  logger.info('Patient action', {
    action,
    patientId,
    timestamp: new Date().toISOString(),
    userAgent: req.get('User-Agent')
  })
}

// Performance monitoring
export const measurePerformance = (operation: string) => {
  const start = Date.now()
  
  return {
    end: () => {
      const duration = Date.now() - start
      logger.info('Performance metric', { operation, duration })
      
      // Alert if operations are too slow for clinic workflow
      if (duration > 3000) {
        logger.warn('Slow operation detected', { operation, duration })
      }
    }
  }
}
```

### Health Checks
```typescript
// Comprehensive health check for clinic systems
app.get('/health', async (req, res) => {
  const health = {
    status: 'ok',
    timestamp: new Date().toISOString(),
    checks: {
      database: await checkDatabase(),
      redis: await checkRedis(),
      externalApis: await checkExternalApis()
    }
  }
  
  const allHealthy = Object.values(health.checks).every(check => check.status === 'ok')
  
  res.status(allHealthy ? 200 : 500).json(health)
})

const checkDatabase = async () => {
  try {
    await pool.query('SELECT 1')
    return { status: 'ok', message: 'Database connection healthy' }
  } catch (error) {
    return { status: 'error', message: error.message }
  }
}
```

---

## 💰 Cost Optimization

### Railway Cost Management
```bash
# Monitor Railway usage
railway metrics

# Optimize resource allocation
railway env set RAILWAY_VOLUME_MOUNT_PATH=/data
railway env set NODE_OPTIONS="--max-old-space-size=512"

# Use Railway's free tier efficiently
# - Static sites: Up to 3 free sites
# - Web services: $5/month per service
# - Databases: $5/month for small instances
```

### Efficient Resource Usage
```typescript
// Optimize memory usage for clinic app
process.on('warning', (warning) => {
  if (warning.name === 'MaxListenersExceededWarning') {
    console.log('Memory warning:', warning)
  }
})

// Cleanup resources
const gracefulShutdown = () => {
  console.log('Shutting down gracefully...')
  
  // Close database connections
  pool.end()
  
  // Close Redis connections
  redis.disconnect()
  
  process.exit(0)
}

process.on('SIGTERM', gracefulShutdown)
process.on('SIGINT', gracefulShutdown)
```

---

## 🔗 Navigation

← [Back: Implementation Guide](./implementation-guide.md) | [Next: Performance Analysis](./performance-analysis.md) →