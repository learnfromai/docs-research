# Template Examples: Express.js Code Templates

## 🎯 Overview

This document provides ready-to-use code templates based on patterns discovered in production Express.js applications. These templates can serve as starting points for new projects or as reference implementations for specific features.

## 🚀 Project Starter Templates

### 1. **Minimal API Starter**

#### Basic Express.js API Template
```typescript
// ✅ Minimal Express.js API with TypeScript
// src/app.ts
import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import compression from 'compression';
import morgan from 'morgan';
import { config } from './config';
import { errorHandler, notFound } from './middleware/error';
import routes from './routes';

const app = express();

// Security middleware
app.use(helmet());
app.use(cors({
  origin: process.env.ALLOWED_ORIGINS?.split(',') || ['http://localhost:3000']
}));

// Request processing
app.use(compression());
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Logging
app.use(morgan(config.nodeEnv === 'development' ? 'dev' : 'combined'));

// Health check
app.get('/health', (req, res) => {
  res.json({ 
    status: 'OK', 
    timestamp: new Date().toISOString(),
    uptime: process.uptime()
  });
});

// Routes
app.use('/api/v1', routes);

// Error handling
app.use(notFound);
app.use(errorHandler);

export default app;

// src/server.ts
import app from './app';
import { config } from './config';
import { connectDatabase } from './config/database';

const startServer = async () => {
  try {
    await connectDatabase();
    
    const server = app.listen(config.port, () => {
      console.log(`Server running on port ${config.port}`);
    });

    // Graceful shutdown
    process.on('SIGTERM', () => {
      console.log('SIGTERM received');
      server.close(() => {
        console.log('Process terminated');
      });
    });
  } catch (error) {
    console.error('Failed to start server:', error);
    process.exit(1);
  }
};

startServer();

// package.json
{
  "name": "express-api-starter",
  "version": "1.0.0",
  "scripts": {
    "dev": "nodemon src/server.ts",
    "build": "tsc",
    "start": "node dist/server.js",
    "test": "jest",
    "lint": "eslint src/**/*.ts"
  },
  "dependencies": {
    "express": "^4.18.2",
    "cors": "^2.8.5",
    "helmet": "^7.0.0",
    "compression": "^1.7.4",
    "morgan": "^1.10.0",
    "dotenv": "^16.3.1"
  },
  "devDependencies": {
    "@types/express": "^4.17.17",
    "@types/node": "^20.4.5",
    "typescript": "^5.1.6",
    "nodemon": "^3.0.1",
    "ts-node": "^10.9.1"
  }
}
```

### 2. **Production-Ready API Template**

#### Full-Featured Express.js Template
```typescript
// ✅ Production-ready Express.js API
// src/app.ts
import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import compression from 'compression';
import rateLimit from 'express-rate-limit';
import mongoSanitize from 'express-mongo-sanitize';
import xss from 'xss-clean';
import hpp from 'hpp';
import cookieParser from 'cookie-parser';
import { config } from './config';
import { logger } from './utils/logger';
import { errorHandler, notFound } from './middleware/error';
import { performanceMiddleware } from './middleware/performance';
import routes from './routes';

const app = express();

// Trust proxy
app.set('trust proxy', 1);

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
}));

app.use(cors({
  origin: function (origin, callback) {
    const allowedOrigins = config.allowedOrigins;
    if (!origin || allowedOrigins.includes(origin)) {
      callback(null, true);
    } else {
      callback(new Error('Not allowed by CORS'));
    }
  },
  credentials: true,
  optionsSuccessStatus: 200,
}));

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100,
  message: 'Too many requests from this IP',
  standardHeaders: true,
  legacyHeaders: false,
});
app.use('/api/', limiter);

// Request processing
app.use(compression());
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));
app.use(cookieParser(config.cookieSecret));

// Input sanitization
app.use(mongoSanitize());
app.use(xss());
app.use(hpp());

// Performance monitoring
app.use(performanceMiddleware);

// Request logging
if (config.nodeEnv === 'development') {
  app.use(require('morgan')('dev'));
} else {
  app.use(require('morgan')('combined', {
    stream: { write: (message: string) => logger.info(message.trim()) }
  }));
}

// Health check
app.get('/health', (req, res) => {
  res.json({
    status: 'OK',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    environment: config.nodeEnv,
    version: process.env.npm_package_version || '1.0.0'
  });
});

// API routes
app.use('/api/v1', routes);

// Error handling
app.use(notFound);
app.use(errorHandler);

export default app;

// src/config/index.ts
import dotenv from 'dotenv';
import Joi from 'joi';

dotenv.config();

const envSchema = Joi.object({
  NODE_ENV: Joi.string().valid('development', 'production', 'test').default('development'),
  PORT: Joi.number().port().default(3000),
  MONGODB_URI: Joi.string().required(),
  JWT_SECRET: Joi.string().min(32).required(),
  JWT_EXPIRY: Joi.string().default('7d'),
  BCRYPT_ROUNDS: Joi.number().integer().min(10).max(15).default(12),
  ALLOWED_ORIGINS: Joi.string().default('http://localhost:3000'),
  COOKIE_SECRET: Joi.string().min(32).required(),
}).unknown();

const { error, value: envVars } = envSchema.validate(process.env);

if (error) {
  throw new Error(`Config validation error: ${error.message}`);
}

export const config = {
  nodeEnv: envVars.NODE_ENV,
  port: envVars.PORT,
  mongoUri: envVars.MONGODB_URI,
  jwtSecret: envVars.JWT_SECRET,
  jwtExpiry: envVars.JWT_EXPIRY,
  bcryptRounds: envVars.BCRYPT_ROUNDS,
  allowedOrigins: envVars.ALLOWED_ORIGINS.split(','),
  cookieSecret: envVars.COOKIE_SECRET,
};

// src/middleware/performance.ts
import { Request, Response, NextFunction } from 'express';
import { logger } from '../utils/logger';

export const performanceMiddleware = (req: Request, res: Response, next: NextFunction) => {
  const startTime = Date.now();
  
  res.on('finish', () => {
    const duration = Date.now() - startTime;
    
    if (duration > 2000) { // Log slow requests
      logger.warn('Slow request detected', {
        method: req.method,
        url: req.originalUrl,
        duration: `${duration}ms`,
        ip: req.ip,
        userAgent: req.get('User-Agent')
      });
    }
  });
  
  next();
};
```

