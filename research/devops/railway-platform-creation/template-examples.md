# Template Examples: Railway.com-like Platform

## 🎯 Working Code Templates and Examples

This document provides complete, working examples of key components for building a Railway.com-like platform. These templates can be used as starting points for your implementation.

## 📁 Project Structure Template

### **Complete Monorepo Structure**
```
railway-platform/
├── README.md
├── docker-compose.yml
├── .gitignore
├── .github/
│   └── workflows/
│       ├── ci.yml
│       ├── deploy-staging.yml
│       └── deploy-production.yml
├── backend/
│   ├── cmd/
│   │   ├── api/main.go
│   │   ├── worker/main.go
│   │   └── cli/main.go
│   ├── internal/
│   │   ├── auth/
│   │   ├── project/
│   │   ├── deployment/
│   │   ├── database/
│   │   └── websocket/
│   ├── pkg/
│   │   ├── config/
│   │   ├── logger/
│   │   ├── metrics/
│   │   └── middleware/
│   ├── api/
│   │   └── proto/
│   ├── migrations/
│   ├── Dockerfile
│   ├── go.mod
│   └── go.sum
├── frontend/
│   ├── src/
│   │   ├── components/
│   │   ├── pages/
│   │   ├── hooks/
│   │   ├── stores/
│   │   ├── lib/
│   │   └── types/
│   ├── public/
│   ├── package.json
│   ├── next.config.js
│   ├── tailwind.config.js
│   └── Dockerfile
├── infrastructure/
│   ├── terraform/
│   │   ├── modules/
│   │   ├── environments/
│   │   └── global/
│   ├── k8s/
│   │   ├── base/
│   │   ├── overlays/
│   │   └── operators/
│   └── helm/
│       └── railway-platform/
├── scripts/
│   ├── setup-dev.sh
│   ├── build.sh
│   ├── deploy.sh
│   └── backup.sh
└── docs/
    ├── api/
    ├── deployment/
    └── development/
```

## 🔧 Docker & Container Templates

### **Multi-stage Production Dockerfile (Go API)**
```dockerfile
# backend/Dockerfile
FROM golang:1.21-alpine AS builder

# Install git for private repositories and ca-certificates for SSL
RUN apk add --no-cache git ca-certificates tzdata

# Create non-root user
RUN adduser -D -g '' appuser

WORKDIR /app

# Copy go mod files for better caching
COPY go.mod go.sum ./
RUN go mod download && go mod verify

# Copy source code
COPY . .

# Build the binary with security flags
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags='-w -s -extldflags "-static"' \
    -a -installsuffix cgo \
    -o main ./cmd/api

# Production image - distroless for security
FROM gcr.io/distroless/static:nonroot

# Copy timezone data and CA certificates
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

# Copy the binary
COPY --from=builder /app/main /main

# Use non-root user
USER nonroot:nonroot

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD ["/main", "healthcheck"]

EXPOSE 8080

ENTRYPOINT ["/main"]
```

### **Frontend Dockerfile (Next.js)**
```dockerfile
# frontend/Dockerfile
FROM node:18-alpine AS base

# Install dependencies only when needed
FROM base AS deps
RUN apk add --no-cache libc6-compat
WORKDIR /app

# Install dependencies based on the preferred package manager
COPY package.json package-lock.json* ./
RUN \
  if [ -f package-lock.json ]; then npm ci --only=production; \
  else echo "Lockfile not found." && exit 1; \
  fi

# Rebuild the source code only when needed
FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Environment variables must be present at build time
ARG NEXT_PUBLIC_API_URL
ENV NEXT_PUBLIC_API_URL=${NEXT_PUBLIC_API_URL}

# Build the app
RUN npm run build

# Production image
FROM base AS runner
WORKDIR /app

ENV NODE_ENV production

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

COPY --from=builder /app/public ./public

# Automatically leverage output traces to reduce image size
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs

EXPOSE 3000

ENV PORT 3000

CMD ["node", "server.js"]
```

