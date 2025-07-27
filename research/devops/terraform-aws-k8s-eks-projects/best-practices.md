# Best Practices: Production-Ready Terraform AWS EKS

Comprehensive best practices derived from analyzing 25+ production-ready open source projects for Terraform, AWS EKS, and Kubernetes implementations.

## 🏗️ Infrastructure Architecture Patterns

### **1. Modular Terraform Design**

Based on terraform-aws-modules organization patterns:

#### **Module Structure**
```
terraform/
├── modules/
│   ├── vpc/                 # Network foundation
│   ├── eks/                 # EKS cluster configuration
│   ├── addons/              # Kubernetes add-ons
│   ├── monitoring/          # Observability stack
│   └── security/            # Security policies
├── environments/
│   ├── dev/
│   ├── staging/
│   └── prod/
└── shared/                  # Common configurations
    ├── data.tf
    ├── locals.tf
    └── providers.tf
```

#### **Module Design Principles**
```hcl
# ✅ GOOD: Composable and reusable module
module "eks_cluster" {
  source = "../../modules/eks"
  
  cluster_name    = local.cluster_name
  cluster_version = var.kubernetes_version
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.private_subnets
  
  node_groups = {
    system = {
      instance_types = ["m5.large"]
      capacity_type  = "ON_DEMAND"
      min_size       = 2
      max_size       = 4
      desired_size   = 2
      
      k8s_labels = {
        role = "system"
      }
      
      taints = {
        dedicated = {
          key    = "system"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      }
    }
    
    workload = {
      instance_types = ["m5.xlarge", "m5a.xlarge"]
      capacity_type  = "SPOT"
      min_size       = 1
      max_size       = 10
      desired_size   = 3
    }
  }
  
  tags = local.common_tags
}
```

```hcl
# ❌ BAD: Monolithic configuration
resource "aws_eks_cluster" "main" {
  name     = "hardcoded-cluster-name"
  role_arn = "arn:aws:iam::123456789012:role/eks-service-role"
  
  vpc_config {
    subnet_ids = ["subnet-12345", "subnet-67890"]
  }
  
  # Hardcoded values, no flexibility
}
```

### **2. Environment Separation Strategy**

Following workspace patterns from aws-ia/terraform-aws-eks-blueprints:

#### **Directory-Based Separation**
```hcl
# terraform/environments/prod/main.tf
module "production_cluster" {
  source = "../../modules/eks"
  
  cluster_name    = "prod-cluster"
  cluster_version = "1.28"
  
  node_groups = {
    system = {
      instance_types = ["m5.large"]
      min_size       = 3  # High availability
      max_size       = 6
      desired_size   = 3
    }
    
    workload = {
      instance_types = ["m5.2xlarge", "c5.2xlarge"]
      min_size       = 5  # Production load
      max_size       = 50
      desired_size   = 10
    }
  }
  
  enable_logging = true
  log_retention_days = 30
  
  tags = {
    Environment = "production"
    Backup      = "required"
    Monitoring  = "enhanced"
  }
}
```

#### **State Management**
```hcl
# ✅ GOOD: Environment-specific state
terraform {
  backend "s3" {
    bucket = "company-terraform-state"
    key    = "environments/prod/eks.tfstate"
    region = "us-west-2"
    
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
```

### **3. Resource Tagging Strategy**

Consistent tagging patterns from enterprise projects:

```hcl
# terraform/shared/locals.tf
locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    Owner       = var.team_name
    CostCenter  = var.cost_center
    CreatedBy   = "terraform"
    CreatedAt   = timestamp()
    
    # EKS-specific tags
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }
  
  # Additional environment-specific tags
  environment_tags = var.environment == "prod" ? {
    Backup           = "required"
    MonitoringLevel  = "enhanced"
    ComplianceLevel  = "strict"
  } : {}
  
  # Merge all tags
  final_tags = merge(
    local.common_tags,
    local.environment_tags,
    var.additional_tags
  )
}
```

## 🔒 Security Best Practices

### **1. Network Security Patterns**

Based on security-focused projects like ViktorUJ/cks:

