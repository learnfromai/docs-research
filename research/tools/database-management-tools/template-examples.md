# Template Examples: Database Management Tools

## 🎯 Overview

This document provides ready-to-use templates, configurations, and code examples for implementing pgAdmin, MongoDB Compass, and Redis CLI in EdTech development workflows. All templates are tested and optimized for Philippine licensure exam review platforms.

## 🏗️ Docker Development Environment Templates

### 📦 Complete Docker Compose Stack

#### Production-Ready Docker Compose Configuration
```yaml
# docker-compose.yml - Complete EdTech Database Stack
version: '3.8'

services:
  # PostgreSQL Database
  postgres:
    image: postgres:15-alpine
    container_name: edtech_postgres
    restart: unless-stopped
    environment:
      POSTGRES_DB: ${POSTGRES_DB:-edtech_db}
      POSTGRES_USER: ${POSTGRES_USER:-edtech_user}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-secure_password_123}
      POSTGRES_INITDB_ARGS: "--encoding=UTF-8 --lc-collate=C --lc-ctype=C"
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./init-scripts/postgres:/docker-entrypoint-initdb.d
      - ./backups:/backups
    networks:
      - edtech_network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER:-edtech_user} -d ${POSTGRES_DB:-edtech_db}"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s

  # pgAdmin Web Interface
  pgadmin:
    image: dpage/pgadmin4:latest
    container_name: edtech_pgadmin
    restart: unless-stopped
    environment:
      PGADMIN_DEFAULT_EMAIL: ${PGADMIN_EMAIL:-admin@edtech.local}
      PGADMIN_DEFAULT_PASSWORD: ${PGADMIN_PASSWORD:-admin123}
      PGADMIN_LISTEN_PORT: 80
      PGADMIN_CONFIG_SERVER_MODE: 'False'
      PGADMIN_CONFIG_MASTER_PASSWORD_REQUIRED: 'False'
    ports:
      - "8080:80"
    volumes:
      - pgadmin_data:/var/lib/pgadmin
      - ./pgadmin-config:/pgadmin4/servers.json
    depends_on:
      postgres:
        condition: service_healthy
    networks:
      - edtech_network

  # MongoDB Database
  mongodb:
    image: mongo:7
    container_name: edtech_mongodb
    restart: unless-stopped
    environment:
      MONGO_INITDB_ROOT_USERNAME: ${MONGO_ROOT_USER:-admin}
      MONGO_INITDB_ROOT_PASSWORD: ${MONGO_ROOT_PASSWORD:-secure_mongo_123}
      MONGO_INITDB_DATABASE: ${MONGO_DB:-edtech_content}
    ports:
      - "27017:27017"
    volumes:
      - mongodb_data:/data/db
      - mongodb_config:/data/configdb
      - ./init-scripts/mongodb:/docker-entrypoint-initdb.d
      - ./backups:/backups
    networks:
      - edtech_network
    command: ["mongod", "--auth", "--bind_ip_all"]
    healthcheck:
      test: ["CMD", "mongosh", "--eval", "db.adminCommand('ping')"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s

  # Redis Cache
  redis:
    image: redis:7-alpine
    container_name: edtech_redis
    restart: unless-stopped
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
      - ./redis-config/redis.conf:/usr/local/etc/redis/redis.conf
    networks:
      - edtech_network
    command: ["redis-server", "/usr/local/etc/redis/redis.conf"]
    healthcheck:
      test: ["CMD", "redis-cli", "-a", "${REDIS_PASSWORD:-secure_redis_123}", "ping"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s

  # Redis Commander (Web UI)
  redis-commander:
    image: rediscommander/redis-commander:latest
    container_name: redis_commander
    restart: unless-stopped
    environment:
      REDIS_HOSTS: "local:edtech_redis:6379:0:${REDIS_PASSWORD:-secure_redis_123}"
      HTTP_USER: ${REDIS_COMMANDER_USER:-admin}
      HTTP_PASSWORD: ${REDIS_COMMANDER_PASSWORD:-admin123}
    ports:
      - "8081:8081"
    depends_on:
      redis:
        condition: service_healthy
    networks:
      - edtech_network

  # Backup Service
  backup:
    image: alpine:latest
    container_name: edtech_backup
    restart: "no"
    volumes:
      - ./backups:/backups
      - ./scripts:/scripts
    networks:
      - edtech_network
    depends_on:
      - postgres
      - mongodb
      - redis
    command: ["/scripts/backup.sh"]

volumes:
  postgres_data:
    driver: local
  pgadmin_data:
    driver: local
  mongodb_data:
    driver: local
  mongodb_config:
    driver: local
  redis_data:
    driver: local

networks:
  edtech_network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
```

