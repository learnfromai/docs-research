# Implementation Guide: Terraform with AWS/Kubernetes/EKS

This guide provides step-by-step instructions for implementing the patterns found in production-ready open source projects.

## 🚀 Getting Started

### Prerequisites

Before implementing any of these projects, ensure you have:

**Required Tools:**
```bash
# Install Terraform
brew install terraform  # macOS
# or download from https://terraform.io

# Install AWS CLI
brew install awscli     # macOS
# or download from https://aws.amazon.com/cli/

# Install kubectl
brew install kubectl    # macOS
# or download from https://kubernetes.io/docs/tasks/tools/

# Install Helm (optional but recommended)
brew install helm       # macOS
# or download from https://helm.sh/
```

**AWS Configuration:**
```bash
# Configure AWS credentials
aws configure
# Enter: Access Key ID, Secret Access Key, Region, Output format

# Verify configuration
aws sts get-caller-identity
```

## 📋 Implementation Paths

### Path 1: Official Terraform AWS EKS Module (Recommended for Beginners)

#### Step 1: Basic EKS Cluster Setup

Create a new directory and initialize Terraform:

```bash
mkdir my-eks-cluster && cd my-eks-cluster
terraform init
```

Create `main.tf` with basic EKS configuration:

```hcl
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# Data sources
data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

# VPC Module
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.cluster_name}-vpc"
  cidr = "10.0.0.0/16"

  azs             = slice(data.aws_availability_zones.available.names, 0, 3)
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"           = "1"
  }
}

# EKS Module
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.33"

  vpc_id                         = module.vpc.vpc_id
  subnet_ids                     = module.vpc.private_subnets
  cluster_endpoint_public_access = true

  eks_managed_node_groups = {
    one = {
      name = "node-group-1"

      instance_types = ["t3.small"]

      min_size     = 1
      max_size     = 3
      desired_size = 2
    }
  }
}
```

Create `variables.tf`:

```hcl
variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "my-eks-cluster"
}
```

Create `outputs.tf`:

```hcl
output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ids attached to the cluster control plane"
  value       = module.eks.cluster_security_group_id
}

output "configure_kubectl" {
  description = "Configure kubectl: make sure you're logged in with the correct AWS profile and run the following command to update your kubeconfig"
  value       = "aws eks --region ${var.region} update-kubeconfig --name ${module.eks.cluster_name}"
}
```

#### Step 2: Deploy the Infrastructure

```bash
# Initialize Terraform
terraform init

# Plan the deployment
terraform plan

# Apply the configuration
terraform apply
```

#### Step 3: Configure kubectl

```bash
# Update kubeconfig
aws eks --region us-west-2 update-kubeconfig --name my-eks-cluster

# Verify connection
kubectl get nodes
```

---

### Path 2: Microservices Application (Online Boutique)

#### Step 1: Clone and Setup

```bash
git clone https://github.com/tts1196/online-boutique-eks.git
cd online-boutique-eks
```

#### Step 2: Review Configuration

Examine the Terraform structure:
```bash
ls terraform/
# 01-providers.tf  02-variables.tf  04-vpc.tf  08-eks.tf  ...
```

#### Step 3: Customize Variables

Edit `terraform/02-variables.tf` for your environment:

```hcl
variable "region" {
  description = "AWS region"
  default     = "ap-northeast-1"  # Change to your preferred region
}

variable "cluster_name" {
  description = "EKS cluster name"
  default     = "online-boutique-eks"
}
```

#### Step 4: Deploy Infrastructure

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

#### Step 5: Deploy Application

```bash
# Configure kubectl
aws eks update-kubeconfig --region ap-northeast-1 --name online-boutique-eks

# Make scripts executable
chmod +x scripts/*.sh

# Push images to ECR (optional, uses public images by default)
./scripts/push-images-to-ecr.sh

# Deploy application
./scripts/deploy-app.sh

# Monitor deployment
kubectl get pods -n default
kubectl get svc frontend-external
```

---

### Path 3: Platform Engineering (Kubestack Framework)

#### Step 1: Initialize Kubestack Project

```bash
# Install Kubestack CLI
curl -sL https://raw.githubusercontent.com/kbst/kbst/master/install.sh | bash

# Create new platform
kbst init --platform aws myplatform
cd myplatform
```

#### Step 2: Configure Platform

Edit the configuration files:

```bash
# Review the generated structure
ls -la
# clusters/  environments/  terraform/  kustomize/
```

#### Step 3: Deploy Platform Infrastructure

```bash
# Initialize Terraform workspace
kbst terraform init

# Deploy ops environment
kbst terraform apply --environment ops

# Deploy staging environment  
kbst terraform apply --environment staging

# Deploy production environment
kbst terraform apply --environment production
```

