# Troubleshooting: Common Railway Deployment Issues

## 🔧 Build & Deployment Issues

### Issue 1: Nx Build Failures

#### Symptoms
```bash
Error: Cannot find module '@nx/workspace'
Build failed with exit code 1
```

#### Causes & Solutions
```bash
# Cause 1: Missing dependencies
# Solution: Ensure all Nx dependencies are in package.json
npm install @nx/workspace @nx/vite @nx/node --save-dev

# Cause 2: Corrupted Nx cache
# Solution: Clear cache before build
npx nx reset

# Cause 3: Missing build target
# Solution: Check project.json configuration
cat apps/web/project.json
cat apps/api/project.json
```

#### Prevention
```json
// package.json - Ensure all Nx deps are declared
{
  "devDependencies": {
    "@nx/workspace": "^17.0.0",
    "@nx/vite": "^17.0.0",
    "@nx/node": "^17.0.0",
    "@nx/eslint-plugin": "^17.0.0"
  },
  "scripts": {
    "railway:build:web": "npx nx reset && npx nx build web --prod",
    "railway:build:api": "npx nx reset && npx nx build api --prod"
  }
}
```

### Issue 2: TypeScript Compilation Errors

#### Symptoms
```bash
TS2307: Cannot find module '@clinic/shared/types'
apps/web/src/app/app.tsx(5,24): error TS2307
```

#### Causes & Solutions
```bash
# Cause: Incorrect tsconfig paths
# Solution: Update tsconfig.base.json paths

# Check path mapping
cat tsconfig.base.json

# Ensure proper path resolution
{
  "compilerOptions": {
    "paths": {
      "@clinic/shared/types": ["libs/shared/types/src/index.ts"],
      "@clinic/shared/utils": ["libs/shared/utils/src/index.ts"]
    }
  }
}
```

#### Railway-Specific Fix
```toml
# nixpacks.toml - Ensure TypeScript compilation
[phases.build]
cmds = [
  'npm ci',
  'npx tsc --noEmit', # Check types first
  'npx nx build web --prod'
]
```

### Issue 3: Memory Limits During Build

#### Symptoms
```bash
FATAL ERROR: Ineffective mark-compacts near heap limit
JavaScript heap out of memory
```

#### Solutions
```bash
# Solution 1: Increase Node.js memory limit
export NODE_OPTIONS="--max-old-space-size=4096"

# Solution 2: Optimize build process
npx nx build web --prod --optimization=false

# Solution 3: Update nixpacks.toml
```

```toml
# nixpacks.toml
[variables]
NODE_OPTIONS = "--max-old-space-size=4096"

[phases.build]
cmds = [
  'npm ci --production=false',
  'npx nx build web --prod --maxWorkers=1'
]
```

## 🗄️ Database Connection Issues

### Issue 4: MySQL Connection Timeouts

#### Symptoms
```bash
Error: connect ETIMEDOUT
ER_ACCESS_DENIED_ERROR: Access denied for user
```

#### Diagnostic Steps
```bash
# Step 1: Check DATABASE_URL format
railway variables get DATABASE_URL

# Step 2: Test connection from Railway CLI
railway connect mysql

# Step 3: Verify from application
railway run node -e "console.log(process.env.DATABASE_URL)"
```

#### Solutions
```typescript
// Connection with retry logic
import { DataSource } from 'typeorm';

export const AppDataSource = new DataSource({
  type: 'mysql',
  url: process.env.DATABASE_URL,
  extra: {
    connectionLimit: 10,
    acquireTimeout: 60000,
    timeout: 60000,
    reconnect: true,
    idleTimeout: 300000
  },
  retryAttempts: 10,
  retryDelay: 3000
});

// Graceful connection handling
const connectWithRetry = async () => {
  try {
    await AppDataSource.initialize();
    console.log('Database connected successfully');
  } catch (error) {
    console.error('Database connection failed, retrying in 5s...', error);
    setTimeout(connectWithRetry, 5000);
  }
};
```

### Issue 5: Database Migration Failures

#### Symptoms
```bash
QueryFailedError: Table 'patients' already exists
Migration failed: Duplicate column name 'email'
```

