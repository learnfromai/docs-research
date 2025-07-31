# Template Examples: Complete Configuration Files

## 🎯 Overview

This document provides complete, working configuration files and templates for deploying Nx React/Express applications to Railway.com using the recommended single deployment strategy.

## 📁 Complete Project Structure

```
clinic-management-system/
├── .github/
│   └── workflows/
│       └── railway-deploy.yml
├── apps/
│   ├── client/                     # React PWA Frontend
│   │   ├── public/
│   │   │   ├── icons/
│   │   │   ├── manifest.json
│   │   │   ├── sw.js
│   │   │   └── offline.html
│   │   ├── src/
│   │   ├── vite.config.ts
│   │   └── project.json
│   └── api/                        # Express Backend
│       ├── src/
│       │   ├── main.ts
│       │   ├── routes/
│       │   └── middleware/
│       └── project.json
├── libs/
│   ├── shared-types/
│   ├── database/
│   └── utils/
├── railway.json
├── package.json
├── nx.json
├── .env.example
└── README.md
```

## 📦 Package.json Configuration

```json
{
  "name": "clinic-management-system",
  "version": "1.0.0",
  "description": "Professional clinic management PWA system",
  "main": "dist/apps/api/main.js",
  "engines": {
    "node": ">=18.0.0",
    "npm": ">=9.0.0"
  },
  "scripts": {
    "dev": "nx serve api & nx serve client",
    "build": "nx build client && nx build api",
    "build:prod": "NODE_ENV=production nx build client --prod && nx build api --prod",
    "start": "nx serve api",
    "start:prod": "node dist/apps/api/main.js",
    "test": "nx test",
    "test:e2e": "nx e2e",
    "lint": "nx lint",
    "format": "nx format",
    "db:migrate": "npx prisma migrate deploy",
    "db:seed": "npx prisma db seed",
    "db:studio": "npx prisma studio",
    "db:backup": "node scripts/db-backup.js",
    "railway:build": "npm ci && npm run build:prod",
    "railway:start": "npm run start:prod",
    "railway:release": "npm run db:migrate && npm run db:seed",
    "health:check": "curl -f http://localhost:3000/api/health || exit 1"
  },
  "dependencies": {
    "@nestjs/common": "^10.0.0",
    "@nestjs/core": "^10.0.0",
    "@nestjs/platform-express": "^10.0.0",
    "express": "^4.18.2",
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-router-dom": "^6.8.0",
    "@mui/material": "^5.11.0",
    "@emotion/react": "^11.10.5",
    "@emotion/styled": "^11.10.5",
    "axios": "^1.3.0",
    "bcrypt": "^5.1.0",
    "jsonwebtoken": "^9.0.0",
    "helmet": "^6.0.1",
    "compression": "^1.7.4",
    "cors": "^2.8.5",
    "express-rate-limit": "^6.7.0",
    "winston": "^3.8.2",
    "pg": "^8.9.0",
    "prisma": "^4.10.0",
    "@prisma/client": "^4.10.0",
    "date-fns": "^2.29.3",
    "lodash-es": "^4.17.21",
    "zod": "^3.20.6"
  },
  "devDependencies": {
    "@nrwl/workspace": "^15.7.1",
    "@nrwl/react": "^15.7.1",
    "@nrwl/express": "^15.7.1",
    "@nrwl/vite": "^15.7.1",
    "@nrwl/jest": "^15.7.1",
    "@nrwl/cypress": "^15.7.1",
    "@nrwl/eslint-plugin-nx": "^15.7.1",
    "@vitejs/plugin-react": "^3.1.0",
    "vite": "^4.1.0",
    "vite-plugin-pwa": "^0.14.4",
    "typescript": "^4.9.5",
    "@types/node": "^18.14.0",
    "@types/express": "^4.17.17",
    "@types/bcrypt": "^5.0.0",
    "@types/jsonwebtoken": "^9.0.1",
    "@types/compression": "^1.7.2",
    "@types/cors": "^2.8.13",
    "@typescript-eslint/eslint-plugin": "^5.54.0",
    "@typescript-eslint/parser": "^5.54.0",
    "eslint": "^8.35.0",
    "eslint-plugin-react": "^7.32.2",
    "eslint-plugin-react-hooks": "^4.6.0",
    "prettier": "^2.8.4",
    "jest": "^29.4.3",
    "cypress": "^12.6.0"
  },
  "prisma": {
    "seed": "node dist/libs/database/src/seed.js"
  }
}
```

