# Implementation Guide: Railway.com Deployment for Nx React/Express Applications

## 🎯 Overview

This guide provides step-by-step instructions for implementing both deployment strategies on Railway.com, with primary focus on the **recommended Strategy B (Combined Deployment)** for clinic management systems.

---

## 🚀 Strategy B: Combined Deployment (Recommended)

### Prerequisites

#### Required Tools
```bash
# Install Railway CLI
npm install -g @railway/cli

# Verify installation
railway version

# Login to Railway
railway login
```

#### Project Structure Requirements
```
your-nx-clinic-app/
├── apps/
│   ├── client/          # React Vite frontend
│   └── api/             # Express.js backend
├── libs/               # Shared libraries
├── nx.json
├── package.json
└── railway.json        # Railway configuration
```

### Step 1: Nx Project Configuration

#### 1.1 Update Build Scripts
```json
// package.json
{
  "scripts": {
    "build": "nx build client --prod && nx build api --prod",
    "start": "node dist/apps/api/main.js",
    "dev": "concurrently \"nx build client --watch\" \"nx serve api\"",
    "test": "nx test client && nx test api"
  },
  "dependencies": {
    "compression": "^1.7.4",
    "helmet": "^7.1.0",
    "express-rate-limit": "^7.1.5"
  }
}
```

#### 1.2 Express Server Configuration
```typescript
// apps/api/src/main.ts
import express from 'express';
import compression from 'compression';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import path from 'path';
import { apiRouter } from './app/api.router';

const app = express();
const port = process.env.PORT || 3333;

// Security middleware
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'", "'unsafe-inline'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      imgSrc: ["'self'", "data:", "https:"],
      connectSrc: ["'self'"]
    }
  }
}));

// Enable gzip compression
app.use(compression({
  level: 6,
  threshold: 1024
}));

// Rate limiting for API routes
const apiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // limit each IP to 100 requests per windowMs
  message: { error: 'Too many requests, please try again later' }
});

// JSON parsing middleware
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// API routes
app.use('/api', apiLimiter, apiRouter);

// Static file serving with optimized caching
const staticPath = path.join(__dirname, '../client');
app.use(express.static(staticPath, {
  maxAge: '1d', // Cache for 1 day
  etag: true,
  lastModified: true,
  setHeaders: (res, filePath) => {
    // Cache JS and CSS files for 1 year
    if (filePath.endsWith('.js') || filePath.endsWith('.css')) {
      res.set('Cache-Control', 'public, max-age=31536000, immutable');
    }
    // Cache images for 30 days
    if (filePath.match(/\.(jpg|jpeg|png|gif|ico|svg|webp)$/)) {
      res.set('Cache-Control', 'public, max-age=2592000');
    }
    // Cache fonts for 1 year
    if (filePath.match(/\.(woff|woff2|ttf|eot)$/)) {
      res.set('Cache-Control', 'public, max-age=31536000');
    }
  }
}));

// PWA manifest route
app.get('/manifest.json', (req, res) => {
  res.json({
    name: 'Clinic Management System',
    short_name: 'ClinicMgmt',
    description: 'Professional clinic management solution',
    start_url: '/',
    display: 'standalone',
    background_color: '#ffffff',
    theme_color: '#2196f3',
    icons: [
      {
        src: '/assets/icons/icon-72x72.png',
        sizes: '72x72',
        type: 'image/png'
      },
      {
        src: '/assets/icons/icon-96x96.png',
        sizes: '96x96',
        type: 'image/png'
      },
      {
        src: '/assets/icons/icon-128x128.png',
        sizes: '128x128',
        type: 'image/png'
      },
      {
        src: '/assets/icons/icon-144x144.png',
        sizes: '144x144',
        type: 'image/png'
      },
      {
        src: '/assets/icons/icon-152x152.png',
        sizes: '152x152',
        type: 'image/png'
      },
      {
        src: '/assets/icons/icon-192x192.png',
        sizes: '192x192',
        type: 'image/png'
      },
      {
        src: '/assets/icons/icon-384x384.png',
        sizes: '384x384',
        type: 'image/png'
      },
      {
        src: '/assets/icons/icon-512x512.png',
        sizes: '512x512',
        type: 'image/png'
      }
    ]
  });
});

// Service worker route
app.get('/sw.js', (req, res) => {
  res.setHeader('Content-Type', 'application/javascript');
  res.setHeader('Cache-Control', 'no-cache');
  res.sendFile(path.join(staticPath, 'sw.js'));
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ 
    status: 'healthy', 
    timestamp: new Date().toISOString(),
    version: process.env.RAILWAY_GIT_COMMIT_SHA || 'development'
  });
});

// SPA fallback for client-side routing
app.get('*', (req, res) => {
  res.sendFile(path.join(staticPath, 'index.html'));
});

// Global error handler
app.use((err: Error, req: express.Request, res: express.Response, next: express.NextFunction) => {
  console.error('Unhandled error:', err);
  res.status(500).json({ 
    error: 'Internal server error',
    message: process.env.NODE_ENV === 'development' ? err.message : 'Something went wrong'
  });
});

const server = app.listen(port, () => {
  console.log(`🚀 Clinic Management System running on port ${port}`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully');
  server.close(() => {
    console.log('Process terminated');
  });
});

export default app;
```

