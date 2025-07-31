# Performance Analysis: Database Optimization Strategies

## 🎯 Overview

This comprehensive performance analysis provides detailed strategies, techniques, and tools for optimizing PostgreSQL and MongoDB databases in EdTech environments. The guide includes benchmarking methodologies, optimization techniques, and real-world performance improvements.

## 📊 Performance Benchmarking Framework

### Benchmark Environment Setup

#### Hardware Configuration
```yaml
Production-Grade Test Environment:
  CPU: AMD EPYC 7742 (64 cores, 2.25GHz base)
  RAM: 128GB DDR4-3200
  Storage: NVMe SSD (Samsung 980 PRO, 7000 MB/s read)
  Network: 10Gbps Ethernet
  OS: Ubuntu 22.04 LTS

Database Configurations:
  PostgreSQL: 15.4 (optimized configuration)
  MongoDB: 6.0.8 (WiredTiger storage engine)
  Connection Pool: PgBouncer for PostgreSQL, native for MongoDB
```

#### Test Dataset Specifications
```
EdTech Application Dataset:
├── Users: 1,000,000 records
├── Courses: 50,000 records  
├── Lessons: 500,000 records
├── Enrollments: 5,000,000 records
├── Quiz Attempts: 10,000,000 records
├── User Progress: 15,000,000 records
└── Content Metadata: 2,000,000 documents

Data Distribution:
- Average user: 5 course enrollments
- Average course: 10 lessons, 100 enrollments
- Average lesson: 20 quiz attempts
- Data growth rate: 10% monthly
```

### Performance Testing Methodology

#### Load Testing Framework
```javascript
// Performance testing with Artillery.js
// artillery-config.yml
config:
  target: 'http://api.edtech-app.com'
  phases:
    - duration: 300  # 5 minutes warmup
      arrivalRate: 10
      name: "Warmup"
    - duration: 600  # 10 minutes steady load
      arrivalRate: 100
      name: "Steady Load"
    - duration: 300  # 5 minutes peak load
      arrivalRate: 500
      name: "Peak Load"
  processor: "./test-functions.js"

scenarios:
  - name: "User Authentication & Course Browse"
    weight: 40
    flow:
      - post:
          url: "/auth/login"
          json:
            email: "{{ $randomEmail }}"
            password: "testpass123"
          capture:
            json: "$.token"
            as: "authToken"
      - get:
          url: "/courses?page=1&limit=20"
          headers:
            Authorization: "Bearer {{ authToken }}"
          
  - name: "Course Content Access"
    weight: 30
    flow:
      - get:
          url: "/courses/{{ $randomUUID }}/lessons"
          headers:
            Authorization: "Bearer {{ authToken }}"
      - post:
          url: "/progress/update"
          json:
            lessonId: "{{ $randomUUID }}"
            progress: "{{ $randomInt(1, 100) }}"
            
  - name: "Quiz Taking & Submission"
    weight: 20
    flow:
      - get:
          url: "/quizzes/{{ $randomUUID }}"
      - post:
          url: "/quiz-attempts"
          json:
            quizId: "{{ $randomUUID }}"
            answers: "{{ generateQuizAnswers() }}"
            
  - name: "Analytics Dashboard"
    weight: 10
    flow:
      - get:
          url: "/analytics/user-progress"
      - get:
          url: "/analytics/course-performance"
```

## 🐘 PostgreSQL Performance Optimization

### Configuration Tuning

#### Memory Configuration Optimization
```ini
# postgresql.conf - Optimized for 128GB RAM system
# Memory Settings
shared_buffers = 32GB                   # 25% of total RAM
effective_cache_size = 96GB             # 75% of total RAM
work_mem = 256MB                        # Per-operation memory
maintenance_work_mem = 2GB              # For maintenance operations
huge_pages = on                         # Enable huge pages

# Query Planner Settings
random_page_cost = 1.1                  # Optimized for SSD
seq_page_cost = 1.0                     # Sequential page cost
cpu_tuple_cost = 0.01                   # CPU processing cost
cpu_index_tuple_cost = 0.005            # Index tuple cost
cpu_operator_cost = 0.0025              # Operator cost

# Parallel Query Settings
max_parallel_workers_per_gather = 8     # Parallel workers per query
max_parallel_workers = 16               # Total parallel workers
max_parallel_maintenance_workers = 8    # For maintenance operations
parallel_tuple_cost = 0.1               # Parallel tuple cost
parallel_setup_cost = 1000.0            # Parallel setup cost

# Connection and Resource Settings
max_connections = 500                   # Maximum connections
superuser_reserved_connections = 5      # Reserved for admin
shared_preload_libraries = 'pg_stat_statements,auto_explain'

# WAL and Checkpoint Settings
wal_buffers = 64MB                      # WAL buffers
checkpoint_completion_target = 0.9      # Checkpoint completion target
checkpoint_timeout = 10min              # Maximum time between checkpoints
max_wal_size = 8GB                      # Maximum WAL size
min_wal_size = 2GB                      # Minimum WAL size

# Logging and Monitoring
log_min_duration_statement = 1000       # Log slow queries (1 second)
log_checkpoints = on                    # Log checkpoint information
log_connections = on                    # Log connections
log_disconnections = on                 # Log disconnections
log_lock_waits = on                     # Log lock waits
track_activity_query_size = 2048        # Query string size in pg_stat_activity
```

