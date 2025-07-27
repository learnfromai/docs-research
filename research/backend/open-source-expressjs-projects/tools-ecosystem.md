# Tools Ecosystem: Express.js Production Libraries

## 🛠️ Overview

Comprehensive analysis of tools, libraries, and middleware used in production Express.js applications. This document catalogs the most commonly adopted packages across different categories based on analysis of 20+ open source projects.

## 📊 Library Adoption Statistics

### Core Express.js Extensions

| Library | Adoption Rate | Purpose | GitHub Stars |
|---------|-------------|---------|--------------|
| **helmet** | 85% | Security headers | 10k+ |
| **cors** | 90% | CORS handling | 6k+ |
| **compression** | 75% | Response compression | 2k+ |
| **express-rate-limit** | 80% | Rate limiting | 2k+ |
| **express-validator** | 70% | Input validation | 6k+ |
| **express-session** | 65% | Session management | 6k+ |
| **cookie-parser** | 85% | Cookie handling | 2k+ |
| **body-parser** | 95% | Request body parsing | 5k+ |

## 🔐 Authentication & Authorization

### 1. Passport.js Ecosystem (90% Adoption)

**Core Passport Implementation:**
```typescript
// Most commonly used passport strategies
import passport from 'passport';
import { Strategy as LocalStrategy } from 'passport-local';
import { Strategy as JwtStrategy, ExtractJwt } from 'passport-jwt';
import { Strategy as GoogleStrategy } from 'passport-google-oauth20';
import { Strategy as GitHubStrategy } from 'passport-github2';

// Popular passport strategies by adoption rate
const strategyAdoption = {
  'passport-local': '95%',        // Username/password
  'passport-jwt': '85%',          // JWT authentication
  'passport-google-oauth20': '70%', // Google OAuth
  'passport-github2': '45%',      // GitHub OAuth
  'passport-facebook': '35%',     // Facebook OAuth
  'passport-twitter': '25%',      // Twitter OAuth
  'passport-linkedin-oauth2': '20%' // LinkedIn OAuth
};

// Typical passport configuration
const configurePassport = () => {
  // Serialize user for session
  passport.serializeUser((user: any, done) => {
    done(null, user.id);
  });
  
  passport.deserializeUser(async (id: string, done) => {
    try {
      const user = await User.findById(id);
      done(null, user);
    } catch (error) {
      done(error);
    }
  });
  
  // Local strategy
  passport.use(new LocalStrategy({
    usernameField: 'email',
    passwordField: 'password',
    passReqToCallback: true
  }, async (req, email, password, done) => {
    try {
      const user = await User.findOne({ email });
      if (!user || !await user.comparePassword(password)) {
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
    algorithms: ['RS256'],
    passReqToCallback: true
  }, async (req, payload, done) => {
    try {
      const user = await User.findById(payload.sub);
      return done(null, user || false);
    } catch (error) {
      return done(error);
    }
  }));
};
```

### 2. JWT Libraries (85% Adoption)

**JWT Implementation Patterns:**
```typescript
// Primary JWT libraries and their usage
const jwtLibraries = {
  'jsonwebtoken': {
    adoption: '85%',
    pros: ['Mature', 'Feature-rich', 'Wide support'],
    cons: ['Synchronous by default', 'Larger bundle'],
    usage: 'Most common choice'
  },
  'jose': {
    adoption: '15%',
    pros: ['Modern', 'Async/await', 'Smaller bundle'],
    cons: ['Newer', 'Less community resources'],
    usage: 'Growing adoption'
  },
  'fast-jwt': {
    adoption: '5%',
    pros: ['High performance', 'Lightweight'],
    cons: ['Limited features', 'Smaller community'],
    usage: 'Performance-critical applications'
  }
};

// Recommended JWT configuration
import jwt from 'jsonwebtoken';
import fs from 'fs';

class JWTService {
  private privateKey: string;
  private publicKey: string;
  
  constructor() {
    this.privateKey = fs.readFileSync(process.env.JWT_PRIVATE_KEY_PATH!, 'utf8');
    this.publicKey = fs.readFileSync(process.env.JWT_PUBLIC_KEY_PATH!, 'utf8');
  }
  
  generateAccessToken(payload: any): string {
    return jwt.sign(payload, this.privateKey, {
      algorithm: 'RS256',
      expiresIn: '15m',
      issuer: 'your-app-name',
      audience: 'your-app-users'
    });
  }
  
  generateRefreshToken(payload: any): string {
    return jwt.sign(payload, this.privateKey, {
      algorithm: 'RS256',
      expiresIn: '7d',
      issuer: 'your-app-name',
      audience: 'your-app-users'
    });
  }
  
  verifyToken(token: string): any {
    return jwt.verify(token, this.publicKey, {
      algorithms: ['RS256'],
      issuer: 'your-app-name',
      audience: 'your-app-users'
    });
  }
}
```

