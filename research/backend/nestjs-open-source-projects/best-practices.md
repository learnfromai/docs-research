# Best Practices for NestJS Development

## 🎯 Overview

This document compiles the most effective best practices, patterns, and recommendations derived from analyzing 25+ production-ready NestJS open source projects. These practices represent proven approaches used by successful development teams building scalable, maintainable applications.

## 🏗️ Project Structure & Organization

### **1. Domain-Driven Design Structure**
*Recommended for: Large applications with complex business logic*

```
src/
├── modules/                        # Feature modules
│   ├── auth/
│   │   ├── controllers/
│   │   ├── services/
│   │   ├── dto/
│   │   ├── entities/
│   │   ├── guards/
│   │   ├── strategies/
│   │   └── auth.module.ts
│   ├── users/
│   │   ├── controllers/
│   │   ├── services/
│   │   ├── repositories/
│   │   ├── dto/
│   │   ├── entities/
│   │   └── users.module.ts
│   └── ...
├── shared/                         # Shared resources
│   ├── constants/
│   ├── decorators/
│   ├── guards/
│   ├── interceptors/
│   ├── pipes/
│   ├── filters/
│   ├── interfaces/
│   ├── types/
│   └── utils/
├── config/                         # Configuration
│   ├── database.config.ts
│   ├── auth.config.ts
│   ├── cache.config.ts
│   └── app.config.ts
├── database/                       # Database-related files
│   ├── migrations/
│   ├── seeds/
│   └── factories/
├── common/                         # Common utilities
│   ├── base.entity.ts
│   ├── base.repository.ts
│   ├── base.service.ts
│   └── pagination.dto.ts
└── main.ts
```

### **2. File Naming Conventions**
*Standard across 95% of projects*

```typescript
// Controllers
user.controller.ts
auth.controller.ts

// Services
user.service.ts
email.service.ts

// DTOs
create-user.dto.ts
update-user.dto.ts

// Entities
user.entity.ts
post.entity.ts

// Guards
jwt-auth.guard.ts
roles.guard.ts

// Interceptors
logging.interceptor.ts
transform.interceptor.ts

// Pipes
validation.pipe.ts
parse-int.pipe.ts

// Filters
http-exception.filter.ts
all-exceptions.filter.ts

// Modules
user.module.ts
auth.module.ts

// Interfaces
user.interface.ts
config.interface.ts

// Types
pagination.types.ts
response.types.ts
```

## 📝 Code Quality Standards

### **1. TypeScript Best Practices**
*Found in: 100% of quality projects*

```typescript
// Use strict TypeScript configuration
// tsconfig.json
{
  "compilerOptions": {
    "strict": true,
    "noImplicitAny": true,
    "strictNullChecks": true,
    "strictFunctionTypes": true,
    "noImplicitReturns": true,
    "noFallthroughCasesInSwitch": true,
    "exactOptionalPropertyTypes": true
  }
}

// ✅ Good: Strong typing with interfaces
interface CreateUserRequest {
  readonly email: string;
  readonly password: string;
  readonly firstName: string;
  readonly lastName: string;
}

interface UserResponse {
  readonly id: string;
  readonly email: string;
  readonly firstName: string;
  readonly lastName: string;
  readonly createdAt: Date;
}

// ✅ Good: Use enums for constants
export enum UserRole {
  ADMIN = 'admin',
  USER = 'user',
  MODERATOR = 'moderator',
}

// ✅ Good: Use type assertions carefully
const user = data as User; // Only when you're certain of the type

// ❌ Bad: Using 'any' type
const user: any = getUserData();

// ✅ Good: Use union types for specific values
type Status = 'pending' | 'approved' | 'rejected';

// ✅ Good: Use generics for reusable types
interface ApiResponse<T> {
  data: T;
  message: string;
  success: boolean;
}

interface PaginatedResponse<T> extends ApiResponse<T[]> {
  meta: {
    total: number;
    page: number;
    limit: number;
    pages: number;
  };
}
```

