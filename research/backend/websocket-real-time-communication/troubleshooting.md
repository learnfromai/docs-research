# Troubleshooting: WebSocket Real-Time Communication

## 🔧 Common Issues & Solutions

### Connection Issues

#### 1. WebSocket Connection Fails

**Symptoms:**
- Client cannot establish WebSocket connection
- Connection immediately closes after establishment
- Handshake failures in browser developer tools

**Common Causes & Solutions:**

```typescript
// Problem: CORS configuration issues
// Solution: Proper CORS setup
const io = new SocketServer(server, {
  cors: {
    origin: process.env.CLIENT_ORIGINS?.split(',') || ['http://localhost:3000'],
    methods: ['GET', 'POST'],
    credentials: true
  }
});

// Problem: Proxy/firewall blocking WebSocket
// Solution: Configure fallback transports
const io = new SocketServer(server, {
  transports: ['websocket', 'polling'], // Fallback to polling
  cors: { origin: "*" }
});

// Problem: SSL/TLS certificate issues
// Solution: Verify SSL configuration
const server = createServer({
  key: fs.readFileSync('/path/to/private.key'),
  cert: fs.readFileSync('/path/to/certificate.crt')
}, app);
```

**Debugging Steps:**
1. Check browser Network tab for WebSocket handshake
2. Verify server CORS configuration
3. Test with different transports
4. Check firewall/proxy settings
5. Validate SSL certificates

#### 2. Frequent Disconnections

**Symptoms:**
- Clients disconnect unexpectedly
- High reconnection frequency
- Intermittent connection drops

**Solutions:**

```typescript
// Implement robust heartbeat mechanism
class ConnectionManager {
  private heartbeatInterval = 25000; // 25 seconds
  private heartbeatTimeout = 60000;  // 60 seconds
  
  setupHeartbeat(socket: Socket) {
    let lastPong = Date.now();
    
    const heartbeat = setInterval(() => {
      if (Date.now() - lastPong > this.heartbeatTimeout) {
        console.log('Client heartbeat timeout, disconnecting');
        socket.disconnect(true);
        clearInterval(heartbeat);
        return;
      }
      
      socket.emit('ping');
    }, this.heartbeatInterval);
    
    socket.on('pong', () => {
      lastPong = Date.now();
    });
    
    socket.on('disconnect', () => {
      clearInterval(heartbeat);
    });
  }
}

// Configure Socket.IO timeouts
const io = new SocketServer(server, {
  pingTimeout: 60000,    // How long to wait for pong
  pingInterval: 25000,   // How often to send ping
  upgradeTimeout: 10000, // How long to wait for upgrade
  allowUpgrades: true
});
```

#### 3. Load Balancer Issues

**Symptoms:**
- Connections work with single server but fail with load balancer
- Messages not reaching all clients
- Room functionality broken

**Solutions:**

```typescript
// Enable sticky sessions for Socket.IO
const io = new SocketServer(server, {
  cors: { origin: "*" },
  // Generate consistent session IDs for sticky sessions
  generateId: (req) => {
    const userId = req._query?.userId;
    if (userId) {
      // Create session ID that routes to same server
      const hash = crypto.createHash('md5').update(userId).digest('hex');
      return `${hash.substring(0, 8)}-${Date.now()}`;
    }
    return require('uuid').v4();
  }
});

// Configure Redis adapter for multi-server setup
import { createAdapter } from '@socket.io/redis-adapter';
import { Redis } from 'ioredis';

const pubClient = new Redis(process.env.REDIS_URL);
const subClient = pubClient.duplicate();

io.adapter(createAdapter(pubClient, subClient));
```

**NGINX Load Balancer Configuration:**
```nginx
upstream websocket_backend {
    # Enable sticky sessions
    ip_hash;
    server app1:3001;
    server app2:3001;
    server app3:3001;
}

server {
    location / {
        proxy_pass http://websocket_backend;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        
        # Sticky session headers
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```

### Performance Issues

#### 4. High Memory Usage

**Symptoms:**
- Server memory consumption continuously increases
- Out of memory errors
- Performance degradation over time

**Diagnostic Tools:**

