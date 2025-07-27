# Best Practices for NestJS Applications

## 🎯 Overview

Consolidated best practices and recommendations derived from analyzing 30+ production NestJS applications. This guide covers code organization, security, performance, testing, and deployment best practices that have proven successful in real-world applications.

## 🏗️ Architecture & Design Best Practices

### 1. Module Organization

**✅ DO: Feature-Based Module Structure**
```typescript
// Good: Feature-based organization
src/
├── users/
│   ├── users.module.ts
│   ├── users.controller.ts
│   ├── users.service.ts
│   ├── users.repository.ts
│   ├── dto/
│   └── entities/
├── auth/
├── posts/
└── common/
```

**❌ DON'T: Technology-Based Organization**
```typescript
// Bad: Technology-based organization
src/
├── controllers/
├── services/
├── repositories/
├── entities/
└── dto/
```

**Module Design Principles:**
```typescript
// Keep modules focused and cohesive
@Module({
  imports: [
    TypeOrmModule.forFeature([User]),
    // Only import what you need
  ],
  controllers: [UsersController],
  providers: [
    UsersService,
    UsersRepository,
    // Use interfaces for better testability
    {
      provide: 'IUserRepository',
      useClass: UsersRepository,
    },
  ],
  exports: [
    'IUserRepository', // Export interfaces, not implementations
    UsersService,
  ],
})
export class UsersModule {}
```

---

### 2. Dependency Injection Best Practices

**✅ DO: Use Constructor Injection**
```typescript
@Injectable()
export class UsersService {
  constructor(
    @Inject('IUserRepository')
    private readonly userRepository: IUserRepository,
    private readonly configService: ConfigService,
    private readonly logger: Logger,
  ) {}
}
```

**✅ DO: Use Interface-Based Dependencies**
```typescript
// Define interface
export interface IUserRepository {
  findById(id: string): Promise<User>;
  save(user: User): Promise<User>;
}

// Implement interface
@Injectable()
export class TypeOrmUserRepository implements IUserRepository {
  // Implementation
}

// Use in module
@Module({
  providers: [
    {
      provide: 'IUserRepository',
      useClass: TypeOrmUserRepository,
    },
  ],
})
export class UsersModule {}
```

**❌ DON'T: Use Direct Class Dependencies in Business Logic**
```typescript
// Bad: Tight coupling
@Injectable()
export class UsersService {
  constructor(
    private readonly typeOrmUserRepository: TypeOrmUserRepository, // Tightly coupled
  ) {}
}
```

---

### 3. Error Handling Best Practices

**✅ DO: Use Domain-Specific Exceptions**
```typescript
// Custom exceptions
export class UserNotFoundException extends NotFoundException {
  constructor(userId: string) {
    super(`User with ID ${userId} not found`);
  }
}

export class EmailAlreadyExistsException extends ConflictException {
  constructor(email: string) {
    super(`User with email ${email} already exists`);
  }
}

// Usage in service
@Injectable()
export class UsersService {
  async findById(id: string): Promise<User> {
    const user = await this.userRepository.findById(id);
    if (!user) {
      throw new UserNotFoundException(id);
    }
    return user;
  }
}
```

**✅ DO: Implement Global Exception Filter**
```typescript
@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  private readonly logger = new Logger(AllExceptionsFilter.name);

  catch(exception: unknown, host: ArgumentsHost): void {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();

    let status = HttpStatus.INTERNAL_SERVER_ERROR;
    let message = 'Internal server error';

    if (exception instanceof HttpException) {
      status = exception.getStatus();
      message = exception.message;
    } else if (exception instanceof Error) {
      message = exception.message;
    }

    const errorResponse = {
      statusCode: status,
      timestamp: new Date().toISOString(),
      path: request.url,
      method: request.method,
      message,
    };

    // Log error for monitoring
    this.logger.error(
      `${request.method} ${request.url}`,
      exception instanceof Error ? exception.stack : exception,
    );

    response.status(status).json(errorResponse);
  }
}
```

---

## 🔐 Security Best Practices

### 1. Authentication & Authorization

