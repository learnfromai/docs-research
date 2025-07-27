# Implementation Guide: Getting Started with Terraform, AWS, and Kubernetes

This comprehensive guide provides step-by-step instructions for implementing production-ready DevOps infrastructure using patterns from the best open source projects.

## 🎯 Prerequisites

### Required Tools
```bash
# Core tools
aws-cli         # AWS CLI v2
terraform      # >= v1.5.0
kubectl        # >= v1.27.0
helm           # >= v3.12.0

# Optional but recommended
k9s            # Kubernetes UI
flux           # GitOps CLI
terragrunt     # Terraform wrapper
```

### Knowledge Requirements
- **Basic**: Linux command line, Git workflows
- **Intermediate**: AWS services (VPC, EC2, IAM), Docker containers
- **Advanced**: Kubernetes concepts, Infrastructure as Code principles

## 🚀 Quick Start Path

### Phase 1: Foundation (Week 1-2)
**Goal**: Deploy your first EKS cluster with Terraform

1. **Study Reference**: [terraform-aws-eks](https://github.com/terraform-aws-modules/terraform-aws-eks)
2. **Follow Pattern**: AWS official EKS module
3. **Deploy**: Basic EKS cluster with managed node groups

### Phase 2: Production Readiness (Week 3-4)
**Goal**: Implement production-grade configurations

1. **Study Reference**: [eks-blueprints-for-terraform](https://github.com/aws-ia/terraform-aws-eks-blueprints)
2. **Add**: Security, monitoring, and add-ons
3. **Implement**: Multi-environment strategy

### Phase 3: GitOps Integration (Week 5-6)
**Goal**: Automate deployments with GitOps

1. **Study Reference**: [tofu-controller](https://github.com/flux-iac/tofu-controller)
2. **Implement**: FluxCD with Terraform automation
3. **Practice**: GitOps workflows

---

## 📋 Detailed Implementation Steps

## Step 1: Environment Setup

### 1.1 AWS Configuration
```bash
# Configure AWS CLI
aws configure
# or use AWS SSO
aws configure sso

# Verify access
aws sts get-caller-identity
```

### 1.2 Terraform Setup
```bash
# Create project directory
mkdir terraform-k8s-project
cd terraform-k8s-project

# Initialize Terraform configuration
cat > main.tf << 'EOF'
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
  }
}

provider "aws" {
  region = var.aws_region
}
EOF
```

### 1.3 Variables Configuration
```bash
cat > variables.tf << 'EOF'
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "my-eks-cluster"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}
EOF
```

---

## Step 2: VPC Infrastructure

### 2.1 VPC Module Implementation
*Based on [terraform-aws-eks](https://github.com/terraform-aws-modules/terraform-aws-eks) patterns*

```bash
cat > vpc.tf << 'EOF'
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.cluster_name}-vpc"
  cidr = "10.0.0.0/16"

  azs             = data.aws_availability_zones.available.names
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = false  # Set to true for cost savings
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Tags required for EKS
  public_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"           = "1"
  }

  tags = {
    Environment = var.environment
    Project     = var.cluster_name
  }
}

data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}
EOF
```

---

## Step 3: EKS Cluster Deployment

### 3.1 Basic EKS Configuration
*Following [terraform-aws-eks](https://github.com/terraform-aws-modules/terraform-aws-eks) best practices*

```bash
cat > eks.tf << 'EOF'
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.27"

  vpc_id                         = module.vpc.vpc_id
  subnet_ids                     = module.vpc.private_subnets
  cluster_endpoint_public_access = true

  # EKS Managed Node Groups
  eks_managed_node_groups = {
    main = {
      name = "main"

      instance_types = ["t3.medium"]
      
      min_size     = 1
      max_size     = 10
      desired_size = 3

      # Use spot instances for cost savings
      capacity_type = "SPOT"

      # Disk size
      disk_size = 50

      # Labels and taints
      labels = {
        Environment = var.environment
        NodeGroup   = "main"
      }

      # User data for additional setup
      pre_bootstrap_user_data = <<-EOT
        #!/bin/bash
        /etc/eks/bootstrap.sh ${var.cluster_name}
      EOT

      tags = {
        Environment = var.environment
      }
    }
  }

  # Cluster access entry
  # To add the current caller identity as an administrator
  enable_cluster_creator_admin_permissions = true

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

  tags = {
    Environment = var.environment
    Project     = var.cluster_name
  }
}
EOF
```

### 3.2 Kubernetes Provider Configuration
```bash
cat > kubernetes.tf << 'EOF'
# Kubernetes provider configuration
data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_name
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}
EOF
```

---

## Step 4: Essential Add-ons

### 4.1 AWS Load Balancer Controller
*Following [eks-blueprints-for-terraform](https://github.com/aws-ia/terraform-aws-eks-blueprints) patterns*

```bash
cat > addons.tf << 'EOF'
# AWS Load Balancer Controller
module "aws_load_balancer_controller" {
  source = "terraform-aws-modules/eks/aws//modules/aws-load-balancer-controller"

  cluster_name = module.eks.cluster_name

  attach_cluster_encryption_policy = false
  attach_node_group_policy         = false

  depends_on = [module.eks]
}

# Metrics Server
resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  namespace  = "kube-system"

  set {
    name  = "args"
    value = "{--kubelet-insecure-tls}"
  }

  depends_on = [module.eks]
}

# Cluster Autoscaler
resource "helm_release" "cluster_autoscaler" {
  name       = "cluster-autoscaler"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  namespace  = "kube-system"

  set {
    name  = "autoDiscovery.clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "awsRegion"
    value = var.aws_region
  }

  depends_on = [module.eks]
}
EOF
```

### 4.2 Ingress Controller
```bash
cat >> addons.tf << 'EOF'

# NGINX Ingress Controller
resource "helm_release" "ingress_nginx" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = "ingress-nginx"
  create_namespace = true

  values = [
    yamlencode({
      controller = {
        service = {
          type = "LoadBalancer"
          annotations = {
            "service.beta.kubernetes.io/aws-load-balancer-type" = "nlb"
          }
        }
        metrics = {
          enabled = true
        }
      }
    })
  ]

  depends_on = [module.eks]
}
EOF
```

---

## Step 5: Monitoring and Observability

### 5.1 Prometheus and Grafana Stack
*Based on [terraform-kubernetes-monitoring-prometheus](https://github.com/mateothegreat/terraform-kubernetes-monitoring-prometheus)*

```bash
cat > monitoring.tf << 'EOF'
# Prometheus Stack
resource "helm_release" "kube_prometheus_stack" {
  name             = "kube-prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  namespace        = "monitoring"
  create_namespace = true

  values = [
    yamlencode({
      grafana = {
        enabled = true
        adminPassword = "admin123" # Change this!
        service = {
          type = "LoadBalancer"
        }
      }
      prometheus = {
        prometheusSpec = {
          storageSpec = {
            volumeClaimTemplate = {
              spec = {
                accessModes = ["ReadWriteOnce"]
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

  depends_on = [module.eks]
}
EOF
```

---

## Step 6: GitOps Setup (Optional)

### 6.1 FluxCD Installation
*Following [tofu-controller](https://github.com/flux-iac/tofu-controller) patterns*

```bash
cat > gitops.tf << 'EOF'
# FluxCD Bootstrap
resource "helm_release" "flux2" {
  name             = "flux2"
  repository       = "https://fluxcd-community.github.io/helm-charts"
  chart            = "flux2"
  namespace        = "flux-system"
  create_namespace = true

  depends_on = [module.eks]
}

# Tofu Controller for GitOps Terraform
resource "helm_release" "tofu_controller" {
  name             = "tofu-controller"
  repository       = "https://flux-iac.github.io/tofu-controller/"
  chart            = "tofu-controller"
  namespace        = "flux-system"

  depends_on = [helm_release.flux2]
}
EOF
```

---

## Step 7: Outputs and Testing

### 7.1 Output Configuration
```bash
cat > outputs.tf << 'EOF'
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

output "configure_kubectl" {
  description = "Configure kubectl: make sure you're logged in with the correct AWS profile and run the following command to update your kubeconfig"
  value       = "aws eks --region ${var.aws_region} update-kubeconfig --name ${module.eks.cluster_name}"
}
EOF
```

### 7.2 Deployment Commands
```bash
# Initialize Terraform
terraform init

# Plan the deployment
terraform plan

# Apply the configuration
terraform apply

# Configure kubectl
aws eks --region us-west-2 update-kubeconfig --name my-eks-cluster

# Verify cluster
kubectl get nodes
kubectl get pods --all-namespaces
```

---

## 🧪 Testing Your Deployment

### Basic Cluster Tests
```bash
# Check cluster status
kubectl cluster-info

# Verify nodes
kubectl get nodes -o wide

# Check system pods
kubectl get pods -n kube-system

# Test DNS resolution
kubectl run test-pod --image=busybox --rm -it --restart=Never -- nslookup kubernetes.default
```

### Application Deployment Test
```bash
# Deploy test application
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.21
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  selector:
    app: nginx
  ports:
  - port: 80
    targetPort: 80
  type: LoadBalancer
EOF

# Check deployment
kubectl get deployments
kubectl get services

# Get external IP
kubectl get service nginx-service
```

---

## 🔧 Troubleshooting Common Issues

### Issue 1: Node Group Not Ready
```bash
# Check node status
kubectl describe nodes

# Check node group in AWS console
aws eks describe-nodegroup --cluster-name my-eks-cluster --nodegroup-name main

# Common fixes:
# 1. Check IAM roles and policies
# 2. Verify subnet tags
# 3. Check security groups
```

### Issue 2: Pods Not Scheduling
```bash
# Check pod status
kubectl describe pod <pod-name>

# Check node resources
kubectl top nodes

# Check taints and tolerations
kubectl describe nodes | grep -i taint
```

### Issue 3: Load Balancer Not Working
```bash
# Check AWS Load Balancer Controller
kubectl get pods -n kube-system | grep aws-load-balancer

# Check service annotations
kubectl describe service <service-name>

# Verify IAM roles for service accounts
kubectl describe serviceaccount -n kube-system aws-load-balancer-controller
```

---

## 📚 Next Steps

### Immediate Improvements
1. **Security**: Implement Pod Security Standards
2. **Networking**: Add Network Policies
3. **Storage**: Configure Persistent Volumes
4. **Secrets**: Integrate AWS Secrets Manager

### Advanced Features
1. **Multi-Environment**: Terragrunt for environment management
2. **Service Mesh**: Istio or Linkerd integration
3. **Policy**: Open Policy Agent (OPA) Gatekeeper
4. **Cost**: Implement FinOps practices

### Learning Resources
- [Best Practices Guide](./best-practices.md)
- [Template Examples](./template-examples.md)
- [Troubleshooting Guide](./troubleshooting.md)

---

## 🔗 Reference Projects

This implementation guide combines patterns from:
- [terraform-aws-eks](https://github.com/terraform-aws-modules/terraform-aws-eks) - Foundation
- [eks-blueprints-for-terraform](https://github.com/aws-ia/terraform-aws-eks-blueprints) - Production patterns
- [tofu-controller](https://github.com/flux-iac/tofu-controller) - GitOps integration
- [terraform-kubernetes-monitoring-prometheus](https://github.com/mateothegreat/terraform-kubernetes-monitoring-prometheus) - Monitoring

---

## Navigation
← [Project Categories](./project-categories.md) | → [Best Practices](./best-practices.md) | ↑ [README](./README.md)