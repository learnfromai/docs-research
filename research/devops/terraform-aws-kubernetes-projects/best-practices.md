# Best Practices: Terraform + AWS + Kubernetes/EKS Production Patterns

## 🏗️ Infrastructure Architecture Patterns

### **1. Modular Infrastructure Design**

#### **Layered Architecture Approach**
```
├── foundation/          # Core networking and security
│   ├── vpc/
│   ├── security-groups/
│   └── iam/
├── platform/           # Kubernetes platform components
│   ├── eks/
│   ├── addons/
│   └── operators/
└── applications/       # Application-specific resources
    ├── ingress/
    ├── storage/
    └── secrets/
```

#### **Module Composition Best Practices**

```hcl
# Example: Composable VPC module
module "vpc" {
  source = "./modules/vpc"
  
  # Required inputs
  cluster_name = var.cluster_name
  region       = var.region
  
  # Network configuration
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  private_subnet_cidrs = var.private_subnet_cidrs
  public_subnet_cidrs  = var.public_subnet_cidrs
  
  # Feature flags
  enable_nat_gateway     = var.enable_nat_gateway
  enable_vpn_gateway     = var.enable_vpn_gateway
  enable_dns_hostnames   = true
  enable_dns_support     = true
  
  # Tagging strategy
  tags = local.common_tags
}

# Example: EKS module with dependency injection
module "eks" {
  source = "./modules/eks"
  
  # Dependencies
  vpc_id              = module.vpc.vpc_id
  private_subnet_ids  = module.vpc.private_subnet_ids
  security_group_ids  = [module.security_groups.cluster_sg_id]
  
  # Cluster configuration
  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version
  
  # Node group configuration
  node_groups = var.node_groups
  
  tags = local.common_tags
  
  depends_on = [module.vpc]
}
```

### **2. Environment Management Strategies**

#### **Terragrunt Multi-Environment Pattern**

```hcl
# terragrunt.hcl - Root configuration
locals {
  # Auto-extract environment and region from path
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  region_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  
  environment = local.env_vars.locals.environment
  aws_region  = local.region_vars.locals.aws_region
  
  # Common naming convention
  name_prefix = "${local.environment}-${local.aws_region}"
}

# Remote state configuration
remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
  config = {
    bucket         = "terraform-state-${local.environment}"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = local.aws_region
    encrypt        = true
    dynamodb_table = "terraform-locks-${local.environment}"
  }
}

# Generate provider configuration
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region = "${local.aws_region}"
  
  default_tags {
    tags = {
      Environment = "${local.environment}"
      Region      = "${local.aws_region}"
      ManagedBy   = "terragrunt"
    }
  }
}
EOF
}
```

#### **Environment-Specific Configuration**

```hcl
# environments/prod/env.hcl
locals {
  environment = "prod"
  
  # Production-specific settings
  cluster_version = "1.27"
  enable_logging  = true
  enable_monitoring = true
  
  # Node group configuration
  node_groups = {
    general = {
      instance_types = ["t3.large"]
      min_size       = 3
      max_size       = 10
      desired_size   = 6
      capacity_type  = "ON_DEMAND"
    }
    
    compute = {
      instance_types = ["c5.xlarge"]
      min_size       = 0
      max_size       = 5
      desired_size   = 1
      capacity_type  = "SPOT"
    }
  }
  
  # Security settings
  enable_public_access = false
  allowed_cidr_blocks  = ["10.0.0.0/8"]
  
  # Backup and retention
  backup_retention_days = 30
  log_retention_days    = 90
}
```

---

## 🔒 Security Best Practices

### **1. Identity and Access Management (IAM)**

#### **Principle of Least Privilege**

```hcl
# EKS Service Role - Minimal permissions
resource "aws_iam_role" "eks_cluster_role" {
  name = "${var.cluster_name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })
}

# Attach only required policies
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

# Node group role with minimal permissions
resource "aws_iam_role" "eks_node_group_role" {
  name = "${var.cluster_name}-node-group-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# Required policies for node groups
resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_group_role.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_group_role.name
}

resource "aws_iam_role_policy_attachment" "eks_container_registry_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_group_role.name
}
```

