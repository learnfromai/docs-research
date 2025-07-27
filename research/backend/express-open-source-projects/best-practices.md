# Best Practices for Express.js Production Applications

## 🎯 Best Practices Overview

Comprehensive compilation of best practices derived from analyzing 15+ major Express.js open source projects. These practices represent battle-tested approaches that ensure security, performance, maintainability, and scalability in production environments.

## 🔒 Security Best Practices

### 1. Authentication & Authorization

**✅ DO: Implement Multi-Factor Authentication**
```typescript
// JWT with refresh token rotation
class AuthService {
  generateTokenPair(user: User): TokenPair {
    const accessToken = jwt.sign(
      { sub: user.id, roles: user.roles },
      JWT_SECRET,
      { expiresIn: '15m', algorithm: 'RS256' }
    );
    
    const refreshToken = this.generateSecureRefreshToken();
    return { accessToken, refreshToken };
  }
  
  private generateSecureRefreshToken(): string {
    return crypto.randomBytes(32).toString('hex');
  }
}
```

**❌ DON'T: Store sensitive data in JWT payload**
```typescript
// BAD - Sensitive data in JWT
const payload = {
  sub: user.id,
  password: user.password, // ❌ Never store passwords
  creditCard: user.creditCard, // ❌ Never store PII
  socialSecurity: user.ssn // ❌ Never store sensitive data
};
```

**✅ DO: Use secure token storage**
```typescript
// Secure httpOnly cookies for web apps
app.use(cookieParser());

const setSecureToken = (res: Response, token: string) => {
  res.cookie('accessToken', token, {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'strict',
    maxAge: 15 * 60 * 1000 // 15 minutes
  });
};
```

### 2. Input Validation & Sanitization

**✅ DO: Validate all inputs**
```typescript
// Comprehensive validation with Joi
const userSchema = Joi.object({
  email: Joi.string().email().required(),
  password: Joi.string()
    .min(8)
    .pattern(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])/)
    .required(),
  age: Joi.number().integer().min(13).max(120)
});

// XSS protection
import DOMPurify from 'isomorphic-dompurify';

const sanitizeInput = (input: string): string => {
  return DOMPurify.sanitize(input, { FORBID_SCRIPTS: true });
};
```

**❌ DON'T: Trust user input**
```typescript
// BAD - No validation
app.post('/users', (req, res) => {
  const user = new User(req.body); // ❌ Direct assignment
  user.save(); // ❌ No validation
});
```

### 3. SQL Injection Prevention

**✅ DO: Use parameterized queries**
```typescript
// Safe parameterized query
const getUserByEmail = async (email: string): Promise<User | null> => {
  const query = 'SELECT * FROM users WHERE email = $1';
  const result = await db.query(query, [email]);
  return result.rows[0] || null;
};
```

**❌ DON'T: Use string concatenation**
```typescript
// BAD - SQL injection vulnerability
const getUserByEmail = async (email: string) => {
  const query = `SELECT * FROM users WHERE email = '${email}'`; // ❌ Vulnerable
  return db.query(query);
};
```

## 🚀 Performance Best Practices

### 1. Database Optimization

**✅ DO: Implement connection pooling**
```typescript
const pool = new Pool({
  host: 'localhost',
  port: 5432,
  database: 'myapp',
  user: 'postgres',
  password: 'password',
  max: 20, // Maximum connections
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000
});
```

**✅ DO: Use database indexes**
```sql
-- Essential indexes for user table
CREATE INDEX CONCURRENTLY idx_users_email ON users(email);
CREATE INDEX CONCURRENTLY idx_users_created_at ON users(created_at);
CREATE INDEX CONCURRENTLY idx_users_status ON users(status) WHERE status = 'active';
```

**✅ DO: Implement query optimization**
```typescript
// Efficient pagination
const getUsers = async (page: number, limit: number) => {
  const offset = (page - 1) * limit;
  const query = `
    SELECT id, email, first_name, last_name, created_at
    FROM users 
    WHERE status = 'active'
    ORDER BY created_at DESC 
    OFFSET $1 LIMIT $2
  `;
  return db.query(query, [offset, limit]);
};
```

