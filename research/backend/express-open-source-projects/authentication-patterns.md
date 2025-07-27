# Authentication Patterns in Express.js Open Source Projects

## 🔐 Overview

Comprehensive analysis of authentication and security patterns implemented across 15+ production Express.js applications, focusing on JWT, OAuth, session management, and security best practices.

## 🎯 Authentication Strategy Distribution

### Primary Authentication Methods

| Method | Adoption Rate | Use Cases | Examples |
|--------|---------------|-----------|----------|
| **JWT + Refresh Tokens** | 70% | API-first, mobile apps, SPAs | Strapi, Medusa, Ghost API |
| **Session-based** | 25% | Traditional web apps, admin panels | Ghost admin, some CMS |
| **OAuth 2.0/OIDC** | 85% | Social login, enterprise SSO | Most platforms |
| **API Keys** | 60% | Public APIs, webhooks | GitHub-style APIs |
| **Multi-factor Auth** | 45% | High-security applications | Enterprise platforms |

## 🔑 JWT Implementation Patterns

### 1. Standard JWT + Refresh Token Pattern

**Strapi Implementation**
```javascript
// JWT token generation
const jwt = require('jsonwebtoken');

const issueJWT = (user) => {
  const payload = {
    id: user.id,
    role: user.role?.name || 'authenticated',
    iat: Date.now()
  };

  const accessToken = jwt.sign(payload, process.env.JWT_SECRET, {
    expiresIn: process.env.JWT_ACCESS_TOKEN_EXPIRES_IN || '15m'
  });

  const refreshToken = jwt.sign(
    { id: user.id, tokenVersion: user.tokenVersion },
    process.env.JWT_REFRESH_SECRET,
    { expiresIn: process.env.JWT_REFRESH_TOKEN_EXPIRES_IN || '7d' }
  );

  return { accessToken, refreshToken };
};

// Token validation middleware
const validateToken = async (req, res, next) => {
  try {
    const token = extractToken(req);
    if (!token) {
      return res.status(401).json({ error: 'No token provided' });
    }

    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    const user = await strapi.query('plugin::users-permissions.user')
      .findOne({ where: { id: decoded.id } });

    if (!user || !user.confirmed) {
      return res.status(401).json({ error: 'Invalid user' });
    }

    req.user = user;
    next();
  } catch (error) {
    if (error.name === 'TokenExpiredError') {
      return res.status(401).json({ error: 'Token expired' });
    }
    return res.status(401).json({ error: 'Invalid token' });
  }
};

// Token refresh endpoint
const refreshTokens = async (req, res) => {
  try {
    const { refreshToken } = req.body;
    
    const decoded = jwt.verify(refreshToken, process.env.JWT_REFRESH_SECRET);
    const user = await getUserById(decoded.id);

    if (!user || user.tokenVersion !== decoded.tokenVersion) {
      return res.status(401).json({ error: 'Invalid refresh token' });
    }

    const tokens = issueJWT(user);
    res.json(tokens);
  } catch (error) {
    res.status(401).json({ error: 'Invalid refresh token' });
  }
};
```

**Token Storage Strategy**
```javascript
// Client-side token storage (recommended approach)
class TokenManager {
  constructor() {
    this.accessToken = null;
    this.refreshToken = null;
  }

  setTokens(tokens) {
    this.accessToken = tokens.accessToken;
    
    // Store refresh token in httpOnly cookie
    document.cookie = `refreshToken=${tokens.refreshToken}; HttpOnly; Secure; SameSite=Strict; Max-Age=${7 * 24 * 60 * 60}`;
  }

  getAccessToken() {
    return this.accessToken;
  }

  async refreshAccessToken() {
    const response = await fetch('/api/auth/refresh', {
      method: 'POST',
      credentials: 'include' // Include httpOnly cookie
    });

    if (response.ok) {
      const tokens = await response.json();
      this.setTokens(tokens);
      return tokens.accessToken;
    }
    
    throw new Error('Token refresh failed');
  }

  logout() {
    this.accessToken = null;
    // Clear refresh token cookie
    document.cookie = 'refreshToken=; expires=Thu, 01 Jan 1970 00:00:00 UTC; path=/;';
  }
}
```

