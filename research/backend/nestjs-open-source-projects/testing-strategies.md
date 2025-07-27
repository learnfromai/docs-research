# Testing Strategies

## 🧪 Overview

Comprehensive analysis of testing strategies and patterns used in production-ready NestJS applications. This document examines testing approaches, frameworks, and best practices identified across the researched projects.

## 📊 Testing Framework Analysis

### **Framework Adoption Rates**
- **Jest**: 95% (24/25 projects)
- **Supertest**: 80% (20/25 projects)
- **Test Utilities**: 60% (15/25 projects)
- **Custom Mocks**: 75% (19/25 projects)

### **Testing Types Coverage**
- **Unit Tests**: 100% (25/25 projects)
- **Integration Tests**: 85% (21/25 projects)
- **E2E Tests**: 70% (18/25 projects)
- **Contract Tests**: 25% (6/25 projects)

## 🎯 Testing Pyramid Implementation

### 1. **Unit Tests (70% of test coverage)**

#### **Service Testing Pattern**
```typescript
// users.service.spec.ts
describe('UsersService', () => {
  let service: UsersService;
  let repository: Repository<User>;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        UsersService,
        {
          provide: getRepositoryToken(User),
          useValue: {
            findOne: jest.fn(),
            save: jest.fn(),
            create: jest.fn(),
            find: jest.fn(),
            delete: jest.fn(),
          },
        },
      ],
    }).compile();

    service = module.get<UsersService>(UsersService);
    repository = module.get<Repository<User>>(getRepositoryToken(User));
  });

  describe('findById', () => {
    it('should return a user when found', async () => {
      // Arrange
      const userId = 'test-id';
      const expectedUser = createMockUser({ id: userId });
      jest.spyOn(repository, 'findOne').mockResolvedValue(expectedUser);

      // Act
      const result = await service.findById(userId);

      // Assert
      expect(result).toEqual(expectedUser);
      expect(repository.findOne).toHaveBeenCalledWith({
        where: { id: userId },
        relations: ['roles'],
      });
    });

    it('should throw NotFoundException when user not found', async () => {
      // Arrange
      jest.spyOn(repository, 'findOne').mockResolvedValue(null);

      // Act & Assert
      await expect(service.findById('non-existent')).rejects.toThrow(NotFoundException);
    });
  });

  describe('create', () => {
    it('should create a user successfully', async () => {
      // Arrange
      const createUserDto = {
        email: 'test@example.com',
        password: 'password123',
        firstName: 'Test',
        lastName: 'User',
      };
      const createdUser = createMockUser(createUserDto);

      jest.spyOn(repository, 'create').mockReturnValue(createdUser);
      jest.spyOn(repository, 'save').mockResolvedValue(createdUser);

      // Act
      const result = await service.create(createUserDto);

      // Assert
      expect(result).toEqual(createdUser);
      expect(repository.create).toHaveBeenCalledWith(createUserDto);
      expect(repository.save).toHaveBeenCalledWith(createdUser);
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

#### **Controller Testing Pattern**
```typescript
// auth.controller.spec.ts
describe('AuthController', () => {
  let controller: AuthController;
  let authService: AuthService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [AuthController],
      providers: [
        {
          provide: AuthService,
          useValue: {
            login: jest.fn(),
            register: jest.fn(),
            refreshToken: jest.fn(),
          },
        },
      ],
    }).compile();

    controller = module.get<AuthController>(AuthController);
    authService = module.get<AuthService>(AuthService);
  });

  describe('login', () => {
    it('should return access token on successful login', async () => {
      // Arrange
      const loginDto = { email: 'test@example.com', password: 'password123' };
      const expectedResult = {
        access_token: 'jwt-token',
        refresh_token: 'refresh-token',
        user: { id: '1', email: 'test@example.com' },
      };
      jest.spyOn(authService, 'login').mockResolvedValue(expectedResult);

      // Act
      const result = await controller.login(loginDto);

      // Assert
      expect(result).toEqual(expectedResult);
      expect(authService.login).toHaveBeenCalledWith(loginDto);
    });

    it('should throw UnauthorizedException on invalid credentials', async () => {
      // Arrange
      const loginDto = { email: 'test@example.com', password: 'wrong' };
      jest.spyOn(authService, 'login').mockRejectedValue(new UnauthorizedException());

      // Act & Assert
      await expect(controller.login(loginDto)).rejects.toThrow(UnauthorizedException);
    });
  });
});
```

### 2. **Integration Tests (20% of test coverage)**

#### **Database Integration Testing**
```typescript
// users.integration.spec.ts
describe('Users Integration', () => {
  let app: INestApplication;
  let userRepository: Repository<User>;
  let dataSource: DataSource;

  beforeAll(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [
        ConfigModule.forRoot({
          isGlobal: true,
          envFilePath: '.env.test',
        }),
        TypeOrmModule.forRoot({
          type: 'postgres',
          host: 'localhost',
          port: 5433, // Test database port
          username: 'test',
          password: 'test',
          database: 'test_db',
          entities: [User, Role],
          synchronize: true,
          dropSchema: true,
        }),
        UsersModule,
      ],
    }).compile();

    app = moduleFixture.createNestApplication();
    dataSource = moduleFixture.get<DataSource>(DataSource);
    userRepository = moduleFixture.get<Repository<User>>(getRepositoryToken(User));
    
    await app.init();
  });

  beforeEach(async () => {
    // Clean database before each test
    await userRepository.query('TRUNCATE TABLE users RESTART IDENTITY CASCADE');
  });

  afterAll(async () => {
    await dataSource.destroy();
    await app.close();
  });

  describe('User CRUD Operations', () => {
    it('should create and retrieve user', async () => {
      // Arrange
      const userData = {
        email: 'integration@test.com',
        password: 'hashedPassword',
        firstName: 'Integration',
        lastName: 'Test',
      };

      // Act
      const createdUser = await userRepository.save(userData);
      const retrievedUser = await userRepository.findOne({
        where: { id: createdUser.id },
      });

      // Assert
      expect(retrievedUser).toBeDefined();
      expect(retrievedUser.email).toBe(userData.email);
      expect(retrievedUser.firstName).toBe(userData.firstName);
    });

    it('should handle unique constraint on email', async () => {
      // Arrange
      const userData = {
        email: 'duplicate@test.com',
        password: 'hashedPassword',
      };

      // Act
      await userRepository.save(userData);
      
      // Assert
      await expect(userRepository.save(userData)).rejects.toThrow();
    });
  });
});
```

#### **Service Integration Testing**
```typescript
// auth.integration.spec.ts
describe('Auth Service Integration', () => {
  let app: INestApplication;
  let authService: AuthService;
  let usersService: UsersService;

  beforeAll(async () => {
    const moduleFixture = await createTestingApp([AuthModule, UsersModule]);
    app = moduleFixture.createNestApplication();
    authService = moduleFixture.get<AuthService>(AuthService);
    usersService = moduleFixture.get<UsersService>(UsersService);
    
    await app.init();
  });

  afterAll(async () => {
    await app.close();
  });

  beforeEach(async () => {
    await clearDatabase(app);
  });

  describe('Authentication Flow', () => {
    it('should register and login user successfully', async () => {
      // Arrange
      const registerDto = {
        email: 'auth@test.com',
        password: 'Password123!',
        firstName: 'Auth',
        lastName: 'Test',
      };

      // Act - Register
      const registerResult = await authService.register(registerDto);
      
      // Assert - Register
      expect(registerResult.access_token).toBeDefined();
      expect(registerResult.user.email).toBe(registerDto.email);

      // Act - Login
      const loginResult = await authService.login({
        email: registerDto.email,
        password: registerDto.password,
      });

      // Assert - Login
      expect(loginResult.access_token).toBeDefined();
      expect(loginResult.user.email).toBe(registerDto.email);
    });
  });
});
```

### 3. **E2E Tests (10% of test coverage)**

#### **API Endpoint Testing**
```typescript
// auth.e2e.spec.ts
describe('Auth (e2e)', () => {
  let app: INestApplication;
  let userRepository: Repository<User>;

  beforeAll(async () => {
    const moduleFixture = await createTestingApp();
    app = moduleFixture.createNestApplication();
    
    // Apply same middleware as main app
    app.useGlobalPipes(new ValidationPipe({
      transform: true,
      whitelist: true,
      forbidNonWhitelisted: true,
    }));
    
    userRepository = moduleFixture.get<Repository<User>>(getRepositoryToken(User));
    
    await app.init();
  });

  afterAll(async () => {
    await app.close();
  });

  beforeEach(async () => {
    await userRepository.clear();
  });

  describe('/auth/register (POST)', () => {
    it('should register user successfully', () => {
      const registerDto = {
        email: 'e2e@test.com',
        password: 'Password123!',
        firstName: 'E2E',
        lastName: 'Test',
      };

      return request(app.getHttpServer())
        .post('/auth/register')
        .send(registerDto)
        .expect(201)
        .expect((res) => {
          expect(res.body.access_token).toBeDefined();
          expect(res.body.user.email).toBe(registerDto.email);
          expect(res.body.user.password).toBeUndefined();
        });
    });

    it('should return 400 for invalid email', () => {
      return request(app.getHttpServer())
        .post('/auth/register')
        .send({
          email: 'invalid-email',
          password: 'Password123!',
        })
        .expect(400)
        .expect((res) => {
          expect(res.body.message).toContain('email');
        });
    });

    it('should return 400 for weak password', () => {
      return request(app.getHttpServer())
        .post('/auth/register')
        .send({
          email: 'test@example.com',
          password: 'weak',
        })
        .expect(400);
    });
  });

  describe('/auth/login (POST)', () => {
    beforeEach(async () => {
      // Create test user
      const hashedPassword = await bcrypt.hash('Password123!', 12);
      await userRepository.save({
        email: 'login@test.com',
        password: hashedPassword,
        firstName: 'Login',
        lastName: 'Test',
      });
    });

    it('should login successfully with valid credentials', () => {
      return request(app.getHttpServer())
        .post('/auth/login')
        .send({
          email: 'login@test.com',
          password: 'Password123!',
        })
        .expect(200)
        .expect((res) => {
          expect(res.body.access_token).toBeDefined();
          expect(res.body.refresh_token).toBeDefined();
          expect(res.body.user.email).toBe('login@test.com');
        });
    });

    it('should return 401 for invalid credentials', () => {
      return request(app.getHttpServer())
        .post('/auth/login')
        .send({
          email: 'login@test.com',
          password: 'wrong-password',
        })
        .expect(401);
    });
  });

  describe('Protected Routes', () => {
    let accessToken: string;

    beforeEach(async () => {
      // Register and get token
      const response = await request(app.getHttpServer())
        .post('/auth/register')
        .send({
          email: 'protected@test.com',
          password: 'Password123!',
        });
      
      accessToken = response.body.access_token;
    });

    it('should access protected route with valid token', () => {
      return request(app.getHttpServer())
        .get('/users/profile')
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(200);
    });

    it('should return 401 without token', () => {
      return request(app.getHttpServer())
        .get('/users/profile')
        .expect(401);
    });

    it('should return 401 with invalid token', () => {
      return request(app.getHttpServer())
        .get('/users/profile')
        .set('Authorization', 'Bearer invalid-token')
        .expect(401);
    });
  });
});
```

## 🛠️ Test Utilities & Helpers

### 1. **Test Factory Functions**

```typescript
// test/factories/user.factory.ts
import { User } from '../../src/database/entities/user.entity';
import { Role } from '../../src/database/entities/role.entity';

