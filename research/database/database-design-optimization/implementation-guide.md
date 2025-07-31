# Implementation Guide: Database Design & Optimization

## 🚀 Getting Started

This comprehensive implementation guide provides step-by-step instructions for setting up, configuring, and optimizing PostgreSQL and MongoDB databases for EdTech applications. Each section includes practical examples, configuration files, and optimization techniques.

## 📋 Prerequisites

### System Requirements
```bash
# Minimum hardware requirements for production
CPU: 4+ cores (8+ recommended)
RAM: 8GB minimum (16GB+ recommended)
Storage: SSD with 1000+ IOPS
Network: 1Gbps connection with low latency

# Software prerequisites
Docker and Docker Compose
Node.js 18+ with npm/yarn
Git for version control
```

### Development Environment Setup
```bash
# Clone project template
git clone https://github.com/your-org/edtech-database-template
cd edtech-database-template

# Install dependencies
npm install

# Set up environment variables
cp .env.example .env
# Edit .env with your configuration
```

## 🐘 PostgreSQL Implementation

### 1. Docker Setup & Configuration

```yaml
# docker-compose.yml
version: '3.8'
services:
  postgres:
    image: postgres:15-alpine
    container_name: edtech_postgres
    environment:
      POSTGRES_DB: edtech_db
      POSTGRES_USER: edtech_user
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_INITDB_ARGS: "--encoding=UTF-8 --lc-collate=C --lc-ctype=C"
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./postgresql.conf:/etc/postgresql/postgresql.conf
      - ./pg_hba.conf:/etc/postgresql/pg_hba.conf
      - ./init-scripts:/docker-entrypoint-initdb.d
    command: postgres -c config_file=/etc/postgresql/postgresql.conf
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U edtech_user -d edtech_db"]
      interval: 30s
      timeout: 10s
      retries: 3

  pgbouncer:
    image: pgbouncer/pgbouncer:latest
    container_name: edtech_pgbouncer
    environment:
      DATABASES_HOST: postgres
      DATABASES_PORT: 5432
      DATABASES_USER: edtech_user
      DATABASES_PASSWORD: ${POSTGRES_PASSWORD}
      DATABASES_DBNAME: edtech_db
      POOL_MODE: transaction
      SERVER_RESET_QUERY: DISCARD ALL
      MAX_CLIENT_CONN: 1000
      DEFAULT_POOL_SIZE: 100
      MIN_POOL_SIZE: 10
      RESERVE_POOL_SIZE: 10
    ports:
      - "6432:5432"
    depends_on:
      postgres:
        condition: service_healthy

volumes:
  postgres_data:
```

### 2. PostgreSQL Configuration Optimization

```ini
# postgresql.conf - Production optimized settings
# Memory Configuration
shared_buffers = 4GB                    # 25% of total RAM
effective_cache_size = 12GB             # 75% of total RAM
work_mem = 64MB                         # For complex queries
maintenance_work_mem = 1GB              # For maintenance operations
huge_pages = try                        # Enable huge pages if available

# Connection Configuration
max_connections = 200                   # Adjust based on expected load
superuser_reserved_connections = 3      # Reserved for admin
listen_addresses = '*'
port = 5432

# Write-Ahead Logging (WAL)
wal_level = replica                     # For replication
max_wal_size = 4GB                      # Maximum WAL size
min_wal_size = 1GB                      # Minimum WAL size
checkpoint_completion_target = 0.9      # Spread checkpoints
checkpoint_timeout = 10min              # Maximum time between checkpoints

# Query Planner
random_page_cost = 1.1                  # For SSD storage (default: 4.0)
effective_io_concurrency = 200          # For SSD storage
seq_page_cost = 1.0                     # Sequential page cost

# Parallel Query Configuration
max_parallel_workers_per_gather = 4     # Parallel workers per query
max_parallel_workers = 8                # Total parallel workers
max_parallel_maintenance_workers = 4    # For maintenance operations

# Logging Configuration
log_destination = 'stderr'
logging_collector = on
log_directory = 'log'
log_filename = 'postgresql-%Y-%m-%d_%H%M%S.log'
log_statement = 'ddl'                   # Log DDL statements
log_duration = on                       # Log query duration
log_min_duration_statement = 1000       # Log slow queries (1 second)
log_line_prefix = '%t [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h '

# Statistics Collection
shared_preload_libraries = 'pg_stat_statements'
track_activity_query_size = 2048
track_io_timing = on
track_functions = all
```

