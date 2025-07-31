# Deployment Guide - Svelte/SvelteKit Production Deployment

## 🚀 Production Deployment Strategies

Comprehensive guide for deploying SvelteKit EdTech applications to production environments, with focus on performance, scalability, and reliability for Philippine and international markets.

{% hint style="success" %}
**Deployment Ready**: This guide covers everything from development to production deployment with monitoring, scaling, and maintenance strategies.
{% endhint %}

## 🌐 Hosting Platform Comparison

### Quick Comparison Matrix

| Platform | Cost (Monthly) | Performance | Ease of Setup | Edge Locations | Recommended For |
|----------|----------------|-------------|---------------|----------------|-----------------|
| **Vercel** | $0-$20+ | Excellent | Very Easy | Global | Startups, fast deployment |
| **Netlify** | $0-$19+ | Excellent | Very Easy | Global | JAMstack apps, CDN focus |
| **Railway** | $5-$25+ | Good | Easy | Limited | Full-stack apps, databases |
| **DigitalOcean** | $6-$100+ | Good | Medium | Limited | Cost-conscious, control |
| **AWS** | $10-$500+ | Excellent | Hard | Global | Enterprise, scalability |
| **Google Cloud** | $15-$400+ | Excellent | Hard | Global | AI integration, analytics |

### Recommended Deployment Stack

```typescript
// Production deployment architecture
Architecture: SvelteKit + Node.js
Database: PostgreSQL (Supabase/PlanetScale)
CDN: Cloudflare
Monitoring: Sentry + Vercel Analytics
Email: Resend/SendGrid
Search: Meilisearch/Algolia
File Storage: Cloudinary/AWS S3
```

## ⚡ Vercel Deployment (Recommended for Startups)

### Setup and Configuration

```bash
# Install Vercel CLI
npm i -g vercel

# Login to Vercel
vercel login

# Deploy from project directory
vercel

# Production deployment
vercel --prod
```

### Vercel Configuration

```json
// vercel.json
{
  "framework": "sveltekit",
  "buildCommand": "npm run build",
  "devCommand": "npm run dev",
  "installCommand": "npm install",
  "regions": ["sin1", "hnd1", "syd1"], // Asia-Pacific regions for Philippine users
  "functions": {
    "src/routes/api/**/*.ts": {
      "maxDuration": 30
    }
  },
  "headers": [
    {
      "source": "/api/(.*)",
      "headers": [
        { "key": "Cache-Control", "value": "public, max-age=300, s-maxage=3600" }
      ]
    }
  ],
  "rewrites": [
    { "source": "/sitemap.xml", "destination": "/api/sitemap" },
    { "source": "/robots.txt", "destination": "/api/robots" }
  ]
}
```

### Environment Variables Setup

```bash
# Set environment variables
vercel env add DATABASE_URL production
vercel env add JWT_SECRET production
vercel env add STRIPE_SECRET_KEY production
vercel env add EMAIL_API_KEY production

# Local development
vercel env pull .env.local
```

### Custom Domain Configuration

```bash
# Add custom domain
vercel domains add yourdomain.com

# Configure DNS (for Philippine domains)
# A record: @ -> 76.76.19.61
# CNAME record: www -> cname.vercel-dns.com
```

## 🏗️ Self-Hosted Deployment (DigitalOcean/AWS)

### Docker Configuration

```dockerfile
# Dockerfile
FROM node:18-alpine AS base

# Install dependencies only when needed
FROM base AS deps
RUN apk add --no-cache libc6-compat
WORKDIR /app

# Install dependencies based on the preferred package manager
COPY package.json package-lock.json* ./
RUN npm ci --only=production

# Rebuild the source code only when needed
FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

ENV NODE_ENV production
RUN npm run build

# Production image, copy all the files and run the app
FROM base AS runner
WORKDIR /app

ENV NODE_ENV production
ENV ORIGIN https://yourdomain.com
ENV PROTOCOL_HEADER x-forwarded-proto
ENV HOST_HEADER x-forwarded-host

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 sveltekit

COPY --from=builder /app/build ./build
COPY --from=builder /app/package.json ./package.json
COPY --from=deps /app/node_modules ./node_modules

USER sveltekit

EXPOSE 3000

ENV PORT 3000

CMD ["node", "build"]
```

