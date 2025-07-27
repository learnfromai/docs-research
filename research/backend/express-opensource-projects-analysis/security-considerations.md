# Security Considerations: Express.js Applications

## 🛡️ Overview

This document provides comprehensive security guidance based on analysis of production Express.js applications. Security patterns are organized by threat category with implementation examples from real-world projects.

## 🔐 Authentication Security

### 1. **JWT Token Security**

#### Secure JWT Implementation
```javascript
// ✅ Production-grade JWT configuration
const jwt = require('jsonwebtoken');
const crypto = require('crypto');

class TokenService {
  constructor() {
    this.accessTokenSecret = process.env.JWT_ACCESS_SECRET;
    this.refreshTokenSecret = process.env.JWT_REFRESH_SECRET;
    this.accessTokenExpiry = '15m';
    this.refreshTokenExpiry = '7d';
  }

  generateTokenPair(payload) {
    const accessToken = jwt.sign(payload, this.accessTokenSecret, {
      expiresIn: this.accessTokenExpiry,
      audience: 'myapp-users',
      issuer: 'myapp-server',
      algorithm: 'HS256'
    });

    const refreshToken = jwt.sign(
      { ...payload, tokenType: 'refresh' },
      this.refreshTokenSecret,
      {
        expiresIn: this.refreshTokenExpiry,
        audience: 'myapp-users',
        issuer: 'myapp-server',
        algorithm: 'HS256'
      }
    );

    return { accessToken, refreshToken };
  }

  verifyAccessToken(token) {
    try {
      return jwt.verify(token, this.accessTokenSecret, {
        audience: 'myapp-users',
        issuer: 'myapp-server',
        algorithms: ['HS256']
      });
    } catch (error) {
      throw new Error(`Invalid access token: ${error.message}`);
    }
  }

  verifyRefreshToken(token) {
    try {
      const decoded = jwt.verify(token, this.refreshTokenSecret, {
        audience: 'myapp-users',
        issuer: 'myapp-server',
        algorithms: ['HS256']
      });

      if (decoded.tokenType !== 'refresh') {
        throw new Error('Invalid token type');
      }

      return decoded;
    } catch (error) {
      throw new Error(`Invalid refresh token: ${error.message}`);
    }
  }
}
```

#### Token Storage Security
```javascript
// ✅ Secure cookie configuration for refresh tokens
const cookieOptions = {
  httpOnly: true, // Prevent XSS attacks
  secure: process.env.NODE_ENV === 'production', // HTTPS only in production
  sameSite: 'strict', // CSRF protection
  maxAge: 7 * 24 * 60 * 60 * 1000, // 7 days
  path: '/api/auth' // Limit cookie scope
};

// Login endpoint
app.post('/api/auth/login', async (req, res) => {
  const { accessToken, refreshToken } = tokenService.generateTokenPair(userPayload);
  
  // Send access token in response body
  // Store refresh token in httpOnly cookie
  res.cookie('refreshToken', refreshToken, cookieOptions);
  
  res.json({
    success: true,
    data: {
      user: sanitizedUser,
      accessToken,
      expiresIn: 900 // 15 minutes in seconds
    }
  });
});

// Token refresh endpoint
app.post('/api/auth/refresh', (req, res) => {
  const refreshToken = req.cookies.refreshToken;
  
  if (!refreshToken) {
    return res.status(401).json({ error: 'Refresh token required' });
  }

  try {
    const decoded = tokenService.verifyRefreshToken(refreshToken);
    const newTokenPair = tokenService.generateTokenPair({
      id: decoded.id,
      email: decoded.email,
      role: decoded.role
    });

    res.cookie('refreshToken', newTokenPair.refreshToken, cookieOptions);
    res.json({
      success: true,
      data: {
        accessToken: newTokenPair.accessToken,
        expiresIn: 900
      }
    });
  } catch (error) {
    res.clearCookie('refreshToken');
    res.status(401).json({ error: 'Invalid refresh token' });
  }
});
```

### 2. **Multi-Factor Authentication (MFA)**

