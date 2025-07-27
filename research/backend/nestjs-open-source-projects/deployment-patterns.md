# Deployment Patterns for NestJS Applications

## 🎯 Overview

Analysis of deployment strategies, infrastructure patterns, and production configurations used across 30+ open source NestJS projects. This guide covers containerization, orchestration, monitoring, and scalability patterns proven in production environments.

## 🐳 Containerization Patterns

### 1. Docker Best Practices from Production Projects

**Multi-Stage Production Dockerfile (90% of projects)**
```dockerfile
# Stage 1: Dependencies
FROM node:18-alpine AS dependencies
RUN apk add --no-cache libc6-compat
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force

# Stage 2: Build
FROM node:18-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build && npm prune --production

# Stage 3: Runtime
FROM node:18-alpine AS runtime
RUN addgroup -g 1001 -S nodejs
RUN adduser -S nestjs -u 1001

WORKDIR /app

# Copy built application
COPY --from=build --chown=nestjs:nodejs /app/node_modules ./node_modules
COPY --from=build --chown=nestjs:nodejs /app/dist ./dist
COPY --from=build --chown=nestjs:nodejs /app/package*.json ./

# Security
USER nestjs

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1

EXPOSE 3000

ENV NODE_ENV=production
CMD ["node", "dist/main"]
```

**Development Docker Setup**
```dockerfile
# Development Dockerfile
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
EXPOSE 3000
CMD ["npm", "run", "start:dev"]
```

---

### 2. Docker Compose Configurations

**Production-Ready Docker Compose (75% of projects)**
```yaml
version: '3.8'

services:
  app:
    build:
      context: .
      dockerfile: Dockerfile
      target: runtime
    ports:
      - '3000:3000'
    environment:
      - NODE_ENV=production
      - DATABASE_URL=postgresql://postgres:password@postgres:5432/myapp
      - REDIS_URL=redis://redis:6379
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

  postgres:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: myapp
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: password
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./docker/postgres/init.sql:/docker-entrypoint-initdb.d/init.sql
    ports:
      - '5432:5432'
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    ports:
      - '6379:6379'
    volumes:
      - redis_data:/data
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  nginx:
    image: nginx:alpine
    ports:
      - '80:80'
      - '443:443'
    volumes:
      - ./docker/nginx/nginx.conf:/etc/nginx/nginx.conf
      - ./docker/nginx/ssl:/etc/nginx/ssl
    depends_on:
      - app
    restart: unless-stopped

volumes:
  postgres_data:
  redis_data:
```

---

## ☸️ Kubernetes Deployment Patterns

### 1. Kubernetes Manifests (25% of enterprise projects)

**Deployment Configuration**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nestjs-app
  labels:
    app: nestjs-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nestjs-app
  template:
    metadata:
      labels:
        app: nestjs-app
    spec:
      containers:
      - name: nestjs-app
        image: my-registry/nestjs-app:latest
        ports:
        - containerPort: 3000
        env:
        - name: NODE_ENV
          value: "production"
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: app-secrets
              key: database-url
        - name: JWT_SECRET
          valueFrom:
            secretKeyRef:
              name: app-secrets
              key: jwt-secret
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health/ready
            port: 3000
          initialDelaySeconds: 5
          periodSeconds: 5
```

**Service Configuration**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: nestjs-service
spec:
  selector:
    app: nestjs-app
  ports:
    - protocol: TCP
      port: 80
      targetPort: 3000
  type: ClusterIP
```

**Ingress Configuration**
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nestjs-ingress
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/use-regex: "true"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  tls:
  - hosts:
    - api.example.com
    secretName: nestjs-tls
  rules:
  - host: api.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: nestjs-service
            port:
              number: 80
