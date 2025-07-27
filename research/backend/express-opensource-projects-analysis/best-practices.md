# Best Practices: Express.js Production Applications

## 🎯 Overview

Consolidated best practices derived from analyzing successful Express.js open source projects. These practices have been proven in production environments and are essential for building secure, scalable, and maintainable applications.

## 🏗️ Architecture Best Practices

### 1. Project Structure and Organization

**✅ Recommended Structure**

```
src/
├── config/           # Configuration management
│   ├── database.ts   # Database configuration
│   ├── redis.ts      # Cache configuration
│   ├── auth.ts       # Authentication settings
│   └── index.ts      # Centralized config
├── controllers/      # Request handlers (thin layer)
├── services/         # Business logic (thick layer)
├── repositories/     # Data access layer
├── middleware/       # Cross-cutting concerns
├── models/          # Data models and schemas
├── routes/          # Route definitions
├── types/           # TypeScript definitions
├── utils/           # Helper functions
├── validators/      # Input validation schemas
└── tests/           # Test files organized by type
    ├── unit/        # Unit tests
    ├── integration/ # Integration tests
    └── e2e/         # End-to-end tests
```

**❌ Avoid These Patterns:**
- Putting business logic in controllers
- Mixing data access with business logic
- Circular dependencies between modules
- Deep folder nesting (>4 levels)

### 2. Dependency Injection

**✅ Implement Proper DI:**

```typescript
// Container-based dependency injection
export class Container {
  private services = new Map<string, any>();
  
  register<T>(name: string, factory: () => T): void {
    this.services.set(name, factory);
  }
  
  resolve<T>(name: string): T {
    const factory = this.services.get(name);
    if (!factory) {
      throw new Error(`Service ${name} not found`);
    }
    return factory();
  }
}

// Service registration
const container = new Container();

container.register('userRepository', () => new UserRepository(prisma));
container.register('userService', () => new UserService(
  container.resolve('userRepository'),
  container.resolve('logger')
));
container.register('userController', () => new UserController(
  container.resolve('userService')
));

// Usage in routes
const userController = container.resolve<UserController>('userController');
router.get('/users', userController.getUsers.bind(userController));
```

### 3. Layered Architecture Implementation

**✅ Proper Layer Separation:**

```typescript
// Controller Layer - Handle HTTP concerns only
export class UserController {
  constructor(private userService: UserService) {}
  
  async getUsers(req: Request, res: Response): Promise<void> {
    try {
      const { page = 1, limit = 10, search } = req.query;
      
      const result = await this.userService.getUsers({
        page: Number(page),
        limit: Number(limit),
        search: search as string
      });
      
      res.json({
        success: true,
        data: result.users,
        pagination: result.pagination
      });
    } catch (error) {
      res.status(400).json({
        success: false,
        message: error.message
      });
    }
  }
}

// Service Layer - Business logic and orchestration
export class UserService {
  constructor(
    private userRepository: UserRepository,
    private emailService: EmailService,
    private cacheService: CacheService
  ) {}
  
  async getUsers(params: GetUsersParams): Promise<GetUsersResult> {
    // Validate business rules
    if (params.limit > 100) {
      throw new Error('Limit cannot exceed 100');
    }
    
    // Check cache first
    const cacheKey = `users:${JSON.stringify(params)}`;
    const cached = await this.cacheService.get(cacheKey);
    if (cached) {
      return cached;
    }
    
    // Fetch from repository
    const users = await this.userRepository.findUsers(params);
    const total = await this.userRepository.countUsers(params);
    
    const result = {
      users,
      pagination: {
        page: params.page,
        limit: params.limit,
        total,
        pages: Math.ceil(total / params.limit)
      }
    };
    
    // Cache result
    await this.cacheService.set(cacheKey, result, 300); // 5 minutes
    
    return result;
  }
}

// Repository Layer - Data access only
export class UserRepository {
  constructor(private prisma: PrismaClient) {}
  
  async findUsers(params: GetUsersParams): Promise<User[]> {
    const where: any = {};
    
    if (params.search) {
      where.OR = [
        { name: { contains: params.search, mode: 'insensitive' } },
        { email: { contains: params.search, mode: 'insensitive' } }
      ];
    }
    
    return this.prisma.user.findMany({
      where,
      skip: (params.page - 1) * params.limit,
      take: params.limit,
      select: {
        id: true,
        name: true,
        email: true,
        isActive: true,
        createdAt: true
      },
      orderBy: { createdAt: 'desc' }
    });
  }
}
```

