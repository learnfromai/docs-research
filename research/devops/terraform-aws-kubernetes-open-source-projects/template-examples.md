# Template Examples: Working Terraform + AWS/Kubernetes/EKS Configurations

## 🎯 Overview

This document provides working code templates and configuration examples extracted from production-ready open source projects. These templates can be used as starting points for implementing Infrastructure as Code with Terraform, AWS, Kubernetes, and EKS.

## 🏗️ Complete EKS Cluster Templates

### 1. **Production-Ready EKS Cluster with Terraform**

#### Directory Structure
```
eks-terraform-template/
├── main.tf                 # Main configuration
├── variables.tf            # Input variables
├── outputs.tf             # Output values
├── versions.tf            # Provider versions
├── locals.tf              # Local values
├── modules/
│   ├── vpc/               # VPC module
│   ├── eks/               # EKS cluster module
│   ├── node-groups/       # Node groups module
│   └── addons/            # EKS add-ons module
└── examples/
    ├── dev/               # Development environment
    ├── staging/           # Staging environment
    └── prod/              # Production environment
```

#### Main Configuration (main.tf)
```hcl
terraform {
  required_version = ">= 1.5"
  
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
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
  
  backend "s3" {
    # Configure backend in backend.tf
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = local.common_tags
  }
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_availability_zones" "available" {
  state = "available"
}

# Local values
locals {
  cluster_name = "${var.project_name}-${var.environment}"
  
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Owner       = var.team_name
    CostCenter  = var.cost_center
    CreatedDate = formatdate("YYYY-MM-DD", timestamp())
  }
  
  # Kubernetes tags for resources
  cluster_tags = merge(local.common_tags, {
    "kubernetes.io/cluster/${local.cluster_name}" = "owned"
  })
}

# VPC Module
module "vpc" {
  source = "./modules/vpc"
  
  cluster_name = local.cluster_name
  cidr_block   = var.vpc_cidr
  
  availability_zones = slice(data.aws_availability_zones.available.names, 0, 3)
  
  enable_nat_gateway   = true
  single_nat_gateway   = var.environment != "prod"
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = local.cluster_tags
}

# EKS Cluster Module
module "eks" {
  source = "./modules/eks"
  
  cluster_name    = local.cluster_name
  cluster_version = var.cluster_version
  
  vpc_id         = module.vpc.vpc_id
  subnet_ids     = module.vpc.private_subnets
  
  endpoint_private_access = var.endpoint_private_access
  endpoint_public_access  = var.endpoint_public_access
  public_access_cidrs     = var.public_access_cidrs
  
  enable_cluster_encryption = var.enable_cluster_encryption
  kms_key_arn              = var.kms_key_arn
  
  cluster_log_types = var.cluster_log_types
  log_retention_days = var.log_retention_days
  
  tags = local.cluster_tags
}

# Managed Node Groups
module "node_groups" {
  source = "./modules/node-groups"
  
  cluster_name = module.eks.cluster_name
  
  node_groups = var.node_groups
  subnet_ids  = module.vpc.private_subnets
  
  cluster_security_group_id        = module.eks.cluster_security_group_id
  cluster_primary_security_group_id = module.eks.cluster_primary_security_group_id
  
  tags = local.cluster_tags
  
  depends_on = [module.eks]
}

# EKS Add-ons
module "addons" {
  source = "./modules/addons"
  
  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn
  
  # AWS Native Add-ons
  eks_addons = var.eks_addons
  
  # Community Add-ons
  enable_aws_load_balancer_controller = var.enable_aws_load_balancer_controller
  enable_cluster_autoscaler           = var.enable_cluster_autoscaler
  enable_metrics_server               = var.enable_metrics_server
  enable_prometheus                   = var.enable_prometheus
  enable_grafana                      = var.enable_grafana
  enable_argocd                       = var.enable_argocd
  
  tags = local.cluster_tags
  
  depends_on = [module.node_groups]
}

# Configure kubectl provider
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}
```