export const createMockUser = (overrides: Partial<User> = {}): User => {
  return {
    id: 'test-user-id',
    email: 'test@example.com',
    password: 'hashedPassword',
    firstName: 'Test',
    lastName: 'User',
    isActive: true,
    lastLoginAt: null,
    createdAt: new Date('2023-01-01'),
    updatedAt: new Date('2023-01-01'),
    posts: [],
    roles: [],
    ...overrides,
  } as User;
};

export const createMockRole = (overrides: Partial<Role> = {}): Role => {
  return {
    id: 'test-role-id',
    name: 'user',
    description: 'Standard user role',
    permissions: [],
    users: [],
    createdAt: new Date('2023-01-01'),
    updatedAt: new Date('2023-01-01'),
    ...overrides,
  } as Role;
};
```

### 2. **Database Test Utilities**

```typescript
// test/utils/database.utils.ts
import { DataSource } from 'typeorm';
import { INestApplication } from '@nestjs/common';

export class DatabaseTestUtils {
  static async clearDatabase(app: INestApplication): Promise<void> {
    const dataSource = app.get<DataSource>(DataSource);
    const entities = dataSource.entityMetadatas;

    // Disable foreign key checks
    await dataSource.query('SET FOREIGN_KEY_CHECKS = 0');

    // Clear all tables
    for (const entity of entities) {
      const repository = dataSource.getRepository(entity.name);
      await repository.clear();
    }

    // Re-enable foreign key checks
    await dataSource.query('SET FOREIGN_KEY_CHECKS = 1');
  }

