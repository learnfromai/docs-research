# Best Practices for Railway.com-like Platform Development

## 🎯 Production-Ready Development Patterns

Building a robust Platform-as-a-Service requires adherence to industry best practices across all layers. This document consolidates proven patterns and practices for developing, deploying, and operating a Railway.com-like platform.

## 🏗 Architecture Best Practices

### **Microservices Design Principles**

#### **Single Responsibility Principle**
```go
// Good: Each service has a single, well-defined responsibility
type UserService struct {
    repo UserRepository
    validator *validator.Validate
    events EventPublisher
}

// User service only handles user-related operations
func (s *UserService) CreateUser(ctx context.Context, req CreateUserRequest) (*User, error) {
    // Validate input
    if err := s.validator.Struct(req); err != nil {
        return nil, ErrInvalidInput
    }
    
    // Create user
    user, err := s.repo.Create(ctx, &User{
        Email: req.Email,
        Name:  req.Name,
    })
    if err != nil {
        return nil, fmt.Errorf("failed to create user: %w", err)
    }
    
    // Publish event for other services
    s.events.Publish(UserCreatedEvent{
        UserID: user.ID,
        Email:  user.Email,
        Timestamp: time.Now(),
    })
    
    return user, nil
}

// Bad: Service doing too many things
type MonolithService struct {
    // Multiple responsibilities mixed together
    userRepo UserRepository
    projectRepo ProjectRepository
    deploymentManager DeploymentManager
    billingCalculator BillingCalculator
    emailSender EmailSender
}
```

#### **API Gateway Pattern**
```go
// API Gateway with proper routing and middleware
package gateway

import (
    "context"
    "net/http"
    "time"
    
    "github.com/gin-gonic/gin"
    "go.opentelemetry.io/contrib/instrumentation/github.com/gin-gonic/gin/otelgin"
)

type Gateway struct {
    userService       UserServiceClient
    projectService    ProjectServiceClient
    deploymentService DeploymentServiceClient
    rateLimiter      RateLimiter
    circuitBreaker   CircuitBreaker
}

func (g *Gateway) setupRoutes() *gin.Engine {
    router := gin.New()
    
    // Global middleware
    router.Use(gin.Recovery())
    router.Use(otelgin.Middleware("railway-gateway"))
    router.Use(g.corsMiddleware())
    router.Use(g.loggingMiddleware())
    router.Use(g.rateLimitMiddleware())
    
    // API versioning
    v1 := router.Group("/api/v1")
    {
        // Authentication routes (no auth required)
        auth := v1.Group("/auth")
        {
            auth.POST("/login", g.handleLogin)
            auth.POST("/register", g.handleRegister)
            auth.POST("/refresh", g.handleRefreshToken)
        }
        
        // Protected routes
        protected := v1.Group("")
        protected.Use(g.authMiddleware())
        {
            // User management
            users := protected.Group("/users")
            {
                users.GET("/me", g.handleGetCurrentUser)
                users.PUT("/me", g.handleUpdateCurrentUser)
            }
            
            // Project management
            projects := protected.Group("/projects")
            {
                projects.GET("", g.handleListProjects)
                projects.POST("", g.handleCreateProject)
                projects.GET("/:id", g.handleGetProject)
                projects.PUT("/:id", g.handleUpdateProject)
                projects.DELETE("/:id", g.handleDeleteProject)
            }
            
            // Deployment management
            deployments := protected.Group("/deployments")
            {
                deployments.POST("", g.handleCreateDeployment)
                deployments.GET("/:id", g.handleGetDeployment)
                deployments.GET("/:id/logs", g.handleGetDeploymentLogs)
                deployments.POST("/:id/rollback", g.handleRollbackDeployment)
            }
        }
    }
    
    return router
}

// Circuit breaker pattern for external service calls
func (g *Gateway) handleCreateProject(c *gin.Context) {
    var req CreateProjectRequest
    if err := c.ShouldBindJSON(&req); err != nil {
        c.JSON(http.StatusBadRequest, ErrorResponse{Error: err.Error()})
        return
    }
    
    // Use circuit breaker for external service call
    result, err := g.circuitBreaker.Execute(func() (interface{}, error) {
        ctx, cancel := context.WithTimeout(c.Request.Context(), 10*time.Second)
        defer cancel()
        
        return g.projectService.CreateProject(ctx, &req)
    })
    
    if err != nil {
        if errors.Is(err, ErrCircuitBreakerOpen) {
            c.JSON(http.StatusServiceUnavailable, ErrorResponse{
                Error: "Service temporarily unavailable",
            })
            return
        }
        
        c.JSON(http.StatusInternalServerError, ErrorResponse{
            Error: "Failed to create project",
        })
        return
    }
    
    project := result.(*Project)
    c.JSON(http.StatusCreated, project)
}
```

### **Database Design Best Practices**

#### **Multi-Tenant Data Isolation**
```sql
-- Row Level Security (RLS) for multi-tenant isolation
CREATE POLICY tenant_isolation ON projects
    FOR ALL TO application_role
    USING (tenant_id = current_setting('app.current_tenant')::UUID);

-- Proper indexing strategy
CREATE INDEX CONCURRENTLY idx_projects_tenant_id ON projects(tenant_id);
CREATE INDEX CONCURRENTLY idx_projects_user_id_tenant_id ON projects(user_id, tenant_id);
CREATE INDEX CONCURRENTLY idx_deployments_project_id_status ON deployments(project_id, status);
CREATE INDEX CONCURRENTLY idx_deployments_created_at_desc ON deployments(created_at DESC);

-- Partitioning for time-series data
CREATE TABLE metrics (
    id BIGSERIAL,
    tenant_id UUID NOT NULL,
    project_id UUID NOT NULL,
    metric_name VARCHAR(100) NOT NULL,
    metric_value DECIMAL(15,4) NOT NULL,
    recorded_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id, recorded_at)
) PARTITION BY RANGE (recorded_at);

-- Create monthly partitions
CREATE TABLE metrics_2024_01 PARTITION OF metrics
    FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');
CREATE TABLE metrics_2024_02 PARTITION OF metrics
    FOR VALUES FROM ('2024-02-01') TO ('2024-03-01');
```

