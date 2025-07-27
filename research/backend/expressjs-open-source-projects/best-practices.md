# Best Practices: Production-Ready Express.js Development

## 🎯 Overview

This document consolidates the best practices extracted from successful production Express.js projects, providing actionable guidelines for building secure, scalable, and maintainable applications.

## 🏗️ Architecture & Code Organization

### 1. Project Structure Best Practices

**Follow the Modular MVC Pattern**
```
src/
├── controllers/         # Request handlers only
├── services/           # Business logic (testable)
├── models/             # Data models and validation
├── middleware/         # Reusable middleware
├── routes/             # Route definitions
├── config/             # Configuration management
├── utils/              # Pure utility functions
├── types/              # TypeScript definitions
└── tests/              # Test files alongside code
```

**Benefits:**
- Clear separation of concerns
- Easy to test individual layers
- Team can work on different parts simultaneously
- Code is easy to locate and maintain

**Implementation Guidelines:**
```typescript
// ❌ Don't put business logic in controllers
export class UserController {
  async createUser(req: Request, res: Response) {
    // DON'T: Business logic in controller
    const hashedPassword = await bcrypt.hash(req.body.password, 12);
    const user = await User.create({ ...req.body, password: hashedPassword });
    await emailService.sendWelcomeEmail(user.email);
    res.json({ user });
  }
}

// ✅ Do: Keep controllers thin, delegate to services
export class UserController {
  constructor(private userService: UserService) {}
  
  async createUser(req: Request, res: Response) {
    try {
      const user = await this.userService.createUser(req.body);
      res.status(201).json({ user });
    } catch (error) {
      this.handleError(error, res);
    }
  }
}
```

### 2. Dependency Injection Pattern

**Use Constructor Injection for Testability**
```typescript
// ✅ Good: Dependencies injected through constructor
export class UserService {
  constructor(
    private userRepository: UserRepository,
    private emailService: EmailService,
    private logger: Logger
  ) {}
  
  async createUser(userData: CreateUserData): Promise<User> {
    const user = await this.userRepository.create(userData);
    await this.emailService.sendWelcomeEmail(user);
    this.logger.info('User created', { userId: user.id });
    return user;
  }
}

// ✅ Easy to test with mocks
describe('UserService', () => {
  let userService: UserService;
  let mockUserRepository: jest.Mocked<UserRepository>;
  let mockEmailService: jest.Mocked<EmailService>;
  
  beforeEach(() => {
    mockUserRepository = createMockUserRepository();
    mockEmailService = createMockEmailService();
    
    userService = new UserService(
      mockUserRepository,
      mockEmailService,
      mockLogger
    );
  });
});
```

### 3. Configuration Management

**Environment-Based Configuration with Validation**
```typescript
// ✅ Validate configuration at startup
import Joi from 'joi';

const configSchema = Joi.object({
  NODE_ENV: Joi.string().valid('development', 'production', 'test').required(),
  PORT: Joi.number().default(3000),
  DATABASE_URL: Joi.string().uri().required(),
  JWT_SECRET: Joi.string().min(32).required(),
  REDIS_URL: Joi.string().uri().required()
}).unknown();

const { error, value } = configSchema.validate(process.env);
if (error) {
  throw new Error(`Configuration validation failed: ${error.message}`);
}

export const config = value;
```

---

## 🔐 Security Best Practices

### 1. Input Validation & Sanitization

**Always Validate Input at the Boundary**
```typescript
// ✅ Use schema validation middleware
const userValidationSchemas = {
  create: Joi.object({
    email: Joi.string().email().lowercase().trim().required(),
    password: Joi.string().min(8).pattern(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/)
      .message('Password must contain uppercase, lowercase, and number'),
    name: Joi.string().min(2).max(50).trim().required()
  }),
  
  update: Joi.object({
    name: Joi.string().min(2).max(50).trim(),
    email: Joi.string().email().lowercase().trim()
  }).min(1)
};

// Apply validation at route level
app.post('/users', 
  validate(userValidationSchemas.create),
  userController.create
);
```

**Sanitize User Input**
```typescript
// ✅ Sanitize HTML content
import DOMPurify from 'isomorphic-dompurify';

export const sanitizeHtml = (html: string): string => {
  return DOMPurify.sanitize(html, {
    ALLOWED_TAGS: ['p', 'br', 'strong', 'em', 'ul', 'ol', 'li'],
    ALLOWED_ATTR: []
  });
};

// ✅ Escape user input for database queries
import validator from 'validator';

const safeTitle = validator.escape(userInput.title);
```

