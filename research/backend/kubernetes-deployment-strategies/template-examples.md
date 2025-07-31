# Template Examples: Kubernetes Deployment Strategies

> **Production-ready Kubernetes manifests and configuration templates for EdTech platforms**

## 🎯 Template Overview

This document provides complete, production-ready Kubernetes templates specifically designed for EdTech platforms. All templates include comprehensive security, monitoring, and operational best practices.

## 🚀 Complete EdTech Application Stack

### 1. Namespace and RBAC Setup

```yaml
# namespace-setup.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: edtech-production
  labels:
    name: edtech-production
    environment: production
    data-classification: confidential
    compliance.edtech/ferpa: required
    compliance.edtech/gdpr: required
  annotations:
    description: "Production namespace for EdTech platform"
    security.policy/pod-security-standard: restricted
    network.policy/default-deny: "true"

---
# Service Account for API services
apiVersion: v1
kind: ServiceAccount
metadata:
  name: edtech-api-sa
  namespace: edtech-production
  labels:
    app: edtech-api
    component: backend
  annotations:
    description: "Service account for EdTech API services"
automountServiceAccountToken: false

---
# Role for API operations
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: edtech-production
  name: edtech-api-role
  labels:
    rbac.edtech.io/role: api-service
rules:
# ConfigMap access
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get", "list", "watch"]
  resourceNames: ["app-config", "feature-flags"]

# Secret access (limited)
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get"]
  resourceNames: ["database-secret", "jwt-secret", "encryption-key"]

# Pod information for health checks
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]

# Event creation for audit logging
- apiGroups: [""]
  resources: ["events"]
  verbs: ["create"]

---
# RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: edtech-api-binding
  namespace: edtech-production
  labels:
    rbac.edtech.io/binding: api-service
subjects:
- kind: ServiceAccount
  name: edtech-api-sa
  namespace: edtech-production
roleRef:
  kind: Role
  name: edtech-api-role
  apiGroup: rbac.authorization.k8s.io

---
# Network Policy - Default Deny
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: edtech-production
  labels:
    security.policy/type: default-deny
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

### 2. Application Configuration

```yaml
# app-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: edtech-production
  labels:
    app: edtech-platform
    config-type: application
data:
  # Application settings
  NODE_ENV: "production"
  LOG_LEVEL: "info"
  PORT: "3000"
  METRICS_PORT: "9090"
  
  # Database settings
  DB_POOL_MIN: "5"
  DB_POOL_MAX: "50"
  DB_TIMEOUT: "30000"
  DB_SSL_MODE: "require"
  
  # Cache settings
  REDIS_TTL: "3600"
  REDIS_MAX_RETRIES: "3"
  
  # Security settings
  JWT_EXPIRY: "15m"
  JWT_REFRESH_EXPIRY: "7d"
  RATE_LIMIT_WINDOW: "900000"  # 15 minutes
  RATE_LIMIT_MAX: "1000"
  
  # FERPA compliance
  DATA_RETENTION_PERIOD: "7y"
  AUDIT_LOG_ENABLED: "true"
  PII_ENCRYPTION_ENABLED: "true"
  
  # Feature flags
  FEATURE_ADVANCED_ANALYTICS: "true"
  FEATURE_VIDEO_STREAMING: "true"
  FEATURE_MOBILE_APP_API: "true"
  
  # Monitoring
  METRICS_ENABLED: "true"
  TRACING_ENABLED: "true"
  APM_SAMPLING_RATE: "0.1"

---
# Feature flags ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: feature-flags
  namespace: edtech-production
  labels:
    app: edtech-platform
    config-type: feature-flags
data:
  flags.json: |
    {
      "examProctoring": {
        "enabled": true,
        "rolloutPercentage": 100,
        "description": "AI-powered exam proctoring"
      },
      "adaptiveLearning": {
        "enabled": true,
        "rolloutPercentage": 75,
        "description": "Adaptive learning algorithms"
      },
      "socialLearning": {
        "enabled": false,
        "rolloutPercentage": 0,
        "description": "Social learning features"
      },
      "mobileNotifications": {
        "enabled": true,
        "rolloutPercentage": 100,
        "description": "Push notifications for mobile apps"
      },
      "advancedReporting": {
        "enabled": true,
        "rolloutPercentage": 50,
        "description": "Advanced analytics and reporting"
      }
    }
