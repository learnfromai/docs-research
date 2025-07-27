# Best Practices: Express.js Development

## 🎯 Overview

This guide compiles the best practices discovered from analyzing production-ready Express.js applications. These practices represent proven patterns that enhance security, performance, maintainability, and scalability.

## 🔒 Security Best Practices

### 1. **Authentication & Authorization**

#### JWT Implementation Best Practices
```javascript
// ✅ Secure JWT configuration
const jwtConfig = {
  secret: process.env.JWT_SECRET, // Strong, random secret
  expiresIn: '15m', // Short-lived access tokens
  audience: 'your-app',
  issuer: 'your-app-name',
  algorithm: 'HS256'
};

// ✅ Refresh token strategy
const refreshTokenConfig = {
  secret: process.env.REFRESH_TOKEN_SECRET, // Different secret
  expiresIn: '7d',
  httpOnly: true, // Prevent XSS
  secure: process.env.NODE_ENV === 'production', // HTTPS only in production
  sameSite: 'strict' // CSRF protection
};
```

#### Password Security
```javascript
// ✅ Strong password hashing
const bcrypt = require('bcryptjs');
const saltRounds = 12; // Minimum 12 rounds

const hashPassword = async (password) => {
  return await bcrypt.hash(password, saltRounds);
};

// ✅ Password validation pattern
const passwordSchema = Joi.string()
  .min(8)
  .pattern(new RegExp('^(?=.*[a-z])(?=.*[A-Z])(?=.*[0-9])(?=.*[!@#\\$%\\^&\\*])'))
  .message('Password must be at least 8 characters with uppercase, lowercase, number, and special character');
```

### 2. **Input Validation & Sanitization**

#### Comprehensive Validation
```javascript
// ✅ Request validation middleware
const validateRequest = (schema) => (req, res, next) => {
  const { error, value } = schema.validate(req.body, {
    abortEarly: false,
    stripUnknown: true,
    allowUnknown: false
  });

  if (error) {
    const errors = error.details.map(detail => ({
      field: detail.path.join('.'),
      message: detail.message
    }));
    
    return res.status(400).json({
      success: false,
      error: 'Validation failed',
      details: errors
    });
  }

  req.body = value;
  next();
};
```

#### Input Sanitization
```javascript
// ✅ Multi-layer sanitization
app.use(express.json({ limit: '10mb' }));
app.use(mongoSanitize()); // Remove NoSQL injection
app.use(xss()); // Clean HTML input
app.use(hpp()); // Prevent HTTP Parameter Pollution

// ✅ Custom sanitization for specific fields
const sanitizeEmail = (email) => validator.normalizeEmail(email);
const sanitizeString = (str) => validator.escape(str.trim());
```

### 3. **Security Headers & CORS**

#### Helmet Configuration
```javascript
// ✅ Comprehensive helmet setup
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'", "https://fonts.googleapis.com"],
      fontSrc: ["'self'", "https://fonts.gstatic.com"],
      scriptSrc: ["'self'"],
      imgSrc: ["'self'", "data:", "https:"],
      connectSrc: ["'self'", "https://api.yourservice.com"],
      frameSrc: ["'none'"],
      objectSrc: ["'none'"],
      baseUri: ["'self'"],
      formAction: ["'self'"],
    },
  },
  crossOriginEmbedderPolicy: true,
  crossOriginOpenerPolicy: true,
  crossOriginResourcePolicy: true,
  dnsPrefetchControl: true,
  frameguard: { action: 'deny' },
  hidePoweredBy: true,
  hsts: {
    maxAge: 31536000,
    includeSubDomains: true,
    preload: true
  },
  ieNoOpen: true,
  noSniff: true,
  originAgentCluster: true,
  permittedCrossDomainPolicies: false,
  referrerPolicy: "no-referrer",
  xssFilter: true,
}));
```

