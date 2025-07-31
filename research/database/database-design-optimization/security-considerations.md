# Security Considerations: Database Protection Strategies

## 🎯 Overview

This comprehensive security guide addresses critical security considerations for PostgreSQL and MongoDB deployments in EdTech environments. The guide covers authentication, authorization, encryption, audit logging, and compliance requirements for educational applications handling sensitive student and institutional data.

## 🛡️ Security Framework for EdTech Applications

### Regulatory Compliance Requirements

#### Educational Data Privacy Laws
```
United States:
✅ FERPA (Family Educational Rights and Privacy Act)
   - Protects student educational records
   - Requires consent for data disclosure
   - Mandates data access controls

✅ COPPA (Children's Online Privacy Protection Act)
   - Applies to users under 13 years old
   - Requires parental consent for data collection
   - Strict data minimization requirements

✅ CCPA (California Consumer Privacy Act)
   - Data subject rights (access, deletion, portability)
   - Data processing transparency
   - Third-party data sharing restrictions

International:
✅ GDPR (General Data Protection Regulation)
   - Comprehensive data protection framework
   - Right to be forgotten
   - Data protection by design

✅ PIPEDA (Canada)
   - Personal information protection
   - Consent requirements
   - Data breach notifications

Australia:
✅ Privacy Act 1988
   - Australian Privacy Principles
   - Notifiable data breach scheme
   - Credit reporting regulations
```

#### Compliance Implementation Matrix
| Requirement | PostgreSQL Implementation | MongoDB Implementation | Priority |
|-------------|---------------------------|------------------------|----------|
| **Data Encryption at Rest** | TDE, pg_crypto | WiredTiger encryption | Critical |
| **Data Encryption in Transit** | SSL/TLS certificates | TLS 1.2+ connections | Critical |
| **Access Controls** | RBAC, Row-level security | Role-based access control | Critical |
| **Audit Logging** | pgAudit extension | MongoDB audit logs | High |
| **Data Anonymization** | Custom functions | Aggregation pipelines | High |
| **Backup Encryption** | Encrypted pg_dump | Encrypted mongodump | High |
| **Network Security** | VPC, IP restrictions | Network security groups | Medium |

## 🔐 Authentication and Authorization

### PostgreSQL Security Implementation

#### Role-Based Access Control (RBAC)
```sql
-- Create security roles hierarchy
-- 1. Base roles for different access levels
CREATE ROLE edtech_readonly;
CREATE ROLE edtech_readwrite; 
CREATE ROLE edtech_admin;
CREATE ROLE edtech_analytics;
CREATE ROLE edtech_backup;

-- 2. Grant appropriate permissions
-- Read-only role (for reporting, analytics)
GRANT CONNECT ON DATABASE edtech_production TO edtech_readonly;
GRANT USAGE ON SCHEMA public TO edtech_readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO edtech_readonly;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO edtech_readonly;

-- Read-write role (for application services)
GRANT edtech_readonly TO edtech_readwrite;
GRANT INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO edtech_readwrite;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO edtech_readwrite;

-- Analytics role (for business intelligence)
GRANT edtech_readonly TO edtech_analytics;
GRANT CREATE ON SCHEMA public TO edtech_analytics; -- For temp tables
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO edtech_analytics;

-- Admin role (for database maintenance)
GRANT edtech_readwrite TO edtech_admin;
GRANT CREATE ON DATABASE edtech_production TO edtech_admin;
GRANT ALL PRIVILEGES ON SCHEMA public TO edtech_admin;

-- Backup role (for automated backups)
GRANT edtech_readonly TO edtech_backup;
GRANT EXECUTE ON FUNCTION pg_start_backup(text) TO edtech_backup;
GRANT EXECUTE ON FUNCTION pg_stop_backup() TO edtech_backup;

-- 3. Create specific user accounts
-- Application service account
CREATE USER api_service WITH PASSWORD 'secure_random_password_here';
GRANT edtech_readwrite TO api_service;
ALTER USER api_service SET statement_timeout = '30s';
ALTER USER api_service SET lock_timeout = '10s';

-- Analytics service account
CREATE USER analytics_service WITH PASSWORD 'secure_analytics_password';
GRANT edtech_analytics TO analytics_service;
ALTER USER analytics_service SET statement_timeout = '10min';

-- Backup service account
CREATE USER backup_service WITH PASSWORD 'secure_backup_password';
GRANT edtech_backup TO backup_service;

-- Admin account (human users)
CREATE USER db_admin WITH PASSWORD 'secure_admin_password';
GRANT edtech_admin TO db_admin;
ALTER USER db_admin VALID UNTIL '2024-12-31'; -- Expire annually

-- 4. Prevent default permissions on new objects
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON TABLES FROM public;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO edtech_readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT INSERT, UPDATE, DELETE ON TABLES TO edtech_readwrite;
```

