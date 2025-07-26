# Troubleshooting Guide: Common Nx Deployment Issues

## 🎯 Overview

This troubleshooting guide addresses the most common issues encountered when deploying Nx monorepos to managed platforms, with step-by-step solutions and preventive measures.

## 🚨 Build & Deployment Failures

### Issue: "nx command not found" During Build

**Symptoms:**
```bash
/bin/sh: nx: command not found
Build failed with exit code 127
```

**Root Cause:** Nx CLI not installed or not in PATH during build process.

**Solutions:**

**Option 1: Use npx (Recommended)**
```json
{
  "scripts": {
    "build:frontend": "npx nx build frontend --prod",
    "build:backend": "npx nx build backend --prod"
  }
}
```

**Option 2: Install Nx globally in build script**
```bash
# In railway.toml or build script
npm install -g @nx/cli
nx build frontend --prod
```

**Option 3: Use npm run scripts**
```json
{
  "scripts": {
    "nx": "nx",
    "build": "npm run nx build frontend --prod"
  }
}
```

**Prevention:**
- Always use `npx nx` in production build commands
- Test build commands locally before deploying
- Include Nx in devDependencies if using global installation

---

### Issue: Build Timeout on Large Monorepos

**Symptoms:**
```bash
Build timed out after 10 minutes
Process killed due to timeout
```

**Root Cause:** Large monorepos with many dependencies taking too long to build.

**Solutions:**

**Option 1: Optimize Build with Nx Cache**
```json
{
  "scripts": {
    "build:frontend": "npx nx build frontend --prod --skip-nx-cache=false",
    "build:backend": "npx nx build backend --prod --skip-nx-cache=false"
  }
}
```

**Option 2: Use Affected Commands**
```yaml
# .github/workflows/deploy.yml
- name: Build affected apps
  run: npx nx affected --target=build --prod --parallel=3
```

**Option 3: Platform-Specific Optimizations**
```toml
# railway.toml
[build]
builder = "nixpacks"
buildCommand = "npm ci --only=production && npx nx build backend --prod"

[deploy]
startCommand = "node dist/apps/backend/main.js"
```

**Prevention:**
- Use Nx Cloud for distributed caching
- Optimize dependencies and remove unused packages
- Use `--parallel` flag for concurrent builds
- Consider splitting large monorepos

---

### Issue: Module Resolution Errors

**Symptoms:**
```bash
Error: Cannot resolve module '@myapp/shared-types'
Module not found: Can't resolve '../../libs/shared-types'
```

**Root Cause:** Incorrect path mapping or build order issues in monorepo.

**Solutions:**

**Option 1: Fix tsconfig.json Paths**
```json
{
  "compilerOptions": {
    "baseUrl": ".",
    "paths": {
      "@myapp/shared-types": ["libs/shared-types/src/index.ts"],
      "@myapp/*": ["libs/*/src/index.ts"]
    }
  }
}
```

**Option 2: Build Libraries First**
```bash
# Build in correct order
npx nx build shared-types
npx nx build backend --prod
```

**Option 3: Use Nx Project Dependencies**
```json
// apps/backend/project.json
{
  "name": "backend",
  "implicitDependencies": ["shared-types"],
  "targets": {
    "build": {
      "dependsOn": ["^build"]
    }
  }
}
```

**Prevention:**
- Always define proper project dependencies
- Use absolute imports with path mapping
- Test build process locally
- Use `nx dep-graph` to visualize dependencies

---

## 🗄 Database Connection Issues

### Issue: "Connection refused" to Database

**Symptoms:**
```bash
Error: connect ECONNREFUSED 127.0.0.1:3306
ER_ACCESS_DENIED_ERROR: Access denied for user
```

**Root Cause:** Incorrect database configuration or network issues.

**Solutions:**

**Option 1: Verify Environment Variables**
```typescript
// Debug database configuration
console.log('Database config:', {
  host: process.env.MYSQLHOST,
  port: process.env.MYSQLPORT,
  user: process.env.MYSQLUSER,
  database: process.env.MYSQLDATABASE,
  // Don't log password in production!
});
```

