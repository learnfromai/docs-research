# Implementation Guide: Step-by-Step Railway Deployment

## 🎯 Pre-Deployment Checklist

### Required Tools & Accounts
- [ ] **Railway Account**: Sign up at [railway.app](https://railway.app)
- [ ] **GitHub Account**: Repository hosting for automatic deployments
- [ ] **Railway CLI**: Install via `npm install -g @railway/cli`
- [ ] **Node.js**: Version 18+ for Nx workspace compatibility
- [ ] **Git**: Version control for deployment triggers

### Project Prerequisites
- [ ] **Nx Workspace**: Configured with `apps/web` and `apps/api`
- [ ] **Environment Variables**: Development and production configurations
- [ ] **Database Schema**: Migration files ready for deployment
- [ ] **Build Configuration**: Optimized for production deployment

## 🚀 Phase 1: Railway Project Setup

### Step 1: Create Railway Project
```bash
# Install and authenticate Railway CLI
npm install -g @railway/cli
railway login

# Initialize new Railway project
railway init
# Choose: "Empty Project"
# Project name: "clinic-management-system"
```

### Step 2: Connect GitHub Repository
```bash
# Link your existing repository
railway link

# Or create from GitHub directly
railway init --template github:your-username/clinic-nx-repo
```

### Step 3: Create Core Services
```bash
# Create frontend service
railway service create web

# Create backend service  
railway service create api

# Create MySQL database
railway add mysql
```

## 🏗️ Phase 2: Service Configuration

### Step 2.1: Frontend Service Setup
```bash
# Link to frontend service
railway link --service web

# Set frontend environment variables
railway variables set NODE_ENV=production
railway variables set VITE_API_URL=https://api-production.up.railway.app
railway variables set VITE_APP_NAME="Clinic Management"
```

Create `nixpacks.toml` for frontend:
```toml
# nixpacks.toml (frontend specific)
[phases.setup]
nixPkgs = ['nodejs_18']

[phases.install]
cmds = ['npm ci']

[phases.build] 
cmds = ['npx nx build web --prod']

[start]
cmd = 'npx serve dist/apps/web -s -l $PORT'
```

### Step 2.2: Backend Service Setup
```bash
# Link to backend service
railway link --service api

# Set backend environment variables
railway variables set NODE_ENV=production
railway variables set DATABASE_URL=${{MySQL.DATABASE_URL}}
railway variables set JWT_SECRET=${{JWT_SECRET}}
railway variables set CORS_ORIGIN=https://web-production.up.railway.app
```

Create backend-specific configuration:
```toml
# nixpacks.toml (backend specific)
[phases.setup]
nixPkgs = ['nodejs_18']

[phases.install]
cmds = ['npm ci']

[phases.build]
cmds = ['npx nx build api --prod']

[start]
cmd = 'node dist/apps/api/main.js'
```

### Step 2.3: Database Configuration
```bash
# Database is automatically configured
# Connection string available as ${{MySQL.DATABASE_URL}}

# Verify database connection
railway connect mysql
```

## ⚙️ Phase 3: Build Configuration

### Step 3.1: Optimize Nx for Railway
Update `nx.json`:
```json
{
  "targetDefaults": {
    "build": {
      "cache": true,
      "dependsOn": ["^build"],
      "inputs": ["production", "^production"]
    }
  },
  "tasksRunnerOptions": {
    "default": {
      "runner": "nx/tasks-runners/default",
      "options": {
        "cacheableOperations": ["build", "lint", "test"],
        "parallel": 3,
        "maxParallel": 3
      }
    }
  }
}
```

### Step 3.2: Configure Package.json Scripts
```json
{
  "scripts": {
    "build": "nx run-many --target=build --projects=web,api --prod",
    "build:web": "nx build web --prod",
    "build:api": "nx build api --prod",
    "start:web": "npx serve dist/apps/web -s -l $PORT",
    "start:api": "node dist/apps/api/main.js",
    "railway:migrate": "npm run build:api && npm run db:migrate"
  }
}
```

### Step 3.3: Environment-Specific Configurations
Create `.env.railway`:
```bash
# .env.railway - Railway-specific environment
NODE_ENV=production
RAILWAY_ENVIRONMENT=production

# Frontend variables (prefixed with VITE_)
VITE_API_URL=https://api-production.up.railway.app
VITE_APP_ENV=production
VITE_APP_NAME=Clinic Management System

# Backend variables
DATABASE_URL=${{MySQL.DATABASE_URL}}
JWT_SECRET=${{JWT_SECRET}}
CORS_ORIGIN=https://web-production.up.railway.app
PORT=${{PORT}}
```

## 🗄️ Phase 4: Database Migration

### Step 4.1: Prepare Migration Files
```typescript
// apps/api/src/database/migrations/001-initial-schema.ts
import { MigrationInterface, QueryRunner } from 'typeorm';

export class InitialSchema1700000000000 implements MigrationInterface {
  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE patients (
        id INT PRIMARY KEY AUTO_INCREMENT,
        first_name VARCHAR(100) NOT NULL,
        last_name VARCHAR(100) NOT NULL,
        email VARCHAR(255) UNIQUE,
        phone VARCHAR(20),
        date_of_birth DATE,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
      )
    `);
    
    await queryRunner.query(`
      CREATE TABLE appointments (
        id INT PRIMARY KEY AUTO_INCREMENT,
        patient_id INT NOT NULL,
        appointment_date DATETIME NOT NULL,
        status ENUM('scheduled', 'confirmed', 'completed', 'cancelled') DEFAULT 'scheduled',
        notes TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (patient_id) REFERENCES patients(id)
      )
    `);
  }
  
  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query('DROP TABLE appointments');
    await queryRunner.query('DROP TABLE patients');
  }
}
```

### Step 4.2: Run Migrations
```bash
# Create migration script
cat > migrate.js << 'EOF'
const { execSync } = require('child_process');