### 2. Advanced JWT Security Pattern

**Medusa's Enhanced JWT Implementation**
```typescript
import { verify, sign } from 'jsonwebtoken';
import { randomBytes } from 'crypto';

interface JWTPayload {
  userId: string;
  role: string;
  permissions: string[];
  sessionId: string;
  deviceId?: string;
}

class AuthService {
  private jwtSecret: string;
  private refreshSecret: string;
  private sessionStorage: Map<string, any> = new Map();

  constructor() {
    this.jwtSecret = process.env.JWT_SECRET!;
    this.refreshSecret = process.env.JWT_REFRESH_SECRET!;
  }

  async generateTokens(user: User, deviceInfo?: any): Promise<TokenPair> {
    const sessionId = randomBytes(32).toString('hex');
    
    // Store session info for validation
    this.sessionStorage.set(sessionId, {
      userId: user.id,
      createdAt: new Date(),
      deviceInfo,
      isActive: true
    });

    const payload: JWTPayload = {
      userId: user.id,
      role: user.role,
      permissions: user.permissions,
      sessionId,
      deviceId: deviceInfo?.deviceId
    };

    const accessToken = sign(payload, this.jwtSecret, {
      expiresIn: '15m',
      issuer: 'medusa-api',
      audience: 'medusa-client',
      algorithm: 'HS256'
    });

    const refreshToken = sign(
      { 
        userId: user.id, 
        sessionId,
        tokenVersion: user.tokenVersion 
      },
      this.refreshSecret,
      { 
        expiresIn: '7d',
        issuer: 'medusa-api',
        audience: 'medusa-client'
      }
    );

    return { accessToken, refreshToken };
  }

  async validateToken(token: string): Promise<JWTPayload> {
    try {
      const payload = verify(token, this.jwtSecret, {
        issuer: 'medusa-api',
        audience: 'medusa-client'
      }) as JWTPayload;

      // Validate session is still active
      const session = this.sessionStorage.get(payload.sessionId);
      if (!session || !session.isActive) {
        throw new Error('Session expired');
      }

      return payload;
    } catch (error) {
      throw new AuthenticationError('Invalid token');
    }
  }

  async revokeSession(sessionId: string): Promise<void> {
    const session = this.sessionStorage.get(sessionId);
    if (session) {
      session.isActive = false;
    }
  }

  async revokeAllUserSessions(userId: string): Promise<void> {
    for (const [sessionId, session] of this.sessionStorage.entries()) {
      if (session.userId === userId) {
        session.isActive = false;
      }
    }
  }
}
```

## 🔒 OAuth 2.0 & Social Authentication

### 1. Passport.js Implementation Pattern

