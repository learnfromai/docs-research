# Implementation Guide: Database Management Tools

## 🎯 Overview

This guide provides step-by-step instructions for implementing pgAdmin, MongoDB Compass, and Redis CLI in an EdTech development environment. Designed for Filipino developers working on international remote projects with focus on Khan Academy-style educational platforms.

## 🛠️ Prerequisites

### System Requirements
- **Operating System**: macOS, Windows 10+, or Linux (Ubuntu 20.04+ recommended)
- **Memory**: Minimum 8GB RAM (16GB+ recommended for development)
- **Storage**: 20GB+ available space for databases and tools
- **Network**: Stable internet connection for cloud database access

### Development Environment
```bash
# Required tools
- Docker Desktop
- Node.js 18+ (for application development)
- Git (for version control)
- Code editor (VS Code recommended)
```

## 📦 Phase 1: Docker Development Environment

### 1.1 Docker Compose Setup

Create a `docker-compose.yml` file for your development environment:

```yaml
version: '3.8'

services:
  # PostgreSQL with pgAdmin
  postgres:
    image: postgres:15-alpine
    container_name: edtech_postgres
    environment:
      POSTGRES_DB: edtech_db
      POSTGRES_USER: edtech_user
      POSTGRES_PASSWORD: secure_password_123
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./init-scripts:/docker-entrypoint-initdb.d
    networks:
      - edtech_network

  pgadmin:
    image: dpage/pgadmin4:latest
    container_name: edtech_pgadmin
    environment:
      PGADMIN_DEFAULT_EMAIL: admin@edtech.local
      PGADMIN_DEFAULT_PASSWORD: admin123
      PGADMIN_LISTEN_PORT: 80
    ports:
      - "8080:80"
    volumes:
      - pgadmin_data:/var/lib/pgadmin
    depends_on:
      - postgres
    networks:
      - edtech_network

  # MongoDB
  mongodb:
    image: mongo:7
    container_name: edtech_mongodb
    environment:
      MONGO_INITDB_ROOT_USERNAME: admin
      MONGO_INITDB_ROOT_PASSWORD: secure_mongo_123
      MONGO_INITDB_DATABASE: edtech_content
    ports:
      - "27017:27017"
    volumes:
      - mongodb_data:/data/db
      - ./mongo-init:/docker-entrypoint-initdb.d
    networks:
      - edtech_network

  # Redis
  redis:
    image: redis:7-alpine
    container_name: edtech_redis
    command: redis-server --requirepass secure_redis_123 --appendonly yes
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    networks:
      - edtech_network

  # Redis Commander (Web UI for Redis)
  redis-commander:
    image: rediscommander/redis-commander:latest
    container_name: redis_commander
    environment:
      REDIS_HOSTS: local:edtech_redis:6379:0:secure_redis_123
    ports:
      - "8081:8081"
    depends_on:
      - redis
    networks:
      - edtech_network

volumes:
  postgres_data:
  pgadmin_data:
  mongodb_data:
  redis_data:

networks:
  edtech_network:
    driver: bridge
```

### 1.2 Initialize Development Environment