#### Environment Configuration Template
```bash
# .env - Environment Variables
# PostgreSQL Configuration
POSTGRES_DB=edtech_db
POSTGRES_USER=edtech_user
POSTGRES_PASSWORD=secure_password_123

# pgAdmin Configuration
PGADMIN_EMAIL=admin@edtech.local
PGLADMIN_PASSWORD=admin123

# MongoDB Configuration
MONGO_ROOT_USER=admin
MONGO_ROOT_PASSWORD=secure_mongo_123
MONGO_DB=edtech_content

# Redis Configuration
REDIS_PASSWORD=secure_redis_123

# Redis Commander Configuration
REDIS_COMMANDER_USER=admin
REDIS_COMMANDER_PASSWORD=admin123

# Application Configuration
NODE_ENV=development
LOG_LEVEL=debug
JWT_SECRET=your_jwt_secret_key_here
ENCRYPTION_KEY=your_encryption_key_here

# Cloud Configuration (for production)
AWS_ACCESS_KEY_ID=your_aws_access_key
AWS_SECRET_ACCESS_KEY=your_aws_secret_key
AWS_REGION=ap-southeast-1
```

## 🗄️ PostgreSQL + pgAdmin Templates

### 📋 Complete Schema Template for EdTech Platform
```sql
-- init-scripts/postgres/01-schema.sql
-- EdTech Platform Database Schema

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";

-- Create schemas for organization
CREATE SCHEMA IF NOT EXISTS user_management;
CREATE SCHEMA IF NOT EXISTS content_management;
CREATE SCHEMA IF NOT EXISTS analytics;
CREATE SCHEMA IF NOT EXISTS audit;

-- Set default schema
SET search_path TO public, user_management, content_management;

-- Users table with comprehensive user management
CREATE TABLE user_management.users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    username VARCHAR(50) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    role VARCHAR(20) DEFAULT 'student' CHECK (role IN ('student', 'instructor', 'admin', 'moderator')),
    phone VARCHAR(20),
    date_of_birth DATE,
    address JSONB,
    preferences JSONB DEFAULT '{}',
    timezone VARCHAR(50) DEFAULT 'Asia/Manila',
    language VARCHAR(10) DEFAULT 'en-PH',
    avatar_url VARCHAR(500),
    email_verified BOOLEAN DEFAULT FALSE,
    phone_verified BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    last_login TIMESTAMPTZ,
    login_count INTEGER DEFAULT 0,
    failed_login_attempts INTEGER DEFAULT 0,
    locked_until TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- User sessions for authentication tracking
CREATE TABLE user_management.user_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES user_management.users(id) ON DELETE CASCADE,
    session_token VARCHAR(255) UNIQUE NOT NULL,
    device_info JSONB,
    ip_address INET,
    user_agent TEXT,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    last_activity TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE,
    
    CONSTRAINT valid_expiry CHECK (expires_at > created_at)
);

-- Courses table
CREATE TABLE content_management.courses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(255) NOT NULL,
    slug VARCHAR(255) UNIQUE NOT NULL,
    description TEXT,
    short_description TEXT,
    category VARCHAR(100) NOT NULL,
    subcategory VARCHAR(100),
    difficulty_level VARCHAR(20) DEFAULT 'beginner' CHECK (difficulty_level IN ('beginner', 'intermediate', 'advanced')),
    exam_type VARCHAR(100), -- 'bar', 'cpa', 'nursing', 'engineering', etc.
    language VARCHAR(10) DEFAULT 'en-PH',
    instructor_id UUID REFERENCES user_management.users(id),
    thumbnail_url VARCHAR(500),
    trailer_video_url VARCHAR(500),
    price DECIMAL(10,2) DEFAULT 0.00,
    currency VARCHAR(3) DEFAULT 'PHP',
    estimated_duration INTEGER, -- in minutes
    total_lessons INTEGER DEFAULT 0,
    total_quizzes INTEGER DEFAULT 0,
    prerequisites TEXT[],
    learning_objectives TEXT[],
    tags TEXT[],
    metadata JSONB DEFAULT '{}',
    is_published BOOLEAN DEFAULT FALSE,
    is_featured BOOLEAN DEFAULT FALSE,
    enrollment_count INTEGER DEFAULT 0,
    average_rating DECIMAL(3,2) DEFAULT 0.00,
    total_ratings INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    published_at TIMESTAMPTZ
);

-- User course enrollment and progress
CREATE TABLE user_management.user_course_enrollments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES user_management.users(id) ON DELETE CASCADE,
    course_id UUID REFERENCES content_management.courses(id) ON DELETE CASCADE,
    enrollment_date TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    completion_percentage DECIMAL(5,2) DEFAULT 0.00,
    current_lesson_id UUID,
    total_time_spent INTEGER DEFAULT 0, -- in minutes
    last_accessed TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    completion_date TIMESTAMPTZ,
    certificate_issued BOOLEAN DEFAULT FALSE,
    certificate_url VARCHAR(500),
    final_score DECIMAL(5,2),
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'completed', 'dropped', 'paused')),
    notes TEXT,
    
    UNIQUE(user_id, course_id)
);

-- Detailed lesson progress tracking
CREATE TABLE user_management.user_lesson_progress (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES user_management.users(id) ON DELETE CASCADE,
    course_id UUID REFERENCES content_management.courses(id) ON DELETE CASCADE,
    lesson_id UUID NOT NULL, -- References MongoDB lesson
    enrollment_id UUID REFERENCES user_management.user_course_enrollments(id) ON DELETE CASCADE,
    status VARCHAR(20) DEFAULT 'not_started' CHECK (status IN ('not_started', 'in_progress', 'completed', 'skipped')),
    progress_percentage DECIMAL(5,2) DEFAULT 0.00,
    time_spent INTEGER DEFAULT 0, -- in seconds
    score DECIMAL(5,2),
    attempts INTEGER DEFAULT 0,
    first_accessed TIMESTAMPTZ,
    last_accessed TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    notes TEXT,
    bookmarks JSONB DEFAULT '[]',
    
    UNIQUE(user_id, lesson_id)
);

-- Quiz attempts and results
CREATE TABLE analytics.quiz_attempts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES user_management.users(id) ON DELETE CASCADE,
    course_id UUID REFERENCES content_management.courses(id) ON DELETE CASCADE,
    quiz_id UUID NOT NULL, -- References MongoDB quiz
    attempt_number INTEGER NOT NULL,
    started_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMPTZ,
    time_taken INTEGER, -- in seconds
    total_questions INTEGER,
    correct_answers INTEGER,
    score DECIMAL(5,2),
    percentage DECIMAL(5,2),
    answers JSONB, -- Detailed answer data
    status VARCHAR(20) DEFAULT 'in_progress' CHECK (status IN ('in_progress', 'completed', 'abandoned')),
    
    UNIQUE(user_id, quiz_id, attempt_number)
);

-- User activity logging for analytics
CREATE TABLE analytics.user_activities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES user_management.users(id) ON DELETE CASCADE,
    activity_type VARCHAR(50) NOT NULL,
    resource_type VARCHAR(50), -- 'course', 'lesson', 'quiz', etc.
    resource_id UUID,
    details JSONB DEFAULT '{}',
    session_id UUID,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Audit trail for data changes
CREATE TABLE audit.audit_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    table_name VARCHAR(100) NOT NULL,
    operation VARCHAR(10) NOT NULL CHECK (operation IN ('INSERT', 'UPDATE', 'DELETE')),
    old_values JSONB,
    new_values JSONB,
    user_id UUID,
    timestamp TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    session_id UUID
);

-- Create indexes for performance
CREATE INDEX idx_users_email ON user_management.users(email);
CREATE INDEX idx_users_username ON user_management.users(username);
CREATE INDEX idx_users_role ON user_management.users(role);
CREATE INDEX idx_users_active ON user_management.users(is_active) WHERE is_active = TRUE;

CREATE INDEX idx_user_sessions_user_id ON user_management.user_sessions(user_id);
CREATE INDEX idx_user_sessions_token ON user_management.user_sessions(session_token);
CREATE INDEX idx_user_sessions_expires ON user_management.user_sessions(expires_at);
CREATE INDEX idx_user_sessions_active ON user_management.user_sessions(is_active) WHERE is_active = TRUE;

CREATE INDEX idx_courses_slug ON content_management.courses(slug);
CREATE INDEX idx_courses_category ON content_management.courses(category);
CREATE INDEX idx_courses_exam_type ON content_management.courses(exam_type);
CREATE INDEX idx_courses_published ON content_management.courses(is_published) WHERE is_published = TRUE;
CREATE INDEX idx_courses_featured ON content_management.courses(is_featured) WHERE is_featured = TRUE;

CREATE INDEX idx_enrollments_user_id ON user_management.user_course_enrollments(user_id);
CREATE INDEX idx_enrollments_course_id ON user_management.user_course_enrollments(course_id);
CREATE INDEX idx_enrollments_status ON user_management.user_course_enrollments(status);
CREATE INDEX idx_enrollments_completion ON user_management.user_course_enrollments(completion_percentage);

CREATE INDEX idx_lesson_progress_user_id ON user_management.user_lesson_progress(user_id);
CREATE INDEX idx_lesson_progress_course_id ON user_management.user_lesson_progress(course_id);
CREATE INDEX idx_lesson_progress_lesson_id ON user_management.user_lesson_progress(lesson_id);
CREATE INDEX idx_lesson_progress_status ON user_management.user_lesson_progress(status);

CREATE INDEX idx_quiz_attempts_user_id ON analytics.quiz_attempts(user_id);
CREATE INDEX idx_quiz_attempts_quiz_id ON analytics.quiz_attempts(quiz_id);
CREATE INDEX idx_quiz_attempts_started ON analytics.quiz_attempts(started_at);

CREATE INDEX idx_user_activities_user_id ON analytics.user_activities(user_id);
CREATE INDEX idx_user_activities_type ON analytics.user_activities(activity_type);
CREATE INDEX idx_user_activities_created ON analytics.user_activities(created_at);

CREATE INDEX idx_audit_log_table ON audit.audit_log(table_name);
CREATE INDEX idx_audit_log_operation ON audit.audit_log(operation);
CREATE INDEX idx_audit_log_timestamp ON audit.audit_log(timestamp);
```

