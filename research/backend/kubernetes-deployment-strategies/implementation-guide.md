# Implementation Guide: Kubernetes Deployment Strategies

> **Step-by-step implementation guide for production-ready Kubernetes deployments**

## 🎯 Prerequisites & Environment Setup

### Required Tools
```bash
# Core Kubernetes tools
kubectl >= 1.25.0
helm >= 3.10.0
docker >= 20.10.0

# Optional but recommended
k9s                    # Kubernetes CLI management
kubectx/kubens        # Context and namespace switching
stern                 # Multi-pod log tailing
```

### Cloud Provider Setup

#### AWS EKS Setup
```bash
# Install AWS CLI and eksctl
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip && sudo ./aws/install

# Install eksctl
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin

# Create EKS cluster
eksctl create cluster \
  --name edtech-platform \
  --version 1.28 \
  --region us-west-2 \
  --nodegroup-name standard-workers \
  --node-type t3.medium \
  --nodes 2 \
  --nodes-min 1 \
  --nodes-max 4 \
  --ssh-access \
  --ssh-public-key ~/.ssh/id_rsa.pub \
  --managed
```

#### GCP GKE Setup
```bash
# Install gcloud CLI
curl https://sdk.cloud.google.com | bash
exec -l $SHELL
gcloud init

# Create GKE cluster
gcloud container clusters create edtech-platform \
    --zone us-central1-a \
    --num-nodes 2 \
    --enable-autoscaling \
    --min-nodes 1 \
    --max-nodes 4 \
    --machine-type e2-standard-2 \
    --enable-autorepair \
    --enable-autoupgrade
```

## 🚀 Core Deployment Strategies Implementation

### 1. Rolling Update Deployment

Rolling updates are the default and most commonly used deployment strategy for EdTech applications.

#### Basic Rolling Update Configuration
```yaml
# edtech-api-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: edtech-api
  namespace: production
  labels:
    app: edtech-api
    version: v1.2.0
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1        # 33% of pods can be unavailable
      maxSurge: 2              # Can create 2 extra pods during update
  selector:
    matchLabels:
      app: edtech-api
  template:
    metadata:
      labels:
        app: edtech-api
        version: v1.2.0
    spec:
      containers:
      - name: api
        image: edtech/api:v1.2.0
        ports:
        - containerPort: 3000
          name: http
        env:
        - name: NODE_ENV
          value: "production"
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: database-secret
              key: url
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
        livenessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /ready
            port: 3000
          initialDelaySeconds: 5
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 3
```

#### Deployment Commands
```bash
# Apply the deployment
kubectl apply -f edtech-api-deployment.yaml

# Monitor rollout status
kubectl rollout status deployment/edtech-api -n production

# View rollout history
kubectl rollout history deployment/edtech-api -n production

# Rollback if needed
kubectl rollout undo deployment/edtech-api -n production
```

### 2. Blue-Green Deployment

Blue-green deployments provide zero-downtime updates with instant rollback capability.

#### Blue-Green Setup with Services
```yaml
# blue-green-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: edtech-api-service
  namespace: production
spec:
  selector:
    app: edtech-api
    version: blue  # Switch between 'blue' and 'green'
  ports:
  - port: 80
    targetPort: 3000
    protocol: TCP
  type: ClusterIP

---
# Blue deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: edtech-api-blue
  namespace: production
spec:
  replicas: 3
  selector:
    matchLabels:
      app: edtech-api
      version: blue
  template:
    metadata:
      labels:
        app: edtech-api
        version: blue
    spec:
      containers:
      - name: api
        image: edtech/api:v1.1.0  # Current stable version
        ports:
        - containerPort: 3000
        # ... (same configuration as rolling update)

---
# Green deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: edtech-api-green
  namespace: production
spec:
  replicas: 3
  selector:
    matchLabels:
      app: edtech-api
      version: green
  template:
    metadata:
      labels:
        app: edtech-api
        version: green
    spec:
      containers:
      - name: api
        image: edtech/api:v1.2.0  # New version to deploy
        ports:
        - containerPort: 3000
        # ... (same configuration as rolling update)
```

