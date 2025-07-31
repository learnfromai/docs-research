# Best Practices - Railway.com Platform Development

## 🎯 Development Best Practices

This document compiles industry best practices and lessons learned for building a production-ready Platform-as-a-Service (PaaS) like Railway.com.

## 🏗️ Architecture Best Practices

### 1. Microservices Design Principles

**Service Boundaries:**
```go
// Good: Domain-driven service boundaries
type UserService struct {
    // Handles user management, authentication, profiles
}

type ProjectService struct {
    // Handles project lifecycle, settings, permissions
}

type DeploymentService struct {
    // Handles builds, deployments, rollbacks
}

type BillingService struct {
    // Handles subscriptions, usage tracking, invoicing
}

// Avoid: Overly granular services
type UserEmailService struct{} // Too specific
type UserPasswordService struct{} // Too specific
```

**API Design:**
```yaml
# RESTful API with consistent patterns
/api/v1/projects                    # GET, POST
/api/v1/projects/{id}               # GET, PUT, DELETE
/api/v1/projects/{id}/services      # GET, POST
/api/v1/projects/{id}/deployments   # GET, POST
/api/v1/deployments/{id}            # GET, DELETE
/api/v1/deployments/{id}/logs       # GET (real-time)
/api/v1/deployments/{id}/metrics    # GET

# Consistent error responses
{
  "error": {
    "code": "INVALID_PROJECT_ID",
    "message": "Project not found or access denied",
    "details": {
      "project_id": "proj_123",
      "user_id": "user_456"
    }
  }
}
```

### 2. Data Management Best Practices

**Database Per Service:**
```sql
-- User Service Database
CREATE DATABASE railway_users;
CREATE TABLE users (
    id UUID PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Project Service Database  
CREATE DATABASE railway_projects;
CREATE TABLE projects (
    id UUID PRIMARY KEY,
    owner_id UUID NOT NULL, -- Reference to user, not FK
    name VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Deployment Service Database
CREATE DATABASE railway_deployments;
CREATE TABLE deployments (
    id UUID PRIMARY KEY,
    project_id UUID NOT NULL, -- Reference to project
    status VARCHAR(50) NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);
```

**Event-Driven Communication:**
```go
// Event publishing for service communication
type EventPublisher struct {
    nats *nats.Conn
}

type ProjectCreated struct {
    ProjectID string `json:"project_id"`
    OwnerID   string `json:"owner_id"`
    Name      string `json:"name"`
    CreatedAt time.Time `json:"created_at"`
}

func (e *EventPublisher) PublishProjectCreated(project *ProjectCreated) error {
    data, _ := json.Marshal(project)
    return e.nats.Publish("project.created", data)
}

// Event handling in other services
func (b *BillingService) HandleProjectCreated(event *ProjectCreated) error {
    // Initialize billing for new project
    return b.CreateProjectBilling(event.ProjectID, event.OwnerID)
}
```

### 3. Security Architecture

**Defense in Depth:**
```yaml
# Multiple security layers
1. Network Level:
   - VPC isolation
   - Network policies
   - WAF protection

2. Application Level:
   - Input validation
   - Output encoding
   - Authentication/Authorization

3. Data Level:
   - Encryption at rest
   - Encryption in transit
   - Field-level encryption

4. Infrastructure Level:
   - Container security
   - Secrets management
   - Audit logging
```

**Zero-Trust Implementation:**
```go
// Never trust, always verify
func (s *ServiceHandler) HandleRequest(ctx context.Context, req *Request) error {
    // 1. Validate JWT token
    claims, err := s.auth.ValidateToken(req.Token)
    if err != nil {
        return ErrUnauthorized
    }
    
    // 2. Check service-level permissions
    if !s.rbac.HasPermission(claims.UserID, req.Resource, req.Action) {
        return ErrForbidden
    }
    
    // 3. Validate resource ownership
    if !s.ownership.CanAccess(claims.UserID, req.ResourceID) {
        return ErrForbidden
    }
    
    // 4. Rate limiting
    if !s.rateLimit.Allow(claims.UserID) {
        return ErrTooManyRequests
    }
    
    return s.processRequest(ctx, req)
}
```

## 🚀 Deployment Best Practices

### 1. Container Optimization

**Multi-stage Dockerfile:**
```dockerfile
# Build stage
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force

# Runtime stage
FROM node:18-alpine AS runtime
RUN addgroup -g 1001 -S nodejs && adduser -S nextjs -u 1001

WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY --chown=nextjs:nodejs . .

USER nextjs
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1

CMD ["node", "server.js"]
```

