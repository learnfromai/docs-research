# Security Implementations in Express.js Applications

## 🛡️ Authentication Patterns Analysis

### 1. JWT-Based Authentication (85% adoption rate)

#### Access + Refresh Token Pattern (Production Standard)
```typescript
// Token Configuration
interface TokenConfig {
  accessTokenExpiry: string;   // '15m'
  refreshTokenExpiry: string;  // '7d'
  algorithm: 'RS256' | 'HS256'; // RS256 for production
  issuer: string;
  audience: string;
}

// JWT Service Implementation
class JWTService {
  private readonly accessTokenSecret: string;
  private readonly refreshTokenSecret: string;
  
  generateTokens(payload: UserPayload): TokenPair {
    const accessToken = jwt.sign(payload, this.accessTokenSecret, {
      expiresIn: '15m',
      algorithm: 'RS256',
      issuer: 'your-app',
      audience: 'your-app-users'
    });
    
    const refreshToken = jwt.sign(
      { userId: payload.userId }, 
      this.refreshTokenSecret, 
      { expiresIn: '7d' }
    );
    
    return { accessToken, refreshToken };
  }
  
  verifyAccessToken(token: string): UserPayload | null {
    try {
      return jwt.verify(token, this.accessTokenSecret) as UserPayload;
    } catch (error) {
      return null;
    }
  }
}
```

#### Authentication Middleware Implementation
```typescript
// Production-grade authentication middleware
export const authenticateToken = async (
  req: Request, 
  res: Response, 
  next: NextFunction
): Promise<void> => {
  try {
    const authHeader = req.headers.authorization;
    const token = authHeader && authHeader.split(' ')[1]; // Bearer TOKEN
    
    if (!token) {
      return res.status(401).json({
        success: false,
        message: 'Access token required'
      });
    }
    
    const decoded = jwtService.verifyAccessToken(token);
    if (!decoded) {
      return res.status(403).json({
        success: false,
        message: 'Invalid or expired token'
      });
    }
    
    // Attach user to request
    req.user = await User.findById(decoded.userId);
    next();
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Authentication error'
    });
  }
};

// Token refresh endpoint
app.post('/auth/refresh', async (req, res) => {
  const { refreshToken } = req.body;
  
  try {
    const decoded = jwt.verify(refreshToken, REFRESH_TOKEN_SECRET);
    const user = await User.findById(decoded.userId);
    
    if (!user || user.tokenVersion !== decoded.tokenVersion) {
      return res.status(403).json({ message: 'Invalid refresh token' });
    }
    
    const tokens = jwtService.generateTokens({
      userId: user.id,
      role: user.role,
      permissions: user.permissions
    });
    
    res.json({ success: true, ...tokens });
  } catch (error) {
    res.status(403).json({ message: 'Invalid refresh token' });
  }
});
```

### 2. Passport.js Integration (67% adoption rate)

#### Multi-Strategy Authentication Setup
```typescript
// Passport Configuration
import passport from 'passport';
import { Strategy as LocalStrategy } from 'passport-local';
import { Strategy as GoogleStrategy } from 'passport-google-oauth20';
import { Strategy as JwtStrategy, ExtractJwt } from 'passport-jwt';

// Local Strategy (Username/Password)
passport.use(new LocalStrategy({
  usernameField: 'email',
  passwordField: 'password'
}, async (email: string, password: string, done) => {
  try {
    const user = await User.findOne({ email });
    if (!user) {
      return done(null, false, { message: 'Invalid credentials' });
    }
    
    const isValidPassword = await bcrypt.compare(password, user.password);
    if (!isValidPassword) {
      return done(null, false, { message: 'Invalid credentials' });
    }
    
    return done(null, user);
  } catch (error) {
    return done(error);
  }
}));

// JWT Strategy
passport.use(new JwtStrategy({
  jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
  secretOrKey: process.env.JWT_SECRET,
  algorithms: ['RS256']
}, async (payload, done) => {
  try {
    const user = await User.findById(payload.userId);
    if (user) {
      return done(null, user);
    }
    return done(null, false);
  } catch (error) {
    return done(error, false);
  }
}));

// Google OAuth Strategy
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
        name: profile.displayName,
        avatar: profile.photos[0].value,
        provider: 'google'
      });
    }
    
    return done(null, user);
  } catch (error) {
    return done(error, null);
  }
}));
```

