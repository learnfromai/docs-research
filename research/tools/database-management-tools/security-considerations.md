# Security Considerations: Database Management Tools

## 🎯 Overview

This guide provides comprehensive security best practices for pgAdmin, MongoDB Compass, and Redis CLI in EdTech environments. Security measures are designed to protect student data, comply with international privacy regulations, and ensure secure remote development workflows.

## 🛡️ PostgreSQL + pgAdmin Security

### 🔐 Authentication and Access Control

#### Strong Authentication Setup
```sql
-- Create secure password policy
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Create role-based access control
CREATE ROLE edtech_admin;
CREATE ROLE edtech_instructor;
CREATE ROLE edtech_student;
CREATE ROLE edtech_readonly;

-- Admin role (full access)
GRANT ALL PRIVILEGES ON DATABASE edtech_db TO edtech_admin;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO edtech_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO edtech_admin;

-- Instructor role (limited write access)
GRANT CONNECT ON DATABASE edtech_db TO edtech_instructor;
GRANT USAGE ON SCHEMA public TO edtech_instructor;
GRANT SELECT, INSERT, UPDATE ON content_management.courses TO edtech_instructor;
GRANT SELECT ON user_management.users TO edtech_instructor;
GRANT SELECT, INSERT, UPDATE ON analytics.quiz_attempts TO edtech_instructor;

-- Student role (read-only for most data)
GRANT CONNECT ON DATABASE edtech_db TO edtech_student;
GRANT USAGE ON SCHEMA public TO edtech_student;
GRANT SELECT ON content_management.courses TO edtech_student;
GRANT SELECT, INSERT, UPDATE ON user_management.user_course_enrollments TO edtech_student;
GRANT SELECT, INSERT, UPDATE ON user_management.user_lesson_progress TO edtech_student;

-- Read-only role for analytics
GRANT CONNECT ON DATABASE edtech_db TO edtech_readonly;
GRANT USAGE ON SCHEMA public TO edtech_readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA analytics TO edtech_readonly;

-- Create application users with specific roles
CREATE USER edtech_app_admin WITH PASSWORD 'very_secure_admin_pass_2024!@#' IN ROLE edtech_admin;
CREATE USER edtech_app_instructor WITH PASSWORD 'secure_instructor_pass_2024$%^' IN ROLE edtech_instructor;
CREATE USER edtech_app_student WITH PASSWORD 'student_secure_pass_2024&*(' IN ROLE edtech_student;
CREATE USER edtech_analytics WITH PASSWORD 'analytics_pass_2024)!@' IN ROLE edtech_readonly;

-- Enforce password strength
ALTER SYSTEM SET password_encryption = 'scram-sha-256';
```