#### **VPC Configuration**
```hcl
# ✅ GOOD: Secure VPC setup
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  
  name = "${var.cluster_name}-vpc"
  cidr = "10.0.0.0/16"
  
  azs             = ["us-west-2a", "us-west-2b", "us-west-2c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  
  # Security hardening
  enable_nat_gateway   = true
  single_nat_gateway   = false  # Multiple NAT gateways for HA
  enable_vpn_gateway   = false
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  # VPC Flow Logs for security monitoring
  enable_flow_log                      = true
  create_flow_log_cloudwatch_log_group = true
  create_flow_log_cloudwatch_iam_role  = true
  flow_log_max_aggregation_interval    = 60
  
  # EKS-specific subnet tags
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }
  
  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}
```

#### **EKS Security Configuration**
```hcl
# ✅ GOOD: Security-hardened EKS cluster
module "eks" {
  source = "terraform-aws-modules/eks/aws"
  
  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version
  
  # Control plane security
  cluster_endpoint_config = {
    private_access = true
    public_access  = var.enable_public_access
    public_access_cidrs = var.allowed_cidr_blocks
  }
  
  # Enable logging for all types
  cluster_enabled_log_types = [
    "api",
    "audit", 
    "authenticator",
    "controllerManager",
    "scheduler"
  ]
  
  cluster_log_retention_in_days = 30
  
  # Encryption at rest
  cluster_encryption_config = {
    provider_key_arn = aws_kms_key.eks.arn
    resources        = ["secrets"]
  }
  
  # Security group rules
  cluster_security_group_additional_rules = {
    ingress_nodes_443 = {
      description                = "Node groups to cluster API"
      protocol                   = "tcp"
      from_port                  = 443
      to_port                    = 443
      type                       = "ingress"
      source_node_security_group = true
    }
  }
  
  node_security_group_additional_rules = {
    # Restrict SSH access
    ingress_ssh_bastion = {
      description = "SSH from bastion"
      protocol    = "tcp"
      from_port   = 22
      to_port     = 22
      type        = "ingress"
      cidr_blocks = ["10.0.0.0/16"]
    }
    
    # Allow communication between nodes
    ingress_self_all = {
      description = "Node to node all traffic"
      protocol    = "-1"
      from_port   = 0
      to_port     = 65535
      type        = "ingress"
      self        = true
    }
  }
}

# KMS key for EKS encryption
resource "aws_kms_key" "eks" {
  description             = "EKS Secret Encryption Key"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  
  tags = local.common_tags
}
```

### **2. IAM and RBAC Patterns**

#### **Service Account IAM Roles (IRSA)**
```hcl
# ✅ GOOD: Least privilege service account
module "load_balancer_controller_irsa_role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  
  role_name = "aws-load-balancer-controller"
  
  attach_load_balancer_controller_policy = true
  
  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
  
  tags = local.common_tags
}
```

#### **RBAC Configuration**
```yaml
# ✅ GOOD: Granular RBAC policies
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: developer-role
rules:
# Pod management
- apiGroups: [""]
  resources: ["pods", "pods/log", "pods/exec"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
# Service management
- apiGroups: [""]
  resources: ["services"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
# ConfigMap and Secret access (limited)
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list", "watch"]
# Deployment management
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
---
# ❌ BAD: Overly permissive RBAC
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: developer-admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin  # Too permissive!
subjects:
- kind: User
  name: developer
```

### **3. Network Policy Implementation**

#### **Default Deny Policy**
```yaml
# ✅ GOOD: Start with default deny
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
---
# Allow essential traffic
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
  namespace: production
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
# Allow specific application communication
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: frontend-to-backend
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: frontend
  policyTypes:
  - Egress
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: backend
    ports:
    - protocol: TCP
      port: 8080
```

## 📊 Monitoring and Observability

### **1. Metrics Collection Patterns**

Based on prometheus patterns from analyzed projects:

#### **Prometheus Configuration**
```yaml
# ✅ GOOD: Comprehensive monitoring setup
prometheus:
  prometheusSpec:
    retention: 15d
    retentionSize: 50GB
    
    # Resource management
    resources:
      requests:
        memory: 2Gi
        cpu: 1000m
      limits:
        memory: 4Gi
        cpu: 2000m
    
    # Storage configuration
    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: gp3
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 100Gi
    
    # Security
    securityContext:
      runAsNonRoot: true
      runAsUser: 65534
      fsGroup: 65534
    
    # Service monitor selectors
    serviceMonitorSelectorNilUsesHelmValues: false
    serviceMonitorSelector: {}
    serviceMonitorNamespaceSelector: {}
    
    # Additional scrape configs
    additionalScrapeConfigs:
    - job_name: 'kubernetes-pods'
      kubernetes_sd_configs:
      - role: pod
      relabel_configs:
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
        action: keep
        regex: true
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
        action: replace
        target_label: __metrics_path__
        regex: (.+)
```