**✅ DO: Implement Comprehensive JWT Strategy**
```typescript
@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(
    private readonly configService: ConfigService,
    private readonly userService: UserService,
  ) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: configService.get('JWT_SECRET'),
      // Additional security options
      algorithms: ['HS256'],
    });
  }

  async validate(payload: JwtPayload): Promise<User> {
    // Always verify user still exists and is active
    const user = await this.userService.findById(payload.sub);
    if (!user || !user.isActive) {
      throw new UnauthorizedException('User not found or inactive');
    }

    // Check if token is blacklisted (if implementing token blacklist)
    if (await this.authService.isTokenBlacklisted(payload.jti)) {
      throw new UnauthorizedException('Token has been revoked');
    }

    return user;
  }
}
```

**✅ DO: Use Strong Password Validation**
```typescript
export class CreateUserDto {
  @IsEmail()
  @Transform(({ value }) => value.toLowerCase().trim())
  email: string;

  @IsString()
  @MinLength(8)
  @MaxLength(128)
  @Matches(
    /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]/,
    {
      message: 'Password must contain at least one lowercase letter, one uppercase letter, one number and one special character',
    },
  )
  password: string;
}
```

**✅ DO: Implement Rate Limiting**
```typescript
// Global rate limiting
@Module({
  imports: [
    ThrottlerModule.forRootAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        ttl: config.get('THROTTLE_TTL'),
        limit: config.get('THROTTLE_LIMIT'),
      }),
    }),
  ],
})
export class AppModule {}

// Route-specific rate limiting
@Controller('auth')
@UseGuards(ThrottlerGuard)
export class AuthController {
  @Post('login')
  @Throttle(5, 60) // 5 attempts per minute
  async login(@Body() loginDto: LoginDto) {
    return this.authService.login(loginDto);
  }
}
```

---

### 2. Input Validation & Sanitization

**✅ DO: Validate All Input Data**
```typescript
export class CreatePostDto {
  @IsString()
  @IsNotEmpty()
  @Length(5, 200)
  @Transform(({ value }) => value.trim())
  title: string;

  @IsString()
  @IsNotEmpty()
  @Transform(({ value }) => sanitizeHtml(value))
  content: string;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  @ArrayMaxSize(10)
  tags?: string[];

  @IsOptional()
  @IsUrl()
  featuredImage?: string;
}
```

**✅ DO: Use Proper Sanitization**
```typescript
import DOMPurify from 'isomorphic-dompurify';

export function sanitizeHtml(dirty: string): string {
  return DOMPurify.sanitize(dirty, {
    ALLOWED_TAGS: ['b', 'i', 'em', 'strong', 'a', 'p', 'br', 'ul', 'ol', 'li'],
    ALLOWED_ATTR: ['href'],
    ALLOW_DATA_ATTR: false,
  });
}

// Custom decorator for auto-sanitization
export function SanitizeHtml() {
  return Transform(({ value }) => sanitizeHtml(value));
}
```

---

## 📊 Database Best Practices

### 1. Entity Design

**✅ DO: Use Proper Entity Relationships**
```typescript
@Entity('users')
export class User {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ unique: true })
  @Index() // Add indexes for frequently queried fields
  email: string;

  @Column()
  firstName: string;

  @Column()
  lastName: string;

  @Column()
  @Exclude({ toPlainOnly: true }) // Never expose password
  password: string;

  @ManyToMany(() => Role, role => role.users, {
    cascade: true,
    eager: false, // Avoid N+1 queries
  })
  @JoinTable()
  roles: Role[];

  @OneToMany(() => Post, post => post.author, {
    cascade: true,
  })
  posts: Post[];

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;

  @DeleteDateColumn()
  deletedAt: Date; // Soft delete

  // Add computed properties
  @AfterLoad()
  setComputed() {
    this.fullName = `${this.firstName} ${this.lastName}`;
  }

  fullName: string;
}
```

