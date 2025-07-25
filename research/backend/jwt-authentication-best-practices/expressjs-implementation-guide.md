# Express.js Implementation Guide

## 🚀 Complete JWT Authentication Setup

This guide provides a production-ready JWT authentication implementation for Express.js with TypeScript, focusing on security, performance, and maintainability.

## 📦 Project Setup and Dependencies

### 1. Essential Dependencies

```bash
# Core authentication dependencies
npm install jsonwebtoken bcryptjs joi helmet express-rate-limit
npm install express cookie-parser cors dotenv

# TypeScript and development dependencies
npm install -D @types/jsonwebtoken @types/bcryptjs @types/node
npm install -D @types/express @types/cookie-parser typescript
```

### 2. Package.json Configuration

```json
{
  "name": "express-jwt-auth",
  "version": "1.0.0",
  "scripts": {
    "dev": "tsx watch src/index.ts",
    "build": "tsc",
    "start": "node dist/index.js",
    "test": "jest",
    "test:security": "npm audit && npm run test"
  },
  "dependencies": {
    "jsonwebtoken": "^9.0.2",
    "bcryptjs": "^2.4.3",
    "joi": "^17.11.0",
    "helmet": "^7.1.0",
    "express-rate-limit": "^7.1.5",
    "express": "^4.18.2",
    "cookie-parser": "^1.4.6",
    "cors": "^2.8.5",
    "dotenv": "^16.3.1"
  }
}
```

### 3. Environment Configuration

```bash
# .env file
NODE_ENV=production
PORT=3000

# JWT Configuration
JWT_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQC..."
JWT_PUBLIC_KEY="-----BEGIN PUBLIC KEY-----\nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAtfIwregV..."
JWT_ISSUER=https://api.yourapp.com
JWT_AUDIENCE=yourapp-clients

# Database (example with PostgreSQL)
DATABASE_URL=postgresql://user:password@localhost:5432/yourapp

# Security
BCRYPT_ROUNDS=12
RATE_LIMIT_WINDOW_MS=900000
RATE_LIMIT_MAX_REQUESTS=100

# CORS settings
CORS_ORIGIN=https://yourapp.com
```

## 🔧 Core Implementation

### 1. JWT Service Class

```typescript
// src/services/JWTService.ts
import jwt from 'jsonwebtoken';
import { createHash } from 'crypto';
import { promisify } from 'util';

const signAsync = promisify(jwt.sign);
const verifyAsync = promisify(jwt.verify);

export interface JWTClaims {
  iss: string;
  sub: string;
  aud: string;
  exp: number;
  iat: number;
  jti: string;
  userId: string;
  email: string;
  roles: string[];
  permissions: string[];
  sessionId: string;
}

export interface TokenPair {
  accessToken: string;
  refreshToken: string;
  expiresIn: number;
}

export class JWTService {
  private readonly privateKey: string;
  private readonly publicKey: string;
  private readonly issuer: string;
  private readonly audience: string;
  private readonly accessTokenTTL = 15 * 60; // 15 minutes
  private readonly refreshTokenTTL = 7 * 24 * 60 * 60; // 7 days
  
  constructor() {
    this.privateKey = process.env.JWT_PRIVATE_KEY?.replace(/\\n/g, '\n') || '';
    this.publicKey = process.env.JWT_PUBLIC_KEY?.replace(/\\n/g, '\n') || '';
    this.issuer = process.env.JWT_ISSUER || 'localhost';
    this.audience = process.env.JWT_AUDIENCE || 'localhost';
    
    if (!this.privateKey || !this.publicKey) {
      throw new Error('JWT keys must be configured');
    }
  }
  
  async generateAccessToken(user: {
    id: string;
    email: string;
    roles: string[];
    permissions: string[];
  }, sessionId: string): Promise<string> {
    const now = Math.floor(Date.now() / 1000);
    
    const payload: Partial<JWTClaims> = {
      iss: this.issuer,
      sub: user.id,
      aud: this.audience,
      exp: now + this.accessTokenTTL,
      iat: now,
      jti: this.generateJTI(),
      
      userId: user.id,
      email: user.email,
      roles: user.roles,
      permissions: user.permissions,
      sessionId
    };
    
    return await signAsync(payload, this.privateKey, {
      algorithm: 'RS256'
    }) as string;
  }
  
  async generateRefreshToken(userId: string, sessionId: string): Promise<string> {
    const now = Math.floor(Date.now() / 1000);
    
    const payload = {
      iss: this.issuer,
      sub: userId,
      aud: `${this.audience}:refresh`,
      exp: now + this.refreshTokenTTL,
      iat: now,
      jti: this.generateJTI(),
      sessionId,
      type: 'refresh'
    };
    
    return await signAsync(payload, this.privateKey, {
      algorithm: 'RS256'
    }) as string;
  }
  
  async verifyAccessToken(token: string): Promise<JWTClaims> {
    try {
      const payload = await verifyAsync(token, this.publicKey, {
        algorithms: ['RS256'],
        issuer: this.issuer,
        audience: this.audience,
        clockTolerance: 30
      }) as JWTClaims;
      
      return payload;
    } catch (error) {
      throw new Error(`Token verification failed: ${error}`);
    }
  }
  
  async verifyRefreshToken(token: string): Promise<any> {
    try {
      const payload = await verifyAsync(token, this.publicKey, {
        algorithms: ['RS256'],
        issuer: this.issuer,
        audience: `${this.audience}:refresh`,
        clockTolerance: 30
      });
      
      return payload;
    } catch (error) {
      throw new Error(`Refresh token verification failed: ${error}`);
    }
  }
  
  private generateJTI(): string {
    return createHash('sha256')
      .update(Date.now() + Math.random().toString())
      .digest('hex')
      .substring(0, 16);
  }
  
  getTokenExpiration(): number {
    return this.accessTokenTTL;
  }
}
```

