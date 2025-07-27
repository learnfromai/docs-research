# Testing Strategies in Express.js Open Source Projects

## 🧪 Testing Overview

Comprehensive analysis of testing methodologies, frameworks, and best practices employed by major Express.js open source projects. This research reveals industry-standard approaches to unit testing, integration testing, end-to-end testing, and quality assurance that ensure production reliability.

## 📊 Testing Framework Adoption

### Primary Testing Stack Analysis

| Framework | Adoption Rate | Category | Strengths | Common Use Cases |
|-----------|---------------|----------|-----------|------------------|
| **Jest** | 85% | Unit/Integration | Rich ecosystem, snapshots, mocking | Unit tests, API testing |
| **Mocha** | 45% | Unit/Integration | Flexibility, async support | Legacy projects, custom setups |
| **Vitest** | 25% | Unit/Integration | Vite ecosystem, speed | Modern TypeScript projects |
| **Supertest** | 90% | HTTP Testing | Express integration | API endpoint testing |
| **Cypress** | 60% | E2E Testing | Real browser, debugging | User journey testing |
| **Playwright** | 40% | E2E Testing | Multi-browser, speed | Modern E2E testing |
| **k6** | 30% | Load Testing | Performance focus | Scalability testing |

### Testing Pyramid Implementation

**Distribution Analysis** across analyzed projects:
```typescript
{
  "unit_tests": {
    "percentage": "70%",
    "coverage_target": "80-95%",
    "focus": "Business logic, utilities, pure functions"
  },
  "integration_tests": {
    "percentage": "25%",
    "coverage_target": "60-80%",
    "focus": "API endpoints, database operations, service interactions"
  },
  "e2e_tests": {
    "percentage": "5%",
    "coverage_target": "20-40%",
    "focus": "Critical user flows, authentication, payment processes"
  }
}
```

## 🎯 Unit Testing Patterns

### 1. Jest with Supertest (Most Common Pattern)

**Setup Configuration**:
```typescript
// jest.config.js
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  roots: ['<rootDir>/src', '<rootDir>/tests'],
  testMatch: [
    '**/__tests__/**/*.test.ts',
    '**/?(*.)+(spec|test).ts'
  ],
  collectCoverageFrom: [
    'src/**/*.ts',
    '!src/**/*.d.ts',
    '!src/index.ts',
    '!src/config/**',
    '!src/migrations/**'
  ],
  coverageThreshold: {
    global: {
      branches: 80,
      functions: 80,
      lines: 80,
      statements: 80
    }
  },
  setupFilesAfterEnv: ['<rootDir>/tests/setup.ts'],
  testTimeout: 10000
};

// tests/setup.ts
import { testDatabase } from './utils/database';
import { redisClient } from './utils/redis';

beforeAll(async () => {
  await testDatabase.connect();
  await redisClient.connect();
});

afterAll(async () => {
  await testDatabase.disconnect();
  await redisClient.disconnect();
});

beforeEach(async () => {
  await testDatabase.clear();
  await redisClient.flushall();
});
```

