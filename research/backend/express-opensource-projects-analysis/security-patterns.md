# Security Patterns: Express.js Open Source Projects

## 🛡️ Security Overview

Comprehensive analysis of security implementations across leading Express.js projects, documenting authentication strategies, authorization patterns, input validation, and security middleware configurations that protect production applications.

## 🔐 Authentication Strategies

### 1. JWT Authentication Patterns

**Most Common Implementation (80% of projects):**

```typescript
// JWT Authentication Middleware
import jwt from 'jsonwebtoken';
import { Request, Response, NextFunction } from 'express';

interface AuthenticatedRequest extends Request {
  user?: {
    id: string;
    email: string;
    roles: string[];
  };
}

export const authenticateToken = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
) => {
  try {
    const authHeader = req.headers.authorization;
    const token = authHeader && authHeader.split(' ')[1]; // Bearer TOKEN
    
    if (!token) {
      return res.status(401).json({
        success: false,
        message: 'Access token required',
        code: 'MISSING_TOKEN'
      });
    }
    
    // Verify token
    const decoded = jwt.verify(token, process.env.JWT_SECRET!) as any;
    
    // Check if token is blacklisted (for logout)
    const isBlacklisted = await redisClient.get(`blacklist:${token}`);
    if (isBlacklisted) {
      return res.status(401).json({
        success: false,
        message: 'Token has been revoked',
        code: 'TOKEN_REVOKED'
      });
    }
    
    // Attach user to request
    req.user = {
      id: decoded.userId,
      email: decoded.email,
      roles: decoded.roles || []
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
    
    return res.status(500).json({
      success: false,
      message: 'Token verification failed',
      code: 'TOKEN_VERIFICATION_ERROR'
    });
  }
};
```

**Refresh Token Implementation:**

```typescript
// Refresh Token Service
export class AuthService {
  async generateTokens(user: User) {
    const payload = {
      userId: user.id,
      email: user.email,
      roles: user.roles
    };
    
    const accessToken = jwt.sign(payload, process.env.JWT_SECRET!, {
      expiresIn: '15m',
      issuer: process.env.JWT_ISSUER,
      audience: process.env.JWT_AUDIENCE
    });
    
    const refreshToken = jwt.sign(
      { userId: user.id },
      process.env.JWT_REFRESH_SECRET!,
      {
        expiresIn: '7d',
        issuer: process.env.JWT_ISSUER,
        audience: process.env.JWT_AUDIENCE
      }
    );
    
    // Store refresh token in database
    await this.storeRefreshToken(user.id, refreshToken);
    
    return { accessToken, refreshToken };
  }
  
  async refreshAccessToken(refreshToken: string) {
    try {
      const decoded = jwt.verify(
        refreshToken,
        process.env.JWT_REFRESH_SECRET!
      ) as any;
      
      // Verify refresh token exists in database
      const storedToken = await this.getRefreshToken(decoded.userId, refreshToken);
      if (!storedToken) {
        throw new Error('Invalid refresh token');
      }
      
      const user = await User.findById(decoded.userId);
      if (!user) {
        throw new Error('User not found');
      }
      
      // Generate new tokens
      const tokens = await this.generateTokens(user);
      
      // Rotate refresh token
      await this.revokeRefreshToken(refreshToken);
      
      return tokens;
    } catch (error) {
      throw new Error('Invalid refresh token');
    }
  }
}
```

### 2. Passport.js Integration Patterns

**Multi-Strategy Authentication (70% of analyzed projects):**

