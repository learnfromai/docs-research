# Best Practices: Railway.com Platform Creation

## 🎯 **Development Best Practices**

Building a Railway.com-like platform requires following industry best practices across development, security, operations, and business domains. This document consolidates proven patterns and recommendations.

## 🏗️ **Architecture Best Practices**

### **Microservices Design Principles**
```typescript
// Microservices best practices implementation
interface MicroservicesPattern {
  service_boundaries: {
    principle: 'Domain-driven design with clear business boundaries';
    size: 'Small enough to be maintained by a single team (2-pizza rule)';
    coupling: 'Loose coupling between services, high cohesion within services';
    data: 'Each service owns its data and database schema';
  };
  
  communication: {
    sync: 'HTTP/gRPC for request-response patterns';
    async: 'Message queues for event-driven communication';
    discovery: 'Service mesh or API gateway for service discovery';
    fallback: 'Circuit breaker pattern for failure resilience';
  };
  
  deployment: {
    independence: 'Each service can be deployed independently';
    versioning: 'Semantic versioning with backward compatibility';
    rollback: 'Blue-green or canary deployment strategies';
    monitoring: 'Distributed tracing and centralized logging';
  };
}

// Example: Well-designed microservice structure
export class ProjectService {
  constructor(
    private readonly projectRepository: ProjectRepository,
    private readonly eventBus: EventBus,
    private readonly logger: Logger
  ) {}
  
  async createProject(userId: string, projectData: CreateProjectDTO): Promise<Project> {
    try {
      // Validate input
      const validatedData = ProjectSchema.parse(projectData);
      
      // Business logic
      const project = await this.projectRepository.create({
        ...validatedData,
        ownerId: userId,
        createdAt: new Date()
      });
      
      // Publish event for other services
      await this.eventBus.publish('project.created', {
        projectId: project.id,
        ownerId: userId,
        timestamp: new Date()
      });
      
      this.logger.info('Project created', { projectId: project.id, userId });
      
      return project;
      
    } catch (error) {
      this.logger.error('Failed to create project', { error, userId, projectData });
      throw new ProjectCreationError('Failed to create project', error);
    }
  }
}
```

### **Database Design Best Practices**
```sql
-- Database design patterns for PaaS platforms

-- 1. Multi-tenant architecture with proper isolation
CREATE SCHEMA tenant_common;
CREATE SCHEMA tenant_1;
CREATE SCHEMA tenant_2;

-- 2. Proper indexing strategy
CREATE INDEX CONCURRENTLY idx_projects_owner_id ON projects(owner_id);
CREATE INDEX CONCURRENTLY idx_deployments_project_env ON deployments(project_id, environment_id);
CREATE INDEX CONCURRENTLY idx_deployments_status_created ON deployments(status, created_at);

-- 3. Audit trail for compliance
CREATE TABLE audit_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    table_name VARCHAR(100) NOT NULL,
    operation VARCHAR(10) NOT NULL, -- INSERT, UPDATE, DELETE
    old_values JSONB,
    new_values JSONB,
    user_id UUID,
    timestamp TIMESTAMPTZ DEFAULT NOW(),
    ip_address INET,
    user_agent TEXT
);

-- 4. Soft deletes for data recovery
ALTER TABLE projects ADD COLUMN deleted_at TIMESTAMPTZ NULL;
CREATE INDEX idx_projects_not_deleted ON projects(id) WHERE deleted_at IS NULL;

-- 5. Time-series data for metrics
CREATE TABLE metrics (
    timestamp TIMESTAMPTZ NOT NULL,
    service_name VARCHAR(100) NOT NULL,
    metric_name VARCHAR(100) NOT NULL,
    value DECIMAL NOT NULL,
    tags JSONB DEFAULT '{}',
    PRIMARY KEY (timestamp, service_name, metric_name)
);

-- Partition by time for better performance
SELECT create_hypertable('metrics', 'timestamp');
```

