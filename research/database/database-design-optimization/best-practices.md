# Best Practices: Database Design & Optimization

## 🎯 Overview

This comprehensive guide outlines industry best practices for database design, optimization, and management, specifically tailored for PostgreSQL and MongoDB deployments in EdTech environments. These practices ensure scalability, performance, security, and maintainability.

## 🏗️ Database Design Best Practices

### Schema Design Principles

#### PostgreSQL Schema Design

```sql
-- ✅ GOOD: Proper normalization with performance considerations
-- Users table with appropriate data types and constraints
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'),
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(100) NOT NULL CHECK (LENGTH(TRIM(first_name)) > 0),
    last_name VARCHAR(100) NOT NULL CHECK (LENGTH(TRIM(last_name)) > 0),
    role user_role DEFAULT 'student',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    -- Indexes for common queries
    CONSTRAINT users_name_not_empty CHECK (
        LENGTH(TRIM(first_name)) > 0 AND LENGTH(TRIM(last_name)) > 0
    )
);

-- Custom enum for better type safety
CREATE TYPE user_role AS ENUM ('student', 'instructor', 'admin', 'moderator');

-- ❌ AVOID: Over-normalization that hurts performance
-- Don't create separate tables for simple lookup values that rarely change
CREATE TABLE user_titles (id SERIAL PRIMARY KEY, title VARCHAR(10)); -- Unnecessary

-- ✅ BETTER: Use enums or simple varchar with constraints
ALTER TABLE users ADD COLUMN title VARCHAR(10) 
CHECK (title IN ('Mr', 'Ms', 'Dr', 'Prof'));
```

#### MongoDB Schema Design

```javascript
// ✅ GOOD: Embedded documents for related data accessed together
{
  "_id": ObjectId("..."),
  "email": "student@example.com",
  "profile": {
    "firstName": "John",
    "lastName": "Doe",
    "avatar": "https://cdn.example.com/avatars/john.jpg",
    "bio": "Computer Science student",
    "preferences": {
      "language": "en",
      "timezone": "Asia/Manila",
      "notifications": {
        "email": true,
        "push": false,
        "sms": false
      }
    }
  },
  "subscription": {
    "tier": "premium",
    "startDate": ISODate("2024-01-01"),
    "endDate": ISODate("2024-12-31"),
    "features": ["unlimited_courses", "offline_download", "certificates"]
  },
  "learningStats": {
    "totalCourses": 12,
    "completedCourses": 8,
    "totalHours": 240,
    "currentStreak": 7,
    "longestStreak": 45
  },
  "createdAt": ISODate("2024-01-01"),
  "updatedAt": ISODate("2024-01-15")
}

// ❌ AVOID: Over-embedding large arrays that grow without bounds
{
  "userId": ObjectId("..."),
  "allQuizAttempts": [ // This will grow infinitely
    { "quizId": ObjectId("..."), "score": 85, "date": ISODate("...") },
    // ... thousands of attempts
  ]
}

// ✅ BETTER: Reference large collections
// User document
{
  "_id": ObjectId("..."),
  "email": "student@example.com",
  "recentQuizAttempts": [ // Only last 10 attempts
    { "quizId": ObjectId("..."), "score": 85, "date": ISODate("...") }
  ]
}

// Separate quiz_attempts collection for complete history
{
  "_id": ObjectId("..."),
  "userId": ObjectId("..."),
  "quizId": ObjectId("..."),
  "score": 85,
  "attemptDate": ISODate("..."),
  "timeSpent": 1800, // seconds
  "answers": [...]
}
```

### Data Type Selection

#### PostgreSQL Data Types

```sql
-- ✅ GOOD: Appropriate data type selection
CREATE TABLE courses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title VARCHAR(255) NOT NULL,           -- Limited length for indexes
    slug VARCHAR(255) UNIQUE NOT NULL,     -- URL-safe identifier
    description TEXT,                      -- Unlimited text
    price DECIMAL(10,2),                   -- Exact decimal for money
    duration_minutes INTEGER CHECK (duration_minutes > 0),
    rating DECIMAL(3,2) CHECK (rating >= 0 AND rating <= 5),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    metadata JSONB,                        -- Structured data with indexing
    tags TEXT[],                          -- Array for multiple values
    coordinates POINT                      -- Geometric data type
);

-- ❌ AVOID: Inappropriate data types
CREATE TABLE bad_courses (
    price FLOAT,                          -- Imprecise for money
    rating VARCHAR(10),                   -- String for numeric data
    created_at TIMESTAMP WITHOUT TIME ZONE, -- No timezone info
    metadata TEXT,                        -- JSON as text (no indexing)
    tags VARCHAR(1000)                    -- Comma-separated in string
);
```