### Docker Compose for Development

```yaml
# docker-compose.yml
version: '3.8'
services:
  app:
    build: .
    ports:
      - "3000:3000"
    environment:
      - DATABASE_URL=postgresql://user:password@db:5432/edtech_db
      - JWT_SECRET=your-jwt-secret
      - NODE_ENV=production
    depends_on:
      - db
      - redis
    restart: unless-stopped

  db:
    image: postgres:15-alpine
    environment:
      - POSTGRES_DB=edtech_db
      - POSTGRES_USER=user
      - POSTGRES_PASSWORD=password
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    restart: unless-stopped

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    restart: unless-stopped

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
      - ./ssl:/etc/nginx/ssl
    depends_on:
      - app
    restart: unless-stopped

volumes:
  postgres_data:
  redis_data:
```

### Nginx Configuration

```nginx
# nginx.conf
events {
    worker_connections 1024;
}

http {
    upstream app {
        server app:3000;
    }

    # Rate limiting for Philippine and international traffic
    limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
    limit_req_zone $binary_remote_addr zone=auth:10m rate=5r/s;

    server {
        listen 80;
        server_name yourdomain.com www.yourdomain.com;
        return 301 https://$server_name$request_uri;
    }

    server {
        listen 443 ssl http2;
        server_name yourdomain.com www.yourdomain.com;

        ssl_certificate /etc/nginx/ssl/cert.pem;
        ssl_certificate_key /etc/nginx/ssl/key.pem;
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers HIGH:!aNULL:!MD5;

        # Security headers
        add_header X-Frame-Options DENY;
        add_header X-Content-Type-Options nosniff;
        add_header X-XSS-Protection "1; mode=block";
        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains";

        # Gzip compression
        gzip on;
        gzip_vary on;
        gzip_min_length 1024;
        gzip_proxied any;
        gzip_comp_level 6;
        gzip_types
            text/plain
            text/css
            text/xml
            text/javascript
            application/json
            application/javascript
            application/xml+rss
            application/atom+xml
            image/svg+xml;

        # Static file caching
        location /static/ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }

        # API rate limiting
        location /api/ {
            limit_req zone=api burst=20 nodelay;
            proxy_pass http://app;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        # Auth endpoints with stricter rate limiting
        location /api/auth/ {
            limit_req zone=auth burst=10 nodelay;
            proxy_pass http://app;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        # Main application
        location / {
            proxy_pass http://app;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            
            # WebSocket support for hot reloading in dev
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
        }

        # Health check endpoint
        location /health {
            access_log off;
            return 200 "healthy\n";
            add_header Content-Type text/plain;
        }
    }
}
```

## 🔄 CI/CD Pipeline Setup

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
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  test:
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
      
      - name: Run tests
        run: npm test
      
      - name: Run E2E tests
        run: npm run test:e2e
      
      - name: Check build
        run: npm run build

  build-and-push:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    permissions:
      contents: read
      packages: write
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Log in to Container Registry
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      
      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
          tags: |
            type=ref,event=branch
            type=sha,prefix={{branch}}-
            type=raw,value=latest,enable={{is_default_branch}}
      
      - name: Build and push Docker image
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}

  deploy:
    needs: build-and-push
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    
    steps:
      - name: Deploy to production
        uses: appleboy/ssh-action@v1.0.0
        with:
          host: ${{ secrets.HOST }}
          username: ${{ secrets.USERNAME }}
          key: ${{ secrets.PRIVATE_KEY }}
          script: |
            # Pull latest image
            docker pull ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:latest
            
            # Update docker-compose
            cd /opt/edtech-platform
            docker-compose pull
            docker-compose up -d
            
            # Clean up old images
            docker image prune -f
```

### Deployment Scripts

```bash
#!/bin/bash
# deploy.sh - Production deployment script

set -e

echo "🚀 Starting deployment process..."

# Configuration
APP_NAME="edtech-platform"
BACKUP_DIR="/opt/backups"
LOG_FILE="/var/log/deploy.log"