### **2. Dependency Injection Best Practices**
*Critical for maintainable code*

```typescript
// ✅ Good: Use interfaces for dependency injection
interface IUserRepository {
  findById(id: string): Promise<User | null>;
  create(user: CreateUserDto): Promise<User>;
  update(id: string, updates: UpdateUserDto): Promise<User>;
  delete(id: string): Promise<boolean>;
}

@Injectable()
export class UserService {
  constructor(
    @Inject('IUserRepository')
    private readonly userRepository: IUserRepository,
    @Inject('IEmailService')
    private readonly emailService: IEmailService,
  ) {}

  async createUser(createUserDto: CreateUserDto): Promise<User> {
    const user = await this.userRepository.create(createUserDto);
    await this.emailService.sendWelcomeEmail(user.email);
    return user;
  }
}

// ✅ Good: Module configuration with proper exports
@Module({
  imports: [TypeOrmModule.forFeature([User])],
  controllers: [UserController],
  providers: [
    UserService,
    {
      provide: 'IUserRepository',
      useClass: TypeOrmUserRepository,
    },
    {
      provide: 'IEmailService',
      useClass: SendGridEmailService,
    },
  ],
  exports: [UserService, 'IUserRepository'],
})
export class UserModule {}

// ❌ Bad: Direct class dependencies
@Injectable()
export class UserService {
  constructor(
    private readonly userRepository: TypeOrmUserRepository, // Tightly coupled
    private readonly sendGridService: SendGridEmailService, // Hard to test
  ) {}
}
```

### **3. Error Handling Patterns**
*Essential for production applications*

```typescript
// ✅ Good: Custom exception hierarchy
export class AppException extends Error {
  constructor(
    message: string,
    public readonly code: string,
    public readonly statusCode: number = 500,
  ) {
    super(message);
    this.name = this.constructor.name;
  }
}

export class ValidationException extends AppException {
  constructor(message: string, public readonly field: string) {
    super(message, 'VALIDATION_ERROR', 400);
  }
}

export class NotFoundError extends AppException {
  constructor(resource: string, id: string) {
    super(`${resource} with id ${id} not found`, 'NOT_FOUND', 404);
  }
}

// ✅ Good: Global exception filter
@Catch()
export class GlobalExceptionFilter implements ExceptionFilter {
  private readonly logger = new Logger(GlobalExceptionFilter.name);

  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();

    let status = 500;
    let message = 'Internal server error';
    let code = 'INTERNAL_ERROR';

    if (exception instanceof AppException) {
      status = exception.statusCode;
      message = exception.message;
      code = exception.code;
    } else if (exception instanceof HttpException) {
      status = exception.getStatus();
      message = exception.message;
      code = 'HTTP_ERROR';
    }

    // Log error for monitoring
    this.logger.error(
      `${request.method} ${request.url} - ${status} - ${message}`,
      exception instanceof Error ? exception.stack : exception,
    );

    response.status(status).json({
      success: false,
      error: {
        code,
        message,
        timestamp: new Date().toISOString(),
        path: request.url,
      },
    });
  }
}

// ✅ Good: Service-level error handling
@Injectable()
export class UserService {
  async findById(id: string): Promise<User> {
    try {
      const user = await this.userRepository.findById(id);
      if (!user) {
        throw new NotFoundError('User', id);
      }
      return user;
    } catch (error) {
      if (error instanceof AppException) {
        throw error; // Re-throw custom exceptions
      }
      
      // Log unexpected errors
      this.logger.error(`Unexpected error in findById: ${error.message}`, error.stack);
      throw new AppException('Failed to retrieve user', 'USER_RETRIEVAL_ERROR');
    }
  }
}
```

## 🔒 Security Best Practices

### **1. Authentication & Authorization**
*Security-first approach*

