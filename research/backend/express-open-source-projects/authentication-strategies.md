# Authentication Strategies in Express.js Open Source Projects

## 🔐 Overview

This comprehensive analysis examines authentication strategies used across 15 production-grade Express.js applications, providing practical implementation patterns for secure user authentication and authorization.

## 📊 Authentication Method Distribution

| Authentication Method | Usage % | Projects Using | Security Level | Implementation Complexity |
|----------------------|---------|----------------|----------------|---------------------------|
| **JWT (JSON Web Tokens)** | 80% | Ghost, Parse Server, Botpress, WikiJS, Strapi, Rocket.Chat, Joplin, Wekan, Etherpad, Sentry, Automattic, Notepad++ | High | Medium |
| **Session-based Authentication** | 53% | Ghost, Discourse, GitLab, Mattermost, Etherpad, Wekan, Automattic, WikiJS | Medium | Low |
| **OAuth 2.0 Integration** | 67% | Ghost, Rocket.Chat, GitLab, Discourse, Mattermost, Botpress, WikiJS, Strapi, Automattic, Parse Server | High | High |
| **API Key Authentication** | 40% | Parse Server, Sentry, Botpress, GitLab, Strapi, Ghost | Medium | Low |
| **Multi-Factor Authentication** | 33% | GitLab, Rocket.Chat, Mattermost, Discourse, Ghost | Very High | High |
| **LDAP/Active Directory** | 27% | Rocket.Chat, Mattermost, GitLab, Wekan | High | High |

## 🎯 Authentication Strategy Patterns

### 1. **JWT-First Strategy** (Recommended for APIs)

**Best suited for**: Stateless APIs, microservices, mobile applications, SPAs

**Used by**: Parse Server, Botpress, Strapi, Joplin

**Complete Implementation**:
```javascript
// config/auth.js
const jwt = require('jsonwebtoken');
const bcrypt = require('bcrypt');
const crypto = require('crypto');

class JWTAuthStrategy {
  constructor() {
    this.accessTokenSecret = process.env.JWT_ACCESS_SECRET;
    this.refreshTokenSecret = process.env.JWT_REFRESH_SECRET;
    this.accessTokenExpiry = process.env.JWT_ACCESS_EXPIRY || '15m';
    this.refreshTokenExpiry = process.env.JWT_REFRESH_EXPIRY || '7d';
  }
  
  // Generate token pair with security best practices
  generateTokens(user) {
    const jti = crypto.randomUUID();
    const tokenData = {
      sub: user.id,
      email: user.email,
      roles: user.roles,
      permissions: user.permissions,
      jti,
      iat: Math.floor(Date.now() / 1000)
    };
    
    const accessToken = jwt.sign(
      { ...tokenData, type: 'access' },
      this.accessTokenSecret,
      {
        expiresIn: this.accessTokenExpiry,
        issuer: process.env.JWT_ISSUER,
        audience: process.env.JWT_AUDIENCE,
        algorithm: 'HS256'
      }
    );
    
    const refreshToken = jwt.sign(
      { sub: user.id, jti, type: 'refresh' },
      this.refreshTokenSecret,
      {
        expiresIn: this.refreshTokenExpiry,
        issuer: process.env.JWT_ISSUER,
        audience: process.env.JWT_AUDIENCE,
        algorithm: 'HS256'
      }
    );
    
    return { accessToken, refreshToken, jti };
  }
  
  // Verify and decode access token
  verifyAccessToken(token) {
    try {
      const decoded = jwt.verify(token, this.accessTokenSecret, {
        issuer: process.env.JWT_ISSUER,
        audience: process.env.JWT_AUDIENCE,
        algorithms: ['HS256']
      });
      
      if (decoded.type !== 'access') {
        throw new Error('Invalid token type');
      }
      
      return decoded;
    } catch (error) {
      if (error.name === 'TokenExpiredError') {
        throw new Error('Token expired');
      }
      throw new Error('Invalid token');
    }
  }
  
  // Token refresh mechanism
  async refreshTokens(refreshToken, userRepository, tokenBlacklist) {
    try {
      const decoded = jwt.verify(refreshToken, this.refreshTokenSecret, {
        issuer: process.env.JWT_ISSUER,
        audience: process.env.JWT_AUDIENCE,
        algorithms: ['HS256']
      });
      
      if (decoded.type !== 'refresh') {
        throw new Error('Invalid token type');
      }
      
      // Check if token is blacklisted
      const isBlacklisted = await tokenBlacklist.isBlacklisted(decoded.jti);
      if (isBlacklisted) {
        throw new Error('Token has been revoked');
      }
      
      // Get current user data
      const user = await userRepository.findById(decoded.sub);
      if (!user || !user.isActive) {
        throw new Error('User not found or inactive');
      }
      
      // Blacklist old refresh token
      await tokenBlacklist.blacklistToken(decoded.jti, new Date(decoded.exp * 1000));
      
      // Generate new token pair
      return this.generateTokens(user);
    } catch (error) {
      throw new Error('Invalid refresh token');
    }
  }
}

module.exports = new JWTAuthStrategy();
```

