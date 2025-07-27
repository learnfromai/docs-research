# Template Examples & Starter Code

## 🎯 Overview

This document provides complete, working code templates and examples derived from patterns found in production Express.js applications. These templates can be used as starting points for new projects or reference implementations.

## 🚀 Complete Application Templates

### 1. **Minimal Express.js API Template**

A lightweight starter template based on patterns from Parse Server and Botpress.

**Directory Structure**:
```
minimal-express-api/
├── src/
│   ├── controllers/
│   │   ├── authController.js
│   │   └── userController.js
│   ├── middleware/
│   │   ├── auth.js
│   │   ├── errorHandler.js
│   │   └── validation.js
│   ├── routes/
│   │   ├── auth.js
│   │   └── users.js
│   ├── services/
│   │   ├── authService.js
│   │   └── userService.js
│   ├── utils/
│   │   ├── logger.js
│   │   └── helpers.js
│   ├── config/
│   │   ├── database.js
│   │   └── security.js
│   └── app.js
├── tests/
├── .env.example
├── package.json
└── server.js
```

**Complete Implementation**:

**package.json**:
```json
{
  "name": "minimal-express-api",
  "version": "1.0.0",
  "description": "Production-ready minimal Express.js API",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js",
    "test": "jest",
    "test:watch": "jest --watch",
    "lint": "eslint src/ --fix"
  },
  "dependencies": {
    "express": "^4.18.2",
    "helmet": "^6.1.5",
    "cors": "^2.8.5",
    "morgan": "^1.10.0",
    "compression": "^1.7.4",
    "express-rate-limit": "^6.7.0",
    "express-validator": "^6.15.0",
    "jsonwebtoken": "^9.0.0",
    "bcrypt": "^5.1.0",
    "prisma": "^4.14.0",
    "@prisma/client": "^4.14.0",
    "winston": "^3.8.2",
    "dotenv": "^16.0.3"
  },
  "devDependencies": {
    "nodemon": "^2.0.22",
    "jest": "^29.5.0",
    "supertest": "^6.3.3",
    "eslint": "^8.40.0",
    "prettier": "^2.8.8"
  }
}
```

**server.js**:
```javascript
require('dotenv').config();
const app = require('./src/app');
const logger = require('./src/utils/logger');
const { connectDatabase } = require('./src/config/database');

const PORT = process.env.PORT || 3000;
const HOST = process.env.HOST || 'localhost';

async function startServer() {
  try {
    // Connect to database
    await connectDatabase();
    
    // Start server
    app.listen(PORT, HOST, () => {
      logger.info(`Server running on http://${HOST}:${PORT}`);
      logger.info(`Environment: ${process.env.NODE_ENV}`);
    });
  } catch (error) {
    logger.error('Failed to start server:', error);
    process.exit(1);
  }
}

startServer();
```

**src/app.js**:
```javascript
const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const morgan = require('morgan');
const compression = require('compression');
const rateLimit = require('express-rate-limit');

// Import routes
const authRoutes = require('./routes/auth');
const userRoutes = require('./routes/users');

// Import middleware
const errorHandler = require('./middleware/errorHandler');
const { authenticateToken } = require('./middleware/auth');

const app = express();

// Security middleware
app.use(helmet());
app.use(cors({
  origin: process.env.ALLOWED_ORIGINS?.split(',') || 'http://localhost:3000',
  credentials: true
}));

// Performance middleware
app.use(compression());

// Logging
if (process.env.NODE_ENV !== 'test') {
  app.use(morgan('combined'));
}

// Rate limiting
app.use('/api/', rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100,
  message: 'Too many requests from this IP'
}));

// Body parsing
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Health check
app.get('/health', (req, res) => {
  res.json({ 
    status: 'healthy', 
    timestamp: new Date().toISOString(),
    version: process.env.npm_package_version || '1.0.0'
  });
});

