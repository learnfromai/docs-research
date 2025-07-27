# Template Examples: Express.js Production Patterns

## 🎯 Overview

Ready-to-use code templates and patterns extracted from successful Express.js open source projects. These templates provide production-ready implementations that you can adapt for your own applications.

## 🏗️ Project Structure Templates

### 1. Complete Project Structure

```
express-production-app/
├── .env.example                 # Environment variables template
├── .gitignore                   # Git ignore patterns
├── Dockerfile                   # Container configuration
├── docker-compose.yml           # Multi-service setup
├── package.json                 # Dependencies and scripts
├── tsconfig.json               # TypeScript configuration
├── jest.config.js              # Testing configuration
├── .eslintrc.json              # Code linting rules
├── .prettierrc                 # Code formatting rules
├── prisma/                     # Database schema and migrations
│   ├── schema.prisma
│   ├── migrations/
│   └── seed.ts
├── src/
│   ├── config/                 # Configuration management
│   │   ├── index.ts
│   │   ├── database.ts
│   │   ├── redis.ts
│   │   └── auth.ts
│   ├── controllers/            # Request handlers
│   │   ├── auth.controller.ts
│   │   ├── user.controller.ts
│   │   └── index.ts
│   ├── services/              # Business logic
│   │   ├── auth.service.ts
│   │   ├── user.service.ts
│   │   ├── email.service.ts
│   │   └── index.ts
│   ├── repositories/          # Data access layer
│   │   ├── user.repository.ts
│   │   ├── base.repository.ts
│   │   └── index.ts
│   ├── middleware/            # Custom middleware
│   │   ├── auth.middleware.ts
│   │   ├── validation.middleware.ts
│   │   ├── error.middleware.ts
│   │   ├── security.middleware.ts
│   │   └── index.ts
│   ├── models/               # Data models and types
│   │   ├── user.model.ts
│   │   ├── response.model.ts
│   │   └── index.ts
│   ├── routes/               # Route definitions
│   │   ├── auth.routes.ts
│   │   ├── user.routes.ts
│   │   ├── health.routes.ts
│   │   └── index.ts
│   ├── types/                # TypeScript definitions
│   │   ├── auth.types.ts
│   │   ├── user.types.ts
│   │   ├── common.types.ts
│   │   └── index.ts
│   ├── utils/                # Helper functions
│   │   ├── logger.ts
│   │   ├── validator.ts
│   │   ├── crypto.ts
│   │   └── index.ts
│   ├── tests/                # Test files
│   │   ├── unit/
│   │   ├── integration/
│   │   ├── e2e/
│   │   ├── fixtures/
│   │   └── setup.ts
│   ├── app.ts                # Express app configuration
│   └── server.ts             # Server entry point
├── logs/                     # Log files (gitignored)
├── coverage/                 # Test coverage reports
└── dist/                     # Compiled JavaScript (gitignored)
```

## 🔧 Configuration Templates

### 1. Environment Configuration Template

**`.env.example`:**
```bash
# Application
NODE_ENV=development
PORT=3000
APP_NAME=Express Production App
APP_VERSION=1.0.0

# Database
DATABASE_URL=postgresql://username:password@localhost:5432/myapp
DB_POOL_MIN=2
DB_POOL_MAX=10

# Redis
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=
REDIS_DB=0

# JWT Authentication
JWT_SECRET=your-super-secret-jwt-key-at-least-32-characters-long
JWT_REFRESH_SECRET=your-super-secret-refresh-key-at-least-32-characters-long
JWT_EXPIRES_IN=15m
JWT_REFRESH_EXPIRES_IN=7d
JWT_ISSUER=express-app
JWT_AUDIENCE=express-app-users

# Session
SESSION_SECRET=your-super-secret-session-key-at-least-32-characters-long
SESSION_NAME=sessionId
SESSION_MAX_AGE=86400000

# Security
BCRYPT_ROUNDS=12
RATE_LIMIT_WINDOW=900000
RATE_LIMIT_MAX=100
CORS_ORIGIN=http://localhost:3000,http://localhost:3001

# Email Service
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASSWORD=your-app-password

# External Services
AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
AWS_REGION=us-east-1
S3_BUCKET_NAME=

# Monitoring
LOG_LEVEL=info
SENTRY_DSN=
NEW_RELIC_LICENSE_KEY=
```

### 2. TypeScript Configuration Template

