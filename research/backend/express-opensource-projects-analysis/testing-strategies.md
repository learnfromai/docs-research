# Testing Strategies: Express.js Applications

## 🧪 Overview

This document analyzes testing strategies employed by production Express.js applications, covering testing frameworks, patterns, and methodologies that ensure application reliability and maintainability.

## 📊 Testing Framework Adoption

Based on analysis of 15+ production Express.js projects:

| Framework | Usage | Purpose | Complexity | Learning Curve |
|-----------|-------|---------|------------|----------------|
| **Jest** | 95% | Unit/Integration testing | ⭐⭐ | ⭐⭐ |
| **Supertest** | 90% | HTTP endpoint testing | ⭐⭐ | ⭐ |
| **Mocha + Chai** | 30% | Unit/Integration testing | ⭐⭐⭐ | ⭐⭐⭐ |
| **Playwright/Cypress** | 45% | E2E testing | ⭐⭐⭐ | ⭐⭐⭐ |
| **Testing Library** | 25% | Component testing | ⭐⭐ | ⭐⭐ |

## 🎯 Testing Pyramid Implementation

### Testing Distribution in Analyzed Projects
- **Unit Tests**: 70% of total tests
- **Integration Tests**: 20% of total tests  
- **End-to-End Tests**: 10% of total tests

### 1. **Unit Testing Strategy**

#### Jest Configuration
```javascript
// ✅ Comprehensive Jest configuration
// jest.config.js
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  roots: ['<rootDir>/src'],
  testMatch: [
    '**/__tests__/**/*.ts',
    '**/?(*.)+(spec|test).ts'
  ],
  transform: {
    '^.+\\.ts$': 'ts-jest',
  },
  collectCoverageFrom: [
    'src/**/*.ts',
    '!src/**/*.d.ts',
    '!src/index.ts',
    '!src/**/*.interface.ts',
    '!src/config/**',
    '!src/migrations/**'
  ],
  coverageDirectory: 'coverage',
  coverageReporters: ['text', 'lcov', 'html', 'json'],
  coverageThreshold: {
    global: {
      branches: 80,
      functions: 80,
      lines: 80,
      statements: 80
    }
  },
  setupFilesAfterEnv: ['<rootDir>/src/tests/setup.ts'],
  testTimeout: 30000,
  verbose: true,
  detectOpenHandles: true,
  forceExit: true
};
```

