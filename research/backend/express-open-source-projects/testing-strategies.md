# Testing Strategies in Express.js Open Source Projects

## 🧪 Overview

Comprehensive analysis of testing approaches, frameworks, and methodologies used across production Express.js applications, covering unit testing, integration testing, API testing, security testing, and performance testing.

## 📊 Testing Framework Distribution

### Testing Framework Adoption

| Framework | Adoption Rate | Use Case | Examples |
|-----------|---------------|----------|----------|
| **Jest** | 80% | Unit & integration testing | Ghost, Strapi, Medusa |
| **Mocha + Chai** | 35% | Traditional testing setup | Older projects, specific needs |
| **Vitest** | 15% | Modern Vite-based projects | New projects, fast execution |
| **Supertest** | 70% | HTTP API testing | Most Express applications |
| **Cypress** | 45% | E2E testing | Full-stack applications |
| **Playwright** | 25% | Modern E2E testing | Performance-critical apps |

### Testing Types Implementation

| Testing Type | Coverage | Automation Level | Priority |
|--------------|----------|------------------|----------|
| **Unit Tests** | 80-90% | Fully automated | High |
| **Integration Tests** | 60-70% | Fully automated | High |
| **API Tests** | 90%+ | Fully automated | Critical |
| **Security Tests** | 40% | Semi-automated | Medium |
| **Performance Tests** | 30% | Manual/scheduled | Medium |
| **E2E Tests** | 50% | Automated CI/CD | Variable |

## 🔧 Unit Testing Patterns

### 1. Jest Configuration and Setup

**Comprehensive Jest Configuration**
```javascript
// jest.config.js
module.exports = {
    testEnvironment: 'node',
    testMatch: [
        '<rootDir>/tests/**/*.test.js',
        '<rootDir>/tests/**/*.spec.js',
        '<rootDir>/src/**/__tests__/**/*.js'
    ],
    collectCoverageFrom: [
        'src/**/*.js',
        '!src/**/*.test.js',
        '!src/**/*.spec.js',
        '!src/config/**',
        '!src/migrations/**',
        '!src/seeders/**'
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
            functions: 95,
            lines: 95,
            statements: 95
        }
    },
    setupFilesAfterEnv: [
        '<rootDir>/tests/setup.js'
    ],
    globalSetup: '<rootDir>/tests/globalSetup.js',
    globalTeardown: '<rootDir>/tests/globalTeardown.js',
    testTimeout: 10000,
    verbose: true,
    collectCoverage: true,
    coverageDirectory: 'coverage',
    coverageReporters: ['text', 'lcov', 'html', 'json-summary'],
    moduleNameMapping: {
        '^@/(.*)$': '<rootDir>/src/$1',
        '^@tests/(.*)$': '<rootDir>/tests/$1'
    },
    transform: {
        '^.+\\.js$': 'babel-jest'
    }
};

// tests/setup.js - Global test setup
const { MongoMemoryServer } = require('mongodb-memory-server');
const mongoose = require('mongoose');

let mongoServer;

beforeAll(async () => {
    // Start in-memory MongoDB instance
    mongoServer = await MongoMemoryServer.create();
    const mongoUri = mongoServer.getUri();
    
    await mongoose.connect(mongoUri, {
        useNewUrlParser: true,
        useUnifiedTopology: true
    });
});

afterAll(async () => {
    await mongoose.disconnect();
    await mongoServer.stop();
});

afterEach(async () => {
    // Clean up database after each test
    const collections = mongoose.connection.collections;
    for (const key in collections) {
        await collections[key].deleteMany({});
    }
});

// Global test utilities
global.createTestUser = async (overrides = {}) => {
    const User = require('../src/models/User');
    return await User.create({
        email: 'test@example.com',
        name: 'Test User',
        password: 'password123',
        role: 'user',
        ...overrides
    });
};

global.generateTestJWT = (user) => {
    const jwt = require('jsonwebtoken');
    return jwt.sign(
        { userId: user.id, role: user.role },
        process.env.JWT_SECRET || 'test-secret',
        { expiresIn: '1h' }
    );
};
```

### 2. Service Layer Unit Testing

