# Tools & Libraries Analysis

## 🛠️ Overview

Comprehensive analysis of tools, libraries, and dependencies commonly used across production Express.js applications, including their adoption rates, use cases, and best practices.

## 📊 Dependency Ecosystem Analysis

### Core Framework Dependencies

| Library | Adoption Rate | Purpose | Stability | Examples |
|---------|---------------|---------|-----------|----------|
| **express** | 100% | Web framework | Stable | All projects |
| **cors** | 90% | Cross-origin requests | Stable | Most APIs |
| **helmet** | 95% | Security headers | Stable | Security-focused apps |
| **compression** | 85% | Response compression | Stable | Performance-oriented |
| **morgan** | 85% | HTTP logging | Stable | Most production apps |

### Authentication & Security

| Library | Adoption Rate | Use Case | Security Level | Examples |
|---------|---------------|----------|----------------|----------|
| **jsonwebtoken** | 70% | JWT handling | High | API authentication |
| **passport** | 65% | Multi-strategy auth | High | Social login |
| **bcrypt** | 70% | Password hashing | High | User management |
| **express-rate-limit** | 80% | Rate limiting | Medium | DDoS protection |
| **joi** | 40% | Input validation | High | Data validation |
| **zod** | 35% | TypeScript validation | High | Type-safe validation |

### Database & ORM

| Library | Adoption Rate | Database Type | Learning Curve | Examples |
|---------|---------------|---------------|----------------|----------|
| **mongoose** | 45% | MongoDB | Medium | Document-based apps |
| **prisma** | 35% | Multi-database | Low | Modern applications |
| **typeorm** | 30% | Multi-database | High | Enterprise apps |
| **sequelize** | 25% | SQL databases | High | Traditional apps |
| **knex** | 20% | SQL query builder | Medium | Custom queries |

### Testing Frameworks

| Library | Adoption Rate | Testing Type | Performance | Examples |
|---------|---------------|--------------|-------------|----------|
| **jest** | 80% | Unit/Integration | Good | Most modern apps |
| **supertest** | 70% | API testing | Good | HTTP testing |
| **mocha** | 35% | Unit testing | Good | Traditional setup |
| **chai** | 30% | Assertions | Good | BDD style |
| **cypress** | 45% | E2E testing | Medium | Full-stack apps |

## 🔧 Essential Development Tools

### 1. Code Quality & Linting

**ESLint Configuration Patterns**
```javascript
// .eslintrc.js - Comprehensive ESLint setup
module.exports = {
    env: {
        node: true,
        es2021: true,
        jest: true
    },
    extends: [
        'eslint:recommended',
        '@typescript-eslint/recommended',
        'airbnb-base',
        'plugin:security/recommended',
        'plugin:jest/recommended',
        'prettier'
    ],
    parser: '@typescript-eslint/parser',
    parserOptions: {
        ecmaVersion: 2021,
        sourceType: 'module',
        project: './tsconfig.json'
    },
    plugins: [
        '@typescript-eslint',
        'security',
        'jest',
        'import'
    ],
    rules: {
        // Error Prevention
        'no-console': ['warn', { allow: ['warn', 'error'] }],
        'no-debugger': 'error',
        'no-alert': 'error',
        'no-eval': 'error',
        'no-implied-eval': 'error',
        
        // Security Rules
        'security/detect-object-injection': 'error',
        'security/detect-non-literal-regexp': 'error',
        'security/detect-unsafe-regex': 'error',
        'security/detect-buffer-noassert': 'error',
        
        // TypeScript Rules
        '@typescript-eslint/no-unused-vars': 'error',
        '@typescript-eslint/explicit-function-return-type': 'warn',
        '@typescript-eslint/no-explicit-any': 'warn',
        '@typescript-eslint/prefer-const': 'error',
        
        // Import Rules
        'import/order': ['error', {
            groups: [
                'builtin',
                'external',
                'internal',
                'parent',
                'sibling',
                'index'
            ],
            'newlines-between': 'always'
        }],
        'import/no-unresolved': 'error',
        'import/no-duplicates': 'error',
        
        // Jest Rules
        'jest/expect-expect': 'error',
        'jest/no-disabled-tests': 'warn',
        'jest/no-focused-tests': 'error',
        'jest/prefer-to-have-length': 'warn'
    },
    settings: {
        'import/resolver': {
            typescript: {
                alwaysTryTypes: true,
                project: './tsconfig.json'
            }
        }
    },
    overrides: [
        {
            files: ['*.test.js', '*.test.ts', '*.spec.js', '*.spec.ts'],
            rules: {
                'no-console': 'off',
                '@typescript-eslint/no-explicit-any': 'off'
            }
        }
    ]
};

// package.json scripts
{
    "scripts": {
        "lint": "eslint src --ext .js,.ts",
        "lint:fix": "eslint src --ext .js,.ts --fix",
        "lint:staged": "lint-staged",
        "type-check": "tsc --noEmit",
        "format": "prettier --write \"src/**/*.{js,ts,json,md}\"",
        "format:check": "prettier --check \"src/**/*.{js,ts,json,md}\""
    },
    "lint-staged": {
        "*.{js,ts}": [
            "eslint --fix",
            "prettier --write"
        ],
        "*.{json,md}": [
            "prettier --write"
        ]
    }
}
```

