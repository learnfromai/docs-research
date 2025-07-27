# Best Practices: Production-Ready NestJS Development

## 🏗️ Architecture & Design Patterns

### 1. Domain-Driven Design (DDD) Module Organization

**Recommended Module Structure:**
```
src/modules/
├── auth/                      # Authentication domain
│   ├── auth.controller.ts
│   ├── auth.service.ts
│   ├── auth.module.ts
│   ├── dto/
│   ├── entities/
│   ├── guards/
│   └── strategies/
├── users/                     # User management domain
├── orders/                    # Business domain
├── payments/                  # Payment processing domain
└── shared/                    # Shared business logic
    ├── interfaces/
    ├── enums/
    └── types/
```

**Module Best Practices:**
- **Single Responsibility**: Each module handles one business domain
- **Loose Coupling**: Modules communicate through well-defined interfaces
- **High Cohesion**: Related functionality grouped together
- **Clear Boundaries**: Explicit imports/exports between modules

### 2. Service Layer Architecture

```typescript
// Good: Layered service architecture
@Injectable()
export class UserService {
  constructor(
    private readonly userRepository: UserRepository,
    private readonly emailService: EmailService,
    private readonly cacheService: CacheService,
  ) {}

  async createUser(createUserDto: CreateUserDto): Promise<User> {
    // 1. Validation layer
    await this.validateUserData(createUserDto);
    
    // 2. Business logic layer
    const user = await this.userRepository.create(createUserDto);
    
    // 3. Side effects layer
    await this.emailService.sendWelcomeEmail(user.email);
    await this.cacheService.invalidateUserCache();
    
    return user;
  }

  private async validateUserData(data: CreateUserDto): Promise<void> {
    const existingUser = await this.userRepository.findByEmail(data.email);
    if (existingUser) {
      throw new ConflictException('User already exists');
    }
  }
}
```

### 3. Repository Pattern Implementation

```typescript
// Abstract repository interface
export abstract class BaseRepository<T> {
  abstract create(entity: Partial<T>): Promise<T>;
  abstract findById(id: string): Promise<T | null>;
  abstract findAll(options?: FindOptions): Promise<T[]>;
  abstract update(id: string, updates: Partial<T>): Promise<T>;
  abstract delete(id: string): Promise<void>;
}

// Concrete implementation
@Injectable()
export class UserRepository extends BaseRepository<User> {
  constructor(
    @InjectRepository(User)
    private readonly userRepo: Repository<User>,
  ) {
    super();
  }

  async create(userData: Partial<User>): Promise<User> {
    const user = this.userRepo.create(userData);
    return this.userRepo.save(user);
  }

  async findByEmail(email: string): Promise<User | null> {
    return this.userRepo.findOne({ where: { email } });
  }

  // Custom business queries
  async findActiveUsers(): Promise<User[]> {
    return this.userRepo.find({ where: { isActive: true } });
  }
}
```

## 🔐 Security Best Practices

### 1. Input Validation & Sanitization

```typescript
// Comprehensive validation DTO
export class CreateProductDto {
  @ApiProperty({ description: 'Product name', minLength: 2, maxLength: 100 })
  @IsString()
  @MinLength(2)
  @MaxLength(100)
  @Transform(({ value }) => value?.trim())
  name: string;

  @ApiProperty({ description: 'Product price', minimum: 0 })
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  @Transform(({ value }) => parseFloat(value))
  price: number;

  @ApiProperty({ description: 'Product category' })
  @IsEnum(ProductCategory)
  category: ProductCategory;

  @ApiProperty({ description: 'Product tags', type: [String] })
  @IsArray()
  @ArrayMaxSize(10)
  @IsString({ each: true })
  @Transform(({ value }) => value?.map((tag: string) => tag.trim().toLowerCase()))
  tags: string[];

  @ApiProperty({ description: 'Product description', required: false })
  @IsOptional()
  @IsString()
  @MaxLength(1000)
  @Transform(({ value }) => value?.trim())
  description?: string;
}
```

### 2. Authentication & Authorization

