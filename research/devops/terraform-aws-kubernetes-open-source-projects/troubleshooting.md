# Troubleshooting: Common Issues and Solutions

This document provides solutions to common issues encountered when implementing Terraform with AWS/Kubernetes/EKS based on experiences from open source projects.

## 🔧 Quick Troubleshooting Checklist

### Before You Start
1. ✅ **Check AWS credentials**: `aws sts get-caller-identity`
2. ✅ **Verify Terraform version**: `terraform version`
3. ✅ **Check kubectl context**: `kubectl config current-context`
4. ✅ **Validate region availability**: Ensure EKS is available in your region
5. ✅ **Check quotas**: Verify AWS service quotas and limits

## 🚨 Terraform Infrastructure Issues

### Issue 1: Terraform Apply Fails with Permission Errors

#### Error Message
```
Error: creating EKS Cluster: AccessDenied: User is not authorized to perform: eks:CreateCluster
```

#### Diagnosis
```bash
# Check current AWS identity
aws sts get-caller-identity

# Check attached policies
aws iam list-attached-user-policies --user-name $(aws sts get-caller-identity --query 'Arn' --output text | cut -d'/' -f2)
```

#### Solution
```hcl
# Required IAM policy for EKS deployment
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "eks:*",
        "ec2:*",
        "iam:CreateRole",
        "iam:AttachRolePolicy",
        "iam:PassRole",
        "iam:CreateInstanceProfile",
        "iam:AddRoleToInstanceProfile",
        "iam:ListAttachedRolePolicies",
        "iam:ListInstanceProfiles",
        "iam:GetRole",
        "iam:GetInstanceProfile",
        "iam:DeleteRole",
        "iam:DetachRolePolicy",
        "iam:DeleteInstanceProfile",
        "iam:RemoveRoleFromInstanceProfile",
        "cloudformation:*",
        "autoscaling:*"
      ],
      "Resource": "*"
    }
  ]
}
```

### Issue 2: VPC CIDR Conflicts

#### Error Message
```
Error: creating VPC: InvalidVpc.Range: The CIDR '10.0.0.0/16' conflicts with another VPC
```

#### Diagnosis and Solution
```hcl
# Check existing VPCs
data "aws_vpcs" "existing" {
  tags = {
    Name = "*"
  }
}

# Use unique CIDR ranges
variable "vpc_cidrs" {
  description = "CIDR blocks for different environments"
  type = map(string)
  default = {
    dev        = "10.10.0.0/16"
    staging    = "10.20.0.0/16"
    production = "10.30.0.0/16"
  }
}

locals {
  vpc_cidr = var.vpc_cidrs[var.environment]
}
```

### Issue 3: Subnet Creation Fails Due to Availability Zone Issues

#### Error Message
```
Error: creating EC2 Subnet: InvalidParameterValue: Value (us-east-1e) for parameter availabilityZone is invalid. Subnets can currently only be created in the following availability zones: us-east-1a, us-east-1b, us-east-1c, us-east-1d, us-east-1f.
```

#### Solution
```hcl
# Dynamically get available AZs
data "aws_availability_zones" "available" {
  state = "available"
  
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

# Use only available AZs
locals {
  azs = slice(data.aws_availability_zones.available.names, 0, min(3, length(data.aws_availability_zones.available.names)))
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  
  azs = local.azs
  # ... other configuration
}
```

### Issue 4: State Lock Issues

#### Error Message
```
Error: Error acquiring the state lock: ConditionalCheckFailedException: The conditional request failed
```

#### Diagnosis and Solution
```bash
# Check DynamoDB table for locks
aws dynamodb scan --table-name terraform-locks --region us-west-2

# Force unlock (use with caution)
terraform force-unlock <LOCK_ID>

# Prevent issues with proper backend configuration
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "eks/terraform.tfstate"
    region         = "us-west-2"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
```

## 🎯 EKS Cluster Issues

### Issue 5: EKS Cluster Creation Timeout

#### Error Message
```
Error: waiting for EKS Cluster to become active: timeout while waiting for state to become 'ACTIVE'
```

#### Diagnosis
```bash
# Check CloudTrail logs
aws logs filter-log-events \
  --log-group-name /aws/eks/cluster-name/cluster \
  --start-time $(date -d '1 hour ago' +%s)000

# Check cluster status
aws eks describe-cluster --name cluster-name --region us-west-2
```

