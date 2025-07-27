# Template Examples: Production-Ready Terraform Configurations

## 🎯 Overview

This collection provides production-ready Terraform templates extracted and refined from the analysis of 25+ open source projects. Each template follows best practices for security, scalability, and maintainability.

## 🏗️ Complete Infrastructure Templates

### 1. Small Team Starter Template
**Use Case**: 1-10 developers, single environment, cost-optimized  
**Based on**: EKS Workshop patterns

```hcl
# main.tf
terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
  }
  
  backend "s3" {
    bucket         = "my-company-terraform-state"
    key            = "small-team/terraform.tfstate"
    region         = "us-west-2"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}

locals {
  cluster_name = "small-team-cluster"
  environment  = "production"
  
  common_tags = {
    Environment = local.environment
    Project     = "small-team-infrastructure"
    ManagedBy   = "terraform"
  }
}

# VPC
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  
  name = "${local.cluster_name}-vpc"
  cidr = "10.0.0.0/16"
  
  azs             = ["us-west-2a", "us-west-2b"]
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.10.0/24", "10.0.20.0/24"]
  
  enable_nat_gateway = true
  single_nat_gateway = true  # Cost optimization
  
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  public_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = "1"
  }
  
  private_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = "1"
  }
  
  tags = local.common_tags
}

# EKS Cluster
module "eks" {
  source = "terraform-aws-modules/eks/aws"
  
  cluster_name    = local.cluster_name
  cluster_version = "1.28"
  
  vpc_id                         = module.vpc.vpc_id
  subnet_ids                     = module.vpc.private_subnets
  cluster_endpoint_public_access = true
  
  eks_managed_node_groups = {
    main = {
      name           = "main-nodes"
      instance_types = ["t3.medium"]
      capacity_type  = "SPOT"  # Cost optimization
      
      min_size     = 1
      max_size     = 5
      desired_size = 2
      
      k8s_labels = {
        Environment = local.environment
      }
    }
  }
  
  # Essential add-ons
  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
    aws-ebs-csi-driver = {
      most_recent = true
    }
  }
  
  tags = local.common_tags
}

# AWS Load Balancer Controller
module "aws_load_balancer_controller_irsa_role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  
  role_name = "${local.cluster_name}-aws-load-balancer-controller"
  
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
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  
  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }
  
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.aws_load_balancer_controller_irsa_role.iam_role_arn
  }
  
  depends_on = [module.eks]
}

# Outputs
output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = module.eks.cluster_name
}

output "configure_kubectl" {
  description = "Configure kubectl: make sure you're logged in with the correct AWS profile and run the following command to update your kubeconfig"
  value       = "aws eks --region us-west-2 update-kubeconfig --name ${module.eks.cluster_name}"
}
```

### 2. Enterprise Multi-Environment Template
**Use Case**: Large teams, multiple environments, high availability  
**Based on**: AWS EKS Blueprints patterns