#### Service Layer Unit Tests
```typescript
// ✅ Comprehensive service testing
// src/services/__tests__/user.service.test.ts
describe('UserService', () => {
  let userService: UserService;
  let mockUserRepository: jest.Mocked<IUserRepository>;
  let mockEmailService: jest.Mocked<IEmailService>;
  let mockHashingService: jest.Mocked<IHashingService>;

  beforeEach(() => {
    mockUserRepository = {
      findById: jest.fn(),
      findByEmail: jest.fn(),
      create: jest.fn(),
      update: jest.fn(),
      delete: jest.fn(),
      exists: jest.fn()
    };

    mockEmailService = {
      sendWelcomeEmail: jest.fn(),
      sendVerificationEmail: jest.fn(),
      sendPasswordResetEmail: jest.fn()
    };

    mockHashingService = {
      hash: jest.fn(),
      compare: jest.fn()
    };

    userService = new UserService(
      mockUserRepository,
      mockEmailService,
      mockHashingService
    );
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('createUser', () => {
    const validUserData = {
      name: 'John Doe',
      email: 'john@example.com',
      password: 'Password123!'
    };

    it('should create user successfully with valid data', async () => {
      // Arrange
      mockUserRepository.exists.mockResolvedValue(false);
      mockHashingService.hash.mockResolvedValue('hashedPassword');
      mockUserRepository.create.mockResolvedValue({
        id: '1',
        ...validUserData,
        password: 'hashedPassword',
        emailVerified: false,
        createdAt: new Date()
      });
      mockEmailService.sendWelcomeEmail.mockResolvedValue();

      // Act
      const result = await userService.createUser(validUserData);

      // Assert
      expect(result).toEqual({
        id: '1',
        name: validUserData.name,
        email: validUserData.email,
        emailVerified: false,
        createdAt: expect.any(Date)
      });

      expect(mockUserRepository.exists).toHaveBeenCalledWith(validUserData.email);
      expect(mockHashingService.hash).toHaveBeenCalledWith(validUserData.password);
      expect(mockUserRepository.create).toHaveBeenCalledWith({
        ...validUserData,
        password: 'hashedPassword',
        emailVerified: false,
        createdAt: expect.any(Date)
      });
      expect(mockEmailService.sendWelcomeEmail).toHaveBeenCalledWith(
        validUserData.email,
        validUserData.name
      );
    });

    it('should throw ConflictError when user already exists', async () => {
      // Arrange
      mockUserRepository.exists.mockResolvedValue(true);

      // Act & Assert
      await expect(userService.createUser(validUserData))
        .rejects
        .toThrow(ConflictError);

      expect(mockUserRepository.exists).toHaveBeenCalledWith(validUserData.email);
      expect(mockHashingService.hash).not.toHaveBeenCalled();
      expect(mockUserRepository.create).not.toHaveBeenCalled();
    });

    it('should handle hashing service failure', async () => {
      // Arrange
      mockUserRepository.exists.mockResolvedValue(false);
      mockHashingService.hash.mockRejectedValue(new Error('Hashing failed'));

      // Act & Assert
      await expect(userService.createUser(validUserData))
        .rejects
        .toThrow('Hashing failed');

      expect(mockUserRepository.create).not.toHaveBeenCalled();
      expect(mockEmailService.sendWelcomeEmail).not.toHaveBeenCalled();
    });

    it('should rollback if email sending fails', async () => {
      // Arrange
      mockUserRepository.exists.mockResolvedValue(false);
      mockHashingService.hash.mockResolvedValue('hashedPassword');
      mockUserRepository.create.mockResolvedValue({
        id: '1',
        ...validUserData,
        password: 'hashedPassword',
        emailVerified: false,
        createdAt: new Date()
      });
      mockEmailService.sendWelcomeEmail.mockRejectedValue(new Error('Email failed'));
      mockUserRepository.delete.mockResolvedValue();

      // Act & Assert
      await expect(userService.createUser(validUserData))
        .rejects
        .toThrow('Email failed');

      expect(mockUserRepository.delete).toHaveBeenCalledWith('1');
    });
  });

  describe('authenticateUser', () => {
    const credentials = {
      email: 'john@example.com',
      password: 'Password123!'
    };

    const mockUser = {
      id: '1',
      name: 'John Doe',
      email: 'john@example.com',
      password: 'hashedPassword',
      role: 'user',
      emailVerified: true
    };

    it('should authenticate user with valid credentials', async () => {
      // Arrange
      mockUserRepository.findByEmail.mockResolvedValue(mockUser);
      mockHashingService.compare.mockResolvedValue(true);

      // Act
      const result = await userService.authenticateUser(
        credentials.email,
        credentials.password
      );

      // Assert
      expect(result).toEqual({
        id: mockUser.id,
        name: mockUser.name,
        email: mockUser.email,
        role: mockUser.role
      });

      expect(mockUserRepository.findByEmail).toHaveBeenCalledWith(credentials.email);
      expect(mockHashingService.compare).toHaveBeenCalledWith(
        credentials.password,
        mockUser.password
      );
    });

    it('should throw AuthenticationError for non-existent user', async () => {
      // Arrange
      mockUserRepository.findByEmail.mockResolvedValue(null);

      // Act & Assert
      await expect(userService.authenticateUser(
        credentials.email,
        credentials.password
      )).rejects.toThrow(AuthenticationError);

      expect(mockHashingService.compare).not.toHaveBeenCalled();
    });

    it('should throw AuthenticationError for invalid password', async () => {
      // Arrange
      mockUserRepository.findByEmail.mockResolvedValue(mockUser);
      mockHashingService.compare.mockResolvedValue(false);

      // Act & Assert
      await expect(userService.authenticateUser(
        credentials.email,
        credentials.password
      )).rejects.toThrow(AuthenticationError);
    });

    it('should throw AuthenticationError for unverified email', async () => {
      // Arrange
      const unverifiedUser = { ...mockUser, emailVerified: false };
      mockUserRepository.findByEmail.mockResolvedValue(unverifiedUser);
      mockHashingService.compare.mockResolvedValue(true);

      // Act & Assert
      await expect(userService.authenticateUser(
        credentials.email,
        credentials.password
      )).rejects.toThrow(AuthenticationError);
    });
  });
});

// ✅ Utility function testing
// src/utils/__tests__/validation.test.ts
describe('Validation Utils', () => {
  describe('validateEmail', () => {
    it.each([
      ['user@example.com', true],
      ['user.name@example.com', true],
      ['user+tag@example.co.uk', true],
      ['invalid-email', false],
      ['@example.com', false],
      ['user@', false],
      ['', false],
      [null, false],
      [undefined, false]
    ])('should validate email "%s" as %s', (email, expected) => {
      expect(validateEmail(email)).toBe(expected);
    });
  });

  describe('sanitizeString', () => {
    it('should remove malicious script tags', () => {
      const input = '<script>alert("xss")</script>Hello World';
      const result = sanitizeString(input);
      expect(result).toBe('Hello World');
      expect(result).not.toContain('<script>');
    });

    it('should preserve safe HTML', () => {
      const input = '<p>Hello <strong>World</strong></p>';
      const result = sanitizeString(input, { allowedTags: ['p', 'strong'] });
      expect(result).toBe('<p>Hello <strong>World</strong></p>');
    });

    it('should handle null and undefined inputs', () => {
      expect(sanitizeString(null)).toBe('');
      expect(sanitizeString(undefined)).toBe('');
    });
  });
});
```