#### Row-Level Security (RLS)
```sql
-- Enable RLS for sensitive tables
ALTER TABLE user_management.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_management.user_course_enrollments ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_management.user_lesson_progress ENABLE ROW LEVEL SECURITY;

-- Policy for users to see only their own data
CREATE POLICY user_own_data_policy ON user_management.users
FOR ALL TO edtech_student
USING (id = current_setting('app.current_user_id')::uuid);

-- Policy for instructors to see their students' progress
CREATE POLICY instructor_student_progress_policy ON user_management.user_course_enrollments
FOR SELECT TO edtech_instructor
USING (
    course_id IN (
        SELECT id FROM content_management.courses 
        WHERE instructor_id = current_setting('app.current_user_id')::uuid
    )
);

-- Policy for students to see only their own progress
CREATE POLICY student_own_progress_policy ON user_management.user_course_enrollments
FOR ALL TO edtech_student
USING (user_id = current_setting('app.current_user_id')::uuid);

-- Set user context in application
-- This should be called at the beginning of each database session
CREATE OR REPLACE FUNCTION set_current_user_id(user_uuid uuid)
RETURNS void AS $$
BEGIN
    PERFORM set_config('app.current_user_id', user_uuid::text, true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

#### Data Encryption
```sql
-- Encrypt sensitive data fields
CREATE TABLE user_management.user_sensitive_data (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES user_management.users(id) ON DELETE CASCADE,
    encrypted_ssn BYTEA, -- Social Security Number (encrypted)
    encrypted_id_number BYTEA, -- Government ID (encrypted)
    encrypted_payment_info BYTEA, -- Payment information (encrypted)
    encryption_version INTEGER DEFAULT 1,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Functions for encryption/decryption
CREATE OR REPLACE FUNCTION encrypt_sensitive_data(plaintext TEXT, key TEXT)
RETURNS BYTEA AS $$
BEGIN
    RETURN pgp_sym_encrypt(plaintext, key);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION decrypt_sensitive_data(encrypted_data BYTEA, key TEXT)
RETURNS TEXT AS $$
BEGIN
    RETURN pgp_sym_decrypt(encrypted_data, key);
EXCEPTION
    WHEN OTHERS THEN
        RETURN NULL; -- Return NULL if decryption fails
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Usage example
INSERT INTO user_management.user_sensitive_data (user_id, encrypted_ssn)
VALUES (
    'user-uuid-here',
    encrypt_sensitive_data('123-45-6789', current_setting('app.encryption_key'))
);
```

### 🔒 pgAdmin Security Configuration

#### Secure pgAdmin Setup
```python
# pgAdmin config_local.py - Security Configuration
import os

# Authentication
AUTHENTICATION_SOURCES = ['ldap', 'internal']
LOGIN_BANNER = "Authorized Users Only - EdTech Platform Database"

# Session security
SESSION_COOKIE_SECURE = True
SESSION_COOKIE_HTTPONLY = True
SESSION_COOKIE_SAMESITE = 'Strict'
WTF_CSRF_TIME_LIMIT = 3600  # 1 hour CSRF token validity

# Password policies
PASSWORD_LENGTH_MIN = 12
PASSWORD_LENGTH_MAX = 128

# Security headers
SECURE_HEADERS = {
    'X-Frame-Options': 'DENY',
    'X-Content-Type-Options': 'nosniff',
    'X-XSS-Protection': '1; mode=block',
    'Strict-Transport-Security': 'max-age=31536000; includeSubDomains',
    'Content-Security-Policy': "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline';"
}

# Audit logging
AUDIT_LOG = True
AUDIT_LOG_FILE = '/var/log/pgadmin/audit.log'

# Two-factor authentication (if available)
MFA_ENABLED = True

# IP allowlisting (for production)
ALLOWED_HOSTS = ['192.168.1.0/24', '10.0.0.0/8']  # Adjust for your network

# SSL Configuration
SSL_CERT_FILE = '/etc/ssl/certs/pgadmin.crt'
SSL_KEY_FILE = '/etc/ssl/private/pgadmin.key'
```

#### Network Security
```bash
# nginx.conf - Reverse proxy with security headers
server {
    listen 443 ssl http2;
    server_name pgadmin.edtech.local;

    ssl_certificate /etc/ssl/certs/pgadmin.crt;
    ssl_certificate_key /etc/ssl/private/pgadmin.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;

    # Security headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    # Rate limiting
    limit_req zone=pgadmin burst=5 nodelay;

    # IP allowlisting
    allow 192.168.1.0/24;
    allow 10.0.0.0/8;
    deny all;

    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Prevent proxy buffer attacks
        proxy_buffering off;
        proxy_request_buffering off;
    }
}

# Rate limiting configuration
http {
    limit_req_zone $binary_remote_addr zone=pgadmin:10m rate=10r/m;
}
```

## 🍃 MongoDB + Compass Security

### 🔐 Authentication and Authorization

#### MongoDB User Security Setup
```javascript
// MongoDB security configuration
use admin;

// Create admin user
db.createUser({
  user: "admin",
  pwd: "very_secure_admin_pass_2024!@#",
  roles: ["root"]
});

// Create application users with limited privileges
db.createUser({
  user: "edtech_app",
  pwd: "secure_app_password_2024$%^",
  roles: [
    { role: "readWrite", db: "edtech_content" },
    { role: "read", db: "config" }
  ]
});