## 🚂 Railway Configuration

### railway.json
```json
{
  "$schema": "https://railway.app/railway.schema.json",
  "build": {
    "builder": "NIXPACKS",
    "buildCommand": "npm ci && npm run build:prod",
    "watchPatterns": [
      "apps/**/*",
      "libs/**/*",
      "package.json",
      "nx.json",
      "tsconfig.base.json"
    ]
  },
  "deploy": {
    "startCommand": "npm run start:prod",
    "healthcheckPath": "/api/health",
    "healthcheckTimeout": 300,
    "restartPolicyType": "ON_FAILURE",
    "restartPolicyMaxRetries": 3,
    "cronJobs": [
      {
        "schedule": "0 2 * * *",
        "command": "npm run db:backup"
      },
      {
        "schedule": "0 */6 * * *",
        "command": "node scripts/cleanup-logs.js"
      }
    ]
  },
  "environments": {
    "production": {
      "variables": {
        "NODE_ENV": "production",
        "LOG_LEVEL": "info",
        "DB_POOL_MAX": "20",
        "ENABLE_COMPRESSION": "true"
      }
    },
    "staging": {
      "variables": {
        "NODE_ENV": "staging",
        "LOG_LEVEL": "debug",
        "DB_POOL_MAX": "10"
      }
    }
  }
}
```

### .env.example
```bash
# Application Configuration
NODE_ENV=development
PORT=3000
LOG_LEVEL=debug

# Database Configuration
DATABASE_URL=postgresql://username:password@localhost:5432/clinic_db
DB_POOL_MIN=2
DB_POOL_MAX=20
DB_TIMEOUT=30000
DB_SSL=false

# Security Configuration
JWT_SECRET=your-super-secret-jwt-key-here
ENCRYPTION_KEY=your-encryption-key-here
SESSION_SECRET=your-session-secret-here

# Application URLs
APP_URL=http://localhost:3000
API_BASE_URL=http://localhost:3000/api

# PWA Configuration
VAPID_PUBLIC_KEY=your-vapid-public-key
VAPID_PRIVATE_KEY=your-vapid-private-key

# External Services
TWILIO_ACCOUNT_SID=your-twilio-account-sid
TWILIO_AUTH_TOKEN=your-twilio-auth-token
SENDGRID_API_KEY=your-sendgrid-api-key

# File Upload Configuration
MAX_FILE_SIZE=10485760
UPLOAD_PATH=./uploads
```

## 🖥️ Express.js Main Application

