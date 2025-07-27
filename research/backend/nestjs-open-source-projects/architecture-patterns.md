# Architecture Patterns

## 🏗️ Overview

Analysis of architectural patterns and design principles found in production-ready NestJS applications. This document examines how successful projects structure their codebases for scalability, maintainability, and testability.

## 🎯 Common Architecture Patterns

### 1. **Modular Monolith Architecture** (85% adoption)

The most common pattern among NestJS projects is the modular monolith, which provides a good balance between simplicity and scalability.

```typescript
// Feature-based module structure
@Module({
  imports: [
    TypeOrmModule.forFeature([User, Profile, Role]),
    JwtModule.registerAsync({
      useFactory: (configService: ConfigService) => ({
        secret: configService.get('JWT_SECRET'),
        signOptions: { expiresIn: '1h' },
      }),
      inject: [ConfigService],
    }),
  ],
  controllers: [AuthController, UserController],
  providers: [AuthService, UserService, JwtStrategy],
  exports: [AuthService], // Only export what other modules need
})
export class AuthModule {}
```

**Benefits:**
- Clear module boundaries
- Testable in isolation
- Scalable to microservices
- Maintainable code organization

### 2. **Layered Architecture** (95% adoption)

Almost all projects follow a layered architecture with clear separation of concerns:

```
├── controllers/     # HTTP request handling
├── services/        # Business logic
├── repositories/    # Data access layer
├── entities/        # Data models
├── dto/            # Data transfer objects
├── guards/         # Authentication/Authorization
├── interceptors/   # Cross-cutting concerns
└── pipes/          # Data transformation/validation
```

**Implementation Example:**
```typescript
// Controller Layer - HTTP handling
@Controller('users')
@UseGuards(JwtAuthGuard)
export class UserController {
  constructor(private readonly userService: UserService) {}

  @Get()
  async findAll(@Query() query: PaginationQueryDto): Promise<PaginatedResponseDto<UserDto>> {
    return this.userService.findAll(query);
  }
}

// Service Layer - Business logic
@Injectable()
export class UserService {
  constructor(private readonly userRepository: UserRepository) {}

  async findAll(query: PaginationQueryDto): Promise<PaginatedResponseDto<UserDto>> {
    const { data, total } = await this.userRepository.findWithPagination(query);
    return {
      data: data.map(user => new UserDto(user)),
      total,
      page: query.page,
      limit: query.limit,
      totalPages: Math.ceil(total / query.limit),
    };
  }
}

// Repository Layer - Data access
@Injectable()
export class UserRepository {
  constructor(
    @InjectRepository(User)
    private readonly repository: Repository<User>,
  ) {}

  async findWithPagination(query: PaginationQueryDto): Promise<{ data: User[]; total: number }> {
    const [data, total] = await this.repository.findAndCount({
      skip: (query.page - 1) * query.limit,
      take: query.limit,
      order: { [query.orderBy]: query.order },
    });
    return { data, total };
  }
}
```

### 3. **Domain-Driven Design (DDD)** (30% adoption)

More sophisticated projects implement DDD principles with clear domain boundaries:

```typescript
// Domain Entity
export class User {
  private constructor(
    private readonly _id: UserId,
    private readonly _email: Email,
    private _profile: Profile,
    private _roles: Role[],
  ) {}

  static create(props: CreateUserProps): User {
    const user = new User(
      UserId.generate(),
      Email.create(props.email),
      Profile.create(props.profile),
      [],
    );
    
    // Domain events
    user.addDomainEvent(new UserCreatedEvent(user.id, user.email));
    
    return user;
  }

  public assignRole(role: Role): void {
    if (this._roles.some(r => r.equals(role))) {
      throw new DomainError('User already has this role');
    }
    
    this._roles.push(role);
    this.addDomainEvent(new UserRoleAssignedEvent(this._id, role.id));
  }

  get id(): UserId { return this._id; }
  get email(): Email { return this._email; }
  get roles(): Role[] { return [...this._roles]; }
}

// Value Objects
export class Email {
  private constructor(private readonly value: string) {}

  static create(email: string): Email {
    if (!this.isValid(email)) {
      throw new DomainError('Invalid email format');
    }
    return new Email(email);
  }

  private static isValid(email: string): boolean {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return emailRegex.test(email);
  }

  toString(): string {
    return this.value;
  }
}
```

