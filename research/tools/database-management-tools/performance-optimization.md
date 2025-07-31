# Performance Optimization: Database Management Tools

## 🎯 Overview

This guide provides advanced performance optimization techniques for pgAdmin, MongoDB Compass, and Redis CLI in high-traffic EdTech environments. Strategies are tailored for Philippine licensure exam platforms serving thousands of concurrent users.

## 🗄️ PostgreSQL + pgAdmin Performance Optimization

### 📊 Query Performance Tuning

#### Index Optimization Strategies
```sql
-- Analyze current index usage
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan as index_scans,
    idx_tup_read as tuples_read,
    idx_tup_fetch as tuples_fetched
FROM pg_stat_user_indexes
WHERE idx_scan = 0
ORDER BY schemaname, tablename;

-- Create composite indexes for common query patterns
CREATE INDEX CONCURRENTLY idx_user_progress_composite 
ON user_progress (user_id, course_id, completion_percentage DESC);

-- Partial indexes for filtered queries
CREATE INDEX CONCURRENTLY idx_active_sessions 
ON user_sessions (user_id, expires_at) 
WHERE expires_at > CURRENT_TIMESTAMP;

-- Expression indexes for computed columns
CREATE INDEX CONCURRENTLY idx_user_full_name 
ON users (LOWER(first_name || ' ' || last_name));
```

#### Query Plan Optimization
```sql
-- Enable query plan analysis
SET work_mem = '256MB';  -- Increase for complex queries
SET effective_cache_size = '4GB';  -- Adjust based on system RAM

-- Analyze query performance
EXPLAIN (ANALYZE, BUFFERS, VERBOSE) 
SELECT u.email, c.title, up.completion_percentage
FROM users u
JOIN user_progress up ON u.id = up.user_id
JOIN courses c ON up.course_id = c.id
WHERE u.role = 'student' 
AND up.completion_percentage > 80
ORDER BY up.completion_percentage DESC
LIMIT 50;

-- Use CTEs for complex analytics
WITH high_performers AS (
    SELECT user_id, AVG(completion_percentage) as avg_score
    FROM user_progress
    GROUP BY user_id
    HAVING AVG(completion_percentage) > 85
),
course_difficulty AS (
    SELECT course_id, AVG(completion_percentage) as avg_completion
    FROM user_progress
    GROUP BY course_id
)
SELECT 
    u.email,
    hp.avg_score,
    COUNT(DISTINCT up.course_id) as courses_completed
FROM high_performers hp
JOIN users u ON hp.user_id = u.id
JOIN user_progress up ON hp.user_id = up.user_id
WHERE up.completion_percentage = 100
GROUP BY u.email, hp.avg_score
ORDER BY hp.avg_score DESC;
```

#### Connection Pooling Optimization
```python
# Advanced connection pooling configuration
import psycopg2.pool
from contextlib import contextmanager

class DatabaseManager:
    def __init__(self):
        self.pool = psycopg2.pool.ThreadedConnectionPool(
            minconn=10,          # Minimum connections
            maxconn=100,         # Maximum connections
            host='localhost',
            database='edtech_db',
            user='edtech_user',
            password='secure_password_123',
            # Performance optimization parameters
            options='-c default_transaction_isolation=read_committed'
        )
    
    @contextmanager
    def get_connection(self):
        conn = self.pool.getconn()
        try:
            yield conn
            conn.commit()
        except Exception:
            conn.rollback()
            raise
        finally:
            self.pool.putconn(conn)

# Usage example
db_manager = DatabaseManager()

def get_user_analytics(user_id: int):
    with db_manager.get_connection() as conn:
        with conn.cursor() as cursor:
            cursor.execute("""
                SELECT 
                    COUNT(*) as total_courses,
                    AVG(completion_percentage) as avg_completion,
                    SUM(CASE WHEN completion_percentage = 100 THEN 1 ELSE 0 END) as completed_courses
                FROM user_progress 
                WHERE user_id = %s
            """, (user_id,))
            return cursor.fetchone()
```