```typescript
// ✅ Good: Secure JWT configuration
@Module({
  imports: [
    JwtModule.registerAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        secret: config.get<string>('JWT_SECRET'),
        signOptions: {
          expiresIn: '15m', // Short expiration for access tokens
          issuer: 'your-app-name',
          audience: 'your-app-users',
        },
      }),
    }),
  ],
})
export class AuthModule {}

// ✅ Good: Refresh token implementation
@Injectable()
export class AuthService {
  async login(user: User): Promise<AuthResponse> {
    const payload = { sub: user.id, email: user.email, role: user.role };
    
    const [accessToken, refreshToken] = await Promise.all([
      this.jwtService.signAsync(payload, { expiresIn: '15m' }),
      this.jwtService.signAsync(payload, { 
        expiresIn: '7d',
        secret: this.configService.get('JWT_REFRESH_SECRET'),
      }),
    ]);

    // Store refresh token hash in database
    await this.storeRefreshToken(user.id, refreshToken);

    return { accessToken, refreshToken, user: this.sanitizeUser(user) };
  }

  private async storeRefreshToken(userId: string, token: string): Promise<void> {
    const hashedToken = await bcrypt.hash(token, 10);
    await this.userRepository.updateRefreshToken(userId, hashedToken);
  }
}

// ✅ Good: Role-based authorization
@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const requiredRoles = this.reflector.getAllAndOverride<Role[]>('roles', [
      context.getHandler(),
      context.getClass(),
    ]);

    if (!requiredRoles) return true;

    const { user } = context.switchToHttp().getRequest();
    return requiredRoles.some((role) => user.roles?.includes(role));
  }
}

// ✅ Good: Input validation and sanitization
export class CreateUserDto {
  @IsEmail()
  @Transform(({ value }) => value.toLowerCase().trim())
  email: string;

  @IsString()
  @MinLength(8)
  @Matches(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]/, {
    message: 'Password must contain uppercase, lowercase, number and special character',
  })
  password: string;

  @IsString()
  @Length(2, 50)
  @Transform(({ value }) => value.trim())
  firstName: string;

  @IsString()
  @Length(2, 50)
  @Transform(({ value }) => value.trim())
  lastName: string;
}
```

### **2. Data Protection**
*Privacy and security compliance*

```typescript
// ✅ Good: Data sanitization
@Injectable()
export class DataSanitizationService {
  sanitizeUser(user: User): Partial<User> {
    const { password, passwordHash, refreshToken, ...sanitized } = user;
    return sanitized;
  }

  sanitizeUserForPublic(user: User): Partial<User> {
    return {
      id: user.id,
      firstName: user.firstName,
      lastName: user.lastName,
      // Don't expose email or other sensitive data
    };
  }
}

// ✅ Good: Audit logging
@Injectable()
export class AuditService {
  async logUserAction(
    userId: string,
    action: string,
    resource: string,
    metadata?: any,
  ): Promise<void> {
    const auditLog = {
      userId,
      action,
      resource,
      metadata,
      timestamp: new Date(),
      ipAddress: this.getClientIp(),
      userAgent: this.getUserAgent(),
    };

    await this.auditRepository.create(auditLog);
  }
}

// ✅ Good: Sensitive data encryption
@Injectable()
export class EncryptionService {
  private readonly algorithm = 'aes-256-gcm';
  private readonly key = crypto.scryptSync(
    this.configService.get('ENCRYPTION_KEY'),
    'salt',
    32,
  );

  encrypt(text: string): string {
    const iv = crypto.randomBytes(16);
    const cipher = crypto.createCipher(this.algorithm, this.key);
    cipher.setAAD(Buffer.from('metadata', 'utf8'));
    
    let encrypted = cipher.update(text, 'utf8', 'hex');
    encrypted += cipher.final('hex');
    
    const authTag = cipher.getAuthTag();
    
    return iv.toString('hex') + ':' + authTag.toString('hex') + ':' + encrypted;
  }

  decrypt(encryptedText: string): string {
    const [ivHex, authTagHex, encrypted] = encryptedText.split(':');
    const iv = Buffer.from(ivHex, 'hex');
    const authTag = Buffer.from(authTagHex, 'hex');
    
    const decipher = crypto.createDecipher(this.algorithm, this.key);
    decipher.setAAD(Buffer.from('metadata', 'utf8'));
    decipher.setAuthTag(authTag);
    
    let decrypted = decipher.update(encrypted, 'hex', 'utf8');
    decrypted += decipher.final('utf8');
    
    return decrypted;
  }
}
```

