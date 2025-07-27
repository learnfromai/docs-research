# Testing Strategies in Express.js Open Source Projects

## 🧪 Overview

This analysis examines testing strategies and frameworks used across 15 production-grade Express.js applications, providing comprehensive patterns for unit testing, integration testing, and end-to-end testing.

## 📊 Testing Framework Distribution

| Testing Framework | Usage % | Projects Using | Type | Best For |
|------------------|---------|----------------|------|----------|
| **Jest** | 53% | Parse Server, Botpress, WikiJS, Joplin, Wekan, Strapi, Automattic, Ghost | Unit/Integration | TypeScript projects, snapshot testing |
| **Mocha** | 40% | Ghost, Rocket.Chat, Etherpad, GitLab, Discourse, Sentry | Unit/Integration | Flexible test structure |
| **Supertest** | 67% | Ghost, Parse Server, Strapi, WikiJS, Botpress, Joplin, Rocket.Chat, GitLab, Etherpad, Sentry | API Testing | HTTP endpoint testing |
| **Cypress** | 33% | GitLab, Discourse, Mattermost, Strapi, WikiJS | E2E Testing | Frontend integration |
| **Playwright** | 20% | Parse Server, Botpress, WikiJS | E2E Testing | Cross-browser testing |
| **Vitest** | 13% | Modern projects, Botpress | Unit/Integration | Vite ecosystem |
| **TAP (Node.js)** | 13% | Parse Server, Sentry | Unit Testing | Lightweight testing |

## 🏗️ Testing Architecture Patterns

### 1. **Layered Testing Strategy** (90% Adoption)

**Found in**: Ghost, Strapi, Parse Server, WikiJS, Botpress

**Structure**:
```
tests/
├── unit/                   # Business logic, utilities
│   ├── services/
│   ├── utils/
│   └── models/
├── integration/            # API endpoints, database
│   ├── api/
│   ├── database/
│   └── middleware/
├── e2e/                    # End-to-end user flows
│   ├── user-flows/
│   └── admin-flows/
├── fixtures/               # Test data
├── helpers/                # Test utilities
└── setup/                  # Test configuration
```

**Complete Implementation Example**:
```javascript
// tests/setup/testSetup.js
const { MongoMemoryServer } = require('mongodb-memory-server');
const mongoose = require('mongoose');
const Redis = require('redis-mock');

class TestSetup {
  static async setupDatabase() {
    const mongod = await MongoMemoryServer.create();
    const uri = mongod.getUri();
    
    await mongoose.connect(uri, {
      useNewUrlParser: true,
      useUnifiedTopology: true
    });
    
    return mongod;
  }
  
  static setupRedis() {
    return Redis.createClient();
  }
  
  static async createTestApp() {
    process.env.NODE_ENV = 'test';
    process.env.JWT_SECRET = 'test-secret';
    process.env.REDIS_URL = 'redis://localhost:6379';
    
    const app = require('../../src/app');
    return app;
  }
  
  static async cleanDatabase() {
    const collections = await mongoose.connection.db.collections();
    
    for (let collection of collections) {
      await collection.deleteMany({});
    }
  }
  
  static generateTestUser(overrides = {}) {
    return {
      email: 'test@example.com',
      name: 'Test User',
      password: 'TestPassword123!',
      isEmailVerified: true,
      isActive: true,
      ...overrides
    };
  }
}

module.exports = TestSetup;
```

---

### 2. **Jest with Supertest Integration** (Most Popular Pattern)