#### **Service Account and IRSA Implementation**

```hcl
# OIDC Identity Provider
data "tls_certificate" "eks_cluster" {
  url = aws_eks_cluster.cluster.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_cluster.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.cluster.identity[0].oidc[0].issuer

  tags = var.tags
}

# Example: AWS Load Balancer Controller IRSA
resource "aws_iam_role" "aws_load_balancer_controller" {
  name = "${var.cluster_name}-alb-controller"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Condition = {
          StringEquals = {
            "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub": "system:serviceaccount:kube-system:aws-load-balancer-controller"
            "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud": "sts.amazonaws.com"
          }
        }
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks.arn
        }
      }
    ]
  })
}
```

### **2. Network Security**

#### **Security Group Best Practices**

```hcl
# Cluster security group - Restrictive rules
resource "aws_security_group" "cluster_sg" {
  name_prefix = "${var.cluster_name}-cluster-"
  vpc_id      = var.vpc_id

  # Allow HTTPS from private subnets only
  ingress {
    description = "HTTPS from private subnets"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.private_subnet_cidrs
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-cluster-sg"
  })
}

# Node group security group
resource "aws_security_group" "node_sg" {
  name_prefix = "${var.cluster_name}-node-"
  vpc_id      = var.vpc_id

  # Allow traffic from cluster
  ingress {
    description     = "Cluster API to nodes"
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.cluster_sg.id]
  }

  # Node to node communication
  ingress {
    description = "Node to node"
    from_port   = 0
    to_port     = 65535
    protocol    = "-1"
    self        = true
  }

  # Allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-node-sg"
  })
}
```

#### **Network Policies Implementation**

```yaml
# Example: Default deny network policy
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: default
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress

---
# Allow specific communication patterns
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend
  namespace: default
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

### **3. Secret Management**

#### **External Secrets Integration**

```yaml
# External Secrets Operator configuration
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: aws-secrets-manager
  namespace: default
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-west-2
      auth:
        secretRef:
          accessKeyID:
            name: aws-secret
            key: access-key-id
          secretAccessKey:
            name: aws-secret
            key: secret-access-key

---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: database-secret
  namespace: default
spec:
  refreshInterval: 15s
  secretStoreRef:
    name: aws-secrets-manager
    kind: SecretStore
  target:
    name: database-secret
    creationPolicy: Owner
  data:
  - secretKey: username
    remoteRef:
      key: prod/database
      property: username
  - secretKey: password
    remoteRef:
      key: prod/database
      property: password
```

---

## 📊 Monitoring and Observability

### **1. Comprehensive Monitoring Stack**

#### **Prometheus Configuration**

```yaml
# values/prometheus-values.yaml
prometheus:
  prometheusSpec:
    retention: 30d
    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: gp3
          resources:
            requests:
              storage: 100Gi
    
    # Resource limits
    resources:
      requests:
        memory: 2Gi
        cpu: 1000m
      limits:
        memory: 4Gi
        cpu: 2000m
    
    # Additional scrape configs
    additionalScrapeConfigs:
      - job_name: 'kubernetes-pods'
        kubernetes_sd_configs:
          - role: pod
        relabel_configs:
          - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
            action: keep
            regex: true

grafana:
  adminPassword: prom-operator
  
  persistence:
    enabled: true
    storageClassName: gp3
    size: 20Gi
  
  grafana.ini:
    security:
      disable_gravatar: true
    auth.anonymous:
      enabled: true
      org_role: Viewer
  
  dashboardProviders:
    dashboardproviders.yaml:
      apiVersion: 1
      providers:
      - name: 'default'
        orgId: 1
        folder: ''
        type: file
        disableDeletion: false
        editable: true
        options:
          path: /var/lib/grafana/dashboards/default

alertmanager:
  alertmanagerSpec:
    storage:
      volumeClaimTemplate:
        spec:
          storageClassName: gp3
          resources:
            requests:
              storage: 10Gi