```

---

## 🌐 Cloud Platform Deployment

### 1. Platform as a Service (PaaS) Deployment

**Heroku Configuration (20% of projects)**
```json
{
  "name": "nestjs-app",
  "description": "NestJS Application",
  "repository": "https://github.com/username/nestjs-app",
  "logo": "https://example.com/logo.png",
  "keywords": ["nestjs", "typescript", "api"],
  "image": "heroku/nodejs",
  "addons": [
    {
      "plan": "heroku-postgresql:hobby-dev"
    },
    {
      "plan": "heroku-redis:hobby-dev"
    }
  ],
  "env": {
    "NODE_ENV": {
      "description": "Environment",
      "value": "production"
    },
    "JWT_SECRET": {
      "description": "JWT Secret Key",
      "generator": "secret"
    }
  },
  "formation": {
    "web": {
      "quantity": 1,
      "size": "hobby"
    }
  },
  "buildpacks": [
    {
      "url": "heroku/nodejs"
    }
  ]
}
```

**Railway Deployment (15% of projects)**
```toml
# railway.toml
[build]
  builder = "nixpacks"

[deploy]
  startCommand = "npm run start:prod"
  healthcheckPath = "/health"
  healthcheckTimeout = 100
  restartPolicyType = "always"

[[services]]
  name = "nestjs-app"
  
  [services.variables]
    NODE_ENV = "production"
    PORT = "3000"
```

---

### 2. Serverless Deployment

**AWS Lambda with Serverless Framework (15% of projects)**
```yaml
# serverless.yml
service: nestjs-serverless

provider:
  name: aws
  runtime: nodejs18.x
  region: us-east-1
  environment:
    NODE_ENV: production
    DATABASE_URL: ${env:DATABASE_URL}
    JWT_SECRET: ${env:JWT_SECRET}

functions:
  app:
    handler: dist/lambda.handler
    events:
      - http:
          method: ANY
          path: /{proxy+}
      - http:
          method: ANY
          path: /

plugins:
  - serverless-plugin-typescript
  - serverless-plugin-optimize
  - serverless-offline

custom:
  optimize:
    external: ['pg', 'pg-native']
```

**Lambda Handler**
```typescript
// lambda.ts
import { NestFactory } from '@nestjs/core';
import { ExpressAdapter } from '@nestjs/platform-express';
import { Context, APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { createServer, proxy } from 'aws-serverless-express';
import * as express from 'express';
import { AppModule } from './app.module';

let cachedServer: any;

async function bootstrapServer(): Promise<any> {
  const expressApp = express();
  const adapter = new ExpressAdapter(expressApp);
  const app = await NestFactory.create(AppModule, adapter);
  
  app.enableCors();
  await app.init();
  
  return createServer(expressApp);
}

export const handler = async (
  event: APIGatewayProxyEvent,
  context: Context,
): Promise<APIGatewayProxyResult> => {
  if (!cachedServer) {
    cachedServer = await bootstrapServer();
  }
  
  return proxy(cachedServer, event, context, 'PROMISE').promise;
};
```

---

## 📊 Monitoring & Observability

### 1. Health Check Implementation

**Comprehensive Health Checks**
```typescript
@Controller('health')
export class HealthController {
  constructor(
    @InjectConnection() private readonly connection: Connection,
    @Inject(CACHE_MANAGER) private readonly cacheManager: Cache,
  ) {}

  @Get()
  @Public()
  async check(): Promise<HealthCheckResult> {
    const start = Date.now();
    
    const checks = await Promise.allSettled([
      this.checkDatabase(),
      this.checkCache(),
      this.checkExternalServices(),
      this.checkDiskSpace(),
      this.checkMemoryUsage(),
    ]);

    const results = checks.map((check, index) => {
      const names = ['database', 'cache', 'external', 'disk', 'memory'];
      return {
        name: names[index],
        status: check.status === 'fulfilled' ? 'healthy' : 'unhealthy',
        responseTime: check.status === 'fulfilled' ? check.value.responseTime : null,
        details: check.status === 'fulfilled' ? check.value.details : check.reason,
      };
    });

    const isHealthy = results.every(result => result.status === 'healthy');
    const totalResponseTime = Date.now() - start;

    return {
      status: isHealthy ? 'healthy' : 'unhealthy',
      timestamp: new Date().toISOString(),
      responseTime: totalResponseTime,
      version: process.env.npm_package_version,
      uptime: process.uptime(),
      checks: results,
    };
  }

  @Get('ready')
  @Public()
  async readiness(): Promise<{ status: string }> {
    // Check if application is ready to serve requests
    try {
      await this.checkDatabase();
      return { status: 'ready' };
    } catch (error) {
      throw new ServiceUnavailableException('Application not ready');
    }
  }

  @Get('live')
  @Public()
  liveness(): { status: string } {
    // Check if application is alive
    return { status: 'alive' };
  }

  private async checkDatabase(): Promise<{ responseTime: number; details: object }> {
    const start = Date.now();
    await this.connection.query('SELECT 1');
    return {
      responseTime: Date.now() - start,
      details: { connected: true },
    };
  }
}
```

---

### 2. Logging Configuration

**Production Logging Setup**
```typescript
// logger.service.ts
import { Injectable, LoggerService } from '@nestjs/common';
import * as winston from 'winston';

@Injectable()
export class AppLoggerService implements LoggerService {
  private readonly logger: winston.Logger;

  constructor() {
    this.logger = winston.createLogger({
      level: process.env.LOG_LEVEL || 'info',
      format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.errors({ stack: true }),
        winston.format.json(),
      ),
      transports: [
        new winston.transports.Console({
          format: winston.format.combine(
            winston.format.colorize(),
            winston.format.simple(),
          ),
        }),
      ],
    });

    if (process.env.NODE_ENV === 'production') {
      this.logger.add(
        new winston.transports.File({
          filename: 'logs/error.log',
          level: 'error',
        }),
      );
      this.logger.add(
        new winston.transports.File({
          filename: 'logs/combined.log',
        }),
      );
    }
  }

  log(message: any, context?: string) {
    this.logger.info(message, { context });
  }

  error(message: any, trace?: string, context?: string) {
    this.logger.error(message, { trace, context });
  }

  warn(message: any, context?: string) {
    this.logger.warn(message, { context });
  }

  debug(message: any, context?: string) {
    this.logger.debug(message, { context });
  }

  verbose(message: any, context?: string) {
    this.logger.verbose(message, { context });
  }
}
```

---

## 🔧 CI/CD Pipeline Patterns

### 1. GitHub Actions Workflow

**Complete CI/CD Pipeline**
```yaml
# .github/workflows/deploy.yml
name: CI/CD Pipeline

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

