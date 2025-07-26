# Template Examples: Nx Managed Deployment

## 🎯 Overview

This document provides working configuration files, deployment scripts, and template examples for deploying Nx monorepo projects to various managed platforms. All examples are production-ready and optimized for client handovers.

---

## 📁 Project Structure Templates

### Standard Nx Monorepo Structure
```
nx-fullstack-app/
├── apps/
│   ├── frontend/              # React + Vite application
│   │   ├── src/
│   │   ├── project.json
│   │   └── vite.config.ts
│   ├── backend/               # Express.js API
│   │   ├── src/
│   │   ├── project.json
│   │   └── webpack.config.js
│   └── admin/                 # Admin dashboard (optional)
├── libs/
│   ├── shared/
│   │   ├── types/             # TypeScript interfaces
│   │   ├── utils/             # Common utilities
│   │   └── validation/        # Schema validation
│   └── ui/
│       └── components/        # Reusable UI components
├── tools/
│   ├── deployment/            # Deployment scripts
│   └── generators/            # Custom Nx generators
├── .do/
│   └── app.yaml              # Digital Ocean configuration
├── .github/
│   └── workflows/
│       └── deploy.yml        # CI/CD pipeline
├── nx.json                   # Nx workspace configuration
├── package.json              # Root dependencies
├── README.md                 # Project documentation
└── deployment/
    ├── railway.toml          # Railway configuration
    ├── render.yaml           # Render configuration
    └── vercel.json           # Vercel configuration
```

---

## 🔧 Configuration Files

### Digital Ocean App Platform

#### Complete app.yaml Template
```yaml
# .do/app.yaml - Production-ready configuration
name: nx-fullstack-app
region: nyc1

# Global environment variables
envs:
  - key: NODE_ENV
    value: "production"
  - key: JWT_SECRET
    value: "your-super-secret-jwt-key-minimum-32-characters"
    type: SECRET
  - key: APP_VERSION
    value: "1.0.0"
  - key: CORS_ALLOWED_ORIGINS
    value: "https://yourdomain.com,https://www.yourdomain.com"

services:
  # Frontend Service (React + Vite)
  - name: frontend
    source_dir: /
    github:
      repo: your-username/nx-fullstack-app
      branch: main
      deploy_on_push: true
    
    # Build configuration optimized for Nx
    build_command: |
      echo "🔧 Installing dependencies..."
      npm ci --only=production --silent
      echo "🏗️ Building frontend application..."
      export NODE_OPTIONS="--max-old-space-size=4096"
      npm run build:frontend
      echo "✅ Frontend build completed"
      ls -la dist/apps/frontend/
    
    # Runtime configuration
    run_command: |
      echo "🚀 Starting frontend server..."
      npx serve dist/apps/frontend -s -n -L -p $PORT --cors
    
    # Service settings
    environment_slug: node-js
    instance_count: 1
    instance_size_slug: basic-s
    http_port: 8080
    
    # Health check
    health_check:
      http_path: /
      initial_delay_seconds: 30
      period_seconds: 10
      timeout_seconds: 5
      success_threshold: 1
      failure_threshold: 3
    
    # Routing
    routes:
      - path: /
        preserve_path_prefix: false
    
    # Environment variables
    envs:
      - key: VITE_API_URL
        value: "${backend.PUBLIC_URL}"
      - key: VITE_APP_NAME
        value: "My Nx Application"
      - key: VITE_APP_VERSION
        value: "${APP_VERSION}"

  # Backend Service (Express.js)
  - name: backend
    source_dir: /
    github:
      repo: your-username/nx-fullstack-app
      branch: main
      deploy_on_push: true
    
    # Build configuration
    build_command: |
      echo "🔧 Installing dependencies..."
      npm ci --only=production --silent
      echo "🏗️ Building backend application..."
      export NODE_OPTIONS="--max-old-space-size=4096"
      npm run build:backend
      echo "✅ Backend build completed"
      ls -la dist/apps/backend/
    
    # Runtime configuration
    run_command: |
      echo "🚀 Starting backend server..."
      node dist/apps/backend/main.js
    
    # Service settings
    environment_slug: node-js
    instance_count: 1
    instance_size_slug: basic-s
    http_port: 8080
    
    # Health check
    health_check:
      http_path: /health
      initial_delay_seconds: 45
      period_seconds: 10
      timeout_seconds: 5
      success_threshold: 1
      failure_threshold: 3
    
    # Routing
    routes:
      - path: /api
        preserve_path_prefix: true
      - path: /health
        preserve_path_prefix: true
    
    # Environment variables
    envs:
      - key: DATABASE_URL
        value: "${db.DATABASE_URL}"
      - key: JWT_SECRET
        value: "${JWT_SECRET}"
      - key: CORS_ORIGIN
        value: "${frontend.PUBLIC_URL}"
      - key: PORT
        value: "8080"

# Database configuration
databases:
  - name: db
    engine: PG
    version: "15"
    production: true
    num_nodes: 1
    size: db-s-1vcpu-1gb

# Jobs (for background tasks)
jobs:
  - name: database-migrate
    source_dir: /
    github:
      repo: your-username/nx-fullstack-app
      branch: main
    build_command: |
      npm ci --only=production
      npm run build:backend
    run_command: |
      node dist/apps/backend/scripts/migrate.js
    environment_slug: node-js
    instance_count: 1
    instance_size_slug: basic-xxs
    kind: PRE_DEPLOY
    envs:
      - key: DATABASE_URL
        value: "${db.DATABASE_URL}"

# Custom domains (optional)
domains:
  - domain: yourdomain.com
    type: PRIMARY
    zone: yourdomain.com
  - domain: www.yourdomain.com
    type: ALIAS
    zone: yourdomain.com
```

