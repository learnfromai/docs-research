# Best Practices Guide: Production-Ready NestJS Applications

This comprehensive guide compiles best practices extracted from analysis of 30+ production NestJS applications, providing actionable recommendations for building secure, scalable, and maintainable applications.

## 🏗️ Project Structure & Architecture

### 1. Recommended Directory Structure

Based on analysis of top-rated projects, this structure balances organization and scalability:

```
src/
├── modules/                    # Feature modules
│   ├── auth/
│   │   ├── dto/               # Data transfer objects
│   │   ├── entities/          # Database entities
│   │   ├── guards/            # Custom guards
│   │   ├── strategies/        # Passport strategies
│   │   ├── auth.controller.ts
│   │   ├── auth.service.ts
│   │   ├── auth.module.ts
│   │   └── __tests__/         # Module-specific tests
│   ├── users/
│   ├── articles/
│   └── ...
├── shared/                     # Shared utilities
│   ├── decorators/            # Custom decorators
│   ├── filters/               # Exception filters
│   ├── guards/                # Global guards
│   ├── interceptors/          # Global interceptors
│   ├── pipes/                 # Custom pipes
│   ├── interfaces/            # TypeScript interfaces
│   ├── constants/             # Application constants
│   └── utils/                 # Utility functions
├── config/                     # Configuration management
│   ├── database.config.ts
│   ├── auth.config.ts
│   ├── cache.config.ts
│   └── app.config.ts
├── database/                   # Database-related files
│   ├── migrations/            # Database migrations
│   ├── seeds/                 # Database seeders
│   └── factories/             # Data factories for testing
├── common/                     # Common application-wide code
│   ├── enums/                 # Enums and constants
│   ├── types/                 # TypeScript type definitions
│   └── validators/            # Custom validators
├── app.module.ts              # Root module
├── main.ts                    # Application entry point
└── health/                    # Health check endpoints
```

### 2. Module Organization Principles

#### ✅ Feature-Based Modules
```typescript
// ✅ Good: Feature-based organization
@Module({
  imports: [
    TypeOrmModule.forFeature([User, UserProfile]),
    forwardRef(() => AuthModule),
  ],
  controllers: [UsersController],
  providers: [
    UsersService,
    UsersRepository,
    UserProfileService,
    {
      provide: 'USER_REPOSITORY',
      useClass: TypeOrmUserRepository,
    },
  ],
  exports: [UsersService, 'USER_REPOSITORY'],
})
export class UsersModule {}
```

#### ❌ Avoid Layer-Based Organization
```typescript
// ❌ Avoid: Layer-based organization leads to tight coupling
@Module({
  imports: [AllControllersModule, AllServicesModule, AllRepositoriesModule],
})
export class AppModule {}
```

### 3. Dependency Injection Best Practices

#### Interface-Based Dependencies
```typescript
// Define interfaces for better testability
export interface IUserRepository {
  findById(id: string): Promise<User | null>;
  findByEmail(email: string): Promise<User | null>;
  create(user: CreateUserDto): Promise<User>;
  update(id: string, updates: Partial<User>): Promise<User>;
  delete(id: string): Promise<void>;
}

// Implementation
@Injectable()
export class TypeOrmUserRepository implements IUserRepository {
  constructor(
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
  ) {}

  async findById(id: string): Promise<User | null> {
    return this.userRepository.findOne({
      where: { id },
      relations: ['role', 'profile'],
    });
  }
}

// Service using interface
@Injectable()
export class UsersService {
  constructor(
    @Inject('USER_REPOSITORY')
    private readonly userRepository: IUserRepository,
  ) {}
}
```

#### Provider Configuration
```typescript
// ✅ Good: Explicit provider configuration
@Module({
  providers: [
    {
      provide: 'USER_REPOSITORY',
      useClass: TypeOrmUserRepository,
    },
    {
      provide: 'EMAIL_SERVICE',
      useFactory: (configService: ConfigService) => {
        const provider = configService.get('email.provider');
        return provider === 'sendgrid' 
          ? new SendGridEmailService(configService)
          : new SMTPEmailService(configService);
      },
      inject: [ConfigService],
    },
    {
      provide: 'CACHE_TTL',
      useValue: 3600,
    },
  ],
})
export class UsersModule {}
```

