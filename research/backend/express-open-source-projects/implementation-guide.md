# Implementation Guide: Building Production-Ready Express.js Applications

## 🚀 Overview

This comprehensive implementation guide provides step-by-step instructions for building secure, scalable Express.js applications based on patterns identified from 15+ production-grade open source projects.

## 🏗️ Project Setup and Architecture

### 1. **Initial Project Structure**

**Recommended Directory Structure** (based on 90% of analyzed projects):
```
my-express-app/
├── src/
│   ├── controllers/         # Request/response handling
│   ├── services/           # Business logic
│   ├── repositories/       # Data access layer
│   ├── models/            # Data models/schemas
│   ├── middleware/        # Custom middleware
│   ├── routes/            # Route definitions
│   ├── utils/             # Helper functions
│   ├── config/            # Configuration files
│   └── app.js             # Express app setup
├── tests/
│   ├── unit/              # Unit tests
│   ├── integration/       # Integration tests
│   └── e2e/               # End-to-end tests
├── docs/                  # API documentation
├── scripts/               # Build/deployment scripts
├── docker/                # Docker configurations
├── .env.example           # Environment variables template
├── .gitignore
├── package.json
├── README.md
└── server.js              # Entry point
```

### 2. **Package.json Setup**

```json
{
  "name": "my-express-app",
  "version": "1.0.0",
  "description": "Production-ready Express.js application",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js",
    "test": "jest",
    "test:unit": "jest tests/unit",
    "test:integration": "jest tests/integration",
    "test:e2e": "jest tests/e2e",
    "test:coverage": "jest --coverage",
    "lint": "eslint src/ tests/",
    "lint:fix": "eslint src/ tests/ --fix",
    "format": "prettier --write \"src/**/*.js\" \"tests/**/*.js\"",
    "build": "npm run lint && npm run test",
    "migrate": "node scripts/migrate.js",
    "seed": "node scripts/seed.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "express-rate-limit": "^6.7.0",
    "express-validator": "^6.15.0",
    "helmet": "^6.1.5",
    "cors": "^2.8.5",
    "jsonwebtoken": "^9.0.0",
    "bcrypt": "^5.1.0",
    "passport": "^0.6.0",
    "passport-jwt": "^4.0.1",
    "passport-local": "^1.0.0",
    "prisma": "^4.14.0",
    "@prisma/client": "^4.14.0",
    "redis": "^4.6.6",
    "winston": "^3.8.2",
    "dotenv": "^16.0.3",
    "compression": "^1.7.4",
    "morgan": "^1.10.0"
  },
  "devDependencies": {
    "nodemon": "^2.0.22",
    "jest": "^29.5.0",
    "supertest": "^6.3.3",
    "eslint": "^8.40.0",
    "prettier": "^2.8.8",
    "@types/jest": "^29.5.1",
    "husky": "^8.0.3",
    "lint-staged": "^13.2.2"
  },
  "engines": {
    "node": ">=18.0.0",
    "npm": ">=8.0.0"
  }
}
```

### 3. **Environment Configuration**

**.env.example**:
```bash
# Server Configuration
NODE_ENV=development
PORT=3000
HOST=localhost

# Database Configuration
DATABASE_URL="postgresql://username:password@localhost:5432/myapp"

# Redis Configuration
REDIS_URL="redis://localhost:6379"

# JWT Configuration
JWT_ACCESS_SECRET=your-super-secret-jwt-access-key-change-in-production
JWT_REFRESH_SECRET=your-super-secret-jwt-refresh-key-change-in-production
JWT_ISSUER=your-app-name
JWT_AUDIENCE=your-app-audience

# Session Configuration
SESSION_SECRET=your-super-secret-session-key-change-in-production

# Email Configuration
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASS=your-email-password

# External APIs
GOOGLE_CLIENT_ID=your-google-oauth-client-id
GOOGLE_CLIENT_SECRET=your-google-oauth-client-secret

# Frontend URLs
FRONTEND_URL=http://localhost:3000
ALLOWED_ORIGINS=http://localhost:3000,http://localhost:3001

# File Upload
MAX_FILE_SIZE=10485760
UPLOAD_PATH=uploads/

# Security
BCRYPT_ROUNDS=12
RATE_LIMIT_WINDOW_MS=900000
RATE_LIMIT_MAX_REQUESTS=100

# Monitoring
LOG_LEVEL=info
ENABLE_REQUEST_LOGGING=true
```