```bash
# Create project directory
mkdir edtech-database-setup
cd edtech-database-setup

# Create init scripts directory
mkdir -p init-scripts mongo-init

# Create PostgreSQL initialization script
cat > init-scripts/01-init-edtech-schema.sql << 'EOF'
-- EdTech Database Schema Initialization

-- Users table
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    username VARCHAR(50) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    role VARCHAR(20) DEFAULT 'student',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Courses table
CREATE TABLE courses (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    category VARCHAR(100),
    difficulty_level VARCHAR(20),
    created_by INTEGER REFERENCES users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- User progress table
CREATE TABLE user_progress (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    course_id INTEGER REFERENCES courses(id),
    completion_percentage DECIMAL(5,2) DEFAULT 0.00,
    last_accessed TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, course_id)
);

-- Create indexes for performance
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_user_progress_user_id ON user_progress(user_id);
CREATE INDEX idx_user_progress_course_id ON user_progress(course_id);

-- Insert sample data
INSERT INTO users (email, username, password_hash, first_name, last_name, role) VALUES
('admin@edtech.local', 'admin', '$2b$12$dummy_hash', 'Admin', 'User', 'administrator'),
('student@edtech.local', 'student', '$2b$12$dummy_hash', 'Test', 'Student', 'student'),
('instructor@edtech.local', 'instructor', '$2b$12$dummy_hash', 'Test', 'Instructor', 'instructor');

INSERT INTO courses (title, description, category, difficulty_level, created_by) VALUES
('Philippine Bar Exam Review', 'Comprehensive review for Philippine Bar Examination', 'Law', 'Advanced', 1),
('CPA Board Exam Preparation', 'Complete preparation for CPA board examination', 'Accounting', 'Advanced', 1),
('Nursing Licensure Exam Review', 'Review materials for nursing licensure examination', 'Healthcare', 'Intermediate', 1);
EOF

# Create MongoDB initialization script
cat > mongo-init/01-init-content.js << 'EOF'
// EdTech Content Database Initialization

db = db.getSiblingDB('edtech_content');

// Create collections and insert sample content
db.lessons.insertMany([
  {
    courseId: "bar_exam_review",
    title: "Constitutional Law Fundamentals",
    type: "video",
    content: {
      videoUrl: "https://example.com/video1",
      duration: 3600,
      transcript: "Constitutional law is the foundation..."
    },
    tags: ["constitutional-law", "fundamentals", "bar-exam"],
    metadata: {
      difficulty: "intermediate",
      estimatedTime: 60,
      language: "en-PH"
    },
    createdAt: new Date(),
    updatedAt: new Date()
  },
  {
    courseId: "cpa_exam_prep",
    title: "Financial Accounting Principles",
    type: "interactive",
    content: {
      sections: [
        {
          title: "Balance Sheet Analysis",
          exercises: [
            {
              question: "Calculate the current ratio",
              type: "calculation",
              difficulty: "medium"
            }
          ]
        }
      ]
    },
    tags: ["accounting", "financial", "cpa"],
    metadata: {
      difficulty: "advanced",
      estimatedTime: 90,
      language: "en-PH"
    },
    createdAt: new Date(),
    updatedAt: new Date()
  }
]);

db.quizzes.insertMany([
  {
    courseId: "bar_exam_review",
    title: "Constitutional Law Quiz",
    questions: [
      {
        question: "What is the supreme law of the Philippines?",
        type: "multiple_choice",
        options: [
          "Civil Code",
          "Constitution",
          "Revised Penal Code",
          "Labor Code"
        ],
        correctAnswer: 1,
        explanation: "The Constitution is the supreme law of the land."
      }
    ],
    settings: {
      timeLimit: 1800,
      shuffleQuestions: true,
      showResults: true
    },
    createdAt: new Date()
  }
]);

// Create indexes for performance
db.lessons.createIndex({ courseId: 1 });
db.lessons.createIndex({ tags: 1 });
db.lessons.createIndex({ "metadata.difficulty": 1 });
db.quizzes.createIndex({ courseId: 1 });
EOF

# Start the services
docker-compose up -d

# Wait for services to start
echo "Waiting for services to initialize..."
sleep 30

# Check service status
docker-compose ps
```

## 🔧 Phase 2: pgAdmin Configuration

### 2.1 Access pgAdmin

1. Open browser and navigate to `http://localhost:8080`
2. Login with credentials:
   - **Email**: `admin@edtech.local`
   - **Password**: `admin123`

### 2.2 Add PostgreSQL Server

1. Right-click "Servers" → "Register" → "Server"
2. **General Tab**:
   - Name: `EdTech PostgreSQL`
3. **Connection Tab**:
   - Host: `edtech_postgres`
   - Port: `5432`
   - Database: `edtech_db`
   - Username: `edtech_user`
   - Password: `secure_password_123`

### 2.3 Essential pgAdmin Configuration

```sql
-- Create additional schemas for organization
CREATE SCHEMA analytics;
CREATE SCHEMA content_management;
CREATE SCHEMA user_management;

-- Set up roles and permissions
CREATE ROLE edtech_read_only;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO edtech_read_only;

CREATE ROLE edtech_analytics;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO edtech_analytics;
GRANT ALL ON SCHEMA analytics TO edtech_analytics;

-- Enable extensions for better functionality
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";
```

### 2.4 pgAdmin Query Tool Setup

Essential queries for EdTech monitoring:

```sql
-- Monitor user engagement
SELECT 
    u.role,
    COUNT(*) as user_count,
    AVG(up.completion_percentage) as avg_completion
FROM users u
LEFT JOIN user_progress up ON u.id = up.user_id
GROUP BY u.role;

-- Course popularity analysis
SELECT 
    c.title,
    c.category,
    COUNT(up.user_id) as enrolled_users,
    AVG(up.completion_percentage) as avg_completion
FROM courses c
LEFT JOIN user_progress up ON c.id = up.course_id
GROUP BY c.id, c.title, c.category
ORDER BY enrolled_users DESC;

-- Performance monitoring query
SELECT 
    schemaname,
    tablename,
    attname,
    n_distinct,
    correlation
FROM pg_stats 
WHERE schemaname = 'public'
ORDER BY tablename, attname;
```