## 🔐 Security Best Practices

### 1. Authentication Implementation

#### JWT with Refresh Tokens
```typescript
@Injectable()
export class AuthService {
  private readonly JWT_ACCESS_EXPIRY = '15m';
  private readonly JWT_REFRESH_EXPIRY = '7d';

  async login(credentials: LoginDto): Promise<AuthResult> {
    const user = await this.validateCredentials(credentials);
    
    if (!user) {
      // Use timing-safe comparison to prevent timing attacks
      await bcrypt.compare('dummy-password', '$2b$12$dummy.hash');
      throw new UnauthorizedException('Invalid credentials');
    }

    const session = await this.sessionService.createSession(user.id);
    const tokens = await this.generateTokens(user, session.id);

    // Log successful authentication
    this.auditService.logAuthSuccess(user.id, this.getClientInfo());

    return {
      user: this.sanitizeUser(user),
      ...tokens,
    };
  }

  private async generateTokens(user: User, sessionId: string) {
    const payload = {
      sub: user.id,
      email: user.email,
      role: user.role.name,
      sessionId,
    };

    const [accessToken, refreshToken] = await Promise.all([
      this.jwtService.signAsync(payload, {
        expiresIn: this.JWT_ACCESS_EXPIRY,
        issuer: 'your-app-name',
        audience: 'your-app-users',
      }),
      this.jwtService.signAsync(
        { sessionId },
        {
          expiresIn: this.JWT_REFRESH_EXPIRY,
          secret: this.configService.get('JWT_REFRESH_SECRET'),
        },
      ),
    ]);

    return { accessToken, refreshToken };
  }

  private sanitizeUser(user: User): SafeUser {
    const { password, refreshToken, ...safeUser } = user;
    return safeUser;
  }
}
```

#### Password Security
```typescript
@Injectable()
export class PasswordService {
  private readonly BCRYPT_ROUNDS = 12;
  private readonly MIN_PASSWORD_STRENGTH = 3;

  async hashPassword(password: string): Promise<string> {
    // Validate password strength
    if (!this.isPasswordStrong(password)) {
      throw new BadRequestException('Password does not meet security requirements');
    }

    return bcrypt.hash(password, this.BCRYPT_ROUNDS);
  }

  async validatePassword(password: string, hash: string): Promise<boolean> {
    return bcrypt.compare(password, hash);
  }

  private isPasswordStrong(password: string): boolean {
    const strength = zxcvbn(password);
    return strength.score >= this.MIN_PASSWORD_STRENGTH;
  }

  generateSecurePassword(length: number = 16): string {
    const charset = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*';
    let password = '';
    
    for (let i = 0; i < length; i++) {
      const randomIndex = crypto.randomInt(0, charset.length);
      password += charset[randomIndex];
    }
    
    return password;
  }
}
```

### 2. Input Validation & Sanitization