### **Development Docker Compose**
```yaml
# docker-compose.yml
version: '3.8'

services:
  api:
    build:
      context: ./backend
      dockerfile: Dockerfile.dev
    ports:
      - "8080:8080"
    environment:
      - DATABASE_URL=postgres://railway:password@postgres:5432/railway_dev
      - REDIS_URL=redis://redis:6379
      - JWT_SECRET=dev-secret-key
      - LOG_LEVEL=debug
    volumes:
      - ./backend:/app
      - go_cache:/go/pkg/mod
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    restart: unless-stopped

  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile.dev
    ports:
      - "3000:3000"
    environment:
      - NEXT_PUBLIC_API_URL=http://localhost:8080
      - NEXT_PUBLIC_WS_URL=ws://localhost:8080
    volumes:
      - ./frontend:/app
      - node_modules:/app/node_modules
    restart: unless-stopped

  postgres:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: railway_dev
      POSTGRES_USER: railway
      POSTGRES_PASSWORD: password
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./backend/migrations:/docker-entrypoint-initdb.d
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U railway -d railway_dev"]
      interval: 5s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 5

  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./monitoring/prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3001:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
    volumes:
      - grafana_data:/var/lib/grafana
      - ./monitoring/grafana:/etc/grafana/provisioning

volumes:
  postgres_data:
  redis_data:
  prometheus_data:
  grafana_data:
  go_cache:
  node_modules:
```

## 🚀 Kubernetes Deployment Templates

### **Complete Kubernetes Manifests**
```yaml
# k8s/namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: railway-system
  labels:
    name: railway-system
    app.kubernetes.io/name: railway-platform
---
apiVersion: v1
kind: Namespace
metadata:
  name: user-workloads
  labels:
    name: user-workloads
    app.kubernetes.io/name: railway-platform
```

```yaml
# k8s/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: railway-config
  namespace: railway-system
data:
  app.yaml: |
    server:
      port: 8080
      host: "0.0.0.0"
      read_timeout: 30s
      write_timeout: 30s
    
    database:
      max_open_conns: 25
      max_idle_conns: 5
      conn_max_lifetime: 300s
    
    redis:
      pool_size: 10
      min_idle_conns: 5
    
    deployment:
      max_concurrent: 5
      timeout: 600s
      cleanup_after: 24h
    
    metrics:
      enabled: true
      path: "/metrics"
    
    logging:
      level: "info"
      format: "json"
```

```yaml
# k8s/secrets.yaml
apiVersion: v1
kind: Secret
metadata:
  name: railway-secrets
  namespace: railway-system
type: Opaque
data:
  database-url: cG9zdGdyZXM6Ly91c2VyOnBhc3N3b3JkQGhvc3Q6cG9ydC9kYiA=  # base64 encoded
  redis-url: cmVkaXM6Ly91c2VyOnBhc3N3b3JkQGhvc3Q6cG9ydA==          # base64 encoded
  jwt-secret: c29tZS1zZWNyZXQta2V5                                  # base64 encoded
  github-webhook-secret: Z2l0aHViLXdlYmhvb2stc2VjcmV0             # base64 encoded
```

```yaml
# k8s/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: railway-api
  namespace: railway-system
  labels:
    app: railway-api
    component: backend
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  selector:
    matchLabels:
      app: railway-api
  template:
    metadata:
      labels:
        app: railway-api
        component: backend
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
        prometheus.io/path: "/metrics"
    spec:
      serviceAccountName: railway-api
      securityContext:
        runAsNonRoot: true
        runAsUser: 65534
        fsGroup: 65534
      containers:
      - name: api
        image: railway/api:latest
        imagePullPolicy: Always
        ports:
        - containerPort: 8080
          name: http
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: railway-secrets
              key: database-url
        - name: REDIS_URL
          valueFrom:
            secretKeyRef:
              name: railway-secrets
              key: redis-url
        - name: JWT_SECRET
          valueFrom:
            secretKeyRef:
              name: railway-secrets
              key: jwt-secret
        - name: CONFIG_PATH
          value: "/etc/railway/app.yaml"
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
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
          timeoutSeconds: 3
          successThreshold: 1
          failureThreshold: 3
        volumeMounts:
        - name: config
          mountPath: /etc/railway
          readOnly: true
      volumes:
      - name: config
        configMap:
          name: railway-config
      restartPolicy: Always
```

```yaml
# k8s/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: railway-api-service
  namespace: railway-system
  labels:
    app: railway-api
spec:
  selector:
    app: railway-api
  ports:
  - name: http
    port: 80
    targetPort: 8080
    protocol: TCP
  type: ClusterIP
```

