# Best Practices for Railway.com Deployments

## Overview

This guide outlines production-ready best practices for deploying and managing applications on Railway.com, covering security, performance, cost optimization, and operational excellence.

## Project Organization and Structure

### 1. Service Architecture Best Practices

**Microservices Design**:
```
Project: clinic-management
├── web (Frontend Service)
├── api (Backend Service)
├── mysql (Database Service)
├── worker (Background Jobs)
└── redis (Cache Service)
```

**Service Naming Conventions**:
- Use descriptive, lowercase names
- Include environment prefixes for clarity
- Follow consistent naming patterns

```bash
# Good naming
clinic-web-prod
clinic-api-prod
clinic-db-prod

# Avoid
service1
app
db
```

### 2. Environment Management

**Multi-Environment Strategy**:
```bash
# Production environment
railway environment create production

# Staging environment  
railway environment create staging

# Development environment
railway environment create development
```

**Environment Variable Hierarchy**:
```toml
# railway.toml
[environments.staging]
variables = { NODE_ENV = "staging", DEBUG = "true" }

[environments.production]
variables = { NODE_ENV = "production", DEBUG = "false" }
```

## Security Best Practices

### 1. Environment Variables and Secrets

**Secure Secret Management**:
```bash
# Use Railway's secret management
railway variables set --sensitive DATABASE_PASSWORD=$(openssl rand -base64 32)
railway variables set --sensitive JWT_SECRET=$(openssl rand -base64 64)
railway variables set --sensitive API_KEY=your-secret-key

# Never commit secrets to git
echo "*.env*" >> .gitignore
echo "secrets/" >> .gitignore
```

**Environment Variable Organization**:
```bash
# Database configuration
DATABASE_URL=mysql://user:pass@host:port/db
MYSQL_HOST=${{MYSQL_HOST}}
MYSQL_PORT=${{MYSQL_PORT}}
MYSQL_USER=${{MYSQL_USER}}
MYSQL_PASSWORD=${{MYSQL_PASSWORD}}

# Application secrets
JWT_SECRET=${{JWT_SECRET}}
SESSION_SECRET=${{SESSION_SECRET}}
ENCRYPTION_KEY=${{ENCRYPTION_KEY}}

# External service keys
STRIPE_SECRET_KEY=${{STRIPE_SECRET_KEY}}
SENDGRID_API_KEY=${{SENDGRID_API_KEY}}
```

### 2. Network Security

**CORS Configuration**:
```typescript
// Secure CORS setup
import cors from 'cors';

const corsOptions = {
  origin: [
    process.env.FRONTEND_URL,
    'https://clinic.yourdomain.com'
  ],
  credentials: true,
  optionsSuccessStatus: 200,
  methods: ['GET', 'POST', 'PUT', 'DELETE'],
  allowedHeaders: ['Content-Type', 'Authorization']
};

app.use(cors(corsOptions));
```

**Request Validation**:
```typescript
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';

// Security headers
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      scriptSrc: ["'self'"],
      imgSrc: ["'self'", "data:", "https:"]
    }
  }
}));

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // limit each IP to 100 requests per windowMs
  message: 'Too many requests from this IP'
});

app.use('/api/', limiter);
```

### 3. Database Security

**Secure Database Connections**:
```typescript
const dbConfig = {
  host: process.env.MYSQL_HOST,
  port: parseInt(process.env.MYSQL_PORT || '3306'),
  user: process.env.MYSQL_USER,
  password: process.env.MYSQL_PASSWORD,
  database: process.env.MYSQL_DATABASE,
  ssl: {
    rejectUnauthorized: process.env.NODE_ENV === 'production',
    ca: process.env.MYSQL_SSL_CA
  },
  connectionLimit: 10,
  acquireTimeout: 60000,
  timeout: 60000
};
```

**SQL Injection Prevention**:
```typescript
// Always use parameterized queries
export class PatientService {
  async getPatientById(id: number) {
    // SECURE: Parameterized query
    const query = 'SELECT * FROM patients WHERE id = ?';
    return await db.query(query, [id]);
  }
  
  async searchPatients(searchTerm: string) {
    // SECURE: Parameterized with LIKE
    const query = `
      SELECT * FROM patients 
      WHERE first_name LIKE ? OR last_name LIKE ?
      ORDER BY last_name, first_name
      LIMIT 50
    `;
    const pattern = `%${searchTerm}%`;
    return await db.query(query, [pattern, pattern]);
  }
}
```

