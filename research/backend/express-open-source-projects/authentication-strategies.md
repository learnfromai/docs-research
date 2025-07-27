# Authentication Strategies in Express.js Applications

## 🔑 Authentication Overview

Authentication is the cornerstone of secure Express.js applications. This comprehensive analysis examines proven authentication strategies implemented across successful open source projects, covering traditional sessions, modern JWT patterns, OAuth integrations, and emerging authentication methods.

---

## 🎯 Authentication Strategy Comparison

### Quick Reference Matrix
| Strategy | Security Level | Scalability | Complexity | Mobile Support | Offline Support |
|----------|----------------|-------------|------------|----------------|-----------------|
| Session-based | High | Medium | Low | Limited | No |
| JWT | High | High | Medium | Excellent | Limited |
| OAuth 2.0 | Very High | High | High | Good | No |
| SAML | Very High | Medium | Very High | Limited | No |
| WebAuthn | Excellent | High | High | Emerging | No |
| Magic Links | Medium | High | Low | Good | No |

---

## 🍪 Session-Based Authentication

Traditional session-based authentication remains effective for server-rendered applications and provides excellent security when properly implemented.

### Implementation with Redis Store

```typescript
import session from 'express-session';
import RedisStore from 'connect-redis';
import Redis from 'ioredis';

// Redis configuration for session storage
const redis = new Redis({
  host: process.env.REDIS_HOST || 'localhost',
  port: parseInt(process.env.REDIS_PORT || '6379'),
  password: process.env.REDIS_PASSWORD,
  db: 0,
  retryDelayOnFailover: 100,
  maxRetriesPerRequest: 3,
  lazyConnect: true,
});

// Session configuration
const sessionConfig: session.SessionOptions = {
  store: new RedisStore({ 
    client: redis,
    prefix: 'sess:',
    ttl: 86400, // 24 hours in seconds
  }),
  secret: process.env.SESSION_SECRET!,
  name: 'sessionId',
  resave: false,
  saveUninitialized: false,
  rolling: true, // Refresh session on activity
  cookie: {
    secure: process.env.NODE_ENV === 'production',
    httpOnly: true,
    maxAge: 24 * 60 * 60 * 1000, // 24 hours
    sameSite: process.env.NODE_ENV === 'production' ? 'strict' : 'lax',
  },
  genid: () => crypto.randomUUID(),
};

app.use(session(sessionConfig));

// Session-based authentication service
class SessionAuthService {
  async login(email: string, password: string, req: Request): Promise<User> {
    const user = await this.userRepository.findByEmail(email);
    
    if (!user || !await bcrypt.compare(password, user.password)) {
      throw new UnauthorizedException('Invalid credentials');
    }

    if (!user.isActive) {
      throw new UnauthorizedException('Account is disabled');
    }

    // Track login attempt
    await this.auditService.logLogin(user.id, req.ip, true);

    // Create session
    req.session.userId = user.id;
    req.session.userRole = user.role;
    req.session.loginAt = new Date();

    // Update last login
    await this.userRepository.updateLastLogin(user.id);

    return user;
  }

  async logout(req: Request): Promise<void> {
    const userId = req.session.userId;
    
    // Destroy session
    req.session.destroy((err) => {
      if (err) {
        console.error('Session destruction error:', err);
      }
    });

    // Clear session cookie
    req.res?.clearCookie('sessionId');

    // Log logout
    if (userId) {
      await this.auditService.logLogout(userId);
    }
  }

  isAuthenticated(req: Request): boolean {
    return !!req.session.userId;
  }

  getCurrentUser(req: Request): Promise<User | null> {
    if (!req.session.userId) {
      return Promise.resolve(null);
    }
    return this.userRepository.findById(req.session.userId);
  }
}

// Session authentication middleware
const sessionAuth = async (req: Request, res: Response, next: NextFunction) => {
  if (!req.session.userId) {
    return res.status(401).json({ error: 'Authentication required' });
  }

  try {
    const user = await userRepository.findById(req.session.userId);
    if (!user || !user.isActive) {
      req.session.destroy(() => {});
      return res.status(401).json({ error: 'Invalid session' });
    }

    req.user = user;
    next();
  } catch (error) {
    return res.status(500).json({ error: 'Authentication error' });
  }
};
```

### Session Security Enhancements