#### **Database Connection Management**
```go
// Connection pooling configuration
package database

import (
    "time"
    
    "gorm.io/driver/postgres"
    "gorm.io/gorm"
    "gorm.io/gorm/logger"
)

type Config struct {
    Host            string
    Port            int
    User            string
    Password        string
    Database        string
    MaxOpenConns    int
    MaxIdleConns    int
    ConnMaxLifetime time.Duration
    ConnMaxIdleTime time.Duration
}

func Connect(cfg Config) (*gorm.DB, error) {
    dsn := fmt.Sprintf("host=%s port=%d user=%s password=%s dbname=%s sslmode=require TimeZone=UTC",
        cfg.Host, cfg.Port, cfg.User, cfg.Password, cfg.Database)
    
    db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{
        Logger: logger.Default.LogMode(logger.Info),
        NowFunc: func() time.Time {
            return time.Now().UTC()
        },
    })
    if err != nil {
        return nil, fmt.Errorf("failed to connect to database: %w", err)
    }
    
    sqlDB, err := db.DB()
    if err != nil {
        return nil, fmt.Errorf("failed to get underlying sql.DB: %w", err)
    }
    
    // Connection pool settings
    sqlDB.SetMaxOpenConns(cfg.MaxOpenConns)           // Maximum open connections
    sqlDB.SetMaxIdleConns(cfg.MaxIdleConns)           // Maximum idle connections
    sqlDB.SetConnMaxLifetime(cfg.ConnMaxLifetime)     // Maximum connection lifetime
    sqlDB.SetConnMaxIdleTime(cfg.ConnMaxIdleTime)     // Maximum idle time
    
    return db, nil
}

// Repository pattern with context
type ProjectRepository struct {
    db *gorm.DB
}

func (r *ProjectRepository) Create(ctx context.Context, project *Project) error {
    return r.db.WithContext(ctx).Create(project).Error
}

func (r *ProjectRepository) GetByIDWithTenant(ctx context.Context, id, tenantID uuid.UUID) (*Project, error) {
    var project Project
    err := r.db.WithContext(ctx).
        Where("id = ? AND tenant_id = ?", id, tenantID).
        First(&project).Error
    
    if errors.Is(err, gorm.ErrRecordNotFound) {
        return nil, ErrProjectNotFound
    }
    
    return &project, err
}
```

## 🔐 Security Best Practices

### **Authentication & Authorization**

#### **JWT Token Management**
```go
// Secure JWT implementation with rotation
package auth

import (
    "crypto/rand"
    "encoding/base64"
    "fmt"
    "time"
    
    "github.com/golang-jwt/jwt/v5"
    "golang.org/x/crypto/argon2"
)

type TokenManager struct {
    accessSecret  []byte
    refreshSecret []byte
    issuer       string
}

type Claims struct {
    UserID   string   `json:"sub"`
    Email    string   `json:"email"`
    TenantID string   `json:"tenant_id"`
    Roles    []string `json:"roles"`
    jwt.RegisteredClaims
}

func (tm *TokenManager) GenerateTokenPair(userID, email, tenantID string, roles []string) (*TokenPair, error) {
    // Generate access token (short-lived)
    accessClaims := Claims{
        UserID:   userID,
        Email:    email,
        TenantID: tenantID,
        Roles:    roles,
        RegisteredClaims: jwt.RegisteredClaims{
            Issuer:    tm.issuer,
            Subject:   userID,
            Audience:  []string{"railway-api"},
            ExpiresAt: jwt.NewNumericDate(time.Now().Add(15 * time.Minute)),
            NotBefore: jwt.NewNumericDate(time.Now()),
            IssuedAt:  jwt.NewNumericDate(time.Now()),
            ID:        generateJTI(),
        },
    }
    
    accessToken := jwt.NewWithClaims(jwt.SigningMethodHS256, accessClaims)
    accessTokenString, err := accessToken.SignedString(tm.accessSecret)
    if err != nil {
        return nil, fmt.Errorf("failed to sign access token: %w", err)
    }
    
    // Generate refresh token (long-lived)
    refreshClaims := jwt.RegisteredClaims{
        Issuer:    tm.issuer,
        Subject:   userID,
        Audience:  []string{"railway-refresh"},
        ExpiresAt: jwt.NewNumericDate(time.Now().Add(7 * 24 * time.Hour)),
        NotBefore: jwt.NewNumericDate(time.Now()),
        IssuedAt:  jwt.NewNumericDate(time.Now()),
        ID:        generateJTI(),
    }
    
    refreshToken := jwt.NewWithClaims(jwt.SigningMethodHS256, refreshClaims)
    refreshTokenString, err := refreshToken.SignedString(tm.refreshSecret)
    if err != nil {
        return nil, fmt.Errorf("failed to sign refresh token: %w", err)
    }
    
    return &TokenPair{
        AccessToken:  accessTokenString,
        RefreshToken: refreshTokenString,
        ExpiresIn:    15 * 60, // 15 minutes in seconds
        TokenType:    "Bearer",
    }, nil
}

// Secure password hashing with Argon2
func HashPassword(password string) (string, error) {
    salt := make([]byte, 32)
    if _, err := rand.Read(salt); err != nil {
        return "", fmt.Errorf("failed to generate salt: %w", err)
    }
    
    // Argon2id parameters (adjust based on your security requirements)
    hash := argon2.IDKey([]byte(password), salt, 1, 64*1024, 4, 32)
    
    // Encode salt and hash
    encoded := fmt.Sprintf("$argon2id$v=%d$m=%d,t=%d,p=%d$%s$%s",
        argon2.Version, 64*1024, 1, 4,
        base64.RawStdEncoding.EncodeToString(salt),
        base64.RawStdEncoding.EncodeToString(hash))
    
    return encoded, nil
}
```