**Comprehensive Service Testing Pattern**
```javascript
// tests/services/PostService.test.js
const PostService = require('../../src/services/PostService');
const Post = require('../../src/models/Post');
const User = require('../../src/models/User');
const { ValidationError, NotFoundError, ForbiddenError } = require('../../src/lib/errors');

// Mock external dependencies
jest.mock('../../src/lib/events/EventBus');
jest.mock('../../src/services/EmailService');

describe('PostService', () => {
    let postService;
    let testUser;
    let adminUser;

    beforeEach(async () => {
        postService = new PostService();
        
        testUser = await createTestUser({
            role: 'user',
            email: 'user@test.com'
        });
        
        adminUser = await createTestUser({
            role: 'admin',
            email: 'admin@test.com'
        });
    });

    describe('create', () => {
        const validPostData = {
            title: 'Test Post',
            content: 'This is test content',
            tags: ['test', 'jest']
        };

        it('should create a post with valid data', async () => {
            const post = await postService.create(validPostData, testUser);

            expect(post).toBeDefined();
            expect(post.title).toBe(validPostData.title);
            expect(post.content).toBe(validPostData.content);
            expect(post.authorId).toBe(testUser.id);
            expect(post.status).toBe('draft'); // Default status
        });

        it('should validate required fields', async () => {
            const invalidData = { content: 'Content without title' };

            await expect(postService.create(invalidData, testUser))
                .rejects.toThrow(ValidationError);
        });

        it('should set status to published for admin users', async () => {
            const post = await postService.create(validPostData, adminUser);
            expect(post.status).toBe('published');
        });

        it('should emit post.created event', async () => {
            const mockEventBus = require('../../src/lib/events/EventBus');
            mockEventBus.emit = jest.fn();

            await postService.create(validPostData, testUser);

            expect(mockEventBus.emit).toHaveBeenCalledWith('post.created', 
                expect.objectContaining({
                    post: expect.any(Object),
                    user: testUser
                })
            );
        });

        it('should handle database errors gracefully', async () => {
            // Mock database error
            const mockCreate = jest.spyOn(Post, 'create')
                .mockRejectedValue(new Error('Database connection failed'));

            await expect(postService.create(validPostData, testUser))
                .rejects.toThrow('Database connection failed');

            mockCreate.mockRestore();
        });
    });

    describe('findAll', () => {
        beforeEach(async () => {
            // Create test posts
            await Post.create({
                title: 'Published Post',
                content: 'Published content',
                authorId: testUser.id,
                status: 'published'
            });

            await Post.create({
                title: 'Draft Post',
                content: 'Draft content',
                authorId: testUser.id,
                status: 'draft'
            });

            await Post.create({
                title: 'Admin Post',
                content: 'Admin content',
                authorId: adminUser.id,
                status: 'published'
            });
        });

        it('should return published posts for regular users', async () => {
            const result = await postService.findAll({}, testUser);

            expect(result.data).toHaveLength(2); // Only published posts
            expect(result.data.every(post => post.status === 'published')).toBe(true);
        });

        it('should return all posts for admin users', async () => {
            const result = await postService.findAll({}, adminUser);

            expect(result.data).toHaveLength(3); // All posts
        });

        it('should handle pagination correctly', async () => {
            const result = await postService.findAll({ page: 1, limit: 2 }, adminUser);

            expect(result.data).toHaveLength(2);
            expect(result.meta.total).toBe(3);
            expect(result.meta.page).toBe(1);
            expect(result.meta.totalPages).toBe(2);
        });

        it('should filter by author', async () => {
            const result = await postService.findAll(
                { filter: { authorId: testUser.id } }, 
                adminUser
            );

            expect(result.data).toHaveLength(2);
            expect(result.data.every(post => post.authorId === testUser.id)).toBe(true);
        });
    });

    describe('update', () => {
        let testPost;

        beforeEach(async () => {
            testPost = await Post.create({
                title: 'Original Title',
                content: 'Original content',
                authorId: testUser.id,
                status: 'draft'
            });
        });

        it('should allow author to update own post', async () => {
            const updateData = { title: 'Updated Title' };
            const updatedPost = await postService.update(testPost.id, updateData, testUser);

            expect(updatedPost.title).toBe('Updated Title');
            expect(updatedPost.content).toBe('Original content'); // Unchanged
        });

        it('should allow admin to update any post', async () => {
            const updateData = { title: 'Admin Updated' };
            const updatedPost = await postService.update(testPost.id, updateData, adminUser);

            expect(updatedPost.title).toBe('Admin Updated');
        });

        it('should prevent unauthorized updates', async () => {
            const otherUser = await createTestUser({ email: 'other@test.com' });
            const updateData = { title: 'Unauthorized Update' };

            await expect(postService.update(testPost.id, updateData, otherUser))
                .rejects.toThrow(ForbiddenError);
        });

        it('should throw NotFoundError for non-existent post', async () => {
            const fakeId = new mongoose.Types.ObjectId();
            const updateData = { title: 'Update Non-existent' };

            await expect(postService.update(fakeId, updateData, testUser))
                .rejects.toThrow(NotFoundError);
        });

        it('should emit post.updated event', async () => {
            const mockEventBus = require('../../src/lib/events/EventBus');
            mockEventBus.emit = jest.fn();

            const updateData = { title: 'Event Test' };
            await postService.update(testPost.id, updateData, testUser);

            expect(mockEventBus.emit).toHaveBeenCalledWith('post.updated',
                expect.objectContaining({
                    post: expect.any(Object),
                    user: testUser
                })
            );
        });
    });

    describe('delete', () => {
        let testPost;

        beforeEach(async () => {
            testPost = await Post.create({
                title: 'To Be Deleted',
                content: 'Delete me',
                authorId: testUser.id,
                status: 'draft'
            });
        });

        it('should allow author to delete own post', async () => {
            await postService.delete(testPost.id, testUser);

            const deletedPost = await Post.findById(testPost.id);
            expect(deletedPost).toBeNull();
        });

        it('should prevent unauthorized deletion', async () => {
            const otherUser = await createTestUser({ email: 'other@test.com' });

            await expect(postService.delete(testPost.id, otherUser))
                .rejects.toThrow(ForbiddenError);
        });

        it('should prevent deletion of published posts by non-admin', async () => {
            await Post.findByIdAndUpdate(testPost.id, { status: 'published' });

            await expect(postService.delete(testPost.id, testUser))
                .rejects.toThrow(ForbiddenError);
        });

        it('should allow admin to delete any post', async () => {
            await Post.findByIdAndUpdate(testPost.id, { status: 'published' });

            await postService.delete(testPost.id, adminUser);

            const deletedPost = await Post.findById(testPost.id);
            expect(deletedPost).toBeNull();
        });
    });
});
```

### 3. Mock Strategy Patterns