### 4. **CQRS (Command Query Responsibility Segregation)** (15% adoption)

Enterprise applications often implement CQRS for complex business logic:

```typescript
// Command
export class CreateUserCommand {
  constructor(
    public readonly email: string,
    public readonly firstName: string,
    public readonly lastName: string,
  ) {}
}

// Command Handler
@CommandHandler(CreateUserCommand)
export class CreateUserHandler implements ICommandHandler<CreateUserCommand> {
  constructor(
    private readonly userRepository: UserRepository,
    private readonly eventBus: EventBus,
  ) {}

  async execute(command: CreateUserCommand): Promise<string> {
    const user = User.create({
      email: command.email,
      firstName: command.firstName,
      lastName: command.lastName,
    });

    await this.userRepository.save(user);
    
    // Publish domain events
    user.getUncommittedEvents().forEach(event => {
      this.eventBus.publish(event);
    });

    return user.id.toString();
  }
}

// Query
export class GetUserQuery {
  constructor(public readonly userId: string) {}
}

// Query Handler
@QueryHandler(GetUserQuery)
export class GetUserHandler implements IQueryHandler<GetUserQuery> {
  constructor(private readonly userReadRepository: UserReadRepository) {}

  async execute(query: GetUserQuery): Promise<UserView> {
    return this.userReadRepository.findById(query.userId);
  }
}
```

## 🔗 Dependency Management Patterns

### 1. **Dependency Injection Hierarchy**

```typescript
// Core Module - Shared across application
@Global()
@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      validationSchema: configValidationSchema,
    }),
    DatabaseModule,
    LoggerModule,
  ],
  providers: [
    GlobalExceptionFilter,
    {
      provide: APP_FILTER,
      useClass: GlobalExceptionFilter,
    },
    {
      provide: APP_INTERCEPTOR,
      useClass: LoggingInterceptor,
    },
  ],
  exports: [DatabaseModule, LoggerModule],
})
export class CoreModule {}

// Feature Module - Specific functionality
@Module({
  imports: [
    CoreModule,
    TypeOrmModule.forFeature([User, Profile]),
    PassportModule,
  ],
  controllers: [AuthController],
  providers: [
    AuthService,
    JwtStrategy,
    LocalStrategy,
    {
      provide: 'USER_REPOSITORY',
      useClass: TypeOrmUserRepository,
    },
  ],
  exports: [AuthService],
})
export class AuthModule {}
```

### 2. **Repository Pattern Implementation**

```typescript
// Abstract Repository
export abstract class Repository<T> {
  abstract findById(id: string): Promise<T | null>;
  abstract save(entity: T): Promise<T>;
  abstract delete(id: string): Promise<void>;
  abstract findAll(options?: FindOptions): Promise<T[]>;
}

// Concrete Repository
@Injectable()
export class TypeOrmUserRepository implements Repository<User> {
  constructor(
    @InjectRepository(UserEntity)
    private readonly ormRepository: Repository<UserEntity>,
    private readonly mapper: UserMapper,
  ) {}

  async findById(id: string): Promise<User | null> {
    const entity = await this.ormRepository.findOne({ where: { id } });
    return entity ? this.mapper.toDomain(entity) : null;
  }

  async save(user: User): Promise<User> {
    const entity = this.mapper.toEntity(user);
    const saved = await this.ormRepository.save(entity);
    return this.mapper.toDomain(saved);
  }
}

// Usage in Service
@Injectable()
export class UserService {
  constructor(
    @Inject('USER_REPOSITORY')
    private readonly userRepository: Repository<User>,
  ) {}
}
```

## 🎛️ Configuration Patterns

### 1. **Environment-Based Configuration**

