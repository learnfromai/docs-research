# Deployment Guide: Railway.com Configuration for Nx Applications

## 🚄 Railway.com Platform Overview

Railway is a modern cloud platform designed for developers, offering seamless deployment with minimal configuration. For Nx React/Express applications, Railway provides excellent support through its nixpacks build system and integrated PostgreSQL/MySQL databases.

## 🎯 Deployment Architecture

### Unified Deployment Architecture
```
┌─────────────────────────────────────────┐
│             Railway Service             │
├─────────────────────────────────────────┤
│  Express.js Server (Port 3000)         │
│  ├── API Routes (/api/*)               │
│  ├── Static Assets (React Build)       │
│  └── SPA Fallback (index.html)         │
├─────────────────────────────────────────┤
│  Railway PostgreSQL Database           │
│  ├── Connection Pooling                │
│  └── Automatic Backups                 │
└─────────────────────────────────────────┘
```

### Separate Deployment Architecture
```
┌───────────────────────┐    ┌──────────────────────┐
│   Railway Static      │    │  Railway Web Service │
│   ────────────────    │    │  ─────────────────── │
│   React App (Vite)    │    │  Express.js API      │
│   Service Worker      │◄───┤  CORS Enabled        │
│   PWA Manifest        │    │  Database Connected  │
└───────────────────────┘    └──────────────────────┘
```

## 🔧 Railway Project Setup

### Step 1: Railway CLI Installation and Authentication

```bash
# Install Railway CLI
npm install -g @railway/cli

# Alternative: Using curl
curl -fsSL https://railway.app/install.sh | sh

# Login to Railway
railway login

# Verify authentication
railway whoami
```

### Step 2: Project Initialization

#### Option A: New Railway Project
```bash
# Create new project
railway new clinic-management-nx

# Initialize in existing directory
cd your-nx-workspace
railway init

# Link to existing project
railway link [project-id]
```

