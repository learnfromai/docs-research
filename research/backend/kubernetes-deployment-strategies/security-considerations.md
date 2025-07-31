# Security Considerations: Kubernetes Deployment Strategies

> **Comprehensive security patterns, compliance guidelines, and best practices for EdTech platforms**

## 🛡️ Security Overview

This document provides detailed security considerations for Kubernetes deployments in EdTech environments, focusing on data protection, compliance requirements, and threat mitigation strategies specific to educational platforms handling student data.

## 🎯 EdTech Security Requirements

### Regulatory Compliance Framework

| Regulation | Scope | Key Requirements | Implementation Priority |
|------------|-------|------------------|------------------------|
| **FERPA (US)** | Student educational records | Data encryption, access controls, audit trails | High |
| **GDPR (EU)** | Personal data of EU students | Consent management, data portability, right to erasure | High |
| **COPPA (US)** | Children under 13 | Parental consent, minimal data collection | Medium |
| **SOC 2 Type II** | Service organization controls | Security, availability, confidentiality | High |
| **PCI DSS** | Payment card data | Secure payment processing | High |
| **ISO 27001** | Information security management | Comprehensive security framework | Medium |

### Data Classification for EdTech

```yaml
# Data classification labels for Kubernetes resources
metadata:
  labels:
    data-classification: "confidential"    # Student records, grades
    data-type: "pii"                      # Personally identifiable information
    retention-period: "7-years"           # FERPA requirement
    geography: "us-only"                  # Data residency requirement
  annotations:
    compliance.edtech/ferpa: "required"
    compliance.edtech/encryption: "aes-256"
    compliance.edtech/audit: "enabled"
```

## 🔐 Pod Security Standards

### Restricted Pod Security Policy

```yaml
# Pod Security Standards - Restricted Profile
apiVersion: v1
kind: Pod
metadata:
  name: edtech-api-secure
  namespace: production
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
spec:
  # Security context at pod level
  securityContext:
    runAsNonRoot: true                    # Never run as root
    runAsUser: 65534                      # Use nobody user
    runAsGroup: 65534                     # Use nobody group
    fsGroup: 65534                        # File system group
    supplementalGroups: [65534]           # Additional groups
    
    # Secure defaults
    seccompProfile:
      type: RuntimeDefault               # Enable seccomp
    
    # Prevent privilege escalation
    allowPrivilegeEscalation: false
    
    # Drop all capabilities
    capabilities:
      drop: ["ALL"]
  
  containers:
  - name: api
    image: edtech/api:v1.3.0-distroless   # Use distroless images
    
    # Container security context
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true        # Immutable container filesystem
      runAsNonRoot: true
      runAsUser: 65534
      capabilities:
        drop: ["ALL"]                     # Drop all Linux capabilities
        # Add only required capabilities
        # add: ["NET_BIND_SERVICE"]       # Only if binding to port < 1024
    
    # Resource limits for security
    resources:
      limits:
        cpu: 1000m
        memory: 512Mi
        ephemeral-storage: 100Mi          # Limit temp storage
      requests:
        cpu: 100m
        memory: 128Mi
        ephemeral-storage: 50Mi
    
    # Secure volume mounts
    volumeMounts:
    - name: tmp-volume
      mountPath: /tmp
      readOnly: false
    - name: cache-volume
      mountPath: /app/cache
      readOnly: false
    - name: config-volume
      mountPath: /app/config
      readOnly: true                      # Configuration is read-only
    
    # Environment variables from secrets only
    env:
    - name: DATABASE_URL
      valueFrom:
        secretKeyRef:
          name: database-secret
          key: url
    - name: ENCRYPTION_KEY
      valueFrom:
        secretKeyRef:
          name: encryption-secret
          key: key
    
    # Health checks with security considerations
    livenessProbe:
      httpGet:
        path: /health/live
        port: 8080                        # Use non-privileged port
        httpHeaders:
        - name: X-Health-Check
          value: "internal"
      initialDelaySeconds: 30
      periodSeconds: 10
      timeoutSeconds: 5
      failureThreshold: 3
    
    readinessProbe:
      httpGet:
        path: /health/ready
        port: 8080
        httpHeaders:
        - name: X-Health-Check
          value: "internal"
      initialDelaySeconds: 10
      periodSeconds: 5
      timeoutSeconds: 3
      failureThreshold: 3
  
  # Secure volumes
  volumes:
  - name: tmp-volume
    emptyDir:
      sizeLimit: 100Mi
      medium: Memory                      # Use memory for temp files
  - name: cache-volume
    emptyDir:
      sizeLimit: 200Mi
  - name: config-volume
    configMap:
      name: app-config
      defaultMode: 0444                   # Read-only permissions
  
  # Pod-level security constraints
  automountServiceAccountToken: false     # Don't mount SA token unless needed
  hostNetwork: false                      # Never use host network
  hostPID: false                          # Never use host PID
  hostIPC: false                          # Never use host IPC
  
  # DNS and networking
  dnsPolicy: ClusterFirst
  dnsConfig:
    options:
    - name: ndots
      value: "2"
    - name: edns0
```