#### Row-Level Security (RLS) for Multi-Tenancy
```sql
-- Enable RLS on sensitive tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE quiz_attempts ENABLE ROW LEVEL SECURITY;

-- Create security context function
CREATE OR REPLACE FUNCTION get_current_user_id()
RETURNS UUID AS $$
BEGIN
    RETURN COALESCE(
        current_setting('app.current_user_id', true)::UUID,
        '00000000-0000-0000-0000-000000000000'::UUID
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create RLS policies
-- Users can only see their own data
CREATE POLICY user_self_access ON users
    FOR ALL TO edtech_readwrite
    USING (id = get_current_user_id());

-- Instructors can see their students' progress
CREATE POLICY instructor_student_progress ON user_progress
    FOR SELECT TO edtech_readwrite
    USING (
        user_id = get_current_user_id() OR
        EXISTS (
            SELECT 1 FROM courses c 
            WHERE c.id = user_progress.course_id 
              AND c.instructor_id = get_current_user_id()
        )
    );

-- Students can only modify their own progress
CREATE POLICY student_own_progress ON user_progress
    FOR INSERT, UPDATE, DELETE TO edtech_readwrite
    USING (user_id = get_current_user_id());

-- Quiz attempts policy - students see only their attempts
CREATE POLICY quiz_attempts_user_policy ON quiz_attempts
    FOR ALL TO edtech_readwrite
    USING (user_id = get_current_user_id());

-- Admin bypass policy
CREATE POLICY admin_full_access ON users
    FOR ALL TO edtech_admin
    USING (true);

CREATE POLICY admin_full_access_progress ON user_progress
    FOR ALL TO edtech_admin
    USING (true);

CREATE POLICY admin_full_access_quiz ON quiz_attempts
    FOR ALL TO edtech_admin
    USING (true);
```

#### Connection Security and SSL Configuration
```sql
-- SSL/TLS Configuration in postgresql.conf
ssl = on
ssl_cert_file = '/etc/postgresql/ssl/server.crt'
ssl_key_file = '/etc/postgresql/ssl/server.key'
ssl_ca_file = '/etc/postgresql/ssl/ca.crt'
ssl_crl_file = '/etc/postgresql/ssl/ca.crl'

-- Force SSL for all connections
ssl_prefer_server_ciphers = on
ssl_ciphers = 'ECDHE+AESGCM:ECDHE+AES256:ECDHE+AES128:!aNULL:!MD5:!DSS'
ssl_protocols = 'TLSv1.2,TLSv1.3'

-- Connection restrictions in pg_hba.conf
# Only allow SSL connections
hostssl all api_service 10.0.0.0/8 scram-sha-256
hostssl all analytics_service 192.168.1.0/24 scram-sha-256
hostssl all backup_service 172.16.0.0/12 cert
hostssl all db_admin 0.0.0.0/0 scram-sha-256

# Deny non-SSL connections
host all all 0.0.0.0/0 reject

-- Password policy enforcement
CREATE EXTENSION IF NOT EXISTS passwordcheck;
ALTER SYSTEM SET passwordcheck.policy = 'strong';
ALTER SYSTEM SET password_encryption = 'scram-sha-256';
```

### MongoDB Security Implementation