```

### 3. Secrets Management

```yaml
# secrets-template.yaml
# Note: This template shows structure. Use external secrets management in production.
apiVersion: v1
kind: Secret
metadata:
  name: database-secret
  namespace: edtech-production
  labels:
    app: edtech-platform
    secret-type: database
  annotations:
    managed-by: external-secrets-operator
    vault.hashicorp.com/agent-inject: "true"
    vault.hashicorp.com/role: "edtech-api"
type: Opaque
data:
  # Base64 encoded values - use external secrets in production
  username: <base64-encoded-username>
  password: <base64-encoded-password>
  url: <base64-encoded-full-connection-string>
  ssl-cert: <base64-encoded-ssl-certificate>

---
apiVersion: v1
kind: Secret
metadata:
  name: jwt-secret
  namespace: edtech-production
  labels:
    app: edtech-platform
    secret-type: jwt
  annotations:
    managed-by: external-secrets-operator
type: Opaque
data:
  private-key: <base64-encoded-rsa-private-key>
  public-key: <base64-encoded-rsa-public-key>
  key-id: <base64-encoded-key-identifier>

---
apiVersion: v1
kind: Secret
metadata:
  name: encryption-key
  namespace: edtech-production
  labels:
    app: edtech-platform
    secret-type: encryption
  annotations:
    managed-by: external-secrets-operator
type: Opaque
data:
  aes-key: <base64-encoded-aes-256-key>
  iv: <base64-encoded-initialization-vector>

---
apiVersion: v1
kind: Secret
metadata:
  name: external-api-keys
  namespace: edtech-production
  labels:
    app: edtech-platform
    secret-type: external-apis
type: Opaque
data:
  stripe-secret-key: <base64-encoded-stripe-secret>
  sendgrid-api-key: <base64-encoded-sendgrid-key>
  aws-access-key: <base64-encoded-aws-access-key>
  aws-secret-key: <base64-encoded-aws-secret-key>
```

### 4. User Service Deployment

```yaml
# user-service.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: user-service
  namespace: edtech-production
  labels:
    app: user-service
    component: backend
    tier: api
    version: v2.1.0
  annotations:
    deployment.kubernetes.io/revision: "5"
    changelog: "Added OAuth integration and enhanced user profiles"
    security.scan/last-scanned: "2024-07-31T10:00:00Z"
    security.scan/status: "passed"
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
        version: v2.1.0
        tier: api
        security.scan/status: passed
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "9090"
        prometheus.io/path: "/metrics"
        config.reload/checksum: "${CONFIG_CHECKSUM}"
    spec:
      serviceAccountName: edtech-api-sa
      automountServiceAccountToken: false
      
      # Security context
      securityContext:
        runAsNonRoot: true
        runAsUser: 65534
        runAsGroup: 65534
        fsGroup: 65534
        seccompProfile:
          type: RuntimeDefault
      
      # Init containers
      initContainers:
      - name: db-migration
        image: edtech/user-service-migrations:v2.1.0
        imagePullPolicy: Always
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: database-secret
              key: url
        - name: MIGRATION_MODE
          value: "up"
        command: ['npm', 'run', 'migrate']
        securityContext:
          runAsNonRoot: true
          runAsUser: 65534
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop: ["ALL"]
      
      containers:
      - name: user-service
        image: edtech/user-service:v2.1.0
        imagePullPolicy: Always
        
        ports:
        - containerPort: 3000
          name: http
          protocol: TCP
        - containerPort: 9090
          name: metrics
          protocol: TCP
        
        # Environment from ConfigMap
        envFrom:
        - configMapRef:
            name: app-config
        
        # Environment from Secrets
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: database-secret
              key: url
        - name: JWT_PRIVATE_KEY
          valueFrom:
            secretKeyRef:
              name: jwt-secret
              key: private-key
        - name: JWT_PUBLIC_KEY
          valueFrom:
            secretKeyRef:
              name: jwt-secret
              key: public-key
        - name: ENCRYPTION_KEY
          valueFrom:
            secretKeyRef:
              name: encryption-key
              key: aes-key
        - name: STRIPE_SECRET_KEY
          valueFrom:
            secretKeyRef:
              name: external-api-keys
              key: stripe-secret-key
        
        # Resource allocation
        resources:
          requests:
            cpu: 200m
            memory: 256Mi
            ephemeral-storage: 100Mi
          limits:
            cpu: 1000m
            memory: 512Mi
            ephemeral-storage: 200Mi
        
        # Security context
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          runAsUser: 65534
          capabilities:
            drop: ["ALL"]
        
        # Health checks
        livenessProbe:
          httpGet:
            path: /health/live
            port: 3000
            httpHeaders:
            - name: X-Health-Check
              value: "internal"
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
          successThreshold: 1
        
        readinessProbe:
          httpGet:
            path: /health/ready
            port: 3000
            httpHeaders:
            - name: X-Health-Check
              value: "internal"
          initialDelaySeconds: 10
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 3
          successThreshold: 1
        
        startupProbe:
          httpGet:
            path: /health/startup
            port: 3000
            httpHeaders:
            - name: X-Health-Check
              value: "internal"
          initialDelaySeconds: 10
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 30
        
        # Graceful shutdown
        lifecycle:
          preStop:
            exec:
              command: ["/bin/sh", "-c", "sleep 15"]
        
        # Volume mounts
        volumeMounts:
        - name: tmp-volume
          mountPath: /tmp
        - name: cache-volume
          mountPath: /app/cache
        - name: logs-volume
          mountPath: /app/logs
        - name: config-volume
          mountPath: /app/config
          readOnly: true
      
      # Volumes
      volumes:
      - name: tmp-volume
        emptyDir:
          sizeLimit: 100Mi
          medium: Memory
      - name: cache-volume
        emptyDir:
          sizeLimit: 200Mi
      - name: logs-volume
        emptyDir:
          sizeLimit: 500Mi
      - name: config-volume
        configMap:
          name: app-config
          defaultMode: 0444
      
      # Pod disruption and affinity
      terminationGracePeriodSeconds: 30
      
      # Anti-affinity for better distribution
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
        
        # Node affinity (prefer specific node types)
        nodeAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 50
            preference:
              matchExpressions:
              - key: node-type
                operator: In
                values: ["api-optimized"]

