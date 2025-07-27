# Implementation Guide: Building Production-Ready Express.js Applications

## 🎯 Quick Start Guide

This comprehensive implementation guide provides step-by-step instructions for building secure, scalable Express.js applications based on patterns found in successful open source projects.

---

## 🚀 Project Setup & Initialization

### 1. Project Structure Setup

```bash
# Create project directory
mkdir my-express-api
cd my-express-api

# Initialize npm project
npm init -y

# Install core dependencies
npm install express helmet cors compression express-rate-limit
npm install bcrypt jsonwebtoken passport passport-jwt
npm install joi winston morgan dotenv
npm install prisma @prisma/client
npm install redis ioredis

# Install development dependencies
npm install -D typescript @types/node @types/express
npm install -D @types/bcrypt @types/jsonwebtoken @types/morgan
npm install -D eslint @typescript-eslint/eslint-plugin @typescript-eslint/parser
npm install -D prettier eslint-config-prettier
npm install -D jest @types/jest ts-jest supertest @types/supertest
npm install -D tsx rimraf husky lint-staged

# Create directory structure
mkdir -p src/{controllers,services,models,middleware,routes,types,utils,config}
mkdir -p src/__tests__/{controllers,services,models,utils}
mkdir -p logs
```

### 2. TypeScript Configuration

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
    "declaration": true,
    "sourceMap": true,
    "baseUrl": "./src",
    "paths": {
      "@/*": ["*"],
      "@/controllers/*": ["controllers/*"],
      "@/services/*": ["services/*"],
      "@/models/*": ["models/*"],
      "@/middleware/*": ["middleware/*"],
      "@/types/*": ["types/*"],
      "@/utils/*": ["utils/*"],
      "@/config/*": ["config/*"]
    }
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist", "**/*.test.ts"]
}
```

### 3. Package.json Scripts

```json
{
  "scripts": {
    "build": "tsc",
    "start": "node dist/app.js",
    "dev": "tsx watch src/app.ts",
    "test": "jest",
    "test:watch": "jest --watch",
    "test:coverage": "jest --coverage",
    "lint": "eslint src/**/*.ts",
    "lint:fix": "eslint src/**/*.ts --fix",
    "format": "prettier --write src/**/*.ts",
    "type-check": "tsc --noEmit",
    "clean": "rimraf dist",
    "db:migrate": "prisma migrate dev",
    "db:generate": "prisma generate",
    "db:studio": "prisma studio",
    "prepare": "husky install"
  }
}
```

---

## 🏗️ Core Application Structure

### 1. Application Entry Point

```typescript
// src/app.ts
import express from 'express';
import helmet from 'helmet';
import cors from 'cors';
import compression from 'compression';
import rateLimit from 'express-rate-limit';

import { config } from '@/config/env';
import { logger } from '@/config/logger';
import { errorHandler } from '@/middleware/errorHandler';
import { requestLogger, requestId } from '@/middleware/logging';
import { authMiddleware } from '@/middleware/auth';
import { routes } from '@/routes';

const app = express();

// Trust proxy if behind reverse proxy
app.set('trust proxy', 1);

// Security middleware
app.use(helmet({
  contentSecurityPolicy: process.env.NODE_ENV === 'production',
  crossOriginEmbedderPolicy: false,
}));

app.use(cors({
  origin: config.cors.origin,
  credentials: true,
  optionsSuccessStatus: 200,
}));

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // limit each IP to 100 requests per windowMs
  message: 'Too many requests from this IP',
  standardHeaders: true,
  legacyHeaders: false,
});
app.use('/api', limiter);

// Body parsing and compression
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));
app.use(compression());

// Logging middleware
app.use(requestId);
app.use(requestLogger);

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    version: process.env.npm_package_version || '1.0.0',
  });
});

// API routes
app.use('/api/auth', routes.auth);
app.use('/api/users', authMiddleware, routes.users);
app.use('/api/posts', authMiddleware, routes.posts);

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({
    error: 'Route not found',
    path: req.originalUrl,
  });
});

// Global error handler
app.use(errorHandler);

export { app };

// src/server.ts
import { app } from './app';
import { config } from '@/config/env';
import { DatabaseService } from '@/services/database';
import { RedisService } from '@/services/redis';
import { logger } from '@/config/logger';

