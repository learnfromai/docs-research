# Template Examples: Working Terraform Configurations

This document provides ready-to-use Terraform templates based on patterns from production open source projects.

## 🎯 Template Overview

All templates are production-ready and include:
- ✅ Security best practices
- ✅ Proper tagging and naming
- ✅ Environment-specific configurations
- ✅ Remote state management
- ✅ Comprehensive outputs

## 📁 Template 1: Complete EKS Cluster with Monitoring

### Directory Structure
```
complete-eks-cluster/
├── main.tf
├── variables.tf
├── outputs.tf
├── versions.tf
├── backend.tf
├── environments/
│   ├── dev.tfvars
│   ├── staging.tfvars
│   └── production.tfvars
└── modules/
    └── monitoring/
```

### `versions.tf`
```hcl
terraform {
  required_version = ">= 1.0"
  
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
}
```

### `backend.tf`
```hcl
terraform {
  backend "s3" {
    # Configuration provided via backend config file
    # terraform init -backend-config=backend-config.hcl
  }
}
```

### `main.tf`
```hcl
# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

# Local values
locals {
  name = "${var.environment}-${var.cluster_name}"
  
  common_tags = {
    Environment   = var.environment
    Project       = var.project_name
    ManagedBy     = "terraform"
    Owner         = var.owner
    CostCenter    = var.cost_center
    CreatedAt     = timestamp()
  }
  
  # VPC CIDR calculation
  vpc_cidr = var.vpc_cidr
  azs      = slice(data.aws_availability_zones.available.names, 0, var.availability_zones_count)
}

#------------------------------------------------------------------------------
# KMS Key for EKS encryption
#------------------------------------------------------------------------------
resource "aws_kms_key" "eks" {
  description             = "EKS Secret Encryption Key for ${local.name}"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  
  tags = merge(local.common_tags, {
    Name = "${local.name}-eks-encryption-key"
  })
}

resource "aws_kms_alias" "eks" {
  name          = "alias/${local.name}-eks"
  target_key_id = aws_kms_key.eks.key_id
}

#------------------------------------------------------------------------------
# VPC Module
#------------------------------------------------------------------------------
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${local.name}-vpc"
  cidr = local.vpc_cidr

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 48)]
  intra_subnets   = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 52)]

  enable_nat_gateway = true
  single_nat_gateway = var.environment == "dev" ? true : false
  enable_vpn_gateway = false

  enable_dns_hostnames = true
  enable_dns_support   = true

  # VPC Flow Logs
  enable_flow_log                      = true
  create_flow_log_cloudwatch_iam_role  = true
  create_flow_log_cloudwatch_log_group = true

  # Kubernetes tags
  public_subnet_tags = {
    "kubernetes.io/cluster/${local.name}" = "shared"
    "kubernetes.io/role/elb"              = 1
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.name}" = "shared"
    "kubernetes.io/role/internal-elb"     = 1
  }

  tags = local.common_tags
}

#------------------------------------------------------------------------------
# EKS Module
#------------------------------------------------------------------------------
module "eks" {
  source = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  cluster_name    = local.name
  cluster_version = var.kubernetes_version

  # Cluster access
  cluster_endpoint_public_access       = var.cluster_endpoint_public_access
  cluster_endpoint_private_access      = true
  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs

  # Encryption
  cluster_encryption_config = {
    provider_key_arn = aws_kms_key.eks.arn
    resources        = ["secrets"]
  }

  # Logging
  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  cloudwatch_log_group_retention_in_days = var.log_retention_days

  # Network
  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.intra_subnets

  # Security
  create_node_security_group = true
  node_security_group_additional_rules = {
    ingress_cluster_to_node_all_traffic = {
      description                   = "Cluster API to Nodegroup all traffic"
      protocol                      = "-1"
      from_port                     = 0
      to_port                       = 0
      type                          = "ingress"
      source_cluster_security_group = true
    }
  }

  # EKS Managed Node Groups
  eks_managed_node_groups = {
    for k, v in var.node_groups : k => {
      name           = "${local.name}-${k}"
      instance_types = v.instance_types
      capacity_type  = v.capacity_type

      min_size     = v.min_size
      max_size     = v.max_size
      desired_size = v.desired_size

      # Launch template
      create_launch_template = true
      launch_template_name   = "${local.name}-${k}"

      # Storage
      disk_size    = v.disk_size
      disk_type    = "gp3"
      disk_encrypted = true
      disk_kms_key_id = aws_kms_key.eks.arn

      # AMI
      ami_type = v.ami_type

      # Networking
      subnet_ids = module.vpc.private_subnets

      # Security
      vpc_security_group_ids = [module.eks.node_security_group_id]

      # Metadata options
      metadata_options = {
        http_endpoint               = "enabled"
        http_tokens                 = "required"
        http_put_response_hop_limit = 2
        instance_metadata_tags      = "disabled"
      }

      # User data
      enable_bootstrap_user_data = true
      bootstrap_extra_args       = "--container-runtime containerd"

      # Labels
      labels = merge(v.labels, {
        Environment = var.environment
        NodeGroup   = k
      })

      # Taints
      taints = v.taints

      # Auto-scaling tags
      tags = merge(local.common_tags, {
        "k8s.io/cluster-autoscaler/enabled" = "true"
        "k8s.io/cluster-autoscaler/${local.name}" = "owned"
      })
    }
  }

  # Fargate profiles
  fargate_profiles = var.enable_fargate ? {
    karpenter = {
      name = "karpenter"
      selectors = [
        { namespace = "karpenter" }
      ]
    }
  } : {}

  # IRSA
  enable_irsa = true

  # Cluster access
  manage_aws_auth_configmap = true
  aws_auth_roles = var.aws_auth_roles
  aws_auth_users = var.aws_auth_users

  tags = local.common_tags
}

#------------------------------------------------------------------------------
# Kubernetes Provider Configuration
#------------------------------------------------------------------------------
data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

#------------------------------------------------------------------------------
# EKS Add-ons
#------------------------------------------------------------------------------
resource "aws_eks_addon" "addons" {
  for_each = var.cluster_addons

  cluster_name             = module.eks.cluster_name
  addon_name               = each.key
  addon_version            = each.value.version
  resolve_conflicts        = "OVERWRITE"
  service_account_role_arn = try(each.value.service_account_role_arn, null)

  depends_on = [
    module.eks.eks_managed_node_groups,
  ]

  tags = local.common_tags
}

#------------------------------------------------------------------------------
# AWS Load Balancer Controller
#------------------------------------------------------------------------------
module "aws_load_balancer_controller_irsa_role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name = "${local.name}-aws-load-balancer-controller"

  attach_load_balancer_controller_policy = true

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }

  tags = local.common_tags
}

resource "helm_release" "aws_load_balancer_controller" {
  count = var.enable_aws_load_balancer_controller ? 1 : 0

  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = var.aws_load_balancer_controller_version

  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.aws_load_balancer_controller_irsa_role.iam_role_arn
  }

  depends_on = [
    module.eks.eks_managed_node_groups,
  ]
}

#------------------------------------------------------------------------------
# Cluster Autoscaler
#------------------------------------------------------------------------------
module "cluster_autoscaler_irsa_role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name                        = "${local.name}-cluster-autoscaler"
  attach_cluster_autoscaler_policy = true
  cluster_autoscaler_cluster_names = [module.eks.cluster_name]

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:cluster-autoscaler"]
    }
  }

  tags = local.common_tags
}

resource "helm_release" "cluster_autoscaler" {
  count = var.enable_cluster_autoscaler ? 1 : 0

  name       = "cluster-autoscaler"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  namespace  = "kube-system"
  version    = var.cluster_autoscaler_version

  set {
    name  = "autoDiscovery.clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "autoDiscovery.enabled"
    value = "true"
  }

  set {
    name  = "rbac.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.cluster_autoscaler_irsa_role.iam_role_arn
  }

  depends_on = [
    module.eks.eks_managed_node_groups,
  ]
}

#------------------------------------------------------------------------------
# Monitoring Module
#------------------------------------------------------------------------------
module "monitoring" {
  count = var.enable_monitoring ? 1 : 0

  source = "./modules/monitoring"

  cluster_name                = module.eks.cluster_name
  cluster_endpoint            = module.eks.cluster_endpoint
  cluster_certificate_authority_data = module.eks.cluster_certificate_authority_data
  oidc_provider_arn          = module.eks.oidc_provider_arn
  
  environment = var.environment
  tags        = local.common_tags
  
  # Monitoring configuration
  prometheus_retention = var.prometheus_retention
  grafana_admin_password = var.grafana_admin_password
  slack_webhook_url     = var.slack_webhook_url
  
  depends_on = [
    module.eks.eks_managed_node_groups,
  ]
}
```