// API routes
app.use('/api/auth', authRoutes);
app.use('/api/users', authenticateToken, userRoutes);

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({
    error: 'Not Found',
    message: `Route ${req.originalUrl} not found`,
    timestamp: new Date().toISOString()
  });
});

// Error handler (must be last)
app.use(errorHandler);

module.exports = app;
```

**src/controllers/authController.js**:
```javascript
const authService = require('../services/authService');
const { validationResult } = require('express-validator');
const logger = require('../utils/logger');

class AuthController {
  async register(req, res, next) {
    try {
      // Check validation results
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({
          error: 'Validation failed',
          details: errors.array()
        });
      }

      const { email, password, name } = req.body;
      
      const result = await authService.register({ email, password, name });
      
      logger.info(`User registered: ${email}`);
      
      res.status(201).json({
        message: 'User registered successfully',
        user: result.user,
        accessToken: result.accessToken
      });
    } catch (error) {
      next(error);
    }
  }

  async login(req, res, next) {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({
          error: 'Validation failed',
          details: errors.array()
        });
      }

      const { email, password } = req.body;
      
      const result = await authService.login(email, password);
      
      logger.info(`User logged in: ${email}`);
      
      res.json({
        message: 'Login successful',
        user: result.user,
        accessToken: result.accessToken,
        expiresIn: '1h'
      });
    } catch (error) {
      next(error);
    }
  }

  async refreshToken(req, res, next) {
    try {
      const { refreshToken } = req.body;
      
      if (!refreshToken) {
        return res.status(400).json({
          error: 'Refresh token required'
        });
      }
      
      const result = await authService.refreshToken(refreshToken);
      
      res.json({
        accessToken: result.accessToken,
        expiresIn: '1h'
      });
    } catch (error) {
      next(error);
    }
  }

  async logout(req, res, next) {
    try {
      await authService.logout(req.user.jti);
      
      logger.info(`User logged out: ${req.user.email}`);
      
      res.json({
        message: 'Logout successful'
      });
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new AuthController();
```

**src/services/authService.js**:
```javascript
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const { prisma } = require('../config/database');
const logger = require('../utils/logger');

class AuthService {
  constructor() {
    this.jwtSecret = process.env.JWT_SECRET;
    this.jwtExpiresIn = process.env.JWT_EXPIRES_IN || '1h';
    this.refreshTokenSecret = process.env.JWT_REFRESH_SECRET;
    this.refreshTokenExpiresIn = process.env.JWT_REFRESH_EXPIRES_IN || '7d';
  }

  async register(userData) {
    const { email, password, name } = userData;

    // Check if user already exists
    const existingUser = await prisma.user.findUnique({
      where: { email: email.toLowerCase() }
    });

    if (existingUser) {
      throw new Error('User with this email already exists');
    }

    // Hash password
    const hashedPassword = await bcrypt.hash(password, 12);

    // Create user
    const user = await prisma.user.create({
      data: {
        email: email.toLowerCase(),
        name,
        password: hashedPassword,
        isEmailVerified: false,
        isActive: true
      },
      select: {
        id: true,
        email: true,
        name: true,
        isEmailVerified: true,
        isActive: true,
        createdAt: true
      }
    });

    // Generate tokens
    const tokens = this.generateTokenPair(user);

    return {
      user,
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken
    };
  }

  async login(email, password) {
    // Find user
    const user = await prisma.user.findUnique({
      where: { email: email.toLowerCase() }
    });

    if (!user) {
      throw new Error('Invalid credentials');
    }

    // Check password
    const isValidPassword = await bcrypt.compare(password, user.password);
    if (!isValidPassword) {
      throw new Error('Invalid credentials');
    }

    // Check if user is active
    if (!user.isActive) {
      throw new Error('Account is deactivated');
    }

    // Update last login
    await prisma.user.update({
      where: { id: user.id },
      data: { lastLoginAt: new Date() }
    });

    // Generate tokens
    const tokens = this.generateTokenPair(user);

    // Return user without password
    const { password: _, ...userWithoutPassword } = user;

    return {
      user: userWithoutPassword,
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken
    };
  }

  generateTokenPair(user) {
    const jti = crypto.randomUUID();
    
    const payload = {
      sub: user.id,
      email: user.email,
      name: user.name,
      jti
    };

    const accessToken = jwt.sign(
      payload,
      this.jwtSecret,
      { 
        expiresIn: this.jwtExpiresIn,
        issuer: 'minimal-express-api',
        audience: 'api-users'
      }
    );

    const refreshToken = jwt.sign(
      { sub: user.id, jti },
      this.refreshTokenSecret,
      { 
        expiresIn: this.refreshTokenExpiresIn,
        issuer: 'minimal-express-api',
        audience: 'api-users'
      }
    );

    return { accessToken, refreshToken, jti };
  }

  async refreshToken(refreshToken) {
    try {
      const decoded = jwt.verify(refreshToken, this.refreshTokenSecret);
      
      const user = await prisma.user.findUnique({
        where: { id: decoded.sub },
        select: {
          id: true,
          email: true,
          name: true,
          isActive: true
        }
      });

      if (!user || !user.isActive) {
        throw new Error('User not found or inactive');
      }

      const tokens = this.generateTokenPair(user);
      
      return {
        accessToken: tokens.accessToken
      };
    } catch (error) {
      throw new Error('Invalid refresh token');
    }
  }

  async logout(jti) {
    // In a production app, you would blacklist the token
    // For simplicity, we'll just log the logout
    logger.info(`Token ${jti} logged out`);
  }
}

module.exports = new AuthService();
```

**src/middleware/auth.js**:
```javascript
const jwt = require('jsonwebtoken');
const { prisma } = require('../config/database');
const logger = require('../utils/logger');

const authenticateToken = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({
        error: 'Authentication required',
        message: 'Please provide a valid authorization token'
      });
    }

    const token = authHeader.slice(7);
    
    const decoded = jwt.verify(token, process.env.JWT_SECRET, {
      issuer: 'minimal-express-api',
      audience: 'api-users'
    });

    // Get current user data
    const user = await prisma.user.findUnique({
      where: { id: decoded.sub },
      select: {
        id: true,
        email: true,
        name: true,
        isActive: true,
        isEmailVerified: true
      }
    });

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

    req.user = {
      ...user,
      jti: decoded.jti
    };

    next();
  } catch (error) {
    logger.debug('Authentication failed:', error.message);
    
    if (error.name === 'TokenExpiredError') {
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

module.exports = {
  authenticateToken
};
```

**src/middleware/errorHandler.js**:
```javascript
const logger = require('../utils/logger');

class AppError extends Error {
  constructor(message, statusCode = 500) {
    super(message);
    this.statusCode = statusCode;
    this.isOperational = true;
    
    Error.captureStackTrace(this, this.constructor);
  }
}

const errorHandler = (err, req, res, next) => {
  // Log error
  logger.error('Error occurred:', {
    message: err.message,
    stack: err.stack,
    url: req.url,
    method: req.method,
    ip: req.ip,
    userAgent: req.get('User-Agent'),
    userId: req.user?.id
  });

  // Operational errors - safe to send to client
  if (err.isOperational) {
    return res.status(err.statusCode).json({
      error: err.message,
      timestamp: new Date().toISOString(),
      path: req.path
    });
  }

  // Programming errors - don't leak error details
  if (process.env.NODE_ENV === 'development') {
    return res.status(500).json({
      error: err.message,
      stack: err.stack,
      timestamp: new Date().toISOString(),
      path: req.path
    });
  }

  res.status(500).json({
    error: 'Internal server error',
    message: 'Something went wrong on our end',
    timestamp: new Date().toISOString(),
    path: req.path
  });
};

module.exports = errorHandler;
module.exports.AppError = AppError;
```

**src/routes/auth.js**:
```javascript
const express = require('express');
const { body } = require('express-validator');
const authController = require('../controllers/authController');
const rateLimit = require('express-rate-limit');

const router = express.Router();

// Rate limiting for auth endpoints
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 5, // limit each IP to 5 requests per windowMs
  message: 'Too many authentication attempts, please try again later'
});

