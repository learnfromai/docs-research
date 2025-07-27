# Railway.com Troubleshooting Guide

This comprehensive guide covers common issues, debugging strategies, and solutions for Railway.com deployments, with specific focus on Nx monorepo projects and database connectivity.

## Common Deployment Issues

### 1. Build Failures

#### Nx Build Issues

**Problem**: Build fails with "Cannot find project" error
```
Error: Cannot find configuration for task "build" in project "web"
```

**Solution**:
```bash
# 1. Verify Nx workspace configuration
cat nx.json

# 2. Check project configuration
cat apps/web/project.json

# 3. Regenerate project configurations
npx nx reset
npx nx build web --verbose

# 4. Update Railway build command
# In railway.json or Railway dashboard:
{
  "build": {
    "buildCommand": "npx nx build web --prod"
  }
}
```

**Problem**: Build fails with dependency resolution errors
```
Error: Module not found: Can't resolve '@my-app/shared-types'
```

**Solution**:
```bash
# 1. Clear Nx cache
npx nx reset

# 2. Reinstall dependencies
rm -rf node_modules package-lock.json
npm install

# 3. Build with dependency graph
npx nx build web --with-deps

# 4. Check tsconfig paths
# In apps/web/tsconfig.json:
{
  "extends": "../../tsconfig.base.json",
  "compilerOptions": {
    "paths": {
      "@my-app/shared-types": ["libs/shared-types/src/index.ts"]
    }
  }
}
```

**Problem**: Out of memory during build
```
Error: JavaScript heap out of memory
```

**Solution**:
```bash
# 1. Increase memory limit in package.json
{
  "scripts": {
    "build": "node --max-old-space-size=4096 ./node_modules/.bin/nx build web --prod"
  }
}

# 2. Optimize build process
# In vite.config.ts:
export default defineConfig({
  build: {
    rollupOptions: {
      output: {
        manualChunks: {
          vendor: ['react', 'react-dom'],
          // Split large dependencies
        }
      }
    },
    chunkSizeWarningLimit: 1000
  }
});

# 3. Use Railway's build configuration
# In Railway dashboard, set environment variable:
NODE_OPTIONS=--max-old-space-size=4096
```

#### Docker Build Issues

**Problem**: Docker build fails with package resolution
```
npm ERR! Could not resolve dependency
```

**Solution**:
```dockerfile
# Use specific Node.js version
FROM node:18-alpine

# Copy package files first for better caching
COPY package*.json ./
COPY nx.json ./
COPY workspace.json ./

# Install dependencies with clean slate
RUN npm ci --only=production

# Copy source code
COPY . .

# Build with proper configuration
RUN npx nx build web --prod --skip-nx-cache
```

**Problem**: Railway auto-detection fails
```
Error: No buildpack found for this application
```

**Solution**:
```bash
# 1. Add Dockerfile to project root
# 2. Or specify buildpack in railway.json:
{
  "build": {
    "builder": "NIXPACKS",
    "buildCommand": "npm run build:railway"
  }
}

# 3. Create railway-specific build script in package.json:
{
  "scripts": {
    "build:railway": "npx nx build web --prod && npx nx build api --prod"
  }
}
```

### 2. Database Connection Issues

#### MySQL Connection Failures

**Problem**: Cannot connect to MySQL database
```
Error: connect ECONNREFUSED 127.0.0.1:3306
```

**Diagnosis Steps**:
```bash
# 1. Check Railway database status
railway status

# 2. Verify environment variables
railway variables

# 3. Test connection from Railway shell
railway shell
mysql -h $MYSQLHOST -P $MYSQLPORT -u $MYSQLUSER -p$MYSQLPASSWORD $MYSQLDATABASE
```

**Solution**:
```typescript
// Robust connection with retry logic
import mysql from 'mysql2/promise';

const connectWithRetry = async (maxRetries = 5, delay = 2000) => {
  for (let i = 0; i < maxRetries; i++) {
    try {
      const connection = await mysql.createConnection({
        host: process.env.MYSQLHOST,
        port: parseInt(process.env.MYSQLPORT || '3306'),
        user: process.env.MYSQLUSER,
        password: process.env.MYSQLPASSWORD,
        database: process.env.MYSQLDATABASE,
        ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false,
        connectTimeout: 60000,
        acquireTimeout: 60000,
        timeout: 60000,
      });
      
      console.log('Database connected successfully');
      return connection;
    } catch (error) {
      console.error(`Connection attempt ${i + 1} failed:`, error.message);
      
      if (i === maxRetries - 1) {
        throw new Error(`Failed to connect after ${maxRetries} attempts: ${error.message}`);
      }
      
      await new Promise(resolve => setTimeout(resolve, delay * Math.pow(2, i)));
    }
  }
};

// Health check endpoint
app.get('/db-health', async (req, res) => {
  try {
    const connection = await connectWithRetry();
    await connection.ping();
    await connection.end();
    
    res.json({ 
      status: 'healthy',
      database: 'connected',
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    res.status(503).json({
      status: 'unhealthy',
      database: 'disconnected',
      error: error.message,
      timestamp: new Date().toISOString()
    });
  }
});
```