### `variables.tf`
```hcl
#------------------------------------------------------------------------------
# General Variables
#------------------------------------------------------------------------------
variable "environment" {
  description = "Environment name (dev, staging, production)"
  type        = string
  
  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be one of: dev, staging, production."
  }
}

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "owner" {
  description = "Owner of the resources"
  type        = string
}

variable "cost_center" {
  description = "Cost center for billing"
  type        = string
  default     = ""
}

#------------------------------------------------------------------------------
# Cluster Variables
#------------------------------------------------------------------------------
variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.33"
}

variable "cluster_endpoint_public_access" {
  description = "Enable public API server endpoint"
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "List of CIDR blocks that can access the public API server endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

#------------------------------------------------------------------------------
# Network Variables
#------------------------------------------------------------------------------
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones_count" {
  description = "Number of availability zones to use"
  type        = number
  default     = 3
  
  validation {
    condition     = var.availability_zones_count >= 2 && var.availability_zones_count <= 6
    error_message = "Availability zones count must be between 2 and 6."
  }
}

#------------------------------------------------------------------------------
# Node Group Variables
#------------------------------------------------------------------------------
variable "node_groups" {
  description = "Map of EKS managed node group definitions"
  type = map(object({
    instance_types = list(string)
    capacity_type  = string
    min_size      = number
    max_size      = number
    desired_size  = number
    disk_size     = number
    ami_type      = string
    labels        = map(string)
    taints = map(object({
      key    = string
      value  = string
      effect = string
    }))
  }))
  
  default = {
    main = {
      instance_types = ["m5.large"]
      capacity_type  = "ON_DEMAND"
      min_size      = 1
      max_size      = 10
      desired_size  = 3
      disk_size     = 50
      ami_type      = "AL2023_x86_64_STANDARD"
      labels        = {}
      taints        = {}
    }
  }
}

#------------------------------------------------------------------------------
# Add-ons Variables
#------------------------------------------------------------------------------
variable "cluster_addons" {
  description = "Map of cluster addon configurations"
  type = map(object({
    version                 = string
    service_account_role_arn = optional(string)
  }))
  
  default = {
    coredns = {
      version = "v1.11.1-eksbuild.4"
    }
    kube-proxy = {
      version = "v1.29.0-eksbuild.1"
    }
    vpc-cni = {
      version = "v1.16.0-eksbuild.1"
    }
    aws-ebs-csi-driver = {
      version = "v1.26.1-eksbuild.1"
    }
  }
}

variable "enable_fargate" {
  description = "Enable Fargate profiles"
  type        = bool
  default     = false
}

variable "enable_aws_load_balancer_controller" {
  description = "Enable AWS Load Balancer Controller"
  type        = bool
  default     = true
}

variable "aws_load_balancer_controller_version" {
  description = "AWS Load Balancer Controller version"
  type        = string
  default     = "1.6.2"
}

variable "enable_cluster_autoscaler" {
  description = "Enable Cluster Autoscaler"
  type        = bool
  default     = true
}

variable "cluster_autoscaler_version" {
  description = "Cluster Autoscaler version"
  type        = string
  default     = "9.29.0"
}

#------------------------------------------------------------------------------
# Access Variables
#------------------------------------------------------------------------------
variable "aws_auth_roles" {
  description = "List of role maps to add to the aws-auth configmap"
  type = list(object({
    rolearn  = string
    username = string
    groups   = list(string)
  }))
  default = []
}

variable "aws_auth_users" {
  description = "List of user maps to add to the aws-auth configmap"
  type = list(object({
    userarn  = string
    username = string
    groups   = list(string)
  }))
  default = []
}

#------------------------------------------------------------------------------
# Monitoring Variables
#------------------------------------------------------------------------------
variable "enable_monitoring" {
  description = "Enable monitoring stack (Prometheus/Grafana)"
  type        = bool
  default     = true
}

variable "prometheus_retention" {
  description = "Prometheus data retention period"
  type        = string
  default     = "30d"
}

variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
  default     = ""
}

variable "slack_webhook_url" {
  description = "Slack webhook URL for alerts"
  type        = string
  sensitive   = true
  default     = ""
}
```