### 3. Database Schema Design

```sql
-- init-scripts/01-schema.sql
-- Create extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";

-- Users table with optimized indexing
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    role VARCHAR(50) DEFAULT 'student',
    country VARCHAR(3), -- ISO country code
    subscription_tier VARCHAR(20) DEFAULT 'free',
    is_active BOOLEAN DEFAULT true,
    last_login_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Courses table for content management
CREATE TABLE courses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title VARCHAR(255) NOT NULL,
    slug VARCHAR(255) UNIQUE NOT NULL,
    description TEXT,
    category_id UUID REFERENCES categories(id),
    instructor_id UUID REFERENCES users(id),
    level VARCHAR(20) DEFAULT 'beginner',
    duration_minutes INTEGER,
    price DECIMAL(10,2) DEFAULT 0,
    is_published BOOLEAN DEFAULT false,
    enrollment_count INTEGER DEFAULT 0,
    rating DECIMAL(3,2) DEFAULT 0,
    metadata JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Lessons table with content storage
CREATE TABLE lessons (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    course_id UUID REFERENCES courses(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    slug VARCHAR(255) NOT NULL,
    content TEXT,
    video_url VARCHAR(500),
    duration_minutes INTEGER,
    order_position INTEGER NOT NULL,
    is_free BOOLEAN DEFAULT false,
    resources JSONB, -- Additional resources, files, etc.
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(course_id, slug),
    UNIQUE(course_id, order_position)
);

-- User progress tracking
CREATE TABLE user_progress (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    lesson_id UUID REFERENCES lessons(id) ON DELETE CASCADE,
    course_id UUID REFERENCES courses(id) ON DELETE CASCADE,
    completion_percentage INTEGER DEFAULT 0 CHECK (completion_percentage >= 0 AND completion_percentage <= 100),
    time_spent_minutes INTEGER DEFAULT 0,
    is_completed BOOLEAN DEFAULT false,
    last_accessed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    completed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, lesson_id)
);

-- Quiz and assessment system
CREATE TABLE quizzes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    lesson_id UUID REFERENCES lessons(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    questions JSONB NOT NULL, -- Store questions and answers
    passing_score INTEGER DEFAULT 70,
    time_limit_minutes INTEGER,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- User quiz attempts
CREATE TABLE quiz_attempts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    quiz_id UUID REFERENCES quizzes(id) ON DELETE CASCADE,
    score INTEGER NOT NULL,
    answers JSONB NOT NULL, -- User's answers
    time_taken_minutes INTEGER,
    is_passed BOOLEAN DEFAULT false,
    attempt_number INTEGER DEFAULT 1,
    started_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    completed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

### 4. Advanced Indexing Strategy

```sql
-- init-scripts/02-indexes.sql
-- Primary indexes for user operations
CREATE INDEX idx_users_email_lower ON users (LOWER(email));
CREATE INDEX idx_users_role_active ON users (role, is_active) WHERE is_active = true;
CREATE INDEX idx_users_country ON users (country) WHERE country IS NOT NULL;
CREATE INDEX idx_users_subscription ON users (subscription_tier, is_active);
CREATE INDEX idx_users_last_login ON users (last_login_at DESC) WHERE last_login_at IS NOT NULL;

-- Course discovery and search indexes
CREATE INDEX idx_courses_published ON courses (is_published, created_at DESC) WHERE is_published = true;
CREATE INDEX idx_courses_category ON courses (category_id, is_published) WHERE is_published = true;
CREATE INDEX idx_courses_instructor ON courses (instructor_id, is_published) WHERE is_published = true;
CREATE INDEX idx_courses_level ON courses (level, is_published) WHERE is_published = true;
CREATE INDEX idx_courses_rating ON courses (rating DESC, enrollment_count DESC) WHERE is_published = true;

-- Full-text search for courses
CREATE INDEX idx_courses_search ON courses USING GIN (
    to_tsvector('english', title || ' ' || COALESCE(description, ''))
) WHERE is_published = true;