**Resource Optimization:**
```yaml
# Kubernetes resource management
resources:
  requests:
    memory: "64Mi"     # Minimum required
    cpu: "50m"         # 0.05 CPU cores
  limits:
    memory: "512Mi"    # Maximum allowed
    cpu: "500m"        # 0.5 CPU cores

# Horizontal Pod Autoscaler
spec:
  minReplicas: 1
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

### 2. Blue-Green Deployments

**Implementation Pattern:**
```yaml
# Blue deployment (current)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-blue
  labels:
    version: blue
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
      version: blue

---
# Green deployment (new)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-green
  labels:
    version: green
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
      version: green

---
# Service switch
apiVersion: v1
kind: Service
metadata:
  name: app-service
spec:
  selector:
    app: myapp
    version: blue  # Switch to green after validation
```

**Automated Rollback:**
```go
func (d *DeploymentService) DeployWithRollback(ctx context.Context, deployment *Deployment) error {
    // Deploy green version
    if err := d.deployGreen(ctx, deployment); err != nil {
        return err
    }
    
    // Health check with timeout
    if err := d.healthCheck(ctx, deployment, 5*time.Minute); err != nil {
        log.Printf("Health check failed, rolling back: %v", err)
        return d.rollback(ctx, deployment)
    }
    
    // Switch traffic
    if err := d.switchTraffic(ctx, deployment); err != nil {
        log.Printf("Traffic switch failed, rolling back: %v", err)
        return d.rollback(ctx, deployment)
    }
    
    // Clean up old version
    return d.cleanupBlue(ctx, deployment)
}
```

### 3. GitOps Implementation

**ArgoCD Application:**
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: railway-platform
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/railway/platform-config
    targetRevision: HEAD
    path: k8s-manifests
  destination:
    server: https://kubernetes.default.svc
    namespace: railway-system
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
```

## 🔍 Monitoring & Observability

### 1. Three Pillars Implementation

**Metrics Collection:**
```go
// Prometheus metrics
var (
    deploymentTotal = prometheus.NewCounterVec(
        prometheus.CounterOpts{
            Name: "railway_deployments_total",
            Help: "Total number of deployments",
        },
        []string{"project_id", "status"},
    )
    
    deploymentDuration = prometheus.NewHistogramVec(
        prometheus.HistogramOpts{
            Name: "railway_deployment_duration_seconds",
            Help: "Time taken for deployments",
            Buckets: prometheus.DefBuckets,
        },
        []string{"project_id"},
    )
)

func (d *DeploymentService) recordMetrics(projectID, status string, duration time.Duration) {
    deploymentTotal.WithLabelValues(projectID, status).Inc()
    deploymentDuration.WithLabelValues(projectID).Observe(duration.Seconds())
}
```

**Structured Logging:**
```go
// Structured JSON logging
type Logger struct {
    *zap.Logger
}

func (l *Logger) LogDeployment(ctx context.Context, deployment *Deployment, message string) {
    l.Info(message,
        zap.String("deployment_id", deployment.ID),
        zap.String("project_id", deployment.ProjectID),
        zap.String("user_id", deployment.UserID),
        zap.String("git_commit", deployment.GitCommit),
        zap.String("status", deployment.Status),
        zap.String("trace_id", getTraceID(ctx)),
    )
}
```

**Distributed Tracing:**
```go
// OpenTelemetry tracing
func (s *ProjectService) CreateProject(ctx context.Context, req *CreateProjectRequest) (*Project, error) {
    ctx, span := tracer.Start(ctx, "project.create")
    defer span.End()
    
    span.SetAttributes(
        attribute.String("user.id", req.UserID),
        attribute.String("project.name", req.Name),
    )
    
    // Validate request
    ctx, validateSpan := tracer.Start(ctx, "project.validate")
    if err := s.validateCreateRequest(req); err != nil {
        validateSpan.SetStatus(codes.Error, err.Error())
        return nil, err
    }
    validateSpan.End()
    
    // Create project
    project, err := s.repository.Create(ctx, req)
    if err != nil {
        span.SetStatus(codes.Error, err.Error())
        return nil, err
    }
    
    span.SetAttributes(attribute.String("project.id", project.ID))
    return project, nil
}
```

### 2. Alerting Strategy

**SLI/SLO Definition:**
```yaml
# Service Level Indicators & Objectives
slos:
  api_availability:
    sli: "Percentage of successful API requests"
    slo: "99.9% over 30 days"
    error_budget: "0.1% (43.2 minutes/month)"
  
  deployment_success:
    sli: "Percentage of successful deployments"
    slo: "99.5% over 7 days"
    error_budget: "0.5%"
  
  deployment_latency:
    sli: "Time from deploy trigger to service ready"
    slo: "95% under 2 minutes"
    error_budget: "5% can exceed 2 minutes"
```