### 🔧 pgAdmin Server Configuration Template
```json
{
  "Servers": {
    "1": {
      "Name": "EdTech Local Development",
      "Group": "Servers",
      "Host": "edtech_postgres",
      "Port": 5432,
      "MaintenanceDB": "edtech_db",
      "Username": "edtech_user",
      "PassFile": "/pgadmin4/pgpass",
      "SSLMode": "prefer",
      "SSLCert": "",
      "SSLKey": "",
      "SSLRootCert": "",
      "SSLCrl": "",
      "SSLCompression": 0,
      "Timeout": 10,
      "UseSSHTunnel": 0,
      "TunnelHost": "",
      "TunnelPort": "22",
      "TunnelUsername": "",
      "TunnelAuthentication": 0
    },
    "2": {
      "Name": "EdTech Production",
      "Group": "Servers",
      "Host": "prod-postgres.example.com",
      "Port": 5432,
      "MaintenanceDB": "edtech_prod",
      "Username": "edtech_prod_user",
      "PassFile": "/pgladmin4/pgpass_prod",
      "SSLMode": "require",
      "Timeout": 10,
      "UseSSHTunnel": 1,
      "TunnelHost": "bastion.example.com",
      "TunnelPort": "22",
      "TunnelUsername": "deploy",
      "TunnelAuthentication": 1
    }
  }
}
```

