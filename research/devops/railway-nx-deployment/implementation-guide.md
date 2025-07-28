# Implementation Guide: Railway.com Deployment for Nx Applications

## 🚀 Quick Start Overview

This guide provides step-by-step instructions for implementing both deployment approaches on Railway.com. Choose the approach that best fits your needs based on the [comparison analysis](./comparison-analysis.md).

## 📋 Prerequisites

### Development Environment
- Node.js 18+ installed
- Nx workspace set up with React (Vite) and Express apps
- Git repository with your Nx monorepo
- Railway.com account (free tier available)

### Nx Project Structure
```
my-clinic-app/
├── apps/
│   ├── frontend/          # React + Vite app
│   └── backend/           # Express.js API
├── libs/                  # Shared libraries
├── package.json
└── nx.json
```

---

## 🎯 Approach 1: Separate Deployment (Recommended)

### Step 1: Prepare React App for Static Deployment

#### 1.1 Configure Vite Build
```typescript
// apps/frontend/vite.config.ts
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  build: {
    outDir: 'dist',
    sourcemap: true,
    assetsDir: 'assets'
  },
  base: '/', // Important for Railway static hosting
  server: {
    port: 4200
  }
})
```

#### 1.2 Add Railway Static Site Configuration
```json
// apps/frontend/railway.json
{
  "builder": "NIXPACKS",
  "buildCommand": "npm run build:frontend",
  "staticPublishPath": "dist/apps/frontend"
}
```

#### 1.3 Update Package.json Scripts
```json
{
  "scripts": {
    "build:frontend": "nx build frontend --prod",
    "build:backend": "nx build backend --prod"
  }
}
```

### Step 2: Configure Express Backend

#### 2.1 Add CORS Support
```typescript
// apps/backend/src/main.ts
import express from 'express'
import cors from 'cors'

const app = express()

// CORS configuration for separate deployment
app.use(cors({
  origin: [
    'http://localhost:4200',           // Development
    process.env.FRONTEND_URL           // Production
  ],
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH'],
  allowedHeaders: ['Content-Type', 'Authorization']
}))

app.use(express.json())

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() })
})

// API routes
app.use('/api', apiRoutes)

const port = process.env.PORT || 3000
app.listen(port, () => {
  console.log(`🚀 Backend running on port ${port}`)
})
```

#### 2.2 Environment Variables Setup
```bash
# apps/backend/.env.example
NODE_ENV=production
PORT=3000
FRONTEND_URL=https://your-frontend.railway.app
DATABASE_URL=postgresql://user:pass@host:port/db
JWT_SECRET=your-jwt-secret
```

### Step 3: Deploy to Railway

#### 3.1 Install Railway CLI
```bash
npm install -g @railway/cli
railway login
```

#### 3.2 Create Railway Projects
```bash
# Create separate projects for frontend and backend
railway project create clinic-frontend
railway project create clinic-backend
```

#### 3.3 Deploy Frontend (Static Site)
```bash
# Switch to frontend project
railway project use clinic-frontend

# Link to frontend directory
cd apps/frontend

# Deploy static site
railway up

# Set build command
railway env set NIXPACKS_BUILD_CMD="npm run build:frontend"
railway env set NIXPACKS_INSTALL_CMD="npm install"
```

#### 3.4 Deploy Backend (Web Service)
```bash
# Switch to backend project  
railway project use clinic-backend

# Link to backend directory
cd apps/backend

# Deploy web service
railway up

# Set environment variables
railway env set NODE_ENV=production
railway env set FRONTEND_URL=https://your-frontend.railway.app
```

### Step 4: Configure CI/CD with GitHub Actions

#### 4.1 Create GitHub Actions Workflow
```yaml
# .github/workflows/deploy-railway.yml
name: Deploy to Railway

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  deploy-frontend:
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: ./apps/frontend
    
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        
      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '18'
          cache: 'npm'
          
      - name: Install dependencies
        run: npm ci
        
      - name: Build frontend
        run: npm run build:frontend
        
      - name: Deploy to Railway
        uses: railway/cli@v1
        with:
          command: 'up --service frontend'
        env:
          RAILWAY_TOKEN: ${{ secrets.RAILWAY_TOKEN }}

  deploy-backend:
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: ./apps/backend
        
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        
      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '18'
          cache: 'npm'
          
      - name: Install dependencies
        run: npm ci
        
      - name: Build backend
        run: npm run build:backend
        
      - name: Deploy to Railway
        uses: railway/cli@v1
        with:
          command: 'up --service backend'
        env:
          RAILWAY_TOKEN: ${{ secrets.RAILWAY_TOKEN }}
```

---

## 🔄 Approach 2: Unified Deployment (Alternative)

### Step 1: Configure Express to Serve React

#### 1.1 Update Express Server
```typescript
// apps/backend/src/main.ts
import express from 'express'
import path from 'path'

const app = express()

app.use(express.json())

// Serve static files from React build
const frontendPath = path.join(__dirname, '../frontend')
app.use(express.static(frontendPath))

// API routes (must come before catch-all)
app.use('/api', apiRoutes)

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok' })
})

// Catch-all handler for React Router
app.get('*', (req, res) => {
  res.sendFile(path.join(frontendPath, 'index.html'))
})

const port = process.env.PORT || 3000
app.listen(port, () => {
  console.log(`🚀 Server running on port ${port}`)
})
```

