# Implementation Guide: Terraform + AWS + Kubernetes/EKS

## 🚀 Quick Start

This guide provides step-by-step instructions for implementing production-ready DevOps infrastructure using Terraform, AWS, and Kubernetes/EKS based on patterns from leading open source projects.

## 📋 Prerequisites

### Required Tools
```bash
# Core tools
terraform >= 1.0
aws-cli >= 2.0
kubectl >= 1.28
helm >= 3.0

# Optional but recommended
terragrunt >= 0.45
flux >= 2.0
```

### AWS Prerequisites
```bash
# Configure AWS CLI
aws configure
aws sts get-caller-identity

# Required AWS permissions
- EKS full access
- VPC full access
- IAM role creation
- EC2 instance management
- S3 bucket access
```

### Local Environment Setup
```bash
# Install required tools (macOS)
brew install terraform aws-cli kubectl helm terragrunt

# Install Flux CLI
curl -s https://fluxcd.io/install.sh | sudo bash

# Verify installations
terraform version
aws --version
kubectl version --client
helm version
```

## 🏗️ Infrastructure Setup Patterns

### Pattern 1: Basic EKS with Terraform

#### Step 1: Project Structure
```
terraform-eks-project/
├── environments/
│   ├── dev/
│   ├── staging/
│   └── prod/
├── modules/
│   ├── vpc/
│   ├── eks/
│   └── addons/
├── terraform.tf
└── variables.tf
```

#### Step 2: VPC Module (`modules/vpc/main.tf`)
```hcl
data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = var.vpc_name
  cidr = var.vpc_cidr

  azs             = data.aws_availability_zones.available.names
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets

  enable_nat_gateway   = true
  enable_vpn_gateway   = false
  enable_dns_hostnames = true
  enable_dns_support   = true

  # EKS-specific tags
  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }

  tags = merge(var.common_tags, {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  })
}
```

#### Step 3: EKS Module (`modules/eks/main.tf`)
```hcl
module "eks" {
  source = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id                         = var.vpc_id
  subnet_ids                     = var.private_subnet_ids
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true
  cluster_endpoint_public_access_cidrs = var.allowed_cidr_blocks

  # Cluster logging
  cluster_enabled_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler"
  ]

  # EKS Managed Node Group(s)
  eks_managed_node_group_defaults = {
    instance_types = ["t3.medium"]
    
    # Disk configuration
    disk_size = 50
    disk_type = "gp3"
    disk_encrypted = true
    
    # Security
    enable_bootstrap_user_data = true
  }

  eks_managed_node_groups = {
    main = {
      name = "main-node-group"
      
      min_size     = 1
      max_size     = 10
      desired_size = 3

      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"

      labels = {
        Environment = var.environment
        NodeGroup   = "main"
      }

      taints = []

      update_config = {
        max_unavailable_percentage = 33
      }

      tags = var.common_tags
    }
  }

  # aws-auth configmap
  manage_aws_auth_configmap = true
  aws_auth_roles = var.aws_auth_roles
  aws_auth_users = var.aws_auth_users

  tags = var.common_tags
}
```

#### Step 4: Environment Configuration (`environments/prod/main.tf`)
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
  }

  backend "s3" {
    bucket  = "your-terraform-state-bucket"
    key     = "prod/terraform.tfstate"
    region  = "us-west-2"
    encrypt = true
    
    dynamodb_table = "terraform-state-lock"
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Environment   = "production"
      Project       = "eks-cluster"
      ManagedBy     = "terraform"
      CostCenter    = "engineering"
    }
  }
}

# Configure Kubernetes provider
data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_id
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

# Local values
locals {
  cluster_name = "prod-eks-cluster"
  common_tags = {
    Environment = "production"
    Project     = "eks-infrastructure"
    ManagedBy   = "terraform"
  }
}

# VPC Module
module "vpc" {
  source = "../../modules/vpc"