#### Advanced Indexing Strategies
```sql
-- Strategic Index Creation for EdTech Workloads

-- 1. User Authentication and Profile Queries
CREATE UNIQUE INDEX idx_users_email_lower ON users (LOWER(email));
CREATE INDEX idx_users_active_login ON users (is_active, last_login_at DESC) 
    WHERE is_active = true;

-- 2. Course Discovery and Search
CREATE INDEX idx_courses_discovery ON courses 
    (category_id, level, is_published, rating DESC, enrollment_count DESC)
    WHERE is_published = true;

-- Full-text search with GIN index
CREATE INDEX idx_courses_fts ON courses 
    USING GIN (to_tsvector('english', title || ' ' || COALESCE(description, '')))
    WHERE is_published = true;

-- 3. User Progress Tracking (Hot Path)
CREATE INDEX idx_user_progress_hot ON user_progress 
    (user_id, course_id, last_accessed_at DESC)
    INCLUDE (completion_percentage, is_completed);

-- Partial index for active learning
CREATE INDEX idx_user_progress_active ON user_progress 
    (user_id, last_accessed_at DESC)
    WHERE is_completed = false AND last_accessed_at > NOW() - INTERVAL '30 days';

-- 4. Quiz Performance Optimization
CREATE INDEX idx_quiz_attempts_user_recent ON quiz_attempts 
    (user_id, created_at DESC)
    INCLUDE (quiz_id, score, is_passed);

-- Composite index for leaderboards
CREATE INDEX idx_quiz_leaderboard ON quiz_attempts 
    (quiz_id, score DESC, created_at DESC)
    WHERE is_passed = true;

-- 5. Analytics and Reporting Indexes
CREATE INDEX idx_enrollments_analytics ON enrollments 
    (enrolled_at, course_id)
    INCLUDE (user_id, price_paid);

-- Time-series partitioning helper
CREATE INDEX idx_user_activity_time_series ON user_activity 
    (DATE_TRUNC('day', created_at), user_id)
    WHERE created_at >= CURRENT_DATE - INTERVAL '90 days';

-- 6. JSONB Optimization for Metadata
CREATE INDEX idx_courses_metadata ON courses 
    USING GIN (metadata jsonb_path_ops)
    WHERE metadata IS NOT NULL;

-- Specific JSONB queries
CREATE INDEX idx_courses_difficulty ON courses 
    USING BTREE ((metadata->>'difficulty'))
    WHERE is_published = true AND metadata ? 'difficulty';
```

#### Query Optimization Techniques
```sql
-- 1. Optimized Course Listing with Pagination
-- BEFORE: Slow query with offset
SELECT c.id, c.title, c.rating, c.price, u.first_name, u.last_name
FROM courses c
JOIN users u ON c.instructor_id = u.id
WHERE c.is_published = true
ORDER BY c.rating DESC, c.created_at DESC
LIMIT 20 OFFSET 1000;  -- Slow for large offsets

-- AFTER: Cursor-based pagination (10x faster)
WITH course_page AS (
    SELECT c.id, c.title, c.rating, c.price, c.instructor_id,
           c.created_at, c.rating AS cursor_rating
    FROM courses c
    WHERE c.is_published = true
      AND (c.rating, c.created_at) < (4.5, '2024-01-15'::timestamp)  -- Cursor values
    ORDER BY c.rating DESC, c.created_at DESC
    LIMIT 20
)
SELECT cp.id, cp.title, cp.rating, cp.price, 
       u.first_name, u.last_name
FROM course_page cp
JOIN users u ON cp.instructor_id = u.id;

-- 2. User Progress Analytics with Window Functions
-- Optimized query for user learning analytics
SELECT 
    up.user_id,
    up.course_id,
    c.title,
    up.completion_percentage,
    up.time_spent_minutes,
    -- Running totals and rankings
    SUM(up.time_spent_minutes) OVER (
        PARTITION BY up.user_id 
        ORDER BY up.last_accessed_at
        ROWS UNBOUNDED PRECEDING
    ) as cumulative_time,
    RANK() OVER (
        PARTITION BY up.course_id 
        ORDER BY up.completion_percentage DESC
    ) as course_rank,
    -- Comparative metrics
    AVG(up.completion_percentage) OVER (
        PARTITION BY up.course_id
    ) as avg_course_completion,
    PERCENTILE_CONT(0.5) WITHIN GROUP (
        ORDER BY up.time_spent_minutes
    ) OVER (
        PARTITION BY up.course_id
    ) as median_time_spent
FROM user_progress up
JOIN courses c ON up.course_id = c.id
WHERE up.user_id = $1
  AND up.last_accessed_at >= NOW() - INTERVAL '90 days'
ORDER BY up.last_accessed_at DESC;

-- 3. Complex Analytics Query Optimization
-- Multi-dimensional course performance analysis
WITH monthly_metrics AS (
    SELECT 
        DATE_TRUNC('month', e.enrolled_at) as month,
        c.category_id,
        COUNT(DISTINCT e.user_id) as new_enrollments,
        COUNT(DISTINCT CASE WHEN up.completion_percentage = 100 THEN e.user_id END) as completions,
        AVG(up.completion_percentage) as avg_completion,
        SUM(e.price_paid) as revenue
    FROM enrollments e
    JOIN courses c ON e.course_id = c.id
    LEFT JOIN user_progress up ON e.user_id = up.user_id AND e.course_id = up.course_id
    WHERE e.enrolled_at >= DATE_TRUNC('month', NOW() - INTERVAL '12 months')
    GROUP BY DATE_TRUNC('month', e.enrolled_at), c.category_id
),
category_rankings AS (
    SELECT 
        month,
        category_id,
        new_enrollments,
        completions,
        avg_completion,
        revenue,
        ROW_NUMBER() OVER (PARTITION BY month ORDER BY revenue DESC) as revenue_rank,
        LAG(revenue) OVER (PARTITION BY category_id ORDER BY month) as prev_month_revenue
    FROM monthly_metrics
)
SELECT 
    month,
    category_id,
    new_enrollments,
    completions,
    ROUND(avg_completion, 2) as avg_completion_pct,
    revenue,
    revenue_rank,
    CASE 
        WHEN prev_month_revenue IS NOT NULL THEN
            ROUND(((revenue - prev_month_revenue) / prev_month_revenue * 100), 2)
        ELSE NULL
    END as revenue_growth_pct,
    ROUND((completions::DECIMAL / NULLIF(new_enrollments, 0) * 100), 2) as completion_rate_pct
FROM category_rankings
ORDER BY month DESC, revenue_rank;
```

### Connection Pool Optimization

#### PgBouncer Configuration
```ini
# pgbouncer.ini - Production Configuration
[databases]
edtech_db = host=localhost port=5432 dbname=edtech_production user=edtech_user

[pgbouncer]
# Connection pool settings
pool_mode = transaction              # Most efficient for web apps
listen_port = 6432
listen_addr = 0.0.0.0
auth_type = scram-sha-256
auth_file = /etc/pgbouncer/userlist.txt

# Pool sizing - critical for performance
max_client_conn = 1000              # Maximum client connections
default_pool_size = 100             # Default pool size per database
min_pool_size = 20                  # Minimum connections to maintain
reserve_pool_size = 20              # Reserved connections for superuser
reserve_pool_timeout = 5            # Timeout for reserved pool

# Performance tuning
server_reset_query = DISCARD ALL    # Reset server state
server_check_query = SELECT 1       # Health check query
server_check_delay = 30             # Health check interval
max_db_connections = 200            # Max connections per database
max_user_connections = 100          # Max connections per user

# Timeouts
server_lifetime = 3600              # Server connection lifetime
server_idle_timeout = 600           # Idle timeout
client_idle_timeout = 0             # Client idle timeout (disabled)
query_timeout = 300                 # Query timeout
query_wait_timeout = 120            # Queue wait timeout

# Logging and monitoring
log_connections = 1                 # Log connections
log_disconnections = 1              # Log disconnections
log_pooler_errors = 1               # Log pooler errors
stats_period = 60                   # Statistics period
```