#### Variables Definition (variables.tf)
```hcl
# Project Configuration
variable "project_name" {
  description = "Name of the project"
  type        = string
  
  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]*$", var.project_name))
    error_message = "Project name must start with a letter and contain only alphanumeric characters and hyphens."
  }
}

variable "environment" {
  description = "Environment name"
  type        = string
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "team_name" {
  description = "Name of the team owning this infrastructure"
  type        = string
  default     = "platform-team"
}

variable "cost_center" {
  description = "Cost center for billing"
  type        = string
  default     = "engineering"
}

# AWS Configuration
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

# VPC Configuration
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
  
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid IPv4 CIDR block."
  }
}

# EKS Cluster Configuration
variable "cluster_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
  default     = "1.28"
  
  validation {
    condition     = can(regex("^1\\.(2[4-9]|[3-9][0-9])$", var.cluster_version))
    error_message = "Cluster version must be 1.24 or higher."
  }
}

variable "endpoint_private_access" {
  description = "Enable private API server endpoint"
  type        = bool
  default     = true
}

variable "endpoint_public_access" {
  description = "Enable public API server endpoint"
  type        = bool
  default     = true
}

variable "public_access_cidrs" {
  description = "List of CIDR blocks that can access the public API server endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enable_cluster_encryption" {
  description = "Enable cluster encryption"
  type        = bool
  default     = true
}

variable "kms_key_arn" {
  description = "ARN of KMS key for cluster encryption"
  type        = string
  default     = ""
}

variable "cluster_log_types" {
  description = "List of control plane log types to enable"
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "log_retention_days" {
  description = "CloudWatch log retention period in days"
  type        = number
  default     = 7
  
  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.log_retention_days)
    error_message = "Log retention days must be a valid CloudWatch retention period."
  }
}

# Node Groups Configuration
variable "node_groups" {
  description = "Map of node group configurations"
  type = map(object({
    instance_types   = list(string)
    capacity_type    = string
    desired_capacity = number
    max_capacity     = number
    min_capacity     = number
    disk_size        = number
    labels           = map(string)
    taints = list(object({
      key    = string
      value  = string
      effect = string
    }))
  }))
  
  default = {
    main = {
      instance_types   = ["t3.medium"]
      capacity_type    = "ON_DEMAND"
      desired_capacity = 3
      max_capacity     = 6
      min_capacity     = 3
      disk_size        = 20
      labels = {
        "node.kubernetes.io/instance-type" = "t3.medium"
      }
      taints = []
    }
  }
}

# EKS Add-ons Configuration
variable "eks_addons" {
  description = "Map of EKS native add-ons to install"
  type = map(object({
    version               = string
    configuration_values  = string
    resolve_conflicts     = string
  }))
  
  default = {
    coredns = {
      version               = null
      configuration_values = null
      resolve_conflicts     = "OVERWRITE"
    }
    vpc-cni = {
      version = null
      configuration_values = jsonencode({
        env = {
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = "1"
        }
      })
      resolve_conflicts = "OVERWRITE"
    }
    aws-ebs-csi-driver = {
      version               = null
      configuration_values = null
      resolve_conflicts     = "OVERWRITE"
    }
  }
}

# Community Add-ons
variable "enable_aws_load_balancer_controller" {
  description = "Enable AWS Load Balancer Controller"
  type        = bool
  default     = true
}

variable "enable_cluster_autoscaler" {
  description = "Enable Cluster Autoscaler"
  type        = bool
  default     = true
}

variable "enable_metrics_server" {
  description = "Enable Metrics Server"
  type        = bool
  default     = true
}

variable "enable_prometheus" {
  description = "Enable Prometheus monitoring stack"
  type        = bool
  default     = false
}

variable "enable_grafana" {
  description = "Enable Grafana dashboards"
  type        = bool
  default     = false
}

variable "enable_argocd" {
  description = "Enable ArgoCD for GitOps"
  type        = bool
  default     = false
}
```