#### Comprehensive DTO Validation
```typescript
export class CreateUserDto {
  @IsEmail()
  @IsNotEmpty()
  @Transform(({ value }) => value?.toLowerCase()?.trim())
  @MaxLength(255)
  email: string;

  @IsString()
  @MinLength(8)
  @MaxLength(128)
  @Matches(
    /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]/,
    { message: 'Password must contain uppercase, lowercase, number and special character' }
  )
  password: string;

  @IsString()
  @IsNotEmpty()
  @Transform(({ value }) => value?.trim())
  @Matches(/^[a-zA-ZÀ-ÿ\s]*$/, { message: 'Name can only contain letters and spaces' })
  @MaxLength(50)
  firstName: string;

  @IsString()
  @IsNotEmpty()
  @Transform(({ value }) => value?.trim())
  @Matches(/^[a-zA-ZÀ-ÿ\s]*$/, { message: 'Name can only contain letters and spaces' })
  @MaxLength(50)
  lastName: string;

  @IsOptional()
  @IsPhoneNumber()
  @Transform(({ value }) => value?.replace(/\s+/g, ''))
  phone?: string;

  @IsOptional()
  @IsDateString()
  @IsEighteenOrOlder()
  dateOfBirth?: string;
}

// Custom validator for age verification
export function IsEighteenOrOlder(validationOptions?: ValidationOptions) {
  return function (object: any, propertyName: string) {
    registerDecorator({
      name: 'isEighteenOrOlder',
      target: object.constructor,
      propertyName: propertyName,
      options: validationOptions,
      validator: {
        validate(value: any) {
          if (!value) return true; // Optional field
          const birthDate = new Date(value);
          const today = new Date();
          const age = today.getFullYear() - birthDate.getFullYear();
          const monthDiff = today.getMonth() - birthDate.getMonth();
          
          if (monthDiff < 0 || (monthDiff === 0 && today.getDate() < birthDate.getDate())) {
            age--;
          }
          
          return age >= 18;
        },
        defaultMessage() {
          return 'User must be at least 18 years old';
        },
      },
    });
  };
}
```

#### Global Validation Configuration
```typescript
// main.ts
app.useGlobalPipes(
  new ValidationPipe({
    transform: true,
    whitelist: true,
    forbidNonWhitelisted: true,
    disableErrorMessages: process.env.NODE_ENV === 'production',
    validationError: {
      target: false,
      value: false,
    },
    exceptionFactory: (errors: ValidationError[]) => {
      const messages = errors.map(error => ({
        property: error.property,
        constraints: Object.values(error.constraints || {}),
        children: error.children?.map(child => ({
          property: child.property,
          constraints: Object.values(child.constraints || {}),
        })),
      }));

      return new BadRequestException({
        statusCode: HttpStatus.BAD_REQUEST,
        message: 'Validation failed',
        errors: messages,
      });
    },
  }),
);
```

### 3. Authorization Patterns

#### Role-Based Access Control (RBAC)
```typescript
// Role entity with permissions
@Entity('roles')
export class Role {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ unique: true })
  name: string;

  @ManyToMany(() => Permission)
  @JoinTable()
  permissions: Permission[];
}

@Entity('permissions')
export class Permission {
  @PrimaryGeneratedColumn()
  id: number;

  @Column()
  resource: string; // e.g., 'users', 'articles'

  @Column()
  action: string; // e.g., 'create', 'read', 'update', 'delete'

  @Column({ default: false })
  isOwnerOnly: boolean; // Resource owner restriction
}

// Permission guard
@Injectable()
export class PermissionGuard implements CanActivate {
  constructor(private reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const requiredPermissions = this.reflector.getAllAndOverride<string[]>(
      'permissions',
      [context.getHandler(), context.getClass()],
    );

    if (!requiredPermissions?.length) {
      return true;
    }

    const { user, params } = context.switchToHttp().getRequest();
    
    return this.checkPermissions(user, requiredPermissions, params);
  }

  private checkPermissions(
    user: User,
    requiredPermissions: string[],
    params: any,
  ): boolean {
    const userPermissions = user.role.permissions.map(p => `${p.resource}:${p.action}`);
    
    return requiredPermissions.every(permission => {
      const [resource, action] = permission.split(':');
      const hasPermission = userPermissions.includes(permission);
      
      if (!hasPermission) return false;

      // Check owner-only restrictions
      const permissionEntity = user.role.permissions.find(
        p => p.resource === resource && p.action === action
      );
      
      if (permissionEntity?.isOwnerOnly) {
        return this.checkOwnership(user, resource, params);
      }

      return true;
    });
  }

  private checkOwnership(user: User, resource: string, params: any): boolean {
    // Implement ownership checks based on resource type
    switch (resource) {
      case 'articles':
        return params.authorId === user.id;
      case 'profiles':
        return params.userId === user.id;
      default:
        return false;
    }
  }
}

// Usage
@Controller('articles')
export class ArticlesController {
  @Post()
  @RequirePermissions('articles:create')
  @UseGuards(JwtAuthGuard, PermissionGuard)
  async create(@Body() dto: CreateArticleDto, @CurrentUser() user: User) {
    return this.articlesService.create(dto, user);
  }

  @Put(':id')
  @RequirePermissions('articles:update')
  @UseGuards(JwtAuthGuard, PermissionGuard)
  async update(@Param('id') id: string, @Body() dto: UpdateArticleDto) {
    return this.articlesService.update(id, dto);
  }
}
```

