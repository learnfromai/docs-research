# Scalability Approaches in Express.js Applications

## 🚀 Scalability Overview

Scalability is crucial for production Express.js applications that need to handle increasing load, user growth, and feature complexity. This analysis examines proven scalability strategies from successful open source projects, covering horizontal scaling, performance optimization, caching strategies, and infrastructure patterns.

---

## 📊 Scalability Fundamentals

### Scalability Dimensions
| Dimension | Description | Strategies | Trade-offs |
|-----------|-------------|------------|------------|
| **Horizontal** | Add more servers | Load balancing, clustering | Complexity, consistency |
| **Vertical** | Increase server resources | CPU, RAM, SSD upgrades | Cost, hardware limits |
| **Database** | Scale data layer | Sharding, read replicas | Complexity, eventual consistency |
| **Functional** | Split by features | Microservices, modular design | Network overhead, coordination |

---

## ⚡ Performance Optimization

### 1. Node.js Process Optimization

```typescript
// Cluster mode for multi-core utilization
import cluster from 'cluster';
import os from 'os';

if (cluster.isPrimary) {
  const numCPUs = os.cpus().length;
  console.log(`Primary ${process.pid} is running`);

  // Fork workers
  for (let i = 0; i < numCPUs; i++) {
    cluster.fork();
  }

  cluster.on('exit', (worker, code, signal) => {
    console.log(`Worker ${worker.process.pid} died`);
    // Replace dead worker
    cluster.fork();
  });
} else {
  // Worker process runs the Express app
  const app = express();
  
  // Graceful shutdown handling
  process.on('SIGTERM', () => {
    console.log('SIGTERM received, shutting down gracefully');
    server.close(() => {
      console.log('Process terminated');
      process.exit(0);
    });
  });

  const server = app.listen(port, () => {
    console.log(`Worker ${process.pid} started on port ${port}`);
  });
}

// PM2 ecosystem configuration
// ecosystem.config.js
module.exports = {
  apps: [{
    name: 'api-server',
    script: './dist/app.js',
    instances: 'max', // Use all available CPUs
    exec_mode: 'cluster',
    max_memory_restart: '1G',
    node_args: '--max-old-space-size=1024',
    env: {
      NODE_ENV: 'production',
      PORT: 3000,
    },
    error_file: './logs/err.log',
    out_file: './logs/out.log',
    log_file: './logs/combined.log',
    time: true,
  }],
};
```

### 2. Memory Management & Garbage Collection

```typescript
// Memory monitoring and optimization
class MemoryMonitor {
  private readonly memoryThreshold = 0.8; // 80% of available memory

  startMonitoring(): void {
    setInterval(() => {
      const usage = process.memoryUsage();
      const usageInMB = {
        rss: Math.round(usage.rss / 1024 / 1024),
        heapTotal: Math.round(usage.heapTotal / 1024 / 1024),
        heapUsed: Math.round(usage.heapUsed / 1024 / 1024),
        external: Math.round(usage.external / 1024 / 1024),
      };

      console.log('Memory usage:', usageInMB);

      // Trigger garbage collection if memory usage is high
      if (usage.heapUsed / usage.heapTotal > this.memoryThreshold) {
        if (global.gc) {
          global.gc();
          console.log('Garbage collection triggered');
        }
      }
    }, 30000); // Check every 30 seconds
  }

  // Object pool for frequent allocations
  createObjectPool<T>(factory: () => T, reset: (obj: T) => void, initialSize = 10): ObjectPool<T> {
    const pool: T[] = [];
    
    // Pre-populate pool
    for (let i = 0; i < initialSize; i++) {
      pool.push(factory());
    }

    return {
      acquire(): T {
        return pool.pop() || factory();
      },
      
      release(obj: T): void {
        reset(obj);
        if (pool.length < initialSize * 2) {
          pool.push(obj);
        }
      },
    };
  }
}

// Stream processing for large datasets
class StreamProcessor {
  async processLargeDataset(query: any): Promise<void> {
    const stream = await database.streamQuery(query);
    
    return new Promise((resolve, reject) => {
      const transform = new Transform({
        objectMode: true,
        transform(chunk, encoding, callback) {
          try {
            const processed = this.processChunk(chunk);
            callback(null, processed);
          } catch (error) {
            callback(error);
          }
        },
      });

      const writableStream = new Writable({
        objectMode: true,
        write(chunk, encoding, callback) {
          // Process or store transformed data
          this.handleProcessedData(chunk);
          callback();
        },
      });

      stream
        .pipe(transform)
        .pipe(writableStream)
        .on('finish', resolve)
        .on('error', reject);
    });
  }

  private processChunk(data: any): any {
    // Transform data without holding large objects in memory
    return {
      id: data.id,
      processedAt: new Date(),
      result: this.calculateResult(data),
    };
  }
}
```

