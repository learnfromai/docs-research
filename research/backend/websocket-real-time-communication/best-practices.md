# Best Practices: WebSocket Real-Time Communication

## 🏗️ Architecture & Design Patterns

### Connection Management Best Practices

#### 1. Connection Lifecycle Management

```typescript
// Proper connection handling with graceful degradation
class ConnectionManager {
  private connections = new Map<string, ConnectionInfo>();
  private reconnectAttempts = new Map<string, number>();
  
  public async handleConnection(socket: Socket) {
    const connectionInfo: ConnectionInfo = {
      id: socket.id,
      userId: socket.userId,
      connectedAt: new Date(),
      lastActivity: new Date(),
      isHealthy: true
    };
    
    this.connections.set(socket.id, connectionInfo);
    
    // Set up heartbeat
    this.setupHeartbeat(socket);
    
    // Clean up on disconnect
    socket.on('disconnect', () => {
      this.handleDisconnection(socket.id);
    });
  }
  
  private setupHeartbeat(socket: Socket) {
    const interval = setInterval(() => {
      const connection = this.connections.get(socket.id);
      if (!connection) {
        clearInterval(interval);
        return;
      }
      
      // Check if connection is still alive
      const lastActivity = Date.now() - connection.lastActivity.getTime();
      if (lastActivity > 60000) { // 1 minute timeout
        connection.isHealthy = false;
        socket.disconnect(true);
        clearInterval(interval);
      } else {
        socket.emit('ping');
      }
    }, 30000); // Every 30 seconds
    
    socket.on('pong', () => {
      const connection = this.connections.get(socket.id);
      if (connection) {
        connection.lastActivity = new Date();
        connection.isHealthy = true;
      }
    });
  }
}
```

#### 2. Client-Side Reconnection Strategy

```typescript
// Client-side reconnection with exponential backoff
class ReconnectManager {
  private socket: Socket | null = null;
  private reconnectAttempts = 0;
  private maxReconnectAttempts = 10;
  private baseDelay = 1000; // 1 second
  private maxDelay = 30000; // 30 seconds
  
  public connect(url: string, options: any = {}) {
    this.socket = io(url, {
      ...options,
      autoConnect: false,
      transports: ['websocket', 'polling'] // Fallback to polling
    });
    
    this.setupEventHandlers();
    this.socket.connect();
  }
  
  private setupEventHandlers() {
    if (!this.socket) return;
    
    this.socket.on('connect', () => {
      console.log('Connected to server');
      this.reconnectAttempts = 0;
    });
    
    this.socket.on('disconnect', (reason) => {
      console.log('Disconnected:', reason);
      
      // Only attempt reconnection for network issues
      if (reason === 'io server disconnect') {
        // Server forcibly disconnected, don't reconnect
        return;
      }
      
      this.attemptReconnection();
    });
    
    this.socket.on('connect_error', (error) => {
      console.error('Connection error:', error);
      this.attemptReconnection();
    });
  }
  
  private attemptReconnection() {
    if (this.reconnectAttempts >= this.maxReconnectAttempts) {
      console.error('Max reconnection attempts reached');
      return;
    }
    
    this.reconnectAttempts++;
    
    // Exponential backoff with jitter
    const delay = Math.min(
      this.baseDelay * Math.pow(2, this.reconnectAttempts - 1),
      this.maxDelay
    );
    
    const jitter = Math.random() * 0.1 * delay;
    const finalDelay = delay + jitter;
    
    console.log(`Reconnecting in ${finalDelay}ms (attempt ${this.reconnectAttempts})`);
    
    setTimeout(() => {
      if (this.socket) {
        this.socket.connect();
      }
    }, finalDelay);
  }
}
```

### Message Handling Patterns

#### 3. Message Validation and Sanitization

