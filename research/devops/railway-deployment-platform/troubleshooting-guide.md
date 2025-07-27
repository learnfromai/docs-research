# Railway.com Troubleshooting Guide

## 🔧 Common Issues and Solutions

This guide covers common problems encountered when deploying applications on Railway.com, with specific focus on Nx monorepos, healthcare applications, and multi-service architectures.

## 🚀 Deployment Issues

### Build Failures

#### Issue: Nx Build Command Not Found
```bash
# Error message:
# "nx: command not found" during build process
```

**Solutions:**
```bash
# Solution 1: Add Nx CLI to dependencies
npm install --save-dev @nrwl/cli

# Solution 2: Use npx in build commands
# In Railway service settings:
BUILD_COMMAND="npx nx build api"
START_COMMAND="node dist/apps/api/main.js"

# Solution 3: Add to package.json scripts
{
  "scripts": {
    "build:api": "nx build api",
    "build:web": "nx build web",
    "start:api": "node dist/apps/api/main.js"
  }
}
```

#### Issue: Build Timeout
```bash
# Error: Build process times out after 10-15 minutes
```

**Solutions:**
```typescript
const buildOptimization = {
  // 1. Optimize package.json dependencies
  removeUnused: "Remove unused dependencies to reduce install time",
  
  // 2. Use npm ci instead of npm install
  packageLock: "Ensure package-lock.json is committed for faster installs",
  
  // 3. Optimize Nx build configuration
  caching: {
    enable: "nx.json should have cacheableOperations",
    config: {
      "cacheableOperations": ["build", "test", "lint"],
      "implicitDependencies": {
        "package.json": {
          "dependencies": "*",
          "devDependencies": "*"
        }
      }
    }
  },
  
  // 4. Split large builds
  incremental: "Use Nx incremental builds where possible"
};
```

#### Issue: Memory Errors During Build
```bash
# Error: "JavaScript heap out of memory" during build
```

**Solutions:**
```bash
# Solution 1: Increase Node.js heap size
export NODE_OPTIONS="--max-old-space-size=4096"

# Solution 2: Optimize build configuration
# In nx.json
{
  "targetDefaults": {
    "build": {
      "executor": "@nrwl/webpack:webpack",
      "options": {
        "optimization": true,
        "sourceMap": false,
        "namedChunks": false
      }
    }
  }
}

# Solution 3: Use Railway's build environment variables
NODE_OPTIONS="--max-old-space-size=4096"
```

### Service Communication Issues

#### Issue: Services Cannot Connect
```bash
# Error: Connection refused between API and database
```

**Solutions:**
```typescript
// 1. Use Railway-provided environment variables
const dbConfig = {
  // ❌ Don't use localhost
  host: 'localhost',
  
  // ✅ Use Railway environment variables
  host: process.env.MYSQLHOST,
  port: process.env.MYSQLPORT,
  user: process.env.MYSQLUSER,
  password: process.env.MYSQLPASSWORD,
  database: process.env.MYSQLDATABASE
};

// 2. Check service networking
const serviceUrls = {
  // ❌ Hardcoded URLs
  apiUrl: 'http://localhost:3000',
  
  // ✅ Use Railway service URLs
  apiUrl: process.env.RAILWAY_API_URL || process.env.API_URL,
  
  // ✅ Internal service communication
  internalApi: process.env.RAILWAY_PRIVATE_DOMAIN
};
```

#### Issue: CORS Errors
```bash
# Error: "Access to fetch blocked by CORS policy"
```

**Solutions:**
```typescript
// apps/api/src/main.ts
import cors from 'cors';

// ❌ Overly permissive CORS
app.use(cors({ origin: '*' }));

// ✅ Properly configured CORS
app.use(cors({
  origin: [
    process.env.WEB_URL || 'http://localhost:4200',
    process.env.RAILWAY_WEB_URL,
    // Add all frontend URLs
  ],
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));

// ✅ Environment-based CORS
const allowedOrigins = process.env.ALLOWED_ORIGINS?.split(',') || ['http://localhost:4200'];
app.use(cors({
  origin: allowedOrigins,
  credentials: true
}));
```