#### CORS Best Practices
```javascript
// ✅ Secure CORS configuration
const corsOptions = {
  origin: function (origin, callback) {
    const allowedOrigins = process.env.ALLOWED_ORIGINS?.split(',') || [];
    
    // Allow requests with no origin (mobile apps, etc.)
    if (!origin) return callback(null, true);
    
    if (allowedOrigins.includes(origin)) {
      callback(null, true);
    } else {
      callback(new Error('Not allowed by CORS'));
    }
  },
  credentials: true,
  optionsSuccessStatus: 200,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH'],
  allowedHeaders: ['Content-Type', 'Authorization'],
  exposedHeaders: ['X-Total-Count'],
  maxAge: 86400 // 24 hours
};

app.use(cors(corsOptions));
```

### 4. **Rate Limiting & DoS Protection**

#### Multi-tier Rate Limiting
```javascript
// ✅ Global rate limiting
const globalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 1000, // requests per window
  message: 'Too many requests from this IP',
  standardHeaders: true,
  legacyHeaders: false,
});

// ✅ Authentication rate limiting
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 5, // 5 attempts per window
  skipSuccessfulRequests: true,
  message: 'Too many authentication attempts',
});

// ✅ API-specific rate limiting
const apiLimiter = rateLimit({
  windowMs: 60 * 1000, // 1 minute
  max: 100, // requests per minute
  keyGenerator: (req) => {
    return req.user?.id || req.ip; // User-based or IP-based
  },
});

app.use('/api/', globalLimiter);
app.use('/api/auth', authLimiter);
app.use('/api/v1', apiLimiter);
```

## 🏗️ Architecture Best Practices

### 1. **Project Structure**

#### Feature-Based Architecture (Recommended for Large Apps)
```
src/
├── shared/                 # Shared utilities and components
│   ├── middleware/
│   ├── utils/
│   ├── types/
│   └── constants/
├── features/               # Feature-based modules
│   ├── auth/
│   │   ├── controllers/
│   │   ├── services/
│   │   ├── models/
│   │   ├── routes/
│   │   ├── validations/
│   │   ├── tests/
│   │   └── index.ts
│   ├── users/
│   └── posts/
├── config/                 # Configuration files
├── database/               # Database-related files
└── app.ts                  # Application setup
```

#### Layered Architecture (Recommended for Medium Apps)
```
src/
├── controllers/            # HTTP request handlers
├── services/               # Business logic
├── repositories/           # Data access layer
├── models/                 # Data models
├── middleware/             # Custom middleware
├── routes/                 # Route definitions
├── utils/                  # Utility functions
├── config/                 # Configuration
├── types/                  # TypeScript types
└── tests/                  # Test files
```

### 2. **Dependency Injection**

#### Service Container Pattern
```typescript
// ✅ Service container for dependency management
interface IUserService {
  createUser(userData: CreateUserDto): Promise<User>;
  getUserById(id: string): Promise<User | null>;
}

interface IEmailService {
  sendEmail(to: string, subject: string, content: string): Promise<void>;
}

class Container {
  private services = new Map();

  register<T>(name: string, service: T): void {
    this.services.set(name, service);
  }

  resolve<T>(name: string): T {
    const service = this.services.get(name);
    if (!service) {
      throw new Error(`Service ${name} not found`);
    }
    return service;
  }
}

// Usage
const container = new Container();
container.register('userService', new UserService());
container.register('emailService', new EmailService());

// In controllers
const userService = container.resolve<IUserService>('userService');
```

### 3. **Error Handling**