#### Solutions
```typescript
// Safe migration implementation
import { MigrationInterface, QueryRunner } from 'typeorm';

export class SafeMigration1700000000000 implements MigrationInterface {
  public async up(queryRunner: QueryRunner): Promise<void> {
    // Check if table exists before creating
    const hasTable = await queryRunner.hasTable('patients');
    if (!hasTable) {
      await queryRunner.query(`
        CREATE TABLE patients (
          id INT PRIMARY KEY AUTO_INCREMENT,
          first_name VARCHAR(100) NOT NULL,
          last_name VARCHAR(100) NOT NULL
        )
      `);
    }
    
    // Check if column exists before adding
    const hasColumn = await queryRunner.hasColumn('patients', 'email');
    if (!hasColumn) {
      await queryRunner.query(
        'ALTER TABLE patients ADD COLUMN email VARCHAR(255)'
      );
    }
  }
}
```

## 🌐 Service Communication Issues

### Issue 6: CORS Errors

#### Symptoms
```bash
Access to fetch at 'https://api-production.up.railway.app' 
from origin 'https://web-production.up.railway.app' 
has been blocked by CORS policy
```

#### Solutions
```typescript
// Proper CORS configuration
import cors from 'cors';

const allowedOrigins = [
  process.env.FRONTEND_URL,
  'https://web-production.up.railway.app',
  'https://clinic-web.railway.app'
].filter(Boolean);

app.use(cors({
  origin: (origin, callback) => {
    // Allow requests with no origin (mobile apps, etc.)
    if (!origin) return callback(null, true);
    
    if (allowedOrigins.indexOf(origin) !== -1) {
      callback(null, true);
    } else {
      callback(new Error('Not allowed by CORS'));
    }
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));
```

### Issue 7: Service Discovery Problems

#### Symptoms
```bash
fetch failed: getaddrinfo ENOTFOUND api-production.up.railway.app
```

#### Solutions
```typescript
// Robust API client with fallbacks
export class ApiClient {
  private baseUrl: string;
  
  constructor() {
    this.baseUrl = this.getApiUrl();
  }
  
  private getApiUrl(): string {
    // Priority order for API URL
    if (process.env.VITE_API_URL) {
      return process.env.VITE_API_URL;
    }
    
    if (process.env.RAILWAY_ENVIRONMENT === 'production') {
      return 'https://api-production.up.railway.app';
    }
    
    return 'http://localhost:3000';
  }
  
  async makeRequest(endpoint: string, options: RequestInit = {}) {
    const maxRetries = 3;
    let lastError;
    
    for (let attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        const response = await fetch(`${this.baseUrl}${endpoint}`, {
          ...options,
          timeout: 10000
        });
        
        if (!response.ok) {
          throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }
        
        return response;
      } catch (error) {
        lastError = error;
        console.warn(`API request attempt ${attempt} failed:`, error);
        
        if (attempt < maxRetries) {
          await new Promise(resolve => setTimeout(resolve, 1000 * attempt));
        }
      }
    }
    
    throw lastError;
  }
}
```

## 🔐 Environment & Configuration Issues

### Issue 8: Missing Environment Variables

#### Symptoms
```bash
TypeError: Cannot read property 'JWT_SECRET' of undefined
Database connection string is undefined
```

#### Diagnostic Commands
```bash
# Check all environment variables
railway variables list

# Check specific variable
railway variables get JWT_SECRET

# Test in running service
railway run env | grep JWT_SECRET
```

#### Solutions
```bash
# Set missing variables
railway variables set JWT_SECRET=$(openssl rand -base64 32)
railway variables set DATABASE_URL=${{MySQL.DATABASE_URL}}

# Verify variable references
railway variables set FRONTEND_URL=${{web.RAILWAY_PUBLIC_DOMAIN}}
```

```typescript
// Environment validation
import { z } from 'zod';

const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'production', 'test']),
  DATABASE_URL: z.string().url(),
  JWT_SECRET: z.string().min(32),
  PORT: z.string().transform(Number),
  FRONTEND_URL: z.string().url().optional()
});

export const env = envSchema.parse(process.env);
```

### Issue 9: Service Not Starting

#### Symptoms
```bash
Service exited with code 1
Process failed to bind to $PORT
```

#### Solutions
```typescript
// Proper port binding
const PORT = process.env.PORT || 3000;

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server running on port ${PORT}`);
  console.log(`Environment: ${process.env.NODE_ENV}`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully');
  server.close(() => {
    console.log('Process terminated');
  });
});
```

## 🚀 Performance Issues

### Issue 10: Slow Cold Starts

#### Symptoms
```bash
Service taking 30+ seconds to respond after idle
Request timeout errors after deployment
```

#### Solutions
```typescript
// Optimize application startup
import { performance } from 'perf_hooks';

const startTime = performance.now();

// Lazy load heavy dependencies
const loadHeavyDependencies = async () => {
  const modules = await Promise.all([
    import('some-heavy-library'),
    import('another-heavy-library')
  ]);
  return modules;
};