### `outputs.tf`
```hcl
#------------------------------------------------------------------------------
# Cluster Outputs
#------------------------------------------------------------------------------
output "cluster_arn" {
  description = "The Amazon Resource Name (ARN) of the cluster"
  value       = module.eks.cluster_arn
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.eks.cluster_certificate_authority_data
}

output "cluster_endpoint" {
  description = "Endpoint for your Kubernetes API server"
  value       = module.eks.cluster_endpoint
}

output "cluster_id" {
  description = "The ID of the EKS cluster"
  value       = module.eks.cluster_id
}

output "cluster_name" {
  description = "The name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster for the OpenID Connect identity provider"
  value       = module.eks.cluster_oidc_issuer_url
}

output "cluster_platform_version" {
  description = "Platform version for the cluster"
  value       = module.eks.cluster_platform_version
}

output "cluster_primary_security_group_id" {
  description = "Cluster security group that was created by Amazon EKS for the cluster"
  value       = module.eks.cluster_primary_security_group_id
}

output "cluster_security_group_id" {
  description = "ID of the cluster security group"
  value       = module.eks.cluster_security_group_id
}

output "cluster_status" {
  description = "Status of the EKS cluster"
  value       = module.eks.cluster_status
}

output "cluster_version" {
  description = "The Kubernetes version for the cluster"
  value       = module.eks.cluster_version
}

#------------------------------------------------------------------------------
# OIDC Provider Outputs
#------------------------------------------------------------------------------
output "oidc_provider" {
  description = "The OpenID Connect identity provider (issuer URL without leading `https://`)"
  value       = module.eks.oidc_provider
}