## 🔐 Authentication Templates

### 1. **JWT Authentication System**

#### Complete JWT Implementation
```typescript
// ✅ JWT Authentication Service
// src/services/auth.service.ts
import jwt from 'jsonwebtoken';
import bcrypt from 'bcryptjs';
import crypto from 'crypto';
import { User } from '../models/user.model';
import { AppError } from '../utils/appError';
import { config } from '../config';

export interface AuthTokens {
  accessToken: string;
  refreshToken: string;
}

export interface TokenPayload {
  id: string;
  email: string;
  role: string;
}

export class AuthService {
  async register(userData: {
    name: string;
    email: string;
    password: string;
  }) {
    // Check if user exists
    const existingUser = await User.findOne({ email: userData.email });
    if (existingUser) {
      throw new AppError('User already exists', 409);
    }

    // Hash password
    const hashedPassword = await bcrypt.hash(userData.password, config.bcryptRounds);

    // Create user
    const user = await User.create({
      ...userData,
      password: hashedPassword,
      emailVerified: false,
      verificationToken: this.generateVerificationToken(),
    });

    // Generate tokens
    const tokens = this.generateTokenPair({
      id: user._id.toString(),
      email: user.email,
      role: user.role,
    });

    return {
      user: this.sanitizeUser(user),
      ...tokens,
    };
  }

  async login(email: string, password: string) {
    // Find user
    const user = await User.findOne({ email }).select('+password');
    if (!user) {
      throw new AppError('Invalid credentials', 401);
    }

    // Check password
    const isPasswordValid = await bcrypt.compare(password, user.password);
    if (!isPasswordValid) {
      throw new AppError('Invalid credentials', 401);
    }

    // Check if email is verified
    if (!user.emailVerified) {
      throw new AppError('Please verify your email first', 401);
    }

    // Update last login
    user.lastLoginAt = new Date();
    await user.save();

    // Generate tokens
    const tokens = this.generateTokenPair({
      id: user._id.toString(),
      email: user.email,
      role: user.role,
    });

    return {
      user: this.sanitizeUser(user),
      ...tokens,
    };
  }

  generateTokenPair(payload: TokenPayload): AuthTokens {
    const accessToken = jwt.sign(payload, config.jwtSecret, {
      expiresIn: '15m',
      issuer: 'myapp',
      audience: 'myapp-users',
    });

    const refreshToken = jwt.sign(
      { ...payload, type: 'refresh' },
      config.jwtSecret,
      {
        expiresIn: config.jwtExpiry,
        issuer: 'myapp',
        audience: 'myapp-users',
      }
    );

    return { accessToken, refreshToken };
  }

  verifyAccessToken(token: string): TokenPayload {
    try {
      const decoded = jwt.verify(token, config.jwtSecret, {
        issuer: 'myapp',
        audience: 'myapp-users',
      }) as any;

      return {
        id: decoded.id,
        email: decoded.email,
        role: decoded.role,
      };
    } catch (error) {
      throw new AppError('Invalid or expired token', 401);
    }
  }

  async refreshTokens(refreshToken: string): Promise<AuthTokens> {
    try {
      const decoded = jwt.verify(refreshToken, config.jwtSecret, {
        issuer: 'myapp',
        audience: 'myapp-users',
      }) as any;

      if (decoded.type !== 'refresh') {
        throw new AppError('Invalid token type', 401);
      }

      // Verify user still exists
      const user = await User.findById(decoded.id);
      if (!user) {
        throw new AppError('User not found', 401);
      }

      // Generate new token pair
      return this.generateTokenPair({
        id: user._id.toString(),
        email: user.email,
        role: user.role,
      });
    } catch (error) {
      throw new AppError('Invalid refresh token', 401);
    }
  }

  private generateVerificationToken(): string {
    return crypto.randomBytes(32).toString('hex');
  }

  private sanitizeUser(user: any) {
    const { password, verificationToken, resetToken, ...sanitized } = user.toObject();
    return sanitized;
  }
}

// src/middleware/auth.middleware.ts
import { Request, Response, NextFunction } from 'express';
import { AuthService } from '../services/auth.service';
import { User } from '../models/user.model';
import { AppError } from '../utils/appError';

export interface AuthRequest extends Request {
  user?: any;
}

const authService = new AuthService();

export const authenticateToken = async (
  req: AuthRequest,
  res: Response,
  next: NextFunction
) => {
  try {
    const authHeader = req.headers.authorization;
    const token = authHeader && authHeader.split(' ')[1];

    if (!token) {
      throw new AppError('Access token required', 401);
    }

    const decoded = authService.verifyAccessToken(token);
    const user = await User.findById(decoded.id);

    if (!user) {
      throw new AppError('User not found', 401);
    }

    req.user = user;
    next();
  } catch (error) {
    next(error);
  }
};

export const authorize = (...roles: string[]) => {
  return (req: AuthRequest, res: Response, next: NextFunction) => {
    if (!req.user) {
      return next(new AppError('Authentication required', 401));
    }

    if (!roles.includes(req.user.role)) {
      return next(new AppError('Insufficient permissions', 403));
    }

    next();
  };
};

// src/controllers/auth.controller.ts
import { Request, Response, NextFunction } from 'express';
import { AuthService } from '../services/auth.service';
import { AuthRequest } from '../middleware/auth.middleware';
import { asyncHandler } from '../utils/asyncHandler';

export class AuthController {
  private authService = new AuthService();

  register = asyncHandler(async (req: Request, res: Response) => {
    const result = await this.authService.register(req.body);
    
    // Set refresh token in httpOnly cookie
    res.cookie('refreshToken', result.refreshToken, {
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'strict',
      maxAge: 7 * 24 * 60 * 60 * 1000, // 7 days
    });

    res.status(201).json({
      success: true,
      message: 'User registered successfully',
      data: {
        user: result.user,
        accessToken: result.accessToken,
      },
    });
  });

  login = asyncHandler(async (req: Request, res: Response) => {
    const { email, password } = req.body;
    const result = await this.authService.login(email, password);

    // Set refresh token in httpOnly cookie
    res.cookie('refreshToken', result.refreshToken, {
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'strict',
      maxAge: 7 * 24 * 60 * 60 * 1000, // 7 days
    });

    res.json({
      success: true,
      message: 'Login successful',
      data: {
        user: result.user,
        accessToken: result.accessToken,
      },
    });
  });

  refreshToken = asyncHandler(async (req: Request, res: Response) => {
    const refreshToken = req.cookies.refreshToken;
    
    if (!refreshToken) {
      return res.status(401).json({ error: 'Refresh token required' });
    }

    const tokens = await this.authService.refreshTokens(refreshToken);

    // Set new refresh token
    res.cookie('refreshToken', tokens.refreshToken, {
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'strict',
      maxAge: 7 * 24 * 60 * 60 * 1000, // 7 days
    });

    res.json({
      success: true,
      data: {
        accessToken: tokens.accessToken,
      },
    });
  });

  logout = asyncHandler(async (req: AuthRequest, res: Response) => {
    res.clearCookie('refreshToken');
    
    res.json({
      success: true,
      message: 'Logged out successfully',
    });
  });

  getProfile = asyncHandler(async (req: AuthRequest, res: Response) => {
    res.json({
      success: true,
      data: req.user,
    });
  });
}
```

