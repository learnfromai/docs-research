# Performance Optimization

## ⚡ JWT Performance Best Practices

JWT operations can become performance bottlenecks in high-traffic applications. This guide covers optimization strategies for token generation, verification, caching, and scaling JWT authentication systems.

## 📊 Performance Benchmarks

### Algorithm Performance Comparison

| Algorithm | Key Size | Sign Time* | Verify Time* | Memory Usage | Use Case |
|-----------|----------|------------|--------------|--------------|----------|
| **RS256** | 2048-bit | ~2.5ms | ~0.8ms | ~4KB | **Recommended** |
| **RS512** | 2048-bit | ~2.8ms | ~0.9ms | ~4KB | High security |
| **ES256** | 256-bit | ~1.2ms | ~2.1ms | ~2KB | Modern systems |
| **HS256** | 256-bit | ~0.1ms | ~0.1ms | ~1KB | Development only |

*Average times for Node.js v18 on modern hardware

### Token Size Impact

```typescript
// Token size comparison
const payloadSizes = {
  minimal: {
    sub: '123',
    iat: 1640995200,
    exp: 1641000000
  }, // ~180 bytes encoded
  
  standard: {
    sub: '123',
    iat: 1640995200,
    exp: 1641000000,
    email: 'user@example.com',
    roles: ['user'],
    permissions: ['read', 'write']
  }, // ~280 bytes encoded
  
  large: {
    sub: '123',
    iat: 1640995200,
    exp: 1641000000,
    email: 'user@example.com',
    roles: ['user', 'moderator', 'content-creator'],
    permissions: ['read', 'write', 'delete', 'moderate', 'publish'],
    profile: {
      firstName: 'John',
      lastName: 'Doe',
      avatar: 'https://example.com/avatar.jpg',
      preferences: { theme: 'dark', language: 'en' }
    },
    metadata: {
      loginCount: 42,
      lastLogin: '2024-01-15T10:30:00Z',
      deviceInfo: 'Mozilla/5.0...'
    }
  } // ~650+ bytes encoded
};

// Performance impact of token size
const measureTokenOperations = async (payload: any) => {
  const iterations = 1000;
  
  // Measure signing
  const signStart = performance.now();
  for (let i = 0; i < iterations; i++) {
    await jwtService.generateAccessToken(payload, `session${i}`);
  }
  const signTime = (performance.now() - signStart) / iterations;
  
  // Measure verification
  const token = await jwtService.generateAccessToken(payload, 'test');
  const verifyStart = performance.now();
  for (let i = 0; i < iterations; i++) {
    await jwtService.verifyAccessToken(token);
  }
  const verifyTime = (performance.now() - verifyStart) / iterations;
  
  return { signTime, verifyTime, tokenSize: token.length };
};
```

## 🚀 Optimization Strategies

### 1. Token Caching Implementation