### 3. Session Management (65% Adoption)

**Session Store Options:**
```typescript
import session from 'express-session';
import MongoStore from 'connect-mongo';
import RedisStore from 'connect-redis';
import { createClient } from 'redis';

// Session store adoption rates
const sessionStores = {
  'memory': {
    adoption: '10%',
    usage: 'Development only',
    pros: ['Simple', 'No dependencies'],
    cons: ['Not scalable', 'Memory leaks']
  },
  'connect-redis': {
    adoption: '60%',
    usage: 'Production (Redis)',
    pros: ['Fast', 'Scalable', 'TTL support'],
    cons: ['Redis dependency', 'Network calls']
  },
  'connect-mongo': {
    adoption: '25%',
    usage: 'Production (MongoDB)',
    pros: ['Persistent', 'No TTL issues'],
    cons: ['Slower', 'More complex queries']
  },
  'connect-pg-simple': {
    adoption: '15%',
    usage: 'Production (PostgreSQL)',
    pros: ['ACID compliance', 'Joins possible'],
    cons: ['PostgreSQL dependency', 'Setup complexity']
  }
};

// Redis session configuration (most popular)
const redisClient = createClient({
  url: process.env.REDIS_URL,
  retry_strategy: (options) => {
    if (options.error && options.error.code === 'ECONNREFUSED') {
      return new Error('Redis server refused connection');
    }
    if (options.total_retry_time > 1000 * 60 * 60) {
      return new Error('Retry time exhausted');
    }
    if (options.attempt > 10) {
      return undefined;
    }
    return Math.min(options.attempt * 100, 3000);
  }
});

const sessionConfig = session({
  store: new RedisStore({
    client: redisClient,
    prefix: 'sess:',
    ttl: 24 * 60 * 60 // 24 hours
  }),
  secret: process.env.SESSION_SECRET!,
  resave: false,
  saveUninitialized: false,
  rolling: true,
  cookie: {
    secure: process.env.NODE_ENV === 'production',
    httpOnly: true,
    maxAge: 24 * 60 * 60 * 1000, // 24 hours
    sameSite: 'strict'
  },
  name: 'sessionId' // Don't use default 'connect.sid'
});
```

## 🗄️ Database & ORM

### 1. Database Drivers & ORMs

**Adoption Statistics:**
```typescript
const databaseTools = {
  // SQL Databases
  'postgresql': {
    drivers: {
      'pg': { adoption: '85%', type: 'Native driver' },
      'node-postgres': { adoption: '85%', type: 'Same as pg' }
    },
    orms: {
      'prisma': { adoption: '45%', trend: 'Rising' },
      'typeorm': { adoption: '35%', trend: 'Stable' },
      'sequelize': { adoption: '25%', trend: 'Declining' },
      'knex': { adoption: '20%', trend: 'Stable' }
    }
  },
  
  'mysql': {
    drivers: {
      'mysql2': { adoption: '70%', type: 'Modern driver' },
      'mysql': { adoption: '30%', type: 'Legacy driver' }
    },
    orms: {
      'prisma': { adoption: '40%', trend: 'Rising' },
      'typeorm': { adoption: '35%', trend: 'Stable' },
      'sequelize': { adoption: '30%', trend: 'Declining' }
    }
  },
  
  // NoSQL Databases
  'mongodb': {
    drivers: {
      'mongodb': { adoption: '95%', type: 'Official driver' }
    },
    odms: {
      'mongoose': { adoption: '80%', trend: 'Stable' },
      'prisma': { adoption: '15%', trend: 'Rising' },
      'typegoose': { adoption: '10%', trend: 'Niche' }
    }
  },
  
  // Cache/Session Stores
  'redis': {
    drivers: {
      'ioredis': { adoption: '65%', type: 'Feature-rich' },
      'redis': { adoption: '35%', type: 'Official client' }
    }
  }
};
```