## 🔧 Core Application Setup

### 1. **Main Application File (src/app.js)**

```javascript
const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const compression = require('compression');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');

// Import configurations
const corsConfig = require('./config/cors');
const securityConfig = require('./config/security');
const rateLimitConfig = require('./config/rateLimit');

// Import middleware
const authMiddleware = require('./middleware/auth');
const errorHandler = require('./middleware/errorHandler');
const requestLogger = require('./middleware/requestLogger');

// Import routes
const authRoutes = require('./routes/auth');
const userRoutes = require('./routes/users');
const healthRoutes = require('./routes/health');

class Application {
  constructor() {
    this.app = express();
    this.setupMiddleware();
    this.setupRoutes();
    this.setupErrorHandling();
  }
  
  setupMiddleware() {
    // Security middleware
    this.app.use(helmet(securityConfig));
    this.app.use(cors(corsConfig));
    
    // Performance middleware
    this.app.use(compression());
    
    // Request parsing
    this.app.use(express.json({ limit: '10mb' }));
    this.app.use(express.urlencoded({ extended: true, limit: '10mb' }));
    
    // Logging
    if (process.env.NODE_ENV !== 'test') {
      this.app.use(morgan('combined'));
    }
    this.app.use(requestLogger);
    
    // Rate limiting
    this.app.use('/api/', rateLimit(rateLimitConfig.api));
    this.app.use('/api/auth/', rateLimit(rateLimitConfig.auth));
  }
  
  setupRoutes() {
    // Health check routes (no auth required)
    this.app.use('/health', healthRoutes);
    
    // Public API routes
    this.app.use('/api/auth', authRoutes);
    
    // Protected API routes
    this.app.use('/api/users', authMiddleware, userRoutes);
    
    // API documentation
    if (process.env.NODE_ENV !== 'production') {
      const swaggerUi = require('swagger-ui-express');
      const swaggerSpec = require('./config/swagger');
      this.app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerSpec));
    }
    
    // Catch-all route for SPA routing
    this.app.get('*', (req, res) => {
      if (req.path.startsWith('/api/')) {
        return res.status(404).json({ error: 'API endpoint not found' });
      }
      res.sendFile(path.join(__dirname, '../public/index.html'));
    });
  }
  
  setupErrorHandling() {
    // 404 handler for API routes
    this.app.use('/api/*', (req, res) => {
      res.status(404).json({
        error: 'API endpoint not found',
        path: req.path,
        method: req.method
      });
    });
    
    // Global error handler
    this.app.use(errorHandler);
  }
  
  getApp() {
    return this.app;
  }
}

module.exports = new Application().getApp();
```

### 2. **Server Entry Point (server.js)**

```javascript
require('dotenv').config();
const app = require('./src/app');
const logger = require('./src/utils/logger');
const { connectDatabase } = require('./src/config/database');
const { connectRedis } = require('./src/config/redis');

class Server {
  constructor() {
    this.port = process.env.PORT || 3000;
    this.host = process.env.HOST || 'localhost';
  }
  
  async start() {
    try {
      // Connect to external services
      await this.connectServices();
      
      // Start HTTP server
      this.server = app.listen(this.port, this.host, () => {
        logger.info(`Server running on http://${this.host}:${this.port}`);
        logger.info(`Environment: ${process.env.NODE_ENV}`);
        logger.info(`API Documentation: http://${this.host}:${this.port}/api-docs`);
      });
      
      // Graceful shutdown handling
      this.setupGracefulShutdown();
      
    } catch (error) {
      logger.error('Failed to start server:', error);
      process.exit(1);
    }
  }
  
  async connectServices() {
    logger.info('Connecting to external services...');
    
    try {
      await connectDatabase();
      logger.info('Database connected successfully');
      
      await connectRedis();
      logger.info('Redis connected successfully');
      
    } catch (error) {
      logger.error('Failed to connect to external services:', error);
      throw error;
    }
  }
  
  setupGracefulShutdown() {
    const shutdown = async (signal) => {
      logger.info(`Received ${signal}, shutting down gracefully...`);
      
      // Stop accepting new connections
      this.server.close(async () => {
        logger.info('HTTP server closed');
        
        try {
          // Close database connections
          await require('./src/config/database').disconnect();
          await require('./src/config/redis').disconnect();
          
          logger.info('All services disconnected');
          process.exit(0);
        } catch (error) {
          logger.error('Error during shutdown:', error);
          process.exit(1);
        }
      });
      
      // Force shutdown after 30 seconds
      setTimeout(() => {
        logger.error('Could not close connections in time, forcefully shutting down');
        process.exit(1);
      }, 30000);
    };
    
    process.on('SIGTERM', () => shutdown('SIGTERM'));
    process.on('SIGINT', () => shutdown('SIGINT'));
  }
}

