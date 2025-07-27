# Railway.com Implementation Guide

This comprehensive guide walks you through implementing a complete application deployment on Railway.com, from initial setup to production deployment.

## Getting Started

### 1. Account Setup and Preparation

#### Create Railway Account
1. Visit [railway.app](https://railway.app) and sign up
2. Choose your subscription plan:
   - **Trial**: Free with $5 credits (good for learning)
   - **Hobby**: $5 minimum (personal projects)
   - **Pro**: $20 minimum (production applications)

#### Install Required Tools
```bash
# Install Railway CLI
npm install -g @railway/cli

# Or using curl
curl -fsSL https://railway.app/install.sh | sh

# Verify installation
railway --version

# Login to Railway
railway login
```

#### Prepare Your Development Environment
```bash
# Install Node.js 18+
node --version

# Install Nx CLI globally
npm install -g nx

# Verify Nx installation
nx --version
```

### 2. Project Initialization

#### Method 1: Create New Nx Workspace
```bash
# Create new Nx workspace
npx create-nx-workspace@latest my-clinic-app

# Choose options:
# - Package-based monorepo
# - React for frontend
# - Express for backend
# - Yes to Nx Cloud (optional)

cd my-clinic-app
```

#### Method 2: Use Existing Nx Project
```bash
# Clone existing project
git clone https://github.com/your-username/existing-nx-project.git
cd existing-nx-project

# Install dependencies
npm install

# Verify project structure
nx graph
```

## Step-by-Step Implementation

### Phase 1: Backend API Setup

#### 1. Create Express.js Backend (if not exists)
```bash
# Generate Express application
nx g @nx/express:app api

# Generate API routes
nx g @nx/express:route patients --project=api
nx g @nx/express:route appointments --project=api
```

#### 2. Configure Backend for Railway

**Update `apps/api/src/main.ts`:**
```typescript
import express from 'express';
import cors from 'cors';
import { json, urlencoded } from 'express';
import mysql from 'mysql2/promise';

const app = express();

// Middleware
app.use(cors({
  origin: process.env.FRONTEND_URL || ['http://localhost:4200'],
  credentials: true
}));

app.use(json({ limit: '10mb' }));
app.use(urlencoded({ extended: true, limit: '10mb' }));

// Health check
app.get('/health', (req, res) => {
  res.json({ 
    status: 'OK', 
    timestamp: new Date().toISOString(),
    environment: process.env.NODE_ENV 
  });
});

// Database connection test
app.get('/db-health', async (req, res) => {
  try {
    const connection = await mysql.createConnection({
      host: process.env.MYSQLHOST,
      port: parseInt(process.env.MYSQLPORT || '3306'),
      user: process.env.MYSQLUSER,
      password: process.env.MYSQLPASSWORD,
      database: process.env.MYSQLDATABASE,
    });
    
    await connection.ping();
    await connection.end();
    
    res.json({ database: 'connected' });
  } catch (error) {
    res.status(500).json({ database: 'disconnected', error: error.message });
  }
});

// API routes
app.use('/api', require('./routes'));

// Error handling
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ error: 'Something went wrong!' });
});

// Start server
const port = process.env.PORT || 3333;
app.listen(port, '0.0.0.0', () => {
  console.log(`API server listening at http://0.0.0.0:${port}/api`);
});
```

#### 3. Create Database Schema

**Create `apps/api/src/database/schema.sql`:**
```sql
-- Clinic Management System Database Schema