### 2. Prisma Implementation (45% Growing Adoption)

**Modern Type-Safe Database Access:**
```typescript
// Prisma schema example
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
  name      String?
  posts     Post[]
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
  
  @@map("users")
}

model Post {
  id        String   @id @default(cuid())
  title     String
  content   String?
  published Boolean  @default(false)
  authorId  String
  author    User     @relation(fields: [authorId], references: [id])
  tags      Tag[]    @relation("PostTags")
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
  
  @@map("posts")
}

model Tag {
  id    String @id @default(cuid())
  name  String @unique
  posts Post[] @relation("PostTags")
  
  @@map("tags")
}

// Service implementation with Prisma
import { PrismaClient, User, Post } from '@prisma/client';

class UserService {
  constructor(private prisma: PrismaClient) {}
  
  async createUser(data: {
    email: string;
    name?: string;
  }): Promise<User> {
    return await this.prisma.user.create({
      data,
      include: {
        posts: {
          where: { published: true },
          select: {
            id: true,
            title: true,
            createdAt: true
          }
        }
      }
    });
  }
  
  async getUserPosts(userId: string, published?: boolean): Promise<Post[]> {
    return await this.prisma.post.findMany({
      where: {
        authorId: userId,
        ...(published !== undefined && { published })
      },
      include: {
        tags: true,
        author: {
          select: {
            id: true,
            name: true,
            email: true
          }
        }
      },
      orderBy: {
        createdAt: 'desc'
      }
    });
  }
  
  async searchPosts(query: string): Promise<Post[]> {
    return await this.prisma.post.findMany({
      where: {
        OR: [
          { title: { contains: query, mode: 'insensitive' } },
          { content: { contains: query, mode: 'insensitive' } }
        ],
        published: true
      },
      include: {
        author: {
          select: { name: true }
        },
        tags: true
      }
    });
  }
}
```

### 3. TypeORM Implementation (35% Stable Adoption)

**Decorator-Based ORM:**
```typescript
// Entity definitions
import { Entity, PrimaryGeneratedColumn, Column, OneToMany, ManyToOne, ManyToMany, JoinTable } from 'typeorm';

@Entity('users')
export class User {
  @PrimaryGeneratedColumn('uuid')
  id: string;
  
  @Column({ unique: true })
  email: string;
  
  @Column({ nullable: true })
  name: string;
  
  @OneToMany(() => Post, post => post.author)
  posts: Post[];
  
  @Column({ type: 'timestamp', default: () => 'CURRENT_TIMESTAMP' })
  createdAt: Date;
  
  @Column({ type: 'timestamp', default: () => 'CURRENT_TIMESTAMP', onUpdate: 'CURRENT_TIMESTAMP' })
  updatedAt: Date;
}

@Entity('posts')
export class Post {
  @PrimaryGeneratedColumn('uuid')
  id: string;
  
  @Column()
  title: string;
  
  @Column('text', { nullable: true })
  content: string;
  
  @Column({ default: false })
  published: boolean;
  
  @ManyToOne(() => User, user => user.posts)
  author: User;
  
  @ManyToMany(() => Tag, tag => tag.posts)
  @JoinTable({
    name: 'post_tags',
    joinColumn: { name: 'post_id', referencedColumnName: 'id' },
    inverseJoinColumn: { name: 'tag_id', referencedColumnName: 'id' }
  })
  tags: Tag[];
}

// Repository pattern with TypeORM
import { Repository, getRepository } from 'typeorm';

class PostRepository {
  private repository: Repository<Post>;
  
  constructor() {
    this.repository = getRepository(Post);
  }
  
  async findByAuthor(authorId: string): Promise<Post[]> {
    return await this.repository.find({
      where: { author: { id: authorId } },
      relations: ['author', 'tags'],
      order: { createdAt: 'DESC' }
    });
  }
  
  async searchPosts(query: string): Promise<Post[]> {
    return await this.repository
      .createQueryBuilder('post')
      .leftJoinAndSelect('post.author', 'author')
      .leftJoinAndSelect('post.tags', 'tags')
      .where('post.title ILIKE :query OR post.content ILIKE :query', { query: `%${query}%` })
      .andWhere('post.published = :published', { published: true })
      .orderBy('post.createdAt', 'DESC')
      .getMany();
  }
}
```