### apps/api/src/main.ts
```typescript
import express from 'express';
import helmet from 'helmet';
import compression from 'compression';
import rateLimit from 'express-rate-limit';
import cors from 'cors';
import path from 'path';
import { createProxyMiddleware } from 'http-proxy-middleware';
import { logger } from '@clinic/logger';
import { db } from '@clinic/database';

// Import routes
import authRoutes from './routes/auth';
import patientRoutes from './routes/patients';
import appointmentRoutes from './routes/appointments';
import healthRoutes from './routes/health';

const app = express();
const port = process.env.PORT || 3000;
const isProduction = process.env.NODE_ENV === 'production';

// Trust proxy for Railway
if (isProduction) {
  app.set('trust proxy', 1);
}

// Security middleware
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'", "https://fonts.googleapis.com"],
      fontSrc: ["'self'", "https://fonts.gstatic.com"],
      scriptSrc: ["'self'", "'wasm-unsafe-eval'"],
      imgSrc: ["'self'", "data:", "https:"],
      connectSrc: ["'self'", "wss:", "https:"],
      manifestSrc: ["'self'"],
      workerSrc: ["'self'"]
    }
  },
  crossOriginEmbedderPolicy: false
}));

// Compression middleware
app.use(compression({
  level: 6,
  threshold: 1024,
  filter: (req, res) => {
    if (req.headers['x-no-compression']) return false;
    return compression.filter(req, res);
  }
}));

// CORS configuration
app.use(cors({
  origin: isProduction 
    ? [process.env.APP_URL!, 'https://*.railway.app']
    : true,
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With']
}));

// Rate limiting
const apiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100,
  message: 'Too many requests from this IP, please try again later',
  standardHeaders: true,
  legacyHeaders: false,
  handler: (req, res) => {
    logger.warn('Rate limit exceeded', { 
      ip: req.ip, 
      userAgent: req.get('User-Agent') 
    });
    res.status(429).json({ 
      error: 'Too many requests',
      retryAfter: '15 minutes'
    });
  }
});

// Request parsing
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Request logging
app.use((req, res, next) => {
  const start = Date.now();
  
  res.on('finish', () => {
    const duration = Date.now() - start;
    logger.info('HTTP Request', {
      method: req.method,
      url: req.url,
      statusCode: res.statusCode,
      duration,
      userAgent: req.get('User-Agent'),
      ip: req.ip
    });
  });
  
  next();
});

// Health check (before rate limiting)
app.use('/api/health', healthRoutes);

// Apply rate limiting to API routes
app.use('/api', apiLimiter);

// API routes
app.use('/api/auth', authRoutes);
app.use('/api/patients', patientRoutes);
app.use('/api/appointments', appointmentRoutes);

// Static file serving with optimized caching
const staticPath = path.join(__dirname, '../../../dist/apps/client');

// Check if static files exist
import fs from 'fs';
if (!fs.existsSync(staticPath)) {
  logger.error('Static files directory not found', { path: staticPath });
  process.exit(1);
}

app.use(express.static(staticPath, {
  maxAge: isProduction ? '1y' : '0',
  etag: true,
  lastModified: true,
  index: false,
  setHeaders: (res, filePath, stat) => {
    // Cache headers for different file types
    if (filePath.endsWith('.html')) {
      res.setHeader('Cache-Control', 'no-cache, must-revalidate');
    } else if (filePath.includes('sw.js')) {
      res.setHeader('Cache-Control', 'no-cache');
    } else if (filePath.match(/\.(js|css|woff2?)$/)) {
      res.setHeader('Cache-Control', 'public, max-age=31536000, immutable');
    } else if (filePath.match(/\.(png|jpg|jpeg|gif|ico|svg)$/)) {
      res.setHeader('Cache-Control', 'public, max-age=2592000'); // 30 days
    }
  }
}));

// SPA fallback - MUST be last
app.get('*', (req, res) => {
  // Don't serve SPA for API routes or files with extensions
  if (req.path.startsWith('/api') || path.extname(req.path)) {
    return res.status(404).json({ error: 'Not found' });
  }
  
  res.sendFile(path.join(staticPath, 'index.html'));
});

// Global error handler
app.use((err: Error, req: express.Request, res: express.Response, next: express.NextFunction) => {
  logger.error('Unhandled error', {
    error: err.message,
    stack: err.stack,
    url: req.url,
    method: req.method
  });
  
  if (isProduction) {
    res.status(500).json({ error: 'Internal server error' });
  } else {
    res.status(500).json({ 
      error: err.message, 
      stack: err.stack 
    });
  }
});

// Graceful shutdown
process.on('SIGTERM', async () => {
  logger.info('SIGTERM received, shutting down gracefully...');
  
  try {
    await db.end();
    logger.info('Database connections closed');
    process.exit(0);
  } catch (error) {
    logger.error('Error during shutdown', { error });
    process.exit(1);
  }
});

process.on('SIGINT', async () => {
  logger.info('SIGINT received, shutting down gracefully...');
  process.exit(0);
});

// Start server
app.listen(port, () => {
  logger.info('Server started', {
    port,
    environment: process.env.NODE_ENV,
    staticPath,
    timestamp: new Date().toISOString()
  });
  
  if (isProduction) {
    logger.info('PWA available', { url: process.env.APP_URL });
  }
});

export default app;
```

## ⚛️ React PWA Configuration