**`tsconfig.json`:**
```json
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "commonjs",
    "lib": ["ES2020"],
    "allowJs": true,
    "outDir": "./dist",
    "rootDir": "./src",
    "removeComments": true,
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "declaration": true,
    "declarationMap": true,
    "sourceMap": true,
    "noImplicitAny": true,
    "strictNullChecks": true,
    "strictFunctionTypes": true,
    "noImplicitThis": true,
    "noImplicitReturns": true,
    "noFallthroughCasesInSwitch": true,
    "noUncheckedIndexedAccess": true,
    "experimentalDecorators": true,
    "emitDecoratorMetadata": true,
    "baseUrl": "./src",
    "paths": {
      "@/*": ["*"],
      "@/config/*": ["config/*"],
      "@/controllers/*": ["controllers/*"],
      "@/services/*": ["services/*"],
      "@/repositories/*": ["repositories/*"],
      "@/middleware/*": ["middleware/*"],
      "@/models/*": ["models/*"],
      "@/routes/*": ["routes/*"],
      "@/types/*": ["types/*"],
      "@/utils/*": ["utils/*"],
      "@/tests/*": ["tests/*"]
    }
  },
  "include": [
    "src/**/*",
    "types/**/*"
  ],
  "exclude": [
    "node_modules",
    "dist",
    "coverage",
    "**/*.test.ts",
    "**/*.spec.ts"
  ]
}
```

## 🔐 Authentication Templates

### 1. Complete Authentication Service