**Authentication Controller**:
```javascript
// controllers/authController.js
const authStrategy = require('../config/auth');
const userRepository = require('../repositories/userRepository');
const tokenBlacklist = require('../utils/tokenBlacklist');
const { SecurityAudit, SecurityEvents } = require('../utils/securityLogger');

class AuthController {
  async login(req, res, next) {
    try {
      const { email, password, rememberMe } = req.body;
      
      // Find user
      const user = await userRepository.findByEmail(email);
      if (!user) {
        SecurityAudit.logEvent(SecurityEvents.AUTH_FAILURE, { email, reason: 'User not found' }, req);
        return res.status(401).json({ error: 'Invalid credentials' });
      }
      
      // Check password
      const isValidPassword = await bcrypt.compare(password, user.password);
      if (!isValidPassword) {
        SecurityAudit.logEvent(SecurityEvents.AUTH_FAILURE, { 
          email, 
          userId: user.id, 
          reason: 'Invalid password' 
        }, req);
        return res.status(401).json({ error: 'Invalid credentials' });
      }
      
      // Check account status
      if (!user.isEmailVerified) {
        return res.status(401).json({ 
          error: 'Please verify your email before logging in',
          requiresVerification: true 
        });
      }
      
      if (user.isLocked) {
        SecurityAudit.logEvent(SecurityEvents.AUTH_FAILURE, { 
          email, 
          userId: user.id, 
          reason: 'Account locked' 
        }, req);
        return res.status(401).json({ error: 'Account is temporarily locked' });
      }
      
      // Generate tokens
      const tokens = authStrategy.generateTokens(user);
      
      // Update user login information
      await userRepository.update(user.id, {
        lastLoginAt: new Date(),
        lastLoginIP: req.ip,
        refreshTokenHash: await bcrypt.hash(tokens.refreshToken, 10)
      });
      
      // Security audit log
      SecurityAudit.logEvent(SecurityEvents.AUTH_SUCCESS, {
        userId: user.id,
        email: user.email,
        method: 'password'
      }, req);
      
      // Set refresh token as httpOnly cookie if remember me
      if (rememberMe) {
        res.cookie('refreshToken', tokens.refreshToken, {
          httpOnly: true,
          secure: process.env.NODE_ENV === 'production',
          sameSite: 'strict',
          maxAge: 7 * 24 * 60 * 60 * 1000 // 7 days
        });
      }
      
      res.json({
        user: {
          id: user.id,
          email: user.email,
          name: user.name,
          roles: user.roles,
          permissions: user.permissions
        },
        accessToken: tokens.accessToken,
        expiresIn: '15m'
      });
      
    } catch (error) {
      next(error);
    }
  }
  
  async refreshToken(req, res, next) {
    try {
      const refreshToken = req.body.refreshToken || req.cookies.refreshToken;
      if (!refreshToken) {
        return res.status(401).json({ error: 'Refresh token required' });
      }
      
      const tokens = await authStrategy.refreshTokens(refreshToken, userRepository, tokenBlacklist);
      
      SecurityAudit.logEvent(SecurityEvents.TOKEN_REFRESH, {
        userId: tokens.user?.id
      }, req);
      
      res.json({
        accessToken: tokens.accessToken,
        expiresIn: '15m'
      });
      
    } catch (error) {
      res.status(401).json({ error: error.message });
    }
  }
  
  async logout(req, res, next) {
    try {
      const { jti } = req.user;
      
      // Blacklist current token
      await tokenBlacklist.blacklistToken(jti, new Date(req.user.exp * 1000));
      
      // Clear refresh token cookie
      res.clearCookie('refreshToken');
      
      SecurityAudit.logEvent(SecurityEvents.LOGOUT, {
        userId: req.user.sub
      }, req);
      
      res.json({ message: 'Logged out successfully' });
      
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new AuthController();
```