### 2. Authentication Implementation

**JWT Best Practices**
```typescript
// ✅ Use short-lived access tokens with refresh tokens
export class TokenService {
  generateTokenPair(user: User): TokenPair {
    const accessToken = jwt.sign(
      { userId: user.id, role: user.role },
      config.jwt.secret,
      { 
        expiresIn: '15m',           // Short-lived
        issuer: 'your-app',
        audience: 'your-app-users'
      }
    );
    
    const refreshToken = jwt.sign(
      { userId: user.id, tokenVersion: user.tokenVersion },
      config.jwt.refreshSecret,
      { expiresIn: '7d' }         // Longer-lived
    );
    
    return { accessToken, refreshToken };
  }
}

// ✅ Store tokens securely
const cookieOptions = {
  httpOnly: true,                 // Prevent XSS
  secure: process.env.NODE_ENV === 'production', // HTTPS only
  sameSite: 'strict' as const,    // CSRF protection
  path: '/'
};

res.cookie('accessToken', accessToken, {
  ...cookieOptions,
  maxAge: 15 * 60 * 1000         // 15 minutes
});
```

**Password Security**
```typescript
// ✅ Use proper password hashing
import bcrypt from 'bcryptjs';

// Use appropriate salt rounds (12+ for production)
const SALT_ROUNDS = 12;

export const hashPassword = async (password: string): Promise<string> => {
  return bcrypt.hash(password, SALT_ROUNDS);
};

// ✅ Implement password strength requirements
const passwordSchema = Joi.string()
  .min(8)
  .max(128)
  .pattern(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]/)
  .message('Password must contain uppercase, lowercase, number, and special character');
```

### 3. Security Headers & Middleware

**Comprehensive Security Headers**
```typescript
// ✅ Use Helmet.js with proper configuration
import helmet from 'helmet';

app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'", "https://trusted-cdn.com"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      imgSrc: ["'self'", "data:", "https:"],
      connectSrc: ["'self'", "https://api.yourapp.com"],
      frameSrc: ["'none'"],
      objectSrc: ["'none'"]
    }
  },
  hsts: {
    maxAge: 31536000,
    includeSubDomains: true,
    preload: true
  }
}));
```

**Rate Limiting**
```typescript
// ✅ Implement different rate limits for different endpoints
const createRateLimit = (options: RateLimitOptions) => 
  rateLimit({
    windowMs: options.windowMs,
    max: options.max,
    keyGenerator: options.keyGenerator || ((req) => req.ip),
    standardHeaders: true,
    legacyHeaders: false
  });

// Strict limits for auth endpoints
app.use('/api/auth/login', 
  createRateLimit({ max: 5, windowMs: 15 * 60 * 1000 })
);

// General API limits
app.use('/api/', 
  createRateLimit({ max: 100, windowMs: 60 * 1000 })
);
```

---

## 🗄️ Database Best Practices

### 1. Query Optimization

**Use Proper Indexing**
```typescript
// ✅ Create indexes for frequently queried fields
const userSchema = new Schema({
  email: { 
    type: String, 
    unique: true, 
    index: true        // Single field index
  },
  name: { type: String },
  role: { type: String },
  createdAt: { type: Date, default: Date.now }
});

// Compound indexes for complex queries
userSchema.index({ role: 1, createdAt: -1 });  // For role + date queries
userSchema.index({ email: 1, isActive: 1 });   // For active user lookups
```

**Query Optimization Patterns**
```typescript
// ✅ Use lean() for read-only operations
const users = await User.find({ role: 'user' })
  .lean()              // Return plain objects, not Mongoose documents
  .select('name email role')  // Select only needed fields
  .limit(100);

// ✅ Use aggregation for complex queries
const userStats = await User.aggregate([
  { $match: { createdAt: { $gte: startDate } } },
  { $group: { 
    _id: '$role', 
    count: { $sum: 1 },
    avgAge: { $avg: '$age' }
  }}
]);

// ✅ Use populate selectively
const posts = await Post.find({ published: true })
  .populate('author', 'name email')  // Only populate needed fields
  .limit(10);
```

### 2. Transaction Management