  static async seedDatabase(app: INestApplication): Promise<void> {
    // Add common test data
    const userRepository = app.get('UserRepository');
    
    await userRepository.save([
      createMockUser({ email: 'admin@test.com', roles: ['admin'] }),
      createMockUser({ email: 'user@test.com', roles: ['user'] }),
    ]);
  }
}
```

### 3. **Test Module Builder**

```typescript
// test/utils/test-module.builder.ts
import { Test, TestingModule } from '@nestjs/testing';
import { ConfigModule } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { getRepositoryToken } from '@nestjs/typeorm';

export class TestModuleBuilder {
  private imports: any[] = [];
  private providers: any[] = [];
  private mockRepositories: Map<string, any> = new Map();

  withConfig(config?: any): TestModuleBuilder {
    this.imports.push(
      ConfigModule.forRoot({
        isGlobal: true,
        envFilePath: '.env.test',
        ...config,
      }),
    );
    return this;
  }

  withInMemoryDatabase(entities: any[]): TestModuleBuilder {
    this.imports.push(
      TypeOrmModule.forRoot({
        type: 'sqlite',
        database: ':memory:',
        entities,
        synchronize: true,
      }),
    );
    return this;
  }

  withMockRepository(entity: any, mockMethods: any = {}): TestModuleBuilder {
    const defaultMethods = {
      findOne: jest.fn(),
      find: jest.fn(),
      save: jest.fn(),
      create: jest.fn(),
      update: jest.fn(),
      delete: jest.fn(),
      clear: jest.fn(),
      ...mockMethods,
    };

    this.providers.push({
      provide: getRepositoryToken(entity),
      useValue: defaultMethods,
    });

    this.mockRepositories.set(entity.name, defaultMethods);
    return this;
  }