## 🗄️ Database Issues

### Connection Problems

#### Issue: Database Connection Timeout
```bash
# Error: "connect ETIMEDOUT" or "Connection lost: The server closed the connection"
```

**Solutions:**
```typescript
// 1. Optimize connection pooling
const connectionConfig = {
  extra: {
    // Increase timeouts
    acquireTimeout: 60000, // 60 seconds
    connectionLimit: 10,
    timeout: 60000,
    
    // Handle connection drops
    reconnect: true,
    handleDisconnects: true,
    
    // SSL configuration
    ssl: process.env.NODE_ENV === 'production' ? {
      rejectUnauthorized: false
    } : false
  }
};

// 2. Implement connection retry logic
export class DatabaseConnection {
  static async initializeWithRetry(maxRetries = 3): Promise<void> {
    for (let i = 0; i < maxRetries; i++) {
      try {
        await AppDataSource.initialize();
        console.log('Database connected successfully');
        return;
      } catch (error) {
        console.log(`Database connection attempt ${i + 1} failed:`, error.message);
        
        if (i === maxRetries - 1) {
          throw new Error('Database connection failed after all retries');
        }
        
        // Wait before retry
        await new Promise(resolve => setTimeout(resolve, 5000));
      }
    }
  }
}
```

#### Issue: Too Many Connections
```bash
# Error: "Too many connections" or "User 'xyz' has exceeded the 'max_user_connections' resource"
```

**Solutions:**
```typescript
// 1. Optimize connection pool size
const poolConfig = {
  min: 1, // Minimum connections
  max: 5, // Reduced for small applications
  idle: 10000, // 10 seconds
  acquire: 30000, // 30 seconds
  evict: 1000 // Eviction check interval
};

// 2. Implement connection monitoring
export class ConnectionMonitor {
  static async checkConnectionCount(): Promise<number> {
    const result = await AppDataSource.query('SHOW STATUS WHERE Variable_name = "Threads_connected"');
    return parseInt(result[0].Value);
  }
  
  static async alertIfHighConnections(): Promise<void> {
    const count = await this.checkConnectionCount();
    if (count > 8) {
      console.warn(`High connection count: ${count}`);
      // Implement alerting logic
    }
  }
}

// 3. Close connections properly
export class DatabaseService {
  async closeConnection(): Promise<void> {
    if (AppDataSource.isInitialized) {
      await AppDataSource.destroy();
    }
  }
}
```

### Migration Issues

#### Issue: Migration Failures
```bash
# Error: "Migration failed" or "Table already exists"
```

**Solutions:**
```typescript
// 1. Check migration status
export class MigrationManager {
  static async checkMigrationStatus(): Promise<void> {
    const pendingMigrations = await AppDataSource.showMigrations();
    console.log('Pending migrations:', pendingMigrations);
  }
  
  static async safeMigration(): Promise<void> {
    try {
      // Check current schema
      const tables = await AppDataSource.query('SHOW TABLES');
      console.log('Existing tables:', tables);
      
      // Run migrations
      await AppDataSource.runMigrations();
      console.log('Migrations completed successfully');
    } catch (error) {
      console.error('Migration failed:', error);
      
      // Rollback strategy
      await this.rollbackLastMigration();
      throw error;
    }
  }
  
  static async rollbackLastMigration(): Promise<void> {
    try {
      await AppDataSource.undoLastMigration();
      console.log('Last migration rolled back');
    } catch (error) {
      console.error('Rollback failed:', error);
    }
  }
}

// 2. Migration best practices
const migrationBestPractices = {
  backup: "Always backup before running migrations in production",
  testing: "Test migrations in staging environment first",
  rollback: "Always have rollback strategy prepared",
  monitoring: "Monitor application after migration deployment"
};
```

## 🌐 Frontend Issues

### Static Site Deployment

#### Issue: React Router Not Working
```bash
# Error: 404 errors on page refresh or direct URL access
```