CREATE TABLE IF NOT EXISTS patients (
  id INT AUTO_INCREMENT PRIMARY KEY,
  first_name VARCHAR(100) NOT NULL,
  last_name VARCHAR(100) NOT NULL,
  email VARCHAR(255) UNIQUE,
  phone VARCHAR(20),
  date_of_birth DATE,
  address TEXT,
  medical_notes TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS appointments (
  id INT AUTO_INCREMENT PRIMARY KEY,
  patient_id INT NOT NULL,
  appointment_date DATETIME NOT NULL,
  duration_minutes INT DEFAULT 30,
  status ENUM('scheduled', 'completed', 'cancelled', 'no-show') DEFAULT 'scheduled',
  notes TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (patient_id) REFERENCES patients(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS staff (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  role ENUM('doctor', 'nurse', 'admin', 'receptionist') NOT NULL,
  email VARCHAR(255) UNIQUE NOT NULL,
  phone VARCHAR(20),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for better performance
CREATE INDEX idx_patients_email ON patients(email);
CREATE INDEX idx_appointments_date ON appointments(appointment_date);
CREATE INDEX idx_appointments_patient ON appointments(patient_id);
CREATE INDEX idx_staff_email ON staff(email);
```

**Create database initialization script `apps/api/src/database/init.ts`:**
```typescript
import mysql from 'mysql2/promise';
import fs from 'fs';
import path from 'path';

export const initializeDatabase = async () => {
  try {
    const connection = await mysql.createConnection({
      host: process.env.MYSQLHOST,
      port: parseInt(process.env.MYSQLPORT || '3306'),
      user: process.env.MYSQLUSER,
      password: process.env.MYSQLPASSWORD,
      database: process.env.MYSQLDATABASE,
      multipleStatements: true
    });

    // Read and execute schema
    const schemaPath = path.join(__dirname, 'schema.sql');
    const schema = fs.readFileSync(schemaPath, 'utf-8');
    
    await connection.execute(schema);
    console.log('Database schema initialized successfully');
    
    await connection.end();
  } catch (error) {
    console.error('Database initialization failed:', error);
    throw error;
  }
};

// Run initialization if called directly
if (require.main === module) {
  initializeDatabase().catch(console.error);
}
```

#### 4. Deploy Backend to Railway

```bash
# Initialize Railway project
railway init my-clinic-app

# Create backend service
railway service create api

# Deploy backend
cd apps/api
railway up --service api

# Set environment variables
railway variables set NODE_ENV=production --service api
railway variables set PORT=3333 --service api
```

### Phase 2: Database Setup

#### 1. Add MySQL Database
```bash
# Add MySQL to Railway project
railway add mysql

# Get database URL
railway variables
```

#### 2. Initialize Database Schema
```bash
# Run database initialization
railway run --service api npm run db:init

# Or connect directly to run schema
railway connect mysql
# Then paste your schema.sql content
```

#### 3. Verify Database Connection
```bash
# Test database connectivity
curl https://your-api-service.railway.app/db-health
```

### Phase 3: Frontend Setup

#### 1. Create React Frontend (if not exists)
```bash
# Generate React application with Vite
nx g @nx/react:app web --bundler=vite --unitTestRunner=jest --e2eTestRunner=cypress
```

#### 2. Configure Frontend for Railway

**Update `apps/web/vite.config.ts`:**
```typescript
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { nxViteTsPaths } from '@nx/vite/plugins/nx-tsconfig-paths.plugin';

export default defineConfig({
  root: __dirname,
  cacheDir: '../../node_modules/.vite/web',
  
  server: {
    port: 4200,
    host: 'localhost',
  },

  preview: {
    port: 4300,
    host: 'localhost',
  },

  plugins: [react(), nxViteTsPaths()],

  build: {
    outDir: '../../dist/apps/web',
    reportCompressedSize: true,
    commonjsOptions: {
      transformMixedEsModules: true,
    },
  },

  define: {
    'process.env.VITE_API_URL': JSON.stringify(
      process.env.VITE_API_URL || 'http://localhost:3333'
    ),
  },
});
```

**Create API service `apps/web/src/services/api.ts`:**
```typescript
const API_BASE_URL = process.env.VITE_API_URL || 'http://localhost:3333';

class ApiService {
  private baseUrl: string;

  constructor(baseUrl: string = API_BASE_URL) {
    this.baseUrl = baseUrl;
  }

  async request<T>(endpoint: string, options: RequestInit = {}): Promise<T> {
    const url = `${this.baseUrl}${endpoint}`;
    
    const response = await fetch(url, {
      headers: {
        'Content-Type': 'application/json',
        ...options.headers,
      },
      ...options,
    });

    if (!response.ok) {
      throw new Error(`API request failed: ${response.statusText}`);
    }

    return response.json();
  }

  // Patient endpoints
  async getPatients() {
    return this.request<Patient[]>('/api/patients');
  }

  async createPatient(patient: Omit<Patient, 'id'>) {
    return this.request<Patient>('/api/patients', {
      method: 'POST',
      body: JSON.stringify(patient),
    });
  }

  // Appointment endpoints
  async getAppointments() {
    return this.request<Appointment[]>('/api/appointments');
  }

  async createAppointment(appointment: Omit<Appointment, 'id'>) {
    return this.request<Appointment>('/api/appointments', {
      method: 'POST',
      body: JSON.stringify(appointment),
    });
  }
}

export const apiService = new ApiService();

// Type definitions
export interface Patient {
  id: number;
  first_name: string;
  last_name: string;
  email?: string;
  phone?: string;
  date_of_birth?: string;
  address?: string;
  medical_notes?: string;
}

export interface Appointment {
  id: number;
  patient_id: number;
  appointment_date: string;
  duration_minutes: number;
  status: 'scheduled' | 'completed' | 'cancelled' | 'no-show';
  notes?: string;
}
```

#### 3. Deploy Frontend to Railway

```bash
# Create frontend service
railway service create web

# Deploy frontend
cd apps/web
railway up --service web

# Set environment variables
railway variables set VITE_API_URL=https://your-api-service.railway.app --service web
```

### Phase 4: Shared Libraries (Optional)

#### 1. Create Shared Types Library
```bash
# Generate shared types library
nx g @nx/js:lib shared-types

# Create types in libs/shared-types/src/lib/types.ts
```

#### 2. Create Shared Utilities Library
```bash
# Generate shared utilities library
nx g @nx/js:lib shared-utils

# Add common utility functions
```

#### 3. Update Applications to Use Shared Libraries
```typescript
// In both frontend and backend
import { Patient, Appointment } from '@my-clinic-app/shared-types';
import { formatDate, validateEmail } from '@my-clinic-app/shared-utils';
```

## Advanced Configuration

### 1. Environment-Specific Configurations

#### Development Environment
```bash
# Create development environment
railway environment create development

# Deploy to development
railway up --environment development
```

#### Production Environment
```bash
# Production deployment
railway environment create production
railway up --environment production

# Production-specific variables
railway variables set NODE_ENV=production --environment production
railway variables set LOG_LEVEL=error --environment production
```

### 2. Custom Domains Setup

#### Configure Custom Domain
```bash
# Add custom domain to frontend service
railway domain add my-clinic-app.com --service web

# Add custom domain to API service  
railway domain add api.my-clinic-app.com --service api
```

#### Update Environment Variables
```bash
# Update API URL to use custom domain
railway variables set VITE_API_URL=https://api.my-clinic-app.com --service web
railway variables set FRONTEND_URL=https://my-clinic-app.com --service api
```

### 3. SSL/TLS Configuration

Railway automatically provides SSL certificates for all deployed services. No additional configuration required.

### 4. Environment Variables Management

#### Production Variables
```bash
# API service variables
railway variables set NODE_ENV=production --service api
railway variables set PORT=3333 --service api
railway variables set LOG_LEVEL=info --service api
railway variables set JWT_SECRET=your-jwt-secret --service api

# Frontend service variables  
railway variables set VITE_API_URL=https://api.my-clinic-app.com --service web
railway variables set VITE_APP_NAME="Clinic Management System" --service web
```

#### Database Variables (automatically set by Railway)
- `DATABASE_URL`
- `MYSQLHOST`
- `MYSQLPORT`
- `MYSQLUSER`
- `MYSQLPASSWORD`
- `MYSQLDATABASE`

## Monitoring and Maintenance

### 1. Application Monitoring

#### Health Check Endpoints
Ensure your applications have health check endpoints:

```typescript
// Backend health check
app.get('/health', (req, res) => {
  res.json({
    status: 'OK',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    memory: process.memoryUsage(),
    environment: process.env.NODE_ENV
  });
});

// Database health check
app.get('/db-health', async (req, res) => {
  // Database connection test logic
});
```

#### Railway Dashboard Monitoring
- Monitor service status and uptime
- Track resource usage (CPU, memory, storage)
- View application logs in real-time
- Set up alerts for service failures

### 2. Logging and Debugging

#### Structured Logging
```typescript
import winston from 'winston';

const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
  ),
  transports: [
    new winston.transports.Console()
  ]
});

// Use throughout application
logger.info('Patient created', { patientId: 123 });
logger.error('Database error', { error: error.message });
```

#### Viewing Logs
```bash
# View real-time logs
railway logs --service api
railway logs --service web

# Follow logs
railway logs --follow --service api
```

### 3. Database Maintenance

#### Backup Strategy
```bash
# Railway automatically backs up databases
# Manual backup can be triggered
railway db backup

# List backups
railway db backups list

# Restore from backup
railway db backup restore <backup-id>
```

#### Database Performance Monitoring
```sql
-- Monitor database performance
SHOW PROCESSLIST;
SHOW STATUS LIKE 'Threads_connected';
SHOW STATUS LIKE 'Queries';

-- Analyze slow queries
SHOW FULL PROCESSLIST;
```

## Scaling Considerations

### 1. Horizontal Scaling

Railway automatically scales your applications based on demand. For additional control:

#### Load Balancing
- Railway automatically load balances traffic
- No additional configuration required
- Supports multiple regions for global distribution

#### Database Scaling
```sql
-- Optimize database for scaling
CREATE INDEX idx_patients_created_at ON patients(created_at);
CREATE INDEX idx_appointments_date_status ON appointments(appointment_date, status);

-- Implement connection pooling
-- Use read replicas for read-heavy operations
```

### 2. Vertical Scaling

#### Resource Monitoring
```bash
# Monitor resource usage
railway status --service api
railway metrics --service api
```

#### Resource Optimization
```typescript
// Implement efficient database queries
const getRecentPatients = async (limit = 10) => {
  const [rows] = await pool.execute(
    'SELECT * FROM patients ORDER BY created_at DESC LIMIT ?',
    [limit]
  );
  return rows;
};

// Cache frequently accessed data
const cache = new Map();
const getCachedPatient = async (id) => {
  if (cache.has(id)) {
    return cache.get(id);
  }
  
  const patient = await getPatient(id);
  cache.set(id, patient);
  return patient;
};
```

## Security Implementation

### 1. Authentication Setup

#### JWT Authentication
```typescript
import jwt from 'jsonwebtoken';
import bcrypt from 'bcrypt';

// Authentication middleware
const authenticateToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.sendStatus(401);
  }

  jwt.verify(token, process.env.JWT_SECRET, (err, user) => {
    if (err) return res.sendStatus(403);
    req.user = user;
    next();
  });
};

