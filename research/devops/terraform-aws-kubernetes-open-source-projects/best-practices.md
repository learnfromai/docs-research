# Best Practices: Terraform + AWS/Kubernetes/EKS from Open Source Projects

## 🎯 Overview

This document compiles proven best practices extracted from analysis of 15+ production-ready open source DevOps projects. These patterns represent battle-tested approaches for implementing Infrastructure as Code with Terraform, AWS services, Kubernetes, and EKS.

## 🏗️ Infrastructure as Code Best Practices

### 1. **Terraform Module Design Patterns**

#### Modular Architecture
```hcl
# ✅ Good: Modular design with clear separation
modules/
├── vpc/              # Networking foundation
├── eks-cluster/      # Core Kubernetes platform  
├── eks-addons/       # Operational components
├── security/         # IAM, policies, encryption
├── monitoring/       # Observability stack
└── storage/          # Persistent volumes, backup
```

#### Module Composition Pattern
```hcl
# ✅ Good: Compose modules for environment-specific needs
module "vpc" {
  source = "./modules/vpc"
  
  cluster_name = var.cluster_name
  cidr_block   = var.vpc_cidr
  
  tags = local.common_tags
}

module "eks_cluster" {
  source = "./modules/eks-cluster"
  
  cluster_name    = var.cluster_name
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.private_subnet_ids
  
  node_groups = var.node_groups
  
  depends_on = [module.vpc]
  tags       = local.common_tags
}

module "eks_addons" {
  source = "./modules/eks-addons"
  
  cluster_name      = module.eks_cluster.cluster_name
  cluster_endpoint  = module.eks_cluster.cluster_endpoint
  oidc_provider_arn = module.eks_cluster.oidc_provider_arn
  
  enable_monitoring = var.enable_monitoring
  enable_gitops     = var.enable_gitops
  
  depends_on = [module.eks_cluster]
  tags       = local.common_tags
}
```

#### Variable Management
```hcl
# ✅ Good: Structured variable definitions
variable "cluster_config" {
  description = "EKS cluster configuration"
  type = object({
    name            = string
    version         = string
    endpoint_access = object({
      private = bool
      public  = bool
      public_access_cidrs = list(string)
    })
    encryption = object({
      enabled = bool
      kms_key_id = string
    })
  })
  
  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]*$", var.cluster_config.name))
    error_message = "Cluster name must start with letter and contain only alphanumeric characters and hyphens."
  }
}

# ✅ Good: Environment-specific variable files
# terraform.tfvars.example
cluster_config = {
  name    = "production-cluster"
  version = "1.28"
  endpoint_access = {
    private             = true
    public              = true
    public_access_cidrs = ["203.0.113.0/24"] # Office IP range
  }
  encryption = {
    enabled    = true
    kms_key_id = "arn:aws:kms:us-west-2:123456789012:key/12345678-1234-1234-1234-123456789012"
  }
}
```

#### State Management
```hcl
# ✅ Good: Remote state with locking
terraform {
  backend "s3" {
    bucket         = "company-terraform-state"
    key            = "eks/production/terraform.tfstate"
    region         = "us-west-2"
    encrypt        = true
    dynamodb_table = "terraform-lock"
    
    # Workspace-specific state
    workspace_key_prefix = "env"
  }
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
  }
  
  required_version = ">= 1.5"
}
```

### 2. **AWS Resource Management Patterns**

#### Tagging Strategy
```hcl
# ✅ Good: Consistent tagging across all resources
locals {
  common_tags = merge(
    var.additional_tags,
    {
      Environment   = var.environment
      Project       = var.project_name
      Owner         = var.team_name
      CostCenter    = var.cost_center
      ManagedBy     = "terraform"
      CreatedDate   = formatdate("YYYY-MM-DD", timestamp())
      
      # Kubernetes-specific tags
      "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    }
  )
  
  # Environment-specific tags
  environment_tags = var.environment == "production" ? {
    Backup    = "daily"
    Retention = "7-years"
    Compliance = "required"
  } : {}
  
  final_tags = merge(local.common_tags, local.environment_tags)
}

# Apply to all resources
resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = aws_iam_role.cluster.arn
  
  tags = local.final_tags
}
```

