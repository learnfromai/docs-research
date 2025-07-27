# Implementation Guide: Express.js Production Best Practices

## 🎯 Implementation Overview

Step-by-step guide for implementing production-ready Express.js applications based on patterns and best practices observed in major open source projects. This guide provides actionable instructions for building secure, scalable, and maintainable Express.js applications.

## 🚀 Phase 1: Project Foundation (Week 1-2)

### 1.1 Project Initialization

**Step 1: Create Project Structure**
```bash
# Initialize project with TypeScript
mkdir express-production-app
cd express-production-app
npm init -y

# Install core dependencies
npm install express cors helmet compression morgan winston
npm install @types/express @types/cors @types/node typescript ts-node nodemon --save-dev

# Setup TypeScript configuration
npx tsc --init
```

**Step 2: Configure TypeScript**
```json
// tsconfig.json
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "commonjs",
    "lib": ["ES2020"],
    "outDir": "./dist",
    "rootDir": "./src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "experimentalDecorators": true,
    "emitDecoratorMetadata": true,
    "sourceMap": true,
    "declaration": true,
    "removeComments": true
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist", "tests"]
}
```

**Step 3: Project Structure Setup**
```
src/
├── app.ts                     # Express app configuration
├── index.ts                   # Entry point
├── config/                    # Configuration management
│   ├── database.ts
│   ├── redis.ts
│   └── environment.ts
├── controllers/               # Route handlers
├── middleware/                # Custom middleware
├── models/                    # Data models
├── repositories/              # Data access layer
├── services/                  # Business logic
├── utils/                     # Utility functions
├── types/                     # TypeScript type definitions
└── validation/                # Input validation schemas
```

### 1.2 Environment Configuration

**Step 1: Environment Variables Setup**
```typescript
// src/config/environment.ts
import dotenv from 'dotenv';
import Joi from 'joi';

// Load environment files
const nodeEnv = process.env.NODE_ENV || 'development';
dotenv.config({ path: `.env.${nodeEnv}` });
dotenv.config({ path: '.env.local' });
dotenv.config({ path: '.env' });

// Validation schema
const envSchema = Joi.object({
  NODE_ENV: Joi.string().valid('development', 'testing', 'production').default('development'),
  PORT: Joi.number().default(3000),
  
  // Database
  DATABASE_URL: Joi.string().required(),
  DATABASE_MAX_CONNECTIONS: Joi.number().default(20),
  
  // Redis
  REDIS_URL: Joi.string().required(),
  
  // JWT
  JWT_SECRET: Joi.string().required(),
  JWT_EXPIRES_IN: Joi.string().default('15m'),
  REFRESH_TOKEN_SECRET: Joi.string().required(),
  REFRESH_TOKEN_EXPIRES_IN: Joi.string().default('7d'),
  
  // Logging
  LOG_LEVEL: Joi.string().valid('error', 'warn', 'info', 'debug').default('info'),
  
  // Rate limiting
  RATE_LIMIT_WINDOW_MS: Joi.number().default(900000), // 15 minutes
  RATE_LIMIT_MAX_REQUESTS: Joi.number().default(100),
  
  // CORS
  ALLOWED_ORIGINS: Joi.string().default('http://localhost:3000'),
  
  // Security
  BCRYPT_SALT_ROUNDS: Joi.number().default(12),
  
  // Monitoring
  ENABLE_METRICS: Joi.boolean().default(false),
  METRICS_PORT: Joi.number().default(9090)
}).unknown();

const { error, value: env } = envSchema.validate(process.env);

if (error) {
  throw new Error(`Environment validation error: ${error.message}`);
}

export const config = {
  env: env.NODE_ENV,
  port: env.PORT,
  database: {
    url: env.DATABASE_URL,
    maxConnections: env.DATABASE_MAX_CONNECTIONS
  },
  redis: {
    url: env.REDIS_URL
  },
  jwt: {
    secret: env.JWT_SECRET,
    expiresIn: env.JWT_EXPIRES_IN,
    refreshTokenSecret: env.REFRESH_TOKEN_SECRET,
    refreshTokenExpiresIn: env.REFRESH_TOKEN_EXPIRES_IN
  },
  logging: {
    level: env.LOG_LEVEL
  },
  rateLimit: {
    windowMs: env.RATE_LIMIT_WINDOW_MS,
    maxRequests: env.RATE_LIMIT_MAX_REQUESTS
  },
  cors: {
    allowedOrigins: env.ALLOWED_ORIGINS.split(',')
  },
  security: {
    bcryptSaltRounds: env.BCRYPT_SALT_ROUNDS
  },
  monitoring: {
    enableMetrics: env.ENABLE_METRICS,
    metricsPort: env.METRICS_PORT
  }
};
```

**Step 2: Create Environment Files**
```bash
# .env.development
NODE_ENV=development
PORT=3000
DATABASE_URL=postgresql://localhost:5432/myapp_dev
REDIS_URL=redis://localhost:6379
JWT_SECRET=your-development-jwt-secret
REFRESH_TOKEN_SECRET=your-development-refresh-secret
LOG_LEVEL=debug
ALLOWED_ORIGINS=http://localhost:3000,http://localhost:3001

# .env.production
NODE_ENV=production
PORT=3000
# Use environment variables or secrets manager for production values
```

### 1.3 Logging Setup

