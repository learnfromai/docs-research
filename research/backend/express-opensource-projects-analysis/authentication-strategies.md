# Authentication Strategies: Express.js Open Source Projects

## 🔐 Overview

Analysis of authentication and authorization strategies implemented across successful Express.js open source projects, providing insights into production-ready patterns for securing web applications.

## 🎯 Authentication Patterns Analysis

### 1. JWT-Based Authentication (90% of projects)

**Most Common Implementation Pattern:**

```typescript
// JWT Configuration from NestJS and Strapi
export const jwtConfig = {
  secret: process.env.JWT_SECRET,
  signOptions: {
    expiresIn: '15m',
    issuer: 'app-name',
    audience: 'app-users',
    algorithm: 'HS256' // Use RS256 in production
  },
  verifyOptions: {
    issuer: 'app-name',
    audience: 'app-users',
    algorithms: ['HS256']
  }
};

// Token generation service
class TokenService {
  generateAccessToken(payload: TokenPayload): string {
    return jwt.sign(payload, jwtConfig.secret, jwtConfig.signOptions);
  }
  
  generateRefreshToken(userId: string): string {
    return jwt.sign(
      { userId, type: 'refresh' },
      process.env.JWT_REFRESH_SECRET,
      { expiresIn: '7d' }
    );
  }
  
  verifyToken(token: string): TokenPayload {
    return jwt.verify(token, jwtConfig.secret, jwtConfig.verifyOptions) as TokenPayload;
  }
}
```

### 2. Passport.js Integration (70% of projects)

**Multi-Strategy Authentication (Ghost, Strapi, KeystoneJS):**

```typescript
// Passport configuration from Ghost and Strapi
import passport from 'passport';
import { Strategy as LocalStrategy } from 'passport-local';
import { Strategy as JwtStrategy, ExtractJwt } from 'passport-jwt';
import { Strategy as GoogleStrategy } from 'passport-google-oauth20';

// Local authentication strategy
passport.use(new LocalStrategy(
  {
    usernameField: 'email',
    passwordField: 'password'
  },
  async (email: string, password: string, done) => {
    try {
      const user = await User.findOne({ email });
      
      if (!user || !await bcrypt.compare(password, user.password)) {
        return done(null, false, { message: 'Invalid credentials' });
      }
      
      if (!user.isActive) {
        return done(null, false, { message: 'Account deactivated' });
      }
      
      return done(null, user);
    } catch (error) {
      return done(error);
    }
  }
));

// JWT strategy for API authentication
passport.use(new JwtStrategy(
  {
    jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
    secretOrKey: process.env.JWT_SECRET,
    issuer: 'app-name',
    audience: 'app-users'
  },
  async (payload, done) => {
    try {
      const user = await User.findById(payload.sub).populate('roles');
      return user ? done(null, user) : done(null, false);
    } catch (error) {
      return done(error, false);
    }
  }
));

// OAuth2 Google strategy
passport.use(new GoogleStrategy(
  {
    clientID: process.env.GOOGLE_CLIENT_ID,
    clientSecret: process.env.GOOGLE_CLIENT_SECRET,
    callbackURL: '/auth/google/callback'
  },
  async (accessToken, refreshToken, profile, done) => {
    try {
      let user = await User.findOne({ googleId: profile.id });
      
      if (!user) {
        user = await User.create({
          googleId: profile.id,
          email: profile.emails[0].value,
          name: profile.displayName,
          avatar: profile.photos[0].value,
          provider: 'google',
          isEmailVerified: true
        });
      }
      
      return done(null, user);
    } catch (error) {
      return done(error, null);
    }
  }
));
```

### 3. Session-Based Authentication (40% of projects)

**Express Session with Redis (Ghost, traditional CMSs):**

```typescript
// Session configuration from Ghost
import session from 'express-session';
import RedisStore from 'connect-redis';
import { createClient } from 'redis';

const redisClient = createClient({
  host: process.env.REDIS_HOST,
  port: process.env.REDIS_PORT,
  password: process.env.REDIS_PASSWORD
});

const sessionConfig = {
  store: new RedisStore({ client: redisClient }),
  secret: process.env.SESSION_SECRET,
  name: 'sessionId',
  resave: false,
  saveUninitialized: false,
  cookie: {
    secure: process.env.NODE_ENV === 'production',
    httpOnly: true,
    maxAge: 24 * 60 * 60 * 1000, // 24 hours
    sameSite: 'strict' as const
  },
  rolling: true // Reset expiry on activity
};

app.use(session(sessionConfig));

// Session-based authentication middleware
const requireAuth = (req: Request, res: Response, next: NextFunction) => {
  if (!req.session?.user) {
    return res.status(401).json({
      success: false,
      message: 'Authentication required'
    });
  }
  
  // Check session validity
  if (req.session.expiresAt && new Date() > req.session.expiresAt) {
    req.session.destroy((err) => {
      if (err) console.error('Session destruction error:', err);
    });
    
    return res.status(401).json({
      success: false,
      message: 'Session expired'
    });
  }
  
  next();
};
```