---

### Path 4: Monitoring Stack Implementation

#### Step 1: Clone Monitoring Project

```bash
git clone https://github.com/gurpreet2828/terraform-k8s-monitoring-stack.git
cd terraform-k8s-monitoring-stack
```

#### Step 2: Review and Customize

```bash
# Examine the structure
ls -la
# terraform/  kubernetes/  scripts/

# Customize variables
vim terraform/variables.tf
```

#### Step 3: Deploy Infrastructure and Monitoring

```bash
cd terraform
terraform init
terraform plan
terraform apply

# Deploy Kubernetes monitoring stack
cd ../kubernetes
kubectl apply -f monitoring/
```

#### Step 4: Access Grafana Dashboard

```bash
# Get Grafana service details
kubectl get svc -n monitoring

# Port forward to access locally
kubectl port-forward -n monitoring svc/grafana 3000:3000

# Access: http://localhost:3000
# Default credentials: admin/admin
```

---

## 🔧 Common Configuration Patterns

### 1. Remote State Configuration

Add to your Terraform configuration:

```hcl
terraform {
  backend "s3" {
    bucket         = "my-terraform-state-bucket"
    key            = "eks/terraform.tfstate"
    region         = "us-west-2"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
```

Create the S3 bucket and DynamoDB table:

```bash
# Create S3 bucket
aws s3 mb s3://my-terraform-state-bucket --region us-west-2

# Create DynamoDB table
aws dynamodb create-table \
    --table-name terraform-locks \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
    --region us-west-2
```

### 2. Environment-Specific Configurations

Create different `.tfvars` files for each environment:

**dev.tfvars:**
```hcl
cluster_name = "my-cluster-dev"
region       = "us-west-2"
node_groups = {
  dev = {
    instance_types = ["t3.small"]
    desired_size   = 1
    min_size       = 1
    max_size       = 3
  }
}
```

**prod.tfvars:**
```hcl
cluster_name = "my-cluster-prod"
region       = "us-west-2"
node_groups = {
  prod = {
    instance_types = ["m5.large"]
    desired_size   = 3
    min_size       = 3
    max_size       = 10
  }
}
```

Deploy with environment-specific variables:
```bash
terraform apply -var-file="dev.tfvars"
terraform apply -var-file="prod.tfvars"
```

### 3. Security Best Practices Implementation

#### Enable Encryption
```hcl
module "eks" {
  # ... other configuration

  cluster_encryption_config = {
    provider_key_arn = aws_kms_key.eks.arn
    resources        = ["secrets"]
  }
}

resource "aws_kms_key" "eks" {
  description             = "EKS Secret Encryption Key"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}
```

#### Implement IRSA (IAM Roles for Service Accounts)
```hcl
module "load_balancer_controller_irsa_role" {
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

## 🚨 Common Pitfalls and Solutions

### 1. IAM Permissions Issues

**Problem:** Terraform fails with permission errors
**Solution:** Ensure your AWS user/role has sufficient permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "eks:*",
        "ec2:*",
        "iam:*",
        "cloudformation:*"
      ],
      "Resource": "*"
    }
  ]
}
```

### 2. Node Group Creation Fails

**Problem:** Node groups fail to launch
**Solution:** Check instance types and availability zones:

```hcl
data "aws_ec2_instance_type_offerings" "available" {
  filter {
    name   = "instance-type"
    values = ["t3.small", "t3.medium"]
  }
  location_type = "availability-zone"
}
```

### 3. kubectl Access Issues

**Problem:** Cannot access cluster after creation
**Solution:** Ensure AWS CLI is configured correctly:

```bash
# Check current AWS identity
aws sts get-caller-identity

# Update kubeconfig with correct profile
aws eks --region <region> update-kubeconfig --name <cluster-name> --profile <profile>
```

## 📚 Next Steps

1. **Security Hardening:** Implement network policies and pod security standards
2. **Monitoring:** Add comprehensive monitoring with Prometheus/Grafana
3. **GitOps:** Implement ArgoCD for application deployment
4. **Scaling:** Configure Horizontal Pod Autoscaler and Cluster Autoscaler
5. **Backup:** Implement Velero for cluster backup and disaster recovery

---

## 🔗 Navigation

| Previous | Current | Next |
|----------|---------|------|
| [Comparison Analysis](./comparison-analysis.md) | **Implementation Guide** | [Best Practices](./best-practices.md) |

---

*This implementation guide provides practical steps for deploying production-ready Kubernetes infrastructure using the patterns identified in open source projects.*