### 2. Authentication Middleware

```typescript
// src/middleware/auth.ts
import { Request, Response, NextFunction } from 'express';
import { JWTService, JWTClaims } from '../services/JWTService';
import { logger } from '../utils/logger';
import { RateLimiterService } from '../services/RateLimiterService';

export interface AuthenticatedRequest extends Request {
  user?: JWTClaims;
  sessionId?: string;
}

export class AuthMiddleware {
  private jwtService: JWTService;
  private rateLimiter: RateLimiterService;
  
  constructor() {
    this.jwtService = new JWTService();
    this.rateLimiter = new RateLimiterService();
  }
  
  authenticate = async (
    req: AuthenticatedRequest,
    res: Response,
    next: NextFunction
  ): Promise<void> => {
    try {
      // Extract token from multiple sources
      const token = this.extractToken(req);
      
      if (!token) {
        return this.sendUnauthorized(res, 'TOKEN_MISSING', 'Access token required');
      }
      
      // Rate limiting check
      await this.checkRateLimit(req);
      
      // Verify JWT token
      const payload = await this.jwtService.verifyAccessToken(token);
      
      // Additional security validations
      await this.performSecurityChecks(req, payload);
      
      // Attach user context to request
      req.user = payload;
      req.sessionId = payload.sessionId;
      
      // Log successful authentication
      logger.info('Authentication successful', {
        userId: payload.userId,
        sessionId: payload.sessionId,
        ip: req.ip
      });
      
      next();
      
    } catch (error) {
      this.handleAuthenticationError(req, res, error);
    }
  };
  
  requireRole = (requiredRoles: string[]) => {
    return (req: AuthenticatedRequest, res: Response, next: NextFunction): void => {
      if (!req.user) {
        return this.sendUnauthorized(res, 'TOKEN_MISSING', 'Authentication required');
      }
      
      const hasRole = req.user.roles.some(role => requiredRoles.includes(role));
      
      if (!hasRole) {
        logger.warn('Insufficient permissions', {
          userId: req.user.userId,
          requiredRoles,
          userRoles: req.user.roles,
          ip: req.ip
        });
        
        return res.status(403).json({
          error: 'Insufficient permissions',
          code: 'FORBIDDEN',
          required: requiredRoles
        });
      }
      
      next();
    };
  };
  
  requirePermission = (requiredPermissions: string[]) => {
    return (req: AuthenticatedRequest, res: Response, next: NextFunction): void => {
      if (!req.user) {
        return this.sendUnauthorized(res, 'TOKEN_MISSING', 'Authentication required');
      }
      
      const hasPermission = req.user.permissions.some(
        permission => requiredPermissions.includes(permission)
      );
      
      if (!hasPermission) {
        logger.warn('Insufficient permissions', {
          userId: req.user.userId,
          requiredPermissions,
          userPermissions: req.user.permissions,
          ip: req.ip
        });
        
        return res.status(403).json({
          error: 'Insufficient permissions',
          code: 'FORBIDDEN',
          required: requiredPermissions
        });
      }
      
      next();
    };
  };
  
  private extractToken(req: Request): string | null {
    // Priority 1: HTTP-only cookie (most secure)
    if (req.cookies?.accessToken) {
      return req.cookies.accessToken;
    }
    
    // Priority 2: Authorization header
    const authHeader = req.headers.authorization;
    if (authHeader?.startsWith('Bearer ')) {
      return authHeader.substring(7);
    }
    
    return null;
  }
  
  private async checkRateLimit(req: Request): Promise<void> {
    const identifier = req.ip || 'unknown';
    const isAllowed = await this.rateLimiter.checkLimit(identifier);
    
    if (!isAllowed) {
      throw new Error('Rate limit exceeded');
    }
  }
  
  private async performSecurityChecks(
    req: Request,
    payload: JWTClaims
  ): Promise<void> {
    // Check if session is still active
    // This would typically query your session store/database
    // const session = await this.sessionService.getSession(payload.sessionId);
    // if (!session?.active) {
    //   throw new Error('Session expired');
    // }
    
    // IP address validation (optional - configure based on security requirements)
    // if (session.enforceIPBinding && session.ipAddress !== req.ip) {
    //   throw new Error('IP address mismatch');
    // }
    
    // Device fingerprinting validation (if implemented)
    // const deviceId = req.headers['x-device-id'];
    // if (session.deviceId && deviceId !== session.deviceId) {
    //   throw new Error('Device mismatch');
    // }
  }
  
  private handleAuthenticationError(
    req: Request,
    res: Response,
    error: any
  ): void {
    let errorCode = 'TOKEN_INVALID';
    let message = 'Authentication failed';
    
    if (error.message.includes('expired')) {
      errorCode = 'TOKEN_EXPIRED';
      message = 'Token has expired';
    } else if (error.message.includes('Rate limit')) {
      errorCode = 'RATE_LIMITED';
      message = 'Too many requests';
    }
    
    // Log authentication failure
    logger.warn('Authentication failed', {
      error: error.message,
      ip: req.ip,
      userAgent: req.get('User-Agent'),
      timestamp: new Date().toISOString()
    });
    
    this.sendUnauthorized(res, errorCode, message);
  }
  
  private sendUnauthorized(res: Response, code: string, message: string): void {
    res.status(401).json({
      error: message,
      code,
      timestamp: new Date().toISOString()
    });
  }
}
```