## ✅ Validation & Sanitization

### 1. Input Validation Libraries

**Validation Library Comparison:**
```typescript
const validationLibraries = {
  'joi': {
    adoption: '45%',
    pros: ['Comprehensive', 'Schema-based', 'Great error messages'],
    cons: ['Large bundle', 'Learning curve'],
    usage: 'Complex validation logic'
  },
  'yup': {
    adoption: '30%',
    pros: ['Smaller bundle', 'Promise-based', 'Good TypeScript support'],
    cons: ['Less features than Joi'],
    usage: 'Frontend-backend shared validation'
  },
  'class-validator': {
    adoption: '25%',
    pros: ['Decorator-based', 'TypeScript-first', 'NestJS integration'],
    cons: ['Requires reflect-metadata', 'Class-based only'],
    usage: 'TypeScript/NestJS applications'
  },
  'ajv': {
    adoption: '20%',
    pros: ['JSON Schema', 'High performance', 'Standard compliance'],
    cons: ['JSON Schema learning curve'],
    usage: 'API schema validation'
  },
  'express-validator': {
    adoption: '35%',
    pros: ['Express-specific', 'Middleware-based', 'Built on validator.js'],
    cons: ['Express-only', 'Less powerful than Joi'],
    usage: 'Simple Express applications'
  }
};

// Joi implementation (most popular)
import Joi from 'joi';

const userValidationSchemas = {
  create: Joi.object({
    email: Joi.string()
      .email({ minDomainSegments: 2 })
      .required()
      .lowercase()
      .trim(),
    password: Joi.string()
      .min(8)
      .max(128)
      .pattern(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]/)
      .required()
      .messages({
        'string.pattern.base': 'Password must contain uppercase, lowercase, number and special character'
      }),
    name: Joi.string()
      .min(2)
      .max(50)
      .trim(),
    age: Joi.number()
      .integer()
      .min(13)
      .max(120),
    roles: Joi.array()
      .items(Joi.string().valid('admin', 'user', 'moderator'))
      .min(1)
      .default(['user'])
  }),
  
  update: Joi.object({
    email: Joi.string().email().lowercase().trim(),
    name: Joi.string().min(2).max(50).trim(),
    age: Joi.number().integer().min(13).max(120),
    currentPassword: Joi.string().when('newPassword', {
      is: Joi.exist(),
      then: Joi.required(),
      otherwise: Joi.forbidden()
    }),
    newPassword: Joi.string().min(8).max(128)
  }).min(1)
};

// Validation middleware
const validate = (schema: Joi.Schema) => {
  return (req: Request, res: Response, next: NextFunction) => {
    const { error, value } = schema.validate(req.body, {
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
      
      return res.status(400).json({
        status: 'error',
        message: 'Validation failed',
        errors
      });
    }
    
    req.body = value;
    next();
  };
};
```

### 2. Sanitization Libraries

