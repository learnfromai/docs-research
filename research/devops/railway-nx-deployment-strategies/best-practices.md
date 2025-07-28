# Best Practices

## 🎯 Railway.com Deployment Best Practices

This guide provides industry-proven best practices for deploying Nx React/Express applications on Railway.com, with specific focus on clinic management systems and small-scale applications.

## 🏗️ Architecture Best Practices

### Single Deployment Recommended Practices

#### Express.js Server Configuration
```typescript
// apps/backend/src/main.ts - Production-ready configuration
import express from 'express';
import helmet from 'helmet';
import compression from 'compression';
import rateLimit from 'express-rate-limit';
import cors from 'cors';
import { fileURLToPath } from 'url';
import path from 'path';

const app = express();

// 1. Security First - Apply security middleware early
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      scriptSrc: ["'self'"],
      imgSrc: ["'self'", "data:", "https:"],
      connectSrc: ["'self'"],
      fontSrc: ["'self'"],
      objectSrc: ["'none'"],
      mediaSrc: ["'self'"],
      frameSrc: ["'none'"],
    },
  },
  crossOriginEmbedderPolicy: false, // Required for some medical device integrations
}));

// 2. Rate Limiting - Protect against abuse
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // Limit each IP to 100 requests per windowMs
  message: {
    error: 'Too many requests',
    retryAfter: '15 minutes'
  },
  standardHeaders: true,
  legacyHeaders: false,
  // Skip localhost for development
  skip: (req) => req.ip === '127.0.0.1' || req.ip === '::1'
});

app.use('/api', limiter);

// 3. Compression - Improve performance
app.use(compression({
  level: 6, // Balance between compression and CPU usage
  threshold: 1024, // Only compress responses larger than 1KB
  filter: (req, res) => {
    if (req.headers['x-no-compression']) return false;
    return compression.filter(req, res);
  }
}));

// 4. Body parsing with limits
app.use(express.json({ 
  limit: '10mb', // Accommodate medical images/documents
  verify: (req, res, buf) => {
    // Store raw body for webhook verification if needed
    (req as any).rawBody = buf;
  }
}));

app.use(express.urlencoded({ 
  extended: true, 
  limit: '10mb' 
}));

// 5. Health check endpoint (critical for Railway)
app.get('/health', (req, res) => {
  const healthData = {
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    memory: process.memoryUsage(),
    version: process.env.npm_package_version || '1.0.0',
    environment: process.env.NODE_ENV,
    // Database health check
    database: await checkDatabaseHealth()
  };
  
  res.status(200).json(healthData);
});

// 6. API routes with proper error handling
app.use('/api', apiRoutes);

// 7. Static file serving with optimal caching
const staticPath = path.join(__dirname, 'public');
app.use(express.static(staticPath, {
  maxAge: process.env.NODE_ENV === 'production' ? '1y' : '0',
  etag: true,
  immutable: true,
  setHeaders: (res, filePath, stat) => {
    // Cache strategy based on file type
    if (filePath.endsWith('.html')) {
      res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
    } else if (filePath.match(/\.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2)$/)) {
      res.setHeader('Cache-Control', 'public, max-age=31536000, immutable');
    } else {
      res.setHeader('Cache-Control', 'public, max-age=3600');
    }
  }
}));

// 8. SPA fallback for client-side routing
app.get('*', (req, res, next) => {
  // Skip API routes
  if (req.path.startsWith('/api/')) {
    return res.status(404).json({ 
      error: 'API endpoint not found',
      path: req.path,
      method: req.method
    });
  }
  
  res.sendFile(path.join(staticPath, 'index.html'), (err) => {
    if (err) {
      next(err);
    }
  });
});

// 9. Global error handling
app.use((err: Error, req: express.Request, res: express.Response, next: express.NextFunction) => {
  console.error('Application error:', {
    error: err.message,
    stack: process.env.NODE_ENV === 'development' ? err.stack : undefined,
    path: req.path,
    method: req.method,
    userAgent: req.get('User-Agent'),
    ip: req.ip,
    timestamp: new Date().toISOString()
  });
  
  if (req.path.startsWith('/api/')) {
    res.status(500).json({ 
      error: 'Internal server error',
      message: process.env.NODE_ENV === 'development' ? err.message : 'Something went wrong',
      requestId: req.headers['x-request-id'] || 'unknown'
    });
  } else {
    res.sendFile(path.join(staticPath, 'index.html'));
  }
});

export default app;
```