**Alert Rules:**
```yaml
# Prometheus alert rules
groups:
- name: railway-platform
  rules:
  - alert: HighErrorRate
    expr: |
      (
        rate(http_requests_total{job="railway-api",code=~"5.."}[5m]) /
        rate(http_requests_total{job="railway-api"}[5m])
      ) > 0.05
    for: 2m
    labels:
      severity: critical
    annotations:
      summary: "High error rate detected"
      description: "Error rate is {{ $value | humanizePercentage }}"

  - alert: DeploymentFailures
    expr: |
      (
        rate(railway_deployments_total{status="failed"}[10m]) /
        rate(railway_deployments_total[10m])
      ) > 0.1
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "High deployment failure rate"
```

## 🧪 Testing Best Practices

### 1. Testing Pyramid

**Unit Tests (70%):**
```go
func TestProjectService_CreateProject(t *testing.T) {
    tests := []struct {
        name    string
        request *CreateProjectRequest
        setup   func(*mocks.ProjectRepository)
        want    *Project
        wantErr bool
    }{
        {
            name: "successful creation",
            request: &CreateProjectRequest{
                Name:    "test-project",
                UserID:  "user-123",
            },
            setup: func(repo *mocks.ProjectRepository) {
                repo.On("Create", mock.Anything, mock.Anything).
                    Return(&Project{ID: "proj-123"}, nil)
            },
            want: &Project{ID: "proj-123"},
        },
        {
            name: "duplicate name",
            request: &CreateProjectRequest{
                Name:   "existing-project",
                UserID: "user-123",
            },
            setup: func(repo *mocks.ProjectRepository) {
                repo.On("Create", mock.Anything, mock.Anything).
                    Return(nil, ErrProjectExists)
            },
            wantErr: true,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            repo := &mocks.ProjectRepository{}
            tt.setup(repo)
            
            service := NewProjectService(repo)
            got, err := service.CreateProject(context.Background(), tt.request)
            
            if tt.wantErr {
                assert.Error(t, err)
                return
            }
            
            assert.NoError(t, err)
            assert.Equal(t, tt.want.ID, got.ID)
            repo.AssertExpectations(t)
        })
    }
}
```

**Integration Tests (20%):**
```go
func TestDeploymentFlow(t *testing.T) {
    // Setup test environment
    testDB := setupTestDatabase(t)
    defer testDB.Close()
    
    testK8s := setupTestKubernetes(t)
    defer testK8s.Cleanup()
    
    // Create services with real dependencies
    projectSvc := NewProjectService(NewProjectRepository(testDB))
    deploySvc := NewDeploymentService(NewDeploymentRepository(testDB), testK8s)
    
    // Test end-to-end flow
    project, err := projectSvc.CreateProject(ctx, &CreateProjectRequest{
        Name:   "integration-test",
        UserID: "user-123",
    })
    require.NoError(t, err)
    
    deployment, err := deploySvc.Deploy(ctx, &DeployRequest{
        ProjectID: project.ID,
        GitURL:    "https://github.com/test/app.git",
        GitRef:    "main",
    })
    require.NoError(t, err)
    
    // Wait for deployment to complete
    err = deploySvc.WaitForCompletion(ctx, deployment.ID, 2*time.Minute)
    assert.NoError(t, err)
    
    // Verify deployment is accessible
    resp, err := http.Get(deployment.URL)
    assert.NoError(t, err)
    assert.Equal(t, 200, resp.StatusCode)
}
```

**End-to-End Tests (10%):**
```typescript
// Playwright E2E tests
test('deploy application from dashboard', async ({ page }) => {
  // Login
  await page.goto('/login');
  await page.click('text=Login with GitHub');
  
  // Create project
  await page.goto('/dashboard');
  await page.click('text=New Project');
  await page.fill('[data-testid=project-name]', 'e2e-test-project');
  await page.fill('[data-testid=git-url]', 'https://github.com/test/sample-app');
  await page.click('[data-testid=create-project]');
  
  // Wait for deployment
  await page.waitForSelector('[data-testid=deployment-status]:has-text("Deployed")', {
    timeout: 120000
  });
  
  // Verify deployment
  const deploymentUrl = await page.textContent('[data-testid=deployment-url]');
  const response = await page.request.get(deploymentUrl);
  expect(response.status()).toBe(200);
});
```

### 2. Load Testing

