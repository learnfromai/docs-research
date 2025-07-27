# Implementation Guide: Learning from Open Source DevOps Projects

## 🎯 Overview

This guide provides a structured approach to studying and implementing patterns from production-ready open source DevOps projects that use Terraform with AWS, Kubernetes, and EKS. Follow this methodology to systematically learn from real-world implementations.

## 📋 Prerequisites

### Required Tools & Knowledge
- **AWS Account**: Active account with billing alerts configured
- **Local Development Environment**: 
  - Terraform >= 1.5.0
  - kubectl >= 1.28.0
  - AWS CLI >= 2.0
  - Docker Desktop
- **Basic Knowledge**:
  - Terraform fundamentals (modules, state, providers)
  - Kubernetes concepts (pods, services, deployments)
  - AWS services (VPC, EC2, IAM)
  - Git workflows and version control

### Initial Setup Checklist
- [ ] AWS CLI configured with appropriate credentials
- [ ] Terraform installed and PATH configured
- [ ] kubectl installed and configured
- [ ] GitHub/GitLab account for repository management
- [ ] Code editor with Terraform and YAML extensions

## 🚀 Phase 1: Foundation Learning (Weeks 1-2)

### Step 1: Environment Preparation
```bash
# Install required tools (macOS example)
brew install terraform kubectl awscli helm

# Verify installations
terraform version
kubectl version --client
aws --version
helm version
```