async function startServer(): Promise<void> {
  try {
    // Initialize database connection
    await DatabaseService.getInstance().connect();
    logger.info('Database connected successfully');

    // Initialize Redis connection
    await RedisService.getInstance().connect();
    logger.info('Redis connected successfully');

    // Start server
    const server = app.listen(config.port, () => {
      logger.info(`Server running on port ${config.port}`);
      logger.info(`Environment: ${config.nodeEnv}`);
    });

    // Graceful shutdown
    const gracefulShutdown = async (signal: string) => {
      logger.info(`Received ${signal}, shutting down gracefully`);
      
      server.close(async () => {
        await DatabaseService.getInstance().disconnect();
        await RedisService.getInstance().disconnect();
        logger.info('Server closed');
        process.exit(0);
      });

      // Force close after 10 seconds
      setTimeout(() => {
        logger.error('Could not close connections in time, forcefully shutting down');
        process.exit(1);
      }, 10000);
    };

    process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
    process.on('SIGINT', () => gracefulShutdown('SIGINT'));

  } catch (error) {
    logger.error('Failed to start server:', error);
    process.exit(1);
  }
}

startServer();
```

### 2. Configuration Management

```typescript
// src/config/env.ts
import dotenv from 'dotenv';
import Joi from 'joi';

dotenv.config();

const envSchema = Joi.object({
  NODE_ENV: Joi.string().valid('development', 'production', 'test').default('development'),
  PORT: Joi.number().default(3000),
  
  // Database
  DATABASE_URL: Joi.string().required(),
  
  // Redis
  REDIS_HOST: Joi.string().default('localhost'),
  REDIS_PORT: Joi.number().default(6379),
  REDIS_PASSWORD: Joi.string().allow(''),
  
  // JWT
  JWT_ACCESS_SECRET: Joi.string().required(),
  JWT_REFRESH_SECRET: Joi.string().required(),
  JWT_ISSUER: Joi.string().default('my-app'),
  JWT_AUDIENCE: Joi.string().default('my-app-api'),
  
  // CORS
  CORS_ORIGIN: Joi.string().default('http://localhost:3001'),
  
  // Email
  SMTP_HOST: Joi.string().required(),
  SMTP_PORT: Joi.number().default(587),
  SMTP_USER: Joi.string().required(),
  SMTP_PASS: Joi.string().required(),
  
  // OAuth
  GOOGLE_CLIENT_ID: Joi.string().allow(''),
  GOOGLE_CLIENT_SECRET: Joi.string().allow(''),
  
  // File Upload
  UPLOAD_MAX_SIZE: Joi.number().default(10 * 1024 * 1024), // 10MB
  UPLOAD_ALLOWED_TYPES: Joi.string().default('image/jpeg,image/png,image/gif'),
  
  // Logging
  LOG_LEVEL: Joi.string().valid('error', 'warn', 'info', 'debug').default('info'),
}).unknown();

const { error, value: envVars } = envSchema.validate(process.env);

if (error) {
  throw new Error(`Config validation error: ${error.message}`);
}

export const config = {
  nodeEnv: envVars.NODE_ENV,
  port: envVars.PORT,
  
  database: {
    url: envVars.DATABASE_URL,
  },
  
  redis: {
    host: envVars.REDIS_HOST,
    port: envVars.REDIS_PORT,
    password: envVars.REDIS_PASSWORD,
  },
  
  jwt: {
    accessSecret: envVars.JWT_ACCESS_SECRET,
    refreshSecret: envVars.JWT_REFRESH_SECRET,
    issuer: envVars.JWT_ISSUER,
    audience: envVars.JWT_AUDIENCE,
    accessExpiry: '15m',
    refreshExpiry: '7d',
  },
  
  cors: {
    origin: envVars.CORS_ORIGIN.split(','),
  },
  
  email: {
    host: envVars.SMTP_HOST,
    port: envVars.SMTP_PORT,
    user: envVars.SMTP_USER,
    pass: envVars.SMTP_PASS,
  },
  
  oauth: {
    google: {
      clientId: envVars.GOOGLE_CLIENT_ID,
      clientSecret: envVars.GOOGLE_CLIENT_SECRET,
    },
  },
  
  upload: {
    maxSize: envVars.UPLOAD_MAX_SIZE,
    allowedTypes: envVars.UPLOAD_ALLOWED_TYPES.split(','),
  },
  
  logging: {
    level: envVars.LOG_LEVEL,
  },
};
```

---

## 🔐 Authentication Implementation

### 1. JWT Service

```typescript
// src/services/auth.ts
import jwt from 'jsonwebtoken';
import bcrypt from 'bcrypt';
import { config } from '@/config/env';
import { User } from '@/models/User';
import { RedisService } from '@/services/redis';
import { logger } from '@/config/logger';

