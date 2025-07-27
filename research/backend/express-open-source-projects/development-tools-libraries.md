# Development Tools & Libraries in Express.js Applications

## 🛠️ Ecosystem Overview

The Express.js ecosystem is rich with tools and libraries that enhance development productivity, code quality, and application functionality. This analysis examines the most commonly used and battle-tested tools found in production Express.js applications.

---

## 📊 Essential Tools Matrix

### Core Development Tools
| Category | Tool | Adoption Rate | Learning Curve | Value Rating |
|----------|------|---------------|----------------|--------------|
| **Type Safety** | TypeScript | 95% | Medium | Essential |
| **Validation** | Joi / Zod | 90% | Low | High |
| **ORM/ODM** | Prisma / Mongoose | 85% | Medium | High |
| **Testing** | Jest + Supertest | 90% | Low | Essential |
| **Linting** | ESLint + Prettier | 95% | Low | Essential |
| **Documentation** | Swagger/OpenAPI | 80% | Low | High |
| **Process Manager** | PM2 | 85% | Low | High |
| **Monitoring** | Winston + Morgan | 80% | Low | Medium |

---

## 🔧 Core Development Stack

### 1. TypeScript Configuration

```json
// tsconfig.json - Production-ready configuration
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
    "declarationMap": true,
    "sourceMap": true,
    "removeComments": true,
    "noImplicitAny": true,
    "noImplicitReturns": true,
    "noImplicitThis": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "exactOptionalPropertyTypes": true,
    "noUncheckedIndexedAccess": true,
    "noImplicitOverride": true,
    "allowUnreachableCode": false,
    "allowUnusedLabels": false,
    "baseUrl": "./src",
    "paths": {
      "@/*": ["*"],
      "@/controllers/*": ["controllers/*"],
      "@/services/*": ["services/*"],
      "@/models/*": ["models/*"],
      "@/middleware/*": ["middleware/*"],
      "@/types/*": ["types/*"],
      "@/utils/*": ["utils/*"]
    }
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist", "**/*.test.ts", "**/*.spec.ts"]
}

// package.json scripts
{
  "scripts": {
    "build": "tsc",
    "build:watch": "tsc --watch",
    "start": "node dist/app.js",
    "dev": "tsx watch src/app.ts",
    "type-check": "tsc --noEmit",
    "clean": "rimraf dist"
  }
}
```

### 2. ESLint & Prettier Configuration

```json
// .eslintrc.json
{
  "env": {
    "node": true,
    "es2020": true
  },
  "extends": [
    "eslint:recommended",
    "@typescript-eslint/recommended",
    "@typescript-eslint/recommended-requiring-type-checking",
    "prettier"
  ],
  "parser": "@typescript-eslint/parser",
  "parserOptions": {
    "ecmaVersion": 2020,
    "sourceType": "module",
    "project": "./tsconfig.json"
  },
  "plugins": [
    "@typescript-eslint",
    "import",
    "security"
  ],
  "rules": {
    "@typescript-eslint/no-unused-vars": ["error", { "argsIgnorePattern": "^_" }],
    "@typescript-eslint/explicit-function-return-type": "warn",
    "@typescript-eslint/no-explicit-any": "error",
    "@typescript-eslint/no-non-null-assertion": "error",
    "@typescript-eslint/prefer-nullish-coalescing": "error",
    "@typescript-eslint/prefer-optional-chain": "error",
    "import/order": ["error", {
      "groups": ["builtin", "external", "internal", "parent", "sibling", "index"],
      "newlines-between": "always"
    }],
    "security/detect-object-injection": "warn",
    "security/detect-sql-injection": "error",
    "no-console": ["warn", { "allow": ["warn", "error"] }]
  }
}

// .prettierrc
{
  "semi": true,
  "trailingComma": "es5",
  "singleQuote": true,
  "printWidth": 100,
  "tabWidth": 2,
  "useTabs": false,
  "arrowParens": "avoid",
  "endOfLine": "lf"
}
```

### 3. Package.json Dependencies