**Solutions:**
```typescript
// 1. Configure serve with SPA support
// In package.json for web service:
{
  "scripts": {
    "start": "npx serve dist/apps/web -s"
  }
}

// 2. Add _redirects file for SPA routing
// In dist/apps/web/_redirects:
/*    /index.html   200

// 3. Configure Railway build settings
const webServiceConfig = {
  buildCommand: "nx build web",
  startCommand: "npx serve dist/apps/web -s -l 3000",
  environmentVariables: {
    NODE_ENV: "production"
  }
};
```

#### Issue: Environment Variables Not Available in Frontend
```bash
# Error: process.env.VITE_API_URL is undefined
```

**Solutions:**
```typescript
// 1. Use Vite environment variable prefix
// ❌ Wrong prefix
const apiUrl = process.env.API_URL;

// ✅ Correct Vite prefix
const apiUrl = import.meta.env.VITE_API_URL;

// 2. Configure in Railway service
// Environment Variables:
VITE_API_URL=https://clinic-api-production.up.railway.app

// 3. Build-time configuration
// vite.config.ts
export default defineConfig({
  define: {
    'process.env.VITE_API_URL': JSON.stringify(process.env.VITE_API_URL)
  }
});

// 4. Runtime configuration check
const config = {
  apiUrl: import.meta.env.VITE_API_URL || 'http://localhost:3000',
  environment: import.meta.env.MODE
};

if (!config.apiUrl) {
  console.error('VITE_API_URL environment variable not set');
}
```

## 🔒 Security Issues

### Authentication Problems

#### Issue: JWT Token Issues
```bash
# Error: "Invalid token" or "Token expired"
```

**Solutions:**
```typescript
// 1. Implement proper token refresh
export class AuthService {
  private static refreshTimeout: NodeJS.Timeout;
  
  static async refreshToken(): Promise<string> {
    try {
      const response = await fetch('/api/auth/refresh', {
        method: 'POST',
        credentials: 'include'
      });
      
      if (!response.ok) {
        throw new Error('Token refresh failed');
      }
      
      const { token } = await response.json();
      this.scheduleTokenRefresh(token);
      return token;
    } catch (error) {
      // Redirect to login
      window.location.href = '/login';
      throw error;
    }
  }
  
  static scheduleTokenRefresh(token: string): void {
    const payload = JSON.parse(atob(token.split('.')[1]));
    const refreshTime = (payload.exp * 1000) - Date.now() - 60000; // 1 minute before expiry
    
    this.refreshTimeout = setTimeout(() => {
      this.refreshToken();
    }, refreshTime);
  }
}

// 2. Handle token expiration gracefully
const apiClient = {
  async request(url: string, options: RequestInit = {}) {
    const token = localStorage.getItem('auth_token');
    
    const response = await fetch(url, {
      ...options,
      headers: {
        ...options.headers,
        'Authorization': `Bearer ${token}`
      }
    });
    
    if (response.status === 401) {
      // Try to refresh token
      try {
        const newToken = await AuthService.refreshToken();
        localStorage.setItem('auth_token', newToken);
        
        // Retry original request
        return fetch(url, {
          ...options,
          headers: {
            ...options.headers,
            'Authorization': `Bearer ${newToken}`
          }
        });
      } catch (error) {
        // Redirect to login
        window.location.href = '/login';
        throw error;
      }
    }
    
    return response;
  }
};
```

### SSL/TLS Issues

#### Issue: SSL Certificate Problems
```bash
# Error: "NET::ERR_CERT_AUTHORITY_INVALID" or SSL connection errors
```

