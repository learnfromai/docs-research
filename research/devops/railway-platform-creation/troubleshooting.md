# Troubleshooting Guide: Railway.com-like Platform

## 🔍 Common Issues and Solutions

This troubleshooting guide covers the most common issues you'll encounter when building and operating a Railway.com-like platform, along with practical solutions and debugging techniques.

## 🚨 Development Environment Issues

### **1. Docker Container Build Failures**

#### **Issue: Multi-stage Docker build fails**
```bash
Error: failed to solve: executor failed running [/bin/sh -c go build ...]: exit code 2
```

**Solution:**
```dockerfile
# Ensure proper Go module caching
FROM golang:1.21-alpine AS builder
WORKDIR /app

# Copy go.mod and go.sum first for better caching
COPY go.mod go.sum ./
RUN go mod download

# Then copy source code
COPY . .

# Build with verbose output for debugging
RUN CGO_ENABLED=0 GOOS=linux go build -v -o main ./cmd/api
```

#### **Issue: Frontend Docker build running out of memory**
```bash
Error: JavaScript heap out of memory
```

**Solution:**
```dockerfile
# Increase Node.js memory limit
FROM node:18-alpine AS builder
WORKDIR /app

# Increase memory limit
ENV NODE_OPTIONS="--max-old-space-size=4096"

COPY package*.json ./
RUN npm ci --only=production

COPY . .
RUN npm run build
```

### **2. Database Connection Issues**

#### **Issue: Connection refused to PostgreSQL**
```bash
Error: dial tcp 127.0.0.1:5432: connect: connection refused
```

**Debugging Steps:**
```bash
# Check if PostgreSQL is running
docker-compose ps postgres

# Check PostgreSQL logs
docker-compose logs postgres

# Test connection manually
docker-compose exec postgres psql -U railway -d railway_dev

# Check network connectivity
docker-compose exec api ping postgres
```

**Solution:**
```yaml
# docker-compose.yml - Ensure proper health checks
services:
  postgres:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: railway_dev
      POSTGRES_USER: railway
      POSTGRES_PASSWORD: password
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U railway -d railway_dev"]
      interval: 5s
      timeout: 5s
      retries: 5
  
  api:
    depends_on:
      postgres:
        condition: service_healthy
```

#### **Issue: Database migration failures**
```bash
Error: migration 001_create_users failed: pq: relation "users" already exists
```

**Solution:**
```go
// Use proper migration library with rollback support
package migrations

import (
    "database/sql"
    "github.com/pressly/goose/v3"
)

func init() {
    goose.AddMigration(upCreateUsers, downCreateUsers)
}

func upCreateUsers(tx *sql.Tx) error {
    query := `
    CREATE TABLE IF NOT EXISTS users (
        id SERIAL PRIMARY KEY,
        email VARCHAR(255) UNIQUE NOT NULL,
        password_hash VARCHAR(255) NOT NULL,
        name VARCHAR(255) NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );`
    
    _, err := tx.Exec(query)
    return err
}

func downCreateUsers(tx *sql.Tx) error {
    _, err := tx.Exec("DROP TABLE IF EXISTS users;")
    return err
}
```

### **3. Authentication and Authorization Issues**

#### **Issue: JWT token validation failing**
```bash
Error: invalid token: token is malformed
```

**Debugging:**
```go
// Add detailed JWT debugging
func (tm *TokenManager) VerifyToken(tokenString string) (*Claims, error) {
    // Log token for debugging (remove in production)
    log.Printf("Verifying token: %s", tokenString[:20]+"...")
    
    token, err := jwt.ParseWithClaims(tokenString, &Claims{}, func(token *jwt.Token) (interface{}, error) {
        // Verify signing method
        if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
            return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
        }
        return tm.secret, nil
    })
    
    if err != nil {
        log.Printf("Token parsing error: %v", err)
        return nil, err
    }
    
    if claims, ok := token.Claims.(*Claims); ok && token.Valid {
        log.Printf("Token verified for user: %s", claims.UserID)
        return claims, nil
    }
    
    return nil, fmt.Errorf("invalid token claims")
}
```

#### **Issue: CORS errors in frontend**
```bash
Error: Access to fetch at 'http://localhost:8080/api/v1/projects' from origin 'http://localhost:3000' has been blocked by CORS policy
```