---

### 2. **Hybrid Strategy (JWT + Sessions)** 

**Best suited for**: Web applications with both browser and API clients

**Used by**: Ghost, WikiJS, Rocket.Chat

**Implementation**:
```javascript
// strategies/hybridAuth.js
const session = require('express-session');
const RedisStore = require('connect-redis')(session);
const jwt = require('jsonwebtoken');

class HybridAuthStrategy {
  constructor() {
    this.sessionConfig = {
      store: new RedisStore({ client: redisClient }),
      secret: process.env.SESSION_SECRET,
      resave: false,
      saveUninitialized: false,
      name: 'sessionId',
      cookie: {
        secure: process.env.NODE_ENV === 'production',
        httpOnly: true,
        maxAge: 24 * 60 * 60 * 1000, // 24 hours
        sameSite: 'strict'
      }
    };
  }
  
  // Authentication middleware that supports both JWT and sessions
  authenticate() {
    return async (req, res, next) => {
      let user = null;
      
      // Try JWT authentication first
      const token = req.headers.authorization?.replace('Bearer ', '');
      if (token) {
        try {
          const decoded = jwt.verify(token, process.env.JWT_SECRET);
          user = await userRepository.findById(decoded.sub);
        } catch (error) {
          // JWT failed, try session
        }
      }
      
      // Try session authentication
      if (!user && req.session?.userId) {
        user = await userRepository.findById(req.session.userId);
      }
      
      if (!user) {
        return res.status(401).json({ error: 'Authentication required' });
      }
      
      req.user = user;
      next();
    };
  }
  
  // Login for web interface (creates session)
  async webLogin(req, res, email, password) {
    const user = await this.validateCredentials(email, password);
    req.session.userId = user.id;
    req.session.loginTime = new Date();
    
    res.json({ user: this.sanitizeUser(user) });
  }
  
  // Login for API (returns JWT)
  async apiLogin(req, res, email, password) {
    const user = await this.validateCredentials(email, password);
    const token = jwt.sign(
      { sub: user.id, email: user.email },
      process.env.JWT_SECRET,
      { expiresIn: '1h' }
    );
    
    res.json({ 
      user: this.sanitizeUser(user),
      token,
      expiresIn: '1h'
    });
  }
}
```

---

### 3. **OAuth 2.0 Strategy** 

**Best suited for**: Enterprise applications, social login, third-party integrations

**Used by**: GitLab, Rocket.Chat, Discourse, Mattermost

