# Best Practices: Railway Nx Deployment Strategies

## 🎯 Overview

This document outlines proven best practices for deploying Nx React/Express applications to Railway.com, with specific focus on clinic management PWA systems and production-ready configurations.

## 🏆 Strategy 2 (Single Deployment) Best Practices

### Project Structure Organization

```
clinic-management/
├── apps/
│   ├── client/                 # React PWA Frontend
│   │   ├── src/
│   │   ├── public/
│   │   │   ├── sw.js           # Service worker
│   │   │   ├── manifest.json   # PWA manifest
│   │   │   └── icons/          # PWA icons
│   │   └── vite.config.ts
│   └── api/                    # Express Backend
│       ├── src/
│       │   ├── main.ts         # Entry point
│       │   ├── routes/         # API routes
│       │   ├── middleware/     # Custom middleware
│       │   └── services/       # Business logic
│       └── project.json
├── libs/                       # Shared libraries
│   ├── shared-types/           # TypeScript interfaces
│   ├── validation/             # Zod schemas
│   └── utils/                  # Common utilities
├── railway.json                # Railway configuration
└── package.json
```

### Railway Configuration Best Practices

#### 1. Optimized railway.json

```json
{
  "$schema": "https://railway.app/railway.schema.json",
  "build": {
    "builder": "NIXPACKS",
    "buildCommand": "npm ci && npm run build:prod",
    "watchPatterns": [
      "apps/**/*",
      "libs/**/*",
      "package.json",
      "nx.json"
    ]
  },
  "deploy": {
    "startCommand": "npm run start:prod",
    "healthcheckPath": "/api/health",
    "healthcheckTimeout": 300,
    "restartPolicyType": "ON_FAILURE",
    "restartPolicyMaxRetries": 3,
    "cronJobs": [
      {
        "schedule": "0 2 * * *",
        "command": "npm run db:backup"
      }
    ]
  },
  "environments": {
    "production": {
      "variables": {
        "NODE_ENV": "production",
        "LOG_LEVEL": "info"
      }
    }
  }
}
```

#### 2. Environment Variables Management

```bash
# Production environment variables
railway variables set NODE_ENV=production
railway variables set PORT=3000
railway variables set LOG_LEVEL=info

# Database configuration
railway variables set DATABASE_URL=${{Postgres.DATABASE_URL}}
railway variables set REDIS_URL=${{Redis.REDIS_URL}}

# Security configuration
railway variables set JWT_SECRET=$(openssl rand -base64 32)
railway variables set ENCRYPTION_KEY=$(openssl rand -base64 32)

# PWA configuration
railway variables set APP_URL=https://clinic-app.railway.app
railway variables set VAPID_PUBLIC_KEY=your_vapid_public_key
railway variables set VAPID_PRIVATE_KEY=your_vapid_private_key

# External service configuration
railway variables set TWILIO_ACCOUNT_SID=your_twilio_sid
railway variables set TWILIO_AUTH_TOKEN=your_twilio_token
```

### Production-Ready Express Configuration

#### 1. Robust Main Application Setup