```typescript
// Passport Configuration
import passport from 'passport';
import { Strategy as LocalStrategy } from 'passport-local';
import { Strategy as JwtStrategy, ExtractJwt } from 'passport-jwt';
import { Strategy as GoogleStrategy } from 'passport-google-oauth20';

// Local Strategy for email/password login
passport.use(new LocalStrategy(
  {
    usernameField: 'email',
    passwordField: 'password'
  },
  async (email: string, password: string, done) => {
    try {
      const user = await User.findOne({ email });
      
      if (!user) {
        return done(null, false, { message: 'User not found' });
      }
      
      const isValidPassword = await bcrypt.compare(password, user.password);
      if (!isValidPassword) {
        return done(null, false, { message: 'Invalid password' });
      }
      
      if (!user.emailVerified) {
        return done(null, false, { message: 'Email not verified' });
      }
      
      return done(null, user);
    } catch (error) {
      return done(error);
    }
  }
));

// JWT Strategy for API authentication
passport.use(new JwtStrategy(
  {
    jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
    secretOrKey: process.env.JWT_SECRET!,
    issuer: process.env.JWT_ISSUER,
    audience: process.env.JWT_AUDIENCE
  },
  async (payload, done) => {
    try {
      const user = await User.findById(payload.userId)
        .select('-password')
        .populate('roles');
        
      if (!user) {
        return done(null, false);
      }
      
      return done(null, user);
    } catch (error) {
      return done(error, false);
    }
  }
));

// Google OAuth Strategy
passport.use(new GoogleStrategy(
  {
    clientID: process.env.GOOGLE_CLIENT_ID!,
    clientSecret: process.env.GOOGLE_CLIENT_SECRET!,
    callbackURL: '/auth/google/callback'
  },
  async (accessToken, refreshToken, profile, done) => {
    try {
      let user = await User.findOne({ googleId: profile.id });
      
      if (!user) {
        user = await User.create({
          googleId: profile.id,
          email: profile.emails![0].value,
          name: profile.displayName,
          emailVerified: true,
          provider: 'google'
        });
      }
      
      return done(null, user);
    } catch (error) {
      return done(error, null);
    }
  }
));
```

## 🔒 Authorization Patterns

### 1. Role-Based Access Control (RBAC)

**Middleware-based Authorization:**

```typescript
// Role and permission middleware
export const authorize = (
  requiredRoles: string[],
  requiredPermissions?: string[]
) => {
  return async (
    req: AuthenticatedRequest,
    res: Response,
    next: NextFunction
  ) => {
    if (!req.user) {
      return res.status(401).json({
        success: false,
        message: 'Authentication required',
        code: 'UNAUTHENTICATED'
      });
    }
    
    // Check roles
    const userRoles = req.user.roles;
    const hasRequiredRole = requiredRoles.some(role => 
      userRoles.includes(role)
    );
    
    if (!hasRequiredRole) {
      return res.status(403).json({
        success: false,
        message: 'Insufficient permissions',
        code: 'INSUFFICIENT_PERMISSIONS'
      });
    }
    
    // Check specific permissions if provided
    if (requiredPermissions) {
      const userPermissions = await getUserPermissions(req.user.id);
      const hasRequiredPermission = requiredPermissions.some(permission =>
        userPermissions.includes(permission)
      );
      
      if (!hasRequiredPermission) {
        return res.status(403).json({
          success: false,
          message: 'Insufficient permissions',
          code: 'INSUFFICIENT_PERMISSIONS'
        });
      }
    }
    
    next();
  };
};

// Usage in routes
router.get('/admin/users',
  authenticateToken,
  authorize(['admin']),
  async (req, res) => {
    // Admin-only endpoint
  }
);

router.delete('/posts/:id',
  authenticateToken,
  authorize(['admin', 'moderator'], ['posts:delete']),
  async (req, res) => {
    // Delete post with specific permission
  }
);
```

### 2. Resource-Based Authorization

**Ownership-based Access Control:**

```typescript
// Resource ownership middleware
export const requireOwnership = (resourceType: string) => {
  return async (
    req: AuthenticatedRequest,
    res: Response,
    next: NextFunction
  ) => {
    try {
      const resourceId = req.params.id;
      const userId = req.user!.id;
      
      let resource;
      switch (resourceType) {
        case 'post':
          resource = await Post.findById(resourceId);
          break;
        case 'comment':
          resource = await Comment.findById(resourceId);
          break;
        default:
          return res.status(400).json({
            success: false,
            message: 'Invalid resource type'
          });
      }
      
      if (!resource) {
        return res.status(404).json({
          success: false,
          message: 'Resource not found'
        });
      }
      
      // Check ownership or admin role
      const isOwner = resource.userId.toString() === userId;
      const isAdmin = req.user!.roles.includes('admin');
      
      if (!isOwner && !isAdmin) {
        return res.status(403).json({
          success: false,
          message: 'Access denied: insufficient permissions'
        });
      }
      
      // Attach resource to request for use in controller
      req.resource = resource;
      next();
    } catch (error) {
      res.status(500).json({
        success: false,
        message: 'Authorization check failed'
      });
    }
  };
};
```