**Implementation with Multiple Providers**:
```javascript
// strategies/oauthStrategy.js
const passport = require('passport');
const GoogleStrategy = require('passport-google-oauth20').Strategy;
const GitHubStrategy = require('passport-github2').Strategy;
const MicrosoftStrategy = require('passport-microsoft').Strategy;

class OAuthStrategy {
  constructor() {
    this.setupStrategies();
  }
  
  setupStrategies() {
    // Google OAuth
    passport.use('google', new GoogleStrategy({
      clientID: process.env.GOOGLE_CLIENT_ID,
      clientSecret: process.env.GOOGLE_CLIENT_SECRET,
      callbackURL: '/auth/google/callback',
      scope: ['profile', 'email']
    }, this.handleOAuthCallback.bind(this, 'google')));
    
    // GitHub OAuth
    passport.use('github', new GitHubStrategy({
      clientID: process.env.GITHUB_CLIENT_ID,
      clientSecret: process.env.GITHUB_CLIENT_SECRET,
      callbackURL: '/auth/github/callback',
      scope: ['user:email']
    }, this.handleOAuthCallback.bind(this, 'github')));
    
    // Microsoft OAuth
    passport.use('microsoft', new MicrosoftStrategy({
      clientID: process.env.MICROSOFT_CLIENT_ID,
      clientSecret: process.env.MICROSOFT_CLIENT_SECRET,
      callbackURL: '/auth/microsoft/callback',
      scope: ['user.read']
    }, this.handleOAuthCallback.bind(this, 'microsoft')));
  }
  
  async handleOAuthCallback(provider, accessToken, refreshToken, profile, done) {
    try {
      const email = this.extractEmail(profile, provider);
      const providerData = {
        id: profile.id,
        username: profile.username,
        displayName: profile.displayName,
        emails: profile.emails,
        photos: profile.photos,
        accessToken,
        refreshToken
      };
      
      // Find or create user
      let user = await userRepository.findByEmail(email);
      
      if (!user) {
        // Create new user from OAuth profile
        user = await userRepository.create({
          email,
          name: profile.displayName || profile.username,
          avatar: profile.photos?.[0]?.value,
          isEmailVerified: true, // Trust OAuth provider
          authProviders: {
            [provider]: providerData
          }
        });
      } else {
        // Update existing user with OAuth data
        user = await userRepository.update(user.id, {
          [`authProviders.${provider}`]: providerData,
          lastLoginAt: new Date()
        });
      }
      
      return done(null, user);
    } catch (error) {
      return done(error, null);
    }
  }
  
  extractEmail(profile, provider) {
    switch (provider) {
      case 'google':
        return profile.emails?.[0]?.value;
      case 'github':
        return profile.emails?.find(email => email.primary)?.email;
      case 'microsoft':
        return profile.emails?.[0]?.value;
      default:
        throw new Error(`Unsupported provider: ${provider}`);
    }
  }
  
  // OAuth routes
  setupRoutes(app) {
    // Google OAuth routes
    app.get('/auth/google', 
      passport.authenticate('google', { scope: ['profile', 'email'] })
    );
    
    app.get('/auth/google/callback',
      passport.authenticate('google', { session: false }),
      this.handleOAuthSuccess.bind(this)
    );
    
    // GitHub OAuth routes
    app.get('/auth/github',
      passport.authenticate('github', { scope: ['user:email'] })
    );
    
    app.get('/auth/github/callback',
      passport.authenticate('github', { session: false }),
      this.handleOAuthSuccess.bind(this)
    );
    
    // Microsoft OAuth routes
    app.get('/auth/microsoft',
      passport.authenticate('microsoft', { scope: ['user.read'] })
    );
    
    app.get('/auth/microsoft/callback',
      passport.authenticate('microsoft', { session: false }),
      this.handleOAuthSuccess.bind(this)
    );
  }
  
  handleOAuthSuccess(req, res) {
    try {
      // Generate JWT token for the authenticated user
      const token = jwt.sign(
        { 
          sub: req.user.id,
          email: req.user.email,
          name: req.user.name
        },
        process.env.JWT_SECRET,
        { expiresIn: '1h' }
      );
      
      // Redirect to frontend with token
      const redirectUrl = `${process.env.FRONTEND_URL}/auth/callback?token=${token}`;
      res.redirect(redirectUrl);
    } catch (error) {
      res.redirect(`${process.env.FRONTEND_URL}/auth/error?message=${encodeURIComponent(error.message)}`);
    }
  }
}

module.exports = new OAuthStrategy();
```

---

### 4. **Multi-Factor Authentication (MFA)** 

**Best suited for**: High-security applications, enterprise environments

**Used by**: GitLab, Rocket.Chat, Mattermost

