# Security Considerations: Terraform with AWS/Kubernetes/EKS

This document consolidates security best practices and considerations learned from analyzing production open source projects.

## 🔐 Security Framework Overview

Security must be implemented at multiple layers:
- **Infrastructure Security** - AWS resources and networking
- **Cluster Security** - Kubernetes control plane and nodes
- **Application Security** - Workload and pod-level security
- **Identity & Access** - Authentication and authorization
- **Data Security** - Encryption and secrets management
- **Network Security** - Traffic control and isolation

## 🏗️ Infrastructure Security

### 1. **VPC and Network Security**

#### Secure Network Design
```hcl
# ✅ Best Practice: Private subnets for worker nodes
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  
  # Private subnets for EKS nodes (no direct internet access)
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  
  # Public subnets only for load balancers
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  
  # Enable NAT Gateway for private subnet internet access
  enable_nat_gateway = true
  
  # VPC Flow Logs for security monitoring
  enable_flow_log                      = true
  create_flow_log_cloudwatch_iam_role  = true
  create_flow_log_cloudwatch_log_group = true
  
  # DNS settings required for EKS
  enable_dns_hostnames = true
  enable_dns_support   = true
}

# VPC Endpoints for secure AWS service access
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = module.vpc.private_route_table_ids
}

resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnets
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  
  policy = jsonencode({
    Statement = [
      {
        Effect = "Allow"
        Principal = "*"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      }
    ]
  })
}
```

#### Security Group Configuration
```hcl
# Security group for VPC endpoints
resource "aws_security_group" "vpc_endpoints" {
  name_prefix = "${local.name}-vpc-endpoints"
  vpc_id      = module.vpc.vpc_id
  
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = merge(local.common_tags, {
    Name = "${local.name}-vpc-endpoints"
  })
}

# Additional security group rules for EKS
resource "aws_security_group_rule" "cluster_ingress_workstation_https" {
  description       = "Allow workstation to communicate with the cluster API Server"
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = var.workstation_cidr_blocks
  security_group_id = module.eks.cluster_security_group_id
}
```

### 2. **EKS Cluster Security**

#### Encryption Configuration
```hcl
# KMS key for EKS secrets encryption
resource "aws_kms_key" "eks" {
  description             = "EKS Secret Encryption Key"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow EKS Service"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey*",
          "kms:ReEncrypt*"
        ]
        Resource = "*"
      }
    ]
  })
  
  tags = local.common_tags
}

# EKS cluster with security best practices
module "eks" {
  source = "terraform-aws-modules/eks/aws"
  
  # Enable private endpoint access
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = var.cluster_endpoint_public_access
  
  # Restrict public access to specific CIDRs
  cluster_endpoint_public_access_cidrs = var.allowed_cidr_blocks
  
  # Enable encryption for secrets
  cluster_encryption_config = {
    provider_key_arn = aws_kms_key.eks.arn
    resources        = ["secrets"]
  }
  
  # Enable comprehensive logging
  cluster_enabled_log_types = [
    "api",
    "audit", 
    "authenticator",
    "controllerManager",
    "scheduler"
  ]
  
  # Service account token volume projection
  cluster_service_ipv4_cidr = var.cluster_service_cidr
  
  # Security groups
  create_cluster_security_group = true
  create_node_security_group    = true
}
```

#### Node Group Security
```hcl
eks_managed_node_groups = {
  secure = {
    # Use latest AMI with security patches
    ami_type = "AL2023_x86_64_STANDARD"
    
    # Encrypted storage
    disk_encrypted  = true
    disk_kms_key_id = aws_kms_key.eks.arn
    
    # Metadata service configuration
    metadata_options = {
      http_endpoint               = "enabled"
      http_tokens                 = "required"  # Require IMDSv2
      http_put_response_hop_limit = 2
      instance_metadata_tags      = "disabled"
    }
    
    # User data for additional hardening
    pre_bootstrap_user_data = <<-EOT
      #!/bin/bash
      # Additional security configurations
      echo 'net.ipv4.conf.all.log_martians = 1' >> /etc/sysctl.conf
      echo 'net.ipv4.conf.default.log_martians = 1' >> /etc/sysctl.conf
      sysctl -p
    EOT
    
    # Remote access configuration
    remote_access = {
      ec2_ssh_key = var.node_ssh_key_name
      source_security_group_ids = [aws_security_group.ssh_access.id]
    }
  }
}

# Restricted SSH access security group
resource "aws_security_group" "ssh_access" {
  name_prefix = "${local.name}-ssh-access"
  vpc_id      = module.vpc.vpc_id
  
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssh_allowed_cidr_blocks
  }
  
  tags = merge(local.common_tags, {
    Name = "${local.name}-ssh-access"
  })
}
```