### 3. Authentication Controller

```typescript
// src/controllers/AuthController.ts
import { Request, Response } from 'express';
import bcrypt from 'bcryptjs';
import Joi from 'joi';
import { JWTService, TokenPair } from '../services/JWTService';
import { UserService } from '../services/UserService';
import { SessionService } from '../services/SessionService';
import { logger } from '../utils/logger';

const loginSchema = Joi.object({
  email: Joi.string().email().required(),
  password: Joi.string().min(8).required(),
  rememberMe: Joi.boolean().default(false)
});

const refreshTokenSchema = Joi.object({
  refreshToken: Joi.string().required()
});

export class AuthController {
  private jwtService: JWTService;
  private userService: UserService;
  private sessionService: SessionService;
  
  constructor() {
    this.jwtService = new JWTService();
    this.userService = new UserService();
    this.sessionService = new SessionService();
  }
  
  login = async (req: Request, res: Response): Promise<void> => {
    try {
      // Validate request body
      const { error, value } = loginSchema.validate(req.body);
      if (error) {
        res.status(400).json({
          error: 'Validation failed',
          details: error.details.map(d => d.message)
        });
        return;
      }
      
      const { email, password, rememberMe } = value;
      
      // Find user and verify password
      const user = await this.userService.findByEmail(email);
      if (!user || !await bcrypt.compare(password, user.passwordHash)) {
        // Log failed login attempt
        logger.warn('Login failed', {
          email,
          ip: req.ip,
          userAgent: req.get('User-Agent')
        });
        
        res.status(401).json({
          error: 'Invalid credentials',
          code: 'INVALID_CREDENTIALS'
        });
        return;
      }
      
      // Create session
      const session = await this.sessionService.createSession({
        userId: user.id,
        ipAddress: req.ip!,
        userAgent: req.get('User-Agent') || '',
        rememberMe
      });
      
      // Generate token pair
      const accessToken = await this.jwtService.generateAccessToken(user, session.id);
      const refreshToken = await this.jwtService.generateRefreshToken(user.id, session.id);
      
      // Set secure cookies
      this.setTokenCookies(res, accessToken, refreshToken, rememberMe);
      
      // Log successful login
      logger.info('User login successful', {
        userId: user.id,
        sessionId: session.id,
        ip: req.ip
      });
      
      res.json({
        success: true,
        user: {
          id: user.id,
          email: user.email,
          roles: user.roles,
          permissions: user.permissions
        },
        expiresIn: this.jwtService.getTokenExpiration()
      });
      
    } catch (error) {
      logger.error('Login error', error);
      res.status(500).json({
        error: 'Internal server error',
        code: 'INTERNAL_ERROR'
      });
    }
  };
  
  refreshToken = async (req: Request, res: Response): Promise<void> => {
    try {
      // Extract refresh token from cookies or body
      const refreshToken = req.cookies?.refreshToken || req.body.refreshToken;
      
      if (!refreshToken) {
        res.status(401).json({
          error: 'Refresh token required',
          code: 'REFRESH_TOKEN_MISSING'
        });
        return;
      }
      
      // Verify refresh token
      const payload = await this.jwtService.verifyRefreshToken(refreshToken);
      
      // Validate session
      const session = await this.sessionService.getSession(payload.sessionId);
      if (!session?.active) {
        res.status(401).json({
          error: 'Session expired',
          code: 'SESSION_EXPIRED'
        });
        return;
      }
      
      // Get user data
      const user = await this.userService.findById(payload.sub);
      if (!user) {
        res.status(401).json({
          error: 'User not found',
          code: 'USER_NOT_FOUND'
        });
        return;
      }
      
      // Generate new access token
      const newAccessToken = await this.jwtService.generateAccessToken(user, session.id);
      
      // Optionally rotate refresh token for enhanced security
      let newRefreshToken = refreshToken;
      if (this.shouldRotateRefreshToken(session)) {
        newRefreshToken = await this.jwtService.generateRefreshToken(user.id, session.id);
        await this.sessionService.updateRefreshToken(session.id, newRefreshToken);
      }
      
      // Set new cookies
      this.setTokenCookies(res, newAccessToken, newRefreshToken, session.rememberMe);
      
      logger.info('Token refreshed', {
        userId: user.id,
        sessionId: session.id
      });
      
      res.json({
        success: true,
        expiresIn: this.jwtService.getTokenExpiration()
      });
      
    } catch (error) {
      logger.warn('Token refresh failed', { error: error.message });
      res.status(401).json({
        error: 'Token refresh failed',
        code: 'REFRESH_FAILED'
      });
    }
  };
  
  logout = async (req: Request, res: Response): Promise<void> => {
    try {
      const sessionId = (req as any).sessionId;
      
      if (sessionId) {
        await this.sessionService.deactivateSession(sessionId);
        logger.info('User logout', { sessionId });
      }
      
      // Clear cookies
      res.clearCookie('accessToken', {
        httpOnly: true,
        secure: process.env.NODE_ENV === 'production',
        sameSite: 'strict',
        path: '/api'
      });
      
      res.clearCookie('refreshToken', {
        httpOnly: true,
        secure: process.env.NODE_ENV === 'production',
        sameSite: 'strict',
        path: '/api/auth'
      });
      
      res.json({ success: true });
      
    } catch (error) {
      logger.error('Logout error', error);
      res.status(500).json({
        error: 'Logout failed',
        code: 'LOGOUT_FAILED'
      });
    }
  };
  
  private setTokenCookies(
    res: Response,
    accessToken: string,
    refreshToken: string,
    rememberMe: boolean
  ): void {
    const isProduction = process.env.NODE_ENV === 'production';
    const accessTokenMaxAge = 15 * 60 * 1000; // 15 minutes
    const refreshTokenMaxAge = rememberMe ? 
      7 * 24 * 60 * 60 * 1000 :  // 7 days if remember me
      24 * 60 * 60 * 1000;       // 1 day otherwise
    
    // Access token cookie
    res.cookie('accessToken', accessToken, {
      httpOnly: true,
      secure: isProduction,
      sameSite: 'strict',
      maxAge: accessTokenMaxAge,
      path: '/api'
    });
    
    // Refresh token cookie (more restrictive path)
    res.cookie('refreshToken', refreshToken, {
      httpOnly: true,
      secure: isProduction,
      sameSite: 'strict',
      maxAge: refreshTokenMaxAge,
      path: '/api/auth'
    });
  }
  
  private shouldRotateRefreshToken(session: any): boolean {
    // Rotate refresh token every 24 hours or on security events
    const lastRotation = new Date(session.refreshTokenIssuedAt);
    const hoursSinceRotation = (Date.now() - lastRotation.getTime()) / (1000 * 60 * 60);
    
    return hoursSinceRotation > 24;
  }
}
```

