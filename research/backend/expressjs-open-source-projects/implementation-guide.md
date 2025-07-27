# Implementation Guide: Building Production-Ready Express.js Applications

## 🎯 Overview

This guide provides step-by-step instructions for implementing a production-ready Express.js application based on patterns extracted from successful open source projects.

## 📋 Project Setup & Structure

### 1. Initial Project Structure

Create a scalable project structure based on successful patterns:

```bash
# Initialize project
mkdir my-express-app
cd my-express-app
npm init -y

# Install core dependencies
npm install express helmet cors express-rate-limit joi jsonwebtoken bcryptjs
npm install mongoose redis winston morgan multer

# Install development dependencies
npm install -D @types/node @types/express typescript ts-node nodemon
npm install -D jest supertest @types/jest @types/supertest eslint prettier
```

### 2. Directory Structure

```
src/
├── controllers/         # Request handlers
├── services/           # Business logic
├── models/             # Data models
├── middleware/         # Custom middleware
├── routes/             # Route definitions
├── config/             # Configuration files
├── utils/              # Shared utilities
├── types/              # TypeScript type definitions
└── tests/              # Test files
    ├── unit/
    ├── integration/
    └── setup/
```

### 3. TypeScript Configuration

```typescript
// tsconfig.json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "commonjs",
    "lib": ["ES2022"],
    "outDir": "./dist",
    "rootDir": "./src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "declaration": true,
    "declarationMap": true,
    "sourceMap": true,
    "removeComments": true,
    "noImplicitAny": true,
    "noImplicitReturns": true,
    "noFallthroughCasesInSwitch": true,
    "moduleResolution": "node",
    "baseUrl": "./src",
    "paths": {
      "@/*": ["*"],
      "@/controllers/*": ["controllers/*"],
      "@/services/*": ["services/*"],
      "@/models/*": ["models/*"],
      "@/middleware/*": ["middleware/*"],
      "@/utils/*": ["utils/*"],
      "@/types/*": ["types/*"]
    }
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist", "**/*.test.ts"]
}
```

---

## 🔧 Core Application Setup

### 1. Environment Configuration

```typescript
// src/config/environment.ts
import { config } from 'dotenv';
import Joi from 'joi';

// Load environment variables
config();

// Environment schema validation
const envSchema = Joi.object({
  NODE_ENV: Joi.string().valid('development', 'production', 'test').default('development'),
  PORT: Joi.number().default(3000),
  
  // Database
  DATABASE_URL: Joi.string().required(),
  REDIS_URL: Joi.string().required(),
  
  // Security
  JWT_SECRET: Joi.string().min(32).required(),
  JWT_REFRESH_SECRET: Joi.string().min(32).required(),
  BCRYPT_ROUNDS: Joi.number().default(12),
  
  // External services
  SMTP_HOST: Joi.string().required(),
  SMTP_PORT: Joi.number().default(587),
  SMTP_USER: Joi.string().required(),
  SMTP_PASS: Joi.string().required(),
  
  // File storage
  AWS_ACCESS_KEY_ID: Joi.string().optional(),
  AWS_SECRET_ACCESS_KEY: Joi.string().optional(),
  AWS_REGION: Joi.string().optional(),
  S3_BUCKET: Joi.string().optional()
}).unknown();

const { error, value: envVars } = envSchema.validate(process.env);

if (error) {
  throw new Error(`Config validation error: ${error.message}`);
}

export const config = {
  env: envVars.NODE_ENV,
  port: envVars.PORT,
  
  database: {
    url: envVars.DATABASE_URL
  },
  
  redis: {
    url: envVars.REDIS_URL
  },
  
  jwt: {
    secret: envVars.JWT_SECRET,
    refreshSecret: envVars.JWT_REFRESH_SECRET,
    accessExpiration: '15m',
    refreshExpiration: '7d'
  },
  
  bcrypt: {
    rounds: envVars.BCRYPT_ROUNDS
  },
  
  email: {
    smtp: {
      host: envVars.SMTP_HOST,
      port: envVars.SMTP_PORT,
      auth: {
        user: envVars.SMTP_USER,
        pass: envVars.SMTP_PASS
      }
    }
  },
  
  aws: {
    accessKeyId: envVars.AWS_ACCESS_KEY_ID,
    secretAccessKey: envVars.AWS_SECRET_ACCESS_KEY,
    region: envVars.AWS_REGION,
    s3Bucket: envVars.S3_BUCKET
  }
};
```