// Validation rules
const registerValidation = [
  body('email')
    .isEmail()
    .normalizeEmail()
    .withMessage('Please provide a valid email'),
  body('password')
    .isLength({ min: 8 })
    .withMessage('Password must be at least 8 characters long')
    .matches(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]/)
    .withMessage('Password must contain uppercase, lowercase, number, and special character'),
  body('name')
    .trim()
    .isLength({ min: 2, max: 50 })
    .withMessage('Name must be between 2 and 50 characters')
];

const loginValidation = [
  body('email')
    .isEmail()
    .normalizeEmail()
    .withMessage('Please provide a valid email'),
  body('password')
    .notEmpty()
    .withMessage('Password is required')
];

// Routes
router.post('/register', registerValidation, authController.register);
router.post('/login', authLimiter, loginValidation, authController.login);
router.post('/refresh', authController.refreshToken);
router.post('/logout', require('../middleware/auth').authenticateToken, authController.logout);

module.exports = router;
```

**src/config/database.js**:
```javascript
const { PrismaClient } = require('@prisma/client');
const logger = require('../utils/logger');

const prisma = new PrismaClient({
  log: process.env.NODE_ENV === 'development' 
    ? ['query', 'info', 'warn', 'error'] 
    : ['error']
});

const connectDatabase = async () => {
  try {
    await prisma.$connect();
    logger.info('Database connected successfully');
    
    // Test the connection
    await prisma.$queryRaw`SELECT 1`;
  } catch (error) {
    logger.error('Failed to connect to database:', error);
    throw error;
  }
};