### 2. Caching Strategies

**✅ DO: Implement multi-layer caching**
```typescript
class CacheService {
  async get<T>(key: string): Promise<T | null> {
    // L1: Memory cache (fastest)
    let value = this.memoryCache.get<T>(key);
    if (value) return value;
    
    // L2: Redis cache (distributed)
    value = await this.redisCache.get<T>(key);
    if (value) {
      this.memoryCache.set(key, value, 60); // 1 min in memory
      return value;
    }
    
    return null;
  }
}
```

**✅ DO: Cache expensive operations**
```typescript
// Cache database queries
@cache('user:profile', 300) // 5 minutes
async getUserProfile(userId: string): Promise<UserProfile> {
  return this.userRepository.getProfile(userId);
}

// Cache API responses
const cacheMiddleware = cache('5 minutes');
app.get('/api/users', cacheMiddleware, getUsersHandler);
```

### 3. Response Optimization

**✅ DO: Enable compression**
```typescript
import compression from 'compression';

app.use(compression({
  level: 6,
  threshold: 1024, // Only compress responses > 1kb
  filter: (req, res) => {
    if (req.headers['x-no-compression']) return false;
    return compression.filter(req, res);
  }
}));
```

**✅ DO: Implement streaming for large data**
```typescript
// Stream large responses
app.get('/export/users', (req, res) => {
  res.setHeader('Content-Type', 'application/json');
  res.write('[');
  
  let first = true;
  const userStream = getUserStream();
  
  userStream.on('data', (user) => {
    if (!first) res.write(',');
    res.write(JSON.stringify(user));
    first = false;
  });
  
  userStream.on('end', () => {
    res.write(']');
    res.end();
  });
});
```

## 🏗️ Architecture Best Practices

### 1. Code Organization

**✅ DO: Use feature-based organization**
```
src/
├── features/
│   ├── auth/
│   │   ├── controllers/
│   │   ├── services/
│   │   ├── repositories/
│   │   ├── middleware/
│   │   └── routes.ts
│   └── users/
│       ├── controllers/
│       ├── services/
│       ├── repositories/
│       └── routes.ts
├── shared/
│   ├── middleware/
│   ├── utils/
│   └── types/
└── config/
```

**✅ DO: Implement dependency injection**
```typescript
// Service container
class Container {
  private services = new Map();
  
  register<T>(token: string, factory: () => T): void {
    this.services.set(token, factory);
  }
  
  resolve<T>(token: string): T {
    const factory = this.services.get(token);
    if (!factory) throw new Error(`Service ${token} not found`);
    return factory();
  }
}

// Usage
container.register('UserRepository', () => new UserRepository(database));
container.register('UserService', () => 
  new UserService(container.resolve('UserRepository'))
);
```

### 2. Error Handling

**✅ DO: Implement centralized error handling**
```typescript
// Custom error classes
class AppError extends Error {
  constructor(
    public message: string,
    public statusCode: number,
    public isOperational: boolean = true
  ) {
    super(message);
    this.name = this.constructor.name;
  }
}

// Global error handler
const errorHandler = (err: AppError, req: Request, res: Response, next: NextFunction) => {
  const { statusCode = 500, message } = err;
  
  logger.error('Application error', {
    error: message,
    stack: err.stack,
    url: req.url,
    method: req.method,
    ip: req.ip
  });
  
  res.status(statusCode).json({
    error: message,
    ...(process.env.NODE_ENV !== 'production' && { stack: err.stack })
  });
};
```

**✅ DO: Use async error handling**
```typescript
// Async wrapper to catch errors
const asyncHandler = (fn: Function) => (req: Request, res: Response, next: NextFunction) => {
  Promise.resolve(fn(req, res, next)).catch(next);
};

// Usage
app.get('/users', asyncHandler(async (req, res) => {
  const users = await userService.getUsers();
  res.json(users);
}));
```

### 3. Configuration Management