#### Option B: GitHub Integration (Recommended)
1. Push your Nx workspace to GitHub
2. Visit [railway.app](https://railway.app)
3. Connect GitHub repository
4. Select your Nx monorepo
5. Configure build settings in Railway dashboard

## 🏗️ Build Configuration

### Unified Deployment Setup

#### Railway Configuration (`railway.toml`)
```toml
[build]
builder = "nixpacks"
buildCommand = "npm run build:production"

[deploy]
numReplicas = 1
restartPolicyType = "always"
restartPolicyMaxRetries = 3
startCommand = "npm run start:production"

[services.clinic-management]
tcpProxies = []

[services.clinic-management.healthcheck]
path = "/health"
port = 3000

[services.clinic-management.variables]
NODE_ENV = "production"
PORT = "3000"
```

#### Package.json Scripts
```json
{
  "scripts": {
    "build:frontend": "nx build frontend --configuration=production",
    "build:backend": "nx build backend --configuration=production", 
    "build:production": "npm run build:frontend && npm run build:backend",
    "start:production": "node dist/apps/backend/main.js",
    "railway:dev": "railway run npm run dev",
    "railway:build": "railway run npm run build:production"
  }
}
```

#### Nixpacks Configuration (`nixpacks.toml`)
```toml
[phases.build]
cmds = [
  "npm ci",
  "npm run build:production"
]

[phases.start]
cmd = "npm run start:production"

[variables]
NODE_ENV = "production"
NPM_CONFIG_PRODUCTION = "false"  # Keep devDependencies for build
```

### Separate Deployment Setup

#### Frontend Service Configuration
Create `apps/frontend/railway.toml`:
```toml
[build]
builder = "nixpacks"
buildCommand = "nx build frontend --configuration=production"

[deploy]
staticPublishPath = "dist/apps/frontend"

[services.clinic-frontend]
variables.NODE_ENV = "production"
variables.VITE_API_URL = "${{clinic-backend.RAILWAY_PUBLIC_DOMAIN}}"
```

#### Backend Service Configuration  
Create `apps/backend/railway.toml`:
```toml
[build]
builder = "nixpacks"
buildCommand = "nx build backend --configuration=production"

[deploy]
startCommand = "node dist/apps/backend/main.js"

[services.clinic-backend]
variables.NODE_ENV = "production"
variables.PORT = "3000"
variables.FRONTEND_URL = "${{clinic-frontend.RAILWAY_PUBLIC_DOMAIN}}"
```

## 🗄️ Database Configuration

### PostgreSQL Setup (Recommended)

#### Railway Database Service
```bash
# Add PostgreSQL to your project
railway add postgresql

# Get database URL
railway variables get DATABASE_URL

# Connect to database
railway connect postgresql
```

#### Database Connection Configuration
```typescript
// libs/database/src/connection.ts
import { Pool } from 'pg';

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false,
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});

export default pool;
```

#### Environment Variables Setup
```bash
# Set in Railway dashboard or via CLI
railway variables set DATABASE_URL="postgresql://..."
railway variables set JWT_SECRET="your-secret-key"
railway variables set CLINIC_NAME="Your Clinic Name"
railway variables set ADMIN_EMAIL="admin@clinic.com"
```

### MySQL Alternative Setup
```bash
# Add MySQL plugin
railway add mysql

# Configuration for MySQL
railway variables set MYSQL_URL="mysql://..."
```

## 🔒 Environment Configuration

### Production Environment Variables

#### Unified Deployment Variables
```bash
# Core application
railway variables set NODE_ENV=production
railway variables set PORT=3000
railway variables set APP_NAME="Clinic Management System"

# Database
railway variables set DATABASE_URL="postgresql://..."
railway variables set DB_POOL_MAX=20
railway variables set DB_POOL_MIN=5

# Authentication
railway variables set JWT_SECRET="your-256-bit-secret"
railway variables set JWT_EXPIRE="7d"
railway variables set SESSION_SECRET="your-session-secret"

# API Configuration
railway variables set API_RATE_LIMIT=1000
railway variables set CORS_ORIGIN="https://your-domain.railway.app"

# PWA Configuration
railway variables set PWA_SHORT_NAME="ClinicMS"
railway variables set PWA_THEME_COLOR="#2196f3"
```

#### Separate Deployment Variables

**Frontend Service:**
```bash
railway variables set VITE_API_URL="https://clinic-backend.railway.app"
railway variables set VITE_APP_NAME="Clinic Management System"
railway variables set VITE_PWA_ENABLED=true
```

**Backend Service:**
```bash
railway variables set NODE_ENV=production
railway variables set DATABASE_URL="postgresql://..."
railway variables set FRONTEND_URL="https://clinic-frontend.railway.app"
railway variables set CORS_ORIGIN="https://clinic-frontend.railway.app"
```

## 🚀 Deployment Process

### Manual Deployment

#### Unified Deployment
```bash
# Ensure you're in project root
cd your-nx-workspace

# Build and deploy
railway up

# Monitor deployment
railway logs

# Check service status
railway status
```

#### Separate Deployment
```bash
# Deploy backend first
cd apps/backend
railway up --service clinic-backend

# Deploy frontend
cd ../frontend  
railway up --service clinic-frontend

# Verify both services
railway status --service clinic-backend
railway status --service clinic-frontend
```

### Automated Deployment (GitHub Actions)

#### Unified Deployment Pipeline
```yaml
# .github/workflows/deploy-railway.yml
name: Deploy to Railway

on:
  push:
    branches: [main, production]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v3

      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Run tests
        run: npm run test:ci

      - name: Build application
        run: npm run build:production

      - name: Deploy to Railway
        uses: railway/action@v1
        with:
          token: ${{ secrets.RAILWAY_TOKEN }}
          service: clinic-management
```

#### Separate Deployment Pipeline
```yaml
name: Deploy Frontend and Backend

on:
  push:
    branches: [main]

jobs:
  deploy-backend:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Deploy Backend
        uses: railway/action@v1
        with:
          token: ${{ secrets.RAILWAY_TOKEN }}
          service: clinic-backend
          
  deploy-frontend:
    runs-on: ubuntu-latest
    needs: deploy-backend
    steps:
      - uses: actions/checkout@v3
      - name: Deploy Frontend
        uses: railway/action@v1
        with:
          token: ${{ secrets.RAILWAY_TOKEN }}
          service: clinic-frontend
```

## 📊 Railway Dashboard Configuration

### Service Settings

#### Compute Resources
```
Memory Limit:     512MB - 1GB (adjust based on clinic size)
CPU Limit:        0.5 vCPU - 1 vCPU
Disk Storage:     1GB - 5GB
```

#### Networking
```
Custom Domain:    clinic-management.yourdomain.com
SSL Certificate:  Automatic (Let's Encrypt)
IPv6 Support:     Enabled
```

#### Health Checks
```typescript
// Add to Express app
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    version: process.env.npm_package_version,
    environment: process.env.NODE_ENV,
    database: 'connected', // Add DB health check
    memory: process.memoryUsage(),
    uptime: process.uptime()
  });
});
```

### Monitoring Configuration

#### Log Management
```bash
# View real-time logs
railway logs --tail

# Search logs
railway logs --search "ERROR"

# Export logs
railway logs --since 1h > clinic-logs.txt
```

#### Metrics Dashboard
Access via Railway dashboard:
- CPU and Memory usage
- Request rate and response times
- Error rates and status codes
- Database connection metrics

## 🔧 Troubleshooting Common Issues

### Build Failures

#### Nx Build Issues
```bash
# Clear Nx cache
npx nx reset

# Verbose build output
npx nx build backend --verbose

# Check build command in railway.toml
cat railway.toml
```

#### Memory Issues During Build
```toml
# Increase build memory in railway.toml
[build]
builder = "nixpacks"
buildCommand = "NODE_OPTIONS='--max-old-space-size=4096' npm run build:production"
```

### Runtime Issues

#### Port Configuration
```typescript
// Ensure Express uses Railway's PORT
const port = process.env.PORT || 3000;
app.listen(port, '0.0.0.0', () => {
  console.log(`Server running on port ${port}`);
});
```

#### Database Connection Issues
```typescript
// Add connection retry logic
const connectWithRetry = () => {
  return pool.connect()
    .catch(err => {
      console.error('Database connection failed, retrying in 5s...', err);
      setTimeout(connectWithRetry, 5000);
    });
};
```

### CORS Issues (Separate Deployment)
```typescript
// Dynamic CORS configuration
const allowedOrigins = [
  process.env.FRONTEND_URL,
  /^https:\/\/.*\.railway\.app$/,
  ...(process.env.NODE_ENV === 'development' ? ['http://localhost:4200'] : [])
];

app.use(cors({
  origin: allowedOrigins,
  credentials: true
}));
```

## 📋 Deployment Checklist

### Pre-Deployment
- [ ] Nx workspace builds successfully locally
- [ ] Environment variables configured
- [ ] Database schema migrated
- [ ] Tests passing
- [ ] Railway CLI authenticated

### Deployment Setup
- [ ] Railway project created
- [ ] Build commands configured
- [ ] Environment variables set
- [ ] Health check endpoint implemented
- [ ] Custom domain configured (optional)

### Post-Deployment Verification
- [ ] Application accessible via Railway URL
- [ ] Database connectivity verified
- [ ] API endpoints responding correctly
- [ ] PWA installation working
- [ ] Monitoring and logging active

### Production Hardening
- [ ] HTTPS enforced
- [ ] Security headers configured
- [ ] Rate limiting implemented
- [ ] Backup procedures documented
- [ ] Error monitoring active

## 💰 Cost Optimization

### Railway Pricing Considerations
```
Starter Plan:     $5/month per service
- 512MB RAM, 1 vCPU
- 1GB storage
- Suitable for clinic size

Pro Plan:         $20/month per service  
- 8GB RAM, 8 vCPU
- 100GB storage
- For larger clinics/multiple locations
```

### Cost-Effective Strategies
1. **Use Unified Deployment** - Single service reduces costs
2. **Optimize Bundle Size** - Faster builds, less resource usage
3. **Implement Efficient Caching** - Reduce database queries
4. **Monitor Resource Usage** - Scale appropriately

## 🔗 Navigation

- **Previous**: [Performance Analysis](./performance-analysis.md) - PWA optimization strategies
- **Next**: [Best Practices](./best-practices.md) - Production recommendations
- **Related**: [Implementation Guide](./implementation-guide.md) - Code configuration details

---

*Comprehensive Railway.com deployment guide optimized for Nx monorepos in healthcare environments.*