**Prettier Configuration**
```javascript
// .prettierrc.js
module.exports = {
    semi: true,
    trailingComma: 'es5',
    singleQuote: true,
    printWidth: 100,
    tabWidth: 2,
    useTabs: false,
    bracketSpacing: true,
    bracketSameLine: false,
    arrowParens: 'avoid',
    endOfLine: 'lf',
    overrides: [
        {
            files: '*.json',
            options: {
                printWidth: 120
            }
        },
        {
            files: '*.md',
            options: {
                printWidth: 80,
                proseWrap: 'always'
            }
        }
    ]
};
```

### 2. TypeScript Configuration

**Production TypeScript Setup**
```json
// tsconfig.json
{
    "compilerOptions": {
        "target": "ES2020",
        "module": "commonjs",
        "lib": ["ES2020"],
        "allowJs": true,
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
            "@utils/*": ["src/utils/*"],
            "@config/*": ["src/config/*"],
            "@middleware/*": ["src/middleware/*"],
            "@types/*": ["src/types/*"]
        },
        "esModuleInterop": true,
        "forceConsistentCasingInFileNames": true,
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
        "noImplicitOverride": true,
        "noPropertyAccessFromIndexSignature": true,
        "noUncheckedIndexedAccess": true,
        "experimentalDecorators": true,
        "emitDecoratorMetadata": true,
        "skipLibCheck": true,
        "resolveJsonModule": true
    },
    "include": [
        "src/**/*",
        "types/**/*"
    ],
    "exclude": [
        "node_modules",
        "dist",
        "**/*.test.ts",
        "**/*.spec.ts"
    ],
    "ts-node": {
        "require": ["tsconfig-paths/register"]
    }
}

// tsconfig.build.json - Production build configuration
{
    "extends": "./tsconfig.json",
    "exclude": [
        "node_modules",
        "**/*.test.ts",
        "**/*.spec.ts",
        "tests"
    ]
}
```

### 3. Build Tools & Bundling

**Modern Build Setup with SWC**
```javascript
// .swcrc - Fast TypeScript/JavaScript compiler
{
    "jsc": {
        "parser": {
            "syntax": "typescript",
            "tsx": false,
            "decorators": true,
            "dynamicImport": true
        },
        "transform": {
            "legacyDecorator": true,
            "decoratorMetadata": true
        },
        "target": "es2020",
        "loose": false,
        "externalHelpers": false,
        "keepClassNames": false
    },
    "module": {
        "type": "commonjs",
        "strict": false,
        "strictMode": true,
        "lazy": false,
        "noInterop": false
    },
    "minify": false,
    "sourceMaps": true
}

// Build scripts
{
    "scripts": {
        "build": "swc src -d dist --copy-files",
        "build:prod": "swc src -d dist --copy-files --minify",
        "build:watch": "swc src -d dist --copy-files --watch",
        "clean": "rimraf dist",
        "prebuild": "npm run clean",
        "prestart:prod": "npm run build:prod"
    }
}
```