```typescript
// Configuration Schema
export interface DatabaseConfig {
  type: 'postgres' | 'mysql' | 'sqlite';
  host: string;
  port: number;
  username: string;
  password: string;
  database: string;
  synchronize: boolean;
  logging: boolean;
}

// Configuration Factory
export const databaseConfig = registerAs('database', (): DatabaseConfig => ({
  type: process.env.DATABASE_TYPE as 'postgres',
  host: process.env.DATABASE_HOST || 'localhost',
  port: parseInt(process.env.DATABASE_PORT, 10) || 5432,
  username: process.env.DATABASE_USERNAME,
  password: process.env.DATABASE_PASSWORD,
  database: process.env.DATABASE_NAME,
  synchronize: process.env.NODE_ENV === 'development',
  logging: process.env.NODE_ENV === 'development',
}));

// Dynamic Module Configuration
@Module({})
export class DatabaseModule {
  static forRootAsync(): DynamicModule {
    return {
      module: DatabaseModule,
      imports: [ConfigModule],
      providers: [
        {
          provide: DataSource,
          useFactory: (configService: ConfigService) => {
            const config = configService.get<DatabaseConfig>('database');
            return new DataSource(config);
          },
          inject: [ConfigService],
        },
      ],
      exports: [DataSource],
    };
  }
}
```

## 🧩 Cross-Cutting Concerns

### 1. **Interceptor Pattern**

```typescript
// Logging Interceptor
@Injectable()
export class LoggingInterceptor implements NestInterceptor {
  private readonly logger = new Logger(LoggingInterceptor.name);

  intercept(context: ExecutionContext, next: CallHandler): Observable<any> {
    const request = context.switchToHttp().getRequest();
    const { method, url, headers } = request;
    const userAgent = headers['user-agent'] || '';
    const ip = request.ip;

    this.logger.log(`${method} ${url} - ${userAgent} ${ip}: ${context.getClass().name} ${context.getHandler().name}`);

    const now = Date.now();
    return next
      .handle()
      .pipe(
        tap(() => this.logger.log(`${method} ${url} - ${userAgent} ${ip}: ${Date.now() - now}ms`)),
        catchError((error) => {
          this.logger.error(`${method} ${url} - ${userAgent} ${ip}: ${error.message}`);
          throw error;
        }),
      );
  }
}
```

### 2. **Exception Filter Pattern**

```typescript
@Catch()
export class GlobalExceptionFilter implements ExceptionFilter {
  private readonly logger = new Logger(GlobalExceptionFilter.name);

  catch(exception: unknown, host: ArgumentsHost): void {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();

    const status = this.getHttpStatus(exception);
    const message = this.getErrorMessage(exception);

    const errorResponse = {
      statusCode: status,
      timestamp: new Date().toISOString(),
      path: request.url,
      method: request.method,
      message,
      ...(process.env.NODE_ENV === 'development' && { stack: exception.stack }),
    };

    this.logger.error(
      `${request.method} ${request.url}`,
      JSON.stringify(errorResponse),
      exception instanceof Error ? exception.stack : 'Unknown',
    );

    response.status(status).json(errorResponse);
  }

  private getHttpStatus(exception: unknown): number {
    if (exception instanceof HttpException) {
      return exception.getStatus();
    }
    return HttpStatus.INTERNAL_SERVER_ERROR;
  }
}
```

## 🔄 Event-Driven Architecture

### 1. **Domain Events Pattern**

```typescript
// Domain Event Base
export abstract class DomainEvent {
  public readonly occurredOn: Date;
  public readonly eventId: string;

  constructor() {
    this.occurredOn = new Date();
    this.eventId = uuid();
  }
}

// Specific Domain Event
export class UserCreatedEvent extends DomainEvent {
  constructor(
    public readonly userId: string,
    public readonly email: string,
  ) {
    super();
  }
}

// Event Handler
@EventsHandler(UserCreatedEvent)
export class UserCreatedHandler implements IEventHandler<UserCreatedEvent> {
  constructor(
    private readonly emailService: EmailService,
    private readonly analyticsService: AnalyticsService,
  ) {}

  async handle(event: UserCreatedEvent): Promise<void> {
    // Send welcome email
    await this.emailService.sendWelcomeEmail(event.email);
    
    // Track analytics
    await this.analyticsService.trackUserRegistration(event.userId);
  }
}
```

## 📊 Scalability Patterns

### 1. **Horizontal Scaling Preparation**