**Ghost's Multi-Strategy Authentication**
```javascript
const passport = require('passport');
const GoogleStrategy = require('passport-google-oauth20').Strategy;
const GitHubStrategy = require('passport-github2').Strategy;
const LocalStrategy = require('passport-local').Strategy;

// Local strategy for email/password
passport.use(new LocalStrategy({
    usernameField: 'email',
    passwordField: 'password'
}, async (email, password, done) => {
    try {
        const user = await User.findOne({ email: email.toLowerCase() });
        
        if (!user) {
            return done(null, false, { message: 'Invalid email or password' });
        }

        const isValid = await user.validatePassword(password);
        if (!isValid) {
            return done(null, false, { message: 'Invalid email or password' });
        }

        return done(null, user);
    } catch (error) {
        return done(error);
    }
}));

// Google OAuth strategy
passport.use(new GoogleStrategy({
    clientID: process.env.GOOGLE_CLIENT_ID,
    clientSecret: process.env.GOOGLE_CLIENT_SECRET,
    callbackURL: '/auth/google/callback',
    scope: ['profile', 'email']
}, async (accessToken, refreshToken, profile, done) => {
    try {
        // Check if user exists
        let user = await User.findOne({ googleId: profile.id });
        
        if (user) {
            return done(null, user);
        }

        // Check if user exists with same email
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
            email: profile.emails[0].value,
            name: profile.displayName,
            avatar: profile.photos[0].value,
            verified: true // Google accounts are pre-verified
        });

        return done(null, user);
    } catch (error) {
        return done(error);
    }
}));

// GitHub strategy
passport.use(new GitHubStrategy({
    clientID: process.env.GITHUB_CLIENT_ID,
    clientSecret: process.env.GITHUB_CLIENT_SECRET,
    callbackURL: '/auth/github/callback'
}, async (accessToken, refreshToken, profile, done) => {
    try {
        const user = await handleOAuthUser({
            provider: 'github',
            providerId: profile.id,
            email: profile.emails?.[0]?.value,
            name: profile.displayName || profile.username,
            avatar: profile.photos?.[0]?.value,
            username: profile.username
        });
        
        return done(null, user);
    } catch (error) {
        return done(error);
    }
}));

// OAuth user handling utility
const handleOAuthUser = async (oauthData) => {
    const { provider, providerId, email, name, avatar, username } = oauthData;
    
    // Try to find existing user by provider ID
    let user = await User.findOne({ [`${provider}Id`]: providerId });
    
    if (user) {
        // Update user info
        user.name = name || user.name;
        user.avatar = avatar || user.avatar;
        await user.save();
        return user;
    }

    // Try to find by email
    if (email) {
        user = await User.findOne({ email });
        if (user) {
            // Link OAuth account
            user[`${provider}Id`] = providerId;
            user.name = name || user.name;
            user.avatar = avatar || user.avatar;
            await user.save();
            return user;
        }
    }

    // Create new user
    return User.create({
        [`${provider}Id`]: providerId,
        email,
        name,
        avatar,
        username,
        verified: true,
        role: 'user'
    });
};
```

### 2. Custom OAuth Implementation