### Step 2: Study AWS EKS Blueprints
**Repository**: [aws-ia/terraform-aws-eks-blueprints](https://github.com/aws-ia/terraform-aws-eks-blueprints)

#### Learning Approach
1. **Clone and Explore**:
   ```bash
   git clone https://github.com/aws-ia/terraform-aws-eks-blueprints.git
   cd terraform-aws-eks-blueprints
   
   # Explore the structure
   tree -L 3
   ```

2. **Analyze Module Structure**:
   ```
   modules/
   ├── eks-blueprints/          # Core EKS cluster module
   ├── eks-blueprints-addons/   # Add-on configurations
   ├── vpc/                     # Networking module
   └── irsa/                    # IAM Roles for Service Accounts
   ```

3. **Start with Basic Example**:
   ```bash
   cd examples/getting-started
   
   # Review the configuration
   cat main.tf
   cat variables.tf
   cat outputs.tf
   ```

#### Hands-on Exercise
Create your first EKS cluster using the blueprint:

```hcl
# main.tf - Basic EKS cluster
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Data sources
data "aws_availability_zones" "available" {}
data "aws_caller_identity" "current" {}

# VPC Module
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  
  name = "${var.cluster_name}-vpc"
  cidr = "10.0.0.0/16"
  
  azs             = slice(data.aws_availability_zones.available.names, 0, 3)
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
  
  tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

# EKS Blueprints
module "eks" {
  source = "github.com/aws-ia/terraform-aws-eks-blueprints"
  
  cluster_name    = var.cluster_name
  cluster_version = "1.28"
  
  vpc_id               = module.vpc.vpc_id
  private_subnet_ids   = module.vpc.private_subnets
  
  managed_node_groups = {
    initial = {
      node_group_name = "managed-ondemand"
      instance_types  = ["t3.medium"]
      desired_size    = 2
      max_size        = 4
      min_size        = 1
    }
  }
  
  tags = {
    Environment = "learning"
    Project     = "eks-blueprints-study"
  }
}

# EKS Blueprints Add-ons
module "eks_addons" {
  source = "aws-ia/eks-blueprints-addons/aws"
  
  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn
  
  eks_addons = {
    aws-ebs-csi-driver = {
      most_recent = true
    }
    coredns = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
  }
  
  # Essential add-ons for learning
  enable_aws_load_balancer_controller = true
  enable_metrics_server               = true
  enable_cluster_autoscaler          = true
  
  tags = {
    Environment = "learning"
  }
}
```

#### Deployment Steps
```bash
# Initialize Terraform
terraform init

# Plan the deployment
terraform plan -var="cluster_name=learning-eks" -var="aws_region=us-west-2"

# Apply (this will take 15-20 minutes)
terraform apply -var="cluster_name=learning-eks" -var="aws_region=us-west-2"

# Configure kubectl
aws eks update-kubeconfig --name learning-eks --region us-west-2

# Verify cluster
kubectl get nodes
kubectl get pods -A
```

### Step 3: Understand Key Patterns

#### Pattern 1: Module Composition
Study how blueprints compose multiple modules:
- **VPC Module**: Network foundation
- **EKS Module**: Control plane and worker nodes
- **Add-ons Module**: Operational components

#### Pattern 2: IRSA (IAM Roles for Service Accounts)
```hcl
# Example: AWS Load Balancer Controller IRSA
module "aws_load_balancer_controller_irsa" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  
  role_name = "aws-load-balancer-controller"
  
  attach_load_balancer_controller_policy = true
  
  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
}
```

#### Pattern 3: Add-on Management
```hcl
# Systematic add-on installation
locals {
  addons = {
    coredns = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
      configuration_values = jsonencode({
        env = {
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = "1"
        }
      })
    }
  }
}
```

---

## 🔄 Phase 2: GitOps Implementation (Weeks 3-4)

### Step 1: ArgoCD Installation and Configuration

#### Install ArgoCD via Terraform
```hcl
# argocd.tf
resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }
}

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = "argocd"
  version    = "5.51.6"
  
  values = [
    yamlencode({
      global = {
        domain = "argocd.${var.domain_name}"
      }
      server = {
        ingress = {
          enabled = true
          annotations = {
            "kubernetes.io/ingress.class"                    = "alb"
            "alb.ingress.kubernetes.io/scheme"               = "internet-facing"
            "alb.ingress.kubernetes.io/target-type"          = "ip"
            "alb.ingress.kubernetes.io/certificate-arn"      = var.certificate_arn
            "alb.ingress.kubernetes.io/listen-ports"         = "[{\"HTTP\": 80}, {\"HTTPS\": 443}]"
            "alb.ingress.kubernetes.io/ssl-redirect"         = "443"
          }
          hosts = ["argocd.${var.domain_name}"]
        }
        config = {
          "application.instanceLabelKey" = "argocd.argoproj.io/instance"
          "server.insecure"              = "true"
        }
      }
      configs = {
        secret = {
          argocdServerAdminPassword = bcrypt(var.argocd_admin_password)
        }
      }
    })
  ]
}
```

#### Repository Structure for GitOps
```
gitops-infrastructure/
├── apps/
│   ├── app-of-apps.yaml
│   ├── monitoring/
│   │   ├── kustomization.yaml
│   │   └── prometheus-stack.yaml
│   ├── ingress/
│   │   ├── kustomization.yaml
│   │   └── aws-load-balancer-controller.yaml
│   └── workloads/
│       ├── kustomization.yaml
│       └── sample-app.yaml
├── infrastructure/
│   ├── terraform/
│   │   ├── environments/
│   │   │   ├── dev/
│   │   │   │   ├── main.tf
│   │   │   │   ├── terraform.tfvars
│   │   │   │   └── backend.tf
│   │   │   ├── staging/
│   │   │   └── prod/
│   │   └── modules/
│   │       ├── eks-cluster/
│   │       ├── monitoring/
│   │       └── security/
│   └── kubernetes/
│       ├── base/
│       │   ├── monitoring/
│       │   ├── ingress/
│       │   └── security/
│       └── overlays/
│           ├── dev/
│           ├── staging/
│           └── prod/
└── docs/
    ├── setup.md
    ├── troubleshooting.md
    └── architecture.md
```

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
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/gitops-infrastructure
    targetRevision: HEAD
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
```

### Step 2: Application Deployment Patterns

#### Monitoring Stack Application
```yaml
# apps/monitoring/prometheus-stack.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: kube-prometheus-stack
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://prometheus-community.github.io/helm-charts
    chart: kube-prometheus-stack
    targetRevision: 55.5.0
    helm:
      releaseName: kube-prometheus-stack
      values: |
        prometheus:
          prometheusSpec:
            serviceMonitorSelectorNilUsesHelmValues: false
            podMonitorSelectorNilUsesHelmValues: false
            storageSpec:
              volumeClaimTemplate:
                spec:
                  storageClassName: gp3
                  accessModes: ["ReadWriteOnce"]
                  resources:
                    requests:
                      storage: 50Gi
        grafana:
          adminPassword: admin123
          persistence:
            enabled: true
            storageClassName: gp3
            size: 10Gi
          service:
            type: LoadBalancer
  destination:
    server: https://kubernetes.default.svc
    namespace: monitoring
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

---

## 📊 Phase 3: Monitoring and Observability (Weeks 5-6)

### Step 1: Comprehensive Monitoring Setup

#### Prometheus Configuration
```yaml
# infrastructure/kubernetes/base/monitoring/prometheus-config.yaml
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
    
    rule_files:
      - /etc/prometheus/rules/*.yml
    
    scrape_configs:
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
      
      - job_name: 'kubernetes-nodes'
        kubernetes_sd_configs:
          - role: node
        scheme: https
        tls_config:
          ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
```

#### Grafana Dashboard as Code
```json
{
  "dashboard": {
    "id": null,
    "title": "EKS Cluster Overview",
    "tags": ["kubernetes", "eks"],
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "Cluster CPU Usage",
        "type": "stat",
        "targets": [
          {
            "expr": "100 - (avg(irate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)",
            "legendFormat": "CPU Usage %"
          }
        ]
      }
    ],
    "time": {
      "from": "now-1h",
      "to": "now"
    },
    "refresh": "5s"
  }
}
```

### Step 2: AWS CloudWatch Integration
```hcl
# cloudwatch-integration.tf
resource "aws_cloudwatch_log_group" "eks_cluster" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = 7
}

resource "helm_release" "aws_for_fluent_bit" {
  name       = "aws-for-fluent-bit"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-for-fluent-bit"
  namespace  = "amazon-cloudwatch"
  
  create_namespace = true
  
  values = [
    yamlencode({
      cloudWatchLogs = {
        enabled = true
        region  = var.aws_region
      }
      firehose = {
        enabled = false
      }
      kinesis = {
        enabled = false
      }
    })
  ]
}
```

---

## 🔐 Phase 4: Security Implementation (Weeks 7-8)

### Step 1: Pod Security Standards
```yaml
# infrastructure/kubernetes/base/security/pod-security-policy.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
---
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
```

### Step 2: OPA Gatekeeper Policies
```yaml
# security/gatekeeper-constraints.yaml
apiVersion: templates.gatekeeper.sh/v1beta1
kind: ConstraintTemplate
metadata:
  name: requireresourcelimits
spec:
  crd:
    spec:
      names:
        kind: RequireResourceLimits
      validation:
        openAPIV3Schema:
          type: object
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package requireresourcelimits
        
        violation[{"msg": msg}] {
          container := input.review.object.spec.containers[_]
          not container.resources.limits.memory
          msg := "Container must have memory limits"
        }
        
        violation[{"msg": msg}] {
          container := input.review.object.spec.containers[_]
          not container.resources.limits.cpu
          msg := "Container must have CPU limits"
        }
---
apiVersion: config.gatekeeper.sh/v1alpha1
kind: RequireResourceLimits
metadata:
  name: must-have-resource-limits
spec:
  match:
    - apiGroups: ["apps"]
      kinds: ["Deployment"]
      namespaces: ["production"]
```

---

## 🚀 Phase 5: Advanced Patterns (Weeks 9-12)

### Step 1: Multi-Environment Management
```hcl
# environments/dev/main.tf
module "eks_cluster" {
  source = "../../modules/eks-cluster"
  
  cluster_name     = "dev-cluster"
  cluster_version  = "1.28"
  instance_types   = ["t3.medium"]
  desired_capacity = 2
  max_capacity     = 4
  min_capacity     = 1
  
  # Development-specific configurations
  enable_logging = false
  node_group_disk_size = 20
  
  tags = {
    Environment = "development"
    CostCenter  = "engineering"
  }
}

# environments/prod/main.tf
module "eks_cluster" {
  source = "../../modules/eks-cluster"
  
  cluster_name     = "prod-cluster"
  cluster_version  = "1.28"
  instance_types   = ["m5.large", "m5.xlarge"]
  desired_capacity = 6
  max_capacity     = 20
  min_capacity     = 6
  
  # Production-specific configurations
  enable_logging = true
  node_group_disk_size = 100
  
  tags = {
    Environment = "production"
    CostCenter  = "engineering"
  }
}
```

### Step 2: Disaster Recovery Setup
```hcl
# backup-configuration.tf
resource "aws_s3_bucket" "velero_backup" {
  bucket = "${var.cluster_name}-velero-backup"
}

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
          bucket = aws_s3_bucket.velero_backup.bucket
          config = {
            region = var.aws_region
          }
        }
      }
      schedules = {
        daily = {
          schedule = "0 2 * * *"
          template = {
            ttl = "720h"
          }
        }
      }
    })
  ]
}
```

---

## 🎯 Success Metrics & Validation

### Infrastructure Metrics
```bash
# Validate cluster health
kubectl get nodes
kubectl get pods -A
kubectl top nodes
kubectl top pods -A

# Check add-on status
helm list -A
kubectl get crd | grep -E "(argo|prometheus|grafana)"

# Verify IRSA functionality
kubectl get sa -A | grep aws
kubectl describe sa aws-load-balancer-controller -n kube-system
```

### Application Deployment Metrics
```bash
# GitOps validation
kubectl get applications -n argocd
kubectl get appprojects -n argocd

# Monitor application sync status
argocd app list
argocd app get app-of-apps
```

### Security Validation
```bash
# Pod Security Standards
kubectl auth can-i create pods --as=system:serviceaccount:default:default
kubectl get psp
kubectl get networkpolicies -A

# Gatekeeper validation
kubectl get constraints
kubectl get constrainttemplates
```

---

## 📚 Recommended Study Sequence

### Week 1-2: Foundation
1. Complete AWS EKS Blueprints basic example
2. Study module composition patterns
3. Understand IRSA implementation
4. Deploy monitoring stack

### Week 3-4: GitOps
1. Install and configure ArgoCD
2. Implement app-of-apps pattern
3. Create multi-application deployment
4. Practice rollback procedures

### Week 5-6: Observability
1. Deploy comprehensive monitoring
2. Configure custom dashboards
3. Set up alerting rules
4. Integrate with AWS CloudWatch

### Week 7-8: Security
1. Implement Pod Security Standards
2. Deploy OPA Gatekeeper
3. Configure network policies
4. Set up security scanning

### Week 9-12: Production Readiness
1. Multi-environment management
2. Disaster recovery setup
3. Cost optimization
4. Performance tuning

---

## 🔗 Navigation

← [Back to Project Analysis](./project-analysis.md) | [Next: Best Practices](./best-practices.md) →