```yaml
# k8s/ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: railway-ingress
  namespace: railway-system
  annotations:
    kubernetes.io/ingress.class: "nginx"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    nginx.ingress.kubernetes.io/proxy-body-size: "100m"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "600"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "600"
spec:
  tls:
  - hosts:
    - api.railway.com
    - app.railway.com
    secretName: railway-tls
  rules:
  - host: api.railway.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: railway-api-service
            port:
              number: 80
  - host: app.railway.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: railway-frontend-service
            port:
              number: 80
```

```yaml
# k8s/hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: railway-api-hpa
  namespace: railway-system
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: railway-api
  minReplicas: 3
  maxReplicas: 20
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
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
      - type: Percent
        value: 50
        periodSeconds: 60
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 10
        periodSeconds: 60
```

## 🏗 Terraform Infrastructure Templates

### **Complete AWS Infrastructure**
```hcl
# terraform/main.tf
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  backend "s3" {
    bucket = "railway-terraform-state"
    key    = "infrastructure/terraform.tfstate"
    region = "us-west-2"
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project     = "railway-platform"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# VPC and Networking
module "vpc" {
  source = "./modules/vpc"
  
  environment = var.environment
  vpc_cidr    = var.vpc_cidr
  
  availability_zones = data.aws_availability_zones.available.names
  
  tags = local.common_tags
}

# EKS Cluster
module "eks" {
  source = "./modules/eks"
  
  cluster_name    = "${var.environment}-railway-cluster"
  cluster_version = "1.27"
  
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
  
  node_groups = {
    general = {
      instance_types = ["m6i.large"]
      min_size      = 2
      max_size      = 10
      desired_size  = 3
    }
    
    compute = {
      instance_types = ["c6i.xlarge"]
      min_size      = 0
      max_size      = 20
      desired_size  = 0
      
      labels = {
        role = "compute"
      }
      
      taints = [
        {
          key    = "compute"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      ]
    }
  }
  
  tags = local.common_tags
}

# RDS Database
module "rds" {
  source = "./modules/rds"
  
  identifier = "${var.environment}-railway-db"
  
  engine         = "postgres"
  engine_version = "15.3"
  instance_class = var.db_instance_class
  
  allocated_storage     = 100
  max_allocated_storage = 1000
  
  database_name = "railway"
  username      = "railway_admin"
  password      = var.db_password
  
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.database_subnet_ids
  
  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"
  
  tags = local.common_tags
}

# ElastiCache Redis
module "redis" {
  source = "./modules/redis"
  
  cluster_id = "${var.environment}-railway-redis"
  
  node_type     = "cache.t3.micro"
  num_nodes     = 2
  port          = 6379
  
  subnet_group_name = module.vpc.elasticache_subnet_group_name
  security_group_id = module.vpc.elasticache_security_group_id
  
  tags = local.common_tags
}

# S3 Buckets
module "s3" {
  source = "./modules/s3"
  
  environment = var.environment
  
  buckets = {
    backups = {
      name = "${var.environment}-railway-backups"
      versioning = true
      lifecycle_rules = [
        {
          id     = "delete_old_backups"
          status = "Enabled"
          expiration = {
            days = 90
          }
        }
      ]
    }
    
    logs = {
      name = "${var.environment}-railway-logs"
      versioning = false
      lifecycle_rules = [
        {
          id     = "delete_old_logs"
          status = "Enabled"
          expiration = {
            days = 30
          }
        }
      ]
    }
  }
  
  tags = local.common_tags
}

# CloudWatch
module "monitoring" {
  source = "./modules/monitoring"
  
  environment = var.environment
  
  log_groups = [
    "/aws/eks/${var.environment}-railway-cluster/cluster",
    "/railway/api",
    "/railway/frontend",
    "/railway/worker"
  ]
  
  sns_topic_name = "${var.environment}-railway-alerts"
  
  tags = local.common_tags
}

# Variables
variable "environment" {
  description = "Environment name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.medium"
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

# Locals
locals {
  common_tags = {
    Project     = "railway-platform"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

# Outputs
output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "database_endpoint" {
  description = "RDS database endpoint"
  value       = module.rds.endpoint
  sensitive   = true
}

output "redis_endpoint" {
  description = "Redis cluster endpoint"
  value       = module.redis.endpoint
}
```

## 🔄 CI/CD Pipeline Templates