### Pod Security Policy Enforcement

```yaml
# Pod Security Policy for production workloads
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: edtech-restricted-psp
  annotations:
    seccomp.security.alpha.kubernetes.io/allowedProfileNames: 'runtime/default'
    apparmor.security.beta.kubernetes.io/allowedProfileNames: 'runtime/default'
    seccomp.security.alpha.kubernetes.io/defaultProfileName: 'runtime/default'
    apparmor.security.beta.kubernetes.io/defaultProfileName: 'runtime/default'
spec:
  # Prevent privilege escalation
  privileged: false
  allowPrivilegeEscalation: false
  requiredDropCapabilities:
    - ALL
  
  # Volume restrictions
  volumes:
    - 'configMap'
    - 'emptyDir'
    - 'projected'
    - 'secret'
    - 'persistentVolumeClaim'
  
  # Host restrictions
  hostNetwork: false
  hostIPC: false
  hostPID: false
  hostPorts:
  - min: 0
    max: 0
  
  # User restrictions
  runAsUser:
    rule: 'MustRunAsNonRoot'
  runAsGroup:
    rule: 'MustRunAs'
    ranges:
    - min: 1000
      max: 65535
  
  # File system restrictions
  readOnlyRootFilesystem: true
  fsGroup:
    rule: 'RunAsAny'
  
  # SELinux/AppArmor
  seLinux:
    rule: 'RunAsAny'
  supplementalGroups:
    rule: 'MustRunAs'
    ranges:
    - min: 1000
      max: 65535

---
# ClusterRole for PSP
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: edtech-restricted-psp-user
rules:
- apiGroups: ['policy']
  resources: ['podsecuritypolicies']
  verbs: ['use']
  resourceNames:
  - edtech-restricted-psp

---
# RoleBinding for developers
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: edtech-developers-psp
  namespace: production
roleRef:
  kind: ClusterRole
  name: edtech-restricted-psp-user
  apiGroup: rbac.authorization.k8s.io
subjects:
- kind: ServiceAccount
  name: edtech-api-sa
  namespace: production
```

## 🌐 Network Security

### Network Policies for Microsegmentation

