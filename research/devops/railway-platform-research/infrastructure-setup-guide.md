# Infrastructure Setup Guide - Railway.com Platform Development

## 🏗️ Production-Ready Infrastructure Setup

This guide provides step-by-step instructions for setting up the cloud infrastructure required to build a Railway.com-like Platform-as-a-Service (PaaS).

## 🛠️ Prerequisites

### Required Tools
```bash
# Install required CLI tools
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install Terraform
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
unzip terraform_1.6.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/

# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

## ☁️ Cloud Provider Setup

### AWS Infrastructure with Terraform

**Directory Structure:**
```
infrastructure/
├── terraform/
│   ├── environments/
│   │   ├── dev/
│   │   ├── staging/
│   │   └── production/
│   ├── modules/
│   │   ├── vpc/
│   │   ├── eks/
│   │   ├── rds/
│   │   └── monitoring/
│   └── shared/
└── k8s-manifests/
    ├── system/
    ├── monitoring/
    └── applications/
```

**Main Infrastructure Configuration:**
```hcl
# infrastructure/terraform/environments/production/main.tf
terraform {
  required_version = ">= 1.6"
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
  
  backend "s3" {
    bucket = "railway-terraform-state"
    key    = "production/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Environment = "production"
      Project     = "railway-platform"
      ManagedBy   = "terraform"
    }
  }
}

# VPC Module
module "vpc" {
  source = "../../modules/vpc"
  
  name_prefix        = "railway-prod"
  cidr_block        = "10.0.0.0/16"
  availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
  
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnets = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
  database_subnets = ["10.0.21.0/24", "10.0.22.0/24", "10.0.23.0/24"]
  
  enable_nat_gateway = true
  enable_dns_hostnames = true
  enable_dns_support = true
}

# EKS Cluster
module "eks" {
  source = "../../modules/eks"
  
  cluster_name    = "railway-production"
  cluster_version = "1.28"
  
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.private_subnets
  
  node_groups = {
    general = {
      instance_types = ["m5.large", "m5.xlarge"]
      capacity_type  = "ON_DEMAND"
      min_size      = 3
      max_size      = 20
      desired_size  = 5
      
      labels = {
        role = "general"
      }
      
      taints = []
    }
    
    spot = {
      instance_types = ["m5.large", "m5.xlarge", "m4.large"]
      capacity_type  = "SPOT"
      min_size      = 0
      max_size      = 10
      desired_size  = 2
      
      labels = {
        role = "spot"
      }
      
      taints = [
        {
          key    = "spot-instance"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      ]
    }
  }
  
  enable_irsa = true
  enable_cluster_autoscaler = true
  enable_aws_load_balancer_controller = true
}

# RDS Database
module "rds" {
  source = "../../modules/rds"
  
  identifier = "railway-production"
  
  engine         = "postgres"
  engine_version = "15.4"
  instance_class = "db.r5.large"
  
  allocated_storage     = 100
  max_allocated_storage = 1000
  storage_encrypted     = true
  
  database_name = "railway_platform"
  username      = "railway_admin"
  
  vpc_id               = module.vpc.vpc_id
  subnet_ids          = module.vpc.database_subnets
  vpc_security_groups = [module.vpc.database_security_group_id]
  
  backup_retention_period = 30
  backup_window          = "03:00-04:00"
  maintenance_window     = "Sun:04:00-Sun:05:00"
  
  enabled_cloudwatch_logs_exports = ["postgresql"]
  monitoring_interval             = 60
  
  deletion_protection = true
  skip_final_snapshot = false
  