const disconnectDatabase = async () => {
  try {
    await prisma.$disconnect();
    logger.info('Database disconnected');
  } catch (error) {
    logger.error('Error disconnecting from database:', error);
  }
};

module.exports = {
  prisma,
  connectDatabase,
  disconnectDatabase
};
```

**src/utils/logger.js**:
```javascript
const winston = require('winston');

const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  defaultMeta: { 
    service: 'minimal-express-api',
    version: process.env.npm_package_version || '1.0.0'
  },
  transports: [
    new winston.transports.File({ 
      filename: 'logs/error.log', 
      level: 'error' 
    }),
    new winston.transports.File({ 
      filename: 'logs/combined.log' 
    })
  ]
});

// Add console transport for non-production environments
if (process.env.NODE_ENV !== 'production') {
  logger.add(new winston.transports.Console({
    format: winston.format.combine(
      winston.format.colorize(),
      winston.format.simple()
    )
  }));
}

module.exports = logger;
```

**prisma/schema.prisma**:
```prisma
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

model User {
  id              String    @id @default(cuid())
  email           String    @unique
  name            String
  password        String
  isEmailVerified Boolean   @default(false)
  isActive        Boolean   @default(true)
  lastLoginAt     DateTime?
  createdAt       DateTime  @default(now())
  updatedAt       DateTime  @updatedAt

  @@map("users")
}
```

**.env.example**:
```bash
# Database
DATABASE_URL="postgresql://username:password@localhost:5432/minimal_api?schema=public"

# JWT
JWT_SECRET="your-super-secret-jwt-key-change-in-production"
JWT_EXPIRES_IN="1h"
JWT_REFRESH_SECRET="your-super-secret-refresh-key-change-in-production"
JWT_REFRESH_EXPIRES_IN="7d"

# Server
NODE_ENV="development"
PORT=3000
HOST="localhost"
LOG_LEVEL="info"