#### TOTP Implementation
```javascript
// ✅ Time-based One-Time Password implementation
const speakeasy = require('speakeasy');
const qrcode = require('qrcode');

class MFAService {
  generateSecret(userEmail) {
    const secret = speakeasy.generateSecret({
      name: userEmail,
      issuer: 'MyApp',
      length: 32
    });

    return {
      secret: secret.base32,
      qrCode: secret.otpauth_url
    };
  }

  async generateQRCode(otpauthUrl) {
    try {
      return await qrcode.toDataURL(otpauthUrl);
    } catch (error) {
      throw new Error('Failed to generate QR code');
    }
  }

  verifyToken(token, secret) {
    return speakeasy.totp.verify({
      secret,
      encoding: 'base32',
      token,
      window: 2 // Allow 2 time steps of variance
    });
  }
}

// MFA setup endpoint
app.post('/api/auth/mfa/setup', authenticateToken, async (req, res) => {
  try {
    const { secret, qrCode } = mfaService.generateSecret(req.user.email);
    const qrCodeDataUrl = await mfaService.generateQRCode(qrCode);

    // Store secret temporarily (not activated yet)
    await User.findByIdAndUpdate(req.user.id, {
      mfaSecret: secret,
      mfaEnabled: false
    });

    res.json({
      success: true,
      data: {
        secret,
        qrCode: qrCodeDataUrl
      }
    });
  } catch (error) {
    res.status(500).json({ error: 'MFA setup failed' });
  }
});

// MFA verification endpoint
app.post('/api/auth/mfa/verify', authenticateToken, async (req, res) => {
  try {
    const { token } = req.body;
    const user = await User.findById(req.user.id);

    if (!user.mfaSecret) {
      return res.status(400).json({ error: 'MFA not set up' });
    }

    const isValid = mfaService.verifyToken(token, user.mfaSecret);

    if (!isValid) {
      return res.status(400).json({ error: 'Invalid MFA token' });
    }

    // Activate MFA
    await User.findByIdAndUpdate(req.user.id, { mfaEnabled: true });

    res.json({
      success: true,
      message: 'MFA activated successfully'
    });
  } catch (error) {
    res.status(500).json({ error: 'MFA verification failed' });
  }
});
```

### 3. **OAuth 2.0 Integration**

#### Secure OAuth Implementation
```javascript
// ✅ OAuth 2.0 with Passport.js
const passport = require('passport');
const GoogleStrategy = require('passport-google-oauth20').Strategy;

class OAuthService {
  constructor() {
    this.setupGoogleStrategy();
  }

  setupGoogleStrategy() {
    passport.use(new GoogleStrategy({
      clientID: process.env.GOOGLE_CLIENT_ID,
      clientSecret: process.env.GOOGLE_CLIENT_SECRET,
      callbackURL: "/api/auth/google/callback",
      scope: ['profile', 'email']
    }, async (accessToken, refreshToken, profile, done) => {
      try {
        // Check if user exists
        let user = await User.findOne({ googleId: profile.id });

        if (user) {
          return done(null, user);
        }

        // Check if email already exists
        user = await User.findOne({ email: profile.emails[0].value });

        if (user) {
          // Link Google account to existing user
          user.googleId = profile.id;
          await user.save();
          return done(null, user);
        }

        // Create new user
        user = await User.create({
          googleId: profile.id,
          name: profile.displayName,
          email: profile.emails[0].value,
          avatar: profile.photos[0].value,
          emailVerified: true, // Google emails are verified
          provider: 'google'
        });

        done(null, user);
      } catch (error) {
        done(error, null);
      }
    }));
  }
}

// OAuth routes
app.get('/api/auth/google', 
  passport.authenticate('google', { scope: ['profile', 'email'] })
);

app.get('/api/auth/google/callback',
  passport.authenticate('google', { session: false }),
  (req, res) => {
    const { accessToken, refreshToken } = tokenService.generateTokenPair({
      id: req.user.id,
      email: req.user.email,
      role: req.user.role
    });

    res.cookie('refreshToken', refreshToken, cookieOptions);

    // Redirect to frontend with access token
    res.redirect(`${process.env.FRONTEND_URL}/auth/callback?token=${accessToken}`);
  }
);
```

## 🛡️ Input Security

### 1. **Comprehensive Input Validation**

#### Schema-Based Validation
```javascript
// ✅ Advanced validation schemas
const Joi = require('joi');

const validationSchemas = {
  // User registration
  register: Joi.object({
    name: Joi.string()
      .trim()
      .min(2)
      .max(50)
      .pattern(/^[a-zA-Z\s]+$/)
      .required(),
    
    email: Joi.string()
      .email({ tlds: { allow: false } })
      .lowercase()
      .required(),
    
    password: Joi.string()
      .min(8)
      .max(128)
      .pattern(new RegExp('^(?=.*[a-z])(?=.*[A-Z])(?=.*[0-9])(?=.*[!@#\\$%\\^&\\*])'))
      .required()
      .messages({
        'string.pattern.base': 'Password must contain uppercase, lowercase, number, and special character'
      }),
    
    confirmPassword: Joi.string()
      .valid(Joi.ref('password'))
      .required()
      .messages({
        'any.only': 'Passwords must match'
      }),
    
    age: Joi.number()
      .integer()
      .min(13)
      .max(120)
      .optional(),
    
    phoneNumber: Joi.string()
      .pattern(/^\+?[1-9]\d{1,14}$/)
      .optional()
  }),

  // Post creation
  createPost: Joi.object({
    title: Joi.string()
      .trim()
      .min(5)
      .max(200)
      .required(),
    
    content: Joi.string()
      .trim()
      .min(10)
      .max(10000)
      .required(),
    
    tags: Joi.array()
      .items(Joi.string().trim().min(2).max(30))
      .max(10)
      .optional(),
    
    category: Joi.string()
      .valid('tech', 'business', 'lifestyle', 'education')
      .required(),
    
    publishedAt: Joi.date()
      .min('now')
      .optional()
  }),

  // Search parameters
  search: Joi.object({
    query: Joi.string()
      .trim()
      .min(2)
      .max(100)
      .pattern(/^[a-zA-Z0-9\s\-_]+$/)
      .required(),
    
    page: Joi.number()
      .integer()
      .min(1)
      .max(1000)
      .default(1),
    
    limit: Joi.number()
      .integer()
      .min(1)
      .max(100)
      .default(20),
    
    sortBy: Joi.string()
      .valid('createdAt', 'updatedAt', 'title', 'popularity')
      .default('createdAt'),
    
    sortOrder: Joi.string()
      .valid('asc', 'desc')
      .default('desc')
  })
};
```