## 📚 Library Ecosystem Deep Dive

### 1. Authentication Libraries Comparison

**Passport.js vs JWT Libraries**
```javascript
// Passport.js - Multi-strategy approach
const passport = require('passport');
const LocalStrategy = require('passport-local').Strategy;
const JwtStrategy = require('passport-jwt').Strategy;
const GoogleStrategy = require('passport-google-oauth20').Strategy;

// Local strategy
passport.use(new LocalStrategy({
    usernameField: 'email',
    passwordField: 'password'
}, async (email, password, done) => {
    try {
        const user = await User.findOne({ email });
        if (!user || !await user.validatePassword(password)) {
            return done(null, false, { message: 'Invalid credentials' });
        }
        return done(null, user);
    } catch (error) {
        return done(error);
    }
}));

// JWT strategy
passport.use(new JwtStrategy({
    jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
    secretOrKey: process.env.JWT_SECRET,
    issuer: 'myapp',
    audience: 'myapp-users'
}, async (payload, done) => {
    try {
        const user = await User.findById(payload.sub);
        if (user) {
            return done(null, user);
        }
        return done(null, false);
    } catch (error) {
        return done(error, false);
    }
}));

// Google OAuth strategy
passport.use(new GoogleStrategy({
    clientID: process.env.GOOGLE_CLIENT_ID,
    clientSecret: process.env.GOOGLE_CLIENT_SECRET,
    callbackURL: '/auth/google/callback'
}, async (accessToken, refreshToken, profile, done) => {
    try {
        let user = await User.findOne({ googleId: profile.id });
        
        if (user) {
            return done(null, user);
        }

        user = await User.create({
            googleId: profile.id,
            email: profile.emails[0].value,
            name: profile.displayName,
            avatar: profile.photos[0].value
        });

        return done(null, user);
    } catch (error) {
        return done(error);
    }
}));

// Pros: Multiple strategies, established ecosystem, social login support
// Cons: Heavier, session-based by default, learning curve

// Pure JWT approach
const jwt = require('jsonwebtoken');
const bcrypt = require('bcrypt');

class AuthService {
    static async authenticate(email, password) {
        const user = await User.findOne({ email });
        if (!user || !await bcrypt.compare(password, user.password)) {
            throw new AuthError('Invalid credentials');
        }

        const token = jwt.sign(
            { sub: user.id, role: user.role },
            process.env.JWT_SECRET,
            { 
                expiresIn: '1h',
                issuer: 'myapp',
                audience: 'myapp-users'
            }
        );

        return { user, token };
    }

    static async validateToken(token) {
        try {
            const payload = jwt.verify(token, process.env.JWT_SECRET);
            const user = await User.findById(payload.sub);
            return user;
        } catch (error) {
            throw new AuthError('Invalid token');
        }
    }
}

// Pros: Lightweight, stateless, simple
// Cons: Manual implementation, fewer built-in features
```

### 2. Validation Libraries Comparison