### 2. **Multi-Factor Authentication Template**

#### TOTP-based MFA Implementation
```typescript
// ✅ Multi-Factor Authentication Service
// src/services/mfa.service.ts
import speakeasy from 'speakeasy';
import qrcode from 'qrcode';
import { User } from '../models/user.model';
import { AppError } from '../utils/appError';

export class MFAService {
  async setupTOTP(userId: string) {
    const user = await User.findById(userId);
    if (!user) {
      throw new AppError('User not found', 404);
    }

    // Generate secret
    const secret = speakeasy.generateSecret({
      name: `MyApp (${user.email})`,
      issuer: 'MyApp',
      length: 32,
    });

    // Store secret temporarily (not activated yet)
    user.mfaSecret = secret.base32;
    user.mfaEnabled = false;
    await user.save();

    // Generate QR code
    const qrCodeUrl = await qrcode.toDataURL(secret.otpauth_url);

    return {
      secret: secret.base32,
      qrCode: qrCodeUrl,
      manualEntryKey: secret.base32,
    };
  }

  async verifyTOTP(userId: string, token: string) {
    const user = await User.findById(userId);
    if (!user || !user.mfaSecret) {
      throw new AppError('MFA not set up', 400);
    }

    const isValid = speakeasy.totp.verify({
      secret: user.mfaSecret,
      encoding: 'base32',
      token,
      window: 2, // Allow 2 time steps of variance
    });

    if (!isValid) {
      throw new AppError('Invalid MFA token', 400);
    }

    // Enable MFA if this is the first verification
    if (!user.mfaEnabled) {
      user.mfaEnabled = true;
      await user.save();
    }

    return { verified: true };
  }

  async disableMFA(userId: string, token: string) {
    const user = await User.findById(userId);
    if (!user || !user.mfaEnabled) {
      throw new AppError('MFA not enabled', 400);
    }

    // Verify current token before disabling
    const isValid = speakeasy.totp.verify({
      secret: user.mfaSecret,
      encoding: 'base32',
      token,
      window: 2,
    });

    if (!isValid) {
      throw new AppError('Invalid MFA token', 400);
    }

    // Disable MFA
    user.mfaEnabled = false;
    user.mfaSecret = undefined;
    await user.save();

    return { disabled: true };
  }

  async generateBackupCodes(userId: string): Promise<string[]> {
    const user = await User.findById(userId);
    if (!user) {
      throw new AppError('User not found', 404);
    }

    // Generate 10 backup codes
    const backupCodes = Array.from({ length: 10 }, () =>
      Math.random().toString(36).substring(2, 10).toUpperCase()
    );

    // Hash and store backup codes
    const hashedCodes = await Promise.all(
      backupCodes.map(code => bcrypt.hash(code, 12))
    );

    user.mfaBackupCodes = hashedCodes;
    await user.save();

    return backupCodes;
  }

  async verifyBackupCode(userId: string, code: string): Promise<boolean> {
    const user = await User.findById(userId);
    if (!user || !user.mfaBackupCodes?.length) {
      throw new AppError('No backup codes available', 400);
    }

    // Check if code matches any backup code
    for (let i = 0; i < user.mfaBackupCodes.length; i++) {
      const isMatch = await bcrypt.compare(code, user.mfaBackupCodes[i]);
      if (isMatch) {
        // Remove used backup code
        user.mfaBackupCodes.splice(i, 1);
        await user.save();
        return true;
      }
    }

    throw new AppError('Invalid backup code', 400);
  }
}

// src/controllers/mfa.controller.ts
import { Response, NextFunction } from 'express';
import { MFAService } from '../services/mfa.service';
import { AuthRequest } from '../middleware/auth.middleware';
import { asyncHandler } from '../utils/asyncHandler';

export class MFAController {
  private mfaService = new MFAService();

  setupTOTP = asyncHandler(async (req: AuthRequest, res: Response) => {
    const result = await this.mfaService.setupTOTP(req.user.id);

    res.json({
      success: true,
      message: 'MFA setup initiated',
      data: result,
    });
  });

  verifyTOTP = asyncHandler(async (req: AuthRequest, res: Response) => {
    const { token } = req.body;
    const result = await this.mfaService.verifyTOTP(req.user.id, token);

    res.json({
      success: true,
      message: 'MFA verified successfully',
      data: result,
    });
  });

  disableMFA = asyncHandler(async (req: AuthRequest, res: Response) => {
    const { token } = req.body;
    const result = await this.mfaService.disableMFA(req.user.id, token);

    res.json({
      success: true,
      message: 'MFA disabled successfully',
      data: result,
    });
  });

  generateBackupCodes = asyncHandler(async (req: AuthRequest, res: Response) => {
    const backupCodes = await this.mfaService.generateBackupCodes(req.user.id);

    res.json({
      success: true,
      message: 'Backup codes generated',
      data: { backupCodes },
    });
  });

  verifyBackupCode = asyncHandler(async (req: AuthRequest, res: Response) => {
    const { code } = req.body;
    const result = await this.mfaService.verifyBackupCode(req.user.id, code);

    res.json({
      success: true,
      message: 'Backup code verified',
      data: { verified: result },
    });
  });
}
```

