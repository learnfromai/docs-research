# Best Practices

Production-proven patterns and best practices extracted from analyzing 25+ open source DevOps projects using Terraform with AWS and Kubernetes/EKS.

## 🏗️ Terraform Best Practices

### Module Organization

**1. Hierarchical Module Structure**
```
project/
├── modules/
│   ├── vpc/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── versions.tf
│   ├── eks/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── versions.tf
│   └── security/
├── environments/
│   ├── dev/
│   ├── staging/
│   └── prod/
└── shared/
    ├── backend.tf
    └── providers.tf
```

**2. Version Constraints (from terraform-aws-modules)**
```hcl
# versions.tf
terraform {
  required_version = ">= 1.5.7"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.10"
    }
  }
}
```

**3. Remote State Management**
```hcl
# backend.tf
terraform {
  backend "s3" {
    bucket         = "my-terraform-state-bucket"
    key            = "environments/prod/terraform.tfstate"
    region         = "us-west-2"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
```

### Variable Design Patterns

**1. Comprehensive Variable Definitions**
```hcl
# variables.tf (following aws-ia/terraform-aws-eks-blueprints pattern)
variable "name" {
  description = "Name of the EKS cluster"
  type        = string
  
  validation {
    condition     = length(var.name) <= 100
    error_message = "Cluster name must be 100 characters or less."
  }
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.33"
  
  validation {
    condition = contains([
      "1.29", "1.30", "1.31", "1.32", "1.33"
    ], var.kubernetes_version)
    error_message = "Kubernetes version must be a supported version."
  }
}

variable "eks_managed_node_groups" {
  description = "Map of EKS managed node group definitions"
  type = map(object({
    instance_types = list(string)
    min_size      = number
    max_size      = number
    desired_size  = number
    capacity_type = optional(string, "ON_DEMAND")
    ami_type      = optional(string, "AL2023_x86_64_STANDARD")
    
    taints = optional(map(object({
      key    = string
      value  = optional(string)
      effect = string
    })), {})
    
    labels = optional(map(string), {})
  }))
  default = {}
}
```

**2. Environment-Specific Configurations**
```hcl
# environments/prod/terraform.tfvars
name               = "production-cluster"
kubernetes_version = "1.33"

vpc_cidr = "10.0.0.0/16"
azs      = ["us-west-2a", "us-west-2b", "us-west-2c"]

eks_managed_node_groups = {
  production = {
    instance_types = ["m5.xlarge", "m5.2xlarge"]
    min_size      = 3
    max_size      = 10
    desired_size  = 5
    capacity_type = "ON_DEMAND"
    
    labels = {
      Environment = "production"
      NodeGroup   = "production"
    }
    
    taints = {
      production = {
        key    = "production"
        value  = "true"
        effect = "NO_SCHEDULE"
      }
    }
  }
  
  spot = {
    instance_types = ["m5.large", "m5.xlarge", "m4.large"]
    min_size      = 1
    max_size      = 5
    desired_size  = 2
    capacity_type = "SPOT"
    
    labels = {
      Environment = "production"
      NodeGroup   = "spot"
    }
  }
}
```

### Tagging Strategy

**1. Consistent Tagging (from multiple projects)**
```hcl
locals {
  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    Owner       = var.owner
    CostCenter  = var.cost_center
    Terraform   = "true"
    
    # EKS-specific tags
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }
  
  # VPC subnet tags for load balancer discovery
  public_subnet_tags = merge(local.common_tags, {
    "kubernetes.io/role/elb" = "1"
    Type                     = "public"
  })
  
  private_subnet_tags = merge(local.common_tags, {
    "kubernetes.io/role/internal-elb" = "1"
    Type                              = "private"
  })
}

# Apply tags to resources
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-vpc"
  })
}
```

## ⚙️ EKS Configuration Best Practices

### Cluster Security