### 🔧 pgAdmin Configuration Optimization

#### Memory and Cache Settings
```ini
# postgresql.conf optimizations for EdTech workloads

# Memory configuration
shared_buffers = 2GB                    # 25% of system RAM
effective_cache_size = 6GB              # 75% of system RAM
work_mem = 256MB                        # For complex queries
maintenance_work_mem = 1GB              # For maintenance operations

# Query planner settings
random_page_cost = 1.1                  # SSD optimization
effective_io_concurrency = 200          # SSD concurrent I/O

# Checkpoint and WAL settings
checkpoint_completion_target = 0.9      # Spread checkpoint I/O
wal_buffers = 64MB                      # WAL buffer size
min_wal_size = 2GB                      # Minimum WAL size
max_wal_size = 8GB                      # Maximum WAL size

# Connection settings
max_connections = 200                   # Adjust based on application needs
```

#### Query Monitoring Setup
```sql
-- Enable pg_stat_statements for query analysis
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Configure statement tracking
ALTER SYSTEM SET pg_stat_statements.track = 'all';
ALTER SYSTEM SET pg_stat_statements.max = 10000;
ALTER SYSTEM SET pg_stat_statements.track_utility = on;

-- Create monitoring views
CREATE VIEW slow_queries AS
SELECT 
    query,
    calls,
    total_time,
    mean_time,
    rows,
    100.0 * shared_blks_hit / nullif(shared_blks_hit + shared_blks_read, 0) AS hit_percent
FROM pg_stat_statements
WHERE calls > 100
ORDER BY total_time DESC;

-- Automated performance alerts
CREATE OR REPLACE FUNCTION check_slow_queries()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.mean_time > 1000 THEN  -- Queries taking >1 second
        INSERT INTO performance_alerts (alert_type, query_text, mean_time, created_at)
        VALUES ('slow_query', NEW.query, NEW.mean_time, NOW());
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

## 🍃 MongoDB + Compass Performance Optimization

### 📋 Schema Optimization

#### Efficient Document Design
```javascript
// Optimized lesson document structure
{
  "_id": ObjectId("..."),
  "courseId": "bar_exam_2024",
  "title": "Constitutional Law Fundamentals",
  
  // Embed frequently accessed data
  "summary": {
    "duration": 3600,
    "difficulty": "intermediate",
    "estimatedTime": 60,
    "viewCount": 1250,
    "avgRating": 4.7
  },
  
  // Reference infrequently accessed data
  "instructorId": ObjectId("..."),
  "fullContentId": ObjectId("..."),
  
  // Optimize for queries
  "tags": ["constitutional-law", "fundamentals", "bar-exam"],
  "categories": ["law", "philippines", "licensure"],
  
  // Pre-calculated fields for performance
  "searchText": "constitutional law fundamentals philippines bar exam",
  "popularityScore": 85.4,
  
  // Efficient timestamp handling
  "created": ISODate("2024-01-15T10:00:00Z"),
  "lastModified": ISODate("2024-01-15T10:00:00Z")
}

// User progress optimization - embedded vs referenced
{
  "_id": ObjectId("..."),
  "userId": ObjectId("..."),
  "courseId": "bar_exam_2024",
  
  // Embed for fast access
  "currentProgress": {
    "currentLesson": "lesson_005",
    "overallCompletion": 45.2,
    "lastActivity": ISODate("2024-01-15T16:20:00Z"),
    "streak": 7
  },
  
  // Reference detailed progress for analytics
  "detailedProgressRef": ObjectId("...")
}
```

#### Index Strategy for EdTech Workloads
```javascript
// Compound indexes for common query patterns
db.lessons.createIndex({
  "courseId": 1,
  "summary.difficulty": 1,
  "summary.popularityScore": -1
});

// Text search optimization
db.lessons.createIndex({
  "title": "text",
  "searchText": "text",
  "tags": "text"
}, {
  weights: {
    "title": 10,
    "searchText": 5,
    "tags": 1
  },
  name: "lesson_search_index"
});