## 🔒 Security Best Practices

### 1. Authentication and Authorization

**✅ JWT Best Practices:**

```typescript
// Secure JWT configuration
export const jwtConfig = {
  algorithm: 'RS256', // Use asymmetric algorithms in production
  accessTokenExpiry: '15m', // Short-lived access tokens
  refreshTokenExpiry: '7d', // Longer-lived refresh tokens
  issuer: process.env.JWT_ISSUER,
  audience: process.env.JWT_AUDIENCE,
  
  // Token verification options
  options: {
    algorithms: ['RS256'],
    issuer: process.env.JWT_ISSUER,
    audience: process.env.JWT_AUDIENCE,
    clockTolerance: 30 // 30 seconds clock skew tolerance
  }
};

// Secure token generation
export class TokenService {
  private publicKey: string;
  private privateKey: string;
  
  constructor() {
    this.publicKey = process.env.JWT_PUBLIC_KEY!.replace(/\\n/g, '\n');
    this.privateKey = process.env.JWT_PRIVATE_KEY!.replace(/\\n/g, '\n');
  }
  
  generateAccessToken(payload: TokenPayload): string {
    return jwt.sign(payload, this.privateKey, {
      algorithm: 'RS256',
      expiresIn: jwtConfig.accessTokenExpiry,
      issuer: jwtConfig.issuer,
      audience: jwtConfig.audience,
      subject: payload.userId,
      jwtid: crypto.randomBytes(16).toString('hex') // Unique token ID
    });
  }
  
  verifyToken(token: string): TokenPayload {
    return jwt.verify(token, this.publicKey, jwtConfig.options) as TokenPayload;
  }
}
```

**✅ Authorization Patterns:**

```typescript
// Role-based access control with permissions
export class AuthorizationService {
  async checkPermission(
    userId: string,
    resource: string,
    action: string
  ): Promise<boolean> {
    const user = await this.userRepository.findWithPermissions(userId);
    
    if (!user || !user.isActive) {
      return false;
    }
    
    // Check if user has required permission
    const hasPermission = user.roles.some(role =>
      role.permissions.some(permission =>
        permission.resource === resource && permission.action === action
      )
    );
    
    return hasPermission;
  }
  
  // Resource ownership check
  async checkOwnership(
    userId: string,
    resourceType: string,
    resourceId: string
  ): Promise<boolean> {
    const resource = await this.getResource(resourceType, resourceId);
    return resource?.ownerId === userId;
  }
}

// Authorization middleware
export const requirePermission = (resource: string, action: string) => {
  return async (req: AuthRequest, res: Response, next: NextFunction) => {
    const hasPermission = await authService.checkPermission(
      req.user!.id,
      resource,
      action
    );
    
    if (!hasPermission) {
      return res.status(403).json({
        success: false,
        message: 'Insufficient permissions',
        code: 'FORBIDDEN'
      });
    }
    
    next();
  };
};
```

### 2. Input Validation and Sanitization

**✅ Comprehensive Validation:**