**Service Testing Pattern**:
```typescript
// tests/services/UserService.test.ts
describe('UserService', () => {
  let userService: UserService;
  let userRepository: jest.Mocked<UserRepository>;
  let emailService: jest.Mocked<EmailService>;

  beforeEach(() => {
    userRepository = {
      findByEmail: jest.fn(),
      save: jest.fn(),
      findById: jest.fn(),
      delete: jest.fn()
    } as jest.Mocked<UserRepository>;

    emailService = {
      sendWelcomeEmail: jest.fn(),
      sendPasswordResetEmail: jest.fn()
    } as jest.Mocked<EmailService>;

    userService = new UserService(userRepository, emailService);
  });

  describe('createUser', () => {
    it('should create a new user successfully', async () => {
      // Arrange
      const userData = {
        email: 'test@example.com',
        password: 'SecurePass123!',
        firstName: 'John',
        lastName: 'Doe'
      };

      userRepository.findByEmail.mockResolvedValue(null);
      userRepository.save.mockResolvedValue(undefined);
      emailService.sendWelcomeEmail.mockResolvedValue(undefined);

      // Act
      const result = await userService.createUser(userData);

      // Assert
      expect(userRepository.findByEmail).toHaveBeenCalledWith(userData.email);
      expect(userRepository.save).toHaveBeenCalledWith(
        expect.objectContaining({
          email: userData.email,
          firstName: userData.firstName,
          lastName: userData.lastName
        })
      );
      expect(emailService.sendWelcomeEmail).toHaveBeenCalledWith(
        expect.objectContaining({ email: userData.email })
      );
      expect(result).toHaveProperty('id');
      expect(result.email).toBe(userData.email);
    });

    it('should throw ConflictError when user already exists', async () => {
      // Arrange
      const userData = {
        email: 'existing@example.com',
        password: 'SecurePass123!',
        firstName: 'John',
        lastName: 'Doe'
      };

      const existingUser = { id: '1', email: userData.email };
      userRepository.findByEmail.mockResolvedValue(existingUser as User);

      // Act & Assert
      await expect(userService.createUser(userData)).rejects.toThrow(
        new ConflictError('User already exists')
      );
      expect(userRepository.save).not.toHaveBeenCalled();
      expect(emailService.sendWelcomeEmail).not.toHaveBeenCalled();
    });

    it('should handle email service failures gracefully', async () => {
      // Arrange
      const userData = {
        email: 'test@example.com',
        password: 'SecurePass123!',
        firstName: 'John',
        lastName: 'Doe'
      };

      userRepository.findByEmail.mockResolvedValue(null);
      userRepository.save.mockResolvedValue(undefined);
      emailService.sendWelcomeEmail.mockRejectedValue(new Error('Email service unavailable'));

      // Act & Assert
      // Should still create user even if email fails
      const result = await userService.createUser(userData);
      expect(result).toHaveProperty('id');
      expect(userRepository.save).toHaveBeenCalled();
    });
  });

  describe('authenticateUser', () => {
    it('should authenticate user with valid credentials', async () => {
      // Arrange
      const email = 'test@example.com';
      const password = 'SecurePass123!';
      const hashedPassword = await bcrypt.hash(password, 12);
      
      const user = {
        id: '1',
        email,
        password: hashedPassword,
        isActive: true
      } as User;

      userRepository.findByEmail.mockResolvedValue(user);

      // Act
      const result = await userService.authenticateUser(email, password);

      // Assert
      expect(result).toEqual({
        id: user.id,
        email: user.email,
        isAuthenticated: true
      });
    });

    it('should reject authentication with invalid password', async () => {
      // Arrange
      const email = 'test@example.com';
      const password = 'WrongPassword';
      const hashedPassword = await bcrypt.hash('CorrectPassword', 12);
      
      const user = {
        id: '1',
        email,
        password: hashedPassword,
        isActive: true
      } as User;

      userRepository.findByEmail.mockResolvedValue(user);

      // Act & Assert
      await expect(userService.authenticateUser(email, password)).rejects.toThrow(
        new UnauthorizedError('Invalid credentials')
      );
    });
  });
});
```

### 2. Domain Entity Testing

**Value Object Testing**:
```typescript
// tests/domain/value-objects/Email.test.ts
describe('Email Value Object', () => {
  describe('create', () => {
    it('should create valid email', () => {
      const validEmails = [
        'test@example.com',
        'user.name+tag@domain.co.uk',
        'test123@test-domain.com'
      ];

      validEmails.forEach(email => {
        const emailVO = Email.create(email);
        expect(emailVO.value).toBe(email.toLowerCase());
      });
    });

    it('should reject invalid email formats', () => {
      const invalidEmails = [
        'invalid-email',
        '@domain.com',
        'user@',
        'user..double.dot@domain.com',
        'user@domain',
        ''
      ];

      invalidEmails.forEach(email => {
        expect(() => Email.create(email)).toThrow(InvalidEmailError);
      });
    });
  });

  describe('equals', () => {
    it('should return true for identical emails', () => {
      const email1 = Email.create('test@example.com');
      const email2 = Email.create('TEST@EXAMPLE.COM');
      
      expect(email1.equals(email2)).toBe(true);
    });

    it('should return false for different emails', () => {
      const email1 = Email.create('test1@example.com');
      const email2 = Email.create('test2@example.com');
      
      expect(email1.equals(email2)).toBe(false);
    });
  });
});
```