// Sparse indexes for optional fields
db.lessons.createIndex(
  { "summary.avgRating": -1 },
  { sparse: true }
);

// TTL index for temporary data
db.userSessions.createIndex(
  { "expiresAt": 1 },
  { expireAfterSeconds: 0 }
);

// Partial indexes for active content
db.lessons.createIndex(
  { "courseId": 1, "created": -1 },
  { 
    partialFilterExpression: { 
      "status": "published",
      "summary.viewCount": { $gt: 10 }
    } 
  }
);
```

### 🚀 Aggregation Pipeline Optimization

#### Efficient Analytics Queries
```javascript
// Optimized course analytics pipeline
db.userProgress.aggregate([
  // Match early to reduce documents
  { $match: { 
    "courseId": "bar_exam_2024",
    "currentProgress.lastActivity": { 
      $gte: ISODate("2024-01-01T00:00:00Z") 
    }
  }},
  
  // Add computed fields
  { $addFields: {
    "completionBucket": {
      $switch: {
        branches: [
          { case: { $lt: ["$currentProgress.overallCompletion", 25] }, then: "0-25%" },
          { case: { $lt: ["$currentProgress.overallCompletion", 50] }, then: "25-50%" },
          { case: { $lt: ["$currentProgress.overallCompletion", 75] }, then: "50-75%" }
        ],
        default: "75-100%"
      }
    }
  }},
  
  // Group for analytics
  { $group: {
    "_id": {
      "completionBucket": "$completionBucket",
      "month": { $dateToString: { format: "%Y-%m", date: "$currentProgress.lastActivity" }}
    },
    "userCount": { $sum: 1 },
    "avgCompletion": { $avg: "$currentProgress.overallCompletion" },
    "totalSessions": { $sum: "$currentProgress.streak" }
  }},
  
  // Sort results
  { $sort: { "_id.month": -1, "_id.completionBucket": 1 }},
  
  // Limit for performance
  { $limit: 100 }
]);

// Real-time leaderboard aggregation
db.userProgress.aggregate([
  { $match: { 
    "courseId": "bar_exam_2024",
    "currentProgress.overallCompletion": { $gte: 50 }
  }},
  
  { $lookup: {
    from: "users",
    localField: "userId",
    foreignField: "_id",
    as: "user",
    pipeline: [
      { $project: { "name": 1, "avatar": 1 }}
    ]
  }},
  
  { $unwind: "$user" },
  
  { $project: {
    "userName": "$user.name",
    "avatar": "$user.avatar",
    "completion": "$currentProgress.overallCompletion",
    "streak": "$currentProgress.streak",
    "score": {
      $add: [
        { $multiply: ["$currentProgress.overallCompletion", 0.7] },
        { $multiply: ["$currentProgress.streak", 3] }
      ]
    }
  }},
  
  { $sort: { "score": -1 }},
  { $limit: 50 }
]);
```

#### Compass Performance Monitoring
```javascript
// Enable profiler for slow operations
db.setProfilingLevel(2, { slowms: 100 });

// Analyze index performance
db.lessons.aggregate([
  { $indexStats: {} },
  { $sort: { "accesses.ops": -1 }}
]);

// Monitor collection statistics
db.runCommand({ collStats: "lessons" });

// Check query execution plans
db.lessons.find({ 
  "courseId": "bar_exam_2024",
  "summary.difficulty": "advanced" 
}).explain("executionStats");
```

## ⚡ Redis + CLI Performance Optimization

### 🏗️ Data Structure Optimization

#### Memory-Efficient Data Types
```bash
# Use Hashes for objects to save memory
# Instead of multiple string keys
SET user:12345:name "Juan Dela Cruz"
SET user:12345:email "juan@example.com"
SET user:12345:score 95.5

# Use single Hash (saves ~40% memory)
HMSET user:12345 name "Juan Dela Cruz" email "juan@example.com" score 95.5

# Optimize sorted sets for leaderboards
# Store user scores with efficient key structure
ZADD course:101:leaderboard:2024-01 95.5 user:12345 88.2 user:67890