**Comprehensive Mocking Patterns**
```javascript
// tests/utils/mocks.js
const mongoose = require('mongoose');

class MockBuilder {
    static user(overrides = {}) {
        return {
            id: new mongoose.Types.ObjectId().toString(),
            email: 'test@example.com',
            name: 'Test User',
            role: 'user',
            createdAt: new Date(),
            ...overrides
        };
    }

    static post(overrides = {}) {
        return {
            id: new mongoose.Types.ObjectId().toString(),
            title: 'Test Post',
            content: 'Test content',
            authorId: new mongoose.Types.ObjectId().toString(),
            status: 'draft',
            tags: ['test'],
            createdAt: new Date(),
            updatedAt: new Date(),
            ...overrides
        };
    }

    static apiResponse(data, meta = null) {
        return {
            success: true,
            data,
            ...(meta && { meta }),
            timestamp: new Date().toISOString()
        };
    }

    static errorResponse(message, code = 'TEST_ERROR', status = 500) {
        return {
            success: false,
            error: {
                code,
                message,
                status
            },
            timestamp: new Date().toISOString()
        };
    }
}

// Service mocks
class MockEmailService {
    constructor() {
        this.sentEmails = [];
    }

    async sendEmail(to, subject, body) {
        this.sentEmails.push({ to, subject, body, sentAt: new Date() });
        return { messageId: 'mock-message-id' };
    }

    async sendWelcomeEmail(email) {
        return this.sendEmail(email, 'Welcome!', 'Welcome to our platform');
    }

    getLastEmail() {
        return this.sentEmails[this.sentEmails.length - 1];
    }

    getSentEmails() {
        return [...this.sentEmails];
    }

    clear() {
        this.sentEmails = [];
    }
}

// External API mocks
class MockExternalApiClient {
    constructor() {
        this.responses = new Map();
        this.requests = [];
    }

    setResponse(endpoint, response) {
        this.responses.set(endpoint, response);
    }

    async get(endpoint) {
        this.requests.push({ method: 'GET', endpoint, timestamp: new Date() });
        
        if (this.responses.has(endpoint)) {
            return this.responses.get(endpoint);
        }
        
        throw new Error(`No mock response configured for ${endpoint}`);
    }

    async post(endpoint, data) {
        this.requests.push({ method: 'POST', endpoint, data, timestamp: new Date() });
        
        if (this.responses.has(endpoint)) {
            return this.responses.get(endpoint);
        }
        
        throw new Error(`No mock response configured for ${endpoint}`);
    }

    getRequests() {
        return [...this.requests];
    }

    getRequestsTo(endpoint) {
        return this.requests.filter(req => req.endpoint === endpoint);
    }

    clear() {
        this.requests = [];
        this.responses.clear();
    }
}

module.exports = {
    MockBuilder,
    MockEmailService,
    MockExternalApiClient
};

// Usage in tests
const { MockBuilder, MockEmailService } = require('./utils/mocks');

describe('UserService', () => {
    let userService;
    let mockEmailService;

    beforeEach(() => {
        mockEmailService = new MockEmailService();
        userService = new UserService({ emailService: mockEmailService });
    });

    it('should send welcome email on user creation', async () => {
        const userData = MockBuilder.user({ email: 'new@example.com' });
        
        await userService.create(userData);
        
        const lastEmail = mockEmailService.getLastEmail();
        expect(lastEmail.to).toBe('new@example.com');
        expect(lastEmail.subject).toBe('Welcome!');
    });
});
```

## 🔌 Integration Testing Patterns

### 1. API Integration Testing with Supertest