#### IAM Role Design
```hcl
# ✅ Good: Principle of least privilege with IRSA
data "aws_iam_policy_document" "cluster_assume_role" {
  statement {
    effect = "Allow"
    
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
    
    actions = ["sts:AssumeRole"]
    
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_iam_role" "cluster" {
  name               = "${var.cluster_name}-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.cluster_assume_role.json
  
  tags = local.final_tags
}

# Attach only required managed policies
resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

# IRSA for service-specific permissions
module "aws_load_balancer_controller_irsa" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  
  role_name = "${var.cluster_name}-aws-load-balancer-controller"
  
  attach_load_balancer_controller_policy = true
  
  oidc_providers = {
    main = {
      provider_arn               = aws_eks_cluster.main.identity[0].oidc[0].issuer
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
  
  tags = local.final_tags
}
```

#### Network Security
```hcl
# ✅ Good: Defense in depth networking
resource "aws_security_group" "cluster" {
  name_prefix = "${var.cluster_name}-cluster-"
  vpc_id      = var.vpc_id
  
  # Control plane access
  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }
  
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = merge(local.final_tags, {
    Name = "${var.cluster_name}-cluster-sg"
  })
}

resource "aws_security_group" "nodes" {
  name_prefix = "${var.cluster_name}-nodes-"
  vpc_id      = var.vpc_id
  
  # Node-to-node communication
  ingress {
    description = "Node to node"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    self        = true
  }
  
  # Control plane to nodes
  ingress {
    description     = "Control plane to nodes"
    from_port       = 1025
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.cluster.id]
  }
  
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = merge(local.final_tags, {
    Name = "${var.cluster_name}-nodes-sg"
  })
}
```

---

## ☸️ Kubernetes & EKS Best Practices

### 1. **Cluster Configuration Patterns**

#### Production-Ready Cluster Settings
```hcl
# ✅ Good: Production cluster configuration
resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = aws_iam_role.cluster.arn
  version  = var.cluster_version
  
  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = var.public_access_cidrs
    security_group_ids      = [aws_security_group.cluster.id]
  }
  
  encryption_config {
    provider {
      key_arn = var.kms_key_arn
    }
    resources = ["secrets"]
  }
  
  enabled_cluster_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler"
  ]
  
  tags = local.final_tags
  
  depends_on = [
    aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy,
    aws_cloudwatch_log_group.cluster
  ]
}

# Dedicated log group with retention
resource "aws_cloudwatch_log_group" "cluster" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn
  
  tags = local.final_tags
}
```

#### Node Group Best Practices
```hcl
# ✅ Good: Managed node groups with proper configuration
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-${var.node_group_name}"
  node_role_arn   = aws_iam_role.nodes.arn
  subnet_ids      = var.private_subnet_ids
  
  # Instance configuration
  instance_types = var.instance_types
  capacity_type  = var.capacity_type # "ON_DEMAND" or "SPOT"
  disk_size      = var.disk_size
  
  # Auto-scaling configuration
  scaling_config {
    desired_size = var.desired_capacity
    max_size     = var.max_capacity
    min_size     = var.min_capacity
  }
  
  update_config {
    max_unavailable_percentage = 25
  }
  
  # Launch template for advanced configuration
  launch_template {
    id      = aws_launch_template.nodes.id
    version = aws_launch_template.nodes.latest_version
  }
  
  # Labels and taints
  labels = merge(var.node_labels, {
    "node.kubernetes.io/instance-type" = join(",", var.instance_types)
    "eks.amazonaws.com/capacityType"   = var.capacity_type
  })
  
  dynamic "taint" {
    for_each = var.node_taints
    content {
      key    = taint.value.key
      value  = taint.value.value
      effect = taint.value.effect
    }
  }
  
  tags = local.final_tags
  
  depends_on = [
    aws_iam_role_policy_attachment.nodes_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.nodes_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.nodes_AmazonEC2ContainerRegistryReadOnly,
  ]
}

# Launch template for custom AMI and user data
resource "aws_launch_template" "nodes" {
  name_prefix = "${var.cluster_name}-${var.node_group_name}-"
  
  vpc_security_group_ids = [aws_security_group.nodes.id]
  
  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    cluster_name        = aws_eks_cluster.main.name
    cluster_endpoint    = aws_eks_cluster.main.endpoint
    cluster_ca          = aws_eks_cluster.main.certificate_authority[0].data
    bootstrap_arguments = var.bootstrap_arguments
  }))
  
  tag_specifications {
    resource_type = "instance"
    tags = merge(local.final_tags, {
      Name = "${var.cluster_name}-${var.node_group_name}"
    })
  }
  
  tags = local.final_tags
}
```

