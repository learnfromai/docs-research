# Best Practices for Production NestJS Applications

## 🎯 Overview

Comprehensive best practices extracted from 23+ production NestJS projects, covering code organization, security, performance, testing, and operational excellence. These practices are battle-tested in real-world applications handling millions of users.

---

## 🏗️ Project Structure & Organization

### 1. Feature-Based Module Organization

**✅ Recommended Structure**:
```
src/
├── modules/                    # Feature modules
│   ├── auth/                  # Authentication feature
│   │   ├── controllers/
│   │   ├── services/
│   │   ├── guards/
│   │   ├── strategies/
│   │   ├── dto/
│   │   ├── entities/
│   │   ├── tests/
│   │   └── auth.module.ts
│   ├── users/                 # User management
│   └── products/              # Product management
├── common/                    # Shared utilities
│   ├── decorators/
│   ├── guards/
│   ├── interceptors/
│   ├── pipes/
│   ├── filters/
│   └── interfaces/
├── config/                    # Configuration
│   ├── database.config.ts
│   ├── cache.config.ts
│   └── app.config.ts
├── database/                  # Database-related
│   ├── migrations/
│   ├── seeds/
│   └── factories/
└── utils/                     # Pure functions
```

**✅ Module Design Principles**:
```typescript
@Module({
  imports: [
    TypeOrmModule.forFeature([User, UserProfile]),
    // Only import what you need
  ],
  controllers: [UsersController],
  providers: [
    UsersService,
    UserRepository,
    // Use interfaces for dependencies
    {
      provide: 'USER_REPOSITORY',
      useClass: TypeOrmUserRepository,
    },
  ],
  exports: [
    UsersService, // Export only public interfaces
  ],
})
export class UsersModule {}
```

### 2. Consistent Naming Conventions

**✅ File Naming**:
```
users.controller.ts        # Controllers
users.service.ts          # Services
users.repository.ts       # Repositories
create-user.dto.ts        # DTOs
user.entity.ts           # Entities
users.module.ts          # Modules
users.controller.spec.ts  # Tests
```

**✅ Class Naming**:
```typescript
// Controllers: Feature + Controller
export class UsersController {}

// Services: Feature + Service
export class UsersService {}

// DTOs: Action + Feature + Dto
export class CreateUserDto {}
export class UpdateUserDto {}
export class UserResponseDto {}

// Entities: Singular noun
export class User {}

// Interfaces: I + Description
export interface IUserRepository {}
```

---

## 🔒 Security Best Practices

### 1. Input Validation & Sanitization

**✅ Comprehensive Validation**:
```typescript
export class CreateUserDto {
  @IsEmail()
  @IsNotEmpty()
  @Transform(({ value }) => value.toLowerCase().trim())
  @MaxLength(255)
  email: string;

  @IsString()
  @IsNotEmpty()
  @Length(8, 128)
  @Matches(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])/, {
    message: 'Password must contain uppercase, lowercase, number and special character',
  })
  password: string;

  @IsOptional()
  @IsString()
  @Length(1, 50)
  @Matches(/^[a-zA-Z\s'-]+$/, {
    message: 'First name can only contain letters, spaces, hyphens, and apostrophes',
  })
  @Transform(({ value }) => value?.trim())
  firstName?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  @Transform(({ value }) => sanitizeHtml(value, {
    allowedTags: [],
    allowedAttributes: {},
  }))
  bio?: string;
}
```

**✅ Global Validation Setup**:
```typescript
app.useGlobalPipes(
  new ValidationPipe({
    whitelist: true, // Strip unknown properties
    forbidNonWhitelisted: true, // Throw error for unknown properties
    transform: true, // Auto-transform to DTO classes
    disableErrorMessages: process.env.NODE_ENV === 'production',
    transformOptions: {
      enableImplicitConversion: true,
    },
  }),
);
```

### 2. Authentication & Authorization

