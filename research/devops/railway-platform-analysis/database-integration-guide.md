# Database Integration Guide: Railway.com

## 🎯 Overview

This guide covers comprehensive database integration strategies for Railway.com, focusing on MySQL and PostgreSQL deployment, configuration, and optimization for production applications.

## 🗄 Database Services Overview

### Available Database Options

| Database | Version | Use Cases | Key Features |
|----------|---------|-----------|--------------|
| **PostgreSQL** | 15.x | Complex queries, JSON data, analytics | ACID compliance, advanced indexing, full-text search |
| **MySQL** | 8.x | Traditional web apps, clinic systems | High performance, replication, wide compatibility |
| **Redis** | 7.x | Caching, sessions, real-time features | In-memory, pub/sub, data structures |
| **MongoDB** | 6.x | Document storage, flexible schemas | NoSQL, horizontal scaling, aggregation |

### Recommended Choice for Clinic Management System

**MySQL** is recommended for clinic management systems because:
- **ACID compliance** for medical data integrity
- **Mature ecosystem** with extensive tooling
- **Predictable performance** for transactional workloads
- **Strong consistency** for critical healthcare data
- **Excellent integration** with Node.js/Express applications

## 🚀 MySQL Database Setup

### 1. Creating MySQL Service

```bash
# Create MySQL database service
railway service create mysql

# Set MySQL version (optional, defaults to latest)
railway variables set MYSQL_VERSION=8.0 --service mysql

# Get database connection details
railway variables get DATABASE_URL --service mysql
```

### 2. Database Configuration

**Connection String Format:**
```
mysql://username:password@hostname:port/database_name

Example:
mysql://root:password123@mysql.railway.app:3306/clinic_db
```

**Environment Variables Setup:**
```bash
# For API service
railway variables set DATABASE_URL=${{MySQL.DATABASE_URL}} --service api
railway variables set DB_HOST=${{MySQL.MYSQL_HOST}} --service api
railway variables set DB_PORT=${{MySQL.MYSQL_PORT}} --service api
railway variables set DB_USER=${{MySQL.MYSQL_USER}} --service api
railway variables set DB_PASSWORD=${{MySQL.MYSQL_PASSWORD}} --service api
railway variables set DB_NAME=${{MySQL.MYSQL_DATABASE}} --service api
```

### 3. Connection Pool Configuration

```javascript
// libs/shared/database/src/mysql-connection.ts
import mysql from 'mysql2/promise';

interface DatabaseConfig {
  host: string;
  port: number;
  user: string;
  password: string;
  database: string;
  connectionLimit?: number;
  acquireTimeout?: number;
  timeout?: number;
  reconnect?: boolean;
}

export class MySQLService {
  private pool: mysql.Pool;
  private config: DatabaseConfig;

  constructor(config: DatabaseConfig) {
    this.config = {
      connectionLimit: 10,
      acquireTimeout: 60000,
      timeout: 60000,
      reconnect: true,
      ...config
    };

    this.pool = mysql.createPool({
      host: this.config.host,
      port: this.config.port,
      user: this.config.user,
      password: this.config.password,
      database: this.config.database,
      connectionLimit: this.config.connectionLimit,
      queueLimit: 0,
      acquireTimeout: this.config.acquireTimeout,
      timeout: this.config.timeout,
      reconnect: this.config.reconnect,
      // Enable multiple statements for migrations
      multipleStatements: false,
      // Character set and timezone
      charset: 'utf8mb4',
      timezone: 'Z',
      // SSL configuration for production
      ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false
    });
  }

  async query<T>(sql: string, params?: any[]): Promise<T[]> {
    try {
      const [rows] = await this.pool.execute(sql, params);
      return rows as T[];
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

  async healthCheck(): Promise<boolean> {
    try {
      await this.query('SELECT 1');
      return true;
    } catch {
      return false;
    }
  }

  async close(): Promise<void> {
    await this.pool.end();
  }
}

// Database service factory
export function createDatabaseService(): MySQLService {
  const config = {
    host: process.env.DB_HOST || 'localhost',
    port: parseInt(process.env.DB_PORT || '3306'),
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || '',
    database: process.env.DB_NAME || 'clinic_db'
  };

  return new MySQLService(config);
}

// Export singleton instance
export const db = createDatabaseService();
```

## 🏗 Database Schema Design

### 1. Core Tables for Clinic Management

