# Best Practices: Railway.com Deployment

## 🎯 Overview

This guide provides proven best practices for deploying and managing applications on Railway.com, based on real-world experience and optimization strategies for production environments.

## 🏗 Architecture Best Practices

### 1. Service Organization

#### Recommended Service Structure
```
Project: clinic-management-prod
├── web-service (React/Vite frontend)
├── api-service (Express.js backend)
├── database-service (MySQL)
└── redis-service (Cache/sessions - optional)
```

#### Service Naming Conventions
```bash
# Use descriptive, consistent names
railway service create clinic-web
railway service create clinic-api
railway service create clinic-db

# Avoid generic names
❌ railway service create web
❌ railway service create backend
❌ railway service create db
```

### 2. Environment Configuration

#### Environment Variable Management
```bash
# Use Railway's variable references for service communication
railway variables set API_URL=https://${{api.RAILWAY_PUBLIC_DOMAIN}} --service web
railway variables set DATABASE_URL=${{MySQL.DATABASE_URL}} --service api

# Group related variables with prefixes
railway variables set DB_CONNECTION_LIMIT=10 --service api
railway variables set DB_POOL_MIN=2 --service api
railway variables set DB_POOL_MAX=10 --service api

# Use secrets for sensitive data
railway variables set JWT_SECRET=$(openssl rand -base64 32) --service api
railway variables set ENCRYPTION_KEY=$(openssl rand -base64 32) --service api
```

#### Configuration File Structure
```typescript
// libs/shared/config/src/index.ts
export interface Config {
  port: number;
  nodeEnv: string;
  database: {
    url: string;
    connectionLimit: number;
    timeout: number;
  };
  auth: {
    jwtSecret: string;
    jwtExpiresIn: string;
  };
  cors: {
    origin: string;
    credentials: boolean;
  };
}

export const config: Config = {
  port: parseInt(process.env.PORT || '8080'),
  nodeEnv: process.env.NODE_ENV || 'development',
  database: {
    url: process.env.DATABASE_URL || '',
    connectionLimit: parseInt(process.env.DB_CONNECTION_LIMIT || '10'),
    timeout: parseInt(process.env.DB_TIMEOUT || '60000'),
  },
  auth: {
    jwtSecret: process.env.JWT_SECRET || '',
    jwtExpiresIn: process.env.JWT_EXPIRES_IN || '24h',
  },
  cors: {
    origin: process.env.CORS_ORIGIN || 'http://localhost:3000',
    credentials: process.env.CORS_CREDENTIALS === 'true',
  },
};

// Validate required environment variables
const requiredEnvVars = ['DATABASE_URL', 'JWT_SECRET'];
const missingVars = requiredEnvVars.filter(envVar => !process.env[envVar]);

if (missingVars.length > 0) {
  throw new Error(`Missing required environment variables: ${missingVars.join(', ')}`);
}
```

## 🚀 Deployment Best Practices

### 1. Railway Configuration

#### Optimized `railway.toml`
```toml
# Root configuration
[build]
builder = "nixpacks"
buildCommand = "npm run build:prod"

[deploy]
numReplicas = 1
restartPolicyType = "ON_FAILURE"
restartPolicyMaxRetries = 3
healthcheckPath = "/health"
healthcheckTimeout = 30
healthcheckInterval = 30

# Resource optimization
[resources]
memory = "512Mi"  # Start with minimal resources
cpu = "0.25"      # Adjust based on actual usage

# Environment-specific overrides
[environments.production]
replicas = 2
memory = "1Gi"
cpu = "0.5"
```

#### Service-Specific Configurations

**Frontend Service (`.railway/web.toml`):**
```toml
[build]
builder = "nixpacks"
buildCommand = "npx nx build web --prod"

[deploy]
startCommand = "npx serve dist/apps/web -s -p $PORT -C"
healthcheckPath = "/"
healthcheckTimeout = 30

# Static asset optimization
[staticFiles]
directory = "dist/apps/web"
```

**Backend Service (`.railway/api.toml`):**
```toml
[build]
builder = "nixpacks"
buildCommand = "npx nx build api --prod"

[deploy]
startCommand = "node dist/apps/api/main.js"
healthcheckPath = "/health"
healthcheckTimeout = 30

# Process management
[process]
restart = "always"
maxMemoryRestart = "500M"
```

### 2. Build Optimization