#### Blue-Green Deployment Script
```bash
#!/bin/bash
# blue-green-deploy.sh

set -e

NAMESPACE="production"
SERVICE_NAME="edtech-api-service"
NEW_VERSION=$1
CURRENT_COLOR=$2

if [ -z "$NEW_VERSION" ] || [ -z "$CURRENT_COLOR" ]; then
    echo "Usage: $0 <new-version> <current-color>"
    echo "Example: $0 v1.2.0 blue"
    exit 1
fi

# Determine target color
if [ "$CURRENT_COLOR" = "blue" ]; then
    TARGET_COLOR="green"
else
    TARGET_COLOR="blue"
fi

echo "Deploying version $NEW_VERSION to $TARGET_COLOR environment..."

# Update the target deployment with new image
kubectl patch deployment edtech-api-$TARGET_COLOR -n $NAMESPACE \
    -p '{"spec":{"template":{"spec":{"containers":[{"name":"api","image":"edtech/api:'$NEW_VERSION'"}]}}}}'

# Wait for rollout to complete
kubectl rollout status deployment/edtech-api-$TARGET_COLOR -n $NAMESPACE

# Run health checks
echo "Running health checks..."
sleep 30

# Check if the deployment is healthy
READY_REPLICAS=$(kubectl get deployment edtech-api-$TARGET_COLOR -n $NAMESPACE -o jsonpath='{.status.readyReplicas}')
DESIRED_REPLICAS=$(kubectl get deployment edtech-api-$TARGET_COLOR -n $NAMESPACE -o jsonpath='{.spec.replicas}')

if [ "$READY_REPLICAS" -eq "$DESIRED_REPLICAS" ]; then
    echo "Health checks passed. Switching traffic to $TARGET_COLOR..."
    
    # Switch service to point to new deployment
    kubectl patch service $SERVICE_NAME -n $NAMESPACE \
        -p '{"spec":{"selector":{"version":"'$TARGET_COLOR'"}}}'
    
    echo "Traffic switched successfully!"
    echo "Old deployment ($CURRENT_COLOR) is still running for quick rollback if needed."
    echo "To rollback: kubectl patch service $SERVICE_NAME -n $NAMESPACE -p '{\"spec\":{\"selector\":{\"version\":\"$CURRENT_COLOR\"}}}'"
else
    echo "Health checks failed. Rolling back..."
    kubectl rollout undo deployment/edtech-api-$TARGET_COLOR -n $NAMESPACE
    exit 1
fi
```

### 3. Canary Deployment

Canary deployments allow gradual traffic shifting to reduce risk.

#### Canary Deployment with Istio
```yaml
# canary-virtual-service.yaml
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: edtech-api-canary
  namespace: production
spec:
  http:
  - match:
    - headers:
        canary:
          exact: "true"
    route:
    - destination:
        host: edtech-api-service
        subset: canary
      weight: 100
  - route:
    - destination:
        host: edtech-api-service
        subset: stable
      weight: 90
    - destination:
        host: edtech-api-service
        subset: canary
      weight: 10  # Start with 10% traffic to canary

---
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: edtech-api-destination
  namespace: production
spec:
  host: edtech-api-service
  subsets:
  - name: stable
    labels:
      version: stable
  - name: canary
    labels:
      version: canary
```

#### Canary Traffic Shifting Script
```bash
#!/bin/bash
# canary-traffic-shift.sh

NAMESPACE="production"
VIRTUAL_SERVICE="edtech-api-canary"

# Progressive traffic shifting: 10% -> 25% -> 50% -> 100%
TRAFFIC_PERCENTAGES=(10 25 50 100)

for percentage in "${TRAFFIC_PERCENTAGES[@]}"; do
    echo "Shifting $percentage% traffic to canary..."
    
    stable_weight=$((100 - percentage))
    
    kubectl patch virtualservice $VIRTUAL_SERVICE -n $NAMESPACE --type='merge' -p='{
        "spec": {
            "http": [{
                "route": [{
                    "destination": {"host": "edtech-api-service", "subset": "stable"},
                    "weight": '$stable_weight'
                }, {
                    "destination": {"host": "edtech-api-service", "subset": "canary"},
                    "weight": '$percentage'
                }]
            }]
        }
    }'
    
    # Wait and monitor metrics before next shift
    echo "Monitoring for 5 minutes..."
    sleep 300
    
    # Check error rates (this would typically integrate with monitoring system)
    echo "Checking metrics... (implement your monitoring logic here)"
    
    # Simple health check
    if ! kubectl get pods -n $NAMESPACE -l version=canary | grep -q "Running"; then
        echo "Canary deployment unhealthy, rolling back..."
        kubectl patch virtualservice $VIRTUAL_SERVICE -n $NAMESPACE --type='merge' -p='{
            "spec": {
                "http": [{
                    "route": [{
                        "destination": {"host": "edtech-api-service", "subset": "stable"},
                        "weight": 100
                    }]
                }]
            }
        }'
        exit 1
    fi
done

echo "Canary deployment completed successfully!"
```

