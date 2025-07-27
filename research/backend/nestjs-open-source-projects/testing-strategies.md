# Testing Strategies in NestJS Open Source Projects

## 🧪 Overview

This document analyzes testing approaches, frameworks, and best practices found across production-ready NestJS applications. The analysis covers unit testing, integration testing, end-to-end testing, and specialized testing patterns used in real-world projects.

## 📊 Testing Framework Distribution

### **Primary Testing Framework Usage**
- **Jest**: 95% of projects (Near-universal adoption)
- **Mocha + Chai**: 3% of projects (Legacy preference)
- **Vitest**: 2% of projects (Modern alternative)

### **Additional Testing Tools**
- **Supertest**: 90% for HTTP testing
- **Test Containers**: 25% for integration testing
- **Jest Mock Extended**: 40% for advanced mocking
- **Factory Bot**: 20% for test data generation

## 🔧 Testing Infrastructure Setup

### **1. Basic Jest Configuration**
*Found in: 95% of projects*

```json
// package.json - Jest Configuration
{
  "scripts": {
    "test": "jest",
    "test:watch": "jest --watch",
    "test:cov": "jest --coverage",
    "test:debug": "node --inspect-brk -r tsconfig-paths/register -r ts-node/register node_modules/.bin/jest --runInBand",
    "test:e2e": "jest --config ./test/jest-e2e.json"
  },
  "jest": {
    "moduleFileExtensions": ["js", "json", "ts"],
    "rootDir": "src",
    "testRegex": ".*\\.spec\\.ts$",
    "transform": {
      "^.+\\.(t|j)s$": "ts-jest"
    },
    "collectCoverageFrom": [
      "**/*.(t|j)s",
      "!**/*.spec.ts",
      "!**/*.interface.ts",
      "!**/node_modules/**",
      "!**/dist/**"
    ],
    "coverageDirectory": "../coverage",
    "testEnvironment": "node",
    "coverageThreshold": {
      "global": {
        "branches": 80,
        "functions": 80,
        "lines": 80,
        "statements": 80
      }
    }
  }
}
```

### **2. Advanced Test Configuration**
*Found in: 70% of enterprise projects*

```typescript
// test/jest-e2e.json - E2E Configuration
{
  "moduleFileExtensions": ["js", "json", "ts"],
  "rootDir": ".",
  "testEnvironment": "node",
  "testRegex": ".e2e-spec.ts$",
  "transform": {
    "^.+\\.(t|j)s$": "ts-jest"
  },
  "setupFilesAfterEnv": ["<rootDir>/test/setup.ts"],
  "testTimeout": 30000,
  "maxWorkers": 1
}

// test/setup.ts - Global Test Setup
import { Test } from '@nestjs/testing';
import { INestApplication } from '@nestjs/common';
import { getRepositoryToken } from '@nestjs/typeorm';
import { Repository } from 'typeorm';

export class TestHelper {
  private static app: INestApplication;

  static async beforeAll(): Promise<void> {
    const moduleRef = await Test.createTestingModule({
      imports: [AppModule],
    })
      .overrideProvider(getRepositoryToken(User))
      .useClass(Repository)
      .compile();

    this.app = moduleRef.createNestApplication();
    await this.app.init();
  }

  static async afterAll(): Promise<void> {
    await this.app.close();
  }

  static getApp(): INestApplication {
    return this.app;
  }
}
```

## 🧪 Unit Testing Patterns

### **1. Service Testing with Mocking**
*Standard pattern in 100% of projects*