#### Authentication and Authorization
```javascript
// MongoDB security configuration
// 1. Enable authentication in mongod.conf
security:
  authorization: enabled
  clusterAuthMode: keyFile
  keyFile: /etc/mongodb/mongodb-keyfile
  javascriptEnabled: false  // Disable server-side JavaScript

// 2. Create administrative users
use admin;

// Create super admin user
db.createUser({
  user: "mongoAdmin",
  pwd: "super_secure_admin_password",
  roles: [
    { role: "userAdminAnyDatabase", db: "admin" },
    { role: "dbAdminAnyDatabase", db: "admin" },
    { role: "readWriteAnyDatabase", db: "admin" },
    { role: "clusterAdmin", db: "admin" }
  ]
});

// 3. Create custom roles for EdTech application
use edtech_db;

// Create student role - limited access
db.createRole({
  role: "studentRole",
  privileges: [
    // Students can read courses and update their own progress
    { resource: { db: "edtech_db", collection: "courses" }, actions: ["find"] },
    { resource: { db: "edtech_db", collection: "user_progress" }, actions: ["find", "insert", "update"] },
    { resource: { db: "edtech_db", collection: "quiz_attempts" }, actions: ["find", "insert", "update"] }
  ],
  roles: []
});

// Create instructor role - can manage their courses
db.createRole({
  role: "instructorRole",
  privileges: [
    { resource: { db: "edtech_db", collection: "courses" }, actions: ["find", "insert", "update", "remove"] },
    { resource: { db: "edtech_db", collection: "user_progress" }, actions: ["find"] },
    { resource: { db: "edtech_db", collection: "quiz_attempts" }, actions: ["find"] },
    { resource: { db: "edtech_db", collection: "users" }, actions: ["find"] }
  ],
  roles: ["studentRole"]
});

// Create analytics role - read-only access for reporting
db.createRole({
  role: "analyticsRole",
  privileges: [
    { resource: { db: "edtech_db", collection: "" }, actions: ["find", "listCollections", "listIndexes"] },
    { resource: { db: "edtech_db", collection: "system.js" }, actions: [] }
  ],
  roles: []
});

// Create API service role
db.createRole({
  role: "apiServiceRole",
  privileges: [
    { resource: { db: "edtech_db", collection: "" }, actions: ["find", "insert", "update", "remove", "createIndex"] }
  ],
  roles: []
});

// 4. Create service accounts
// API service account
db.createUser({
  user: "api_service",
  pwd: "secure_api_service_password",
  roles: ["apiServiceRole"]
});

// Analytics service account
db.createUser({
  user: "analytics_service", 
  pwd: "secure_analytics_password",
  roles: ["analyticsRole"]
});

// Backup service account
db.createUser({
  user: "backup_service",
  pwd: "secure_backup_password",
  roles: ["backup"]
});
```

#### Field-Level Security and Views
```javascript
// Create secure views to hide sensitive data
use edtech_db;

// Public user profile view (excludes sensitive information)
db.createView("public_user_profiles", "users", [
  {
    $project: {
      email: 0,                    // Hide email
      password_hash: 0,            // Hide password hash
      "profile.ssn": 0,           // Hide SSN
      "profile.phone": 0,         // Hide phone
      "billing": 0,               // Hide billing info
      "authentication": 0         // Hide auth tokens
    }
  }
]);

// Student progress view (filtered by user)
db.createView("student_progress_view", "user_progress", [
  {
    $match: {
      // This would be replaced with actual user context in application
      "userId": ObjectId("USER_ID_PLACEHOLDER")
    }
  },
  {
    $project: {
      "personalNotes": 0,         // Hide personal notes from other users
      "internalFlags": 0          // Hide internal tracking flags
    }
  }
]);

// Course analytics view (aggregated data only)
db.createView("course_analytics_view", "user_progress", [
  {
    $group: {
      _id: "$courseId",
      totalEnrollments: { $sum: 1 },
      avgCompletion: { $avg: "$overallCompletionPercentage" },
      avgTimeSpent: { $avg: "$totalTimeSpent" },
      completionRate: {
        $avg: { $cond: [{ $eq: ["$overallCompletionPercentage", 100] }, 1, 0] }
      }
    }
  }
]);
```

## 🔒 Data Encryption Strategies

### Encryption at Rest

