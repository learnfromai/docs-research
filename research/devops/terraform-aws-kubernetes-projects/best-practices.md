# Best Practices: Terraform + AWS + Kubernetes/EKS

## 🎯 Overview

This document compiles production-tested best practices derived from analyzing 15+ open source DevOps projects. These practices ensure security, reliability, maintainability, and operational excellence in Terraform and Kubernetes deployments.

## 🏗️ Infrastructure as Code Best Practices

### 1. Terraform Module Design

#### Modular Architecture
```hcl
# ✅ Good: Focused, reusable modules
module "vpc" {
  source = "./modules/vpc"
  
  name_prefix = var.name_prefix
  cidr_block  = var.vpc_cidr
  environment = var.environment
  
  tags = local.common_tags
}

module "eks" {
  source = "./modules/eks"
  
  cluster_name = "${var.name_prefix}-${var.environment}"
  vpc_id       = module.vpc.vpc_id
  subnet_ids   = module.vpc.private_subnet_ids
  
  depends_on = [module.vpc]
  tags       = local.common_tags
}
```

#### Version Pinning
```hcl
# ✅ Good: Pin module versions
terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.21"  # Pin to specific version
  
  # Module configuration...
}
```

#### Variable Validation
```hcl
# ✅ Good: Input validation
variable "environment" {
  description = "Environment name"
  type        = string
  
  validation {
    condition = contains([
      "development", 
      "staging", 
      "production"
    ], var.environment)
    error_message = "Environment must be development, staging, or production."
  }
}

variable "cluster_version" {
  description = "Kubernetes cluster version"
  type        = string
  
  validation {
    condition     = can(regex("^1\\.(2[6-9]|[3-9][0-9])$", var.cluster_version))
    error_message = "Cluster version must be 1.26 or higher."
  }
}
```

### 2. State Management

#### Remote State Configuration
```hcl
# ✅ Good: S3 backend with encryption and locking
terraform {
  backend "s3" {
    bucket         = "company-terraform-state"
    key            = "environments/prod/eks/terraform.tfstate"
    region         = "us-west-2"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
    
    # Enable versioning for state recovery
    versioning = true
  }
}
```

#### State Isolation
```
# ✅ Good: Separate state files per environment
terraform-states/
├── dev/
│   ├── vpc/terraform.tfstate
│   ├── eks/terraform.tfstate
│   └── apps/terraform.tfstate
├── staging/
│   ├── vpc/terraform.tfstate
│   ├── eks/terraform.tfstate
│   └── apps/terraform.tfstate
└── prod/
    ├── vpc/terraform.tfstate
    ├── eks/terraform.tfstate
    └── apps/terraform.tfstate
```

### 3. Security and Compliance

#### IAM Least Privilege
```hcl
# ✅ Good: Specific IAM policies
data "aws_iam_policy_document" "eks_node_group" {
  statement {
    effect = "Allow"
    actions = [
      "ec2:DescribeInstances",
      "ec2:DescribeRouteTables",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSubnets",
      "ec2:DescribeVolumes",
      "ec2:DescribeVolumesModifications",
      "ec2:DescribeVpcs",
      "eks:DescribeCluster"
    ]
    resources = ["*"]
  }
  
  statement {
    effect = "Allow"
    actions = [
      "ec2:AttachVolume",
      "ec2:CreateVolume",
      "ec2:DeleteVolume",
      "ec2:ModifyVolume"
    ]
    resources = ["*"]
    
    condition {
      test     = "StringEquals"
      variable = "ec2:CreateVolumePermissions"
      values   = ["true"]
    }
  }
}
```

#### Encryption by Default
```hcl
# ✅ Good: Encryption configuration
module "eks" {
  source = "terraform-aws-modules/eks/aws"
  
  # EBS encryption
  eks_managed_node_group_defaults = {
    disk_encrypted = true
    disk_kms_key_id = aws_kms_key.eks.arn
  }
  
  # Cluster encryption
  cluster_encryption_config = [
    {
      provider_key_arn = aws_kms_key.eks.arn
      resources        = ["secrets"]
    }
  ]
  
  # CloudWatch logs encryption
  cloudwatch_log_group_kms_key_id = aws_kms_key.eks.arn
}

# Dedicated KMS key for EKS
resource "aws_kms_key" "eks" {
  description             = "EKS encryption key"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  
  tags = local.common_tags
}
```