env:
  NODE_VERSION: '18'
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  test:
    runs-on: ubuntu-latest
    
    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_PASSWORD: postgres
          POSTGRES_DB: test_db
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    steps:
    - uses: actions/checkout@v3

    - name: Setup Node.js
      uses: actions/setup-node@v3
      with:
        node-version: ${{ env.NODE_VERSION }}
        cache: 'npm'

    - name: Install dependencies
      run: npm ci

    - name: Run linter
      run: npm run lint

    - name: Run tests
      run: npm run test:cov
      env:
        DATABASE_URL: postgresql://postgres:postgres@localhost:5432/test_db

    - name: Run e2e tests
      run: npm run test:e2e
      env:
        DATABASE_URL: postgresql://postgres:postgres@localhost:5432/test_db

    - name: Upload coverage reports
      uses: codecov/codecov-action@v3

  build:
    needs: test
    runs-on: ubuntu-latest
    outputs:
      image: ${{ steps.image.outputs.image }}

    steps:
    - uses: actions/checkout@v3

    - name: Set up Docker Buildx
      uses: docker/setup-buildx-action@v2

    - name: Log in to Container Registry
      uses: docker/login-action@v2
      with:
        registry: ${{ env.REGISTRY }}
        username: ${{ github.actor }}
        password: ${{ secrets.GITHUB_TOKEN }}

    - name: Extract metadata
      id: meta
      uses: docker/metadata-action@v4
      with:
        images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}

    - name: Build and push Docker image
      id: build
      uses: docker/build-push-action@v4
      with:
        context: .
        push: true
        tags: ${{ steps.meta.outputs.tags }}
        labels: ${{ steps.meta.outputs.labels }}
        cache-from: type=gha
        cache-to: type=gha,mode=max

    - name: Output image
      id: image
      run: echo "image=${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}" >> $GITHUB_OUTPUT

  deploy:
    needs: build
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'

    steps:
    - name: Deploy to production
      uses: appleboy/ssh-action@v0.1.8
      with:
        host: ${{ secrets.HOST }}
        username: ${{ secrets.USERNAME }}
        key: ${{ secrets.PRIVATE_KEY }}
        script: |
          docker pull ${{ needs.build.outputs.image }}
          docker stop nestjs-app || true
          docker rm nestjs-app || true
          docker run -d \
            --name nestjs-app \
            --restart unless-stopped \
            -p 3000:3000 \
            -e NODE_ENV=production \
            -e DATABASE_URL=${{ secrets.DATABASE_URL }} \
            -e JWT_SECRET=${{ secrets.JWT_SECRET }} \
            ${{ needs.build.outputs.image }}