## 🍃 MongoDB Templates

### 📋 MongoDB Initialization Script
```javascript
// init-scripts/mongodb/01-init-collections.js
// EdTech Content Database Initialization

// Switch to the EdTech content database
db = db.getSiblingDB('edtech_content');

// Create application user
db.createUser({
  user: "edtech_app",
  pwd: "secure_app_password_123",
  roles: [
    { role: "readWrite", db: "edtech_content" },
    { role: "read", db: "admin" }
  ]
});

// Lessons collection with comprehensive structure
db.createCollection("lessons", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["courseId", "title", "type", "content", "metadata"],
      properties: {
        courseId: {
          bsonType: "string",
          description: "Course ID reference from PostgreSQL"
        },
        title: {
          bsonType: "string",
          minLength: 5,
          maxLength: 200,
          description: "Lesson title"
        },
        slug: {
          bsonType: "string",
          pattern: "^[a-z0-9-]+$",
          description: "URL-friendly lesson identifier"
        },
        type: {
          bsonType: "string",
          enum: ["video", "text", "interactive", "quiz", "assignment", "live_session"],
          description: "Type of lesson content"
        },
        content: {
          bsonType: "object",
          description: "Lesson content structure"
        },
        metadata: {
          bsonType: "object",
          required: ["difficulty", "estimatedTime", "language"],
          properties: {
            difficulty: {
              bsonType: "string",
              enum: ["beginner", "intermediate", "advanced"]
            },
            estimatedTime: {
              bsonType: "int",
              minimum: 1,
              maximum: 600,
              description: "Estimated time in minutes"
            },
            language: {
              bsonType: "string",
              pattern: "^[a-z]{2}-[A-Z]{2}$",
              description: "Language code (e.g., en-PH, tl-PH)"
            },
            prerequisites: {
              bsonType: "array",
              items: { bsonType: "string" }
            },
            learningObjectives: {
              bsonType: "array",
              items: { bsonType: "string" }
            }
          }
        },
        tags: {
          bsonType: "array",
          items: { bsonType: "string" },
          description: "Content tags for search and categorization"
        },
        status: {
          bsonType: "string",
          enum: ["draft", "review", "published", "archived"],
          description: "Publication status"
        }
      }
    }
  }
});

// Sample lesson documents
db.lessons.insertMany([
  {
    courseId: "bar-exam-constitutional-law",
    title: "Fundamental Rights and Freedoms",
    slug: "fundamental-rights-and-freedoms",
    type: "video",
    content: {
      videoUrl: "https://cdn.edtech.ph/videos/constitutional-law-01.mp4",
      duration: 2400, // 40 minutes
      thumbnailUrl: "https://cdn.edtech.ph/thumbnails/constitutional-law-01.jpg",
      transcripts: [
        {
          language: "en-PH",
          url: "https://cdn.edtech.ph/transcripts/constitutional-law-01-en.vtt",
          content: "The 1987 Philippine Constitution establishes fundamental rights..."
        },
        {
          language: "tl-PH",
          url: "https://cdn.edtech.ph/transcripts/constitutional-law-01-tl.vtt",
          content: "Ang 1987 Saligang Batas ng Pilipinas ay nagtatatag ng mga pangunahing karapatan..."
        }
      ],
      attachments: [
        {
          name: "Constitutional Law Handout",
          type: "pdf",
          url: "https://cdn.edtech.ph/attachments/constitutional-law-handout.pdf",
          size: 2048576 // 2MB
        }
      ],
      interactiveElements: [
        {
          timestamp: 600, // 10 minutes
          type: "quiz",
          question: "What article of the Constitution deals with the Bill of Rights?",
          options: ["Article II", "Article III", "Article IV", "Article V"],
          correctAnswer: 1
        }
      ]
    },
    metadata: {
      difficulty: "intermediate",
      estimatedTime: 45,
      language: "en-PH",
      prerequisites: ["constitutional-law-basics"],
      learningObjectives: [
        "Understand the scope of fundamental rights",
        "Identify key constitutional provisions",
        "Analyze landmark Supreme Court cases"
      ],
      viewCount: 1250,
      averageRating: 4.7,
      totalRatings: 89
    },
    tags: ["constitutional-law", "bill-of-rights", "fundamental-freedoms", "supreme-court"],
    status: "published",
    createdAt: new Date("2024-01-15T10:00:00Z"),
    updatedAt: new Date("2024-01-15T10:00:00Z"),
    publishedAt: new Date("2024-01-15T12:00:00Z")
  },
  {
    courseId: "cpa-financial-accounting",
    title: "Financial Statement Analysis",
    slug: "financial-statement-analysis",
    type: "interactive",
    content: {
      sections: [
        {
          title: "Balance Sheet Analysis",
          content: "Understanding the structure and components of a balance sheet...",
          exercises: [
            {
              type: "calculation",
              question: "Calculate the current ratio given current assets of ₱500,000 and current liabilities of ₱200,000",
              solution: {
                formula: "Current Ratio = Current Assets / Current Liabilities",
                calculation: "₱500,000 / ₱200,000 = 2.5",
                answer: 2.5
              },
              difficulty: "medium",
              points: 10
            }
          ]
        },
        {
          title: "Income Statement Analysis",
          content: "Analyzing profitability and operational efficiency...",
          exercises: [
            {
              type: "multiple_choice",
              question: "Which ratio measures a company's ability to generate profit from sales?",
              options: [
                "Current Ratio",
                "Debt-to-Equity Ratio",
                "Net Profit Margin",
                "Inventory Turnover"
              ],
              correctAnswer: 2,
              explanation: "Net Profit Margin measures how much profit a company generates from its total revenue.",
              difficulty: "easy",
              points: 5
            }
          ]
        }
      ],
      totalExercises: 15,
      estimatedCompletionTime: 90
    },
    metadata: {
      difficulty: "advanced",
      estimatedTime: 90,
      language: "en-PH",
      prerequisites: ["basic-accounting", "financial-statements-intro"],
      learningObjectives: [
        "Analyze financial statements effectively",
        "Calculate key financial ratios",
        "Interpret financial performance metrics"
      ],
      viewCount: 847,
      averageRating: 4.5,
      totalRatings: 67
    },
    tags: ["cpa", "financial-accounting", "financial-analysis", "ratios"],
    status: "published",
    createdAt: new Date("2024-01-10T08:00:00Z"),
    updatedAt: new Date("2024-01-12T14:30:00Z"),
    publishedAt: new Date("2024-01-12T16:00:00Z")
  }
]);

// Quizzes collection
db.createCollection("quizzes", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["courseId", "title", "questions", "settings"],
      properties: {
        courseId: { bsonType: "string" },
        title: { bsonType: "string" },
        description: { bsonType: "string" },
        questions: {
          bsonType: "array",
          minItems: 1,
          items: {
            bsonType: "object",
            required: ["question", "type", "correctAnswer"],
            properties: {
              question: { bsonType: "string" },
              type: {
                bsonType: "string",
                enum: ["multiple_choice", "true_false", "fill_blank", "essay"]
              },
              options: { bsonType: "array" },
              correctAnswer: {},
              explanation: { bsonType: "string" },
              points: { bsonType: "int", minimum: 1 }
            }
          }
        },
        settings: {
          bsonType: "object",
          properties: {
            timeLimit: { bsonType: "int" },
            shuffleQuestions: { bsonType: "bool" },
            shuffleOptions: { bsonType: "bool" },
            showResults: { bsonType: "bool" },
            allowRetake: { bsonType: "bool" },
            passingScore: { bsonType: "int", minimum: 0, maximum: 100 }
          }
        }
      }
    }
  }
});

// Sample quiz document
db.quizzes.insertOne({
  courseId: "bar-exam-constitutional-law",
  title: "Constitutional Law Fundamentals Quiz",
  description: "Test your understanding of basic constitutional law principles",
  questions: [
    {
      question: "What is the supreme law of the Philippines?",
      type: "multiple_choice",
      options: [
        "Civil Code",
        "1987 Constitution",
        "Revised Penal Code",
        "Labor Code"
      ],
      correctAnswer: 1,
      explanation: "The 1987 Constitution is the supreme law of the Philippines, serving as the fundamental law of the state.",
      points: 5,
      difficulty: "easy",
      tags: ["constitution", "fundamental-law"]
    },
    {
      question: "The Bill of Rights is found in which article of the 1987 Constitution?",
      type: "multiple_choice",
      options: [
        "Article II",
        "Article III",
        "Article IV",
        "Article V"
      ],
      correctAnswer: 1,
      explanation: "Article III of the 1987 Constitution contains the Bill of Rights.",
      points: 5,
      difficulty: "medium",
      tags: ["bill-of-rights", "article-three"]
    },
    {
      question: "Due process of law is guaranteed under the Constitution.",
      type: "true_false",
      correctAnswer: true,
      explanation: "Due process is guaranteed under Section 1, Article III of the 1987 Constitution.",
      points: 3,
      difficulty: "easy",
      tags: ["due-process", "constitutional-rights"]
    }
  ],
  settings: {
    timeLimit: 1800, // 30 minutes
    shuffleQuestions: true,
    shuffleOptions: true,
    showResults: true,
    allowRetake: true,
    passingScore: 70,
    maxAttempts: 3
  },
  metadata: {
    difficulty: "intermediate",
    estimatedTime: 25,
    language: "en-PH",
    averageScore: 78.5,
    totalAttempts: 156,
    passRate: 82.1
  },
  tags: ["constitutional-law", "fundamentals", "quiz", "assessment"],
  status: "published",
  createdAt: new Date("2024-01-15T11:00:00Z"),
  updatedAt: new Date("2024-01-15T11:00:00Z")
});

// Create indexes for optimal performance
db.lessons.createIndex({ courseId: 1 });
db.lessons.createIndex({ courseId: 1, status: 1 });
db.lessons.createIndex({ courseId: 1, "metadata.difficulty": 1, createdAt: -1 });
db.lessons.createIndex({ slug: 1 }, { unique: true });
db.lessons.createIndex({ tags: 1 });
db.lessons.createIndex({ status: 1, publishedAt: -1 });
db.lessons.createIndex({ "metadata.language": 1 });

// Text search index for lessons
db.lessons.createIndex({
  title: "text",
  "content.transcripts.content": "text",
  tags: "text"
}, {
  weights: {
    title: 10,
    "content.transcripts.content": 5,
    tags: 1
  },
  name: "lesson_search_index"
});

// Quiz indexes
db.quizzes.createIndex({ courseId: 1 });
db.quizzes.createIndex({ courseId: 1, status: 1 });
db.quizzes.createIndex({ tags: 1 });
db.quizzes.createIndex({ "settings.difficulty": 1 });

// Text search index for quizzes
db.quizzes.createIndex({
  title: "text",
  description: "text",
  "questions.question": "text"
}, {
  name: "quiz_search_index"
});

print("MongoDB initialization completed successfully!");
```