**Use Transactions for Multi-Document Operations**
```typescript
// ✅ Use transactions for data consistency
export class UserService {
  async createUserWithProfile(userData: CreateUserData): Promise<User> {
    const session = await mongoose.startSession();
    
    try {
      const result = await session.withTransaction(async () => {
        // Create user
        const [user] = await User.create([userData], { session });
        
        // Create user profile
        await UserProfile.create([{
          userId: user.id,
          preferences: { theme: 'light' }
        }], { session });
        
        // Send welcome email (outside transaction)
        setImmediate(() => {
          this.emailService.sendWelcomeEmail(user.email);
        });
        
        return user;
      });
      
      return result;
    } finally {
      await session.endSession();
    }
  }
}
```

### 3. Connection Management

**Proper Connection Configuration**
```typescript
// ✅ Configure connection pool properly
await mongoose.connect(config.database.url, {
  maxPoolSize: 10,              // Maximum connections
  serverSelectionTimeoutMS: 5000,  // How long to try selecting a server
  socketTimeoutMS: 45000,       // How long to wait for a response
  bufferCommands: false,        // Don't buffer commands if not connected
  bufferMaxEntries: 0          // Don't buffer any commands
});

// ✅ Handle connection events
mongoose.connection.on('connected', () => {
  logger.info('MongoDB connected');
});

mongoose.connection.on('error', (error) => {
  logger.error('MongoDB connection error:', error);
});

mongoose.connection.on('disconnected', () => {
  logger.warn('MongoDB disconnected');
});
```

---

## 🚀 Performance Best Practices

### 1. Caching Strategies

**Implement Multi-Level Caching**
```typescript
// ✅ Application-level caching
export class CacheService {
  private redis = RedisClient.getInstance();
  private memoryCache = new Map();
  
  async get(key: string): Promise<any> {
    // 1. Check memory cache first (fastest)
    if (this.memoryCache.has(key)) {
      return this.memoryCache.get(key);
    }
    
    // 2. Check Redis cache
    const cached = await this.redis.get(key);
    if (cached) {
      const data = JSON.parse(cached);
      this.memoryCache.set(key, data);  // Store in memory for next time
      return data;
    }
    
    return null;
  }
  
  async set(key: string, data: any, ttl = 3600): Promise<void> {
    // Store in both levels
    this.memoryCache.set(key, data);
    await this.redis.setEx(key, ttl, JSON.stringify(data));
  }
}

// ✅ Cache expensive database queries
export class UserService {
  async getUserById(id: string): Promise<User | null> {
    const cacheKey = `user:${id}`;
    
    // Try cache first
    let user = await this.cacheService.get(cacheKey);
    if (user) return user;
    
    // Query database
    user = await User.findById(id);
    if (user) {
      await this.cacheService.set(cacheKey, user, 1800); // 30 minutes
    }
    
    return user;
  }
}
```

### 2. Response Optimization

**Compression & Response Headers**
```typescript
// ✅ Enable compression
import compression from 'compression';

app.use(compression({
  level: 6,                    // Compression level
  threshold: 1024,             // Only compress responses > 1KB
  filter: (req, res) => {
    // Don't compress images, videos, etc.
    if (req.headers['x-no-compression']) return false;
    return compression.filter(req, res);
  }
}));

// ✅ Set appropriate cache headers
export const setCacheHeaders = (maxAge: number) => {
  return (req: Request, res: Response, next: NextFunction) => {
    res.set({
      'Cache-Control': `public, max-age=${maxAge}`,
      'ETag': `"${Date.now()}"`,
      'Last-Modified': new Date().toUTCString()
    });
    next();
  };
};

// ✅ Use for static data
app.get('/api/categories', 
  setCacheHeaders(3600),      // Cache for 1 hour
  categoriesController.list
);
```

### 3. Async Operations & Background Jobs

**Non-Blocking Operations**
```typescript
// ✅ Use background jobs for heavy operations
import Bull from 'bull';

const emailQueue = new Bull('email processing');

export class UserService {
  async createUser(userData: CreateUserData): Promise<User> {
    const user = await User.create(userData);
    
    // ✅ Queue non-critical operations
    await emailQueue.add('welcome-email', {
      userId: user.id,
      email: user.email
    }, {
      attempts: 3,
      backoff: 'exponential'
    });
    
    // ✅ Return immediately to user
    return user;
  }
}

// ✅ Process jobs in background
emailQueue.process('welcome-email', async (job) => {
  const { userId, email } = job.data;
  await emailService.sendWelcomeEmail(email);
  logger.info('Welcome email sent', { userId });
});
```

