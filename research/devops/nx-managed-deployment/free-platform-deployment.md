# Free Platform Deployment Guide

## 🎯 Overview

This guide provides comprehensive instructions for deploying full-stack Nx monorepo projects to free managed platforms, ideal for development simulation, prototyping, and testing deployment strategies before moving to production environments.

---

## 🆓 Platform Overview

### Recommended Free Platforms for Nx Development

| Platform | Best For | Free Tier Limits | Full-Stack Support |
|----------|----------|------------------|-------------------|
| **Railway** | Complete development simulation | $5/month credit | ✅ Backend + Database |
| **Vercel** | Frontend deployment excellence | 100GB bandwidth | ⚠️ Serverless functions only |
| **Render** | Heroku alternative | 750 hours/month | ✅ Full Docker support |
| **Netlify** | JAMstack applications | 100GB bandwidth | ⚠️ Edge functions only |
| **Cyclic** | Simple Node.js deployment | Basic tier free | ✅ Node.js + MongoDB |

---

## 🚂 Railway Deployment (Recommended)

### Why Railway for Development?
- **$5 monthly credit** covers full development needs
- **PostgreSQL database included** in free tier
- **Excellent developer experience** with real-time logs
- **GitHub integration** with automatic deployments
- **Docker and Nixpacks support** for flexible deployments

### Step 1: Project Setup

#### Install Railway CLI
```bash
# Install Railway CLI
npm install -g @railway/cli

# Login to Railway
railway login

# Initialize project
railway init
```

#### Configure Nx Build Scripts
Update your `package.json`:
```json
{
  "scripts": {
    "build:frontend": "nx build frontend --configuration=production",
    "build:backend": "nx build backend --configuration=production",
    "start:frontend": "npx serve dist/apps/frontend -s -n -L -p $PORT",
    "start:backend": "node dist/apps/backend/main.js",
    "dev:frontend": "nx serve frontend",
    "dev:backend": "nx serve backend"
  },
  "dependencies": {
    "serve": "^14.2.0"
  }
}
```

### Step 2: Deploy Backend Service

#### Create Railway Service
```bash
# Create new service for backend
railway service create backend

# Link to backend service
railway service link backend
```

#### Configure Backend with railway.toml
Create `railway-backend.toml`:
```toml
[build]
builder = "NIXPACKS"
buildCommand = "npm ci && npm run build:backend"

[deploy]
startCommand = "npm run start:backend"
healthcheckPath = "/health"
healthcheckTimeout = 60
restartPolicyType = "ON_FAILURE"
restartPolicyMaxRetries = 3

[env]
NODE_ENV = "production"
PORT = "8080"

# Nixpacks configuration
[nixpacks]
aptPkgs = []
nixPkgs = ["nodejs-18_x", "npm"]
```

#### Deploy Backend
```bash
# Deploy backend service
railway up --service backend --config railway-backend.toml

# Set environment variables
railway variables set NODE_ENV=production --service backend
railway variables set JWT_SECRET=your-development-jwt-secret --service backend
```

### Step 3: Add Database

#### Create PostgreSQL Database
```bash
# Add PostgreSQL database to your project
railway add postgresql

# Get database URL (automatically set as DATABASE_URL)
railway variables list

# The DATABASE_URL will be automatically available to all services
```

#### Configure Database Connection
Update your backend configuration:
```typescript
// apps/backend/src/database/connection.ts
import { Pool } from 'pg';

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: process.env.NODE_ENV === 'production' ? {
    rejectUnauthorized: false
  } : false,
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000
});

export { pool };
```

### Step 4: Deploy Frontend Service

#### Create Frontend Service
```bash
# Create service for frontend
railway service create frontend

# Switch to frontend service
railway service link frontend
```

#### Configure Frontend with railway.toml
Create `railway-frontend.toml`:
```toml
[build]
builder = "NIXPACKS"
buildCommand = "npm ci && npm run build:frontend"

[deploy]
startCommand = "npm run start:frontend"
healthcheckPath = "/"
healthcheckTimeout = 100
restartPolicyType = "ON_FAILURE"
restartPolicyMaxRetries = 10

[env]
NODE_ENV = "production"
PORT = "3000"

[nixpacks]
aptPkgs = []
nixPkgs = ["nodejs-18_x", "npm"]
```