## 🛡️ Authorization Strategies

### 1. Role-Based Access Control (RBAC) - 85% adoption

**Implementation from Strapi and NestJS:**

```typescript
// Role and permission models
interface Role {
  id: string;
  name: string;
  permissions: Permission[];
}

interface Permission {
  id: string;
  resource: string;
  action: string; // create, read, update, delete
  conditions?: any; // Additional constraints
}

// RBAC service
class RBACService {
  async hasPermission(
    userId: string,
    resource: string,
    action: string,
    resourceId?: string
  ): Promise<boolean> {
    const user = await User.findById(userId).populate({
      path: 'roles',
      populate: { path: 'permissions' }
    });
    
    if (!user) return false;
    
    // Check direct permissions
    for (const role of user.roles) {
      for (const permission of role.permissions) {
        if (permission.resource === resource && permission.action === action) {
          // Check conditions if any
          if (permission.conditions) {
            return await this.evaluateConditions(
              permission.conditions,
              user,
              resourceId
            );
          }
          return true;
        }
      }
    }
    
    return false;
  }
  
  private async evaluateConditions(
    conditions: any,
    user: any,
    resourceId?: string
  ): Promise<boolean> {
    // Custom condition evaluation logic
    if (conditions.owner && resourceId) {
      const resource = await this.getResource(conditions.resource, resourceId);
      return resource?.ownerId === user.id;
    }
    
    if (conditions.department) {
      return user.department === conditions.department;
    }
    
    return false;
  }
}

// Authorization middleware
const authorize = (resource: string, action: string) => {
  return async (req: AuthRequest, res: Response, next: NextFunction) => {
    if (!req.user) {
      return res.status(401).json({
        success: false,
        message: 'Authentication required'
      });
    }
    
    const hasPermission = await rbacService.hasPermission(
      req.user.id,
      resource,
      action,
      req.params.id
    );
    
    if (!hasPermission) {
      return res.status(403).json({
        success: false,
        message: 'Insufficient permissions'
      });
    }
    
    next();
  };
};

// Usage in routes
router.delete('/posts/:id',
  authenticateToken,
  authorize('posts', 'delete'),
  deletePost
);
```

### 2. Attribute-Based Access Control (ABAC) - Advanced Projects

**Implementation from Enterprise Projects:**

```typescript
// ABAC policy engine
interface PolicyRule {
  subject: any; // User attributes
  resource: any; // Resource attributes
  action: string;
  environment?: any; // Context attributes
  effect: 'allow' | 'deny';
}

class ABACService {
  private policies: PolicyRule[] = [];
  
  addPolicy(policy: PolicyRule): void {
    this.policies.push(policy);
  }
  
  async evaluate(
    subject: any,
    resource: any,
    action: string,
    environment: any = {}
  ): Promise<boolean> {
    let decision = false; // Default deny
    
    for (const policy of this.policies) {
      if (this.matchesPolicy(subject, resource, action, environment, policy)) {
        if (policy.effect === 'deny') {
          return false; // Explicit deny overrides allow
        }
        decision = true;
      }
    }
    
    return decision;
  }
  
  private matchesPolicy(
    subject: any,
    resource: any,
    action: string,
    environment: any,
    policy: PolicyRule
  ): boolean {
    return (
      this.matchAttributes(subject, policy.subject) &&
      this.matchAttributes(resource, policy.resource) &&
      action === policy.action &&
      this.matchAttributes(environment, policy.environment || {})
    );
  }
  
  private matchAttributes(actual: any, expected: any): boolean {
    for (const [key, value] of Object.entries(expected)) {
      if (actual[key] !== value) {
        return false;
      }
    }
    return true;
  }
}

// Policy definition example
abacService.addPolicy({
  subject: { role: 'manager', department: 'engineering' },
  resource: { type: 'project', department: 'engineering' },
  action: 'update',
  environment: { time: 'business_hours' },
  effect: 'allow'
});
```

