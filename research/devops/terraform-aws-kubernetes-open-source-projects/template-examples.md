# Template Examples: Working Code and Configurations

Ready-to-use templates and examples extracted from 60+ production-ready open source projects, organized by complexity and use case.

## 📂 Template Index

| Template | Complexity | Use Case | Based On |
|----------|------------|----------|----------|
| [Basic EKS Cluster](#-basic-eks-cluster) | Beginner | Learning, Development | [terraform-aws-eks](https://github.com/terraform-aws-modules/terraform-aws-eks) |
| [Production EKS](#-production-eks-cluster) | Intermediate | Production Workloads | [eks-blueprints](https://github.com/aws-ia/terraform-aws-eks-blueprints) |
| [GitOps Setup](#-gitops-configuration) | Advanced | Automated Deployments | [tofu-controller](https://github.com/flux-iac/tofu-controller) |
| [Multi-Environment](#-multi-environment-setup) | Advanced | Enterprise Scale | [terraform-kubestack](https://github.com/kbst/terraform-kubestack) |
| [Monitoring Stack](#-monitoring-configuration) | Intermediate | Observability | [terraform-kubernetes-monitoring-prometheus](https://github.com/mateothegreat/terraform-kubernetes-monitoring-prometheus) |
| [Microservices App](#-microservices-application) | Intermediate | Application Deployment | [e-commerce-microservices-sample](https://github.com/venkataravuri/e-commerce-microservices-sample) |

---

## 🌱 Basic EKS Cluster

*Perfect for learning and development environments*

### Directory Structure
```
basic-eks/
├── main.tf
├── variables.tf
├── outputs.tf
├── versions.tf
└── terraform.tfvars.example
```

### versions.tf
```hcl
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.20"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.10"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "terraform"
    }
  }
}

# Kubernetes provider will be configured after EKS cluster creation
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

### variables.tf
```hcl
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "basic-eks"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "cluster_version" {
  description = "Kubernetes cluster version"
  type        = string
  default     = "1.27"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "enable_nat_gateway" {
  description = "Should be true to provision NAT Gateways for each of your private networks"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Should be true to provision a single shared NAT Gateway across all of your private networks"
  type        = bool
  default     = true
}
```

### main.tf
```hcl
# Data sources
data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

data "aws_caller_identity" "current" {}

locals {
  cluster_name = "${var.project_name}-${var.environment}"
  
  azs = slice(data.aws_availability_zones.available.names, 0, 3)

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# VPC
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${local.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 8, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 8, k + 4)]

  enable_nat_gateway   = var.enable_nat_gateway
  single_nat_gateway   = var.single_nat_gateway
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Kubernetes specific tags
  public_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = "1"
  }

  tags = local.tags
}

# EKS Cluster
module "eks" {
  source = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = local.cluster_name
  cluster_version = var.cluster_version

  vpc_id                         = module.vpc.vpc_id
  subnet_ids                     = module.vpc.private_subnets
  cluster_endpoint_public_access = true

  # EKS Managed Node Groups
  eks_managed_node_groups = {
    main = {
      name = "main"

      instance_types = ["t3.medium"]

      min_size     = 1
      max_size     = 3
      desired_size = 2

      # Disk configuration
      disk_size = 50
      disk_type = "gp3"

      labels = {
        Environment = var.environment
        NodeGroup   = "main"
      }

      tags = local.tags
    }
  }

  # Cluster access entry
  enable_cluster_creator_admin_permissions = true

  # Add-ons
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

  tags = local.tags
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

  tags = local.tags
}

resource "kubernetes_service_account" "aws_load_balancer_controller" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    labels = {
      "app.kubernetes.io/component" = "controller"
      "app.kubernetes.io/name"      = "aws-load-balancer-controller"
    }
    annotations = {
      "eks.amazonaws.com/role-arn" = module.aws_load_balancer_controller_irsa_role.iam_role_arn
    }
  }

  depends_on = [module.eks]
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
    name  = "serviceAccount.create"
    value = "false"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  depends_on = [
    kubernetes_service_account.aws_load_balancer_controller,
    module.eks
  ]
}
```

### outputs.tf
```hcl
output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ids attached to the cluster control plane"
  value       = module.eks.cluster_security_group_id
}

output "cluster_name" {
  description = "The name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_arn" {
  description = "The Amazon Resource Name (ARN) of the cluster"
  value       = module.eks.cluster_arn
}

output "oidc_provider_arn" {
  description = "The ARN of the OIDC Provider"
  value       = module.eks.oidc_provider_arn
}

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

output "configure_kubectl" {
  description = "Configure kubectl: make sure you're logged in with the correct AWS profile and run the following command to update your kubeconfig"
  value       = "aws eks --region ${var.aws_region} update-kubeconfig --name ${module.eks.cluster_name}"
}
```

### terraform.tfvars.example
```hcl
# Copy this file to terraform.tfvars and customize

aws_region  = "us-west-2"
project_name = "my-project"
environment = "dev"

# Cluster configuration
cluster_version = "1.27"

# VPC configuration
vpc_cidr = "10.0.0.0/16"
enable_nat_gateway = true
single_nat_gateway = true  # Set to false for production
```

---

## 🏗️ Production EKS Cluster

*Enterprise-ready configuration with security and monitoring*

### main.tf (Production)
```hcl
# Production EKS cluster with enhanced security and monitoring
locals {
  cluster_name = "${var.project_name}-${var.environment}"
  
  node_groups = {
    # On-demand node group for critical workloads
    critical = {
      name           = "critical"
      instance_types = ["m5.large"]
      capacity_type  = "ON_DEMAND"
      
      min_size     = 2
      max_size     = 10
      desired_size = 3
      
      labels = {
        role = "critical"
        "node.kubernetes.io/lifecycle" = "on-demand"
      }
      
      taints = []
    }
    
    # Spot instance node group for flexible workloads
    flexible = {
      name           = "flexible"
      instance_types = ["m5.large", "m5.xlarge", "m4.large"]
      capacity_type  = "SPOT"
      
      min_size     = 0
      max_size     = 20
      desired_size = 3
      
      labels = {
        role = "flexible"
        "node.kubernetes.io/lifecycle" = "spot"
      }
      
      taints = [
        {
          key    = "spot"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      ]
    }
  }
}

# KMS key for EKS encryption
resource "aws_kms_key" "eks" {
  description = "EKS cluster encryption key"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      }
    ]
  })

  tags = local.tags
}