interface JWTPayload {
  sub: string;
  email: string;
  role: string;
  iat: number;
  exp: number;
  jti: string;
}

interface TokenPair {
  accessToken: string;
  refreshToken: string;
}

export class AuthService {
  private redis = RedisService.getInstance();

  async login(email: string, password: string): Promise<{ user: User; tokens: TokenPair }> {
    // Find user by email
    const user = await User.findOne({ email }).select('+password');
    if (!user) {
      throw new Error('Invalid credentials');
    }

    // Verify password
    const isValidPassword = await bcrypt.compare(password, user.password);
    if (!isValidPassword) {
      throw new Error('Invalid credentials');
    }

    // Check if user is active
    if (!user.isActive) {
      throw new Error('Account is disabled');
    }

    // Generate tokens
    const tokens = await this.generateTokens(user);

    // Update last login
    user.lastLoginAt = new Date();
    await user.save();

    // Remove password from user object
    user.password = undefined;

    logger.info('User logged in', { userId: user.id, email: user.email });

    return { user, tokens };
  }

  async generateTokens(user: User): Promise<TokenPair> {
    const jti = crypto.randomUUID();
    const now = Math.floor(Date.now() / 1000);

    // Access token payload
    const accessPayload: JWTPayload = {
      sub: user.id,
      email: user.email,
      role: user.role,
      iat: now,
      exp: now + (15 * 60), // 15 minutes
      jti,
    };

    // Generate tokens
    const accessToken = jwt.sign(accessPayload, config.jwt.accessSecret, {
      issuer: config.jwt.issuer,
      audience: config.jwt.audience,
    });

    const refreshToken = jwt.sign(
      { sub: user.id, jti, type: 'refresh' },
      config.jwt.refreshSecret,
      { expiresIn: config.jwt.refreshExpiry }
    );

    // Store refresh token in Redis
    await this.redis.setex(
      `refresh_token:${jti}`,
      7 * 24 * 60 * 60, // 7 days in seconds
      JSON.stringify({
        userId: user.id,
        createdAt: new Date().toISOString(),
      })
    );

    return { accessToken, refreshToken };
  }

  async verifyAccessToken(token: string): Promise<JWTPayload> {
    try {
      const payload = jwt.verify(token, config.jwt.accessSecret, {
        issuer: config.jwt.issuer,
        audience: config.jwt.audience,
      }) as JWTPayload;

      // Check if token is blacklisted
      const isBlacklisted = await this.redis.get(`blacklist:${payload.jti}`);
      if (isBlacklisted) {
        throw new Error('Token is blacklisted');
      }

      return payload;
    } catch (error) {
      throw new Error('Invalid access token');
    }
  }

  async refreshTokens(refreshToken: string): Promise<TokenPair> {
    try {
      const payload = jwt.verify(refreshToken, config.jwt.refreshSecret) as any;
      
      // Check if refresh token exists in Redis
      const storedToken = await this.redis.get(`refresh_token:${payload.jti}`);
      if (!storedToken) {
        throw new Error('Refresh token not found');
      }

      // Get user
      const user = await User.findById(payload.sub);
      if (!user || !user.isActive) {
        throw new Error('User not found or inactive');
      }

      // Revoke old refresh token
      await this.redis.del(`refresh_token:${payload.jti}`);

      // Generate new tokens
      return await this.generateTokens(user);
    } catch (error) {
      throw new Error('Invalid refresh token');
    }
  }

  async logout(jti: string): Promise<void> {
    // Blacklist the access token
    await this.redis.setex(`blacklist:${jti}`, 15 * 60, 'true'); // 15 minutes
    
    // Remove refresh token
    await this.redis.del(`refresh_token:${jti}`);
    
    logger.info('User logged out', { jti });
  }

  async revokeAllTokens(userId: string): Promise<void> {
    // Get all refresh tokens for user
    const keys = await this.redis.keys(`refresh_token:*`);
    
    for (const key of keys) {
      const tokenData = await this.redis.get(key);
      if (tokenData) {
        const parsed = JSON.parse(tokenData);
        if (parsed.userId === userId) {
          await this.redis.del(key);
        }
      }
    }
    
    logger.info('All tokens revoked for user', { userId });
  }

  async hashPassword(password: string): Promise<string> {
    return bcrypt.hash(password, 12);
  }