---
# Service for User Service
apiVersion: v1
kind: Service
metadata:
  name: user-service
  namespace: edtech-production
  labels:
    app: user-service
    tier: api
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: nlb
    prometheus.io/scrape: "true"
    prometheus.io/port: "9090"
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
# HPA for User Service
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: user-service-hpa
  namespace: edtech-production
  labels:
    app: user-service
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
  - type: Pods
    pods:
      metric:
        name: concurrent_user_sessions
      target:
        type: AverageValue
        averageValue: "100"
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
# PDB for User Service
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: user-service-pdb
  namespace: edtech-production
  labels:
    app: user-service
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: user-service
```

### 5. Database Deployment (PostgreSQL)

```yaml
# database.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres-primary
  namespace: edtech-production
  labels:
    app: postgres
    role: primary
    tier: database
spec:
  serviceName: postgres-primary
  replicas: 1
  updateStrategy:
    type: RollingUpdate
  selector:
    matchLabels:
      app: postgres
      role: primary
  template:
    metadata:
      labels:
        app: postgres
        role: primary
        tier: database
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "9187"
        backup.schedule: "0 2 * * *"
    spec:
      securityContext:
        runAsUser: 999
        runAsGroup: 999
        fsGroup: 999
      
      containers:
      - name: postgres
        image: postgres:15.4-alpine
        imagePullPolicy: Always
        
        env:
        - name: POSTGRES_DB
          value: edtech_production
        - name: POSTGRES_USER
          valueFrom:
            secretKeyRef:
              name: database-secret
              key: username
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: database-secret
              key: password
        - name: PGDATA
          value: /var/lib/postgresql/data/pgdata
        - name: POSTGRES_INITDB_ARGS
          value: "--encoding=UTF8 --locale=en_US.UTF-8"
        
        ports:
        - containerPort: 5432
          name: postgres
        
        resources:
          requests:
            cpu: 500m
            memory: 1Gi
            ephemeral-storage: 100Mi
          limits:
            cpu: 2000m
            memory: 4Gi
            ephemeral-storage: 200Mi
        
        volumeMounts:
        - name: postgres-storage
          mountPath: /var/lib/postgresql/data
        - name: postgres-config
          mountPath: /etc/postgresql/postgresql.conf
          subPath: postgresql.conf
          readOnly: true
        - name: postgres-init
          mountPath: /docker-entrypoint-initdb.d
        
        livenessProbe:
          exec:
            command:
            - sh
            - -c
            - pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB"
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        
        readinessProbe:
          exec:
            command:
            - sh
            - -c
            - pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB"
          initialDelaySeconds: 5
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 3
      
      # PostgreSQL Exporter for monitoring
      - name: postgres-exporter
        image: prometheuscommunity/postgres-exporter:v0.13.2
        imagePullPolicy: Always
        env:
        - name: DATA_SOURCE_NAME
          valueFrom:
            secretKeyRef:
              name: database-secret
              key: url
        ports:
        - containerPort: 9187
          name: metrics
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 200m
            memory: 128Mi
        securityContext:
          runAsNonRoot: true
          runAsUser: 65534
          allowPrivilegeEscalation: false
      
      volumes:
      - name: postgres-config
        configMap:
          name: postgres-config
      - name: postgres-init
        configMap:
          name: postgres-init-scripts
  
  volumeClaimTemplates:
  - metadata:
      name: postgres-storage
      labels:
        app: postgres
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: fast-ssd
      resources:
        requests:
          storage: 100Gi