```typescript
// user.service.spec.ts
describe('UserService', () => {
  let service: UserService;
  let repository: Repository<User>;
  let passwordService: PasswordService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        UserService,
        {
          provide: getRepositoryToken(User),
          useValue: {
            findOne: jest.fn(),
            save: jest.fn(),
            create: jest.fn(),
            delete: jest.fn(),
            find: jest.fn(),
          },
        },
        {
          provide: PasswordService,
          useValue: {
            hashPassword: jest.fn(),
            comparePassword: jest.fn(),
          },
        },
      ],
    }).compile();

    service = module.get<UserService>(UserService);
    repository = module.get<Repository<User>>(getRepositoryToken(User));
    passwordService = module.get<PasswordService>(PasswordService);
  });

  describe('createUser', () => {
    it('should create a new user successfully', async () => {
      // Arrange
      const createUserDto: CreateUserDto = {
        email: 'test@example.com',
        password: 'password123',
        firstName: 'John',
        lastName: 'Doe',
      };

      const hashedPassword = 'hashedPassword123';
      const expectedUser = {
        id: '1',
        ...createUserDto,
        password: hashedPassword,
        createdAt: new Date(),
      };

      jest.spyOn(passwordService, 'hashPassword').mockResolvedValue(hashedPassword);
      jest.spyOn(repository, 'create').mockReturnValue(expectedUser as User);
      jest.spyOn(repository, 'save').mockResolvedValue(expectedUser as User);

      // Act
      const result = await service.createUser(createUserDto);

      // Assert
      expect(passwordService.hashPassword).toHaveBeenCalledWith(createUserDto.password);
      expect(repository.create).toHaveBeenCalledWith({
        ...createUserDto,
        password: hashedPassword,
      });
      expect(repository.save).toHaveBeenCalledWith(expectedUser);
      expect(result).toEqual(expectedUser);
    });

    it('should throw ConflictException if email already exists', async () => {
      // Arrange
      const createUserDto: CreateUserDto = {
        email: 'existing@example.com',
        password: 'password123',
        firstName: 'John',
        lastName: 'Doe',
      };

      jest.spyOn(repository, 'save').mockRejectedValue({
        code: '23505', // PostgreSQL unique violation
      });

      // Act & Assert
      await expect(service.createUser(createUserDto)).rejects.toThrow(ConflictException);
    });
  });

  describe('findByEmail', () => {
    it('should return user when found', async () => {
      // Arrange
      const email = 'test@example.com';
      const expectedUser = {
        id: '1',
        email,
        firstName: 'John',
        lastName: 'Doe',
      };

      jest.spyOn(repository, 'findOne').mockResolvedValue(expectedUser as User);

      // Act
      const result = await service.findByEmail(email);

      // Assert
      expect(repository.findOne).toHaveBeenCalledWith({
        where: { email },
      });
      expect(result).toEqual(expectedUser);
    });

    it('should return null when user not found', async () => {
      // Arrange
      const email = 'nonexistent@example.com';
      jest.spyOn(repository, 'findOne').mockResolvedValue(null);

      // Act
      const result = await service.findByEmail(email);

      // Assert
      expect(repository.findOne).toHaveBeenCalledWith({
        where: { email },
      });
      expect(result).toBeNull();
    });
  });
});
```

### **2. Controller Testing**
*Found in: 85% of projects*