#### Application-Level Connection Management
```typescript
// Optimized PostgreSQL connection management
import { Pool, PoolConfig } from 'pg';
import { promisify } from 'util';

interface DatabaseMetrics {
  totalConnections: number;
  idleConnections: number;
  waitingClients: number;
  averageQueryTime: number;
}

class OptimizedPostgreSQLService {
  private pool: Pool;
  private queryMetrics: Map<string, number[]> = new Map();

  constructor() {
    const poolConfig: PoolConfig = {
      // Connection settings
      host: process.env.DB_HOST,
      port: parseInt(process.env.DB_PORT || '5432'),
      database: process.env.DB_NAME,
      user: process.env.DB_USER,
      password: process.env.DB_PASSWORD,

      // Pool configuration - tuned for EdTech workloads
      min: 20,                        // Minimum connections
      max: 100,                       // Maximum connections
      idleTimeoutMillis: 30000,       // 30 second idle timeout
      connectionTimeoutMillis: 5000,   // 5 second connection timeout
      
      // Query configuration
      query_timeout: 60000,           // 60 second query timeout
      statement_timeout: 120000,      // 2 minute statement timeout
      
      // SSL configuration
      ssl: process.env.NODE_ENV === 'production' ? {
        rejectUnauthorized: false
      } : false,

      // Advanced settings
      application_name: 'edtech-api',
      keepAlive: true,
      keepAliveInitialDelayMillis: 10000,
    };

    this.pool = new Pool(poolConfig);
    this.setupEventHandlers();
    this.startMetricsCollection();
  }

  private setupEventHandlers(): void {
    this.pool.on('connect', (client) => {
      console.log('New PostgreSQL client connected');
      
      // Set session-level optimizations
      client.query(`
        SET statement_timeout = '2min';
        SET lock_timeout = '30s';
        SET idle_in_transaction_session_timeout = '10min';
      `);
    });

    this.pool.on('error', (err, client) => {
      console.error('Unexpected error on idle PostgreSQL client', err);
    });

    this.pool.on('remove', (client) => {
      console.log('PostgreSQL client removed from pool');
    });
  }

  // High-performance query execution with metrics
  async executeQuery<T>(
    query: string, 
    params: any[] = [], 
    queryName?: string
  ): Promise<T[]> {
    const startTime = Date.now();
    const client = await this.pool.connect();

    try {
      const result = await client.query(query, params);
      const executionTime = Date.now() - startTime;

      // Track query performance
      if (queryName) {
        this.trackQueryMetrics(queryName, executionTime);
      }

      // Log slow queries
      if (executionTime > 1000) {
        console.warn(`Slow query detected: ${queryName || 'unnamed'} took ${executionTime}ms`);
      }

      return result.rows;
    } finally {
      client.release();
    }
  }

  // Optimized transaction handling
  async executeTransaction<T>(
    callback: (client: any) => Promise<T>
  ): Promise<T> {
    const client = await this.pool.connect();
    
    try {
      await client.query('BEGIN');
      
      // Set transaction-level optimizations
      await client.query('SET LOCAL synchronous_commit = OFF');
      await client.query('SET LOCAL checkpoint_completion_target = 0.9');
      
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

  // Performance metrics collection
  private trackQueryMetrics(queryName: string, executionTime: number): void {
    if (!this.queryMetrics.has(queryName)) {
      this.queryMetrics.set(queryName, []);
    }
    
    const metrics = this.queryMetrics.get(queryName)!;
    metrics.push(executionTime);
    
    // Keep only last 100 measurements
    if (metrics.length > 100) {
      metrics.shift();
    }
  }

  // Connection pool health monitoring
  getPoolMetrics(): DatabaseMetrics {
    return {
      totalConnections: this.pool.totalCount,
      idleConnections: this.pool.idleCount,
      waitingClients: this.pool.waitingCount,
      averageQueryTime: this.calculateAverageQueryTime()
    };
  }

  private calculateAverageQueryTime(): number {
    let totalTime = 0;
    let totalQueries = 0;

    for (const metrics of this.queryMetrics.values()) {
      totalTime += metrics.reduce((sum, time) => sum + time, 0);
      totalQueries += metrics.length;
    }

    return totalQueries > 0 ? totalTime / totalQueries : 0;
  }

  private startMetricsCollection(): void {
    setInterval(() => {
      const metrics = this.getPoolMetrics();
      console.log('PostgreSQL Pool Metrics:', metrics);
      
      // Alert on performance issues
      if (metrics.waitingClients > 10) {
        console.warn('High connection pool contention detected');
      }
      
      if (metrics.averageQueryTime > 500) {
        console.warn('High average query time detected');
      }
    }, 30000); // Every 30 seconds
  }

  async close(): Promise<void> {
    await this.pool.end();
  }
}
```

## 🍃 MongoDB Performance Optimization

### Configuration Tuning

#### WiredTiger Storage Engine Optimization
```yaml
# mongod.conf - Production optimized configuration
systemLog:
  destination: file
  path: /var/log/mongodb/mongod.log
  logAppend: true
  logRotate: reopen
  component:
    query:
      verbosity: 1
    command:
      verbosity: 1

net:
  port: 27017
  bindIp: 0.0.0.0
  maxIncomingConnections: 2000         # Increased for high concurrency
  serviceExecutor: adaptive            # Adaptive thread pool

processManagement:
  timeZoneInfo: /usr/share/zoneinfo

security:
  authorization: enabled

storage:
  dbPath: /data/db
  engine: wiredTiger
  wiredTiger:
    engineConfig:
      cacheSizeGB: 64                  # 50% of available RAM
      directoryForIndexes: true        # Separate directory for indexes
      configString: |
        eviction=(threads_min=4,threads_max=8),
        file_manager=(close_idle_time=300,close_scan_interval=10),
        statistics_log=(wait=0),
        log=(compressor=snappy,file_max=200MB),
        checkpoint=(wait=60)
    collectionConfig:
      blockCompressor: snappy          # Compression for collections
    indexConfig:
      prefixCompression: true          # Prefix compression for indexes

operationProfiling:
  mode: slowOp
  slowOpThresholdMs: 500              # Profile operations slower than 500ms
  slowOpSampleRate: 0.1               # Sample 10% of slow operations

replication:
  replSetName: "edtech-rs"
  enableMajorityReadConcern: true

sharding:
  clusterRole: shardsvr               # If part of sharded cluster

setParameter:
  failIndexKeyTooLong: false
  notablescan: 0                      # Allow table scans in development
  maxIndexBuildMemoryUsageMegabytes: 2048  # Index build memory limit
  internalQueryPlanEvaluationWorks: 100000  # Query plan evaluation
  internalQueryPlanEvaluationCollFraction: 0.3
  wiredTigerConcurrentReadTransactions: 256
  wiredTigerConcurrentWriteTransactions: 256
```