```typescript
// Comprehensive message validation
import Joi from 'joi';
import DOMPurify from 'isomorphic-dompurify';
import rateLimit from 'express-rate-limit';

interface ValidatedMessage {
  type: string;
  payload: any;
  timestamp: Date;
  userId: string;
}

class MessageValidator {
  private schemas = new Map<string, Joi.Schema>();
  private rateLimiters = new Map<string, any>();
  
  constructor() {
    this.setupSchemas();
    this.setupRateLimiters();
  }
  
  private setupSchemas() {
    // Chat message schema
    this.schemas.set('chat:message', Joi.object({
      content: Joi.string().min(1).max(1000).required(),
      roomId: Joi.string().uuid().required(),
      type: Joi.string().valid('text', 'image', 'file').default('text'),
      metadata: Joi.object({
        replyTo: Joi.string().uuid().optional(),
        mentions: Joi.array().items(Joi.string()).max(10).optional()
      }).optional()
    }));
    
    // Quiz answer schema
    this.schemas.set('quiz:answer', Joi.object({
      sessionId: Joi.string().uuid().required(),
      questionId: Joi.string().uuid().required(),
      answer: Joi.alternatives().try(
        Joi.number().integer().min(0).max(10),
        Joi.string().max(500),
        Joi.array().items(Joi.number().integer()).max(10)
      ).required(),
      timestamp: Joi.date().default(Date.now)
    }));
    
    // User action schema
    this.schemas.set('user:action', Joi.object({
      action: Joi.string().valid('join', 'leave', 'typing', 'stop_typing').required(),
      target: Joi.string().optional(),
      metadata: Joi.object().optional()
    }));
  }
  
  private setupRateLimiters() {
    // Different rate limits for different message types
    this.rateLimiters.set('chat:message', this.createRateLimit(60, 60000)); // 60 per minute
    this.rateLimiters.set('quiz:answer', this.createRateLimit(30, 60000)); // 30 per minute
    this.rateLimiters.set('user:action', this.createRateLimit(100, 60000)); // 100 per minute
  }
  
  private createRateLimit(max: number, windowMs: number) {
    const store = new Map<string, { count: number; resetTime: number }>();
    
    return (userId: string): boolean => {
      const now = Date.now();
      const userLimit = store.get(userId);
      
      if (!userLimit || now > userLimit.resetTime) {
        store.set(userId, { count: 1, resetTime: now + windowMs });
        return true;
      }
      
      if (userLimit.count >= max) {
        return false;
      }
      
      userLimit.count++;
      return true;
    };
  }
  
  public async validateMessage(
    messageType: string,
    payload: any,
    userId: string
  ): Promise<{ isValid: boolean; data?: ValidatedMessage; error?: string }> {
    // Check rate limiting first
    const rateLimiter = this.rateLimiters.get(messageType);
    if (rateLimiter && !rateLimiter(userId)) {
      return { isValid: false, error: 'Rate limit exceeded' };
    }
    
    // Validate against schema
    const schema = this.schemas.get(messageType);
    if (!schema) {
      return { isValid: false, error: 'Unknown message type' };
    }
    
    const { error, value } = schema.validate(payload);
    if (error) {
      return {
        isValid: false,
        error: `Validation error: ${error.details[0].message}`
      };
    }
    
    // Sanitize content if it's a text message
    if (value.content && typeof value.content === 'string') {
      value.content = this.sanitizeContent(value.content);
    }
    
    return {
      isValid: true,
      data: {
        type: messageType,
        payload: value,
        timestamp: new Date(),
        userId
      }
    };
  }
  
  private sanitizeContent(content: string): string {
    // Remove potentially harmful HTML/JavaScript
    const sanitized = DOMPurify.sanitize(content, {
      ALLOWED_TAGS: ['b', 'i', 'em', 'strong', 'code', 'pre'],
      ALLOWED_ATTR: []
    });
    
    // Additional custom sanitization
    return sanitized
      .trim()
      .replace(/\s+/g, ' ') // Normalize whitespace
      .substring(0, 1000); // Enforce max length
  }
}
```

#### 4. Event-Driven Architecture Pattern