# Use bit operations for tracking
# Track daily active users efficiently
SETBIT daily_active:2024-01-15 12345 1
SETBIT daily_active:2024-01-15 67890 1
BITCOUNT daily_active:2024-01-15  # Count active users

# HyperLogLog for unique count approximation
PFADD unique_visitors:2024-01-15 user:12345 user:67890 user:54321
PFCOUNT unique_visitors:2024-01-15  # Approximate unique count
```

#### Cache Strategy Implementation
```python
import redis
import json
import hashlib
from typing import Any, Optional
from datetime import timedelta

class EdTechCache:
    def __init__(self):
        self.redis_client = redis.Redis(
            host='localhost',
            port=6379,
            password='secure_redis_123',
            decode_responses=True,
            socket_connect_timeout=5,
            socket_timeout=5,
            retry_on_timeout=True,
            health_check_interval=30
        )
    
    def cache_user_progress(self, user_id: int, course_id: str, progress: dict):
        """Cache user progress with optimized structure."""
        key = f"progress:{user_id}:{course_id}"
        
        # Use Hash for structured data
        pipe = self.redis_client.pipeline()
        pipe.hset(key, mapping={
            'completion': progress['completion'],
            'current_lesson': progress['current_lesson'],
            'last_activity': progress['last_activity'].isoformat(),
            'streak': progress['streak']
        })
        pipe.expire(key, 3600)  # 1 hour expiry
        pipe.execute()
    
    def cache_lesson_content(self, lesson_id: str, content: dict):
        """Cache lesson content with compression."""
        key = f"lesson:{lesson_id}"
        
        # Compress JSON for large content
        compressed_content = json.dumps(content, separators=(',', ':'))
        
        self.redis_client.setex(
            key, 
            timedelta(hours=24),  # 24 hour expiry
            compressed_content
        )
    
    def update_leaderboard(self, course_id: str, user_id: int, score: float):
        """Atomic leaderboard update."""
        lua_script = """
        local leaderboard_key = KEYS[1]
        local user_key = KEYS[2]
        local analytics_key = KEYS[3]
        local user_id = ARGV[1]
        local score = tonumber(ARGV[2])
        
        -- Update leaderboard
        redis.call('ZADD', leaderboard_key, score, user_id)
        
        -- Update user stats
        redis.call('HINCRBYFLOAT', user_key, 'total_score', score)
        redis.call('HINCRBY', user_key, 'quiz_count', 1)
        
        -- Update course analytics
        redis.call('HINCRBY', analytics_key, 'total_submissions', 1)
        redis.call('HINCRBYFLOAT', analytics_key, 'total_score', score)
        
        return redis.call('ZREVRANK', leaderboard_key, user_id)
        """
        
        return self.redis_client.eval(
            lua_script,
            3,
            f"leaderboard:{course_id}",
            f"user_stats:{user_id}",
            f"course_analytics:{course_id}",
            user_id,
            score
        )
    
    def get_trending_content(self, limit: int = 10):
        """Get trending content using sorted sets."""
        return self.redis_client.zrevrange(
            "trending:content",
            0, limit - 1,
            withscores=True
        )
```

### 📊 Redis Performance Monitoring

#### Memory Optimization Commands
```bash
# Analyze memory usage
MEMORY USAGE lesson:12345
MEMORY STATS

# Find large keys
redis-cli --bigkeys

# Memory optimization settings
CONFIG SET maxmemory 4gb
CONFIG SET maxmemory-policy allkeys-lru

# Enable compression for string values
CONFIG SET list-compress-depth 1
CONFIG SET set-max-intset-entries 512

# Optimize hash tables
CONFIG SET hash-max-ziplist-entries 512
CONFIG SET hash-max-ziplist-value 64
```

#### Performance Monitoring Script
```bash
#!/bin/bash
# redis_monitor.sh

echo "=== Redis Performance Monitor ==="
date

# Memory usage
echo "Memory Usage:"
redis-cli INFO memory | grep used_memory_human
redis-cli INFO memory | grep used_memory_peak_human