#### Advanced Indexing for MongoDB
```javascript
// Strategic MongoDB index creation for EdTech workloads
db = db.getSiblingDB('edtech_db');

// 1. User Authentication and Profile Queries
db.users.createIndex({ "email": 1 }, { unique: true });
db.users.createIndex({ "isActive": 1, "lastLoginAt": -1 });
db.users.createIndex({ "role": 1, "isActive": 1 });

// Sparse index for optional fields
db.users.createIndex(
  { "subscription.endDate": 1 },
  { sparse: true, partialFilterExpression: { "subscription.endDate": { $exists: true } } }
);

// 2. Course Discovery and Search Optimization
// Compound index for course discovery (order matters!)
db.courses.createIndex({
  "isPublished": 1,
  "category": 1,
  "level": 1,
  "rating": -1,
  "enrollmentCount": -1
});

// Text search index with weights
db.courses.createIndex({
  "title": "text",
  "description": "text",
  "tags": "text",
  "instructor.name": "text"
}, {
  weights: {
    "title": 10,
    "tags": 5,
    "description": 3,
    "instructor.name": 2
  },
  name: "course_search_index"
});

// Geospatial index for location-based content
db.courses.createIndex({ "location": "2dsphere" });

// 3. User Progress Tracking (Critical Performance Path)
// Compound index for user progress queries
db.user_progress.createIndex({
  "userId": 1,
  "courseId": 1,
  "lastAccessedAt": -1
}, { unique: true });

// Index for active learning sessions
db.user_progress.createIndex(
  { "userId": 1, "lastAccessedAt": -1 },
  {
    partialFilterExpression: {
      "isCompleted": false,
      "lastAccessedAt": { $gte: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000) }
    }
  }
);

// Embedded array indexing for lesson progress
db.user_progress.createIndex({ "lessonProgress.lessonId": 1 });
db.user_progress.createIndex({ "lessonProgress.isCompleted": 1, "lessonProgress.completedAt": -1 });

// 4. Quiz and Assessment Performance
db.quiz_attempts.createIndex({
  "userId": 1,
  "completedAt": -1
});

db.quiz_attempts.createIndex({
  "quizId": 1,
  "score": -1,
  "completedAt": -1
});

// Compound index for leaderboards
db.quiz_attempts.createIndex({
  "courseId": 1,
  "isPassed": 1,
  "score": -1,
  "completedAt": -1
});

// 5. Analytics and Reporting Indexes
db.enrollments.createIndex({
  "enrolledAt": -1,
  "courseId": 1
});

// Time-series indexing pattern
db.user_activity.createIndex({
  "userId": 1,
  "timestamp": -1
});

// TTL index for temporary data
db.sessions.createIndex(
  { "expiresAt": 1 },
  { expireAfterSeconds: 0 }
);

// 6. Aggregation Pipeline Optimization Indexes
// Support for complex aggregation queries
db.quiz_attempts.createIndex({
  "courseId": 1,
  "completedAt": -1,
  "score": -1
});

db.user_progress.createIndex({
  "courseId": 1,
  "overallCompletionPercentage": -1,
  "lastAccessedAt": -1
});

console.log("✅ All MongoDB indexes created successfully");

// Index analysis and optimization
function analyzeIndexUsage() {
  const collections = ['users', 'courses', 'user_progress', 'quiz_attempts', 'enrollments'];
  
  collections.forEach(collectionName => {
    console.log(`\n=== ${collectionName} Index Statistics ===`);
    
    const stats = db[collectionName].aggregate([
      { $indexStats: {} },
      { $sort: { "accesses.ops": -1 } }
    ]).toArray();
    
    stats.forEach(stat => {
      console.log(`Index: ${stat.name}`);
      console.log(`  Operations: ${stat.accesses.ops}`);
      console.log(`  Since: ${stat.accesses.since}`);
      
      if (stat.accesses.ops === 0) {
        console.log(`  ⚠️  UNUSED INDEX - Consider dropping`);
      }
    });
  });
}

// Run index analysis
analyzeIndexUsage();
```