### 3. Database Optimization

```typescript
// Connection pooling and optimization
import { Pool } from 'pg';

class DatabaseManager {
  private pool: Pool;

  constructor() {
    this.pool = new Pool({
      host: process.env.DB_HOST,
      port: parseInt(process.env.DB_PORT!),
      database: process.env.DB_NAME,
      user: process.env.DB_USER,
      password: process.env.DB_PASSWORD,
      
      // Connection pool settings
      min: 5, // Minimum pool size
      max: 20, // Maximum pool size
      idleTimeoutMillis: 30000, // Close idle connections after 30s
      connectionTimeoutMillis: 2000, // Return error after 2s if no connection available
      
      // Query timeout
      query_timeout: 10000, // 10 second query timeout
      
      // SSL configuration for production
      ssl: process.env.NODE_ENV === 'production' ? {
        rejectUnauthorized: false,
      } : false,
    });

    // Pool event handlers
    this.pool.on('connect', (client) => {
      console.log('New client connected');
    });

    this.pool.on('error', (err, client) => {
      console.error('Database pool error:', err);
    });
  }

  // Query with automatic retry
  async query(text: string, params?: any[]): Promise<any> {
    const maxRetries = 3;
    let retries = 0;

    while (retries < maxRetries) {
      try {
        const start = Date.now();
        const result = await this.pool.query(text, params);
        const duration = Date.now() - start;

        // Log slow queries
        if (duration > 1000) {
          console.warn(`Slow query detected: ${duration}ms`, { text, params });
        }

        return result;
      } catch (error) {
        retries++;
        if (retries >= maxRetries) {
          throw error;
        }
        
        // Exponential backoff
        await this.delay(Math.pow(2, retries) * 100);
      }
    }
  }

  // Read/write splitting
  async executeRead(query: string, params?: any[]): Promise<any> {
    // Use read replica for read operations
    return this.readPool.query(query, params);
  }

  async executeWrite(query: string, params?: any[]): Promise<any> {
    // Use primary database for write operations
    return this.writePool.query(query, params);
  }

  private delay(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}

// Query optimization patterns
class OptimizedRepository {
  // Batch operations to reduce database round trips
  async batchCreate(items: CreateItemDto[]): Promise<Item[]> {
    const query = `
      INSERT INTO items (name, description, price, category_id)
      VALUES ${items.map((_, i) => `($${i * 4 + 1}, $${i * 4 + 2}, $${i * 4 + 3}, $${i * 4 + 4})`).join(', ')}
      RETURNING *
    `;
    
    const params = items.flatMap(item => [item.name, item.description, item.price, item.categoryId]);
    const result = await db.query(query, params);
    return result.rows;
  }

  // Pagination with cursor-based approach
  async findWithCursor(cursor?: string, limit = 20): Promise<PaginatedResult<Item>> {
    let query = `
      SELECT * FROM items 
      WHERE deleted_at IS NULL
    `;
    
    const params: any[] = [];
    
    if (cursor) {
      query += ` AND created_at < $1`;
      params.push(new Date(cursor));
    }
    
    query += ` ORDER BY created_at DESC LIMIT $${params.length + 1}`;
    params.push(limit + 1); // Fetch one extra to determine if there's a next page
    
    const result = await db.query(query, params);
    const items = result.rows;
    
    const hasNextPage = items.length > limit;
    if (hasNextPage) {
      items.pop(); // Remove the extra item
    }
    
    const nextCursor = hasNextPage ? items[items.length - 1].created_at.toISOString() : null;
    
    return {
      items,
      hasNextPage,
      nextCursor,
    };
  }

  // Efficient search with full-text search
  async searchItems(searchTerm: string, filters: SearchFilters): Promise<Item[]> {
    const query = `
      SELECT *, ts_rank(search_vector, plainto_tsquery($1)) AS rank
      FROM items 
      WHERE search_vector @@ plainto_tsquery($1)
      AND ($2::int IS NULL OR category_id = $2)
      AND ($3::decimal IS NULL OR price >= $3)
      AND ($4::decimal IS NULL OR price <= $4)
      ORDER BY rank DESC, created_at DESC
      LIMIT $5 OFFSET $6
    `;
    
    const params = [
      searchTerm,
      filters.categoryId,
      filters.minPrice,
      filters.maxPrice,
      filters.limit || 20,
      filters.offset || 0,
    ];
    
    const result = await db.query(query, params);
    return result.rows;
  }
}
```

