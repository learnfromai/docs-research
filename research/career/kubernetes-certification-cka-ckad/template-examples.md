# Template Examples - YAML Manifests and Practice Exercises

## Overview

This document provides comprehensive YAML templates, practice exercises, and exam-style scenarios for both CKA and CKAD certifications. All templates are production-ready and follow Kubernetes best practices.

## Core Resource Templates

### Pod Templates

#### Basic Pod Template
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: basic-pod
  namespace: default
  labels:
    app: webapp
    version: "1.0"
    environment: production
  annotations:
    description: "Basic pod template with best practices"
spec:
  containers:
  - name: web-container
    image: nginx:1.21-alpine
    ports:
    - containerPort: 80
      name: http
      protocol: TCP
    resources:
      requests:
        memory: "64Mi"
        cpu: "250m"
      limits:
        memory: "128Mi"
        cpu: "500m"
    env:
    - name: ENVIRONMENT
      value: "production"
    - name: POD_NAME
      valueFrom:
        fieldRef:
          fieldPath: metadata.name
    - name: POD_IP
      valueFrom:
        fieldRef:
          fieldPath: status.podIP
    livenessProbe:
      httpGet:
        path: /
        port: 80
      initialDelaySeconds: 30
      periodSeconds: 10
      timeoutSeconds: 5
      failureThreshold: 3
    readinessProbe:
      httpGet:
        path: /
        port: 80
      initialDelaySeconds: 5
      periodSeconds: 5
      timeoutSeconds: 3
      failureThreshold: 3
  restartPolicy: Always
  terminationGracePeriodSeconds: 30
```

#### Multi-Container Pod Template
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: multi-container-pod
  labels:
    app: webapp
    tier: frontend
spec:
  initContainers:
  - name: init-database
    image: busybox:1.35
    command: ['sh', '-c']
    args:
    - |
      echo "Waiting for database to be ready..."
      until nslookup database-service.default.svc.cluster.local; do
        echo "Database not ready, waiting..."
        sleep 2
      done
      echo "Database is ready!"
  containers:
  - name: web-app
    image: nginx:1.21-alpine
    ports:
    - containerPort: 80
    volumeMounts:
    - name: shared-data
      mountPath: /usr/share/nginx/html
    - name: config-volume
      mountPath: /etc/nginx/conf.d
    resources:
      requests:
        memory: "128Mi"
        cpu: "250m"
      limits:
        memory: "256Mi"
        cpu: "500m"
  - name: log-collector
    image: fluent/fluent-bit:1.9
    volumeMounts:
    - name: shared-data
      mountPath: /var/log/nginx
    - name: fluent-bit-config
      mountPath: /fluent-bit/etc
    resources:
      requests:
        memory: "64Mi"
        cpu: "100m"
      limits:
        memory: "128Mi"
        cpu: "200m"
  - name: metrics-exporter
    image: nginx/nginx-prometheus-exporter:0.10.0
    args:
    - -nginx.scrape-uri=http://localhost:80/nginx_status
    ports:
    - containerPort: 9113
      name: metrics
    resources:
      requests:
        memory: "32Mi"
        cpu: "50m"
      limits:
        memory: "64Mi"
        cpu: "100m"
  volumes:
  - name: shared-data
    emptyDir: {}
  - name: config-volume
    configMap:
      name: nginx-config
  - name: fluent-bit-config
    configMap:
      name: fluent-bit-config
```

### Deployment Templates

#### Production-Ready Deployment
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-deployment
  namespace: production
  labels:
    app: webapp
    version: v1.2.0
    tier: frontend
  annotations:
    deployment.kubernetes.io/revision: "1"
    description: "Production web application deployment"
