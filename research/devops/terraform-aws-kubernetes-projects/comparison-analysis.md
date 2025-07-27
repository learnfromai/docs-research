# Comparison Analysis: Terraform + AWS + Kubernetes/EKS Project Frameworks

## 🏗️ Complete Platform Solutions

### **Comprehensive Platform Comparison**

| Project | Stars | Last Updated | Complexity | Best For | Key Features |
|---------|-------|--------------|------------|----------|--------------|
| **[Crossplane](https://github.com/crossplane/crossplane)** | 9.4k | Active | High | Multi-cloud infrastructure | Universal control plane, composition functions |
| **[DevSpace](https://github.com/loft-sh/devspace)** | 4.2k | Active | Medium | Developer workflows | Local development, deployment automation |
| **[AWS Controllers for K8s](https://github.com/aws-controllers-k8s/community)** | 2.4k | Active | High | AWS-native operations | Native AWS service operators |
| **[Cluster API AWS](https://github.com/kubernetes-sigs/cluster-api-provider-aws)** | 640 | Active | High | Kubernetes-native clusters | Declarative cluster management |
| **[KubeOne](https://github.com/kubermatic/kubeone)** | 1.4k | Active | Medium | Multi-cloud K8s | Automated K8s installation |

#### **Selection Criteria Matrix**

| Criteria | Crossplane | DevSpace | AWS Controllers | Cluster API | KubeOne |
|----------|------------|----------|-----------------|-------------|---------|
| **Learning Curve** | High | Low | High | High | Medium |
| **Multi-cloud Support** | ✅ | ❌ | ❌ | ✅ | ✅ |
| **Production Readiness** | ✅ | ✅ | ⚠️ | ✅ | ✅ |
| **Community Support** | ✅ | ✅ | ⚠️ | ✅ | ✅ |
| **Enterprise Features** | ✅ | ⚠️ | ✅ | ✅ | ⚠️ |
| **Documentation Quality** | ✅ | ✅ | ⚠️ | ✅ | ✅ |

### **Detailed Analysis**

#### **1. Crossplane - Universal Control Plane**

**Architecture Overview:**
```yaml
# Example Crossplane Composition
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: eks-cluster
spec:
  compositeTypeRef:
    apiVersion: platform.example.com/v1alpha1
    kind: XEKSCluster
  resources:
  - name: vpc
    base:
      apiVersion: ec2.aws.crossplane.io/v1beta1
      kind: VPC
      spec:
        forProvider:
          cidrBlock: "10.0.0.0/16"
          region: us-west-2
  - name: eks-cluster
    base:
      apiVersion: eks.aws.crossplane.io/v1beta1
      kind: Cluster
      spec:
        forProvider:
          region: us-west-2
          version: "1.27"
          roleArnSelector:
            matchLabels:
              role: cluster
```

**Pros:**
- ✅ True infrastructure as code with Kubernetes APIs
- ✅ Multi-cloud abstraction layer
- ✅ Composition and function capabilities
- ✅ Strong community and CNCF backing
- ✅ GitOps-native approach

**Cons:**
- ❌ Steep learning curve
- ❌ Complex setup for simple use cases
- ❌ Limited debugging tools
- ❌ Requires deep Kubernetes knowledge

**Best Use Cases:**
- Large enterprises with multi-cloud strategy
- Platform engineering teams
- Organizations with strong Kubernetes expertise
- Complex infrastructure requirements

#### **2. DevSpace - Developer-Focused Platform**

**Configuration Example:**
```yaml
# devspace.yaml
version: v2beta1
name: my-app

pipelines:
  dev:
    run: |-
      create_deployments --all
      start_dev --all
  deploy:
    run: |-
      build_images --all
      create_deployments --all

images:
  app:
    image: my-registry/my-app
    dockerfile: ./Dockerfile

deployments:
  app:
    helm:
      chart:
        name: ./chart
      values:
        image: ${runtime.images.app.image}

dev:
  app:
    imageSelector: ${runtime.images.app.image}
    workingDir: /app
    sync:
    - path: ./src
      target: /app/src
```

**Pros:**
- ✅ Excellent developer experience
- ✅ Fast local development
- ✅ Easy deployment automation
- ✅ Good documentation and tutorials
- ✅ Active development

**Cons:**
- ❌ Primarily AWS/single-cloud focused
- ❌ Limited enterprise features
- ❌ Not suitable for complex infrastructure
- ❌ Smaller community compared to alternatives

**Best Use Cases:**
- Development teams seeking faster workflows
- Microservices development
- CI/CD pipeline optimization
- Kubernetes adoption acceleration

---

## 🎯 Production-Ready EKS Templates

### **EKS Implementation Comparison**

| Project | Architecture | Monitoring | Security | Automation | Complexity |
|---------|-------------|------------|----------|------------|------------|
| **[TEKS](https://github.com/particuleio/teks)** | Modular | ✅ | ✅ | Terragrunt | High |
| **[EKS with Istio](https://github.com/msfidelis/eks-with-istio)** | Service Mesh | ✅ | ✅ | Terraform | Medium |
| **[EKS GitHub Actions](https://github.com/AmanPathak-DevOps/EKS-Terraform-GitHub-Actions)** | CI/CD Focus | ⚠️ | ⚠️ | GitHub Actions | Low |
| **[AWS EKS Blueprints](https://github.com/aws-ia/terraform-aws-eks-blueprints)** | Comprehensive | ✅ | ✅ | Terraform | High |

#### **1. TEKS - Full-Featured EKS with Terragrunt**

**Project Structure:**
```
teks/
├── terragrunt.hcl
├── terraform/
│   ├── modules/
│   │   ├── eks/
│   │   ├── vpc/
│   │   └── addons/
│   └── live/
│       ├── dev/
│       ├── staging/
│       └── prod/
└── addons/
    ├── aws-load-balancer-controller/
    ├── cluster-autoscaler/
    ├── external-dns/
    └── prometheus/
```

**Key Features:**
- 🎯 Complete EKS ecosystem with 20+ addons
- 🔧 Terragrunt for multi-environment management
- 📊 Integrated monitoring with Prometheus/Grafana
- 🔒 Security hardening with Falco and OPA
- 🚀 GitOps ready with ArgoCD

**Configuration Example:**
```hcl
# live/prod/eks/terragrunt.hcl
include {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../terraform/modules/eks"
}

dependency "vpc" {
  config_path = "../vpc"
}

inputs = {
  cluster_name    = "teks-prod"
  cluster_version = "1.27"
  
  vpc_id     = dependency.vpc.outputs.vpc_id
  subnet_ids = dependency.vpc.outputs.private_subnets
  
  node_groups = {
    main = {
      instance_types = ["t3.large"]
      min_size       = 3
      max_size       = 10
      desired_size   = 6
    }
  }
  
  addons = {
    aws_load_balancer_controller = {
      enabled = true
    }
    cluster_autoscaler = {
      enabled = true
    }
    external_dns = {
      enabled = true
      domain  = "example.com"
    }
  }
}
```

**Pros:**
- ✅ Battle-tested in production environments
- ✅ Comprehensive addon ecosystem
- ✅ Strong security defaults
- ✅ Excellent documentation
- ✅ Active community maintenance

**Cons:**
- ❌ Complex initial setup
- ❌ Opinionated architecture decisions
- ❌ Requires Terragrunt knowledge
- ❌ Can be overkill for simple deployments

#### **2. EKS with Istio - Service Mesh Focus**

**Architecture Components:**
```hcl
# modules/istio/main.tf
resource "helm_release" "istio_base" {
  name       = "istio-base"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "base"
  namespace  = "istio-system"
  version    = var.istio_version

  create_namespace = true

  depends_on = [kubernetes_namespace.istio_system]
}

resource "helm_release" "istiod" {
  name       = "istiod"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "istiod"
  namespace  = "istio-system"
  version    = var.istio_version

  values = [
    yamlencode({
      pilot = {
        resources = {
          requests = {
            cpu    = "100m"
            memory = "128Mi"
          }
        }
      }
    })
  ]

  depends_on = [helm_release.istio_base]
}
```

**Service Mesh Configuration:**
```yaml
# istio-config/gateway.yaml
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: main-gateway
  namespace: istio-system
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "*.example.com"
    tls:
      httpsRedirect: true
  - port:
      number: 443
      name: https
      protocol: HTTPS
    tls:
      mode: SIMPLE
      credentialName: example-com-tls
    hosts:
    - "*.example.com"
```

**Pros:**
- ✅ Production-ready service mesh integration
- ✅ Advanced traffic management
- ✅ Strong security with mTLS
- ✅ Comprehensive observability
- ✅ Well-documented implementation

**Cons:**
- ❌ Service mesh complexity overhead
- ❌ Higher resource requirements
- ❌ Steep learning curve for Istio
- ❌ Limited to single-cluster setups

---

## 🔧 Infrastructure as Code Tools Comparison

### **Terraform vs Alternatives**

| Tool | Pros | Cons | Best For |
|------|------|------|----------|
| **Terraform** | Mature, broad provider support, large community | HCL learning curve, state management complexity | General infrastructure provisioning |
| **Terragrunt** | DRY configuration, multi-environment management | Additional abstraction layer, Terraform dependency | Enterprise multi-environment setups |
| **AWS CDK** | Familiar programming languages, strong typing | AWS-specific, smaller community | AWS-native applications |
| **Pulumi** | Real programming languages, good testing support | Newer ecosystem, smaller community | Complex infrastructure logic |
| **OpenTofu** | Open source Terraform fork, compatible | Early stage, uncertain future | Organizations avoiding HashiCorp licensing |

#### **Terraform Module Best Practices**

```hcl
# Example: Well-structured EKS module
module "eks" {
  source = "./modules/eks"
  
  # Required inputs
  cluster_name = var.cluster_name
  vpc_id       = var.vpc_id
  subnet_ids   = var.subnet_ids
  
  # Optional inputs with defaults
  cluster_version              = var.cluster_version
  enable_cluster_autoscaler   = var.enable_cluster_autoscaler
  enable_aws_load_balancer    = var.enable_aws_load_balancer
  
  # Node group configuration
  node_groups = var.node_groups
  
  # Security settings
  cluster_endpoint_public_access = var.cluster_endpoint_public_access
  cluster_endpoint_access_cidrs  = var.cluster_endpoint_access_cidrs
  
  # Tagging
  tags = merge(var.common_tags, var.eks_tags)
}

# Module variables with validation
variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  
  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]*$", var.cluster_name))
    error_message = "Cluster name must start with a letter and contain only alphanumeric characters and hyphens."
  }
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.27"
  
  validation {
    condition     = contains(["1.25", "1.26", "1.27", "1.28"], var.cluster_version)
    error_message = "Cluster version must be a supported EKS version."
  }
}
```

#### **Terragrunt Configuration Patterns**

```hcl
# Root terragrunt.hcl with advanced patterns
locals {
  # Parse environment and region from directory structure
  parsed = regex("envs/(?P<env>[^/]+)/(?P<region>[^/]+)", get_terragrunt_dir())
  env    = local.parsed.env
  region = local.parsed.region
  
  # Load environment-specific variables
  env_vars    = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  region_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  
  # Common tags
  common_tags = {
    Environment = local.env
    Region      = local.region
    ManagedBy   = "terragrunt"
    Project     = "eks-platform"
  }
}

# Remote state with environment-specific backends
remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
  config = {
    bucket         = "terraform-state-${local.env}-${local.region}"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = local.region
    encrypt        = true
    dynamodb_table = "terraform-locks-${local.env}"
    
    s3_bucket_tags = local.common_tags
    dynamodb_table_tags = local.common_tags
  }
}

# Auto-generate provider configurations
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = templatefile("${get_terragrunt_dir()}/provider.tmpl", {
    region = local.region
    tags   = local.common_tags
  })
}

# Dependency management
dependencies {
  paths = [
    "../vpc",
    "../security-groups",
    "../iam"
  ]
}
```

---

## 📊 Monitoring and Observability Stack

### **Monitoring Solutions Comparison**

| Solution | Complexity | Cost | Scalability | Integration | Best For |
|----------|------------|------|-------------|-------------|----------|
| **Prometheus + Grafana** | Medium | Free | High | Excellent | Self-managed, customizable |
| **AWS CloudWatch** | Low | Pay-per-use | High | Native | AWS-native, simple setup |
| **Datadog** | Low | High | High | Good | Enterprise, managed service |
| **New Relic** | Low | High | High | Good | APM focus, enterprise |
| **Elastic Stack (ELK)** | High | Free/Paid | Very High | Good | Log analytics, search |

#### **Prometheus Stack Implementation**

```yaml
# monitoring/prometheus-values.yaml
prometheus:
  prometheusSpec:
    # Storage configuration
    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: gp3-retain
          resources:
            requests:
              storage: 100Gi
    
    # Retention and resources
    retention: 30d
    retentionSize: 90GB
    resources:
      requests:
        memory: 2Gi
        cpu: 1000m
      limits:
        memory: 4Gi
        cpu: 2000m
    
    # Additional scrape configurations
    additionalScrapeConfigs:
      - job_name: 'istio-mesh'
        kubernetes_sd_configs:
          - role: endpoints
            namespaces:
              names:
              - istio-system
        relabel_configs:
          - source_labels: [__meta_kubernetes_service_name, __meta_kubernetes_endpoint_port_name]
            action: keep
            regex: istio-telemetry;prometheus
    
    # Rule evaluation
    evaluationInterval: 30s
    ruleSelector:
      matchLabels:
        prometheus: kube-prometheus
        role: alert-rules

grafana:
  # Admin credentials
  adminPassword: ${GRAFANA_ADMIN_PASSWORD}
  
  # Persistence
  persistence:
    enabled: true
    storageClassName: gp3-retain
    size: 20Gi
  
  # Dashboard providers
  dashboardProviders:
    dashboardproviders.yaml:
      apiVersion: 1
      providers:
      - name: 'eks-dashboards'
        orgId: 1
        folder: 'EKS'
        type: file
        disableDeletion: false
        editable: true
        options:
          path: /var/lib/grafana/dashboards/eks
  
  # Data sources
  datasources:
    datasources.yaml:
      apiVersion: 1
      datasources:
      - name: Prometheus
        type: prometheus
        url: http://prometheus-kube-prometheus-prometheus:9090
        access: proxy
        isDefault: true
      - name: Loki
        type: loki
        url: http://loki:3100
        access: proxy

alertmanager:
  alertmanagerSpec:
    storage:
      volumeClaimTemplate:
        spec:
          storageClassName: gp3-retain
          resources:
            requests:
              storage: 10Gi
    
    # Slack integration
    config:
      global:
        slack_api_url: ${SLACK_API_URL}
      route:
        group_by: ['alertname', 'cluster', 'service']
        group_wait: 10s
        group_interval: 10s
        repeat_interval: 1h
        receiver: 'slack-notifications'
      receivers:
      - name: 'slack-notifications'
        slack_configs:
        - channel: '#alerts'
          title: 'EKS Cluster Alert'
          text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'
```

#### **Custom Alerts Configuration**

```yaml
# monitoring/eks-alerts.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: eks-cluster-alerts
  namespace: monitoring
  labels:
    prometheus: kube-prometheus
    role: alert-rules
spec:
  groups:
  - name: eks.cluster
    rules:
    - alert: EKSClusterUnreachable
      expr: up{job="kube-apiserver"} == 0
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "EKS cluster API server is unreachable"
        description: "The EKS cluster API server has been unreachable for more than 5 minutes."
    
    - alert: EKSHighPodCrashRate
      expr: increase(kube_pod_container_status_restarts_total[1h]) > 5
      for: 15m
      labels:
        severity: warning
      annotations:
        summary: "High pod crash rate detected"
        description: "Pod {{ $labels.namespace }}/{{ $labels.pod }} has restarted {{ $value }} times in the last hour."
    
    - alert: EKSNodeHighMemoryUsage
      expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 90
      for: 15m
      labels:
        severity: warning
      annotations:
        summary: "High memory usage on node {{ $labels.instance }}"
        description: "Memory usage is {{ $value }}% on node {{ $labels.instance }}."
    
    - alert: EKSPersistentVolumeUsageHigh
      expr: (kubelet_volume_stats_used_bytes / kubelet_volume_stats_capacity_bytes) * 100 > 85
      for: 10m
      labels:
        severity: warning
      annotations:
        summary: "High persistent volume usage"
        description: "PV {{ $labels.persistentvolumeclaim }} usage is {{ $value }}%."
```

---

## 🔒 Security Tools and Frameworks

### **Security Tool Comparison**

| Tool | Purpose | Complexity | Integration | Cost | Best For |
|------|---------|------------|-------------|------|----------|
| **Falco** | Runtime security | Medium | Native | Free | Threat detection |
| **OPA/Gatekeeper** | Policy enforcement | High | Native | Free | Admission control |
| **Istio** | Service mesh security | High | Native | Free | mTLS, traffic policies |
| **Aqua Security** | Container security | Low | Good | Paid | Enterprise security |
| **Twistlock/Prisma** | Cloud security | Low | Excellent | Paid | Comprehensive security |

#### **Policy as Code with OPA Gatekeeper**

```yaml
# security/constraint-template.yaml
apiVersion: templates.gatekeeper.sh/v1beta1
kind: ConstraintTemplate
metadata:
  name: k8srequiredlabels
spec:
  crd:
    spec:
      names:
        kind: K8sRequiredLabels
      validation:
        type: object
        properties:
          labels:
            type: array
            items:
              type: string
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8srequiredlabels
        
        violation[{"msg": msg}] {
          required := input.parameters.labels
          provided := input.review.object.metadata.labels
          missing := required[_]
          not provided[missing]
          msg := sprintf("Missing required label: %v", [missing])
        }

---
# security/required-labels-constraint.yaml
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequiredLabels
metadata:
  name: must-have-app-label
spec:
  match:
    kinds:
      - apiGroups: ["apps"]
        kinds: ["Deployment", "ReplicaSet"]
  parameters:
    labels: ["app", "version", "environment"]
```

#### **Falco Security Rules**

```yaml
# security/falco-rules.yaml
customRules:
  rules-eks.yaml: |-
    - rule: Unauthorized K8s API Call
      desc: Detect unauthorized calls to K8s API
      condition: ka and non_system_user and ka.verb in (create, update, delete)
      output: Unauthorized K8s API call (user=%ka.user.name verb=%ka.verb uri=%ka.uri reason=%ka.response_reason)
      priority: WARNING
      tags: [k8s]
    
    - rule: Pod Created in Privileged Mode
      desc: Detect pod created with privileged mode
      condition: ka and kcreate and ka.target.subresource exists and ka.target.subresource contains "privileged"
      output: Pod created in privileged mode (user=%ka.user.name pod=%ka.target.name)
      priority: WARNING
      tags: [k8s, security]
    
    - rule: Suspicious Network Activity
      desc: Detect suspicious network connections
      condition: spawned_process and proc.name=nc and proc.args contains "-l"
      output: Suspicious netcat command (user=%user.name command=%proc.cmdline)
      priority: WARNING
      tags: [network, security]
```

---

## 🚀 CI/CD Pipeline Comparison

### **CI/CD Platform Analysis**

| Platform | Complexity | K8s Integration | Cost | Scalability | Best For |
|----------|------------|-----------------|------|-------------|----------|
| **GitHub Actions** | Low | Good | Free/Paid | High | GitHub-centric workflows |
| **Jenkins** | High | Excellent | Free | Very High | Customizable, enterprise |
| **GitLab CI** | Medium | Good | Free/Paid | High | GitLab-centric workflows |
| **Tekton** | High | Native | Free | Very High | Cloud-native, Kubernetes |
| **Argo Workflows** | Medium | Native | Free | High | Kubernetes-native workflows |

#### **GitHub Actions EKS Pipeline**

```yaml
# .github/workflows/eks-deploy.yml
name: EKS Deployment Pipeline

on:
  push:
    branches: [main]
    paths: ['infrastructure/**', 'applications/**']
  pull_request:
    branches: [main]
    paths: ['infrastructure/**', 'applications/**']

env:
  AWS_REGION: us-west-2
  CLUSTER_NAME: eks-prod

jobs:
  infrastructure:
    name: Infrastructure Changes
    runs-on: ubuntu-latest
    if: contains(github.event.head_commit.modified, 'infrastructure/')
    
    steps:
    - name: Checkout
      uses: actions/checkout@v4

    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v4
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: ${{ env.AWS_REGION }}

    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v2
      with:
        terraform_version: 1.5.0

    - name: Setup Terragrunt
      uses: autero1/action-terragrunt@v1.3.0
      with:
        terragrunt_version: 0.50.0

    - name: Terraform Plan
      run: |
        cd infrastructure/environments/prod/${{ env.AWS_REGION }}
        terragrunt run-all plan --terragrunt-non-interactive
      if: github.event_name == 'pull_request'

    - name: Terraform Apply
      run: |
        cd infrastructure/environments/prod/${{ env.AWS_REGION }}
        terragrunt run-all apply --terragrunt-non-interactive
      if: github.ref == 'refs/heads/main'

  applications:
    name: Application Deployment
    runs-on: ubuntu-latest
    needs: infrastructure
    if: always() && (needs.infrastructure.result == 'success' || needs.infrastructure.result == 'skipped')
    
    steps:
    - name: Checkout
      uses: actions/checkout@v4

    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v4
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: ${{ env.AWS_REGION }}

    - name: Setup kubectl
      uses: azure/setup-kubectl@v3
      with:
        version: 'v1.27.0'

    - name: Update kubeconfig
      run: |
        aws eks update-kubeconfig --region ${{ env.AWS_REGION }} --name ${{ env.CLUSTER_NAME }}

    - name: Deploy with ArgoCD
      run: |
        kubectl apply -f applications/argocd/
        kubectl wait --for=condition=Synced application/app-of-apps -n argocd --timeout=600s

    - name: Run smoke tests
      run: |
        kubectl apply -f tests/smoke-tests.yaml
        kubectl wait --for=condition=complete job/smoke-tests --timeout=300s
```

#### **Tekton Cloud-Native Pipeline**

```yaml
# pipelines/eks-deployment-pipeline.yaml
apiVersion: tekton.dev/v1beta1
kind: Pipeline
metadata:
  name: eks-deployment-pipeline
  namespace: tekton-pipelines
spec:
  params:
  - name: git-url
    type: string
  - name: git-revision
    type: string
    default: main
  - name: cluster-name
    type: string
  - name: aws-region
    type: string
    default: us-west-2

  workspaces:
  - name: shared-data
  - name: aws-secrets

  tasks:
  - name: git-clone
    taskRef:
      name: git-clone
    workspaces:
    - name: output
      workspace: shared-data
    params:
    - name: url
      value: $(params.git-url)
    - name: revision
      value: $(params.git-revision)

  - name: terraform-plan
    taskRef:
      name: terraform
    runAfter:
    - git-clone
    workspaces:
    - name: source
      workspace: shared-data
    - name: aws-credentials
      workspace: aws-secrets
    params:
    - name: command
      value: plan
    - name: working-directory
      value: infrastructure/

  - name: terraform-apply
    taskRef:
      name: terraform
    runAfter:
    - terraform-plan
    when:
    - input: $(params.git-revision)
      operator: in
      values: ["main", "master"]
    workspaces:
    - name: source
      workspace: shared-data
    - name: aws-credentials
      workspace: aws-secrets
    params:
    - name: command
      value: apply
    - name: working-directory
      value: infrastructure/

  - name: kubectl-deploy
    taskRef:
      name: kubectl
    runAfter:
    - terraform-apply
    workspaces:
    - name: source
      workspace: shared-data
    - name: aws-credentials
      workspace: aws-secrets
    params:
    - name: script
      value: |
        aws eks update-kubeconfig --region $(params.aws-region) --name $(params.cluster-name)
        kubectl apply -k applications/overlays/production/
```

---

## 📖 Navigation

- **[← Back to Best Practices](./best-practices.md)**
- **[Next: Template Examples →](./template-examples.md)**

---

*Last Updated: July 26, 2025*