#### **Custom Dashboards**
```json
{
  "dashboard": {
    "title": "EKS Cluster Overview",
    "panels": [
      {
        "title": "Node CPU Usage",
        "type": "graph",
        "targets": [
          {
            "expr": "100 - (avg by (instance) (irate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)"
          }
        ]
      },
      {
        "title": "Pod Memory Usage",
        "type": "graph", 
        "targets": [
          {
            "expr": "sum(container_memory_working_set_bytes{container!=\"\",pod!=\"\"}) by (pod)"
          }
        ]
      },
      {
        "title": "Cluster Resource Utilization",
        "type": "singlestat",
        "targets": [
          {
            "expr": "(sum(kube_node_status_allocatable{resource=\"cpu\"}) - sum(kube_pod_container_resource_requests{resource=\"cpu\"})) / sum(kube_node_status_allocatable{resource=\"cpu\"}) * 100"
          }
        ]
      }
    ]
  }
}
```

### **2. Logging Architecture**

#### **Centralized Logging with ELK**
```yaml
# ✅ GOOD: Structured logging pipeline
elasticsearch:
  replicas: 3
  minimumMasterNodes: 2
  
  esConfig:
    elasticsearch.yml: |
      cluster.name: "eks-logging"
      network.host: 0.0.0.0
      discovery.zen.minimum_master_nodes: 2
      discovery.zen.ping.unicast.hosts: elasticsearch-master-headless
      
  resources:
    requests:
      cpu: "1000m"
      memory: "2Gi"
    limits:
      cpu: "2000m" 
      memory: "4Gi"
      
  volumeClaimTemplate:
    accessModes: [ "ReadWriteOnce" ]
    storageClassName: gp3
    resources:
      requests:
        storage: 100Gi

logstash:
  replicas: 2
  
  logstashConfig:
    logstash.yml: |
      http.host: 0.0.0.0
      xpack.monitoring.elasticsearch.hosts: ["http://elasticsearch-master:9200"]
      
  logstashPipeline:
    logstash.conf: |
      input {
        beats {
          port => 5044
        }
      }
      filter {
        if [kubernetes] {
          mutate {
            add_field => { "cluster_name" => "prod-eks-cluster" }
          }
        }
      }
      output {
        elasticsearch {
          hosts => ["http://elasticsearch-master:9200"]
          index => "kubernetes-logs-%{+YYYY.MM.dd}"
        }
      }

filebeat:
  daemonset:
    enabled: true
    
  filebeatConfig:
    filebeat.yml: |
      filebeat.inputs:
      - type: container
        paths:
          - /var/log/containers/*.log
        processors:
        - add_kubernetes_metadata:
            host: ${NODE_NAME}
            matchers:
            - logs_path:
                logs_path: "/var/log/containers/"
      
      output.logstash:
        hosts: ["logstash-logstash:5044"]
```

## 🚀 Performance and Scaling

### **1. Node Group Optimization**

#### **Mixed Instance Types Strategy**
```hcl
# ✅ GOOD: Diversified node groups for reliability and cost
eks_managed_node_groups = {
  # System workloads - reliable instances
  system = {
    name = "system-nodes"
    
    instance_types = ["m5.large", "m5a.large", "m5n.large"]
    capacity_type  = "ON_DEMAND"
    
    min_size     = 2
    max_size     = 4  
    desired_size = 2
    
    # System node taints
    taints = {
      dedicated = {
        key    = "CriticalAddonsOnly"
        value  = "true"
        effect = "NO_SCHEDULE"
      }
    }
    
    labels = {
      role = "system"
      "node.kubernetes.io/lifecycle" = "normal"
    }
    
    # Ensure system pods can run
    k8s_labels = {
      "node-role.kubernetes.io/system" = "true"
    }
  }
  
  # Application workloads - cost-optimized with spot
  workload = {
    name = "workload-nodes"
    
    instance_types = [
      "m5.xlarge", "m5a.xlarge", "m5n.xlarge",
      "c5.xlarge", "c5a.xlarge", "c5n.xlarge",
      "r5.xlarge", "r5a.xlarge"
    ]
    capacity_type = "SPOT"
    
    min_size     = 2
    max_size     = 20
    desired_size = 4
    
    labels = {
      role = "workload"
      "node.kubernetes.io/lifecycle" = "spot"
    }
    
    # Spot instance interruption handling
    metadata_options = {
      http_endpoint = "enabled"
      http_tokens   = "required"
      http_put_response_hop_limit = 2
    }
  }
  
  # GPU workloads for ML/AI
  gpu = {
    name = "gpu-nodes"
    
    instance_types = ["p3.2xlarge", "p3.8xlarge", "g4dn.xlarge"]
    capacity_type  = "ON_DEMAND"
    
    min_size     = 0
    max_size     = 5
    desired_size = 0
    
    # GPU-specific AMI
    ami_type = "AL2_x86_64_GPU"
    
    taints = {
      nvidia = {
        key    = "nvidia.com/gpu"
        value  = "true"
        effect = "NO_SCHEDULE"
      }
    }
    
    labels = {
      role = "gpu"
      "accelerator" = "nvidia-tesla"
    }
  }
}
```