**✅ DO: Use Repository Pattern**
```typescript
@Injectable()
export class UsersRepository {
  constructor(
    @InjectRepository(User)
    private readonly repository: Repository<User>,
  ) {}

  async findById(id: string): Promise<User | null> {
    return this.repository.findOne({
      where: { id },
      relations: ['roles'],
    });
  }

  async findByEmailWithRoles(email: string): Promise<User | null> {
    return this.repository
      .createQueryBuilder('user')
      .leftJoinAndSelect('user.roles', 'role')
      .where('user.email = :email', { email })
      .getOne();
  }

  async findActiveUsers(
    page: number = 1,
    limit: number = 10,
  ): Promise<[User[], number]> {
    return this.repository
      .createQueryBuilder('user')
      .where('user.deletedAt IS NULL')
      .andWhere('user.isActive = :isActive', { isActive: true })
      .skip((page - 1) * limit)
      .take(limit)
      .getManyAndCount();
  }

  async save(user: User): Promise<User> {
    return this.repository.save(user);
  }

  async softDelete(id: string): Promise<void> {
    await this.repository.softDelete(id);
  }
}
```

---

### 2. Migration Best Practices

**✅ DO: Write Safe Migrations**
```typescript
export class AddUserRoles1634567890123 implements MigrationInterface {
  name = 'AddUserRoles1634567890123';

  public async up(queryRunner: QueryRunner): Promise<void> {
    // Create new table
    await queryRunner.createTable(
      new Table({
        name: 'roles',
        columns: [
          {
            name: 'id',
            type: 'uuid',
            isPrimary: true,
            generationStrategy: 'uuid',
            default: 'uuid_generate_v4()',
          },
          {
            name: 'name',
            type: 'varchar',
            isUnique: true,
          },
          {
            name: 'description',
            type: 'text',
            isNullable: true,
          },
        ],
      }),
      true,
    );

    // Add foreign key safely
    await queryRunner.addColumn(
      'users',
      new TableColumn({
        name: 'role_id',
        type: 'uuid',
        isNullable: true, // Allow null during migration
      }),
    );

    // Create foreign key
    await queryRunner.createForeignKey(
      'users',
      new TableForeignKey({
        columnNames: ['role_id'],
        referencedTableName: 'roles',
        referencedColumnNames: ['id'],
        onDelete: 'SET NULL',
      }),
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    const table = await queryRunner.getTable('users');
    const foreignKey = table.foreignKeys.find(
      fk => fk.columnNames.indexOf('role_id') !== -1,
    );
    
    if (foreignKey) {
      await queryRunner.dropForeignKey('users', foreignKey);
    }
    
    await queryRunner.dropColumn('users', 'role_id');
    await queryRunner.dropTable('roles');
  }
}
```

---

## 🚀 Performance Best Practices

### 1. Query Optimization

**✅ DO: Use Efficient Queries**
```typescript
@Injectable()
export class PostsService {
  // Good: Use select to limit fields
  async findPostSummaries(): Promise<PostSummary[]> {
    return this.postRepository
      .createQueryBuilder('post')
      .select(['post.id', 'post.title', 'post.createdAt'])
      .leftJoin('post.author', 'author')
      .addSelect(['author.id', 'author.firstName', 'author.lastName'])
      .where('post.isPublished = :isPublished', { isPublished: true })
      .orderBy('post.createdAt', 'DESC')
      .limit(20)
      .getMany();
  }

  // Good: Use pagination
  async findPosts(
    page: number = 1,
    limit: number = 10,
  ): Promise<PaginatedResult<Post>> {
    const [posts, total] = await this.postRepository
      .createQueryBuilder('post')
      .leftJoinAndSelect('post.author', 'author')
      .skip((page - 1) * limit)
      .take(limit)
      .getManyAndCount();

    return {
      data: posts,
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit),
    };
  }
}
```

**❌ DON'T: Load Unnecessary Data**
```typescript
// Bad: Loading all data
async findPosts(): Promise<Post[]> {
  return this.postRepository.find({
    relations: ['author', 'comments', 'tags'], // Loads everything
  });
}
```

---

### 2. Caching Strategies

