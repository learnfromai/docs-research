# Best Practices for Express.js Applications

## 🎯 Overview

This comprehensive guide consolidates best practices derived from analyzing production-ready Express.js open source projects. These practices ensure security, scalability, maintainability, and performance in real-world applications.

---

## 🏗️ Project Structure & Organization

### 1. Directory Structure

```
src/
├── controllers/          # HTTP request handlers
│   ├── auth/
│   ├── users/
│   └── posts/
├── services/            # Business logic layer
│   ├── auth.service.ts
│   ├── user.service.ts
│   └── email.service.ts
├── repositories/        # Data access layer
│   ├── user.repository.ts
│   └── post.repository.ts
├── models/             # Data models and schemas
│   ├── User.ts
│   └── Post.ts
├── middleware/         # Custom middleware
│   ├── auth.ts
│   ├── validation.ts
│   └── errorHandler.ts
├── routes/             # Route definitions
│   ├── auth.routes.ts
│   ├── user.routes.ts
│   └── index.ts
├── types/              # TypeScript type definitions
│   ├── express.d.ts
│   └── common.ts
├── utils/              # Utility functions
│   ├── validation.ts
│   ├── encryption.ts
│   └── helpers.ts
├── config/             # Configuration files
│   ├── database.ts
│   ├── redis.ts
│   └── logger.ts
├── __tests__/          # Test files
│   ├── controllers/
│   ├── services/
│   └── utils/
├── docs/               # API documentation
└── scripts/            # Build and deployment scripts
```

### 2. File Naming Conventions

```typescript
// Use consistent naming patterns
controllers/
  UserController.ts      // PascalCase for classes
  auth.controller.ts     // kebab-case for modules

services/
  userService.ts         // camelCase for functions
  email.service.ts       // kebab-case for modules

// Interface and type naming
interface IUser {        // Prefix interfaces with 'I'
  id: string;
  email: string;
}

type UserRole = 'user' | 'admin';  // PascalCase for types

// Enum naming
enum UserStatus {        // PascalCase
  ACTIVE = 'active',
  INACTIVE = 'inactive',
}

// Constants
const API_ENDPOINTS = {  // UPPER_SNAKE_CASE
  USERS: '/api/users',
  AUTH: '/api/auth',
};
```

---

## 🔐 Security Best Practices

### 1. Input Validation & Sanitization

```typescript
// Always validate input at API boundaries
import Joi from 'joi';
import DOMPurify from 'isomorphic-dompurify';

const userSchema = Joi.object({
  email: Joi.string().email().required(),
  password: Joi.string().min(8).pattern(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])/),
  name: Joi.string().min(2).max(50).required(),
});

// Sanitize HTML content
const sanitizeHtml = (content: string): string => {
  return DOMPurify.sanitize(content, {
    ALLOWED_TAGS: ['p', 'br', 'strong', 'em'],
    ALLOWED_ATTR: [],
  });
};

// Validate and sanitize middleware
const validateAndSanitize = (schema: Joi.ObjectSchema) => {
  return (req: Request, res: Response, next: NextFunction) => {
    // Validate
    const { error, value } = schema.validate(req.body);
    if (error) {
      return res.status(400).json({ error: 'Validation failed' });
    }

    // Sanitize string fields
    req.body = sanitizeObject(value);
    next();
  };
};
```

### 2. Authentication & Authorization

```typescript
// Use strong JWT configuration
const jwtConfig = {
  accessTokenExpiry: '15m',      // Short-lived access tokens
  refreshTokenExpiry: '7d',      // Longer refresh tokens
  algorithm: 'HS256',            // Use HMAC-SHA256
  issuer: 'your-app',
  audience: 'your-api',
};

// Implement role-based access control
const authorize = (requiredPermissions: string[]) => {
  return async (req: Request, res: Response, next: NextFunction) => {
    const userPermissions = await getUserPermissions(req.user.id);
    
    const hasPermission = requiredPermissions.every(permission =>
      userPermissions.includes(permission)
    );

    if (!hasPermission) {
      return res.status(403).json({ error: 'Insufficient permissions' });
    }

    next();
  };
};

// Use secure session configuration
const sessionConfig = {
  secret: process.env.SESSION_SECRET,
  name: 'sessionId',              // Don't use default name
  resave: false,
  saveUninitialized: false,
  cookie: {
    secure: process.env.NODE_ENV === 'production',  // HTTPS only in production
    httpOnly: true,                                  // Prevent XSS
    maxAge: 24 * 60 * 60 * 1000,                    // 24 hours
    sameSite: 'strict',                              // CSRF protection
  },
};
```