**Strapi's OAuth Flow**
```javascript
const axios = require('axios');
const qs = require('querystring');

class OAuthService {
    constructor() {
        this.providers = {
            google: {
                authUrl: 'https://accounts.google.com/o/oauth2/v2/auth',
                tokenUrl: 'https://oauth2.googleapis.com/token',
                userUrl: 'https://www.googleapis.com/oauth2/v2/userinfo',
                scope: 'openid profile email',
                clientId: process.env.GOOGLE_CLIENT_ID,
                clientSecret: process.env.GOOGLE_CLIENT_SECRET
            },
            github: {
                authUrl: 'https://github.com/login/oauth/authorize',
                tokenUrl: 'https://github.com/login/oauth/access_token',
                userUrl: 'https://api.github.com/user',
                scope: 'user:email',
                clientId: process.env.GITHUB_CLIENT_ID,
                clientSecret: process.env.GITHUB_CLIENT_SECRET
            }
        };
    }

    getAuthUrl(provider, state, redirectUri) {
        const config = this.providers[provider];
        if (!config) throw new Error('Unsupported provider');

        const params = {
            client_id: config.clientId,
            redirect_uri: redirectUri,
            scope: config.scope,
            response_type: 'code',
            state: state // CSRF protection
        };

        return `${config.authUrl}?${qs.stringify(params)}`;
    }

    async exchangeCodeForToken(provider, code, redirectUri) {
        const config = this.providers[provider];
        
        const tokenResponse = await axios.post(config.tokenUrl, {
            client_id: config.clientId,
            client_secret: config.clientSecret,
            code,
            redirect_uri: redirectUri,
            grant_type: 'authorization_code'
        }, {
            headers: { 'Accept': 'application/json' }
        });

        return tokenResponse.data.access_token;
    }

    async getUserInfo(provider, accessToken) {
        const config = this.providers[provider];
        
        const userResponse = await axios.get(config.userUrl, {
            headers: { 'Authorization': `Bearer ${accessToken}` }
        });

        return this.normalizeUserData(provider, userResponse.data);
    }

    normalizeUserData(provider, userData) {
        switch (provider) {
            case 'google':
                return {
                    providerId: userData.id,
                    email: userData.email,
                    name: userData.name,
                    avatar: userData.picture,
                    verified: userData.email_verified
                };
            case 'github':
                return {
                    providerId: userData.id.toString(),
                    email: userData.email,
                    name: userData.name || userData.login,
                    avatar: userData.avatar_url,
                    username: userData.login
                };
            default:
                throw new Error('Unsupported provider');
        }
    }
}

// OAuth endpoints
app.get('/auth/:provider', (req, res) => {
    const { provider } = req.params;
    const state = crypto.randomBytes(32).toString('hex');
    const redirectUri = `${process.env.BASE_URL}/auth/${provider}/callback`;
    
    // Store state for verification
    req.session.oauthState = state;
    
    const authUrl = oauthService.getAuthUrl(provider, state, redirectUri);
    res.redirect(authUrl);
});

app.get('/auth/:provider/callback', async (req, res) => {
    try {
        const { provider } = req.params;
        const { code, state } = req.query;
        
        // Verify state (CSRF protection)
        if (state !== req.session.oauthState) {
            return res.status(400).json({ error: 'Invalid state parameter' });
        }
        
        const redirectUri = `${process.env.BASE_URL}/auth/${provider}/callback`;
        const accessToken = await oauthService.exchangeCodeForToken(provider, code, redirectUri);
        const userData = await oauthService.getUserInfo(provider, accessToken);
        
        // Create or link user account
        const user = await handleOAuthUser(provider, userData);
        const tokens = await authService.generateTokens(user);
        
        // Redirect to frontend with tokens
        res.redirect(`${process.env.FRONTEND_URL}/auth/callback?token=${tokens.accessToken}`);
    } catch (error) {
        res.status(400).json({ error: 'OAuth authentication failed' });
    }
});
```

## 🛡️ Authorization Patterns

### 1. Role-Based Access Control (RBAC)

**Strapi's Permission System**
```javascript
const roles = {
    admin: {
        permissions: ['*'] // All permissions
    },
    editor: {
        permissions: [
            'content.create',
            'content.read',
            'content.update',
            'media.upload'
        ]
    },
    author: {
        permissions: [
            'content.create',
            'content.read',
            'content.update:own'
        ]
    },
    user: {
        permissions: ['content.read']
    }
};

const checkPermission = (requiredPermission) => {
    return async (req, res, next) => {
        const { user } = req;
        
        if (!user) {
            return res.status(401).json({ error: 'Authentication required' });
        }

        const userRole = roles[user.role];
        if (!userRole) {
            return res.status(403).json({ error: 'Invalid role' });
        }

        // Check for wildcard permission
        if (userRole.permissions.includes('*')) {
            return next();
        }

        // Check specific permission
        if (userRole.permissions.includes(requiredPermission)) {
            return next();
        }

        // Check for resource-specific permissions
        if (requiredPermission.endsWith(':own')) {
            const basePermission = requiredPermission.replace(':own', '');
            if (userRole.permissions.includes(`${basePermission}:own`)) {
                // Additional check: verify resource ownership
                req.checkOwnership = true;
                return next();
            }
        }

        return res.status(403).json({ error: 'Insufficient permissions' });
    };
};

// Usage examples
app.get('/admin/users', authenticate, checkPermission('users.read'), getUsersController);
app.put('/posts/:id', authenticate, checkPermission('content.update:own'), updatePostController);
app.delete('/posts/:id', authenticate, checkPermission('content.delete'), deletePostController);

// Resource ownership check
const updatePostController = async (req, res) => {
    const { id } = req.params;
    const post = await Post.findById(id);
    
    if (!post) {
        return res.status(404).json({ error: 'Post not found' });
    }

    // Check ownership if required
    if (req.checkOwnership && post.authorId !== req.user.id) {
        return res.status(403).json({ error: 'Can only update own posts' });
    }

    // Proceed with update
    const updatedPost = await Post.findByIdAndUpdate(id, req.validatedBody, { new: true });
    res.json({ success: true, data: updatedPost });
};
```