resource "aws_kms_alias" "eks" {
  name          = "alias/${local.cluster_name}-eks"
  target_key_id = aws_kms_key.eks.key_id
}

# CloudWatch Log Group for EKS
resource "aws_cloudwatch_log_group" "eks_cluster" {
  name              = "/aws/eks/${local.cluster_name}/cluster"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.eks.arn

  tags = local.tags
}

# Production EKS cluster
module "eks" {
  source = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = local.cluster_name
  cluster_version = var.cluster_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Security configuration
  cluster_endpoint_public_access  = var.cluster_endpoint_public_access
  cluster_endpoint_private_access = true
  
  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs

  # Enable logging
  cluster_enabled_log_types = [
    "api",
    "audit", 
    "authenticator",
    "controllerManager",
    "scheduler"
  ]

  # Encryption at rest
  cluster_encryption_config = [
    {
      provider_key_arn = aws_kms_key.eks.arn
      resources        = ["secrets"]
    }
  ]

  # Node groups
  eks_managed_node_groups = {
    for name, config in local.node_groups : name => {
      name           = config.name
      instance_types = config.instance_types
      capacity_type  = config.capacity_type
      
      min_size     = config.min_size
      max_size     = config.max_size
      desired_size = config.desired_size
      
      # Enhanced disk configuration
      disk_size = 100
      disk_type = "gp3"
      disk_iops = 3000
      disk_throughput = 125
      
      # Security and performance
      ami_type = "AL2_x86_64"
      
      labels = merge(config.labels, {
        Environment = var.environment
        NodeGroup   = config.name
      })
      
      taints = config.taints
      
      # User data for additional setup
      pre_bootstrap_user_data = <<-EOT
        #!/bin/bash
        /etc/eks/bootstrap.sh ${local.cluster_name}
        
        # Install SSM agent
        yum install -y amazon-ssm-agent
        systemctl enable amazon-ssm-agent
        systemctl start amazon-ssm-agent
        
        # Configure CloudWatch agent
        yum install -y amazon-cloudwatch-agent
      EOT
      
      # Instance metadata options
      metadata_options = {
        http_endpoint               = "enabled"
        http_tokens                 = "required"
        http_put_response_hop_limit = 2
        instance_metadata_tags      = "enabled"
      }
      
      tags = local.tags
    }
  }