#### Outputs Definition (outputs.tf)
```hcl
# Cluster Information
output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_version" {
  description = "The Kubernetes server version for the EKS cluster"
  value       = module.eks.cluster_version
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

output "cluster_iam_role_arn" {
  description = "IAM role ARN of the EKS cluster"
  value       = module.eks.cluster_iam_role_arn
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster for the OpenID Connect identity provider"
  value       = module.eks.cluster_oidc_issuer_url
}

output "oidc_provider_arn" {
  description = "The ARN of the OIDC Provider if enabled"
  value       = module.eks.oidc_provider_arn
}

# VPC Information
output "vpc_id" {
  description = "ID of the VPC where the cluster is deployed"
  value       = module.vpc.vpc_id
}

output "private_subnets" {
  description = "List of IDs of private subnets"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "List of IDs of public subnets"
  value       = module.vpc.public_subnets
}

# Node Groups Information
output "node_groups" {
  description = "Map of node groups and their attributes"
  value       = module.node_groups.node_groups
}

# kubectl Configuration
output "kubectl_config" {
  description = "kubectl config command to configure access to the cluster"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

# Add-ons Information
output "enabled_addons" {
  description = "Map of enabled EKS add-ons"
  value       = module.addons.enabled_addons
}
```

---

## 🔧 Module Templates

### 1. **VPC Module Template**

#### modules/vpc/main.tf
```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

locals {
  # Calculate subnet CIDRs
  public_subnet_cidrs  = [for i in range(length(var.availability_zones)) : cidrsubnet(var.cidr_block, 8, i)]
  private_subnet_cidrs = [for i in range(length(var.availability_zones)) : cidrsubnet(var.cidr_block, 8, i + 100)]
  
  # Common tags for subnets
  subnet_tags = merge(var.tags, {
    "kubernetes.io/role/elb"              = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  })
}

# VPC
resource "aws_vpc" "main" {
  cidr_block = var.cidr_block
  
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support
  
  tags = merge(var.tags, {
    Name = "${var.cluster_name}-vpc"
  })
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  
  tags = merge(var.tags, {
    Name = "${var.cluster_name}-igw"
  })
}

# Public Subnets
resource "aws_subnet" "public" {
  count = length(var.availability_zones)
  
  vpc_id            = aws_vpc.main.id
  cidr_block        = local.public_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]
  
  map_public_ip_on_launch = true
  
  tags = merge(local.subnet_tags, {
    Name = "${var.cluster_name}-public-${var.availability_zones[count.index]}"
    "kubernetes.io/role/elb" = "1"
  })
}

# Private Subnets
resource "aws_subnet" "private" {
  count = length(var.availability_zones)
  
  vpc_id            = aws_vpc.main.id
  cidr_block        = local.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]
  
  tags = merge(local.subnet_tags, {
    Name = "${var.cluster_name}-private-${var.availability_zones[count.index]}"
    "kubernetes.io/role/internal-elb" = "1"
  })
}

# Elastic IPs for NAT Gateways
resource "aws_eip" "nat" {
  count = var.single_nat_gateway ? 1 : length(var.availability_zones)
  
  domain = "vpc"
  
  tags = merge(var.tags, {
    Name = "${var.cluster_name}-eip-${count.index + 1}"
  })
  
  depends_on = [aws_internet_gateway.main]
}

# NAT Gateways
resource "aws_nat_gateway" "main" {
  count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.availability_zones)) : 0
  
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  
  tags = merge(var.tags, {
    Name = "${var.cluster_name}-nat-${count.index + 1}"
  })
  
  depends_on = [aws_internet_gateway.main]
}

# Route Tables
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  
  tags = merge(var.tags, {
    Name = "${var.cluster_name}-public-rt"
  })
}

resource "aws_route_table" "private" {
  count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.availability_zones)) : 0
  
  vpc_id = aws_vpc.main.id
  
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }
  
  tags = merge(var.tags, {
    Name = "${var.cluster_name}-private-rt-${count.index + 1}"
  })
}

# Route Table Associations
resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)
  
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)
  
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = var.single_nat_gateway ? aws_route_table.private[0].id : aws_route_table.private[count.index].id
}

# VPC Flow Logs
resource "aws_flow_log" "main" {
  count = var.enable_flow_logs ? 1 : 0
  
  iam_role_arn    = aws_iam_role.flow_log[0].arn
  log_destination = aws_cloudwatch_log_group.flow_log[0].arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.main.id
  
  tags = merge(var.tags, {
    Name = "${var.cluster_name}-flow-logs"
  })
}

resource "aws_cloudwatch_log_group" "flow_log" {
  count = var.enable_flow_logs ? 1 : 0
  
  name              = "/aws/vpc/${var.cluster_name}/flowlogs"
  retention_in_days = var.flow_log_retention_days
  
  tags = var.tags
}

resource "aws_iam_role" "flow_log" {
  count = var.enable_flow_logs ? 1 : 0
  
  name = "${var.cluster_name}-flow-log-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })
  
  tags = var.tags
}

resource "aws_iam_role_policy" "flow_log" {
  count = var.enable_flow_logs ? 1 : 0
  
  name = "${var.cluster_name}-flow-log-policy"
  role = aws_iam_role.flow_log[0].id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}
```