async function runMigrations() {
  try {
    console.log('Running database migrations...');
    execSync('npm run typeorm migration:run', { stdio: 'inherit' });
    console.log('Migrations completed successfully');
  } catch (error) {
    console.error('Migration failed:', error);
    process.exit(1);
  }
}

runMigrations();
EOF

# Run migrations on Railway
railway run node migrate.js
```

## 🚀 Phase 5: Deployment Process

### Step 5.1: Deploy Frontend Service
```bash
# Switch to frontend service
railway link --service web

# Deploy frontend
railway up

# Monitor deployment
railway logs
```

### Step 5.2: Deploy Backend Service
```bash
# Switch to backend service
railway link --service api

# Deploy backend
railway up

# Monitor deployment and check health
railway logs
curl https://api-production.up.railway.app/health
```

### Step 5.3: Verify Full Stack Deployment
```bash
# Check all services status
railway status

# Test frontend
curl https://web-production.up.railway.app

# Test API endpoints
curl https://api-production.up.railway.app/api/patients

# Check database connectivity
railway connect mysql
```

## 🔧 Phase 6: Domain Configuration

### Step 6.1: Configure Custom Domains
```bash
# Add custom domain to frontend
railway domain add web.clinic-example.com --service web

# Add custom domain to backend
railway domain add api.clinic-example.com --service api

# Update environment variables with new domains
railway variables set VITE_API_URL=https://api.clinic-example.com
railway variables set CORS_ORIGIN=https://web.clinic-example.com
```

### Step 6.2: SSL Certificate Setup
Railway automatically handles SSL certificates for custom domains:
```bash
# Verify SSL status
railway domain list

# SSL certificates are automatically provisioned
# No manual configuration required
```

## 📊 Phase 7: Monitoring & Observability

### Step 7.1: Set Up Health Checks
Add health check endpoints:
```typescript
// apps/api/src/health/health.controller.ts
import { Controller, Get } from '@nestjs/common';

@Controller('health')
export class HealthController {
  @Get()
  async checkHealth() {
    return {
      status: 'healthy',
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
      memory: process.memoryUsage(),
      environment: process.env.NODE_ENV
    };
  }
  
  @Get('database')
  async checkDatabase() {
    // Database connectivity check
    try {
      await this.dataSource.query('SELECT 1');
      return { database: 'connected' };
    } catch (error) {
      throw new Error('Database connection failed');
    }
  }
}
```

### Step 7.2: Configure Monitoring Dashboard
```bash
# Access Railway dashboard for monitoring
railway open