## 🔑 Identity and Access Management

### 1. **IAM Roles for Service Accounts (IRSA)**

#### Secure Service Account Configuration
```hcl
# IRSA role for AWS Load Balancer Controller
module "aws_load_balancer_controller_irsa" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  
  role_name = "${local.name}-aws-load-balancer-controller"
  
  # Attach minimal required policy
  attach_load_balancer_controller_policy = true
  
  # Restrict to specific namespaces and service accounts
  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
  
  # Additional custom policy for fine-grained permissions
  role_policy_arns = {
    additional = aws_iam_policy.load_balancer_controller_additional.arn
  }
  
  tags = local.common_tags
}

# Custom policy with least privilege
resource "aws_iam_policy" "load_balancer_controller_additional" {
  name_prefix = "${local.name}-alb-controller-additional"
  description = "Additional permissions for ALB controller"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "wafv2:GetWebACL",
          "wafv2:GetWebACLForResource",
          "wafv2:AssociateWebACL",
          "wafv2:DisassociateWebACL"
        ]
        Resource = "*"
      }
    ]
  })
}

# External Secrets Operator IRSA
module "external_secrets_irsa" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  
  role_name = "${local.name}-external-secrets"
  
  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["external-secrets:external-secrets"]
    }
  }
  
  role_policy_arns = {
    policy = aws_iam_policy.external_secrets.arn
  }
}

resource "aws_iam_policy" "external_secrets" {
  name_prefix = "${local.name}-external-secrets"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:${var.environment}/*"
        ]
      }
    ]
  })
}
```

### 2. **RBAC Configuration**

#### Kubernetes RBAC Setup
```yaml
# restricted-service-account.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: restricted-service-account
  namespace: application
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT:role/restricted-role
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: application
  name: restricted-role
rules:
- apiGroups: [""]
  resources: ["pods", "services", "configmaps"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "watch", "create", "update", "patch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: restricted-binding
  namespace: application
subjects:
- kind: ServiceAccount
  name: restricted-service-account
  namespace: application
roleRef:
  kind: Role
  name: restricted-role
  apiGroup: rbac.authorization.k8s.io
```

#### Cluster Access Management
```hcl
# AWS auth configuration for user access
manage_aws_auth_configmap = true

aws_auth_roles = [
  {
    rolearn  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/EKSReadOnlyRole"
    username = "readonly-user"
    groups   = ["system:readonly"]
  },
  {
    rolearn  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/EKSAdminRole"
    username = "admin-user"
    groups   = ["system:masters"]
  }
]

aws_auth_users = [
  {
    userarn  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/developer"
    username = "developer"
    groups   = ["developers"]
  }
]
```

## 🔒 Secrets Management

### 1. **External Secrets Operator**

#### Installation and Configuration
```hcl
resource "helm_release" "external_secrets" {
  name       = "external-secrets"
  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  namespace  = "external-secrets"
  version    = var.external_secrets_version
  
  create_namespace = true
  
  set {
    name  = "installCRDs"
    value = "true"
  }
  
  set {
    name  = "webhook.port"
    value = "9443"
  }
  
  # Security settings
  set {
    name  = "securityContext.runAsNonRoot"
    value = "true"
  }
  
  set {
    name  = "securityContext.runAsUser"
    value = "65534"
  }
}

# SecretStore configuration
resource "kubernetes_manifest" "secret_store" {
  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "SecretStore"
    metadata = {
      name      = "aws-secrets-manager"
      namespace = "application"
    }
    spec = {
      provider = {
        aws = {
          service = "SecretsManager"
          region  = data.aws_region.current.name
          auth = {
            jwt = {
              serviceAccountRef = {
                name = "external-secrets"
              }
            }
          }
        }
      }
    }
  }
  
  depends_on = [helm_release.external_secrets]
}
```

#### External Secret Example
```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: database-credentials
  namespace: application
spec:
  refreshInterval: 15s
  secretStoreRef:
    name: aws-secrets-manager
    kind: SecretStore
  target:
    name: database-credentials
    creationPolicy: Owner
  data:
  - secretKey: username
    remoteRef:
      key: production/database
      property: username
  - secretKey: password
    remoteRef:
      key: production/database
      property: password
```

### 2. **Sealed Secrets**