### 2. **EKS Module Template**

#### modules/eks/main.tf
```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

# KMS Key for cluster encryption
resource "aws_kms_key" "cluster" {
  count = var.enable_cluster_encryption && var.kms_key_arn == "" ? 1 : 0
  
  description             = "EKS Cluster encryption key for ${var.cluster_name}"
  deletion_window_in_days = 7
  
  tags = merge(var.tags, {
    Name = "${var.cluster_name}-encryption-key"
  })
}

resource "aws_kms_alias" "cluster" {
  count = var.enable_cluster_encryption && var.kms_key_arn == "" ? 1 : 0
  
  name          = "alias/${var.cluster_name}-encryption-key"
  target_key_id = aws_kms_key.cluster[0].key_id
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "cluster" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.enable_cluster_encryption ? (var.kms_key_arn != "" ? var.kms_key_arn : aws_kms_key.cluster[0].arn) : null
  
  tags = var.tags
}

# EKS Cluster IAM Role
resource "aws_iam_role" "cluster" {
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
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
  
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

# Additional cluster security group
resource "aws_security_group" "cluster" {
  name_prefix = "${var.cluster_name}-cluster-"
  vpc_id      = var.vpc_id
  description = "EKS cluster security group"
  
  # Allow all egress
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = merge(var.tags, {
    Name = "${var.cluster_name}-cluster-sg"
  })
}

# Security group rules for cluster
resource "aws_security_group_rule" "cluster_ingress_workstation_https" {
  count = length(var.public_access_cidrs) > 0 ? 1 : 0
  
  description       = "Allow workstation to communicate with the cluster API Server"
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = var.public_access_cidrs
  security_group_id = aws_security_group.cluster.id
}

# EKS Cluster
resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = aws_iam_role.cluster.arn
  version  = var.cluster_version
  
  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_private_access = var.endpoint_private_access
    endpoint_public_access  = var.endpoint_public_access
    public_access_cidrs     = var.public_access_cidrs
    security_group_ids      = [aws_security_group.cluster.id]
  }
  
  dynamic "encryption_config" {
    for_each = var.enable_cluster_encryption ? [1] : []
    content {
      provider {
        key_arn = var.kms_key_arn != "" ? var.kms_key_arn : aws_kms_key.cluster[0].arn
      }
      resources = ["secrets"]
    }
  }
  
  enabled_cluster_log_types = var.cluster_log_types
  
  tags = var.tags
  
  depends_on = [
    aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy,
    aws_cloudwatch_log_group.cluster
  ]
}

# OIDC Identity Provider
data "tls_certificate" "cluster" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "cluster" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer
  
  tags = var.tags
}

# Data sources
data "aws_caller_identity" "current" {}
```

