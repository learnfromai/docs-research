# Service Mesh Implementation Guide: Step-by-Step Setup

## 🎯 Implementation Overview

This comprehensive guide provides step-by-step instructions for implementing service mesh solutions in production environments, with specific focus on EdTech platforms and best practices for Philippine developers building scalable applications.

## 🏗️ Pre-Implementation Planning

### Infrastructure Requirements Assessment

```yaml
# Minimum Infrastructure Requirements
kubernetes_cluster:
  nodes: "3+ nodes (production)"
  cpu_per_node: "4+ cores"
  memory_per_node: "8GB+"
  storage: "50GB+ SSD per node"
  kubernetes_version: "v1.24+"

networking:
  cni: "Calico, Flannel, or Weave"
  load_balancer: "Cloud LB or MetalLB"
  ingress_controller: "Optional but recommended"

observability_prerequisites:
  prometheus: "For metrics collection"
  grafana: "For visualization"
  jaeger_or_zipkin: "For distributed tracing"

security_requirements:
  rbac: "Enabled and configured"
  network_policies: "Basic policies in place"
  secrets_management: "Kubernetes secrets or external"
```

### Team Readiness Checklist

```yaml
# Skills Assessment
required_skills:
  kubernetes_fundamentals:
    - "Pod, Service, Deployment concepts"
    - "YAML configuration management"
    - "kubectl command proficiency"
    - "Troubleshooting basics"
  
  networking_knowledge:
    - "DNS and service discovery"
    - "Load balancing concepts"
    - "HTTP/HTTPS protocols"
    - "Certificate management"
  
  observability_basics:
    - "Metrics and monitoring"
    - "Log aggregation"
    - "Distributed tracing concepts"

# Training Plan (4-6 weeks)
training_roadmap:
  week_1_2: "Kubernetes fundamentals review"
  week_3_4: "Service mesh concepts and theory"
  week_5_6: "Hands-on implementation practice"
```

## 🚀 Linkerd Implementation (Recommended for Most Cases)

### Phase 1: Linkerd Installation

#### Step 1: Environment Preparation

```bash
# Verify Kubernetes cluster
kubectl cluster-info
kubectl get nodes

# Install Linkerd CLI
curl --proto '=https' --tlsv1.2 -sSfL https://run.linkerd.io/install | sh
export PATH=$PATH:$HOME/.linkerd2/bin

# Verify CLI installation
linkerd version
```

#### Step 2: Pre-Installation Checks

```bash
# Run pre-installation checks
linkerd check --pre

# Expected output should show all checks passing
# If any checks fail, address them before proceeding
```

#### Step 3: Install Linkerd Control Plane

```bash
# Generate and apply Linkerd CRDs
linkerd install --crds | kubectl apply -f -

# Install Linkerd control plane
linkerd install | kubectl apply -f -

# Wait for control plane to be ready
kubectl -n linkerd wait --for=condition=available --timeout=300s deployment/linkerd-controller-api
kubectl -n linkerd wait --for=condition=available --timeout=300s deployment/linkerd-destination
kubectl -n linkerd wait --for=condition=available --timeout=300s deployment/linkerd-identity
kubectl -n linkerd wait --for=condition=available --timeout=300s deployment/linkerd-proxy-injector

# Verify installation
linkerd check
```

#### Step 4: Install Observability Components

```bash
# Install Linkerd Viz extension
linkerd viz install | kubectl apply -f -

# Wait for viz components to be ready
kubectl -n linkerd-viz wait --for=condition=available --timeout=300s deployment/metrics-api
kubectl -n linkerd-viz wait --for=condition=available --timeout=300s deployment/prometheus
kubectl -n linkerd-viz wait --for=condition=available --timeout=300s deployment/web

# Verify viz installation
linkerd viz check

# Access dashboard (optional)
linkerd viz dashboard &
```

### Phase 2: Service Onboarding

#### Step 1: Prepare Application Namespaces

```bash
# Create namespace for EdTech application
kubectl create namespace edtech-production

# Enable automatic sidecar injection
kubectl annotate namespace edtech-production linkerd.io/inject=enabled

# Verify namespace annotation
kubectl get namespace edtech-production -o yaml | grep linkerd.io/inject
```

#### Step 2: Deploy Sample EdTech Services