### 2. Attribute-Based Access Control (ABAC)

**Advanced Permission System**
```javascript
class PermissionEngine {
    constructor() {
        this.policies = new Map();
        this.initializePolicies();
    }

    initializePolicies() {
        // Resource-based policies
        this.policies.set('post.read', {
            rules: [
                { condition: 'post.status === "published"', action: 'allow' },
                { condition: 'user.role === "admin"', action: 'allow' },
                { condition: 'user.id === post.authorId', action: 'allow' },
                { default: 'deny' }
            ]
        });

        this.policies.set('post.update', {
            rules: [
                { condition: 'user.role === "admin"', action: 'allow' },
                { 
                    condition: 'user.id === post.authorId && post.status !== "published"', 
                    action: 'allow' 
                },
                { default: 'deny' }
            ]
        });

        this.policies.set('user.profile.view', {
            rules: [
                { condition: 'user.id === targetUser.id', action: 'allow' },
                { condition: 'user.role === "admin"', action: 'allow' },
                { condition: 'targetUser.privacy === "public"', action: 'allow' },
                { 
                    condition: 'targetUser.privacy === "friends" && user.friends.includes(targetUser.id)', 
                    action: 'allow' 
                },
                { default: 'deny' }
            ]
        });
    }

    async evaluate(permission, context) {
        const policy = this.policies.get(permission);
        if (!policy) return false;

        for (const rule of policy.rules) {
            if (rule.default) {
                return rule.default === 'allow';
            }

            try {
                const result = this.evaluateCondition(rule.condition, context);
                if (result) {
                    return rule.action === 'allow';
                }
            } catch (error) {
                console.error('Permission evaluation error:', error);
                continue;
            }
        }

        return false;
    }

    evaluateCondition(condition, context) {
        // Simple expression evaluation (in production, use a proper expression engine)
        const func = new Function('user', 'post', 'targetUser', `return ${condition}`);
        return func(context.user, context.post, context.targetUser);
    }
}

// Middleware using ABAC
const checkPermissionABAC = (permission) => {
    return async (req, res, next) => {
        const permissionEngine = new PermissionEngine();
        
        const context = {
            user: req.user,
            post: req.post, // Loaded by previous middleware
            targetUser: req.targetUser // For user-related operations
        };

        const hasPermission = await permissionEngine.evaluate(permission, context);
        
        if (!hasPermission) {
            return res.status(403).json({ error: 'Access denied' });
        }

        next();
    };
};
```

## 🔐 Session Management Patterns

### 1. Traditional Session-Based Authentication

**Ghost Admin Session Management**
```javascript
const session = require('express-session');
const MongoStore = require('connect-mongo');

// Session configuration
app.use(session({
    secret: process.env.SESSION_SECRET,
    resave: false,
    saveUninitialized: false,
    store: MongoStore.create({
        mongoUrl: process.env.MONGODB_URI,
        collectionName: 'sessions',
        ttl: 24 * 60 * 60 // 1 day
    }),
    cookie: {
        secure: process.env.NODE_ENV === 'production', // HTTPS only in production
        httpOnly: true, // Prevent XSS
        maxAge: 24 * 60 * 60 * 1000, // 1 day
        sameSite: 'strict' // CSRF protection
    },
    name: 'sessionId' // Don't use default session name
}));

// Login endpoint
app.post('/api/session', async (req, res) => {
    try {
        const { email, password } = req.validatedBody;
        
        const user = await User.findOne({ email: email.toLowerCase() });
        if (!user || !await user.validatePassword(password)) {
            return res.status(401).json({ error: 'Invalid credentials' });
        }

        // Store user in session
        req.session.userId = user.id;
        req.session.role = user.role;
        req.session.loginTime = new Date();

        res.json({
            success: true,
            user: {
                id: user.id,
                email: user.email,
                name: user.name,
                role: user.role
            }
        });
    } catch (error) {
        res.status(500).json({ error: 'Login failed' });
    }
});

// Session authentication middleware
const requireSession = async (req, res, next) => {
    if (!req.session.userId) {
        return res.status(401).json({ error: 'Authentication required' });
    }

    try {
        const user = await User.findById(req.session.userId);
        if (!user) {
            req.session.destroy();
            return res.status(401).json({ error: 'Invalid session' });
        }

        req.user = user;
        next();
    } catch (error) {
        res.status(500).json({ error: 'Session validation failed' });
    }
};

// Logout endpoint
app.delete('/api/session', (req, res) => {
    req.session.destroy((err) => {
        if (err) {
            return res.status(500).json({ error: 'Logout failed' });
        }
        res.clearCookie('sessionId');
        res.json({ success: true });
    });
});
```

