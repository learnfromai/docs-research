# Best Practices: Production-Ready Nx Deployments

## 🎯 Overview

This guide outlines production-ready best practices for deploying Nx monorepos to managed platforms, ensuring security, performance, reliability, and smooth client handovers.

## 🏗 Project Structure Best Practices

### Recommended Nx Workspace Structure
```
nx-project/
├── apps/
│   ├── frontend/                 # React + Vite app
│   │   ├── src/
│   │   ├── vite.config.ts
│   │   └── project.json
│   └── backend/                  # Express.js API
│       ├── src/
│       ├── webpack.config.js
│       └── project.json
├── libs/
│   ├── shared-types/             # Shared TypeScript interfaces
│   ├── ui-components/            # Reusable React components
│   └── utils/                    # Common utilities
├── tools/
│   ├── deploy/                   # Deployment scripts
│   └── migrations/               # Database migrations
├── .env.example                  # Environment template
├── .env.local                    # Local development
├── docker-compose.yml            # Local development
├── railway.toml                  # Railway configuration
└── render.yaml                   # Render configuration
```

### Environment Configuration
```typescript
// libs/shared-types/src/lib/env.ts
export interface EnvironmentConfig {
  NODE_ENV: 'development' | 'production' | 'test';
  PORT: number;
  DATABASE_URL: string;
  JWT_SECRET: string;
  CORS_ORIGIN: string[];
  API_BASE_URL: string;
}

// apps/backend/src/config/env.ts
import { EnvironmentConfig } from '@nx-project/shared-types';

export const config: EnvironmentConfig = {
  NODE_ENV: (process.env.NODE_ENV as any) || 'development',
  PORT: parseInt(process.env.PORT || '3001'),
  DATABASE_URL: process.env.DATABASE_URL || '',
  JWT_SECRET: process.env.JWT_SECRET || 'dev-secret',
  CORS_ORIGIN: process.env.CORS_ORIGIN?.split(',') || ['http://localhost:3000'],
  API_BASE_URL: process.env.API_BASE_URL || 'http://localhost:3001',
};

// Validation
const requiredEnvVars = ['DATABASE_URL', 'JWT_SECRET'];
for (const envVar of requiredEnvVars) {
  if (!process.env[envVar] && config.NODE_ENV === 'production') {
    throw new Error(`Missing required environment variable: ${envVar}`);
  }
}
```

## 🔒 Security Best Practices

### Environment Variables Management
```bash
# .env.example (commit to repo)
NODE_ENV=production
PORT=3001
DATABASE_URL=mysql://user:pass@host:port/db
JWT_SECRET=your-super-secret-key-min-32-chars
CORS_ORIGIN=https://yourdomain.com,https://www.yourdomain.com
API_RATE_LIMIT=100
BCRYPT_ROUNDS=12

# .env.local (never commit)
DATABASE_URL=mysql://localhost:3306/dev_db
JWT_SECRET=dev-secret-key-not-secure
```

### CORS Configuration
```typescript
// apps/backend/src/middleware/cors.ts
import cors from 'cors';
import { config } from '../config/env';

export const corsMiddleware = cors({
  origin: (origin, callback) => {
    // Allow requests with no origin (mobile apps, Postman, etc.)
    if (!origin && config.NODE_ENV === 'development') {
      return callback(null, true);
    }
    
    if (config.CORS_ORIGIN.includes(origin!)) {
      callback(null, true);
    } else {
      callback(new Error('Not allowed by CORS'));
    }
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
  maxAge: 86400, // 24 hours
});
```

### Authentication & Authorization
```typescript
// apps/backend/src/middleware/auth.ts
import jwt from 'jsonwebtoken';
import { Request, Response, NextFunction } from 'express';
import { config } from '../config/env';

interface AuthRequest extends Request {
  user?: { id: number; email: string };
}

export const authenticateToken = (
  req: AuthRequest,
  res: Response,
  next: NextFunction
) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1]; // Bearer TOKEN

  if (!token) {
    return res.status(401).json({ error: 'Access token required' });
  }

  jwt.verify(token, config.JWT_SECRET, (err, user) => {
    if (err) {
      return res.status(403).json({ error: 'Invalid or expired token' });
    }
    req.user = user as { id: number; email: string };
    next();
  });
};

// Rate limiting
import rateLimit from 'express-rate-limit';

export const apiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: parseInt(process.env.API_RATE_LIMIT || '100'),
  message: 'Too many requests, please try again later',
  standardHeaders: true,
  legacyHeaders: false,
});
```