```json
{
  "dependencies": {
    "express": "^4.18.2",
    "helmet": "^7.0.0",
    "cors": "^2.8.5",
    "compression": "^1.7.4",
    "express-rate-limit": "^6.8.1",
    "express-validator": "^7.0.1",
    "bcrypt": "^5.1.0",
    "jsonwebtoken": "^9.0.2",
    "passport": "^0.6.0",
    "passport-jwt": "^4.0.1",
    "passport-google-oauth20": "^2.0.0",
    "redis": "^4.6.7",
    "ioredis": "^5.3.2",
    "prisma": "^5.1.1",
    "@prisma/client": "^5.1.1",
    "winston": "^3.10.0",
    "morgan": "^1.10.0",
    "dotenv": "^16.3.1",
    "joi": "^17.9.2",
    "nodemailer": "^6.9.4",
    "multer": "^1.4.5-lts.1",
    "sharp": "^0.32.4",
    "date-fns": "^2.30.0",
    "lodash": "^4.17.21",
    "uuid": "^9.0.0"
  },
  "devDependencies": {
    "@types/node": "^20.4.5",
    "@types/express": "^4.17.17",
    "@types/bcrypt": "^5.0.0",
    "@types/jsonwebtoken": "^9.0.2",
    "@types/passport": "^1.0.12",
    "@types/passport-jwt": "^3.0.9",
    "@types/morgan": "^1.9.4",
    "@types/joi": "^17.2.3",
    "@types/nodemailer": "^6.4.9",
    "@types/multer": "^1.4.7",
    "@types/lodash": "^4.14.195",
    "@types/uuid": "^9.0.2",
    "typescript": "^5.1.6",
    "@typescript-eslint/eslint-plugin": "^6.2.1",
    "@typescript-eslint/parser": "^6.2.1",
    "eslint": "^8.46.0",
    "eslint-config-prettier": "^8.9.0",
    "eslint-plugin-import": "^2.28.0",
    "eslint-plugin-security": "^1.7.1",
    "prettier": "^3.0.0",
    "jest": "^29.6.1",
    "@types/jest": "^29.5.3",
    "ts-jest": "^29.1.1",
    "supertest": "^6.3.3",
    "@types/supertest": "^2.0.12",
    "tsx": "^3.12.7",
    "rimraf": "^5.0.1",
    "nodemon": "^3.0.1",
    "husky": "^8.0.3",
    "lint-staged": "^13.2.3"
  }
}
```

---

## 🗄️ Database & ORM Tools

### 1. Prisma Configuration

```typescript
// schema.prisma
generator client {
  provider = "prisma-client-js"
  binaryTargets = ["native", "debian-openssl-3.0.x"]
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

model User {
  id                String    @id @default(uuid())
  email             String    @unique
  password          String?
  name              String
  avatar            String?
  role              Role      @default(USER)
  isEmailVerified   Boolean   @default(false)
  mfaEnabled        Boolean   @default(false)
  mfaSecret         String?
  lastLoginAt       DateTime?
  createdAt         DateTime  @default(now())
  updatedAt         DateTime  @updatedAt

  // Relations
  posts             Post[]
  sessions          Session[]
  oauthAccounts     OAuthAccount[]
  refreshTokens     RefreshToken[]

  @@map("users")
}

model Post {
  id          String    @id @default(uuid())
  title       String
  content     String
  published   Boolean   @default(false)
  publishedAt DateTime?
  authorId    String
  createdAt   DateTime  @default(now())
  updatedAt   DateTime  @updatedAt

  // Relations
  author      User      @relation(fields: [authorId], references: [id], onDelete: Cascade)
  tags        Tag[]

  @@index([authorId])
  @@index([published, publishedAt])
  @@map("posts")
}

enum Role {
  USER
  MODERATOR
  ADMIN
  SUPER_ADMIN
}

// Prisma service wrapper
import { PrismaClient } from '@prisma/client';

class DatabaseService {
  private static instance: DatabaseService;
  public client: PrismaClient;

  private constructor() {
    this.client = new PrismaClient({
      log: process.env.NODE_ENV === 'development' 
        ? ['query', 'info', 'warn', 'error']
        : ['error'],
      errorFormat: 'pretty',
    });

    // Middleware for soft deletes
    this.client.$use(async (params, next) => {
      if (params.action === 'delete') {
        params.action = 'update';
        params.args['data'] = { deletedAt: new Date() };
      }
      
      if (params.action === 'deleteMany') {
        params.action = 'updateMany';
        if (params.args.data !== undefined) {
          params.args.data['deletedAt'] = new Date();
        } else {
          params.args['data'] = { deletedAt: new Date() };
        }
      }

      return next(params);
    });

    // Query performance logging
    this.client.$use(async (params, next) => {
      const before = Date.now();
      const result = await next(params);
      const after = Date.now();
      
      const duration = after - before;
      if (duration > 1000) { // Log slow queries
        console.warn(`Slow query detected: ${duration}ms`, {
          model: params.model,
          action: params.action,
        });
      }
      
      return result;
    });
  }

  public static getInstance(): DatabaseService {
    if (!DatabaseService.instance) {
      DatabaseService.instance = new DatabaseService();
    }
    return DatabaseService.instance;
  }

  async healthCheck(): Promise<boolean> {
    try {
      await this.client.$queryRaw`SELECT 1`;
      return true;
    } catch (error) {
      console.error('Database health check failed:', error);
      return false;
    }
  }

  async disconnect(): Promise<void> {
    await this.client.$disconnect();
  }
}

export const db = DatabaseService.getInstance().client;
```