**✅ JWT Best Practices**:
```typescript
@Injectable()
export class AuthService {
  private readonly accessTokenExpiry = '15m';
  private readonly refreshTokenExpiry = '7d';

  async login(user: User): Promise<LoginResponse> {
    const tokens = await this.generateTokens(user);
    
    // Store refresh token hash (never store plain text)
    const refreshTokenHash = await bcrypt.hash(tokens.refreshToken, 10);
    await this.userService.updateRefreshToken(user.id, refreshTokenHash);

    return {
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      expiresIn: 900, // 15 minutes in seconds
    };
  }

  private async generateTokens(user: User): Promise<Tokens> {
    const payload = {
      sub: user.id,
      email: user.email,
      roles: user.roles,
      // Don't include sensitive data
    };

    const [accessToken, refreshToken] = await Promise.all([
      this.jwtService.signAsync(payload, {
        secret: this.configService.get('JWT_ACCESS_SECRET'),
        expiresIn: this.accessTokenExpiry,
      }),
      this.jwtService.signAsync(
        { sub: user.id },
        {
          secret: this.configService.get('JWT_REFRESH_SECRET'),
          expiresIn: this.refreshTokenExpiry,
        },
      ),
    ]);

    return { accessToken, refreshToken };
  }
}
```

**✅ Role-Based Access Control**:
```typescript
// Flexible role system
export enum Permission {
  CREATE_USER = 'create:user',
  READ_USER = 'read:user',
  UPDATE_USER = 'update:user',
  DELETE_USER = 'delete:user',
  READ_ADMIN = 'read:admin',
}

@Injectable()
export class PermissionGuard implements CanActivate {
  constructor(private reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const requiredPermissions = this.reflector.getAllAndOverride<Permission[]>(
      'permissions',
      [context.getHandler(), context.getClass()],
    );

    if (!requiredPermissions) {
      return true;
    }

    const { user } = context.switchToHttp().getRequest();
    
    return requiredPermissions.every((permission) =>
      user.permissions?.includes(permission),
    );
  }
}

// Usage
@Post()
@RequirePermissions(Permission.CREATE_USER)
@UseGuards(JwtAuthGuard, PermissionGuard)
async createUser(@Body() dto: CreateUserDto) {
  return this.userService.create(dto);
}
```

### 3. Rate Limiting & Throttling

**✅ Multi-Layer Rate Limiting**:
```typescript
// Global rate limiting
app.use(rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 1000, // limit each IP to 1000 requests per windowMs
  message: 'Too many requests from this IP',
  standardHeaders: true,
  legacyHeaders: false,
}));

// Specific endpoint throttling
@Controller('auth')
export class AuthController {
  @Post('login')
  @Throttle(5, 60) // 5 attempts per minute
  async login(@Body() loginDto: LoginDto) {
    return this.authService.login(loginDto);
  }

  @Post('register')
  @Throttle(3, 300) // 3 registrations per 5 minutes
  async register(@Body() registerDto: RegisterDto) {
    return this.authService.register(registerDto);
  }
}
```

---

## 🚀 Performance Best Practices

### 1. Database Optimization

**✅ Connection Pool Configuration**:
```typescript
@Module({
  imports: [
    TypeOrmModule.forRootAsync({
      imports: [ConfigModule],
      useFactory: (config: ConfigService) => ({
        type: 'postgres',
        url: config.get('DATABASE_URL'),
        entities: [__dirname + '/**/*.entity{.ts,.js}'],
        synchronize: false, // Never use in production
        migrations: [__dirname + '/migrations/*{.ts,.js}'],
        migrationsRun: true,
        logging: config.get('NODE_ENV') === 'development',
        extra: {
          // Connection pool settings
          max: 20, // Maximum connections
          min: 5,  // Minimum connections
          idle: 10000, // Connection idle timeout
          acquire: 30000, // Connection acquire timeout
          evict: 1000, // Connection eviction interval
        },
      }),
      inject: [ConfigService],
    }),
  ],
})
export class DatabaseModule {}
```

**✅ Query Optimization**:
```typescript
@Injectable()
export class UserRepository {
  constructor(
    @InjectRepository(User)
    private repository: Repository<User>,
  ) {}

  // Use specific select instead of SELECT *
  async findActiveUsers(): Promise<User[]> {
    return this.repository.find({
      select: ['id', 'email', 'firstName', 'lastName', 'isActive'],
      where: { isActive: true },
      order: { createdAt: 'DESC' },
      take: 100, // Always limit results
    });
  }

  // Use joins efficiently
  async findUserWithProfile(id: string): Promise<User> {
    return this.repository.findOne({
      where: { id },
      relations: ['profile'], // Only load what you need
    });
  }

  // Use pagination for large datasets
  async findUsers(
    page: number = 1,
    limit: number = 20,
  ): Promise<PaginatedResult<User>> {
    const [users, total] = await this.repository.findAndCount({
      skip: (page - 1) * limit,
      take: limit,
      order: { createdAt: 'DESC' },
    });

    return {
      data: users,
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit),
    };
  }
}
```