## 🗄️ Database Templates

### 1. **MongoDB with Mongoose Template**

#### Complete Mongoose Setup
```typescript
// ✅ MongoDB Connection and Models
// src/config/database.ts
import mongoose from 'mongoose';
import { config } from './index';
import { logger } from '../utils/logger';

export const connectDatabase = async () => {
  try {
    const conn = await mongoose.connect(config.mongoUri, {
      maxPoolSize: 10,
      serverSelectionTimeoutMS: 5000,
      socketTimeoutMS: 45000,
      bufferCommands: false,
      bufferMaxEntries: 0,
    });

    // Connection event handlers
    mongoose.connection.on('connected', () => {
      logger.info('MongoDB connected successfully');
    });

    mongoose.connection.on('error', (err) => {
      logger.error('MongoDB connection error:', err);
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

    logger.info(`MongoDB Connected: ${conn.connection.host}`);
  } catch (error) {
    logger.error('Database connection failed:', error);
    process.exit(1);
  }
};

// src/models/user.model.ts
import mongoose from 'mongoose';
import bcrypt from 'bcryptjs';

export interface IUser extends mongoose.Document {
  name: string;
  email: string;
  password: string;
  role: 'user' | 'admin';
  emailVerified: boolean;
  verificationToken?: string;
  resetToken?: string;
  resetTokenExpiry?: Date;
  mfaEnabled: boolean;
  mfaSecret?: string;
  mfaBackupCodes?: string[];
  lastLoginAt?: Date;
  createdAt: Date;
  updatedAt: Date;
  comparePassword(candidatePassword: string): Promise<boolean>;
}

const userSchema = new mongoose.Schema<IUser>({
  name: {
    type: String,
    required: [true, 'Name is required'],
    trim: true,
    maxlength: [50, 'Name cannot exceed 50 characters'],
  },
  email: {
    type: String,
    required: [true, 'Email is required'],
    unique: true,
    lowercase: true,
    match: [/^\S+@\S+\.\S+$/, 'Please enter a valid email'],
  },
  password: {
    type: String,
    required: [true, 'Password is required'],
    minlength: [8, 'Password must be at least 8 characters'],
    select: false,
  },
  role: {
    type: String,
    enum: ['user', 'admin'],
    default: 'user',
  },
  emailVerified: {
    type: Boolean,
    default: false,
  },
  verificationToken: String,
  resetToken: String,
  resetTokenExpiry: Date,
  mfaEnabled: {
    type: Boolean,
    default: false,
  },
  mfaSecret: String,
  mfaBackupCodes: [String],
  lastLoginAt: Date,
}, {
  timestamps: true,
  toJSON: {
    virtuals: true,
    transform: function(doc, ret) {
      delete ret.password;
      delete ret.verificationToken;
      delete ret.resetToken;
      delete ret.mfaSecret;
      delete ret.mfaBackupCodes;
      delete ret.__v;
      return ret;
    },
  },
});

// Indexes
userSchema.index({ email: 1 }, { unique: true });
userSchema.index({ role: 1 });
userSchema.index({ emailVerified: 1 });
userSchema.index({ createdAt: -1 });

// Virtual for user profile
userSchema.virtual('profile').get(function() {
  return {
    id: this._id,
    name: this.name,
    email: this.email,
    role: this.role,
    emailVerified: this.emailVerified,
    mfaEnabled: this.mfaEnabled,
    lastLoginAt: this.lastLoginAt,
    createdAt: this.createdAt,
  };
});

// Methods
userSchema.methods.comparePassword = async function(candidatePassword: string): Promise<boolean> {
  return await bcrypt.compare(candidatePassword, this.password);
};

// Pre-save middleware
userSchema.pre('save', async function(next) {
  if (!this.isModified('password')) return next();
  
  const salt = await bcrypt.genSalt(12);
  this.password = await bcrypt.hash(this.password, salt);
  next();
});

export const User = mongoose.model<IUser>('User', userSchema);

// src/repositories/user.repository.ts
import { User, IUser } from '../models/user.model';
import { AppError } from '../utils/appError';

export interface CreateUserDto {
  name: string;
  email: string;
  password: string;
  role?: 'user' | 'admin';
}

export interface UpdateUserDto {
  name?: string;
  email?: string;
  role?: 'user' | 'admin';
}

export interface PaginationOptions {
  page: number;
  limit: number;
  sort?: string;
  filter?: any;
}

export class UserRepository {
  async create(userData: CreateUserDto): Promise<IUser> {
    try {
      const user = await User.create(userData);
      return user;
    } catch (error: any) {
      if (error.code === 11000) {
        throw new AppError('User with this email already exists', 409);
      }
      throw new AppError('Failed to create user', 500);
    }
  }

  async findById(id: string): Promise<IUser | null> {
    return await User.findById(id);
  }

  async findByEmail(email: string): Promise<IUser | null> {
    return await User.findOne({ email }).select('+password');
  }

  async findWithPagination(options: PaginationOptions) {
    const { page, limit, sort = '-createdAt', filter = {} } = options;
    const skip = (page - 1) * limit;

    const [users, total] = await Promise.all([
      User.find(filter)
        .sort(sort)
        .skip(skip)
        .limit(limit)
        .lean(),
      User.countDocuments(filter),
    ]);

    return {
      users,
      pagination: {
        page,
        limit,
        total,
        pages: Math.ceil(total / limit),
        hasNext: page * limit < total,
        hasPrev: page > 1,
      },
    };
  }

  async update(id: string, updateData: UpdateUserDto): Promise<IUser | null> {
    return await User.findByIdAndUpdate(
      id,
      { $set: updateData },
      { new: true, runValidators: true }
    );
  }

  async delete(id: string): Promise<void> {
    const result = await User.findByIdAndDelete(id);
    if (!result) {
      throw new AppError('User not found', 404);
    }
  }

  async exists(email: string): Promise<boolean> {
    const count = await User.countDocuments({ email });
    return count > 0;
  }
}
```