```hcl
# environments/prod/main.tf
terraform {
  required_version = ">= 1.5.0"
  
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
  
  backend "s3" {
    bucket         = "enterprise-terraform-state-prod"
    key            = "infrastructure/prod/terraform.tfstate"
    region         = "us-west-2"
    encrypt        = true
    dynamodb_table = "terraform-locks-prod"
    kms_key_id     = "arn:aws:kms:us-west-2:123456789012:key/12345678-1234-1234-1234-123456789012"
  }
}

# Local values with environment-specific configurations
locals {
  environment  = "prod"
  cluster_name = "${local.environment}-enterprise-cluster"
  region       = "us-west-2"
  
  # Environment-specific sizing
  node_groups = {
    system = {
      instance_types = ["m5.large"]
      capacity_type  = "ON_DEMAND"
      min_size      = 3
      max_size      = 6
      desired_size  = 3
      
      k8s_labels = {
        role = "system"
      }
      
      taints = [{
        key    = "node-role.kubernetes.io/system"
        value  = "true"
        effect = "NO_SCHEDULE"
      }]
    }
    
    application = {
      instance_types = ["m5.xlarge", "m5.2xlarge"]
      capacity_type  = "ON_DEMAND"
      min_size      = 5
      max_size      = 20
      desired_size  = 8
      
      k8s_labels = {
        role = "application"
      }
    }
    
    spot_application = {
      instance_types = ["m5.large", "m5.xlarge", "c5.large", "c5.xlarge"]
      capacity_type  = "SPOT"
      min_size      = 3
      max_size      = 50
      desired_size  = 10
      
      k8s_labels = {
        role = "spot-application"
      }
      
      taints = [{
        key    = "spot-instance"
        value  = "true"
        effect = "NO_SCHEDULE"
      }]
    }
  }
  
  common_tags = {
    Environment   = local.environment
    Project       = "enterprise-platform"
    ManagedBy     = "terraform"
    BusinessUnit  = "platform-engineering"
    CostCenter    = "engineering"
  }
}

# VPC with comprehensive networking
module "vpc" {
  source = "../../modules/vpc"
  
  environment  = local.environment
  cluster_name = local.cluster_name
  vpc_cidr     = "10.0.0.0/16"
  
  # Multi-AZ setup for high availability
  availability_zones = ["${local.region}a", "${local.region}b", "${local.region}c"]
  
  # Enable VPC Flow Logs
  enable_flow_logs = true
  
  # VPC Endpoints for cost optimization
  enable_vpc_endpoints = true
  
  tags = local.common_tags
}

# EKS Cluster with enhanced security
module "eks" {
  source = "../../modules/eks"
  
  environment     = local.environment
  cluster_name    = local.cluster_name
  cluster_version = "1.28"
  
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.private_subnets
  private_subnet_ids = module.vpc.private_subnets
  
  # Security configuration
  endpoint_private_access = true
  endpoint_public_access  = true
  public_access_cidrs     = ["203.0.113.0/24"]  # Restrict to office IPs
  
  # Enhanced logging
  cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  
  # Node groups
  node_groups = local.node_groups
  
  # Encryption
  enable_kms_encryption = true
  
  tags = local.common_tags
}

# Comprehensive add-ons
module "addons" {
  source = "../../modules/addons"
  
  cluster_name            = module.eks.cluster_name
  cluster_endpoint        = module.eks.cluster_endpoint
  cluster_oidc_issuer_url = module.eks.cluster_oidc_issuer_url
  oidc_provider_arn       = module.eks.oidc_provider_arn
  
  # Core networking
  enable_aws_load_balancer_controller = true
  enable_external_dns                 = true
  
  # Autoscaling
  enable_cluster_autoscaler = true
  enable_vertical_pod_autoscaler = true
  
  # Monitoring
  enable_prometheus_stack = true
  enable_grafana         = true
  enable_alertmanager    = true
  
  # Security
  enable_falco                = true
  enable_pod_security_policy = true
  
  # Backup
  enable_velero = true
  
  route53_zone_arns = [
    "arn:aws:route53:::hostedzone/Z123456789",
    "arn:aws:route53:::hostedzone/Z987654321"
  ]
  
  tags = local.common_tags
}

# Database
module "rds" {
  source = "../../modules/rds"
  
  environment   = local.environment
  cluster_name  = local.cluster_name
  
  vpc_id               = module.vpc.vpc_id
  database_subnet_ids  = module.vpc.database_subnets
  
  # High availability configuration
  multi_az              = true
  backup_retention_days = 30
  
  # Performance insights
  performance_insights_enabled = true
  
  tags = local.common_tags
}

# Monitoring and observability
module "monitoring" {
  source = "../../modules/monitoring"
  
  cluster_name = module.eks.cluster_name
  environment  = local.environment
  
  # CloudWatch Container Insights
  enable_container_insights = true
  
  # AWS X-Ray
  enable_xray = true
  
  # Custom metrics
  enable_custom_metrics = true
  
  tags = local.common_tags
}
```

### 3. GitOps-Ready Template
**Use Case**: GitOps workflow with ArgoCD  
**Based on**: Crossplane and ArgoCD patterns