```yaml
# Comprehensive network policy for EdTech microservices
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: edtech-api-network-policy
  namespace: production
  labels:
    tier: api
    security-level: high
spec:
  podSelector:
    matchLabels:
      app: edtech-api
      tier: backend
  
  policyTypes:
  - Ingress
  - Egress
  
  # Ingress rules - what can connect TO this service
  ingress:
  # Allow ingress controller
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
    - podSelector:
        matchLabels:
          app: nginx-ingress
    ports:
    - protocol: TCP
      port: 8080
  
  # Allow inter-service communication within namespace
  - from:
    - namespaceSelector:
        matchLabels:
          name: production
    - podSelector:
        matchLabels:
          tier: backend
    ports:
    - protocol: TCP
      port: 8080
  
  # Allow monitoring systems
  - from:
    - namespaceSelector:
        matchLabels:
          name: monitoring
    - podSelector:
        matchLabels:
          app: prometheus
    ports:
    - protocol: TCP
      port: 9090  # Metrics port
  
  # Egress rules - what this service can connect TO
  egress:
  # Allow database connections
  - to:
    - podSelector:
        matchLabels:
          app: postgres
          tier: database
    ports:
    - protocol: TCP
      port: 5432
  
  # Allow Redis connections
  - to:
    - podSelector:
        matchLabels:
          app: redis
          tier: cache
    ports:
    - protocol: TCP
      port: 6379
  
  # Allow DNS resolution
  - to: []
    ports:
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53
  
  # Allow HTTPS to external APIs (payment, email, etc.)
  - to: []
    ports:
    - protocol: TCP
      port: 443
  
  # Allow NTP for time synchronization
  - to: []
    ports:
    - protocol: UDP
      port: 123

---
# Database isolation network policy
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: database-isolation
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: postgres
      tier: database
  
  policyTypes:
  - Ingress
  - Egress
  
  ingress:
  # Only allow API services to connect to database
  - from:
    - podSelector:
        matchLabels:
          tier: backend
    ports:
    - protocol: TCP
      port: 5432
  
  # Allow backup jobs
  - from:
    - podSelector:
        matchLabels:
          app: database-backup
    ports:
    - protocol: TCP
      port: 5432
  
  egress:
  # DNS only
  - to: []
    ports:
    - protocol: UDP
      port: 53
  
  # NTP for time sync
  - to: []
    ports:
    - protocol: UDP
      port: 123

---
# Default deny-all network policy
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: production
spec:
  podSelector: {}  # Apply to all pods in namespace
  policyTypes:
  - Ingress
  - Egress
  # No rules = deny all
```

### Service Mesh Security with Istio

```yaml
# Istio security policies for EdTech platform
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: production
spec:
  # Require mTLS for all services in production
  mtls:
    mode: STRICT

---
# Authorization policy for API access
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: api-access-control
  namespace: production
spec:
  selector:
    matchLabels:
      app: edtech-api
  
  # Allow authenticated requests only
  rules:
  - from:
    - source:
        principals: 
        - "cluster.local/ns/production/sa/frontend-service"
        - "cluster.local/ns/production/sa/mobile-app-service"
    to:
    - operation:
        methods: ["GET", "POST", "PUT", "DELETE"]
        paths: ["/api/v1/*"]
    when:
    - key: request.headers[authorization]
      values: ["Bearer *"]  # Require Bearer token

---
# Database access authorization
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: database-access-control
  namespace: production
spec:
  selector:
    matchLabels:
      app: postgres
  
  rules:
  # Only backend services can access database
  - from:
    - source:
        principals:
        - "cluster.local/ns/production/sa/user-service"
        - "cluster.local/ns/production/sa/exam-service"
        - "cluster.local/ns/production/sa/notification-service"
    to:
    - operation:
        ports: ["5432"]

---
# External service security
apiVersion: security.istio.io/v1beta1
kind: ServiceEntry
metadata:
  name: external-payment-api
  namespace: production
spec:
  hosts:
  - api.stripe.com
  ports:
  - number: 443
    name: https
    protocol: HTTPS
  location: MESH_EXTERNAL
  resolution: DNS

---
apiVersion: security.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: stripe-api-tls
  namespace: production
spec:
  host: api.stripe.com
  trafficPolicy:
    tls:
      mode: SIMPLE  # Use TLS without client certificate
      minProtocolVersion: TLSV1_2
      maxProtocolVersion: TLSV1_3
```

## 🔑 Identity and Access Management (IAM)

### RBAC Configuration

