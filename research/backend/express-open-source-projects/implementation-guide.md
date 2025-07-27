# Implementation Guide: Express.js Production Applications

## 🎯 Overview

Step-by-step implementation guide for building production-ready Express.js applications based on patterns and practices from successful open source projects.

## 🚀 Quick Start Guide

### Phase 1: Project Foundation (Week 1)

#### 1.1 Project Initialization

**Initialize Project Structure**
```bash
# Create project directory
mkdir my-express-api && cd my-express-api

# Initialize npm project
npm init -y

# Install core dependencies
npm install express cors helmet compression morgan dotenv
npm install bcrypt jsonwebtoken joi express-rate-limit
npm install mongoose redis winston

# Install development dependencies
npm install -D nodemon jest supertest eslint prettier
npm install -D @typescript-eslint/parser @typescript-eslint/eslint-plugin
npm install -D typescript @types/node @types/express ts-node
```

**Setup TypeScript Configuration**
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
        "moduleResolution": "node",
        "baseUrl": "./",
        "paths": {
            "@/*": ["src/*"],
            "@controllers/*": ["src/controllers/*"],
            "@services/*": ["src/services/*"],
            "@models/*": ["src/models/*"],
            "@middleware/*": ["src/middleware/*"],
            "@utils/*": ["src/utils/*"],
            "@config/*": ["src/config/*"],
            "@types/*": ["src/types/*"]
        },
        "esModuleInterop": true,
        "forceConsistentCasingInFileNames": true,
        "declaration": true,
        "sourceMap": true,
        "experimentalDecorators": true,
        "emitDecoratorMetadata": true,
        "skipLibCheck": true,
        "resolveJsonModule": true
    },
    "include": ["src/**/*"],
    "exclude": ["node_modules", "dist", "**/*.test.ts"]
}
```

**Create Initial Directory Structure**
```bash
mkdir -p src/{config,controllers,services,models,middleware,routes,utils,types}
mkdir -p tests/{unit,integration,e2e}
mkdir -p logs
mkdir -p docs
```

#### 1.2 Environment Configuration

**Environment Variables Setup**
```bash
# .env.example
NODE_ENV=development
PORT=3000

# Database
DATABASE_URL=mongodb://localhost:27017/myapp
DB_POOL_MIN=2
DB_POOL_MAX=10

# Redis
REDIS_URL=redis://localhost:6379
REDIS_KEY_PREFIX=myapp:

# JWT
JWT_SECRET=your-super-secret-jwt-key-here-min-32-chars
JWT_EXPIRES_IN=1h
JWT_REFRESH_SECRET=your-refresh-secret-key-here-min-32-chars
JWT_REFRESH_EXPIRES_IN=7d

# Security
CORS_ORIGIN=http://localhost:3000,http://localhost:3001
RATE_LIMIT_WINDOW_MS=900000
RATE_LIMIT_MAX_REQUESTS=100

# Email (optional)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASS=your-app-password

# Monitoring (optional)
NEW_RELIC_LICENSE_KEY=your-new-relic-key
SENTRY_DSN=your-sentry-dsn

# Copy to .env and fill with actual values
cp .env.example .env
```

**Environment Validation**
```typescript
// src/config/env.ts
import Joi from 'joi';

const envSchema = Joi.object({
    NODE_ENV: Joi.string().valid('development', 'production', 'test').default('development'),
    PORT: Joi.number().port().default(3000),
    DATABASE_URL: Joi.string().uri().required(),
    REDIS_URL: Joi.string().uri().required(),
    JWT_SECRET: Joi.string().min(32).required(),
    JWT_EXPIRES_IN: Joi.string().default('1h'),
    CORS_ORIGIN: Joi.string().default('*'),
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
    },
    redis: {
        url: env.REDIS_URL,
    },
    jwt: {
        secret: env.JWT_SECRET,
        expiresIn: env.JWT_EXPIRES_IN,
    },
    cors: {
        origin: env.CORS_ORIGIN.split(','),
    },
};
```

#### 1.3 Basic Express Application

**Application Setup**
```typescript
// src/app.ts
import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import compression from 'compression';
import morgan from 'morgan';
import rateLimit from 'express-rate-limit';