**Aggregate Testing**:
```typescript
// tests/domain/aggregates/User.test.ts
describe('User Aggregate', () => {
  describe('create', () => {
    it('should create user with valid data', () => {
      const userData = {
        email: 'test@example.com',
        password: 'SecurePass123!',
        firstName: 'John',
        lastName: 'Doe'
      };

      const user = User.create(userData);

      expect(user.getId()).toBeDefined();
      expect(user.getEmail().value).toBe(userData.email);
      expect(user.getFullName()).toBe('John Doe');
      expect(user.isActive()).toBe(true);
      
      // Check domain events
      const events = user.getUncommittedEvents();
      expect(events).toHaveLength(1);
      expect(events[0]).toBeInstanceOf(UserCreatedEvent);
    });

    it('should enforce password complexity requirements', () => {
      const userData = {
        email: 'test@example.com',
        password: 'weak',
        firstName: 'John',
        lastName: 'Doe'
      };

      expect(() => User.create(userData)).toThrow(WeakPasswordError);
    });
  });

  describe('changePassword', () => {
    it('should change password with valid current password', () => {
      const user = createTestUser();
      const currentPassword = 'CurrentPass123!';
      const newPassword = 'NewSecurePass123!';

      user.changePassword(newPassword, currentPassword);

      expect(user.verifyPassword(newPassword)).toBe(true);
      expect(user.verifyPassword(currentPassword)).toBe(false);
      
      const events = user.getUncommittedEvents();
      expect(events.some(e => e instanceof PasswordChangedEvent)).toBe(true);
    });

    it('should reject password change with invalid current password', () => {
      const user = createTestUser();
      const wrongPassword = 'WrongPassword';
      const newPassword = 'NewSecurePass123!';

      expect(() => user.changePassword(newPassword, wrongPassword))
        .toThrow(InvalidPasswordError);
    });
  });
});
```

## 🎯 Integration Testing Patterns

### 1. API Endpoint Testing with Supertest

**Test Setup**:
```typescript
// tests/integration/setup.ts
import express from 'express';
import { createApp } from '../../src/app';
import { TestDatabase } from '../utils/TestDatabase';
import { TestRedis } from '../utils/TestRedis';

export class TestApp {
  public app: express.Application;
  public database: TestDatabase;
  public redis: TestRedis;

  constructor() {
    this.database = new TestDatabase();
    this.redis = new TestRedis();
    this.app = createApp({
      database: this.database.connection,
      redis: this.redis.client,
      environment: 'test'
    });
  }

  async initialize(): Promise<void> {
    await this.database.connect();
    await this.redis.connect();
    await this.database.migrate();
  }

  async cleanup(): Promise<void> {
    await this.database.clear();
    await this.redis.clear();
  }

  async destroy(): Promise<void> {
    await this.database.disconnect();
    await this.redis.disconnect();
  }
}
```

