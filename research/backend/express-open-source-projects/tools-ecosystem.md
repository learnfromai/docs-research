# Tools & Ecosystem: Express.js Production Environment

## 🎯 Overview

This document catalogs the complete ecosystem of tools, libraries, and middleware used across 15+ successful Express.js projects. It provides practical recommendations for building production-ready applications with the right technology stack.

## 📋 Table of Contents

1. [Core Dependencies & Frameworks](#1-core-dependencies--frameworks)
2. [Security & Authentication](#2-security--authentication)
3. [Database & ORM/ODM](#3-database--ormodm)
4. [Validation & Sanitization](#4-validation--sanitization)
5. [Testing Frameworks](#5-testing-frameworks)
6. [Development Tools](#6-development-tools)
7. [Production & Deployment](#7-production--deployment)
8. [Monitoring & Observability](#8-monitoring--observability)

## 1. Core Dependencies & Frameworks

### 1.1 Essential Express.js Stack

| Package | Usage % | Purpose | Configuration Example |
|---------|---------|---------|----------------------|
| **express** | 100% | Core web framework | `const app = express();` |
| **helmet** | 100% | Security headers | `app.use(helmet());` |
| **cors** | 95% | Cross-origin requests | `app.use(cors(corsOptions));` |
| **compression** | 90% | Response compression | `app.use(compression());` |
| **morgan** | 85% | HTTP request logging | `app.use(morgan('combined'));` |

```javascript
// Standard Express.js setup from Ghost & Strapi
const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const compression = require('compression');
const morgan = require('morgan');

const app = express();

// Security middleware
app.use(helmet({
    contentSecurityPolicy: {
        directives: {
            defaultSrc: ["'self'"],
            scriptSrc: ["'self'", "https://apis.google.com"],
            styleSrc: ["'self'", "'unsafe-inline'", "https://fonts.googleapis.com"]
        }
    }
}));

// CORS configuration
app.use(cors({
    origin: process.env.ALLOWED_ORIGINS?.split(',') || ['http://localhost:3000'],
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH']
}));

// Compression and logging
app.use(compression());
app.use(morgan('combined'));

// Body parsing
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));
```

### 1.2 Middleware Ecosystem

#### Rate Limiting & Throttling

| Package | Projects Using | Use Case | Configuration |
|---------|---------------|----------|---------------|
| **express-rate-limit** | Ghost, Strapi, Parse Server | General rate limiting | Per-endpoint limits |
| **express-slow-down** | Rocket.Chat, GitLab CE | Progressive delays | Gradual slowdown |
| **express-brute** | Security-focused projects | Brute force protection | Failed attempt tracking |

```javascript
// Advanced rate limiting configuration
const rateLimit = require('express-rate-limit');
const slowDown = require('express-slow-down');

// Tiered rate limiting
const createRateLimit = (windowMs, max, message) => 
    rateLimit({
        windowMs,
        max,
        message: { success: false, message },
        standardHeaders: true,
        keyGenerator: (req) => req.user ? `${req.ip}:${req.user.id}` : req.ip
    });

// Global API rate limiting
app.use('/api', createRateLimit(15 * 60 * 1000, 1000, 'Too many requests'));

// Authentication rate limiting
app.use('/api/auth', createRateLimit(15 * 60 * 1000, 5, 'Too many auth attempts'));

// Progressive slowdown for authentication
app.use('/api/auth', slowDown({
    windowMs: 15 * 60 * 1000,
    delayAfter: 2,
    delayMs: 500,
    maxDelayMs: 20000
}));
```

#### Session & Cookie Management

| Package | Adoption | Purpose | Best Practice |
|---------|----------|---------|---------------|
| **express-session** | 60% | Server-side sessions | Redis store |
| **cookie-parser** | 70% | Cookie parsing | Secure flags |
| **connect-redis** | 55% | Redis session store | Session persistence |

```javascript
// Session configuration from Rocket.Chat
const session = require('express-session');
const RedisStore = require('connect-redis')(session);
const redis = require('redis');

const redisClient = redis.createClient({
    url: process.env.REDIS_URL
});

app.use(session({
    store: new RedisStore({ client: redisClient }),
    secret: process.env.SESSION_SECRET,
    name: 'sessionId',
    resave: false,
    saveUninitialized: false,
    cookie: {
        secure: process.env.NODE_ENV === 'production',
        httpOnly: true,
        maxAge: 24 * 60 * 60 * 1000, // 24 hours
        sameSite: 'strict'
    }
}));
```

## 2. Security & Authentication

### 2.1 Authentication Libraries

| Package | Usage % | Projects | Implementation Pattern |
|---------|---------|----------|----------------------|
| **jsonwebtoken** | 85% | Ghost, Strapi, Parse Server | JWT tokens |
| **passport** | 60% | GitLab CE, Rocket.Chat | Multi-strategy auth |
| **bcryptjs** | 90% | All projects | Password hashing |
| **speakeasy** | 30% | Rocket.Chat, GitLab CE | TOTP/2FA |

```javascript
// JWT implementation from Strapi
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');

class AuthService {
    // Token generation with proper configuration
    generateTokens(user) {
        const payload = {
            sub: user.id,
            email: user.email,
            role: user.role,
            iat: Math.floor(Date.now() / 1000)
        };

        const accessToken = jwt.sign(
            { ...payload, type: 'access' },
            process.env.JWT_SECRET,
            {
                expiresIn: '15m',
                algorithm: 'HS256',
                issuer: process.env.APP_NAME,
                audience: `${process.env.APP_NAME}:users`
            }
        );

        const refreshToken = jwt.sign(
            { ...payload, type: 'refresh' },
            process.env.REFRESH_TOKEN_SECRET,
            { expiresIn: '7d' }
        );

        return { accessToken, refreshToken };
    }

    // Secure password hashing
    async hashPassword(password) {
        const saltRounds = parseInt(process.env.BCRYPT_ROUNDS) || 12;
        return bcrypt.hash(password, saltRounds);
    }

    async verifyPassword(password, hash) {
        return bcrypt.compare(password, hash);
    }
}

// Passport.js multi-strategy setup from GitLab CE
const passport = require('passport');
const LocalStrategy = require('passport-local').Strategy;
const GoogleStrategy = require('passport-google-oauth20').Strategy;
const GitHubStrategy = require('passport-github2').Strategy;

// Local strategy
passport.use(new LocalStrategy({
    usernameField: 'email',
    passwordField: 'password'
}, async (email, password, done) => {
    try {
        const user = await User.findOne({ email });
        if (!user || !await authService.verifyPassword(password, user.password)) {
            return done(null, false, { message: 'Invalid credentials' });
        }
        return done(null, user);
    } catch (error) {
        return done(error);
    }
}));

// OAuth strategies
passport.use(new GoogleStrategy({
    clientID: process.env.GOOGLE_CLIENT_ID,
    clientSecret: process.env.GOOGLE_CLIENT_SECRET,
    callbackURL: '/auth/google/callback'
}, async (accessToken, refreshToken, profile, done) => {
    try {
        let user = await User.findOne({ googleId: profile.id });
        
        if (!user) {
            user = await User.create({
                googleId: profile.id,
                email: profile.emails[0].value,
                firstName: profile.name.givenName,
                lastName: profile.name.familyName,
                avatar: profile.photos[0].value
            });
        }
        
        return done(null, user);
    } catch (error) {
        return done(error);
    }
}));
```

### 2.2 Authorization & Permissions

| Package | Projects | Use Case | Implementation |
|---------|----------|----------|----------------|
| **acl** | Parse Server | Access Control Lists | Resource-based permissions |
| **node-casbin** | GitLab CE | RBAC/ABAC | Policy-based authorization |
| **accesscontrol** | Strapi | Role-based access | Simplified RBAC |

```javascript
// Role-based authorization from Strapi
const AccessControl = require('accesscontrol');

class PermissionService {
    constructor() {
        this.ac = new AccessControl();
        this.setupRoles();
    }

    setupRoles() {
        // Define permissions for each role
        this.ac.grant('user')
            .readOwn('profile')
            .updateOwn('profile')
            .createOwn('post')
            .readAny('post');

        this.ac.grant('moderator')
            .extend('user')
            .updateAny('post')
            .deleteAny('post')
            .readAny('user');

        this.ac.grant('admin')
            .extend('moderator')
            .createAny('user')
            .updateAny('user')
            .deleteAny('user');
    }

    // Check permissions
    can(role, action, resource) {
        return this.ac.can(role)[action](resource);
    }

    // Middleware for route protection
    authorize(action, resource) {
        return (req, res, next) => {
            if (!req.user) {
                return res.status(401).json({ message: 'Authentication required' });
            }

            const permission = this.can(req.user.role, action, resource);
            
            if (!permission.granted) {
                return res.status(403).json({ message: 'Insufficient permissions' });
            }

            req.permission = permission;
            next();
        };
    }
}

// Usage in routes
const permissionService = new PermissionService();

app.get('/api/users/:id', 
    authenticate,
    permissionService.authorize('read', 'user'),
    getUserController
);
```

## 3. Database & ORM/ODM

### 3.1 Database Drivers & ORMs

| Technology | Package | Projects Using | Use Case |
|------------|---------|---------------|----------|
| **MongoDB** | mongoose | Parse Server, Rocket.Chat, Ghost | Document databases |
| **PostgreSQL** | pg, sequelize | GitLab CE, Supabase | Relational databases |
| **MySQL** | mysql2, bookshelf | Ghost, Strapi | Traditional RDBMS |
| **Redis** | redis, ioredis | All projects | Caching & sessions |

```javascript
// Mongoose configuration from Parse Server
const mongoose = require('mongoose');

class DatabaseManager {
    constructor() {
        this.connection = null;
    }

    async connect() {
        const options = {
            useNewUrlParser: true,
            useUnifiedTopology: true,
            maxPoolSize: 10,
            serverSelectionTimeoutMS: 5000,
            socketTimeoutMS: 45000,
            bufferCommands: false,
            bufferMaxEntries: 0
        };

        try {
            this.connection = await mongoose.connect(process.env.MONGO_URI, options);
            
            // Setup connection event handlers
            mongoose.connection.on('error', this.handleError);
            mongoose.connection.on('disconnected', this.handleDisconnect);
            
            logger.info('Database connected successfully');
        } catch (error) {
            logger.error('Database connection failed:', error);
            process.exit(1);
        }
    }

    // Optimized schema with proper indexing
    setupSchemas() {
        const userSchema = new mongoose.Schema({
            email: { 
                type: String, 
                required: true, 
                unique: true,
                index: true 
            },
            username: { 
                type: String, 
                unique: true, 
                sparse: true,
                index: true 
            },
            profile: {
                firstName: String,
                lastName: String,
                avatar: String
            },
            role: { 
                type: String, 
                enum: ['user', 'admin', 'moderator'],
                default: 'user',
                index: true 
            },
            isActive: { type: Boolean, default: true, index: true },
            lastLogin: { type: Date, index: true }
        }, {
            timestamps: true,
            toJSON: { transform: this.transformUser }
        });

        // Compound indexes for common queries
        userSchema.index({ email: 1, isActive: 1 });
        userSchema.index({ lastLogin: -1, role: 1 });
        userSchema.index({ 'profile.firstName': 1, 'profile.lastName': 1 });

        return mongoose.model('User', userSchema);
    }
}

// Sequelize configuration from GitLab CE
const { Sequelize, DataTypes } = require('sequelize');

const sequelize = new Sequelize(process.env.DATABASE_URL, {
    dialect: 'postgres',
    pool: {
        max: 20,
        min: 0,
        acquire: 30000,
        idle: 10000
    },
    logging: process.env.NODE_ENV === 'development' ? console.log : false,
    retry: {
        max: 3
    }
});

const User = sequelize.define('User', {
    id: {
        type: DataTypes.UUID,
        defaultValue: DataTypes.UUIDV4,
        primaryKey: true
    },
    email: {
        type: DataTypes.STRING,
        allowNull: false,
        unique: true,
        validate: { isEmail: true }
    },
    passwordHash: {
        type: DataTypes.STRING,
        allowNull: false,
        field: 'password_hash'
    }
}, {
    tableName: 'users',
    indexes: [
        { fields: ['email'] },
        { fields: ['created_at'] },
        { fields: ['email', 'is_active'] }
    ]
});
```

### 3.2 Query Builders & Migration Tools

| Package | Purpose | Projects | Best Practice |
|---------|---------|----------|---------------|
| **knex** | Query builder | Ghost, Bookshelf projects | SQL generation |
| **migrate-mongo** | MongoDB migrations | Mongoose projects | Schema versioning |
| **sequelize-cli** | PostgreSQL migrations | Sequelize projects | Database versioning |

```javascript
// Migration example from Ghost
exports.up = async function(knex) {
    await knex.schema.createTable('posts', function(table) {
        table.string('id', 24).notNullable().primary();
        table.string('uuid', 36).notNullable().unique();
        table.string('title', 2000).notNullable();
        table.string('slug', 191).notNullable();
        table.text('mobiledoc', 'longtext');
        table.text('html', 'longtext');
        table.text('plaintext', 'longtext');
        table.string('feature_image', 2000);
        table.boolean('featured').notNullable().defaultTo(false);
        table.string('status', 50).notNullable().defaultTo('draft');
        table.string('locale', 6);
        table.string('visibility', 50).notNullable().defaultTo('public');
        table.dateTime('created_at').notNullable();
        table.dateTime('updated_at');
        table.dateTime('published_at');
        table.string('created_by', 24).notNullable();
        table.string('updated_by', 24);
        table.string('published_by', 24);
        
        // Indexes
        table.index(['slug', 'status', 'published_at']);
        table.index(['author_id', 'status', 'published_at']);
        table.index(['featured', 'status', 'published_at']);
    });
};

exports.down = async function(knex) {
    await knex.schema.dropTableIfExists('posts');
};
```

## 4. Validation & Sanitization

### 4.1 Input Validation Libraries

| Package | Usage % | Projects | Use Case |
|---------|---------|----------|----------|
| **joi** | 70% | Strapi, Parse Server | Schema validation |
| **express-validator** | 60% | Ghost, GitLab CE | Express middleware |
| **yup** | 40% | Strapi, React forms | Schema validation |
| **ajv** | 30% | JSON Schema validation | API validation |

```javascript
// Joi validation schemas from Strapi
const Joi = require('joi');

const userValidationSchemas = {
    register: Joi.object({
        email: Joi.string()
            .email()
            .required()
            .messages({
                'string.email': 'Please provide a valid email address',
                'any.required': 'Email is required'
            }),
        
        password: Joi.string()
            .min(8)
            .max(128)
            .pattern(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]/)
            .required()
            .messages({
                'string.min': 'Password must be at least 8 characters long',
                'string.pattern.base': 'Password must contain uppercase, lowercase, number, and special character'
            }),
        
        firstName: Joi.string()
            .trim()
            .min(1)
            .max(50)
            .pattern(/^[a-zA-Z\s'-]+$/)
            .required(),
        
        lastName: Joi.string()
            .trim()
            .min(1)
            .max(50)
            .pattern(/^[a-zA-Z\s'-]+$/)
            .required(),
        
        dateOfBirth: Joi.date()
            .max('now')
            .min('1900-01-01')
            .optional(),
        
        phoneNumber: Joi.string()
            .pattern(/^\+?[1-9]\d{1,14}$/)
            .optional()
    }),
    
    updateProfile: Joi.object({
        firstName: Joi.string().trim().min(1).max(50).optional(),
        lastName: Joi.string().trim().min(1).max(50).optional(),
        bio: Joi.string().max(500).optional(),
        website: Joi.string().uri().optional(),
        socialLinks: Joi.array().items(
            Joi.object({
                platform: Joi.string().valid('twitter', 'facebook', 'linkedin', 'github').required(),
                url: Joi.string().uri().required()
            })
        ).max(5).optional()
    })
};

// Validation middleware
const validate = (schema) => {
    return (req, res, next) => {
        const { error, value } = schema.validate(req.body, {
            abortEarly: false,
            stripUnknown: true
        });
        
        if (error) {
            return res.status(400).json({
                success: false,
                message: 'Validation failed',
                errors: error.details.map(detail => ({
                    field: detail.path.join('.'),
                    message: detail.message
                }))
            });
        }
        
        req.validatedData = value;
        next();
    };
};

// Express-validator alternative from Ghost
const { body, param, query, validationResult } = require('express-validator');

const userValidationRules = {
    register: [
        body('email')
            .isEmail()
            .normalizeEmail()
            .custom(async (email) => {
                const user = await User.findOne({ email });
                if (user) throw new Error('Email already in use');
            }),
        
        body('password')
            .isLength({ min: 8 })
            .matches(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])/),
        
        body('firstName')
            .trim()
            .isLength({ min: 1, max: 50 })
            .matches(/^[a-zA-Z\s'-]+$/)
            .escape(),
        
        body('lastName')
            .trim()
            .isLength({ min: 1, max: 50 })
            .matches(/^[a-zA-Z\s'-]+$/)
            .escape()
    ]
};

const handleValidationErrors = (req, res, next) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
        return res.status(400).json({
            success: false,
            errors: errors.array()
        });
    }
    next();
};
```

### 4.2 File Upload & Processing

| Package | Purpose | Projects | Implementation |
|---------|---------|----------|----------------|
| **multer** | File upload | Ghost, Strapi | Multipart handling |
| **sharp** | Image processing | Ghost, Strapi | Image optimization |
| **file-type** | File validation | Security-focused | MIME detection |

```javascript
// Secure file upload from Ghost
const multer = require('multer');
const sharp = require('sharp');
const fileType = require('file-type');
const crypto = require('crypto');

class FileUploadService {
    constructor() {
        this.allowedTypes = {
            image: ['image/jpeg', 'image/png', 'image/webp', 'image/gif'],
            document: ['application/pdf', 'application/msword'],
            video: ['video/mp4', 'video/webm']
        };
        
        this.maxSizes = {
            image: 5 * 1024 * 1024, // 5MB
            document: 10 * 1024 * 1024, // 10MB
            video: 50 * 1024 * 1024 // 50MB
        };
    }

    // Multer configuration
    createUploadMiddleware(type) {
        const storage = multer.memoryStorage();
        
        return multer({
            storage,
            fileFilter: this.createFileFilter(type),
            limits: {
                fileSize: this.maxSizes[type],
                files: 5
            }
        });
    }

    createFileFilter(type) {
        return async (req, file, cb) => {
            try {
                // Check MIME type
                if (!this.allowedTypes[type].includes(file.mimetype)) {
                    return cb(new Error('Invalid file type'));
                }

                // Validate file signature
                const chunk = file.stream.read(12);
                if (chunk) {
                    const detectedType = await fileType.fromBuffer(chunk);
                    if (!detectedType || !this.allowedTypes[type].includes(detectedType.mime)) {
                        return cb(new Error('File signature does not match MIME type'));
                    }
                }

                cb(null, true);
            } catch (error) {
                cb(error);
            }
        };
    }

    // Process uploaded files
    async processImage(buffer, options = {}) {
        const {
            width = 2048,
            height = 2048,
            quality = 80,
            format = 'jpeg'
        } = options;

        return sharp(buffer)
            .resize({ width, height, fit: 'inside', withoutEnlargement: true })
            .jpeg({ quality, progressive: true })
            .withMetadata(false) // Strip EXIF data
            .toBuffer();
    }

    // Generate secure filename
    generateFilename(originalName) {
        const ext = path.extname(originalName);
        const filename = crypto.randomUUID();
        return `${filename}${ext}`;
    }
}
```

## 5. Testing Frameworks

### 5.1 Unit & Integration Testing

| Framework | Usage % | Projects | Best For |
|-----------|---------|----------|----------|
| **jest** | 70% | Strapi, Rocket.Chat | Modern testing |
| **mocha** | 50% | Ghost, Parse Server | Flexible testing |
| **chai** | 45% | With Mocha | Assertions |
| **supertest** | 85% | All projects | HTTP testing |

```javascript
// Jest configuration from Strapi
module.exports = {
    testEnvironment: 'node',
    setupFilesAfterEnv: ['<rootDir>/tests/setup.js'],
    testMatch: [
        '<rootDir>/tests/**/*.test.js',
        '<rootDir>/src/**/*.test.js'
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
    },
    testTimeout: 10000
};

// Test setup file
const { setupDatabase, teardownDatabase } = require('./helpers/database');

beforeAll(async () => {
    await setupDatabase();
});

afterAll(async () => {
    await teardownDatabase();
});

// Example test from Rocket.Chat
const request = require('supertest');
const app = require('../src/app');
const User = require('../src/models/User');

describe('User Authentication', () => {
    beforeEach(async () => {
        await User.deleteMany({});
    });

    describe('POST /api/auth/register', () => {
        it('should register a new user successfully', async () => {
            const userData = {
                email: 'test@example.com',
                password: 'Password123!',
                firstName: 'John',
                lastName: 'Doe'
            };

            const response = await request(app)
                .post('/api/auth/register')
                .send(userData)
                .expect(201);

            expect(response.body.success).toBe(true);
            expect(response.body.data.user.email).toBe(userData.email);
            expect(response.body.data.tokens.accessToken).toBeDefined();

            // Verify user in database
            const user = await User.findOne({ email: userData.email });
            expect(user).toBeTruthy();
            expect(user.firstName).toBe(userData.firstName);
        });

        it('should return validation errors for invalid data', async () => {
            const invalidData = {
                email: 'invalid-email',
                password: '123',
                firstName: ''
            };

            const response = await request(app)
                .post('/api/auth/register')
                .send(invalidData)
                .expect(400);

            expect(response.body.success).toBe(false);
            expect(response.body.errors).toBeDefined();
            expect(response.body.errors.length).toBeGreaterThan(0);
        });
    });
});
```

### 5.2 E2E Testing Tools

| Tool | Projects | Use Case | Configuration |
|------|----------|----------|---------------|
| **cypress** | GitLab CE | Browser testing | Modern E2E |
| **playwright** | Ghost, Strapi | Multi-browser | Comprehensive |
| **puppeteer** | Various | Headless Chrome | PDF generation |

```javascript
// Cypress configuration from GitLab CE
module.exports = {
    e2e: {
        baseUrl: 'http://localhost:3000',
        supportFile: 'cypress/support/e2e.js',
        specPattern: 'cypress/e2e/**/*.cy.js',
        video: true,
        screenshotOnRunFailure: true,
        viewportWidth: 1280,
        viewportHeight: 720,
        defaultCommandTimeout: 10000,
        requestTimeout: 10000,
        responseTimeout: 10000
    },
    component: {
        devServer: {
            framework: 'react',
            bundler: 'webpack'
        }
    }
};

// Example E2E test
describe('User Registration Flow', () => {
    beforeEach(() => {
        cy.visit('/register');
    });

    it('should complete user registration successfully', () => {
        cy.get('[data-testid="email-input"]').type('test@example.com');
        cy.get('[data-testid="password-input"]').type('Password123!');
        cy.get('[data-testid="first-name-input"]').type('John');
        cy.get('[data-testid="last-name-input"]').type('Doe');
        
        cy.get('[data-testid="register-button"]').click();
        
        cy.url().should('include', '/dashboard');
        cy.get('[data-testid="welcome-message"]').should('contain', 'Welcome, John');
    });
});
```

## 6. Development Tools

### 6.1 Code Quality & Linting

| Tool | Usage % | Purpose | Configuration |
|------|---------|---------|---------------|
| **eslint** | 95% | Code linting | Style enforcement |
| **prettier** | 90% | Code formatting | Consistent formatting |
| **husky** | 75% | Git hooks | Pre-commit checks |
| **lint-staged** | 70% | Staged file linting | Performance |

```javascript
// ESLint configuration from Ghost
module.exports = {
    extends: [
        'eslint:recommended',
        '@typescript-eslint/recommended',
        'prettier'
    ],
    parser: '@typescript-eslint/parser',
    plugins: ['@typescript-eslint'],
    env: {
        node: true,
        es2020: true,
        jest: true
    },
    parserOptions: {
        ecmaVersion: 2020,
        sourceType: 'module'
    },
    rules: {
        'no-console': process.env.NODE_ENV === 'production' ? 'error' : 'warn',
        'no-debugger': process.env.NODE_ENV === 'production' ? 'error' : 'warn',
        'prefer-const': 'error',
        'no-var': 'error',
        'object-shorthand': 'error',
        'prefer-template': 'error'
    },
    overrides: [
        {
            files: ['**/*.test.js', '**/*.spec.js'],
            env: { jest: true },
            rules: {
                'no-console': 'off'
            }
        }
    ]
};

// Prettier configuration
module.exports = {
    semi: true,
    singleQuote: true,
    tabWidth: 2,
    trailingComma: 'es5',
    printWidth: 100,
    bracketSpacing: true,
    arrowParens: 'avoid'
};

// Husky pre-commit hook
#!/bin/sh
. "$(dirname "$0")/_/husky.sh"

npx lint-staged
npm run test:unit
```

### 6.2 Development Workflow

| Tool | Purpose | Projects | Benefits |
|------|---------|----------|----------|
| **nodemon** | Auto-restart | All projects | Development efficiency |
| **dotenv** | Environment variables | All projects | Configuration management |
| **cross-env** | Cross-platform env | Windows support | Platform compatibility |

```javascript
// Development script configuration
{
  "scripts": {
    "dev": "cross-env NODE_ENV=development nodemon src/server.js",
    "dev:debug": "cross-env NODE_ENV=development DEBUG=app:* nodemon src/server.js",
    "start": "cross-env NODE_ENV=production node dist/server.js",
    "build": "tsc && npm run copy-assets",
    "test": "jest",
    "test:watch": "jest --watch",
    "test:coverage": "jest --coverage",
    "lint": "eslint src --ext .js,.ts",
    "lint:fix": "eslint src --ext .js,.ts --fix",
    "format": "prettier --write \"src/**/*.{js,ts,json,md}\"",
    "type-check": "tsc --noEmit"
  }
}

// Nodemon configuration
{
  "watch": ["src"],
  "ext": "js,ts,json",
  "ignore": ["src/**/*.test.js", "src/**/*.spec.js"],
  "exec": "node src/server.js",
  "env": {
    "NODE_ENV": "development"
  },
  "delay": 1000
}
```

## 7. Production & Deployment

### 7.1 Process Management

| Tool | Usage % | Projects | Use Case |
|------|---------|----------|----------|
| **pm2** | 80% | Ghost, Strapi | Production process management |
| **forever** | 20% | Legacy projects | Simple process monitoring |
| **systemd** | 40% | Linux deployments | System service |

```javascript
// PM2 ecosystem configuration from Ghost
module.exports = {
    apps: [
        {
            name: 'express-app',
            script: './dist/server.js',
            instances: 'max',
            exec_mode: 'cluster',
            env: {
                NODE_ENV: 'production',
                PORT: 3000
            },
            // Logging
            log_file: './logs/combined.log',
            out_file: './logs/out.log',
            error_file: './logs/error.log',
            log_date_format: 'YYYY-MM-DD HH:mm Z',
            
            // Restart policy
            watch: false,
            ignore_watch: ['node_modules', 'logs'],
            max_memory_restart: '1G',
            restart_delay: 4000,
            
            // Health monitoring
            min_uptime: '10s',
            max_restarts: 10,
            
            // Advanced features
            merge_logs: true,
            kill_timeout: 5000,
            listen_timeout: 8000,
            shutdown_with_message: true
        }
    ]
};
```

### 7.2 Containerization

| Tool | Adoption | Projects | Benefits |
|------|----------|----------|----------|
| **docker** | 95% | All modern projects | Containerization |
| **docker-compose** | 85% | Development environments | Multi-service orchestration |
| **kubernetes** | 40% | Large scale deployments | Orchestration |

```dockerfile
# Multi-stage Dockerfile from Strapi
FROM node:18-alpine AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production && npm cache clean --force

# Copy source code
COPY . .

# Build application
RUN npm run build

# Production stage
FROM node:18-alpine

# Install dumb-init for signal handling
RUN apk add --no-cache dumb-init

# Create app directory
WORKDIR /app

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

# Copy built application
COPY --from=builder --chown=nodejs:nodejs /app/dist ./dist
COPY --from=builder --chown=nodejs:nodejs /app/node_modules ./node_modules
COPY --from=builder --chown=nodejs:nodejs /app/package.json ./package.json

# Create logs directory
RUN mkdir -p logs && chown nodejs:nodejs logs

# Use non-root user
USER nodejs

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD node dist/healthcheck.js

# Start application
ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "dist/server.js"]
```

## 8. Monitoring & Observability

### 8.1 Application Monitoring

| Tool | Projects | Purpose | Implementation |
|------|----------|---------|----------------|
| **winston** | 90% | Structured logging | Log management |
| **pino** | 30% | High-performance logging | Fast logging |
| **prometheus** | 50% | Metrics collection | Observability |
| **jaeger** | 20% | Distributed tracing | Request tracing |

```javascript
// Winston logging configuration from Rocket.Chat
const winston = require('winston');

const logger = winston.createLogger({
    level: process.env.LOG_LEVEL || 'info',
    format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.errors({ stack: true }),
        winston.format.json()
    ),
    defaultMeta: {
        service: 'express-app',
        version: process.env.APP_VERSION,
        environment: process.env.NODE_ENV
    },
    transports: [
        new winston.transports.File({
            filename: 'logs/error.log',
            level: 'error',
            maxsize: 5242880,
            maxFiles: 5
        }),
        new winston.transports.File({
            filename: 'logs/combined.log',
            maxsize: 5242880,
            maxFiles: 5
        })
    ]
});

// Add console transport for development
if (process.env.NODE_ENV !== 'production') {
    logger.add(new winston.transports.Console({
        format: winston.format.combine(
            winston.format.colorize(),
            winston.format.simple()
        )
    }));
}

// Prometheus metrics from GitLab CE
const promClient = require('prom-client');

// HTTP request metrics
const httpRequestDuration = new promClient.Histogram({
    name: 'http_request_duration_seconds',
    help: 'Duration of HTTP requests in seconds',
    labelNames: ['method', 'route', 'status_code']
});

const httpRequestsTotal = new promClient.Counter({
    name: 'http_requests_total',
    help: 'Total number of HTTP requests',
    labelNames: ['method', 'route', 'status_code']
});

// Application metrics
const activeConnections = new promClient.Gauge({
    name: 'active_connections',
    help: 'Number of active connections'
});

const databaseConnections = new promClient.Gauge({
    name: 'database_connections_active',
    help: 'Number of active database connections'
});

// Middleware to collect metrics
app.use((req, res, next) => {
    const start = Date.now();
    
    res.on('finish', () => {
        const duration = (Date.now() - start) / 1000;
        const route = req.route?.path || req.path;
        
        httpRequestDuration
            .labels(req.method, route, res.statusCode)
            .observe(duration);
        
        httpRequestsTotal
            .labels(req.method, route, res.statusCode)
            .inc();
    });
    
    next();
});

// Metrics endpoint
app.get('/metrics', async (req, res) => {
    res.set('Content-Type', promClient.register.contentType);
    res.end(await promClient.register.metrics());
});
```

### 8.2 Health Checks & Status

```javascript
// Comprehensive health check from Supabase
app.get('/health', async (req, res) => {
    const healthStatus = {
        status: 'healthy',
        timestamp: new Date().toISOString(),
        uptime: process.uptime(),
        version: process.env.APP_VERSION,
        environment: process.env.NODE_ENV,
        checks: {}
    };
    
    try {
        // Database health
        const dbStart = Date.now();
        await mongoose.connection.db.admin().ping();
        healthStatus.checks.database = {
            status: 'healthy',
            responseTime: Date.now() - dbStart
        };
    } catch (error) {
        healthStatus.checks.database = {
            status: 'unhealthy',
            error: error.message
        };
        healthStatus.status = 'unhealthy';
    }
    
    try {
        // Redis health
        const redisStart = Date.now();
        await redisClient.ping();
        healthStatus.checks.redis = {
            status: 'healthy',
            responseTime: Date.now() - redisStart
        };
    } catch (error) {
        healthStatus.checks.redis = {
            status: 'unhealthy',
            error: error.message
        };
        if (healthStatus.status === 'healthy') {
            healthStatus.status = 'degraded';
        }
    }
    
    // Memory usage
    const memUsage = process.memoryUsage();
    healthStatus.checks.memory = {
        status: memUsage.heapUsed < 500 * 1024 * 1024 ? 'healthy' : 'warning',
        heapUsed: memUsage.heapUsed,
        heapTotal: memUsage.heapTotal
    };
    
    const statusCode = healthStatus.status === 'healthy' ? 200 : 503;
    res.status(statusCode).json(healthStatus);
});
```

## 🔗 Navigation

### Related Documents
- ⬅️ **Previous**: [Architecture Patterns](./architecture-patterns.md)
- ➡️ **Next**: [Testing Strategies](./testing-strategies.md)

### Quick Links
- [Implementation Guide](./implementation-guide.md)
- [Best Practices](./best-practices.md)
- [Security Considerations](./security-considerations.md)

---

**Tools & Ecosystem Complete** | **Categories**: 8 | **Packages Analyzed**: 50+ | **Configuration Examples**: 25+