### 2. **PostgreSQL with Prisma Template**

#### Complete Prisma Setup
```typescript
// ✅ Prisma Schema and Setup
// prisma/schema.prisma
generator client {
  provider = "prisma-client-js"
  binaryTargets = ["native", "linux-musl"]
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

model User {
  id                String    @id @default(cuid())
  email             String    @unique
  name              String
  password          String
  role              Role      @default(USER)
  emailVerified     Boolean   @default(false)
  verificationToken String?
  resetToken        String?
  resetTokenExpiry  DateTime?
  mfaEnabled        Boolean   @default(false)
  mfaSecret         String?
  lastLoginAt       DateTime?
  createdAt         DateTime  @default(now())
  updatedAt         DateTime  @updatedAt

  // Relations
  posts    Post[]
  comments Comment[]

  @@map("users")
}

model Post {
  id        String    @id @default(cuid())
  title     String
  content   String?
  published Boolean   @default(false)
  authorId  String
  author    User      @relation(fields: [authorId], references: [id], onDelete: Cascade)
  comments  Comment[]
  createdAt DateTime  @default(now())
  updatedAt DateTime  @updatedAt

  @@map("posts")
}

model Comment {
  id      String @id @default(cuid())
  content String
  postId  String
  post    Post   @relation(fields: [postId], references: [id], onDelete: Cascade)
  userId  String
  user    User   @relation(fields: [userId], references: [id], onDelete: Cascade)
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt

  @@map("comments")
}

enum Role {
  USER
  ADMIN
}

// src/config/database.ts
import { PrismaClient } from '@prisma/client';
import { logger } from '../utils/logger';

const prisma = new PrismaClient({
  log: process.env.NODE_ENV === 'development' 
    ? ['query', 'info', 'warn', 'error'] 
    : ['error'],
});

// Middleware for soft deletes
prisma.$use(async (params, next) => {
  if (params.action === 'delete') {
    params.action = 'update';
    params.args['data'] = { deletedAt: new Date() };
  }
  
  if (params.action === 'deleteMany') {
    params.action = 'updateMany';
    if (params.args.data != undefined) {
      params.args.data['deletedAt'] = new Date();
    } else {
      params.args['data'] = { deletedAt: new Date() };
    }
  }

  return next(params);
});

// Graceful shutdown
process.on('beforeExit', async () => {
  await prisma.$disconnect();
  logger.info('Prisma disconnected');
});

export { prisma };

// src/repositories/user.repository.prisma.ts
import { prisma } from '../config/database';
import { User, Prisma } from '@prisma/client';
import { AppError } from '../utils/appError';
import bcrypt from 'bcryptjs';

export interface CreateUserDto {
  name: string;
  email: string;
  password: string;
  role?: 'USER' | 'ADMIN';
}

export interface UpdateUserDto {
  name?: string;
  email?: string;
  role?: 'USER' | 'ADMIN';
}

export class UserRepositoryPrisma {
  async create(userData: CreateUserDto): Promise<User> {
    try {
      // Hash password
      const hashedPassword = await bcrypt.hash(userData.password, 12);

      const user = await prisma.user.create({
        data: {
          ...userData,
          password: hashedPassword,
        },
        include: {
          posts: {
            select: {
              id: true,
              title: true,
              published: true,
              createdAt: true,
            },
            take: 5,
            orderBy: {
              createdAt: 'desc',
            },
          },
        },
      });

      return user;
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError) {
        if (error.code === 'P2002') {
          throw new AppError('User with this email already exists', 409);
        }
      }
      throw new AppError('Failed to create user', 500);
    }
  }

  async findById(id: string): Promise<User | null> {
    return await prisma.user.findUnique({
      where: { id },
      include: {
        posts: {
          select: {
            id: true,
            title: true,
            published: true,
            createdAt: true,
          },
          take: 5,
          orderBy: {
            createdAt: 'desc',
          },
        },
      },
    });
  }

  async findByEmail(email: string): Promise<User | null> {
    return await prisma.user.findUnique({
      where: { email },
    });
  }

  async findWithPagination(
    page: number = 1,
    limit: number = 20,
    filters: {
      search?: string;
      role?: 'USER' | 'ADMIN';
      emailVerified?: boolean;
    } = {}
  ) {
    const skip = (page - 1) * limit;

    const where: Prisma.UserWhereInput = {};

    if (filters.search) {
      where.OR = [
        { name: { contains: filters.search, mode: 'insensitive' } },
        { email: { contains: filters.search, mode: 'insensitive' } },
      ];
    }

    if (filters.role) {
      where.role = filters.role;
    }

    if (filters.emailVerified !== undefined) {
      where.emailVerified = filters.emailVerified;
    }

    const [users, total] = await Promise.all([
      prisma.user.findMany({
        where,
        skip,
        take: limit,
        include: {
          posts: {
            select: {
              id: true,
              title: true,
              published: true,
            },
            take: 3,
          },
        },
        orderBy: {
          createdAt: 'desc',
        },
      }),
      prisma.user.count({ where }),
    ]);

    return {
      users,
      pagination: {
        page,
        limit,
        total,
        pages: Math.ceil(total / limit),
        hasNext: page * limit < total,
        hasPrev: page > 1,
      },
    };
  }

  async update(id: string, updateData: UpdateUserDto): Promise<User | null> {
    try {
      return await prisma.user.update({
        where: { id },
        data: updateData,
        include: {
          posts: {
            select: {
              id: true,
              title: true,
              published: true,
            },
            take: 5,
          },
        },
      });
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError) {
        if (error.code === 'P2025') {
          throw new AppError('User not found', 404);
        }
        if (error.code === 'P2002') {
          throw new AppError('Email already exists', 409);
        }
      }
      throw new AppError('Failed to update user', 500);
    }
  }

  async delete(id: string): Promise<void> {
    try {
      await prisma.user.delete({
        where: { id },
      });
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError) {
        if (error.code === 'P2025') {
          throw new AppError('User not found', 404);
        }
      }
      throw new AppError('Failed to delete user', 500);
    }
  }

  async exists(email: string): Promise<boolean> {
    const count = await prisma.user.count({
      where: { email },
    });
    return count > 0;
  }
}
```

