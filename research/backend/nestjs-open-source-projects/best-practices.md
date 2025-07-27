# Best Practices for Production NestJS Applications

## 🎯 Overview

Consolidated best practices derived from analyzing 15+ production-ready NestJS applications, focusing on architecture, security, performance, and maintainability patterns that have proven successful in real-world applications.

## 🏗️ Architecture Best Practices

### 1. Module Organization and Structure

#### Recommended Project Structure
```
src/
├── common/                 # Shared utilities
│   ├── decorators/        # Custom decorators
│   ├── filters/           # Exception filters
│   ├── guards/            # Authentication/authorization guards
│   ├── interceptors/      # Response interceptors
│   ├── pipes/             # Validation pipes
│   └── utils/             # Utility functions
├── config/                # Configuration management
│   ├── database.config.ts
│   ├── auth.config.ts
│   └── app.config.ts
├── modules/               # Feature modules
│   ├── auth/             # Authentication module
│   ├── users/            # User management module
│   ├── products/         # Business domain modules
│   └── shared/           # Shared business logic
├── database/             # Database-related files
│   ├── migrations/       # Database migrations
│   ├── seeds/           # Database seeders
│   └── entities/        # Database entities (if using TypeORM)
└── main.ts              # Application entry point
```

#### Module Design Pattern
```typescript
// Feature Module Example
@Module({
  imports: [
    TypeOrmModule.forFeature([UserEntity]),
    ConfigModule,
  ],
  controllers: [UsersController],
  providers: [
    UsersService,
    UsersRepository,
    {
      provide: 'IUsersRepository',
      useClass: UsersRepository,
    },
  ],
  exports: [UsersService, 'IUsersRepository'],
})
export class UsersModule {}

// Service with Dependency Injection
@Injectable()
export class UsersService {
  constructor(
    @Inject('IUsersRepository')
    private readonly usersRepository: IUsersRepository,
    private readonly configService: ConfigService,
    private readonly logger: Logger,
  ) {}

  async findById(id: string): Promise<UserEntity> {
    try {
      const user = await this.usersRepository.findById(id);
      if (!user) {
        throw new NotFoundException(`User with ID ${id} not found`);
      }
      return user;
    } catch (error) {
      this.logger.error(`Failed to find user with ID ${id}`, error.stack);
      throw error;
    }
  }
}
```

### 2. Configuration Management

#### Environment-based Configuration
```typescript
// config/database.config.ts
import { registerAs } from '@nestjs/config';
import { TypeOrmModuleOptions } from '@nestjs/typeorm';

export default registerAs(
  'database',
  (): TypeOrmModuleOptions => ({
    type: 'postgres',
    host: process.env.DATABASE_HOST || 'localhost',
    port: parseInt(process.env.DATABASE_PORT) || 5432,
    username: process.env.DATABASE_USERNAME,
    password: process.env.DATABASE_PASSWORD,
    database: process.env.DATABASE_NAME,
    entities: [__dirname + '/../**/*.entity{.ts,.js}'],
    migrations: [__dirname + '/../database/migrations/*{.ts,.js}'],
    synchronize: process.env.NODE_ENV === 'development',
    logging: process.env.NODE_ENV === 'development',
    ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false,
    pool: {
      min: 2,
      max: 10,
      acquireTimeoutMillis: 60000,
      createTimeoutMillis: 30000,
      destroyTimeoutMillis: 5000,
      idleTimeoutMillis: 30000,
      reapIntervalMillis: 1000,
      createRetryIntervalMillis: 200,
    },
  }),
);

// Configuration Validation
import Joi from 'joi';

export const validationSchema = Joi.object({
  NODE_ENV: Joi.string().valid('development', 'production', 'test').required(),
  PORT: Joi.number().default(3000),
  DATABASE_HOST: Joi.string().required(),
  DATABASE_PORT: Joi.number().default(5432),
  DATABASE_USERNAME: Joi.string().required(),
  DATABASE_PASSWORD: Joi.string().required(),
  DATABASE_NAME: Joi.string().required(),
  JWT_SECRET: Joi.string().min(32).required(),
  JWT_EXPIRATION_TIME: Joi.string().default('15m'),
  REDIS_HOST: Joi.string().required(),
  REDIS_PORT: Joi.number().default(6379),
});
```

