# Deployment Guide: Railway Configuration & Setup

## 🎯 Overview

This guide provides detailed Railway.com platform-specific configuration for deploying Nx React/Express applications, with focus on the recommended single deployment strategy for clinic management PWA systems.

## 🚀 Railway Platform Setup

### Step 1: Railway Account and Project Creation

#### 1.1 Create Railway Account
```bash
# Visit https://railway.app and sign up
# Connect your GitHub account for seamless deployments
# Choose the Hobby plan ($5/month) for small clinic applications
```

#### 1.2 Install Railway CLI
```bash
# Install Railway CLI globally
npm install -g @railway/cli

# Verify installation
railway --version

# Login to Railway
railway login
```

#### 1.3 Initialize Railway Project
```bash
# From your Nx project root
cd clinic-management-system

# Initialize Railway project
railway init

# Choose "Deploy from GitHub repo" for automated deployments
# Select your repository and branch
```

### Step 2: Railway Service Configuration

#### 2.1 Create Main Application Service

```bash
# Create new service for the combined app
railway service create clinic-app

# Link service to current directory
railway link
```

#### 2.2 Configure Build and Deploy Settings

**Via Railway Dashboard:**
1. Go to your project dashboard
2. Click on your service
3. Navigate to "Settings" tab
4. Configure the following:

**Build Settings:**
- **Builder**: Nixpacks (auto-detected)
- **Build Command**: `npm ci && npm run build:prod`
- **Watch Paths**: `apps/**, libs/**, package.json, nx.json`

**Deploy Settings:**
- **Start Command**: `npm run start:prod`
- **Health Check Path**: `/api/health`
- **Health Check Timeout**: 300 seconds
- **Restart Policy**: ON_FAILURE
- **Max Retries**: 3

#### 2.3 Environment Variables Configuration

```bash
# Core application settings
railway variables set NODE_ENV=production
railway variables set PORT=3000
railway variables set LOG_LEVEL=info

# Application URLs
railway variables set APP_URL=https://clinic-app.up.railway.app
railway variables set API_BASE_URL=https://clinic-app.up.railway.app/api

# Security configuration
railway variables set JWT_SECRET=$(openssl rand -base64 32)
railway variables set ENCRYPTION_KEY=$(openssl rand -base64 32)
railway variables set SESSION_SECRET=$(openssl rand -base64 32)

# PWA configuration
railway variables set VAPID_PUBLIC_KEY=your_vapid_public_key
railway variables set VAPID_PRIVATE_KEY=your_vapid_private_key
```

### Step 3: Database Setup

#### 3.1 Add PostgreSQL Database

```bash
# Add PostgreSQL plugin to your Railway project
railway add postgresql

# Verify database creation
railway variables | grep DATABASE_URL
```

**Database will be automatically provisioned with:**
- **Instance**: Shared PostgreSQL instance
- **Storage**: 1GB included (expandable)
- **Connections**: Up to 20 concurrent connections
- **Backup**: Automatic daily backups

#### 3.2 Database Configuration

```bash
# Set additional database variables
railway variables set DB_POOL_MIN=2
railway variables set DB_POOL_MAX=20
railway variables set DB_TIMEOUT=30000

# SSL configuration for production
railway variables set DB_SSL=true
```

#### 3.3 Run Database Migrations

```bash
# Create migration script in package.json
{
  "scripts": {
    "db:migrate": "npx prisma migrate deploy",
    "db:seed": "npx prisma db seed",
    "railway:release": "npm run db:migrate && npm run db:seed"
  }
}

# Set release command in Railway
railway variables set RAILWAY_RELEASE_COMMAND="npm run railway:release"
```

### Step 4: Custom Domain Setup (Optional)

#### 4.1 Configure Custom Domain

```bash
# Add custom domain via CLI
railway domain add yourdomain.com

# Or add subdomain
railway domain add clinic.yourdomain.com
```

#### 4.2 SSL Certificate Configuration

Railway automatically provides SSL certificates for custom domains. No additional configuration required.

**DNS Configuration:**
1. Add CNAME record pointing to your Railway app domain
2. Wait for DNS propagation (5-30 minutes)
3. SSL certificate will be automatically provisioned

### Step 5: Monitoring and Logging Setup

#### 5.1 Enable Railway Observability

**Built-in Features:**
- **Metrics Dashboard**: CPU, Memory, Network usage
- **Deployment Logs**: Build and deployment information
- **Application Logs**: Runtime logs and errors
- **Health Checks**: Automated service health monitoring