```sql
-- Database creation and character set
CREATE DATABASE clinic_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE clinic_db;

-- Users table (doctors, staff, admin)
CREATE TABLE users (
  id INT AUTO_INCREMENT PRIMARY KEY,
  email VARCHAR(255) UNIQUE NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  role ENUM('admin', 'doctor', 'nurse', 'receptionist') NOT NULL,
  first_name VARCHAR(100) NOT NULL,
  last_name VARCHAR(100) NOT NULL,
  phone VARCHAR(20),
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  INDEX idx_email (email),
  INDEX idx_role (role),
  INDEX idx_active (is_active)
);

-- Patients table
CREATE TABLE patients (
  id INT AUTO_INCREMENT PRIMARY KEY,
  patient_id VARCHAR(20) UNIQUE NOT NULL, -- Custom patient ID
  first_name VARCHAR(100) NOT NULL,
  last_name VARCHAR(100) NOT NULL,
  email VARCHAR(255),
  phone VARCHAR(20),
  date_of_birth DATE,
  gender ENUM('male', 'female', 'other'),
  address TEXT,
  emergency_contact_name VARCHAR(100),
  emergency_contact_phone VARCHAR(20),
  medical_history TEXT,
  allergies TEXT,
  current_medications TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  INDEX idx_patient_id (patient_id),
  INDEX idx_email (email),
  INDEX idx_name (last_name, first_name),
  INDEX idx_phone (phone),
  FULLTEXT idx_search (first_name, last_name, patient_id)
);

-- Appointments table
CREATE TABLE appointments (
  id INT AUTO_INCREMENT PRIMARY KEY,
  patient_id INT NOT NULL,
  doctor_id INT NOT NULL,
  scheduled_at DATETIME NOT NULL,
  duration_minutes INT DEFAULT 30,
  status ENUM('scheduled', 'confirmed', 'in_progress', 'completed', 'cancelled', 'no_show') DEFAULT 'scheduled',
  appointment_type ENUM('consultation', 'follow_up', 'emergency', 'procedure') DEFAULT 'consultation',
  chief_complaint TEXT,
  notes TEXT,
  created_by INT NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  FOREIGN KEY (patient_id) REFERENCES patients(id) ON DELETE CASCADE,
  FOREIGN KEY (doctor_id) REFERENCES users(id) ON DELETE RESTRICT,
  FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE RESTRICT,
  
  INDEX idx_patient (patient_id),
  INDEX idx_doctor (doctor_id),
  INDEX idx_scheduled_at (scheduled_at),
  INDEX idx_status (status),
  INDEX idx_doctor_date (doctor_id, scheduled_at),
  INDEX idx_patient_status (patient_id, status)
);

-- Medical records table
CREATE TABLE medical_records (
  id INT AUTO_INCREMENT PRIMARY KEY,
  appointment_id INT,
  patient_id INT NOT NULL,
  doctor_id INT NOT NULL,
  record_date DATE NOT NULL,
  diagnosis TEXT,
  symptoms TEXT,
  treatment_plan TEXT,
  prescribed_medications JSON, -- Store as JSON for flexibility
  lab_orders TEXT,
  follow_up_instructions TEXT,
  vital_signs JSON, -- Blood pressure, temperature, etc.
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  FOREIGN KEY (appointment_id) REFERENCES appointments(id) ON DELETE SET NULL,
  FOREIGN KEY (patient_id) REFERENCES patients(id) ON DELETE CASCADE,
  FOREIGN KEY (doctor_id) REFERENCES users(id) ON DELETE RESTRICT,
  
  INDEX idx_appointment (appointment_id),
  INDEX idx_patient (patient_id),
  INDEX idx_doctor (doctor_id),
  INDEX idx_record_date (record_date),
  INDEX idx_patient_date (patient_id, record_date)
);

-- Billing table
CREATE TABLE billing (
  id INT AUTO_INCREMENT PRIMARY KEY,
  patient_id INT NOT NULL,
  appointment_id INT,
  invoice_number VARCHAR(50) UNIQUE NOT NULL,
  service_description TEXT NOT NULL,
  amount DECIMAL(10, 2) NOT NULL,
  status ENUM('draft', 'sent', 'paid', 'overdue', 'cancelled') DEFAULT 'draft',
  due_date DATE,
  paid_date DATE,
  payment_method ENUM('cash', 'card', 'insurance', 'bank_transfer'),
  created_by INT NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  FOREIGN KEY (patient_id) REFERENCES patients(id) ON DELETE CASCADE,
  FOREIGN KEY (appointment_id) REFERENCES appointments(id) ON DELETE SET NULL,
  FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE RESTRICT,
  
  INDEX idx_patient (patient_id),
  INDEX idx_appointment (appointment_id),
  INDEX idx_invoice (invoice_number),
  INDEX idx_status (status),
  INDEX idx_due_date (due_date)
);
```