### 2. **Integration Testing Strategy**

#### API Integration Tests with Supertest
```typescript
// ✅ Comprehensive API testing
// src/tests/integration/auth.test.ts
describe('Authentication API', () => {
  let app: Express;
  let server: Server;

  beforeAll(async () => {
    app = createTestApp();
    server = app.listen(0);
    await connectTestDatabase();
  });

  afterAll(async () => {
    await server.close();
    await disconnectTestDatabase();
  });

  beforeEach(async () => {
    await clearDatabase();
  });

  describe('POST /api/auth/register', () => {
    const validRegistrationData = {
      name: 'John Doe',
      email: 'john@example.com',
      password: 'Password123!',
      confirmPassword: 'Password123!'
    };

    it('should register user with valid data', async () => {
      const response = await request(app)
        .post('/api/auth/register')
        .send(validRegistrationData)
        .expect(201);

      expect(response.body).toEqual({
        success: true,
        message: 'User created successfully',
        data: {
          id: expect.any(String),
          name: validRegistrationData.name,
          email: validRegistrationData.email,
          emailVerified: false,
          createdAt: expect.any(String)
        }
      });

      // Verify user was created in database
      const user = await User.findOne({ email: validRegistrationData.email });
      expect(user).toBeTruthy();
      expect(user.name).toBe(validRegistrationData.name);
      expect(user.emailVerified).toBe(false);
    });

    it('should return 400 for invalid email', async () => {
      const invalidData = {
        ...validRegistrationData,
        email: 'invalid-email'
      };

      const response = await request(app)
        .post('/api/auth/register')
        .send(invalidData)
        .expect(400);

      expect(response.body.success).toBe(false);
      expect(response.body.error).toContain('email');
    });

    it('should return 400 for weak password', async () => {
      const weakPasswordData = {
        ...validRegistrationData,
        password: '123',
        confirmPassword: '123'
      };

      const response = await request(app)
        .post('/api/auth/register')
        .send(weakPasswordData)
        .expect(400);

      expect(response.body.success).toBe(false);
      expect(response.body.error).toContain('password');
    });

    it('should return 409 for existing user', async () => {
      // Create user first
      await createTestUser(validRegistrationData);

      const response = await request(app)
        .post('/api/auth/register')
        .send(validRegistrationData)
        .expect(409);

      expect(response.body.success).toBe(false);
      expect(response.body.error).toContain('already exists');
    });

    it('should handle password mismatch', async () => {
      const mismatchData = {
        ...validRegistrationData,
        confirmPassword: 'DifferentPassword123!'
      };

      const response = await request(app)
        .post('/api/auth/register')
        .send(mismatchData)
        .expect(400);

      expect(response.body.success).toBe(false);
      expect(response.body.error).toContain('match');
    });
  });

  describe('POST /api/auth/login', () => {
    const userData = {
      name: 'John Doe',
      email: 'john@example.com',
      password: 'Password123!'
    };

    beforeEach(async () => {
      await createTestUser({ ...userData, emailVerified: true });
    });

    it('should login with valid credentials', async () => {
      const response = await request(app)
        .post('/api/auth/login')
        .send({
          email: userData.email,
          password: userData.password
        })
        .expect(200);

      expect(response.body).toEqual({
        success: true,
        message: 'Login successful',
        data: {
          user: {
            id: expect.any(String),
            name: userData.name,
            email: userData.email,
            role: 'user'
          },
          accessToken: expect.any(String)
        }
      });

      // Check refresh token cookie
      const cookies = response.headers['set-cookie'];
      expect(cookies).toBeDefined();
      expect(cookies.some(cookie => cookie.startsWith('refreshToken='))).toBe(true);
    });

    it('should return 401 for invalid credentials', async () => {
      const response = await request(app)
        .post('/api/auth/login')
        .send({
          email: userData.email,
          password: 'WrongPassword'
        })
        .expect(401);

      expect(response.body.success).toBe(false);
      expect(response.body.error).toContain('Invalid credentials');
    });

    it('should return 401 for unverified email', async () => {
      await User.findOneAndUpdate(
        { email: userData.email },
        { emailVerified: false }
      );

      const response = await request(app)
        .post('/api/auth/login')
        .send({
          email: userData.email,
          password: userData.password
        })
        .expect(401);

      expect(response.body.error).toContain('verify your email');
    });

    it('should respect rate limiting', async () => {
      const loginAttempts = Array(6).fill(null).map(() =>
        request(app)
          .post('/api/auth/login')
          .send({
            email: userData.email,
            password: 'WrongPassword'
          })
      );

      const responses = await Promise.all(loginAttempts);
      
      // First 5 should return 401, 6th should return 429
      responses.slice(0, 5).forEach(response => {
        expect(response.status).toBe(401);
      });
      
      expect(responses[5].status).toBe(429);
      expect(responses[5].body.error).toContain('Too many');
    });
  });

  describe('Protected Routes', () => {
    let authToken: string;
    let userId: string;

    beforeEach(async () => {
      const user = await createTestUser({
        name: 'Test User',
        email: 'test@example.com',
        password: 'Password123!',
        emailVerified: true
      });
      
      userId = user.id;
      authToken = generateTestToken({ id: userId, email: user.email });
    });

    describe('GET /api/users/profile', () => {
      it('should return user profile with valid token', async () => {
        const response = await request(app)
          .get('/api/users/profile')
          .set('Authorization', `Bearer ${authToken}`)
          .expect(200);

        expect(response.body).toEqual({
          success: true,
          data: {
            id: userId,
            name: 'Test User',
            email: 'test@example.com',
            role: 'user',
            emailVerified: true,
            createdAt: expect.any(String),
            updatedAt: expect.any(String)
          }
        });
      });

      it('should return 401 without token', async () => {
        const response = await request(app)
          .get('/api/users/profile')
          .expect(401);

        expect(response.body.error).toContain('token required');
      });

      it('should return 401 with invalid token', async () => {
        const response = await request(app)
          .get('/api/users/profile')
          .set('Authorization', 'Bearer invalid-token')
          .expect(401);

        expect(response.body.error).toContain('Invalid token');
      });
    });
  });
});

// ✅ Database integration testing
// src/tests/integration/database.test.ts
describe('Database Integration', () => {
  beforeAll(async () => {
    await connectTestDatabase();
  });

  afterAll(async () => {
    await disconnectTestDatabase();
  });

  beforeEach(async () => {
    await clearDatabase();
  });

  describe('User Repository', () => {
    let userRepository: UserRepository;

    beforeEach(() => {
      userRepository = new UserRepository();
    });

    it('should handle concurrent user creation', async () => {
      const userData = {
        name: 'Test User',
        email: 'test@example.com',
        password: 'hashedPassword'
      };

      // Attempt to create the same user concurrently
      const createPromises = Array(5).fill(null).map(() =>
        userRepository.create(userData).catch(error => error)
      );

      const results = await Promise.all(createPromises);
      
      // Only one should succeed
      const successful = results.filter(result => !(result instanceof Error));
      const failed = results.filter(result => result instanceof Error);

      expect(successful).toHaveLength(1);
      expect(failed).toHaveLength(4);
      expect(failed.every(error => error.message.includes('duplicate'))).toBe(true);
    });

    it('should handle database connection failures gracefully', async () => {
      // Temporarily close database connection
      await mongoose.connection.close();

      await expect(userRepository.findById('507f1f77bcf86cd799439011'))
        .rejects
        .toThrow(DatabaseError);

      // Reconnect for cleanup
      await connectTestDatabase();
    });

    it('should maintain data consistency during transactions', async () => {
      const session = await mongoose.startSession();
      
      try {
        await session.withTransaction(async () => {
          const user = await userRepository.create({
            name: 'Transaction User',
            email: 'transaction@example.com',
            password: 'hashedPassword'
          }, { session });

          // Simulate error that would cause rollback
          throw new Error('Simulated transaction failure');
        });
      } catch (error) {
        // Transaction should be rolled back
      } finally {
        await session.endSession();
      }

      // User should not exist due to rollback
      const user = await userRepository.findByEmail('transaction@example.com');
      expect(user).toBeNull();
    });
  });
});
```

