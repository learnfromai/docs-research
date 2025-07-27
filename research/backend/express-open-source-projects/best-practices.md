# Best Practices for Express.js Applications

## 🎯 Overview

Consolidated best practices and patterns extracted from production Express.js applications, covering security, performance, code organization, deployment, and maintenance strategies.

## 🏗️ Code Organization & Architecture

### 1. Project Structure Best Practices

**Recommended Directory Structure**
```
src/
├── app.js                    # Express app configuration
├── server.js                 # Server startup and lifecycle
├── config/                   # Configuration management
│   ├── database.js           # Database configuration
│   ├── redis.js             # Redis configuration
│   ├── env.js               # Environment validation
│   └── constants.js         # Application constants
├── controllers/             # Request handlers
│   ├── auth.controller.js
│   ├── user.controller.js
│   └── post.controller.js
├── services/               # Business logic
│   ├── auth.service.js
│   ├── user.service.js
│   ├── email.service.js
│   └── notification.service.js
├── models/                 # Data models
│   ├── User.js
│   ├── Post.js
│   └── Comment.js
├── middleware/             # Custom middleware
│   ├── auth.middleware.js
│   ├── validation.middleware.js
│   ├── error.middleware.js
│   └── logging.middleware.js
├── routes/                 # Route definitions
│   ├── index.js            # Route aggregation
│   ├── auth.routes.js
│   ├── user.routes.js
│   └── post.routes.js
├── utils/                  # Utility functions
│   ├── logger.js
│   ├── email.js
│   ├── validation.js
│   └── helpers.js
├── types/                  # TypeScript type definitions
│   ├── auth.types.ts
│   ├── user.types.ts
│   └── common.types.ts
└── tests/                  # Test files
    ├── unit/
    ├── integration/
    └── e2e/
```

**Module Export Patterns**
```javascript
// Good: Named exports for utilities
// utils/helpers.js
exports.formatDate = (date) => { /* ... */ };
exports.generateId = () => { /* ... */ };
exports.sanitizeInput = (input) => { /* ... */ };

// Good: Class exports for services
// services/UserService.js
class UserService {
    async createUser(userData) { /* ... */ }
    async findUser(id) { /* ... */ }
}

module.exports = UserService;

// Good: Factory pattern for configurations
// config/database.js
module.exports = (env) => {
    const config = {
        development: { /* dev config */ },
        production: { /* prod config */ },
        test: { /* test config */ }
    };
    
    return config[env] || config.development;
};

// Good: Aggregated exports
// routes/index.js
const authRoutes = require('./auth.routes');
const userRoutes = require('./user.routes');
const postRoutes = require('./post.routes');

module.exports = {
    authRoutes,
    userRoutes,
    postRoutes
};
```

### 2. Separation of Concerns

**Controller → Service → Repository Pattern**
```javascript
// controllers/UserController.js - Handle HTTP concerns only
class UserController {
    constructor(userService) {
        this.userService = userService;
    }

    async createUser(req, res, next) {
        try {
            const userData = req.validatedBody;
            const user = await this.userService.createUser(userData);
            
            res.status(201).json({
                success: true,
                data: user,
                meta: { location: `/api/users/${user.id}` }
            });
        } catch (error) {
            next(error);
        }
    }

    async getUsers(req, res, next) {
        try {
            const options = this.parseQueryOptions(req.query);
            const result = await this.userService.findUsers(options);
            
            res.json({
                success: true,
                data: result.users,
                meta: { pagination: result.pagination }
            });
        } catch (error) {
            next(error);
        }
    }

    parseQueryOptions(query) {
        return {
            page: parseInt(query.page) || 1,
            limit: Math.min(parseInt(query.limit) || 10, 100),
            search: query.search,
            filters: query.filter || {},
            sort: query.sort || '-createdAt'
        };
    }
}

// services/UserService.js - Business logic only
class UserService {
    constructor(userRepository, emailService, auditService) {
        this.userRepository = userRepository;
        this.emailService = emailService;
        this.auditService = auditService;
    }

    async createUser(userData) {
        // Business validation
        await this.validateBusinessRules(userData);
        
        // Hash password
        const hashedPassword = await bcrypt.hash(userData.password, 12);
        
        // Create user
        const user = await this.userRepository.create({
            ...userData,
            password: hashedPassword,
            status: 'pending_verification'
        });

        // Send welcome email (async)
        this.emailService.sendWelcomeEmail(user.email).catch(error => {
            console.error('Failed to send welcome email:', error);
        });

        // Audit log
        await this.auditService.logUserCreation(user.id);

        return this.sanitizeUser(user);
    }

    async findUsers(options) {
        // Apply business filters
        const filters = this.buildUserFilters(options.filters);
        
        const result = await this.userRepository.findWithPagination({
            ...options,
            filters
        });

        return {
            users: result.data.map(user => this.sanitizeUser(user)),
            pagination: result.pagination
        };
    }

    validateBusinessRules(userData) {
        // Custom business validation logic
        if (this.isEmailBlacklisted(userData.email)) {
            throw new BusinessError('Email domain not allowed');
        }
        
        if (this.isDuplicateUsername(userData.username)) {
            throw new BusinessError('Username already taken');
        }
    }

    sanitizeUser(user) {
        const { password, resetToken, ...sanitized } = user.toObject();
        return sanitized;
    }
}

// repositories/UserRepository.js - Data access only
class UserRepository {
    constructor(model) {
        this.model = model;
    }

    async create(userData) {
        return await this.model.create(userData);
    }

    async findById(id) {
        return await this.model.findById(id);
    }

    async findByEmail(email) {
        return await this.model.findOne({ email: email.toLowerCase() });
    }

    async findWithPagination(options) {
        const { page, limit, filters, sort } = options;
        const skip = (page - 1) * limit;

        const [data, total] = await Promise.all([
            this.model
                .find(filters)
                .sort(this.parseSortString(sort))
                .skip(skip)
                .limit(limit)
                .exec(),
            this.model.countDocuments(filters)
        ]);

        return {
            data,
            pagination: {
                page,
                limit,
                total,
                pages: Math.ceil(total / limit),
                hasNextPage: page * limit < total,
                hasPrevPage: page > 1
            }
        };
    }

    parseSortString(sortStr) {
        // Convert "-createdAt,name" to { createdAt: -1, name: 1 }
        return sortStr.split(',').reduce((acc, field) => {
            if (field.startsWith('-')) {
                acc[field.substring(1)] = -1;
            } else {
                acc[field] = 1;
            }
            return acc;
        }, {});
    }
}
```