# CORS
ALLOWED_ORIGINS="http://localhost:3000,http://localhost:3001"
```

---

### 2. **Enterprise Express.js Template**

A comprehensive template with advanced features based on patterns from GitLab, Discourse, and Rocket.Chat.

**Additional Features**:
- Role-based access control (RBAC)
- Multi-factor authentication (MFA)
- Advanced caching with Redis
- Comprehensive testing setup
- API documentation with Swagger
- Docker configuration
- CI/CD pipeline

**Extended package.json**:
```json
{
  "name": "enterprise-express-api",
  "version": "1.0.0",
  "dependencies": {
    "express": "^4.18.2",
    "helmet": "^6.1.5",
    "cors": "^2.8.5",
    "morgan": "^1.10.0",
    "compression": "^1.7.4",
    "express-rate-limit": "^6.7.0",
    "express-validator": "^6.15.0",
    "jsonwebtoken": "^9.0.0",
    "bcrypt": "^5.1.0",
    "speakeasy": "^2.0.0",
    "qrcode": "^1.5.3",
    "passport": "^0.6.0",
    "passport-local": "^1.0.0",
    "passport-jwt": "^4.0.1",
    "passport-google-oauth20": "^2.0.0",
    "prisma": "^4.14.0",
    "@prisma/client": "^4.14.0",
    "redis": "^4.6.6",
    "winston": "^3.8.2",
    "dotenv": "^16.0.3",
    "joi": "^17.9.2",
    "swagger-jsdoc": "^6.2.8",
    "swagger-ui-express": "^4.6.3",
    "nodemailer": "^6.9.2"
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
  }
}
```

**docker-compose.yml**:
```yaml
version: '3.8'

services:
  app:
    build: .
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
      - DATABASE_URL=postgresql://user:password@db:5432/enterprise_api
      - REDIS_URL=redis://redis:6379
    depends_on:
      - db
      - redis
    volumes:
      - ./logs:/app/logs

  db:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: enterprise_api
      POSTGRES_USER: user
      POSTGRES_PASSWORD: password
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
      - ./ssl:/etc/nginx/ssl
    depends_on:
      - app

volumes:
  postgres_data:
  redis_data:
```

**Dockerfile**:
```dockerfile
FROM node:18-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production

# Copy source code
COPY . .

# Generate Prisma client
RUN npx prisma generate

# Create logs directory
RUN mkdir -p logs

# Create non-root user
RUN addgroup -g 1001 -S nodejs
RUN adduser -S nodejs -u 1001

# Change ownership
RUN chown -R nodejs:nodejs /app
USER nodejs

EXPOSE 3000

CMD ["npm", "start"]
```

**.github/workflows/ci.yml**:
```yaml
name: CI/CD Pipeline

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest

    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_PASSWORD: postgres
          POSTGRES_DB: test_db
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 5432:5432

      redis:
        image: redis:7
        options: >-
          --health-cmd "redis-cli ping"
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
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

    - name: Run tests
      run: npm test
      env:
        DATABASE_URL: postgresql://postgres:postgres@localhost:5432/test_db
        REDIS_URL: redis://localhost:6379
        JWT_SECRET: test-secret
        JWT_REFRESH_SECRET: test-refresh-secret

    - name: Upload coverage to Codecov
      uses: codecov/codecov-action@v3

  build:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'

    steps:
    - uses: actions/checkout@v3

    - name: Build Docker image
      run: docker build -t enterprise-express-api .

    - name: Run security scan
      uses: aquasecurity/trivy-action@master
      with:
        image-ref: 'enterprise-express-api'
        format: 'sarif'
        output: 'trivy-results.sarif'

    - name: Upload Trivy scan results to GitHub Security tab
      uses: github/codeql-action/upload-sarif@v2
      with:
        sarif_file: 'trivy-results.sarif'