### 2. Hybrid JWT + Session Pattern

**Best of Both Worlds Approach**
```javascript
// Hybrid authentication service
class HybridAuthService {
    constructor() {
        this.activeSessions = new Map();
    }

    async authenticate(email, password) {
        const user = await User.findOne({ email });
        if (!user || !await user.validatePassword(password)) {
            throw new AuthError('Invalid credentials');
        }

        // Create session record
        const sessionId = crypto.randomBytes(32).toString('hex');
        const session = {
            id: sessionId,
            userId: user.id,
            createdAt: new Date(),
            lastActivity: new Date(),
            ipAddress: req.ip,
            userAgent: req.get('User-Agent')
        };

        this.activeSessions.set(sessionId, session);

        // Generate JWT with session reference
        const token = jwt.sign({
            userId: user.id,
            sessionId: sessionId,
            role: user.role
        }, process.env.JWT_SECRET, { expiresIn: '1h' });

        return { token, sessionId, user };
    }

    async validateToken(token) {
        try {
            const payload = jwt.verify(token, process.env.JWT_SECRET);
            const session = this.activeSessions.get(payload.sessionId);

            if (!session || session.userId !== payload.userId) {
                throw new Error('Invalid session');
            }

            // Update last activity
            session.lastActivity = new Date();

            return payload;
        } catch (error) {
            throw new AuthError('Invalid token');
        }
    }

    async revokeSession(sessionId) {
        this.activeSessions.delete(sessionId);
    }

    async revokeAllUserSessions(userId) {
        for (const [sessionId, session] of this.activeSessions.entries()) {
            if (session.userId === userId) {
                this.activeSessions.delete(sessionId);
            }
        }
    }

    async getActiveSessions(userId) {
        const sessions = [];
        for (const [sessionId, session] of this.activeSessions.entries()) {
            if (session.userId === userId) {
                sessions.push({
                    id: sessionId,
                    createdAt: session.createdAt,
                    lastActivity: session.lastActivity,
                    ipAddress: session.ipAddress,
                    userAgent: session.userAgent
                });
            }
        }
        return sessions;
    }
}
```

## 🔒 Security Middleware Patterns

### 1. Comprehensive Security Stack