#### PostgreSQL Transparent Data Encryption (TDE)
```sql
-- 1. Enable data encryption at rest
-- This requires PostgreSQL with TDE support or filesystem encryption

-- Using pg_crypto for application-level encryption
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Create encryption/decryption functions
CREATE OR REPLACE FUNCTION encrypt_sensitive_data(data TEXT)
RETURNS TEXT AS $$
BEGIN
    RETURN encode(
        encrypt(data::bytea, current_setting('app.encryption_key'), 'aes'),
        'base64'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION decrypt_sensitive_data(encrypted_data TEXT)
RETURNS TEXT AS $$
BEGIN
    RETURN convert_from(
        decrypt(decode(encrypted_data, 'base64'), current_setting('app.encryption_key'), 'aes'),
        'UTF8'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Example table with encrypted columns
CREATE TABLE user_sensitive_data (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id),
    encrypted_ssn TEXT,              -- Encrypted field
    encrypted_phone TEXT,            -- Encrypted field
    encrypted_address TEXT,          -- Encrypted field
    encryption_key_version INTEGER DEFAULT 1,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Secure insert function
CREATE OR REPLACE FUNCTION insert_sensitive_data(
    p_user_id UUID,
    p_ssn TEXT,
    p_phone TEXT,
    p_address TEXT
) RETURNS UUID AS $$
DECLARE
    record_id UUID;
BEGIN
    INSERT INTO user_sensitive_data (
        user_id,
        encrypted_ssn,
        encrypted_phone, 
        encrypted_address
    ) VALUES (
        p_user_id,
        encrypt_sensitive_data(p_ssn),
        encrypt_sensitive_data(p_phone),
        encrypt_sensitive_data(p_address)
    ) RETURNING id INTO record_id;
    
    RETURN record_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Secure select function
CREATE OR REPLACE FUNCTION get_sensitive_data(p_user_id UUID)
RETURNS TABLE(
    ssn TEXT,
    phone TEXT,
    address TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        decrypt_sensitive_data(usd.encrypted_ssn),
        decrypt_sensitive_data(usd.encrypted_phone),
        decrypt_sensitive_data(usd.encrypted_address)
    FROM user_sensitive_data usd
    WHERE usd.user_id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

#### MongoDB Encryption at Rest
```yaml
# mongod.conf - Encryption configuration
security:
  enableEncryption: true
  encryptionKeyFile: /etc/mongodb/encryption-keyfile
  encryptionCipherMode: AES256-CBC
  kmip:
    keyIdentifier: "mongodb-key-identifier"
    rotateMasterKey: true
    serverName: "kmip.example.com"
    port: 5696
    clientCertificateFile: /etc/mongodb/client.pem
```

```javascript
// Application-level field encryption with MongoDB
// Using MongoDB Client-Side Field Level Encryption (CSFLE)

const { MongoClient, ClientEncryption } = require('mongodb');
const crypto = require('crypto');

// Encryption configuration
const kmsProviders = {
  local: {
    key: Buffer.from('your-96-byte-master-key-here', 'base64')
  }
};

const keyVaultNamespace = 'encryption.__keyVault';

// Create data encryption keys
async function createDataEncryptionKey() {
  const client = new MongoClient(connectionString);
  await client.connect();
  
  const encryption = new ClientEncryption(client, {
    keyVaultNamespace,
    kmsProviders
  });

  // Create key for SSN encryption
  const ssnKeyId = await encryption.createDataKey('local', {
    keyAltNames: ['ssn_key']
  });

  // Create key for phone encryption  
  const phoneKeyId = await encryption.createDataKey('local', {
    keyAltNames: ['phone_key']
  });

  await client.close();
  return { ssnKeyId, phoneKeyId };
}

// Encryption schema for automatic encryption
const encryptionSchema = {
  'edtech_db.users': {
    bsonType: 'object',
    properties: {
      ssn: {
        encrypt: {
          keyId: [Binary.createFromBase64('ssnKeyId')],
          bsonType: 'string',
          algorithm: 'AEAD_AES_256_CBC_HMAC_SHA_512-Deterministic'
        }
      },
      phone: {
        encrypt: {
          keyId: [Binary.createFromBase64('phoneKeyId')],
          bsonType: 'string', 
          algorithm: 'AEAD_AES_256_CBC_HMAC_SHA_512-Random'
        }
      }
    }
  }
};

// Client with automatic encryption
const encryptedClient = new MongoClient(connectionString, {
  autoEncryption: {
    keyVaultNamespace,
    kmsProviders,
    schemaMap: encryptionSchema,
    extraOptions: {
      cryptSharedLibPath: '/path/to/crypt_shared'
    }
  }
});
```

### Encryption in Transit

#### SSL/TLS Configuration for Both Databases
```typescript
// PostgreSQL SSL connection
import { Pool } from 'pg';
import fs from 'fs';