#### Advanced Sanitization
```javascript
// ✅ Multi-layer input sanitization
const validator = require('validator');
const DOMPurify = require('isomorphic-dompurify');

class InputSanitizer {
  static sanitizeString(input) {
    if (typeof input !== 'string') return input;
    
    return validator.escape(
      validator.stripLow(input.trim(), true)
    );
  }

  static sanitizeEmail(email) {
    if (!email) return null;
    
    const normalized = validator.normalizeEmail(email, {
      gmail_lowercase: true,
      gmail_remove_dots: false,
      gmail_remove_subaddress: false,
      outlookdotcom_lowercase: true,
      yahoo_lowercase: true,
      icloud_lowercase: true
    });

    return normalized;
  }

  static sanitizeHtml(html, allowedTags = []) {
    if (!html) return '';
    
    const config = {
      ALLOWED_TAGS: allowedTags.length > 0 ? allowedTags : ['b', 'i', 'em', 'strong', 'p', 'br'],
      ALLOWED_ATTR: ['href', 'target'],
      ALLOW_DATA_ATTR: false,
      FORBID_SCRIPT: true,
      FORBID_TAGS: ['script', 'object', 'embed', 'iframe'],
      KEEP_CONTENT: false
    };

    return DOMPurify.sanitize(html, config);
  }

  static sanitizeFileName(fileName) {
    if (!fileName) return null;
    
    // Remove path traversal attempts
    let sanitized = fileName.replace(/[\.]{2,}/g, '');
    
    // Remove dangerous characters
    sanitized = sanitized.replace(/[<>:"/\\|?*\x00-\x1f]/g, '');
    
    // Limit length
    sanitized = sanitized.substring(0, 255);
    
    return sanitized.trim();
  }

  static sanitizeUrl(url) {
    if (!url) return null;
    
    try {
      const parsed = new URL(url);
      
      // Only allow http and https protocols
      if (!['http:', 'https:'].includes(parsed.protocol)) {
        throw new Error('Invalid protocol');
      }
      
      return parsed.toString();
    } catch (error) {
      return null;
    }
  }
}

// Sanitization middleware
const sanitizeInputs = (req, res, next) => {
  const sanitizeObject = (obj) => {
    for (const key in obj) {
      if (typeof obj[key] === 'string') {
        obj[key] = InputSanitizer.sanitizeString(obj[key]);
      } else if (typeof obj[key] === 'object' && obj[key] !== null) {
        sanitizeObject(obj[key]);
      }
    }
  };

  if (req.body) sanitizeObject(req.body);
  if (req.query) sanitizeObject(req.query);
  if (req.params) sanitizeObject(req.params);

  next();
};
```

### 2. **File Upload Security**