#### Alternative Secrets Management
```hcl
resource "helm_release" "sealed_secrets" {
  name       = "sealed-secrets-controller"
  repository = "https://bitnami-labs.github.io/sealed-secrets"
  chart      = "sealed-secrets"
  namespace  = "kube-system"
  version    = var.sealed_secrets_version
  
  set {
    name  = "fullnameOverride"
    value = "sealed-secrets-controller"
  }
  
  # Security settings
  set {
    name  = "securityContext.runAsNonRoot"
    value = "true"
  }
  
  set {
    name  = "securityContext.runAsUser"
    value = "1001"
  }
}
```

## 🛡️ Pod Security

### 1. **Pod Security Standards**

#### Pod Security Policy (Deprecated) to Pod Security Standards Migration
```yaml
# pod-security-policy.yaml (for reference - deprecated)
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: restricted-psp
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
```

#### Pod Security Standards Implementation
```yaml
# namespace-security-labels.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: secure-workloads
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: secure-app
  namespace: secure-workloads
spec:
  template:
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: app
        image: myapp:latest
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - ALL
        resources:
          requests:
            memory: "64Mi"
            cpu: "250m"
          limits:
            memory: "128Mi"
            cpu: "500m"
```

### 2. **Open Policy Agent (OPA) Gatekeeper**

#### Installation and Policies
```hcl
resource "helm_release" "gatekeeper" {
  name       = "gatekeeper"
  repository = "https://open-policy-agent.github.io/gatekeeper/charts"
  chart      = "gatekeeper"
  namespace  = "gatekeeper-system"
  version    = var.gatekeeper_version
  
  create_namespace = true
  
  values = [
    yamlencode({
      replicas = var.environment == "production" ? 3 : 1
      
      audit = {
        replicas = var.environment == "production" ? 2 : 1
      }
      
      # Enable mutation
      mutations = {
        enable = true
      }
      
      # Resource limits
      resources = {
        limits = {
          cpu    = "1000m"
          memory = "512Mi"
        }
        requests = {
          cpu    = "100m"
          memory = "256Mi"
        }
      }
    })
  ]
}

# Constraint Templates and Constraints
resource "kubernetes_manifest" "require_security_context" {
  manifest = {
    apiVersion = "templates.gatekeeper.sh/v1beta1"
    kind       = "ConstraintTemplate"
    metadata = {
      name = "k8srequiresecuritycontext"
    }
    spec = {
      crd = {
        spec = {
          names = {
            kind = "K8sRequireSecurityContext"
          }
        }
      }
      targets = [
        {
          target = "admission.k8s.gatekeeper.sh"
          rego = <<-EOT
            package k8srequiresecuritycontext

            violation[{"msg": msg}] {
              container := input.review.object.spec.containers[_]
              not container.securityContext.runAsNonRoot
              msg := "Container must run as non-root user"
            }

            violation[{"msg": msg}] {
              container := input.review.object.spec.containers[_]
              not container.securityContext.readOnlyRootFilesystem
              msg := "Container must have read-only root filesystem"
            }
          EOT
        }
      ]
    }
  }
  
  depends_on = [helm_release.gatekeeper]
}
```

## 🌐 Network Security

### 1. **Network Policies**

#### Default Deny Network Policy
```yaml
# default-deny-all.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: application
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
---
# allow-dns.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns-access
  namespace: application
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  - to: []
    ports:
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53
---
# allow-specific-app-communication.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend
  namespace: application
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
    ports:
    - protocol: TCP
      port: 8080
```

### 2. **Service Mesh Security**

#### Istio Security Configuration
```hcl
resource "helm_release" "istio_base" {
  name       = "istio-base"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "base"
  namespace  = "istio-system"
  version    = var.istio_version
  
  create_namespace = true
}

resource "helm_release" "istiod" {
  name       = "istiod"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "istiod"
  namespace  = "istio-system"
  version    = var.istio_version
  
  values = [
    yamlencode({
      global = {
        meshConfig = {
          defaultConfig = {
            proxyMetadata = {
              ISTIO_META_DNS_CAPTURE = "true"
              ISTIO_META_DNS_AUTO_ALLOCATE = "true"
            }
          }
        }
      }
      
      pilot = {
        env = {
          EXTERNAL_ISTIOD = false
        }
      }
    })
  ]
  
  depends_on = [helm_release.istio_base]
}
```

#### mTLS Configuration
```yaml
# peer-authentication.yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: application
spec:
  mtls:
    mode: STRICT
---
# authorization-policy.yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-frontend-to-backend
  namespace: application
spec:
  selector:
    matchLabels:
      app: backend
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/application/sa/frontend"]
  - to:
    - operation:
        methods: ["GET", "POST"]
```