**1. IAM Roles and Policies (from cloudposse patterns)**
```hcl
# EKS Cluster IAM Role
resource "aws_iam_role" "eks_cluster" {
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
  
  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

# Additional policies for enhanced security
resource "aws_iam_role_policy_attachment" "eks_vpc_resource_controller" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.eks_cluster.name
}
```

**2. Security Group Configuration**
```hcl
# Cluster security group
resource "aws_security_group" "cluster" {
  name_prefix = "${var.cluster_name}-cluster-"
  vpc_id      = var.vpc_id
  
  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  # Allow inbound from node groups
  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.node_groups.id]
  }
  
  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-cluster-sg"
  })
}

# Node group security group
resource "aws_security_group" "node_groups" {
  name_prefix = "${var.cluster_name}-node-"
  vpc_id      = var.vpc_id
  
  # Allow communication between nodes
  ingress {
    from_port = 0
    to_port   = 65535
    protocol  = "tcp"
    self      = true
  }
  
  # Allow communication from cluster
  ingress {
    from_port       = 1025
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.cluster.id]
  }
  
  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-node-sg"
  })
}
```

### Node Group Configuration

**1. Multi-AZ Node Groups (from maddevsio patterns)**
```hcl
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-nodes"
  node_role_arn   = aws_iam_role.node_group.arn
  subnet_ids      = var.private_subnet_ids
  
  # Instance configuration
  instance_types = var.instance_types
  ami_type       = "AL2023_x86_64_STANDARD"
  capacity_type  = "ON_DEMAND"
  disk_size      = 50
  
  # Scaling configuration
  scaling_config {
    desired_size = var.desired_size
    max_size     = var.max_size
    min_size     = var.min_size
  }
  
  # Update configuration
  update_config {
    max_unavailable = 1
  }
  
  # Launch template for custom configuration
  launch_template {
    id      = aws_launch_template.node_group.id
    version = aws_launch_template.node_group.latest_version
  }
  
  # Labels for workload placement
  labels = {
    Environment = var.environment
    NodeGroup   = "primary"
  }
  
  # Taints for specialized workloads
  dynamic "taint" {
    for_each = var.node_taints
    content {
      key    = taint.value.key
      value  = taint.value.value
      effect = taint.value.effect
    }
  }
  
  tags = local.common_tags
  
  depends_on = [
    aws_iam_role_policy_attachment.node_group_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node_group_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.node_group_AmazonEC2ContainerRegistryReadOnly,
  ]
}
```

**2. Launch Template for Advanced Configuration**
```hcl
resource "aws_launch_template" "node_group" {
  name_prefix = "${var.cluster_name}-node-"
  
  # Instance configuration
  instance_type = var.instance_types[0]
  
  # Security group
  vpc_security_group_ids = [aws_security_group.node_groups.id]
  
  # User data for custom bootstrap
  user_data = base64encode(templatefile(
    "${path.module}/templates/user_data.sh.tpl",
    {
      cluster_name        = var.cluster_name
      cluster_endpoint    = aws_eks_cluster.main.endpoint
      cluster_ca          = aws_eks_cluster.main.certificate_authority[0].data
      bootstrap_arguments = var.bootstrap_arguments
    }
  ))
  
  # EBS optimization
  ebs_optimized = true
  
  # Block device mappings
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 50
      volume_type          = "gp3"
      encrypted            = true
      delete_on_termination = true
    }
  }
  
  # Metadata options for security
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
    http_put_response_hop_limit = 2
  }
  
  # Network interfaces for ENI configuration
  network_interfaces {
    associate_public_ip_address = false
    delete_on_termination       = true
    security_groups            = [aws_security_group.node_groups.id]
  }
  
  tag_specifications {
    resource_type = "instance"
    tags = merge(local.common_tags, {
      Name = "${var.cluster_name}-node"
    })
  }
  
  lifecycle {
    create_before_destroy = true
  }
}
```

### Add-ons Management