**Option 2: Add Connection Retry Logic**
```typescript
// apps/backend/src/config/database-retry.ts
import mysql from 'mysql2/promise';

async function createConnectionWithRetry(retries = 5): Promise<mysql.Connection> {
  for (let i = 0; i < retries; i++) {
    try {
      const connection = await mysql.createConnection({
        host: process.env.MYSQLHOST,
        port: parseInt(process.env.MYSQLPORT || '3306'),
        user: process.env.MYSQLUSER,
        password: process.env.MYSQLPASSWORD,
        database: process.env.MYSQLDATABASE,
        ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false,
        connectTimeout: 60000,
      });
      
      console.log('✅ Database connected successfully');
      return connection;
    } catch (error) {
      console.error(`❌ Database connection attempt ${i + 1} failed:`, error.message);
      
      if (i === retries - 1) throw error;
      
      // Wait before retrying (exponential backoff)
      await new Promise(resolve => setTimeout(resolve, Math.pow(2, i) * 1000));
    }
  }
  
  throw new Error('Failed to connect after all attempts');
}
```

**Option 3: Railway-Specific Fix**
```bash
# Railway automatically provides these variables
MYSQLHOST=${{MySQL.MYSQLHOST}}
MYSQLPORT=${{MySQL.MYSQLPORT}}
MYSQLUSER=${{MySQL.MYSQLUSER}}
MYSQLPASSWORD=${{MySQL.MYSQLPASSWORD}}
MYSQLDATABASE=${{MySQL.MYSQLDATABASE}}
```

**Prevention:**
- Always use environment variables for database config
- Implement connection retry logic
- Test database connectivity before app startup
- Use health checks to monitor database status

---

### Issue: SSL/TLS Connection Errors

**Symptoms:**
```bash
Error: ER_NOT_SUPPORTED_AUTH_MODE
Error: unable to verify the first certificate
```

**Root Cause:** SSL configuration mismatch between app and database.

**Solutions:**

**Option 1: Configure SSL Properly**
```typescript
const connection = mysql.createConnection({
  // ... other config
  ssl: process.env.NODE_ENV === 'production' 
    ? { 
        rejectUnauthorized: false,
        ca: process.env.DATABASE_CA_CERT 
      } 
    : false
});
```

**Option 2: For PlanetScale (SSL Required)**
```typescript
const connection = mysql.createConnection({
  host: process.env.PLANETSCALE_HOST,
  username: process.env.PLANETSCALE_USERNAME,
  password: process.env.PLANETSCALE_PASSWORD,
  database: process.env.PLANETSCALE_DATABASE,
  ssl: { rejectUnauthorized: true }
});
```

**Option 3: Disable SSL for Development**
```typescript
const sslConfig = process.env.NODE_ENV === 'production' 
  ? { rejectUnauthorized: false }
  : false;
```

---

## 🌐 CORS and API Issues

### Issue: CORS Errors in Production

**Symptoms:**
```bash
Access to XMLHttpRequest at 'https://api.example.com' from origin 'https://example.com' 
has been blocked by CORS policy
```

**Root Cause:** Frontend and backend URLs don't match CORS configuration.

**Solutions:**

**Option 1: Dynamic CORS Configuration**
```typescript
// apps/backend/src/middleware/cors.ts
import cors from 'cors';

const allowedOrigins = [
  'http://localhost:3000', // Development
  'https://yourdomain.com', // Production
  'https://www.yourdomain.com', // Production with www
  process.env.FRONTEND_URL, // Dynamic
].filter(Boolean);

export const corsMiddleware = cors({
  origin: (origin, callback) => {
    // Allow requests with no origin (mobile apps, etc.)
    if (!origin) return callback(null, true);
    
    if (allowedOrigins.includes(origin)) {
      callback(null, true);
    } else {
      console.error('CORS blocked origin:', origin);
      callback(new Error('Not allowed by CORS'));
    }
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
});
```

**Option 2: Environment-Specific CORS**
```typescript
const corsOrigin = process.env.NODE_ENV === 'production'
  ? [process.env.FRONTEND_URL]
  : ['http://localhost:3000', 'http://127.0.0.1:3000'];
```

**Option 3: Railway-Specific Configuration**
```bash
# Railway Environment Variables
CORS_ORIGIN=${frontend.PUBLIC_URL}
FRONTEND_URL=${frontend.PUBLIC_URL}
```

**Prevention:**
- Use environment variables for CORS origins
- Test CORS in production-like environment
- Log blocked origins for debugging
- Include both www and non-www versions

---

### Issue: API Routes Not Found (404)

**Symptoms:**
```bash
GET /api/users 404 Not Found
Cannot GET /api/users
```

**Root Cause:** Incorrect API routing or path configuration.

**Solutions:**

**Option 1: Verify Route Registration**
```typescript
// apps/backend/src/main.ts
import express from 'express';
import { userRouter } from './routes/users';

const app = express();

// Debug middleware
app.use((req, res, next) => {
  console.log(`${req.method} ${req.path}`);
  next();
});

// Register routes
app.use('/api/users', userRouter);
app.use('/api', apiRouter);

// Catch-all for debugging
app.use('*', (req, res) => {
  console.log('Route not found:', req.originalUrl);
  res.status(404).json({ error: 'Route not found' });
});
```

