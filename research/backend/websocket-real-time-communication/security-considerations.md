# Security Considerations: WebSocket Real-Time Communication

## 🔒 WebSocket Security Fundamentals

### Security Challenges in Real-Time Communication

WebSocket connections present unique security challenges compared to traditional HTTP APIs:

1. **Long-lived connections** increase attack surface exposure
2. **Bidirectional communication** allows both client and server-initiated attacks  
3. **State management** requires careful session handling
4. **Origin validation** becomes more complex than HTTP requests
5. **Rate limiting** needs different approaches than REST APIs

## 🛡️ Authentication & Authorization

### JWT-Based Authentication for WebSocket

#### Secure Token Implementation

```typescript
// Enhanced JWT authentication with security best practices
import jwt from 'jsonwebtoken';
import crypto from 'crypto';
import { Redis } from 'ioredis';

interface SecureTokenPayload {
  userId: string;
  username: string;
  role: string;
  permissions: string[];
  sessionId: string;
  deviceFingerprint: string;
  iat: number;
  exp: number;
  jti: string; // JWT ID for revocation
}

class SecureAuthenticationService {
  private redis: Redis;
  private accessTokenSecret: string;
  private refreshTokenSecret: string;
  
  constructor(redis: Redis) {
    this.redis = redis;
    // Use different secrets for different token types
    this.accessTokenSecret = process.env.JWT_ACCESS_SECRET!;
    this.refreshTokenSecret = process.env.JWT_REFRESH_SECRET!;
    
    if (this.accessTokenSecret.length < 32) {
      throw new Error('JWT_ACCESS_SECRET must be at least 32 characters');
    }
  }
  
  public async generateSecureTokenPair(
    user: {
      userId: string;
      username: string;
      role: string;
      permissions: string[];
    },
    deviceInfo: {
      userAgent: string;
      ipAddress: string;
    }
  ): Promise<{
    accessToken: string;
    refreshToken: string;
    expiresAt: Date;
    sessionId: string;
  }> {
    const sessionId = crypto.randomUUID();
    const jwtId = crypto.randomUUID();
    
    // Create device fingerprint for security
    const deviceFingerprint = this.createDeviceFingerprint(deviceInfo);
    
    // Short-lived access token (15 minutes)
    const accessTokenPayload: SecureTokenPayload = {
      userId: user.userId,
      username: user.username,
      role: user.role,
      permissions: user.permissions,
      sessionId,
      deviceFingerprint,
      iat: Math.floor(Date.now() / 1000),
      exp: Math.floor(Date.now() / 1000) + (15 * 60), // 15 minutes
      jti: jwtId
    };
    
    const accessToken = jwt.sign(
      accessTokenPayload,
      this.accessTokenSecret,
      {
        algorithm: 'HS256',
        issuer: 'edtech-platform',
        audience: 'websocket-api'
      }
    );
    
    // Long-lived refresh token (7 days) with rotation
    const refreshTokenId = crypto.randomUUID();
    const refreshToken = jwt.sign(
      {
        userId: user.userId,
        sessionId,
        tokenId: refreshTokenId,
        deviceFingerprint,
        type: 'refresh'
      },
      this.refreshTokenSecret,
      { 
        expiresIn: '7d',
        algorithm: 'HS256',
        issuer: 'edtech-platform',
        audience: 'websocket-api'
      }
    );
    
    // Store session metadata in Redis
    const sessionKey = `session:${sessionId}`;
    await this.redis.setex(sessionKey, 7 * 24 * 60 * 60, JSON.stringify({
      userId: user.userId,
      username: user.username,
      role: user.role,
      permissions: user.permissions,
      deviceFingerprint,
      ipAddress: deviceInfo.ipAddress,
      userAgent: deviceInfo.userAgent,
      createdAt: new Date().toISOString(),
      lastActivity: new Date().toISOString()
    }));
    
    // Store active JWT IDs for revocation tracking
    await this.redis.setex(`jwt:${jwtId}`, 15 * 60, sessionId);
    await this.redis.setex(`refresh:${refreshTokenId}`, 7 * 24 * 60 * 60, sessionId);
    
    // Track active sessions per user (for concurrent session management)
    await this.redis.sadd(`user:sessions:${user.userId}`, sessionId);
    await this.redis.expire(`user:sessions:${user.userId}`, 7 * 24 * 60 * 60);
    
    return {
      accessToken,
      refreshToken,
      expiresAt: new Date(Date.now() + 15 * 60 * 1000),
      sessionId
    };
  }
  
  public async verifySecureToken(
    token: string,
    deviceInfo: {
      userAgent: string;
      ipAddress: string;
    }
  ): Promise<SecureTokenPayload | null> {
    try {
      // Verify token signature and expiration
      const payload = jwt.verify(
        token,
        this.accessTokenSecret,
        {
          algorithms: ['HS256'],
          issuer: 'edtech-platform',
          audience: 'websocket-api'
        }
      ) as SecureTokenPayload;
      
      // Check if JWT ID is still valid (not revoked)
      const sessionId = await this.redis.get(`jwt:${payload.jti}`);
      if (!sessionId) {
        throw new Error('Token has been revoked');
      }
      
      // Verify session is still active
      const sessionData = await this.redis.get(`session:${payload.sessionId}`);
      if (!sessionData) {
        throw new Error('Session has expired');
      }
      
      // Verify device fingerprint for additional security
      const currentFingerprint = this.createDeviceFingerprint(deviceInfo);
      if (payload.deviceFingerprint !== currentFingerprint) {
        // Log potential token theft attempt
        console.warn('Token used from different device:', {
          userId: payload.userId,
          sessionId: payload.sessionId,
          expectedFingerprint: payload.deviceFingerprint,
          actualFingerprint: currentFingerprint
        });
        
        // Optionally revoke session on fingerprint mismatch
        await this.revokeSession(payload.sessionId);
        throw new Error('Device fingerprint mismatch');
      }
      
      // Update last activity
      const session = JSON.parse(sessionData);
      session.lastActivity = new Date().toISOString();
      await this.redis.setex(
        `session:${payload.sessionId}`,
        7 * 24 * 60 * 60, // Reset expiration
        JSON.stringify(session)
      );
      
      return payload;
    } catch (error) {
      console.error('Token verification failed:', error.message);
      return null;
    }
  }
  
  private createDeviceFingerprint(deviceInfo: {
    userAgent: string;
    ipAddress: string;
  }): string {
    const fingerprint = `${deviceInfo.userAgent}:${deviceInfo.ipAddress}`;
    return crypto.createHash('sha256').update(fingerprint).digest('hex').substring(0, 16);
  }
  
  public async revokeSession(sessionId: string): Promise<void> {
    // Get session data to find associated JWTs
    const sessionData = await this.redis.get(`session:${sessionId}`);
    if (!sessionData) return;
    
    const session = JSON.parse(sessionData);
    
    // Remove from user's active sessions
    await this.redis.srem(`user:sessions:${session.userId}`, sessionId);
    
    // Delete session data
    await this.redis.del(`session:${sessionId}`);
    
    // Revoke all JWTs for this session
    // This is a simplified approach - in production, you'd track all JWTs per session
    const keys = await this.redis.keys(`jwt:*`);
    for (const key of keys) {
      const jwtSessionId = await this.redis.get(key);
      if (jwtSessionId === sessionId) {
        await this.redis.del(key);
      }
    }
    
    // Similar for refresh tokens
    const refreshKeys = await this.redis.keys(`refresh:*`);
    for (const key of refreshKeys) {
      const refreshSessionId = await this.redis.get(key);
      if (refreshSessionId === sessionId) {
        await this.redis.del(key);
      }
    }
  }
  
  public async limitConcurrentSessions(
    userId: string,
    maxSessions: number = 5
  ): Promise<void> {
    const sessionsKey = `user:sessions:${userId}`;
    const activeSessions = await this.redis.smembers(sessionsKey);
    
    if (activeSessions.length > maxSessions) {
      // Sort sessions by last activity and remove oldest
      const sessionActivities = await Promise.all(
        activeSessions.map(async (sessionId) => {
          const sessionData = await this.redis.get(`session:${sessionId}`);
          if (!sessionData) return null;
          
          const session = JSON.parse(sessionData);
          return {
            sessionId,
            lastActivity: new Date(session.lastActivity)
          };
        })
      );
      
      const validSessions = sessionActivities
        .filter(s => s !== null)
        .sort((a, b) => a!.lastActivity.getTime() - b!.lastActivity.getTime());
      
      // Revoke oldest sessions
      const sessionsToRevoke = validSessions.slice(0, validSessions.length - maxSessions);
      for (const session of sessionsToRevoke) {
        await this.revokeSession(session!.sessionId);
      }
    }
  }
}
```