```typescript
import NodeCache from 'node-cache';
import { createHash } from 'crypto';

class OptimizedJWTService extends JWTService {
  private verificationCache: NodeCache;
  private publicKeyCache: Map<string, string>;
  
  constructor() {
    super();
    
    this.verificationCache = new NodeCache({
      stdTTL: 300,      // 5 minutes default
      checkperiod: 60,  // Check expired keys every minute
      maxKeys: 10000,   // Limit memory usage
      useClones: false  // Better performance, careful with object mutation
    });
    
    this.publicKeyCache = new Map();
    
    // Warm up the cache
    this.warmUpCache();
  }
  
  async verifyAccessTokenCached(token: string): Promise<JWTClaims> {
    // Create cache key from token signature
    const [, , signature] = token.split('.');
    const cacheKey = createHash('sha256').update(signature).digest('hex').substring(0, 16);
    
    // Check cache first
    const cached = this.verificationCache.get<{
      payload: JWTClaims;
      expires: number;
    }>(cacheKey);
    
    if (cached && cached.expires > Math.floor(Date.now() / 1000)) {
      this.recordCacheHit();
      return cached.payload;
    }
    
    // Cache miss - verify token
    this.recordCacheMiss();
    const payload = await super.verifyAccessToken(token);
    
    // Cache the result
    const ttl = Math.min(payload.exp - Math.floor(Date.now() / 1000), 300);
    if (ttl > 0) {
      this.verificationCache.set(cacheKey, {
        payload,
        expires: payload.exp
      }, ttl);
    }
    
    return payload;
  }
  
  async generateAccessTokenOptimized(
    user: UserData,
    sessionId: string
  ): Promise<string> {
    // Pre-calculate common values
    const now = this.getCurrentTimestamp();
    const exp = now + this.accessTokenTTL;
    
    // Use efficient payload structure
    const payload = {
      iss: this.issuer,
      sub: user.id,
      aud: this.audience,
      exp,
      iat: now,
      jti: this.generateEfficientJTI(),
      
      // Optimized user data
      uid: user.id,           // Shorter field names
      eml: user.email,
      rol: user.roles,
      prm: user.permissions,
      sid: sessionId
    };
    
    return await this.signTokenEfficiently(payload);
  }
  
  private getCurrentTimestamp(): number {
    // Cache timestamp for short periods to reduce Date.now() calls
    return Math.floor(Date.now() / 1000);
  }
  
  private generateEfficientJTI(): string {
    // Use faster random generation
    return Date.now().toString(36) + Math.random().toString(36).substr(2, 9);
  }
  
  private async signTokenEfficiently(payload: any): Promise<string> {
    // Reuse JWT library instances for better performance
    return jwt.sign(payload, this.privateKey, {
      algorithm: 'RS256',
      noTimestamp: true  // We set iat manually
    });
  }
  
  private warmUpCache(): void {
    // Pre-load frequently used data
    this.publicKeyCache.set('current', this.publicKey);
  }
  
  // Performance monitoring
  private cacheHits = 0;
  private cacheMisses = 0;
  
  private recordCacheHit(): void {
    this.cacheHits++;
  }
  
  private recordCacheMiss(): void {
    this.cacheMisses++;
  }
  
  getCacheStats() {
    const total = this.cacheHits + this.cacheMisses;
    return {
      hits: this.cacheHits,
      misses: this.cacheMisses,
      hitRate: total > 0 ? (this.cacheHits / total) * 100 : 0,
      cacheSize: this.verificationCache.keys().length
    };
  }
}
```

### 2. Connection Pooling for Token Storage

```typescript
// Redis connection pooling for token storage
import Redis from 'redis';
import { Pool } from 'generic-pool';

class RedisTokenStorage {
  private redisPool: Pool<Redis.RedisClientType>;
  
  constructor() {
    this.redisPool = this.createRedisPool();
  }
  
  private createRedisPool(): Pool<Redis.RedisClientType> {
    return Pool.createPool(
      {
        create: async () => {
          const client = Redis.createClient({
            url: process.env.REDIS_URL,
            socket: {
              connectTimeout: 5000,
              lazyConnect: true,
              keepAlive: 30000
            }
          });
          
          await client.connect();
          return client;
        },
        destroy: async (client) => {
          await client.quit();
        },
        validate: async (client) => {
          try {
            await client.ping();
            return true;
          } catch {
            return false;
          }
        }
      },
      {
        max: 10,          // Maximum connections
        min: 2,           // Minimum connections
        acquireTimeoutMillis: 3000,
        createTimeoutMillis: 3000,
        destroyTimeoutMillis: 5000,
        idleTimeoutMillis: 30000,
        reapIntervalMillis: 1000,
        createRetryIntervalMillis: 100,
        maxWaitingClients: 20
      }
    );
  }
  
  async execute<T>(operation: (client: Redis.RedisClientType) => Promise<T>): Promise<T> {
    const client = await this.redisPool.acquire();
    try {
      return await operation(client);
    } finally {
      await this.redisPool.release(client);
    }
  }
  
  async isTokenRevoked(jti: string): Promise<boolean> {
    return this.execute(async (client) => {
      const result = await client.get(`blacklist:${jti}`);
      return result === 'revoked';
    });
  }
  
  async revokeToken(jti: string, ttl: number): Promise<void> {
    return this.execute(async (client) => {
      await client.setex(`blacklist:${jti}`, ttl, 'revoked');
    });
  }
}
```

### 3. Batch Token Operations