### **2. Cluster Autoscaler Configuration**

#### **Optimized Scaling Policies**
```yaml
# ✅ GOOD: Responsive autoscaling configuration
replicaCount: 2

image:
  tag: v1.27.2

autoDiscovery:
  clusterName: prod-eks-cluster
  enabled: true

awsRegion: us-west-2

nodeGroups: []  # Use auto-discovery

extraArgs:
  scale-down-enabled: true
  scale-down-delay-after-add: 10m
  scale-down-unneeded-time: 10m
  scale-down-util-threshold: 0.5
  skip-nodes-with-local-storage: false
  expander: least-waste
  node-group-auto-discovery: asg:tag=k8s.io/cluster-autoscaler/enabled,k8s.io/cluster-autoscaler/prod-eks-cluster

resources:
  limits:
    cpu: 100m
    memory: 300Mi
  requests:
    cpu: 100m
    memory: 300Mi

priorityClassName: system-cluster-critical

nodeSelector:
  role: system

tolerations:
- key: CriticalAddonsOnly
  operator: Exists
  effect: NoSchedule
```

### **3. Karpenter Advanced Configuration**

#### **Intelligent Node Provisioning**
```yaml
# ✅ GOOD: Karpenter with smart provisioning
apiVersion: karpenter.sh/v1beta1
kind: NodePool
metadata:
  name: default
spec:
  template:
    metadata:
      labels:
        billing-team: platform
        environment: production
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
          values: ["m5.large", "m5.xlarge", "m5.2xlarge", "c5.large", "c5.xlarge", "c5.2xlarge"]
          
      # Node properties
      nodeClassRef:
        apiVersion: karpenter.k8s.aws/v1beta1
        kind: EC2NodeClass
        name: default
        
      # Resource limits
      taints:
        - key: karpenter.sh/nodepool
          value: default
          effect: NoSchedule
          
  # Disruption settings
  disruption:
    consolidationPolicy: WhenUnderutilized
    consolidateAfter: 30s
    expireAfter: 30m
    
  # Total resource limits
  limits:
    cpu: 1000
    memory: 1000Gi
    
---
apiVersion: karpenter.k8s.aws/v1beta1
kind: EC2NodeClass
metadata:
  name: default
spec:
  amiFamily: AL2
  subnetSelectorTerms:
    - tags:
        karpenter.sh/discovery: "prod-eks-cluster"
  securityGroupSelectorTerms:
    - tags:
        karpenter.sh/discovery: "prod-eks-cluster"
        
  # Instance configuration
  instanceStorePolicy: RAID0
  userData: |
    #!/bin/bash
    /etc/eks/bootstrap.sh prod-eks-cluster
    echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.conf
    echo 'net.bridge.bridge-nf-call-iptables = 1' >> /etc/sysctl.conf
    
  # Block device mappings
  blockDeviceMappings:
    - deviceName: /dev/xvda
      ebs:
        volumeSize: 100Gi
        volumeType: gp3
        iops: 3000
        encrypted: true
        
  tags:
    Environment: production
    ManagedBy: karpenter
```

## 📋 Operational Best Practices

### **1. Backup and Disaster Recovery**