import { config } from '@/config/env';
import { errorHandler, notFoundHandler } from '@/middleware/error.middleware';
import { setupRoutes } from '@/routes';

const app = express();

// Security middleware
app.use(helmet());
app.use(cors({ origin: config.cors.origin, credentials: true }));

// Rate limiting
const limiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 100, // Limit each IP to 100 requests per windowMs
    message: 'Too many requests from this IP, please try again later.',
});
app.use('/api/', limiter);

// Compression and parsing
app.use(compression());
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Logging
if (config.env !== 'test') {
    app.use(morgan('combined'));
}

// Health check
app.get('/health', (req, res) => {
    res.status(200).json({ 
        status: 'OK', 
        timestamp: new Date().toISOString(),
        uptime: process.uptime()
    });
});

// Routes
setupRoutes(app);

// Error handling
app.use(notFoundHandler);
app.use(errorHandler);

export default app;
```

**Server Entry Point**
```typescript
// src/server.ts
import app from './app';
import { config } from '@/config/env';
import { connectDatabase } from '@/config/database';
import { connectRedis } from '@/config/redis';
import { logger } from '@/utils/logger';

async function startServer() {
    try {
        // Connect to databases
        await connectDatabase();
        await connectRedis();

        // Start server
        const server = app.listen(config.port, () => {
            logger.info(`Server running on port ${config.port} in ${config.env} mode`);
        });

        // Graceful shutdown
        const gracefulShutdown = (signal: string) => {
            logger.info(`Received ${signal}, shutting down gracefully`);
            server.close(() => {
                logger.info('Server closed');
                process.exit(0);
            });
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

### Phase 2: Core Features (Week 2)

#### 2.1 Database Models and Connection

**Database Connection**
```typescript
// src/config/database.ts
import mongoose from 'mongoose';
import { config } from './env';
import { logger } from '@/utils/logger';

export async function connectDatabase(): Promise<void> {
    try {
        await mongoose.connect(config.database.url, {
            maxPoolSize: 10,
            serverSelectionTimeoutMS: 5000,
            socketTimeoutMS: 45000,
        });

        logger.info('Connected to MongoDB');

        mongoose.connection.on('error', (err) => {
            logger.error('MongoDB connection error:', err);
        });

        mongoose.connection.on('disconnected', () => {
            logger.warn('MongoDB disconnected');
        });

    } catch (error) {
        logger.error('Database connection failed:', error);
        throw error;
    }
}
```

**User Model**
```typescript
// src/models/User.ts
import mongoose, { Document, Schema } from 'mongoose';
import bcrypt from 'bcrypt';

export interface IUser extends Document {
    email: string;
    password: string;
    name: string;
    role: 'user' | 'admin';
    isActive: boolean;
    emailVerified: boolean;
    lastLoginAt?: Date;
    createdAt: Date;
    updatedAt: Date;
    validatePassword(password: string): Promise<boolean>;
}

const userSchema = new Schema<IUser>({
    email: {
        type: String,
        required: true,
        unique: true,
        lowercase: true,
        trim: true,
    },
    password: {
        type: String,
        required: true,
        minlength: 8,
    },
    name: {
        type: String,
        required: true,
        trim: true,
        maxlength: 100,
    },
    role: {
        type: String,
        enum: ['user', 'admin'],
        default: 'user',
    },
    isActive: {
        type: Boolean,
        default: true,
    },
    emailVerified: {
        type: Boolean,
        default: false,
    },
    lastLoginAt: {
        type: Date,
    },
}, {
    timestamps: true,
});

// Indexes
userSchema.index({ email: 1 });
userSchema.index({ role: 1, isActive: 1 });

// Hash password before saving
userSchema.pre('save', async function(next) {
    if (!this.isModified('password')) return next();

    try {
        const salt = await bcrypt.genSalt(12);
        this.password = await bcrypt.hash(this.password, salt);
        next();
    } catch (error) {
        next(error as Error);
    }
});

// Instance method to validate password
userSchema.methods.validatePassword = async function(password: string): Promise<boolean> {
    return bcrypt.compare(password, this.password);
};

// Remove password from JSON output
userSchema.methods.toJSON = function() {
    const obj = this.toObject();
    delete obj.password;
    return obj;
};

export const User = mongoose.model<IUser>('User', userSchema);
```

#### 2.2 Authentication System

**Authentication Service**
```typescript
// src/services/auth.service.ts
import jwt from 'jsonwebtoken';
import { User, IUser } from '@/models/User';
import { config } from '@/config/env';
import { AppError } from '@/utils/errors';

export class AuthService {
    static generateToken(user: IUser): string {
        return jwt.sign(
            { 
                sub: user._id,
                email: user.email,
                role: user.role 
            },
            config.jwt.secret,
            { 
                expiresIn: config.jwt.expiresIn,
                issuer: 'myapp',
                audience: 'myapp-users'
            }
        );
    }

    static verifyToken(token: string): any {
        try {
            return jwt.verify(token, config.jwt.secret, {
                issuer: 'myapp',
                audience: 'myapp-users'
            });
        } catch (error) {
            throw new AppError('Invalid token', 401);
        }
    }

    static async register(userData: {
        email: string;
        password: string;
        name: string;
    }): Promise<{ user: IUser; token: string }> {
        // Check if user already exists
        const existingUser = await User.findOne({ email: userData.email });
        if (existingUser) {
            throw new AppError('Email already registered', 400);
        }

        // Create user
        const user = await User.create(userData);

        // Generate token
        const token = this.generateToken(user);

        return { user, token };
    }

    static async login(email: string, password: string): Promise<{ user: IUser; token: string }> {
        // Find user
        const user = await User.findOne({ email: email.toLowerCase() });
        if (!user || !user.isActive) {
            throw new AppError('Invalid credentials', 401);
        }

        // Validate password
        const isValidPassword = await user.validatePassword(password);
        if (!isValidPassword) {
            throw new AppError('Invalid credentials', 401);
        }

        // Update last login
        user.lastLoginAt = new Date();
        await user.save();

        // Generate token
        const token = this.generateToken(user);

        return { user, token };
    }

    static async getUserFromToken(token: string): Promise<IUser> {
        const payload = this.verifyToken(token);
        
        const user = await User.findById(payload.sub);
        if (!user || !user.isActive) {
            throw new AppError('User not found', 401);
        }

        return user;
    }
}
```

**Authentication Middleware**
```typescript
// src/middleware/auth.middleware.ts
import { Request, Response, NextFunction } from 'express';
import { AuthService } from '@/services/auth.service';
import { AppError } from '@/utils/errors';

interface AuthenticatedRequest extends Request {
    user?: any;
}

export const authenticate = async (
    req: AuthenticatedRequest,
    res: Response,
    next: NextFunction
): Promise<void> => {
    try {
        const authHeader = req.headers.authorization;
        const token = authHeader && authHeader.split(' ')[1];

        if (!token) {
            throw new AppError('Access token required', 401);
        }

        const user = await AuthService.getUserFromToken(token);
        req.user = user;
        next();
    } catch (error) {
        next(error);
    }
};

export const authorize = (...roles: string[]) => {
    return (req: AuthenticatedRequest, res: Response, next: NextFunction): void => {
        if (!req.user) {
            return next(new AppError('Authentication required', 401));
        }

        if (roles.length > 0 && !roles.includes(req.user.role)) {
            return next(new AppError('Insufficient permissions', 403));
        }

        next();
    };
};
```

#### 2.3 Validation and Error Handling

**Input Validation**
```typescript
// src/middleware/validation.middleware.ts
import { Request, Response, NextFunction } from 'express';
import Joi from 'joi';
import { AppError } from '@/utils/errors';

export const validate = (schema: Joi.ObjectSchema) => {
    return (req: Request, res: Response, next: NextFunction): void => {
        const { error, value } = schema.validate(req.body, {
            abortEarly: false,
            stripUnknown: true,
        });

        if (error) {
            const details = error.details.map(detail => ({
                field: detail.path.join('.'),
                message: detail.message,
            }));

            return next(new AppError('Validation failed', 400, details));
        }

        req.body = value;
        next();
    };
};

// Validation schemas
export const authSchemas = {
    register: Joi.object({
        email: Joi.string().email().required(),
        password: Joi.string()
            .min(8)
            .pattern(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])/)
            .required()
            .messages({
                'string.pattern.base': 'Password must contain uppercase, lowercase, number and special character'
            }),
        name: Joi.string().min(2).max(100).required(),
    }),

    login: Joi.object({
        email: Joi.string().email().required(),
        password: Joi.string().required(),
    }),
};
```

**Error Handling**
```typescript
// src/utils/errors.ts
export class AppError extends Error {
    public statusCode: number;
    public status: string;
    public isOperational: boolean;
    public details?: any;

    constructor(message: string, statusCode: number = 500, details?: any) {
        super(message);
        
        this.statusCode = statusCode;
        this.status = `${statusCode}`.startsWith('4') ? 'fail' : 'error';
        this.isOperational = true;
        this.details = details;

        Error.captureStackTrace(this, this.constructor);
    }
}

// src/middleware/error.middleware.ts
import { Request, Response, NextFunction } from 'express';
import { AppError } from '@/utils/errors';
import { logger } from '@/utils/logger';

export const errorHandler = (
    err: Error,
    req: Request,
    res: Response,
    next: NextFunction
): void => {
    let error = { ...err } as AppError;
    error.message = err.message;

    // Log error
    logger.error(err.stack);

    // Mongoose bad ObjectId
    if (err.name === 'CastError') {
        const message = 'Resource not found';
        error = new AppError(message, 404);
    }

    // Mongoose duplicate key
    if ((err as any).code === 11000) {
        const message = 'Duplicate field value entered';
        error = new AppError(message, 400);
    }

    // Mongoose validation error
    if (err.name === 'ValidationError') {
        const message = 'Validation Error';
        error = new AppError(message, 400);
    }

    res.status(error.statusCode || 500).json({
        success: false,
        error: {
            message: error.message,
            ...(error.details && { details: error.details }),
            ...(process.env.NODE_ENV === 'development' && { stack: err.stack }),
        },
    });
};

export const notFoundHandler = (req: Request, res: Response): void => {
    res.status(404).json({
        success: false,
        error: {
            message: `Route ${req.originalUrl} not found`,
        },
    });
};
```

### Phase 3: Advanced Features (Week 3)

#### 3.1 Controllers and Routes

**Auth Controller**
```typescript
// src/controllers/auth.controller.ts
import { Request, Response, NextFunction } from 'express';
import { AuthService } from '@/services/auth.service';
import { asyncHandler } from '@/utils/asyncHandler';

export class AuthController {
    static register = asyncHandler(async (req: Request, res: Response) => {
        const { user, token } = await AuthService.register(req.body);

        res.status(201).json({
            success: true,
            data: {
                user,
                token,
            },
            message: 'User registered successfully',
        });
    });

    static login = asyncHandler(async (req: Request, res: Response) => {
        const { email, password } = req.body;
        const { user, token } = await AuthService.login(email, password);

        res.json({
            success: true,
            data: {
                user,
                token,
            },
            message: 'Login successful',
        });
    });

    static getProfile = asyncHandler(async (req: Request, res: Response) => {
        res.json({
            success: true,
            data: req.user,
        });
    });
}
```

**Routes Setup**
```typescript
// src/routes/auth.routes.ts
import { Router } from 'express';
import { AuthController } from '@/controllers/auth.controller';
import { validate, authSchemas } from '@/middleware/validation.middleware';
import { authenticate } from '@/middleware/auth.middleware';

const router = Router();

router.post('/register', validate(authSchemas.register), AuthController.register);
router.post('/login', validate(authSchemas.login), AuthController.login);
router.get('/profile', authenticate, AuthController.getProfile);

export default router;

// src/routes/index.ts
import { Application } from 'express';
import authRoutes from './auth.routes';

export function setupRoutes(app: Application): void {
    app.use('/api/auth', authRoutes);
    
    // API documentation
    app.get('/api', (req, res) => {
        res.json({
            message: 'API is running!',
            version: '1.0.0',
            endpoints: {
                auth: '/api/auth',
                health: '/health',
            },
        });
    });
}
```

#### 3.2 Async Handler Utility

```typescript
// src/utils/asyncHandler.ts
import { Request, Response, NextFunction } from 'express';

export const asyncHandler = (fn: Function) => {
    return (req: Request, res: Response, next: NextFunction) => {
        Promise.resolve(fn(req, res, next)).catch(next);
    };
};
```

#### 3.3 Logger Setup

```typescript
// src/utils/logger.ts
import winston from 'winston';

const logger = winston.createLogger({
    level: process.env.LOG_LEVEL || 'info',
    format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.errors({ stack: true }),
        winston.format.json()
    ),
    defaultMeta: { service: 'myapp' },
    transports: [
        new winston.transports.File({ filename: 'logs/error.log', level: 'error' }),
        new winston.transports.File({ filename: 'logs/combined.log' }),
    ],
});

if (process.env.NODE_ENV !== 'production') {
    logger.add(new winston.transports.Console({
        format: winston.format.simple()
    }));
}

export { logger };
```

### Phase 4: Testing (Week 4)

#### 4.1 Testing Setup

**Jest Configuration**
```javascript
// jest.config.js
module.exports = {
    preset: 'ts-jest',
    testEnvironment: 'node',
    roots: ['<rootDir>/src', '<rootDir>/tests'],
    testMatch: ['**/__tests__/**/*.ts', '**/?(*.)+(spec|test).ts'],
    transform: {
        '^.+\\.ts$': 'ts-jest',
    },
    collectCoverageFrom: [
        'src/**/*.ts',
        '!src/**/*.d.ts',
        '!src/server.ts',
    ],
    coverageDirectory: 'coverage',
    coverageReporters: ['text', 'lcov', 'html'],
    setupFilesAfterEnv: ['<rootDir>/tests/setup.ts'],
    moduleNameMapping: {
        '^@/(.*)$': '<rootDir>/src/$1',
    },
};
```

**Test Setup**
```typescript
// tests/setup.ts
import { MongoMemoryServer } from 'mongodb-memory-server';
import mongoose from 'mongoose';

let mongoServer: MongoMemoryServer;

beforeAll(async () => {
    mongoServer = await MongoMemoryServer.create();
    const mongoUri = mongoServer.getUri();
    await mongoose.connect(mongoUri);
});

afterAll(async () => {
    await mongoose.disconnect();
    await mongoServer.stop();
});

afterEach(async () => {
    const collections = mongoose.connection.collections;
    for (const key in collections) {
        await collections[key].deleteMany({});
    }
});
```

#### 4.2 Unit Tests

**Auth Service Tests**
```typescript
// tests/unit/auth.service.test.ts
import { AuthService } from '@/services/auth.service';
import { User } from '@/models/User';
import { AppError } from '@/utils/errors';

describe('AuthService', () => {
    describe('register', () => {
        it('should register a new user', async () => {
            const userData = {
                email: 'test@example.com',
                password: 'Password123!',
                name: 'Test User',
            };

            const result = await AuthService.register(userData);

            expect(result.user.email).toBe(userData.email);
            expect(result.user.name).toBe(userData.name);
            expect(result.token).toBeDefined();
        });

        it('should throw error for duplicate email', async () => {
            const userData = {
                email: 'test@example.com',
                password: 'Password123!',
                name: 'Test User',
            };

            await AuthService.register(userData);

            await expect(AuthService.register(userData))
                .rejects.toThrow(AppError);
        });
    });

    describe('login', () => {
        beforeEach(async () => {
            await User.create({
                email: 'test@example.com',
                password: 'Password123!',
                name: 'Test User',
            });
        });

        it('should login with valid credentials', async () => {
            const result = await AuthService.login('test@example.com', 'Password123!');

            expect(result.user.email).toBe('test@example.com');
            expect(result.token).toBeDefined();
        });

        it('should throw error for invalid credentials', async () => {
            await expect(AuthService.login('test@example.com', 'wrongpassword'))
                .rejects.toThrow(AppError);
        });
    });
});
```

#### 4.3 Integration Tests

**API Integration Tests**
```typescript
// tests/integration/auth.test.ts
import request from 'supertest';
import app from '@/app';

describe('Auth API', () => {
    describe('POST /api/auth/register', () => {
        it('should register a new user', async () => {
            const userData = {
                email: 'test@example.com',
                password: 'Password123!',
                name: 'Test User',
            };

            const response = await request(app)
                .post('/api/auth/register')
                .send(userData)
                .expect(201);

            expect(response.body.success).toBe(true);
            expect(response.body.data.user.email).toBe(userData.email);
            expect(response.body.data.token).toBeDefined();
        });

        it('should return validation error for invalid data', async () => {
            const invalidData = {
                email: 'invalid-email',
                password: '123', // Too short
                name: '', // Empty
            };

            const response = await request(app)
                .post('/api/auth/register')
                .send(invalidData)
                .expect(400);

            expect(response.body.success).toBe(false);
            expect(response.body.error.details).toBeDefined();
        });
    });

    describe('POST /api/auth/login', () => {
        beforeEach(async () => {
            await request(app)
                .post('/api/auth/register')
                .send({
                    email: 'test@example.com',
                    password: 'Password123!',
                    name: 'Test User',
                });
        });

        it('should login with valid credentials', async () => {
            const response = await request(app)
                .post('/api/auth/login')
                .send({
                    email: 'test@example.com',
                    password: 'Password123!',
                })
                .expect(200);

            expect(response.body.success).toBe(true);
            expect(response.body.data.token).toBeDefined();
        });
    });

    describe('GET /api/auth/profile', () => {
        let token: string;

        beforeEach(async () => {
            const registerResponse = await request(app)
                .post('/api/auth/register')
                .send({
                    email: 'test@example.com',
                    password: 'Password123!',
                    name: 'Test User',
                });

            token = registerResponse.body.data.token;
        });

        it('should return user profile with valid token', async () => {
            const response = await request(app)
                .get('/api/auth/profile')
                .set('Authorization', `Bearer ${token}`)
                .expect(200);

            expect(response.body.success).toBe(true);
            expect(response.body.data.email).toBe('test@example.com');
        });

        it('should return 401 without token', async () => {
            await request(app)
                .get('/api/auth/profile')
                .expect(401);
        });
    });
});
```

### Phase 5: Production Deployment (Week 5)

#### 5.1 Docker Configuration

```dockerfile
# Dockerfile
FROM node:18-alpine AS base
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force

FROM node:18-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM base AS production
COPY --from=build /app/dist ./dist
COPY --from=build /app/package.json ./
EXPOSE 3000
USER node
CMD ["node", "dist/server.js"]
```

**Docker Compose for Development**
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
      - DATABASE_URL=mongodb://mongo:27017/myapp
      - REDIS_URL=redis://redis:6379
    volumes:
      - .:/app
      - /app/node_modules
    depends_on:
      - mongo
      - redis

  mongo:
    image: mongo:5.0
    ports:
      - "27017:27017"
    volumes:
      - mongo_data:/data/db

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"

volumes:
  mongo_data:
```

#### 5.2 Package.json Scripts

```json
{
    "scripts": {
        "dev": "nodemon src/server.ts",
        "build": "tsc",
        "start": "node dist/server.js",
        "test": "jest",
        "test:watch": "jest --watch",
        "test:coverage": "jest --coverage",
        "lint": "eslint src --ext .ts",
        "lint:fix": "eslint src --ext .ts --fix",
        "format": "prettier --write \"src/**/*.ts\"",
        "docker:build": "docker build -t myapp .",
        "docker:run": "docker run -p 3000:3000 myapp"
    }
}
```

## 🔧 Advanced Implementation Patterns

### 1. CRUD Service Generator

**Generic CRUD Service**
```typescript
// src/services/base.service.ts
import { Document, Model, FilterQuery, UpdateQuery } from 'mongoose';
import { AppError } from '@/utils/errors';

export class BaseService<T extends Document> {
    constructor(private model: Model<T>) {}

    async create(data: Partial<T>): Promise<T> {
        try {
            return await this.model.create(data);
        } catch (error) {
            throw new AppError('Failed to create resource', 400);
        }
    }

    async findById(id: string): Promise<T | null> {
        if (!id.match(/^[0-9a-fA-F]{24}$/)) {
            throw new AppError('Invalid ID format', 400);
        }

        return await this.model.findById(id);
    }

    async findOne(filter: FilterQuery<T>): Promise<T | null> {
        return await this.model.findOne(filter);
    }

    async findMany(filter: FilterQuery<T> = {}, options: any = {}): Promise<T[]> {
        const { sort = {}, limit = 10, skip = 0 } = options;
        
        return await this.model
            .find(filter)
            .sort(sort)
            .limit(limit)
            .skip(skip);
    }

    async update(id: string, data: UpdateQuery<T>): Promise<T | null> {
        if (!id.match(/^[0-9a-fA-F]{24}$/)) {
            throw new AppError('Invalid ID format', 400);
        }

        return await this.model.findByIdAndUpdate(id, data, {
            new: true,
            runValidators: true,
        });
    }

    async delete(id: string): Promise<boolean> {
        if (!id.match(/^[0-9a-fA-F]{24}$/)) {
            throw new AppError('Invalid ID format', 400);
        }

        const result = await this.model.findByIdAndDelete(id);
        return !!result;
    }

    async count(filter: FilterQuery<T> = {}): Promise<number> {
        return await this.model.countDocuments(filter);
    }
}
```

### 2. API Response Formatter

**Response Formatter Utility**
```typescript
// src/utils/response.ts
import { Response } from 'express';

export class ApiResponse {
    static success(res: Response, data: any, message?: string, statusCode: number = 200) {
        return res.status(statusCode).json({
            success: true,
            data,
            message,
            timestamp: new Date().toISOString(),
        });
    }

    static error(res: Response, message: string, statusCode: number = 500, details?: any) {
        return res.status(statusCode).json({
            success: false,
            error: {
                message,
                details,
            },
            timestamp: new Date().toISOString(),
        });
    }

    static paginated(res: Response, data: any[], pagination: any, message?: string) {
        return res.json({
            success: true,
            data,
            pagination,
            message,
            timestamp: new Date().toISOString(),
        });
    }
}
```

### 3. Redis Cache Integration

**Cache Service**
```typescript
// src/config/redis.ts
import Redis from 'ioredis';
import { config } from './env';
import { logger } from '@/utils/logger';

const redis = new Redis(config.redis.url, {
    retryDelayOnFailover: 100,
    enableReadyCheck: false,
    maxRetriesPerRequest: null,
});

redis.on('connect', () => {
    logger.info('Connected to Redis');
});

redis.on('error', (err) => {
    logger.error('Redis connection error:', err);
});

export { redis };

// src/services/cache.service.ts
import { redis } from '@/config/redis';

export class CacheService {
    static async get<T>(key: string): Promise<T | null> {
        try {
            const cached = await redis.get(key);
            return cached ? JSON.parse(cached) : null;
        } catch (error) {
            console.error('Cache get error:', error);
            return null;
        }
    }

    static async set(key: string, value: any, ttl: number = 3600): Promise<boolean> {
        try {
            await redis.setex(key, ttl, JSON.stringify(value));
            return true;
        } catch (error) {
            console.error('Cache set error:', error);
            return false;
        }
    }

    static async del(key: string): Promise<boolean> {
        try {
            await redis.del(key);
            return true;
        } catch (error) {
            console.error('Cache delete error:', error);
            return false;
        }
    }

    static async flush(): Promise<boolean> {
        try {
            await redis.flushall();
            return true;
        } catch (error) {
            console.error('Cache flush error:', error);
            return false;
        }
    }
}
```

## 📈 Performance Optimization

### 1. Database Query Optimization

```typescript
// src/utils/queryBuilder.ts
export class QueryBuilder {
    static buildPaginationQuery(page: number = 1, limit: number = 10) {
        const skip = (page - 1) * limit;
        return { skip, limit: Math.min(limit, 100) }; // Max 100 items
    }

    static buildSortQuery(sortString: string = '-createdAt') {
        const sorts = sortString.split(',');
        const sortObj: any = {};

        sorts.forEach(sort => {
            if (sort.startsWith('-')) {
                sortObj[sort.substring(1)] = -1;
            } else {
                sortObj[sort] = 1;
            }
        });

        return sortObj;
    }

    static buildFilterQuery(filters: any) {
        const query: any = {};

        Object.keys(filters).forEach(key => {
            if (filters[key] !== undefined && filters[key] !== '') {
                if (typeof filters[key] === 'string' && filters[key].includes(',')) {
                    query[key] = { $in: filters[key].split(',') };
                } else {
                    query[key] = filters[key];
                }
            }
        });

        return query;
    }
}
```

### 2. Monitoring and Health Checks

```typescript
// src/middleware/monitoring.ts
import { Request, Response, NextFunction } from 'express';
import { performance } from 'perf_hooks';

export const requestTimer = (req: Request, res: Response, next: NextFunction) => {
    const start = performance.now();

    res.on('finish', () => {
        const duration = performance.now() - start;
        console.log(`${req.method} ${req.originalUrl} - ${res.statusCode} - ${duration.toFixed(2)}ms`);
    });

    next();
};

// src/routes/health.routes.ts
import { Router } from 'express';
import mongoose from 'mongoose';
import { redis } from '@/config/redis';

const router = Router();

router.get('/health', async (req, res) => {
    const health = {
        status: 'OK',
        timestamp: new Date().toISOString(),
        uptime: process.uptime(),
        checks: {
            database: 'OK',
            redis: 'OK',
            memory: 'OK',
        },
    };

    try {
        // Check database
        await mongoose.connection.db.admin().ping();
    } catch (error) {
        health.checks.database = 'ERROR';
        health.status = 'ERROR';
    }

    try {
        // Check Redis
        await redis.ping();
    } catch (error) {
        health.checks.redis = 'ERROR';
        health.status = 'ERROR';
    }

    // Check memory usage
    const memoryUsage = process.memoryUsage();
    if (memoryUsage.heapUsed > 512 * 1024 * 1024) { // 512MB
        health.checks.memory = 'WARNING';
    }

    const statusCode = health.status === 'OK' ? 200 : 503;
    res.status(statusCode).json(health);
});

export default router;
```

## 🔗 Navigation

← [Best Practices](./best-practices.md) | [Comparison Analysis](./comparison-analysis.md) →