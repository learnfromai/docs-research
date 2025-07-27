# Best Practices

## 🎯 Overview

Comprehensive compilation of best practices extracted from production-ready NestJS open source projects. These practices represent proven patterns for building secure, scalable, and maintainable applications.

## 🏗️ Project Structure & Organization

### **Feature-Based Module Organization** (90% adoption)
```
src/
├── modules/
│   ├── auth/
│   │   ├── auth.controller.ts
│   │   ├── auth.service.ts
│   │   ├── auth.module.ts
│   │   ├── dto/
│   │   ├── guards/
│   │   └── strategies/
│   ├── users/
│   │   ├── users.controller.ts
│   │   ├── users.service.ts
│   │   ├── users.module.ts
│   │   ├── entities/
│   │   └── dto/
│   └── posts/
├── shared/
│   ├── guards/
│   ├── interceptors/
│   ├── pipes/
│   ├── decorators/
│   └── utils/
├── config/
├── database/
└── main.ts
```

### **Module Design Principles**
```typescript
// ✅ Good: Clear module boundaries
@Module({
  imports: [
    TypeOrmModule.forFeature([User, Profile]),
    JwtModule.registerAsync({
      useFactory: (configService: ConfigService) => ({
        secret: configService.get('JWT_SECRET'),
        signOptions: { expiresIn: '1h' },
      }),
      inject: [ConfigService],
    }),
  ],
  controllers: [AuthController],
  providers: [AuthService, JwtStrategy],
  exports: [AuthService], // Only export what's needed
})
export class AuthModule {}
```

## 🔧 Configuration Management

### **Environment-Based Configuration** (95% adoption)
```typescript
// config/database.config.ts
export default registerAs('database', () => ({
  type: process.env.DATABASE_TYPE as 'postgres' | 'mysql',
  host: process.env.DATABASE_HOST,
  port: parseInt(process.env.DATABASE_PORT, 10) || 5432,
  username: process.env.DATABASE_USERNAME,
  password: process.env.DATABASE_PASSWORD,
  database: process.env.DATABASE_NAME,
  synchronize: process.env.NODE_ENV === 'development',
  logging: process.env.NODE_ENV === 'development',
  entities: [__dirname + '/../**/*.entity{.ts,.js}'],
  migrations: [__dirname + '/../database/migrations/*{.ts,.js}'],
}));
```

### **Configuration Validation** (80% adoption)
```typescript
// config/validation.schema.ts
export const configValidationSchema = Joi.object({
  NODE_ENV: Joi.string()
    .valid('development', 'production', 'test')
    .default('development'),
  PORT: Joi.number().default(3000),
  DATABASE_HOST: Joi.string().required(),
  DATABASE_PORT: Joi.number().default(5432),
  JWT_SECRET: Joi.string().min(32).required(),
  REDIS_URL: Joi.string().when('NODE_ENV', {
    is: 'production',
    then: Joi.required(),
    otherwise: Joi.optional(),
  }),
});
```

## 🗄️ Database Best Practices

### **Entity Design** (TypeORM)
```typescript
// ✅ Good: Comprehensive entity with proper relationships
@Entity('users')
export class User {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ unique: true })
  @Index()
  email: string;

  @Column()
  @Exclude({ toPlainOnly: true }) // Never expose in responses
  password: string;

  @Column({ nullable: true })
  firstName?: string;

  @Column({ nullable: true })
  lastName?: string;

  @Column({ default: true })
  isActive: boolean;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;

  @Column({ nullable: true })
  lastLoginAt?: Date;

  // Relationships
  @OneToMany(() => Post, post => post.author)
  posts: Post[];

  @ManyToMany(() => Role)
  @JoinTable()
  roles: Role[];

  // Virtual properties
  @Expose()
  get fullName(): string {
    return `${this.firstName} ${this.lastName}`.trim();
  }

  // Methods
  async validatePassword(password: string): Promise<boolean> {
    return bcrypt.compare(password, this.password);
  }
}
```

### **Repository Pattern** (70% adoption)
```typescript
// Custom repository for complex queries
@Injectable()
export class UserRepository {
  constructor(
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
  ) {}

  async findActiveUsers(page: number = 1, limit: number = 10): Promise<PaginatedResult<User>> {
    const [users, total] = await this.userRepository.findAndCount({
      where: { isActive: true },
      skip: (page - 1) * limit,
      take: limit,
      order: { createdAt: 'DESC' },
      relations: ['roles'],
    });

    return {
      data: users,
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit),
    };
  }

  async findByEmailWithRoles(email: string): Promise<User | null> {
    return this.userRepository.findOne({
      where: { email, isActive: true },
      relations: ['roles'],
    });
  }
}
```