### Input Validation
```typescript
// apps/backend/src/middleware/validation.ts
import { body, validationResult } from 'express-validator';
import { Request, Response, NextFunction } from 'express';

export const validateUser = [
  body('email')
    .isEmail()
    .normalizeEmail()
    .withMessage('Valid email required'),
  body('password')
    .isLength({ min: 8 })
    .matches(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/)
    .withMessage('Password must be 8+ chars with upper, lower, and number'),
  body('name')
    .trim()
    .isLength({ min: 2, max: 50 })
    .withMessage('Name must be 2-50 characters'),
];

export const handleValidationErrors = (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({
      error: 'Validation failed',
      details: errors.array()
    });
  }
  next();
};
```

## 🛠 Database Best Practices

### Connection Management
```typescript
// apps/backend/src/config/database.ts
import mysql from 'mysql2/promise';
import { config } from './env';

class DatabaseManager {
  private pool: mysql.Pool;

  constructor() {
    this.pool = mysql.createPool({
      uri: config.DATABASE_URL,
      connectionLimit: 10,
      queueLimit: 0,
      acquireTimeout: 60000,
      timeout: 60000,
      reconnect: true,
      ssl: config.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false,
    });

    // Handle pool events
    this.pool.on('connection', (connection) => {
      console.log(`MySQL connected as id ${connection.threadId}`);
    });

    this.pool.on('error', (err) => {
      console.error('MySQL pool error:', err);
      if (err.code === 'PROTOCOL_CONNECTION_LOST') {
        this.handleDisconnect();
      }
    });
  }

  private handleDisconnect() {
    console.log('Reconnecting to MySQL...');
    // Pool will automatically reconnect
  }

  async query(sql: string, params?: any[]) {
    try {
      const [results] = await this.pool.execute(sql, params);
      return results;
    } catch (error) {
      console.error('Database query error:', error);
      throw error;
    }
  }

  async transaction<T>(
    callback: (connection: mysql.PoolConnection) => Promise<T>
  ): Promise<T> {
    const connection = await this.pool.getConnection();
    
    try {
      await connection.beginTransaction();
      const result = await callback(connection);
      await connection.commit();
      return result;
    } catch (error) {
      await connection.rollback();
      throw error;
    } finally {
      connection.release();
    }
  }

  async healthCheck(): Promise<boolean> {
    try {
      await this.query('SELECT 1');
      return true;
    } catch {
      return false;
    }
  }

  async close() {
    await this.pool.end();
  }
}

export const db = new DatabaseManager();
```

### Migration System
```typescript
// tools/migrations/migrate.ts
import fs from 'fs/promises';
import path from 'path';
import { db } from '../../apps/backend/src/config/database';

interface Migration {
  id: number;
  filename: string;
  executed_at: Date;
}

class MigrationRunner {
  private migrationsDir = path.join(__dirname, 'sql');

  async initialize() {
    // Create migrations table
    await db.query(`
      CREATE TABLE IF NOT EXISTS migrations (
        id INT AUTO_INCREMENT PRIMARY KEY,
        filename VARCHAR(255) NOT NULL UNIQUE,
        executed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        checksum VARCHAR(64) NOT NULL
      )
    `);
  }

  async getPendingMigrations(): Promise<string[]> {
    const files = await fs.readdir(this.migrationsDir);
    const sqlFiles = files
      .filter(f => f.endsWith('.sql'))
      .sort();

    const executed = await db.query(
      'SELECT filename FROM migrations'
    ) as Migration[];
    
    const executedFiles = new Set(executed.map(m => m.filename));
    
    return sqlFiles.filter(file => !executedFiles.has(file));
  }

  async runMigration(filename: string) {
    const filepath = path.join(this.migrationsDir, filename);
    const sql = await fs.readFile(filepath, 'utf8');
    const checksum = this.calculateChecksum(sql);

    await db.transaction(async (connection) => {
      // Execute migration SQL
      const statements = sql.split(';').filter(s => s.trim());
      for (const statement of statements) {
        if (statement.trim()) {
          await connection.execute(statement);
        }
      }

      // Record migration
      await connection.execute(
        'INSERT INTO migrations (filename, checksum) VALUES (?, ?)',
        [filename, checksum]
      );
    });

    console.log(`✅ Executed migration: ${filename}`);
  }

  async run() {
    await this.initialize();
    const pending = await this.getPendingMigrations();

    if (pending.length === 0) {
      console.log('✅ No pending migrations');
      return;
    }

    console.log(`Running ${pending.length} migrations...`);
    
    for (const migration of pending) {
      await this.runMigration(migration);
    }

    console.log('✅ All migrations completed');
  }

  private calculateChecksum(content: string): string {
    const crypto = require('crypto');
    return crypto.createHash('sha256').update(content).digest('hex');
  }
}

// Run migrations
if (require.main === module) {
  const runner = new MigrationRunner();
  runner.run()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error('Migration failed:', error);
      process.exit(1);
    });
}
```