### Railway Configuration

#### railway.toml for Full-Stack Deployment
```toml
# railway.toml - Complete Railway configuration

[build]
builder = "NIXPACKS"
buildCommand = """
  echo "Installing dependencies..."
  npm ci --only=production
  echo "Building applications..."
  npm run build:frontend
  npm run build:backend
"""

[deploy]
startCommand = "npm run start:prod"
healthcheckPath = "/health"
healthcheckTimeout = 60
restartPolicyType = "ON_FAILURE"
restartPolicyMaxRetries = 3

# Environment configuration
[env]
NODE_ENV = "production"
PORT = "8080"

# Nixpacks customization
[nixpacks]
aptPkgs = ["curl", "git"]
nixPkgs = ["nodejs-18_x", "npm-9_x"]

# Build phases
[nixpacks.phases.setup]
nixPkgs = ["nodejs-18_x", "npm-9_x"]

[nixpacks.phases.install]
cmds = [
  "npm ci --only=production --silent"
]

[nixpacks.phases.build]
cmds = [
  "export NODE_OPTIONS='--max-old-space-size=4096'",
  "npm run build:frontend",
  "npm run build:backend"
]

[nixpacks.phases.start]
cmd = "npm run start:prod"
```

#### Separate Service Configuration
```toml
# railway-frontend.toml
[build]
builder = "NIXPACKS"
buildCommand = "npm ci && npm run build:frontend"

[deploy]
startCommand = "npx serve dist/apps/frontend -s -n -L -p $PORT"
healthcheckPath = "/"
healthcheckTimeout = 100

[env]
NODE_ENV = "production"
PORT = "3000"

# railway-backend.toml
[build]
builder = "NIXPACKS" 
buildCommand = "npm ci && npm run build:backend"

[deploy]
startCommand = "node dist/apps/backend/main.js"
healthcheckPath = "/health"
healthcheckTimeout = 60

[env]
NODE_ENV = "production"
PORT = "8080"
```

### Render Configuration

#### render.yaml Template
```yaml
# render.yaml - Complete Render configuration
services:
  # Frontend Static Site
  - type: web
    name: nx-frontend
    env: static
    plan: free
    buildCommand: |
      npm ci --only=production
      npm run build:frontend
    staticPublishPath: dist/apps/frontend
    pullRequestPreviewsEnabled: true
    
    # Custom headers for security
    headers:
      - path: /*
        name: X-Frame-Options
        value: DENY
      - path: /*
        name: X-Content-Type-Options
        value: nosniff
    
    # SPA routing
    routes:
      - type: rewrite
        source: /*
        destination: /index.html
    
    envVars:
      - key: NODE_ENV
        value: production
      - key: VITE_API_URL
        value: https://nx-backend.onrender.com

  # Backend API Service
  - type: web
    name: nx-backend
    env: node
    plan: free
    buildCommand: |
      npm ci --only=production
      npm run build:backend
    startCommand: node dist/apps/backend/main.js
    healthCheckPath: /health
    
    # Auto scaling configuration
    scaling:
      minInstances: 1
      maxInstances: 3
      targetMemoryPercent: 80
      targetCPUPercent: 70
    
    envVars:
      - key: NODE_ENV
        value: production
      - key: PORT
        value: 10000
      - key: DATABASE_URL
        fromDatabase:
          name: nx-database
          property: connectionString
      - key: JWT_SECRET
        generateValue: true
      - key: CORS_ORIGIN
        value: https://nx-frontend.onrender.com

# Database configuration
databases:
  - name: nx-database
    databaseName: nx_app_db
    user: nx_user
    plan: free
    region: oregon
    version: "15"
```