// Login endpoint
app.post('/api/auth/login', async (req, res) => {
  const { email, password } = req.body;
  
  // Validate user credentials
  const user = await getUserByEmail(email);
  if (!user || !await bcrypt.compare(password, user.password)) {
    return res.status(401).json({ error: 'Invalid credentials' });
  }
  
  const token = jwt.sign({ userId: user.id }, process.env.JWT_SECRET);
  res.json({ token, user: { id: user.id, name: user.name, role: user.role } });
});
```

### 2. Data Validation

#### Input Validation
```typescript
import Joi from 'joi';

const patientSchema = Joi.object({
  first_name: Joi.string().required().max(100),
  last_name: Joi.string().required().max(100),
  email: Joi.string().email().optional(),
  phone: Joi.string().pattern(/^[\d\s\-\+\(\)]+$/).optional(),
  date_of_birth: Joi.date().optional(),
  address: Joi.string().max(500).optional()
});

// Validation middleware
const validatePatient = (req, res, next) => {
  const { error } = patientSchema.validate(req.body);
  if (error) {
    return res.status(400).json({ error: error.details[0].message });
  }
  next();
};
```

### 3. Environment Security

#### Environment Variables Security
```bash
# Use Railway's built-in secret management
railway variables set JWT_SECRET=$(openssl rand -base64 32) --service api
railway variables set DATABASE_ENCRYPTION_KEY=$(openssl rand -base64 32) --service api