# Set up alerting rules
railway alerts create --service api --metric cpu --threshold 80
railway alerts create --service api --metric memory --threshold 85
railway alerts create --service api --metric errors --threshold 5
```

## 🔄 Phase 8: CI/CD Integration

### Step 8.1: GitHub Actions Setup
Create `.github/workflows/railway.yml`:
```yaml
name: Deploy to Railway

on:
  push:
    branches: [main, develop]
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
        run: |
          npx nx test web
          npx nx test api
          npx nx lint web
          npx nx lint api
  
  deploy:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Deploy to Railway
        uses: railway/railway@v1
        with:
          railway-token: ${{ secrets.RAILWAY_TOKEN }}
          command: 'up'
```

### Step 8.2: Configure Railway Webhooks
```bash
# Set up webhook for deployment notifications
railway webhooks create \
  --url https://your-slack-webhook-url \
  --events deployment.success,deployment.failed
```

## 🔐 Phase 9: Security Configuration

### Step 9.1: Environment Secrets
```bash
# Add sensitive environment variables
railway variables set JWT_SECRET=$(openssl rand -base64 32)
railway variables set DATABASE_ENCRYPTION_KEY=$(openssl rand -base64 32)

# Set up CORS properly
railway variables set CORS_ORIGIN=https://web.clinic-example.com
railway variables set ALLOWED_ORIGINS=https://web.clinic-example.com,https://www.clinic-example.com
```

### Step 9.2: Network Security
```typescript
// apps/api/src/main.ts - Security middleware
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';

// Security headers
app.use(helmet({
  crossOriginEmbedderPolicy: false,
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'", "'unsafe-inline'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      imgSrc: ["'self'", "data:", "https:"],
    },
  },
}));

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 1000, // limit each IP to 1000 requests per windowMs
  message: 'Too many requests from this IP'
});
app.use('/api', limiter);
```

## 📋 Phase 10: Testing & Validation

### Step 10.1: End-to-End Testing
```bash
# Test complete user flow
npm run e2e:railway

# Load testing with realistic clinic traffic
npx artillery quick --count 10 --num 50 https://api.clinic-example.com/api/patients
```

### Step 10.2: Performance Validation
```bash
# Check API response times
curl -w "@curl-format.txt" -o /dev/null -s https://api.clinic-example.com/health

# Frontend performance testing
npx lighthouse https://web.clinic-example.com --output html --output-path lighthouse-report.html
```

## 🔧 Troubleshooting Common Issues

### Issue 1: Build Failures
```bash
# Clear Nx cache
npx nx reset

# Clean install
rm -rf node_modules package-lock.json
npm install

# Test build locally before deployment
npx nx build web --prod
npx nx build api --prod
```

### Issue 2: Database Connection Issues
```bash
# Check database URL format
railway variables get DATABASE_URL

# Test connection
railway connect mysql

# Verify migration status
railway run npm run typeorm migration:show
```

### Issue 3: Service Communication
```bash
# Check internal URLs
railway variables list

# Verify CORS configuration
curl -H "Origin: https://web.clinic-example.com" \
     -H "Access-Control-Request-Method: GET" \
     -X OPTIONS \
     https://api.clinic-example.com/api/patients
```

## ✅ Deployment Validation Checklist

### Functional Testing
- [ ] **Frontend loads correctly**: Main pages render without errors
- [ ] **API endpoints respond**: All CRUD operations working
- [ ] **Database connectivity**: Data persistence and retrieval
- [ ] **Authentication flow**: Login/logout functionality
- [ ] **File uploads**: Patient document handling (if applicable)

### Performance Testing
- [ ] **Page load times**: < 3 seconds for main pages
- [ ] **API response times**: < 500ms for simple queries
- [ ] **Database queries**: < 100ms for indexed queries
- [ ] **Memory usage**: Within allocated limits
- [ ] **CPU utilization**: < 70% under normal load

### Security Testing
- [ ] **HTTPS enabled**: All traffic encrypted
- [ ] **CORS configured**: Only allowed origins accepted
- [ ] **Authentication required**: Protected routes secured
- [ ] **Input validation**: SQL injection prevention
- [ ] **Rate limiting**: API abuse protection

---

## 🔗 Navigation

← [Previous: Clinic Management Case Study](./clinic-management-case-study.md) | [Next: Best Practices](./best-practices.md) →