# Operations per second
echo "Operations/sec:"
redis-cli INFO stats | grep instantaneous_ops_per_sec

# Keyspace statistics
echo "Keyspace:"
redis-cli INFO keyspace

# Slow log analysis
echo "Slow queries (>10ms):"
redis-cli SLOWLOG GET 5

# Connection statistics
echo "Connections:"
redis-cli INFO clients | grep connected_clients

# Hit ratio analysis
echo "Cache Hit Ratio:"
redis-cli INFO stats | grep keyspace_hits
redis-cli INFO stats | grep keyspace_misses

# Memory fragmentation
echo "Memory Fragmentation:"
redis-cli INFO memory | grep mem_fragmentation_ratio
```

### 🔧 Advanced Redis Optimization

#### Lua Scripts for Complex Operations
```lua
-- Efficient session management with cleanup
local function manage_user_session(user_id, session_data, max_sessions)
    local session_key = "sessions:user:" .. user_id
    local active_sessions_key = "active_sessions:" .. user_id
    
    -- Clean old sessions
    local old_sessions = redis.call('ZRANGEBYSCORE', active_sessions_key, 0, tonumber(ARGV[3]) - 3600)
    for i, session_id in ipairs(old_sessions) do
        redis.call('DEL', session_key .. ":" .. session_id)
    end
    redis.call('ZREMRANGEBYSCORE', active_sessions_key, 0, tonumber(ARGV[3]) - 3600)
    
    -- Check session limit
    local session_count = redis.call('ZCARD', active_sessions_key)
    if session_count >= max_sessions then
        -- Remove oldest session
        local oldest = redis.call('ZRANGE', active_sessions_key, 0, 0)
        if #oldest > 0 then
            redis.call('DEL', session_key .. ":" .. oldest[1])
            redis.call('ZREM', active_sessions_key, oldest[1])
        end
    end
    
    -- Add new session
    local session_id = ARGV[1]
    redis.call('SETEX', session_key .. ":" .. session_id, 3600, ARGV[2])
    redis.call('ZADD', active_sessions_key, tonumber(ARGV[3]), session_id)
    
    return session_id
end

-- Rate limiting with sliding window
local function rate_limit_check(key, limit, window_size, current_time)
    -- Remove expired entries
    redis.call('ZREMRANGEBYSCORE', key, 0, current_time - window_size)
    
    -- Check current count
    local current_count = redis.call('ZCARD', key)
    if current_count < limit then
        -- Add current request
        redis.call('ZADD', key, current_time, current_time)
        redis.call('EXPIRE', key, window_size)
        return 1
    else
        return 0
    end
end
```

## 🔄 Cross-Database Performance Integration

### 📊 Unified Monitoring Dashboard

#### Performance Metrics Collection
```python
import psycopg2
import pymongo
import redis
import time
from datetime import datetime
from typing import Dict, Any

