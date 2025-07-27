# Troubleshooting Guide: Railway.com Deployment Issues

## 🎯 Overview

This comprehensive troubleshooting guide covers common issues encountered when deploying applications to Railway.com, with specific solutions for Nx monorepos and clinic management systems.

## 🚨 Common Deployment Issues

### 1. Build Failures

#### Issue: Nx Build Command Not Found
```bash
Error: npm ERR! missing script: build
Error: Command failed: npm run build
```

**Root Cause:** Railway trying to run generic build commands instead of Nx-specific commands.

**Solution:**
```toml
# railway.toml
[build]
builder = "nixpacks"
buildCommand = "npx nx build api --prod"  # Specify exact Nx command

# Alternative: Use package.json scripts
```

```json
// package.json
{
  "scripts": {
    "build": "nx build api --prod",
    "build:web": "nx build web --prod",
    "build:api": "nx build api --prod"
  }
}
```

#### Issue: Out of Memory During Build
```bash
Error: JavaScript heap out of memory
Error: Build failed with exit code 137
```

**Root Cause:** Insufficient memory allocated for build process.

**Solution:**
```bash
# Increase Node.js memory limit
export NODE_OPTIONS="--max-old-space-size=4096"

# Or in package.json
{
  "scripts": {
    "build": "node --max-old-space-size=4096 ./node_modules/.bin/nx build api --prod"
  }
}
```

```toml
# railway.toml - Request more build resources
[build]
builder = "nixpacks"
buildCommand = "NODE_OPTIONS='--max-old-space-size=4096' npx nx build api --prod"
```

#### Issue: Missing Dependencies
```bash
Error: Cannot find module '@clinic/shared/types'
Error: Module not found: Can't resolve 'libs/shared/utils'
```

**Root Cause:** Nx workspace path resolution not working in Railway environment.

**Solution:**
```typescript
// tsconfig.base.json - Ensure proper path mapping
{
  "compilerOptions": {
    "paths": {
      "@clinic/shared/types": ["libs/shared/types/src/index.ts"],
      "@clinic/shared/utils": ["libs/shared/utils/src/index.ts"],
      "@clinic/shared/database": ["libs/shared/database/src/index.ts"]
    }
  }
}
```

```json
// Ensure all workspace dependencies are in package.json
{
  "dependencies": {
    "@clinic/shared": "workspace:*"
  }
}
```

### 2. Runtime Errors

#### Issue: Database Connection Failed
```bash
Error: connect ECONNREFUSED
Error: ER_ACCESS_DENIED_ERROR: Access denied for user
```

**Root Cause:** Incorrect database connection configuration.

**Debugging Steps:**
```bash
# Check environment variables
railway shell --service api
echo $DATABASE_URL
echo $DB_HOST
echo $DB_USER

# Test database connectivity
railway run --service api node -e "
const mysql = require('mysql2/promise');
mysql.createConnection(process.env.DATABASE_URL)
  .then(() => console.log('Connected!'))
  .catch(err => console.error('Failed:', err.message));
"
```

**Solution:**
```typescript
// Enhanced connection with better error handling
import mysql from 'mysql2/promise';

const createConnection = async (retries = 3): Promise<mysql.Connection> => {
  for (let i = 0; i < retries; i++) {
    try {
      const connection = await mysql.createConnection({
        uri: process.env.DATABASE_URL,
        connectTimeout: 60000,
        acquireTimeout: 60000,
        timeout: 60000,
        reconnect: true,
        ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false
      });
      
      // Test connection
      await connection.ping();
      return connection;
      
    } catch (error) {
      console.error(`Database connection attempt ${i + 1} failed:`, error.message);
      
      if (i === retries - 1) throw error;
      
      // Wait before retry
      await new Promise(resolve => setTimeout(resolve, 2000 * (i + 1)));
    }
  }
  
  throw new Error('Failed to connect after retries');
};
```

#### Issue: Port Binding Error
```bash
Error: listen EADDRINUSE: address already in use :::3000
Error: Error: listen EADDRINUSE :::8080
```

**Root Cause:** Application not using Railway's dynamic port assignment.

**Solution:**
```typescript
// apps/api/src/main.ts
const PORT = process.env.PORT || 8080; // Railway sets PORT automatically

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server running on port ${PORT}`);
});

// NOT this (will fail):
// app.listen(8080, 'localhost', ...);
```

```toml
# railway.toml
[deploy]
startCommand = "node dist/apps/api/main.js"
# Don't specify port in start command
```

#### Issue: Environment Variable Not Accessible
```bash
Error: JWT_SECRET is not defined
Error: Cannot read property 'DATABASE_URL' of undefined
```

**Root Cause:** Environment variables not properly set or accessed.

**Debugging:**
```bash
# List all variables for service
railway variables --service api