  # Cluster access entry
  enable_cluster_creator_admin_permissions = true

  # Enhanced add-ons
  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
      configuration_values = jsonencode({
        env = {
          ENABLE_POD_ENI = "true"
        }
      })
    }
    aws-ebs-csi-driver = {
      most_recent = true
    }
    aws-efs-csi-driver = {
      most_recent = true
    }
    adot = {
      most_recent = true
    }
  }

  tags = local.tags

  depends_on = [aws_cloudwatch_log_group.eks_cluster]
}
```

---

## 🔄 GitOps Configuration

*Complete GitOps setup with FluxCD and Terraform automation*

### flux-system/
```yaml
# flux-system/gotk-components.yaml
# Generated by: flux install --export > flux-system/gotk-components.yaml

# flux-system/gotk-sync.yaml
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: GitRepository
metadata:
  name: flux-system
  namespace: flux-system
spec:
  interval: 1m0s
  ref:
    branch: main
  secretRef:
    name: flux-system
  url: ssh://git@github.com/your-org/k8s-gitops
---
apiVersion: kustomize.toolkit.fluxcd.io/v1beta2
kind: Kustomization
metadata:
  name: flux-system
  namespace: flux-system
spec:
  interval: 10m0s
  path: ./clusters/production
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-system
```

### clusters/production/
```yaml
# clusters/production/infrastructure.yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1beta2
kind: Kustomization
metadata:
  name: infrastructure
  namespace: flux-system
spec:
  interval: 10m
  sourceRef:
    kind: GitRepository
    name: flux-system
  path: "./infrastructure"
  prune: true
  wait: true
---
apiVersion: kustomize.toolkit.fluxcd.io/v1beta2
kind: Kustomization
metadata:
  name: apps
  namespace: flux-system
spec:
  dependsOn:
  - name: infrastructure
  interval: 10m
  sourceRef:
    kind: GitRepository
    name: flux-system
  path: "./apps/production"
  prune: true
  wait: true
```

### infrastructure/terraform/
```yaml
# infrastructure/terraform/source.yaml
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: GitRepository
metadata:
  name: infrastructure-source
  namespace: flux-system
spec:
  interval: 5m
  url: https://github.com/your-org/infrastructure
  ref:
    branch: main
  secretRef:
    name: git-credentials
---
# infrastructure/terraform/eks-cluster.yaml
apiVersion: infra.contrib.fluxcd.io/v1alpha1
kind: Terraform
metadata:
  name: eks-cluster
  namespace: flux-system
spec:
  interval: 10m
  path: "./terraform/eks"
  sourceRef:
    kind: GitRepository
    name: infrastructure-source
  vars:
    - name: cluster_name
      value: "production-cluster"
    - name: environment
      value: "production"
    - name: cluster_version
      value: "1.27"
  writeOutputsToSecret:
    name: eks-outputs
  runnerPodTemplate:
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 65534
        fsGroup: 65534
      containers:
      - name: tf-runner
        resources:
          limits:
            cpu: 500m
            memory: 512Mi
          requests:
            cpu: 100m
            memory: 128Mi