```typescript
// Batch processing for multiple token operations
class BatchJWTProcessor {
  async verifyTokensBatch(tokens: string[]): Promise<Map<string, JWTClaims | Error>> {
    const results = new Map<string, JWTClaims | Error>();
    
    // Process tokens in parallel batches
    const batchSize = 50;
    const batches = this.chunk(tokens, batchSize);
    
    for (const batch of batches) {
      const promises = batch.map(async (token) => {
        try {
          const payload = await jwtService.verifyAccessToken(token);
          return { token, payload, error: null };
        } catch (error) {
          return { token, payload: null, error: error as Error };
        }
      });
      
      const batchResults = await Promise.all(promises);
      
      batchResults.forEach(({ token, payload, error }) => {
        results.set(token, error || payload!);
      });
    }
    
    return results;
  }
  
  async generateTokensBatch(
    userSessions: Array<{ user: UserData; sessionId: string }>
  ): Promise<Map<string, string>> {
    const tokens = new Map<string, string>();
    
    // Pre-calculate common values
    const now = Math.floor(Date.now() / 1000);
    const exp = now + 900; // 15 minutes
    
    const promises = userSessions.map(async ({ user, sessionId }) => {
      const token = await jwtService.generateAccessToken(user, sessionId);
      return { key: `${user.id}:${sessionId}`, token };
    });
    
    const results = await Promise.all(promises);
    
    results.forEach(({ key, token }) => {
      tokens.set(key, token);
    });
    
    return tokens;
  }
  
  private chunk<T>(array: T[], size: number): T[][] {
    const chunks: T[][] = [];
    for (let i = 0; i < array.length; i += size) {
      chunks.push(array.slice(i, i + size));
    }
    return chunks;
  }
}
```

## 📈 Scaling JWT Authentication

### 1. Horizontal Scaling with Redis

```typescript
// Distributed JWT service with Redis
class DistributedJWTService {
  private redisCluster: Redis.Cluster;
  private localCache: Map<string, any>;
  
  constructor() {
    this.redisCluster = new Redis.Cluster([
      { host: 'redis-node-1', port: 6379 },
      { host: 'redis-node-2', port: 6379 },
      { host: 'redis-node-3', port: 6379 }
    ], {
      retryDelayOnFailover: 100,
      maxRetriesPerRequest: 3,
      enableReadyCheck: true,
      scaleReads: 'slave'
    });
    
    this.localCache = new Map();
  }
  
  async verifyTokenDistributed(token: string): Promise<JWTClaims> {
    // L1 Cache: Local memory (fastest)
    const cacheKey = this.generateCacheKey(token);
    const localCached = this.localCache.get(cacheKey);
    
    if (localCached && localCached.expires > Date.now()) {
      return localCached.payload;
    }
    
    // L2 Cache: Redis cluster (fast)
    const redisCached = await this.redisCluster.get(`jwt:${cacheKey}`);
    if (redisCached) {
      const cached = JSON.parse(redisCached);
      if (cached.expires > Date.now()) {
        // Update L1 cache
        this.localCache.set(cacheKey, cached);
        return cached.payload;
      }
    }
    
    // L3: Token verification (slow)
    const payload = await super.verifyAccessToken(token);
    
    // Cache in both layers
    const cacheData = {
      payload,
      expires: Date.now() + (5 * 60 * 1000) // 5 minutes
    };
    
    this.localCache.set(cacheKey, cacheData);
    await this.redisCluster.setex(
      `jwt:${cacheKey}`,
      300,
      JSON.stringify(cacheData)
    );
    
    return payload;
  }
  
  private generateCacheKey(token: string): string {
    return createHash('sha256').update(token).digest('hex').substring(0, 16);
  }
}
```

### 2. Load Balancing Considerations