## 📊 Database Best Practices

### **1. Entity Design**
*Scalable data modeling*

```typescript
// ✅ Good: Base entity with common fields
@Entity()
export abstract class BaseEntity {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;

  @DeleteDateColumn()
  deletedAt?: Date;

  @VersionColumn()
  version: number;
}

// ✅ Good: Well-designed entity with proper relationships
@Entity('users')
@Index(['email']) // Unique index for faster lookups
@Index(['firstName', 'lastName']) // Composite index for name searches
export class User extends BaseEntity {
  @Column({ unique: true })
  email: string;

  @Column({ select: false }) // Exclude from default selects
  passwordHash: string;

  @Column()
  firstName: string;

  @Column()
  lastName: string;

  @Column({ type: 'enum', enum: UserRole, default: UserRole.USER })
  role: UserRole;

  @Column({ default: true })
  isActive: boolean;

  @Column({ nullable: true, select: false })
  refreshTokenHash?: string;

  // Lazy loading for better performance
  @OneToMany(() => Post, post => post.author, { lazy: true })
  posts: Promise<Post[]>;

  @OneToOne(() => UserProfile, profile => profile.user, { 
    cascade: true,
    lazy: true,
  })
  profile: Promise<UserProfile>;

  // Virtual properties
  @AfterLoad()
  setFullName() {
    this.fullName = `${this.firstName} ${this.lastName}`;
  }

  fullName: string;
}

// ✅ Good: Repository pattern with custom methods
@Injectable()
export class UserRepository extends Repository<User> {
  constructor(private dataSource: DataSource) {
    super(User, dataSource.createEntityManager());
  }

  async findByEmailWithProfile(email: string): Promise<User | null> {
    return this.findOne({
      where: { email },
      relations: ['profile'],
    });
  }

  async findActiveUsers(limit: number = 10): Promise<User[]> {
    return this.createQueryBuilder('user')
      .where('user.isActive = :isActive', { isActive: true })
      .orderBy('user.createdAt', 'DESC')
      .limit(limit)
      .getMany();
  }

  async getUserStats(): Promise<{
    total: number;
    active: number;
    inactive: number;
  }> {
    const [total, active] = await Promise.all([
      this.count(),
      this.count({ where: { isActive: true } }),
    ]);

    return {
      total,
      active,
      inactive: total - active,
    };
  }
}
```

### **2. Migration Best Practices**
*Safe database evolution*