### 2. Database Connection

```typescript
// src/config/database.ts
import mongoose from 'mongoose';
import { config } from './environment';
import { logger } from '@/utils/logger';

export class Database {
  static async connect(): Promise<void> {
    try {
      await mongoose.connect(config.database.url, {
        maxPoolSize: 10,
        serverSelectionTimeoutMS: 5000,
        socketTimeoutMS: 45000,
        bufferCommands: false,
        bufferMaxEntries: 0
      });
      
      logger.info('Connected to MongoDB');
      
      // Connection event handlers
      mongoose.connection.on('error', (error) => {
        logger.error('MongoDB connection error:', error);
      });
      
      mongoose.connection.on('disconnected', () => {
        logger.warn('MongoDB disconnected');
      });
      
      // Graceful shutdown
      process.on('SIGINT', async () => {
        await mongoose.connection.close();
        logger.info('MongoDB connection closed');
        process.exit(0);
      });
      
    } catch (error) {
      logger.error('Failed to connect to MongoDB:', error);
      process.exit(1);
    }
  }
  
  static async disconnect(): Promise<void> {
    await mongoose.connection.close();
  }
}
```

### 3. Redis Connection

```typescript
// src/config/redis.ts
import { createClient } from 'redis';
import { config } from './environment';
import { logger } from '@/utils/logger';

export class RedisClient {
  private static instance: ReturnType<typeof createClient>;
  
  static async connect() {
    if (!this.instance) {
      this.instance = createClient({
        url: config.redis.url
      });
      
      this.instance.on('error', (error) => {
        logger.error('Redis connection error:', error);
      });
      
      this.instance.on('connect', () => {
        logger.info('Connected to Redis');
      });
      
      await this.instance.connect();
    }
    
    return this.instance;
  }
  
  static getInstance() {
    if (!this.instance) {
      throw new Error('Redis client not initialized. Call connect() first.');
    }
    return this.instance;
  }
  
  static async disconnect() {
    if (this.instance) {
      await this.instance.disconnect();
    }
  }
}
```

---

## 🔐 Authentication Implementation

### 1. User Model

```typescript
// src/models/User.ts
import mongoose, { Document, Schema } from 'mongoose';
import bcrypt from 'bcryptjs';
import { config } from '@/config/environment';

export interface IUser extends Document {
  email: string;
  password: string;
  name: string;
  role: 'user' | 'moderator' | 'admin';
  isEmailVerified: boolean;
  tokenVersion: number;
  lastLoginAt?: Date;
  createdAt: Date;
  updatedAt: Date;
  
  comparePassword(password: string): Promise<boolean>;
  incrementTokenVersion(): Promise<void>;
}

const userSchema = new Schema<IUser>({
  email: {
    type: String,
    required: true,
    unique: true,
    lowercase: true,
    trim: true,
    index: true
  },
  password: {
    type: String,
    required: true,
    minlength: 8
  },
  name: {
    type: String,
    required: true,
    trim: true,
    maxlength: 50
  },
  role: {
    type: String,
    enum: ['user', 'moderator', 'admin'],
    default: 'user'
  },
  isEmailVerified: {
    type: Boolean,
    default: false
  },
  tokenVersion: {
    type: Number,
    default: 0
  },
  lastLoginAt: {
    type: Date
  }
}, {
  timestamps: true
});

// Hash password before saving
userSchema.pre('save', async function(next) {
  if (!this.isModified('password')) return next();
  
  this.password = await bcrypt.hash(this.password, config.bcrypt.rounds);
  next();
});

// Instance method to compare password
userSchema.methods.comparePassword = async function(password: string): Promise<boolean> {
  return bcrypt.compare(password, this.password);
};

// Instance method to increment token version (invalidates all tokens)
userSchema.methods.incrementTokenVersion = async function(): Promise<void> {
  this.tokenVersion += 1;
  await this.save();
};

// Remove password from JSON output
userSchema.methods.toJSON = function() {
  const userObject = this.toObject();
  delete userObject.password;
  delete userObject.tokenVersion;
  return userObject;
};

export const User = mongoose.model<IUser>('User', userSchema);
```

