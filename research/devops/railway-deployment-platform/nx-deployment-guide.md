# Nx Deployment Guide for Railway.com

## 🎯 Overview

This comprehensive guide focuses specifically on deploying Nx monorepo projects to Railway.com, covering the setup, configuration, and optimization strategies for multi-application deployments with shared libraries.

## 🏗️ Nx Monorepo Architecture for Railway

### Project Structure
```
clinic-management-nx/
├── apps/
│   ├── api/                    # Express.js backend → Railway Service
│   │   ├── src/
│   │   │   ├── main.ts
│   │   │   ├── app/
│   │   │   └── environments/
│   │   ├── project.json
│   │   └── Dockerfile (optional)
│   ├── web/                    # React/Vite frontend → Railway Service
│   │   ├── src/
│   │   │   ├── main.tsx
│   │   │   ├── app/
│   │   │   └── environments/
│   │   ├── index.html
│   │   ├── project.json
│   │   └── vite.config.ts
│   └── admin/                  # Optional admin panel → Railway Service
├── libs/
│   ├── shared/
│   │   ├── api-interfaces/     # Shared TypeScript interfaces
│   │   ├── data-access/        # Database models and services
│   │   ├── ui-components/      # Shared React components
│   │   └── utils/              # Utility functions
├── tools/
├── nx.json
├── package.json
└── railway.json
```

### Railway Service Mapping
```typescript
const railwayServices = {
  'clinic-api': {
    sourceApp: 'apps/api',
    buildCommand: 'nx build api',
    startCommand: 'node dist/apps/api/main.js',
    environment: 'Node.js backend service'
  },
  
  'clinic-web': {
    sourceApp: 'apps/web', 
    buildCommand: 'nx build web',
    startCommand: 'npx serve dist/apps/web -s',
    environment: 'Static site hosting'
  },
  
  'clinic-database': {
    sourceApp: 'none',
    type: 'MySQL managed database',
    environment: 'Managed database service'
  }
};
```

## 🚀 Step-by-Step Deployment Guide

### Step 1: Nx Workspace Setup

#### Create Nx Workspace
```bash
# Create new Nx workspace
npx create-nx-workspace@latest clinic-management --preset=react-express

# OR add to existing workspace
npx nx g @nrwl/express:app api
npx nx g @nrwl/react:app web --bundler=vite
```

#### Configure Shared Libraries
```bash
# Generate shared libraries
npx nx g @nrwl/workspace:lib shared/api-interfaces
npx nx g @nrwl/workspace:lib shared/data-access
npx nx g @nrwl/react:lib shared/ui-components
npx nx g @nrwl/workspace:lib shared/utils

# Generate specific feature libraries
npx nx g @nrwl/workspace:lib patient-management
npx nx g @nrwl/workspace:lib appointment-scheduling
```

### Step 2: Configure Apps for Railway

#### API Application Configuration
```typescript
// apps/api/project.json
{
  "name": "api",
  "sourceRoot": "apps/api/src",
  "projectType": "application",
  "targets": {
    "build": {
      "executor": "@nrwl/node:build",
      "outputs": ["{options.outputPath}"],
      "options": {
        "outputPath": "dist/apps/api",
        "main": "apps/api/src/main.ts",
        "tsConfig": "apps/api/tsconfig.app.json",
        "assets": ["apps/api/src/assets"],
        "buildLibsFromSource": false
      },
      "configurations": {
        "production": {
          "optimization": true,
          "extractLicenses": true,
          "inspect": false,
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
      "executor": "@nrwl/node:serve",
      "options": {
        "buildTarget": "api:build"
      }
    }
  }
}
```

#### Web Application Configuration
```typescript
// apps/web/project.json
{
  "name": "web", 
  "sourceRoot": "apps/web/src",
  "projectType": "application",
  "targets": {
    "build": {
      "executor": "@nrwl/vite:build",
      "outputs": ["{options.outputPath}"],
      "options": {
        "outputPath": "dist/apps/web"
      },
      "configurations": {
        "production": {
          "optimization": true,
          "sourceMap": false,
          "namedChunks": false,
          "extractLicenses": true,
          "vendorChunk": false
        }
      }
    },
    "serve": {
      "executor": "@nrwl/vite:serve",
      "options": {
        "buildTarget": "web:build"
      }
    }
  }
}
```

### Step 3: Environment Configuration