#### MongoDB Data Types

```javascript
// ✅ GOOD: Proper BSON type usage
{
  "_id": ObjectId("..."),              // Unique identifier
  "title": "Advanced JavaScript",      // String
  "price": NumberDecimal("99.99"),     // Decimal128 for precise money
  "duration": 120,                     // Int32 for smaller numbers
  "rating": 4.5,                       // Double for ratings
  "isPublished": true,                 // Boolean
  "createdAt": new Date(),             // Date object
  "tags": ["javascript", "advanced"],  // Array of strings
  "metadata": {                        // Embedded document
    "difficulty": "intermediate",
    "prerequisites": ["basic-js"],
    "certification": true
  },
  "statistics": {
    "enrollments": NumberLong(15243),  // Int64 for large numbers
    "completionRate": 0.85            // Double for percentages
  }
}

// ❌ AVOID: Inappropriate type usage
{
  "price": "99.99",                    // String for money (precision issues)
  "isPublished": "true",               // String for boolean
  "createdAt": "2024-01-15T10:30:00Z", // String for dates
  "enrollments": 15243.0               // Double for integers
}
```

### Relationship Design

#### One-to-Many Relationships

```sql
-- PostgreSQL: Foreign key relationships
CREATE TABLE courses (
    id UUID PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    instructor_id UUID REFERENCES users(id) ON DELETE SET NULL
);

CREATE TABLE lessons (
    id UUID PRIMARY KEY,
    course_id UUID REFERENCES courses(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    order_position INTEGER NOT NULL,
    UNIQUE(course_id, order_position)
);
```

```javascript
// MongoDB: Embedded vs Referenced approach
// ✅ GOOD: Embed when data is accessed together and bounded
{
  "_id": ObjectId("course123"),
  "title": "Advanced JavaScript",
  "lessons": [
    {
      "_id": ObjectId("lesson1"),
      "title": "Closures and Scope",
      "duration": 45,
      "orderPosition": 1
    },
    {
      "_id": ObjectId("lesson2"),
      "title": "Async/Await Patterns",
      "duration": 60,
      "orderPosition": 2
    }
  ]
}

// ✅ ALSO GOOD: Reference when data is large or accessed independently
{
  "_id": ObjectId("course123"),
  "title": "Advanced JavaScript",
  "lessonCount": 12,
  "totalDuration": 720
}
// Separate lessons collection
{
  "_id": ObjectId("lesson1"),
  "courseId": ObjectId("course123"),
  "title": "Closures and Scope",
  "content": "...", // Large content
  "orderPosition": 1
}
```

## 🚀 Performance Optimization Best Practices

### Indexing Strategies

#### PostgreSQL Indexing

```sql
-- ✅ GOOD: Strategic index creation
-- Compound index with most selective column first
CREATE INDEX idx_courses_discovery ON courses (category_id, is_published, rating DESC)
WHERE is_published = true;

-- Partial index for specific conditions
CREATE INDEX idx_active_users ON users (last_login_at DESC)
WHERE is_active = true AND last_login_at > NOW() - INTERVAL '30 days';

-- Functional index for case-insensitive searches
CREATE INDEX idx_users_email_lower ON users (LOWER(email));

-- GIN index for full-text search
CREATE INDEX idx_courses_search ON courses 
USING GIN (to_tsvector('english', title || ' ' || COALESCE(description, '')));

-- JSONB index for metadata queries
CREATE INDEX idx_courses_metadata ON courses USING GIN (metadata);

-- ❌ AVOID: Over-indexing
-- Don't create indexes for every column
CREATE INDEX idx_users_first_name ON users (first_name); -- Rarely queried alone
CREATE INDEX idx_users_created_at ON users (created_at);  -- Generic timestamp

-- ✅ BETTER: Compound indexes for common query patterns
CREATE INDEX idx_users_name_search ON users (last_name, first_name)
WHERE is_active = true;
```

