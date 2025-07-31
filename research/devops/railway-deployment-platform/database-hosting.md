# Database Hosting on Railway.com

## 🗄️ Overview

Railway.com provides managed database hosting with zero-configuration setup, automatic backups, and seamless integration with application services. This guide covers database options, configuration, optimization, and best practices for healthcare applications.

## 🚀 Available Database Options

### Supported Database Types

| Database | Use Case | Key Features | Healthcare Suitability |
|----------|----------|--------------|----------------------|
| **PostgreSQL** | General-purpose, complex queries | ACID compliance, JSON support, full-text search | ✅ Excellent |
| **MySQL** | Traditional web applications | Proven reliability, wide support | ✅ Excellent |
| **MongoDB** | Document-based, flexible schema | NoSQL, rapid development | ⚠️ Limited compliance |
| **Redis** | Caching, session storage | In-memory, high performance | ✅ Good for caching |

### Database Selection Guide
```typescript
const databaseSelection = {
  postgresql: {
    bestFor: [
      "Complex relational data models",
      "Advanced querying requirements", 
      "JSON document storage hybrid",
      "High compliance requirements"
    ],
    clinicUsage: [
      "Patient records with complex relationships",
      "Medical history with structured and unstructured data",
      "Reporting and analytics",
      "Audit trails and compliance logging"
    ]
  },
  
  mysql: {
    bestFor: [
      "Traditional web applications",
      "Simple to moderate complexity",
      "Wide ecosystem support",
      "Familiar SQL syntax"
    ],
    clinicUsage: [
      "Basic patient management",
      "Appointment scheduling",
      "Simple billing systems",
      "Legacy system compatibility"
    ]
  }
};
```

## 🏗️ Database Setup and Configuration

### Creating a Database Service

#### Using Railway Dashboard
```bash
# 1. Navigate to Railway dashboard
# 2. Select your project
# 3. Click "Add Service"
# 4. Choose database type (MySQL/PostgreSQL/MongoDB/Redis)
# 5. Railway automatically provisions and configures
```

#### Using Railway CLI
```bash
# Install Railway CLI
npm install -g @railway/cli

# Login and select project
railway login
railway link

# Add database service
railway add mysql
# OR
railway add postgresql
# OR  
railway add mongodb
# OR
railway add redis

# View connection details
railway variables
```

### Database Configuration
```typescript
// Automatic environment variables provided by Railway
const databaseConfig = {
  mysql: {
    host: process.env.MYSQLHOST,
    port: process.env.MYSQLPORT,
    user: process.env.MYSQLUSER,
    password: process.env.MYSQLPASSWORD,
    database: process.env.MYSQLDATABASE,
    url: process.env.DATABASE_URL // Complete connection string
  },
  
  postgresql: {
    host: process.env.PGHOST,
    port: process.env.PGPORT,
    user: process.env.PGUSER,
    password: process.env.PGPASSWORD,
    database: process.env.PGDATABASE,
    url: process.env.DATABASE_URL
  }
};
```

## 🔧 Database Integration Examples

### MySQL with TypeORM (Clinic Application)
```typescript
// apps/api/src/config/database.ts
import { DataSource } from 'typeorm';
import { Patient } from '../entities/Patient';
import { Appointment } from '../entities/Appointment';
import { User } from '../entities/User';

export const AppDataSource = new DataSource({
  type: 'mysql',
  url: process.env.DATABASE_URL,
  
  // Production settings
  synchronize: false, // Never true in production
  migrationsRun: true,
  logging: process.env.NODE_ENV === 'development',
  
  // Entity configuration
  entities: [Patient, Appointment, User],
  migrations: ['dist/migrations/*.js'],
  subscribers: ['dist/subscribers/*.js'],
  
  // Connection pooling
  extra: {
    connectionLimit: 10,
    acquireTimeout: 60000,
    timeout: 60000,
    reconnect: true
  },
  
  // SSL configuration (Railway provides this automatically)
  ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false
});

// Initialize connection
export const initializeDatabase = async (): Promise<void> => {
  try {
    await AppDataSource.initialize();
    console.log('Database connection established');
  } catch (error) {
    console.error('Database connection failed:', error);
    throw error;
  }
};
```