### 3. Error Handling and Logging

#### Global Exception Filter
```typescript
@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  private readonly logger = new Logger(AllExceptionsFilter.name);

  catch(exception: unknown, host: ArgumentsHost): void {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();

    let status: number;
    let message: string;
    let error: string;

    if (exception instanceof HttpException) {
      status = exception.getStatus();
      const errorResponse = exception.getResponse();
      message = (errorResponse as any).message || exception.message;
      error = (errorResponse as any).error || exception.name;
    } else if (exception instanceof QueryFailedError) {
      status = HttpStatus.BAD_REQUEST;
      message = 'Database query failed';
      error = 'Database Error';
    } else {
      status = HttpStatus.INTERNAL_SERVER_ERROR;
      message = 'Internal server error';
      error = 'Internal Error';
    }

    const errorResponse = {
      statusCode: status,
      timestamp: new Date().toISOString(),
      path: request.url,
      method: request.method,
      message,
      error,
    };

    this.logger.error(
      `${request.method} ${request.url}`,
      JSON.stringify(errorResponse),
      exception instanceof Error ? exception.stack : 'Unknown error',
    );

    response.status(status).json(errorResponse);
  }
}

// Custom Logger Service
@Injectable()
export class CustomLogger extends Logger {
  constructor(private configService: ConfigService) {
    super();
  }

  log(message: string, context?: string) {
    if (this.configService.get('NODE_ENV') !== 'test') {
      super.log(message, context);
    }
  }

  error(message: string, trace?: string, context?: string) {
    // Send to external logging service in production
    if (this.configService.get('NODE_ENV') === 'production') {
      // Send to Sentry, LogRocket, etc.
    }
    super.error(message, trace, context);
  }
}
```

## 🔐 Security Best Practices

### 1. Authentication Implementation

#### Secure JWT Configuration
```typescript
// JWT Module Configuration
@Module({
  imports: [
    JwtModule.registerAsync({
      imports: [ConfigModule],
      useFactory: async (configService: ConfigService) => ({
        secret: configService.get<string>('JWT_SECRET'),
        signOptions: {
          expiresIn: configService.get<string>('JWT_EXPIRATION_TIME'),
          issuer: configService.get<string>('APP_NAME'),
          audience: configService.get<string>('APP_URL'),
        },
      }),
      inject: [ConfigService],
    }),
  ],
})
export class AuthModule {}

// Secure Password Hashing
@Injectable()
export class PasswordService {
  private readonly saltRounds = 12;

  async hashPassword(password: string): Promise<string> {
    return bcrypt.hash(password, this.saltRounds);
  }

  async comparePassword(password: string, hash: string): Promise<boolean> {
    return bcrypt.compare(password, hash);
  }

  generateSecureToken(): string {
    return crypto.randomBytes(32).toString('hex');
  }
}
```

### 2. Input Validation and Sanitization

