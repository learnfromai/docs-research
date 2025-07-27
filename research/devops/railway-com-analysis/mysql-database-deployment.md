# MySQL Database Deployment on Railway.com

## Overview

This guide covers deploying and managing MySQL databases on Railway.com, including setup, configuration, resource sharing strategies, and optimization for applications like clinic management systems.

## MySQL Service Options on Railway

### 1. Railway Managed MySQL
Railway provides **fully managed MySQL instances** with:
- Automatic backups and point-in-time recovery
- Built-in monitoring and metrics
- Automatic scaling and resource management
- Private networking with other Railway services
- SSL/TLS encryption by default

### 2. External MySQL Providers
You can also connect to external MySQL services:
- **PlanetScale**: Serverless MySQL with branching
- **AWS RDS**: Enterprise-grade managed MySQL
- **Google Cloud SQL**: Scalable MySQL hosting
- **DigitalOcean Managed Databases**: Cost-effective MySQL

## Setting Up Railway MySQL Service

### 1. Create MySQL Service via Dashboard

1. **Login to Railway Dashboard**
   ```bash
   railway login
   ```

2. **Create New Project or Use Existing**
   ```bash
   railway new clinic-management
   # or
   railway link  # if connecting to existing project
   ```

3. **Add MySQL Service**
   - Go to Railway dashboard
   - Click "Add Service" → "Database" → "MySQL"
   - Railway automatically provisions MySQL 8.0 instance

### 2. Create MySQL Service via CLI

```bash
# Create MySQL service
railway service create mysql

# Set MySQL configuration
railway variables set MYSQL_ROOT_PASSWORD=$(openssl rand -base64 32)
railway variables set MYSQL_DATABASE=clinic_db
railway variables set MYSQL_USER=clinic_user
railway variables set MYSQL_PASSWORD=$(openssl rand -base64 32)
```

### 3. Automatic Configuration

Railway automatically provides these environment variables:
```bash
DATABASE_URL=mysql://root:password@mysql.railway.internal:3306/clinic_db
MYSQL_URL=mysql://root:password@mysql.railway.internal:3306/clinic_db
MYSQL_HOST=mysql.railway.internal
MYSQL_PORT=3306
MYSQL_DATABASE=clinic_db
MYSQL_USER=root
MYSQL_PASSWORD=generated_password
```

## Database Schema Setup

### 1. Initial Schema Creation

Create `database/schema.sql`:

```sql
-- Clinic Management System Database Schema

-- Create database (if not exists)
CREATE DATABASE IF NOT EXISTS clinic_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE clinic_db;

-- Patients table
CREATE TABLE patients (
  id INT AUTO_INCREMENT PRIMARY KEY,
  patient_id VARCHAR(20) UNIQUE NOT NULL,
  first_name VARCHAR(100) NOT NULL,
  last_name VARCHAR(100) NOT NULL,
  date_of_birth DATE NOT NULL,
  gender ENUM('Male', 'Female', 'Other') NOT NULL,
  phone VARCHAR(20),
  email VARCHAR(255),
  address TEXT,
  emergency_contact_name VARCHAR(100),
  emergency_contact_phone VARCHAR(20),
  medical_history TEXT,
  allergies TEXT,
  current_medications TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_patient_id (patient_id),
  INDEX idx_name (last_name, first_name),
  INDEX idx_phone (phone)
);

-- Appointments table
CREATE TABLE appointments (
  id INT AUTO_INCREMENT PRIMARY KEY,
  patient_id INT NOT NULL,
  appointment_date DATE NOT NULL,
  appointment_time TIME NOT NULL,
  duration_minutes INT DEFAULT 30,
  appointment_type ENUM('Consultation', 'Follow-up', 'Emergency', 'Procedure') NOT NULL,
  status ENUM('Scheduled', 'Confirmed', 'In Progress', 'Completed', 'Cancelled', 'No Show') DEFAULT 'Scheduled',
  notes TEXT,
  created_by VARCHAR(100),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (patient_id) REFERENCES patients(id) ON DELETE CASCADE,
  INDEX idx_date (appointment_date),
  INDEX idx_patient (patient_id),
  INDEX idx_status (status)
);

-- Medical records table
CREATE TABLE medical_records (
  id INT AUTO_INCREMENT PRIMARY KEY,
  patient_id INT NOT NULL,
  appointment_id INT,
  record_date DATE NOT NULL,
  chief_complaint TEXT,
  diagnosis TEXT,
  treatment_plan TEXT,
  prescribed_medications TEXT,
  follow_up_instructions TEXT,
  doctor_notes TEXT,
  vital_signs JSON,
  created_by VARCHAR(100),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (patient_id) REFERENCES patients(id) ON DELETE CASCADE,
  FOREIGN KEY (appointment_id) REFERENCES appointments(id) ON DELETE SET NULL,
  INDEX idx_patient (patient_id),
  INDEX idx_date (record_date)
);

-- Users (staff) table
CREATE TABLE users (
  id INT AUTO_INCREMENT PRIMARY KEY,
  username VARCHAR(50) UNIQUE NOT NULL,
  email VARCHAR(255) UNIQUE NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  first_name VARCHAR(100) NOT NULL,
  last_name VARCHAR(100) NOT NULL,
  role ENUM('Admin', 'Doctor', 'Nurse', 'Receptionist') NOT NULL,
  is_active BOOLEAN DEFAULT TRUE,
  last_login TIMESTAMP NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_username (username),
  INDEX idx_email (email),
  INDEX idx_role (role)
);

-- Clinic settings table
CREATE TABLE clinic_settings (
  id INT AUTO_INCREMENT PRIMARY KEY,
  setting_key VARCHAR(100) UNIQUE NOT NULL,
  setting_value TEXT,
  description TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Insert default clinic settings
INSERT INTO clinic_settings (setting_key, setting_value, description) VALUES
('clinic_name', 'Medical Clinic', 'Name of the clinic'),
('clinic_address', '', 'Clinic address'),
('clinic_phone', '', 'Clinic phone number'),
('clinic_email', '', 'Clinic email address'),
('appointment_duration', '30', 'Default appointment duration in minutes'),
('working_hours_start', '08:00', 'Clinic opening time'),
('working_hours_end', '17:00', 'Clinic closing time'),
('working_days', 'Monday,Tuesday,Wednesday,Thursday,Friday', 'Working days of the week');

-- Create default admin user (password: admin123)
INSERT INTO users (username, email, password_hash, first_name, last_name, role) VALUES
('admin', 'admin@clinic.com', '$2b$10$8nNzx3lqJ0Xp2Kj4qN1vNe5yKjHgFdSaQwErTyUiOpAsDfGhJkL2', 'Admin', 'User', 'Admin');
```

### 2. Database Migration Scripts

Create `database/migrations/001_initial_schema.sql`:

```sql
-- Migration 001: Initial Schema
-- Created: 2025-01-XX
-- Description: Create initial clinic management system tables

-- Add your schema here (same as above)
```

Create `database/migrations/002_add_indexes.sql`:

```sql
-- Migration 002: Add Performance Indexes
-- Created: 2025-01-XX
-- Description: Add database indexes for better query performance

-- Additional indexes for better performance
CREATE INDEX idx_appointments_datetime ON appointments(appointment_date, appointment_time);
CREATE INDEX idx_medical_records_patient_date ON medical_records(patient_id, record_date DESC);
CREATE INDEX idx_patients_full_name ON patients(first_name, last_name);

-- Full-text search indexes
ALTER TABLE patients ADD FULLTEXT(first_name, last_name, patient_id);
ALTER TABLE medical_records ADD FULLTEXT(chief_complaint, diagnosis);
```

## Database Connection Configuration

### 1. Node.js/Express.js Connection

Create `libs/database/src/mysql-connection.ts`:

```typescript
import mysql from 'mysql2/promise';
import { ConnectionOptions } from 'mysql2';

interface DatabaseConfig extends ConnectionOptions {
  host: string;
  port: number;
  user: string;
  password: string;
  database: string;
  ssl?: any;
}

class DatabaseConnection {
  private pool: mysql.Pool;
  private config: DatabaseConfig;

  constructor() {
    this.config = {
      host: process.env.MYSQL_HOST!,
      port: parseInt(process.env.MYSQL_PORT || '3306'),
      user: process.env.MYSQL_USER!,
      password: process.env.MYSQL_PASSWORD!,
      database: process.env.MYSQL_DATABASE!,
      ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false,
      connectionLimit: 10,
      acquireTimeout: 60000,
      timeout: 60000,
      multipleStatements: true,
      timezone: 'Z'
    };

    this.pool = mysql.createPool(this.config);
  }

  async query(sql: string, params?: any[]): Promise<any> {
    try {
      const [rows] = await this.pool.execute(sql, params);
      return rows;
    } catch (error) {
      console.error('Database query error:', error);
      throw error;
    }
  }

  async transaction<T>(callback: (connection: mysql.PoolConnection) => Promise<T>): Promise<T> {
    const connection = await this.pool.getConnection();
    
    try {
      await connection.beginTransaction();
      const result = await callback(connection);
      await connection.commit();
      return result;
    } catch (error) {
      await connection.rollback();
      throw error;
    } finally {
      connection.release();
    }
  }

  async checkConnection(): Promise<boolean> {
    try {
      await this.pool.execute('SELECT 1');
      return true;
    } catch (error) {
      console.error('Database connection check failed:', error);
      return false;
    }
  }

  async close(): Promise<void> {
    await this.pool.end();
  }
}

// Singleton instance
export const db = new DatabaseConnection();
```