#### Centralized Error Handling
```typescript
// ✅ Custom error classes
export class AppError extends Error {
  statusCode: number;
  isOperational: boolean;
  errorCode?: string;

  constructor(message: string, statusCode: number, errorCode?: string) {
    super(message);
    this.statusCode = statusCode;
    this.isOperational = true;
    this.errorCode = errorCode;

    Error.captureStackTrace(this, this.constructor);
  }
}

// ✅ Async error wrapper
export const asyncHandler = (fn: Function) => {
  return (req: Request, res: Response, next: NextFunction) => {
    Promise.resolve(fn(req, res, next)).catch(next);
  };
};

// ✅ Global error handler
export const globalErrorHandler = (
  err: any,
  req: Request,
  res: Response,
  next: NextFunction
) => {
  err.statusCode = err.statusCode || 500;
  err.status = err.status || 'error';

  // Log error
  logger.error({
    error: err.message,
    stack: err.stack,
    url: req.url,
    method: req.method,
    ip: req.ip,
    userAgent: req.get('User-Agent'),
  });

  // Send error response
  if (process.env.NODE_ENV === 'development') {
    sendErrorDev(err, res);
  } else {
    sendErrorProd(err, res);
  }
};
```

## ⚡ Performance Best Practices

### 1. **Caching Strategies**

#### Multi-level Caching
```javascript
// ✅ Redis caching
const redis = require('redis');
const client = redis.createClient(process.env.REDIS_URL);

const cache = {
  async get(key) {
    try {
      const value = await client.get(key);
      return value ? JSON.parse(value) : null;
    } catch (error) {
      logger.error('Cache get error:', error);
      return null;
    }
  },

  async set(key, value, ttl = 3600) {
    try {
      await client.setex(key, ttl, JSON.stringify(value));
    } catch (error) {
      logger.error('Cache set error:', error);
    }
  },

  async del(key) {
    try {
      await client.del(key);
    } catch (error) {
      logger.error('Cache delete error:', error);
    }
  }
};

// ✅ Cache middleware
const cacheMiddleware = (ttl = 300) => {
  return async (req, res, next) => {
    const key = `cache:${req.method}:${req.originalUrl}:${req.user?.id || 'anonymous'}`;
    
    try {
      const cached = await cache.get(key);
      if (cached) {
        return res.json(cached);
      }

      // Store original json method
      const originalJson = res.json;
      res.json = function(data) {
        // Cache successful responses
        if (res.statusCode >= 200 && res.statusCode < 300) {
          cache.set(key, data, ttl);
        }
        return originalJson.call(this, data);
      };

      next();
    } catch (error) {
      logger.error('Cache middleware error:', error);
      next();
    }
  };
};
```

### 2. **Database Optimization**

#### Connection Pooling
```javascript
// ✅ MongoDB connection with pooling
const mongoose = require('mongoose');

const connectDB = async () => {
  try {
    const conn = await mongoose.connect(process.env.MONGODB_URI, {
      maxPoolSize: 10, // Maintain up to 10 socket connections
      serverSelectionTimeoutMS: 5000, // Keep trying to send operations for 5 seconds
      socketTimeoutMS: 45000, // Close sockets after 45 seconds of inactivity
      bufferCommands: false, // Disable mongoose buffering
      bufferMaxEntries: 0, // Disable mongoose buffering
    });

    logger.info(`MongoDB Connected: ${conn.connection.host}`);
  } catch (error) {
    logger.error('Database connection error:', error);
    process.exit(1);
  }
};
```

#### Query Optimization
```javascript
// ✅ Efficient querying patterns
class UserRepository {
  async findUserWithPosts(userId) {
    return User.findById(userId)
      .populate({
        path: 'posts',
        select: 'title createdAt',
        options: { sort: { createdAt: -1 }, limit: 10 }
      })
      .select('-password -__v')
      .lean(); // Returns plain objects for read-only operations
  }

  async findUsersWithPagination(page = 1, limit = 10) {
    const skip = (page - 1) * limit;
    
    const [users, total] = await Promise.all([
      User.find({ active: true })
        .select('-password')
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limit)
        .lean(),
      User.countDocuments({ active: true })
    ]);

    return {
      users,
      pagination: {
        page,
        limit,
        total,
        pages: Math.ceil(total / limit)
      }
    };
  }
}
```

### 3. **Response Optimization**

