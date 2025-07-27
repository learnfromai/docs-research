# Best Practices: Terraform with AWS/Kubernetes/EKS

This document consolidates best practices learned from analyzing production-ready open source projects.

## 🏗️ Infrastructure Architecture Best Practices

### 1. **Modular Terraform Design**

#### Recommended Module Structure
```
terraform/
├── modules/
│   ├── vpc/
│   ├── eks/
│   ├── monitoring/
│   └── security/
├── environments/
│   ├── dev/
│   ├── staging/
│   └── production/
├── global/
│   └── backend.tf
└── shared/
    └── data.tf
```

#### Module Best Practices
```hcl
# ✅ Good: Well-defined module with clear inputs/outputs
module "eks" {
  source = "./modules/eks"
  
  cluster_name    = var.cluster_name
  cluster_version = var.kubernetes_version
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.private_subnet_ids
  
  # Pass only what's needed
  node_groups = var.node_groups
  
  tags = local.common_tags
}

# ❌ Bad: Monolithic configuration
resource "aws_eks_cluster" "cluster" {
  # 200+ lines of configuration...
}
```

### 2. **VPC and Network Design**

#### Multi-AZ Setup with Proper Subnetting
```hcl
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  
  name = "${var.environment}-${var.cluster_name}"
  cidr = "10.0.0.0/16"
  
  # Span multiple AZs for high availability
  azs = slice(data.aws_availability_zones.available.names, 0, 3)
  
  # Private subnets for nodes (more secure)
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  # Public subnets for load balancers
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  
  # Required for EKS
  enable_nat_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  # EKS-specific subnet tags
  public_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = "1"
  }
  
  private_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"           = "1"
  }
}
```

### 3. **EKS Cluster Configuration**

#### Production-Ready Cluster Setup
```hcl
module "eks" {
  source = "terraform-aws-modules/eks/aws"
  
  cluster_name    = var.cluster_name
  cluster_version = "1.33"
  
  # Network configuration
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets
  
  # Security settings
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true
  cluster_endpoint_public_access_cidrs = var.allowed_cidr_blocks
  
  # Encryption at rest
  cluster_encryption_config = {
    provider_key_arn = aws_kms_key.eks.arn
    resources        = ["secrets"]
  }
  
  # Logging
  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  
  # Node groups with best practices
  eks_managed_node_groups = {
    main = {
      # Use latest Amazon Linux 2 optimized AMI
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = var.node_instance_types
      
      # Scaling configuration
      min_size     = var.node_min_size
      max_size     = var.node_max_size
      desired_size = var.node_desired_size
      
      # Security
      disk_size      = 50
      disk_encrypted = true
      
      # Networking
      subnet_ids = module.vpc.private_subnets
      
      # Labels and taints
      labels = {
        Environment = var.environment
        NodeGroup   = "main"
      }
      
      # Update configuration
      update_config = {
        max_unavailable_percentage = 25
      }
    }
  }
  
  # Fargate profiles for serverless workloads
  fargate_profiles = {
    default = {
      name = "default"
      selectors = [
        {
          namespace = "default"
        },
        {
          namespace = "kube-system"
        }
      ]
    }
  }
}
```

## 🔐 Security Best Practices

### 1. **IAM Roles for Service Accounts (IRSA)**

#### Secure Service-to-Service Communication
```hcl
# ✅ Best Practice: Use IRSA instead of storing AWS credentials
module "aws_load_balancer_controller_irsa_role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  
  role_name = "${var.cluster_name}-aws-load-balancer-controller"
  
  attach_load_balancer_controller_policy = true
  
  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
  
  tags = local.common_tags
}

# Deploy with Helm
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
}
```

### 2. **Network Security**

#### Security Groups and Network Policies
```hcl
# Additional security group rules
resource "aws_security_group_rule" "node_to_node" {
  description              = "Allow node to communicate with each other"
  from_port                = 0
  protocol                 = "-1"
  security_group_id        = module.eks.node_security_group_id
  source_security_group_id = module.eks.node_security_group_id
  to_port                  = 65535
  type                     = "ingress"
}

# Network policy for pod-to-pod communication
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

### 3. **Secrets Management**

#### External Secrets Integration
```hcl
# Install External Secrets Operator
resource "helm_release" "external_secrets" {
  name       = "external-secrets"
  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  namespace  = "external-secrets-system"
  
  create_namespace = true
  
  set {
    name  = "installCRDs"
    value = "true"
  }
}