### 2. **Add-on Management Patterns**

#### Essential Add-ons Configuration
```hcl
# ✅ Good: Systematic add-on management
locals {
  cluster_addons = {
    coredns = {
      most_recent = true
      configuration_values = jsonencode({
        nodeSelector = {
          "kubernetes.io/os" = "linux"
        }
        tolerations = [
          {
            key      = "CriticalAddonsOnly"
            operator = "Exists"
          }
        ]
      })
    }
    
    vpc-cni = {
      most_recent = true
      configuration_values = jsonencode({
        env = {
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = "1"
          ANNOTATE_POD_IP         = "true"
        }
      })
    }
    
    aws-ebs-csi-driver = {
      most_recent = true
      service_account_role_arn = module.ebs_csi_driver_irsa.iam_role_arn
    }
    
    eks-pod-identity-agent = {
      most_recent = true
    }
  }
}

resource "aws_eks_addon" "main" {
  for_each = local.cluster_addons
  
  cluster_name             = aws_eks_cluster.main.name
  addon_name               = each.key
  addon_version            = each.value.most_recent ? null : each.value.version
  service_account_role_arn = lookup(each.value, "service_account_role_arn", null)
  configuration_values     = lookup(each.value, "configuration_values", null)
  
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  
  tags = local.final_tags
}
```

#### Community Add-ons via Helm
```hcl
# ✅ Good: AWS Load Balancer Controller
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = var.aws_load_balancer_controller_version
  
  values = [
    yamlencode({
      clusterName = aws_eks_cluster.main.name
      region      = data.aws_region.current.name
      vpcId       = var.vpc_id
      
      serviceAccount = {
        create = true
        name   = "aws-load-balancer-controller"
        annotations = {
          "eks.amazonaws.com/role-arn" = module.aws_load_balancer_controller_irsa.iam_role_arn
        }
      }
      
      nodeSelector = {
        "kubernetes.io/os" = "linux"
      }
      
      tolerations = [
        {
          key      = "CriticalAddonsOnly"
          operator = "Exists"
        }
      ]
      
      resources = {
        limits = {
          cpu    = "200m"
          memory = "500Mi"
        }
        requests = {
          cpu    = "100m"
          memory = "200Mi"
        }
      }
    })
  ]
  
  depends_on = [
    aws_eks_cluster.main,
    module.aws_load_balancer_controller_irsa
  ]
}
```

---

## 🔄 GitOps Implementation Best Practices

### 1. **Repository Structure Patterns**

#### Multi-Repository Strategy
```
# ✅ Good: Separation of concerns
infrastructure-repo/
├── terraform/
│   ├── environments/
│   │   ├── dev/
│   │   ├── staging/
│   │   └── prod/
│   └── modules/
└── kubernetes/
    ├── base/
    └── overlays/

application-configs-repo/
├── apps/
│   ├── app-of-apps.yaml
│   ├── monitoring/
│   ├── security/
│   └── workloads/
└── projects/
    ├── team-a/
    └── team-b/
```

#### Application Definitions
```yaml
# ✅ Good: Comprehensive application configuration
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: microservice-a
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
  annotations:
    argocd.argoproj.io/sync-wave: "1"
spec:
  project: team-a-project
  source:
    repoURL: https://github.com/company/microservice-a-config
    targetRevision: main
    path: k8s/overlays/production
  destination:
    server: https://kubernetes.default.svc
    namespace: team-a-production
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - PruneLast=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
  revisionHistoryLimit: 10
```

### 2. **Security and Compliance Patterns**

#### RBAC Configuration
```yaml
# ✅ Good: Team-based access control
apiVersion: v1
kind: Namespace
metadata:
  name: team-a-production
  labels:
    team: team-a
    environment: production
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: team-a-production
  name: team-a-developer
rules:
- apiGroups: [""]
  resources: ["pods", "services", "configmaps", "secrets"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "watch", "patch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: team-a-developers
  namespace: team-a-production
subjects:
- kind: Group
  name: team-a-developers
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: team-a-developer
  apiGroup: rbac.authorization.k8s.io
```