output "oidc_provider_arn" {
  description = "The ARN of the OIDC Provider if `enable_irsa = true`"
  value       = module.eks.oidc_provider_arn
}

#------------------------------------------------------------------------------
# Node Group Outputs
#------------------------------------------------------------------------------
output "eks_managed_node_groups" {
  description = "Map of attribute maps for all EKS managed node groups created"
  value       = module.eks.eks_managed_node_groups
  sensitive   = true
}

output "eks_managed_node_groups_autoscaling_group_names" {
  description = "List of the autoscaling group names created by EKS managed node groups"
  value       = module.eks.eks_managed_node_groups_autoscaling_group_names
}

#------------------------------------------------------------------------------
# VPC Outputs
#------------------------------------------------------------------------------
output "vpc_id" {
  description = "ID of the VPC where the cluster and its nodes will be provisioned"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "The CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}

output "private_subnets" {
  description = "List of IDs of private subnets"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "List of IDs of public subnets"
  value       = module.vpc.public_subnets
}

#------------------------------------------------------------------------------
# Access Configuration
#------------------------------------------------------------------------------
output "configure_kubectl" {
  description = "Configure kubectl: make sure you're logged in with the correct AWS profile and run the following command to update your kubeconfig"
  value = format("aws eks --region %s update-kubeconfig --name %s", 
    data.aws_region.current.name, 
    module.eks.cluster_name
  )
}

#------------------------------------------------------------------------------
# Monitoring Outputs (when enabled)
#------------------------------------------------------------------------------
output "grafana_url" {
  description = "Grafana dashboard URL"
  value       = var.enable_monitoring ? module.monitoring[0].grafana_url : null
}

output "prometheus_url" {
  description = "Prometheus server URL"
  value       = var.enable_monitoring ? module.monitoring[0].prometheus_url : null
}
```

### Environment-Specific Variables

#### `environments/dev.tfvars`
```hcl
# Development Environment Configuration
environment    = "dev"
project_name   = "my-project"
owner         = "devops-team"
cost_center   = "engineering"

cluster_name  = "my-project-dev"
kubernetes_version = "1.33"

# Network
vpc_cidr = "10.0.0.0/16"
availability_zones_count = 2

# Single NAT Gateway for cost savings in dev
# This is handled automatically based on environment in main.tf

# Node Groups - smaller instances for dev
node_groups = {
  main = {
    instance_types = ["t3.medium"]
    capacity_type  = "ON_DEMAND"
    min_size      = 1
    max_size      = 5
    desired_size  = 2
    disk_size     = 30
    ami_type      = "AL2023_x86_64_STANDARD"
    labels = {
      Role = "general"
    }
    taints = {}
  }
}

# Add-ons
enable_aws_load_balancer_controller = true
enable_cluster_autoscaler = true
enable_fargate = false

# Monitoring
enable_monitoring = true
prometheus_retention = "7d"
grafana_admin_password = "dev-password-change-me"

# Access
cluster_endpoint_public_access = true
cluster_endpoint_public_access_cidrs = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]