spec:
  replicas: 3
  revisionHistoryLimit: 10
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
      maxSurge: 1
  selector:
    matchLabels:
      app: webapp
      tier: frontend
  template:
    metadata:
      labels:
        app: webapp
        tier: frontend
        version: v1.2.0
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "9090"
        prometheus.io/path: "/metrics"
    spec:
      serviceAccountName: webapp-service-account
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 3000
        fsGroup: 2000
      containers:
      - name: webapp
        image: myregistry/webapp:v1.2.0
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 8080
          name: http
          protocol: TCP
        - containerPort: 9090
          name: metrics
          protocol: TCP
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: webapp-secrets
              key: database-url
        - name: REDIS_URL
          valueFrom:
            secretKeyRef:
              name: webapp-secrets
              key: redis-url
        - name: LOG_LEVEL
          valueFrom:
            configMapKeyRef:
              name: webapp-config
              key: log-level
        - name: ENVIRONMENT
          value: "production"
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: POD_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
            ephemeral-storage: "1Gi"
          limits:
            memory: "512Mi"
            cpu: "500m"
            ephemeral-storage: "2Gi"
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
            scheme: HTTP
          initialDelaySeconds: 60
          periodSeconds: 30
          timeoutSeconds: 10
          failureThreshold: 3
          successThreshold: 1
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
            scheme: HTTP
          initialDelaySeconds: 10
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
          successThreshold: 1
        startupProbe:
          httpGet:
            path: /startup
            port: 8080
            scheme: HTTP
          initialDelaySeconds: 10
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 30
          successThreshold: 1
        volumeMounts:
        - name: config-volume
          mountPath: /app/config
          readOnly: true
        - name: secret-volume
          mountPath: /app/secrets
          readOnly: true
        - name: temp-volume
          mountPath: /tmp
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - ALL
      volumes:
      - name: config-volume
        configMap:
          name: webapp-config
          defaultMode: 0644
      - name: secret-volume
        secret:
          secretName: webapp-secrets
          defaultMode: 0600
      - name: temp-volume
        emptyDir: {}
      imagePullSecrets:
      - name: registry-secret
      nodeSelector:
        kubernetes.io/os: linux
        node-type: worker
      tolerations:
      - key: "high-memory"
        operator: "Equal"
        value: "true"
        effect: "NoSchedule"
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values:
                  - webapp
              topologyKey: kubernetes.io/hostname
```

### Service Templates

#### ClusterIP Service
```yaml
apiVersion: v1
kind: Service
metadata:
  name: webapp-service
  namespace: production
  labels:
    app: webapp
    service-type: internal
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
spec:
  type: ClusterIP
  selector:
    app: webapp
    tier: frontend
  ports:
  - name: http
    port: 80
    targetPort: 8080
    protocol: TCP
  - name: metrics
    port: 9090
    targetPort: 9090
    protocol: TCP
  sessionAffinity: None
```

#### LoadBalancer Service
```yaml
apiVersion: v1
kind: Service
metadata:
  name: webapp-external-service
  namespace: production
  labels:
    app: webapp
    service-type: external
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
    service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: "true"
    service.beta.kubernetes.io/aws-load-balancer-backend-protocol: "tcp"
spec:
  type: LoadBalancer
  selector:
    app: webapp
    tier: frontend
  ports:
  - name: http
    port: 80
    targetPort: 8080
    protocol: TCP
  - name: https
    port: 443
    targetPort: 8443
    protocol: TCP
  loadBalancerSourceRanges:
  - "10.0.0.0/8"
  - "172.16.0.0/12"
  - "192.168.0.0/16"
  externalTrafficPolicy: Local
```

#### Headless Service for StatefulSet
```yaml
apiVersion: v1
kind: Service
metadata:
  name: database-headless-service
  namespace: production
  labels:
    app: database
    service-type: headless
spec:
  clusterIP: None
  selector:
    app: database
    tier: backend
  ports:
  - name: postgres
    port: 5432
    targetPort: 5432
    protocol: TCP
  publishNotReadyAddresses: true
```

### ConfigMap and Secret Templates

#### Application Configuration
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: webapp-config
  namespace: production
  labels:
    app: webapp
    config-type: application
data:
  # Application settings
  log-level: "info"
  max-connections: "100"
  timeout: "30s"
  debug: "false"
  
  # Database settings
  database-pool-size: "10"
  database-timeout: "5s"
  
  # Cache settings
  cache-ttl: "300"
  cache-max-size: "1000"
  
  # Configuration file
  app.properties: |
    # Application Properties
    app.name=webapp
    app.version=1.2.0
    app.environment=production
    
    # Server Configuration
    server.port=8080
    server.address=0.0.0.0
    server.max-threads=200
    
    # Logging Configuration
    logging.level=INFO
    logging.format=json
    logging.output=/var/log/app.log
  
  # Nginx configuration
  nginx.conf: |
    upstream backend {
        server webapp-service:8080;
    }
    
    server {
        listen 80;
        server_name _;
        
        location / {
            proxy_pass http://backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
        
        location /health {
            access_log off;
            return 200 "healthy\n";
            add_header Content-Type text/plain;
        }
    }
```