### apps/client/vite.config.ts
```typescript
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { VitePWA } from 'vite-plugin-pwa';
import path from 'path';

export default defineConfig({
  plugins: [
    react(),
    VitePWA({
      registerType: 'autoUpdate',
      workbox: {
        globPatterns: ['**/*.{js,css,html,ico,png,svg,woff2}'],
        maximumFileSizeToCacheInBytes: 3000000, // 3MB
        runtimeCaching: [
          {
            urlPattern: /^https:\/\/[^\/]+\/api\/.*/i,
            handler: 'NetworkFirst',
            options: {
              cacheName: 'clinic-api-cache',
              networkTimeoutSeconds: 10,
              cacheableResponse: {
                statuses: [0, 200]
              },
              backgroundSync: {
                name: 'api-sync',
                options: {
                  maxRetentionTime: 24 * 60 // 24 hours
                }
              }
            }
          },
          {
            urlPattern: /^https:\/\/fonts\.googleapis\.com\/.*/i,
            handler: 'CacheFirst',
            options: {
              cacheName: 'google-fonts-stylesheets',
            }
          },
          {
            urlPattern: /^https:\/\/fonts\.gstatic\.com\/.*/i,
            handler: 'CacheFirst',
            options: {
              cacheName: 'google-fonts-webfonts',
              cacheableResponse: {
                statuses: [0, 200],
              },
              expiration: {
                maxAgeSeconds: 60 * 60 * 24 * 365, // 1 year
              },
            },
          }
        ],
        skipWaiting: true,
        clientsClaim: true
      },
      includeAssets: ['favicon.ico', 'apple-touch-icon.png', 'masked-icon.svg'],
      manifest: {
        name: 'Clinic Management System',
        short_name: 'ClinicCMS',
        description: 'Professional clinic management and patient records system',
        theme_color: '#1976d2',
        background_color: '#ffffff',
        display: 'standalone',
        orientation: 'portrait-primary',
        scope: '/',
        start_url: '/',
        categories: ['health', 'medical', 'productivity'],
        lang: 'en-US',
        icons: [
          {
            src: 'icons/pwa-64x64.png',
            sizes: '64x64',
            type: 'image/png'
          },
          {
            src: 'icons/pwa-192x192.png',
            sizes: '192x192',
            type: 'image/png',
            purpose: 'any'
          },
          {
            src: 'icons/pwa-192x192.png',
            sizes: '192x192',
            type: 'image/png',
            purpose: 'maskable'
          },
          {
            src: 'icons/pwa-512x512.png',
            sizes: '512x512',
            type: 'image/png'
          },
          {
            src: 'icons/maskable-icon-512x512.png',
            sizes: '512x512',
            type: 'image/png',
            purpose: 'maskable'
          }
        ],
        shortcuts: [
          {
            name: 'Patient Search',
            short_name: 'Patients',
            description: 'Search and manage patient records',
            url: '/patients',
            icons: [{ src: 'icons/patients-96x96.png', sizes: '96x96' }]
          },
          {
            name: "Today's Appointments",
            short_name: 'Appointments',
            description: "View today's appointment schedule",
            url: '/appointments/today',
            icons: [{ src: 'icons/calendar-96x96.png', sizes: '96x96' }]
          }
        ]
      },
      devOptions: {
        enabled: true,
        type: 'module'
      }
    })
  ],
  build: {
    outDir: '../../dist/apps/client',
    emptyOutDir: true,
    target: 'es2018',
    rollupOptions: {
      output: {
        manualChunks: {
          'patient-management': [
            './src/features/patients/PatientList.tsx',
            './src/features/patients/PatientForm.tsx',
            './src/features/patients/PatientDetails.tsx'
          ],
          'appointment-booking': [
            './src/features/appointments/AppointmentCalendar.tsx',
            './src/features/appointments/AppointmentForm.tsx'
          ],
          'medical-records': [
            './src/features/records/MedicalRecords.tsx',
            './src/features/records/RecordForm.tsx'
          ],
          vendor: [
            'react',
            'react-dom',
            'react-router-dom',
            '@mui/material'
          ],
          utils: [
            'date-fns',
            'lodash-es',
            'axios'
          ]
        }
      }
    },
    chunkSizeWarningLimit: 1000
  },
  server: {
    port: 4200,
    proxy: {
      '/api': {
        target: 'http://localhost:3000',
        changeOrigin: true,
        secure: false
      }
    }
  },
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
      '@clinic': path.resolve(__dirname, '../../libs')
    }
  }
});
```

