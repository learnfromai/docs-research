# Security Best Practices in Express.js Applications

## 🔐 Security Overview

Security is paramount in production Express.js applications. This analysis examines comprehensive security implementations found in mature open source projects, covering authentication, authorization, input validation, and protection against common vulnerabilities.

---

## 🛡️ Fundamental Security Principles

### 1. Defense in Depth
Implement multiple layers of security controls to protect against various attack vectors.

```typescript
// Multi-layer security middleware stack
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'", "'unsafe-inline'", "cdn.jsdelivr.net"],
      styleSrc: ["'self'", "'unsafe-inline'", "fonts.googleapis.com"],
      fontSrc: ["'self'", "fonts.gstatic.com"],
      imgSrc: ["'self'", "data:", "https:"],
    },
  },
  hsts: {
    maxAge: 31536000,
    includeSubDomains: true,
    preload: true,
  },
}));

app.use(cors({
  origin: process.env.NODE_ENV === 'production' 
    ? ['https://myapp.com', 'https://api.myapp.com']
    : ['http://localhost:3000', 'http://localhost:3001'],
  credentials: true,
  optionsSuccessStatus: 200,
}));

app.use(rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // limit each IP to 100 requests per windowMs
  message: 'Too many requests from this IP',
  standardHeaders: true,
  legacyHeaders: false,
}));
```

### 2. Least Privilege Principle
Grant minimum necessary permissions and access rights.

```typescript
// Role-based access control implementation
enum Permission {
  READ_USER = 'read:user',
  WRITE_USER = 'write:user',
  DELETE_USER = 'delete:user',
  READ_ADMIN = 'read:admin',
  WRITE_ADMIN = 'write:admin',
}

class RolePermissionService {
  private rolePermissions = new Map([
    ['user', [Permission.READ_USER]],
    ['moderator', [Permission.READ_USER, Permission.WRITE_USER]],
    ['admin', [Permission.READ_USER, Permission.WRITE_USER, Permission.DELETE_USER]],
    ['super_admin', Object.values(Permission)],
  ]);

  hasPermission(userRole: string, requiredPermission: Permission): boolean {
    const permissions = this.rolePermissions.get(userRole) || [];
    return permissions.includes(requiredPermission);
  }
}

// Permission-based route protection
const requirePermission = (permission: Permission) => {
  return async (req: Request, res: Response, next: NextFunction) => {
    const user = req.user;
    if (!user) {
      return res.status(401).json({ error: 'Authentication required' });
    }

    if (!rolePermissionService.hasPermission(user.role, permission)) {
      return res.status(403).json({ error: 'Insufficient permissions' });
    }

    next();
  };
};

// Usage in routes
app.get('/api/users', 
  authenticateToken, 
  requirePermission(Permission.READ_USER), 
  userController.getUsers
);

app.delete('/api/users/:id', 
  authenticateToken, 
  requirePermission(Permission.DELETE_USER), 
  userController.deleteUser
);
```

---

## 🔑 Authentication Strategies

### 1. JWT-Based Authentication (Most Common)