#### Dockerfile Best Practices (Optional)
```dockerfile
# Multi-stage build for optimal size
FROM node:18-alpine AS builder

# Set working directory
WORKDIR /app

# Copy package files first (better caching)
COPY package*.json ./
COPY nx.json ./
COPY tsconfig.base.json ./

# Install dependencies
RUN npm ci --only=production && npm cache clean --force

# Copy source code
COPY apps/ apps/
COPY libs/ libs/

# Build the application
RUN npx nx build api --prod

# Production image
FROM node:18-alpine AS production

# Create non-root user
RUN addgroup -g 1001 -S nodejs
RUN adduser -S nextjs -u 1001

WORKDIR /app

# Copy built application
COPY --from=builder --chown=nextjs:nodejs /app/dist/apps/api ./
COPY --from=builder --chown=nextjs:nodejs /app/node_modules ./node_modules

# Switch to non-root user
USER nextjs

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8080/health || exit 1

# Start application
CMD ["node", "main.js"]
```

#### Build Performance Optimization
```json
// nx.json
{
  "tasksRunnerOptions": {
    "default": {
      "runner": "nx/tasks-runners/default",
      "options": {
        "cacheableOperations": ["build", "test", "lint"],
        "parallel": 3,
        "maxParallel": 3
      }
    }
  },
  "targetDefaults": {
    "build": {
      "cache": true,
      "dependsOn": ["^build"],
      "inputs": [
        "production",
        "^production"
      ]
    }
  },
  "namedInputs": {
    "production": [
      "default",
      "!{projectRoot}/**/?(*.)+(spec|test).[jt]s?(x)?(.snap)",
      "!{projectRoot}/tsconfig.spec.json",
      "!{projectRoot}/.eslintrc.json"
    ]
  }
}
```

## 🔧 Performance Optimization

### 1. Database Optimization

#### Connection Pool Configuration
```typescript
// libs/shared/database/src/connection.ts
import mysql from 'mysql2/promise';

export const createDatabasePool = () => {
  return mysql.createPool({
    uri: process.env.DATABASE_URL,
    
    // Connection pool settings
    connectionLimit: parseInt(process.env.DB_CONNECTION_LIMIT || '10'),
    queueLimit: 0,
    acquireTimeout: 60000,
    timeout: 60000,
    
    // Performance settings
    reconnect: true,
    charset: 'utf8mb4',
    timezone: 'Z',
    
    // Security settings
    ssl: process.env.NODE_ENV === 'production' ? {
      rejectUnauthorized: false
    } : false,
    
    // Connection management
    idleTimeout: 300000, // 5 minutes
    maxIdle: 5,
    
    // Query optimization
    typeCast: function (field, next) {
      if (field.type === 'TINY' && field.length === 1) {
        return (field.string() === '1'); // Convert TINYINT(1) to boolean
      }
      return next();
    }
  });
};

// Connection health monitoring
export const monitorDatabaseHealth = (pool: mysql.Pool) => {
  setInterval(async () => {
    try {
      const connection = await pool.getConnection();
      await connection.ping();
      connection.release();
    } catch (error) {
      console.error('Database health check failed:', error);
    }
  }, 30000); // Check every 30 seconds
};
```

#### Query Optimization
```typescript
// Optimized patient search
export class PatientRepository {
  constructor(private db: mysql.Pool) {}

  async searchPatients(searchTerm: string, limit: number = 20): Promise<Patient[]> {
    // Use full-text search for better performance
    const sql = `
      SELECT 
        id, 
        patient_id,
        CONCAT(first_name, ' ', last_name) as full_name,
        email,
        phone,
        created_at
      FROM patients 
      WHERE MATCH(first_name, last_name, patient_id) AGAINST(? IN BOOLEAN MODE)
      ORDER BY created_at DESC
      LIMIT ?
    `;
    
    const [rows] = await this.db.execute(sql, [`${searchTerm}*`, limit]);
    return rows as Patient[];
  }

  async getPatientAppointments(patientId: number): Promise<Appointment[]> {
    // Efficient query with proper joins and indexes
    const sql = `
      SELECT 
        a.id,
        a.scheduled_at,
        a.status,
        a.appointment_type,
        u.first_name as doctor_first_name,
        u.last_name as doctor_last_name
      FROM appointments a
      INNER JOIN users u ON a.doctor_id = u.id
      WHERE a.patient_id = ?
      ORDER BY a.scheduled_at DESC
      LIMIT 50
    `;
    
    const [rows] = await this.db.execute(sql, [patientId]);
    return rows as Appointment[];
  }
}
```

### 2. Caching Strategy