```typescript
// Event-driven pattern for scalable real-time applications
import { EventEmitter } from 'events';
import { Redis } from 'ioredis';

interface DomainEvent {
  id: string;
  type: string;
  aggregateId: string;
  payload: any;
  timestamp: Date;
  version: number;
}

class EventStore extends EventEmitter {
  private redis: Redis;
  
  constructor(redis: Redis) {
    super();
    this.redis = redis;
    this.setupSubscriptions();
  }
  
  private setupSubscriptions() {
    // Subscribe to Redis pub/sub for distributed events
    const subscriber = this.redis.duplicate();
    subscriber.subscribe('domain-events');
    
    subscriber.on('message', (channel, message) => {
      if (channel === 'domain-events') {
        const event: DomainEvent = JSON.parse(message);
        this.emit(event.type, event);
      }
    });
  }
  
  public async publishEvent(event: DomainEvent): Promise<void> {
    // Store event for persistence
    await this.redis.zadd(
      `events:${event.aggregateId}`,
      event.version,
      JSON.stringify(event)
    );
    
    // Publish for real-time propagation
    await this.redis.publish('domain-events', JSON.stringify(event));
    
    // Emit locally for immediate handlers
    this.emit(event.type, event);
  }
}

// Usage in application services
class QuizSessionService extends EventEmitter {
  private eventStore: EventStore;
  
  constructor(eventStore: EventStore) {
    super();
    this.eventStore = eventStore;
    this.setupEventHandlers();
  }
  
  private setupEventHandlers() {
    this.eventStore.on('quiz:answer_submitted', (event) => {
      this.handleAnswerSubmitted(event);
    });
    
    this.eventStore.on('quiz:question_timeout', (event) => {
      this.handleQuestionTimeout(event);
    });
  }
  
  public async submitAnswer(sessionId: string, userId: string, answer: any): Promise<void> {
    const event: DomainEvent = {
      id: require('uuid').v4(),
      type: 'quiz:answer_submitted',
      aggregateId: sessionId,
      payload: { userId, answer, timestamp: new Date() },
      timestamp: new Date(),
      version: await this.getNextVersion(sessionId)
    };
    
    await this.eventStore.publishEvent(event);
  }
  
  private async handleAnswerSubmitted(event: DomainEvent): Promise<void> {
    // Business logic for processing answer
    const { userId, answer } = event.payload;
    
    // Calculate score
    const score = await this.calculateScore(event.aggregateId, userId, answer);
    
    // Publish score update event
    const scoreEvent: DomainEvent = {
      id: require('uuid').v4(),
      type: 'quiz:score_updated',
      aggregateId: event.aggregateId,
      payload: { userId, score, newTotal: score },
      timestamp: new Date(),
      version: await this.getNextVersion(event.aggregateId)
    };
    
    await this.eventStore.publishEvent(scoreEvent);
  }
  
  private async getNextVersion(aggregateId: string): Promise<number> {
    const count = await this.eventStore.redis.zcard(`events:${aggregateId}`);
    return count + 1;
  }
}
```

## 🔒 Security Best Practices

### Authentication & Authorization

#### 5. JWT-Based Authentication with Refresh Tokens