-- JSONB indexes for metadata
CREATE INDEX idx_courses_metadata ON courses USING GIN (metadata);

-- Lesson ordering and access indexes
CREATE INDEX idx_lessons_course_order ON lessons (course_id, order_position);
CREATE INDEX idx_lessons_course_slug ON lessons (course_id, slug);

-- User progress tracking indexes
CREATE INDEX idx_user_progress_user_course ON user_progress (user_id, course_id);
CREATE INDEX idx_user_progress_completion ON user_progress (user_id, is_completed, last_accessed_at DESC);
CREATE INDEX idx_user_progress_course_stats ON user_progress (course_id, is_completed);

-- Quiz and assessment indexes
CREATE INDEX idx_quizzes_lesson ON quizzes (lesson_id, is_active) WHERE is_active = true;
CREATE INDEX idx_quiz_attempts_user ON quiz_attempts (user_id, created_at DESC);
CREATE INDEX idx_quiz_attempts_quiz ON quiz_attempts (quiz_id, score DESC);
CREATE INDEX idx_quiz_attempts_user_quiz ON quiz_attempts (user_id, quiz_id, attempt_number DESC);

-- Composite indexes for common queries
CREATE INDEX idx_courses_discovery ON courses (category_id, level, rating DESC, enrollment_count DESC) 
    WHERE is_published = true;
CREATE INDEX idx_user_learning_path ON user_progress (user_id, course_id, completion_percentage DESC, last_accessed_at DESC);
```

### 5. Database Functions and Triggers

```sql
-- init-scripts/03-functions.sql
-- Update timestamp trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply update triggers to relevant tables
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_courses_updated_at BEFORE UPDATE ON courses 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_lessons_updated_at BEFORE UPDATE ON lessons 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Function to calculate course completion percentage
CREATE OR REPLACE FUNCTION calculate_course_completion(p_user_id UUID, p_course_id UUID)
RETURNS INTEGER AS $$
DECLARE
    total_lessons INTEGER;
    completed_lessons INTEGER;
    completion_percentage INTEGER;
BEGIN
    -- Get total lessons in course
    SELECT COUNT(*) INTO total_lessons
    FROM lessons 
    WHERE course_id = p_course_id;

    -- Get completed lessons for user
    SELECT COUNT(*) INTO completed_lessons
    FROM user_progress 
    WHERE user_id = p_user_id 
      AND course_id = p_course_id 
      AND is_completed = true;

    -- Calculate percentage
    IF total_lessons = 0 THEN
        completion_percentage := 0;
    ELSE
        completion_percentage := ROUND((completed_lessons::DECIMAL / total_lessons::DECIMAL) * 100);
    END IF;

    RETURN completion_percentage;
END;
$$ LANGUAGE plpgsql;

-- Function to update course statistics
CREATE OR REPLACE FUNCTION update_course_stats()
RETURNS TRIGGER AS $$
BEGIN
    -- Update enrollment count and rating when user progress changes
    UPDATE courses 
    SET 
        enrollment_count = (
            SELECT COUNT(DISTINCT user_id) 
            FROM user_progress 
            WHERE course_id = NEW.course_id
        ),
        updated_at = NOW()
    WHERE id = NEW.course_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to update course stats
CREATE TRIGGER trigger_update_course_stats 
    AFTER INSERT OR UPDATE OR DELETE ON user_progress
    FOR EACH ROW EXECUTE FUNCTION update_course_stats();