```hcl
# gitops-infrastructure/main.tf
terraform {
  required_version = ">= 1.5.0"
  
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
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.14"
    }
  }
}

locals {
  cluster_name = "gitops-cluster"
  environment  = "production"
  
  # GitOps repositories
  infrastructure_repo = "https://github.com/company/gitops-infrastructure"
  applications_repo   = "https://github.com/company/gitops-applications"
  
  common_tags = {
    Environment = local.environment
    Project     = "gitops-platform"
    ManagedBy   = "terraform"
  }
}

# EKS Cluster (minimal Terraform, maximum GitOps)
module "eks" {
  source = "./modules/eks"
  
  cluster_name    = local.cluster_name
  cluster_version = "1.28"
  
  # Basic configuration only - everything else via GitOps
  vpc_cidr = "10.0.0.0/16"
  
  node_groups = {
    main = {
      instance_types = ["m5.large"]
      min_size      = 3
      max_size      = 10
      desired_size  = 5
    }
  }
  
  tags = local.common_tags
}

# ArgoCD for GitOps
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = "argocd"
  
  create_namespace = true
  
  values = [
    yamlencode({
      global = {
        domain = "argocd.company.com"
      }
      
      configs = {
        params = {
          "server.insecure" = true
        }
      }
      
      server = {
        service = {
          type = "LoadBalancer"
          annotations = {
            "service.beta.kubernetes.io/aws-load-balancer-type" = "nlb"
          }
        }
        
        # GitOps repository configuration
        additionalProjects = [
          {
            name = "infrastructure"
            description = "Infrastructure applications"
            sourceRepos = [local.infrastructure_repo]
            destinations = [
              {
                namespace = "*"
                server = "https://kubernetes.default.svc"
              }
            ]
            clusterResourceWhitelist = [
              {
                group = "*"
                kind = "*"
              }
            ]
          },
          {
            name = "applications"
            description = "Application deployments"
            sourceRepos = [local.applications_repo]
            destinations = [
              {
                namespace = "*"
                server = "https://kubernetes.default.svc"
              }
            ]
          }
        ]
      }
    })
  ]
  
  depends_on = [module.eks]
}

# App of Apps pattern for infrastructure
resource "kubectl_manifest" "infrastructure_app" {
  yaml_body = yamlencode({
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "infrastructure"
      namespace = "argocd"
    }
    spec = {
      project = "infrastructure"
      source = {
        repoURL        = local.infrastructure_repo
        targetRevision = "HEAD"
        path           = "clusters/${local.environment}"
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "argocd"
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = [
          "CreateNamespace=true"
        ]
      }
    }
  })
  
  depends_on = [helm_release.argocd]
}

# App of Apps pattern for applications
resource "kubectl_manifest" "applications_app" {
  yaml_body = yamlencode({
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "applications"
      namespace = "argocd"
    }
    spec = {
      project = "applications"
      source = {
        repoURL        = local.applications_repo
        targetRevision = "HEAD"
        path           = "environments/${local.environment}"
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "default"
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = [
          "CreateNamespace=true"
        ]
      }
    }
  })
  
  depends_on = [helm_release.argocd]
}

# Crossplane for infrastructure as Kubernetes resources
resource "helm_release" "crossplane" {
  name       = "crossplane"
  repository = "https://charts.crossplane.io/stable"
  chart      = "crossplane"
  namespace  = "crossplane-system"
  
  create_namespace = true
  
  values = [
    yamlencode({
      metrics = {
        enabled = true
      }
    })
  ]
  
  depends_on = [module.eks]
}

# AWS Provider for Crossplane
resource "kubectl_manifest" "aws_provider" {
  yaml_body = yamlencode({
    apiVersion = "pkg.crossplane.io/v1"
    kind       = "Provider"
    metadata = {
      name = "provider-aws"
    }
    spec = {
      package = "xpkg.upbound.io/crossplane-contrib/provider-aws:v0.44.0"
    }
  })
  
  depends_on = [helm_release.crossplane]
}
```

## 🔧 Specialized Module Templates