```typescript
// Session fixation protection
class SessionSecurityService {
  regenerateSession(req: Request): Promise<void> {
    return new Promise((resolve, reject) => {
      const oldSessionData = req.session;
      
      req.session.regenerate((err) => {
        if (err) {
          reject(err);
          return;
        }

        // Restore session data
        Object.assign(req.session, oldSessionData);
        req.session.save((saveErr) => {
          if (saveErr) {
            reject(saveErr);
            return;
          }
          resolve();
        });
      });
    });
  }

  // Session monitoring
  async validateSession(req: Request): Promise<boolean> {
    const session = req.session;
    
    if (!session.userId) {
      return false;
    }

    // Check session age
    const maxAge = 8 * 60 * 60 * 1000; // 8 hours
    if (session.loginAt && Date.now() - session.loginAt.getTime() > maxAge) {
      session.destroy(() => {});
      return false;
    }

    // Check for suspicious activity
    const currentIp = req.ip;
    if (session.lastIp && session.lastIp !== currentIp) {
      await this.auditService.logSuspiciousActivity(session.userId, 'ip_change', {
        oldIp: session.lastIp,
        newIp: currentIp,
      });
    }

    session.lastIp = currentIp;
    session.lastActivity = new Date();

    return true;
  }
}
```

---

## 🎫 JWT-Based Authentication

JWT (JSON Web Tokens) provide stateless authentication ideal for APIs and microservices architectures.

### Secure JWT Implementation

```typescript
import jwt from 'jsonwebtoken';
import { promisify } from 'util';

interface JWTPayload {
  sub: string; // user ID
  email: string;
  role: string;
  iat: number;
  exp: number;
  jti: string; // JWT ID
  aud: string; // audience
  iss: string; // issuer
}

interface RefreshTokenPayload {
  sub: string;
  jti: string;
  type: 'refresh';
}

class JWTAuthService {
  private readonly accessSecret = process.env.JWT_ACCESS_SECRET!;
  private readonly refreshSecret = process.env.JWT_REFRESH_SECRET!;
  private readonly issuer = process.env.JWT_ISSUER || 'myapp';
  private readonly audience = process.env.JWT_AUDIENCE || 'myapp-api';

  async generateTokenPair(user: User): Promise<TokenPair> {
    const jti = crypto.randomUUID();
    const now = Math.floor(Date.now() / 1000);

    // Access token (short-lived)
    const accessPayload: JWTPayload = {
      sub: user.id,
      email: user.email,
      role: user.role,
      iat: now,
      exp: now + (15 * 60), // 15 minutes
      jti,
      aud: this.audience,
      iss: this.issuer,
    };

    // Refresh token (long-lived)
    const refreshPayload: RefreshTokenPayload = {
      sub: user.id,
      jti,
      type: 'refresh',
    };

    const accessToken = jwt.sign(accessPayload, this.accessSecret, {
      algorithm: 'HS256',
    });

    const refreshToken = jwt.sign(refreshPayload, this.refreshSecret, {
      algorithm: 'HS256',
      expiresIn: '7d',
    });

    // Store refresh token metadata
    await this.tokenRepository.saveRefreshToken({
      jti,
      userId: user.id,
      expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
      userAgent: req.headers['user-agent'],
      ipAddress: req.ip,
    });

    return { accessToken, refreshToken };
  }

  async verifyAccessToken(token: string): Promise<JWTPayload> {
    try {
      const payload = jwt.verify(token, this.accessSecret, {
        issuer: this.issuer,
        audience: this.audience,
        algorithms: ['HS256'],
      }) as JWTPayload;

      // Check if token is blacklisted
      const isBlacklisted = await this.tokenRepository.isTokenBlacklisted(payload.jti);
      if (isBlacklisted) {
        throw new Error('Token is blacklisted');
      }

      return payload;
    } catch (error) {
      throw new UnauthorizedException('Invalid access token');
    }
  }

  async refreshTokens(refreshToken: string): Promise<TokenPair> {
    try {
      const payload = jwt.verify(refreshToken, this.refreshSecret) as RefreshTokenPayload;
      
      // Validate refresh token in database
      const storedToken = await this.tokenRepository.findRefreshToken(payload.jti);
      if (!storedToken || storedToken.expiresAt < new Date()) {
        throw new Error('Refresh token not found or expired');
      }

      // Get user
      const user = await this.userRepository.findById(payload.sub);
      if (!user || !user.isActive) {
        throw new Error('User not found or inactive');
      }

      // Revoke old refresh token
      await this.tokenRepository.revokeRefreshToken(payload.jti);

      // Generate new token pair
      return await this.generateTokenPair(user);
    } catch (error) {
      throw new UnauthorizedException('Invalid refresh token');
    }
  }

  async revokeAllTokens(userId: string): Promise<void> {
    await this.tokenRepository.revokeAllUserTokens(userId);
  }

  async blacklistToken(jti: string): Promise<void> {
    await this.tokenRepository.blacklistToken(jti);
  }
}

// JWT authentication middleware
const jwtAuth = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader?.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'Bearer token required' });
    }

    const token = authHeader.slice(7);
    const payload = await jwtAuthService.verifyAccessToken(token);

    // Attach user to request
    req.user = {
      id: payload.sub,
      email: payload.email,
      role: payload.role,
    };

    next();
  } catch (error) {
    return res.status(401).json({ error: 'Invalid token' });
  }
};

// Optional: Refresh token endpoint
app.post('/auth/refresh', async (req, res) => {
  try {
    const { refreshToken } = req.body;
    if (!refreshToken) {
      return res.status(400).json({ error: 'Refresh token required' });
    }

    const tokens = await jwtAuthService.refreshTokens(refreshToken);
    res.json(tokens);
  } catch (error) {
    res.status(401).json({ error: 'Invalid refresh token' });
  }
});
```