### 3. Dependency Injection Pattern

**IoC Container Implementation**
```javascript
// container.js - Simple dependency injection container
class Container {
    constructor() {
        this.dependencies = new Map();
        this.singletons = new Map();
    }

    register(name, factory, options = {}) {
        this.dependencies.set(name, {
            factory,
            singleton: options.singleton || false,
            dependencies: options.dependencies || []
        });
    }

    resolve(name) {
        const dependency = this.dependencies.get(name);
        
        if (!dependency) {
            throw new Error(`Dependency '${name}' not found`);
        }

        // Return singleton instance if already created
        if (dependency.singleton && this.singletons.has(name)) {
            return this.singletons.get(name);
        }

        // Resolve dependencies recursively
        const resolvedDependencies = dependency.dependencies.map(dep => 
            this.resolve(dep)
        );

        // Create instance
        const instance = dependency.factory(...resolvedDependencies);

        // Cache singleton
        if (dependency.singleton) {
            this.singletons.set(name, instance);
        }

        return instance;
    }
}

// Setup container
const container = new Container();

// Register dependencies
container.register('database', () => require('./config/database'), { singleton: true });
container.register('logger', () => require('./utils/logger'), { singleton: true });

container.register('UserModel', () => require('./models/User'), { 
    singleton: true,
    dependencies: ['database'] 
});

container.register('UserRepository', (UserModel) => new UserRepository(UserModel), {
    dependencies: ['UserModel']
});

container.register('EmailService', () => new EmailService(), { singleton: true });
container.register('AuditService', () => new AuditService(), { singleton: true });

container.register('UserService', (userRepository, emailService, auditService) => 
    new UserService(userRepository, emailService, auditService), {
    dependencies: ['UserRepository', 'EmailService', 'AuditService']
});

container.register('UserController', (userService) => new UserController(userService), {
    dependencies: ['UserService']
});

// Usage in route files
const userController = container.resolve('UserController');
```

## 🔒 Security Best Practices

### 1. Input Validation & Sanitization