### **GitHub Actions Workflow**
```yaml
# .github/workflows/ci-cd.yml
name: CI/CD Pipeline

on:
  push:
    branches: [main, develop]
    tags: ['v*']
  pull_request:
    branches: [main, develop]

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  test:
    name: Test
    runs-on: ubuntu-latest
    
    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_PASSWORD: test
          POSTGRES_DB: railway_test
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 5432:5432
      
      redis:
        image: redis:7
        options: >-
          --health-cmd "redis-cli ping"
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 6379:6379
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v4
    
    - name: Set up Go
      uses: actions/setup-go@v4
      with:
        go-version: '1.21'
        cache: true
        cache-dependency-path: backend/go.sum
    
    - name: Set up Node.js
      uses: actions/setup-node@v4
      with:
        node-version: '18'
        cache: 'npm'
        cache-dependency-path: frontend/package-lock.json
    
    - name: Install backend dependencies
      working-directory: backend
      run: go mod download
    
    - name: Install frontend dependencies
      working-directory: frontend
      run: npm ci
    
    - name: Run backend tests
      working-directory: backend
      env:
        DATABASE_URL: postgres://postgres:test@localhost:5432/railway_test?sslmode=disable
        REDIS_URL: redis://localhost:6379
      run: |
        go test -v -race -coverprofile=coverage.out ./...
        go tool cover -html=coverage.out -o coverage.html
    
    - name: Run frontend tests
      working-directory: frontend
      run: npm test -- --coverage --watchAll=false
    
    - name: Run frontend linting
      working-directory: frontend
      run: npm run lint
    
    - name: Upload coverage to Codecov
      uses: codecov/codecov-action@v3
      with:
        files: backend/coverage.out,frontend/coverage/lcov.info
        fail_ci_if_error: true

  security:
    name: Security Scan
    runs-on: ubuntu-latest
    steps:
    - name: Checkout code
      uses: actions/checkout@v4
    
    - name: Run Trivy vulnerability scanner
      uses: aquasecurity/trivy-action@master
      with:
        scan-type: 'fs'
        ignore-unfixed: true
        format: 'sarif'
        output: 'trivy-results.sarif'
    
    - name: Upload Trivy scan results to GitHub Security tab
      uses: github/codeql-action/upload-sarif@v2
      with:
        sarif_file: 'trivy-results.sarif'

  build:
    name: Build and Push
    runs-on: ubuntu-latest
    needs: [test, security]
    if: github.event_name == 'push'
    
    strategy:
      matrix:
        component: [backend, frontend]
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v4
    
    - name: Set up Docker Buildx
      uses: docker/setup-buildx-action@v3
    
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
        images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}-${{ matrix.component }}
        tags: |
          type=ref,event=branch
          type=ref,event=pr
          type=semver,pattern={{version}}
          type=semver,pattern={{major}}.{{minor}}
          type=sha,prefix={{branch}}-
    
    - name: Build and push Docker image
      uses: docker/build-push-action@v5
      with:
        context: ./${{ matrix.component }}
        push: true
        tags: ${{ steps.meta.outputs.tags }}
        labels: ${{ steps.meta.outputs.labels }}
        cache-from: type=gha
        cache-to: type=gha,mode=max
        platforms: linux/amd64,linux/arm64

  deploy-staging:
    name: Deploy to Staging
    runs-on: ubuntu-latest
    needs: build
    if: github.ref == 'refs/heads/develop'
    environment: staging
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v4
    
    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v4
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: us-west-2
    
    - name: Update kubeconfig
      run: aws eks update-kubeconfig --region us-west-2 --name staging-railway-cluster
    
    - name: Deploy to staging
      run: |
        # Update image tags in Kubernetes manifests
        sed -i "s|railway/backend:.*|${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}-backend:develop-${{ github.sha }}|" k8s/staging/backend-deployment.yaml
        sed -i "s|railway/frontend:.*|${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}-frontend:develop-${{ github.sha }}|" k8s/staging/frontend-deployment.yaml
        
        # Apply manifests
        kubectl apply -f k8s/staging/
        
        # Wait for rollout
        kubectl rollout status deployment/railway-api -n railway-staging --timeout=300s
        kubectl rollout status deployment/railway-frontend -n railway-staging --timeout=300s

  deploy-production:
    name: Deploy to Production
    runs-on: ubuntu-latest
    needs: build
    if: startsWith(github.ref, 'refs/tags/v')
    environment: production
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v4
    
    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v4
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: us-west-2
    
    - name: Update kubeconfig
      run: aws eks update-kubeconfig --region us-west-2 --name production-railway-cluster
    
    - name: Deploy to production
      run: |
        # Extract version from tag
        VERSION=${GITHUB_REF#refs/tags/v}
        
        # Update image tags in Kubernetes manifests
        sed -i "s|railway/backend:.*|${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}-backend:${VERSION}|" k8s/production/backend-deployment.yaml
        sed -i "s|railway/frontend:.*|${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}-frontend:${VERSION}|" k8s/production/frontend-deployment.yaml
        
        # Apply manifests
        kubectl apply -f k8s/production/
        
        # Wait for rollout
        kubectl rollout status deployment/railway-api -n railway-system --timeout=600s
        kubectl rollout status deployment/railway-frontend -n railway-system --timeout=600s
    
    - name: Notify Slack
      uses: 8398a7/action-slack@v3
      with:
        status: ${{ job.status }}
        channel: '#deployments'
        webhook_url: ${{ secrets.SLACK_WEBHOOK }}
      if: always()
```