---
# PostgreSQL Service
apiVersion: v1
kind: Service
metadata:
  name: postgres-primary
  namespace: edtech-production
  labels:
    app: postgres
    role: primary
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "9187"
spec:
  type: ClusterIP
  selector:
    app: postgres
    role: primary
  ports:
  - port: 5432
    targetPort: 5432
    protocol: TCP
    name: postgres
  - port: 9187
    targetPort: 9187
    protocol: TCP
    name: metrics

---
# PostgreSQL Configuration
apiVersion: v1
kind: ConfigMap
metadata:
  name: postgres-config
  namespace: edtech-production
  labels:
    app: postgres
data:
  postgresql.conf: |
    # Performance settings
    shared_buffers = 256MB
    effective_cache_size = 1GB
    maintenance_work_mem = 64MB
    checkpoint_completion_target = 0.9
    wal_buffers = 16MB
    default_statistics_target = 100
    random_page_cost = 1.1
    
    # Connection settings
    max_connections = 200
    superuser_reserved_connections = 3
    
    # Logging
    log_destination = 'stderr'
    logging_collector = on
    log_directory = 'pg_log'
    log_filename = 'postgresql-%a.log'
    log_truncate_on_rotation = on
    log_rotation_age = 1d
    log_min_duration_statement = 1000  # Log slow queries
    log_checkpoints = on
    log_connections = on
    log_disconnections = on
    log_lock_waits = on
    
    # Security
    ssl = on
    ssl_ciphers = 'HIGH:MEDIUM:+3DES:!aNULL'
    ssl_prefer_server_ciphers = on
    
    # Replication (for future read replicas)
    wal_level = replica
    max_wal_senders = 3
    max_replication_slots = 3
    
    # Archive settings for backup
    archive_mode = on
    archive_command = 'cp %p /var/lib/postgresql/archive/%f'

---
# Database initialization scripts
apiVersion: v1
kind: ConfigMap
metadata:
  name: postgres-init-scripts
  namespace: edtech-production
  labels:
    app: postgres
data:
  01-extensions.sql: |
    -- Enable required extensions
    CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
    CREATE EXTENSION IF NOT EXISTS "pgcrypto";
    CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";
    
  02-audit-setup.sql: |
    -- Audit table for FERPA compliance
    CREATE TABLE audit_log (
      id SERIAL PRIMARY KEY,
      table_name VARCHAR(255) NOT NULL,
      operation VARCHAR(10) NOT NULL,
      old_values JSONB,
      new_values JSONB,
      user_id INTEGER,
      timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      ip_address INET,
      user_agent TEXT
    );
    
    -- Index for efficient querying
    CREATE INDEX idx_audit_log_timestamp ON audit_log(timestamp);
    CREATE INDEX idx_audit_log_user_id ON audit_log(user_id);
    CREATE INDEX idx_audit_log_table_name ON audit_log(table_name);
```

### 6. Redis Cache Deployment

```yaml
# redis.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis
  namespace: edtech-production
  labels:
    app: redis
    tier: cache
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
        tier: cache
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "9121"
    spec:
      securityContext:
        runAsUser: 999
        runAsGroup: 999
        fsGroup: 999
      
      containers:
      - name: redis
        image: redis:7.2-alpine
        imagePullPolicy: Always
        
        ports:
        - containerPort: 6379
          name: redis
        
        command: ["redis-server"]
        args:
        - /etc/redis/redis.conf
        - --requirepass
        - $(REDIS_PASSWORD)
        
        env:
        - name: REDIS_PASSWORD
          valueFrom:
            secretKeyRef:
              name: redis-secret
              key: password
        
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
        
        volumeMounts:
        - name: redis-config
          mountPath: /etc/redis
        - name: redis-data
          mountPath: /data
        
        livenessProbe:
          exec:
            command:
            - redis-cli
            - --no-auth-warning
            - -a
            - $(REDIS_PASSWORD)
            - ping
          initialDelaySeconds: 30
          periodSeconds: 10
        
        readinessProbe:
          exec:
            command:
            - redis-cli
            - --no-auth-warning
            - -a
            - $(REDIS_PASSWORD)
            - ping
          initialDelaySeconds: 5
          periodSeconds: 5
      
      # Redis Exporter for monitoring
      - name: redis-exporter
        image: oliver006/redis_exporter:v1.53.0
        imagePullPolicy: Always
        env:
        - name: REDIS_ADDR
          value: "redis://localhost:6379"
        - name: REDIS_PASSWORD
          valueFrom:
            secretKeyRef:
              name: redis-secret
              key: password
        ports:
        - containerPort: 9121
          name: metrics
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 200m
            memory: 128Mi
      
      volumes:
      - name: redis-config
        configMap:
          name: redis-config
      - name: redis-data
        emptyDir:
          sizeLimit: 1Gi