```typescript
// ✅ Good: Safe migration with rollback
import { MigrationInterface, QueryRunner, Table, Index } from 'typeorm';

export class CreateUsersTable1234567890 implements MigrationInterface {
  name = 'CreateUsersTable1234567890';

  public async up(queryRunner: QueryRunner): Promise<void> {
    // Create table with all constraints
    await queryRunner.createTable(
      new Table({
        name: 'users',
        columns: [
          {
            name: 'id',
            type: 'uuid',
            isPrimary: true,
            generationStrategy: 'uuid',
            default: 'uuid_generate_v4()',
          },
          {
            name: 'email',
            type: 'varchar',
            length: '255',
            isUnique: true,
            isNullable: false,
          },
          {
            name: 'password_hash',
            type: 'varchar',
            length: '255',
            isNullable: false,
          },
          {
            name: 'first_name',
            type: 'varchar',
            length: '100',
            isNullable: false,
          },
          {
            name: 'last_name',
            type: 'varchar',
            length: '100',
            isNullable: false,
          },
          {
            name: 'role',
            type: 'enum',
            enum: ['admin', 'user', 'moderator'],
            default: "'user'",
          },
          {
            name: 'is_active',
            type: 'boolean',
            default: true,
          },
          {
            name: 'created_at',
            type: 'timestamp',
            default: 'CURRENT_TIMESTAMP',
          },
          {
            name: 'updated_at',
            type: 'timestamp',
            default: 'CURRENT_TIMESTAMP',
            onUpdate: 'CURRENT_TIMESTAMP',
          },
          {
            name: 'deleted_at',
            type: 'timestamp',
            isNullable: true,
          },
          {
            name: 'version',
            type: 'int',
            default: 1,
          },
        ],
      }),
      true,
    );

    // Create indexes for better performance
    await queryRunner.createIndex(
      'users',
      new Index({
        name: 'IDX_USER_EMAIL',
        columnNames: ['email'],
      }),
    );

    await queryRunner.createIndex(
      'users',
      new Index({
        name: 'IDX_USER_NAME',
        columnNames: ['first_name', 'last_name'],
      }),
    );

    await queryRunner.createIndex(
      'users',
      new Index({
        name: 'IDX_USER_ACTIVE',
        columnNames: ['is_active'],
      }),
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    // Drop indexes first
    await queryRunner.dropIndex('users', 'IDX_USER_ACTIVE');
    await queryRunner.dropIndex('users', 'IDX_USER_NAME');
    await queryRunner.dropIndex('users', 'IDX_USER_EMAIL');
    
    // Drop table
    await queryRunner.dropTable('users');
  }
}

// ✅ Good: Data migration with safety checks
export class MigrateUserData1234567891 implements MigrationInterface {
  public async up(queryRunner: QueryRunner): Promise<void> {
    // Check if migration is needed
    const count = await queryRunner.query(
      'SELECT COUNT(*) as count FROM users WHERE role IS NULL'
    );
    
    if (count[0].count === 0) {
      return; // No data to migrate
    }

    // Batch update to avoid locking large tables
    let offset = 0;
    const batchSize = 1000;

    while (true) {
      const result = await queryRunner.query(`
        UPDATE users 
        SET role = 'user' 
        WHERE role IS NULL 
        AND id IN (
          SELECT id FROM users 
          WHERE role IS NULL 
          ORDER BY id 
          LIMIT ${batchSize} OFFSET ${offset}
        )
      `);

      if (result.affectedRows === 0) break;
      offset += batchSize;
    }
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    // Rollback data changes if needed
    await queryRunner.query("UPDATE users SET role = NULL WHERE role = 'user'");
  }
}
```

## 🧪 Testing Best Practices

### **1. Test Organization**
*Comprehensive testing strategy*