### Step 2: Railway Configuration

#### 2.1 Create Railway Configuration
```json
// railway.json
{
  "version": 2,
  "build": {
    "command": "npm run build"
  },
  "deploy": {
    "startCommand": "npm start"
  }
}
```

#### 2.2 Environment Variables Setup
```bash
# Create .env file for local development
# .env
NODE_ENV=development
PORT=3333
DATABASE_URL=postgresql://user:password@localhost:5432/clinic_db
JWT_SECRET=your-super-secret-jwt-key
CORS_ORIGINS=http://localhost:3000

# Production environment variables (set in Railway dashboard)
NODE_ENV=production
DATABASE_URL=${{DATABASE_URL}}
JWT_SECRET=${{JWT_SECRET}}
CORS_ORIGINS=${{RAILWAY_PUBLIC_DOMAIN}}
```

### Step 3: PWA Implementation

#### 3.1 Service Worker Configuration
```typescript
// apps/client/public/sw.js
const CACHE_NAME = 'clinic-mgmt-v1';
const API_CACHE_NAME = 'clinic-api-v1';

// Static assets to cache
const STATIC_ASSETS = [
  '/',
  '/index.html',
  '/manifest.json',
  '/assets/icons/icon-192x192.png',
  '/assets/icons/icon-512x512.png'
];

// API endpoints to cache
const CACHEABLE_API_ROUTES = [
  '/api/settings',
  '/api/staff',
  '/api/services'
];

// Install event - cache static assets
self.addEventListener('install', (event) => {
  console.log('Service Worker installing...');
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then((cache) => {
        console.log('Caching static assets');
        return cache.addAll(STATIC_ASSETS);
      })
      .then(() => self.skipWaiting())
  );
});

// Activate event - clean up old caches
self.addEventListener('activate', (event) => {
  console.log('Service Worker activating...');
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames.map((cacheName) => {
          if (cacheName !== CACHE_NAME && cacheName !== API_CACHE_NAME) {
            console.log('Deleting old cache:', cacheName);
            return caches.delete(cacheName);
          }
        })
      );
    }).then(() => self.clients.claim())
  );
});

// Fetch event - handle requests
self.addEventListener('fetch', (event) => {
  const { request } = event;
  const url = new URL(request.url);

  // Handle API requests
  if (url.pathname.startsWith('/api/')) {
    // Cache static API data
    if (CACHEABLE_API_ROUTES.some(route => url.pathname.startsWith(route))) {
      event.respondWith(
        caches.open(API_CACHE_NAME).then((cache) => {
          return cache.match(request).then((cachedResponse) => {
            if (cachedResponse) {
              // Return cached response and update in background
              fetch(request).then((fetchResponse) => {
                cache.put(request, fetchResponse.clone());
              }).catch(() => {}); // Ignore background update errors
              return cachedResponse;
            } else {
              // Fetch and cache
              return fetch(request).then((fetchResponse) => {
                if (fetchResponse.ok) {
                  cache.put(request, fetchResponse.clone());
                }
                return fetchResponse;
              }).catch(() => {
                // Return offline message for API calls
                return new Response(
                  JSON.stringify({ error: 'Offline - data not available' }),
                  { 
                    status: 503,
                    headers: { 'Content-Type': 'application/json' }
                  }
                );
              });
            }
          });
        })
      );
    } else {
      // Network-first for dynamic API calls
      event.respondWith(
        fetch(request).catch(() => {
          return caches.match(request).then((cachedResponse) => {
            return cachedResponse || new Response(
              JSON.stringify({ error: 'Offline - please try again later' }),
              {
                status: 503,
                headers: { 'Content-Type': 'application/json' }
              }
            );
          });
        })
      );
    }
  } else {
    // Cache-first for static assets
    event.respondWith(
      caches.match(request).then((cachedResponse) => {
        if (cachedResponse) {
          return cachedResponse;
        }
        return fetch(request).then((fetchResponse) => {
          // Cache successful responses for static assets
          if (fetchResponse.ok && request.method === 'GET') {
            const responseClone = fetchResponse.clone();
            caches.open(CACHE_NAME).then((cache) => {
              cache.put(request, responseClone);
            });
          }
          return fetchResponse;
        }).catch(() => {
          // Return offline page for navigation requests
          if (request.mode === 'navigate') {
            return caches.match('/index.html');
          }
          throw error;
        });
      })
    );
  }
});

// Background sync for data synchronization
self.addEventListener('sync', (event) => {
  if (event.tag === 'background-sync') {
    event.waitUntil(doBackgroundSync());
  }
});

// Background sync implementation
async function doBackgroundSync() {
  try {
    // Sync pending data when online
    const pendingData = await getStoredPendingData();
    for (const data of pendingData) {
      await fetch('/api/sync', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data)
      });
    }
    await clearStoredPendingData();
  } catch (error) {
    console.error('Background sync failed:', error);
  }
}
```