class DatabasePerformanceMonitor:
    def __init__(self):
        self.postgres = psycopg2.connect(
            host='localhost',
            database='edtech_db',
            user='edtech_user',
            password='secure_password_123'
        )
        self.mongodb = pymongo.MongoClient('mongodb://admin:secure_mongo_123@localhost:27017/')
        self.redis_client = redis.Redis(host='localhost', port=6379, password='secure_redis_123')
    
    def collect_postgres_metrics(self) -> Dict[str, Any]:
        """Collect PostgreSQL performance metrics."""
        with self.postgres.cursor() as cursor:
            metrics = {}
            
            # Connection count
            cursor.execute("SELECT count(*) FROM pg_stat_activity;")
            metrics['connections'] = cursor.fetchone()[0]
            
            # Query performance
            cursor.execute("""
                SELECT 
                    calls,
                    total_time,
                    mean_time,
                    rows
                FROM pg_stat_statements
                ORDER BY total_time DESC
                LIMIT 1;
            """)
            result = cursor.fetchone()
            if result:
                metrics['top_query'] = {
                    'calls': result[0],
                    'total_time': result[1],
                    'mean_time': result[2],
                    'rows': result[3]
                }
            
            # Database size
            cursor.execute("SELECT pg_size_pretty(pg_database_size('edtech_db'));")
            metrics['database_size'] = cursor.fetchone()[0]
            
            return metrics
    
    def collect_mongodb_metrics(self) -> Dict[str, Any]:
        """Collect MongoDB performance metrics."""
        db = self.mongodb.edtech_content
        
        # Server status
        server_status = db.command('serverStatus')
        
        metrics = {
            'connections': server_status['connections']['current'],
            'operations': {
                'insert': server_status['opcounters']['insert'],
                'query': server_status['opcounters']['query'],
                'update': server_status['opcounters']['update'],
                'delete': server_status['opcounters']['delete']
            },
            'memory': server_status['mem'],
            'collection_stats': {}
        }
        
        # Collection statistics
        for collection_name in ['lessons', 'userProgress', 'quizzes']:
            stats = db.command('collStats', collection_name)
            metrics['collection_stats'][collection_name] = {
                'count': stats['count'],
                'size': stats['size'],
                'avgObjSize': stats['avgObjSize']
            }
        
        return metrics
    
    def collect_redis_metrics(self) -> Dict[str, Any]:
        """Collect Redis performance metrics."""
        info = self.redis_client.info()
        
        return {
            'memory': {
                'used': info['used_memory_human'],
                'peak': info['used_memory_peak_human'],
                'fragmentation_ratio': info['mem_fragmentation_ratio']
            },
            'stats': {
                'ops_per_sec': info['instantaneous_ops_per_sec'],
                'keyspace_hits': info['keyspace_hits'],
                'keyspace_misses': info['keyspace_misses'],
                'connected_clients': info['connected_clients']
            },
            'keyspace': info.get('db0', {})
        }
    
    def generate_performance_report(self) -> Dict[str, Any]:
        """Generate comprehensive performance report."""
        return {
            'timestamp': datetime.now().isoformat(),
            'postgresql': self.collect_postgres_metrics(),
            'mongodb': self.collect_mongodb_metrics(),
            'redis': self.collect_redis_metrics()
        }
```

### 🚀 Automated Optimization Scripts

#### Performance Optimization Automation
```bash
#!/bin/bash
# optimize_databases.sh

echo "=== Database Optimization Script ==="
date

# PostgreSQL optimization
echo "Optimizing PostgreSQL..."
psql -h localhost -U edtech_user -d edtech_db << 'EOF'
-- Update table statistics
ANALYZE;

-- Reindex fragmented indexes
REINDEX INDEX CONCURRENTLY idx_user_progress_composite;

-- Clean up dead tuples
VACUUM (ANALYZE, VERBOSE) user_progress;
VACUUM (ANALYZE, VERBOSE) users;
VACUUM (ANALYZE, VERBOSE) courses;

-- Update configuration for current workload
SELECT pg_reload_conf();
EOF

# MongoDB optimization
echo "Optimizing MongoDB..."
mongosh --host localhost --port 27017 << 'EOF'
use edtech_content;

// Rebuild indexes
db.lessons.reIndex();
db.userProgress.reIndex();
db.quizzes.reIndex();

// Compact collections
db.runCommand({compact: 'lessons'});

// Update statistics
db.lessons.updateMany({}, {$currentDate: {lastOptimized: true}});
EOF

# Redis optimization
echo "Optimizing Redis..."
redis-cli << 'EOF'
# Rewrite AOF file
BGREWRITEAOF

# Save current state
BGSAVE

# Clear expired keys
EVAL "return redis.call('DEL', unpack(redis.call('KEYS', ARGV[1])))" 0 "*:expired:*"

# Get memory info after optimization
INFO memory
EOF

echo "Optimization completed at $(date)"
```

## 🔗 Navigation

- **Previous**: [Comparison Analysis](./comparison-analysis.md)
- **Next**: [Security Considerations](./security-considerations.md)
- **Home**: [Database Management Tools Research](./README.md)

---

*This performance optimization guide provides advanced techniques for maximizing database management tool efficiency in high-traffic EdTech environments.*