// Start server if this file is run directly
if (require.main === module) {
  const server = new Server();
  server.start();
}

module.exports = Server;
```

## 🔐 Authentication Implementation

### 1. **JWT Service (src/services/jwtService.js)**

```javascript
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const logger = require('../utils/logger');

class JWTService {
  constructor() {
    this.accessTokenSecret = process.env.JWT_ACCESS_SECRET;
    this.refreshTokenSecret = process.env.JWT_REFRESH_SECRET;
    this.accessTokenExpiry = '15m';
    this.refreshTokenExpiry = '7d';
    this.issuer = process.env.JWT_ISSUER;
    this.audience = process.env.JWT_AUDIENCE;
  }
  
  generateTokenPair(user) {
    const jti = crypto.randomUUID();
    const now = Math.floor(Date.now() / 1000);
    
    const payload = {
      sub: user.id,
      email: user.email,
      name: user.name,
      roles: user.roles || [],
      jti,
      iat: now
    };
    
    const accessToken = jwt.sign(
      { ...payload, type: 'access' },
      this.accessTokenSecret,
      {
        expiresIn: this.accessTokenExpiry,
        issuer: this.issuer,
        audience: this.audience,
        algorithm: 'HS256'
      }
    );
    
    const refreshToken = jwt.sign(
      { sub: user.id, jti, type: 'refresh' },
      this.refreshTokenSecret,
      {
        expiresIn: this.refreshTokenExpiry,
        issuer: this.issuer,
        audience: this.audience,
        algorithm: 'HS256'
      }
    );
    
    return {
      accessToken,
      refreshToken,
      jti,
      expiresIn: this.accessTokenExpiry
    };
  }
  
  verifyAccessToken(token) {
    try {
      const decoded = jwt.verify(token, this.accessTokenSecret, {
        issuer: this.issuer,
        audience: this.audience,
        algorithms: ['HS256']
      });
      
      if (decoded.type !== 'access') {
        throw new Error('Invalid token type');
      }
      
      return decoded;
    } catch (error) {
      logger.debug('Token verification failed:', error.message);
      
      if (error.name === 'TokenExpiredError') {
        throw new Error('Token expired');
      }
      if (error.name === 'JsonWebTokenError') {
        throw new Error('Invalid token');
      }
      throw error;
    }
  }
  
  verifyRefreshToken(token) {
    try {
      const decoded = jwt.verify(token, this.refreshTokenSecret, {
        issuer: this.issuer,
        audience: this.audience,
        algorithms: ['HS256']
      });
      
      if (decoded.type !== 'refresh') {
        throw new Error('Invalid token type');
      }
      
      return decoded;
    } catch (error) {
      logger.debug('Refresh token verification failed:', error.message);
      throw new Error('Invalid refresh token');
    }
  }
}

module.exports = new JWTService();
```

### 2. **Authentication Middleware (src/middleware/auth.js)**

```javascript
const jwtService = require('../services/jwtService');
const userRepository = require('../repositories/userRepository');
const tokenBlacklist = require('../utils/tokenBlacklist');
const logger = require('../utils/logger');