### 3. Rate Limiting & DDoS Protection

```typescript
import rateLimit from 'express-rate-limit';
import slowDown from 'express-slow-down';

// General rate limiting
const generalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,      // 15 minutes
  max: 100,                       // Limit each IP to 100 requests per windowMs
  message: 'Too many requests',
  standardHeaders: true,
  legacyHeaders: false,
});

// Strict rate limiting for authentication endpoints
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 5,                         // 5 attempts per 15 minutes
  message: 'Too many login attempts',
  skipSuccessfulRequests: true,
});

// Slow down repeated requests
const speedLimiter = slowDown({
  windowMs: 15 * 60 * 1000,
  delayAfter: 10,                 // Allow 10 requests per window without delay
  delayMs: 500,                   // Add 500ms delay per request after delayAfter
});

app.use('/api', generalLimiter);
app.use('/api/auth', authLimiter);
app.use(speedLimiter);
```

---

## 🗄️ Database Best Practices

### 1. Connection Management

```typescript
// Use connection pooling
const dbConfig = {
  host: process.env.DB_HOST,
  port: parseInt(process.env.DB_PORT),
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  
  // Pool configuration
  min: 5,                         // Minimum pool size
  max: 20,                        // Maximum pool size
  idleTimeoutMillis: 30000,       // Close idle connections after 30s
  connectionTimeoutMillis: 2000,   // Return error after 2s if no connection
  
  // Performance settings
  query_timeout: 10000,           // 10 second query timeout
  statement_timeout: 10000,       // 10 second statement timeout
};

// Implement graceful connection handling
class DatabaseService {
  private pool: Pool;

  async connect(): Promise<void> {
    this.pool = new Pool(dbConfig);
    
    this.pool.on('error', (err) => {
      console.error('Database pool error:', err);
    });

    // Test connection
    try {
      await this.pool.query('SELECT 1');
      console.log('Database connected successfully');
    } catch (error) {
      console.error('Database connection failed:', error);
      throw error;
    }
  }

  async disconnect(): Promise<void> {
    if (this.pool) {
      await this.pool.end();
    }
  }
}
```

### 2. Query Optimization

```typescript
// Use parameterized queries to prevent SQL injection
const getUserById = async (id: string): Promise<User | null> => {
  const query = 'SELECT * FROM users WHERE id = $1 AND deleted_at IS NULL';
  const result = await db.query(query, [id]);
  return result.rows[0] || null;
};

// Implement pagination for large datasets
const getUsers = async (page = 1, limit = 20): Promise<PaginatedResult<User>> => {
  const offset = (page - 1) * limit;
  
  const countQuery = 'SELECT COUNT(*) FROM users WHERE deleted_at IS NULL';
  const dataQuery = `
    SELECT id, email, name, created_at 
    FROM users 
    WHERE deleted_at IS NULL 
    ORDER BY created_at DESC 
    LIMIT $1 OFFSET $2
  `;

  const [countResult, dataResult] = await Promise.all([
    db.query(countQuery),
    db.query(dataQuery, [limit, offset]),
  ]);

  const total = parseInt(countResult.rows[0].count);
  const totalPages = Math.ceil(total / limit);

  return {
    data: dataResult.rows,
    pagination: {
      page,
      limit,
      total,
      totalPages,
      hasNext: page < totalPages,
      hasPrev: page > 1,
    },
  };
};

// Use database indexes strategically
const createIndexes = async (): Promise<void> => {
  await db.query('CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_users_email ON users(email)');
  await db.query('CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_users_created_at ON users(created_at DESC)');
  await db.query('CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_posts_author_id ON posts(author_id)');
};
```