**✅ DO: Implement Strategic Caching**
```typescript
@Injectable()
export class CacheService {
  constructor(
    @Inject(CACHE_MANAGER) private cacheManager: Cache,
  ) {}

  async getOrSet<T>(
    key: string,
    factory: () => Promise<T>,
    ttl: number = 300,
  ): Promise<T> {
    let result = await this.cacheManager.get<T>(key);
    
    if (result === undefined) {
      result = await factory();
      await this.cacheManager.set(key, result, ttl);
    }
    
    return result;
  }
}

@Injectable()
export class UsersService {
  constructor(
    private readonly userRepository: UsersRepository,
    private readonly cacheService: CacheService,
  ) {}

  async findById(id: string): Promise<User> {
    return this.cacheService.getOrSet(
      `user:${id}`,
      () => this.userRepository.findById(id),
      600, // 10 minutes
    );
  }

  async updateUser(id: string, updateData: UpdateUserDto): Promise<User> {
    const user = await this.userRepository.update(id, updateData);
    
    // Invalidate cache
    await this.cacheService.delete(`user:${id}`);
    
    return user;
  }
}
```

---

## 🧪 Testing Best Practices

### 1. Unit Testing

**✅ DO: Write Focused Unit Tests**
```typescript
describe('UsersService', () => {
  let service: UsersService;
  let mockRepository: jest.Mocked<UsersRepository>;

  beforeEach(async () => {
    const mockRepo = {
      findById: jest.fn(),
      findByEmail: jest.fn(),
      save: jest.fn(),
      delete: jest.fn(),
    };

    const module = await Test.createTestingModule({
      providers: [
        UsersService,
        {
          provide: 'IUsersRepository',
          useValue: mockRepo,
        },
      ],
    }).compile();

    service = module.get<UsersService>(UsersService);
    mockRepository = module.get('IUsersRepository');
  });

  describe('findById', () => {
    it('should return user when found', async () => {
      // Arrange
      const userId = '123';
      const expectedUser = createMockUser({ id: userId });
      mockRepository.findById.mockResolvedValue(expectedUser);

      // Act
      const result = await service.findById(userId);

      // Assert
      expect(result).toEqual(expectedUser);
      expect(mockRepository.findById).toHaveBeenCalledWith(userId);
    });

    it('should throw UserNotFoundException when user not found', async () => {
      // Arrange
      const userId = '999';
      mockRepository.findById.mockResolvedValue(null);

      // Act & Assert
      await expect(service.findById(userId)).rejects.toThrow(
        UserNotFoundException,
      );
    });
  });
});
```

---

### 2. Integration Testing

**✅ DO: Test Database Interactions**
```typescript
describe('UsersRepository Integration', () => {
  let repository: UsersRepository;
  let connection: Connection;

  beforeAll(async () => {
    const module = await Test.createTestingModule({
      imports: [
        TypeOrmModule.forRoot({
          type: 'sqlite',
          database: ':memory:',
          entities: [User, Role],
          synchronize: true,
        }),
        TypeOrmModule.forFeature([User, Role]),
      ],
      providers: [UsersRepository],
    }).compile();

    repository = module.get<UsersRepository>(UsersRepository);
    connection = module.get<Connection>(Connection);
  });

  afterEach(async () => {
    await connection.query('DELETE FROM users');
  });

  afterAll(async () => {
    await connection.close();
  });

  it('should save and retrieve user', async () => {
    // Arrange
    const userData = {
      email: 'test@example.com',
      firstName: 'John',
      lastName: 'Doe',
      password: 'hashedPassword',
    };

    // Act
    const savedUser = await repository.save(userData);
    const retrievedUser = await repository.findById(savedUser.id);

    // Assert
    expect(retrievedUser).toBeDefined();
    expect(retrievedUser.email).toBe(userData.email);
  });
});
```

---

## 🛠️ Configuration Best Practices

### 1. Environment Configuration