---

## 📊 GitOps Templates

### 1. **ArgoCD Application Templates**

#### App-of-Apps Pattern
```yaml
# apps/app-of-apps.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: app-of-apps
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
  annotations:
    argocd.argoproj.io/sync-wave: "-1"
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/gitops-configs
    targetRevision: HEAD
    path: applications
    directory:
      recurse: true
      jsonnet: {}
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
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
---
# Application project for team isolation
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: team-a-project
  namespace: argocd
spec:
  description: "Project for Team A applications"
  sourceRepos:
  - 'https://github.com/your-org/*'
  - 'https://charts.bitnami.com/bitnami'
  - 'https://prometheus-community.github.io/helm-charts'
  destinations:
  - namespace: 'team-a-*'
    server: https://kubernetes.default.svc
  - namespace: 'monitoring'
    server: https://kubernetes.default.svc
  clusterResourceWhitelist:
  - group: ''
    kind: Namespace
  - group: rbac.authorization.k8s.io
    kind: ClusterRole
  - group: rbac.authorization.k8s.io
    kind: ClusterRoleBinding
  namespaceResourceWhitelist:
  - group: ''
    kind: ConfigMap
  - group: ''
    kind: Secret
  - group: ''
    kind: Service
  - group: apps
    kind: Deployment
  - group: networking.k8s.io
    kind: Ingress
  roles:
  - name: team-a-admin
    description: "Admin access for Team A"
    policies:
    - p, proj:team-a-project:team-a-admin, applications, *, team-a-project/*, allow
    - p, proj:team-a-project:team-a-admin, repositories, *, *, allow
    groups:
    - team-a-admins
  - name: team-a-developer
    description: "Developer access for Team A"
    policies:
    - p, proj:team-a-project:team-a-developer, applications, get, team-a-project/*, allow
    - p, proj:team-a-project:team-a-developer, applications, sync, team-a-project/*, allow
    groups:
    - team-a-developers
```