## Performance Optimization

### 1. Application Performance

**Database Query Optimization**:
```typescript
// Efficient pagination
export async function getPatients(page = 1, limit = 20) {
  const offset = (page - 1) * limit;
  
  const [countResult, patients] = await Promise.all([
    db.query('SELECT COUNT(*) as total FROM patients'),
    db.query(`
      SELECT id, patient_id, first_name, last_name, phone 
      FROM patients 
      ORDER BY last_name, first_name 
      LIMIT ? OFFSET ?
    `, [limit, offset])
  ]);
  
  return {
    patients,
    total: countResult[0].total,
    page,
    limit,
    totalPages: Math.ceil(countResult[0].total / limit)
  };
}

// Efficient joins
export async function getPatientsWithAppointments() {
  const query = `
    SELECT 
      p.id, p.first_name, p.last_name,
      COUNT(a.id) as appointment_count,
      MAX(a.appointment_date) as last_appointment
    FROM patients p
    LEFT JOIN appointments a ON p.id = a.patient_id
    GROUP BY p.id, p.first_name, p.last_name
    ORDER BY p.last_name, p.first_name
  `;
  
  return await db.query(query);
}
```

**Connection Pooling**:
```typescript
class DatabasePool {
  private pool: mysql.Pool;
  
  constructor() {
    this.pool = mysql.createPool({
      host: process.env.MYSQL_HOST,
      user: process.env.MYSQL_USER,
      password: process.env.MYSQL_PASSWORD,
      database: process.env.MYSQL_DATABASE,
      connectionLimit: 10,
      acquireTimeout: 60000,
      timeout: 60000,
      reconnect: true,
      idleTimeout: 300000
    });
  }
  
  async getConnection() {
    return await this.pool.getConnection();
  }
  
  async query(sql: string, params?: any[]) {
    const connection = await this.getConnection();
    try {
      const [rows] = await connection.execute(sql, params);
      return rows;
    } finally {
      connection.release();
    }
  }
}
```

### 2. Frontend Performance

**React Optimization**:
```typescript
import React, { memo, useMemo, useCallback } from 'react';

// Memoized components
const PatientCard = memo(({ patient }: { patient: Patient }) => {
  return (
    <div className="patient-card">
      <h3>{patient.first_name} {patient.last_name}</h3>
      <p>{patient.phone}</p>
    </div>
  );
});

// Optimized patient list
const PatientList = ({ patients }: { patients: Patient[] }) => {
  const sortedPatients = useMemo(
    () => patients.sort((a, b) => a.last_name.localeCompare(b.last_name)),
    [patients]
  );
  
  const handlePatientClick = useCallback((patientId: number) => {
    // Handle patient selection
  }, []);
  
  return (
    <div className="patient-list">
      {sortedPatients.map(patient => (
        <PatientCard 
          key={patient.id} 
          patient={patient}
          onClick={() => handlePatientClick(patient.id)}
        />
      ))}
    </div>
  );
};
```

**Vite Build Optimization**:
```typescript
// vite.config.ts
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  build: {
    rollupOptions: {
      output: {
        manualChunks: {
          vendor: ['react', 'react-dom'],
          utils: ['date-fns', 'lodash']
        }
      }
    },
    minify: 'terser',
    terserOptions: {
      compress: {
        drop_console: true,
        drop_debugger: true
      }
    }
  }
});
```

### 3. Caching Strategies

**Application-Level Caching**:
```typescript
import NodeCache from 'node-cache';

// Cache for 5 minutes
const cache = new NodeCache({ stdTTL: 300 });

export class CachedPatientService {
  async getPatients(page = 1, limit = 20) {
    const cacheKey = `patients:${page}:${limit}`;
    
    // Check cache first
    const cached = cache.get(cacheKey);
    if (cached) {
      return cached;
    }
    
    // Fetch from database
    const result = await getPatients(page, limit);
    
    // Cache the result
    cache.set(cacheKey, result);
    
    return result;
  }
  
  // Invalidate cache when data changes
  async createPatient(patientData: any) {
    const result = await createPatient(patientData);
    
    // Clear relevant cache entries
    cache.flushAll(); // Or be more specific
    
    return result;
  }
}
```