#### Database Connection Best Practices
```typescript
// apps/backend/src/database/connection.ts
import { Pool, PoolConfig } from 'pg';

const poolConfig: PoolConfig = {
  connectionString: process.env.DATABASE_URL,
  ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false,
  
  // Connection pool optimization for small applications
  min: 2,                    // Minimum connections
  max: 10,                   // Maximum connections
  acquireTimeoutMillis: 60000,   // 60 seconds
  idleTimeoutMillis: 30000,      // 30 seconds
  
  // Performance and reliability settings
  keepAlive: true,
  keepAliveInitialDelayMillis: 10000,
  statement_timeout: 30000,      // 30 second query timeout
  query_timeout: 30000,
  connectionTimeoutMillis: 10000, // 10 second connection timeout
};

export const pool = new Pool(poolConfig);

// Health check function
export async function checkDatabaseHealth(): Promise<{ status: string; latency?: number; error?: string }> {
  const start = Date.now();
  
  try {
    const client = await pool.connect();
    await client.query('SELECT 1 as health_check');
    client.release();
    
    const latency = Date.now() - start;
    return { status: 'healthy', latency };
  } catch (error) {
    console.error('Database health check failed:', error);
    return { 
      status: 'unhealthy', 
      error: error instanceof Error ? error.message : 'Unknown error'
    };
  }
}

// Graceful shutdown
export async function closeDatabaseConnection(): Promise<void> {
  try {
    await pool.end();
    console.log('Database connection pool closed');
  } catch (error) {
    console.error('Error closing database pool:', error);
  }
}

// Handle process termination
process.on('SIGTERM', closeDatabaseConnection);
process.on('SIGINT', closeDatabaseConnection);
```

### Security Best Practices

#### Authentication and Authorization
```typescript
// apps/backend/src/middleware/auth.ts
import jwt from 'jsonwebtoken';
import bcrypt from 'bcrypt';
import { Request, Response, NextFunction } from 'express';

const JWT_SECRET = process.env.JWT_SECRET;
const JWT_EXPIRES_IN = '24h';
const SALT_ROUNDS = 12;

if (!JWT_SECRET) {
  throw new Error('JWT_SECRET environment variable is required');
}

export interface AuthenticatedRequest extends Request {
  user?: {
    id: string;
    email: string;
    role: string;
    clinicId: string;
  };
}

export async function hashPassword(password: string): Promise<string> {
  return bcrypt.hash(password, SALT_ROUNDS);
}

export async function comparePassword(password: string, hash: string): Promise<boolean> {
  return bcrypt.compare(password, hash);
}

export function generateToken(payload: object): string {
  return jwt.sign(payload, JWT_SECRET, { 
    expiresIn: JWT_EXPIRES_IN,
    issuer: 'clinic-management-system',
    audience: 'clinic-staff'
  });
}

export function authenticateToken(req: AuthenticatedRequest, res: Response, next: NextFunction) {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ 
      error: 'Access denied',
      message: 'Authentication token required'
    });
  }

  jwt.verify(token, JWT_SECRET, (err: any, decoded: any) => {
    if (err) {
      console.warn('Invalid token attempt:', {
        ip: req.ip,
        userAgent: req.get('User-Agent'),
        error: err.message
      });
      
      return res.status(403).json({ 
        error: 'Invalid token',
        message: 'Please log in again'
      });
    }

    req.user = decoded;
    next();
  });
}

// Role-based authorization
export function requireRole(roles: string[]) {
  return (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
    if (!req.user) {
      return res.status(401).json({ error: 'Authentication required' });
    }

    if (!roles.includes(req.user.role)) {
      return res.status(403).json({ 
        error: 'Insufficient permissions',
        required: roles,
        current: req.user.role
      });
    }

    next();
  };
}

// Clinic isolation middleware
export function requireSameClinic(req: AuthenticatedRequest, res: Response, next: NextFunction) {
  if (!req.user) {
    return res.status(401).json({ error: 'Authentication required' });
  }

  // Add clinic ID validation logic here
  // This ensures users can only access data from their clinic
  next();
}
```

