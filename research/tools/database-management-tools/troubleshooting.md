# Troubleshooting: Database Management Tools

## 🎯 Overview

This guide provides comprehensive troubleshooting solutions for common issues with pgAdmin, MongoDB Compass, and Redis CLI in EdTech development environments. Solutions are tested and verified for international remote development scenarios.

## 🗄️ PostgreSQL + pgAdmin Troubleshooting

### 🔧 Connection Issues

#### Problem: pgAdmin Cannot Connect to PostgreSQL Server
```bash
# Error: "could not connect to server: Connection refused"

# Solution 1: Check PostgreSQL service status
sudo systemctl status postgresql
sudo systemctl start postgresql  # If not running

# Solution 2: Verify PostgreSQL configuration
sudo -u postgres psql -c "SHOW listen_addresses;"
sudo -u postgres psql -c "SHOW port;"

# Solution 3: Update pg_hba.conf for remote connections
sudo nano /etc/postgresql/15/main/pg_hba.conf
# Add line: host all all 0.0.0.0/0 md5

# Solution 4: Update postgresql.conf
sudo nano /etc/postgresql/15/main/postgresql.conf
# Change: listen_addresses = '*'

# Restart PostgreSQL
sudo systemctl restart postgresql
```

#### Problem: Authentication Failed for User
```sql
-- Error: "password authentication failed for user"

-- Solution 1: Reset user password
ALTER USER edtech_user WITH PASSWORD 'new_secure_password_123';

-- Solution 2: Check user permissions
SELECT usename, usesuper, usecreatedb FROM pg_user WHERE usename = 'edtech_user';

-- Solution 3: Grant necessary permissions
GRANT CONNECT ON DATABASE edtech_db TO edtech_user;
GRANT USAGE ON SCHEMA public TO edtech_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO edtech_user;
```

#### Problem: pgAdmin Web Server Won't Start
```bash
# Error: "An error occurred initialising the application server"

# Solution 1: Check Python dependencies
pip install --upgrade pgadmin4

# Solution 2: Reset pgAdmin configuration
rm -rf ~/.pgadmin/
pgadmin4 --setup

# Solution 3: Check port conflicts
netstat -tulpn | grep :5050
# Kill conflicting process or change port

# Solution 4: Fix file permissions
sudo chown -R $USER:$USER ~/.pgadmin/
chmod -R 700 ~/.pgadmin/
```

### 📊 Performance Issues

#### Problem: Slow Query Execution
```sql
-- Diagnosis: Identify slow queries
SELECT 
    query,
    calls,
    total_time,
    mean_time,
    rows
FROM pg_stat_statements 
WHERE mean_time > 1000  -- Queries taking >1 second
ORDER BY total_time DESC 
LIMIT 10;

-- Solution 1: Add missing indexes
CREATE INDEX CONCURRENTLY idx_user_progress_user_course 
ON user_progress (user_id, course_id);

-- Solution 2: Update table statistics
ANALYZE user_progress;

-- Solution 3: Increase work_mem for complex queries
SET work_mem = '512MB';

-- Solution 4: Rewrite inefficient queries
-- Instead of:
SELECT * FROM users WHERE LOWER(email) = 'student@example.com';

-- Use:
CREATE INDEX idx_users_email_lower ON users (LOWER(email));
SELECT * FROM users WHERE LOWER(email) = 'student@example.com';
```

#### Problem: High Memory Usage
```sql
-- Diagnosis: Check memory usage
SELECT 
    datname,
    pid,
    usename,
    application_name,
    client_addr,
    query_start,
    state,
    query
FROM pg_stat_activity
WHERE state = 'active'
ORDER BY query_start;

-- Solution 1: Identify memory-intensive queries
SELECT 
    query,
    calls,
    total_time,
    mean_time,
    shared_blks_read,
    shared_blks_hit
FROM pg_stat_statements
ORDER BY shared_blks_read DESC
LIMIT 10;

-- Solution 2: Adjust PostgreSQL memory settings
-- In postgresql.conf:
-- shared_buffers = 256MB (reduce from 2GB)
-- work_mem = 64MB (reduce from 256MB)
-- maintenance_work_mem = 256MB (reduce from 1GB)
```

### 🔐 Security Issues

