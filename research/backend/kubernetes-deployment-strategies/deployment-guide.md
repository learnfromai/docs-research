# Deployment Guide: Kubernetes Deployment Strategies

> **Comprehensive deployment configurations and strategies for EdTech microservices**

## 🎯 Deployment Strategy Overview

This guide provides complete deployment configurations for various Kubernetes deployment patterns, specifically tailored for EdTech platforms and microservices architecture.

## 🚀 Rolling Update Deployments

### Standard API Service Deployment

```yaml
# user-service-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: user-service
  namespace: production
  labels:
    app: user-service
    component: backend
    tier: api
    version: v1.3.0
  annotations:
    deployment.kubernetes.io/revision: "3"
    changelog: "Added OAuth2 integration and enhanced user profiles"
spec:
  replicas: 5
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
      maxSurge: 2
  selector:
    matchLabels:
      app: user-service
  template:
    metadata:
      labels:
        app: user-service
        version: v1.3.0
        tier: api
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "9090"
        prometheus.io/path: "/metrics"
    spec:
      serviceAccountName: user-service-sa
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 1000
      
      # Init container for database migrations
      initContainers:
      - name: db-migration
        image: edtech/user-service-migrations:v1.3.0
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: database-secret
              key: url
        command: ['npm', 'run', 'migrate']
      
      containers:
      - name: user-service
        image: edtech/user-service:v1.3.0
        imagePullPolicy: Always
        ports:
        - containerPort: 3000
          name: http
          protocol: TCP
        - containerPort: 9090
          name: metrics
          protocol: TCP
        
        env:
        - name: NODE_ENV
          value: "production"
        - name: PORT
          value: "3000"
        - name: METRICS_PORT
          value: "9090"
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: database-secret
              key: url
        - name: REDIS_URL
          valueFrom:
            secretKeyRef:
              name: redis-secret
              key: url
        - name: JWT_SECRET
          valueFrom:
            secretKeyRef:
              name: jwt-secret
              key: secret
        - name: OAUTH_CLIENT_ID
          valueFrom:
            secretKeyRef:
              name: oauth-secret
              key: client-id
        - name: OAUTH_CLIENT_SECRET
          valueFrom:
            secretKeyRef:
              name: oauth-secret
              key: client-secret
        
        resources:
          requests:
            cpu: 200m
            memory: 256Mi
          limits:
            cpu: 1000m
            memory: 512Mi
        
        livenessProbe:
          httpGet:
            path: /health/live
            port: 3000
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        
        readinessProbe:
          httpGet:
            path: /health/ready
            port: 3000
          initialDelaySeconds: 10
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 3
        
        startupProbe:
          httpGet:
            path: /health/startup
            port: 3000
          initialDelaySeconds: 10
          periodSeconds: 10
          failureThreshold: 30
        
        # Graceful shutdown
        lifecycle:
          preStop:
            exec:
              command: ["/bin/sh", "-c", "sleep 15"]
        
        # Security context
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - ALL
        
        # Volume mounts for tmp and cache
        volumeMounts:
        - name: tmp-volume
          mountPath: /tmp
        - name: cache-volume
          mountPath: /app/cache
        - name: config-volume
          mountPath: /app/config
          readOnly: true
      
      volumes:
      - name: tmp-volume
        emptyDir: {}
      - name: cache-volume
        emptyDir:
          sizeLimit: 100Mi
      - name: config-volume
        configMap:
          name: user-service-config
      
      # Pod disruption budget
      terminationGracePeriodSeconds: 30
      
      # Node affinity for better distribution
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values: [user-service]
              topologyKey: kubernetes.io/hostname

---
# Service configuration
apiVersion: v1
kind: Service
metadata:
  name: user-service
  namespace: production
  labels:
    app: user-service
    tier: api
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: nlb
spec:
  type: ClusterIP
  selector:
    app: user-service
  ports:
  - port: 80
    targetPort: 3000
    protocol: TCP
    name: http
  - port: 9090
    targetPort: 9090
    protocol: TCP
    name: metrics

---
# HPA configuration
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: user-service-hpa
  namespace: production
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: user-service
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
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 10
        periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
      - type: Percent
        value: 50
        periodSeconds: 60

---
# Pod Disruption Budget
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: user-service-pdb
  namespace: production
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: user-service
```

## 🔄 Blue-Green Deployment Configuration

### Complete Blue-Green Setup