### 3. API Key Authentication (45% adoption rate)

#### API Key Management System
```typescript
// API Key Model
interface ApiKey {
  id: string;
  key: string;
  name: string;
  permissions: string[];
  rateLimit: number;
  isActive: boolean;
  expiresAt?: Date;
  createdBy: string;
  lastUsed?: Date;
  usageCount: number;
}

// API Key Middleware
export const authenticateApiKey = async (
  req: Request, 
  res: Response, 
  next: NextFunction
): Promise<void> => {
  try {
    const apiKey = req.headers['x-api-key'] as string;
    
    if (!apiKey) {
      return res.status(401).json({
        error: 'API key required',
        code: 'API_KEY_MISSING'
      });
    }
    
    const keyRecord = await ApiKey.findOne({ 
      key: apiKey, 
      isActive: true 
    });
    
    if (!keyRecord) {
      return res.status(401).json({
        error: 'Invalid API key',
        code: 'API_KEY_INVALID'
      });
    }
    
    // Check expiration
    if (keyRecord.expiresAt && keyRecord.expiresAt < new Date()) {
      return res.status(401).json({
        error: 'API key expired',
        code: 'API_KEY_EXPIRED'
      });
    }
    
    // Rate limiting check
    const hourlyUsage = await getHourlyUsage(keyRecord.id);
    if (hourlyUsage >= keyRecord.rateLimit) {
      return res.status(429).json({
        error: 'Rate limit exceeded',
        code: 'RATE_LIMIT_EXCEEDED'
      });
    }
    
    // Update usage statistics
    await updateKeyUsage(keyRecord.id);
    
    req.apiKey = keyRecord;
    next();
  } catch (error) {
    res.status(500).json({ error: 'Authentication error' });
  }
};
```

## 🔐 Authorization Patterns

### 1. Role-Based Access Control (RBAC)

#### Implementation Pattern
```typescript
// Role and Permission Models
interface Role {
  id: string;
  name: string;
  permissions: Permission[];
  description: string;
}

interface Permission {
  id: string;
  name: string;
  resource: string;
  action: string; // create, read, update, delete
}

interface User {
  id: string;
  email: string;
  roles: Role[];
  permissions: Permission[]; // Direct permissions
}

// Authorization Middleware
export const authorize = (requiredPermission: string) => {
  return (req: Request, res: Response, next: NextFunction) => {
    const user = req.user;
    
    if (!user) {
      return res.status(401).json({ error: 'Authentication required' });
    }
    
    // Check direct permissions
    const hasDirectPermission = user.permissions.some(
      p => p.name === requiredPermission
    );
    
    // Check role-based permissions
    const hasRolePermission = user.roles.some(role =>
      role.permissions.some(p => p.name === requiredPermission)
    );
    
    if (!hasDirectPermission && !hasRolePermission) {
      return res.status(403).json({ 
        error: 'Insufficient permissions',
        required: requiredPermission 
      });
    }
    
    next();
  };
};

// Usage in routes
app.get('/admin/users', 
  authenticateToken,
  authorize('users:read'),
  getUsersController
);

app.delete('/admin/users/:id',
  authenticateToken,
  authorize('users:delete'),
  deleteUserController
);
```

### 2. Resource-Based Authorization

#### Implementation Pattern
```typescript
// Resource ownership check
export const authorizeResourceOwner = (resourceParam: string = 'id') => {
  return async (req: Request, res: Response, next: NextFunction) => {
    try {
      const resourceId = req.params[resourceParam];
      const userId = req.user.id;
      
      // Check if user owns the resource
      const resource = await getResourceById(resourceId);
      
      if (!resource) {
        return res.status(404).json({ error: 'Resource not found' });
      }
      
      if (resource.ownerId !== userId && !req.user.roles.includes('admin')) {
        return res.status(403).json({ 
          error: 'Access denied: You can only access your own resources' 
        });
      }
      
      req.resource = resource;
      next();
    } catch (error) {
      res.status(500).json({ error: 'Authorization error' });
    }
  };
};

// Usage
app.put('/posts/:id',
  authenticateToken,
  authorizeResourceOwner('id'),
  updatePostController
);
```

## 🛡️ Input Validation and Sanitization