#### Solution
```hcl
# Increase timeout values
resource "aws_eks_cluster" "cluster" {
  # ... configuration
  
  timeouts {
    create = "30m"
    update = "60m"
    delete = "15m"
  }
}

# Ensure proper subnet configuration
resource "aws_subnet" "private" {
  # Must have at least 2 subnets in different AZs
  count = length(local.azs)
  
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(local.vpc_cidr, 8, count.index)
  availability_zone = local.azs[count.index]
  
  # Required tags for EKS
  tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"           = "1"
  }
}
```

### Issue 6: Node Groups Fail to Launch

#### Error Message
```
Error: NodeCreationFailure: Instances failed to join the kubernetes cluster
```

#### Diagnosis
```bash
# Check node group events
aws eks describe-nodegroup \
  --cluster-name my-cluster \
  --nodegroup-name my-nodes \
  --region us-west-2

# Check Auto Scaling Group
aws autoscaling describe-auto-scaling-groups \
  --query 'AutoScalingGroups[?contains(Tags[?Key==`Name`].Value, `eks-node`)]'

# Check EC2 instances
aws ec2 describe-instances \
  --filters "Name=tag:eks:cluster-name,Values=my-cluster" \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name,StateReason.Message]'
```

#### Common Solutions

##### Solution A: Instance Type Not Available
```hcl
# Use multiple instance types for better availability
eks_managed_node_groups = {
  main = {
    instance_types = ["m5.large", "m5a.large", "m4.large"]
    
    # Use spot instances with multiple types
    capacity_type = "SPOT"
    
    # Instance requirements for better spot availability
    use_mixed_instances_policy = true
    mixed_instances_policy = {
      instances_distribution = {
        on_demand_base_capacity                  = 1
        on_demand_percentage_above_base_capacity = 10
        spot_allocation_strategy                 = "capacity-optimized"
      }
    }
  }
}
```

##### Solution B: Insufficient IP Addresses
```hcl
# Ensure sufficient IP addresses in subnets
locals {
  # Calculate subnet sizes based on expected node count
  subnet_count = length(local.azs)
  subnet_bits  = ceil(log(var.max_node_count / local.subnet_count * 2, 2))
}

resource "aws_subnet" "private" {
  count = local.subnet_count
  
  vpc_id     = aws_vpc.main.id
  cidr_block = cidrsubnet(local.vpc_cidr, local.subnet_bits, count.index)
  
  # ... other configuration
}
```

##### Solution C: Security Group Issues
```hcl
# Ensure proper security group rules
resource "aws_security_group_rule" "cluster_ingress_node_https" {
  description              = "Allow pods to communicate with the cluster API Server"
  from_port                = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.cluster.id
  source_security_group_id = aws_security_group.node.id
  to_port                  = 443
  type                     = "ingress"
}

resource "aws_security_group_rule" "node_ingress_self" {
  description              = "Allow node to communicate with each other"
  from_port                = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.node.id
  source_security_group_id = aws_security_group.node.id
  to_port                  = 65535
  type                     = "ingress"
}
```

## 🔑 Authentication and Access Issues

### Issue 7: kubectl Access Denied

#### Error Message
```
error: You must be logged in to the server (Unauthorized)
```

#### Diagnosis and Solutions

##### Solution A: Update kubeconfig
```bash
# Update kubeconfig with correct profile
aws eks update-kubeconfig \
  --region us-west-2 \
  --name my-cluster \
  --profile my-aws-profile

# Verify current context
kubectl config current-context

# Check if cluster is accessible
kubectl cluster-info
```

##### Solution B: IAM User Not in aws-auth ConfigMap
```bash
# Check current AWS identity
aws sts get-caller-identity

# Add user to aws-auth ConfigMap
kubectl edit configmap aws-auth -n kube-system
```

```yaml
# Add to mapUsers section
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapUsers: |
    - userarn: arn:aws:iam::ACCOUNT:user/USERNAME
      username: USERNAME
      groups:
        - system:masters
```

##### Solution C: Cross-Account Access
```hcl
# Terraform configuration for cross-account access
aws_auth_roles = [
  {
    rolearn  = "arn:aws:iam::EXTERNAL-ACCOUNT:role/EKSAccessRole"
    username = "external-admin"
    groups   = ["system:masters"]
  }
]
```

### Issue 8: IRSA (IAM Roles for Service Accounts) Not Working

#### Error Message in Pod Logs
```
An error occurred (AccessDenied) when calling the AssumeRoleWithWebIdentity operation
```