**JWT Implementation with Refresh Tokens:**
```typescript
@Injectable()
export class AuthService {
  constructor(
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
    private readonly usersService: UsersService,
    private readonly redisService: RedisService,
  ) {}

  async login(loginDto: LoginDto): Promise<AuthResponse> {
    const user = await this.validateUser(loginDto.email, loginDto.password);
    
    const tokens = await this.generateTokens(user);
    
    // Store refresh token in Redis with expiration
    await this.redisService.set(
      `refresh_token:${user.id}`,
      tokens.refreshToken,
      'EX',
      this.configService.get('jwt.refreshTokenTtl'),
    );

    // Log successful login
    await this.usersService.updateLastLogin(user.id);

    return {
      user: this.excludePassword(user),
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
    };
  }

  async refreshTokens(refreshToken: string): Promise<AuthResponse> {
    try {
      const payload = this.jwtService.verify(refreshToken, {
        secret: this.configService.get('jwt.refreshSecret'),
      });

      // Verify refresh token exists in Redis
      const storedToken = await this.redisService.get(`refresh_token:${payload.sub}`);
      if (storedToken !== refreshToken) {
        throw new UnauthorizedException('Invalid refresh token');
      }

      const user = await this.usersService.findById(payload.sub);
      const tokens = await this.generateTokens(user);

      // Update refresh token in Redis
      await this.redisService.set(
        `refresh_token:${user.id}`,
        tokens.refreshToken,
        'EX',
        this.configService.get('jwt.refreshTokenTtl'),
      );

      return {
        user: this.excludePassword(user),
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
      };
    } catch (error) {
      throw new UnauthorizedException('Invalid refresh token');
    }
  }

  private async generateTokens(user: User) {
    const payload = { sub: user.id, email: user.email, roles: user.roles };
    
    const [accessToken, refreshToken] = await Promise.all([
      this.jwtService.signAsync(payload, {
        secret: this.configService.get('jwt.secret'),
        expiresIn: this.configService.get('jwt.accessTokenTtl'),
      }),
      this.jwtService.signAsync(payload, {
        secret: this.configService.get('jwt.refreshSecret'),
        expiresIn: this.configService.get('jwt.refreshTokenTtl'),
      }),
    ]);

    return { accessToken, refreshToken };
  }
}
```

**Advanced Role-Based Access Control:**
```typescript
// Custom decorator for granular permissions
export const RequirePermissions = (...permissions: Permission[]) =>
  SetMetadata('permissions', permissions);

// Advanced guard with permission checking
@Injectable()
export class PermissionsGuard implements CanActivate {
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
    
    // Check if user has required permissions through roles
    const userPermissions = this.getUserPermissions(user.roles);
    
    return requiredPermissions.every(permission =>
      userPermissions.includes(permission)
    );
  }

  private getUserPermissions(roles: Role[]): Permission[] {
    const rolePermissions: Record<Role, Permission[]> = {
      [Role.ADMIN]: [Permission.READ_ALL, Permission.WRITE_ALL, Permission.DELETE_ALL],
      [Role.MODERATOR]: [Permission.READ_ALL, Permission.WRITE_USERS],
      [Role.USER]: [Permission.READ_OWN, Permission.WRITE_OWN],
    };

    return roles.flatMap(role => rolePermissions[role] || []);
  }
}

// Usage in controller
@Controller('users')
export class UsersController {
  @Get()
  @UseGuards(JwtAuthGuard, PermissionsGuard)
  @RequirePermissions(Permission.READ_ALL)
  async findAll() {
    return this.usersService.findAll();
  }

  @Delete(':id')
  @UseGuards(JwtAuthGuard, PermissionsGuard)
  @RequirePermissions(Permission.DELETE_ALL)
  async remove(@Param('id') id: string) {
    return this.usersService.remove(id);
  }
}
```

### 3. Rate Limiting & Security Headers