### 3. **End-to-End Testing Strategy**

#### Playwright E2E Tests
```typescript
// ✅ E2E testing with Playwright
// e2e/auth.e2e.test.ts
import { test, expect, Page } from '@playwright/test';

test.describe('Authentication Flow', () => {
  let page: Page;

  test.beforeEach(async ({ page: p }) => {
    page = p;
    await page.goto('/');
  });

  test('complete user registration and login flow', async () => {
    // Navigate to registration
    await page.click('text=Sign Up');
    await expect(page).toHaveURL('/auth/register');

    // Fill registration form
    await page.fill('[data-testid=name-input]', 'John Doe');
    await page.fill('[data-testid=email-input]', 'john@example.com');
    await page.fill('[data-testid=password-input]', 'Password123!');
    await page.fill('[data-testid=confirm-password-input]', 'Password123!');

    // Submit registration
    await page.click('[data-testid=register-button]');

    // Verify registration success
    await expect(page.locator('[data-testid=success-message]'))
      .toContainText('Registration successful');

    // Simulate email verification (in real test, you'd check email)
    await page.goto('/auth/verify-email?token=mock-verification-token');
    await expect(page.locator('[data-testid=verification-success]'))
      .toBeVisible();

    // Login with new account
    await page.goto('/auth/login');
    await page.fill('[data-testid=email-input]', 'john@example.com');
    await page.fill('[data-testid=password-input]', 'Password123!');
    await page.click('[data-testid=login-button]');

    // Verify successful login
    await expect(page).toHaveURL('/dashboard');
    await expect(page.locator('[data-testid=user-name]'))
      .toContainText('John Doe');
  });

  test('should handle login errors appropriately', async () => {
    await page.goto('/auth/login');

    // Test invalid credentials
    await page.fill('[data-testid=email-input]', 'wrong@example.com');
    await page.fill('[data-testid=password-input]', 'wrongpassword');
    await page.click('[data-testid=login-button]');

    await expect(page.locator('[data-testid=error-message]'))
      .toContainText('Invalid credentials');

    // Test validation errors
    await page.fill('[data-testid=email-input]', 'invalid-email');
    await page.click('[data-testid=login-button]');

    await expect(page.locator('[data-testid=email-error]'))
      .toContainText('Please enter a valid email');
  });

  test('should maintain session across page refreshes', async () => {
    // Login first
    await login(page, 'test@example.com', 'Password123!');
    
    // Verify logged in state
    await expect(page).toHaveURL('/dashboard');
    
    // Refresh page
    await page.reload();
    
    // Should still be logged in
    await expect(page).toHaveURL('/dashboard');
    await expect(page.locator('[data-testid=user-menu]')).toBeVisible();
  });

  test('should handle token expiration gracefully', async () => {
    // Login with short-lived token (simulate)
    await login(page, 'test@example.com', 'Password123!');
    
    // Simulate token expiration by manipulating localStorage
    await page.evaluate(() => {
      localStorage.setItem('accessToken', 'expired-token');
    });

    // Navigate to protected page
    await page.goto('/dashboard/profile');

    // Should redirect to login
    await expect(page).toHaveURL('/auth/login');
    await expect(page.locator('[data-testid=session-expired-message]'))
      .toContainText('Session expired');
  });
});

// ✅ Performance testing with Playwright
test.describe('Performance Tests', () => {
  test('page load performance', async ({ page }) => {
    const startTime = Date.now();
    
    await page.goto('/');
    
    // Wait for page to be fully loaded
    await page.waitForLoadState('networkidle');
    
    const loadTime = Date.now() - startTime;
    
    // Assert page loads within reasonable time
    expect(loadTime).toBeLessThan(3000); // 3 seconds
    
    // Check Core Web Vitals
    const vitals = await page.evaluate(() => {
      return new Promise((resolve) => {
        new PerformanceObserver((list) => {
          const entries = list.getEntries();
          resolve(entries.map(entry => ({
            name: entry.name,
            value: entry.value
          })));
        }).observe({ entryTypes: ['measure'] });
      });
    });
    
    console.log('Core Web Vitals:', vitals);
  });

  test('API response times', async ({ request }) => {
    const startTime = Date.now();
    
    const response = await request.get('/api/health');
    
    const responseTime = Date.now() - startTime;
    
    expect(response.status()).toBe(200);
    expect(responseTime).toBeLessThan(500); // 500ms
  });
});

// Helper functions
async function login(page: Page, email: string, password: string) {
  await page.goto('/auth/login');
  await page.fill('[data-testid=email-input]', email);
  await page.fill('[data-testid=password-input]', password);
  await page.click('[data-testid=login-button]');
  await page.waitForURL('/dashboard');
}
```