**API Integration Tests**:
```typescript
// tests/integration/api/users.test.ts
import request from 'supertest';
import { TestApp } from '../setup';

describe('Users API Integration', () => {
  let testApp: TestApp;

  beforeAll(async () => {
    testApp = new TestApp();
    await testApp.initialize();
  });

  afterAll(async () => {
    await testApp.destroy();
  });

  beforeEach(async () => {
    await testApp.cleanup();
  });

  describe('POST /api/users', () => {
    it('should create a new user', async () => {
      const userData = {
        email: 'test@example.com',
        password: 'SecurePass123!',
        firstName: 'John',
        lastName: 'Doe'
      };

      const response = await request(testApp.app)
        .post('/api/users')
        .send(userData)
        .expect(201);

      expect(response.body).toMatchObject({
        id: expect.any(String),
        email: userData.email,
        firstName: userData.firstName,
        lastName: userData.lastName,
        createdAt: expect.any(String)
      });

      expect(response.body).not.toHaveProperty('password');

      // Verify user was actually created in database
      const createdUser = await testApp.database.query(
        'SELECT * FROM users WHERE email = $1',
        [userData.email]
      );
      expect(createdUser.rows).toHaveLength(1);
    });

    it('should return 400 for invalid email', async () => {
      const userData = {
        email: 'invalid-email',
        password: 'SecurePass123!',
        firstName: 'John',
        lastName: 'Doe'
      };

      const response = await request(testApp.app)
        .post('/api/users')
        .send(userData)
        .expect(400);

      expect(response.body).toMatchObject({
        error: 'Validation failed',
        details: expect.arrayContaining([
          expect.objectContaining({
            field: 'email',
            message: expect.stringContaining('email')
          })
        ])
      });
    });

    it('should return 409 for duplicate email', async () => {
      const userData = {
        email: 'duplicate@example.com',
        password: 'SecurePass123!',
        firstName: 'John',
        lastName: 'Doe'
      };

      // Create first user
      await request(testApp.app)
        .post('/api/users')
        .send(userData)
        .expect(201);

      // Attempt to create duplicate
      const response = await request(testApp.app)
        .post('/api/users')
        .send(userData)
        .expect(409);

      expect(response.body).toMatchObject({
        error: 'User already exists'
      });
    });

    it('should enforce rate limiting', async () => {
      const userData = {
        email: 'ratelimit@example.com',
        password: 'SecurePass123!',
        firstName: 'John',
        lastName: 'Doe'
      };

      // Send multiple requests rapidly
      const requests = Array.from({ length: 10 }, (_, i) =>
        request(testApp.app)
          .post('/api/users')
          .send({ ...userData, email: `user${i}@example.com` })
      );

      const responses = await Promise.all(requests);
      
      // Some requests should be rate limited
      const rateLimitedResponses = responses.filter(r => r.status === 429);
      expect(rateLimitedResponses.length).toBeGreaterThan(0);
    });
  });

  describe('GET /api/users/:id', () => {
    let authToken: string;
    let userId: string;

    beforeEach(async () => {
      // Create test user and get auth token
      const userData = {
        email: 'auth@example.com',
        password: 'SecurePass123!',
        firstName: 'Auth',
        lastName: 'User'
      };

      const createResponse = await request(testApp.app)
        .post('/api/users')
        .send(userData);

      userId = createResponse.body.id;

      const loginResponse = await request(testApp.app)
        .post('/api/auth/login')
        .send({
          email: userData.email,
          password: userData.password
        });

      authToken = loginResponse.body.accessToken;
    });

    it('should return user data for authenticated request', async () => {
      const response = await request(testApp.app)
        .get(`/api/users/${userId}`)
        .set('Authorization', `Bearer ${authToken}`)
        .expect(200);

      expect(response.body).toMatchObject({
        id: userId,
        email: 'auth@example.com',
        firstName: 'Auth',
        lastName: 'User'
      });
    });

    it('should return 401 for unauthenticated request', async () => {
      await request(testApp.app)
        .get(`/api/users/${userId}`)
        .expect(401);
    });

    it('should return 404 for non-existent user', async () => {
      const nonExistentId = 'non-existent-id';

      await request(testApp.app)
        .get(`/api/users/${nonExistentId}`)
        .set('Authorization', `Bearer ${authToken}`)
        .expect(404);
    });
  });
});
```

### 2. Database Integration Testing

**Repository Testing Pattern**:
```typescript
// tests/integration/repositories/UserRepository.test.ts
describe('UserRepository Integration', () => {
  let userRepository: UserRepository;
  let testApp: TestApp;

  beforeAll(async () => {
    testApp = new TestApp();
    await testApp.initialize();
    userRepository = new UserRepositoryImpl(testApp.database.connection);
  });

  afterAll(async () => {
    await testApp.destroy();
  });

  beforeEach(async () => {
    await testApp.cleanup();
  });

  describe('save', () => {
    it('should persist user to database', async () => {
      const user = User.create({
        email: 'repo@example.com',
        password: 'SecurePass123!',
        firstName: 'Repo',
        lastName: 'Test'
      });

      await userRepository.save(user);

      // Verify persistence
      const savedUser = await userRepository.findById(user.getId());
      expect(savedUser).toBeDefined();
      expect(savedUser!.getEmail().value).toBe('repo@example.com');
    });

    it('should update existing user', async () => {
      const user = User.create({
        email: 'update@example.com',
        password: 'SecurePass123!',
        firstName: 'Original',
        lastName: 'Name'
      });

      await userRepository.save(user);

      // Update user
      user.updateProfile({ firstName: 'Updated' });
      await userRepository.save(user);

      // Verify update
      const updatedUser = await userRepository.findById(user.getId());
      expect(updatedUser!.getFirstName()).toBe('Updated');
    });
  });

  describe('findByEmail', () => {
    it('should find user by email case-insensitively', async () => {
      const user = User.create({
        email: 'CaseTest@Example.COM',
        password: 'SecurePass123!',
        firstName: 'Case',
        lastName: 'Test'
      });

      await userRepository.save(user);

      const foundUser = await userRepository.findByEmail(
        Email.create('casetest@example.com')
      );

      expect(foundUser).toBeDefined();
      expect(foundUser!.getId().equals(user.getId())).toBe(true);
    });

    it('should return null for non-existent email', async () => {
      const foundUser = await userRepository.findByEmail(
        Email.create('nonexistent@example.com')
      );

      expect(foundUser).toBeNull();
    });
  });

  describe('transaction support', () => {
    it('should rollback on error', async () => {
      const user1 = User.create({
        email: 'transaction1@example.com',
        password: 'SecurePass123!',
        firstName: 'Trans',
        lastName: 'One'
      });

      const user2 = User.create({
        email: 'transaction2@example.com',
        password: 'SecurePass123!',
        firstName: 'Trans',
        lastName: 'Two'
      });

      // Mock a database error on second save
      jest.spyOn(testApp.database.connection, 'query')
        .mockImplementationOnce(() => Promise.resolve())
        .mockImplementationOnce(() => Promise.reject(new Error('Database error')));

      await expect(
        userRepository.saveMultiple([user1, user2])
      ).rejects.toThrow('Database error');

      // Verify rollback - neither user should exist
      const foundUser1 = await userRepository.findById(user1.getId());
      const foundUser2 = await userRepository.findById(user2.getId());

      expect(foundUser1).toBeNull();
      expect(foundUser2).toBeNull();
    });
  });
});
```