### 2. Mongoose Configuration (Alternative)

```typescript
import mongoose from 'mongoose';
import { MongoMemoryServer } from 'mongodb-memory-server';

class MongooseService {
  private static instance: MongooseService;
  private mongoServer?: MongoMemoryServer;

  private constructor() {}

  public static getInstance(): MongooseService {
    if (!MongooseService.instance) {
      MongooseService.instance = new MongooseService();
    }
    return MongooseService.instance;
  }

  async connect(): Promise<void> {
    const mongoUri = process.env.NODE_ENV === 'test'
      ? await this.getTestDatabaseUri()
      : process.env.MONGODB_URI!;

    await mongoose.connect(mongoUri, {
      maxPoolSize: 10,
      serverSelectionTimeoutMS: 5000,
      socketTimeoutMS: 45000,
      bufferCommands: false,
      bufferMaxEntries: 0,
    });

    // Connection event handlers
    mongoose.connection.on('connected', () => {
      console.log('MongoDB connected successfully');
    });

    mongoose.connection.on('error', (error) => {
      console.error('MongoDB connection error:', error);
    });

    mongoose.connection.on('disconnected', () => {
      console.warn('MongoDB disconnected');
    });
  }

  async disconnect(): Promise<void> {
    if (this.mongoServer) {
      await this.mongoServer.stop();
    }
    await mongoose.disconnect();
  }

  private async getTestDatabaseUri(): Promise<string> {
    this.mongoServer = await MongoMemoryServer.create();
    return this.mongoServer.getUri();
  }
}

// User schema with Mongoose
import { Schema, model, Document } from 'mongoose';

interface IUser extends Document {
  email: string;
  password?: string;
  name: string;
  role: 'user' | 'admin';
  isEmailVerified: boolean;
  createdAt: Date;
  updatedAt: Date;
  toPublic(): Partial<IUser>;
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
    select: false, // Don't include password in queries by default
  },
  name: {
    type: String,
    required: true,
    trim: true,
  },
  role: {
    type: String,
    enum: ['user', 'admin'],
    default: 'user',
  },
  isEmailVerified: {
    type: Boolean,
    default: false,
  },
}, {
  timestamps: true,
  versionKey: false,
});

// Indexes
userSchema.index({ email: 1 });
userSchema.index({ createdAt: -1 });

// Methods
userSchema.methods.toPublic = function(): Partial<IUser> {
  return {
    id: this._id,
    email: this.email,
    name: this.name,
    role: this.role,
    isEmailVerified: this.isEmailVerified,
    createdAt: this.createdAt,
    updatedAt: this.updatedAt,
  };
};

export const User = model<IUser>('User', userSchema);
```

---

## ✅ Validation Libraries

### 1. Joi Validation