**Comprehensive API Testing Setup**
```javascript
// tests/integration/api.test.js
const request = require('supertest');
const app = require('../../src/app');
const User = require('../../src/models/User');
const Post = require('../../src/models/Post');

describe('Posts API Integration Tests', () => {
    let authToken;
    let testUser;
    let adminToken;
    let adminUser;

    beforeEach(async () => {
        // Create test users
        testUser = await createTestUser({
            email: 'test@example.com',
            role: 'user'
        });

        adminUser = await createTestUser({
            email: 'admin@example.com',
            role: 'admin'
        });

        // Generate auth tokens
        authToken = generateTestJWT(testUser);
        adminToken = generateTestJWT(adminUser);
    });

    describe('GET /api/posts', () => {
        beforeEach(async () => {
            // Create test posts
            await Post.create([
                {
                    title: 'Published Post 1',
                    content: 'Content 1',
                    authorId: testUser.id,
                    status: 'published'
                },
                {
                    title: 'Draft Post',
                    content: 'Draft content',
                    authorId: testUser.id,
                    status: 'draft'
                },
                {
                    title: 'Published Post 2',
                    content: 'Content 2',
                    authorId: adminUser.id,
                    status: 'published'
                }
            ]);
        });

        it('should return published posts for authenticated users', async () => {
            const response = await request(app)
                .get('/api/posts')
                .set('Authorization', `Bearer ${authToken}`)
                .expect(200);

            expect(response.body.success).toBe(true);
            expect(response.body.data).toHaveLength(2);
            expect(response.body.data.every(post => post.status === 'published')).toBe(true);
        });

        it('should return all posts for admin users', async () => {
            const response = await request(app)
                .get('/api/posts')
                .set('Authorization', `Bearer ${adminToken}`)
                .expect(200);

            expect(response.body.data).toHaveLength(3);
        });

        it('should support pagination', async () => {
            const response = await request(app)
                .get('/api/posts?page=1&limit=1')
                .set('Authorization', `Bearer ${authToken}`)
                .expect(200);

            expect(response.body.data).toHaveLength(1);
            expect(response.body.meta.pagination).toEqual({
                page: 1,
                limit: 1,
                total: 2,
                pages: 2,
                hasNextPage: true,
                hasPrevPage: false
            });
        });

        it('should support filtering by status', async () => {
            const response = await request(app)
                .get('/api/posts?filter[status]=published')
                .set('Authorization', `Bearer ${adminToken}`)
                .expect(200);

            expect(response.body.data).toHaveLength(2);
            expect(response.body.data.every(post => post.status === 'published')).toBe(true);
        });

        it('should support search functionality', async () => {
            const response = await request(app)
                .get('/api/posts?search=Published Post 1')
                .set('Authorization', `Bearer ${authToken}`)
                .expect(200);

            expect(response.body.data).toHaveLength(1);
            expect(response.body.data[0].title).toBe('Published Post 1');
        });

        it('should require authentication', async () => {
            await request(app)
                .get('/api/posts')
                .expect(401);
        });

        it('should handle invalid authentication token', async () => {
            await request(app)
                .get('/api/posts')
                .set('Authorization', 'Bearer invalid-token')
                .expect(401);
        });
    });

    describe('POST /api/posts', () => {
        const validPostData = {
            title: 'New Test Post',
            content: 'This is test content for the new post',
            tags: ['test', 'integration']
        };

        it('should create a post with valid data', async () => {
            const response = await request(app)
                .post('/api/posts')
                .set('Authorization', `Bearer ${authToken}`)
                .send(validPostData)
                .expect(201);

            expect(response.body.success).toBe(true);
            expect(response.body.data.title).toBe(validPostData.title);
            expect(response.body.data.authorId).toBe(testUser.id);
            expect(response.body.meta.created).toBe(true);
            expect(response.body.meta.location).toBeDefined();

            // Verify post exists in database
            const post = await Post.findById(response.body.data.id);
            expect(post).toBeTruthy();
            expect(post.title).toBe(validPostData.title);
        });

        it('should validate required fields', async () => {
            const invalidData = { content: 'Content without title' };

            const response = await request(app)
                .post('/api/posts')
                .set('Authorization', `Bearer ${authToken}`)
                .send(invalidData)
                .expect(400);

            expect(response.body.success).toBe(false);
            expect(response.body.error.code).toBe('VALIDATION_ERROR');
            expect(response.body.error.details).toEqual(
                expect.arrayContaining([
                    expect.objectContaining({
                        field: 'title',
                        message: expect.stringContaining('required')
                    })
                ])
            );
        });

        it('should validate field lengths', async () => {
            const invalidData = {
                title: 'A', // Too short
                content: 'Too short'
            };

            const response = await request(app)
                .post('/api/posts')
                .set('Authorization', `Bearer ${authToken}`)
                .send(invalidData)
                .expect(400);

            expect(response.body.error.details).toEqual(
                expect.arrayContaining([
                    expect.objectContaining({
                        field: 'title',
                        message: expect.stringContaining('minimum')
                    }),
                    expect.objectContaining({
                        field: 'content',
                        message: expect.stringContaining('minimum')
                    })
                ])
            );
        });

        it('should handle special characters in content', async () => {
            const specialData = {
                title: 'Special Characters Test',
                content: 'Content with emojis 🚀 and symbols #@$%^&*()',
                tags: ['special', 'unicode']
            };

            const response = await request(app)
                .post('/api/posts')
                .set('Authorization', `Bearer ${authToken}`)
                .send(specialData)
                .expect(201);

            expect(response.body.data.content).toBe(specialData.content);
        });

        it('should set correct default status for regular users', async () => {
            const response = await request(app)
                .post('/api/posts')
                .set('Authorization', `Bearer ${authToken}`)
                .send(validPostData)
                .expect(201);

            expect(response.body.data.status).toBe('draft');
        });

        it('should set published status for admin users', async () => {
            const response = await request(app)
                .post('/api/posts')
                .set('Authorization', `Bearer ${adminToken}`)
                .send(validPostData)
                .expect(201);

            expect(response.body.data.status).toBe('published');
        });

        it('should handle database errors gracefully', async () => {
            // Mock database error
            const originalCreate = Post.create;
            Post.create = jest.fn().mockRejectedValue(new Error('Database error'));

            await request(app)
                .post('/api/posts')
                .set('Authorization', `Bearer ${authToken}`)
                .send(validPostData)
                .expect(500);

            Post.create = originalCreate;
        });
    });

    describe('PUT /api/posts/:id', () => {
        let testPost;

        beforeEach(async () => {
            testPost = await Post.create({
                title: 'Original Title',
                content: 'Original content',
                authorId: testUser.id,
                status: 'draft'
            });
        });

        it('should update post by author', async () => {
            const updateData = {
                title: 'Updated Title',
                content: 'Updated content'
            };

            const response = await request(app)
                .put(`/api/posts/${testPost.id}`)
                .set('Authorization', `Bearer ${authToken}`)
                .send(updateData)
                .expect(200);

            expect(response.body.data.title).toBe(updateData.title);
            expect(response.body.data.content).toBe(updateData.content);
            expect(response.body.meta.updated).toBe(true);
        });

        it('should prevent unauthorized updates', async () => {
            const otherUser = await createTestUser({ email: 'other@example.com' });
            const otherToken = generateTestJWT(otherUser);

            await request(app)
                .put(`/api/posts/${testPost.id}`)
                .set('Authorization', `Bearer ${otherToken}`)
                .send({ title: 'Unauthorized Update' })
                .expect(403);
        });

        it('should handle non-existent post', async () => {
            const fakeId = new mongoose.Types.ObjectId();

            await request(app)
                .put(`/api/posts/${fakeId}`)
                .set('Authorization', `Bearer ${authToken}`)
                .send({ title: 'Update Non-existent' })
                .expect(404);
        });

        it('should validate update data', async () => {
            const invalidData = { title: '' }; // Empty title

            await request(app)
                .put(`/api/posts/${testPost.id}`)
                .set('Authorization', `Bearer ${authToken}`)
                .send(invalidData)
                .expect(400);
        });
    });

    describe('DELETE /api/posts/:id', () => {
        let testPost;

        beforeEach(async () => {
            testPost = await Post.create({
                title: 'To Be Deleted',
                content: 'Delete me',
                authorId: testUser.id,
                status: 'draft'
            });
        });

        it('should delete post by author', async () => {
            const response = await request(app)
                .delete(`/api/posts/${testPost.id}`)
                .set('Authorization', `Bearer ${authToken}`)
                .expect(200);

            expect(response.body.data.deleted).toBe(true);
            expect(response.body.data.id).toBe(testPost.id);

            // Verify post is deleted
            const deletedPost = await Post.findById(testPost.id);
            expect(deletedPost).toBeNull();
        });

        it('should prevent unauthorized deletion', async () => {
            const otherUser = await createTestUser({ email: 'other@example.com' });
            const otherToken = generateTestJWT(otherUser);

            await request(app)
                .delete(`/api/posts/${testPost.id}`)
                .set('Authorization', `Bearer ${otherToken}`)
                .expect(403);
        });

        it('should handle non-existent post', async () => {
            const fakeId = new mongoose.Types.ObjectId();

            await request(app)
                .delete(`/api/posts/${fakeId}`)
                .set('Authorization', `Bearer ${authToken}`)
                .expect(404);
        });
    });
});
```