**1. Core Add-ons (from aws-ia blueprints)**
```hcl
# EBS CSI Driver
resource "aws_eks_addon" "ebs_csi" {
  cluster_name             = aws_eks_cluster.main.name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = var.ebs_csi_addon_version
  service_account_role_arn = aws_iam_role.ebs_csi_driver.arn
  
  configuration_values = jsonencode({
    controller = {
      replicaCount = 2
      resources = {
        limits = {
          cpu    = "100m"
          memory = "128Mi"
        }
        requests = {
          cpu    = "50m"
          memory = "64Mi"
        }
      }
    }
  })
  
  tags = local.common_tags
}

# VPC CNI Add-on
resource "aws_eks_addon" "vpc_cni" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "vpc-cni"
  addon_version = var.vpc_cni_addon_version
  
  configuration_values = jsonencode({
    env = {
      ENABLE_PREFIX_DELEGATION = "true"
      WARM_PREFIX_TARGET       = "1"
    }
  })
  
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  
  tags = local.common_tags
}

# CoreDNS Add-on
resource "aws_eks_addon" "coredns" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "coredns"
  addon_version = var.coredns_addon_version
  
  configuration_values = jsonencode({
    replicaCount = 2
    resources = {
      limits = {
        memory = "170Mi"
      }
      requests = {
        cpu    = "100m"
        memory = "70Mi"
      }
    }
  })
  
  tags = local.common_tags
}
```

## 🔐 Security Best Practices

### Pod Security Standards

**1. Pod Security Policies (from security-focused projects)**
```yaml
# pod-security-policy.yaml
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: restricted
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

**2. Network Policies**
```yaml
# default-deny-network-policy.yaml
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
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-internal
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: internal-service
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: production
    ports:
    - protocol: TCP
      port: 8080
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: production
    ports:
    - protocol: TCP
      port: 5432