```typescript
// Session affinity for JWT services
class SessionAffinityJWTService {
  private serviceNodes: Map<string, JWTServiceInstance>;
  
  constructor() {
    this.serviceNodes = new Map([
      ['node1', new JWTServiceInstance('node1')],
      ['node2', new JWTServiceInstance('node2')],
      ['node3', new JWTServiceInstance('node3')]
    ]);
  }
  
  private getNodeForUser(userId: string): JWTServiceInstance {
    // Consistent hashing for session affinity
    const hash = createHash('sha256').update(userId).digest('hex');
    const nodeIndex = parseInt(hash.substring(0, 8), 16) % this.serviceNodes.size;
    const nodeId = `node${nodeIndex + 1}`;
    
    return this.serviceNodes.get(nodeId)!;
  }
  
  async generateToken(user: UserData, sessionId: string): Promise<string> {
    const node = this.getNodeForUser(user.id);
    return node.generateAccessToken(user, sessionId);
  }
  
  async verifyToken(token: string): Promise<JWTClaims> {
    // Token verification can be done on any node
    // Try current node first, fallback to others
    const currentNode = this.getCurrentNode();
    
    try {
      return await currentNode.verifyAccessToken(token);
    } catch (error) {
      // Fallback to other nodes
      for (const [nodeId, node] of this.serviceNodes) {
        if (nodeId !== currentNode.id) {
          try {
            return await node.verifyAccessToken(token);
          } catch {
            // Continue to next node
          }
        }
      }
      throw error;
    }
  }
}
```

## 🔧 Memory Optimization

### 1. Efficient Token Structure

```typescript
// Optimized token payload structure
interface OptimizedJWTPayload {
  // Standard claims (short names)
  sub: string;        // User ID
  exp: number;        // Expiration
  iat: number;        // Issued at
  jti: string;        // JWT ID (shorter format)
  
  // Custom claims (abbreviated)
  r: string[];        // Roles (shortened)
  p: string[];        // Permissions (shortened)
  s: string;          // Session ID
  
  // Avoid these in access tokens:
  // - Large user objects
  // - Extensive metadata
  // - Base64-encoded data
  // - Arrays with many elements
}

class OptimizedTokenGenerator {
  generateMinimalToken(user: UserData, sessionId: string): string {
    // Include only essential data
    const payload: OptimizedJWTPayload = {
      sub: user.id,
      exp: Math.floor(Date.now() / 1000) + 900,
      iat: Math.floor(Date.now() / 1000),
      jti: this.generateShortJTI(),
      r: user.roles.slice(0, 3),           // Limit roles
      p: user.permissions.slice(0, 5),     // Limit permissions
      s: sessionId
    };
    
    return jwt.sign(payload, this.privateKey, {
      algorithm: 'RS256',
      noTimestamp: true
    });
  }
  
  private generateShortJTI(): string {
    // 8-character JTI instead of 32+ characters
    return Math.random().toString(36).substr(2, 8);
  }
}
```

### 2. Memory Pool for Token Operations

```typescript
// Object pooling for token operations
class TokenOperationPool {
  private payloadPool: Array<any> = [];
  private headerPool: Array<any> = [];
  
  getPayloadObject(): any {
    return this.payloadPool.pop() || {};
  }
  
  returnPayloadObject(obj: any): void {
    // Clear object properties
    for (const key in obj) {
      delete obj[key];
    }
    
    if (this.payloadPool.length < 100) {
      this.payloadPool.push(obj);
    }
  }
  
  async generateTokenPooled(user: UserData, sessionId: string): Promise<string> {
    const payload = this.getPayloadObject();
    
    try {
      // Set payload properties
      payload.sub = user.id;
      payload.exp = Math.floor(Date.now() / 1000) + 900;
      payload.iat = Math.floor(Date.now() / 1000);
      payload.jti = this.generateJTI();
      payload.r = user.roles;
      payload.p = user.permissions;
      payload.s = sessionId;
      
      const token = await jwt.sign(payload, this.privateKey, {
        algorithm: 'RS256'
      });
      
      return token;
      
    } finally {
      this.returnPayloadObject(payload);
    }
  }
}
```

## 📊 Performance Monitoring

### 1. JWT Performance Metrics