```typescript
// Memory monitoring utility
class MemoryMonitor {
  private thresholds = {
    warning: 1024 * 1024 * 1024,  // 1GB
    critical: 2048 * 1024 * 1024  // 2GB
  };
  
  startMonitoring() {
    setInterval(() => {
      const memUsage = process.memoryUsage();
      const heapUsed = memUsage.heapUsed;
      const heapTotal = memUsage.heapTotal;
      const external = memUsage.external;
      const rss = memUsage.rss;
      
      console.log('Memory Usage:', {
        heapUsed: Math.round(heapUsed / 1024 / 1024) + 'MB',
        heapTotal: Math.round(heapTotal / 1024 / 1024) + 'MB',
        external: Math.round(external / 1024 / 1024) + 'MB',
        rss: Math.round(rss / 1024 / 1024) + 'MB'
      });
      
      if (heapUsed > this.thresholds.critical) {
        console.error('CRITICAL: Memory usage above 2GB');
        this.triggerMemoryCleanup();
      } else if (heapUsed > this.thresholds.warning) {
        console.warn('WARNING: Memory usage above 1GB');
      }
    }, 30000); // Every 30 seconds
  }
  
  private triggerMemoryCleanup() {
    if (global.gc) {
      console.log('Triggering garbage collection...');
      global.gc();
    }
    
    // Emit warning to monitoring system
    this.emitMemoryAlert();
  }
  
  private emitMemoryAlert() {
    // Send alert to monitoring system
    // Example: Prometheus, DataDog, etc.
  }
}
```

**Memory Leak Prevention:**

```typescript
// Proper cleanup for message history
class MessageHistoryManager {
  private messageHistory = new Map<string, Array<any>>();
  private maxMessages = 1000;
  private maxAge = 24 * 60 * 60 * 1000; // 24 hours
  
  addMessage(roomId: string, message: any) {
    if (!this.messageHistory.has(roomId)) {
      this.messageHistory.set(roomId, []);
    }
    
    const messages = this.messageHistory.get(roomId)!;
    messages.push({
      ...message,
      timestamp: Date.now()
    });
    
    // Trim old messages
    if (messages.length > this.maxMessages) {
      messages.splice(0, messages.length - this.maxMessages);
    }
  }
  
  cleanupOldMessages() {
    const cutoff = Date.now() - this.maxAge;
    
    for (const [roomId, messages] of this.messageHistory.entries()) {
      const filteredMessages = messages.filter(
        msg => msg.timestamp > cutoff
      );
      
      if (filteredMessages.length === 0) {
        this.messageHistory.delete(roomId);
      } else {
        this.messageHistory.set(roomId, filteredMessages);
      }
    }
  }
  
  startCleanupTask() {
    setInterval(() => {
      this.cleanupOldMessages();
    }, 60000); // Every minute
  }
}

// Connection cleanup
class ConnectionCleanup {
  private connections = new Map<string, { socket: Socket; lastActivity: number }>();
  
  trackConnection(socket: Socket) {
    this.connections.set(socket.id, {
      socket,
      lastActivity: Date.now()
    });
    
    socket.on('disconnect', () => {
      this.connections.delete(socket.id);
    });
    
    // Update activity on any event
    socket.onAny(() => {
      const conn = this.connections.get(socket.id);
      if (conn) {
        conn.lastActivity = Date.now();
      }
    });
  }
  
  cleanupStaleConnections() {
    const cutoff = Date.now() - 5 * 60 * 1000; // 5 minutes
    
    for (const [socketId, conn] of this.connections.entries()) {
      if (conn.lastActivity < cutoff) {
        console.log(`Cleaning up stale connection: ${socketId}`);
        conn.socket.disconnect(true);
        this.connections.delete(socketId);
      }
    }
  }
  
  startCleanupTask() {
    setInterval(() => {
      this.cleanupStaleConnections();
    }, 2 * 60 * 1000); // Every 2 minutes
  }
}
```

#### 5. High CPU Usage

**Symptoms:**
- Server CPU usage consistently high
- Response times increase
- Connection timeouts

**Optimization Strategies:**