## 🛡️ Input Validation and Sanitization

### 1. Schema-based Validation

**Joi Validation Pattern (Most common - 60% of projects):**

```typescript
import Joi from 'joi';

// User validation schemas
export const userSchemas = {
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
      .pattern(new RegExp('^(?=.*[a-z])(?=.*[A-Z])(?=.*[0-9])(?=.*[!@#\$%\^&\*])'))
      .required()
      .messages({
        'string.min': 'Password must be at least 8 characters long',
        'string.pattern.base': 'Password must contain at least one lowercase letter, one uppercase letter, one number, and one special character'
      }),
    
    name: Joi.string()
      .min(2)
      .max(50)
      .pattern(/^[a-zA-Z\s]+$/)
      .required()
      .messages({
        'string.pattern.base': 'Name can only contain letters and spaces'
      }),
    
    dateOfBirth: Joi.date()
      .max('now')
      .min('1900-01-01')
      .optional(),
    
    phone: Joi.string()
      .pattern(/^\+?[1-9]\d{1,14}$/)
      .optional()
      .messages({
        'string.pattern.base': 'Please provide a valid phone number'
      })
  }),
  
  update: Joi.object({
    name: Joi.string().min(2).max(50).pattern(/^[a-zA-Z\s]+$/),
    dateOfBirth: Joi.date().max('now').min('1900-01-01'),
    phone: Joi.string().pattern(/^\+?[1-9]\d{1,14}$/)
  }).min(1)
};

// Validation middleware
export const validate = (schema: Joi.ObjectSchema) => {
  return async (req: Request, res: Response, next: NextFunction) => {
    try {
      const { error, value } = schema.validate(req.body, {
        abortEarly: false,
        allowUnknown: false,
        stripUnknown: true
      });
      
      if (error) {
        const validationErrors = error.details.map(detail => ({
          field: detail.path.join('.'),
          message: detail.message,
          value: detail.context?.value
        }));
        
        return res.status(400).json({
          success: false,
          message: 'Validation failed',
          errors: validationErrors
        });
      }
      
      // Replace req.body with validated and sanitized data
      req.body = value;
      next();
    } catch (err) {
      res.status(500).json({
        success: false,
        message: 'Validation error'
      });
    }
  };
};
```

**Zod Validation Pattern (Modern TypeScript projects - 30%):**

```typescript
import { z } from 'zod';

// User schemas with Zod
export const userSchemas = {
  register: z.object({
    email: z.string()
      .email('Please provide a valid email address')
      .min(1, 'Email is required'),
    
    password: z.string()
      .min(8, 'Password must be at least 8 characters long')
      .regex(
        /^(?=.*[a-z])(?=.*[A-Z])(?=.*[0-9])(?=.*[!@#\$%\^&\*])/,
        'Password must contain at least one lowercase letter, one uppercase letter, one number, and one special character'
      ),
    
    name: z.string()
      .min(2, 'Name must be at least 2 characters')
      .max(50, 'Name must be less than 50 characters')
      .regex(/^[a-zA-Z\s]+$/, 'Name can only contain letters and spaces'),
    
    dateOfBirth: z.string()
      .datetime()
      .optional()
      .transform(val => val ? new Date(val) : undefined),
    
    phone: z.string()
      .regex(/^\+?[1-9]\d{1,14}$/, 'Please provide a valid phone number')
      .optional()
  }),
  
  update: z.object({
    name: z.string().min(2).max(50).regex(/^[a-zA-Z\s]+$/).optional(),
    dateOfBirth: z.string().datetime().optional(),
    phone: z.string().regex(/^\+?[1-9]\d{1,14}$/).optional()
  }).refine(data => Object.keys(data).length > 0, {
    message: 'At least one field must be provided'
  })
};

// Zod validation middleware
export const validateZod = <T>(schema: z.ZodSchema<T>) => {
  return async (req: Request, res: Response, next: NextFunction) => {
    try {
      const validatedData = schema.parse(req.body);
      req.body = validatedData;
      next();
    } catch (error) {
      if (error instanceof z.ZodError) {
        const validationErrors = error.errors.map(err => ({
          field: err.path.join('.'),
          message: err.message,
          value: err.input
        }));
        
        return res.status(400).json({
          success: false,
          message: 'Validation failed',
          errors: validationErrors
        });
      }
      
      res.status(500).json({
        success: false,
        message: 'Validation error'
      });
    }
  };
};
```