## 📊 Monitoring Templates

### **Prometheus Configuration**
```yaml
# monitoring/prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    cluster: 'railway-platform'
    environment: 'production'

rule_files:
  - "alert_rules.yml"

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - alertmanager:9093

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'railway-api'
    kubernetes_sd_configs:
      - role: endpoints
        namespaces:
          names:
            - railway-system
    relabel_configs:
      - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_scrape]
        action: keep
        regex: true
      - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_path]
        action: replace
        target_label: __metrics_path__
        regex: (.+)
      - source_labels: [__address__, __meta_kubernetes_service_annotation_prometheus_io_port]
        action: replace
        regex: ([^:]+)(?::\d+)?;(\d+)
        replacement: $1:$2
        target_label: __address__
      - action: labelmap
        regex: __meta_kubernetes_service_label_(.+)
      - source_labels: [__meta_kubernetes_namespace]
        action: replace
        target_label: kubernetes_namespace
      - source_labels: [__meta_kubernetes_service_name]
        action: replace
        target_label: kubernetes_name

  - job_name: 'node-exporter'
    kubernetes_sd_configs:
      - role: node
    relabel_configs:
      - action: labelmap
        regex: __meta_kubernetes_node_label_(.+)
      - target_label: __address__
        replacement: kubernetes.default.svc:443
      - source_labels: [__meta_kubernetes_node_name]
        regex: (.+)
        target_label: __metrics_path__
        replacement: /api/v1/nodes/${1}/proxy/metrics

  - job_name: 'cadvisor'
    kubernetes_sd_configs:
      - role: node
    scheme: https
    tls_config:
      ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
    bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
    relabel_configs:
      - action: labelmap
        regex: __meta_kubernetes_node_label_(.+)
      - target_label: __address__
        replacement: kubernetes.default.svc:443
      - source_labels: [__meta_kubernetes_node_name]
        regex: (.+)
        target_label: __metrics_path__
        replacement: /api/v1/nodes/${1}/proxy/metrics/cadvisor
```

### **Alert Rules**
```yaml
# monitoring/alert_rules.yml
groups:
  - name: railway_platform_alerts
    rules:
      - alert: HighCPUUsage
        expr: (100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)) > 80
        for: 5m
        labels:
          severity: warning
          component: infrastructure
        annotations:
          summary: "High CPU usage detected on {{ $labels.instance }}"
          description: "CPU usage is above 80% for more than 5 minutes on {{ $labels.instance }}"

      - alert: HighMemoryUsage
        expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 85
        for: 5m
        labels:
          severity: warning
          component: infrastructure
        annotations:
          summary: "High memory usage detected on {{ $labels.instance }}"
          description: "Memory usage is above 85% for more than 5 minutes on {{ $labels.instance }}"

      - alert: PodCrashLooping
        expr: rate(kube_pod_container_status_restarts_total[15m]) * 60 * 15 > 0
        for: 5m
        labels:
          severity: critical
          component: kubernetes
        annotations:
          summary: "Pod {{ $labels.pod }} is crash looping"
          description: "Pod {{ $labels.pod }} in namespace {{ $labels.namespace }} is restarting frequently"

      - alert: APIHighLatency
        expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{job="railway-api"}[5m])) > 0.5
        for: 5m
        labels:
          severity: warning
          component: api
        annotations:
          summary: "High API latency detected"
          description: "95th percentile latency is above 500ms for the Railway API"

      - alert: DeploymentFailed
        expr: increase(railway_deployments_total{status="failed"}[5m]) > 0
        for: 1m
        labels:
          severity: critical
          component: deployment
        annotations:
          summary: "Deployment failure detected"
          description: "A deployment has failed in the last 5 minutes"

      - alert: DatabaseConnectionsHigh
        expr: pg_stat_activity_count > 80
        for: 5m
        labels:
          severity: warning
          component: database
        annotations:
          summary: "High number of database connections"
          description: "Database has more than 80 active connections"

      - alert: RedisMemoryUsageHigh
        expr: redis_memory_used_bytes / redis_memory_max_bytes > 0.9
        for: 5m
        labels:
          severity: warning
          component: redis
        annotations:
          summary: "High Redis memory usage"
          description: "Redis memory usage is above 90%"

      - alert: ServiceDown
        expr: up == 0
        for: 1m
        labels:
          severity: critical
          component: service
        annotations:
          summary: "Service {{ $labels.job }} is down"
          description: "Service {{ $labels.job }} has been down for more than 1 minute"
```