## 🎯 Error Handling & Logging

### 1. Global Exception Filter

```typescript
@Catch()
export class GlobalExceptionFilter implements ExceptionFilter {
  private readonly logger = new Logger(GlobalExceptionFilter.name);

  catch(exception: unknown, host: ArgumentsHost): void {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();

    const { status, message, stack } = this.getErrorDetails(exception);

    const errorResponse = {
      statusCode: status,
      timestamp: new Date().toISOString(),
      path: request.url,
      method: request.method,
      message,
      ...(process.env.NODE_ENV !== 'production' && { stack }),
    };

    // Log error with context
    this.logger.error(
      `${request.method} ${request.url}`,
      {
        status,
        message,
        stack,
        user: request.user?.id,
        ip: request.ip,
        userAgent: request.get('user-agent'),
      },
    );

    // Send response
    response.status(status).json(errorResponse);
  }

  private getErrorDetails(exception: unknown) {
    if (exception instanceof HttpException) {
      return {
        status: exception.getStatus(),
        message: exception.getResponse(),
        stack: exception.stack,
      };
    }

    if (exception instanceof QueryFailedError) {
      return {
        status: HttpStatus.BAD_REQUEST,
        message: 'Database operation failed',
        stack: exception.stack,
      };
    }

    if (exception instanceof ValidationError) {
      return {
        status: HttpStatus.BAD_REQUEST,
        message: 'Validation failed',
        stack: exception.stack,
      };
    }

    return {
      status: HttpStatus.INTERNAL_SERVER_ERROR,
      message: 'Internal server error',
      stack: exception instanceof Error ? exception.stack : String(exception),
    };
  }
}
```

### 2. Structured Logging

```typescript
// Custom logger service
@Injectable()
export class LoggerService {
  private readonly logger = winston.createLogger({
    level: process.env.LOG_LEVEL || 'info',
    format: winston.format.combine(
      winston.format.timestamp(),
      winston.format.errors({ stack: true }),
      winston.format.json(),
    ),
    defaultMeta: {
      service: 'nestjs-app',
      version: process.env.APP_VERSION,
      environment: process.env.NODE_ENV,
    },
    transports: [
      new winston.transports.Console({
        format: winston.format.combine(
          winston.format.colorize(),
          winston.format.simple(),
        ),
      }),
      new winston.transports.File({
        filename: 'logs/error.log',
        level: 'error',
      }),
      new winston.transports.File({
        filename: 'logs/combined.log',
      }),
    ],
  });

  log(message: string, context?: any): void {
    this.logger.info(message, { context });
  }

  error(message: string, trace?: string, context?: any): void {
    this.logger.error(message, { trace, context });
  }

  warn(message: string, context?: any): void {
    this.logger.warn(message, { context });
  }

  debug(message: string, context?: any): void {
    this.logger.debug(message, { context });
  }

  // Structured logging methods
  logUserAction(userId: string, action: string, resource?: string, details?: any): void {
    this.logger.info('User action', {
      userId,
      action,
      resource,
      details,
      timestamp: new Date().toISOString(),
    });
  }

  logPerformance(operation: string, duration: number, context?: any): void {
    this.logger.info('Performance metric', {
      operation,
      duration,
      context,
      timestamp: new Date().toISOString(),
    });
  }

  logSecurityEvent(event: string, severity: 'low' | 'medium' | 'high' | 'critical', details: any): void {
    this.logger.warn('Security event', {
      event,
      severity,
      details,
      timestamp: new Date().toISOString(),
    });
  }
}

// Request logging interceptor
@Injectable()
export class RequestLoggingInterceptor implements NestInterceptor {
  constructor(private readonly logger: LoggerService) {}

  intercept(context: ExecutionContext, next: CallHandler): Observable<any> {
    const request = context.switchToHttp().getRequest();
    const { method, url, body, query, params, user, ip } = request;
    const startTime = Date.now();

    return next.handle().pipe(
      tap(() => {
        const duration = Date.now() - startTime;
        
        this.logger.logUserAction(
          user?.id || 'anonymous',
          `${method} ${url}`,
          this.extractResource(url),
          {
            duration,
            ip,
            userAgent: request.get('user-agent'),
            body: this.sanitizeBody(body),
            query,
            params,
          },
        );
      }),
      catchError(error => {
        const duration = Date.now() - startTime;
        
        this.logger.error(
          `${method} ${url} failed`,
          error.stack,
          {
            duration,
            user: user?.id,
            ip,
            body: this.sanitizeBody(body),
            error: error.message,
          },
        );
        
        throw error;
      }),
    );
  }

  private extractResource(url: string): string {
    const segments = url.split('/').filter(Boolean);
    return segments[0] || 'unknown';
  }

  private sanitizeBody(body: any): any {
    if (!body) return undefined;
    
    const sanitized = { ...body };
    const sensitiveFields = ['password', 'token', 'secret', 'key'];
    
    sensitiveFields.forEach(field => {
      if (sanitized[field]) {
        sanitized[field] = '[REDACTED]';
      }
    });
    
    return sanitized;
  }
}
```