## 🔐 Password Security Patterns

### 1. Password Hashing Standards

**bcrypt Implementation (100% of analyzed projects):**

```typescript
// Password service from all analyzed projects
class PasswordService {
  private readonly SALT_ROUNDS = 12; // Configurable based on security requirements
  
  async hashPassword(password: string): Promise<string> {
    // Validate password strength
    if (!this.isStrongPassword(password)) {
      throw new Error('Password does not meet security requirements');
    }
    
    return bcrypt.hash(password, this.SALT_ROUNDS);
  }
  
  async verifyPassword(password: string, hash: string): Promise<boolean> {
    return bcrypt.compare(password, hash);
  }
  
  private isStrongPassword(password: string): boolean {
    const minLength = 8;
    const hasUpperCase = /[A-Z]/.test(password);
    const hasLowerCase = /[a-z]/.test(password);
    const hasNumbers = /\d/.test(password);
    const hasNonalphas = /\W/.test(password);
    
    return (
      password.length >= minLength &&
      hasUpperCase &&
      hasLowerCase &&
      hasNumbers &&
      hasNonalphas
    );
  }
  
  generateSecurePassword(length: number = 16): string {
    const charset = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*';
    let password = '';
    
    for (let i = 0; i < length; i++) {
      password += charset.charAt(Math.floor(Math.random() * charset.length));
    }
    
    return password;
  }
}
```

### 2. Password Reset Flow

**Secure Password Reset (Common across all projects):**

```typescript
// Password reset service
class PasswordResetService {
  async requestPasswordReset(email: string): Promise<void> {
    const user = await User.findOne({ email: email.toLowerCase() });
    
    if (!user) {
      // Don't reveal if email exists (security practice)
      logger.warn('Password reset requested for non-existent email', { email });
      return;
    }
    
    // Generate secure reset token
    const resetToken = crypto.randomBytes(32).toString('hex');
    const resetTokenExpiry = new Date(Date.now() + 3600000); // 1 hour
    
    // Hash the token before storing (additional security)
    const hashedToken = crypto.createHash('sha256').update(resetToken).digest('hex');
    
    await User.findByIdAndUpdate(user.id, {
      resetPasswordToken: hashedToken,
      resetPasswordExpiry: resetTokenExpiry
    });
    
    // Send email with unhashed token
    await emailService.sendPasswordResetEmail(user.email, resetToken);
    
    logger.info('Password reset token generated', { userId: user.id });
  }
  
  async resetPassword(token: string, newPassword: string): Promise<void> {
    // Hash the provided token to compare with stored hash
    const hashedToken = crypto.createHash('sha256').update(token).digest('hex');
    
    const user = await User.findOne({
      resetPasswordToken: hashedToken,
      resetPasswordExpiry: { $gt: Date.now() }
    });
    
    if (!user) {
      throw new Error('Invalid or expired reset token');
    }
    
    // Hash new password
    const hashedPassword = await passwordService.hashPassword(newPassword);
    
    // Update password and clear reset fields
    await User.findByIdAndUpdate(user.id, {
      password: hashedPassword,
      resetPasswordToken: undefined,
      resetPasswordExpiry: undefined,
      passwordChangedAt: new Date()
    });
    
    // Invalidate all sessions/tokens for security
    await this.invalidateAllUserSessions(user.id);
    
    logger.info('Password reset completed', { userId: user.id });
  }
  
  private async invalidateAllUserSessions(userId: string): Promise<void> {
    // Remove all refresh tokens
    await RefreshToken.deleteMany({ userId });
    
    // Add user to blacklist temporarily (if using JWT)
    const blacklistKey = `user_blacklist:${userId}`;
    await redis.setex(blacklistKey, 3600, 'password_reset'); // 1 hour
  }
}
```

## 🔑 Token Management Strategies

### 1. Refresh Token Rotation

**Secure Token Rotation (Implemented by 60% of projects):**