### Vercel Configuration

#### vercel.json for Frontend + Serverless Functions
```json
{
  "version": 2,
  "name": "nx-fullstack-app",
  "builds": [
    {
      "src": "apps/frontend/package.json",
      "use": "@vercel/static-build",
      "config": {
        "distDir": "../../dist/apps/frontend"
      }
    },
    {
      "src": "apps/backend/src/main.ts",
      "use": "@vercel/node",
      "config": {
        "includeFiles": ["dist/apps/backend/**"]
      }
    }
  ],
  "routes": [
    {
      "src": "/api/(.*)",
      "dest": "/apps/backend/src/main.ts"
    },
    {
      "src": "/(.*)",
      "dest": "/apps/frontend/$1"
    }
  ],
  "env": {
    "NODE_ENV": "production",
    "VITE_API_URL": "https://your-app.vercel.app"
  },
  "build": {
    "env": {
      "NODE_ENV": "production"
    }
  },
  "functions": {
    "apps/backend/src/main.ts": {
      "runtime": "nodejs18.x",
      "memory": 1024,
      "maxDuration": 10
    }
  },
  "regions": ["iad1"],
  "framework": null
}
```

---

## 📦 Package.json Templates

### Root Package.json
```json
{
  "name": "nx-fullstack-app",
  "version": "1.0.0",
  "license": "MIT",
  "scripts": {
    "build": "nx build --parallel",
    "build:frontend": "nx build frontend --configuration=production",
    "build:backend": "nx build backend --configuration=production", 
    "build:all": "npm run build:frontend && npm run build:backend",
    "start": "nx serve",
    "start:frontend": "npx serve dist/apps/frontend -s -n -L -p ${PORT:-3000}",
    "start:backend": "node dist/apps/backend/main.js",
    "start:prod": "concurrently \"npm run start:backend\" \"npm run start:frontend\"",
    "dev": "nx serve --parallel",
    "test": "nx affected:test",
    "lint": "nx affected:lint",
    "e2e": "nx affected:e2e",
    "deploy:railway": "railway up",
    "deploy:vercel": "vercel --prod",
    "migrate": "node dist/apps/backend/scripts/migrate.js",
    "seed": "node dist/apps/backend/scripts/seed.js"
  },
  "private": true,
  "dependencies": {
    "@nrwl/devkit": "17.2.8",
    "axios": "^1.6.2",
    "bcryptjs": "^2.4.3",
    "compression": "^1.7.4",
    "cors": "^2.8.5",
    "express": "^4.18.2",
    "helmet": "^7.1.0",
    "jsonwebtoken": "^9.0.2",
    "pg": "^8.11.3",
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-router-dom": "^6.20.1",
    "serve": "^14.2.1",
    "zod": "^3.22.4",
    "concurrently": "^8.2.2"
  },
  "devDependencies": {
    "@nrwl/cypress": "17.2.8",
    "@nrwl/eslint-plugin-nx": "17.2.8",
    "@nrwl/jest": "17.2.8",
    "@nrwl/js": "17.2.8",
    "@nrwl/linter": "17.2.8",
    "@nrwl/node": "17.2.8",
    "@nrwl/react": "17.2.8",
    "@nrwl/vite": "17.2.8",
    "@nrwl/webpack": "17.2.8",
    "@nrwl/workspace": "17.2.8",
    "@types/bcryptjs": "^2.4.6",
    "@types/compression": "^1.7.5",
    "@types/cors": "^2.8.17",
    "@types/express": "^4.17.21",
    "@types/jsonwebtoken": "^9.0.5",
    "@types/node": "^20.10.0",
    "@types/pg": "^8.10.9",
    "@types/react": "^18.2.42",
    "@types/react-dom": "^18.2.17",
    "@typescript-eslint/eslint-plugin": "^6.21.0",
    "@typescript-eslint/parser": "^6.21.0",
    "@vitejs/plugin-react": "^4.2.0",
    "cypress": "^13.6.0",
    "eslint": "^8.57.0",
    "eslint-config-prettier": "^9.1.0",
    "eslint-plugin-cypress": "^2.15.1",
    "eslint-plugin-import": "^2.29.0",
    "eslint-plugin-jsx-a11y": "^6.8.0",
    "eslint-plugin-react": "^7.33.2",
    "eslint-plugin-react-hooks": "^4.6.0",
    "jest": "^29.7.0",
    "jest-environment-jsdom": "^29.7.0",
    "nx": "17.2.8",
    "prettier": "^3.1.1",
    "ts-jest": "^29.1.1",
    "ts-node": "^10.9.1",
    "typescript": "^5.3.2",
    "vite": "^5.0.8"
  },
  "nx": {
    "includedScripts": []
  }
}
```