#### 5.2 Configure Log Drains (Optional)

```bash
# Add external log management (e.g., Datadog)
railway logs drain add datadog --token YOUR_DATADOG_TOKEN

# Or add webhook for custom log processing
railway logs drain add webhook --url https://your-log-processor.com/webhook
```

### Step 6: Production Deployment

#### 6.1 Automated Deployment Setup

**GitHub Integration:**
1. Connect Railway to your GitHub repository
2. Enable automatic deployments on push to main branch
3. Configure deployment previews for pull requests

```yaml
# .github/workflows/railway-deploy.yml
name: Railway Deployment

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v3
      
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: 18
          cache: 'npm'
      
      - name: Install dependencies
        run: npm ci
      
      - name: Run tests
        run: npm run test
      
      - name: Build application
        run: npm run build:prod
      
      - name: Deploy to Railway
        uses: railway/deploy@v1
        with:
          service: clinic-app
        env:
          RAILWAY_TOKEN: ${{ secrets.RAILWAY_TOKEN }}
```

#### 6.2 Manual Deployment

```bash
# Deploy current branch to Railway
railway up

# Deploy specific service
railway up --service clinic-app

# Deploy with environment override
railway up --environment production
```

## 🔧 Railway Platform-Specific Optimizations

### Resource Allocation

#### Memory and CPU Configuration
```bash
# Railway automatically scales based on usage
# For clinic applications (2-3 concurrent users):
# - Memory: 512MB - 1GB (auto-scaling)
# - CPU: Shared vCPU (sufficient for low traffic)
# - Storage: 1GB included, expandable as needed
```

#### Network Configuration
```bash
# Railway provides:
# - Automatic HTTPS/SSL
# - Global CDN for static assets
# - Load balancing (automatic)
# - DDoS protection (included)
```

### Build Optimization

#### Nixpacks Configuration
```toml
# nixpacks.toml - Optional advanced configuration
[build]
cmd = "npm ci && npm run build:prod"

[start]
cmd = "npm run start:prod"

[variables]
NODE_ENV = "production"
NPM_CONFIG_PRODUCTION = "false"  # Keep devDependencies for build
```

#### Dockerfile Alternative (if needed)
```dockerfile
# Dockerfile - Only if Nixpacks auto-detection fails
FROM node:18-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./
COPY nx.json ./
COPY tsconfig.base.json ./

# Install dependencies
RUN npm ci

# Copy source code
COPY apps/ ./apps/
COPY libs/ ./libs/

# Build application
RUN npm run build:prod

# Expose port
EXPOSE 3000

# Start application
CMD ["npm", "run", "start:prod"]
```

### Environment-Specific Configurations

#### Development Environment
```bash
# Create development environment
railway environment create development

# Set development-specific variables
railway variables set NODE_ENV=development --environment development
railway variables set LOG_LEVEL=debug --environment development
railway variables set API_BASE_URL=http://localhost:3000/api --environment development
```

#### Staging Environment
```bash
# Create staging environment
railway environment create staging

# Set staging-specific variables
railway variables set NODE_ENV=staging --environment staging
railway variables set LOG_LEVEL=info --environment staging
railway variables set APP_URL=https://clinic-app-staging.up.railway.app --environment staging
```

#### Production Environment
```bash
# Production environment (default)
railway variables set NODE_ENV=production --environment production
railway variables set LOG_LEVEL=warn --environment production
railway variables set APP_URL=https://clinic-app.up.railway.app --environment production
```

## 🔄 Continuous Integration/Continuous Deployment

### Railway GitHub Integration

#### Automatic Deployments
1. **Connect Repository**: Link your GitHub repository to Railway project
2. **Branch Configuration**: Set main branch for production deployments
3. **PR Previews**: Enable preview deployments for pull requests
4. **Build Triggers**: Automatic builds on code changes

#### Deployment Workflow
```
Code Push → GitHub → Railway Build → Deploy → Health Check → Live
    ↓
 Run Tests → Build App → Update Service → Verify Deployment
```

### Rollback Strategy

#### Automatic Rollback
```bash
# Railway automatically keeps deployment history
# Rollback to previous deployment via dashboard or CLI

# List recent deployments
railway deployments list

# Rollback to specific deployment
railway deployments rollback <deployment-id>
```

#### Manual Rollback Process
1. **Identify Issue**: Monitor health checks and error rates
2. **Quick Rollback**: Use Railway dashboard one-click rollback
3. **Verify Rollback**: Check application functionality
4. **Investigate**: Debug issue in staging environment
5. **Redeploy**: Deploy fix after testing