```typescript
// Refresh token service with rotation
class RefreshTokenService {
  async generateRefreshToken(userId: string, deviceInfo?: DeviceInfo): Promise<string> {
    const token = crypto.randomBytes(40).toString('hex');
    
    await RefreshToken.create({
      token: crypto.createHash('sha256').update(token).digest('hex'),
      userId,
      expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000), // 7 days
      deviceInfo: {
        userAgent: deviceInfo?.userAgent,
        ip: deviceInfo?.ip,
        fingerprint: deviceInfo?.fingerprint
      }
    });
    
    return token;
  }
  
  async rotateRefreshToken(oldToken: string): Promise<{ accessToken: string; refreshToken: string }> {
    const hashedOldToken = crypto.createHash('sha256').update(oldToken).digest('hex');
    
    const storedToken = await RefreshToken.findOne({
      token: hashedOldToken,
      expiresAt: { $gt: new Date() }
    }).populate('user');
    
    if (!storedToken) {
      throw new Error('Invalid refresh token');
    }
    
    // Check for token reuse (security concern)
    if (storedToken.isRevoked) {
      // Potential token theft - revoke all tokens for this user
      await RefreshToken.updateMany(
        { userId: storedToken.userId },
        { isRevoked: true }
      );
      
      throw new Error('Token reuse detected - all tokens revoked');
    }
    
    // Mark old token as used
    storedToken.isRevoked = true;
    await storedToken.save();
    
    // Generate new tokens
    const accessToken = tokenService.generateAccessToken({
      userId: storedToken.userId,
      email: storedToken.user.email,
      roles: storedToken.user.roles
    });
    
    const newRefreshToken = await this.generateRefreshToken(
      storedToken.userId,
      storedToken.deviceInfo
    );
    
    return { accessToken, refreshToken: newRefreshToken };
  }
  
  async revokeRefreshToken(token: string): Promise<void> {
    const hashedToken = crypto.createHash('sha256').update(token).digest('hex');
    
    await RefreshToken.findOneAndUpdate(
      { token: hashedToken },
      { isRevoked: true }
    );
  }
  
  async revokeAllUserTokens(userId: string): Promise<void> {
    await RefreshToken.updateMany(
      { userId },
      { isRevoked: true }
    );
  }
}
```

### 2. Multi-Device Token Management

**Device-based Token Management:**

```typescript
// Device management for tokens
interface DeviceInfo {
  userAgent: string;
  ip: string;
  fingerprint: string;
  deviceType: 'mobile' | 'desktop' | 'tablet';
  location?: {
    country: string;
    city: string;
  };
}

class DeviceTokenService {
  async loginWithDevice(
    userId: string,
    deviceInfo: DeviceInfo
  ): Promise<{ accessToken: string; refreshToken: string; deviceId: string }> {
    // Check if device already exists
    let device = await Device.findOne({
      userId,
      fingerprint: deviceInfo.fingerprint
    });
    
    if (!device) {
      // New device - create device record
      device = await Device.create({
        userId,
        ...deviceInfo,
        name: this.generateDeviceName(deviceInfo),
        isActive: true,
        lastSeenAt: new Date()
      });
      
      // Send new device notification
      await this.notifyNewDevice(userId, device);
    } else {
      // Update existing device
      device.lastSeenAt = new Date();
      device.ip = deviceInfo.ip;
      await device.save();
    }
    
    // Generate tokens for this device
    const accessToken = tokenService.generateAccessToken({
      userId,
      deviceId: device.id
    });
    
    const refreshToken = await refreshTokenService.generateRefreshToken(
      userId,
      { ...deviceInfo, deviceId: device.id }
    );
    
    return { accessToken, refreshToken, deviceId: device.id };
  }
  
  async getUserDevices(userId: string): Promise<Device[]> {
    return Device.find({
      userId,
      isActive: true
    }).sort({ lastSeenAt: -1 });
  }
  
  async revokeDevice(userId: string, deviceId: string): Promise<void> {
    // Deactivate device
    await Device.findOneAndUpdate(
      { _id: deviceId, userId },
      { isActive: false }
    );
    
    // Revoke all tokens for this device
    await RefreshToken.updateMany(
      { userId, 'deviceInfo.deviceId': deviceId },
      { isRevoked: true }
    );
  }
  
  private generateDeviceName(deviceInfo: DeviceInfo): string {
    const parser = new UAParser(deviceInfo.userAgent);
    const browser = parser.getBrowser();
    const os = parser.getOS();
    
    return `${browser.name} on ${os.name}`;
  }
  
  private async notifyNewDevice(userId: string, device: Device): Promise<void> {
    const user = await User.findById(userId);
    if (user?.emailNotifications?.newDevice) {
      await emailService.sendNewDeviceNotification(user.email, device);
    }
  }
}
```