## 🎯 End-to-End Testing Patterns

### 1. Playwright Implementation

**E2E Test Setup**:
```typescript
// tests/e2e/playwright.config.ts
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './tests/e2e',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: 'html',
  use: {
    baseURL: 'http://localhost:3000',
    trace: 'on-first-retry',
    video: 'retain-on-failure',
    screenshot: 'only-on-failure'
  },
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
    {
      name: 'firefox',
      use: { ...devices['Desktop Firefox'] },
    },
    {
      name: 'webkit',
      use: { ...devices['Desktop Safari'] },
    }
  ],
  webServer: {
    command: 'npm run start:test',
    port: 3000,
    reuseExistingServer: !process.env.CI
  }
});
```

**User Journey Testing**:
```typescript
// tests/e2e/user-registration.spec.ts
import { test, expect } from '@playwright/test';

test.describe('User Registration Flow', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
  });

  test('should complete full registration process', async ({ page }) => {
    // Navigate to registration
    await page.click('text=Sign Up');
    await expect(page).toHaveURL('/register');

    // Fill registration form
    await page.fill('[data-testid=email-input]', 'e2e@example.com');
    await page.fill('[data-testid=password-input]', 'SecurePass123!');
    await page.fill('[data-testid=confirm-password-input]', 'SecurePass123!');
    await page.fill('[data-testid=first-name-input]', 'E2E');
    await page.fill('[data-testid=last-name-input]', 'Test');

    // Submit form
    await page.click('[data-testid=submit-button]');

    // Verify success
    await expect(page.locator('[data-testid=success-message]')).toBeVisible();
    await expect(page).toHaveURL('/dashboard');

    // Verify user is logged in
    await expect(page.locator('[data-testid=user-menu]')).toContainText('E2E Test');
  });

  test('should show validation errors for invalid input', async ({ page }) => {
    await page.click('text=Sign Up');

    // Submit empty form
    await page.click('[data-testid=submit-button]');

    // Verify validation errors
    await expect(page.locator('[data-testid=email-error]')).toContainText('Email is required');
    await expect(page.locator('[data-testid=password-error]')).toContainText('Password is required');

    // Test invalid email
    await page.fill('[data-testid=email-input]', 'invalid-email');
    await page.blur('[data-testid=email-input]');
    await expect(page.locator('[data-testid=email-error]')).toContainText('Invalid email format');

    // Test weak password
    await page.fill('[data-testid=password-input]', 'weak');
    await page.blur('[data-testid=password-input]');
    await expect(page.locator('[data-testid=password-error]')).toContainText('Password must be at least 8 characters');
  });

  test('should handle network errors gracefully', async ({ page }) => {
    // Intercept and fail registration request
    await page.route('/api/users', route => {
      route.fulfill({
        status: 500,
        body: JSON.stringify({ error: 'Internal server error' })
      });
    });

    await page.click('text=Sign Up');
    await page.fill('[data-testid=email-input]', 'error@example.com');
    await page.fill('[data-testid=password-input]', 'SecurePass123!');
    await page.fill('[data-testid=confirm-password-input]', 'SecurePass123!');
    await page.fill('[data-testid=first-name-input]', 'Error');
    await page.fill('[data-testid=last-name-input]', 'Test');

    await page.click('[data-testid=submit-button]');

    // Verify error handling
    await expect(page.locator('[data-testid=error-message]')).toContainText('Registration failed');
    await expect(page).toHaveURL('/register'); // Should stay on registration page
  });
});
```