## 🚀 Performance Optimization

### Frontend Optimization
```typescript
// apps/frontend/vite.config.ts
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { resolve } from 'path';

export default defineConfig({
  plugins: [react()],
  
  build: {
    outDir: '../../dist/apps/frontend',
    sourcemap: process.env.NODE_ENV !== 'production',
    minify: 'esbuild',
    target: 'es2020',
    
    rollupOptions: {
      output: {
        manualChunks: {
          vendor: ['react', 'react-dom'],
          router: ['react-router-dom'],
          ui: ['@mui/material', '@emotion/react'],
        },
      },
    },
    
    // Optimize bundle size
    chunkSizeWarningLimit: 1000,
  },

  // Development optimizations
  server: {
    port: 3000,
    host: '0.0.0.0',
    hmr: {
      overlay: false, // Disable error overlay for production-like testing
    },
  },

  // Path aliases
  resolve: {
    alias: {
      '@': resolve(__dirname, 'src'),
      '@shared': resolve(__dirname, '../../libs/shared-types/src'),
    },
  },

  // Environment variables
  define: {
    __BUILD_TIME__: JSON.stringify(new Date().toISOString()),
  },
});
```

### Backend Optimization
```typescript
// apps/backend/src/middleware/compression.ts
import compression from 'compression';
import helmet from 'helmet';

export const securityMiddleware = [
  helmet({
    contentSecurityPolicy: {
      directives: {
        defaultSrc: ["'self'"],
        styleSrc: ["'self'", "'unsafe-inline'"],
        scriptSrc: ["'self'"],
        imgSrc: ["'self'", "data:", "https:"],
      },
    },
    crossOriginEmbedderPolicy: false, // For development
  }),
  
  compression({
    level: 6,
    threshold: 1024, // Only compress if larger than 1KB
    filter: (req, res) => {
      if (req.headers['x-no-compression']) return false;
      return compression.filter(req, res);
    },
  }),
];

// apps/backend/src/middleware/logging.ts
import morgan from 'morgan';

const logFormat = process.env.NODE_ENV === 'production' 
  ? 'combined' 
  : 'dev';

export const loggingMiddleware = morgan(logFormat, {
  skip: (req) => req.url === '/health', // Skip health check logs
});
```

### Caching Strategy
```typescript
// apps/backend/src/middleware/cache.ts
import { Request, Response, NextFunction } from 'express';

const cache = new Map<string, { data: any; expires: number }>();

export const cacheMiddleware = (ttl: number = 300) => {
  return (req: Request, res: Response, next: NextFunction) => {
    const key = req.originalUrl;
    const cached = cache.get(key);

    if (cached && cached.expires > Date.now()) {
      return res.json(cached.data);
    }

    // Override res.json to cache the response
    const originalJson = res.json;
    res.json = function(data: any) {
      cache.set(key, {
        data,
        expires: Date.now() + (ttl * 1000)
      });
      return originalJson.call(this, data);
    };

    next();
  };
};

// Usage in routes
app.get('/api/users', cacheMiddleware(300), async (req, res) => {
  // This response will be cached for 5 minutes
  const users = await db.query('SELECT * FROM users');
  res.json(users);
});
```

## 📊 Monitoring & Observability

### Health Checks
```typescript
// apps/backend/src/routes/health.ts
import express from 'express';
import { db } from '../config/database';

const router = express.Router();

interface HealthStatus {
  status: 'ok' | 'error';
  timestamp: string;
  uptime: number;
  version: string;
  services: {
    database: 'ok' | 'error';
    memory: {
      used: number;
      total: number;
      percentage: number;
    };
  };
}

router.get('/', async (req, res) => {
  const startTime = Date.now();
  
  try {
    // Check database
    const dbHealthy = await db.healthCheck();
    
    // Check memory usage
    const memUsage = process.memoryUsage();
    const memPercentage = (memUsage.heapUsed / memUsage.heapTotal) * 100;
    
    const health: HealthStatus = {
      status: dbHealthy ? 'ok' : 'error',
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
      version: process.env.APP_VERSION || '1.0.0',
      services: {
        database: dbHealthy ? 'ok' : 'error',
        memory: {
          used: Math.round(memUsage.heapUsed / 1024 / 1024), // MB
          total: Math.round(memUsage.heapTotal / 1024 / 1024), // MB
          percentage: Math.round(memPercentage),
        },
      },
    };

    const statusCode = health.status === 'ok' ? 200 : 503;
    res.status(statusCode).json(health);
    
  } catch (error) {
    res.status(503).json({
      status: 'error',
      timestamp: new Date().toISOString(),
      error: error instanceof Error ? error.message : 'Unknown error',
    });
  }
});

export { router as healthRouter };
```