```typescript
// Advanced rate limiting configuration
@Module({
  imports: [
    ThrottlerModule.forRootAsync({
      imports: [ConfigModule],
      useFactory: (configService: ConfigService) => ({
        storage: new ThrottlerStorageRedisService(
          new Redis(configService.get('redis')),
        ),
        throttlers: [
          {
            name: 'short',
            ttl: 60000, // 1 minute
            limit: 10,
          },
          {
            name: 'medium',
            ttl: 600000, // 10 minutes
            limit: 100,
          },
          {
            name: 'long',
            ttl: 3600000, // 1 hour
            limit: 1000,
          },
        ],
      }),
      inject: [ConfigService],
    }),
  ],
})
export class AppModule {}

// Custom rate limiting per endpoint
@Controller('auth')
export class AuthController {
  @Post('login')
  @Throttle({ short: { limit: 5, ttl: 60000 } }) // 5 per minute for login
  async login(@Body() loginDto: LoginDto) {
    return this.authService.login(loginDto);
  }

  @Post('forgot-password')
  @Throttle({ medium: { limit: 3, ttl: 600000 } }) // 3 per 10 minutes
  async forgotPassword(@Body() forgotPasswordDto: ForgotPasswordDto) {
    return this.authService.forgotPassword(forgotPasswordDto);
  }
}
```

## 🚀 Performance Optimization

### 1. Database Query Optimization

```typescript
@Injectable()
export class ProductService {
  constructor(
    @InjectRepository(Product)
    private readonly productRepo: Repository<Product>,
  ) {}

  // Good: Optimized query with relations and pagination
  async findProducts(query: FindProductsDto): Promise<PaginatedResponse<Product>> {
    const queryBuilder = this.productRepo
      .createQueryBuilder('product')
      .leftJoinAndSelect('product.category', 'category')
      .leftJoinAndSelect('product.reviews', 'reviews')
      .select([
        'product.id',
        'product.name',
        'product.price',
        'product.imageUrl',
        'category.name',
        'AVG(reviews.rating) as avgRating',
        'COUNT(reviews.id) as reviewCount',
      ])
      .groupBy('product.id, category.id');

    // Dynamic filtering
    if (query.categoryId) {
      queryBuilder.andWhere('category.id = :categoryId', { categoryId: query.categoryId });
    }

    if (query.minPrice) {
      queryBuilder.andWhere('product.price >= :minPrice', { minPrice: query.minPrice });
    }

    if (query.search) {
      queryBuilder.andWhere(
        'product.name ILIKE :search OR product.description ILIKE :search',
        { search: `%${query.search}%` },
      );
    }

    // Pagination
    const total = await queryBuilder.getCount();
    const products = await queryBuilder
      .skip((query.page - 1) * query.limit)
      .take(query.limit)
      .orderBy('product.createdAt', 'DESC')
      .getRawAndEntities();

    return {
      data: products.entities,
      meta: {
        total,
        page: query.page,
        limit: query.limit,
        totalPages: Math.ceil(total / query.limit),
      },
    };
  }

  // Database indexing suggestions
  /*
  CREATE INDEX idx_products_category_id ON products(category_id);
  CREATE INDEX idx_products_price ON products(price);
  CREATE INDEX idx_products_name_gin ON products USING gin(to_tsvector('english', name));
  CREATE INDEX idx_products_created_at ON products(created_at);
  */
}
```

### 2. Caching Strategies