```yaml
# Service Account for API services
apiVersion: v1
kind: ServiceAccount
metadata:
  name: edtech-api-sa
  namespace: production
  labels:
    app: edtech-api
  annotations:
    description: "Service account for EdTech API services"
automountServiceAccountToken: false  # Explicit control

---
# Role for API service operations
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: production
  name: edtech-api-role
  labels:
    rbac.edtech.io/role: "api-service"
rules:
# ConfigMap access for configuration
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get", "list", "watch"]
  resourceNames: ["app-config", "feature-flags"]

# Secret access for database credentials
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get"]
  resourceNames: ["database-secret", "jwt-secret", "encryption-key"]

# Pod information for health checks
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
  resourceNames: []

# Event creation for audit logging
- apiGroups: [""]
  resources: ["events"]
  verbs: ["create"]

---
# RoleBinding to associate ServiceAccount with Role
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: edtech-api-binding
  namespace: production
  labels:
    rbac.edtech.io/binding: "api-service"
subjects:
- kind: ServiceAccount
  name: edtech-api-sa
  namespace: production
roleRef:
  kind: Role
  name: edtech-api-role
  apiGroup: rbac.authorization.k8s.io

---
# ClusterRole for cross-namespace service discovery
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: edtech-service-discovery
  labels:
    rbac.edtech.io/scope: "cluster"
rules:
# Service discovery across namespaces
- apiGroups: [""]
  resources: ["services", "endpoints"]
  verbs: ["get", "list", "watch"]

# Node information for placement decisions
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["get", "list"]

---
# Developer access control
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: development
  name: developer-role
rules:
# Full access in development namespace
- apiGroups: ["", "apps", "extensions"]
  resources: ["*"]
  verbs: ["*"]

# Limited access to secrets
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list"]
  resourceNames: ["dev-database-secret"]

---
# Production read-only access for developers
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: production
  name: developer-readonly-role
rules:
# Read-only access to most resources
- apiGroups: ["", "apps", "extensions"]
  resources: ["pods", "services", "deployments", "configmaps"]
  verbs: ["get", "list", "watch"]

# Log access
- apiGroups: [""]
  resources: ["pods/log"]
  verbs: ["get", "list"]

# No secret access in production
- apiGroups: [""]
  resources: ["secrets"]
  verbs: []
```

### JWT Authentication and Authorization