#### WebSocket Authentication Middleware

```typescript
// Secure WebSocket authentication middleware
import { Socket } from 'socket.io';
import { SecureAuthenticationService } from './auth-service';

interface AuthenticatedSocket extends Socket {
  userId?: string;
  username?: string;
  role?: string;
  permissions?: string[];
  sessionId?: string;
}

export class WebSocketAuthMiddleware {
  constructor(private authService: SecureAuthenticationService) {}
  
  public authenticate() {
    return async (socket: AuthenticatedSocket, next: (err?: Error) => void) => {
      try {
        // Extract token from handshake
        const token = socket.handshake.auth.token || 
                     socket.handshake.headers.authorization?.replace('Bearer ', '');
        
        if (!token) {
          return next(new Error('Authentication token required'));
        }
        
        // Get device information
        const deviceInfo = {
          userAgent: socket.handshake.headers['user-agent'] || '',
          ipAddress: socket.handshake.address
        };
        
        // Verify token
        const payload = await this.authService.verifySecureToken(token, deviceInfo);
        if (!payload) {
          return next(new Error('Invalid or expired token'));
        }
        
        // Attach user information to socket
        socket.userId = payload.userId;
        socket.username = payload.username;
        socket.role = payload.role;
        socket.permissions = payload.permissions;
        socket.sessionId = payload.sessionId;
        
        // Set up session cleanup on disconnect
        socket.on('disconnect', async () => {
          // Update last activity to mark session as inactive
          console.log(`User ${payload.username} disconnected from session ${payload.sessionId}`);
        });
        
        next();
      } catch (error) {
        console.error('WebSocket authentication error:', error);
        next(new Error('Authentication failed'));
      }
    };
  }
  
  public requirePermission(resource: string, action: string) {
    return (socket: AuthenticatedSocket, next: (err?: Error) => void) => {
      if (!socket.permissions) {
        return next(new Error('User permissions not available'));
      }
      
      const hasPermission = this.checkPermission(
        socket.permissions,
        socket.role!,
        resource,
        action
      );
      
      if (!hasPermission) {
        return next(new Error(`Insufficient permissions for ${resource}:${action}`));
      }
      
      next();
    };
  }
  
  private checkPermission(
    userPermissions: string[],
    userRole: string,
    resource: string,
    action: string
  ): boolean {
    // Check for wildcard permissions
    if (userPermissions.includes('*') || userRole === 'admin') {
      return true;
    }
    
    // Check specific permission
    const permission = `${resource}:${action}`;
    if (userPermissions.includes(permission)) {
      return true;
    }
    
    // Check resource wildcard
    const resourceWildcard = `${resource}:*`;
    if (userPermissions.includes(resourceWildcard)) {
      return true;
    }
    
    return false;
  }
}
```