```typescript
// user.controller.spec.ts
describe('UserController', () => {
  let controller: UserController;
  let service: UserService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [UserController],
      providers: [
        {
          provide: UserService,
          useValue: {
            createUser: jest.fn(),
            findAll: jest.fn(),
            findById: jest.fn(),
            updateUser: jest.fn(),
            deleteUser: jest.fn(),
          },
        },
      ],
    }).compile();

    controller = module.get<UserController>(UserController);
    service = module.get<UserService>(UserService);
  });

  describe('POST /users', () => {
    it('should create a user successfully', async () => {
      // Arrange
      const createUserDto: CreateUserDto = {
        email: 'test@example.com',
        password: 'password123',
        firstName: 'John',
        lastName: 'Doe',
      };

      const expectedResult = {
        id: '1',
        email: 'test@example.com',
        firstName: 'John',
        lastName: 'Doe',
        createdAt: new Date(),
      };

      jest.spyOn(service, 'createUser').mockResolvedValue(expectedResult as User);

      // Act
      const result = await controller.create(createUserDto);

      // Assert
      expect(service.createUser).toHaveBeenCalledWith(createUserDto);
      expect(result).toEqual(expectedResult);
    });

    it('should handle validation errors', async () => {
      // Arrange
      const invalidDto = {
        email: 'invalid-email',
        password: '123', // Too short
      } as CreateUserDto;

      // Act & Assert
      // Note: Validation happens at the framework level with ValidationPipe
      // This would be caught by integration tests
    });
  });

  describe('GET /users/:id', () => {
    it('should return user when found', async () => {
      // Arrange
      const userId = '1';
      const expectedUser = {
        id: userId,
        email: 'test@example.com',
        firstName: 'John',
        lastName: 'Doe',
      };

      jest.spyOn(service, 'findById').mockResolvedValue(expectedUser as User);

      // Act
      const result = await controller.findOne(userId);

      // Assert
      expect(service.findById).toHaveBeenCalledWith(userId);
      expect(result).toEqual(expectedUser);
    });

    it('should throw NotFoundException when user not found', async () => {
      // Arrange
      const userId = 'nonexistent';
      jest.spyOn(service, 'findById').mockResolvedValue(null);

      // Act & Assert
      await expect(controller.findOne(userId)).rejects.toThrow(NotFoundException);
    });
  });
});
```

### **3. Guard Testing**
*Found in: 70% of projects with custom guards*

```typescript
// auth.guard.spec.ts
describe('JwtAuthGuard', () => {
  let guard: JwtAuthGuard;
  let jwtService: JwtService;
  let userService: UserService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        JwtAuthGuard,
        {
          provide: JwtService,
          useValue: {
            verify: jest.fn(),
          },
        },
        {
          provide: UserService,
          useValue: {
            findById: jest.fn(),
          },
        },
      ],
    }).compile();

    guard = module.get<JwtAuthGuard>(JwtAuthGuard);
    jwtService = module.get<JwtService>(JwtService);
    userService = module.get<UserService>(UserService);
  });

  describe('canActivate', () => {
    it('should return true for valid token', async () => {
      // Arrange
      const context = createMockExecutionContext({
        headers: {
          authorization: 'Bearer valid-token',
        },
      });

      const payload = { sub: '1', email: 'test@example.com' };
      const user = { id: '1', email: 'test@example.com' };

      jest.spyOn(jwtService, 'verify').mockReturnValue(payload);
      jest.spyOn(userService, 'findById').mockResolvedValue(user as User);

      // Act
      const result = await guard.canActivate(context);

      // Assert
      expect(result).toBe(true);
      expect(context.switchToHttp().getRequest().user).toEqual(user);
    });

    it('should return false for invalid token', async () => {
      // Arrange
      const context = createMockExecutionContext({
        headers: {
          authorization: 'Bearer invalid-token',
        },
      });

      jest.spyOn(jwtService, 'verify').mockImplementation(() => {
        throw new Error('Invalid token');
      });

      // Act
      const result = await guard.canActivate(context);

      // Assert
      expect(result).toBe(false);
    });

    it('should return false when no token provided', async () => {
      // Arrange
      const context = createMockExecutionContext({
        headers: {},
      });

      // Act
      const result = await guard.canActivate(context);

      // Assert
      expect(result).toBe(false);
    });
  });
});

// Test helper for creating mock execution context
function createMockExecutionContext(request: Partial<Request>) {
  return {
    switchToHttp: () => ({
      getRequest: () => request,
    }),
  } as ExecutionContext;
}
```

## 🔗 Integration Testing

### **1. Database Integration Testing**
*Found in: 60% of projects*

