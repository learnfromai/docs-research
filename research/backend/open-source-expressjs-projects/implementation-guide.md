# Implementation Guide: Building Production-Ready Express.js Applications

## 🎯 Overview

Step-by-step guide for implementing production-ready Express.js applications based on patterns and practices observed in successful open source projects. This guide covers project setup, architecture implementation, security integration, and deployment preparation.

## 🏗️ Project Setup & Structure

### 1. Initial Project Structure

**Recommended Directory Structure:**
```
express-app/
├── src/
│   ├── config/              # Configuration management
│   │   ├── database.ts
│   │   ├── redis.ts
│   │   └── index.ts
│   ├── controllers/         # Request handlers
│   │   ├── auth.controller.ts
│   │   ├── user.controller.ts
│   │   └── post.controller.ts
│   ├── middleware/          # Custom middleware
│   │   ├── auth.middleware.ts
│   │   ├── validation.middleware.ts
│   │   ├── error.middleware.ts
│   │   └── logging.middleware.ts
│   ├── models/             # Data models (if using ORM)
│   │   ├── user.model.ts
│   │   └── post.model.ts
│   ├── routes/             # Route definitions
│   │   ├── auth.routes.ts
│   │   ├── user.routes.ts
│   │   ├── post.routes.ts
│   │   └── index.ts
│   ├── services/           # Business logic
│   │   ├── auth.service.ts
│   │   ├── user.service.ts
│   │   ├── email.service.ts
│   │   └── upload.service.ts
│   ├── utils/              # Helper functions
│   │   ├── logger.ts
│   │   ├── validator.ts
│   │   ├── crypto.ts
│   │   └── constants.ts
│   ├── types/              # TypeScript type definitions
│   │   ├── express.d.ts
│   │   ├── user.types.ts
│   │   └── common.types.ts
│   ├── tests/              # Test files
│   │   ├── unit/
│   │   ├── integration/
│   │   └── e2e/
│   └── app.ts              # Express app configuration
│   └── server.ts           # Server startup
├── prisma/                 # Database schema (if using Prisma)
│   ├── schema.prisma
│   └── migrations/
├── logs/                   # Log files
├── uploads/                # File uploads (development)
├── .env.example           # Environment variables template
├── .gitignore
├── docker-compose.yml     # Local development
├── Dockerfile            # Production deployment
├── package.json
├── tsconfig.json
└── README.md
```

### 2. Package.json Configuration

**Production-Ready Dependencies:**
```json
{
  "name": "express-production-app",
  "version": "1.0.0",
  "description": "Production-ready Express.js application",
  "main": "dist/server.js",
  "scripts": {
    "start": "node dist/server.js",
    "dev": "nodemon src/server.ts",
    "build": "tsc",
    "build:prod": "npm run clean && tsc --project tsconfig.prod.json",
    "clean": "rimraf dist",
    "test": "jest",
    "test:watch": "jest --watch",
    "test:coverage": "jest --coverage",
    "test:e2e": "jest --config jest.e2e.config.js",
    "lint": "eslint src/**/*.ts",
    "lint:fix": "eslint src/**/*.ts --fix",
    "format": "prettier --write src/**/*.ts",
    "migrate": "prisma migrate deploy",
    "db:generate": "prisma generate",
    "db:seed": "ts-node prisma/seed.ts",
    "docker:build": "docker build -t express-app .",
    "docker:run": "docker run -p 3000:3000 express-app"
  },
  "dependencies": {
    "express": "^4.18.2",
    "helmet": "^7.1.0",
    "cors": "^2.8.5",
    "compression": "^1.7.4",
    "express-rate-limit": "^7.1.5",
    "express-validator": "^7.0.1",
    "passport": "^0.7.0",
    "passport-local": "^1.0.0",
    "passport-jwt": "^4.0.1",
    "jsonwebtoken": "^9.0.2",
    "bcryptjs": "^2.4.3",
    "joi": "^17.11.0",
    "winston": "^3.11.0",
    "winston-daily-rotate-file": "^4.7.1",
    "@prisma/client": "^5.7.1",
    "redis": "^4.6.12",
    "ioredis": "^5.3.2",
    "nodemailer": "^6.9.7",
    "multer": "^1.4.5-lts.1",
    "sharp": "^0.33.1",
    "dotenv": "^16.3.1"
  },
  "devDependencies": {
    "@types/node": "^20.10.5",
    "@types/express": "^4.17.21",
    "@types/bcryptjs": "^2.4.6",
    "@types/jsonwebtoken": "^9.0.5",
    "@types/passport": "^1.0.16",
    "@types/passport-local": "^1.0.38",
    "@types/passport-jwt": "^3.0.13",
    "@types/multer": "^1.4.11",
    "@types/nodemailer": "^6.4.14",
    "@types/jest": "^29.5.8",
    "@types/supertest": "^2.0.16",
    "typescript": "^5.3.3",
    "ts-node": "^10.9.2",
    "nodemon": "^3.0.2",
    "jest": "^29.7.0",
    "ts-jest": "^29.1.1",
    "supertest": "^6.3.3",
    "eslint": "^8.55.0",
    "@typescript-eslint/parser": "^6.13.2",
    "@typescript-eslint/eslint-plugin": "^6.13.2",
    "eslint-plugin-security": "^1.7.1",
    "prettier": "^3.1.1",
    "rimraf": "^5.0.5",
    "prisma": "^5.7.1"
  },
  "engines": {
    "node": ">=18.0.0",
    "npm": ">=9.0.0"
  }
}
```