```

## 🍃 MongoDB Implementation

### 1. MongoDB Docker Setup

```yaml
# docker-compose.mongodb.yml
version: '3.8'
services:
  mongodb:
    image: mongo:6.0
    container_name: edtech_mongodb
    environment:
      MONGO_INITDB_ROOT_USERNAME: admin
      MONGO_INITDB_ROOT_PASSWORD: ${MONGO_ROOT_PASSWORD}
      MONGO_INITDB_DATABASE: edtech_db
    ports:
      - "27017:27017"
    volumes:
      - mongodb_data:/data/db
      - mongodb_config:/data/configdb
      - ./mongo-init:/docker-entrypoint-initdb.d
      - ./mongod.conf:/etc/mongod.conf
    command: mongod --config /etc/mongod.conf
    restart: unless-stopped
    healthcheck:
      test: echo 'db.runCommand("ping").ok' | mongosh localhost:27017/test --quiet
      interval: 30s
      timeout: 10s
      retries: 3

  mongo-express:
    image: mongo-express:latest
    container_name: edtech_mongo_express
    environment:
      ME_CONFIG_MONGODB_ADMINUSERNAME: admin
      ME_CONFIG_MONGODB_ADMINPASSWORD: ${MONGO_ROOT_PASSWORD}
      ME_CONFIG_MONGODB_SERVER: mongodb
      ME_CONFIG_BASICAUTH_USERNAME: admin
      ME_CONFIG_BASICAUTH_PASSWORD: ${MONGO_EXPRESS_PASSWORD}
    ports:
      - "8081:8081"
    depends_on:
      mongodb:
        condition: service_healthy

volumes:
  mongodb_data:
  mongodb_config:
```

### 2. MongoDB Configuration

```yaml
# mongod.conf
systemLog:
  destination: file
  path: /var/log/mongodb/mongod.log
  logAppend: true
  logRotate: reopen

net:
  port: 27017
  bindIp: 0.0.0.0
  maxIncomingConnections: 1000

processManagement:
  timeZoneInfo: /usr/share/zoneinfo

security:
  authorization: enabled

storage:
  dbPath: /data/db
  engine: wiredTiger
  wiredTiger:
    engineConfig:
      cacheSizeGB: 4  # 50% of available RAM
      directoryForIndexes: true
    collectionConfig:
      blockCompressor: snappy
    indexConfig:
      prefixCompression: true

operationProfiling:
  mode: slowOp
  slowOpThresholdMs: 1000

replication:
  replSetName: "edtech-rs"

setParameter:
  failIndexKeyTooLong: false
  notablescan: 0
```

### 3. MongoDB Schema Design

```javascript
// mongo-init/01-init.js
// Switch to application database
db = db.getSiblingDB('edtech_db');

// Create application user
db.createUser({
  user: 'edtech_user',
  pwd: 'your_secure_password_here',
  roles: [
    { role: 'readWrite', db: 'edtech_db' },
    { role: 'dbAdmin', db: 'edtech_db' }
  ]
});

// Users collection with validation schema
db.createCollection('users', {
  validator: {
    $jsonSchema: {
      bsonType: 'object',
      required: ['email', 'password_hash', 'first_name', 'last_name'],
      properties: {
        email: {
          bsonType: 'string',
          pattern: '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
        },
        password_hash: { bsonType: 'string' },
        first_name: { bsonType: 'string', maxLength: 100 },
        last_name: { bsonType: 'string', maxLength: 100 },
        role: { 
          bsonType: 'string', 
          enum: ['student', 'instructor', 'admin'] 
        },
        country: { 
          bsonType: 'string', 
          maxLength: 3 
        },
        subscription_tier: {
          bsonType: 'string',
          enum: ['free', 'basic', 'premium', 'enterprise']
        },
        is_active: { bsonType: 'bool' },
        last_login_at: { bsonType: 'date' },
        created_at: { bsonType: 'date' },
        updated_at: { bsonType: 'date' }
      }
    }
  }
});

// Courses collection for content management
db.createCollection('courses', {
  validator: {
    $jsonSchema: {
      bsonType: 'object',
      required: ['title', 'slug', 'instructor_id'],
      properties: {
        title: { bsonType: 'string', maxLength: 255 },
        slug: { bsonType: 'string', maxLength: 255 },
        description: { bsonType: 'string' },
        category_id: { bsonType: 'objectId' },
        instructor_id: { bsonType: 'objectId' },
        level: {
          bsonType: 'string',
          enum: ['beginner', 'intermediate', 'advanced']
        },
        duration_minutes: { bsonType: 'int', minimum: 0 },
        price: { bsonType: 'decimal' },
        is_published: { bsonType: 'bool' },
        enrollment_count: { bsonType: 'int', minimum: 0 },
        rating: { 
          bsonType: 'decimal', 
          minimum: 0, 
          maximum: 5 
        },
        tags: {
          bsonType: 'array',
          items: { bsonType: 'string' }
        },
        metadata: { bsonType: 'object' },
        lessons: {
          bsonType: 'array',
          items: {
            bsonType: 'object',
            required: ['title', 'order_position'],
            properties: {
              title: { bsonType: 'string' },
              slug: { bsonType: 'string' },
              content: { bsonType: 'string' },
              video_url: { bsonType: 'string' },
              duration_minutes: { bsonType: 'int' },
              order_position: { bsonType: 'int' },
              is_free: { bsonType: 'bool' },
              resources: { bsonType: 'object' }
            }
          }
        },
        created_at: { bsonType: 'date' },
        updated_at: { bsonType: 'date' }
      }
    }
  }
});