  async comparePassword(password: string, hash: string): Promise<boolean> {
    return bcrypt.compare(password, hash);
  }
}
```

### 2. Authentication Middleware

```typescript
// src/middleware/auth.ts
import { Request, Response, NextFunction } from 'express';
import { AuthService } from '@/services/auth';
import { User } from '@/models/User';
import { logger } from '@/config/logger';

const authService = new AuthService();

export const authMiddleware = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
  try {
    const authHeader = req.headers.authorization;
    
    if (!authHeader?.startsWith('Bearer ')) {
      res.status(401).json({ error: 'Access token required' });
      return;
    }

    const token = authHeader.slice(7);
    const payload = await authService.verifyAccessToken(token);

    // Get user details
    const user = await User.findById(payload.sub);
    if (!user || !user.isActive) {
      res.status(401).json({ error: 'User not found or inactive' });
      return;
    }

    // Attach user to request
    req.user = user;
    req.tokenJti = payload.jti;

    next();
  } catch (error) {
    logger.warn('Authentication failed', { error: error.message });
    res.status(401).json({ error: 'Invalid or expired token' });
  }
};

export const optionalAuth = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
  try {
    const authHeader = req.headers.authorization;
    
    if (authHeader?.startsWith('Bearer ')) {
      const token = authHeader.slice(7);
      const payload = await authService.verifyAccessToken(token);
      const user = await User.findById(payload.sub);
      
      if (user && user.isActive) {
        req.user = user;
        req.tokenJti = payload.jti;
      }
    }
    
    next();
  } catch (error) {
    // Continue without authentication for optional auth
    next();
  }
};

export const requireRole = (roles: string[]) => {
  return (req: Request, res: Response, next: NextFunction): void => {
    if (!req.user) {
      res.status(401).json({ error: 'Authentication required' });
      return;
    }

    if (!roles.includes(req.user.role)) {
      res.status(403).json({ error: 'Insufficient permissions' });
      return;
    }

    next();
  };
};
```

---

## 📝 Controller Implementation

### 1. User Controller

```typescript
// src/controllers/userController.ts
import { Request, Response } from 'express';
import { AuthService } from '@/services/auth';
import { UserService } from '@/services/userService';
import { logger } from '@/config/logger';
import { validationSchemas } from '@/utils/validation';

const authService = new AuthService();
const userService = new UserService();

export class UserController {
  async register(req: Request, res: Response): Promise<void> {
    try {
      const { error, value } = validationSchemas.user.create.validate(req.body);
      if (error) {
        res.status(400).json({
          error: 'Validation failed',
          details: error.details.map(d => ({
            field: d.path.join('.'),
            message: d.message,
          })),
        });
        return;
      }

      const { email, password, name } = value;

      // Check if user already exists
      const existingUser = await userService.findByEmail(email);
      if (existingUser) {
        res.status(409).json({ error: 'User already exists' });
        return;
      }

      // Hash password
      const hashedPassword = await authService.hashPassword(password);

      // Create user
      const user = await userService.create({
        email,
        password: hashedPassword,
        name,
      });

      // Generate tokens
      const tokens = await authService.generateTokens(user);

      logger.info('User registered', { userId: user.id, email: user.email });

      res.status(201).json({
        message: 'User created successfully',
        user: user.toPublic(),
        tokens,
      });
    } catch (error) {
      logger.error('Registration error', { error: error.message });
      res.status(500).json({ error: 'Registration failed' });
    }
  }

  async login(req: Request, res: Response): Promise<void> {
    try {
      const { error, value } = validationSchemas.user.login.validate(req.body);
      if (error) {
        res.status(400).json({ error: 'Validation failed' });
        return;
      }

      const { email, password } = value;
      const result = await authService.login(email, password);

      res.json({
        message: 'Login successful',
        user: result.user.toPublic(),
        tokens: result.tokens,
      });
    } catch (error) {
      logger.warn('Login attempt failed', { email: req.body.email, error: error.message });
      res.status(401).json({ error: 'Invalid credentials' });
    }
  }

  async refreshToken(req: Request, res: Response): Promise<void> {
    try {
      const { refreshToken } = req.body;
      if (!refreshToken) {
        res.status(400).json({ error: 'Refresh token required' });
        return;
      }

      const tokens = await authService.refreshTokens(refreshToken);
      res.json({ tokens });
    } catch (error) {
      logger.warn('Token refresh failed', { error: error.message });
      res.status(401).json({ error: 'Invalid refresh token' });
    }
  }