```typescript
// Multi-level caching implementation
@Injectable()
export class CachedProductService {
  constructor(
    private readonly productService: ProductService,
    private readonly cacheService: CacheService,
    private readonly redisService: RedisService,
  ) {}

  async getProduct(id: string): Promise<Product> {
    const cacheKey = `product:${id}`;
    
    // L1 Cache: Memory cache (fastest)
    let product = await this.cacheService.get<Product>(cacheKey);
    if (product) {
      return product;
    }

    // L2 Cache: Redis cache (fast)
    const cachedProduct = await this.redisService.get(cacheKey);
    if (cachedProduct) {
      product = JSON.parse(cachedProduct);
      // Populate L1 cache
      await this.cacheService.set(cacheKey, product, 300); // 5 minutes
      return product;
    }

    // L3: Database (slowest)
    product = await this.productService.findById(id);
    if (product) {
      // Populate both caches
      await Promise.all([
        this.cacheService.set(cacheKey, product, 300), // 5 minutes
        this.redisService.setex(cacheKey, 1800, JSON.stringify(product)), // 30 minutes
      ]);
    }

    return product;
  }

  async invalidateProductCache(id: string): Promise<void> {
    const cacheKey = `product:${id}`;
    await Promise.all([
      this.cacheService.del(cacheKey),
      this.redisService.del(cacheKey),
      // Invalidate related caches
      this.redisService.del(`products:category:${product.categoryId}`),
    ]);
  }
}

// Cache warming strategy
@Cron('0 */6 * * *') // Every 6 hours
async warmCache(): Promise<void> {
  const popularProducts = await this.productService.findPopularProducts(100);
  
  await Promise.all(
    popularProducts.map(product =>
      this.getProduct(product.id), // This will populate the cache
    ),
  );
}
```

### 3. Background Job Processing

```typescript
// Queue processor for background jobs
@Processor('email')
export class EmailProcessor {
  private readonly logger = new Logger(EmailProcessor.name);

  constructor(private readonly emailService: EmailService) {}

  @Process('welcome')
  async handleWelcomeEmail(job: Job<WelcomeEmailData>) {
    this.logger.log(`Processing welcome email for user ${job.data.userId}`);
    
    try {
      await this.emailService.sendWelcomeEmail(job.data);
      this.logger.log(`Welcome email sent successfully to ${job.data.email}`);
    } catch (error) {
      this.logger.error(`Failed to send welcome email: ${error.message}`);
      throw error; // This will retry the job
    }
  }

  @Process('password-reset')
  async handlePasswordResetEmail(job: Job<PasswordResetEmailData>) {
    this.logger.log(`Processing password reset email for ${job.data.email}`);
    
    try {
      await this.emailService.sendPasswordResetEmail(job.data);
    } catch (error) {
      this.logger.error(`Failed to send password reset email: ${error.message}`);
      throw error;
    }
  }
}

// Service using queues
@Injectable()
export class UserService {
  constructor(
    @InjectQueue('email') private readonly emailQueue: Queue,
  ) {}

  async createUser(createUserDto: CreateUserDto): Promise<User> {
    const user = await this.userRepository.create(createUserDto);

    // Queue welcome email (non-blocking)
    await this.emailQueue.add(
      'welcome',
      {
        userId: user.id,
        email: user.email,
        firstName: user.firstName,
      },
      {
        delay: 5000, // 5 second delay
        attempts: 3,
        backoff: {
          type: 'exponential',
          delay: 2000,
        },
      },
    );

    return user;
  }
}
```

## 🧪 Testing Best Practices

### 1. Unit Testing Strategy

```typescript
// Comprehensive service testing
describe('UserService', () => {
  let service: UserService;
  let userRepository: MockRepository<User>;
  let emailQueue: MockQueue;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        UserService,
        {
          provide: getRepositoryToken(User),
          useValue: createMockRepository(),
        },
        {
          provide: getQueueToken('email'),
          useValue: createMockQueue(),
        },
      ],
    }).compile();

    service = module.get<UserService>(UserService);
    userRepository = module.get(getRepositoryToken(User));
    emailQueue = module.get(getQueueToken('email'));
  });

  describe('createUser', () => {
    it('should create user and queue welcome email', async () => {
      // Arrange
      const createUserDto: CreateUserDto = {
        email: 'test@example.com',
        firstName: 'John',
        lastName: 'Doe',
        password: 'password123',
      };

      const expectedUser = { id: '1', ...createUserDto };
      userRepository.create.mockReturnValue(expectedUser);
      userRepository.save.mockResolvedValue(expectedUser);

      // Act
      const result = await service.createUser(createUserDto);

      // Assert
      expect(userRepository.create).toHaveBeenCalledWith(createUserDto);
      expect(userRepository.save).toHaveBeenCalledWith(expectedUser);
      expect(emailQueue.add).toHaveBeenCalledWith(
        'welcome',
        {
          userId: '1',
          email: 'test@example.com',
          firstName: 'John',
        },
        expect.objectContaining({
          delay: 5000,
          attempts: 3,
        }),
      );
      expect(result).toEqual(expectedUser);
    });

    it('should throw ConflictException when user already exists', async () => {
      // Arrange
      const createUserDto: CreateUserDto = {
        email: 'existing@example.com',
        firstName: 'John',
        lastName: 'Doe',
        password: 'password123',
      };

      userRepository.findOne.mockResolvedValue({ id: '1' } as User);

      // Act & Assert
      await expect(service.createUser(createUserDto)).rejects.toThrow(
        ConflictException,
      );
    });
  });
});
```