# Create backup
echo "📦 Creating database backup..."
docker exec postgres pg_dump -U user edtech_db > "$BACKUP_DIR/backup-$(date +%Y%m%d-%H%M%S).sql"

# Pull latest changes
echo "📥 Pulling latest application..."
docker-compose pull

# Run database migrations
echo "🗄️ Running database migrations..."
docker-compose run --rm app npm run migrate

# Update application
echo "🔄 Updating application..."
docker-compose up -d --remove-orphans

# Health check
echo "🏥 Performing health check..."
sleep 10

if curl -f http://localhost:3000/health; then
    echo "✅ Deployment successful!"
    
    # Clean up old backups (keep last 10)
    find "$BACKUP_DIR" -name "backup-*.sql" | sort | head -n -10 | xargs rm -f
    
    # Send notification
    curl -X POST "$SLACK_WEBHOOK_URL" \
         -H 'Content-type: application/json' \
         --data '{"text":"🚀 EdTech Platform deployed successfully to production!"}'
else
    echo "❌ Health check failed! Rolling back..."
    
    # Rollback
    docker-compose down
    # Restore from backup (implementation depends on your backup strategy)
    
    exit 1
fi

echo "✅ Deployment completed successfully!"
```

## 📊 Performance Optimization

### Build Optimization

```javascript
// vite.config.js
import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vite';

export default defineConfig({
  plugins: [sveltekit()],
  
  build: {
    target: 'es2020',
    minify: 'terser',
    terserOptions: {
      compress: {
        drop_console: true,
        drop_debugger: true
      }
    },
    rollupOptions: {
      output: {
        manualChunks: {
          // Vendor chunks
          vendor: ['svelte', '@sveltejs/kit'],
          utils: ['date-fns', 'lodash-es'],
          
          // Feature chunks
          quiz: [
            'src/lib/components/quiz/QuizContainer.svelte',
            'src/lib/components/quiz/QuestionCard.svelte',
            'src/lib/stores/quiz.ts'
          ],
          dashboard: [
            'src/lib/components/dashboard/Dashboard.svelte',
            'src/lib/components/dashboard/ProgressChart.svelte'
          ],
          
          // Third-party chunks
          charts: ['chart.js', 'd3'],
          ui: ['@radix-ui/primitives']
        }
      }
    }
  },
  
  // Optimize dependencies
  optimizeDeps: {
    include: ['chart.js', 'date-fns', 'lodash-es']
  },
  
  // Server configuration
  server: {
    fs: {
      allow: ['..']
    }
  },
  
  // Preview configuration for production testing
  preview: {
    port: 4173,
    host: true
  }
});
```

### SvelteKit Configuration

```javascript
// svelte.config.js
import adapter from '@sveltejs/adapter-node'; // or adapter-vercel, adapter-netlify
import { vitePreprocess } from '@sveltejs/vite-plugin-svelte';

/** @type {import('@sveltejs/kit').Config} */
const config = {
  preprocess: vitePreprocess(),
  
  kit: {
    adapter: adapter({
      // Node adapter options
      out: 'build',
      precompress: true,
      envPrefix: 'EDTECH_'
    }),
    
    // CSP for security
    csp: {
      mode: 'hash',
      directives: {
        'default-src': ['self'],
        'script-src': ['self', 'unsafe-inline'],
        'style-src': ['self', 'unsafe-inline'],
        'img-src': ['self', 'data:', 'https:'],
        'font-src': ['self'],
        'connect-src': ['self', 'https://api.stripe.com'],
        'frame-src': ['https://js.stripe.com']
      }
    },
    
    // Service worker
    serviceWorker: {
      register: true,
      files: (filepath) => !/\.DS_Store/.test(filepath)
    },
    
    // Preload strategy
    preloadStrategy: 'preload-mjs',
    
    // Environment variables
    env: {
      publicPrefix: 'PUBLIC_',
      privatePrefix: 'PRIVATE_'
    }
  }
};

export default config;
```

## 🔐 Security Configuration

### SSL/TLS Setup

```bash
# Using Let's Encrypt with Certbot
sudo apt update
sudo apt install certbot python3-certbot-nginx