# Logging
log_retention_days = 3
```

#### `environments/production.tfvars`
```hcl
# Production Environment Configuration
environment    = "production"
project_name   = "my-project"
owner         = "platform-team"
cost_center   = "engineering"

cluster_name  = "my-project-prod"
kubernetes_version = "1.33"

# Network
vpc_cidr = "10.100.0.0/16"
availability_zones_count = 3

# Node Groups - production sizing
node_groups = {
  system = {
    instance_types = ["m5.large"]
    capacity_type  = "ON_DEMAND"
    min_size      = 3
    max_size      = 10
    desired_size  = 3
    disk_size     = 100
    ami_type      = "AL2023_x86_64_STANDARD"
    labels = {
      Role = "system"
    }
    taints = {
      system = {
        key    = "CriticalAddonsOnly"
        value  = "true"
        effect = "NO_SCHEDULE"
      }
    }
  }
  
  application = {
    instance_types = ["m5.xlarge", "m5a.xlarge"]
    capacity_type  = "SPOT"
    min_size      = 3
    max_size      = 50
    desired_size  = 10
    disk_size     = 100
    ami_type      = "AL2023_x86_64_STANDARD"
    labels = {
      Role = "application"
    }
    taints = {}
  }
}

# Add-ons
enable_aws_load_balancer_controller = true
enable_cluster_autoscaler = true
enable_fargate = true

# Monitoring
enable_monitoring = true
prometheus_retention = "90d"
# grafana_admin_password should be set via environment variable or secrets

# Access - more restrictive for production
cluster_endpoint_public_access = true
cluster_endpoint_public_access_cidrs = ["203.0.113.0/24"] # Replace with your office IP

# Logging
log_retention_days = 30
```

## 🚀 Template 2: GitOps-Ready EKS with ArgoCD

### `argocd-addon.tf`
```hcl
#------------------------------------------------------------------------------
# ArgoCD Installation
#------------------------------------------------------------------------------
resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
    labels = {
      name = "argocd"
    }
  }
  
  depends_on = [module.eks]
}

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  version    = var.argocd_version

  values = [
    yamlencode({
      # High availability configuration
      controller = {
        replicas = var.environment == "production" ? 2 : 1
      }
      
      server = {
        replicas = var.environment == "production" ? 2 : 1
        
        # Ingress configuration
        service = {
          type = "ClusterIP"
        }
        
        # Configuration
        config = {
          "application.instanceLabelKey" = "argocd.argoproj.io/instance"
          "server.rbac.log.enforce.enable" = "true"
          "policy.default" = "role:readonly"
          "policy.csv" = var.argocd_rbac_policy
        }
        
        # Admin password
        adminPassword = var.argocd_admin_password
        adminPasswordMtime = timestamp()
      }
      
      repoServer = {
        replicas = var.environment == "production" ? 2 : 1
      }
      
      # Redis HA for production
      redis-ha = {
        enabled = var.environment == "production"
      }
      
      redis = {
        enabled = var.environment != "production"
      }
      
      # ApplicationSet controller
      applicationSet = {
        enabled = true
      }
      
      # Notifications
      notifications = {
        enabled = true
        argocdUrl = "https://argocd.${var.domain_name}"
        
        notifiers = {
          "service.slack" = {
            token = var.slack_bot_token
          }
        }
        
        templates = {
          "template.app-deployed" = {
            message = "Application {{.app.metadata.name}} is now running new version of deployments manifests."
            slack = {
              attachments = [
                {
                  title = "{{ .app.metadata.name}}"
                  title_link = "{{.context.argocdUrl}}/applications/{{.app.metadata.name}}"
                  color = "#18be52"
                  fields = [
                    {
                      title = "Sync Status"
                      value = "{{.app.status.sync.status}}"
                      short = true
                    },
                    {
                      title = "Repository"
                      value = "{{.app.spec.source.repoURL}}"
                      short = true
                    }
                  ]
                }
              ]
            }
          }
        }
        
        triggers = {
          "trigger.on-deployed" = [
            {
              when = "app.status.operationState.phase in ['Succeeded'] and app.status.health.status == 'Healthy'"
              send = ["app-deployed"]
            }
          ]
        }
      }
    })
  ]

  depends_on = [
    module.eks.eks_managed_node_groups,
    kubernetes_namespace.argocd
  ]
}