#### Secrets Template
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: webapp-secrets
  namespace: production
  labels:
    app: webapp
    secret-type: application
type: Opaque
data:
  # Base64 encoded values
  database-url: cG9zdGdyZXNxbDovL3VzZXI6cGFzc0BkYjoxMjM0NS9hcHBkYg==
  redis-url: cmVkaXM6Ly86cGFzc3dvcmRAcmVkaXM6NjM3OS8w
  api-key: YWJjZGVmZ2hpams=
  jwt-secret: c3VwZXJzZWNyZXRqd3RrZXk=
  
---
apiVersion: v1
kind: Secret
metadata:
  name: registry-secret
  namespace: production
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: eyJhdXRocyI6eyJteXJlZ2lzdHJ5LmNvbSI6eyJ1c2VybmFtZSI6InVzZXIiLCJwYXNzd29yZCI6InBhc3MiLCJhdXRoIjoiZFhObGNqcHdZWE56In19fQ==

---
apiVersion: v1
kind: Secret
metadata:
  name: tls-secret
  namespace: production
type: kubernetes.io/tls
data:
  tls.crt: LS0tLS1CRUdJTi4uLg==  # Base64 encoded certificate
  tls.key: LS0tLS1CRUdJTi4uLg==  # Base64 encoded private key
```

## Storage Templates

### Persistent Volume and Claim
```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: database-pv
  labels:
    type: local
    app: database
spec:
  capacity:
    storage: 20Gi
  volumeMode: Filesystem
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: fast-ssd
  hostPath:
    path: /mnt/data/database
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - worker-node-1

---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: database-pvc
  namespace: production
  labels:
    app: database
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 20Gi
  storageClassName: fast-ssd
  selector:
    matchLabels:
      app: database
```

### Storage Class Template
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
  annotations:
    storageclass.kubernetes.io/is-default-class: "false"
provisioner: kubernetes.io/aws-ebs  # Change based on cloud provider
parameters:
  type: gp3
  iops: "3000"
  throughput: "125"
  encrypted: "true"
  kmsKeyId: alias/kubernetes-storage
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
mountOptions:
- debug
- data=ordered
```

## StatefulSet Template

### Database StatefulSet
```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgresql-cluster
  namespace: production
  labels:
    app: postgresql
    tier: database
spec:
  serviceName: postgresql-headless
  replicas: 3
  revisionHistoryLimit: 10
  selector:
    matchLabels:
      app: postgresql
      tier: database
  template:
    metadata:
      labels:
        app: postgresql
        tier: database
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "9187"
    spec:
      serviceAccountName: postgresql-service-account
      securityContext:
        runAsUser: 999
        runAsGroup: 999
        fsGroup: 999
      initContainers:
      - name: init-permissions
        image: busybox:1.35
        command:
        - sh
        - -c
        - |
          chown -R 999:999 /var/lib/postgresql/data
          chmod 700 /var/lib/postgresql/data
        volumeMounts:
        - name: postgresql-storage
          mountPath: /var/lib/postgresql/data
        securityContext:
          runAsUser: 0
      containers:
      - name: postgresql
        image: postgres:13-alpine
        ports:
        - containerPort: 5432
          name: postgres
        - containerPort: 9187
          name: metrics
        env:
        - name: POSTGRES_DB
          value: "appdb"
        - name: POSTGRES_USER
          valueFrom:
            secretKeyRef:
              name: postgresql-secret
              key: username
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: postgresql-secret
              key: password
        - name: PGDATA
          value: /var/lib/postgresql/data/pgdata
        - name: POD_IP
          valueFrom:
            fieldRef:
              fieldPath: status.podIP
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
            ephemeral-storage: "1Gi"
          limits:
            memory: "1Gi"
            cpu: "1000m"
            ephemeral-storage: "2Gi"
        livenessProbe:
          exec:
            command:
            - /bin/sh
            - -c
            - exec pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB" -h 127.0.0.1 -p 5432
          initialDelaySeconds: 60
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 6
        readinessProbe:
          exec:
            command:
            - /bin/sh
            - -c
            - exec pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB" -h 127.0.0.1 -p 5432
          initialDelaySeconds: 10
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 3
        volumeMounts:
        - name: postgresql-storage
          mountPath: /var/lib/postgresql/data
        - name: postgresql-config
          mountPath: /etc/postgresql/postgresql.conf
          subPath: postgresql.conf
        - name: postgresql-init
          mountPath: /docker-entrypoint-initdb.d
      volumes:
      - name: postgresql-config
        configMap:
          name: postgresql-config
      - name: postgresql-init
        configMap:
          name: postgresql-init-scripts
  volumeClaimTemplates:
  - metadata:
      name: postgresql-storage
      labels:
        app: postgresql
    spec:
      accessModes:
      - ReadWriteOnce
      storageClassName: fast-ssd
      resources:
        requests:
          storage: 50Gi
```