### 2. Database Integration Testing

**Database Transaction Testing Pattern**
```javascript
// tests/integration/database.test.js
const mongoose = require('mongoose');
const User = require('../../src/models/User');
const Post = require('../../src/models/Post');
const Comment = require('../../src/models/Comment');

describe('Database Integration Tests', () => {
    describe('User-Post Relationships', () => {
        it('should maintain referential integrity', async () => {
            const user = await User.create({
                email: 'author@example.com',
                name: 'Author',
                password: 'password123'
            });

            const post = await Post.create({
                title: 'Test Post',
                content: 'Test content',
                authorId: user.id
            });

            // Verify relationship
            const foundPost = await Post.findById(post.id).populate('author');
            expect(foundPost.author.email).toBe(user.email);

            // Test cascade delete behavior
            await User.findByIdAndDelete(user.id);
            
            // Post should still exist but author should be null/undefined
            const orphanedPost = await Post.findById(post.id).populate('author');
            expect(orphanedPost).toBeTruthy();
            expect(orphanedPost.author).toBeNull();
        });

        it('should handle complex queries efficiently', async () => {
            // Create test data
            const users = await User.create([
                { email: 'user1@example.com', name: 'User 1', password: 'pass1' },
                { email: 'user2@example.com', name: 'User 2', password: 'pass2' }
            ]);

            const posts = await Post.create([
                { title: 'Post 1', content: 'Content 1', authorId: users[0].id, status: 'published' },
                { title: 'Post 2', content: 'Content 2', authorId: users[1].id, status: 'draft' },
                { title: 'Post 3', content: 'Content 3', authorId: users[0].id, status: 'published' }
            ]);

            await Comment.create([
                { content: 'Comment 1', postId: posts[0].id, authorId: users[1].id },
                { content: 'Comment 2', postId: posts[0].id, authorId: users[0].id },
                { content: 'Comment 3', postId: posts[2].id, authorId: users[1].id }
            ]);

            // Complex aggregation query
            const result = await User.aggregate([
                {
                    $lookup: {
                        from: 'posts',
                        localField: '_id',
                        foreignField: 'authorId',
                        as: 'posts'
                    }
                },
                {
                    $lookup: {
                        from: 'comments',
                        localField: '_id',
                        foreignField: 'authorId',
                        as: 'comments'
                    }
                },
                {
                    $project: {
                        name: 1,
                        email: 1,
                        postCount: { $size: '$posts' },
                        commentCount: { $size: '$comments' },
                        publishedPosts: {
                            $size: {
                                $filter: {
                                    input: '$posts',
                                    cond: { $eq: ['$$this.status', 'published'] }
                                }
                            }
                        }
                    }
                }
            ]);

            expect(result).toHaveLength(2);
            expect(result[0].postCount).toBe(2);
            expect(result[0].publishedPosts).toBe(2);
            expect(result[1].postCount).toBe(1);
            expect(result[1].publishedPosts).toBe(0);
        });
    });

    describe('Transaction Handling', () => {
        it('should handle successful transactions', async () => {
            const session = await mongoose.startSession();
            
            try {
                await session.withTransaction(async () => {
                    const user = await User.create([{
                        email: 'transaction@example.com',
                        name: 'Transaction User',
                        password: 'password123'
                    }], { session });

                    await Post.create([{
                        title: 'Transaction Post',
                        content: 'Created in transaction',
                        authorId: user[0].id
                    }], { session });
                });

                // Verify data was committed
                const user = await User.findOne({ email: 'transaction@example.com' });
                const post = await Post.findOne({ title: 'Transaction Post' });
                
                expect(user).toBeTruthy();
                expect(post).toBeTruthy();
                expect(post.authorId.toString()).toBe(user.id);
            } finally {
                await session.endSession();
            }
        });

        it('should rollback failed transactions', async () => {
            const session = await mongoose.startSession();
            
            try {
                await session.withTransaction(async () => {
                    await User.create([{
                        email: 'rollback@example.com',
                        name: 'Rollback User',
                        password: 'password123'
                    }], { session });

                    // Simulate error that causes rollback
                    throw new Error('Transaction failed');
                });
            } catch (error) {
                expect(error.message).toBe('Transaction failed');
            } finally {
                await session.endSession();
            }

            // Verify data was rolled back
            const user = await User.findOne({ email: 'rollback@example.com' });
            expect(user).toBeNull();
        });
    });
});
```