# Obtain SSL certificate
sudo certbot --nginx -d yourdomain.com -d www.yourdomain.com

# Auto-renewal setup
sudo crontab -e
# Add: 0 12 * * * /usr/bin/certbot renew --quiet
```

### Security Headers

```typescript
// src/hooks.server.ts
import type { Handle } from '@sveltejs/kit';

export const handle: Handle = async ({ event, resolve }) => {
  const response = await resolve(event);
  
  // Security headers
  response.headers.set('X-Frame-Options', 'DENY');
  response.headers.set('X-Content-Type-Options', 'nosniff');
  response.headers.set('X-XSS-Protection', '1; mode=block');
  response.headers.set('Referrer-Policy', 'strict-origin-when-cross-origin');
  response.headers.set(
    'Strict-Transport-Security', 
    'max-age=31536000; includeSubDomains; preload'
  );
  
  // Content Security Policy
  response.headers.set(
    'Content-Security-Policy',
    [
      "default-src 'self'",
      "script-src 'self' 'unsafe-inline'",
      "style-src 'self' 'unsafe-inline'",
      "img-src 'self' data: https:",
      "font-src 'self'",
      "connect-src 'self' https://api.stripe.com",
      "frame-src https://js.stripe.com"
    ].join('; ')
  );
  
  return response;
};
```

### Environment Security

```bash
# .env.production (never commit this file)
DATABASE_URL="postgresql://user:secure_password@localhost:5432/edtech_prod"
JWT_SECRET="your-super-secure-jwt-secret-at least-32-characters"
STRIPE_SECRET_KEY="sk_live_..."
EMAIL_API_KEY="your-email-service-api-key"
ADMIN_EMAIL="admin@yourdomain.com"
ENCRYPTION_KEY="your-32-character-encryption-key"

# Set proper file permissions
chmod 600 .env.production
```

## 📈 Monitoring and Analytics

### Application Monitoring with Sentry

```typescript
// src/lib/monitoring/sentry.ts
import * as Sentry from '@sentry/sveltekit';

Sentry.init({
  dsn: 'YOUR_SENTRY_DSN',
  environment: process.env.NODE_ENV,
  
  // Performance monitoring
  tracesSampleRate: 1.0,
  
  // Release tracking
  release: process.env.VERCEL_GIT_COMMIT_SHA || 'development',
  
  // Error filtering
  beforeSend(event) {
    // Filter out non-critical errors
    if (event.exception) {
      const error = event.exception.values?.[0];
      if (error?.type === 'ChunkLoadError') {
        return null; // Ignore chunk loading errors
      }
    }
    return event;
  },
  
  // User context
  initialScope: {
    tags: {
      component: 'edtech-platform'
    }
  }
});
```

### Custom Analytics

```typescript
// src/lib/monitoring/analytics.ts
interface AnalyticsEvent {
  event: string;
  category: string;
  label?: string;
  value?: number;
  properties?: Record<string, any>;
}

class Analytics {
  private isProduction = process.env.NODE_ENV === 'production';
  
  track(event: AnalyticsEvent) {
    if (!this.isProduction) {
      console.log('Analytics Event:', event);
      return;
    }
    
    // Send to multiple analytics providers
    this.sendToGoogleAnalytics(event);
    this.sendToPostHog(event);
    this.sendToCustomAnalytics(event);
  }
  
  private sendToGoogleAnalytics(event: AnalyticsEvent) {
    if (typeof gtag !== 'undefined') {
      gtag('event', event.event, {
        event_category: event.category,
        event_label: event.label,
        value: event.value,
        custom_parameters: event.properties
      });
    }
  }
  
  private sendToPostHog(event: AnalyticsEvent) {
    if (typeof posthog !== 'undefined') {
      posthog.capture(event.event, {
        category: event.category,
        label: event.label,
        value: event.value,
        ...event.properties
      });
    }
  }
  