## 🚀 Step-by-Step Implementation

### Step 1: Environment Configuration

**Environment Variables Setup:**
```typescript
// src/config/index.ts
import dotenv from 'dotenv';
import joi from 'joi';

dotenv.config();

// Environment validation schema
const envSchema = joi.object({
  NODE_ENV: joi.string().valid('development', 'staging', 'production').default('development'),
  PORT: joi.number().default(3000),
  
  // Database
  DATABASE_URL: joi.string().required(),
  DATABASE_POOL_MIN: joi.number().default(5),
  DATABASE_POOL_MAX: joi.number().default(20),
  
  // Redis
  REDIS_URL: joi.string().required(),
  REDIS_PASSWORD: joi.string().optional(),
  
  // JWT
  JWT_SECRET: joi.string().min(32).required(),
  JWT_EXPIRES_IN: joi.string().default('15m'),
  JWT_REFRESH_EXPIRES_IN: joi.string().default('7d'),
  
  // Security
  BCRYPT_ROUNDS: joi.number().default(12),
  SESSION_SECRET: joi.string().min(32).required(),
  
  // Email
  EMAIL_HOST: joi.string().required(),
  EMAIL_PORT: joi.number().default(587),
  EMAIL_USER: joi.string().required(),
  EMAIL_PASS: joi.string().required(),
  
  // File uploads
  UPLOAD_MAX_SIZE: joi.number().default(10485760), // 10MB
  UPLOAD_ALLOWED_TYPES: joi.string().default('image/jpeg,image/png,image/gif'),
  
  // External services
  SENTRY_DSN: joi.string().optional(),
  NEW_RELIC_LICENSE_KEY: joi.string().optional(),
  
  // Rate limiting
  RATE_LIMIT_WINDOW_MS: joi.number().default(900000), // 15 minutes
  RATE_LIMIT_MAX_REQUESTS: joi.number().default(100)
});

const { error, value: envVars } = envSchema.validate(process.env);

if (error) {
  throw new Error(`Environment validation error: ${error.message}`);
}

export const config = {
  env: envVars.NODE_ENV,
  port: envVars.PORT,
  
  database: {
    url: envVars.DATABASE_URL,
    pool: {
      min: envVars.DATABASE_POOL_MIN,
      max: envVars.DATABASE_POOL_MAX
    }
  },
  
  redis: {
    url: envVars.REDIS_URL,
    password: envVars.REDIS_PASSWORD
  },
  
  jwt: {
    secret: envVars.JWT_SECRET,
    expiresIn: envVars.JWT_EXPIRES_IN,
    refreshExpiresIn: envVars.JWT_REFRESH_EXPIRES_IN
  },
  
  security: {
    bcryptRounds: envVars.BCRYPT_ROUNDS,
    sessionSecret: envVars.SESSION_SECRET
  },
  
  email: {
    host: envVars.EMAIL_HOST,
    port: envVars.EMAIL_PORT,
    user: envVars.EMAIL_USER,
    pass: envVars.EMAIL_PASS
  },
  
  upload: {
    maxSize: envVars.UPLOAD_MAX_SIZE,
    allowedTypes: envVars.UPLOAD_ALLOWED_TYPES.split(',')
  },
  
  monitoring: {
    sentryDsn: envVars.SENTRY_DSN,
    newRelicKey: envVars.NEW_RELIC_LICENSE_KEY
  },
  
  rateLimit: {
    windowMs: envVars.RATE_LIMIT_WINDOW_MS,
    maxRequests: envVars.RATE_LIMIT_MAX_REQUESTS
  }
};
```