```typescript
import Joi from 'joi';

// Custom validation schemas
export const validationSchemas = {
  user: {
    create: Joi.object({
      email: Joi.string().email().required(),
      password: Joi.string()
        .min(8)
        .pattern(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]/)
        .required()
        .messages({
          'string.pattern.base': 'Password must contain at least one uppercase letter, one lowercase letter, one number, and one special character',
        }),
      name: Joi.string().min(2).max(50).required(),
      role: Joi.string().valid('user', 'admin').default('user'),
    }),

    update: Joi.object({
      email: Joi.string().email(),
      name: Joi.string().min(2).max(50),
      role: Joi.string().valid('user', 'admin'),
    }).min(1),

    login: Joi.object({
      email: Joi.string().email().required(),
      password: Joi.string().required(),
    }),
  },

  post: {
    create: Joi.object({
      title: Joi.string().min(1).max(200).required(),
      content: Joi.string().min(1).required(),
      published: Joi.boolean().default(false),
      tags: Joi.array().items(Joi.string()).max(10),
    }),

    update: Joi.object({
      title: Joi.string().min(1).max(200),
      content: Joi.string().min(1),
      published: Joi.boolean(),
      tags: Joi.array().items(Joi.string()).max(10),
    }).min(1),
  },

  query: {
    pagination: Joi.object({
      page: Joi.number().integer().min(1).default(1),
      limit: Joi.number().integer().min(1).max(100).default(20),
      sortBy: Joi.string().valid('createdAt', 'updatedAt', 'name', 'email'),
      sortOrder: Joi.string().valid('asc', 'desc').default('desc'),
    }),

    search: Joi.object({
      q: Joi.string().min(1).max(100),
      category: Joi.string(),
      status: Joi.string().valid('active', 'inactive'),
      dateFrom: Joi.date().iso(),
      dateTo: Joi.date().iso().min(Joi.ref('dateFrom')),
    }),
  },
};

// Validation middleware factory
export const validate = (schema: Joi.ObjectSchema, property: 'body' | 'query' | 'params' = 'body') => {
  return (req: Request, res: Response, next: NextFunction): void => {
    const { error, value } = schema.validate(req[property], {
      abortEarly: false,
      stripUnknown: true,
      allowUnknown: false,
    });

    if (error) {
      const errors = error.details.map(detail => ({
        field: detail.path.join('.'),
        message: detail.message,
        value: detail.context?.value,
      }));

      res.status(400).json({
        error: 'Validation failed',
        details: errors,
      });
      return;
    }

    req[property] = value;
    next();
  };
};

// Usage in routes
app.post('/api/users',
  validate(validationSchemas.user.create),
  userController.createUser
);

app.get('/api/posts',
  validate(validationSchemas.query.pagination, 'query'),
  validate(validationSchemas.query.search, 'query'),
  postController.getPosts
);
```

### 2. Zod Validation (Modern Alternative)

```typescript
import { z } from 'zod';

// Zod schemas with TypeScript integration
export const schemas = {
  user: {
    create: z.object({
      email: z.string().email('Invalid email format'),
      password: z.string()
        .min(8, 'Password must be at least 8 characters')
        .regex(
          /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]/,
          'Password must contain uppercase, lowercase, number, and special character'
        ),
      name: z.string().min(2).max(50),
      role: z.enum(['user', 'admin']).default('user'),
    }),

    update: z.object({
      email: z.string().email().optional(),
      name: z.string().min(2).max(50).optional(),
      role: z.enum(['user', 'admin']).optional(),
    }).refine(data => Object.keys(data).length > 0, {
      message: 'At least one field must be provided',
    }),
  },

  post: {
    create: z.object({
      title: z.string().min(1).max(200),
      content: z.string().min(1),
      published: z.boolean().default(false),
      tags: z.array(z.string()).max(10).optional(),
    }),
  },

  pagination: z.object({
    page: z.coerce.number().int().min(1).default(1),
    limit: z.coerce.number().int().min(1).max(100).default(20),
    sortBy: z.enum(['createdAt', 'updatedAt', 'name', 'email']).optional(),
    sortOrder: z.enum(['asc', 'desc']).default('desc'),
  }),
};

// Type inference from Zod schemas
export type CreateUserDto = z.infer<typeof schemas.user.create>;
export type UpdateUserDto = z.infer<typeof schemas.user.update>;
export type CreatePostDto = z.infer<typeof schemas.post.create>;
export type PaginationQuery = z.infer<typeof schemas.pagination>;

// Zod validation middleware
export const validateZod = <T extends z.ZodType>(schema: T, property: 'body' | 'query' | 'params' = 'body') => {
  return (req: Request, res: Response, next: NextFunction): void => {
    try {
      const validated = schema.parse(req[property]);
      req[property] = validated;
      next();
    } catch (error) {
      if (error instanceof z.ZodError) {
        const errors = error.errors.map(err => ({
          field: err.path.join('.'),
          message: err.message,
          value: err.received,
        }));

        res.status(400).json({
          error: 'Validation failed',
          details: errors,
        });
        return;
      }
      next(error);
    }
  };
};
```

---

## 📝 Logging & Monitoring

### 1. Winston Logger Configuration