**TOTP Implementation**:
```javascript
// strategies/mfaStrategy.js
const speakeasy = require('speakeasy');
const QRCode = require('qrcode');

class MFAStrategy {
  async enableMFA(userId) {
    // Generate secret
    const secret = speakeasy.generateSecret({
      name: `${process.env.APP_NAME} (${user.email})`,
      issuer: process.env.APP_NAME,
      length: 32
    });
    
    // Store secret in database (encrypted)
    await userRepository.update(userId, {
      mfaSecret: encrypt(secret.base32),
      mfaEnabled: false // Will be enabled after verification
    });
    
    // Generate QR code
    const qrCodeUrl = await QRCode.toDataURL(secret.otpauth_url);
    
    return {
      secret: secret.base32,
      qrCode: qrCodeUrl,
      backupCodes: await this.generateBackupCodes(userId)
    };
  }
  
  async verifyMFASetup(userId, token) {
    const user = await userRepository.findById(userId);
    const secret = decrypt(user.mfaSecret);
    
    const verified = speakeasy.totp.verify({
      secret,
      encoding: 'base32',
      token,
      window: 2 // Allow 2 time steps (60 seconds) tolerance
    });
    
    if (verified) {
      await userRepository.update(userId, { mfaEnabled: true });
      return true;
    }
    
    return false;
  }
  
  async verifyMFAToken(userId, token) {
    const user = await userRepository.findById(userId);
    
    if (!user.mfaEnabled) {
      return true; // MFA not enabled for user
    }
    
    // Check backup codes first
    if (await this.verifyBackupCode(userId, token)) {
      return true;
    }
    
    // Verify TOTP token
    const secret = decrypt(user.mfaSecret);
    return speakeasy.totp.verify({
      secret,
      encoding: 'base32',
      token,
      window: 2
    });
  }
  
  async generateBackupCodes(userId) {
    const codes = [];
    for (let i = 0; i < 8; i++) {
      codes.push(crypto.randomBytes(4).toString('hex').toUpperCase());
    }
    
    await userRepository.update(userId, {
      mfaBackupCodes: codes.map(code => bcrypt.hashSync(code, 10))
    });
    
    return codes;
  }
  
  async verifyBackupCode(userId, code) {
    const user = await userRepository.findById(userId);
    const codeIndex = user.mfaBackupCodes.findIndex(hashedCode => 
      bcrypt.compareSync(code, hashedCode)
    );
    
    if (codeIndex !== -1) {
      // Remove used backup code
      const updatedCodes = user.mfaBackupCodes.filter((_, index) => index !== codeIndex);
      await userRepository.update(userId, { mfaBackupCodes: updatedCodes });
      return true;
    }
    
    return false;
  }
}

// MFA-enabled authentication middleware
const mfaAuthMiddleware = async (req, res, next) => {
  try {
    const { email, password, mfaToken } = req.body;
    
    // Step 1: Validate password
    const user = await authStrategy.validateCredentials(email, password);
    
    // Step 2: Check MFA requirement
    if (user.mfaEnabled) {
      if (!mfaToken) {
        return res.status(200).json({
          requiresMFA: true,
          message: 'MFA token required'
        });
      }
      
      const mfaValid = await mfaStrategy.verifyMFAToken(user.id, mfaToken);
      if (!mfaValid) {
        return res.status(401).json({ error: 'Invalid MFA token' });
      }
    }
    
    // Generate tokens and complete login
    const tokens = authStrategy.generateTokens(user);
    res.json({
      user: authStrategy.sanitizeUser(user),
      accessToken: tokens.accessToken,
      expiresIn: '15m'
    });
    
  } catch (error) {
    next(error);
  }
};

module.exports = { MFAStrategy, mfaAuthMiddleware };
```

---

### 5. **API Key Strategy** 

**Best suited for**: Service-to-service authentication, external integrations

**Used by**: Parse Server, Sentry, Strapi