#### Secure File Upload Implementation
```javascript
// ✅ Secure file upload with validation
const multer = require('multer');
const path = require('path');
const crypto = require('crypto');

class FileUploadSecurity {
  constructor() {
    this.allowedImageTypes = ['image/jpeg', 'image/png', 'image/gif', 'image/webp'];
    this.allowedDocumentTypes = ['application/pdf', 'text/plain'];
    this.maxFileSize = 5 * 1024 * 1024; // 5MB
  }

  createStorage() {
    return multer.diskStorage({
      destination: (req, file, cb) => {
        const uploadPath = this.getUploadPath(file.mimetype);
        cb(null, uploadPath);
      },
      filename: (req, file, cb) => {
        const uniqueName = this.generateSecureFileName(file.originalname);
        cb(null, uniqueName);
      }
    });
  }

  generateSecureFileName(originalName) {
    const ext = path.extname(originalName);
    const randomName = crypto.randomBytes(16).toString('hex');
    const timestamp = Date.now();
    return `${timestamp}-${randomName}${ext}`;
  }

  getUploadPath(mimetype) {
    if (this.allowedImageTypes.includes(mimetype)) {
      return 'uploads/images/';
    } else if (this.allowedDocumentTypes.includes(mimetype)) {
      return 'uploads/documents/';
    }
    throw new Error('Invalid file type');
  }

  fileFilter(req, file, cb) {
    const allowedTypes = [...this.allowedImageTypes, ...this.allowedDocumentTypes];
    
    if (!allowedTypes.includes(file.mimetype)) {
      return cb(new Error('Invalid file type'), false);
    }

    // Additional security: Check file extension
    const ext = path.extname(file.originalname).toLowerCase();
    const allowedExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.pdf', '.txt'];
    
    if (!allowedExtensions.includes(ext)) {
      return cb(new Error('Invalid file extension'), false);
    }

    cb(null, true);
  }

  createUploader() {
    return multer({
      storage: this.createStorage(),
      fileFilter: this.fileFilter.bind(this),
      limits: {
        fileSize: this.maxFileSize,
        files: 5 // Maximum 5 files per request
      }
    });
  }
}

// File validation middleware
const validateFile = async (req, res, next) => {
  if (!req.file) {
    return next();
  }

  try {
    // Virus scanning (integrate with ClamAV or similar)
    await scanFileForViruses(req.file.path);

    // Image validation
    if (req.file.mimetype.startsWith('image/')) {
      await validateImageFile(req.file);
    }

    next();
  } catch (error) {
    // Remove uploaded file if validation fails
    fs.unlinkSync(req.file.path);
    res.status(400).json({ error: error.message });
  }
};

const validateImageFile = async (file) => {
  const sharp = require('sharp');
  
  try {
    const metadata = await sharp(file.path).metadata();
    
    // Check image dimensions
    if (metadata.width > 4000 || metadata.height > 4000) {
      throw new Error('Image dimensions too large');
    }

    // Check for embedded scripts (basic check)
    const buffer = fs.readFileSync(file.path);
    if (buffer.includes('<script>') || buffer.includes('javascript:')) {
      throw new Error('Potentially malicious file content');
    }
  } catch (error) {
    throw new Error('Invalid image file');
  }
};
```

## 🔒 Authorization Security

### 1. **Role-Based Access Control (RBAC)**

#### Advanced RBAC Implementation
```javascript
// ✅ Comprehensive RBAC system
class RBACService {
  constructor() {
    this.permissions = new Map();
    this.roles = new Map();
    this.initializePermissions();
    this.initializeRoles();
  }

  initializePermissions() {
    const permissions = [
      'user:read', 'user:write', 'user:delete',
      'post:read', 'post:write', 'post:delete',
      'admin:read', 'admin:write', 'admin:delete',
      'system:config', 'system:backup', 'system:logs'
    ];

    permissions.forEach(permission => {
      this.permissions.set(permission, {
        name: permission,
        description: `Permission to ${permission.replace(':', ' ')}`
      });
    });
  }

  initializeRoles() {
    this.roles.set('user', {
      name: 'user',
      permissions: ['user:read', 'post:read']
    });

    this.roles.set('moderator', {
      name: 'moderator',
      permissions: ['user:read', 'post:read', 'post:write', 'post:delete']
    });

    this.roles.set('admin', {
      name: 'admin',
      permissions: [
        'user:read', 'user:write', 'user:delete',
        'post:read', 'post:write', 'post:delete',
        'admin:read', 'admin:write'
      ]
    });

    this.roles.set('superadmin', {
      name: 'superadmin',
      permissions: Array.from(this.permissions.keys())
    });
  }

  hasPermission(userRole, requiredPermission) {
    const role = this.roles.get(userRole);
    if (!role) return false;
    
    return role.permissions.includes(requiredPermission);
  }

  hasAnyPermission(userRole, requiredPermissions) {
    return requiredPermissions.some(permission => 
      this.hasPermission(userRole, permission)
    );
  }

  hasAllPermissions(userRole, requiredPermissions) {
    return requiredPermissions.every(permission => 
      this.hasPermission(userRole, permission)
    );
  }
}

// Authorization middleware
const authorize = (permission) => {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({ error: 'Authentication required' });
    }

    const hasPermission = rbacService.hasPermission(req.user.role, permission);
    
    if (!hasPermission) {
      logger.warn({
        type: 'authorization_denied',
        userId: req.user.id,
        userRole: req.user.role,
        requiredPermission: permission,
        endpoint: req.originalUrl,
        method: req.method,
        ip: req.ip
      });

      return res.status(403).json({ 
        error: 'Insufficient permissions',
        required: permission
      });
    }

    next();
  };
};

// Resource-based authorization
const authorizeResource = (resource) => {
  return async (req, res, next) => {
    try {
      const resourceId = req.params.id;
      const userId = req.user.id;
      const userRole = req.user.role;

      // Admin and superadmin can access all resources
      if (['admin', 'superadmin'].includes(userRole)) {
        return next();
      }

      // Check resource ownership
      let resourceDoc;
      switch (resource) {
        case 'post':
          resourceDoc = await Post.findById(resourceId);
          break;
        case 'user':
          resourceDoc = await User.findById(resourceId);
          break;
        default:
          return res.status(400).json({ error: 'Invalid resource type' });
      }

      if (!resourceDoc) {
        return res.status(404).json({ error: 'Resource not found' });
      }

      // Check ownership or special permissions
      const isOwner = resourceDoc.createdBy?.toString() === userId ||
                     resourceDoc._id.toString() === userId;

      if (!isOwner) {
        return res.status(403).json({ error: 'Access denied to this resource' });
      }

      req.resource = resourceDoc;
      next();
    } catch (error) {
      res.status(500).json({ error: 'Authorization check failed' });
    }
  };
};
```

