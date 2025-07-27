# Implementation Guide: Step-by-Step EKS Deployment

Comprehensive guide for implementing production-ready Terraform AWS EKS infrastructure based on best practices from analyzed open source projects.

## 🚀 Prerequisites

### **Required Tools**
```bash
# Install required CLI tools
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
curl -o aws-iam-authenticator https://amazon-eks.s3.us-west-2.amazonaws.com/1.21.2/2021-07-05/bin/linux/amd64/aws-iam-authenticator
```

### **AWS Configuration**
```bash
# Configure AWS credentials
aws configure
# Verify access
aws sts get-caller-identity
```

### **Environment Setup**
```bash
# Set environment variables
export AWS_REGION=us-west-2
export CLUSTER_NAME=my-eks-cluster
export ENVIRONMENT=production
```

## 📋 Phase 1: Foundation Setup (Week 1-2)

### **1.1 Project Structure Setup**

Create a standard project structure based on best practices from analyzed projects:

```bash
mkdir -p terraform-eks-project/{terraform/{modules,environments/{dev,staging,prod}},kubernetes/{manifests,helm-charts},scripts,docs}

# Project structure
terraform-eks-project/
├── terraform/
│   ├── modules/
│   │   ├── vpc/
│   │   ├── eks/
│   │   └── addons/
│   ├── environments/
│   │   ├── dev/
│   │   ├── staging/
│   │   └── prod/
│   └── shared/
├── kubernetes/
│   ├── manifests/
│   ├── helm-charts/
│   └── gitops/
├── scripts/
└── docs/
```

### **1.2 Terraform State Management**

Set up remote state management following terraform-aws-modules patterns:

```hcl
# terraform/shared/backend.tf
terraform {
  backend "s3" {
    bucket         = "my-terraform-state-bucket"
    key            = "eks/terraform.tfstate"
    region         = "us-west-2"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}

# Create state bucket and DynamoDB table
resource "aws_s3_bucket" "terraform_state" {
  bucket = "my-terraform-state-bucket"
  
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_dynamodb_table" "terraform_locks" {
  name           = "terraform-locks"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}
```

### **1.3 VPC Module Implementation**

Based on terraform-aws-modules/terraform-aws-vpc patterns:

```hcl
# terraform/modules/vpc/main.tf
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs             = var.availability_zones
  private_subnets = var.private_subnet_cidrs
  public_subnets  = var.public_subnet_cidrs

  enable_nat_gateway = true
  enable_vpn_gateway = false
  enable_dns_hostnames = true
  enable_dns_support = true

  # EKS specific tags
  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  tags = var.tags
}

# terraform/modules/vpc/variables.tf
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
  description = "List of availability zones"
  type        = list(string)
  default     = ["us-west-2a", "us-west-2b", "us-west-2c"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}
```

### **1.4 EKS Module Implementation**

Based on terraform-aws-modules/terraform-aws-eks:

```hcl
# terraform/modules/eks/main.tf
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  cluster_endpoint_config = {
    private_access = var.enable_private_access
    public_access  = var.enable_public_access
    public_access_cidrs = var.public_access_cidrs
  }

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

  vpc_id                   = var.vpc_id
  subnet_ids               = var.subnet_ids
  control_plane_subnet_ids = var.control_plane_subnet_ids

  # EKS Managed Node Group(s)
  eks_managed_node_group_defaults = {
    instance_types = ["m6i.large", "m5.large", "m5n.large", "m5zn.large"]
    
    attach_cluster_primary_security_group = true
    vpc_security_group_ids                = [aws_security_group.additional.id]
  }

  eks_managed_node_groups = var.node_groups

  # Fargate Profile(s)
  fargate_profiles = var.fargate_profiles

  # aws-auth configmap
  manage_aws_auth_configmap = true

  aws_auth_roles = var.aws_auth_roles
  aws_auth_users = var.aws_auth_users

  tags = var.tags
}

# Additional security group for worker nodes
resource "aws_security_group" "additional" {
  name_prefix = "${var.cluster_name}-additional"
  vpc_id      = var.vpc_id

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-additional-sg"
    }
  )
}
```