## Monitoring and Observability

### 1. Health Checks

**Comprehensive Health Endpoint**:
```typescript
export class HealthService {
  static async checkHealth() {
    const startTime = Date.now();
    
    try {
      // Database health check
      const dbStart = Date.now();
      await db.query('SELECT 1');
      const dbResponseTime = Date.now() - dbStart;
      
      // Memory usage
      const memoryUsage = process.memoryUsage();
      
      // System info
      const systemInfo = {
        uptime: process.uptime(),
        nodeVersion: process.version,
        platform: process.platform,
        environment: process.env.NODE_ENV
      };
      
      return {
        status: 'healthy',
        timestamp: new Date().toISOString(),
        responseTime: Date.now() - startTime,
        database: {
          status: 'connected',
          responseTime: dbResponseTime
        },
        memory: {
          rss: Math.round(memoryUsage.rss / 1024 / 1024) + ' MB',
          heapUsed: Math.round(memoryUsage.heapUsed / 1024 / 1024) + ' MB',
          heapTotal: Math.round(memoryUsage.heapTotal / 1024 / 1024) + ' MB'
        },
        system: systemInfo
      };
      
    } catch (error) {
      return {
        status: 'unhealthy',
        timestamp: new Date().toISOString(),
        error: error.message,
        responseTime: Date.now() - startTime
      };
    }
  }
}
```

### 2. Logging Strategy

**Structured Logging**:
```typescript
import winston from 'winston';

const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  defaultMeta: { 
    service: 'clinic-api',
    environment: process.env.NODE_ENV 
  },
  transports: [
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.colorize(),
        winston.format.simple()
      )
    })
  ]
});

// Request logging middleware
export const requestLogger = (req: any, res: any, next: any) => {
  const start = Date.now();
  
  res.on('finish', () => {
    const duration = Date.now() - start;
    
    logger.info('HTTP Request', {
      method: req.method,
      url: req.url,
      statusCode: res.statusCode,
      duration,
      userAgent: req.get('User-Agent'),
      ip: req.ip
    });
    
    // Log slow requests
    if (duration > 1000) {
      logger.warn('Slow Request Detected', {
        method: req.method,
        url: req.url,
        duration
      });
    }
  });
  
  next();
};
```

### 3. Error Handling

**Global Error Handler**:
```typescript
import { logger } from './logger';

export const errorHandler = (error: any, req: any, res: any, next: any) => {
  logger.error('Unhandled Error', {
    error: error.message,
    stack: error.stack,
    url: req.url,
    method: req.method,
    body: req.body,
    params: req.params,
    query: req.query
  });
  
  // Don't expose internal errors in production
  if (process.env.NODE_ENV === 'production') {
    res.status(500).json({
      error: 'Internal server error',
      timestamp: new Date().toISOString(),
      requestId: req.id
    });
  } else {
    res.status(500).json({
      error: error.message,
      stack: error.stack,
      timestamp: new Date().toISOString()
    });
  }
};

// Async error wrapper
export const asyncHandler = (fn: any) => (req: any, res: any, next: any) => {
  Promise.resolve(fn(req, res, next)).catch(next);
};

// Usage
app.get('/api/patients/:id', asyncHandler(async (req, res) => {
  const patient = await getPatientById(req.params.id);
  res.json(patient);
}));
```

## Cost Optimization

### 1. Resource Right-Sizing

**Monitor Resource Usage**:
```bash
# Check current resource usage
railway metrics --service api

# Analyze usage patterns
railway logs --service api | grep -E "(memory|cpu)"

# Optimize based on actual usage
railway variables set CPU_LIMIT=0.5
railway variables set MEMORY_LIMIT=512
```

**Efficient Resource Allocation**:
```typescript
// Connection pool optimization for small applications
const poolConfig = {
  connectionLimit: process.env.NODE_ENV === 'production' ? 5 : 2,
  acquireTimeout: 30000,
  timeout: 30000,
  idleTimeout: 300000
};

// Memory-efficient data processing
export async function processLargePatientsDataset() {
  const batchSize = 100;
  let offset = 0;
  
  while (true) {
    const batch = await db.query(
      'SELECT * FROM patients LIMIT ? OFFSET ?', 
      [batchSize, offset]
    );
    
    if (batch.length === 0) break;
    
    // Process batch
    await processBatch(batch);
    
    offset += batchSize;
    
    // Allow garbage collection
    if (global.gc) global.gc();
  }
}
```

