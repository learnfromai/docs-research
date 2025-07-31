# Best Practices: Database Management Tools

## 🎯 Overview

This guide outlines best practices for using pgAdmin, MongoDB Compass, and Redis CLI in EdTech development workflows. Recommendations are based on industry standards and optimized for international remote development teams.

## 🗄️ pgAdmin Best Practices

### 🔧 Configuration Optimization

#### Connection Management
```python
# Use connection pooling in application code
import psycopg2.pool

# Create connection pool
connection_pool = psycopg2.pool.ThreadedConnectionPool(
    minconn=1,
    maxconn=20,
    host='localhost',
    database='edtech_db',
    user='edtech_user',
    password='secure_password_123'
)

# Best practice: Always use prepared statements
def get_user_progress(user_id, course_id):
    conn = connection_pool.getconn()
    try:
        cursor = conn.cursor()
        cursor.execute(
            "SELECT completion_percentage FROM user_progress WHERE user_id=%s AND course_id=%s",
            (user_id, course_id)
        )
        return cursor.fetchone()
    finally:
        connection_pool.putconn(conn)
```

#### Query Optimization
```sql
-- Best Practice 1: Use indexes effectively
EXPLAIN ANALYZE SELECT * FROM users WHERE email = 'student@example.com';

-- Best Practice 2: Avoid SELECT * in production
SELECT id, email, first_name, last_name FROM users WHERE role = 'student';

-- Best Practice 3: Use CTEs for complex queries
WITH course_stats AS (
    SELECT 
        course_id,
        COUNT(*) as enrolled_count,
        AVG(completion_percentage) as avg_completion
    FROM user_progress
    GROUP BY course_id
)
SELECT 
    c.title,
    cs.enrolled_count,
    cs.avg_completion
FROM courses c
JOIN course_stats cs ON c.id = cs.course_id
WHERE cs.enrolled_count > 10;

-- Best Practice 4: Use LIMIT for large result sets
SELECT * FROM user_activity 
ORDER BY created_at DESC 
LIMIT 50 OFFSET 0;
```

#### Schema Design Best Practices
```sql
-- Use appropriate data types
CREATE TABLE user_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    session_token VARCHAR(255) UNIQUE NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Add constraints for data integrity
    CONSTRAINT valid_expiry CHECK (expires_at > created_at)
);

-- Create indexes for foreign keys and search columns
CREATE INDEX CONCURRENTLY idx_user_sessions_user_id ON user_sessions(user_id);
CREATE INDEX CONCURRENTLY idx_user_sessions_expires_at ON user_sessions(expires_at);
CREATE INDEX CONCURRENTLY idx_user_sessions_token ON user_sessions(session_token);
```

### 📊 Monitoring and Maintenance

#### Performance Monitoring Queries
```sql
-- Monitor slow queries
SELECT 
    query,
    calls,
    total_time,
    mean_time,
    rows
FROM pg_stat_statements 
ORDER BY total_time DESC 
LIMIT 10;

-- Check index usage
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch
FROM pg_stat_user_indexes
WHERE idx_scan = 0;

-- Monitor connection counts
SELECT 
    state,
    COUNT(*) as connection_count
FROM pg_stat_activity
GROUP BY state;
```

#### Backup and Recovery
```bash
# Daily backup with compression
pg_dump -h localhost -U edtech_user -d edtech_db | gzip > /backups/edtech_$(date +%Y%m%d).sql.gz

# Point-in-time recovery setup
# Enable WAL archiving in postgresql.conf:
# wal_level = replica
# archive_mode = on
# archive_command = 'cp %p /var/lib/postgresql/wal_archive/%f'
```

## 🍃 MongoDB Compass Best Practices

### 📋 Schema Design Excellence