## ⚡ Performance Optimization

### 1. Database Optimization

#### Query Optimization
```typescript
@Injectable()
export class UsersService {
  constructor(
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
    @InjectRedis() private readonly redis: Redis,
  ) {}

  async findWithOptimizedQuery(filters: UserFiltersDto): Promise<User[]> {
    const queryBuilder = this.userRepository.createQueryBuilder('user');

    // Conditional joins to avoid N+1 problems
    if (filters.includeRole) {
      queryBuilder.leftJoinAndSelect('user.role', 'role');
    }

    if (filters.includePermissions) {
      queryBuilder.leftJoinAndSelect('role.permissions', 'permissions');
    }

    // Efficient filtering
    if (filters.status) {
      queryBuilder.andWhere('user.status = :status', { status: filters.status });
    }

    if (filters.createdAfter) {
      queryBuilder.andWhere('user.createdAt > :date', { date: filters.createdAfter });
    }

    // Optimized search
    if (filters.search) {
      queryBuilder.andWhere(
        new Brackets(qb => {
          qb.where('user.firstName ILIKE :search', { search: `%${filters.search}%` })
            .orWhere('user.lastName ILIKE :search', { search: `%${filters.search}%` })
            .orWhere('user.email ILIKE :search', { search: `%${filters.search}%` });
        }),
      );
    }

    // Pagination
    if (filters.limit) {
      queryBuilder.take(filters.limit);
    }

    if (filters.offset) {
      queryBuilder.skip(filters.offset);
    }

    // Efficient ordering
    queryBuilder.orderBy('user.createdAt', 'DESC');

    return queryBuilder.getMany();
  }

  // Batch operations for performance
  async createUsersInBatch(users: CreateUserDto[]): Promise<User[]> {
    const BATCH_SIZE = 100;
    const results: User[] = [];

    for (let i = 0; i < users.length; i += BATCH_SIZE) {
      const batch = users.slice(i, i + BATCH_SIZE);
      const entities = batch.map(userData => this.userRepository.create(userData));
      
      const savedBatch = await this.userRepository.save(entities);
      results.push(...savedBatch);
    }

    return results;
  }
}
```

#### Connection Pooling
```typescript
// database.config.ts
export const databaseConfig = (): TypeOrmModuleOptions => ({
  type: 'postgres',
  host: process.env.DB_HOST,
  port: parseInt(process.env.DB_PORT, 10),
  username: process.env.DB_USERNAME,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_DATABASE,
  entities: [__dirname + '/../**/*.entity{.ts,.js}'],
  synchronize: process.env.NODE_ENV !== 'production',
  logging: process.env.NODE_ENV === 'development',
  extra: {
    // Connection pool configuration
    max: 20, // Maximum number of connections
    min: 5, // Minimum number of connections
    acquire: 30000, // Maximum time (ms) to get connection
    idle: 10000, // Maximum time (ms) connection can be idle
    evict: 1000, // Time interval (ms) to run eviction
    // Performance optimizations
    statement_timeout: 30000, // Statement timeout
    query_timeout: 30000, // Query timeout
    connectionTimeoutMillis: 30000,
    idleTimeoutMillis: 30000,
  },
});
```