#### MongoDB Indexing

```javascript
// ✅ GOOD: Strategic index creation
// Compound index matching query patterns
db.courses.createIndex({
  "category": 1,
  "isPublished": 1,
  "rating": -1,
  "enrollmentCount": -1
});

// Sparse index for optional fields
db.users.createIndex(
  { "lastLoginAt": -1 },
  { sparse: true }
);

// Text index for search functionality
db.courses.createIndex({
  "title": "text",
  "description": "text",
  "tags": "text"
}, {
  weights: {
    "title": 10,
    "description": 5,
    "tags": 3
  }
});

// TTL index for temporary data
db.sessions.createIndex(
  { "expiresAt": 1 },
  { expireAfterSeconds: 0 }
);

// ❌ AVOID: Inefficient indexing
// Single field indexes that could be compound
db.courses.createIndex({ "category": 1 });
db.courses.createIndex({ "isPublished": 1 });
db.courses.createIndex({ "rating": -1 });

// ✅ BETTER: Single compound index
db.courses.createIndex({
  "category": 1,
  "isPublished": 1,
  "rating": -1
});
```

### Query Optimization

#### PostgreSQL Query Optimization

```sql
-- ✅ GOOD: Optimized queries
-- Use LIMIT with pagination
SELECT id, title, rating
FROM courses
WHERE is_published = true
  AND category_id = $1
ORDER BY rating DESC, created_at DESC
LIMIT 20 OFFSET $2;

-- Use EXISTS instead of IN for better performance
SELECT u.id, u.email
FROM users u
WHERE EXISTS (
    SELECT 1 FROM enrollments e
    WHERE e.user_id = u.id AND e.course_id = $1
);

-- Use window functions instead of correlated subqueries
SELECT 
    c.id,
    c.title,
    c.rating,
    AVG(c.rating) OVER (PARTITION BY c.category_id) as avg_category_rating,
    ROW_NUMBER() OVER (ORDER BY c.rating DESC) as rating_rank
FROM courses c
WHERE c.is_published = true;

-- ❌ AVOID: Inefficient queries
-- Using SELECT * unnecessarily
SELECT * FROM courses WHERE title LIKE '%javascript%';

-- ✅ BETTER: Select only needed columns
SELECT id, title, price FROM courses 
WHERE title ILIKE '%javascript%' 
  AND is_published = true;

-- ❌ AVOID: Functions in WHERE clauses preventing index usage
SELECT * FROM users WHERE UPPER(email) = 'JOHN@EXAMPLE.COM';

-- ✅ BETTER: Use functional index or proper comparison
SELECT * FROM users WHERE email = LOWER('JOHN@EXAMPLE.COM');
```

#### MongoDB Query Optimization

```javascript
// ✅ GOOD: Optimized MongoDB queries
// Use projection to limit returned fields
db.courses.find(
  { "isPublished": true, "category": "programming" },
  { "title": 1, "price": 1, "rating": 1 }
).sort({ "rating": -1 }).limit(20);

// Use compound indexes effectively
db.courses.find({
  "category": "programming",
  "isPublished": true,
  "rating": { $gte: 4.0 }
}).sort({ "rating": -1, "enrollmentCount": -1 });

// Use aggregation pipeline for complex operations
db.courses.aggregate([
  { $match: { "isPublished": true } },
  { $group: {
      _id: "$category",
      avgRating: { $avg: "$rating" },
      totalCourses: { $sum: 1 },
      topRating: { $max: "$rating" }
  }},
  { $sort: { "avgRating": -1 } }
]);

// ❌ AVOID: Inefficient queries
// Querying without indexes
db.courses.find({ "instructor.name": "John Doe" }); // No index on embedded field

// Using regex without anchoring
db.courses.find({ "title": /javascript/i }); // Full collection scan

// ✅ BETTER: Proper indexing and text search
db.courses.createIndex({ "instructor.name": 1 });
db.courses.find({ "instructor.name": "John Doe" });

// Use text search instead of regex
db.courses.find({ $text: { $search: "javascript" } });
```

### Connection Management

#### PostgreSQL Connection Pooling