#### Environment Variables Structure
```typescript
// apps/api/src/environments/environment.ts
export const environment = {
  production: false,
  port: process.env.PORT || 3000,
  database: {
    url: process.env.DATABASE_URL || 'mysql://localhost:3306/clinic_dev',
    host: process.env.MYSQLHOST || 'localhost',
    port: parseInt(process.env.MYSQLPORT || '3306'),
    user: process.env.MYSQLUSER || 'root',
    password: process.env.MYSQLPASSWORD || '',
    database: process.env.MYSQLDATABASE || 'clinic_dev'
  },
  jwt: {
    secret: process.env.JWT_SECRET || 'dev-secret',
    expiresIn: '24h'
  },
  cors: {
    origin: process.env.CORS_ORIGIN?.split(',') || ['http://localhost:4200']
  }
};

// apps/api/src/environments/environment.prod.ts
export const environment = {
  production: true,
  port: process.env.PORT || 3000,
  database: {
    url: process.env.DATABASE_URL,
    host: process.env.MYSQLHOST,
    port: parseInt(process.env.MYSQLPORT || '3306'),
    user: process.env.MYSQLUSER,
    password: process.env.MYSQLPASSWORD,
    database: process.env.MYSQLDATABASE
  },
  jwt: {
    secret: process.env.JWT_SECRET,
    expiresIn: '24h'
  },
  cors: {
    origin: process.env.CORS_ORIGIN?.split(',') || []
  }
};
```

#### Web App Environment Configuration
```typescript
// apps/web/src/environments/environment.ts
export const environment = {
  production: false,
  apiUrl: 'http://localhost:3000/api',
  appName: 'Clinic Management System'
};

// apps/web/src/environments/environment.prod.ts
export const environment = {
  production: true,
  apiUrl: import.meta.env.VITE_API_URL || '/api',
  appName: 'Clinic Management System'
};
```

### Step 4: Shared Libraries Implementation

#### API Interfaces Library
```typescript
// libs/shared/api-interfaces/src/lib/patient.interface.ts
export interface Patient {
  id: string;
  firstName: string;
  lastName: string;
  dateOfBirth: Date;
  phone?: string;
  email?: string;
  address?: string;
  createdAt: Date;
  updatedAt: Date;
}

export interface CreatePatientRequest {
  firstName: string;
  lastName: string;
  dateOfBirth: string;
  phone?: string;
  email?: string;
  address?: string;
}

export interface Appointment {
  id: string;
  patientId: string;
  patient?: Patient;
  scheduledAt: Date;
  durationMinutes: number;
  status: 'scheduled' | 'confirmed' | 'in-progress' | 'completed' | 'cancelled';
  notes?: string;
  reasonForVisit?: string;
}

// libs/shared/api-interfaces/src/index.ts
export * from './lib/patient.interface';
export * from './lib/appointment.interface';
export * from './lib/user.interface';
```

#### Data Access Library
```typescript
// libs/shared/data-access/src/lib/api-client.ts
import { environment } from '@clinic/shared/environments';

export class ApiClient {
  private baseUrl: string;
  
  constructor() {
    this.baseUrl = environment.apiUrl;
  }
  
  async get<T>(endpoint: string): Promise<T> {
    const response = await fetch(`${this.baseUrl}${endpoint}`, {
      headers: this.getHeaders()
    });
    
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }
    
    return response.json();
  }
  
  async post<T>(endpoint: string, data: any): Promise<T> {
    const response = await fetch(`${this.baseUrl}${endpoint}`, {
      method: 'POST',
      headers: this.getHeaders(),
      body: JSON.stringify(data)
    });
    
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }
    
    return response.json();
  }
  
  private getHeaders(): HeadersInit {
    const headers: HeadersInit = {
      'Content-Type': 'application/json'
    };
    
    const token = localStorage.getItem('auth_token');
    if (token) {
      headers['Authorization'] = `Bearer ${token}`;
    }
    
    return headers;
  }
}

// Export singleton instance
export const apiClient = new ApiClient();
```

### Step 5: Railway Service Configuration

#### Create Railway Services
```bash
# Install Railway CLI
npm install -g @railway/cli

# Login and initialize project
railway login
railway init clinic-management

# Add database service
railway add mysql

# Create API service
railway service create clinic-api

# Create Web service  
railway service create clinic-web
```

#### Configure API Service
```bash
# Set API service environment variables
railway service clinic-api
railway variables set NODE_ENV=production
railway variables set BUILD_COMMAND="nx build api"
railway variables set START_COMMAND="node dist/apps/api/main.js"
railway variables set PORT=3000

# Database variables are automatically set when you add MySQL service
# MYSQLHOST, MYSQLPORT, MYSQLUSER, MYSQLPASSWORD, MYSQLDATABASE, DATABASE_URL
```