```typescript
// apps/api/src/main.ts
import express from 'express';
import helmet from 'helmet';
import compression from 'compression';
import rateLimit from 'express-rate-limit';
import cors from 'cors';
import path from 'path';
import { createProxyMiddleware } from 'http-proxy-middleware';

const app = express();
const port = process.env.PORT || 3000;
const isProduction = process.env.NODE_ENV === 'production';

// Security middleware
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'", "https://fonts.googleapis.com"],
      fontSrc: ["'self'", "https://fonts.gstatic.com"],
      scriptSrc: ["'self'"],
      imgSrc: ["'self'", "data:", "https:"],
      connectSrc: ["'self'", "wss:"]
    }
  },
  crossOriginEmbedderPolicy: false // Allow embedding for PWA
}));

// Rate limiting for API endpoints
const apiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // Limit each IP to 100 requests per windowMs
  message: 'Too many requests from this IP, please try again later',
  standardHeaders: true,
  legacyHeaders: false,
});

// Compression middleware
app.use(compression({
  level: 6,
  threshold: 1024,
  filter: (req, res) => {
    if (req.headers['x-no-compression']) return false;
    return compression.filter(req, res);
  }
}));

// CORS configuration
app.use(cors({
  origin: isProduction ? process.env.APP_URL : true,
  credentials: true
}));

// Request parsing
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Apply rate limiting to API routes
app.use('/api', apiLimiter);

// API routes
app.use('/api', routes);

// Static file serving with caching
const staticPath = path.join(__dirname, '../../../dist/apps/client');
app.use(express.static(staticPath, {
  maxAge: isProduction ? '1y' : '0',
  etag: true,
  lastModified: true,
  index: false, // Prevent directory listing
  setHeaders: (res, filePath) => {
    // Special handling for different file types
    if (filePath.endsWith('.html')) {
      res.setHeader('Cache-Control', 'no-cache, must-revalidate');
    } else if (filePath.includes('sw.js')) {
      res.setHeader('Cache-Control', 'no-cache');
    } else if (filePath.match(/\.(js|css|woff2?)$/)) {
      res.setHeader('Cache-Control', 'public, max-age=31536000, immutable');
    }
  }
}));

// SPA fallback - must be last
app.get('*', (req, res) => {
  // Don't serve SPA for API routes or files with extensions
  if (req.path.startsWith('/api') || path.extname(req.path)) {
    return res.status(404).json({ error: 'Not found' });
  }
  
  res.sendFile(path.join(staticPath, 'index.html'));
});

// Error handling middleware
app.use((err: Error, req: express.Request, res: express.Response, next: express.NextFunction) => {
  console.error('Error:', err);
  
  if (isProduction) {
    res.status(500).json({ error: 'Internal server error' });
  } else {
    res.status(500).json({ error: err.message, stack: err.stack });
  }
});

app.listen(port, () => {
  console.log(`🚀 Server running on port ${port}`);
  console.log(`📱 PWA available at: ${process.env.APP_URL || `http://localhost:${port}`}`);
});
```

#### 2. Health Check Implementation

```typescript
// apps/api/src/routes/health.ts
import express from 'express';
import { Pool } from 'pg';

const router = express.Router();
const db = new Pool({ connectionString: process.env.DATABASE_URL });

interface HealthStatus {
  status: 'healthy' | 'unhealthy';
  timestamp: string;
  uptime: number;
  environment: string;
  version: string;
  services: {
    database: 'connected' | 'disconnected';
    memory: {
      used: number;
      free: number;
      percentage: number;
    };
  };
}

router.get('/health', async (req, res) => {
  try {
    const memUsage = process.memoryUsage();
    const totalMem = memUsage.heapTotal;
    const usedMem = memUsage.heapUsed;
    const freeMem = totalMem - usedMem;
    const memPercentage = (usedMem / totalMem) * 100;

    // Test database connection
    let dbStatus: 'connected' | 'disconnected';
    try {
      await db.query('SELECT 1');
      dbStatus = 'connected';
    } catch (error) {
      dbStatus = 'disconnected';
    }

    const health: HealthStatus = {
      status: dbStatus === 'connected' && memPercentage < 90 ? 'healthy' : 'unhealthy',
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
      environment: process.env.NODE_ENV || 'development',
      version: process.env.npm_package_version || '1.0.0',
      services: {
        database: dbStatus,
        memory: {
          used: Math.round(usedMem / 1024 / 1024), // MB
          free: Math.round(freeMem / 1024 / 1024), // MB
          percentage: Math.round(memPercentage)
        }
      }
    };

    const statusCode = health.status === 'healthy' ? 200 : 503;
    res.status(statusCode).json(health);
  } catch (error) {
    res.status(503).json({
      status: 'unhealthy',
      timestamp: new Date().toISOString(),
      error: 'Health check failed'
    });
  }
});

export default router;
```

