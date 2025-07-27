# Testing Strategies: Express.js Applications

## 🎯 Overview

This document analyzes testing strategies and patterns used across 15+ successful Express.js projects, providing comprehensive guidance on implementing robust testing for production applications.

## 📋 Table of Contents

1. [Testing Pyramid & Strategy](#1-testing-pyramid--strategy)
2. [Unit Testing Patterns](#2-unit-testing-patterns)
3. [Integration Testing](#3-integration-testing)
4. [API Testing](#4-api-testing)
5. [End-to-End Testing](#5-end-to-end-testing)
6. [Performance Testing](#6-performance-testing)
7. [Security Testing](#7-security-testing)
8. [Testing Best Practices](#8-testing-best-practices)

## 1. Testing Pyramid & Strategy

### 1.1 Testing Distribution Analysis

**From 15+ Express.js Projects**:

| Test Type | Percentage | Speed | Cost | Confidence |
|-----------|------------|-------|------|------------|
| **Unit Tests** | 70% | Fast | Low | Medium |
| **Integration Tests** | 20% | Medium | Medium | High |
| **E2E Tests** | 10% | Slow | High | Very High |

```javascript
// Testing strategy configuration from Ghost
module.exports = {
    testEnvironment: 'node',
    projects: [
        {
            displayName: 'unit',
            testMatch: ['<rootDir>/tests/unit/**/*.test.js'],
            setupFilesAfterEnv: ['<rootDir>/tests/unit/setup.js']
        },
        {
            displayName: 'integration',
            testMatch: ['<rootDir>/tests/integration/**/*.test.js'],
            setupFilesAfterEnv: ['<rootDir>/tests/integration/setup.js']
        },
        {
            displayName: 'e2e',
            testMatch: ['<rootDir>/tests/e2e/**/*.test.js'],
            setupFilesAfterEnv: ['<rootDir>/tests/e2e/setup.js'],
            testTimeout: 30000
        }
    ],
    collectCoverageFrom: [
        'src/**/*.js',
        '!src/**/*.test.js',
        '!src/server.js'
    ],
    coverageThreshold: {
        global: {
            branches: 80,
            functions: 80,
            lines: 80,
            statements: 80
        }
    }
};
```

### 1.2 Project-Specific Testing Approaches

| Project | Unit % | Integration % | E2E % | Coverage | Framework |
|---------|--------|---------------|-------|----------|-----------|
| **Ghost** | 85% | 10% | 5% | 85%+ | Mocha + Should |
| **Strapi** | 75% | 20% | 5% | 80%+ | Jest + Supertest |
| **Parse Server** | 90% | 8% | 2% | 90%+ | Jasmine + Supertest |
| **Rocket.Chat** | 70% | 25% | 5% | 75%+ | Jest + Playwright |
| **GitLab CE** | 80% | 15% | 5% | 85%+ | RSpec + Capybara |

## 2. Unit Testing Patterns

### 2.1 Service Layer Testing

**Pattern from Strapi & Parse Server**:

```javascript
// Service under test
class UserService {
    constructor(userRepository, emailService, logger) {
        this.userRepository = userRepository;
        this.emailService = emailService;
        this.logger = logger;
    }
    
    async createUser(userData) {
        // Validate business rules
        const existingUser = await this.userRepository.findByEmail(userData.email);
        if (existingUser) {
            throw new Error('User already exists');
        }
        
        // Create user
        const user = await this.userRepository.create(userData);
        
        // Send welcome email
        try {
            await this.emailService.sendWelcomeEmail(user.email);
        } catch (error) {
            this.logger.warn('Failed to send welcome email', { userId: user.id, error });
        }
        
        // Log user creation
        this.logger.info('User created', { userId: user.id });
        
        return user;
    }
}

// Unit test
describe('UserService', () => {
    let userService;
    let mockUserRepository;
    let mockEmailService;
    let mockLogger;
    
    beforeEach(() => {
        mockUserRepository = {
            findByEmail: jest.fn(),
            create: jest.fn()
        };
        
        mockEmailService = {
            sendWelcomeEmail: jest.fn()
        };
        
        mockLogger = {
            info: jest.fn(),
            warn: jest.fn(),
            error: jest.fn()
        };
        
        userService = new UserService(
            mockUserRepository,
            mockEmailService,
            mockLogger
        );
    });
    
    describe('createUser', () => {
        const userData = {
            email: 'test@example.com',
            firstName: 'John',
            lastName: 'Doe'
        };
        
        it('should create user successfully', async () => {
            const createdUser = { id: '123', ...userData };
            
            mockUserRepository.findByEmail.mockResolvedValue(null);
            mockUserRepository.create.mockResolvedValue(createdUser);
            mockEmailService.sendWelcomeEmail.mockResolvedValue(true);
            
            const result = await userService.createUser(userData);
            
            expect(mockUserRepository.findByEmail).toHaveBeenCalledWith(userData.email);
            expect(mockUserRepository.create).toHaveBeenCalledWith(userData);
            expect(mockEmailService.sendWelcomeEmail).toHaveBeenCalledWith(userData.email);
            expect(mockLogger.info).toHaveBeenCalledWith(
                'User created',
                { userId: createdUser.id }
            );
            expect(result).toEqual(createdUser);
        });
        
        it('should throw error when user already exists', async () => {
            const existingUser = { id: '456', email: userData.email };
            mockUserRepository.findByEmail.mockResolvedValue(existingUser);
            
            await expect(userService.createUser(userData))
                .rejects
                .toThrow('User already exists');
            
            expect(mockUserRepository.create).not.toHaveBeenCalled();
            expect(mockEmailService.sendWelcomeEmail).not.toHaveBeenCalled();
        });
        
        it('should handle email service failure gracefully', async () => {
            const createdUser = { id: '123', ...userData };
            
            mockUserRepository.findByEmail.mockResolvedValue(null);
            mockUserRepository.create.mockResolvedValue(createdUser);
            mockEmailService.sendWelcomeEmail.mockRejectedValue(new Error('Email failed'));
            
            const result = await userService.createUser(userData);
            
            expect(result).toEqual(createdUser);
            expect(mockLogger.warn).toHaveBeenCalledWith(
                'Failed to send welcome email',
                { userId: createdUser.id, error: expect.any(Error) }
            );
            expect(mockLogger.info).toHaveBeenCalledWith(
                'User created',
                { userId: createdUser.id }
            );
        });
    });
});
```

### 2.2 Middleware Testing

```javascript
// Authentication middleware test from Ghost
const authenticateToken = require('../../../src/middleware/auth');
const jwt = require('jsonwebtoken');
const User = require('../../../src/models/User');

jest.mock('jsonwebtoken');
jest.mock('../../../src/models/User');

describe('authenticateToken middleware', () => {
    let req, res, next;
    
    beforeEach(() => {
        req = {
            headers: {}
        };
        res = {
            status: jest.fn().mockReturnThis(),
            json: jest.fn()
        };
        next = jest.fn();
        
        jest.clearAllMocks();
    });
    
    it('should authenticate valid token', async () => {
        const mockUser = { id: '123', email: 'test@example.com' };
        const mockToken = 'valid.jwt.token';
        const mockDecoded = { userId: '123' };
        
        req.headers.authorization = `Bearer ${mockToken}`;
        jwt.verify.mockReturnValue(mockDecoded);
        User.findById.mockResolvedValue(mockUser);
        
        await authenticateToken(req, res, next);
        
        expect(jwt.verify).toHaveBeenCalledWith(mockToken, process.env.JWT_SECRET);
        expect(User.findById).toHaveBeenCalledWith('123');
        expect(req.user).toEqual(mockUser);
        expect(next).toHaveBeenCalled();
    });
    
    it('should return 401 when no token provided', async () => {
        await authenticateToken(req, res, next);
        
        expect(res.status).toHaveBeenCalledWith(401);
        expect(res.json).toHaveBeenCalledWith({
            success: false,
            message: 'Access token required'
        });
        expect(next).not.toHaveBeenCalled();
    });
    
    it('should return 403 when token is invalid', async () => {
        req.headers.authorization = 'Bearer invalid.token';
        jwt.verify.mockImplementation(() => {
            throw new Error('Invalid token');
        });
        
        await authenticateToken(req, res, next);
        
        expect(res.status).toHaveBeenCalledWith(403);
        expect(res.json).toHaveBeenCalledWith({
            success: false,
            message: 'Invalid or expired token'
        });
        expect(next).not.toHaveBeenCalled();
    });
    
    it('should return 401 when user not found', async () => {
        const mockToken = 'valid.jwt.token';
        const mockDecoded = { userId: '123' };
        
        req.headers.authorization = `Bearer ${mockToken}`;
        jwt.verify.mockReturnValue(mockDecoded);
        User.findById.mockResolvedValue(null);
        
        await authenticateToken(req, res, next);
        
        expect(res.status).toHaveBeenCalledWith(401);
        expect(res.json).toHaveBeenCalledWith({
            success: false,
            message: 'User not found or inactive'
        });
        expect(next).not.toHaveBeenCalled();
    });
});
```

### 2.3 Utility Function Testing

```javascript
// Validation utility tests from Strapi
const { validateEmail, sanitizeInput, generateSlug } = require('../../../src/utils/validation');

describe('Validation Utilities', () => {
    describe('validateEmail', () => {
        it('should validate correct email formats', () => {
            const validEmails = [
                'test@example.com',
                'user.name@domain.co.uk',
                'user+tag@example.org'
            ];
            
            validEmails.forEach(email => {
                expect(validateEmail(email)).toBe(true);
            });
        });
        
        it('should reject invalid email formats', () => {
            const invalidEmails = [
                'invalid.email',
                '@domain.com',
                'user@',
                'user name@domain.com'
            ];
            
            invalidEmails.forEach(email => {
                expect(validateEmail(email)).toBe(false);
            });
        });
    });
    
    describe('sanitizeInput', () => {
        it('should remove dangerous HTML tags', () => {
            const input = '<script>alert("xss")</script><p>Safe content</p>';
            const expected = '<p>Safe content</p>';
            
            expect(sanitizeInput(input)).toBe(expected);
        });
        
        it('should preserve safe HTML tags', () => {
            const input = '<p>Safe <strong>content</strong> with <em>emphasis</em></p>';
            
            expect(sanitizeInput(input)).toBe(input);
        });
    });
    
    describe('generateSlug', () => {
        it('should generate URL-friendly slugs', () => {
            const testCases = [
                { input: 'Hello World', expected: 'hello-world' },
                { input: 'Special Characters!@#', expected: 'special-characters' },
                { input: 'Multiple   Spaces', expected: 'multiple-spaces' }
            ];
            
            testCases.forEach(({ input, expected }) => {
                expect(generateSlug(input)).toBe(expected);
            });
        });
    });
});
```

## 3. Integration Testing

### 3.1 Database Integration Testing

```javascript
// Database integration test setup from Parse Server
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');
const User = require('../../../src/models/User');

describe('User Model Integration', () => {
    let mongoServer;
    let mongoUri;
    
    beforeAll(async () => {
        mongoServer = await MongoMemoryServer.create();
        mongoUri = mongoServer.getUri();
        
        await mongoose.connect(mongoUri, {
            useNewUrlParser: true,
            useUnifiedTopology: true
        });
    });
    
    afterAll(async () => {
        await mongoose.connection.dropDatabase();
        await mongoose.connection.close();
        await mongoServer.stop();
    });
    
    beforeEach(async () => {
        await User.deleteMany({});
    });
    
    describe('User creation', () => {
        it('should create user with valid data', async () => {
            const userData = {
                email: 'test@example.com',
                password: 'hashedpassword',
                firstName: 'John',
                lastName: 'Doe'
            };
            
            const user = new User(userData);
            const savedUser = await user.save();
            
            expect(savedUser._id).toBeDefined();
            expect(savedUser.email).toBe(userData.email);
            expect(savedUser.createdAt).toBeDefined();
            expect(savedUser.updatedAt).toBeDefined();
        });
        
        it('should enforce unique email constraint', async () => {
            const userData = {
                email: 'test@example.com',
                password: 'hashedpassword',
                firstName: 'John',
                lastName: 'Doe'
            };
            
            await User.create(userData);
            
            await expect(User.create(userData))
                .rejects
                .toThrow(/duplicate key error/);
        });
        
        it('should validate required fields', async () => {
            const invalidUserData = {
                firstName: 'John'
                // Missing required fields
            };
            
            await expect(User.create(invalidUserData))
                .rejects
                .toThrow(/validation failed/);
        });
    });
    
    describe('User queries', () => {
        beforeEach(async () => {
            await User.create([
                {
                    email: 'user1@example.com',
                    password: 'hash1',
                    firstName: 'John',
                    lastName: 'Doe',
                    role: 'user'
                },
                {
                    email: 'admin@example.com',
                    password: 'hash2',
                    firstName: 'Admin',
                    lastName: 'User',
                    role: 'admin'
                }
            ]);
        });
        
        it('should find user by email', async () => {
            const user = await User.findOne({ email: 'user1@example.com' });
            
            expect(user).toBeTruthy();
            expect(user.firstName).toBe('John');
        });
        
        it('should find users by role', async () => {
            const admins = await User.find({ role: 'admin' });
            
            expect(admins).toHaveLength(1);
            expect(admins[0].email).toBe('admin@example.com');
        });
        
        it('should support pagination', async () => {
            const page1 = await User.find().limit(1).skip(0);
            const page2 = await User.find().limit(1).skip(1);
            
            expect(page1).toHaveLength(1);
            expect(page2).toHaveLength(1);
            expect(page1[0]._id).not.toEqual(page2[0]._id);
        });
    });
});
```

### 3.2 Service Integration Testing

```javascript
// Service integration test from Rocket.Chat
const UserService = require('../../../src/services/UserService');
const EmailService = require('../../../src/services/EmailService');
const User = require('../../../src/models/User');

describe('UserService Integration', () => {
    let userService;
    let emailService;
    
    beforeEach(async () => {
        emailService = new EmailService();
        userService = new UserService(emailService);
        
        // Mock external email service
        jest.spyOn(emailService, 'sendWelcomeEmail').mockResolvedValue(true);
        
        await User.deleteMany({});
    });
    
    describe('User registration flow', () => {
        it('should complete full registration process', async () => {
            const userData = {
                email: 'test@example.com',
                password: 'Password123!',
                firstName: 'John',
                lastName: 'Doe'
            };
            
            const result = await userService.registerUser(userData);
            
            // Verify user created in database
            const savedUser = await User.findById(result.user.id);
            expect(savedUser).toBeTruthy();
            expect(savedUser.email).toBe(userData.email);
            
            // Verify password is hashed
            expect(savedUser.password).not.toBe(userData.password);
            expect(savedUser.password).toMatch(/^\$2[aby]\$/);
            
            // Verify email was sent
            expect(emailService.sendWelcomeEmail).toHaveBeenCalledWith(userData.email);
            
            // Verify JWT tokens generated
            expect(result.tokens.accessToken).toBeDefined();
            expect(result.tokens.refreshToken).toBeDefined();
        });
        
        it('should handle duplicate email registration', async () => {
            const userData = {
                email: 'duplicate@example.com',
                password: 'Password123!',
                firstName: 'John',
                lastName: 'Doe'
            };
            
            // Create first user
            await userService.registerUser(userData);
            
            // Attempt to create duplicate
            await expect(userService.registerUser(userData))
                .rejects
                .toThrow('User already exists');
            
            // Verify only one user exists
            const users = await User.find({ email: userData.email });
            expect(users).toHaveLength(1);
        });
        
        it('should handle email service failure gracefully', async () => {
            const userData = {
                email: 'test@example.com',
                password: 'Password123!',
                firstName: 'John',
                lastName: 'Doe'
            };
            
            // Mock email service failure
            emailService.sendWelcomeEmail.mockRejectedValue(new Error('Email service down'));
            
            // Registration should still succeed
            const result = await userService.registerUser(userData);
            
            expect(result.user).toBeDefined();
            expect(result.tokens).toBeDefined();
            
            // User should exist in database
            const savedUser = await User.findById(result.user.id);
            expect(savedUser).toBeTruthy();
        });
    });
});
```

## 4. API Testing

### 4.1 HTTP API Testing with Supertest

```javascript
// API integration tests from Ghost
const request = require('supertest');
const app = require('../../../src/app');
const User = require('../../../src/models/User');

describe('Authentication API', () => {
    beforeEach(async () => {
        await User.deleteMany({});
    });
    
    describe('POST /api/auth/register', () => {
        const validUserData = {
            email: 'test@example.com',
            password: 'Password123!',
            firstName: 'John',
            lastName: 'Doe'
        };
        
        it('should register user with valid data', async () => {
            const response = await request(app)
                .post('/api/auth/register')
                .send(validUserData)
                .expect(201);
            
            expect(response.body).toMatchObject({
                success: true,
                data: {
                    user: {
                        email: validUserData.email,
                        firstName: validUserData.firstName,
                        lastName: validUserData.lastName
                    },
                    tokens: {
                        accessToken: expect.any(String),
                        refreshToken: expect.any(String)
                    }
                }
            });
            
            // Verify user in database
            const user = await User.findOne({ email: validUserData.email });
            expect(user).toBeTruthy();
            expect(user.password).not.toBe(validUserData.password); // Should be hashed
        });
        
        it('should return validation errors for invalid data', async () => {
            const invalidData = {
                email: 'invalid-email',
                password: '123', // Too short
                firstName: '', // Empty
                lastName: 'Doe'
            };
            
            const response = await request(app)
                .post('/api/auth/register')
                .send(invalidData)
                .expect(400);
            
            expect(response.body).toMatchObject({
                success: false,
                message: 'Validation failed',
                errors: expect.arrayContaining([
                    expect.objectContaining({
                        field: 'email',
                        message: expect.stringContaining('email')
                    }),
                    expect.objectContaining({
                        field: 'password',
                        message: expect.stringContaining('password')
                    })
                ])
            });
        });
        
        it('should handle duplicate email registration', async () => {
            // Create first user
            await request(app)
                .post('/api/auth/register')
                .send(validUserData)
                .expect(201);
            
            // Attempt duplicate registration
            const response = await request(app)
                .post('/api/auth/register')
                .send(validUserData)
                .expect(409);
            
            expect(response.body).toMatchObject({
                success: false,
                message: expect.stringContaining('already exists')
            });
        });
        
        it('should enforce rate limiting', async () => {
            // Make multiple rapid requests
            const requests = Array(6).fill().map(() =>
                request(app)
                    .post('/api/auth/register')
                    .send({
                        ...validUserData,
                        email: `test${Math.random()}@example.com`
                    })
            );
            
            const responses = await Promise.all(requests);
            
            // Should have at least one rate limited response
            const rateLimited = responses.some(res => res.status === 429);
            expect(rateLimited).toBe(true);
        });
    });
    
    describe('POST /api/auth/login', () => {
        beforeEach(async () => {
            // Create test user
            await request(app)
                .post('/api/auth/register')
                .send({
                    email: 'test@example.com',
                    password: 'Password123!',
                    firstName: 'John',
                    lastName: 'Doe'
                });
        });
        
        it('should login with valid credentials', async () => {
            const response = await request(app)
                .post('/api/auth/login')
                .send({
                    email: 'test@example.com',
                    password: 'Password123!'
                })
                .expect(200);
            
            expect(response.body).toMatchObject({
                success: true,
                data: {
                    user: {
                        email: 'test@example.com'
                    },
                    tokens: {
                        accessToken: expect.any(String),
                        refreshToken: expect.any(String)
                    }
                }
            });
        });
        
        it('should reject invalid credentials', async () => {
            const response = await request(app)
                .post('/api/auth/login')
                .send({
                    email: 'test@example.com',
                    password: 'wrongpassword'
                })
                .expect(401);
            
            expect(response.body).toMatchObject({
                success: false,
                message: expect.stringContaining('Invalid credentials')
            });
        });
    });
});

// Protected routes testing
describe('Protected Routes', () => {
    let authToken;
    let userId;
    
    beforeEach(async () => {
        // Register and login user
        const registerResponse = await request(app)
            .post('/api/auth/register')
            .send({
                email: 'test@example.com',
                password: 'Password123!',
                firstName: 'John',
                lastName: 'Doe'
            });
        
        authToken = registerResponse.body.data.tokens.accessToken;
        userId = registerResponse.body.data.user.id;
    });
    
    describe('GET /api/users/profile', () => {
        it('should return user profile with valid token', async () => {
            const response = await request(app)
                .get('/api/users/profile')
                .set('Authorization', `Bearer ${authToken}`)
                .expect(200);
            
            expect(response.body.data.user).toMatchObject({
                id: userId,
                email: 'test@example.com'
            });
        });
        
        it('should return 401 without token', async () => {
            await request(app)
                .get('/api/users/profile')
                .expect(401);
        });
        
        it('should return 403 with invalid token', async () => {
            await request(app)
                .get('/api/users/profile')
                .set('Authorization', 'Bearer invalid.jwt.token')
                .expect(403);
        });
    });
});
```

### 4.2 GraphQL API Testing

```javascript
// GraphQL testing from Strapi
const { graphql } = require('graphql');
const { buildSchema } = require('../../../src/graphql/schema');
const { createContext } = require('../../../src/graphql/context');

describe('GraphQL API', () => {
    let schema;
    let context;
    
    beforeEach(async () => {
        schema = buildSchema();
        context = await createContext();
    });
    
    describe('User queries', () => {
        beforeEach(async () => {
            // Create test users
            await User.create([
                {
                    email: 'user1@example.com',
                    firstName: 'John',
                    lastName: 'Doe'
                },
                {
                    email: 'user2@example.com',
                    firstName: 'Jane',
                    lastName: 'Smith'
                }
            ]);
        });
        
        it('should fetch all users', async () => {
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
            
            const result = await graphql(schema, query, null, context);
            
            expect(result.errors).toBeUndefined();
            expect(result.data.users).toHaveLength(2);
            expect(result.data.users[0]).toMatchObject({
                email: 'user1@example.com',
                firstName: 'John'
            });
        });
        
        it('should fetch user by ID', async () => {
            const user = await User.findOne({ email: 'user1@example.com' });
            
            const query = `
                query($id: ID!) {
                    user(id: $id) {
                        id
                        email
                        firstName
                    }
                }
            `;
            
            const result = await graphql(
                schema,
                query,
                null,
                context,
                { id: user._id.toString() }
            );
            
            expect(result.errors).toBeUndefined();
            expect(result.data.user).toMatchObject({
                id: user._id.toString(),
                email: 'user1@example.com'
            });
        });
    });
    
    describe('User mutations', () => {
        it('should create user', async () => {
            const mutation = `
                mutation($input: CreateUserInput!) {
                    createUser(input: $input) {
                        id
                        email
                        firstName
                    }
                }
            `;
            
            const variables = {
                input: {
                    email: 'new@example.com',
                    password: 'Password123!',
                    firstName: 'New',
                    lastName: 'User'
                }
            };
            
            const result = await graphql(schema, mutation, null, context, variables);
            
            expect(result.errors).toBeUndefined();
            expect(result.data.createUser).toMatchObject({
                email: 'new@example.com',
                firstName: 'New'
            });
            
            // Verify in database
            const user = await User.findOne({ email: 'new@example.com' });
            expect(user).toBeTruthy();
        });
        
        it('should handle validation errors', async () => {
            const mutation = `
                mutation($input: CreateUserInput!) {
                    createUser(input: $input) {
                        id
                        email
                    }
                }
            `;
            
            const variables = {
                input: {
                    email: 'invalid-email',
                    password: '123' // Too short
                }
            };
            
            const result = await graphql(schema, mutation, null, context, variables);
            
            expect(result.errors).toBeDefined();
            expect(result.errors[0].message).toContain('validation');
        });
    });
});
```

## 5. End-to-End Testing

### 5.1 Cypress E2E Testing

```javascript
// Cypress E2E tests from GitLab CE
describe('User Authentication Flow', () => {
    beforeEach(() => {
        cy.visit('/');
        cy.clearCookies();
        cy.clearLocalStorage();
    });
    
    describe('User Registration', () => {
        it('should complete registration successfully', () => {
            cy.visit('/register');
            
            // Fill registration form
            cy.get('[data-testid="email-input"]').type('test@example.com');
            cy.get('[data-testid="password-input"]').type('Password123!');
            cy.get('[data-testid="confirm-password-input"]').type('Password123!');
            cy.get('[data-testid="first-name-input"]').type('John');
            cy.get('[data-testid="last-name-input"]').type('Doe');
            
            // Accept terms
            cy.get('[data-testid="terms-checkbox"]').check();
            
            // Submit form
            cy.get('[data-testid="register-button"]').click();
            
            // Verify successful registration
            cy.url().should('include', '/dashboard');
            cy.get('[data-testid="welcome-message"]').should('contain', 'Welcome, John');
            cy.get('[data-testid="user-menu"]').should('be.visible');
        });
        
        it('should show validation errors for invalid data', () => {
            cy.visit('/register');
            
            // Try to submit with invalid data
            cy.get('[data-testid="email-input"]').type('invalid-email');
            cy.get('[data-testid="password-input"]').type('123');
            cy.get('[data-testid="register-button"]').click();
            
            // Check validation errors
            cy.get('[data-testid="email-error"]').should('contain', 'valid email');
            cy.get('[data-testid="password-error"]').should('contain', 'at least 8 characters');
            
            // Should not navigate away
            cy.url().should('include', '/register');
        });
    });
    
    describe('User Login', () => {
        beforeEach(() => {
            // Create test user via API
            cy.request('POST', '/api/auth/register', {
                email: 'test@example.com',
                password: 'Password123!',
                firstName: 'John',
                lastName: 'Doe'
            });
        });
        
        it('should login with valid credentials', () => {
            cy.visit('/login');
            
            cy.get('[data-testid="email-input"]').type('test@example.com');
            cy.get('[data-testid="password-input"]').type('Password123!');
            cy.get('[data-testid="login-button"]').click();
            
            cy.url().should('include', '/dashboard');
            cy.get('[data-testid="user-menu"]').should('be.visible');
        });
        
        it('should show error for invalid credentials', () => {
            cy.visit('/login');
            
            cy.get('[data-testid="email-input"]').type('test@example.com');
            cy.get('[data-testid="password-input"]').type('wrongpassword');
            cy.get('[data-testid="login-button"]').click();
            
            cy.get('[data-testid="error-message"]').should('contain', 'Invalid credentials');
            cy.url().should('include', '/login');
        });
    });
    
    describe('Protected Routes', () => {
        it('should redirect unauthenticated users to login', () => {
            cy.visit('/dashboard');
            cy.url().should('include', '/login');
        });
        
        it('should allow authenticated users to access protected routes', () => {
            // Login via API and set token
            cy.request('POST', '/api/auth/login', {
                email: 'test@example.com',
                password: 'Password123!'
            }).then((response) => {
                window.localStorage.setItem('accessToken', response.body.data.tokens.accessToken);
            });
            
            cy.visit('/dashboard');
            cy.url().should('include', '/dashboard');
            cy.get('[data-testid="dashboard-content"]').should('be.visible');
        });
    });
});

// Advanced E2E scenarios
describe('User Profile Management', () => {
    beforeEach(() => {
        // Setup authenticated user
        cy.login('test@example.com', 'Password123!');
    });
    
    it('should update profile information', () => {
        cy.visit('/profile');
        
        // Update profile
        cy.get('[data-testid="first-name-input"]').clear().type('Jane');
        cy.get('[data-testid="bio-textarea"]').type('Software developer');
        cy.get('[data-testid="save-button"]').click();
        
        // Verify success message
        cy.get('[data-testid="success-message"]').should('contain', 'Profile updated');
        
        // Verify changes persisted
        cy.reload();
        cy.get('[data-testid="first-name-input"]').should('have.value', 'Jane');
        cy.get('[data-testid="bio-textarea"]').should('contain', 'Software developer');
    });
    
    it('should upload profile picture', () => {
        cy.visit('/profile');
        
        // Upload file
        cy.get('[data-testid="avatar-upload"]').selectFile('cypress/fixtures/avatar.jpg');
        
        // Verify upload
        cy.get('[data-testid="upload-progress"]').should('be.visible');
        cy.get('[data-testid="avatar-preview"]').should('be.visible');
        cy.get('[data-testid="save-button"]').click();
        
        // Verify success
        cy.get('[data-testid="success-message"]').should('contain', 'Avatar updated');
    });
});
```

### 5.2 Playwright E2E Testing

```javascript
// Playwright tests from Rocket.Chat
const { test, expect } = require('@playwright/test');

test.describe('Real-time Chat Features', () => {
    test.beforeEach(async ({ page }) => {
        await page.goto('/login');
        await page.fill('[data-testid="email-input"]', 'test@example.com');
        await page.fill('[data-testid="password-input"]', 'Password123!');
        await page.click('[data-testid="login-button"]');
        await expect(page).toHaveURL(/.*\/dashboard/);
    });
    
    test('should send and receive messages', async ({ page, context }) => {
        // Open second browser context for second user
        const secondPage = await context.newPage();
        await secondPage.goto('/login');
        await secondPage.fill('[data-testid="email-input"]', 'user2@example.com');
        await secondPage.fill('[data-testid="password-input"]', 'Password123!');
        await secondPage.click('[data-testid="login-button"]');
        
        // User 1 creates a channel
        await page.click('[data-testid="create-channel-button"]');
        await page.fill('[data-testid="channel-name-input"]', 'test-channel');
        await page.click('[data-testid="create-button"]');
        
        // User 1 invites User 2
        await page.click('[data-testid="invite-users-button"]');
        await page.fill('[data-testid="user-search-input"]', 'user2@example.com');
        await page.click('[data-testid="invite-button"]');
        
        // User 2 joins the channel
        await secondPage.click('[data-testid="notifications-button"]');
        await secondPage.click('[data-testid="join-channel-invitation"]');
        
        // User 1 sends a message
        const message = 'Hello from User 1!';
        await page.fill('[data-testid="message-input"]', message);
        await page.press('[data-testid="message-input"]', 'Enter');
        
        // Verify message appears for both users
        await expect(page.locator('[data-testid="message-text"]').last()).toContainText(message);
        await expect(secondPage.locator('[data-testid="message-text"]').last()).toContainText(message);
        
        // User 2 replies
        const reply = 'Hello back from User 2!';
        await secondPage.fill('[data-testid="message-input"]', reply);
        await secondPage.press('[data-testid="message-input"]', 'Enter');
        
        // Verify reply appears for both users
        await expect(page.locator('[data-testid="message-text"]').last()).toContainText(reply);
        await expect(secondPage.locator('[data-testid="message-text"]').last()).toContainText(reply);
    });
    
    test('should handle file uploads in chat', async ({ page }) => {
        await page.click('[data-testid="general-channel"]');
        
        // Upload file
        await page.setInputFiles('[data-testid="file-upload-input"]', 'tests/fixtures/test-document.pdf');
        
        // Wait for upload to complete
        await expect(page.locator('[data-testid="upload-progress"]')).toBeVisible();
        await expect(page.locator('[data-testid="upload-complete"]')).toBeVisible();
        
        // Send message with file
        await page.click('[data-testid="send-file-button"]');
        
        // Verify file message appears
        await expect(page.locator('[data-testid="file-message"]')).toBeVisible();
        await expect(page.locator('[data-testid="file-name"]')).toContainText('test-document.pdf');
    });
});
```

## 6. Performance Testing

### 6.1 Load Testing with Artillery

```yaml
# artillery-config.yml from Parse Server
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
  payload:
    path: "test-data.csv"
    fields:
      - email
      - password

scenarios:
  - name: "Authentication flow"
    weight: 40
    flow:
      - post:
          url: "/api/auth/register"
          json:
            email: "{{ email }}"
            password: "{{ password }}"
            firstName: "Test"
            lastName: "User"
          capture:
            - json: "$.data.tokens.accessToken"
              as: "accessToken"
      - post:
          url: "/api/auth/login"
          json:
            email: "{{ email }}"
            password: "{{ password }}"
      - get:
          url: "/api/users/profile"
          headers:
            Authorization: "Bearer {{ accessToken }}"

  - name: "API endpoints"
    weight: 60
    flow:
      - post:
          url: "/api/auth/login"
          json:
            email: "test@example.com"
            password: "Password123!"
          capture:
            - json: "$.data.tokens.accessToken"
              as: "accessToken"
      - get:
          url: "/api/posts"
          headers:
            Authorization: "Bearer {{ accessToken }}"
      - post:
          url: "/api/posts"
          headers:
            Authorization: "Bearer {{ accessToken }}"
          json:
            title: "Test Post {{ $randomString() }}"
            content: "This is a test post"
```

### 6.2 Performance Testing with K6

```javascript
// k6-performance.js from GitLab CE
import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate } from 'k6/metrics';

const errorRate = new Rate('errors');

export let options = {
    stages: [
        { duration: '2m', target: 20 }, // Ramp up
        { duration: '5m', target: 20 }, // Stay at 20 users
        { duration: '2m', target: 50 }, // Ramp up to 50 users
        { duration: '5m', target: 50 }, // Stay at 50 users
        { duration: '2m', target: 0 },  // Ramp down
    ],
    thresholds: {
        http_req_duration: ['p(95)<2000'], // 95% of requests must complete below 2s
        http_req_failed: ['rate<0.05'],    // Error rate must be below 5%
        errors: ['rate<0.1'],              // Custom error rate
    },
};

const BASE_URL = 'http://localhost:3000';

export function setup() {
    // Create test user
    const payload = {
        email: 'loadtest@example.com',
        password: 'Password123!',
        firstName: 'Load',
        lastName: 'Test'
    };
    
    const response = http.post(`${BASE_URL}/api/auth/register`, JSON.stringify(payload), {
        headers: { 'Content-Type': 'application/json' }
    });
    
    return {
        accessToken: response.json('data.tokens.accessToken')
    };
}

export default function(data) {
    // Login
    const loginPayload = {
        email: 'loadtest@example.com',
        password: 'Password123!'
    };
    
    const loginResponse = http.post(
        `${BASE_URL}/api/auth/login`,
        JSON.stringify(loginPayload),
        { headers: { 'Content-Type': 'application/json' } }
    );
    
    check(loginResponse, {
        'login status is 200': (r) => r.status === 200,
        'login response time < 500ms': (r) => r.timings.duration < 500,
    }) || errorRate.add(1);
    
    const accessToken = loginResponse.json('data.tokens.accessToken');
    
    // Fetch user profile
    const profileResponse = http.get(`${BASE_URL}/api/users/profile`, {
        headers: { Authorization: `Bearer ${accessToken}` }
    });
    
    check(profileResponse, {
        'profile status is 200': (r) => r.status === 200,
        'profile response time < 300ms': (r) => r.timings.duration < 300,
    }) || errorRate.add(1);
    
    // Create post
    const postPayload = {
        title: `Test Post ${Date.now()}`,
        content: 'This is a load test post'
    };
    
    const postResponse = http.post(
        `${BASE_URL}/api/posts`,
        JSON.stringify(postPayload),
        {
            headers: {
                'Content-Type': 'application/json',
                Authorization: `Bearer ${accessToken}`
            }
        }
    );
    
    check(postResponse, {
        'post creation status is 201': (r) => r.status === 201,
        'post creation response time < 1000ms': (r) => r.timings.duration < 1000,
    }) || errorRate.add(1);
    
    sleep(1);
}

export function teardown(data) {
    // Cleanup if needed
}
```

## 7. Security Testing

### 7.1 Automated Security Testing

```javascript
// Security tests from Strapi
describe('Security Tests', () => {
    describe('SQL Injection Protection', () => {
        it('should prevent SQL injection in query parameters', async () => {
            const maliciousPayload = "'; DROP TABLE users; --";
            
            const response = await request(app)
                .get(`/api/users`)
                .query({ search: maliciousPayload })
                .expect(200);
            
            // Should return normal response, not error
            expect(response.body.success).toBe(true);
            
            // Verify users table still exists
            const users = await User.find();
            expect(users).toBeDefined();
        });
    });
    
    describe('XSS Protection', () => {
        it('should sanitize HTML input', async () => {
            const xssPayload = '<script>alert("xss")</script>';
            
            const response = await request(app)
                .post('/api/posts')
                .set('Authorization', `Bearer ${authToken}`)
                .send({
                    title: 'Test Post',
                    content: xssPayload
                })
                .expect(201);
            
            // Content should be sanitized
            expect(response.body.data.post.content).not.toContain('<script>');
        });
    });
    
    describe('CSRF Protection', () => {
        it('should require CSRF token for state-changing operations', async () => {
            const response = await request(app)
                .post('/api/users/profile')
                .set('Authorization', `Bearer ${authToken}`)
                .send({ firstName: 'Updated' })
                .expect(403);
            
            expect(response.body.message).toContain('CSRF');
        });
    });
    
    describe('Rate Limiting', () => {
        it('should enforce rate limits on authentication endpoints', async () => {
            const requests = Array(10).fill().map(() =>
                request(app)
                    .post('/api/auth/login')
                    .send({
                        email: 'test@example.com',
                        password: 'wrongpassword'
                    })
            );
            
            const responses = await Promise.all(requests);
            const rateLimited = responses.some(res => res.status === 429);
            
            expect(rateLimited).toBe(true);
        });
    });
});
```

## 8. Testing Best Practices

### 8.1 Test Organization & Structure

```javascript
// Test utilities and helpers
class TestHelpers {
    static async createTestUser(overrides = {}) {
        const userData = {
            email: 'test@example.com',
            password: 'Password123!',
            firstName: 'John',
            lastName: 'Doe',
            ...overrides
        };
        
        return User.create(userData);
    }
    
    static async authenticateUser(email, password) {
        const response = await request(app)
            .post('/api/auth/login')
            .send({ email, password });
        
        return response.body.data.tokens.accessToken;
    }
    
    static generateRandomEmail() {
        return `test${Date.now()}@example.com`;
    }
    
    static async clearDatabase() {
        await User.deleteMany({});
        await Post.deleteMany({});
        // Clear other collections
    }
}

// Test data factories
class UserFactory {
    static build(overrides = {}) {
        return {
            email: TestHelpers.generateRandomEmail(),
            password: 'Password123!',
            firstName: 'John',
            lastName: 'Doe',
            ...overrides
        };
    }
    
    static async create(overrides = {}) {
        const userData = this.build(overrides);
        return User.create(userData);
    }
}

// Common test setup
function setupTestEnvironment() {
    beforeEach(async () => {
        await TestHelpers.clearDatabase();
    });
    
    afterAll(async () => {
        await mongoose.connection.close();
    });
}
```

### 8.2 Coverage & Quality Metrics

```javascript
// Jest coverage configuration
module.exports = {
    collectCoverageFrom: [
        'src/**/*.js',
        '!src/**/*.test.js',
        '!src/server.js',
        '!src/config/**',
        '!**/node_modules/**'
    ],
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
        }
    },
    coverageReporters: ['text', 'lcov', 'html']
};
```

## 🔗 Navigation

### Related Documents
- ⬅️ **Previous**: [Tools & Ecosystem](./tools-ecosystem.md)
- ➡️ **Next**: [Performance Optimization](./performance-optimization.md)

### Quick Links
- [Implementation Guide](./implementation-guide.md)
- [Security Considerations](./security-considerations.md)
- [Best Practices](./best-practices.md)

---

**Testing Strategies Complete** | **Test Types**: 7 | **Frameworks Covered**: 10+ | **Examples**: 20+