```typescript
// Validation middleware with Joi
export const createValidationMiddleware = (schema: Joi.ObjectSchema) => {
  return async (req: Request, res: Response, next: NextFunction) => {
    try {
      // Validate and sanitize
      const { error, value } = schema.validate(req.body, {
        abortEarly: false,
        allowUnknown: false,
        stripUnknown: true,
        convert: true
      });
      
      if (error) {
        const errors = error.details.map(detail => ({
          field: detail.path.join('.'),
          message: detail.message,
          type: detail.type
        }));
        
        return res.status(400).json({
          success: false,
          message: 'Validation failed',
          errors
        });
      }
      
      // Replace request body with validated data
      req.body = value;
      next();
    } catch (err) {
      next(err);
    }
  };
};

// Comprehensive validation schemas
export const userSchemas = {
  create: Joi.object({
    email: Joi.string()
      .email({ tlds: { allow: false } })
      .lowercase()
      .required(),
    
    password: Joi.string()
      .min(8)
      .max(128)
      .pattern(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]/)
      .required()
      .messages({
        'string.pattern.base': 'Password must contain at least one lowercase letter, uppercase letter, number, and special character'
      }),
    
    name: Joi.string()
      .min(2)
      .max(100)
      .pattern(/^[a-zA-Z\s'-]+$/)
      .required()
      .messages({
        'string.pattern.base': 'Name can only contain letters, spaces, hyphens, and apostrophes'
      }),
    
    phone: Joi.string()
      .pattern(/^\+?[1-9]\d{1,14}$/)
      .optional()
      .messages({
        'string.pattern.base': 'Please provide a valid phone number'
      }),
    
    dateOfBirth: Joi.date()
      .max('now')
      .min('1900-01-01')
      .optional(),
    
    preferences: Joi.object({
      notifications: Joi.boolean().default(true),
      language: Joi.string().valid('en', 'es', 'fr').default('en'),
      timezone: Joi.string().default('UTC')
    }).optional()
  }),
  
  update: Joi.object({
    name: Joi.string().min(2).max(100).pattern(/^[a-zA-Z\s'-]+$/),
    phone: Joi.string().pattern(/^\+?[1-9]\d{1,14}$/),
    dateOfBirth: Joi.date().max('now').min('1900-01-01'),
    preferences: Joi.object({
      notifications: Joi.boolean(),
      language: Joi.string().valid('en', 'es', 'fr'),
      timezone: Joi.string()
    })
  }).min(1).messages({
    'object.min': 'At least one field must be provided for update'
  })
};
```

### 3. Data Sanitization

**✅ XSS and Injection Prevention:**

```typescript
import DOMPurify from 'isomorphic-dompurify';
import validator from 'validator';

export class SanitizationService {
  // Sanitize HTML content
  static sanitizeHTML(content: string): string {
    return DOMPurify.sanitize(content, {
      ALLOWED_TAGS: ['p', 'br', 'strong', 'em', 'u', 'ol', 'ul', 'li'],
      ALLOWED_ATTR: []
    });
  }
  
  // Sanitize user input
  static sanitizeInput(input: any): any {
    if (typeof input === 'string') {
      return validator.escape(input.trim());
    }
    
    if (Array.isArray(input)) {
      return input.map(item => this.sanitizeInput(item));
    }
    
    if (typeof input === 'object' && input !== null) {
      const sanitized: any = {};
      for (const [key, value] of Object.entries(input)) {
        sanitized[validator.escape(key)] = this.sanitizeInput(value);
      }
      return sanitized;
    }
    
    return input;
  }
  
  // File upload sanitization
  static sanitizeFileName(fileName: string): string {
    return fileName
      .replace(/[^a-zA-Z0-9.-]/g, '_')
      .replace(/_{2,}/g, '_')
      .toLowerCase();
  }
}

// Sanitization middleware
export const sanitizeInput = (req: Request, res: Response, next: NextFunction) => {
  if (req.body) {
    req.body = SanitizationService.sanitizeInput(req.body);
  }
  
  if (req.query) {
    req.query = SanitizationService.sanitizeInput(req.query);
  }
  
  next();
};
```

## ⚡ Performance Best Practices

### 1. Database Optimization

**✅ Query Optimization:**

