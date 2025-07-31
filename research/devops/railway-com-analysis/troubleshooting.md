# Troubleshooting Guide

## Overview

This guide provides solutions to common issues encountered when deploying and managing applications on Railway.com, specifically for Nx monorepo projects with React frontend, Express.js backend, and MySQL database.

## Build and Deployment Issues

### 1. Build Failures

#### Problem: Nx Build Command Not Found
```
Error: nx: command not found
```

**Solution**:
```bash
# Option 1: Use npx (recommended)
npx nx build web --prod
npx nx build api --prod

# Option 2: Install Nx globally (in railway.toml)
[environments.production.services.api]
buildCommand = "npm install -g nx && nx build api --prod"

# Option 3: Use npm scripts
# In package.json:
"scripts": {
  "build:api": "npx nx build api --prod"
}

# In railway.toml:
buildCommand = "npm run build:api"
```

#### Problem: TypeScript Compilation Errors
```
Error: TS2307: Cannot find module '@clinic/shared'
```

**Solution**:
```bash
# Check tsconfig paths
# Ensure tsconfig.base.json has correct paths:
{
  "compilerOptions": {
    "paths": {
      "@clinic/shared": ["libs/shared/src/index.ts"]
    }
  }
}

# Update Nx project configuration
# In apps/api/project.json:
{
  "targets": {
    "build": {
      "options": {
        "buildLibsFromSource": false  // Use pre-built libs
      }
    }
  }
}
```

#### Problem: Out of Memory During Build
```
Error: JavaScript heap out of memory
```

**Solution**:
```bash
# Increase Node.js memory limit
# In package.json:
"scripts": {
  "build": "NODE_OPTIONS='--max-old-space-size=4096' nx run-many --target=build --all --prod"
}

# Or in railway.toml:
buildCommand = "NODE_OPTIONS='--max-old-space-size=4096' npx nx build api --prod"

# Alternative: Use incremental builds
buildCommand = "npx nx build api --prod --skip-nx-cache=false"
```

### 2. Deployment Configuration Issues

#### Problem: Railway Service Not Starting
```
Error: Service exited with code 1
```

**Diagnostic Steps**:
```bash
# Check Railway logs
railway logs --tail

# Check service status
railway status

# Verify start command
railway variables list | grep COMMAND

# Test locally
npm run start
node dist/apps/api/main.js
```

**Common Solutions**:
```bash
# Fix 1: Correct start command in railway.toml
[environments.production.services.api]
startCommand = "node dist/apps/api/main.js"

# Fix 2: Ensure output directory exists
buildCommand = "npx nx build api --prod && ls -la dist/apps/"

# Fix 3: Check for missing dependencies
# Add to package.json dependencies (not devDependencies):
"dependencies": {
  "express": "^4.18.2",
  "mysql2": "^3.6.0"
}
```

#### Problem: Environment Variables Not Set
```
Error: Cannot read property 'MYSQL_HOST' of undefined
```

**Solution**:
```bash
# Check current variables
railway variables list

# Set missing variables
railway variables set MYSQL_HOST=${{MYSQL_HOST}}
railway variables set MYSQL_PASSWORD=${{MYSQL_PASSWORD}}

# Use Railway-provided database URL
railway variables set DATABASE_URL=${{DATABASE_URL}}

# Verify in code:
console.log('Environment variables:', {
  MYSQL_HOST: process.env.MYSQL_HOST,
  NODE_ENV: process.env.NODE_ENV,
  PORT: process.env.PORT
});
```

## Database Connection Issues

### 1. MySQL Connection Failures

#### Problem: Connection Refused
```
Error: connect ECONNREFUSED
```

**Diagnostic Steps**:
```bash
# Check MySQL service status
railway service select mysql
railway logs --tail

# Verify connection variables
railway variables list | grep MYSQL

# Test connection from API service
railway run mysql -h $MYSQL_HOST -u $MYSQL_USER -p
```

**Solutions**:
```typescript
// Add connection retry logic
import mysql from 'mysql2/promise';

async function createConnection(retries = 5): Promise<mysql.Connection> {
  for (let i = 0; i < retries; i++) {
    try {
      const connection = await mysql.createConnection({
        host: process.env.MYSQL_HOST,
        port: parseInt(process.env.MYSQL_PORT || '3306'),
        user: process.env.MYSQL_USER,
        password: process.env.MYSQL_PASSWORD,
        database: process.env.MYSQL_DATABASE,
        connectTimeout: 60000,
        acquireTimeout: 60000,
        timeout: 60000,
        ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false
      });
      
      await connection.ping();
      console.log('Database connected successfully');
      return connection;
      
    } catch (error) {
      console.log(`Connection attempt ${i + 1} failed:`, error.message);
      
      if (i === retries - 1) {
        throw error;
      }
      
      // Wait before retry
      await new Promise(resolve => setTimeout(resolve, 2000 * (i + 1)));
    }
  }
}
```