**Solutions:**
```typescript
const sslTroubleshooting = {
  // 1. Railway automatically provides SSL certificates
  automatic: "SSL certificates are automatically provisioned and renewed",
  
  // 2. Check custom domain configuration
  customDomain: {
    dns: "Ensure CNAME record points to Railway domain",
    verification: "Verify domain ownership in Railway dashboard",
    propagation: "DNS changes may take up to 48 hours to propagate"
  },
  
  // 3. Force HTTPS in production
  middleware: `
    app.use((req, res, next) => {
      if (process.env.NODE_ENV === 'production' && req.header('x-forwarded-proto') !== 'https') {
        res.redirect(\`https://\${req.header('host')}\${req.url}\`);
      } else {
        next();
      }
    });
  `
};
```

## 📊 Performance Issues

### Slow Response Times

#### Issue: API Endpoints Taking Too Long
```bash
# Error: Requests timing out or taking >5 seconds
```

**Solutions:**
```typescript
// 1. Implement database query optimization
export class PerformanceOptimizer {
  // Add query timing
  static async profileQuery<T>(query: () => Promise<T>, queryName: string): Promise<T> {
    const start = Date.now();
    try {
      const result = await query();
      const duration = Date.now() - start;
      
      if (duration > 1000) {
        console.warn(`Slow query detected: ${queryName} took ${duration}ms`);
      }
      
      return result;
    } catch (error) {
      console.error(`Query failed: ${queryName}`, error);
      throw error;
    }
  }
  
  // Implement caching
  static cache = new Map<string, { data: any; timestamp: number; ttl: number }>();
  
  static async getCachedData<T>(
    key: string, 
    fetcher: () => Promise<T>, 
    ttlMs: number = 300000
  ): Promise<T> {
    const cached = this.cache.get(key);
    const now = Date.now();
    
    if (cached && (now - cached.timestamp) < cached.ttl) {
      return cached.data;
    }
    
    const data = await fetcher();
    this.cache.set(key, { data, timestamp: now, ttl: ttlMs });
    return data;
  }
}

// 2. Optimize database queries
const queryOptimization = {
  // Use indexes
  indexes: "CREATE INDEX idx_patient_name ON patients(firstName, lastName)",
  
  // Limit result sets
  pagination: "SELECT * FROM patients LIMIT 50 OFFSET 0",
  
  // Optimize joins
  selectFields: "SELECT p.id, p.name FROM patients p WHERE ...",
  
  // Use query builder for complex queries
  queryBuilder: `
    const patients = await AppDataSource
      .getRepository(Patient)
      .createQueryBuilder('patient')
      .select(['patient.id', 'patient.firstName', 'patient.lastName'])
      .where('patient.firstName LIKE :name', { name: '%John%' })
      .limit(50)
      .getMany();
  `
};
```

### Memory Issues

#### Issue: Application Running Out of Memory
```bash
# Error: "JavaScript heap out of memory" in production
```

**Solutions:**
```typescript
// 1. Implement memory monitoring
export class MemoryMonitor {
  static logMemoryUsage(): void {
    const usage = process.memoryUsage();
    const formatMB = (bytes: number) => Math.round(bytes / 1024 / 1024 * 100) / 100;
    
    console.log({
      rss: `${formatMB(usage.rss)} MB`,
      heapTotal: `${formatMB(usage.heapTotal)} MB`,
      heapUsed: `${formatMB(usage.heapUsed)} MB`,
      external: `${formatMB(usage.external)} MB`
    });
    
    // Alert if memory usage is high
    if (formatMB(usage.heapUsed) > 400) {
      console.warn('High memory usage detected');
    }
  }
  
  static startMemoryMonitoring(): void {
    setInterval(() => {
      this.logMemoryUsage();
    }, 60000); // Every minute
  }
}

// 2. Optimize memory usage
const memoryOptimization = {
  // Clear cache periodically
  cacheCleanup: `
    setInterval(() => {
      // Clear old cache entries
      const now = Date.now();
      for (const [key, value] of cache.entries()) {
        if (now - value.timestamp > value.ttl) {
          cache.delete(key);
        }
      }
    }, 300000); // Every 5 minutes
  `,
  
  // Stream large responses
  streaming: `
    app.get('/api/patients/export', (req, res) => {
      res.setHeader('Content-Type', 'application/json');
      res.write('[');
      
      // Stream results instead of loading all into memory
      const stream = repository.createQueryBuilder()
        .stream();
        
      stream.on('data', (patient) => {
        res.write(JSON.stringify(patient) + ',');
      });
      
      stream.on('end', () => {
        res.write(']');
        res.end();
      });
    });
  `
};
```

## 🔧 Diagnostic Tools

### Logging and Debugging

```typescript
// 1. Structured logging for Railway
export class Logger {
  static info(message: string, metadata?: any): void {
    console.log(JSON.stringify({
      level: 'info',
      timestamp: new Date().toISOString(),
      message,
      service: process.env.SERVICE_NAME || 'unknown',
      environment: process.env.NODE_ENV || 'development',
      ...metadata
    }));
  }
  
  static error(message: string, error?: Error, metadata?: any): void {
    console.error(JSON.stringify({
      level: 'error',
      timestamp: new Date().toISOString(),
      message,
      error: error?.message,
      stack: error?.stack,
      service: process.env.SERVICE_NAME || 'unknown',
      environment: process.env.NODE_ENV || 'development',
      ...metadata
    }));
  }
}

// 2. Health check endpoint
app.get('/health', async (req, res) => {
  try {
    const health = {
      status: 'healthy',
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
      memory: process.memoryUsage(),
      database: await checkDatabaseHealth(),
      version: process.env.APP_VERSION || '1.0.0'
    };
    
    res.json(health);
  } catch (error) {
    res.status(503).json({
      status: 'unhealthy',
      error: error.message,
      timestamp: new Date().toISOString()
    });
  }
});

async function checkDatabaseHealth(): Promise<string> {
  try {
    await AppDataSource.query('SELECT 1');
    return 'connected';
  } catch (error) {
    return 'disconnected';
  }
}
```

### Performance Monitoring

```typescript
// Request timing middleware
app.use((req, res, next) => {
  const start = Date.now();
  
  res.on('finish', () => {
    const duration = Date.now() - start;
    Logger.info('HTTP Request', {
      method: req.method,
      url: req.url,
      statusCode: res.statusCode,
      duration: `${duration}ms`,
      userAgent: req.get('User-Agent'),
      ip: req.ip
    });
    
    if (duration > 5000) {
      Logger.error('Slow request detected', null, {
        method: req.method,
        url: req.url,
        duration: `${duration}ms`
      });
    }
  });
  
  next();
});
```

## 📋 Troubleshooting Checklist

### Deployment Checklist
- [ ] Build commands correctly configured
- [ ] Environment variables set properly
- [ ] Dependencies installed correctly
- [ ] Port configuration matches Railway expectations
- [ ] Service communication URLs configured

### Database Checklist  
- [ ] Connection string environment variables present
- [ ] Database service running and accessible
- [ ] Migrations executed successfully
- [ ] Connection pooling configured appropriately
- [ ] SSL/TLS configuration correct

### Performance Checklist
- [ ] Query performance optimized
- [ ] Caching implemented for frequent operations
- [ ] Memory usage monitored and optimized
- [ ] Response times under acceptable thresholds
- [ ] Health checks implemented and passing

### Security Checklist
- [ ] Authentication working correctly
- [ ] CORS configured properly
- [ ] SSL certificates valid and auto-renewing
- [ ] Sensitive data encrypted
- [ ] Access controls implemented

### Monitoring Checklist
- [ ] Structured logging implemented
- [ ] Error tracking and alerting configured
- [ ] Performance metrics monitored
- [ ] Health checks accessible
- [ ] Backup verification working

---

## 🆘 Getting Help

### Railway Support Channels
- **Documentation**: https://docs.railway.app/
- **Community Discord**: https://discord.gg/railway  
- **GitHub Issues**: https://github.com/railwayapp/issues
- **Twitter Support**: @Railway

### Emergency Response
1. **Service Outage**: Check Railway status page
2. **Data Loss**: Contact Railway support immediately
3. **Security Incident**: Secure systems and report to Railway
4. **Performance Crisis**: Implement emergency scaling

---

## 🔗 Navigation

- **Previous**: [Comparison Analysis](./comparison-analysis.md)
- **Next**: [Railway Research Overview](./README.md)