**Step 1: Configure Winston Logger**
```typescript
// src/config/logger.ts
import winston from 'winston';
import 'winston-daily-rotate-file';
import { config } from './environment';

const logFormat = winston.format.combine(
  winston.format.timestamp(),
  winston.format.errors({ stack: true }),
  winston.format.json()
);

const logger = winston.createLogger({
  level: config.logging.level,
  format: logFormat,
  defaultMeta: { 
    service: 'express-app',
    version: process.env.npm_package_version || '1.0.0'
  },
  transports: []
});

// Console transport for development
if (config.env !== 'production') {
  logger.add(new winston.transports.Console({
    format: winston.format.combine(
      winston.format.colorize(),
      winston.format.simple()
    )
  }));
}

// File transports for production
if (config.env === 'production') {
  // Application logs
  logger.add(new winston.transports.DailyRotateFile({
    filename: 'logs/application-%DATE%.log',
    datePattern: 'YYYY-MM-DD',
    maxSize: '20m',
    maxFiles: '14d',
    level: 'info'
  }));

  // Error logs
  logger.add(new winston.transports.DailyRotateFile({
    filename: 'logs/error-%DATE%.log',
    datePattern: 'YYYY-MM-DD',
    maxSize: '20m',
    maxFiles: '30d',
    level: 'error'
  }));
}

export { logger };

// Request logging middleware
export const requestLogger = (req: any, res: any, next: any) => {
  const start = Date.now();
  
  res.on('finish', () => {
    const duration = Date.now() - start;
    logger.info('HTTP Request', {
      method: req.method,
      url: req.url,
      statusCode: res.statusCode,
      responseTime: duration,
      userAgent: req.get('User-Agent'),
      ip: req.ip,
      userId: req.user?.id
    });
  });
  
  next();
};
```

## 🔐 Phase 2: Security Implementation (Week 2-3)

### 2.1 Authentication System

**Step 1: JWT Service Implementation**
```typescript
// src/services/auth.service.ts
import jwt from 'jsonwebtoken';
import bcrypt from 'bcrypt';
import { config } from '../config/environment';
import { logger } from '../config/logger';

export interface TokenPair {
  accessToken: string;
  refreshToken: string;
}

export interface JWTPayload {
  sub: string;
  email: string;
  roles: string[];
  iat: number;
  exp: number;
}

export class AuthService {
  async hashPassword(password: string): Promise<string> {
    return bcrypt.hash(password, config.security.bcryptSaltRounds);
  }

  async verifyPassword(password: string, hashedPassword: string): Promise<boolean> {
    return bcrypt.compare(password, hashedPassword);
  }

  generateTokenPair(user: { id: string; email: string; roles: string[] }): TokenPair {
    const payload = {
      sub: user.id,
      email: user.email,
      roles: user.roles
    };

    const accessToken = jwt.sign(payload, config.jwt.secret, {
      expiresIn: config.jwt.expiresIn,
      issuer: 'express-app',
      audience: 'express-app-users'
    });

    const refreshToken = jwt.sign(
      { sub: user.id }, 
      config.jwt.refreshTokenSecret,
      {
        expiresIn: config.jwt.refreshTokenExpiresIn,
        issuer: 'express-app',
        audience: 'express-app-users'
      }
    );

    return { accessToken, refreshToken };
  }

  verifyAccessToken(token: string): JWTPayload {
    try {
      return jwt.verify(token, config.jwt.secret, {
        issuer: 'express-app',
        audience: 'express-app-users'
      }) as JWTPayload;
    } catch (error) {
      logger.error('Access token verification failed', { error: error.message });
      throw new Error('Invalid access token');
    }
  }

  verifyRefreshToken(token: string): { sub: string } {
    try {
      return jwt.verify(token, config.jwt.refreshTokenSecret, {
        issuer: 'express-app',
        audience: 'express-app-users'
      }) as { sub: string };
    } catch (error) {
      logger.error('Refresh token verification failed', { error: error.message });
      throw new Error('Invalid refresh token');
    }
  }

  async authenticateUser(email: string, password: string): Promise<any> {
    // This would integrate with your user repository
    // const user = await this.userRepository.findByEmail(email);
    // if (!user || !await this.verifyPassword(password, user.passwordHash)) {
    //   throw new Error('Invalid credentials');
    // }
    // return user;
    
    // Placeholder implementation
    throw new Error('Not implemented');
  }
}
```

**Step 2: Authentication Middleware**
```typescript
// src/middleware/auth.middleware.ts
import { Request, Response, NextFunction } from 'express';
import { AuthService } from '../services/auth.service';
import { logger } from '../config/logger';

const authService = new AuthService();

export interface AuthenticatedRequest extends Request {
  user?: {
    id: string;
    email: string;
    roles: string[];
  };
}

export const authenticateJWT = (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  const authHeader = req.headers.authorization;
  
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Access token required' });
  }

  const token = authHeader.substring(7);

  try {
    const payload = authService.verifyAccessToken(token);
    req.user = {
      id: payload.sub,
      email: payload.email,
      roles: payload.roles
    };
    next();
  } catch (error) {
    logger.warn('Authentication failed', { 
      error: error.message,
      ip: req.ip,
      userAgent: req.get('User-Agent')
    });
    return res.status(401).json({ error: 'Invalid token' });
  }
};

export const requireRoles = (roles: string[]) => {
  return (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
    if (!req.user) {
      return res.status(401).json({ error: 'Authentication required' });
    }

    const hasRole = roles.some(role => req.user!.roles.includes(role));
    if (!hasRole) {
      logger.warn('Authorization failed', {
        userId: req.user.id,
        requiredRoles: roles,
        userRoles: req.user.roles
      });
      return res.status(403).json({ error: 'Insufficient permissions' });
    }

    next();
  };
};
```

