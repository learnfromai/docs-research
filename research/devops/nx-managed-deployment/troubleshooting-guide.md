# Troubleshooting Guide: Nx Managed Deployment

## 🎯 Overview

This comprehensive troubleshooting guide addresses common issues encountered when deploying Nx monorepo projects to managed cloud platforms, providing step-by-step solutions and preventive measures.

---

## 🚨 Build Issues

### Module Resolution Errors

#### Issue: "Cannot resolve module" during build
```bash
Error: Cannot resolve module '@myapp/shared/types'
Module not found: Error: Can't resolve '@myapp/shared/types' in '/app/apps/frontend/src'
```

**Root Causes:**
- Incorrect TypeScript path mapping
- Missing library in dependencies
- Build order issues in Nx workspace

**Solutions:**

**1. Verify Path Mapping Configuration**
```json
// tsconfig.base.json
{
  "compilerOptions": {
    "paths": {
      "@myapp/shared/types": ["libs/shared/types/src/index.ts"],
      "@myapp/shared/utils": ["libs/shared/utils/src/index.ts"],
      "@myapp/ui/components": ["libs/ui/components/src/index.ts"]
    }
  }
}
```

**2. Check Library Dependencies**
```json
// apps/frontend/project.json
{
  "targets": {
    "build": {
      "executor": "@nrwl/vite:build",
      "options": {
        "buildLibsFromSource": false
      },
      "configurations": {
        "production": {
          "buildLibsFromSource": false
        }
      }
    }
  }
}
```

**3. Fix Build Order**
```bash
# Build libraries first, then applications
nx build shared-types
nx build shared-utils  
nx build frontend
```

**4. Platform-Specific Fix (Digital Ocean)**
```yaml
# .do/app.yaml - Ensure proper build command
build_command: |
  npm ci --only=production
  # Build shared libraries first
  nx build shared-types
  nx build shared-utils
  # Then build applications
  nx build frontend --configuration=production
```

---

### Out of Memory Errors

#### Issue: "JavaScript heap out of memory" during build
```bash
FATAL ERROR: Ineffective mark-compacts near heap limit Allocation failed - JavaScript heap out of memory
```

**Solutions:**

**1. Increase Node.js Memory Limit**
```bash
# In build command
export NODE_OPTIONS="--max-old-space-size=4096"
npm run build:frontend
```

**2. Platform-Specific Memory Configuration**

**Digital Ocean:**
```yaml
# .do/app.yaml
services:
  - name: frontend
    instance_size_slug: basic-s  # Upgrade from basic-xxs
    build_command: |
      export NODE_OPTIONS="--max-old-space-size=4096"
      npm ci && npm run build:frontend
```

**Railway:**
```toml
# railway.toml
[nixpacks.phases.build]
cmds = [
  "export NODE_OPTIONS='--max-old-space-size=4096'",
  "npm run build:frontend"
]
```

**3. Optimize Build Process**
```json
// vite.config.ts - Reduce bundle splitting
export default defineConfig({
  build: {
    rollupOptions: {
      output: {
        manualChunks: undefined, // Disable automatic chunking
        chunkSizeWarningLimit: 2000
      }
    }
  }
});
```

---

### Dependency Installation Failures

#### Issue: npm install fails with permission or network errors
```bash
npm ERR! code EACCES
npm ERR! errno -13
npm ERR! Error: EACCES: permission denied, open '/root/.npm/_locks/staging-xyz'
```

**Solutions:**

**1. Use npm ci Instead of npm install**
```bash
# Recommended for production builds
npm ci --only=production --silent
```

**2. Clear npm Cache**
```bash
# In build command
npm cache clean --force
npm ci --only=production
```

**3. Fix Package-lock.json Issues**
```bash
# Locally, then commit the fix
rm package-lock.json node_modules -rf
npm install
git add package-lock.json
git commit -m "fix: regenerate package-lock.json"
```

---

## 🌐 Runtime Issues

### Application Won't Start