```javascript
// JWT security implementation for EdTech platform
const jwt = require('jsonwebtoken');
const crypto = require('crypto');

class EdTechJWTManager {
  constructor() {
    this.publicKey = process.env.JWT_PUBLIC_KEY;
    this.privateKey = process.env.JWT_PRIVATE_KEY;
    this.issuer = 'edtech-platform.com';
    this.audience = ['api.edtech-platform.com', 'app.edtech-platform.com'];
  }
  
  // Generate secure JWT token
  generateToken(user, permissions = []) {
    const payload = {
      // Standard claims
      iss: this.issuer,
      aud: this.audience,
      sub: user.id,
      iat: Math.floor(Date.now() / 1000),
      exp: Math.floor(Date.now() / 1000) + (15 * 60), // 15 minutes
      
      // Custom claims for EdTech
      role: user.role,
      permissions: permissions,
      student_id: user.studentId,
      institution_id: user.institutionId,
      data_classification: this.getDataClassification(user.role),
      
      // Security features
      jti: crypto.randomUUID(), // Unique token ID for revocation
      token_type: 'access',
      
      // FERPA compliance
      ferpa_consent: user.ferpaConsent || false,
      data_retention_period: this.getRetentionPeriod(user.role),
    };
    
    const options = {
      algorithm: 'RS256',
      keyid: process.env.JWT_KEY_ID,
    };
    
    return jwt.sign(payload, this.privateKey, options);
  }
  
  // Generate refresh token
  generateRefreshToken(user) {
    const payload = {
      iss: this.issuer,
      aud: this.audience,
      sub: user.id,
      iat: Math.floor(Date.now() / 1000),
      exp: Math.floor(Date.now() / 1000) + (7 * 24 * 60 * 60), // 7 days
      token_type: 'refresh',
      jti: crypto.randomUUID(),
    };
    
    return jwt.sign(payload, this.privateKey, { algorithm: 'RS256' });
  }
  
  // Verify and decode token
  verifyToken(token) {
    try {
      const decoded = jwt.verify(token, this.publicKey, {
        algorithms: ['RS256'],
        issuer: this.issuer,
        audience: this.audience,
      });
      
      // Additional security checks
      this.validateTokenClaims(decoded);
      
      return decoded;
    } catch (error) {
      throw new Error(`Token verification failed: ${error.message}`);
    }
  }
  
  validateTokenClaims(token) {
    // Check token type
    if (!['access', 'refresh'].includes(token.token_type)) {
      throw new Error('Invalid token type');
    }
    
    // Validate permissions format
    if (token.permissions && !Array.isArray(token.permissions)) {
      throw new Error('Invalid permissions format');
    }
    
    // FERPA compliance check
    if (token.role === 'student' && !token.ferpa_consent) {
      throw new Error('FERPA consent required for student access');
    }
    
    // Check for token revocation (integrate with Redis/database)
    if (this.isTokenRevoked(token.jti)) {
      throw new Error('Token has been revoked');
    }
  }
  
  // Permission-based authorization middleware
  requirePermissions(...requiredPermissions) {
    return (req, res, next) => {
      try {
        const authHeader = req.headers.authorization;
        if (!authHeader || !authHeader.startsWith('Bearer ')) {
          return res.status(401).json({ error: 'Missing or invalid authorization header' });
        }
        
        const token = authHeader.substring(7);
        const decoded = this.verifyToken(token);
        
        // Check permissions
        const userPermissions = decoded.permissions || [];
        const hasPermission = requiredPermissions.every(permission => 
          userPermissions.includes(permission) || 
          userPermissions.includes('admin:all')
        );
        
        if (!hasPermission) {
          return res.status(403).json({ 
            error: 'Insufficient permissions',
            required: requiredPermissions,
            granted: userPermissions
          });
        }
        
        // Add user context to request
        req.user = {
          id: decoded.sub,
          role: decoded.role,
          permissions: decoded.permissions,
          studentId: decoded.student_id,
          institutionId: decoded.institution_id,
          dataClassification: decoded.data_classification
        };
        
        next();
      } catch (error) {
        return res.status(401).json({ error: error.message });
      }
    };
  }
  
  getDataClassification(role) {
    const classifications = {
      'student': 'confidential',
      'instructor': 'internal',
      'admin': 'restricted',
      'parent': 'confidential'
    };
    return classifications[role] || 'public';
  }
  
  getRetentionPeriod(role) {
    // FERPA requires 7 years retention for educational records
    return role === 'student' ? '7-years' : '3-years';
  }
}

// Usage in Express middleware
const jwtManager = new EdTechJWTManager();

// Protect exam endpoints
app.get('/api/exams/:id', 
  jwtManager.requirePermissions('exam:read', 'student:active'),
  async (req, res) => {
    // Access granted, implement exam logic
    const exam = await getExam(req.params.id, req.user);
    res.json(exam);
  }
);

// Admin-only endpoints
app.post('/api/admin/users',
  jwtManager.requirePermissions('admin:user:create'),
  async (req, res) => {
    // Admin access required
    const newUser = await createUser(req.body, req.user);
    res.json(newUser);
  }
);
```

## 🔒 Secret Management

### HashiCorp Vault Integration

```yaml
# Vault configuration for Kubernetes
apiVersion: v1
kind: ConfigMap
metadata:
  name: vault-config
  namespace: vault
data:
  vault.hcl: |
    ui = true
    
    listener "tcp" {
      address = "0.0.0.0:8200"
      tls_disable = false
      tls_cert_file = "/vault/tls/server.crt"
      tls_key_file = "/vault/tls/server.key"
    }
    
    storage "consul" {
      address = "consul:8500"
      path = "vault/"
      ha_enabled = "true"
      lock_timeout = "30s"
    }
    
    # Enable Kubernetes auth
    auth "kubernetes" {
      kubernetes_host = "https://kubernetes.default.svc"
      kubernetes_ca_cert = "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
      token_reviewer_jwt = "/var/run/secrets/kubernetes.io/serviceaccount/token"
    }
    
    # Database secrets engine
    secrets "database" {
      path = "database/"
      default_ttl = "1h"
      max_ttl = "24h"
    }
    
    # PKI for TLS certificates
    secrets "pki" {
      path = "pki/"
      default_ttl = "8760h"  # 1 year
      max_ttl = "17520h"     # 2 years
    }

---
# Vault Secret Operator for automatic secret management
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultDynamicSecret
metadata:
  name: database-credentials
  namespace: production
spec:
  mount: database
  path: creds/edtech-production
  destination:
    name: database-secret
    create: true
  rolloutRestartTargets:
  - kind: Deployment
    name: edtech-api

---
# Vault authentication for service accounts
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultAuth
metadata:
  name: vault-auth
  namespace: production
spec:
  method: kubernetes
  mount: kubernetes
  kubernetes:
    role: edtech-api
    serviceAccount: edtech-api-sa
```