**`src/services/auth.service.ts`:**
```typescript
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import crypto from 'crypto';
import { PrismaClient, User, RefreshToken } from '@prisma/client';
import { config } from '@/config';
import logger from '@/utils/logger';
import { EmailService } from './email.service';
import { 
  AuthTokens, 
  LoginCredentials, 
  RegisterData, 
  ResetPasswordData,
  ChangePasswordData 
} from '@/types/auth.types';

export class AuthService {
  constructor(
    private prisma: PrismaClient,
    private emailService: EmailService
  ) {}

  async register(userData: RegisterData): Promise<{ user: Omit<User, 'password'>; tokens: AuthTokens }> {
    try {
      // Check if user already exists
      const existingUser = await this.prisma.user.findUnique({
        where: { email: userData.email.toLowerCase() }
      });

      if (existingUser) {
        throw new Error('User already exists with this email');
      }

      // Hash password
      const hashedPassword = await bcrypt.hash(userData.password, config.security.bcryptRounds);

      // Create email verification token
      const emailVerificationToken = crypto.randomBytes(32).toString('hex');

      // Create user
      const user = await this.prisma.user.create({
        data: {
          email: userData.email.toLowerCase(),
          password: hashedPassword,
          name: userData.name,
          emailVerificationToken,
          roles: {
            connect: { name: 'user' } // Default role
          }
        },
        include: {
          roles: {
            include: {
              permissions: true
            }
          }
        }
      });

      // Generate tokens
      const tokens = await this.generateTokens(user);

      // Send verification email
      await this.emailService.sendEmailVerification(user.email, emailVerificationToken);

      // Remove sensitive data
      const { password, emailVerificationToken: _, ...userWithoutSensitiveData } = user;

      logger.info('User registered successfully', { 
        userId: user.id, 
        email: user.email 
      });

      return { user: userWithoutSensitiveData, tokens };
    } catch (error) {
      logger.error('Registration failed', { 
        error: error.message, 
        email: userData.email 
      });
      throw error;
    }
  }

  async login(credentials: LoginCredentials): Promise<{ user: Omit<User, 'password'>; tokens: AuthTokens }> {
    try {
      // Find user with roles and permissions
      const user = await this.prisma.user.findUnique({
        where: { email: credentials.email.toLowerCase() },
        include: {
          roles: {
            include: {
              permissions: true
            }
          }
        }
      });

      if (!user) {
        throw new Error('Invalid email or password');
      }

      if (!user.isActive) {
        throw new Error('Account has been deactivated');
      }

      // Verify password
      const isValidPassword = await bcrypt.compare(credentials.password, user.password);
      if (!isValidPassword) {
        // Log failed login attempt
        logger.warn('Failed login attempt', {
          email: credentials.email,
          ip: credentials.ip,
          userAgent: credentials.userAgent
        });
        throw new Error('Invalid email or password');
      }

      // Check if email is verified
      if (!user.emailVerified) {
        throw new Error('Please verify your email before logging in');
      }

      // Update last login
      await this.prisma.user.update({
        where: { id: user.id },
        data: { 
          lastLoginAt: new Date(),
          lastLoginIp: credentials.ip
        }
      });

      // Generate tokens
      const tokens = await this.generateTokens(user);

      // Remove sensitive data
      const { password, emailVerificationToken, ...userWithoutSensitiveData } = user;

      logger.info('User logged in successfully', { 
        userId: user.id, 
        email: user.email,
        ip: credentials.ip
      });

      return { user: userWithoutSensitiveData, tokens };
    } catch (error) {
      logger.error('Login failed', { 
        error: error.message, 
        email: credentials.email 
      });
      throw error;
    }
  }

  async refreshTokens(refreshToken: string): Promise<AuthTokens> {
    try {
      // Verify refresh token
      const decoded = jwt.verify(refreshToken, config.jwt.refreshSecret) as any;

      // Check if refresh token exists in database
      const storedToken = await this.prisma.refreshToken.findUnique({
        where: { token: refreshToken },
        include: {
          user: {
            include: {
              roles: {
                include: {
                  permissions: true
                }
              }
            }
          }
        }
      });

      if (!storedToken) {
        throw new Error('Invalid refresh token');
      }

      if (new Date() > storedToken.expiresAt) {
        // Clean up expired token
        await this.prisma.refreshToken.delete({
          where: { token: refreshToken }
        });
        throw new Error('Refresh token has expired');
      }

      if (!storedToken.user.isActive) {
        throw new Error('User account is deactivated');
      }

      // Generate new tokens
      const tokens = await this.generateTokens(storedToken.user);

      // Remove old refresh token (token rotation)
      await this.prisma.refreshToken.delete({
        where: { token: refreshToken }
      });

      logger.info('Tokens refreshed successfully', { 
        userId: storedToken.user.id 
      });

      return tokens;
    } catch (error) {
      logger.error('Token refresh failed', { 
        error: error.message 
      });
      throw error;
    }
  }

  async logout(refreshToken: string): Promise<void> {
    try {
      await this.prisma.refreshToken.delete({
        where: { token: refreshToken }
      });

      logger.info('User logged out successfully');
    } catch (error) {
      // Don't throw error if token doesn't exist
      logger.warn('Logout attempt with invalid token', { 
        error: error.message 
      });
    }
  }

  async requestPasswordReset(email: string): Promise<void> {
    try {
      const user = await this.prisma.user.findUnique({
        where: { email: email.toLowerCase() }
      });

      if (!user) {
        // Don't reveal if email exists
        logger.warn('Password reset requested for non-existent email', { email });
        return;
      }

      // Generate reset token
      const resetToken = crypto.randomBytes(32).toString('hex');
      const resetTokenExpiry = new Date(Date.now() + 3600000); // 1 hour

      // Save reset token
      await this.prisma.user.update({
        where: { id: user.id },
        data: {
          resetPasswordToken: resetToken,
          resetPasswordExpiry: resetTokenExpiry
        }
      });

      // Send reset email
      await this.emailService.sendPasswordReset(user.email, resetToken);

      logger.info('Password reset requested', { 
        userId: user.id, 
        email: user.email 
      });
    } catch (error) {
      logger.error('Password reset request failed', { 
        error: error.message, 
        email 
      });
      throw error;
    }
  }

  async resetPassword(data: ResetPasswordData): Promise<void> {
    try {
      const user = await this.prisma.user.findFirst({
        where: {
          resetPasswordToken: data.token,
          resetPasswordExpiry: {
            gt: new Date()
          }
        }
      });

      if (!user) {
        throw new Error('Invalid or expired reset token');
      }

      // Hash new password
      const hashedPassword = await bcrypt.hash(data.password, config.security.bcryptRounds);

      // Update password and clear reset token
      await this.prisma.user.update({
        where: { id: user.id },
        data: {
          password: hashedPassword,
          resetPasswordToken: null,
          resetPasswordExpiry: null
        }
      });

      // Revoke all refresh tokens for security
      await this.prisma.refreshToken.deleteMany({
        where: { userId: user.id }
      });

      logger.info('Password reset successfully', { 
        userId: user.id 
      });
    } catch (error) {
      logger.error('Password reset failed', { 
        error: error.message 
      });
      throw error;
    }
  }

  async changePassword(userId: string, data: ChangePasswordData): Promise<void> {
    try {
      const user = await this.prisma.user.findUnique({
        where: { id: userId }
      });

      if (!user) {
        throw new Error('User not found');
      }

      // Verify current password
      const isValidPassword = await bcrypt.compare(data.currentPassword, user.password);
      if (!isValidPassword) {
        throw new Error('Current password is incorrect');
      }

      // Hash new password
      const hashedPassword = await bcrypt.hash(data.newPassword, config.security.bcryptRounds);

      // Update password
      await this.prisma.user.update({
        where: { id: userId },
        data: { password: hashedPassword }
      });

      // Revoke all refresh tokens except current one
      await this.prisma.refreshToken.deleteMany({
        where: { 
          userId,
          token: { not: data.currentRefreshToken }
        }
      });

      logger.info('Password changed successfully', { userId });
    } catch (error) {
      logger.error('Password change failed', { 
        error: error.message, 
        userId 
      });
      throw error;
    }
  }

  async verifyEmail(token: string): Promise<void> {
    try {
      const user = await this.prisma.user.findFirst({
        where: { emailVerificationToken: token }
      });

      if (!user) {
        throw new Error('Invalid verification token');
      }

      await this.prisma.user.update({
        where: { id: user.id },
        data: {
          emailVerified: true,
          emailVerificationToken: null
        }
      });

      logger.info('Email verified successfully', { 
        userId: user.id 
      });
    } catch (error) {
      logger.error('Email verification failed', { 
        error: error.message 
      });
      throw error;
    }
  }

  private async generateTokens(user: any): Promise<AuthTokens> {
    const payload = {
      userId: user.id,
      email: user.email,
      roles: user.roles.map((role: any) => role.name),
      permissions: user.roles.flatMap((role: any) => 
        role.permissions.map((permission: any) => permission.name)
      )
    };

    // Generate access token
    const accessToken = jwt.sign(payload, config.jwt.secret, {
      expiresIn: config.jwt.expiresIn,
      issuer: config.jwt.issuer,
      audience: config.jwt.audience,
      subject: user.id,
      jwtid: crypto.randomBytes(16).toString('hex')
    });

    // Generate refresh token
    const refreshTokenString = jwt.sign(
      { userId: user.id },
      config.jwt.refreshSecret,
      {
        expiresIn: config.jwt.refreshExpiresIn,
        issuer: config.jwt.issuer,
        audience: config.jwt.audience,
        subject: user.id,
        jwtid: crypto.randomBytes(16).toString('hex')
      }
    );

    // Store refresh token in database
    const expiresAt = new Date();
    expiresAt.setTime(expiresAt.getTime() + (7 * 24 * 60 * 60 * 1000)); // 7 days

    await this.prisma.refreshToken.create({
      data: {
        token: refreshTokenString,
        userId: user.id,
        expiresAt
      }
    });

    return { 
      accessToken, 
      refreshToken: refreshTokenString 
    };
  }
}
```