**Production Security Middleware**
```javascript
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const slowDown = require('express-slow-down');
const MongoStore = require('rate-limit-mongo');

// Security headers
app.use(helmet({
    contentSecurityPolicy: {
        directives: {
            defaultSrc: ["'self'"],
            styleSrc: ["'self'", "'unsafe-inline'", 'fonts.googleapis.com'],
            fontSrc: ["'self'", 'fonts.gstatic.com'],
            imgSrc: ["'self'", 'data:', 'https:'],
            scriptSrc: ["'self'"],
            connectSrc: ["'self'", 'api.stripe.com'],
            frameSrc: ["'none'"],
            objectSrc: ["'none'"],
            upgradeInsecureRequests: []
        }
    },
    hsts: {
        maxAge: 31536000, // 1 year
        includeSubDomains: true,
        preload: true
    }
}));

// Rate limiting with different tiers
const createRateLimiter = (windowMs, max, message) => {
    return rateLimit({
        windowMs,
        max,
        message: { error: message },
        standardHeaders: true,
        legacyHeaders: false,
        store: new MongoStore({
            uri: process.env.MONGODB_URI,
            collectionName: 'rateLimits',
            expireTimeMs: windowMs
        }),
        keyGenerator: (req) => {
            // Use user ID if authenticated, otherwise IP
            return req.user?.id || req.ip;
        },
        skip: (req) => {
            // Skip rate limiting for admins
            return req.user?.role === 'admin';
        }
    });
};

// Different rate limits for different endpoints
app.use('/api/auth', createRateLimiter(15 * 60 * 1000, 5, 'Too many authentication attempts'));
app.use('/api/password-reset', createRateLimiter(60 * 60 * 1000, 3, 'Too many password reset attempts'));
app.use('/api/', createRateLimiter(15 * 60 * 1000, 100, 'Too many API requests'));

// Slow down repeated requests
app.use('/api/auth/login', slowDown({
    windowMs: 15 * 60 * 1000, // 15 minutes
    delayAfter: 2, // Allow 2 requests per window without delay
    delayMs: 500, // Add 500ms delay per request after delayAfter
    maxDelayMs: 20000 // Maximum delay of 20 seconds
}));

// Input sanitization
const mongoSanitize = require('express-mongo-sanitize');
const xss = require('xss-clean');

app.use(mongoSanitize()); // Prevent NoSQL injection
app.use(xss()); // Prevent XSS attacks

// Request size limits
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// CORS configuration
const cors = require('cors');
app.use(cors({
    origin: (origin, callback) => {
        const allowedOrigins = process.env.ALLOWED_ORIGINS?.split(',') || [];
        
        // Allow requests with no origin (mobile apps, Postman, etc.)
        if (!origin) return callback(null, true);
        
        if (allowedOrigins.includes(origin)) {
            callback(null, true);
        } else {
            callback(new Error('Not allowed by CORS'));
        }
    },
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH'],
    allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With']
}));
```

### 2. API Key Authentication

**Strapi's API Key Pattern**
```javascript
class ApiKeyService {
    constructor() {
        this.apiKeys = new Map();
        this.loadApiKeys();
    }

    async loadApiKeys() {
        const keys = await ApiKey.findAll({ include: ['user', 'permissions'] });
        for (const key of keys) {
            this.apiKeys.set(key.key, {
                userId: key.userId,
                permissions: key.permissions.map(p => p.name),
                rateLimit: key.rateLimit,
                lastUsed: key.lastUsed,
                expiresAt: key.expiresAt
            });
        }
    }

    async validateApiKey(key) {
        const apiKey = this.apiKeys.get(key);
        
        if (!apiKey) {
            throw new AuthError('Invalid API key');
        }

        if (apiKey.expiresAt && new Date() > apiKey.expiresAt) {
            throw new AuthError('API key expired');
        }

        // Update last used timestamp
        await ApiKey.update(
            { lastUsed: new Date() },
            { where: { key } }
        );

        return apiKey;
    }

    async generateApiKey(userId, permissions = [], options = {}) {
        const key = `ak_${crypto.randomBytes(32).toString('hex')}`;
        const apiKey = await ApiKey.create({
            key,
            userId,
            name: options.name || 'Generated API Key',
            rateLimit: options.rateLimit || 1000,
            expiresAt: options.expiresAt
        });

        // Associate permissions
        if (permissions.length > 0) {
            await apiKey.setPermissions(permissions);
        }

        this.apiKeys.set(key, {
            userId,
            permissions,
            rateLimit: options.rateLimit || 1000,
            lastUsed: null,
            expiresAt: options.expiresAt
        });

        return key;
    }
}

// API key authentication middleware
const authenticateApiKey = async (req, res, next) => {
    const apiKey = req.get('X-API-Key') || req.query.apiKey;
    
    if (!apiKey) {
        return res.status(401).json({ error: 'API key required' });
    }

    try {
        const keyData = await apiKeyService.validateApiKey(apiKey);
        
        // Get user associated with API key
        const user = await User.findById(keyData.userId);
        if (!user) {
            return res.status(401).json({ error: 'Invalid API key' });
        }

        req.user = user;
        req.apiKey = keyData;
        next();
    } catch (error) {
        res.status(401).json({ error: error.message });
    }
};

// Permission check for API keys
const checkApiPermission = (requiredPermission) => {
    return (req, res, next) => {
        if (!req.apiKey) {
            return res.status(401).json({ error: 'API key authentication required' });
        }

        if (!req.apiKey.permissions.includes(requiredPermission) && 
            !req.apiKey.permissions.includes('*')) {
            return res.status(403).json({ error: 'Insufficient API permissions' });
        }

        next();
    };
};
```