#### Problem: SSL/TLS Connection Issues
```
Error: ER_NOT_SUPPORTED_AUTH_MODE
```

**Solution**:
```typescript
// Update connection configuration
const dbConfig = {
  host: process.env.MYSQL_HOST,
  port: parseInt(process.env.MYSQL_PORT || '3306'),
  user: process.env.MYSQL_USER,
  password: process.env.MYSQL_PASSWORD,
  database: process.env.MYSQL_DATABASE,
  ssl: {
    rejectUnauthorized: false,
    ca: undefined,
    cert: undefined,
    key: undefined
  },
  authPlugins: {
    mysql_clear_password: () => () => {
      return Buffer.from(process.env.MYSQL_PASSWORD + '\0');
    }
  }
};
```

#### Problem: Connection Pool Exhaustion
```
Error: Too many connections
```

**Solution**:
```typescript
// Optimize connection pool
const pool = mysql.createPool({
  host: process.env.MYSQL_HOST,
  user: process.env.MYSQL_USER,
  password: process.env.MYSQL_PASSWORD,
  database: process.env.MYSQL_DATABASE,
  connectionLimit: 5, // Reduce for small applications
  acquireTimeout: 30000,
  timeout: 30000,
  idleTimeout: 300000, // 5 minutes
  reconnect: true,
  queueLimit: 0
});

// Always release connections
export async function safeQuery(sql: string, params?: any[]) {
  let connection;
  try {
    connection = await pool.getConnection();
    const [rows] = await connection.execute(sql, params);
    return rows;
  } finally {
    if (connection) connection.release();
  }
}
```

### 2. Schema and Migration Issues

#### Problem: Tables Not Found
```
Error: Table 'clinic_db.patients' doesn't exist
```

**Solution**:
```bash
# Check if database exists
railway run mysql -e "SHOW DATABASES;"

# Create database manually
railway run mysql -e "CREATE DATABASE IF NOT EXISTS clinic_db;"

# Run schema script
railway run mysql clinic_db < database/schema.sql

# Or use migration script
node scripts/migrate.js
```

#### Problem: Migration Script Fails
```
Error: Migration script timeout
```

**Solution**:
```javascript
// Improved migration script with better error handling
const mysql = require('mysql2/promise');
const fs = require('fs');
const path = require('path');

async function runMigrations() {
  let connection;
  
  try {
    connection = await mysql.createConnection({
      host: process.env.MYSQL_HOST,
      port: process.env.MYSQL_PORT || 3306,
      user: process.env.MYSQL_USER,
      password: process.env.MYSQL_PASSWORD,
      database: process.env.MYSQL_DATABASE,
      multipleStatements: true,
      connectTimeout: 60000,
      acquireTimeout: 60000,
      timeout: 60000
    });

    // Test connection
    await connection.ping();
    console.log('✅ Database connection established');

    // Run migrations with timeout
    const migrationTimeout = 300000; // 5 minutes
    
    const migrationPromise = runMigrationFiles(connection);
    const timeoutPromise = new Promise((_, reject) => 
      setTimeout(() => reject(new Error('Migration timeout')), migrationTimeout)
    );

    await Promise.race([migrationPromise, timeoutPromise]);
    
  } catch (error) {
    console.error('❌ Migration failed:', error);
    throw error;
  } finally {
    if (connection) {
      await connection.end();
    }
  }
}

async function runMigrationFiles(connection) {
  // Migration logic here
}
```

## Service Communication Issues

### 1. CORS Errors

#### Problem: CORS Policy Violations
```
Error: Access to fetch at 'https://api.railway.app' from origin 'https://web.railway.app' has been blocked by CORS policy
```

**Solution**:
```typescript
// Update CORS configuration in Express.js
import cors from 'cors';

const corsOptions = {
  origin: [
    process.env.FRONTEND_URL,
    'https://web-production.railway.app',
    'https://clinic-web.railway.app',
    'http://localhost:3000' // For development
  ],
  credentials: true,
  optionsSuccessStatus: 200,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
  allowedHeaders: [
    'Content-Type', 
    'Authorization', 
    'X-Requested-With',
    'Accept',
    'Origin'
  ]
};

app.use(cors(corsOptions));

// Handle preflight requests
app.options('*', cors(corsOptions));
```