### 2. **API Key Management**

#### Secure API Key System
```javascript
// ✅ API Key management system
const crypto = require('crypto');

class APIKeyService {
  constructor() {
    this.keyPrefix = 'ak_';
    this.keyLength = 32;
  }

  generateAPIKey() {
    const randomBytes = crypto.randomBytes(this.keyLength);
    const key = this.keyPrefix + randomBytes.toString('hex');
    return key;
  }

  hashAPIKey(key) {
    return crypto.createHash('sha256').update(key).digest('hex');
  }

  async createAPIKey(userId, name, permissions = [], expiresAt = null) {
    const key = this.generateAPIKey();
    const hashedKey = this.hashAPIKey(key);

    const apiKey = await APIKey.create({
      userId,
      name,
      keyHash: hashedKey,
      permissions,
      expiresAt,
      lastUsedAt: null,
      isActive: true
    });

    // Return the plain key only once
    return {
      id: apiKey._id,
      key, // This is the only time the plain key is returned
      name,
      permissions,
      expiresAt,
      createdAt: apiKey.createdAt
    };
  }

  async validateAPIKey(key) {
    if (!key || !key.startsWith(this.keyPrefix)) {
      throw new Error('Invalid API key format');
    }

    const hashedKey = this.hashAPIKey(key);
    const apiKey = await APIKey.findOne({
      keyHash: hashedKey,
      isActive: true
    }).populate('userId', 'email role');

    if (!apiKey) {
      throw new Error('Invalid API key');
    }

    if (apiKey.expiresAt && apiKey.expiresAt < new Date()) {
      throw new Error('API key expired');
    }

    // Update last used timestamp
    await APIKey.findByIdAndUpdate(apiKey._id, {
      lastUsedAt: new Date(),
      $inc: { usageCount: 1 }
    });

    return apiKey;
  }
}

// API Key authentication middleware
const authenticateAPIKey = async (req, res, next) => {
  try {
    const apiKey = req.headers['x-api-key'] || req.query.api_key;
    
    if (!apiKey) {
      return res.status(401).json({ error: 'API key required' });
    }

    const validatedKey = await apiKeyService.validateAPIKey(apiKey);
    
    req.apiKey = validatedKey;
    req.user = validatedKey.userId;
    
    next();
  } catch (error) {
    logger.warn({
      type: 'invalid_api_key',
      key: req.headers['x-api-key']?.substring(0, 10) + '...',
      ip: req.ip,
      userAgent: req.get('User-Agent'),
      error: error.message
    });

    res.status(401).json({ error: error.message });
  }
};

// API Key permission check
const checkAPIKeyPermission = (requiredPermission) => {
  return (req, res, next) => {
    if (!req.apiKey) {
      return res.status(401).json({ error: 'API key authentication required' });
    }

    if (!req.apiKey.permissions.includes(requiredPermission)) {
      return res.status(403).json({ 
        error: 'API key lacks required permission',
        required: requiredPermission 
      });
    }

    next();
  };
};
```

## 🚨 Attack Prevention

### 1. **Rate Limiting & DDoS Protection**