#### **Role-Based Access Control (RBAC)**
```go
// RBAC implementation
package rbac

type Permission struct {
    Resource string `json:"resource"` // projects, deployments, databases
    Action   string `json:"action"`   // create, read, update, delete
    Scope    string `json:"scope"`    // own, team, global
}

type Role struct {
    Name        string       `json:"name"`
    Permissions []Permission `json:"permissions"`
}

var DefaultRoles = map[string]Role{
    "owner": {
        Name: "owner",
        Permissions: []Permission{
            {Resource: "*", Action: "*", Scope: "team"},
        },
    },
    "admin": {
        Name: "admin",
        Permissions: []Permission{
            {Resource: "projects", Action: "*", Scope: "team"},
            {Resource: "deployments", Action: "*", Scope: "team"},
            {Resource: "databases", Action: "*", Scope: "team"},
            {Resource: "team", Action: "read", Scope: "team"},
        },
    },
    "developer": {
        Name: "developer",
        Permissions: []Permission{
            {Resource: "projects", Action: "read", Scope: "team"},
            {Resource: "projects", Action: "*", Scope: "own"},
            {Resource: "deployments", Action: "*", Scope: "own"},
            {Resource: "databases", Action: "read", Scope: "team"},
        },
    },
    "viewer": {
        Name: "viewer",
        Permissions: []Permission{
            {Resource: "*", Action: "read", Scope: "team"},
        },
    },
}

type Authorizer struct {
    roles map[string]Role
}

func NewAuthorizer() *Authorizer {
    return &Authorizer{
        roles: DefaultRoles,
    }
}

func (a *Authorizer) CheckPermission(userRoles []string, resource, action, scope string, userID, resourceOwnerID string) bool {
    for _, roleName := range userRoles {
        role, exists := a.roles[roleName]
        if !exists {
            continue
        }
        
        for _, permission := range role.Permissions {
            if a.matchesPermission(permission, resource, action, scope, userID, resourceOwnerID) {
                return true
            }
        }
    }
    
    return false
}

func (a *Authorizer) matchesPermission(perm Permission, resource, action, scope, userID, resourceOwnerID string) bool {
    // Check resource match
    if perm.Resource != "*" && perm.Resource != resource {
        return false
    }
    
    // Check action match
    if perm.Action != "*" && perm.Action != action {
        return false
    }
    
    // Check scope
    switch perm.Scope {
    case "global":
        return true
    case "team":
        return true // Assuming user is already in the team context
    case "own":
        return userID == resourceOwnerID
    default:
        return false
    }
}
```

### **Input Validation & Sanitization**
```go
// Comprehensive input validation
package validation

import (
    "regexp"
    "strings"
    
    "github.com/go-playground/validator/v10"
)

var (
    projectNameRegex = regexp.MustCompile(`^[a-zA-Z0-9][a-zA-Z0-9-_.]{0,62}[a-zA-Z0-9]$`)
    domainRegex     = regexp.MustCompile(`^[a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9]?\.[a-zA-Z]{2,}$`)
)

type Validator struct {
    validate *validator.Validate
}

func NewValidator() *Validator {
    v := validator.New()
    
    // Custom validation rules
    v.RegisterValidation("project_name", validateProjectName)
    v.RegisterValidation("domain_name", validateDomainName)
    v.RegisterValidation("env_var_name", validateEnvVarName)
    
    return &Validator{validate: v}
}

func validateProjectName(fl validator.FieldLevel) bool {
    name := fl.Field().String()
    return projectNameRegex.MatchString(name)
}

func validateDomainName(fl validator.FieldLevel) bool {
    domain := fl.Field().String()
    return domainRegex.MatchString(domain)
}

func validateEnvVarName(fl validator.FieldLevel) bool {
    name := fl.Field().String()
    // Environment variable names should follow POSIX standards
    match, _ := regexp.MatchString(`^[A-Z][A-Z0-9_]*$`, name)
    return match
}

// Request validation structs
type CreateProjectRequest struct {
    Name         string            `json:"name" validate:"required,project_name"`
    Description  string            `json:"description" validate:"max=500"`
    RepositoryURL string           `json:"repository_url" validate:"required,url"`
    Environment  map[string]string `json:"environment" validate:"dive,keys,env_var_name,endkeys,max=1000"`
}

type UpdateDomainRequest struct {
    Domain string `json:"domain" validate:"required,domain_name"`
}

// Sanitization functions
func SanitizeString(input string) string {
    // Remove null bytes and control characters
    cleaned := strings.Map(func(r rune) rune {
        if r < 32 && r != '\t' && r != '\n' && r != '\r' {
            return -1
        }
        return r
    }, input)
    
    // Trim whitespace
    return strings.TrimSpace(cleaned)
}

func SanitizeEnvironmentVariables(env map[string]string) map[string]string {
    sanitized := make(map[string]string)
    
    for key, value := range env {
        cleanKey := SanitizeString(key)
        cleanValue := SanitizeString(value)
        
        if cleanKey != "" && len(cleanValue) <= 1000 {
            sanitized[cleanKey] = cleanValue
        }
    }
    
    return sanitized
}
```