```

---

### 3. **Microservices Template**

A template for microservices architecture based on patterns from Sentry and GitLab.

**service-template/package.json**:
```json
{
  "name": "microservice-template",
  "version": "1.0.0",
  "dependencies": {
    "express": "^4.18.2",
    "helmet": "^6.1.5",
    "cors": "^2.8.5",
    "express-rate-limit": "^6.7.0",
    "jsonwebtoken": "^9.0.0",
    "axios": "^1.4.0",
    "winston": "^3.8.2",
    "dotenv": "^16.0.3",
    "consul": "^0.47.0",
    "amqplib": "^0.10.3"
  }
}
```

**src/app.js**:
```javascript
const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const consul = require('consul')();
const logger = require('./utils/logger');

class MicroserviceApp {
  constructor(serviceName, port) {
    this.serviceName = serviceName;
    this.port = port;
    this.app = express();
    this.serviceId = `${serviceName}-${process.env.HOSTNAME || 'local'}-${port}`;
    
    this.setupMiddleware();
    this.setupRoutes();
    this.setupHealthCheck();
  }

  setupMiddleware() {
    this.app.use(helmet());
    this.app.use(cors());
    this.app.use(express.json());
    
    // Request tracing
    this.app.use((req, res, next) => {
      req.traceId = req.headers['x-trace-id'] || require('crypto').randomUUID();
      res.setHeader('X-Trace-ID', req.traceId);
      logger.info('Request received', {
        traceId: req.traceId,
        method: req.method,
        url: req.url,
        service: this.serviceName
      });
      next();
    });
  }

  setupRoutes() {
    // Service-specific routes will be added here
    this.app.get('/api/status', (req, res) => {
      res.json({
        service: this.serviceName,
        version: process.env.SERVICE_VERSION || '1.0.0',
        timestamp: new Date().toISOString(),
        uptime: process.uptime()
      });
    });
  }

  setupHealthCheck() {
    this.app.get('/health', async (req, res) => {
      try {
        // Check dependencies (database, cache, etc.)
        const healthChecks = await this.performHealthChecks();
        
        const isHealthy = healthChecks.every(check => check.status === 'healthy');
        
        res.status(isHealthy ? 200 : 503).json({
          service: this.serviceName,
          status: isHealthy ? 'healthy' : 'unhealthy',
          checks: healthChecks,
          timestamp: new Date().toISOString()
        });
      } catch (error) {
        res.status(503).json({
          service: this.serviceName,
          status: 'unhealthy',
          error: error.message,
          timestamp: new Date().toISOString()
        });
      }
    });
  }

  async performHealthChecks() {
    // Override in specific services
    return [
      { name: 'app', status: 'healthy' }
    ];
  }

  async start() {
    try {
      // Register with service discovery
      await this.registerService();
      
      // Start server
      this.server = this.app.listen(this.port, () => {
        logger.info(`${this.serviceName} service started on port ${this.port}`);
      });

      // Graceful shutdown
      process.on('SIGTERM', () => this.shutdown());
      process.on('SIGINT', () => this.shutdown());

    } catch (error) {
      logger.error(`Failed to start ${this.serviceName}:`, error);
      process.exit(1);
    }
  }

  async registerService() {
    try {
      await consul.agent.service.register({
        id: this.serviceId,
        name: this.serviceName,
        tags: ['api', 'microservice'],
        address: process.env.SERVICE_HOST || 'localhost',
        port: this.port,
        check: {
          http: `http://${process.env.SERVICE_HOST || 'localhost'}:${this.port}/health`,
          interval: '10s',
          timeout: '3s'
        }
      });
      
      logger.info(`Service ${this.serviceId} registered with Consul`);
    } catch (error) {
      logger.error('Failed to register service:', error);
    }
  }

  async shutdown() {
    logger.info(`Shutting down ${this.serviceName}...`);
    
    try {
      // Deregister from service discovery
      await consul.agent.service.deregister(this.serviceId);
      
      // Close server
      this.server.close(() => {
        logger.info(`${this.serviceName} shut down gracefully`);
        process.exit(0);
      });
    } catch (error) {
      logger.error('Error during shutdown:', error);
      process.exit(1);
    }
  }
}