#### Diagnosis
```bash
# Check OIDC provider
aws eks describe-cluster --name my-cluster --query 'cluster.identity.oidc.issuer'

# Check IAM role trust policy
aws iam get-role --role-name my-service-role --query 'Role.AssumeRolePolicyDocument'

# Check service account annotations
kubectl describe sa my-service-account -n my-namespace
```

#### Solution
```hcl
# Correct IRSA configuration
module "irsa_role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  
  role_name = "my-service-role"
  
  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["my-namespace:my-service-account"]
    }
  }
  
  role_policy_arns = {
    policy = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
  }
}

# Service account with correct annotations
resource "kubernetes_service_account" "service_account" {
  metadata {
    name      = "my-service-account"
    namespace = "my-namespace"
    
    annotations = {
      "eks.amazonaws.com/role-arn" = module.irsa_role.iam_role_arn
    }
  }
}
```

## 🚀 Application Deployment Issues

### Issue 9: Pods Stuck in Pending State

#### Diagnosis
```bash
# Check pod status and events
kubectl describe pod <pod-name> -n <namespace>

# Check node resources
kubectl top nodes
kubectl describe nodes

# Check pod resource requests
kubectl get pods -o wide --all-namespaces
```

#### Common Causes and Solutions

##### Solution A: Insufficient Resources
```yaml
# Check and adjust resource requests
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      containers:
      - name: app
        resources:
          requests:
            memory: "64Mi"    # Reduce if too high
            cpu: "250m"       # Reduce if too high
          limits:
            memory: "128Mi"
            cpu: "500m"
```

##### Solution B: Node Selector Issues
```bash
# Check node labels
kubectl get nodes --show-labels

# Update node selector or remove it
kubectl patch deployment myapp -p '{"spec":{"template":{"spec":{"nodeSelector":null}}}}'
```

##### Solution C: Taints and Tolerations
```bash
# Check node taints
kubectl describe nodes | grep -i taint

# Add tolerations to deployment
```

```yaml
spec:
  template:
    spec:
      tolerations:
      - key: "node.kubernetes.io/not-ready"
        operator: "Exists"
        effect: "NoExecute"
        tolerationSeconds: 300
```

### Issue 10: Load Balancer Not Accessible

#### Error Message
```
Service external IP remains <pending>
```

#### Diagnosis and Solutions

##### Check AWS Load Balancer Controller
```bash
# Check if AWS Load Balancer Controller is running
kubectl get pods -n kube-system | grep aws-load-balancer-controller

# Check controller logs
kubectl logs -n kube-system deployment/aws-load-balancer-controller

# Check service annotations
kubectl describe svc my-service
```

##### Solution: Correct Service Configuration
```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-service
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
    service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
    service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: "true"
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 8080
  selector:
    app: my-app
```

## 📊 Monitoring and Observability Issues

### Issue 11: Prometheus Not Scraping Metrics

#### Diagnosis
```bash
# Check Prometheus targets
kubectl port-forward -n monitoring svc/prometheus-server 9090:80
# Navigate to http://localhost:9090/targets

# Check service monitor configuration
kubectl get servicemonitor -n monitoring
kubectl describe servicemonitor my-app -n monitoring
```

#### Solution
```yaml
# Correct ServiceMonitor configuration
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: my-app
  namespace: monitoring
  labels:
    release: prometheus  # Must match Prometheus selector
spec:
  selector:
    matchLabels:
      app: my-app
  endpoints:
  - port: metrics
    path: /metrics
    interval: 30s
```

### Issue 12: Grafana Dashboards Not Loading

#### Diagnosis
```bash
# Check Grafana pod status
kubectl get pods -n monitoring | grep grafana

# Check Grafana logs
kubectl logs -n monitoring deployment/grafana

# Check ConfigMap for dashboards
kubectl get configmap -n monitoring | grep dashboard
```

#### Solution
```yaml
# Correct dashboard ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: my-dashboard
  namespace: monitoring
  labels:
    grafana_dashboard: "1"  # Required label
data:
  dashboard.json: |
    {
      "dashboard": {
        "title": "My Application",
        "panels": [...]
      }
    }
```

## 🔄 CI/CD and GitOps Issues

### Issue 13: ArgoCD Application Sync Failures

#### Error Message
```
ComparisonError: failed to unmarshal manifest: error unmarshaling JSON: while decoding JSON: json: unknown field "replicas"
```