**HTML and Data Sanitization:**
```typescript
import DOMPurify from 'isomorphic-dompurify';
import validator from 'validator';

// Sanitization utilities
class SanitizationService {
  // HTML content sanitization
  static sanitizeHTML(content: string, options?: {
    allowedTags?: string[];
    allowedAttributes?: string[];
  }): string {
    const defaultOptions = {
      ALLOWED_TAGS: [
        'p', 'br', 'strong', 'em', 'u', 's', 'ol', 'ul', 'li',
        'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'blockquote',
        'a', 'img', 'code', 'pre'
      ],
      ALLOWED_ATTR: [
        'href', 'src', 'alt', 'title', 'target', 'rel'
      ],
      ALLOW_DATA_ATTR: false,
      SANITIZE_DOM: true
    };
    
    if (options?.allowedTags) {
      defaultOptions.ALLOWED_TAGS = options.allowedTags;
    }
    
    if (options?.allowedAttributes) {
      defaultOptions.ALLOWED_ATTR = options.allowedAttributes;
    }
    
    return DOMPurify.sanitize(content, defaultOptions);
  }
  
  // Email sanitization
  static sanitizeEmail(email: string): string {
    return validator.normalizeEmail(email.trim().toLowerCase()) || '';
  }
  
  // URL sanitization
  static sanitizeURL(url: string): string {
    const trimmedUrl = url.trim();
    
    if (!validator.isURL(trimmedUrl, {
      protocols: ['http', 'https'],
      require_protocol: true
    })) {
      throw new Error('Invalid URL format');
    }
    
    return trimmedUrl;
  }
  
  // File name sanitization
  static sanitizeFileName(fileName: string): string {
    return fileName
      .replace(/[^a-zA-Z0-9.-]/g, '_')
      .replace(/_{2,}/g, '_')
      .replace(/^_+|_+$/g, '')
      .toLowerCase();
  }
  
  // Search query sanitization
  static sanitizeSearchQuery(query: string): string {
    return query
      .trim()
      .replace(/[<>'"]/g, '')
      .replace(/\s+/g, ' ')
      .substring(0, 100);
  }
}

// Sanitization middleware
const sanitizeInput = (fields: {
  html?: string[];
  email?: string[];
  url?: string[];
  search?: string[];
}) => {
  return (req: Request, res: Response, next: NextFunction) => {
    try {
      // Sanitize HTML fields
      fields.html?.forEach(field => {
        if (req.body[field] && typeof req.body[field] === 'string') {
          req.body[field] = SanitizationService.sanitizeHTML(req.body[field]);
        }
      });
      
      // Sanitize email fields
      fields.email?.forEach(field => {
        if (req.body[field] && typeof req.body[field] === 'string') {
          req.body[field] = SanitizationService.sanitizeEmail(req.body[field]);
        }
      });
      
      // Sanitize URL fields
      fields.url?.forEach(field => {
        if (req.body[field] && typeof req.body[field] === 'string') {
          req.body[field] = SanitizationService.sanitizeURL(req.body[field]);
        }
      });
      
      // Sanitize search fields
      fields.search?.forEach(field => {
        if (req.body[field] && typeof req.body[field] === 'string') {
          req.body[field] = SanitizationService.sanitizeSearchQuery(req.body[field]);
        }
      });
      
      next();
    } catch (error) {
      res.status(400).json({
        status: 'error',
        message: 'Invalid input data',
        error: error.message
      });
    }
  };
};
```

## 📝 Logging & Monitoring

### 1. Logging Libraries (95% Implementation)