```

---

## 🏢 Multi-Environment Setup

*Scalable multi-environment configuration*

### environments/
```
environments/
├── dev/
│   ├── main.tf
│   ├── terraform.tfvars
│   └── backend.tf
├── staging/
│   ├── main.tf
│   ├── terraform.tfvars
│   └── backend.tf
└── prod/
    ├── main.tf
    ├── terraform.tfvars
    └── backend.tf
```

### environments/dev/main.tf
```hcl
terraform {
  backend "s3" {
    bucket         = "my-terraform-state-dev"
    key            = "eks/terraform.tfstate"
    region         = "us-west-2"
    encrypt        = true
    dynamodb_table = "terraform-locks-dev"
  }
}

module "infrastructure" {
  source = "../../modules/infrastructure"
  
  # Environment-specific configuration
  environment = "dev"
  
  # Cluster configuration
  cluster_version = "1.27"
  
  # Node configuration
  node_groups = {
    main = {
      instance_types = ["t3.medium"]
      capacity_type  = "SPOT"
      min_size       = 1
      max_size       = 3
      desired_size   = 2
    }
  }
  
  # Cost optimization for dev
  enable_nat_gateway = true
  single_nat_gateway = true
  
  # Monitoring (basic for dev)
  monitoring_enabled = false
  logging_enabled    = true
  
  # Security (relaxed for dev)
  cluster_endpoint_public_access = true
  
  # Backup (disabled for dev)
  backup_enabled = false
}
```

### environments/prod/terraform.tfvars
```hcl
# Production environment configuration

# Basic settings
environment = "prod"
project_name = "my-project"

# Cluster settings
cluster_version = "1.27"
cluster_endpoint_public_access = false

# Node groups configuration
node_groups = {
  critical = {
    instance_types = ["m5.large", "m5.xlarge"]
    capacity_type  = "ON_DEMAND"
    min_size       = 3
    max_size       = 10
    desired_size   = 5
    disk_size      = 100
  }
  
  flexible = {
    instance_types = ["m5.large", "m5.xlarge", "m4.large"]
    capacity_type  = "SPOT"
    min_size       = 0
    max_size       = 20
    desired_size   = 5
    disk_size      = 50
  }
}

# High availability
enable_nat_gateway = true
single_nat_gateway = false  # Multiple NAT gateways for HA

# Monitoring and logging
monitoring_enabled = true
logging_enabled    = true
log_retention_days = 90

# Security
enable_irsa = true
enable_pod_security_policy = true

# Backup
backup_enabled = true
backup_retention_days = 30