### JWT Security Best Practices

```typescript
// Token rotation and security
class JWTSecurityService {
  // Automatic token rotation
  async rotateTokenIfNeeded(token: string): Promise<string | null> {
    const payload = jwt.decode(token) as JWTPayload;
    if (!payload) return null;

    const now = Math.floor(Date.now() / 1000);
    const timeUntilExpiry = payload.exp - now;
    const rotationThreshold = 5 * 60; // 5 minutes

    if (timeUntilExpiry <= rotationThreshold) {
      const user = await this.userRepository.findById(payload.sub);
      if (user) {
        const newTokenPair = await this.jwtAuthService.generateTokenPair(user);
        return newTokenPair.accessToken;
      }
    }

    return null;
  }

  // Token introspection
  async introspectToken(token: string): Promise<TokenIntrospection> {
    try {
      const payload = await this.jwtAuthService.verifyAccessToken(token);
      
      return {
        active: true,
        sub: payload.sub,
        email: payload.email,
        role: payload.role,
        exp: payload.exp,
        iat: payload.iat,
        iss: payload.iss,
        aud: payload.aud,
      };
    } catch (error) {
      return { active: false };
    }
  }

  // Concurrent session management
  async limitConcurrentSessions(userId: string, maxSessions = 3): Promise<void> {
    const activeSessions = await this.tokenRepository.getActiveRefreshTokens(userId);
    
    if (activeSessions.length >= maxSessions) {
      // Revoke oldest sessions
      const sessionsToRevoke = activeSessions
        .sort((a, b) => a.createdAt.getTime() - b.createdAt.getTime())
        .slice(0, activeSessions.length - maxSessions + 1);

      for (const session of sessionsToRevoke) {
        await this.tokenRepository.revokeRefreshToken(session.jti);
      }
    }
  }
}
```

---

## 🌐 OAuth 2.0 Integration

OAuth 2.0 enables secure third-party authentication and authorization.

### Google OAuth Implementation