db.createUser({
  user: "edtech_readonly",
  pwd: "readonly_password_2024&*(",
  roles: [
    { role: "read", db: "edtech_content" }
  ]
});

// Create custom roles for fine-grained access control
db.createRole({
  role: "courseContentManager",
  privileges: [
    {
      resource: { db: "edtech_content", collection: "lessons" },
      actions: ["find", "insert", "update", "remove"]
    },
    {
      resource: { db: "edtech_content", collection: "quizzes" },
      actions: ["find", "insert", "update", "remove"]
    },
    {
      resource: { db: "edtech_content", collection: "userProgress" },
      actions: ["find", "update"]
    }
  ],
  roles: []
});

db.createRole({
  role: "studentRole",
  privileges: [
    {
      resource: { db: "edtech_content", collection: "lessons" },
      actions: ["find"]
    },
    {
      resource: { db: "edtech_content", collection: "quizzes" },
      actions: ["find"]
    },
    {
      resource: { db: "edtech_content", collection: "userProgress" },
      actions: ["find", "insert", "update"],
      // Restrict to user's own documents
      filter: { "userId": "$$USER_ID" }
    }
  ],
  roles: []
});

// Create instructor user
db.createUser({
  user: "edtech_instructor",
  pwd: "instructor_secure_pass_2024)!@",
  roles: ["courseContentManager"]
});
```

#### Field-Level Encryption
```javascript
// Client-side field level encryption setup
const { MongoClient, ClientEncryption } = require('mongodb');

// Key management
const kmsProviders = {
  local: {
    key: Buffer.from('your-96-byte-master-key-here', 'base64') // 96 bytes
  }
};

const keyVaultNamespace = 'encryption.datakeys';

// Create data encryption key
async function createDataKey() {
  const client = new MongoClient('mongodb://admin:password@localhost:27017');
  const encryption = new ClientEncryption(client, {
    keyVaultNamespace,
    kmsProviders
  });

  const dataKey = await encryption.createDataKey('local', {
    keyAltNames: ['edtech-pii-key']
  });

  console.log('Data key created:', dataKey);
  await client.close();
}

// Encrypt sensitive user data
const encryptedCollectionSchema = {
  'edtech_content.users': {
    bsonType: 'object',
    encryptMetadata: {
      keyId: [BinData(4, 'your-data-key-uuid-here')]
    },
    properties: {
      personalInfo: {
        encrypt: {
          bsonType: 'object',
          algorithm: 'AEAD_AES_256_CBC_HMAC_SHA_512-Deterministic'
        }
      },
      contactInfo: {
        encrypt: {
          bsonType: 'object',
          algorithm: 'AEAD_AES_256_CBC_HMAC_SHA_512-Random'
        }
      }
    }
  }
};

// Client with automatic encryption
const secureClient = new MongoClient('mongodb://admin:password@localhost:27017', {
  autoEncryption: {
    keyVaultNamespace,
    kmsProviders,
    schemaMap: encryptedCollectionSchema
  }
});
```

### 🔒 MongoDB Compass Security

#### Secure Connection Configuration
```javascript
// Compass connection string with security options
mongodb://edtech_app:secure_app_password_2024%24%25%5E@localhost:27017/edtech_content?authSource=admin&ssl=true&sslValidate=true&sslCA=/path/to/ca.pem&sslCert=/path/to/client.pem&sslKey=/path/to/client-key.pem

// SSL/TLS Configuration in mongod.conf
net:
  port: 27017
  bindIp: 0.0.0.0
  ssl:
    mode: requireSSL
    PEMKeyFile: /etc/ssl/mongodb.pem
    CAFile: /etc/ssl/ca.pem
    allowConnectionsWithoutCertificates: false
    allowInvalidHostnames: false

security:
  authorization: enabled
  javascriptEnabled: false  # Disable server-side JavaScript for security

# Enable audit logging
auditLog:
  destination: file
  format: JSON
  path: /var/log/mongodb/audit.log
  filter: |
    {
      $or: [
        {"atype": "authenticate"},
        {"atype": "authCheck", "ts": {"$gt": {"$date": "2024-01-01T00:00:00.000Z"}}}
      ]
    }