### 2. Caching Strategies

**✅ Multi-Level Caching**:
```typescript
@Injectable()
export class UserService {
  constructor(
    private userRepository: UserRepository,
    @Inject(CACHE_MANAGER) private cacheManager: Cache,
  ) {}

  async findById(id: string): Promise<User> {
    const cacheKey = `user:${id}`;
    
    // Level 1: Memory cache (fastest)
    const cached = await this.cacheManager.get<User>(cacheKey);
    if (cached) {
      return cached;
    }

    // Level 2: Database
    const user = await this.userRepository.findById(id);
    
    if (user) {
      // Cache for 5 minutes
      await this.cacheManager.set(cacheKey, user, 300);
    }
    
    return user;
  }

  async updateUser(id: string, data: UpdateUserDto): Promise<User> {
    const user = await this.userRepository.update(id, data);
    
    // Invalidate cache on update
    await this.cacheManager.del(`user:${id}`);
    
    return user;
  }

  // Cache expensive operations
  @Cacheable('user-stats', 3600) // 1 hour cache
  async getUserStats(): Promise<UserStats> {
    return this.userRepository.calculateStats();
  }
}
```

### 3. Response Optimization

**✅ Compression & Headers**:
```typescript
// Enable compression
app.use(compression({
  level: 6,
  threshold: 1000, // Only compress responses > 1KB
  filter: (req, res) => {
    if (req.headers['x-no-compression']) {
      return false;
    }
    return compression.filter(req, res);
  },
}));

// Response interceptor for optimization
@Injectable()
export class ResponseInterceptor implements NestInterceptor {
  intercept(context: ExecutionContext, next: CallHandler): Observable<any> {
    const response = context.switchToHttp().getResponse();
    
    // Set security headers
    response.setHeader('X-Content-Type-Options', 'nosniff');
    response.setHeader('X-Frame-Options', 'DENY');
    response.setHeader('X-XSS-Protection', '1; mode=block');
    
    return next.handle().pipe(
      map((data) => {
        // Transform response data
        if (Array.isArray(data)) {
          return {
            data,
            count: data.length,
            timestamp: new Date().toISOString(),
          };
        }
        return data;
      }),
    );
  }
}
```

---

## 🧪 Testing Best Practices

### 1. Test Structure & Organization

**✅ Test File Organization**:
```
src/
├── modules/
│   └── users/
│       ├── users.controller.ts
│       ├── users.service.ts
│       └── tests/
│           ├── users.controller.spec.ts
│           ├── users.service.spec.ts
│           ├── users.e2e.spec.ts
│           └── fixtures/
│               ├── user.factory.ts
│               └── user.data.ts
```

**✅ Test Factories & Fixtures**:
```typescript
// User factory
export class UserFactory {
  static create(overrides: Partial<User> = {}): User {
    return {
      id: faker.datatype.uuid(),
      email: faker.internet.email(),
      firstName: faker.name.firstName(),
      lastName: faker.name.lastName(),
      password: faker.internet.password(),
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

// Test data
export const testUsers = {
  valid: UserFactory.create({
    email: 'test@example.com',
    firstName: 'John',
    lastName: 'Doe',
  }),
  admin: UserFactory.create({
    email: 'admin@example.com',
    roles: [Role.ADMIN],
  }),
  inactive: UserFactory.create({
    isActive: false,
  }),
};
```

### 2. Unit Testing Patterns