```typescript
// Message batching to reduce CPU overhead
class MessageBatcher {
  private batches = new Map<string, any[]>();
  private batchTimers = new Map<string, NodeJS.Timeout>();
  private batchSize = 50;
  private batchDelay = 100; // milliseconds
  
  addToBatch(roomId: string, message: any) {
    if (!this.batches.has(roomId)) {
      this.batches.set(roomId, []);
    }
    
    const batch = this.batches.get(roomId)!;
    batch.push(message);
    
    // Send immediately if batch is full
    if (batch.length >= this.batchSize) {
      this.sendBatch(roomId);
    } else if (!this.batchTimers.has(roomId)) {
      // Set timer for partial batch
      const timer = setTimeout(() => {
        this.sendBatch(roomId);
      }, this.batchDelay);
      
      this.batchTimers.set(roomId, timer);
    }
  }
  
  private sendBatch(roomId: string) {
    const batch = this.batches.get(roomId);
    if (!batch || batch.length === 0) return;
    
    // Clear timer
    const timer = this.batchTimers.get(roomId);
    if (timer) {
      clearTimeout(timer);
      this.batchTimers.delete(roomId);
    }
    
    // Send batch
    this.io.to(roomId).emit('message_batch', {
      messages: batch,
      count: batch.length
    });
    
    // Clear batch
    this.batches.set(roomId, []);
  }
}

// Efficient JSON parsing/stringification
class JSONOptimizer {
  private parseCache = new Map<string, any>();
  private stringifyCache = new Map<any, string>();
  
  safeParse(str: string): any {
    if (this.parseCache.has(str)) {
      return this.parseCache.get(str);
    }
    
    try {
      const parsed = JSON.parse(str);
      
      // Cache only small objects to avoid memory issues
      if (str.length < 1000) {
        this.parseCache.set(str, parsed);
        
        // Limit cache size
        if (this.parseCache.size > 1000) {
          const firstKey = this.parseCache.keys().next().value;
          this.parseCache.delete(firstKey);
        }
      }
      
      return parsed;
    } catch (error) {
      console.error('JSON parse error:', error);
      return null;
    }
  }
  
  safeStringify(obj: any): string {
    if (this.stringifyCache.has(obj)) {
      return this.stringifyCache.get(obj)!;
    }
    
    try {
      const stringified = JSON.stringify(obj);
      
      // Cache only small objects
      if (stringified.length < 1000) {
        this.stringifyCache.set(obj, stringified);
        
        // Limit cache size
        if (this.stringifyCache.size > 1000) {
          const firstKey = this.stringifyCache.keys().next().value;
          this.stringifyCache.delete(firstKey);
        }
      }
      
      return stringified;
    } catch (error) {
      console.error('JSON stringify error:', error);
      return '{}';
    }
  }
  
  clearCache() {
    this.parseCache.clear();
    this.stringifyCache.clear();
  }
}
```

### Database Issues

#### 6. Database Connection Pool Exhaustion

**Symptoms:**
- "Connection pool exhausted" errors
- Database timeouts
- Slow query performance

**Solutions:**

```typescript
// Optimized database connection pool
import { Pool } from 'pg';

const dbPool = new Pool({
  host: process.env.DB_HOST,
  port: parseInt(process.env.DB_PORT || '5432'),
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  
  // Pool configuration
  min: 5,                    // Minimum connections
  max: 20,                   // Maximum connections
  idleTimeoutMillis: 30000,  // Close idle connections after 30s
  connectionTimeoutMillis: 2000, // Fail fast on connection timeout
  acquireTimeoutMillis: 5000,    // Timeout waiting for connection
  
  // Query timeouts
  statement_timeout: 10000,  // Kill queries after 10s
  query_timeout: 8000,       // Timeout queries after 8s
  
  // Connection validation
  allowExitOnIdle: false
});

// Connection monitoring
dbPool.on('connect', (client) => {
  console.log('Database client connected');
});

dbPool.on('error', (err, client) => {
  console.error('Database client error:', err);
});

// Pool monitoring
setInterval(() => {
  console.log('DB Pool Status:', {
    totalCount: dbPool.totalCount,
    idleCount: dbPool.idleCount,
    waitingCount: dbPool.waitingCount
  });
}, 30000);

// Query wrapper with proper error handling
async function executeQuery(text: string, params: any[] = []): Promise<any> {
  const client = await dbPool.connect();
  const startTime = Date.now();
  
  try {
    const result = await client.query(text, params);
    const duration = Date.now() - startTime;
    
    if (duration > 1000) {
      console.warn('Slow query detected:', {
        query: text.substring(0, 100),
        duration,
        params: params.length
      });
    }
    
    return result;
  } catch (error) {
    console.error('Database query error:', {
      error: error.message,
      query: text.substring(0, 100),
      params: params.length
    });
    throw error;
  } finally {
    client.release();
  }
}
```