### 3. Transaction Management

```typescript
// Use transactions for data consistency
const transferFunds = async (fromUserId: string, toUserId: string, amount: number): Promise<void> => {
  const client = await db.connect();
  
  try {
    await client.query('BEGIN');

    // Check sender balance
    const senderResult = await client.query(
      'SELECT balance FROM accounts WHERE user_id = $1 FOR UPDATE',
      [fromUserId]
    );

    if (senderResult.rows[0].balance < amount) {
      throw new Error('Insufficient funds');
    }

    // Update balances
    await client.query(
      'UPDATE accounts SET balance = balance - $1 WHERE user_id = $2',
      [amount, fromUserId]
    );

    await client.query(
      'UPDATE accounts SET balance = balance + $1 WHERE user_id = $2',
      [amount, toUserId]
    );

    // Record transaction
    await client.query(
      'INSERT INTO transactions (from_user_id, to_user_id, amount) VALUES ($1, $2, $3)',
      [fromUserId, toUserId, amount]
    );

    await client.query('COMMIT');
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
};
```

---

## ⚡ Performance Optimization

### 1. Caching Strategies

```typescript
// Implement multi-level caching
class CacheService {
  private l1Cache = new Map();    // In-memory cache
  private l2Cache: Redis;         // Redis cache

  async get<T>(key: string): Promise<T | null> {
    // Try L1 cache first
    if (this.l1Cache.has(key)) {
      return this.l1Cache.get(key);
    }

    // Try L2 cache
    const cached = await this.l2Cache.get(key);
    if (cached) {
      const value = JSON.parse(cached);
      this.l1Cache.set(key, value);  // Populate L1
      return value;
    }

    return null;
  }

  async set<T>(key: string, value: T, ttl = 3600): Promise<void> {
    this.l1Cache.set(key, value);
    await this.l2Cache.setex(key, ttl, JSON.stringify(value));
  }

  // Cache-aside pattern
  async getOrSet<T>(key: string, fetcher: () => Promise<T>, ttl = 3600): Promise<T> {
    const cached = await this.get<T>(key);
    if (cached) return cached;

    const value = await fetcher();
    await this.set(key, value, ttl);
    return value;
  }
}

// Use HTTP caching headers
const setCacheHeaders = (req: Request, res: Response, next: NextFunction): void => {
  // Public static resources
  if (req.url.match(/\.(css|js|png|jpg|gif)$/)) {
    res.set('Cache-Control', 'public, max-age=31536000'); // 1 year
  }
  
  // API responses
  else if (req.url.startsWith('/api/')) {
    res.set('Cache-Control', 'private, max-age=300'); // 5 minutes
  }
  
  next();
};
```

### 2. Compression & Minification

```typescript
import compression from 'compression';

// Configure compression
app.use(compression({
  filter: (req, res) => {
    // Don't compress responses with this request header
    if (req.headers['x-no-compression']) {
      return false;
    }
    
    // Fallback to standard filter function
    return compression.filter(req, res);
  },
  level: 6,                       // Balance between speed and compression ratio
  threshold: 1024,                // Only compress responses > 1KB
}));

// Minify JSON responses
const minifyJson = (req: Request, res: Response, next: NextFunction): void => {
  const originalSend = res.send;
  
  res.send = function(data: any) {
    if (res.getHeader('content-type')?.includes('application/json')) {
      // Remove unnecessary whitespace from JSON
      data = JSON.stringify(JSON.parse(data));
    }
    
    return originalSend.call(this, data);
  };
  
  next();
};
```

### 3. Async Patterns & Error Handling