**Joi vs Zod vs express-validator**
```javascript
// Joi - Schema validation
const Joi = require('joi');

const userSchema = Joi.object({
    email: Joi.string().email().required(),
    password: Joi.string().min(8).pattern(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/).required(),
    name: Joi.string().min(2).max(50).required(),
    age: Joi.number().integer().min(18).max(120).optional(),
    role: Joi.string().valid('user', 'admin').default('user')
});

const validateUser = (req, res, next) => {
    const { error, value } = userSchema.validate(req.body);
    if (error) {
        return res.status(400).json({ 
            error: 'Validation failed',
            details: error.details 
        });
    }
    req.validatedBody = value;
    next();
};

// Pros: Mature, extensive features, good documentation
// Cons: Runtime validation only, larger bundle size

// Zod - TypeScript-first validation
import { z } from 'zod';

const userSchema = z.object({
    email: z.string().email(),
    password: z.string().min(8).regex(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/),
    name: z.string().min(2).max(50),
    age: z.number().int().min(18).max(120).optional(),
    role: z.enum(['user', 'admin']).default('user')
});

type User = z.infer<typeof userSchema>;

const validateUser = (req: Request, res: Response, next: NextFunction) => {
    try {
        req.validatedBody = userSchema.parse(req.body);
        next();
    } catch (error) {
        if (error instanceof z.ZodError) {
            return res.status(400).json({
                error: 'Validation failed',
                details: error.errors
            });
        }
        next(error);
    }
};

// Pros: TypeScript integration, type inference, smaller bundle
// Cons: Newer library, fewer advanced features

// express-validator - Express-specific validation
const { body, validationResult } = require('express-validator');

const validateUser = [
    body('email').isEmail().normalizeEmail(),
    body('password').isLength({ min: 8 }).matches(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/),
    body('name').isLength({ min: 2, max: 50 }).trim(),
    body('age').optional().isInt({ min: 18, max: 120 }),
    body('role').optional().isIn(['user', 'admin']),
    
    (req, res, next) => {
        const errors = validationResult(req);
        if (!errors.isEmpty()) {
            return res.status(400).json({
                error: 'Validation failed',
                details: errors.array()
            });
        }
        next();
    }
];

// Pros: Express integration, sanitization, field-level validation
// Cons: Verbose, no type safety, middleware chaining
```

### 3. Database Libraries Comparison

**ORM/ODM Trade-offs Analysis**
```javascript
// Prisma - Modern database toolkit
// schema.prisma
model User {
    id        String   @id @default(cuid())
    email     String   @unique
    name      String
    posts     Post[]
    createdAt DateTime @default(now())
    updatedAt DateTime @updatedAt
}

model Post {
    id        String   @id @default(cuid())
    title     String
    content   String
    published Boolean  @default(false)
    author    User     @relation(fields: [authorId], references: [id])
    authorId  String
    createdAt DateTime @default(now())
    updatedAt DateTime @updatedAt
}

// Generated TypeScript client
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

class UserService {
    async createUser(data: { email: string; name: string }) {
        return prisma.user.create({
            data,
            include: {
                posts: true
            }
        });
    }

    async findUserWithPosts(id: string) {
        return prisma.user.findUnique({
            where: { id },
            include: {
                posts: {
                    where: { published: true },
                    orderBy: { createdAt: 'desc' }
                }
            }
        });
    }
}

// Pros: Type safety, schema-first, migrations, great DX
// Cons: Less flexible queries, opinionated structure

// TypeORM - Decorator-based ORM
import { Entity, PrimaryGeneratedColumn, Column, OneToMany, ManyToOne } from 'typeorm';

@Entity()
export class User {
    @PrimaryGeneratedColumn('uuid')
    id: string;

    @Column({ unique: true })
    email: string;

    @Column()
    name: string;

    @OneToMany(() => Post, post => post.author)
    posts: Post[];

    @Column({ type: 'timestamp', default: () => 'CURRENT_TIMESTAMP' })
    createdAt: Date;
}

@Entity()
export class Post {
    @PrimaryGeneratedColumn('uuid')
    id: string;

    @Column()
    title: string;

    @Column('text')
    content: string;

    @ManyToOne(() => User, user => user.posts)
    author: User;

    @Column({ default: false })
    published: boolean;
}

// Repository pattern
import { Repository } from 'typeorm';

class UserService {
    constructor(private userRepository: Repository<User>) {}

    async createUser(userData: Partial<User>): Promise<User> {
        const user = this.userRepository.create(userData);
        return this.userRepository.save(user);
    }

    async findUserWithPosts(id: string): Promise<User | null> {
        return this.userRepository.findOne({
            where: { id },
            relations: ['posts'],
            order: { posts: { createdAt: 'DESC' } }
        });
    }
}

// Pros: Decorators, Active Record pattern, complex queries
// Cons: Heavy, learning curve, configuration complexity

// Mongoose - MongoDB ODM
import mongoose from 'mongoose';

const userSchema = new mongoose.Schema({
    email: { type: String, required: true, unique: true },
    name: { type: String, required: true },
    posts: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Post' }]
}, { timestamps: true });

const postSchema = new mongoose.Schema({
    title: { type: String, required: true },
    content: { type: String, required: true },
    author: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    published: { type: Boolean, default: false }
}, { timestamps: true });

const User = mongoose.model('User', userSchema);
const Post = mongoose.model('Post', postSchema);

class UserService {
    async createUser(userData: { email: string; name: string }) {
        return User.create(userData);
    }

    async findUserWithPosts(id: string) {
        return User.findById(id).populate({
            path: 'posts',
            match: { published: true },
            options: { sort: { createdAt: -1 } }
        });
    }
}

// Pros: MongoDB native, flexible schemas, middleware
// Cons: NoSQL only, schema validation limitations
```