```typescript
// ✅ GOOD: Proper connection pool configuration
import { Pool } from 'pg';

const pool = new Pool({
  host: process.env.DB_HOST,
  port: 5432,
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  
  // Optimal pool settings
  min: 5,                    // Minimum connections
  max: 50,                   // Maximum connections (not too high)
  idleTimeoutMillis: 30000,  // Close idle connections
  connectionTimeoutMillis: 2000, // Fast timeout for new connections
  
  // SSL in production
  ssl: process.env.NODE_ENV === 'production' ? {
    rejectUnauthorized: false
  } : false,
});

// ❌ AVOID: Poor connection management
const badPool = new Pool({
  max: 500,                  // Too many connections
  idleTimeoutMillis: 0,      // Never close idle connections
  connectionTimeoutMillis: 60000, // Too long timeout
});

// ✅ GOOD: Proper connection usage
async function getUserCourses(userId: string) {
  const client = await pool.connect();
  try {
    const result = await client.query(
      'SELECT * FROM courses WHERE instructor_id = $1',
      [userId]
    );
    return result.rows;
  } finally {
    client.release(); // Always release connection
  }
}

// ❌ AVOID: Not releasing connections
async function badGetUserCourses(userId: string) {
  const client = await pool.connect();
  const result = await client.query(
    'SELECT * FROM courses WHERE instructor_id = $1',
    [userId]
  );
  return result.rows; // Connection never released!
}
```

#### MongoDB Connection Management

```typescript
// ✅ GOOD: Proper MongoDB connection management
import { MongoClient, MongoClientOptions } from 'mongodb';

const mongoOptions: MongoClientOptions = {
  maxPoolSize: 100,          // Maximum connections
  minPoolSize: 5,            // Minimum connections
  maxIdleTimeMS: 30000,      // Close idle connections
  serverSelectionTimeoutMS: 5000, // Fast server selection
  socketTimeoutMS: 45000,    // Socket timeout
  
  // Write concern for durability
  writeConcern: {
    w: 'majority',
    j: true,
    wtimeout: 5000
  },
  
  // Read preference
  readPreference: 'primary',
};

const client = new MongoClient(connectionString, mongoOptions);

// ✅ GOOD: Connection reuse
class DatabaseService {
  private static db: Db;

  static async initialize() {
    await client.connect();
    this.db = client.db('edtech');
  }

  static getCollection(name: string) {
    return this.db.collection(name);
  }
}

// ❌ AVOID: Creating new connections for each operation
async function badGetCourses() {
  const newClient = new MongoClient(connectionString); // New connection each time
  await newClient.connect();
  const db = newClient.db('edtech');
  const courses = await db.collection('courses').find({}).toArray();
  await newClient.close();
  return courses;
}
```

## 🔒 Security Best Practices

### Authentication and Authorization

#### PostgreSQL Security

```sql
-- ✅ GOOD: Role-based security
-- Create specific roles for different access levels
CREATE ROLE edtech_readonly;
CREATE ROLE edtech_readwrite;
CREATE ROLE edtech_admin;

-- Grant appropriate permissions
GRANT SELECT ON ALL TABLES IN SCHEMA public TO edtech_readonly;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO edtech_readwrite;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO edtech_admin;

-- Create users with specific roles
CREATE USER api_server WITH PASSWORD 'secure_password';
GRANT edtech_readwrite TO api_server;

CREATE USER reporting_user WITH PASSWORD 'secure_password';
GRANT edtech_readonly TO reporting_user;

-- ✅ Row-level security for multi-tenant applications
ALTER TABLE user_progress ENABLE ROW LEVEL SECURITY;

CREATE POLICY user_progress_policy ON user_progress
FOR ALL TO edtech_readwrite
USING (user_id = current_setting('app.current_user_id')::UUID);

-- ❌ AVOID: Overprivileged users
CREATE USER api_server SUPERUSER; -- Too many privileges

-- ✅ GOOD: Connection security
-- Use SSL certificates
ALTER SYSTEM SET ssl = on;
ALTER SYSTEM SET ssl_cert_file = '/path/to/server.crt';
ALTER SYSTEM SET ssl_key_file = '/path/to/server.key';

-- Restrict connections by IP
-- In pg_hba.conf:
-- hostssl all api_server 10.0.0.0/8 cert
-- hostssl all reporting_user 192.168.1.0/24 md5
```