---

## 🧪 Testing Best Practices

### 1. Testing Strategy

**Test Pyramid Implementation**
```typescript
// ✅ Unit tests (70% of tests)
describe('UserService', () => {
  let userService: UserService;
  let mockUserRepository: jest.Mocked<UserRepository>;
  
  beforeEach(() => {
    mockUserRepository = {
      create: jest.fn(),
      findById: jest.fn(),
      findByEmail: jest.fn()
    } as any;
    
    userService = new UserService(mockUserRepository);
  });
  
  it('should create user with hashed password', async () => {
    const userData = { email: 'test@example.com', password: 'password123' };
    const expectedUser = { id: '1', email: 'test@example.com' };
    
    mockUserRepository.create.mockResolvedValue(expectedUser);
    
    const result = await userService.createUser(userData);
    
    expect(mockUserRepository.create).toHaveBeenCalledWith({
      ...userData,
      password: expect.not.stringMatching('password123') // Should be hashed
    });
    expect(result).toEqual(expectedUser);
  });
});

// ✅ Integration tests (20% of tests)
describe('Users API', () => {
  beforeEach(async () => {
    await setupTestDatabase();
  });
  
  afterEach(async () => {
    await cleanupTestDatabase();
  });
  
  it('should create user via API', async () => {
    const userData = {
      email: 'test@example.com',
      password: 'Password123!',
      name: 'Test User'
    };
    
    const response = await request(app)
      .post('/api/users')
      .send(userData)
      .expect(201);
    
    expect(response.body.user.email).toBe(userData.email);
    expect(response.body.user.password).toBeUndefined();
  });
});

// ✅ E2E tests (10% of tests)
describe('User Registration Flow', () => {
  it('should register user and send welcome email', async () => {
    // Test complete user flow including email
  });
});
```

### 2. Test Environment Setup

**Isolated Test Environment**
```typescript
// ✅ Test database setup
export const setupTestDatabase = async () => {
  const testDbUrl = `${config.database.url}_test`;
  await mongoose.connect(testDbUrl);
  
  // Clear all collections
  const collections = await mongoose.connection.db.collections();
  await Promise.all(
    collections.map(collection => collection.deleteMany({}))
  );
};

// ✅ Mock external services
jest.mock('@/services/EmailService', () => ({
  EmailService: jest.fn().mockImplementation(() => ({
    sendWelcomeEmail: jest.fn().mockResolvedValue(true),
    sendPasswordReset: jest.fn().mockResolvedValue(true)
  }))
}));
```

---

## 📊 Monitoring & Logging

### 1. Structured Logging

**Use Structured Logging with Context**
```typescript
// ✅ Structured logging with Winston
import winston from 'winston';

export const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  defaultMeta: { 
    service: 'user-service',
    version: process.env.npm_package_version 
  },
  transports: [
    new winston.transports.File({ filename: 'error.log', level: 'error' }),
    new winston.transports.File({ filename: 'combined.log' })
  ]
});

// ✅ Log with context
logger.info('User created', {
  userId: user.id,
  email: user.email,
  requestId: req.id,
  userAgent: req.get('user-agent'),
  ip: req.ip
});

// ✅ Log errors with full context
logger.error('Database connection failed', {
  error: error.message,
  stack: error.stack,
  database: config.database.url.replace(/\/\/.*@/, '//***:***@') // Hide credentials
});
```

### 2. Health Checks & Metrics

**Comprehensive Health Monitoring**
```typescript
// ✅ Health check endpoint
app.get('/health', async (req, res) => {
  const health = {
    status: 'ok',
    timestamp: new Date().toISOString(),
    version: process.env.npm_package_version,
    uptime: process.uptime(),
    checks: {
      database: 'unknown',
      redis: 'unknown',
      memory: 'unknown'
    }
  };
  
  try {
    // Check database
    await mongoose.connection.db.admin().ping();
    health.checks.database = 'ok';
  } catch (error) {
    health.checks.database = 'error';
    health.status = 'error';
  }
  
  try {
    // Check Redis
    await redis.ping();
    health.checks.redis = 'ok';
  } catch (error) {
    health.checks.redis = 'error';
    health.status = 'error';
  }
  
  // Check memory usage
  const memoryUsage = process.memoryUsage();
  if (memoryUsage.heapUsed > 500 * 1024 * 1024) { // 500MB
    health.checks.memory = 'warning';
  } else {
    health.checks.memory = 'ok';
  }
  
  const statusCode = health.status === 'ok' ? 200 : 503;
  res.status(statusCode).json(health);
});
```