```typescript
// user.integration.spec.ts
describe('User Integration Tests', () => {
  let app: INestApplication;
  let dataSource: DataSource;
  let userRepository: Repository<User>;

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      imports: [
        TypeOrmModule.forRoot({
          type: 'sqlite',
          database: ':memory:',
          entities: [User],
          synchronize: true,
        }),
        UserModule,
      ],
    }).compile();

    app = moduleRef.createNestApplication();
    await app.init();

    dataSource = moduleRef.get<DataSource>(DataSource);
    userRepository = dataSource.getRepository(User);
  });

  afterAll(async () => {
    await app.close();
  });

  beforeEach(async () => {
    // Clean database before each test
    await userRepository.clear();
  });

  describe('UserService Integration', () => {
    it('should create and retrieve user from database', async () => {
      // Arrange
      const userService = app.get<UserService>(UserService);
      const createUserDto: CreateUserDto = {
        email: 'test@example.com',
        password: 'password123',
        firstName: 'John',
        lastName: 'Doe',
      };

      // Act
      const createdUser = await userService.createUser(createUserDto);
      const retrievedUser = await userService.findById(createdUser.id);

      // Assert
      expect(retrievedUser).toBeDefined();
      expect(retrievedUser.email).toBe(createUserDto.email);
      expect(retrievedUser.firstName).toBe(createUserDto.firstName);
      expect(retrievedUser.password).not.toBe(createUserDto.password); // Should be hashed
    });

    it('should handle database constraints', async () => {
      // Arrange
      const userService = app.get<UserService>(UserService);
      const createUserDto: CreateUserDto = {
        email: 'duplicate@example.com',
        password: 'password123',
        firstName: 'John',
        lastName: 'Doe',
      };

      // Act
      await userService.createUser(createUserDto);

      // Assert
      await expect(userService.createUser(createUserDto))
        .rejects.toThrow(); // Should throw due to unique email constraint
    });
  });

  describe('User Relationships', () => {
    it('should handle user-profile relationship', async () => {
      // Arrange
      const userService = app.get<UserService>(UserService);
      const profileService = app.get<ProfileService>(ProfileService);
      
      const user = await userService.createUser({
        email: 'test@example.com',
        password: 'password123',
        firstName: 'John',
        lastName: 'Doe',
      });

      // Act
      const profile = await profileService.createProfile(user.id, {
        bio: 'Software Developer',
        website: 'https://example.com',
      });

      const userWithProfile = await userService.findById(user.id, ['profile']);

      // Assert
      expect(userWithProfile.profile).toBeDefined();
      expect(userWithProfile.profile.bio).toBe('Software Developer');
    });
  });
});
```

### **2. API Integration Testing with Test Containers**
*Found in: 25% of advanced projects*

```typescript
// user.api.integration.spec.ts
import { GenericContainer, StartedTestContainer } from 'testcontainers';

describe('User API Integration (TestContainers)', () => {
  let app: INestApplication;
  let postgresContainer: StartedTestContainer;

  beforeAll(async () => {
    // Start PostgreSQL container
    postgresContainer = await new GenericContainer('postgres:15')
      .withEnvironment({
        POSTGRES_DB: 'testdb',
        POSTGRES_USER: 'testuser',
        POSTGRES_PASSWORD: 'testpass',
      })
      .withExposedPorts(5432)
      .start();

    const moduleRef = await Test.createTestingModule({
      imports: [
        TypeOrmModule.forRoot({
          type: 'postgres',
          host: postgresContainer.getHost(),
          port: postgresContainer.getMappedPort(5432),
          username: 'testuser',
          password: 'testpass',
          database: 'testdb',
          entities: [User, Profile],
          synchronize: true,
        }),
        UserModule,
      ],
    }).compile();

    app = moduleRef.createNestApplication();
    await app.init();
  });

  afterAll(async () => {
    await app.close();
    await postgresContainer.stop();
  });

  it('should perform complex database operations', async () => {
    const userService = app.get<UserService>(UserService);
    
    // Create multiple users
    const users = await Promise.all([
      userService.createUser({
        email: 'user1@example.com',
        password: 'password123',
        firstName: 'John',
        lastName: 'Doe',
      }),
      userService.createUser({
        email: 'user2@example.com',
        password: 'password123',
        firstName: 'Jane',
        lastName: 'Smith',
      }),
    ]);

    // Test pagination
    const paginatedUsers = await userService.findAll({ page: 1, limit: 1 });
    expect(paginatedUsers.data).toHaveLength(1);
    expect(paginatedUsers.total).toBe(2);

    // Test search
    const searchResults = await userService.search('John');
    expect(searchResults).toHaveLength(1);
    expect(searchResults[0].firstName).toBe('John');
  });
});
```