#### Problem: Unauthorized Access Attempts
```sql
-- Diagnosis: Check failed login attempts
SELECT 
    datname,
    usename,
    application_name,
    client_addr,
    backend_start,
    state
FROM pg_stat_activity
WHERE client_addr IS NOT NULL;

-- Solution 1: Implement connection limiting
ALTER USER edtech_user CONNECTION LIMIT 10;

-- Solution 2: Enable logging for security monitoring
-- In postgresql.conf:
-- log_connections = on
-- log_disconnections = on
-- log_failed_login_attempts = on

-- Solution 3: Restrict access by IP
-- In pg_hba.conf:
-- host edtech_db edtech_user 192.168.1.0/24 md5
```

## 🍃 MongoDB + Compass Troubleshooting

### 🔧 Connection and Authentication Issues

#### Problem: MongoDB Compass Cannot Connect
```bash
# Error: "connection timed out" or "authentication failed"

# Solution 1: Check MongoDB service
sudo systemctl status mongod
sudo systemctl start mongod

# Solution 2: Verify MongoDB configuration
sudo cat /etc/mongod.conf | grep bindIp
# Should be: bindIp: 0.0.0.0 for remote access

# Solution 3: Check firewall settings
sudo ufw allow 27017
sudo firewall-cmd --permanent --add-port=27017/tcp

# Solution 4: Test connection with mongo shell
mongosh --host localhost --port 27017 --username admin --password
```

#### Problem: Authentication Error with MongoDB Compass
```javascript
// Error: "Authentication failed"

// Solution 1: Create user with proper roles
use admin;
db.createUser({
  user: "compass_user",
  pwd: "secure_compass_password",
  roles: [
    { role: "readWrite", db: "edtech_content" },
    { role: "read", db: "admin" }
  ]
});

// Solution 2: Enable authentication in MongoDB
// In /etc/mongod.conf:
// security:
//   authorization: enabled

// Solution 3: Use correct connection string format
// mongodb://username:password@host:port/database?authSource=admin
```

#### Problem: Compass Crashes or Freezes
```bash
# Solution 1: Clear Compass cache
rm -rf ~/Library/Application\ Support/MongoDB\ Compass/  # macOS
rm -rf ~/.config/MongoDB\ Compass/  # Linux
# Windows: %APPDATA%\MongoDB Compass\

# Solution 2: Update Compass to latest version
# Download from: https://www.mongodb.com/products/compass

# Solution 3: Increase system memory allocation
# Add to MongoDB configuration:
# wiredTiger:
#   engineConfig:
#     cacheSizeGB: 2

# Solution 4: Disable real-time performance monitoring
# In Compass: Performance tab > Disable real-time charts
```

### 📊 Query and Performance Issues

#### Problem: Slow Query Performance in Compass
```javascript
// Diagnosis: Enable profiler
db.setProfilingLevel(2, { slowms: 100 });

// Check slow queries
db.system.profile.find().limit(5).sort({ ts: -1 }).pretty();

// Solution 1: Add missing indexes
db.lessons.createIndex({ "courseId": 1, "created": -1 });

// Solution 2: Optimize aggregation pipelines
// Instead of:
db.userProgress.aggregate([
  { $lookup: { from: "users", localField: "userId", foreignField: "_id", as: "user" }},
  { $match: { "user.role": "student" }}
]);

// Use:
db.userProgress.aggregate([
  { $match: { "userRole": "student" }},  // Filter early
  { $lookup: { from: "users", localField: "userId", foreignField: "_id", as: "user" }}
]);

// Solution 3: Use projection to limit data
db.lessons.find(
  { "courseId": "bar_exam_2024" },
  { "title": 1, "summary.duration": 1, "_id": 0 }
);
```

#### Problem: Out of Memory Errors
```javascript
// Error: "Exceeded memory limit"

// Solution 1: Add allowDiskUse for large aggregations
db.userProgress.aggregate([
  { $group: { _id: "$courseId", count: { $sum: 1 }}},
  { $sort: { count: -1 }}
], { allowDiskUse: true });

// Solution 2: Process data in batches
const batchSize = 1000;
let skip = 0;
let batch;

do {
  batch = db.lessons.find().skip(skip).limit(batchSize);
  // Process batch
  skip += batchSize;
} while (batch.hasNext());

// Solution 3: Increase MongoDB memory allocation
// In /etc/mongod.conf:
// wiredTiger:
//   engineConfig:
//     cacheSizeGB: 4
```

### 🔐 Security and Access Issues

