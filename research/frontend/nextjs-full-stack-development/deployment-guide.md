# Deployment Guide: Next.js Educational Platform

## 🎯 Overview

This comprehensive deployment guide covers multiple deployment strategies for Next.js educational platforms, from MVP development to enterprise-scale production environments. Each strategy is evaluated for cost, scalability, performance, and suitability for different stages of an educational technology business.

## 🚀 Deployment Strategies Comparison

### Quick Comparison Matrix

| Platform | Setup Time | Cost (Monthly) | Scalability | Maintenance | Education Platform Fit |
|----------|------------|----------------|-------------|-------------|----------------------|
| **Vercel** | 5 minutes | $0 - $20 | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ Perfect for startups |
| **Netlify** | 10 minutes | $0 - $19 | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ Good for static-heavy |
| **AWS Amplify** | 30 minutes | $15 - $200+ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ Enterprise ready |
| **Railway** | 15 minutes | $5 - $50 | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ Developer friendly |
| **DigitalOcean** | 60 minutes | $20 - $100+ | ⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐ Cost-effective |
| **Self-hosted** | 4+ hours | $50+ | ⭐⭐⭐⭐⭐ | ⭐ | ⭐⭐ Full control needed |

## 1. 🟢 Vercel Deployment (Recommended for Startups)

### Why Vercel for Educational Platforms?

**Advantages:**
- **Zero-config deployment** with automatic optimizations
- **Built-in CDN** with edge functions for global performance
- **Automatic HTTPS** with custom domain support
- **Preview deployments** for testing course content
- **Built-in analytics** for performance monitoring
- **Serverless functions** perfect for API routes

**Ideal for:**
- MVP development and validation
- Small to medium educational platforms (< 100k students)
- Teams prioritizing development speed over infrastructure control

### Step-by-Step Vercel Deployment

#### 1. Project Preparation

```bash
# Ensure your project structure is optimized for Vercel
education-platform/
├── package.json
├── next.config.js
├── vercel.json          # Vercel configuration
├── .env.local           # Local environment variables
├── .env.example         # Environment variables template
└── src/
    └── app/             # Next.js 13+ App Router
```

#### 2. Vercel Configuration

```json
// vercel.json
{
  "version": 2,
  "buildCommand": "npm run build",
  "outputDirectory": ".next",
  "installCommand": "npm ci",
  "functions": {
    "src/app/api/**/*.ts": {
      "maxDuration": 10
    }
  },
  "regions": ["sin1", "hnd1", "syd1"], // Asia-Pacific regions for Philippines
  "env": {
    "DATABASE_URL": "@database-url",
    "NEXTAUTH_SECRET": "@nextauth-secret",
    "NEXTAUTH_URL": "@nextauth-url"
  },
  "build": {
    "env": {
      "SKIP_ENV_VALIDATION": "1"
    }
  },
  "rewrites": [
    {
      "source": "/api/webhooks/:path*",
      "destination": "/api/webhooks/:path*"
    }
  ],
  "headers": [
    {
      "source": "/api/(.*)",
      "headers": [
        {
          "key": "Access-Control-Allow-Origin",
          "value": "https://yourdomain.com"
        },
        {
          "key": "Access-Control-Allow-Methods",
          "value": "GET, POST, PUT, DELETE, OPTIONS"
        }
      ]
    }
  ]
}
```

#### 3. Environment Variables Setup

```bash
# Install Vercel CLI
npm i -g vercel

# Login to Vercel
vercel login

# Set environment variables
vercel env add DATABASE_URL
vercel env add NEXTAUTH_SECRET
vercel env add NEXTAUTH_URL
vercel env add GOOGLE_CLIENT_ID
vercel env add GOOGLE_CLIENT_SECRET
vercel env add STRIPE_SECRET_KEY

# For different environments
vercel env add DATABASE_URL production
vercel env add DATABASE_URL preview
vercel env add DATABASE_URL development
```

#### 4. Database Setup with PlanetScale