### Database Entities for Clinic Management
```typescript
// apps/api/src/entities/Patient.ts
import { Entity, PrimaryGeneratedColumn, Column, OneToMany, CreateDateColumn, UpdateDateColumn } from 'typeorm';
import { Appointment } from './Appointment';
import { MedicalRecord } from './MedicalRecord';

@Entity('patients')
export class Patient {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ length: 100 })
  firstName: string;

  @Column({ length: 100 })
  lastName: string;

  @Column({ type: 'date' })
  dateOfBirth: Date;

  @Column({ length: 20, nullable: true })
  phone: string;

  @Column({ length: 100, nullable: true })
  email: string;

  @Column({ type: 'text', nullable: true })
  address: string;

  // Encrypted sensitive data
  @Column({ type: 'text', nullable: true })
  encryptedSSN: string;

  @Column({ type: 'json', nullable: true })
  insuranceInfo: any;

  @Column({ type: 'json', nullable: true })
  emergencyContact: any;

  @OneToMany(() => Appointment, appointment => appointment.patient)
  appointments: Appointment[];

  @OneToMany(() => MedicalRecord, record => record.patient)
  medicalRecords: MedicalRecord[];

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}

// apps/api/src/entities/Appointment.ts
@Entity('appointments')
export class Appointment {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @ManyToOne(() => Patient, patient => patient.appointments)
  patient: Patient;

  @Column('uuid')
  patientId: string;

  @Column({ length: 100 })
  providerName: string;

  @Column({ type: 'datetime' })
  scheduledAt: Date;

  @Column({ type: 'int', default: 30 })
  durationMinutes: number;

  @Column({ 
    type: 'enum', 
    enum: ['scheduled', 'confirmed', 'in-progress', 'completed', 'cancelled'],
    default: 'scheduled'
  })
  status: string;

  @Column({ type: 'text', nullable: true })
  notes: string;

  @Column({ type: 'text', nullable: true })
  reasonForVisit: string;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
```

### Database Migrations
```typescript
// Database migration example
import { MigrationInterface, QueryRunner, Table, Index } from 'typeorm';

export class CreatePatientsTable1640995200000 implements MigrationInterface {
  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.createTable(
      new Table({
        name: 'patients',
        columns: [
          {
            name: 'id',
            type: 'varchar',
            length: '36',
            isPrimary: true,
            generationStrategy: 'uuid'
          },
          {
            name: 'firstName',
            type: 'varchar',
            length: '100'
          },
          {
            name: 'lastName', 
            type: 'varchar',
            length: '100'
          },
          {
            name: 'dateOfBirth',
            type: 'date'
          },
          {
            name: 'phone',
            type: 'varchar',
            length: '20',
            isNullable: true
          },
          {
            name: 'email',
            type: 'varchar', 
            length: '100',
            isNullable: true
          },
          {
            name: 'createdAt',
            type: 'timestamp',
            default: 'CURRENT_TIMESTAMP'
          },
          {
            name: 'updatedAt',
            type: 'timestamp',
            default: 'CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP'
          }
        ]
      })
    );

    // Create indexes for better query performance
    await queryRunner.createIndex('patients', new Index('IDX_PATIENT_NAME', ['firstName', 'lastName']));
    await queryRunner.createIndex('patients', new Index('IDX_PATIENT_DOB', ['dateOfBirth']));
    await queryRunner.createIndex('patients', new Index('IDX_PATIENT_EMAIL', ['email']));
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.dropTable('patients');
  }
}
```

## 📊 Storage and Performance

### Storage Scaling
```typescript
const storageScaling = {
  automatic: {
    description: "Railway automatically scales storage based on usage",
    billing: "Pay only for actual storage consumed",
    limits: "No arbitrary storage limits"
  },
  
  clinicGrowthProjection: {
    initial: "1-2 GB (patient records, appointments)",
    year1: "3-4 GB (50% patient growth + historical data)",
    year2: "6-8 GB (100% growth + medical images)",
    year3: "12-15 GB (expanded services + compliance archival)"
  },
  
  costProjection: {
    storageRate: "$0.25 per GB per month",
    year1Cost: "$1-2/month storage", 
    year2Cost: "$2-3/month storage",
    year3Cost: "$3-4/month storage"
  }
};
```

### Performance Optimization
```typescript
// Database performance optimization strategies
export class DatabaseOptimization {
  // Connection pooling configuration
  static getPoolConfig() {
    return {
      min: 2, // Minimum connections
      max: 10, // Maximum for small clinic
      idle: 10000, // 10 seconds idle timeout
      acquire: 30000, // 30 seconds acquire timeout
      evict: 1000 // Eviction interval
    };
  }

  // Query optimization
  static async optimizeQueries() {
    // Use indexes for frequently queried fields
    const indexedQueries = {
      patientSearch: "CREATE INDEX idx_patient_search ON patients(firstName, lastName, dateOfBirth)",
      appointmentDate: "CREATE INDEX idx_appointment_date ON appointments(scheduledAt)",
      patientAppointments: "CREATE INDEX idx_patient_appointments ON appointments(patientId, scheduledAt)"
    };
    
    return indexedQueries;
  }

  // Caching strategy  
  static implementCaching() {
    return {
      patientList: "Cache for 5 minutes (frequently updated)",
      scheduleData: "Cache for 1 minute (real-time booking)",
      staticData: "Cache for 1 hour (clinic info, providers)",
      reports: "Cache for 15 minutes (analytical queries)"
    };
  }
}
```