### Frontend Package.json
```json
{
  "name": "frontend",
  "version": "0.0.1",
  "private": true,
  "scripts": {
    "build": "cd ../.. && nx build frontend --configuration=production",
    "dev": "cd ../.. && nx serve frontend",
    "test": "cd ../.. && nx test frontend",
    "lint": "cd ../.. && nx lint frontend"
  },
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-router-dom": "^6.20.1",
    "axios": "^1.6.2",
    "zod": "^3.22.4"
  },
  "devDependencies": {
    "@types/react": "^18.2.42",
    "@types/react-dom": "^18.2.17",
    "@vitejs/plugin-react": "^4.2.0",
    "vite": "^5.0.8"
  }
}
```

### Backend Package.json  
```json
{
  "name": "backend",
  "version": "0.0.1",
  "private": true,
  "scripts": {
    "build": "cd ../.. && nx build backend --configuration=production",
    "dev": "cd ../.. && nx serve backend",
    "start": "node ../../dist/apps/backend/main.js",
    "test": "cd ../.. && nx test backend",
    "lint": "cd ../.. && nx lint backend",
    "migrate": "node ../../dist/apps/backend/scripts/migrate.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "cors": "^2.8.5",
    "helmet": "^7.1.0",
    "compression": "^1.7.4",
    "bcryptjs": "^2.4.3",
    "jsonwebtoken": "^9.0.2",
    "pg": "^8.11.3",
    "zod": "^3.22.4"
  },
  "devDependencies": {
    "@types/express": "^4.17.21",
    "@types/cors": "^2.8.17",
    "@types/bcryptjs": "^2.4.6",
    "@types/jsonwebtoken": "^9.0.5",
    "@types/pg": "^8.10.9",
    "@types/node": "^20.10.0"
  }
}
```

---

## 🔄 CI/CD Pipeline Templates

### GitHub Actions