## 🎨 API Design & DTOs

### **DTO Design Patterns**
```typescript
// Base DTO classes
export abstract class BaseDto {
  @ApiProperty()
  @IsUUID()
  id: string;

  @ApiProperty()
  createdAt: Date;

  @ApiProperty()
  updatedAt: Date;
}

// Create DTOs
export class CreateUserDto {
  @ApiProperty({ example: 'user@example.com' })
  @IsEmail()
  @IsNotEmpty()
  email: string;

  @ApiProperty({ minLength: 8, maxLength: 50 })
  @IsString()
  @MinLength(8)
  @MaxLength(50)
  @Matches(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]/, {
    message: 'Password must contain uppercase, lowercase, number and special character',
  })
  password: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  @Length(2, 50)
  @Transform(({ value }) => value?.trim())
  firstName?: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  @Length(2, 50)
  @Transform(({ value }) => value?.trim())
  lastName?: string;
}

// Update DTOs
export class UpdateUserDto extends PartialType(
  OmitType(CreateUserDto, ['email', 'password'] as const)
) {}

// Response DTOs
export class UserResponseDto extends BaseDto {
  @ApiProperty()
  email: string;

  @ApiProperty({ required: false })
  firstName?: string;

  @ApiProperty({ required: false })
  lastName?: string;

  @ApiProperty()
  fullName: string;

  @ApiProperty()
  isActive: boolean;

  @ApiProperty({ type: [RoleDto] })
  roles: RoleDto[];
}
```

### **Pagination & Filtering**
```typescript
// Query DTOs
export class PaginationQueryDto {
  @ApiPropertyOptional({ minimum: 1, default: 1 })
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @IsOptional()
  page?: number = 1;

  @ApiPropertyOptional({ minimum: 1, maximum: 100, default: 10 })
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  @IsOptional()
  limit?: number = 10;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  search?: string;

  @ApiPropertyOptional({ enum: ['ASC', 'DESC'] })
  @IsEnum(['ASC', 'DESC'])
  @IsOptional()
  order?: 'ASC' | 'DESC' = 'DESC';

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  orderBy?: string = 'createdAt';
}

// Pagination response
export class PaginatedResponseDto<T> {
  @ApiProperty({ isArray: true })
  data: T[];

  @ApiProperty()
  total: number;

  @ApiProperty()
  page: number;

  @ApiProperty()
  limit: number;

  @ApiProperty()
  totalPages: number;

  @ApiProperty()
  hasNextPage: boolean;

  @ApiProperty()
  hasPreviousPage: boolean;
}
```

## 🔒 Security Best Practices

### **Input Validation & Sanitization**
```typescript
// Global validation pipe configuration
app.useGlobalPipes(
  new ValidationPipe({
    transform: true,
    whitelist: true, // Remove non-whitelisted properties
    forbidNonWhitelisted: true, // Throw error for non-whitelisted properties
    validateCustomDecorators: true,
    transformOptions: {
      enableImplicitConversion: true,
    },
  }),
);

// Custom sanitization
@Injectable()
export class SanitizationPipe implements PipeTransform {
  transform(value: any) {
    if (typeof value === 'string') {
      return value.trim().replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, '');
    }
    if (typeof value === 'object' && value !== null) {
      return this.sanitizeObject(value);
    }
    return value;
  }

  private sanitizeObject(obj: any): any {
    const sanitized = {};
    for (const key in obj) {
      if (typeof obj[key] === 'string') {
        sanitized[key] = obj[key].trim();
      } else if (typeof obj[key] === 'object') {
        sanitized[key] = this.sanitizeObject(obj[key]);
      } else {
        sanitized[key] = obj[key];
      }
    }
    return sanitized;
  }
}
```

### **Authentication & Authorization Guards**
```typescript
// Flexible role guard
@Injectable()
export class FlexibleRoleGuard implements CanActivate {
  constructor(private reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    // Check for bypass metadata
    const isPublic = this.reflector.getAllAndOverride<boolean>('isPublic', [
      context.getHandler(),
      context.getClass(),
    ]);

    if (isPublic) {
      return true;
    }

    const requiredRoles = this.reflector.getAllAndOverride<string[]>('roles', [
      context.getHandler(),
      context.getClass(),
    ]);

    if (!requiredRoles) {
      return true;
    }

    const { user } = context.switchToHttp().getRequest();
    
    if (!user) {
      return false;
    }

    return requiredRoles.some(role => user.roles?.includes(role));
  }
}

// Usage decorators
export const Public = () => SetMetadata('isPublic', true);
export const Roles = (...roles: string[]) => SetMetadata('roles', roles);
```