#### Problem: Unauthorized Database Access
```javascript
// Solution 1: Implement field-level security
db.createRole({
  role: "studentRole",
  privileges: [
    {
      resource: { db: "edtech_content", collection: "lessons" },
      actions: ["find"]
    },
    {
      resource: { db: "edtech_content", collection: "userProgress" },
      actions: ["find", "update"],
      // Restrict to user's own documents
      filter: { "userId": { "$eq": "$$USER_ID" }}
    }
  ],
  roles: []
});

// Solution 2: Enable SSL/TLS
// In /etc/mongod.conf:
// net:
//   ssl:
//     mode: requireSSL
//     PEMKeyFile: /path/to/mongodb.pem
```

## ⚡ Redis + CLI Troubleshooting

### 🔧 Connection and Configuration Issues

#### Problem: Redis CLI Cannot Connect
```bash
# Error: "Could not connect to Redis"

# Solution 1: Check Redis service status
sudo systemctl status redis
sudo systemctl start redis

# Solution 2: Verify Redis configuration
redis-cli ping
# Should return: PONG

# Solution 3: Check Redis configuration file
sudo nano /etc/redis/redis.conf
# Verify:
# bind 0.0.0.0  # For remote access
# port 6379
# requirepass your_password

# Solution 4: Test with authentication
redis-cli -h localhost -p 6379 -a your_password ping
```

#### Problem: Redis Server Keeps Crashing
```bash
# Diagnosis: Check Redis logs
sudo tail -f /var/log/redis/redis-server.log

# Solution 1: Check available memory
free -h
# If low memory, adjust maxmemory setting
redis-cli CONFIG SET maxmemory 2gb
redis-cli CONFIG SET maxmemory-policy allkeys-lru

# Solution 2: Fix configuration errors
redis-server --test-memory 1024  # Test memory allocation

# Solution 3: Check disk space for persistence
df -h
# Ensure adequate space for RDB/AOF files

# Solution 4: Disable problematic features temporarily
redis-cli CONFIG SET save ""  # Disable RDB snapshots
redis-cli CONFIG SET appendonly no  # Disable AOF
```

### 📊 Performance and Memory Issues

#### Problem: High Memory Usage
```bash
# Diagnosis: Analyze memory usage
redis-cli INFO memory
redis-cli --bigkeys

# Solution 1: Find memory-consuming keys
redis-cli --bigkeys --i 0.01

# Solution 2: Implement key expiration
redis-cli SCAN 0 MATCH "session:*" | xargs -I {} redis-cli EXPIRE {} 3600

# Solution 3: Use more efficient data structures
# Instead of storing JSON strings:
SET user:12345 '{"name":"Juan","email":"juan@example.com","score":95}'

# Use Hashes:
HMSET user:12345 name "Juan" email "juan@example.com" score 95

# Solution 4: Configure memory policies
redis-cli CONFIG SET maxmemory-policy volatile-lru
redis-cli CONFIG SET maxmemory 4gb
```

#### Problem: Slow Redis Operations
```bash
# Diagnosis: Check slow operations
redis-cli SLOWLOG GET 10

# Solution 1: Avoid expensive operations
# Instead of KEYS pattern (O(n)):
redis-cli KEYS user:*

# Use SCAN (O(1) per call):
redis-cli SCAN 0 MATCH user:* COUNT 100

# Solution 2: Use pipelining for multiple operations
redis-cli --pipe << 'EOF'
SET key1 value1
SET key2 value2
SET key3 value3
EOF

# Solution 3: Optimize Lua scripts
redis-cli EVAL "
local keys = redis.call('SCAN', 0, 'MATCH', ARGV[1], 'COUNT', 100)
for i, key in ipairs(keys[2]) do
    redis.call('EXPIRE', key, ARGV[2])
end
return #keys[2]
" 0 "session:*" 3600
```

### 🔐 Security Issues

#### Problem: Unauthorized Redis Access
```bash
# Solution 1: Enable authentication
redis-cli CONFIG SET requirepass "very_secure_password_2024"

# Solution 2: Rename dangerous commands
redis-cli CONFIG SET rename-command FLUSHDB ""
redis-cli CONFIG SET rename-command FLUSHALL ""
redis-cli CONFIG SET rename-command DEBUG ""

# Solution 3: Bind to specific interfaces
# In /etc/redis/redis.conf:
# bind 127.0.0.1 192.168.1.100

# Solution 4: Enable SSL/TLS
# In /etc/redis/redis.conf:
# tls-port 6380
# tls-cert-file /path/to/redis.crt
# tls-key-file /path/to/redis.key
```