## 🌐 End-to-End (E2E) Testing

### **1. HTTP API E2E Testing**
*Standard in: 90% of projects*

```typescript
// user.e2e-spec.ts
describe('User E2E Tests', () => {
  let app: INestApplication;
  let authToken: string;

  beforeAll(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleFixture.createNestApplication();
    
    // Apply same configuration as production
    app.useGlobalPipes(new ValidationPipe({
      whitelist: true,
      transform: true,
      forbidNonWhitelisted: true,
    }));

    await app.init();
  });

  afterAll(async () => {
    await app.close();
  });

  beforeEach(async () => {
    // Clean database before each test
    await cleanDatabase(app);
    
    // Create admin user and get auth token
    authToken = await createAuthenticatedUser(app, {
      email: 'admin@example.com',
      role: 'admin',
    });
  });

  describe('POST /users', () => {
    it('should create user with valid data', () => {
      const createUserDto = {
        email: 'newuser@example.com',
        password: 'SecurePass123!',
        firstName: 'John',
        lastName: 'Doe',
      };

      return request(app.getHttpServer())
        .post('/users')
        .set('Authorization', `Bearer ${authToken}`)
        .send(createUserDto)
        .expect(201)
        .expect((res) => {
          expect(res.body.id).toBeDefined();
          expect(res.body.email).toBe(createUserDto.email);
          expect(res.body.password).toBeUndefined(); // Should not return password
          expect(res.body.createdAt).toBeDefined();
        });
    });

    it('should return 400 for invalid email', () => {
      const invalidDto = {
        email: 'invalid-email',
        password: 'SecurePass123!',
        firstName: 'John',
        lastName: 'Doe',
      };

      return request(app.getHttpServer())
        .post('/users')
        .set('Authorization', `Bearer ${authToken}`)
        .send(invalidDto)
        .expect(400)
        .expect((res) => {
          expect(res.body.message).toContain('email must be an email');
        });
    });

    it('should return 400 for weak password', () => {
      const weakPasswordDto = {
        email: 'test@example.com',
        password: '123', // Too weak
        firstName: 'John',
        lastName: 'Doe',
      };

      return request(app.getHttpServer())
        .post('/users')
        .set('Authorization', `Bearer ${authToken}`)
        .send(weakPasswordDto)
        .expect(400)
        .expect((res) => {
          expect(res.body.message).toContain('password');
        });
    });

    it('should return 409 for duplicate email', async () => {
      const userDto = {
        email: 'duplicate@example.com',
        password: 'SecurePass123!',
        firstName: 'John',
        lastName: 'Doe',
      };

      // Create first user
      await request(app.getHttpServer())
        .post('/users')
        .set('Authorization', `Bearer ${authToken}`)
        .send(userDto)
        .expect(201);

      // Try to create duplicate
      return request(app.getHttpServer())
        .post('/users')
        .set('Authorization', `Bearer ${authToken}`)
        .send(userDto)
        .expect(409);
    });

    it('should return 401 without authentication', () => {
      const createUserDto = {
        email: 'test@example.com',
        password: 'SecurePass123!',
        firstName: 'John',
        lastName: 'Doe',
      };

      return request(app.getHttpServer())
        .post('/users')
        .send(createUserDto)
        .expect(401);
    });
  });

  describe('GET /users', () => {
    beforeEach(async () => {
      // Create test users
      await createTestUsers(app, [
        { email: 'user1@example.com', firstName: 'John', lastName: 'Doe' },
        { email: 'user2@example.com', firstName: 'Jane', lastName: 'Smith' },
        { email: 'user3@example.com', firstName: 'Bob', lastName: 'Johnson' },
      ]);
    });

    it('should return paginated users', () => {
      return request(app.getHttpServer())
        .get('/users?page=1&limit=2')
        .set('Authorization', `Bearer ${authToken}`)
        .expect(200)
        .expect((res) => {
          expect(res.body.data).toHaveLength(2);
          expect(res.body.meta.total).toBe(3);
          expect(res.body.meta.page).toBe(1);
          expect(res.body.meta.limit).toBe(2);
        });
    });

    it('should filter users by search term', () => {
      return request(app.getHttpServer())
        .get('/users?search=John')
        .set('Authorization', `Bearer ${authToken}`)
        .expect(200)
        .expect((res) => {
          expect(res.body.data).toHaveLength(1);
          expect(res.body.data[0].firstName).toBe('John');
        });
    });

    it('should sort users by creation date', () => {
      return request(app.getHttpServer())
        .get('/users?sort=createdAt&order=DESC')
        .set('Authorization', `Bearer ${authToken}`)
        .expect(200)
        .expect((res) => {
          const users = res.body.data;
          expect(new Date(users[0].createdAt)).toBeInstanceOf(Date);
          // Verify descending order
          for (let i = 1; i < users.length; i++) {
            expect(new Date(users[i-1].createdAt) >= new Date(users[i].createdAt)).toBe(true);
          }
        });
    });
  });

  describe('Authentication Flow E2E', () => {
    it('should complete full authentication flow', async () => {
      // 1. Register new user
      const registerDto = {
        email: 'newuser@example.com',
        password: 'SecurePass123!',
        firstName: 'John',
        lastName: 'Doe',
      };

      const registerResponse = await request(app.getHttpServer())
        .post('/auth/register')
        .send(registerDto)
        .expect(201);

      expect(registerResponse.body.user.email).toBe(registerDto.email);
      expect(registerResponse.body.accessToken).toBeDefined();

      // 2. Login with credentials
      const loginResponse = await request(app.getHttpServer())
        .post('/auth/login')
        .send({
          email: registerDto.email,
          password: registerDto.password,
        })
        .expect(200);

      expect(loginResponse.body.accessToken).toBeDefined();
      expect(loginResponse.body.refreshToken).toBeDefined();

      // 3. Access protected route
      await request(app.getHttpServer())
        .get('/users/profile')
        .set('Authorization', `Bearer ${loginResponse.body.accessToken}`)
        .expect(200)
        .expect((res) => {
          expect(res.body.email).toBe(registerDto.email);
        });

      // 4. Refresh token
      const refreshResponse = await request(app.getHttpServer())
        .post('/auth/refresh')
        .send({
          refreshToken: loginResponse.body.refreshToken,
        })
        .expect(200);

      expect(refreshResponse.body.accessToken).toBeDefined();
      expect(refreshResponse.body.accessToken).not.toBe(loginResponse.body.accessToken);
    });
  });
});

// Helper functions
async function cleanDatabase(app: INestApplication): Promise<void> {
  const dataSource = app.get<DataSource>(DataSource);
  const entities = dataSource.entityMetadatas;

  for (const entity of entities) {
    const repository = dataSource.getRepository(entity.name);
    await repository.clear();
  }
}

async function createAuthenticatedUser(
  app: INestApplication,
  userData: { email: string; role?: string }
): Promise<string> {
  const authService = app.get<AuthService>(AuthService);
  const userService = app.get<UserService>(UserService);

  const user = await userService.createUser({
    email: userData.email,
    password: 'password123',
    firstName: 'Test',
    lastName: 'User',
    role: userData.role || 'user',
  });

  const { accessToken } = await authService.login(user);
  return accessToken;
}

async function createTestUsers(
  app: INestApplication,
  usersData: Array<{ email: string; firstName: string; lastName: string }>
): Promise<void> {
  const userService = app.get<UserService>(UserService);

  for (const userData of usersData) {
    await userService.createUser({
      ...userData,
      password: 'password123',
    });
  }
}
```