### Error Handling
```typescript
// apps/backend/src/middleware/error.ts
import { Request, Response, NextFunction } from 'express';

interface ApiError extends Error {
  statusCode?: number;
  isOperational?: boolean;
}

export class AppError extends Error implements ApiError {
  statusCode: number;
  isOperational: boolean;

  constructor(message: string, statusCode: number = 500) {
    super(message);
    this.statusCode = statusCode;
    this.isOperational = true;
    
    Error.captureStackTrace(this, this.constructor);
  }
}

export const errorHandler = (
  error: ApiError,
  req: Request,
  res: Response,
  next: NextFunction
) => {
  const { statusCode = 500, message } = error;

  // Log error (in production, send to monitoring service)
  console.error(`[${new Date().toISOString()}] Error ${statusCode}:`, {
    message,
    stack: error.stack,
    url: req.url,
    method: req.method,
    ip: req.ip,
  });

  // Don't expose internal errors in production
  const isDevelopment = process.env.NODE_ENV === 'development';
  
  res.status(statusCode).json({
    error: {
      message: isDevelopment ? message : 'Internal server error',
      ...(isDevelopment && { stack: error.stack }),
    },
    timestamp: new Date().toISOString(),
    path: req.url,
  });
};

// 404 handler
export const notFoundHandler = (req: Request, res: Response) => {
  res.status(404).json({
    error: {
      message: `Route ${req.method} ${req.url} not found`,
    },
    timestamp: new Date().toISOString(),
  });
};
```

## 🔄 CI/CD Best Practices

### GitHub Actions Workflow
```yaml
# .github/workflows/deploy.yml
name: Deploy to Production

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

env:
  NODE_VERSION: '18'

jobs:
  test:
    name: Test & Lint
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: 'npm'
      
      - name: Install dependencies
        run: npm ci
      
      - name: Lint code
        run: |
          npx nx run-many --target=lint --all --parallel
      
      - name: Type check
        run: |
          npx nx run-many --target=type-check --all --parallel
      
      - name: Run tests
        run: |
          npx nx run-many --target=test --all --parallel --coverage
      
      - name: Build applications
        run: |
          npx nx build frontend --prod
          npx nx build backend --prod

  deploy:
    name: Deploy to Railway
    runs-on: ubuntu-latest
    needs: test
    if: github.ref == 'refs/heads/main'
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Deploy to Railway
        uses: railway-app/railway-deploy@v1
        with:
          service: production
        env:
          RAILWAY_TOKEN: ${{ secrets.RAILWAY_TOKEN }}
```

### Pre-deployment Checks
```bash
#!/bin/bash
# tools/deploy/pre-deploy.sh

set -e

echo "🔍 Running pre-deployment checks..."

# Check environment variables
echo "Checking environment variables..."
if [ -z "$DATABASE_URL" ]; then
  echo "❌ DATABASE_URL is not set"
  exit 1
fi

if [ -z "$JWT_SECRET" ]; then
  echo "❌ JWT_SECRET is not set"
  exit 1
fi

# Run tests
echo "Running tests..."
npm run test

# Build applications
echo "Building applications..."
npx nx build frontend --prod
npx nx build backend --prod

# Check build outputs
if [ ! -d "dist/apps/frontend" ]; then
  echo "❌ Frontend build failed"
  exit 1
fi

if [ ! -d "dist/apps/backend" ]; then
  echo "❌ Backend build failed"
  exit 1
fi

# Test database connection
echo "Testing database connection..."
node -e "
const mysql = require('mysql2/promise');
mysql.createConnection(process.env.DATABASE_URL)
  .then(conn => {
    console.log('✅ Database connection successful');
    conn.end();
  })
  .catch(err => {
    console.error('❌ Database connection failed:', err.message);
    process.exit(1);
  });
"

echo "✅ All pre-deployment checks passed!"
```

## 👥 Client Handover Best Practices