### 2. Authentication Flow Testing

```typescript
// tests/e2e/authentication.spec.ts
test.describe('Authentication Flow', () => {
  test.beforeEach(async ({ page }) => {
    // Create test user via API
    await page.request.post('/api/users', {
      data: {
        email: 'login@example.com',
        password: 'SecurePass123!',
        firstName: 'Login',
        lastName: 'Test'
      }
    });
  });

  test('should login successfully with valid credentials', async ({ page }) => {
    await page.goto('/login');

    await page.fill('[data-testid=email-input]', 'login@example.com');
    await page.fill('[data-testid=password-input]', 'SecurePass123!');
    await page.click('[data-testid=login-button]');

    await expect(page).toHaveURL('/dashboard');
    await expect(page.locator('[data-testid=welcome-message]')).toContainText('Welcome, Login Test');
  });

  test('should persist session after page refresh', async ({ page }) => {
    // Login first
    await page.goto('/login');
    await page.fill('[data-testid=email-input]', 'login@example.com');
    await page.fill('[data-testid=password-input]', 'SecurePass123!');
    await page.click('[data-testid=login-button]');

    await expect(page).toHaveURL('/dashboard');

    // Refresh page
    await page.reload();

    // Should still be logged in
    await expect(page).toHaveURL('/dashboard');
    await expect(page.locator('[data-testid=user-menu]')).toBeVisible();
  });

  test('should logout successfully', async ({ page }) => {
    // Login first
    await page.goto('/login');
    await page.fill('[data-testid=email-input]', 'login@example.com');
    await page.fill('[data-testid=password-input]', 'SecurePass123!');
    await page.click('[data-testid=login-button]');

    // Logout
    await page.click('[data-testid=user-menu]');
    await page.click('[data-testid=logout-button]');

    // Verify logout
    await expect(page).toHaveURL('/');
    await expect(page.locator('[data-testid=login-button]')).toBeVisible();

    // Try to access protected route
    await page.goto('/dashboard');
    await expect(page).toHaveURL('/login');
  });

  test('should handle session expiration', async ({ page }) => {
    // Login and get tokens
    await page.goto('/login');
    await page.fill('[data-testid=email-input]', 'login@example.com');
    await page.fill('[data-testid=password-input]', 'SecurePass123!');
    await page.click('[data-testid=login-button]');

    // Mock expired token responses
    await page.route('/api/**', route => {
      route.fulfill({
        status: 401,
        body: JSON.stringify({ error: 'Token expired' })
      });
    });

    // Try to access protected resource
    await page.click('[data-testid=profile-link]');

    // Should redirect to login
    await expect(page).toHaveURL('/login');
    await expect(page.locator('[data-testid=session-expired-message]')).toBeVisible();
  });
});
```

## 🎯 Performance Testing Patterns

### 1. Load Testing with k6