## 🚀 DevOps Best Practices

### **Container Security**

#### **Secure Dockerfile Patterns**
```dockerfile
# Multi-stage build with security best practices
FROM golang:1.21-alpine AS builder

# Install security updates
RUN apk add --no-cache git ca-certificates tzdata

# Create non-root user for build
RUN adduser -D -g '' appuser

WORKDIR /app

# Copy go mod files first for better caching
COPY go.mod go.sum ./
RUN go mod download && go mod verify

# Copy source code
COPY . .

# Build with security flags
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags='-w -s -extldflags "-static"' \
    -a -installsuffix cgo \
    -o main ./cmd/api

# Production image
FROM scratch

# Copy CA certificates for HTTPS
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /etc/passwd /etc/passwd
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo

# Copy binary
COPY --from=builder --chown=appuser:appuser /app/main /main

# Use non-root user
USER appuser

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD ["/main", "healthcheck"]

# Run application
ENTRYPOINT ["/main"]
```

#### **Kubernetes Security Policies**
```yaml
# Pod Security Policy
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: railway-restricted
spec:
  privileged: false
  allowPrivilegeEscalation: false
  requiredDropCapabilities:
    - ALL
  volumes:
    - 'configMap'
    - 'emptyDir'
    - 'projected'
    - 'secret'
    - 'downwardAPI'
    - 'persistentVolumeClaim'
  runAsUser:
    rule: 'MustRunAsNonRoot'
  seLinux:
    rule: 'RunAsAny'
  fsGroup:
    rule: 'RunAsAny'

---
# Network Policy for tenant isolation
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: tenant-isolation
  namespace: user-workloads
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: railway-system
    - podSelector:
        matchLabels:
          tenant: same-tenant
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: railway-system
  - to: []
    ports:
    - protocol: TCP
      port: 53
    - protocol: UDP
      port: 53
  - to: []
    ports:
    - protocol: TCP
      port: 443
    - protocol: TCP
      port: 80
```

### **Monitoring & Observability**

#### **Structured Logging**
```go
// Structured logging with contextual information
package logging

import (
    "context"
    "os"
    "time"
    
    "github.com/sirupsen/logrus"
    "go.opentelemetry.io/otel/trace"
)

type Logger struct {
    *logrus.Logger
}

func NewLogger() *Logger {
    logger := logrus.New()
    
    // JSON formatting for production
    logger.SetFormatter(&logrus.JSONFormatter{
        TimestampFormat: time.RFC3339Nano,
        FieldMap: logrus.FieldMap{
            logrus.FieldKeyTime:  "timestamp",
            logrus.FieldKeyLevel: "level",
            logrus.FieldKeyMsg:   "message",
        },
    })
    
    // Set log level from environment
    level, err := logrus.ParseLevel(os.Getenv("LOG_LEVEL"))
    if err != nil {
        level = logrus.InfoLevel
    }
    logger.SetLevel(level)
    
    return &Logger{logger}
}

// Context-aware logging with trace information
func (l *Logger) WithContext(ctx context.Context) *logrus.Entry {
    entry := l.WithFields(logrus.Fields{})
    
    // Add trace information if available
    span := trace.SpanFromContext(ctx)
    if span.SpanContext().IsValid() {
        entry = entry.WithFields(logrus.Fields{
            "trace_id": span.SpanContext().TraceID().String(),
            "span_id":  span.SpanContext().SpanID().String(),
        })
    }
    
    return entry
}

// Request logging middleware
func (l *Logger) RequestLoggingMiddleware() gin.HandlerFunc {
    return func(c *gin.Context) {
        start := time.Now()
        
        // Process request
        c.Next()
        
        // Log request details
        duration := time.Since(start)
        entry := l.WithContext(c.Request.Context()).WithFields(logrus.Fields{
            "method":     c.Request.Method,
            "path":       c.Request.URL.Path,
            "status":     c.Writer.Status(),
            "duration":   duration.Milliseconds(),
            "user_agent": c.Request.UserAgent(),
            "ip":         c.ClientIP(),
        })
        
        if len(c.Errors) > 0 {
            entry.WithField("errors", c.Errors.String()).Error("Request completed with errors")
        } else {
            entry.Info("Request completed")
        }
    }
}

// Business logic logging
func (l *Logger) LogDeploymentEvent(ctx context.Context, projectID, deploymentID string, event string, metadata map[string]interface{}) {
    entry := l.WithContext(ctx).WithFields(logrus.Fields{
        "project_id":    projectID,
        "deployment_id": deploymentID,
        "event":         event,
        "component":     "deployment",
    })
    
    for key, value := range metadata {
        entry = entry.WithField(key, value)
    }
    
    entry.Info("Deployment event")
}
```