#### Input Validation and Sanitization
```typescript
// apps/backend/src/middleware/validation.ts
import { body, param, query, validationResult } from 'express-validator';
import { Request, Response, NextFunction } from 'express';
import DOMPurify from 'isomorphic-dompurify';

// Handle validation errors
export function handleValidationErrors(req: Request, res: Response, next: NextFunction) {
  const errors = validationResult(req);
  
  if (!errors.isEmpty()) {
    return res.status(400).json({
      error: 'Validation failed',
      details: errors.array()
    });
  }
  
  next();
}

// Common validation rules
export const patientValidation = [
  body('firstName')
    .trim()
    .isLength({ min: 1, max: 50 })
    .withMessage('First name must be 1-50 characters')
    .customSanitizer(value => DOMPurify.sanitize(value)),
    
  body('lastName')
    .trim()
    .isLength({ min: 1, max: 50 })
    .withMessage('Last name must be 1-50 characters')
    .customSanitizer(value => DOMPurify.sanitize(value)),
    
  body('email')
    .isEmail()
    .normalizeEmail()
    .withMessage('Valid email required'),
    
  body('phone')
    .isMobilePhone('any')
    .withMessage('Valid phone number required'),
    
  body('dateOfBirth')
    .isISO8601()
    .toDate()
    .withMessage('Valid date of birth required'),
    
  handleValidationErrors
];

export const appointmentValidation = [
  body('patientId')
    .isUUID()
    .withMessage('Valid patient ID required'),
    
  body('datetime')
    .isISO8601()
    .toDate()
    .custom((value) => {
      if (new Date(value) <= new Date()) {
        throw new Error('Appointment must be in the future');
      }
      return true;
    }),
    
  body('duration')
    .isInt({ min: 15, max: 240 })
    .withMessage('Duration must be between 15 and 240 minutes'),
    
  body('notes')
    .optional()
    .isLength({ max: 1000 })
    .customSanitizer(value => DOMPurify.sanitize(value)),
    
  handleValidationErrors
];
```

### Performance Optimization Best Practices

#### Caching Strategy
```typescript
// apps/backend/src/middleware/cache.ts
import { Request, Response, NextFunction } from 'express';

interface CacheOptions {
  duration: number; // in seconds
  key?: (req: Request) => string;
  condition?: (req: Request) => boolean;
}

const cache = new Map<string, { data: any; expires: number }>();

export function cacheMiddleware(options: CacheOptions) {
  return (req: Request, res: Response, next: NextFunction) => {
    // Skip caching for non-GET requests
    if (req.method !== 'GET') {
      return next();
    }
    
    // Check condition if provided
    if (options.condition && !options.condition(req)) {
      return next();
    }
    
    // Generate cache key
    const key = options.key ? options.key(req) : req.originalUrl;
    const cached = cache.get(key);
    
    // Return cached data if valid
    if (cached && cached.expires > Date.now()) {
      res.setHeader('X-Cache', 'HIT');
      return res.json(cached.data);
    }
    
    // Override res.json to cache the response
    const originalJson = res.json;
    res.json = function(data) {
      // Cache successful responses
      if (res.statusCode < 400) {
        cache.set(key, {
          data,
          expires: Date.now() + (options.duration * 1000)
        });
      }
      
      res.setHeader('X-Cache', 'MISS');
      return originalJson.call(this, data);
    };
    
    next();
  };
}

// Cache for reference data (rarely changes)
export const referenceDataCache = cacheMiddleware({
  duration: 3600, // 1 hour
  key: (req) => `reference:${req.path}`,
  condition: (req) => req.path.startsWith('/api/reference/')
});

// Cache for user profile (changes infrequently)
export const userProfileCache = cacheMiddleware({
  duration: 300, // 5 minutes
  key: (req) => `profile:${req.user?.id}:${req.path}`,
  condition: (req) => req.path.includes('/profile')
});

// Clean expired cache entries periodically
setInterval(() => {
  const now = Date.now();
  for (const [key, value] of cache.entries()) {
    if (value.expires <= now) {
      cache.delete(key);
    }
  }
}, 5 * 60 * 1000); // Every 5 minutes
```