const authenticateToken = async (req, res, next) => {
  try {
    // Extract token from Authorization header
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({
        error: 'Authentication required',
        message: 'Please provide a valid authorization token'
      });
    }
    
    const token = authHeader.slice(7); // Remove 'Bearer ' prefix
    
    // Verify and decode token
    const decoded = jwtService.verifyAccessToken(token);
    
    // Check if token is blacklisted
    const isBlacklisted = await tokenBlacklist.isBlacklisted(decoded.jti);
    if (isBlacklisted) {
      return res.status(401).json({
        error: 'Token revoked',
        message: 'This token has been revoked'
      });
    }
    
    // Get current user data
    const user = await userRepository.findById(decoded.sub);
    if (!user) {
      return res.status(401).json({
        error: 'User not found',
        message: 'The user associated with this token no longer exists'
      });
    }
    
    if (!user.isActive) {
      return res.status(401).json({
        error: 'Account deactivated',
        message: 'Your account has been deactivated'
      });
    }
    
    // Attach user and token info to request
    req.user = {
      id: user.id,
      email: user.email,
      name: user.name,
      roles: user.roles,
      permissions: user.permissions
    };
    req.token = {
      jti: decoded.jti,
      iat: decoded.iat,
      exp: decoded.exp
    };
    
    next();
    
  } catch (error) {
    logger.debug('Authentication failed:', error.message);
    
    if (error.message === 'Token expired') {
      return res.status(401).json({
        error: 'Token expired',
        message: 'Your session has expired, please login again'
      });
    }
    
    return res.status(401).json({
      error: 'Invalid token',
      message: 'Please provide a valid authorization token'
    });
  }
};

// Optional authentication middleware (doesn't fail if no token)
const optionalAuth = async (req, res, next) => {
  const authHeader = req.headers.authorization;
  
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return next();
  }
  
  try {
    const token = authHeader.slice(7);
    const decoded = jwtService.verifyAccessToken(token);
    
    const isBlacklisted = await tokenBlacklist.isBlacklisted(decoded.jti);
    if (isBlacklisted) {
      return next();
    }
    
    const user = await userRepository.findById(decoded.sub);
    if (user && user.isActive) {
      req.user = {
        id: user.id,
        email: user.email,
        name: user.name,
        roles: user.roles,
        permissions: user.permissions
      };
    }
  } catch (error) {
    // Silently fail for optional authentication
    logger.debug('Optional authentication failed:', error.message);
  }
  
  next();
};

module.exports = {
  authenticateToken,
  optionalAuth
};
```

## 🗄️ Database Layer Implementation

### 1. **Prisma Schema (prisma/schema.prisma)**

```prisma
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

model User {
  id                String   @id @default(cuid())
  email             String   @unique
  name              String
  password          String
  avatar            String?
  isEmailVerified   Boolean  @default(false)
  isActive          Boolean  @default(true)
  isLocked          Boolean  @default(false)
  lastLoginAt       DateTime?
  lastLoginIP       String?
  emailVerifiedAt   DateTime?
  passwordChangedAt DateTime?
  lockoutUntil      DateTime?
  loginAttempts     Int      @default(0)
  
  // MFA fields
  mfaEnabled        Boolean  @default(false)
  mfaSecret         String?
  mfaBackupCodes    String[]
  
  // OAuth fields
  googleId          String?  @unique
  githubId          String?  @unique
  
  // Refresh token hash for security
  refreshTokenHash  String?
  
  createdAt         DateTime @default(now())
  updatedAt         DateTime @updatedAt
  
  // Relations
  posts             Post[]
  sessions          Session[]
  
  @@map("users")
}

model Post {
  id          String   @id @default(cuid())
  title       String
  content     String
  published   Boolean  @default(false)
  slug        String   @unique
  
  authorId    String
  author      User     @relation(fields: [authorId], references: [id], onDelete: Cascade)
  
  createdAt   DateTime @default(now())
  updatedAt   DateTime @updatedAt
  
  @@map("posts")
}

model Session {
  id        String   @id @default(cuid())
  userId    String
  user      User     @relation(fields: [userId], references: [id], onDelete: Cascade)
  
  token     String   @unique
  expiresAt DateTime
  createdAt DateTime @default(now())
  
  @@map("sessions")
}

model BlacklistedToken {
  id        String   @id @default(cuid())
  jti       String   @unique
  expiresAt DateTime
  createdAt DateTime @default(now())
  
  @@map("blacklisted_tokens")
}
```

### 2. **Database Configuration (src/config/database.js)**

```javascript
const { PrismaClient } = require('@prisma/client');
const logger = require('../utils/logger');

class DatabaseManager {
  constructor() {
    this.prisma = new PrismaClient({
      log: process.env.NODE_ENV === 'development' 
        ? ['query', 'info', 'warn', 'error'] 
        : ['error'],
      errorFormat: 'pretty'
    });
    
    this.setupEventHandlers();
  }
  
