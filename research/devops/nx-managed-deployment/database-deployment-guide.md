# Database Deployment Guide: MySQL Hosting for Nx Applications

## 🎯 Overview

This guide covers MySQL deployment options for full-stack Nx applications, focusing on managed database services that integrate seamlessly with app deployment platforms while maintaining cost-effectiveness.

## 🗄 Database Architecture Options

### Option 1: Platform-Native Databases
```
App Platform + Integrated Database
├── Railway → Railway MySQL Plugin
├── Render → Render PostgreSQL 
├── Digital Ocean → DO Managed MySQL
└── Shared networking and billing
```

### Option 2: External Managed Databases
```
App Platform + External Database
├── PlanetScale (MySQL-compatible)
├── AWS RDS MySQL
├── Google Cloud SQL
└── Separate billing and management
```

### Option 3: Hybrid Approach
```
Multi-Platform Architecture
├── Frontend → Vercel/Netlify
├── Backend → Railway/Render
└── Database → PlanetScale/Supabase
```

## 🚂 Railway MySQL Plugin (Most Cost-Effective)

### ✅ Advantages
- **Integrated billing**: Single platform management
- **Automatic configuration**: Environment variables auto-injected
- **Lowest cost**: $5/month for 512MB RAM, 1GB storage
- **Zero-config networking**: Backend connects automatically
- **Built-in backups**: Daily automated backups included

### 📊 Pricing Tiers
```
Shared ($5/month):
- 512MB RAM, 1GB storage
- Shared CPU
- Daily backups
- Connection pooling

Dedicated ($15/month):
- 1GB RAM, 8GB storage  
- Dedicated CPU
- Hourly backups
- Advanced monitoring
```

### 🔧 Setup Instructions

1. **Add MySQL Plugin**
```bash
# In Railway dashboard
Project → Add Plugin → MySQL
# Automatically creates database and credentials
```

2. **Environment Variables (Auto-generated)**
```bash
MYSQLHOST=containers-us-west-xyz.railway.app
MYSQLPORT=6543
MYSQLUSER=root
MYSQLPASSWORD=generated-password
MYSQLDATABASE=railway
```

3. **Backend Connection Code**
```typescript
// apps/backend/src/config/database.ts
import mysql from 'mysql2/promise';

export const createConnection = async () => {
  return await mysql.createConnection({
    host: process.env.MYSQLHOST,
    port: parseInt(process.env.MYSQLPORT || '3306'),
    user: process.env.MYSQLUSER,
    password: process.env.MYSQLPASSWORD,
    database: process.env.MYSQLDATABASE,
    ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false,
    connectTimeout: 60000,
    acquireTimeout: 60000,
    reconnect: true
  });
};
```