#### Pod Security Standards
```yaml
# ✅ Good: Enforce security standards
apiVersion: v1
kind: Namespace
metadata:
  name: production-workloads
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: production-workloads
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-same-namespace
  namespace: production-workloads
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: production-workloads
```

---

## 📊 Monitoring and Observability Best Practices

### 1. **Prometheus Configuration Patterns**

#### Service Discovery and Scraping
```yaml
# ✅ Good: Comprehensive service discovery
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
  namespace: monitoring
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
      evaluation_interval: 15s
      external_labels:
        cluster: {{ .Values.clusterName }}
        environment: {{ .Values.environment }}
    
    rule_files:
      - /etc/prometheus/rules/*.yml
    
    scrape_configs:
      # Kubernetes API server
      - job_name: 'kubernetes-apiservers'
        kubernetes_sd_configs:
          - role: endpoints
        scheme: https
        tls_config:
          ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
        relabel_configs:
          - source_labels: [__meta_kubernetes_namespace, __meta_kubernetes_service_name, __meta_kubernetes_endpoint_port_name]
            action: keep
            regex: default;kubernetes;https
      
      # Node metrics
      - job_name: 'kubernetes-nodes'
        kubernetes_sd_configs:
          - role: node
        scheme: https
        tls_config:
          ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
        relabel_configs:
          - action: labelmap
            regex: __meta_kubernetes_node_label_(.+)
      
      # Pod metrics
      - job_name: 'kubernetes-pods'
        kubernetes_sd_configs:
          - role: pod
        relabel_configs:
          - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
            action: keep
            regex: true
          - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
            action: replace
            target_label: __metrics_path__
            regex: (.+)
```

#### Alert Rules
```yaml
# ✅ Good: Production-ready alert rules
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-rules
  namespace: monitoring
data:
  kubernetes.yml: |
    groups:
    - name: kubernetes-cluster
      rules:
      - alert: KubernetesNodeReady
        expr: kube_node_status_condition{condition="Ready",status="true"} == 0
        for: 10m
        labels:
          severity: critical
        annotations:
          summary: "Kubernetes Node not ready"
          description: "Node {{ $labels.node }} has been unready for more than 10 minutes"
      
      - alert: KubernetesPodCrashLooping
        expr: rate(kube_pod_container_status_restarts_total[15m]) > 0
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Pod is crash looping"
          description: "Pod {{ $labels.namespace }}/{{ $labels.pod }} is restarting frequently"
      
      - alert: KubernetesHighMemoryUsage
        expr: (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes > 0.9
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage"
          description: "Node {{ $labels.instance }} memory usage is above 90%"
```

### 2. **Grafana Dashboard Patterns**

#### Infrastructure Dashboard
```json
{
  "dashboard": {
    "title": "EKS Cluster Overview",
    "tags": ["kubernetes", "eks", "infrastructure"],
    "timezone": "browser",
    "refresh": "30s",
    "panels": [
      {
        "title": "Cluster Status",
        "type": "stat",
        "targets": [
          {
            "expr": "up{job=\"kubernetes-apiservers\"}",
            "legendFormat": "API Server"
          },
          {
            "expr": "kube_node_status_condition{condition=\"Ready\",status=\"true\"}",
            "legendFormat": "Ready Nodes"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "color": {
              "mode": "thresholds"
            },
            "thresholds": {
              "steps": [
                {"color": "red", "value": 0},
                {"color": "green", "value": 1}
              ]
            }
          }
        }
      }
    ]
  }
}
```

---

## 🔐 Security Best Practices

### 1. **Secrets Management**

#### AWS Secrets Manager Integration
```hcl
# ✅ Good: External secrets operator
resource "helm_release" "external_secrets" {
  name       = "external-secrets"
  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  namespace  = "external-secrets-system"
  
  create_namespace = true
  
  values = [
    yamlencode({
      serviceAccount = {
        annotations = {
          "eks.amazonaws.com/role-arn" = module.external_secrets_irsa.iam_role_arn
        }
      }
    })
  ]
}

# SecretStore configuration
resource "kubernetes_manifest" "secret_store" {
  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "SecretStore"
    metadata = {
      name      = "aws-secrets-manager"
      namespace = "default"
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
}
```