#### Aggregation Pipeline Optimization
```javascript
// Optimized MongoDB aggregation pipelines for EdTech analytics

// 1. Course Performance Analytics (Optimized)
db.user_progress.aggregate([
  // Stage 1: Match recent activity (use index)
  {
    $match: {
      "lastAccessedAt": { $gte: new Date(Date.now() - 90 * 24 * 60 * 60 * 1000) },
      "overallCompletionPercentage": { $gt: 0 }
    }
  },
  
  // Stage 2: Early group to reduce data volume
  {
    $group: {
      _id: "$courseId",
      totalUsers: { $sum: 1 },
      avgCompletion: { $avg: "$overallCompletionPercentage" },
      totalTimeSpent: { $sum: "$totalTimeSpent" },
      completedUsers: {
        $sum: { $cond: [{ $eq: ["$overallCompletionPercentage", 100] }, 1, 0] }
      }
    }
  },
  
  // Stage 3: Lookup course details (after data reduction)
  {
    $lookup: {
      from: "courses",
      localField: "_id",
      foreignField: "_id",
      as: "course",
      pipeline: [
        { $project: { "title": 1, "category": 1, "level": 1, "rating": 1 } }
      ]
    }
  },
  
  // Stage 4: Unwind and calculate metrics
  {
    $unwind: "$course"
  },
  
  // Stage 5: Add calculated fields
  {
    $addFields: {
      completionRate: { $divide: ["$completedUsers", "$totalUsers"] },
      avgTimePerUser: { $divide: ["$totalTimeSpent", "$totalUsers"] },
      engagementScore: {
        $multiply: [
          { $divide: ["$avgCompletion", 100] },
          { $add: [1, { $divide: ["$course.rating", 5] }] }
        ]
      }
    }
  },
  
  // Stage 6: Final projection and sorting
  {
    $project: {
      courseId: "$_id",
      title: "$course.title",
      category: "$course.category",
      level: "$course.level",
      totalUsers: 1,
      avgCompletion: { $round: ["$avgCompletion", 2] },
      completionRate: { $round: ["$completionRate", 3] },
      avgTimePerUser: { $round: ["$avgTimePerUser", 0] },
      engagementScore: { $round: ["$engagementScore", 2] }
    }
  },
  
  {
    $sort: { "engagementScore": -1 }
  },
  
  {
    $limit: 50
  }
], {
  allowDiskUse: true,  // Allow using disk for large datasets
  hint: { "courseId": 1, "overallCompletionPercentage": -1, "lastAccessedAt": -1 }
});

// 2. User Learning Path Analytics (Highly Optimized)
function getUserLearningAnalytics(userId) {
  return db.user_progress.aggregate([
    // Stage 1: Match specific user (uses index efficiently)
    {
      $match: {
        "userId": ObjectId(userId)
      }
    },
    
    // Stage 2: Lookup course information
    {
      $lookup: {
        from: "courses",
        localField: "courseId",
        foreignField: "_id",
        as: "course",
        pipeline: [
          {
            $project: {
              "title": 1,
              "category": 1,
              "level": 1,
              "estimatedHours": 1,
              "lessons": { $size: "$lessons" }
            }
          }
        ]
      }
    },
    
    {
      $unwind: "$course"
    },
    
    // Stage 3: Calculate learning metrics
    {
      $addFields: {
        timeEfficiency: {
          $divide: [
            "$overallCompletionPercentage",
            { $add: ["$totalTimeSpent", 1] }  // Avoid division by zero
          ]
        },
        progressVelocity: {
          $divide: [
            "$overallCompletionPercentage",
            {
              $divide: [
                { $subtract: [new Date(), "$startedAt"] },
                1000 * 60 * 60 * 24  // Convert to days
              ]
            }
          ]
        },
        estimatedTimeRemaining: {
          $multiply: [
            { $divide: [
              { $subtract: [100, "$overallCompletionPercentage"] },
              100
            ]},
            "$course.estimatedHours"
          ]
        }
      }
    },
    
    // Stage 4: Group by category for insights
    {
      $group: {
        _id: "$course.category",
        courses: {
          $push: {
            courseId: "$courseId",
            title: "$course.title",
            level: "$course.level",
            completion: "$overallCompletionPercentage",
            timeSpent: "$totalTimeSpent",
            timeEfficiency: "$timeEfficiency",
            progressVelocity: "$progressVelocity",
            estimatedTimeRemaining: "$estimatedTimeRemaining",
            lastAccessed: "$lastAccessedAt"
          }
        },
        totalCourses: { $sum: 1 },
        avgCompletion: { $avg: "$overallCompletionPercentage" },
        totalTimeSpent: { $sum: "$totalTimeSpent" },
        avgTimeEfficiency: { $avg: "$timeEfficiency" }
      }
    },
    
    // Stage 5: Sort and format final results
    {
      $sort: { "avgCompletion": -1 }
    },
    
    {
      $project: {
        category: "$_id",
        totalCourses: 1,
        avgCompletion: { $round: ["$avgCompletion", 2] },
        totalTimeSpent: 1,
        avgTimeEfficiency: { $round: ["$avgTimeEfficiency", 4] },
        courses: {
          $sortArray: {
            input: "$courses",
            sortBy: { "lastAccessed": -1 }
          }
        }
      }
    }
  ], {
    allowDiskUse: false  // Should be fast enough without disk usage
  });
}

// 3. Real-time Dashboard Metrics (Cached Aggregation)
function getCachedDashboardMetrics() {
  // Use $merge to maintain materialized view
  return db.user_progress.aggregate([
    {
      $match: {
        "lastAccessedAt": { $gte: new Date(Date.now() - 24 * 60 * 60 * 1000) }
      }
    },
    
    {
      $facet: {
        "activeUsers": [
          { $group: { _id: null, count: { $sum: 1 } } }
        ],
        "courseEngagement": [
          {
            $group: {
              _id: "$courseId",
              activeUsers: { $sum: 1 },
              avgCompletion: { $avg: "$overallCompletionPercentage" }
            }
          },
          { $sort: { "activeUsers": -1 } },
          { $limit: 10 }
        ],
        "completionTrends": [
          {
            $bucket: {
              groupBy: "$overallCompletionPercentage",
              boundaries: [0, 25, 50, 75, 100],
              default: "other",
              output: {
                count: { $sum: 1 },
                avgTimeSpent: { $avg: "$totalTimeSpent" }
              }
            }
          }
        ]
      }
    },
    
    // Cache results in dashboard_metrics collection
    {
      $merge: {
        into: "dashboard_metrics",
        whenMatched: "replace",
        whenNotMatched: "insert"
      }
    }
  ], {
    allowDiskUse: true
  });
}
```

### Connection Management for MongoDB