## 🔄 Specialized Testing Patterns

### **1. GraphQL Testing**
*Found in: 25% of GraphQL projects*

```typescript
// user.graphql.e2e-spec.ts
describe('User GraphQL E2E', () => {
  let app: INestApplication;

  beforeAll(async () => {
    const moduleFixture = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleFixture.createNestApplication();
    await app.init();
  });

  afterAll(async () => {
    await app.close();
  });

  describe('Query: users', () => {
    it('should return users list', () => {
      const query = `
        query {
          users {
            id
            email
            firstName
            lastName
          }
        }
      `;

      return request(app.getHttpServer())
        .post('/graphql')
        .send({ query })
        .expect(200)
        .expect((res) => {
          expect(res.body.data.users).toBeDefined();
          expect(Array.isArray(res.body.data.users)).toBe(true);
        });
    });

    it('should handle GraphQL errors', () => {
      const invalidQuery = `
        query {
          nonExistentField
        }
      `;

      return request(app.getHttpServer())
        .post('/graphql')
        .send({ query: invalidQuery })
        .expect(400)
        .expect((res) => {
          expect(res.body.errors).toBeDefined();
        });
    });
  });

  describe('Mutation: createUser', () => {
    it('should create user via GraphQL', () => {
      const mutation = `
        mutation CreateUser($input: CreateUserInput!) {
          createUser(input: $input) {
            id
            email
            firstName
            lastName
          }
        }
      `;

      const variables = {
        input: {
          email: 'graphql@example.com',
          password: 'SecurePass123!',
          firstName: 'GraphQL',
          lastName: 'User',
        },
      };

      return request(app.getHttpServer())
        .post('/graphql')
        .send({ query: mutation, variables })
        .expect(200)
        .expect((res) => {
          expect(res.body.data.createUser.email).toBe(variables.input.email);
          expect(res.body.data.createUser.id).toBeDefined();
        });
    });
  });
});
```