```bash
# Install PlanetScale CLI
curl -fsSL https://get.planetscale.com/install.sh | bash

# Create database
pscale database create education-platform --region ap-southeast

# Create branches for different environments
pscale branch create education-platform main
pscale branch create education-platform staging

# Get connection strings
pscale password create education-platform main vercel-prod
pscale password create education-platform staging vercel-preview

# Connect to database for migrations
pscale connect education-platform main --port 3309

# Run Prisma migrations
DATABASE_URL="mysql://127.0.0.1:3309/education-platform" npx prisma db push
```

#### 5. Deployment Commands

```bash
# Deploy to production
vercel --prod

# Deploy to preview (staging)
vercel

# Deploy with environment
vercel --prod --env DATABASE_URL=@prod-database-url

# Check deployment status
vercel ls

# View logs
vercel logs education-platform.vercel.app
```

#### 6. Custom Domain Setup

```bash
# Add custom domain
vercel domains add yourdomain.com

# Add subdomain for different environments
vercel domains add app.yourdomain.com      # Production
vercel domains add staging.yourdomain.com  # Staging
vercel domains add admin.yourdomain.com    # Admin panel

# Configure DNS (add to your DNS provider)
# CNAME app -> cname.vercel-dns.com
# A @ -> 76.76.19.61
```

### Vercel Performance Optimization

```javascript
// next.config.js for Vercel
/** @type {import('next').NextConfig} */
const nextConfig = {
  // Optimize for Vercel's CDN
  images: {
    domains: ['cdn.yourdomain.com'],
    formats: ['image/webp', 'image/avif'],
  },
  
  // Enable Vercel Analytics
  experimental: {
    appDir: true,
  },
  
  // Optimize bundle for serverless
  webpack: (config, { isServer, webpack, dev }) => {
    if (!dev && !isServer) {
      config.resolve.alias = {
        ...config.resolve.alias,
        '@/lib/server-only': false,
      }
    }
    return config
  },
  
  // Configure headers for better caching
  async headers() {
    return [
      {
        source: '/api/courses/:path*',
        headers: [
          {
            key: 'Cache-Control',
            value: 'public, s-maxage=300, stale-while-revalidate=86400',
          },
        ],
      },
      {
        source: '/_next/static/:path*',
        headers: [
          {
            key: 'Cache-Control',
            value: 'public, max-age=31536000, immutable',
          },
        ],
      },
    ]
  },
}

module.exports = nextConfig
```

## 2. 🔵 AWS Amplify Deployment (Enterprise Solution)

### Why AWS Amplify for Educational Platforms?

**Advantages:**
- **Full AWS ecosystem** integration
- **Auto-scaling** with high availability
- **Advanced security** features and compliance
- **Custom build environments** for complex applications
- **Cost-effective** for high-traffic applications

**Ideal for:**
- Large educational institutions
- Platforms requiring compliance (FERPA, GDPR)
- High-traffic applications (>100k students)
- Multi-region deployments

### AWS Amplify Setup

#### 1. Project Configuration

```yaml
# amplify.yml
version: 1
applications:
  - appRoot: .
    frontend:
      phases:
        preBuild:
          commands:
            - npm ci
            - npx prisma generate
        build:
          commands:
            - npm run build
      artifacts:
        baseDirectory: .next
        files:
          - '**/*'
      cache:
        paths:
          - node_modules/**/*
          - .next/cache/**/*
    backend:
      phases:
        preBuild:
          commands:
            - npm ci
        build:
          commands:
            - npx prisma db push
env:
  variables:
    DATABASE_URL: $DATABASE_URL
    NEXTAUTH_SECRET: $NEXTAUTH_SECRET
    NEXTAUTH_URL: $NEXTAUTH_URL
```

#### 2. Infrastructure as Code (CDK)