**Problem**: SSL connection issues
```
Error: ER_NOT_SUPPORTED_AUTH_MODE
```

**Solution**:
```typescript
// Update MySQL connection configuration
const connection = await mysql.createConnection({
  host: process.env.MYSQLHOST,
  port: parseInt(process.env.MYSQLPORT || '3306'),
  user: process.env.MYSQLUSER,
  password: process.env.MYSQLPASSWORD,
  database: process.env.MYSQLDATABASE,
  ssl: {
    rejectUnauthorized: false,
    // For Railway MySQL, typically don't need client certificates
  },
  authPlugins: {
    mysql_native_password: () => () => Buffer.alloc(0),
    caching_sha2_password: mysql.authPlugins.caching_sha2_password,
  },
});
```

#### Connection Pool Issues

**Problem**: Too many connections error
```
Error: ER_TOO_MANY_USER_CONNECTIONS
```

**Solution**:
```typescript
// Optimized connection pool for Railway
const pool = mysql.createPool({
  host: process.env.MYSQLHOST,
  port: parseInt(process.env.MYSQLPORT || '3306'),
  user: process.env.MYSQLUSER,
  password: process.env.MYSQLPASSWORD,
  database: process.env.MYSQLDATABASE,
  
  // Connection pool optimization
  connectionLimit: 5, // Reduced for cost optimization
  queueLimit: 10,
  acquireTimeout: 30000,
  timeout: 60000,
  
  // Connection lifecycle
  idleTimeout: 300000, // 5 minutes
  maxIdle: 2,
  
  // Reconnection handling
  reconnect: true,
  maxReconnects: 3,
  
  // SSL configuration
  ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false,
});

// Graceful pool management
process.on('SIGTERM', async () => {
  console.log('Closing database connections...');
  await pool.end();
  process.exit(0);
});

process.on('SIGINT', async () => {
  console.log('Closing database connections...');
  await pool.end();
  process.exit(0);
});
```

### 3. Environment Variable Issues

#### Missing Environment Variables

**Problem**: Environment variables not available in application
```
Error: JWT_SECRET is not defined
```

**Diagnosis**:
```bash
# 1. Check Railway variables
railway variables

# 2. Check service-specific variables
railway variables --service api

# 3. Verify in application
console.log('Environment variables:', {
  NODE_ENV: process.env.NODE_ENV,
  DATABASE_URL: process.env.DATABASE_URL ? 'SET' : 'NOT SET',
  JWT_SECRET: process.env.JWT_SECRET ? 'SET' : 'NOT SET'
});
```

**Solution**:
```bash
# 1. Set variables using Railway CLI
railway variables set JWT_SECRET=your-secret-here --service api
railway variables set NODE_ENV=production --service api

# 2. Or use Railway dashboard
# Go to Project > Service > Variables

# 3. Add validation in application
const requiredVars = ['DATABASE_URL', 'JWT_SECRET'];
const missingVars = requiredVars.filter(varName => !process.env[varName]);

if (missingVars.length > 0) {
  console.error('Missing required environment variables:', missingVars);
  process.exit(1);
}
```

#### Variable Synchronization Issues

**Problem**: Variables not updating after changes
```
Application still uses old environment values
```

**Solution**:
```bash
# 1. Restart service to pick up new variables
railway service restart api

# 2. Redeploy if variables still not updated
railway up --service api

# 3. Check variable inheritance
# Variables set at project level inherit to all services
# Service-level variables override project-level variables
```

### 4. Networking and CORS Issues

#### CORS Configuration Problems

**Problem**: Frontend cannot connect to backend API
```
Error: CORS policy: No 'Access-Control-Allow-Origin' header is present
```

