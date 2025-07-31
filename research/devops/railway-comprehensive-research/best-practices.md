# Best Practices: Railway.com Deployment & Operations

## 🏗️ Project Structure & Organization

### Railway Project Architecture
```yaml
Recommended Structure:
Single Project Per Environment:
  - clinic-management-dev (development)
  - clinic-management-staging (staging)  
  - clinic-management-prod (production)

Service Organization:
  - web (frontend)
  - api (backend)
  - mysql (database)
  - redis (caching - optional)
  - worker (background jobs - optional)
```

### Environment Management
```yaml
Development Environment:
  Plan: Hobby ($5/month)
  Services: Sleep after inactivity (acceptable for dev)
  Database: Smaller instance, test data

Staging Environment:
  Plan: Pro ($20/month) 
  Services: Always-on for client demos
  Database: Production-like data subset

Production Environment:
  Plan: Pro ($20/month)
  Services: Always-on, monitored
  Database: Full production data, daily backups
```

## 💻 Code Organization Best Practices

### Nx Workspace Configuration
```json
// nx.json - Optimized for Railway
{
  "targetDefaults": {
    "build": {
      "cache": true,
      "dependsOn": ["^build"],
      "inputs": ["production", "^production"],
      "outputs": ["{workspaceRoot}/dist"]
    },
    "test": {
      "cache": true,
      "inputs": ["default", "^production", "{workspaceRoot}/jest.preset.js"]
    }
  },
  "generators": {
    "@nx/react": {
      "application": {
        "bundler": "vite",
        "style": "css",
        "linter": "eslint",
        "unitTestRunner": "vitest"
      }
    },
    "@nx/node": {
      "application": {
        "linter": "eslint",
        "unitTestRunner": "jest"
      }
    }
  }
}
```

### Environment Variables Strategy
```typescript
// libs/shared/config/src/lib/config.ts
export const config = {
  // Frontend configuration
  frontend: {
    apiUrl: process.env['VITE_API_URL'] || 'http://localhost:3000',
    environment: process.env['VITE_APP_ENV'] || 'development',
    appName: process.env['VITE_APP_NAME'] || 'Clinic Management'
  },
  
  // Backend configuration
  backend: {
    port: parseInt(process.env['PORT'] || '3000'),
    nodeEnv: process.env['NODE_ENV'] || 'development',
    databaseUrl: process.env['DATABASE_URL'],
    jwtSecret: process.env['JWT_SECRET'],
    corsOrigin: process.env['CORS_ORIGIN'] || 'http://localhost:4200'
  },
  
  // Railway-specific
  railway: {
    environment: process.env['RAILWAY_ENVIRONMENT'],
    serviceName: process.env['RAILWAY_SERVICE_NAME'],
    projectName: process.env['RAILWAY_PROJECT_NAME']
  }
};
```

## 🚀 Deployment Best Practices

### Build Optimization
```yaml
Railway Build Strategy:
1. Cache Dependencies:
   - Use package-lock.json for deterministic builds
   - Leverage Railway's built-in caching
   - Minimize build-time dependencies

2. Optimize Build Commands:
   - Use Nx affected commands for monorepos
   - Parallel builds when possible
   - Skip unnecessary steps in production

3. Bundle Optimization:
   - Tree shaking for unused code
   - Code splitting for better loading
   - Compress assets (gzip/brotli)
```

### Dockerfile Alternatives (Advanced)
```dockerfile
# Multi-stage build for optimal production images
FROM node:18-alpine AS base
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force

FROM node:18-alpine AS builder
WORKDIR /app
COPY . .
RUN npm ci
RUN npx nx build api --prod

FROM base AS production
COPY --from=builder /app/dist/apps/api ./
EXPOSE 3000
CMD ["node", "main.js"]
```