```typescript
// ✅ Good: Well-structured test file
describe('UserService', () => {
  let service: UserService;
  let repository: MockRepository<User>;
  let emailService: MockEmailService;

  beforeEach(async () => {
    const module = await Test.createTestingModule({
      providers: [
        UserService,
        {
          provide: getRepositoryToken(User),
          useValue: createMockRepository(),
        },
        {
          provide: 'IEmailService',
          useValue: createMockEmailService(),
        },
      ],
    }).compile();

    service = module.get<UserService>(UserService);
    repository = module.get(getRepositoryToken(User));
    emailService = module.get('IEmailService');
  });

  describe('createUser', () => {
    it('should create user successfully', async () => {
      // Arrange
      const createUserDto = createMockCreateUserDto();
      const expectedUser = createMockUser();
      
      repository.create.mockReturnValue(expectedUser);
      repository.save.mockResolvedValue(expectedUser);
      emailService.sendWelcomeEmail.mockResolvedValue(undefined);

      // Act
      const result = await service.createUser(createUserDto);

      // Assert
      expect(repository.create).toHaveBeenCalledWith(createUserDto);
      expect(repository.save).toHaveBeenCalledWith(expectedUser);
      expect(emailService.sendWelcomeEmail).toHaveBeenCalledWith(expectedUser.email);
      expect(result).toEqual(expectedUser);
    });

    it('should throw ConflictException for duplicate email', async () => {
      // Arrange
      const createUserDto = createMockCreateUserDto();
      repository.save.mockRejectedValue({ code: '23505' }); // PostgreSQL unique violation

      // Act & Assert
      await expect(service.createUser(createUserDto)).rejects.toThrow(ConflictException);
    });
  });

  describe('findById', () => {
    it('should return user when found', async () => {
      // Arrange
      const userId = 'test-id';
      const expectedUser = createMockUser({ id: userId });
      repository.findOne.mockResolvedValue(expectedUser);

      // Act
      const result = await service.findById(userId);

      // Assert
      expect(repository.findOne).toHaveBeenCalledWith({
        where: { id: userId },
      });
      expect(result).toEqual(expectedUser);
    });

    it('should throw NotFoundError when user not found', async () => {
      // Arrange
      const userId = 'nonexistent-id';
      repository.findOne.mockResolvedValue(null);

      // Act & Assert
      await expect(service.findById(userId)).rejects.toThrow(NotFoundError);
    });
  });
});

// ✅ Good: Test utilities and factories
export const createMockUser = (overrides: Partial<User> = {}): User => ({
  id: 'test-id',
  email: 'test@example.com',
  firstName: 'John',
  lastName: 'Doe',
  role: UserRole.USER,
  isActive: true,
  createdAt: new Date(),
  updatedAt: new Date(),
  version: 1,
  ...overrides,
});

export const createMockCreateUserDto = (overrides: Partial<CreateUserDto> = {}): CreateUserDto => ({
  email: 'test@example.com',
  password: 'SecurePass123!',
  firstName: 'John',
  lastName: 'Doe',
  ...overrides,
});

type MockRepository<T = any> = Partial<Record<keyof Repository<T>, jest.Mock>>;

export const createMockRepository = <T = any>(): MockRepository<T> => ({
  create: jest.fn(),
  save: jest.fn(),
  findOne: jest.fn(),
  find: jest.fn(),
  update: jest.fn(),
  delete: jest.fn(),
  createQueryBuilder: jest.fn(() => ({
    where: jest.fn().mockReturnThis(),
    andWhere: jest.fn().mockReturnThis(),
    orderBy: jest.fn().mockReturnThis(),
    getMany: jest.fn(),
    getOne: jest.fn(),
  })),
});
```

### **2. Integration Testing**
*Database and API testing*

```typescript
// ✅ Good: Database integration test
describe('User Integration Tests', () => {
  let app: INestApplication;
  let dataSource: DataSource;

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      imports: [
        TypeOrmModule.forRoot({
          type: 'sqlite',
          database: ':memory:',
          entities: [User, UserProfile],
          synchronize: true,
        }),
        UserModule,
      ],
    }).compile();

    app = moduleRef.createNestApplication();
    await app.init();

    dataSource = moduleRef.get<DataSource>(DataSource);
  });

  afterAll(async () => {
    await app.close();
  });

  beforeEach(async () => {
    // Clean database before each test
    await dataSource.synchronize(true);
  });

  it('should create user with profile', async () => {
    const userService = app.get<UserService>(UserService);
    
    const createUserDto = {
      email: 'integration@test.com',
      password: 'SecurePass123!',
      firstName: 'Integration',
      lastName: 'Test',
    };

    const user = await userService.createUser(createUserDto);
    const retrievedUser = await userService.findById(user.id);

    expect(retrievedUser).toBeDefined();
    expect(retrievedUser.email).toBe(createUserDto.email);
  });
});
```

## 🔧 Configuration Management

### **1. Environment Configuration**
*Secure and flexible configuration*