**✅ DO: Use environment-based configuration**
```typescript
// Centralized configuration
const config = {
  env: process.env.NODE_ENV || 'development',
  port: parseInt(process.env.PORT || '3000'),
  database: {
    url: process.env.DATABASE_URL!,
    maxConnections: parseInt(process.env.DB_MAX_CONNECTIONS || '20')
  },
  jwt: {
    secret: process.env.JWT_SECRET!,
    expiresIn: process.env.JWT_EXPIRES_IN || '15m'
  },
  redis: {
    url: process.env.REDIS_URL!
  }
};

// Validate configuration
const validateConfig = () => {
  const required = ['DATABASE_URL', 'JWT_SECRET', 'REDIS_URL'];
  const missing = required.filter(key => !process.env[key]);
  
  if (missing.length > 0) {
    throw new Error(`Missing required environment variables: ${missing.join(', ')}`);
  }
};
```

## 📝 Logging Best Practices

### 1. Structured Logging

**✅ DO: Use structured JSON logging**
```typescript
// Winston configuration
const logger = winston.createLogger({
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  defaultMeta: { service: 'api' },
  transports: [
    new winston.transports.File({ filename: 'error.log', level: 'error' }),
    new winston.transports.File({ filename: 'combined.log' })
  ]
});

// Structured log entries
logger.info('User login', {
  userId: user.id,
  email: user.email,
  ip: req.ip,
  userAgent: req.get('User-Agent'),
  timestamp: new Date().toISOString()
});
```

**✅ DO: Log security events**
```typescript
// Security event logging
const logSecurityEvent = (event: string, details: any) => {
  logger.warn('Security event', {
    event,
    ...details,
    severity: 'high',
    category: 'security'
  });
};

// Usage
logSecurityEvent('failed_login_attempt', {
  email: req.body.email,
  ip: req.ip,
  userAgent: req.get('User-Agent')
});
```

### 2. Performance Monitoring

**✅ DO: Monitor response times**
```typescript
// Response time middleware
const responseTimeLogger = (req: Request, res: Response, next: NextFunction) => {
  const start = Date.now();
  
  res.on('finish', () => {
    const duration = Date.now() - start;
    
    logger.info('HTTP request', {
      method: req.method,
      url: req.url,
      statusCode: res.statusCode,
      responseTime: duration,
      contentLength: res.get('Content-Length')
    });
    
    // Alert on slow requests
    if (duration > 1000) {
      logger.warn('Slow request detected', {
        method: req.method,
        url: req.url,
        responseTime: duration
      });
    }
  });
  
  next();
};
```

## 🧪 Testing Best Practices

### 1. Test Structure

**✅ DO: Follow the testing pyramid**
```typescript
// Unit tests (70%)
describe('UserService', () => {
  let userService: UserService;
  let mockUserRepository: jest.Mocked<UserRepository>;
  
  beforeEach(() => {
    mockUserRepository = {
      findByEmail: jest.fn(),
      create: jest.fn()
    } as any;
    
    userService = new UserService(mockUserRepository);
  });
  
  it('should create user with valid data', async () => {
    mockUserRepository.findByEmail.mockResolvedValue(null);
    mockUserRepository.create.mockResolvedValue(mockUser);
    
    const result = await userService.createUser(validUserData);
    
    expect(result).toEqual(expectedUser);
    expect(mockUserRepository.create).toHaveBeenCalledWith(validUserData);
  });
});

// Integration tests (25%)
describe('User API Integration', () => {
  let app: Application;
  
  beforeAll(async () => {
    app = createTestApp();
    await setupTestDatabase();
  });
  
  it('should create user via API', async () => {
    const response = await request(app)
      .post('/api/users')
      .send(validUserData)
      .expect(201);
      
    expect(response.body.data).toHaveProperty('id');
    expect(response.body.data.email).toBe(validUserData.email);
  });
});

// E2E tests (5%)
describe('User Registration Flow', () => {
  it('should complete registration process', async () => {
    await page.goto('/register');
    await page.fill('[data-testid=email]', 'test@example.com');
    await page.fill('[data-testid=password]', 'SecurePass123!');
    await page.click('[data-testid=submit]');
    
    await expect(page).toHaveURL('/dashboard');
  });
});
```

### 2. Test Data Management