```typescript
// Use async/await properly
const asyncHandler = (fn: Function) => {
  return (req: Request, res: Response, next: NextFunction) => {
    Promise.resolve(fn(req, res, next)).catch(next);
  };
};

// Implement proper error handling
class AppError extends Error {
  statusCode: number;
  isOperational: boolean;

  constructor(message: string, statusCode = 500) {
    super(message);
    this.statusCode = statusCode;
    this.isOperational = true;

    Error.captureStackTrace(this, this.constructor);
  }
}

const errorHandler = (err: Error, req: Request, res: Response, next: NextFunction): void => {
  if (err instanceof AppError) {
    res.status(err.statusCode).json({
      error: err.message,
      ...(process.env.NODE_ENV === 'development' && { stack: err.stack }),
    });
  } else {
    console.error('Unexpected error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
};

// Use Promise.all for concurrent operations
const getUserWithPosts = async (userId: string): Promise<UserWithPosts> => {
  const [user, posts, followers] = await Promise.all([
    userService.findById(userId),
    postService.findByAuthor(userId),
    userService.getFollowers(userId),
  ]);

  return { user, posts, followers };
};
```

---

## 📝 Logging & Monitoring

### 1. Structured Logging

```typescript
// Create structured log entries
const logger = winston.createLogger({
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  defaultMeta: {
    service: 'api',
    version: process.env.npm_package_version,
  },
});

// Context-aware logging
class Logger {
  static request(req: Request, res: Response, duration: number): void {
    logger.info('HTTP Request', {
      method: req.method,
      url: req.url,
      statusCode: res.statusCode,
      duration,
      userAgent: req.headers['user-agent'],
      ip: req.ip,
      userId: req.user?.id,
      requestId: req.id,
    });
  }

  static security(event: string, context: any): void {
    logger.warn('Security Event', {
      event,
      ...context,
      timestamp: new Date().toISOString(),
    });
  }

  static business(event: string, data: any): void {
    logger.info('Business Event', {
      event,
      data,
      timestamp: new Date().toISOString(),
    });
  }
}

// Log important business events
const createUser = async (userData: CreateUserDto): Promise<User> => {
  const user = await userRepository.create(userData);
  
  Logger.business('user_created', {
    userId: user.id,
    email: user.email,
    registrationMethod: 'email',
  });
  
  return user;
};
```

### 2. Health Checks & Metrics

```typescript
// Comprehensive health check
const healthCheck = async (req: Request, res: Response): Promise<void> => {
  const checks = {
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    version: process.env.npm_package_version,
    environment: process.env.NODE_ENV,
    checks: {
      database: false,
      redis: false,
      memory: false,
    },
  };

  try {
    // Database check
    await db.query('SELECT 1');
    checks.checks.database = true;

    // Redis check
    await redis.ping();
    checks.checks.redis = true;

    // Memory check
    const memUsage = process.memoryUsage();
    checks.checks.memory = memUsage.heapUsed < memUsage.heapTotal * 0.9;

    const allHealthy = Object.values(checks.checks).every(check => check);
    
    res.status(allHealthy ? 200 : 503).json(checks);
  } catch (error) {
    checks.status = 'unhealthy';
    res.status(503).json(checks);
  }
};

// Performance monitoring
const performanceMonitor = (req: Request, res: Response, next: NextFunction): void => {
  const start = process.hrtime.bigint();
  
  res.on('finish', () => {
    const duration = Number(process.hrtime.bigint() - start) / 1000000; // Convert to ms
    
    // Log slow requests
    if (duration > 1000) {
      logger.warn('Slow request detected', {
        method: req.method,
        url: req.url,
        duration,
        statusCode: res.statusCode,
      });
    }
    
    // Emit metrics
    metrics.histogram('http_request_duration', duration, {
      method: req.method,
      route: req.route?.path,
      status_code: res.statusCode.toString(),
    });
  });
  
  next();
};
```

---

## 🧪 Testing Best Practices

### 1. Test Organization

```typescript
// Organize tests by feature/module
describe('UserService', () => {
  describe('createUser', () => {
    it('should create user with valid data', async () => {
      // Test implementation
    });

    it('should throw error for duplicate email', async () => {
      // Test implementation
    });
  });

  describe('updateUser', () => {
    it('should update user profile', async () => {
      // Test implementation
    });
  });
});

// Use descriptive test names
describe('Authentication middleware', () => {
  it('should allow access with valid JWT token', async () => {
    // Test implementation
  });

  it('should return 401 for expired token', async () => {
    // Test implementation
  });

  it('should return 401 for malformed token', async () => {
    // Test implementation
  });
});
```