```typescript
import winston from 'winston';
import DailyRotateFile from 'winston-daily-rotate-file';

// Custom log format
const logFormat = winston.format.combine(
  winston.format.timestamp(),
  winston.format.errors({ stack: true }),
  winston.format.json(),
  winston.format.printf(({ timestamp, level, message, ...meta }) => {
    return JSON.stringify({
      timestamp,
      level,
      message,
      ...meta,
    });
  })
);

// Logger configuration
export const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: logFormat,
  defaultMeta: {
    service: process.env.SERVICE_NAME || 'express-api',
    version: process.env.APP_VERSION || '1.0.0',
  },
  transports: [
    // Console transport for development
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.colorize(),
        winston.format.simple()
      ),
    }),

    // File transport for all logs
    new DailyRotateFile({
      filename: 'logs/app-%DATE%.log',
      datePattern: 'YYYY-MM-DD',
      maxSize: '20m',
      maxFiles: '14d',
      level: 'info',
    }),

    // Separate file for errors
    new DailyRotateFile({
      filename: 'logs/error-%DATE%.log',
      datePattern: 'YYYY-MM-DD',
      maxSize: '20m',
      maxFiles: '30d',
      level: 'error',
    }),
  ],

  // Handle uncaught exceptions
  exceptionHandlers: [
    new winston.transports.File({
      filename: 'logs/exceptions.log',
    }),
  ],

  // Handle unhandled promise rejections
  rejectionHandlers: [
    new winston.transports.File({
      filename: 'logs/rejections.log',
    }),
  ],
});

// Structured logging utilities
export class StructuredLogger {
  static request(req: Request, res: Response, duration: number): void {
    logger.info('HTTP Request', {
      method: req.method,
      url: req.url,
      statusCode: res.statusCode,
      duration,
      userAgent: req.headers['user-agent'],
      ip: req.ip,
      userId: req.user?.id,
    });
  }

  static error(error: Error, context: Record<string, any> = {}): void {
    logger.error('Application Error', {
      message: error.message,
      stack: error.stack,
      name: error.name,
      ...context,
    });
  }

  static security(event: string, details: Record<string, any>): void {
    logger.warn('Security Event', {
      event,
      ...details,
      timestamp: new Date().toISOString(),
    });
  }

  static performance(operation: string, duration: number, metadata: Record<string, any> = {}): void {
    logger.info('Performance Metric', {
      operation,
      duration,
      ...metadata,
    });
  }

  static business(event: string, details: Record<string, any>): void {
    logger.info('Business Event', {
      event,
      ...details,
      timestamp: new Date().toISOString(),
    });
  }
}
```

### 2. Morgan HTTP Request Logger

```typescript
import morgan from 'morgan';
import { logger } from './winston';

// Custom Morgan token for request ID
morgan.token('id', (req: Request) => req.id);

// Custom Morgan token for user ID
morgan.token('user', (req: Request) => req.user?.id || 'anonymous');

// Custom format string
const morganFormat = ':id :method :url :status :res[content-length] - :response-time ms - :user';

// Stream to Winston
const morganStream = {
  write: (message: string) => {
    logger.info(message.trim());
  },
};

// Morgan middleware configuration
export const requestLogger = morgan(morganFormat, {
  stream: morganStream,
  skip: (req, res) => {
    // Skip health check endpoints and static files
    return req.url.includes('/health') || req.url.includes('/static');
  },
});

// Request ID middleware
export const requestId = (req: Request, res: Response, next: NextFunction): void => {
  req.id = crypto.randomUUID();
  res.setHeader('X-Request-ID', req.id);
  next();
};

// Performance timing middleware
export const performanceTimer = (req: Request, res: Response, next: NextFunction): void => {
  const start = process.hrtime.bigint();
  
  res.on('finish', () => {
    const duration = Number(process.hrtime.bigint() - start) / 1000000; // Convert to ms
    
    StructuredLogger.performance('http_request', duration, {
      method: req.method,
      url: req.url,
      statusCode: res.statusCode,
      requestId: req.id,
    });
  });
  
  next();
};
```

---

## 🧪 Testing Framework

### 1. Jest Configuration