#### Advanced Rate Limiting
```javascript
// ✅ Multi-tier rate limiting system
const rateLimit = require('express-rate-limit');
const RedisStore = require('rate-limit-redis');
const redis = require('redis');

class RateLimitService {
  constructor() {
    this.redisClient = redis.createClient(process.env.REDIS_URL);
    this.store = new RedisStore({
      sendCommand: (...args) => this.redisClient.sendCommand(args),
    });
  }

  // Global rate limiter
  createGlobalLimiter() {
    return rateLimit({
      store: this.store,
      windowMs: 15 * 60 * 1000, // 15 minutes
      max: 1000, // requests per window per IP
      message: 'Too many requests from this IP',
      standardHeaders: true,
      legacyHeaders: false,
      handler: (req, res) => {
        logger.warn({
          type: 'rate_limit_exceeded',
          ip: req.ip,
          userAgent: req.get('User-Agent'),
          endpoint: req.originalUrl
        });

        res.status(429).json({
          error: 'Too many requests',
          retryAfter: Math.round(15 * 60) // seconds
        });
      }
    });
  }

  // Authentication rate limiter
  createAuthLimiter() {
    return rateLimit({
      store: this.store,
      windowMs: 15 * 60 * 1000,
      max: 5, // 5 login attempts per window
      skipSuccessfulRequests: true,
      keyGenerator: (req) => {
        // Rate limit by IP and email combination
        return `auth:${req.ip}:${req.body.email || 'unknown'}`;
      },
      handler: (req, res) => {
        logger.warn({
          type: 'auth_rate_limit_exceeded',
          ip: req.ip,
          email: req.body.email,
          userAgent: req.get('User-Agent')
        });

        res.status(429).json({
          error: 'Too many authentication attempts',
          retryAfter: Math.round(15 * 60)
        });
      }
    });
  }

  // API rate limiter with user-based limits
  createAPILimiter() {
    return rateLimit({
      store: this.store,
      windowMs: 60 * 1000, // 1 minute
      max: (req) => {
        // Different limits based on user role
        if (req.user?.role === 'admin') return 200;
        if (req.user?.role === 'premium') return 100;
        return 50; // Default limit
      },
      keyGenerator: (req) => {
        return req.user?.id || req.ip;
      },
      handler: (req, res) => {
        res.status(429).json({
          error: 'API rate limit exceeded',
          retryAfter: 60
        });
      }
    });
  }

  // Distributed rate limiting
  createDistributedLimiter(maxRequests, windowMs) {
    return async (req, res, next) => {
      const key = `rate_limit:${req.ip}:${req.originalUrl}`;
      const current = await this.redisClient.incr(key);
      
      if (current === 1) {
        await this.redisClient.expire(key, Math.ceil(windowMs / 1000));
      }

      if (current > maxRequests) {
        const ttl = await this.redisClient.ttl(key);
        
        return res.status(429).json({
          error: 'Rate limit exceeded',
          retryAfter: ttl
        });
      }

      next();
    };
  }
}
```

### 2. **SQL/NoSQL Injection Prevention**

#### Injection Prevention Strategies
```javascript
// ✅ MongoDB injection prevention
const mongoSanitize = require('express-mongo-sanitize');

// Middleware to sanitize MongoDB queries
app.use(mongoSanitize({
  replaceWith: '_' // Replace prohibited characters
}));

// ✅ Safe query building
class SafeQueryBuilder {
  static buildUserQuery(filters) {
    const query = {};

    // Whitelist allowed filter fields
    const allowedFields = ['name', 'email', 'role', 'isActive', 'createdAt'];
    
    Object.keys(filters).forEach(key => {
      if (allowedFields.includes(key)) {
        if (key === 'name' || key === 'email') {
          // Use regex for text search with escaped input
          query[key] = new RegExp(this.escapeRegex(filters[key]), 'i');
        } else if (key === 'createdAt') {
          // Handle date ranges safely
          if (filters[key].start || filters[key].end) {
            query[key] = {};
            if (filters[key].start) {
              query[key].$gte = new Date(filters[key].start);
            }
            if (filters[key].end) {
              query[key].$lte = new Date(filters[key].end);
            }
          }
        } else {
          // Direct equality for other fields
          query[key] = filters[key];
        }
      }
    });

    return query;
  }

  static escapeRegex(string) {
    return string.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  }

  static buildSortQuery(sortBy, sortOrder) {
    const allowedSortFields = ['name', 'email', 'createdAt', 'updatedAt'];
    const allowedSortOrders = ['asc', 'desc', 1, -1];

    if (!allowedSortFields.includes(sortBy)) {
      sortBy = 'createdAt';
    }

    if (!allowedSortOrders.includes(sortOrder)) {
      sortOrder = 'desc';
    }

    return { [sortBy]: sortOrder === 'desc' ? -1 : 1 };
  }
}

// ✅ Parameterized queries for SQL databases
class SafeSQLQueryBuilder {
  static async findUserById(id) {
    // Use parameterized queries to prevent SQL injection
    const query = 'SELECT * FROM users WHERE id = $1 AND deleted_at IS NULL';
    const values = [id];
    
    try {
      const result = await db.query(query, values);
      return result.rows[0];
    } catch (error) {
      logger.error('Database query error:', error);
      throw new Error('Database operation failed');
    }
  }

  static async searchUsers(searchTerm, limit, offset) {
    const query = `
      SELECT id, name, email, created_at 
      FROM users 
      WHERE (name ILIKE $1 OR email ILIKE $1) 
        AND deleted_at IS NULL 
      ORDER BY created_at DESC 
      LIMIT $2 OFFSET $3
    `;
    
    const searchPattern = `%${searchTerm}%`;
    const values = [searchPattern, limit, offset];
    
    try {
      const result = await db.query(query, values);
      return result.rows;
    } catch (error) {
      logger.error('Search query error:', error);
      throw new Error('Search operation failed');
    }
  }
}
```

### 3. **Cross-Site Scripting (XSS) Prevention**