---

## 🗄️ Caching Strategies

### 1. Multi-Level Caching

```typescript
import Redis from 'ioredis';
import NodeCache from 'node-cache';

// Multi-level cache implementation
class CacheManager {
  private l1Cache: NodeCache; // In-memory cache
  private l2Cache: Redis; // Redis cache
  private l3Cache: any; // Database cache

  constructor() {
    // L1: In-memory cache (fastest, smallest)
    this.l1Cache = new NodeCache({
      stdTTL: 300, // 5 minutes default TTL
      checkperiod: 60, // Check for expired keys every minute
      maxKeys: 1000, // Limit memory usage
    });

    // L2: Redis cache (fast, larger capacity)
    this.l2Cache = new Redis({
      host: process.env.REDIS_HOST,
      port: parseInt(process.env.REDIS_PORT!),
      password: process.env.REDIS_PASSWORD,
      db: 0,
      retryDelayOnFailover: 100,
      maxRetriesPerRequest: 3,
      lazyConnect: true,
    });

    // L3: Database cache would be configured here
  }

  async get<T>(key: string): Promise<T | null> {
    // Try L1 cache first
    const l1Result = this.l1Cache.get<T>(key);
    if (l1Result !== undefined) {
      return l1Result;
    }

    // Try L2 cache
    try {
      const l2Result = await this.l2Cache.get(key);
      if (l2Result) {
        const parsed = JSON.parse(l2Result) as T;
        // Populate L1 cache
        this.l1Cache.set(key, parsed, 300);
        return parsed;
      }
    } catch (error) {
      console.error('L2 cache error:', error);
    }

    return null;
  }

  async set<T>(key: string, value: T, ttl = 3600): Promise<void> {
    // Set in all cache levels
    this.l1Cache.set(key, value, Math.min(ttl, 300)); // L1 max 5 minutes
    
    try {
      await this.l2Cache.setex(key, ttl, JSON.stringify(value));
    } catch (error) {
      console.error('L2 cache set error:', error);
    }
  }

  async delete(key: string): Promise<void> {
    this.l1Cache.del(key);
    
    try {
      await this.l2Cache.del(key);
    } catch (error) {
      console.error('L2 cache delete error:', error);
    }
  }

  // Cache-aside pattern
  async getOrSet<T>(
    key: string,
    fetcher: () => Promise<T>,
    ttl = 3600
  ): Promise<T> {
    const cached = await this.get<T>(key);
    if (cached !== null) {
      return cached;
    }

    const value = await fetcher();
    await this.set(key, value, ttl);
    return value;
  }

  // Bulk operations for efficiency
  async mget<T>(keys: string[]): Promise<(T | null)[]> {
    const results: (T | null)[] = [];
    const missingKeys: string[] = [];
    const missingIndices: number[] = [];

    // Check L1 cache for all keys
    keys.forEach((key, index) => {
      const cached = this.l1Cache.get<T>(key);
      if (cached !== undefined) {
        results[index] = cached;
      } else {
        results[index] = null;
        missingKeys.push(key);
        missingIndices.push(index);
      }
    });

    // Fetch missing keys from L2 cache
    if (missingKeys.length > 0) {
      try {
        const l2Results = await this.l2Cache.mget(...missingKeys);
        l2Results.forEach((result, i) => {
          if (result) {
            const parsed = JSON.parse(result) as T;
            const originalIndex = missingIndices[i];
            results[originalIndex] = parsed;
            // Populate L1 cache
            this.l1Cache.set(missingKeys[i], parsed, 300);
          }
        });
      } catch (error) {
        console.error('L2 cache mget error:', error);
      }
    }

    return results;
  }
}

// Application-level caching patterns
class CachedUserService {
  constructor(
    private userRepository: UserRepository,
    private cacheManager: CacheManager
  ) {}

  async getUserById(id: string): Promise<User | null> {
    const cacheKey = `user:${id}`;
    
    return this.cacheManager.getOrSet(
      cacheKey,
      () => this.userRepository.findById(id),
      3600 // 1 hour TTL
    );
  }

  async getUsersByIds(ids: string[]): Promise<(User | null)[]> {
    const cacheKeys = ids.map(id => `user:${id}`);
    const cached = await this.cacheManager.mget<User>(cacheKeys);
    
    const missingIds: string[] = [];
    const missingIndices: number[] = [];
    
    cached.forEach((user, index) => {
      if (user === null) {
        missingIds.push(ids[index]);
        missingIndices.push(index);
      }
    });

    // Fetch missing users from database
    if (missingIds.length > 0) {
      const missingUsers = await this.userRepository.findByIds(missingIds);
      
      // Update cache and results
      for (let i = 0; i < missingUsers.length; i++) {
        const user = missingUsers[i];
        const originalIndex = missingIndices[i];
        
        if (user) {
          cached[originalIndex] = user;
          await this.cacheManager.set(`user:${user.id}`, user, 3600);
        }
      }
    }

    return cached;
  }

  async updateUser(id: string, data: UpdateUserDto): Promise<User> {
    const user = await this.userRepository.update(id, data);
    
    // Update cache
    const cacheKey = `user:${id}`;
    await this.cacheManager.set(cacheKey, user, 3600);
    
    // Invalidate related caches
    await this.invalidateRelatedCaches(id);
    
    return user;
  }

  private async invalidateRelatedCaches(userId: string): Promise<void> {
    // Invalidate caches that depend on this user
    await Promise.all([
      this.cacheManager.delete(`user:${userId}`),
      this.cacheManager.delete(`user-profile:${userId}`),
      this.cacheManager.delete(`user-permissions:${userId}`),
    ]);
  }
}
```