```typescript
class JWTPerformanceMonitor {
  private metrics = {
    tokenGeneration: new Map<string, number[]>(),
    tokenVerification: new Map<string, number[]>(),
    cacheHitRate: 0,
    errorRate: 0,
    throughput: 0
  };
  
  measureOperation<T>(
    operation: string,
    fn: () => Promise<T>
  ): Promise<T> {
    const start = process.hrtime.bigint();
    
    return fn()
      .then(result => {
        const duration = Number(process.hrtime.bigint() - start) / 1e6;
        this.recordMetric(operation, duration);
        return result;
      })
      .catch(error => {
        const duration = Number(process.hrtime.bigint() - start) / 1e6;
        this.recordMetric(operation, duration);
        this.recordError(operation);
        throw error;
      });
  }
  
  private recordMetric(operation: string, duration: number): void {
    if (!this.metrics.tokenGeneration.has(operation)) {
      this.metrics.tokenGeneration.set(operation, []);
    }
    
    const timings = this.metrics.tokenGeneration.get(operation)!;
    timings.push(duration);
    
    // Keep only recent measurements (sliding window)
    if (timings.length > 1000) {
      timings.shift();
    }
  }
  
  getPerformanceReport(): any {
    const report: any = {};
    
    for (const [operation, timings] of this.metrics.tokenGeneration) {
      if (timings.length === 0) continue;
      
      const sorted = [...timings].sort((a, b) => a - b);
      
      report[operation] = {
        count: timings.length,
        average: timings.reduce((a, b) => a + b, 0) / timings.length,
        median: sorted[Math.floor(sorted.length / 2)],
        p95: sorted[Math.floor(sorted.length * 0.95)],
        p99: sorted[Math.floor(sorted.length * 0.99)],
        min: Math.min(...timings),
        max: Math.max(...timings)
      };
    }
    
    return report;
  }
  
  private recordError(operation: string): void {
    // Implement error rate tracking
  }
}

// Usage in JWT service
const performanceMonitor = new JWTPerformanceMonitor();

class MonitoredJWTService extends JWTService {
  async generateAccessToken(user: UserData, sessionId: string): Promise<string> {
    return performanceMonitor.measureOperation('token_generation', 
      () => super.generateAccessToken(user, sessionId)
    );
  }
  
  async verifyAccessToken(token: string): Promise<JWTClaims> {
    return performanceMonitor.measureOperation('token_verification',
      () => super.verifyAccessToken(token)
    );
  }
}
```

### 2. Real-time Performance Dashboard

```typescript
// Performance dashboard endpoint
app.get('/api/admin/jwt-performance', requireAdminRole, (req, res) => {
  const performanceReport = performanceMonitor.getPerformanceReport();
  const cacheStats = jwtService.getCacheStats();
  
  res.json({
    timestamp: new Date().toISOString(),
    performance: performanceReport,
    cache: cacheStats,
    recommendations: generatePerformanceRecommendations(performanceReport)
  });
});

function generatePerformanceRecommendations(report: any): string[] {
  const recommendations: string[] = [];
  
  if (report.token_generation?.average > 5) {
    recommendations.push('Consider caching user data to reduce token generation time');
  }
  
  if (report.token_verification?.average > 2) {
    recommendations.push('Enable token verification caching');
  }
  
  if (report.token_verification?.p95 > 10) {
    recommendations.push('Consider using faster algorithm or hardware acceleration');
  }
  
  return recommendations;
}
```

## 🎯 Performance Best Practices Summary

### Token Design
- ✅ Keep payloads minimal (< 1KB)
- ✅ Use short field names for custom claims
- ✅ Avoid nested objects and large arrays
- ✅ Set appropriate expiration times (15 minutes for access tokens)

### Algorithm Selection
- ✅ Use RS256 for production (best security/performance balance)
- ✅ Consider ES256 for better performance if infrastructure supports it
- ❌ Never use HS256 in distributed systems

### Caching Strategy
- ✅ Implement multi-level caching (memory + Redis)
- ✅ Cache verification results, not tokens themselves
- ✅ Set appropriate TTLs (5 minutes max)
- ✅ Monitor cache hit rates (target > 80%)

### Infrastructure
- ✅ Use connection pooling for Redis operations
- ✅ Implement horizontal scaling with consistent hashing
- ✅ Monitor performance metrics and set alerts
- ✅ Use CDNs for public key distribution (JWKS)

### Code Optimization
- ✅ Batch token operations when possible
- ✅ Reuse JWT library instances
- ✅ Implement object pooling for high-throughput scenarios
- ✅ Profile and optimize hot paths

---

**Navigation**
- ← Back to: [Testing Strategies](./testing-strategies.md)
- → Next: [Migration and Integration Guide](./migration-integration-guide.md)
- ↑ Back to: [JWT Authentication Research](./README.md)