### 2. **Network Security**

#### Calico Network Policies
```yaml
# ✅ Good: Micro-segmentation with Calico
apiVersion: projectcalico.org/v3
kind: NetworkPolicy
metadata:
  name: frontend-policy
  namespace: production
spec:
  selector: app == 'frontend'
  types:
  - Ingress
  - Egress
  ingress:
  - action: Allow
    protocol: TCP
    destination:
      ports: [80, 443]
    source:
      selector: app == 'ingress-controller'
  egress:
  - action: Allow
    protocol: TCP
    destination:
      selector: app == 'backend'
      ports: [8080]
  - action: Allow
    protocol: TCP
    destination:
      selector: app == 'database'
      ports: [5432]
```

---

## 💰 Cost Optimization Best Practices

### 1. **Resource Right-Sizing**

#### Spot Instance Integration
```hcl
# ✅ Good: Mixed instance types with spot instances
resource "aws_eks_node_group" "spot" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-spot"
  node_role_arn   = aws_iam_role.nodes.arn
  subnet_ids      = var.private_subnet_ids
  
  capacity_type   = "SPOT"
  instance_types  = ["m5.large", "m5a.large", "m4.large"]
  
  scaling_config {
    desired_size = var.spot_desired_capacity
    max_size     = var.spot_max_capacity
    min_size     = var.spot_min_capacity
  }
  
  labels = {
    "node.kubernetes.io/capacity-type" = "SPOT"
    "node.kubernetes.io/instance-type" = "mixed"
  }
  
  taint {
    key    = "spot-instance"
    value  = "true"
    effect = "NO_SCHEDULE"
  }
  
  tags = local.final_tags
}
```

#### Cluster Autoscaler Configuration
```yaml
# ✅ Good: Efficient autoscaling
apiVersion: v1
kind: ConfigMap
metadata:
  name: cluster-autoscaler-status
  namespace: kube-system
data:
  nodes.max: "100"
  scale-down-delay-after-add: "10m"
  scale-down-unneeded-time: "10m"
  scale-down-utilization-threshold: "0.5"
  skip-nodes-with-local-storage: "false"
  skip-nodes-with-system-pods: "false"
```

---

## 🚨 Common Anti-Patterns to Avoid

### Infrastructure Management
- ❌ **Hardcoded Values**: Always use variables and data sources
- ❌ **No Resource Tagging**: Implement consistent tagging strategy
- ❌ **Manual Resource Creation**: Use Terraform for all AWS resources
- ❌ **No State Locking**: Always implement remote state with DynamoDB locking
- ❌ **Monolithic Modules**: Break down into logical, reusable components

### Kubernetes Security
- ❌ **Root Containers**: Always run containers as non-root users
- ❌ **No Resource Limits**: Define CPU/memory requests and limits
- ❌ **Overprivileged Pods**: Follow principle of least privilege
- ❌ **No Network Policies**: Implement proper network segmentation
- ❌ **Secrets in Code**: Use external secret management

### Operational Practices
- ❌ **No Monitoring**: Implement comprehensive observability
- ❌ **No Backup Strategy**: Configure regular backups
- ❌ **Direct kubectl Apply**: Use GitOps for all production changes
- ❌ **No Disaster Recovery**: Plan for failure scenarios
- ❌ **Ignoring Cost**: Implement cost monitoring and optimization

---

## 📊 Success Metrics and KPIs

### Infrastructure Metrics
- **Cluster Uptime**: > 99.9%
- **Node Utilization**: 70-80% average
- **Pod Startup Time**: < 30 seconds
- **Network Latency**: < 5ms intra-cluster

### Operational Metrics
- **Mean Time to Recovery (MTTR)**: < 15 minutes
- **Deployment Frequency**: Multiple times per day
- **Change Failure Rate**: < 5%
- **Lead Time for Changes**: < 1 hour

### Cost Metrics
- **Cost per Application**: Track and optimize
- **Spot Instance Ratio**: > 50% for non-critical workloads
- **Resource Waste**: < 20% unused capacity
- **Storage Costs**: Optimize with lifecycle policies

---

## 🔗 Navigation

← [Back to Implementation Guide](./implementation-guide.md) | [Next: Template Examples](./template-examples.md) →