const pool = new Pool({
  host: process.env.DB_HOST,
  port: 5432,
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  ssl: {
    rejectUnauthorized: true,
    ca: fs.readFileSync('/path/to/ca-certificate.crt').toString(),
    cert: fs.readFileSync('/path/to/client-certificate.crt').toString(),
    key: fs.readFileSync('/path/to/client-key.key').toString(),
  }
});

// MongoDB TLS connection
import { MongoClient } from 'mongodb';

const mongoClient = new MongoClient(connectionString, {
  tls: true,
  tlsCAFile: '/path/to/ca-certificate.pem',
  tlsCertificateKeyFile: '/path/to/client-certificate.pem',
  tlsAllowInvalidCertificates: false,
  tlsAllowInvalidHostnames: false,
  tlsInsecure: false
});
```

## 📊 Audit Logging and Monitoring

### PostgreSQL Audit Implementation
```sql
-- Install and configure pgAudit extension
CREATE EXTENSION IF NOT EXISTS pgaudit;

-- Configure audit settings in postgresql.conf
shared_preload_libraries = 'pgaudit'
pgaudit.log = 'all'                    # Log all operations
pgaudit.log_catalog = off              # Don't log catalog queries
pgaudit.log_client = on                # Log to client
pgaudit.log_level = log                # Log level
pgaudit.log_parameter = on             # Log parameters
pgaudit.log_relation = on              # Log relation names
pgaudit.log_statement_once = off       # Log each statement
pgaudit.role = 'audit_role'            # Audit role

-- Create audit role and tables
CREATE ROLE audit_role;

-- Grant audit role to users that need detailed logging
GRANT audit_role TO api_service;
GRANT audit_role TO db_admin;

-- Create custom audit log table for application events
CREATE TABLE audit_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID,
    user_email VARCHAR(255),
    action VARCHAR(100) NOT NULL,
    table_name VARCHAR(100),
    record_id TEXT,
    old_values JSONB,
    new_values JSONB,
    ip_address INET,
    user_agent TEXT,
    session_id VARCHAR(255),
    application_name VARCHAR(100),
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for audit log queries
CREATE INDEX idx_audit_log_user_id ON audit_log (user_id, timestamp DESC);
CREATE INDEX idx_audit_log_action ON audit_log (action, timestamp DESC);
CREATE INDEX idx_audit_log_table ON audit_log (table_name, timestamp DESC);
CREATE INDEX idx_audit_log_timestamp ON audit_log (timestamp DESC);

-- Audit trigger function
CREATE OR REPLACE FUNCTION audit_trigger_function()
RETURNS TRIGGER AS $$
DECLARE
    user_id_val UUID;
    user_email_val VARCHAR(255);
    old_data JSONB;
    new_data JSONB;
BEGIN
    -- Get current user context
    user_id_val := COALESCE(current_setting('app.current_user_id', true)::UUID, NULL);
    user_email_val := current_setting('app.current_user_email', true);
    
    -- Prepare old and new data
    IF TG_OP = 'DELETE' THEN
        old_data := to_jsonb(OLD);
        new_data := NULL;
    ELSIF TG_OP = 'INSERT' THEN
        old_data := NULL;
        new_data := to_jsonb(NEW);
    ELSE -- UPDATE
        old_data := to_jsonb(OLD);
        new_data := to_jsonb(NEW);
    END IF;
    
    -- Insert audit record
    INSERT INTO audit_log (
        user_id,
        user_email,
        action,
        table_name,
        record_id,
        old_values,
        new_values,
        ip_address,
        session_id,
        application_name
    ) VALUES (
        user_id_val,
        user_email_val,
        TG_OP,
        TG_TABLE_NAME,
        COALESCE(NEW.id::TEXT, OLD.id::TEXT),
        old_data,
        new_data,
        inet_client_addr(),
        current_setting('app.session_id', true),
        current_setting('application_name', true)
    );
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Apply audit triggers to sensitive tables
CREATE TRIGGER users_audit_trigger
    AFTER INSERT OR UPDATE OR DELETE ON users
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();