**Comprehensive Validation Strategy**
```javascript
// middleware/validation.js
const Joi = require('joi');
const DOMPurify = require('isomorphic-dompurify');

// Validation schemas
const schemas = {
    user: {
        create: Joi.object({
            email: Joi.string().email().required(),
            password: Joi.string()
                .min(8)
                .pattern(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]/)
                .required()
                .messages({
                    'string.pattern.base': 'Password must contain uppercase, lowercase, number and special character'
                }),
            name: Joi.string().min(2).max(50).required().trim(),
            phone: Joi.string().pattern(/^\+?[\d\s-()]+$/).optional(),
            dateOfBirth: Joi.date().max('now').optional()
        }),
        
        update: Joi.object({
            email: Joi.string().email(),
            name: Joi.string().min(2).max(50).trim(),
            phone: Joi.string().pattern(/^\+?[\d\s-()]+$/),
            bio: Joi.string().max(500).allow('')
        }).min(1) // At least one field required
    },
    
    post: {
        create: Joi.object({
            title: Joi.string().min(3).max(200).required().trim(),
            content: Joi.string().min(10).required(),
            tags: Joi.array().items(Joi.string().trim()).max(10),
            category: Joi.string().valid('tech', 'lifestyle', 'business').required(),
            featured: Joi.boolean().default(false),
            publishAt: Joi.date().min('now').optional()
        })
    }
};

// Validation middleware factory
const validate = (schemaName, operation) => {
    return (req, res, next) => {
        const schema = schemas[schemaName]?.[operation];
        
        if (!schema) {
            return next(new Error(`Validation schema not found: ${schemaName}.${operation}`));
        }

        const { error, value } = schema.validate(req.body, {
            abortEarly: false,
            stripUnknown: true,
            convert: true
        });

        if (error) {
            const details = error.details.map(detail => ({
                field: detail.path.join('.'),
                message: detail.message,
                value: detail.context?.value
            }));

            return res.status(400).json({
                success: false,
                error: {
                    code: 'VALIDATION_ERROR',
                    message: 'Validation failed',
                    details
                }
            });
        }

        // Sanitize HTML content
        if (value.content) {
            value.content = DOMPurify.sanitize(value.content, {
                ALLOWED_TAGS: ['p', 'br', 'strong', 'em', 'u', 'h1', 'h2', 'h3', 'ul', 'ol', 'li'],
                ALLOWED_ATTR: []
            });
        }

        req.validatedBody = value;
        next();
    };
};

// Usage
app.post('/api/users', validate('user', 'create'), userController.createUser);
app.put('/api/posts/:id', validate('post', 'update'), postController.updatePost);
```

### 2. Authentication & Authorization

**Secure Authentication Implementation**
```javascript
// middleware/auth.js
const jwt = require('jsonwebtoken');
const rateLimit = require('express-rate-limit');

// Rate limiting for auth endpoints
const authLimiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 5, // Limit each IP to 5 requests per windowMs
    message: 'Too many authentication attempts, please try again later',
    standardHeaders: true,
    legacyHeaders: false,
    handler: (req, res) => {
        res.status(429).json({
            success: false,
            error: {
                code: 'RATE_LIMIT_EXCEEDED',
                message: 'Too many authentication attempts, please try again later',
                retryAfter: Math.round(req.rateLimit.resetTime / 1000)
            }
        });
    }
});

// JWT token validation
const authenticateToken = async (req, res, next) => {
    try {
        const authHeader = req.headers.authorization;
        const token = authHeader && authHeader.split(' ')[1]; // Bearer TOKEN

        if (!token) {
            return res.status(401).json({
                success: false,
                error: {
                    code: 'NO_TOKEN',
                    message: 'Access token required'
                }
            });
        }

        // Verify token
        const payload = jwt.verify(token, process.env.JWT_SECRET, {
            issuer: process.env.JWT_ISSUER,
            audience: process.env.JWT_AUDIENCE
        });

        // Check if user still exists and is active
        const user = await User.findById(payload.sub);
        if (!user || user.status !== 'active') {
            return res.status(401).json({
                success: false,
                error: {
                    code: 'INVALID_USER',
                    message: 'User not found or inactive'
                }
            });
        }

        // Check if password was changed after token was issued
        if (user.passwordChangedAt && payload.iat < user.passwordChangedAt.getTime() / 1000) {
            return res.status(401).json({
                success: false,
                error: {
                    code: 'TOKEN_EXPIRED',
                    message: 'Token is no longer valid'
                }
            });
        }

        req.user = user;
        next();
    } catch (error) {
        if (error.name === 'JsonWebTokenError') {
            return res.status(401).json({
                success: false,
                error: {
                    code: 'INVALID_TOKEN',
                    message: 'Invalid access token'
                }
            });
        }

        if (error.name === 'TokenExpiredError') {
            return res.status(401).json({
                success: false,
                error: {
                    code: 'TOKEN_EXPIRED',
                    message: 'Access token has expired'
                }
            });
        }

        next(error);
    }
};

// Role-based authorization
const authorize = (...roles) => {
    return (req, res, next) => {
        if (!req.user) {
            return res.status(401).json({
                success: false,
                error: {
                    code: 'AUTHENTICATION_REQUIRED',
                    message: 'Authentication required'
                }
            });
        }

        if (roles.length > 0 && !roles.includes(req.user.role)) {
            return res.status(403).json({
                success: false,
                error: {
                    code: 'INSUFFICIENT_PERMISSIONS',
                    message: 'Insufficient permissions to access this resource'
                }
            });
        }

        next();
    };
};

// Resource ownership check
const checkOwnership = (resourceModel, resourceIdField = 'id') => {
    return async (req, res, next) => {
        try {
            const resourceId = req.params[resourceIdField];
            const resource = await resourceModel.findById(resourceId);

            if (!resource) {
                return res.status(404).json({
                    success: false,
                    error: {
                        code: 'RESOURCE_NOT_FOUND',
                        message: 'Resource not found'
                    }
                });
            }

            // Check ownership or admin role
            if (resource.userId !== req.user.id && req.user.role !== 'admin') {
                return res.status(403).json({
                    success: false,
                    error: {
                        code: 'RESOURCE_FORBIDDEN',
                        message: 'You can only access your own resources'
                    }
                });
            }

            req.resource = resource;
            next();
        } catch (error) {
            next(error);
        }
    };
};

module.exports = {
    authLimiter,
    authenticateToken,
    authorize,
    checkOwnership
};
```