4. **Database Initialization**
```typescript
// apps/backend/src/scripts/init-db.ts
import { createConnection } from '../config/database';

async function initializeDatabase() {
  const connection = await createConnection();
  
  await connection.execute(`
    CREATE TABLE IF NOT EXISTS users (
      id INT AUTO_INCREMENT PRIMARY KEY,
      email VARCHAR(255) UNIQUE NOT NULL,
      name VARCHAR(255) NOT NULL,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  `);
  
  console.log('✅ Database initialized successfully');
  await connection.end();
}

initializeDatabase().catch(console.error);
```

### 🚀 Migration & Seeding
```typescript
// apps/backend/src/scripts/migrate.ts
export async function runMigrations() {
  const connection = await createConnection();
  
  // Run migrations in order
  const migrations = [
    'CREATE TABLE users...',
    'CREATE TABLE posts...',
    'ALTER TABLE users ADD COLUMN...'
  ];
  
  for (const migration of migrations) {
    await connection.execute(migration);
  }
  
  await connection.end();
}
```

## 🎨 Render PostgreSQL (Production-Ready)

### ✅ Advantages
- **High reliability**: 99.9% uptime SLA
- **Automatic backups**: Point-in-time recovery
- **Connection pooling**: Efficient connection management
- **Monitoring included**: Performance metrics and alerts
- **PostgreSQL optimized**: Better performance than MySQL for complex queries

### ❌ Considerations
- **PostgreSQL only**: No native MySQL support
- **Higher cost**: $7/month minimum
- **Migration needed**: If coming from MySQL

### 💰 Pricing Structure
```
Starter ($7/month):
- 1GB RAM, 1GB storage
- 7-day backups
- Connection pooling
- SSL encryption

Standard ($20/month):
- 2GB RAM, 10GB storage
- 30-day backups
- Advanced monitoring
- Read replicas available
```

### 🔧 Setup with MySQL Alternative

Since Render doesn't natively support MySQL, here are alternatives:

**Option A: Use PostgreSQL (Recommended)**
```typescript
// Switch to pg instead of mysql2
import { Pool } from 'pg';

export const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false
});

// Convert MySQL queries to PostgreSQL
// MySQL: AUTO_INCREMENT → PostgreSQL: SERIAL
// MySQL: DATETIME → PostgreSQL: TIMESTAMP
```

**Option B: External MySQL (PlanetScale)**
```typescript
// Use PlanetScale for MySQL compatibility
export const databaseConfig = {
  host: process.env.PLANETSCALE_HOST,
  username: process.env.PLANETSCALE_USERNAME,
  password: process.env.PLANETSCALE_PASSWORD,
  database: process.env.PLANETSCALE_DATABASE,
  ssl: { rejectUnauthorized: true }
};
```

## 🌊 Digital Ocean Managed MySQL

### ✅ Advantages
- **Enterprise-grade**: High availability and automatic failover
- **Native MySQL**: Full MySQL 8.0 compatibility
- **Advanced features**: Read replicas, automatic scaling
- **VPC networking**: Secure private connections
- **Professional support**: 24/7 enterprise support

### 💰 Pricing Structure
```
Basic ($15/month):
- 1GB RAM, 10GB storage
- 1 vCPU
- Automated backups
- SSL encryption

Professional ($50/month):
- 4GB RAM, 80GB storage  
- 2 vCPU
- High availability (standby)
- Read replicas
- Advanced monitoring
```

### 🔧 Setup Instructions

1. **Create Database Cluster**
```bash
# Digital Ocean Dashboard
Databases → Create Database Cluster
Engine: MySQL 8.0
Plan: Basic ($15/month)
Region: Same as app deployment
```

2. **Configure Connection**
```typescript
// apps/backend/src/config/database.ts
export const databaseConfig = {
  host: process.env.DO_DATABASE_HOST,
  port: parseInt(process.env.DO_DATABASE_PORT || '25060'),
  user: process.env.DO_DATABASE_USER,
  password: process.env.DO_DATABASE_PASSWORD,
  database: process.env.DO_DATABASE_NAME,
  ssl: {
    ca: process.env.DO_DATABASE_CA_CERT,
    rejectUnauthorized: true
  },
  connectionLimit: 10,
  acquireTimeout: 60000
};
```

3. **Environment Variables**
```bash
DO_DATABASE_HOST=db-mysql-fra1-12345.db.ondigitalocean.com
DO_DATABASE_PORT=25060
DO_DATABASE_USER=doadmin
DO_DATABASE_PASSWORD=secure-password
DO_DATABASE_NAME=defaultdb
DO_DATABASE_CA_CERT=-----BEGIN CERTIFICATE-----...
```

## 🌟 PlanetScale (External MySQL Alternative)

### ✅ Advantages
- **True MySQL compatibility**: No syntax changes needed
- **Branching databases**: Git-like database branches
- **Serverless scaling**: Automatic scaling based on usage
- **Global distribution**: Edge database locations
- **Developer-friendly**: Excellent CLI and dashboard

### 💰 Pricing Structure
```
Hobby (Free):
- 5GB storage
- 1 billion row reads/month
- 10 million row writes/month
- Sleeps after 7 days inactivity

Scaler ($29/month):
- 50GB storage
- 50 billion row reads/month
- 50 million row writes/month
- Multiple databases
```

### 🔧 Integration Setup

1. **Create PlanetScale Database**
```bash
# Install PlanetScale CLI
npm install -g @planetscale/cli

# Create database
pscale database create nx-production --region us-east

# Create development branch
pscale branch create nx-production development
```

2. **Connection Configuration**
```typescript
// apps/backend/src/config/planetscale.ts
import mysql from 'mysql2/promise';

export const createPlanetScaleConnection = () => {
  return mysql.createConnection({
    host: process.env.PLANETSCALE_HOST,
    username: process.env.PLANETSCALE_USERNAME,  
    password: process.env.PLANETSCALE_PASSWORD,
    database: process.env.PLANETSCALE_DATABASE,
    ssl: { rejectUnauthorized: true },
    namedPlaceholders: true
  });
};
```

3. **Environment Variables**
```bash
PLANETSCALE_HOST=aws.connect.psdb.cloud
PLANETSCALE_USERNAME=generated-username
PLANETSCALE_PASSWORD=pscale_pw_generated-password
PLANETSCALE_DATABASE=nx-production
```

## 💾 Database Migration Strategies

### Schema-First Approach
```sql
-- migrations/001_initial_schema.sql
CREATE TABLE users (
  id INT AUTO_INCREMENT PRIMARY KEY,
  email VARCHAR(255) UNIQUE NOT NULL,
  name VARCHAR(255) NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE posts (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  title VARCHAR(255) NOT NULL,
  content TEXT,
  published BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);
```

### Migration Runner
```typescript
// apps/backend/src/scripts/migrate.ts
import fs from 'fs/promises';
import path from 'path';
import { createConnection } from '../config/database';

async function runMigrations() {
  const connection = await createConnection();
  
  // Create migrations table
  await connection.execute(`
    CREATE TABLE IF NOT EXISTS migrations (
      id INT AUTO_INCREMENT PRIMARY KEY,
      filename VARCHAR(255) NOT NULL,
      executed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  `);
  
  // Get executed migrations
  const [executed] = await connection.execute(
    'SELECT filename FROM migrations'
  );
  const executedMigrations = new Set(
    (executed as any[]).map(row => row.filename)
  );
  
  // Read migration files
  const migrationsDir = path.join(__dirname, '../../migrations');
  const files = await fs.readdir(migrationsDir);
  const sqlFiles = files.filter(f => f.endsWith('.sql')).sort();
  
  // Execute pending migrations
  for (const file of sqlFiles) {
    if (!executedMigrations.has(file)) {
      console.log(`Running migration: ${file}`);
      const sql = await fs.readFile(path.join(migrationsDir, file), 'utf8');
      await connection.execute(sql);
      await connection.execute(
        'INSERT INTO migrations (filename) VALUES (?)',
        [file]
      );
    }
  }
  
  await connection.end();
  console.log('✅ Migrations completed');
}

runMigrations().catch(console.error);
```

## 🔄 Backup & Recovery Strategies

### Automated Backups
```typescript
// apps/backend/src/scripts/backup.ts
import { exec } from 'child_process';
import { promisify } from 'util';

const execAsync = promisify(exec);

async function createBackup() {
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
  const filename = `backup-${timestamp}.sql`;
  
  const command = `mysqldump \
    --host=${process.env.MYSQLHOST} \
    --port=${process.env.MYSQLPORT} \
    --user=${process.env.MYSQLUSER} \
    --password=${process.env.MYSQLPASSWORD} \
    --single-transaction \
    --routines \
    --triggers \
    ${process.env.MYSQLDATABASE} > ${filename}`;
  
  await execAsync(command);
  console.log(`✅ Backup created: ${filename}`);
}
```

### Point-in-Time Recovery
```bash
# For production databases, implement PITR
# Most managed services provide this automatically:
# - Railway: Daily snapshots
# - Render: Point-in-time recovery
# - Digital Ocean: Automated backups with restore points
# - PlanetScale: Branch-based recovery
```

## 📊 Performance Optimization

### Connection Pooling
```typescript
// apps/backend/src/config/pool.ts
import mysql from 'mysql2/promise';

export const pool = mysql.createPool({
  host: process.env.MYSQLHOST,
  port: parseInt(process.env.MYSQLPORT || '3306'),
  user: process.env.MYSQLUSER,
  password: process.env.MYSQLPASSWORD,
  database: process.env.MYSQLDATABASE,
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
  acquireTimeout: 60000,
  timeout: 60000,
  reconnect: true,
  ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false
});
```

### Query Optimization
```typescript
// apps/backend/src/services/user.service.ts
export class UserService {
  async findUserWithPosts(userId: number) {
    // Use prepared statements and proper indexing
    const [rows] = await pool.execute(`
      SELECT 
        u.id, u.name, u.email,
        p.id as post_id, p.title, p.content
      FROM users u
      LEFT JOIN posts p ON u.id = p.user_id
      WHERE u.id = ?
    `, [userId]);
    
    return rows;
  }
}
```

## 💰 Cost Comparison Summary

| Option | Setup Cost | Monthly Cost | Storage | Backup | Best For |
|--------|------------|--------------|---------|--------|----------|
| **Railway MySQL** | $0 | $5-15 | 1-8GB | Daily | MVP, Budget |
| **Render PostgreSQL** | $0 | $7-20 | 1-10GB | PITR | Production |
| **Digital Ocean MySQL** | $0 | $15-50 | 10-80GB | Advanced | Enterprise |
| **PlanetScale** | $0 | $0-29 | 5-50GB | Branching | Scale |
| **AWS RDS** | $0 | $15-100+ | 20GB+ | PITR | Enterprise |

## 🎯 Recommendations by Use Case

### MVP/Prototype ($5-10/month)
- **Railway MySQL Plugin**: Simplest setup, lowest cost
- **PlanetScale Hobby**: Free tier for development

### Production App ($15-30/month)  
- **Railway MySQL Pro**: Good balance of features and cost
- **Render PostgreSQL**: Better reliability and monitoring
- **PlanetScale Scaler**: For high-traffic applications

### Enterprise ($30+/month)
- **Digital Ocean Managed MySQL**: Full enterprise features
- **AWS RDS MySQL**: Maximum control and scaling
- **PlanetScale**: For global, high-scale applications

## 🔗 Integration Examples

### Railway + Express.js
```typescript
// Complete integration example
import express from 'express';
import { pool } from './config/database';

const app = express();

app.get('/api/users', async (req, res) => {
  try {
    const [rows] = await pool.execute('SELECT * FROM users');
    res.json(rows);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.listen(process.env.PORT || 3001);
```

### Error Handling & Reconnection
```typescript
// apps/backend/src/config/database-with-retry.ts
import mysql from 'mysql2/promise';

let pool: mysql.Pool;

export function createPool() {
  if (!pool) {
    pool = mysql.createPool({
      // ... config
      reconnect: true,
      acquireTimeout: 60000,
    });
    
    // Handle connection errors
    pool.on('connection', (connection) => {
      console.log('MySQL connected as id ' + connection.threadId);
    });
    
    pool.on('error', (err) => {
      console.error('MySQL pool error:', err);
      if (err.code === 'PROTOCOL_CONNECTION_LOST') {
        createPool(); // Recreate pool
      }
    });
  }
  
  return pool;
}
```

---

**💡 Quick Decision Guide**:
- **Tight budget + simple setup** → Railway MySQL Plugin
- **Production reliability** → Render PostgreSQL  
- **True MySQL needed** → PlanetScale or Digital Ocean
- **Enterprise features** → Digital Ocean Managed MySQL

---

*Database Deployment Guide | MySQL hosting strategies for Nx applications*