### 2.2 Input Validation

**Step 1: Validation Schemas**
```typescript
// src/validation/user.validation.ts
import Joi from 'joi';

export const createUserSchema = Joi.object({
  email: Joi.string().email().required().messages({
    'string.email': 'Please provide a valid email address',
    'any.required': 'Email is required'
  }),
  password: Joi.string()
    .min(8)
    .pattern(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]/)
    .required()
    .messages({
      'string.min': 'Password must be at least 8 characters long',
      'string.pattern.base': 'Password must contain uppercase, lowercase, number and special character',
      'any.required': 'Password is required'
    }),
  firstName: Joi.string().min(2).max(50).required().messages({
    'string.min': 'First name must be at least 2 characters',
    'string.max': 'First name cannot exceed 50 characters',
    'any.required': 'First name is required'
  }),
  lastName: Joi.string().min(2).max(50).required().messages({
    'string.min': 'Last name must be at least 2 characters',
    'string.max': 'Last name cannot exceed 50 characters',
    'any.required': 'Last name is required'
  })
});

export const updateUserSchema = Joi.object({
  firstName: Joi.string().min(2).max(50),
  lastName: Joi.string().min(2).max(50),
  email: Joi.string().email()
}).min(1).messages({
  'object.min': 'At least one field must be provided for update'
});

export const loginSchema = Joi.object({
  email: Joi.string().email().required(),
  password: Joi.string().required()
});
```

**Step 2: Validation Middleware**
```typescript
// src/middleware/validation.middleware.ts
import { Request, Response, NextFunction } from 'express';
import Joi from 'joi';
import { logger } from '../config/logger';

export const validate = (schema: Joi.ObjectSchema, property: 'body' | 'query' | 'params' = 'body') => {
  return (req: Request, res: Response, next: NextFunction) => {
    const { error, value } = schema.validate(req[property], {
      abortEarly: false,
      stripUnknown: true,
      convert: true
    });

    if (error) {
      const validationErrors = error.details.map(detail => ({
        field: detail.path.join('.'),
        message: detail.message,
        value: detail.context?.value
      }));

      logger.warn('Validation failed', {
        errors: validationErrors,
        originalValue: req[property],
        ip: req.ip
      });

      return res.status(400).json({
        error: 'Validation failed',
        details: validationErrors
      });
    }

    req[property] = value;
    next();
  };
};

// XSS protection middleware
export const sanitizeInput = (req: Request, res: Response, next: NextFunction) => {
  const sanitizeValue = (value: any): any => {
    if (typeof value === 'string') {
      return value
        .replace(/[<>]/g, '') // Remove angle brackets
        .trim();
    }
    if (Array.isArray(value)) {
      return value.map(sanitizeValue);
    }
    if (value && typeof value === 'object') {
      const sanitized: any = {};
      for (const [key, val] of Object.entries(value)) {
        sanitized[key] = sanitizeValue(val);
      }
      return sanitized;
    }
    return value;
  };

  req.body = sanitizeValue(req.body);
  req.query = sanitizeValue(req.query);
  req.params = sanitizeValue(req.params);

  next();
};
```

### 2.3 Rate Limiting

**Step 1: Rate Limiting Setup**
```typescript
// src/middleware/rate-limit.middleware.ts
import rateLimit from 'express-rate-limit';
import slowDown from 'express-slow-down';
import RedisStore from 'rate-limit-redis';
import Redis from 'ioredis';
import { config } from '../config/environment';
import { logger } from '../config/logger';

const redisClient = new Redis(config.redis.url);

// Global rate limiting
export const globalLimiter = rateLimit({
  store: new RedisStore({
    client: redisClient,
    prefix: 'global:',
  }),
  windowMs: config.rateLimit.windowMs,
  max: config.rateLimit.maxRequests,
  message: {
    error: 'Too many requests from this IP',
    retryAfter: Math.ceil(config.rateLimit.windowMs / 1000)
  },
  standardHeaders: true,
  legacyHeaders: false,
  skip: (req) => {
    // Skip rate limiting for health checks
    return req.path === '/health';
  },
  onLimitReached: (req) => {
    logger.warn('Rate limit reached', {
      ip: req.ip,
      userAgent: req.get('User-Agent'),
      path: req.path
    });
  }
});

// Authentication endpoints rate limiting
export const authLimiter = rateLimit({
  store: new RedisStore({
    client: redisClient,
    prefix: 'auth:',
  }),
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 5, // Limit each IP to 5 requests per windowMs
  skipSuccessfulRequests: true,
  message: {
    error: 'Too many authentication attempts, please try again later'
  }
});

// API rate limiting with progressive delay
export const apiSlowDown = slowDown({
  store: new RedisStore({
    client: redisClient,
    prefix: 'slowdown:',
  }),
  windowMs: 15 * 60 * 1000, // 15 minutes
  delayAfter: 10, // Allow 10 requests at full speed
  delayMs: 500, // Add 500ms delay per request after delayAfter
  maxDelayMs: 20000 // Maximum delay of 20 seconds
});
```

## 🗄️ Phase 3: Database Integration (Week 3-4)

### 3.1 Database Setup