  async logout(req: Request, res: Response): Promise<void> {
    try {
      await authService.logout(req.tokenJti!);
      res.json({ message: 'Logged out successfully' });
    } catch (error) {
      logger.error('Logout error', { error: error.message });
      res.status(500).json({ error: 'Logout failed' });
    }
  }

  async getProfile(req: Request, res: Response): Promise<void> {
    res.json(req.user!.toPublic());
  }

  async updateProfile(req: Request, res: Response): Promise<void> {
    try {
      const { error, value } = validationSchemas.user.update.validate(req.body);
      if (error) {
        res.status(400).json({ error: 'Validation failed' });
        return;
      }

      const updatedUser = await userService.update(req.user!.id, value);
      
      logger.info('Profile updated', { userId: req.user!.id });
      
      res.json({
        message: 'Profile updated successfully',
        user: updatedUser.toPublic(),
      });
    } catch (error) {
      logger.error('Profile update error', { error: error.message });
      res.status(500).json({ error: 'Profile update failed' });
    }
  }

  async deleteAccount(req: Request, res: Response): Promise<void> {
    try {
      await userService.delete(req.user!.id);
      await authService.revokeAllTokens(req.user!.id);
      
      logger.info('Account deleted', { userId: req.user!.id });
      
      res.json({ message: 'Account deleted successfully' });
    } catch (error) {
      logger.error('Account deletion error', { error: error.message });
      res.status(500).json({ error: 'Account deletion failed' });
    }
  }
}
```

---

## 🧪 Testing Implementation

### 1. Test Setup

```typescript
// src/__tests__/setup.ts
import { MongoMemoryServer } from 'mongodb-memory-server';
import mongoose from 'mongoose';
import { RedisMemoryServer } from 'redis-memory-server';
import { RedisService } from '@/services/redis';

let mongoServer: MongoMemoryServer;
let redisServer: RedisMemoryServer;

beforeAll(async () => {
  // Start MongoDB Memory Server
  mongoServer = await MongoMemoryServer.create();
  const mongoUri = mongoServer.getUri();
  
  await mongoose.connect(mongoUri);

  // Start Redis Memory Server
  redisServer = new RedisMemoryServer();
  const redisHost = await redisServer.getHost();
  const redisPort = await redisServer.getPort();
  
  process.env.REDIS_HOST = redisHost;
  process.env.REDIS_PORT = redisPort.toString();
  
  await RedisService.getInstance().connect();
}, 30000);

afterAll(async () => {
  await mongoose.disconnect();
  await mongoServer.stop();
  
  await RedisService.getInstance().disconnect();
  await redisServer.stop();
});

beforeEach(async () => {
  // Clear database
  const collections = mongoose.connection.collections;
  for (const key in collections) {
    await collections[key].deleteMany({});
  }
  
  // Clear Redis
  await RedisService.getInstance().flushall();
});
```

### 2. Integration Tests

```typescript
// src/__tests__/controllers/auth.test.ts
import supertest from 'supertest';
import { app } from '@/app';
import { User } from '@/models/User';
import { AuthService } from '@/services/auth';

const request = supertest(app);
const authService = new AuthService();