### 2. Authentication Service

```typescript
// src/services/AuthService.ts
import jwt from 'jsonwebtoken';
import { User, IUser } from '@/models/User';
import { config } from '@/config/environment';
import { RedisClient } from '@/config/redis';
import { CustomError } from '@/utils/errors';

export interface TokenPair {
  accessToken: string;
  refreshToken: string;
}

export interface JWTPayload {
  userId: string;
  email: string;
  role: string;
  iat: number;
  exp: number;
}

export class AuthService {
  private redis = RedisClient.getInstance();
  
  async authenticate(email: string, password: string): Promise<IUser> {
    const user = await User.findOne({ email }).select('+password');
    
    if (!user || !await user.comparePassword(password)) {
      throw new CustomError('Invalid credentials', 401);
    }
    
    if (!user.isEmailVerified) {
      throw new CustomError('Email not verified', 401);
    }
    
    // Update last login
    user.lastLoginAt = new Date();
    await user.save();
    
    return user;
  }
  
  generateTokenPair(user: IUser): TokenPair {
    const payload = {
      userId: user.id,
      email: user.email,
      role: user.role
    };
    
    const accessToken = jwt.sign(payload, config.jwt.secret, {
      expiresIn: config.jwt.accessExpiration,
      issuer: 'your-app',
      audience: 'your-app-users'
    });
    
    const refreshToken = jwt.sign(
      { userId: user.id, tokenVersion: user.tokenVersion },
      config.jwt.refreshSecret,
      { expiresIn: config.jwt.refreshExpiration }
    );
    
    return { accessToken, refreshToken };
  }
  
  async verifyAccessToken(token: string): Promise<JWTPayload> {
    try {
      // Check if token is blacklisted
      const isBlacklisted = await this.redis.exists(`blacklist:${token}`);
      if (isBlacklisted) {
        throw new CustomError('Token has been revoked', 401);
      }
      
      const decoded = jwt.verify(token, config.jwt.secret) as JWTPayload;
      return decoded;
      
    } catch (error) {
      if (error instanceof jwt.TokenExpiredError) {
        throw new CustomError('Access token expired', 401);
      } else if (error instanceof jwt.JsonWebTokenError) {
        throw new CustomError('Invalid access token', 401);
      }
      throw error;
    }
  }
  
  async refreshTokens(refreshToken: string): Promise<TokenPair> {
    try {
      const decoded = jwt.verify(refreshToken, config.jwt.refreshSecret) as any;
      
      const user = await User.findById(decoded.userId);
      if (!user || user.tokenVersion !== decoded.tokenVersion) {
        throw new CustomError('Invalid refresh token', 401);
      }
      
      return this.generateTokenPair(user);
      
    } catch (error) {
      if (error instanceof jwt.TokenExpiredError) {
        throw new CustomError('Refresh token expired', 401);
      }
      throw new CustomError('Invalid refresh token', 401);
    }
  }
  
  async revokeToken(token: string): Promise<void> {
    try {
      const decoded = jwt.verify(token, config.jwt.secret) as JWTPayload;
      const expiration = decoded.exp - Math.floor(Date.now() / 1000);
      
      if (expiration > 0) {
        await this.redis.setEx(`blacklist:${token}`, expiration, 'revoked');
      }
    } catch (error) {
      // Token might already be invalid, but we still want to blacklist it
      await this.redis.setEx(`blacklist:${token}`, 86400, 'revoked'); // 24 hours
    }
  }
  
  async revokeAllUserTokens(userId: string): Promise<void> {
    const user = await User.findById(userId);
    if (user) {
      await user.incrementTokenVersion();
    }
  }
}
```