### Step 2: Database Setup (Prisma)

**Prisma Schema Definition:**
```prisma
// prisma/schema.prisma
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

model User {
  id        String   @id @default(cuid())
  email     String   @unique
  password  String
  name      String?
  role      Role     @default(USER)
  isActive  Boolean  @default(true)
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
  
  // Relations
  posts     Post[]
  sessions  Session[]
  
  // Indexes
  @@map("users")
}

model Post {
  id        String   @id @default(cuid())
  title     String
  content   String?
  published Boolean  @default(false)
  authorId  String
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
  
  // Relations
  author    User     @relation(fields: [authorId], references: [id], onDelete: Cascade)
  
  // Indexes
  @@index([authorId])
  @@index([published, createdAt])
  @@map("posts")
}

model Session {
  id        String   @id @default(cuid())
  token     String   @unique
  userId    String
  expiresAt DateTime
  createdAt DateTime @default(now())
  
  // Relations
  user      User     @relation(fields: [userId], references: [id], onDelete: Cascade)
  
  // Indexes
  @@index([token])
  @@index([userId])
  @@index([expiresAt])
  @@map("sessions")
}

enum Role {
  USER
  ADMIN
  MODERATOR
}
```

**Database Configuration:**
```typescript
// src/config/database.ts
import { PrismaClient } from '@prisma/client';
import { config } from './index';

const prisma = new PrismaClient({
  datasources: {
    db: {
      url: config.database.url
    }
  },
  log: config.env === 'development' ? ['query', 'info', 'warn', 'error'] : ['error']
});

// Graceful shutdown
process.on('beforeExit', async () => {
  await prisma.$disconnect();
});

export { prisma };
```

### Step 3: Authentication Implementation