**Solution:**
```go
// Proper CORS middleware
func CORSMiddleware() gin.HandlerFunc {
    return func(c *gin.Context) {
        origin := c.Request.Header.Get("Origin")
        
        // Allow specific origins in development
        allowedOrigins := []string{
            "http://localhost:3000",
            "http://localhost:3001",
            "https://app.railway.local",
        }
        
        for _, allowedOrigin := range allowedOrigins {
            if origin == allowedOrigin {
                c.Header("Access-Control-Allow-Origin", origin)
                break
            }
        }
        
        c.Header("Access-Control-Allow-Methods", "GET,POST,PUT,DELETE,OPTIONS")
        c.Header("Access-Control-Allow-Headers", "Content-Type,Authorization,X-Requested-With")
        c.Header("Access-Control-Allow-Credentials", "true")
        c.Header("Access-Control-Max-Age", "86400")
        
        if c.Request.Method == "OPTIONS" {
            c.AbortWithStatus(204)
            return
        }
        
        c.Next()
    }
}
```

## 🐳 Container and Kubernetes Issues

### **4. Kubernetes Pod Failures**

#### **Issue: ImagePullBackOff error**
```bash
Error: Failed to pull image "railway/api:latest": rpc error: code = NotFound desc = failed to pull and unpack image
```

**Debugging:**
```bash
# Check if image exists
kubectl describe pod railway-api-xyz

# Check image pull secrets
kubectl get secrets -n railway-system
kubectl describe secret regcred -n railway-system

# Test manual image pull
docker pull railway/api:latest
```

**Solution:**
```yaml
# Ensure proper image registry configuration
apiVersion: apps/v1
kind: Deployment
metadata:
  name: railway-api
spec:
  template:
    spec:
      imagePullSecrets:
      - name: regcred
      containers:
      - name: api
        image: ghcr.io/yourorg/railway-api:v1.0.0  # Use specific tags
        imagePullPolicy: Always
```

#### **Issue: CrashLoopBackOff**
```bash
Status: CrashLoopBackOff
Restart Count: 5
```

**Debugging:**
```bash
# Check pod logs
kubectl logs railway-api-xyz -n railway-system --previous

# Check pod events
kubectl describe pod railway-api-xyz -n railway-system

# Check resource limits
kubectl top pod railway-api-xyz -n railway-system

# Access pod for debugging
kubectl exec -it railway-api-xyz -n railway-system -- /bin/sh
```

**Common Solutions:**
```yaml
# Fix resource limits
resources:
  requests:
    memory: "256Mi"
    cpu: "250m"
  limits:
    memory: "512Mi"    # Increase if OOMKilled
    cpu: "500m"

# Fix liveness probe
livenessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 30  # Increase startup time
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3
```

### **5. Networking and Service Discovery Issues**

#### **Issue: Service unreachable from other pods**
```bash
Error: dial tcp: lookup railway-api-service: no such host
```

**Debugging:**
```bash
# Check service existence
kubectl get svc -n railway-system

# Check service endpoints
kubectl get endpoints railway-api-service -n railway-system

# Test DNS resolution
kubectl run debug --image=busybox -it --rm --restart=Never -- nslookup railway-api-service.railway-system.svc.cluster.local

# Test connectivity
kubectl run debug --image=curlimages/curl -it --rm --restart=Never -- curl http://railway-api-service.railway-system.svc.cluster.local/health
```

**Solution:**
```yaml
# Ensure proper service configuration
apiVersion: v1
kind: Service
metadata:
  name: railway-api-service
  namespace: railway-system
spec:
  selector:
    app: railway-api  # Must match pod labels
  ports:
  - name: http
    port: 80
    targetPort: 8080  # Must match container port
    protocol: TCP
  type: ClusterIP
```

#### **Issue: Ingress not routing traffic properly**
```bash
Error: 502 Bad Gateway
```

**Debugging:**
```bash
# Check ingress status
kubectl get ingress railway-ingress -n railway-system

# Check ingress controller logs
kubectl logs -f deployment/nginx-ingress-controller -n ingress-nginx

# Check backend service
kubectl get svc railway-api-service -n railway-system

# Test internal connectivity
kubectl port-forward svc/railway-api-service 8080:80 -n railway-system
```