## 🔧 Service Discovery Implementation

### 1. DNS-Based Service Discovery

Kubernetes provides built-in DNS service discovery through CoreDNS.

#### Service Configuration
```yaml
# edtech-services.yaml
apiVersion: v1
kind: Service
metadata:
  name: user-service
  namespace: production
spec:
  selector:
    app: user-service
  ports:
  - port: 80
    targetPort: 3000
    name: http
  type: ClusterIP

---
apiVersion: v1
kind: Service
metadata:
  name: exam-service
  namespace: production
spec:
  selector:
    app: exam-service
  ports:
  - port: 80
    targetPort: 3001
    name: http
  type: ClusterIP

---
apiVersion: v1
kind: Service
metadata:
  name: notification-service
  namespace: production
spec:
  selector:
    app: notification-service
  ports:
  - port: 80
    targetPort: 3002
    name: http
  type: ClusterIP
```

#### Service Discovery Usage Examples
```javascript
// Node.js service discovery example
const axios = require('axios');

class ServiceDiscovery {
  constructor(namespace = 'production') {
    this.namespace = namespace;
    this.services = {
      user: `http://user-service.${namespace}.svc.cluster.local`,
      exam: `http://exam-service.${namespace}.svc.cluster.local`,
      notification: `http://notification-service.${namespace}.svc.cluster.local`
    };
  }

  async callUserService(endpoint, data) {
    try {
      const response = await axios.post(`${this.services.user}${endpoint}`, data);
      return response.data;
    } catch (error) {
      console.error('User service call failed:', error.message);
      throw error;
    }
  }

  async getExamQuestions(examId) {
    return this.callService('exam', `/api/exams/${examId}/questions`);
  }

  async sendNotification(userId, message) {
    return this.callService('notification', '/api/notifications', {
      userId,
      message,
      timestamp: new Date().toISOString()
    });
  }
}

module.exports = ServiceDiscovery;
```

### 2. Service Mesh Implementation (Istio)

#### Istio Installation
```bash
# Download and install Istio
curl -L https://istio.io/downloadIstio | sh -
cd istio-*
export PATH=$PWD/bin:$PATH

# Install Istio on cluster
istioctl install --set values.defaultRevision=default -y

# Enable sidecar injection for production namespace
kubectl label namespace production istio-injection=enabled
```

#### Service Mesh Configuration
```yaml
# istio-gateway.yaml
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: edtech-gateway
  namespace: production
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - api.edtech-platform.com
  - port:
      number: 443
      name: https
      protocol: HTTPS
    tls:
      mode: SIMPLE
      credentialName: edtech-tls-secret
    hosts:
    - api.edtech-platform.com

---
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: edtech-api-routing
  namespace: production
spec:
  hosts:
  - api.edtech-platform.com
  gateways:
  - edtech-gateway
  http:
  - match:
    - uri:
        prefix: /api/users
    route:
    - destination:
        host: user-service
        port:
          number: 80
  - match:
    - uri:
        prefix: /api/exams
    route:
    - destination:
        host: exam-service
        port:
          number: 80
  - match:
    - uri:
        prefix: /api/notifications
    route:
    - destination:
        host: notification-service
        port:
          number: 80
```

## 📊 Auto-Scaling Implementation

### 1. Horizontal Pod Autoscaler (HPA)

#### Basic CPU/Memory-based HPA
```yaml
# hpa-basic.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: edtech-api-hpa
  namespace: production
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: edtech-api
  minReplicas: 2
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
      - type: Pods
        value: 4
        periodSeconds: 60
      selectPolicy: Max