```yaml
# blue-green-deployments.yaml

# Blue Deployment (Current Stable)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: exam-service-blue
  namespace: production
  labels:
    app: exam-service
    version: blue
    deployment-strategy: blue-green
spec:
  replicas: 5
  selector:
    matchLabels:
      app: exam-service
      version: blue
  template:
    metadata:
      labels:
        app: exam-service
        version: blue
        tier: api
    spec:
      containers:
      - name: exam-service
        image: edtech/exam-service:v2.1.0  # Current stable version
        ports:
        - containerPort: 3001
          name: http
        env:
        - name: ENVIRONMENT
          value: production-blue
        - name: VERSION
          value: v2.1.0
        resources:
          requests:
            cpu: 300m
            memory: 512Mi
          limits:
            cpu: 1500m
            memory: 2Gi
        livenessProbe:
          httpGet:
            path: /health/live
            port: 3001
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health/ready
            port: 3001
          initialDelaySeconds: 10
          periodSeconds: 5

---
# Green Deployment (New Version)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: exam-service-green
  namespace: production
  labels:
    app: exam-service
    version: green
    deployment-strategy: blue-green
spec:
  replicas: 5
  selector:
    matchLabels:
      app: exam-service
      version: green
  template:
    metadata:
      labels:
        app: exam-service
        version: green
        tier: api
    spec:
      containers:
      - name: exam-service
        image: edtech/exam-service:v2.2.0  # New version to deploy
        ports:
        - containerPort: 3001
          name: http
        env:
        - name: ENVIRONMENT
          value: production-green
        - name: VERSION
          value: v2.2.0
        - name: FEATURE_ADVANCED_ANALYTICS
          value: "true"
        resources:
          requests:
            cpu: 300m
            memory: 512Mi
          limits:
            cpu: 1500m
            memory: 2Gi
        livenessProbe:
          httpGet:
            path: /health/live
            port: 3001
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health/ready
            port: 3001
          initialDelaySeconds: 10
          periodSeconds: 5

---
# Main Service (Traffic Router)
apiVersion: v1
kind: Service
metadata:
  name: exam-service
  namespace: production
  labels:
    app: exam-service
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: nlb
spec:
  type: ClusterIP
  selector:
    app: exam-service
    version: blue  # Initially points to blue deployment
  ports:
  - port: 80
    targetPort: 3001
    protocol: TCP
    name: http

---
# Blue Service (Direct Access)
apiVersion: v1
kind: Service
metadata:
  name: exam-service-blue
  namespace: production
  labels:
    app: exam-service
    version: blue
spec:
  type: ClusterIP
  selector:
    app: exam-service
    version: blue
  ports:
  - port: 80
    targetPort: 3001
    protocol: TCP
    name: http

---
# Green Service (Direct Access)
apiVersion: v1
kind: Service
metadata:
  name: exam-service-green
  namespace: production
  labels:
    app: exam-service
    version: green
spec:
  type: ClusterIP
  selector:
    app: exam-service
    version: green
  ports:
  - port: 80
    targetPort: 3001
    protocol: TCP
    name: http
```

### Blue-Green Deployment Automation Script

