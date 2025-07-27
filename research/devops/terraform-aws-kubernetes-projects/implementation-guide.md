# Implementation Guide: Getting Started with Terraform + AWS + Kubernetes/EKS

## 🚀 Quick Start Paths

Choose your implementation path based on your experience level and requirements:

### **🎯 Path 1: Basic EKS Setup (Beginners)**
**Timeline**: 1-2 days | **Complexity**: Low | **Best for**: Learning, development environments

### **🏗️ Path 2: Production-Ready EKS (Intermediate)**
**Timeline**: 1-2 weeks | **Complexity**: Medium | **Best for**: Small-medium production workloads

### **🏢 Path 3: Enterprise Platform (Advanced)**
**Timeline**: 1-3 months | **Complexity**: High | **Best for**: Large-scale, multi-team environments

---

## 🛠️ Prerequisites & Environment Setup

### **Essential Tools Installation**

```bash
# Install required tools
# Terraform
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update && sudo apt-get install terraform

# AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip && sudo ./aws/install

# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Terragrunt (optional)
wget https://github.com/gruntwork-io/terragrunt/releases/download/v0.50.0/terragrunt_linux_amd64
sudo mv terragrunt_linux_amd64 /usr/local/bin/terragrunt
sudo chmod +x /usr/local/bin/terragrunt
```

### **AWS Configuration**

```bash
# Configure AWS credentials
aws configure
# AWS Access Key ID: [Your Access Key]
# AWS Secret Access Key: [Your Secret Key]
# Default region name: us-west-2
# Default output format: json

# Verify configuration
aws sts get-caller-identity
```

---

## 🎯 Path 1: Basic EKS Setup

### **Step 1: Project Structure Setup**

```bash
mkdir terraform-eks-basic && cd terraform-eks-basic

# Create project structure
mkdir -p {modules/{vpc,eks,addons},environments/dev}
```

### **Step 2: VPC Module**

Create `modules/vpc/main.tf`:

```hcl
# modules/vpc/main.tf
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = var.cluster_name
  cidr = var.vpc_cidr

  azs             = var.availability_zones
  private_subnets = var.private_subnet_cidrs
  public_subnets  = var.public_subnet_cidrs

  enable_nat_gateway = true
  enable_vpn_gateway = false
  single_nat_gateway = true

  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  })

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }
}
```

Create `modules/vpc/variables.tf`:

```hcl
variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
```

### **Step 3: EKS Module**

Create `modules/eks/main.tf`:

```hcl
# modules/eks/main.tf
module "eks" {
  source = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids

  cluster_endpoint_public_access = true
  cluster_endpoint_private_access = true

  # EKS Managed Node Group(s)
  eks_managed_node_group_defaults = {
    instance_types = ["t3.medium"]
    
    attach_cluster_primary_security_group = true
  }

  eks_managed_node_groups = {
    default = {
      min_size     = 1
      max_size     = 3
      desired_size = 2

      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"

      tags = var.tags
    }
  }

  tags = var.tags
}
```

### **Step 4: Main Configuration**

Create `environments/dev/main.tf`:

```hcl
# environments/dev/main.tf
terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket = "your-terraform-state-bucket"
    key    = "eks/dev/terraform.tfstate"
    region = "us-west-2"
  }
}

provider "aws" {
  region = var.aws_region
}

locals {
  cluster_name = "eks-dev"
  region       = "us-west-2"
  
  tags = {
    Environment = "dev"
    Project     = "terraform-eks"
    ManagedBy   = "terraform"
  }
}

# Data sources
data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

# VPC
module "vpc" {
  source = "../../modules/vpc"

  cluster_name        = local.cluster_name
  availability_zones  = slice(data.aws_availability_zones.available.names, 0, 3)
  private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnet_cidrs  = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
  tags                = local.tags
}

# EKS
module "eks" {
  source = "../../modules/eks"

  cluster_name    = local.cluster_name
  cluster_version = "1.27"
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.private_subnets
  tags            = local.tags
}
```

### **Step 5: Deploy the Infrastructure**

```bash
# Initialize Terraform
cd environments/dev
terraform init

# Plan the deployment
terraform plan

# Apply the configuration
terraform apply

# Configure kubectl
aws eks update-kubeconfig --region us-west-2 --name eks-dev

# Verify cluster access
kubectl get nodes
```

---

## 🏗️ Path 2: Production-Ready EKS

### **Enhanced Features for Production**

1. **Advanced Networking**: Multiple AZs, private endpoints
2. **Security**: IAM roles, security groups, network policies
3. **Monitoring**: Prometheus, Grafana, CloudWatch
4. **Logging**: EFK stack integration
5. **Autoscaling**: Cluster and pod autoscaling
6. **Backup**: Velero for cluster backups

### **Step 1: Enhanced Project Structure**

```bash
mkdir terraform-eks-production && cd terraform-eks-production

# Create comprehensive structure
mkdir -p {
  modules/{vpc,eks,addons,monitoring,security},
  environments/{dev,staging,prod},
  helm-charts,
  manifests/{namespaces,rbac,policies}
}
```