**JWT Service:**
```typescript
// src/services/auth.service.ts
import jwt from 'jsonwebtoken';
import bcrypt from 'bcryptjs';
import { prisma } from '../config/database';
import { config } from '../config';
import { User } from '@prisma/client';

export interface TokenPair {
  accessToken: string;
  refreshToken: string;
}

export interface JWTPayload {
  sub: string;
  email: string;
  role: string;
  iat: number;
  exp: number;
}

export class AuthService {
  async register(userData: {
    email: string;
    password: string;
    name?: string;
  }): Promise<{ user: Omit<User, 'password'>; tokens: TokenPair }> {
    // Check if user exists
    const existingUser = await prisma.user.findUnique({
      where: { email: userData.email }
    });
    
    if (existingUser) {
      throw new Error('User already exists');
    }
    
    // Hash password
    const hashedPassword = await bcrypt.hash(userData.password, config.security.bcryptRounds);
    
    // Create user
    const user = await prisma.user.create({
      data: {
        email: userData.email,
        password: hashedPassword,
        name: userData.name
      }
    });
    
    // Generate tokens
    const tokens = await this.generateTokens(user);
    
    // Remove password from response
    const { password, ...userWithoutPassword } = user;
    
    return { user: userWithoutPassword, tokens };
  }
  
  async login(email: string, password: string): Promise<{ user: Omit<User, 'password'>; tokens: TokenPair }> {
    // Find user
    const user = await prisma.user.findUnique({
      where: { email }
    });
    
    if (!user || !user.isActive) {
      throw new Error('Invalid credentials');
    }
    
    // Verify password
    const isPasswordValid = await bcrypt.compare(password, user.password);
    
    if (!isPasswordValid) {
      throw new Error('Invalid credentials');
    }
    
    // Generate tokens
    const tokens = await this.generateTokens(user);
    
    // Remove password from response
    const { password: _, ...userWithoutPassword } = user;
    
    return { user: userWithoutPassword, tokens };
  }
  
  async refreshTokens(refreshToken: string): Promise<TokenPair> {
    try {
      // Verify refresh token
      const payload = jwt.verify(refreshToken, config.jwt.secret) as JWTPayload;
      
      // Check if session exists and is valid
      const session = await prisma.session.findUnique({
        where: { token: refreshToken },
        include: { user: true }
      });
      
      if (!session || session.expiresAt < new Date() || !session.user.isActive) {
        throw new Error('Invalid refresh token');
      }
      
      // Generate new tokens
      const tokens = await this.generateTokens(session.user);
      
      // Update session with new refresh token
      await prisma.session.update({
        where: { id: session.id },
        data: {
          token: tokens.refreshToken,
          expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000) // 7 days
        }
      });
      
      return tokens;
    } catch (error) {
      throw new Error('Invalid refresh token');
    }
  }
  
  async logout(refreshToken: string): Promise<void> {
    await prisma.session.delete({
      where: { token: refreshToken }
    });
  }
  
  async generateTokens(user: User): Promise<TokenPair> {
    const payload: Omit<JWTPayload, 'iat' | 'exp'> = {
      sub: user.id,
      email: user.email,
      role: user.role
    };
    
    // Generate access token
    const accessToken = jwt.sign(payload, config.jwt.secret, {
      expiresIn: config.jwt.expiresIn,
      issuer: 'express-app',
      audience: 'express-app-users'
    });
    
    // Generate refresh token
    const refreshToken = jwt.sign(payload, config.jwt.secret, {
      expiresIn: config.jwt.refreshExpiresIn,
      issuer: 'express-app',
      audience: 'express-app-users'
    });
    
    // Store refresh token in database
    await prisma.session.create({
      data: {
        token: refreshToken,
        userId: user.id,
        expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000) // 7 days
      }
    });
    
    return { accessToken, refreshToken };
  }
  
  verifyAccessToken(token: string): JWTPayload {
    return jwt.verify(token, config.jwt.secret, {
      issuer: 'express-app',
      audience: 'express-app-users'
    }) as JWTPayload;
  }
}

export const authService = new AuthService();
```

### Step 4: Middleware Implementation

**Authentication Middleware:**
```typescript
// src/middleware/auth.middleware.ts
import { Request, Response, NextFunction } from 'express';
import { authService } from '../services/auth.service';
import { prisma } from '../config/database';

export interface AuthenticatedRequest extends Request {
  user?: {
    id: string;
    email: string;
    role: string;
  };
}

export const authenticate = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const authHeader = req.headers.authorization;
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      res.status(401).json({
        status: 'error',
        message: 'Access token required'
      });
      return;
    }
    
    const token = authHeader.substring(7);
    const payload = authService.verifyAccessToken(token);
    
    // Verify user still exists and is active
    const user = await prisma.user.findUnique({
      where: { id: payload.sub },
      select: { id: true, email: true, role: true, isActive: true }
    });
    
    if (!user || !user.isActive) {
      res.status(401).json({
        status: 'error',
        message: 'Invalid or expired token'
      });
      return;
    }
    
    req.user = {
      id: user.id,
      email: user.email,
      role: user.role
    };
    
    next();
  } catch (error) {
    res.status(401).json({
      status: 'error',
      message: 'Invalid or expired token'
    });
  }
};

export const authorize = (roles: string[]) => {
  return (req: AuthenticatedRequest, res: Response, next: NextFunction): void => {
    if (!req.user) {
      res.status(401).json({
        status: 'error',
        message: 'Authentication required'
      });
      return;
    }
    
    if (!roles.includes(req.user.role)) {
      res.status(403).json({
        status: 'error',
        message: 'Insufficient permissions'
      });
      return;
    }
    
    next();
  };
};
```