## 🚫 Input Validation & Sanitization

### Comprehensive Message Validation

```typescript
// Advanced input validation for WebSocket messages
import Joi from 'joi';
import DOMPurify from 'isomorphic-dompurify';
import rateLimit from 'express-rate-limit';

interface ValidationRule {
  schema: Joi.Schema;
  sanitizers: Array<(data: any) => any>;
  rateLimit?: {
    windowMs: number;
    maxRequests: number;
  };
}

class MessageValidator {
  private validationRules = new Map<string, ValidationRule>();
  private rateLimiters = new Map<string, any>();
  
  constructor() {
    this.setupValidationRules();
    this.setupRateLimiters();
  }
  
  private setupValidationRules() {
    // Chat message validation
    this.validationRules.set('chat:message', {
      schema: Joi.object({
        content: Joi.string()
          .min(1)
          .max(2000)
          .pattern(/^[^<>]*$/) // Basic HTML injection prevention
          .required(),
        roomId: Joi.string().uuid().required(),
        type: Joi.string().valid('text', 'image', 'file').default('text'),
        replyTo: Joi.string().uuid().optional(),
        mentions: Joi.array().items(Joi.string().uuid()).max(10).optional()
      }),
      sanitizers: [
        this.sanitizeHtml,
        this.sanitizeUrls,  
        this.filterProfanity
      ],
      rateLimit: {
        windowMs: 60000, // 1 minute
        maxRequests: 30  // 30 messages per minute
      }
    });
    
    // Quiz answer validation
    this.validationRules.set('quiz:answer', {
      schema: Joi.object({
        sessionId: Joi.string().uuid().required(),
        questionId: Joi.string().uuid().required(),
        answer: Joi.alternatives().try(
          Joi.number().integer().min(0).max(10),
          Joi.string().max(500).pattern(/^[a-zA-Z0-9\s.,!?-]*$/),
          Joi.array().items(Joi.number().integer().min(0).max(10)).max(5)
        ).required(),
        timeSpent: Joi.number().integer().min(0).max(300).optional() // seconds
      }),
      sanitizers: [
        this.sanitizeQuizAnswer
      ],
      rateLimit: {
        windowMs: 10000, // 10 seconds
        maxRequests: 5   // Max 5 answers per 10 seconds
      }
    });
    
    // File upload validation
    this.validationRules.set('file:upload', {
      schema: Joi.object({
        fileName: Joi.string()
          .max(255)
          .pattern(/^[a-zA-Z0-9._-]+$/) // Safe filename characters only
          .required(),
        fileSize: Joi.number().integer().min(1).max(10 * 1024 * 1024).required(), // 10MB max
        mimeType: Joi.string().valid(
          'image/jpeg', 'image/png', 'image/gif',
          'application/pdf', 'text/plain',
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
        ).required(),
        roomId: Joi.string().uuid().required()
      }),
      sanitizers: [
        this.sanitizeFileName
      ],
      rateLimit: {
        windowMs: 300000, // 5 minutes
        maxRequests: 10   // 10 files per 5 minutes
      }
    });
  }
  
  public async validateMessage(
    messageType: string,
    payload: any,
    userId: string,
    ipAddress: string
  ): Promise<{
    isValid: boolean;
    data?: any;
    error?: string;
    rateLimited?: boolean;
  }> {
    const rule = this.validationRules.get(messageType);
    if (!rule) {
      return { isValid: false, error: 'Unknown message type' };
    }
    
    // Check rate limiting first
    if (rule.rateLimit) {
      const rateLimited = await this.checkRateLimit(
        messageType,
        userId,
        ipAddress,
        rule.rateLimit
      );
      
      if (rateLimited) {
        return { 
          isValid: false, 
          error: 'Rate limit exceeded',
          rateLimited: true 
        };
      }
    }
    
    // Validate schema
    const { error, value } = rule.schema.validate(payload, {
      abortEarly: false,
      stripUnknown: true
    });
    
    if (error) {
      return {
        isValid: false,
        error: `Validation error: ${error.details.map(d => d.message).join(', ')}`
      };
    }
    
    // Apply sanitizers
    let sanitizedData = value;
    for (const sanitizer of rule.sanitizers) {
      try {
        sanitizedData = await sanitizer(sanitizedData);
      } catch (sanitizeError) {
        return {
          isValid: false,
          error: 'Content sanitization failed'
        };
      }
    }
    
    return {
      isValid: true,
      data: sanitizedData
    };
  }
  
  private sanitizeHtml = (data: any): any => {
    if (data.content && typeof data.content === 'string') {
      // Allow only safe HTML tags for formatting
      data.content = DOMPurify.sanitize(data.content, {
        ALLOWED_TAGS: ['b', 'i', 'em', 'strong', 'code', 'pre', 'br'],
        ALLOWED_ATTR: [],
        KEEP_CONTENT: true
      });
    }
    return data;
  };
  
  private sanitizeUrls = (data: any): any => {
    if (data.content && typeof data.content === 'string') {
      // Replace URLs with safe, tracked versions
      const urlRegex = /(https?:\/\/[^\s]+)/g;
      data.content = data.content.replace(urlRegex, (url) => {
        try {
          const parsedUrl = new URL(url);
          
          // Block dangerous protocols
          if (!['http:', 'https:'].includes(parsedUrl.protocol)) {
            return '[BLOCKED URL]';
          }
          
          // Block suspicious domains (implement your blacklist)
          const suspiciousDomains = ['malware-site.com', 'phishing-site.net'];
          if (suspiciousDomains.includes(parsedUrl.hostname)) {
            return '[BLOCKED URL]';
          }
          
          return url;
        } catch {
          return '[INVALID URL]';
        }
      });
    }
    return data;
  };
  
  private filterProfanity = (data: any): any => {
    if (data.content && typeof data.content === 'string') {
      // Implement profanity filter (use a library like 'bad-words' in production)
      const profanityWords = ['badword1', 'badword2']; // Placeholder
      let content = data.content;
      
      profanityWords.forEach(word => {
        const regex = new RegExp(word, 'gi');
        content = content.replace(regex, '*'.repeat(word.length));
      });
      
      data.content = content;
    }
    return data;
  };
  
  private sanitizeQuizAnswer = (data: any): any => {
    // Ensure quiz answers are properly formatted and within bounds
    if (typeof data.answer === 'string') {
      data.answer = data.answer.trim().substring(0, 500);
    } else if (Array.isArray(data.answer)) {
      data.answer = data.answer.slice(0, 5); // Max 5 selections
    }
    return data;
  };
  
  private sanitizeFileName = (data: any): any => {
    if (data.fileName) {
      // Remove dangerous characters and ensure safe filename
      data.fileName = data.fileName
        .replace(/[^a-zA-Z0-9._-]/g, '_')
        .substring(0, 255);
      
      // Prevent directory traversal
      data.fileName = data.fileName.replace(/\.\./g, '');
    }
    return data;
  };
  
  private async checkRateLimit(
    messageType: string,
    userId: string,
    ipAddress: string,
    limit: { windowMs: number; maxRequests: number }
  ): Promise<boolean> {
    const redis = require('./redis-client'); // Your Redis instance
    
    // Check both user-based and IP-based rate limiting
    const userKey = `rate_limit:${messageType}:user:${userId}`;
    const ipKey = `rate_limit:${messageType}:ip:${ipAddress}`;
    
    const now = Date.now();
    const windowStart = now - limit.windowMs;
    
    // Clean old entries and count current requests
    await redis.zremrangebyscore(userKey, 0, windowStart);
    await redis.zremrangebyscore(ipKey, 0, windowStart);
    
    const userCount = await redis.zcard(userKey);
    const ipCount = await redis.zcard(ipKey);
    
    // Check if either limit is exceeded
    if (userCount >= limit.maxRequests || ipCount >= limit.maxRequests * 2) {
      return true; // Rate limited
    }
    
    // Add current request
    await redis.zadd(userKey, now, `${now}:${Math.random()}`);
    await redis.zadd(ipKey, now, `${now}:${Math.random()}`);
    
    // Set expiration
    await redis.expire(userKey, Math.ceil(limit.windowMs / 1000));
    await redis.expire(ipKey, Math.ceil(limit.windowMs / 1000));
    
    return false; // Not rate limited
  }
}
```