## 🍃 Phase 3: MongoDB Compass Setup

### 3.1 Install MongoDB Compass

**macOS:**
```bash
# Using Homebrew
brew install --cask mongodb-compass

# Or download from MongoDB website
# https://www.mongodb.com/products/compass
```

**Windows:**
```bash
# Download installer from MongoDB website
# Run the installer and follow setup wizard
```

**Linux (Ubuntu):**
```bash
# Download .deb package
wget https://downloads.mongodb.com/compass/mongodb-compass_1.40.4_amd64.deb

# Install
sudo dpkg -i mongodb-compass_1.40.4_amd64.deb
```

### 3.2 Connect to MongoDB

1. Launch MongoDB Compass
2. Connection string: `mongodb://admin:secure_mongo_123@localhost:27017/edtech_content?authSource=admin`
3. Click "Connect"

### 3.3 MongoDB Schema Design

Create optimized schemas for EdTech content:

```javascript
// Lesson schema with validation
db.createCollection("lessons", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["courseId", "title", "type", "content"],
      properties: {
        courseId: {
          bsonType: "string",
          description: "must be a string and is required"
        },
        title: {
          bsonType: "string",
          minLength: 5,
          maxLength: 200,
          description: "must be a string between 5-200 characters"
        },
        type: {
          bsonType: "string",
          enum: ["video", "text", "interactive", "quiz"],
          description: "must be one of the enum values"
        },
        content: {
          bsonType: "object",
          description: "must be an object containing lesson content"
        },
        tags: {
          bsonType: "array",
          items: {
            bsonType: "string"
          },
          description: "must be an array of strings"
        },
        metadata: {
          bsonType: "object",
          properties: {
            difficulty: {
              bsonType: "string",
              enum: ["beginner", "intermediate", "advanced"]
            },
            estimatedTime: {
              bsonType: "int",
              minimum: 1,
              maximum: 600
            },
            language: {
              bsonType: "string",
              pattern: "^[a-z]{2}-[A-Z]{2}$"
            }
          }
        }
      }
    }
  }
});

// Create performance indexes
db.lessons.createIndex({ courseId: 1, "metadata.difficulty": 1 });
db.lessons.createIndex({ tags: 1 });
db.lessons.createIndex({ createdAt: -1 });
db.lessons.createIndex({ "content.duration": 1 });
```

### 3.4 Compass Query Examples

Use these queries in Compass query bar:

```javascript
// Find all advanced lessons
{ "metadata.difficulty": "advanced" }

// Find lessons by course and difficulty
{ 
  "courseId": "bar_exam_review", 
  "metadata.difficulty": { "$in": ["intermediate", "advanced"] }
}

// Text search across lessons
{ 
  "$text": { 
    "$search": "constitutional law fundamentals" 
  } 
}

// Aggregation pipeline for content analytics
[
  {
    "$group": {
      "_id": "$courseId",
      "totalLessons": { "$sum": 1 },
      "avgDuration": { "$avg": "$content.duration" },
      "difficulties": { "$addToSet": "$metadata.difficulty" }
    }
  },
  {
    "$sort": { "totalLessons": -1 }
  }
]
```

## ⚡ Phase 4: Redis CLI Optimization

### 4.1 Redis CLI Connection

```bash
# Connect to Redis container
docker exec -it edtech_redis redis-cli -a secure_redis_123

# Or connect from host machine (if Redis CLI installed)
redis-cli -h localhost -p 6379 -a secure_redis_123
```

### 4.2 Essential Redis Commands for EdTech

```bash
# Session management
SET session:user:12345 "{"userId":12345,"role":"student","lastActivity":"2024-01-15T10:30:00Z"}" EX 3600

# User progress caching
HSET user:12345:progress course:101 85.5 course:102 92.0 course:103 67.8

# Leaderboard management
ZADD course:101:leaderboard 95.5 user:12345 88.2 user:67890 92.1 user:54321

# Real-time analytics
INCR daily:page_views:2024-01-15
HINCRBY course:analytics:101 total_views 1
HINCRBY course:analytics:101 unique_users 1

# Caching frequently accessed content
SET content:lesson:456 '{"title":"Constitutional Law","duration":3600,"url":"..."}' EX 7200
```

### 4.3 Redis Performance Optimization

```bash
# Monitor Redis performance
INFO stats
INFO memory
SLOWLOG GET 10

# Configure memory optimization
CONFIG SET maxmemory 2gb
CONFIG SET maxmemory-policy allkeys-lru

# Enable append-only file for persistence
CONFIG SET appendonly yes
CONFIG SET appendfsync everysec

# Monitor keyspace
INFO keyspace
DBSIZE
```