  tags = {
    Name = "railway-production-database"
  }
}

# ElastiCache Redis
resource "aws_elasticache_subnet_group" "redis" {
  name       = "railway-redis-subnet-group"
  subnet_ids = module.vpc.private_subnets
}

resource "aws_elasticache_replication_group" "redis" {
  description         = "Railway Platform Redis Cluster"
  replication_group_id = "railway-redis"
  
  port = 6379
  parameter_group_name = "default.redis7"
  
  num_cache_clusters = 3
  node_type         = "cache.r6g.large"
  
  subnet_group_name  = aws_elasticache_subnet_group.redis.name
  security_group_ids = [module.vpc.redis_security_group_id]
  
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  
  automatic_failover_enabled = true
  multi_az_enabled          = true
  
  snapshot_retention_limit = 7
  snapshot_window         = "03:00-05:00"
  
  tags = {
    Name = "railway-production-redis"
  }
}
```

## 🔧 Kubernetes System Setup

### Core System Components

**1. NGINX Ingress Controller:**
```yaml
# k8s-manifests/system/nginx-ingress.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: ingress-nginx
---
apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  name: ingress-nginx
  namespace: kube-system
spec:
  chart: ingress-nginx
  repo: https://kubernetes.github.io/ingress-nginx
  targetNamespace: ingress-nginx
  valuesContent: |-
    controller:
      replicaCount: 3
      
      service:
        type: LoadBalancer
        annotations:
          service.beta.kubernetes.io/aws-load-balancer-type: nlb
          service.beta.kubernetes.io/aws-load-balancer-backend-protocol: tcp
          service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: "true"
      
      config:
        proxy-buffer-size: "16k"
        proxy-body-size: "100m"
        server-name-hash-bucket-size: "256"
        use-forwarded-headers: "true"
        compute-full-forwarded-for: "true"
        use-proxy-protocol: "false"
      
      metrics:
        enabled: true
        serviceMonitor:
          enabled: true
      
      resources:
        requests:
          cpu: 200m
          memory: 256Mi
        limits:
          cpu: 500m
          memory: 512Mi
      
      nodeSelector:
        role: general
      
      tolerations:
      - key: "spot-instance"
        operator: "Equal"
        value: "true"
        effect: "NoSchedule"
```

**2. Cert-Manager for SSL:**
```yaml
# k8s-manifests/system/cert-manager.yaml
apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  name: cert-manager
  namespace: kube-system
spec:
  chart: cert-manager
  repo: https://charts.jetstack.io
  targetNamespace: cert-manager
  createNamespace: true
  valuesContent: |-
    installCRDs: true
    
    prometheus:
      enabled: true
      servicemonitor:
        enabled: true
    
    webhook:
      replicaCount: 2
    
    cainjector:
      replicaCount: 2
    
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
      limits:
        cpu: 200m
        memory: 256Mi

---
# ClusterIssuer for Let's Encrypt
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@railway.app
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: admin@railway.app
    privateKeySecretRef:
      name: letsencrypt-staging
    solvers:
    - http01:
        ingress:
          class: nginx
```

**3. External DNS:**
```yaml
# k8s-manifests/system/external-dns.yaml
apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  name: external-dns
  namespace: kube-system
spec:
  chart: external-dns
  repo: https://kubernetes-sigs.github.io/external-dns/
  targetNamespace: external-dns
  createNamespace: true
  valuesContent: |-
    provider: aws
    
    aws:
      region: us-east-1
      zoneType: public
    
    domainFilters:
    - railway.app
    
    policy: sync
    
    txtOwnerId: railway-production
    txtPrefix: external-dns-
    
    logLevel: info
    logFormat: json
    
    sources:
    - ingress
    - service
    
    serviceMonitor:
      enabled: true
    
    resources:
      requests:
        cpu: 50m
        memory: 64Mi
      limits:
        cpu: 100m
        memory: 128Mi
```

## 📊 Monitoring Stack Setup

### Prometheus & Grafana

**Prometheus Configuration:**
```yaml
# k8s-manifests/monitoring/prometheus.yaml
apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  name: kube-prometheus-stack
  namespace: kube-system
spec:
  chart: kube-prometheus-stack
  repo: https://prometheus-community.github.io/helm-charts
  targetNamespace: monitoring
  createNamespace: true
  valuesContent: |-
    prometheus:
      prometheusSpec:
        retention: 30d
        retentionSize: 50GB
        
        storageSpec:
          volumeClaimTemplate:
            spec:
              storageClassName: gp3
              accessModes: ["ReadWriteOnce"]
              resources:
                requests:
                  storage: 100Gi
        