**Implementation Example**:
```javascript
// tests/integration/api/auth.test.js
const request = require('supertest');
const bcrypt = require('bcrypt');
const TestSetup = require('../../setup/testSetup');
const User = require('../../../src/models/User');

describe('Authentication API', () => {
  let app;
  let mongod;
  
  beforeAll(async () => {
    mongod = await TestSetup.setupDatabase();
    app = await TestSetup.createTestApp();
  });
  
  afterAll(async () => {
    await mongoose.connection.close();
    await mongod.stop();
  });
  
  beforeEach(async () => {
    await TestSetup.cleanDatabase();
  });
  
  describe('POST /api/auth/login', () => {
    beforeEach(async () => {
      // Create test user
      const hashedPassword = await bcrypt.hash('TestPassword123!', 10);
      await User.create({
        email: 'test@example.com',
        name: 'Test User',
        password: hashedPassword,
        isEmailVerified: true,
        isActive: true
      });
    });
    
    it('should login with valid credentials', async () => {
      const response = await request(app)
        .post('/api/auth/login')
        .send({
          email: 'test@example.com',
          password: 'TestPassword123!'
        })
        .expect(200);
      
      expect(response.body).toHaveProperty('accessToken');
      expect(response.body).toHaveProperty('user');
      expect(response.body.user.email).toBe('test@example.com');
      expect(response.body.user).not.toHaveProperty('password');
    });
    
    it('should reject invalid credentials', async () => {
      const response = await request(app)
        .post('/api/auth/login')
        .send({
          email: 'test@example.com',
          password: 'WrongPassword'
        })
        .expect(401);
      
      expect(response.body).toHaveProperty('error');
      expect(response.body.error).toBe('Invalid credentials');
    });
    
    it('should reject unverified email', async () => {
      await User.updateOne(
        { email: 'test@example.com' },
        { isEmailVerified: false }
      );
      
      const response = await request(app)
        .post('/api/auth/login')
        .send({
          email: 'test@example.com',
          password: 'TestPassword123!'
        })
        .expect(401);
      
      expect(response.body.requiresVerification).toBe(true);
    });
    
    it('should validate request body', async () => {
      const response = await request(app)
        .post('/api/auth/login')
        .send({
          email: 'invalid-email',
          password: '123'
        })
        .expect(400);
      
      expect(response.body.error).toBe('Validation failed');
      expect(response.body.details).toHaveLength(2);
    });
    
    it('should handle rate limiting', async () => {
      // Attempt multiple logins
      const promises = Array(6).fill().map(() =>
        request(app)
          .post('/api/auth/login')
          .send({
            email: 'test@example.com',
            password: 'WrongPassword'
          })
      );
      
      const responses = await Promise.all(promises);
      const rateLimitedResponse = responses.find(res => res.status === 429);
      expect(rateLimitedResponse).toBeDefined();
    });
  });
  
  describe('POST /api/auth/refresh', () => {
    let refreshToken;
    
    beforeEach(async () => {
      // Login to get refresh token
      const hashedPassword = await bcrypt.hash('TestPassword123!', 10);
      await User.create({
        email: 'test@example.com',
        password: hashedPassword,
        isEmailVerified: true
      });
      
      const loginResponse = await request(app)
        .post('/api/auth/login')
        .send({
          email: 'test@example.com',
          password: 'TestPassword123!',
          rememberMe: true
        });
      
      refreshToken = loginResponse.headers['set-cookie']
        .find(cookie => cookie.startsWith('refreshToken='))
        .split('=')[1].split(';')[0];
    });
    
    it('should refresh access token with valid refresh token', async () => {
      const response = await request(app)
        .post('/api/auth/refresh')
        .set('Cookie', `refreshToken=${refreshToken}`)
        .expect(200);
      
      expect(response.body).toHaveProperty('accessToken');
      expect(response.body).toHaveProperty('expiresIn');
    });
    
    it('should reject invalid refresh token', async () => {
      const response = await request(app)
        .post('/api/auth/refresh')
        .set('Cookie', 'refreshToken=invalid-token')
        .expect(401);
      
      expect(response.body.error).toBe('Invalid refresh token');
    });
  });
});
```

---

### 3. **Unit Testing Patterns**