**Solution:**
```yaml
# Ensure proper ingress configuration
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: railway-ingress
  namespace: railway-system
  annotations:
    kubernetes.io/ingress.class: "nginx"
    nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "600"
spec:
  rules:
  - host: api.railway.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: railway-api-service
            port:
              number: 80  # Must match service port
```

## 📊 Performance and Scaling Issues

### **6. Database Performance Problems**

#### **Issue: Slow database queries**
```bash
Error: context deadline exceeded (timeout after 30s)
```

**Debugging:**
```sql
-- Enable query logging
ALTER SYSTEM SET log_statement = 'all';
ALTER SYSTEM SET log_min_duration_statement = 1000;  -- Log queries > 1s
SELECT pg_reload_conf();

-- Check slow queries
SELECT query, mean_exec_time, calls, total_exec_time
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 10;

-- Check table statistics
SELECT schemaname, tablename, n_tup_ins, n_tup_upd, n_tup_del, n_live_tup, n_dead_tup
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC;

-- Check index usage
SELECT schemaname, tablename, indexname, idx_scan, idx_tup_read, idx_tup_fetch
FROM pg_stat_user_indexes
ORDER BY idx_scan ASC;
```

**Solutions:**
```sql
-- Add missing indexes
CREATE INDEX CONCURRENTLY idx_deployments_project_id_status 
ON deployments(project_id, status);

CREATE INDEX CONCURRENTLY idx_deployments_created_at_desc 
ON deployments(created_at DESC);

-- Optimize queries
-- Bad: N+1 query
SELECT * FROM projects WHERE user_id = ?;
-- For each project: SELECT * FROM deployments WHERE project_id = ?;

-- Good: Join or subquery
SELECT p.*, d.*
FROM projects p
LEFT JOIN LATERAL (
    SELECT * FROM deployments 
    WHERE project_id = p.id 
    ORDER BY created_at DESC 
    LIMIT 5
) d ON true
WHERE p.user_id = ?;

-- Regular maintenance
VACUUM ANALYZE;
REINDEX SCHEMA public;
```

### **7. Memory and Resource Issues**

#### **Issue: Out of Memory errors**
```bash
Error: signal: killed (OOMKilled)
```

**Debugging:**
```bash
# Check memory usage
kubectl top pod railway-api-xyz -n railway-system

# Check pod events
kubectl describe pod railway-api-xyz -n railway-system

# Monitor memory usage over time
kubectl exec railway-api-xyz -n railway-system -- cat /proc/meminfo

# Check for memory leaks in Go
# Add to your application
import _ "net/http/pprof"

go func() {
    log.Println(http.ListenAndServe("localhost:6060", nil))
}()
```

**Solutions:**
```go
// Optimize memory usage in Go
package main

import (
    "context"
    "runtime"
    "time"
)

// Use context for cancellation
func (s *Service) ProcessLargeDataset(ctx context.Context) error {
    for i := 0; i < 1000000; i++ {
        select {
        case <-ctx.Done():
            return ctx.Err()
        default:
            // Process item
            if i%1000 == 0 {
                runtime.GC() // Force garbage collection periodically
            }
        }
    }
    return nil
}

// Use connection pooling
func NewDatabase(dsn string) (*gorm.DB, error) {
    db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{})
    if err != nil {
        return nil, err
    }
    
    sqlDB, err := db.DB()
    if err != nil {
        return nil, err
    }
    
    // Configure connection pool
    sqlDB.SetMaxOpenConns(25)        // Limit concurrent connections
    sqlDB.SetMaxIdleConns(5)         // Limit idle connections
    sqlDB.SetConnMaxLifetime(5 * time.Minute)
    
    return db, nil
}
```

```yaml
# Increase resource limits
resources:
  requests:
    memory: "512Mi"
    cpu: "250m"
  limits:
    memory: "1Gi"      # Increased limit
    cpu: "500m"
```

### **8. Auto-scaling Issues**

#### **Issue: HPA not scaling pods**
```bash
Warning: FailedGetResourceMetric unable to get metrics for resource cpu
```