#### 3.2 Client-Side PWA Registration
```typescript
// apps/client/src/main.tsx
import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './app/App';

// Register service worker
if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('/sw.js')
      .then((registration) => {
        console.log('SW registered: ', registration);
        
        // Check for updates
        registration.addEventListener('updatefound', () => {
          const newWorker = registration.installing;
          if (newWorker) {
            newWorker.addEventListener('statechange', () => {
              if (newWorker.state === 'installed' && navigator.serviceWorker.controller) {
                // New content available, show update prompt
                if (confirm('New version available! Click OK to update.')) {
                  window.location.reload();
                }
              }
            });
          }
        });
      })
      .catch((registrationError) => {
        console.log('SW registration failed: ', registrationError);
      });
  });
}

const root = ReactDOM.createRoot(document.getElementById('root') as HTMLElement);
root.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
```

### Step 4: Railway Deployment

#### 4.1 Initialize Railway Project
```bash
# Navigate to your project directory
cd your-nx-clinic-app

# Initialize Railway project
railway init

# Create new project or link existing
railway login
```

#### 4.2 Set Environment Variables
```bash
# Set production environment variables
railway variables set NODE_ENV=production
railway variables set JWT_SECRET="your-production-jwt-secret"

# Add database (PostgreSQL recommended for clinic data)
railway add postgresql

# The DATABASE_URL will be automatically set
```

#### 4.3 Deploy to Railway
```bash
# Deploy the application
railway up

# Check deployment status
railway status

# View logs
railway logs
```

#### 4.4 Custom Domain Setup (Optional)
```bash
# Add custom domain
railway domain add clinic.yourdomain.com

# Configure DNS records as instructed by Railway
```

### Step 5: Production Optimizations

#### 5.1 Database Configuration
```typescript
// apps/api/src/app/database.ts
import { Pool } from 'pg';

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false,
  max: 10, // Maximum number of connections
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});

// Health check query
export const checkDatabaseHealth = async () => {
  try {
    const client = await pool.connect();
    await client.query('SELECT 1');
    client.release();
    return true;
  } catch (error) {
    console.error('Database health check failed:', error);
    return false;
  }
};

export default pool;
```

#### 5.2 Monitoring and Logging
```typescript
// apps/api/src/app/middleware/monitoring.ts
import { Request, Response, NextFunction } from 'express';

// Request logging middleware
export const requestLogger = (req: Request, res: Response, next: NextFunction) => {
  const start = Date.now();
  
  res.on('finish', () => {
    const duration = Date.now() - start;
    console.log({
      method: req.method,
      url: req.url,
      status: res.statusCode,
      duration: `${duration}ms`,
      userAgent: req.get('User-Agent'),
      ip: req.ip
    });
  });
  
  next();
};

// Error tracking middleware
export const errorTracker = (err: Error, req: Request, res: Response, next: NextFunction) => {
  console.error({
    error: err.message,
    stack: err.stack,
    url: req.url,
    method: req.method,
    body: req.body,
    timestamp: new Date().toISOString()
  });
  
  res.status(500).json({
    error: 'Internal server error',
    message: process.env.NODE_ENV === 'development' ? err.message : 'Something went wrong'
  });
};
```