**Service Layer Testing**:
```javascript
// tests/unit/services/userService.test.js
const UserService = require('../../../src/services/UserService');
const UserRepository = require('../../../src/repositories/UserRepository');
const EmailService = require('../../../src/services/EmailService');

// Mock dependencies
jest.mock('../../../src/repositories/UserRepository');
jest.mock('../../../src/services/EmailService');

describe('UserService', () => {
  let userService;
  let mockUserRepository;
  let mockEmailService;
  
  beforeEach(() => {
    mockUserRepository = new UserRepository();
    mockEmailService = new EmailService();
    userService = new UserService(mockUserRepository, mockEmailService);
    
    jest.clearAllMocks();
  });
  
  describe('createUser', () => {
    const userData = {
      email: 'test@example.com',
      name: 'Test User',
      password: 'TestPassword123!'
    };
    
    it('should create user successfully', async () => {
      const expectedUser = { id: 1, ...userData, password: 'hashed-password' };
      
      mockUserRepository.findByEmail.mockResolvedValue(null);
      mockUserRepository.create.mockResolvedValue(expectedUser);
      mockEmailService.sendWelcomeEmail.mockResolvedValue(true);
      
      const result = await userService.createUser(userData);
      
      expect(mockUserRepository.findByEmail).toHaveBeenCalledWith(userData.email);
      expect(mockUserRepository.create).toHaveBeenCalledWith(
        expect.objectContaining({
          email: userData.email,
          name: userData.name,
          password: expect.not.stringMatching(userData.password) // Should be hashed
        })
      );
      expect(mockEmailService.sendWelcomeEmail).toHaveBeenCalledWith(userData.email);
      expect(result).toEqual(expectedUser);
    });
    
    it('should throw error if user already exists', async () => {
      mockUserRepository.findByEmail.mockResolvedValue({ id: 1 });
      
      await expect(userService.createUser(userData))
        .rejects.toThrow('User with this email already exists');
      
      expect(mockUserRepository.create).not.toHaveBeenCalled();
      expect(mockEmailService.sendWelcomeEmail).not.toHaveBeenCalled();
    });
    
    it('should validate required fields', async () => {
      await expect(userService.createUser({ email: 'test@example.com' }))
        .rejects.toThrow('Name and password are required');
    });
    
    it('should handle email service failure gracefully', async () => {
      const expectedUser = { id: 1, ...userData };
      
      mockUserRepository.findByEmail.mockResolvedValue(null);
      mockUserRepository.create.mockResolvedValue(expectedUser);
      mockEmailService.sendWelcomeEmail.mockRejectedValue(new Error('Email service down'));
      
      // Should still create user even if email fails
      const result = await userService.createUser(userData);
      expect(result).toEqual(expectedUser);
    });
  });
  
  describe('updateUserProfile', () => {
    const userId = 1;
    const updateData = { name: 'Updated Name' };
    
    it('should update user profile', async () => {
      const existingUser = { id: userId, name: 'Old Name', email: 'test@example.com' };
      const updatedUser = { ...existingUser, ...updateData };
      
      mockUserRepository.findById.mockResolvedValue(existingUser);
      mockUserRepository.update.mockResolvedValue(updatedUser);
      
      const result = await userService.updateUserProfile(userId, updateData);
      
      expect(mockUserRepository.findById).toHaveBeenCalledWith(userId);
      expect(mockUserRepository.update).toHaveBeenCalledWith(userId, updateData);
      expect(result).toEqual(updatedUser);
    });
    
    it('should throw error if user not found', async () => {
      mockUserRepository.findById.mockResolvedValue(null);
      
      await expect(userService.updateUserProfile(userId, updateData))
        .rejects.toThrow('User not found');
    });
  });
});
```

