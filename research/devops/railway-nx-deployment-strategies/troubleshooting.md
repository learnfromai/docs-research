# Troubleshooting: Railway Deployment Issues

## 🎯 Overview

This guide covers common issues encountered when deploying Nx React/Express applications to Railway.com, with specific solutions for clinic management PWA systems and the recommended single deployment strategy.

## 🚨 Common Build Issues

### Build Failures

#### Issue: "Build failed with exit code 1"
**Symptoms:**
- Build process terminates unexpectedly
- Generic error messages in Railway logs
- Missing dependencies or build tools

**Diagnosis:**
```bash
# Check Railway build logs
railway logs --deployment <deployment-id>

# Local build test
npm run build:prod
```

**Solutions:**
```bash
# 1. Verify Node.js version compatibility
{
  "engines": {
    "node": ">=18.0.0",
    "npm": ">=9.0.0"
  }
}

# 2. Clear Railway cache
railway run bash
rm -rf node_modules package-lock.json
npm install

# 3. Fix memory issues
railway variables set NODE_OPTIONS="--max-old-space-size=4096"

# 4. Update railway.json build command
{
  "build": {
    "buildCommand": "npm ci --production=false && npm run build:prod"
  }
}
```

#### Issue: "Cannot find module" during build
**Symptoms:**
- Missing TypeScript types
- Import errors for Nx libraries
- Missing build dependencies

**Solutions:**
```bash
# 1. Ensure all dependencies are listed correctly
npm install --save-dev @types/node @types/express

# 2. Check tsconfig paths
{
  "compilerOptions": {
    "paths": {
      "@clinic/*": ["libs/*/src/index.ts"]
    }
  }
}

# 3. Verify Nx workspace integrity
npx nx reset
npm run build:prod
```

#### Issue: "Vite build fails with memory error"
**Symptoms:**
- JavaScript heap out of memory
- Build process crashes during client build
- Large bundle sizes

**Solutions:**
```typescript
// vite.config.ts optimization
export default defineConfig({
  build: {
    rollupOptions: {
      output: {
        manualChunks: {
          vendor: ['react', 'react-dom'],
          mui: ['@mui/material', '@emotion/react'],
          utils: ['date-fns', 'lodash-es']
        }
      }
    },
    chunkSizeWarningLimit: 1000,
    target: 'es2018'
  }
});
```

### Static File Serving Issues

#### Issue: "404 errors on React app refresh"
**Symptoms:**
- Direct URL access returns 404
- App works on initial load but fails on refresh
- Missing SPA fallback

**Solutions:**
```typescript
// apps/api/src/main.ts - Correct SPA fallback
app.use(express.static(staticPath, { index: false }));

// SPA fallback MUST be last
app.get('*', (req, res) => {
  // Don't serve SPA for API routes or files with extensions
  if (req.path.startsWith('/api') || path.extname(req.path)) {
    return res.status(404).json({ error: 'Not found' });
  }
  
  res.sendFile(path.join(staticPath, 'index.html'));
});
```

#### Issue: "Static files not found"
**Symptoms:**
- CSS/JS files return 404
- Images not loading
- Wrong build output paths

**Solutions:**
```typescript
// 1. Verify build output paths
const staticPath = path.join(__dirname, '../../../dist/apps/client');
console.log('Static path:', staticPath);
console.log('Files:', fs.readdirSync(staticPath));

// 2. Check Vite build configuration
// vite.config.ts
export default defineConfig({
  build: {
    outDir: '../../dist/apps/client',
    emptyOutDir: true
  }
});

// 3. Verify Nx build configuration
// apps/client/project.json
{
  "build": {
    "options": {
      "outputPath": "dist/apps/client"
    }
  }
}
```

## 🔌 Runtime Issues

### Application Startup Failures

#### Issue: "Port already in use"
**Symptoms:**
- Server fails to start
- EADDRINUSE error messages
- Conflicting port assignments

**Solutions:**
```typescript
// Use Railway's PORT environment variable
const port = process.env.PORT || 3000;

// Add error handling
app.listen(port, () => {
  console.log(`Server running on port ${port}`);
}).on('error', (err) => {
  if (err.code === 'EADDRINUSE') {
    console.error(`Port ${port} is already in use`);
    process.exit(1);
  }
  throw err;
});
```

#### Issue: "Database connection failures"
**Symptoms:**
- "Connection refused" errors
- Timeout errors during startup
- Invalid connection strings