### 2. Authentication Middleware Template

**`src/middleware/auth.middleware.ts`:**
```typescript
import jwt from 'jsonwebtoken';
import { Request, Response, NextFunction } from 'express';
import { PrismaClient } from '@prisma/client';
import { config } from '@/config';
import logger from '@/utils/logger';

const prisma = new PrismaClient();

export interface AuthenticatedRequest extends Request {
  user?: {
    id: string;
    email: string;
    roles: string[];
    permissions: string[];
  };
}

export const authenticateToken = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
) => {
  try {
    const authHeader = req.headers.authorization;
    const token = authHeader && authHeader.split(' ')[1];

    if (!token) {
      return res.status(401).json({
        success: false,
        message: 'Access token required',
        code: 'MISSING_TOKEN'
      });
    }

    // Verify JWT token
    const decoded = jwt.verify(token, config.jwt.secret, {
      algorithms: ['HS256', 'RS256'],
      issuer: config.jwt.issuer,
      audience: config.jwt.audience
    }) as any;

    // Verify user still exists and is active
    const user = await prisma.user.findUnique({
      where: { id: decoded.userId },
      include: {
        roles: {
          include: {
            permissions: true
          }
        }
      }
    });

    if (!user || !user.isActive) {
      return res.status(401).json({
        success: false,
        message: 'User not found or inactive',
        code: 'USER_NOT_FOUND'
      });
    }

    // Attach user info to request
    req.user = {
      id: user.id,
      email: user.email,
      roles: user.roles.map(role => role.name),
      permissions: user.roles.flatMap(role => 
        role.permissions.map(permission => permission.name)
      )
    };

    next();
  } catch (error) {
    if (error.name === 'TokenExpiredError') {
      return res.status(401).json({
        success: false,
        message: 'Token has expired',
        code: 'TOKEN_EXPIRED'
      });
    }

    if (error.name === 'JsonWebTokenError') {
      return res.status(401).json({
        success: false,
        message: 'Invalid token',
        code: 'INVALID_TOKEN'
      });
    }

    logger.error('Token verification failed', { 
      error: error.message 
    });

    return res.status(500).json({
      success: false,
      message: 'Authentication failed',
      code: 'AUTH_ERROR'
    });
  }
};

export const authorize = (
  requiredRoles: string[] = [], 
  requiredPermissions: string[] = []
) => {
  return (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
    if (!req.user) {
      return res.status(401).json({
        success: false,
        message: 'Authentication required',
        code: 'UNAUTHENTICATED'
      });
    }

    // Check roles
    if (requiredRoles.length > 0) {
      const hasRequiredRole = requiredRoles.some(role => 
        req.user!.roles.includes(role)
      );

      if (!hasRequiredRole) {
        return res.status(403).json({
          success: false,
          message: 'Insufficient role permissions',
          code: 'INSUFFICIENT_ROLE_PERMISSIONS',
          required: requiredRoles,
          current: req.user.roles
        });
      }
    }

    // Check permissions
    if (requiredPermissions.length > 0) {
      const hasRequiredPermission = requiredPermissions.some(permission =>
        req.user!.permissions.includes(permission)
      );

      if (!hasRequiredPermission) {
        return res.status(403).json({
          success: false,
          message: 'Insufficient permissions',
          code: 'INSUFFICIENT_PERMISSIONS',
          required: requiredPermissions,
          current: req.user.permissions
        });
      }
    }

    next();
  };
};

export const requireOwnership = (resourceField: string = 'userId') => {
  return async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
    if (!req.user) {
      return res.status(401).json({
        success: false,
        message: 'Authentication required',
        code: 'UNAUTHENTICATED'
      });
    }

    // Admin can access any resource
    if (req.user.roles.includes('admin')) {
      return next();
    }

    const resourceId = req.params.id;
    if (!resourceId) {
      return res.status(400).json({
        success: false,
        message: 'Resource ID required',
        code: 'MISSING_RESOURCE_ID'
      });
    }

    try {
      // This is a generic example - adapt based on your resource models
      const resource = await prisma.post.findUnique({
        where: { id: resourceId },
        select: { [resourceField]: true }
      });

      if (!resource) {
        return res.status(404).json({
          success: false,
          message: 'Resource not found',
          code: 'RESOURCE_NOT_FOUND'
        });
      }

      if (resource[resourceField] !== req.user.id) {
        return res.status(403).json({
          success: false,
          message: 'Access denied: insufficient permissions',
          code: 'ACCESS_DENIED'
        });
      }

      next();
    } catch (error) {
      logger.error('Ownership check failed', { 
        error: error.message,
        userId: req.user.id,
        resourceId
      });

      res.status(500).json({
        success: false,
        message: 'Authorization check failed',
        code: 'AUTH_CHECK_ERROR'
      });
    }
  };
};

// Optional authentication - doesn't fail if no token provided
export const optionalAuth = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
) => {
  const authHeader = req.headers.authorization;
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return next(); // Continue without authentication
  }

  try {
    const decoded = jwt.verify(token, config.jwt.secret) as any;
    
    const user = await prisma.user.findUnique({
      where: { id: decoded.userId },
      include: {
        roles: {
          include: {
            permissions: true
          }
        }
      }
    });

    if (user && user.isActive) {
      req.user = {
        id: user.id,
        email: user.email,
        roles: user.roles.map(role => role.name),
        permissions: user.roles.flatMap(role => 
          role.permissions.map(permission => permission.name)
        )
      };
    }
  } catch (error) {
    // Ignore authentication errors for optional auth
    logger.debug('Optional authentication failed', { 
      error: error.message 
    });
  }

  next();
};
```