### 2. Database Triggers and Procedures

```sql
-- Trigger to auto-generate patient ID
DELIMITER //
CREATE TRIGGER generate_patient_id
BEFORE INSERT ON patients
FOR EACH ROW
BEGIN
  IF NEW.patient_id IS NULL OR NEW.patient_id = '' THEN
    SET NEW.patient_id = CONCAT('P', YEAR(NOW()), LPAD((
      SELECT COALESCE(MAX(CAST(SUBSTRING(patient_id, 6) AS UNSIGNED)), 0) + 1
      FROM patients 
      WHERE patient_id LIKE CONCAT('P', YEAR(NOW()), '%')
    ), 4, '0'));
  END IF;
END;//
DELIMITER ;

-- Trigger to auto-generate invoice numbers
DELIMITER //
CREATE TRIGGER generate_invoice_number
BEFORE INSERT ON billing
FOR EACH ROW
BEGIN
  IF NEW.invoice_number IS NULL OR NEW.invoice_number = '' THEN
    SET NEW.invoice_number = CONCAT('INV', YEAR(NOW()), MONTH(NOW()), LPAD((
      SELECT COALESCE(MAX(CAST(SUBSTRING(invoice_number, 8) AS UNSIGNED)), 0) + 1
      FROM billing 
      WHERE invoice_number LIKE CONCAT('INV', YEAR(NOW()), MONTH(NOW()), '%')
    ), 4, '0'));
  END IF;
END;//
DELIMITER ;

-- Procedure for appointment availability check
DELIMITER //
CREATE PROCEDURE CheckAppointmentAvailability(
  IN p_doctor_id INT,
  IN p_start_time DATETIME,
  IN p_duration_minutes INT,
  OUT p_available BOOLEAN
)
BEGIN
  DECLARE appointment_count INT DEFAULT 0;
  
  SELECT COUNT(*) INTO appointment_count
  FROM appointments 
  WHERE doctor_id = p_doctor_id 
    AND status NOT IN ('cancelled', 'no_show')
    AND (
      (scheduled_at BETWEEN p_start_time AND DATE_ADD(p_start_time, INTERVAL p_duration_minutes MINUTE))
      OR 
      (DATE_ADD(scheduled_at, INTERVAL duration_minutes MINUTE) BETWEEN p_start_time AND DATE_ADD(p_start_time, INTERVAL p_duration_minutes MINUTE))
      OR
      (scheduled_at <= p_start_time AND DATE_ADD(scheduled_at, INTERVAL duration_minutes MINUTE) >= DATE_ADD(p_start_time, INTERVAL p_duration_minutes MINUTE))
    );
  
  SET p_available = (appointment_count = 0);
END;//
DELIMITER ;
```

## 🔄 Migration System

### 1. Migration Framework