#### Compression & Response Headers
```javascript
// ✅ Response optimization
const compression = require('compression');

app.use(compression({
  level: 6, // Compression level (1-9)
  threshold: 1024, // Only compress responses > 1KB
  filter: (req, res) => {
    if (req.headers['x-no-compression']) {
      return false;
    }
    return compression.filter(req, res);
  }
}));

// ✅ ETags for caching
app.use((req, res, next) => {
  if (req.method === 'GET') {
    res.set('Cache-Control', 'public, max-age=300'); // 5 minutes
  }
  next();
});
```

## 🧪 Testing Best Practices

### 1. **Test Structure**

#### Testing Pyramid
```javascript
// ✅ Unit tests (70% of tests)
describe('UserService', () => {
  describe('createUser', () => {
    it('should create user with valid data', async () => {
      const userData = { name: 'John', email: 'john@example.com' };
      const mockUser = { id: '1', ...userData };
      
      jest.spyOn(userRepository, 'create').mockResolvedValue(mockUser);
      
      const result = await userService.createUser(userData);
      
      expect(result).toEqual(mockUser);
      expect(userRepository.create).toHaveBeenCalledWith(userData);
    });
  });
});

// ✅ Integration tests (20% of tests)
describe('Auth API', () => {
  describe('POST /api/auth/login', () => {
    it('should login with valid credentials', async () => {
      const user = await createTestUser();
      
      const response = await request(app)
        .post('/api/auth/login')
        .send({ email: user.email, password: 'password123' })
        .expect(200);
      
      expect(response.body.token).toBeDefined();
      expect(response.body.user.email).toBe(user.email);
    });
  });
});

// ✅ E2E tests (10% of tests)
describe('User Registration Flow', () => {
  it('should complete full registration process', async () => {
    // Test complete user journey
  });
});
```

### 2. **Test Utilities**

#### Test Helpers
```javascript
// ✅ Test database setup
const { MongoMemoryServer } = require('mongodb-memory-server');

let mongoServer;

beforeAll(async () => {
  mongoServer = await MongoMemoryServer.create();
  const mongoUri = mongoServer.getUri();
  await mongoose.connect(mongoUri);
});

afterAll(async () => {
  await mongoose.disconnect();
  await mongoServer.stop();
});

// ✅ Test data factories
const userFactory = {
  create: (overrides = {}) => ({
    name: 'Test User',
    email: 'test@example.com',
    password: 'Password123!',
    role: 'user',
    ...overrides
  }),

  createInDb: async (overrides = {}) => {
    const userData = userFactory.create(overrides);
    return await User.create(userData);
  }
};
```

## 📊 Monitoring & Observability

### 1. **Logging Best Practices**

#### Structured Logging
```javascript
// ✅ Winston configuration
const winston = require('winston');

const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  defaultMeta: {
    service: 'express-app',
    environment: process.env.NODE_ENV,
    version: process.env.APP_VERSION
  },
  transports: [
    new winston.transports.File({ 
      filename: 'logs/error.log', 
      level: 'error',
      maxsize: 10485760, // 10MB
      maxFiles: 5
    }),
    new winston.transports.File({ 
      filename: 'logs/combined.log',
      maxsize: 10485760,
      maxFiles: 5
    })
  ],
});

// ✅ Request logging middleware
const requestLogger = (req, res, next) => {
  const start = Date.now();
  
  res.on('finish', () => {
    const duration = Date.now() - start;
    
    logger.info({
      type: 'request',
      method: req.method,
      url: req.url,
      statusCode: res.statusCode,
      duration,
      userAgent: req.get('User-Agent'),
      ip: req.ip,
      userId: req.user?.id
    });
  });
  
  next();
};
```

### 2. **Health Checks**