#### MongoDB Security

```javascript
// ✅ GOOD: Role-based access control
use edtech_db;

// Create roles for different access levels
db.createRole({
  role: "courseReader",
  privileges: [
    { resource: { db: "edtech_db", collection: "courses" }, actions: ["find"] },
    { resource: { db: "edtech_db", collection: "users" }, actions: ["find"] }
  ],
  roles: []
});

db.createRole({
  role: "courseManager",
  privileges: [
    { resource: { db: "edtech_db", collection: "courses" }, actions: ["find", "insert", "update", "remove"] },
    { resource: { db: "edtech_db", collection: "lessons" }, actions: ["find", "insert", "update", "remove"] }
  ],
  roles: ["courseReader"]
});

// Create users with specific roles
db.createUser({
  user: "api_server",
  pwd: "secure_password",
  roles: ["courseManager"]
});

db.createUser({
  user: "analytics_user",
  pwd: "secure_password",
  roles: ["courseReader"]
});

// ✅ GOOD: Field-level security with views
db.createView("public_user_profile", "users", [
  {
    $project: {
      email: 0,        // Hide email
      password_hash: 0, // Hide password
      personal_info: 0  // Hide sensitive data
    }
  }
]);
```

### Data Encryption

#### Encryption at Rest

```yaml
# PostgreSQL encryption configuration
# postgresql.conf
ssl = on
ssl_cert_file = '/etc/ssl/certs/server.crt'
ssl_key_file = '/etc/ssl/private/server.key'
ssl_ca_file = '/etc/ssl/certs/ca.crt'
ssl_crl_file = '/etc/ssl/certs/ca.crl'

# Enable transparent data encryption (if available)
data_encryption = on
```

```yaml
# MongoDB encryption configuration
# mongod.conf
security:
  enableEncryption: true
  encryptionKeyFile: /etc/mongodb/encryption-key
  encryptionCipherMode: AES256-CBC

net:
  ssl:
    mode: requireSSL
    PEMKeyFile: /etc/ssl/mongodb.pem
    CAFile: /etc/ssl/ca.pem
```

#### Application-Level Encryption

```typescript
// ✅ GOOD: Encrypt sensitive data before storage
import crypto from 'crypto';

class EncryptionService {
  private readonly algorithm = 'aes-256-gcm';
  private readonly secretKey = process.env.ENCRYPTION_KEY; // 32 bytes key

  encrypt(text: string): { encrypted: string; iv: string; tag: string } {
    const iv = crypto.randomBytes(16);
    const cipher = crypto.createCipher(this.algorithm, this.secretKey);
    cipher.setAAD(Buffer.from('edtech-app'));
    
    let encrypted = cipher.update(text, 'utf8', 'hex');
    encrypted += cipher.final('hex');
    
    const tag = cipher.getAuthTag();
    
    return {
      encrypted,
      iv: iv.toString('hex'),
      tag: tag.toString('hex')
    };
  }

  decrypt(encrypted: string, iv: string, tag: string): string {
    const decipher = crypto.createDecipher(this.algorithm, this.secretKey);
    decipher.setAAD(Buffer.from('edtech-app'));
    decipher.setAuthTag(Buffer.from(tag, 'hex'));
    
    let decrypted = decipher.update(encrypted, 'hex', 'utf8');
    decrypted += decipher.final('utf8');
    
    return decrypted;
  }
}

// Usage in user service
class UserService {
  private encryption = new EncryptionService();

  async createUser(userData: any) {
    // Encrypt sensitive fields
    const encryptedPII = this.encryption.encrypt(JSON.stringify({
      ssn: userData.ssn,
      phone: userData.phone,
      address: userData.address
    }));

    return await this.db.query(`
      INSERT INTO users (email, password_hash, encrypted_pii, encryption_iv, encryption_tag)
      VALUES ($1, $2, $3, $4, $5)
    `, [
      userData.email,
      userData.password_hash,
      encryptedPII.encrypted,
      encryptedPII.iv,
      encryptedPII.tag
    ]);
  }
}
```

## 📊 Monitoring and Maintenance

### Performance Monitoring

#### PostgreSQL Monitoring