```

## ⚡ Redis Security

### 🔐 Redis Authentication and Access Control

#### Redis Security Configuration
```bash
# redis.conf - Security hardening
# Authentication
requirepass very_secure_redis_password_2024!@#$%

# Network security
bind 127.0.0.1 192.168.1.100  # Bind to specific interfaces
protected-mode yes
port 0  # Disable default port
tls-port 6380  # Use TLS port instead

# TLS Configuration
tls-cert-file /etc/redis/tls/redis.crt
tls-key-file /etc/redis/tls/redis.key
tls-ca-cert-file /etc/redis/tls/ca.crt
tls-dh-params-file /etc/redis/tls/dhparam.pem
tls-protocols "TLSv1.2 TLSv1.3"
tls-ciphers "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384"
tls-prefer-server-ciphers yes

# Disable dangerous commands
rename-command FLUSHDB ""
rename-command FLUSHALL ""
rename-command DEBUG ""
rename-command CONFIG "CONFIG_a1b2c3d4e5f6"
rename-command SHUTDOWN "SHUTDOWN_x9y8z7w6v5u4"
rename-command EVAL ""
rename-command SCRIPT ""

# Enable keyspace notifications for session management
notify-keyspace-events "Ex"

# Logging and monitoring
logfile /var/log/redis/redis-server.log
loglevel notice
syslog-enabled yes
syslog-ident redis

# Memory protection
maxclients 1000
timeout 300
tcp-keepalive 300

# Slow log for monitoring
slowlog-log-slower-than 10000
slowlog-max-len 128
```

#### Redis ACL (Access Control Lists)
```bash
# Redis 6+ ACL configuration
# Create different users with specific permissions

# Admin user (full access)
ACL SETUSER admin on >admin_password_2024!@# ~* &* +@all

# Application user (limited commands)
ACL SETUSER edtech_app on >app_password_2024$%^ ~edtech:* -@all +@read +@write +@string +@hash +@list +@set +@sortedset +expire +ttl +exists

# Session manager user (session management only)
ACL SETUSER session_manager on >session_pass_2024&*( ~session:* ~user_sessions:* -@all +@read +@write +@string +@hash +expire +ttl +exists +del

# Analytics user (read-only for analytics data)
ACL SETUSER analytics_readonly on >analytics_pass_2024)!@ ~analytics:* ~stats:* ~leaderboard:* -@all +@read

# Save ACL configuration
ACL SAVE

# List current ACL users
ACL LIST
```

#### Secure Redis Connection Examples
```python
# Python secure Redis connection
import redis
import ssl

# SSL/TLS connection
ssl_context = ssl.create_default_context(ssl.Purpose.SERVER_AUTH)
ssl_context.check_hostname = False
ssl_context.verify_mode = ssl.CERT_REQUIRED
ssl_context.load_verify_locations('/etc/redis/tls/ca.crt')
ssl_context.load_cert_chain('/etc/redis/tls/client.crt', '/etc/redis/tls/client.key')

redis_client = redis.Redis(
    host='localhost',
    port=6380,  # TLS port
    username='edtech_app',
    password='app_password_2024$%^',
    ssl=True,
    ssl_context=ssl_context,
    socket_connect_timeout=5,
    socket_timeout=5,
    retry_on_timeout=True,
    health_check_interval=30
)

# Connection pool for production
connection_pool = redis.ConnectionPool(
    host='localhost',
    port=6380,
    username='edtech_app',
    password='app_password_2024$%^',
    ssl=True,
    ssl_context=ssl_context,
    max_connections=20,
    retry_on_timeout=True
)

redis_client = redis.Redis(connection_pool=connection_pool)
```

## 🌍 Cross-Database Security Integration

### 🔐 Unified Security Architecture

#### Application-Level Security Layer
```python
# Secure database connection manager
import os
import logging
from contextlib import contextmanager
from typing import Dict, Any

import psycopg2
import pymongo
import redis
import hashlib
import jwt
from datetime import datetime, timedelta