**Solution**:
```typescript
// Comprehensive CORS configuration
import cors from 'cors';

const corsOptions = {
  origin: (origin, callback) => {
    // Allow requests from Railway domains and localhost
    const allowedOrigins = [
      process.env.FRONTEND_URL,
      'http://localhost:4200',
      'http://localhost:3000',
      /\.railway\.app$/, // All Railway domains
    ].filter(Boolean);

    // Allow no origin (mobile apps, Postman, etc.)
    if (!origin) return callback(null, true);

    const isAllowed = allowedOrigins.some(allowed => {
      if (typeof allowed === 'string') {
        return allowed === origin;
      }
      if (allowed instanceof RegExp) {
        return allowed.test(origin);
      }
      return false;
    });

    if (isAllowed) {
      callback(null, true);
    } else {
      console.warn(`CORS blocked origin: ${origin}`);
      callback(new Error('Not allowed by CORS'));
    }
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With'],
  preflightContinue: false,
  optionsSuccessStatus: 204
};

app.use(cors(corsOptions));

// Debug CORS issues
app.use((req, res, next) => {
  console.log(`CORS Debug - Origin: ${req.headers.origin}, Method: ${req.method}`);
  next();
});
```

#### API Connection Issues

**Problem**: Frontend gets network errors when calling API
```
TypeError: Failed to fetch
```

**Diagnosis Steps**:
```typescript
// Add comprehensive error handling in frontend
const apiCall = async (endpoint: string, options: RequestInit = {}) => {
  const url = `${process.env.VITE_API_URL}${endpoint}`;
  
  console.log(`API Call: ${options.method || 'GET'} ${url}`);
  
  try {
    const response = await fetch(url, {
      ...options,
      headers: {
        'Content-Type': 'application/json',
        ...options.headers,
      },
    });

    console.log(`API Response: ${response.status} ${response.statusText}`);

    if (!response.ok) {
      const errorText = await response.text();
      console.error(`API Error Response: ${errorText}`);
      throw new Error(`API Error: ${response.status} - ${errorText}`);
    }

    return await response.json();
  } catch (error) {
    console.error('API Call Failed:', {
      url,
      method: options.method || 'GET',
      error: error.message,
      stack: error.stack
    });
    throw error;
  }
};
```

**Solution**:
```bash
# 1. Verify API URL environment variable
railway variables --service web
# Should show: VITE_API_URL=https://your-api-service.railway.app

# 2. Test API connectivity
curl -v https://your-api-service.railway.app/health

# 3. Check Railway service logs
railway logs --service api
railway logs --service web

# 4. Update frontend API configuration
# In apps/web/.env or Railway variables:
VITE_API_URL=https://your-api-service.railway.app
```

### 5. Performance Issues

#### Slow Application Startup

**Problem**: Application takes too long to start
```
Service timeout during startup
```

**Diagnosis**:
```typescript
// Add startup timing
const startTime = Date.now();

console.log('🚀 Starting application...');

// Database connection
console.log('📦 Connecting to database...');
const dbStart = Date.now();
await initializeDatabase();
console.log(`✅ Database connected in ${Date.now() - dbStart}ms`);

// Server startup
console.log('🌐 Starting server...');
const serverStart = Date.now();
app.listen(port, () => {
  console.log(`✅ Server started in ${Date.now() - serverStart}ms`);
  console.log(`🎉 Total startup time: ${Date.now() - startTime}ms`);
  console.log(`🔗 Server listening on port ${port}`);
});
```

**Solution**:
```typescript
// Optimize startup sequence
const optimizedStartup = async () => {
  try {
    // 1. Initialize non-blocking operations first
    const logger = initializeLogger();
    const cache = initializeCache();
    
    // 2. Database connection with timeout
    const dbPromise = Promise.race([
      initializeDatabase(),
      new Promise((_, reject) => 
        setTimeout(() => reject(new Error('Database connection timeout')), 30000)
      )
    ]);
    
    await dbPromise;
    
    // 3. Start server
    const server = app.listen(port, '0.0.0.0', () => {
      console.log(`Server ready on port ${port}`);
    });
    
    // 4. Graceful shutdown handling
    const gracefulShutdown = async (signal) => {
      console.log(`Received ${signal}, shutting down gracefully...`);
      server.close(() => {
        console.log('Server closed');
        process.exit(0);
      });
    };
    
    process.on('SIGTERM', gracefulShutdown);
    process.on('SIGINT', gracefulShutdown);
    
  } catch (error) {
    console.error('Startup failed:', error);
    process.exit(1);
  }
};

optimizedStartup();
```