---
# Redis Service
apiVersion: v1
kind: Service
metadata:
  name: redis
  namespace: edtech-production
  labels:
    app: redis
    tier: cache
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "9121"
spec:
  type: ClusterIP
  selector:
    app: redis
  ports:
  - port: 6379
    targetPort: 6379
    protocol: TCP
    name: redis
  - port: 9121
    targetPort: 9121
    protocol: TCP
    name: metrics

---
# Redis Configuration
apiVersion: v1
kind: ConfigMap
metadata:
  name: redis-config
  namespace: edtech-production
  labels:
    app: redis
data:
  redis.conf: |
    # Network
    bind 0.0.0.0
    port 6379
    tcp-backlog 511
    timeout 0
    tcp-keepalive 300
    
    # General
    daemonize no
    pidfile /var/run/redis.pid
    loglevel notice
    logfile ""
    databases 16
    
    # Persistence
    save 900 1
    save 300 10
    save 60 10000
    stop-writes-on-bgsave-error yes
    rdbcompression yes
    rdbchecksum yes
    dbfilename dump.rdb
    dir /data
    
    # Security
    # requirepass will be set via command line args
    
    # Memory management
    maxmemory 400mb
    maxmemory-policy allkeys-lru
    
    # Performance
    tcp-nodelay yes
    timeout 0

---
# Redis Secret
apiVersion: v1
kind: Secret
metadata:
  name: redis-secret
  namespace: edtech-production
  labels:
    app: redis
type: Opaque
data:
  password: <base64-encoded-redis-password>
```

### 7. Ingress and Load Balancing

```yaml
# ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: edtech-platform-ingress
  namespace: edtech-production
  labels:
    app: edtech-platform
    tier: frontend
  annotations:
    # NGINX Ingress Controller
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    
    # SSL/TLS
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/ssl-protocols: "TLSv1.2 TLSv1.3"
    nginx.ingress.kubernetes.io/ssl-ciphers: "ECDHE-RSA-AES128-GCM-SHA256,ECDHE-RSA-AES256-GCM-SHA384"
    
    # Security headers
    nginx.ingress.kubernetes.io/server-snippet: |
      add_header X-Frame-Options "SAMEORIGIN" always;
      add_header X-Content-Type-Options "nosniff" always;
      add_header X-XSS-Protection "1; mode=block" always;
      add_header Referrer-Policy "strict-origin-when-cross-origin" always;
      add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval' *.googleapis.com *.gstatic.com; style-src 'self' 'unsafe-inline' *.googleapis.com; img-src 'self' data: *.amazonaws.com; font-src 'self' *.googleapis.com *.gstatic.com; connect-src 'self' *.stripe.com; frame-ancestors 'none';" always;
    
    # Rate limiting
    nginx.ingress.kubernetes.io/rate-limit: "100"
    nginx.ingress.kubernetes.io/rate-limit-window: "1m"
    
    # CORS (if needed)
    nginx.ingress.kubernetes.io/enable-cors: "true"
    nginx.ingress.kubernetes.io/cors-allow-origin: "https://app.edtech-platform.com,https://mobile.edtech-platform.com"
    nginx.ingress.kubernetes.io/cors-allow-methods: "GET,POST,PUT,DELETE,OPTIONS"
    nginx.ingress.kubernetes.io/cors-allow-headers: "DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,Authorization"
    
    # Load balancing
    nginx.ingress.kubernetes.io/load-balance: "ewma"
    nginx.ingress.kubernetes.io/upstream-hash-by: "$remote_addr"
    
    # Request size
    nginx.ingress.kubernetes.io/proxy-body-size: "50m"
    
    # Timeouts
    nginx.ingress.kubernetes.io/proxy-connect-timeout: "30"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "30"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "30"
    
    # Health checks
    nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
    nginx.ingress.kubernetes.io/health-check-path: "/health/ready"
    nginx.ingress.kubernetes.io/health-check-interval: "30s"
    