```typescript
// infrastructure/amplify-stack.ts
import * as cdk from 'aws-cdk-lib'
import * as amplify from 'aws-cdk-lib/aws-amplify'
import * as rds from 'aws-cdk-lib/aws-rds'
import * as ec2 from 'aws-cdk-lib/aws-ec2'
import * as secretsmanager from 'aws-cdk-lib/aws-secretsmanager'

export class EducationPlatformStack extends cdk.Stack {
  constructor(scope: cdk.App, id: string, props?: cdk.StackProps) {
    super(scope, id, props)

    // VPC for database
    const vpc = new ec2.Vpc(this, 'EducationVPC', {
      maxAzs: 2,
      natGateways: 1,
    })

    // RDS PostgreSQL database
    const database = new rds.DatabaseInstance(this, 'EducationDB', {
      engine: rds.DatabaseInstanceEngine.postgres({
        version: rds.PostgresEngineVersion.VER_15_3,
      }),
      instanceType: ec2.InstanceType.of(ec2.InstanceClass.T3, ec2.InstanceSize.MICRO),
      vpc,
      databaseName: 'education_platform',
      backupRetention: cdk.Duration.days(7),
      deletionProtection: true,
      multiAz: true, // High availability
    })

    // Store database credentials in Secrets Manager
    const dbSecret = new secretsmanager.Secret(this, 'DatabaseSecret', {
      description: 'Database credentials for education platform',
      generateSecretString: {
        secretStringTemplate: JSON.stringify({ username: 'admin' }),
        generateStringKey: 'password',
        excludeCharacters: '"@/\\',
      },
    })

    // Amplify App
    const amplifyApp = new amplify.App(this, 'EducationPlatformApp', {
      sourceCodeProvider: new amplify.GitHubSourceCodeProvider({
        owner: 'your-github-username',
        repository: 'education-platform',
        oauthToken: cdk.SecretValue.secretsManager('github-token'),
      }),
      environmentVariables: {
        DATABASE_URL: `postgresql://admin:${dbSecret.secretValueFromJson('password')}@${database.instanceEndpoint.hostname}:5432/education_platform`,
        NEXTAUTH_SECRET: cdk.SecretValue.secretsManager('nextauth-secret').unsafeUnwrap(),
      },
      buildSpec: cdk.aws_codebuild.BuildSpec.fromObject({
        version: 1,
        applications: [{
          appRoot: '.',
          frontend: {
            phases: {
              preBuild: {
                commands: [
                  'npm ci',
                  'npx prisma generate',
                ],
              },
              build: {
                commands: ['npm run build'],
              },
            },
            artifacts: {
              baseDirectory: '.next',
              files: ['**/*'],
            },
          },
        }],
      }),
    })

    // Production branch
    const mainBranch = amplifyApp.addBranch('main', {
      branchName: 'main',
      stage: 'PRODUCTION',
    })

    // Staging branch
    const devBranch = amplifyApp.addBranch('develop', {
      branchName: 'develop',
      stage: 'DEVELOPMENT',
    })

    // Custom domain
    const domain = amplifyApp.addDomain('yourdomain.com', {
      subDomains: [
        { branchName: mainBranch.branchName, prefix: 'app' },
        { branchName: devBranch.branchName, prefix: 'staging' },
      ],
    })

    // Output URLs
    new cdk.CfnOutput(this, 'AppURL', {
      value: `https://app.yourdomain.com`,
    })

    new cdk.CfnOutput(this, 'StagingURL', {
      value: `https://staging.yourdomain.com`,
    })
  }
}
```

#### 3. Deployment Commands

```bash
# Install AWS CDK
npm install -g aws-cdk

# Configure AWS credentials
aws configure
# or use AWS CLI profiles
export AWS_PROFILE=education-platform

# Deploy infrastructure
cdk bootstrap
cdk deploy EducationPlatformStack

# Connect Amplify app to repository
aws amplify create-app --name education-platform --repository https://github.com/your-username/education-platform

# Create webhook for automatic deployments
aws amplify create-webhook --app-id d1yfvs0eg --branch-name main
```

## 3. 🟡 Railway Deployment (Developer-Friendly)

### Why Railway for Educational Platforms?

**Advantages:**
- **Simple deployment** with database included
- **Affordable pricing** for small to medium platforms
- **Built-in monitoring** and logging
- **Easy scaling** with reasonable pricing
- **Great for rapid prototyping**

**Ideal for:**
- MVP development
- Small educational platforms
- Rapid prototyping
- Developer-focused teams

### Railway Setup

#### 1. Project Structure

```bash
# Add Railway configuration
touch railway.toml Procfile
```

```toml
# railway.toml
[build]
builder = "NIXPACKS"

[deploy]
healthcheckPath = "/api/health"
healthcheckTimeout = 300
restartPolicyType = "ON_FAILURE"
restartPolicyMaxRetries = 10