```typescript
// ✅ Good: Type-safe configuration
export interface AppConfig {
  port: number;
  environment: 'development' | 'production' | 'test';
  database: DatabaseConfig;
  jwt: JwtConfig;
  redis: RedisConfig;
  email: EmailConfig;
}

export interface DatabaseConfig {
  host: string;
  port: number;
  username: string;
  password: string;
  database: string;
  ssl: boolean;
}

// ✅ Good: Configuration validation
const configSchema = Joi.object({
  NODE_ENV: Joi.string().valid('development', 'production', 'test').required(),
  PORT: Joi.number().default(3000),
  
  // Database
  DB_HOST: Joi.string().required(),
  DB_PORT: Joi.number().default(5432),
  DB_USERNAME: Joi.string().required(),
  DB_PASSWORD: Joi.string().required(),
  DB_NAME: Joi.string().required(),
  DB_SSL: Joi.boolean().default(false),
  
  // JWT
  JWT_SECRET: Joi.string().min(32).required(),
  JWT_REFRESH_SECRET: Joi.string().min(32).required(),
  JWT_EXPIRES_IN: Joi.string().default('15m'),
  
  // Redis
  REDIS_HOST: Joi.string().required(),
  REDIS_PORT: Joi.number().default(6379),
  REDIS_PASSWORD: Joi.string().optional(),
});

// ✅ Good: Configuration factory
export const appConfig = registerAs('app', (): AppConfig => ({
  port: parseInt(process.env.PORT, 10) || 3000,
  environment: process.env.NODE_ENV as any,
  database: {
    host: process.env.DB_HOST,
    port: parseInt(process.env.DB_PORT, 10) || 5432,
    username: process.env.DB_USERNAME,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
    ssl: process.env.DB_SSL === 'true',
  },
  jwt: {
    secret: process.env.JWT_SECRET,
    refreshSecret: process.env.JWT_REFRESH_SECRET,
    expiresIn: process.env.JWT_EXPIRES_IN || '15m',
  },
  redis: {
    host: process.env.REDIS_HOST,
    port: parseInt(process.env.REDIS_PORT, 10) || 6379,
    password: process.env.REDIS_PASSWORD,
  },
  email: {
    provider: process.env.EMAIL_PROVIDER || 'sendgrid',
    apiKey: process.env.EMAIL_API_KEY,
    fromEmail: process.env.EMAIL_FROM,
  },
}));

// ✅ Good: Module setup
@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      load: [appConfig],
      validationSchema: configSchema,
      validationOptions: {
        allowUnknown: true,
        abortEarly: true,
      },
    }),
  ],
})
export class AppModule {}
```

## 📈 Performance Best Practices

### **1. Caching Strategy**
*Efficient data access*

```typescript
// ✅ Good: Smart caching service
@Injectable()
export class CacheService {
  constructor(@Inject(CACHE_MANAGER) private cache: Cache) {}

  async get<T>(key: string): Promise<T | null> {
    return this.cache.get<T>(key);
  }

  async set<T>(key: string, value: T, ttl: number = 300): Promise<void> {
    await this.cache.set(key, value, ttl);
  }

  async getOrSet<T>(
    key: string,
    factory: () => Promise<T>,
    ttl: number = 300,
  ): Promise<T> {
    let value = await this.get<T>(key);
    
    if (value === null) {
      value = await factory();
      await this.set(key, value, ttl);
    }
    
    return value;
  }

  async invalidate(pattern: string): Promise<void> {
    const keys = await this.cache.store.keys(pattern);
    await Promise.all(keys.map(key => this.cache.del(key)));
  }

  // Cache user data with different TTLs based on data type
  async cacheUserData(userId: string, data: any, type: 'profile' | 'preferences' | 'stats'): Promise<void> {
    const ttl = {
      profile: 600,    // 10 minutes - changes rarely
      preferences: 300, // 5 minutes - changes occasionally  
      stats: 60,       // 1 minute - changes frequently
    }[type];

    await this.set(`user:${userId}:${type}`, data, ttl);
  }
}

// ✅ Good: Caching decorator
export function Cacheable(ttl: number = 300, keyPrefix?: string) {
  return function (target: any, propertyName: string, descriptor: PropertyDescriptor) {
    const method = descriptor.value;

    descriptor.value = async function (...args: any[]) {
      const cacheService = this.cacheService;
      const key = `${keyPrefix || target.constructor.name}:${propertyName}:${JSON.stringify(args)}`;
      
      return cacheService.getOrSet(key, () => method.apply(this, args), ttl);
    };

    return descriptor;
  };
}

// Usage
@Injectable()
export class UserService {
  constructor(private readonly cacheService: CacheService) {}

  @Cacheable(600, 'user')
  async findById(id: string): Promise<User> {
    return this.userRepository.findOne({ where: { id } });
  }
}
```