```typescript
// Secure JWT implementation for WebSocket authentication
import jwt from 'jsonwebtoken';
import crypto from 'crypto';
import { Redis } from 'ioredis';

interface TokenPair {
  accessToken: string;
  refreshToken: string;
  expiresAt: Date;
}

interface UserPayload {
  userId: string;
  username: string;
  role: string;
  permissions: string[];
}

class AuthenticationService {
  private redis: Redis;
  private accessTokenSecret: string;
  private refreshTokenSecret: string;
  
  constructor(redis: Redis) {
    this.redis = redis;
    this.accessTokenSecret = process.env.JWT_ACCESS_SECRET!;
    this.refreshTokenSecret = process.env.JWT_REFRESH_SECRET!;
  }
  
  public async generateTokenPair(user: UserPayload): Promise<TokenPair> {
    // Short-lived access token (15 minutes)
    const accessToken = jwt.sign(
      {
        userId: user.userId,
        username: user.username,
        role: user.role,
        permissions: user.permissions,
        type: 'access'
      },
      this.accessTokenSecret,
      { 
        expiresIn: '15m',
        algorithm: 'HS256',
        issuer: 'edtech-platform',
        audience: 'webapp'
      }
    );
    
    // Long-lived refresh token (7 days)
    const refreshTokenId = crypto.randomUUID();
    const refreshToken = jwt.sign(
      {
        userId: user.userId,
        tokenId: refreshTokenId,
        type: 'refresh'
      },
      this.refreshTokenSecret,
      { 
        expiresIn: '7d',
        algorithm: 'HS256',
        issuer: 'edtech-platform',
        audience: 'webapp'
      }
    );
    
    // Store refresh token in Redis with user association
    const refreshKey = `refresh_token:${refreshTokenId}`;
    await this.redis.setex(refreshKey, 7 * 24 * 60 * 60, JSON.stringify({
      userId: user.userId,
      username: user.username,
      role: user.role,
      issuedAt: new Date().toISOString()
    }));
    
    // Track active refresh tokens per user (for revocation)
    await this.redis.sadd(`user_tokens:${user.userId}`, refreshTokenId);
    
    return {
      accessToken,
      refreshToken,
      expiresAt: new Date(Date.now() + 15 * 60 * 1000) // 15 minutes
    };
  }
  
  public async verifyAccessToken(token: string): Promise<UserPayload | null> {
    try {
      // Check if token is blacklisted
      const isBlacklisted = await this.redis.get(`blacklist:${token}`);
      if (isBlacklisted) {
        throw new Error('Token has been revoked');
      }
      
      const payload = jwt.verify(token, this.accessTokenSecret) as any;
      
      if (payload.type !== 'access') {
        throw new Error('Invalid token type');
      }
      
      return {
        userId: payload.userId,
        username: payload.username,
        role: payload.role,
        permissions: payload.permissions || []
      };
    } catch (error) {
      console.error('Token verification failed:', error);
      return null;
    }
  }
  
  public async refreshAccessToken(refreshToken: string): Promise<TokenPair | null> {
    try {
      const payload = jwt.verify(refreshToken, this.refreshTokenSecret) as any;
      
      if (payload.type !== 'refresh') {
        throw new Error('Invalid token type');
      }
      
      // Check if refresh token exists in Redis
      const refreshKey = `refresh_token:${payload.tokenId}`;
      const storedData = await this.redis.get(refreshKey);
      
      if (!storedData) {
        throw new Error('Refresh token not found or expired');
      }
      
      const userData = JSON.parse(storedData);
      
      // Generate new token pair
      const newTokenPair = await this.generateTokenPair({
        userId: userData.userId,
        username: userData.username,
        role: userData.role,
        permissions: userData.permissions || []
      });
      
      // Invalidate old refresh token
      await this.redis.del(refreshKey);
      await this.redis.srem(`user_tokens:${userData.userId}`, payload.tokenId);
      
      return newTokenPair;
    } catch (error) {
      console.error('Token refresh failed:', error);
      return null;
    }
  }
  
  public async revokeUserTokens(userId: string): Promise<void> {
    // Get all refresh tokens for user
    const tokenIds = await this.redis.smembers(`user_tokens:${userId}`);
    
    // Remove all refresh tokens
    for (const tokenId of tokenIds) {
      await this.redis.del(`refresh_token:${tokenId}`);
    }
    
    // Clear user token set
    await this.redis.del(`user_tokens:${userId}`);
  }
  
  public async blacklistAccessToken(token: string): Promise<void> {
    try {
      const payload = jwt.decode(token) as any;
      if (payload && payload.exp) {
        const expiryTime = payload.exp - Math.floor(Date.now() / 1000);
        if (expiryTime > 0) {
          await this.redis.setex(`blacklist:${token}`, expiryTime, '1');
        }
      }
    } catch (error) {
      console.error('Failed to blacklist token:', error);
    }
  }
}
```

#### 6. Permission-Based Access Control