## ⚡ Redis Configuration Templates

### 🔧 Production Redis Configuration
```ini
# redis-config/redis.conf - Production Redis Configuration

# Network and Security
bind 0.0.0.0
protected-mode yes
port 6379
timeout 300
tcp-keepalive 300
tcp-backlog 511

# Authentication
requirepass secure_redis_123

# Memory Management
maxmemory 4gb
maxmemory-policy allkeys-lru
maxmemory-samples 5

# Persistence Configuration
# RDB Snapshots
save 900 1    # Save if at least 1 key changed in 900 seconds
save 300 10   # Save if at least 10 keys changed in 300 seconds
save 60 10000 # Save if at least 10000 keys changed in 60 seconds

rdbcompression yes
rdbchecksum yes
dbfilename dump.rdb
dir /data

# AOF Configuration
appendonly yes
appendfilename "appendonly.aof"
appendfsync everysec
no-appendfsync-on-rewrite no
auto-aof-rewrite-percentage 100
auto-aof-rewrite-min-size 64mb

# Slow Log Configuration
slowlog-log-slower-than 10000  # 10ms
slowlog-max-len 128

# Client Configuration
maxclients 10000

# Disable dangerous commands for security
rename-command FLUSHDB ""
rename-command FLUSHALL ""
rename-command DEBUG ""
rename-command CONFIG "CONFIG_b6c85e0e6a1c4b8a9f4a3c2d1e0f9b8a"

# Logging
loglevel notice
logfile /var/log/redis/redis-server.log

# Advanced Configuration
hash-max-ziplist-entries 512
hash-max-ziplist-value 64
list-max-ziplist-entries 512
list-max-ziplist-value 64
set-max-intset-entries 512
zset-max-ziplist-entries 128
zset-max-ziplist-value 64

# Latency Monitoring
latency-monitor-threshold 100

# Notifications for expired keys (useful for session management)
notify-keyspace-events Ex
```