### 3. Security Headers & CORS

**Security Middleware Configuration**
```javascript
// middleware/security.js
const helmet = require('helmet');
const cors = require('cors');

// Comprehensive security headers
const securityHeaders = helmet({
    contentSecurityPolicy: {
        directives: {
            defaultSrc: ["'self'"],
            styleSrc: ["'self'", "'unsafe-inline'", 'https://fonts.googleapis.com'],
            scriptSrc: ["'self'", "'unsafe-eval'"], // Avoid unsafe-eval in production
            fontSrc: ["'self'", 'https://fonts.gstatic.com'],
            imgSrc: ["'self'", 'data:', 'https:'],
            connectSrc: ["'self'", 'wss:', 'https:'],
            frameSrc: ["'none'"],
            objectSrc: ["'none'"],
            baseUri: ["'self'"],
            formAction: ["'self'"],
            upgradeInsecureRequests: [],
        },
        reportOnly: process.env.NODE_ENV === 'development'
    },
    
    crossOriginEmbedderPolicy: { policy: 'require-corp' },
    crossOriginOpenerPolicy: { policy: 'same-origin' },
    crossOriginResourcePolicy: { policy: 'cross-origin' },
    
    dnsPrefetchControl: { allow: false },
    frameguard: { action: 'deny' },
    hidePoweredBy: true,
    hsts: {
        maxAge: 31536000, // 1 year
        includeSubDomains: true,
        preload: true
    },
    
    ieNoOpen: true,
    noSniff: true,
    originAgentCluster: true,
    permittedCrossDomainPolicies: false,
    referrerPolicy: { policy: 'no-referrer' },
    xssFilter: true
});

// CORS configuration
const corsOptions = {
    origin: (origin, callback) => {
        const allowedOrigins = process.env.ALLOWED_ORIGINS?.split(',') || [];
        
        // Allow requests with no origin (mobile apps, etc.)
        if (!origin) return callback(null, true);
        
        if (allowedOrigins.includes(origin) || process.env.NODE_ENV === 'development') {
            callback(null, true);
        } else {
            callback(new Error('Not allowed by CORS'));
        }
    },
    
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: [
        'Origin',
        'X-Requested-With',
        'Content-Type',
        'Accept',
        'Authorization',
        'X-API-Key'
    ],
    
    credentials: true,
    maxAge: 86400, // 24 hours
    
    optionsSuccessStatus: 200 // Support legacy browsers
};

module.exports = {
    securityHeaders,
    corsOptions: cors(corsOptions)
};
```

## ⚡ Performance Best Practices

### 1. Caching Strategies