#### Document Structure Best Practices
```javascript
// Good: Normalized reference for frequently updated data
{
  "_id": ObjectId("..."),
  "courseId": "bar_exam_2024",
  "title": "Constitutional Law Fundamentals",
  "instructorId": ObjectId("..."), // Reference to instructor
  "content": {
    "type": "video",
    "videoUrl": "https://cdn.example.com/video123",
    "duration": 3600,
    "transcripts": [
      {
        "language": "en-PH",
        "url": "https://cdn.example.com/transcript123_en.vtt"
      },
      {
        "language": "tl-PH",
        "url": "https://cdn.example.com/transcript123_tl.vtt"
      }
    ]
  },
  "metadata": {
    "difficulty": "intermediate",
    "estimatedTime": 60,
    "prerequisites": ["constitutional_basics"],
    "learningObjectives": [
      "Understand fundamental constitutional principles",
      "Analyze constitutional provisions"
    ]
  },
  "tags": ["constitutional-law", "fundamentals", "philippines"],
  "created": ISODate("2024-01-15T10:00:00Z"),
  "updated": ISODate("2024-01-15T10:00:00Z")
}

// Good: Embedded documents for tightly coupled data
{
  "_id": ObjectId("..."),
  "userId": ObjectId("..."),
  "courseId": "bar_exam_2024",
  "progress": {
    "completedLessons": [
      {
        "lessonId": "lesson_001",
        "completedAt": ISODate("2024-01-10T14:30:00Z"),
        "score": 85.5,
        "timeSpent": 75
      }
    ],
    "currentLesson": "lesson_002",
    "overallCompletion": 45.2,
    "totalTimeSpent": 450
  },
  "lastActivity": ISODate("2024-01-15T16:20:00Z")
}
```

#### Index Strategy
```javascript
// Create compound indexes for common query patterns
db.lessons.createIndex({ 
  "courseId": 1, 
  "metadata.difficulty": 1, 
  "created": -1 
});

// Text index for search functionality
db.lessons.createIndex({ 
  "title": "text", 
  "content.transcript": "text", 
  "tags": "text" 
});

// Partial index for active courses only
db.lessons.createIndex(
  { "courseId": 1, "created": -1 },
  { 
    partialFilterExpression: { 
      "status": "published" 
    } 
  }
);

// TTL index for temporary data
db.userSessions.createIndex(
  { "expiresAt": 1 },
  { expireAfterSeconds: 0 }
);
```

### 🔍 Query Optimization

#### Efficient Query Patterns
```javascript
// Use projection to limit returned fields
db.lessons.find(
  { "courseId": "bar_exam_2024" },
  { "title": 1, "metadata.estimatedTime": 1, "created": 1 }
);

// Use aggregation for complex analytics
db.userProgress.aggregate([
  { $match: { "courseId": "bar_exam_2024" } },
  { $group: {
    "_id": "$metadata.difficulty",
    "avgCompletion": { $avg: "$progress.overallCompletion" },
    "userCount": { $sum: 1 },
    "totalTimeSpent": { $sum: "$progress.totalTimeSpent" }
  }},
  { $sort: { "avgCompletion": -1 } }
]);

// Use $lookup for joining collections efficiently
db.lessons.aggregate([
  { $match: { "courseId": "bar_exam_2024" } },
  { $lookup: {
    from: "instructors",
    localField: "instructorId",
    foreignField: "_id",
    as: "instructor"
  }},
  { $unwind: "$instructor" },
  { $project: {
    "title": 1,
    "instructorName": "$instructor.name",
    "metadata.difficulty": 1
  }}
]);
```

#### Performance Monitoring
```javascript
// Enable profiler for slow operations
db.setProfilingLevel(2, { slowms: 100 });

// Analyze query performance
db.system.profile.find().limit(5).sort({ ts: -1 }).pretty();

// Check index usage
db.lessons.find({ "courseId": "bar_exam_2024" }).explain("executionStats");
```

## ⚡ Redis CLI Best Practices

### 🏗️ Data Structure Selection

#### Choose Appropriate Data Types
```bash
# Use Hashes for objects with multiple fields
HSET user:12345 name "Juan Dela Cruz" email "juan@example.com" role "student"
HGET user:12345 email
HMGET user:12345 name role

# Use Sets for unique collections
SADD course:101:enrolled_users user:12345 user:67890 user:54321
SISMEMBER course:101:enrolled_users user:12345
SCARD course:101:enrolled_users

# Use Sorted Sets for rankings and leaderboards
ZADD course:101:leaderboard 95.5 user:12345 88.2 user:67890 92.1 user:54321
ZREVRANGE course:101:leaderboard 0 9 WITHSCORES
ZRANK course:101:leaderboard user:12345

# Use Lists for message queues and activity feeds
LPUSH user:12345:notifications "New lesson available in Constitutional Law"
LRANGE user:12345:notifications 0 4
LTRIM user:12345:notifications 0 9  # Keep only latest 10 notifications
```