### 2. Database Optimization

**Query Performance**:
```sql
-- Create efficient indexes
CREATE INDEX idx_patients_name ON patients(last_name, first_name);
CREATE INDEX idx_appointments_date_patient ON appointments(appointment_date, patient_id);
CREATE INDEX idx_patients_search ON patients(patient_id, phone, email);

-- Optimize frequently used queries
EXPLAIN SELECT * FROM patients WHERE last_name LIKE 'Smith%';

-- Archive old data to reduce storage costs
CREATE TABLE patients_archive AS 
SELECT * FROM patients WHERE created_at < DATE_SUB(CURRENT_DATE, INTERVAL 2 YEAR);

DELETE FROM patients WHERE created_at < DATE_SUB(CURRENT_DATE, INTERVAL 2 YEAR);
```

**Storage Management**:
```typescript
// Database cleanup script
export class DatabaseMaintenance {
  static async cleanupOldData() {
    const cutoffDate = new Date();
    cutoffDate.setFullYear(cutoffDate.getFullYear() - 2);
    
    // Archive old appointments
    await db.query(`
      INSERT INTO appointments_archive 
      SELECT * FROM appointments 
      WHERE appointment_date < ?
    `, [cutoffDate]);
    
    await db.query(`
      DELETE FROM appointments 
      WHERE appointment_date < ?
    `, [cutoffDate]);
    
    logger.info('Database cleanup completed', { cutoffDate });
  }
  
  static async optimizeTables() {
    const tables = ['patients', 'appointments', 'medical_records'];
    
    for (const table of tables) {
      await db.query(`OPTIMIZE TABLE ${table}`);
      logger.info(`Optimized table: ${table}`);
    }
  }
}
```

## Deployment Best Practices

### 1. CI/CD Pipeline

**GitHub Actions Integration**:
```yaml
# .github/workflows/deploy.yml
name: Deploy to Railway

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'
          cache: 'npm'
      
      - name: Install dependencies
        run: npm ci
      
      - name: Run tests
        run: npm test
      
      - name: Build applications
        run: |
          npx nx build web --prod
          npx nx build api --prod

  deploy:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v3
      
      - name: Install Railway CLI
        run: npm install -g @railway/cli
      
      - name: Deploy to Railway
        run: railway up --detach
        env:
          RAILWAY_TOKEN: ${{ secrets.RAILWAY_TOKEN }}
```

### 2. Environment Configuration

**Staging Environment**:
```bash
# Create staging environment
railway environment create staging

# Set staging-specific variables
railway environment select staging
railway variables set NODE_ENV=staging
railway variables set DEBUG=true
railway variables set LOG_LEVEL=debug
```

**Production Environment**:
```bash
# Production environment setup
railway environment select production
railway variables set NODE_ENV=production
railway variables set DEBUG=false
railway variables set LOG_LEVEL=error
```

### 3. Database Migrations

**Migration Strategy**:
```typescript
// migrations/001_initial_schema.ts
export const migration_001 = {
  up: async () => {
    await db.query(`
      CREATE TABLE IF NOT EXISTS patients (
        id INT AUTO_INCREMENT PRIMARY KEY,
        patient_id VARCHAR(20) UNIQUE NOT NULL,
        first_name VARCHAR(100) NOT NULL,
        last_name VARCHAR(100) NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);
  },
  
  down: async () => {
    await db.query('DROP TABLE IF EXISTS patients');
  }
};