#### Problem: API URL Not Resolving
```
Error: TypeError: Failed to fetch
```

**Solution**:
```typescript
// Frontend API configuration with fallback
const API_BASE_URL = import.meta.env.VITE_API_URL || 
                    'https://api-production.railway.app' ||
                    'http://localhost:3333';

// Add error handling to API calls
async function apiCall(endpoint: string, options: RequestInit = {}) {
  try {
    const response = await fetch(`${API_BASE_URL}${endpoint}`, {
      ...options,
      headers: {
        'Content-Type': 'application/json',
        ...options.headers
      }
    });

    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }

    return await response.json();
  } catch (error) {
    console.error('API call failed:', error);
    
    // Try fallback URL if main URL fails
    if (API_BASE_URL.includes('railway.app')) {
      const fallbackUrl = 'http://localhost:3333';
      const fallbackResponse = await fetch(`${fallbackUrl}${endpoint}`, options);
      return await fallbackResponse.json();
    }
    
    throw error;
  }
}
```

### 2. Service Discovery Issues

#### Problem: Services Can't Communicate
```
Error: getaddrinfo ENOTFOUND api-service
```

**Solution**:
```bash
# Use Railway-provided URLs instead of service names
# Set environment variables correctly:
railway service select web
railway variables set VITE_API_URL=https://api-production.railway.app

railway service select api
railway variables set FRONTEND_URL=https://web-production.railway.app

# Check Railway internal networking
railway run nslookup api-production.railway.internal
```

## Performance Issues

### 1. Slow Application Response

#### Problem: High Response Times
```
Warning: API responses taking >2000ms
```

**Diagnostic Steps**:
```bash
# Check Railway metrics
railway metrics --service api

# Monitor resource usage
railway logs --service api | grep -i memory

# Check database performance
railway run mysql -e "SHOW PROCESSLIST;"
```

**Solutions**:
```typescript
// Add response time monitoring
app.use((req, res, next) => {
  const start = Date.now();
  
  res.on('finish', () => {
    const duration = Date.now() - start;
    console.log(`${req.method} ${req.path} - ${res.statusCode} - ${duration}ms`);
    
    if (duration > 1000) {
      console.warn(`Slow request: ${req.method} ${req.path} took ${duration}ms`);
    }
  });
  
  next();
});

// Optimize database queries
export async function getPatients(limit = 20, offset = 0) {
  // Use LIMIT and OFFSET for pagination
  const query = `
    SELECT id, patient_id, first_name, last_name, phone 
    FROM patients 
    ORDER BY last_name, first_name 
    LIMIT ? OFFSET ?
  `;
  
  return await db.query(query, [limit, offset]);
}

// Add database indexes
// CREATE INDEX idx_patients_name ON patients(last_name, first_name);
// CREATE INDEX idx_appointments_date ON appointments(appointment_date);
```

#### Problem: Memory Leaks
```
Error: JavaScript heap out of memory
```

**Solution**:
```typescript
// Proper connection management
class DatabaseService {
  private pool: mysql.Pool;
  
  async query(sql: string, params?: any[]) {
    let connection;
    try {
      connection = await this.pool.getConnection();
      const [rows] = await connection.execute(sql, params);
      return rows;
    } finally {
      if (connection) connection.release(); // Always release
    }
  }
}

// Memory monitoring
setInterval(() => {
  const usage = process.memoryUsage();
  console.log('Memory usage:', {
    rss: Math.round(usage.rss / 1024 / 1024) + ' MB',
    heapUsed: Math.round(usage.heapUsed / 1024 / 1024) + ' MB',
    heapTotal: Math.round(usage.heapTotal / 1024 / 1024) + ' MB'
  });
}, 300000); // Every 5 minutes

// Graceful shutdown
process.on('SIGTERM', async () => {
  console.log('SIGTERM received, closing database connections...');
  await db.close();
  process.exit(0);
});
```

### 2. Cold Start Issues

#### Problem: Service Takes Too Long to Start
```
Error: Health check timeout
```

**Solution**:
```typescript
// Optimize application startup
async function startServer() {
  console.log('🚀 Starting server...');
  
  try {
    // Initialize database connection with timeout
    const dbPromise = initDatabase();
    const timeoutPromise = new Promise((_, reject) => 
      setTimeout(() => reject(new Error('Database connection timeout')), 30000)
    );
    
    await Promise.race([dbPromise, timeoutPromise]);
    console.log('✅ Database connected');
    
    // Start HTTP server
    const server = app.listen(PORT, '0.0.0.0', () => {
      console.log(`✅ Server running on port ${PORT}`);
    });
    
    // Health check endpoint
    app.get('/health', (req, res) => {
      res.json({ 
        status: 'healthy',
        timestamp: new Date().toISOString(),
        uptime: process.uptime()
      });
    });
    
  } catch (error) {
    console.error('❌ Server startup failed:', error);
    process.exit(1);
  }
}
```