```typescript
// Efficient repository patterns
export class UserRepository {
  // Use database indexing
  async findByEmail(email: string): Promise<User | null> {
    return this.prisma.user.findUnique({
      where: { email }, // email should be indexed
      select: {
        id: true,
        email: true,
        name: true,
        roles: {
          select: {
            name: true,
            permissions: {
              select: { name: true }
            }
          }
        }
      }
    });
  }
  
  // Implement pagination properly
  async findUsers(params: FindUsersParams): Promise<PaginatedResult<User>> {
    const [users, total] = await Promise.all([
      this.prisma.user.findMany({
        where: this.buildWhereClause(params),
        select: this.getUserSelectFields(),
        skip: (params.page - 1) * params.limit,
        take: params.limit,
        orderBy: { [params.sortBy]: params.sortOrder }
      }),
      this.prisma.user.count({
        where: this.buildWhereClause(params)
      })
    ]);
    
    return {
      data: users,
      pagination: {
        page: params.page,
        limit: params.limit,
        total,
        pages: Math.ceil(total / params.limit)
      }
    };
  }
  
  // Batch operations for efficiency
  async createMultipleUsers(userData: CreateUserData[]): Promise<User[]> {
    return this.prisma.user.createMany({
      data: userData,
      skipDuplicates: true
    });
  }
  
  // Use transactions for data consistency
  async transferUserData(fromUserId: string, toUserId: string): Promise<void> {
    await this.prisma.$transaction(async (tx) => {
      await tx.post.updateMany({
        where: { authorId: fromUserId },
        data: { authorId: toUserId }
      });
      
      await tx.user.delete({
        where: { id: fromUserId }
      });
    });
  }
}
```

### 2. Caching Strategies

**✅ Multi-Level Caching:**

```typescript
// Cache service with multiple strategies
export class CacheService {
  private redisClient: Redis;
  private memoryCache: Map<string, any> = new Map();
  
  constructor(redisClient: Redis) {
    this.redisClient = redisClient;
  }
  
  // L1: Memory cache for frequently accessed data
  async getFromMemory<T>(key: string): Promise<T | null> {
    const cached = this.memoryCache.get(key);
    if (cached && cached.expiresAt > Date.now()) {
      return cached.value;
    }
    
    this.memoryCache.delete(key);
    return null;
  }
  
  setInMemory<T>(key: string, value: T, ttl: number): void {
    this.memoryCache.set(key, {
      value,
      expiresAt: Date.now() + (ttl * 1000)
    });
  }
  
  // L2: Redis cache for shared data
  async get<T>(key: string): Promise<T | null> {
    // Try memory cache first
    const memoryResult = await this.getFromMemory<T>(key);
    if (memoryResult) {
      return memoryResult;
    }
    
    // Try Redis cache
    const cached = await this.redisClient.get(key);
    if (cached) {
      const parsed = JSON.parse(cached);
      
      // Store in memory cache for next access
      this.setInMemory(key, parsed, 60); // 1 minute in memory
      
      return parsed;
    }
    
    return null;
  }
  
  async set<T>(key: string, value: T, ttl: number = 3600): Promise<void> {
    // Store in Redis
    await this.redisClient.setex(key, ttl, JSON.stringify(value));
    
    // Store in memory cache for immediate access
    this.setInMemory(key, value, Math.min(ttl, 300)); // Max 5 minutes in memory
  }
  
  // Cache invalidation patterns
  async invalidatePattern(pattern: string): Promise<void> {
    const keys = await this.redisClient.keys(pattern);
    if (keys.length > 0) {
      await this.redisClient.del(...keys);
    }
    
    // Clear related memory cache entries
    for (const [key] of this.memoryCache) {
      if (key.match(pattern.replace('*', '.*'))) {
        this.memoryCache.delete(key);
      }
    }
  }
}

// Caching middleware
export const cacheMiddleware = (ttl: number = 300) => {
  return async (req: Request, res: Response, next: NextFunction) => {
    if (req.method !== 'GET') {
      return next();
    }
    
    const cacheKey = `api:${req.originalUrl}:${JSON.stringify(req.query)}`;
    const cached = await cacheService.get(cacheKey);
    
    if (cached) {
      return res.json(cached);
    }
    
    // Store original json method
    const originalJson = res.json;
    
    // Override json method to cache response
    res.json = function(body: any) {
      if (res.statusCode === 200) {
        cacheService.set(cacheKey, body, ttl);
      }
      return originalJson.call(this, body);
    };
    
    next();
  };
};
```

### 3. Request Processing Optimization

**✅ Efficient Middleware Order:**