#### 7. Slow Database Queries

**Diagnostic Queries:**

```sql
-- Find slow queries
SELECT 
    query,
    mean_time,
    calls,
    total_time,
    rows,
    100.0 * shared_blks_hit / nullif(shared_blks_hit + shared_blks_read, 0) AS hit_percent
FROM pg_stat_statements
WHERE mean_time > 100  -- Queries taking more than 100ms on average
ORDER BY mean_time DESC
LIMIT 20;

-- Check for missing indexes
SELECT 
    schemaname,
    tablename,
    attname,
    n_distinct,
    correlation
FROM pg_stats
WHERE schemaname = 'public'
    AND n_distinct > 100
    AND correlation < 0.1;

-- Monitor active connections
SELECT 
    pid,
    now() - pg_stat_activity.query_start AS duration,
    query,
    state
FROM pg_stat_activity
WHERE (now() - pg_stat_activity.query_start) > interval '5 minutes'
    AND state = 'active';
```

**Optimization Solutions:**

```typescript
// Query optimization with prepared statements
class OptimizedQueries {
  private preparedQueries = new Map<string, string>();
  
  constructor(private db: Pool) {
    this.preparePerfCriticalQueries();
  }
  
  private async preparePerfCriticalQueries() {
    const queries = [
      {
        name: 'getUserById',
        text: 'SELECT id, username, role, permissions FROM users WHERE id = $1'
      },
      {
        name: 'getRoomParticipants',
        text: `SELECT u.id, u.username, u.role 
               FROM users u 
               WHERE u.id = ANY($1::uuid[])`
      },
      {
        name: 'getRecentMessages',
        text: `SELECT cm.*, u.username 
               FROM chat_messages cm 
               JOIN users u ON cm.user_id = u.id 
               WHERE cm.room_id = $1 
               ORDER BY cm.timestamp DESC 
               LIMIT $2`
      }
    ];
    
    for (const query of queries) {
      try {
        await this.db.query(`PREPARE ${query.name} AS ${query.text}`);
        this.preparedQueries.set(query.name, query.text);
      } catch (error) {
        console.warn(`Failed to prepare query ${query.name}:`, error.message);
      }
    }
  }
  
  async getUserById(userId: string) {
    return this.db.query('EXECUTE getUserById($1)', [userId]);
  }
  
  async getRoomParticipants(userIds: string[]) {
    return this.db.query('EXECUTE getRoomParticipants($1)', [userIds]);
  }
  
  async getRecentMessages(roomId: string, limit: number = 50) {
    return this.db.query('EXECUTE getRecentMessages($1, $2)', [roomId, limit]);
  }
}

// Batch database operations
class BatchOperations {
  private insertBatch: any[] = [];
  private updateBatch: any[] = [];
  private batchSize = 100;
  
  addToInsertBatch(table: string, data: any) {
    this.insertBatch.push({ table, data });
    
    if (this.insertBatch.length >= this.batchSize) {
      this.flushInsertBatch();
    }
  }
  
  private async flushInsertBatch() {
    if (this.insertBatch.length === 0) return;
    
    // Group by table
    const grouped = this.insertBatch.reduce((acc, item) => {
      if (!acc[item.table]) acc[item.table] = [];
      acc[item.table].push(item.data);
      return acc;
    }, {} as Record<string, any[]>);
    
    // Batch insert for each table
    for (const [table, records] of Object.entries(grouped)) {
      await this.batchInsert(table, records);
    }
    
    this.insertBatch = [];
  }
  
  private async batchInsert(table: string, records: any[]) {
    if (records.length === 0) return;
    
    const columns = Object.keys(records[0]);
    const values = records.map((record, index) => 
      `(${columns.map((_, colIndex) => `$${index * columns.length + colIndex + 1}`).join(', ')})`
    ).join(', ');
    
    const params = records.flatMap(record => columns.map(col => record[col]));
    
    const query = `
      INSERT INTO ${table} (${columns.join(', ')})
      VALUES ${values}
      ON CONFLICT DO NOTHING
    `;
    
    try {
      await this.db.query(query, params);
    } catch (error) {
      console.error(`Batch insert failed for table ${table}:`, error);
    }
  }
}
```

