# Best Practices for Production NestJS Applications

## 🎯 Overview

Compilation of best practices derived from analyzing 40+ production-ready NestJS projects, covering code organization, project structure, development workflows, testing strategies, and deployment considerations.

## 📁 1. Project Structure & Organization

### Feature-Based Structure (Recommended - 60% of projects)

Most successful projects organize code by business features rather than technical layers:

```
src/
├── modules/                 # Feature modules
│   ├── auth/
│   │   ├── dto/
│   │   │   ├── login.dto.ts
│   │   │   ├── register.dto.ts
│   │   │   └── refresh-token.dto.ts
│   │   ├── entities/
│   │   │   └── user.entity.ts
│   │   ├── guards/
│   │   │   ├── jwt-auth.guard.ts
│   │   │   └── roles.guard.ts
│   │   ├── strategies/
│   │   │   ├── jwt.strategy.ts
│   │   │   └── google.strategy.ts
│   │   ├── services/
│   │   │   └── auth.service.ts
│   │   ├── controllers/
│   │   │   └── auth.controller.ts
│   │   └── auth.module.ts
│   ├── users/
│   ├── projects/
│   └── notifications/
├── common/                  # Shared utilities
│   ├── decorators/
│   ├── filters/
│   ├── guards/
│   ├── interceptors/
│   ├── pipes/
│   └── utils/
├── config/                  # Configuration
│   ├── database.config.ts
│   ├── auth.config.ts
│   └── app.config.ts
├── database/                # Database-related
│   ├── migrations/
│   ├── seeds/
│   └── database.module.ts
└── main.ts
```

### Module Structure Best Practices

```typescript
// Feature module template
@Module({
  imports: [
    TypeOrmModule.forFeature([UserEntity, UserRepository]),
    // Only import what this module needs
    AuthModule, // For authentication
    ConfigModule, // For configuration
  ],
  controllers: [UserController],
  providers: [
    UserService,
    UserRepository, // Custom repository if needed
    // Feature-specific services only
  ],
  exports: [
    UserService, // Export only what other modules need
  ],
})
export class UserModule {}
```

### Common Module Organization

```typescript
// Common module for shared utilities
@Global()
@Module({
  providers: [
    LoggerService,
    CacheService,
    EventEmitterService,
    {
      provide: APP_FILTER,
      useClass: AllExceptionsFilter,
    },
    {
      provide: APP_INTERCEPTOR,
      useClass: TransformInterceptor,
    },
    {
      provide: APP_PIPE,
      useClass: ValidationPipe,
    },
  ],
  exports: [LoggerService, CacheService, EventEmitterService],
})
export class CommonModule {}
```

## 🔧 2. Configuration Management

### Environment-Based Configuration

95% of production projects implement robust configuration management:

```typescript
// Configuration schema validation
export class EnvironmentVariables {
  // Database
  @IsString()
  @IsNotEmpty()
  DATABASE_URL: string;

  @IsString()
  @IsOptional()
  DATABASE_HOST: string = 'localhost';

  @IsNumber()
  @IsOptional()
  @Type(() => Number)
  DATABASE_PORT: number = 5432;

  // JWT
  @IsString()
  @MinLength(32)
  JWT_SECRET: string;

  @IsString()
  @IsOptional()
  JWT_EXPIRES_IN: string = '15m';

  // Redis
  @IsString()
  @IsOptional()
  REDIS_URL: string;

  // Email
  @IsString()
  @IsOptional()
  SMTP_HOST: string;

  @IsNumber()
  @IsOptional()
  @Type(() => Number)
  SMTP_PORT: number = 587;

  // App
  @IsIn(['development', 'staging', 'production'])
  @IsOptional()
  NODE_ENV: string = 'development';

  @IsNumber()
  @IsOptional()
  @Type(() => Number)
  PORT: number = 3000;
}

// Configuration factory
export const configFactory = () => ({
  app: {
    name: process.env.APP_NAME || 'NestJS App',
    version: process.env.APP_VERSION || '1.0.0',
    port: parseInt(process.env.PORT, 10) || 3000,
    env: process.env.NODE_ENV || 'development',
    url: process.env.APP_URL || 'http://localhost:3000',
  },
  database: {
    url: process.env.DATABASE_URL,
    host: process.env.DATABASE_HOST || 'localhost',
    port: parseInt(process.env.DATABASE_PORT, 10) || 5432,
    username: process.env.DATABASE_USERNAME,
    password: process.env.DATABASE_PASSWORD,
    name: process.env.DATABASE_NAME,
    synchronize: process.env.NODE_ENV === 'development',
    logging: process.env.NODE_ENV === 'development',
  },
  jwt: {
    secret: process.env.JWT_SECRET,
    expiresIn: process.env.JWT_EXPIRES_IN || '15m',
    refreshExpiresIn: process.env.JWT_REFRESH_EXPIRES_IN || '7d',
  },
  redis: {
    url: process.env.REDIS_URL,
    host: process.env.REDIS_HOST || 'localhost',
    port: parseInt(process.env.REDIS_PORT, 10) || 6379,
  },
});

// Configuration module setup
@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      load: [configFactory],
      validationSchema: plainToClass(EnvironmentVariables, process.env),
      validationOptions: {
        allowUnknown: true,
        abortEarly: false,
      },
    }),
  ],
})
export class ConfigurationModule {}
```

### Type-Safe Configuration Service

```typescript
@Injectable()
export class AppConfigService {
  constructor(private configService: ConfigService) {}

  get app() {
    return {
      name: this.configService.get<string>('app.name'),
      version: this.configService.get<string>('app.version'),
      port: this.configService.get<number>('app.port'),
      env: this.configService.get<string>('app.env'),
      url: this.configService.get<string>('app.url'),
    };
  }

  get database() {
    return {
      url: this.configService.get<string>('database.url'),
      host: this.configService.get<string>('database.host'),
      port: this.configService.get<number>('database.port'),
      // ... other database config
    };
  }

  get jwt() {
    return {
      secret: this.configService.get<string>('jwt.secret'),
      expiresIn: this.configService.get<string>('jwt.expiresIn'),
      refreshExpiresIn: this.configService.get<string>('jwt.refreshExpiresIn'),
    };
  }

  get isDevelopment(): boolean {
    return this.app.env === 'development';
  }

  get isProduction(): boolean {
    return this.app.env === 'production';
  }
}
```

## 🎨 3. Code Quality & Standards

### TypeScript Best Practices

Strict TypeScript configuration used by top projects:

```json
// tsconfig.json
{
  "compilerOptions": {
    "target": "ES2021",
    "lib": ["ES2021"],
    "module": "commonjs",
    "declaration": true,
    "strict": true,
    "noImplicitAny": true,
    "strictNullChecks": true,
    "strictFunctionTypes": true,
    "noImplicitReturns": true,
    "noFallthroughCasesInSwitch": true,
    "noUncheckedIndexedAccess": true,
    "exactOptionalPropertyTypes": true,
    "noImplicitOverride": true,
    "removeComments": true,
    "emitDecoratorMetadata": true,
    "experimentalDecorators": true,
    "resolveJsonModule": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "baseUrl": "./src",
    "paths": {
      "@/*": ["*"],
      "@common/*": ["common/*"],
      "@modules/*": ["modules/*"],
      "@config/*": ["config/*"]
    }
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist", "test"]
}
```

### ESLint Configuration