#### Database Query Optimization
```typescript
// apps/backend/src/services/patientService.ts
import { pool } from '../database/connection';

export class PatientService {
  // Optimized patient search with pagination
  static async searchPatients(
    clinicId: string, 
    searchTerm?: string, 
    page = 1, 
    limit = 20
  ) {
    const offset = (page - 1) * limit;
    
    let query = `
      SELECT 
        p.id,
        p.first_name,
        p.last_name,
        p.email,
        p.phone,
        p.date_of_birth,
        p.created_at,
        COUNT(*) OVER() as total_count
      FROM patients p
      WHERE p.clinic_id = $1
    `;
    
    const params: any[] = [clinicId];
    
    if (searchTerm) {
      query += ` AND (
        p.first_name ILIKE $2 
        OR p.last_name ILIKE $2 
        OR p.email ILIKE $2
        OR p.phone ILIKE $2
      )`;
      params.push(`%${searchTerm}%`);
    }
    
    query += ` ORDER BY p.last_name, p.first_name LIMIT $${params.length + 1} OFFSET $${params.length + 2}`;
    params.push(limit, offset);
    
    const result = await pool.query(query, params);
    
    return {
      patients: result.rows,
      total: result.rows[0]?.total_count || 0,
      page,
      totalPages: Math.ceil((result.rows[0]?.total_count || 0) / limit)
    };
  }
  
  // Optimized patient details with related data
  static async getPatientDetails(patientId: string, clinicId: string) {
    const query = `
      SELECT 
        p.*,
        COALESCE(
          JSON_AGG(
            JSON_BUILD_OBJECT(
              'id', a.id,
              'datetime', a.datetime,
              'status', a.status,
              'notes', a.notes
            ) ORDER BY a.datetime DESC
          ) FILTER (WHERE a.id IS NOT NULL),
          '[]'
        ) as recent_appointments
      FROM patients p
      LEFT JOIN appointments a ON p.id = a.patient_id 
        AND a.datetime >= NOW() - INTERVAL '6 months'
      WHERE p.id = $1 AND p.clinic_id = $2
      GROUP BY p.id
    `;
    
    const result = await pool.query(query, [patientId, clinicId]);
    return result.rows[0];
  }
}
```

### PWA Best Practices