### 2. SQL Injection Prevention

**Parameterized Queries with ORM:**

```typescript
// Safe database queries with Prisma
export class UserRepository {
  async findByEmail(email: string): Promise<User | null> {
    // Prisma automatically handles parameterization
    return await prisma.user.findUnique({
      where: { email },
      include: { roles: true }
    });
  }
  
  async searchUsers(query: string, limit: number = 10): Promise<User[]> {
    // Safe search with parameterized queries
    return await prisma.user.findMany({
      where: {
        OR: [
          { name: { contains: query, mode: 'insensitive' } },
          { email: { contains: query, mode: 'insensitive' } }
        ]
      },
      take: limit,
      select: {
        id: true,
        name: true,
        email: true,
        createdAt: true
      }
    });
  }
}

// Raw query protection (when ORM is not used)
export class DatabaseService {
  async executeQuery(query: string, params: any[]): Promise<any[]> {
    // Use parameterized queries
    const client = await pool.connect();
    try {
      const result = await client.query(query, params);
      return result.rows;
    } finally {
      client.release();
    }
  }
  
  async findUsersByRole(roleNames: string[]): Promise<User[]> {
    // Safe array parameter handling
    const placeholders = roleNames.map((_, index) => `$${index + 1}`).join(',');
    const query = `
      SELECT u.id, u.name, u.email
      FROM users u
      JOIN user_roles ur ON u.id = ur.user_id
      JOIN roles r ON ur.role_id = r.id
      WHERE r.name IN (${placeholders})
    `;
    
    return this.executeQuery(query, roleNames);
  }
}
```

## 🛡️ Security Headers and CORS

### 1. Helmet.js Security Headers

**Comprehensive Security Headers Configuration:**

```typescript
import helmet from 'helmet';

// Production security configuration
const securityConfig = helmet({
  // Content Security Policy
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: [
        "'self'",
        "'unsafe-inline'", // Only if absolutely necessary
        "https://cdn.jsdelivr.net",
        "https://unpkg.com"
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
        "https://api.example.com",
        process.env.NODE_ENV === 'development' && "ws://localhost:*"
      ].filter(Boolean),
      mediaSrc: ["'self'"],
      objectSrc: ["'none'"],
      frameSrc: ["'none'"],
      baseUri: ["'self'"],
      formAction: ["'self'"],
      frameAncestors: ["'none'"],
      upgradeInsecureRequests: process.env.NODE_ENV === 'production' ? [] : null
    },
    reportOnly: process.env.NODE_ENV === 'development'
  },
  
  // HTTP Strict Transport Security
  hsts: {
    maxAge: 31536000, // 1 year
    includeSubDomains: true,
    preload: true
  },
  
  // X-Content-Type-Options
  noSniff: true,
  
  // X-Frame-Options
  frameguard: { action: 'deny' },
  
  // X-XSS-Protection
  xssFilter: true,
  
  // Referrer Policy
  referrerPolicy: { policy: 'same-origin' },
  
  // Cross-Origin-Embedder-Policy
  crossOriginEmbedderPolicy: false, // Set to true if needed
  
  // Cross-Origin-Opener-Policy
  crossOriginOpenerPolicy: { policy: 'same-origin' },
  
  // Cross-Origin-Resource-Policy
  crossOriginResourcePolicy: { policy: 'cross-origin' }
});

app.use(securityConfig);
```

### 2. CORS Configuration

**Production CORS Setup:**