### 2. Test Utilities & Helpers

```typescript
// Create reusable test utilities
export class TestHelper {
  static async createTestUser(overrides: Partial<User> = {}): Promise<User> {
    const userData = {
      email: 'test@example.com',
      password: 'Test123!@#',
      name: 'Test User',
      ...overrides,
    };

    return userService.create(userData);
  }

  static async authenticateUser(user?: User): Promise<{ user: User; token: string }> {
    const testUser = user || await this.createTestUser();
    const token = authService.generateAccessToken(testUser);
    
    return { user: testUser, token };
  }

  static expectApiError(response: any, statusCode: number, message?: string): void {
    expect(response.status).toBe(statusCode);
    expect(response.body).toHaveProperty('error');
    
    if (message) {
      expect(response.body.error).toContain(message);
    }
  }
}

// Use factories for test data
export class UserFactory {
  static create(overrides: Partial<User> = {}): User {
    return {
      id: faker.string.uuid(),
      email: faker.internet.email(),
      name: faker.person.fullName(),
      role: 'user',
      isActive: true,
      createdAt: new Date(),
      updatedAt: new Date(),
      ...overrides,
    };
  }

  static createMany(count: number, overrides: Partial<User> = {}): User[] {
    return Array.from({ length: count }, () => this.create(overrides));
  }
}
```

### 3. Integration Testing

```typescript
// Test API endpoints end-to-end
describe('POST /api/users', () => {
  it('should create user and return 201', async () => {
    const userData = {
      email: 'newuser@example.com',
      password: 'Password123!',
      name: 'New User',
    };

    const response = await request(app)
      .post('/api/users')
      .send(userData)
      .expect(201);

    expect(response.body).toMatchObject({
      user: {
        email: userData.email,
        name: userData.name,
        role: 'user',
      },
    });

    // Verify in database
    const createdUser = await userService.findByEmail(userData.email);
    expect(createdUser).toBeTruthy();
  });
});

// Test error scenarios
describe('Authentication error handling', () => {
  it('should handle database connection failure gracefully', async () => {
    // Mock database failure
    jest.spyOn(db, 'query').mockRejectedValueOnce(new Error('Connection failed'));

    const response = await request(app)
      .post('/api/auth/login')
      .send({ email: 'test@example.com', password: 'password' })
      .expect(500);

    expect(response.body.error).toBe('Internal server error');
  });
});
```

---

## 🚀 Deployment & DevOps

### 1. Environment Configuration

```typescript
// Use environment-specific configurations
const config = {
  development: {
    database: {
      host: 'localhost',
      port: 5432,
      ssl: false,
    },
    redis: {
      host: 'localhost',
      port: 6379,
    },
    cors: {
      origin: 'http://localhost:3001',
    },
  },
  
  production: {
    database: {
      host: process.env.DB_HOST,
      port: parseInt(process.env.DB_PORT),
      ssl: true,
    },
    redis: {
      host: process.env.REDIS_HOST,
      port: parseInt(process.env.REDIS_PORT),
      password: process.env.REDIS_PASSWORD,
    },
    cors: {
      origin: process.env.CORS_ORIGIN?.split(','),
    },
  },
};

// Validate required environment variables
const requiredEnvVars = [
  'DATABASE_URL',
  'JWT_ACCESS_SECRET',
  'JWT_REFRESH_SECRET',
  'REDIS_HOST',
];

const missingVars = requiredEnvVars.filter(varName => !process.env[varName]);
if (missingVars.length > 0) {
  throw new Error(`Missing required environment variables: ${missingVars.join(', ')}`);
}
```

### 2. Graceful Shutdown