## 📦 Phase 2: Core Services (Week 3-4)

### **2.1 Essential Add-ons Deployment**

Based on aws-ia/terraform-aws-eks-blueprints patterns:

```hcl
# terraform/modules/addons/main.tf
module "eks_blueprints_addons" {
  source = "aws-ia/eks-blueprints-addons/aws"
  version = "~> 1.0"

  cluster_name      = var.cluster_name
  cluster_endpoint  = var.cluster_endpoint
  cluster_version   = var.cluster_version
  oidc_provider_arn = var.oidc_provider_arn

  # Essential add-ons
  eks_addons = {
    aws-ebs-csi-driver = {
      most_recent = true
    }
    aws-efs-csi-driver = {
      most_recent = true
    }
  }

  # AWS Load Balancer Controller
  enable_aws_load_balancer_controller = true
  aws_load_balancer_controller = {
    chart_version = "1.6.0"
  }

  # Cluster Autoscaler
  enable_cluster_autoscaler = true
  cluster_autoscaler = {
    chart_version = "9.29.0"
  }

  # Metrics Server
  enable_metrics_server = true
  metrics_server = {
    chart_version = "3.11.0"
  }

  # External DNS
  enable_external_dns = var.enable_external_dns
  external_dns = {
    chart_version = "1.13.0"
  }

  # Karpenter (if enabled)
  enable_karpenter = var.enable_karpenter
  karpenter = {
    chart_version = "v0.31.0"
  }

  tags = var.tags
}
```

### **2.2 Monitoring Stack Setup**

Following kube-prometheus-stack patterns from analyzed projects:

```yaml
# kubernetes/helm-charts/monitoring/values.yaml
prometheus:
  prometheusSpec:
    retention: 30d
    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: gp3
          resources:
            requests:
              storage: 50Gi

grafana:
  enabled: true
  adminPassword: "secure-password"
  persistence:
    enabled: true
    storageClassName: gp3
    size: 10Gi
  
  dashboardProviders:
    dashboardproviders.yaml:
      apiVersion: 1
      providers:
      - name: 'default'
        orgId: 1
        folder: ''
        type: file
        disableDeletion: false
        editable: true
        options:
          path: /var/lib/grafana/dashboards/default

  datasources:
    datasources.yaml:
      apiVersion: 1
      datasources:
      - name: Prometheus
        type: prometheus
        url: http://prometheus-server:9090
        access: proxy
        isDefault: true

alertmanager:
  enabled: true
  persistence:
    enabled: true
    storageClassName: gp3
    size: 2Gi
```

```bash
# Deploy monitoring stack
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --values kubernetes/helm-charts/monitoring/values.yaml
```

### **2.3 RBAC Configuration**

Based on security patterns from analyzed projects:

```yaml
# kubernetes/manifests/rbac/cluster-roles.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: platform-admin
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["*"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: developer
rules:
- apiGroups: ["", "apps", "extensions"]
  resources: ["pods", "deployments", "services", "configmaps", "secrets"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: [""]
  resources: ["pods/log", "pods/exec"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: read-only
rules:
- apiGroups: ["", "apps", "extensions"]
  resources: ["*"]
  verbs: ["get", "list", "watch"]
```

## 🔒 Phase 3: Production Hardening (Week 5-6)

### **3.1 Network Policies**

Based on security patterns from ViktorUJ/cks and other security-focused projects:

```yaml
# kubernetes/manifests/network-policies/default-deny.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: default
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
  namespace: default
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  - to: []
    ports:
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-monitoring
  namespace: default
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: monitoring
    ports:
    - protocol: TCP
      port: 8080
```

### **3.2 Pod Security Standards**

```yaml
# kubernetes/manifests/security/pod-security-policy.yaml
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
```

### **3.3 Multi-Environment Pipeline**