#### Configure Web Service
```bash
# Set Web service environment variables
railway service clinic-web
railway variables set NODE_ENV=production
railway variables set BUILD_COMMAND="nx build web"
railway variables set START_COMMAND="npx serve dist/apps/web -s"
railway variables set VITE_API_URL="https://clinic-api-production.up.railway.app"
```

### Step 6: Build Optimization for Railway

#### Nx Cache Configuration
```json
// nx.json
{
  "extends": "@nrwl/workspace/presets/npm.json",
  "defaultProject": "web",
  "cacheableOperations": ["build", "test", "lint", "e2e"],
  "implicitDependencies": {
    "package.json": {
      "dependencies": "*",
      "devDependencies": "*"
    },
    "tsconfig.base.json": "*",
    "nx.json": "*"
  },
  "targetDefaults": {
    "build": {
      "dependsOn": ["^build"],
      "cache": true
    },
    "test": {
      "cache": true
    }
  },
  "workspaceLayout": {
    "appsDir": "apps",
    "libsDir": "libs"
  }
}
```

#### Package.json Scripts for Railway
```json
{
  "name": "clinic-management",
  "scripts": {
    "build": "nx build",
    "build:api": "nx build api --prod",
    "build:web": "nx build web --prod", 
    "start:api": "node dist/apps/api/main.js",
    "start:web": "npx serve dist/apps/web -s",
    "test": "nx test",
    "lint": "nx lint"
  },
  "dependencies": {
    "@nrwl/node": "^15.0.0",
    "@nrwl/react": "^15.0.0",
    "@nrwl/vite": "^15.0.0",
    "express": "^4.18.0",
    "react": "^18.0.0",
    "react-dom": "^18.0.0"
  },
  "devDependencies": {
    "@nrwl/cli": "^15.0.0",
    "@nrwl/workspace": "^15.0.0",
    "nx": "^15.0.0",
    "typescript": "^4.8.0"
  }
}
```

### Step 7: Inter-Service Communication

#### API Service Setup
```typescript
// apps/api/src/main.ts
import express from 'express';
import cors from 'cors';
import { environment } from './environments/environment';

const app = express();

// CORS configuration for Railway
app.use(cors({
  origin: environment.cors.origin,
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));

app.use(express.json());

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    service: 'clinic-api',
    version: process.env.APP_VERSION || '1.0.0'
  });
});

// API routes
app.use('/api/patients', patientsRouter);
app.use('/api/appointments', appointmentsRouter);
app.use('/api/auth', authRouter);

const port = environment.port;
app.listen(port, () => {
  console.log(`API server running on port ${port}`);
});
```

#### Web App Service Integration
```typescript
// apps/web/src/app/services/patient.service.ts
import { apiClient } from '@clinic/shared/data-access';
import { Patient, CreatePatientRequest } from '@clinic/shared/api-interfaces';

export class PatientService {
  static async getPatients(): Promise<Patient[]> {
    return apiClient.get<Patient[]>('/patients');
  }
  
  static async createPatient(patient: CreatePatientRequest): Promise<Patient> {
    return apiClient.post<Patient>('/patients', patient);
  }
  
  static async getPatient(id: string): Promise<Patient> {
    return apiClient.get<Patient>(`/patients/${id}`);
  }
  
  static async updatePatient(id: string, patient: Partial<Patient>): Promise<Patient> {
    return apiClient.put<Patient>(`/patients/${id}`, patient);
  }
  
  static async deletePatient(id: string): Promise<void> {
    return apiClient.delete(`/patients/${id}`);
  }
}
```

## 🔧 Advanced Nx Features for Railway

### Dependency Graph Optimization
```bash
# Analyze project dependencies
nx graph

# Build only affected projects
nx affected:build --base=main

# Test only affected projects  
nx affected:test --base=main
```

### Shared Library Best Practices
```typescript
// Example: Shared validation library
// libs/shared/validation/src/lib/patient.validation.ts
import { z } from 'zod';

export const createPatientSchema = z.object({
  firstName: z.string().min(1).max(100),
  lastName: z.string().min(1).max(100),
  dateOfBirth: z.string().pipe(z.coerce.date()),
  phone: z.string().optional(),
  email: z.string().email().optional(),
  address: z.string().optional()
});

export const updatePatientSchema = createPatientSchema.partial();

export type CreatePatientInput = z.infer<typeof createPatientSchema>;
export type UpdatePatientInput = z.infer<typeof updatePatientSchema>;
```