#### Application-Level Caching
```typescript
// libs/shared/cache/src/index.ts
import NodeCache from 'node-cache';

export class CacheService {
  private cache: NodeCache;

  constructor(options?: { stdTTL?: number; checkperiod?: number }) {
    this.cache = new NodeCache({
      stdTTL: options?.stdTTL || 600, // 10 minutes default
      checkperiod: options?.checkperiod || 120, // Check every 2 minutes
      useClones: false // Better performance, be careful with mutations
    });
  }

  get<T>(key: string): T | undefined {
    return this.cache.get<T>(key);
  }

  set<T>(key: string, value: T, ttl?: number): boolean {
    return this.cache.set(key, value, ttl);
  }

  del(key: string): number {
    return this.cache.del(key);
  }

  flush(): void {
    this.cache.flushAll();
  }

  getStats() {
    return this.cache.getStats();
  }
}

// Singleton instance
export const cache = new CacheService();

// Usage in API routes
app.get('/api/patients/:id', async (req, res) => {
  const patientId = req.params.id;
  const cacheKey = `patient_${patientId}`;
  
  // Try cache first
  let patient = cache.get<Patient>(cacheKey);
  
  if (!patient) {
    patient = await patientRepository.findById(parseInt(patientId));
    if (patient) {
      cache.set(cacheKey, patient, 300); // Cache for 5 minutes
    }
  }
  
  res.json(patient);
});
```

### 3. API Performance

#### Request/Response Optimization
```typescript
// apps/api/src/middleware/performance.ts
import compression from 'compression';
import helmet from 'helmet';
import cors from 'cors';

export const performanceMiddleware = [
  // Security headers
  helmet({
    contentSecurityPolicy: {
      directives: {
        defaultSrc: ["'self'"],
        styleSrc: ["'self'", "'unsafe-inline'"],
        scriptSrc: ["'self'"],
        imgSrc: ["'self'", "data:", "https:"],
      },
    },
  }),

  // CORS configuration
  cors({
    origin: process.env.CORS_ORIGIN?.split(',') || ['http://localhost:3000'],
    credentials: true,
    optionsSuccessStatus: 200,
  }),

  // Compression
  compression({
    filter: (req, res) => {
      if (req.headers['x-no-compression']) {
        return false;
      }
      return compression.filter(req, res);
    },
    level: 6, // Good balance between compression and CPU usage
    threshold: 1024, // Only compress responses > 1KB
  }),

  // Request timeout
  (req: Request, res: Response, next: NextFunction) => {
    req.setTimeout(30000, () => {
      res.status(408).json({ error: 'Request timeout' });
    });
    next();
  },

  // Request size limit
  express.json({ limit: '10mb' }),
  express.urlencoded({ extended: true, limit: '10mb' }),
];
```

## 🔐 Security Best Practices

### 1. Authentication & Authorization

#### JWT Implementation
```typescript
// libs/shared/auth/src/jwt.service.ts
import jwt from 'jsonwebtoken';
import { config } from '@clinic/shared/config';

export interface JWTPayload {
  userId: number;
  email: string;
  role: string;
  iat?: number;
  exp?: number;
}

export class JWTService {
  private readonly secret: string;
  private readonly expiresIn: string;

  constructor() {
    this.secret = config.auth.jwtSecret;
    this.expiresIn = config.auth.jwtExpiresIn;
  }

  generateToken(payload: Omit<JWTPayload, 'iat' | 'exp'>): string {
    return jwt.sign(payload, this.secret, {
      expiresIn: this.expiresIn,
      issuer: 'clinic-management',
      audience: 'clinic-users',
    });
  }

  verifyToken(token: string): JWTPayload {
    try {
      return jwt.verify(token, this.secret, {
        issuer: 'clinic-management',
        audience: 'clinic-users',
      }) as JWTPayload;
    } catch (error) {
      throw new Error('Invalid token');
    }
  }

  refreshToken(token: string): string {
    const payload = this.verifyToken(token);
    const { iat, exp, ...tokenData } = payload;
    return this.generateToken(tokenData);
  }
}

// Middleware for protected routes
export const authenticateToken = (req: Request, res: Response, next: NextFunction) => {
  const authHeader = req.headers.authorization;
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ error: 'Access token required' });
  }

  try {
    const jwtService = new JWTService();
    const payload = jwtService.verifyToken(token);
    req.user = payload;
    next();
  } catch (error) {
    return res.status(403).json({ error: 'Invalid or expired token' });
  }
};
```

### 2. Data Validation