```

#### Custom Metrics HPA with Prometheus
```yaml
# hpa-custom-metrics.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: edtech-exam-hpa
  namespace: production
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: exam-service
  minReplicas: 3
  maxReplicas: 50
  metrics:
  - type: Pods
    pods:
      metric:
        name: concurrent_exam_sessions
      target:
        type: AverageValue
        averageValue: "10"  # Scale up when >10 concurrent sessions per pod
  - type: Pods
    pods:
      metric:
        name: api_request_rate
      target:
        type: AverageValue
        averageValue: "100"  # Scale up when >100 requests/second per pod
```

### 2. Vertical Pod Autoscaler (VPA)

```yaml
# vpa-config.yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: edtech-api-vpa
  namespace: production
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: edtech-api
  updatePolicy:
    updateMode: "Auto"  # Can be "Off", "Initial", or "Auto"
  resourcePolicy:
    containerPolicies:
    - containerName: api
      minAllowed:
        cpu: 100m
        memory: 128Mi
      maxAllowed:
        cpu: 2
        memory: 2Gi
      controlledResources: ["cpu", "memory"]
```

### 3. Cluster Autoscaler

#### AWS EKS Cluster Autoscaler
```yaml
# cluster-autoscaler.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cluster-autoscaler
  namespace: kube-system
  labels:
    app: cluster-autoscaler
spec:
  selector:
    matchLabels:
      app: cluster-autoscaler
  template:
    metadata:
      labels:
        app: cluster-autoscaler
    spec:
      serviceAccountName: cluster-autoscaler
      containers:
      - image: k8s.gcr.io/autoscaling/cluster-autoscaler:v1.25.0
        name: cluster-autoscaler
        resources:
          limits:
            cpu: 100m
            memory: 300Mi
          requests:
            cpu: 100m
            memory: 300Mi
        command:
        - ./cluster-autoscaler
        - --v=4
        - --stderrthreshold=info
        - --cloud-provider=aws
        - --skip-nodes-with-local-storage=false
        - --expander=least-waste
        - --node-group-auto-discovery=asg:tag=k8s.io/cluster-autoscaler/enabled,k8s.io/cluster-autoscaler/edtech-platform
        - --balance-similar-node-groups
        - --skip-nodes-with-system-pods=false
        env:
        - name: AWS_REGION
          value: us-west-2
```

## 🛡️ Security Implementation

### 1. Network Policies
```yaml
# network-policies.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: edtech-api-network-policy
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: edtech-api
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
    - podSelector:
        matchLabels:
          app: user-service
    ports:
    - protocol: TCP
      port: 3000
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: database
    ports:
    - protocol: TCP
      port: 5432
  - to: []  # Allow DNS
    ports:
    - protocol: UDP
      port: 53
```

### 2. RBAC Configuration
```yaml
# rbac.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: edtech-api-sa
  namespace: production

---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: production
  name: edtech-api-role
rules:
- apiGroups: [""]
  resources: ["configmaps", "secrets"]
  verbs: ["get", "list"]
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: edtech-api-binding
  namespace: production
subjects:
- kind: ServiceAccount
  name: edtech-api-sa
  namespace: production
roleRef:
  kind: Role
  name: edtech-api-role
  apiGroup: rbac.authorization.k8s.io
```

## 📋 Monitoring & Observability Setup

### Prometheus & Grafana Installation
```bash
# Add Prometheus Helm repository
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install Prometheus
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set grafana.adminPassword=your-secure-password \
  --set prometheus.prometheusSpec.retention=30d \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=50Gi
```

### Custom Metrics for EdTech Platform
```yaml
# servicemonitor.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: edtech-api-metrics
  namespace: production
spec:
  selector:
    matchLabels:
      app: edtech-api
  endpoints:
  - port: metrics
    path: /metrics
    interval: 30s
```

---

## 🔗 Next Steps

After completing this implementation guide, proceed to:
- [Best Practices](./best-practices.md) - Production-ready patterns and recommendations
- [Performance Analysis](./performance-analysis.md) - Optimization and monitoring strategies
- [Troubleshooting](./troubleshooting.md) - Common issues and resolution strategies

---

### 🔗 Navigation
- [← Back to Main Research](./README.md)
- [Next: Best Practices →](./best-practices.md)