#### Monitoring Stack Application
```yaml
# applications/monitoring/kube-prometheus-stack.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: kube-prometheus-stack
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "2"
spec:
  project: default
  source:
    repoURL: https://prometheus-community.github.io/helm-charts
    chart: kube-prometheus-stack
    targetRevision: 55.5.0
    helm:
      releaseName: kube-prometheus-stack
      values: |
        fullnameOverride: prometheus
        
        defaultRules:
          create: true
          rules:
            alertmanager: true
            etcd: true
            configReloaders: true
            general: true
            k8s: true
            kubeApiserver: true
            kubeApiserverAvailability: true
            kubeApiserverSlos: true
            kubelet: true
            kubeProxy: true
            kubePrometheusGeneral: true
            kubePrometheusNodeRecording: true
            kubernetesApps: true
            kubernetesResources: true
            kubernetesStorage: true
            kubernetesSystem: true
            kubeScheduler: true
            kubeStateMetrics: true
            network: true
            node: true
            nodeExporterAlerting: true
            nodeExporterRecording: true
            prometheus: true
            prometheusOperator: true
        
        prometheus:
          prometheusSpec:
            serviceMonitorSelectorNilUsesHelmValues: false
            podMonitorSelectorNilUsesHelmValues: false
            ruleSelectorNilUsesHelmValues: false
            retention: 30d
            storageSpec:
              volumeClaimTemplate:
                spec:
                  storageClassName: gp3
                  accessModes: ["ReadWriteOnce"]
                  resources:
                    requests:
                      storage: 50Gi
            resources:
              requests:
                cpu: 200m
                memory: 2Gi
              limits:
                cpu: 1000m
                memory: 4Gi
        
        grafana:
          enabled: true
          adminPassword: admin123 # Use secrets in production
          persistence:
            enabled: true
            storageClassName: gp3
            size: 10Gi
          service:
            type: LoadBalancer
            annotations:
              service.beta.kubernetes.io/aws-load-balancer-type: nlb
              service.beta.kubernetes.io/aws-load-balancer-internal: "true"
          grafana.ini:
            server:
              domain: grafana.internal.company.com
              root_url: https://grafana.internal.company.com
            auth.github:
              enabled: true
              allow_sign_up: true
              client_id: your-github-client-id
              client_secret: your-github-client-secret
              scopes: user:email,read:org
              auth_url: https://github.com/login/oauth/authorize
              token_url: https://github.com/login/oauth/access_token
              api_url: https://api.github.com/user
              allowed_organizations: your-github-org
          dashboardProviders:
            dashboardproviders.yaml:
              apiVersion: 1
              providers:
              - name: 'grafana-dashboards-kubernetes'
                orgId: 1
                folder: 'Kubernetes'
                type: file
                disableDeletion: true
                editable: true
                options:
                  path: /var/lib/grafana/dashboards/grafana-dashboards-kubernetes
        
        alertmanager:
          alertmanagerSpec:
            storage:
              volumeClaimTemplate:
                spec:
                  storageClassName: gp3
                  accessModes: ["ReadWriteOnce"]
                  resources:
                    requests:
                      storage: 10Gi
          config:
            global:
              smtp_smarthost: 'localhost:587'
              smtp_from: 'alerts@company.com'
            route:
              group_by: ['alertname']
              group_wait: 10s
              group_interval: 10s
              repeat_interval: 1h
              receiver: 'web.hook'
            receivers:
            - name: 'web.hook'
              slack_configs:
              - api_url: 'https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK'
                channel: '#alerts'
                title: 'Kubernetes Alert'
                text: 'Summary: {{ range .Alerts }}{{ .Annotations.summary }}{{ end }}'
  destination:
    server: https://kubernetes.default.svc
    namespace: monitoring
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
    retry:
      limit: 3
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
```

---

## 🔐 Security Templates

### 1. **Pod Security Standards**
```yaml
# security/pod-security-standards.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
---
apiVersion: v1
kind: Namespace
metadata:
  name: development
  labels:
    pod-security.kubernetes.io/enforce: baseline
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
---
# Network policy template
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
  name: allow-same-namespace
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: production
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: production
  - to: {}
    ports:
    - protocol: TCP
      port: 53
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 443
```

### 2. **OPA Gatekeeper Policies**
```yaml
# security/gatekeeper-policies.yaml
apiVersion: templates.gatekeeper.sh/v1beta1
kind: ConstraintTemplate
metadata:
  name: k8srequiredsecuritycontext
spec:
  crd:
    spec:
      names:
        kind: K8sRequiredSecurityContext
      validation:
        openAPIV3Schema:
          type: object
          properties:
            runAsNonRoot:
              type: boolean
            runAsUser:
              type: integer
            fsGroup:
              type: integer
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8srequiredsecuritycontext
        
        violation[{"msg": msg}] {
          container := input.review.object.spec.containers[_]
          not container.securityContext.runAsNonRoot
          msg := "Container must run as non-root user"
        }
        
        violation[{"msg": msg}] {
          container := input.review.object.spec.containers[_]
          not container.securityContext.allowPrivilegeEscalation == false
          msg := "Container must not allow privilege escalation"
        }
        
        violation[{"msg": msg}] {
          container := input.review.object.spec.containers[_]
          container.securityContext.privileged
          msg := "Container must not be privileged"
        }
---
apiVersion: config.gatekeeper.sh/v1alpha1
kind: K8sRequiredSecurityContext
metadata:
  name: must-have-security-context
spec:
  match:
    - apiGroups: ["apps"]
      kinds: ["Deployment"]
      namespaces: ["production"]
  parameters:
    runAsNonRoot: true
```

---

## 🔗 Navigation

← [Back to Best Practices](./best-practices.md) | [Next: Comparison Analysis](./comparison-analysis.md) →