// Implement health check warmup
app.get('/warmup', async (req, res) => {
  try {
    // Warm up database connection
    await AppDataSource.query('SELECT 1');
    
    // Load critical dependencies
    await loadHeavyDependencies();
    
    const warmupTime = performance.now() - startTime;
    res.json({ 
      status: 'warm', 
      startupTime: `${warmupTime.toFixed(2)}ms` 
    });
  } catch (error) {
    res.status(500).json({ status: 'error', error: error.message });
  }
});
```

### Issue 11: Memory Leaks

#### Symptoms
```bash
Memory usage continuously increasing
OutOfMemoryError after extended runtime
```

#### Monitoring & Solutions
```typescript
// Memory monitoring
const monitorMemory = () => {
  const usage = process.memoryUsage();
  console.log('Memory Usage:', {
    rss: `${Math.round(usage.rss / 1024 / 1024)} MB`,
    heapTotal: `${Math.round(usage.heapTotal / 1024 / 1024)} MB`,
    heapUsed: `${Math.round(usage.heapUsed / 1024 / 1024)} MB`,
    external: `${Math.round(usage.external / 1024 / 1024)} MB`
  });
};

// Run every 5 minutes
setInterval(monitorMemory, 5 * 60 * 1000);

// Proper cleanup
process.on('beforeExit', async () => {
  await AppDataSource.destroy();
  console.log('Database connections closed');
});
```

## 📊 Monitoring & Debugging

### Issue 12: Application Logs Not Appearing

#### Solutions
```bash
# Check logs from Railway CLI
railway logs --follow

# Check specific service logs
railway logs --service api --follow

# Filter logs by time
railway logs --since 1h --service api
```

```typescript
// Structured logging for Railway
import winston from 'winston';

const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  defaultMeta: {
    service: process.env.RAILWAY_SERVICE_NAME,
    environment: process.env.RAILWAY_ENVIRONMENT
  },
  transports: [
    new winston.transports.Console()
  ]
});

// Ensure logs are flushed
process.on('exit', () => {
  logger.end();
});
```

### Issue 13: Health Check Failures

#### Implementation
```typescript
// Comprehensive health check
export class HealthService {
  async checkHealth(): Promise<HealthStatus> {
    const checks = await Promise.allSettled([
      this.checkDatabase(),
      this.checkExternalServices(),
      this.checkMemory(),
      this.checkDisk()
    ]);
    
    const failures = checks.filter(check => 
      check.status === 'rejected' || 
      (check.status === 'fulfilled' && !check.value.healthy)
    );
    
    return {
      status: failures.length === 0 ? 'healthy' : 'unhealthy',
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
      checks: {
        database: checks[0],
        external: checks[1],
        memory: checks[2],
        disk: checks[3]
      }
    };
  }
  
  private async checkDatabase(): Promise<{ healthy: boolean; latency: number }> {
    const start = Date.now();
    try {
      await AppDataSource.query('SELECT 1');
      return {
        healthy: true,
        latency: Date.now() - start
      };
    } catch (error) {
      return {
        healthy: false,
        latency: Date.now() - start
      };
    }
  }
}
```

## 🛠️ Emergency Recovery Procedures

### Rollback Deployment
```bash
# Quick rollback to previous version
railway rollback

# Rollback to specific deployment
railway deployments list
railway rollback --deployment <deployment-id>
```

### Database Recovery
```bash
# Connect to database for manual fixes
railway connect mysql

# Restore from backup (if available)
railway backups list
railway backups restore <backup-id>
```

### Service Restart
```bash
# Restart specific service
railway restart --service api

# Force restart all services
railway restart
```

## 📋 Troubleshooting Checklist

### Pre-Deployment Checklist
- [ ] All environment variables configured
- [ ] Database migrations tested locally
- [ ] Build process successful locally
- [ ] Health check endpoint implemented
- [ ] CORS configuration verified

### Post-Deployment Checklist
- [ ] All services responding to health checks
- [ ] Database connectivity verified
- [ ] Frontend can communicate with backend
- [ ] Logs are being generated properly
- [ ] Performance metrics within acceptable range

### Emergency Response Checklist
- [ ] Identify affected services
- [ ] Check recent deployments and changes
- [ ] Review error logs and metrics
- [ ] Implement immediate workaround if needed
- [ ] Plan and execute proper fix
- [ ] Verify resolution and monitor

---

## 🔗 Navigation

← [Previous: Comparison Analysis](./comparison-analysis.md) | [Back to README](./README.md) →