**Debugging:**
```bash
# Check HPA status
kubectl describe hpa railway-api-hpa -n railway-system

# Check metrics server
kubectl get deployment metrics-server -n kube-system
kubectl logs deployment/metrics-server -n kube-system

# Check resource requests are set
kubectl describe pod railway-api-xyz -n railway-system | grep -A 5 "Requests"

# Test metrics manually
kubectl top pods -n railway-system
```

**Solution:**
```yaml
# Ensure resource requests are set
spec:
  containers:
  - name: api
    resources:
      requests:        # Required for HPA
        memory: "256Mi"
        cpu: "250m"
      limits:
        memory: "512Mi"
        cpu: "500m"
---
# Fix HPA configuration
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: railway-api-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: railway-api
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 60
    scaleDown:
      stabilizationWindowSeconds: 300
```

## 🔐 Security Issues

### **9. Certificate and TLS Problems**

#### **Issue: TLS certificate errors**
```bash
Error: x509: certificate signed by unknown authority
```

**Debugging:**
```bash
# Check certificate details
openssl s_client -connect api.railway.com:443 -servername api.railway.com

# Check cert-manager logs
kubectl logs deployment/cert-manager -n cert-manager

# Check certificate resource
kubectl describe certificate railway-tls -n railway-system

# Check issuer status
kubectl describe clusterissuer letsencrypt-prod
```

**Solution:**
```yaml
# Fix cert-manager configuration
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@railway.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: railway-ingress
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    kubernetes.io/ingress.class: "nginx"
spec:
  tls:
  - hosts:
    - api.railway.com
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
```

### **10. RBAC and Permission Issues**

#### **Issue: Forbidden errors in Kubernetes**
```bash
Error: pods is forbidden: User "system:serviceaccount:railway-system:railway-api" cannot get resource "pods"
```

**Solution:**
```yaml
# Create proper RBAC configuration
apiVersion: v1
kind: ServiceAccount
metadata:
  name: railway-api
  namespace: railway-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: railway-system
  name: railway-api-role
rules:
- apiGroups: [""]
  resources: ["pods", "pods/log"]
  verbs: ["get", "list", "create", "delete"]
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "create", "update", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: railway-api-binding
  namespace: railway-system
subjects:
- kind: ServiceAccount
  name: railway-api
  namespace: railway-system
roleRef:
  kind: Role
  name: railway-api-role
  apiGroup: rbac.authorization.k8s.io
```

## 📈 Monitoring and Observability Issues

### **11. Prometheus Scraping Problems**

#### **Issue: Targets not being discovered**
```bash
Error: Get "http://railway-api:8080/metrics": dial tcp: lookup railway-api on 10.96.0.10:53: no such host
```

**Debugging:**
```bash
# Check Prometheus targets
curl http://prometheus:9090/api/v1/targets

# Check service discovery
kubectl get endpoints -n railway-system

# Check service annotations
kubectl describe svc railway-api-service -n railway-system
```

**Solution:**
```yaml
# Add proper annotations to service
apiVersion: v1
kind: Service
metadata:
  name: railway-api-service
  namespace: railway-system
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "8080"
    prometheus.io/path: "/metrics"
spec:
  selector:
    app: railway-api
  ports:
  - name: http
    port: 80
    targetPort: 8080
```

### **12. Log Aggregation Issues**

#### **Issue: Logs not appearing in aggregation system**
```bash
Error: No logs found for application
```

**Debugging:**
```bash
# Check if logs are being produced
kubectl logs railway-api-xyz -n railway-system

# Check fluentd/fluent-bit logs
kubectl logs daemonset/fluent-bit -n logging

# Check log format
kubectl logs railway-api-xyz -n railway-system --tail=5
```

**Solution:**
```go
// Use structured logging
package main

import (
    "github.com/sirupsen/logrus"
)

func init() {
    logrus.SetFormatter(&logrus.JSONFormatter{
        FieldMap: logrus.FieldMap{
            logrus.FieldKeyTime:  "timestamp",
            logrus.FieldKeyLevel: "level",
            logrus.FieldKeyMsg:   "message",
        },
    })
}

func logDeploymentEvent(projectID, deploymentID, event string) {
    logrus.WithFields(logrus.Fields{
        "project_id":    projectID,
        "deployment_id": deploymentID,
        "event":         event,
        "component":     "deployment",
    }).Info("Deployment event")
}
```