### **API Design Best Practices**
```typescript
// RESTful API design patterns
interface APIDesignPrinciples {
  rest: {
    resources: 'Use nouns for resources, not verbs';
    methods: 'HTTP methods represent actions (GET, POST, PUT, DELETE)';
    status_codes: 'Proper HTTP status codes for all responses';
    versioning: 'API versioning in URL path (/api/v1/) or headers';
  };
  
  graphql: {
    schema_first: 'Design schema before implementation';
    single_endpoint: 'One endpoint for all queries and mutations';
    type_safety: 'Strong typing with schema validation';
    caching: 'Implement query result caching';
  };
  
  security: {
    authentication: 'JWT tokens with proper expiration';
    authorization: 'Role-based access control on all endpoints';
    rate_limiting: 'Implement rate limiting per user/IP';
    input_validation: 'Validate all inputs with schema validation';
  };
}

// Example: Well-designed API endpoints
export class ProjectController {
  // GET /api/v1/projects?page=1&limit=20&sort=name
  async getProjects(req: AuthenticatedRequest, res: Response) {
    try {
      const query = ProjectQuerySchema.parse(req.query);
      const userId = req.user.id;
      
      const result = await this.projectService.getUserProjects(userId, query);
      
      res.status(200).json({
        data: result.projects,
        pagination: {
          page: query.page,
          limit: query.limit,
          total: result.total,
          hasNext: result.hasNext
        },
        meta: {
          timestamp: new Date().toISOString(),
          version: 'v1'
        }
      });
      
    } catch (error) {
      this.handleError(error, res);
    }
  }
  
  // POST /api/v1/projects
  async createProject(req: AuthenticatedRequest, res: Response) {
    try {
      const projectData = CreateProjectSchema.parse(req.body);
      const userId = req.user.id;
      
      const project = await this.projectService.createProject(userId, projectData);
      
      res.status(201).json({
        data: project,
        meta: {
          message: 'Project created successfully',
          timestamp: new Date().toISOString()
        }
      });
      
    } catch (error) {
      this.handleError(error, res);
    }
  }
  
  private handleError(error: Error, res: Response) {
    if (error instanceof ValidationError) {
      res.status(400).json({
        error: 'Validation failed',
        details: error.details,
        timestamp: new Date().toISOString()
      });
    } else if (error instanceof NotFoundError) {
      res.status(404).json({
        error: 'Resource not found',
        timestamp: new Date().toISOString()
      });
    } else {
      // Log internal errors
      this.logger.error('Internal server error', { error });
      
      res.status(500).json({
        error: 'Internal server error',
        timestamp: new Date().toISOString()
      });
    }
  }
}
```

## 🔐 **Security Best Practices**

### **Authentication & Authorization**
```typescript
// Security implementation patterns
interface SecurityPractices {
  authentication: {
    mfa: 'Multi-factor authentication for all admin accounts';
    jwt: 'Short-lived access tokens with refresh token rotation';
    oauth: 'OAuth 2.0 with PKCE for client applications';
    session: 'Secure session management with proper timeout';
  };
  
  authorization: {
    rbac: 'Role-based access control with principle of least privilege';
    abac: 'Attribute-based access control for fine-grained permissions';
    resource: 'Resource-level permissions for multi-tenant isolation';
    audit: 'Complete audit trail for all permission grants/denials';
  };
  
  data_protection: {
    encryption: 'AES-256 encryption for data at rest';
    tls: 'TLS 1.3 for all data in transit';
    secrets: 'Proper secrets management with rotation';
    pii: 'Special handling for personally identifiable information';
  };
}

// Example: Secure authentication middleware
export function createAuthMiddleware(options: AuthOptions) {
  return async (req: Request, res: Response, next: NextFunction) => {
    try {
      const token = extractToken(req);
      
      if (!token) {
        return res.status(401).json({ error: 'Authentication required' });
      }
      
      // Verify JWT token
      const payload = jwt.verify(token, process.env.JWT_SECRET!) as JWTPayload;
      
      // Check token blacklist
      const isBlacklisted = await tokenBlacklist.isBlacklisted(token);
      if (isBlacklisted) {
        return res.status(401).json({ error: 'Token has been revoked' });
      }
      
      // Get user details
      const user = await userService.getById(payload.userId);
      if (!user || !user.isActive) {
        return res.status(401).json({ error: 'User not found or inactive' });
      }
      
      // Check if password has been changed since token issue
      if (user.passwordChangedAt > payload.iat) {
        return res.status(401).json({ error: 'Token expired due to password change' });
      }
      
      // Add user to request context
      req.user = user;
      
      // Log authentication for audit
      await auditLog({
        action: 'authenticated',
        userId: user.id,
        ip: req.ip,
        userAgent: req.get('User-Agent'),
        endpoint: req.path
      });
      
      next();
      
    } catch (error) {
      // Log failed authentication attempt
      await auditLog({
        action: 'authentication_failed',
        ip: req.ip,
        userAgent: req.get('User-Agent'),
        endpoint: req.path,
        error: error.message
      });
      
      res.status(401).json({ error: 'Invalid authentication token' });
    }
  };
}
```