#### Issue: Application starts but immediately crashes
```bash
Error: Cannot find module '/app/dist/apps/backend/main.js'
Application failed to start
```

**Root Causes:**
- Build output path incorrect
- Missing build artifacts
- Incorrect start command

**Solutions:**

**1. Verify Build Output**
```bash
# Check build completed successfully
ls -la dist/apps/
# Should show frontend/ and backend/ directories
```

**2. Correct Start Commands**
```json
// package.json
{
  "scripts": {
    "start:frontend": "npx serve dist/apps/frontend -s -n -L -p $PORT",
    "start:backend": "node dist/apps/backend/main.js"
  }
}
```

**3. Platform-Specific Start Command Fixes**

**Digital Ocean:**
```yaml
# .do/app.yaml
services:
  - name: backend
    run_command: node dist/apps/backend/main.js
    # Ensure build creates this file
    build_command: |
      npm ci && npm run build:backend
      ls -la dist/apps/backend/  # Debug output
```

---

### Health Check Failures

#### Issue: Health check endpoint returns 404 or 500
```bash
Health check failed: GET /health -> 404 Not Found
Service marked as unhealthy, restarting...
```

**Solutions:**

**1. Implement Proper Health Check**
```typescript
// apps/backend/src/main.ts
import express from 'express';

const app = express();

// Health check endpoint (critical for managed platforms)
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
    // Add your database ping here
    await pool.query('SELECT 1');
    res.status(200).json({ database: 'connected' });
  } catch (error) {
    res.status(503).json({ 
      database: 'disconnected', 
      error: error.message 
    });
  }
});

const port = process.env.PORT || 8080;
app.listen(port, () => {
  console.log(`Server running on port ${port}`);
  console.log(`Health check: http://localhost:${port}/health`);
});
```

**2. Configure Platform Health Checks**

**Digital Ocean:**
```yaml
# .do/app.yaml
services:
  - name: backend
    health_check:
      http_path: /health
      initial_delay_seconds: 60  # Give app time to start
      period_seconds: 10
      timeout_seconds: 5
      success_threshold: 1
      failure_threshold: 3
```

**Railway:**
```toml
# railway.toml
[deploy]
healthcheckPath = "/health"
healthcheckTimeout = 60
```

---

### Database Connection Issues

#### Issue: Cannot connect to database
```bash
Error: connect ECONNREFUSED 127.0.0.1:5432
Error: password authentication failed for user "postgres"
```

**Solutions:**

**1. Verify Database Connection String**
```typescript
// apps/backend/src/database/connection.ts
import { Pool } from 'pg';

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: process.env.NODE_ENV === 'production' ? {
    rejectUnauthorized: false  // Required for managed databases
  } : false,
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000
});

// Test connection on startup
pool.connect((err, client, release) => {
  if (err) {
    console.error('Database connection failed:', err);
    process.exit(1);
  }
  console.log('✅ Database connected successfully');
  release();
});

export { pool };
```

**2. Environment Variable Configuration**

**Digital Ocean:**
```yaml
# .do/app.yaml
services:
  - name: backend
    envs:
      - key: DATABASE_URL
        value: "${db.DATABASE_URL}"  # Auto-injected by platform

databases:
  - name: db
    engine: PG
    version: "15"
```

**Railway:**
```bash
# Database URL is auto-injected as ${{Postgres.DATABASE_URL}}
railway variables set DATABASE_URL=${{Postgres.DATABASE_URL}}
```

**3. Database Migration Issues**
```typescript
// Run migrations on startup
async function startServer() {
  try {
    // Run migrations first
    await runMigrations();
    
    // Then start the server
    const port = process.env.PORT || 8080;
    app.listen(port, () => {
      console.log(`Server running on port ${port}`);
    });
  } catch (error) {
    console.error('Startup failed:', error);
    process.exit(1);
  }
}

startServer();
```

---

## 🔒 Authentication & CORS Issues

### CORS Errors

#### Issue: Frontend cannot connect to backend API
```bash
Access to fetch at 'https://backend.domain.com/api/users' from origin 'https://frontend.domain.com' has been blocked by CORS policy
```

**Solutions:**

**1. Configure CORS Properly**
```typescript
// apps/backend/src/main.ts
import cors from 'cors';