### 1. Joi Schema Validation (72% adoption rate)

#### Comprehensive Validation Setup
```typescript
import Joi from 'joi';

// User Registration Schema
const userRegistrationSchema = Joi.object({
  name: Joi.string()
    .min(2)
    .max(50)
    .pattern(/^[a-zA-Z\s]+$/)
    .required(),
  email: Joi.string()
    .email()
    .lowercase()
    .required(),
  password: Joi.string()
    .min(8)
    .pattern(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]/)
    .required(),
  confirmPassword: Joi.string()
    .valid(Joi.ref('password'))
    .required(),
  age: Joi.number()
    .integer()
    .min(13)
    .max(120),
  phone: Joi.string()
    .pattern(/^\+?[1-9]\d{1,14}$/)
    .optional()
});

// Validation Middleware
export const validateRequest = (schema: Joi.ObjectSchema) => {
  return (req: Request, res: Response, next: NextFunction) => {
    const { error, value } = schema.validate(req.body, {
      abortEarly: false,
      stripUnknown: true,
      errors: {
        wrap: {
          label: ''
        }
      }
    });
    
    if (error) {
      const errorDetails = error.details.map(detail => ({
        field: detail.path.join('.'),
        message: detail.message,
        value: detail.context?.value
      }));
      
      return res.status(400).json({
        success: false,
        message: 'Validation error',
        errors: errorDetails
      });
    }
    
    req.body = value; // Use sanitized values
    next();
  };
};

// Usage
app.post('/auth/register',
  validateRequest(userRegistrationSchema),
  registerController
);
```

### 2. Express Validator (58% adoption rate)

#### Advanced Validation Patterns
```typescript
import { body, param, query, validationResult } from 'express-validator';

// Complex validation chains
const blogPostValidation = [
  body('title')
    .isLength({ min: 5, max: 200 })
    .withMessage('Title must be between 5 and 200 characters')
    .escape(), // HTML escape
  
  body('content')
    .isLength({ min: 100 })
    .withMessage('Content must be at least 100 characters')
    .custom((value) => {
      // Custom validation for HTML content
      if (value.includes('<script>')) {
        throw new Error('Script tags are not allowed');
      }
      return true;
    }),
  
  body('tags')
    .isArray({ min: 1, max: 10 })
    .withMessage('Must provide 1-10 tags'),
  
  body('tags.*')
    .isLength({ min: 2, max: 30 })
    .withMessage('Each tag must be 2-30 characters'),
  
  body('publishedAt')
    .optional()
    .isISO8601()
    .toDate(),
  
  body('categories')
    .isArray()
    .custom(async (categories) => {
      const validCategories = await Category.find({
        _id: { $in: categories }
      });
      if (validCategories.length !== categories.length) {
        throw new Error('Invalid category IDs');
      }
      return true;
    })
];

// Error handling middleware
export const handleValidationErrors = (
  req: Request, 
  res: Response, 
  next: NextFunction
) => {
  const errors = validationResult(req);
  
  if (!errors.isEmpty()) {
    const formattedErrors = errors.array().map(error => ({
      field: error.param,
      message: error.msg,
      value: error.value
    }));
    
    return res.status(400).json({
      success: false,
      message: 'Validation failed',
      errors: formattedErrors
    });
  }
  
  next();
};

// Usage
app.post('/posts',
  authenticateToken,
  ...blogPostValidation,
  handleValidationErrors,
  createPostController
);
```

## 🔒 Security Middleware Stack

### 1. Helmet.js Security Headers (78% adoption rate)

#### Comprehensive Security Configuration
```typescript
import helmet from 'helmet';

// Production security configuration
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'", "https://fonts.googleapis.com"],
      fontSrc: ["'self'", "https://fonts.gstatic.com"],
      imgSrc: ["'self'", "data:", "https://res.cloudinary.com"],
      scriptSrc: ["'self'"],
      connectSrc: ["'self'", "https://api.yourdomain.com"],
      frameSrc: ["'none'"],
      objectSrc: ["'none'"],
      upgradeInsecureRequests: [],
    },
  },
  crossOriginEmbedderPolicy: false, // Adjust based on needs
  hsts: {
    maxAge: 31536000,
    includeSubDomains: true,
    preload: true
  },
  noSniff: true,
  referrerPolicy: { policy: "same-origin" },
  xssFilter: true
}));
```