// Migration runner
export class MigrationRunner {
  static async runMigrations() {
    // Create migrations table
    await db.query(`
      CREATE TABLE IF NOT EXISTS migrations (
        id INT AUTO_INCREMENT PRIMARY KEY,
        migration_name VARCHAR(255) UNIQUE NOT NULL,
        executed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);
    
    // Get executed migrations
    const executed = await db.query('SELECT migration_name FROM migrations');
    const executedNames = executed.map((m: any) => m.migration_name);
    
    // Run pending migrations
    const migrations = [migration_001]; // Add more migrations here
    
    for (const migration of migrations) {
      const migrationName = migration.constructor.name;
      
      if (!executedNames.includes(migrationName)) {
        await migration.up();
        await db.query(
          'INSERT INTO migrations (migration_name) VALUES (?)', 
          [migrationName]
        );
        console.log(`Migration completed: ${migrationName}`);
      }
    }
  }
}
```

## Backup and Recovery

### 1. Automated Backups

**Backup Script**:
```typescript
import { exec } from 'child_process';
import { promisify } from 'util';

const execAsync = promisify(exec);

export class BackupService {
  static async createBackup() {
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    const backupFileName = `clinic_backup_${timestamp}.sql`;
    
    try {
      // Create database dump
      const command = `mysqldump -h ${process.env.MYSQL_HOST} -u ${process.env.MYSQL_USER} -p${process.env.MYSQL_PASSWORD} ${process.env.MYSQL_DATABASE}`;
      
      const { stdout } = await execAsync(command);
      
      // Save backup to cloud storage (implement based on your needs)
      await this.uploadToCloudStorage(backupFileName, stdout);
      
      logger.info('Backup completed successfully', { fileName: backupFileName });
      
      return { success: true, fileName: backupFileName };
    } catch (error) {
      logger.error('Backup failed', { error: error.message });
      throw error;
    }
  }
  
  static async uploadToCloudStorage(fileName: string, data: string) {
    // Implement cloud storage upload
    // Example: AWS S3, Google Cloud Storage, etc.
  }
  
  static async scheduleBackups() {
    // Schedule daily backups
    setInterval(async () => {
      await this.createBackup();
    }, 24 * 60 * 60 * 1000); // 24 hours
  }
}
```

### 2. Recovery Procedures

**Recovery Plan**:
```typescript
export class RecoveryService {
  static async restoreFromBackup(backupFileName: string) {
    try {
      // Download backup from cloud storage
      const backupData = await this.downloadFromCloudStorage(backupFileName);
      
      // Restore database
      const command = `mysql -h ${process.env.MYSQL_HOST} -u ${process.env.MYSQL_USER} -p${process.env.MYSQL_PASSWORD} ${process.env.MYSQL_DATABASE}`;
      
      await execAsync(`echo "${backupData}" | ${command}`);
      
      logger.info('Database restored successfully', { backupFileName });
      
      return { success: true };
    } catch (error) {
      logger.error('Database restore failed', { error: error.message });
      throw error;
    }
  }
  
  static async downloadFromCloudStorage(fileName: string) {
    // Implement cloud storage download
  }
}
```

## Team Collaboration

### 1. Access Control

**Team Management**:
```bash
# Add team members
railway team add user@email.com --role developer
railway team add admin@email.com --role admin

# Set up role-based access
railway project permissions set --user user@email.com --role developer
```

### 2. Environment Isolation

**Branch-Based Deployments**:
```bash
# Create feature environment
railway environment create feature-patient-search
railway environment select feature-patient-search

# Deploy feature branch
git checkout feature/patient-search
railway up --detach
```

---

## Summary Checklist

### Security
- [ ] Environment variables encrypted
- [ ] CORS properly configured
- [ ] Rate limiting implemented
- [ ] SQL injection protection
- [ ] HTTPS enforced

### Performance  
- [ ] Database queries optimized
- [ ] Connection pooling configured
- [ ] Caching strategy implemented
- [ ] Frontend build optimized
- [ ] Resource usage monitored

### Monitoring
- [ ] Health checks implemented
- [ ] Structured logging setup
- [ ] Error handling configured
- [ ] Metrics collection enabled
- [ ] Alerts configured

### Operations
- [ ] Backup strategy implemented
- [ ] Recovery procedures documented
- [ ] CI/CD pipeline setup
- [ ] Migration strategy defined
- [ ] Team access configured

---

## Next Steps

1. **[Review Implementation Guide](./implementation-guide.md)** - Complete deployment setup
2. **[Analyze Costs](./small-scale-cost-analysis.md)** - Optimize resource usage
3. **[Check Troubleshooting](./troubleshooting.md)** - Common issues and solutions

---

*Best Practices Guide | Railway.com Deployments | January 2025*