// User progress tracking
db.createCollection('user_progress', {
  validator: {
    $jsonSchema: {
      bsonType: 'object',
      required: ['user_id', 'course_id'],
      properties: {
        user_id: { bsonType: 'objectId' },
        course_id: { bsonType: 'objectId' },
        lesson_progress: {
          bsonType: 'array',
          items: {
            bsonType: 'object',
            required: ['lesson_id', 'completion_percentage'],
            properties: {
              lesson_id: { bsonType: 'objectId' },
              completion_percentage: {
                bsonType: 'int',
                minimum: 0,
                maximum: 100
              },
              time_spent_minutes: { bsonType: 'int' },
              is_completed: { bsonType: 'bool' },
              last_accessed_at: { bsonType: 'date' },
              completed_at: { bsonType: 'date' }
            }
          }
        },
        overall_completion_percentage: {
          bsonType: 'int',
          minimum: 0,
          maximum: 100
        },
        total_time_spent: { bsonType: 'int' },
        last_accessed_at: { bsonType: 'date' },
        started_at: { bsonType: 'date' },
        completed_at: { bsonType: 'date' }
      }
    }
  }
});

// Quiz attempts collection
db.createCollection('quiz_attempts', {
  validator: {
    $jsonSchema: {
      bsonType: 'object',
      required: ['user_id', 'course_id', 'quiz_id', 'score'],
      properties: {
        user_id: { bsonType: 'objectId' },
        course_id: { bsonType: 'objectId' },
        quiz_id: { bsonType: 'objectId' },
        score: { 
          bsonType: 'int',
          minimum: 0,
          maximum: 100
        },
        answers: {
          bsonType: 'array',
          items: { bsonType: 'object' }
        },
        time_taken_minutes: { bsonType: 'int' },
        is_passed: { bsonType: 'bool' },
        attempt_number: { bsonType: 'int', minimum: 1 },
        started_at: { bsonType: 'date' },
        completed_at: { bsonType: 'date' }
      }
    }
  }
});
```

### 4. MongoDB Indexing Strategy

```javascript
// mongo-init/02-indexes.js
db = db.getSiblingDB('edtech_db');

// Users collection indexes
db.users.createIndex({ "email": 1 }, { unique: true });
db.users.createIndex({ "role": 1, "is_active": 1 });
db.users.createIndex({ "country": 1 });
db.users.createIndex({ "subscription_tier": 1, "is_active": 1 });
db.users.createIndex({ "last_login_at": -1 });

// Courses collection indexes
db.courses.createIndex({ "slug": 1 }, { unique: true });
db.courses.createIndex({ "is_published": 1, "created_at": -1 });
db.courses.createIndex({ "category_id": 1, "is_published": 1 });
db.courses.createIndex({ "instructor_id": 1, "is_published": 1 });
db.courses.createIndex({ "level": 1, "is_published": 1 });
db.courses.createIndex({ "rating": -1, "enrollment_count": -1 });
db.courses.createIndex({ "tags": 1 });

// Text search index for courses
db.courses.createIndex({ 
  "title": "text", 
  "description": "text",
  "tags": "text"
}, {
  weights: {
    "title": 10,
    "description": 5,
    "tags": 3
  },
  name: "course_text_search"
});

// Compound indexes for course discovery
db.courses.createIndex({ 
  "category_id": 1, 
  "level": 1, 
  "rating": -1, 
  "enrollment_count": -1 
});

// Lessons embedded in courses - no separate indexes needed
// but ensure proper array indexing for queries