#### Complete Deployment Workflow
```yaml
# .github/workflows/deploy.yml
name: Deploy Nx Fullstack App

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

env:
  NODE_VERSION: '18'
  NX_CACHE_KEY: 'nx-cache-v1'

jobs:
  # Install and cache dependencies
  setup:
    runs-on: ubuntu-latest
    outputs:
      cache-key: ${{ steps.cache-deps.outputs.cache-hit }}
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: 'npm'

      - name: Cache dependencies
        id: cache-deps
        uses: actions/cache@v3
        with:
          path: |
            node_modules
            ~/.npm
          key: ${{ runner.os }}-node-${{ hashFiles('package-lock.json') }}
          restore-keys: |
            ${{ runner.os }}-node-

      - name: Install dependencies
        if: steps.cache-deps.outputs.cache-hit != 'true'
        run: npm ci --prefer-offline --no-audit

  # Run tests and linting
  test:
    needs: setup
    runs-on: ubuntu-latest
    strategy:
      matrix:
        command: [test, lint, e2e]
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: 'npm'

      - name: Restore dependencies
        uses: actions/cache@v3
        with:
          path: |
            node_modules
            ~/.npm
          key: ${{ runner.os }}-node-${{ hashFiles('package-lock.json') }}

      - name: Run ${{ matrix.command }}
        run: |
          if [ "${{ matrix.command }}" == "test" ]; then
            npm run test -- --passWithNoTests --coverage
          elif [ "${{ matrix.command }}" == "lint" ]; then
            npm run lint
          elif [ "${{ matrix.command }}" == "e2e" ]; then
            npm run e2e -- --headless
          fi

      - name: Upload coverage reports
        if: matrix.command == 'test'
        uses: codecov/codecov-action@v3
        with:
          file: ./coverage/lcov.info

  # Build applications
  build:
    needs: [setup, test]
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: 'npm'

      - name: Restore dependencies
        uses: actions/cache@v3
        with:
          path: |
            node_modules
            ~/.npm
          key: ${{ runner.os }}-node-${{ hashFiles('package-lock.json') }}

      - name: Build applications
        env:
          NODE_OPTIONS: '--max-old-space-size=4096'
        run: |
          npm run build:frontend
          npm run build:backend

      - name: Upload build artifacts
        uses: actions/upload-artifact@v3
        with:
          name: build-artifacts
          path: |
            dist/
            package.json
            package-lock.json
          retention-days: 7

  # Deploy to staging (develop branch)
  deploy-staging:
    if: github.ref == 'refs/heads/develop'
    needs: [setup, test, build]
    runs-on: ubuntu-latest
    environment: staging
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Download build artifacts
        uses: actions/download-artifact@v3
        with:
          name: build-artifacts

      - name: Deploy to Railway (Staging)
        env:
          RAILWAY_TOKEN: ${{ secrets.RAILWAY_TOKEN }}
        run: |
          npm install -g @railway/cli
          railway up --service staging-frontend
          railway up --service staging-backend

      - name: Run health checks
        run: |
          # Wait for deployment to complete
          sleep 30
          
          # Check frontend health
          curl -f ${{ vars.STAGING_FRONTEND_URL }} || exit 1
          
          # Check backend health
          curl -f ${{ vars.STAGING_BACKEND_URL }}/health || exit 1

  # Deploy to production (main branch)
  deploy-production:
    if: github.ref == 'refs/heads/main'
    needs: [setup, test, build]
    runs-on: ubuntu-latest
    environment: production
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Download build artifacts
        uses: actions/download-artifact@v3
        with:
          name: build-artifacts

      - name: Install doctl
        uses: digitalocean/action-doctl@v2
        with:
          token: ${{ secrets.DIGITALOCEAN_ACCESS_TOKEN }}

      - name: Deploy to Digital Ocean
        run: |
          # Update app with latest spec
          doctl apps update ${{ secrets.DO_APP_ID }} --spec .do/app.yaml --wait
          
          # Verify deployment
          doctl apps get ${{ secrets.DO_APP_ID }} --format json | jq '.status'

      - name: Run production health checks
        run: |
          # Get app URLs
          FRONTEND_URL=$(doctl apps get ${{ secrets.DO_APP_ID }} --format json | jq -r '.live_url')
          BACKEND_URL=$(doctl apps get ${{ secrets.DO_APP_ID }} --format json | jq -r '.services[] | select(.name=="backend") | .live_url')
          
          # Health checks
          curl -f "$FRONTEND_URL" || exit 1
          curl -f "$BACKEND_URL/health" || exit 1
          
          echo "✅ Production deployment successful!"
          echo "Frontend: $FRONTEND_URL"
          echo "Backend: $BACKEND_URL"

      - name: Notify deployment success
        uses: 8398a7/action-slack@v3
        if: success()
        with:
          status: success
          channel: '#deployments'
          text: |
            🚀 Production deployment successful!
            Application: ${{ github.repository }}
            Commit: ${{ github.sha }}
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}

      - name: Notify deployment failure
        uses: 8398a7/action-slack@v3
        if: failure()
        with:
          status: failure
          channel: '#deployments'
          text: |
            ❌ Production deployment failed!
            Application: ${{ github.repository }}
            Commit: ${{ github.sha }}
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
```

### GitLab CI Pipeline