### 📊 Redis CLI Scripts for EdTech Operations

#### User Session Management Script
```bash
#!/bin/bash
# redis-scripts/session-management.sh

REDIS_HOST="localhost"
REDIS_PORT="6379"
REDIS_PASSWORD="secure_redis_123"

# Function to execute Redis commands
redis_exec() {
    redis-cli -h $REDIS_HOST -p $REDIS_PORT -a $REDIS_PASSWORD "$@"
}

# Create user session
create_session() {
    local user_id=$1
    local session_data=$2
    local expiry=${3:-3600}  # Default 1 hour
    
    local session_id=$(uuidgen)
    local session_key="session:${session_id}"
    local user_sessions_key="user_sessions:${user_id}"
    
    # Store session data
    redis_exec HMSET $session_key \
        user_id $user_id \
        created_at $(date -u +"%Y-%m-%dT%H:%M:%SZ") \
        last_activity $(date -u +"%Y-%m-%dT%H:%M:%SZ") \
        data "$session_data"
    
    # Set expiration
    redis_exec EXPIRE $session_key $expiry
    
    # Add to user's session list
    redis_exec SADD $user_sessions_key $session_id
    redis_exec EXPIRE $user_sessions_key $expiry
    
    echo $session_id
}

# Update session activity
update_session_activity() {
    local session_id=$1
    local session_key="session:${session_id}"
    
    redis_exec HSET $session_key last_activity $(date -u +"%Y-%m-%dT%H:%M:%SZ")
    redis_exec EXPIRE $session_key 3600  # Extend expiration
}

# Clean expired sessions for user
clean_user_sessions() {
    local user_id=$1
    local user_sessions_key="user_sessions:${user_id}"
    
    # Get all sessions for user
    local sessions=$(redis_exec SMEMBERS $user_sessions_key)
    
    for session_id in $sessions; do
        local session_key="session:${session_id}"
        if ! redis_exec EXISTS $session_key > /dev/null; then
            # Session expired, remove from user's session set
            redis_exec SREM $user_sessions_key $session_id
        fi
    done
}

# Usage examples
case "$1" in
    "create")
        create_session "$2" "$3" "$4"
        ;;
    "update")
        update_session_activity "$2"
        ;;
    "clean")
        clean_user_sessions "$2"
        ;;
    *)
        echo "Usage: $0 {create|update|clean} [args...]"
        echo "  create <user_id> <session_data> [expiry_seconds]"
        echo "  update <session_id>"
        echo "  clean <user_id>"
        ;;
esac
```