## 🚀 Performance & Monitoring Tools

### 1. Application Performance Monitoring

**New Relic Integration**
```javascript
// newrelic.js
'use strict';

exports.config = {
    app_name: ['My Express App'],
    license_key: process.env.NEW_RELIC_LICENSE_KEY,
    logging: {
        level: 'info'
    },
    allow_all_headers: true,
    attributes: {
        exclude: [
            'request.headers.cookie',
            'request.headers.authorization',
            'request.headers.proxyAuthorization',
            'request.headers.setCookie*',
            'request.headers.x*',
            'response.headers.cookie',
            'response.headers.authorization',
            'response.headers.proxyAuthorization',
            'response.headers.setCookie*',
            'response.headers.x*'
        ]
    }
};

// Custom middleware for enhanced monitoring
const newrelic = require('newrelic');

const performanceMonitoring = (req, res, next) => {
    // Add custom attributes
    newrelic.addCustomAttribute('userId', req.user?.id);
    newrelic.addCustomAttribute('userRole', req.user?.role);
    newrelic.addCustomAttribute('endpoint', req.route?.path);
    
    // Start custom timing
    const startTime = Date.now();
    
    res.on('finish', () => {
        const duration = Date.now() - startTime;
        newrelic.recordMetric('Custom/ResponseTime', duration);
        
        // Record business metrics
        if (req.route?.path === '/api/posts' && req.method === 'POST') {
            newrelic.incrementMetric('Custom/PostsCreated');
        }
    });
    
    next();
};
```

**Prometheus Metrics**
```javascript
// prometheus-metrics.js
const promClient = require('prom-client');

// Create a Registry
const register = new promClient.Registry();

// Add default metrics
promClient.collectDefaultMetrics({ register });

// Custom metrics
const httpRequestsTotal = new promClient.Counter({
    name: 'http_requests_total',
    help: 'Total number of HTTP requests',
    labelNames: ['method', 'route', 'status_code'],
    registers: [register]
});

const httpRequestDuration = new promClient.Histogram({
    name: 'http_request_duration_seconds',
    help: 'Duration of HTTP requests in seconds',
    labelNames: ['method', 'route'],
    buckets: [0.1, 0.5, 1, 2, 5],
    registers: [register]
});

const activeConnections = new promClient.Gauge({
    name: 'active_connections',
    help: 'Number of active connections',
    registers: [register]
});

const dbConnectionPool = new promClient.Gauge({
    name: 'db_connection_pool_size',
    help: 'Database connection pool size',
    registers: [register]
});

// Middleware
const metricsMiddleware = (req, res, next) => {
    const start = Date.now();
    
    res.on('finish', () => {
        const duration = (Date.now() - start) / 1000;
        const route = req.route?.path || req.path;
        
        httpRequestsTotal.inc({
            method: req.method,
            route,
            status_code: res.statusCode
        });
        
        httpRequestDuration.observe({
            method: req.method,
            route
        }, duration);
    });
    
    next();
};

// Metrics endpoint
app.get('/metrics', (req, res) => {
    res.set('Content-Type', register.contentType);
    res.end(register.metrics());
});

module.exports = {
    register,
    metricsMiddleware,
    httpRequestsTotal,
    httpRequestDuration,
    activeConnections,
    dbConnectionPool
};
```