## 🚀 Deployment and CI/CD Issues

### **13. GitHub Actions Failures**

#### **Issue: Docker build fails in CI**
```bash
Error: failed to solve: failed to read dockerfile
```

**Solution:**
```yaml
# Fix context and dockerfile path
- name: Build and push Docker image
  uses: docker/build-push-action@v5
  with:
    context: ./backend          # Specify correct context
    file: ./backend/Dockerfile  # Specify dockerfile path
    push: true
    tags: ${{ steps.meta.outputs.tags }}
```

#### **Issue: Kubernetes deployment fails**
```bash
Error: error validating "k8s/deployment.yaml": error validating data
```

**Solution:**
```bash
# Validate manifests before deployment
- name: Validate Kubernetes manifests
  run: |
    kubectl apply --dry-run=client -f k8s/
    kubectl apply --dry-run=server -f k8s/
```

## 🔧 General Debugging Tools and Techniques

### **Debugging Toolkit**
```bash
#!/bin/bash
# debug-toolkit.sh

# Kubernetes debugging
debug_k8s() {
    echo "=== Kubernetes Debug Info ==="
    kubectl get pods -A
    kubectl get events --sort-by=.metadata.creationTimestamp
    kubectl top nodes
    kubectl top pods -A
}

# Database debugging
debug_db() {
    echo "=== Database Debug Info ==="
    docker-compose exec postgres psql -U railway -d railway_dev -c "
    SELECT 
        datname,
        numbackends,
        xact_commit,
        xact_rollback,
        blks_read,
        blks_hit,
        temp_files,
        temp_bytes,
        deadlocks
    FROM pg_stat_database 
    WHERE datname = 'railway_dev';"
}

# Application debugging
debug_app() {
    echo "=== Application Debug Info ==="
    curl -s http://localhost:8080/health | jq .
    curl -s http://localhost:8080/metrics | grep -E "^railway_"
}

# Network debugging
debug_network() {
    echo "=== Network Debug Info ==="
    kubectl get svc -A
    kubectl get ingress -A
    kubectl get networkpolicies -A
}

# Run all debugging
case "$1" in
    k8s) debug_k8s ;;
    db) debug_db ;;
    app) debug_app ;;
    network) debug_network ;;
    all) 
        debug_k8s
        debug_db
        debug_app
        debug_network
        ;;
    *)
        echo "Usage: $0 {k8s|db|app|network|all}"
        exit 1
        ;;
esac
```

### **Log Analysis Script**
```bash
#!/bin/bash
# analyze-logs.sh

# Analyze error patterns
analyze_errors() {
    kubectl logs -l app=railway-api -n railway-system --since=1h | \
    jq -r 'select(.level == "error") | .message' | \
    sort | uniq -c | sort -nr
}

# Check deployment timeline
deployment_timeline() {
    kubectl get events -n railway-system --sort-by=.metadata.creationTimestamp | \
    grep -E "(Deployment|Pod)" | tail -20
}

# Performance metrics
performance_metrics() {
    kubectl top pods -n railway-system --containers | \
    awk 'NR>1 {print $1 ": CPU=" $2 ", Memory=" $3}'
}

analyze_errors
deployment_timeline
performance_metrics
```

## 📚 Additional Resources

### **Useful Commands Reference**
```bash
# Quick health checks
kubectl get pods -A --field-selector=status.phase!=Running
kubectl get events --sort-by=.metadata.creationTimestamp | tail -20
docker-compose ps
docker-compose logs --tail=50

# Performance monitoring
kubectl top nodes
kubectl top pods -A
docker stats
htop

# Network troubleshooting
kubectl get svc -A
kubectl get ingress -A
nslookup api.railway.com
curl -I https://api.railway.com/health

# Database maintenance
VACUUM ANALYZE;
REINDEX SCHEMA public;
SELECT pg_size_pretty(pg_database_size('railway'));
```

This troubleshooting guide should help you quickly identify and resolve common issues when building and operating your Railway.com-like platform.

---

**Navigation:**
- **Previous:** [Template Examples](./template-examples.md)
- **Home:** [Railway Platform Creation](./README.md)