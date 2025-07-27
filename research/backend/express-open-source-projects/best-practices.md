# Best Practices: Production Express.js Applications

## 🎯 Overview

This guide compiles best practices extracted from analyzing 15+ successful open source Express.js projects. These practices cover security, architecture, performance, testing, and operational excellence for production-ready applications.

## 📋 Table of Contents

1. [Security Best Practices](#1-security-best-practices)
2. [Architecture & Code Organization](#2-architecture--code-organization)
3. [Performance Optimization](#3-performance-optimization)
4. [Error Handling & Logging](#4-error-handling--logging)
5. [Testing & Quality Assurance](#5-testing--quality-assurance)
6. [Database Management](#6-database-management)
7. [API Design & Documentation](#7-api-design--documentation)
8. [Deployment & Operations](#8-deployment--operations)

## 1. Security Best Practices

### 1.1 Authentication & Authorization

**✅ DO:**
```javascript
// Use JWT with short-lived access tokens + refresh tokens
const tokens = {
  accessToken: jwt.sign(payload, secret, { expiresIn: '15m' }),
  refreshToken: jwt.sign(payload, refreshSecret, { expiresIn: '7d' })
};

// Implement proper password policies
const passwordPolicy = {
  minLength: 8,
  requireUppercase: true,
  requireLowercase: true,
  requireNumbers: true,
  requireSpecialChars: true,
  maxAttempts: 5,
  lockoutDuration: 2 * 60 * 60 * 1000 // 2 hours
};

// Use bcrypt with appropriate rounds (12+ for production)
const hashedPassword = await bcrypt.hash(password, 12);
```

**❌ DON'T:**
```javascript
// Don't use long-lived JWT tokens
const token = jwt.sign(payload, secret, { expiresIn: '30d' }); // BAD

// Don't store passwords in plain text
user.password = password; // BAD

// Don't use weak password policies
if (password.length < 6) { /* BAD */ }
```

### 1.2 Input Validation & Sanitization

**✅ DO:**
```javascript
// Validate and sanitize all inputs
const userValidation = [
  body('email')
    .isEmail()
    .normalizeEmail()
    .escape(),
  body('name')
    .trim()
    .isLength({ min: 2, max: 50 })
    .matches(/^[a-zA-Z\s]+$/)
    .escape(),
  body('age')
    .isInt({ min: 1, max: 120 })
    .toInt()
];

// Use parameter validation for routes
app.get('/users/:id', [
  param('id').isMongoId().withMessage('Invalid user ID'),
  handleValidationErrors
], getUserController);
```

**❌ DON'T:**
```javascript
// Don't trust user input
const query = `SELECT * FROM users WHERE id = ${req.params.id}`; // SQL Injection risk

// Don't skip validation
app.post('/users', (req, res) => {
  const user = new User(req.body); // Dangerous without validation
});
```

### 1.3 Security Middleware Configuration

**✅ DO:**
```javascript
// Comprehensive security middleware stack
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'", "fonts.googleapis.com"],
      fontSrc: ["'self'", "fonts.gstatic.com"],
      scriptSrc: ["'self'"],
      imgSrc: ["'self'", "data:", "https:"],
      connectSrc: ["'self'", "api.domain.com"]
    }
  },
  hsts: {
    maxAge: 31536000,
    includeSubDomains: true,
    preload: true
  }
}));

// CORS with strict configuration
app.use(cors({
  origin: function (origin, callback) {
    const allowedOrigins = process.env.ALLOWED_ORIGINS.split(',');
    if (!origin || allowedOrigins.includes(origin)) {
      callback(null, true);
    } else {
      callback(new Error('Not allowed by CORS'));
    }
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));

// Rate limiting with different tiers
const createRateLimit = (windowMs, max, message) => 
  rateLimit({ windowMs, max, message, standardHeaders: true });

app.use('/api/auth', createRateLimit(15 * 60 * 1000, 5, 'Too many auth attempts'));
app.use('/api', createRateLimit(15 * 60 * 1000, 100, 'Too many API requests'));
```

## 2. Architecture & Code Organization

### 2.1 Project Structure

**✅ DO:**
```
src/
├── controllers/           # Route handlers
├── middleware/           # Custom middleware
├── models/              # Data models
├── routes/              # Route definitions
├── services/            # Business logic
├── utils/               # Helper functions
├── config/              # Configuration files
├── validators/          # Input validation schemas
└── types/               # TypeScript types
tests/
├── unit/                # Unit tests
├── integration/         # Integration tests
├── fixtures/            # Test data
└── setup.js             # Test configuration
```

**❌ DON'T:**
```
// Avoid flat structure for large applications
src/
├── app.js               # Everything in one place
├── routes.js
├── models.js
└── utils.js
```

### 2.2 Controller Pattern

**✅ DO:**
```javascript
// Thin controllers, fat services
class UserController {
  static async getUser(req, res, next) {
    try {
      const userId = req.params.id;
      const user = await UserService.getUserById(userId);
      
      res.json({
        success: true,
        data: { user }
      });
    } catch (error) {
      next(error);
    }
  }
  
  static async createUser(req, res, next) {
    try {
      const userData = req.body;
      const user = await UserService.createUser(userData);
      
      res.status(201).json({
        success: true,
        data: { user }
      });
    } catch (error) {
      next(error);
    }
  }
}

// Business logic in services
class UserService {
  static async createUser(userData) {
    // Validate business rules
    await this.validateUserCreation(userData);
    
    // Create user
    const user = await User.create(userData);
    
    // Send welcome email
    await EmailService.sendWelcomeEmail(user.email);
    
    // Log user creation
    logger.info('User created', { userId: user.id });
    
    return user;
  }
}
```

### 2.3 Dependency Injection

**✅ DO:**
```javascript
// Use dependency injection for testability
class UserService {
  constructor(userRepository, emailService, logger) {
    this.userRepository = userRepository;
    this.emailService = emailService;
    this.logger = logger;
  }
  
  async createUser(userData) {
    const user = await this.userRepository.create(userData);
    await this.emailService.sendWelcomeEmail(user.email);
    this.logger.info('User created', { userId: user.id });
    return user;
  }
}

// Container setup
const container = {
  userRepository: new UserRepository(),
  emailService: new EmailService(),
  logger: require('./utils/logger'),
  userService: null
};

container.userService = new UserService(
  container.userRepository,
  container.emailService,
  container.logger
);
```

## 3. Performance Optimization

### 3.1 Caching Strategies

**✅ DO:**
```javascript
// Multi-level caching strategy
class CacheManager {
  constructor() {
    this.memoryCache = new Map();
    this.redisClient = redis.createClient();
  }
  
  async get(key) {
    // L1: Memory cache (fastest)
    if (this.memoryCache.has(key)) {
      return this.memoryCache.get(key);
    }
    
    // L2: Redis cache
    const value = await this.redisClient.get(key);
    if (value) {
      const parsed = JSON.parse(value);
      this.memoryCache.set(key, parsed);
      return parsed;
    }
    
    return null;
  }
  
  async set(key, value, ttl = 300) {
    // Set in both caches
    this.memoryCache.set(key, value);
    await this.redisClient.setex(key, ttl, JSON.stringify(value));
  }
}

// Cache middleware with proper headers
const cacheMiddleware = (duration = 300) => {
  return async (req, res, next) => {
    const key = `cache:${req.method}:${req.originalUrl}`;
    const cached = await cache.get(key);
    
    if (cached) {
      res.set({
        'Cache-Control': `public, max-age=${duration}`,
        'X-Cache': 'HIT',
        'ETag': `"${crypto.createHash('md5').update(JSON.stringify(cached)).digest('hex')}"`
      });
      return res.json(cached);
    }
    
    // Cache the response
    const originalJson = res.json;
    res.json = function(body) {
      if (res.statusCode < 400) {
        cache.set(key, body, duration);
      }
      res.set('X-Cache', 'MISS');
      return originalJson.call(this, body);
    };
    
    next();
  };
};
```

### 3.2 Database Query Optimization

**✅ DO:**
```javascript
// Use proper indexing
const userSchema = new mongoose.Schema({
  email: { type: String, index: true, unique: true },
  username: { type: String, index: true },
  createdAt: { type: Date, default: Date.now, index: true },
  lastActive: { type: Date, index: true }
});

// Compound indexes for complex queries
userSchema.index({ email: 1, isActive: 1 });
userSchema.index({ createdAt: -1, role: 1 });

// Optimized queries with projection
const getUsers = async (page = 1, limit = 10) => {
  return User.find({ isActive: true })
    .select('email username firstName lastName createdAt') // Only needed fields
    .sort({ createdAt: -1 })
    .limit(limit)
    .skip((page - 1) * limit)
    .lean(); // Return plain objects instead of Mongoose documents
};

// Use aggregation for complex operations
const getUserStats = async (userId) => {
  return User.aggregate([
    { $match: { _id: userId } },
    {
      $lookup: {
        from: 'posts',
        localField: '_id',
        foreignField: 'authorId',
        as: 'posts'
      }
    },
    {
      $project: {
        email: 1,
        username: 1,
        postCount: { $size: '$posts' },
        lastPost: { $max: '$posts.createdAt' }
      }
    }
  ]);
};
```

### 3.3 Response Compression & Optimization

**✅ DO:**
```javascript
// Compression with selective filtering
app.use(compression({
  filter: (req, res) => {
    if (req.headers['x-no-compression']) {
      return false;
    }
    return compression.filter(req, res);
  },
  level: 6, // Good compression/speed balance
  threshold: 1024 // Only compress responses > 1KB
}));

// Stream large responses
app.get('/api/export/:format', async (req, res) => {
  const format = req.params.format;
  
  res.writeHead(200, {
    'Content-Type': format === 'csv' ? 'text/csv' : 'application/json',
    'Content-Disposition': `attachment; filename="export.${format}"`,
    'Transfer-Encoding': 'chunked'
  });
  
  const stream = UserService.exportUsersStream(format);
  stream.pipe(res);
});
```

## 4. Error Handling & Logging

### 4.1 Centralized Error Handling

**✅ DO:**
```javascript
// Custom error classes with proper inheritance
class AppError extends Error {
  constructor(message, statusCode, code = null) {
    super(message);
    this.statusCode = statusCode;
    this.status = `${statusCode}`.startsWith('4') ? 'fail' : 'error';
    this.isOperational = true;
    this.code = code;
    
    Error.captureStackTrace(this, this.constructor);
  }
}

class ValidationError extends AppError {
  constructor(message, errors = []) {
    super(message, 400, 'VALIDATION_ERROR');
    this.errors = errors;
  }
}

// Comprehensive error handler
const globalErrorHandler = (err, req, res, next) => {
  err.statusCode = err.statusCode || 500;
  
  // Log error details
  logger.error('Request failed', {
    error: err.message,
    stack: err.stack,
    url: req.url,
    method: req.method,
    ip: req.ip,
    userAgent: req.get('User-Agent'),
    userId: req.user?.id
  });
  
  // Development vs Production responses
  if (process.env.NODE_ENV === 'development') {
    res.status(err.statusCode).json({
      success: false,
      error: {
        message: err.message,
        stack: err.stack,
        ...err
      }
    });
  } else {
    if (err.isOperational) {
      res.status(err.statusCode).json({
        success: false,
        message: err.message,
        code: err.code
      });
    } else {
      res.status(500).json({
        success: false,
        message: 'Something went wrong!',
        code: 'INTERNAL_ERROR'
      });
    }
  }
};
```

### 4.2 Structured Logging

**✅ DO:**
```javascript
// Winston configuration with multiple transports
const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json(),
    winston.format.metadata()
  ),
  defaultMeta: {
    service: 'express-app',
    version: process.env.APP_VERSION,
    environment: process.env.NODE_ENV
  },
  transports: [
    new winston.transports.File({
      filename: 'logs/error.log',
      level: 'error',
      maxsize: 5242880,
      maxFiles: 5
    }),
    new winston.transports.File({
      filename: 'logs/combined.log',
      maxsize: 5242880,
      maxFiles: 5
    })
  ]
});

// Request logging middleware
const requestLogger = (req, res, next) => {
  const start = Date.now();
  
  res.on('finish', () => {
    const duration = Date.now() - start;
    
    logger.info('HTTP Request', {
      method: req.method,
      url: req.url,
      statusCode: res.statusCode,
      duration,
      ip: req.ip,
      userAgent: req.get('User-Agent'),
      userId: req.user?.id,
      contentLength: res.get('Content-Length')
    });
  });
  
  next();
};
```

## 5. Testing & Quality Assurance

### 5.1 Testing Strategy

**✅ DO:**
```javascript
// Comprehensive test structure
describe('UserService', () => {
  let userService;
  let mockUserRepository;
  let mockEmailService;
  
  beforeEach(() => {
    mockUserRepository = {
      create: jest.fn(),
      findById: jest.fn(),
      findByEmail: jest.fn()
    };
    
    mockEmailService = {
      sendWelcomeEmail: jest.fn()
    };
    
    userService = new UserService(mockUserRepository, mockEmailService);
  });
  
  describe('createUser', () => {
    it('should create user and send welcome email', async () => {
      const userData = {
        email: 'test@example.com',
        password: 'password123',
        firstName: 'John'
      };
      
      const createdUser = { id: '123', ...userData };
      mockUserRepository.create.mockResolvedValue(createdUser);
      mockEmailService.sendWelcomeEmail.mockResolvedValue(true);
      
      const result = await userService.createUser(userData);
      
      expect(mockUserRepository.create).toHaveBeenCalledWith(userData);
      expect(mockEmailService.sendWelcomeEmail).toHaveBeenCalledWith(userData.email);
      expect(result).toEqual(createdUser);
    });
    
    it('should handle email service failure gracefully', async () => {
      const userData = { email: 'test@example.com' };
      const createdUser = { id: '123', ...userData };
      
      mockUserRepository.create.mockResolvedValue(createdUser);
      mockEmailService.sendWelcomeEmail.mockRejectedValue(new Error('Email failed'));
      
      // Should still create user even if email fails
      const result = await userService.createUser(userData);
      expect(result).toEqual(createdUser);
    });
  });
});

// Integration tests with real database
describe('User API Integration', () => {
  beforeEach(async () => {
    await setupTestDatabase();
  });
  
  afterEach(async () => {
    await clearTestDatabase();
  });
  
  it('should create user with valid data', async () => {
    const userData = {
      email: 'test@example.com',
      password: 'Password123!',
      firstName: 'John',
      lastName: 'Doe'
    };
    
    const response = await request(app)
      .post('/api/users')
      .send(userData)
      .expect(201);
    
    expect(response.body.success).toBe(true);
    expect(response.body.data.user.email).toBe(userData.email);
    
    // Verify in database
    const user = await User.findOne({ email: userData.email });
    expect(user).toBeTruthy();
  });
});
```

### 5.2 Test Configuration

**✅ DO:**
```javascript
// Jest configuration for different test types
module.exports = {
  testEnvironment: 'node',
  setupFilesAfterEnv: ['<rootDir>/tests/setup.js'],
  testMatch: [
    '<rootDir>/tests/**/*.test.js',
    '<rootDir>/src/**/*.test.js'
  ],
  collectCoverageFrom: [
    'src/**/*.js',
    '!src/**/*.test.js',
    '!src/server.js'
  ],
  coverageThreshold: {
    global: {
      branches: 80,
      functions: 80,
      lines: 80,
      statements: 80
    }
  },
  projects: [
    {
      displayName: 'unit',
      testMatch: ['<rootDir>/tests/unit/**/*.test.js']
    },
    {
      displayName: 'integration',
      testMatch: ['<rootDir>/tests/integration/**/*.test.js']
    }
  ]
};
```

## 6. Database Management

### 6.1 Schema Design

**✅ DO:**
```javascript
// Well-designed schema with proper validation
const userSchema = new mongoose.Schema({
  email: {
    type: String,
    required: [true, 'Email is required'],
    unique: true,
    lowercase: true,
    validate: [validator.isEmail, 'Invalid email'],
    index: true
  },
  password: {
    type: String,
    required: [true, 'Password is required'],
    minlength: [8, 'Password must be at least 8 characters'],
    select: false // Don't include in queries by default
  },
  profile: {
    firstName: {
      type: String,
      required: [true, 'First name is required'],
      trim: true,
      maxlength: [50, 'First name too long']
    },
    lastName: {
      type: String,
      required: [true, 'Last name is required'],
      trim: true,
      maxlength: [50, 'Last name too long']
    },
    avatar: {
      type: String,
      validate: [validator.isURL, 'Invalid avatar URL']
    }
  },
  settings: {
    notifications: {
      email: { type: Boolean, default: true },
      push: { type: Boolean, default: true }
    },
    privacy: {
      profileVisible: { type: Boolean, default: true }
    }
  },
  metadata: {
    lastLogin: Date,
    loginCount: { type: Number, default: 0 },
    ipAddress: String,
    userAgent: String
  }
}, {
  timestamps: true,
  toJSON: {
    transform: function(doc, ret) {
      delete ret.password;
      delete ret.__v;
      return ret;
    }
  }
});

// Compound indexes for common queries
userSchema.index({ 'profile.firstName': 1, 'profile.lastName': 1 });
userSchema.index({ createdAt: -1, 'settings.privacy.profileVisible': 1 });
```

### 6.2 Database Connection Management

**✅ DO:**
```javascript
// Robust connection handling with retry logic
class DatabaseManager {
  constructor() {
    this.connection = null;
    this.retryCount = 0;
    this.maxRetries = 5;
  }
  
  async connect() {
    const options = {
      useNewUrlParser: true,
      useUnifiedTopology: true,
      maxPoolSize: 10,
      serverSelectionTimeoutMS: 5000,
      socketTimeoutMS: 45000,
      bufferCommands: false,
      bufferMaxEntries: 0
    };
    
    try {
      this.connection = await mongoose.connect(process.env.MONGO_URI, options);
      this.retryCount = 0;
      
      logger.info('Database connected successfully');
      
      // Monitor connection events
      mongoose.connection.on('error', this.handleError.bind(this));
      mongoose.connection.on('disconnected', this.handleDisconnect.bind(this));
      
    } catch (error) {
      await this.handleConnectionError(error);
    }
  }
  
  async handleConnectionError(error) {
    logger.error(`Database connection failed (attempt ${this.retryCount + 1}):`, error);
    
    if (this.retryCount < this.maxRetries) {
      this.retryCount++;
      const delay = Math.min(1000 * Math.pow(2, this.retryCount), 30000);
      
      logger.info(`Retrying connection in ${delay}ms...`);
      setTimeout(() => this.connect(), delay);
    } else {
      logger.error('Max retry attempts reached. Exiting...');
      process.exit(1);
    }
  }
}
```

## 7. API Design & Documentation

### 7.1 RESTful API Design

**✅ DO:**
```javascript
// Consistent API response format
const sendResponse = (res, data, message = 'Success', statusCode = 200) => {
  res.status(statusCode).json({
    success: true,
    message,
    data,
    timestamp: new Date().toISOString()
  });
};

const sendError = (res, message, statusCode = 400, errors = []) => {
  res.status(statusCode).json({
    success: false,
    message,
    errors,
    timestamp: new Date().toISOString()
  });
};

// Proper HTTP status codes
app.post('/api/users', async (req, res) => {
  const user = await UserService.createUser(req.body);
  sendResponse(res, { user }, 'User created successfully', 201);
});

app.get('/api/users/:id', async (req, res) => {
  const user = await UserService.getUserById(req.params.id);
  if (!user) {
    return sendError(res, 'User not found', 404);
  }
  sendResponse(res, { user });
});
```

### 7.2 API Documentation

**✅ DO:**
```javascript
// OpenAPI/Swagger documentation
/**
 * @swagger
 * /api/users:
 *   post:
 *     summary: Create a new user
 *     tags: [Users]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - email
 *               - password
 *               - firstName
 *               - lastName
 *             properties:
 *               email:
 *                 type: string
 *                 format: email
 *                 example: user@example.com
 *               password:
 *                 type: string
 *                 minLength: 8
 *                 example: SecurePass123!
 *               firstName:
 *                 type: string
 *                 example: John
 *               lastName:
 *                 type: string
 *                 example: Doe
 *     responses:
 *       201:
 *         description: User created successfully
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/UserResponse'
 *       400:
 *         description: Validation error
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 */
```

## 8. Deployment & Operations

### 8.1 Environment Configuration

**✅ DO:**
```javascript
// Environment-specific configurations
const environments = {
  development: {
    port: 3000,
    logLevel: 'debug',
    cors: { origin: 'http://localhost:3000' },
    rateLimit: { max: 1000 }
  },
  
  staging: {
    port: process.env.PORT || 3000,
    logLevel: 'info',
    cors: { origin: process.env.STAGING_ORIGIN },
    rateLimit: { max: 500 }
  },
  
  production: {
    port: process.env.PORT || 3000,
    logLevel: 'warn',
    cors: { origin: process.env.PROD_ORIGIN },
    rateLimit: { max: 100 }
  }
};

const config = environments[process.env.NODE_ENV] || environments.development;
```

### 8.2 Health Checks & Monitoring

**✅ DO:**
```javascript
// Comprehensive health check endpoint
app.get('/health', async (req, res) => {
  const healthStatus = {
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    version: process.env.APP_VERSION,
    environment: process.env.NODE_ENV,
    checks: {}
  };
  
  try {
    // Database health
    await mongoose.connection.db.admin().ping();
    healthStatus.checks.database = { status: 'healthy' };
  } catch (error) {
    healthStatus.checks.database = { status: 'unhealthy', error: error.message };
    healthStatus.status = 'unhealthy';
  }
  
  try {
    // Redis health
    await redisClient.ping();
    healthStatus.checks.redis = { status: 'healthy' };
  } catch (error) {
    healthStatus.checks.redis = { status: 'unhealthy', error: error.message };
    healthStatus.status = 'degraded';
  }
  
  const statusCode = healthStatus.status === 'healthy' ? 200 : 503;
  res.status(statusCode).json(healthStatus);
});

// Application metrics
const promClient = require('prom-client');

const httpRequestDuration = new promClient.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status_code']
});

app.use((req, res, next) => {
  const start = Date.now();
  
  res.on('finish', () => {
    const duration = (Date.now() - start) / 1000;
    httpRequestDuration
      .labels(req.method, req.route?.path || req.path, res.statusCode)
      .observe(duration);
  });
  
  next();
});
```

## 🔗 Navigation

### Related Documents
- ⬅️ **Previous**: [Implementation Guide](./implementation-guide.md)
- ➡️ **Next**: [Comparison Analysis](./comparison-analysis.md)

### Quick Links
- [Security Considerations](./security-considerations.md)
- [Architecture Patterns](./architecture-patterns.md)
- [Performance Optimization](./performance-optimization.md)

---

**Best Practices Guide Complete** | **Categories Covered**: 8 | **Code Examples**: 25+