### 2. Logging Solutions

**Winston Logger Configuration**
```javascript
// logger.js
const winston = require('winston');
const DailyRotateFile = require('winston-daily-rotate-file');

// Custom format
const customFormat = winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json(),
    winston.format.printf(({ level, message, timestamp, stack, ...meta }) => {
        return JSON.stringify({
            timestamp,
            level,
            message,
            ...(stack && { stack }),
            ...meta
        });
    })
);

// Create logger
const logger = winston.createLogger({
    level: process.env.LOG_LEVEL || 'info',
    format: customFormat,
    defaultMeta: { 
        service: 'express-api',
        version: process.env.APP_VERSION || '1.0.0',
        environment: process.env.NODE_ENV || 'development'
    },
    transports: [
        // Console transport
        new winston.transports.Console({
            format: winston.format.combine(
                winston.format.colorize(),
                winston.format.simple()
            )
        }),
        
        // File transports
        new DailyRotateFile({
            filename: 'logs/application-%DATE%.log',
            datePattern: 'YYYY-MM-DD',
            zippedArchive: true,
            maxSize: '20m',
            maxFiles: '14d'
        }),
        
        new DailyRotateFile({
            filename: 'logs/error-%DATE%.log',
            datePattern: 'YYYY-MM-DD',
            level: 'error',
            zippedArchive: true,
            maxSize: '20m',
            maxFiles: '30d'
        })
    ],
    
    // Handle uncaught exceptions
    exceptionHandlers: [
        new winston.transports.File({ filename: 'logs/exceptions.log' })
    ],
    
    // Handle unhandled rejections
    rejectionHandlers: [
        new winston.transports.File({ filename: 'logs/rejections.log' })
    ]
});

// Logging middleware
const requestLogger = (req, res, next) => {
    const start = Date.now();
    
    // Log request
    logger.info('Request started', {
        method: req.method,
        url: req.originalUrl,
        ip: req.ip,
        userAgent: req.get('User-Agent'),
        userId: req.user?.id,
        requestId: req.id
    });
    
    res.on('finish', () => {
        const duration = Date.now() - start;
        
        logger.info('Request completed', {
            method: req.method,
            url: req.originalUrl,
            statusCode: res.statusCode,
            duration,
            requestId: req.id
        });
    });
    
    next();
};

module.exports = { logger, requestLogger };
```

## 🔧 Development Environment Tools

### 1. Docker Development Setup

**Multi-stage Docker Configuration**
```dockerfile
# Dockerfile
# Development stage
FROM node:18-alpine AS development
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=development
COPY . .
EXPOSE 3000
CMD ["npm", "run", "dev"]

# Build stage
FROM node:18-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force
COPY . .
RUN npm run build

# Production stage
FROM node:18-alpine AS production
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force
COPY --from=build /app/dist ./dist
COPY --from=build /app/package.json ./

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nextjs -u 1001

USER nodejs

EXPOSE 3000
CMD ["node", "dist/index.js"]

# docker-compose.yml
version: '3.8'

services:
  app:
    build:
      context: .
      target: development
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
    networks:
      - app-network

  mongo:
    image: mongo:5.0
    ports:
      - "27017:27017"
    volumes:
      - mongo_data:/data/db
    networks:
      - app-network

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    networks:
      - app-network

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
    depends_on:
      - app
    networks:
      - app-network

volumes:
  mongo_data:
  redis_data:

networks:
  app-network:
    driver: bridge
```

### 2. Environment Configuration