### apps/client/project.json
```json
{
  "name": "client",
  "$schema": "../../node_modules/nx/schemas/project-schema.json",
  "projectType": "application",
  "sourceRoot": "apps/client/src",
  "targets": {
    "build": {
      "executor": "@nrwl/vite:build",
      "outputs": ["{options.outputPath}"],
      "defaultConfiguration": "production",
      "options": {
        "outputPath": "dist/apps/client"
      },
      "configurations": {
        "development": {
          "mode": "development",
          "sourcemap": true
        },
        "production": {
          "mode": "production",
          "sourcemap": false,
          "optimization": true
        }
      }
    },
    "serve": {
      "executor": "@nrwl/vite:dev-server",
      "defaultConfiguration": "development",
      "options": {
        "buildTarget": "client:build"
      },
      "configurations": {
        "development": {
          "buildTarget": "client:build:development",
          "hmr": true,
          "open": true
        },
        "production": {
          "buildTarget": "client:build:production",
          "hmr": false
        }
      }
    },
    "preview": {
      "executor": "@nrwl/vite:preview-server",
      "defaultConfiguration": "development",
      "options": {
        "buildTarget": "client:build"
      }
    },
    "test": {
      "executor": "@nrwl/vite:test",
      "outputs": ["coverage/apps/client"],
      "options": {
        "passWithNoTests": true,
        "reportsDirectory": "../../coverage/apps/client"
      }
    },
    "lint": {
      "executor": "@nrwl/linter:eslint",
      "outputs": ["{options.outputFile}"],
      "options": {
        "lintFilePatterns": ["apps/client/**/*.{ts,tsx,js,jsx}"]
      }
    }
  },
  "tags": ["scope:client", "type:app"]
}
```

## 🔧 API Configuration

### apps/api/project.json
```json
{
  "name": "api",
  "$schema": "../../node_modules/nx/schemas/project-schema.json",
  "projectType": "application",
  "sourceRoot": "apps/api/src",
  "targets": {
    "build": {
      "executor": "@nrwl/webpack:webpack",
      "outputs": ["{options.outputPath}"],
      "defaultConfiguration": "production",
      "options": {
        "target": "node",
        "compiler": "tsc",
        "outputPath": "dist/apps/api",
        "main": "apps/api/src/main.ts",
        "tsConfig": "apps/api/tsconfig.app.json",
        "assets": [
          "apps/api/src/assets",
          {
            "glob": "**/*",
            "input": "libs/database/src/migrations",
            "output": "migrations"
          }
        ],
        "generatePackageJson": true,
        "optimization": false,
        "extractLicenses": false,
        "inspect": false
      },
      "configurations": {
        "development": {
          "optimization": false,
          "extractLicenses": false,
          "inspect": false,
          "fileReplacements": [
            {
              "replace": "apps/api/src/environments/environment.ts",
              "with": "apps/api/src/environments/environment.dev.ts"
            }
          ]
        },
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
      "executor": "@nrwl/node:execute",
      "defaultConfiguration": "development",
      "options": {
        "buildTarget": "api:build"
      },
      "configurations": {
        "development": {
          "buildTarget": "api:build:development"
        },
        "production": {
          "buildTarget": "api:build:production"
        }
      }
    },
    "test": {
      "executor": "@nrwl/jest:jest",
      "outputs": ["coverage/apps/api"],
      "options": {
        "jestConfig": "apps/api/jest.config.ts",
        "passWithNoTests": true
      }
    },
    "lint": {
      "executor": "@nrwl/linter:eslint",
      "outputs": ["{options.outputFile}"],
      "options": {
        "lintFilePatterns": ["apps/api/**/*.ts"]
      }
    }
  },
  "tags": ["scope:api", "type:app"]
}
```

## 🚀 CI/CD Configuration