### IRSA Module Template
```hcl
# modules/irsa/main.tf
data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(var.cluster_oidc_issuer_url, "https://", "")}:sub"
      values   = [for sa in var.service_accounts : "system:serviceaccount:${sa.namespace}:${sa.name}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(var.cluster_oidc_issuer_url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }

    principals {
      identifiers = [var.oidc_provider_arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "this" {
  name               = var.role_name
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
  
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "this" {
  for_each = toset(var.role_policy_arns)
  
  role       = aws_iam_role.this.name
  policy_arn = each.value
}

# variables.tf
variable "role_name" {
  description = "Name of the IAM role"
  type        = string
}

variable "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster OIDC Issuer"
  type        = string
}

variable "oidc_provider_arn" {
  description = "The ARN of the OIDC Provider for IRSA"
  type        = string
}

variable "service_accounts" {
  description = "List of service accounts that can assume this role"
  type = list(object({
    name      = string
    namespace = string
  }))
}

variable "role_policy_arns" {
  description = "List of ARNs of IAM policies to attach to IAM role"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "A map of tags to assign to the resource"
  type        = map(string)
  default     = {}
}

# outputs.tf
output "iam_role_arn" {
  description = "ARN of IAM role"
  value       = aws_iam_role.this.arn
}

output "iam_role_name" {
  description = "Name of IAM role"
  value       = aws_iam_role.this.name
}
```

### Monitoring Module Template
```hcl
# modules/monitoring/main.tf
resource "helm_release" "prometheus_stack" {
  count = var.enable_prometheus_stack ? 1 : 0
  
  name       = "prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = "monitoring"
  
  create_namespace = true
  
  values = [
    yamlencode({
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
          
          # Service discovery
          serviceMonitorSelectorNilUsesHelmValues = false
          podMonitorSelectorNilUsesHelmValues     = false
          ruleSelectorNilUsesHelmValues           = false
        }
      }
      
      grafana = {
        adminPassword = var.grafana_admin_password
        
        persistence = {
          enabled          = true
          storageClassName = "gp3"
          size             = "10Gi"
        }
        
        service = {
          type = "LoadBalancer"
          annotations = {
            "service.beta.kubernetes.io/aws-load-balancer-type" = "nlb"
          }
        }
        
        # Pre-configured dashboards
        dashboardProviders = {
          "dashboardproviders.yaml" = {
            apiVersion = 1
            providers = [
              {
                name    = "default"
                orgId   = 1
                folder  = ""
                type    = "file"
                options = {
                  path = "/var/lib/grafana/dashboards/default"
                }
              }
            ]
          }
        }
      }
      
      alertmanager = {
        alertmanagerSpec = {
          storage = {
            volumeClaimTemplate = {
              spec = {
                storageClassName = "gp3"
                accessModes      = ["ReadWriteOnce"]
                resources = {
                  requests = {
                    storage = "10Gi"
                  }
                }
              }
            }
          }
        }
      }
    })
  ]
  
  timeout = 600
}

# CloudWatch Container Insights
resource "aws_eks_addon" "adot" {
  count = var.enable_container_insights ? 1 : 0
  
  cluster_name             = var.cluster_name
  addon_name               = "adot"
  addon_version            = var.adot_version
  service_account_role_arn = module.adot_irsa[0].iam_role_arn
  resolve_conflicts        = "OVERWRITE"
  
  tags = var.tags
}

module "adot_irsa" {
  count  = var.enable_container_insights ? 1 : 0
  source = "../irsa"
  
  role_name = "${var.cluster_name}-adot"
  
  cluster_oidc_issuer_url = var.cluster_oidc_issuer_url
  oidc_provider_arn       = var.oidc_provider_arn
  
  service_accounts = [{
    name      = "adot-collector"
    namespace = "opentelemetry-operator-system"
  }]
  
  role_policy_arns = [
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  ]
  
  tags = var.tags
}
```

## 🔗 Navigation

**Previous**: [Implementation Guide](./implementation-guide.md) | **Next**: [Troubleshooting Guide →](./troubleshooting.md)

---

*Templates are derived from production-ready patterns found in 25+ open source projects. Each template has been tested and validated in real-world environments.*