**Step 1: Database Configuration**
```typescript
// src/config/database.ts
import { Pool, PoolConfig } from 'pg';
import { config } from './environment';
import { logger } from './logger';

class DatabaseService {
  private pool: Pool;

  constructor() {
    const poolConfig: PoolConfig = {
      connectionString: config.database.url,
      max: config.database.maxConnections,
      idleTimeoutMillis: 30000,
      connectionTimeoutMillis: 2000,
      ssl: config.env === 'production' ? { rejectUnauthorized: false } : false
    };

    this.pool = new Pool(poolConfig);
    this.setupEventListeners();
  }

  private setupEventListeners(): void {
    this.pool.on('connect', (client) => {
      logger.info('New database connection established');
    });

    this.pool.on('error', (err, client) => {
      logger.error('Database pool error', { error: err.message });
    });

    this.pool.on('remove', (client) => {
      logger.info('Database connection removed from pool');
    });
  }

  async query(text: string, params?: any[]): Promise<any> {
    const start = Date.now();
    try {
      const result = await this.pool.query(text, params);
      const duration = Date.now() - start;
      
      if (duration > 1000) {
        logger.warn('Slow query detected', {
          duration,
          query: text,
          params
        });
      }
      
      return result;
    } catch (error) {
      logger.error('Database query error', {
        error: error.message,
        query: text,
        params
      });
      throw error;
    }
  }

  async transaction<T>(callback: (client: any) => Promise<T>): Promise<T> {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      const result = await callback(client);
      await client.query('COMMIT');
      return result;
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }

  async close(): Promise<void> {
    await this.pool.end();
  }

  async healthCheck(): Promise<boolean> {
    try {
      await this.query('SELECT 1');
      return true;
    } catch (error) {
      logger.error('Database health check failed', { error: error.message });
      return false;
    }
  }
}

export const database = new DatabaseService();
```

**Step 2: Repository Pattern Implementation**
```typescript
// src/repositories/user.repository.ts
import { database } from '../config/database';
import { logger } from '../config/logger';

export interface User {
  id: string;
  email: string;
  passwordHash: string;
  firstName: string;
  lastName: string;
  roles: string[];
  isActive: boolean;
  createdAt: Date;
  updatedAt: Date;
}

export interface CreateUserData {
  email: string;
  passwordHash: string;
  firstName: string;
  lastName: string;
  roles?: string[];
}

export interface UpdateUserData {
  email?: string;
  firstName?: string;
  lastName?: string;
  roles?: string[];
  isActive?: boolean;
}

export class UserRepository {
  async create(userData: CreateUserData): Promise<User> {
    const query = `
      INSERT INTO users (email, password_hash, first_name, last_name, roles, created_at, updated_at)
      VALUES ($1, $2, $3, $4, $5, NOW(), NOW())
      RETURNING *
    `;
    
    const values = [
      userData.email,
      userData.passwordHash,
      userData.firstName,
      userData.lastName,
      JSON.stringify(userData.roles || ['user'])
    ];

    try {
      const result = await database.query(query, values);
      return this.mapRowToUser(result.rows[0]);
    } catch (error) {
      logger.error('Failed to create user', { 
        error: error.message,
        userData: { ...userData, passwordHash: '[REDACTED]' }
      });
      throw error;
    }
  }

  async findById(id: string): Promise<User | null> {
    const query = 'SELECT * FROM users WHERE id = $1';
    const result = await database.query(query, [id]);
    return result.rows[0] ? this.mapRowToUser(result.rows[0]) : null;
  }

  async findByEmail(email: string): Promise<User | null> {
    const query = 'SELECT * FROM users WHERE email = $1';
    const result = await database.query(query, [email]);
    return result.rows[0] ? this.mapRowToUser(result.rows[0]) : null;
  }

  async update(id: string, updateData: UpdateUserData): Promise<User> {
    const setClauses: string[] = [];
    const values: any[] = [];
    let paramIndex = 1;

    Object.entries(updateData).forEach(([key, value]) => {
      if (value !== undefined) {
        if (key === 'roles') {
          setClauses.push(`roles = $${paramIndex}`);
          values.push(JSON.stringify(value));
        } else {
          const columnName = this.camelToSnake(key);
          setClauses.push(`${columnName} = $${paramIndex}`);
          values.push(value);
        }
        paramIndex++;
      }
    });

    if (setClauses.length === 0) {
      throw new Error('No fields to update');
    }

    setClauses.push(`updated_at = NOW()`);
    values.push(id);

    const query = `
      UPDATE users 
      SET ${setClauses.join(', ')}
      WHERE id = $${paramIndex}
      RETURNING *
    `;

    try {
      const result = await database.query(query, values);
      if (result.rows.length === 0) {
        throw new Error('User not found');
      }
      return this.mapRowToUser(result.rows[0]);
    } catch (error) {
      logger.error('Failed to update user', { 
        error: error.message,
        userId: id,
        updateData 
      });
      throw error;
    }
  }

  async delete(id: string): Promise<void> {
    const query = 'DELETE FROM users WHERE id = $1';
    const result = await database.query(query, [id]);
    
    if (result.rowCount === 0) {
      throw new Error('User not found');
    }
  }

  async findMany(offset: number = 0, limit: number = 50): Promise<User[]> {
    const query = `
      SELECT * FROM users 
      ORDER BY created_at DESC 
      OFFSET $1 LIMIT $2
    `;
    const result = await database.query(query, [offset, limit]);
    return result.rows.map(this.mapRowToUser);
  }

  async count(): Promise<number> {
    const query = 'SELECT COUNT(*) FROM users';
    const result = await database.query(query);
    return parseInt(result.rows[0].count);
  }

  private mapRowToUser(row: any): User {
    return {
      id: row.id,
      email: row.email,
      passwordHash: row.password_hash,
      firstName: row.first_name,
      lastName: row.last_name,
      roles: JSON.parse(row.roles || '["user"]'),
      isActive: row.is_active,
      createdAt: row.created_at,
      updatedAt: row.updated_at
    };
  }

  private camelToSnake(str: string): string {
    return str.replace(/[A-Z]/g, letter => `_${letter.toLowerCase()}`);
  }
}
```