```

### IRSA (IAM Roles for Service Accounts)

**1. OIDC Provider Setup**
```hcl
# OIDC provider for IRSA
data "tls_certificate" "cluster" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "cluster" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer
  
  tags = local.common_tags
}
```

**2. Service Account IAM Role**
```hcl
# AWS Load Balancer Controller IAM Role
module "load_balancer_controller_irsa_role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  
  role_name = "${var.cluster_name}-aws-load-balancer-controller"
  
  attach_load_balancer_controller_policy = true
  
  oidc_providers = {
    ex = {
      provider_arn               = aws_iam_openid_connect_provider.cluster.arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
  
  tags = local.common_tags
}
```

## 📊 Monitoring and Observability

### Prometheus and Grafana Setup

**1. Helm Chart Deployment**
```hcl
# Prometheus Operator
resource "helm_release" "prometheus" {
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = "monitoring"
  
  create_namespace = true
  
  values = [
    yamlencode({
      grafana = {
        adminPassword = var.grafana_admin_password
        persistence = {
          enabled = true
          size    = "10Gi"
        }
        service = {
          type = "LoadBalancer"
          annotations = {
            "service.beta.kubernetes.io/aws-load-balancer-type" = "nlb"
          }
        }
      }
      
      prometheus = {
        prometheusSpec = {
          retention = "30d"
          storageSpec = {
            volumeClaimTemplate = {
              spec = {
                storageClassName = "gp3"
                accessModes      = ["ReadWriteOnce"]
                resources = {
                  requests = {
                    storage = "50Gi"
                  }
                }
              }
            }
          }
        }
      }
    })
  ]
  
  depends_on = [aws_eks_node_group.main]
}
```

### Logging with Fluent Bit

**1. Fluent Bit Configuration**
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
        Flush         1
        Log_Level     info
        Daemon        off
        Parsers_File  parsers.conf
        HTTP_Server   On
        HTTP_Listen   0.0.0.0
        HTTP_Port     2020

    @INCLUDE application-log.conf
    @INCLUDE dataplane-log.conf
    @INCLUDE host-log.conf

  application-log.conf: |
    [INPUT]
        Name              tail
        Tag               application.*
        Exclude_Path      /var/log/containers/cloudwatch-agent*, /var/log/containers/fluent-bit*, /var/log/containers/aws-node*, /var/log/containers/kube-proxy*
        Path              /var/log/containers/*.log
        Docker_Mode       On
        Docker_Mode_Flush 5
        Docker_Mode_Parser container_firstline
        Parser            docker
        DB                /var/fluent-bit/state/flb_container.db
        Mem_Buf_Limit     50MB
        Skip_Long_Lines   On
        Refresh_Interval  10
        Rotate_Wait       30
        storage.type      filesystem
        Read_from_Head    ${READ_FROM_HEAD}

    [OUTPUT]
        Name                cloudwatch_logs
        Match               application.*
        region              ${AWS_REGION}
        log_group_name      /aws/containerinsights/${CLUSTER_NAME}/application
        log_stream_prefix   ${HOST_NAME}-
        auto_create_group   true
        extra_user_agent    container-insights
```

## 🚀 Performance Optimization

### Resource Management

**1. Resource Requests and Limits**
```yaml
# deployment-with-resources.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
  namespace: production
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web-app
  template:
    metadata:
      labels:
        app: web-app
    spec:
      containers:
      - name: web-app
        image: nginx:1.21-alpine
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 10
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 15
          periodSeconds: 20
      nodeSelector:
        kubernetes.io/arch: amd64
      tolerations:
      - key: "production"
        operator: "Equal"
        value: "true"
        effect: "NoSchedule"
```

### Cluster Autoscaling

**1. Horizontal Pod Autoscaler**
```yaml
# hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: web-app-hpa
  namespace: production
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: web-app
  minReplicas: 3
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
      stabilizationWindowSeconds: 0
      policies:
      - type: Percent
        value: 100
        periodSeconds: 15
      - type: Pods
        value: 4
        periodSeconds: 15
      selectPolicy: Max
```

## 🔧 Operational Excellence

### Backup and Disaster Recovery

**1. ETCD Backup Configuration**
```hcl
# S3 bucket for backups
resource "aws_s3_bucket" "backup" {
  bucket = "${var.cluster_name}-backup-${random_id.bucket_suffix.hex}"
  
  tags = local.common_tags
}

resource "aws_s3_bucket_versioning" "backup" {
  bucket = aws_s3_bucket.backup.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_encryption" "backup" {
  bucket = aws_s3_bucket.backup.id
  
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}

# IAM role for backup service
resource "aws_iam_role" "backup_service" {
  name = "${var.cluster_name}-backup-service"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "pods.amazonaws.com"
        }
      }
    ]
  })
  
  tags = local.common_tags
}
```

### Cost Optimization

**1. Spot Instance Configuration**
```hcl
# Mixed instance node group
resource "aws_eks_node_group" "spot" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-spot"
  node_role_arn   = aws_iam_role.node_group.arn
  subnet_ids      = var.private_subnet_ids
  
  capacity_type  = "SPOT"
  instance_types = ["m5.large", "m5.xlarge", "m4.large", "m4.xlarge"]
  
  scaling_config {
    desired_size = 2
    max_size     = 10
    min_size     = 0
  }
  
  labels = {
    "node.kubernetes.io/lifecycle" = "spot"
  }
  
  taints {
    key    = "spot"
    value  = "true"
    effect = "NO_SCHEDULE"
  }
  
  tags = merge(local.common_tags, {
    "k8s.io/cluster-autoscaler/node-template/label/node.kubernetes.io/lifecycle" = "spot"
    "k8s.io/cluster-autoscaler/node-template/taint/spot"                        = "true:NoSchedule"
  })
}
```

## 🔗 Navigation

**Previous**: [← Implementation Guide](./implementation-guide.md) | **Next**: [Comparison Analysis →](./comparison-analysis.md)