#### Deploy Frontend
```bash
# Deploy frontend service
railway up --service frontend --config railway-frontend.toml

# Set API URL environment variable
railway variables set VITE_API_URL=https://backend-production-xxxx.up.railway.app --service frontend
```

### Step 5: Environment Configuration

#### Complete Environment Setup
```bash
# Backend environment variables
railway variables set NODE_ENV=production --service backend
railway variables set DATABASE_URL=${{Postgres.DATABASE_URL}} --service backend
railway variables set JWT_SECRET=your-jwt-secret-32-chars-minimum --service backend
railway variables set CORS_ORIGIN=https://frontend-production-xxxx.up.railway.app --service backend

# Frontend environment variables
railway variables set NODE_ENV=production --service frontend  
railway variables set VITE_API_URL=https://backend-production-xxxx.up.railway.app --service frontend
railway variables set VITE_APP_VERSION=1.0.0 --service frontend
```

### Step 6: Monitoring and Logs

#### View Application Logs
```bash
# View backend logs
railway logs --service backend --follow

# View frontend logs
railway logs --service frontend --follow

# View database logs
railway logs --service Postgres --follow
```

#### Monitor Resource Usage
```bash
# Check service status
railway status

# View project dashboard
railway open
```

---

## ▲ Vercel Deployment (Frontend-Focused)

### Best Use Case
- **React/Next.js frontends** with serverless backend needs
- **Static sites** with API routes
- **JAMstack applications** with external databases

### Step 1: Frontend Deployment

#### Install Vercel CLI
```bash
npm install -g vercel
vercel login
```

#### Configure Vercel for Nx
Create `vercel.json` in your project root:
```json
{
  "version": 2,
  "builds": [
    {
      "src": "apps/frontend/package.json",
      "use": "@vercel/static-build",
      "config": {
        "distDir": "../../dist/apps/frontend"
      }
    }
  ],
  "routes": [
    {
      "src": "/(.*)",
      "dest": "/apps/frontend/$1"
    }
  ],
  "env": {
    "VITE_API_URL": "https://your-backend.railway.app"
  },
  "functions": {
    "apps/api/src/main.ts": {
      "runtime": "nodejs18.x"
    }
  }
}
```

#### Prepare Frontend Build
Update `apps/frontend/package.json`:
```json
{
  "scripts": {
    "build": "cd ../.. && nx build frontend --configuration=production",
    "dev": "cd ../.. && nx serve frontend"
  }
}
```

#### Deploy to Vercel
```bash
# Deploy from project root
cd /path/to/your/nx-workspace
vercel

# Follow prompts:
# - Link to existing project or create new
# - Select framework preset: "Other"
# - Set build command: "npm run build:frontend"
# - Set output directory: "dist/apps/frontend"
```

### Step 2: Serverless Functions (Limited Backend)

#### Create API Routes
Create `api/` directory in project root:
```typescript
// api/users.ts - Vercel serverless function
import { VercelRequest, VercelResponse } from '@vercel/node';

export default async function handler(
  req: VercelRequest,
  res: VercelResponse
) {
  // Enable CORS
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  if (req.method === 'GET') {
    // Simple API endpoint
    return res.json({
      users: [
        { id: 1, name: 'John Doe' },
        { id: 2, name: 'Jane Smith' }
      ]
    });
  }

  return res.status(405).json({ error: 'Method not allowed' });
}
```

#### Limitations of Vercel Backend
```yaml
Serverless Function Limitations:
  Execution Time: 10 seconds (Hobby), 60 seconds (Pro)
  Memory Limit: 1024MB
  Package Size: 50MB compressed
  No Persistent Connections: Database connections must be managed carefully
  Cold Starts: Functions may have startup delay

Best For:
  ✅ Simple API endpoints
  ✅ Authentication functions
  ✅ Data processing tasks
  ❌ Complex Express.js applications
  ❌ Real-time applications (WebSockets)
  ❌ Long-running processes
```

---

## 🎨 Render Deployment