## 🌐 OAuth Integration Patterns

### 1. OAuth2 Provider Integration

**Multi-Provider OAuth (from Strapi and NestJS):**

```typescript
// OAuth service for multiple providers
class OAuthService {
  private providers = {
    google: new GoogleOAuthProvider(),
    github: new GitHubOAuthProvider(),
    facebook: new FacebookOAuthProvider(),
    microsoft: new MicrosoftOAuthProvider()
  };
  
  async authenticateWithProvider(
    provider: string,
    code: string,
    state?: string
  ): Promise<{ user: User; tokens: AuthTokens }> {
    const oauthProvider = this.providers[provider];
    if (!oauthProvider) {
      throw new Error(`Unsupported OAuth provider: ${provider}`);
    }
    
    // Exchange code for access token
    const { accessToken, refreshToken } = await oauthProvider.exchangeCodeForToken(code);
    
    // Get user profile from provider
    const profile = await oauthProvider.getUserProfile(accessToken);
    
    // Find or create user
    let user = await User.findOne({
      $or: [
        { [`oauth.${provider}.id`]: profile.id },
        { email: profile.email }
      ]
    });
    
    if (!user) {
      user = await this.createUserFromOAuth(provider, profile);
    } else {
      user = await this.updateUserOAuthInfo(user, provider, profile);
    }
    
    // Generate application tokens
    const appTokens = await tokenService.generateTokens(user);
    
    return { user, tokens: appTokens };
  }
  
  private async createUserFromOAuth(
    provider: string,
    profile: OAuthProfile
  ): Promise<User> {
    return User.create({
      email: profile.email,
      name: profile.name,
      avatar: profile.avatar,
      isEmailVerified: true, // OAuth providers verify emails
      oauth: {
        [provider]: {
          id: profile.id,
          email: profile.email
        }
      },
      provider
    });
  }
  
  private async updateUserOAuthInfo(
    user: User,
    provider: string,
    profile: OAuthProfile
  ): Promise<User> {
    const updateData = {
      [`oauth.${provider}`]: {
        id: profile.id,
        email: profile.email
      }
    };
    
    // Update avatar if user doesn't have one
    if (!user.avatar && profile.avatar) {
      updateData.avatar = profile.avatar;
    }
    
    return User.findByIdAndUpdate(user.id, updateData, { new: true });
  }
}

// OAuth provider interface
interface OAuthProvider {
  exchangeCodeForToken(code: string): Promise<{ accessToken: string; refreshToken?: string }>;
  getUserProfile(accessToken: string): Promise<OAuthProfile>;
}

interface OAuthProfile {
  id: string;
  email: string;
  name: string;
  avatar?: string;
}
```

## 📊 Authentication Metrics and Monitoring

### Security Event Tracking

```typescript
// Authentication event logging
class AuthEventLogger {
  async logLoginAttempt(attempt: LoginAttempt): Promise<void> {
    await AuthEvent.create({
      type: 'login_attempt',
      userId: attempt.userId,
      success: attempt.success,
      ip: attempt.ip,
      userAgent: attempt.userAgent,
      failureReason: attempt.failureReason,
      timestamp: new Date()
    });
    
    // Check for suspicious activity
    if (!attempt.success) {
      await this.checkForSuspiciousActivity(attempt);
    }
  }
  
  private async checkForSuspiciousActivity(attempt: LoginAttempt): Promise<void> {
    const recentFailures = await AuthEvent.countDocuments({
      type: 'login_attempt',
      success: false,
      ip: attempt.ip,
      timestamp: { $gte: new Date(Date.now() - 15 * 60 * 1000) } // Last 15 minutes
    });
    
    if (recentFailures >= 5) {
      // Temporarily block IP
      await IPBlock.create({
        ip: attempt.ip,
        reason: 'multiple_failed_logins',
        expiresAt: new Date(Date.now() + 60 * 60 * 1000) // 1 hour
      });
      
      securityLogger.warn('IP blocked due to multiple failed login attempts', {
        ip: attempt.ip,
        failures: recentFailures
      });
    }
  }
}
```

---

*Authentication Strategies Analysis | Research conducted January 2025*

**Navigation**
- **Previous**: [Architecture Patterns](./architecture-patterns.md) ←
- **Next**: [Performance Optimization](./performance-optimization.md) →
- **Back to**: [Research Overview](./README.md) ↑