# Network security
allowed_cidr_blocks = [
  "10.0.0.0/8",    # Internal networks
  "172.16.0.0/12", # VPN ranges
]
```

---

## 📊 Monitoring Configuration

*Complete observability stack*

### monitoring.tf
```hcl
# Prometheus and Grafana stack
resource "helm_release" "kube_prometheus_stack" {
  name             = "kube-prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  namespace        = "monitoring"
  create_namespace = true
  version          = "51.2.0"

  values = [
    yamlencode({
      # Global configuration
      fullnameOverride = "prometheus"
      
      # Prometheus configuration
      prometheus = {
        prometheusSpec = {
          # Storage configuration
          retention = "30d"
          retentionSize = "50GB"
          
          storageSpec = {
            volumeClaimTemplate = {
              spec = {
                storageClassName = "gp3"
                accessModes      = ["ReadWriteOnce"]
                resources = {
                  requests = {
                    storage = "100Gi"
                  }
                }
              }
            }
          }
          
          # Resource configuration
          resources = {
            limits = {
              cpu    = "2000m"
              memory = "4Gi"
            }
            requests = {
              cpu    = "1000m"
              memory = "2Gi"
            }
          }
          
          # Security configuration
          securityContext = {
            runAsNonRoot = true
            runAsUser    = 65534
            fsGroup      = 65534
          }
          
          # Service monitor configuration
          serviceMonitorSelectorNilUsesHelmValues = false
          podMonitorSelectorNilUsesHelmValues     = false
          ruleSelectorNilUsesHelmValues           = false
          
          # External labels for federation
          externalLabels = {
            cluster = var.cluster_name
            region  = var.aws_region
          }
        }
        
        # Ingress configuration
        ingress = {
          enabled = true
          ingressClassName = "alb"
          annotations = {
            "alb.ingress.kubernetes.io/scheme"      = "internal"
            "alb.ingress.kubernetes.io/target-type" = "ip"
            "alb.ingress.kubernetes.io/listen-ports" = jsonencode([
              { HTTP = 80 },
              { HTTPS = 443 }
            ])
          }
          hosts = ["prometheus.internal.example.com"]
        }
      }
      
      # Grafana configuration
      grafana = {
        enabled = true
        
        # Admin configuration
        adminPassword = random_password.grafana_admin.result
        
        # Persistence
        persistence = {
          enabled          = true
          size             = "20Gi"
          storageClassName = "gp3"
        }
        
        # Resource configuration
        resources = {
          limits = {
            cpu    = "500m"
            memory = "512Mi"
          }
          requests = {
            cpu    = "100m"
            memory = "128Mi"
          }
        }
        
        # Configuration
        grafana.ini = {
          server = {
            root_url = "https://grafana.internal.example.com"
          }
          security = {
            disable_gravatar = true
          }
          users = {
            allow_sign_up = false
          }
          auth = {
            disable_login_form = false
          }
        }
        
        # Datasources
        datasources = {
          "datasources.yaml" = {
            apiVersion = 1
            datasources = [
              {
                name      = "Prometheus"
                type      = "prometheus"
                url       = "http://prometheus-prometheus:9090"
                isDefault = true
              },
              {
                name = "CloudWatch"
                type = "cloudwatch"
                jsonData = {
                  defaultRegion = var.aws_region
                  authType      = "default"
                }
              }
            ]
          }
        }
        
        # Dashboard providers
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
        
        # Pre-configured dashboards
        dashboards = {
          default = {
            "kubernetes-cluster" = {
              gnetId     = 7249
              revision   = 1
              datasource = "Prometheus"
            }
            "kubernetes-pods" = {
              gnetId     = 6417
              revision   = 1
              datasource = "Prometheus"
            }
            "aws-load-balancer-controller" = {
              gnetId     = 14366
              revision   = 2
              datasource = "Prometheus"
            }
          }
        }
        
        # Ingress configuration
        ingress = {
          enabled = true
          ingressClassName = "alb"
          annotations = {
            "alb.ingress.kubernetes.io/scheme"      = "internal"
            "alb.ingress.kubernetes.io/target-type" = "ip"
          }
          hosts = ["grafana.internal.example.com"]
        }
      }
      
      # AlertManager configuration
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
          
          resources = {
            limits = {
              cpu    = "200m"
              memory = "256Mi"
            }
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
          }
        }
        
        config = {
          global = {
            slack_api_url = var.slack_webhook_url
          }
          
          route = {
            group_by        = ["alertname", "cluster", "service"]
            group_wait      = "10s"
            group_interval  = "5m"
            repeat_interval = "12h"
            receiver        = "default"
            
            routes = [
              {
                match = {
                  severity = "critical"
                }
                receiver = "critical-alerts"
              }
            ]
          }
          
          receivers = [
            {
              name = "default"
              slack_configs = [
                {
                  channel    = "#alerts"
                  title      = "{{ range .Alerts }}{{ .Annotations.summary }}{{ end }}"
                  text       = "{{ range .Alerts }}{{ .Annotations.description }}{{ end }}"
                  send_resolved = true
                }
              ]
            },
            {
              name = "critical-alerts"
              slack_configs = [
                {
                  channel    = "#critical-alerts"
                  title      = "🚨 CRITICAL: {{ range .Alerts }}{{ .Annotations.summary }}{{ end }}"
                  text       = "{{ range .Alerts }}{{ .Annotations.description }}{{ end }}"
                  send_resolved = true
                }
              ]
            }
          ]
        }
      }
      
      # Node exporter configuration
      nodeExporter = {
        enabled = true
      }
      
      # Kube-state-metrics configuration
      kubeStateMetrics = {
        enabled = true
      }
    })
  ]

  depends_on = [module.eks]
}