```yaml
# user-service.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: user-service
  namespace: edtech-production
spec:
  replicas: 2
  selector:
    matchLabels:
      app: user-service
  template:
    metadata:
      labels:
        app: user-service
        version: v1
    spec:
      containers:
      - name: user-service
        image: nginx:1.21
        ports:
        - containerPort: 80
        env:
        - name: SERVICE_NAME
          value: "user-service"
---
apiVersion: v1
kind: Service
metadata:
  name: user-service
  namespace: edtech-production
spec:
  selector:
    app: user-service
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP

---
# exam-service.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: exam-service
  namespace: edtech-production
spec:
  replicas: 3
  selector:
    matchLabels:
      app: exam-service
  template:
    metadata:
      labels:
        app: exam-service
        version: v1
    spec:
      containers:
      - name: exam-service
        image: nginx:1.21
        ports:
        - containerPort: 80
        env:
        - name: SERVICE_NAME
          value: "exam-service"
---
apiVersion: v1
kind: Service
metadata:
  name: exam-service
  namespace: edtech-production
spec:
  selector:
    app: exam-service
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP

---
# content-service.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: content-service
  namespace: edtech-production
spec:
  replicas: 2
  selector:
    matchLabels:
      app: content-service
  template:
    metadata:
      labels:
        app: content-service
        version: v1
    spec:
      containers:
      - name: content-service
        image: nginx:1.21
        ports:
        - containerPort: 80
        env:
        - name: SERVICE_NAME
          value: "content-service"
---
apiVersion: v1
kind: Service
metadata:
  name: content-service
  namespace: edtech-production
spec:
  selector:
    app: content-service
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
```

```bash
# Apply the services
kubectl apply -f user-service.yaml
kubectl apply -f exam-service.yaml
kubectl apply -f content-service.yaml

# Verify services are running with Linkerd proxies
kubectl get pods -n edtech-production
# Each pod should show 2/2 containers (app + linkerd-proxy)

# Check proxy injection
linkerd viz stat deployment -n edtech-production
```

#### Step 3: Configure Service Profiles

```yaml
# user-service-profile.yaml
apiVersion: linkerd.io/v1alpha2
kind: ServiceProfile
metadata:
  name: user-service
  namespace: edtech-production
spec:
  routes:
  - name: get_user_profile
    condition:
      method: GET
      pathRegex: /api/v1/users/[^/]+
    responseClasses:
    - condition:
        status:
          min: 200
          max: 299
      isFailure: false
    - condition:
        status:
          min: 500
          max: 599
      isFailure: true
    timeout: 5s
    
  - name: update_user_profile
    condition:
      method: PUT
      pathRegex: /api/v1/users/[^/]+
    timeout: 10s
    retryBudget:
      retryRatio: 0.2
      minRetriesPerSecond: 10
      ttl: 10s

---
# exam-service-profile.yaml
apiVersion: linkerd.io/v1alpha2
kind: ServiceProfile
metadata:
  name: exam-service
  namespace: edtech-production
spec:
  routes:
  - name: get_exam_questions
    condition:
      method: GET
      pathRegex: /api/v1/exams/[^/]+/questions
    responseClasses:
    - condition:
        status:
          min: 200
          max: 299
      isFailure: false
    timeout: 3s
    retryBudget:
      retryRatio: 0.1
      minRetriesPerSecond: 5
      ttl: 5s
  
  - name: submit_exam_answers
    condition:
      method: POST
      pathRegex: /api/v1/exams/[^/]+/submit
    timeout: 30s
    # No retries for exam submissions to prevent duplicates
```

```bash
# Apply service profiles
kubectl apply -f user-service-profile.yaml
kubectl apply -f exam-service-profile.yaml

# Verify service profiles
linkerd viz routes deployment/user-service -n edtech-production
linkerd viz routes deployment/exam-service -n edtech-production
```

### Phase 3: Traffic Management Setup

#### Step 1: Implement Canary Deployments

```yaml
# exam-service-canary.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: exam-service-v2
  namespace: edtech-production
spec:
  replicas: 1
  selector:
    matchLabels:
      app: exam-service
      version: v2
  template:
    metadata:
      labels:
        app: exam-service
        version: v2
    spec:
      containers:
      - name: exam-service
        image: nginx:1.22  # New version
        ports:
        - containerPort: 80
        env:
        - name: SERVICE_NAME
          value: "exam-service-v2"

---
apiVersion: v1
kind: Service
metadata:
  name: exam-service-v2
  namespace: edtech-production
spec:
  selector:
    app: exam-service
    version: v2
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP

---
# Traffic Split for Canary Deployment
apiVersion: split.smi-spec.io/v1alpha1
kind: TrafficSplit
metadata:
  name: exam-service-canary
  namespace: edtech-production
spec:
  service: exam-service
  backends:
  - service: exam-service
    weight: 90  # 90% to stable version
  - service: exam-service-v2
    weight: 10  # 10% to canary version
```