#### **Velero Backup Configuration**
```yaml
# ✅ GOOD: Comprehensive backup strategy
configuration:
  provider: aws
  backupStorageLocation:
    bucket: company-k8s-backups
    prefix: prod-cluster
    config:
      region: us-west-2
      serverSideEncryption: AES256
      
  volumeSnapshotLocation:
    config:
      region: us-west-2
      
# Backup schedules
schedules:
  daily:
    disabled: false
    schedule: "0 2 * * *"
    template:
      includedNamespaces:
      - default
      - kube-system
      - monitoring
      excludedResources:
      - events
      - events.events.k8s.io
      ttl: 720h  # 30 days
      
  weekly:
    disabled: false
    schedule: "0 3 * * 0"
    template:
      includedNamespaces: ["*"]
      ttl: 2160h  # 90 days
      
  cluster-backup:
    disabled: false
    schedule: "0 4 * * 0"
    template:
      includeClusterResources: true
      ttl: 4320h  # 180 days
```

### **2. Cost Optimization Strategies**

#### **Resource Quotas and Limits**
```yaml
# ✅ GOOD: Resource governance
apiVersion: v1
kind: ResourceQuota
metadata:
  name: production-quota
  namespace: production
spec:
  hard:
    requests.cpu: "50"
    requests.memory: 100Gi
    limits.cpu: "100"
    limits.memory: 200Gi
    persistentvolumeclaims: "10"
    services.loadbalancers: "5"
---
apiVersion: v1
kind: LimitRange
metadata:
  name: production-limits
  namespace: production
spec:
  limits:
  - default:
      cpu: "1"
      memory: "1Gi"
    defaultRequest:
      cpu: "100m"
      memory: "128Mi"
    type: Container
  - max:
      cpu: "4"
      memory: "8Gi"
    min:
      cpu: "50m"
      memory: "64Mi"
    type: Container
```

#### **Pod Disruption Budgets**
```yaml
# ✅ GOOD: High availability protection
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: web-app-pdb
  namespace: production
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: web-app
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: database-pdb
  namespace: production
spec:
  maxUnavailable: 0
  selector:
    matchLabels:
      app: database
```

## 🔄 CI/CD Integration Patterns

### **1. GitOps Workflow**

#### **ArgoCD Application Sets**
```yaml
# ✅ GOOD: Automated multi-environment deployment
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: microservices
  namespace: argocd
spec:
  generators:
  - clusters:
      selector:
        matchLabels:
          environment: production
  - git:
      repoURL: https://github.com/company/k8s-manifests
      revision: HEAD
      directories:
      - path: applications/*
  
  template:
    metadata:
      name: '{{path.basename}}-{{name}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/company/k8s-manifests
        targetRevision: HEAD
        path: '{{path}}'
      destination:
        server: '{{server}}'
        namespace: '{{path.basename}}'
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
        - CreateNamespace=true
        - PruneLast=true
```

### **2. Security Scanning Integration**

#### **Policy as Code with OPA Gatekeeper**
```yaml
# ✅ GOOD: Automated policy enforcement
apiVersion: templates.gatekeeper.sh/v1beta1
kind: ConstraintTemplate
metadata:
  name: k8srequiredsecuritycontext
spec:
  crd:
    spec:
      names:
        kind: K8sRequiredSecurityContext
      validation:
        type: object
        properties:
          runAsNonRoot:
            type: boolean
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8srequiredsecuritycontext
        
        violation[{"msg": msg}] {
          container := input.review.object.spec.containers[_]
          not container.securityContext.runAsNonRoot
          msg := "Container must run as non-root user"
        }
        
        violation[{"msg": msg}] {
          container := input.review.object.spec.containers[_]
          container.securityContext.runAsUser == 0
          msg := "Container cannot run as root (UID 0)"
        }
---
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequiredSecurityContext
metadata:
  name: must-run-as-non-root
spec:
  match:
    kinds:
      - apiGroups: [""]
        kinds: ["Pod"]
    namespaces: ["production", "staging"]
  parameters:
    runAsNonRoot: true
```

## 📊 Key Performance Indicators

### **Monitoring Metrics to Track**

#### **Infrastructure Health**
- **Node CPU/Memory utilization**: < 80% average
- **Pod restart rate**: < 5% per hour
- **Cluster autoscaler latency**: < 30 seconds
- **Network policy violations**: 0 per day

#### **Application Performance**
- **Pod startup time**: < 30 seconds P95
- **Service response time**: < 200ms P95
- **Error rate**: < 0.1%
- **Availability**: > 99.9%

#### **Cost Optimization**
- **Resource utilization**: > 70% average
- **Spot instance savings**: > 50% of compute costs
- **Storage optimization**: < 5% waste
- **Right-sizing effectiveness**: > 90% correctly sized

---

← [Back to Implementation Guide](./implementation-guide.md) | **Next**: [Security Considerations](./security-considerations.md) →