### 3. Authentication Middleware

```typescript
// src/middleware/auth.ts
import { Request, Response, NextFunction } from 'express';
import { AuthService } from '@/services/AuthService';
import { User } from '@/models/User';
import { CustomError } from '@/utils/errors';

// Extend Request interface
declare global {
  namespace Express {
    interface Request {
      user?: any;
    }
  }
}

const authService = new AuthService();

export const authenticate = async (req: Request, res: Response, next: NextFunction) => {
  try {
    let token: string | undefined;
    
    // Extract token from various sources
    if (req.cookies?.accessToken) {
      token = req.cookies.accessToken;
    } else if (req.headers.authorization?.startsWith('Bearer ')) {
      token = req.headers.authorization.substring(7);
    } else if (req.headers['x-access-token']) {
      token = req.headers['x-access-token'] as string;
    }
    
    if (!token) {
      throw new CustomError('Access token required', 401);
    }
    
    const decoded = await authService.verifyAccessToken(token);
    
    // Get fresh user data
    const user = await User.findById(decoded.userId);
    if (!user) {
      throw new CustomError('User not found', 401);
    }
    
    req.user = user;
    next();
    
  } catch (error) {
    if (error instanceof CustomError) {
      return res.status(error.statusCode).json({ error: error.message });
    }
    return res.status(401).json({ error: 'Authentication failed' });
  }
};

export const authenticateOptional = async (req: Request, res: Response, next: NextFunction) => {
  try {
    await authenticate(req, res, () => {});
  } catch (error) {
    // Continue without authentication
  }
  next();
};

export const authorize = (roles: string[]) => {
  return (req: Request, res: Response, next: NextFunction) => {
    if (!req.user) {
      return res.status(401).json({ error: 'Authentication required' });
    }
    
    if (!roles.includes(req.user.role)) {
      return res.status(403).json({ error: 'Insufficient permissions' });
    }
    
    next();
  };
};
```

---

## 📝 CRUD Operations Implementation

### 1. User Service

```typescript
// src/services/UserService.ts
import { User, IUser } from '@/models/User';
import { CustomError } from '@/utils/errors';
import Joi from 'joi';

export interface CreateUserData {
  email: string;
  password: string;
  name: string;
  role?: string;
}

export interface UpdateUserData {
  name?: string;
  email?: string;
}

export class UserService {
  // Validation schemas
  private createUserSchema = Joi.object({
    email: Joi.string().email().required(),
    password: Joi.string().min(8).max(128).required()
      .pattern(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]/)
      .message('Password must contain uppercase, lowercase, number and special character'),
    name: Joi.string().min(2).max(50).required(),
    role: Joi.string().valid('user', 'moderator', 'admin').default('user')
  });
  
  private updateUserSchema = Joi.object({
    name: Joi.string().min(2).max(50),
    email: Joi.string().email()
  }).min(1);
  
  async createUser(userData: CreateUserData): Promise<IUser> {
    const { error, value } = this.createUserSchema.validate(userData);
    if (error) {
      throw new CustomError(`Validation error: ${error.details[0].message}`, 400);
    }
    
    // Check if user already exists
    const existingUser = await User.findOne({ email: value.email });
    if (existingUser) {
      throw new CustomError('User with this email already exists', 409);
    }
    
    const user = new User(value);
    await user.save();
    
    return user;
  }
  
  async getUserById(id: string): Promise<IUser | null> {
    if (!id.match(/^[0-9a-fA-F]{24}$/)) {
      throw new CustomError('Invalid user ID format', 400);
    }
    
    return User.findById(id);
  }
  
  async getUserByEmail(email: string): Promise<IUser | null> {
    return User.findOne({ email: email.toLowerCase() });
  }
  
  async updateUser(id: string, updateData: UpdateUserData): Promise<IUser> {
    const { error, value } = this.updateUserSchema.validate(updateData);
    if (error) {
      throw new CustomError(`Validation error: ${error.details[0].message}`, 400);
    }
    
    // Check if email is being changed and already exists
    if (value.email) {
      const existingUser = await User.findOne({ 
        email: value.email,
        _id: { $ne: id }
      });
      if (existingUser) {
        throw new CustomError('Email already in use', 409);
      }
    }
    
    const user = await User.findByIdAndUpdate(
      id,
      { ...value, updatedAt: new Date() },
      { new: true, runValidators: true }
    );
    
    if (!user) {
      throw new CustomError('User not found', 404);
    }
    
    return user;
  }
  
  async deleteUser(id: string): Promise<void> {
    const user = await User.findByIdAndDelete(id);
    if (!user) {
      throw new CustomError('User not found', 404);
    }
  }
  
  async listUsers(page = 1, limit = 10, filters: any = {}): Promise<{
    users: IUser[];
    total: number;
    page: number;
    totalPages: number;
  }> {
    const skip = (page - 1) * limit;
    
    // Build query filters
    const query: any = {};
    if (filters.role) {
      query.role = filters.role;
    }
    if (filters.search) {
      query.$or = [
        { name: { $regex: filters.search, $options: 'i' } },
        { email: { $regex: filters.search, $options: 'i' } }
      ];
    }
    
    const [users, total] = await Promise.all([
      User.find(query)
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limit),
      User.countDocuments(query)
    ]);
    
    return {
      users,
      total,
      page,
      totalPages: Math.ceil(total / limit)
    };
  }
}
```