### PWA Configuration Best Practices

#### 1. Optimized Service Worker

```typescript
// apps/client/public/sw.js
const CACHE_NAME = 'clinic-pwa-v1.0.0';
const OFFLINE_URL = '/offline.html';

// Critical resources for offline functionality
const CRITICAL_RESOURCES = [
  '/',
  '/offline.html',
  '/static/js/main.js',
  '/static/css/main.css',
  '/api/patients/recent',
  '/api/appointments/today'
];

// Install event - cache critical resources
self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then(cache => cache.addAll(CRITICAL_RESOURCES))
      .then(() => self.skipWaiting())
  );
});

// Activate event - clean up old caches
self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys()
      .then(cacheNames => {
        return Promise.all(
          cacheNames
            .filter(cacheName => cacheName !== CACHE_NAME)
            .map(cacheName => caches.delete(cacheName))
        );
      })
      .then(() => self.clients.claim())
  );
});

// Fetch event - implement caching strategies
self.addEventListener('fetch', event => {
  if (event.request.mode === 'navigate') {
    // Network first for navigation requests
    event.respondWith(
      fetch(event.request)
        .catch(() => caches.match(OFFLINE_URL))
    );
  } else if (event.request.url.includes('/api/')) {
    // Network first with cache fallback for API requests
    event.respondWith(
      fetch(event.request)
        .then(response => {
          if (response.ok) {
            const responseClone = response.clone();
            caches.open(CACHE_NAME)
              .then(cache => cache.put(event.request, responseClone));
          }
          return response;
        })
        .catch(() => caches.match(event.request))
    );
  } else {
    // Cache first for static assets
    event.respondWith(
      caches.match(event.request)
        .then(response => response || fetch(event.request))
    );
  }
});

// Background sync for offline actions
self.addEventListener('sync', event => {
  if (event.tag === 'background-sync') {
    event.waitUntil(syncOfflineActions());
  }
});

async function syncOfflineActions() {
  // Implement offline action synchronization
  const cache = await caches.open(CACHE_NAME);
  const offlineActions = await cache.match('/offline-actions');
  
  if (offlineActions) {
    const actions = await offlineActions.json();
    // Process offline actions when connection is restored
    for (const action of actions) {
      try {
        await fetch(`/api/${action.endpoint}`, {
          method: action.method,
          body: JSON.stringify(action.data),
          headers: { 'Content-Type': 'application/json' }
        });
      } catch (error) {
        console.error('Failed to sync action:', action, error);
      }
    }
    
    // Clear processed actions
    await cache.delete('/offline-actions');
  }
}
```

#### 2. PWA Manifest Configuration