#### Memory Optimization
```bash
# Use appropriate expiration times
SETEX session:user:12345 3600 "session_data"  # 1 hour expiry
EXPIRE user:12345:cache 7200  # 2 hours expiry

# Use efficient serialization
# Good: Use JSON for complex objects
SET lesson:456 '{"title":"Constitutional Law","duration":3600}'

# Better: Use Hash for frequently accessed fields
HSET lesson:456 title "Constitutional Law" duration 3600 difficulty "intermediate"

# Use memory-efficient commands
# Instead of KEYS pattern (expensive)
KEYS user:*

# Use SCAN for production (memory efficient)
SCAN 0 MATCH user:* COUNT 10
```

### 🚀 Performance Optimization

#### Connection Management
```python
import redis
import redis.connection

# Use connection pooling
pool = redis.ConnectionPool(
    host='localhost',
    port=6379,
    password='secure_redis_123',
    db=0,
    max_connections=20,
    socket_connect_timeout=5,
    socket_timeout=5
)

redis_client = redis.Redis(connection_pool=pool)

# Use pipeline for multiple operations
def update_user_activity(user_id, course_id, lesson_id, score):
    pipe = redis_client.pipeline()
    pipe.hset(f"user:{user_id}:current", "course", course_id, "lesson", lesson_id)
    pipe.zadd(f"course:{course_id}:leaderboard", {f"user:{user_id}": score})
    pipe.incr(f"stats:daily:active_users:{datetime.now().strftime('%Y-%m-%d')}")
    pipe.execute()
```

#### Lua Scripts for Atomic Operations
```lua
-- Rate limiting script
local key = KEYS[1]
local limit = tonumber(ARGV[1])
local window = tonumber(ARGV[2])

local current = redis.call('GET', key)
if current == false then
    redis.call('SETEX', key, window, 1)
    return 1
elseif tonumber(current) < limit then
    return redis.call('INCR', key)
else
    return 0
end

-- User progress update with leaderboard
local userId = ARGV[1]
local courseId = ARGV[2]
local lessonId = ARGV[3]
local score = tonumber(ARGV[4])

-- Update user progress
local progressKey = "user:" .. userId .. ":progress:" .. courseId
redis.call("HSET", progressKey, lessonId, score)

-- Update leaderboard
local leaderboardKey = "course:" .. courseId .. ":leaderboard"
redis.call("ZADD", leaderboardKey, score, "user:" .. userId)

-- Update analytics
local analyticsKey = "course:analytics:" .. courseId
redis.call("HINCRBY", analyticsKey, "total_completions", 1)
redis.call("HINCRBY", analyticsKey, "total_score", score)

return "OK"
```

### 📊 Monitoring and Maintenance

```bash
# Monitor performance
INFO stats
INFO memory
INFO clients

# Monitor slow queries
SLOWLOG GET 10
CONFIG SET slowlog-log-slower-than 10000  # 10ms threshold

# Memory analysis
MEMORY USAGE lesson:456
MEMORY STATS

# Database maintenance
BGREWRITEAOF  # Rewrite AOF file
LASTSAVE      # Check last save time
```

## 🔐 Security Best Practices

### 🛡️ Authentication and Authorization

#### PostgreSQL Security
```sql
-- Create role-based access
CREATE ROLE edtech_read_only;
GRANT CONNECT ON DATABASE edtech_db TO edtech_read_only;
GRANT USAGE ON SCHEMA public TO edtech_read_only;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO edtech_read_only;

-- Row-level security for multi-tenant data
ALTER TABLE user_progress ENABLE ROW LEVEL SECURITY;

CREATE POLICY user_progress_policy ON user_progress
FOR ALL TO edtech_app_user
USING (user_id = current_setting('app.current_user_id')::integer);
```

#### MongoDB Security
```javascript
// Create user with limited permissions
db.createUser({
  user: "edtech_readonly",
  pwd: "readonly_secure_password",
  roles: [
    { role: "read", db: "edtech_content" }
  ]
});

// Use field-level encryption for sensitive data
const clientEncryption = new ClientEncryption(keyVault, {
  kmsProviders: {
    local: {
      key: masterKey
    }
  }
});
```

#### Redis Security
```bash
# Use strong authentication
CONFIG SET requirepass "very_secure_redis_password_2024"

# Rename dangerous commands
CONFIG SET rename-command FLUSHDB ""
CONFIG SET rename-command FLUSHALL ""
CONFIG SET rename-command CONFIG "MY_CONFIG_COMMAND"

# Use TLS encryption
# In redis.conf:
# tls-port 6380
# tls-cert-file /path/to/redis.crt
# tls-key-file /path/to/redis.key
```