## 🧪 Testing Best Practices

### **Test Structure & Organization**
```typescript
// Test utilities
export class TestHelper {
  static async createTestingModule(
    providers: any[] = [],
    imports: any[] = [],
  ): Promise<TestingModule> {
    return Test.createTestingModule({
      imports: [
        ConfigModule.forRoot({
          isGlobal: true,
          envFilePath: '.env.test',
        }),
        TypeOrmModule.forRootAsync({
          useFactory: () => ({
            type: 'sqlite',
            database: ':memory:',
            entities: [User, Post, Role],
            synchronize: true,
          }),
        }),
        ...imports,
      ],
      providers: [...providers],
    }).compile();
  }

  static createMockUser(overrides: Partial<User> = {}): User {
    return {
      id: 'test-id',
      email: 'test@example.com',
      firstName: 'Test',
      lastName: 'User',
      isActive: true,
      createdAt: new Date(),
      updatedAt: new Date(),
      roles: [],
      posts: [],
      ...overrides,
    } as User;
  }
}
```

### **Service Testing Pattern**
```typescript
describe('UserService', () => {
  let service: UserService;
  let repository: Repository<User>;

  beforeEach(async () => {
    const module = await TestHelper.createTestingModule([
      UserService,
      {
        provide: getRepositoryToken(User),
        useClass: Repository,
      },
    ]);

    service = module.get<UserService>(UserService);
    repository = module.get<Repository<User>>(getRepositoryToken(User));
  });

  describe('create', () => {
    it('should create a user successfully', async () => {
      // Arrange
      const createUserDto = {
        email: 'test@example.com',
        password: 'Password123!',
        firstName: 'Test',
      };
      const expectedUser = TestHelper.createMockUser(createUserDto);

      jest.spyOn(repository, 'create').mockReturnValue(expectedUser);
      jest.spyOn(repository, 'save').mockResolvedValue(expectedUser);

      // Act
      const result = await service.create(createUserDto);

      // Assert
      expect(result).toEqual(expectedUser);
      expect(repository.create).toHaveBeenCalledWith(createUserDto);
      expect(repository.save).toHaveBeenCalledWith(expectedUser);
    });

    it('should throw ConflictException when email already exists', async () => {
      // Arrange
      const createUserDto = { email: 'existing@example.com' };
      jest.spyOn(repository, 'save').mockRejectedValue({ code: '23505' });

      // Act & Assert
      await expect(service.create(createUserDto)).rejects.toThrow(ConflictException);
    });
  });
});
```

### **E2E Testing Pattern**
```typescript
describe('AuthController (e2e)', () => {
  let app: INestApplication;
  let userRepository: Repository<User>;

  beforeEach(async () => {
    const moduleFixture = await TestHelper.createTestingModule([], [AuthModule]);

    app = moduleFixture.createNestApplication();
    app.useGlobalPipes(new ValidationPipe());
    
    userRepository = moduleFixture.get<Repository<User>>(getRepositoryToken(User));
    
    await app.init();
  });

  afterEach(async () => {
    await userRepository.clear();
    await app.close();
  });

  describe('/auth/login (POST)', () => {
    it('should login successfully with valid credentials', async () => {
      // Arrange
      const user = await userRepository.save({
        email: 'test@example.com',
        password: await bcrypt.hash('Password123!', 10),
      });

      // Act
      const response = await request(app.getHttpServer())
        .post('/auth/login')
        .send({
          email: 'test@example.com',
          password: 'Password123!',
        })
        .expect(200);

      // Assert
      expect(response.body).toHaveProperty('access_token');
      expect(response.body).toHaveProperty('user');
      expect(response.body.user.email).toBe('test@example.com');
    });
  });
});
```

## 🚀 Performance & Optimization