### Code Generation with Nx
```bash
# Generate CRUD operations
npx nx g @nrwl/workspace:lib patient-management
npx nx g @nrwl/node:controller patient --project=api
npx nx g @nrwl/react:component patient-list --project=web

# Generate shared utilities
npx nx g @nrwl/workspace:lib shared/date-utils
npx nx g @nrwl/workspace:lib shared/validation
```

## 📊 Performance Optimization

### Build Performance
```typescript
const buildOptimization = {
  // 1. Use buildLibsFromSource: false for production
  production: {
    buildLibsFromSource: false,
    optimization: true,
    sourceMap: false
  },
  
  // 2. Configure Nx cache properly
  cache: {
    cacheableOperations: ['build', 'test', 'lint'],
    implicitDependencies: {
      'package.json': { dependencies: '*', devDependencies: '*' }
    }
  },
  
  // 3. Optimize bundle size
  webpackOptimization: {
    splitChunks: {
      chunks: 'all',
      cacheGroups: {
        vendor: {
          test: /[\\/]node_modules[\\/]/,
          name: 'vendors',
          chunks: 'all'
        }
      }
    }
  }
};
```

### Runtime Performance
```typescript
// Lazy loading with Nx
// apps/web/src/app/app.tsx
import { lazy, Suspense } from 'react';
import { Routes, Route } from 'react-router-dom';

const PatientList = lazy(() => import('./pages/patient-list/patient-list'));
const AppointmentScheduler = lazy(() => import('./pages/appointment-scheduler/appointment-scheduler'));

export function App() {
  return (
    <Suspense fallback={<div>Loading...</div>}>
      <Routes>
        <Route path="/patients" element={<PatientList />} />
        <Route path="/appointments" element={<AppointmentScheduler />} />
      </Routes>
    </Suspense>
  );
}
```

## 🚀 Deployment Automation

### CI/CD Pipeline with GitHub Actions
```yaml
# .github/workflows/railway-deploy.yml
name: Deploy to Railway

on:
  push:
    branches: [main, develop]

env:
  RAILWAY_TOKEN: ${{ secrets.RAILWAY_TOKEN }}

jobs:
  test:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v3
        with:
          fetch-depth: 0
          
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'
          cache: 'npm'
          
      - name: Install dependencies
        run: npm ci
        
      - name: Run affected tests
        run: npx nx affected:test --base=origin/main
        
      - name: Run affected lint
        run: npx nx affected:lint --base=origin/main
        
      - name: Build affected apps
        run: npx nx affected:build --base=origin/main

  deploy-staging:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/develop'
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Install Railway CLI
        run: npm install -g @railway/cli
        
      - name: Deploy API to Staging
        run: railway up --service clinic-api --environment staging
        
      - name: Deploy Web to Staging
        run: railway up --service clinic-web --environment staging

  deploy-production:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Install Railway CLI
        run: npm install -g @railway/cli
        
      - name: Deploy API to Production
        run: railway up --service clinic-api --environment production
        
      - name: Deploy Web to Production 
        run: railway up --service clinic-web --environment production
        
      - name: Run Health Checks
        run: |
          sleep 30
          curl -f https://clinic-api-production.up.railway.app/health
          curl -f https://clinic-web-production.up.railway.app
```

## 📋 Nx Railway Deployment Checklist

### Pre-Deployment Setup
- [ ] Nx workspace configured with proper project structure
- [ ] Shared libraries created and properly configured
- [ ] Environment variables configured for each app
- [ ] Build targets optimized for production
- [ ] Dependencies properly declared in package.json

### Railway Configuration
- [ ] Railway project created and linked to repository
- [ ] Database service added and configured
- [ ] API service created with correct build/start commands
- [ ] Web service created with static hosting configuration
- [ ] Environment variables set for all services
- [ ] Custom domains configured (if needed)

### Inter-Service Communication
- [ ] CORS properly configured for cross-service requests
- [ ] API URLs configured as environment variables
- [ ] Health check endpoints implemented
- [ ] Service discovery working correctly
- [ ] SSL/TLS certificates configured

### Performance Optimization
- [ ] Nx build cache configured
- [ ] Bundle splitting implemented for web app
- [ ] Lazy loading configured for large components
- [ ] Database queries optimized
- [ ] CDN configured for static assets

### Monitoring and Maintenance
- [ ] Structured logging implemented
- [ ] Error tracking configured
- [ ] Performance monitoring set up
- [ ] Backup strategies implemented
- [ ] CI/CD pipeline configured and tested

---

## 🔗 Navigation

- **Previous**: [Best Practices](./best-practices.md)
- **Next**: [Database Hosting](./database-hosting.md)