**K6 Performance Tests:**
```javascript
// k6 load test for deployment API
import http from 'k6/http';
import { check, sleep } from 'k6';

export let options = {
  stages: [
    { duration: '2m', target: 10 },   // Ramp up
    { duration: '5m', target: 50 },   // Stay at 50 users
    { duration: '2m', target: 0 },    // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<2000'], // 95% of requests under 2s
    http_req_failed: ['rate<0.05'],    // Error rate under 5%
  },
};

export default function() {
  const payload = JSON.stringify({
    project_id: 'proj-123',
    git_url: 'https://github.com/test/app.git',
    git_ref: 'main',
  });

  const params = {
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ' + __ENV.API_TOKEN,
    },
  };

  const response = http.post('https://api.railway.app/v1/deployments', payload, params);
  
  check(response, {
    'status is 201': (r) => r.status === 201,
    'response time < 2000ms': (r) => r.timings.duration < 2000,
  });

  sleep(1);
}
```

## 🔐 Security Best Practices

### 1. Secure Development Lifecycle

**Security Gates:**
```yaml
# GitHub Actions security pipeline
name: Security Pipeline
on: [push, pull_request]

jobs:
  security-scan:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    
    # Static Application Security Testing (SAST)
    - name: Run CodeQL
      uses: github/codeql-action/analyze@v2
      with:
        languages: go, javascript
    
    # Dependency scanning
    - name: Run Snyk
      uses: snyk/actions/node@master
      with:
        args: --severity-threshold=high
    
    # Container scanning
    - name: Run Trivy
      uses: aquasecurity/trivy-action@master
      with:
        image-ref: ${{ env.IMAGE_NAME }}
        format: sarif
        output: trivy-results.sarif
    
    # Secret scanning
    - name: Run GitLeaks
      uses: zricethezav/gitleaks-action@master
```

### 2. Runtime Security

**Pod Security Standards:**
```yaml
apiVersion: v1
kind: Pod
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1001
    fsGroup: 1001
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop:
        - ALL
    volumeMounts:
    - name: tmp
      mountPath: /tmp
  volumes:
  - name: tmp
    emptyDir: {}
```

## 📊 Performance Optimization

### 1. Database Optimization

**Connection Pooling:**
```go
// Optimized database configuration
func NewDatabasePool(config *DatabaseConfig) (*sql.DB, error) {
    db, err := sql.Open("postgres", config.DSN)
    if err != nil {
        return nil, err
    }
    
    // Connection pool settings
    db.SetMaxOpenConns(25)                 // Maximum connections
    db.SetMaxIdleConns(5)                  // Idle connections
    db.SetConnMaxLifetime(5 * time.Minute) // Connection lifetime
    db.SetConnMaxIdleTime(1 * time.Minute) // Idle timeout
    
    return db, nil
}
```

**Query Optimization:**
```sql
-- Efficient pagination
SELECT id, name, created_at
FROM projects 
WHERE user_id = $1 
  AND created_at < $2  -- Cursor-based pagination
ORDER BY created_at DESC 
LIMIT 20;

-- Proper indexing
CREATE INDEX CONCURRENTLY idx_projects_user_created 
ON projects (user_id, created_at DESC);

-- Materialized views for complex queries
CREATE MATERIALIZED VIEW user_project_stats AS
SELECT 
    user_id,
    COUNT(*) as project_count,
    COUNT(CASE WHEN status = 'active' THEN 1 END) as active_projects
FROM projects 
GROUP BY user_id;
```

### 2. Caching Strategy

**Multi-Layer Caching:**
```go
type CacheService struct {
    redis  *redis.Client
    memory *bigcache.BigCache
}

func (c *CacheService) Get(ctx context.Context, key string) ([]byte, error) {
    // L1: Memory cache (fastest)
    if data, err := c.memory.Get(key); err == nil {
        return data, nil
    }
    
    // L2: Redis cache
    data, err := c.redis.Get(ctx, key).Bytes()
    if err != nil {
        return nil, err
    }
    
    // Store in memory cache for next time
    c.memory.Set(key, data)
    return data, nil
}

func (c *CacheService) Set(ctx context.Context, key string, data []byte, ttl time.Duration) error {
    // Store in both layers
    c.memory.Set(key, data)
    return c.redis.Set(ctx, key, data, ttl).Err()
}
```

---

## 🔗 Navigation

← [Back to Business Model Analysis](./business-model-analysis.md) | [Next: README →](./README.md)

## 📚 Best Practices References

1. [Kubernetes Best Practices](https://kubernetes.io/docs/concepts/configuration/overview/)
2. [Microservices Patterns](https://microservices.io/patterns/)
3. [12-Factor App Methodology](https://12factor.net/)
4. [Google SRE Practices](https://sre.google/sre-book/table-of-contents/)
5. [OWASP Security Guidelines](https://owasp.org/www-project-top-ten/)
6. [Clean Code Principles](https://clean-code-developer.com/)
7. [Database Performance Tuning](https://use-the-index-luke.com/)
8. [Container Security Best Practices](https://kubernetes.io/docs/concepts/security/)