**Validation Middleware:**
```typescript
// src/middleware/validation.middleware.ts
import { Request, Response, NextFunction } from 'express';
import joi from 'joi';

export const validate = (schema: joi.Schema, property: 'body' | 'params' | 'query' = 'body') => {
  return (req: Request, res: Response, next: NextFunction): void => {
    const { error, value } = schema.validate(req[property], {
      abortEarly: false,
      stripUnknown: true,
      convert: true
    });
    
    if (error) {
      const errors = error.details.map(detail => ({
        field: detail.path.join('.'),
        message: detail.message,
        value: detail.context?.value
      }));
      
      res.status(400).json({
        status: 'error',
        message: 'Validation failed',
        errors
      });
      return;
    }
    
    req[property] = value;
    next();
  };
};

// Validation schemas
export const authSchemas = {
  register: joi.object({
    email: joi.string().email().required().lowercase().trim(),
    password: joi.string().min(8).max(128).required(),
    name: joi.string().min(2).max(50).trim().optional()
  }),
  
  login: joi.object({
    email: joi.string().email().required().lowercase().trim(),
    password: joi.string().required()
  }),
  
  refreshToken: joi.object({
    refreshToken: joi.string().required()
  })
};

export const postSchemas = {
  create: joi.object({
    title: joi.string().min(3).max(200).required().trim(),
    content: joi.string().min(10).optional(),
    published: joi.boolean().default(false)
  }),
  
  update: joi.object({
    title: joi.string().min(3).max(200).trim().optional(),
    content: joi.string().min(10).optional(),
    published: joi.boolean().optional()
  }).min(1),
  
  params: joi.object({
    id: joi.string().required()
  })
};
```

### Step 5: Controller Implementation

**Authentication Controller:**
```typescript
// src/controllers/auth.controller.ts
import { Request, Response } from 'express';
import { authService } from '../services/auth.service';
import { AuthenticatedRequest } from '../middleware/auth.middleware';

export class AuthController {
  async register(req: Request, res: Response): Promise<void> {
    try {
      const { email, password, name } = req.body;
      
      const result = await authService.register({ email, password, name });
      
      // Set refresh token as httpOnly cookie
      res.cookie('refreshToken', result.tokens.refreshToken, {
        httpOnly: true,
        secure: process.env.NODE_ENV === 'production',
        sameSite: 'strict',
        maxAge: 7 * 24 * 60 * 60 * 1000 // 7 days
      });
      
      res.status(201).json({
        status: 'success',
        data: {
          user: result.user,
          accessToken: result.tokens.accessToken
        }
      });
    } catch (error) {
      res.status(400).json({
        status: 'error',
        message: error.message
      });
    }
  }
  
  async login(req: Request, res: Response): Promise<void> {
    try {
      const { email, password } = req.body;
      
      const result = await authService.login(email, password);
      
      // Set refresh token as httpOnly cookie
      res.cookie('refreshToken', result.tokens.refreshToken, {
        httpOnly: true,
        secure: process.env.NODE_ENV === 'production',
        sameSite: 'strict',
        maxAge: 7 * 24 * 60 * 60 * 1000 // 7 days
      });
      
      res.json({
        status: 'success',
        data: {
          user: result.user,
          accessToken: result.tokens.accessToken
        }
      });
    } catch (error) {
      res.status(401).json({
        status: 'error',
        message: error.message
      });
    }
  }
  
  async refreshToken(req: Request, res: Response): Promise<void> {
    try {
      const refreshToken = req.cookies.refreshToken || req.body.refreshToken;
      
      if (!refreshToken) {
        res.status(401).json({
          status: 'error',
          message: 'Refresh token required'
        });
        return;
      }
      
      const tokens = await authService.refreshTokens(refreshToken);
      
      // Set new refresh token as httpOnly cookie
      res.cookie('refreshToken', tokens.refreshToken, {
        httpOnly: true,
        secure: process.env.NODE_ENV === 'production',
        sameSite: 'strict',
        maxAge: 7 * 24 * 60 * 60 * 1000 // 7 days
      });
      
      res.json({
        status: 'success',
        data: {
          accessToken: tokens.accessToken
        }
      });
    } catch (error) {
      res.status(401).json({
        status: 'error',
        message: error.message
      });
    }
  }
  
  async logout(req: AuthenticatedRequest, res: Response): Promise<void> {
    try {
      const refreshToken = req.cookies.refreshToken;
      
      if (refreshToken) {
        await authService.logout(refreshToken);
      }
      
      res.clearCookie('refreshToken');
      
      res.json({
        status: 'success',
        message: 'Logged out successfully'
      });
    } catch (error) {
      res.status(500).json({
        status: 'error',
        message: 'Logout failed'
      });
    }
  }
  
  async getProfile(req: AuthenticatedRequest, res: Response): Promise<void> {
    res.json({
      status: 'success',
      data: {
        user: req.user
      }
    });
  }
}

export const authController = new AuthController();
```