```typescript
// Fine-grained permission system for WebSocket actions
interface Permission {
  resource: string;
  action: string;
  condition?: (context: any) => boolean;
}

interface Role {
  name: string;
  permissions: Permission[];
}

class AuthorizationService {
  private roles = new Map<string, Role>();
  
  constructor() {
    this.setupRoles();
  }
  
  private setupRoles() {
    // Student role
    this.roles.set('student', {
      name: 'student',
      permissions: [
        { resource: 'chat', action: 'read' },
        { resource: 'chat', action: 'write' },
        { resource: 'quiz', action: 'participate' },
        { resource: 'quiz', action: 'submit_answer' },
        { resource: 'room', action: 'join' },
        { resource: 'room', action: 'leave' }
      ]
    });
    
    // Instructor role
    this.roles.set('instructor', {
      name: 'instructor',
      permissions: [
        { resource: 'chat', action: 'read' },
        { resource: 'chat', action: 'write' },
        { resource: 'chat', action: 'moderate' },
        { resource: 'quiz', action: 'create' },
        { resource: 'quiz', action: 'start' },
        { resource: 'quiz', action: 'manage' },
        { resource: 'room', action: 'create' },
        { resource: 'room', action: 'manage' },
        { resource: 'user', action: 'mute', condition: (ctx) => ctx.targetRole !== 'admin' },
        { resource: 'user', action: 'kick', condition: (ctx) => ctx.targetRole !== 'admin' }
      ]
    });
    
    // Admin role
    this.roles.set('admin', {
      name: 'admin',
      permissions: [
        { resource: '*', action: '*' } // All permissions
      ]
    });
  }
  
  public hasPermission(
    userRole: string,
    resource: string,
    action: string,
    context: any = {}
  ): boolean {
    const role = this.roles.get(userRole);
    if (!role) return false;
    
    return role.permissions.some(permission => {
      // Check for wildcard permissions (admin)
      if (permission.resource === '*' && permission.action === '*') {
        return true;
      }
      
      // Check specific resource and action
      const resourceMatch = permission.resource === resource || permission.resource === '*';
      const actionMatch = permission.action === action || permission.action === '*';
      
      if (resourceMatch && actionMatch) {
        // Check additional conditions if present
        if (permission.condition) {
          return permission.condition(context);
        }
        return true;
      }
      
      return false;
    });
  }
  
  public async authorizeSocketAction(
    socket: any,
    resource: string,
    action: string,
    context: any = {}
  ): Promise<boolean> {
    if (!socket.userId || !socket.role) {
      return false;
    }
    
    // Add user context
    context.userId = socket.userId;
    context.userRole = socket.role;
    
    return this.hasPermission(socket.role, resource, action, context);
  }
}

// Usage in WebSocket handlers
class SecureWebSocketHandler {
  private authService: AuthorizationService;
  
  constructor() {
    this.authService = new AuthorizationService();
  }
  
  public setupHandlers(io: SocketServer) {
    io.on('connection', (socket) => {
      // Chat message handler with authorization
      socket.on('chat:message', async (data) => {
        const authorized = await this.authService.authorizeSocketAction(
          socket,
          'chat',
          'write',
          { roomId: data.roomId }
        );
        
        if (!authorized) {
          socket.emit('error', { message: 'Insufficient permissions' });
          return;
        }
        
        // Process message...
      });
      
      // Moderation action handler
      socket.on('chat:moderate', async (data) => {
        const authorized = await this.authService.authorizeSocketAction(
          socket,
          'chat',
          'moderate',
          { 
            roomId: data.roomId,
            action: data.action,
            targetUserId: data.targetUserId
          }
        );
        
        if (!authorized) {
          socket.emit('error', { message: 'Insufficient permissions for moderation' });
          return;
        }
        
        // Process moderation action...
      });
      
      // Quiz management handler
      socket.on('quiz:start', async (data) => {
        const authorized = await this.authService.authorizeSocketAction(
          socket,
          'quiz',
          'start',
          { sessionId: data.sessionId }
        );
        
        if (!authorized) {
          socket.emit('error', { message: 'Only instructors can start quizzes' });
          return;
        }
        
        // Start quiz...
      });
    });
  }
}
```

### Input Validation & Rate Limiting

#### 7. Advanced Rate Limiting Strategies