```bash
#!/bin/bash
# blue-green-automated-deploy.sh

set -euo pipefail

# Configuration
NAMESPACE="${NAMESPACE:-production}"
APP_NAME="${APP_NAME:-exam-service}"
NEW_VERSION="$1"
HEALTH_CHECK_TIMEOUT="${HEALTH_CHECK_TIMEOUT:-300}"
SMOKE_TEST_ENABLED="${SMOKE_TEST_ENABLED:-true}"

# Validation
if [[ -z "$NEW_VERSION" ]]; then
    echo "❌ Usage: $0 <new-version>"
    echo "   Example: $0 v2.2.0"
    exit 1
fi

# Functions
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

cleanup() {
    if [[ -n "${CLEANUP_PID:-}" ]]; then
        kill "$CLEANUP_PID" 2>/dev/null || true
    fi
}
trap cleanup EXIT

get_current_color() {
    kubectl get service "$APP_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.selector.version}' 2>/dev/null || echo "blue"
}

wait_for_deployment() {
    local deployment="$1"
    local timeout="$2"
    
    log "⏳ Waiting for deployment $deployment to be ready..."
    if kubectl rollout status "deployment/$deployment" -n "$NAMESPACE" --timeout="${timeout}s"; then
        log "✅ Deployment $deployment is ready"
        return 0
    else
        log "❌ Deployment $deployment failed to become ready within ${timeout}s"
        return 1
    fi
}

run_health_checks() {
    local service_name="$1"
    local max_attempts=10
    local attempt=1
    
    log "🏥 Running health checks for $service_name..."
    
    # Get service endpoint
    local service_ip=$(kubectl get service "$service_name" -n "$NAMESPACE" -o jsonpath='{.spec.clusterIP}')
    local service_port=$(kubectl get service "$service_name" -n "$NAMESPACE" -o jsonpath='{.spec.ports[0].port}')
    
    # Port forward for testing
    kubectl port-forward "service/$service_name" 8080:80 -n "$NAMESPACE" >/dev/null 2>&1 &
    local port_forward_pid=$!
    sleep 5
    
    while [[ $attempt -le $max_attempts ]]; do
        if curl -f --max-time 10 "http://localhost:8080/health/ready" >/dev/null 2>&1; then
            log "✅ Health check passed (attempt $attempt/$max_attempts)"
            kill $port_forward_pid 2>/dev/null || true
            return 0
        else
            log "⚠️  Health check failed (attempt $attempt/$max_attempts)"
            sleep 10
            ((attempt++))
        fi
    done
    
    kill $port_forward_pid 2>/dev/null || true
    log "❌ Health checks failed after $max_attempts attempts"
    return 1
}

run_smoke_tests() {
    local service_name="$1"
    
    if [[ "$SMOKE_TEST_ENABLED" != "true" ]]; then
        log "ℹ️  Smoke tests disabled, skipping..."
        return 0
    fi
    
    log "🧪 Running smoke tests for $service_name..."
    
    # Port forward for testing
    kubectl port-forward "service/$service_name" 8081:80 -n "$NAMESPACE" >/dev/null 2>&1 &
    local port_forward_pid=$!
    sleep 5
    
    # Basic functionality tests
    local test_results=()
    
    # Test 1: Version endpoint
    if curl -f --max-time 10 "http://localhost:8081/version" | grep -q "$NEW_VERSION"; then
        test_results+=("✅ Version test passed")
    else
        test_results+=("❌ Version test failed")
    fi
    
    # Test 2: API health
    if curl -f --max-time 10 "http://localhost:8081/api/exams/health" >/dev/null 2>&1; then
        test_results+=("✅ API health test passed")
    else
        test_results+=("❌ API health test failed")
    fi
    
    # Test 3: Database connectivity
    if curl -f --max-time 10 "http://localhost:8081/health/db" >/dev/null 2>&1; then
        test_results+=("✅ Database connectivity test passed")
    else
        test_results+=("❌ Database connectivity test failed")
    fi
    
    kill $port_forward_pid 2>/dev/null || true
    
    # Evaluate results
    local failed_tests=0
    for result in "${test_results[@]}"; do
        log "   $result"
        if [[ "$result" == *"❌"* ]]; then
            ((failed_tests++))
        fi
    done
    
    if [[ $failed_tests -eq 0 ]]; then
        log "✅ All smoke tests passed"
        return 0
    else
        log "❌ $failed_tests smoke test(s) failed"
        return 1
    fi
}

rollback_deployment() {
    local failed_color="$1"
    local stable_color="$2"
    
    log "🔄 Rolling back deployment..."
    
    # Switch service back to stable deployment
    kubectl patch service "$APP_NAME" -n "$NAMESPACE" \
        -p "{\"spec\":{\"selector\":{\"version\":\"$stable_color\"}}}"
    
    # Scale down failed deployment
    kubectl scale deployment "${APP_NAME}-${failed_color}" --replicas=0 -n "$NAMESPACE"
    
    log "✅ Rollback completed. Traffic restored to $stable_color deployment"
}

# Main deployment logic
main() {
    log "🚀 Starting blue-green deployment for $APP_NAME:$NEW_VERSION"
    
    # Determine current and target colors
    CURRENT_COLOR=$(get_current_color)
    TARGET_COLOR=$([[ "$CURRENT_COLOR" == "blue" ]] && echo "green" || echo "blue")
    
    log "📋 Current deployment: $CURRENT_COLOR | Target deployment: $TARGET_COLOR"
    
    # Scale up target deployment if it's scaled down
    local current_replicas=$(kubectl get deployment "${APP_NAME}-${TARGET_COLOR}" -n "$NAMESPACE" -o jsonpath='{.spec.replicas}')
    if [[ "$current_replicas" -eq 0 ]]; then
        log "📈 Scaling up $TARGET_COLOR deployment..."
        kubectl scale deployment "${APP_NAME}-${TARGET_COLOR}" --replicas=5 -n "$NAMESPACE"
    fi
    
    # Update target deployment with new image
    log "📦 Deploying $NEW_VERSION to $TARGET_COLOR environment..."
    kubectl patch deployment "${APP_NAME}-${TARGET_COLOR}" -n "$NAMESPACE" \
        -p "{\"spec\":{\"template\":{\"spec\":{\"containers\":[{\"name\":\"${APP_NAME}\",\"image\":\"edtech/${APP_NAME}:${NEW_VERSION}\"}]}}}}"
    
    # Wait for rollout to complete
    if ! wait_for_deployment "${APP_NAME}-${TARGET_COLOR}" "$HEALTH_CHECK_TIMEOUT"; then
        log "❌ Deployment failed. Keeping current $CURRENT_COLOR deployment active."
        exit 1
    fi
    
    # Run health checks on target deployment
    if ! run_health_checks "${APP_NAME}-${TARGET_COLOR}"; then
        log "❌ Health checks failed. Keeping current $CURRENT_COLOR deployment active."
        kubectl rollout undo "deployment/${APP_NAME}-${TARGET_COLOR}" -n "$NAMESPACE"
        exit 1
    fi
    
    # Run smoke tests
    if ! run_smoke_tests "${APP_NAME}-${TARGET_COLOR}"; then
        log "❌ Smoke tests failed. Keeping current $CURRENT_COLOR deployment active."
        kubectl rollout undo "deployment/${APP_NAME}-${TARGET_COLOR}" -n "$NAMESPACE"
        exit 1
    fi
    
    # Switch traffic to target deployment
    log "🔄 Switching traffic from $CURRENT_COLOR to $TARGET_COLOR..."
    kubectl patch service "$APP_NAME" -n "$NAMESPACE" \
        -p "{\"spec\":{\"selector\":{\"version\":\"$TARGET_COLOR\"}}}"
    
    # Wait a bit to ensure traffic is properly routed
    sleep 10
    
    # Final verification
    if run_health_checks "$APP_NAME"; then
        log "✅ Deployment completed successfully!"
        log "📝 Traffic is now served by $TARGET_COLOR deployment ($NEW_VERSION)"
        log "🔄 Rollback command: kubectl patch service $APP_NAME -n $NAMESPACE -p '{\"spec\":{\"selector\":{\"version\":\"$CURRENT_COLOR\"}}}'"
        
        # Scale down old deployment (optional)
        read -p "Scale down $CURRENT_COLOR deployment? (y/N): " -r
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            kubectl scale deployment "${APP_NAME}-${CURRENT_COLOR}" --replicas=0 -n "$NAMESPACE"
            log "📉 Scaled down $CURRENT_COLOR deployment"
        fi
    else
        log "❌ Final verification failed. Rolling back..."
        rollback_deployment "$TARGET_COLOR" "$CURRENT_COLOR"
        exit 1
    fi
}

# Run main function
main "$@"
```