```typescript
// Implement graceful shutdown
class GracefulShutdown {
  private server: any;
  private connections = new Set();

  constructor(server: any) {
    this.server = server;
    
    // Track connections
    server.on('connection', (connection: any) => {
      this.connections.add(connection);
      connection.on('close', () => {
        this.connections.delete(connection);
      });
    });
  }

  async shutdown(signal: string): Promise<void> {
    console.log(`Received ${signal}, shutting down gracefully`);
    
    // Stop accepting new connections
    this.server.close(async () => {
      console.log('HTTP server closed');
      
      // Close database connections
      await DatabaseService.getInstance().disconnect();
      console.log('Database connections closed');
      
      // Close Redis connections
      await RedisService.getInstance().disconnect();
      console.log('Redis connections closed');
      
      process.exit(0);
    });

    // Force close after timeout
    setTimeout(() => {
      console.error('Forcing shutdown');
      process.exit(1);
    }, 10000);

    // Destroy remaining connections
    this.connections.forEach((connection: any) => {
      connection.destroy();
    });
  }
}

const gracefulShutdown = new GracefulShutdown(server);
process.on('SIGTERM', () => gracefulShutdown.shutdown('SIGTERM'));
process.on('SIGINT', () => gracefulShutdown.shutdown('SIGINT'));
```

### 3. Production Optimizations

```typescript
// Production-specific optimizations
if (process.env.NODE_ENV === 'production') {
  // Trust proxy for load balancers
  app.set('trust proxy', 1);
  
  // Disable X-Powered-By header
  app.disable('x-powered-by');
  
  // Enable compression
  app.use(compression());
  
  // Set security headers
  app.use(helmet({
    contentSecurityPolicy: {
      directives: {
        defaultSrc: ["'self'"],
        scriptSrc: ["'self'", "'unsafe-inline'"],
        styleSrc: ["'self'", "'unsafe-inline'"],
      },
    },
  }));
  
  // Production error handler (don't leak stack traces)
  app.use((err: Error, req: Request, res: Response, next: NextFunction) => {
    logger.error('Production error', {
      message: err.message,
      stack: err.stack,
      url: req.url,
      method: req.method,
    });
    
    res.status(500).json({ error: 'Internal server error' });
  });
}
```

---

## 📋 Checklist for Production Readiness

### Security ✅
- [ ] Input validation on all endpoints
- [ ] SQL injection prevention with parameterized queries
- [ ] XSS protection with content sanitization
- [ ] CSRF protection implementation
- [ ] Rate limiting on API endpoints
- [ ] Secure session configuration
- [ ] Strong password requirements
- [ ] JWT token security (short expiry, secure storage)
- [ ] HTTPS enforcement in production
- [ ] Security headers with Helmet.js

### Performance ✅
- [ ] Database connection pooling
- [ ] Query optimization and indexing
- [ ] Caching strategy implementation
- [ ] Response compression
- [ ] Asset minification
- [ ] CDN configuration for static assets
- [ ] Database read replicas for scaling
- [ ] Memory leak monitoring
- [ ] CPU usage optimization

### Monitoring & Logging ✅
- [ ] Structured logging implementation
- [ ] Error tracking and alerting
- [ ] Performance monitoring
- [ ] Health check endpoints
- [ ] Database monitoring
- [ ] Security event logging
- [ ] Business metrics tracking
- [ ] Uptime monitoring

### Testing ✅
- [ ] Unit tests with >80% coverage
- [ ] Integration tests for API endpoints
- [ ] Security testing
- [ ] Performance testing
- [ ] Load testing
- [ ] End-to-end testing
- [ ] Automated test pipeline
- [ ] Test data management

### DevOps ✅
- [ ] Environment configuration management
- [ ] Docker containerization
- [ ] CI/CD pipeline setup
- [ ] Database migration scripts
- [ ] Backup and recovery procedures
- [ ] Graceful shutdown implementation
- [ ] Blue-green deployment strategy
- [ ] Infrastructure as Code

---

## 🔗 Navigation

← [Implementation Guide](./implementation-guide.md) | [Comparison Analysis](./comparison-analysis.md) →

---

*Best practices compilation: July 2025 | Based on analysis of 15+ production Express.js applications*