# IRSA role for External Secrets
module "external_secrets_irsa_role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  
  role_name = "${var.cluster_name}-external-secrets"
  
  role_policy_arns = {
    policy = aws_iam_policy.external_secrets.arn
  }
  
  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["external-secrets-system:external-secrets"]
    }
  }
}
```

## 📊 Monitoring and Observability

### 1. **Prometheus and Grafana Setup**

#### Complete Monitoring Stack
```hcl
resource "helm_release" "kube_prometheus_stack" {
  name       = "kube-prometheus-stack"
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
        }
      }
      
      grafana = {
        adminPassword = var.grafana_admin_password
        persistence = {
          enabled      = true
          storageClassName = "gp3"
          size         = "10Gi"
        }
        
        # Custom dashboards
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
        config = {
          global = {
            slack_api_url = var.slack_webhook_url
          }
          route = {
            group_by        = ["alertname"]
            group_wait      = "10s"
            group_interval  = "10s"
            repeat_interval = "1h"
            receiver        = "web.hook"
          }
          receivers = [
            {
              name = "web.hook"
              slack_configs = [
                {
                  channel  = "#alerts"
                  title    = "{{ range .Alerts }}{{ .Annotations.summary }}{{ end }}"
                  text     = "{{ range .Alerts }}{{ .Annotations.description }}{{ end }}"
                }
              ]
            }
          ]
        }
      }
    })
  ]
}
```

### 2. **Logging with Fluent Bit**

#### Centralized Logging Setup
```hcl
resource "helm_release" "fluent_bit" {
  name       = "fluent-bit"
  repository = "https://fluent.github.io/helm-charts"
  chart      = "fluent-bit"
  namespace  = "logging"
  
  create_namespace = true
  
  values = [
    yamlencode({
      config = {
        outputs = "[OUTPUT]\n    Name cloudwatch\n    Match *\n    region ${var.region}\n    log_group_name /eks/${var.cluster_name}/fluent-bit\n    log_stream_name $${hostname}\n    auto_create_group true"
      }
      
      serviceAccount = {
        annotations = {
          "eks.amazonaws.com/role-arn" = module.fluent_bit_irsa_role.iam_role_arn
        }
      }
    })
  ]
}
```

## 🚀 Deployment and GitOps

### 1. **ArgoCD Integration**

#### GitOps Workflow Setup
```hcl
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = "argocd"
  
  create_namespace = true
  
  values = [
    yamlencode({
      server = {
        service = {
          type = "LoadBalancer"
          annotations = {
            "service.beta.kubernetes.io/aws-load-balancer-type" = "nlb"
          }
        }
        
        # High availability
        replicas = 2
        
        # Auto-sync configuration
        config = {
          "application.instanceLabelKey" = "argocd.argoproj.io/instance"
          "server.rbac.log.enforce.enable" = "true"
          "policy.default" = "role:readonly"
        }
      }
      
      controller = {
        replicas = 2
      }
      
      redis = {
        enabled = true
      }
    })
  ]
}
```

### 2. **Application Deployment Patterns**

#### Application Configuration
```yaml
# application.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: argocd
spec:
  project: default
  
  source:
    repoURL: https://github.com/my-org/my-app
    targetRevision: HEAD
    path: k8s/overlays/production
  
  destination:
    server: https://kubernetes.default.svc
    namespace: my-app
  
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
    - PrunePropagationPolicy=foreground
    - PruneLast=true
```

## 🏗️ Infrastructure Management

### 1. **State Management**

#### Remote State with Locking
```hcl
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "eks/production/terraform.tfstate"
    region         = "us-west-2"
    encrypt        = true
    
    # State locking
    dynamodb_table = "terraform-locks"
    
    # Workspace support
    workspace_key_prefix = "workspaces"
  }
}

# Separate backend configuration for each environment
# backend-dev.hcl
bucket = "my-terraform-state"
key    = "eks/dev/terraform.tfstate"

# backend-prod.hcl  
bucket = "my-terraform-state"
key    = "eks/production/terraform.tfstate"
```

### 2. **Environment Management**

#### Workspace Strategy
```bash
# Initialize with backend config
terraform init -backend-config=backend-prod.hcl

# Use workspaces for environment isolation
terraform workspace new production
terraform workspace new staging
terraform workspace new development

# Deploy to specific environment
terraform workspace select production
terraform apply -var-file="production.tfvars"
```

#### Environment-Specific Variables
```hcl
# variables.tf
variable "environment_configs" {
  description = "Environment-specific configurations"
  type = map(object({
    node_instance_types = list(string)
    node_min_size      = number
    node_max_size      = number
    node_desired_size  = number
  }))
  
  default = {
    development = {
      node_instance_types = ["t3.small"]
      node_min_size      = 1
      node_max_size      = 3
      node_desired_size  = 2
    }
    
    production = {
      node_instance_types = ["m5.large", "m5.xlarge"]
      node_min_size      = 3
      node_max_size      = 20
      node_desired_size  = 6
    }
  }
}