[env]
NODE_ENV = "production"
```

```
# Procfile
web: npm start
release: npx prisma migrate deploy && npx prisma db seed
```

#### 2. Database Setup

```bash
# Install Railway CLI
npm install -g @railway/cli

# Login
railway login

# Initialize project
railway init

# Add PostgreSQL database
railway add --plugin postgresql

# Link environment variables
railway variables

# Set custom environment variables
railway variables set NEXTAUTH_SECRET=your-secret-here
railway variables set NEXTAUTH_URL=https://your-app.railway.app
```

#### 3. Deployment Configuration

```javascript
// next.config.js for Railway
/** @type {import('next').NextConfig} */
const nextConfig = {
  // Railway-specific optimizations
  output: 'standalone',
  
  // Handle Railway's dynamic port
  serverRuntimeConfig: {
    port: process.env.PORT || 3000,
  },
  
  // Optimize for Railway's build environment
  webpack: (config, { isServer }) => {
    if (isServer) {
      config.externals.push('@prisma/client')
    }
    return config
  },
}

module.exports = nextConfig
```

#### 4. Health Check Endpoint

```typescript
// src/app/api/health/route.ts
import { NextResponse } from 'next/server'
import { prisma } from '@/lib/db'

export async function GET() {
  try {
    // Check database connection
    await prisma.$queryRaw`SELECT 1`
    
    return NextResponse.json({
      status: 'healthy',
      timestamp: new Date().toISOString(),
      database: 'connected',
    })
  } catch (error) {
    console.error('Health check failed:', error)
    
    return NextResponse.json(
      {
        status: 'unhealthy',
        timestamp: new Date().toISOString(),
        database: 'disconnected',
        error: error.message,
      },
      { status: 503 }
    )
  }
}
```

#### 5. Deployment Commands

```bash
# Deploy to Railway
railway up

# Deploy specific service
railway up --service education-platform

# View logs
railway logs

# Connect to database
railway connect postgresql

# Run migrations
railway run npx prisma migrate deploy

# Set up custom domain
railway domain add yourdomain.com
```

## 4. 🔴 Self-Hosted Deployment (Full Control)

### Why Self-Hosted for Educational Platforms?

**Advantages:**
- **Complete control** over infrastructure and data
- **Cost-effective** for large-scale applications
- **Custom optimizations** for specific use cases
- **Compliance flexibility** for sensitive data
- **No vendor lock-in**

**Ideal for:**
- Large educational institutions
- Platforms with strict data requirements
- Cost-conscious high-traffic applications
- Custom infrastructure needs

### Docker-Based Self-Hosted Setup

#### 1. Dockerfile

```dockerfile
# Dockerfile
FROM node:18-alpine AS base

# Install dependencies only when needed
FROM base AS deps
RUN apk add --no-cache libc6-compat
WORKDIR /app

# Install dependencies based on the preferred package manager
COPY package.json yarn.lock* package-lock.json* pnpm-lock.yaml* ./
RUN \
  if [ -f yarn.lock ]; then yarn --frozen-lockfile; \
  elif [ -f package-lock.json ]; then npm ci; \
  elif [ -f pnpm-lock.yaml ]; then yarn global add pnpm && pnpm i --frozen-lockfile; \
  else echo "Lockfile not found." && exit 1; \
  fi

# Rebuild the source code only when needed
FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Generate Prisma client
RUN npx prisma generate

# Build the application
RUN npm run build

# Production image, copy all the files and run next
FROM base AS runner
WORKDIR /app

ENV NODE_ENV production

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

COPY --from=builder /app/public ./public

# Set the correct permission for prerender cache
RUN mkdir .next
RUN chown nextjs:nodejs .next

# Automatically leverage output traces to reduce image size
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs

EXPOSE 3000

ENV PORT 3000
ENV HOSTNAME "0.0.0.0"

CMD ["node", "server.js"]
```

#### 2. Docker Compose Setup

```yaml
# docker-compose.yml
version: '3.8'