# Check specific variable
railway variables get JWT_SECRET --service api

# Debug in runtime
railway shell --service api
printenv | grep -E "(DATABASE|JWT|CORS)"
```

**Solution:**
```typescript
// Validate environment variables at startup
const requiredEnvVars = [
  'DATABASE_URL',
  'JWT_SECRET',
  'CORS_ORIGIN'
];

const missingVars = requiredEnvVars.filter(envVar => !process.env[envVar]);

if (missingVars.length > 0) {
  console.error('Missing required environment variables:', missingVars);
  process.exit(1);
}
```

### 3. Service Communication Issues

#### Issue: Frontend Cannot Reach Backend
```bash
Error: Failed to fetch
Error: net::ERR_CONNECTION_REFUSED
```

**Root Cause:** Incorrect API URL configuration or CORS issues.

**Debugging:**
```bash
# Check service URLs
railway status

# Verify API service is responding
curl https://your-api-service.railway.app/health

# Check frontend environment variables
railway variables get VITE_API_URL --service web
```

**Solution:**
```bash
# Set correct API URL for frontend
railway variables set VITE_API_URL=https://${{api.RAILWAY_PUBLIC_DOMAIN}} --service web

# Configure CORS on backend
railway variables set CORS_ORIGIN=https://${{web.RAILWAY_PUBLIC_DOMAIN}} --service api
```

```typescript
// apps/api/src/main.ts
import cors from 'cors';

app.use(cors({
  origin: process.env.CORS_ORIGIN?.split(',') || ['http://localhost:3000'],
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));
```

#### Issue: Database Service Unreachable
```bash
Error: getaddrinfo ENOTFOUND mysql.railway.internal
Error: Connection lost: The server closed the connection
```

**Root Cause:** Database service not properly connected or misconfigured.

**Solution:**
```bash
# Recreate database service if corrupted
railway service delete mysql
railway service create mysql

# Update database URL in API service
railway variables set DATABASE_URL=${{MySQL.DATABASE_URL}} --service api

# Verify connection string format
railway variables get DATABASE_URL --service mysql
```

## 🔧 Performance Issues

### 1. Slow Response Times

#### Issue: High API Response Times
```bash
Warning: Response time >1000ms
Error: Request timeout after 30s
```

**Debugging:**
```typescript
// Add performance monitoring
import { performance } from 'perf_hooks';

app.use((req, res, next) => {
  const start = performance.now();
  
  res.on('finish', () => {
    const duration = performance.now() - start;
    if (duration > 1000) {
      console.warn(`Slow request: ${req.method} ${req.path} - ${duration.toFixed(2)}ms`);
    }
  });
  
  next();
});

// Monitor database query performance
const originalQuery = db.query;
db.query = async function(sql, params) {
  const start = performance.now();
  const result = await originalQuery.call(this, sql, params);
  const duration = performance.now() - start;
  
  if (duration > 500) {
    console.warn(`Slow query (${duration.toFixed(2)}ms):`, sql);
  }
  
  return result;
};
```

**Solutions:**
```typescript
// 1. Implement connection pooling
const pool = mysql.createPool({
  uri: process.env.DATABASE_URL,
  connectionLimit: 10,
  queueLimit: 0,
  acquireTimeout: 60000,
  timeout: 60000
});

// 2. Add query caching
const cache = new NodeCache({ stdTTL: 300 });

const getCachedPatients = async (doctorId: number) => {
  const cacheKey = `patients_${doctorId}`;
  let patients = cache.get(cacheKey);
  
  if (!patients) {
    patients = await db.query('SELECT * FROM patients WHERE doctor_id = ?', [doctorId]);
    cache.set(cacheKey, patients);
  }
  
  return patients;
};

// 3. Optimize database queries
// Before: N+1 query problem
const patients = await db.query('SELECT * FROM patients');
for (const patient of patients) {
  const appointments = await db.query('SELECT * FROM appointments WHERE patient_id = ?', [patient.id]);
  patient.appointments = appointments;
}

// After: Single query with JOIN
const patientsWithAppointments = await db.query(`
  SELECT 
    p.*,
    a.id as appointment_id,
    a.scheduled_at,
    a.status
  FROM patients p
  LEFT JOIN appointments a ON p.id = a.patient_id
  WHERE p.doctor_id = ?
`, [doctorId]);
```

### 2. High Memory Usage

#### Issue: Memory Leaks and High Consumption
```bash
Warning: Heap size exceeded 500MB
Error: JavaScript heap out of memory
```

**Debugging:**
```typescript
// Memory monitoring
setInterval(() => {
  const usage = process.memoryUsage();
  const memoryUsageMB = {
    rss: Math.round(usage.rss / 1024 / 1024),
    heapTotal: Math.round(usage.heapTotal / 1024 / 1024),
    heapUsed: Math.round(usage.heapUsed / 1024 / 1024),
    external: Math.round(usage.external / 1024 / 1024)
  };
  
  console.log('Memory usage:', memoryUsageMB);
  
  // Alert if memory usage is high
  if (memoryUsageMB.heapUsed > 400) {
    console.warn('High memory usage detected');
    
    // Force garbage collection if available
    if (global.gc) {
      global.gc();
    }
  }
}, 60000); // Check every minute
```

**Solutions:**
```typescript
// 1. Proper connection cleanup
const handleGracefulShutdown = () => {
  console.log('Shutting down gracefully...');
  
  // Close database connections
  db.end();
  
  // Clear cache
  cache.flushAll();
  
  // Close server
  server.close(() => {
    console.log('Server closed');
    process.exit(0);
  });
};

process.on('SIGTERM', handleGracefulShutdown);
process.on('SIGINT', handleGracefulShutdown);

// 2. Limit response data size
app.get('/api/patients', async (req, res) => {
  const page = parseInt(req.query.page) || 1;
  const limit = Math.min(parseInt(req.query.limit) || 20, 100); // Max 100 records
  const offset = (page - 1) * limit;
  
  const patients = await db.query(
    'SELECT * FROM patients LIMIT ? OFFSET ?',
    [limit, offset]
  );
  
  res.json({
    data: patients,
    pagination: { page, limit, total: patients.length }
  });
});

// 3. Stream large responses
app.get('/api/export/patients', (req, res) => {
  res.setHeader('Content-Type', 'application/json');
  res.write('[');
  
  let isFirst = true;
  const stream = db.queryStream('SELECT * FROM patients');
  
  stream.on('data', (row) => {
    if (!isFirst) res.write(',');
    res.write(JSON.stringify(row));
    isFirst = false;
  });
  
  stream.on('end', () => {
    res.write(']');
    res.end();
  });
  
  stream.on('error', (error) => {
    res.status(500).json({ error: error.message });
  });
});
```

## 📊 Monitoring & Debugging

### 1. Enhanced Logging

```typescript
// Enhanced logging setup
import winston from 'winston';

const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  defaultMeta: {
    service: 'clinic-api',
    environment: process.env.NODE_ENV,
    railway: {
      projectId: process.env.RAILWAY_PROJECT_ID,
      serviceId: process.env.RAILWAY_SERVICE_ID,
      deploymentId: process.env.RAILWAY_DEPLOYMENT_ID
    }
  },
  transports: [
    new winston.transports.Console()
  ]
});