**✅ Service Testing**:
```typescript
describe('UserService', () => {
  let service: UserService;
  let repository: jest.Mocked<UserRepository>;
  let cacheManager: jest.Mocked<Cache>;

  beforeEach(async () => {
    const mockRepository = {
      findById: jest.fn(),
      save: jest.fn(),
      update: jest.fn(),
    };

    const mockCacheManager = {
      get: jest.fn(),
      set: jest.fn(),
      del: jest.fn(),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        UserService,
        { provide: 'USER_REPOSITORY', useValue: mockRepository },
        { provide: CACHE_MANAGER, useValue: mockCacheManager },
      ],
    }).compile();

    service = module.get<UserService>(UserService);
    repository = module.get('USER_REPOSITORY');
    cacheManager = module.get(CACHE_MANAGER);
  });

  describe('findById', () => {
    it('should return cached user when available', async () => {
      // Arrange
      const userId = 'test-id';
      const cachedUser = testUsers.valid;
      cacheManager.get.mockResolvedValue(cachedUser);

      // Act
      const result = await service.findById(userId);

      // Assert
      expect(result).toEqual(cachedUser);
      expect(cacheManager.get).toHaveBeenCalledWith(`user:${userId}`);
      expect(repository.findById).not.toHaveBeenCalled();
    });

    it('should fetch from repository and cache when not in cache', async () => {
      // Arrange
      const userId = 'test-id';
      const user = testUsers.valid;
      cacheManager.get.mockResolvedValue(null);
      repository.findById.mockResolvedValue(user);

      // Act
      const result = await service.findById(userId);

      // Assert
      expect(result).toEqual(user);
      expect(repository.findById).toHaveBeenCalledWith(userId);
      expect(cacheManager.set).toHaveBeenCalledWith(`user:${userId}`, user, 300);
    });
  });
});
```

### 3. Integration Testing

**✅ E2E Testing with Test Containers**:
```typescript
describe('Users API (e2e)', () => {
  let app: INestApplication;
  let container: StartedPostgreSqlContainer;
  let jwtToken: string;

  beforeAll(async () => {
    // Start PostgreSQL container
    container = await new PostgreSqlContainer('postgres:15')
      .withDatabase('testdb')
      .withUsername('testuser')
      .withPassword('testpass')
      .start();

    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [
        ConfigModule.forRoot({
          load: [() => ({
            DATABASE_URL: container.getConnectionUri(),
          })],
        }),
        DatabaseModule,
        UsersModule,
        AuthModule,
      ],
    }).compile();

    app = moduleFixture.createNestApplication();
    
    // Apply global pipes and filters
    app.useGlobalPipes(new ValidationPipe({ whitelist: true }));
    app.useGlobalFilters(new HttpExceptionFilter());
    
    await app.init();

    // Setup test user and get JWT token
    jwtToken = await createTestUserAndGetToken(app);
  });

  afterAll(async () => {
    await app.close();
    await container.stop();
  });

  describe('POST /users', () => {
    it('should create a new user', async () => {
      const createUserDto = {
        email: 'newuser@example.com',
        password: 'SecurePass123!',
        firstName: 'New',
        lastName: 'User',
      };

      const response = await request(app.getHttpServer())
        .post('/users')
        .set('Authorization', `Bearer ${jwtToken}`)
        .send(createUserDto)
        .expect(201);

      expect(response.body).toMatchObject({
        email: createUserDto.email,
        firstName: createUserDto.firstName,
        lastName: createUserDto.lastName,
      });
      expect(response.body.password).toBeUndefined();
      expect(response.body.id).toBeDefined();
    });

    it('should return validation error for invalid email', async () => {
      const invalidDto = {
        email: 'invalid-email',
        password: 'SecurePass123!',
      };

      await request(app.getHttpServer())
        .post('/users')
        .set('Authorization', `Bearer ${jwtToken}`)
        .send(invalidDto)
        .expect(400)
        .expect((res) => {
          expect(res.body.message).toContain('email must be an email');
        });
    });
  });
});
```

---

## 📊 Error Handling & Logging

### 1. Centralized Error Handling

**✅ Global Exception Filter**:
```typescript
@Catch()
export class GlobalExceptionFilter implements ExceptionFilter {
  private readonly logger = new Logger(GlobalExceptionFilter.name);

  catch(exception: unknown, host: ArgumentsHost): void {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();

    let status = HttpStatus.INTERNAL_SERVER_ERROR;
    let message = 'Internal server error';
    let code = 'INTERNAL_SERVER_ERROR';

    if (exception instanceof HttpException) {
      status = exception.getStatus();
      const exceptionResponse = exception.getResponse();
      
      if (typeof exceptionResponse === 'object') {
        message = (exceptionResponse as any).message || exception.message;
        code = (exceptionResponse as any).error || exception.constructor.name;
      } else {
        message = exceptionResponse;
      }
    } else if (exception instanceof Error) {
      message = exception.message;
      code = exception.constructor.name;
    }

    const errorResponse = {
      statusCode: status,
      timestamp: new Date().toISOString(),
      path: request.url,
      method: request.method,
      message,
      code,
      ...(process.env.NODE_ENV === 'development' && {
        stack: exception instanceof Error ? exception.stack : undefined,
      }),
    };

    // Log error
    this.logger.error(
      `${request.method} ${request.url}`,
      JSON.stringify(errorResponse),
      exception instanceof Error ? exception.stack : 'Unknown',
    );

    response.status(status).json(errorResponse);
  }
}
```