module.exports = MicroserviceApp;
```

---

### 4. **Testing Templates**

**Complete Test Suite Template**:

**tests/setup.js**:
```javascript
const { MongoMemoryServer } = require('mongodb-memory-server');
const { execSync } = require('child_process');

let mongod;

beforeAll(async () => {
  // Start in-memory MongoDB
  mongod = await MongoMemoryServer.create();
  process.env.DATABASE_URL = mongod.getUri();
  
  // Run migrations
  execSync('npx prisma db push', { stdio: 'inherit' });
}, 30000);

afterAll(async () => {
  await mongod.stop();
});

beforeEach(async () => {
  // Clean database between tests
  const { prisma } = require('../src/config/database');
  await prisma.user.deleteMany();
});
```

**tests/integration/auth.test.js**:
```javascript
const request = require('supertest');
const app = require('../../src/app');

describe('Authentication Integration Tests', () => {
  describe('POST /api/auth/register', () => {
    it('should register a new user', async () => {
      const userData = {
        email: 'test@example.com',
        name: 'Test User',
        password: 'TestPassword123!'
      };

      const response = await request(app)
        .post('/api/auth/register')
        .send(userData)
        .expect(201);

      expect(response.body).toMatchObject({
        message: 'User registered successfully',
        user: {
          email: userData.email,
          name: userData.name
        },
        accessToken: expect.any(String)
      });

      expect(response.body.user).not.toHaveProperty('password');
    });

    it('should not register user with invalid email', async () => {
      const response = await request(app)
        .post('/api/auth/register')
        .send({
          email: 'invalid-email',
          name: 'Test User',
          password: 'TestPassword123!'
        })
        .expect(400);

      expect(response.body.error).toBe('Validation failed');
    });

    it('should not register user with weak password', async () => {
      const response = await request(app)
        .post('/api/auth/register')
        .send({
          email: 'test@example.com',
          name: 'Test User',
          password: 'weak'
        })
        .expect(400);

      expect(response.body.error).toBe('Validation failed');
    });
  });

  describe('POST /api/auth/login', () => {
    beforeEach(async () => {
      // Create test user
      await request(app)
        .post('/api/auth/register')
        .send({
          email: 'test@example.com',
          name: 'Test User',
          password: 'TestPassword123!'
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

      expect(response.body).toMatchObject({
        message: 'Login successful',
        user: expect.any(Object),
        accessToken: expect.any(String)
      });
    });

    it('should not login with invalid credentials', async () => {
      const response = await request(app)
        .post('/api/auth/login')
        .send({
          email: 'test@example.com',
          password: 'WrongPassword'
        })
        .expect(400);

      expect(response.body.error).toBeDefined();
    });
  });
});
```

---

## 📚 Usage Instructions

### Getting Started with Templates

1. **Choose the appropriate template** based on your project requirements:
   - **Minimal**: For simple APIs and MVPs
   - **Enterprise**: For large-scale applications with advanced features
   - **Microservices**: For distributed architectures

2. **Clone and setup**:
```bash
# Copy template files
cp -r minimal-express-api my-new-project
cd my-new-project

# Install dependencies
npm install

# Setup environment
cp .env.example .env
# Edit .env with your configuration

# Setup database
npx prisma db push

# Start development server
npm run dev
```

3. **Customize for your needs**:
   - Modify the database schema in `prisma/schema.prisma`
   - Add your business logic in services
   - Create new controllers and routes
   - Add your specific validation rules
   - Configure deployment settings

### Deployment Checklist

- [ ] Environment variables configured
- [ ] Database migrations run
- [ ] SSL certificates installed
- [ ] Monitoring and logging configured
- [ ] Security headers validated
- [ ] Performance testing completed
- [ ] Backup strategy implemented

---

**Previous**: [Comparison Analysis](./comparison-analysis.md) | **Next**: [README](./README.md)