```sql
-- ✅ Monitor key performance metrics
-- Query performance monitoring
SELECT 
    query,
    calls,
    total_time,
    mean_time,
    rows,
    100.0 * shared_blks_hit / nullif(shared_blks_hit + shared_blks_read, 0) AS hit_percent
FROM pg_stat_statements 
WHERE calls > 100  -- Focus on frequently called queries
ORDER BY total_time DESC 
LIMIT 20;

-- Index usage monitoring
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch,
    pg_size_pretty(pg_relation_size(indexname::regclass)) as size
FROM pg_stat_user_indexes 
ORDER BY idx_scan DESC;

-- Connection monitoring
SELECT 
    state,
    count(*),
    max(now() - state_change) as max_duration,
    max(now() - query_start) as max_query_duration
FROM pg_stat_activity 
WHERE state IS NOT NULL
GROUP BY state;

-- Database size monitoring
SELECT 
    pg_database.datname,
    pg_size_pretty(pg_database_size(pg_database.datname)) as size
FROM pg_database 
ORDER BY pg_database_size(pg_database.datname) DESC;
```

#### MongoDB Monitoring

```javascript
// ✅ MongoDB performance monitoring
// Database statistics
db.runCommand({ dbStats: 1 });

// Collection statistics
db.courses.stats();

// Current operations
db.currentOp({
  "active": true,
  "secs_running": { "$gt": 1 }
});

// Index usage statistics
db.courses.aggregate([
  { $indexStats: {} },
  { $sort: { "accesses.ops": -1 } }
]);

// Slow query profiler
db.setProfilingLevel(2, { slowms: 1000 });
db.system.profile.find().sort({ ts: -1 }).limit(5);

// Replication status (if using replica sets)
rs.status();
rs.printReplicationInfo();

// Sharding status (if using sharding)
sh.status();
```

### Automated Maintenance

#### PostgreSQL Maintenance

```sql
-- ✅ Automated maintenance configuration
-- Configure auto-vacuum
ALTER TABLE courses SET (
    autovacuum_vacuum_scale_factor = 0.1,
    autovacuum_analyze_scale_factor = 0.05,
    autovacuum_vacuum_threshold = 100,
    autovacuum_analyze_threshold = 50
);

-- Maintenance script (to be run via cron)
DO $$
DECLARE
    rec RECORD;
BEGIN
    -- Update table statistics
    FOR rec IN SELECT tablename FROM pg_tables WHERE schemaname = 'public'
    LOOP
        EXECUTE 'ANALYZE ' || rec.tablename;
    END LOOP;
    
    -- Log maintenance completion
    INSERT INTO maintenance_log (operation, completed_at) 
    VALUES ('analyze_tables', NOW());
END $$;
```

#### MongoDB Maintenance

```javascript
// ✅ MongoDB maintenance scripts
// Compact collections to reclaim space
db.runCommand({ compact: "courses" });

// Update collection statistics
db.runCommand({ collStats: "courses" });

// Repair database (if needed)
db.runCommand({ repairDatabase: 1 });

// Create maintenance script
function performMaintenance() {
    const collections = db.runCommand("listCollections").cursor.firstBatch;
    
    collections.forEach(collection => {
        const collName = collection.name;
        
        // Skip system collections
        if (!collName.startsWith("system.")) {
            print(`Maintaining collection: ${collName}`);
            
            // Update statistics
            db.runCommand({ collStats: collName });
            
            // Check for unused indexes
            const indexStats = db[collName].aggregate([
                { $indexStats: {} }
            ]).toArray();
            
            indexStats.forEach(stat => {
                if (stat.accesses.ops === 0) {
                    print(`Unused index found: ${stat.name} on ${collName}`);
                }
            });
        }
    });
}
```

## 🌍 Scalability Best Practices

### Horizontal Scaling

#### PostgreSQL Read Replicas

```yaml
# docker-compose.replication.yml
version: '3.8'
services:
  postgres-master:
    image: postgres:15
    environment:
      POSTGRES_REPLICATION_USER: replicator
      POSTGRES_REPLICATION_PASSWORD: repl_password
    volumes:
      - ./postgresql.master.conf:/etc/postgresql/postgresql.conf
    command: postgres -c config_file=/etc/postgresql/postgresql.conf

  postgres-replica:
    image: postgres:15
    environment:
      PGUSER: postgres
      POSTGRES_PASSWORD: password
      POSTGRES_MASTER_SERVICE: postgres-master
    volumes:
      - ./postgresql.replica.conf:/etc/postgresql/postgresql.conf
    depends_on:
      - postgres-master
```