#### Advanced DTO Validation
```typescript
// Custom Validation Decorators
export function IsStrongPassword(validationOptions?: ValidationOptions) {
  return function (object: Object, propertyName: string) {
    registerDecorator({
      name: 'isStrongPassword',
      target: object.constructor,
      propertyName: propertyName,
      options: validationOptions,
      validator: {
        validate(value: any) {
          const strongPasswordRegex = /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$/;
          return typeof value === 'string' && strongPasswordRegex.test(value);
        },
        defaultMessage() {
          return 'Password must be at least 8 characters long and contain uppercase, lowercase, number, and special character';
        },
      },
    });
  };
}

// Comprehensive DTO
export class CreateUserDto {
  @IsEmail()
  @IsNotEmpty()
  @Transform(({ value }) => value?.toLowerCase().trim())
  @Length(5, 254)
  email: string;

  @IsStrongPassword()
  @IsNotEmpty()
  password: string;

  @IsString()
  @IsNotEmpty()
  @Length(2, 50)
  @Transform(({ value }) => value?.trim())
  @Matches(/^[a-zA-Z\s]*$/, { message: 'First name can only contain letters and spaces' })
  firstName: string;

  @IsString()
  @IsNotEmpty()
  @Length(2, 50)
  @Transform(({ value }) => value?.trim())
  @Matches(/^[a-zA-Z\s]*$/, { message: 'Last name can only contain letters and spaces' })
  lastName: string;

  @IsOptional()
  @IsPhoneNumber()
  phone?: string;

  @IsOptional()
  @IsISO8601()
  @Transform(({ value }) => value ? new Date(value).toISOString() : value)
  dateOfBirth?: string;
}
```

### 3. Security Middleware Configuration

#### Production Security Setup
```typescript
async function bootstrap() {
  const app = await NestFactory.create(AppModule, {
    logger: ['error', 'warn'],
  });

  // Security Headers
  app.use(helmet({
    contentSecurityPolicy: {
      directives: {
        defaultSrc: ["'self'"],
        styleSrc: ["'self'", "'unsafe-inline'", "https://fonts.googleapis.com"],
        scriptSrc: ["'self'"],
        imgSrc: ["'self'", "data:", "https:"],
        connectSrc: ["'self'"],
        fontSrc: ["'self'", "https://fonts.gstatic.com"],
        objectSrc: ["'none'"],
        mediaSrc: ["'self'"],
        frameSrc: ["'none'"],
      },
    },
  }));

  // CORS Configuration
  app.enableCors({
    origin: (origin, callback) => {
      const allowedOrigins = process.env.ALLOWED_ORIGINS?.split(',') || [];
      if (!origin || allowedOrigins.includes(origin)) {
        callback(null, true);
      } else {
        callback(new Error('Not allowed by CORS'));
      }
    },
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With'],
  });

  // Rate Limiting
  app.use('/api', rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 100, // limit each IP to 100 requests per windowMs
    message: {
      statusCode: 429,
      error: 'Too Many Requests',
      message: 'Too many requests from this IP, please try again later.',
    },
    standardHeaders: true,
    legacyHeaders: false,
  }));

  // Special rate limiting for auth endpoints
  app.use('/api/auth', rateLimit({
    windowMs: 15 * 60 * 1000,
    max: 5, // limit login attempts
    message: {
      statusCode: 429,
      error: 'Too Many Requests',
      message: 'Too many authentication attempts, please try again later.',
    },
  }));

  // Global pipes
  app.useGlobalPipes(new ValidationPipe({
    whitelist: true,
    forbidNonWhitelisted: true,
    transform: true,
    transformOptions: {
      enableImplicitConversion: true,
    },
  }));

  await app.listen(process.env.PORT || 3000);
}
```

## 🚀 Performance Best Practices

### 1. Database Optimization