  vpc_name        = "${local.cluster_name}-vpc"
  vpc_cidr        = "10.0.0.0/16"
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  cluster_name    = local.cluster_name
  common_tags     = local.common_tags
}

# EKS Module
module "eks" {
  source = "../../modules/eks"

  cluster_name      = local.cluster_name
  cluster_version   = "1.28"
  vpc_id           = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnets
  environment      = "production"
  allowed_cidr_blocks = ["10.0.0.0/16"]
  
  aws_auth_roles = [
    {
      rolearn  = "arn:aws:iam::123456789012:role/DevOpsRole"
      username = "devops"
      groups   = ["system:masters"]
    }
  ]
  
  aws_auth_users = [
    {
      userarn  = "arn:aws:iam::123456789012:user/admin"
      username = "admin"
      groups   = ["system:masters"]
    }
  ]

  common_tags = local.common_tags
  
  depends_on = [module.vpc]
}
```

### Pattern 2: EKS with Add-ons and GitOps

#### Step 1: Add-ons Module (`modules/addons/main.tf`)
```hcl
# AWS Load Balancer Controller
resource "kubernetes_service_account" "aws_load_balancer_controller" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    labels = {
      "app.kubernetes.io/component" = "controller"
      "app.kubernetes.io/name"      = "aws-load-balancer-controller"
    }
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.aws_load_balancer_controller.arn
    }
  }
}

resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.6.2"

  set {
    name  = "clusterName"
    value = var.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  set {
    name  = "serviceAccount.name"
    value = kubernetes_service_account.aws_load_balancer_controller.metadata[0].name
  }

  depends_on = [kubernetes_service_account.aws_load_balancer_controller]
}

# Cluster Autoscaler
resource "helm_release" "cluster_autoscaler" {
  name       = "cluster-autoscaler"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  namespace  = "kube-system"
  version    = "9.21.0"

  set {
    name  = "cloudProvider"
    value = "aws"
  }

  set {
    name  = "awsRegion"
    value = var.aws_region
  }

  set {
    name  = "autoDiscovery.clusterName"
    value = var.cluster_name
  }

  set {
    name  = "autoDiscovery.enabled"
    value = "true"
  }

  set {
    name  = "rbac.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.cluster_autoscaler.arn
  }
}

# Flux GitOps
resource "kubernetes_namespace" "flux_system" {
  metadata {
    name = "flux-system"
  }
}

resource "helm_release" "flux" {
  name       = "flux2"
  repository = "https://fluxcd-community.github.io/helm-charts"
  chart      = "flux2"
  namespace  = kubernetes_namespace.flux_system.metadata[0].name
  version    = "2.10.2"

  values = [
    yamlencode({
      installCRDs = true
      
      sourceController = {
        create = true
      }
      
      kustomizeController = {
        create = true
      }
      
      helmController = {
        create = true
      }
      
      notificationController = {
        create = true
      }
      
      imageReflectionController = {
        create = true
      }
      
      imageAutomationController = {
        create = true
      }
    })
  ]
}
```

#### Step 2: Monitoring Stack (`modules/monitoring/main.tf`)
```hcl
# Prometheus Operator
resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
  }
}