#### .gitlab-ci.yml Template
```yaml
# .gitlab-ci.yml
stages:
  - setup
  - test
  - build
  - deploy

variables:
  NODE_VERSION: "18"
  NPM_CONFIG_CACHE: "$CI_PROJECT_DIR/.npm"
  NX_CACHE_DIRECTORY: "$CI_PROJECT_DIR/.nx"

# Cache configuration
.cache_template: &cache_template
  cache:
    key: 
      files:
        - package-lock.json
    paths:
      - node_modules/
      - .npm/
      - .nx/

# Install dependencies
setup:
  stage: setup
  image: node:18-alpine
  <<: *cache_template
  script:
    - npm ci --prefer-offline --no-audit
  artifacts:
    paths:
      - node_modules/
    expire_in: 1 hour

# Run tests
test:
  stage: test
  image: node:18-alpine
  <<: *cache_template
  dependencies:
    - setup
  parallel:
    matrix:
      - COMMAND: [test, lint]
  script:
    - |
      if [ "$COMMAND" == "test" ]; then
        npm run test -- --passWithNoTests --coverage
      elif [ "$COMMAND" == "lint" ]; then
        npm run lint
      fi
  coverage: '/Lines\s*:\s*(\d+\.\d*)%/'
  artifacts:
    reports:
      coverage_report:
        coverage_format: cobertura
        path: coverage/cobertura-coverage.xml

# Build applications
build:
  stage: build
  image: node:18-alpine
  <<: *cache_template
  dependencies:
    - setup
  script:
    - export NODE_OPTIONS="--max-old-space-size=4096"
    - npm run build:frontend
    - npm run build:backend
  artifacts:
    paths:
      - dist/
    expire_in: 1 week

# Deploy to staging
deploy_staging:
  stage: deploy
  image: node:18-alpine
  dependencies:
    - build
  environment:
    name: staging
    url: https://staging.yourdomain.com
  script:
    - npm install -g @railway/cli
    - railway up --service staging-frontend
    - railway up --service staging-backend
  only:
    - develop

# Deploy to production
deploy_production:
  stage: deploy
  image: digitalocean/doctl:latest
  dependencies:
    - build
  environment:
    name: production
    url: https://yourdomain.com
  before_script:
    - doctl auth init --access-token $DIGITALOCEAN_ACCESS_TOKEN
  script:
    - doctl apps update $DO_APP_ID --spec .do/app.yaml --wait
    - |
      # Health check
      APP_URL=$(doctl apps get $DO_APP_ID --format json | jq -r '.live_url')
      curl -f "$APP_URL/health" || exit 1
      echo "✅ Deployment successful: $APP_URL"
  only:
    - main
  when: manual
```

---

## 🗄️ Database Templates

### Migration Scripts