#### Input Validation with Zod
```typescript
// libs/shared/validations/src/patient.schema.ts
import { z } from 'zod';

export const createPatientSchema = z.object({
  firstName: z.string().min(1).max(100),
  lastName: z.string().min(1).max(100),
  email: z.string().email().optional(),
  phone: z.string().regex(/^\+?[\d\s\-\(\)]+$/).optional(),
  dateOfBirth: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
  gender: z.enum(['male', 'female', 'other']).optional(),
  address: z.string().max(500).optional(),
  emergencyContactName: z.string().max(100).optional(),
  emergencyContactPhone: z.string().regex(/^\+?[\d\s\-\(\)]+$/).optional(),
});

export const updatePatientSchema = createPatientSchema.partial();

// Validation middleware
export const validateCreatePatient = (req: Request, res: Response, next: NextFunction) => {
  try {
    createPatientSchema.parse(req.body);
    next();
  } catch (error) {
    if (error instanceof z.ZodError) {
      return res.status(400).json({
        error: 'Validation failed',
        details: error.errors,
      });
    }
    next(error);
  }
};
```

### 3. Rate Limiting

#### API Rate Limiting
```typescript
// apps/api/src/middleware/rate-limiting.ts
import rateLimit from 'express-rate-limit';
import RedisStore from 'rate-limit-redis';
import Redis from 'ioredis';

// Redis configuration (optional, for multiple instances)
const redis = process.env.REDIS_URL ? new Redis(process.env.REDIS_URL) : undefined;

// General API rate limiting
export const apiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // Limit each IP to 100 requests per windowMs
  message: {
    error: 'Too many requests from this IP, please try again later.',
  },
  standardHeaders: true,
  legacyHeaders: false,
  store: redis ? new RedisStore({
    sendCommand: (...args: string[]) => redis.call(...args),
  }) : undefined,
});

// Stricter rate limiting for authentication endpoints
export const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 5, // Limit each IP to 5 requests per windowMs
  message: {
    error: 'Too many authentication attempts, please try again later.',
  },
  skipSuccessfulRequests: true,
});

// Apply rate limiting
app.use('/api/', apiLimiter);
app.use('/api/auth/', authLimiter);
```

## 📊 Monitoring & Observability

### 1. Application Monitoring

#### Health Check Implementation
```typescript
// apps/api/src/health/health.controller.ts
interface HealthCheck {
  status: 'healthy' | 'degraded' | 'unhealthy';
  timestamp: string;
  uptime: number;
  version: string;
  environment: string;
  checks: {
    database: boolean;
    cache: boolean;
    memory: {
      used: string;
      total: string;
      percentage: number;
    };
    disk: {
      used: string;
      total: string;
      percentage: number;
    };
  };
}

export class HealthController {
  async checkHealth(): Promise<HealthCheck> {
    const startTime = Date.now();
    
    // Check database connectivity
    const dbHealthy = await this.checkDatabase();
    
    // Check cache connectivity
    const cacheHealthy = await this.checkCache();
    
    // Get memory usage
    const memoryUsage = process.memoryUsage();
    const memoryTotal = memoryUsage.heapTotal;
    const memoryUsed = memoryUsage.heapUsed;
    
    // Determine overall status
    let status: 'healthy' | 'degraded' | 'unhealthy' = 'healthy';
    
    if (!dbHealthy) {
      status = 'unhealthy';
    } else if (!cacheHealthy || (memoryUsed / memoryTotal) > 0.9) {
      status = 'degraded';
    }

    return {
      status,
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
      version: process.env.npm_package_version || 'unknown',
      environment: process.env.NODE_ENV || 'development',
      checks: {
        database: dbHealthy,
        cache: cacheHealthy,
        memory: {
          used: this.formatBytes(memoryUsed),
          total: this.formatBytes(memoryTotal),
          percentage: Math.round((memoryUsed / memoryTotal) * 100),
        },
        disk: await this.getDiskUsage(),
      },
    };
  }

  private async checkDatabase(): Promise<boolean> {
    try {
      await db.query('SELECT 1');
      return true;
    } catch {
      return false;
    }
  }

  private async checkCache(): Promise<boolean> {
    try {
      cache.set('health_check', Date.now(), 1);
      return cache.get('health_check') !== undefined;
    } catch {
      return false;
    }
  }

  private formatBytes(bytes: number): string {
    return (bytes / 1024 / 1024).toFixed(2) + ' MB';
  }

  private async getDiskUsage(): Promise<{ used: string; total: string; percentage: number }> {
    // Simplified disk usage - in production, use proper disk monitoring
    return {
      used: '100 MB',
      total: '1 GB',
      percentage: 10,
    };
  }
}
```

### 2. Error Tracking