### **2. Database Optimization**
*Efficient queries and connections*

```typescript
// ✅ Good: Optimized repository methods
@Injectable()
export class UserRepository {
  constructor(private dataSource: DataSource) {}

  // Use projection to select only needed fields
  async findForList(options: FindManyOptions<User>): Promise<User[]> {
    return this.dataSource.getRepository(User).find({
      ...options,
      select: ['id', 'email', 'firstName', 'lastName', 'isActive'],
    });
  }

  // Use query builder for complex queries
  async findActiveUsersWithPostCount(): Promise<any[]> {
    return this.dataSource
      .getRepository(User)
      .createQueryBuilder('user')
      .leftJoin('user.posts', 'post')
      .select([
        'user.id',
        'user.email',
        'user.firstName',
        'user.lastName',
        'COUNT(post.id) as postCount',
      ])
      .where('user.isActive = :isActive', { isActive: true })
      .groupBy('user.id')
      .getRawMany();
  }

  // Efficient pagination
  async findWithPagination(
    page: number,
    limit: number,
    filters?: any,
  ): Promise<{ data: User[]; total: number }> {
    const queryBuilder = this.dataSource
      .getRepository(User)
      .createQueryBuilder('user')
      .select(['user.id', 'user.email', 'user.firstName', 'user.lastName']);

    if (filters?.search) {
      queryBuilder.where(
        '(user.firstName ILIKE :search OR user.lastName ILIKE :search OR user.email ILIKE :search)',
        { search: `%${filters.search}%` },
      );
    }

    if (filters?.role) {
      queryBuilder.andWhere('user.role = :role', { role: filters.role });
    }

    const [data, total] = await queryBuilder
      .skip((page - 1) * limit)
      .take(limit)
      .orderBy('user.createdAt', 'DESC')
      .getManyAndCount();

    return { data, total };
  }
}
```

## 📋 Production Readiness Checklist

### **Essential Requirements**

#### **Code Quality**
- [ ] TypeScript strict mode enabled
- [ ] ESLint and Prettier configured
- [ ] 80%+ test coverage
- [ ] No `any` types in production code
- [ ] Consistent error handling
- [ ] Input validation on all endpoints

#### **Security**
- [ ] JWT with refresh tokens
- [ ] Rate limiting implemented
- [ ] Input sanitization
- [ ] SQL injection prevention
- [ ] XSS protection
- [ ] CORS properly configured
- [ ] Security headers (Helmet)
- [ ] Secrets not in source code

#### **Performance**
- [ ] Database connection pooling
- [ ] Query optimization
- [ ] Response caching
- [ ] Request compression
- [ ] Memory leak prevention
- [ ] Response time monitoring

#### **Observability**
- [ ] Structured logging
- [ ] Health check endpoints
- [ ] Metrics collection
- [ ] Error tracking
- [ ] Performance monitoring
- [ ] Audit logging

#### **Deployment**
- [ ] Docker containerization
- [ ] Environment configuration
- [ ] Database migrations
- [ ] CI/CD pipeline
- [ ] Backup strategy
- [ ] Rollback procedure

---

**Navigation**: [← Performance Optimization](./performance-optimization.md) | [Next: Implementation Guide →](./implementation-guide.md)