resource "helm_release" "prometheus_operator" {
  name       = "prometheus-operator"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  version    = "51.2.0"

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
        }
      }
      
      grafana = {
        adminPassword = var.grafana_admin_password
        
        persistence = {
          enabled = true
          size    = "10Gi"
        }
        
        ingress = {
          enabled = true
          annotations = {
            "kubernetes.io/ingress.class"                = "alb"
            "alb.ingress.kubernetes.io/scheme"           = "internet-facing"
            "alb.ingress.kubernetes.io/target-type"      = "ip"
            "alb.ingress.kubernetes.io/certificate-arn"  = var.ssl_certificate_arn
          }
          hosts = [var.grafana_hostname]
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
}
```

## 🚀 Deployment Workflow

### Step 1: Infrastructure Deployment
```bash
# Navigate to environment directory
cd environments/prod

# Initialize Terraform
terraform init

# Plan deployment
terraform plan -var-file="terraform.tfvars"

# Apply infrastructure
terraform apply -var-file="terraform.tfvars"

# Configure kubectl
aws eks update-kubeconfig --region us-west-2 --name prod-eks-cluster
```

### Step 2: Verify Cluster Setup
```bash
# Check cluster status
kubectl cluster-info

# Verify nodes
kubectl get nodes

# Check system pods
kubectl get pods -n kube-system

# Verify add-ons
kubectl get pods -n kube-system | grep -E "aws-load-balancer|cluster-autoscaler"
```

### Step 3: GitOps Bootstrap
```bash
# Bootstrap Flux
flux bootstrap github \
  --owner=$GITHUB_USER \
  --repository=fleet-infra \
  --branch=main \
  --path=./clusters/production \
  --personal

# Verify Flux installation
flux get sources git
flux get kustomizations
```

### Step 4: Application Deployment
```yaml
# GitRepository source (saved to Git repo)
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: GitRepository
metadata:
  name: webapp
  namespace: flux-system
spec:
  interval: 30s
  ref:
    branch: main
  url: https://github.com/your-org/webapp
---
# Kustomization for deployment
apiVersion: kustomize.toolkit.fluxcd.io/v1beta2
kind: Kustomization
metadata:
  name: webapp
  namespace: flux-system
spec:
  interval: 5m
  path: "./k8s/overlays/production"
  prune: true
  sourceRef:
    kind: GitRepository
    name: webapp
  targetNamespace: webapp
```

## 🔧 Advanced Patterns

### Multi-Environment Management with Terragrunt
```hcl
# terragrunt.hcl (root)
remote_state {
  backend = "s3"
  config = {
    bucket         = "your-terraform-state-bucket"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = "us-west-2"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

generate "provider" {
  path = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents = <<EOF
provider "aws" {
  region = var.aws_region
}
EOF
}

inputs = {
  aws_region = "us-west-2"
}
```

```hcl
# environments/prod/terragrunt.hcl
include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../modules//eks"
}

inputs = {
  cluster_name    = "prod-eks-cluster"
  cluster_version = "1.28"
  environment     = "production"
  instance_types  = ["m5.large"]
  min_size        = 3
  max_size        = 20
  desired_size    = 5
}
```

### Blue-Green Deployment Pattern
```yaml
# Application with Flagger for progressive delivery
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: webapp
  namespace: webapp
spec:
  provider: kubernetes
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: webapp
  service:
    port: 80
    targetPort: 8080
  analysis:
    interval: 30s
    threshold: 5
    maxWeight: 50
    stepWeight: 10
    metrics:
    - name: request-success-rate
      thresholdRange:
        min: 99
      interval: 1m
    webhooks:
    - name: load-test
      url: http://flagger-loadtester.test/
      timeout: 5s
      metadata:
        cmd: "hey -z 1m -q 10 -c 2 http://webapp.webapp.svc.cluster.local/"
```

## 🔒 Security Hardening

### Pod Security Standards
```yaml
# Pod Security Standards enforcement
apiVersion: v1
kind: Namespace
metadata:
  name: webapp
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

### Network Policies
```yaml
# Network policy for webapp
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: webapp-netpol
  namespace: webapp
spec:
  podSelector:
    matchLabels:
      app: webapp
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
    ports:
    - protocol: TCP
      port: 8080
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: database
    ports:
    - protocol: TCP
      port: 5432
```

## 🔗 Next Steps

1. **Review Best Practices**: See [Best Practices Guide](./best-practices.md)
2. **Explore Templates**: Use [Template Examples](./template-examples.md)
3. **Security Hardening**: Follow [Security Considerations](./security-considerations.md)
4. **Troubleshooting**: Reference [Troubleshooting Guide](./troubleshooting-guide.md)

## 🔗 Navigation

← [Back to Project Examples](./project-examples-analysis.md) | [Next: Best Practices →](./best-practices.md)