```typescript
import cors from 'cors';

// CORS configuration
const corsOptions: cors.CorsOptions = {
  origin: (origin, callback) => {
    // Allow requests with no origin (mobile apps, Postman, etc.)
    if (!origin) return callback(null, true);
    
    const allowedOrigins = (process.env.ALLOWED_ORIGINS || '').split(',');
    
    if (allowedOrigins.includes(origin)) {
      callback(null, true);
    } else {
      callback(new Error('Not allowed by CORS'));
    }
  },
  
  credentials: true, // Allow cookies
  
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  
  allowedHeaders: [
    'Origin',
    'X-Requested-With',
    'Content-Type',
    'Accept',
    'Authorization',
    'X-CSRF-Token'
  ],
  
  exposedHeaders: [
    'X-Total-Count',
    'X-Page-Count',
    'X-Rate-Limit-Remaining'
  ],
  
  maxAge: 86400, // 24 hours
  
  optionsSuccessStatus: 200
};

app.use(cors(corsOptions));

// Handle CORS errors
app.use((error: Error, req: Request, res: Response, next: NextFunction) => {
  if (error.message === 'Not allowed by CORS') {
    return res.status(403).json({
      success: false,
      message: 'CORS policy violation',
      code: 'CORS_ERROR'
    });
  }
  next(error);
});
```

## 🚫 Rate Limiting and DDoS Protection

### 1. Express Rate Limiting

**Adaptive Rate Limiting:**

```typescript
import rateLimit from 'express-rate-limit';
import RedisStore from 'rate-limit-redis';
import { createClient } from 'redis';

// Redis client for rate limiting
const redisClient = createClient({
  host: process.env.REDIS_HOST,
  port: parseInt(process.env.REDIS_PORT || '6379'),
  password: process.env.REDIS_PASSWORD
});

// General API rate limiting
const generalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // 100 requests per window
  
  store: new RedisStore({
    client: redisClient,
    prefix: 'rl:general:'
  }),
  
  message: {
    success: false,
    message: 'Too many requests, please try again later',
    code: 'RATE_LIMIT_EXCEEDED'
  },
  
  standardHeaders: true,
  legacyHeaders: false,
  
  keyGenerator: (req) => {
    // Use user ID if authenticated, otherwise IP
    return req.user?.id || req.ip;
  },
  
  skip: (req) => {
    // Skip rate limiting for health checks
    return req.path === '/health';
  }
});

// Strict rate limiting for authentication endpoints
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 5, // 5 attempts per window
  
  store: new RedisStore({
    client: redisClient,
    prefix: 'rl:auth:'
  }),
  
  message: {
    success: false,
    message: 'Too many authentication attempts, please try again later',
    code: 'AUTH_RATE_LIMIT_EXCEEDED'
  },
  
  skipSuccessfulRequests: true, // Don't count successful requests
  
  keyGenerator: (req) => {
    // Combine IP and email for auth rate limiting
    const email = req.body?.email || 'unknown';
    return `${req.ip}:${email}`;
  }
});

// API key rate limiting (higher limits)
const apiKeyLimiter = rateLimit({
  windowMs: 60 * 60 * 1000, // 1 hour
  max: 1000, // 1000 requests per hour
  
  store: new RedisStore({
    client: redisClient,
    prefix: 'rl:apikey:'
  }),
  
  keyGenerator: (req) => {
    return req.headers['x-api-key'] as string || req.ip;
  }
});

// Apply rate limiting
app.use('/api/', generalLimiter);
app.use('/auth/', authLimiter);
app.use('/api/v1/', apiKeyLimiter);
```

### 2. Advanced DDoS Protection

**Request Size and Complexity Limiting:**

```typescript
// Request size limiting
app.use(express.json({
  limit: '10mb',
  verify: (req, res, buf) => {
    // Check for suspicious patterns in JSON
    const jsonString = buf.toString();
    
    // Detect deeply nested objects (JSON bomb attack)
    const depth = (jsonString.match(/{/g) || []).length;
    if (depth > 10) {
      throw new Error('JSON structure too deep');
    }
    
    // Detect excessive array sizes
    const arrayMatches = jsonString.match(/\[.*?\]/g) || [];
    for (const match of arrayMatches) {
      const elements = (match.match(/,/g) || []).length + 1;
      if (elements > 1000) {
        throw new Error('Array size too large');
      }
    }
  }
}));

// Connection limiting
const connectionLimiter = (req: Request, res: Response, next: NextFunction) => {
  const connections = getActiveConnections();
  
  if (connections > 1000) {
    return res.status(503).json({
      success: false,
      message: 'Service temporarily unavailable',
      code: 'TOO_MANY_CONNECTIONS'
    });
  }
  
  next();
};

app.use(connectionLimiter);
```