```typescript
// Secure JWT implementation with refresh tokens
interface JWTPayload {
  userId: string;
  email: string;
  role: string;
  sessionId: string;
}

class AuthService {
  private readonly jwtSecret = process.env.JWT_SECRET!;
  private readonly refreshSecret = process.env.REFRESH_SECRET!;
  private readonly accessTokenExpiry = '15m';
  private readonly refreshTokenExpiry = '7d';

  async generateTokens(user: User): Promise<TokenPair> {
    const sessionId = uuid();
    
    const payload: JWTPayload = {
      userId: user.id,
      email: user.email,
      role: user.role,
      sessionId,
    };

    const accessToken = jwt.sign(payload, this.jwtSecret, {
      expiresIn: this.accessTokenExpiry,
      issuer: 'myapp',
      audience: 'myapp-api',
    });

    const refreshToken = jwt.sign(
      { userId: user.id, sessionId },
      this.refreshSecret,
      { expiresIn: this.refreshTokenExpiry }
    );

    // Store refresh token in database with expiration
    await this.tokenRepository.saveRefreshToken({
      userId: user.id,
      sessionId,
      token: await bcrypt.hash(refreshToken, 10),
      expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
    });

    return { accessToken, refreshToken };
  }

  async validateAccessToken(token: string): Promise<JWTPayload | null> {
    try {
      const decoded = jwt.verify(token, this.jwtSecret, {
        issuer: 'myapp',
        audience: 'myapp-api',
      }) as JWTPayload;

      // Check if session is still valid
      const isValidSession = await this.tokenRepository.isSessionValid(
        decoded.userId,
        decoded.sessionId
      );

      return isValidSession ? decoded : null;
    } catch (error) {
      return null;
    }
  }

  async refreshTokens(refreshToken: string): Promise<TokenPair | null> {
    try {
      const decoded = jwt.verify(refreshToken, this.refreshSecret) as any;
      
      // Validate refresh token in database
      const storedToken = await this.tokenRepository.getRefreshToken(
        decoded.userId,
        decoded.sessionId
      );

      if (!storedToken || !await bcrypt.compare(refreshToken, storedToken.token)) {
        throw new Error('Invalid refresh token');
      }

      // Generate new token pair
      const user = await this.userRepository.findById(decoded.userId);
      if (!user) throw new Error('User not found');

      // Revoke old refresh token
      await this.tokenRepository.revokeRefreshToken(decoded.userId, decoded.sessionId);

      return await this.generateTokens(user);
    } catch (error) {
      return null;
    }
  }
}

// Authentication middleware
const authenticateToken = async (req: Request, res: Response, next: NextFunction) => {
  const authHeader = req.headers.authorization;
  const token = authHeader?.startsWith('Bearer ') ? authHeader.slice(7) : null;

  if (!token) {
    return res.status(401).json({ error: 'Access token required' });
  }

  const payload = await authService.validateAccessToken(token);
  if (!payload) {
    return res.status(401).json({ error: 'Invalid or expired token' });
  }

  req.user = payload;
  next();
};
```

### 2. OAuth 2.0 / OIDC Integration

```typescript
// OAuth integration with Passport.js
import passport from 'passport';
import { Strategy as GoogleStrategy } from 'passport-google-oauth20';
import { Strategy as GitHubStrategy } from 'passport-github2';

// Google OAuth strategy
passport.use(new GoogleStrategy({
  clientID: process.env.GOOGLE_CLIENT_ID!,
  clientSecret: process.env.GOOGLE_CLIENT_SECRET!,
  callbackURL: '/auth/google/callback',
}, async (accessToken, refreshToken, profile, done) => {
  try {
    // Check if user exists
    let user = await userRepository.findByEmail(profile.emails![0].value);
    
    if (!user) {
      // Create new user
      user = await userRepository.create({
        email: profile.emails![0].value,
        name: profile.displayName,
        provider: 'google',
        providerId: profile.id,
        avatar: profile.photos?.[0]?.value,
      });
    }

    return done(null, user);
  } catch (error) {
    return done(error, null);
  }
}));

// OAuth routes
app.get('/auth/google', 
  passport.authenticate('google', { scope: ['profile', 'email'] })
);

app.get('/auth/google/callback',
  passport.authenticate('google', { session: false }),
  async (req, res) => {
    const tokens = await authService.generateTokens(req.user as User);
    
    // Set secure HTTP-only cookies
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

    res.redirect('/dashboard');
  }
);
```

### 3. Session-Based Authentication (Traditional)