## ⚙️ Kubernetes Best Practices

### 1. Resource Management

#### Resource Requests and Limits
```yaml
# ✅ Good: Always set resource limits
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
spec:
  template:
    spec:
      containers:
      - name: webapp
        image: webapp:v1.2.3
        resources:
          requests:
            memory: "64Mi"
            cpu: "250m"
          limits:
            memory: "128Mi"
            cpu: "500m"
        # Liveness and readiness probes
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
```

#### Horizontal Pod Autoscaling
```yaml
# ✅ Good: HPA configuration
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: webapp-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: webapp
  minReplicas: 3
  maxReplicas: 100
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 50
        periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
      - type: Percent
        value: 100
        periodSeconds: 60
```

### 2. Security Hardening

#### Pod Security Standards
```yaml
# ✅ Good: Restricted pod security
apiVersion: v1
kind: Namespace
metadata:
  name: webapp
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
  namespace: webapp
spec:
  template:
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 65534
        fsGroup: 65534
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: webapp
        image: webapp:v1.2.3
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          runAsUser: 65534
          capabilities:
            drop:
            - ALL
        volumeMounts:
        - name: tmp
          mountPath: /tmp
        - name: cache
          mountPath: /app/cache
      volumes:
      - name: tmp
        emptyDir: {}
      - name: cache
        emptyDir: {}
```

#### Network Policies
```yaml
# ✅ Good: Default deny network policy
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: webapp
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
---
# Allow specific traffic
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: webapp-netpol
  namespace: webapp
spec:
  podSelector:
    matchLabels:
      app: webapp
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
    ports:
    - protocol: TCP
      port: 8080
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: database
    ports:
    - protocol: TCP
      port: 5432
  - to: []  # Allow DNS
    ports:
    - protocol: UDP
      port: 53
```

### 3. Configuration Management

#### ConfigMaps and Secrets
```yaml
# ✅ Good: Separate config from secrets
apiVersion: v1
kind: ConfigMap
metadata:
  name: webapp-config
  namespace: webapp
data:
  DATABASE_HOST: "postgres.database.svc.cluster.local"
  DATABASE_PORT: "5432"
  DATABASE_NAME: "webapp"
  LOG_LEVEL: "info"
  CACHE_TTL: "3600"
---
apiVersion: v1
kind: Secret
metadata:
  name: webapp-secrets
  namespace: webapp
type: Opaque
data:
  DATABASE_PASSWORD: <base64-encoded-password>
  API_KEY: <base64-encoded-api-key>
---
# Deployment using external secrets operator
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: webapp-secrets
  namespace: webapp
spec:
  refreshInterval: 15s
  secretStoreRef:
    name: aws-secrets-manager
    kind: SecretStore
  target:
    name: webapp-secrets
    creationPolicy: Owner
  data:
  - secretKey: DATABASE_PASSWORD
    remoteRef:
      key: webapp/database
      property: password
  - secretKey: API_KEY
    remoteRef:
      key: webapp/api
      property: key
```

## 🔄 GitOps Best Practices

### 1. Repository Structure

#### GitOps Repository Layout
```
fleet-infra/
├── clusters/
│   ├── development/
│   │   ├── infrastructure/
│   │   └── applications/
│   ├── staging/
│   │   ├── infrastructure/
│   │   └── applications/
│   └── production/
│       ├── infrastructure/
│       └── applications/
├── infrastructure/
│   ├── sources/
│   ├── monitoring/
│   ├── security/
│   └── networking/
└── applications/
    ├── webapp/
    ├── api/
    └── worker/
```

#### Flux Kustomization Structure
```yaml
# ✅ Good: Layered configuration management
# clusters/production/infrastructure/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- ../../../infrastructure/sources
- ../../../infrastructure/monitoring
- ../../../infrastructure/security
- ../../../infrastructure/networking

patchesStrategicMerge:
- monitoring-patch.yaml
- security-patch.yaml

images:
- name: prometheus
  newTag: v2.45.0
```

### 2. Progressive Delivery