### 4. Express App Configuration

```typescript
// src/app.ts
import express, { Application } from 'express';
import helmet from 'helmet';
import cors from 'cors';
import cookieParser from 'cookie-parser';
import rateLimit from 'express-rate-limit';
import { AuthController } from './controllers/AuthController';
import { AuthMiddleware } from './middleware/auth';
import { errorHandler } from './middleware/errorHandler';
import { requestLogger } from './middleware/requestLogger';

export const createApp = (): Application => {
  const app = express();
  
  // Security middleware
  app.use(helmet({
    contentSecurityPolicy: {
      directives: {
        defaultSrc: ["'self'"],
        styleSrc: ["'self'", "'unsafe-inline'"],
        scriptSrc: ["'self'"],
        imgSrc: ["'self'", "data:", "https:"],
      },
    },
    hsts: {
      maxAge: 31536000,
      includeSubDomains: true,
      preload: true
    }
  }));
  
  // CORS configuration
  app.use(cors({
    origin: process.env.CORS_ORIGIN?.split(',') || 'http://localhost:3000',
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With']
  }));
  
  // Rate limiting
  const limiter = rateLimit({
    windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS || '900000'), // 15 minutes
    max: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS || '100'),
    message: {
      error: 'Too many requests',
      code: 'RATE_LIMITED'
    },
    standardHeaders: true,
    legacyHeaders: false
  });
  
  app.use('/api/', limiter);
  
  // Body parsing middleware
  app.use(express.json({ limit: '10mb' }));
  app.use(express.urlencoded({ extended: true, limit: '10mb' }));
  app.use(cookieParser());
  
  // Request logging
  app.use(requestLogger);
  
  // Initialize services
  const authController = new AuthController();
  const authMiddleware = new AuthMiddleware();
  
  // Auth routes (public)
  app.post('/api/auth/login', authController.login);
  app.post('/api/auth/refresh', authController.refreshToken);
  app.post('/api/auth/logout', authMiddleware.authenticate, authController.logout);
  
  // Protected routes example
  app.get('/api/profile', 
    authMiddleware.authenticate,
    (req: any, res) => {
      res.json({
        user: req.user,
        sessionId: req.sessionId
      });
    }
  );
  
  // Admin-only route example
  app.get('/api/admin/users',
    authMiddleware.authenticate,
    authMiddleware.requireRole(['admin']),
    (req, res) => {
      res.json({ message: 'Admin access granted' });
    }
  );
  
  // Permission-based route example
  app.delete('/api/users/:id',
    authMiddleware.authenticate,
    authMiddleware.requirePermission(['user:delete']),
    (req, res) => {
      res.json({ message: 'User deletion access granted' });
    }
  );
  
  // Error handling middleware (should be last)
  app.use(errorHandler);
  
  return app;
};
```