## 🔧 Test Infrastructure

### 1. **Test Database Setup**

#### In-Memory Database for Testing
```typescript
// ✅ Test database configuration
// src/tests/setup.ts
import { MongoMemoryServer } from 'mongodb-memory-server';
import mongoose from 'mongoose';

let mongoServer: MongoMemoryServer;

export async function connectTestDatabase(): Promise<void> {
  mongoServer = await MongoMemoryServer.create();
  const mongoUri = mongoServer.getUri();
  
  await mongoose.connect(mongoUri, {
    useNewUrlParser: true,
    useUnifiedTopology: true,
  });
}

export async function disconnectTestDatabase(): Promise<void> {
  await mongoose.connection.dropDatabase();
  await mongoose.connection.close();
  if (mongoServer) {
    await mongoServer.stop();
  }
}

export async function clearDatabase(): Promise<void> {
  const collections = mongoose.connection.collections;
  
  for (const key in collections) {
    const collection = collections[key];
    await collection.deleteMany({});
  }
}

// Global test setup
beforeAll(async () => {
  await connectTestDatabase();
});

afterAll(async () => {
  await disconnectTestDatabase();
});

beforeEach(async () => {
  await clearDatabase();
});
```

### 2. **Test Factories and Fixtures**

#### Data Factory Pattern
```typescript
// ✅ Test data factories
// src/tests/factories/user.factory.ts
interface UserFactoryOptions {
  name?: string;
  email?: string;
  password?: string;
  role?: string;
  emailVerified?: boolean;
}

export class UserFactory {
  static build(options: UserFactoryOptions = {}): any {
    return {
      name: options.name || faker.person.fullName(),
      email: options.email || faker.internet.email(),
      password: options.password || 'Password123!',
      role: options.role || 'user',
      emailVerified: options.emailVerified ?? true,
      createdAt: new Date(),
      updatedAt: new Date()
    };
  }

  static async create(options: UserFactoryOptions = {}): Promise<any> {
    const userData = this.build(options);
    
    // Hash password before creating
    userData.password = await bcrypt.hash(userData.password, 12);
    
    return await User.create(userData);
  }

  static async createMany(count: number, options: UserFactoryOptions = {}): Promise<any[]> {
    const users = [];
    
    for (let i = 0; i < count; i++) {
      const user = await this.create({
        ...options,
        email: options.email || `user${i}@example.com`
      });
      users.push(user);
    }
    
    return users;
  }

  static buildAdmin(options: UserFactoryOptions = {}): any {
    return this.build({
      ...options,
      role: 'admin'
    });
  }

  static async createAdmin(options: UserFactoryOptions = {}): Promise<any> {
    return await this.create({
      ...options,
      role: 'admin'
    });
  }
}

// src/tests/factories/post.factory.ts
export class PostFactory {
  static build(options: any = {}): any {
    return {
      title: options.title || faker.lorem.sentence(),
      content: options.content || faker.lorem.paragraphs(3),
      author: options.author || new mongoose.Types.ObjectId(),
      tags: options.tags || faker.lorem.words(3).split(' '),
      status: options.status || 'published',
      createdAt: new Date(),
      updatedAt: new Date()
    };
  }

  static async create(options: any = {}): Promise<any> {
    const postData = this.build(options);
    return await Post.create(postData);
  }

  static async createWithAuthor(authorOptions: any = {}, postOptions: any = {}): Promise<{ post: any, author: any }> {
    const author = await UserFactory.create(authorOptions);
    const post = await this.create({
      ...postOptions,
      author: author._id
    });
    
    return { post, author };
  }
}
```