#### Optimized MongoDB Connection Service
```typescript
// Advanced MongoDB connection management with monitoring
import { MongoClient, MongoClientOptions, Db, Collection } from 'mongodb';

interface MongoMetrics {
  totalConnections: number;
  availableConnections: number;
  activeOperations: number;
  averageResponseTime: number;
  slowQueries: number;
}

class OptimizedMongoDBService {
  private client: MongoClient | null = null;
  private db: Db | null = null;
  private operationMetrics: Map<string, number[]> = new Map();
  private slowQueryThreshold = 1000; // 1 second

  private readonly connectionOptions: MongoClientOptions = {
    // Connection pool settings - optimized for EdTech workloads
    maxPoolSize: 200,                    // Maximum concurrent connections
    minPoolSize: 20,                     // Minimum connections to maintain
    maxIdleTimeMS: 30000,                // Close idle connections after 30s
    waitQueueTimeoutMS: 10000,           // Wait timeout for connection from pool
    
    // Server selection and connection timeouts
    serverSelectionTimeoutMS: 10000,     // Timeout for server selection
    connectTimeoutMS: 10000,             // Initial connection timeout
    socketTimeoutMS: 45000,              // Socket timeout
    
    // Write concern for data durability
    writeConcern: {
      w: 'majority',                     // Wait for majority acknowledgment
      j: true,                           // Wait for journal sync
      wtimeout: 10000                    // Write timeout
    },
    
    // Read preferences
    readPreference: 'primaryPreferred',   // Prefer primary but use secondary if needed
    readConcern: { level: 'local' },     // Local read concern for performance
    
    // Compression and performance
    compressors: ['snappy', 'zlib'],     // Enable compression
    zlibCompressionLevel: 6,             // Balanced compression level
    
    // Monitoring and debugging
    monitorCommands: true,               // Enable command monitoring
    
    // Authentication
    authSource: 'edtech_db',
    
    // Retry logic
    retryWrites: true,                   // Retry failed writes
    retryReads: true,                    // Retry failed reads
    
    // Advanced options
    maxConnecting: 10,                   // Max simultaneous connection attempts
    heartbeatFrequencyMS: 10000,         // Heartbeat frequency
    appName: 'edtech-api',               // Application identifier
  };

  async connect(): Promise<void> {
    try {
      this.client = new MongoClient(
        process.env.MONGODB_CONNECTION_STRING!,
        this.connectionOptions
      );

      await this.client.connect();
      this.db = this.client.db(process.env.MONGODB_DATABASE_NAME);
      
      console.log('✅ Connected to MongoDB');
      
      // Setup monitoring
      this.setupEventHandlers();
      this.startMetricsCollection();
      
      // Test connection with ping
      await this.db.admin().ping();
      console.log('✅ MongoDB ping successful');
      
    } catch (error) {
      console.error('❌ MongoDB connection failed:', error);
      throw error;
    }
  }

  private setupEventHandlers(): void {
    if (!this.client) return;

    // Connection pool monitoring
    this.client.on('connectionPoolCreated', (event) => {
      console.log('MongoDB connection pool created');
    });

    this.client.on('connectionPoolClosed', (event) => {
      console.log('MongoDB connection pool closed');
    });

    this.client.on('connectionCreated', (event) => {
      console.log(`MongoDB connection created: ${event.connectionId}`);
    });

    this.client.on('connectionClosed', (event) => {
      console.log(`MongoDB connection closed: ${event.connectionId}`);
    });

    // Command monitoring for performance tracking
    this.client.on('commandStarted', (event) => {
      // Track command start time
      event.requestId && this.operationMetrics.set(
        `start_${event.requestId}`, 
        [Date.now()]
      );
    });

    this.client.on('commandSucceeded', (event) => {
      this.trackCommandPerformance(event.requestId, event.duration, event.commandName);
    });

    this.client.on('commandFailed', (event) => {
      console.error(`MongoDB command failed: ${event.commandName}`, event.failure);
      this.trackCommandPerformance(event.requestId, event.duration, event.commandName, true);
    });

    // Error handling
    this.client.on('error', (error) => {
      console.error('MongoDB client error:', error);
    });

    this.client.on('timeout', (error) => {
      console.error('MongoDB timeout:', error);
    });

    this.client.on('close', () => {
      console.log('MongoDB connection closed');
    });
  }

  private trackCommandPerformance(
    requestId: number, 
    duration: number, 
    commandName: string, 
    failed: boolean = false
  ): void {
    // Track slow queries
    if (duration > this.slowQueryThreshold) {
      console.warn(`Slow MongoDB query detected: ${commandName} took ${duration}ms`);
      
      if (!this.operationMetrics.has('slowQueries')) {
        this.operationMetrics.set('slowQueries', []);
      }
      
      const slowQueries = this.operationMetrics.get('slowQueries')!;
      slowQueries.push(duration);
      
      // Keep only last 100 slow queries
      if (slowQueries.length > 100) {
        slowQueries.shift();
      }
    }

    // Track command metrics
    const metricsKey = `command_${commandName}`;
    if (!this.operationMetrics.has(metricsKey)) {
      this.operationMetrics.set(metricsKey, []);
    }

    const commandMetrics = this.operationMetrics.get(metricsKey)!;
    commandMetrics.push(duration);

    // Keep only last 1000 measurements per command
    if (commandMetrics.length > 1000) {
      commandMetrics.shift();
    }
  }

  // High-performance collection access with caching
  getCollection<T extends Document = Document>(name: string): Collection<T> {
    if (!this.db) {
      throw new Error('MongoDB not connected. Call connect() first.');
    }
    return this.db.collection<T>(name);
  }

  // Optimized aggregation with performance tracking
  async performAggregation<T>(
    collectionName: string,
    pipeline: any[],
    options: any = {},
    operationName?: string
  ): Promise<T[]> {
    const startTime = Date.now();
    
    try {
      const collection = this.getCollection(collectionName);
      
      // Add performance optimizations
      const optimizedOptions = {
        allowDiskUse: true,
        maxTimeMS: 60000,        // 1 minute timeout
        batchSize: 1000,         // Optimal batch size
        ...options
      };

      const result = await collection.aggregate<T>(pipeline, optimizedOptions).toArray();
      
      const executionTime = Date.now() - startTime;
      
      // Track performance
      if (operationName) {
        this.trackOperationMetrics(operationName, executionTime);
      }

      // Log slow aggregations
      if (executionTime > this.slowQueryThreshold) {
        console.warn(`Slow aggregation: ${operationName || collectionName} took ${executionTime}ms`);
      }

      return result;
    } catch (error) {
      const executionTime = Date.now() - startTime;
      console.error(`Aggregation failed after ${executionTime}ms:`, error);
      throw error;
    }
  }

  // Bulk operations optimization
  async performBulkWrite(
    collectionName: string,
    operations: any[],
    options: any = {}
  ): Promise<any> {
    const collection = this.getCollection(collectionName);
    
    // Optimize bulk operations
    const optimizedOptions = {
      ordered: false,          // Unordered for better performance
      writeConcern: { w: 1 },  // Faster write concern for bulk operations
      ...options
    };

    return collection.bulkWrite(operations, optimizedOptions);
  }

  private trackOperationMetrics(operationName: string, executionTime: number): void {
    if (!this.operationMetrics.has(operationName)) {
      this.operationMetrics.set(operationName, []);
    }

    const metrics = this.operationMetrics.get(operationName)!;
    metrics.push(executionTime);

    // Keep only last 100 measurements
    if (metrics.length > 100) {
      metrics.shift();
    }
  }

  // Comprehensive metrics collection
  async getMetrics(): Promise<MongoMetrics> {
    if (!this.db) {
      throw new Error('MongoDB not connected');
    }

    try {
      // Get connection pool stats
      const serverStatus = await this.db.admin().serverStatus();
      const connections = serverStatus.connections;

      // Calculate average response time
      let totalTime = 0;
      let totalOps = 0;

      for (const [key, times] of this.operationMetrics.entries()) {
        if (!key.startsWith('command_') && key !== 'slowQueries') {
          totalTime += times.reduce((sum, time) => sum + time, 0);
          totalOps += times.length;
        }
      }

      const averageResponseTime = totalOps > 0 ? totalTime / totalOps : 0;
      const slowQueries = this.operationMetrics.get('slowQueries')?.length || 0;

      return {
        totalConnections: connections.current || 0,
        availableConnections: connections.available || 0,
        activeOperations: connections.active || 0,
        averageResponseTime: Math.round(averageResponseTime),
        slowQueries
      };
    } catch (error) {
      console.error('Error collecting MongoDB metrics:', error);
      return {
        totalConnections: 0,
        availableConnections: 0,
        activeOperations: 0,
        averageResponseTime: 0,
        slowQueries: 0
      };
    }
  }

  // Health check with detailed diagnostics
  async healthCheck(): Promise<{ healthy: boolean; details: any }> {
    try {
      if (!this.db) {
        return { healthy: false, details: { error: 'Not connected' } };
      }

      const startTime = Date.now();
      await this.db.admin().ping();
      const pingTime = Date.now() - startTime;

      const metrics = await this.getMetrics();
      
      const healthy = pingTime < 1000 && metrics.totalConnections > 0;

      return {
        healthy,
        details: {
          pingTime,
          ...metrics,
          timestamp: new Date().toISOString()
        }
      };
    } catch (error) {
      return {
        healthy: false,
        details: { error: error.message }
      };
    }
  }

  private startMetricsCollection(): void {
    setInterval(async () => {
      try {
        const metrics = await this.getMetrics();
        console.log('MongoDB Metrics:', metrics);

        // Alert on performance issues
        if (metrics.availableConnections < 10) {
          console.warn('⚠️  Low available MongoDB connections');
        }

        if (metrics.averageResponseTime > 500) {
          console.warn('⚠️  High MongoDB response time detected');
        }

        if (metrics.slowQueries > 10) {
          console.warn('⚠️  High number of slow MongoDB queries');
        }
      } catch (error) {
        console.error('Error collecting MongoDB metrics:', error);
      }
    }, 30000); // Every 30 seconds
  }

  async disconnect(): Promise<void> {
    if (this.client) {
      await this.client.close();
      console.log('✅ Disconnected from MongoDB');
    }
  }
}

// Usage example
const mongoService = new OptimizedMongoDBService();

// Graceful shutdown
process.on('SIGINT', async () => {
  console.log('Shutting down MongoDB connection...');
  await mongoService.disconnect();
  process.exit(0);
});

export { mongoService, OptimizedMongoDBService };
```