const corsOptions = {
  origin: [
    process.env.FRONTEND_URL,
    process.env.CORS_ORIGIN,
    'https://your-frontend-domain.com',
    // Development origins
    'http://localhost:3000',
    'http://localhost:4200'
  ].filter(Boolean),
  credentials: true,
  optionsSuccessStatus: 200,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: [
    'Content-Type', 
    'Authorization', 
    'X-Requested-With',
    'Accept',
    'Origin'
  ]
};

app.use(cors(corsOptions));

// Handle preflight requests
app.options('*', cors(corsOptions));
```

**2. Platform-Specific CORS Configuration**

**Digital Ocean:**
```yaml
# .do/app.yaml
services:
  - name: backend
    envs:
      - key: CORS_ORIGIN
        value: "${frontend.PUBLIC_URL}"
  - name: frontend
    envs:
      - key: VITE_API_URL
        value: "${backend.PUBLIC_URL}"
```

**3. Environment Variable Debug**
```typescript
// Debug CORS configuration
console.log('CORS Configuration:', {
  frontendUrl: process.env.FRONTEND_URL,
  corsOrigin: process.env.CORS_ORIGIN,
  nodeEnv: process.env.NODE_ENV
});
```

---

### JWT Authentication Issues

#### Issue: JWT tokens not working correctly
```bash
Error: JsonWebTokenError: invalid signature
Error: TokenExpiredError: jwt expired
```

**Solutions:**

**1. Consistent JWT Secret**
```typescript
// apps/backend/src/utils/jwt.ts
import jwt from 'jsonwebtoken';

const JWT_SECRET = process.env.JWT_SECRET;

if (!JWT_SECRET) {
  console.error('JWT_SECRET environment variable is required');
  process.exit(1);
}

if (JWT_SECRET.length < 32) {
  console.error('JWT_SECRET must be at least 32 characters long');
  process.exit(1);
}

export const generateToken = (payload: any) => {
  return jwt.sign(payload, JWT_SECRET, {
    expiresIn: process.env.JWT_EXPIRES_IN || '7d'
  });
};

export const verifyToken = (token: string) => {
  return jwt.verify(token, JWT_SECRET);
};
```

**2. Token Storage (Frontend)**
```typescript
// apps/frontend/src/utils/auth.ts
// Secure token storage
export class TokenStorage {
  private static readonly ACCESS_TOKEN_KEY = 'accessToken';

  static setToken(token: string) {
    if (typeof window !== 'undefined') {
      localStorage.setItem(this.ACCESS_TOKEN_KEY, token);
    }
  }

  static getToken(): string | null {
    if (typeof window !== 'undefined') {
      return localStorage.getItem(this.ACCESS_TOKEN_KEY);
    }
    return null;
  }

  static removeToken() {
    if (typeof window !== 'undefined') {
      localStorage.removeItem(this.ACCESS_TOKEN_KEY);
    }
  }
}
```

---

## 📊 Performance Issues

### Slow Response Times

#### Issue: API responses taking 2+ seconds
```bash
GET /api/users -> 2,847ms
GET /api/posts -> 3,156ms
High response times causing timeouts
```

**Solutions:**

**1. Database Query Optimization**
```sql
-- Add indexes for frequently queried columns
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_posts_user_id ON posts(user_id);
CREATE INDEX idx_posts_created_at ON posts(created_at DESC);