```typescript
// Multi-tier rate limiting system
import { Redis } from 'ioredis';

interface RateLimitConfig {
  windowMs: number;
  maxRequests: number;
  skipSuccessfulRequests?: boolean;
  keyGenerator?: (socket: any) => string;
}

interface RateLimitRule {
  name: string;
  config: RateLimitConfig;
  scope: 'global' | 'user' | 'ip' | 'room';
}

class AdvancedRateLimiter {
  private redis: Redis;
  private rules: RateLimitRule[] = [];
  
  constructor(redis: Redis) {
    this.redis = redis;
    this.setupDefaultRules();
  }
  
  private setupDefaultRules() {
    this.rules = [
      // Global connection rate limiting
      {
        name: 'global_connections',
        scope: 'global',
        config: {
          windowMs: 60000, // 1 minute
          maxRequests: 1000 // Max 1000 new connections per minute globally
        }
      },
      
      // Per-IP connection limiting
      {
        name: 'ip_connections',
        scope: 'ip',
        config: {
          windowMs: 60000,
          maxRequests: 10, // Max 10 connections per IP per minute
          keyGenerator: (socket) => socket.handshake.address
        }
      },
      
      // Per-user message limiting
      {
        name: 'user_messages',
        scope: 'user',
        config: {
          windowMs: 60000,
          maxRequests: 60, // Max 60 messages per user per minute
          keyGenerator: (socket) => socket.userId
        }
      },
      
      // Per-room message limiting
      {
        name: 'room_messages',
        scope: 'room',
        config: {
          windowMs: 60000,
          maxRequests: 500, // Max 500 messages per room per minute
          keyGenerator: (socket, data) => data.roomId
        }
      },
      
      // Burst protection for quiz answers
      {
        name: 'quiz_answers',
        scope: 'user',
        config: {
          windowMs: 10000, // 10 seconds
          maxRequests: 5, // Max 5 quiz answers per 10 seconds
          keyGenerator: (socket) => `quiz:${socket.userId}`
        }
      }
    ];
  }
  
  public async checkRateLimit(
    ruleName: string,
    socket: any,
    data: any = {}
  ): Promise<{ allowed: boolean; remaining: number; resetTime: number }> {
    const rule = this.rules.find(r => r.name === ruleName);
    if (!rule) {
      return { allowed: true, remaining: Infinity, resetTime: 0 };
    }
    
    const key = this.generateKey(rule, socket, data);
    const window = rule.config.windowMs;
    const limit = rule.config.maxRequests;
    
    // Use Redis sliding window rate limiting
    const now = Date.now();
    const windowStart = now - window;
    
    // Remove old entries
    await this.redis.zremrangebyscore(key, 0, windowStart);
    
    // Count current requests
    const currentCount = await this.redis.zcard(key);
    
    if (currentCount >= limit) {
      // Get the oldest entry to calculate reset time
      const oldestEntries = await this.redis.zrange(key, 0, 0, 'WITHSCORES');
      const resetTime = oldestEntries.length > 0 
        ? parseInt(oldestEntries[1]) + window
        : now + window;
      
      return {
        allowed: false,
        remaining: 0,
        resetTime
      };
    }
    
    // Add current request
    await this.redis.zadd(key, now, `${now}:${Math.random()}`);
    await this.redis.expire(key, Math.ceil(window / 1000));
    
    return {
      allowed: true,
      remaining: limit - currentCount - 1,
      resetTime: now + window
    };
  }
  
  private generateKey(rule: RateLimitRule, socket: any, data: any): string {
    let identifier: string;
    
    if (rule.config.keyGenerator) {
      identifier = rule.config.keyGenerator(socket, data);
    } else {
      switch (rule.scope) {
        case 'global':
          identifier = 'global';
          break;
        case 'ip':
          identifier = socket.handshake.address;
          break;
        case 'user':
          identifier = socket.userId || socket.id;
          break;
        case 'room':
          identifier = data.roomId || 'unknown';
          break;
        default:
          identifier = socket.id;
      }
    }
    
    return `rate_limit:${rule.name}:${identifier}`;
  }
  
  // Middleware for rate limiting WebSocket events
  public createRateLimitMiddleware(ruleName: string) {
    return async (socket: any, data: any, next: Function) => {
      const result = await this.checkRateLimit(ruleName, socket, data);
      
      if (!result.allowed) {
        const error = new Error('Rate limit exceeded');
        (error as any).data = {
          type: 'RATE_LIMIT_EXCEEDED',
          resetTime: result.resetTime,
          rule: ruleName
        };
        return next(error);
      }
      
      // Add rate limit info to socket for client feedback
      socket.rateLimitInfo = {
        remaining: result.remaining,
        resetTime: result.resetTime
      };
      
      next();
    };
  }
}

// Usage example
const rateLimiter = new AdvancedRateLimiter(redis);

io.on('connection', (socket) => {
  // Apply rate limiting middleware to specific events
  socket.use(rateLimiter.createRateLimitMiddleware('user_messages'));
  
  socket.on('chat:message', async (data) => {
    // Additional room-specific rate limiting
    const roomLimitResult = await rateLimiter.checkRateLimit('room_messages', socket, data);
    if (!roomLimitResult.allowed) {
      socket.emit('error', {
        type: 'ROOM_RATE_LIMIT_EXCEEDED',
        message: 'Room message limit exceeded',
        resetTime: roomLimitResult.resetTime
      });
      return;
    }
    
    // Process message...
  });
  
  socket.on('quiz:answer', async (data) => {
    const quizLimitResult = await rateLimiter.checkRateLimit('quiz_answers', socket, data);
    if (!quizLimitResult.allowed) {
      socket.emit('error', {
        type: 'QUIZ_RATE_LIMIT_EXCEEDED',
        message: 'Too many quiz answers submitted',
        resetTime: quizLimitResult.resetTime
      });
      return;
    }
    
    // Process quiz answer...
  });
});
```