### Redis Issues

#### 8. Redis Connection Issues

**Symptoms:**
- Redis connection errors
- Pub/sub messages not delivered
- Session data lost

**Solutions:**

```typescript
// Robust Redis connection with retry logic
import Redis from 'ioredis';

class RedisManager {
  private redis: Redis;
  private subscriber: Redis;
  private publisher: Redis;
  
  constructor() {
    const redisConfig = {
      host: process.env.REDIS_HOST,
      port: parseInt(process.env.REDIS_PORT || '6379'),
      password: process.env.REDIS_PASSWORD,
      db: parseInt(process.env.REDIS_DB || '0'),
      
      // Connection retry configuration
      retryDelayOnFailover: 100,
      retryDelayMs: 50,
      maxRetriesPerRequest: 3,
      connectTimeout: 10000,
      lazyConnect: true,
      keepAlive: 30000,
      
      // Cluster support (if using Redis Cluster)
      enableReadyCheck: false,
      
      // Connection pool
      family: 4,
      
      // Error handling
      maxRetriesPerRequest: null
    };
    
    this.redis = new Redis(redisConfig);
    this.subscriber = new Redis(redisConfig);
    this.publisher = new Redis(redisConfig);
    
    this.setupEventHandlers();
  }
  
  private setupEventHandlers() {
    // Main Redis connection events
    this.redis.on('connect', () => {
      console.log('Redis connected');
    });
    
    this.redis.on('ready', () => {
      console.log('Redis ready');
    });
    
    this.redis.on('error', (error) => {
      console.error('Redis error:', error);
    });
    
    this.redis.on('close', () => {
      console.warn('Redis connection closed');
    });
    
    this.redis.on('reconnecting', () => {
      console.log('Redis reconnecting...');
    });
    
    // Pub/Sub connection events
    this.subscriber.on('error', (error) => {
      console.error('Redis subscriber error:', error);
    });
    
    this.publisher.on('error', (error) => {
      console.error('Redis publisher error:', error);
    });
  }
  
  async healthCheck(): Promise<boolean> {
    try {
      await this.redis.ping();
      return true;
    } catch (error) {
      console.error('Redis health check failed:', error);
      return false;
    }
  }
  
  async safeGet(key: string): Promise<string | null> {
    try {
      return await this.redis.get(key);
    } catch (error) {
      console.error(`Redis GET error for key ${key}:`, error);
      return null;
    }
  }
  
  async safeSet(key: string, value: string, ttl?: number): Promise<boolean> {
    try {
      if (ttl) {
        await this.redis.setex(key, ttl, value);
      } else {
        await this.redis.set(key, value);
      }
      return true;
    } catch (error) {
      console.error(`Redis SET error for key ${key}:`, error);
      return false;
    }
  }
  
  async publish(channel: string, message: string): Promise<boolean> {
    try {
      await this.publisher.publish(channel, message);
      return true;
    } catch (error) {
      console.error(`Redis PUBLISH error for channel ${channel}:`, error);
      return false;
    }
  }
  
  subscribe(channel: string, handler: (message: string) => void) {
    this.subscriber.subscribe(channel);
    this.subscriber.on('message', (receivedChannel, message) => {
      if (receivedChannel === channel) {
        handler(message);
      }
    });
  }
}

// Redis fallback mechanism
class RedisWithFallback {
  private redis: RedisManager;
  private memoryCache = new Map<string, { value: string; expiry: number }>();
  
  constructor(redis: RedisManager) {
    this.redis = redis;
    this.startCacheCleanup();
  }
  
  async get(key: string): Promise<string | null> {
    // Try Redis first
    const redisValue = await this.redis.safeGet(key);
    if (redisValue !== null) {
      return redisValue;
    }
    
    // Fallback to memory cache
    const cached = this.memoryCache.get(key);
    if (cached && cached.expiry > Date.now()) {
      return cached.value;
    }
    
    return null;
  }
  
  async set(key: string, value: string, ttl?: number): Promise<boolean> {
    // Try Redis first
    const redisSuccess = await this.redis.safeSet(key, value, ttl);
    
    // Always cache in memory as fallback
    const expiry = ttl ? Date.now() + (ttl * 1000) : Date.now() + (3600 * 1000);
    this.memoryCache.set(key, { value, expiry });
    
    return redisSuccess;
  }
  
  private startCacheCleanup() {
    setInterval(() => {
      const now = Date.now();
      for (const [key, cached] of this.memoryCache.entries()) {
        if (cached.expiry <= now) {
          this.memoryCache.delete(key);
        }
      }
    }, 60000); // Clean up every minute
  }
}
```