**Solutions:**
```typescript
// 1. Implement connection retry logic
const connectWithRetry = async (maxRetries = 5) => {
  for (let i = 0; i < maxRetries; i++) {
    try {
      await db.query('SELECT 1');
      console.log('Database connected successfully');
      return;
    } catch (error) {
      console.log(`Database connection attempt ${i + 1} failed:`, error.message);
      if (i === maxRetries - 1) throw error;
      await new Promise(resolve => setTimeout(resolve, 5000 * (i + 1)));
    }
  }
};

// 2. Verify DATABASE_URL format
// postgresql://username:password@host:port/database?sslmode=require

// 3. Check Railway database status
railway status
railway variables | grep DATABASE_URL
```

#### Issue: "Module import errors in production"
**Symptoms:**
- ES module errors
- CommonJS/ESM conflicts
- Missing module exports

**Solutions:**
```json
// package.json configuration
{
  "type": "module",
  "exports": {
    ".": {
      "import": "./dist/index.js",
      "require": "./dist/index.cjs"
    }
  }
}

// Or use CommonJS consistently
{
  "type": "commonjs"
}
```

### Performance Issues

#### Issue: "Slow application response times"
**Symptoms:**
- High response times (>3 seconds)
- Memory usage growing over time
- CPU usage consistently high

**Diagnosis:**
```typescript
// Add performance monitoring
app.use((req, res, next) => {
  const start = Date.now();
  res.on('finish', () => {
    const duration = Date.now() - start;
    if (duration > 1000) {
      console.warn(`Slow request: ${req.method} ${req.url} - ${duration}ms`);
    }
  });
  next();
});

// Monitor memory usage
setInterval(() => {
  const usage = process.memoryUsage();
  const mbUsed = Math.round(usage.heapUsed / 1024 / 1024);
  if (mbUsed > 400) {
    console.warn(`High memory usage: ${mbUsed}MB`);
  }
}, 60000);
```

**Solutions:**
```typescript
// 1. Implement caching
import NodeCache from 'node-cache';
const cache = new NodeCache({ stdTTL: 600 }); // 10 minutes

app.get('/api/patients', (req, res) => {
  const cacheKey = `patients-${JSON.stringify(req.query)}`;
  const cached = cache.get(cacheKey);
  
  if (cached) {
    return res.json(cached);
  }
  
  // Fetch data and cache result
  fetchPatients(req.query).then(data => {
    cache.set(cacheKey, data);
    res.json(data);
  });
});

// 2. Optimize database queries
app.get('/api/patients', async (req, res) => {
  const { page = 1, limit = 20 } = req.query;
  const offset = (page - 1) * limit;
  
  const patients = await db.query(`
    SELECT id, name, phone, last_visit 
    FROM patients 
    ORDER BY last_visit DESC 
    LIMIT $1 OFFSET $2
  `, [limit, offset]);
  
  res.json(patients.rows);
});

// 3. Enable compression
app.use(compression({ level: 6 }));
```

## 🔐 Security Issues

### Authentication Failures

#### Issue: "JWT token validation errors"
**Symptoms:**
- Users getting logged out unexpectedly
- "Invalid token" errors
- CORS issues with authentication

**Solutions:**
```typescript
// 1. Ensure consistent JWT secret
railway variables set JWT_SECRET=$(openssl rand -base64 32)

// 2. Implement proper token refresh
const generateTokens = (user) => {
  const accessToken = jwt.sign(
    { userId: user.id, role: user.role },
    process.env.JWT_SECRET,
    { expiresIn: '15m' }
  );
  
  const refreshToken = jwt.sign(
    { userId: user.id },
    process.env.JWT_REFRESH_SECRET,
    { expiresIn: '7d' }
  );
  
  return { accessToken, refreshToken };
};

// 3. Configure CORS for authentication
app.use(cors({
  origin: process.env.APP_URL,
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));
```

#### Issue: "HTTPS/SSL certificate problems"
**Symptoms:**
- Mixed content warnings
- SSL certificate errors
- Insecure connection warnings

**Solutions:**
```typescript
// 1. Enforce HTTPS in production
if (process.env.NODE_ENV === 'production') {
  app.use((req, res, next) => {
    if (req.header('x-forwarded-proto') !== 'https') {
      return res.redirect(`https://${req.header('host')}${req.url}`);
    }
    next();
  });
}

// 2. Configure security headers
app.use(helmet({
  forceHTTPSRedirect: true,
  hsts: {
    maxAge: 31536000,
    includeSubDomains: true,
    preload: true
  }
}));