// User progress indexes
db.user_progress.createIndex({ "user_id": 1, "course_id": 1 }, { unique: true });
db.user_progress.createIndex({ "user_id": 1, "last_accessed_at": -1 });
db.user_progress.createIndex({ "course_id": 1, "overall_completion_percentage": -1 });
db.user_progress.createIndex({ "lesson_progress.lesson_id": 1 });
db.user_progress.createIndex({ "lesson_progress.is_completed": 1, "lesson_progress.completed_at": -1 });

// Quiz attempts indexes
db.quiz_attempts.createIndex({ "user_id": 1, "course_id": 1, "completed_at": -1 });
db.quiz_attempts.createIndex({ "quiz_id": 1, "score": -1 });
db.quiz_attempts.createIndex({ "user_id": 1, "quiz_id": 1, "attempt_number": -1 });

// TTL index for temporary data (e.g., session data, temp uploads)
db.sessions.createIndex({ "expires_at": 1 }, { expireAfterSeconds: 0 });

print("✅ All indexes created successfully");
```

## 🔧 Connection Management

### PostgreSQL Connection with Node.js

```typescript
// src/config/database.ts
import { Pool, PoolConfig } from 'pg';
import { config } from './env';

const poolConfig: PoolConfig = {
  host: config.database.host,
  port: config.database.port,
  database: config.database.name,
  user: config.database.user,
  password: config.database.password,
  
  // Connection pool settings
  min: 5,              // Minimum connections
  max: 100,            // Maximum connections
  idleTimeoutMillis: 30000,  // Close idle connections after 30s
  connectionTimeoutMillis: 2000,  // Timeout for new connections
  
  // SSL configuration for production
  ssl: config.nodeEnv === 'production' ? {
    rejectUnauthorized: false
  } : false,
  
  // Query timeout
  query_timeout: 60000,
  
  // Connection validation
  application_name: 'edtech-api',
};

export const pool = new Pool(poolConfig);

// Graceful shutdown
process.on('SIGINT', async () => {
  console.log('Closing PostgreSQL connection pool...');
  await pool.end();
  process.exit(0);
});

// Error handling
pool.on('error', (err, client) => {
  console.error('Unexpected error on idle client', err);
  process.exit(-1);
});

// Connection monitoring
pool.on('connect', (client) => {
  console.log('New PostgreSQL client connected');
});

pool.on('remove', (client) => {
  console.log('PostgreSQL client removed from pool');
});