## Cost and Resource Management

### 1. Unexpected High Costs

#### Problem: Railway Bill Higher Than Expected
```
Warning: Usage exceeded budget
```

**Diagnostic Steps**:
```bash
# Check resource usage
railway metrics --service api --time-range 7d

# Review usage patterns
railway logs --service api | grep -E "(memory|cpu|disk)"

# Check service configurations
railway variables list
```

**Solutions**:
```bash
# Optimize resource allocation
# Reduce memory limits for small applications
railway variables set MEMORY_LIMIT=512  # MB
railway variables set CPU_LIMIT=0.5     # vCPU

# Monitor database usage
railway run mysql -e "
  SELECT 
    table_schema AS 'Database',
    ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'Size (MB)'
  FROM information_schema.TABLES 
  GROUP BY table_schema;
"

# Cleanup old data
node scripts/cleanup-old-data.js
```

#### Problem: Service Auto-Scaling Too Aggressively
```
Warning: Multiple instances running
```

**Solution**:
```bash
# Configure scaling limits
# In railway.toml:
[environments.production.services.api]
replicas = { min = 1, max = 2 }
resources = { memory = "512Mi", cpu = "0.5" }

# Or via CLI:
railway service configure --replicas-min 1 --replicas-max 2
railway service configure --memory 512Mi --cpu 0.5
```

### 2. Database Storage Issues

#### Problem: Database Storage Growing Rapidly
```
Warning: Database storage usage high
```

**Solution**:
```sql
-- Check table sizes
SELECT 
  table_name AS 'Table',
  ROUND(((data_length + index_length) / 1024 / 1024), 2) AS 'Size (MB)'
FROM information_schema.TABLES 
WHERE table_schema = 'clinic_db'
ORDER BY (data_length + index_length) DESC;

-- Archive old data
CREATE TABLE appointments_archive AS 
SELECT * FROM appointments 
WHERE appointment_date < DATE_SUB(CURRENT_DATE, INTERVAL 1 YEAR);

DELETE FROM appointments 
WHERE appointment_date < DATE_SUB(CURRENT_DATE, INTERVAL 1 YEAR);

-- Optimize tables
OPTIMIZE TABLE patients;
OPTIMIZE TABLE appointments;
OPTIMIZE TABLE medical_records;
```

## Security Issues

### 1. Authentication Problems

#### Problem: JWT Token Validation Fails
```
Error: JsonWebTokenError: invalid signature
```

**Solution**:
```typescript
// Ensure consistent JWT secret across deployments
// In environment configuration:
export const environment = {
  jwt: {
    secret: process.env.JWT_SECRET || (() => {
      throw new Error('JWT_SECRET environment variable is required');
    })(),
    expiresIn: '24h',
    issuer: 'clinic-api',
    audience: 'clinic-web'
  }
};

// Robust token validation
import jwt from 'jsonwebtoken';

export function verifyToken(token: string) {
  try {
    return jwt.verify(token, environment.jwt.secret, {
      issuer: environment.jwt.issuer,
      audience: environment.jwt.audience,
      algorithms: ['HS256']
    });
  } catch (error) {
    if (error instanceof jwt.TokenExpiredError) {
      throw new Error('Token expired');
    } else if (error instanceof jwt.JsonWebTokenError) {
      throw new Error('Invalid token');
    } else {
      throw new Error('Token verification failed');
    }
  }
}
```

#### Problem: Session Management Issues
```
Error: Session store disconnected
```

**Solution**:
```typescript
// Use database-backed sessions for Railway
import session from 'express-session';
import MySQLStore from 'express-mysql-session';

const MySQLStoreConstructor = MySQLStore(session);

const sessionStore = new MySQLStoreConstructor({
  host: process.env.MYSQL_HOST,
  port: parseInt(process.env.MYSQL_PORT || '3306'),
  user: process.env.MYSQL_USER,
  password: process.env.MYSQL_PASSWORD,
  database: process.env.MYSQL_DATABASE,
  createDatabaseTable: true,
  reconnect: true,
  endConnectionOnClose: false
});

app.use(session({
  key: 'clinic_session',
  secret: process.env.SESSION_SECRET!,
  store: sessionStore,
  resave: false,
  saveUninitialized: false,
  rolling: true,
  cookie: {
    maxAge: 24 * 60 * 60 * 1000, // 24 hours
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'lax'
  }
}));
```