```typescript
import { Strategy as GoogleStrategy } from 'passport-google-oauth20';
import passport from 'passport';

// Google OAuth configuration
passport.use(new GoogleStrategy({
  clientID: process.env.GOOGLE_CLIENT_ID!,
  clientSecret: process.env.GOOGLE_CLIENT_SECRET!,
  callbackURL: '/auth/google/callback',
  scope: ['profile', 'email'],
}, async (accessToken, refreshToken, profile, done) => {
  try {
    const oauthProfile = {
      provider: 'google',
      providerId: profile.id,
      email: profile.emails?.[0]?.value,
      name: profile.displayName,
      avatar: profile.photos?.[0]?.value,
      accessToken,
      refreshToken,
    };

    const user = await oauthService.authenticateOrCreateUser(oauthProfile);
    return done(null, user);
  } catch (error) {
    return done(error, null);
  }
}));

// OAuth service
class OAuthService {
  async authenticateOrCreateUser(profile: OAuthProfile): Promise<User> {
    // Check if user exists by email
    let user = await this.userRepository.findByEmail(profile.email);
    
    if (user) {
      // Update OAuth info if user exists
      await this.userRepository.updateOAuthInfo(user.id, {
        provider: profile.provider,
        providerId: profile.providerId,
        accessToken: profile.accessToken,
        refreshToken: profile.refreshToken,
      });
    } else {
      // Create new user
      user = await this.userRepository.create({
        email: profile.email,
        name: profile.name,
        avatar: profile.avatar,
        provider: profile.provider,
        providerId: profile.providerId,
        isEmailVerified: true, // OAuth emails are pre-verified
        role: 'user',
      });
    }

    return user;
  }

  async linkOAuthAccount(userId: string, profile: OAuthProfile): Promise<void> {
    // Check if OAuth account is already linked to another user
    const existingUser = await this.userRepository.findByOAuthProvider(
      profile.provider,
      profile.providerId
    );

    if (existingUser && existingUser.id !== userId) {
      throw new ConflictException('OAuth account already linked to another user');
    }

    await this.userRepository.linkOAuthAccount(userId, profile);
  }

  async unlinkOAuthAccount(userId: string, provider: string): Promise<void> {
    const user = await this.userRepository.findById(userId);
    if (!user) {
      throw new NotFoundException('User not found');
    }

    // Ensure user has a password or another OAuth method before unlinking
    if (!user.password && user.oauthAccounts.length <= 1) {
      throw new BadRequestException('Cannot unlink last authentication method');
    }

    await this.userRepository.unlinkOAuthAccount(userId, provider);
  }
}

// OAuth routes
app.get('/auth/google',
  passport.authenticate('google', { 
    scope: ['profile', 'email'],
    session: false,
  })
);

app.get('/auth/google/callback',
  passport.authenticate('google', { session: false }),
  async (req, res) => {
    try {
      const user = req.user as User;
      const tokens = await jwtAuthService.generateTokenPair(user);
      
      // Set secure cookies
      res.cookie('accessToken', tokens.accessToken, {
        httpOnly: true,
        secure: process.env.NODE_ENV === 'production',
        sameSite: 'strict',
        maxAge: 15 * 60 * 1000, // 15 minutes
      });

      res.cookie('refreshToken', tokens.refreshToken, {
        httpOnly: true,
        secure: process.env.NODE_ENV === 'production',
        sameSite: 'strict',
        maxAge: 7 * 24 * 60 * 60 * 1000, // 7 days
      });

      res.redirect(process.env.CLIENT_URL + '/dashboard');
    } catch (error) {
      res.redirect(process.env.CLIENT_URL + '/login?error=oauth_error');
    }
  }
);
```

### GitHub OAuth Implementation

```typescript
import { Strategy as GitHubStrategy } from 'passport-github2';

passport.use(new GitHubStrategy({
  clientID: process.env.GITHUB_CLIENT_ID!,
  clientSecret: process.env.GITHUB_CLIENT_SECRET!,
  callbackURL: '/auth/github/callback',
  scope: ['user:email'],
}, async (accessToken, refreshToken, profile, done) => {
  try {
    const oauthProfile = {
      provider: 'github',
      providerId: profile.id,
      email: profile.emails?.[0]?.value,
      name: profile.displayName || profile.username,
      username: profile.username,
      avatar: profile.photos?.[0]?.value,
      accessToken,
    };

    const user = await oauthService.authenticateOrCreateUser(oauthProfile);
    return done(null, user);
  } catch (error) {
    return done(error, null);
  }
}));

// Multi-provider OAuth management
class MultiProviderOAuth {
  private providers = new Map([
    ['google', GoogleStrategy],
    ['github', GitHubStrategy],
    ['facebook', FacebookStrategy],
  ]);

  initializeProviders(): void {
    for (const [name, Strategy] of this.providers) {
      const config = this.getProviderConfig(name);
      if (config.enabled) {
        passport.use(new Strategy(config, this.oauthCallback.bind(this)));
      }
    }
  }

  private getProviderConfig(provider: string): OAuthConfig {
    return {
      enabled: process.env[`${provider.toUpperCase()}_ENABLED`] === 'true',
      clientID: process.env[`${provider.toUpperCase()}_CLIENT_ID`]!,
      clientSecret: process.env[`${provider.toUpperCase()}_CLIENT_SECRET`]!,
      callbackURL: `/auth/${provider}/callback`,
    };
  }

  private async oauthCallback(accessToken: string, refreshToken: string, profile: any, done: Function) {
    // Common OAuth callback logic
    // Implementation varies by provider
  }
}
```

---

## 🔐 Multi-Factor Authentication (MFA)

Implement TOTP-based MFA for enhanced security.

### TOTP Implementation