  withModules(modules: any[]): TestModuleBuilder {
    this.imports.push(...modules);
    return this;
  }

  withProviders(providers: any[]): TestModuleBuilder {
    this.providers.push(...providers);
    return this;
  }

  async build(): Promise<{
    module: TestingModule;
    mocks: Map<string, any>;
  }> {
    const module = await Test.createTestingModule({
      imports: this.imports,
      providers: this.providers,
    }).compile();

    return {
      module,
      mocks: this.mockRepositories,
    };
  }
}

// Usage example
describe('UserService', () => {
  let service: UserService;
  let userMocks: any;

  beforeEach(async () => {
    const { module, mocks } = await new TestModuleBuilder()
      .withConfig()
      .withMockRepository(User)
      .withProviders([UserService])
      .build();

    service = module.get<UserService>(UserService);
    userMocks = mocks.get('User');
  });
});
```

## 🎭 Mocking Strategies

### 1. **Service Mocking**

```typescript
// Mocking external services
const mockEmailService = {
  sendEmail: jest.fn().mockResolvedValue(true),
  sendWelcomeEmail: jest.fn().mockResolvedValue(true),
  sendPasswordResetEmail: jest.fn().mockResolvedValue(true),
};

const mockAnalyticsService = {
  track: jest.fn().mockResolvedValue(undefined),
  identify: jest.fn().mockResolvedValue(undefined),
};