### External Secrets Operator

```yaml
# External Secrets Operator configuration
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: vault-secret-store
  namespace: production
spec:
  provider:
    vault:
      server: "https://vault.vault.svc.cluster.local:8200"
      path: "secret"
      version: "v2"
      auth:
        kubernetes:
          mountPath: "kubernetes"
          role: "edtech-api"
          serviceAccountRef:
            name: "edtech-api-sa"

---
# External Secret for database credentials
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: database-external-secret
  namespace: production
spec:
  refreshInterval: 1h  # Refresh every hour
  secretStoreRef:
    name: vault-secret-store
    kind: SecretStore
  
  target:
    name: database-secret
    creationPolicy: Owner
    template:
      type: Opaque
      data:
        username: "{{ .username }}"
        password: "{{ .password }}"
        url: "postgresql://{{ .username }}:{{ .password }}@postgres:5432/edtech_production?sslmode=require"
  
  data:
  - secretKey: username
    remoteRef:
      key: database/production
      property: username
  - secretKey: password
    remoteRef:
      key: database/production
      property: password

---
# External Secret for JWT signing keys
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: jwt-keys-external-secret
  namespace: production
spec:
  refreshInterval: 24h  # Refresh daily
  secretStoreRef:
    name: vault-secret-store
    kind: SecretStore
  
  target:
    name: jwt-secret
    template:
      type: Opaque
      data:
        private-key: "{{ .private_key }}"
        public-key: "{{ .public_key }}"
        key-id: "{{ .key_id }}"
  
  data:
  - secretKey: private_key
    remoteRef:
      key: jwt/production
      property: private_key
  - secretKey: public_key
    remoteRef:
      key: jwt/production
      property: public_key
  - secretKey: key_id
    remoteRef:
      key: jwt/production
      property: key_id
```

## 🔍 Security Monitoring and Audit

### Audit Logging Configuration