class SecureDatabaseManager:
    def __init__(self):
        self.encryption_key = os.getenv('ENCRYPTION_KEY')
        self.jwt_secret = os.getenv('JWT_SECRET')
        
        # Initialize secure connections
        self._init_postgres_connection()
        self._init_mongodb_connection()
        self._init_redis_connection()
        
        # Setup logging
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler('/var/log/edtech/security.log'),
                logging.StreamHandler()
            ]
        )
        self.logger = logging.getLogger(__name__)
    
    def _init_postgres_connection(self):
        """Initialize secure PostgreSQL connection"""
        self.postgres = psycopg2.connect(
            host=os.getenv('POSTGRES_HOST', 'localhost'),
            database=os.getenv('POSTGRES_DB', 'edtech_db'),
            user=os.getenv('POSTGRES_USER', 'edtech_app'),
            password=os.getenv('POSTGRES_PASSWORD'),
            sslmode='require',
            sslcert='/etc/ssl/certs/client.crt',
            sslkey='/etc/ssl/private/client.key',
            sslrootcert='/etc/ssl/certs/ca.crt'
        )
    
    def _init_mongodb_connection(self):
        """Initialize secure MongoDB connection"""
        connection_string = (
            f"mongodb://{os.getenv('MONGO_USER')}:{os.getenv('MONGO_PASSWORD')}"
            f"@{os.getenv('MONGO_HOST', 'localhost')}:27017/{os.getenv('MONGO_DB')}"
            f"?authSource=admin&ssl=true&sslCertificateKeyFile=/etc/ssl/mongodb-client.pem"
            f"&sslCAFile=/etc/ssl/ca.pem"
        )
        self.mongodb_client = pymongo.MongoClient(connection_string)
        self.mongodb = self.mongodb_client[os.getenv('MONGO_DB', 'edtech_content')]
    
    def _init_redis_connection(self):
        """Initialize secure Redis connection"""
        import ssl
        ssl_context = ssl.create_default_context(ssl.Purpose.SERVER_AUTH)
        ssl_context.load_verify_locations('/etc/redis/tls/ca.crt')
        ssl_context.load_cert_chain('/etc/redis/tls/client.crt', '/etc/redis/tls/client.key')
        
        self.redis_client = redis.Redis(
            host=os.getenv('REDIS_HOST', 'localhost'),
            port=int(os.getenv('REDIS_TLS_PORT', '6380')),
            username=os.getenv('REDIS_USER', 'edtech_app'),
            password=os.getenv('REDIS_PASSWORD'),
            ssl=True,
            ssl_context=ssl_context
        )
    
    def authenticate_user(self, email: str, password: str) -> Dict[str, Any]:
        """Secure user authentication with audit logging"""
        try:
            with self.postgres.cursor() as cursor:
                # Get user data with hashed password
                cursor.execute("""
                    SELECT id, email, password_hash, role, failed_login_attempts, locked_until
                    FROM user_management.users 
                    WHERE email = %s AND is_active = TRUE
                """, (email,))
                
                user_data = cursor.fetchone()
                
                if not user_data:
                    self._log_security_event('login_failed', email, 'user_not_found')
                    return {'success': False, 'error': 'Invalid credentials'}
                
                user_id, user_email, password_hash, role, failed_attempts, locked_until = user_data
                
                # Check if account is locked
                if locked_until and locked_until > datetime.utcnow():
                    self._log_security_event('login_failed', email, 'account_locked')
                    return {'success': False, 'error': 'Account locked'}
                
                # Verify password
                if not self._verify_password(password, password_hash):
                    # Increment failed attempts
                    cursor.execute("""
                        UPDATE user_management.users 
                        SET failed_login_attempts = failed_login_attempts + 1,
                            locked_until = CASE 
                                WHEN failed_login_attempts >= 4 THEN NOW() + INTERVAL '15 minutes'
                                ELSE NULL 
                            END
                        WHERE id = %s
                    """, (user_id,))
                    
                    self._log_security_event('login_failed', email, 'invalid_password')
                    return {'success': False, 'error': 'Invalid credentials'}
                
                # Reset failed attempts on successful login
                cursor.execute("""
                    UPDATE user_management.users 
                    SET failed_login_attempts = 0, 
                        locked_until = NULL,
                        last_login = NOW(),
                        login_count = login_count + 1
                    WHERE id = %s
                """, (user_id,))
                
                # Generate JWT token
                token = jwt.encode({
                    'user_id': str(user_id),
                    'email': user_email,
                    'role': role,
                    'exp': datetime.utcnow() + timedelta(hours=24)
                }, self.jwt_secret, algorithm='HS256')
                
                # Create secure session
                session_id = self._create_secure_session(user_id, user_email, role)
                
                self._log_security_event('login_success', email, 'authenticated')
                
                return {
                    'success': True,
                    'token': token,
                    'session_id': session_id,
                    'user': {
                        'id': str(user_id),
                        'email': user_email,
                        'role': role
                    }
                }
                
        except Exception as e:
            self.logger.error(f"Authentication error: {str(e)}")
            return {'success': False, 'error': 'Authentication failed'}
    
    def _verify_password(self, password: str, password_hash: str) -> bool:
        """Verify password using secure hashing"""
        import bcrypt
        return bcrypt.checkpw(password.encode('utf-8'), password_hash.encode('utf-8'))
    
    def _create_secure_session(self, user_id: str, email: str, role: str) -> str:
        """Create secure session in Redis"""
        import uuid
        session_id = str(uuid.uuid4())
        
        session_data = {
            'user_id': user_id,
            'email': email,
            'role': role,
            'created_at': datetime.utcnow().isoformat(),
            'last_activity': datetime.utcnow().isoformat()
        }
        
        # Store session with 24-hour expiration
        self.redis_client.hmset(f'session:{session_id}', session_data)
        self.redis_client.expire(f'session:{session_id}', 86400)  # 24 hours
        
        # Add to user's active sessions
        self.redis_client.sadd(f'user_sessions:{user_id}', session_id)
        self.redis_client.expire(f'user_sessions:{user_id}', 86400)
        
        return session_id
    
    def _log_security_event(self, event_type: str, user_identifier: str, details: str):
        """Log security events for audit trail"""
        try:
            with self.postgres.cursor() as cursor:
                cursor.execute("""
                    INSERT INTO audit.security_events (event_type, user_identifier, details, ip_address, user_agent, created_at)
                    VALUES (%s, %s, %s, %s, %s, NOW())
                """, (event_type, user_identifier, details, self._get_client_ip(), self._get_user_agent()))
            
            self.logger.info(f"Security event: {event_type} - {user_identifier} - {details}")
            
        except Exception as e:
            self.logger.error(f"Failed to log security event: {str(e)}")