### 2. Environment Variables Setup

```bash
# Railway environment variables for MySQL
DATABASE_URL=mysql://root:${MYSQL_PASSWORD}@${MYSQL_HOST}:${MYSQL_PORT}/${MYSQL_DATABASE}
MYSQL_HOST=mysql.railway.internal
MYSQL_PORT=3306
MYSQL_DATABASE=clinic_db
MYSQL_USER=root
MYSQL_PASSWORD=generated_secure_password

# Connection pool settings
DB_CONNECTION_LIMIT=10
DB_ACQUIRE_TIMEOUT=60000
DB_TIMEOUT=60000
```

## Resource Sharing and Optimization

### 1. Connection Pooling Strategy

```typescript
// Optimized pool configuration for small clinic
const poolConfig = {
  connectionLimit: 5,        // Maximum 5 concurrent connections
  acquireTimeout: 30000,     // 30 second timeout
  timeout: 30000,            // Query timeout
  idleTimeout: 300000,       // 5 minute idle timeout
  reconnect: true,           // Auto-reconnect on connection loss
  multipleStatements: false  // Security best practice
};
```

### 2. Query Optimization

```typescript
// Efficient patient search
export class PatientService {
  async searchPatients(searchTerm: string, limit = 20): Promise<Patient[]> {
    const sql = `
      SELECT id, patient_id, first_name, last_name, phone, email
      FROM patients 
      WHERE MATCH(first_name, last_name, patient_id) AGAINST(? IN BOOLEAN MODE)
         OR phone LIKE ?
         OR email LIKE ?
      ORDER BY 
        CASE 
          WHEN patient_id = ? THEN 1
          WHEN CONCAT(first_name, ' ', last_name) = ? THEN 2
          ELSE 3
        END
      LIMIT ?
    `;
    
    const likePattern = `%${searchTerm}%`;
    return await db.query(sql, [
      searchTerm, likePattern, likePattern, 
      searchTerm, searchTerm, limit
    ]);
  }

  async getPatientWithHistory(patientId: number): Promise<any> {
    // Use JOIN to get patient data and recent records in single query
    const sql = `
      SELECT 
        p.*,
        JSON_ARRAYAGG(
          CASE WHEN mr.id IS NOT NULL THEN
            JSON_OBJECT(
              'id', mr.id,
              'record_date', mr.record_date,
              'chief_complaint', mr.chief_complaint,
              'diagnosis', mr.diagnosis
            )
          END
        ) as medical_history
      FROM patients p
      LEFT JOIN medical_records mr ON p.id = mr.patient_id 
        AND mr.record_date >= DATE_SUB(CURRENT_DATE, INTERVAL 6 MONTH)
      WHERE p.id = ?
      GROUP BY p.id
    `;
    
    const result = await db.query(sql, [patientId]);
    return result[0];
  }
}
```

## Storage and Pricing Analysis

### 1. Storage Consumption Estimates

**Small Clinic Management System (2-3 users)**:

| Data Type | Initial Size | Monthly Growth | 1 Year Projection |
|-----------|-------------|----------------|-------------------|
| **Patient Records** | 100 records × 2KB | 50 records × 2KB | ~600KB |
| **Appointments** | 200 entries × 1KB | 100 entries × 1KB | ~1.4MB |
| **Medical Records** | 150 records × 5KB | 75 records × 5KB | ~4.2MB |
| **System Data** | 50KB | 10KB/month | ~170KB |
| **Indexes & Overhead** | 200KB | 50KB/month | ~800KB |
| **Total Storage** | **~1MB** | **~500KB/month** | **~7MB** |

### 2. Railway MySQL Pricing