```yaml
# Kubernetes audit policy for EdTech compliance
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
# Log requests to sensitive resources at Request level
- level: Request
  namespaces: ["production", "staging"]
  resources:
  - group: ""
    resources: ["secrets", "configmaps"]
  - group: ""
    resources: ["pods/exec", "pods/attach", "pods/portforward"]
  
# Log metadata for normal operations
- level: Metadata
  resources:
  - group: ""
    resources: ["pods", "services"]
  - group: "apps"
    resources: ["deployments", "replicasets"]
  
# Log RBAC changes at Request level
- level: Request
  resources:
  - group: "rbac.authorization.k8s.io"
    resources: ["roles", "rolebindings", "clusterroles", "clusterrolebindings"]
  
# Don't log routine operations
- level: None
  users: ["system:kube-proxy"]
  verbs: ["watch"]
  resources:
  - group: ""
    resources: ["endpoints", "services"]

---
# Falco security monitoring rules
apiVersion: v1
kind: ConfigMap
metadata:
  name: falco-config
  namespace: falco
data:
  falco_rules.yaml: |
    # EdTech-specific security rules
    
    # Detect sensitive file access in containers
    - rule: Read sensitive file untrusted
      desc: an attempt to read any sensitive file (e.g. files containing user/password/authentication information)
      condition: >
        sensitive_files and open_read
        and proc_name_exists
        and not proc.name in (trusted_binaries)
        and not container.image.repository in (trusted_images)
      output: >
        Sensitive file opened for reading by non-trusted program (user=%user.name 
        command=%proc.cmdline file=%fd.name parent=%proc.pname container_id=%container.id image=%container.image.repository)
      priority: WARNING
    
    # Detect privilege escalation attempts
    - rule: Set Setuid or Setgid bit
      desc: detect setuid or setgid bit set via chmod
      condition: >
        chmod and (evt.arg.mode contains "S_ISUID" or evt.arg.mode contains "S_ISGID")
        and not container.image.repository in (trusted_images)
      output: >
        Setuid or setgid bit is set via chmod (user=%user.name command=%proc.cmdline 
        file=%evt.arg.filename mode=%evt.arg.mode container_id=%container.id)
      priority: NOTICE
    
    # Detect network connections to suspicious hosts
    - rule: Outbound Connection to Suspicious Host
      desc: detect outbound connection to suspicious IP addresses
      condition: >
        outbound and fd.sip in (suspicious_ips)
        and not container.image.repository in (trusted_images)
      output: >
        Outbound connection to suspicious host (user=%user.name command=%proc.cmdline 
        connection=%fd.name container_id=%container.id image=%container.image.repository)
      priority: WARNING
    
    # EdTech-specific: Detect unauthorized access to student data
    - rule: Unauthorized Student Data Access
      desc: detect access to student data by unauthorized processes
      condition: >
        open_read and fd.name contains "/student-data/"
        and not proc.name in (authorized_student_data_readers)
        and not container.image.repository in (trusted_edtech_images)
      output: >
        Unauthorized access to student data (user=%user.name command=%proc.cmdline 
        file=%fd.name container_id=%container.id image=%container.image.repository)
      priority: CRITICAL

  falco.yaml: |
    # Falco configuration
    rules_file:
    - /etc/falco/falco_rules.yaml
    - /etc/falco/k8s_audit_rules.yaml
    
    # Output channels
    json_output: true
    json_include_output_property: true
    
    # Kubernetes audit integration
    k8s_audit_endpoint: /k8s-audit
    
    # Grpc output for real-time alerts
    grpc:
      enabled: true
      bind_address: "0.0.0.0:5060"
      threadiness: 8
    
    # Program output for log shipping
    program_output:
      enabled: true
      keep_alive: true
      program: "curl -X POST http://security-webhook:8080/alerts -H 'Content-Type: application/json' -d @-"
```

### Security Incident Response