### 3.2 Database Migrations

**Step 1: Migration System**
```typescript
// src/migrations/001_create_users_table.sql
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    roles JSONB DEFAULT '["user"]',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_created_at ON users(created_at);
CREATE INDEX idx_users_roles ON users USING GIN(roles);

-- Migration script runner
// scripts/migrate.ts
import fs from 'fs';
import path from 'path';
import { database } from '../src/config/database';
import { logger } from '../src/config/logger';

interface Migration {
  id: number;
  filename: string;
  sql: string;
}

class MigrationRunner {
  async createMigrationsTable(): Promise<void> {
    const query = `
      CREATE TABLE IF NOT EXISTS migrations (
        id SERIAL PRIMARY KEY,
        filename VARCHAR(255) NOT NULL UNIQUE,
        executed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
      )
    `;
    await database.query(query);
  }

  async getExecutedMigrations(): Promise<string[]> {
    const query = 'SELECT filename FROM migrations ORDER BY id';
    const result = await database.query(query);
    return result.rows.map(row => row.filename);
  }

  async getMigrationFiles(): Promise<Migration[]> {
    const migrationsDir = path.join(__dirname, '../src/migrations');
    const files = fs.readdirSync(migrationsDir)
      .filter(file => file.endsWith('.sql'))
      .sort();

    return files.map((filename, index) => ({
      id: index + 1,
      filename,
      sql: fs.readFileSync(path.join(migrationsDir, filename), 'utf8')
    }));
  }

  async runMigrations(): Promise<void> {
    await this.createMigrationsTable();
    
    const executedMigrations = await this.getExecutedMigrations();
    const allMigrations = await this.getMigrationFiles();
    
    const pendingMigrations = allMigrations.filter(
      migration => !executedMigrations.includes(migration.filename)
    );

    if (pendingMigrations.length === 0) {
      logger.info('No pending migrations');
      return;
    }

    for (const migration of pendingMigrations) {
      try {
        await database.transaction(async (client) => {
          logger.info(`Running migration: ${migration.filename}`);
          await client.query(migration.sql);
          await client.query(
            'INSERT INTO migrations (filename) VALUES ($1)',
            [migration.filename]
          );
        });
        logger.info(`Migration completed: ${migration.filename}`);
      } catch (error) {
        logger.error(`Migration failed: ${migration.filename}`, { error: error.message });
        throw error;
      }
    }

    logger.info(`Completed ${pendingMigrations.length} migrations`);
  }
}

// CLI runner
if (require.main === module) {
  const runner = new MigrationRunner();
  runner.runMigrations()
    .then(() => {
      console.log('Migrations completed successfully');
      process.exit(0);
    })
    .catch((error) => {
      console.error('Migration failed:', error);
      process.exit(1);
    });
}
```

## 🎮 Phase 4: Application Layer (Week 4-5)

### 4.1 Service Layer Implementation

**Step 1: User Service**
```typescript
// src/services/user.service.ts
import { UserRepository, User, CreateUserData, UpdateUserData } from '../repositories/user.repository';
import { AuthService } from './auth.service';
import { logger } from '../config/logger';

export interface CreateUserRequest {
  email: string;
  password: string;
  firstName: string;
  lastName: string;
}

export interface UserResponse {
  id: string;
  email: string;
  firstName: string;
  lastName: string;
  roles: string[];
  isActive: boolean;
  createdAt: Date;
  updatedAt: Date;
}

export class UserService {
  constructor(
    private userRepository: UserRepository,
    private authService: AuthService
  ) {}

  async createUser(userData: CreateUserRequest): Promise<UserResponse> {
    // Check if user already exists
    const existingUser = await this.userRepository.findByEmail(userData.email);
    if (existingUser) {
      throw new Error('User with this email already exists');
    }

    // Hash password
    const passwordHash = await this.authService.hashPassword(userData.password);

    // Create user
    const createData: CreateUserData = {
      email: userData.email,
      passwordHash,
      firstName: userData.firstName,
      lastName: userData.lastName,
      roles: ['user']
    };

    const user = await this.userRepository.create(createData);
    
    logger.info('User created', { 
      userId: user.id, 
      email: user.email 
    });

    return this.mapToResponse(user);
  }

  async getUserById(id: string): Promise<UserResponse | null> {
    const user = await this.userRepository.findById(id);
    return user ? this.mapToResponse(user) : null;
  }

  async getUserByEmail(email: string): Promise<UserResponse | null> {
    const user = await this.userRepository.findByEmail(email);
    return user ? this.mapToResponse(user) : null;
  }

  async updateUser(id: string, updateData: Partial<UpdateUserData>): Promise<UserResponse> {
    const user = await this.userRepository.update(id, updateData);
    
    logger.info('User updated', { 
      userId: id, 
      updatedFields: Object.keys(updateData) 
    });

    return this.mapToResponse(user);
  }

  async deleteUser(id: string): Promise<void> {
    await this.userRepository.delete(id);
    
    logger.info('User deleted', { userId: id });
  }

  async getUsers(page: number = 1, limit: number = 50): Promise<{
    users: UserResponse[];
    pagination: {
      page: number;
      limit: number;
      total: number;
      totalPages: number;
    };
  }> {
    const offset = (page - 1) * limit;
    const [users, total] = await Promise.all([
      this.userRepository.findMany(offset, limit),
      this.userRepository.count()
    ]);

    return {
      users: users.map(this.mapToResponse),
      pagination: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit)
      }
    };
  }

  async authenticateUser(email: string, password: string): Promise<UserResponse> {
    const user = await this.userRepository.findByEmail(email);
    if (!user) {
      throw new Error('Invalid credentials');
    }

    if (!user.isActive) {
      throw new Error('Account is deactivated');
    }

    const isValidPassword = await this.authService.verifyPassword(password, user.passwordHash);
    if (!isValidPassword) {
      throw new Error('Invalid credentials');
    }

    logger.info('User authenticated', { 
      userId: user.id, 
      email: user.email 
    });

    return this.mapToResponse(user);
  }

  private mapToResponse(user: User): UserResponse {
    return {
      id: user.id,
      email: user.email,
      firstName: user.firstName,
      lastName: user.lastName,
      roles: user.roles,
      isActive: user.isActive,
      createdAt: user.createdAt,
      updatedAt: user.updatedAt
    };
  }
}
```