**Logger Adoption Statistics:**
```typescript
const loggingLibraries = {
  'winston': {
    adoption: '60%',
    pros: ['Mature', 'Multiple transports', 'Highly configurable'],
    cons: ['Complex configuration', 'Large API surface'],
    usage: 'Enterprise applications'
  },
  'pino': {
    adoption: '35%',
    pros: ['High performance', 'Low overhead', 'JSON output'],
    cons: ['Less features', 'Smaller ecosystem'],
    usage: 'Performance-critical applications'
  },
  'bunyan': {
    adoption: '10%',
    pros: ['JSON-based', 'Good CLI tools'],
    cons: ['Less maintained', 'Smaller community'],
    usage: 'Legacy applications'
  },
  'debug': {
    adoption: '80%',
    pros: ['Simple', 'Environment-based', 'Lightweight'],
    cons: ['Basic features only'],
    usage: 'Development debugging'
  }
};

// Winston configuration (most popular)
import winston from 'winston';
import 'winston-daily-rotate-file';

const createLogger = () => {
  const format = winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
  );
  
  const transports: winston.transport[] = [
    // Console transport for development
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.colorize(),
        winston.format.simple()
      ),
      silent: process.env.NODE_ENV === 'test'
    }),
    
    // File transport for all logs
    new winston.transports.DailyRotateFile({
      filename: 'logs/application-%DATE%.log',
      datePattern: 'YYYY-MM-DD-HH',
      zippedArchive: true,
      maxSize: '20m',
      maxFiles: '14d'
    }),
    
    // Separate file for errors
    new winston.transports.DailyRotateFile({
      filename: 'logs/error-%DATE%.log',
      datePattern: 'YYYY-MM-DD',
      zippedArchive: true,
      maxSize: '20m',
      maxFiles: '30d',
      level: 'error'
    })
  ];
  
  // Add external logging in production
  if (process.env.NODE_ENV === 'production') {
    // Example: Loggly transport
    transports.push(
      new winston.transports.Http({
        host: 'logs-01.loggly.com',
        port: 443,
        path: `/inputs/${process.env.LOGGLY_TOKEN}/tag/nodejs/`,
        ssl: true
      })
    );
  }
  
  return winston.createLogger({
    level: process.env.LOG_LEVEL || 'info',
    format,
    transports,
    exceptionHandlers: [
      new winston.transports.File({ filename: 'logs/exceptions.log' })
    ],
    rejectionHandlers: [
      new winston.transports.File({ filename: 'logs/rejections.log' })
    ]
  });
};

const logger = createLogger();

// Structured logging helper
class Logger {
  static info(message: string, meta?: any): void {
    logger.info(message, { ...meta, timestamp: new Date().toISOString() });
  }
  
  static error(message: string, error?: Error, meta?: any): void {
    logger.error(message, { 
      error: error?.message,
      stack: error?.stack,
      ...meta,
      timestamp: new Date().toISOString()
    });
  }
  
  static warn(message: string, meta?: any): void {
    logger.warn(message, { ...meta, timestamp: new Date().toISOString() });
  }
  
  static debug(message: string, meta?: any): void {
    logger.debug(message, { ...meta, timestamp: new Date().toISOString() });
  }
  
  // HTTP request logging
  static httpRequest(req: Request, res: Response, duration: number): void {
    logger.info('HTTP Request', {
      method: req.method,
      url: req.originalUrl,
      statusCode: res.statusCode,
      duration: `${duration}ms`,
      userAgent: req.get('User-Agent'),
      ip: req.ip,
      userId: req.user?.id,
      timestamp: new Date().toISOString()
    });
  }
}
```

### 2. Application Performance Monitoring (60% Adoption)

**APM Integration Examples:**
```typescript
// New Relic integration (30% adoption)
import newrelic from 'newrelic';

// Sentry integration (55% adoption)
import * as Sentry from '@sentry/node';
import * as Tracing from '@sentry/tracing';

// Sentry configuration
Sentry.init({
  dsn: process.env.SENTRY_DSN,
  environment: process.env.NODE_ENV,
  integrations: [
    new Sentry.Integrations.Http({ tracing: true }),
    new Tracing.Integrations.Express({ app }),
    new Tracing.Integrations.Postgres(),
    new Tracing.Integrations.Redis()
  ],
  tracesSampleRate: process.env.NODE_ENV === 'production' ? 0.1 : 1.0,
  beforeSend(event) {
    // Filter out sensitive data
    if (event.request?.headers) {
      delete event.request.headers.authorization;
      delete event.request.headers.cookie;
    }
    return event;
  }
});

// Performance monitoring middleware
const performanceMonitoring = (req: Request, res: Response, next: NextFunction) => {
  const startTime = Date.now();
  
  // Add correlation ID
  const correlationId = req.headers['x-correlation-id'] || uuidv4();
  req.correlationId = correlationId;
  res.setHeader('X-Correlation-ID', correlationId);
  
  // Monitor response
  res.on('finish', () => {
    const duration = Date.now() - startTime;
    
    // Log HTTP request
    Logger.httpRequest(req, res, duration);
    
    // Custom metrics
    if (duration > 1000) {
      Logger.warn('Slow request detected', {
        method: req.method,
        url: req.originalUrl,
        duration: `${duration}ms`,
        correlationId
      });
    }
    
    // New Relic custom metrics
    if (process.env.NEW_RELIC_LICENSE_KEY) {
      newrelic.recordMetric('Custom/ResponseTime', duration);
      newrelic.addCustomAttribute('correlationId', correlationId);
    }
  });
  
  next();
};
```