#### Problem: Data Loss or Corruption
```bash
# Diagnosis: Check data integrity
redis-cli LASTSAVE  # Last successful save time
redis-cli INFO persistence

# Solution 1: Configure proper persistence
redis-cli CONFIG SET save "900 1 300 10 60 10000"
redis-cli CONFIG SET appendonly yes
redis-cli CONFIG SET appendfsync everysec

# Solution 2: Manual backup
redis-cli BGSAVE
redis-cli BGREWRITEAOF

# Solution 3: Restore from backup
# Stop Redis
sudo systemctl stop redis
# Replace dump.rdb with backup
sudo cp /backup/dump.rdb /var/lib/redis/
sudo chown redis:redis /var/lib/redis/dump.rdb
# Start Redis
sudo systemctl start redis
```

## 🔄 Cross-Database Integration Issues

### 📊 Data Synchronization Problems

#### Problem: Inconsistent Data Across Databases
```python
# Solution: Implement transaction-like behavior across databases

import psycopg2
import pymongo
import redis
from contextlib import contextmanager

class MultiDatabaseTransaction:
    def __init__(self):
        self.postgres = psycopg2.connect(
            host='localhost',
            database='edtech_db',
            user='edtech_user',
            password='secure_password_123'
        )
        self.mongodb = pymongo.MongoClient('mongodb://admin:secure_mongo_123@localhost:27017/')
        self.redis_client = redis.Redis(host='localhost', port=6379, password='secure_redis_123')
        
        self.rollback_operations = []
    
    @contextmanager
    def transaction(self):
        postgres_tx = self.postgres.cursor()
        try:
            postgres_tx.execute("BEGIN")
            yield {
                'postgres': postgres_tx,
                'mongodb': self.mongodb.edtech_content,
                'redis': self.redis_client
            }
            postgres_tx.execute("COMMIT")
            self.rollback_operations.clear()
        except Exception as e:
            postgres_tx.execute("ROLLBACK")
            self._rollback_operations()
            raise e
        finally:
            postgres_tx.close()
    
    def _rollback_operations(self):
        for operation in reversed(self.rollback_operations):
            try:
                operation()
            except Exception as rollback_error:
                print(f"Rollback error: {rollback_error}")

# Usage example
def update_user_progress(user_id, course_id, progress_data):
    tx_manager = MultiDatabaseTransaction()
    
    with tx_manager.transaction() as dbs:
        # Update PostgreSQL
        dbs['postgres'].execute(
            "UPDATE user_progress SET completion_percentage = %s WHERE user_id = %s AND course_id = %s",
            (progress_data['completion'], user_id, course_id)
        )
        
        # Update MongoDB
        result = dbs['mongodb'].userProgress.update_one(
            {"userId": user_id, "courseId": course_id},
            {"$set": {"currentProgress": progress_data}}
        )
        
        # Add rollback operation for MongoDB
        if result.modified_count > 0:
            tx_manager.rollback_operations.append(
                lambda: dbs['mongodb'].userProgress.update_one(
                    {"userId": user_id, "courseId": course_id},
                    {"$unset": {"currentProgress": ""}}
                )
            )
        
        # Update Redis cache
        cache_key = f"progress:{user_id}:{course_id}"
        old_data = dbs['redis'].hgetall(cache_key)
        
        dbs['redis'].hmset(cache_key, progress_data)
        
        # Add rollback operation for Redis
        if old_data:
            tx_manager.rollback_operations.append(
                lambda: dbs['redis'].hmset(cache_key, old_data)
            )
        else:
            tx_manager.rollback_operations.append(
                lambda: dbs['redis'].delete(cache_key)
            )
```

### 🔧 Environment-Specific Issues

#### Problem: Development vs Production Configuration Mismatch
```bash
# Solution: Environment-specific configuration management

# Create environment configuration script
cat > database_config.sh << 'EOF'
#!/bin/bash

ENVIRONMENT=${1:-development}

case $ENVIRONMENT in
  "development")
    export DB_HOST="localhost"
    export DB_PASSWORD="dev_password_123"
    export REDIS_PASSWORD="dev_redis_123"
    export MONGO_PASSWORD="dev_mongo_123"
    export LOG_LEVEL="DEBUG"
    ;;
  "staging")
    export DB_HOST="staging-db.example.com"
    export DB_PASSWORD="$STAGING_DB_PASSWORD"
    export REDIS_PASSWORD="$STAGING_REDIS_PASSWORD"
    export MONGO_PASSWORD="$STAGING_MONGO_PASSWORD"
    export LOG_LEVEL="INFO"
    ;;
  "production")
    export DB_HOST="prod-db.example.com"
    export DB_PASSWORD="$PROD_DB_PASSWORD"
    export REDIS_PASSWORD="$PROD_REDIS_PASSWORD"
    export MONGO_PASSWORD="$PROD_MONGO_PASSWORD"
    export LOG_LEVEL="ERROR"
    ;;
esac

echo "Environment: $ENVIRONMENT"
echo "Database Host: $DB_HOST"
echo "Log Level: $LOG_LEVEL"
EOF

chmod +x database_config.sh

# Usage:
source database_config.sh production
```