-- Optimize queries
-- Instead of: SELECT * FROM posts ORDER BY created_at DESC;
SELECT id, title, excerpt, created_at FROM posts 
WHERE status = 'published' 
ORDER BY created_at DESC 
LIMIT 20;
```

**2. Connection Pool Optimization**
```typescript
// apps/backend/src/database/connection.ts
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  // Connection pool settings
  max: 20,                    // Maximum number of connections
  min: 5,                     // Minimum number of connections
  idleTimeoutMillis: 30000,   // Close idle connections after 30s
  connectionTimeoutMillis: 2000, // Timeout connection attempts after 2s
  acquireTimeoutMillis: 60000,   // Timeout acquiring connection after 60s
  ssl: process.env.NODE_ENV === 'production' ? {
    rejectUnauthorized: false
  } : false
});
```

**3. Enable Compression**
```typescript
// apps/backend/src/main.ts
import compression from 'compression';

app.use(compression({
  filter: (req, res) => {
    if (req.headers['x-no-compression']) {
      return false;
    }
    return compression.filter(req, res);
  },
  threshold: 0,
  level: 6,
  memLevel: 8
}));
```

---

### High Memory Usage

#### Issue: Application consuming excessive memory
```bash
Memory usage: 85% (425MB/512MB limit)
Application restarting due to memory limit
```

**Solutions:**

**1. Memory Leak Detection**
```typescript
// apps/backend/src/utils/monitoring.ts
export function monitorMemory() {
  setInterval(() => {
    const usage = process.memoryUsage();
    const mbUsage = {
      rss: Math.round(usage.rss / 1024 / 1024),
      heapTotal: Math.round(usage.heapTotal / 1024 / 1024),
      heapUsed: Math.round(usage.heapUsed / 1024 / 1024),
      external: Math.round(usage.external / 1024 / 1024)
    };
    
    console.log('Memory usage (MB):', mbUsage);
    
    // Alert if memory usage is high
    if (mbUsage.heapUsed > 400) {
      console.warn('⚠️ High memory usage detected:', mbUsage);
    }
  }, 60000); // Check every minute
}
```

**2. Database Connection Management**
```typescript
// Ensure connections are properly released
export async function queryDatabase(query: string, params: any[]) {
  const client = await pool.connect();
  try {
    const result = await client.query(query, params);
    return result;
  } finally {
    client.release(); // Always release the connection
  }
}
```

**3. Upgrade Instance Size**

**Digital Ocean:**
```yaml
# .do/app.yaml
services:
  - name: backend
    instance_size_slug: basic-s  # 1GB RAM instead of 512MB
```

**Railway:**
```bash
# Check usage and upgrade if needed
railway status
# Upgrade through Railway dashboard
```

---

## 🔧 Platform-Specific Issues

### Digital Ocean App Platform

#### Issue: Build taking too long or timing out
```bash
Build exceeded maximum time limit (15 minutes)
Build failed due to timeout
```

**Solutions:**

**1. Optimize Build Commands**
```yaml
# .do/app.yaml
services:
  - name: frontend
    build_command: |
      # Use npm ci for faster installs
      npm ci --only=production --silent
      
      # Set memory limit
      export NODE_OPTIONS="--max-old-space-size=4096"
      
      # Build only what's needed
      npm run build:frontend
      
      # Verify build
      ls -la dist/apps/frontend
```

**2. Use Build Cache**
```yaml
# .do/app.yaml - Enable build caching
services:
  - name: frontend
    instance_size_slug: basic-s  # More powerful for builds
    build_command: |
      # npm ci automatically uses cache
      npm ci --only=production
      npm run build:frontend
```

#### Issue: SSL certificate not renewing
```bash
SSL certificate expired
HTTPS requests failing with certificate error
```

**Solutions:**

**1. Verify Domain Configuration**
```yaml
# .do/app.yaml
domains:
  - domain: yourdomain.com
    type: PRIMARY
    zone: yourdomain.com
    # Don't specify certificate_id - let DO manage it
```

**2. Check DNS Settings**
```bash
# Verify DNS points to Digital Ocean
dig yourdomain.com
# Should show Digital Ocean IP addresses
```

---

### Railway Issues

#### Issue: Service crashes with "R14" errors
```bash
Error R14 (Memory quota exceeded)
Process running mem=512M (out of memory)
```

**Solutions:**

**1. Monitor Resource Usage**
```bash
# Check current usage
railway status