```typescript
// Optimized middleware stack
export const setupMiddleware = (app: Express) => {
  // 1. Early termination for health checks
  app.get('/health', (req, res) => {
    res.json({ status: 'ok', timestamp: Date.now() });
  });
  
  // 2. Security headers (lightweight)
  app.use(helmet());
  
  // 3. CORS (before other middleware)
  app.use(cors(corsOptions));
  
  // 4. Request logging (non-blocking)
  app.use(morgan('combined', { stream: logStream }));
  
  // 5. Rate limiting (prevent abuse early)
  app.use(rateLimiter);
  
  // 6. Body parsing (with limits)
  app.use(express.json({ 
    limit: '10mb',
    verify: (req, res, buf) => {
      // Early validation for malformed JSON
      try {
        JSON.parse(buf.toString());
      } catch (err) {
        throw new Error('Invalid JSON');
      }
    }
  }));
  
  // 7. Response compression (after body parsing)
  app.use(compression({
    filter: (req, res) => {
      if (req.headers['x-no-compression']) {
        return false;
      }
      return compression.filter(req, res);
    },
    threshold: 1024 // Only compress responses > 1KB
  }));
  
  // 8. Session management (if needed)
  app.use(session(sessionConfig));
  
  // 9. Authentication (for protected routes)
  app.use('/api/protected', authenticateToken);
};
```

## 🧪 Testing Best Practices

### 1. Test Structure and Organization

**✅ Comprehensive Testing Strategy:**

```typescript
// Test structure example
describe('UserService', () => {
  let userService: UserService;
  let userRepository: jest.Mocked<UserRepository>;
  let emailService: jest.Mocked<EmailService>;
  
  beforeEach(() => {
    // Create mocks
    userRepository = createMockUserRepository();
    emailService = createMockEmailService();
    
    // Inject dependencies
    userService = new UserService(userRepository, emailService);
  });
  
  describe('createUser', () => {
    it('should create user with valid data', async () => {
      // Arrange
      const userData = {
        email: 'test@example.com',
        password: 'SecurePass123!',
        name: 'Test User'
      };
      
      const expectedUser = {
        id: '1',
        ...userData,
        password: 'hashed_password',
        createdAt: new Date()
      };
      
      userRepository.findByEmail.mockResolvedValue(null);
      userRepository.create.mockResolvedValue(expectedUser);
      
      // Act
      const result = await userService.createUser(userData);
      
      // Assert
      expect(result).toMatchObject({
        id: expect.any(String),
        email: userData.email,
        name: userData.name
      });
      expect(result.password).toBeUndefined(); // Password should be excluded
      expect(userRepository.create).toHaveBeenCalledWith({
        ...userData,
        password: expect.any(String) // Should be hashed
      });
      expect(emailService.sendWelcomeEmail).toHaveBeenCalledWith(expectedUser);
    });
    
    it('should throw error if user already exists', async () => {
      // Arrange
      const userData = {
        email: 'existing@example.com',
        password: 'SecurePass123!',
        name: 'Test User'
      };
      
      userRepository.findByEmail.mockResolvedValue({
        id: '1',
        email: userData.email
      } as User);
      
      // Act & Assert
      await expect(userService.createUser(userData))
        .rejects
        .toThrow('User already exists');
      
      expect(userRepository.create).not.toHaveBeenCalled();
      expect(emailService.sendWelcomeEmail).not.toHaveBeenCalled();
    });
  });
});

// Integration tests
describe('User API Integration Tests', () => {
  let app: Application;
  let server: Server;
  
  beforeAll(async () => {
    app = await createTestApp();
    server = app.listen(0);
  });
  
  afterAll(async () => {
    await server.close();
    await cleanupDatabase();
  });
  
  beforeEach(async () => {
    await seedTestData();
  });
  
  afterEach(async () => {
    await clearTestData();
  });
  
  describe('POST /api/users', () => {
    it('should create user and return 201', async () => {
      const userData = {
        email: 'newuser@example.com',
        password: 'SecurePass123!',
        name: 'New User'
      };
      
      const response = await request(app)
        .post('/api/users')
        .send(userData)
        .expect(201);
      
      expect(response.body).toMatchObject({
        success: true,
        data: {
          id: expect.any(String),
          email: userData.email,
          name: userData.name
        }
      });
      
      // Verify user was created in database
      const createdUser = await User.findOne({ email: userData.email });
      expect(createdUser).toBeTruthy();
      expect(createdUser!.password).not.toBe(userData.password); // Should be hashed
    });
  });
});
```