## 🧪 Testing Implementation

### 1. Authentication Tests

```typescript
// src/__tests__/auth.test.ts
import request from 'supertest';
import { createApp } from '../app';
import { JWTService } from '../services/JWTService';

describe('Authentication', () => {
  let app: any;
  let jwtService: JWTService;
  
  beforeAll(() => {
    app = createApp();
    jwtService = new JWTService();
  });
  
  describe('POST /api/auth/login', () => {
    test('should login with valid credentials', async () => {
      const response = await request(app)
        .post('/api/auth/login')
        .send({
          email: 'test@example.com',
          password: 'password123'
        })
        .expect(200);
      
      expect(response.body.success).toBe(true);
      expect(response.body.user).toBeDefined();
      expect(response.body.expiresIn).toBe(900); // 15 minutes
      
      // Check if cookies are set
      const cookies = response.headers['set-cookie'];
      expect(cookies).toBeDefined();
      expect(cookies.some(cookie => cookie.includes('accessToken'))).toBe(true);
      expect(cookies.some(cookie => cookie.includes('refreshToken'))).toBe(true);
    });
    
    test('should reject invalid credentials', async () => {
      await request(app)
        .post('/api/auth/login')
        .send({
          email: 'test@example.com',
          password: 'wrongpassword'
        })
        .expect(401);
    });
    
    test('should validate input format', async () => {
      await request(app)
        .post('/api/auth/login')
        .send({
          email: 'invalid-email',
          password: 'short'
        })
        .expect(400);
    });
  });
  
  describe('JWT Token Security', () => {
    test('should reject tokens with wrong algorithm', async () => {
      // Create token with HS256 (should be rejected)
      const maliciousToken = jwt.sign(
        { userId: '123' },
        'secret',
        { algorithm: 'HS256' }
      );
      
      await request(app)
        .get('/api/profile')
        .set('Authorization', `Bearer ${maliciousToken}`)
        .expect(401);
    });
    
    test('should reject expired tokens', async () => {
      const expiredToken = await jwtService.generateAccessToken(
        { 
          id: '123', 
          email: 'test@example.com',
          roles: ['user'],
          permissions: ['read']
        },
        'session123'
      );
      
      // Wait for token to expire (in real test, you'd mock time)
      setTimeout(async () => {
        await request(app)
          .get('/api/profile')
          .set('Authorization', `Bearer ${expiredToken}`)
          .expect(401);
      }, 16 * 60 * 1000); // Wait 16 minutes
    });
  });
});
```