### 2. Caching Strategies

#### Multi-level Caching
```typescript
@Injectable()
export class CacheService {
  private readonly memoryCache = new Map<string, { data: any; expiry: number }>();

  constructor(@InjectRedis() private readonly redis: Redis) {}

  async get<T>(key: string): Promise<T | null> {
    // Level 1: Memory cache (fastest)
    const memoryResult = this.memoryCache.get(key);
    if (memoryResult && Date.now() < memoryResult.expiry) {
      return memoryResult.data;
    }

    // Level 2: Redis cache
    try {
      const redisResult = await this.redis.get(key);
      if (redisResult) {
        const data = JSON.parse(redisResult);
        
        // Store in memory cache for next access
        this.memoryCache.set(key, {
          data,
          expiry: Date.now() + 60000, // 1 minute memory cache
        });
        
        return data;
      }
    } catch (error) {
      console.error('Redis cache error:', error);
    }

    return null;
  }

  async set(key: string, value: any, ttlSeconds: number = 3600): Promise<void> {
    try {
      // Set in Redis
      await this.redis.setex(key, ttlSeconds, JSON.stringify(value));
      
      // Set in memory cache with shorter TTL
      this.memoryCache.set(key, {
        data: value,
        expiry: Date.now() + Math.min(ttlSeconds * 1000, 60000),
      });
    } catch (error) {
      console.error('Cache set error:', error);
    }
  }

  async invalidate(pattern: string): Promise<void> {
    // Clear memory cache
    for (const key of this.memoryCache.keys()) {
      if (key.match(pattern)) {
        this.memoryCache.delete(key);
      }
    }

    // Clear Redis cache
    try {
      const keys = await this.redis.keys(pattern);
      if (keys.length > 0) {
        await this.redis.del(...keys);
      }
    } catch (error) {
      console.error('Cache invalidation error:', error);
    }
  }
}

// Cache decorator for automatic caching
export function Cache(ttl: number = 300, keyGenerator?: (args: any[]) => string) {
  return function (target: any, propertyName: string, descriptor: PropertyDescriptor) {
    const originalMethod = descriptor.value;

    descriptor.value = async function (...args: any[]) {
      const cacheService = this.cacheService as CacheService;
      
      if (!cacheService) {
        return originalMethod.apply(this, args);
      }

      const cacheKey = keyGenerator 
        ? keyGenerator(args)
        : `${target.constructor.name}:${propertyName}:${JSON.stringify(args)}`;

      const cached = await cacheService.get(cacheKey);
      if (cached) {
        return cached;
      }

      const result = await originalMethod.apply(this, args);
      await cacheService.set(cacheKey, result, ttl);

      return result;
    };

    return descriptor;
  };
}

// Usage
@Injectable()
export class ArticlesService {
  constructor(private readonly cacheService: CacheService) {}

  @Cache(300, (args) => `articles:popular:${args[0]}`) // 5 minutes cache
  async getPopularArticles(limit: number = 10): Promise<Article[]> {
    // Expensive operation
    return this.articleRepository.find({
      order: { viewCount: 'DESC' },
      take: limit,
    });
  }
}
```

## 🧪 Testing Best Practices

### 1. Comprehensive Testing Strategy