#### Comprehensive Health Monitoring
```javascript
// ✅ Health check endpoint
app.get('/health', async (req, res) => {
  const health = {
    status: 'OK',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    checks: {}
  };

  try {
    // Database health
    await mongoose.connection.db.admin().ping();
    health.checks.database = 'OK';
  } catch (error) {
    health.checks.database = 'FAIL';
    health.status = 'FAIL';
  }

  try {
    // Redis health
    await redis.ping();
    health.checks.redis = 'OK';
  } catch (error) {
    health.checks.redis = 'FAIL';
    health.status = 'FAIL';
  }

  const statusCode = health.status === 'OK' ? 200 : 503;
  res.status(statusCode).json(health);
});

// ✅ Graceful shutdown
const gracefulShutdown = (server) => {
  const shutdown = (signal) => {
    logger.info(`Received ${signal}, shutting down gracefully`);
    
    server.close(() => {
      logger.info('HTTP server closed');
      
      mongoose.connection.close(false, () => {
        logger.info('MongoDB connection closed');
        process.exit(0);
      });
    });
  };

  process.on('SIGTERM', shutdown);
  process.on('SIGINT', shutdown);
};
```

## 🚀 Deployment Best Practices

### 1. **Environment Configuration**

#### Environment Variables Management
```javascript
// ✅ Environment validation
const Joi = require('joi');

const envSchema = Joi.object({
  NODE_ENV: Joi.string().valid('development', 'staging', 'production').required(),
  PORT: Joi.number().port().default(3000),
  MONGODB_URI: Joi.string().uri().required(),
  JWT_SECRET: Joi.string().min(32).required(),
  REDIS_URL: Joi.string().uri().required(),
  ALLOWED_ORIGINS: Joi.string().required()
}).unknown();

const { error, value: envVars } = envSchema.validate(process.env);

if (error) {
  throw new Error(`Config validation error: ${error.message}`);
}

module.exports = envVars;
```

### 2. **Docker Best Practices**

#### Production Dockerfile
```dockerfile
# ✅ Multi-stage build
FROM node:18-alpine AS builder

WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force

FROM node:18-alpine AS runtime

# Security: Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

WORKDIR /app

# Copy dependencies
COPY --from=builder /app/node_modules ./node_modules
COPY --chown=nodejs:nodejs . .

# Security: Run as non-root
USER nodejs

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node healthcheck.js

EXPOSE 3000

CMD ["node", "index.js"]
```

## 📋 Quality Assurance Checklist

### ✅ Security Checklist
- [ ] All inputs validated and sanitized
- [ ] Authentication implemented with JWT best practices
- [ ] Authorization checks on all protected routes
- [ ] Rate limiting implemented
- [ ] Security headers configured with Helmet
- [ ] CORS properly configured
- [ ] Secrets stored in environment variables
- [ ] HTTPS enforced in production
- [ ] SQL/NoSQL injection protection implemented
- [ ] XSS protection implemented

### ✅ Performance Checklist
- [ ] Response compression enabled
- [ ] Caching strategy implemented
- [ ] Database queries optimized
- [ ] Connection pooling configured
- [ ] Static assets served efficiently
- [ ] Image optimization implemented
- [ ] CDN configured for static assets

### ✅ Reliability Checklist
- [ ] Comprehensive error handling
- [ ] Graceful shutdown implemented
- [ ] Health check endpoints available
- [ ] Logging properly configured
- [ ] Monitoring and alerting set up
- [ ] Database backups configured
- [ ] Circuit breaker pattern for external services

### ✅ Maintainability Checklist
- [ ] Code properly organized and modular
- [ ] TypeScript implemented for type safety
- [ ] Comprehensive test coverage (>80%)
- [ ] API documentation available
- [ ] Code formatting and linting configured
- [ ] Git hooks for quality checks
- [ ] Clear naming conventions followed

---

## 🧭 Navigation

### ⬅️ Previous: [Implementation Guide](./implementation-guide.md)
### ➡️ Next: [Security Considerations](./security-considerations.md)

---

*Best practices compiled from analysis of 15+ production Express.js applications with proven track records.*