### 2. Test Data Management

**✅ Test Data Factories:**

```typescript
// Test data factories
export class UserFactory {
  static create(overrides: Partial<User> = {}): User {
    return {
      id: faker.string.uuid(),
      email: faker.internet.email(),
      name: faker.person.fullName(),
      password: faker.internet.password(),
      isActive: true,
      createdAt: new Date(),
      updatedAt: new Date(),
      ...overrides
    };
  }
  
  static createMany(count: number, overrides: Partial<User> = {}): User[] {
    return Array.from({ length: count }, () => this.create(overrides));
  }
  
  static createWithRoles(roles: string[], overrides: Partial<User> = {}): User {
    return {
      ...this.create(overrides),
      roles: roles.map(name => ({ name, permissions: [] }))
    };
  }
}

// Database seeding for tests
export class TestDataSeeder {
  static async seedUsers(count: number = 10): Promise<User[]> {
    const users = UserFactory.createMany(count);
    return Promise.all(
      users.map(user => prisma.user.create({ data: user }))
    );
  }
  
  static async createTestUser(overrides: Partial<User> = {}): Promise<User> {
    const userData = UserFactory.create(overrides);
    return prisma.user.create({ data: userData });
  }
  
  static async cleanup(): Promise<void> {
    await prisma.user.deleteMany({});
    await prisma.role.deleteMany({});
    await prisma.permission.deleteMany({});
  }
}
```

## 📊 Monitoring and Observability

### 1. Structured Logging

**✅ Comprehensive Logging Strategy:**

```typescript
// Enhanced logging service
export class LoggingService {
  private logger: winston.Logger;
  private performanceLogger: winston.Logger;
  private securityLogger: winston.Logger;
  
  constructor() {
    this.logger = this.createLogger('application');
    this.performanceLogger = this.createLogger('performance');
    this.securityLogger = this.createLogger('security');
  }
  
  // Request logging middleware
  createRequestLogger() {
    return (req: Request, res: Response, next: NextFunction) => {
      const startTime = Date.now();
      const requestId = crypto.randomUUID();
      
      // Add request ID to request object
      req.requestId = requestId;
      
      // Log request start
      this.logger.info('Request started', {
        requestId,
        method: req.method,
        url: req.url,
        ip: req.ip,
        userAgent: req.headers['user-agent'],
        userId: req.user?.id
      });
      
      // Override res.end to log response
      const originalEnd = res.end;
      res.end = function(chunk?: any, encoding?: any) {
        const duration = Date.now() - startTime;
        
        // Log request completion
        this.logger.info('Request completed', {
          requestId,
          statusCode: res.statusCode,
          duration,
          contentLength: res.get('content-length')
        });
        
        // Log performance metrics
        if (duration > 1000) { // Slow request threshold
          this.performanceLogger.warn('Slow request detected', {
            requestId,
            method: req.method,
            url: req.url,
            duration,
            userId: req.user?.id
          });
        }
        
        originalEnd.call(this, chunk, encoding);
      }.bind(this);
      
      next();
    };
  }
  
  // Security event logging
  logSecurityEvent(event: SecurityEvent): void {
    this.securityLogger.warn('Security event', {
      type: event.type,
      severity: event.severity,
      userId: event.userId,
      ip: event.ip,
      details: event.details,
      timestamp: new Date().toISOString()
    });
  }
  
  // Performance metrics
  logPerformanceMetric(metric: PerformanceMetric): void {
    this.performanceLogger.info('Performance metric', {
      operation: metric.operation,
      duration: metric.duration,
      resourceUsage: metric.resourceUsage,
      timestamp: new Date().toISOString()
    });
  }
}
```

### 2. Health Checks and Metrics