### 2. User Controller

```typescript
// src/controllers/UserController.ts
import { Request, Response } from 'express';
import { UserService } from '@/services/UserService';
import { AuthService } from '@/services/AuthService';
import { logger } from '@/utils/logger';
import { CustomError } from '@/utils/errors';

export class UserController {
  private userService = new UserService();
  private authService = new AuthService();
  
  register = async (req: Request, res: Response) => {
    try {
      const user = await this.userService.createUser(req.body);
      
      // Generate tokens
      const tokens = this.authService.generateTokenPair(user);
      
      // Set HTTP-only cookies
      this.setTokenCookies(res, tokens);
      
      logger.info('User registered', { userId: user.id, email: user.email });
      
      res.status(201).json({
        message: 'User registered successfully',
        user
      });
      
    } catch (error) {
      this.handleError(error, res);
    }
  };
  
  login = async (req: Request, res: Response) => {
    try {
      const { email, password } = req.body;
      
      const user = await this.authService.authenticate(email, password);
      const tokens = this.authService.generateTokenPair(user);
      
      this.setTokenCookies(res, tokens);
      
      logger.info('User logged in', { userId: user.id, email: user.email });
      
      res.json({
        message: 'Login successful',
        user
      });
      
    } catch (error) {
      this.handleError(error, res);
    }
  };
  
  logout = async (req: Request, res: Response) => {
    try {
      // Blacklist current token
      const token = this.extractToken(req);
      if (token) {
        await this.authService.revokeToken(token);
      }
      
      // Clear cookies
      res.clearCookie('accessToken');
      res.clearCookie('refreshToken');
      
      logger.info('User logged out', { userId: req.user?.id });
      
      res.json({ message: 'Logged out successfully' });
      
    } catch (error) {
      this.handleError(error, res);
    }
  };
  
  refreshToken = async (req: Request, res: Response) => {
    try {
      const refreshToken = req.cookies.refreshToken || req.body.refreshToken;
      
      if (!refreshToken) {
        throw new CustomError('Refresh token required', 401);
      }
      
      const tokens = await this.authService.refreshTokens(refreshToken);
      this.setTokenCookies(res, tokens);
      
      res.json({ message: 'Tokens refreshed successfully' });
      
    } catch (error) {
      this.handleError(error, res);
    }
  };
  
  getProfile = async (req: Request, res: Response) => {
    try {
      const user = await this.userService.getUserById(req.user.id);
      res.json({ user });
    } catch (error) {
      this.handleError(error, res);
    }
  };
  
  updateProfile = async (req: Request, res: Response) => {
    try {
      const user = await this.userService.updateUser(req.user.id, req.body);
      
      logger.info('User profile updated', { userId: user.id });
      
      res.json({
        message: 'Profile updated successfully',
        user
      });
      
    } catch (error) {
      this.handleError(error, res);
    }
  };
  
  getUsers = async (req: Request, res: Response) => {
    try {
      const page = parseInt(req.query.page as string) || 1;
      const limit = parseInt(req.query.limit as string) || 10;
      const filters = {
        role: req.query.role,
        search: req.query.search
      };
      
      const result = await this.userService.listUsers(page, limit, filters);
      res.json(result);
      
    } catch (error) {
      this.handleError(error, res);
    }
  };
  
  private setTokenCookies(res: Response, tokens: { accessToken: string; refreshToken: string }) {
    const cookieOptions = {
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'strict' as const,
      path: '/'
    };
    
    res.cookie('accessToken', tokens.accessToken, {
      ...cookieOptions,
      maxAge: 15 * 60 * 1000 // 15 minutes
    });
    
    res.cookie('refreshToken', tokens.refreshToken, {
      ...cookieOptions,
      maxAge: 7 * 24 * 60 * 60 * 1000 // 7 days
    });
  }
  
  private extractToken(req: Request): string | undefined {
    if (req.cookies?.accessToken) {
      return req.cookies.accessToken;
    } else if (req.headers.authorization?.startsWith('Bearer ')) {
      return req.headers.authorization.substring(7);
    }
    return undefined;
  }
  
  private handleError(error: any, res: Response) {
    if (error instanceof CustomError) {
      return res.status(error.statusCode).json({ error: error.message });
    }
    
    logger.error('User controller error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
}
```