```bash
# Apply canary deployment
kubectl apply -f exam-service-canary.yaml

# Monitor canary deployment
linkerd viz stat trafficsplit -n edtech-production
linkerd viz top deployment/exam-service-v2 -n edtech-production

# Gradually increase canary traffic (if successful)
kubectl patch trafficsplit exam-service-canary -n edtech-production --type='merge' -p='{"spec":{"backends":[{"service":"exam-service","weight":70},{"service":"exam-service-v2","weight":30}]}}'
```

#### Step 2: Security Policy Implementation

```yaml
# server-authorization.yaml
apiVersion: policy.linkerd.io/v1beta1
kind: Server
metadata:
  name: exam-api-server
  namespace: edtech-production
spec:
  podSelector:
    matchLabels:
      app: exam-service
  port: 80
  proxyProtocol: HTTP/1.1

---
apiVersion: policy.linkerd.io/v1beta1
kind: ServerAuthorization
metadata:
  name: exam-api-authz
  namespace: edtech-production
spec:
  server:
    name: exam-api-server
  client:
    meshTLS:
      serviceAccounts:
      - name: default  # Allow default service account for demo
      # In production, use specific service accounts

---
# user-service-server.yaml
apiVersion: policy.linkerd.io/v1beta1
kind: Server
metadata:
  name: user-api-server
  namespace: edtech-production
spec:
  podSelector:
    matchLabels:
      app: user-service
  port: 80
  proxyProtocol: HTTP/1.1

---
apiVersion: policy.linkerd.io/v1beta1
kind: ServerAuthorization
metadata:
  name: user-api-authz
  namespace: edtech-production
spec:
  server:
    name: user-api-server
  client:
    meshTLS:
      serviceAccounts:
      - name: default
```

```bash
# Apply security policies
kubectl apply -f server-authorization.yaml
kubectl apply -f user-service-server.yaml

# Verify mTLS is working
linkerd viz edges -n edtech-production
# Should show locks (🔒) indicating mTLS connections
```

## 🏢 Istio Implementation (For Complex Requirements)

### Phase 1: Istio Installation

#### Step 1: Install Istio CLI

```bash
# Download and install Istio
curl -L https://istio.io/downloadIstio | sh -
cd istio-1.20.0
export PATH=$PWD/bin:$PATH

# Verify installation
istioctl version
```

#### Step 2: Install Istio Control Plane

```bash
# Pre-installation check
istioctl x precheck

# Install Istio with production profile
istioctl install --set values.defaultRevision=default

# Verify installation
istioctl verify-install

# Enable sidecar injection for namespace
kubectl label namespace edtech-production istio-injection=enabled
```

#### Step 3: Install Observability Addons

```bash
# Install observability components
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/prometheus.yaml
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/grafana.yaml
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/jaeger.yaml
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/kiali.yaml

# Wait for components to be ready
kubectl rollout status deployment/prometheus -n istio-system
kubectl rollout status deployment/grafana -n istio-system
kubectl rollout status deployment/jaeger -n istio-system
kubectl rollout status deployment/kiali -n istio-system
```

### Phase 2: Gateway and Virtual Service Configuration

#### Step 1: Configure Istio Gateway

```yaml
# istio-gateway.yaml
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: edtech-gateway
  namespace: edtech-production
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "edtech-platform.local"
    - "api.edtech-platform.local"
  - port:
      number: 443
      name: https
      protocol: HTTPS
    tls:
      mode: SIMPLE
      credentialName: edtech-tls-secret
    hosts:
    - "edtech-platform.local"
    - "api.edtech-platform.local"
```

#### Step 2: Configure Virtual Services