```typescript
// Secure session configuration
import session from 'express-session';
import RedisStore from 'connect-redis';
import Redis from 'ioredis';

const redis = new Redis({
  host: process.env.REDIS_HOST,
  port: parseInt(process.env.REDIS_PORT!),
  password: process.env.REDIS_PASSWORD,
  retryDelayOnFailover: 100,
  maxRetriesPerRequest: 3,
});

app.use(session({
  store: new RedisStore({ client: redis }),
  secret: process.env.SESSION_SECRET!,
  name: 'sessionId',
  resave: false,
  saveUninitialized: false,
  cookie: {
    secure: process.env.NODE_ENV === 'production',
    httpOnly: true,
    maxAge: 24 * 60 * 60 * 1000, // 24 hours
    sameSite: 'strict',
  },
  genid: () => uuid(),
}));

// Session-based authentication middleware
const requireAuth = (req: Request, res: Response, next: NextFunction) => {
  if (!req.session.userId) {
    return res.status(401).json({ error: 'Authentication required' });
  }
  next();
};

// Login endpoint
app.post('/auth/login', async (req, res) => {
  const { email, password } = req.body;
  
  const user = await userRepository.findByEmail(email);
  if (!user || !await bcrypt.compare(password, user.password)) {
    return res.status(401).json({ error: 'Invalid credentials' });
  }

  // Create session
  req.session.userId = user.id;
  req.session.userRole = user.role;
  
  res.json({ message: 'Login successful', user: user.toPublic() });
});
```

---

## 🔒 Input Validation & Sanitization

### 1. Request Validation with Joi

```typescript
import Joi from 'joi';

// Validation schemas
const userCreateSchema = Joi.object({
  email: Joi.string().email().required(),
  password: Joi.string().min(8).pattern(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]/).required(),
  name: Joi.string().min(2).max(50).required(),
  role: Joi.string().valid('user', 'admin').default('user'),
});

const userUpdateSchema = Joi.object({
  name: Joi.string().min(2).max(50),
  email: Joi.string().email(),
  role: Joi.string().valid('user', 'admin'),
}).min(1);

// Validation middleware
const validate = (schema: Joi.ObjectSchema) => {
  return (req: Request, res: Response, next: NextFunction) => {
    const { error, value } = schema.validate(req.body, {
      abortEarly: false,
      stripUnknown: true,
    });

    if (error) {
      const errors = error.details.map(detail => ({
        field: detail.path.join('.'),
        message: detail.message,
      }));
      
      return res.status(400).json({
        error: 'Validation failed',
        details: errors,
      });
    }

    req.body = value;
    next();
  };
};

// Usage in routes
app.post('/api/users', 
  validate(userCreateSchema), 
  userController.createUser
);

app.put('/api/users/:id', 
  validate(userUpdateSchema), 
  userController.updateUser
);
```

### 2. SQL Injection Prevention

```typescript
// Parameterized queries with Prisma
class UserRepository {
  async findByEmail(email: string): Promise<User | null> {
    return await prisma.user.findUnique({
      where: { email },
      select: {
        id: true,
        email: true,
        name: true,
        role: true,
        createdAt: true,
      },
    });
  }

  async findWithFilters(filters: UserFilters): Promise<User[]> {
    const where: Prisma.UserWhereInput = {};
    
    if (filters.email) {
      where.email = { contains: filters.email, mode: 'insensitive' };
    }
    
    if (filters.role) {
      where.role = filters.role;
    }
    
    if (filters.createdAfter) {
      where.createdAt = { gte: filters.createdAfter };
    }

    return await prisma.user.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      take: filters.limit || 50,
      skip: filters.offset || 0,
    });
  }
}

// Raw query safety (when necessary)
class AnalyticsRepository {
  async getUserStats(filters: StatsFilters): Promise<UserStats> {
    // Validate and sanitize inputs
    const validatedFilters = this.validateStatsFilters(filters);
    
    // Use parameterized raw query
    const result = await prisma.$queryRaw`
      SELECT 
        COUNT(*) as total_users,
        COUNT(CASE WHEN created_at >= ${validatedFilters.startDate} THEN 1 END) as new_users
      FROM users 
      WHERE role = ${validatedFilters.role}
      AND created_at BETWEEN ${validatedFilters.startDate} AND ${validatedFilters.endDate}
    `;
    
    return result[0];
  }
}
```

### 3. XSS Prevention

