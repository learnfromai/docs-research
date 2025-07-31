# Implementation Guide: Railway.com Deployment

## 🎯 Overview

This guide provides step-by-step instructions for deploying applications to Railway.com, with specific focus on Nx monorepo projects and full-stack applications.

## 🚀 Getting Started with Railway

### 1. Account Setup

```bash
# Install Railway CLI
npm install -g @railway/cli

# Login to Railway
railway login

# Verify login
railway whoami
```

**Web Dashboard Setup:**
1. Visit [railway.app](https://railway.app)
2. Sign up with GitHub, Google, or email
3. Connect your GitHub repositories
4. Choose your subscription plan

### 2. Project Initialization

```bash
# Initialize Railway project in existing repo
railway init

# Or create new project from template
railway new
```

### 3. Environment Configuration

```bash
# Set environment variables
railway variables set NODE_ENV=production
railway variables set DATABASE_URL=${{Postgres.DATABASE_URL}}

# View all variables
railway variables
```

## 🏗 Nx Monorepo Deployment

### Project Structure Example

```
my-nx-workspace/
├── apps/
│   ├── web/                 # React/Vite frontend
│   └── api/                 # Express.js backend
├── libs/
│   └── shared/              # Shared libraries
├── tools/
├── nx.json
├── package.json
└── railway.toml             # Railway configuration
```

### 1. Railway Configuration File

Create `railway.toml` in your project root:

```toml
[build]
builder = "nixpacks"

[deploy]
numReplicas = 1
restartPolicyType = "ON_FAILURE"
restartPolicyMaxRetries = 10
```

### 2. Frontend Deployment (React/Vite)

**Service Configuration:**
```toml
# apps/web/railway.toml
[build]
builder = "nixpacks"
buildCommand = "nx build web"

[deploy]
startCommand = "npx serve dist/apps/web -s -p $PORT"
```

**Environment Variables:**
```bash
# Set for web service
railway variables set VITE_API_URL=${{api.RAILWAY_PUBLIC_DOMAIN}}
railway variables set PORT=3000
```

**Deployment Steps:**
```bash
# Create frontend service
railway service create web

# Deploy frontend
railway up --service web
```

### 3. Backend Deployment (Express.js)

**Service Configuration:**
```toml
# apps/api/railway.toml
[build]
builder = "nixpacks" 
buildCommand = "nx build api"

[deploy]
startCommand = "node dist/apps/api/main.js"
```

**Environment Variables:**
```bash
# Set for API service
railway variables set NODE_ENV=production
railway variables set PORT=8080
railway variables set DATABASE_URL=${{MySQL.DATABASE_URL}}
railway variables set CORS_ORIGIN=${{web.RAILWAY_PUBLIC_DOMAIN}}
```

**Deployment Steps:**
```bash
# Create backend service
railway service create api

# Deploy backend
railway up --service api
```

### 4. Database Setup

**MySQL Database:**
```bash
# Create MySQL service
railway service create mysql

# Get connection details
railway variables get DATABASE_URL --service mysql
```

**Connection String Format:**
```
mysql://username:password@host:port/database
```

**Environment Integration:**
```bash
# Reference in other services
railway variables set DATABASE_URL=${{MySQL.DATABASE_URL}} --service api
```

## 🔧 Advanced Configuration

### 1. Custom Build Process

**Multi-stage Docker Approach:**
```dockerfile
# Dockerfile.web
FROM node:18-alpine AS builder

WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

COPY . .
RUN npx nx build web

FROM nginx:alpine
COPY --from=builder /app/dist/apps/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

**Railway Service Config:**
```toml
[build]
builder = "dockerfile"
dockerfilePath = "Dockerfile.web"

[deploy]
numReplicas = 1
```

### 2. Environment-Specific Deployments

**Staging Environment:**
```bash
# Create staging project
railway project create clinic-staging

# Deploy with staging configs
railway variables set NODE_ENV=staging
railway variables set DATABASE_URL=${{MySQL-Staging.DATABASE_URL}}
```

**Production Environment:**
```bash
# Create production project  
railway project create clinic-production

# Deploy with production configs
railway variables set NODE_ENV=production
railway variables set DATABASE_URL=${{MySQL-Prod.DATABASE_URL}}
```

### 3. Custom Domains

```bash
# Add custom domain
railway domain add yourdomain.com

# View domain status
railway domain list

# Generate SSL certificate (automatic)
# Railway handles SSL/TLS automatically
```

## 📊 Monitoring & Observability

### 1. Logging

```bash
# View real-time logs
railway logs --service api

# Follow logs with filtering
railway logs --service web --follow
```

**Application Logging Best Practices:**
```javascript
// Use structured logging
const winston = require('winston');

const logger = winston.createLogger({
  level: 'info',
  format: winston.format.json(),
  transports: [
    new winston.transports.Console()
  ]
});

// Log with context
logger.info('User authentication', { 
  userId: user.id, 
  timestamp: new Date().toISOString() 
});
```

### 2. Metrics Monitoring

```bash
# View service metrics
railway metrics --service api

# Monitor resource usage
railway service status
```

### 3. Health Checks

**Express.js Health Endpoint:**
```javascript
// apps/api/src/health.js
app.get('/health', async (req, res) => {
  try {
    // Check database connection
    await db.ping();
    
    res.status(200).json({
      status: 'healthy',
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
      memory: process.memoryUsage()
    });
  } catch (error) {
    res.status(503).json({
      status: 'unhealthy',
      error: error.message
    });
  }
});
```

**Railway Health Check Config:**
```toml
[deploy]
healthcheckPath = "/health"
healthcheckTimeout = 300
```

## 🔄 CI/CD Integration

### 1. GitHub Actions Workflow

```yaml
# .github/workflows/deploy.yml
name: Deploy to Railway

on:
  push:
    branches: [main]

jobs:
  deploy:
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
        run: npm run test
        
      - name: Deploy to Railway
        uses: railway/cli-action@v1
        with:
          token: ${{ secrets.RAILWAY_TOKEN }}
          command: up --service api
```

### 2. Automated Database Migrations

```javascript
// apps/api/src/migrate.js
const mysql = require('mysql2/promise');

async function runMigrations() {
  const connection = await mysql.createConnection(process.env.DATABASE_URL);
  
  // Run migration scripts
  await connection.execute(`
    CREATE TABLE IF NOT EXISTS users (
      id INT AUTO_INCREMENT PRIMARY KEY,
      email VARCHAR(255) UNIQUE NOT NULL,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  `);
  
  await connection.end();
}

// Run migrations on deployment
if (process.env.NODE_ENV === 'production') {
  runMigrations().catch(console.error);
}
```

### 3. Deployment Hooks

```toml
# railway.toml
[build]
buildCommand = "nx build api && npm run migrate"

[deploy]
startCommand = "node dist/apps/api/main.js"
```

## 🛠 Troubleshooting Common Issues

### 1. Build Failures

**Nx Build Issues:**
```bash
# Clear Nx cache
nx reset

# Verbose build output
nx build api --verbose

# Check build logs on Railway
railway logs --service api --deployment <deployment-id>
```

### 2. Environment Variable Issues

```bash
# Debug environment variables
railway shell --service api
echo $DATABASE_URL
```

### 3. Port Configuration

**Ensure correct port binding:**
```javascript
// apps/api/src/main.js
const PORT = process.env.PORT || 3000;

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server running on port ${PORT}`);
});
```

### 4. Database Connection Issues

**Connection debugging:**
```javascript
const mysql = require('mysql2/promise');

async function testConnection() {
  try {
    const connection = await mysql.createConnection(process.env.DATABASE_URL);
    console.log('Database connected successfully');
    await connection.end();
  } catch (error) {
    console.error('Database connection failed:', error.message);
  }
}
```

## 📋 Deployment Checklist

### Pre-Deployment
- [ ] Railway CLI installed and authenticated
- [ ] Environment variables configured
- [ ] Database service created and configured
- [ ] Health checks implemented
- [ ] Error handling and logging added

### Deployment
- [ ] Services created (web, api, database)
- [ ] Build commands configured
- [ ] Start commands verified
- [ ] Inter-service communication tested
- [ ] Custom domains configured (if needed)

### Post-Deployment
- [ ] Application functionality verified
- [ ] Performance metrics monitored
- [ ] Error rates checked
- [ ] Database connectivity confirmed
- [ ] SSL certificates verified

---

## 🔗 Navigation

**← Previous:** [Executive Summary](./executive-summary.md) | **Next:** [Nx Monorepo Deployment](./nx-monorepo-deployment.md) →

---

## 📚 Additional Resources

- [Railway CLI Documentation](https://docs.railway.app/cli/reference)
- [Nixpacks Build System](https://nixpacks.com/)
- [Railway Templates](https://railway.app/templates)
- [Nx Deployment Guides](https://nx.dev/recipes/deployment)