#### Leaderboard Management Script
```bash
#!/bin/bash
# redis-scripts/leaderboard-management.sh

REDIS_HOST="localhost"
REDIS_PORT="6379"
REDIS_PASSWORD="secure_redis_123"

redis_exec() {
    redis-cli -h $REDIS_HOST -p $REDIS_PORT -a $REDIS_PASSWORD "$@"
}

# Update user score in course leaderboard
update_leaderboard() {
    local course_id=$1
    local user_id=$2
    local score=$3
    local quiz_id=${4:-"general"}
    
    local leaderboard_key="leaderboard:${course_id}"
    local user_stats_key="user_stats:${user_id}:${course_id}"
    local course_stats_key="course_stats:${course_id}"
    
    # Lua script for atomic leaderboard update
    local lua_script='
        local leaderboard_key = KEYS[1]
        local user_stats_key = KEYS[2]
        local course_stats_key = KEYS[3]
        local user_id = ARGV[1]
        local score = tonumber(ARGV[2])
        local quiz_id = ARGV[3]
        local timestamp = ARGV[4]
        
        -- Update leaderboard
        redis.call("ZADD", leaderboard_key, score, user_id)
        
        -- Update user statistics
        redis.call("HINCRBYFLOAT", user_stats_key, "total_score", score)
        redis.call("HINCRBY", user_stats_key, "quiz_count", 1)
        redis.call("HSET", user_stats_key, "last_activity", timestamp)
        
        -- Update course statistics
        redis.call("HINCRBY", course_stats_key, "total_submissions", 1)
        redis.call("HINCRBYFLOAT", course_stats_key, "total_score", score)
        
        -- Get user rank
        local rank = redis.call("ZREVRANK", leaderboard_key, user_id)
        return rank + 1  -- Convert to 1-based ranking
    '
    
    redis_exec EVAL "$lua_script" 3 \
        $leaderboard_key $user_stats_key $course_stats_key \
        $user_id $score $quiz_id $(date -u +"%Y-%m-%dT%H:%M:%SZ")
}

# Get top performers
get_top_performers() {
    local course_id=$1
    local limit=${2:-10}
    
    local leaderboard_key="leaderboard:${course_id}"
    
    echo "Top $limit performers for course $course_id:"
    redis_exec ZREVRANGE $leaderboard_key 0 $((limit-1)) WITHSCORES
}

# Get user rank and score
get_user_rank() {
    local course_id=$1
    local user_id=$2
    
    local leaderboard_key="leaderboard:${course_id}"
    
    local rank=$(redis_exec ZREVRANK $leaderboard_key $user_id)
    local score=$(redis_exec ZSCORE $leaderboard_key $user_id)
    
    if [ "$rank" != "" ]; then
        echo "User $user_id - Rank: $((rank+1)), Score: $score"
    else
        echo "User $user_id not found in leaderboard"
    fi
}

# Reset leaderboard (use with caution)
reset_leaderboard() {
    local course_id=$1
    local confirm=$2
    
    if [ "$confirm" == "CONFIRM" ]; then
        local leaderboard_key="leaderboard:${course_id}"
        redis_exec DEL $leaderboard_key
        echo "Leaderboard for course $course_id has been reset"
    else
        echo "To reset leaderboard, use: $0 reset $course_id CONFIRM"
    fi
}

# Usage
case "$1" in
    "update")
        update_leaderboard "$2" "$3" "$4" "$5"
        ;;
    "top")
        get_top_performers "$2" "$3"
        ;;
    "rank")
        get_user_rank "$2" "$3"
        ;;
    "reset")
        reset_leaderboard "$2" "$3"
        ;;
    *)
        echo "Usage: $0 {update|top|rank|reset} [args...]"
        echo "  update <course_id> <user_id> <score> [quiz_id]"
        echo "  top <course_id> [limit]"
        echo "  rank <course_id> <user_id>"
        echo "  reset <course_id> CONFIRM"
        ;;
esac
```