spec:
  tls:
  - hosts:
    - api.edtech-platform.com
    - app.edtech-platform.com
    - admin.edtech-platform.com
    secretName: edtech-platform-tls
  
  rules:
  # API endpoints
  - host: api.edtech-platform.com
    http:
      paths:
      - path: /api/users
        pathType: Prefix
        backend:
          service:
            name: user-service
            port:
              number: 80
      
      - path: /api/exams
        pathType: Prefix
        backend:
          service:
            name: exam-service
            port:
              number: 80
      
      - path: /api/notifications
        pathType: Prefix
        backend:
          service:
            name: notification-service
            port:
              number: 80
      
      - path: /api/payments
        pathType: Prefix
        backend:
          service:
            name: payment-service
            port:
              number: 80
      
      - path: /health
        pathType: Prefix
        backend:
          service:
            name: health-check-service
            port:
              number: 80
  
  # Frontend application
  - host: app.edtech-platform.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend-service
            port:
              number: 80
  
  # Admin panel
  - host: admin.edtech-platform.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: admin-service
            port:
              number: 80
```

### 8. Network Policies

```yaml
# network-policies.yaml
# Allow ingress controller to reach services
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-ingress-to-services
  namespace: edtech-production
  labels:
    security.policy/type: ingress-access
spec:
  podSelector:
    matchLabels:
      tier: api
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
    ports:
    - protocol: TCP
      port: 3000

---
# Allow inter-service communication
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-inter-service-communication
  namespace: edtech-production
  labels:
    security.policy/type: inter-service
spec:
  podSelector:
    matchLabels:
      tier: api
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          tier: api
    ports:
    - protocol: TCP
      port: 3000
  egress:
  - to:
    - podSelector:
        matchLabels:
          tier: api
    ports:
    - protocol: TCP
      port: 3000

---
# Allow API services to access database
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-api-to-database
  namespace: edtech-production
  labels:
    security.policy/type: database-access
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
          tier: api
    ports:
    - protocol: TCP
      port: 5432

---
# Allow API services to access Redis
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-api-to-redis
  namespace: edtech-production
  labels:
    security.policy/type: cache-access
spec:
  podSelector:
    matchLabels:
      app: redis
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          tier: api
    ports:
    - protocol: TCP
      port: 6379

---
# Allow monitoring to scrape metrics
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-monitoring-scraping
  namespace: edtech-production
  labels:
    security.policy/type: monitoring-access
spec:
  podSelector:
    matchExpressions:
    - key: prometheus.io/scrape
      operator: In
      values: ["true"]
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: monitoring
    - podSelector:
        matchLabels:
          app: prometheus
    ports:
    - protocol: TCP
      port: 9090
    - protocol: TCP
      port: 9187
    - protocol: TCP
      port: 9121

---
# Allow DNS resolution and external HTTPS
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns-and-external-https
  namespace: edtech-production
  labels:
    security.policy/type: external-access
spec:
  podSelector:
    matchLabels:
      tier: api
  policyTypes:
  - Egress
  egress:
  # DNS
  - to: []
    ports:
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53
  
  # HTTPS to external services
  - to: []
    ports:
    - protocol: TCP
      port: 443
  
  # NTP for time synchronization
  - to: []
    ports:
    - protocol: UDP
      port: 123
```

### 9. Monitoring Stack

```yaml
# monitoring.yaml
apiVersion: v1
kind: ServiceMonitor
metadata:
  name: edtech-services-metrics
  namespace: edtech-production
  labels:
    app: edtech-platform
    monitoring: prometheus
spec:
  selector:
    matchLabels:
      prometheus.io/scrape: "true"
  endpoints:
  - port: metrics
    path: /metrics
    interval: 30s
    scrapeTimeout: 10s