## 📊 Performance Monitoring

### JWT Performance Metrics

```typescript
// src/utils/performanceMonitor.ts
import { performance } from 'perf_hooks';

export class JWTPerformanceMonitor {
  private metrics = {
    tokenGeneration: [],
    tokenVerification: [],
    cacheHits: 0,
    cacheMisses: 0
  };
  
  measureTokenGeneration<T>(fn: () => Promise<T>): Promise<T> {
    const start = performance.now();
    return fn().then(result => {
      const duration = performance.now() - start;
      this.metrics.tokenGeneration.push(duration);
      return result;
    });
  }
  
  measureTokenVerification<T>(fn: () => Promise<T>): Promise<T> {
    const start = performance.now();
    return fn().then(result => {
      const duration = performance.now() - start;
      this.metrics.tokenVerification.push(duration);
      return result;
    });
  }
  
  recordCacheHit(): void {
    this.metrics.cacheHits++;
  }
  
  recordCacheMiss(): void {
    this.metrics.cacheMisses++;
  }
  
  getAverageTokenGenerationTime(): number {
    const times = this.metrics.tokenGeneration;
    return times.length > 0 ? times.reduce((a, b) => a + b, 0) / times.length : 0;
  }
  
  getAverageTokenVerificationTime(): number {
    const times = this.metrics.tokenVerification;
    return times.length > 0 ? times.reduce((a, b) => a + b, 0) / times.length : 0;
  }
  
  getCacheHitRatio(): number {
    const total = this.metrics.cacheHits + this.metrics.cacheMisses;
    return total > 0 ? this.metrics.cacheHits / total : 0;
  }
}
```

---

**Navigation**
- ← Back to: [JWT Fundamentals and Security](./jwt-fundamentals-security.md)
- → Next: [Token Storage and Security](./token-storage-security.md)
- ↑ Back to: [JWT Authentication Research](./README.md)