#### Test Utilities
```typescript
// test/utils/test-utils.ts
export class TestUtils {
  static async createTestingModule(options: {
    imports?: any[];
    providers?: any[];
    controllers?: any[];
  }): Promise<TestingModule> {
    return Test.createTestingModule({
      imports: [
        TypeOrmModule.forRoot({
          type: 'sqlite',
          database: ':memory:',
          entities: [__dirname + '/../../src/**/*.entity{.ts,.js}'],
          synchronize: true,
        }),
        ...options.imports || [],
      ],
      providers: options.providers || [],
      controllers: options.controllers || [],
    }).compile();
  }

  static createMockRepository<T = any>(): MockRepository<T> {
    return {
      find: jest.fn(),
      findOne: jest.fn(),
      save: jest.fn(),
      create: jest.fn(),
      update: jest.fn(),
      delete: jest.fn(),
      createQueryBuilder: jest.fn(() => ({
        where: jest.fn().mockReturnThis(),
        andWhere: jest.fn().mockReturnThis(),
        leftJoinAndSelect: jest.fn().mockReturnThis(),
        orderBy: jest.fn().mockReturnThis(),
        limit: jest.fn().mockReturnThis(),
        offset: jest.fn().mockReturnThis(),
        getMany: jest.fn(),
        getOne: jest.fn(),
        getManyAndCount: jest.fn(),
      })),
    };
  }

  static createMockUser(overrides: Partial<User> = {}): User {
    return {
      id: 'test-user-id',
      email: 'test@example.com',
      firstName: 'Test',
      lastName: 'User',
      role: { id: 1, name: 'user', permissions: [] },
      createdAt: new Date(),
      updatedAt: new Date(),
      ...overrides,
    } as User;
  }
}

type MockRepository<T = any> = Partial<Record<keyof Repository<T>, jest.Mock>>;
```

#### Integration Test Setup
```typescript
// test/integration/users.integration.spec.ts
describe('UsersController (Integration)', () => {
  let app: INestApplication;
  let userRepository: Repository<User>;
  let authService: AuthService;

  beforeAll(async () => {
    const moduleRef = await TestUtils.createTestingModule({
      imports: [UsersModule, AuthModule],
    });

    app = moduleRef.createNestApplication();
    userRepository = moduleRef.get<Repository<User>>(getRepositoryToken(User));
    authService = moduleRef.get<AuthService>(AuthService);

    await app.init();
  });

  beforeEach(async () => {
    await userRepository.clear();
  });

  afterAll(async () => {
    await app.close();
  });

  describe('POST /users', () => {
    it('should create a new user successfully', async () => {
      const createUserDto = {
        email: 'test@example.com',
        password: 'SecurePassword123!',
        firstName: 'John',
        lastName: 'Doe',
      };

      const response = await request(app.getHttpServer())
        .post('/users')
        .send(createUserDto)
        .expect(201);

      expect(response.body).toMatchObject({
        email: createUserDto.email,
        firstName: createUserDto.firstName,
        lastName: createUserDto.lastName,
      });

      expect(response.body.password).toBeUndefined();

      // Verify user was saved to database
      const savedUser = await userRepository.findOne({
        where: { email: createUserDto.email },
      });

      expect(savedUser).toBeDefined();
      expect(savedUser.email).toBe(createUserDto.email);
    });

    it('should return 400 for invalid email', async () => {
      const createUserDto = {
        email: 'invalid-email',
        password: 'SecurePassword123!',
        firstName: 'John',
        lastName: 'Doe',
      };

      const response = await request(app.getHttpServer())
        .post('/users')
        .send(createUserDto)
        .expect(400);

      expect(response.body.message).toContain('Validation failed');
    });
  });

  describe('GET /users/:id', () => {
    it('should return user with valid token', async () => {
      // Create test user
      const user = await userRepository.save(
        userRepository.create({
          email: 'test@example.com',
          firstName: 'John',
          lastName: 'Doe',
          password: 'hashedpassword',
        }),
      );

      // Generate valid token
      const { accessToken } = await authService.login({
        email: user.email,
        password: 'password',
      });

      const response = await request(app.getHttpServer())
        .get(`/users/${user.id}`)
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(200);

      expect(response.body.id).toBe(user.id);
      expect(response.body.email).toBe(user.email);
    });
  });
});
```

This comprehensive best practices guide provides production-tested patterns for building secure, scalable, and maintainable NestJS applications based on analysis of real-world implementations.