#### Canary Deployment with Flagger
```yaml
# ✅ Good: Automated canary analysis
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: webapp
  namespace: webapp
spec:
  provider: istio
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: webapp
  service:
    port: 80
    targetPort: 8080
    gateways:
    - webapp-gateway
    hosts:
    - webapp.example.com
  analysis:
    interval: 1m
    threshold: 5
    maxWeight: 50
    stepWeight: 10
    metrics:
    - name: request-success-rate
      thresholdRange:
        min: 99
      interval: 1m
    - name: request-duration
      thresholdRange:
        max: 500
      interval: 1m
    webhooks:
    - name: load-test
      type: rollout
      url: http://loadtester.test/
      timeout: 5s
      metadata:
        cmd: "hey -z 1m -q 10 -c 2 http://webapp.example.com/"
```

## 📊 Monitoring and Observability

### 1. Metrics Collection

#### Prometheus Configuration
```yaml
# ✅ Good: Comprehensive monitoring setup
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
    - "/etc/prometheus/rules/*.yml"
    
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
      relabel_configs:
      - action: labelmap
        regex: __meta_kubernetes_node_label_(.+)
    
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

### 2. Alerting Rules

#### Critical Alerts
```yaml
# ✅ Good: Actionable alerts
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-rules
  namespace: monitoring
data:
  kubernetes.yml: |
    groups:
    - name: kubernetes
      rules:
      - alert: KubernetesPodCrashLooping
        expr: rate(kube_pod_container_status_restarts_total[15m]) > 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Pod {{ $labels.namespace }}/{{ $labels.pod }} is crash looping"
          description: "Pod {{ $labels.namespace }}/{{ $labels.pod }} has been restarting {{ $value }} times in the last 15 minutes"
      
      - alert: KubernetesNodeNotReady
        expr: kube_node_status_condition{condition="Ready",status="true"} == 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Node {{ $labels.node }} is not ready"
          description: "Node {{ $labels.node }} has been not ready for more than 5 minutes"
      
      - alert: KubernetesPodNotReady
        expr: kube_pod_status_ready{condition="true"} == 0
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "Pod {{ $labels.namespace }}/{{ $labels.pod }} is not ready"
          description: "Pod {{ $labels.namespace }}/{{ $labels.pod }} has been not ready for more than 10 minutes"
```

## 🛡️ Disaster Recovery and Backup

### 1. Cluster Backup Strategy

#### Velero Backup Configuration
```yaml
# ✅ Good: Automated backup setup
apiVersion: velero.io/v1
kind: Schedule
metadata:
  name: daily-backup
  namespace: velero
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  template:
    includedNamespaces:
    - webapp
    - api
    - database
    excludedResources:
    - events
    - events.events.k8s.io
    storageLocation: default
    ttl: 720h  # 30 days
    snapshotVolumes: true
```

### 2. Multi-Region Setup

#### Cross-Region Replication
```hcl
# ✅ Good: Multi-region deployment
module "primary_cluster" {
  source = "./modules/eks"
  
  providers = {
    aws = aws.us_west_2
  }
  
  cluster_name = "prod-primary"
  region       = "us-west-2"
  
  # Primary cluster configuration
}

module "disaster_recovery_cluster" {
  source = "./modules/eks"
  
  providers = {
    aws = aws.us_east_1
  }
  
  cluster_name = "prod-dr"
  region       = "us-east-1"
  
  # DR cluster configuration
}

# Cross-region state replication
resource "aws_s3_bucket_replication_configuration" "terraform_state" {
  role   = aws_iam_role.replication.arn
  bucket = aws_s3_bucket.terraform_state.id
  
  rule {
    id     = "replicate_state"
    status = "Enabled"
    
    destination {
      bucket        = aws_s3_bucket.terraform_state_replica.arn
      storage_class = "STANDARD_IA"
    }
  }
}
```

## 🔄 CI/CD Pipeline Best Practices

### 1. Terraform Pipeline

#### GitLab CI Terraform Pipeline
```yaml
# ✅ Good: Comprehensive Terraform pipeline
stages:
  - validate
  - plan
  - security
  - apply