#### High Memory Usage

**Problem**: Application using too much memory
```
Memory usage exceeding Railway limits
```

**Diagnosis**:
```typescript
// Memory monitoring
const monitorMemory = () => {
  const formatBytes = (bytes) => (bytes / 1024 / 1024).toFixed(2) + ' MB';
  
  setInterval(() => {
    const usage = process.memoryUsage();
    console.log('Memory Usage:', {
      heapUsed: formatBytes(usage.heapUsed),
      heapTotal: formatBytes(usage.heapTotal),
      external: formatBytes(usage.external),
      rss: formatBytes(usage.rss),
    });
    
    // Alert if memory usage is high
    if (usage.heapUsed > 400 * 1024 * 1024) { // 400MB
      console.warn('High memory usage detected!');
    }
  }, 30000); // Check every 30 seconds
};

monitorMemory();
```

**Solution**:
```typescript
// Memory optimization strategies
const optimizeMemory = () => {
  // 1. Limit cache size
  const cache = new NodeCache({
    maxKeys: 100, // Limit cached items
    stdTTL: 300,
    checkperiod: 60,
    deleteOnExpire: true,
  });
  
  // 2. Database connection pooling
  const pool = mysql.createPool({
    connectionLimit: 3, // Reduced for memory
    queueLimit: 5,
    idleTimeout: 300000,
    maxIdle: 1,
  });
  
  // 3. Implement memory cleanup
  const cleanup = () => {
    if (global.gc) {
      global.gc();
      console.log('Garbage collection triggered');
    }
  };
  
  setInterval(cleanup, 60000); // Every minute
  
  // 4. Monitor and limit request payload
  app.use(json({ limit: '1mb' }));
  app.use(urlencoded({ extended: true, limit: '1mb' }));
};
```

### 6. Service Communication Issues

#### Service Discovery Problems

**Problem**: Services cannot communicate with each other
```
Error: ENOTFOUND your-api-service.railway.app
```

**Solution**:
```bash
# 1. Use Railway's internal service communication
# Services in the same project can communicate using service names
# Instead of: https://your-api-service.railway.app
# Use: http://api:3333 (where 'api' is the service name)

# 2. Set internal service URLs
railway variables set INTERNAL_API_URL=http://api:3333 --service web

# 3. Update service configuration
```

```typescript
// Environment-aware API URL configuration
const getApiUrl = () => {
  // Use internal URL for service-to-service communication
  if (process.env.RAILWAY_ENVIRONMENT) {
    return process.env.INTERNAL_API_URL || 'http://api:3333';
  }
  
  // Use external URL for development
  return process.env.VITE_API_URL || 'http://localhost:3333';
};

export const API_BASE_URL = getApiUrl();
```

#### Load Balancing Issues

**Problem**: Inconsistent responses from replicated services
```
Intermittent 502 Bad Gateway errors
```

**Solution**:
```typescript
// Health check endpoint for load balancer
app.get('/health', async (req, res) => {
  try {
    // Check all critical dependencies
    const checks = await Promise.all([
      checkDatabase(),
      checkCache(),
      checkExternalServices(),
    ]);
    
    const allHealthy = checks.every(check => check.healthy);
    
    res.status(allHealthy ? 200 : 503).json({
      status: allHealthy ? 'healthy' : 'unhealthy',
      checks: checks,
      timestamp: new Date().toISOString(),
      instance: process.env.RAILWAY_REPLICA_ID || 'unknown',
    });
  } catch (error) {
    res.status(503).json({
      status: 'unhealthy',
      error: error.message,
      timestamp: new Date().toISOString(),
    });
  }
});

// Graceful degradation
const checkDatabase = async () => {
  try {
    await pool.execute('SELECT 1');
    return { service: 'database', healthy: true };
  } catch (error) {
    return { service: 'database', healthy: false, error: error.message };
  }
};
```

## Debugging Strategies

### 1. Logging and Monitoring

#### Comprehensive Logging Setup