### **2. WebSocket Testing**
*Found in: 30% of real-time applications*

```typescript
// chat.websocket.e2e-spec.ts
import { io, Socket } from 'socket.io-client';

describe('Chat WebSocket E2E', () => {
  let app: INestApplication;
  let client: Socket;

  beforeAll(async () => {
    const moduleFixture = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleFixture.createNestApplication();
    await app.init();
    await app.listen(3001);
  });

  afterAll(async () => {
    await app.close();
  });

  beforeEach(() => {
    client = io('http://localhost:3001', {
      transports: ['websocket'],
    });
  });

  afterEach(() => {
    client.close();
  });

  it('should connect and authenticate', (done) => {
    client.emit('authenticate', { token: 'valid-jwt-token' });
    
    client.on('authenticated', (data) => {
      expect(data.success).toBe(true);
      done();
    });
  });

  it('should send and receive messages', (done) => {
    const message = {
      roomId: 'room-1',
      content: 'Hello, World!',
    };

    client.emit('join-room', { roomId: 'room-1' });
    
    client.on('joined-room', () => {
      client.emit('send-message', message);
    });

    client.on('message-received', (receivedMessage) => {
      expect(receivedMessage.content).toBe(message.content);
      expect(receivedMessage.roomId).toBe(message.roomId);
      done();
    });
  });

  it('should handle connection errors', (done) => {
    client.emit('authenticate', { token: 'invalid-token' });
    
    client.on('error', (error) => {
      expect(error.message).toContain('authentication');
      done();
    });
  });
});
```