### 3. Routes Setup

```typescript
// src/routes/userRoutes.ts
import { Router } from 'express';
import { UserController } from '@/controllers/UserController';
import { authenticate, authorize } from '@/middleware/auth';
import { validate } from '@/middleware/validation';
import { rateLimit } from '@/middleware/rateLimit';
import Joi from 'joi';

const router = Router();
const userController = new UserController();

// Validation schemas
const registerSchema = Joi.object({
  email: Joi.string().email().required(),
  password: Joi.string().min(8).required(),
  name: Joi.string().min(2).max(50).required()
});

const loginSchema = Joi.object({
  email: Joi.string().email().required(),
  password: Joi.string().required()
});

const updateProfileSchema = Joi.object({
  name: Joi.string().min(2).max(50),
  email: Joi.string().email()
}).min(1);

// Auth routes
router.post('/register', 
  rateLimit({ max: 5, windowMs: 15 * 60 * 1000 }),
  validate(registerSchema),
  userController.register
);

router.post('/login',
  rateLimit({ max: 5, windowMs: 15 * 60 * 1000 }),
  validate(loginSchema),
  userController.login
);

router.post('/logout',
  authenticate,
  userController.logout
);

router.post('/refresh-token',
  rateLimit({ max: 10, windowMs: 15 * 60 * 1000 }),
  userController.refreshToken
);

// User profile routes
router.get('/profile',
  authenticate,
  userController.getProfile
);

router.put('/profile',
  authenticate,
  validate(updateProfileSchema),
  userController.updateProfile
);

// Admin routes
router.get('/users',
  authenticate,
  authorize(['admin', 'moderator']),
  userController.getUsers
);

export { router as userRoutes };
```

---

## 🚀 Application Bootstrap

### 1. Main Application File