```typescript
import DOMPurify from 'isomorphic-dompurify';
import { escape } from 'html-escaper';

// Content sanitization middleware
const sanitizeHtml = (req: Request, res: Response, next: NextFunction) => {
  if (req.body && typeof req.body === 'object') {
    req.body = sanitizeObject(req.body);
  }
  next();
};

function sanitizeObject(obj: any): any {
  if (typeof obj === 'string') {
    return DOMPurify.sanitize(obj, {
      ALLOWED_TAGS: ['p', 'br', 'strong', 'em', 'a', 'ul', 'ol', 'li'],
      ALLOWED_ATTR: ['href', 'target'],
    });
  }
  
  if (Array.isArray(obj)) {
    return obj.map(sanitizeObject);
  }
  
  if (obj && typeof obj === 'object') {
    const sanitized: any = {};
    for (const [key, value] of Object.entries(obj)) {
      sanitized[key] = sanitizeObject(value);
    }
    return sanitized;
  }
  
  return obj;
}

// Safe output rendering
class ResponseHelper {
  static safeJson(res: Response, data: any): void {
    // Escape potentially dangerous content
    const safeData = this.escapeObject(data);
    res.json(safeData);
  }

  private static escapeObject(obj: any): any {
    if (typeof obj === 'string') {
      return escape(obj);
    }
    
    if (Array.isArray(obj)) {
      return obj.map(this.escapeObject.bind(this));
    }
    
    if (obj && typeof obj === 'object') {
      const escaped: any = {};
      for (const [key, value] of Object.entries(obj)) {
        escaped[key] = this.escapeObject(value);
      }
      return escaped;
    }
    
    return obj;
  }
}
```

---

## 🚫 CSRF Protection

```typescript
import csrf from 'csurf';

// CSRF protection setup
const csrfProtection = csrf({
  cookie: {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'strict',
  },
});

// Apply CSRF protection to state-changing routes
app.use('/api', csrfProtection);

// CSRF token endpoint
app.get('/api/csrf-token', (req, res) => {
  res.json({ csrfToken: req.csrfToken() });
});

// Double submit cookie pattern (alternative)
class CSRFProtection {
  generateToken(): string {
    return crypto.randomBytes(32).toString('hex');
  }

  middleware() {
    return (req: Request, res: Response, next: NextFunction) => {
      if (['GET', 'HEAD', 'OPTIONS'].includes(req.method)) {
        return next();
      }

      const token = req.headers['x-csrf-token'] as string;
      const cookieToken = req.cookies.csrfToken;

      if (!token || !cookieToken || token !== cookieToken) {
        return res.status(403).json({ error: 'CSRF token mismatch' });
      }

      next();
    };
  }
}
```

---

## 🔐 Password Security

