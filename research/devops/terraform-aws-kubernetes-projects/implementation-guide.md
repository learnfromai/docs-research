# Implementation Guide

Complete step-by-step guide for implementing and deploying the analyzed open source DevOps projects using Terraform with AWS and Kubernetes/EKS.

## 🚀 Getting Started

### Prerequisites

**Required Tools**
```bash
# Terraform (version 1.5+)
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update && sudo apt-get install terraform

# AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Helm (for add-ons management)
curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update && sudo apt-get install helm
```

**AWS Setup**
```bash
# Configure AWS CLI
aws configure
# Enter your Access Key ID, Secret Access Key, Region, and Output format

# Verify configuration
aws sts get-caller-identity
```

### Environment Preparation

**1. Create Working Directory**
```bash
mkdir -p ~/terraform-eks-projects
cd ~/terraform-eks-projects
```

**2. Set Environment Variables**
```bash
export AWS_REGION="us-west-2"
export CLUSTER_NAME="my-eks-cluster"
export PROJECT_NAME="terraform-eks-demo"
```

## 📋 Implementation Paths

### Path 1: Starting with terraform-aws-modules/terraform-aws-eks

**Step 1: Basic EKS Cluster Setup**
```bash
# Clone the reference repository
git clone https://github.com/terraform-aws-modules/terraform-aws-eks.git
cd terraform-aws-eks/examples/eks-managed-node-group

# Create your own configuration
cat > main.tf << 'EOF'
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = var.cluster_name
  kubernetes_version = "1.33"

  # VPC Configuration
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Enable public endpoint for learning (disable in production)
  endpoint_public_access = true

  # Add current user as admin
  enable_cluster_creator_admin_permissions = true

  # EKS Managed Node Group
  eks_managed_node_groups = {
    example = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = ["m5.large"]
      
      min_size     = 1
      max_size     = 3
      desired_size = 2
    }
  }

  tags = {
    Environment = "learning"
    Project     = var.project_name
    Terraform   = "true"
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.cluster_name}-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["${var.aws_region}a", "${var.aws_region}b", "${var.aws_region}c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true
  enable_vpn_gateway = true
  
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

  tags = {
    Environment = "learning"
    Project     = var.project_name
    Terraform   = "true"
  }
}
EOF

# Create variables file
cat > variables.tf << 'EOF'
variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "my-eks-cluster"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "terraform-eks-demo"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}
EOF

# Create outputs file
cat > outputs.tf << 'EOF'
output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ids attached to the cluster control plane"
  value       = module.eks.cluster_security_group_id
}

output "cluster_iam_role_name" {
  description = "IAM role name associated with EKS cluster"
  value       = module.eks.cluster_iam_role_name
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.eks.cluster_certificate_authority_data
}

output "cluster_name" {
  description = "The name of the EKS cluster"
  value       = module.eks.cluster_name
}
EOF

# Initialize and deploy
terraform init
terraform plan
terraform apply -auto-approve
```

**Step 2: Configure kubectl**
```bash
# Update kubeconfig
aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME

# Verify connection
kubectl get nodes
kubectl get pods -A
```

### Path 2: Using AWS EKS Blueprints

**Step 1: Clone and Setup**
```bash
cd ~/terraform-eks-projects
git clone https://github.com/aws-ia/terraform-aws-eks-blueprints.git
cd terraform-aws-eks-blueprints/examples/getting-started

# Customize the example
cp terraform.tfvars.example terraform.tfvars
```

**Step 2: Configure Variables**
```bash
cat > terraform.tfvars << EOF
name               = "eks-blueprints-demo"
kubernetes_version = "1.33"

# VPC Configuration
vpc_cidr = "10.0.0.0/16"
azs      = ["${AWS_REGION}a", "${AWS_REGION}b", "${AWS_REGION}c"]

# Node Groups
eks_managed_node_groups = {
  initial = {
    node_group_name = "managed-ondemand"
    instance_types  = ["m5.large"]
    
    min_size     = 1
    max_size     = 5
    desired_size = 2
    
    ami_type = "AL2_x86_64"
    capacity_type = "ON_DEMAND"
  }
}

# Enable add-ons
enable_aws_load_balancer_controller = true
enable_metrics_server              = true
enable_cluster_autoscaler          = true
enable_aws_efs_csi_driver          = true
enable_aws_ebs_csi_driver          = true

tags = {
  Environment = "learning"
  Blueprint   = "eks-blueprints"
}
EOF

# Deploy
terraform init
terraform apply -auto-approve
```

### Path 3: Learning with stacksimplify Demos

**Step 1: Clone Repository**
```bash
cd ~/terraform-eks-projects
git clone https://github.com/stacksimplify/terraform-on-aws-eks.git
cd terraform-on-aws-eks
```