**Multi-Level Caching Implementation**
```javascript
// services/CacheService.js
const Redis = require('ioredis');

class CacheService {
    constructor() {
        this.redis = new Redis(process.env.REDIS_URL);
        this.memCache = new Map(); // In-memory cache for hot data
        this.defaultTTL = 3600; // 1 hour
    }

    async get(key, options = {}) {
        try {
            // Try memory cache first
            if (this.memCache.has(key)) {
                const cached = this.memCache.get(key);
                if (cached.expires > Date.now()) {
                    return cached.value;
                } else {
                    this.memCache.delete(key);
                }
            }

            // Try Redis cache
            const cached = await this.redis.get(key);
            if (cached) {
                const value = JSON.parse(cached);
                
                // Store in memory cache if requested
                if (options.memoryCacheTTL) {
                    this.memCache.set(key, {
                        value,
                        expires: Date.now() + (options.memoryCacheTTL * 1000)
                    });
                }
                
                return value;
            }

            return null;
        } catch (error) {
            console.error('Cache get error:', error);
            return null;
        }
    }

    async set(key, value, ttl = this.defaultTTL) {
        try {
            // Store in Redis
            await this.redis.setex(key, ttl, JSON.stringify(value));
            
            // Store in memory cache for frequently accessed data
            if (ttl <= 300) { // 5 minutes or less
                this.memCache.set(key, {
                    value,
                    expires: Date.now() + (Math.min(ttl, 60) * 1000) // Max 1 minute in memory
                });
            }

            return true;
        } catch (error) {
            console.error('Cache set error:', error);
            return false;
        }
    }

    async del(key) {
        try {
            this.memCache.delete(key);
            await this.redis.del(key);
            return true;
        } catch (error) {
            console.error('Cache delete error:', error);
            return false;
        }
    }

    async invalidatePattern(pattern) {
        try {
            const keys = await this.redis.keys(pattern);
            if (keys.length > 0) {
                await this.redis.del(...keys);
            }
            
            // Clear related memory cache entries
            for (const [key] of this.memCache.entries()) {
                if (this.matchesPattern(key, pattern)) {
                    this.memCache.delete(key);
                }
            }
            
            return true;
        } catch (error) {
            console.error('Cache invalidation error:', error);
            return false;
        }
    }

    matchesPattern(key, pattern) {
        const regex = new RegExp(pattern.replace(/\*/g, '.*'));
        return regex.test(key);
    }
}

// Caching middleware
const cache = (options = {}) => {
    const cacheService = new CacheService();
    
    return async (req, res, next) => {
        const key = options.keyGenerator ? 
            options.keyGenerator(req) : 
            `${req.method}:${req.originalUrl}:${req.user?.id || 'anonymous'}`;

        const ttl = options.ttl || 300; // 5 minutes default

        try {
            const cached = await cacheService.get(key);
            
            if (cached) {
                return res.json(cached);
            }

            // Store original res.json
            const originalJson = res.json;
            
            res.json = function(data) {
                // Cache successful responses
                if (res.statusCode === 200) {
                    cacheService.set(key, data, ttl);
                }
                
                return originalJson.call(this, data);
            };

            next();
        } catch (error) {
            console.error('Cache middleware error:', error);
            next();
        }
    };
};

// Usage examples
app.get('/api/posts', 
    cache({ ttl: 600, keyGenerator: req => `posts:${req.query.page || 1}` }),
    postController.getPosts
);

app.get('/api/users/:id', 
    cache({ ttl: 1800 }),
    userController.getUser
);
```

### 2. Database Optimization

**Query Optimization Patterns**
```javascript
// services/OptimizedQueryService.js
class OptimizedQueryService {
    constructor(model) {
        this.model = model;
    }

    // Pagination with total count optimization
    async findWithPagination(options) {
        const { page = 1, limit = 10, filters = {}, sort = {} } = options;
        const skip = (page - 1) * limit;

        // Use Promise.all for parallel execution
        const [data, total] = await Promise.all([
            this.model
                .find(filters)
                .sort(sort)
                .skip(skip)
                .limit(limit)
                .lean() // Return plain JavaScript objects
                .exec(),
            
            // Use countDocuments for better performance
            this.model.countDocuments(filters)
        ]);

        return {
            data,
            pagination: {
                page,
                limit,
                total,
                pages: Math.ceil(total / limit),
                hasNextPage: page * limit < total,
                hasPrevPage: page > 1
            }
        };
    }

    // Efficient aggregation with proper indexing
    async getPostStatistics(userId) {
        return this.model.aggregate([
            // Match stage - ensure index on userId
            { $match: { authorId: new ObjectId(userId) } },
            
            // Group stage
            {
                $group: {
                    _id: null,
                    totalPosts: { $sum: 1 },
                    publishedPosts: {
                        $sum: { $cond: [{ $eq: ['$status', 'published'] }, 1, 0] }
                    },
                    avgWordsPerPost: { $avg: '$wordCount' },
                    mostRecentPost: { $max: '$createdAt' }
                }
            },
            
            // Project stage
            {
                $project: {
                    _id: 0,
                    totalPosts: 1,
                    publishedPosts: 1,
                    avgWordsPerPost: { $round: ['$avgWordsPerPost', 0] },
                    mostRecentPost: 1,
                    draftPosts: { $subtract: ['$totalPosts', '$publishedPosts'] }
                }
            }
        ]);
    }

    // Bulk operations for better performance
    async bulkUpdatePostViews(updates) {
        const bulkOps = updates.map(update => ({
            updateOne: {
                filter: { _id: update.postId },
                update: { $inc: { views: update.increment } }
            }
        }));

        return this.model.bulkWrite(bulkOps, { ordered: false });
    }

    // Efficient search with text indexes
    async searchPosts(searchTerm, options = {}) {
        const pipeline = [];

        // Text search stage
        if (searchTerm) {
            pipeline.push({
                $match: {
                    $text: { $search: searchTerm },
                    status: 'published'
                }
            });
            
            // Add text score for relevance sorting
            pipeline.push({
                $addFields: {
                    score: { $meta: 'textScore' }
                }
            });
        }

        // Apply additional filters
        if (options.category) {
            pipeline.push({
                $match: { category: options.category }
            });
        }

        // Sort by relevance and date
        pipeline.push({
            $sort: searchTerm ? 
                { score: { $meta: 'textScore' }, createdAt: -1 } :
                { createdAt: -1 }
        });

        // Pagination
        if (options.skip) pipeline.push({ $skip: options.skip });
        if (options.limit) pipeline.push({ $limit: options.limit });

        // Populate author information
        pipeline.push({
            $lookup: {
                from: 'users',
                localField: 'authorId',
                foreignField: '_id',
                as: 'author',
                pipeline: [
                    { $project: { name: 1, avatar: 1, email: 1 } }
                ]
            }
        });

        pipeline.push({
            $unwind: '$author'
        });

        return this.model.aggregate(pipeline);
    }

    // Connection pooling and index management
    static setupIndexes(model) {
        // Compound indexes for common queries
        model.createIndex({ authorId: 1, status: 1, createdAt: -1 });
        model.createIndex({ status: 1, publishedAt: -1 });
        model.createIndex({ category: 1, status: 1 });
        
        // Text index for search
        model.createIndex({ 
            title: 'text', 
            content: 'text', 
            tags: 'text' 
        });
        
        // Sparse index for optional fields
        model.createIndex({ publishedAt: 1 }, { sparse: true });
        
        // TTL index for temporary data
        model.createIndex({ expiresAt: 1 }, { expireAfterSeconds: 0 });
    }
}

// Database connection optimization
const mongoose = require('mongoose');

const connectDB = async () => {
    try {
        const conn = await mongoose.connect(process.env.DATABASE_URL, {
            // Connection pool settings
            maxPoolSize: 10, // Maximum number of connections
            minPoolSize: 2,  // Minimum number of connections
            maxIdleTimeMS: 30000, // Close connections after 30 seconds of inactivity
            serverSelectionTimeoutMS: 5000, // How long to try selecting a server
            socketTimeoutMS: 45000, // How long a send or receive on a socket can take
            
            // Buffering settings
            bufferMaxEntries: 0, // Disable mongoose buffering
            bufferCommands: false, // Disable mongoose buffering
            
            // Other optimizations
            useNewUrlParser: true,
            useUnifiedTopology: true
        });

        console.log(`MongoDB Connected: ${conn.connection.host}`);

        // Handle connection events
        mongoose.connection.on('error', err => {
            console.error('MongoDB connection error:', err);
        });

        mongoose.connection.on('disconnected', () => {
            console.log('MongoDB disconnected');
        });

        // Graceful shutdown
        process.on('SIGINT', async () => {
            await mongoose.connection.close();
            console.log('MongoDB connection closed through app termination');
            process.exit(0);
        });

    } catch (error) {
        console.error('Database connection failed:', error);
        process.exit(1);
    }
};
```