### Health Monitoring

#### Railway Health Checks
```typescript
// Implement comprehensive health check endpoint
app.get('/api/health', async (req, res) => {
  const health = {
    status: 'healthy',
    timestamp: new Date().toISOString(),
    environment: process.env.NODE_ENV,
    version: process.env.npm_package_version,
    services: {},
    metrics: {}
  };

  try {
    // Database health check
    const dbResult = await db.query('SELECT NOW()');
    health.services.database = 'connected';
    
    // Memory usage check
    const memUsage = process.memoryUsage();
    health.metrics.memory = {
      used: Math.round(memUsage.heapUsed / 1024 / 1024),
      total: Math.round(memUsage.heapTotal / 1024 / 1024)
    };
    
    // Uptime check
    health.metrics.uptime = Math.round(process.uptime());
    
    res.status(200).json(health);
  } catch (error) {
    health.status = 'unhealthy';
    health.services.database = 'disconnected';
    res.status(503).json(health);
  }
});
```

## 💰 Cost Management

### Railway Pricing Tiers

#### Hobby Plan ($5/month)
- **Included Resources**:
  - $5 worth of usage credits
  - Shared CPU and memory
  - 1GB disk storage
  - Automatic scaling
  - SSL certificates

#### Pro Plan ($20/month)
- **Additional Benefits**:
  - $20 worth of usage credits
  - Priority support
  - Team collaboration features
  - Advanced analytics

### Cost Optimization Tips

#### Resource Usage Optimization
```bash
# Monitor resource usage
railway usage

# Optimize database connections
railway variables set DB_POOL_MAX=10  # Reduce from default 20

# Enable compression to reduce bandwidth
railway variables set ENABLE_COMPRESSION=true
```

#### Efficient Database Usage
```typescript
// Implement connection pooling
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  max: 10, // Reduced pool size for cost optimization
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000
});
```

### Usage Monitoring

#### Monitor Railway Usage
```bash
# Check current usage
railway usage show

# Set up usage alerts via Railway dashboard
# Configure notifications at 80% of plan limit
```

## 🚨 Troubleshooting Deployment Issues

### Common Build Failures

#### Node.js Version Issues
```bash
# Specify Node.js version in package.json
{
  "engines": {
    "node": "18.x",
    "npm": "9.x"
  }
}
```

#### Build Memory Issues
```bash
# Increase build memory for large applications
railway variables set NODE_OPTIONS="--max-old-space-size=4096"
```

#### Build Timeout Issues
```bash
# Optimize build process
{
  "scripts": {
    "build:prod": "nx build client --prod --max-workers=2 && nx build api --prod"
  }
}
```

### Runtime Issues

#### Application Startup Failures
```typescript
// Add startup logging
console.log('🚀 Starting application...');
console.log(`Node.js version: ${process.version}`);
console.log(`Environment: ${process.env.NODE_ENV}`);
console.log(`Port: ${process.env.PORT}`);
```

#### Database Connection Issues
```typescript
// Implement retry logic for database connections
const connectWithRetry = async (retries = 3) => {
  try {
    await db.query('SELECT 1');
    console.log('📊 Database connected successfully');
  } catch (error) {
    if (retries > 0) {
      console.log(`📊 Database connection failed, retrying... (${retries} attempts left)`);
      await new Promise(resolve => setTimeout(resolve, 5000));
      return connectWithRetry(retries - 1);
    }
    throw error;
  }
};
```

### Performance Issues

#### Slow Application Response
```typescript
// Add request timing middleware
app.use((req, res, next) => {
  const start = Date.now();
  res.on('finish', () => {
    const duration = Date.now() - start;
    if (duration > 1000) {
      console.warn(`Slow request: ${req.method} ${req.url} took ${duration}ms`);
    }
  });
  next();
});
```

#### Memory Usage Issues
```typescript
// Monitor memory usage
setInterval(() => {
  const memUsage = process.memoryUsage();
  const usage = Math.round(memUsage.heapUsed / 1024 / 1024);
  
  if (usage > 400) { // Alert if using more than 400MB
    console.warn(`High memory usage: ${usage}MB`);
  }
}, 60000); // Check every minute
```

---

## 🔗 Navigation

**← Previous:** [Best Practices](./best-practices.md) | **Next:** [Template Examples](./template-examples.md) →

**Related Sections:**
- [Performance Analysis](./performance-analysis.md) - Railway-specific performance optimization
- [Troubleshooting](./troubleshooting.md) - Common Railway deployment issues