### **Step 2: Production EKS Module**

Create `modules/eks/main.tf` with enhanced configuration:

```hcl
# modules/eks/main.tf - Production version
module "eks" {
  source = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids

  # Enhanced security
  cluster_endpoint_public_access  = var.enable_public_access
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access_cidrs = var.public_access_cidrs

  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  # IRSA
  enable_irsa = true

  # EKS Managed Node Groups
  eks_managed_node_group_defaults = {
    instance_types = var.default_instance_types
    
    attach_cluster_primary_security_group = true
    vpc_security_group_ids = [aws_security_group.node_group_additional.id]

    # Launch template
    create_launch_template = true
    launch_template_name   = "${var.cluster_name}-node-group"

    # Remote access
    remote_access = {
      ec2_ssh_key = var.ssh_key_name
      source_security_group_ids = [aws_security_group.remote_access.id]
    }

    # Block device mappings
    block_device_mappings = {
      xvda = {
        device_name = "/dev/xvda"
        ebs = {
          volume_size           = 100
          volume_type           = "gp3"
          iops                  = 3000
          throughput            = 150
          encrypted             = true
          delete_on_termination = true
        }
      }
    }
  }

  eks_managed_node_groups = var.node_groups

  # aws-auth configmap
  manage_aws_auth_configmap = true

  aws_auth_roles = var.aws_auth_roles
  aws_auth_users = var.aws_auth_users

  tags = var.tags
}

# Additional security groups
resource "aws_security_group" "node_group_additional" {
  name_prefix = "${var.cluster_name}-node-additional"
  vpc_id      = var.vpc_id

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-node-additional"
  })
}

resource "aws_security_group" "remote_access" {
  name_prefix = "${var.cluster_name}-remote-access"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-remote-access"
  })
}
```

### **Step 3: Addons Module**

Create `modules/addons/main.tf`:

```hcl
# modules/addons/main.tf
# AWS Load Balancer Controller
resource "aws_iam_role" "aws_load_balancer_controller" {
  name = "${var.cluster_name}-aws-load-balancer-controller"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Condition = {
          StringEquals = {
            "${replace(var.oidc_provider_arn, "/^arn:aws:iam::\\d+:oidc-provider\\//", "")}:sub": "system:serviceaccount:kube-system:aws-load-balancer-controller"
            "${replace(var.oidc_provider_arn, "/^arn:aws:iam::\\d+:oidc-provider\\//", "")}:aud": "sts.amazonaws.com"
          }
        }
        Principal = {
          Federated = var.oidc_provider_arn
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller" {
  policy_arn = "arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess"
  role       = aws_iam_role.aws_load_balancer_controller.name
}

# Helm releases
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
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.aws_load_balancer_controller.arn
  }

  depends_on = [var.node_groups]
}

# Cluster Autoscaler
resource "helm_release" "cluster_autoscaler" {
  name       = "cluster-autoscaler"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  namespace  = "kube-system"
  version    = "9.29.0"

  set {
    name  = "autoDiscovery.clusterName"
    value = var.cluster_name
  }

  set {
    name  = "awsRegion"
    value = var.aws_region
  }

  depends_on = [var.node_groups]
}

# Metrics Server
resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  namespace  = "kube-system"
  version    = "3.11.0"

  depends_on = [var.node_groups]
}
```

### **Step 4: Monitoring Setup**

Create `modules/monitoring/main.tf`:

```hcl
# modules/monitoring/main.tf
# Prometheus Stack
resource "helm_release" "prometheus" {
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = "monitoring"
  version    = "51.2.0"

  create_namespace = true

  values = [
    file("${path.module}/values/prometheus-values.yaml")
  ]

  depends_on = [var.node_groups]
}

# Grafana configuration
resource "kubernetes_config_map" "grafana_dashboards" {
  metadata {
    name      = "custom-dashboards"
    namespace = "monitoring"
    labels = {
      grafana_dashboard = "1"
    }
  }

  data = {
    "eks-cluster-overview.json" = file("${path.module}/dashboards/eks-cluster-overview.json")
    "node-exporter-full.json"   = file("${path.module}/dashboards/node-exporter-full.json")
  }

  depends_on = [helm_release.prometheus]
}
```

### **Step 5: Production Deployment**

```bash
# Navigate to production environment
cd environments/prod

# Initialize with backend configuration
terraform init \
  -backend-config="bucket=your-prod-terraform-state" \
  -backend-config="key=eks/prod/terraform.tfstate" \
  -backend-config="region=us-west-2"

# Plan with production variables
terraform plan -var-file="prod.tfvars"

# Apply with approval
terraform apply -var-file="prod.tfvars"

# Configure kubectl for production
aws eks update-kubeconfig --region us-west-2 --name eks-prod --profile production

# Verify deployment
kubectl get nodes -o wide
kubectl get pods -A
```

---

## 🏢 Path 3: Enterprise Platform

### **Terragrunt Implementation**

For enterprise-scale deployments, use Terragrunt for DRY configuration management:

### **Step 1: Terragrunt Project Structure**