### 2. HTTP Caching

```typescript
// HTTP caching middleware
class HTTPCacheMiddleware {
  // ETag-based caching
  static etag(req: Request, res: Response, next: NextFunction): void {
    const originalSend = res.send;
    
    res.send = function(data: any) {
      if (res.statusCode === 200 && data) {
        const etag = crypto
          .createHash('md5')
          .update(JSON.stringify(data))
          .digest('hex');
        
        res.set('ETag', `"${etag}"`);
        
        // Check if client has cached version
        const clientETag = req.headers['if-none-match'];
        if (clientETag === `"${etag}"`) {
          return res.status(304).end();
        }
      }
      
      return originalSend.call(this, data);
    };
    
    next();
  }

  // Cache-Control headers
  static cacheControl(maxAge: number, options: CacheOptions = {}) {
    return (req: Request, res: Response, next: NextFunction) => {
      const {
        public: isPublic = true,
        mustRevalidate = false,
        noCache = false,
        noStore = false,
      } = options;

      if (noStore) {
        res.set('Cache-Control', 'no-store');
      } else if (noCache) {
        res.set('Cache-Control', 'no-cache');
      } else {
        const directives = [
          isPublic ? 'public' : 'private',
          `max-age=${maxAge}`,
        ];

        if (mustRevalidate) {
          directives.push('must-revalidate');
        }

        res.set('Cache-Control', directives.join(', '));
      }

      next();
    };
  }

  // Conditional requests with Last-Modified
  static lastModified(getLastModified: (req: Request) => Date | Promise<Date>) {
    return async (req: Request, res: Response, next: NextFunction) => {
      try {
        const lastModified = await getLastModified(req);
        res.set('Last-Modified', lastModified.toUTCString());

        const ifModifiedSince = req.headers['if-modified-since'];
        if (ifModifiedSince) {
          const clientDate = new Date(ifModifiedSince);
          if (lastModified <= clientDate) {
            return res.status(304).end();
          }
        }

        next();
      } catch (error) {
        next(error);
      }
    };
  }
}

// Usage in routes
app.get('/api/articles',
  HTTPCacheMiddleware.cacheControl(300), // 5 minutes
  HTTPCacheMiddleware.etag,
  articleController.getArticles
);

app.get('/api/articles/:id',
  HTTPCacheMiddleware.lastModified(async (req) => {
    const article = await articleService.getById(req.params.id);
    return article.updatedAt;
  }),
  articleController.getArticle
);
```

---

## 🔄 Load Balancing & Clustering

### 1. Application-Level Load Balancing