**✅ DO: Use factories for test data**
```typescript
// Test data factory
class UserFactory {
  static create(overrides: Partial<User> = {}): User {
    return {
      id: faker.datatype.uuid(),
      email: faker.internet.email(),
      firstName: faker.name.firstName(),
      lastName: faker.name.lastName(),
      createdAt: faker.date.recent(),
      ...overrides
    };
  }
  
  static createMany(count: number, overrides: Partial<User> = {}): User[] {
    return Array.from({ length: count }, () => this.create(overrides));
  }
}
```

## 🔧 Development Best Practices

### 1. Code Quality

**✅ DO: Use TypeScript strict mode**
```json
// tsconfig.json
{
  "compilerOptions": {
    "strict": true,
    "noImplicitAny": true,
    "noImplicitReturns": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true
  }
}
```

**✅ DO: Implement comprehensive linting**
```json
// .eslintrc.js
module.exports = {
  extends: [
    '@typescript-eslint/recommended',
    'prettier'
  ],
  rules: {
    '@typescript-eslint/no-unused-vars': 'error',
    '@typescript-eslint/explicit-function-return-type': 'warn',
    'prefer-const': 'error',
    'no-var': 'error'
  }
};
```

### 2. Git Workflow

**✅ DO: Use conventional commits**
```bash
# Commit message format
feat: add user registration endpoint
fix: resolve password validation issue
docs: update API documentation
test: add integration tests for auth
refactor: extract user service logic
```

**✅ DO: Implement pre-commit hooks**
```json
// package.json
{
  "husky": {
    "hooks": {
      "pre-commit": "lint-staged",
      "commit-msg": "commitlint -E HUSKY_GIT_PARAMS"
    }
  },
  "lint-staged": {
    "*.{ts,js}": ["eslint --fix", "prettier --write"],
    "*.{json,md}": ["prettier --write"]
  }
}
```

## 🚀 Deployment Best Practices

### 1. Environment Configuration

**✅ DO: Use environment-specific configs**
```yaml
# docker-compose.production.yml
version: '3.8'
services:
  app:
    image: myapp:latest
    environment:
      - NODE_ENV=production
      - LOG_LEVEL=warn
      - ENABLE_METRICS=true
    deploy:
      replicas: 3
      resources:
        limits:
          memory: 512M
          cpus: '0.5'
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
```

### 2. Security Hardening

**✅ DO: Run as non-root user**
```dockerfile
# Dockerfile
FROM node:18-alpine

# Create non-root user
RUN addgroup -g 1001 -S nodejs
RUN adduser -S expressjs -u 1001

# Copy and set ownership
COPY --chown=expressjs:nodejs . .

# Switch to non-root user
USER expressjs

EXPOSE 3000
CMD ["node", "dist/index.js"]
```

### 3. Monitoring & Observability

**✅ DO: Implement health checks**
```typescript
// Health check endpoint
app.get('/health', async (req, res) => {
  const health = {
    status: 'healthy',
    timestamp: new Date().toISOString(),
    version: process.env.npm_package_version,
    checks: {
      database: false,
      redis: false,
      memory: false
    }
  };
  
  try {
    // Database check
    await database.query('SELECT 1');
    health.checks.database = true;
    
    // Redis check
    await redis.ping();
    health.checks.redis = true;
    
    // Memory check
    const usage = process.memoryUsage();
    health.checks.memory = usage.heapUsed < 500 * 1024 * 1024; // < 500MB
    
    const isHealthy = Object.values(health.checks).every(check => check);
    
    res.status(isHealthy ? 200 : 503).json(health);
  } catch (error) {
    health.status = 'unhealthy';
    res.status(503).json(health);
  }
});
```

## ❌ Common Anti-Patterns to Avoid

### 1. Security Anti-Patterns

**❌ DON'T: Store secrets in code**
```typescript
// BAD
const JWT_SECRET = 'my-super-secret-key'; // ❌ Hardcoded secret
const API_KEY = 'sk-1234567890'; // ❌ Exposed API key
```

**❌ DON'T: Use weak authentication**
```typescript
// BAD
const isAuthenticated = req.headers.authorization === 'Bearer admin'; // ❌ Weak auth
```

### 2. Performance Anti-Patterns