## 🔒 Database Security for Healthcare

### Encryption and Compliance
```typescript
// Field-level encryption for sensitive healthcare data
import crypto from 'crypto';

export class HealthcareDataEncryption {
  private readonly algorithm = 'aes-256-gcm';
  private readonly key = Buffer.from(process.env.ENCRYPTION_KEY!, 'base64');

  // Encrypt PHI (Protected Health Information)
  encryptPHI(data: string): string {
    const iv = crypto.randomBytes(16);
    const cipher = crypto.createCipher(this.algorithm, this.key);
    
    let encrypted = cipher.update(data, 'utf8', 'hex');
    encrypted += cipher.final('hex');
    
    const authTag = cipher.getAuthTag();
    return `${iv.toString('hex')}:${authTag.toString('hex')}:${encrypted}`;
  }

  // Decrypt PHI
  decryptPHI(encryptedData: string): string {
    const [ivHex, authTagHex, encrypted] = encryptedData.split(':');
    const iv = Buffer.from(ivHex, 'hex');
    const authTag = Buffer.from(authTagHex, 'hex');
    
    const decipher = crypto.createDecipher(this.algorithm, this.key);
    decipher.setAuthTag(authTag);
    
    let decrypted = decipher.update(encrypted, 'hex', 'utf8');
    decrypted += decipher.final('utf8');
    return decrypted;
  }
}

// Database audit logging
export class DatabaseAuditLogger {
  async logDataAccess(userId: string, action: string, table: string, recordId?: string): Promise<void> {
    const auditEntry = {
      timestamp: new Date().toISOString(),
      userId,
      action, // 'CREATE', 'READ', 'UPDATE', 'DELETE'
      table,
      recordId,
      ipAddress: this.getClientIP(),
      userAgent: this.getUserAgent()
    };
    
    // Store in separate audit table
    await this.storeAuditEntry(auditEntry);
  }
  
  private async storeAuditEntry(entry: any): Promise<void> {
    // Implementation depends on audit requirements
    // Can be separate database, external logging service, etc.
    console.log('AUDIT:', JSON.stringify(entry));
  }
}
```

### Database Access Control
```typescript
// Role-based database access
export enum UserRole {
  ADMIN = 'admin',
  DOCTOR = 'doctor', 
  NURSE = 'nurse',
  RECEPTIONIST = 'receptionist'
}

export class DatabaseAccessControl {
  // Define access permissions by role
  static getPermissions(role: UserRole): Record<string, string[]> {
    const permissions = {
      [UserRole.ADMIN]: ['patients:*', 'appointments:*', 'users:*', 'reports:*'],
      [UserRole.DOCTOR]: ['patients:read,update', 'appointments:*', 'medical-records:*'],
      [UserRole.NURSE]: ['patients:read,update', 'appointments:read,update', 'medical-records:read'],
      [UserRole.RECEPTIONIST]: ['patients:read,create', 'appointments:*', 'billing:*']
    };
    
    return permissions[role] || [];
  }

  // Validate access before database operations
  static validateAccess(userRole: UserRole, resource: string, action: string): boolean {
    const permissions = this.getPermissions(userRole);
    const resourcePermission = permissions.find(p => p.startsWith(resource + ':'));
    
    if (!resourcePermission) return false;
    
    const allowedActions = resourcePermission.split(':')[1];
    return allowedActions === '*' || allowedActions.split(',').includes(action);
  }
}
```

## 💾 Backup and Recovery

### Automatic Backup Configuration
```typescript
const backupStrategy = {
  railway: {
    automatic: "Daily backups included with managed databases",
    retention: "7 days for Developer, 30 days for Pro/Team plans",
    restoration: "Point-in-time recovery available",
    storage: "Encrypted backups in secure cloud storage"
  },
  
  additionalBackups: {
    weekly: "Export full database to external storage",
    monthly: "Archive compliance data",
    beforeUpdates: "Manual backup before schema changes",
    disaster: "Cross-region backup for critical healthcare data"
  }
};

// Custom backup implementation
export class DatabaseBackupService {
  async createManualBackup(description: string): Promise<string> {
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    const backupId = `manual-backup-${timestamp}`;
    
    try {
      // For MySQL
      const command = `mysqldump --host=${process.env.MYSQLHOST} --user=${process.env.MYSQLUSER} --password=${process.env.MYSQLPASSWORD} ${process.env.MYSQLDATABASE}`;
      
      // Execute backup (implementation depends on environment)
      // Store backup file in secure external storage
      
      return backupId;
    } catch (error) {
      console.error('Backup failed:', error);
      throw new Error(`Backup creation failed: ${error.message}`);
    }
  }

  async restoreFromBackup(backupId: string): Promise<void> {
    // Implementation for restore process
    // Should include verification and rollback capabilities
  }
}
```