CREATE TRIGGER user_progress_audit_trigger
    AFTER INSERT OR UPDATE OR DELETE ON user_progress
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();

CREATE TRIGGER courses_audit_trigger
    AFTER INSERT OR UPDATE OR DELETE ON courses
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();
```

### MongoDB Audit Configuration
```yaml
# mongod.conf - Audit configuration
auditLog:
  destination: file
  format: JSON
  path: /var/log/mongodb/audit.json
  filter: |
    {
      atype: {
        $in: [
          "authenticate", "authCheck", "createUser", "dropUser",
          "createRole", "dropRole", "createCollection", "dropCollection",
          "insert", "update", "remove", "find"
        ]
      }
    }
```

```javascript
// Custom audit logging for MongoDB
class MongoAuditLogger {
  constructor(db) {
    this.db = db;
    this.auditCollection = db.collection('audit_log');
  }

  async logOperation(operation, collection, userId, data) {
    const auditRecord = {
      timestamp: new Date(),
      operation: operation,
      collection: collection,
      userId: userId,
      userEmail: data.userEmail,
      ipAddress: data.ipAddress,
      userAgent: data.userAgent,
      sessionId: data.sessionId,
      documentId: data.documentId,
      oldValues: data.oldValues || null,
      newValues: data.newValues || null,
      success: data.success,
      error: data.error || null
    };

    try {
      await this.auditCollection.insertOne(auditRecord);
    } catch (error) {
      console.error('Failed to log audit record:', error);
    }
  }

  // Audit wrapper for database operations
  async auditedOperation(operation, collection, userId, operationData, auditData) {
    const startTime = Date.now();
    let result;
    let success = true;
    let error = null;

    try {
      result = await operation();
    } catch (err) {
      success = false;
      error = err.message;
      throw err;
    } finally {
      const duration = Date.now() - startTime;
      
      await this.logOperation(operationData.type, collection, userId, {
        ...auditData,
        success,
        error,
        duration,
        documentId: operationData.documentId,
        oldValues: operationData.oldValues,
        newValues: operationData.newValues
      });
    }

    return result;
  }
}

// Usage example
const auditLogger = new MongoAuditLogger(db);