variables:
  TF_ROOT: ${CI_PROJECT_DIR}/environments/${CI_COMMIT_REF_NAME}
  TF_ADDRESS: ${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/terraform/state/${CI_COMMIT_REF_NAME}

cache:
  key: "${CI_COMMIT_REF_NAME}"
  paths:
    - ${TF_ROOT}/.terraform

before_script:
  - cd ${TF_ROOT}
  - terraform --version
  - terraform init -backend-config="address=${TF_ADDRESS}" -backend-config="lock_address=${TF_ADDRESS}/lock" -backend-config="unlock_address=${TF_ADDRESS}/lock" -backend-config="username=${CI_USERNAME}" -backend-config="password=${CI_JOB_TOKEN}" -backend-config="lock_method=POST" -backend-config="unlock_method=DELETE" -backend-config="retry_wait_min=5"

validate:
  stage: validate
  script:
    - terraform validate
    - terraform fmt -check
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
    - if: $CI_COMMIT_BRANCH && $CI_OPEN_MERGE_REQUESTS
      when: never
    - if: $CI_COMMIT_BRANCH

plan:
  stage: plan
  script:
    - terraform plan -out="planfile"
  artifacts:
    name: plan
    paths:
      - ${TF_ROOT}/planfile
    expire_in: 7 days
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
    - if: $CI_COMMIT_BRANCH && $CI_OPEN_MERGE_REQUESTS
      when: never
    - if: $CI_COMMIT_BRANCH

security:
  stage: security
  image: bridgecrew/checkov:latest
  script:
    - checkov -d ${TF_ROOT} --framework terraform --output cli --output junitxml --output-file-path console,${TF_ROOT}/checkov-report.xml
  artifacts:
    reports:
      junit: ${TF_ROOT}/checkov-report.xml
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
    - if: $CI_COMMIT_BRANCH && $CI_OPEN_MERGE_REQUESTS
      when: never
    - if: $CI_COMMIT_BRANCH

apply:
  stage: apply
  script:
    - terraform apply -input=false "planfile"
  dependencies:
    - plan
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
      when: manual
    - if: $CI_COMMIT_BRANCH == "production"
      when: manual
```

## 📝 Documentation Standards

### 1. Module Documentation

#### Terraform Module README Template
```markdown
# Module Name

## Description
Brief description of what this module does and its purpose.

## Usage
```hcl
module "example" {
  source = "./modules/example"
  
  name        = "my-resource"
  environment = "production"
  
  tags = {
    Project = "MyProject"
  }
}
```

## Requirements
| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| aws | ~> 5.0 |

## Providers
| Name | Version |
|------|---------|
| aws | ~> 5.0 |

## Inputs
| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| name | Resource name | `string` | n/a | yes |
| environment | Environment name | `string` | n/a | yes |

## Outputs
| Name | Description |
|------|-------------|
| resource_id | The ID of the created resource |
| resource_arn | The ARN of the created resource |
```

## 🔗 Quick Reference Checklist

### Infrastructure Deployment Checklist
- [ ] Terraform modules are versioned and tested
- [ ] Remote state backend is configured with encryption
- [ ] IAM policies follow least privilege principle
- [ ] All resources are tagged consistently
- [ ] Encryption is enabled for all data stores
- [ ] Network policies are configured
- [ ] Resource limits are set for all workloads
- [ ] Monitoring and alerting are configured
- [ ] Backup strategy is implemented
- [ ] Disaster recovery plan is tested

### Security Checklist
- [ ] Pod Security Standards are enforced
- [ ] Network policies deny traffic by default
- [ ] Secrets are managed externally (not in Git)
- [ ] Container images are scanned for vulnerabilities
- [ ] RBAC is configured with minimal permissions
- [ ] Audit logging is enabled
- [ ] Encryption in transit and at rest is enabled
- [ ] Security scanning is integrated in CI/CD

### Operational Checklist
- [ ] GitOps workflow is implemented
- [ ] Canary deployments are configured
- [ ] Horizontal Pod Autoscaler is configured
- [ ] Cluster autoscaling is enabled
- [ ] Comprehensive monitoring is in place
- [ ] Alerting rules are actionable
- [ ] Runbooks are documented
- [ ] Incident response procedures are defined

## 🔗 Navigation

← [Back to Implementation Guide](./implementation-guide.md) | [Next: Terraform Patterns →](./terraform-patterns-analysis.md)