// 3. Update PWA manifest for HTTPS
{
  "start_url": "https://your-domain.com/",
  "scope": "https://your-domain.com/"
}
```

## 📱 PWA Issues

### Service Worker Problems

#### Issue: "Service worker not registering"
**Symptoms:**
- PWA features not working
- No offline functionality
- Install prompt not appearing

**Solutions:**
```typescript
// 1. Verify service worker path
// apps/client/src/main.tsx
if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('/sw.js')
      .then(registration => {
        console.log('SW registered: ', registration);
      })
      .catch(registrationError => {
        console.log('SW registration failed: ', registrationError);
      });
  });
}

// 2. Check service worker serving
// apps/api/src/main.ts
app.use((req, res, next) => {
  if (req.url === '/sw.js') {
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Content-Type', 'application/javascript');
  }
  next();
});

// 3. Verify HTTPS requirement
// Service workers only work over HTTPS in production
```

#### Issue: "PWA not installable"
**Symptoms:**
- No "Add to Home Screen" prompt
- PWA criteria not met
- Manifest issues

**Solutions:**
```json
// 1. Complete manifest.json
{
  "name": "Clinic Management System",
  "short_name": "ClinicCMS",
  "start_url": "/",
  "display": "standalone",
  "background_color": "#ffffff",
  "theme_color": "#1976d2",
  "icons": [
    {
      "src": "/icons/icon-192x192.png",
      "sizes": "192x192",
      "type": "image/png",
      "purpose": "any maskable"
    },
    {
      "src": "/icons/icon-512x512.png",
      "sizes": "512x512",
      "type": "image/png",
      "purpose": "any maskable"
    }
  ]
}

// 2. Verify PWA criteria
// - HTTPS deployment
// - Valid manifest
// - Service worker
// - Responsive design
// - Offline functionality
```

## 🗄️ Database Issues

### Migration Failures

#### Issue: "Database migrations not running"
**Symptoms:**
- Tables not created
- Schema out of sync
- Migration timeout errors

**Solutions:**
```bash
# 1. Run migrations manually
railway run npx prisma migrate deploy

# 2. Set up automatic migrations
railway variables set RAILWAY_RELEASE_COMMAND="npx prisma migrate deploy"

# 3. Debug migration issues
railway run npx prisma migrate status
railway run npx prisma db pull
```

#### Issue: "Database connection pool exhaustion"
**Symptoms:**
- "Too many connections" errors
- Application hanging on database calls
- Connection timeout errors

**Solutions:**
```typescript
// 1. Optimize connection pool settings
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  max: 20, // Reduced for Railway limits
  min: 2,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
  allowExitOnIdle: true
});

// 2. Implement connection monitoring
pool.on('connect', () => {
  console.log('Database connection established');
});

pool.on('error', (err) => {
  console.error('Database connection error:', err);
});

// 3. Add graceful shutdown
process.on('SIGTERM', async () => {
  await pool.end();
  process.exit(0);
});
```

## 🔧 Environment & Configuration Issues

### Environment Variable Problems

#### Issue: "Environment variables not loading"
**Symptoms:**
- Undefined process.env values
- Configuration errors
- Missing secrets

**Solutions:**
```bash
# 1. Verify variables are set
railway variables

# 2. Check variable scope
railway variables --environment production

# 3. Update variables with proper format
railway variables set DATABASE_URL=${{Postgres.DATABASE_URL}}
railway variables set JWT_SECRET=$(openssl rand -base64 32)

# 4. Verify variable loading in code
console.log('Environment check:', {
  NODE_ENV: process.env.NODE_ENV,
  PORT: process.env.PORT,
  DATABASE_URL: process.env.DATABASE_URL ? 'Set' : 'Missing'
});
```

#### Issue: "Configuration conflicts between environments"
**Symptoms:**
- Different behavior in development vs production
- Wrong API endpoints
- Mixed environment settings

**Solutions:**
```typescript
// 1. Create environment-specific configurations
// apps/api/src/config/index.ts
export const config = {
  port: process.env.PORT || 3000,
  database: {
    url: process.env.DATABASE_URL,
    pool: {
      min: parseInt(process.env.DB_POOL_MIN || '2'),
      max: parseInt(process.env.DB_POOL_MAX || '20')
    }
  },
  auth: {
    jwtSecret: process.env.JWT_SECRET,
    jwtExpiry: process.env.JWT_EXPIRY || '15m'
  },
  app: {
    url: process.env.APP_URL || 'http://localhost:3000',
    environment: process.env.NODE_ENV || 'development'
  }
};