# Use in configuration
locals {
  env_config = var.environment_configs[var.environment]
}
```

## 🧪 Testing and Validation

### 1. **Infrastructure Testing**

#### Terratest Integration
```go
// test/eks_test.go
package test

import (
    "testing"
    "github.com/gruntwork-io/terratest/modules/terraform"
    "github.com/stretchr/testify/assert"
)

func TestEKSCluster(t *testing.T) {
    terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
        TerraformDir: "../examples/complete",
        Vars: map[string]interface{}{
            "cluster_name": "test-cluster",
            "region":      "us-west-2",
        },
    })

    defer terraform.Destroy(t, terraformOptions)
    terraform.InitAndApply(t, terraformOptions)

    clusterName := terraform.Output(t, terraformOptions, "cluster_name")
    assert.Equal(t, "test-cluster", clusterName)
}
```

### 2. **Pre-commit Hooks**

#### Code Quality Checks
```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/antonbabenko/pre-commit-terraform
    rev: v1.83.2
    hooks:
      - id: terraform_fmt
      - id: terraform_docs
      - id: terraform_validate
      - id: terraform_tflint
      - id: checkov
        args: [--quiet, --compact]
```

## 📋 Operational Best Practices

### 1. **Backup and Disaster Recovery**

#### Velero Setup
```hcl
resource "helm_release" "velero" {
  name       = "velero"
  repository = "https://vmware-tanzu.github.io/helm-charts"
  chart      = "velero"
  namespace  = "velero"
  
  create_namespace = true
  
  values = [
    yamlencode({
      configuration = {
        provider = "aws"
        backupStorageLocation = {
          bucket = aws_s3_bucket.velero.bucket
          config = {
            region = var.region
          }
        }
        volumeSnapshotLocation = {
          config = {
            region = var.region
          }
        }
      }
      
      serviceAccount = {
        server = {
          annotations = {
            "eks.amazonaws.com/role-arn" = module.velero_irsa_role.iam_role_arn
          }
        }
      }
      
      # Backup schedules
      schedules = {
        daily = {
          template = {
            includedNamespaces = ["*"]
            excludedNamespaces = ["velero"]
          }
          schedule = "0 2 * * *"
        }
      }
    })
  ]
}
```

### 2. **Cost Optimization**

#### Spot Instances and Auto-scaling
```hcl
eks_managed_node_groups = {
  spot = {
    capacity_type  = "SPOT"
    instance_types = ["m5.large", "m5a.large", "m4.large"]
    
    # Mixed instance policy for better availability
    use_mixed_instances_policy = true
    mixed_instances_policy = {
      instances_distribution = {
        on_demand_base_capacity                  = 1
        on_demand_percentage_above_base_capacity = 10
        spot_allocation_strategy                 = "capacity-optimized"
      }
    }
    
    # Cluster autoscaler tags
    tags = {
      "k8s.io/cluster-autoscaler/enabled" = "true"
      "k8s.io/cluster-autoscaler/${var.cluster_name}" = "owned"
    }
  }
}
```

## 🚨 Common Anti-Patterns to Avoid

### ❌ **Security Anti-Patterns**

```hcl
# DON'T: Store secrets in Terraform state
resource "kubernetes_secret" "db_password" {
  data = {
    password = "hardcoded-password"  # ❌ Never do this
  }
}

# DON'T: Use overly permissive security groups
resource "aws_security_group_rule" "allow_all" {
  cidr_blocks = ["0.0.0.0/0"]  # ❌ Too permissive
  from_port   = 0
  to_port     = 65535
}
```

### ❌ **Infrastructure Anti-Patterns**

```hcl
# DON'T: Single AZ deployment
resource "aws_subnet" "single_az" {
  availability_zone = "us-west-2a"  # ❌ No high availability
}

# DON'T: Hardcode values
resource "aws_eks_cluster" "cluster" {
  name = "prod-cluster"  # ❌ Not flexible
  version = "1.29"       # ❌ Should be variable
}
```

---

## 🔗 Navigation

| Previous | Current | Next |
|----------|---------|------|
| [Implementation Guide](./implementation-guide.md) | **Best Practices** | [Template Examples](./template-examples.md) |

---

*These best practices are derived from analyzing production-ready open source projects and industry standards for Kubernetes platform engineering.*