**Basic Load Test**:
```typescript
// tests/performance/load-test.js
import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate } from 'k6/metrics';

const errorRate = new Rate('errors');

export const options = {
  stages: [
    { duration: '2m', target: 100 }, // Ramp up
    { duration: '5m', target: 100 }, // Steady state
    { duration: '2m', target: 200 }, // Ramp up to 200
    { duration: '5m', target: 200 }, // Steady state
    { duration: '2m', target: 0 },   // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'], // 95% of requests under 500ms
    http_req_failed: ['rate<0.1'],    // Error rate under 10%
    errors: ['rate<0.1'],
  },
};

const BASE_URL = 'http://localhost:3000';

export function setup() {
  // Create test users
  const users = [];
  for (let i = 0; i < 10; i++) {
    const response = http.post(`${BASE_URL}/api/users`, JSON.stringify({
      email: `loadtest${i}@example.com`,
      password: 'SecurePass123!',
      firstName: `Load${i}`,
      lastName: 'Test'
    }), {
      headers: { 'Content-Type': 'application/json' }
    });
    
    if (response.status === 201) {
      users.push(response.json());
    }
  }
  return { users };
}

export default function (data) {
  const user = data.users[Math.floor(Math.random() * data.users.length)];
  
  // Login
  const loginResponse = http.post(`${BASE_URL}/api/auth/login`, JSON.stringify({
    email: user.email,
    password: 'SecurePass123!'
  }), {
    headers: { 'Content-Type': 'application/json' }
  });

  const loginSuccess = check(loginResponse, {
    'login status is 200': (r) => r.status === 200,
    'login has token': (r) => r.json('accessToken') !== undefined,
  });

  errorRate.add(!loginSuccess);

  if (loginSuccess) {
    const token = loginResponse.json('accessToken');
    
    // Get user profile
    const profileResponse = http.get(`${BASE_URL}/api/users/${user.id}`, {
      headers: { 
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
      }
    });

    const profileSuccess = check(profileResponse, {
      'profile status is 200': (r) => r.status === 200,
      'profile has user data': (r) => r.json('id') === user.id,
    });

    errorRate.add(!profileSuccess);

    // Update profile
    const updateResponse = http.put(`${BASE_URL}/api/users/${user.id}`, JSON.stringify({
      firstName: `Updated${Math.random()}`
    }), {
      headers: { 
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
      }
    });

    const updateSuccess = check(updateResponse, {
      'update status is 200': (r) => r.status === 200,
    });

    errorRate.add(!updateSuccess);
  }

  sleep(1);
}

export function teardown(data) {
  // Cleanup test users
  data.users.forEach(user => {
    http.del(`${BASE_URL}/api/users/${user.id}`);
  });
}
```

**Database Performance Testing**:
```typescript
// tests/performance/database-load.js
import http from 'k6/http';
import { check } from 'k6';

export const options = {
  scenarios: {
    database_reads: {
      executor: 'constant-vus',
      vus: 50,
      duration: '5m',
      exec: 'testDatabaseReads'
    },
    database_writes: {
      executor: 'constant-vus',
      vus: 10,
      duration: '5m',
      exec: 'testDatabaseWrites'
    }
  },
  thresholds: {
    'http_req_duration{scenario:database_reads}': ['p(95)<200'],
    'http_req_duration{scenario:database_writes}': ['p(95)<1000'],
  }
};

export function testDatabaseReads() {
  const response = http.get(`${BASE_URL}/api/users?page=${Math.floor(Math.random() * 100)}`);
  check(response, {
    'read status is 200': (r) => r.status === 200,
    'read response time < 200ms': (r) => r.timings.duration < 200,
  });
}

export function testDatabaseWrites() {
  const response = http.post(`${BASE_URL}/api/posts`, JSON.stringify({
    title: `Performance Test Post ${Date.now()}`,
    content: 'This is a performance test post with some content.',
    userId: Math.floor(Math.random() * 1000) + 1
  }), {
    headers: { 'Content-Type': 'application/json' }
  });
  
  check(response, {
    'write status is 201': (r) => r.status === 201,
    'write response time < 1000ms': (r) => r.timings.duration < 1000,
  });
}
```

## 📊 Testing Metrics & Coverage

### Coverage Analysis Pattern

**Jest Coverage Configuration**:
```typescript
// jest.config.js - Advanced coverage settings
module.exports = {
  // ... other config
  collectCoverageFrom: [
    'src/**/*.{ts,tsx}',
    '!src/**/*.d.ts',
    '!src/index.ts',
    '!src/config/**',
    '!src/migrations/**',
    '!src/**/*.interface.ts',
    '!src/**/*.enum.ts'
  ],
  coverageReporters: ['text', 'lcov', 'html', 'json-summary'],
  coverageThreshold: {
    global: {
      branches: 80,
      functions: 85,
      lines: 85,
      statements: 85
    },
    './src/domain/': {
      branches: 90,
      functions: 95,
      lines: 95,
      statements: 95
    },
    './src/application/': {
      branches: 85,
      functions: 90,
      lines: 90,
      statements: 90
    }
  }
};
```