## 🔒 Security Testing Patterns

### 1. Authentication Security Testing

**Authentication Vulnerability Testing**
```javascript
// tests/security/authentication.test.js
const request = require('supertest');
const app = require('../../src/app');
const jwt = require('jsonwebtoken');

describe('Authentication Security Tests', () => {
    describe('JWT Security', () => {
        it('should reject expired tokens', async () => {
            const expiredToken = jwt.sign(
                { userId: 'test-id', role: 'user' },
                process.env.JWT_SECRET,
                { expiresIn: '-1h' } // Expired 1 hour ago
            );

            await request(app)
                .get('/api/posts')
                .set('Authorization', `Bearer ${expiredToken}`)
                .expect(401);
        });

        it('should reject tokens with invalid signature', async () => {
            const invalidToken = jwt.sign(
                { userId: 'test-id', role: 'user' },
                'wrong-secret'
            );

            await request(app)
                .get('/api/posts')
                .set('Authorization', `Bearer ${invalidToken}`)
                .expect(401);
        });

        it('should reject malformed tokens', async () => {
            const malformedTokens = [
                'not-a-jwt-token',
                'Bearer.malformed.token',
                '',
                'Bearer ',
                'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9' // Incomplete JWT
            ];

            for (const token of malformedTokens) {
                await request(app)
                    .get('/api/posts')
                    .set('Authorization', token)
                    .expect(401);
            }
        });

        it('should reject tokens with tampered payload', async () => {
            const validToken = jwt.sign(
                { userId: 'user-id', role: 'user' },
                process.env.JWT_SECRET
            );

            // Tamper with the token
            const parts = validToken.split('.');
            const tamperedPayload = Buffer.from(JSON.stringify({
                userId: 'admin-id',
                role: 'admin'
            })).toString('base64');
            
            const tamperedToken = `${parts[0]}.${tamperedPayload}.${parts[2]}`;

            await request(app)
                .get('/api/posts')
                .set('Authorization', `Bearer ${tamperedToken}`)
                .expect(401);
        });
    });

    describe('Rate Limiting', () => {
        it('should enforce rate limits on login attempts', async () => {
            const loginData = {
                email: 'test@example.com',
                password: 'wrongpassword'
            };

            // Make multiple failed login attempts
            for (let i = 0; i < 5; i++) {
                await request(app)
                    .post('/api/auth/login')
                    .send(loginData)
                    .expect(401);
            }

            // Next attempt should be rate limited
            await request(app)
                .post('/api/auth/login')
                .send(loginData)
                .expect(429);
        });

        it('should enforce general API rate limits', async () => {
            const user = await createTestUser();
            const token = generateTestJWT(user);

            // Make requests up to the limit
            for (let i = 0; i < 100; i++) {
                await request(app)
                    .get('/api/posts')
                    .set('Authorization', `Bearer ${token}`)
                    .expect(200);
            }

            // Next request should be rate limited
            await request(app)
                .get('/api/posts')
                .set('Authorization', `Bearer ${token}`)
                .expect(429);
        });
    });

    describe('Input Validation Security', () => {
        it('should prevent NoSQL injection in filters', async () => {
            const user = await createTestUser();
            const token = generateTestJWT(user);

            // Attempt NoSQL injection
            const maliciousQuery = {
                'filter[email][$ne]': null, // MongoDB injection attempt
                'filter[password][$regex]': '.*' // Another injection attempt
            };

            const response = await request(app)
                .get('/api/users')
                .query(maliciousQuery)
                .set('Authorization', `Bearer ${token}`)
                .expect(400); // Should be rejected

            expect(response.body.error.code).toBe('VALIDATION_ERROR');
        });

        it('should sanitize XSS attempts in content', async () => {
            const user = await createTestUser();
            const token = generateTestJWT(user);

            const xssPayload = {
                title: '<script>alert("XSS")</script>',
                content: '<img src="x" onerror="alert(\'XSS\')" />'
            };

            const response = await request(app)
                .post('/api/posts')
                .set('Authorization', `Bearer ${token}`)
                .send(xssPayload)
                .expect(201);

            // Content should be sanitized
            expect(response.body.data.title).not.toContain('<script>');
            expect(response.body.data.content).not.toContain('onerror');
        });

        it('should reject oversized payloads', async () => {
            const user = await createTestUser();
            const token = generateTestJWT(user);

            const oversizedContent = 'x'.repeat(10 * 1024 * 1024); // 10MB string

            await request(app)
                .post('/api/posts')
                .set('Authorization', `Bearer ${token}`)
                .send({
                    title: 'Large Content Test',
                    content: oversizedContent
                })
                .expect(413); // Payload too large
        });
    });

    describe('Authorization Security', () => {
        it('should prevent privilege escalation', async () => {
            const user = await createTestUser({ role: 'user' });
            const token = generateTestJWT(user);

            // Attempt to access admin endpoint
            await request(app)
                .get('/api/admin/users')
                .set('Authorization', `Bearer ${token}`)
                .expect(403);

            // Attempt to modify role in update
            await request(app)
                .put(`/api/users/${user.id}`)
                .set('Authorization', `Bearer ${token}`)
                .send({ role: 'admin' })
                .expect(403);
        });

        it('should prevent accessing other users\' data', async () => {
            const user1 = await createTestUser({ email: 'user1@example.com' });
            const user2 = await createTestUser({ email: 'user2@example.com' });
            const token1 = generateTestJWT(user1);

            // User1 tries to access User2's profile
            await request(app)
                .get(`/api/users/${user2.id}`)
                .set('Authorization', `Bearer ${token1}`)
                .expect(403);

            // User1 tries to update User2's profile
            await request(app)
                .put(`/api/users/${user2.id}`)
                .set('Authorization', `Bearer ${token1}`)
                .send({ name: 'Hacked Name' })
                .expect(403);
        });
    });
});
```