---
# Grafana Dashboard ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: edtech-dashboard
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
data:
  edtech-overview.json: |
    {
      "dashboard": {
        "id": null,
        "title": "EdTech Platform Overview",
        "tags": ["edtech", "production"],
        "timezone": "browser",
        "panels": [
          {
            "id": 1,
            "title": "Request Rate",
            "type": "graph",
            "targets": [
              {
                "expr": "sum(rate(http_requests_total{namespace=\"edtech-production\"}[5m])) by (service)",
                "legendFormat": "{{service}}"
              }
            ]
          },
          {
            "id": 2,
            "title": "Response Time P95",
            "type": "graph",
            "targets": [
              {
                "expr": "histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket{namespace=\"edtech-production\"}[5m])) by (service, le))",
                "legendFormat": "{{service}}"
              }
            ]
          },
          {
            "id": 3,
            "title": "Error Rate",
            "type": "graph",
            "targets": [
              {
                "expr": "sum(rate(http_requests_total{namespace=\"edtech-production\",code!~\"2..\"}[5m])) by (service) / sum(rate(http_requests_total{namespace=\"edtech-production\"}[5m])) by (service)",
                "legendFormat": "{{service}}"
              }
            ]
          }
        ],
        "time": {
          "from": "now-1h",
          "to": "now"
        },
        "refresh": "30s"
      }
    }
```

## 🔧 Deployment Scripts

### Complete Deployment Script

```bash
#!/bin/bash
# deploy-edtech-platform.sh
# Complete deployment script for EdTech platform

set -euo pipefail

# Configuration
NAMESPACE="edtech-production"
CLUSTER_NAME="edtech-cluster"
ENVIRONMENT="production"
VERSION="${1:-latest}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

# Pre-deployment checks
pre_deployment_checks() {
    log "Running pre-deployment checks..."
    
    # Check kubectl connectivity
    if ! kubectl cluster-info &>/dev/null; then
        error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    # Check namespace
    if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
        log "Creating namespace $NAMESPACE..."
        kubectl create namespace "$NAMESPACE"
    fi
    
    # Check required secrets
    required_secrets=("database-secret" "jwt-secret" "encryption-key" "external-api-keys" "redis-secret")
    for secret in "${required_secrets[@]}"; do
        if ! kubectl get secret "$secret" -n "$NAMESPACE" &>/dev/null; then
            error "Required secret '$secret' not found in namespace '$NAMESPACE'"
            error "Please create required secrets before deployment"
            exit 1
        fi
    done
    
    # Check storage class
    if ! kubectl get storageclass fast-ssd &>/dev/null; then
        warn "Storage class 'fast-ssd' not found. Database may use default storage class."
    fi
    
    log "Pre-deployment checks completed successfully"
}

# Deploy database
deploy_database() {
    log "Deploying PostgreSQL database..."
    
    kubectl apply -f database.yaml
    
    # Wait for database to be ready
    log "Waiting for database to be ready..."
    kubectl rollout status statefulset/postgres-primary -n "$NAMESPACE" --timeout=300s
    
    # Test database connectivity
    log "Testing database connectivity..."
    if kubectl exec -n "$NAMESPACE" statefulset/postgres-primary -- pg_isready -U postgres; then
        log "Database is ready and accepting connections"
    else
        error "Database is not responding"
        exit 1
    fi
}

# Deploy Redis
deploy_redis() {
    log "Deploying Redis cache..."
    
    kubectl apply -f redis.yaml
    
    # Wait for Redis to be ready
    log "Waiting for Redis to be ready..."
    kubectl rollout status deployment/redis -n "$NAMESPACE" --timeout=300s
    
    # Test Redis connectivity
    log "Testing Redis connectivity..."
    redis_password=$(kubectl get secret redis-secret -n "$NAMESPACE" -o jsonpath='{.data.password}' | base64 -d)
    if kubectl exec -n "$NAMESPACE" deployment/redis -- redis-cli -a "$redis_password" ping | grep -q PONG; then
        log "Redis is ready and accepting connections"
    else
        error "Redis is not responding"
        exit 1
    fi
}

# Deploy application services
deploy_services() {
    log "Deploying application services..."
    
    # Update image tags if version specified
    if [ "$VERSION" != "latest" ]; then
        log "Updating image tags to version $VERSION..."
        sed -i.bak "s/:v[0-9]\+\.[0-9]\+\.[0-9]\+/:$VERSION/g" user-service.yaml
        # Add similar sed commands for other services
    fi
    
    # Deploy services in order
    services=("user-service" "exam-service" "notification-service" "payment-service")
    
    for service in "${services[@]}"; do
        log "Deploying $service..."
        kubectl apply -f "${service}.yaml" 2>/dev/null || {
            # If service-specific file doesn't exist, it might be in user-service.yaml
            log "Service file ${service}.yaml not found, checking user-service.yaml..."
        }
        
        # Wait for deployment to be ready
        if kubectl get deployment "$service" -n "$NAMESPACE" &>/dev/null; then
            kubectl rollout status deployment/"$service" -n "$NAMESPACE" --timeout=300s
            log "$service deployed successfully"
        fi
    done
}