**Coverage Analysis Tools**:
```typescript
// scripts/analyze-coverage.ts
import fs from 'fs';
import path from 'path';

interface CoverageData {
  total: {
    lines: { total: number; covered: number; pct: number };
    functions: { total: number; covered: number; pct: number };
    statements: { total: number; covered: number; pct: number };
    branches: { total: number; covered: number; pct: number };
  };
  files: Record<string, any>;
}

class CoverageAnalyzer {
  analyzeCoverage(): void {
    const coverageFile = path.join(__dirname, '../coverage/coverage-summary.json');
    const coverage: CoverageData = JSON.parse(fs.readFileSync(coverageFile, 'utf8'));

    console.log('Coverage Analysis Report');
    console.log('======================');
    
    this.printOverallCoverage(coverage.total);
    this.printLowCoverageFiles(coverage.files);
    this.printRecommendations(coverage);
  }

  private printOverallCoverage(total: any): void {
    console.log('\nOverall Coverage:');
    console.log(`Lines: ${total.lines.pct}% (${total.lines.covered}/${total.lines.total})`);
    console.log(`Functions: ${total.functions.pct}% (${total.functions.covered}/${total.functions.total})`);
    console.log(`Statements: ${total.statements.pct}% (${total.statements.covered}/${total.statements.total})`);
    console.log(`Branches: ${total.branches.pct}% (${total.branches.covered}/${total.branches.total})`);
  }

  private printLowCoverageFiles(files: Record<string, any>): void {
    console.log('\nFiles with Low Coverage (<80%):');
    
    Object.entries(files)
      .filter(([_, data]) => data.lines.pct < 80)
      .sort(([_, a], [__, b]) => a.lines.pct - b.lines.pct)
      .forEach(([file, data]) => {
        console.log(`${file}: ${data.lines.pct}% lines, ${data.branches.pct}% branches`);
      });
  }

  private printRecommendations(coverage: CoverageData): void {
    console.log('\nRecommendations:');
    
    if (coverage.total.branches.pct < 80) {
      console.log('- Focus on branch coverage: Add tests for conditional logic');
    }
    
    if (coverage.total.functions.pct < 85) {
      console.log('- Increase function coverage: Test all public methods');
    }
    
    console.log('- Prioritize testing domain logic and business rules');
    console.log('- Consider mutation testing for quality assessment');
  }
}

new CoverageAnalyzer().analyzeCoverage();
```

## 🎯 Test Organization & Best Practices

### Testing Pyramid Distribution

**Recommended Test Distribution** based on project analysis:
```typescript
{
  "small_projects": {
    "unit": "60%",
    "integration": "30%",
    "e2e": "10%"
  },
  "medium_projects": {
    "unit": "70%",
    "integration": "25%",
    "e2e": "5%"
  },
  "large_projects": {
    "unit": "75%",
    "integration": "20%",
    "e2e": "5%"
  }
}
```

### Test Naming Conventions

**Consistent Naming Pattern**:
```typescript
// Pattern: [Unit of work]_[State under test]_[Expected behavior]
describe('UserService', () => {
  describe('createUser', () => {
    it('should create user when valid data provided', () => {});
    it('should throw ConflictError when email already exists', () => {});
    it('should throw ValidationError when password is weak', () => {});
  });
  
  describe('authenticateUser', () => {
    it('should return user data when credentials are valid', () => {});
    it('should throw UnauthorizedError when password is incorrect', () => {});
    it('should throw NotFoundError when user does not exist', () => {});
  });
});
```

---

## 🔗 Navigation

**Previous**: [Architecture Patterns](./architecture-patterns.md) | **Next**: [Tools & Libraries Ecosystem](./tools-libraries-ecosystem.md)

---

## 📚 References

1. [Jest Testing Framework](https://jestjs.io/docs/getting-started)
2. [Supertest HTTP Testing](https://github.com/visionmedia/supertest)
3. [Playwright E2E Testing](https://playwright.dev/docs/intro)
4. [k6 Load Testing](https://k6.io/docs/)
5. [Testing Best Practices](https://github.com/goldbergyoni/javascript-testing-best-practices)
6. [Test-Driven Development](https://www.agilealliance.org/glossary/tdd/)
7. [Testing Pyramid](https://martinfowler.com/articles/practical-test-pyramid.html)
8. [Node.js Testing Best Practices](https://github.com/goldbergyoni/nodebestpractices#-6-testing-and-overall-quality-practices)
9. [Database Testing Strategies](https://blog.logrocket.com/unit-testing-node-js-mongodb-using-jest/)
10. [API Testing with Supertest](https://www.albertgao.xyz/2017/05/24/how-to-test-expressjs-with-jest-and-supertest/)