**Storage Costs**:
- **Price**: $0.25 per GB per month
- **Small clinic projection**: 7MB = 0.007GB
- **Monthly storage cost**: 0.007 × $0.25 = **$0.002/month**

**Compute Costs** (for database operations):
- **CPU**: $0.000694 per vCPU-hour
- **Memory**: $0.000694 per GB-hour
- **Typical small clinic usage**:
  - 0.25 vCPU × 720 hours = $0.125
  - 1GB RAM × 720 hours = $0.50
  - **Total compute**: **~$0.625/month**

**Total MySQL Cost**: **~$0.63/month**

### 3. Growth Projections

**Scaling scenarios**:

| Scenario | Patients | Storage | Monthly Cost |
|----------|----------|---------|-------------|
| **Small Clinic** | 500 patients | 7MB | $0.63 |
| **Medium Clinic** | 2,000 patients | 50MB | $0.68 |
| **Large Clinic** | 10,000 patients | 500MB | $1.25 |

## Backup and Recovery

### 1. Railway Automatic Backups
Railway provides automatic backups:
- **Daily backups** retained for 7 days
- **Point-in-time recovery** up to 7 days
- **No additional cost** for standard backups

### 2. Custom Backup Strategy

Create backup script `scripts/backup-database.js`:

```javascript
const mysqldump = require('mysqldump');
const fs = require('fs');
const path = require('path');

async function createBackup() {
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
  const backupFile = path.join(__dirname, `../backups/clinic_db_${timestamp}.sql`);
  
  try {
    await mysqldump({
      connection: {
        host: process.env.MYSQL_HOST,
        user: process.env.MYSQL_USER,
        password: process.env.MYSQL_PASSWORD,
        database: process.env.MYSQL_DATABASE,
      },
      dumpToFile: backupFile,
      compressFile: true
    });
    
    console.log(`Backup created: ${backupFile}`);
    
    // Upload to cloud storage (optional)
    // await uploadToCloudStorage(backupFile);
    
  } catch (error) {
    console.error('Backup failed:', error);
  }
}

// Schedule backup (can be run as cron job)
if (require.main === module) {
  createBackup();
}

module.exports = { createBackup };
```

### 3. Data Migration Scripts

Create `scripts/migrate-database.js`:

```javascript
const fs = require('fs');
const path = require('path');
const { db } = require('../libs/database/src/mysql-connection');

async function runMigrations() {
  const migrationsDir = path.join(__dirname, '../database/migrations');
  const migrationFiles = fs.readdirSync(migrationsDir)
    .filter(file => file.endsWith('.sql'))
    .sort();

  // Create migrations table if not exists
  await db.query(`
    CREATE TABLE IF NOT EXISTS migrations (
      id INT AUTO_INCREMENT PRIMARY KEY,
      filename VARCHAR(255) UNIQUE NOT NULL,
      executed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  `);

  // Get executed migrations
  const executedMigrations = await db.query(
    'SELECT filename FROM migrations'
  );
  const executed = executedMigrations.map(m => m.filename);

  // Run pending migrations
  for (const file of migrationFiles) {
    if (!executed.includes(file)) {
      console.log(`Running migration: ${file}`);
      
      const sqlContent = fs.readFileSync(
        path.join(migrationsDir, file), 
        'utf8'
      );
      
      try {
        await db.query(sqlContent);
        await db.query(
          'INSERT INTO migrations (filename) VALUES (?)', 
          [file]
        );
        console.log(`Migration completed: ${file}`);
      } catch (error) {
        console.error(`Migration failed: ${file}`, error);
        break;
      }
    }
  }
}

if (require.main === module) {
  runMigrations()
    .then(() => process.exit(0))
    .catch(error => {
      console.error('Migration process failed:', error);
      process.exit(1);
    });
}

module.exports = { runMigrations };
```

## Performance Optimization

### 1. Database Indexes

```sql
-- Query performance indexes
CREATE INDEX idx_patients_search ON patients(last_name, first_name, patient_id);
CREATE INDEX idx_appointments_schedule ON appointments(appointment_date, appointment_time, status);
CREATE INDEX idx_medical_records_recent ON medical_records(patient_id, record_date DESC);

-- Composite indexes for common queries
CREATE INDEX idx_appointments_patient_status ON appointments(patient_id, status, appointment_date);
CREATE INDEX idx_patients_active ON patients(id) WHERE id IN (
  SELECT DISTINCT patient_id FROM appointments 
  WHERE appointment_date >= DATE_SUB(CURRENT_DATE, INTERVAL 1 YEAR)
);
```

### 2. Query Optimization Strategies

```typescript
// Efficient pagination
export async function getPatients(page = 1, limit = 20, search = '') {
  const offset = (page - 1) * limit;
  
  let whereClause = '';
  let params = [];
  
  if (search) {
    whereClause = `
      WHERE MATCH(first_name, last_name, patient_id) AGAINST(? IN BOOLEAN MODE)
         OR phone LIKE ? OR email LIKE ?
    `;
    const likePattern = `%${search}%`;
    params = [search, likePattern, likePattern];
  }
  
  // Get total count and data in parallel
  const [countResult, patients] = await Promise.all([
    db.query(`SELECT COUNT(*) as total FROM patients ${whereClause}`, params),
    db.query(`
      SELECT id, patient_id, first_name, last_name, phone, email, created_at
      FROM patients ${whereClause}
      ORDER BY last_name, first_name
      LIMIT ? OFFSET ?
    `, [...params, limit, offset])
  ]);
  
  return {
    patients,
    total: countResult[0].total,
    page,
    limit,
    totalPages: Math.ceil(countResult[0].total / limit)
  };
}
```

## Security Considerations

### 1. Connection Security

```typescript
const sslConfig = {
  ssl: {
    rejectUnauthorized: process.env.NODE_ENV === 'production',
    ca: process.env.MYSQL_SSL_CA,
    cert: process.env.MYSQL_SSL_CERT,
    key: process.env.MYSQL_SSL_KEY
  }
};
```

### 2. SQL Injection Prevention

```typescript
// Always use parameterized queries
export async function getPatientById(id: number) {
  // GOOD: Parameterized query
  const sql = 'SELECT * FROM patients WHERE id = ?';
  return await db.query(sql, [id]);
}

// BAD: String concatenation (vulnerable to SQL injection)
// const sql = `SELECT * FROM patients WHERE id = ${id}`;
```

### 3. Environment Variables Security

```bash
# Use Railway secrets for sensitive data
railway variables set MYSQL_ROOT_PASSWORD=$(openssl rand -base64 32)
railway variables set JWT_SECRET=$(openssl rand -base64 64)
railway variables set ENCRYPTION_KEY=$(openssl rand -base64 32)

# Mark variables as sensitive
railway variables set --sensitive MYSQL_PASSWORD=password123
```

## Monitoring and Maintenance

### 1. Database Health Checks

```typescript
export class DatabaseHealth {
  static async checkHealth(): Promise<HealthStatus> {
    try {
      const start = Date.now();
      
      // Test basic connectivity
      await db.query('SELECT 1');
      const responseTime = Date.now() - start;
      
      // Check table integrity
      const tables = ['patients', 'appointments', 'medical_records', 'users'];
      const tableChecks = await Promise.all(
        tables.map(table => db.query(`SELECT COUNT(*) as count FROM ${table}`))
      );
      
      // Get database size
      const sizeResult = await db.query(`
        SELECT 
          ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'db_size_mb'
        FROM information_schema.tables 
        WHERE table_schema = ?
      `, [process.env.MYSQL_DATABASE]);
      
      return {
        status: 'healthy',
        responseTime,
        databaseSize: sizeResult[0].db_size_mb,
        tableStats: tableChecks.map((result, index) => ({
          table: tables[index],
          count: result[0].count
        })),
        timestamp: new Date().toISOString()
      };
      
    } catch (error) {
      return {
        status: 'unhealthy',
        error: error.message,
        timestamp: new Date().toISOString()
      };
    }
  }
}
```

### 2. Performance Monitoring

```typescript
// Add to Express.js middleware
app.use('/api', async (req, res, next) => {
  const start = Date.now();
  
  res.on('finish', () => {
    const duration = Date.now() - start;
    console.log(`${req.method} ${req.path} - ${res.statusCode} - ${duration}ms`);
    
    // Log slow queries (>1000ms)
    if (duration > 1000) {
      console.warn(`Slow query detected: ${req.method} ${req.path} took ${duration}ms`);
    }
  });
  
  next();
});
```

---

## Next Steps

1. **[Review Implementation Guide](./implementation-guide.md)** - Complete deployment setup
2. **[Check Best Practices](./best-practices.md)** - Security and optimization
3. **[Analyze Small-Scale Costs](./small-scale-cost-analysis.md)** - Detailed cost projections

---

*MySQL Database Deployment Guide | Railway.com Platform | January 2025*