## Networking Templates

### Ingress Template
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: webapp-ingress
  namespace: production
  labels:
    app: webapp
    ingress-type: public
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/use-regex: "true"
    nginx.ingress.kubernetes.io/rate-limit: "100"
    nginx.ingress.kubernetes.io/rate-limit-window: "1m"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/cors-allow-origin: "https://example.com"
    nginx.ingress.kubernetes.io/cors-allow-methods: "GET, POST, PUT, DELETE, OPTIONS"
    nginx.ingress.kubernetes.io/cors-allow-headers: "DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,Authorization"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - webapp.example.com
    - api.example.com
    secretName: webapp-tls-secret
  rules:
  - host: webapp.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: webapp-service
            port:
              number: 80
      - path: /api/v1
        pathType: Prefix
        backend:
          service:
            name: api-service
            port:
              number: 8080
  - host: api.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: api-service
            port:
              number: 8080
```

### Network Policy Templates
```yaml
# Default deny all traffic
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress

---
# Allow frontend to backend communication
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: frontend-to-backend
  namespace: production
spec:
  podSelector:
    matchLabels:
      tier: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          tier: frontend
    ports:
    - protocol: TCP
      port: 8080

---
# Allow backend to database communication
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-to-database
  namespace: production
spec:
  podSelector:
    matchLabels:
      tier: database
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          tier: backend
    ports:
    - protocol: TCP
      port: 5432

---
# Allow egress to external services
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-external-egress
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: webapp
  policyTypes:
  - Egress
  egress:
  - to: []
    ports:
    - protocol: TCP
      port: 80
    - protocol: TCP
      port: 443
    - protocol: TCP
      port: 53
    - protocol: UDP
      port: 53
```

## Security Templates

### RBAC Templates
```yaml
# Service Account
apiVersion: v1
kind: ServiceAccount
metadata:
  name: webapp-service-account
  namespace: production
  labels:
    app: webapp
automountServiceAccountToken: true

---
# Role for application operations
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: production
  name: webapp-role
  labels:
    app: webapp