```typescript
import bcrypt from 'bcrypt';
import { promisify } from 'util';

class PasswordService {
  private readonly saltRounds = 12;

  async hashPassword(password: string): Promise<string> {
    this.validatePasswordStrength(password);
    return await bcrypt.hash(password, this.saltRounds);
  }

  async verifyPassword(password: string, hash: string): Promise<boolean> {
    return await bcrypt.compare(password, hash);
  }

  validatePasswordStrength(password: string): void {
    const minLength = 8;
    const hasUppercase = /[A-Z]/.test(password);
    const hasLowercase = /[a-z]/.test(password);
    const hasNumbers = /\d/.test(password);
    const hasSpecialChar = /[!@#$%^&*(),.?":{}|<>]/.test(password);

    if (password.length < minLength) {
      throw new Error(`Password must be at least ${minLength} characters long`);
    }

    if (!hasUppercase) {
      throw new Error('Password must contain at least one uppercase letter');
    }

    if (!hasLowercase) {
      throw new Error('Password must contain at least one lowercase letter');
    }

    if (!hasNumbers) {
      throw new Error('Password must contain at least one number');
    }

    if (!hasSpecialChar) {
      throw new Error('Password must contain at least one special character');
    }

    // Check against common passwords
    if (this.isCommonPassword(password)) {
      throw new Error('Password is too common');
    }
  }

  private isCommonPassword(password: string): boolean {
    const commonPasswords = [
      'password', '123456', 'password123', 'admin', 'qwerty',
      '12345678', '123456789', '1234567890', 'abc123',
    ];
    
    return commonPasswords.includes(password.toLowerCase());
  }
}

// Password reset with secure tokens
class PasswordResetService {
  async generateResetToken(userId: string): Promise<string> {
    const token = crypto.randomBytes(32).toString('hex');
    const hashedToken = crypto.createHash('sha256').update(token).digest('hex');
    
    await this.tokenRepository.savePasswordResetToken({
      userId,
      token: hashedToken,
      expiresAt: new Date(Date.now() + 60 * 60 * 1000), // 1 hour
    });

    return token;
  }

  async resetPassword(token: string, newPassword: string): Promise<void> {
    const hashedToken = crypto.createHash('sha256').update(token).digest('hex');
    
    const resetToken = await this.tokenRepository.findPasswordResetToken(hashedToken);
    if (!resetToken || resetToken.expiresAt < new Date()) {
      throw new Error('Invalid or expired reset token');
    }

    const hashedPassword = await passwordService.hashPassword(newPassword);
    await this.userRepository.updatePassword(resetToken.userId, hashedPassword);
    await this.tokenRepository.deletePasswordResetToken(hashedToken);
  }
}
```

---

## 📊 Security Monitoring & Logging

```typescript
import winston from 'winston';

// Security event logging
class SecurityLogger {
  private logger = winston.createLogger({
    level: 'info',
    format: winston.format.combine(
      winston.format.timestamp(),
      winston.format.errors({ stack: true }),
      winston.format.json()
    ),
    transports: [
      new winston.transports.File({ filename: 'logs/security.log' }),
      new winston.transports.Console({ format: winston.format.simple() }),
    ],
  });

  logAuthenticationAttempt(email: string, ip: string, success: boolean): void {
    this.logger.info('Authentication attempt', {
      type: 'auth_attempt',
      email,
      ip,
      success,
      timestamp: new Date().toISOString(),
    });
  }

  logSuspiciousActivity(userId: string, activity: string, details: any): void {
    this.logger.warn('Suspicious activity detected', {
      type: 'suspicious_activity',
      userId,
      activity,
      details,
      timestamp: new Date().toISOString(),
    });
  }

  logSecurityEvent(event: string, details: any): void {
    this.logger.error('Security event', {
      type: 'security_event',
      event,
      details,
      timestamp: new Date().toISOString(),
    });
  }
}

// Rate limiting with security logging
class SecurityRateLimiter {
  private attempts = new Map<string, { count: number; lastAttempt: Date }>();

  middleware() {
    return (req: Request, res: Response, next: NextFunction) => {
      const ip = req.ip;
      const now = new Date();
      const windowMs = 15 * 60 * 1000; // 15 minutes
      const maxAttempts = 5;

      const attemptData = this.attempts.get(ip) || { count: 0, lastAttempt: now };
      
      // Reset counter if window has passed
      if (now.getTime() - attemptData.lastAttempt.getTime() > windowMs) {
        attemptData.count = 0;
      }

      attemptData.count++;
      attemptData.lastAttempt = now;
      this.attempts.set(ip, attemptData);

      if (attemptData.count > maxAttempts) {
        securityLogger.logSuspiciousActivity('system', 'rate_limit_exceeded', {
          ip,
          attempts: attemptData.count,
          endpoint: req.path,
        });

        return res.status(429).json({
          error: 'Too many requests',
          retryAfter: Math.ceil(windowMs / 1000),
        });
      }

      next();
    };
  }
}
```

---

## 🔗 Navigation

← [Architecture Patterns](./architecture-patterns.md) | [Authentication Strategies](./authentication-strategies.md) →

---

*Security analysis: July 2025 | Coverage: Authentication, validation, protection patterns*