```typescript
// ✅ Read-write splitting in application
class DatabaseService {
  private writePool: Pool;
  private readPool: Pool;

  constructor() {
    this.writePool = new Pool({
      host: process.env.DB_MASTER_HOST,
      // ... master configuration
    });

    this.readPool = new Pool({
      host: process.env.DB_REPLICA_HOST,
      // ... replica configuration
    });
  }

  async executeRead(query: string, params: any[] = []) {
    return this.readPool.query(query, params);
  }

  async executeWrite(query: string, params: any[] = []) {
    return this.writePool.query(query, params);
  }

  // Service methods
  async getCourses(filters: any) {
    // Use read replica for queries
    return this.executeRead('SELECT * FROM courses WHERE ...', []);
  }

  async createCourse(courseData: any) {
    // Use master for writes
    return this.executeWrite('INSERT INTO courses ...', []);
  }
}
```

#### MongoDB Sharding

```javascript
// ✅ MongoDB sharding setup
// Enable sharding on database
sh.enableSharding("edtech_db");

// Choose appropriate shard keys
// For courses collection - distribute by category
sh.shardCollection("edtech_db.courses", { "category": 1, "_id": 1 });

// For user progress - distribute by user
sh.shardCollection("edtech_db.user_progress", { "userId": 1, "_id": 1 });

// For quiz attempts - distribute by date for time-series data
sh.shardCollection("edtech_db.quiz_attempts", { "completedAt": 1, "_id": 1 });

// ✅ Application-level shard awareness
class MongoService {
  async getCoursesByCategory(category: string) {
    // This query will only hit relevant shards
    return db.courses.find({ category: category });
  }

  async getUserProgress(userId: ObjectId) {
    // This query will only hit the shard containing this user's data
    return db.user_progress.find({ userId: userId });
  }
}
```

### Caching Strategies

```typescript
// ✅ Multi-level caching implementation
import Redis from 'ioredis';

class CacheService {
  private redis: Redis;
  private localCache = new Map();

  constructor() {
    this.redis = new Redis({
      host: process.env.REDIS_HOST,
      port: process.env.REDIS_PORT,
      retryDelayOnFailover: 100,
      enableReadyCheck: false,
      maxRetriesPerRequest: null,
    });
  }

  // L1: Local cache (fastest)
  getLocal(key: string): any {
    return this.localCache.get(key);
  }

  setLocal(key: string, value: any, ttl: number = 60000) {
    this.localCache.set(key, value);
    setTimeout(() => this.localCache.delete(key), ttl);
  }

  // L2: Redis cache (fast, shared)
  async getRedis(key: string): Promise<any> {
    const cached = await this.redis.get(key);
    return cached ? JSON.parse(cached) : null;
  }

  async setRedis(key: string, value: any, ttl: number = 3600) {
    await this.redis.setex(key, ttl, JSON.stringify(value));
  }

  // Multi-level get with fallback
  async get(key: string, fetchFn: () => Promise<any>): Promise<any> {
    // Try L1 cache first
    let cached = this.getLocal(key);
    if (cached) return cached;

    // Try L2 cache
    cached = await this.getRedis(key);
    if (cached) {
      this.setLocal(key, cached);
      return cached;
    }

    // Fetch from database
    const fresh = await fetchFn();
    
    // Store in both caches
    await this.setRedis(key, fresh);
    this.setLocal(key, fresh);
    
    return fresh;
  }
}

// Usage in service
class CourseService {
  private cache = new CacheService();

  async getCourse(id: string) {
    return this.cache.get(
      `course:${id}`,
      () => this.database.getCourse(id)
    );
  }
}
```

This comprehensive best practices guide ensures that your database implementations are optimized for performance, security, and scalability while maintaining code quality and operational excellence.

---

⬅️ **[Previous: Implementation Guide](./implementation-guide.md)**  
➡️ **[Next: Comparison Analysis](./comparison-analysis.md)**  
🏠 **[Research Home](../../README.md)**

---

*Best Practices - Industry-standard database design and optimization techniques*