**Step 2: Start with Basic Examples**
```bash
# Begin with VPC creation
cd 01-ekscluster-terraform-manifests

# Follow the README for each demo
ls -la  # Review available demos

# Start with basic cluster
cd 02-k8sresources-terraform-manifests
terraform init
terraform plan
terraform apply -auto-approve
```

### Path 4: Production-Ready with maddevsio/aws-eks-base

**Step 1: Clone and Configure**
```bash
cd ~/terraform-eks-projects
git clone https://github.com/maddevsio/aws-eks-base.git
cd aws-eks-base

# Copy and customize configuration
cp terraform.tfvars.example terraform.tfvars
```

**Step 2: Environment Configuration**
```bash
cat > terraform.tfvars << EOF
region     = "us-west-2"
azs        = ["us-west-2a", "us-west-2b", "us-west-2c"]

name            = "maddevs-demo"
environment     = "learning"
project         = "eks-demo"

# Cluster Configuration
cluster_version = "1.33"

# Network Configuration  
cidr            = "10.0.0.0/16"
private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

# Node Groups
instance_types = ["t3.medium"]
min_size      = 1
max_size      = 3
desired_size  = 2

# Security
create_aws_auth_configmap = true
manage_aws_auth_configmap = true

tags = {
  Environment = "learning"
  ManagedBy   = "terraform"
}
EOF

# Deploy infrastructure
terraform init
terraform plan
terraform apply -auto-approve
```

## 🔧 Essential Operations

### Cluster Management

**Connect to Cluster**
```bash
# Update kubeconfig for any cluster
aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME

# Verify connection
kubectl cluster-info
kubectl get nodes -o wide
```

**Install Essential Tools**
```bash
# Install AWS Load Balancer Controller
helm repo add eks https://aws.github.io/eks-charts
helm repo update

kubectl apply -k "github.com/aws/eks-charts/stable/aws-load-balancer-controller//crds?ref=master"

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=$CLUSTER_NAME \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller

# Install Metrics Server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Install Cluster Autoscaler
kubectl apply -f https://raw.githubusercontent.com/kubernetes/autoscaler/master/cluster-autoscaler/cloudprovider/aws/examples/cluster-autoscaler-autodiscover.yaml

# Patch cluster autoscaler
kubectl patch deployment cluster-autoscaler \
  -n kube-system \
  -p '{"spec":{"template":{"metadata":{"annotations":{"cluster-autoscaler.kubernetes.io/safe-to-evict":"false"}}}}}'
```

### Application Deployment

**Deploy Sample Application**
```bash
# Create namespace
kubectl create namespace demo-app

# Deploy sample application
cat > sample-app.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  namespace: demo-app
spec:
  replicas: 3
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
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 200m
            memory: 256Mi

---
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
  namespace: demo-app
spec:
  selector:
    app: nginx
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
  type: LoadBalancer

---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx-ingress
  namespace: demo-app
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
spec:
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: nginx-service
            port:
              number: 80
EOF

kubectl apply -f sample-app.yaml

# Check deployment
kubectl get pods -n demo-app
kubectl get service -n demo-app
kubectl get ingress -n demo-app
```

### Monitoring and Observability

**Deploy Prometheus and Grafana**
```bash
# Add Helm repositories
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Install Prometheus
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.storageClassName=gp2 \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.accessModes[0]=ReadWriteOnce \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=10Gi

# Get Grafana admin password
kubectl get secret --namespace monitoring prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo

# Port forward to access Grafana
kubectl port-forward --namespace monitoring svc/prometheus-grafana 3000:80
```

## 🧹 Cleanup

**Destroy Resources**
```bash
# For any Terraform project
terraform destroy -auto-approve

# Clean up kubeconfig entries
kubectl config get-contexts
kubectl config delete-context <context-name>

# Remove kubectl configurations
kubectl config unset clusters.<cluster-name>
kubectl config unset contexts.<context-name>
kubectl config unset users.<user-name>
```

## 🔍 Troubleshooting

**Common Issues and Solutions**

**1. Authentication Issues**
```bash
# Update kubeconfig
aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME

# Check AWS credentials
aws sts get-caller-identity

# Verify IAM permissions
aws iam get-user
```

**2. Node Group Issues**
```bash
# Check node group status
aws eks describe-nodegroup --cluster-name $CLUSTER_NAME --nodegroup-name <nodegroup-name>

# Check node health
kubectl get nodes -o wide
kubectl describe node <node-name>
```

**3. Pod Scheduling Issues**
```bash
# Check node resources
kubectl top nodes
kubectl describe node <node-name>

# Check pod events
kubectl describe pod <pod-name> -n <namespace>
kubectl get events --sort-by=.metadata.creationTimestamp
```

## 🔗 Navigation

**Previous**: [← Executive Summary](./executive-summary.md) | **Next**: [Best Practices →](./best-practices.md)