#### **Metrics Collection**
```go
// Prometheus metrics collection
package metrics

import (
    "time"
    
    "github.com/prometheus/client_golang/prometheus"
    "github.com/prometheus/client_golang/prometheus/promauto"
)

var (
    // HTTP metrics
    httpRequestsTotal = promauto.NewCounterVec(
        prometheus.CounterOpts{
            Name: "railway_http_requests_total",
            Help: "Total number of HTTP requests",
        },
        []string{"method", "endpoint", "status"},
    )
    
    httpRequestDuration = promauto.NewHistogramVec(
        prometheus.HistogramOpts{
            Name:    "railway_http_request_duration_seconds",
            Help:    "HTTP request duration in seconds",
            Buckets: []float64{.001, .005, .01, .025, .05, .1, .25, .5, 1, 2.5, 5, 10},
        },
        []string{"method", "endpoint"},
    )
    
    // Business metrics
    deploymentsTotal = promauto.NewCounterVec(
        prometheus.CounterOpts{
            Name: "railway_deployments_total",
            Help: "Total number of deployments",
        },
        []string{"status", "project_id", "environment"},
    )
    
    deploymentDuration = promauto.NewHistogramVec(
        prometheus.HistogramOpts{
            Name:    "railway_deployment_duration_seconds",
            Help:    "Deployment duration in seconds",
            Buckets: []float64{30, 60, 120, 300, 600, 1200, 1800, 3600},
        },
        []string{"project_id", "environment"},
    )
    
    activeProjects = promauto.NewGaugeVec(
        prometheus.GaugeOpts{
            Name: "railway_active_projects",
            Help: "Number of active projects",
        },
        []string{"region", "plan"},
    )
    
    resourceUsage = promauto.NewGaugeVec(
        prometheus.GaugeOpts{
            Name: "railway_resource_usage",
            Help: "Resource usage by project",
        },
        []string{"project_id", "resource_type", "unit"},
    )
)

type MetricsCollector struct {
    registry prometheus.Registerer
}

func NewMetricsCollector(registry prometheus.Registerer) *MetricsCollector {
    return &MetricsCollector{
        registry: registry,
    }
}

// HTTP middleware for metrics
func (m *MetricsCollector) HTTPMetricsMiddleware() gin.HandlerFunc {
    return func(c *gin.Context) {
        start := time.Now()
        
        c.Next()
        
        duration := time.Since(start).Seconds()
        status := c.Writer.Status()
        
        httpRequestsTotal.WithLabelValues(
            c.Request.Method,
            c.FullPath(),
            fmt.Sprintf("%d", status),
        ).Inc()
        
        httpRequestDuration.WithLabelValues(
            c.Request.Method,
            c.FullPath(),
        ).Observe(duration)
    }
}

// Business metrics recording
func (m *MetricsCollector) RecordDeployment(projectID, environment, status string, duration time.Duration) {
    deploymentsTotal.WithLabelValues(status, projectID, environment).Inc()
    
    if status == "success" {
        deploymentDuration.WithLabelValues(projectID, environment).Observe(duration.Seconds())
    }
}

func (m *MetricsCollector) UpdateResourceUsage(projectID string, cpuCores, memoryGB, storageGB float64) {
    resourceUsage.WithLabelValues(projectID, "cpu", "cores").Set(cpuCores)
    resourceUsage.WithLabelValues(projectID, "memory", "gb").Set(memoryGB)
    resourceUsage.WithLabelValues(projectID, "storage", "gb").Set(storageGB)
}
```

## 🔧 Performance Optimization

### **Database Optimization**

#### **Query Optimization Patterns**
```go
// Efficient database queries
package repository

import (
    "context"
    "fmt"
    
    "gorm.io/gorm"
)

type ProjectRepository struct {
    db *gorm.DB
}

// Good: Use pagination and indexes
func (r *ProjectRepository) ListProjectsPaginated(ctx context.Context, userID uuid.UUID, offset, limit int) ([]*Project, int64, error) {
    var projects []*Project
    var total int64
    
    // Count total (use EXPLAIN to verify index usage)
    if err := r.db.WithContext(ctx).
        Model(&Project{}).
        Where("user_id = ?", userID).
        Count(&total).Error; err != nil {
        return nil, 0, err
    }
    
    // Fetch paginated results with preloading
    if err := r.db.WithContext(ctx).
        Where("user_id = ?", userID).
        Preload("Deployments", func(db *gorm.DB) *gorm.DB {
            return db.Order("created_at DESC").Limit(5)
        }).
        Order("created_at DESC").
        Offset(offset).
        Limit(limit).
        Find(&projects).Error; err != nil {
        return nil, 0, err
    }
    
    return projects, total, nil
}

// Bad: N+1 query problem
func (r *ProjectRepository) ListProjectsWithDeployments(ctx context.Context, userID uuid.UUID) ([]*Project, error) {
    var projects []*Project
    
    if err := r.db.WithContext(ctx).
        Where("user_id = ?", userID).
        Find(&projects).Error; err != nil {
        return nil, err
    }
    
    // This creates N+1 queries - one for each project
    for i := range projects {
        var deployments []*Deployment
        r.db.WithContext(ctx).
            Where("project_id = ?", projects[i].ID).
            Find(&deployments)
        projects[i].Deployments = deployments
    }
    
    return projects, nil
}

// Optimized: Batch queries with proper indexing
func (r *ProjectRepository) GetProjectMetrics(ctx context.Context, projectIDs []uuid.UUID, days int) (map[uuid.UUID]*ProjectMetrics, error) {
    if len(projectIDs) == 0 {
        return make(map[uuid.UUID]*ProjectMetrics), nil
    }
    
    var results []struct {
        ProjectID       uuid.UUID `gorm:"column:project_id"`
        DeploymentCount int64     `gorm:"column:deployment_count"`
        AvgDuration     float64   `gorm:"column:avg_duration"`
        SuccessRate     float64   `gorm:"column:success_rate"`
    }
    
    query := `
        SELECT 
            project_id,
            COUNT(*) as deployment_count,
            AVG(EXTRACT(EPOCH FROM (completed_at - started_at))) as avg_duration,
            (COUNT(*) FILTER (WHERE status = 'success')::float / COUNT(*)) * 100 as success_rate
        FROM deployments 
        WHERE project_id = ANY(?) 
        AND created_at >= NOW() - INTERVAL '%d days'
        GROUP BY project_id`
    
    if err := r.db.WithContext(ctx).
        Raw(fmt.Sprintf(query, days), projectIDs).
        Scan(&results).Error; err != nil {
        return nil, err
    }
    
    metrics := make(map[uuid.UUID]*ProjectMetrics)
    for _, result := range results {
        metrics[result.ProjectID] = &ProjectMetrics{
            DeploymentCount: result.DeploymentCount,
            AvgDuration:     time.Duration(result.AvgDuration * float64(time.Second)),
            SuccessRate:     result.SuccessRate,
        }
    }
    
    return metrics, nil
}
```