**✅ Comprehensive Health Monitoring:**

```typescript
// Health check service
export class HealthCheckService {
  private checks: Map<string, HealthCheck> = new Map();
  
  registerCheck(name: string, check: HealthCheck): void {
    this.checks.set(name, check);
  }
  
  async runAllChecks(): Promise<HealthStatus> {
    const results: Record<string, any> = {};
    let overallStatus = 'healthy';
    
    for (const [name, check] of this.checks) {
      try {
        const result = await Promise.race([
          check.execute(),
          new Promise((_, reject) => 
            setTimeout(() => reject(new Error('Timeout')), 5000)
          )
        ]);
        
        results[name] = {
          status: 'healthy',
          details: result,
          timestamp: new Date().toISOString()
        };
      } catch (error) {
        results[name] = {
          status: 'unhealthy',
          error: error.message,
          timestamp: new Date().toISOString()
        };
        
        if (overallStatus === 'healthy') {
          overallStatus = 'degraded';
        }
      }
    }
    
    return {
      status: overallStatus,
      checks: results,
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
      version: process.env.APP_VERSION || 'unknown'
    };
  }
}

// Health check implementations
export const databaseHealthCheck: HealthCheck = {
  async execute() {
    const start = Date.now();
    await prisma.$queryRaw`SELECT 1`;
    const duration = Date.now() - start;
    
    return {
      connectionTime: duration,
      status: duration < 1000 ? 'good' : 'slow'
    };
  }
};

export const redisHealthCheck: HealthCheck = {
  async execute() {
    const start = Date.now();
    await redisClient.ping();
    const duration = Date.now() - start;
    
    return {
      connectionTime: duration,
      status: duration < 100 ? 'good' : 'slow'
    };
  }
};

// Health check endpoint
app.get('/health', async (req, res) => {
  const healthStatus = await healthCheckService.runAllChecks();
  
  const statusCode = healthStatus.status === 'healthy' ? 200 : 503;
  res.status(statusCode).json(healthStatus);
});
```

## 🚀 Deployment Best Practices

### 1. Environment Configuration

**✅ Secure Configuration Management:**

```typescript
// Environment-specific configurations
export const environmentConfigs = {
  development: {
    logLevel: 'debug',
    enableCors: true,
    rateLimitEnabled: false,
    cacheEnabled: false
  },
  
  staging: {
    logLevel: 'info',
    enableCors: true,
    rateLimitEnabled: true,
    cacheEnabled: true
  },
  
  production: {
    logLevel: 'warn',
    enableCors: false, // Use specific origins
    rateLimitEnabled: true,
    cacheEnabled: true,
    securityHeadersEnabled: true,
    httpsOnly: true
  }
};

// Configuration validation
const configSchema = Joi.object({
  NODE_ENV: Joi.string().valid('development', 'staging', 'production').required(),
  PORT: Joi.number().port().required(),
  DATABASE_URL: Joi.string().uri().required(),
  JWT_SECRET: Joi.string().min(32).required(),
  REDIS_URL: Joi.string().uri().optional(),
  LOG_LEVEL: Joi.string().valid('error', 'warn', 'info', 'debug').default('info')
});

export function validateConfig(): void {
  const { error } = configSchema.validate(process.env);
  if (error) {
    throw new Error(`Configuration validation failed: ${error.message}`);
  }
}
```

### 2. Graceful Shutdown

**✅ Proper Application Lifecycle Management:**