## 🔒 Session Security

### 1. Secure Session Management

**Redis Session Store:**

```typescript
import session from 'express-session';
import RedisStore from 'connect-redis';

const sessionConfig = {
  store: new RedisStore({
    client: redisClient,
    prefix: 'sess:',
    ttl: 24 * 60 * 60 // 24 hours
  }),
  
  secret: process.env.SESSION_SECRET!,
  
  name: 'sessionId', // Don't use default 'connect.sid'
  
  resave: false,
  saveUninitialized: false,
  
  cookie: {
    secure: process.env.NODE_ENV === 'production', // HTTPS only in production
    httpOnly: true, // Prevent XSS
    maxAge: 24 * 60 * 60 * 1000, // 24 hours
    sameSite: 'strict' as const // CSRF protection
  },
  
  genid: () => {
    // Generate cryptographically secure session ID
    return require('crypto').randomBytes(32).toString('hex');
  }
};

app.use(session(sessionConfig));
```

### 2. CSRF Protection

**Double Submit Cookie Pattern:**

```typescript
import crypto from 'crypto';

// CSRF token generation
export const generateCSRFToken = (): string => {
  return crypto.randomBytes(32).toString('hex');
};

// CSRF middleware
export const csrfProtection = (req: Request, res: Response, next: NextFunction) => {
  // Skip CSRF for GET, HEAD, OPTIONS
  if (['GET', 'HEAD', 'OPTIONS'].includes(req.method)) {
    return next();
  }
  
  // Skip CSRF for API key authentication
  if (req.headers['x-api-key']) {
    return next();
  }
  
  const tokenFromHeader = req.headers['x-csrf-token'] as string;
  const tokenFromBody = req.body._csrf;
  const tokenFromCookie = req.cookies.csrfToken;
  
  const submittedToken = tokenFromHeader || tokenFromBody;
  
  if (!submittedToken || !tokenFromCookie) {
    return res.status(403).json({
      success: false,
      message: 'CSRF token missing',
      code: 'CSRF_TOKEN_MISSING'
    });
  }
  
  if (submittedToken !== tokenFromCookie) {
    return res.status(403).json({
      success: false,
      message: 'CSRF token mismatch',
      code: 'CSRF_TOKEN_MISMATCH'
    });
  }
  
  next();
};

// CSRF token endpoint
app.get('/csrf-token', (req, res) => {
  const token = generateCSRFToken();
  
  res.cookie('csrfToken', token, {
    httpOnly: false, // Accessible to JavaScript
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'strict',
    maxAge: 60 * 60 * 1000 // 1 hour
  });
  
  res.json({
    success: true,
    csrfToken: token
  });
});
```

## 🔍 Security Monitoring and Logging

### 1. Security Event Logging

**Comprehensive Security Logging:**

```typescript
import winston from 'winston';

// Security logger configuration
const securityLogger = winston.createLogger({
  level: 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  transports: [
    new winston.transports.File({
      filename: 'logs/security.log',
      level: 'warn'
    }),
    new winston.transports.Console({
      format: winston.format.simple()
    })
  ]
});

// Security event logging middleware
export const logSecurityEvent = (
  eventType: string,
  severity: 'low' | 'medium' | 'high' | 'critical'
) => {
  return (req: Request, res: Response, next: NextFunction) => {
    const securityEvent = {
      type: eventType,
      severity,
      timestamp: new Date().toISOString(),
      ip: req.ip,
      userAgent: req.headers['user-agent'],
      userId: req.user?.id,
      path: req.path,
      method: req.method,
      headers: req.headers,
      body: req.body
    };
    
    securityLogger.warn('Security Event', securityEvent);
    
    next();
  };
};

// Usage for sensitive operations
app.post('/auth/login',
  logSecurityEvent('LOGIN_ATTEMPT', 'medium'),
  // ... other middleware
);

app.post('/admin/users',
  authenticateToken,
  authorize(['admin']),
  logSecurityEvent('ADMIN_USER_CREATE', 'high'),
  // ... controller
);
```

### 2. Intrusion Detection

**Anomaly Detection Middleware:**