describe('Authentication Controller', () => {
  describe('POST /api/auth/register', () => {
    it('should register a new user', async () => {
      const userData = {
        email: 'test@example.com',
        password: 'Test123!@#',
        name: 'Test User',
      };

      const response = await request
        .post('/api/auth/register')
        .send(userData)
        .expect(201);

      expect(response.body).toMatchObject({
        message: 'User created successfully',
        user: {
          email: userData.email,
          name: userData.name,
          role: 'user',
        },
        tokens: {
          accessToken: expect.any(String),
          refreshToken: expect.any(String),
        },
      });

      // Verify user in database
      const user = await User.findOne({ email: userData.email });
      expect(user).toBeTruthy();
      expect(user!.name).toBe(userData.name);
    });

    it('should return validation error for invalid data', async () => {
      const userData = {
        email: 'invalid-email',
        password: '123', // Too short
        name: '',
      };

      const response = await request
        .post('/api/auth/register')
        .send(userData)
        .expect(400);

      expect(response.body).toHaveProperty('error', 'Validation failed');
      expect(response.body.details).toBeInstanceOf(Array);
    });

    it('should return error for duplicate email', async () => {
      const userData = {
        email: 'test@example.com',
        password: 'Test123!@#',
        name: 'Test User',
      };

      // Create user first
      await User.create({
        ...userData,
        password: await authService.hashPassword(userData.password),
      });

      const response = await request
        .post('/api/auth/register')
        .send(userData)
        .expect(409);

      expect(response.body).toHaveProperty('error', 'User already exists');
    });
  });

  describe('POST /api/auth/login', () => {
    beforeEach(async () => {
      // Create test user
      await User.create({
        email: 'test@example.com',
        password: await authService.hashPassword('Test123!@#'),
        name: 'Test User',
        isActive: true,
      });
    });

    it('should login with valid credentials', async () => {
      const loginData = {
        email: 'test@example.com',
        password: 'Test123!@#',
      };

      const response = await request
        .post('/api/auth/login')
        .send(loginData)
        .expect(200);

      expect(response.body).toMatchObject({
        message: 'Login successful',
        user: {
          email: loginData.email,
        },
        tokens: {
          accessToken: expect.any(String),
          refreshToken: expect.any(String),
        },
      });
    });

    it('should return error for invalid credentials', async () => {
      const loginData = {
        email: 'test@example.com',
        password: 'WrongPassword',
      };

      const response = await request
        .post('/api/auth/login')
        .send(loginData)
        .expect(401);

      expect(response.body).toHaveProperty('error', 'Invalid credentials');
    });
  });
});
```

---

## 🚀 Deployment Configuration

### 1. Docker Configuration

```dockerfile
# Dockerfile
FROM node:18-alpine AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./
COPY tsconfig.json ./

# Install dependencies
RUN npm ci --only=production && npm cache clean --force

# Copy source code
COPY src ./src

# Build application
RUN npm run build

# Production stage
FROM node:18-alpine AS production

WORKDIR /app

# Install dumb-init for proper signal handling
RUN apk add --no-cache dumb-init

# Create non-root user
RUN addgroup -g 1001 -S nodejs
RUN adduser -S nodejs -u 1001

# Copy built application
COPY --from=builder --chown=nodejs:nodejs /app/dist ./dist
COPY --from=builder --chown=nodejs:nodejs /app/node_modules ./node_modules
COPY --from=builder --chown=nodejs:nodejs /app/package.json ./

# Switch to non-root user
USER nodejs

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/health', (res) => { process.exit(res.statusCode === 200 ? 0 : 1) })"

# Start application
ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "dist/server.js"]
```

### 2. Docker Compose

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
      - DATABASE_URL=postgresql://user:password@db:5432/myapp
      - REDIS_HOST=redis
      - JWT_ACCESS_SECRET=your-access-secret
      - JWT_REFRESH_SECRET=your-refresh-secret
    depends_on:
      - db
      - redis
    volumes:
      - ./logs:/app/logs
    restart: unless-stopped

  db:
    image: postgres:15-alpine
    environment:
      - POSTGRES_DB=myapp
      - POSTGRES_USER=user
      - POSTGRES_PASSWORD=password
    volumes:
      - postgres_data:/var/lib/postgresql/data
    restart: unless-stopped

  redis:
    image: redis:7-alpine
    command: redis-server --appendonly yes
    volumes:
      - redis_data:/data
    restart: unless-stopped

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
      - ./ssl:/etc/nginx/ssl
    depends_on:
      - app
    restart: unless-stopped

volumes:
  postgres_data:
  redis_data:
```

### 3. Environment Variables

```bash
# .env.production
NODE_ENV=production
PORT=3000

# Database
DATABASE_URL=postgresql://username:password@localhost:5432/myapp

# Redis
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=

# JWT Secrets (generate with: openssl rand -base64 32)
JWT_ACCESS_SECRET=your-super-secret-access-key
JWT_REFRESH_SECRET=your-super-secret-refresh-key
JWT_ISSUER=my-app
JWT_AUDIENCE=my-app-api

# CORS
CORS_ORIGIN=https://myapp.com,https://www.myapp.com

# Email
SMTP_HOST=smtp.sendgrid.net
SMTP_PORT=587
SMTP_USER=apikey
SMTP_PASS=your-sendgrid-api-key

# OAuth
GOOGLE_CLIENT_ID=your-google-client-id
GOOGLE_CLIENT_SECRET=your-google-client-secret

# Monitoring
LOG_LEVEL=info
```

---

## 🔗 Navigation

← [Development Tools & Libraries](./development-tools-libraries.md) | [Best Practices](./best-practices.md) →

---

*Implementation guide: July 2025 | Complete production-ready setup with TypeScript, authentication, testing, and deployment*