  private async sendToCustomAnalytics(event: AnalyticsEvent) {
    try {
      await fetch('/api/analytics', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          ...event,
          timestamp: new Date().toISOString(),
          url: window.location.href,
          userAgent: navigator.userAgent
        })
      });
    } catch (error) {
      console.error('Analytics error:', error);
    }
  }
  
  // Educational platform specific events
  trackQuizStart(category: string, questionCount: number) {
    this.track({
      event: 'quiz_started',
      category: 'engagement',
      label: category,
      value: questionCount,
      properties: { quiz_category: category, question_count: questionCount }
    });
  }
  
  trackQuestionAnswer(questionId: string, correct: boolean, timeSpent: number) {
    this.track({
      event: 'question_answered',
      category: 'learning',
      label: correct ? 'correct' : 'incorrect',
      value: timeSpent,
      properties: { question_id: questionId, correct, time_spent: timeSpent }
    });
  }
  
  trackUserRegistration(method: string) {
    this.track({
      event: 'user_registered',
      category: 'auth',
      label: method,
      properties: { registration_method: method }
    });
  }
}

export const analytics = new Analytics();
```

### Health Monitoring

```typescript
// src/routes/api/health/+server.ts
import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';

interface HealthCheck {
  status: 'healthy' | 'unhealthy';
  timestamp: string;
  version: string;
  services: {
    database: 'up' | 'down';
    redis: 'up' | 'down';
    external_apis: 'up' | 'down';
  };
  metrics: {
    uptime: number;
    memory_usage: number;
    response_time: number;
  };
}

export const GET: RequestHandler = async () => {
  const startTime = Date.now();
  
  try {
    // Check database connection
    const dbStatus = await checkDatabase();
    
    // Check Redis connection
    const redisStatus = await checkRedis();
    
    // Check external APIs
    const apiStatus = await checkExternalAPIs();
    
    const responseTime = Date.now() - startTime;
    
    const health: HealthCheck = {
      status: (dbStatus && redisStatus && apiStatus) ? 'healthy' : 'unhealthy',
      timestamp: new Date().toISOString(),
      version: process.env.VERCEL_GIT_COMMIT_SHA || 'development',
      services: {
        database: dbStatus ? 'up' : 'down',
        redis: redisStatus ? 'up' : 'down',
        external_apis: apiStatus ? 'up' : 'down'
      },
      metrics: {
        uptime: process.uptime(),
        memory_usage: process.memoryUsage().heapUsed / 1024 / 1024, // MB
        response_time: responseTime
      }
    };
    
    const statusCode = health.status === 'healthy' ? 200 : 503;
    
    return json(health, { status: statusCode });
  } catch (error) {
    return json({
      status: 'unhealthy',
      timestamp: new Date().toISOString(),
      error: error.message
    }, { status: 503 });
  }
};

async function checkDatabase(): Promise<boolean> {
  try {
    // Simple database query
    // const result = await db.query('SELECT 1');
    return true;
  } catch {
    return false;
  }
}

async function checkRedis(): Promise<boolean> {
  try {
    // Redis ping
    // await redis.ping();
    return true;
  } catch {
    return false;
  }
}

async function checkExternalAPIs(): Promise<boolean> {
  try {
    // Check critical external services
    const checks = await Promise.allSettled([
      fetch('https://api.stripe.com/v1/charges', { method: 'HEAD' }),
      // Add other critical API checks
    ]);
    
    return checks.every(check => check.status === 'fulfilled');
  } catch {
    return false;
  }
}
```

## 📱 CDN and Caching Strategy

### Cloudflare Configuration

```javascript
// cloudflare-worker.js - Edge computing for Philippine users
addEventListener('fetch', event => {
  event.respondWith(handleRequest(event.request));
});