### .github/workflows/railway-deploy.yml
```yaml
name: Railway Deployment

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

env:
  NODE_VERSION: '18'

jobs:
  test:
    name: Test & Build
    runs-on: ubuntu-latest
    
    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_DB: clinic_test
          POSTGRES_USER: test
          POSTGRES_PASSWORD: test
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 5432:5432

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

      - name: Install dependencies
        run: npm ci

      - name: Lint code
        run: npm run lint

      - name: Run tests
        run: npm run test
        env:
          DATABASE_URL: postgresql://test:test@localhost:5432/clinic_test

      - name: Build application
        run: npm run build:prod

      - name: Run E2E tests
        run: npm run test:e2e
        if: github.event_name == 'pull_request'

      - name: Upload build artifacts
        uses: actions/upload-artifact@v3
        with:
          name: dist
          path: dist/
          retention-days: 1

  deploy-staging:
    name: Deploy to Staging
    runs-on: ubuntu-latest
    needs: test
    if: github.ref == 'refs/heads/develop'
    
    environment:
      name: staging
      url: https://clinic-app-staging.up.railway.app

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: 'npm'

      - name: Install Railway CLI
        run: npm install -g @railway/cli

      - name: Deploy to Railway Staging
        run: railway up --service clinic-app-staging --environment staging
        env:
          RAILWAY_TOKEN: ${{ secrets.RAILWAY_TOKEN }}

      - name: Run health check
        run: |
          sleep 30  # Wait for deployment
          curl -f https://clinic-app-staging.up.railway.app/api/health

  deploy-production:
    name: Deploy to Production
    runs-on: ubuntu-latest
    needs: test
    if: github.ref == 'refs/heads/main'
    
    environment:
      name: production
      url: https://clinic-app.up.railway.app

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: 'npm'

      - name: Install Railway CLI
        run: npm install -g @railway/cli

      - name: Deploy to Railway Production
        run: railway up --service clinic-app --environment production
        env:
          RAILWAY_TOKEN: ${{ secrets.RAILWAY_TOKEN }}

      - name: Run health check
        run: |
          sleep 60  # Wait for deployment and migrations
          curl -f https://clinic-app.up.railway.app/api/health

      - name: Run Lighthouse CI
        uses: treosh/lighthouse-ci-action@v9
        with:
          urls: https://clinic-app.up.railway.app
          configPath: './lighthouserc.json'
          uploadArtifacts: true
        if: success()

  notify:
    name: Notify Deployment Status
    runs-on: ubuntu-latest
    needs: [deploy-production, deploy-staging]
    if: always()

    steps:
      - name: Notify success
        if: ${{ needs.deploy-production.result == 'success' || needs.deploy-staging.result == 'success' }}
        run: echo "✅ Deployment successful!"

      - name: Notify failure
        if: ${{ needs.deploy-production.result == 'failure' || needs.deploy-staging.result == 'failure' }}
        run: echo "❌ Deployment failed!"
```

## 🔍 Health Check & Monitoring