### Step 6: Testing and Validation

#### 6.1 Local Testing
```bash
# Test build process
npm run build

# Test production server locally
npm start

# Run test suites
npm test

# Test PWA functionality
# Open browser to http://localhost:3333
# Check Application tab in DevTools
# Verify service worker registration
# Test offline functionality
```

#### 6.2 Production Health Checks
```bash
# Check deployment health
curl https://your-app.railway.app/health

# Test API endpoints
curl https://your-app.railway.app/api/health

# Verify PWA manifest
curl https://your-app.railway.app/manifest.json
```

---

## 🔧 Strategy A: Separate Deployment (Alternative)

### When to Use Strategy A
- User base > 10 concurrent users
- Heavy static asset requirements
- Independent scaling needs
- Advanced CDN requirements

### Quick Setup for Strategy A

#### Frontend Service Configuration
```json
// railway.json (Frontend Service)
{
  "version": 2,
  "build": {
    "command": "npx nx build client --prod"
  },
  "deploy": {
    "startCommand": "npx serve dist/apps/client -s -l 3000"
  }
}
```

#### Backend Service Configuration
```json
// railway.json (Backend Service)
{
  "version": 2,
  "build": {
    "command": "npx nx build api --prod"
  },
  "deploy": {
    "startCommand": "node dist/apps/api/main.js"
  }
}
```

#### CORS Configuration for Separate Deployment
```typescript
// apps/api/src/main.ts
import cors from 'cors';

const corsOptions = {
  origin: [
    process.env.FRONTEND_URL || 'https://your-frontend.railway.app',
    'http://localhost:3000' // for development
  ],
  credentials: true,
  optionsSuccessStatus: 200
};

app.use(cors(corsOptions));
```

---

## 🚀 Deployment Checklist

### Pre-Deployment
- [ ] Nx build scripts configured
- [ ] Express server optimized for static serving
- [ ] PWA assets (manifest.json, service worker) created
- [ ] Environment variables defined
- [ ] Database connection configured
- [ ] Security middleware implemented

### Railway Setup
- [ ] Railway CLI installed and authenticated
- [ ] Project initialized with `railway init`
- [ ] Environment variables set
- [ ] Database service added (if needed)
- [ ] Custom domain configured (optional)

### Post-Deployment
- [ ] Health check endpoint responding
- [ ] PWA manifest accessible
- [ ] Service worker registering correctly
- [ ] API endpoints functional
- [ ] Database connectivity verified
- [ ] Monitoring and logging operational

### Performance Validation
- [ ] Page load times < 1s
- [ ] API response times < 300ms
- [ ] PWA offline functionality working
- [ ] Cache headers properly set
- [ ] Compression enabled

---

## 🔧 Troubleshooting

### Common Issues

#### Build Failures
```bash
# Check build logs
railway logs --build

# Common fix: Update Node.js version
echo "engines: { node: '18.x' }" >> package.json
```

#### Static File Issues
```bash
# Verify static files are built correctly
ls -la dist/apps/client/

# Check Express static serving
console.log('Static path:', path.join(__dirname, '../client'));
```

#### PWA Registration Problems
```javascript
// Debug service worker registration
navigator.serviceWorker.register('/sw.js')
  .then(reg => console.log('SW registered:', reg))
  .catch(err => console.error('SW registration failed:', err));
```

#### Environment Variable Issues
```bash
# Check Railway environment variables
railway variables

# Set missing variables
railway variables set VARIABLE_NAME="value"
```

### Performance Issues
- Enable compression middleware
- Implement proper caching headers
- Optimize static asset serving
- Monitor resource usage in Railway dashboard

### Database Connection Issues
- Verify DATABASE_URL format
- Check SSL settings for production
- Implement connection pooling
- Add connection timeout handling

---

This implementation guide provides a complete setup for deploying Nx React/Express applications to Railway.com with optimized performance for clinic management systems.