## 🌍 International Development Best Practices

### 🕐 Time Zone Handling
```sql
-- PostgreSQL: Always use timestamptz
CREATE TABLE user_activity (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    activity_type VARCHAR(50),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Store user timezone preference
ALTER TABLE users ADD COLUMN timezone VARCHAR(50) DEFAULT 'Asia/Manila';
```

```javascript
// MongoDB: Use ISODate for UTC storage
{
  "userId": ObjectId("..."),
  "loginTime": ISODate("2024-01-15T10:00:00Z"),  // Always UTC
  "userTimezone": "Asia/Manila",
  "localLoginTime": "2024-01-15T18:00:00+08:00"  // Display format
}
```

### 🌐 Multi-language Support
```sql
-- PostgreSQL: Translatable content structure
CREATE TABLE course_translations (
    id SERIAL PRIMARY KEY,
    course_id INTEGER REFERENCES courses(id),
    language_code VARCHAR(5) NOT NULL,  -- en-US, en-PH, tl-PH
    title VARCHAR(255) NOT NULL,
    description TEXT,
    UNIQUE(course_id, language_code)
);
```

```javascript
// MongoDB: Embedded translations
{
  "_id": ObjectId("..."),
  "courseId": "bar_exam_2024",
  "content": {
    "en-US": {
      "title": "Constitutional Law Fundamentals",
      "description": "Learn the basics of constitutional law"
    },
    "en-PH": {
      "title": "Constitutional Law Fundamentals",
      "description": "Learn the basics of Philippine constitutional law"
    },
    "tl-PH": {
      "title": "Mga Pangunahing Prinsipyo ng Saligang Batas",
      "description": "Matuto ng mga pangunahing kaalaman sa saligang batas"
    }
  }
}
```

## 🔄 Backup and Disaster Recovery

### 📋 Automated Backup Strategy
```bash
#!/bin/bash
# comprehensive_backup.sh

DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_ROOT="/backups/$DATE"
mkdir -p $BACKUP_ROOT

# PostgreSQL backup with custom format
pg_dump -h localhost -U edtech_user -d edtech_db -Fc > $BACKUP_ROOT/postgres_backup.custom

# MongoDB backup
mongodump --host localhost --port 27017 --out $BACKUP_ROOT/mongodb_backup

# Redis backup
redis-cli -h localhost -p 6379 -a secure_redis_123 --rdb $BACKUP_ROOT/redis_backup.rdb

# Compress and upload to cloud storage
tar -czf $BACKUP_ROOT.tar.gz $BACKUP_ROOT
aws s3 cp $BACKUP_ROOT.tar.gz s3://edtech-backups/

# Clean up old backups (keep last 7 days)
find /backups -name "*.tar.gz" -mtime +7 -delete
```

### 🔄 Recovery Procedures
```bash
# PostgreSQL recovery
pg_restore -h localhost -U edtech_user -d edtech_db_restored /backups/postgres_backup.custom

# MongoDB recovery
mongorestore --host localhost --port 27017 /backups/mongodb_backup

# Redis recovery
redis-cli -h localhost -p 6379 -a secure_redis_123 --rdb /backups/redis_backup.rdb
```

## 📈 Performance Monitoring

### 🔍 Key Performance Indicators

#### PostgreSQL KPIs
```sql
-- Query performance metrics
SELECT 
    calls,
    total_time,
    mean_time,
    query
FROM pg_stat_statements 
WHERE calls > 100
ORDER BY total_time DESC 
LIMIT 10;

-- Connection and lock monitoring
SELECT 
    wait_event_type,
    wait_event,
    COUNT(*) as count
FROM pg_stat_activity 
WHERE state = 'active'
GROUP BY wait_event_type, wait_event;
```

#### MongoDB Monitoring
```javascript
// Database statistics
db.stats()

// Collection statistics
db.lessons.stats()

// Current operations
db.currentOp()

// Index usage statistics
db.lessons.aggregate([{ $indexStats: {} }])
```

#### Redis Monitoring
```bash
# Memory usage breakdown
INFO memory

# Command statistics
INFO commandstats

# Client connections
INFO clients

# Replication status
INFO replication
```

## 🔗 Navigation

- **Previous**: [Implementation Guide](./implementation-guide.md)
- **Next**: [Comparison Analysis](./comparison-analysis.md)
- **Home**: [Database Management Tools Research](./README.md)

---

*These best practices ensure optimal performance, security, and maintainability for database management tools in EdTech development workflows.*