### **Caching Strategies**

#### **Multi-Level Caching**
```go
// Redis caching implementation
package cache

import (
    "context"
    "encoding/json"
    "fmt"
    "time"
    
    "github.com/redis/go-redis/v9"
)

type Cache struct {
    client redis.Cmdable
    prefix string
}

func NewCache(client redis.Cmdable, prefix string) *Cache {
    return &Cache{
        client: client,
        prefix: prefix,
    }
}

func (c *Cache) key(k string) string {
    return fmt.Sprintf("%s:%s", c.prefix, k)
}

// Generic caching with JSON serialization
func (c *Cache) Set(ctx context.Context, key string, value interface{}, ttl time.Duration) error {
    data, err := json.Marshal(value)
    if err != nil {
        return fmt.Errorf("failed to marshal value: %w", err)
    }
    
    return c.client.Set(ctx, c.key(key), data, ttl).Err()
}

func (c *Cache) Get(ctx context.Context, key string, dest interface{}) error {
    data, err := c.client.Get(ctx, c.key(key)).Bytes()
    if err != nil {
        return err
    }
    
    return json.Unmarshal(data, dest)
}

// Cache-aside pattern implementation
type ProjectService struct {
    repo  ProjectRepository
    cache *Cache
}

func (s *ProjectService) GetProject(ctx context.Context, id uuid.UUID) (*Project, error) {
    cacheKey := fmt.Sprintf("project:%s", id)
    
    // Try cache first
    var project Project
    if err := s.cache.Get(ctx, cacheKey, &project); err == nil {
        return &project, nil
    }
    
    // Cache miss - fetch from database
    dbProject, err := s.repo.GetByID(ctx, id)
    if err != nil {
        return nil, err
    }
    
    // Store in cache for 5 minutes
    s.cache.Set(ctx, cacheKey, dbProject, 5*time.Minute)
    
    return dbProject, nil
}

// Cache invalidation on updates
func (s *ProjectService) UpdateProject(ctx context.Context, id uuid.UUID, updates *ProjectUpdates) (*Project, error) {
    project, err := s.repo.Update(ctx, id, updates)
    if err != nil {
        return nil, err
    }
    
    // Invalidate cache
    cacheKey := fmt.Sprintf("project:%s", id)
    s.cache.client.Del(ctx, s.cache.key(cacheKey))
    
    return project, nil
}

// Write-through caching for critical data
func (s *ProjectService) CreateProject(ctx context.Context, req *CreateProjectRequest) (*Project, error) {
    project, err := s.repo.Create(ctx, req)
    if err != nil {
        return nil, err
    }
    
    // Immediately cache the new project
    cacheKey := fmt.Sprintf("project:%s", project.ID)
    s.cache.Set(ctx, cacheKey, project, 5*time.Minute)
    
    return project, nil
}
```

## 🚨 Error Handling & Resilience

### **Graceful Error Handling**

#### **Error Types & Handling**
```go
// Structured error handling
package errors

import (
    "fmt"
    "net/http"
)

// Domain errors
type ErrorType string

const (
    ErrorTypeValidation    ErrorType = "validation"
    ErrorTypeNotFound      ErrorType = "not_found"
    ErrorTypeUnauthorized  ErrorType = "unauthorized"
    ErrorTypeForbidden     ErrorType = "forbidden"
    ErrorTypeConflict      ErrorType = "conflict"
    ErrorTypeInternal      ErrorType = "internal"
    ErrorTypeExternal      ErrorType = "external"
)

type DomainError struct {
    Type    ErrorType `json:"type"`
    Message string    `json:"message"`
    Details string    `json:"details,omitempty"`
    Code    string    `json:"code,omitempty"`
}

func (e DomainError) Error() string {
    return e.Message
}

func (e DomainError) HTTPStatus() int {
    switch e.Type {
    case ErrorTypeValidation:
        return http.StatusBadRequest
    case ErrorTypeNotFound:
        return http.StatusNotFound
    case ErrorTypeUnauthorized:
        return http.StatusUnauthorized
    case ErrorTypeForbidden:
        return http.StatusForbidden
    case ErrorTypeConflict:
        return http.StatusConflict
    case ErrorTypeExternal:
        return http.StatusBadGateway
    default:
        return http.StatusInternalServerError
    }
}

// Predefined errors
var (
    ErrProjectNotFound = DomainError{
        Type:    ErrorTypeNotFound,
        Message: "Project not found",
        Code:    "PROJECT_NOT_FOUND",
    }
    
    ErrInvalidProjectName = DomainError{
        Type:    ErrorTypeValidation,
        Message: "Invalid project name",
        Code:    "INVALID_PROJECT_NAME",
    }
    
    ErrDeploymentInProgress = DomainError{
        Type:    ErrorTypeConflict,
        Message: "Another deployment is already in progress",
        Code:    "DEPLOYMENT_IN_PROGRESS",
    }
)

// Error handling middleware
func ErrorHandlingMiddleware() gin.HandlerFunc {
    return gin.CustomRecovery(func(c *gin.Context, recovered interface{}) {
        if err, ok := recovered.(string); ok {
            c.JSON(http.StatusInternalServerError, gin.H{
                "error": "Internal server error",
                "details": err,
            })
        }
        c.AbortWithStatus(http.StatusInternalServerError)
    })
}

// Service layer error handling
func (s *ProjectService) CreateProject(ctx context.Context, req *CreateProjectRequest) (*Project, error) {
    // Validation
    if err := s.validator.Struct(req); err != nil {
        return nil, DomainError{
            Type:    ErrorTypeValidation,
            Message: "Invalid project data",
            Details: err.Error(),
            Code:    "VALIDATION_FAILED",
        }
    }
    
    // Business logic validation
    if exists, err := s.repo.ExistsByName(ctx, req.Name); err != nil {
        return nil, fmt.Errorf("failed to check project existence: %w", err)
    } else if exists {
        return nil, DomainError{
            Type:    ErrorTypeConflict,
            Message: "Project with this name already exists",
            Code:    "PROJECT_NAME_EXISTS",
        }
    }
    
    // Create project
    project, err := s.repo.Create(ctx, req)
    if err != nil {
        return nil, fmt.Errorf("failed to create project: %w", err)
    }
    
    return project, nil
}
```