### Database Migration Strategy
```typescript
// apps/api/src/database/migration-runner.ts
import { AppDataSource } from './config';

export class MigrationRunner {
  static async runMigrations(): Promise<void> {
    try {
      await AppDataSource.initialize();
      
      // Check current migration status
      const migrations = await AppDataSource.showMigrations();
      console.log(`Pending migrations: ${migrations.length}`);
      
      // Run migrations
      await AppDataSource.runMigrations();
      console.log('Migrations completed successfully');
      
    } catch (error) {
      console.error('Migration failed:', error);
      throw error;
    } finally {
      await AppDataSource.destroy();
    }
  }
}

// Auto-run migrations in production
if (process.env.AUTO_MIGRATE === 'true') {
  MigrationRunner.runMigrations();
}
```

## 📊 Performance Optimization

### Frontend Performance
```typescript
// apps/web/vite.config.ts - Production optimization
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  build: {
    target: 'es2020',
    minify: 'terser',
    terserOptions: {
      compress: {
        drop_console: true,
        drop_debugger: true
      }
    },
    rollupOptions: {
      output: {
        manualChunks: {
          vendor: ['react', 'react-dom', 'react-router-dom'],
          ui: ['@mui/material', '@mui/icons-material'],
          utils: ['date-fns', 'lodash-es']
        }
      }
    },
    chunkSizeWarningLimit: 1000
  },
  server: {
    port: 4200
  }
});
```

### Backend Performance
```typescript
// apps/api/src/main.ts - Production optimizations
import express from 'express';
import compression from 'compression';
import helmet from 'helmet';

const app = express();

// Compression middleware
app.use(compression({
  level: 6,
  threshold: 100 * 1024, // Only compress files > 100KB
  filter: (req, res) => {
    if (req.headers['x-no-compression']) return false;
    return compression.filter(req, res);
  }
}));

// Security headers
app.use(helmet({
  crossOriginEmbedderPolicy: false,
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      imgSrc: ["'self'", "data:", "https:"]
    }
  }
}));

// Request size limits
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));
```

### Database Performance
```typescript
// Database connection optimization
import { DataSource } from 'typeorm';

export const AppDataSource = new DataSource({
  type: 'mysql',
  url: process.env.DATABASE_URL,
  
  // Connection pool optimization
  extra: {
    connectionLimit: 10,
    acquireTimeout: 60000,
    timeout: 60000,
    reconnect: true
  },
  
  // Query optimization
  cache: {
    duration: 30000, // Cache queries for 30 seconds
    type: 'ioredis',
    options: {
      host: process.env.REDIS_HOST,
      port: process.env.REDIS_PORT
    }
  },
  
  // Production settings
  synchronize: false,
  logging: process.env.NODE_ENV === 'development',
  entities: ['dist/**/*.entity.js'],
  migrations: ['dist/migrations/*.js']
});
```

## 🔐 Security Best Practices

### Authentication & Authorization
```typescript
// JWT implementation with refresh tokens
import jwt from 'jsonwebtoken';
import { Response } from 'express';

export class AuthService {
  generateTokens(userId: number) {
    const accessToken = jwt.sign(
      { userId, type: 'access' },
      process.env.JWT_SECRET!,
      { expiresIn: '15m' }
    );
    
    const refreshToken = jwt.sign(
      { userId, type: 'refresh' },
      process.env.REFRESH_SECRET!,
      { expiresIn: '7d' }
    );
    
    return { accessToken, refreshToken };
  }
  
  setSecureCookies(res: Response, tokens: { accessToken: string; refreshToken: string }) {
    res.cookie('accessToken', tokens.accessToken, {
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'strict',
      maxAge: 15 * 60 * 1000 // 15 minutes
    });
    
    res.cookie('refreshToken', tokens.refreshToken, {
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'strict',
      maxAge: 7 * 24 * 60 * 60 * 1000 // 7 days
    });
  }
}
```