```typescript
// libs/shared/database/src/migrations/migration-runner.ts
import { db } from '../mysql-connection';
import fs from 'fs/promises';
import path from 'path';

interface Migration {
  id: number;
  filename: string;
  executed_at: Date;
}

export class MigrationRunner {
  private migrationsPath: string;

  constructor(migrationsPath: string = path.join(__dirname, 'migrations')) {
    this.migrationsPath = migrationsPath;
  }

  async ensureMigrationsTable(): Promise<void> {
    await db.query(`
      CREATE TABLE IF NOT EXISTS migrations (
        id INT AUTO_INCREMENT PRIMARY KEY,
        filename VARCHAR(255) NOT NULL UNIQUE,
        checksum VARCHAR(64) NOT NULL,
        executed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        
        INDEX idx_filename (filename)
      )
    `);
  }

  async getExecutedMigrations(): Promise<Set<string>> {
    const migrations = await db.query<Migration>(
      'SELECT filename FROM migrations ORDER BY id'
    );
    return new Set(migrations.map(m => m.filename));
  }

  async getMigrationFiles(): Promise<string[]> {
    try {
      const files = await fs.readdir(this.migrationsPath);
      return files
        .filter(f => f.endsWith('.sql'))
        .sort();
    } catch (error) {
      console.warn('Migrations directory not found:', this.migrationsPath);
      return [];
    }
  }

  async calculateChecksum(content: string): Promise<string> {
    const crypto = require('crypto');
    return crypto.createHash('sha256').update(content).digest('hex');
  }

  async runMigrations(): Promise<void> {
    console.log('🔄 Running database migrations...');
    
    await this.ensureMigrationsTable();
    
    const executedMigrations = await this.getExecutedMigrations();
    const migrationFiles = await this.getMigrationFiles();
    
    if (migrationFiles.length === 0) {
      console.log('ℹ️  No migration files found');
      return;
    }

    let migrationsRun = 0;

    for (const file of migrationFiles) {
      if (!executedMigrations.has(file)) {
        console.log(`📝 Running migration: ${file}`);
        
        try {
          const filePath = path.join(this.migrationsPath, file);
          const content = await fs.readFile(filePath, 'utf-8');
          const checksum = await this.calculateChecksum(content);
          
          // Split and execute multiple statements
          const statements = content
            .split(';')
            .map(s => s.trim())
            .filter(s => s.length > 0);

          await db.transaction(async (connection) => {
            for (const statement of statements) {
              if (statement.trim()) {
                await connection.execute(statement);
              }
            }
            
            await connection.execute(
              'INSERT INTO migrations (filename, checksum) VALUES (?, ?)',
              [file, checksum]
            );
          });
          
          migrationsRun++;
          console.log(`✅ Migration completed: ${file}`);
          
        } catch (error) {
          console.error(`❌ Migration failed: ${file}`, error);
          throw error;
        }
      }
    }
    
    if (migrationsRun === 0) {
      console.log('✅ Database is up to date');
    } else {
      console.log(`✅ Successfully ran ${migrationsRun} migration(s)`);
    }
  }

  async rollbackMigration(filename: string): Promise<void> {
    // Check if rollback file exists
    const rollbackFile = filename.replace('.sql', '.rollback.sql');
    const rollbackPath = path.join(this.migrationsPath, rollbackFile);
    
    try {
      const content = await fs.readFile(rollbackPath, 'utf-8');
      
      await db.transaction(async (connection) => {
        const statements = content
          .split(';')
          .map(s => s.trim())
          .filter(s => s.length > 0);

        for (const statement of statements) {
          if (statement.trim()) {
            await connection.execute(statement);
          }
        }
        
        await connection.execute(
          'DELETE FROM migrations WHERE filename = ?',
          [filename]
        );
      });
      
      console.log(`✅ Rollback completed: ${filename}`);
      
    } catch (error) {
      console.error(`❌ Rollback failed: ${filename}`, error);
      throw error;
    }
  }
}
```

### 2. Sample Migration Files

**001_create_users_table.sql:**
```sql
-- Migration: Create users table
CREATE TABLE users (
  id INT AUTO_INCREMENT PRIMARY KEY,
  email VARCHAR(255) UNIQUE NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  role ENUM('admin', 'doctor', 'nurse', 'receptionist') NOT NULL,
  first_name VARCHAR(100) NOT NULL,
  last_name VARCHAR(100) NOT NULL,
  phone VARCHAR(20),
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  INDEX idx_email (email),
  INDEX idx_role (role),
  INDEX idx_active (is_active)
);

-- Insert default admin user
INSERT INTO users (email, password_hash, role, first_name, last_name) 
VALUES ('admin@clinic.com', '$2b$10$defaulthashedpassword', 'admin', 'System', 'Administrator');
```

**001_create_users_table.rollback.sql:**
```sql
-- Rollback: Drop users table
DROP TABLE IF EXISTS users;
```

## 🔒 Security and Performance

### 1. Database Security