### 3. Response Compression & Optimization

**Advanced Compression Configuration**
```javascript
// middleware/compression.js
const compression = require('compression');
const zlib = require('zlib');

// Smart compression middleware
const smartCompression = compression({
    // Only compress responses that are larger than this threshold
    threshold: 1024, // 1KB

    // Compression level (1-9, higher = better compression but slower)
    level: process.env.NODE_ENV === 'production' ? 6 : 1,

    // Memory level (1-9, higher = more memory usage but better compression)
    memLevel: 8,

    // Custom filter function
    filter: (req, res) => {
        // Don't compress if client doesn't support it
        if (req.headers['x-no-compression']) {
            return false;
        }

        // Don't compress images, videos, or already compressed files
        const contentType = res.getHeader('Content-Type');
        if (contentType) {
            const type = contentType.split(';')[0];
            const skipTypes = [
                'image/',
                'video/',
                'audio/',
                'application/zip',
                'application/gzip',
                'application/pdf'
            ];

            if (skipTypes.some(skipType => type.startsWith(skipType))) {
                return false;
            }
        }

        // Use default compression filter
        return compression.filter(req, res);
    }
});

// Response optimization middleware
const optimizeResponse = (req, res, next) => {
    // Set caching headers for static-like content
    if (req.method === 'GET' && !req.originalUrl.includes('/api/')) {
        res.set('Cache-Control', 'public, max-age=31536000'); // 1 year
    }

    // API response optimizations
    if (req.originalUrl.startsWith('/api/')) {
        // Remove unnecessary headers
        res.removeHeader('X-Powered-By');
        
        // Set appropriate cache headers for API responses
        if (req.method === 'GET') {
            res.set('Cache-Control', 'public, max-age=300'); // 5 minutes
        } else {
            res.set('Cache-Control', 'no-cache, no-store, must-revalidate');
        }

        // Add ETag for conditional requests
        res.set('ETag', 'weak');
    }

    next();
};

module.exports = {
    smartCompression,
    optimizeResponse
};
```

## 🚀 Deployment Best Practices

### 1. Environment Configuration