### Step 6: Route Setup

**Route Configuration:**
```typescript
// src/routes/auth.routes.ts
import { Router } from 'express';
import { authController } from '../controllers/auth.controller';
import { validate, authSchemas } from '../middleware/validation.middleware';
import { authenticate } from '../middleware/auth.middleware';

const router = Router();

router.post('/register', 
  validate(authSchemas.register),
  authController.register
);

router.post('/login', 
  validate(authSchemas.login),
  authController.login
);

router.post('/refresh', 
  authController.refreshToken
);

router.post('/logout', 
  authenticate,
  authController.logout
);

router.get('/profile', 
  authenticate,
  authController.getProfile
);

export { router as authRoutes };
```

### Step 7: Application Setup

**Express App Configuration:**
```typescript
// src/app.ts
import express from 'express';
import helmet from 'helmet';
import cors from 'cors';
import compression from 'compression';
import rateLimit from 'express-rate-limit';
import cookieParser from 'cookie-parser';

import { config } from './config';
import { errorHandler } from './middleware/error.middleware';
import { loggingMiddleware } from './middleware/logging.middleware';
import { authRoutes } from './routes/auth.routes';

const app = express();

// Security middleware
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      scriptSrc: ["'self'"],
      imgSrc: ["'self'", "data:", "https:"],
    }
  }
}));

// CORS configuration
app.use(cors({
  origin: process.env.ALLOWED_ORIGINS?.split(',') || ['http://localhost:3000'],
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));

// Rate limiting
app.use(rateLimit({
  windowMs: config.rateLimit.windowMs,
  max: config.rateLimit.maxRequests,
  message: {
    status: 'error',
    message: 'Too many requests'
  },
  standardHeaders: true,
  legacyHeaders: false
}));

// General middleware
app.use(compression());
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));
app.use(cookieParser());

// Logging middleware
app.use(loggingMiddleware);

// Health check
app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    uptime: process.uptime()
  });
});

// Routes
app.use('/api/auth', authRoutes);

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({
    status: 'error',
    message: 'Route not found'
  });
});

// Error handling
app.use(errorHandler);

export { app };
```

**Server Startup:**
```typescript
// src/server.ts
import { app } from './app';
import { config } from './config';
import { prisma } from './config/database';

const server = app.listen(config.port, () => {
  console.log(`Server running on port ${config.port} in ${config.env} mode`);
});

// Graceful shutdown
const gracefulShutdown = async () => {
  console.log('Received shutdown signal, starting graceful shutdown...');
  
  server.close(async () => {
    try {
      await prisma.$disconnect();
      console.log('Database connections closed');
      process.exit(0);
    } catch (error) {
      console.error('Error during shutdown:', error);
      process.exit(1);
    }
  });
  
  // Force shutdown after 10 seconds
  setTimeout(() => {
    console.error('Forceful shutdown due to timeout');
    process.exit(1);
  }, 10000);
};

process.on('SIGTERM', gracefulShutdown);
process.on('SIGINT', gracefulShutdown);
```

## 🧪 Testing Setup