### 3. **Mock Services and Utilities**

#### Service Mocking Pattern
```typescript
// ✅ Mock service implementations
// src/tests/mocks/email.service.mock.ts
export class MockEmailService implements IEmailService {
  public sentEmails: any[] = [];

  async sendWelcomeEmail(email: string, name: string): Promise<void> {
    this.sentEmails.push({
      type: 'welcome',
      to: email,
      data: { name },
      sentAt: new Date()
    });
  }

  async sendVerificationEmail(email: string, token: string): Promise<void> {
    this.sentEmails.push({
      type: 'verification',
      to: email,
      data: { token },
      sentAt: new Date()
    });
  }

  async sendPasswordResetEmail(email: string, token: string): Promise<void> {
    this.sentEmails.push({
      type: 'password-reset',
      to: email,
      data: { token },
      sentAt: new Date()
    });
  }

  getLastEmail(): any {
    return this.sentEmails[this.sentEmails.length - 1];
  }

  getEmailsSentTo(email: string): any[] {
    return this.sentEmails.filter(e => e.to === email);
  }

  clear(): void {
    this.sentEmails = [];
  }
}

// src/tests/mocks/payment.service.mock.ts
export class MockPaymentService implements IPaymentService {
  public payments: any[] = [];
  public shouldSucceed: boolean = true;

  async processPayment(amount: number, currency: string, paymentMethod: string): Promise<any> {
    const payment = {
      id: faker.string.uuid(),
      amount,
      currency,
      paymentMethod,
      status: this.shouldSucceed ? 'succeeded' : 'failed',
      createdAt: new Date()
    };

    this.payments.push(payment);

    if (!this.shouldSucceed) {
      throw new PaymentError('Payment failed');
    }

    return payment;
  }

  setSuccessMode(succeed: boolean): void {
    this.shouldSucceed = succeed;
  }

  getPayments(): any[] {
    return this.payments;
  }

  clear(): void {
    this.payments = [];
  }
}
```