### 4.4 Redis Lua Scripts for EdTech

Create efficient atomic operations:

```lua
-- Update user progress with leaderboard
local function updateProgress(userId, courseId, score)
    local progressKey = "user:" .. userId .. ":progress"
    local leaderboardKey = "course:" .. courseId .. ":leaderboard"
    
    -- Update user progress
    redis.call("HSET", progressKey, courseId, score)
    
    -- Update leaderboard
    redis.call("ZADD", leaderboardKey, score, "user:" .. userId)
    
    -- Update analytics
    local analyticsKey = "course:analytics:" .. courseId
    redis.call("HINCRBY", analyticsKey, "total_completions", 1)
    
    return "OK"
end
```

## 🔐 Phase 5: Security Configuration

### 5.1 PostgreSQL Security

```sql
-- Create secure user roles
CREATE ROLE edtech_app_user WITH LOGIN PASSWORD 'app_secure_pass_123';
GRANT CONNECT ON DATABASE edtech_db TO edtech_app_user;
GRANT USAGE ON SCHEMA public TO edtech_app_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO edtech_app_user;

-- Enable SSL connections
-- Add to postgresql.conf:
-- ssl = on
-- ssl_cert_file = 'server.crt'
-- ssl_key_file = 'server.key'
```

### 5.2 MongoDB Security

```javascript
// Create application user
use edtech_content
db.createUser({
  user: "edtech_app",
  pwd: "mongo_app_secure_123",
  roles: [
    { role: "readWrite", db: "edtech_content" },
    { role: "read", db: "admin" }
  ]
});

// Enable authentication in MongoDB
// Add to mongod.conf:
// security:
//   authorization: enabled
```

### 5.3 Redis Security

```bash
# Configure Redis authentication
CONFIG SET requirepass "redis_production_secure_456"

# Disable dangerous commands
CONFIG SET rename-command FLUSHDB ""
CONFIG SET rename-command FLUSHALL ""
CONFIG SET rename-command DEBUG ""

# Enable SSL/TLS (in redis.conf)
# tls-port 6380
# tls-cert-file /path/to/redis.crt
# tls-key-file /path/to/redis.key
```

## 📊 Phase 6: Monitoring and Maintenance

### 6.1 Health Check Scripts

Create monitoring scripts for each database:

```bash
#!/bin/bash
# health-check.sh

echo "=== Database Health Check ==="

# PostgreSQL health check
echo "PostgreSQL Status:"
docker exec edtech_postgres pg_isready -h localhost -p 5432 -U edtech_user

# MongoDB health check
echo "MongoDB Status:"
docker exec edtech_mongodb mongosh --quiet --eval "db.runCommand('ping')"

# Redis health check
echo "Redis Status:"
docker exec edtech_redis redis-cli -a secure_redis_123 ping

echo "=== Performance Metrics ==="

# PostgreSQL connections
docker exec edtech_postgres psql -U edtech_user -d edtech_db -c "SELECT count(*) as active_connections FROM pg_stat_activity;"

# MongoDB operations
docker exec edtech_mongodb mongosh --quiet --eval "db.serverStatus().opcounters"

# Redis memory usage
docker exec edtech_redis redis-cli -a secure_redis_123 info memory | grep used_memory_human
```

### 6.2 Backup Procedures

```bash
#!/bin/bash
# backup.sh

BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/backups/$BACKUP_DATE"
mkdir -p $BACKUP_DIR

# PostgreSQL backup
docker exec edtech_postgres pg_dump -U edtech_user edtech_db > $BACKUP_DIR/postgres_backup.sql

# MongoDB backup
docker exec edtech_mongodb mongodump --out /tmp/mongo_backup
docker cp edtech_mongodb:/tmp/mongo_backup $BACKUP_DIR/

# Redis backup
docker exec edtech_redis redis-cli -a secure_redis_123 BGSAVE
docker cp edtech_redis:/data/dump.rdb $BACKUP_DIR/

echo "Backup completed: $BACKUP_DIR"
```

## 🚀 Next Steps

1. **Complete Phase 1-2** this week for basic functionality
2. **Optimize Phase 3-4** next week for performance
3. **Implement Phase 5-6** for production readiness

## 🔗 Navigation

- **Previous**: [Executive Summary](./executive-summary.md)
- **Next**: [Best Practices](./best-practices.md)
- **Home**: [Database Management Tools Research](./README.md)

---

*This implementation guide provides practical steps for setting up comprehensive database management tools for EdTech development workflows.*