## 📊 Security Monitoring and Compliance

### 1. **Falco Runtime Security**

#### Installation and Configuration
```hcl
resource "helm_release" "falco" {
  name       = "falco"
  repository = "https://falcosecurity.github.io/charts"
  chart      = "falco"
  namespace  = "falco-system"
  version    = var.falco_version
  
  create_namespace = true
  
  values = [
    yamlencode({
      # Enable gRPC API
      grpc = {
        enabled = true
      }
      
      # Enable HTTP output
      grpcOutput = {
        enabled = true
      }
      
      # Falco rules
      customRules = {
        rules-custom.yaml = <<-EOT
          - rule: Unexpected inbound connection
            desc: Detect inbound connection to a service from an unexpected client
            condition: >
              inbound_outbound and
              fd.sockfamily = ip and
              (fd.typechar = 4 or fd.typechar = 6) and
              fd.ip != "0.0.0.0" and
              not fd.ip in (allowed_ips)
            output: >
              Inbound connection from unexpected IP (connection=%fd.name
              client_ip=%fd.cip client_port=%fd.cport server_ip=%fd.sip server_port=%fd.sport)
            priority: WARNING
        EOT
      }
      
      # Output to CloudWatch
      falco = {
        grpc_output = {
          enabled = true
        }
        json_output = true
        log_stderr = true
        log_syslog = false
        log_level = "info"
      }
    })
  ]
}
```

### 2. **Image Scanning**

#### Trivy Operator
```hcl
resource "helm_release" "trivy_operator" {
  name       = "trivy-operator"
  repository = "https://aquasecurity.github.io/helm-charts/"
  chart      = "trivy-operator"
  namespace  = "trivy-system"
  version    = var.trivy_operator_version
  
  create_namespace = true
  
  values = [
    yamlencode({
      # Enable vulnerability scanning
      vulnerabilityReports = {
        enabled = true
      }
      
      # Enable configuration auditing
      configAuditReports = {
        enabled = true
      }
      
      # Enable exposed secret scanning
      exposeSecretReports = {
        enabled = true
      }
      
      # Resource limits
      resources = {
        limits = {
          cpu    = "500m"
          memory = "500Mi"
        }
        requests = {
          cpu    = "100m"
          memory = "100Mi"
        }
      }
    })
  ]
}
```

## 🚨 Incident Response and Forensics

### 1. **Audit Logging**

#### Enhanced Audit Policy
```yaml
# audit-policy.yaml
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
# Log all security-related events
- level: Metadata
  namespaces: ["kube-system", "kube-public", "kube-node-lease"]
  resources:
  - group: ""
    resources: ["secrets", "configmaps"]
  - group: "rbac.authorization.k8s.io"
    resources: ["*"]

# Log pod creation/deletion
- level: Request
  resources:
  - group: ""
    resources: ["pods", "services"]
  verbs: ["create", "delete", "update", "patch"]

# Log exec/attach commands
- level: Request
  resources:
  - group: ""
    resources: ["pods/exec", "pods/attach", "pods/portforward"]

# Log authentication failures
- level: Request
  users: ["system:anonymous"]
  verbs: ["*"]
  resources:
  - group: ""
    resources: ["*"]
```

### 2. **Security Benchmarks**

#### CIS Kubernetes Benchmark Implementation
```bash
#!/bin/bash
# security-hardening.sh

# 1. Configure kubelet with security settings
cat <<EOF > /etc/kubernetes/kubelet/kubelet-config.json
{
  "kind": "KubeletConfiguration",
  "apiVersion": "kubelet.config.k8s.io/v1beta1",
  "authentication": {
    "anonymous": {
      "enabled": false
    },
    "webhook": {
      "enabled": true
    }
  },
  "authorization": {
    "mode": "Webhook"
  },
  "readOnlyPort": 0,
  "protectKernelDefaults": true,
  "makeIPTablesUtilChains": true
}
EOF

# 2. Set secure file permissions
chmod 600 /etc/kubernetes/kubelet/kubelet-config.json
chmod 600 /etc/kubernetes/pki/ca.key
```

---

## 🔗 Navigation

| Previous | Current | Next |
|----------|---------|------|
| [Template Examples](./template-examples.md) | **Security Considerations** | [Troubleshooting](./troubleshooting.md) |

---

*Security is a continuous process. Regularly review and update these configurations based on the latest security best practices and threat intelligence.*