### **Input Validation & Sanitization**
```typescript
// Comprehensive input validation
import { z } from 'zod';
import DOMPurify from 'isomorphic-dompurify';

// Schema definitions with validation rules
const CreateProjectSchema = z.object({
  name: z.string()
    .min(1, 'Name is required')
    .max(100, 'Name must be less than 100 characters')
    .regex(/^[a-zA-Z0-9\s\-_]+$/, 'Name contains invalid characters'),
  
  description: z.string()
    .max(500, 'Description must be less than 500 characters')
    .optional()
    .transform((val) => val ? DOMPurify.sanitize(val) : val),
  
  repositoryUrl: z.string()
    .url('Invalid repository URL')
    .regex(/^https:\/\/(github|gitlab|bitbucket)\./, 'Only GitHub, GitLab, and Bitbucket URLs are allowed')
    .optional(),
  
  isPrivate: z.boolean().default(false),
  
  environmentVariables: z.record(
    z.string().regex(/^[A-Z_][A-Z0-9_]*$/, 'Invalid environment variable name'),
    z.string().max(1000, 'Environment variable value too long')
  ).optional()
});

// SQL injection prevention
export class DatabaseService {
  async findProjectsByOwner(ownerId: string, filters: ProjectFilters) {
    // Use parameterized queries
    const query = `
      SELECT * FROM projects 
      WHERE owner_id = $1 
      AND deleted_at IS NULL
      AND ($2::text IS NULL OR name ILIKE $2)
      ORDER BY created_at DESC
      LIMIT $3 OFFSET $4
    `;
    
    const params = [
      ownerId,
      filters.search ? `%${filters.search}%` : null,
      filters.limit || 20,
      (filters.page - 1) * (filters.limit || 20)
    ];
    
    return this.db.query(query, params);
  }
}
```

## 🚀 **DevOps Best Practices**