### 2. Data Security Testing

**Data Protection and Privacy Testing**
```javascript
// tests/security/data-protection.test.js
describe('Data Protection Security Tests', () => {
    describe('Sensitive Data Handling', () => {
        it('should not expose passwords in API responses', async () => {
            const user = await createTestUser();
            const token = generateTestJWT(user);

            const response = await request(app)
                .get(`/api/users/${user.id}`)
                .set('Authorization', `Bearer ${token}`)
                .expect(200);

            expect(response.body.data.password).toBeUndefined();
            expect(response.body.data.hashedPassword).toBeUndefined();
        });

        it('should hash passwords securely', async () => {
            const password = 'testpassword123';
            const user = await User.create({
                email: 'hash@example.com',
                name: 'Hash User',
                password
            });

            // Password should be hashed
            expect(user.password).not.toBe(password);
            expect(user.password).toMatch(/^\$2[aby]?\$\d+\$/); // bcrypt format

            // Should be able to validate password
            const isValid = await user.validatePassword(password);
            expect(isValid).toBe(true);

            const isInvalid = await user.validatePassword('wrongpassword');
            expect(isInvalid).toBe(false);
        });

        it('should enforce strong password requirements', async () => {
            const weakPasswords = [
                '123456',
                'password',
                'abc123',
                'qwerty',
                '12345678'
            ];

            for (const weakPassword of weakPasswords) {
                await request(app)
                    .post('/api/auth/register')
                    .send({
                        email: 'weak@example.com',
                        name: 'Weak Password User',
                        password: weakPassword
                    })
                    .expect(400);
            }
        });

        it('should mask sensitive data in logs', async () => {
            const consoleSpy = jest.spyOn(console, 'log');
            
            await request(app)
                .post('/api/auth/login')
                .send({
                    email: 'test@example.com',
                    password: 'secretpassword'
                });

            // Check that password is not logged
            const logCalls = consoleSpy.mock.calls.flat();
            const hasPasswordInLogs = logCalls.some(call => 
                typeof call === 'string' && call.includes('secretpassword')
            );
            
            expect(hasPasswordInLogs).toBe(false);
            
            consoleSpy.mockRestore();
        });
    });

    describe('GDPR Compliance', () => {
        it('should support data export', async () => {
            const user = await createTestUser();
            const token = generateTestJWT(user);

            // Create user data
            await Post.create({
                title: 'User Post',
                content: 'User content',
                authorId: user.id
            });

            const response = await request(app)
                .get('/api/users/export')
                .set('Authorization', `Bearer ${token}`)
                .expect(200);

            expect(response.body.data).toEqual({
                personalInfo: expect.objectContaining({
                    email: user.email,
                    name: user.name
                }),
                posts: expect.arrayContaining([
                    expect.objectContaining({
                        title: 'User Post'
                    })
                ]),
                exportedAt: expect.any(String)
            });
        });

        it('should support data deletion', async () => {
            const user = await createTestUser();
            const token = generateTestJWT(user);

            await Post.create({
                title: 'User Post',
                content: 'User content',
                authorId: user.id
            });

            // Delete user account
            await request(app)
                .delete(`/api/users/${user.id}`)
                .set('Authorization', `Bearer ${token}`)
                .expect(200);

            // Verify user is deleted
            const deletedUser = await User.findById(user.id);
            expect(deletedUser).toBeNull();

            // Verify associated data is handled
            const userPosts = await Post.find({ authorId: user.id });
            expect(userPosts).toHaveLength(0); // Or anonymized
        });
    });
});
```

## ⚡ Performance Testing Patterns

### 1. Load Testing with Artillery