# Generate random password for Grafana
resource "random_password" "grafana_admin" {
  length  = 16
  special = true
}

# Store Grafana password in AWS Secrets Manager
resource "aws_secretsmanager_secret" "grafana_admin" {
  name = "${var.cluster_name}-grafana-admin"
}

resource "aws_secretsmanager_secret_version" "grafana_admin" {
  secret_id     = aws_secretsmanager_secret.grafana_admin.id
  secret_string = random_password.grafana_admin.result
}
```

---

## 🚀 Microservices Application

*Complete microservices deployment example*

### microservices/frontend.yaml
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: default
  labels:
    app: frontend
    version: v1
spec:
  replicas: 3
  selector:
    matchLabels:
      app: frontend
      version: v1
  template:
    metadata:
      labels:
        app: frontend
        version: v1
    spec:
      containers:
      - name: frontend
        image: nginx:1.21-alpine
        ports:
        - containerPort: 80
        env:
        - name: BACKEND_URL
          value: "http://backend-service:8080"
        - name: API_URL
          value: "http://api-service:3000"
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
        volumeMounts:
        - name: config
          mountPath: /etc/nginx/conf.d
      volumes:
      - name: config
        configMap:
          name: frontend-config
---
apiVersion: v1
kind: Service
metadata:
  name: frontend-service
  labels:
    app: frontend
spec:
  selector:
    app: frontend
  ports:
  - port: 80
    targetPort: 80
    name: http
  type: ClusterIP
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: frontend-config
data:
  default.conf: |
    server {
        listen 80;
        server_name localhost;
        
        location / {
            root /usr/share/nginx/html;
            index index.html index.htm;
            try_files $uri $uri/ /index.html;
        }
        
        location /api {
            proxy_pass http://backend-service:8080;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }
    }
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: frontend-ingress
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
    alb.ingress.kubernetes.io/ssl-redirect: '443'
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:us-west-2:123456789:certificate/12345
spec:
  rules:
  - host: myapp.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend-service
            port:
              number: 80
```

### microservices/backend.yaml
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  labels:
    app: backend
    version: v1
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backend
      version: v1
  template:
    metadata:
      labels:
        app: backend
        version: v1
    spec:
      containers:
      - name: backend
        image: node:16-alpine
        ports:
        - containerPort: 8080
        env:
        - name: NODE_ENV
          value: "production"
        - name: PORT
          value: "8080"
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: database-secret
              key: url
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: backend-service
  labels:
    app: backend
spec:
  selector:
    app: backend
  ports:
  - port: 8080
    targetPort: 8080
    name: http
  type: ClusterIP
---
apiVersion: v1
kind: Secret
metadata:
  name: database-secret
type: Opaque
data:
  # Base64 encoded database URL
  url: cG9zdGdyZXNxbDovL3VzZXI6cGFzc0BkYXRhYmFzZS1zZXJ2aWNlOjU0MzIvbXlkYg==
```

### microservices/database.yaml
```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
  labels:
    app: postgres
spec:
  serviceName: postgres-service
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:13-alpine
        ports:
        - containerPort: 5432
        env:
        - name: POSTGRES_DB
          value: "mydb"
        - name: POSTGRES_USER
          value: "user"
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: password
        - name: PGDATA
          value: /var/lib/postgresql/data/pgdata
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        volumeMounts:
        - name: postgres-storage
          mountPath: /var/lib/postgresql/data
        livenessProbe:
          exec:
            command:
            - pg_isready
            - -U
            - user
            - -d
            - mydb
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          exec:
            command:
            - pg_isready
            - -U
            - user
            - -d
            - mydb
          initialDelaySeconds: 5
          periodSeconds: 5
  volumeClaimTemplates:
  - metadata:
      name: postgres-storage
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: "gp3"
      resources:
        requests:
          storage: 20Gi
---
apiVersion: v1
kind: Service
metadata:
  name: postgres-service
  labels:
    app: postgres