```typescript
import winston from 'winston';

// Railway-optimized logger
const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json(),
    winston.format.printf(({ timestamp, level, message, ...meta }) => {
      return JSON.stringify({
        timestamp,
        level,
        message,
        service: process.env.RAILWAY_SERVICE_NAME || 'unknown',
        environment: process.env.RAILWAY_ENVIRONMENT || 'development',
        replica: process.env.RAILWAY_REPLICA_ID || 'unknown',
        ...meta
      });
    })
  ),
  transports: [
    new winston.transports.Console(),
  ],
});

// Request logging with correlation IDs
export const requestLogger = (req, res, next) => {
  req.id = req.headers['x-request-id'] || require('uuid').v4();
  req.startTime = Date.now();
  
  logger.info({
    type: 'request',
    requestId: req.id,
    method: req.method,
    url: req.url,
    userAgent: req.headers['user-agent'],
    ip: req.ip,
  });
  
  res.on('finish', () => {
    const duration = Date.now() - req.startTime;
    
    logger.info({
      type: 'response',
      requestId: req.id,
      method: req.method,
      url: req.url,
      statusCode: res.statusCode,
      duration: `${duration}ms`,
    });
  });
  
  next();
};
```

#### Railway Logs Analysis

```bash
# Real-time log monitoring
railway logs --follow --service api

# Filter logs by level
railway logs --service api | grep ERROR

# Search for specific patterns
railway logs --service api | grep "database connection"

# Export logs for analysis
railway logs --service api --start "2024-01-01" --end "2024-01-02" > logs.txt
```

### 2. Health Checks and Monitoring

#### Comprehensive Health Checks

```typescript
// Multi-layer health check system
class HealthChecker {
  private checks: Map<string, () => Promise<HealthCheckResult>> = new Map();

  register(name: string, check: () => Promise<HealthCheckResult>) {
    this.checks.set(name, check);
  }

  async runAll(): Promise<HealthCheckReport> {
    const results = new Map<string, HealthCheckResult>();
    
    for (const [name, check] of this.checks) {
      try {
        const result = await Promise.race([
          check(),
          this.timeout(5000) // 5 second timeout
        ]);
        results.set(name, result);
      } catch (error) {
        results.set(name, {
          healthy: false,
          message: error.message,
          duration: 0,
        });
      }
    }
    
    const allHealthy = Array.from(results.values()).every(r => r.healthy);
    
    return {
      status: allHealthy ? 'healthy' : 'unhealthy',
      checks: Object.fromEntries(results),
      timestamp: new Date().toISOString(),
    };
  }

  private async timeout(ms: number): Promise<HealthCheckResult> {
    await new Promise((_, reject) => 
      setTimeout(() => reject(new Error('Health check timeout')), ms)
    );
    return { healthy: false, message: 'timeout', duration: ms };
  }
}

const healthChecker = new HealthChecker();

// Register health checks
healthChecker.register('database', async () => {
  const start = Date.now();
  try {
    await pool.execute('SELECT 1');
    return {
      healthy: true,
      message: 'Connected',
      duration: Date.now() - start,
    };
  } catch (error) {
    return {
      healthy: false,
      message: error.message,
      duration: Date.now() - start,
    };
  }
});

healthChecker.register('cache', async () => {
  const start = Date.now();
  try {
    cache.set('health-check', 'ok', 1);
    const value = cache.get('health-check');
    return {
      healthy: value === 'ok',
      message: value === 'ok' ? 'Working' : 'Failed to read/write',
      duration: Date.now() - start,
    };
  } catch (error) {
    return {
      healthy: false,
      message: error.message,
      duration: Date.now() - start,
    };
  }
});

// Health check endpoint
app.get('/health', async (req, res) => {
  const report = await healthChecker.runAll();
  res.status(report.status === 'healthy' ? 200 : 503).json(report);
});
```

### 3. Performance Debugging

#### Request Performance Analysis

```typescript
// Performance monitoring middleware
export const performanceMonitor = (req, res, next) => {
  const start = process.hrtime.bigint();
  
  // Track memory at request start
  const memStart = process.memoryUsage();
  
  res.on('finish', () => {
    const end = process.hrtime.bigint();
    const duration = Number(end - start) / 1000000; // Convert to ms
    const memEnd = process.memoryUsage();
    
    const performanceData = {
      requestId: req.id,
      method: req.method,
      url: req.url,
      statusCode: res.statusCode,
      duration: `${duration.toFixed(2)}ms`,
      memory: {
        heapUsedDelta: `${((memEnd.heapUsed - memStart.heapUsed) / 1024 / 1024).toFixed(2)}MB`,
        heapUsed: `${(memEnd.heapUsed / 1024 / 1024).toFixed(2)}MB`,
      },
    };
    
    // Log slow requests
    if (duration > 1000) {
      logger.warn({
        ...performanceData,
        type: 'slow-request',
      });
    } else {
      logger.debug({
        ...performanceData,
        type: 'request-performance',
      });
    }
  });
  
  next();
};

// Database query performance tracking
export const trackQuery = (query: string, params?: any[]) => {
  return async (executor: Function) => {
    const start = process.hrtime.bigint();
    
    try {
      const result = await executor();
      const end = process.hrtime.bigint();
      const duration = Number(end - start) / 1000000;
      
      if (duration > 500) { // Log slow queries (>500ms)
        logger.warn({
          type: 'slow-query',
          query: query.substring(0, 100) + '...',
          duration: `${duration.toFixed(2)}ms`,
          params: params?.length || 0,
        });
      }
      
      return result;
    } catch (error) {
      logger.error({
        type: 'query-error',
        query: query.substring(0, 100) + '...',
        error: error.message,
      });
      throw error;
    }
  };
};
```