async function handleRequest(request) {
  const url = new URL(request.url);
  
  // Cache static assets aggressively
  if (url.pathname.match(/\.(js|css|png|jpg|jpeg|gif|ico|svg|woff2?)$/)) {
    const cache = caches.default;
    const cacheKey = new Request(url.toString(), request);
    
    let response = await cache.match(cacheKey);
    
    if (!response) {
      response = await fetch(request);
      
      if (response.status === 200) {
        const headers = new Headers(response.headers);
        headers.set('Cache-Control', 'public, max-age=31536000, immutable');
        headers.set('Expires', new Date(Date.now() + 31536000000).toUTCString());
        
        response = new Response(response.body, {
          status: response.status,
          statusText: response.statusText,
          headers
        });
        
        event.waitUntil(cache.put(cacheKey, response.clone()));
      }
    }
    
    return response;
  }
  
  // For API requests, add CORS headers for Philippine domains
  if (url.pathname.startsWith('/api/')) {
    const response = await fetch(request);
    const headers = new Headers(response.headers);
    
    headers.set('Access-Control-Allow-Origin', 'https://yourdomain.com');
    headers.set('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
    headers.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    
    return new Response(response.body, {
      status: response.status,
      statusText: response.statusText,
      headers
    });
  }
  
  // Default to origin
  return fetch(request);
}
```

### Service Worker for Offline Support

```typescript
// src/service-worker.ts
import { build, files, version } from '$service-worker';

const CACHE_NAME = `edtech-cache-${version}`;
const ASSETS = [...build, ...files];

// Install event - cache all assets
self.addEventListener('install', (event: ExtendableEvent) => {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then((cache) => cache.addAll(ASSETS))
      .then(() => self.skipWaiting())
  );
});

// Activate event - clean up old caches
self.addEventListener('activate', (event: ExtendableEvent) => {
  event.waitUntil(
    caches.keys().then(async (keys) => {
      for (const key of keys) {
        if (key !== CACHE_NAME) {
          await caches.delete(key);
        }
      }
      self.clients.claim();
    })
  );
});

// Fetch event - serve from cache, fallback to network
self.addEventListener('fetch', (event: FetchEvent) => {
  if (event.request.method !== 'GET') return;
  
  event.respondWith(
    caches.open(CACHE_NAME).then(async (cache) => {
      const cachedResponse = await cache.match(event.request);
      
      if (cachedResponse) {
        // Serve from cache
        return cachedResponse;
      }
      
      try {
        // Try network
        const networkResponse = await fetch(event.request);
        
        // Cache successful responses
        if (networkResponse.ok) {
          cache.put(event.request, networkResponse.clone());
        }
        
        return networkResponse;
      } catch {
        // Network failed, serve offline page for navigation requests
        if (event.request.mode === 'navigate') {
          return cache.match('/offline.html') || new Response('Offline');
        }
        
        throw new Error('Network unavailable');
      }
    })
  );
});

// Background sync for form submissions
self.addEventListener('sync', (event: SyncEvent) => {
  if (event.tag === 'quiz-submission') {
    event.waitUntil(syncQuizData());
  }
});

async function syncQuizData() {
  // Sync offline quiz submissions when online
  const db = await openDB();
  const submissions = await db.getAll('pendingSubmissions');
  
  for (const submission of submissions) {
    try {
      await fetch('/api/quiz/submit', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(submission.data)
      });
      
      await db.delete('pendingSubmissions', submission.id);
    } catch (error) {
      console.error('Sync failed for submission:', submission.id, error);
    }
  }
}
```

## 🔧 Database Deployment

### PostgreSQL Setup

```sql
-- Production database schema
-- migrations/001_initial_schema.sql

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm"; -- For text search

-- Users table
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    name VARCHAR(100) NOT NULL,
    role VARCHAR(20) DEFAULT 'student',
    verified BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Questions table
CREATE TABLE questions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    text TEXT NOT NULL,
    options JSONB NOT NULL,
    correct_answer INTEGER NOT NULL,
    explanation TEXT,
    category VARCHAR(50) NOT NULL,
    difficulty VARCHAR(20) DEFAULT 'medium',
    tags TEXT[] DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Quiz sessions table
CREATE TABLE quiz_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    category VARCHAR(50) NOT NULL,
    questions JSONB NOT NULL, -- Array of question IDs
    answers JSONB DEFAULT '[]',
    started_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    completed_at TIMESTAMP WITH TIME ZONE,
    score INTEGER,
    time_spent INTEGER -- seconds
);

-- User progress table
CREATE TABLE user_progress (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    category VARCHAR(50) NOT NULL,
    questions_attempted INTEGER DEFAULT 0,
    questions_correct INTEGER DEFAULT 0,
    total_time_spent INTEGER DEFAULT 0, -- seconds
    last_activity TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, category)
);