```typescript
// Round-robin load balancer
class LoadBalancer {
  private servers: string[];
  private currentIndex = 0;
  private healthChecks = new Map<string, boolean>();

  constructor(servers: string[]) {
    this.servers = servers;
    this.startHealthChecks();
  }

  getNextServer(): string {
    const healthyServers = this.servers.filter(server => 
      this.healthChecks.get(server) !== false
    );

    if (healthyServers.length === 0) {
      throw new Error('No healthy servers available');
    }

    const server = healthyServers[this.currentIndex % healthyServers.length];
    this.currentIndex++;
    
    return server;
  }

  private startHealthChecks(): void {
    setInterval(async () => {
      for (const server of this.servers) {
        try {
          const response = await fetch(`${server}/health`);
          this.healthChecks.set(server, response.ok);
        } catch (error) {
          this.healthChecks.set(server, false);
        }
      }
    }, 30000); // Check every 30 seconds
  }
}

// Weighted round-robin
class WeightedLoadBalancer {
  private servers: Array<{ url: string; weight: number; currentWeight: number }>;

  constructor(servers: Array<{ url: string; weight: number }>) {
    this.servers = servers.map(server => ({
      ...server,
      currentWeight: 0,
    }));
  }

  getNextServer(): string {
    let selected = this.servers[0];
    let totalWeight = 0;

    for (const server of this.servers) {
      totalWeight += server.weight;
      server.currentWeight += server.weight;

      if (server.currentWeight > selected.currentWeight) {
        selected = server;
      }
    }

    selected.currentWeight -= totalWeight;
    return selected.url;
  }
}

// Circuit breaker pattern
class CircuitBreaker {
  private state: 'CLOSED' | 'OPEN' | 'HALF_OPEN' = 'CLOSED';
  private failureCount = 0;
  private lastFailureTime = 0;
  private successCount = 0;

  constructor(
    private failureThreshold = 5,
    private timeout = 60000, // 1 minute
    private monitoringPeriod = 10000 // 10 seconds
  ) {}

  async execute<T>(operation: () => Promise<T>): Promise<T> {
    if (this.state === 'OPEN') {
      if (Date.now() - this.lastFailureTime > this.timeout) {
        this.state = 'HALF_OPEN';
        this.successCount = 0;
      } else {
        throw new Error('Circuit breaker is OPEN');
      }
    }

    try {
      const result = await operation();
      this.onSuccess();
      return result;
    } catch (error) {
      this.onFailure();
      throw error;
    }
  }

  private onSuccess(): void {
    this.failureCount = 0;
    
    if (this.state === 'HALF_OPEN') {
      this.successCount++;
      if (this.successCount >= 3) {
        this.state = 'CLOSED';
      }
    }
  }

  private onFailure(): void {
    this.failureCount++;
    this.lastFailureTime = Date.now();

    if (this.failureCount >= this.failureThreshold) {
      this.state = 'OPEN';
    }
  }
}
```

### 2. Session Affinity & Sticky Sessions

```typescript
// Session affinity with consistent hashing
class ConsistentHashingRouter {
  private servers: string[];
  private virtualNodes = 150; // Virtual nodes per server
  private ring = new Map<number, string>();

  constructor(servers: string[]) {
    this.servers = servers;
    this.buildRing();
  }

  private buildRing(): void {
    this.ring.clear();
    
    for (const server of this.servers) {
      for (let i = 0; i < this.virtualNodes; i++) {
        const hash = this.hash(`${server}:${i}`);
        this.ring.set(hash, server);
      }
    }
  }

  getServer(key: string): string {
    const hash = this.hash(key);
    const sortedKeys = Array.from(this.ring.keys()).sort((a, b) => a - b);
    
    // Find the first server with hash >= key hash
    for (const serverHash of sortedKeys) {
      if (serverHash >= hash) {
        return this.ring.get(serverHash)!;
      }
    }
    
    // Wrap around to the first server
    return this.ring.get(sortedKeys[0])!;
  }

  private hash(input: string): number {
    let hash = 0;
    for (let i = 0; i < input.length; i++) {
      const char = input.charCodeAt(i);
      hash = ((hash << 5) - hash) + char;
      hash = hash & hash; // Convert to 32-bit integer
    }
    return Math.abs(hash);
  }

  addServer(server: string): void {
    this.servers.push(server);
    this.buildRing();
  }

  removeServer(server: string): void {
    this.servers = this.servers.filter(s => s !== server);
    this.buildRing();
  }
}

// Sticky session middleware
const stickySessionMiddleware = (router: ConsistentHashingRouter) => {
  return (req: Request, res: Response, next: NextFunction) => {
    const sessionId = req.sessionID || req.cookies.sessionId;
    
    if (sessionId) {
      const targetServer = router.getServer(sessionId);
      req.headers['x-target-server'] = targetServer;
    }
    
    next();
  };
};
```