**Option 2: Check Base Path Configuration**
```typescript
// If using a base path
const basePath = process.env.API_BASE_PATH || '';
app.use(`${basePath}/api`, apiRouter);
```

**Option 3: Frontend API URL Configuration**
```typescript
// apps/frontend/src/config/api.ts
const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:3001';

// Ensure no trailing slash
export const apiClient = axios.create({
  baseURL: API_URL.replace(/\/$/, ''),
});
```

---

## 🔧 Environment Variable Issues

### Issue: Environment Variables Not Loading

**Symptoms:**
```bash
undefined value for required environment variable
process.env.DATABASE_URL is undefined
```

**Root Cause:** Environment variables not properly set or loaded.

**Solutions:**

**Option 1: Railway Variable References**
```bash
# Use Railway's variable reference syntax
DATABASE_URL=${MySQL.DATABASE_URL}
FRONTEND_URL=${frontend.PUBLIC_URL}
BACKEND_URL=${backend.PUBLIC_URL}
```

**Option 2: Validation and Defaults**
```typescript
// apps/backend/src/config/env.ts
function getEnvVar(name: string, defaultValue?: string): string {
  const value = process.env[name] || defaultValue;
  
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  
  return value;
}

export const config = {
  PORT: parseInt(getEnvVar('PORT', '3001')),
  DATABASE_URL: getEnvVar('DATABASE_URL'),
  JWT_SECRET: getEnvVar('JWT_SECRET'),
  NODE_ENV: getEnvVar('NODE_ENV', 'development'),
};
```

**Option 3: Load Environment Files**
```typescript
// For development
import dotenv from 'dotenv';

if (process.env.NODE_ENV !== 'production') {
  dotenv.config({ path: '.env.local' });
}
```

**Prevention:**
- Always validate required environment variables on startup
- Use clear error messages
- Provide sensible defaults for non-sensitive variables
- Document all required environment variables

---

## 🚀 Performance Issues

### Issue: Slow Cold Starts

**Symptoms:**
```bash
Request timeout after 30 seconds
Gateway timeout (504)
First request takes 10+ seconds
```

**Root Cause:** Application takes too long to start up (cold start problem).

**Solutions:**

**Option 1: Optimize Application Startup**
```typescript
// apps/backend/src/main.ts
import express from 'express';

const app = express();

// Initialize database connection early
import('./config/database').then(({ db }) => {
  console.log('Database initialized');
});

// Preload heavy dependencies
import('./services/email');
import('./services/auth');

// Quick health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: Date.now() });
});

// Start server immediately
const port = process.env.PORT || 3001;
app.listen(port, () => {
  console.log(`🚀 Server running on port ${port}`);
});
```

**Option 2: Keep Services Warm**
```bash
# Use a cron job or monitoring service to ping your app
curl -f https://your-app.railway.app/health
```

**Option 3: Render-Specific: Upgrade Plan**
```yaml
# render.yaml - Use paid plan to avoid cold starts
services:
  - type: web
    name: backend
    plan: starter  # Paid plan = no cold starts
```

**Prevention:**
- Minimize startup dependencies
- Use lazy loading for heavy services
- Consider serverless alternatives for low-traffic apps
- Implement proper health checks

---

### Issue: Memory Limit Exceeded

**Symptoms:**
```bash
JavaScript heap out of memory
Process killed (OOMKilled)
Container restart due to memory limit
```

**Root Cause:** Application exceeding platform memory limits.

**Solutions:**

**Option 1: Optimize Memory Usage**
```typescript
// Memory leak prevention
process.on('uncaughtException', (error) => {
  console.error('Uncaught Exception:', error);
  // Graceful shutdown
  process.exit(1);
});

process.on('unhandledRejection', (reason, promise) => {
  console.error('Unhandled Rejection at:', promise, 'reason:', reason);
});

// Database connection pooling
const pool = mysql.createPool({
  connectionLimit: 5, // Reduce for low-memory environments
  acquireTimeout: 30000,
  timeout: 30000,
});
```

**Option 2: Increase Memory Limits**
```toml
# railway.toml
[[services]]
[services.backend]
# Upgrade to higher memory tier
```

**Option 3: Node.js Memory Options**
```json
{
  "scripts": {
    "start": "node --max-old-space-size=512 dist/apps/backend/main.js"
  }
}
```

**Prevention:**
- Monitor memory usage in production
- Use connection pooling
- Implement proper cleanup
- Profile memory usage during development

---