### 2. Structured Logging

**✅ Logger Configuration**:
```typescript
@Injectable()
export class AppLogger {
  private logger: Logger;

  constructor() {
    this.logger = new Logger('Application');
  }

  logRequest(request: Request, response: Response, responseTime: number): void {
    const logData = {
      method: request.method,
      url: request.url,
      statusCode: response.statusCode,
      responseTime: `${responseTime}ms`,
      userAgent: request.get('User-Agent'),
      ip: request.ip,
      userId: (request as any).user?.id,
    };

    if (response.statusCode >= 400) {
      this.logger.error('HTTP Error', JSON.stringify(logData));
    } else {
      this.logger.log('HTTP Request', JSON.stringify(logData));
    }
  }

  logBusinessEvent(event: string, data: any, userId?: string): void {
    const logData = {
      event,
      timestamp: new Date().toISOString(),
      userId,
      data,
    };

    this.logger.log('Business Event', JSON.stringify(logData));
  }

  logSecurityEvent(event: string, details: any): void {
    const logData = {
      securityEvent: event,
      timestamp: new Date().toISOString(),
      ...details,
    };

    this.logger.warn('Security Event', JSON.stringify(logData));
  }
}
```

---

## 🔧 Configuration Management

### 1. Environment-Specific Configuration

**✅ Type-Safe Configuration**:
```typescript
export interface DatabaseConfig {
  host: string;
  port: number;
  username: string;
  password: string;
  database: string;
  ssl: boolean;
}

export interface AppConfig {
  port: number;
  environment: 'development' | 'production' | 'test';
  database: DatabaseConfig;
  jwt: {
    accessSecret: string;
    refreshSecret: string;
    accessExpiration: string;
    refreshExpiration: string;
  };
  redis: {
    host: string;
    port: number;
    password?: string;
  };
}

export const configuration = (): AppConfig => ({
  port: parseInt(process.env.PORT, 10) || 3000,
  environment: process.env.NODE_ENV as any || 'development',
  database: {
    host: process.env.DB_HOST || 'localhost',
    port: parseInt(process.env.DB_PORT, 10) || 5432,
    username: process.env.DB_USERNAME || 'postgres',
    password: process.env.DB_PASSWORD || 'password',
    database: process.env.DB_NAME || 'app',
    ssl: process.env.DB_SSL === 'true',
  },
  jwt: {
    accessSecret: process.env.JWT_ACCESS_SECRET,
    refreshSecret: process.env.JWT_REFRESH_SECRET,
    accessExpiration: process.env.JWT_ACCESS_EXPIRATION || '15m',
    refreshExpiration: process.env.JWT_REFRESH_EXPIRATION || '7d',
  },
  redis: {
    host: process.env.REDIS_HOST || 'localhost',
    port: parseInt(process.env.REDIS_PORT, 10) || 6379,
    password: process.env.REDIS_PASSWORD,
  },
});

// Validation schema
export const validationSchema = Joi.object({
  NODE_ENV: Joi.string()
    .valid('development', 'production', 'test')
    .default('development'),
  PORT: Joi.number().default(3000),
  DB_HOST: Joi.string().required(),
  DB_PORT: Joi.number().default(5432),
  DB_USERNAME: Joi.string().required(),
  DB_PASSWORD: Joi.string().required(),
  DB_NAME: Joi.string().required(),
  JWT_ACCESS_SECRET: Joi.string().required(),
  JWT_REFRESH_SECRET: Joi.string().required(),
});
```

---

## 🚀 Deployment Best Practices

### 1. Docker Configuration

**✅ Production Dockerfile**:
```dockerfile
# Multi-stage build for production
FROM node:18-alpine AS dependencies
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force

FROM node:18-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM node:18-alpine AS production
WORKDIR /app

# Create non-root user
RUN addgroup -g 1001 -S nodejs
RUN adduser -S nestjs -u 1001

# Copy built application
COPY --from=dependencies /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
COPY --from=build /app/package*.json ./

# Security improvements
RUN chown -R nestjs:nodejs /app
USER nestjs

EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1

CMD ["node", "dist/main.js"]
```