## Recovery Procedures

### 1. Service Recovery

#### Automatic Service Recovery

```bash
# Railway automatic restart configuration
# In railway.json:
{
  "deploy": {
    "restartPolicyType": "ON_FAILURE",
    "restartPolicyMaxRetries": 3,
    "healthcheckPath": "/health",
    "healthcheckTimeout": 30
  }
}
```

#### Manual Recovery Steps

```bash
# 1. Check service status
railway status

# 2. View recent logs
railway logs --service api --tail 100

# 3. Restart service
railway service restart api

# 4. If restart fails, redeploy
railway up --service api

# 5. Scale down and up if needed
railway service scale api 0
railway service scale api 1

# 6. Check health after recovery
curl https://your-api-service.railway.app/health
```

### 2. Database Recovery

#### Database Connection Recovery

```typescript
// Database recovery utility
class DatabaseRecovery {
  private pool: mysql.Pool;
  private isRecovering = false;

  constructor(pool: mysql.Pool) {
    this.pool = pool;
    this.setupRecovery();
  }

  private setupRecovery() {
    this.pool.on('error', async (error) => {
      console.error('Database pool error:', error);
      
      if (this.shouldRecover(error)) {
        await this.recover();
      }
    });
  }

  private shouldRecover(error: any): boolean {
    const recoverableErrors = [
      'PROTOCOL_CONNECTION_LOST',
      'ECONNRESET',
      'ETIMEDOUT',
      'ENOTFOUND',
    ];
    
    return recoverableErrors.includes(error.code);
  }

  private async recover() {
    if (this.isRecovering) return;
    
    this.isRecovering = true;
    console.log('Starting database recovery...');
    
    try {
      // Wait before attempting recovery
      await new Promise(resolve => setTimeout(resolve, 5000));
      
      // Test connection
      const testConnection = await mysql.createConnection({
        host: process.env.MYSQLHOST,
        port: parseInt(process.env.MYSQLPORT || '3306'),
        user: process.env.MYSQLUSER,
        password: process.env.MYSQLPASSWORD,
        database: process.env.MYSQLDATABASE,
        ssl: { rejectUnauthorized: false },
      });
      
      await testConnection.ping();
      await testConnection.end();
      
      console.log('Database recovery successful');
    } catch (error) {
      console.error('Database recovery failed:', error);
      
      // Exponential backoff for retry
      setTimeout(() => this.recover(), 30000);
    } finally {
      this.isRecovering = false;
    }
  }
}

// Initialize recovery
const dbRecovery = new DatabaseRecovery(pool);
```

#### Data Recovery and Backup

```bash
# Railway database backup procedures
# 1. Create manual backup
railway db backup create --database mysql

# 2. List available backups
railway db backup list

# 3. Restore from backup
railway db backup restore <backup-id>

# 4. Export data for manual backup
railway connect mysql
mysqldump -h $MYSQLHOST -P $MYSQLPORT -u $MYSQLUSER -p$MYSQLPASSWORD $MYSQLDATABASE > backup.sql

# 5. Import data
mysql -h $MYSQLHOST -P $MYSQLPORT -u $MYSQLUSER -p$MYSQLPASSWORD $MYSQLDATABASE < backup.sql
```

### 3. Application State Recovery

#### Stateless Application Design