### Documentation Package
```markdown
# Client Handover Package

## 🚀 Application Overview
- **Frontend**: https://your-app.com
- **Admin Dashboard**: https://your-app.com/admin
- **API**: https://api.your-app.com

## 🔐 Access Credentials
- **Railway Dashboard**: [Login URL]
- **Database Admin**: [Connection details]
- **Domain Management**: [Registrar info]

## 📞 Support Information
- **Developer Contact**: your-email@domain.com
- **Emergency Support**: +1-xxx-xxx-xxxx
- **Documentation**: Link to this guide

## 💰 Monthly Costs
- **Hosting (Railway)**: $5/month
- **Domain**: $15/year
- **SSL Certificate**: Free (automatic)
- **Total Monthly**: ~$6.25

## 🔧 Common Tasks
### Adding a New User
1. Log into admin dashboard
2. Navigate to Users section
3. Click "Add New User"
4. Fill required fields
5. Click "Save"

### Viewing Usage Statistics
1. Railway dashboard → Your Project
2. Click on "Metrics" tab
3. View traffic and resource usage

## 🚨 Emergency Procedures
### Site is Down
1. Check Railway status page
2. Contact developer if issue persists
3. Have this contact info ready: [details]

### Need to Make Changes
1. Contact developer for quote
2. Changes require development work
3. Typical turnaround: 1-2 weeks
```

### Client Training Checklist
```markdown
## Client Handover Checklist

### ✅ Access Setup
- [ ] Railway account created with client email
- [ ] Domain ownership transferred
- [ ] Admin dashboard credentials provided
- [ ] Database backup procedures explained

### ✅ Documentation Delivered
- [ ] User manual provided
- [ ] Admin guide created
- [ ] Emergency contact information
- [ ] Cost breakdown and payment setup

### ✅ Training Completed
- [ ] Basic admin functions demonstrated
- [ ] Content update procedures shown
- [ ] Backup/restore process explained
- [ ] Support procedures clarified

### ✅ Technical Handover
- [ ] Source code repository access (if requested)
- [ ] Deployment documentation
- [ ] Environment variable documentation
- [ ] Monitoring and alerts configured

### ✅ Ongoing Support
- [ ] Support agreement signed
- [ ] Payment terms established
- [ ] Response time expectations set
- [ ] Escalation procedures defined
```

## 🔗 Integration with External Services

### Email Service Setup
```typescript
// apps/backend/src/services/email.ts
import nodemailer from 'nodemailer';

class EmailService {
  private transporter: nodemailer.Transporter;

  constructor() {
    this.transporter = nodemailer.createTransporter({
      host: process.env.SMTP_HOST,
      port: parseInt(process.env.SMTP_PORT || '587'),
      secure: false,
      auth: {
        user: process.env.SMTP_USER,
        pass: process.env.SMTP_PASS,
      },
    });
  }

  async sendWelcomeEmail(to: string, name: string) {
    const mailOptions = {
      from: process.env.FROM_EMAIL,
      to,
      subject: 'Welcome to Our App!',
      html: `
        <h1>Welcome ${name}!</h1>
        <p>Thank you for joining our platform.</p>
      `,
    };

    try {
      await this.transporter.sendMail(mailOptions);
      console.log(`Welcome email sent to ${to}`);
    } catch (error) {
      console.error('Email send failed:', error);
      throw new Error('Failed to send welcome email');
    }
  }
}

export const emailService = new EmailService();
```

### Payment Integration (Stripe)
```typescript
// apps/backend/src/services/payment.ts
import Stripe from 'stripe';

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, {
  apiVersion: '2023-10-16',
});

export class PaymentService {
  async createPaymentIntent(amount: number, currency = 'usd') {
    try {
      const paymentIntent = await stripe.paymentIntents.create({
        amount: amount * 100, // Convert to cents
        currency,
        automatic_payment_methods: {
          enabled: true,
        },
      });

      return {
        clientSecret: paymentIntent.client_secret,
        id: paymentIntent.id,
      };
    } catch (error) {
      console.error('Payment intent creation failed:', error);
      throw new Error('Failed to create payment intent');
    }
  }

  async handleWebhook(body: string, signature: string) {
    try {
      const event = stripe.webhooks.constructEvent(
        body,
        signature,
        process.env.STRIPE_WEBHOOK_SECRET!
      );

      switch (event.type) {
        case 'payment_intent.succeeded':
          // Handle successful payment
          console.log('Payment succeeded:', event.data.object.id);
          break;
        default:
          console.log(`Unhandled event type: ${event.type}`);
      }
    } catch (error) {
      console.error('Webhook handling failed:', error);
      throw new Error('Invalid webhook signature');
    }
  }
}
```

---

**💡 Key Takeaway**: Following these best practices ensures your Nx deployment is production-ready, secure, performant, and suitable for smooth client handovers. Focus on automation, documentation, and monitoring for long-term success.

---

*Best Practices | Production-ready Nx deployment patterns and client handover strategies*