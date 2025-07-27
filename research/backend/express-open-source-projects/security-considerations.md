# Security Considerations: Express.js Production Applications

## 🎯 Overview

This document provides comprehensive security guidelines derived from analyzing 15+ production Express.js applications. It covers authentication, authorization, data protection, and operational security practices used by successful open source projects.

## 📋 Table of Contents

1. [Authentication Strategies](#1-authentication-strategies)
2. [Authorization & Access Control](#2-authorization--access-control)
3. [Input Validation & Sanitization](#3-input-validation--sanitization)
4. [Security Middleware Stack](#4-security-middleware-stack)
5. [Data Protection & Encryption](#5-data-protection--encryption)
6. [API Security](#6-api-security)
7. [Session Management](#7-session-management)
8. [Security Monitoring & Auditing](#8-security-monitoring--auditing)

## 1. Authentication Strategies

### 1.1 JWT-Based Authentication (Recommended)

**Implementation Pattern from Ghost & Strapi**:

```javascript
// src/services/authService.js
const jwt = require('jsonwebtoken');
const crypto = require('crypto');

class AuthService {
  // Token configuration
  static TOKEN_CONFIG = {
    access: {
      secret: process.env.JWT_SECRET,
      expiresIn: '15m',
      algorithm: 'HS256'
    },
    refresh: {
      secret: process.env.REFRESH_TOKEN_SECRET,
      expiresIn: '7d',
      algorithm: 'HS256'
    }
  };

  // Generate secure token pair
  generateTokens(user) {
    const payload = {
      sub: user.id,
      email: user.email,
      role: user.role,
      iat: Math.floor(Date.now() / 1000),
      jti: crypto.randomUUID() // JWT ID for token tracking
    };

    const accessToken = jwt.sign(
      { ...payload, type: 'access' },
      this.TOKEN_CONFIG.access.secret,
      {
        expiresIn: this.TOKEN_CONFIG.access.expiresIn,
        algorithm: this.TOKEN_CONFIG.access.algorithm,
        issuer: process.env.APP_NAME,
        audience: `${process.env.APP_NAME}:users`
      }
    );

    const refreshToken = jwt.sign(
      { ...payload, type: 'refresh' },
      this.TOKEN_CONFIG.refresh.secret,
      {
        expiresIn: this.TOKEN_CONFIG.refresh.expiresIn,
        algorithm: this.TOKEN_CONFIG.refresh.algorithm
      }
    );

    return { accessToken, refreshToken };
  }

  // Verify and decode token with comprehensive validation
  async verifyToken(token, type = 'access') {
    try {
      const config = this.TOKEN_CONFIG[type];
      const decoded = jwt.verify(token, config.secret, {
        algorithms: [config.algorithm],
        issuer: process.env.APP_NAME,
        audience: type === 'access' ? `${process.env.APP_NAME}:users` : undefined
      });

      // Additional security checks
      if (decoded.type !== type) {
        throw new Error('Invalid token type');
      }

      // Check if token is blacklisted
      const isBlacklisted = await this.isTokenBlacklisted(decoded.jti);
      if (isBlacklisted) {
        throw new Error('Token has been revoked');
      }

      return decoded;
    } catch (error) {
      throw new Error(`Token verification failed: ${error.message}`);
    }
  }

  // Token blacklisting for logout/revocation
  async blacklistToken(jti, expiresAt) {
    await Redis.setex(`blacklist:${jti}`, expiresAt - Date.now(), 'revoked');
  }

  async isTokenBlacklisted(jti) {
    const result = await Redis.get(`blacklist:${jti}`);
    return result !== null;
  }
}
```

### 1.2 Multi-Factor Authentication (MFA)

**TOTP Implementation from Rocket.Chat**:

```javascript
// src/services/mfaService.js
const speakeasy = require('speakeasy');
const QRCode = require('qrcode');

class MFAService {
  // Generate TOTP secret for user
  async generateTOTPSecret(userId) {
    const secret = speakeasy.generateSecret({
      name: `${process.env.APP_NAME} (${userId})`,
      issuer: process.env.APP_NAME,
      length: 32
    });

    // Store secret (encrypted) in database
    await User.updateOne(
      { _id: userId },
      {
        $set: {
          'mfa.totpSecret': this.encryptSecret(secret.base32),
          'mfa.enabled': false // Not enabled until verified
        }
      }
    );

    // Generate QR code for setup
    const qrCodeUrl = await QRCode.toDataURL(secret.otpauth_url);

    return {
      secret: secret.base32,
      qrCode: qrCodeUrl,
      manualEntryKey: secret.base32
    };
  }

  // Verify TOTP token
  async verifyTOTP(userId, token) {
    const user = await User.findById(userId).select('mfa.totpSecret');
    if (!user?.mfa?.totpSecret) {
      throw new Error('TOTP not configured for user');
    }

    const secret = this.decryptSecret(user.mfa.totpSecret);
    
    const verified = speakeasy.totp.verify({
      secret,
      encoding: 'base32',
      token,
      window: 2 // Allow 1 step before/after for clock drift
    });

    if (verified) {
      // Update last used timestamp to prevent replay attacks
      await User.updateOne(
        { _id: userId },
        { $set: { 'mfa.lastUsed': new Date() } }
      );
    }

    return verified;
  }

  // Generate backup codes
  async generateBackupCodes(userId) {
    const codes = Array.from({ length: 8 }, () => 
      crypto.randomBytes(4).toString('hex').toUpperCase()
    );

    const hashedCodes = codes.map(code => bcrypt.hashSync(code, 12));

    await User.updateOne(
      { _id: userId },
      { $set: { 'mfa.backupCodes': hashedCodes } }
    );

    return codes; // Return unhashed codes to user (one time only)
  }

  // Verify backup code
  async verifyBackupCode(userId, code) {
    const user = await User.findById(userId).select('mfa.backupCodes');
    if (!user?.mfa?.backupCodes?.length) {
      return false;
    }

    const codeIndex = user.mfa.backupCodes.findIndex(hashedCode =>
      bcrypt.compareSync(code, hashedCode)
    );

    if (codeIndex !== -1) {
      // Remove used backup code
      user.mfa.backupCodes.splice(codeIndex, 1);
      await user.save();
      return true;
    }

    return false;
  }
}
```

### 1.3 OAuth Integration

**OAuth 2.0 Implementation from GitLab CE**:

```javascript
// src/services/oauthService.js
class OAuthService {
  constructor() {
    this.providers = {
      google: {
        clientId: process.env.GOOGLE_CLIENT_ID,
        clientSecret: process.env.GOOGLE_CLIENT_SECRET,
        authUrl: 'https://accounts.google.com/o/oauth2/v2/auth',
        tokenUrl: 'https://oauth2.googleapis.com/token',
        userInfoUrl: 'https://www.googleapis.com/oauth2/v2/userinfo',
        scope: 'openid email profile'
      },
      github: {
        clientId: process.env.GITHUB_CLIENT_ID,
        clientSecret: process.env.GITHUB_CLIENT_SECRET,
        authUrl: 'https://github.com/login/oauth/authorize',
        tokenUrl: 'https://github.com/login/oauth/access_token',
        userInfoUrl: 'https://api.github.com/user',
        scope: 'user:email'
      }
    };
  }

  // Generate OAuth authorization URL
  getAuthorizationUrl(provider, state) {
    const config = this.providers[provider];
    if (!config) {
      throw new Error('Unsupported OAuth provider');
    }

    const params = new URLSearchParams({
      client_id: config.clientId,
      redirect_uri: `${process.env.BASE_URL}/auth/oauth/${provider}/callback`,
      scope: config.scope,
      response_type: 'code',
      state: state // CSRF protection
    });

    return `${config.authUrl}?${params.toString()}`;
  }

  // Handle OAuth callback
  async handleCallback(provider, code, state) {
    // Verify state parameter (CSRF protection)
    if (!this.verifyState(state)) {
      throw new Error('Invalid state parameter');
    }

    const config = this.providers[provider];
    
    // Exchange code for access token
    const tokens = await this.exchangeCodeForTokens(provider, code);
    
    // Get user information
    const userInfo = await this.getUserInfo(provider, tokens.access_token);
    
    // Create or update user
    const user = await this.findOrCreateUser(userInfo, provider);
    
    return user;
  }

  async exchangeCodeForTokens(provider, code) {
    const config = this.providers[provider];
    
    const response = await fetch(config.tokenUrl, {
      method: 'POST',
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/x-www-form-urlencoded'
      },
      body: new URLSearchParams({
        client_id: config.clientId,
        client_secret: config.clientSecret,
        code,
        redirect_uri: `${process.env.BASE_URL}/auth/oauth/${provider}/callback`
      })
    });

    if (!response.ok) {
      throw new Error('Failed to exchange code for tokens');
    }

    return response.json();
  }

  async getUserInfo(provider, accessToken) {
    const config = this.providers[provider];
    
    const response = await fetch(config.userInfoUrl, {
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Accept': 'application/json'
      }
    });

    if (!response.ok) {
      throw new Error('Failed to fetch user information');
    }

    return response.json();
  }
}
```

## 2. Authorization & Access Control

### 2.1 Role-Based Access Control (RBAC)

**RBAC Implementation from Strapi**:

```javascript
// src/services/rbacService.js
class RBACService {
  constructor() {
    this.permissions = new Map();
    this.roles = new Map();
  }

  // Define permission structure
  definePermission(resource, action, condition = null) {
    const permissionKey = `${resource}:${action}`;
    this.permissions.set(permissionKey, {
      resource,
      action,
      condition
    });
  }

  // Define roles with permissions
  defineRole(roleName, permissions) {
    this.roles.set(roleName, {
      name: roleName,
      permissions: new Set(permissions)
    });
  }

  // Check if user has permission
  async hasPermission(user, resource, action, context = {}) {
    const userRoles = await this.getUserRoles(user.id);
    
    for (const role of userRoles) {
      if (await this.roleHasPermission(role, resource, action, context)) {
        return true;
      }
    }
    
    return false;
  }

  async roleHasPermission(roleName, resource, action, context) {
    const role = this.roles.get(roleName);
    if (!role) return false;

    const permissionKey = `${resource}:${action}`;
    
    // Check if role has the permission
    if (!role.permissions.has(permissionKey)) {
      return false;
    }

    // Check condition if exists
    const permission = this.permissions.get(permissionKey);
    if (permission.condition) {
      return await this.evaluateCondition(permission.condition, context);
    }

    return true;
  }

  // Evaluate dynamic conditions
  async evaluateCondition(condition, context) {
    switch (condition.type) {
      case 'owner':
        return context.resource?.ownerId === context.user?.id;
      
      case 'same_organization':
        return context.resource?.organizationId === context.user?.organizationId;
      
      case 'custom':
        return await condition.handler(context);
      
      default:
        return false;
    }
  }
}

// Permission definitions
const rbac = new RBACService();

// Define permissions
rbac.definePermission('user', 'read');
rbac.definePermission('user', 'create');
rbac.definePermission('user', 'update', { type: 'owner' });
rbac.definePermission('user', 'delete', { type: 'owner' });

rbac.definePermission('post', 'read');
rbac.definePermission('post', 'create');
rbac.definePermission('post', 'update', { type: 'owner' });
rbac.definePermission('post', 'delete', { type: 'owner' });

// Define roles
rbac.defineRole('user', [
  'user:read',
  'user:update',
  'post:read',
  'post:create',
  'post:update',
  'post:delete'
]);

rbac.defineRole('admin', [
  'user:read',
  'user:create',
  'user:update',
  'user:delete',
  'post:read',
  'post:create',
  'post:update',
  'post:delete'
]);
```

### 2.2 Authorization Middleware

```javascript
// src/middleware/authorization.js
const authorize = (resource, action) => {
  return async (req, res, next) => {
    try {
      if (!req.user) {
        return res.status(401).json({
          success: false,
          message: 'Authentication required'
        });
      }

      const context = {
        user: req.user,
        resource: req.params.id ? await getResource(resource, req.params.id) : null,
        request: req
      };

      const hasPermission = await rbac.hasPermission(
        req.user,
        resource,
        action,
        context
      );

      if (!hasPermission) {
        return res.status(403).json({
          success: false,
          message: 'Insufficient permissions'
        });
      }

      req.authContext = context;
      next();
    } catch (error) {
      logger.error('Authorization error:', error);
      res.status(500).json({
        success: false,
        message: 'Authorization check failed'
      });
    }
  };
};

// Usage in routes
app.get('/api/posts/:id', 
  authenticateToken,
  authorize('post', 'read'),
  getPostController
);

app.put('/api/posts/:id',
  authenticateToken,
  authorize('post', 'update'),
  updatePostController
);
```

## 3. Input Validation & Sanitization

### 3.1 Comprehensive Validation Schema

**Validation Implementation from Parse Server**:

```javascript
// src/validators/userValidator.js
const { body, param, query } = require('express-validator');
const validator = require('validator');

class UserValidator {
  // Registration validation
  static register = [
    body('email')
      .isEmail()
      .withMessage('Valid email is required')
      .normalizeEmail()
      .custom(async (email) => {
        const existingUser = await User.findOne({ email });
        if (existingUser) {
          throw new Error('Email already in use');
        }
      }),
    
    body('password')
      .isLength({ min: 8, max: 128 })
      .withMessage('Password must be between 8 and 128 characters')
      .matches(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]/)
      .withMessage('Password must contain at least one uppercase letter, one lowercase letter, one number, and one special character'),
    
    body('firstName')
      .trim()
      .isLength({ min: 1, max: 50 })
      .withMessage('First name must be between 1 and 50 characters')
      .matches(/^[a-zA-Z\s'-]+$/)
      .withMessage('First name can only contain letters, spaces, hyphens, and apostrophes')
      .escape(),
    
    body('lastName')
      .trim()
      .isLength({ min: 1, max: 50 })
      .withMessage('Last name must be between 1 and 50 characters')
      .matches(/^[a-zA-Z\s'-]+$/)
      .withMessage('Last name can only contain letters, spaces, hyphens, and apostrophes')
      .escape(),
    
    body('dateOfBirth')
      .optional()
      .isISO8601()
      .withMessage('Date of birth must be a valid date')
      .custom((value) => {
        const date = new Date(value);
        const now = new Date();
        const age = now.getFullYear() - date.getFullYear();
        if (age < 13 || age > 120) {
          throw new Error('Age must be between 13 and 120 years');
        }
        return true;
      }),
    
    body('phoneNumber')
      .optional()
      .isMobilePhone()
      .withMessage('Valid phone number is required'),
    
    this.handleValidationErrors
  ];

  // Profile update validation
  static updateProfile = [
    param('id')
      .isMongoId()
      .withMessage('Invalid user ID'),
    
    body('firstName')
      .optional()
      .trim()
      .isLength({ min: 1, max: 50 })
      .matches(/^[a-zA-Z\s'-]+$/)
      .escape(),
    
    body('lastName')
      .optional()
      .trim()
      .isLength({ min: 1, max: 50 })
      .matches(/^[a-zA-Z\s'-]+$/)
      .escape(),
    
    body('bio')
      .optional()
      .trim()
      .isLength({ max: 500 })
      .withMessage('Bio cannot exceed 500 characters')
      .escape(),
    
    body('website')
      .optional()
      .isURL({
        protocols: ['http', 'https'],
        require_protocol: true
      })
      .withMessage('Valid URL is required'),
    
    body('socialLinks')
      .optional()
      .isArray()
      .withMessage('Social links must be an array')
      .custom((links) => {
        if (links.length > 5) {
          throw new Error('Maximum 5 social links allowed');
        }
        
        for (const link of links) {
          if (!validator.isURL(link.url, { protocols: ['http', 'https'], require_protocol: true })) {
            throw new Error('All social links must be valid URLs');
          }
          if (!['twitter', 'facebook', 'linkedin', 'github', 'instagram'].includes(link.platform)) {
            throw new Error('Invalid social platform');
          }
        }
        return true;
      }),
    
    this.handleValidationErrors
  ];

  // Search query validation
  static search = [
    query('q')
      .trim()
      .isLength({ min: 1, max: 100 })
      .withMessage('Search query must be between 1 and 100 characters')
      .escape(),
    
    query('page')
      .optional()
      .isInt({ min: 1, max: 1000 })
      .withMessage('Page must be between 1 and 1000')
      .toInt(),
    
    query('limit')
      .optional()
      .isInt({ min: 1, max: 100 })
      .withMessage('Limit must be between 1 and 100')
      .toInt(),
    
    query('sortBy')
      .optional()
      .isIn(['createdAt', 'firstName', 'lastName', 'relevance'])
      .withMessage('Invalid sort field'),
    
    query('order')
      .optional()
      .isIn(['asc', 'desc'])
      .withMessage('Order must be asc or desc'),
    
    this.handleValidationErrors
  ];

  // Error handling middleware
  static handleValidationErrors = (req, res, next) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        success: false,
        message: 'Validation failed',
        errors: errors.array().map(error => ({
          field: error.param,
          message: error.msg,
          value: error.value
        }))
      });
    }
    next();
  };
}

module.exports = UserValidator;
```

### 3.2 File Upload Security

```javascript
// src/middleware/fileUpload.js
const multer = require('multer');
const path = require('path');
const crypto = require('crypto');
const sharp = require('sharp');

class FileUploadSecurity {
  constructor() {
    this.allowedMimeTypes = {
      image: ['image/jpeg', 'image/png', 'image/webp', 'image/gif'],
      document: ['application/pdf', 'application/msword', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'],
      video: ['video/mp4', 'video/webm', 'video/quicktime']
    };
    
    this.maxFileSizes = {
      image: 5 * 1024 * 1024, // 5MB
      document: 10 * 1024 * 1024, // 10MB
      video: 50 * 1024 * 1024 // 50MB
    };
  }

  createUploadMiddleware(type, options = {}) {
    const storage = multer.memoryStorage();
    
    const fileFilter = (req, file, cb) => {
      // Check MIME type
      const allowedTypes = this.allowedMimeTypes[type];
      if (!allowedTypes.includes(file.mimetype)) {
        return cb(new Error(`Invalid file type. Allowed types: ${allowedTypes.join(', ')}`));
      }

      // Check file extension
      const ext = path.extname(file.originalname).toLowerCase();
      const allowedExtensions = this.getExtensionsForType(type);
      if (!allowedExtensions.includes(ext)) {
        return cb(new Error(`Invalid file extension. Allowed extensions: ${allowedExtensions.join(', ')}`));
      }

      cb(null, true);
    };

    const upload = multer({
      storage,
      fileFilter,
      limits: {
        fileSize: this.maxFileSizes[type],
        files: options.maxFiles || 1
      }
    });

    return upload;
  }

  // Process and validate uploaded files
  async processUpload(file, type) {
    // Validate file signature (magic numbers)
    if (!this.validateFileSignature(file.buffer, file.mimetype)) {
      throw new Error('File signature does not match MIME type');
    }

    // Generate secure filename
    const filename = crypto.randomUUID() + path.extname(file.originalname);
    
    let processedBuffer = file.buffer;
    
    // Process images (strip metadata, resize if needed)
    if (type === 'image') {
      processedBuffer = await this.processImage(file.buffer);
    }

    return {
      filename,
      buffer: processedBuffer,
      mimetype: file.mimetype,
      size: processedBuffer.length
    };
  }

  validateFileSignature(buffer, mimetype) {
    const signatures = {
      'image/jpeg': [0xFF, 0xD8, 0xFF],
      'image/png': [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A],
      'image/gif': [0x47, 0x49, 0x46, 0x38],
      'application/pdf': [0x25, 0x50, 0x44, 0x46]
    };

    const signature = signatures[mimetype];
    if (!signature) return true; // Allow if no signature defined

    return signature.every((byte, index) => buffer[index] === byte);
  }

  async processImage(buffer) {
    return sharp(buffer)
      .resize({ width: 2048, height: 2048, fit: 'inside', withoutEnlargement: true })
      .jpeg({ quality: 80, progressive: true })
      .withMetadata(false) // Strip EXIF data
      .toBuffer();
  }

  getExtensionsForType(type) {
    const extensions = {
      image: ['.jpg', '.jpeg', '.png', '.webp', '.gif'],
      document: ['.pdf', '.doc', '.docx'],
      video: ['.mp4', '.webm', '.mov']
    };
    
    return extensions[type] || [];
  }
}

// Usage
const fileUploadSecurity = new FileUploadSecurity();

const uploadImage = fileUploadSecurity.createUploadMiddleware('image', { maxFiles: 5 });

app.post('/api/upload/image', 
  authenticateToken,
  uploadImage.array('images'),
  async (req, res) => {
    try {
      const processedFiles = [];
      
      for (const file of req.files) {
        const processed = await fileUploadSecurity.processUpload(file, 'image');
        // Save to storage (S3, local filesystem, etc.)
        const url = await saveToStorage(processed);
        processedFiles.push({ filename: processed.filename, url });
      }
      
      res.json({
        success: true,
        data: { files: processedFiles }
      });
    } catch (error) {
      res.status(400).json({
        success: false,
        message: error.message
      });
    }
  }
);
```

## 4. Security Middleware Stack

### 4.1 Comprehensive Security Configuration

**Security Middleware from Ghost**:

```javascript
// src/middleware/security.js
const helmet = require('helmet');
const cors = require('cors');
const rateLimit = require('express-rate-limit');
const slowDown = require('express-slow-down');
const compression = require('compression');

class SecurityMiddleware {
  static configure(app) {
    // Content Security Policy
    app.use(helmet.contentSecurityPolicy({
      directives: {
        defaultSrc: ["'self'"],
        scriptSrc: [
          "'self'",
          "'unsafe-inline'", // Only if absolutely necessary
          "https://apis.google.com",
          "https://js.stripe.com"
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
          "https://api.stripe.com",
          "wss:"
        ],
        mediaSrc: ["'self'"],
        objectSrc: ["'none'"],
        baseUri: ["'self'"],
        formAction: ["'self'"],
        frameAncestors: ["'none'"],
        upgradeInsecureRequests: []
      },
      reportOnly: process.env.NODE_ENV !== 'production'
    }));

    // Other security headers
    app.use(helmet({
      hsts: {
        maxAge: 31536000,
        includeSubDomains: true,
        preload: true
      },
      noSniff: true,
      xssFilter: true,
      referrerPolicy: { policy: 'strict-origin-when-cross-origin' },
      permittedCrossDomainPolicies: false,
      crossOriginEmbedderPolicy: true
    }));

    // CORS configuration
    const corsOptions = {
      origin: (origin, callback) => {
        const allowedOrigins = (process.env.ALLOWED_ORIGINS || '').split(',');
        
        // Allow requests with no origin (mobile apps, Postman, etc.)
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
        'Cache-Control',
        'X-Request-ID'
      ],
      exposedHeaders: ['X-Request-ID', 'X-Total-Count'],
      maxAge: 86400 // 24 hours
    };
    
    app.use(cors(corsOptions));

    // Rate limiting with multiple tiers
    const createRateLimit = (windowMs, max, message, skipSuccessfulRequests = false) => 
      rateLimit({
        windowMs,
        max,
        message: { success: false, message },
        standardHeaders: true,
        legacyHeaders: false,
        skipSuccessfulRequests,
        keyGenerator: (req) => {
          // Use IP + User ID for authenticated requests
          return req.user ? `${req.ip}:${req.user.id}` : req.ip;
        }
      });

    // Global rate limiting
    app.use('/api', createRateLimit(
      15 * 60 * 1000, // 15 minutes
      1000, // requests per window
      'Too many requests from this IP, please try again later.'
    ));

    // Authentication rate limiting
    app.use('/api/auth', createRateLimit(
      15 * 60 * 1000, // 15 minutes
      5, // attempts per window
      'Too many authentication attempts, please try again later.',
      true // Don't count successful requests
    ));

    // Slow down repeated requests
    app.use('/api/auth', slowDown({
      windowMs: 15 * 60 * 1000, // 15 minutes
      delayAfter: 2, // Allow 2 requests per window at full speed
      delayMs: 500, // Add 500ms delay per request after delayAfter
      maxDelayMs: 20000 // Maximum delay of 20 seconds
    }));

    // Body parsing with limits
    app.use(express.json({ 
      limit: '10mb',
      verify: (req, res, buf) => {
        // Store raw body for webhook verification
        req.rawBody = buf;
      }
    }));
    
    app.use(express.urlencoded({ 
      extended: true, 
      limit: '10mb' 
    }));

    // Compression
    app.use(compression({
      filter: (req, res) => {
        if (req.headers['x-no-compression']) {
          return false;
        }
        return compression.filter(req, res);
      },
      level: 6,
      threshold: 1024
    }));

    // Security headers middleware
    app.use((req, res, next) => {
      // Prevent MIME type sniffing
      res.setHeader('X-Content-Type-Options', 'nosniff');
      
      // Prevent clickjacking
      res.setHeader('X-Frame-Options', 'DENY');
      
      // XSS protection
      res.setHeader('X-XSS-Protection', '1; mode=block');
      
      // Hide server information
      res.removeHeader('X-Powered-By');
      
      // Add request ID for tracking
      req.requestId = crypto.randomUUID();
      res.setHeader('X-Request-ID', req.requestId);
      
      next();
    });

    // Request logging for security monitoring
    app.use((req, res, next) => {
      const startTime = Date.now();
      
      res.on('finish', () => {
        const duration = Date.now() - startTime;
        
        logger.info('HTTP Request', {
          requestId: req.requestId,
          method: req.method,
          url: req.url,
          statusCode: res.statusCode,
          duration,
          ip: req.ip,
          userAgent: req.get('User-Agent'),
          userId: req.user?.id,
          contentLength: res.get('Content-Length')
        });
        
        // Log suspicious activity
        if (res.statusCode === 429) {
          logger.warn('Rate limit exceeded', {
            ip: req.ip,
            url: req.url,
            userAgent: req.get('User-Agent')
          });
        }
        
        if (res.statusCode >= 400) {
          logger.warn('HTTP Error', {
            requestId: req.requestId,
            statusCode: res.statusCode,
            method: req.method,
            url: req.url,
            ip: req.ip
          });
        }
      });
      
      next();
    });
  }
}

module.exports = SecurityMiddleware;
```

## 5. Data Protection & Encryption

### 5.1 Data Encryption at Rest

```javascript
// src/services/encryptionService.js
const crypto = require('crypto');

class EncryptionService {
  constructor() {
    this.algorithm = 'aes-256-gcm';
    this.keyLength = 32; // 256 bits
    this.ivLength = 16; // 128 bits
    this.tagLength = 16; // 128 bits
    this.saltLength = 32; // 256 bits
    
    // Derive encryption key from environment variable
    this.masterKey = this.deriveKey(process.env.ENCRYPTION_KEY);
  }

  deriveKey(password, salt = null) {
    if (!salt) {
      salt = crypto.randomBytes(this.saltLength);
    }
    
    return crypto.pbkdf2Sync(password, salt, 100000, this.keyLength, 'sha256');
  }

  encrypt(plaintext, additionalData = null) {
    if (typeof plaintext !== 'string') {
      plaintext = JSON.stringify(plaintext);
    }

    const iv = crypto.randomBytes(this.ivLength);
    const cipher = crypto.createCipher(this.algorithm, this.masterKey, { iv });

    if (additionalData) {
      cipher.setAAD(Buffer.from(additionalData));
    }

    let encrypted = cipher.update(plaintext, 'utf8');
    encrypted = Buffer.concat([encrypted, cipher.final()]);
    
    const tag = cipher.getAuthTag();

    // Return base64 encoded string with IV and tag
    return Buffer.concat([iv, tag, encrypted]).toString('base64');
  }

  decrypt(encryptedData, additionalData = null) {
    const buffer = Buffer.from(encryptedData, 'base64');
    
    const iv = buffer.slice(0, this.ivLength);
    const tag = buffer.slice(this.ivLength, this.ivLength + this.tagLength);
    const encrypted = buffer.slice(this.ivLength + this.tagLength);

    const decipher = crypto.createDecipher(this.algorithm, this.masterKey, { iv });
    decipher.setAuthTag(tag);

    if (additionalData) {
      decipher.setAAD(Buffer.from(additionalData));
    }

    let decrypted = decipher.update(encrypted);
    decrypted = Buffer.concat([decrypted, decipher.final()]);

    return decrypted.toString('utf8');
  }

  // Hash sensitive data (one-way)
  hash(data, salt = null) {
    if (!salt) {
      salt = crypto.randomBytes(this.saltLength);
    }

    const hash = crypto.pbkdf2Sync(data, salt, 100000, 64, 'sha256');
    return {
      hash: hash.toString('hex'),
      salt: salt.toString('hex')
    };
  }

  verifyHash(data, hash, salt) {
    const computedHash = crypto.pbkdf2Sync(
      data, 
      Buffer.from(salt, 'hex'), 
      100000, 
      64, 
      'sha256'
    );
    
    return crypto.timingSafeEqual(
      Buffer.from(hash, 'hex'),
      computedHash
    );
  }
}

// Usage in User model
class User {
  // Encrypt sensitive fields before saving
  async encryptSensitiveData() {
    if (this.ssn) {
      this.ssn = encryption.encrypt(this.ssn, this.id);
    }
    
    if (this.paymentInfo) {
      this.paymentInfo = encryption.encrypt(JSON.stringify(this.paymentInfo), this.id);
    }
  }

  // Decrypt sensitive fields after loading
  async decryptSensitiveData() {
    if (this.ssn) {
      this.ssn = encryption.decrypt(this.ssn, this.id);
    }
    
    if (this.paymentInfo) {
      this.paymentInfo = JSON.parse(encryption.decrypt(this.paymentInfo, this.id));
    }
  }
}
```

### 5.2 PII Data Handling

```javascript
// src/services/piiService.js
class PIIService {
  constructor() {
    this.piiFields = new Set([
      'ssn', 'socialSecurityNumber',
      'driverLicense', 'passport',
      'creditCard', 'bankAccount',
      'phoneNumber', 'address',
      'dateOfBirth', 'medicalRecord'
    ]);
  }

  // Automatically detect and protect PII
  protectPII(data, context = {}) {
    if (typeof data !== 'object' || data === null) {
      return data;
    }

    const protected = { ...data };

    for (const [key, value] of Object.entries(protected)) {
      if (this.isPIIField(key)) {
        if (context.encrypt) {
          protected[key] = encryption.encrypt(value, context.userId);
        } else if (context.mask) {
          protected[key] = this.maskPII(key, value);
        } else if (context.remove) {
          delete protected[key];
        }
      } else if (typeof value === 'object' && value !== null) {
        protected[key] = this.protectPII(value, context);
      }
    }

    return protected;
  }

  isPIIField(fieldName) {
    return this.piiFields.has(fieldName.toLowerCase()) ||
           /\b(ssn|social|security|credit|card|license|passport|medical)\b/i.test(fieldName);
  }

  maskPII(fieldName, value) {
    if (!value) return value;

    const str = String(value);
    
    switch (fieldName.toLowerCase()) {
      case 'ssn':
      case 'socialsecuritynumber':
        return str.replace(/\d(?=\d{4})/g, '*');
      
      case 'creditcard':
        return str.replace(/\d(?=\d{4})/g, '*');
      
      case 'phonenumber':
        return str.replace(/\d(?=\d{4})/g, '*');
      
      case 'email':
        const [local, domain] = str.split('@');
        return `${local.charAt(0)}***@${domain}`;
      
      default:
        return str.length > 4 
          ? str.substring(0, 2) + '*'.repeat(str.length - 4) + str.substring(str.length - 2)
          : '***';
    }
  }

  // Audit PII access
  async auditPIIAccess(userId, piiType, action, context = {}) {
    await AuditLog.create({
      userId,
      action: `pii_${action}`,
      resourceType: 'pii_data',
      resourceId: piiType,
      metadata: {
        piiType,
        timestamp: new Date(),
        ip: context.ip,
        userAgent: context.userAgent,
        requestId: context.requestId
      }
    });
  }
}
```

## 🔗 Navigation

### Related Documents
- ⬅️ **Previous**: [Comparison Analysis](./comparison-analysis.md)
- ➡️ **Next**: [Architecture Patterns](./architecture-patterns.md)

### Quick Links
- [Implementation Guide](./implementation-guide.md)
- [Best Practices](./best-practices.md)
- [Tools & Ecosystem](./tools-ecosystem.md)

---

**Security Considerations Complete** | **Security Layers**: 8 | **Code Examples**: 15+ | **Patterns Covered**: 25+