```json
{
  "name": "Clinic Management System",
  "short_name": "ClinicCMS",
  "description": "Professional clinic management and patient records system",
  "start_url": "/",
  "scope": "/",
  "display": "standalone",
  "orientation": "portrait-primary",
  "theme_color": "#1976d2",
  "background_color": "#ffffff",
  "categories": ["health", "medical", "productivity"],
  "lang": "en-US",
  "icons": [
    {
      "src": "/icons/icon-72x72.png",
      "sizes": "72x72",
      "type": "image/png",
      "purpose": "maskable any"
    },
    {
      "src": "/icons/icon-96x96.png",
      "sizes": "96x96",
      "type": "image/png",
      "purpose": "maskable any"
    },
    {
      "src": "/icons/icon-128x128.png",
      "sizes": "128x128",
      "type": "image/png",
      "purpose": "maskable any"
    },
    {
      "src": "/icons/icon-144x144.png",
      "sizes": "144x144",
      "type": "image/png",
      "purpose": "maskable any"
    },
    {
      "src": "/icons/icon-152x152.png",
      "sizes": "152x152",
      "type": "image/png",
      "purpose": "maskable any"
    },
    {
      "src": "/icons/icon-192x192.png",
      "sizes": "192x192",
      "type": "image/png",
      "purpose": "maskable any"
    },
    {
      "src": "/icons/icon-384x384.png",
      "sizes": "384x384",
      "type": "image/png",
      "purpose": "maskable any"
    },
    {
      "src": "/icons/icon-512x512.png",
      "sizes": "512x512",
      "type": "image/png",
      "purpose": "maskable any"
    }
  ],
  "shortcuts": [
    {
      "name": "Patient Search",
      "short_name": "Patients",
      "description": "Search and manage patient records",
      "url": "/patients",
      "icons": [{ "src": "/icons/patients-96x96.png", "sizes": "96x96" }]
    },
    {
      "name": "Today's Appointments",
      "short_name": "Appointments",
      "description": "View today's appointment schedule",
      "url": "/appointments/today",
      "icons": [{ "src": "/icons/calendar-96x96.png", "sizes": "96x96" }]
    }
  ],
  "screenshots": [
    {
      "src": "/screenshots/dashboard-desktop.png",
      "sizes": "1280x720",
      "type": "image/png",
      "platform": "wide"
    },
    {
      "src": "/screenshots/dashboard-mobile.png",
      "sizes": "390x844",
      "type": "image/png",
      "platform": "narrow"
    }
  ]
}
```

### Database Configuration Best Practices

#### 1. Connection Pool Management

```typescript
// libs/database/src/connection.ts
import { Pool, PoolConfig } from 'pg';

const poolConfig: PoolConfig = {
  connectionString: process.env.DATABASE_URL,
  max: 20, // Maximum number of connections
  idleTimeoutMillis: 30000, // Close idle connections after 30 seconds
  connectionTimeoutMillis: 2000, // Return error after 2 seconds if no connection
  keepAlive: true,
  keepAliveInitialDelayMillis: 10000,
  ssl: process.env.NODE_ENV === 'production' ? {
    rejectUnauthorized: false
  } : false
};

export const db = new Pool(poolConfig);

// Graceful shutdown
process.on('SIGINT', async () => {
  console.log('🔌 Closing database connections...');
  await db.end();
  process.exit(0);
});

// Connection monitoring
db.on('connect', () => {
  console.log('📊 Database connected');
});

db.on('error', (err) => {
  console.error('📊 Database connection error:', err);
});
```

#### 2. Migration and Backup Strategy

```typescript
// scripts/db-backup.ts
import { execSync } from 'child_process';
import path from 'path';

const backupDatabase = async () => {
  const timestamp = new Date().toISOString().split('T')[0];
  const backupFile = path.join(__dirname, '..', 'backups', `clinic-db-${timestamp}.sql`);
  
  try {
    execSync(`pg_dump ${process.env.DATABASE_URL} > ${backupFile}`, {
      stdio: 'inherit'
    });
    
    console.log(`✅ Database backup created: ${backupFile}`);
    
    // Upload to cloud storage if configured
    if (process.env.S3_BACKUP_BUCKET) {
      execSync(`aws s3 cp ${backupFile} s3://${process.env.S3_BACKUP_BUCKET}/backups/`);
      console.log('☁️ Backup uploaded to S3');
    }
  } catch (error) {
    console.error('❌ Backup failed:', error);
    process.exit(1);
  }
};

if (require.main === module) {
  backupDatabase();
}
```

### Monitoring and Logging Best Practices

#### 1. Structured Logging

```typescript
// libs/logger/src/logger.ts
import winston from 'winston';

const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  defaultMeta: { service: 'clinic-cms' },
  transports: [
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.colorize(),
        winston.format.simple()
      )
    })
  ]
});

// Add Railway log drains in production
if (process.env.NODE_ENV === 'production') {
  logger.add(new winston.transports.File({
    filename: 'error.log',
    level: 'error'
  }));
  
  logger.add(new winston.transports.File({
    filename: 'combined.log'
  }));
}