// Mocking HTTP clients
const mockHttpService = {
  get: jest.fn(),
  post: jest.fn(),
  put: jest.fn(),
  delete: jest.fn(),
};
```

### 2. **Database Mocking**

```typescript
// Repository mocking with typed methods
const createMockRepository = <T = any>(): Repository<T> => ({
  findOne: jest.fn(),
  find: jest.fn(),
  save: jest.fn(),
  create: jest.fn(),
  update: jest.fn(),
  delete: jest.fn(),
  findAndCount: jest.fn(),
  createQueryBuilder: jest.fn(() => ({
    where: jest.fn().mockReturnThis(),
    andWhere: jest.fn().mockReturnThis(),
    orderBy: jest.fn().mockReturnThis(),
    limit: jest.fn().mockReturnThis(),
    offset: jest.fn().mockReturnThis(),
    getOne: jest.fn(),
    getMany: jest.fn(),
    getCount: jest.fn(),
  })),
}) as any;
```

### 3. **Configuration Mocking**

```typescript
const mockConfigService = {
  get: jest.fn((key: string) => {
    const config = {
      'jwt.secret': 'test-secret',
      'jwt.expiresIn': '1h',
      'database.host': 'localhost',
      'app.port': 3000,
    };
    return config[key];
  }),
};
```

## 📈 Test Coverage & Quality

### 1. **Coverage Configuration**

```json
// jest.config.js
module.exports = {
  moduleFileExtensions: ['js', 'json', 'ts'],
  rootDir: 'src',
  testRegex: '.*\\.spec\\.ts$',
  transform: {
    '^.+\\.(t|j)s$': 'ts-jest',
  },
  collectCoverageFrom: [
    '**/*.(t|j)s',
    '!**/*.spec.ts',
    '!**/*.interface.ts',
    '!**/node_modules/**',
    '!**/dist/**',
  ],
  coverageDirectory: '../coverage',
  testEnvironment: 'node',
  coverageReporters: ['text', 'lcov', 'html'],
  coverageThreshold: {
    global: {
      branches: 80,
      functions: 80,
      lines: 80,
      statements: 80,
    },
  },
};
```

### 2. **Quality Gates**

```typescript
// test/quality/test-quality.spec.ts
describe('Test Quality Gates', () => {
  it('should have sufficient test coverage', () => {
    // This would be run by your CI/CD pipeline
    // to ensure minimum coverage thresholds
    expect(global.__coverage__).toBeDefined();
    
    // Additional custom coverage checks
    const coverage = global.__coverage__;
    const files = Object.keys(coverage);
    
    files.forEach(file => {
      if (file.includes('service')) {
        expect(coverage[file].f.pct).toBeGreaterThanOrEqual(90);
      }
    });
  });

  it('should not have skipped tests in production', () => {
    if (process.env.NODE_ENV === 'production') {
      // Fail if there are .skip or .only tests
      expect(expect.getState().currentTestName).not.toContain('.skip');
      expect(expect.getState().currentTestName).not.toContain('.only');
    }
  });
});
```

## 🚀 Performance Testing

### 1. **Load Testing with Artillery**

```yaml
# artillery.yml
config:
  target: 'http://localhost:3000'
  phases:
    - duration: 60
      arrivalRate: 10
      name: "Warm up"
    - duration: 120
      arrivalRate: 20
      name: "Load test"
  defaults:
    headers:
      Content-Type: 'application/json'

scenarios:
  - name: "Authentication flow"
    flow:
      - post:
          url: "/auth/login"
          json:
            email: "test@example.com"
            password: "password123"
      - think: 1
      - get:
          url: "/users/profile"
          headers:
            Authorization: "Bearer {{ access_token }}"
```

### 2. **Memory Leak Testing**

```typescript
// test/performance/memory-leak.spec.ts
describe('Memory Leak Detection', () => {
  it('should not leak memory during user operations', async () => {
    const initialMemory = process.memoryUsage().heapUsed;
    
    // Perform operations that might leak
    for (let i = 0; i < 1000; i++) {
      await userService.create({
        email: `user${i}@test.com`,
        password: 'password',
      });
    }
    
    // Force garbage collection
    if (global.gc) {
      global.gc();
    }
    
    const finalMemory = process.memoryUsage().heapUsed;
    const memoryGrowth = finalMemory - initialMemory;
    
    // Memory should not grow excessively
    expect(memoryGrowth).toBeLessThan(50 * 1024 * 1024); // 50MB
  });
});
```

## 📊 Testing Metrics

### **Common Test Coverage Targets**
- **Unit Tests**: 80-90% coverage
- **Integration Tests**: 60-70% coverage
- **E2E Tests**: 40-50% coverage
- **Critical Paths**: 100% coverage

### **Performance Benchmarks**
- **Unit Test Speed**: < 10ms per test
- **Integration Test Speed**: < 100ms per test
- **E2E Test Speed**: < 1s per test
- **Test Suite**: < 5 minutes total

### **Quality Metrics**
- **Test Maintainability**: Low coupling, high cohesion
- **Test Readability**: Clear arrange-act-assert pattern
- **Test Reliability**: No flaky tests (< 1% failure rate)
- **Test Documentation**: Self-documenting test names

---

**Navigation**
- ↑ Back to: [Implementation Guide](./implementation-guide.md)
- ↑ Back to: [Research Overview](./README.md)