```yaml
# virtual-services.yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: edtech-platform
  namespace: edtech-production
spec:
  hosts:
  - "api.edtech-platform.local"
  gateways:
  - edtech-gateway
  http:
  # User service routes
  - match:
    - uri:
        prefix: /api/v1/users
    route:
    - destination:
        host: user-service
        port:
          number: 80
  
  # Exam service routes with canary
  - match:
    - uri:
        prefix: /api/v1/exams
    - headers:
        canary:
          exact: "true"
    route:
    - destination:
        host: exam-service
        subset: v2
  
  - match:
    - uri:
        prefix: /api/v1/exams
    route:
    - destination:
        host: exam-service
        subset: v1
      weight: 90
    - destination:
        host: exam-service
        subset: v2
      weight: 10
  
  # Content service routes
  - match:
    - uri:
        prefix: /api/v1/content
    route:
    - destination:
        host: content-service
        port:
          number: 80

---
# Destination Rules
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: exam-service-dr
  namespace: edtech-production
spec:
  host: exam-service
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 100
      http:
        http1MaxPendingRequests: 50
        maxRequestsPerConnection: 10
    loadBalancer:
      simple: LEAST_CONN
    outlierDetection:
      consecutiveGatewayErrors: 3
      interval: 30s
      baseEjectionTime: 30s
  subsets:
  - name: v1
    labels:
      version: v1
  - name: v2
    labels:
      version: v2
```

```bash
# Apply Istio configuration
kubectl apply -f istio-gateway.yaml
kubectl apply -f virtual-services.yaml

# Verify configuration
istioctl analyze -n edtech-production
```

## 📊 Monitoring and Observability Setup

### Comprehensive Monitoring Configuration

```yaml
# prometheus-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
  namespace: linkerd-viz
data:
  prometheus.yml: |
    global:
      scrape_interval: 30s
      evaluation_interval: 30s
    
    rule_files:
    - "/etc/prometheus/rules/*.yml"
    
    scrape_configs:
    - job_name: 'linkerd-controller'
      kubernetes_sd_configs:
      - role: pod
        namespaces:
          names: ['linkerd']
    
    - job_name: 'linkerd-proxy'
      kubernetes_sd_configs:
      - role: pod
      relabel_configs:
      - source_labels: [__meta_kubernetes_pod_container_name]
        action: keep
        regex: ^linkerd-proxy$

    - job_name: 'edtech-applications'
      kubernetes_sd_configs:
      - role: pod
        namespaces:
          names: ['edtech-production']

---
# alerting-rules.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-rules
  namespace: linkerd-viz
data:
  edtech.yml: |
    groups:
    - name: edtech.rules
      rules:
      - alert: ExamServiceHighLatency
        expr: histogram_quantile(0.99, rate(request_duration_ms_bucket{dst_service="exam-service"}[5m])) > 1000
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "Exam service experiencing high latency"
      
      - alert: UserServiceErrorRate
        expr: rate(request_total{dst_service="user-service",classification="failure"}[5m]) / rate(request_total{dst_service="user-service"}[5m]) > 0.05
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "User service error rate is high"
      
      - alert: ServiceMeshControlPlaneDown
        expr: up{job="linkerd-controller"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Service mesh control plane is down"
```

### Grafana Dashboard Configuration

```json
{
  "dashboard": {
    "title": "EdTech Platform Service Mesh Dashboard",
    "panels": [
      {
        "title": "Request Rate by Service",
        "type": "graph",
        "targets": [
          {
            "expr": "sum(rate(request_total[1m])) by (dst_service)",
            "legendFormat": "{{dst_service}}"
          }
        ]
      },
      {
        "title": "Success Rate",
        "type": "stat",
        "targets": [
          {
            "expr": "sum(rate(request_total{classification!=\"failure\"}[5m])) by (dst_service) / sum(rate(request_total[5m])) by (dst_service)"
          }
        ]
      },
      {
        "title": "P99 Latency by Service",
        "type": "graph",
        "targets": [
          {
            "expr": "histogram_quantile(0.99, sum(rate(request_duration_ms_bucket[5m])) by (dst_service, le))"
          }
        ]
      }
    ]
  }
}
```

## 🔧 Production Deployment Checklist

### Pre-Production Validation