## 🛠 Development Scripts

### **Setup Development Environment**
```bash
#!/bin/bash
# scripts/setup-dev.sh

set -euo pipefail

echo "🚀 Setting up Railway Platform development environment..."

# Check prerequisites
check_prerequisites() {
    echo "📋 Checking prerequisites..."
    
    command -v docker >/dev/null 2>&1 || { echo "❌ Docker is required but not installed."; exit 1; }
    command -v docker-compose >/dev/null 2>&1 || { echo "❌ Docker Compose is required but not installed."; exit 1; }
    command -v go >/dev/null 2>&1 || { echo "❌ Go is required but not installed."; exit 1; }
    command -v node >/dev/null 2>&1 || { echo "❌ Node.js is required but not installed."; exit 1; }
    command -v kubectl >/dev/null 2>&1 || { echo "⚠️  kubectl not found. Install it for Kubernetes development."; }
    
    echo "✅ Prerequisites check completed"
}

# Setup environment variables
setup_env() {
    echo "🔧 Setting up environment variables..."
    
    if [[ ! -f .env.local ]]; then
        cp .env.example .env.local
        echo "📝 Created .env.local from .env.example"
        echo "Please edit .env.local with your configuration"
    fi
}

# Install dependencies
install_dependencies() {
    echo "📦 Installing dependencies..."
    
    # Backend dependencies
    echo "Installing Go dependencies..."
    cd backend && go mod download && cd ..
    
    # Frontend dependencies
    echo "Installing Node.js dependencies..."
    cd frontend && npm ci && cd ..
    
    echo "✅ Dependencies installed"
}

# Setup database
setup_database() {
    echo "🗄️ Setting up database..."
    
    # Start database services
    docker-compose up -d postgres redis
    
    # Wait for database to be ready
    echo "Waiting for database to be ready..."
    sleep 10
    
    # Run migrations
    cd backend && go run cmd/migrate/main.go up && cd ..
    
    echo "✅ Database setup completed"
}

# Setup git hooks
setup_git_hooks() {
    echo "🪝 Setting up git hooks..."
    
    mkdir -p .git/hooks
    
    cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash
# Run tests before commit
echo "Running tests..."
cd backend && go test ./... && cd ..
cd frontend && npm test -- --watchAll=false && cd ..
EOF
    
    chmod +x .git/hooks/pre-commit
    
    echo "✅ Git hooks setup completed"
}

# Main setup
main() {
    check_prerequisites
    setup_env
    install_dependencies
    setup_database
    setup_git_hooks
    
    echo ""
    echo "🎉 Development environment setup completed!"
    echo ""
    echo "Next steps:"
    echo "1. Edit .env.local with your configuration"
    echo "2. Run 'docker-compose up' to start all services"
    echo "3. Visit http://localhost:3000 for the frontend"
    echo "4. Visit http://localhost:8080 for the API"
    echo ""
}

main "$@"
```

These templates provide a solid foundation for building a Railway.com-like platform with production-ready configurations, security best practices, and comprehensive monitoring.

---

**Navigation:**
- **Previous:** [Best Practices](./best-practices.md)
- **Next:** [Troubleshooting](./troubleshooting.md)
- **Home:** [Railway Platform Creation](./README.md)