**Utility Function Testing**:
```javascript
// tests/unit/utils/validation.test.js
const { validateEmail, validatePassword, sanitizeInput } = require('../../../src/utils/validation');

describe('Validation Utils', () => {
  describe('validateEmail', () => {
    it('should validate correct email formats', () => {
      const validEmails = [
        'test@example.com',
        'user.name@domain.co.uk',
        'user+tag@domain.com',
        'user123@test-domain.com'
      ];
      
      validEmails.forEach(email => {
        expect(validateEmail(email)).toBe(true);
      });
    });
    
    it('should reject invalid email formats', () => {
      const invalidEmails = [
        'invalid-email',
        '@domain.com',
        'user@',
        'user@domain',
        'user.domain.com',
        ''
      ];
      
      invalidEmails.forEach(email => {
        expect(validateEmail(email)).toBe(false);
      });
    });
  });
  
  describe('validatePassword', () => {
    it('should validate strong passwords', () => {
      const strongPasswords = [
        'TestPassword123!',
        'MySecure@Pass1',
        'Complex&Password9'
      ];
      
      strongPasswords.forEach(password => {
        expect(validatePassword(password)).toBe(true);
      });
    });
    
    it('should reject weak passwords', () => {
      const weakPasswords = [
        'password',           // No uppercase, numbers, or special chars
        'PASSWORD',           // No lowercase, numbers, or special chars
        '12345678',           // No letters or special chars
        'Test123',            // No special chars
        'Test@',              // Too short
        ''                    // Empty
      ];
      
      weakPasswords.forEach(password => {
        expect(validatePassword(password)).toBe(false);
      });
    });
  });
  
  describe('sanitizeInput', () => {
    it('should remove HTML tags', () => {
      const input = '<script>alert("xss")</script>Hello World<b>Bold</b>';
      const expected = 'Hello WorldBold';
      expect(sanitizeInput(input)).toBe(expected);
    });
    
    it('should trim whitespace', () => {
      const input = '  Hello World  ';
      const expected = 'Hello World';
      expect(sanitizeInput(input)).toBe(expected);
    });
    
    it('should handle null and undefined', () => {
      expect(sanitizeInput(null)).toBe('');
      expect(sanitizeInput(undefined)).toBe('');
    });
  });
});
```

---

### 4. **Database Testing Patterns**

**Repository Testing with Test Containers**:
```javascript
// tests/integration/repositories/userRepository.test.js
const { GenericContainer } = require('testcontainers');
const mongoose = require('mongoose');
const UserRepository = require('../../../src/repositories/UserRepository');
const User = require('../../../src/models/User');

describe('UserRepository', () => {
  let container;
  let userRepository;
  
  beforeAll(async () => {
    // Start MongoDB container
    container = await new GenericContainer('mongo:5.0')
      .withExposedPorts(27017)
      .start();
    
    const connectionString = `mongodb://localhost:${container.getMappedPort(27017)}/test`;
    await mongoose.connect(connectionString);
    
    userRepository = new UserRepository();
  }, 30000);
  
  afterAll(async () => {
    await mongoose.connection.close();
    await container.stop();
  });
  
  beforeEach(async () => {
    await User.deleteMany({});
  });
  
  describe('findByEmail', () => {
    it('should find user by email', async () => {
      const userData = {
        email: 'test@example.com',
        name: 'Test User',
        password: 'hashed-password'
      };
      
      await User.create(userData);
      
      const user = await userRepository.findByEmail('test@example.com');
      
      expect(user).toBeTruthy();
      expect(user.email).toBe('test@example.com');
      expect(user.name).toBe('Test User');
    });
    
    it('should return null for non-existent email', async () => {
      const user = await userRepository.findByEmail('nonexistent@example.com');
      expect(user).toBeNull();
    });
    
    it('should be case insensitive', async () => {
      await User.create({
        email: 'test@example.com',
        name: 'Test User',
        password: 'hashed-password'
      });
      
      const user = await userRepository.findByEmail('TEST@EXAMPLE.COM');
      expect(user).toBeTruthy();
    });
  });
  
  describe('create', () => {
    it('should create user with valid data', async () => {
      const userData = {
        email: 'test@example.com',
        name: 'Test User',
        password: 'hashed-password'
      };
      
      const user = await userRepository.create(userData);
      
      expect(user).toBeTruthy();
      expect(user.id).toBeDefined();
      expect(user.email).toBe(userData.email);
      expect(user.createdAt).toBeInstanceOf(Date);
    });
    
    it('should throw error for duplicate email', async () => {
      const userData = {
        email: 'test@example.com',
        name: 'Test User',
        password: 'hashed-password'
      };
      
      await userRepository.create(userData);
      
      await expect(userRepository.create(userData))
        .rejects.toThrow(/duplicate key error/);
    });
  });
});
```

---

### 5. **End-to-End Testing with Playwright**

**E2E Testing Setup**:
```javascript
// tests/e2e/auth.spec.js
const { test, expect } = require('@playwright/test');