#### XSS Protection Implementation
```javascript
// ✅ Comprehensive XSS prevention
const DOMPurify = require('isomorphic-dompurify');
const helmet = require('helmet');

class XSSProtection {
  static sanitizeContent(content, allowedTags = []) {
    if (!content || typeof content !== 'string') {
      return content;
    }

    const defaultAllowedTags = [
      'p', 'br', 'strong', 'em', 'u', 'ol', 'ul', 'li',
      'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'blockquote'
    ];

    const tagsToAllow = allowedTags.length > 0 ? allowedTags : defaultAllowedTags;

    return DOMPurify.sanitize(content, {
      ALLOWED_TAGS: tagsToAllow,
      ALLOWED_ATTR: ['href', 'target', 'rel'],
      FORBID_SCRIPT: true,
      FORBID_TAGS: ['script', 'object', 'embed', 'iframe', 'form', 'input'],
      KEEP_CONTENT: false,
      ADD_ATTR: ['target'], // For links
      ADD_TAGS: [], // No additional tags
      FORCE_BODY: false
    });
  }

  static sanitizeUserInput(input) {
    if (typeof input === 'string') {
      // Remove any script tags and event handlers
      return input
        .replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, '')
        .replace(/on\w+="[^"]*"/gi, '')
        .replace(/on\w+='[^']*'/gi, '')
        .replace(/javascript:/gi, '')
        .replace(/vbscript:/gi, '')
        .replace(/data:text\/html/gi, '');
    }
    return input;
  }

  static createCSPMiddleware() {
    return helmet.contentSecurityPolicy({
      directives: {
        defaultSrc: ["'self'"],
        styleSrc: [
          "'self'",
          "'unsafe-inline'", // Only if absolutely necessary
          "https://fonts.googleapis.com",
          "https://cdn.jsdelivr.net"
        ],
        fontSrc: [
          "'self'",
          "https://fonts.gstatic.com"
        ],
        scriptSrc: [
          "'self'",
          // Use nonces or hashes instead of 'unsafe-inline'
          (req, res) => `'nonce-${res.locals.nonce}'`
        ],
        imgSrc: [
          "'self'",
          "data:",
          "https:",
          "blob:"
        ],
        connectSrc: [
          "'self'",
          "https://api.yourservice.com"
        ],
        frameSrc: ["'none'"],
        objectSrc: ["'none'"],
        baseUri: ["'self'"],
        formAction: ["'self'"],
        upgradeInsecureRequests: []
      },
      reportOnly: false
    });
  }
}

// Middleware to generate CSP nonces
const generateCSPNonce = (req, res, next) => {
  res.locals.nonce = crypto.randomBytes(16).toString('base64');
  next();
};

// Content sanitization middleware
const sanitizeContent = (req, res, next) => {
  if (req.body) {
    req.body = sanitizeObject(req.body);
  }
  
  if (req.query) {
    req.query = sanitizeObject(req.query);
  }
  
  next();
};

function sanitizeObject(obj) {
  const sanitized = {};
  
  for (const key in obj) {
    if (obj.hasOwnProperty(key)) {
      if (typeof obj[key] === 'string') {
        sanitized[key] = XSSProtection.sanitizeUserInput(obj[key]);
      } else if (typeof obj[key] === 'object' && obj[key] !== null) {
        sanitized[key] = sanitizeObject(obj[key]);
      } else {
        sanitized[key] = obj[key];
      }
    }
  }
  
  return sanitized;
}
```

## 🔍 Security Monitoring

### 1. **Security Event Logging**

#### Comprehensive Security Logging
```javascript
// ✅ Security event monitoring
class SecurityLogger {
  constructor() {
    this.securityLogger = winston.createLogger({
      level: 'info',
      format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.json()
      ),
      transports: [
        new winston.transports.File({ 
          filename: 'logs/security.log',
          maxsize: 10485760,
          maxFiles: 10
        }),
        new winston.transports.Console()
      ]
    });
  }

  logSecurityEvent(eventType, details) {
    this.securityLogger.info({
      type: 'security_event',
      eventType,
      timestamp: new Date().toISOString(),
      ...details
    });
  }

  logSuspiciousActivity(activity, req) {
    this.logSecurityEvent('suspicious_activity', {
      activity,
      ip: req.ip,
      userAgent: req.get('User-Agent'),
      url: req.originalUrl,
      method: req.method,
      userId: req.user?.id,
      headers: this.sanitizeHeaders(req.headers)
    });
  }

  logAuthenticationEvent(event, details) {
    this.logSecurityEvent('authentication', {
      event, // 'login_success', 'login_failure', 'logout', 'password_change'
      ...details
    });
  }

  logAccessDenied(req, reason) {
    this.logSecurityEvent('access_denied', {
      reason,
      ip: req.ip,
      url: req.originalUrl,
      method: req.method,
      userId: req.user?.id,
      userRole: req.user?.role
    });
  }

  sanitizeHeaders(headers) {
    const sanitized = { ...headers };
    delete sanitized.authorization;
    delete sanitized.cookie;
    delete sanitized['x-api-key'];
    return sanitized;
  }
}

// Security monitoring middleware
const securityMonitoring = (req, res, next) => {
  // Monitor for suspicious patterns
  const suspiciousPatterns = [
    /union.*select/i,           // SQL injection
    /<script/i,                 // XSS attempts
    /\.\.\/.*\.\.\/.*\.\.\//,   // Path traversal
    /etc\/passwd/i,             // System file access
    /proc\/.*\/environ/i,       // Process information
    /cmd\.exe/i,                // Command injection
    /powershell/i               // PowerShell injection
  ];

  const requestString = JSON.stringify(req.body) + req.url + JSON.stringify(req.query);

  for (const pattern of suspiciousPatterns) {
    if (pattern.test(requestString)) {
      securityLogger.logSuspiciousActivity(`Pattern detected: ${pattern}`, req);
      
      // Optional: Block suspicious requests
      return res.status(403).json({ error: 'Request blocked for security reasons' });
    }
  }

  next();
};
```