**Comprehensive Environment Management**
```javascript
// config/env.js
const Joi = require('joi');

// Environment validation schema
const envSchema = Joi.object({
    NODE_ENV: Joi.string()
        .valid('development', 'production', 'test')
        .default('development'),
    
    PORT: Joi.number().port().default(3000),
    
    // Database
    DATABASE_URL: Joi.string().uri().required(),
    DB_POOL_MIN: Joi.number().min(0).default(2),
    DB_POOL_MAX: Joi.number().min(1).default(10),
    
    // Redis
    REDIS_URL: Joi.string().uri().required(),
    REDIS_KEY_PREFIX: Joi.string().default('myapp:'),
    
    // JWT
    JWT_SECRET: Joi.string().min(32).required(),
    JWT_EXPIRES_IN: Joi.string().default('1h'),
    JWT_REFRESH_SECRET: Joi.string().min(32).required(),
    JWT_REFRESH_EXPIRES_IN: Joi.string().default('7d'),
    
    // Email
    SMTP_HOST: Joi.string().hostname(),
    SMTP_PORT: Joi.number().port(),
    SMTP_USER: Joi.string().email(),
    SMTP_PASS: Joi.string(),
    
    // External APIs
    GOOGLE_CLIENT_ID: Joi.string(),
    GOOGLE_CLIENT_SECRET: Joi.string(),
    STRIPE_SECRET_KEY: Joi.string(),
    STRIPE_WEBHOOK_SECRET: Joi.string(),
    
    // Monitoring
    NEW_RELIC_LICENSE_KEY: Joi.string(),
    SENTRY_DSN: Joi.string().uri(),
    
    // Security
    CORS_ORIGIN: Joi.alternatives().try(
        Joi.string(),
        Joi.array().items(Joi.string())
    ).default('*'),
    RATE_LIMIT_WINDOW_MS: Joi.number().default(900000), // 15 minutes
    RATE_LIMIT_MAX_REQUESTS: Joi.number().default(100),
    
    // File uploads
    MAX_FILE_SIZE: Joi.number().default(10485760), // 10MB
    ALLOWED_FILE_TYPES: Joi.string().default('image/jpeg,image/png,image/gif'),
    
    // Logging
    LOG_LEVEL: Joi.string()
        .valid('error', 'warn', 'info', 'http', 'verbose', 'debug', 'silly')
        .default('info')
}).unknown();

// Validate environment variables
const { error, value: env } = envSchema.validate(process.env);

if (error) {
    throw new Error(`Environment validation error: ${error.message}`);
}

module.exports = {
    env: env.NODE_ENV,
    port: env.PORT,
    
    database: {
        url: env.DATABASE_URL,
        pool: {
            min: env.DB_POOL_MIN,
            max: env.DB_POOL_MAX
        }
    },
    
    redis: {
        url: env.REDIS_URL,
        keyPrefix: env.REDIS_KEY_PREFIX
    },
    
    jwt: {
        secret: env.JWT_SECRET,
        expiresIn: env.JWT_EXPIRES_IN,
        refreshSecret: env.JWT_REFRESH_SECRET,
        refreshExpiresIn: env.JWT_REFRESH_EXPIRES_IN
    },
    
    email: {
        host: env.SMTP_HOST,
        port: env.SMTP_PORT,
        user: env.SMTP_USER,
        pass: env.SMTP_PASS
    },
    
    oauth: {
        google: {
            clientId: env.GOOGLE_CLIENT_ID,
            clientSecret: env.GOOGLE_CLIENT_SECRET
        }
    },
    
    stripe: {
        secretKey: env.STRIPE_SECRET_KEY,
        webhookSecret: env.STRIPE_WEBHOOK_SECRET
    },
    
    monitoring: {
        newRelic: env.NEW_RELIC_LICENSE_KEY,
        sentry: env.SENTRY_DSN
    },
    
    security: {
        corsOrigin: env.CORS_ORIGIN,
        rateLimit: {
            windowMs: env.RATE_LIMIT_WINDOW_MS,
            max: env.RATE_LIMIT_MAX_REQUESTS
        }
    },
    
    upload: {
        maxFileSize: env.MAX_FILE_SIZE,
        allowedTypes: env.ALLOWED_FILE_TYPES.split(',')
    },
    
    logging: {
        level: env.LOG_LEVEL
    }
};
```

## 🔗 Navigation

← [Testing Strategies](./testing-strategies.md) | [Best Practices](./best-practices.md) →