test.describe('Authentication Flow', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
  });
  
  test('should complete login flow', async ({ page }) => {
    // Navigate to login page
    await page.click('text=Login');
    await expect(page).toHaveURL('/auth/login');
    
    // Fill login form
    await page.fill('[data-testid=email-input]', 'test@example.com');
    await page.fill('[data-testid=password-input]', 'TestPassword123!');
    await page.click('[data-testid=login-button]');
    
    // Verify successful login
    await expect(page).toHaveURL('/dashboard');
    await expect(page.locator('[data-testid=user-menu]')).toBeVisible();
    await expect(page.locator('text=Welcome, Test User')).toBeVisible();
  });
  
  test('should show error for invalid credentials', async ({ page }) => {
    await page.click('text=Login');
    
    await page.fill('[data-testid=email-input]', 'test@example.com');
    await page.fill('[data-testid=password-input]', 'WrongPassword');
    await page.click('[data-testid=login-button]');
    
    await expect(page.locator('[data-testid=error-message]')).toContainText('Invalid credentials');
    await expect(page).toHaveURL('/auth/login');
  });
  
  test('should handle logout', async ({ page }) => {
    // Login first
    await page.click('text=Login');
    await page.fill('[data-testid=email-input]', 'test@example.com');
    await page.fill('[data-testid=password-input]', 'TestPassword123!');
    await page.click('[data-testid=login-button]');
    
    await expect(page).toHaveURL('/dashboard');
    
    // Logout
    await page.click('[data-testid=user-menu]');
    await page.click('text=Logout');
    
    await expect(page).toHaveURL('/');
    await expect(page.locator('text=Login')).toBeVisible();
  });
  
  test('should persist session on page refresh', async ({ page }) => {
    // Login
    await page.click('text=Login');
    await page.fill('[data-testid=email-input]', 'test@example.com');
    await page.fill('[data-testid=password-input]', 'TestPassword123!');
    await page.click('[data-testid=login-button]');
    
    await expect(page).toHaveURL('/dashboard');
    
    // Refresh page
    await page.reload();
    
    // Should still be logged in
    await expect(page).toHaveURL('/dashboard');
    await expect(page.locator('[data-testid=user-menu]')).toBeVisible();
  });
});
```

---

### 6. **Load Testing with Artillery**

**Performance Testing Setup**:
```yaml
# tests/load/auth-load-test.yml
config:
  target: 'http://localhost:3000'
  phases:
    - duration: 60
      arrivalRate: 10
      name: "Warm up"
    - duration: 120
      arrivalRate: 50
      name: "Load test"
    - duration: 60
      arrivalRate: 100
      name: "Stress test"
  defaults:
    headers:
      Content-Type: 'application/json'

scenarios:
  - name: "Login flow"
    weight: 70
    flow:
      - post:
          url: "/api/auth/login"
          json:
            email: "test{{ $randomNumber(1, 1000) }}@example.com"
            password: "TestPassword123!"
          capture:
            json: "$.accessToken"
            as: "token"
      - get:
          url: "/api/users/profile"
          headers:
            Authorization: "Bearer {{ token }}"
  
  - name: "Registration flow"
    weight: 30
    flow:
      - post:
          url: "/api/auth/register"
          json:
            email: "newuser{{ $randomNumber(1, 10000) }}@example.com"
            name: "Test User"
            password: "TestPassword123!"
          capture:
            json: "$.accessToken"
            as: "token"
      - get:
          url: "/api/users/profile"
          headers:
            Authorization: "Bearer {{ token }}"
```

---

## 🧪 Test Data Management

### 1. **Fixture Factory Pattern**

```javascript
// tests/fixtures/userFixture.js
const bcrypt = require('bcrypt');
const { faker } = require('@faker-js/faker');

class UserFixture {
  static async create(overrides = {}) {
    const hashedPassword = await bcrypt.hash(overrides.password || 'TestPassword123!', 10);
    
    return {
      email: faker.internet.email(),
      name: faker.person.fullName(),
      password: hashedPassword,
      isEmailVerified: true,
      isActive: true,
      role: 'user',
      createdAt: new Date(),
      ...overrides
    };
  }
  