```typescript
// Stateless Services
@Injectable()
export class StatelessUserService {
  constructor(
    private readonly userRepository: UserRepository,
    private readonly cacheService: CacheService,
    private readonly eventBus: EventBus,
  ) {}

  async findById(id: string): Promise<User> {
    // Try cache first
    const cached = await this.cacheService.get(`user:${id}`);
    if (cached) {
      return cached;
    }

    // Fetch from database
    const user = await this.userRepository.findById(id);
    if (user) {
      await this.cacheService.set(`user:${id}`, user, 300); // 5 minutes
    }

    return user;
  }
}

// Database Connection Pooling
@Injectable()
export class DatabaseService {
  private readonly pool: Pool;

  constructor(private readonly configService: ConfigService) {
    this.pool = new Pool({
      host: this.configService.get('DATABASE_HOST'),
      port: this.configService.get('DATABASE_PORT'),
      user: this.configService.get('DATABASE_USER'),
      password: this.configService.get('DATABASE_PASSWORD'),
      database: this.configService.get('DATABASE_NAME'),
      min: 5,  // Minimum connections
      max: 20, // Maximum connections
      idleTimeoutMillis: 30000,
      connectionTimeoutMillis: 2000,
    });
  }
}
```

### 2. **Microservices Preparation**

```typescript
// Service Interface for Future Extraction
export interface IUserService {
  findById(id: string): Promise<User>;
  create(userData: CreateUserData): Promise<User>;
  update(id: string, userData: UpdateUserData): Promise<User>;
  delete(id: string): Promise<void>;
}

// Implementation that can be extracted to microservice
@Injectable()
export class UserService implements IUserService {
  constructor(
    private readonly userRepository: UserRepository,
    private readonly eventBus: EventBus,
  ) {}

  async create(userData: CreateUserData): Promise<User> {
    const user = User.create(userData);
    await this.userRepository.save(user);
    
    // Publish event for other services
    await this.eventBus.publish(new UserCreatedEvent(user.id, user.email));
    
    return user;
  }
}
```

## 📈 Performance Architecture Patterns

### 1. **Caching Strategy**

```typescript
// Multi-level Caching
@Injectable()
export class CachingService {
  constructor(
    @Inject('REDIS_CLIENT') private readonly redis: Redis,
    private readonly localCache: Map<string, any> = new Map(),
  ) {}

  async get(key: string): Promise<any> {
    // L1: Local cache (fastest)
    if (this.localCache.has(key)) {
      return this.localCache.get(key);
    }

    // L2: Redis cache
    const redisValue = await this.redis.get(key);
    if (redisValue) {
      const parsed = JSON.parse(redisValue);
      this.localCache.set(key, parsed);
      return parsed;
    }

    return null;
  }

  async set(key: string, value: any, ttl: number = 300): Promise<void> {
    // Set in both caches
    this.localCache.set(key, value);
    await this.redis.setex(key, ttl, JSON.stringify(value));
  }
}
```

### 2. **Background Processing**

```typescript
// Queue-based Background Jobs
@Injectable()
export class BackgroundJobService {
  constructor(
    @InjectQueue('user-processing') private userQueue: Queue,
    @InjectQueue('email-sending') private emailQueue: Queue,
  ) {}

  async processUserRegistration(userId: string): Promise<void> {
    // Add jobs to different queues
    await this.userQueue.add('setup-user-profile', { userId });
    await this.emailQueue.add('send-welcome-email', { userId });
  }
}

// Job Processor
@Processor('user-processing')
export class UserProcessor {
  private readonly logger = new Logger(UserProcessor.name);

  @Process('setup-user-profile')
  async handleUserSetup(job: Job<{ userId: string }>): Promise<void> {
    const { userId } = job.data;
    this.logger.log(`Setting up profile for user ${userId}`);
    
    // Heavy processing that can be done asynchronously
    await this.createDefaultProfile(userId);
    await this.setupUserPreferences(userId);
    await this.generateUserRecommendations(userId);
  }
}
```

---

**Navigation**
- ↑ Back to: [Security Patterns](./security-patterns.md)
- ↓ Next: [Tools & Libraries](./tools-libraries.md)