#### Connection Pooling and Query Optimization
```typescript
// Optimized Database Configuration
@Module({
  imports: [
    TypeOrmModule.forRootAsync({
      imports: [ConfigModule],
      useFactory: (configService: ConfigService) => ({
        type: 'postgres',
        host: configService.get('DATABASE_HOST'),
        port: configService.get('DATABASE_PORT'),
        username: configService.get('DATABASE_USERNAME'),
        password: configService.get('DATABASE_PASSWORD'),
        database: configService.get('DATABASE_NAME'),
        entities: [__dirname + '/../**/*.entity{.ts,.js}'],
        synchronize: false, // Always false in production
        logging: configService.get('NODE_ENV') === 'development',
        
        // Connection pool optimization
        extra: {
          connectionLimit: 10,
          acquireTimeoutMillis: 60000,
          timeout: 60000,
          reconnect: true,
        },
        
        // Query optimization
        cache: {
          duration: 30000, // 30 seconds
        },
      }),
      inject: [ConfigService],
    }),
  ],
})
export class DatabaseModule {}

// Repository with Query Optimization
@Injectable()
export class UsersRepository {
  constructor(
    @InjectRepository(UserEntity)
    private readonly userRepository: Repository<UserEntity>,
  ) {}

  async findWithPagination(
    page: number, 
    limit: number, 
    filters: any
  ): Promise<[UserEntity[], number]> {
    const queryBuilder = this.userRepository
      .createQueryBuilder('user')
      .leftJoinAndSelect('user.profile', 'profile')
      .where('user.isActive = :isActive', { isActive: true });

    // Apply filters
    if (filters.email) {
      queryBuilder.andWhere('user.email ILIKE :email', { 
        email: `%${filters.email}%` 
      });
    }

    // Pagination
    queryBuilder
      .skip((page - 1) * limit)
      .take(limit)
      .orderBy('user.createdAt', 'DESC');

    return queryBuilder.getManyAndCount();
  }

  // Use QueryBuilder for complex queries
  async findActiveUsersWithRoles(): Promise<UserEntity[]> {
    return this.userRepository
      .createQueryBuilder('user')
      .leftJoinAndSelect('user.roles', 'role')
      .where('user.isActive = :isActive', { isActive: true })
      .andWhere('user.deletedAt IS NULL')
      .cache(60000) // Cache for 1 minute
      .getMany();
  }
}
```

### 2. Caching Strategies

#### Redis Integration for Caching
```typescript
// Cache Module Configuration
@Module({
  imports: [
    CacheModule.registerAsync({
      imports: [ConfigModule],
      useFactory: async (configService: ConfigService) => ({
        store: redisStore,
        host: configService.get('REDIS_HOST'),
        port: configService.get('REDIS_PORT'),
        password: configService.get('REDIS_PASSWORD'),
        ttl: 600, // 10 minutes default TTL
      }),
      inject: [ConfigService],
    }),
  ],
  exports: [CacheModule],
})
export class CacheConfigModule {}

// Service with Caching
@Injectable()
export class UsersService {
  constructor(
    private readonly usersRepository: UsersRepository,
    @Inject(CACHE_MANAGER) private cacheService: Cache,
  ) {}

  async findById(id: string): Promise<UserEntity> {
    const cacheKey = `user:${id}`;
    
    // Try to get from cache first
    let user = await this.cacheService.get<UserEntity>(cacheKey);
    
    if (!user) {
      user = await this.usersRepository.findById(id);
      if (user) {
        // Cache for 5 minutes
        await this.cacheService.set(cacheKey, user, { ttl: 300 });
      }
    }
    
    return user;
  }

  async updateUser(id: string, updateData: any): Promise<UserEntity> {
    const user = await this.usersRepository.update(id, updateData);
    
    // Invalidate cache
    await this.cacheService.del(`user:${id}`);
    
    return user;
  }
}

// Cache Interceptor for Controllers
@Injectable()
export class HttpCacheInterceptor implements NestInterceptor {
  constructor(@Inject(CACHE_MANAGER) private cacheManager: Cache) {}

  async intercept(context: ExecutionContext, next: CallHandler): Promise<Observable<any>> {
    const request = context.switchToHttp().getRequest();
    const cacheKey = request.url;

    const cachedResponse = await this.cacheManager.get(cacheKey);
    if (cachedResponse) {
      return of(cachedResponse);
    }

    return next.handle().pipe(
      tap(async (response) => {
        await this.cacheManager.set(cacheKey, response, { ttl: 60 });
      }),
    );
  }
}
```

### 3. Background Jobs and Queues