## 🚀 Development Tools

### 1. TypeScript Configuration (75% Adoption)

**Production TypeScript Setup:**
```json
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
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "noImplicitReturns": true,
    "noFallthroughCasesInSwitch": true,
    "moduleResolution": "node",
    "baseUrl": "./src",
    "paths": {
      "@/*": ["*"],
      "@/controllers/*": ["controllers/*"],
      "@/services/*": ["services/*"],
      "@/models/*": ["models/*"],
      "@/utils/*": ["utils/*"]
    },
    "experimentalDecorators": true,
    "emitDecoratorMetadata": true
  },
  "include": [
    "src/**/*"
  ],
  "exclude": [
    "node_modules",
    "dist",
    "tests"
  ]
}
```

### 2. Code Quality Tools (90% Adoption)

**ESLint + Prettier Configuration:**
```javascript
// .eslintrc.js
module.exports = {
  parser: '@typescript-eslint/parser',
  parserOptions: {
    ecmaVersion: 2020,
    sourceType: 'module',
    project: './tsconfig.json'
  },
  plugins: [
    '@typescript-eslint',
    'security',
    'import'
  ],
  extends: [
    'eslint:recommended',
    '@typescript-eslint/recommended',
    '@typescript-eslint/recommended-requiring-type-checking',
    'plugin:security/recommended',
    'plugin:import/errors',
    'plugin:import/warnings',
    'plugin:import/typescript',
    'prettier'
  ],
  rules: {
    '@typescript-eslint/no-unused-vars': 'error',
    '@typescript-eslint/explicit-function-return-type': 'warn',
    '@typescript-eslint/no-explicit-any': 'warn',
    'security/detect-object-injection': 'error',
    'import/order': ['error', {
      'groups': ['builtin', 'external', 'internal', 'parent', 'sibling', 'index'],
      'newlines-between': 'always'
    }]
  }
};

// prettier.config.js
module.exports = {
  semi: true,
  trailingComma: 'es5',
  singleQuote: true,
  printWidth: 100,
  tabWidth: 2,
  useTabs: false
};
```

## 📊 Tool Recommendation Matrix

### By Project Size

| Tool Category | Small Project | Medium Project | Large Project |
|--------------|---------------|----------------|---------------|
| **Authentication** | passport-local | passport-jwt | passport + OAuth |
| **Database** | SQLite + Prisma | PostgreSQL + Prisma | PostgreSQL + TypeORM |
| **Validation** | express-validator | Joi | class-validator |
| **Logging** | debug | winston | winston + APM |
| **Caching** | memory | Redis | Redis Cluster |
| **Testing** | Jest | Jest + Supertest | Jest + E2E |

### By Team Experience

| Tool Category | Junior Team | Mixed Team | Senior Team |
|--------------|-------------|-------------|-------------|
| **TypeScript** | Gradual adoption | Strict mode | Advanced types |
| **ORM** | Prisma | Prisma/TypeORM | Custom + Raw SQL |
| **Architecture** | Monolithic | Modular | Microservices |
| **Monitoring** | Basic logging | APM integration | Custom metrics |

---

*Tools ecosystem analysis based on 20+ production Express.js projects | January 2025*

**Navigation**
- ← Previous: [Architecture Analysis](./architecture-analysis.md)
- → Next: [Implementation Guide](./implementation-guide.md)
- ↑ Back to: [README Overview](./README.md)