```typescript
// Graceful shutdown handler
export class GracefulShutdown {
  private isShuttingDown = false;
  private connections: Set<any> = new Set();
  
  constructor(private app: Express) {
    this.setupSignalHandlers();
  }
  
  private setupSignalHandlers(): void {
    process.on('SIGTERM', () => this.shutdown('SIGTERM'));
    process.on('SIGINT', () => this.shutdown('SIGINT'));
    process.on('SIGUSR2', () => this.shutdown('SIGUSR2')); // Nodemon restart
  }
  
  private async shutdown(signal: string): Promise<void> {
    if (this.isShuttingDown) {
      logger.info('Shutdown already in progress, ignoring signal', { signal });
      return;
    }
    
    this.isShuttingDown = true;
    logger.info('Received shutdown signal, starting graceful shutdown', { signal });
    
    try {
      // Stop accepting new requests
      await this.stopAcceptingConnections();
      
      // Wait for existing requests to complete
      await this.waitForActiveConnections();
      
      // Close database connections
      await this.closeDatabaseConnections();
      
      // Close Redis connections
      await this.closeRedisConnections();
      
      // Cleanup resources
      await this.cleanup();
      
      logger.info('Graceful shutdown completed');
      process.exit(0);
    } catch (error) {
      logger.error('Error during shutdown', { error: error.message });
      process.exit(1);
    }
  }
  
  private async stopAcceptingConnections(): Promise<void> {
    return new Promise((resolve) => {
      this.server?.close(() => {
        logger.info('Server stopped accepting new connections');
        resolve();
      });
    });
  }
  
  private async waitForActiveConnections(timeout = 30000): Promise<void> {
    const startTime = Date.now();
    
    while (this.connections.size > 0 && Date.now() - startTime < timeout) {
      logger.info(`Waiting for ${this.connections.size} active connections to close`);
      await new Promise(resolve => setTimeout(resolve, 1000));
    }
    
    if (this.connections.size > 0) {
      logger.warn(`Forcefully closing ${this.connections.size} remaining connections`);
      this.connections.forEach(connection => connection.destroy());
    }
  }
}
```

## 📋 Development Workflow Best Practices

### 1. Code Quality Standards

**✅ ESLint and Prettier Configuration:**

```json
// .eslintrc.json
{
  "extends": [
    "@typescript-eslint/recommended",
    "prettier"
  ],
  "plugins": ["@typescript-eslint"],
  "rules": {
    "@typescript-eslint/no-unused-vars": "error",
    "@typescript-eslint/explicit-function-return-type": "warn",
    "@typescript-eslint/no-explicit-any": "warn",
    "prefer-const": "error",
    "no-var": "error"
  }
}
```

```json
// .prettierrc
{
  "semi": true,
  "trailingComma": "es5",
  "singleQuote": true,
  "printWidth": 80,
  "tabWidth": 2,
  "useTabs": false
}
```

### 2. Git Workflow

**✅ Commit Message Convention:**

```bash
# Conventional commit format
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]

# Examples:
feat(auth): add JWT refresh token functionality
fix(user): resolve email validation issue
docs(api): update authentication endpoints
test(user): add integration tests for user creation
refactor(db): optimize user query performance
```

### 3. Pre-commit Hooks

**✅ Husky Configuration:**

```json
// package.json
{
  "husky": {
    "hooks": {
      "pre-commit": "lint-staged && npm run test:unit",
      "commit-msg": "commitlint -E HUSKY_GIT_PARAMS"
    }
  },
  "lint-staged": {
    "src/**/*.{ts,js}": [
      "eslint --fix",
      "prettier --write",
      "git add"
    ]
  }
}
```

## 📊 Key Metrics and KPIs

### Performance Benchmarks

| Metric | Target | Warning | Critical |
|--------|--------|---------|----------|
| **Response Time** | <200ms | 200-500ms | >500ms |
| **Error Rate** | <1% | 1-5% | >5% |
| **CPU Usage** | <70% | 70-85% | >85% |
| **Memory Usage** | <80% | 80-90% | >90% |
| **Database Connections** | <50% pool | 50-80% pool | >80% pool |

### Security Metrics

| Security Measure | Target | Implementation |
|------------------|--------|----------------|
| **Authentication Success Rate** | >99% | JWT + refresh tokens |
| **Failed Login Attempts** | <5/minute/IP | Rate limiting |
| **Security Headers Score** | A+ | Helmet.js configuration |
| **Dependency Vulnerabilities** | 0 high/critical | Regular security audits |

---

*Best Practices Guide | Research conducted January 2025*

**Navigation**
- **Previous**: [Implementation Guide](./implementation-guide.md) ←
- **Next**: [Template Examples](./template-examples.md) →
- **Back to**: [Research Overview](./README.md) ↑