```typescript
// src/app.ts
import express from 'express';
import helmet from 'helmet';
import cors from 'cors';
import morgan from 'morgan';
import cookieParser from 'cookie-parser';
import { config } from '@/config/environment';
import { Database } from '@/config/database';
import { RedisClient } from '@/config/redis';
import { logger } from '@/utils/logger';
import { errorHandler } from '@/middleware/errorHandler';
import { userRoutes } from '@/routes/userRoutes';

export const createApp = async () => {
  // Initialize database connections
  await Database.connect();
  await RedisClient.connect();
  
  const app = express();
  
  // Security middleware
  app.use(helmet({
    contentSecurityPolicy: {
      directives: {
        defaultSrc: ["'self'"],
        scriptSrc: ["'self'", "'unsafe-inline'"],
        styleSrc: ["'self'", "'unsafe-inline'"],
        imgSrc: ["'self'", "data:", "https:"],
        connectSrc: ["'self'"]
      }
    }
  }));
  
  // CORS configuration
  app.use(cors({
    origin: process.env.ALLOWED_ORIGINS?.split(',') || ['http://localhost:3000'],
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'],
    allowedHeaders: ['Content-Type', 'Authorization']
  }));
  
  // Request parsing
  app.use(express.json({ limit: '10mb' }));
  app.use(express.urlencoded({ extended: true, limit: '10mb' }));
  app.use(cookieParser());
  
  // Request logging
  app.use(morgan('combined', {
    stream: { write: (message) => logger.info(message.trim()) }
  }));
  
  // Health check endpoint
  app.get('/health', (req, res) => {
    res.json({ 
      status: 'ok',
      timestamp: new Date().toISOString(),
      version: process.env.npm_package_version || '1.0.0'
    });
  });
  
  // API routes
  app.use('/api/auth', userRoutes);
  
  // 404 handler
  app.use('*', (req, res) => {
    res.status(404).json({ error: 'Route not found' });
  });
  
  // Error handling middleware
  app.use(errorHandler);
  
  return app;
};

// Start server
export const startServer = async () => {
  try {
    const app = await createApp();
    
    const server = app.listen(config.port, () => {
      logger.info(`Server running on port ${config.port}`);
    });
    
    // Graceful shutdown
    process.on('SIGINT', async () => {
      logger.info('Shutting down server...');
      
      server.close(async () => {
        await Database.disconnect();
        await RedisClient.disconnect();
        logger.info('Server shut down complete');
        process.exit(0);
      });
    });
    
    return server;
    
  } catch (error) {
    logger.error('Failed to start server:', error);
    process.exit(1);
  }
};
```

### 2. Server Entry Point

```typescript
// src/server.ts
import { startServer } from './app';

// Handle uncaught exceptions
process.on('uncaughtException', (error) => {
  console.error('Uncaught Exception:', error);
  process.exit(1);
});

// Handle unhandled promise rejections
process.on('unhandledRejection', (reason, promise) => {
  console.error('Unhandled Rejection at:', promise, 'reason:', reason);
  process.exit(1);
});

// Start the server
startServer();
```

### 3. Package.json Scripts

```json
{
  "scripts": {
    "dev": "nodemon src/server.ts",
    "build": "tsc",
    "start": "node dist/server.js",
    "test": "jest",
    "test:watch": "jest --watch",
    "test:coverage": "jest --coverage",
    "lint": "eslint src/**/*.ts",
    "lint:fix": "eslint src/**/*.ts --fix",
    "format": "prettier --write src/**/*.ts"
  }
}
```

## 📋 Next Steps

After implementing the basic structure:

1. **Add Testing**: Implement unit and integration tests
2. **Add Logging**: Enhance logging with structured logging
3. **Add Monitoring**: Implement health checks and metrics
4. **Add Documentation**: API documentation with Swagger/OpenAPI
5. **Add CI/CD**: Set up automated testing and deployment
6. **Add Security**: Implement additional security measures
7. **Add Performance**: Add caching and optimization

## 🔗 References

- [Express.js Best Practices](https://expressjs.com/en/advanced/best-practice-performance.html)
- [Node.js Production Best Practices](https://nodejs.org/en/docs/guides/nodejs-docker-webapp/)
- [TypeScript Node.js Starter](https://github.com/microsoft/TypeScript-Node-Starter)

---

*Implementation guide based on production patterns from successful Express.js projects*

**Navigation**
- ← Back to: [Tools and Libraries Analysis](./tools-libraries-analysis.md)
- ↑ Back to: [Main Research Hub](./README.md)
- → Next: [Best Practices](./best-practices.md)