### 4.2 Controller Implementation

**Step 1: User Controller**
```typescript
// src/controllers/user.controller.ts
import { Request, Response, NextFunction } from 'express';
import { UserService } from '../services/user.service';
import { AuthService, TokenPair } from '../services/auth.service';
import { AuthenticatedRequest } from '../middleware/auth.middleware';
import { logger } from '../config/logger';

export class UserController {
  constructor(
    private userService: UserService,
    private authService: AuthService
  ) {}

  register = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const user = await this.userService.createUser(req.body);
      const tokens = this.authService.generateTokenPair(user);

      res.status(201).json({
        message: 'User created successfully',
        data: user,
        tokens
      });
    } catch (error) {
      next(error);
    }
  };

  login = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const { email, password } = req.body;
      const user = await this.userService.authenticateUser(email, password);
      const tokens = this.authService.generateTokenPair(user);

      res.json({
        message: 'Login successful',
        data: user,
        tokens
      });
    } catch (error) {
      next(error);
    }
  };

  getProfile = async (req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> => {
    try {
      const user = await this.userService.getUserById(req.user!.id);
      if (!user) {
        return res.status(404).json({ error: 'User not found' });
      }

      res.json({
        message: 'Profile retrieved successfully',
        data: user
      });
    } catch (error) {
      next(error);
    }
  };

  updateProfile = async (req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> => {
    try {
      const user = await this.userService.updateUser(req.user!.id, req.body);

      res.json({
        message: 'Profile updated successfully',
        data: user
      });
    } catch (error) {
      next(error);
    }
  };

  getUsers = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const page = parseInt(req.query.page as string) || 1;
      const limit = parseInt(req.query.limit as string) || 50;

      const result = await this.userService.getUsers(page, limit);

      res.json({
        message: 'Users retrieved successfully',
        data: result.users,
        pagination: result.pagination
      });
    } catch (error) {
      next(error);
    }
  };

  getUserById = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const user = await this.userService.getUserById(req.params.id);
      if (!user) {
        return res.status(404).json({ error: 'User not found' });
      }

      res.json({
        message: 'User retrieved successfully',
        data: user
      });
    } catch (error) {
      next(error);
    }
  };

  deleteUser = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      await this.userService.deleteUser(req.params.id);

      res.json({
        message: 'User deleted successfully'
      });
    } catch (error) {
      next(error);
    }
  };
}
```

### 4.3 Router Configuration

**Step 1: User Routes**
```typescript
// src/routes/user.routes.ts
import { Router } from 'express';
import { UserController } from '../controllers/user.controller';
import { UserService } from '../services/user.service';
import { AuthService } from '../services/auth.service';
import { UserRepository } from '../repositories/user.repository';
import { authenticateJWT, requireRoles } from '../middleware/auth.middleware';
import { validate, sanitizeInput } from '../middleware/validation.middleware';
import { authLimiter } from '../middleware/rate-limit.middleware';
import { 
  createUserSchema, 
  updateUserSchema, 
  loginSchema 
} from '../validation/user.validation';

// Dependency injection
const userRepository = new UserRepository();
const authService = new AuthService();
const userService = new UserService(userRepository, authService);
const userController = new UserController(userService, authService);

const router = Router();

// Public routes
router.post('/register', 
  authLimiter,
  sanitizeInput,
  validate(createUserSchema),
  userController.register
);

router.post('/login', 
  authLimiter,
  sanitizeInput,
  validate(loginSchema),
  userController.login
);

// Protected routes
router.get('/profile', 
  authenticateJWT,
  userController.getProfile
);

router.put('/profile', 
  authenticateJWT,
  sanitizeInput,
  validate(updateUserSchema),
  userController.updateProfile
);

// Admin routes
router.get('/', 
  authenticateJWT,
  requireRoles(['admin']),
  userController.getUsers
);

router.get('/:id', 
  authenticateJWT,
  requireRoles(['admin']),
  userController.getUserById
);

router.delete('/:id', 
  authenticateJWT,
  requireRoles(['admin']),
  userController.deleteUser
);

export { router as userRoutes };
```