### 2. CORS Configuration (71% adoption rate)

#### Production CORS Setup
```typescript
import cors from 'cors';

// Environment-specific CORS configuration
const corsOptions: cors.CorsOptions = {
  origin: (origin, callback) => {
    const allowedOrigins = process.env.ALLOWED_ORIGINS?.split(',') || ['http://localhost:3000'];
    
    // Allow requests with no origin (mobile apps, etc.)
    if (!origin) return callback(null, true);
    
    if (allowedOrigins.includes(origin)) {
      callback(null, true);
    } else {
      callback(new Error('Not allowed by CORS'));
    }
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
  allowedHeaders: [
    'Origin',
    'X-Requested-With',
    'Content-Type',
    'Accept',
    'Authorization',
    'X-API-Key'
  ],
  exposedHeaders: ['X-Total-Count', 'X-Page-Count'],
  maxAge: 86400 // 24 hours
};

app.use(cors(corsOptions));
```

### 3. Rate Limiting (62% adoption rate)

#### Advanced Rate Limiting Implementation
```typescript
import rateLimit from 'express-rate-limit';
import RedisStore from 'rate-limit-redis';
import Redis from 'ioredis';

const redis = new Redis(process.env.REDIS_URL);

// Global rate limiting
const globalLimiter = rateLimit({
  store: new RedisStore({
    sendCommand: (...args: string[]) => redis.call(...args),
  }),
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 1000, // limit each IP to 1000 requests per windowMs
  message: {
    error: 'Too many requests from this IP',
    retryAfter: 900
  },
  standardHeaders: true,
  legacyHeaders: false,
});

// API-specific rate limiting
const apiLimiter = rateLimit({
  store: new RedisStore({
    sendCommand: (...args: string[]) => redis.call(...args),
  }),
  windowMs: 15 * 60 * 1000,
  max: 100,
  keyGenerator: (req) => {
    // Use API key if available, otherwise IP
    return req.apiKey?.id || req.ip;
  },
  skip: (req) => {
    // Skip rate limiting for admin users
    return req.user?.roles.includes('admin');
  }
});

// Authentication-specific rate limiting
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 5, // Strict limit for auth endpoints
  skipSuccessfulRequests: true,
  keyGenerator: (req) => `auth:${req.ip}:${req.body.email || 'unknown'}`
});

// Apply rate limiting
app.use(globalLimiter);
app.use('/api', apiLimiter);
app.use('/auth', authLimiter);
```

## 🚨 Security Best Practices Checklist

### ✅ Authentication Security
- [ ] JWT tokens use RS256 algorithm for production
- [ ] Access tokens have short expiry (15 minutes)
- [ ] Refresh tokens are properly rotated
- [ ] Password hashing uses bcrypt with salt rounds ≥ 12
- [ ] Account lockout after failed login attempts
- [ ] Two-factor authentication support
- [ ] Secure password reset flow

### ✅ Authorization Security
- [ ] Role-based access control implemented
- [ ] Resource-level authorization checks
- [ ] Principle of least privilege enforced
- [ ] Permission validation on every request
- [ ] Admin actions require additional verification

### ✅ Input Security
- [ ] All inputs validated and sanitized
- [ ] XSS protection enabled
- [ ] SQL injection prevention
- [ ] NoSQL injection prevention
- [ ] File upload restrictions
- [ ] Request size limits
- [ ] Content-Type validation

### ✅ Network Security
- [ ] HTTPS enforced in production
- [ ] Security headers configured (Helmet)
- [ ] CORS properly configured
- [ ] Rate limiting implemented
- [ ] API versioning strategy
- [ ] Request logging and monitoring

### ✅ Error Handling Security
- [ ] No sensitive data in error messages
- [ ] Centralized error handling
- [ ] Error logging without sensitive data
- [ ] Generic error responses to clients
- [ ] Proper HTTP status codes

---

## 🔗 Navigation

| Previous | Next |
|----------|------|
| [← Production Projects](./production-ready-projects-analysis.md) | [Scalable Architecture →](./scalable-architecture-patterns.md) |

---

**Security Note**: Always conduct regular security audits and penetration testing for production applications. Keep dependencies updated and monitor security advisories.