services:
  # Next.js Application
  app:
    build: .
    ports:
      - "3000:3000"
    environment:
      - DATABASE_URL=postgresql://postgres:password@db:5432/education_platform
      - NEXTAUTH_SECRET=your-secret-here
      - NEXTAUTH_URL=https://yourdomain.com
      - REDIS_URL=redis://redis:6379
    depends_on:
      - db
      - redis
    volumes:
      - ./uploads:/app/uploads
    restart: unless-stopped
    networks:
      - education_network

  # PostgreSQL Database
  db:
    image: postgres:15-alpine
    environment:
      - POSTGRES_DB=education_platform
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=password
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./backups:/backups
    ports:
      - "5432:5432"
    restart: unless-stopped
    networks:
      - education_network

  # Redis Cache
  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    restart: unless-stopped
    networks:
      - education_network

  # Nginx Reverse Proxy
  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
      - ./ssl:/etc/nginx/ssl
      - ./static:/var/www/static
    depends_on:
      - app
    restart: unless-stopped
    networks:
      - education_network

  # Certbot for SSL
  certbot:
    image: certbot/certbot
    volumes:
      - ./ssl:/etc/letsencrypt
      - ./static:/var/www/certbot
    command: certonly --webroot --webroot-path=/var/www/certbot --email admin@yourdomain.com --agree-tos --no-eff-email -d yourdomain.com -d www.yourdomain.com

volumes:
  postgres_data:
  redis_data:

networks:
  education_network:
    driver: bridge