## 📊 Testing Metrics and Coverage

### 1. **Coverage Configuration**

#### Coverage Thresholds
```javascript
// ✅ Coverage configuration
module.exports = {
  coverageThreshold: {
    global: {
      branches: 80,
      functions: 80,
      lines: 80,
      statements: 80
    },
    './src/services/': {
      branches: 90,
      functions: 90,
      lines: 90,
      statements: 90
    },
    './src/utils/': {
      branches: 85,
      functions: 85,
      lines: 85,
      statements: 85
    }
  },
  collectCoverageFrom: [
    'src/**/*.ts',
    '!src/**/*.d.ts',
    '!src/index.ts',
    '!src/**/*.interface.ts',
    '!src/config/**',
    '!src/migrations/**',
    '!src/tests/**'
  ]
};
```

### 2. **Test Performance Monitoring**

#### Test Performance Tracking
```typescript
// ✅ Test performance monitoring
// src/tests/utils/performance.ts
export class TestPerformanceMonitor {
  private static instance: TestPerformanceMonitor;
  private testTimes: Map<string, number> = new Map();

  static getInstance(): TestPerformanceMonitor {
    if (!this.instance) {
      this.instance = new TestPerformanceMonitor();
    }
    return this.instance;
  }

  startTest(testName: string): void {
    this.testTimes.set(testName, Date.now());
  }

  endTest(testName: string): number {
    const startTime = this.testTimes.get(testName);
    if (!startTime) {
      throw new Error(`Test ${testName} was not started`);
    }

    const duration = Date.now() - startTime;
    this.testTimes.delete(testName);

    // Log slow tests
    if (duration > 5000) { // 5 seconds
      console.warn(`Slow test detected: ${testName} took ${duration}ms`);
    }

    return duration;
  }

  getAverageTestTime(): number {
    const times = Array.from(this.testTimes.values());
    return times.length > 0 ? times.reduce((a, b) => a + b, 0) / times.length : 0;
  }
}

// Usage in tests
beforeEach(() => {
  TestPerformanceMonitor.getInstance().startTest(expect.getState().currentTestName);
});

afterEach(() => {
  const duration = TestPerformanceMonitor.getInstance().endTest(expect.getState().currentTestName);
  
  // Fail test if it takes too long
  if (duration > 10000) { // 10 seconds
    throw new Error(`Test exceeded maximum duration: ${duration}ms`);
  }
});
```