#### PostgreSQL Migration Template
```typescript
// apps/backend/src/scripts/migrate.ts
import { Pool } from 'pg';

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: process.env.NODE_ENV === 'production' ? {
    rejectUnauthorized: false
  } : false
});

interface Migration {
  version: string;
  description: string;
  up: string;
  down: string;
}

const migrations: Migration[] = [
  {
    version: '001',
    description: 'Create users table',
    up: `
      CREATE TABLE IF NOT EXISTS users (
        id SERIAL PRIMARY KEY,
        email VARCHAR(255) UNIQUE NOT NULL,
        password_hash VARCHAR(255) NOT NULL,
        first_name VARCHAR(100),
        last_name VARCHAR(100),
        is_active BOOLEAN DEFAULT true,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
      
      CREATE INDEX idx_users_email ON users(email);
      CREATE INDEX idx_users_active ON users(is_active);
    `,
    down: `
      DROP TABLE IF EXISTS users;
    `
  },
  {
    version: '002',
    description: 'Create posts table',
    up: `
      CREATE TABLE IF NOT EXISTS posts (
        id SERIAL PRIMARY KEY,
        user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
        title VARCHAR(255) NOT NULL,
        content TEXT,
        status VARCHAR(20) DEFAULT 'draft',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
      
      CREATE INDEX idx_posts_user_id ON posts(user_id);
      CREATE INDEX idx_posts_status ON posts(status);
      CREATE INDEX idx_posts_created_at ON posts(created_at);
    `,
    down: `
      DROP TABLE IF EXISTS posts;
    `
  },
  {
    version: '003',
    description: 'Add updated_at trigger',
    up: `
      CREATE OR REPLACE FUNCTION update_updated_at_column()
      RETURNS TRIGGER AS $$
      BEGIN
        NEW.updated_at = CURRENT_TIMESTAMP;
        RETURN NEW;
      END;
      $$ language 'plpgsql';
      
      CREATE TRIGGER update_users_updated_at 
        BEFORE UPDATE ON users 
        FOR EACH ROW 
        EXECUTE FUNCTION update_updated_at_column();
        
      CREATE TRIGGER update_posts_updated_at 
        BEFORE UPDATE ON posts 
        FOR EACH ROW 
        EXECUTE FUNCTION update_updated_at_column();
    `,
    down: `
      DROP TRIGGER IF EXISTS update_users_updated_at ON users;
      DROP TRIGGER IF EXISTS update_posts_updated_at ON posts;
      DROP FUNCTION IF EXISTS update_updated_at_column();
    `
  }
];

async function createMigrationsTable() {
  const query = `
    CREATE TABLE IF NOT EXISTS migrations (
      version VARCHAR(10) PRIMARY KEY,
      description VARCHAR(255) NOT NULL,
      executed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
  `;
  await pool.query(query);
}

async function getExecutedMigrations(): Promise<string[]> {
  const result = await pool.query(
    'SELECT version FROM migrations ORDER BY version'
  );
  return result.rows.map(row => row.version);
}

async function executeMigration(migration: Migration) {
  const client = await pool.connect();
  
  try {
    await client.query('BEGIN');
    
    // Execute migration
    await client.query(migration.up);
    
    // Record migration
    await client.query(
      'INSERT INTO migrations (version, description) VALUES ($1, $2)',
      [migration.version, migration.description]
    );
    
    await client.query('COMMIT');
    console.log(`✅ Migration ${migration.version}: ${migration.description}`);
  } catch (error) {
    await client.query('ROLLBACK');
    console.error(`❌ Migration ${migration.version} failed:`, error);
    throw error;
  } finally {
    client.release();
  }
}

async function runMigrations() {
  try {
    console.log('🚀 Starting database migrations...');
    
    await createMigrationsTable();
    const executedMigrations = await getExecutedMigrations();
    
    const pendingMigrations = migrations.filter(
      migration => !executedMigrations.includes(migration.version)
    );
    
    if (pendingMigrations.length === 0) {
      console.log('✅ No pending migrations');
      return;
    }
    
    console.log(`📦 Found ${pendingMigrations.length} pending migrations`);
    
    for (const migration of pendingMigrations) {
      await executeMigration(migration);
    }
    
    console.log('🎉 All migrations completed successfully');
  } catch (error) {
    console.error('💥 Migration failed:', error);
    process.exit(1);
  } finally {
    await pool.end();
  }
}

// Run migrations if this file is executed directly
if (require.main === module) {
  runMigrations();
}

export { runMigrations };
```

#### Seed Data Script
```typescript
// apps/backend/src/scripts/seed.ts
import { Pool } from 'pg';
import bcrypt from 'bcryptjs';

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: process.env.NODE_ENV === 'production' ? {
    rejectUnauthorized: false
  } : false
});

async function seedUsers() {
  const users = [
    {
      email: 'admin@example.com',
      password: 'admin123',
      firstName: 'Admin',
      lastName: 'User'
    },
    {
      email: 'user@example.com', 
      password: 'user123',
      firstName: 'Regular',
      lastName: 'User'
    }
  ];

  for (const user of users) {
    const passwordHash = await bcrypt.hash(user.password, 10);
    
    const query = `
      INSERT INTO users (email, password_hash, first_name, last_name)
      VALUES ($1, $2, $3, $4)
      ON CONFLICT (email) DO NOTHING
      RETURNING id, email
    `;
    
    const result = await pool.query(query, [
      user.email,
      passwordHash,
      user.firstName,
      user.lastName
    ]);
    
    if (result.rows.length > 0) {
      console.log(`✅ Created user: ${result.rows[0].email}`);
    } else {
      console.log(`⚠️ User already exists: ${user.email}`);
    }
  }
}

async function seedPosts() {
  // Get user IDs
  const usersResult = await pool.query('SELECT id, email FROM users');
  const users = usersResult.rows;
  
  if (users.length === 0) {
    console.log('⚠️ No users found, skipping posts seeding');
    return;
  }

  const posts = [
    {
      title: 'Welcome to Our Application',
      content: 'This is the first post in our application. Welcome aboard!',
      status: 'published'
    },
    {
      title: 'Getting Started Guide',
      content: 'Here are some tips to help you get started with our platform.',
      status: 'published'
    },
    {
      title: 'Draft Post',
      content: 'This is a draft post that is not yet published.',
      status: 'draft'
    }
  ];

  for (const post of posts) {
    const randomUser = users[Math.floor(Math.random() * users.length)];
    
    const query = `
      INSERT INTO posts (user_id, title, content, status)
      VALUES ($1, $2, $3, $4)
      RETURNING id, title
    `;
    
    const result = await pool.query(query, [
      randomUser.id,
      post.title,
      post.content,
      post.status
    ]);
    
    console.log(`✅ Created post: ${result.rows[0].title}`);
  }
}

async function runSeeder() {
  try {
    console.log('🌱 Starting database seeding...');
    
    await seedUsers();
    await seedPosts();
    
    console.log('🎉 Database seeding completed successfully');
  } catch (error) {
    console.error('💥 Seeding failed:', error);
    process.exit(1);
  } finally {
    await pool.end();
  }
}

// Run seeder if this file is executed directly
if (require.main === module) {
  runSeeder();
}

export { runSeeder };
```

---

## 🔧 Environment Templates

### Environment Variable Templates

#### .env.example
```bash
# .env.example - Template for environment variables

# Application Configuration
NODE_ENV=development
PORT=3333
APP_NAME="My Nx Application"
APP_VERSION=1.0.0

# Database Configuration
DATABASE_URL=postgresql://username:password@localhost:5432/database_name

# Authentication
JWT_SECRET=your-super-secret-jwt-key-minimum-32-characters
JWT_EXPIRES_IN=7d
BCRYPT_ROUNDS=10

# API Configuration
API_URL=http://localhost:3333
CORS_ORIGIN=http://localhost:4200

# External Services
EMAIL_SERVICE_API_KEY=your-email-service-api-key
UPLOAD_SERVICE_URL=https://your-upload-service.com
ANALYTICS_API_KEY=your-analytics-api-key

# Feature Flags
ENABLE_REGISTRATION=true
ENABLE_EMAIL_VERIFICATION=false
ENABLE_FILE_UPLOADS=true
ENABLE_ANALYTICS=false

# Logging
LOG_LEVEL=info
LOG_FORMAT=json

# Development Only
DEBUG=app:*
SEED_DATABASE=false
```

#### Platform-Specific Environment Variables

**Digital Ocean App Platform:**
```yaml
# Environment variables in app.yaml
envs:
  - key: NODE_ENV
    value: "production"
  - key: DATABASE_URL
    value: "${db.DATABASE_URL}"
  - key: JWT_SECRET
    value: "your-production-jwt-secret"
    type: SECRET
  - key: CORS_ORIGIN
    value: "${frontend.PUBLIC_URL}"
  - key: EMAIL_SERVICE_API_KEY
    value: "your-email-api-key"
    type: SECRET
```

**Railway:**
```bash
# Set via Railway CLI
railway variables set NODE_ENV=production
railway variables set JWT_SECRET=your-production-jwt-secret
railway variables set DATABASE_URL=${{Postgres.DATABASE_URL}}
railway variables set CORS_ORIGIN=https://frontend-production-xxxx.up.railway.app
```

**Render:**
```yaml
# In render.yaml
envVars:
  - key: NODE_ENV
    value: production
  - key: DATABASE_URL
    fromDatabase:
      name: nx-database
      property: connectionString
  - key: JWT_SECRET
    generateValue: true
  - key: CORS_ORIGIN
    value: https://nx-frontend.onrender.com
```

---

## 📚 Additional Resources

### Related Documentation
- **[Implementation Guide](./implementation-guide.md)** - Step-by-step deployment instructions
- **[Digital Ocean Deployment](./digital-ocean-deployment.md)** - Platform-specific deployment guide
- **[Free Platform Deployment](./free-platform-deployment.md)** - Free tier deployment strategies
- **[Best Practices](./best-practices.md)** - Production optimization techniques

### External Resources
- [Nx Documentation](https://nx.dev/getting-started/intro)
- [Digital Ocean App Platform Docs](https://docs.digitalocean.com/products/app-platform/)
- [Railway Documentation](https://docs.railway.app/)
- [Render Documentation](https://render.com/docs)
- [Vercel Documentation](https://vercel.com/docs)

---

*These template examples provide production-ready configurations for deploying Nx monorepo projects to various managed platforms. Customize the templates based on your specific application requirements and platform choices.*