```

#### 3. Nginx Configuration

```nginx
# nginx.conf
events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    # Logging
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;
    error_log /var/log/nginx/error.log;

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

    # Rate limiting
    limit_req_zone $binary_remote_addr zone=login:10m rate=5r/m;
    limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;

    # SSL configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;

    # Main server block
    server {
        listen 80;
        server_name yourdomain.com www.yourdomain.com;

        # Certbot challenge
        location /.well-known/acme-challenge/ {
            root /var/www/certbot;
        }

        # Redirect to HTTPS
        location / {
            return 301 https://$server_name$request_uri;
        }
    }

    server {
        listen 443 ssl http2;
        server_name yourdomain.com www.yourdomain.com;

        # SSL certificates
        ssl_certificate /etc/letsencrypt/live/yourdomain.com/fullchain.pem;
        ssl_certificate_key /etc/letsencrypt/live/yourdomain.com/privkey.pem;

        # Security headers
        add_header X-Frame-Options DENY;
        add_header X-Content-Type-Options nosniff;
        add_header X-XSS-Protection "1; mode=block";
        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

        # Static file caching
        location /_next/static/ {
            alias /var/www/static/;
            expires 1y;
            add_header Cache-Control "public, immutable";
        }

        # API rate limiting
        location /api/ {
            limit_req zone=api burst=20 nodelay;
            proxy_pass http://app:3000;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        # Login rate limiting
        location /api/auth/ {
            limit_req zone=login burst=5 nodelay;
            proxy_pass http://app:3000;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        # Main application
        location / {
            proxy_pass http://app:3000;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            
            # WebSocket support
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_cache_bypass $http_upgrade;
        }
    }
}
```

#### 4. Deployment Scripts

```bash
#!/bin/bash
# deploy.sh

set -e

echo "🚀 Starting deployment..."

# Pull latest changes
git pull origin main

# Build and deploy
docker-compose down
docker-compose build --no-cache
docker-compose up -d

# Run database migrations
docker-compose exec app npx prisma migrate deploy

# Health check
echo "⏳ Waiting for services to start..."
sleep 30

if curl -f http://localhost:3000/api/health; then
    echo "✅ Deployment successful!"
else
    echo "❌ Deployment failed!"
    exit 1
fi

# Cleanup old images
docker image prune -f

echo "🎉 Deployment complete!"
```

#### 5. Monitoring Setup

```yaml
# monitoring/docker-compose.monitoring.yml
version: '3.8'

services:
  # Prometheus
  prometheus:
    image: prom/prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'

  # Grafana
  grafana:
    image: grafana/grafana
    ports:
      - "3001:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
    volumes:
      - grafana_data:/var/lib/grafana
      - ./grafana/dashboards:/etc/grafana/provisioning/dashboards
      - ./grafana/datasources:/etc/grafana/provisioning/datasources

  # Node Exporter
  node-exporter:
    image: prom/node-exporter
    ports:
      - "9100:9100"
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.rootfs=/rootfs'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'

volumes:
  prometheus_data:
  grafana_data:
```

## 📊 Cost Analysis

### Monthly Cost Comparison (1000 Students)

| Platform | Basic | Growth | Enterprise | Notes |
|----------|-------|--------|------------|-------|
| **Vercel** | $0 | $20 | $400+ | Perfect for MVP |
| **AWS Amplify** | $15 | $50 | $200+ | Best for scaling |
| **Railway** | $5 | $20 | $100+ | Simple pricing |
| **DigitalOcean** | $20 | $40 | $100+ | Predictable costs |
| **Self-hosted** | $50+ | $100+ | $300+ | Full control |

### Resource Requirements by Scale

| Students | CPU | RAM | Storage | Bandwidth | Database |
|----------|-----|-----|---------|-----------|----------|
| **1K** | 1 vCPU | 2GB | 10GB | 100GB | 1GB |
| **10K** | 2 vCPU | 4GB | 50GB | 500GB | 10GB |
| **100K** | 4 vCPU | 8GB | 200GB | 2TB | 50GB |
| **1M** | 8+ vCPU | 16GB+ | 1TB+ | 10TB+ | 200GB+ |

## 🔒 Security Considerations

### SSL/TLS Configuration

```bash
# Generate SSL certificates with Let's Encrypt
certbot certonly --webroot \
  --webroot-path=/var/www/certbot \
  --email admin@yourdomain.com \
  --agree-tos \
  --no-eff-email \
  -d yourdomain.com \
  -d www.yourdomain.com

# Auto-renewal cron job
0 12 * * * /usr/bin/certbot renew --quiet
```

### Environment Security

```bash
# .env.production (example)
NODE_ENV=production
DATABASE_URL="postgresql://user:secure_password@localhost:5432/education_platform"
NEXTAUTH_SECRET="32-character-random-string-here"
NEXTAUTH_URL="https://yourdomain.com"

# Stripe (production keys)
STRIPE_SECRET_KEY="sk_live_your_key_here"
STRIPE_PUBLISHABLE_KEY="pk_live_your_key_here"

# Email service
EMAIL_SERVER_HOST=smtp.sendgrid.net
EMAIL_SERVER_PORT=587
EMAIL_SERVER_USER=apikey
EMAIL_SERVER_PASSWORD=SG.your_sendgrid_api_key

# Redis (if used)
REDIS_URL="redis://localhost:6379"

# Monitoring
SENTRY_DSN="https://your_sentry_dsn_here"
```

## 📈 Scaling Strategies

### Horizontal Scaling

```yaml
# kubernetes/deployment.yml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: education-platform
spec:
  replicas: 3
  selector:
    matchLabels:
      app: education-platform
  template:
    metadata:
      labels:
        app: education-platform
    spec:
      containers:
      - name: app
        image: education-platform:latest
        ports:
        - containerPort: 3000
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: db-secret
              key: url
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "1Gi"
            cpu: "500m"
---
apiVersion: v1
kind: Service
metadata:
  name: education-platform-service
spec:
  selector:
    app: education-platform
  ports:
  - port: 80
    targetPort: 3000
  type: LoadBalancer
```

### Database Scaling

```typescript
// lib/db-read-replica.ts
import { PrismaClient } from '@prisma/client'

// Master database for writes
export const masterDb = new PrismaClient({
  datasources: {
    db: {
      url: process.env.DATABASE_URL,
    },
  },
})

// Read replica for queries
export const replicaDb = new PrismaClient({
  datasources: {
    db: {
      url: process.env.DATABASE_REPLICA_URL,
    },
  },
})

// Smart query router
export async function getCoursesOptimized() {
  // Use read replica for queries
  return await replicaDb.course.findMany({
    where: { published: true },
    orderBy: { createdAt: 'desc' },
  })
}

export async function createCourse(data: any) {
  // Use master database for writes
  return await masterDb.course.create({ data })
}
```

## 🔗 Related Documentation

### Previous: [Performance Analysis](./performance-analysis.md)
### Next: [Security Considerations](./security-considerations.md)

---

*Deployment Guide | Next.js Full Stack Development | 2024*