**Jest Configuration:**
```typescript
// jest.config.js
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  roots: ['<rootDir>/src'],
  testMatch: ['**/__tests__/**/*.ts', '**/?(*.)+(spec|test).ts'],
  transform: {
    '^.+\\.ts$': 'ts-jest'
  },
  collectCoverageFrom: [
    'src/**/*.ts',
    '!src/**/*.d.ts',
    '!src/tests/**'
  ],
  coverageDirectory: 'coverage',
  coverageReporters: ['text', 'lcov', 'html'],
  setupFilesAfterEnv: ['<rootDir>/src/tests/setup.ts']
};
```

**Test Example:**
```typescript
// src/tests/auth.test.ts
import request from 'supertest';
import { app } from '../app';
import { prisma } from '../config/database';

describe('Authentication', () => {
  beforeEach(async () => {
    await prisma.user.deleteMany();
  });
  
  afterAll(async () => {
    await prisma.$disconnect();
  });
  
  describe('POST /api/auth/register', () => {
    it('should register a new user', async () => {
      const userData = {
        email: 'test@example.com',
        password: 'Test123!@#',
        name: 'Test User'
      };
      
      const response = await request(app)
        .post('/api/auth/register')
        .send(userData)
        .expect(201);
      
      expect(response.body.status).toBe('success');
      expect(response.body.data.user.email).toBe(userData.email);
      expect(response.body.data.accessToken).toBeDefined();
    });
    
    it('should not register user with invalid email', async () => {
      const userData = {
        email: 'invalid-email',
        password: 'Test123!@#'
      };
      
      const response = await request(app)
        .post('/api/auth/register')
        .send(userData)
        .expect(400);
      
      expect(response.body.status).toBe('error');
      expect(response.body.errors).toBeDefined();
    });
  });
});
```

## 🚀 Deployment Preparation

**Docker Configuration:**
```dockerfile
# Dockerfile
FROM node:18-alpine AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./
COPY prisma ./prisma/

# Install dependencies
RUN npm ci --only=production

# Copy source code
COPY . .

# Build application
RUN npm run build
RUN npx prisma generate

# Production stage
FROM node:18-alpine AS production

WORKDIR /app

# Create non-root user
RUN addgroup -g 1001 -S nodejs
RUN adduser -S nodejs -u 1001

# Copy built application
COPY --from=builder --chown=nodejs:nodejs /app/dist ./dist
COPY --from=builder --chown=nodejs:nodejs /app/node_modules ./node_modules
COPY --from=builder --chown=nodejs:nodejs /app/package*.json ./

USER nodejs

EXPOSE 3000

CMD ["node", "dist/server.js"]
```

**Docker Compose for Development:**
```yaml
# docker-compose.yml
version: '3.8'

services:
  app:
    build: .
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=development
      - DATABASE_URL=postgresql://postgres:password@db:5432/myapp
      - REDIS_URL=redis://redis:6379
    depends_on:
      - db
      - redis
    volumes:
      - ./src:/app/src
      - ./logs:/app/logs

  db:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: myapp
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: password
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data

volumes:
  postgres_data:
  redis_data:
```

## ✅ Implementation Checklist

**Security:**
- [x] Helmet.js for security headers
- [x] CORS configuration
- [x] Rate limiting
- [x] Input validation and sanitization
- [x] JWT authentication with refresh tokens
- [x] Password hashing with bcrypt
- [x] Environment variable validation

**Database:**
- [x] Prisma ORM setup
- [x] Connection pooling
- [x] Migration strategy
- [x] Database indexing

**Monitoring:**
- [x] Structured logging
- [x] Health check endpoint
- [x] Error handling middleware
- [x] Request logging

**Testing:**
- [x] Jest configuration
- [x] Unit test examples
- [x] Integration test setup
- [x] Test database setup

**Deployment:**
- [x] Docker configuration
- [x] Environment management
- [x] Graceful shutdown
- [x] Production build process

---

*Implementation guide based on production Express.js patterns | January 2025*

**Navigation**
- ← Previous: [Tools Ecosystem](./tools-ecosystem.md)
- → Next: [Best Practices](./best-practices.md)
- ↑ Back to: [README Overview](./README.md)