### **CI/CD Pipeline Design**
```yaml
# Comprehensive CI/CD pipeline
name: Production Deployment Pipeline

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

env:
  NODE_VERSION: '20'
  REGISTRY: ${{ secrets.ECR_REGISTRY }}
  IMAGE_NAME: railway-platform

jobs:
  test:
    name: Test Suite
    runs-on: ubuntu-latest
    
    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_PASSWORD: postgres
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
      
      redis:
        image: redis:7
        options: >-
          --health-cmd "redis-cli ping"
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: 'npm'
      
      - name: Install dependencies
        run: npm ci
      
      - name: Run linting
        run: |
          npm run lint
          npm run type-check
      
      - name: Run unit tests
        run: npm run test:unit -- --coverage
      
      - name: Run integration tests
        run: npm run test:integration
        env:
          DATABASE_URL: postgresql://postgres:postgres@localhost:5432/test
          REDIS_URL: redis://localhost:6379
      
      - name: Run E2E tests
        run: npm run test:e2e
      
      - name: Upload coverage reports
        uses: codecov/codecov-action@v3
        with:
          token: ${{ secrets.CODECOV_TOKEN }}

  security:
    name: Security Scan
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Run Snyk security scan
        uses: snyk/actions/node@master
        env:
          SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
        with:
          args: --severity-threshold=medium
      
      - name: Run CodeQL analysis
        uses: github/codeql-action/analyze@v3
        with:
          languages: typescript, javascript
      
      - name: Run Semgrep scan
        uses: returntocorp/semgrep-action@v1
        with:
          config: auto

  build:
    name: Build and Push
    runs-on: ubuntu-latest
    needs: [test, security]
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1
      
      - name: Login to Amazon ECR
        uses: aws-actions/amazon-ecr-login@v2
      
      - name: Build Docker image
        run: |
          docker build \
            --build-arg NODE_VERSION=${{ env.NODE_VERSION }} \
            --build-arg BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ') \
            --build-arg VCS_REF=${{ github.sha }} \
            -t ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }} \
            -t ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:latest \
            .
      
      - name: Scan Docker image
        run: |
          docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
            aquasec/trivy image \
            --exit-code 1 \
            --severity HIGH,CRITICAL \
            ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}
      
      - name: Push Docker image
        run: |
          docker push ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}
          docker push ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:latest

  deploy-staging:
    name: Deploy to Staging
    runs-on: ubuntu-latest
    needs: build
    if: github.ref == 'refs/heads/develop'
    environment: staging
    
    steps:
      - name: Deploy to staging
        run: |
          aws eks update-kubeconfig --name railway-staging-cluster
          kubectl set image deployment/railway-api \
            api=${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }} \
            -n staging
          kubectl rollout status deployment/railway-api -n staging --timeout=300s
      
      - name: Run smoke tests
        run: |
          curl -f https://staging-api.railway.com/health
          npm run test:smoke -- --env=staging

  deploy-production:
    name: Deploy to Production
    runs-on: ubuntu-latest
    needs: build
    if: github.ref == 'refs/heads/main'
    environment: production
    
    steps:
      - name: Blue-Green Deployment
        run: |
          aws eks update-kubeconfig --name railway-production-cluster
          
          # Deploy to green environment
          kubectl set image deployment/railway-api-green \
            api=${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }} \
            -n production
          kubectl rollout status deployment/railway-api-green -n production --timeout=300s
          
          # Health check green environment
          kubectl run health-check --rm -i --restart=Never \
            --image=curlimages/curl -- \
            curl -f http://railway-api-green:3000/health
          
          # Switch traffic to green
          kubectl patch service railway-api \
            -p '{"spec":{"selector":{"version":"green"}}}' \
            -n production
          
          # Wait and monitor
          sleep 60
          
          # If successful, update blue environment for next deployment
          kubectl set image deployment/railway-api-blue \
            api=${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }} \
            -n production
```