---

## 📈 Auto-Scaling Strategies

### 1. Horizontal Pod Autoscaling (HPA)

```yaml
# kubernetes-hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: express-api-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: express-api
  minReplicas: 3
  maxReplicas: 20
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
      - type: Percent
        value: 100
        periodSeconds: 15
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 10
        periodSeconds: 60
```

### 2. Custom Metrics Scaling

```typescript
// Custom metrics for scaling decisions
class MetricsCollector {
  private metrics = new Map<string, number>();

  collectMetrics(): void {
    setInterval(() => {
      // CPU usage
      const cpuUsage = process.cpuUsage();
      this.metrics.set('cpu.user', cpuUsage.user);
      this.metrics.set('cpu.system', cpuUsage.system);

      // Memory usage
      const memUsage = process.memoryUsage();
      this.metrics.set('memory.heapUsed', memUsage.heapUsed);
      this.metrics.set('memory.rss', memUsage.rss);

      // Event loop lag
      const start = process.hrtime.bigint();
      setImmediate(() => {
        const lag = Number(process.hrtime.bigint() - start) / 1000000; // Convert to ms
        this.metrics.set('eventLoop.lag', lag);
      });

      // Active connections
      this.metrics.set('connections.active', this.getActiveConnections());

      // Request queue size
      this.metrics.set('queue.size', this.getQueueSize());

      // Send metrics to monitoring system
      this.sendMetrics();
    }, 10000); // Collect every 10 seconds
  }

  private getActiveConnections(): number {
    // Implementation depends on your server setup
    return 0;
  }

  private getQueueSize(): number {
    // Implementation depends on your queue system
    return 0;
  }

  private sendMetrics(): void {
    // Send to Prometheus, DataDog, etc.
    const metricsData = Object.fromEntries(this.metrics);
    console.log('Metrics:', metricsData);
  }
}

// Auto-scaling trigger based on custom metrics
class AutoScaler {
  private currentInstances = 1;
  private readonly minInstances = 2;
  private readonly maxInstances = 10;
  private readonly scaleUpThreshold = 0.8;
  private readonly scaleDownThreshold = 0.3;

  async evaluateScaling(): Promise<void> {
    const metrics = await this.getMetrics();
    
    const cpuUtilization = metrics.cpu / 100;
    const memoryUtilization = metrics.memory / 100;
    const eventLoopLag = metrics.eventLoopLag;
    
    // Scale up conditions
    if (
      cpuUtilization > this.scaleUpThreshold ||
      memoryUtilization > this.scaleUpThreshold ||
      eventLoopLag > 50 // 50ms lag threshold
    ) {
      await this.scaleUp();
    }
    
    // Scale down conditions
    else if (
      cpuUtilization < this.scaleDownThreshold &&
      memoryUtilization < this.scaleDownThreshold &&
      eventLoopLag < 10 // Low lag
    ) {
      await this.scaleDown();
    }
  }

  private async scaleUp(): Promise<void> {
    if (this.currentInstances < this.maxInstances) {
      this.currentInstances++;
      await this.deployInstance();
      console.log(`Scaled up to ${this.currentInstances} instances`);
    }
  }

  private async scaleDown(): Promise<void> {
    if (this.currentInstances > this.minInstances) {
      await this.removeInstance();
      this.currentInstances--;
      console.log(`Scaled down to ${this.currentInstances} instances`);
    }
  }

  private async deployInstance(): Promise<void> {
    // Implementation depends on your infrastructure (Docker, Kubernetes, etc.)
  }

  private async removeInstance(): Promise<void> {
    // Implementation depends on your infrastructure
  }

  private async getMetrics(): Promise<any> {
    // Get metrics from monitoring system
    return {
      cpu: 75,
      memory: 60,
      eventLoopLag: 25,
    };
  }
}
```

---

## 🔗 Navigation

← [Authentication Strategies](./authentication-strategies.md) | [Development Tools & Libraries](./development-tools-libraries.md) →

---

*Scalability analysis: July 2025 | Strategies covered: Performance optimization, caching, clustering, auto-scaling*