#### Bull Queue Implementation
```typescript
// Queue Module Configuration
@Module({
  imports: [
    BullModule.forRootAsync({
      imports: [ConfigModule],
      useFactory: async (configService: ConfigService) => ({
        redis: {
          host: configService.get('REDIS_HOST'),
          port: configService.get('REDIS_PORT'),
          password: configService.get('REDIS_PASSWORD'),
        },
        defaultJobOptions: {
          removeOnComplete: 10,
          removeOnFail: 5,
        },
      }),
      inject: [ConfigService],
    }),
    BullModule.registerQueue({
      name: 'email',
    }),
    BullModule.registerQueue({
      name: 'data-processing',
    }),
  ],
})
export class QueueModule {}

// Queue Producer
@Injectable()
export class EmailService {
  constructor(
    @InjectQueue('email') private emailQueue: Queue,
  ) {}

  async sendWelcomeEmail(userEmail: string, userName: string) {
    await this.emailQueue.add('welcome-email', {
      email: userEmail,
      name: userName,
    }, {
      priority: 10,
      delay: 2000, // 2 second delay
      attempts: 3,
      backoff: {
        type: 'exponential',
        delay: 2000,
      },
    });
  }

  async sendBulkEmails(emails: string[], content: string) {
    const jobs = emails.map(email => ({
      name: 'bulk-email',
      data: { email, content },
      opts: {
        priority: 5,
        attempts: 2,
      },
    }));

    await this.emailQueue.addBulk(jobs);
  }
}

// Queue Consumer
@Processor('email')
export class EmailProcessor {
  private readonly logger = new Logger(EmailProcessor.name);

  @Process('welcome-email')
  async handleWelcomeEmail(job: Job<{ email: string; name: string }>) {
    this.logger.log(`Processing welcome email for ${job.data.email}`);
    
    try {
      // Send email logic here
      await this.sendEmail(job.data.email, 'Welcome!', job.data.name);
      
      this.logger.log(`Welcome email sent to ${job.data.email}`);
    } catch (error) {
      this.logger.error(`Failed to send welcome email to ${job.data.email}`, error.stack);
      throw error;
    }
  }

  @Process('bulk-email')
  async handleBulkEmail(job: Job<{ email: string; content: string }>) {
    // Bulk email processing logic
  }

  private async sendEmail(to: string, subject: string, name: string) {
    // Email sending implementation
  }
}
```

## 📊 Testing Best Practices

### 1. Unit Testing

#### Service Testing Pattern
```typescript
describe('UsersService', () => {
  let service: UsersService;
  let repository: MockRepository<UserEntity>;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        UsersService,
        {
          provide: getRepositoryToken(UserEntity),
          useValue: createMockRepository(),
        },
        {
          provide: CACHE_MANAGER,
          useValue: createMockCacheManager(),
        },
      ],
    }).compile();

    service = module.get<UsersService>(UsersService);
    repository = module.get(getRepositoryToken(UserEntity));
  });

  describe('findById', () => {
    it('should return a user when found', async () => {
      const userId = 'test-id';
      const mockUser = { id: userId, email: 'test@example.com' };
      
      repository.findOne.mockResolvedValue(mockUser);

      const result = await service.findById(userId);

      expect(result).toEqual(mockUser);
      expect(repository.findOne).toHaveBeenCalledWith({
        where: { id: userId },
      });
    });

    it('should throw NotFoundException when user not found', async () => {
      const userId = 'non-existent-id';
      
      repository.findOne.mockResolvedValue(null);

      await expect(service.findById(userId)).rejects.toThrow(NotFoundException);
    });
  });
});

function createMockRepository() {
  return {
    findOne: jest.fn(),
    find: jest.fn(),
    save: jest.fn(),
    create: jest.fn(),
    update: jest.fn(),
    delete: jest.fn(),
  };
}

function createMockCacheManager() {
  return {
    get: jest.fn(),
    set: jest.fn(),
    del: jest.fn(),
  };
}
```

### 2. Integration Testing