```javascript
// Security incident response automation
class SecurityIncidentHandler {
  constructor() {
    this.alertChannels = {
      slack: process.env.SLACK_WEBHOOK_URL,
      email: process.env.SECURITY_EMAIL,
      pagerduty: process.env.PAGERDUTY_INTEGRATION_KEY
    };
    
    this.severityThresholds = {
      CRITICAL: 0,      // Immediate response
      HIGH: 300,        // 5 minutes
      MEDIUM: 1800,     // 30 minutes
      LOW: 3600         // 1 hour
    };
  }
  
  async handleSecurityAlert(alert) {
    const incident = await this.processAlert(alert);
    
    // Classify incident severity
    const severity = this.classifyIncident(incident);
    
    // Immediate response for critical incidents
    if (severity === 'CRITICAL') {
      await this.executeEmergencyResponse(incident);
    }
    
    // Send notifications
    await this.notifySecurityTeam(incident, severity);
    
    // Start automated containment if applicable
    if (this.canAutoContain(incident)) {
      await this.initiateContainment(incident);
    }
    
    // Create incident record
    await this.createIncidentRecord(incident, severity);
    
    return incident;
  }
  
  classifyIncident(incident) {
    // Critical: Data breach, privilege escalation, unauthorized admin access
    if (incident.type === 'data_breach' || 
        incident.type === 'privilege_escalation' ||
        incident.tags.includes('student_data_access')) {
      return 'CRITICAL';
    }
    
    // High: Suspicious network activity, failed authentication spikes
    if (incident.type === 'suspicious_network' || 
        incident.type === 'auth_failure_spike') {
      return 'HIGH';
    }
    
    // Medium: Policy violations, unusual access patterns
    if (incident.type === 'policy_violation' || 
        incident.type === 'unusual_access') {
      return 'MEDIUM';
    }
    
    return 'LOW';
  }
  
  async executeEmergencyResponse(incident) {
    console.log(`🚨 CRITICAL SECURITY INCIDENT: ${incident.title}`);
    
    // For student data breaches - immediate containment
    if (incident.tags.includes('student_data_access')) {
      await this.containStudentDataBreach(incident);
    }
    
    // For privilege escalation - isolate affected systems
    if (incident.type === 'privilege_escalation') {
      await this.isolateAffectedPods(incident.affected_pods);
    }
    
    // Immediate notification to security team
    await this.sendCriticalAlert(incident);
  }
  
  async containStudentDataBreach(incident) {
    // FERPA compliance requires immediate action
    
    // 1. Isolate affected services
    for (const podName of incident.affected_pods) {
      await this.quarantinePod(podName);
    }
    
    // 2. Revoke potentially compromised tokens
    if (incident.compromised_tokens) {
      await this.revokeTokens(incident.compromised_tokens);
    }
    
    // 3. Enable enhanced monitoring
    await this.enableEnhancedMonitoring(incident.affected_services);
    
    // 4. Prepare breach notification templates
    await this.prepareBreadchNotification(incident);
    
    console.log('✅ Student data breach containment measures activated');
  }
  
  async quarantinePod(podName) {
    // Create network policy to isolate pod
    const quarantinePolicy = {
      apiVersion: 'networking.k8s.io/v1',
      kind: 'NetworkPolicy',
      metadata: {
        name: `quarantine-${podName}`,
        namespace: 'production',
        labels: {
          'security.edtech.io/quarantine': 'true',
          'incident.id': `incident-${Date.now()}`
        }
      },
      spec: {
        podSelector: {
          matchLabels: {
            'app': podName
          }
        },
        policyTypes: ['Ingress', 'Egress'],
        // No ingress or egress rules = deny all
      }
    };
    
    // Apply quarantine policy
    await this.applyNetworkPolicy(quarantinePolicy);
    
    // Scale down deployment to prevent spread
    await this.scaleDownDeployment(podName, 0);
    
    console.log(`🔒 Pod ${podName} quarantined`);
  }
  
  async prepareBreadchNotification(incident) {
    // FERPA requires notification within 24 hours
    const notification = {
      incident_id: incident.id,
      discovery_time: new Date().toISOString(),
      affected_records: incident.affected_student_count || 'Unknown',
      data_types: incident.compromised_data_types || ['PII', 'Educational Records'],
      containment_measures: [
        'Affected systems isolated',
        'Access tokens revoked',
        'Enhanced monitoring enabled'
      ],
      next_steps: [
        'Forensic analysis in progress',
        'Affected users will be notified within 24 hours',
        'Additional security measures being implemented'
      ]
    };
    
    // Store for compliance officer review
    await this.storeBreachNotification(notification);
    
    return notification;
  }
}

// Integration with Kubernetes events
const securityHandler = new SecurityIncidentHandler();

// Example usage with Falco alerts
app.post('/security/alerts', async (req, res) => {
  try {
    const falcoAlert = req.body;
    
    // Convert Falco alert to internal incident format
    const incident = {
      id: crypto.randomUUID(),
      title: falcoAlert.rule,
      description: falcoAlert.output,
      type: falcoAlert.rule.toLowerCase().replace(/\s+/g, '_'),
      severity: falcoAlert.priority,
      timestamp: new Date(falcoAlert.time),
      source: 'falco',
      affected_pods: [falcoAlert.output_fields?.container_id],
      tags: falcoAlert.tags || [],
      raw_data: falcoAlert
    };
    
    // Handle the incident
    await securityHandler.handleSecurityAlert(incident);
    
    res.status(200).json({ status: 'processed', incident_id: incident.id });
  } catch (error) {
    console.error('Error processing security alert:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});
```

## 🔗 Next Steps

Complete your security implementation with:
- [Troubleshooting](./troubleshooting.md) - Security-related debugging and incident response
- [Template Examples](./template-examples.md) - Production-ready secure Kubernetes manifests

---

### 🔗 Navigation
- [← Back to Main Research](./README.md)
- [← Previous: Performance Analysis](./performance-analysis.md)
- [Next: Troubleshooting →](./troubleshooting.md)