### 2. Integration Testing

```typescript
// Database integration testing
describe('UserController (Integration)', () => {
  let app: INestApplication;
  let userRepository: Repository<User>;
  let emailQueue: Queue;

  beforeEach(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [
        TypeOrmModule.forRoot({
          type: 'sqlite',
          database: ':memory:',
          entities: [User],
          synchronize: true,
        }),
        BullModule.forRoot({
          redis: {
            host: 'localhost',
            port: 6379,
          },
        }),
        AppModule,
      ],
    }).compile();

    app = moduleFixture.createNestApplication();
    app.useGlobalPipes(new ValidationPipe());
    await app.init();

    userRepository = moduleFixture.get(getRepositoryToken(User));
    emailQueue = moduleFixture.get(getQueueToken('email'));
  });

  afterEach(async () => {
    await userRepository.clear();
    await emailQueue.clean(0, 'completed');
    await emailQueue.clean(0, 'failed');
    await app.close();
  });

  describe('/users (POST)', () => {
    it('should create user and process welcome email job', async () => {
      const createUserDto = {
        email: 'test@example.com',
        firstName: 'John',
        lastName: 'Doe',
        password: 'password123',
      };

      const response = await request(app.getHttpServer())
        .post('/users')
        .send(createUserDto)
        .expect(201);

      // Verify user was created in database
      const user = await userRepository.findOne({
        where: { email: createUserDto.email },
      });
      expect(user).toBeDefined();
      expect(user.email).toBe(createUserDto.email);

      // Verify welcome email job was queued
      const jobs = await emailQueue.getJobs(['waiting', 'delayed']);
      expect(jobs).toHaveLength(1);
      expect(jobs[0].data).toMatchObject({
        userId: user.id,
        email: createUserDto.email,
        firstName: createUserDto.firstName,
      });
    });
  });
});
```

## 🐳 DevOps & Deployment

### 1. Production Docker Configuration

```dockerfile
# Multi-stage production Dockerfile
FROM node:18-alpine AS builder

WORKDIR /usr/src/app

# Copy dependency files
COPY package*.json ./
COPY pnpm-lock.yaml ./

# Install dependencies
RUN npm install -g pnpm
RUN pnpm install --frozen-lockfile

# Copy source code
COPY . .

# Build application
RUN pnpm run build

# Remove dev dependencies
RUN pnpm prune --prod

# Production stage
FROM node:18-alpine AS production

# Create non-root user for security
RUN addgroup -g 1001 -S nodejs
RUN adduser -S nestjs -u 1001

WORKDIR /usr/src/app

# Copy built application
COPY --from=builder --chown=nestjs:nodejs /usr/src/app/dist ./dist
COPY --from=builder --chown=nestjs:nodejs /usr/src/app/node_modules ./node_modules
COPY --from=builder --chown=nestjs:nodejs /usr/src/app/package*.json ./

# Set environment
ENV NODE_ENV=production
ENV PORT=3000

# Expose port
EXPOSE 3000

# Switch to non-root user
USER nestjs

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node dist/health-check.js

# Start application
CMD ["node", "dist/main"]
```

### 2. Kubernetes Deployment