### **Circuit Breaker Pattern**
```go
// Circuit breaker implementation
package circuitbreaker

import (
    "errors"
    "sync"
    "time"
)

type State int

const (
    StateClosed State = iota
    StateHalfOpen
    StateOpen
)

type CircuitBreaker struct {
    mutex      sync.RWMutex
    state      State
    failures   int
    requests   int
    lastFailTime time.Time
    
    maxFailures  int
    timeout      time.Duration
    maxRequests  int
}

var ErrCircuitBreakerOpen = errors.New("circuit breaker is open")

func NewCircuitBreaker(maxFailures int, timeout time.Duration, maxRequests int) *CircuitBreaker {
    return &CircuitBreaker{
        state:       StateClosed,
        maxFailures: maxFailures,
        timeout:     timeout,
        maxRequests: maxRequests,
    }
}

func (cb *CircuitBreaker) Execute(fn func() (interface{}, error)) (interface{}, error) {
    if !cb.canExecute() {
        return nil, ErrCircuitBreakerOpen
    }
    
    result, err := fn()
    cb.recordResult(err == nil)
    
    return result, err
}

func (cb *CircuitBreaker) canExecute() bool {
    cb.mutex.RLock()
    defer cb.mutex.RUnlock()
    
    switch cb.state {
    case StateClosed:
        return true
    case StateOpen:
        return time.Since(cb.lastFailTime) > cb.timeout
    case StateHalfOpen:
        return cb.requests < cb.maxRequests
    default:
        return false
    }
}

func (cb *CircuitBreaker) recordResult(success bool) {
    cb.mutex.Lock()
    defer cb.mutex.Unlock()
    
    if success {
        cb.failures = 0
        if cb.state == StateHalfOpen {
            cb.state = StateClosed
            cb.requests = 0
        }
    } else {
        cb.failures++
        cb.lastFailTime = time.Now()
        
        if cb.failures >= cb.maxFailures {
            cb.state = StateOpen
        }
    }
    
    if cb.state == StateHalfOpen {
        cb.requests++
    }
}
```

## 📊 Testing Best Practices

### **Comprehensive Testing Strategy**

#### **Unit Testing with Mocks**
```go
// Unit testing with proper mocking
package service_test

import (
    "context"
    "testing"
    "time"
    
    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/mock"
    "github.com/stretchr/testify/require"
)

// Mock repository
type MockProjectRepository struct {
    mock.Mock
}

func (m *MockProjectRepository) Create(ctx context.Context, project *Project) error {
    args := m.Called(ctx, project)
    return args.Error(0)
}

func (m *MockProjectRepository) GetByID(ctx context.Context, id uuid.UUID) (*Project, error) {
    args := m.Called(ctx, id)
    return args.Get(0).(*Project), args.Error(1)
}

func (m *MockProjectRepository) ExistsByName(ctx context.Context, name string) (bool, error) {
    args := m.Called(ctx, name)
    return args.Bool(0), args.Error(1)
}

// Test suite
func TestProjectService_CreateProject(t *testing.T) {
    tests := []struct {
        name           string
        request        *CreateProjectRequest
        setupMocks     func(*MockProjectRepository)
        expectedError  error
        expectedResult *Project
    }{
        {
            name: "successful project creation",
            request: &CreateProjectRequest{
                Name:        "test-project",
                Description: "Test project",
                RepoURL:     "https://github.com/user/repo.git",
            },
            setupMocks: func(repo *MockProjectRepository) {
                repo.On("ExistsByName", mock.Anything, "test-project").Return(false, nil)
                repo.On("Create", mock.Anything, mock.AnythingOfType("*Project")).Return(nil)
            },
            expectedError: nil,
            expectedResult: &Project{
                Name:        "test-project",
                Description: "Test project",
                RepoURL:     "https://github.com/user/repo.git",
            },
        },
        {
            name: "project name already exists",
            request: &CreateProjectRequest{
                Name:        "existing-project",
                Description: "Test project",
                RepoURL:     "https://github.com/user/repo.git",
            },
            setupMocks: func(repo *MockProjectRepository) {
                repo.On("ExistsByName", mock.Anything, "existing-project").Return(true, nil)
            },
            expectedError: ErrProjectNameExists,
        },
    }
    
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            // Setup
            mockRepo := new(MockProjectRepository)
            tt.setupMocks(mockRepo)
            
            service := NewProjectService(mockRepo, nil)
            
            // Execute
            result, err := service.CreateProject(context.Background(), tt.request)
            
            // Assert
            if tt.expectedError != nil {
                assert.Error(t, err)
                assert.Equal(t, tt.expectedError, err)
                assert.Nil(t, result)
            } else {
                assert.NoError(t, err)
                assert.NotNil(t, result)
                assert.Equal(t, tt.expectedResult.Name, result.Name)
            }
            
            mockRepo.AssertExpectations(t)
        })
    }
}
```