## 🚨 Emergency Recovery Procedures

### 📋 Complete System Recovery Checklist

#### Database Corruption Recovery
```bash
#!/bin/bash
# emergency_recovery.sh

echo "=== Emergency Database Recovery ==="
date

# 1. Stop all database services
sudo systemctl stop postgresql
sudo systemctl stop mongod
sudo systemctl stop redis

# 2. Backup current (potentially corrupted) data
mkdir -p /emergency_backup/$(date +%Y%m%d_%H%M%S)
cp -r /var/lib/postgresql/15/main/ /emergency_backup/$(date +%Y%m%d_%H%M%S)/postgres/
cp -r /var/lib/mongodb/ /emergency_backup/$(date +%Y%m%d_%H%M%S)/mongodb/
cp -r /var/lib/redis/ /emergency_backup/$(date +%Y%m%d_%H%M%S)/redis/

# 3. Restore from last known good backup
echo "Restoring PostgreSQL..."
sudo -u postgres pg_restore -d edtech_db /backups/latest/postgres_backup.custom

echo "Restoring MongoDB..."
mongorestore --drop /backups/latest/mongodb_backup/

echo "Restoring Redis..."
sudo systemctl start redis
redis-cli --rdb /backups/latest/redis_backup.rdb

# 4. Verify data integrity
echo "Verifying PostgreSQL..."
sudo -u postgres psql -d edtech_db -c "SELECT COUNT(*) FROM users;"

echo "Verifying MongoDB..."
mongosh --eval "db.lessons.count()"

echo "Verifying Redis..."
redis-cli dbsize

echo "Recovery completed at $(date)"
```

## 📞 Support and Resources

### 🆘 Getting Help

#### PostgreSQL Support Channels
- **Official Documentation**: https://www.postgresql.org/docs/
- **Community Forum**: https://www.postgresql.org/list/
- **Stack Overflow**: Tag `postgresql`
- **pgAdmin Support**: https://www.pgadmin.org/support/

#### MongoDB Support Channels
- **Official Documentation**: https://docs.mongodb.com/
- **Community Forum**: https://community.mongodb.com/
- **Stack Overflow**: Tag `mongodb`
- **Compass Support**: MongoDB Compass → Help → Support

#### Redis Support Channels
- **Official Documentation**: https://redis.io/documentation
- **Community**: https://redis.io/community
- **Stack Overflow**: Tag `redis`
- **GitHub Issues**: https://github.com/redis/redis/issues

### 📋 Diagnostic Information Collection

#### System Information Script
```bash
#!/bin/bash
# collect_diagnostics.sh

echo "=== System Diagnostics Collection ==="
date

# System information
echo "System Info:"
uname -a
lsb_release -a 2>/dev/null || cat /etc/os-release

# Memory and CPU
echo "Memory:"
free -h
echo "CPU:"
lscpu | grep -E '^(Architecture|CPU\(s\)|Model name)'

# Disk space
echo "Disk Usage:"
df -h

# Network connectivity
echo "Network Tests:"
ping -c 3 google.com
netstat -tulpn | grep -E ':(5432|27017|6379)'

# Database versions
echo "Database Versions:"
psql --version 2>/dev/null || echo "PostgreSQL not found"
mongod --version 2>/dev/null || echo "MongoDB not found"
redis-server --version 2>/dev/null || echo "Redis not found"

# Service status
echo "Service Status:"
systemctl is-active postgresql 2>/dev/null || echo "PostgreSQL service not found"
systemctl is-active mongod 2>/dev/null || echo "MongoDB service not found"
systemctl is-active redis 2>/dev/null || echo "Redis service not found"

echo "Diagnostics collection completed."
```

## 🔗 Navigation

- **Previous**: [Performance Optimization](./performance-optimization.md)
- **Next**: [Template Examples](./template-examples.md)
- **Home**: [Database Management Tools Research](./README.md)

---

*This troubleshooting guide provides comprehensive solutions for common database management tool issues in EdTech development environments.*