        resources:
          requests:
            cpu: 500m
            memory: 2Gi
          limits:
            cpu: 1000m
            memory: 4Gi
        
        nodeSelector:
          role: general
    
    grafana:
      enabled: true
      
      adminPassword: "secure-admin-password"
      
      persistence:
        enabled: true
        size: 10Gi
        storageClassName: gp3
      
      ingress:
        enabled: true
        annotations:
          kubernetes.io/ingress.class: nginx
          cert-manager.io/cluster-issuer: letsencrypt-prod
        hosts:
        - monitoring.railway.app
        tls:
        - secretName: grafana-tls
          hosts:
          - monitoring.railway.app
      
      resources:
        requests:
          cpu: 200m
          memory: 256Mi
        limits:
          cpu: 500m
          memory: 512Mi
    
    alertmanager:
      alertmanagerSpec:
        storage:
          volumeClaimTemplate:
            spec:
              storageClassName: gp3
              accessModes: ["ReadWriteOnce"]
              resources:
                requests:
                  storage: 10Gi
        
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 200m
            memory: 256Mi
```

### Application Monitoring

**Custom ServiceMonitor for Railway API:**
```yaml
# k8s-manifests/monitoring/railway-servicemonitor.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: railway-api
  namespace: monitoring
  labels:
    app: railway-api
spec:
  selector:
    matchLabels:
      app: railway-api
  endpoints:
  - port: metrics
    path: /metrics
    interval: 30s
    scrapeTimeout: 10s
  namespaceSelector:
    matchNames:
    - railway-system
```

## 🔐 Security Setup

### Network Policies

**Default Deny All:**
```yaml
# k8s-manifests/system/network-policies.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: railway-system
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
---
# Allow ingress traffic to API
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-api-ingress
  namespace: railway-system
spec:
  podSelector:
    matchLabels:
      app: railway-api
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
    ports:
    - protocol: TCP
      port: 8080
---
# Allow API to database
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-api-database
  namespace: railway-system
spec:
  podSelector:
    matchLabels:
      app: railway-api
  policyTypes:
  - Egress
  egress:
  - to: []
    ports:
    - protocol: TCP
      port: 5432  # PostgreSQL
    - protocol: TCP
      port: 6379  # Redis
  - to: []
    ports:
    - protocol: TCP
      port: 53   # DNS
    - protocol: UDP
      port: 53   # DNS
    - protocol: TCP
      port: 443  # HTTPS
```

### Pod Security Standards

**Pod Security Policy:**
```yaml
# k8s-manifests/system/pod-security.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: railway-system
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
---
apiVersion: v1
kind: Namespace
metadata:
  name: user-workloads
  labels:
    pod-security.kubernetes.io/enforce: baseline
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

## 🚀 Container Registry Setup

### AWS ECR Configuration

```hcl
# infrastructure/terraform/modules/ecr/main.tf
resource "aws_ecr_repository" "railway_images" {
  name                 = "railway/platform"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  lifecycle_policy {
    policy = jsonencode({
      rules = [
        {
          rulePriority = 1
          description  = "Keep last 30 tagged images"
          selection = {
            tagStatus     = "tagged"
            tagPrefixList = ["v"]
            countType     = "imageCountMoreThan"
            countNumber   = 30
          }
          action = {
            type = "expire"
          }
        },
        {
          rulePriority = 2
          description  = "Keep last 5 untagged images"
          selection = {
            tagStatus   = "untagged"
            countType   = "imageCountMoreThan"
            countNumber = 5
          }
          action = {
            type = "expire"
          }
        }
      ]
    })
  }

  tags = {
    Name = "railway-platform-images"
  }
}

# ECR IAM policy for EKS nodes
resource "aws_iam_role_policy" "ecr_read_policy" {
  name = "ECRReadPolicy"
  role = var.eks_node_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      }
    ]
  })
}
```

## 🔧 Build Pipeline Infrastructure

### Tekton Pipelines Setup

```yaml
# k8s-manifests/system/tekton.yaml
apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  name: tekton-pipelines
  namespace: kube-system
spec:
  chart: tekton-pipeline
  repo: https://cdfoundation.github.io/tekton-helm-chart
  targetNamespace: tekton-pipelines
  createNamespace: true
  valuesContent: |-
    controller:
      replicas: 2
      resources:
        requests:
          cpu: 200m
          memory: 256Mi
        limits:
          cpu: 500m
          memory: 512Mi
    
    webhook:
      replicas: 2
      resources:
        requests:
          cpu: 100m
          memory: 128Mi
        limits:
          cpu: 200m
          memory: 256Mi
```

### CI/CD Service Account

```yaml
# k8s-manifests/system/cicd-rbac.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: railway-builder
  namespace: railway-system
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT-ID:role/railway-builder-role
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: railway-builder
rules:
- apiGroups: [""]
  resources: ["pods", "services", "configmaps", "secrets"]
  verbs: ["get", "list", "create", "update", "patch", "delete"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "create", "update", "patch", "delete"]
- apiGroups: ["networking.k8s.io"]
  resources: ["ingresses"]
  verbs: ["get", "list", "create", "update", "patch", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: railway-builder
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: railway-builder
subjects:
- kind: ServiceAccount
  name: railway-builder
  namespace: railway-system
```

## 📋 Deployment Checklist

### Pre-Deployment Verification

```bash
#!/bin/bash
# deployment-checklist.sh

echo "🔍 Pre-deployment verification checklist"

# Check AWS credentials
echo "✅ Checking AWS credentials..."
aws sts get-caller-identity || exit 1

# Check Terraform state
echo "✅ Checking Terraform state..."
cd infrastructure/terraform/environments/production
terraform plan -detailed-exitcode || exit 1

# Check Kubernetes connectivity
echo "✅ Checking Kubernetes connectivity..."
kubectl cluster-info || exit 1

# Check required namespaces
echo "✅ Checking required namespaces..."
kubectl get namespace railway-system monitoring ingress-nginx cert-manager || exit 1

# Check ingress controller
echo "✅ Checking ingress controller..."
kubectl get pods -n ingress-nginx -l app.kubernetes.io/component=controller || exit 1

# Check cert-manager
echo "✅ Checking cert-manager..."
kubectl get pods -n cert-manager || exit 1

# Check monitoring stack
echo "✅ Checking monitoring stack..."
kubectl get pods -n monitoring || exit 1

echo "🎉 All checks passed! Ready for deployment."
```

### Post-Deployment Verification

```bash
#!/bin/bash
# post-deployment-verification.sh

echo "🔍 Post-deployment verification"

# Check all pods are running
echo "✅ Checking pod status..."
kubectl get pods --all-namespaces --field-selector=status.phase!=Running,status.phase!=Succeeded

# Check ingress endpoints
echo "✅ Checking ingress endpoints..."
kubectl get ingress --all-namespaces

# Test API health
echo "✅ Testing API health..."
curl -f https://api.railway.app/health || echo "❌ API health check failed"

# Test database connectivity
echo "✅ Testing database connectivity..."
kubectl exec -n railway-system deploy/railway-api -- pg_isready -h $DATABASE_HOST

# Check monitoring
echo "✅ Testing monitoring endpoints..."
curl -f https://monitoring.railway.app || echo "❌ Monitoring not accessible"

echo "🎉 Post-deployment verification complete!"
```

---

## 🔗 Navigation

← [Back to Implementation Roadmap](./implementation-roadmap.md) | [Next: Security Implementation →](./security-implementation.md)

## 📚 Infrastructure References

1. [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
2. [Kubernetes Production Best Practices](https://kubernetes.io/docs/setup/best-practices/)
3. [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
4. [NGINX Ingress Controller](https://kubernetes.github.io/ingress-nginx/)
5. [Cert-Manager Documentation](https://cert-manager.io/docs/)
6. [Prometheus Operator](https://prometheus-operator.dev/)
7. [Tekton Pipelines](https://tekton.dev/docs/pipelines/)
8. [AWS Security Best Practices](https://docs.aws.amazon.com/security/)