  setupEventHandlers() {
    this.prisma.$on('error', (e) => {
      logger.error('Database error:', e);
    });
    
    this.prisma.$on('warn', (e) => {
      logger.warn('Database warning:', e);
    });
    
    if (process.env.NODE_ENV === 'development') {
      this.prisma.$on('query', (e) => {
        logger.debug(`Query: ${e.query} - Duration: ${e.duration}ms`);
      });
    }
  }
  
  async connect() {
    try {
      await this.prisma.$connect();
      logger.info('Database connected successfully');
      
      // Test the connection
      await this.prisma.$queryRaw`SELECT 1`;
      
    } catch (error) {
      logger.error('Failed to connect to database:', error);
      throw error;
    }
  }
  
  async disconnect() {
    try {
      await this.prisma.$disconnect();
      logger.info('Database disconnected');
    } catch (error) {
      logger.error('Error disconnecting from database:', error);
      throw error;
    }
  }
  
  getClient() {
    return this.prisma;
  }
}

const databaseManager = new DatabaseManager();

module.exports = {
  prisma: databaseManager.getClient(),
  connectDatabase: () => databaseManager.connect(),
  disconnect: () => databaseManager.disconnect()
};
```

### 3. **Repository Pattern Implementation**

```javascript
// src/repositories/userRepository.js
const { prisma } = require('../config/database');
const bcrypt = require('bcrypt');
const logger = require('../utils/logger');

class UserRepository {
  async findById(id) {
    try {
      return await prisma.user.findUnique({
        where: { id },
        select: {
          id: true,
          email: true,
          name: true,
          avatar: true,
          isEmailVerified: true,
          isActive: true,
          isLocked: true,
          lastLoginAt: true,
          mfaEnabled: true,
          createdAt: true,
          updatedAt: true,
          // Don't select sensitive fields by default
          password: false,
          mfaSecret: false,
          refreshTokenHash: false
        }
      });
    } catch (error) {
      logger.error('Error finding user by ID:', error);
      throw error;
    }
  }
  
  async findByEmail(email) {
    try {
      return await prisma.user.findUnique({
        where: { 
          email: email.toLowerCase().trim() 
        }
      });
    } catch (error) {
      logger.error('Error finding user by email:', error);
      throw error;
    }
  }
  
  async create(userData) {
    try {
      const hashedPassword = await bcrypt.hash(userData.password, 12);
      
      const user = await prisma.user.create({
        data: {
          ...userData,
          email: userData.email.toLowerCase().trim(),
          password: hashedPassword
        },
        select: {
          id: true,
          email: true,
          name: true,
          avatar: true,
          isEmailVerified: true,
          isActive: true,
          createdAt: true
        }
      });
      
      logger.info(`User created: ${user.email}`);
      return user;
      
    } catch (error) {
      if (error.code === 'P2002') {
        throw new Error('User with this email already exists');
      }
      logger.error('Error creating user:', error);
      throw error;
    }
  }
  
  async update(id, updateData) {
    try {
      // Hash password if it's being updated
      if (updateData.password) {
        updateData.password = await bcrypt.hash(updateData.password, 12);
        updateData.passwordChangedAt = new Date();
      }
      
      return await prisma.user.update({
        where: { id },
        data: {
          ...updateData,
          updatedAt: new Date()
        },
        select: {
          id: true,
          email: true,
          name: true,
          avatar: true,
          isEmailVerified: true,
          isActive: true,
          updatedAt: true
        }
      });
    } catch (error) {
      if (error.code === 'P2025') {
        throw new Error('User not found');
      }
      logger.error('Error updating user:', error);
      throw error;
    }
  }
  
  async delete(id) {
    try {
      await prisma.user.delete({
        where: { id }
      });
      logger.info(`User deleted: ${id}`);
    } catch (error) {
      if (error.code === 'P2025') {
        throw new Error('User not found');
      }
      logger.error('Error deleting user:', error);
      throw error;
    }
  }
  