#### Diagnosis
```bash
# Check ArgoCD application status
kubectl get application -n argocd

# Check application details
kubectl describe application my-app -n argocd

# Check ArgoCD server logs
kubectl logs -n argocd deployment/argocd-server
```

#### Solution
```yaml
# Correct Application manifest
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: argocd
spec:
  project: default
  
  source:
    repoURL: https://github.com/my-org/my-app
    targetRevision: HEAD
    path: k8s/overlays/production
  
  destination:
    server: https://kubernetes.default.svc
    namespace: my-app
  
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
```

## 🔧 Performance Issues

### Issue 14: Cluster Autoscaler Not Scaling

#### Diagnosis
```bash
# Check Cluster Autoscaler logs
kubectl logs -n kube-system deployment/cluster-autoscaler

# Check node group configuration
aws eks describe-nodegroup --cluster-name my-cluster --nodegroup-name my-nodes

# Check pending pods
kubectl get pods --all-namespaces | grep Pending
```

#### Solution
```hcl
# Ensure proper tags on node group
eks_managed_node_groups = {
  main = {
    # Required tags for cluster autoscaler
    tags = {
      "k8s.io/cluster-autoscaler/enabled" = "true"
      "k8s.io/cluster-autoscaler/${var.cluster_name}" = "owned"
    }
    
    # Proper scaling configuration
    min_size     = 1
    max_size     = 100  # Ensure max_size is sufficient
    desired_size = 3
  }
}
```

### Issue 15: High Memory Usage on Nodes

#### Diagnosis
```bash
# Check node resource usage
kubectl top nodes
kubectl describe nodes

# Check resource requests vs limits
kubectl describe pods --all-namespaces | grep -E "Requests|Limits" -A 5

# Check system pods resource usage
kubectl top pods -n kube-system
```

#### Solution
```yaml
# Optimize resource requests and limits
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      containers:
      - name: app
        resources:
          requests:
            memory: "128Mi"   # Set reasonable requests
            cpu: "100m"
          limits:
            memory: "256Mi"   # Set limits to prevent OOM
            cpu: "500m"
```

## 📝 General Debugging Commands

### Essential Troubleshooting Commands

```bash
# Cluster information
kubectl cluster-info
kubectl get nodes -o wide
kubectl get pods --all-namespaces

# Check system pods
kubectl get pods -n kube-system
kubectl get pods -n kube-public

# Events across cluster
kubectl get events --all-namespaces --sort-by='.lastTimestamp'

# Resource usage
kubectl top nodes
kubectl top pods --all-namespaces

# Networking
kubectl get svc --all-namespaces
kubectl get ingress --all-namespaces

# Storage
kubectl get pv
kubectl get pvc --all-namespaces

# RBAC
kubectl auth can-i --list
kubectl get rolebindings,clusterrolebindings --all-namespaces

# Custom resources
kubectl get crd
kubectl api-resources
```

### Log Collection Scripts

```bash
#!/bin/bash
# collect-logs.sh

NAMESPACE=${1:-default}
OUTPUT_DIR="debug-$(date +%Y%m%d-%H%M%S)"

mkdir -p $OUTPUT_DIR

echo "Collecting cluster information..."
kubectl cluster-info > $OUTPUT_DIR/cluster-info.txt
kubectl get nodes -o wide > $OUTPUT_DIR/nodes.txt
kubectl describe nodes > $OUTPUT_DIR/nodes-describe.txt

echo "Collecting pod information..."
kubectl get pods -n $NAMESPACE -o wide > $OUTPUT_DIR/pods.txt
kubectl describe pods -n $NAMESPACE > $OUTPUT_DIR/pods-describe.txt

echo "Collecting events..."
kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp' > $OUTPUT_DIR/events.txt

echo "Collecting logs for failed pods..."
for pod in $(kubectl get pods -n $NAMESPACE --field-selector=status.phase=Failed -o jsonpath='{.items[*].metadata.name}'); do
  kubectl logs $pod -n $NAMESPACE > $OUTPUT_DIR/$pod-logs.txt 2>&1
done

echo "Debug information collected in $OUTPUT_DIR/"
```

---

## 🔗 Navigation

| Previous | Current | Next |
|----------|---------|------|
| [Security Considerations](./security-considerations.md) | **Troubleshooting** | [README](./README.md) |

---

*Keep this troubleshooting guide handy during deployments. Many issues can be quickly resolved with proper diagnosis and the solutions provided here.*