spec:
  selector:
    app: postgres
  ports:
  - port: 5432
    targetPort: 5432
    name: postgres
  type: ClusterIP
---
apiVersion: v1
kind: Secret
metadata:
  name: postgres-secret
type: Opaque
data:
  # Base64 encoded password: "mypassword"
  password: bXlwYXNzd29yZA==
```

---

## 🔧 Quick Start Scripts

### setup.sh
```bash
#!/bin/bash
set -e

# Quick setup script for basic EKS cluster

CLUSTER_NAME=${1:-"basic-eks-dev"}
AWS_REGION=${2:-"us-west-2"}

echo "🚀 Setting up EKS cluster: $CLUSTER_NAME in $AWS_REGION"

# Verify prerequisites
echo "📋 Checking prerequisites..."
command -v terraform >/dev/null 2>&1 || { echo "❌ Terraform not found. Please install Terraform."; exit 1; }
command -v aws >/dev/null 2>&1 || { echo "❌ AWS CLI not found. Please install AWS CLI."; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "❌ kubectl not found. Please install kubectl."; exit 1; }

# Check AWS credentials
aws sts get-caller-identity >/dev/null 2>&1 || { echo "❌ AWS credentials not configured. Please run 'aws configure'."; exit 1; }

echo "✅ Prerequisites check passed"

# Initialize Terraform
echo "🔧 Initializing Terraform..."
terraform init

# Plan
echo "📋 Planning Terraform deployment..."
terraform plan -var="cluster_name=$CLUSTER_NAME" -var="aws_region=$AWS_REGION"

# Ask for confirmation
read -p "Do you want to apply these changes? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Apply
    echo "🚀 Applying Terraform configuration..."
    terraform apply -var="cluster_name=$CLUSTER_NAME" -var="aws_region=$AWS_REGION" -auto-approve
    
    # Configure kubectl
    echo "⚙️ Configuring kubectl..."
    aws eks --region $AWS_REGION update-kubeconfig --name $CLUSTER_NAME
    
    # Verify cluster
    echo "✅ Verifying cluster..."
    kubectl get nodes
    kubectl get pods --all-namespaces
    
    echo "🎉 EKS cluster $CLUSTER_NAME is ready!"
    echo "📋 Next steps:"
    echo "   - Deploy applications: kubectl apply -f your-app.yaml"
    echo "   - Monitor cluster: kubectl get pods -A"
    echo "   - Access logs: kubectl logs -f deployment/your-app"
else
    echo "❌ Deployment cancelled"
fi
```

### cleanup.sh
```bash
#!/bin/bash
set -e

# Cleanup script for EKS resources

CLUSTER_NAME=${1:-"basic-eks-dev"}
AWS_REGION=${2:-"us-west-2"}

echo "🧹 Cleaning up EKS cluster: $CLUSTER_NAME in $AWS_REGION"

# Warning
read -p "⚠️  This will destroy all resources. Are you sure? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🗑️ Destroying Terraform resources..."
    terraform destroy -var="cluster_name=$CLUSTER_NAME" -var="aws_region=$AWS_REGION" -auto-approve
    
    echo "✅ Cleanup completed"
else
    echo "❌ Cleanup cancelled"
fi
```

---

## 📚 Usage Instructions

### Getting Started
1. Choose the appropriate template for your use case
2. Copy the template files to your project directory
3. Customize variables in `terraform.tfvars`
4. Run the setup script or Terraform commands manually

### Template Progression
1. **Start with Basic EKS** for learning
2. **Move to Production EKS** when ready for production
3. **Add GitOps** for automation
4. **Implement Multi-Environment** for scale
5. **Add Monitoring** for observability

### Customization Guidelines
- Always update `terraform.tfvars` with your specific values
- Modify resource sizes based on your workload requirements
- Adjust security settings based on your compliance needs
- Update monitoring configurations for your alerting preferences

---

## Navigation
← [Troubleshooting Guide](./troubleshooting.md) | ↑ [README](./README.md)