## 🎯 Canary Deployment Configuration

### Argo Rollouts Canary Deployment

```yaml
# canary-rollout.yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: notification-service-canary
  namespace: production
  labels:
    app: notification-service
    deployment-strategy: canary
spec:
  replicas: 10
  strategy:
    canary:
      # Canary service for receiving subset of traffic
      canaryService: notification-service-canary
      # Stable service for receiving majority of traffic
      stableService: notification-service-stable
      
      # Traffic routing using NGINX Ingress
      trafficRouting:
        nginx:
          stableIngress: notification-service-ingress
          annotationPrefix: nginx.ingress.kubernetes.io
          additionalIngressAnnotations:
            canary-by-header: X-Canary
            canary-by-header-value: always
      
      # Progressive traffic shifting
      steps:
      - setWeight: 5
      - pause: {duration: 2m}
      - setWeight: 10
      - pause: {duration: 5m}
      - setWeight: 20
      - pause: {duration: 10m}
      - setWeight: 40
      - pause: {duration: 10m}  
      - setWeight: 60
      - pause: {duration: 10m}
      - setWeight: 80
      - pause: {duration: 10m}
      - setWeight: 100
      
      # Automated analysis for decision making
      analysis:
        templates:
        - templateName: success-rate
        - templateName: latency
        startingStep: 2  # Start analysis at 10% traffic
        args:
        - name: service-name
          value: notification-service-canary.production.svc.cluster.local
        - name: prometheus-server
          value: http://prometheus-server.monitoring.svc.cluster.local:80
      
      # Anti-affinity for better distribution
      antiAffinity:
        requiredDuringSchedulingIgnoredDuringExecution: {}
        preferredDuringSchedulingIgnoredDuringExecution:
          weight: 1
  
  selector:
    matchLabels:
      app: notification-service
  
  template:
    metadata:
      labels:
        app: notification-service
    spec:
      containers:
      - name: notification-service
        image: edtech/notification-service:v1.4.0
        ports:
        - containerPort: 3002
          name: http
        env:
        - name: ENVIRONMENT
          value: production
        - name: CANARY_ENABLED
          value: "true"
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 256Mi
        livenessProbe:
          httpGet:
            path: /health/live
            port: 3002
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health/ready
            port: 3002
          initialDelaySeconds: 10
          periodSeconds: 5

---
# Analysis Templates
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: success-rate
  namespace: production
spec:
  args:
  - name: service-name
  - name: prometheus-server
  metrics:
  - name: success-rate
    successCondition: result[0] >= 0.95
    interval: 30s
    count: 5
    failureLimit: 3
    provider:
      prometheus:
        address: "{{args.prometheus-server}}"
        query: |
          sum(irate(
            http_requests_total{job="{{args.service-name}}",status!~"5.."}[2m]
          )) / 
          sum(irate(
            http_requests_total{job="{{args.service-name}}"}[2m]
          ))

---
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: latency
  namespace: production
spec:
  args:
  - name: service-name
  - name: prometheus-server
  metrics:
  - name: latency
    successCondition: result[0] <= 0.5
    interval: 30s
    count: 5
    failureLimit: 3
    provider:
      prometheus:
        address: "{{args.prometheus-server}}"
        query: |
          histogram_quantile(0.95,
            sum(rate(
              http_request_duration_seconds_bucket{job="{{args.service-name}}"}[2m]
            )) by (le)
          )

---
# Stable Service
apiVersion: v1
kind: Service
metadata:
  name: notification-service-stable
  namespace: production
spec:
  type: ClusterIP
  selector:
    app: notification-service
  ports:
  - port: 80
    targetPort: 3002
    protocol: TCP
    name: http

---
# Canary Service
apiVersion: v1
kind: Service
metadata:
  name: notification-service-canary
  namespace: production
spec:
  type: ClusterIP
  selector:
    app: notification-service
  ports:
  - port: 80
    targetPort: 3002
    protocol: TCP
    name: http

---
# Ingress for traffic splitting
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: notification-service-ingress
  namespace: production
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  tls:
  - hosts:
    - api.edtech-platform.com
    secretName: api-tls-secret
  rules:
  - host: api.edtech-platform.com
    http:
      paths:
      - path: /api/notifications
        pathType: Prefix
        backend:
          service:
            name: notification-service-stable
            port:
              number: 80
```