## 📈 Performance Monitoring and Analysis

### Real-time Performance Monitoring

#### Comprehensive Monitoring Dashboard
```typescript
// Performance monitoring service for both databases
interface PerformanceMetrics {
  timestamp: Date;
  database: 'postgresql' | 'mongodb';
  metrics: {
    queryResponseTime: number;
    connectionsActive: number;
    connectionsIdle: number;
    slowQueries: number;
    errorRate: number;
    throughput: number;
  };
}

class DatabasePerformanceMonitor {
  private metrics: PerformanceMetrics[] = [];
  private alertThresholds = {
    responseTime: 1000,      // 1 second
    errorRate: 0.05,         // 5%
    connectionUtilization: 0.8 // 80%
  };

  async collectPostgreSQLMetrics(): Promise<PerformanceMetrics> {
    const startTime = Date.now();
    
    // Test query performance
    await this.testQuery('postgresql');
    const responseTime = Date.now() - startTime;

    // Get connection stats
    const connectionStats = await this.getPostgreSQLConnectionStats();
    
    // Get slow query count
    const slowQueries = await this.getPostgreSQLSlowQueries();

    return {
      timestamp: new Date(),
      database: 'postgresql',
      metrics: {
        queryResponseTime: responseTime,
        connectionsActive: connectionStats.active,
        connectionsIdle: connectionStats.idle,
        slowQueries: slowQueries,
        errorRate: this.calculateErrorRate('postgresql'),
        throughput: this.calculateThroughput('postgresql')
      }
    };
  }

  async collectMongoDBMetrics(): Promise<PerformanceMetrics> {
    const startTime = Date.now();
    
    // Test query performance
    await this.testQuery('mongodb');
    const responseTime = Date.now() - startTime;

    // Get MongoDB server status
    const serverStatus = await this.getMongoDBServerStatus();

    return {
      timestamp: new Date(),
      database: 'mongodb',
      metrics: {
        queryResponseTime: responseTime,
        connectionsActive: serverStatus.connections.active,
        connectionsIdle: serverStatus.connections.available,
        slowQueries: serverStatus.opcounters.query,
        errorRate: this.calculateErrorRate('mongodb'),
        throughput: this.calculateThroughput('mongodb')
      }
    };
  }

  private async testQuery(database: 'postgresql' | 'mongodb'): Promise<void> {
    if (database === 'postgresql') {
      // Simple performance test query
      await pool.query('SELECT COUNT(*) FROM users WHERE created_at > NOW() - INTERVAL \'1 hour\'');
    } else {
      // MongoDB performance test
      await mongoService.getCollection('users').countDocuments({
        createdAt: { $gte: new Date(Date.now() - 60 * 60 * 1000) }
      });
    }
  }

  async startMonitoring(): Promise<void> {
    console.log('🔍 Starting database performance monitoring...');

    setInterval(async () => {
      try {
        // Collect metrics from both databases
        const [pgMetrics, mongoMetrics] = await Promise.all([
          this.collectPostgreSQLMetrics(),
          this.collectMongoDBMetrics()
        ]);

        this.metrics.push(pgMetrics, mongoMetrics);

        // Keep only last 1000 metrics entries
        if (this.metrics.length > 1000) {
          this.metrics.splice(0, this.metrics.length - 1000);
        }

        // Check for alerts
        this.checkAlerts(pgMetrics);
        this.checkAlerts(mongoMetrics);

        // Log summary
        console.log('📊 Performance Summary:', {
          postgresql: {
            responseTime: `${pgMetrics.metrics.queryResponseTime}ms`,
            connections: `${pgMetrics.metrics.connectionsActive}/${pgMetrics.metrics.connectionsActive + pgMetrics.metrics.connectionsIdle}`
          },
          mongodb: {
            responseTime: `${mongoMetrics.metrics.queryResponseTime}ms`,
            connections: `${mongoMetrics.metrics.connectionsActive}/${mongoMetrics.metrics.connectionsActive + mongoMetrics.metrics.connectionsIdle}`
          }
        });

      } catch (error) {
        console.error('Error collecting performance metrics:', error);
      }
    }, 60000); // Every minute
  }

  private checkAlerts(metrics: PerformanceMetrics): void {
    const { database, metrics: m } = metrics;

    // Response time alert
    if (m.queryResponseTime > this.alertThresholds.responseTime) {
      console.warn(`🚨 HIGH RESPONSE TIME ALERT: ${database} - ${m.queryResponseTime}ms`);
    }

    // Error rate alert
    if (m.errorRate > this.alertThresholds.errorRate) {
      console.warn(`🚨 HIGH ERROR RATE ALERT: ${database} - ${(m.errorRate * 100).toFixed(2)}%`);
    }

    // Connection utilization alert
    const totalConnections = m.connectionsActive + m.connectionsIdle;
    const utilization = m.connectionsActive / totalConnections;
    
    if (utilization > this.alertThresholds.connectionUtilization) {
      console.warn(`🚨 HIGH CONNECTION UTILIZATION ALERT: ${database} - ${(utilization * 100).toFixed(2)}%`);
    }
  }

  // Generate performance report
  generateReport(timeRange: 'hour' | 'day' | 'week' = 'hour'): any {
    const now = new Date();
    const timeRangeMs = {
      hour: 60 * 60 * 1000,
      day: 24 * 60 * 60 * 1000,
      week: 7 * 24 * 60 * 60 * 1000
    };

    const cutoff = new Date(now.getTime() - timeRangeMs[timeRange]);
    const recentMetrics = this.metrics.filter(m => m.timestamp >= cutoff);

    const postgresMetrics = recentMetrics.filter(m => m.database === 'postgresql');
    const mongoMetrics = recentMetrics.filter(m => m.database === 'mongodb');

    return {
      timeRange,
      generatedAt: now,
      postgresql: this.calculateSummaryStats(postgresMetrics),
      mongodb: this.calculateSummaryStats(mongoMetrics),
      comparison: this.comparePerformance(postgresMetrics, mongoMetrics)
    };
  }

  private calculateSummaryStats(metrics: PerformanceMetrics[]): any {
    if (metrics.length === 0) return null;

    const responseTimes = metrics.map(m => m.metrics.queryResponseTime);
    const errorRates = metrics.map(m => m.metrics.errorRate);
    const throughputs = metrics.map(m => m.metrics.throughput);

    return {
      count: metrics.length,
      responseTime: {
        avg: this.average(responseTimes),
        min: Math.min(...responseTimes),
        max: Math.max(...responseTimes),
        p95: this.percentile(responseTimes, 95),
        p99: this.percentile(responseTimes, 99)
      },
      errorRate: {
        avg: this.average(errorRates),
        max: Math.max(...errorRates)
      },
      throughput: {
        avg: this.average(throughputs),
        max: Math.max(...throughputs)
      }
    };
  }

  private comparePerformance(pgMetrics: PerformanceMetrics[], mongoMetrics: PerformanceMetrics[]): any {
    const pgStats = this.calculateSummaryStats(pgMetrics);
    const mongoStats = this.calculateSummaryStats(mongoMetrics);

    if (!pgStats || !mongoStats) return null;

    return {
      fasterResponseTime: pgStats.responseTime.avg < mongoStats.responseTime.avg ? 'postgresql' : 'mongodb',
      responseTimeDifference: Math.abs(pgStats.responseTime.avg - mongoStats.responseTime.avg),
      higherThroughput: pgStats.throughput.avg > mongoStats.throughput.avg ? 'postgresql' : 'mongodb',
      throughputDifference: Math.abs(pgStats.throughput.avg - mongoStats.throughput.avg),
      lowerErrorRate: pgStats.errorRate.avg < mongoStats.errorRate.avg ? 'postgresql' : 'mongodb'
    };
  }

  private average(numbers: number[]): number {
    return numbers.reduce((sum, n) => sum + n, 0) / numbers.length;
  }

  private percentile(numbers: number[], p: number): number {
    const sorted = numbers.sort((a, b) => a - b);
    const index = Math.ceil((p / 100) * sorted.length) - 1;
    return sorted[index];
  }

  // Additional helper methods...
  private async getPostgreSQLConnectionStats(): Promise<{active: number, idle: number}> {
    const result = await pool.query(`
      SELECT 
        count(*) FILTER (WHERE state = 'active') as active,
        count(*) FILTER (WHERE state = 'idle') as idle
      FROM pg_stat_activity 
      WHERE datname = current_database()
    `);
    
    return result.rows[0];
  }

  private async getPostgreSQLSlowQueries(): Promise<number> {
    const result = await pool.query(`
      SELECT count(*) as slow_queries
      FROM pg_stat_statements 
      WHERE mean_time > 1000  -- Queries slower than 1 second
    `);
    
    return parseInt(result.rows[0].slow_queries);
  }

  private async getMongoDBServerStatus(): Promise<any> {
    return await mongoService.getCollection('admin').db.admin().serverStatus();
  }

  private calculateErrorRate(database: string): number {
    // Implementation would track error rates over time
    // This is a simplified placeholder
    return Math.random() * 0.02; // 0-2% error rate
  }

  private calculateThroughput(database: string): number {
    // Implementation would track operations per second
    // This is a simplified placeholder
    return Math.random() * 1000 + 500; // 500-1500 ops/sec
  }
}

// Initialize monitoring
const performanceMonitor = new DatabasePerformanceMonitor();
performanceMonitor.startMonitoring();

export { performanceMonitor, DatabasePerformanceMonitor };
```

This comprehensive performance analysis provides detailed optimization strategies for both PostgreSQL and MongoDB, including configuration tuning, indexing strategies, query optimization, and real-time monitoring capabilities specifically tailored for EdTech applications.

---

⬅️ **[Previous: Comparison Analysis](./comparison-analysis.md)**  
➡️ **[Next: Security Considerations](./security-considerations.md)**  
🏠 **[Research Home](../../README.md)**

---

*Performance Analysis - Advanced optimization techniques and monitoring strategies for database systems*