## 🚀 Performance Optimization

### Connection Scaling Patterns

#### 8. Horizontal Scaling with Redis Adapter

```typescript
// Redis adapter for Socket.IO clustering
import { createAdapter } from '@socket.io/redis-adapter';
import { Redis } from 'ioredis';

class ScalableSocketServer {
  private io: SocketServer;
  private redisAdapter: any;
  
  constructor() {
    this.setupRedisAdapter();
    this.setupLoadBalancing();
  }
  
  private setupRedisAdapter() {
    const pubClient = new Redis({
      host: process.env.REDIS_HOST,
      port: parseInt(process.env.REDIS_PORT || '6379'),
      lazyConnect: true,
      retryDelayOnFailover: 100
    });
    
    const subClient = pubClient.duplicate();
    
    this.redisAdapter = createAdapter(pubClient, subClient, {
      key: 'socketio',
      requestsTimeout: 5000
    });
    
    this.io.adapter(this.redisAdapter);
    
    // Handle Redis connection events
    pubClient.on('error', (err) => {
      console.error('Redis pub client error:', err);
    });
    
    subClient.on('error', (err) => {
      console.error('Redis sub client error:', err);
    });
  }
  
  private setupLoadBalancing() {
    // Sticky session support
    this.io.engine.generateId = (req) => {
      const userId = req._query?.userId;
      if (userId) {
        // Hash user ID to determine server affinity
        const hash = require('crypto')
          .createHash('md5')
          .update(userId)
          .digest('hex');
        return `${hash.substring(0, 8)}-${Date.now()}`;
      }
      return require('uuid').v4();
    };
  }
  
  // Room-based sharding for better performance
  public async joinOptimalRoom(socket: any, roomId: string): Promise<void> {
    // Get room statistics from Redis
    const roomStats = await this.getRoomStatistics(roomId);
    
    // If room is getting too large, consider splitting
    if (roomStats.participantCount > 1000) {
      const shardedRoomId = this.getShardedRoomId(roomId, socket.userId);
      await socket.join(shardedRoomId);
      
      // Also join the main room for global broadcasts
      await socket.join(roomId);
    } else {
      await socket.join(roomId);
    }
    
    // Update room statistics
    await this.updateRoomStatistics(roomId, socket.userId, 'join');
  }
  
  private getShardedRoomId(baseRoomId: string, userId: string): string {
    const hash = require('crypto')
      .createHash('md5')
      .update(userId)
      .digest('hex');
    const shardIndex = parseInt(hash.substring(0, 2), 16) % 10; // 10 shards
    return `${baseRoomId}:shard:${shardIndex}`;
  }
  
  private async getRoomStatistics(roomId: string): Promise<{
    participantCount: number;
    messageRate: number;
    avgResponseTime: number;
  }> {
    const statsKey = `room:stats:${roomId}`;
    const stats = await this.redisAdapter.pubClient.hgetall(statsKey);
    
    return {
      participantCount: parseInt(stats.participants || '0'),
      messageRate: parseFloat(stats.messageRate || '0'),
      avgResponseTime: parseFloat(stats.avgResponseTime || '0')
    };
  }
  
  private async updateRoomStatistics(
    roomId: string,
    userId: string,
    action: 'join' | 'leave' | 'message'
  ): Promise<void> {
    const statsKey = `room:stats:${roomId}`;
    
    switch (action) {
      case 'join':
        await this.redisAdapter.pubClient.hincrby(statsKey, 'participants', 1);
        await this.redisAdapter.pubClient.sadd(`room:users:${roomId}`, userId);
        break;
        
      case 'leave':
        await this.redisAdapter.pubClient.hincrby(statsKey, 'participants', -1);
        await this.redisAdapter.pubClient.srem(`room:users:${roomId}`, userId);
        break;
        
      case 'message':
        // Update message rate (messages per minute)
        const now = Math.floor(Date.now() / 60000); // Current minute
        const messageKey = `room:messages:${roomId}:${now}`;
        await this.redisAdapter.pubClient.incr(messageKey);
        await this.redisAdapter.pubClient.expire(messageKey, 300); // 5 minutes
        break;
    }
    
    // Set expiration for stats
    await this.redisAdapter.pubClient.expire(statsKey, 86400); // 24 hours
  }
}
```