```javascript
// jest.config.js
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  roots: ['<rootDir>/src'],
  testMatch: [
    '**/__tests__/**/*.ts',
    '**/?(*.)+(spec|test).ts'
  ],
  transform: {
    '^.+\\.ts$': 'ts-jest'
  },
  collectCoverageFrom: [
    'src/**/*.ts',
    '!src/**/*.d.ts',
    '!src/types/**/*',
    '!src/__tests__/**/*'
  ],
  coverageDirectory: 'coverage',
  coverageReporters: ['text', 'lcov', 'html'],
  coverageThreshold: {
    global: {
      branches: 80,
      functions: 80,
      lines: 80,
      statements: 80
    }
  },
  setupFilesAfterEnv: ['<rootDir>/src/__tests__/setup.ts'],
  testTimeout: 10000,
  maxWorkers: '50%',
  verbose: true
};

// src/__tests__/setup.ts
import { MongoMemoryServer } from 'mongodb-memory-server';
import { DatabaseService } from '../services/database';

let mongoServer: MongoMemoryServer;

beforeAll(async () => {
  // Setup test database
  mongoServer = await MongoMemoryServer.create();
  process.env.DATABASE_URL = mongoServer.getUri();
  
  await DatabaseService.getInstance().connect();
});

afterAll(async () => {
  await DatabaseService.getInstance().disconnect();
  await mongoServer.stop();
});

beforeEach(async () => {
  // Clean database before each test
  const collections = await mongoose.connection.db.collections();
  for (const collection of collections) {
    await collection.deleteMany({});
  }
});
```

### 2. Testing Utilities

```typescript
// src/__tests__/utils/testHelpers.ts
import supertest from 'supertest';
import { app } from '../../app';
import { User } from '../../models/User';
import { generateJWT } from '../../services/auth';

export const request = supertest(app);

// Test user factory
export const createTestUser = async (overrides: Partial<IUser> = {}) => {
  const userData = {
    email: 'test@example.com',
    password: 'Test123!@#',
    name: 'Test User',
    role: 'user',
    isEmailVerified: true,
    ...overrides,
  };

  const user = await User.create(userData);
  return user;
};

// Authentication helper
export const authenticateUser = async (user?: IUser) => {
  const testUser = user || await createTestUser();
  const token = generateJWT(testUser);
  
  return {
    user: testUser,
    token,
    authHeader: { Authorization: `Bearer ${token}` },
  };
};

// API response helper
export const expectApiError = (response: supertest.Response, statusCode: number, message?: string) => {
  expect(response.status).toBe(statusCode);
  expect(response.body).toHaveProperty('error');
  if (message) {
    expect(response.body.error).toContain(message);
  }
};

export const expectApiSuccess = (response: supertest.Response, statusCode = 200) => {
  expect(response.status).toBe(statusCode);
  expect(response.body).not.toHaveProperty('error');
};

// Database helpers
export const clearDatabase = async () => {
  const collections = await mongoose.connection.db.collections();
  await Promise.all(collections.map(collection => collection.deleteMany({})));
};

// Example test
// src/__tests__/controllers/user.test.ts
describe('User Controller', () => {
  describe('POST /api/users', () => {
    it('should create a new user', async () => {
      const userData = {
        email: 'newuser@example.com',
        password: 'Password123!',
        name: 'New User',
      };

      const response = await request
        .post('/api/users')
        .send(userData)
        .expect(201);

      expect(response.body).toMatchObject({
        id: expect.any(String),
        email: userData.email,
        name: userData.name,
        role: 'user',
      });

      expect(response.body).not.toHaveProperty('password');
    });

    it('should return validation error for invalid email', async () => {
      const userData = {
        email: 'invalid-email',
        password: 'Password123!',
        name: 'Test User',
      };

      const response = await request
        .post('/api/users')
        .send(userData);

      expectApiError(response, 400, 'Invalid email');
    });
  });

  describe('GET /api/users/:id', () => {
    it('should return user details for authenticated user', async () => {
      const { user, authHeader } = await authenticateUser();

      const response = await request
        .get(`/api/users/${user.id}`)
        .set(authHeader)
        .expect(200);

      expect(response.body).toMatchObject({
        id: user.id,
        email: user.email,
        name: user.name,
      });
    });

    it('should return 401 for unauthenticated request', async () => {
      const user = await createTestUser();

      const response = await request
        .get(`/api/users/${user.id}`);

      expectApiError(response, 401, 'Authentication required');
    });
  });
});
```

---

## 🔗 Navigation

← [Scalability Approaches](./scalability-approaches.md) | [Testing Strategies](./testing-strategies.md) →

---

*Development tools analysis: July 2025 | Tools covered: TypeScript, validation, ORMs, logging, testing*