// Request logging middleware
app.use((req, res, next) => {
  const startTime = Date.now();
  
  res.on('finish', () => {
    const duration = Date.now() - startTime;
    
    logger.info('HTTP Request', {
      method: req.method,
      url: req.url,
      statusCode: res.statusCode,
      duration: `${duration}ms`,
      userAgent: req.get('User-Agent'),
      ip: req.ip,
      userId: req.user?.userId
    });
  });
  
  next();
});

// Database query logging
const logQuery = (sql: string, params: any[], duration: number) => {
  logger.debug('Database Query', {
    sql: sql.replace(/\s+/g, ' ').trim(),
    params,
    duration: `${duration.toFixed(2)}ms`
  });
};
```

### 2. Health Monitoring

```typescript
// Comprehensive health check
export class HealthMonitor {
  private checks = new Map<string, () => Promise<boolean>>();
  
  constructor() {
    this.registerCheck('database', this.checkDatabase);
    this.registerCheck('memory', this.checkMemory);
    this.registerCheck('disk', this.checkDisk);
  }
  
  registerCheck(name: string, check: () => Promise<boolean>) {
    this.checks.set(name, check);
  }
  
  async runHealthChecks(): Promise<{ status: string; checks: Record<string, boolean> }> {
    const results: Record<string, boolean> = {};
    
    for (const [name, check] of this.checks) {
      try {
        results[name] = await Promise.race([
          check(),
          new Promise<boolean>((_, reject) => 
            setTimeout(() => reject(new Error('Timeout')), 5000)
          )
        ]);
      } catch (error) {
        logger.error(`Health check failed: ${name}`, error);
        results[name] = false;
      }
    }
    
    const allHealthy = Object.values(results).every(Boolean);
    const status = allHealthy ? 'healthy' : 'unhealthy';
    
    return { status, checks: results };
  }
  