# Never commit secrets to git
echo ".env*" >> .gitignore
echo "*.key" >> .gitignore
```

## Cost Optimization

### 1. Resource Optimization

#### Database Query Optimization
```typescript
// Use connection pooling
import mysql from 'mysql2/promise';

const pool = mysql.createPool({
  host: process.env.MYSQLHOST,
  port: parseInt(process.env.MYSQLPORT || '3306'),
  user: process.env.MYSQLUSER,
  password: process.env.MYSQLPASSWORD,
  database: process.env.MYSQLDATABASE,
  waitForConnections: true,
  connectionLimit: 5, // Optimize for small clinic usage
  queueLimit: 0
});

// Efficient pagination
const getPatientsPaginated = async (page = 1, limit = 20) => {
  const offset = (page - 1) * limit;
  const [rows] = await pool.execute(
    'SELECT * FROM patients ORDER BY created_at DESC LIMIT ? OFFSET ?',
    [limit, offset]
  );
  return rows;
};
```

#### Frontend Optimization
```typescript
// Implement lazy loading
import { lazy, Suspense } from 'react';

const PatientList = lazy(() => import('./components/PatientList'));
const AppointmentCalendar = lazy(() => import('./components/AppointmentCalendar'));

// Use React Query for efficient data fetching
import { useQuery } from 'react-query';

const usePatients = () => {
  return useQuery('patients', 
    () => apiService.getPatients(),
    {
      staleTime: 5 * 60 * 1000, // 5 minutes
      cacheTime: 10 * 60 * 1000, // 10 minutes
    }
  );
};
```

### 2. Development Environment Management

#### Efficient Development Workflow
```bash
# Use development environment only when needed
railway environment switch development

# Stop development services when not in use
railway service pause web --environment development
railway service pause api --environment development

# Resume when needed
railway service resume web --environment development
railway service resume api --environment development
```

### 3. Monitoring Usage
```bash
# Check current usage
railway usage

# Monitor costs
railway billing

# Set up budget alerts
railway billing alerts set 15 # Alert at $15 usage
```

---

## Next Steps

After successful implementation:

1. **Testing**: Implement comprehensive testing (unit, integration, e2e)
2. **Documentation**: Create user manuals and API documentation
3. **Training**: Train clinic staff on the new system
4. **Monitoring**: Set up comprehensive monitoring and alerting
5. **Maintenance**: Establish regular maintenance and update procedures

---

## References

- [Railway.com Documentation](https://docs.railway.app/)
- [Nx Monorepo Guide](https://nx.dev/getting-started/intro)
- [Express.js Documentation](https://expressjs.com/)
- [React Documentation](https://reactjs.org/)
- [MySQL Documentation](https://dev.mysql.com/doc/)

---

← [Back to Nx Deployment Guide](./nx-deployment-guide.md) | [Next: Best Practices](./best-practices.md) →