```typescript
import speakeasy from 'speakeasy';
import QRCode from 'qrcode';

class MFAService {
  generateSecret(userEmail: string): MFASecret {
    const secret = speakeasy.generateSecret({
      name: `MyApp (${userEmail})`,
      issuer: 'MyApp',
      length: 32,
    });

    return {
      secret: secret.base32,
      qrCode: secret.otpauth_url!,
    };
  }

  async generateQRCode(secret: string): Promise<string> {
    return await QRCode.toDataURL(secret);
  }

  verifyToken(secret: string, token: string): boolean {
    return speakeasy.totp.verify({
      secret,
      encoding: 'base32',
      token,
      window: 2, // Allow 2 time steps (±30 seconds)
    });
  }

  async enableMFA(userId: string, secret: string, token: string): Promise<void> {
    if (!this.verifyToken(secret, token)) {
      throw new BadRequestException('Invalid MFA token');
    }

    await this.userRepository.enableMFA(userId, secret);
  }

  async disableMFA(userId: string, token: string): Promise<void> {
    const user = await this.userRepository.findById(userId);
    if (!user?.mfaSecret) {
      throw new BadRequestException('MFA not enabled');
    }

    if (!this.verifyToken(user.mfaSecret, token)) {
      throw new BadRequestException('Invalid MFA token');
    }

    await this.userRepository.disableMFA(userId);
  }

  generateBackupCodes(): string[] {
    const codes = [];
    for (let i = 0; i < 10; i++) {
      codes.push(crypto.randomBytes(4).toString('hex').toUpperCase());
    }
    return codes;
  }
}

// MFA middleware
const requireMFA = async (req: Request, res: Response, next: NextFunction) => {
  const user = req.user;
  if (!user) {
    return res.status(401).json({ error: 'Authentication required' });
  }

  if (user.mfaEnabled && !req.session.mfaVerified) {
    return res.status(403).json({ 
      error: 'MFA verification required',
      requiresMFA: true,
    });
  }

  next();
};

// MFA verification endpoint
app.post('/auth/mfa/verify', jwtAuth, async (req, res) => {
  try {
    const { token } = req.body;
    const user = await userRepository.findById(req.user.id);
    
    if (!user?.mfaSecret) {
      return res.status(400).json({ error: 'MFA not enabled' });
    }

    const isValid = mfaService.verifyToken(user.mfaSecret, token);
    if (!isValid) {
      return res.status(400).json({ error: 'Invalid MFA token' });
    }

    req.session.mfaVerified = true;
    res.json({ message: 'MFA verified successfully' });
  } catch (error) {
    res.status(500).json({ error: 'MFA verification failed' });
  }
});
```

---

## 📧 Magic Link Authentication

Passwordless authentication via email links.

```typescript
class MagicLinkService {
  async generateMagicLink(email: string): Promise<string> {
    const token = crypto.randomBytes(32).toString('hex');
    const hashedToken = crypto.createHash('sha256').update(token).digest('hex');
    
    await this.tokenRepository.saveMagicLinkToken({
      email,
      token: hashedToken,
      expiresAt: new Date(Date.now() + 15 * 60 * 1000), // 15 minutes
    });

    return `${process.env.CLIENT_URL}/auth/magic?token=${token}`;
  }

  async verifyMagicLink(token: string): Promise<User> {
    const hashedToken = crypto.createHash('sha256').update(token).digest('hex');
    
    const linkToken = await this.tokenRepository.findMagicLinkToken(hashedToken);
    if (!linkToken || linkToken.expiresAt < new Date()) {
      throw new UnauthorizedException('Invalid or expired magic link');
    }

    let user = await this.userRepository.findByEmail(linkToken.email);
    if (!user) {
      // Create user if doesn't exist
      user = await this.userRepository.create({
        email: linkToken.email,
        isEmailVerified: true,
        role: 'user',
      });
    }

    // Delete used token
    await this.tokenRepository.deleteMagicLinkToken(hashedToken);

    return user;
  }

  async sendMagicLink(email: string): Promise<void> {
    const magicLink = await this.generateMagicLink(email);
    
    await this.emailService.sendMagicLink(email, magicLink);
  }
}

// Magic link endpoints
app.post('/auth/magic-link', async (req, res) => {
  try {
    const { email } = req.body;
    
    if (!email || !isValidEmail(email)) {
      return res.status(400).json({ error: 'Valid email required' });
    }

    await magicLinkService.sendMagicLink(email);
    res.json({ message: 'Magic link sent to your email' });
  } catch (error) {
    res.status(500).json({ error: 'Failed to send magic link' });
  }
});

app.post('/auth/magic-link/verify', async (req, res) => {
  try {
    const { token } = req.body;
    
    const user = await magicLinkService.verifyMagicLink(token);
    const tokens = await jwtAuthService.generateTokenPair(user);
    
    res.json({ 
      message: 'Authentication successful',
      ...tokens,
      user: user.toPublic(),
    });
  } catch (error) {
    res.status(401).json({ error: 'Invalid magic link' });
  }
});
```

---

## 🔗 Navigation

← [Security Best Practices](./security-best-practices.md) | [Scalability Approaches](./scalability-approaches.md) →

---

*Authentication analysis: July 2025 | Strategies covered: Sessions, JWT, OAuth, MFA, Magic Links*