  async findMany(options = {}) {
    try {
      const {
        page = 1,
        limit = 10,
        search,
        isActive,
        orderBy = 'createdAt',
        orderDirection = 'desc'
      } = options;
      
      const where = {
        ...(search && {
          OR: [
            { name: { contains: search, mode: 'insensitive' } },
            { email: { contains: search, mode: 'insensitive' } }
          ]
        }),
        ...(isActive !== undefined && { isActive })
      };
      
      const [users, total] = await Promise.all([
        prisma.user.findMany({
          where,
          select: {
            id: true,
            email: true,
            name: true,
            avatar: true,
            isEmailVerified: true,
            isActive: true,
            lastLoginAt: true,
            createdAt: true
          },
          orderBy: { [orderBy]: orderDirection },
          skip: (page - 1) * limit,
          take: limit
        }),
        prisma.user.count({ where })
      ]);
      
      return {
        users,
        pagination: {
          page,
          limit,
          total,
          pages: Math.ceil(total / limit)
        }
      };
    } catch (error) {
      logger.error('Error finding users:', error);
      throw error;
    }
  }
  
  async verifyPassword(user, password) {
    try {
      return await bcrypt.compare(password, user.password);
    } catch (error) {
      logger.error('Error verifying password:', error);
      throw error;
    }
  }
}

module.exports = new UserRepository();
```

## 🔒 Security Implementation

### 1. **Input Validation (src/middleware/validation.js)**

```javascript
const { body, param, query, validationResult } = require('express-validator');
const rateLimit = require('express-rate-limit');

// Common validation rules
const emailValidation = body('email')
  .isEmail()
  .withMessage('Please provide a valid email address')
  .normalizeEmail()
  .isLength({ max: 320 })
  .withMessage('Email address is too long');

const passwordValidation = body('password')
  .isLength({ min: 8, max: 128 })
  .withMessage('Password must be between 8 and 128 characters')
  .matches(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]/)
  .withMessage('Password must contain at least one uppercase letter, one lowercase letter, one number, and one special character');

const nameValidation = body('name')
  .trim()
  .isLength({ min: 2, max: 100 })
  .withMessage('Name must be between 2 and 100 characters')
  .matches(/^[a-zA-Z\s\-']+$/)
  .withMessage('Name can only contain letters, spaces, hyphens, and apostrophes');

// Validation schemas
const registerValidation = [
  emailValidation,
  passwordValidation,
  nameValidation,
  
  body('confirmPassword')
    .custom((value, { req }) => {
      if (value !== req.body.password) {
        throw new Error('Password confirmation does not match password');
      }
      return true;
    })
];

const loginValidation = [
  emailValidation,
  body('password')
    .notEmpty()
    .withMessage('Password is required'),
  
  body('rememberMe')
    .optional()
    .isBoolean()
    .withMessage('Remember me must be a boolean')
];

const updateProfileValidation = [
  body('name')
    .optional()
    .trim()
    .isLength({ min: 2, max: 100 })
    .withMessage('Name must be between 2 and 100 characters'),
  
  body('avatar')
    .optional()
    .isURL()
    .withMessage('Avatar must be a valid URL')
];

const changePasswordValidation = [
  body('currentPassword')
    .notEmpty()
    .withMessage('Current password is required'),
  
  passwordValidation.custom((value, { req }) => {
    if (value === req.body.currentPassword) {
      throw new Error('New password must be different from current password');
    }
    return true;
  }),
  
  body('confirmPassword')
    .custom((value, { req }) => {
      if (value !== req.body.password) {
        throw new Error('Password confirmation does not match password');
      }
      return true;
    })
];

// Validation middleware
const handleValidationErrors = (req, res, next) => {
  const errors = validationResult(req);
  
  if (!errors.isEmpty()) {
    return res.status(400).json({
      error: 'Validation failed',
      details: errors.array().map(err => ({
        field: err.path,
        message: err.msg,
        value: err.value
      }))
    });
  }
  
  next();
};

// Rate limiting for validation-heavy endpoints
const validationRateLimit = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 20, // limit each IP to 20 validation requests per windowMs
  message: {
    error: 'Too many validation requests',
    message: 'Please slow down your requests'
  },
  standardHeaders: true,
  legacyHeaders: false
});

module.exports = {
  registerValidation,
  loginValidation,
  updateProfileValidation,
  changePasswordValidation,
  handleValidationErrors,
  validationRateLimit
};
```

---

**Next**: [Best Practices](./best-practices.md) | **Previous**: [Testing Strategies](./testing-strategies.md)