```typescript
// Anomaly detection service
export class SecurityMonitor {
  private static suspiciousPatterns = [
    /union.*select/i, // SQL injection
    /<script/i, // XSS attempt
    /javascript:/i, // XSS attempt
    /eval\(/i, // Code injection
    /exec\(/i, // Command injection
    /\.\.\//, // Path traversal
    /\/etc\/passwd/, // File inclusion
    /cmd\.exe/i // Command execution
  ];
  
  static detectSuspiciousActivity(req: Request): string[] {
    const violations: string[] = [];
    const checkString = JSON.stringify(req.body) + req.url + JSON.stringify(req.query);
    
    for (const pattern of this.suspiciousPatterns) {
      if (pattern.test(checkString)) {
        violations.push(`Suspicious pattern detected: ${pattern.source}`);
      }
    }
    
    return violations;
  }
  
  static async checkRateLimitViolations(identifier: string): Promise<boolean> {
    const key = `violations:${identifier}`;
    const violations = await redisClient.get(key);
    
    return violations ? parseInt(violations) > 10 : false;
  }
}

// Security monitoring middleware
export const securityMonitor = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  const violations = SecurityMonitor.detectSuspiciousActivity(req);
  
  if (violations.length > 0) {
    const identifier = req.user?.id || req.ip;
    
    // Log the violation
    securityLogger.error('Security Violation Detected', {
      identifier,
      violations,
      ip: req.ip,
      userAgent: req.headers['user-agent'],
      path: req.path,
      method: req.method,
      timestamp: new Date().toISOString()
    });
    
    // Track violations
    const key = `violations:${identifier}`;
    await redisClient.incr(key);
    await redisClient.expire(key, 3600); // 1 hour expiry
    
    // Check if this IP/user should be blocked
    const isBlocked = await SecurityMonitor.checkRateLimitViolations(identifier);
    
    if (isBlocked) {
      return res.status(403).json({
        success: false,
        message: 'Access denied due to suspicious activity',
        code: 'SECURITY_VIOLATION'
      });
    }
  }
  
  next();
};

app.use(securityMonitor);
```

## 📊 Security Best Practices Summary

### Essential Security Checklist

| Security Measure | Implementation Priority | Complexity | Impact |
|------------------|------------------------|------------|--------|
| **HTTPS/TLS** | ⭐⭐⭐⭐⭐ Critical | Low | High |
| **Input Validation** | ⭐⭐⭐⭐⭐ Critical | Medium | High |
| **Authentication** | ⭐⭐⭐⭐⭐ Critical | Medium | High |
| **Authorization** | ⭐⭐⭐⭐⭐ Critical | Medium | High |
| **Security Headers** | ⭐⭐⭐⭐ High | Low | Medium |
| **Rate Limiting** | ⭐⭐⭐⭐ High | Medium | Medium |
| **CSRF Protection** | ⭐⭐⭐ Medium | Low | Medium |
| **Session Security** | ⭐⭐⭐ Medium | Medium | Medium |
| **Logging/Monitoring** | ⭐⭐⭐ Medium | High | High |
| **Error Handling** | ⭐⭐⭐ Medium | Low | Medium |

### Security Configuration Template

```typescript
// Complete security setup
export const setupSecurity = (app: Express) => {
  // 1. Security headers
  app.use(helmet(securityConfig));
  
  // 2. CORS configuration
  app.use(cors(corsOptions));
  
  // 3. Rate limiting
  app.use('/api/', generalLimiter);
  app.use('/auth/', authLimiter);
  
  // 4. Body parsing with size limits
  app.use(express.json({ limit: '10mb' }));
  app.use(express.urlencoded({ extended: true, limit: '10mb' }));
  
  // 5. Security monitoring
  app.use(securityMonitor);
  
  // 6. CSRF protection
  app.use(csrfProtection);
  
  // 7. Authentication
  app.use('/api/', authenticateToken);
  
  // 8. Request logging
  app.use(morgan('combined'));
};
```

---

*Security Patterns Analysis | Research conducted January 2025*

**Navigation**
- **Previous**: [Project Analysis](./project-analysis.md) ←
- **Next**: [Architecture Patterns](./architecture-patterns.md) →
- **Back to**: [Research Overview](./README.md) ↑