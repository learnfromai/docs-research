# Implementation Guide

## Overview

This comprehensive implementation guide walks you through deploying a complete Nx monorepo application (React frontend + Express.js backend + MySQL database) to Railway.com, from initial setup to production deployment.

## Prerequisites

### Development Environment
- **Node.js** 18+ and npm/yarn
- **Git** repository (GitHub/GitLab)
- **Nx CLI**: `npm install -g nx`
- **Railway CLI**: `npm install -g @railway/cli`

### Project Structure
Ensure your Nx workspace follows this structure:
```
clinic-management/
├── apps/
│   ├── web/              # React frontend
│   └── api/              # Express.js backend
├── libs/                 # Shared libraries
├── nx.json
├── package.json
└── railway.toml         # Railway configuration
```

## Step 1: Railway Account Setup

### 1.1 Create Railway Account
1. Visit [railway.app](https://railway.app)
2. Sign up with GitHub account (recommended)
3. Verify email address
4. Complete profile setup

### 1.2 Install and Configure CLI
```bash
# Install Railway CLI
npm install -g @railway/cli

# Login to Railway
railway login

# Verify login
railway whoami
```

## Step 2: Project Initialization

### 2.1 Create Railway Project
```bash
# Navigate to your Nx workspace
cd clinic-management

# Initialize Railway project
railway new clinic-management-system

# Link local directory to Railway project
railway link
```

### 2.2 Create Services
```bash
# Create frontend service
railway service create web

# Create backend service  
railway service create api

# Create MySQL database service
railway service create mysql
```

## Step 3: Database Setup

### 3.1 Configure MySQL Service
```bash
# Set MySQL environment variables
railway variables set MYSQL_ROOT_PASSWORD=$(openssl rand -base64 32)
railway variables set MYSQL_DATABASE=clinic_db
railway variables set MYSQL_USER=clinic_user
railway variables set MYSQL_PASSWORD=$(openssl rand -base64 32)
```

### 3.2 Database Schema Setup

Create `database/schema.sql`:
```sql
-- Create clinic database schema
CREATE DATABASE IF NOT EXISTS clinic_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE clinic_db;

-- Patients table
CREATE TABLE patients (
  id INT AUTO_INCREMENT PRIMARY KEY,
  patient_id VARCHAR(20) UNIQUE NOT NULL,
  first_name VARCHAR(100) NOT NULL,
  last_name VARCHAR(100) NOT NULL,
  date_of_birth DATE NOT NULL,
  phone VARCHAR(20),
  email VARCHAR(255),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_patient_id (patient_id),
  INDEX idx_name (last_name, first_name)
);

-- Appointments table
CREATE TABLE appointments (
  id INT AUTO_INCREMENT PRIMARY KEY,
  patient_id INT NOT NULL,
  appointment_date DATE NOT NULL,
  appointment_time TIME NOT NULL,
  status ENUM('Scheduled', 'Confirmed', 'Completed', 'Cancelled') DEFAULT 'Scheduled',
  notes TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (patient_id) REFERENCES patients(id) ON DELETE CASCADE,
  INDEX idx_date (appointment_date),
  INDEX idx_patient (patient_id)
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
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### 3.3 Database Connection Library

Create `libs/database/src/index.ts`:
```typescript
import mysql from 'mysql2/promise';

interface DatabaseConfig {
  host: string;
  port: number;
  user: string;
  password: string;
  database: string;
  ssl?: any;
}

class DatabaseService {
  private pool: mysql.Pool;

  constructor() {
    const config: DatabaseConfig = {
      host: process.env.MYSQL_HOST!,
      port: parseInt(process.env.MYSQL_PORT || '3306'),
      user: process.env.MYSQL_USER!,
      password: process.env.MYSQL_PASSWORD!,
      database: process.env.MYSQL_DATABASE!,
      ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false,
      connectionLimit: 10,
      acquireTimeout: 60000,
      timeout: 60000
    };

    this.pool = mysql.createPool(config);
  }

  async query(sql: string, params?: any[]): Promise<any> {
    const [rows] = await this.pool.execute(sql, params);
    return rows;
  }

  async close(): Promise<void> {
    await this.pool.end();
  }
}

export const db = new DatabaseService();
```

## Step 4: Backend API Configuration

### 4.1 Update Express.js Application

Update `apps/api/src/main.ts`:
```typescript
import express from 'express';
import cors from 'cors';
import { db } from '@clinic/database';

const app = express();
const PORT = process.env.PORT || 3333;

// Middleware
app.use(cors({
  origin: process.env.FRONTEND_URL || 'http://localhost:3000',
  credentials: true
}));
app.use(express.json());

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ 
    status: 'healthy',
    timestamp: new Date().toISOString(),
    environment: process.env.NODE_ENV 
  });
});