---

## 🔒 Error Handling Best Practices

### 1. Centralized Error Handling

**Global Error Handler**
```typescript
// ✅ Custom error classes
export class CustomError extends Error {
  constructor(
    message: string,
    public statusCode: number = 500,
    public code?: string
  ) {
    super(message);
    this.name = this.constructor.name;
  }
}

export class ValidationError extends CustomError {
  constructor(message: string, public details?: any[]) {
    super(message, 400, 'VALIDATION_ERROR');
    this.details = details;
  }
}

// ✅ Global error handler middleware
export const errorHandler = (
  error: Error,
  req: Request,
  res: Response,
  next: NextFunction
) => {
  logger.error('Request error', {
    error: error.message,
    stack: error.stack,
    url: req.url,
    method: req.method,
    ip: req.ip,
    userAgent: req.get('user-agent')
  });
  
  if (error instanceof CustomError) {
    return res.status(error.statusCode).json({
      error: error.message,
      code: error.code,
      ...(error instanceof ValidationError && { details: error.details })
    });
  }
  
  // Don't leak internal errors in production
  const message = process.env.NODE_ENV === 'production' 
    ? 'Internal server error' 
    : error.message;
    
  res.status(500).json({ error: message });
};
```

### 2. Graceful Shutdown

**Handle Shutdown Signals**
```typescript
// ✅ Graceful shutdown handling
export const startServer = async () => {
  const app = await createApp();
  const server = app.listen(config.port);
  
  const shutdown = async (signal: string) => {
    logger.info(`Received ${signal}, shutting down gracefully`);
    
    server.close(async () => {
      logger.info('HTTP server closed');
      
      try {
        await Database.disconnect();
        await RedisClient.disconnect();
        logger.info('Database connections closed');
        process.exit(0);
      } catch (error) {
        logger.error('Error during shutdown:', error);
        process.exit(1);
      }
    });
    
    // Force shutdown after 30 seconds
    setTimeout(() => {
      logger.error('Forced shutdown after timeout');
      process.exit(1);
    }, 30000);
  };
  
  process.on('SIGTERM', () => shutdown('SIGTERM'));
  process.on('SIGINT', () => shutdown('SIGINT'));
  
  return server;
};
```

## 📋 Deployment Checklist

### Production Readiness Checklist

**Security:**
- [ ] Environment variables properly configured
- [ ] Secrets stored securely (not in code)
- [ ] HTTPS enforced in production
- [ ] Security headers configured
- [ ] Rate limiting implemented
- [ ] Input validation on all endpoints
- [ ] SQL injection prevention (ORM usage)
- [ ] XSS protection implemented

**Performance:**
- [ ] Database indexes created
- [ ] Connection pooling configured
- [ ] Caching strategy implemented
- [ ] Response compression enabled
- [ ] Static assets optimized
- [ ] Background jobs for heavy operations

**Monitoring:**
- [ ] Structured logging implemented
- [ ] Health check endpoints available
- [ ] Error tracking configured
- [ ] Performance monitoring set up
- [ ] Alerting rules defined

**Testing:**
- [ ] Unit tests with >80% coverage
- [ ] Integration tests for critical paths
- [ ] E2E tests for user flows
- [ ] Load testing completed
- [ ] Security testing performed

**Operations:**
- [ ] Docker containerization
- [ ] CI/CD pipeline configured
- [ ] Database migration strategy
- [ ] Backup and recovery procedures
- [ ] Rollback strategy defined

## 🔗 References

### Best Practice Resources
- [Express.js Security Best Practices](https://expressjs.com/en/advanced/best-practice-security.html)
- [Node.js Best Practices Repository](https://github.com/goldbergyoni/nodebestpractices)
- [OWASP Node.js Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Nodejs_Security_Cheat_Sheet.html)

### Production Examples
- [Ghost CMS Best Practices](https://github.com/TryGhost/Ghost/wiki/Best-Practices)
- [Strapi Production Guide](https://docs.strapi.io/developer-docs/latest/setup-deployment-guides/deployment.html)

---

*Best practices compiled from successful production Express.js projects and industry standards*

**Navigation**
- ← Back to: [Implementation Guide](./implementation-guide.md)
- ↑ Back to: [Main Research Hub](./README.md)