```typescript
// Design for stateless operation
class StatelessService {
  // Avoid in-memory state
  // Use database or cache for persistent state
  
  async getSessionData(sessionId: string) {
    // Get from database, not memory
    return await db.execute(
      'SELECT data FROM sessions WHERE id = ?',
      [sessionId]
    );
  }
  
  async setSessionData(sessionId: string, data: any) {
    // Store in database, not memory
    return await db.execute(
      'INSERT INTO sessions (id, data) VALUES (?, ?) ON DUPLICATE KEY UPDATE data = ?',
      [sessionId, JSON.stringify(data), JSON.stringify(data)]
    );
  }
}

// Circuit breaker pattern for external dependencies
class CircuitBreaker {
  private failures = 0;
  private lastFailureTime = 0;
  private state: 'CLOSED' | 'OPEN' | 'HALF_OPEN' = 'CLOSED';
  
  constructor(
    private maxFailures = 5,
    private timeout = 60000 // 1 minute
  ) {}
  
  async execute<T>(operation: () => Promise<T>): Promise<T> {
    if (this.state === 'OPEN') {
      if (Date.now() - this.lastFailureTime > this.timeout) {
        this.state = 'HALF_OPEN';
      } else {
        throw new Error('Circuit breaker is OPEN');
      }
    }
    
    try {
      const result = await operation();
      this.onSuccess();
      return result;
    } catch (error) {
      this.onFailure();
      throw error;
    }
  }
  
  private onSuccess() {
    this.failures = 0;
    this.state = 'CLOSED';
  }
  
  private onFailure() {
    this.failures++;
    this.lastFailureTime = Date.now();
    
    if (this.failures >= this.maxFailures) {
      this.state = 'OPEN';
    }
  }
}
```

## Prevention Strategies

### 1. Proactive Monitoring

#### Alerting System

```typescript
// Alert configuration
const alerts = {
  highMemoryUsage: {
    threshold: 400 * 1024 * 1024, // 400MB
    interval: 60000, // Check every minute
  },
  slowRequests: {
    threshold: 2000, // 2 seconds
    interval: 30000,
  },
  databaseConnections: {
    threshold: 8, // Alert if >8 connections
    interval: 120000,
  },
};

// Monitoring service
class MonitoringService {
  private alerts: Map<string, any> = new Map();
  
  startMonitoring() {
    this.monitorMemory();
    this.monitorDatabase();
    this.monitorRequests();
  }
  
  private monitorMemory() {
    setInterval(() => {
      const usage = process.memoryUsage();
      
      if (usage.heapUsed > alerts.highMemoryUsage.threshold) {
        this.sendAlert('high-memory', {
          current: `${(usage.heapUsed / 1024 / 1024).toFixed(2)}MB`,
          threshold: `${(alerts.highMemoryUsage.threshold / 1024 / 1024).toFixed(2)}MB`,
        });
      }
    }, alerts.highMemoryUsage.interval);
  }
  
  private async monitorDatabase() {
    setInterval(async () => {
      try {
        const [rows] = await pool.execute('SHOW STATUS LIKE "Threads_connected"');
        const connections = parseInt(rows[0].Value);
        
        if (connections > alerts.databaseConnections.threshold) {
          this.sendAlert('high-db-connections', {
            current: connections,
            threshold: alerts.databaseConnections.threshold,
          });
        }
      } catch (error) {
        console.error('Database monitoring failed:', error);
      }
    }, alerts.databaseConnections.interval);
  }
  
  private sendAlert(type: string, data: any) {
    const alertKey = `${type}-${Date.now()}`;
    
    if (!this.alerts.has(alertKey)) {
      logger.error({
        type: 'alert',
        alertType: type,
        data,
        timestamp: new Date().toISOString(),
      });
      
      this.alerts.set(alertKey, data);
      
      // Clean up old alerts
      setTimeout(() => this.alerts.delete(alertKey), 300000); // 5 minutes
    }
  }
}

const monitoring = new MonitoringService();
monitoring.startMonitoring();
```

### 2. Testing and Validation

#### Pre-deployment Testing

```bash
#!/bin/bash
# pre-deploy-test.sh - Comprehensive testing before deployment

set -e

echo "🧪 Running pre-deployment tests..."

# 1. Unit tests
echo "📋 Running unit tests..."
npx nx test api --coverage
npx nx test web --coverage

# 2. Integration tests
echo "🔗 Running integration tests..."
npx nx e2e web-e2e

# 3. Build verification
echo "🏗️  Verifying builds..."
npx nx build api --prod
npx nx build web --prod

# 4. Database migration test
echo "🗄️  Testing database migrations..."
npm run db:migrate:test

# 5. Health check simulation
echo "❤️  Testing health endpoints..."
npm run test:health

# 6. Load testing (basic)
echo "⚡ Running basic load tests..."
npm run test:load

echo "✅ All pre-deployment tests passed!"
```