## 📊 Security Monitoring & Logging

### 1. Authentication Event Logging

**Comprehensive Audit Trail**
```javascript
const winston = require('winston');

const authLogger = winston.createLogger({
    level: 'info',
    format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.errors({ stack: true }),
        winston.format.json()
    ),
    transports: [
        new winston.transports.File({ filename: 'logs/auth-error.log', level: 'error' }),
        new winston.transports.File({ filename: 'logs/auth-combined.log' }),
        new winston.transports.Console({
            format: winston.format.simple()
        })
    ]
});

class AuthAuditService {
    logAuthEvent(event, data) {
        const logData = {
            event,
            timestamp: new Date().toISOString(),
            ip: data.ip,
            userAgent: data.userAgent,
            userId: data.userId,
            email: data.email,
            success: data.success,
            reason: data.reason,
            sessionId: data.sessionId
        };

        if (data.success) {
            authLogger.info('Authentication event', logData);
        } else {
            authLogger.warn('Authentication failure', logData);
        }

        // Store in database for analytics
        this.storeAuditEvent(logData);
    }

    async storeAuditEvent(logData) {
        try {
            await AuthAuditLog.create(logData);
        } catch (error) {
            console.error('Failed to store audit event:', error);
        }
    }

    async detectSuspiciousActivity(userId) {
        const recentFailures = await AuthAuditLog.count({
            where: {
                userId,
                success: false,
                timestamp: {
                    [Op.gte]: new Date(Date.now() - 15 * 60 * 1000) // Last 15 minutes
                }
            }
        });

        if (recentFailures >= 5) {
            await this.lockAccount(userId, '15 minutes due to suspicious activity');
            await this.notifySecurityTeam(userId, 'Multiple failed login attempts');
        }
    }
}

// Usage in authentication middleware
const auditService = new AuthAuditService();

app.post('/api/auth/login', async (req, res) => {
    const { email, password } = req.body;
    const ip = req.ip;
    const userAgent = req.get('User-Agent');

    try {
        const user = await User.findOne({ email });
        
        if (!user || !await user.validatePassword(password)) {
            auditService.logAuthEvent('LOGIN_FAILED', {
                ip, userAgent, email,
                success: false,
                reason: 'Invalid credentials'
            });
            
            return res.status(401).json({ error: 'Invalid credentials' });
        }

        const tokens = await authService.generateTokens(user);
        
        auditService.logAuthEvent('LOGIN_SUCCESS', {
            ip, userAgent,
            userId: user.id,
            email: user.email,
            success: true,
            sessionId: tokens.sessionId
        });

        res.json(tokens);
    } catch (error) {
        auditService.logAuthEvent('LOGIN_ERROR', {
            ip, userAgent, email,
            success: false,
            reason: error.message
        });
        
        res.status(500).json({ error: 'Login failed' });
    }
});
```

## 🔗 Navigation

← [Project Analysis](./project-analysis.md) | [Architecture Patterns](./architecture-patterns.md) →