#### Error Handling & Logging
```typescript
// libs/shared/logging/src/logger.ts
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
  },
  transports: [
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.colorize(),
        winston.format.simple()
      ),
    }),
  ],
});

// Error handling middleware
export const errorHandler = (
  error: Error,
  req: Request,
  res: Response,
  next: NextFunction
) => {
  logger.error('API Error', {
    error: error.message,
    stack: error.stack,
    url: req.url,
    method: req.method,
    ip: req.ip,
    userAgent: req.get('User-Agent'),
    userId: req.user?.userId,
  });

  // Don't leak error details in production
  const isDevelopment = process.env.NODE_ENV === 'development';
  
  res.status(500).json({
    error: 'Internal server error',
    ...(isDevelopment && { details: error.message, stack: error.stack }),
  });
};

export { logger };
```

## 🔄 CI/CD Best Practices

### 1. GitHub Actions Integration

#### Production Deployment Workflow
```yaml
# .github/workflows/deploy-production.yml
name: Deploy to Production

on:
  push:
    branches: [main]
  workflow_dispatch:

env:
  NODE_VERSION: '18'
  NX_CLOUD_ACCESS_TOKEN: ${{ secrets.NX_CLOUD_ACCESS_TOKEN }}

jobs:
  test:
    name: Test & Build
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
        with:
          fetch-depth: 0

      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Run tests
        run: npx nx run-many --target=test --all --parallel --maxParallel=3

      - name: Run linting
        run: npx nx run-many --target=lint --all --parallel --maxParallel=3

      - name: Build applications
        run: npx nx run-many --target=build --all --parallel --maxParallel=3

      - name: Upload build artifacts
        uses: actions/upload-artifact@v3
        with:
          name: build-artifacts
          path: dist/

  deploy:
    name: Deploy to Railway
    needs: test
    runs-on: ubuntu-latest
    environment: production
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Download build artifacts
        uses: actions/download-artifact@v3
        with:
          name: build-artifacts
          path: dist/

      - name: Deploy to Railway
        uses: railway/cli-action@v1
        with:
          token: ${{ secrets.RAILWAY_TOKEN }}
          command: up --service web --service api

      - name: Wait for deployment
        run: sleep 30

      - name: Health check
        run: |
          curl -f ${{ secrets.API_URL }}/health || exit 1
          curl -f ${{ secrets.WEB_URL }} || exit 1

      - name: Notify team
        if: always()
        uses: 8398a7/action-slack@v3
        with:
          status: ${{ job.status }}
          webhook_url: ${{ secrets.SLACK_WEBHOOK }}
```

### 2. Environment Management

#### Multi-Environment Setup
```bash
# Development environment
railway project create clinic-dev
railway variables set NODE_ENV=development --service api
railway variables set LOG_LEVEL=debug --service api

# Staging environment  
railway project create clinic-staging
railway variables set NODE_ENV=staging --service api
railway variables set LOG_LEVEL=info --service api

# Production environment
railway project create clinic-prod
railway variables set NODE_ENV=production --service api
railway variables set LOG_LEVEL=warn --service api
```

## 💡 Cost Optimization Tips

### 1. Resource Optimization

- **Start small:** Begin with minimal resources and scale based on actual usage
- **Monitor actively:** Use Railway's built-in metrics to track resource consumption
- **Implement caching:** Reduce database queries and API calls
- **Optimize queries:** Use proper indexes and efficient SQL queries
- **Use compression:** Enable gzip compression for API responses

### 2. Development Practices

- **Feature flags:** Use environment variables to enable/disable features
- **Lazy loading:** Load components and data only when needed
- **Efficient builds:** Use Nx caching and parallel builds
- **Database migrations:** Plan schema changes to avoid downtime

### 3. Monitoring & Alerts

- **Set usage alerts:** Monitor when approaching plan limits
- **Performance budgets:** Set targets for response times and resource usage
- **Error tracking:** Monitor and fix errors that cause resource waste
- **Regular reviews:** Monthly review of usage patterns and optimization opportunities

---

## 🔗 Navigation

**← Previous:** [Comparison Analysis](./comparison-analysis.md) | **Next:** [Troubleshooting](./troubleshooting.md) →

---

## 📚 References

- [Railway Production Best Practices](https://docs.railway.app/guides/production-checklist)
- [Node.js Production Best Practices](https://nodejs.org/en/docs/guides/nodejs-docker-webapp/)
- [Express.js Security Best Practices](https://expressjs.com/en/advanced/best-practice-security.html)
- [MySQL Performance Tuning](https://dev.mysql.com/doc/refman/8.0/en/optimization.html)