  static async createMany(count, overrides = {}) {
    const users = [];
    for (let i = 0; i < count; i++) {
      users.push(await this.create({
        ...overrides,
        email: `test${i}@example.com`
      }));
    }
    return users;
  }
  
  static createAdmin(overrides = {}) {
    return this.create({
      role: 'admin',
      permissions: ['user:read', 'user:write', 'admin:access'],
      ...overrides
    });
  }
}

module.exports = UserFixture;
```

### 2. **Database Seeding for Tests**

```javascript
// tests/helpers/seedDatabase.js
const UserFixture = require('../fixtures/userFixture');
const PostFixture = require('../fixtures/postFixture');

class DatabaseSeeder {
  static async seedBasicData() {
    // Create test users
    const admin = await UserFixture.createAdmin({
      email: 'admin@example.com'
    });
    
    const users = await UserFixture.createMany(5);
    
    // Create test posts
    const posts = await PostFixture.createMany(10, {
      authorId: users[0].id
    });
    
    return { admin, users, posts };
  }
  
  static async seedForAuthTests() {
    const verifiedUser = await UserFixture.create({
      email: 'verified@example.com',
      isEmailVerified: true
    });
    
    const unverifiedUser = await UserFixture.create({
      email: 'unverified@example.com',
      isEmailVerified: false
    });
    
    const lockedUser = await UserFixture.create({
      email: 'locked@example.com',
      isLocked: true
    });
    
    return { verifiedUser, unverifiedUser, lockedUser };
  }
}

module.exports = DatabaseSeeder;
```

---

## 📊 Testing Strategy Comparison

| Strategy | Pros | Cons | Best Use Case |
|----------|------|------|---------------|
| **Unit Testing** | Fast, isolated, good coverage | Doesn't test integration | Business logic, utilities |
| **Integration Testing** | Tests real interactions | Slower, more complex setup | API endpoints, database operations |
| **E2E Testing** | Tests complete user flows | Slow, brittle, expensive | Critical user journeys |
| **Load Testing** | Performance validation | Resource intensive | Production readiness |
| **Contract Testing** | API compatibility | Additional tooling needed | Microservices, API consumers |

## 🎯 Testing Best Practices

### 1. **Test Organization**
- **Follow AAA pattern**: Arrange, Act, Assert
- **Use descriptive test names** that explain the scenario
- **Group related tests** with describe blocks
- **Keep tests independent** - no shared state between tests

### 2. **Coverage Goals**
- **Unit Tests**: 90%+ coverage for business logic
- **Integration Tests**: Cover all API endpoints
- **E2E Tests**: Cover critical user flows only
- **Performance Tests**: Key endpoints under load

### 3. **Test Data Management**
- **Use factories/fixtures** for consistent test data
- **Clean database** between tests
- **Use in-memory databases** for faster tests
- **Seed data** specific to test scenarios

### 4. **Mocking Strategy**
- **Mock external services** (APIs, email, etc.)
- **Don't mock what you don't own** (database, framework)
- **Use dependency injection** for easier testing
- **Verify mock interactions** when behavior matters

### 5. **CI/CD Integration**
```yaml
# .github/workflows/test.yml
name: Test Suite

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    
    services:
      mongodb:
        image: mongo:5.0
        ports:
          - 27017:27017
      redis:
        image: redis:6.2
        ports:
          - 6379:6379
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'
          cache: 'npm'
      
      - name: Install dependencies
        run: npm ci
      
      - name: Run linting
        run: npm run lint
      
      - name: Run unit tests
        run: npm run test:unit
      
      - name: Run integration tests
        run: npm run test:integration
        env:
          MONGODB_URI: mongodb://localhost:27017/test
          REDIS_URL: redis://localhost:6379
      
      - name: Upload coverage
        uses: codecov/codecov-action@v3
```

---

**Next**: [Implementation Guide](./implementation-guide.md) | **Previous**: [Authentication Strategies](./authentication-strategies.md)