#### E2E Testing Pattern
```typescript
describe('AuthController (e2e)', () => {
  let app: INestApplication;
  let authService: AuthService;

  beforeAll(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    })
    .overrideProvider(ConfigService)
    .useValue(createMockConfigService())
    .compile();

    app = moduleFixture.createNestApplication();
    
    // Apply same middleware as in production
    app.useGlobalPipes(new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
    }));

    authService = moduleFixture.get<AuthService>(AuthService);
    
    await app.init();
  });

  afterAll(async () => {
    await app.close();
  });

  describe('/auth/login (POST)', () => {
    it('should login with valid credentials', () => {
      return request(app.getHttpServer())
        .post('/auth/login')
        .send({
          email: 'test@example.com',
          password: 'SecurePassword123!',
        })
        .expect(200)
        .expect((res) => {
          expect(res.body).toHaveProperty('accessToken');
          expect(res.body).toHaveProperty('user');
          expect(res.body.user.email).toBe('test@example.com');
        });
    });

    it('should return 401 with invalid credentials', () => {
      return request(app.getHttpServer())
        .post('/auth/login')
        .send({
          email: 'test@example.com',
          password: 'wrongpassword',
        })
        .expect(401);
    });

    it('should validate input format', () => {
      return request(app.getHttpServer())
        .post('/auth/login')
        .send({
          email: 'invalid-email',
          password: '123',
        })
        .expect(400)
        .expect((res) => {
          expect(res.body.message).toContain('email must be an email');
        });
    });
  });
});
```

## 📈 Monitoring and Observability

### 1. Health Checks

#### Comprehensive Health Check Implementation
```typescript
@Controller('health')
export class HealthController {
  constructor(
    private health: HealthCheckService,
    private db: TypeOrmHealthIndicator,
    private redis: TerminusRedisHealthIndicator,
  ) {}

  @Get()
  @HealthCheck()
  check() {
    return this.health.check([
      () => this.db.pingCheck('database'),
      () => this.redis.isHealthy('redis'),
      () => this.checkExternalService(),
    ]);
  }

  private async checkExternalService(): Promise<HealthIndicatorResult> {
    try {
      // Check external API
      const response = await fetch('https://api.external-service.com/health');
      const isHealthy = response.ok;
      
      return {
        'external-service': {
          status: isHealthy ? 'up' : 'down',
          response_time: response.headers.get('x-response-time'),
        },
      };
    } catch (error) {
      return {
        'external-service': {
          status: 'down',
          error: error.message,
        },
      };
    }
  }
}
```

### 2. Metrics and Logging

#### Application Metrics
```typescript
@Injectable()
export class MetricsService {
  private readonly httpRequestsTotal = new Counter({
    name: 'http_requests_total',
    help: 'Total number of HTTP requests',
    labelNames: ['method', 'route', 'status'],
  });

  private readonly httpRequestDuration = new Histogram({
    name: 'http_request_duration_seconds',
    help: 'Duration of HTTP requests in seconds',
    labelNames: ['method', 'route'],
    buckets: [0.1, 0.5, 1, 2, 5],
  });

  recordHttpRequest(method: string, route: string, status: number, duration: number) {
    this.httpRequestsTotal.inc({ method, route, status: status.toString() });
    this.httpRequestDuration.observe({ method, route }, duration);
  }
}

@Injectable()
export class MetricsInterceptor implements NestInterceptor {
  constructor(private metricsService: MetricsService) {}

  intercept(context: ExecutionContext, next: CallHandler): Observable<any> {
    const start = Date.now();
    const request = context.switchToHttp().getRequest();
    const { method, route } = request;

    return next.handle().pipe(
      tap(() => {
        const response = context.switchToHttp().getResponse();
        const duration = (Date.now() - start) / 1000;
        this.metricsService.recordHttpRequest(method, route.path, response.statusCode, duration);
      }),
    );
  }
}
```

---

**Navigation**
- ← Previous: [Authentication & Security](./authentication-security.md)
- → Next: [Code Examples & Templates](./code-examples-templates.md)
- ↑ Back to: [Research Overview](./README.md)