#### Service Worker Optimization
```typescript
// apps/frontend/public/sw.js
const CACHE_NAME = 'clinic-app-v1.0.0';
const STATIC_CACHE = 'static-v1';
const API_CACHE = 'api-v1';
const IMAGES_CACHE = 'images-v1';

// Cache strategies by resource type
const CACHE_STRATEGIES = {
  pages: 'networkFirst',
  api: 'networkFirst',
  static: 'cacheFirst',
  images: 'cacheFirst'
};

// Critical resources to cache immediately
const CRITICAL_RESOURCES = [
  '/',
  '/offline.html',
  '/static/js/bundle.js',
  '/static/css/main.css',
  '/manifest.json'
];

// API endpoints to cache for offline access
const CACHEABLE_API_ENDPOINTS = [
  '/api/user/profile',
  '/api/reference/conditions',
  '/api/reference/medications',
  '/api/patients/recent'
];

// Install event - cache critical resources
self.addEventListener('install', event => {
  console.log('Service Worker installing...');
  
  event.waitUntil(
    Promise.all([
      // Cache critical static resources
      caches.open(STATIC_CACHE).then(cache => {
        return cache.addAll(CRITICAL_RESOURCES);
      }),
      
      // Pre-cache critical API data
      cacheApiEndpoints()
    ]).then(() => {
      console.log('Service Worker installed successfully');
      self.skipWaiting(); // Activate immediately
    })
  );
});

// Activate event - clean up old caches
self.addEventListener('activate', event => {
  console.log('Service Worker activating...');
  
  event.waitUntil(
    caches.keys().then(cacheNames => {
      return Promise.all(
        cacheNames.map(cacheName => {
          if (cacheName !== STATIC_CACHE && 
              cacheName !== API_CACHE && 
              cacheName !== IMAGES_CACHE) {
            console.log('Deleting old cache:', cacheName);
            return caches.delete(cacheName);
          }
        })
      );
    }).then(() => {
      console.log('Service Worker activated');
      clients.claim(); // Take control immediately
    })
  );
});

// Fetch event - implement caching strategies
self.addEventListener('fetch', event => {
  const url = new URL(event.request.url);
  
  // Handle different resource types
  if (url.pathname.startsWith('/api/')) {
    event.respondWith(handleApiRequest(event.request));
  } else if (url.pathname.match(/\.(png|jpg|jpeg|gif|svg|webp)$/)) {
    event.respondWith(handleImageRequest(event.request));
  } else if (url.pathname.match(/\.(js|css|woff|woff2)$/)) {
    event.respondWith(handleStaticRequest(event.request));
  } else {
    event.respondWith(handleNavigationRequest(event.request));
  }
});

// Network-first strategy for API requests
async function handleApiRequest(request) {
  try {
    const response = await fetch(request);
    
    if (response.ok && request.method === 'GET') {
      const cache = await caches.open(API_CACHE);
      cache.put(request, response.clone());
    }
    
    return response;
  } catch (error) {
    console.log('API request failed, trying cache:', request.url);
    
    const cachedResponse = await caches.match(request);
    if (cachedResponse) {
      return cachedResponse;
    }
    
    // Return offline response for failed API calls
    return new Response(JSON.stringify({
      error: 'Offline',
      message: 'This data is not available offline',
      timestamp: new Date().toISOString()
    }), {
      status: 503,
      headers: { 
        'Content-Type': 'application/json',
        'X-Offline': 'true'
      }
    });
  }
}

// Cache-first strategy for images
async function handleImageRequest(request) {
  const cache = await caches.open(IMAGES_CACHE);
  const cachedResponse = await cache.match(request);
  
  if (cachedResponse) {
    return cachedResponse;
  }
  
  try {
    const response = await fetch(request);
    if (response.ok) {
      cache.put(request, response.clone());
    }
    return response;
  } catch (error) {
    // Return placeholder image for failed image requests
    return caches.match('/offline-placeholder.png');
  }
}

// Cache-first strategy for static assets
async function handleStaticRequest(request) {
  const cache = await caches.open(STATIC_CACHE);
  const cachedResponse = await cache.match(request);
  
  if (cachedResponse) {
    return cachedResponse;
  }
  
  try {
    const response = await fetch(request);
    if (response.ok) {
      cache.put(request, response.clone());
    }
    return response;
  } catch (error) {
    throw error; // Let the browser handle static asset failures
  }
}

// Network-first strategy for navigation requests
async function handleNavigationRequest(request) {
  try {
    const response = await fetch(request);
    
    if (response.ok) {
      const cache = await caches.open(STATIC_CACHE);
      cache.put(request, response.clone());
    }
    
    return response;
  } catch (error) {
    console.log('Navigation request failed, trying cache:', request.url);
    
    const cachedResponse = await caches.match(request);
    if (cachedResponse) {
      return cachedResponse;
    }
    
    // Return offline page
    return caches.match('/offline.html');
  }
}

// Pre-cache API endpoints
async function cacheApiEndpoints() {
  const cache = await caches.open(API_CACHE);
  
  const requests = CACHEABLE_API_ENDPOINTS.map(endpoint => {
    return fetch(endpoint, { credentials: 'include' })
      .then(response => {
        if (response.ok) {
          cache.put(endpoint, response.clone());
        }
        return response;
      })
      .catch(error => {
        console.log('Failed to pre-cache:', endpoint, error);
      });
  });
  
  return Promise.allSettled(requests);
}
```

### Monitoring and Logging Best Practices