## 🔄 Multi-Environment Deployment Pipeline

### GitOps Pipeline Configuration

```yaml
# argocd-applications.yaml

# Development Environment
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: edtech-dev
  namespace: argocd
  labels:
    environment: dev
spec:
  project: edtech
  source:
    repoURL: https://github.com/edtech/k8s-manifests
    targetRevision: develop
    path: environments/dev
    helm:
      valueFiles:
      - values-dev.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: development
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
    retry:
      limit: 5

---
# Staging Environment
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: edtech-staging
  namespace: argocd
  labels:
    environment: staging
spec:
  project: edtech
  source:
    repoURL: https://github.com/edtech/k8s-manifests
    targetRevision: main
    path: environments/staging
    helm:
      valueFiles:
      - values-staging.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: staging
  syncPolicy:
    automated:
      prune: false  # Manual approval for staging
      selfHeal: true
    syncOptions:
    - CreateNamespace=true

---
# Production Environment
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: edtech-production
  namespace: argocd
  labels:
    environment: production
spec:
  project: edtech
  source:
    repoURL: https://github.com/edtech/k8s-manifests
    targetRevision: release
    path: environments/production
    helm:
      valueFiles:
      - values-production.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: production
  syncPolicy:
    syncOptions:
    - CreateNamespace=true
    # No automated sync for production - manual deployment only
```

### Environment-Specific Configurations