#### 1.2 Update Build Configuration
```json
// package.json
{
  "scripts": {
    "build": "nx build frontend --prod && nx build backend --prod",
    "build:frontend": "nx build frontend --prod",
    "build:backend": "nx build backend --prod",
    "start": "node dist/apps/backend/main.js"
  }
}
```

#### 1.3 Configure Railway Deployment
```json
// railway.json
{
  "builder": "NIXPACKS",
  "buildCommand": "npm run build",
  "startCommand": "npm start"
}
```

### Step 2: Deploy Unified Service

#### 2.1 Single Railway Project
```bash
railway project create clinic-app
railway up

# Set environment variables
railway env set NODE_ENV=production
railway env set PORT=3000
```

#### 2.2 GitHub Actions for Unified Deployment
```yaml
# .github/workflows/deploy-unified.yml
name: Deploy Unified App to Railway

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        
      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '18'
          cache: 'npm'
          
      - name: Install dependencies
        run: npm ci
        
      - name: Build application
        run: npm run build
        
      - name: Deploy to Railway
        uses: railway/cli@v1
        with:
          command: 'up'
        env:
          RAILWAY_TOKEN: ${{ secrets.RAILWAY_TOKEN }}
```

---

## 🔧 PWA Implementation (Recommended for Separate Deployment)

### Step 1: Add PWA Configuration

#### 1.1 Install PWA Dependencies
```bash
npm install --save-dev vite-plugin-pwa workbox-window
```

#### 1.2 Configure PWA in Vite
```typescript
// apps/frontend/vite.config.ts
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import { VitePWA } from 'vite-plugin-pwa'

export default defineConfig({
  plugins: [
    react(),
    VitePWA({
      registerType: 'autoUpdate',
      workbox: {
        globPatterns: ['**/*.{js,css,html,ico,png,svg}'],
        runtimeCaching: [
          {
            urlPattern: ({ request }) => request.destination === 'document',
            handler: 'NetworkFirst',
            options: {
              cacheName: 'html-cache',
              expiration: {
                maxEntries: 10,
                maxAgeSeconds: 60 * 60 * 24 * 7 // 1 week
              }
            }
          },
          {
            urlPattern: /^https:\/\/your-backend\.railway\.app\/api\/.*/,
            handler: 'NetworkFirst',
            options: {
              cacheName: 'api-cache',
              expiration: {
                maxEntries: 50,
                maxAgeSeconds: 60 * 60 * 24 // 1 day
              }
            }
          }
        ]
      },
      manifest: {
        name: 'Clinic Management System',
        short_name: 'Clinic App',
        description: 'Efficient clinic management for healthcare professionals',
        theme_color: '#2563eb',
        background_color: '#ffffff',
        display: 'standalone',
        orientation: 'portrait',
        scope: '/',
        start_url: '/',
        icons: [
          {
            src: '/icon-192.png',
            sizes: '192x192',
            type: 'image/png'
          },
          {
            src: '/icon-512.png',
            sizes: '512x512',
            type: 'image/png'
          }
        ]
      }
    })
  ]
})
```

#### 1.3 Add PWA Service Worker Registration
```typescript
// apps/frontend/src/main.tsx
import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './app/App'

// PWA Service Worker Registration
if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('/sw.js')
      .then((registration) => {
        console.log('SW registered: ', registration)
      })
      .catch((registrationError) => {
        console.log('SW registration failed: ', registrationError)
      })
  })
}

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
)
```

---

## ✅ Verification & Testing

### Step 1: Local Testing

#### Test Separate Deployment Locally
```bash
# Terminal 1: Start backend
cd apps/backend
npm run serve

# Terminal 2: Start frontend  
cd apps/frontend
npm run dev

# Test CORS by accessing frontend at localhost:4200
```

#### Test Unified Deployment Locally
```bash
# Build and start unified app
npm run build
npm start

# Access at localhost:3000
```

### Step 2: Production Verification

#### Check Deployment Status
```bash
# Check Railway deployments
railway status

# View logs
railway logs
```

#### Performance Testing
```bash
# Test with curl
curl -I https://your-frontend.railway.app
curl -I https://your-backend.railway.app/health

# Test PWA features
# - Open app in mobile browser
# - Add to home screen
# - Test offline functionality
```

---

## 🚨 Common Issues & Solutions

### CORS Issues (Separate Deployment)
```typescript
// Add specific origins
app.use(cors({
  origin: [
    'http://localhost:4200',
    'https://your-frontend.railway.app'
  ]
}))
```

### Build Path Issues (Unified Deployment)
```typescript
// Ensure correct path resolution
const frontendPath = path.resolve(__dirname, '../frontend')
console.log('Serving static files from:', frontendPath)
```

### Environment Variables
```bash
# Set in Railway dashboard or CLI
railway env set FRONTEND_URL=https://your-frontend.railway.app
railway env set NODE_ENV=production
```

---

## 🔗 Navigation

← [Back: Comparison Analysis](./comparison-analysis.md) | [Next: Best Practices](./best-practices.md) →