## 🛡️ Security Middleware Templates

### 1. Comprehensive Security Middleware

**`src/middleware/security.middleware.ts`:**
```typescript
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import slowDown from 'express-slow-down';
import { Request, Response, NextFunction } from 'express';
import { config } from '@/config';
import logger, { securityLogger } from '@/utils/logger';

// Security headers configuration
export const securityHeaders = helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: [
        "'self'",
        "'strict-dynamic'",
        "'nonce-{{nonce}}'",
        "'unsafe-inline'"
      ],
      styleSrc: [
        "'self'",
        "'unsafe-inline'",
        "https://fonts.googleapis.com"
      ],
      fontSrc: [
        "'self'",
        "https://fonts.gstatic.com"
      ],
      imgSrc: [
        "'self'",
        "data:",
        "https:",
        "blob:"
      ],
      connectSrc: [
        "'self'",
        "https://api.example.com"
      ],
      mediaSrc: ["'self'"],
      objectSrc: ["'none'"],
      frameSrc: ["'none'"],
      baseUri: ["'self'"],
      formAction: ["'self'"],
      frameAncestors: ["'none'"],
      upgradeInsecureRequests: config.nodeEnv === 'production' ? [] : null
    },
    reportOnly: config.nodeEnv === 'development'
  },
  
  hsts: {
    maxAge: 31536000, // 1 year
    includeSubDomains: true,
    preload: true
  },
  
  noSniff: true,
  xssFilter: true,
  referrerPolicy: { policy: 'same-origin' },
  crossOriginEmbedderPolicy: false,
  crossOriginOpenerPolicy: { policy: 'same-origin' },
  crossOriginResourcePolicy: { policy: 'cross-origin' }
});

// Rate limiting configurations
export const createRateLimiter = (options: {
  windowMs?: number;
  max?: number;
  message?: string;
  keyGenerator?: (req: Request) => string;
  skip?: (req: Request) => boolean;
}) => {
  return rateLimit({
    windowMs: options.windowMs || 15 * 60 * 1000, // 15 minutes
    max: options.max || 100,
    message: {
      success: false,
      message: options.message || 'Too many requests, please try again later',
      code: 'RATE_LIMIT_EXCEEDED'
    },
    standardHeaders: true,
    legacyHeaders: false,
    keyGenerator: options.keyGenerator || ((req) => req.ip),
    skip: options.skip || (() => false),
    handler: (req, res) => {
      securityLogger.warn('Rate limit exceeded', {
        ip: req.ip,
        userAgent: req.headers['user-agent'],
        path: req.path,
        method: req.method
      });
      
      res.status(429).json({
        success: false,
        message: options.message || 'Too many requests, please try again later',
        code: 'RATE_LIMIT_EXCEEDED'
      });
    }
  });
};

// General API rate limiter
export const apiLimiter = createRateLimiter({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100,
  message: 'Too many API requests, please try again later'
});

// Strict rate limiter for authentication endpoints
export const authLimiter = createRateLimiter({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 5, // 5 attempts per window
  message: 'Too many authentication attempts, please try again later',
  keyGenerator: (req) => `${req.ip}:${req.body?.email || 'unknown'}`
});

// Speed limiter (progressive delay)
export const speedLimiter = slowDown({
  windowMs: 15 * 60 * 1000, // 15 minutes
  delayAfter: 50, // Allow 50 requests per windowMs without delay
  delayMs: 500, // Add 500ms delay per request after delayAfter
  maxDelayMs: 20000, // Max delay of 20 seconds
  skipFailedRequests: false,
  skipSuccessfulRequests: false,
  keyGenerator: (req) => req.ip
});

// Security monitoring middleware
export const securityMonitor = (req: Request, res: Response, next: NextFunction) => {
  // Detect suspicious patterns
  const suspiciousPatterns = [
    /union.*select/i, // SQL injection
    /<script.*>/i, // XSS
    /javascript:/i, // XSS
    /eval\(/i, // Code injection
    /exec\(/i, // Command injection
    /\.\.\//, // Path traversal
    /\/etc\/passwd/, // File inclusion
    /cmd\.exe/i // Windows command execution
  ];
  
  const requestData = JSON.stringify({
    body: req.body,
    query: req.query,
    params: req.params,
    url: req.url
  });
  
  const detectedPatterns: string[] = [];
  
  for (const pattern of suspiciousPatterns) {
    if (pattern.test(requestData)) {
      detectedPatterns.push(pattern.source);
    }
  }
  
  if (detectedPatterns.length > 0) {
    securityLogger.error('Suspicious activity detected', {
      ip: req.ip,
      userAgent: req.headers['user-agent'],
      path: req.path,
      method: req.method,
      patterns: detectedPatterns,
      timestamp: new Date().toISOString()
    });
    
    return res.status(403).json({
      success: false,
      message: 'Request blocked due to suspicious content',
      code: 'SECURITY_VIOLATION'
    });
  }
  
  next();
};

// Request size limiting
export const requestSizeLimit = (req: Request, res: Response, next: NextFunction) => {
  const contentLength = req.headers['content-length'];
  const maxSize = 10 * 1024 * 1024; // 10MB
  
  if (contentLength && parseInt(contentLength) > maxSize) {
    return res.status(413).json({
      success: false,
      message: 'Request too large',
      code: 'REQUEST_TOO_LARGE'
    });
  }
  
  next();
};

// IP whitelist/blacklist middleware
export const ipFilter = (options: {
  whitelist?: string[];
  blacklist?: string[];
}) => {
  return (req: Request, res: Response, next: NextFunction) => {
    const clientIp = req.ip || req.connection.remoteAddress;
    
    if (options.blacklist && options.blacklist.includes(clientIp)) {
      securityLogger.warn('Blocked request from blacklisted IP', {
        ip: clientIp,
        path: req.path,
        method: req.method
      });
      
      return res.status(403).json({
        success: false,
        message: 'Access denied',
        code: 'IP_BLOCKED'
      });
    }
    
    if (options.whitelist && !options.whitelist.includes(clientIp)) {
      securityLogger.warn('Blocked request from non-whitelisted IP', {
        ip: clientIp,
        path: req.path,
        method: req.method
      });
      
      return res.status(403).json({
        success: false,
        message: 'Access denied',
        code: 'IP_NOT_WHITELISTED'
      });
    }
    
    next();
  };
};

// CSRF protection middleware
export const csrfProtection = (req: Request, res: Response, next: NextFunction) => {
  // Skip CSRF for GET, HEAD, OPTIONS
  if (['GET', 'HEAD', 'OPTIONS'].includes(req.method)) {
    return next();
  }
  
  // Skip CSRF for API key authentication
  if (req.headers['x-api-key']) {
    return next();
  }
  
  const token = req.headers['x-csrf-token'] || req.body._csrf;
  const sessionToken = req.session?.csrfToken;
  
  if (!token || !sessionToken || token !== sessionToken) {
    securityLogger.warn('CSRF token validation failed', {
      ip: req.ip,
      path: req.path,
      method: req.method,
      hasToken: !!token,
      hasSessionToken: !!sessionToken
    });
    
    return res.status(403).json({
      success: false,
      message: 'CSRF token validation failed',
      code: 'CSRF_TOKEN_MISMATCH'
    });
  }
  
  next();
};

// Generate CSRF token endpoint
export const generateCSRFToken = (req: Request, res: Response) => {
  const token = require('crypto').randomBytes(32).toString('hex');
  
  if (req.session) {
    req.session.csrfToken = token;
  }
  
  res.json({
    success: true,
    csrfToken: token
  });
};
```