### 2. Health Checks & Monitoring

**✅ Health Check Implementation**:
```typescript
@Controller('health')
export class HealthController {
  constructor(
    private health: HealthCheckService,
    private db: TypeOrmHealthIndicator,
    private redis: RedisHealthIndicator,
    private memory: MemoryHealthIndicator,
    private disk: DiskHealthIndicator,
  ) {}

  @Get()
  @HealthCheck()
  check() {
    return this.health.check([
      // Database connectivity
      () => this.db.pingCheck('database'),
      
      // Redis connectivity
      () => this.redis.checkHealth('redis'),
      
      // Memory usage (< 90%)
      () => this.memory.checkHeap('memory_heap', 150 * 1024 * 1024),
      
      // Disk space (< 90%)
      () => this.disk.checkStorage('storage', {
        path: '/',
        thresholdPercent: 0.9,
      }),
    ]);
  }

  @Get('ready')
  @HealthCheck()
  readiness() {
    return this.health.check([
      () => this.db.pingCheck('database'),
    ]);
  }

  @Get('live')
  liveness() {
    return { status: 'ok' };
  }
}
```

---

## 📈 Performance Monitoring

### 1. Metrics Collection

**✅ Prometheus Metrics**:
```typescript
@Injectable()
export class MetricsService {
  private httpRequestDuration: prometheus.Histogram<string>;
  private httpRequestTotal: prometheus.Counter<string>;
  private activeConnections: prometheus.Gauge<string>;

  constructor() {
    // HTTP request duration
    this.httpRequestDuration = new prometheus.Histogram({
      name: 'http_request_duration_seconds',
      help: 'Duration of HTTP requests in seconds',
      labelNames: ['method', 'route', 'status_code'],
      buckets: [0.1, 0.5, 1, 2, 5],
    });

    // HTTP request count
    this.httpRequestTotal = new prometheus.Counter({
      name: 'http_requests_total',
      help: 'Total number of HTTP requests',
      labelNames: ['method', 'route', 'status_code'],
    });

    // Active connections
    this.activeConnections = new prometheus.Gauge({
      name: 'active_connections',
      help: 'Number of active connections',
    });

    // Register metrics
    prometheus.register.registerMetric(this.httpRequestDuration);
    prometheus.register.registerMetric(this.httpRequestTotal);
    prometheus.register.registerMetric(this.activeConnections);
  }

  recordHttpRequest(method: string, route: string, statusCode: number, duration: number): void {
    this.httpRequestDuration
      .labels(method, route, statusCode.toString())
      .observe(duration);
    
    this.httpRequestTotal
      .labels(method, route, statusCode.toString())
      .inc();
  }

  setActiveConnections(count: number): void {
    this.activeConnections.set(count);
  }
}
```

---

## 🎯 Best Practices Summary

### Security Checklist
- ✅ Use strong password policies and hashing
- ✅ Implement JWT with short expiration times
- ✅ Add rate limiting on sensitive endpoints
- ✅ Validate and sanitize all inputs
- ✅ Use HTTPS in production
- ✅ Implement proper CORS configuration
- ✅ Add security headers with Helmet
- ✅ Log security events for monitoring

### Performance Checklist
- ✅ Use connection pooling for databases
- ✅ Implement multi-level caching
- ✅ Add pagination for large datasets
- ✅ Use compression for responses
- ✅ Optimize database queries and indexes
- ✅ Monitor and log performance metrics
- ✅ Use CDN for static assets
- ✅ Implement graceful shutdowns

### Code Quality Checklist
- ✅ Use TypeScript strict mode
- ✅ Implement comprehensive testing (80%+ coverage)
- ✅ Use consistent naming conventions
- ✅ Add proper error handling
- ✅ Document APIs with Swagger
- ✅ Use linting and formatting tools
- ✅ Implement CI/CD pipelines
- ✅ Regular dependency updates

### Operational Checklist
- ✅ Use Docker for containerization
- ✅ Implement health checks
- ✅ Add structured logging
- ✅ Monitor application metrics
- ✅ Set up alerting for issues
- ✅ Plan for disaster recovery
- ✅ Regular security audits
- ✅ Performance testing

---

**Navigation**
- ← Previous: [Tool Ecosystem](./tool-ecosystem.md)
- → Next: [Implementation Guide](./implementation-guide.md)
- ↑ Back to: [Main Overview](./README.md)