#### **Integration Testing**
```go
// Integration tests with test containers
package integration_test

import (
    "context"
    "testing"
    "time"
    
    "github.com/stretchr/testify/require"
    "github.com/testcontainers/testcontainers-go"
    "github.com/testcontainers/testcontainers-go/modules/postgres"
)

func TestProjectRepository_Integration(t *testing.T) {
    if testing.Short() {
        t.Skip("Skipping integration tests in short mode")
    }
    
    // Setup test database
    ctx := context.Background()
    
    postgresContainer, err := postgres.RunContainer(ctx,
        testcontainers.WithImage("postgres:15-alpine"),
        postgres.WithDatabase("testdb"),
        postgres.WithUsername("testuser"),
        postgres.WithPassword("testpass"),
    )
    require.NoError(t, err)
    defer postgresContainer.Terminate(ctx)
    
    connStr, err := postgresContainer.ConnectionString(ctx, "sslmode=disable")
    require.NoError(t, err)
    
    // Setup repository
    db, err := setupTestDatabase(connStr)
    require.NoError(t, err)
    
    repo := NewProjectRepository(db)
    
    // Test project creation
    t.Run("create and retrieve project", func(t *testing.T) {
        project := &Project{
            Name:        "test-project",
            Description: "Integration test project",
            UserID:      uuid.New(),
            CreatedAt:   time.Now(),
        }
        
        err := repo.Create(ctx, project)
        require.NoError(t, err)
        require.NotEmpty(t, project.ID)
        
        // Retrieve project
        retrieved, err := repo.GetByID(ctx, project.ID)
        require.NoError(t, err)
        require.Equal(t, project.Name, retrieved.Name)
        require.Equal(t, project.UserID, retrieved.UserID)
    })
}
```

#### **End-to-End Testing**
```go
// E2E testing with test environment
package e2e_test

import (
    "bytes"
    "encoding/json"
    "net/http"
    "testing"
    
    "github.com/stretchr/testify/require"
)

func TestDeploymentFlow_E2E(t *testing.T) {
    if testing.Short() {
        t.Skip("Skipping E2E tests in short mode")
    }
    
    // Setup test environment
    client := NewTestClient()
    
    // 1. Create user and login
    user := createTestUser(t, client)
    token := loginUser(t, client, user.Email, "password")
    
    // 2. Create project
    project := createProject(t, client, token, &CreateProjectRequest{
        Name:        "e2e-test-project",
        Description: "E2E test project",
        RepoURL:     "https://github.com/test/repo.git",
    })
    
    // 3. Trigger deployment
    deployment := triggerDeployment(t, client, token, &DeploymentRequest{
        ProjectID: project.ID,
        Branch:    "main",
    })
    
    // 4. Wait for deployment completion
    waitForDeployment(t, client, token, deployment.ID, 5*time.Minute)
    
    // 5. Verify deployment status
    finalDeployment := getDeployment(t, client, token, deployment.ID)
    require.Equal(t, "success", finalDeployment.Status)
    require.NotEmpty(t, finalDeployment.URL)
    
    // 6. Test deployed application
    resp, err := http.Get(finalDeployment.URL)
    require.NoError(t, err)
    require.Equal(t, http.StatusOK, resp.StatusCode)
}

func createProject(t *testing.T, client *TestClient, token string, req *CreateProjectRequest) *Project {
    body, _ := json.Marshal(req)
    
    resp, err := client.Post("/api/v1/projects", bytes.NewBuffer(body), authHeaders(token))
    require.NoError(t, err)
    require.Equal(t, http.StatusCreated, resp.StatusCode)
    
    var project Project
    err = json.NewDecoder(resp.Body).Decode(&project)
    require.NoError(t, err)
    
    return &project
}
```

## 🎯 Summary

These best practices provide a foundation for building a production-ready Railway.com-like platform. Key principles include:

### **Development Practices**
- **Clean Architecture** with clear separation of concerns
- **Comprehensive Testing** across all layers
- **Security-First** approach to authentication and authorization
- **Performance Optimization** from the start

### **Operational Practices**
- **Structured Logging** with contextual information
- **Comprehensive Monitoring** and alerting
- **Graceful Error Handling** and resilience patterns
- **Infrastructure as Code** for reproducible deployments

### **Security Practices**
- **Defense in Depth** across all layers
- **Secure by Default** configurations
- **Regular Security Audits** and updates
- **Compliance** with industry standards

Following these practices ensures your platform can scale to serve thousands of users while maintaining reliability, security, and performance.

---

**Navigation:**
- **Previous:** [Scaling & Performance](./scaling-performance.md)
- **Next:** [Template Examples](./template-examples.md)
- **Home:** [Railway Platform Creation](./README.md)