#### Production Readiness Checklist

```typescript
// Production readiness validator
class ProductionReadinessChecker {
  private checks: Array<{ name: string; check: () => boolean | Promise<boolean> }> = [];

  constructor() {
    this.registerChecks();
  }

  private registerChecks() {
    this.checks = [
      {
        name: 'Environment Variables',
        check: () => this.checkEnvironmentVariables(),
      },
      {
        name: 'Database Connection',
        check: () => this.checkDatabaseConnection(),
      },
      {
        name: 'Health Endpoints',
        check: () => this.checkHealthEndpoints(),
      },
      {
        name: 'Security Headers',
        check: () => this.checkSecurityHeaders(),
      },
      {
        name: 'Error Handling',
        check: () => this.checkErrorHandling(),
      },
    ];
  }

  async runAllChecks(): Promise<void> {
    console.log('🚀 Running production readiness checks...');
    
    for (const { name, check } of this.checks) {
      try {
        const result = await check();
        if (result) {
          console.log(`✅ ${name}: PASS`);
        } else {
          console.error(`❌ ${name}: FAIL`);
          process.exit(1);
        }
      } catch (error) {
        console.error(`❌ ${name}: ERROR - ${error.message}`);
        process.exit(1);
      }
    }
    
    console.log('🎉 All production readiness checks passed!');
  }

  private checkEnvironmentVariables(): boolean {
    const required = ['DATABASE_URL', 'JWT_SECRET', 'NODE_ENV'];
    const missing = required.filter(name => !process.env[name]);
    
    if (missing.length > 0) {
      console.error(`Missing environment variables: ${missing.join(', ')}`);
      return false;
    }
    
    return true;
  }

  private async checkDatabaseConnection(): Promise<boolean> {
    try {
      await pool.execute('SELECT 1');
      return true;
    } catch (error) {
      console.error(`Database connection failed: ${error.message}`);
      return false;
    }
  }

  private checkHealthEndpoints(): boolean {
    // Verify health endpoints are configured
    return app._router && app._router.stack.some(layer => 
      layer.route && layer.route.path === '/health'
    );
  }

  private checkSecurityHeaders(): boolean {
    // Verify security middleware is configured
    // This is a simplified check
    return !!app._router;
  }

  private checkErrorHandling(): boolean {
    // Verify error handling middleware is configured
    return app._router && app._router.stack.some(layer => 
      layer.handle && layer.handle.length === 4 // Error middleware has 4 params
    );
  }
}

// Run checks on startup in production
if (process.env.NODE_ENV === 'production') {
  const readinessChecker = new ProductionReadinessChecker();
  readinessChecker.runAllChecks();
}
```

---

## Emergency Contacts and Resources

### Railway Support Channels
- **Railway Discord**: [discord.gg/railway](https://discord.gg/railway)
- **Railway Documentation**: [docs.railway.app](https://docs.railway.app)
- **Railway Status Page**: [status.railway.app](https://status.railway.app)
- **Railway GitHub Issues**: [github.com/railwayapp/railway](https://github.com/railwayapp/railway)

### Useful Commands Quick Reference

```bash
# Service Management
railway status                          # Check all services status
railway logs --service api --follow     # Real-time logs
railway service restart api             # Restart specific service
railway up --service api               # Redeploy service

# Database Management
railway connect mysql                   # Connect to database
railway db backup create               # Create backup
railway db backup list                 # List backups
railway db backup restore <id>         # Restore backup

# Environment Management
railway variables                       # List all variables
railway variables set KEY=value         # Set variable
railway environment switch production   # Switch environment

# Debugging
railway shell                          # Access service shell
railway run npm run debug              # Run debug command
```

### Escalation Procedures

1. **Level 1**: Check Railway status page and documentation
2. **Level 2**: Search Railway Discord for similar issues
3. **Level 3**: Create detailed issue in Railway Discord #help channel
4. **Level 4**: For Pro plan users, contact Railway support directly

---

## Additional Resources

- [Railway Troubleshooting Guide](https://docs.railway.app/troubleshoot/fixing-common-errors)
- [Node.js Debugging Guide](https://nodejs.org/en/docs/guides/debugging-getting-started/)
- [MySQL Error Codes Reference](https://dev.mysql.com/doc/mysql-errors/8.0/en/)
- [Express.js Error Handling](https://expressjs.com/en/guide/error-handling.html)

---

← [Back to Best Practices](./best-practices.md) | [Next: README](./README.md) →