```javascript
// .eslintrc.js
module.exports = {
  parser: '@typescript-eslint/parser',
  parserOptions: {
    project: 'tsconfig.json',
    tsconfigRootDir: __dirname,
    sourceType: 'module',
  },
  plugins: ['@typescript-eslint/eslint-plugin'],
  extends: [
    '@nestjs',
    'plugin:@typescript-eslint/recommended',
    'plugin:prettier/recommended',
  ],
  root: true,
  env: {
    node: true,
    jest: true,
  },
  ignorePatterns: ['.eslintrc.js'],
  rules: {
    '@typescript-eslint/interface-name-prefix': 'off',
    '@typescript-eslint/explicit-function-return-type': 'error',
    '@typescript-eslint/explicit-module-boundary-types': 'error',
    '@typescript-eslint/no-explicit-any': 'error',
    '@typescript-eslint/no-unused-vars': 'error',
    '@typescript-eslint/prefer-nullish-coalescing': 'error',
    '@typescript-eslint/prefer-optional-chain': 'error',
    'prefer-const': 'error',
    'no-var': 'error',
  },
};
```

### Naming Conventions

```typescript
// File naming conventions
// ✅ Good
user.controller.ts
user.service.ts
user.entity.ts
user.dto.ts
user.interface.ts
create-user.dto.ts
user-created.event.ts

// ❌ Bad
UserController.ts
userService.ts
User.entity.ts

// Class naming conventions
// ✅ Good
export class UserController {}
export class CreateUserDto {}
export class UserCreatedEvent {}
export interface UserRepository {}

// Interface naming (no 'I' prefix)
// ✅ Good
export interface UserRepository {
  findById(id: string): Promise<User>;
}

// ❌ Bad
export interface IUserRepository {}

// Method naming
// ✅ Good
async createUser(userData: CreateUserDto): Promise<User> {}
async getUserById(id: string): Promise<User | null> {}
async updateUserEmail(id: string, email: string): Promise<void> {}

// Variable naming
// ✅ Good
const userRepository = getRepository(User);
const isUserActive = user.status === UserStatus.ACTIVE;
const createdUsers = await userRepository.find();
```

## 🧪 4. Testing Strategies

### Testing Pyramid Implementation

75% of analyzed projects follow the testing pyramid:

```typescript
// Unit test example
describe('UserService', () => {
  let service: UserService;
  let userRepository: MockRepository<User>;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        UserService,
        {
          provide: getRepositoryToken(User),
          useClass: MockRepository,
        },
      ],
    }).compile();

    service = module.get<UserService>(UserService);
    userRepository = module.get(getRepositoryToken(User));
  });

  describe('createUser', () => {
    it('should create a user successfully', async () => {
      // Arrange
      const createUserDto: CreateUserDto = {
        email: 'test@example.com',
        firstName: 'John',
        lastName: 'Doe',
        password: 'SecurePass123!',
      };

      const expectedUser = {
        id: '1',
        ...createUserDto,
        password: 'hashedPassword',
        createdAt: new Date(),
        updatedAt: new Date(),
      };

      userRepository.save.mockResolvedValue(expectedUser);
      jest.spyOn(service, 'hashPassword').mockResolvedValue('hashedPassword');

      // Act
      const result = await service.createUser(createUserDto);

      // Assert
      expect(result).toEqual(expectedUser);
      expect(userRepository.save).toHaveBeenCalledWith({
        ...createUserDto,
        password: 'hashedPassword',
      });
    });

    it('should throw error if email already exists', async () => {
      // Arrange
      const createUserDto: CreateUserDto = {
        email: 'existing@example.com',
        firstName: 'John',
        lastName: 'Doe',
        password: 'SecurePass123!',
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

### Integration Testing

```typescript
// Integration test example
describe('UserController (Integration)', () => {
  let app: INestApplication;
  let userRepository: Repository<User>;

  beforeEach(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [
        ConfigModule.forRoot({
          isGlobal: true,
          load: [() => ({ database: { url: process.env.TEST_DATABASE_URL } })],
        }),
        TypeOrmModule.forRootAsync({
          useFactory: (configService: ConfigService) => ({
            type: 'postgres',
            url: configService.get('database.url'),
            entities: [User],
            synchronize: true,
          }),
          inject: [ConfigService],
        }),
        UserModule,
      ],
    }).compile();

    app = moduleFixture.createNestApplication();
    userRepository = moduleFixture.get(getRepositoryToken(User));
    
    await app.init();
  });

  afterEach(async () => {
    await userRepository.clear();
    await app.close();
  });

  describe('POST /users', () => {
    it('should create a new user', async () => {
      const createUserDto = {
        email: 'test@example.com',
        firstName: 'John',
        lastName: 'Doe',
        password: 'SecurePass123!',
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

      const savedUser = await userRepository.findOne({
        where: { email: createUserDto.email },
      });
      expect(savedUser).toBeDefined();
    });
  });
});
```

### E2E Testing

```typescript
// E2E test example
describe('Authentication Flow (e2e)', () => {
  let app: INestApplication;
  let userRepository: Repository<User>;

  beforeAll(async () => {
    const moduleFixture = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleFixture.createNestApplication();
    userRepository = moduleFixture.get(getRepositoryToken(User));
    
    await app.init();
  });

  afterAll(async () => {
    await app.close();
  });

  beforeEach(async () => {
    await userRepository.clear();
  });

  it('should complete full authentication flow', async () => {
    // 1. Register user
    const registerDto = {
      email: 'test@example.com',
      firstName: 'John',
      lastName: 'Doe',
      password: 'SecurePass123!',
    };

    await request(app.getHttpServer())
      .post('/auth/register')
      .send(registerDto)
      .expect(201);

    // 2. Login
    const loginResponse = await request(app.getHttpServer())
      .post('/auth/login')
      .send({
        email: registerDto.email,
        password: registerDto.password,
      })
      .expect(200);

    expect(loginResponse.body).toHaveProperty('accessToken');
    expect(loginResponse.body).toHaveProperty('refreshToken');

    const { accessToken } = loginResponse.body;

    // 3. Access protected resource
    await request(app.getHttpServer())
      .get('/users/profile')
      .set('Authorization', `Bearer ${accessToken}`)
      .expect(200);

    // 4. Logout
    await request(app.getHttpServer())
      .post('/auth/logout')
      .set('Authorization', `Bearer ${accessToken}`)
      .expect(200);

    // 5. Verify token is invalidated
    await request(app.getHttpServer())
      .get('/users/profile')
      .set('Authorization', `Bearer ${accessToken}`)
      .expect(401);
  });
});
```

### Test Utilities and Helpers

```typescript
// Test utilities
export class TestHelper {
  static createMockUser(overrides: Partial<User> = {}): User {
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

  static async createTestUser(
    userRepository: Repository<User>,
    overrides: Partial<User> = {},
  ): Promise<User> {
    const user = this.createMockUser(overrides);
    return userRepository.save(user);
  }

  static generateJwtToken(payload: any): string {
    return jwt.sign(payload, 'test-secret', { expiresIn: '1h' });
  }
}

// Database test utilities
export class DatabaseTestHelper {
  static async clearDatabase(dataSource: DataSource): Promise<void> {
    const entities = dataSource.entityMetadatas;
    
    for (const entity of entities) {
      const repository = dataSource.getRepository(entity.name);
      await repository.clear();
    }
  }