### Security Issues

#### 9. Authentication Bypass

**Symptoms:**
- Unauthorized access to protected resources
- Token validation failures
- Session hijacking

**Prevention Strategies:**

```typescript
// Comprehensive authentication middleware
class SecureAuthentication {
  private blacklistedTokens = new Set<string>();
  private loginAttempts = new Map<string, { count: number; lastAttempt: number }>();
  
  async validateToken(token: string, ipAddress: string): Promise<any> {
    try {
      // Check token blacklist
      if (this.blacklistedTokens.has(token)) {
        throw new Error('Token has been revoked');
      }
      
      // Verify JWT signature and expiration
      const decoded = jwt.verify(token, process.env.JWT_SECRET!) as any;
      
      // Additional security checks
      if (!decoded.userId || !decoded.username) {
        throw new Error('Invalid token payload');
      }
      
      // Check token age (implement token rotation)
      const tokenAge = Date.now() - (decoded.iat * 1000);
      if (tokenAge > 24 * 60 * 60 * 1000) { // 24 hours
        throw new Error('Token too old, please refresh');
      }
      
      // Verify user still exists and is active
      const user = await this.getUserFromDatabase(decoded.userId);
      if (!user || !user.active) {
        throw new Error('User account not found or inactive');
      }
      
      // Check for concurrent session limits
      await this.validateConcurrentSessions(decoded.userId, token);
      
      // Log successful authentication
      this.logAuthEvent(decoded.userId, 'token_validated', ipAddress);
      
      return decoded;
    } catch (error) {
      // Log failed authentication attempt
      this.logAuthEvent(null, 'token_validation_failed', ipAddress, error.message);
      throw error;
    }
  }
  
  private async validateConcurrentSessions(userId: string, currentToken: string) {
    const activeSessions = await this.redis.smembers(`user_sessions:${userId}`);
    
    if (activeSessions.length > 5) { // Max 5 concurrent sessions
      // Remove oldest sessions
      const sessionsToRemove = activeSessions.slice(0, activeSessions.length - 4);
      
      for (const sessionToken of sessionsToRemove) {
        this.blacklistedTokens.add(sessionToken);
        await this.redis.srem(`user_sessions:${userId}`, sessionToken);
      }
    }
    
    // Add current session
    await this.redis.sadd(`user_sessions:${userId}`, currentToken);
    await this.redis.expire(`user_sessions:${userId}`, 24 * 60 * 60); // 24 hours
  }
  
  private logAuthEvent(userId: string | null, event: string, ipAddress: string, error?: string) {
    const logEntry = {
      userId,
      event,
      ipAddress,
      timestamp: new Date().toISOString(),
      error,
      userAgent: 'websocket-server' // Would come from request headers
    };
    
    // Log to security monitoring system
    console.log('Security Event:', logEntry);
    
    // Send to SIEM system if configured
    if (process.env.SIEM_ENDPOINT) {
      this.sendToSIEM(logEntry);
    }
  }
  
  async revokeToken(token: string) {
    this.blacklistedTokens.add(token);
    
    // Store in Redis for persistence across server restarts
    await this.redis.sadd('blacklisted_tokens', token);
    
    // Set expiration based on token's remaining lifetime
    try {
      const decoded = jwt.decode(token) as any;
      if (decoded && decoded.exp) {
        const ttl = decoded.exp - Math.floor(Date.now() / 1000);
        if (ttl > 0) {
          await this.redis.setex(`blacklist:${token}`, ttl, '1');
        }
      }
    } catch (error) {
      // Token already expired or invalid
    }
  }
  
  async loadBlacklistedTokens() {
    try {
      const tokens = await this.redis.smembers('blacklisted_tokens');
      tokens.forEach(token => this.blacklistedTokens.add(token));
    } catch (error) {
      console.error('Failed to load blacklisted tokens:', error);
    }
  }
}
```