## 📈 Monitoring and Analytics

### Database Performance Monitoring
```typescript
export class DatabaseMonitoring {
  // Track query performance
  async monitorQueries(): Promise<void> {
    const slowQueries = await this.getSlowQueries();
    const connectionCount = await this.getConnectionCount();
    const diskUsage = await this.getDiskUsage();
    
    // Alert if performance thresholds exceeded
    if (slowQueries.length > 10) {
      await this.alertSlowQueries(slowQueries);
    }
    
    if (connectionCount > 8) {
      await this.alertHighConnections(connectionCount);
    }
  }

  // Database health checks
  async healthCheck(): Promise<DatabaseHealth> {
    try {
      const start = Date.now();
      await AppDataSource.query('SELECT 1');
      const responseTime = Date.now() - start;
      
      return {
        status: 'healthy',
        responseTime,
        connections: await this.getConnectionCount(),
        storageUsed: await this.getStorageUsage(),
        lastBackup: await this.getLastBackupTime()
      };
    } catch (error) {
      return {
        status: 'unhealthy',
        error: error.message
      };
    }
  }
}

interface DatabaseHealth {
  status: 'healthy' | 'unhealthy';
  responseTime?: number;
  connections?: number;
  storageUsed?: number;
  lastBackup?: Date;
  error?: string;
}
```

## 🎯 Cost Optimization for Clinic Databases

### Storage Cost Management
```typescript
const costOptimization = {
  // Archive old data to reduce active storage
  dataArchival: {
    schedule: "Monthly archival of records older than 2 years",
    method: "Move to separate archive tables or external storage",
    savings: "30-50% storage cost reduction"
  },
  
  // Optimize data types and indexes
  schemaOptimization: {
    dataTypes: "Use appropriate field sizes (VARCHAR vs TEXT)",
    indexes: "Remove unused indexes, optimize frequently queried fields",
    normalization: "Proper database normalization to reduce redundancy"
  },
  
  // Query optimization
  queryOptimization: {
    caching: "Implement Redis caching for frequent queries",
    pagination: "Limit large result sets with proper pagination",
    joins: "Optimize complex queries and joins"
  }
};
```

### Projected Database Costs
```typescript
const databaseCostProjection = {
  // Small clinic (200-500 patients)
  small: {
    storage: "1-2 GB",
    monthlyCost: "$1-3",
    connections: "2-5 concurrent",
    iops: "Low (< 1000/day)"
  },
  
  // Medium clinic (500-1000 patients)  
  medium: {
    storage: "3-5 GB",
    monthlyCost: "$2-5",
    connections: "5-10 concurrent", 
    iops: "Medium (1000-5000/day)"
  },
  
  // Large clinic (1000+ patients)
  large: {
    storage: "5-10 GB",
    monthlyCost: "$4-8",
    connections: "10-15 concurrent",
    iops: "High (5000+/day)"
  }
};
```

## 📋 Database Checklist

### Setup Checklist
- [ ] Database service created in Railway
- [ ] Connection environment variables configured
- [ ] Database entities defined with proper relationships
- [ ] Migrations created and tested
- [ ] Indexes created for frequently queried fields
- [ ] Connection pooling configured

### Security Checklist
- [ ] Field-level encryption for sensitive data (SSN, insurance)
- [ ] Audit logging implementation for data access
- [ ] Role-based access control implemented
- [ ] Database connections use SSL/TLS
- [ ] Regular security updates applied

### Performance Checklist
- [ ] Query performance monitoring implemented
- [ ] Slow query identification and optimization
- [ ] Caching strategy for frequent queries
- [ ] Database health checks configured
- [ ] Connection pooling optimized for usage patterns

### Backup & Recovery Checklist
- [ ] Automatic daily backups verified
- [ ] Manual backup procedures documented
- [ ] Recovery testing performed
- [ ] Cross-region backup for critical data
- [ ] Backup retention policy defined

### Compliance Checklist (Healthcare)
- [ ] HIPAA technical safeguards implemented
- [ ] Data encryption at rest and in transit
- [ ] Audit trails for all data access
- [ ] Data retention policies defined
- [ ] Business Associate Agreement with Railway

---

## 🔗 Navigation

- **Previous**: [Pricing Analysis](./pricing-analysis.md)
- **Next**: [Resource Management](./resource-management.md)