### Input Validation & Sanitization
```typescript
// Comprehensive input validation
import { IsEmail, IsString, IsOptional, IsDateString, Length } from 'class-validator';

export class CreatePatientDto {
  @IsString()
  @Length(1, 100)
  firstName: string;
  
  @IsString()
  @Length(1, 100)
  lastName: string;
  
  @IsEmail()
  @IsOptional()
  email?: string;
  
  @IsString()
  @IsOptional()
  @Length(10, 20)
  phone?: string;
  
  @IsDateString()
  @IsOptional()
  dateOfBirth?: string;
}
```

### Rate Limiting & DDoS Protection
```typescript
// Multi-level rate limiting
import rateLimit from 'express-rate-limit';
import slowDown from 'express-slow-down';

// General API rate limiting
const apiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 1000, // Limit each IP to 1000 requests per windowMs
  message: 'Too many requests from this IP'
});

// Authentication endpoint rate limiting
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 10, // Limit login attempts
  skipSuccessfulRequests: true
});

// Progressive delay for repeated requests
const speedLimiter = slowDown({
  windowMs: 15 * 60 * 1000,
  delayAfter: 100,
  delayMs: 500,
  maxDelayMs: 20000
});

app.use('/api', apiLimiter);
app.use('/api', speedLimiter);
app.use('/api/auth', authLimiter);
```

## 📊 Monitoring & Observability

### Health Check Implementation
```typescript
// Comprehensive health checks
export class HealthService {
  async getHealthStatus() {
    const checks = await Promise.allSettled([
      this.checkDatabase(),
      this.checkRedis(),
      this.checkExternalAPIs(),
      this.checkDiskSpace(),
      this.checkMemoryUsage()
    ]);
    
    return {
      status: checks.every(check => check.status === 'fulfilled') ? 'healthy' : 'unhealthy',
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
      checks: {
        database: checks[0],
        redis: checks[1],
        externalAPIs: checks[2],
        diskSpace: checks[3],
        memory: checks[4]
      }
    };
  }
  
  private async checkDatabase(): Promise<{ status: string; responseTime: number }> {
    const start = Date.now();
    try {
      await AppDataSource.query('SELECT 1');
      return {
        status: 'healthy',
        responseTime: Date.now() - start
      };
    } catch (error) {
      return {
        status: 'unhealthy',
        responseTime: Date.now() - start
      };
    }
  }
}
```

### Structured Logging
```typescript
// Winston logger configuration
import winston from 'winston';

const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  defaultMeta: {
    service: process.env.RAILWAY_SERVICE_NAME || 'api',
    environment: process.env.RAILWAY_ENVIRONMENT || 'development'
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
app.use((req, res, next) => {
  const start = Date.now();
  
  res.on('finish', () => {
    const duration = Date.now() - start;
    logger.info('HTTP Request', {
      method: req.method,
      url: req.url,
      statusCode: res.statusCode,
      duration,
      userAgent: req.get('User-Agent'),
      ip: req.ip
    });
  });
  
  next();
});
```

## 💰 Cost Optimization

### Resource Right-Sizing
```yaml
Service Sizing Guidelines:

Small Clinic (2-3 users):
  Frontend: 512MB RAM, 0.5 vCPU
  Backend: 1GB RAM, 1 vCPU
  Database: 1GB RAM, 0.5 vCPU

Medium Clinic (5-10 users):
  Frontend: 1GB RAM, 1 vCPU
  Backend: 2GB RAM, 2 vCPU
  Database: 2GB RAM, 1 vCPU

Large Clinic (15+ users):
  Frontend: 2GB RAM, 2 vCPU
  Backend: 4GB RAM, 4 vCPU
  Database: 4GB RAM, 2 vCPU
```