### Why Render?
- **Generous free tier** with 750 hours/month
- **Full Docker support** for complex applications
- **PostgreSQL database** available
- **SSL certificates** included
- **GitHub integration** for automatic deployments

### Step 1: Project Configuration

#### Create render.yaml
Create `render.yaml` in your project root:
```yaml
services:
  # Backend Service
  - type: web
    name: nx-backend
    env: node
    plan: free
    buildCommand: npm ci && npm run build:backend
    startCommand: npm run start:backend
    healthCheckPath: /health
    envVars:
      - key: NODE_ENV
        value: production
      - key: PORT
        value: 10000
      - key: DATABASE_URL
        fromDatabase:
          name: nx-database
          property: connectionString

  # Frontend Service  
  - type: web
    name: nx-frontend
    env: static
    plan: free
    buildCommand: npm ci && npm run build:frontend
    staticPublishPath: dist/apps/frontend
    routes:
      - type: rewrite
        source: /*
        destination: /index.html
    envVars:
      - key: NODE_ENV
        value: production
      - key: VITE_API_URL
        value: https://nx-backend.onrender.com

databases:
  - name: nx-database
    databaseName: myapp
    user: myapp_user
    plan: free
```

### Step 2: Deploy via GitHub

#### Connect Repository
1. Sign up at [Render.com](https://render.com)
2. Connect your GitHub account
3. Select your Nx monorepo repository
4. Choose "Web Service" for each application

#### Manual Service Creation
If not using `render.yaml`:

**Backend Service:**
```yaml
Name: nx-backend
Environment: Node
Build Command: npm ci && npm run build:backend
Start Command: npm run start:backend
Auto Deploy: Yes (on main branch pushes)
```

**Frontend Service:**
```yaml
Name: nx-frontend  
Environment: Static Site
Build Command: npm ci && npm run build:frontend
Publish Directory: dist/apps/frontend
Auto Deploy: Yes (on main branch pushes)
```

### Step 3: Database Setup

#### Create PostgreSQL Database
1. In Render dashboard, click "New +"
2. Select "PostgreSQL"
3. Choose "Free" plan
4. Database will be created with connection details

#### Connect Database to Backend
```typescript
// apps/backend/src/database/connection.ts
import { Pool } from 'pg';

// Render provides DATABASE_URL environment variable
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: {
    rejectUnauthorized: false
  }
});

export { pool };
```

### Step 4: Environment Variables

#### Set Environment Variables in Render Dashboard
```yaml
Backend Service Environment Variables:
NODE_ENV: production
DATABASE_URL: [automatically provided by database]
JWT_SECRET: your-jwt-secret-key
CORS_ORIGIN: https://nx-frontend.onrender.com

Frontend Service Environment Variables:
NODE_ENV: production
VITE_API_URL: https://nx-backend.onrender.com
```

---

## 🌐 Netlify Deployment (JAMstack Focus)

### Best Use Case
- **Static site generators** (Gatsby, Next.js static export)
- **JAMstack applications** with serverless functions
- **Frontend-only applications** with external APIs

### Step 1: Static Site Deployment

#### Configure Netlify Build
Create `netlify.toml`:
```toml
[build]
  command = "npm run build:frontend"
  publish = "dist/apps/frontend"

[build.environment]
  NODE_VERSION = "18"
  NPM_VERSION = "9"

[[redirects]]
  from = "/*"
  to = "/index.html"
  status = 200

[[headers]]
  for = "/api/*"
  [headers.values]
    Access-Control-Allow-Origin = "*"
    Access-Control-Allow-Methods = "GET, POST, PUT, DELETE, OPTIONS"
```

#### Deploy via Git Integration
1. Sign up at [Netlify.com](https://netlify.com)
2. Connect GitHub repository
3. Configure build settings:
   - Build command: `npm run build:frontend`
   - Publish directory: `dist/apps/frontend`
   - Node version: 18

### Step 2: Netlify Functions (Edge Functions)

#### Create Netlify Functions
Create `netlify/functions/` directory:
```typescript
// netlify/functions/users.ts
import { Handler } from '@netlify/functions';

export const handler: Handler = async (event, context) => {
  // Enable CORS
  const headers = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS'
  };

  if (event.httpMethod === 'OPTIONS') {
    return {
      statusCode: 200,
      headers,
      body: ''
    };
  }

  if (event.httpMethod === 'GET') {
    return {
      statusCode: 200,
      headers: {
        ...headers,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        users: [
          { id: 1, name: 'John Doe' },
          { id: 2, name: 'Jane Smith' }
        ]
      })
    };
  }

  return {
    statusCode: 405,
    headers,
    body: JSON.stringify({ error: 'Method not allowed' })
  };
};
```

#### Function Limitations
```yaml
Netlify Functions Limitations:
  Runtime: 10 seconds (Edge), 26 seconds (Background)
  Memory: 1024MB
  Payload Size: 6MB
  Concurrent Executions: 1000

Best For:
  ✅ API endpoints
  ✅ Form processing
  ✅ Authentication
  ❌ Complex backend logic
  ❌ Database-heavy operations
  ❌ Real-time features
```

---

## 🔄 Platform Combination Strategies

### Strategy 1: Vercel + Railway
**Best For**: Frontend-heavy applications with traditional backend needs

```yaml
Frontend (Vercel):
  Advantages:
    ✅ Excellent React performance
    ✅ Global CDN
    ✅ Preview deployments
    ✅ Free SSL and custom domains
  
Backend (Railway):
  Advantages:
    ✅ Full Express.js support
    ✅ PostgreSQL database included
    ✅ Real-time logs and monitoring
    ✅ Docker container flexibility

Total Cost: $0-15/month
Setup Complexity: Medium
Maintenance: Low
```

### Strategy 2: Netlify + Railway
**Best For**: JAMstack applications with API requirements

```yaml
Frontend (Netlify):
  Advantages:
    ✅ Excellent static site hosting
    ✅ Form handling built-in
    ✅ Edge functions for simple logic
    ✅ Great CI/CD integration
  
Backend (Railway):
  Advantages:
    ✅ Complete backend capabilities
    ✅ Database management
    ✅ Background job processing
    ✅ File storage and processing

Total Cost: $0-15/month
Setup Complexity: Medium
Maintenance: Low
```

### Strategy 3: All-Railway Setup
**Best For**: Complete development simulation

```yaml
All Services (Railway):
  Advantages:
    ✅ Single platform management
    ✅ Integrated logging and monitoring
    ✅ Simple environment variable sharing
    ✅ Unified billing and resource management
    ✅ Database included
  
  Considerations:
    ⚠️ No global CDN for frontend
    ⚠️ Higher costs as project scales
    ⚠️ Single point of failure

Total Cost: $0-25/month
Setup Complexity: Low
Maintenance: Very Low
```

---

## 📊 Free Tier Monitoring and Optimization

### Resource Usage Monitoring

#### Railway Usage Tracking
```bash
# Check current usage
railway usage

# Monitor costs
railway billing

# View service metrics
railway metrics --service backend
```

#### Optimization Strategies
```yaml
Memory Optimization:
  ✅ Use production builds (smaller bundle sizes)
  ✅ Implement proper caching strategies
  ✅ Optimize database queries
  ✅ Use compression middleware

Build Time Optimization:
  ✅ Use npm ci instead of npm install
  ✅ Implement build caching
  ✅ Minimize build dependencies
  ✅ Use multi-stage Docker builds (if needed)

Cost Management:
  ✅ Monitor daily usage in dashboards
  ✅ Set up usage alerts
  ✅ Scale down unused services
  ✅ Use efficient database queries
```

### Performance Monitoring

#### Simple Monitoring Setup
```typescript
// apps/backend/src/middleware/monitoring.ts
export const simpleMonitoring = (req: Request, res: Response, next: NextFunction) => {
  const start = Date.now();
  
  res.on('finish', () => {
    const duration = Date.now() - start;
    
    // Log slow requests
    if (duration > 1000) {
      console.warn(`Slow request: ${req.method} ${req.url} - ${duration}ms`);
    }
    
    // Log errors
    if (res.statusCode >= 400) {
      console.error(`Error response: ${req.method} ${req.url} - ${res.statusCode}`);
    }
  });
  
  next();
};

// Usage
app.use(simpleMonitoring);
```

---

## 🔧 Migration Path to Production

### Development to Production Migration

#### Phase 1: Development (Free Platforms)
- Use Railway free tier for complete development
- Test all features and deployment processes
- Validate application architecture
- Document configuration and environment variables

#### Phase 2: Staging (Paid Free Platforms)
- Upgrade to paid Railway tier for realistic testing
- Implement CI/CD pipelines
- Performance testing with production-like data
- Client demonstration and feedback

#### Phase 3: Production (Digital Ocean)
- Transfer configurations to Digital Ocean App Platform
- Migrate database with proper backup procedures
- Setup monitoring, alerting, and logging
- Client handover and documentation

#### Migration Checklist
```yaml
Pre-Migration:
  - [ ] Document all environment variables
  - [ ] Export database schema and data
  - [ ] Test application with production build locally
  - [ ] Prepare migration scripts

During Migration:
  - [ ] Create new production environment
  - [ ] Import database and run migrations
  - [ ] Deploy applications with production configurations
  - [ ] Update DNS and domain settings
  - [ ] Verify all integrations working

Post-Migration:
  - [ ] Monitor application performance
  - [ ] Verify all features working as expected
  - [ ] Update documentation for new environment
  - [ ] Set up monitoring and alerting
  - [ ] Client training on new platform (if applicable)
```

---

## 📈 Scaling Considerations

### When to Upgrade from Free Tiers

#### Railway Upgrade Triggers
```yaml
Upgrade When:
  Monthly usage consistently exceeds $5
  Need more than 512MB RAM per service
  Require dedicated CPU resources
  Need advanced monitoring features
  Want priority support

Cost After Upgrade:
  Usage-based pricing: ~$10-25/month typical
  Professional features included
  No resource limits within reason
```

#### Vercel Upgrade Triggers
```yaml
Upgrade When:
  Bandwidth exceeds 100GB/month
  Need longer function execution times
  Require team collaboration features
  Want advanced analytics
  Need priority support

Cost After Upgrade:
  Pro plan: $20/month per user
  Team plan: $40/month per user
  Enterprise features available
```

### Performance Optimization for Free Tiers

#### Database Optimization
```sql
-- Create indexes for frequently queried columns
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_posts_user_id ON posts(user_id);
CREATE INDEX idx_posts_created_at ON posts(created_at);

-- Optimize queries to reduce database load
SELECT id, name, email FROM users WHERE active = true LIMIT 10;
-- Instead of: SELECT * FROM users;
```

#### Frontend Optimization
```typescript
// Implement code splitting and lazy loading
import { lazy, Suspense } from 'react';

const Dashboard = lazy(() => import('./Dashboard'));
const Profile = lazy(() => import('./Profile'));

function App() {
  return (
    <Suspense fallback={<div>Loading...</div>}>
      <Routes>
        <Route path="/dashboard" element={<Dashboard />} />
        <Route path="/profile" element={<Profile />} />
      </Routes>
    </Suspense>
  );
}
```

---

## ✅ Free Platform Deployment Checklist

### Pre-Deployment
- [ ] Choose appropriate platform(s) based on application needs
- [ ] Configure build scripts for production
- [ ] Set up environment variables
- [ ] Test application locally with production builds
- [ ] Prepare database migration scripts (if applicable)

### During Deployment
- [ ] Deploy backend service first
- [ ] Configure database and run migrations
- [ ] Deploy frontend service
- [ ] Configure environment variables and service connections
- [ ] Test API endpoints and frontend functionality

### Post-Deployment
- [ ] Verify all features working correctly
- [ ] Monitor resource usage and costs
- [ ] Set up basic monitoring and logging
- [ ] Document deployment process and configurations
- [ ] Plan migration strategy to production platform

---

## 📚 Next Steps

After successful free platform deployment:
- **[Comparison Analysis](./comparison-analysis.md)** - Compare with production platforms
- **[Digital Ocean Deployment](./digital-ocean-deployment.md)** - Migration to production
- **[Best Practices](./best-practices.md)** - Production-ready optimization strategies

---

*This free platform deployment guide provides comprehensive strategies for cost-effective Nx monorepo development and testing. Use these platforms to validate your deployment process before moving to production environments.*