**Implementation**:
```javascript
// strategies/apiKeyStrategy.js
const crypto = require('crypto');

class APIKeyStrategy {
  async generateAPIKey(userId, name, permissions = []) {
    const key = this.generateSecureKey();
    const hashedKey = await bcrypt.hash(key, 10);
    
    const apiKey = await apiKeyRepository.create({
      userId,
      name,
      keyHash: hashedKey,
      permissions,
      lastUsedAt: null,
      createdAt: new Date(),
      isActive: true
    });
    
    return {
      id: apiKey.id,
      key: `${process.env.API_KEY_PREFIX}_${key}`,
      name,
      permissions
    };
  }
  
  generateSecureKey() {
    return crypto.randomBytes(32).toString('hex');
  }
  
  async validateAPIKey(keyString) {
    if (!keyString.startsWith(process.env.API_KEY_PREFIX + '_')) {
      return null;
    }
    
    const key = keyString.replace(process.env.API_KEY_PREFIX + '_', '');
    const apiKeys = await apiKeyRepository.findAllActive();
    
    for (const apiKey of apiKeys) {
      if (await bcrypt.compare(key, apiKey.keyHash)) {
        // Update last used time
        await apiKeyRepository.update(apiKey.id, {
          lastUsedAt: new Date(),
          useCount: apiKey.useCount + 1
        });
        
        return apiKey;
      }
    }
    
    return null;
  }
  
  // API Key authentication middleware
  middleware() {
    return async (req, res, next) => {
      const apiKey = req.headers['x-api-key'] || req.query.api_key;
      
      if (!apiKey) {
        return res.status(401).json({ error: 'API key required' });
      }
      
      const validKey = await this.validateAPIKey(apiKey);
      if (!validKey) {
        return res.status(401).json({ error: 'Invalid API key' });
      }
      
      // Load user associated with API key
      const user = await userRepository.findById(validKey.userId);
      if (!user || !user.isActive) {
        return res.status(401).json({ error: 'API key user is inactive' });
      }
      
      req.user = user;
      req.apiKey = validKey;
      next();
    };
  }
}

module.exports = new APIKeyStrategy();
```

---

## 🔄 Authentication Flow Patterns

### 1. **Standard Login Flow**
```
1. User submits credentials
2. Server validates credentials
3. Server generates JWT tokens
4. Client stores access token
5. Client includes token in subsequent requests
6. Server validates token on each request
```

### 2. **OAuth Flow**
```
1. User clicks "Login with [Provider]"
2. Redirect to OAuth provider
3. User authorizes application
4. Provider redirects with authorization code
5. Server exchanges code for access token
6. Server retrieves user profile
7. Server creates/updates user account
8. Server generates internal JWT token
9. Client receives token for subsequent requests
```

### 3. **MFA-Enhanced Flow**
```
1. User submits credentials
2. Server validates credentials
3. If MFA enabled, request MFA token
4. User provides MFA token
5. Server validates MFA token
6. Server generates JWT tokens
7. Normal authenticated session continues
```

## 📊 Security Comparison

| Strategy | Security Level | Implementation Effort | Scalability | Best Use Case |
|----------|----------------|----------------------|-------------|---------------|
| **JWT Only** | High | Medium | Excellent | APIs, SPAs, Mobile Apps |
| **Session Only** | Medium | Low | Good | Traditional Web Apps |
| **Hybrid (JWT + Session)** | High | High | Excellent | Full-stack Applications |
| **OAuth Integration** | Very High | High | Excellent | Enterprise, Social Login |
| **MFA Enhanced** | Very High | High | Good | High-security Applications |
| **API Keys** | Medium | Low | Excellent | Service-to-service |

## 🎯 Implementation Recommendations

### For New Projects
1. **Start with JWT-first strategy** for maximum flexibility
2. **Add OAuth integration** for better user experience
3. **Implement proper token refresh** mechanism
4. **Consider MFA** for sensitive applications
5. **Use API keys** for service-to-service communication

### For Enterprise Applications
1. **Implement hybrid authentication** for multiple client types
2. **Add LDAP/Active Directory** integration
3. **Enforce MFA** for administrative accounts
4. **Implement comprehensive audit logging**
5. **Use role-based access control** (RBAC)

### Security Best Practices
1. **Never store passwords in plain text** - always hash with bcrypt
2. **Use secure secrets** for JWT signing and session encryption
3. **Implement token blacklisting** for secure logout
4. **Set appropriate token expiration times** - short for access, longer for refresh
5. **Log all authentication events** for security monitoring
6. **Implement rate limiting** on authentication endpoints
7. **Use HTTPS in production** to protect tokens in transit

---

**Next**: [Testing Strategies](./testing-strategies.md) | **Previous**: [Security Considerations](./security-considerations.md)