```yaml
# k8s/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nestjs-app
  labels:
    app: nestjs-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nestjs-app
  template:
    metadata:
      labels:
        app: nestjs-app
    spec:
      containers:
      - name: nestjs-app
        image: your-registry/nestjs-app:latest
        ports:
        - containerPort: 3000
        env:
        - name: NODE_ENV
          value: "production"
        - name: DB_HOST
          valueFrom:
            secretKeyRef:
              name: app-secrets
              key: db-host
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: app-secrets
              key: db-password
        - name: JWT_SECRET
          valueFrom:
            secretKeyRef:
              name: app-secrets
              key: jwt-secret
        livenessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health/ready
            port: 3000
          initialDelaySeconds: 5
          periodSeconds: 5
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
```

### 3. Monitoring & Observability

```typescript
// Prometheus metrics integration
@Injectable()
export class MetricsService {
  private readonly httpRequestsTotal = new Counter({
    name: 'http_requests_total',
    help: 'Total number of HTTP requests',
    labelNames: ['method', 'route', 'status_code'],
  });

  private readonly httpRequestDuration = new Histogram({
    name: 'http_request_duration_seconds',
    help: 'Duration of HTTP requests in seconds',
    labelNames: ['method', 'route'],
    buckets: [0.1, 0.3, 0.5, 0.7, 1, 3, 5, 7, 10],
  });

  private readonly activeConnections = new Gauge({
    name: 'active_connections',
    help: 'Number of active connections',
  });

  recordHttpRequest(method: string, route: string, statusCode: number, duration: number) {
    this.httpRequestsTotal.labels(method, route, statusCode.toString()).inc();
    this.httpRequestDuration.labels(method, route).observe(duration);
  }

  setActiveConnections(count: number) {
    this.activeConnections.set(count);
  }
}

// Metrics interceptor
@Injectable()
export class MetricsInterceptor implements NestInterceptor {
  constructor(private readonly metricsService: MetricsService) {}

  intercept(context: ExecutionContext, next: CallHandler): Observable<any> {
    const request = context.switchToHttp().getRequest();
    const startTime = Date.now();

    return next.handle().pipe(
      tap(() => {
        const response = context.switchToHttp().getResponse();
        const duration = (Date.now() - startTime) / 1000;
        
        this.metricsService.recordHttpRequest(
          request.method,
          request.route?.path || request.url,
          response.statusCode,
          duration,
        );
      }),
    );
  }
}
```

## 📝 Documentation Best Practices

### 1. API Documentation with Swagger

```typescript
// Comprehensive API documentation
@ApiTags('Users')
@Controller('users')
@ApiBearerAuth()
export class UsersController {
  @Post()
  @ApiOperation({
    summary: 'Create new user',
    description: 'Creates a new user account with email verification',
  })
  @ApiResponse({
    status: 201,
    description: 'User created successfully',
    type: UserResponseDto,
  })
  @ApiResponse({
    status: 400,
    description: 'Validation error',
    type: ValidationErrorDto,
  })
  @ApiResponse({
    status: 409,
    description: 'User already exists',
    type: ErrorResponseDto,
  })
  async create(@Body() createUserDto: CreateUserDto): Promise<UserResponseDto> {
    return this.usersService.create(createUserDto);
  }

  @Get(':id')
  @ApiOperation({
    summary: 'Get user by ID',
    description: 'Retrieves user information by user ID',
  })
  @ApiParam({
    name: 'id',
    description: 'User ID',
    type: 'string',
    format: 'uuid',
  })
  @ApiResponse({
    status: 200,
    description: 'User found',
    type: UserResponseDto,
  })
  @ApiResponse({
    status: 404,
    description: 'User not found',
    type: ErrorResponseDto,
  })
  async findOne(@Param('id', ParseUUIDPipe) id: string): Promise<UserResponseDto> {
    return this.usersService.findOne(id);
  }
}
```

## 🔗 Next Steps

1. **Review** [Security Considerations](./security-considerations.md) for advanced security patterns
2. **Explore** [Comparison Analysis](./comparison-analysis.md) for different architectural approaches
3. **Use** [Template Examples](./template-examples.md) for quick project setup

---

## 🔗 Navigation

**Previous:** [Implementation Guide](./implementation-guide.md)  
**Next:** [Security Considerations](./security-considerations.md)

---

*Last updated: July 27, 2025*