### **Database Query Optimization**
```typescript
// ✅ Good: Efficient queries with proper indexing
@Injectable()
export class PostService {
  constructor(
    @InjectRepository(Post)
    private postRepository: Repository<Post>,
  ) {}

  async findPublishedPosts(options: FindPostsOptions): Promise<PaginatedResult<Post>> {
    const queryBuilder = this.postRepository
      .createQueryBuilder('post')
      .leftJoinAndSelect('post.author', 'author')
      .leftJoinAndSelect('post.tags', 'tags')
      .where('post.isPublished = :isPublished', { isPublished: true })
      .orderBy('post.createdAt', 'DESC');

    // Apply filters
    if (options.search) {
      queryBuilder.andWhere(
        '(post.title ILIKE :search OR post.content ILIKE :search)',
        { search: `%${options.search}%` }
      );
    }

    if (options.authorId) {
      queryBuilder.andWhere('author.id = :authorId', { authorId: options.authorId });
    }

    // Pagination
    const total = await queryBuilder.getCount();
    const posts = await queryBuilder
      .skip((options.page - 1) * options.limit)
      .take(options.limit)
      .getMany();

    return {
      data: posts,
      total,
      page: options.page,
      limit: options.limit,
      totalPages: Math.ceil(total / options.limit),
    };
  }
}
```

### **Caching Strategy**
```typescript
// Cache decorator
export function Cache(ttl: number = 300) {
  return (target: any, propertyName: string, descriptor: PropertyDescriptor) => {
    const method = descriptor.value;

    descriptor.value = async function (...args: any[]) {
      const redis = this.redis || this.cacheService;
      const cacheKey = `${target.constructor.name}:${propertyName}:${JSON.stringify(args)}`;
      
      const cached = await redis.get(cacheKey);
      if (cached) {
        return JSON.parse(cached);
      }

      const result = await method.apply(this, args);
      await redis.setex(cacheKey, ttl, JSON.stringify(result));
      
      return result;
    };
  };
}

// Usage
@Injectable()
export class UserService {
  constructor(
    @Inject('REDIS_CLIENT') private redis: Redis,
  ) {}

  @Cache(600) // 10 minutes
  async getPopularUsers(limit: number = 10): Promise<User[]> {
    return this.userRepository.find({
      order: { postsCount: 'DESC' },
      take: limit,
    });
  }
}
```

## 📊 Logging & Monitoring

### **Structured Logging**
```typescript
// Logger service
@Injectable()
export class LoggerService {
  private logger = new Logger(LoggerService.name);

  logRequest(request: Request, response: Response, responseTime: number) {
    const { method, originalUrl, ip, headers } = request;
    const { statusCode } = response;

    this.logger.log({
      type: 'http_request',
      method,
      url: originalUrl,
      statusCode,
      responseTime: `${responseTime}ms`,
      ip,
      userAgent: headers['user-agent'],
      timestamp: new Date().toISOString(),
    });
  }

  logError(error: Error, context?: string) {
    this.logger.error({
      type: 'error',
      message: error.message,
      stack: error.stack,
      context,
      timestamp: new Date().toISOString(),
    });
  }

  logBusinessEvent(event: string, data: any, userId?: string) {
    this.logger.log({
      type: 'business_event',
      event,
      data,
      userId,
      timestamp: new Date().toISOString(),
    });
  }
}
```

### **Health Checks**
```typescript
@Controller('health')
export class HealthController {
  constructor(
    private health: HealthCheckService,
    private db: TypeOrmHealthIndicator,
    private redis: HealthIndicator,
  ) {}

  @Get()
  @HealthCheck()
  check() {
    return this.health.check([
      () => this.db.pingCheck('database'),
      () => this.redis.isHealthy('redis'),
      () => this.checkExternalAPI(),
    ]);
  }

  private async checkExternalAPI(): Promise<HealthIndicatorResult> {
    try {
      // Check external dependencies
      await axios.get('https://api.external-service.com/health', { timeout: 5000 });
      return { external_api: { status: 'up' } };
    } catch (error) {
      return { external_api: { status: 'down', message: error.message } };
    }
  }
}
```

## 📋 Code Quality Standards

### **ESLint Configuration**
```json
{
  "extends": [
    "@nestjs",
    "@typescript-eslint/recommended",
    "prettier"
  ],
  "rules": {
    "@typescript-eslint/interface-name-prefix": "off",
    "@typescript-eslint/explicit-function-return-type": "error",
    "@typescript-eslint/explicit-module-boundary-types": "error",
    "@typescript-eslint/no-explicit-any": "warn",
    "prefer-const": "error",
    "no-var": "error"
  }
}
```

### **Pre-commit Hooks**
```json
{
  "husky": {
    "hooks": {
      "pre-commit": "lint-staged",
      "commit-msg": "commitlint -E HUSKY_GIT_PARAMS"
    }
  },
  "lint-staged": {
    "*.{ts,js}": [
      "eslint --fix",
      "prettier --write",
      "git add"
    ]
  }
}
```

---

**Navigation**
- ↑ Back to: [Tools & Libraries](./tools-libraries.md)
- ↓ Next: [Implementation Guide](./implementation-guide.md)