#### 10. Rate Limiting Bypass

**Symptoms:**
- Unusual traffic patterns
- Rate limiting not effective
- DDoS attacks succeeding

**Enhanced Rate Limiting:**

```typescript
// Multi-layer rate limiting
class AdvancedRateLimiting {
  private redis: Redis;
  private rateLimits = {
    global: { window: 60, max: 10000 },      // Global server limit
    perIP: { window: 60, max: 100 },         // Per IP limit
    perUser: { window: 60, max: 200 },       // Per authenticated user
    perEndpoint: { window: 60, max: 50 }     // Per endpoint per user
  };
  
  async checkRateLimit(
    identifier: string,
    limitType: keyof typeof this.rateLimits,
    endpoint?: string
  ): Promise<{ allowed: boolean; remaining: number; resetTime: number }> {
    const limit = this.rateLimits[limitType];
    const key = this.buildRateLimitKey(identifier, limitType, endpoint);
    
    const now = Date.now();
    const windowStart = now - (limit.window * 1000);
    
    // Use Redis sliding window rate limiting
    const pipeline = this.redis.pipeline();
    
    // Remove old entries
    pipeline.zremrangebyscore(key, 0, windowStart);
    
    // Count current requests
    pipeline.zcard(key);
    
    // Add current request
    pipeline.zadd(key, now, `${now}-${Math.random()}`);
    
    // Set expiration
    pipeline.expire(key, limit.window + 1);
    
    const results = await pipeline.exec();
    const currentCount = results![1][1] as number;
    
    const allowed = currentCount < limit.max;
    const remaining = Math.max(0, limit.max - currentCount - 1);
    const resetTime = now + (limit.window * 1000);
    
    if (!allowed) {
      // Log rate limit violation
      this.logRateLimitViolation(identifier, limitType, endpoint, currentCount);
      
      // Increment violation counter
      await this.trackViolation(identifier);
    }
    
    return { allowed, remaining, resetTime };
  }
  
  private buildRateLimitKey(identifier: string, limitType: string, endpoint?: string): string {
    let key = `rate_limit:${limitType}:${identifier}`;
    if (endpoint) {
      key += `:${endpoint}`;
    }
    return key;
  }
  
  private async trackViolation(identifier: string) {
    const violationKey = `violations:${identifier}`;
    const violations = await this.redis.incr(violationKey);
    await this.redis.expire(violationKey, 3600); // 1 hour window
    
    // Escalate if too many violations
    if (violations > 10) {
      await this.escalateViolation(identifier);
    }
  }
  
  private async escalateViolation(identifier: string) {
    // Temporary ban
    const banKey = `banned:${identifier}`;
    await this.redis.setex(banKey, 900, '1'); // 15 minute ban
    
    // Alert administrators
    console.error(`Rate limit violations exceeded for ${identifier}, temporary ban applied`);
    
    // Send alert to monitoring system
    this.sendSecurityAlert({
      type: 'rate_limit_escalation',
      identifier,
      timestamp: new Date().toISOString(),
      action: 'temporary_ban'
    });
  }
  
  async isBlocked(identifier: string): Promise<boolean> {
    const isBanned = await this.redis.exists(`banned:${identifier}`);
    return isBanned === 1;
  }
  
  private logRateLimitViolation(
    identifier: string,
    limitType: string,
    endpoint: string | undefined,
    requestCount: number
  ) {
    console.warn('Rate limit exceeded:', {
      identifier,
      limitType,
      endpoint,
      requestCount,
      timestamp: new Date().toISOString()
    });
  }
  
  private sendSecurityAlert(alert: any) {
    // Send to monitoring/alerting system
    // Implementation depends on your monitoring stack
  }
}
```

## 🔧 Debugging Tools & Techniques

### Real-Time Monitoring