// 2. Validate required environment variables
const requiredVars = ['DATABASE_URL', 'JWT_SECRET'];
const missing = requiredVars.filter(var => !process.env[var]);

if (missing.length > 0) {
  console.error('Missing required environment variables:', missing);
  process.exit(1);
}
```

## 🚀 Deployment Issues

### Railway-Specific Problems

#### Issue: "Deployment stuck or hanging"
**Symptoms:**
- Build process never completes
- Deployment status shows "Building" indefinitely
- No error messages in logs

**Solutions:**
```bash
# 1. Cancel and retry deployment
railway deployment cancel
railway up

# 2. Check Railway status
# Visit https://status.railway.app

# 3. Try deployment with fresh clone
git clone <repository>
cd <project>
railway link
railway up

# 4. Contact Railway support if persistent
```

#### Issue: "Domain/DNS configuration problems"
**Symptoms:**
- Custom domain not working
- SSL certificate issues
- DNS propagation problems

**Solutions:**
```bash
# 1. Verify DNS settings
dig your-domain.com
nslookup your-domain.com

# 2. Check Railway domain configuration
railway domain list
railway domain add your-domain.com

# 3. Wait for SSL provisioning (can take up to 24 hours)
# 4. Verify CNAME record points to Railway app domain
```

## 📊 Monitoring & Debugging

### Logging Issues

#### Issue: "Missing or incomplete logs"
**Symptoms:**
- No application logs in Railway dashboard
- Missing error information
- Incomplete stack traces

**Solutions:**
```typescript
// 1. Implement structured logging
import winston from 'winston';

const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  transports: [
    new winston.transports.Console()
  ]
});

// 2. Add request logging middleware
app.use((req, res, next) => {
  logger.info('Request', {
    method: req.method,
    url: req.url,
    userAgent: req.get('User-Agent'),
    ip: req.ip
  });
  next();
});

// 3. Log uncaught exceptions
process.on('uncaughtException', (error) => {
  logger.error('Uncaught Exception', { error: error.message, stack: error.stack });
  process.exit(1);
});

process.on('unhandledRejection', (reason, promise) => {
  logger.error('Unhandled Rejection', { reason, promise });
});
```

### Health Check Failures

#### Issue: "Health checks failing"
**Symptoms:**
- Railway shows service as unhealthy
- Frequent restarts
- Timeout errors on health endpoint

**Solutions:**
```typescript
// 1. Optimize health check endpoint
app.get('/api/health', async (req, res) => {
  const checks = [];
  
  try {
    // Quick database check
    const dbCheck = await Promise.race([
      db.query('SELECT 1'),
      new Promise((_, reject) => 
        setTimeout(() => reject(new Error('DB timeout')), 5000)
      )
    ]);
    
    checks.push({ name: 'database', status: 'pass' });
  } catch (error) {
    checks.push({ name: 'database', status: 'fail', error: error.message });
  }
  
  const hasFailures = checks.some(check => check.status === 'fail');
  const status = hasFailures ? 503 : 200;
  
  res.status(status).json({
    status: hasFailures ? 'unhealthy' : 'healthy',
    checks,
    timestamp: new Date().toISOString(),
    uptime: process.uptime()
  });
});

// 2. Configure Railway health check settings
{
  "deploy": {
    "healthcheckPath": "/api/health",
    "healthcheckTimeout": 300,
    "restartPolicyType": "ON_FAILURE",
    "restartPolicyMaxRetries": 3
  }
}
```

## 🆘 Emergency Procedures

### Rollback Process

```bash
# 1. Quick rollback via Railway dashboard
# Go to deployments and click "Rollback" on previous working deployment

# 2. CLI rollback
railway deployments list
railway deployment rollback <deployment-id>

# 3. Verify rollback success
railway logs --tail
curl -f https://your-app.railway.app/api/health
```

### Disaster Recovery

```bash
# 1. Database backup restoration
railway run pg_dump $DATABASE_URL > backup.sql
railway run psql $DATABASE_URL < backup.sql

# 2. Emergency maintenance mode
railway variables set MAINTENANCE_MODE=true

# 3. Scale down to prevent further issues
railway service scale --replicas 0
```

---

## 🔗 Navigation

**← Previous:** [Template Examples](./template-examples.md) | **Next:** [README](./README.md) →

**Related Sections:**
- [Implementation Guide](./implementation-guide.md) - Step-by-step deployment instructions
- [Best Practices](./best-practices.md) - Prevention strategies and optimization patterns