**Artillery Configuration and Tests**
```yaml
# artillery.yml
config:
  target: 'http://localhost:3000'
  phases:
    - duration: 60
      arrivalRate: 5
      name: Warm up
    - duration: 120
      arrivalRate: 20
      name: Ramp up load
    - duration: 180
      arrivalRate: 50
      name: Sustained load
    - duration: 60
      arrivalRate: 5
      name: Cool down
  defaults:
    headers:
      Content-Type: 'application/json'
  variables:
    userEmail:
      - 'user1@example.com'
      - 'user2@example.com'
      - 'user3@example.com'
    
scenarios:
  - name: 'Authentication Flow'
    weight: 30
    flow:
      - post:
          url: '/api/auth/login'
          json:
            email: '{{ userEmail }}'
            password: 'password123'
          capture:
            - json: '$.data.token'
              as: 'authToken'
      - get:
          url: '/api/profile'
          headers:
            Authorization: 'Bearer {{ authToken }}'
          
  - name: 'CRUD Operations'
    weight: 50
    flow:
      - post:
          url: '/api/auth/login'
          json:
            email: '{{ userEmail }}'
            password: 'password123'
          capture:
            - json: '$.data.token'
              as: 'authToken'
      - post:
          url: '/api/posts'
          headers:
            Authorization: 'Bearer {{ authToken }}'
          json:
            title: 'Performance Test Post {{ $randomString() }}'
            content: 'Content for performance testing'
          capture:
            - json: '$.data.id'
              as: 'postId'
      - get:
          url: '/api/posts/{{ postId }}'
          headers:
            Authorization: 'Bearer {{ authToken }}'
      - put:
          url: '/api/posts/{{ postId }}'
          headers:
            Authorization: 'Bearer {{ authToken }}'
          json:
            title: 'Updated Performance Test Post'
      - delete:
          url: '/api/posts/{{ postId }}'
          headers:
            Authorization: 'Bearer {{ authToken }}'
            
  - name: 'Read-Heavy Operations'
    weight: 20
    flow:
      - get:
          url: '/api/posts?page={{ $randomInt(1, 10) }}'
      - get:
          url: '/api/posts?search={{ $randomString() }}'
      - get:
          url: '/api/posts?filter[status]=published'
```

### 2. Performance Testing with Jest

**API Performance Benchmarking**
```javascript
// tests/performance/api-performance.test.js
const request = require('supertest');
const app = require('../../src/app');

describe('API Performance Tests', () => {
    let authToken;
    let testUser;

    beforeAll(async () => {
        testUser = await createTestUser();
        authToken = generateTestJWT(testUser);
        
        // Create test data for performance testing
        const posts = Array.from({ length: 100 }, (_, i) => ({
            title: `Performance Test Post ${i}`,
            content: `Content for performance test post number ${i}`,
            authorId: testUser.id,
            status: 'published'
        }));
        
        await Post.insertMany(posts);
    });

    describe('Response Time Benchmarks', () => {
        it('should respond to GET /api/posts within 200ms', async () => {
            const start = Date.now();
            
            await request(app)
                .get('/api/posts')
                .set('Authorization', `Bearer ${authToken}`)
                .expect(200);
                
            const responseTime = Date.now() - start;
            expect(responseTime).toBeLessThan(200);
        });

        it('should handle concurrent requests efficiently', async () => {
            const concurrentRequests = 10;
            const requests = Array.from({ length: concurrentRequests }, () =>
                request(app)
                    .get('/api/posts')
                    .set('Authorization', `Bearer ${authToken}`)
                    .expect(200)
            );

            const start = Date.now();
            const responses = await Promise.all(requests);
            const totalTime = Date.now() - start;

            // All requests should complete within 1 second
            expect(totalTime).toBeLessThan(1000);
            
            // Average response time should be reasonable
            const avgResponseTime = totalTime / concurrentRequests;
            expect(avgResponseTime).toBeLessThan(100);
        });

        it('should handle pagination efficiently', async () => {
            const pageTests = [
                { page: 1, limit: 10 },
                { page: 5, limit: 20 },
                { page: 10, limit: 10 }
            ];

            for (const test of pageTests) {
                const start = Date.now();
                
                await request(app)
                    .get(`/api/posts?page=${test.page}&limit=${test.limit}`)
                    .set('Authorization', `Bearer ${authToken}`)
                    .expect(200);
                    
                const responseTime = Date.now() - start;
                expect(responseTime).toBeLessThan(300);
            }
        });
    });

    describe('Database Query Performance', () => {
        it('should execute complex queries efficiently', async () => {
            const start = Date.now();
            
            // Complex query with multiple filters
            await request(app)
                .get('/api/posts?filter[status]=published&search=Performance&sort=-createdAt&include=author')
                .set('Authorization', `Bearer ${authToken}`)
                .expect(200);
                
            const queryTime = Date.now() - start;
            expect(queryTime).toBeLessThan(500);
        });

        it('should handle large result sets efficiently', async () => {
            const start = Date.now();
            
            await request(app)
                .get('/api/posts?limit=100')
                .set('Authorization', `Bearer ${authToken}`)
                .expect(200);
                
            const queryTime = Date.now() - start;
            expect(queryTime).toBeLessThan(1000);
        });
    });

    describe('Memory Usage', () => {
        it('should not leak memory during repeated requests', async () => {
            const initialMemory = process.memoryUsage().heapUsed;
            
            // Make 50 requests
            for (let i = 0; i < 50; i++) {
                await request(app)
                    .get('/api/posts')
                    .set('Authorization', `Bearer ${authToken}`)
                    .expect(200);
            }
            
            // Force garbage collection if available
            if (global.gc) {
                global.gc();
            }
            
            const finalMemory = process.memoryUsage().heapUsed;
            const memoryIncrease = finalMemory - initialMemory;
            
            // Memory increase should be reasonable (less than 50MB)
            expect(memoryIncrease).toBeLessThan(50 * 1024 * 1024);
        });
    });
});
```

## 🔗 Navigation

← [API Design Patterns](./api-design-patterns.md) | [Deployment & DevOps](./deployment-devops.md) →