```yaml
# values-dev.yaml
global:
  environment: development
  imageTag: latest
  replicas: 1
  resources:
    requests:
      cpu: 50m
      memory: 64Mi
    limits:
      cpu: 200m
      memory: 128Mi

autoscaling:
  enabled: false

monitoring:
  enabled: true
  retention: 7d

security:
  networkPolicies: false
  podSecurityPolicy: false

database:
  host: postgres-dev.development.svc.cluster.local
  name: edtech_dev

redis:
  host: redis-dev.development.svc.cluster.local

---
# values-staging.yaml
global:
  environment: staging
  imageTag: stable
  replicas: 2
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 500m
      memory: 256Mi

autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10

monitoring:
  enabled: true
  retention: 30d

security:
  networkPolicies: true
  podSecurityPolicy: true

database:
  host: postgres-staging.staging.svc.cluster.local
  name: edtech_staging

redis:
  host: redis-staging.staging.svc.cluster.local

---
# values-production.yaml
global:
  environment: production
  imageTag: v1.3.0
  replicas: 5
  resources:
    requests:
      cpu: 200m
      memory: 256Mi
    limits:
      cpu: 1000m
      memory: 512Mi

autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 50

monitoring:
  enabled: true
  retention: 90d
  alertmanager:
    enabled: true

security:
  networkPolicies: true
  podSecurityPolicy: true
  imagePullSecrets: true

database:
  host: postgres-production.production.svc.cluster.local
  name: edtech_production
  ssl: true
  connectionPooling: true

redis:
  host: redis-production.production.svc.cluster.local
  sentinel: true
  clustering: true

backup:
  enabled: true
  schedule: "0 2 * * *"
  retention: 30d
```

## 🔄 Database Migration Deployment

### StatefulSet with Rolling Updates

```yaml
# database-deployment.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres-primary
  namespace: production
spec:
  serviceName: postgres-primary
  replicas: 1
  updateStrategy:
    type: RollingUpdate
    rollingUpdate:
      partition: 0
  selector:
    matchLabels:
      app: postgres-primary
      role: primary
  template:
    metadata:
      labels:
        app: postgres-primary
        role: primary
    spec:
      securityContext:
        runAsUser: 999
        runAsGroup: 999
        fsGroup: 999
      containers:
      - name: postgres
        image: postgres:15.4-alpine
        env:
        - name: POSTGRES_DB
          value: edtech_production
        - name: POSTGRES_USER
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: username
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: password
        - name: PGDATA
          value: /var/lib/postgresql/data/pgdata
        ports:
        - containerPort: 5432
          name: postgres
        volumeMounts:
        - name: postgres-storage
          mountPath: /var/lib/postgresql/data
        - name: postgres-config
          mountPath: /etc/postgresql/postgresql.conf
          subPath: postgresql.conf
        resources:
          requests:
            cpu: 500m
            memory: 1Gi
          limits:
            cpu: 2000m
            memory: 4Gi
        livenessProbe:
          exec:
            command:
            - sh
            - -c
            - pg_isready -U $POSTGRES_USER -d $POSTGRES_DB
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          exec:
            command:
            - sh
            - -c
            - pg_isready -U $POSTGRES_USER -d $POSTGRES_DB
          initialDelaySeconds: 5
          periodSeconds: 5
      
      volumes:
      - name: postgres-config
        configMap:
          name: postgres-config
  
  volumeClaimTemplates:
  - metadata:
      name: postgres-storage
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: fast-ssd
      resources:
        requests:
          storage: 100Gi

---
# Migration Job
apiVersion: batch/v1
kind: Job
metadata:
  name: db-migration-v1-3-0
  namespace: production
  labels:
    app: db-migration
    version: v1.3.0
spec:
  template:
    metadata:
      labels:
        app: db-migration
        version: v1.3.0
    spec:
      restartPolicy: OnFailure
      containers:
      - name: migrate
        image: edtech/migrations:v1.3.0
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: url
        - name: MIGRATION_VERSION
          value: "v1.3.0"
        command: ['npm', 'run', 'migrate:up']
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 256Mi
  backoffLimit: 3
  ttlSecondsAfterFinished: 86400  # Clean up after 24 hours
```

## 🔗 Next Steps

Continue with specialized deployment configurations:
- [Performance Analysis](./performance-analysis.md) - Performance optimization and monitoring
- [Security Considerations](./security-considerations.md) - Advanced security patterns  
- [Troubleshooting](./troubleshooting.md) - Common deployment issues and solutions

---

### 🔗 Navigation
- [← Back to Main Research](./README.md)
- [← Previous: Best Practices](./best-practices.md)
- [Next: Performance Analysis →](./performance-analysis.md)