## 🔄 Backup and Monitoring Templates

### 📋 Comprehensive Backup Script
```bash
#!/bin/bash
# scripts/backup.sh - Comprehensive Database Backup

set -e  # Exit on any error

# Configuration
BACKUP_DIR="/backups"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=7

# Database connection details
POSTGRES_HOST="edtech_postgres"
POSTGRES_USER="edtech_user"
POSTGRES_DB="edtech_db"
POSTGRES_PASSWORD="secure_password_123"

MONGO_HOST="edtech_mongodb"
MONGO_USER="admin"
MONGO_PASSWORD="secure_mongo_123"

REDIS_HOST="edtech_redis"
REDIS_PASSWORD="secure_redis_123"

# Create backup directory
mkdir -p "$BACKUP_DIR/$DATE"

echo "=== Starting Backup Process at $(date) ==="

# PostgreSQL Backup
echo "Backing up PostgreSQL..."
export PGPASSWORD="$POSTGRES_PASSWORD"
pg_dump -h $POSTGRES_HOST -U $POSTGRES_USER -d $POSTGRES_DB \
    --format=custom \
    --compress=9 \
    --verbose \
    --file="$BACKUP_DIR/$DATE/postgres_backup.custom"

# Schema-only backup for quick restoration testing
pg_dump -h $POSTGRES_HOST -U $POSTGRES_USER -d $POSTGRES_DB \
    --schema-only \
    --file="$BACKUP_DIR/$DATE/postgres_schema.sql"

echo "PostgreSQL backup completed"

# MongoDB Backup
echo "Backing up MongoDB..."
mongodump \
    --host "$MONGO_HOST:27017" \
    --username "$MONGO_USER" \
    --password "$MONGO_PASSWORD" \
    --authenticationDatabase admin \
    --gzip \
    --out "$BACKUP_DIR/$DATE/mongodb_backup"

echo "MongoDB backup completed"

# Redis Backup
echo "Backing up Redis..."
redis-cli -h $REDIS_HOST -a $REDIS_PASSWORD BGSAVE

# Wait for background save to complete
while [ $(redis-cli -h $REDIS_HOST -a $REDIS_PASSWORD LASTSAVE) -eq $(redis-cli -h $REDIS_HOST -a $REDIS_PASSWORD LASTSAVE) ]; do
    sleep 1
done

# Copy RDB file
docker cp edtech_redis:/data/dump.rdb "$BACKUP_DIR/$DATE/redis_backup.rdb"

echo "Redis backup completed"

# Create backup manifest
cat > "$BACKUP_DIR/$DATE/backup_manifest.json" << EOF
{
  "backup_date": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "backup_id": "$DATE",
  "databases": {
    "postgresql": {
      "file": "postgres_backup.custom",
      "schema_file": "postgres_schema.sql",
      "size": "$(du -h "$BACKUP_DIR/$DATE/postgres_backup.custom" | cut -f1)"
    },
    "mongodb": {
      "directory": "mongodb_backup",
      "size": "$(du -sh "$BACKUP_DIR/$DATE/mongodb_backup" | cut -f1)"
    },
    "redis": {
      "file": "redis_backup.rdb",
      "size": "$(du -h "$BACKUP_DIR/$DATE/redis_backup.rdb" | cut -f1)"
    }
  },
  "backup_size": "$(du -sh "$BACKUP_DIR/$DATE" | cut -f1)"
}
EOF

# Compress backup
echo "Compressing backup..."
tar -czf "$BACKUP_DIR/backup_$DATE.tar.gz" -C "$BACKUP_DIR" "$DATE"
rm -rf "$BACKUP_DIR/$DATE"

echo "Backup compressed to: backup_$DATE.tar.gz"

# Clean old backups
echo "Cleaning old backups (keeping last $RETENTION_DAYS days)..."
find "$BACKUP_DIR" -name "backup_*.tar.gz" -mtime +$RETENTION_DAYS -delete

# Upload to cloud storage (optional)
if [ -n "$AWS_S3_BUCKET" ]; then
    echo "Uploading to S3..."
    aws s3 cp "$BACKUP_DIR/backup_$DATE.tar.gz" "s3://$AWS_S3_BUCKET/database-backups/"
fi

echo "=== Backup Process Completed at $(date) ==="
echo "Backup file: backup_$DATE.tar.gz"
echo "Backup size: $(du -sh "$BACKUP_DIR/backup_$DATE.tar.gz" | cut -f1)"
```

## 🔗 Navigation

- **Previous**: [Troubleshooting](./troubleshooting.md)
- **Next**: [Alternative Tools Analysis](./alternative-tools-analysis.md)
- **Home**: [Database Management Tools Research](./README.md)

---

*These templates provide production-ready configurations and scripts for implementing database management tools in EdTech development workflows.*