# Deploy networking
deploy_networking() {
    log "Deploying network policies and ingress..."
    
    kubectl apply -f network-policies.yaml
    kubectl apply -f ingress.yaml
    
    # Wait for ingress to get IP
    log "Waiting for ingress to get external IP..."
    for i in {1..30}; do
        ingress_ip=$(kubectl get ingress edtech-platform-ingress -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
        if [ -n "$ingress_ip" ]; then
            log "Ingress IP: $ingress_ip"
            break
        fi
        sleep 10
    done
}

# Deploy monitoring
deploy_monitoring() {
    log "Deploying monitoring configuration..."
    
    kubectl apply -f monitoring.yaml
    
    log "Monitoring configured successfully"
}

# Post-deployment verification
post_deployment_verification() {
    log "Running post-deployment verification..."
    
    # Check all pods are running
    log "Checking pod status..."
    kubectl get pods -n "$NAMESPACE" -o wide
    
    # Check services
    log "Checking services..."
    kubectl get svc -n "$NAMESPACE"
    
    # Run health checks
    log "Running health checks..."
    
    # Get service IPs for health checks
    user_service_ip=$(kubectl get svc user-service -n "$NAMESPACE" -o jsonpath='{.spec.clusterIP}')
    
    # Port forward for health check
    kubectl port-forward svc/user-service 8080:80 -n "$NAMESPACE" &
    port_forward_pid=$!
    sleep 5
    
    if curl -f http://localhost:8080/health/ready &>/dev/null; then
        log "User service health check passed"
    else
        warn "User service health check failed"
    fi
    
    kill $port_forward_pid 2>/dev/null || true
    
    # Check HPA status
    log "Checking HPA status..."
    kubectl get hpa -n "$NAMESPACE"
    
    # Check PDB status
    log "Checking PDB status..."
    kubectl get pdb -n "$NAMESPACE"
    
    log "Post-deployment verification completed"
}

# Cleanup function
cleanup() {
    if [ -n "${port_forward_pid:-}" ]; then
        kill "$port_forward_pid" 2>/dev/null || true
    fi
}
trap cleanup EXIT

# Main deployment process
main() {
    log "Starting EdTech platform deployment..."
    log "Version: $VERSION"
    log "Namespace: $NAMESPACE"
    log "Environment: $ENVIRONMENT"
    
    pre_deployment_checks
    
    # Deploy in dependency order
    deploy_database
    deploy_redis
    deploy_services
    deploy_networking
    deploy_monitoring
    
    post_deployment_verification
    
    log "🎉 EdTech platform deployment completed successfully!"
    log "🌐 Platform should be accessible via the configured ingress endpoints"
    log "📊 Monitor the deployment using kubectl get pods -n $NAMESPACE --watch"
}

# Run main function
main "$@"
```

## 🔗 Usage Instructions

### Quick Start

1. **Prepare secrets** (use external secrets management in production):
```bash
# Create namespace
kubectl create namespace edtech-production

# Create required secrets (example - use external secrets in production)
kubectl create secret generic database-secret \
  --from-literal=username=edtech_user \
  --from-literal=password=secure_password \
  --from-literal=url=postgresql://edtech_user:secure_password@postgres-primary:5432/edtech_production \
  -n edtech-production

kubectl create secret generic jwt-secret \
  --from-literal=private-key="$(openssl genrsa 2048)" \
  --from-literal=public-key="$(openssl rsa -pubout)" \
  --from-literal=key-id=prod-key-1 \
  -n edtech-production
```

2. **Deploy the platform**:
```bash
# Make script executable
chmod +x deploy-edtech-platform.sh

# Deploy with specific version
./deploy-edtech-platform.sh v2.1.0

# Or deploy latest
./deploy-edtech-platform.sh
```

3. **Monitor deployment**:
```bash
# Watch pods
kubectl get pods -n edtech-production --watch

# Check services
kubectl get svc -n edtech-production

# View logs
kubectl logs -f deployment/user-service -n edtech-production
```

### Customization

- **Environment-specific configurations**: Modify ConfigMaps and resource limits based on your environment
- **Security policies**: Adjust network policies and RBAC based on your security requirements
- **Scaling**: Modify HPA settings and resource requests/limits based on your traffic patterns
- **Storage**: Update storage classes and sizes based on your storage requirements

---

### 🔗 Navigation
- [← Back to Main Research](./README.md)
- [← Previous: Troubleshooting](./troubleshooting.md)