## 🔐 Origin & CORS Security

### Secure Origin Validation

```typescript
// Advanced origin validation for WebSocket connections
class OriginValidator {
  private allowedOrigins: Set<string>;
  private allowedPatterns: RegExp[];
  
  constructor(config: {
    allowedOrigins: string[];
    allowedPatterns?: string[];
    isDevelopment?: boolean;
  }) {
    this.allowedOrigins = new Set(config.allowedOrigins);
    this.allowedPatterns = (config.allowedPatterns || []).map(pattern => new RegExp(pattern));
    
    // Add localhost for development
    if (config.isDevelopment) {
      this.allowedOrigins.add('http://localhost:3000');
      this.allowedOrigins.add('http://localhost:3001');
      this.allowedOrigins.add('http://127.0.0.1:3000');
    }
  }
  
  public validateOrigin(origin: string | undefined): boolean {
    // No origin header (native mobile apps, Postman, etc.)
    if (!origin) {
      // In production, you might want to reject requests without origin
      return process.env.NODE_ENV === 'development';
    }
    
    // Check exact match
    if (this.allowedOrigins.has(origin)) {
      return true;
    }
    
    // Check pattern match
    return this.allowedPatterns.some(pattern => pattern.test(origin));
  }
  
  public createCorsMiddleware() {
    return (req: any, res: any, next: any) => {
      const origin = req.headers.origin;
      
      if (this.validateOrigin(origin)) {
        res.header('Access-Control-Allow-Origin', origin);
        res.header('Access-Control-Allow-Credentials', 'true');
        res.header('Access-Control-Allow-Headers', 'Authorization, Content-Type');
        res.header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
      }
      
      if (req.method === 'OPTIONS') {
        res.sendStatus(200);
      } else {
        next();
      }
    };
  }
}

// Usage in Socket.IO server
const originValidator = new OriginValidator({
  allowedOrigins: [
    'https://yourdomain.com',
    'https://app.yourdomain.com',
    'https://admin.yourdomain.com'
  ],
  allowedPatterns: [
    '^https://.*\\.yourdomain\\.com$', // Subdomains
    '^https://review-pr-\\d+\\.herokuapp\\.com$' // PR previews
  ],
  isDevelopment: process.env.NODE_ENV === 'development'
});

const io = new SocketServer(server, {
  cors: {
    origin: (origin, callback) => {
      if (originValidator.validateOrigin(origin)) {
        callback(null, true);
      } else {
        callback(new Error('CORS policy violation'), false);
      }
    },
    credentials: true,
    methods: ['GET', 'POST']
  }
});
```