## 📊 Validation Templates

### 1. Comprehensive Validation Schemas

**`src/validators/user.validator.ts`:**
```typescript
import Joi from 'joi';

// Password validation schema
const passwordSchema = Joi.string()
  .min(8)
  .max(128)
  .pattern(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]/)
  .required()
  .messages({
    'string.min': 'Password must be at least 8 characters long',
    'string.max': 'Password must not exceed 128 characters',
    'string.pattern.base': 'Password must contain at least one lowercase letter, one uppercase letter, one number, and one special character',
    'any.required': 'Password is required'
  });

// Email validation schema
const emailSchema = Joi.string()
  .email({ tlds: { allow: false } })
  .lowercase()
  .max(255)
  .required()
  .messages({
    'string.email': 'Please provide a valid email address',
    'string.max': 'Email must not exceed 255 characters',
    'any.required': 'Email is required'
  });

// Name validation schema
const nameSchema = Joi.string()
  .min(2)
  .max(100)
  .pattern(/^[a-zA-Z\s'-]+$/)
  .required()
  .messages({
    'string.min': 'Name must be at least 2 characters long',
    'string.max': 'Name must not exceed 100 characters',
    'string.pattern.base': 'Name can only contain letters, spaces, hyphens, and apostrophes',
    'any.required': 'Name is required'
  });

// Phone validation schema
const phoneSchema = Joi.string()
  .pattern(/^\+?[1-9]\d{1,14}$/)
  .optional()
  .messages({
    'string.pattern.base': 'Please provide a valid phone number'
  });

// User validation schemas
export const userValidationSchemas = {
  register: Joi.object({
    email: emailSchema,
    password: passwordSchema,
    name: nameSchema,
    phone: phoneSchema,
    dateOfBirth: Joi.date()
      .max('now')
      .min('1900-01-01')
      .optional()
      .messages({
        'date.max': 'Date of birth cannot be in the future',
        'date.min': 'Date of birth must be after 1900'
      }),
    acceptTerms: Joi.boolean()
      .valid(true)
      .required()
      .messages({
        'any.only': 'You must accept the terms and conditions'
      }),
    preferences: Joi.object({
      notifications: Joi.boolean().default(true),
      language: Joi.string().valid('en', 'es', 'fr', 'de').default('en'),
      timezone: Joi.string().default('UTC'),
      theme: Joi.string().valid('light', 'dark', 'auto').default('auto')
    }).optional()
  }),

  login: Joi.object({
    email: emailSchema,
    password: Joi.string().required().messages({
      'any.required': 'Password is required'
    }),
    rememberMe: Joi.boolean().optional()
  }),

  updateProfile: Joi.object({
    name: nameSchema.optional(),
    phone: phoneSchema,
    dateOfBirth: Joi.date()
      .max('now')
      .min('1900-01-01')
      .optional(),
    bio: Joi.string()
      .max(500)
      .optional()
      .messages({
        'string.max': 'Bio must not exceed 500 characters'
      }),
    website: Joi.string()
      .uri()
      .optional()
      .messages({
        'string.uri': 'Please provide a valid website URL'
      }),
    preferences: Joi.object({
      notifications: Joi.boolean(),
      language: Joi.string().valid('en', 'es', 'fr', 'de'),
      timezone: Joi.string(),
      theme: Joi.string().valid('light', 'dark', 'auto')
    }).optional()
  }).min(1).messages({
    'object.min': 'At least one field must be provided for update'
  }),

  changePassword: Joi.object({
    currentPassword: Joi.string().required().messages({
      'any.required': 'Current password is required'
    }),
    newPassword: passwordSchema,
    confirmPassword: Joi.string()
      .valid(Joi.ref('newPassword'))
      .required()
      .messages({
        'any.only': 'Password confirmation does not match new password',
        'any.required': 'Password confirmation is required'
      })
  }),

  requestPasswordReset: Joi.object({
    email: emailSchema
  }),

  resetPassword: Joi.object({
    token: Joi.string().required().messages({
      'any.required': 'Reset token is required'
    }),
    password: passwordSchema,
    confirmPassword: Joi.string()
      .valid(Joi.ref('password'))
      .required()
      .messages({
        'any.only': 'Password confirmation does not match password',
        'any.required': 'Password confirmation is required'
      })
  }),

  verifyEmail: Joi.object({
    token: Joi.string().required().messages({
      'any.required': 'Verification token is required'
    })
  }),

  refreshToken: Joi.object({
    refreshToken: Joi.string().required().messages({
      'any.required': 'Refresh token is required'
    })
  }),

  uploadAvatar: Joi.object({
    file: Joi.any().required().messages({
      'any.required': 'Avatar file is required'
    })
  })
};

// Query parameter validation schemas
export const userQuerySchemas = {
  getUsers: Joi.object({
    page: Joi.number().integer().min(1).default(1),
    limit: Joi.number().integer().min(1).max(100).default(10),
    search: Joi.string().max(100).optional(),
    sortBy: Joi.string().valid('name', 'email', 'createdAt', 'lastLoginAt').default('createdAt'),
    sortOrder: Joi.string().valid('asc', 'desc').default('desc'),
    role: Joi.string().optional(),
    status: Joi.string().valid('active', 'inactive').optional(),
    emailVerified: Joi.boolean().optional()
  }),

  getUserById: Joi.object({
    id: Joi.string().uuid().required().messages({
      'string.uuid': 'User ID must be a valid UUID',
      'any.required': 'User ID is required'
    })
  })
};

// File upload validation
export const fileValidationSchemas = {
  avatar: Joi.object({
    mimetype: Joi.string().valid(
      'image/jpeg',
      'image/png',
      'image/gif',
      'image/webp'
    ).required().messages({
      'any.only': 'Avatar must be a JPEG, PNG, GIF, or WebP image'
    }),
    size: Joi.number().max(5 * 1024 * 1024).required().messages({
      'number.max': 'Avatar file size must not exceed 5MB'
    })
  })
};

// Custom validation functions
export const customValidators = {
  isUniqueEmail: async (email: string, excludeUserId?: string): Promise<boolean> => {
    const { PrismaClient } = await import('@prisma/client');
    const prisma = new PrismaClient();
    
    try {
      const existingUser = await prisma.user.findUnique({
        where: { email: email.toLowerCase() }
      });
      
      if (!existingUser) {
        return true; // Email is unique
      }
      
      // If excluding a user ID (for updates), check if it's the same user
      return excludeUserId ? existingUser.id === excludeUserId : false;
    } finally {
      await prisma.$disconnect();
    }
  },

  isValidTimezone: (timezone: string): boolean => {
    try {
      Intl.DateTimeFormat(undefined, { timeZone: timezone });
      return true;
    } catch {
      return false;
    }
  }
};
```

## 🔗 Navigation Template

**Navigation footer for all documents:**

```markdown
---

*Template Examples | Research conducted January 2025*

**Navigation**
- **Previous**: [Best Practices](./best-practices.md) ←
- **Back to**: [Research Overview](./README.md) ↑
```

This template examples document provides ready-to-use code patterns that you can immediately implement in your Express.js applications. Each template is based on production-proven patterns from successful open source projects and includes comprehensive error handling, validation, and security measures.

---

*Template Examples | Research conducted January 2025*

**Navigation**
- **Previous**: [Best Practices](./best-practices.md) ←
- **Back to**: [Research Overview](./README.md) ↑