**Production Environment Setup**
```javascript
// config/production.js
module.exports = {
    // Server configuration
    server: {
        port: process.env.PORT || 3000,
        host: process.env.HOST || '0.0.0.0',
        keepAliveTimeout: 65000,
        headersTimeout: 66000
    },

    // Database configuration
    database: {
        url: process.env.DATABASE_URL,
        options: {
            maxPoolSize: 20,
            minPoolSize: 5,
            maxIdleTimeMS: 30000,
            serverSelectionTimeoutMS: 5000,
            socketTimeoutMS: 45000,
            retryWrites: true,
            w: 'majority'
        }
    },

    // Redis configuration
    redis: {
        url: process.env.REDIS_URL,
        options: {
            maxRetriesPerRequest: 3,
            retryDelayOnFailover: 100,
            lazyConnect: true,
            keepAlive: 30000
        }
    },

    // Security configuration
    security: {
        jwt: {
            secret: process.env.JWT_SECRET,
            expiresIn: '1h',
            issuer: process.env.JWT_ISSUER,
            audience: process.env.JWT_AUDIENCE
        },
        cors: {
            origin: process.env.ALLOWED_ORIGINS?.split(','),
            credentials: true
        },
        rateLimit: {
            windowMs: 15 * 60 * 1000, // 15 minutes
            max: 100
        }
    },

    // Logging configuration
    logging: {
        level: 'info',
        format: 'json',
        destination: {
            file: '/var/log/app/app.log',
            maxSize: '10MB',
            maxFiles: 5
        }
    },

    // Monitoring configuration
    monitoring: {
        metrics: {
            enabled: true,
            endpoint: '/metrics'
        },
        health: {
            enabled: true,
            endpoint: '/health'
        },
        apm: {
            serviceName: process.env.APM_SERVICE_NAME,
            environment: 'production'
        }
    }
};
```

### 2. Health Checks & Monitoring

**Comprehensive Health Check System**
```javascript
// middleware/health.js
const mongoose = require('mongoose');
const redis = require('./redis');

class HealthChecker {
    constructor() {
        this.checks = new Map();
        this.setupDefaultChecks();
    }

    setupDefaultChecks() {
        // Database health check
        this.addCheck('database', async () => {
            const state = mongoose.connection.readyState;
            const states = {
                0: 'disconnected',
                1: 'connected',
                2: 'connecting',
                3: 'disconnecting'
            };

            if (state !== 1) {
                throw new Error(`Database ${states[state]}`);
            }

            // Test actual query
            await mongoose.connection.db.admin().ping();
            
            return {
                status: 'healthy',
                details: {
                    state: states[state],
                    host: mongoose.connection.host,
                    name: mongoose.connection.name
                }
            };
        });

        // Redis health check
        this.addCheck('redis', async () => {
            const result = await redis.ping();
            
            if (result !== 'PONG') {
                throw new Error('Redis ping failed');
            }

            return {
                status: 'healthy',
                details: {
                    connected: redis.status === 'ready',
                    commandsProcessed: await redis.info('stats')
                }
            };
        });

        // Memory health check
        this.addCheck('memory', async () => {
            const usage = process.memoryUsage();
            const totalMB = Math.round(usage.rss / 1024 / 1024);
            const heapMB = Math.round(usage.heapUsed / 1024 / 1024);
            
            // Alert if using more than 512MB
            if (totalMB > 512) {
                return {
                    status: 'warning',
                    details: {
                        total: `${totalMB}MB`,
                        heap: `${heapMB}MB`,
                        message: 'High memory usage detected'
                    }
                };
            }

            return {
                status: 'healthy',
                details: {
                    total: `${totalMB}MB`,
                    heap: `${heapMB}MB`
                }
            };
        });

        // Disk space check
        this.addCheck('disk', async () => {
            const stats = await this.getDiskStats();
            const usagePercent = ((stats.used / stats.total) * 100).toFixed(1);

            if (usagePercent > 90) {
                throw new Error(`Disk usage critical: ${usagePercent}%`);
            }

            if (usagePercent > 80) {
                return {
                    status: 'warning',
                    details: {
                        usage: `${usagePercent}%`,
                        free: `${Math.round(stats.free / 1024 / 1024 / 1024)}GB`,
                        message: 'High disk usage'
                    }
                };
            }

            return {
                status: 'healthy',
                details: {
                    usage: `${usagePercent}%`,
                    free: `${Math.round(stats.free / 1024 / 1024 / 1024)}GB`
                }
            };
        });
    }

    addCheck(name, checkFunction) {
        this.checks.set(name, checkFunction);
    }

    async runAllChecks() {
        const results = {};
        let overallStatus = 'healthy';

        for (const [name, checkFunction] of this.checks) {
            try {
                const result = await checkFunction();
                results[name] = result;
                
                if (result.status === 'warning' && overallStatus === 'healthy') {
                    overallStatus = 'warning';
                }
            } catch (error) {
                results[name] = {
                    status: 'unhealthy',
                    error: error.message,
                    details: {}
                };
                overallStatus = 'unhealthy';
            }
        }

        return {
            status: overallStatus,
            timestamp: new Date().toISOString(),
            uptime: process.uptime(),
            version: process.env.APP_VERSION || '1.0.0',
            environment: process.env.NODE_ENV,
            checks: results
        };
    }

    async getDiskStats() {
        const fs = require('fs').promises;
        const stats = await fs.statfs('.');
        
        return {
            total: stats.bavail * stats.bsize,
            free: stats.bfree * stats.bsize,
            used: (stats.bavail - stats.bfree) * stats.bsize
        };
    }
}

// Health check middleware
const healthChecker = new HealthChecker();

const healthCheck = async (req, res) => {
    try {
        const health = await healthChecker.runAllChecks();
        
        let statusCode = 200;
        if (health.status === 'warning') statusCode = 200;
        if (health.status === 'unhealthy') statusCode = 503;

        res.status(statusCode).json(health);
    } catch (error) {
        res.status(503).json({
            status: 'unhealthy',
            error: error.message,
            timestamp: new Date().toISOString()
        });
    }
};

module.exports = { healthChecker, healthCheck };
```