```bash
mkdir terragrunt-enterprise-platform && cd terragrunt-enterprise-platform

# Create Terragrunt structure
mkdir -p {
  environments/{dev,staging,prod}/{us-west-2,us-east-1},
  modules/{vpc,eks,addons,monitoring,security},
  terragrunt.hcl
}
```

### **Step 2: Root Terragrunt Configuration**

Create `terragrunt.hcl`:

```hcl
# terragrunt.hcl
locals {
  # Extract environment and region from path
  path_vars = regex("environments/(?P<environment>[^/]+)/(?P<region>[^/]+)", get_terragrunt_dir())
  environment = local.path_vars.environment
  region = local.path_vars.region

  # Common variables
  common_vars = yamldecode(file("${get_terragrunt_dir()}/common.yaml"))
  env_vars = yamldecode(file("${get_terragrunt_dir()}/environments/${local.environment}/env.yaml"))
  region_vars = yamldecode(file("${get_terragrunt_dir()}/environments/${local.environment}/${local.region}/region.yaml"))
}

# Remote state configuration
remote_state {
  backend = "s3"
  config = {
    bucket         = "terraform-state-${local.common_vars.company}-${local.environment}"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = local.region
    encrypt        = true
    dynamodb_table = "terraform-locks-${local.environment}"
  }
}

# Provider configuration
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
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
  }
}

provider "aws" {
  region = "${local.region}"
  
  default_tags {
    tags = {
      Environment   = "${local.environment}"
      Region        = "${local.region}"
      ManagedBy     = "terragrunt"
      Project       = "${local.common_vars.project_name}"
    }
  }
}
EOF
}

# Input variables
inputs = merge(
  local.common_vars,
  local.env_vars,
  local.region_vars,
  {
    environment = local.environment
    region      = local.region
  }
)
```

### **Step 3: Environment-Specific EKS Configuration**

Create `environments/prod/us-west-2/eks/terragrunt.hcl`:

```hcl
# environments/prod/us-west-2/eks/terragrunt.hcl
include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../modules/eks"
}

dependency "vpc" {
  config_path = "../vpc"
  
  mock_outputs = {
    vpc_id          = "vpc-12345678"
    private_subnets = ["subnet-12345", "subnet-67890"]
    vpc_cidr_block  = "10.0.0.0/16"
  }
}

inputs = {
  cluster_name    = "eks-prod-us-west-2"
  cluster_version = "1.27"
  
  vpc_id     = dependency.vpc.outputs.vpc_id
  subnet_ids = dependency.vpc.outputs.private_subnets
  vpc_cidr   = dependency.vpc.outputs.vpc_cidr_block
  
  # Production node groups
  node_groups = {
    general = {
      instance_types = ["t3.large"]
      min_size       = 3
      max_size       = 10
      desired_size   = 6
      capacity_type  = "ON_DEMAND"
      
      labels = {
        role = "general"
      }
      
      taints = []
    }
    
    compute = {
      instance_types = ["c5.xlarge"]
      min_size       = 1
      max_size       = 5
      desired_size   = 2
      capacity_type  = "SPOT"
      
      labels = {
        role = "compute-intensive"
      }
      
      taints = [
        {
          key    = "compute-intensive"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      ]
    }
  }
  
  # Security configuration
  enable_public_access = false
  public_access_cidrs  = []
  
  # AWS auth configuration
  aws_auth_roles = [
    {
      rolearn  = "arn:aws:iam::ACCOUNT_ID:role/EKSAdminRole"
      username = "eks-admin"
      groups   = ["system:masters"]
    }
  ]
}
```

### **Step 4: Deploy Enterprise Platform**

```bash
# Deploy VPC
cd environments/prod/us-west-2/vpc
terragrunt apply

# Deploy EKS cluster
cd ../eks
terragrunt apply

# Deploy addons
cd ../addons
terragrunt apply

# Deploy monitoring
cd ../monitoring
terragrunt apply

# Verify entire stack
terragrunt run-all plan --terragrunt-working-dir=environments/prod/us-west-2
```

---

## 🔧 Common Troubleshooting

### **EKS Access Issues**
```bash
# Update kubeconfig
aws eks update-kubeconfig --region <region> --name <cluster-name>

# Check AWS CLI configuration
aws sts get-caller-identity

# Verify aws-auth ConfigMap
kubectl get configmap aws-auth -n kube-system -o yaml
```

### **Node Group Issues**
```bash
# Check node group status
aws eks describe-nodegroup --cluster-name <cluster> --nodegroup-name <nodegroup>

# Check node readiness
kubectl get nodes -o wide

# Check node group events
kubectl describe nodes
```

### **Networking Issues**
```bash
# Check VPC and subnet configuration
aws ec2 describe-vpcs
aws ec2 describe-subnets

# Test pod connectivity
kubectl run test-pod --image=nginx --restart=Never
kubectl exec -it test-pod -- wget -qO- http://kubernetes.default.svc.cluster.local
```

---

## 📖 Navigation

- **[← Back to Executive Summary](./executive-summary.md)**
- **[Next: Best Practices →](./best-practices.md)**

---

*Last Updated: July 26, 2025*