# ArgoCD Ingress
resource "kubernetes_ingress_v1" "argocd" {
  count = var.enable_argocd_ingress ? 1 : 0
  
  metadata {
    name      = "argocd-server-ingress"
    namespace = kubernetes_namespace.argocd.metadata[0].name
    
    annotations = {
      "kubernetes.io/ingress.class"                    = "alb"
      "alb.ingress.kubernetes.io/scheme"              = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"         = "ip"
      "alb.ingress.kubernetes.io/certificate-arn"     = var.ssl_certificate_arn
      "alb.ingress.kubernetes.io/listen-ports"        = "[{\"HTTP\": 80}, {\"HTTPS\": 443}]"
      "alb.ingress.kubernetes.io/ssl-redirect"        = "443"
      "alb.ingress.kubernetes.io/backend-protocol"    = "HTTPS"
      "alb.ingress.kubernetes.io/healthcheck-path"    = "/healthz"
    }
  }

  spec {
    rule {
      host = "argocd.${var.domain_name}"
      
      http {
        path {
          path = "/"
          path_type = "Prefix"
          
          backend {
            service {
              name = "argocd-server"
              port {
                number = 443
              }
            }
          }
        }
      }
    }
  }
  
  depends_on = [helm_release.argocd]
}

# Application of Applications pattern
resource "kubernetes_manifest" "app_of_apps" {
  manifest = yamldecode(templatefile("${path.module}/templates/app-of-apps.yaml", {
    cluster_name = module.eks.cluster_name
    environment  = var.environment
    git_repo_url = var.applications_git_repo
  }))
  
  depends_on = [helm_release.argocd]
}
```

### `templates/app-of-apps.yaml`
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ${cluster_name}-apps
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  
  source:
    repoURL: ${git_repo_url}
    targetRevision: HEAD
    path: environments/${environment}/applications
  
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
      allowEmpty: false
    syncOptions:
    - CreateNamespace=true
    - PrunePropagationPolicy=foreground
    - PruneLast=true
    
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m0s
```

## 📋 Usage Instructions

### 1. **Initialize New Project**
```bash
# Clone or copy the template
mkdir my-eks-project
cd my-eks-project

# Copy template files
cp -r complete-eks-cluster/* .

# Initialize Terraform
terraform init
```

### 2. **Configure Backend**
Create `backend-config.hcl`:
```hcl
bucket         = "my-terraform-state-bucket"
key            = "eks/my-project/terraform.tfstate"
region         = "us-west-2"
dynamodb_table = "terraform-locks"
encrypt        = true
```

Initialize with backend:
```bash
terraform init -backend-config=backend-config.hcl
```

### 3. **Deploy Environment**
```bash
# Development
terraform workspace new dev
terraform plan -var-file="environments/dev.tfvars"
terraform apply -var-file="environments/dev.tfvars"

# Production  
terraform workspace new production
terraform plan -var-file="environments/production.tfvars"
terraform apply -var-file="environments/production.tfvars"
```

### 4. **Configure kubectl**
```bash
aws eks --region us-west-2 update-kubeconfig --name my-project-dev
kubectl get nodes
```

### 5. **Access Services**
```bash
# Get Grafana URL (if monitoring enabled)
kubectl get ingress -n monitoring

# Get ArgoCD URL (if ArgoCD enabled)
kubectl get ingress -n argocd

# Port forward for local access
kubectl port-forward -n monitoring svc/grafana 3000:80
kubectl port-forward -n argocd svc/argocd-server 8080:80
```

---

## 🔗 Navigation

| Previous | Current | Next |
|----------|---------|------|
| [Best Practices](./best-practices.md) | **Template Examples** | [Security Considerations](./security-considerations.md) |

---

*These templates provide production-ready starting points based on patterns from successful open source projects. Customize them according to your specific requirements.*