**✅ DO: Use Typed Configuration**
```typescript
export interface DatabaseConfig {
  host: string;
  port: number;
  username: string;
  password: string;
  database: string;
}

export interface AppConfig {
  port: number;
  environment: string;
  database: DatabaseConfig;
  jwt: {
    secret: string;
    expiresIn: string;
  };
}

@Injectable()
export class ConfigService {
  private readonly config: AppConfig;

  constructor() {
    this.config = {
      port: parseInt(process.env.PORT, 10) || 3000,
      environment: process.env.NODE_ENV || 'development',
      database: {
        host: process.env.DB_HOST || 'localhost',
        port: parseInt(process.env.DB_PORT, 10) || 5432,
        username: process.env.DB_USERNAME || 'postgres',
        password: process.env.DB_PASSWORD || 'password',
        database: process.env.DB_NAME || 'myapp',
      },
      jwt: {
        secret: process.env.JWT_SECRET || 'default-secret',
        expiresIn: process.env.JWT_EXPIRES_IN || '15m',
      },
    };

    this.validateConfig();
  }

  get<K extends keyof AppConfig>(key: K): AppConfig[K] {
    return this.config[key];
  }

  private validateConfig(): void {
    if (this.config.environment === 'production') {
      if (this.config.jwt.secret === 'default-secret') {
        throw new Error('JWT_SECRET must be set in production');
      }
    }
  }
}
```

---

### 2. Logging Best Practices

**✅ DO: Implement Structured Logging**
```typescript
@Injectable()
export class LoggerService {
  private readonly logger = new Logger(LoggerService.name);

  logUserAction(userId: string, action: string, metadata?: object): void {
    this.logger.log({
      message: `User action: ${action}`,
      userId,
      action,
      timestamp: new Date().toISOString(),
      ...metadata,
    });
  }

  logError(error: Error, context?: string, metadata?: object): void {
    this.logger.error({
      message: error.message,
      stack: error.stack,
      context,
      timestamp: new Date().toISOString(),
      ...metadata,
    });
  }

  logPerformance(operation: string, duration: number, metadata?: object): void {
    this.logger.log({
      message: `Performance: ${operation}`,
      operation,
      duration,
      timestamp: new Date().toISOString(),
      ...metadata,
    });
  }
}
```

---

## 📦 Deployment Best Practices

### 1. Docker Best Practices

**✅ DO: Use Multi-Stage Builds**
```dockerfile
# Build stage
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force
COPY . .
RUN npm run build

# Production stage
FROM node:18-alpine AS production
RUN addgroup -g 1001 -S nodejs
RUN adduser -S nestjs -u 1001
WORKDIR /app

# Copy only necessary files
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/package*.json ./

# Security
USER nestjs
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1

CMD ["node", "dist/main"]
```

---

### 2. Health Checks

**✅ DO: Implement Comprehensive Health Checks**
```typescript
@Controller('health')
export class HealthController {
  constructor(
    @InjectConnection() private readonly connection: Connection,
    @Inject(CACHE_MANAGER) private readonly cacheManager: Cache,
  ) {}

  @Get()
  @Public()
  async check(): Promise<HealthCheckResult> {
    const checks = await Promise.allSettled([
      this.checkDatabase(),
      this.checkCache(),
      this.checkMemory(),
    ]);

    const results = checks.map((check, index) => ({
      name: ['database', 'cache', 'memory'][index],
      status: check.status === 'fulfilled' ? 'healthy' : 'unhealthy',
      details: check.status === 'fulfilled' ? check.value : check.reason,
    }));

    const isHealthy = results.every(result => result.status === 'healthy');

    return {
      status: isHealthy ? 'healthy' : 'unhealthy',
      timestamp: new Date().toISOString(),
      checks: results,
    };
  }

  private async checkDatabase(): Promise<object> {
    const start = Date.now();
    await this.connection.query('SELECT 1');
    return { responseTime: Date.now() - start };
  }

  private async checkCache(): Promise<object> {
    const start = Date.now();
    await this.cacheManager.set('health-check', 'ok', 10);
    await this.cacheManager.get('health-check');
    return { responseTime: Date.now() - start };
  }

  private async checkMemory(): Promise<object> {
    const memoryUsage = process.memoryUsage();
    return {
      heapUsed: Math.round(memoryUsage.heapUsed / 1024 / 1024),
      heapTotal: Math.round(memoryUsage.heapTotal / 1024 / 1024),
      external: Math.round(memoryUsage.external / 1024 / 1024),
    };
  }
}
```

---

## 🔗 Navigation

**Previous:** [Implementation Guide](./implementation-guide.md) - Practical implementation guidance  
**Next:** [Comparison Analysis](./comparison-analysis.md) - Comparative analysis of approaches

---

*Best practices guide completed July 2025 - Based on proven patterns from 30+ production NestJS applications*