**❌ DON'T: Perform N+1 queries**
```typescript
// BAD - N+1 query problem
const getUsers = async () => {
  const users = await User.findAll(); // 1 query
  for (const user of users) {
    user.posts = await Post.findByUserId(user.id); // N queries
  }
  return users;
};

// GOOD - Use joins or batch loading
const getUsersWithPosts = async () => {
  return User.findAll({
    include: [{ model: Post }] // 1 query with join
  });
};
```

**❌ DON'T: Block the event loop**
```typescript
// BAD - Blocking operation
const processData = (data: any[]) => {
  const result = [];
  for (let i = 0; i < 1000000; i++) { // ❌ Blocks event loop
    result.push(heavyCalculation(data[i]));
  }
  return result;
};

// GOOD - Use worker threads or chunking
const processDataAsync = async (data: any[]) => {
  const chunks = chunkArray(data, 1000);
  const results = [];
  
  for (const chunk of chunks) {
    const chunkResult = await processChunk(chunk);
    results.push(...chunkResult);
    await new Promise(resolve => setImmediate(resolve)); // Yield control
  }
  
  return results;
};
```

### 3. Code Organization Anti-Patterns

**❌ DON'T: Create god objects**
```typescript
// BAD - God class with too many responsibilities
class UserManager {
  async createUser() { /* ... */ }
  async authenticateUser() { /* ... */ }
  async sendEmail() { /* ... */ }
  async processPayment() { /* ... */ }
  async generateReport() { /* ... */ }
  // ... 50 more methods
}

// GOOD - Single responsibility principle
class UserService {
  async createUser() { /* ... */ }
  async updateUser() { /* ... */ }
}

class AuthService {
  async authenticateUser() { /* ... */ }
  async generateToken() { /* ... */ }
}
```

## 📋 Production Checklist

### Security Checklist
- [ ] All inputs validated and sanitized
- [ ] SQL injection protection implemented
- [ ] XSS protection enabled
- [ ] CSRF protection configured
- [ ] Rate limiting implemented
- [ ] Authentication/authorization working
- [ ] Secrets stored securely
- [ ] HTTPS enforced
- [ ] Security headers configured

### Performance Checklist
- [ ] Database queries optimized
- [ ] Indexes created for frequent queries
- [ ] Connection pooling implemented
- [ ] Caching strategy in place
- [ ] Response compression enabled
- [ ] Static assets optimized
- [ ] Memory leaks checked
- [ ] Load testing completed

### Monitoring Checklist
- [ ] Structured logging implemented
- [ ] Error tracking configured
- [ ] Performance monitoring setup
- [ ] Health checks working
- [ ] Alerts configured
- [ ] Metrics collection enabled
- [ ] Log rotation configured

### Deployment Checklist
- [ ] Environment variables configured
- [ ] Database migrations tested
- [ ] Docker images optimized
- [ ] Graceful shutdown implemented
- [ ] Zero-downtime deployment tested
- [ ] Rollback strategy planned
- [ ] Documentation updated

---

## 🔗 Navigation

**Previous**: [Implementation Guide](./implementation-guide.md) | **Next**: [Comparison Analysis](./comparison-analysis.md)

---

## 📚 References

1. [Express.js Security Best Practices](https://expressjs.com/en/advanced/best-practice-security.html)
2. [Node.js Best Practices](https://github.com/goldbergyoni/nodebestpractices)
3. [OWASP Node.js Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Nodejs_Security_Cheat_Sheet.html)
4. [TypeScript Best Practices](https://typescript-eslint.io/rules/)
5. [Testing Best Practices](https://github.com/goldbergyoni/javascript-testing-best-practices)
6. [Docker Security Best Practices](https://docs.docker.com/develop/security-best-practices/)
7. [PostgreSQL Performance Tips](https://www.postgresql.org/docs/current/performance-tips.html)
8. [Redis Best Practices](https://redis.io/docs/manual/clients-guide/)
9. [Logging Best Practices](https://www.dataset.com/blog/the-10-commandments-of-logging/)
10. [API Design Best Practices](https://docs.microsoft.com/en-us/azure/architecture/best-practices/api-design)