// Patients API
app.get('/api/patients', async (req, res) => {
  try {
    const patients = await db.query('SELECT * FROM patients ORDER BY last_name, first_name');
    res.json(patients);
  } catch (error) {
    console.error('Error fetching patients:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

app.post('/api/patients', async (req, res) => {
  try {
    const { patient_id, first_name, last_name, date_of_birth, phone, email } = req.body;
    
    const result = await db.query(
      'INSERT INTO patients (patient_id, first_name, last_name, date_of_birth, phone, email) VALUES (?, ?, ?, ?, ?, ?)',
      [patient_id, first_name, last_name, date_of_birth, phone, email]
    );
    
    res.status(201).json({ id: result.insertId, message: 'Patient created successfully' });
  } catch (error) {
    console.error('Error creating patient:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Appointments API
app.get('/api/appointments', async (req, res) => {
  try {
    const appointments = await db.query(`
      SELECT a.*, p.first_name, p.last_name 
      FROM appointments a 
      JOIN patients p ON a.patient_id = p.id 
      ORDER BY a.appointment_date, a.appointment_time
    `);
    res.json(appointments);
  } catch (error) {
    console.error('Error fetching appointments:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Start server
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
```

### 4.2 Update Backend Project Configuration

Update `apps/api/project.json`:
```json
{
  "name": "api",
  "targets": {
    "build": {
      "executor": "@nx/webpack:webpack",
      "options": {
        "outputPath": "dist/apps/api",
        "main": "apps/api/src/main.ts",
        "tsConfig": "apps/api/tsconfig.app.json",
        "target": "node",
        "compiler": "tsc"
      },
      "configurations": {
        "production": {
          "optimization": true,
          "extractLicenses": true,
          "fileReplacements": [
            {
              "replace": "apps/api/src/environments/environment.ts",
              "with": "apps/api/src/environments/environment.prod.ts"
            }
          ]
        }
      }
    },
    "serve": {
      "executor": "@nx/js:node",
      "options": {
        "buildTarget": "api:build",
        "port": 3333
      }
    }
  }
}
```

## Step 5: Frontend Configuration

### 5.1 Update React Application

Update `apps/web/src/main.tsx`:
```typescript
import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';
import './styles.css';

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
```

Create `apps/web/src/App.tsx`:
```typescript
import React, { useState, useEffect } from 'react';

interface Patient {
  id: number;
  patient_id: string;
  first_name: string;
  last_name: string;
  phone: string;
  email: string;
}

const API_BASE_URL = import.meta.env.VITE_API_URL || 'http://localhost:3333';

function App() {
  const [patients, setPatients] = useState<Patient[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchPatients();
  }, []);

  const fetchPatients = async () => {
    try {
      const response = await fetch(`${API_BASE_URL}/api/patients`);
      const data = await response.json();
      setPatients(data);
    } catch (error) {
      console.error('Error fetching patients:', error);
    } finally {
      setLoading(false);
    }
  };

  if (loading) {
    return <div className="loading">Loading patients...</div>;
  }

  return (
    <div className="app">
      <header className="header">
        <h1>Clinic Management System</h1>
      </header>
      
      <main className="main">
        <section className="patients-section">
          <h2>Patients ({patients.length})</h2>
          
          <div className="patients-grid">
            {patients.map((patient) => (
              <div key={patient.id} className="patient-card">
                <h3>{patient.first_name} {patient.last_name}</h3>
                <p>ID: {patient.patient_id}</p>
                <p>Phone: {patient.phone}</p>
                <p>Email: {patient.email}</p>
              </div>
            ))}
          </div>
          
          {patients.length === 0 && (
            <p className="no-patients">No patients found.</p>
          )}
        </section>
      </main>
    </div>
  );
}

export default App;
```

### 5.2 Update Frontend Project Configuration

Update `apps/web/project.json`:
```json
{
  "name": "web",
  "targets": {
    "build": {
      "executor": "@nx/vite:build",
      "options": {
        "outputPath": "dist/apps/web"
      },
      "configurations": {
        "production": {
          "mode": "production",
          "optimization": true
        }
      }
    },
    "serve": {
      "executor": "@nx/vite:dev-server",
      "options": {
        "buildTarget": "web:build",
        "port": 3000
      }
    }
  }
}
```

## Step 6: Railway Configuration

### 6.1 Create Railway Configuration File

Create `railway.toml` in project root:
```toml
[build]
builder = "NIXPACKS"

[environments.production.services.web]
buildCommand = "npx nx build web --prod"
startCommand = "npx nx serve web --prod --port=$PORT"
variables = { 
  NODE_ENV = "production",
  VITE_API_URL = "${{API_URL}}"
}

[environments.production.services.api]
buildCommand = "npx nx build api --prod"
startCommand = "node dist/apps/api/main.js"
variables = { 
  NODE_ENV = "production",
  FRONTEND_URL = "${{WEB_URL}}"
}

[environments.production.services.mysql]
image = "mysql:8.0"
variables = { 
  MYSQL_ROOT_PASSWORD = "${{MYSQL_ROOT_PASSWORD}}",
  MYSQL_DATABASE = "clinic_db"
}
```

### 6.2 Update Package.json Scripts

Add Railway-specific scripts to `package.json`:
```json
{
  "scripts": {
    "build": "nx run-many --target=build --all --prod",
    "build:web": "nx build web --prod",
    "build:api": "nx build api --prod",
    "start": "node dist/apps/api/main.js",
    "start:web": "nx serve web --prod --port=$PORT",
    "start:api": "node dist/apps/api/main.js",
    "railway:build": "npm ci && nx build api --prod",
    "railway:start": "node dist/apps/api/main.js"
  }
}
```

## Step 7: Environment Variables Setup

### 7.1 Set Database Variables
```bash
# Switch to API service
railway service select api

# Set database connection variables
railway variables set MYSQL_HOST=${{MYSQL_HOST}}
railway variables set MYSQL_PORT=${{MYSQL_PORT}}
railway variables set MYSQL_USER=${{MYSQL_USER}}
railway variables set MYSQL_PASSWORD=${{MYSQL_PASSWORD}}
railway variables set MYSQL_DATABASE=${{MYSQL_DATABASE}}
railway variables set DATABASE_URL=${{DATABASE_URL}}
```

### 7.2 Set Frontend Variables
```bash
# Switch to web service
railway service select web

# Set API URL
railway variables set VITE_API_URL=https://api-production.railway.app
```

### 7.3 Set Cross-Service URLs
```bash
# Set frontend URL for CORS
railway service select api
railway variables set FRONTEND_URL=https://web-production.railway.app

# Set API URL for frontend
railway service select web
railway variables set VITE_API_URL=https://api-production.railway.app
```

## Step 8: Deployment

### 8.1 Initial Deployment

```bash
# Deploy all services
railway up --detach

# Monitor deployment status
railway status

# Check logs
railway logs --tail
```

### 8.2 Service-Specific Deployment

```bash
# Deploy frontend only
railway service select web
railway up --detach

# Deploy backend only
railway service select api
railway up --detach

# Check specific service logs
railway logs --service api --tail
```

### 8.3 Database Migration

```bash
# Connect to database and run schema
railway connect mysql

# In MySQL shell:
SOURCE /path/to/database/schema.sql;
EXIT;
```

## Step 9: Custom Domain Setup (Optional)

### 9.1 Configure Custom Domain
```bash
# Add custom domain
railway domain add clinic.yourdomain.com --service web
railway domain add api.yourdomain.com --service api

# Verify DNS configuration
railway domain list
```

### 9.2 Update Environment Variables
```bash
# Update with custom domains
railway service select api
railway variables set FRONTEND_URL=https://clinic.yourdomain.com

railway service select web
railway variables set VITE_API_URL=https://api.yourdomain.com
```

## Step 10: Production Optimizations

### 10.1 Enable Production Features

Create `apps/api/src/environments/environment.prod.ts`:
```typescript
export const environment = {
  production: true,
  database: {
    ssl: true,
    connectionLimit: 10
  },
  cors: {
    origin: process.env.FRONTEND_URL,
    credentials: true
  },
  logging: {
    level: 'error'
  }
};
```

### 10.2 Add Health Checks

Create `apps/api/src/health.ts`:
```typescript
import { db } from '@clinic/database';

export async function healthCheck() {
  try {
    // Test database connection
    await db.query('SELECT 1');
    
    return {
      status: 'healthy',
      database: 'connected',
      timestamp: new Date().toISOString(),
      uptime: process.uptime()
    };
  } catch (error) {
    return {
      status: 'unhealthy',
      database: 'disconnected',
      error: error.message,
      timestamp: new Date().toISOString()
    };
  }
}
```

### 10.3 Add Error Handling

```typescript
// Add to main.ts
app.use((error: any, req: any, res: any, next: any) => {
  console.error('Unhandled error:', error);
  res.status(500).json({ 
    error: 'Internal server error',
    timestamp: new Date().toISOString()
  });
});

// Graceful shutdown
process.on('SIGTERM', async () => {
  console.log('SIGTERM received, shutting down gracefully');
  await db.close();
  process.exit(0);
});
```

## Step 11: Monitoring and Maintenance

### 11.1 Set Up Monitoring
```bash
# View service metrics
railway metrics

# Set up alerts
railway alerts create --name "High CPU" --threshold 80 --metric cpu

# Configure notifications
railway notifications add --webhook https://your-webhook-url.com
```

### 11.2 Backup Strategy

Create `scripts/backup.js`:
```javascript
const { exec } = require('child_process');

async function backupDatabase() {
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
  const backupFile = `backup-${timestamp}.sql`;
  
  const command = `railway run mysqldump -h $MYSQL_HOST -u $MYSQL_USER -p$MYSQL_PASSWORD $MYSQL_DATABASE > ${backupFile}`;
  
  exec(command, (error, stdout, stderr) => {
    if (error) {
      console.error('Backup failed:', error);
      return;
    }
    console.log('Backup completed:', backupFile);
  });
}

// Run backup
backupDatabase();
```

## Step 12: Testing Deployment

### 12.1 Verify Services
```bash
# Test frontend
curl https://web-production.railway.app

# Test backend health
curl https://api-production.railway.app/health

# Test API endpoints
curl https://api-production.railway.app/api/patients
```

### 12.2 Database Verification
```bash
# Connect to database
railway connect mysql

# Verify tables
SHOW TABLES;
DESCRIBE patients;
SELECT COUNT(*) FROM patients;
```

## Troubleshooting Common Issues

### Build Failures
```bash
# Clear build cache
railway service delete && railway service create

# Check build logs
railway logs --deployment [deployment-id]

# Verify build commands
railway variables list | grep COMMAND
```

### Connection Issues
```bash
# Check environment variables
railway variables list

# Test database connection
railway run node -e "console.log(process.env.DATABASE_URL)"

# Verify service communication
railway logs --service api | grep -i error
```

### Performance Issues
```bash
# Monitor resource usage
railway metrics --service api

# Check memory usage
railway logs --service api | grep -i memory

# Optimize queries
railway connect mysql
EXPLAIN SELECT * FROM patients;
```

## Next Steps After Deployment

1. **Monitor Performance**: Use Railway dashboard to track resource usage
2. **Set Up Alerts**: Configure notifications for service issues
3. **Implement Backups**: Schedule regular database backups
4. **Security Review**: Audit access controls and environment variables
5. **Documentation**: Document deployment process for team members

---

## Related Guides

1. **[MySQL Database Guide](./mysql-database-deployment.md)** - Database optimization
2. **[Cost Analysis](./small-scale-cost-analysis.md)** - Budget planning
3. **[Best Practices](./best-practices.md)** - Production optimization

---

*Implementation Guide | Railway.com Deployment | January 2025*