## Monitoring and Logging

### 1. Missing or Inadequate Logs

#### Problem: Cannot Debug Issues
```
Error: No application logs available
```

**Solution**:
```typescript
// Structured logging with Winston
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
      ip: req.ip,
      userId: req.user?.id
    });
  });
  
  next();
};

// Error logging
export const errorHandler = (error: any, req: any, res: any, next: any) => {
  logger.error('Application Error', {
    error: error.message,
    stack: error.stack,
    url: req.url,
    method: req.method,
    body: req.body,
    params: req.params,
    query: req.query,
    userId: req.user?.id
  });
  
  res.status(500).json({
    error: process.env.NODE_ENV === 'production' 
      ? 'Internal server error' 
      : error.message,
    timestamp: new Date().toISOString()
  });
};
```

### 2. Health Check Failures

#### Problem: Health Checks Timing Out
```
Error: Health check failed
```

**Solution**:
```typescript
// Comprehensive health check endpoint
app.get('/health', async (req, res) => {
  const healthCheck = {
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    environment: process.env.NODE_ENV,
    version: process.env.npm_package_version || '1.0.0',
    checks: {}
  };

  try {
    // Database health check with timeout
    const dbCheckPromise = checkDatabaseHealth();
    const dbTimeout = new Promise((_, reject) => 
      setTimeout(() => reject(new Error('Database timeout')), 5000)
    );
    
    healthCheck.checks.database = await Promise.race([dbCheckPromise, dbTimeout]);
    
    // Memory check
    const memoryUsage = process.memoryUsage();
    healthCheck.checks.memory = {
      status: 'healthy',
      heapUsed: Math.round(memoryUsage.heapUsed / 1024 / 1024) + ' MB',
      heapTotal: Math.round(memoryUsage.heapTotal / 1024 / 1024) + ' MB'
    };
    
    res.status(200).json(healthCheck);
    
  } catch (error) {
    healthCheck.status = 'unhealthy';
    healthCheck.checks.database = {
      status: 'error',
      error: error.message
    };
    
    res.status(503).json(healthCheck);
  }
});

async function checkDatabaseHealth() {
  try {
    await db.query('SELECT 1');
    return { status: 'connected', responseTime: Date.now() };
  } catch (error) {
    return { status: 'error', error: error.message };
  }
}
```

## Quick Reference: Common Error Patterns

### Error Pattern Recognition

| Error Pattern | Likely Cause | Quick Fix |
|---------------|--------------|-----------|
| `command not found: nx` | Missing Nx CLI | Use `npx nx` instead |
| `ECONNREFUSED` | Database connection | Check MySQL service status |
| `Heap out of memory` | Build memory limit | Increase Node.js memory |
| `CORS policy blocked` | Wrong origin config | Update CORS origins |
| `Module not found` | Missing dependency | Check package.json |
| `Health check timeout` | Slow startup | Optimize startup process |
| `Invalid token` | JWT secret mismatch | Verify JWT_SECRET |
| `Too many connections` | Connection leak | Implement connection pooling |

### Emergency Procedures

#### Service Down Emergency
```bash
# Quick diagnostics
railway status
railway logs --tail --lines 100

# Restart service
railway service restart

# Rollback deployment
railway deployment rollback

# Check resource usage
railway metrics --time-range 1h
```

#### Database Emergency
```bash
# Check database status
railway service select mysql
railway logs --tail

# Connect to database
railway connect mysql

# Check connection count
SHOW PROCESSLIST;

# Kill long-running queries
KILL <process_id>;
```

---

## Getting Help

### Railway Support Channels
- **Discord**: Railway Community Discord
- **Documentation**: [docs.railway.app](https://docs.railway.app)
- **GitHub**: Railway GitHub Issues
- **Email**: support@railway.app

### Debug Information to Provide
```bash
# Collect debug information
railway status > railway-debug.txt
railway logs --lines 200 >> railway-debug.txt
railway variables list >> railway-debug.txt
railway metrics >> railway-debug.txt
```

---

## Next Steps

1. **[Review Best Practices](./best-practices.md)** - Prevent common issues
2. **[Check Implementation Guide](./implementation-guide.md)** - Proper setup procedures
3. **[Use Template Examples](./template-examples.md)** - Working configurations

---

*Troubleshooting Guide | Railway.com Deployments | January 2025*