### 2. **Intrusion Detection**

#### Real-time Threat Detection
```javascript
// ✅ Intrusion detection system
class IntrusionDetection {
  constructor() {
    this.threatScores = new Map(); // IP -> score
    this.blockedIPs = new Set();
    this.suspiciousPatterns = [
      { pattern: /admin|administrator/i, score: 5 },
      { pattern: /\.php$/i, score: 3 },
      { pattern: /wp-admin/i, score: 4 },
      { pattern: /union.*select/i, score: 10 },
      { pattern: /<script/i, score: 8 },
      { pattern: /etc\/passwd/i, score: 10 }
    ];
  }

  analyzeRequest(req) {
    const ip = req.ip;
    const url = req.url;
    const userAgent = req.get('User-Agent') || '';
    const body = JSON.stringify(req.body || {});
    
    let threatScore = this.threatScores.get(ip) || 0;

    // Check for suspicious patterns
    const requestContent = url + userAgent + body;
    
    for (const { pattern, score } of this.suspiciousPatterns) {
      if (pattern.test(requestContent)) {
        threatScore += score;
        
        securityLogger.logSuspiciousActivity(
          `Threat pattern detected: ${pattern}`,
          req
        );
      }
    }

    // Check for rapid requests (potential DoS)
    const requestKey = `requests:${ip}`;
    const requestCount = this.incrementRequestCount(requestKey);
    
    if (requestCount > 100) { // 100 requests per minute
      threatScore += 5;
    }

    // Check for failed authentication attempts
    if (req.authFailure) {
      threatScore += 3;
    }

    // Update threat score
    this.threatScores.set(ip, threatScore);

    // Block IP if threat score is too high
    if (threatScore >= 20) {
      this.blockedIPs.add(ip);
      this.notifyAdministrators(ip, threatScore);
      
      securityLogger.logSecurityEvent('ip_blocked', {
        ip,
        threatScore,
        reason: 'High threat score detected'
      });
    }

    return threatScore;
  }

  incrementRequestCount(key) {
    // This would typically use Redis for distributed systems
    const current = parseInt(process.env[key] || '0');
    process.env[key] = (current + 1).toString();
    
    // Reset counter after 1 minute
    setTimeout(() => {
      delete process.env[key];
    }, 60000);
    
    return current + 1;
  }

  isBlocked(ip) {
    return this.blockedIPs.has(ip);
  }

  unblockIP(ip) {
    this.blockedIPs.delete(ip);
    this.threatScores.delete(ip);
    
    securityLogger.logSecurityEvent('ip_unblocked', { ip });
  }

  notifyAdministrators(ip, threatScore) {
    // Send notification to administrators
    const notification = {
      type: 'security_alert',
      message: `High threat score detected for IP: ${ip}`,
      threatScore,
      timestamp: new Date().toISOString()
    };

    // Send email, Slack notification, etc.
    this.sendSecurityAlert(notification);
  }

  async sendSecurityAlert(notification) {
    // Implementation for sending alerts
    try {
      // Email notification
      await emailService.sendAlert(
        process.env.ADMIN_EMAIL,
        'Security Alert',
        JSON.stringify(notification, null, 2)
      );
      
      // Slack notification if configured
      if (process.env.SLACK_WEBHOOK_URL) {
        await this.sendSlackAlert(notification);
      }
    } catch (error) {
      logger.error('Failed to send security alert:', error);
    }
  }
}

// Intrusion detection middleware
const intrusionDetection = (req, res, next) => {
  const ip = req.ip;
  
  // Check if IP is blocked
  if (ids.isBlocked(ip)) {
    securityLogger.logSecurityEvent('blocked_ip_attempt', { ip });
    return res.status(403).json({ error: 'Access denied' });
  }

  // Analyze request for threats
  const threatScore = ids.analyzeRequest(req);
  
  // Add threat score to request for logging
  req.threatScore = threatScore;
  
  next();
};
```

---

## 🧭 Navigation

### ⬅️ Previous: [Best Practices](./best-practices.md)
### ➡️ Next: [Architecture Patterns](./architecture-patterns.md)

---

*Security considerations compiled from analysis of production Express.js applications with proven security implementations.*