### Caching Strategy
```typescript
// Redis caching implementation
import Redis from 'ioredis';

const redis = new Redis(process.env.REDIS_URL);

export class CacheService {
  async get<T>(key: string): Promise<T | null> {
    const cached = await redis.get(key);
    return cached ? JSON.parse(cached) : null;
  }
  
  async set(key: string, value: any, ttl: number = 300): Promise<void> {
    await redis.setex(key, ttl, JSON.stringify(value));
  }
  
  async invalidate(pattern: string): Promise<void> {
    const keys = await redis.keys(pattern);
    if (keys.length > 0) {
      await redis.del(...keys);
    }
  }
}

// Usage in controllers
app.get('/api/patients/:id', async (req, res) => {
  const cacheKey = `patient:${req.params.id}`;
  
  // Check cache first
  let patient = await cacheService.get(cacheKey);
  
  if (!patient) {
    // Fetch from database
    patient = await patientRepository.findOne(req.params.id);
    
    // Cache for 5 minutes
    await cacheService.set(cacheKey, patient, 300);
  }
  
  res.json(patient);
});
```

## 🔄 CI/CD Best Practices

### GitHub Actions Workflow
```yaml
# .github/workflows/railway-production.yml
name: Production Deployment

on:
  push:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'
          cache: 'npm'
      
      - name: Install dependencies
        run: npm ci
      
      - name: Run unit tests
        run: npx nx run-many --target=test --projects=web,api --parallel=3
      
      - name: Run integration tests
        run: npx nx run-many --target=test:integration --projects=api
      
      - name: Run linting
        run: npx nx run-many --target=lint --projects=web,api --parallel=3
      
      - name: Build applications
        run: |
          npx nx build web --prod
          npx nx build api --prod
  
  deploy:
    needs: test
    runs-on: ubuntu-latest
    environment: production
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Deploy to Railway
        uses: railway/railway@v1
        with:
          railway-token: ${{ secrets.RAILWAY_TOKEN }}
          command: 'up --detach'
      
      - name: Run health checks
        run: |
          sleep 30
          curl -f https://api-production.up.railway.app/health
      
      - name: Notify deployment
        if: always()
        uses: 8398a7/action-slack@v3
        with:
          status: ${{ job.status }}
          webhook_url: ${{ secrets.SLACK_WEBHOOK }}
```

### Pre-commit Hooks
```json
// package.json
{
  "husky": {
    "hooks": {
      "pre-commit": "lint-staged",
      "pre-push": "npm run test:ci"
    }
  },
  "lint-staged": {
    "*.{ts,tsx}": [
      "npx nx affected --target=lint --fix",
      "npx nx affected --target=test --bail=1"
    ]
  }
}
```

## 🔧 Maintenance & Operations

### Database Maintenance
```sql
-- Regular maintenance queries
-- Run weekly via Railway cron or scheduled job

-- Optimize tables
OPTIMIZE TABLE patients, appointments, medical_records;

-- Update table statistics
ANALYZE TABLE patients, appointments, medical_records;

-- Check for fragmentation
SELECT 
  table_name,
  ROUND(data_length/1024/1024, 2) as data_mb,
  ROUND(index_length/1024/1024, 2) as index_mb,
  ROUND(data_free/1024/1024, 2) as free_mb
FROM information_schema.tables 
WHERE table_schema = DATABASE();
```

### Backup Strategy
```typescript
// Automated backup script
import { execSync } from 'child_process';

export class BackupService {
  async createBackup(): Promise<void> {
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    const backupName = `clinic-backup-${timestamp}.sql`;
    
    try {
      // Create database dump
      execSync(`mysqldump ${process.env.DATABASE_URL} > /tmp/${backupName}`);
      
      // Upload to S3 or external storage
      await this.uploadToStorage(`/tmp/${backupName}`, backupName);
      
      // Clean up local file
      execSync(`rm /tmp/${backupName}`);
      
      console.log(`Backup created successfully: ${backupName}`);
    } catch (error) {
      console.error('Backup failed:', error);
      throw error;
    }
  }
  
  private async uploadToStorage(localPath: string, fileName: string): Promise<void> {
    // Implementation depends on storage provider (AWS S3, etc.)
  }
}
```

---

## 🔗 Navigation

← [Previous: Implementation Guide](./implementation-guide.md) | [Next: Comparison Analysis](./comparison-analysis.md) →