## 🧪 Testing Templates

### 1. **Jest Testing Setup Template**

#### Complete Jest Configuration
```typescript
// ✅ Jest Testing Configuration
// jest.config.js
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  roots: ['<rootDir>/src'],
  testMatch: ['**/__tests__/**/*.ts', '**/?(*.)+(spec|test).ts'],
  transform: {
    '^.+\\.ts$': 'ts-jest',
  },
  collectCoverageFrom: [
    'src/**/*.ts',
    '!src/**/*.d.ts',
    '!src/index.ts',
    '!src/**/*.interface.ts',
  ],
  coverageDirectory: 'coverage',
  coverageReporters: ['text', 'lcov', 'html'],
  setupFilesAfterEnv: ['<rootDir>/src/tests/setup.ts'],
  testTimeout: 30000,
  verbose: true,
};

// src/tests/setup.ts
import { MongoMemoryServer } from 'mongodb-memory-server';
import mongoose from 'mongoose';

let mongoServer: MongoMemoryServer;

beforeAll(async () => {
  mongoServer = await MongoMemoryServer.create();
  const mongoUri = mongoServer.getUri();
  await mongoose.connect(mongoUri);
});

afterAll(async () => {
  await mongoose.disconnect();
  if (mongoServer) {
    await mongoServer.stop();
  }
});

beforeEach(async () => {
  const collections = mongoose.connection.collections;
  for (const key in collections) {
    await collections[key].deleteMany({});
  }
});

// src/tests/factories/user.factory.ts
import { User } from '../../models/user.model';
import { faker } from '@faker-js/faker';

export class UserFactory {
  static build(overrides = {}) {
    return {
      name: faker.person.fullName(),
      email: faker.internet.email(),
      password: 'Password123!',
      role: 'user',
      emailVerified: true,
      ...overrides,
    };
  }

  static async create(overrides = {}) {
    const userData = this.build(overrides);
    return await User.create(userData);
  }

  static async createMany(count: number, overrides = {}) {
    const users = [];
    for (let i = 0; i < count; i++) {
      const user = await this.create({
        ...overrides,
        email: `user${i}@example.com`,
      });
      users.push(user);
    }
    return users;
  }
}

// src/tests/integration/auth.test.ts
import request from 'supertest';
import app from '../../app';
import { UserFactory } from '../factories/user.factory';

describe('Authentication API', () => {
  describe('POST /api/auth/register', () => {
    const validUserData = {
      name: 'John Doe',
      email: 'john@example.com',
      password: 'Password123!',
      confirmPassword: 'Password123!',
    };

    it('should register user with valid data', async () => {
      const response = await request(app)
        .post('/api/auth/register')
        .send(validUserData)
        .expect(201);

      expect(response.body).toEqual({
        success: true,
        message: 'User registered successfully',
        data: {
          user: {
            id: expect.any(String),
            name: validUserData.name,
            email: validUserData.email,
            role: 'user',
            emailVerified: false,
            mfaEnabled: false,
            createdAt: expect.any(String),
            updatedAt: expect.any(String),
          },
          accessToken: expect.any(String),
        },
      });

      // Check if refresh token cookie is set
      const cookies = response.headers['set-cookie'];
      expect(cookies).toBeDefined();
      expect(cookies.some(cookie => cookie.startsWith('refreshToken='))).toBe(true);
    });

    it('should return 400 for invalid email', async () => {
      const response = await request(app)
        .post('/api/auth/register')
        .send({
          ...validUserData,
          email: 'invalid-email',
        })
        .expect(400);

      expect(response.body.success).toBe(false);
      expect(response.body.error).toContain('email');
    });

    it('should return 409 for existing user', async () => {
      await UserFactory.create({ email: validUserData.email });

      const response = await request(app)
        .post('/api/auth/register')
        .send(validUserData)
        .expect(409);

      expect(response.body.error).toContain('already exists');
    });
  });

  describe('POST /api/auth/login', () => {
    let user: any;

    beforeEach(async () => {
      user = await UserFactory.create({
        email: 'test@example.com',
        password: 'Password123!',
        emailVerified: true,
      });
    });

    it('should login with valid credentials', async () => {
      const response = await request(app)
        .post('/api/auth/login')
        .send({
          email: 'test@example.com',
          password: 'Password123!',
        })
        .expect(200);

      expect(response.body).toEqual({
        success: true,
        message: 'Login successful',
        data: {
          user: expect.objectContaining({
            id: user.id,
            email: user.email,
            name: user.name,
          }),
          accessToken: expect.any(String),
        },
      });
    });

    it('should return 401 for invalid credentials', async () => {
      const response = await request(app)
        .post('/api/auth/login')
        .send({
          email: 'test@example.com',
          password: 'wrongpassword',
        })
        .expect(401);

      expect(response.body.error).toContain('Invalid credentials');
    });
  });
});
```