# View detailed metrics
railway metrics --service backend
```

**2. Optimize Memory Usage**
```typescript
// Implement graceful shutdown
process.on('SIGTERM', async () => {
  console.log('SIGTERM received, shutting down gracefully');
  
  // Close database connections
  await pool.end();
  
  // Close server
  server.close(() => {
    console.log('Server closed');
    process.exit(0);
  });
});
```

#### Issue: Database connection limit exceeded
```bash
Error: too many connections for database
Connection pool exhausted
```

**Solutions:**

**1. Reduce Connection Pool Size**
```typescript
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  max: 5,  // Reduced from default 20
  min: 1,
  idleTimeoutMillis: 10000  // Close idle connections faster
});
```

**2. Implement Connection Retry Logic**
```typescript
async function connectWithRetry(retries = 3) {
  for (let i = 0; i < retries; i++) {
    try {
      const client = await pool.connect();
      return client;
    } catch (error) {
      console.warn(`Connection attempt ${i + 1} failed:`, error.message);
      if (i === retries - 1) throw error;
      await new Promise(resolve => setTimeout(resolve, 1000 * (i + 1)));
    }
  }
}
```

---

### Render Issues

#### Issue: Service sleeping on free tier
```bash
Service is spinning down due to inactivity
504 Gateway Timeout - Service unavailable
```

**Solutions:**

**1. Implement Keep-Alive**
```typescript
// Simple keep-alive endpoint
app.get('/ping', (req, res) => {
  res.status(200).send('pong');
});

// Self-ping to prevent sleeping (use sparingly)
if (process.env.NODE_ENV === 'production' && process.env.RENDER_SERVICE_URL) {
  setInterval(async () => {
    try {
      await fetch(`${process.env.RENDER_SERVICE_URL}/ping`);
    } catch (error) {
      // Ignore errors
    }
  }, 14 * 60 * 1000); // Every 14 minutes
}
```

**2. Upgrade to Paid Plan**
```yaml
# render.yaml
services:
  - type: web
    name: backend
    plan: starter  # $7/month - no sleeping
    env: node
```

---

## 🐛 Debugging Techniques

### Log Analysis

#### Structured Logging Setup
```typescript
// apps/backend/src/utils/logger.ts
import winston from 'winston';

const logFormat = winston.format.combine(
  winston.format.timestamp(),
  winston.format.errors({ stack: true }),
  winston.format.json(),
  winston.format.printf(({ timestamp, level, message, ...meta }) => {
    return JSON.stringify({
      timestamp,
      level,
      message,
      service: process.env.SERVICE_NAME || 'backend',
      ...meta
    });
  })
);

export const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: logFormat,
  transports: [
    new winston.transports.Console()
  ]
});

// Request logging middleware
export const requestLogger = (req: Request, res: Response, next: NextFunction) => {
  const start = Date.now();
  
  res.on('finish', () => {
    const duration = Date.now() - start;
    
    logger.info('HTTP Request', {
      method: req.method,
      url: req.url,
      statusCode: res.statusCode,
      duration,
      userAgent: req.get('User-Agent'),
      ip: req.ip,
      userId: (req as any).user?.id
    });
  });
  
  next();
};
```

### Performance Monitoring

#### Response Time Tracking
```typescript
// apps/backend/src/middleware/performance.ts
export const performanceMonitoring = (req: Request, res: Response, next: NextFunction) => {
  const start = process.hrtime();
  
  res.on('finish', () => {
    const [seconds, nanoseconds] = process.hrtime(start);
    const duration = (seconds * 1000) + (nanoseconds / 1000000);
    
    // Log slow requests
    if (duration > 1000) {
      console.warn(`🐌 Slow request detected: ${req.method} ${req.url} - ${duration.toFixed(2)}ms`);
    }
    
    // Track metrics
    res.setHeader('X-Response-Time', `${duration.toFixed(2)}ms`);
  });
  
  next();
};
```

### Database Query Debugging

#### Query Performance Logging
```typescript
// apps/backend/src/database/connection.ts
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  // ... other config
});