-- Indexes for performance
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_questions_category ON questions(category);
CREATE INDEX idx_questions_difficulty ON questions(difficulty);
CREATE INDEX idx_questions_text_search ON questions USING gin(to_tsvector('english', text));
CREATE INDEX idx_quiz_sessions_user_id ON quiz_sessions(user_id);
CREATE INDEX idx_quiz_sessions_category ON quiz_sessions(category);
CREATE INDEX idx_user_progress_user_id ON user_progress(user_id);

-- Updated_at trigger
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_questions_updated_at BEFORE UPDATE ON questions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
```

### Database Migration Script

```typescript
// scripts/migrate.ts
import { Pool } from 'pg';
import { readFileSync, readdirSync } from 'fs';
import { join } from 'path';

const pool = new Pool({
  connectionString: process.env.DATABASE_URL
});

async function runMigrations() {
  const client = await pool.connect();
  
  try {
    // Create migrations table if it doesn't exist
    await client.query(`
      CREATE TABLE IF NOT EXISTS migrations (
        id SERIAL PRIMARY KEY,
        filename VARCHAR(255) NOT NULL,
        executed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
      )
    `);
    
    // Get executed migrations
    const { rows: executedMigrations } = await client.query(
      'SELECT filename FROM migrations ORDER BY id'
    );
    const executed = new Set(executedMigrations.map(row => row.filename));
    
    // Get migration files
    const migrationDir = join(process.cwd(), 'migrations');
    const migrationFiles = readdirSync(migrationDir)
      .filter(file => file.endsWith('.sql'))
      .sort();
    
    // Execute pending migrations
    for (const filename of migrationFiles) {
      if (!executed.has(filename)) {
        console.log(`Executing migration: ${filename}`);
        
        const sql = readFileSync(join(migrationDir, filename), 'utf8');
        
        await client.query('BEGIN');
        try {
          await client.query(sql);
          await client.query(
            'INSERT INTO migrations (filename) VALUES ($1)',
            [filename]
          );
          await client.query('COMMIT');
          
          console.log(`✅ Migration ${filename} completed successfully`);
        } catch (error) {
          await client.query('ROLLBACK');
          throw error;
        }
      }
    }
    
    console.log('🎉 All migrations completed successfully');
  } catch (error) {
    console.error('❌ Migration failed:', error);
    process.exit(1);
  } finally {
    client.release();
    await pool.end();
  }
}

runMigrations();
```

## 📊 Performance Monitoring

### Load Testing with k6

```javascript
// performance/load-test.js
import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate } from 'k6/metrics';

const errorRate = new Rate('errors');

export const options = {
  stages: [
    { duration: '2m', target: 50 }, // Ramp up to 50 users
    { duration: '5m', target: 50 }, // Stay at 50 users
    { duration: '2m', target: 100 }, // Ramp up to 100 users
    { duration: '5m', target: 100 }, // Stay at 100 users
    { duration: '2m', target: 0 }, // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'], // 95% of requests under 500ms
    http_req_failed: ['rate<0.05'], // Error rate under 5%
    errors: ['rate<0.05'],
  },
};

export default function () {
  // Test homepage
  let response = http.get('https://yourdomain.com/');
  check(response, {
    'homepage status is 200': (r) => r.status === 200,
    'homepage loads in <200ms': (r) => r.timings.duration < 200,
  }) || errorRate.add(1);
  
  sleep(1);
  
  // Test quiz API
  response = http.get('https://yourdomain.com/api/questions?category=nursing&limit=10');
  check(response, {
    'API status is 200': (r) => r.status === 200,
    'API response has questions': (r) => JSON.parse(r.body).questions?.length > 0,
    'API responds in <300ms': (r) => r.timings.duration < 300,
  }) || errorRate.add(1);
  
  sleep(2);
  
  // Test quiz page
  response = http.get('https://yourdomain.com/quiz/nursing');
  check(response, {
    'quiz page status is 200': (r) => r.status === 200,
    'quiz page loads in <400ms': (r) => r.timings.duration < 400,
  }) || errorRate.add(1);
  
  sleep(3);
}
```

### Uptime Monitoring

```typescript
// monitoring/uptime-monitor.ts
interface UptimeCheck {
  url: string;
  expectedStatus: number;
  timeout: number;
  interval: number; // minutes
}