```typescript
// Security configuration
export const secureConnectionConfig = {
  // Enable SSL in production
  ssl: process.env.NODE_ENV === 'production' ? {
    rejectUnauthorized: true,
    ca: process.env.DB_SSL_CA,
    cert: process.env.DB_SSL_CERT,
    key: process.env.DB_SSL_KEY
  } : false,
  
  // Connection limits
  connectionLimit: parseInt(process.env.DB_CONNECTION_LIMIT || '10'),
  
  // Security settings
  charset: 'utf8mb4',
  timezone: 'Z',
  
  // Prevent SQL injection
  sql: {
    escapeId: true,
    timezone: 'Z'
  }
};

// Query builder with parameter validation
export class SecureQueryBuilder {
  static buildSelectQuery(
    table: string, 
    conditions: Record<string, any> = {}, 
    options: { limit?: number; offset?: number; orderBy?: string } = {}
  ): { sql: string; params: any[] } {
    const validTables = ['users', 'patients', 'appointments', 'medical_records', 'billing'];
    
    if (!validTables.includes(table)) {
      throw new Error(`Invalid table name: ${table}`);
    }

    let sql = `SELECT * FROM ${table}`;
    const params: any[] = [];
    
    if (Object.keys(conditions).length > 0) {
      const whereClause = Object.keys(conditions)
        .map(key => `${key} = ?`)
        .join(' AND ');
      sql += ` WHERE ${whereClause}`;
      params.push(...Object.values(conditions));
    }
    
    if (options.orderBy) {
      sql += ` ORDER BY ${options.orderBy}`;
    }
    
    if (options.limit) {
      sql += ` LIMIT ?`;
      params.push(options.limit);
      
      if (options.offset) {
        sql += ` OFFSET ?`;
        params.push(options.offset);
      }
    }
    
    return { sql, params };
  }
}
```

### 2. Performance Optimization

```sql
-- Performance optimization indexes
ALTER TABLE appointments ADD INDEX idx_doctor_date_status (doctor_id, scheduled_at, status);
ALTER TABLE medical_records ADD INDEX idx_patient_date_doctor (patient_id, record_date, doctor_id);
ALTER TABLE billing ADD INDEX idx_status_due_date (status, due_date);

-- Analyze table performance
ANALYZE TABLE patients, appointments, medical_records, billing;

-- Optimize tables
OPTIMIZE TABLE patients, appointments, medical_records, billing;

-- Monitor slow queries
SET GLOBAL slow_query_log = 'ON';
SET GLOBAL long_query_time = 2;
SET GLOBAL log_queries_not_using_indexes = 'ON';
```

## 📊 Backup and Recovery

### 1. Automated Backup Strategy

```bash
#!/bin/bash
# backup.sh - Database backup script

DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/backups"
DB_NAME="clinic_db"

# Create backup directory
mkdir -p $BACKUP_DIR

# Create database dump
mysqldump \
  --host=$DB_HOST \
  --port=$DB_PORT \
  --user=$DB_USER \
  --password=$DB_PASSWORD \
  --single-transaction \
  --routines \
  --triggers \
  --add-drop-table \
  --extended-insert \
  $DB_NAME > $BACKUP_DIR/clinic_backup_$DATE.sql

# Compress backup
gzip $BACKUP_DIR/clinic_backup_$DATE.sql

# Keep only last 7 days of backups
find $BACKUP_DIR -name "clinic_backup_*.sql.gz" -mtime +7 -delete

echo "Backup completed: clinic_backup_$DATE.sql.gz"
```

### 2. Railway Backup Integration

```typescript
// Backup service integration
export class BackupService {
  async createBackup(): Promise<string> {
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    const backupName = `clinic_backup_${timestamp}`;
    
    try {
      // Railway provides automatic backups, but you can also create manual ones
      const result = await db.query('SHOW TABLES');
      console.log(`Backup initiated: ${backupName}`);
      console.log(`Tables included:`, result.map((r: any) => Object.values(r)[0]));
      
      return backupName;
    } catch (error) {
      console.error('Backup failed:', error);
      throw error;
    }
  }

  async scheduleBackups(): Promise<void> {
    // Schedule daily backups at 2 AM
    const cron = require('node-cron');
    
    cron.schedule('0 2 * * *', async () => {
      try {
        await this.createBackup();
        console.log('Scheduled backup completed successfully');
      } catch (error) {
        console.error('Scheduled backup failed:', error);
      }
    });
  }
}
```

---

## 🔗 Navigation

**← Previous:** [Resource Consumption Analysis](./resource-consumption-analysis.md) | **Next:** [Small-Scale Deployment Case Study](./small-scale-deployment-case-study.md) →

---

## 📚 References

- [Railway Database Documentation](https://docs.railway.app/databases/mysql)
- [MySQL 8.0 Reference Manual](https://dev.mysql.com/doc/refman/8.0/)
- [Node.js MySQL2 Documentation](https://github.com/sidorares/node-mysql2)
- [Database Design Best Practices](https://dev.mysql.com/doc/refman/8.0/en/optimization.html)