## 🌐 Phase 5: Application Assembly (Week 5-6)

### 5.1 Main Application Setup

**Step 1: Express App Configuration**
```typescript
// src/app.ts
import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import compression from 'compression';
import { config } from './config/environment';
import { logger, requestLogger } from './config/logger';
import { globalLimiter, apiSlowDown } from './middleware/rate-limit.middleware';
import { userRoutes } from './routes/user.routes';

// Error handling middleware
import { errorHandler, notFoundHandler } from './middleware/error.middleware';

export function createApp(): express.Application {
  const app = express();

  // Security middleware
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
    crossOriginEmbedderPolicy: false
  }));

  // CORS configuration
  app.use(cors({
    origin: config.cors.allowedOrigins,
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With'],
    exposedHeaders: ['X-Total-Count', 'X-Rate-Limit-Remaining']
  }));

  // Compression
  app.use(compression());

  // Request parsing
  app.use(express.json({ limit: '10mb' }));
  app.use(express.urlencoded({ extended: true, limit: '10mb' }));

  // Request logging
  app.use(requestLogger);

  // Rate limiting
  app.use(globalLimiter);
  app.use(apiSlowDown);

  // Health check endpoint
  app.get('/health', (req, res) => {
    res.json({
      status: 'healthy',
      timestamp: new Date().toISOString(),
      version: process.env.npm_package_version || '1.0.0'
    });
  });

  // API routes
  app.use('/api/users', userRoutes);

  // Error handling
  app.use(notFoundHandler);
  app.use(errorHandler);

  return app;
}
```

**Step 2: Error Handling Middleware**
```typescript
// src/middleware/error.middleware.ts
import { Request, Response, NextFunction } from 'express';
import { logger } from '../config/logger';
import { config } from '../config/environment';

export interface AppError extends Error {
  statusCode?: number;
  status?: string;
  isOperational?: boolean;
}

export const notFoundHandler = (req: Request, res: Response, next: NextFunction): void => {
  res.status(404).json({
    error: 'Resource not found',
    path: req.path,
    method: req.method
  });
};

export const errorHandler = (
  err: AppError,
  req: Request,
  res: Response,
  next: NextFunction
): void => {
  const statusCode = err.statusCode || 500;
  const isProduction = config.env === 'production';

  // Log error
  logger.error('Application error', {
    error: err.message,
    stack: err.stack,
    url: req.url,
    method: req.method,
    ip: req.ip,
    userAgent: req.get('User-Agent'),
    userId: (req as any).user?.id
  });

  // Prepare error response
  const errorResponse: any = {
    error: err.message || 'Internal server error',
    status: statusCode,
    timestamp: new Date().toISOString()
  };

  // Add stack trace in development
  if (!isProduction) {
    errorResponse.stack = err.stack;
    errorResponse.path = req.path;
    errorResponse.method = req.method;
  }

  // Handle specific error types
  if (err.name === 'ValidationError') {
    errorResponse.error = 'Validation failed';
    errorResponse.details = err.message;
  } else if (err.name === 'CastError') {
    errorResponse.error = 'Invalid ID format';
  } else if (err.name === 'MongoError' && (err as any).code === 11000) {
    errorResponse.error = 'Duplicate field value';
  } else if (err.name === 'JsonWebTokenError') {
    errorResponse.error = 'Invalid token';
  } else if (err.name === 'TokenExpiredError') {
    errorResponse.error = 'Token expired';
  }

  res.status(statusCode).json(errorResponse);
};

// Create custom error classes
export class BadRequestError extends Error {
  statusCode = 400;
  isOperational = true;

  constructor(message: string) {
    super(message);
    this.name = 'BadRequestError';
  }
}

export class UnauthorizedError extends Error {
  statusCode = 401;
  isOperational = true;

  constructor(message: string = 'Unauthorized') {
    super(message);
    this.name = 'UnauthorizedError';
  }
}

export class ForbiddenError extends Error {
  statusCode = 403;
  isOperational = true;

  constructor(message: string = 'Forbidden') {
    super(message);
    this.name = 'ForbiddenError';
  }
}

export class NotFoundError extends Error {
  statusCode = 404;
  isOperational = true;

  constructor(message: string = 'Not found') {
    super(message);
    this.name = 'NotFoundError';
  }
}

export class ConflictError extends Error {
  statusCode = 409;
  isOperational = true;

  constructor(message: string = 'Conflict') {
    super(message);
    this.name = 'ConflictError';
  }
}
```

**Step 3: Server Entry Point**
```typescript
// src/index.ts
import { createApp } from './app';
import { config } from './config/environment';
import { logger } from './config/logger';
import { database } from './config/database';

// Handle uncaught exceptions
process.on('uncaughtException', (err) => {
  logger.error('Uncaught Exception', { error: err.message, stack: err.stack });
  process.exit(1);
});

process.on('unhandledRejection', (reason, promise) => {
  logger.error('Unhandled Rejection', { reason, promise });
  process.exit(1);
});

async function startServer(): Promise<void> {
  try {
    // Check database connection
    const isDbHealthy = await database.healthCheck();
    if (!isDbHealthy) {
      throw new Error('Database connection failed');
    }

    // Create Express app
    const app = createApp();

    // Start server
    const server = app.listen(config.port, () => {
      logger.info(`Server started on port ${config.port}`, {
        environment: config.env,
        port: config.port,
        nodeVersion: process.version
      });
    });

    // Graceful shutdown
    const gracefulShutdown = (signal: string) => {
      logger.info(`Received ${signal}. Starting graceful shutdown...`);
      
      server.close(async () => {
        logger.info('HTTP server closed');
        
        try {
          await database.close();
          logger.info('Database connections closed');
          process.exit(0);
        } catch (error) {
          logger.error('Error during shutdown', { error: error.message });
          process.exit(1);
        }
      });
    };

    process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
    process.on('SIGINT', () => gracefulShutdown('SIGINT'));

  } catch (error) {
    logger.error('Failed to start server', { error: error.message });
    process.exit(1);
  }
}

startServer();
```