Based on GitOps patterns from eks-blueprints:

```yaml
# .github/workflows/terraform.yml
name: Terraform CI/CD

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  terraform:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        environment: [dev, staging, prod]
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v2
      with:
        terraform_version: 1.6.0
    
    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v2
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: us-west-2
    
    - name: Terraform Init
      run: |
        cd terraform/environments/${{ matrix.environment }}
        terraform init
    
    - name: Terraform Plan
      run: |
        cd terraform/environments/${{ matrix.environment }}
        terraform plan -no-color
    
    - name: Terraform Apply
      if: github.ref == 'refs/heads/main' && matrix.environment != 'prod'
      run: |
        cd terraform/environments/${{ matrix.environment }}
        terraform apply -auto-approve
```

## 🚀 Phase 4: Advanced Features (Week 7-8)

### **4.1 GitOps with ArgoCD**

Following patterns from eks-blueprints GitOps implementations:

```yaml
# kubernetes/gitops/argocd/application.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: production-apps
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/k8s-manifests
    targetRevision: HEAD
    path: production
  destination:
    server: https://kubernetes.default.svc
    namespace: production
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
```

### **4.2 Karpenter Auto-scaling**

Based on Karpenter patterns from analyzed projects:

```yaml
# kubernetes/manifests/karpenter/provisioner.yaml
apiVersion: karpenter.sh/v1beta1
kind: NodePool
metadata:
  name: default
spec:
  template:
    metadata:
      labels:
        billing-team: my-team
    spec:
      requirements:
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64"]
        - key: kubernetes.io/os
          operator: In
          values: ["linux"]
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["spot", "on-demand"]
        - key: node.kubernetes.io/instance-type
          operator: In
          values: ["m5.large", "m5.xlarge", "c5.large", "c5.xlarge"]
      nodeClassRef:
        apiVersion: karpenter.k8s.aws/v1beta1
        kind: EC2NodeClass
        name: default
      taints:
        - key: example.com/special-taint
          value: "true"
          effect: NoSchedule
  limits:
    cpu: 1000
  disruption:
    consolidationPolicy: WhenUnderutilized
    consolidateAfter: 30s
    expireAfter: 30m
---
apiVersion: karpenter.k8s.aws/v1beta1
kind: EC2NodeClass
metadata:
  name: default
spec:
  amiFamily: AL2
  subnetSelectorTerms:
    - tags:
        karpenter.sh/discovery: "my-cluster"
  securityGroupSelectorTerms:
    - tags:
        karpenter.sh/discovery: "my-cluster"
  userData: |
    #!/bin/bash
    /etc/eks/bootstrap.sh my-cluster
    echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
```

## 🎯 Deployment Commands

### **Complete Deployment Sequence**

```bash
# 1. Initialize and deploy infrastructure
cd terraform/environments/prod
terraform init
terraform plan
terraform apply

# 2. Configure kubectl
aws eks update-kubeconfig --region us-west-2 --name my-eks-cluster

# 3. Deploy core services
kubectl apply -f kubernetes/manifests/rbac/
kubectl apply -f kubernetes/manifests/security/
kubectl apply -f kubernetes/manifests/network-policies/

# 4. Install monitoring
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --values kubernetes/helm-charts/monitoring/values.yaml

# 5. Deploy applications via GitOps
kubectl apply -f kubernetes/gitops/argocd/

# 6. Configure auto-scaling
kubectl apply -f kubernetes/manifests/karpenter/
```

## 📊 Validation and Testing

### **Cluster Health Checks**

```bash
# Verify cluster status
kubectl get nodes
kubectl get pods --all-namespaces

# Check add-ons
kubectl get pods -n kube-system
kubectl get pods -n monitoring

# Test connectivity
kubectl run test-pod --image=nginx --rm -i --tty -- /bin/bash

# Verify monitoring
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
```

---

← [Back to Project Analysis](./project-analysis.md) | **Next**: [Best Practices](./best-practices.md) →