### **Infrastructure as Code**
```hcl
# Terraform best practices for AWS infrastructure
terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  backend "s3" {
    bucket         = "railway-terraform-state"
    key            = "production/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}

# Local values for reusability
locals {
  name_prefix = "railway-${var.environment}"
  
  common_tags = {
    Environment = var.environment
    Project     = "railway-platform"
    ManagedBy   = "terraform"
    Owner       = "platform-team"
    CostCenter  = "engineering"
  }
  
  # Network configuration
  vpc_cidr = "10.0.0.0/16"
  availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

# VPC with proper subnet design
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"
  
  name = "${local.name_prefix}-vpc"
  cidr = local.vpc_cidr
  
  azs             = local.availability_zones
  private_subnets = [for i, az in local.availability_zones : cidrsubnet(local.vpc_cidr, 8, i + 10)]
  public_subnets  = [for i, az in local.availability_zones : cidrsubnet(local.vpc_cidr, 8, i)]
  database_subnets = [for i, az in local.availability_zones : cidrsubnet(local.vpc_cidr, 8, i + 20)]
  
  enable_nat_gateway = true
  enable_vpn_gateway = false
  single_nat_gateway = var.environment != "production"
  
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = local.common_tags
}

# EKS cluster with proper security configuration
module "eks" {
  source = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"
  
  cluster_name    = "${local.name_prefix}-cluster"
  cluster_version = "1.28"
  
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets
  
  # Cluster endpoint configuration
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true
  cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"]
  
  # Cluster logging
  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  
  # IRSA for pods to assume AWS roles
  enable_irsa = true
  
  # Node groups
  eks_managed_node_groups = {
    general = {
      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"
      
      min_size     = 2
      max_size     = 10
      desired_size = 3
      
      labels = {
        role = "general"
      }
      
      taints = []
    }
    
    compute = {
      instance_types = ["c5.large"]
      capacity_type  = "SPOT"
      
      min_size     = 0
      max_size     = 20
      desired_size = 2
      
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

# RDS database with proper security and backup
resource "aws_db_instance" "main" {
  identifier = "${local.name_prefix}-database"
  
  engine         = "postgres"
  engine_version = "15.4"
  instance_class = var.db_instance_class
  
  allocated_storage     = 100
  max_allocated_storage = 1000
  storage_encrypted     = true
  storage_type          = "gp3"
  
  db_name  = "railway"
  username = "railway_admin"
  password = random_password.db_password.result
  
  vpc_security_group_ids = [aws_security_group.database.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name
  
  # Backup configuration
  backup_retention_period = var.environment == "production" ? 7 : 3
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"
  
  # Performance and monitoring
  performance_insights_enabled = true
  monitoring_interval         = 60
  monitoring_role_arn        = aws_iam_role.rds_monitoring.arn
  
  # Deletion protection
  deletion_protection = var.environment == "production"
  skip_final_snapshot = var.environment != "production"
  
  tags = local.common_tags
}

# Outputs for other modules
output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "database_endpoint" {
  description = "RDS database endpoint"
  value       = aws_db_instance.main.endpoint
  sensitive   = true
}
```

## 📊 **Monitoring & Observability**

### **Comprehensive Monitoring Strategy**
```typescript
// Monitoring and alerting best practices
interface MonitoringStrategy {
  metrics: {
    business: ['User signups', 'Deployments per day', 'Revenue metrics'];
    technical: ['Response time', 'Error rate', 'Throughput', 'Resource usage'];
    infrastructure: ['CPU/Memory usage', 'Disk space', 'Network metrics'];
    security: ['Failed login attempts', 'Suspicious activities', 'Certificate expiry'];
  };
  
  alerting: {
    principles: ['Actionable alerts only', 'Proper escalation', 'Context-rich notifications'];
    channels: ['PagerDuty for critical', 'Slack for warnings', 'Email for info'];
    slos: ['99.9% uptime', '<2s response time', '<1% error rate'];
  };
  
  observability: {
    logs: 'Structured JSON logs with correlation IDs';
    metrics: 'Prometheus with Grafana dashboards';
    tracing: 'OpenTelemetry with Jaeger for distributed tracing';
    profiling: 'Continuous profiling for performance optimization';
  };
}

// Custom metrics collection
export class MetricsCollector {
  private prometheus = require('prom-client');
  
  // Business metrics
  private deploymentCounter = new this.prometheus.Counter({
    name: 'deployments_total',
    help: 'Total number of deployments',
    labelNames: ['project_id', 'environment', 'status']
  });
  
  private userSignupCounter = new this.prometheus.Counter({
    name: 'user_signups_total',
    help: 'Total number of user signups',
    labelNames: ['source', 'plan']
  });
  
  // Technical metrics
  private responseTimeHistogram = new this.prometheus.Histogram({
    name: 'http_request_duration_seconds',
    help: 'HTTP request duration in seconds',
    labelNames: ['method', 'route', 'status_code'],
    buckets: [0.01, 0.05, 0.1, 0.5, 1, 2, 5]
  });
  
  private errorCounter = new this.prometheus.Counter({
    name: 'errors_total',
    help: 'Total number of errors',
    labelNames: ['service', 'error_type', 'severity']
  });
  
  // Infrastructure metrics
  private databaseConnectionsGauge = new this.prometheus.Gauge({
    name: 'database_connections_active',
    help: 'Number of active database connections',
    labelNames: ['database', 'type']
  });
  
  recordDeployment(projectId: string, environment: string, status: string) {
    this.deploymentCounter.inc({ project_id: projectId, environment, status });
  }
  
  recordResponseTime(method: string, route: string, statusCode: number, duration: number) {
    this.responseTimeHistogram
      .labels(method, route, statusCode.toString())
      .observe(duration);
  }
  
  recordError(service: string, errorType: string, severity: string) {
    this.errorCounter.inc({ service, error_type: errorType, severity });
  }
}
```