```typescript
// Comprehensive monitoring dashboard
class WebSocketMonitor {
  private metrics = {
    connections: { total: 0, active: 0, rooms: new Map() },
    messages: { sent: 0, received: 0, failed: 0 },
    performance: { avgLatency: 0, maxLatency: 0 },
    errors: { total: 0, byType: new Map() }
  };
  
  startMonitoring(io: SocketServer) {
    // Connection monitoring
    io.on('connection', (socket) => {
      this.metrics.connections.total++;
      this.metrics.connections.active++;
      
      socket.on('disconnect', () => {
        this.metrics.connections.active--;
      });
      
      // Message monitoring
      socket.onAny((eventName, data) => {
        this.metrics.messages.received++;
        this.trackMessageLatency(data);
      });
      
      socket.onAnyOutgoing((eventName, data) => {
        this.metrics.messages.sent++;
      });
    });
    
    // Error monitoring
    io.engine.on('connection_error', (error) => {
      this.metrics.errors.total++;
      this.trackError('connection_error', error);
    });
    
    // Start metrics reporting
    this.startMetricsReporting();
  }
  
  private trackMessageLatency(data: any) {
    if (data && data._timestamp) {
      const latency = Date.now() - data._timestamp;
      this.updateLatencyMetrics(latency);
    }
  }
  
  private updateLatencyMetrics(latency: number) {
    // Simple moving average
    this.metrics.performance.avgLatency = 
      (this.metrics.performance.avgLatency + latency) / 2;
    
    if (latency > this.metrics.performance.maxLatency) {
      this.metrics.performance.maxLatency = latency;
    }
  }
  
  private trackError(type: string, error: any) {
    const current = this.metrics.errors.byType.get(type) || 0;
    this.metrics.errors.byType.set(type, current + 1);
  }
  
  private startMetricsReporting() {
    setInterval(() => {
      this.reportMetrics();
    }, 30000); // Every 30 seconds
  }
  
  private reportMetrics() {
    const report = {
      timestamp: new Date().toISOString(),
      connections: {
        total: this.metrics.connections.total,
        active: this.metrics.connections.active,
        rooms: this.metrics.connections.rooms.size
      },
      messages: {
        sent: this.metrics.messages.sent,
        received: this.metrics.messages.received,
        failed: this.metrics.messages.failed,
        rate: this.calculateMessageRate()
      },
      performance: {
        avgLatency: Math.round(this.metrics.performance.avgLatency),
        maxLatency: this.metrics.performance.maxLatency
      },
      errors: {
        total: this.metrics.errors.total,
        byType: Object.fromEntries(this.metrics.errors.byType)
      }
    };
    
    console.log('WebSocket Metrics:', JSON.stringify(report, null, 2));
    
    // Send to monitoring system
    this.sendToMonitoringSystem(report);
  }
  
  private calculateMessageRate(): number {
    // Implementation for message rate calculation
    return this.metrics.messages.sent + this.metrics.messages.received;
  }
  
  private sendToMonitoringSystem(metrics: any) {
    // Send to Prometheus, DataDog, etc.
  }
  
  getHealthStatus() {
    return {
      status: this.metrics.connections.active > 0 ? 'healthy' : 'idle',
      connections: this.metrics.connections.active,
      avgLatency: this.metrics.performance.avgLatency,
      errorRate: this.metrics.errors.total / (this.metrics.messages.sent + this.metrics.messages.received)
    };
  }
}
```

### Debugging Commands

```bash
# Monitor WebSocket connections
ss -tuln | grep :3001

# Check process resources
ps aux | grep node
top -p $(pgrep -f "node.*server")

# Monitor network traffic
netstat -i
iftop -i eth0

# Check system resources
free -h
df -h
iostat 1 5

# Monitor logs in real-time
tail -f logs/combined.log | jq '.'
tail -f logs/error.log | grep -E "(ERROR|WARN)"

# Database monitoring
psql -h localhost -U postgres -d websocket_prod -c "
  SELECT 
    count(*) as active_connections,
    avg(extract(epoch from (now() - query_start))) as avg_query_time
  FROM pg_stat_activity 
  WHERE state = 'active';"

# Redis monitoring
redis-cli --latency-history -h localhost -p 6379
redis-cli INFO memory
redis-cli MONITOR
```

## 🔗 Navigation

**Previous**: [Deployment Guide](./deployment-guide.md)  
**Back to**: [README](./README.md)

---

*Troubleshooting Guide | Common issues and solutions for production WebSocket applications*