const checks: UptimeCheck[] = [
  {
    url: 'https://yourdomain.com',
    expectedStatus: 200,
    timeout: 5000,
    interval: 5
  },
  {
    url: 'https://yourdomain.com/api/health',
    expectedStatus: 200,
    timeout: 3000,
    interval: 2
  },
  {
    url: 'https://yourdomain.com/api/questions?category=nursing&limit=1',
    expectedStatus: 200,
    timeout: 5000,
    interval: 10
  }
];

class UptimeMonitor {
  private alertThreshold = 3; // consecutive failures before alert
  private failures = new Map<string, number>();
  
  async runChecks() {
    for (const check of checks) {
      try {
        const response = await fetch(check.url, {
          method: 'GET',
          signal: AbortSignal.timeout(check.timeout)
        });
        
        if (response.status === check.expectedStatus) {
          // Success - reset failure count
          this.failures.set(check.url, 0);
          console.log(`✅ ${check.url} - OK`);
        } else {
          this.handleFailure(check, `Status ${response.status}`);
        }
      } catch (error) {
        this.handleFailure(check, error.message);
      }
    }
  }
  
  private handleFailure(check: UptimeCheck, error: string) {
    const currentFailures = this.failures.get(check.url) || 0;
    const newFailures = currentFailures + 1;
    
    this.failures.set(check.url, newFailures);
    
    console.error(`❌ ${check.url} - ${error} (${newFailures} consecutive failures)`);
    
    if (newFailures >= this.alertThreshold) {
      this.sendAlert(check, error, newFailures);
    }
  }
  
  private async sendAlert(check: UptimeCheck, error: string, failures: number) {
    const message = `🚨 ALERT: ${check.url} has been down for ${failures} consecutive checks. Error: ${error}`;
    
    // Send to multiple notification channels
    await Promise.allSettled([
      this.sendSlackAlert(message),
      this.sendEmailAlert(message),
      this.sendSMSAlert(message) // For critical alerts
    ]);
  }
  
  private async sendSlackAlert(message: string) {
    if (!process.env.SLACK_WEBHOOK_URL) return;
    
    await fetch(process.env.SLACK_WEBHOOK_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ text: message })
    });
  }
  
  private async sendEmailAlert(message: string) {
    // Implementation depends on your email service
    console.log('Email alert:', message);
  }
  
  private async sendSMSAlert(message: string) {
    // Implementation for SMS alerts (Twilio, etc.)
    console.log('SMS alert:', message);
  }
}

// Run monitoring
const monitor = new UptimeMonitor();

setInterval(() => {
  monitor.runChecks();
}, 60000); // Check every minute

// Initial check
monitor.runChecks();
```

---

## 🔗 Continue Reading

- **Next**: [Testing Strategies](./testing-strategies.md) - Quality assurance approaches
- **Previous**: [Migration Strategy](./migration-strategy.md) - Framework migration planning
- **Templates**: [Template Examples](./template-examples.md) - Working examples

---

## 📚 Deployment References

1. **[SvelteKit Deployment Guide](https://kit.svelte.dev/docs/adapters)** - Official deployment documentation
2. **[Vercel SvelteKit Guide](https://vercel.com/guides/deploying-svelte-with-vercel)** - Vercel-specific deployment
3. **[Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)** - Container deployment
4. **[Nginx Configuration Guide](https://nginx.org/en/docs/)** - Web server setup
5. **[PostgreSQL Performance Tuning](https://wiki.postgresql.org/wiki/Performance_Optimization)** - Database optimization
6. **[SSL/TLS Best Practices](https://ssl-config.mozilla.org/)** - Security configuration
7. **[Web Performance Monitoring](https://web.dev/performance/)** - Performance optimization

---

*Deployment Guide completed January 2025 | Production-ready deployment strategies*