### **Logging Best Practices**
```typescript
// Structured logging implementation
import winston from 'winston';

interface LogContext {
  correlationId: string;
  userId?: string;
  projectId?: string;
  deploymentId?: string;
  sessionId?: string;
  requestId?: string;
}

export class Logger {
  private winston: winston.Logger;
  
  constructor(service: string) {
    this.winston = winston.createLogger({
      level: process.env.LOG_LEVEL || 'info',
      format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.errors({ stack: true }),
        winston.format.json(),
        winston.format.printf(({ timestamp, level, message, service: svc, ...meta }) => {
          return JSON.stringify({
            timestamp,
            level,
            service: svc || service,
            message,
            ...meta
          });
        })
      ),
      defaultMeta: { service },
      transports: [
        new winston.transports.Console(),
        new winston.transports.File({ filename: 'error.log', level: 'error' }),
        new winston.transports.File({ filename: 'combined.log' })
      ]
    });
  }
  
  info(message: string, context?: LogContext & Record<string, any>) {
    this.winston.info(message, context);
  }
  
  error(message: string, error?: Error, context?: LogContext & Record<string, any>) {
    this.winston.error(message, {
      error: error ? {
        message: error.message,
        stack: error.stack,
        name: error.name
      } : undefined,
      ...context
    });
  }
  
  warn(message: string, context?: LogContext & Record<string, any>) {
    this.winston.warn(message, context);
  }
  
  debug(message: string, context?: LogContext & Record<string, any>) {
    this.winston.debug(message, context);
  }
}

// Request logging middleware
export function requestLoggingMiddleware(logger: Logger) {
  return (req: Request, res: Response, next: NextFunction) => {
    const startTime = Date.now();
    const correlationId = req.headers['x-correlation-id'] as string || 
                         req.headers['x-request-id'] as string || 
                         generateId();
    
    // Add correlation ID to request
    req.correlationId = correlationId;
    res.setHeader('X-Correlation-ID', correlationId);
    
    // Log request
    logger.info('Request started', {
      correlationId,
      method: req.method,
      url: req.url,
      userAgent: req.get('User-Agent'),
      ip: req.ip,
      userId: req.user?.id
    });
    
    // Log response
    res.on('finish', () => {
      const duration = Date.now() - startTime;
      
      logger.info('Request completed', {
        correlationId,
        method: req.method,
        url: req.url,
        statusCode: res.statusCode,
        duration,
        userId: req.user?.id
      });
    });
    
    next();
  };
}
```

## 🎯 **Performance Optimization**