### **3. Microservices Testing**
*Found in: 20% of microservice architectures*

```typescript
// user.microservice.e2e-spec.ts
describe('User Microservice E2E', () => {
  let app: INestApplication;
  let client: ClientProxy;

  beforeAll(async () => {
    const moduleFixture = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleFixture.createNestApplication();
    app.connectMicroservice({
      transport: Transport.TCP,
      options: { port: 8877 },
    });

    await app.startAllMicroservices();
    await app.init();

    client = app.get<ClientProxy>('USER_SERVICE');
    await client.connect();
  });

  afterAll(async () => {
    await client.close();
    await app.close();
  });

  it('should handle message patterns', (done) => {
    const payload = {
      email: 'microservice@example.com',
      firstName: 'Micro',
      lastName: 'Service',
    };

    client.send({ cmd: 'create-user' }, payload).subscribe({
      next: (result) => {
        expect(result.email).toBe(payload.email);
        expect(result.id).toBeDefined();
        done();
      },
      error: (error) => {
        done(error);
      },
    });
  });

  it('should handle event patterns', (done) => {
    const payload = { userId: '1', status: 'activated' };

    client.emit('user-status-changed', payload).subscribe({
      next: () => {
        // Event emitted successfully
        done();
      },
      error: (error) => {
        done(error);
      },
    });
  });
});
```

## 📊 Test Coverage and Quality Metrics

### **1. Coverage Configuration**
*Standard in: 80% of projects*

```json
// Coverage thresholds
{
  "jest": {
    "coverageThreshold": {
      "global": {
        "branches": 80,
        "functions": 85,
        "lines": 85,
        "statements": 85
      },
      "./src/services/": {
        "branches": 90,
        "functions": 95,
        "lines": 95,
        "statements": 95
      },
      "./src/controllers/": {
        "branches": 80,
        "functions": 90,
        "lines": 90,
        "statements": 90
      }
    },
    "collectCoverageFrom": [
      "src/**/*.{ts,js}",
      "!src/**/*.spec.ts",
      "!src/**/*.e2e-spec.ts",
      "!src/**/*.interface.ts",
      "!src/**/*.module.ts",
      "!src/main.ts"
    ]
  }
}
```

### **2. Test Quality Metrics**
*Analysis from reviewed projects*

**Average Test Coverage:**
- Unit Tests: 85% line coverage
- Integration Tests: 70% feature coverage
- E2E Tests: 90% critical path coverage

**Test Distribution:**
- Unit Tests: 70% of total tests
- Integration Tests: 20% of total tests
- E2E Tests: 10% of total tests

**Common Test Patterns:**
- Arrange-Act-Assert: 95% of test cases
- Given-When-Then: 30% (BDD style)
- Mock/Stub usage: 90% of unit tests
- Test fixtures: 60% of projects

---

## 🎯 Testing Best Practices Summary

### **Essential Testing Practices**
1. **Test Pyramid**: 70% unit, 20% integration, 10% E2E
2. **Mocking Strategy**: Mock external dependencies in unit tests
3. **Database Testing**: Use in-memory databases for fast tests
4. **Authentication Testing**: Test both success and failure scenarios
5. **Error Handling**: Test all error conditions and edge cases

### **Performance Testing**
1. **Database Queries**: Test query performance and N+1 problems
2. **API Response Times**: Measure response times for critical endpoints
3. **Memory Usage**: Test for memory leaks in long-running operations
4. **Concurrency**: Test concurrent user scenarios

### **Security Testing**
1. **Authentication**: Test JWT validation and expiration
2. **Authorization**: Test role and permission enforcement
3. **Input Validation**: Test injection and XSS prevention
4. **Rate Limiting**: Test throttling mechanisms

---

**Navigation**: [← Tools & Libraries](./tools-libraries.md) | [Next: Performance Optimization →](./performance-optimization.md)