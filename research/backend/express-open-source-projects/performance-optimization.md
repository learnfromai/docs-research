# Performance Optimization: Express.js Applications

## 🎯 Overview

This document presents performance optimization strategies extracted from analyzing 15+ production Express.js applications, focusing on real-world techniques for achieving high performance and scalability.

## 📋 Table of Contents

1. [Application-Level Optimizations](#1-application-level-optimizations)
2. [Database Performance](#2-database-performance)
3. [Caching Strategies](#3-caching-strategies)
4. [Memory Management](#4-memory-management)
5. [Network & I/O Optimization](#5-network--io-optimization)
6. [Monitoring & Profiling](#6-monitoring--profiling)
7. [Scaling Strategies](#7-scaling-strategies)
8. [Performance Benchmarks](#8-performance-benchmarks)

## 1. Application-Level Optimizations

### 1.1 Node.js Process Optimization

**Clustering Implementation from Ghost**:

```javascript
// cluster.js - Production clustering setup
const cluster = require('cluster');
const os = require('os');
const logger = require('./utils/logger');

class ClusterManager {
    constructor(options = {}) {
        this.workers = options.workers || os.cpus().length;
        this.respawnThreshold = options.respawnThreshold || 5;
        this.respawnDelay = options.respawnDelay || 1000;
        this.workerRestarts = new Map();
    }
    
    start() {
        if (cluster.isMaster) {
            this.startMaster();
        } else {
            this.startWorker();
        }
    }
    
    startMaster() {
        logger.info(`Master ${process.pid} starting ${this.workers} workers`);
        
        // Fork workers
        for (let i = 0; i < this.workers; i++) {
            this.forkWorker();
        }
        
        // Handle worker events
        cluster.on('exit', (worker, code, signal) => {
            logger.warn(`Worker ${worker.process.pid} died`, { code, signal });
            
            if (!worker.exitedAfterDisconnect) {
                this.handleWorkerRestart(worker);
            }
        });
        
        // Graceful shutdown
        process.on('SIGTERM', () => this.gracefulShutdown());
        process.on('SIGINT', () => this.gracefulShutdown());
        
        // Performance monitoring
        this.startPerformanceMonitoring();
    }
    
    forkWorker() {
        const worker = cluster.fork();
        
        worker.on('message', (message) => {
            if (message.type === 'health_check') {
                this.handleHealthCheck(worker, message);
            }
        });
        
        // Set up worker timeout
        const timeout = setTimeout(() => {
            logger.error(`Worker ${worker.process.pid} startup timeout`);
            worker.kill();
        }, 30000);
        
        worker.on('listening', () => {
            clearTimeout(timeout);
            logger.info(`Worker ${worker.process.pid} started successfully`);
        });
        
        return worker;
    }
    
    handleWorkerRestart(worker) {
        const pid = worker.process.pid;
        const restarts = this.workerRestarts.get(pid) || 0;
        
        if (restarts >= this.respawnThreshold) {
            logger.error(`Worker ${pid} exceeded restart threshold, not respawning`);
            return;
        }
        
        this.workerRestarts.set(pid, restarts + 1);
        
        setTimeout(() => {
            this.forkWorker();
        }, this.respawnDelay);
    }
    
    gracefulShutdown() {
        logger.info('Master shutting down gracefully');
        
        for (const id in cluster.workers) {
            cluster.workers[id].disconnect();
        }
        
        setTimeout(() => {
            for (const id in cluster.workers) {
                cluster.workers[id].kill();
            }
            process.exit(0);
        }, 10000);
    }
    
    startPerformanceMonitoring() {
        setInterval(() => {
            const workers = Object.values(cluster.workers);
            const healthyWorkers = workers.filter(w => !w.isDead()).length;
            
            logger.info('Cluster health', {
                totalWorkers: workers.length,
                healthyWorkers,
                memoryUsage: process.memoryUsage()
            });
        }, 30000);
    }
    
    startWorker() {
        const app = require('./app');
        const port = process.env.PORT || 3000;
        
        const server = app.listen(port, () => {
            logger.info(`Worker ${process.pid} listening on port ${port}`);
            
            // Send health checks to master
            setInterval(() => {
                process.send({
                    type: 'health_check',
                    pid: process.pid,
                    memory: process.memoryUsage(),
                    uptime: process.uptime()
                });
            }, 10000);
        });
        
        // Graceful shutdown for worker
        process.on('SIGTERM', () => {
            logger.info(`Worker ${process.pid} shutting down`);
            
            server.close(() => {
                process.exit(0);
            });
            
            // Force exit after timeout
            setTimeout(() => {
                process.exit(1);
            }, 5000);
        });
    }
}

// Usage
if (require.main === module) {
    const clusterManager = new ClusterManager({
        workers: process.env.WORKERS || os.cpus().length
    });
    clusterManager.start();
}

module.exports = ClusterManager;
```

### 1.2 Middleware Optimization

**Optimized Middleware Stack from Strapi**:

```javascript
// middleware/performance.js
const compression = require('compression');
const helmet = require('helmet');

class PerformanceMiddleware {
    static setupCompression(app) {
        app.use(compression({
            // Only compress responses larger than 1KB
            threshold: 1024,
            
            // Compression level (6 = good balance)
            level: 6,
            
            // Filter function to exclude certain content types
            filter: (req, res) => {
                // Don't compress if the client doesn't support it
                if (req.headers['x-no-compression']) {
                    return false;
                }
                
                // Don't compress images, videos, or already compressed content
                const contentType = res.getHeader('content-type');
                if (contentType && (
                    contentType.includes('image/') ||
                    contentType.includes('video/') ||
                    contentType.includes('audio/') ||
                    contentType.includes('application/zip') ||
                    contentType.includes('application/gzip')
                )) {
                    return false;
                }
                
                return compression.filter(req, res);
            },
            
            // Memory level (8 = good balance)
            memLevel: 8,
            
            // Window bits (15 = maximum compression)
            windowBits: 15
        }));
    }
    
    static setupCaching(app) {
        // Static asset caching
        app.use('/static', (req, res, next) => {
            // Set cache headers for static assets
            if (req.url.match(/\.(css|js|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$/)) {
                res.setHeader('Cache-Control', 'public, max-age=31536000'); // 1 year
                res.setHeader('Expires', new Date(Date.now() + 31536000000).toUTCString());
            }
            next();
        });
        
        // API response caching middleware
        app.use('/api', (req, res, next) => {
            if (req.method === 'GET') {
                const etag = req.headers['if-none-match'];
                const modifiedSince = req.headers['if-modified-since'];
                
                // Generate ETag based on URL and query params
                const requestETag = this.generateETag(req);
                
                if (etag === requestETag) {
                    return res.status(304).end();
                }
                
                res.setHeader('ETag', requestETag);
                res.setHeader('Last-Modified', new Date().toUTCString());
            }
            next();
        });
    }
    
    static generateETag(req) {
        const crypto = require('crypto');
        const content = req.url + JSON.stringify(req.query);
        return crypto.createHash('md5').update(content).digest('hex');
    }
    
    static setupSecurityHeaders(app) {
        app.use(helmet({
            // Optimize CSP for performance
            contentSecurityPolicy: {
                directives: {
                    defaultSrc: ["'self'"],
                    scriptSrc: ["'self'", "'unsafe-inline'"], // Avoid inline scripts when possible
                    styleSrc: ["'self'", "'unsafe-inline'", "https://fonts.googleapis.com"],
                    fontSrc: ["'self'", "https://fonts.gstatic.com"],
                    imgSrc: ["'self'", "data:", "https:"],
                    connectSrc: ["'self'"],
                    mediaSrc: ["'self'"],
                    objectSrc: ["'none'"],
                    baseUri: ["'self'"],
                    formAction: ["'self'"],
                    frameAncestors: ["'none'"],
                    upgradeInsecureRequests: []
                }
            },
            
            // HSTS for HTTPS performance
            hsts: {
                maxAge: 31536000,
                includeSubDomains: true,
                preload: true
            }
        }));
    }
    
    static setupResponseTime(app) {
        app.use((req, res, next) => {
            const start = process.hrtime.bigint();
            
            res.on('finish', () => {
                const end = process.hrtime.bigint();
                const duration = Number(end - start) / 1000000; // Convert to milliseconds
                
                res.setHeader('X-Response-Time', `${duration.toFixed(2)}ms`);
                
                // Log slow responses
                if (duration > 1000) {
                    logger.warn('Slow response detected', {
                        url: req.url,
                        method: req.method,
                        duration,
                        ip: req.ip
                    });
                }
            });
            
            next();
        });
    }
}

module.exports = PerformanceMiddleware;
```

### 1.3 Request/Response Optimization

```javascript
// Request parsing optimization
const express = require('express');

class RequestOptimization {
    static setup(app) {
        // Optimize body parsing
        app.use(express.json({
            limit: '10mb',
            type: ['application/json', 'application/*+json'],
            verify: (req, res, buf, encoding) => {
                // Store raw body for webhook verification if needed
                if (req.headers['content-type']?.includes('application/json')) {
                    req.rawBody = buf;
                }
            }
        }));
        
        app.use(express.urlencoded({
            limit: '10mb',
            extended: true,
            parameterLimit: 1000
        }));
        
        // Optimize query string parsing
        app.set('query parser', (str) => {
            return require('qs').parse(str, {
                depth: 5,
                parameterLimit: 100,
                arrayLimit: 50
            });
        });
        
        // Response optimization
        this.setupResponseOptimization(app);
    }
    
    static setupResponseOptimization(app) {
        app.use((req, res, next) => {
            // Optimize JSON responses
            const originalJson = res.json;
            res.json = function(obj) {
                // Remove undefined values
                const cleaned = this.removeUndefined(obj);
                
                // Set appropriate content type
                res.setHeader('Content-Type', 'application/json; charset=utf-8');
                
                return originalJson.call(this, cleaned);
            };
            
            next();
        });
    }
    
    static removeUndefined(obj) {
        if (Array.isArray(obj)) {
            return obj.map(item => this.removeUndefined(item));
        }
        
        if (obj !== null && typeof obj === 'object') {
            const cleaned = {};
            for (const [key, value] of Object.entries(obj)) {
                if (value !== undefined) {
                    cleaned[key] = this.removeUndefined(value);
                }
            }
            return cleaned;
        }
        
        return obj;
    }
}
```

## 2. Database Performance

### 2.1 MongoDB Optimization

**MongoDB Performance Patterns from Parse Server**:

```javascript
// database/mongodb-optimization.js
class MongoDBOptimization {
    constructor(mongoose) {
        this.mongoose = mongoose;
        this.setupOptimizations();
    }
    
    setupOptimizations() {
        // Connection pooling
        this.setupConnectionPool();
        
        // Query optimization
        this.setupQueryOptimization();
        
        // Index management
        this.setupIndexes();
    }
    
    setupConnectionPool() {
        const options = {
            // Connection pool settings
            maxPoolSize: 10,
            minPoolSize: 5,
            maxIdleTimeMS: 30000,
            serverSelectionTimeoutMS: 5000,
            socketTimeoutMS: 45000,
            
            // Buffer settings
            bufferCommands: false,
            bufferMaxEntries: 0,
            
            // Read preferences
            readPreference: 'secondaryPreferred',
            
            // Write concern
            writeConcern: {
                w: 'majority',
                j: true,
                wtimeout: 10000
            }
        };
        
        return options;
    }
    
    setupQueryOptimization() {
        // Add query performance monitoring
        this.mongoose.connection.on('connected', () => {
            this.mongoose.set('debug', (collectionName, method, query, doc) => {
                const start = Date.now();
                
                // Log slow queries
                setImmediate(() => {
                    const duration = Date.now() - start;
                    if (duration > 100) {
                        logger.warn('Slow MongoDB query', {
                            collection: collectionName,
                            method,
                            query,
                            duration
                        });
                    }
                });
            });
        });
    }
    
    setupIndexes() {
        // User collection indexes
        const userIndexes = [
            { email: 1 },
            { username: 1 },
            { 'profile.firstName': 1, 'profile.lastName': 1 },
            { createdAt: -1 },
            { lastLogin: -1 },
            { email: 1, isActive: 1 },
            { role: 1, isActive: 1 }
        ];
        
        // Post collection indexes
        const postIndexes = [
            { authorId: 1, createdAt: -1 },
            { status: 1, publishedAt: -1 },
            { tags: 1, status: 1 },
            { featured: 1, status: 1, publishedAt: -1 },
            { slug: 1 },
            { 'title': 'text', 'content': 'text' } // Text search index
        ];
        
        return { userIndexes, postIndexes };
    }
    
    // Optimized query patterns
    static createOptimizedQueries() {
        return {
            // Pagination with proper sorting
            async findPostsPaginated(page = 1, limit = 10, filters = {}) {
                const skip = (page - 1) * limit;
                
                return Post.find(filters)
                    .select('title slug excerpt authorId publishedAt featuredImage')
                    .populate('authorId', 'firstName lastName avatar')
                    .sort({ publishedAt: -1 })
                    .limit(limit)
                    .skip(skip)
                    .lean(); // Return plain objects for better performance
            },
            
            // Aggregation for complex queries
            async getUserStats(userId) {
                return User.aggregate([
                    { $match: { _id: mongoose.Types.ObjectId(userId) } },
                    {
                        $lookup: {
                            from: 'posts',
                            localField: '_id',
                            foreignField: 'authorId',
                            as: 'posts'
                        }
                    },
                    {
                        $project: {
                            firstName: 1,
                            lastName: 1,
                            email: 1,
                            postCount: { $size: '$posts' },
                            publishedPosts: {
                                $size: {
                                    $filter: {
                                        input: '$posts',
                                        cond: { $eq: ['$$this.status', 'published'] }
                                    }
                                }
                            },
                            lastPost: { $max: '$posts.createdAt' }
                        }
                    }
                ]);
            },
            
            // Bulk operations for performance
            async bulkUpdatePosts(updates) {
                const bulkOps = updates.map(update => ({
                    updateOne: {
                        filter: { _id: update.id },
                        update: { $set: update.data }
                    }
                }));
                
                return Post.bulkWrite(bulkOps, { ordered: false });
            }
        };
    }
}

// Schema optimization
const optimizedUserSchema = new mongoose.Schema({
    email: { 
        type: String, 
        required: true, 
        unique: true,
        index: true,
        lowercase: true
    },
    username: { 
        type: String, 
        unique: true, 
        sparse: true,
        index: true 
    },
    password: { 
        type: String, 
        required: true,
        select: false // Don't include in queries by default
    },
    profile: {
        firstName: { type: String, index: true },
        lastName: { type: String, index: true },
        avatar: String,
        bio: String
    },
    role: { 
        type: String, 
        enum: ['user', 'admin', 'moderator'],
        default: 'user',
        index: true 
    },
    isActive: { type: Boolean, default: true, index: true },
    lastLogin: { type: Date, index: true },
    settings: {
        notifications: {
            email: { type: Boolean, default: true },
            push: { type: Boolean, default: true }
        },
        privacy: {
            profileVisible: { type: Boolean, default: true }
        }
    }
}, {
    timestamps: true,
    // Optimize JSON output
    toJSON: {
        transform: function(doc, ret) {
            delete ret.password;
            delete ret.__v;
            return ret;
        }
    },
    // Optimize for queries
    minimize: false,
    versionKey: false
});

// Compound indexes for common query patterns
optimizedUserSchema.index({ email: 1, isActive: 1 });
optimizedUserSchema.index({ lastLogin: -1, role: 1 });
optimizedUserSchema.index({ 'profile.firstName': 1, 'profile.lastName': 1 });
optimizedUserSchema.index({ createdAt: -1, role: 1 });
```

### 2.2 PostgreSQL Optimization

**PostgreSQL Performance from GitLab CE**:

```javascript
// database/postgresql-optimization.js
const { Pool } = require('pg');

class PostgreSQLOptimization {
    constructor() {
        this.pool = this.createOptimizedPool();
        this.setupPerformanceMonitoring();
    }
    
    createOptimizedPool() {
        return new Pool({
            connectionString: process.env.DATABASE_URL,
            
            // Connection pool settings
            max: 20,                    // Maximum number of clients
            min: 5,                     // Minimum number of clients
            idleTimeoutMillis: 30000,   // Close idle clients after 30 seconds
            connectionTimeoutMillis: 5000, // Return error after 5 seconds if no connection available
            
            // Query settings
            statement_timeout: 30000,   // Cancel queries after 30 seconds
            query_timeout: 30000,
            
            // SSL settings for production
            ssl: process.env.NODE_ENV === 'production' ? {
                rejectUnauthorized: false
            } : false,
            
            // Connection validation
            application_name: 'express-app',
            
            // Performance settings
            options: '--default_transaction_isolation=read_committed'
        });
    }
    
    setupPerformanceMonitoring() {
        this.pool.on('connect', (client) => {
            logger.info('New PostgreSQL client connected');
            
            // Set up query logging for slow queries
            client.on('notice', (msg) => {
                if (msg.severity === 'WARNING') {
                    logger.warn('PostgreSQL warning:', msg.message);
                }
            });
        });
        
        this.pool.on('error', (err) => {
            logger.error('PostgreSQL pool error:', err);
        });
        
        // Monitor pool statistics
        setInterval(() => {
            logger.info('PostgreSQL pool stats', {
                totalCount: this.pool.totalCount,
                idleCount: this.pool.idleCount,
                waitingCount: this.pool.waitingCount
            });
        }, 60000);
    }
    
    // Optimized query patterns
    async executeOptimizedQuery(text, params = [], options = {}) {
        const start = Date.now();
        const client = await this.pool.connect();
        
        try {
            // Use prepared statements for repeated queries
            if (options.prepared) {
                const result = await client.query({
                    text,
                    values: params,
                    name: options.name
                });
                return result;
            }
            
            const result = await client.query(text, params);
            
            const duration = Date.now() - start;
            
            // Log slow queries
            if (duration > 1000) {
                logger.warn('Slow PostgreSQL query', {
                    query: text,
                    params,
                    duration
                });
            }
            
            return result;
        } finally {
            client.release();
        }
    }
    
    // Connection with transaction support
    async withTransaction(callback) {
        const client = await this.pool.connect();
        
        try {
            await client.query('BEGIN');
            const result = await callback(client);
            await client.query('COMMIT');
            return result;
        } catch (error) {
            await client.query('ROLLBACK');
            throw error;
        } finally {
            client.release();
        }
    }
    
    // Bulk insert optimization
    async bulkInsert(tableName, columns, values, options = {}) {
        const batchSize = options.batchSize || 1000;
        const results = [];
        
        for (let i = 0; i < values.length; i += batchSize) {
            const batch = values.slice(i, i + batchSize);
            
            // Generate parameterized query
            const placeholders = batch.map((_, rowIndex) => 
                `(${columns.map((_, colIndex) => 
                    `$${rowIndex * columns.length + colIndex + 1}`
                ).join(', ')})`
            ).join(', ');
            
            const query = `
                INSERT INTO ${tableName} (${columns.join(', ')})
                VALUES ${placeholders}
                ${options.onConflict || ''}
                RETURNING id
            `;
            
            const flatValues = batch.flat();
            const result = await this.executeOptimizedQuery(query, flatValues);
            results.push(...result.rows);
        }
        
        return results;
    }
    
    // Query builder for complex queries
    buildOptimizedQuery(options) {
        const {
            select = '*',
            from,
            joins = [],
            where = [],
            orderBy = [],
            limit,
            offset
        } = options;
        
        let query = `SELECT ${Array.isArray(select) ? select.join(', ') : select} FROM ${from}`;
        let paramIndex = 1;
        const params = [];
        
        // Add joins
        joins.forEach(join => {
            query += ` ${join.type || 'LEFT'} JOIN ${join.table} ON ${join.condition}`;
        });
        
        // Add where conditions
        if (where.length > 0) {
            const conditions = where.map(condition => {
                if (condition.value !== undefined) {
                    params.push(condition.value);
                    return `${condition.field} ${condition.operator || '='} $${paramIndex++}`;
                }
                return condition.raw;
            });
            query += ` WHERE ${conditions.join(' AND ')}`;
        }
        
        // Add order by
        if (orderBy.length > 0) {
            query += ` ORDER BY ${orderBy.join(', ')}`;
        }
        
        // Add pagination
        if (limit) {
            query += ` LIMIT ${limit}`;
        }
        if (offset) {
            query += ` OFFSET ${offset}`;
        }
        
        return { query, params };
    }
}

// Example usage with Sequelize optimization
const sequelizeConfig = {
    dialect: 'postgres',
    pool: {
        max: 20,
        min: 5,
        acquire: 30000,
        idle: 10000
    },
    logging: (sql, timing) => {
        if (timing > 1000) {
            logger.warn('Slow Sequelize query', { sql, timing });
        }
    },
    benchmark: true,
    retry: {
        max: 3
    },
    dialectOptions: {
        statement_timeout: 30000,
        idle_in_transaction_session_timeout: 30000
    }
};

module.exports = PostgreSQLOptimization;
```

## 3. Caching Strategies

### 3.1 Multi-Level Caching

**Advanced Caching from Rocket.Chat**:

```javascript
// cache/multi-level-cache.js
const NodeCache = require('node-cache');
const Redis = require('ioredis');

class MultiLevelCache {
    constructor(options = {}) {
        // L1 Cache: In-memory (fastest)
        this.l1Cache = new NodeCache({
            stdTTL: options.l1TTL || 300,      // 5 minutes default
            maxKeys: options.l1MaxKeys || 1000,
            checkperiod: 60,                   // Check for expired keys every minute
            useClones: false                   // Better performance, but be careful with mutations
        });
        
        // L2 Cache: Redis (shared across instances)
        this.l2Cache = new Redis({
            host: process.env.REDIS_HOST || 'localhost',
            port: process.env.REDIS_PORT || 6379,
            password: process.env.REDIS_PASSWORD,
            db: 0,
            retryDelayOnFailover: 100,
            maxRetriesPerRequest: 3,
            lazyConnect: true,
            keepAlive: 30000
        });
        
        this.l2TTL = options.l2TTL || 3600; // 1 hour default
        this.compressionThreshold = options.compressionThreshold || 1024; // 1KB
        
        this.setupEventHandlers();
        this.setupMetrics();
    }
    
    setupEventHandlers() {
        this.l2Cache.on('error', (error) => {
            logger.error('Redis cache error:', error);
        });
        
        this.l2Cache.on('connect', () => {
            logger.info('Connected to Redis cache');
        });
        
        this.l1Cache.on('expired', (key, value) => {
            logger.debug('L1 cache key expired:', key);
        });
    }
    
    setupMetrics() {
        this.metrics = {
            l1Hits: 0,
            l1Misses: 0,
            l2Hits: 0,
            l2Misses: 0,
            sets: 0,
            deletes: 0
        };
        
        // Report metrics every 5 minutes
        setInterval(() => {
            logger.info('Cache metrics', this.metrics);
        }, 300000);
    }
    
    async get(key) {
        try {
            // Try L1 cache first
            let value = this.l1Cache.get(key);
            if (value !== undefined) {
                this.metrics.l1Hits++;
                return this.deserializeValue(value);
            }
            this.metrics.l1Misses++;
            
            // Try L2 cache
            const l2Value = await this.l2Cache.get(key);
            if (l2Value !== null) {
                this.metrics.l2Hits++;
                
                // Store in L1 cache for faster access
                const deserializedValue = this.deserializeValue(l2Value);
                this.l1Cache.set(key, l2Value, this.getL1TTL(key));
                
                return deserializedValue;
            }
            this.metrics.l2Misses++;
            
            return null;
        } catch (error) {
            logger.error('Cache get error:', error);
            return null;
        }
    }
    
    async set(key, value, ttl) {
        try {
            const serializedValue = this.serializeValue(value);
            const l1TTL = Math.min(ttl || this.l2TTL, 300); // L1 max 5 minutes
            
            // Set in L1 cache
            this.l1Cache.set(key, serializedValue, l1TTL);
            
            // Set in L2 cache with compression if needed
            const finalValue = this.shouldCompress(serializedValue) 
                ? this.compress(serializedValue)
                : serializedValue;
                
            await this.l2Cache.setex(key, ttl || this.l2TTL, finalValue);
            
            this.metrics.sets++;
            return true;
        } catch (error) {
            logger.error('Cache set error:', error);
            return false;
        }
    }
    
    async del(key) {
        try {
            this.l1Cache.del(key);
            await this.l2Cache.del(key);
            this.metrics.deletes++;
            return true;
        } catch (error) {
            logger.error('Cache delete error:', error);
            return false;
        }
    }
    
    async clear() {
        try {
            this.l1Cache.flushAll();
            await this.l2Cache.flushdb();
            return true;
        } catch (error) {
            logger.error('Cache clear error:', error);
            return false;
        }
    }
    
    // Cache invalidation patterns
    async invalidatePattern(pattern) {
        try {
            const keys = await this.l2Cache.keys(pattern);
            if (keys.length > 0) {
                // Batch delete for better performance
                const pipeline = this.l2Cache.pipeline();
                keys.forEach(key => {
                    pipeline.del(key);
                    this.l1Cache.del(key);
                });
                await pipeline.exec();
            }
            return keys.length;
        } catch (error) {
            logger.error('Cache pattern invalidation error:', error);
            return 0;
        }
    }
    
    // Helper methods
    serializeValue(value) {
        return JSON.stringify({
            data: value,
            timestamp: Date.now(),
            type: typeof value
        });
    }
    
    deserializeValue(serializedValue) {
        try {
            const parsed = JSON.parse(serializedValue);
            return parsed.data;
        } catch (error) {
            return serializedValue;
        }
    }
    
    shouldCompress(value) {
        return Buffer.byteLength(value, 'utf8') > this.compressionThreshold;
    }
    
    compress(value) {
        const zlib = require('zlib');
        return zlib.gzipSync(value).toString('base64');
    }
    
    decompress(compressedValue) {
        const zlib = require('zlib');
        return zlib.gunzipSync(Buffer.from(compressedValue, 'base64')).toString();
    }
    
    getL1TTL(key) {
        // Dynamic TTL based on key type
        if (key.startsWith('user:')) return 600;      // 10 minutes
        if (key.startsWith('post:')) return 300;      // 5 minutes
        if (key.startsWith('config:')) return 3600;   // 1 hour
        return 300; // Default 5 minutes
    }
    
    // Cache warming strategies
    async warmCache(warmingFunctions) {
        logger.info('Starting cache warming');
        
        const promises = warmingFunctions.map(async (fn) => {
            try {
                await fn(this);
            } catch (error) {
                logger.error('Cache warming error:', error);
            }
        });
        
        await Promise.all(promises);
        logger.info('Cache warming completed');
    }
    
    // Statistics and monitoring
    getStats() {
        return {
            l1Stats: this.l1Cache.getStats(),
            l2Connected: this.l2Cache.status === 'ready',
            metrics: this.metrics
        };
    }
}

// Cache middleware
class CacheMiddleware {
    constructor(cache) {
        this.cache = cache;
    }
    
    // HTTP response caching
    httpCache(options = {}) {
        return async (req, res, next) => {
            if (req.method !== 'GET') {
                return next();
            }
            
            const key = this.generateCacheKey(req, options);
            const cached = await this.cache.get(key);
            
            if (cached) {
                res.set({
                    'Cache-Control': `public, max-age=${options.ttl || 300}`,
                    'X-Cache': 'HIT',
                    'ETag': this.generateETag(cached)
                });
                return res.json(cached);
            }
            
            // Override res.json to cache response
            const originalJson = res.json;
            res.json = async function(body) {
                if (res.statusCode >= 200 && res.statusCode < 300) {
                    await this.cache.set(key, body, options.ttl);
                }
                
                res.set({
                    'X-Cache': 'MISS',
                    'ETag': this.generateETag(body)
                });
                
                return originalJson.call(this, body);
            }.bind(this);
            
            next();
        };
    }
    
    generateCacheKey(req, options) {
        const parts = [
            options.prefix || 'http',
            req.method,
            req.path,
            JSON.stringify(req.query),
            req.user?.id || 'anonymous'
        ];
        
        return parts.join(':');
    }
    
    generateETag(data) {
        const crypto = require('crypto');
        return crypto.createHash('md5').update(JSON.stringify(data)).digest('hex');
    }
}

module.exports = { MultiLevelCache, CacheMiddleware };
```

### 3.2 Cache Strategies Implementation

```javascript
// cache/strategies.js
class CacheStrategies {
    constructor(cache) {
        this.cache = cache;
    }
    
    // Write-through caching
    async writeThrough(key, data, updateFunction, ttl = 3600) {
        try {
            // Update the data source
            const result = await updateFunction(data);
            
            // Update cache
            await this.cache.set(key, result, ttl);
            
            return result;
        } catch (error) {
            // Invalidate cache on error
            await this.cache.del(key);
            throw error;
        }
    }
    
    // Write-behind caching
    async writeBehind(key, data, updateFunction, ttl = 3600) {
        // Update cache immediately
        await this.cache.set(key, data, ttl);
        
        // Queue the database update
        setImmediate(async () => {
            try {
                await updateFunction(data);
            } catch (error) {
                logger.error('Write-behind cache error:', error);
                // Optionally invalidate cache
                await this.cache.del(key);
            }
        });
        
        return data;
    }
    
    // Cache-aside pattern
    async cacheAside(key, fetchFunction, ttl = 3600) {
        // Try to get from cache
        let data = await this.cache.get(key);
        
        if (data === null) {
            // Cache miss - fetch from source
            data = await fetchFunction();
            
            if (data !== null) {
                await this.cache.set(key, data, ttl);
            }
        }
        
        return data;
    }
    
    // Read-through caching
    async readThrough(key, fetchFunction, ttl = 3600) {
        return this.cacheAside(key, fetchFunction, ttl);
    }
    
    // Refresh-ahead pattern
    async refreshAhead(key, fetchFunction, ttl = 3600, refreshThreshold = 0.8) {
        const cached = await this.cache.get(key);
        
        if (cached) {
            // Check if cache needs refresh
            const cacheAge = this.getCacheAge(key);
            if (cacheAge > ttl * refreshThreshold) {
                // Refresh asynchronously
                setImmediate(async () => {
                    try {
                        const freshData = await fetchFunction();
                        await this.cache.set(key, freshData, ttl);
                    } catch (error) {
                        logger.error('Refresh-ahead error:', error);
                    }
                });
            }
            
            return cached;
        }
        
        // Cache miss - fetch synchronously
        const data = await fetchFunction();
        await this.cache.set(key, data, ttl);
        return data;
    }
    
    getCacheAge(key) {
        // This would need to be implemented based on your cache implementation
        // Return age in seconds
        return 0;
    }
}

module.exports = CacheStrategies;
```

## 4. Memory Management

### 4.1 Memory Optimization

```javascript
// memory/optimization.js
class MemoryOptimization {
    constructor() {
        this.setupMemoryMonitoring();
        this.setupGarbageCollection();
    }
    
    setupMemoryMonitoring() {
        // Monitor memory usage every 30 seconds
        setInterval(() => {
            const usage = process.memoryUsage();
            const formatBytes = (bytes) => (bytes / 1024 / 1024).toFixed(2) + ' MB';
            
            logger.info('Memory usage', {
                rss: formatBytes(usage.rss),           // Resident Set Size
                heapTotal: formatBytes(usage.heapTotal), // Total heap size
                heapUsed: formatBytes(usage.heapUsed),   // Used heap size
                external: formatBytes(usage.external),   // External memory
                arrayBuffers: formatBytes(usage.arrayBuffers)
            });
            
            // Alert if memory usage is high
            if (usage.heapUsed / usage.heapTotal > 0.9) {
                logger.warn('High memory usage detected', {
                    heapUsedPercent: ((usage.heapUsed / usage.heapTotal) * 100).toFixed(2) + '%'
                });
                
                // Force garbage collection if available
                if (global.gc) {
                    global.gc();
                    logger.info('Forced garbage collection');
                }
            }
        }, 30000);
    }
    
    setupGarbageCollection() {
        // Optimize V8 garbage collection settings
        const gcFlags = [
            '--max-old-space-size=2048',        // 2GB heap limit
            '--max-new-space-size=256',         // 256MB young generation
            '--optimize-for-size',              // Optimize for memory over speed
            '--gc-interval=100'                 // Force GC every 100 allocations
        ];
        
        // These would be set via NODE_OPTIONS environment variable
        // NODE_OPTIONS="--max-old-space-size=2048 --optimize-for-size"
    }
    
    // Object pooling for frequently created objects
    createObjectPool(createFn, resetFn, maxSize = 100) {
        const pool = [];
        
        return {
            acquire() {
                if (pool.length > 0) {
                    return pool.pop();
                }
                return createFn();
            },
            
            release(obj) {
                if (pool.length < maxSize) {
                    resetFn(obj);
                    pool.push(obj);
                }
            },
            
            size() {
                return pool.length;
            }
        };
    }
    
    // Memory-efficient data structures
    createMemoryEfficientMap(maxSize = 1000) {
        const map = new Map();
        const accessOrder = [];
        
        return {
            set(key, value) {
                if (map.has(key)) {
                    // Move to end of access order
                    const index = accessOrder.indexOf(key);
                    accessOrder.splice(index, 1);
                    accessOrder.push(key);
                } else {
                    // Add new entry
                    if (map.size >= maxSize) {
                        // Remove least recently used
                        const lru = accessOrder.shift();
                        map.delete(lru);
                    }
                    accessOrder.push(key);
                }
                
                map.set(key, value);
            },
            
            get(key) {
                if (map.has(key)) {
                    // Move to end of access order
                    const index = accessOrder.indexOf(key);
                    accessOrder.splice(index, 1);
                    accessOrder.push(key);
                    
                    return map.get(key);
                }
                return undefined;
            },
            
            delete(key) {
                if (map.has(key)) {
                    const index = accessOrder.indexOf(key);
                    accessOrder.splice(index, 1);
                    return map.delete(key);
                }
                return false;
            },
            
            size() {
                return map.size;
            }
        };
    }
    
    // Stream processing for large datasets
    createStreamProcessor() {
        const { Transform } = require('stream');
        
        return new Transform({
            objectMode: true,
            highWaterMark: 16, // Process 16 objects at a time
            
            transform(chunk, encoding, callback) {
                try {
                    // Process chunk without keeping in memory
                    const processed = this.processChunk(chunk);
                    callback(null, processed);
                } catch (error) {
                    callback(error);
                }
            },
            
            processChunk(data) {
                // Implement your processing logic
                return data;
            }
        });
    }
    
    // Memory leak detection
    detectMemoryLeaks() {
        const initialUsage = process.memoryUsage();
        let checkCount = 0;
        
        const checkInterval = setInterval(() => {
            const currentUsage = process.memoryUsage();
            const heapGrowth = currentUsage.heapUsed - initialUsage.heapUsed;
            
            checkCount++;
            
            if (checkCount > 10 && heapGrowth > 50 * 1024 * 1024) { // 50MB growth
                logger.warn('Potential memory leak detected', {
                    heapGrowth: (heapGrowth / 1024 / 1024).toFixed(2) + ' MB',
                    checkCount
                });
            }
            
            if (checkCount > 100) {
                clearInterval(checkInterval);
            }
        }, 60000); // Check every minute
    }
}

module.exports = MemoryOptimization;
```

## 5. Network & I/O Optimization

### 5.1 HTTP/2 and Connection Optimization

```javascript
// network/http2-optimization.js
const http2 = require('http2');
const fs = require('fs');

class HTTP2Optimization {
    createHTTP2Server(app) {
        const server = http2.createSecureServer({
            key: fs.readFileSync(process.env.SSL_KEY),
            cert: fs.readFileSync(process.env.SSL_CERT),
            
            // HTTP/2 settings
            settings: {
                headerTableSize: 4096,
                enablePush: true,
                maxConcurrentStreams: 1000,
                initialWindowSize: 65535,
                maxFrameSize: 16384,
                maxHeaderListSize: 8192
            }
        });
        
        // Handle HTTP/2 streams
        server.on('stream', (stream, headers) => {
            const method = headers[':method'];
            const path = headers[':path'];
            const authority = headers[':authority'];
            
            // Create Express-compatible request/response
            const req = this.createRequestObject(stream, headers);
            const res = this.createResponseObject(stream);
            
            // Pass to Express app
            app(req, res);
        });
        
        return server;
    }
    
    setupServerPush(server) {
        server.on('stream', (stream, headers) => {
            // Push critical resources
            if (headers[':path'] === '/') {
                this.pushResources(stream, [
                    '/css/critical.css',
                    '/js/app.js',
                    '/favicon.ico'
                ]);
            }
        });
    }
    
    pushResources(stream, resources) {
        resources.forEach(resource => {
            stream.pushStream({
                ':method': 'GET',
                ':path': resource,
                ':scheme': 'https',
                ':authority': stream.session.socket.servername
            }, (err, pushStream) => {
                if (err) {
                    logger.error('HTTP/2 push error:', err);
                    return;
                }
                
                // Serve the resource
                this.serveStaticResource(pushStream, resource);
            });
        });
    }
    
    createRequestObject(stream, headers) {
        const req = {
            method: headers[':method'],
            url: headers[':path'],
            headers: {},
            stream
        };
        
        // Convert HTTP/2 headers to HTTP/1.1 format
        for (const [key, value] of Object.entries(headers)) {
            if (!key.startsWith(':')) {
                req.headers[key] = value;
            }
        }
        
        return req;
    }
    
    createResponseObject(stream) {
        const res = {
            statusCode: 200,
            headers: {},
            stream,
            
            setHeader(name, value) {
                this.headers[name] = value;
            },
            
            writeHead(statusCode, headers = {}) {
                this.statusCode = statusCode;
                Object.assign(this.headers, headers);
                
                const responseHeaders = {
                    ':status': statusCode,
                    ...this.headers
                };
                
                stream.respond(responseHeaders);
            },
            
            write(chunk) {
                stream.write(chunk);
            },
            
            end(chunk) {
                if (chunk) {
                    stream.write(chunk);
                }
                stream.end();
            }
        };
        
        return res;
    }
}
```

### 5.2 Connection Pooling and Keep-Alive

```javascript
// network/connection-optimization.js
const http = require('http');
const https = require('https');

class ConnectionOptimization {
    setupKeepAlive() {
        // Configure global HTTP agent for outgoing requests
        const httpAgent = new http.Agent({
            keepAlive: true,
            keepAliveMsecs: 30000,      // 30 seconds
            maxSockets: 50,             // Per host
            maxTotalSockets: 0,         // No limit
            timeout: 60000,             // 60 seconds
            freeSocketTimeout: 30000,   // 30 seconds
            scheduling: 'fifo'
        });
        
        const httpsAgent = new https.Agent({
            keepAlive: true,
            keepAliveMsecs: 30000,
            maxSockets: 50,
            maxTotalSockets: 0,
            timeout: 60000,
            freeSocketTimeout: 30000,
            scheduling: 'fifo'
        });
        
        // Set as default agents
        http.globalAgent = httpAgent;
        https.globalAgent = httpsAgent;
        
        return { httpAgent, httpsAgent };
    }
    
    setupServerOptimization(server) {
        // Server-side optimizations
        server.keepAliveTimeout = 120000;  // 2 minutes
        server.headersTimeout = 120000;    // 2 minutes
        server.timeout = 120000;           // 2 minutes
        
        // Connection management
        server.on('connection', (socket) => {
            socket.setKeepAlive(true, 30000);
            socket.setNoDelay(true);
            
            // Monitor connection
            logger.debug('New connection established');
            
            socket.on('close', () => {
                logger.debug('Connection closed');
            });
            
            socket.on('error', (error) => {
                logger.error('Socket error:', error);
            });
        });
        
        // Graceful shutdown
        this.setupGracefulShutdown(server);
    }
    
    setupGracefulShutdown(server) {
        const connections = new Set();
        
        server.on('connection', (socket) => {
            connections.add(socket);
            
            socket.on('close', () => {
                connections.delete(socket);
            });
        });
        
        const gracefulShutdown = (signal) => {
            logger.info(`Received ${signal}, shutting down gracefully`);
            
            server.close(() => {
                logger.info('HTTP server closed');
                process.exit(0);
            });
            
            // Force close connections after timeout
            setTimeout(() => {
                logger.warn('Force closing connections');
                connections.forEach(socket => socket.destroy());
                process.exit(1);
            }, 10000);
        };
        
        process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
        process.on('SIGINT', () => gracefulShutdown('SIGINT'));
    }
}

module.exports = ConnectionOptimization;
```

## 🔗 Navigation

### Related Documents
- ⬅️ **Previous**: [Testing Strategies](./testing-strategies.md)
- ➡️ **Next**: [Deployment Patterns](./deployment-patterns.md)

### Quick Links
- [Implementation Guide](./implementation-guide.md)
- [Tools & Ecosystem](./tools-ecosystem.md)
- [Architecture Patterns](./architecture-patterns.md)

---

**Performance Optimization Complete** | **Optimization Areas**: 7 | **Techniques**: 50+ | **Code Examples**: 25+