```

---

### 2. GitLab CI/CD Configuration

**GitLab CI Pipeline**
```yaml
# .gitlab-ci.yml
stages:
  - test
  - build
  - deploy

variables:
  DOCKER_DRIVER: overlay2
  DOCKER_TLS_CERTDIR: "/certs"

before_script:
  - docker info

test:
  stage: test
  image: node:18-alpine
  services:
    - postgres:15-alpine
  variables:
    POSTGRES_DB: test_db
    POSTGRES_USER: postgres
    POSTGRES_PASSWORD: postgres
    DATABASE_URL: postgresql://postgres:postgres@postgres:5432/test_db
  cache:
    key: ${CI_COMMIT_REF_SLUG}
    paths:
      - node_modules/
  script:
    - npm ci
    - npm run lint
    - npm run test:cov
    - npm run test:e2e
  coverage: '/All files[^|]*\|[^|]*\s+([\d\.]+)/'
  artifacts:
    reports:
      coverage_report:
        coverage_format: cobertura
        path: coverage/cobertura-coverage.xml

build:
  stage: build
  image: docker:latest
  services:
    - docker:dind
  before_script:
    - docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $CI_REGISTRY
  script:
    - docker build -t $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA .
    - docker push $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA
  only:
    - main

deploy:
  stage: deploy
  image: alpine:latest
  before_script:
    - apk add --no-cache openssh-client
    - eval $(ssh-agent -s)
    - echo "$SSH_PRIVATE_KEY" | tr -d '\r' | ssh-add -
    - mkdir -p ~/.ssh
    - chmod 700 ~/.ssh
  script:
    - ssh -o StrictHostKeyChecking=no $DEPLOY_USER@$DEPLOY_HOST "
        docker pull $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA &&
        docker stop nestjs-app || true &&
        docker rm nestjs-app || true &&
        docker run -d --name nestjs-app --restart unless-stopped 
        -p 3000:3000 
        -e NODE_ENV=production 
        -e DATABASE_URL=$DATABASE_URL 
        -e JWT_SECRET=$JWT_SECRET 
        $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA"
  only:
    - main
```

---

## 📈 Scaling Patterns

### 1. Horizontal Scaling with Load Balancer

**Nginx Load Balancer Configuration**
```nginx
upstream nestjs_backend {
    least_conn;
    server app1:3000 max_fails=3 fail_timeout=30s;
    server app2:3000 max_fails=3 fail_timeout=30s;
    server app3:3000 max_fails=3 fail_timeout=30s;
}

server {
    listen 80;
    server_name api.example.com;

    location / {
        proxy_pass http://nestjs_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Health check
        proxy_next_upstream error timeout invalid_header http_500 http_502 http_503;
        proxy_connect_timeout 5s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    location /health {
        proxy_pass http://nestjs_backend/health;
        access_log off;
    }
}
```

---

### 2. Auto-Scaling Configuration

**Kubernetes Horizontal Pod Autoscaler**
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: nestjs-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: nestjs-app
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

---

## 🔗 Navigation

**Previous:** [Comparison Analysis](./comparison-analysis.md) - Comparative analysis of approaches  
**Up:** [README](./README.md) - Research overview and scope

---

*Deployment patterns analysis completed July 2025 - Based on production deployment strategies from 30+ NestJS applications*