## 🔒 SSL and Domain Issues

### Issue: SSL Certificate Problems

**Symptoms:**
```bash
NET::ERR_CERT_AUTHORITY_INVALID
SSL certificate verification failed
```

**Root Cause:** SSL certificate not properly configured or expired.

**Solutions:**

**Option 1: Railway Custom Domain Setup**
```bash
# Railway CLI
railway domain add yourdomain.com
railway domain add www.yourdomain.com

# DNS Settings (at your domain registrar)
CNAME yourdomain.com -> your-project.railway.app
CNAME www.yourdomain.com -> your-project.railway.app
```

**Option 2: Verify SSL Certificate**
```bash
# Check SSL certificate
openssl s_client -connect yourdomain.com:443 -servername yourdomain.com

# Check certificate expiration
curl -vI https://yourdomain.com 2>&1 | grep -i "expire\|certificate"
```

**Option 3: Force HTTPS Redirect**
```typescript
// apps/backend/src/middleware/https.ts
export const httpsRedirect = (req: express.Request, res: express.Response, next: express.NextFunction) => {
  if (process.env.NODE_ENV === 'production' && req.header('x-forwarded-proto') !== 'https') {
    return res.redirect(`https://${req.header('host')}${req.url}`);
  }
  next();
};
```

---

## 🔍 Debugging Tools and Commands

### Useful Debugging Commands

**Railway CLI:**
```bash
# View logs
railway logs

# Connect to database
railway connect MySQL

# Run commands in production environment
railway run node dist/apps/backend/main.js

# Check environment variables
railway variables

# View project status
railway status
```

**General Debugging:**
```bash
# Check build outputs
ls -la dist/apps/frontend
ls -la dist/apps/backend

# Test API endpoints
curl -f https://your-api.com/health
curl -X POST -H "Content-Type: application/json" -d '{"test":"data"}' https://your-api.com/api/test

# Check database connection
mysql -h hostname -P port -u username -p database_name

# View system resources
ps aux | grep node
free -m  # Memory usage
df -h    # Disk usage
```

### Debugging Configuration

```typescript
// apps/backend/src/utils/debug.ts
export class Debug {
  static log(message: string, data?: any) {
    if (process.env.NODE_ENV === 'development' || process.env.DEBUG === 'true') {
      console.log(`[DEBUG] ${message}`, data);
    }
  }

  static error(message: string, error?: any) {
    console.error(`[ERROR] ${message}`, error);
    
    // In production, send to monitoring service
    if (process.env.NODE_ENV === 'production') {
      // Send to Sentry, LogRocket, etc.
    }
  }

  static env() {
    console.log('Environment variables:', {
      NODE_ENV: process.env.NODE_ENV,
      PORT: process.env.PORT,
      DATABASE_URL: process.env.DATABASE_URL ? '[REDACTED]' : 'MISSING',
      JWT_SECRET: process.env.JWT_SECRET ? '[REDACTED]' : 'MISSING',
    });
  }
}
```

---

## 📝 Prevention Checklist

### Pre-Deployment Checklist
```markdown
## Pre-Deployment Checklist

### ✅ Environment Configuration
- [ ] All required environment variables set
- [ ] Database connection string verified
- [ ] CORS origins configured correctly
- [ ] JWT secret is secure (production)
- [ ] API URLs match between frontend/backend

### ✅ Build Process
- [ ] Build commands tested locally
- [ ] No build warnings or errors
- [ ] Dependencies properly installed
- [ ] Bundle sizes acceptable
- [ ] Source maps configured correctly

### ✅ Database Setup
- [ ] Migrations run successfully
- [ ] Database schema matches expectations
- [ ] Connection pooling configured
- [ ] Backup strategy in place
- [ ] SSL/TLS configured properly

### ✅ Security
- [ ] JWT secret is secure and not hardcoded
- [ ] CORS configured properly
- [ ] Rate limiting implemented
- [ ] Input validation in place
- [ ] Error handling doesn't expose sensitive data

### ✅ Performance
- [ ] Bundle optimization enabled
- [ ] Caching strategy implemented
- [ ] Database queries optimized
- [ ] Memory usage within limits
- [ ] Health checks configured

### ✅ Monitoring
- [ ] Logging configured
- [ ] Health check endpoints working
- [ ] Error tracking setup
- [ ] Performance monitoring enabled
- [ ] Backup and recovery tested
```

---

**💡 Pro Tips**:
- Always test locally before deploying
- Keep detailed deployment logs
- Use health checks and monitoring
- Have a rollback plan ready
- Document your configuration for team members

---

*Troubleshooting Guide | Common Nx deployment issues and solutions*