```

## 🚨 Compliance and Regulations

### 📋 GDPR Compliance

#### Data Protection Implementation
```sql
-- GDPR compliance table structure
CREATE TABLE audit.gdpr_compliance (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES user_management.users(id) ON DELETE CASCADE,
    data_type VARCHAR(100) NOT NULL, -- 'personal', 'usage', 'academic', etc.
    legal_basis VARCHAR(100) NOT NULL, -- 'consent', 'contract', 'legitimate_interest', etc.
    purpose TEXT NOT NULL,
    retention_period INTERVAL,
    consent_given BOOLEAN DEFAULT FALSE,
    consent_date TIMESTAMPTZ,
    consent_withdrawn BOOLEAN DEFAULT FALSE,
    consent_withdrawn_date TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Data subject requests table
CREATE TABLE audit.data_subject_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES user_management.users(id),
    request_type VARCHAR(50) NOT NULL, -- 'access', 'rectification', 'erasure', 'portability'
    status VARCHAR(50) DEFAULT 'pending', -- 'pending', 'processing', 'completed', 'denied'
    request_date TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    completion_date TIMESTAMPTZ,
    details JSONB,
    processed_by UUID REFERENCES user_management.users(id)
);

-- Function to handle data erasure (Right to be Forgotten)
CREATE OR REPLACE FUNCTION gdpr_erase_user_data(target_user_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    result BOOLEAN := FALSE;
BEGIN
    -- Anonymize user data instead of deletion to maintain referential integrity
    UPDATE user_management.users 
    SET 
        email = 'deleted_' || target_user_id || '@anonymized.local',
        username = 'deleted_' || EXTRACT(EPOCH FROM NOW()),
        first_name = 'Deleted',
        last_name = 'User',
        phone = NULL,
        date_of_birth = NULL,
        address = NULL,
        avatar_url = NULL,
        preferences = '{}',
        is_active = FALSE
    WHERE id = target_user_id;
    
    -- Delete sensitive data
    DELETE FROM user_management.user_sensitive_data WHERE user_id = target_user_id;
    
    -- Log the erasure
    INSERT INTO audit.gdpr_compliance (user_id, data_type, legal_basis, purpose)
    VALUES (target_user_id, 'erasure', 'data_subject_request', 'Right to be forgotten');
    
    result := TRUE;
    RETURN result;
EXCEPTION
    WHEN OTHERS THEN
        RETURN FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

### 🏛️ International Education Data Standards

#### Student Privacy Protection (FERPA-like compliance)
```python
# Student data access control
class StudentPrivacyManager:
    def __init__(self, db_manager: SecureDatabaseManager):
        self.db = db_manager
    
    def get_student_educational_record(self, requesting_user_id: str, student_user_id: str) -> Dict:
        """Get student educational records with proper authorization"""
        # Check authorization
        if not self._can_access_educational_record(requesting_user_id, student_user_id):
            return {'error': 'Unauthorized access to educational records'}
        
        try:
            with self.db.postgres.cursor() as cursor:
                # Get educational data only (no personal identifiers beyond necessary)
                cursor.execute("""
                    SELECT 
                        uce.course_id,
                        c.title as course_title,
                        uce.completion_percentage,
                        uce.final_score,
                        uce.completion_date,
                        ARRAY_AGG(
                            JSON_BUILD_OBJECT(
                                'quiz_id', qa.quiz_id,
                                'score', qa.score,
                                'completed_at', qa.completed_at
                            )
                        ) as quiz_results
                    FROM user_management.user_course_enrollments uce
                    JOIN content_management.courses c ON uce.course_id = c.id
                    LEFT JOIN analytics.quiz_attempts qa ON qa.user_id = uce.user_id AND qa.course_id = uce.course_id
                    WHERE uce.user_id = %s
                    GROUP BY uce.course_id, c.title, uce.completion_percentage, uce.final_score, uce.completion_date
                """, (student_user_id,))
                
                results = cursor.fetchall()
                
                # Log access for audit trail
                self._log_educational_record_access(requesting_user_id, student_user_id)
                
                return {'success': True, 'educational_records': results}
                
        except Exception as e:
            self.logger.error(f"Error accessing educational records: {str(e)}")
            return {'error': 'Failed to retrieve educational records'}
    
    def _can_access_educational_record(self, requesting_user_id: str, student_user_id: str) -> bool:
        """Check if user can access student's educational records"""
        # Students can access their own records
        if requesting_user_id == student_user_id:
            return True
        
        # Check if requester is instructor of student's courses
        try:
            with self.db.postgres.cursor() as cursor:
                cursor.execute("""
                    SELECT COUNT(*) > 0
                    FROM user_management.user_course_enrollments uce
                    JOIN content_management.courses c ON uce.course_id = c.id
                    WHERE uce.user_id = %s AND c.instructor_id = %s
                """, (student_user_id, requesting_user_id))
                
                return cursor.fetchone()[0]
        except:
            return False
```

## 🔗 Navigation

- **Previous**: [Template Examples](./template-examples.md)
- **Next**: [Alternative Tools Analysis](./alternative-tools-analysis.md)
- **Home**: [Database Management Tools Research](./README.md)

---

*This security guide provides comprehensive protection strategies for database management tools in EdTech environments, ensuring compliance with international privacy regulations and education data standards.*