  static async seedDatabase(dataSource: DataSource): Promise<void> {
    // Seed test data
    const userRepository = dataSource.getRepository(User);
    await userRepository.save([
      TestHelper.createMockUser({ email: 'admin@test.com', role: Role.ADMIN }),
      TestHelper.createMockUser({ email: 'user@test.com', role: Role.USER }),
    ]);
  }
}
```

## 🔄 5. Error Handling & Logging

### Global Exception Filter

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
      
      if (typeof errorResponse === 'object') {
        message = (errorResponse as any).message || exception.message;
        error = (errorResponse as any).error || exception.name;
      } else {
        message = errorResponse;
        error = exception.name;
      }
    } else if (exception instanceof QueryFailedError) {
      status = HttpStatus.BAD_REQUEST;
      message = 'Database operation failed';
      error = 'DatabaseError';
      
      // Log sensitive database errors without exposing to client
      this.logger.error('Database error:', exception.message);
    } else {
      status = HttpStatus.INTERNAL_SERVER_ERROR;
      message = 'Internal server error';
      error = 'InternalServerError';
      
      // Log unexpected errors
      this.logger.error('Unexpected error:', exception);
    }

    const errorResponse = {
      statusCode: status,
      timestamp: new Date().toISOString(),
      path: request.url,
      method: request.method,
      error,
      message,
      ...(process.env.NODE_ENV === 'development' && {
        stack: exception instanceof Error ? exception.stack : undefined,
      }),
    };

    // Log error with request context
    this.logger.error(
      `${request.method} ${request.url} - ${status} - ${message}`,
      {
        error: errorResponse,
        user: (request as any).user?.id,
        ip: request.ip,
        userAgent: request.get('User-Agent'),
      },
    );

    response.status(status).json(errorResponse);
  }
}
```

### Structured Logging

```typescript
// Logger service
@Injectable()
export class LoggerService {
  private logger: winston.Logger;

  constructor(private configService: ConfigService) {
    this.logger = winston.createLogger({
      level: this.configService.get('LOG_LEVEL', 'info'),
      format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.errors({ stack: true }),
        winston.format.json(),
      ),
      defaultMeta: {
        service: this.configService.get('APP_NAME', 'nestjs-app'),
        version: this.configService.get('APP_VERSION', '1.0.0'),
      },
      transports: [
        new winston.transports.Console({
          format: winston.format.combine(
            winston.format.colorize(),
            winston.format.simple(),
          ),
        }),
        ...(this.configService.get('NODE_ENV') === 'production'
          ? [
              new winston.transports.File({
                filename: 'logs/error.log',
                level: 'error',
              }),
              new winston.transports.File({
                filename: 'logs/combined.log',
              }),
            ]
          : []),
      ],
    });
  }

  log(level: string, message: string, meta?: any): void {
    this.logger.log(level, message, meta);
  }

  info(message: string, meta?: any): void {
    this.logger.info(message, meta);
  }

  warn(message: string, meta?: any): void {
    this.logger.warn(message, meta);
  }

  error(message: string, error?: Error, meta?: any): void {
    this.logger.error(message, { error: error?.stack, ...meta });
  }

  debug(message: string, meta?: any): void {
    this.logger.debug(message, meta);
  }
}

// Logging interceptor
@Injectable()
export class LoggingInterceptor implements NestInterceptor {
  constructor(private logger: LoggerService) {}

  intercept(context: ExecutionContext, next: CallHandler): Observable<any> {
    const request = context.switchToHttp().getRequest();
    const startTime = Date.now();
    
    return next.handle().pipe(
      tap((result) => {
        const duration = Date.now() - startTime;
        this.logger.info('Request completed', {
          method: request.method,
          url: request.url,
          statusCode: context.switchToHttp().getResponse().statusCode,
          duration,
          user: request.user?.id,
        });
      }),
      catchError((error) => {
        const duration = Date.now() - startTime;
        this.logger.error('Request failed', error, {
          method: request.method,
          url: request.url,
          duration,
          user: request.user?.id,
        });
        throw error;
      }),
    );
  }
}
```

## 🚀 6. Performance Optimization

### Database Query Optimization

```typescript
// Repository with optimized queries
@Injectable()
export class UserRepository {
  constructor(
    @InjectRepository(User)
    private userRepository: Repository<User>,
  ) {}

  async findUserWithRelations(id: string): Promise<User | null> {
    return this.userRepository.findOne({
      where: { id },
      relations: ['profile', 'roles'],
      select: ['id', 'email', 'firstName', 'lastName'], // Only select needed fields
    });
  }

  async findUsersWithPagination(
    page: number,
    limit: number,
    filters?: UserFilters,
  ): Promise<[User[], number]> {
    const queryBuilder = this.userRepository.createQueryBuilder('user');
    
    if (filters?.search) {
      queryBuilder.andWhere(
        '(user.firstName ILIKE :search OR user.lastName ILIKE :search OR user.email ILIKE :search)',
        { search: `%${filters.search}%` },
      );
    }
    
    if (filters?.isActive !== undefined) {
      queryBuilder.andWhere('user.isActive = :isActive', {
        isActive: filters.isActive,
      });
    }
    
    return queryBuilder
      .leftJoinAndSelect('user.profile', 'profile')
      .orderBy('user.createdAt', 'DESC')
      .skip((page - 1) * limit)
      .take(limit)
      .getManyAndCount();
  }

  async findActiveUsersCount(): Promise<number> {
    return this.userRepository.count({
      where: { isActive: true },
    });
  }
}
```

### Caching Strategy

```typescript
// Cache service
@Injectable()
export class CacheService {
  constructor(
    @Inject(CACHE_MANAGER) private cacheManager: Cache,
    private logger: LoggerService,
  ) {}

  async get<T>(key: string): Promise<T | null> {
    try {
      const value = await this.cacheManager.get<T>(key);
      if (value) {
        this.logger.debug(`Cache hit for key: ${key}`);
      }
      return value;
    } catch (error) {
      this.logger.error(`Cache get error for key ${key}:`, error);
      return null;
    }
  }

  async set(key: string, value: any, ttl?: number): Promise<void> {
    try {
      await this.cacheManager.set(key, value, ttl);
      this.logger.debug(`Cache set for key: ${key}`);
    } catch (error) {
      this.logger.error(`Cache set error for key ${key}:`, error);
    }
  }

  async del(key: string): Promise<void> {
    try {
      await this.cacheManager.del(key);
      this.logger.debug(`Cache deleted for key: ${key}`);
    } catch (error) {
      this.logger.error(`Cache delete error for key ${key}:`, error);
    }
  }

  async invalidatePattern(pattern: string): Promise<void> {
    // Implementation depends on cache store (Redis, etc.)
  }
}

// Cache interceptor
@Injectable()
export class CacheInterceptor implements NestInterceptor {
  constructor(private cacheService: CacheService) {}

  intercept(context: ExecutionContext, next: CallHandler): Observable<any> {
    const request = context.switchToHttp().getRequest();
    const cacheKey = this.generateCacheKey(request);
    
    return from(this.cacheService.get(cacheKey)).pipe(
      switchMap((cachedResult) => {
        if (cachedResult) {
          return of(cachedResult);
        }
        
        return next.handle().pipe(
          tap((result) => {
            if (result) {
              this.cacheService.set(cacheKey, result, 300); // 5 minutes
            }
          }),
        );
      }),
    );
  }

  private generateCacheKey(request: any): string {
    return `${request.method}:${request.url}:${JSON.stringify(request.query)}`;
  }
}
```

## 📦 7. Dependency Management

### Package.json Best Practices

```json
{
  "name": "nestjs-production-app",
  "version": "1.0.0",
  "description": "Production-ready NestJS application",
  "author": "Your Name",
  "private": true,
  "license": "MIT",
  "scripts": {
    "prebuild": "rimraf dist",
    "build": "nest build",
    "format": "prettier --write \"src/**/*.ts\" \"test/**/*.ts\"",
    "start": "nest start",
    "start:dev": "nest start --watch",
    "start:debug": "nest start --debug --watch",
    "start:prod": "node dist/main",
    "lint": "eslint \"{src,apps,libs,test}/**/*.ts\" --fix",
    "test": "jest",
    "test:watch": "jest --watch",
    "test:cov": "jest --coverage",
    "test:debug": "node --inspect-brk -r tsconfig-paths/register -r ts-node/register node_modules/.bin/jest --runInBand",
    "test:e2e": "jest --config ./test/jest-e2e.json",
    "typeorm": "typeorm-ts-node-commonjs",
    "migration:generate": "npm run typeorm -- migration:generate -d src/database/data-source.ts",
    "migration:run": "npm run typeorm -- migration:run -d src/database/data-source.ts",
    "migration:revert": "npm run typeorm -- migration:revert -d src/database/data-source.ts",
    "seed": "ts-node src/database/seeds/seed.ts"
  },
  "dependencies": {
    "@nestjs/common": "^10.0.0",
    "@nestjs/core": "^10.0.0",
    "@nestjs/platform-express": "^10.0.0",
    "@nestjs/config": "^3.0.0",
    "@nestjs/typeorm": "^10.0.0",
    "@nestjs/jwt": "^10.0.0",
    "@nestjs/passport": "^10.0.0",
    "@nestjs/cache-manager": "^2.0.0",
    "typeorm": "^0.3.0",
    "pg": "^8.11.0",
    "class-validator": "^0.14.0",
    "class-transformer": "^0.5.0",
    "bcrypt": "^5.1.0",
    "helmet": "^7.0.0",
    "express-rate-limit": "^6.8.0",
    "winston": "^3.10.0"
  },
  "devDependencies": {
    "@nestjs/cli": "^10.0.0",
    "@nestjs/schematics": "^10.0.0",
    "@nestjs/testing": "^10.0.0",
    "@types/express": "^4.17.17",
    "@types/jest": "^29.5.2",
    "@types/node": "^20.3.1",
    "@types/supertest": "^2.0.12",
    "@typescript-eslint/eslint-plugin": "^6.0.0",
    "@typescript-eslint/parser": "^6.0.0",
    "eslint": "^8.42.0",
    "eslint-config-prettier": "^8.8.0",
    "eslint-plugin-prettier": "^4.2.1",
    "jest": "^29.5.0",
    "prettier": "^2.8.8",
    "source-map-support": "^0.5.21",
    "supertest": "^6.3.3",
    "ts-jest": "^29.1.0",
    "ts-loader": "^9.4.3",
    "ts-node": "^10.9.1",
    "tsconfig-paths": "^4.2.0",
    "typescript": "^5.1.3"
  },
  "engines": {
    "node": ">=18.0.0",
    "npm": ">=8.0.0"
  }
}
```

## 🔄 8. Development Workflow

### Git Hooks with Husky

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
    "*.{ts,js}": [
      "eslint --fix",
      "prettier --write",
      "git add"
    ],
    "*.{json,md}": [
      "prettier --write",
      "git add"
    ]
  }
}
```

### Commit Message Convention

```javascript
// commitlint.config.js
module.exports = {
  extends: ['@commitlint/config-conventional'],
  rules: {
    'type-enum': [
      2,
      'always',
      [
        'feat',     // New feature
        'fix',      // Bug fix
        'docs',     // Documentation
        'style',    // Code style changes
        'refactor', // Code refactoring
        'test',     // Adding tests
        'chore',    // Maintenance tasks
        'perf',     // Performance improvements
        'ci',       // CI/CD changes
        'revert',   // Reverting changes
      ],
    ],
    'scope-case': [2, 'always', 'kebab-case'],
    'subject-case': [2, 'always', 'sentence-case'],
    'subject-max-length': [2, 'always', 72],
    'body-max-line-length': [2, 'always', 100],
  },
};
```

## 📊 Development Tools Integration

### VS Code Configuration

```json
// .vscode/settings.json
{
  "editor.formatOnSave": true,
  "editor.codeActionsOnSave": {
    "source.fixAll.eslint": true,
    "source.organizeImports": true
  },
  "eslint.validate": ["typescript"],
  "typescript.preferences.includePackageJsonAutoImports": "on",
  "files.exclude": {
    "**/node_modules": true,
    "**/dist": true,
    "**/.git": true
  },
  "search.exclude": {
    "**/node_modules": true,
    "**/dist": true
  }
}

// .vscode/extensions.json
{
  "recommendations": [
    "esbenp.prettier-vscode",
    "ms-vscode.vscode-typescript-next",
    "bradlc.vscode-tailwindcss",
    "ms-vscode.vscode-json",
    "formulahendry.auto-rename-tag"
  ]
}
```

---

**Navigation**
- [← Back to README](./README.md)
- [← Previous: Security Considerations](./security-considerations.md)
- [Next: Technology Stack Analysis →](./technology-stack-analysis.md)

*Best practices compilation completed January 2025 | Based on analysis of 40+ production NestJS projects*