export { logger };
```

#### 2. Performance Monitoring

```typescript
// middleware/monitoring.ts
import { Request, Response, NextFunction } from 'express';
import { logger } from '../libs/logger';

export const performanceMiddleware = (req: Request, res: Response, next: NextFunction) => {
  const startTime = Date.now();
  
  res.on('finish', () => {
    const duration = Date.now() - startTime;
    
    logger.info('HTTP Request', {
      method: req.method,
      url: req.url,
      statusCode: res.statusCode,
      duration,
      userAgent: req.get('User-Agent'),
      ip: req.ip
    });
    
    // Alert on slow requests
    if (duration > 2000) {
      logger.warn('Slow request detected', {
        method: req.method,
        url: req.url,
        duration
      });
    }
  });
  
  next();
};
```

### Security Best Practices

#### 1. Authentication and Authorization

```typescript
// middleware/auth.ts
import jwt from 'jsonwebtoken';
import bcrypt from 'bcrypt';
import rateLimit from 'express-rate-limit';

// Login rate limiting
export const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 5, // Limit each IP to 5 login requests per windowMs
  message: 'Too many login attempts, please try again later',
  standardHeaders: true,
  legacyHeaders: false,
});

// JWT token validation
export const authenticateToken = (req: Request, res: Response, next: NextFunction) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ error: 'Access token required' });
  }

  jwt.verify(token, process.env.JWT_SECRET!, (err, user) => {
    if (err) {
      return res.status(403).json({ error: 'Invalid or expired token' });
    }
    
    req.user = user;
    next();
  });
};

// Role-based authorization
export const requireRole = (roles: string[]) => {
  return (req: Request, res: Response, next: NextFunction) => {
    if (!req.user || !roles.includes(req.user.role)) {
      return res.status(403).json({ error: 'Insufficient permissions' });
    }
    next();
  };
};
```

### Deployment Automation Best Practices

#### 1. GitHub Actions CI/CD

```yaml
# .github/workflows/deploy.yml
name: Deploy to Railway

on:
  push:
    branches: [main]
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
      - run: npm run lint
      - run: npm run test
      - run: npm run build

  deploy:
    needs: test
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
        with:
          node-version: 18
          cache: 'npm'
      
      - name: Install Railway CLI
        run: npm install -g @railway/cli
      
      - name: Deploy to Railway
        run: railway up --service clinic-cms
        env:
          RAILWAY_TOKEN: ${{ secrets.RAILWAY_TOKEN }}
```

## 🚨 Common Pitfalls to Avoid

### 1. Static File Serving Issues
- **Problem**: React app shows 404 errors on refresh
- **Solution**: Ensure SPA fallback is configured correctly
- **Fix**: Place SPA fallback route after static file middleware

### 2. Build Path Misalignment
- **Problem**: Express can't find built React files
- **Solution**: Verify build output paths match static serving paths
- **Fix**: Use absolute paths and check directory structure

### 3. CORS Configuration
- **Problem**: API calls fail from deployed frontend
- **Solution**: Configure CORS properly for production domain
- **Fix**: Set specific origins instead of wildcard in production

### 4. Environment Variable Management
- **Problem**: Missing environment variables cause runtime failures
- **Solution**: Use Railway's built-in variable management
- **Fix**: Document all required variables and set defaults

### 5. Database Connection Issues
- **Problem**: Connection pool exhaustion under load
- **Solution**: Configure appropriate pool limits
- **Fix**: Monitor connection usage and implement graceful degradation

---

## 🔗 Navigation

**← Previous:** [Implementation Guide](./implementation-guide.md) | **Next:** [Deployment Guide](./deployment-guide.md) →

**Related Sections:**
- [Template Examples](./template-examples.md) - Complete configuration files
- [Troubleshooting](./troubleshooting.md) - Common deployment issues