## 🛡️ DDoS Protection & Rate Limiting

### Multi-Layer DDoS Protection

```typescript
// Advanced DDoS protection for WebSocket servers
import { Redis } from 'ioredis';

interface DDoSProtectionConfig {
  // Connection limits
  maxConnectionsPerIP: number;
  maxConnectionsGlobal: number;
  connectionWindowMs: number;
  
  // Message limits
  maxMessagesPerSecond: number;
  maxMessagesPerMinute: number;
  
  // Payload limits
  maxPayloadSize: number;
  
  // Behavioral analysis
  suspiciousPatternThreshold: number;
  banDurationMs: number;
}

class DDoSProtectionService {
  private redis: Redis;
  private config: DDoSProtectionConfig;
  private connectionCounts = new Map<string, number>();
  private suspiciousIPs = new Set<string>();
  
  constructor(redis: Redis, config: DDoSProtectionConfig) {
    this.redis = redis;
    this.config = config;
    
    // Clean up connection counts periodically
    setInterval(() => {
      this.connectionCounts.clear();
    }, config.connectionWindowMs);
  }
  
  public async checkConnectionAllowed(ipAddress: string): Promise<{
    allowed: boolean;
    reason?: string;
    banUntil?: Date;
  }> {
    // Check if IP is currently banned
    const banUntil = await this.redis.get(`ban:${ipAddress}`);
    if (banUntil) {
      const banDate = new Date(banUntil);
      if (banDate > new Date()) {
        return {
          allowed: false,
          reason: 'IP address is temporarily banned',
          banUntil: banDate
        };
      } else {
        // Ban expired, remove it
        await this.redis.del(`ban:${ipAddress}`);
      }
    }
    
    // Check global connection limit
    const globalConnections = await this.redis.get('global:connections');
    if (globalConnections && parseInt(globalConnections) >= this.config.maxConnectionsGlobal) {
      return {
        allowed: false,
        reason: 'Server at maximum capacity'
      };
    }
    
    // Check per-IP connection limit
    const ipConnectionsKey = `connections:${ipAddress}`;
    const ipConnections = await this.redis.get(ipConnectionsKey);
    const currentIpConnections = ipConnections ? parseInt(ipConnections) : 0;
    
    if (currentIpConnections >= this.config.maxConnectionsPerIP) {
      // Mark as suspicious if repeatedly hitting connection limit
      await this.markSuspiciousActivity(ipAddress, 'connection_limit_exceeded');
      
      return {
        allowed: false,
        reason: 'Too many connections from this IP address'
      };
    }
    
    return { allowed: true };
  }
  
  public async recordConnection(ipAddress: string): Promise<void> {
    // Increment global counter
    await this.redis.incr('global:connections');
    await this.redis.expire('global:connections', 60); // 1 minute expiry
    
    // Increment per-IP counter
    const ipConnectionsKey = `connections:${ipAddress}`;
    await this.redis.incr(ipConnectionsKey);
    await this.redis.expire(ipConnectionsKey, Math.ceil(this.config.connectionWindowMs / 1000));
    
    // Update local cache
    const currentCount = this.connectionCounts.get(ipAddress) || 0;
    this.connectionCounts.set(ipAddress, currentCount + 1);
  }
  
  public async recordDisconnection(ipAddress: string): Promise<void> {
    // Decrement global counter
    const globalConnections = await this.redis.get('global:connections');
    if (globalConnections && parseInt(globalConnections) > 0) {
      await this.redis.decr('global:connections');
    }
    
    // Decrement per-IP counter
    const ipConnectionsKey = `connections:${ipAddress}`;
    const ipConnections = await this.redis.get(ipConnectionsKey);
    if (ipConnections && parseInt(ipConnections) > 0) {
      await this.redis.decr(ipConnectionsKey);
    }
    
    // Update local cache
    const currentCount = this.connectionCounts.get(ipAddress) || 0;
    if (currentCount > 0) {
      this.connectionCounts.set(ipAddress, currentCount - 1);
    }
  }
  
  public async checkMessageRateLimit(
    ipAddress: string,
    userId?: string
  ): Promise<{
    allowed: boolean;
    reason?: string;
    remainingQuota?: number;
  }> {
    const now = Date.now();
    const secondWindow = Math.floor(now / 1000);
    const minuteWindow = Math.floor(now / 60000);
    
    // Check per-second limit
    const secondKey = `messages:${ipAddress}:${secondWindow}`;
    const messagesThisSecond = await this.redis.get(secondKey);
    const currentSecondCount = messagesThisSecond ? parseInt(messagesThisSecond) : 0;
    
    if (currentSecondCount >= this.config.maxMessagesPerSecond) {
      await this.markSuspiciousActivity(ipAddress, 'message_rate_exceeded');
      return {
        allowed: false,
        reason: 'Message rate limit exceeded (per second)'
      };
    }
    
    // Check per-minute limit
    const minuteKey = `messages:${ipAddress}:${minuteWindow}`;
    const messagesThisMinute = await this.redis.get(minuteKey);
    const currentMinuteCount = messagesThisMinute ? parseInt(messagesThisMinute) : 0;
    
    if (currentMinuteCount >= this.config.maxMessagesPerMinute) {
      await this.markSuspiciousActivity(ipAddress, 'message_burst');
      return {
        allowed: false,
        reason: 'Message rate limit exceeded (per minute)',
        remainingQuota: 0
      };
    }
    
    // Increment counters
    await this.redis.incr(secondKey);
    await this.redis.expire(secondKey, 2); // 2 second expiry for safety
    
    await this.redis.incr(minuteKey);
    await this.redis.expire(minuteKey, 120); // 2 minute expiry for safety
    
    return {
      allowed: true,
      remainingQuota: this.config.maxMessagesPerMinute - currentMinuteCount - 1
    };
  }
  
  public validatePayloadSize(payload: string | Buffer): boolean {
    const size = typeof payload === 'string' ? 
      Buffer.byteLength(payload, 'utf8') : payload.length;
    
    return size <= this.config.maxPayloadSize;
  }
  
  private async markSuspiciousActivity(
    ipAddress: string,
    activityType: string
  ): Promise<void> {
    const suspiciousKey = `suspicious:${ipAddress}`;
    const currentScore = await this.redis.get(suspiciousKey);
    const newScore = (currentScore ? parseInt(currentScore) : 0) + 1;
    
    await this.redis.setex(suspiciousKey, 300, newScore.toString()); // 5 minute window
    
    // Log suspicious activity
    console.warn('Suspicious activity detected:', {
      ipAddress,
      activityType,
      suspiciousScore: newScore,
      timestamp: new Date().toISOString()
    });
    
    // Ban IP if threshold exceeded
    if (newScore >= this.config.suspiciousPatternThreshold) {
      await this.banIP(ipAddress, this.config.banDurationMs);
    }
  }
  
  private async banIP(ipAddress: string, durationMs: number): Promise<void> {
    const banUntil = new Date(Date.now() + durationMs);
    await this.redis.setex(`ban:${ipAddress}`, Math.ceil(durationMs / 1000), banUntil.toISOString());
    
    console.warn('IP address banned:', {
      ipAddress,
      banUntil,
      duration: `${durationMs / 1000} seconds`
    });
    
    // Optionally notify administrators
    // await this.notifyAdministrators('IP_BANNED', { ipAddress, banUntil });
  }
  
  public async getBannedIPs(): Promise<Array<{
    ipAddress: string;
    banUntil: Date;
  }>> {
    const banKeys = await this.redis.keys('ban:*');
    const bannedIPs = [];
    
    for (const key of banKeys) {
      const banUntil = await this.redis.get(key);
      if (banUntil) {
        const ipAddress = key.replace('ban:', '');
        bannedIPs.push({
          ipAddress,
          banUntil: new Date(banUntil)
        });
      }
    }
    
    return bannedIPs;
  }
  
  public async unbanIP(ipAddress: string): Promise<void> {
    await this.redis.del(`ban:${ipAddress}`);
    await this.redis.del(`suspicious:${ipAddress}`);
    
    console.info('IP address unbanned:', { ipAddress });
  }
}

// Usage in WebSocket server
const ddosProtection = new DDoSProtectionService(redis, {
  maxConnectionsPerIP: 100,
  maxConnectionsGlobal: 10000,
  connectionWindowMs: 60000, // 1 minute
  maxMessagesPerSecond: 10,
  maxMessagesPerMinute: 300,
  maxPayloadSize: 64 * 1024, // 64KB
  suspiciousPatternThreshold: 5,
  banDurationMs: 15 * 60 * 1000 // 15 minutes
});

// Pre-connection middleware
io.engine.on('connection_error', (err) => {
  console.error('Connection error:', err);
});

// Connection validation
io.use(async (socket, next) => {
  const ipAddress = socket.handshake.address;
  
  const connectionCheck = await ddosProtection.checkConnectionAllowed(ipAddress);
  if (!connectionCheck.allowed) {
    return next(new Error(connectionCheck.reason));
  }
  
  await ddosProtection.recordConnection(ipAddress);
  
  socket.on('disconnect', async () => {
    await ddosProtection.recordDisconnection(ipAddress);
  });
  
  next();
});

// Message rate limiting
io.on('connection', (socket) => {
  socket.use(async (packet, next) => {
    const ipAddress = socket.handshake.address;
    const [eventName, payload] = packet;
    
    // Check payload size
    const payloadStr = JSON.stringify(payload);
    if (!ddosProtection.validatePayloadSize(payloadStr)) {
      return next(new Error('Payload too large'));
    }
    
    // Check message rate limit
    const rateLimitCheck = await ddosProtection.checkMessageRateLimit(
      ipAddress,
      (socket as any).userId
    );
    
    if (!rateLimitCheck.allowed) {
      return next(new Error(rateLimitCheck.reason));
    }
    
    next();
  });
});
```

## 🔗 Navigation

**Previous**: [Comparison Analysis](./comparison-analysis.md)  
**Next**: [Performance Analysis](./performance-analysis.md)

---

*Security Considerations | Comprehensive security patterns for production WebSocket applications*