### 3. Graceful Shutdown

**Process Lifecycle Management**
```javascript
// server.js
const express = require('express');
const http = require('http');

class GracefulServer {
    constructor(app) {
        this.app = app;
        this.server = null;
        this.connections = new Set();
        this.isShuttingDown = false;
        this.setupGracefulShutdown();
    }

    start(port = 3000) {
        this.server = http.createServer(this.app);
        
        // Track connections
        this.server.on('connection', (connection) => {
            this.connections.add(connection);
            
            connection.on('close', () => {
                this.connections.delete(connection);
            });
        });

        // Handle server errors
        this.server.on('error', (error) => {
            if (error.code === 'EADDRINUSE') {
                console.error(`Port ${port} is already in use`);
                process.exit(1);
            } else {
                console.error('Server error:', error);
            }
        });

        this.server.listen(port, () => {
            console.log(`Server running on port ${port}`);
        });

        return this.server;
    }

    setupGracefulShutdown() {
        const signals = ['SIGTERM', 'SIGINT', 'SIGQUIT'];
        
        signals.forEach(signal => {
            process.on(signal, () => {
                console.log(`Received ${signal}, starting graceful shutdown...`);
                this.shutdown();
            });
        });

        // Handle uncaught exceptions
        process.on('uncaughtException', (error) => {
            console.error('Uncaught Exception:', error);
            this.shutdown(1);
        });

        // Handle unhandled promise rejections
        process.on('unhandledRejection', (reason, promise) => {
            console.error('Unhandled Rejection at:', promise, 'reason:', reason);
            this.shutdown(1);
        });
    }

    async shutdown(exitCode = 0) {
        if (this.isShuttingDown) {
            console.log('Shutdown already in progress...');
            return;
        }

        this.isShuttingDown = true;
        console.log('Starting graceful shutdown...');

        try {
            // Stop accepting new connections
            this.server.close(() => {
                console.log('HTTP server closed');
            });

            // Close existing connections gracefully
            console.log(`Closing ${this.connections.size} active connections...`);
            
            for (const connection of this.connections) {
                connection.destroy();
            }

            // Close database connections
            console.log('Closing database connections...');
            await this.closeDatabaseConnections();

            // Close Redis connections
            console.log('Closing Redis connections...');
            await this.closeRedisConnections();

            // Wait for any pending operations
            await this.waitForPendingOperations();

            console.log('Graceful shutdown completed');
            process.exit(exitCode);

        } catch (error) {
            console.error('Error during shutdown:', error);
            process.exit(1);
        }
    }

    async closeDatabaseConnections() {
        const mongoose = require('mongoose');
        if (mongoose.connection.readyState !== 0) {
            await mongoose.connection.close();
        }
    }

    async closeRedisConnections() {
        const redis = require('./config/redis');
        if (redis && redis.disconnect) {
            await redis.disconnect();
        }
    }

    async waitForPendingOperations() {
        // Wait for any background jobs or pending operations
        return new Promise(resolve => {
            setTimeout(resolve, 1000); // 1 second grace period
        });
    }
}

// Usage
const app = express();
const server = new GracefulServer(app);

// Setup your routes and middleware here
require('./routes')(app);
require('./middleware')(app);

// Start server
const PORT = process.env.PORT || 3000;
server.start(PORT);
```

## 🔗 Navigation

← [Tools & Libraries](./tools-libraries.md) | [Implementation Guide](./implementation-guide.md) →