```

#### **Custom Metrics and Alerts**

```yaml
# Custom PrometheusRule for EKS monitoring
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: eks-cluster-alerts
  namespace: monitoring
spec:
  groups:
  - name: eks.cluster
    rules:
    - alert: EKSNodeNotReady
      expr: kube_node_status_condition{condition="Ready",status="true"} == 0
      for: 15m
      labels:
        severity: critical
      annotations:
        summary: "EKS node {{ $labels.node }} is not ready"
        description: "Node {{ $labels.node }} has been not ready for more than 15 minutes."
    
    - alert: EKSPodCrashLooping
      expr: rate(kube_pod_container_status_restarts_total[15m]) * 60 * 15 > 0
      for: 15m
      labels:
        severity: warning
      annotations:
        summary: "Pod {{ $labels.namespace }}/{{ $labels.pod }} is crash looping"
        description: "Pod {{ $labels.namespace }}/{{ $labels.pod }} has been restarting frequently."
    
    - alert: EKSHighMemoryUsage
      expr: (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes > 0.9
      for: 15m
      labels:
        severity: warning
      annotations:
        summary: "High memory usage on node {{ $labels.instance }}"
        description: "Memory usage is above 90% for more than 15 minutes."
```

### **2. Logging Best Practices**

#### **Fluent Bit Configuration**

```yaml
# fluent-bit-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: fluent-bit-config
  namespace: amazon-cloudwatch
data:
  fluent-bit.conf: |
    [SERVICE]
        Flush                     5
        Grace                     30
        Log_Level                 info
        Daemon                    off
        Parsers_File              parsers.conf
        HTTP_Server               On
        HTTP_Listen               0.0.0.0
        HTTP_Port                 2020
        storage.path              /var/fluent-bit/state/flb-storage/
        storage.sync              normal
        storage.checksum          off
        storage.backlog.mem_limit 5M

    [INPUT]
        Name                tail
        Tag                 application.*
        Exclude_Path        /var/log/containers/cloudwatch-agent*, /var/log/containers/fluent-bit*, /var/log/containers/aws-node*, /var/log/containers/kube-proxy*
        Path                /var/log/containers/*.log
        Parser              docker
        DB                  /var/fluent-bit/state/flb_container.db
        Mem_Buf_Limit       50MB
        Skip_Long_Lines     On
        Refresh_Interval    10
        Rotate_Wait         30
        storage.type        filesystem
        Read_from_Head      Off

    [OUTPUT]
        Name                cloudwatch_logs
        Match               application.*
        region              us-west-2
        log_group_name      /aws/containerinsights/eks-prod/application
        log_stream_prefix   ${HOSTNAME}-
        auto_create_group   true
        extra_user_agent    container-insights
```

---

## 🚀 Deployment and CI/CD Best Practices

### **1. GitOps Implementation**

#### **ArgoCD Application Configuration**

```yaml
# apps/app-of-apps.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: app-of-apps
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/k8s-manifests
    targetRevision: main
    path: apps
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true

---
# apps/infrastructure.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: infrastructure
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/k8s-manifests
    targetRevision: main
    path: infrastructure
  destination:
    server: https://kubernetes.default.svc
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
```

#### **GitHub Actions Pipeline**

```yaml
# .github/workflows/terraform.yml
name: Terraform Infrastructure

on:
  push:
    branches: [main]
    paths: ['terraform/**']
  pull_request:
    branches: [main]
    paths: ['terraform/**']

env:
  TF_VERSION: 1.5.0
  TG_VERSION: 0.50.0

jobs:
  terraform:
    name: Terraform Plan/Apply
    runs-on: ubuntu-latest
    strategy:
      matrix:
        environment: [dev, staging, prod]
    
    steps:
    - name: Checkout
      uses: actions/checkout@v4

    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v2
      with:
        terraform_version: ${{ env.TF_VERSION }}

    - name: Setup Terragrunt
      uses: autero1/action-terragrunt@v1.3.0
      with:
        terragrunt_version: ${{ env.TG_VERSION }}

    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v4
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: us-west-2

    - name: Terragrunt Format Check
      run: terragrunt hclfmt --terragrunt-check --terragrunt-diff
      working-directory: ./terraform

    - name: Terragrunt Plan
      run: |
        cd terraform/environments/${{ matrix.environment }}/us-west-2
        terragrunt run-all plan --terragrunt-non-interactive
      if: github.event_name == 'pull_request'

    - name: Terragrunt Apply
      run: |
        cd terraform/environments/${{ matrix.environment }}/us-west-2
        terragrunt run-all apply --terragrunt-non-interactive
      if: github.ref == 'refs/heads/main' && matrix.environment != 'prod'

    - name: Terragrunt Apply Production (Manual)
      run: |
        cd terraform/environments/prod/us-west-2
        terragrunt run-all apply --terragrunt-non-interactive
      if: github.ref == 'refs/heads/main' && matrix.environment == 'prod' && contains(github.event.head_commit.message, '[deploy-prod]')
```

### **2. Application Deployment Patterns**

#### **Blue-Green Deployment with Argo Rollouts**

```yaml
# rollouts/blue-green-rollout.yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: web-app
  namespace: default
spec:
  replicas: 3
  strategy:
    blueGreen:
      activeService: web-app-active
      previewService: web-app-preview
      autoPromotionEnabled: false
      scaleDownDelaySeconds: 30
      prePromotionAnalysis:
        templates:
        - templateName: success-rate
        args:
        - name: service-name
          value: web-app-preview
      postPromotionAnalysis:
        templates:
        - templateName: success-rate
        args:
        - name: service-name
          value: web-app-active
  selector:
    matchLabels:
      app: web-app
  template:
    metadata:
      labels:
        app: web-app
    spec:
      containers:
      - name: web
        image: nginx:1.21
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"

---
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: success-rate
spec:
  args:
  - name: service-name
  metrics:
  - name: success-rate
    interval: 30s
    count: 3
    successCondition: result[0] >= 0.95
    provider:
      prometheus:
        address: http://prometheus.monitoring.svc.cluster.local:9090
        query: |
          sum(rate(
            http_requests_total{service="{{args.service-name}}",status=~"2.."}[5m]
          )) /
          sum(rate(
            http_requests_total{service="{{args.service-name}}"}[5m]
          ))
```

---

## ⚡ Performance and Optimization

### **1. Resource Management**

#### **Vertical Pod Autoscaler (VPA)**

```yaml
# vpa/frontend-vpa.yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: frontend-vpa
  namespace: default
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: frontend
  updatePolicy:
    updateMode: "Auto"
  resourcePolicy:
    containerPolicies:
    - containerName: frontend
      maxAllowed:
        cpu: 2
        memory: 4Gi
      minAllowed:
        cpu: 100m
        memory: 128Mi
      controlledResources: ["cpu", "memory"]
```

#### **Horizontal Pod Autoscaler (HPA)**

```yaml
# hpa/frontend-hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: frontend-hpa
  namespace: default
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: frontend
  minReplicas: 2
  maxReplicas: 10
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
```

### **2. Cluster Autoscaling**

#### **Cluster Autoscaler Configuration**

```yaml
# cluster-autoscaler/values.yaml
autoDiscovery:
  clusterName: eks-prod
  enabled: true

awsRegion: us-west-2

extraArgs:
  v: 4
  stderrthreshold: info
  logtostderr: true
  node-group-auto-discovery: asg:tag=k8s.io/cluster-autoscaler/enabled,k8s.io/cluster-autoscaler/eks-prod
  balance-similar-node-groups: false
  skip-nodes-with-system-pods: false
  scale-down-enabled: true
  scale-down-delay-after-add: 10m
  scale-down-unneeded-time: 10m
  scale-down-utilization-threshold: 0.5

resources:
  limits:
    cpu: 100m
    memory: 300Mi
  requests:
    cpu: 100m
    memory: 300Mi

nodeSelector:
  kubernetes.io/arch: amd64
  kubernetes.io/os: linux

tolerations:
- key: CriticalAddonsOnly
  operator: Exists
```

---

## 💰 Cost Optimization

### **1. Resource Right-Sizing**

#### **Node Group Optimization**

```hcl
# Cost-optimized node groups
eks_managed_node_groups = {
  # General purpose - burstable instances
  general = {
    instance_types = ["t3.medium", "t3.large"]
    capacity_type  = "ON_DEMAND"
    min_size       = 2
    max_size       = 8
    desired_size   = 3
    
    # Cost optimization
    ami_type = "AL2_x86_64"
    
    # Taints for cost-sensitive workloads
    taints = []
    
    labels = {
      role = "general"
      cost-optimization = "enabled"
    }
  }
  
  # Spot instances for fault-tolerant workloads
  spot = {
    instance_types = ["t3.medium", "t3.large", "t3.xlarge"]
    capacity_type  = "SPOT"
    min_size       = 0
    max_size       = 10
    desired_size   = 2
    
    # Mixed instance policy for spot
    use_mixed_instances_policy = true
    mixed_instances_policy = {
      instances_distribution = {
        on_demand_base_capacity                  = 0
        on_demand_percentage_above_base_capacity = 0
        spot_allocation_strategy                 = "diversified"
        spot_instance_pools                      = 2
        spot_max_price                          = "0.10"
      }
    }
    
    taints = [
      {
        key    = "spot-instance"
        value  = "true"
        effect = "NO_SCHEDULE"
      }
    ]
    
    labels = {
      role = "spot"
      cost-optimization = "aggressive"
    }
  }
}
```

#### **Pod Disruption Budgets**

```yaml
# pdb/frontend-pdb.yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: frontend-pdb
  namespace: default
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: frontend

---
# pdb/backend-pdb.yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: backend-pdb
  namespace: default
spec:
  maxUnavailable: "25%"
  selector:
    matchLabels:
      app: backend
```

### **2. Storage Optimization**

#### **Storage Classes for Different Use Cases**

```yaml
# storage/storage-classes.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3-fast
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  iops: "3000"
  throughput: "125"
  encrypted: "true"
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer

---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3-standard
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  encrypted: "true"
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer

---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp2-cheap
provisioner: ebs.csi.aws.com
parameters:
  type: gp2
  encrypted: "true"
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
```

---

## 🛡️ Backup and Disaster Recovery

### **1. Velero Backup Strategy**

#### **Velero Configuration**

```yaml
# velero/values.yaml
configuration:
  provider: aws
  backupStorageLocation:
    bucket: velero-backups-prod
    config:
      region: us-west-2
  volumeSnapshotLocation:
    config:
      region: us-west-2

credentials:
  useSecret: true
  secretContents:
    cloud: |
      [default]
      aws_access_key_id=AKIA...
      aws_secret_access_key=...

schedules:
  daily-backup:
    schedule: "0 2 * * *"
    template:
      includedNamespaces:
      - default
      - kube-system
      excludedResources:
      - events
      - events.events.k8s.io
      ttl: "720h"
  
  weekly-backup:
    schedule: "0 3 * * 0"
    template:
      includedNamespaces:
      - "*"
      ttl: "2160h"
```

#### **Backup Policies**

```yaml
# velero/backup-policies.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: backup-policies
  namespace: velero
data:
  daily-policy.yaml: |
    apiVersion: velero.io/v1
    kind: BackupStorageLocation
    metadata:
      name: daily-backups
    spec:
      provider: aws
      objectStorage:
        bucket: velero-daily-backups
      config:
        region: us-west-2
  
  disaster-recovery.yaml: |
    # Disaster recovery procedures
    # 1. Restore cluster from backup
    # 2. Verify data integrity
    # 3. Update DNS records
    # 4. Test application functionality
```

---

## 📖 Navigation

- **[← Back to Implementation Guide](./implementation-guide.md)**
- **[Next: Comparison Analysis →](./comparison-analysis.md)**

---

*Last Updated: July 26, 2025*