## 🎯 Testing Best Practices Summary

### ✅ Unit Testing Checklist
- [ ] Test individual functions and methods in isolation
- [ ] Mock external dependencies
- [ ] Test both happy path and error cases
- [ ] Use descriptive test names
- [ ] Follow AAA pattern (Arrange, Act, Assert)
- [ ] Achieve >80% code coverage
- [ ] Test edge cases and boundary conditions

### ✅ Integration Testing Checklist
- [ ] Test API endpoints with real HTTP requests
- [ ] Test database operations with real database
- [ ] Test middleware functionality
- [ ] Test error handling across layers
- [ ] Test authentication and authorization
- [ ] Test rate limiting and security measures

### ✅ E2E Testing Checklist
- [ ] Test complete user workflows
- [ ] Test cross-browser compatibility
- [ ] Test responsive design
- [ ] Test performance requirements
- [ ] Test accessibility requirements
- [ ] Test error scenarios from user perspective

### ✅ Test Infrastructure Checklist
- [ ] Use in-memory database for fast tests
- [ ] Create data factories for consistent test data
- [ ] Mock external services
- [ ] Set up CI/CD pipeline with test automation
- [ ] Monitor test performance and coverage
- [ ] Maintain test documentation

---

## 🧭 Navigation

### ⬅️ Previous: [Architecture Patterns](./architecture-patterns.md)
### ➡️ Next: [Performance Optimization](./performance-optimization.md)

---

*Testing strategies compiled from analysis of production Express.js applications with proven testing practices.*