// Helper function for transactions
export async function withTransaction<T>(
  callback: (client: any) => Promise<T>
): Promise<T> {
  const client = await pool.connect();
  
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
```

### MongoDB Connection with Node.js

```typescript
// src/config/mongodb.ts
import { MongoClient, MongoClientOptions, Db } from 'mongodb';
import { config } from './env';

const mongoOptions: MongoClientOptions = {
  maxPoolSize: 100,           // Maximum connection pool size
  minPoolSize: 5,             // Minimum connection pool size
  maxIdleTimeMS: 30000,       // Close idle connections after 30s
  serverSelectionTimeoutMS: 5000,  // Timeout for server selection
  socketTimeoutMS: 45000,     // Socket timeout
  connectTimeoutMS: 10000,    // Connection timeout
  
  // Write concern for data durability
  writeConcern: {
    w: 'majority',
    j: true,                  // Journal acknowledgment
    wtimeout: 5000           // Write timeout
  },
  
  // Read preference
  readPreference: 'primary',
  
  // Compression
  compressors: ['snappy', 'zlib'],
  
  // Authentication
  authSource: 'edtech_db',
  
  // Monitoring
  monitorCommands: true,
};

class MongoDBConnection {
  private client: MongoClient | null = null;
  private db: Db | null = null;

  async connect(): Promise<void> {
    try {
      this.client = new MongoClient(config.mongodb.connectionString, mongoOptions);
      await this.client.connect();
      this.db = this.client.db(config.mongodb.databaseName);
      
      console.log('✅ Connected to MongoDB');
      
      // Test connection
      await this.db.admin().ping();
      console.log('✅ MongoDB ping successful');
      
    } catch (error) {
      console.error('❌ MongoDB connection failed:', error);
      throw error;
    }
  }

  getDb(): Db {
    if (!this.db) {
      throw new Error('MongoDB not connected. Call connect() first.');
    }
    return this.db;
  }

  async disconnect(): Promise<void> {
    if (this.client) {
      await this.client.close();
      console.log('✅ Disconnected from MongoDB');
    }
  }

  // Health check
  async healthCheck(): Promise<boolean> {
    try {
      if (!this.db) return false;
      await this.db.admin().ping();
      return true;
    } catch {
      return false;
    }
  }
}

export const mongoConnection = new MongoDBConnection();

// Graceful shutdown
process.on('SIGINT', async () => {
  console.log('Closing MongoDB connection...');
  await mongoConnection.disconnect();
  process.exit(0);
});

// Helper function for transactions (MongoDB 4.0+)
export async function withTransaction<T>(
  callback: (session: any) => Promise<T>
): Promise<T> {
  const client = mongoConnection['client'];
  if (!client) {
    throw new Error('MongoDB client not available');
  }

  const session = client.startSession();
  
  try {
    return await session.withTransaction(async () => {
      return await callback(session);
    });
  } finally {
    await session.endSession();
  }
}
```

## 🔍 Monitoring & Performance

### PostgreSQL Monitoring Setup

```sql
-- Monitor query performance
SELECT 
    query,
    calls,
    total_time,
    mean_time,
    stddev_time,
    rows,
    100.0 * shared_blks_hit / nullif(shared_blks_hit + shared_blks_read, 0) AS hit_percent
FROM pg_stat_statements 
ORDER BY total_time DESC 
LIMIT 20;

-- Monitor index usage
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_tup_read,
    idx_tup_fetch,
    idx_scan
FROM pg_stat_user_indexes 
ORDER BY idx_scan DESC;

-- Monitor connection usage
SELECT 
    state,
    count(*) as connections,
    max(now() - state_change) as max_duration
FROM pg_stat_activity 
GROUP BY state
ORDER BY count(*) DESC;
```

### MongoDB Performance Monitoring

```javascript
// MongoDB performance monitoring queries
// Check slow operations
db.runCommand({profile: 2, slowms: 1000});

// View current operations
db.currentOp();

// Check index usage
db.courses.aggregate([
  {$indexStats: {}},
  {$sort: {"accesses.ops": -1}}
]);

// Monitor collection statistics
db.courses.stats();

// Check replication lag (if using replica sets)
rs.printReplicationInfo();
rs.printSlaveReplicationInfo();
```

## 🚀 Deployment Considerations

### Environment Configuration

```bash
# .env.production
# PostgreSQL Configuration
POSTGRES_HOST=your-postgres-host.com
POSTGRES_PORT=5432
POSTGRES_DB=edtech_production
POSTGRES_USER=edtech_user
POSTGRES_PASSWORD=secure_password_here
POSTGRES_SSL=true

# MongoDB Configuration  
MONGODB_CONNECTION_STRING=mongodb+srv://username:password@cluster.mongodb.net/
MONGODB_DATABASE_NAME=edtech_production

# Connection Pool Settings
DB_POOL_MIN=10
DB_POOL_MAX=200
DB_CONNECTION_TIMEOUT=5000
DB_IDLE_TIMEOUT=30000

# Monitoring
ENABLE_QUERY_LOGGING=true
SLOW_QUERY_THRESHOLD=1000
ENABLE_PERFORMANCE_MONITORING=true
```

### Docker Production Setup

```dockerfile
# Dockerfile for production API
FROM node:18-alpine AS builder

WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

FROM node:18-alpine AS runtime

# Install PostgreSQL client for migrations
RUN apk add --no-cache postgresql-client

WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY . .

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
  CMD node healthcheck.js

EXPOSE 3000
CMD ["npm", "start"]
```

This implementation guide provides a solid foundation for setting up both PostgreSQL and MongoDB with optimal configurations for EdTech applications. The next sections will cover performance analysis, security considerations, and migration strategies.

---

⬅️ **[Previous: Executive Summary](./executive-summary.md)**  
➡️ **[Next: Best Practices](./best-practices.md)**  
🏠 **[Research Home](../../README.md)**

---

*Implementation Guide - Complete setup and configuration for optimized database systems*