#### 9. Memory Management and Optimization

```typescript
// Memory optimization for high-concurrency WebSocket servers
class MemoryOptimizedServer {
  private connections = new Map<string, WeakRef<any>>();
  private cleanupRegistry = new FinalizationRegistry((socketId: string) => {
    this.connections.delete(socketId);
  });
  
  private messageBuffer = new Map<string, CircularBuffer>();
  private readonly maxBufferSize = 1000;
  
  constructor(private io: SocketServer) {
    this.setupMemoryManagement();
    this.setupGarbageCollection();
  }
  
  private setupMemoryManagement() {
    this.io.on('connection', (socket) => {
      // Use WeakRef to allow garbage collection
      const socketRef = new WeakRef(socket);
      this.connections.set(socket.id, socketRef);
      this.cleanupRegistry.register(socket, socket.id);
      
      // Initialize circular buffer for message history
      this.messageBuffer.set(socket.id, new CircularBuffer(this.maxBufferSize));
      
      socket.on('disconnect', () => {
        this.cleanupConnection(socket.id);
      });
    });
  }
  
  private setupGarbageCollection() {
    // Periodic cleanup of stale connections
    setInterval(() => {
      this.cleanupStaleConnections();
    }, 60000); // Every minute
    
    // Memory pressure monitoring
    setInterval(() => {
      const memUsage = process.memoryUsage();
      const heapUsedMB = memUsage.heapUsed / 1024 / 1024;
      
      if (heapUsedMB > 500) { // 500MB threshold
        console.warn('High memory usage detected:', heapUsedMB, 'MB');
        this.aggressiveCleanup();
        
        if (global.gc) {
          global.gc();
        }
      }
    }, 30000); // Every 30 seconds
  }
  
  private cleanupStaleConnections() {
    const staleConnections: string[] = [];
    
    for (const [socketId, socketRef] of this.connections.entries()) {
      const socket = socketRef.deref();
      if (!socket || socket.disconnected) {
        staleConnections.push(socketId);
      }
    }
    
    staleConnections.forEach(socketId => {
      this.cleanupConnection(socketId);
    });
  }
  
  private cleanupConnection(socketId: string) {
    this.connections.delete(socketId);
    this.messageBuffer.delete(socketId);
  }
  
  private aggressiveCleanup() {
    // Clear old message buffers
    const cutoffTime = Date.now() - 30 * 60 * 1000; // 30 minutes ago
    
    for (const [socketId, buffer] of this.messageBuffer.entries()) {
      buffer.clearOlderThan(cutoffTime);
    }
    
    // Force cleanup of disconnected sockets
    this.cleanupStaleConnections();
  }
}

// Circular buffer implementation for message history
class CircularBuffer {
  private buffer: any[];
  private head = 0;
  private tail = 0;
  private size = 0;
  
  constructor(private capacity: number) {
    this.buffer = new Array(capacity);
  }
  
  public push(item: any): void {
    this.buffer[this.tail] = item;
    this.tail = (this.tail + 1) % this.capacity;
    
    if (this.size < this.capacity) {
      this.size++;
    } else {
      this.head = (this.head + 1) % this.capacity;
    }
  }
  
  public getRecent(count: number): any[] {
    const result: any[] = [];
    const actualCount = Math.min(count, this.size);
    
    for (let i = 0; i < actualCount; i++) {
      const index = (this.tail - 1 - i + this.capacity) % this.capacity;
      result.unshift(this.buffer[index]);
    }
    
    return result;
  }
  
  public clearOlderThan(timestamp: number): void {
    const itemsToKeep: any[] = [];
    
    for (let i = 0; i < this.size; i++) {
      const index = (this.head + i) % this.capacity;
      const item = this.buffer[index];
      
      if (item && item.timestamp > timestamp) {
        itemsToKeep.push(item);
      }
    }
    
    // Reset buffer with kept items
    this.buffer = new Array(this.capacity);
    this.head = 0;
    this.tail = 0;
    this.size = 0;
    
    itemsToKeep.forEach(item => this.push(item));
  }
}
```

## 🔗 Navigation

**Previous**: [Implementation Guide](./implementation-guide.md)  
**Next**: [Comparison Analysis](./comparison-analysis.md)

---

*Best Practices | Production-ready WebSocket patterns and security measures*