async function updateUserProfile(userId, updateData, auditContext) {
  const collection = db.collection('users');
  
  return auditLogger.auditedOperation(
    () => collection.updateOne(
      { _id: ObjectId(userId) },
      { $set: updateData }
    ),
    'users',
    userId,
    {
      type: 'UPDATE',
      documentId: userId,
      newValues: updateData
    },
    auditContext
  );
}
```

## 🚨 Security Incident Response

### Automated Threat Detection
```sql
-- PostgreSQL security monitoring queries
-- Detect suspicious login patterns
CREATE OR REPLACE FUNCTION detect_suspicious_logins()
RETURNS TABLE(
    user_email VARCHAR(255),
    failed_attempts BIGINT,
    unique_ips BIGINT,
    first_attempt TIMESTAMP WITH TIME ZONE,
    last_attempt TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        al.user_email,
        COUNT(*) as failed_attempts,
        COUNT(DISTINCT al.ip_address) as unique_ips,
        MIN(al.timestamp) as first_attempt,
        MAX(al.timestamp) as last_attempt
    FROM audit_log al
    WHERE al.action = 'FAILED_LOGIN'
      AND al.timestamp >= NOW() - INTERVAL '1 hour'
    GROUP BY al.user_email
    HAVING COUNT(*) >= 5  -- 5 failed attempts in 1 hour
       OR COUNT(DISTINCT al.ip_address) >= 3; -- From 3+ different IPs
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Detect unusual data access patterns
CREATE OR REPLACE FUNCTION detect_unusual_access()
RETURNS TABLE(
    user_id UUID,
    user_email VARCHAR(255),
    records_accessed BIGINT,
    tables_accessed BIGINT,
    access_period INTERVAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        al.user_id,
        al.user_email,
        COUNT(*) as records_accessed,
        COUNT(DISTINCT al.table_name) as tables_accessed,
        MAX(al.timestamp) - MIN(al.timestamp) as access_period
    FROM audit_log al
    WHERE al.action IN ('SELECT', 'UPDATE', 'DELETE')
      AND al.timestamp >= NOW() - INTERVAL '10 minutes'
    GROUP BY al.user_id, al.user_email
    HAVING COUNT(*) >= 1000  -- 1000+ records in 10 minutes
       OR COUNT(DISTINCT al.table_name) >= 10; -- Accessing 10+ tables
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

```javascript
// MongoDB security monitoring
class SecurityMonitor {
  constructor(db) {
    this.db = db;
    this.auditCollection = db.collection('audit_log');
  }

  async detectSuspiciousActivity() {
    const suspiciousLogins = await this.auditCollection.aggregate([
      {
        $match: {
          operation: 'authenticate',
          success: false,
          timestamp: { $gte: new Date(Date.now() - 60 * 60 * 1000) } // Last hour
        }
      },
      {
        $group: {
          _id: "$userEmail",
          failedAttempts: { $sum: 1 },
          uniqueIPs: { $addToSet: "$ipAddress" },
          firstAttempt: { $min: "$timestamp" },
          lastAttempt: { $max: "$timestamp" }
        }
      },
      {
        $match: {
          $or: [
            { failedAttempts: { $gte: 5 } },
            { "uniqueIPs.4": { $exists: true } } // 5+ unique IPs
          ]
        }
      }
    ]).toArray();

    return suspiciousLogins;
  }

  async detectMassDataAccess() {
    const massAccess = await this.auditCollection.aggregate([
      {
        $match: {
          operation: { $in: ['find', 'update', 'remove'] },
          timestamp: { $gte: new Date(Date.now() - 10 * 60 * 1000) } // Last 10 minutes
        }
      },
      {
        $group: {
          _id: "$userId",
          operationCount: { $sum: 1 },
          collectionsAccessed: { $addToSet: "$collection" },
          timespan: {
            $max: { $subtract: ["$timestamp", { $min: "$timestamp" }] }
          }
        }
      },
      {
        $match: {
          $or: [
            { operationCount: { $gte: 1000 } },
            { "collectionsAccessed.9": { $exists: true } } // 10+ collections
          ]
        }
      }
    ]).toArray();

    return massAccess;
  }

  async startMonitoring() {
    setInterval(async () => {
      try {
        const [suspiciousLogins, massAccess] = await Promise.all([
          this.detectSuspiciousActivity(),
          this.detectMassDataAccess()
        ]);

        if (suspiciousLogins.length > 0) {
          console.warn('🚨 Suspicious login activity detected:', suspiciousLogins);
          // Trigger alerts, lock accounts, etc.
        }

        if (massAccess.length > 0) {
          console.warn('🚨 Mass data access detected:', massAccess);
          // Trigger alerts, review access patterns, etc.
        }
      } catch (error) {
        console.error('Security monitoring error:', error);
      }
    }, 60000); // Check every minute
  }
}
```

## 🛡️ Data Protection and Privacy

### Data Anonymization and Pseudonymization
```sql
-- PostgreSQL data anonymization functions
CREATE OR REPLACE FUNCTION anonymize_email(email TEXT)
RETURNS TEXT AS $$
BEGIN
    RETURN 'user' || abs(hashtext(email)) || '@anonymized.com';
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION anonymize_name(name TEXT)
RETURNS TEXT AS $$
BEGIN
    RETURN 'User' || abs(hashtext(name));
END;
$$ LANGUAGE plpgsql;

-- Create anonymized view for analytics
CREATE VIEW anonymized_user_analytics AS
SELECT 
    id,
    anonymize_email(email) as email,
    anonymize_name(first_name) as first_name,
    anonymize_name(last_name) as last_name,
    DATE_TRUNC('month', created_at) as signup_month,
    subscription_tier,
    is_active,
    -- Remove exact timestamps, keep relative data
    EXTRACT(DOW FROM created_at) as signup_day_of_week,
    EXTRACT(HOUR FROM created_at) as signup_hour
FROM users;

-- Data retention and deletion procedures
CREATE OR REPLACE FUNCTION delete_expired_data()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER := 0;
BEGIN
    -- Delete old audit logs (keep 2 years)
    DELETE FROM audit_log 
    WHERE timestamp < NOW() - INTERVAL '2 years';
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    
    -- Delete inactive user sessions (keep 90 days)
    DELETE FROM user_sessions 
    WHERE last_activity < NOW() - INTERVAL '90 days';
    
    -- Anonymize deleted user data (GDPR right to be forgotten)
    UPDATE users SET
        email = anonymize_email(email),
        first_name = anonymize_name(first_name),
        last_name = anonymize_name(last_name),
        updated_at = NOW()
    WHERE is_deleted = true 
      AND updated_at < NOW() - INTERVAL '30 days';
    
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

```javascript
// MongoDB data anonymization
class DataAnonymizer {
  constructor(db) {
    this.db = db;
  }

  anonymizeEmail(email) {
    const hash = crypto.createHash('sha256').update(email).digest('hex').slice(0, 8);
    return `user${hash}@anonymized.com`;
  }

  anonymizeName(name) {
    const hash = crypto.createHash('sha256').update(name).digest('hex').slice(0, 8);
    return `User${hash}`;
  }

  async anonymizeUser(userId) {
    const user = await this.db.collection('users').findOne({ _id: ObjectId(userId) });
    
    if (!user) {
      throw new Error('User not found');
    }

    const anonymizedData = {
      email: this.anonymizeEmail(user.email),
      firstName: this.anonymizeName(user.firstName),
      lastName: this.anonymizeName(user.lastName),
      'profile.phone': null,
      'profile.address': null,
      'profile.dateOfBirth': null,
      anonymizedAt: new Date(),
      isAnonymized: true
    };

    await this.db.collection('users').updateOne(
      { _id: ObjectId(userId) },
      { $set: anonymizedData }
    );

    // Also anonymize related collections
    await this.anonymizeUserRelatedData(userId);
  }

  async anonymizeUserRelatedData(userId) {
    // Anonymize user progress data
    await this.db.collection('user_progress').updateMany(
      { userId: ObjectId(userId) },
      { 
        $unset: { 
          'personalNotes': '',
          'privateFlags': '' 
        },
        $set: { 
          anonymizedAt: new Date(),
          isAnonymized: true 
        }
      }
    );

    // Remove or anonymize quiz attempt details
    await this.db.collection('quiz_attempts').updateMany(
      { userId: ObjectId(userId) },
      { 
        $unset: { 
          'detailedAnswers': '',
          'timingData': '' 
        },
        $set: { 
          anonymizedAt: new Date(),
          isAnonymized: true 
        }
      }
    );
  }

  async createAnonymizedDataset() {
    // Create anonymized collection for analytics
    await this.db.collection('users').aggregate([
      {
        $project: {
          email: { $concat: ['user', { $toString: { $mod: [{ $toInt: '$_id' }, 100000] } }, '@anonymized.com'] },
          signupMonth: { $dateToString: { format: '%Y-%m', date: '$createdAt' } },
          subscriptionTier: 1,
          isActive: 1,
          signupDayOfWeek: { $dayOfWeek: '$createdAt' },
          signupHour: { $hour: '$createdAt' },
          // Remove all personally identifiable information
          firstName: 0,
          lastName: 0,
          profile: 0,
          billing: 0
        }
      },
      {
        $out: 'anonymized_users_analytics'
      }
    ]).toArray();
  }

  async deleteExpiredData() {
    const twoYearsAgo = new Date(Date.now() - 2 * 365 * 24 * 60 * 60 * 1000);
    const ninetyDaysAgo = new Date(Date.now() - 90 * 24 * 60 * 60 * 1000);

    // Delete old audit logs
    await this.db.collection('audit_log').deleteMany({
      timestamp: { $lt: twoYearsAgo }
    });

    // Delete old session data
    await this.db.collection('sessions').deleteMany({
      lastActivity: { $lt: ninetyDaysAgo }
    });

    // Delete temporary files
    await this.db.collection('temp_uploads').deleteMany({
      expiresAt: { $lt: new Date() }
    });
  }
}
```

This comprehensive security guide provides enterprise-grade protection strategies for both PostgreSQL and MongoDB deployments, covering all critical aspects of database security for EdTech applications handling sensitive educational data.

---

⬅️ **[Previous: Performance Analysis](./performance-analysis.md)**  
➡️ **[Next: Migration Strategy](./migration-strategy.md)**  
🏠 **[Research Home](../../README.md)**

---

*Security Considerations - Comprehensive database protection strategies for EdTech applications*