## 🎯 Template Usage Guide

### ✅ Template Selection Checklist

**Choose Minimal API Starter when:**
- [ ] Building a simple REST API
- [ ] Small team (1-3 developers)
- [ ] Rapid prototyping needed
- [ ] Basic requirements

**Choose Production-Ready Template when:**
- [ ] Building for production environment
- [ ] Security is a priority
- [ ] Performance optimization needed
- [ ] Comprehensive error handling required

**Choose JWT Authentication when:**
- [ ] Stateless authentication needed
- [ ] API-first application
- [ ] Mobile app support required
- [ ] Microservices architecture

**Choose MFA Template when:**
- [ ] High security requirements
- [ ] Compliance needs (GDPR, HIPAA)
- [ ] Enterprise application
- [ ] Financial or healthcare domain

**Choose MongoDB Template when:**
- [ ] Flexible schema requirements
- [ ] Rapid development needed
- [ ] Document-based data structure
- [ ] Horizontal scaling planned

**Choose PostgreSQL Template when:**
- [ ] Relational data structure
- [ ] ACID compliance required
- [ ] Complex queries needed
- [ ] Type safety priority

---

## 🧭 Navigation

### ⬅️ Previous: [Comparison Analysis](./comparison-analysis.md)
### ➡️ Next: [README](./README.md)

---

*Code templates based on proven patterns from production Express.js applications.*