#### Structured Logging
```typescript
// apps/backend/src/utils/logger.ts
import winston from 'winston';

const logFormat = winston.format.combine(
  winston.format.timestamp(),
  winston.format.errors({ stack: true }),
  winston.format.json()
);

export const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: logFormat,
  defaultMeta: { 
    service: 'clinic-management',
    version: process.env.npm_package_version || '1.0.0'
  },
  transports: [
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.colorize(),
        winston.format.simple()
      )
    })
  ]
});

// Request logging middleware
export function requestLogger(req: Request, res: Response, next: NextFunction) {
  const start = Date.now();
  const requestId = crypto.randomUUID();
  
  // Add request ID to request object
  (req as any).requestId = requestId;
  
  res.on('finish', () => {
    const duration = Date.now() - start;
    
    logger.info('HTTP Request', {
      requestId,
      method: req.method,
      path: req.path,
      statusCode: res.statusCode,
      duration: `${duration}ms`,
      userAgent: req.get('User-Agent'),
      ip: req.ip,
      user: (req as any).user?.id || 'anonymous'
    });
    
    // Warn on slow requests
    if (duration > 1000) {
      logger.warn('Slow Request Detected', {
        requestId,
        method: req.method,
        path: req.path,
        duration: `${duration}ms`
      });
    }
  });
  
  next();
}

// Error logging
export function logError(error: Error, context: any = {}) {
  logger.error('Application Error', {
    message: error.message,
    stack: error.stack,
    ...context
  });
}
```

## 🚨 Common Pitfalls and How to Avoid Them

### Railway-Specific Issues

#### Health Check Configuration
```yaml
# ❌ Bad: Generic health check
healthcheckPath = "/"

# ✅ Good: Dedicated health endpoint
healthcheckPath = "/health"
healthcheckTimeout = 300
```

#### Environment Variable Management
```bash
# ❌ Bad: Hardcoded values
DATABASE_URL="postgresql://user:pass@localhost/db"

# ✅ Good: Railway-managed variables
railway variables set DATABASE_URL=${{Postgres.DATABASE_URL}}
```

### Security Anti-Patterns

#### CORS Configuration
```typescript
// ❌ Bad: Overly permissive CORS
app.use(cors({
  origin: '*',
  credentials: true
}));

// ✅ Good: Specific origins
app.use(cors({
  origin: process.env.ALLOWED_ORIGINS?.split(',') || ['http://localhost:3000'],
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));
```

#### Error Information Exposure
```typescript
// ❌ Bad: Exposing stack traces in production
app.use((err, req, res, next) => {
  res.status(500).json({ error: err.stack });
});

// ✅ Good: Environment-aware error handling
app.use((err, req, res, next) => {
  logger.error('Application Error', { error: err.message, stack: err.stack });
  
  res.status(500).json({
    error: 'Internal server error',
    message: process.env.NODE_ENV === 'development' ? err.message : 'Something went wrong'
  });
});
```

### Performance Anti-Patterns

#### Database Connection Issues
```typescript
// ❌ Bad: Creating new connections for each request
app.get('/api/patients', async (req, res) => {
  const client = new Client(/* connection config */);
  await client.connect();
  // ... query logic
  await client.end();
});

// ✅ Good: Using connection pool
app.get('/api/patients', async (req, res) => {
  const client = await pool.connect();
  try {
    // ... query logic
  } finally {
    client.release();
  }
});
```

---

## 🧭 Navigation

**Previous**: [Cost Analysis](./cost-analysis.md)  
**Next**: [Scoring Methodology](./scoring-methodology.md)

---

*Best practices compiled from Railway.com documentation, industry standards, and production deployment experience - July 2025*

## 📚 Additional Resources

1. [Railway.com Best Practices](https://docs.railway.app/deploy/best-practices)
2. [Express.js Security Best Practices](https://expressjs.com/en/advanced/best-practice-security.html)
3. [Node.js Production Best Practices](https://nodejs.org/en/docs/guides/nodejs-docker-webapp/)
4. [PostgreSQL Performance Tips](https://wiki.postgresql.org/wiki/Performance_Optimization)
5. [PWA Best Practices](https://web.dev/progressive-web-apps/)