```bash
#!/bin/bash
# production-readiness-check.sh

echo "🔍 Running Production Readiness Checks..."

# 1. Verify service mesh installation
echo "1. Checking service mesh installation..."
if command -v linkerd &> /dev/null; then
    linkerd check
elif command -v istioctl &> /dev/null; then
    istioctl verify-install
fi

# 2. Check certificate expiration
echo "2. Checking certificate expiration..."
if command -v linkerd &> /dev/null; then
    linkerd check --proxy
fi

# 3. Verify mTLS is enabled
echo "3. Verifying mTLS status..."
kubectl get pods -n edtech-production -o jsonpath='{.items[*].metadata.annotations.linkerd\.io/proxy-version}'

# 4. Check resource usage
echo "4. Checking resource usage..."
kubectl top pods -n linkerd
kubectl top pods -n edtech-production

# 5. Verify observability stack
echo "5. Checking observability stack..."
kubectl get pods -n linkerd-viz
kubectl get pods -n istio-system 2>/dev/null || echo "Istio not installed"

# 6. Test service connectivity
echo "6. Testing service connectivity..."
kubectl run test-pod --image=busybox --rm -it --restart=Never -- /bin/sh -c "
  nslookup user-service.edtech-production.svc.cluster.local &&
  nslookup exam-service.edtech-production.svc.cluster.local &&
  nslookup content-service.edtech-production.svc.cluster.local
"

echo "✅ Production readiness check completed!"
```

### Deployment Automation

```yaml
# deploy-pipeline.yaml (GitHub Actions)
name: Service Mesh Deployment
on:
  push:
    branches: [main]
    paths: ['k8s/**']

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    
    - name: Setup kubectl
      uses: azure/setup-kubectl@v3
      with:
        version: 'v1.28.0'
    
    - name: Configure kubeconfig
      run: |
        echo "${{ secrets.KUBECONFIG }}" | base64 -d > kubeconfig
        export KUBECONFIG=kubeconfig
    
    - name: Install Linkerd CLI
      run: |
        curl --proto '=https' --tlsv1.2 -sSfL https://run.linkerd.io/install | sh
        export PATH=$PATH:$HOME/.linkerd2/bin
    
    - name: Validate configurations
      run: |
        kubectl apply --dry-run=client -f k8s/
        linkerd inject k8s/ | kubectl apply --dry-run=client -f -
    
    - name: Deploy applications
      run: |
        kubectl apply -f k8s/
        kubectl rollout status deployment/user-service -n edtech-production
        kubectl rollout status deployment/exam-service -n edtech-production
    
    - name: Run health checks
      run: |
        linkerd check
        linkerd viz stat deployment -n edtech-production
    
    - name: Notify deployment status
      if: failure()
      uses: 8398a7/action-slack@v3
      with:
        status: failure
        webhook_url: ${{ secrets.SLACK_WEBHOOK }}
```

## 🚨 Troubleshooting Guide

### Common Issues and Solutions

```bash
# Issue 1: Sidecar injection not working
# Symptom: Pods show 1/1 containers instead of 2/2
# Solution:
kubectl get namespace edtech-production -o yaml | grep inject
kubectl annotate namespace edtech-production linkerd.io/inject=enabled --overwrite

# Issue 2: mTLS handshake failures
# Symptom: Connection refused errors between services
# Solution:
linkerd check --proxy
kubectl logs <pod-name> -c linkerd-proxy -n edtech-production

# Issue 3: High latency after service mesh installation
# Symptom: Increased response times
# Solution:
linkerd viz top deployment/exam-service -n edtech-production
kubectl describe serviceprofile exam-service -n edtech-production

# Issue 4: Control plane components not ready
# Symptom: Deployments stuck in pending state
# Solution:
kubectl get events -n linkerd --sort-by='.lastTimestamp'
kubectl describe pods -n linkerd

# Issue 5: Certificate expiration
# Symptom: mTLS failures and authentication errors
# Solution:
linkerd check --proxy
# Rotate certificates if needed
linkerd upgrade | kubectl apply -f -
```

### Performance Optimization

```yaml
# Resource optimization configuration
resource_optimization:
  linkerd_proxy:
    requests:
      cpu: "10m"
      memory: "20Mi"
    limits:
      cpu: "100m"
      memory: "50Mi"
  
  control_plane_tuning:
    destination:
      env:
        LINKERD2_PROXY_LOG: "warn"
        LINKERD2_PROXY_DESTINATION_SVC_BASE: "linkerd-destination.linkerd.svc.cluster.local:8086"
    
    proxy_injector:
      env:
        LINKERD2_PROXY_CPU_REQUEST: "10m"
        LINKERD2_PROXY_MEMORY_REQUEST: "20Mi"
```

---

*Implementation Guide | Service Mesh Implementation Research | January 2025*

**Navigation**
- ← Previous: [Comparison Analysis](./comparison-analysis.md)
- → Next: [Traffic Management Strategies](./traffic-management-strategies.md)
- ↑ Back to: [Service Mesh Implementation](./README.md)