// Log slow queries
const originalQuery = pool.query;
pool.query = function(...args) {
  const start = Date.now();
  const result = originalQuery.apply(this, args);
  
  if (result instanceof Promise) {
    return result.then(res => {
      const duration = Date.now() - start;
      if (duration > 1000) {
        console.warn(`🐌 Slow query (${duration}ms):`, args[0]);
      }
      return res;
    });
  }
  
  return result;
};
```

---

## 📋 Diagnostic Checklists

### Build Failure Checklist
```yaml
Build Issues Diagnostic:
  - [ ] Check package.json scripts are correct
  - [ ] Verify all dependencies are in package.json
  - [ ] Ensure TypeScript configuration is valid
  - [ ] Check for module resolution errors
  - [ ] Verify build output paths
  - [ ] Check memory limits and increase if needed
  - [ ] Ensure environment variables are set
  - [ ] Review build logs for specific error messages
```

### Runtime Issues Checklist
```yaml
Runtime Issues Diagnostic:
  - [ ] Verify health check endpoint is accessible
  - [ ] Check database connection string and credentials
  - [ ] Ensure environment variables are correctly set
  - [ ] Verify CORS configuration for frontend/backend communication
  - [ ] Check for memory leaks or high resource usage
  - [ ] Review application logs for error patterns
  - [ ] Test endpoints manually with curl or Postman
  - [ ] Verify SSL certificate status (if using custom domain)
```

### Performance Issues Checklist
```yaml
Performance Issues Diagnostic:
  - [ ] Check database query performance and indexes
  - [ ] Review connection pool configuration
  - [ ] Monitor memory and CPU usage patterns
  - [ ] Check for N+1 query problems
  - [ ] Verify caching strategies are implemented
  - [ ] Review bundle sizes for frontend applications
  - [ ] Check for memory leaks in long-running processes
  - [ ] Monitor third-party API response times
```

---

## 📞 Getting Help

### Platform Support Channels

#### Digital Ocean
- **Support Portal**: https://cloud.digitalocean.com/support
- **Documentation**: https://docs.digitalocean.com/products/app-platform/
- **Community**: https://www.digitalocean.com/community/
- **Status Page**: https://status.digitalocean.com/

#### Railway
- **Discord Community**: https://discord.gg/railway
- **Documentation**: https://docs.railway.app/
- **Support Email**: help@railway.app
- **Status Page**: https://status.railway.app/

#### Render
- **Support Portal**: https://render.com/support
- **Documentation**: https://render.com/docs
- **Community Forum**: https://community.render.com/
- **Status Page**: https://status.render.com/

### When to Escalate Issues

#### Level 1: Self-Diagnosis (0-2 hours)
- Review logs and error messages
- Check common issues in this guide
- Verify configuration and environment variables
- Test with minimal reproduction case

#### Level 2: Community Help (2-8 hours)
- Search platform documentation and forums
- Ask questions in community Discord/forums
- Create minimal reproduction repository
- Review similar issues on GitHub

#### Level 3: Professional Support (8+ hours)
- Contact platform support with detailed information
- Engage development team or consultants
- Consider platform migration if issues persist
- Implement monitoring to prevent future issues

---

## 🔗 Additional Resources

### Related Documentation
- **[Implementation Guide](./implementation-guide.md)** - Complete deployment instructions
- **[Best Practices](./best-practices.md)** - Prevention strategies and optimizations
- **[Digital Ocean Deployment](./digital-ocean-deployment.md)** - Platform-specific guidance
- **[Template Examples](./template-examples.md)** - Working configuration examples

### External Tools
- **Log Analysis**: Logtail, Papertrail, LogDNA
- **Performance Monitoring**: New Relic, DataDog, Sentry
- **Database Monitoring**: PgAdmin, TablePlus, DataGrip
- **Load Testing**: k6, Artillery, Apache Bench

---

*This troubleshooting guide covers the most common issues encountered in Nx managed deployments. For platform-specific issues not covered here, consult the respective platform documentation and support channels.*