  private async checkDatabase(): Promise<boolean> {
    try {
      await db.query('SELECT 1');
      return true;
    } catch {
      return false;
    }
  }
  
  private async checkMemory(): Promise<boolean> {
    const usage = process.memoryUsage();
    const memoryUsagePercent = (usage.heapUsed / usage.heapTotal) * 100;
    return memoryUsagePercent < 90; // Alert if using >90% of heap
  }
  
  private async checkDisk(): Promise<boolean> {
    // Simplified disk check - implement based on your needs
    return true;
  }
}
```

## 🔍 Railway-Specific Debugging

### 1. CLI Debugging Commands

```bash
# View service status
railway status

# Check recent deployments
railway deployment list

# View real-time logs
railway logs --service api --follow

# Check environment variables
railway variables --service api

# Debug specific deployment
railway logs --deployment <deployment-id>

# Connect to service shell
railway shell --service api

# Run one-off commands
railway run --service api npm run migrate

# Check resource usage
railway usage

# View service metrics
railway metrics --service api
```

### 2. Environment Debugging

```bash
# Debug script for Railway environment
#!/bin/bash

echo "=== Railway Environment Debug ==="
echo "Project ID: $RAILWAY_PROJECT_ID"
echo "Service ID: $RAILWAY_SERVICE_ID"
echo "Environment: $RAILWAY_ENVIRONMENT"
echo "Git Commit: $RAILWAY_GIT_COMMIT_SHA"

echo -e "\n=== Node.js Environment ==="
echo "Node Version: $(node --version)"
echo "NPM Version: $(npm --version)"
echo "Platform: $(node -p 'process.platform')"
echo "Architecture: $(node -p 'process.arch')"

echo -e "\n=== Environment Variables ==="
printenv | grep -E "(DATABASE|JWT|CORS|NODE_ENV)" | sort

echo -e "\n=== Network Connectivity ==="
ping -c 3 google.com || echo "External connectivity: FAILED"

echo -e "\n=== Disk Space ==="
df -h

echo -e "\n=== Memory Usage ==="
free -h 2>/dev/null || echo "Memory info not available"

echo -e "\n=== Process Information ==="
ps aux | head -20
```

### 3. Common Railway Issues

#### Issue: Deployment Stuck in "Building" State
```bash
# Check build logs
railway logs --deployment <deployment-id>

# Cancel stuck deployment
railway deployment cancel <deployment-id>

# Redeploy
railway up --service api
```

#### Issue: Service Not Starting After Deployment
```bash
# Check start command
railway variables get RAILWAY_START_COMMAND --service api

# Verify build output
railway shell --service api
ls -la dist/apps/api/

# Test start command manually
railway run --service api node dist/apps/api/main.js
```

#### Issue: Domain/URL Issues
```bash
# Check service URL
railway status

# Force regenerate URL
railway domain

# Check DNS propagation
nslookup your-service.railway.app
```

## 🚨 Emergency Recovery Procedures

### 1. Service Recovery

```bash
# 1. Identify failing service
railway status

# 2. Check recent logs for errors
railway logs --service api | tail -100

# 3. Rollback to previous deployment if needed
railway deployment list
railway deployment rollback <previous-deployment-id>

# 4. If rollback fails, force restart
railway service restart api

# 5. Scale down and up if issues persist
railway scale --service api --replicas 0
railway scale --service api --replicas 1
```

### 2. Database Recovery

```bash
# 1. Check database connectivity
railway run --service api -- node -e "
  require('mysql2/promise')
    .createConnection(process.env.DATABASE_URL)
    .then(() => console.log('DB OK'))
    .catch(e => console.error('DB FAIL:', e.message))
"

# 2. If database is corrupted, restore from backup
railway backups list --service mysql
railway backups restore <backup-id> --service mysql

# 3. Run database health check
railway run --service api -- npm run db:health
```

### 3. Complete Environment Recovery

```bash
# Nuclear option: Recreate entire environment
railway project create clinic-recovery

# Recreate services
railway service create web
railway service create api  
railway service create mysql

# Restore configuration
railway variables import production-vars.json

# Deploy fresh code
railway up --service web --service api

# Migrate data
railway run --service api -- npm run migrate
```

---

## 🔗 Navigation

**← Previous:** [Best Practices](./best-practices.md) | **Next:** [README](./README.md) →

---

## 📚 Additional Resources

- [Railway Documentation](https://docs.railway.app/)
- [Railway Status Page](https://status.railway.app/)
- [Railway Discord Community](https://discord.gg/railway)
- [Node.js Debugging Guide](https://nodejs.org/en/docs/guides/debugging-getting-started/)