### apps/api/src/routes/health.ts
```typescript
import express from 'express';
import { Pool } from 'pg';
import { logger } from '@clinic/logger';

const router = express.Router();
const db = new Pool({ connectionString: process.env.DATABASE_URL });

interface HealthCheck {
  status: 'healthy' | 'degraded' | 'unhealthy';
  timestamp: string;
  uptime: number;
  environment: string;
  version: string;
  services: {
    database: {
      status: 'connected' | 'disconnected';
      responseTime?: number;
    };
    memory: {
      used: number;
      free: number;
      total: number;
      percentage: number;
    };
    disk?: {
      free: number;
      used: number;
      total: number;
      percentage: number;
    };
  };
  checks: {
    name: string;
    status: 'pass' | 'fail';
    time: number;
    output?: string;
  }[];
}

router.get('/', async (req, res) => {
  const startTime = Date.now();
  const checks: HealthCheck['checks'] = [];

  try {
    // Database connectivity check
    const dbStartTime = Date.now();
    let dbStatus: 'connected' | 'disconnected' = 'disconnected';
    let dbResponseTime = 0;

    try {
      await db.query('SELECT NOW()');
      dbStatus = 'connected';
      dbResponseTime = Date.now() - dbStartTime;
      checks.push({
        name: 'database',
        status: 'pass',
        time: dbResponseTime,
        output: 'Database connection successful'
      });
    } catch (error) {
      dbResponseTime = Date.now() - dbStartTime;
      checks.push({
        name: 'database',
        status: 'fail',
        time: dbResponseTime,
        output: `Database connection failed: ${error.message}`
      });
    }

    // Memory usage check
    const memUsage = process.memoryUsage();
    const totalMem = memUsage.heapTotal;
    const usedMem = memUsage.heapUsed;
    const freeMem = totalMem - usedMem;
    const memPercentage = (usedMem / totalMem) * 100;

    checks.push({
      name: 'memory',
      status: memPercentage < 90 ? 'pass' : 'fail',
      time: 0,
      output: `Memory usage: ${memPercentage.toFixed(2)}%`
    });

    // Determine overall health status
    const hasFailures = checks.some(check => check.status === 'fail');
    const hasCriticalFailures = checks.some(check => 
      check.name === 'database' && check.status === 'fail'
    );

    let overallStatus: 'healthy' | 'degraded' | 'unhealthy';
    if (hasCriticalFailures) {
      overallStatus = 'unhealthy';
    } else if (hasFailures) {
      overallStatus = 'degraded';
    } else {
      overallStatus = 'healthy';
    }

    const health: HealthCheck = {
      status: overallStatus,
      timestamp: new Date().toISOString(),
      uptime: Math.round(process.uptime()),
      environment: process.env.NODE_ENV || 'development',
      version: process.env.npm_package_version || '1.0.0',
      services: {
        database: {
          status: dbStatus,
          responseTime: dbResponseTime
        },
        memory: {
          used: Math.round(usedMem / 1024 / 1024), // MB
          free: Math.round(freeMem / 1024 / 1024), // MB
          total: Math.round(totalMem / 1024 / 1024), // MB
          percentage: Math.round(memPercentage)
        }
      },
      checks
    };

    // Log health check if degraded or unhealthy
    if (overallStatus !== 'healthy') {
      logger.warn('Health check failed', { health });
    }

    const statusCode = overallStatus === 'healthy' ? 200 : 
                      overallStatus === 'degraded' ? 200 : 503;
    
    res.status(statusCode).json(health);
  } catch (error) {
    logger.error('Health check error', { error: error.message });
    
    res.status(503).json({
      status: 'unhealthy',
      timestamp: new Date().toISOString(),
      error: 'Health check failed',
      checks: [{
        name: 'health-check',
        status: 'fail',
        time: Date.now() - startTime,
        output: error.message
      }]
    });
  }
});

// Readiness probe for Railway
router.get('/ready', async (req, res) => {
  try {
    await db.query('SELECT 1');
    res.status(200).json({ status: 'ready' });
  } catch (error) {
    res.status(503).json({ status: 'not ready', error: error.message });
  }
});

// Liveness probe
router.get('/live', (req, res) => {
  res.status(200).json({ 
    status: 'alive',
    timestamp: new Date().toISOString(),
    uptime: process.uptime()
  });
});

export default router;
```

## 📋 Performance Configuration

### lighthouserc.json
```json
{
  "ci": {
    "collect": {
      "url": ["https://clinic-app.up.railway.app"],
      "numberOfRuns": 3,
      "settings": {
        "chromeFlags": "--no-sandbox --headless",
        "preset": "desktop"
      }
    },
    "assert": {
      "assertions": {
        "categories:performance": ["error", {"minScore": 0.9}],
        "categories:pwa": ["error", {"minScore": 0.9}],
        "categories:accessibility": ["error", {"minScore": 0.95}],
        "categories:best-practices": ["error", {"minScore": 0.9}],
        "categories:seo": ["error", {"minScore": 0.8}],
        "first-contentful-paint": ["error", {"maxNumericValue": 2000}],
        "largest-contentful-paint": ["error", {"maxNumericValue": 2500}],
        "interactive": ["error", {"maxNumericValue": 3000}],
        "cumulative-layout-shift": ["error", {"maxNumericValue": 0.1}]
      }
    },
    "upload": {
      "target": "temporary-public-storage"
    }
  }
}
```

---

## 🔗 Navigation

**← Previous:** [Deployment Guide](./deployment-guide.md) | **Next:** [Troubleshooting](./troubleshooting.md) →

**Related Sections:**
- [Implementation Guide](./implementation-guide.md) - Step-by-step deployment instructions
- [Best Practices](./best-practices.md) - Railway-specific optimization patterns