rules:
- apiGroups: [""]
  resources: ["pods", "services", "endpoints", "configmaps", "secrets"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["pods/log", "pods/status"]
  verbs: ["get", "list"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["metrics.k8s.io"]
  resources: ["pods", "nodes"]
  verbs: ["get", "list"]

---
# Role Binding
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: webapp-role-binding
  namespace: production
  labels:
    app: webapp
subjects:
- kind: ServiceAccount
  name: webapp-service-account
  namespace: production
roleRef:
  kind: Role
  name: webapp-role
  apiGroup: rbac.authorization.k8s.io

---
# Cluster Role for cross-namespace operations
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: webapp-cluster-role
  labels:
    app: webapp
rules:
- apiGroups: [""]
  resources: ["nodes", "namespaces"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["metrics.k8s.io"]
  resources: ["nodes", "pods"]
  verbs: ["get", "list"]

---
# Cluster Role Binding
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: webapp-cluster-role-binding
  labels:
    app: webapp
subjects:
- kind: ServiceAccount
  name: webapp-service-account
  namespace: production
roleRef:
  kind: ClusterRole
  name: webapp-cluster-role
  apiGroup: rbac.authorization.k8s.io
```

### Pod Security Policy Template
```yaml
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: webapp-psp
  labels:
    app: webapp
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
  readOnlyRootFilesystem: true
  seccompProfile:
    type: RuntimeDefault
```

## Practice Exercises and Exam Scenarios

### CKAD Practice Scenarios

#### Scenario 1: Multi-Container Application Deployment
```yaml
# Exercise: Deploy a web application with the following requirements:
# 1. Main container: nginx:1.21 serving on port 80
# 2. Sidecar container: busybox that creates index.html every 10 seconds
# 3. Init container: busybox that ensures /usr/share/nginx/html exists
# 4. Use a shared volume between containers
# 5. Configure resource limits and health checks
# 6. Expose via ClusterIP service on port 80

# Time limit: 15 minutes

# Solution:
apiVersion: v1
kind: Pod
metadata:
  name: webapp-with-sidecar
  labels:
    app: webapp
spec:
  initContainers:
  - name: init-html-dir
    image: busybox:1.35
    command: ['sh', '-c', 'mkdir -p /usr/share/nginx/html && echo "Directory created" > /usr/share/nginx/html/init.txt']
    volumeMounts:
    - name: html-volume
      mountPath: /usr/share/nginx/html
  containers:
  - name: nginx
    image: nginx:1.21
    ports:
    - containerPort: 80
    resources:
      requests:
        memory: "64Mi"
        cpu: "250m"
      limits:
        memory: "128Mi"
        cpu: "500m"
    livenessProbe:
      httpGet:
        path: /
        port: 80
      initialDelaySeconds: 30
      periodSeconds: 10
    readinessProbe:
      httpGet:
        path: /
        port: 80
      initialDelaySeconds: 5
      periodSeconds: 5
    volumeMounts:
    - name: html-volume
      mountPath: /usr/share/nginx/html
  - name: html-generator
    image: busybox:1.35
    command: ['sh', '-c']
    args:
    - |
      while true; do
        echo "<h1>Generated at $(date)</h1>" > /usr/share/nginx/html/index.html
        sleep 10
      done
    resources:
      requests:
        memory: "32Mi"
        cpu: "100m"
      limits:
        memory: "64Mi"
        cpu: "200m"
    volumeMounts:
    - name: html-volume
      mountPath: /usr/share/nginx/html
  volumes:
  - name: html-volume
    emptyDir: {}

---
apiVersion: v1
kind: Service
metadata:
  name: webapp-service
spec:
  selector:
    app: webapp
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
```

#### Scenario 2: Configuration and Secrets Management
```yaml
# Exercise: Create a deployment with the following requirements:
# 1. Use nginx:1.21 image
# 2. Create ConfigMap with nginx configuration
# 3. Create Secret with TLS certificates
# 4. Mount ConfigMap as volume in /etc/nginx/conf.d/
# 5. Mount Secret as volume in /etc/nginx/ssl/
# 6. Set environment variables from both ConfigMap and Secret
# 7. Use 3 replicas with proper resource constraints

# Time limit: 20 minutes

# ConfigMap creation
kubectl create configmap nginx-config \
  --from-literal=worker_processes=auto \
  --from-literal=worker_connections=1024 \
  --from-file=nginx.conf=/path/to/nginx.conf

# Secret creation
kubectl create secret tls nginx-tls \
  --cert=/path/to/tls.crt \
  --key=/path/to/tls.key

# Deployment solution
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-secure
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx-secure
  template:
    metadata:
      labels:
        app: nginx-secure
    spec:
      containers:
      - name: nginx
        image: nginx:1.21
        ports:
        - containerPort: 80
        - containerPort: 443
        env:
        - name: WORKER_PROCESSES
          valueFrom:
            configMapKeyRef:
              name: nginx-config
              key: worker_processes
        - name: WORKER_CONNECTIONS
          valueFrom:
            configMapKeyRef:
              name: nginx-config
              key: worker_connections
        resources:
          requests:
            memory: "128Mi"
            cpu: "250m"
          limits:
            memory: "256Mi"
            cpu: "500m"
        volumeMounts:
        - name: config-volume
          mountPath: /etc/nginx/conf.d
        - name: tls-volume
          mountPath: /etc/nginx/ssl
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
      volumes:
      - name: config-volume
        configMap:
          name: nginx-config
      - name: tls-volume
        secret:
          secretName: nginx-tls
```

### CKA Practice Scenarios

#### Scenario 1: Cluster Troubleshooting
```bash
# Exercise: A cluster node is in NotReady state. Diagnose and fix the issue.
# 1. Identify the problematic node
# 2. Check node conditions and events
# 3. Examine system services (kubelet, container runtime)
# 4. Fix configuration issues
# 5. Verify node returns to Ready state

# Time limit: 15 minutes

# Diagnostic commands:
kubectl get nodes
kubectl describe node <node-name>
kubectl get events --sort-by=.metadata.creationTimestamp

# SSH to the node and check services:
systemctl status kubelet
systemctl status containerd
journalctl -u kubelet -f

# Common fixes:
sudo systemctl restart kubelet
sudo systemctl restart containerd

# Verify fix:
kubectl get nodes -w
```

#### Scenario 2: ETCD Backup and Restore
```bash
# Exercise: Create a backup of etcd and restore it
# 1. Create etcd snapshot
# 2. Verify snapshot integrity
# 3. Simulate cluster failure
# 4. Restore from backup
# 5. Verify cluster functionality

# Time limit: 20 minutes

# Backup etcd:
ETCDCTL_API=3 etcdctl snapshot save /tmp/etcd-backup.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# Verify backup:
ETCDCTL_API=3 etcdctl snapshot status /tmp/etcd-backup.db \
  --write-out=table

# Restore etcd (during maintenance):
sudo systemctl stop kubelet
sudo systemctl stop etcd

ETCDCTL_API=3 etcdctl snapshot restore /tmp/etcd-backup.db \
  --data-dir=/var/lib/etcd-restore \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# Update etcd configuration to use restored data:
sudo mv /var/lib/etcd /var/lib/etcd-backup
sudo mv /var/lib/etcd-restore /var/lib/etcd

# Restart services:
sudo systemctl start etcd
sudo systemctl start kubelet

# Verify cluster:
kubectl get nodes
kubectl get pods --all-namespaces
```

## Quick Reference Templates

### Common kubectl Commands for Exams
```bash
# Pod operations
kubectl run nginx --image=nginx --dry-run=client -o yaml > pod.yaml
kubectl run nginx --image=nginx --port=80 --expose
kubectl exec -it nginx -- /bin/bash
kubectl logs nginx -f --previous

# Deployment operations
kubectl create deployment webapp --image=nginx --replicas=3
kubectl scale deployment webapp --replicas=5
kubectl rollout status deployment webapp
kubectl rollout undo deployment webapp

# Service operations
kubectl expose deployment webapp --port=80 --target-port=8080
kubectl expose pod nginx --port=80 --type=NodePort

# ConfigMap and Secret operations
kubectl create configmap app-config --from-literal=key=value
kubectl create secret generic app-secret --from-literal=password=secret
kubectl get configmap app-config -o yaml

# Resource management
kubectl top nodes
kubectl top pods --sort-by=cpu
kubectl describe quota
kubectl get limitrange

# Troubleshooting
kubectl get events --sort-by=.metadata.creationTimestamp
kubectl describe pod nginx
kubectl logs -f deployment/webapp
```

### YAML Snippets for Quick Use
```yaml
# Resource requests and limits
resources:
  requests:
    memory: "64Mi"
    cpu: "250m"
  limits:
    memory: "128Mi"
    cpu: "500m"

# Health checks
livenessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 5

# Volume mounts
volumeMounts:
- name: config-volume
  mountPath: /etc/config
- name: secret-volume
  mountPath: /etc/secrets
  readOnly: true

volumes:
- name: config-volume
  configMap:
    name: app-config
- name: secret-volume
  secret:
    secretName: app-secret

# Environment variables
env:
- name: CONFIG_VALUE
  valueFrom:
    configMapKeyRef:
      name: app-config
      key: config-key
- name: SECRET_VALUE
  valueFrom:
    secretKeyRef:
      name: app-secret
      key: secret-key
- name: POD_NAME
  valueFrom:
    fieldRef:
      fieldPath: metadata.name
```

## Navigation

- **Previous**: [Troubleshooting](./troubleshooting.md)
- **Next**: [Main README](./README.md)
- **Related**: [Hands-On Experience Guide](./hands-on-experience-guide.md)

---

*Template examples and practice exercises compiled from official Kubernetes documentation, exam objectives, and real-world production deployments.*