### **Application Performance**
```typescript
// Performance optimization patterns
interface PerformanceOptimization {
  caching: {
    levels: ['CDN edge cache', 'Application cache', 'Database query cache'];
    strategies: ['Cache-aside', 'Write-through', 'Write-behind'];
    invalidation: ['TTL-based', 'Event-driven', 'Manual'];
  };
  
  database: {
    indexing: 'Proper indexing on query patterns';
    pooling: 'Connection pooling with optimal pool size';
    partitioning: 'Table partitioning for large datasets';
    read_replicas: 'Read replicas for read-heavy workloads';
  };
  
  api: {
    pagination: 'Cursor-based pagination for large datasets';
    compression: 'Response compression (gzip/brotli)';
    rate_limiting: 'Intelligent rate limiting';
    async_processing: 'Async processing for heavy operations';
  };
}

// Caching implementation
export class CacheService {
  constructor(
    private readonly redis: Redis,
    private readonly logger: Logger
  ) {}
  
  async get<T>(key: string, fallback?: () => Promise<T>): Promise<T | null> {
    try {
      const cached = await this.redis.get(key);
      
      if (cached) {
        this.logger.debug('Cache hit', { key });
        return JSON.parse(cached);
      }
      
      this.logger.debug('Cache miss', { key });
      
      if (fallback) {
        const value = await fallback();
        await this.set(key, value, 300); // 5 minutes default TTL
        return value;
      }
      
      return null;
      
    } catch (error) {
      this.logger.error('Cache get error', error, { key });
      
      // Fallback to original function if cache fails
      if (fallback) {
        return await fallback();
      }
      
      return null;
    }
  }
  
  async set(key: string, value: any, ttl: number = 300): Promise<void> {
    try {
      await this.redis.setex(key, ttl, JSON.stringify(value));
      this.logger.debug('Cache set', { key, ttl });
      
    } catch (error) {
      this.logger.error('Cache set error', error, { key });
    }
  }
  
  async invalidate(pattern: string): Promise<void> {
    try {
      const keys = await this.redis.keys(pattern);
      
      if (keys.length > 0) {
        await this.redis.del(...keys);
        this.logger.info('Cache invalidated', { pattern, count: keys.length });
      }
      
    } catch (error) {
      this.logger.error('Cache invalidation error', error, { pattern });
    }
  }
}

// Database optimization
export class OptimizedRepository {
  async findProjectsWithPagination(
    userId: string,
    options: PaginationOptions
  ): Promise<PaginatedResult<Project>> {
    // Use cursor-based pagination for better performance
    const query = `
      SELECT p.*, COUNT(*) OVER() as total_count
      FROM projects p
      WHERE p.owner_id = $1
      AND p.deleted_at IS NULL
      AND ($2::uuid IS NULL OR p.id > $2)
      ORDER BY p.id
      LIMIT $3
    `;
    
    const result = await this.db.query(query, [
      userId,
      options.cursor,
      options.limit + 1 // Get one extra to check if there's a next page
    ]);
    
    const hasNextPage = result.rows.length > options.limit;
    const projects = hasNextPage ? result.rows.slice(0, -1) : result.rows;
    
    return {
      data: projects,
      hasNextPage,
      nextCursor: hasNextPage ? projects[projects.length - 1].id : null,
      totalCount: projects[0]?.total_count || 0
    };
  }
}
```

---

### 🔄 Navigation

**Previous:** [Comparison Analysis](./comparison-analysis.md) | **Next:** [Cost Analysis](./cost-analysis.md)

---

## 📖 References

1. [Twelve-Factor App Methodology](https://12factor.net/)
2. [Google Site Reliability Engineering](https://sre.google/books/)
3. [Building Microservices by Sam Newman](https://samnewman.io/books/building_microservices/)
4. [Designing Data-Intensive Applications](https://dataintensive.net/)
5. [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
6. [Kubernetes Best Practices](https://kubernetes.io/docs/concepts/best-practices/)
7. [OWASP Security Best Practices](https://owasp.org/www-project-top-ten/)
8. [Clean Architecture by Robert Martin](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)

*This best practices document provides comprehensive guidelines for building a production-ready Railway.com-like platform following industry standards.*