### 5.2 Package.json Scripts

**Step 1: Development Scripts**
```json
{
  "name": "express-production-app",
  "version": "1.0.0",
  "description": "Production-ready Express.js application",
  "main": "dist/index.js",
  "scripts": {
    "dev": "nodemon --exec ts-node src/index.ts",
    "build": "tsc",
    "start": "node dist/index.js",
    "start:prod": "NODE_ENV=production node dist/index.js",
    "migrate": "ts-node scripts/migrate.ts",
    "migrate:prod": "NODE_ENV=production node dist/scripts/migrate.js",
    "test": "jest",
    "test:watch": "jest --watch",
    "test:coverage": "jest --coverage",
    "lint": "eslint src/**/*.ts",
    "lint:fix": "eslint src/**/*.ts --fix",
    "format": "prettier --write src/**/*.ts",
    "type-check": "tsc --noEmit",
    "clean": "rm -rf dist",
    "docker:build": "docker build -t express-app .",
    "docker:run": "docker run -p 3000:3000 express-app"
  },
  "dependencies": {
    "express": "^4.18.2",
    "cors": "^2.8.5",
    "helmet": "^7.1.0",
    "compression": "^1.7.4",
    "winston": "^3.11.0",
    "winston-daily-rotate-file": "^4.7.1",
    "morgan": "^1.10.0",
    "jsonwebtoken": "^9.0.2",
    "bcrypt": "^5.1.1",
    "joi": "^17.11.0",
    "pg": "^8.11.3",
    "ioredis": "^5.3.2",
    "express-rate-limit": "^7.1.5",
    "express-slow-down": "^2.0.1",
    "rate-limit-redis": "^4.2.0",
    "dotenv": "^16.3.1"
  },
  "devDependencies": {
    "@types/express": "^4.17.21",
    "@types/cors": "^2.8.17",
    "@types/node": "^20.10.4",
    "@types/jsonwebtoken": "^9.0.5",
    "@types/bcrypt": "^5.0.2",
    "@types/pg": "^8.10.9",
    "typescript": "^5.3.3",
    "ts-node": "^10.9.2",
    "nodemon": "^3.0.2",
    "jest": "^29.7.0",
    "@types/jest": "^29.5.8",
    "ts-jest": "^29.1.1",
    "eslint": "^8.55.0",
    "@typescript-eslint/parser": "^6.13.1",
    "@typescript-eslint/eslint-plugin": "^6.13.1",
    "prettier": "^3.1.0"
  }
}
```

### 5.3 Docker Configuration

**Step 1: Dockerfile**
```dockerfile
# Dockerfile
FROM node:18-alpine AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production

# Copy source code
COPY . .

# Build application
RUN npm run build

# Production stage
FROM node:18-alpine AS production

WORKDIR /app

# Create non-root user
RUN addgroup -g 1001 -S nodejs
RUN adduser -S expressjs -u 1001

# Copy built application
COPY --from=builder --chown=expressjs:nodejs /app/dist ./dist
COPY --from=builder --chown=expressjs:nodejs /app/node_modules ./node_modules
COPY --from=builder --chown=expressjs:nodejs /app/package*.json ./

# Create logs directory
RUN mkdir logs && chown expressjs:nodejs logs

# Switch to non-root user
USER expressjs

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/health', (res) => { process.exit(res.statusCode === 200 ? 0 : 1) })"

# Start application
CMD ["node", "dist/index.js"]
```

**Step 2: Docker Compose**
```yaml
# docker-compose.yml
version: '3.8'

services:
  app:
    build: .
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
      - DATABASE_URL=postgresql://postgres:password@postgres:5432/myapp
      - REDIS_URL=redis://redis:6379
    depends_on:
      - postgres
      - redis
    volumes:
      - ./logs:/app/logs
    restart: unless-stopped

  postgres:
    image: postgres:15-alpine
    environment:
      - POSTGRES_DB=myapp
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=password
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    restart: unless-stopped

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    restart: unless-stopped

volumes:
  postgres_data:
  redis_data:
```

---

## 🔗 Navigation

**Previous**: [Scalability Patterns](./scalability-patterns.md) | **Next**: [Best Practices](./best-practices.md)

---

## 📚 Next Steps

1. **Testing Implementation**: Add comprehensive test suite using Jest and Supertest
2. **Monitoring Setup**: Integrate Prometheus metrics and health checks
3. **CI/CD Pipeline**: Setup GitHub Actions or GitLab CI
4. **Documentation**: Add API documentation with Swagger
5. **Performance Optimization**: Implement caching and query optimization
6. **Security Hardening**: Add additional security measures and audit logging

This implementation guide provides a solid foundation for building production-ready Express.js applications using industry best practices from major open source projects.