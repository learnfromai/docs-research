# Troubleshooting Guide: Common Issues and Solutions

A comprehensive troubleshooting guide based on issues commonly encountered in 60+ production-ready open source projects.

## 🚨 Quick Diagnostics

### Emergency Checklist
When something goes wrong, follow this rapid diagnostic process:

```bash
# 1. Check cluster status
kubectl get nodes
kubectl get pods --all-namespaces | grep -v Running

# 2. Check Terraform state
terraform plan
terraform refresh

# 3. Check AWS resources
aws eks describe-cluster --name <cluster-name> --region <region>
aws ec2 describe-instances --filters "Name=tag:kubernetes.io/cluster/<cluster-name>,Values=owned"

# 4. Check logs
kubectl logs -n kube-system deployment/coredns
aws logs describe-log-groups --log-group-name-prefix "/aws/eks"
```

---

## 🔧 Terraform Issues

### Issue 1: Terraform State Conflicts

#### **Symptoms**
```bash
Error: Error acquiring the state lock: ConditionalCheckFailedException
```

#### **Cause**
- Multiple Terraform runs executing simultaneously
- Previous run interrupted without releasing lock
- DynamoDB table issues

#### **Solution**
```bash
# Option 1: Force unlock (use with caution)
terraform force-unlock <LOCK_ID>

# Option 2: Check and clear DynamoDB locks
aws dynamodb scan --table-name terraform-locks
aws dynamodb delete-item --table-name terraform-locks --key '{"LockID":{"S":"<lock-id>"}}'

# Option 3: Verify backend configuration
terraform init -backend-config="bucket=my-terraform-state" \
                -backend-config="key=path/to/state" \
                -backend-config="region=us-west-2"
```

#### **Prevention**
```hcl
# Use workspace for team collaboration
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "env:/terraform.tfstate"
    region         = "us-west-2"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}

# Implement proper CI/CD with mutex
# .github/workflows/terraform.yml
- name: Terraform Plan
  run: |
    terraform plan -lock-timeout=300s
```

### Issue 2: Provider Version Conflicts

#### **Symptoms**
```bash
Error: Failed to install provider
Error: Could not retrieve the list of available versions
```

#### **Cause**
- Terraform version incompatibility
- Provider version constraints too restrictive
- Network connectivity issues

#### **Solution**
```hcl
# Fix version constraints
terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"  # Allow minor updates
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"  
      version = ">= 2.20.0, < 3.0.0"   # Explicit range
    }
  }
}

# Clear provider cache if needed
rm -rf .terraform
terraform init
```

### Issue 3: Resource Dependencies

#### **Symptoms**
```bash
Error: Error creating EKS Cluster: InvalidParameterException: 
The provided subnet does not exist
```

#### **Cause**
- Implicit dependencies not properly defined
- Resources created in wrong order
- Missing `depends_on` declarations

#### **Solution**
```hcl
# Explicit dependencies
resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = aws_iam_role.cluster_role.arn

  vpc_config {
    subnet_ids = module.vpc.private_subnets
  }

  # Explicit dependency
  depends_on = [
    aws_iam_role_policy_attachment.cluster_policy,
    module.vpc
  ]
}

# Use data sources for existing resources
data "aws_vpc" "existing" {
  id = var.vpc_id
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.existing.id]
  }
  
  filter {
    name   = "tag:Type"
    values = ["private"]
  }
}
```

---

## ☸️ Kubernetes Issues

### Issue 4: Pods Not Scheduling

#### **Symptoms**
```bash
kubectl get pods
NAME        READY   STATUS    RESTARTS   AGE
app-pod     0/1     Pending   0          5m
```

#### **Diagnostic Commands**
```bash
# Check pod details
kubectl describe pod <pod-name>

# Check node resources
kubectl top nodes
kubectl describe nodes

# Check node conditions
kubectl get nodes -o custom-columns=NAME:.metadata.name,STATUS:.status.conditions[-1].type,REASON:.status.conditions[-1].reason
```

#### **Common Causes & Solutions**

##### **Resource Constraints**
```bash
# Check resource requests vs available
kubectl describe nodes | grep -A 5 "Allocated resources"

# Solution: Reduce resource requests or add nodes
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      containers:
      - name: app
        resources:
          requests:
            cpu: 100m      # Reduced from 1000m
            memory: 128Mi  # Reduced from 1Gi
```

##### **Node Affinity Issues**
```bash
# Check node labels
kubectl get nodes --show-labels

# Solution: Fix node selectors
spec:
  nodeSelector:
    kubernetes.io/instance-type: t3.medium  # Ensure nodes have this label
```

##### **Taints and Tolerations**
```bash
# Check node taints
kubectl describe nodes | grep -i taint

# Solution: Add tolerations
spec:
  tolerations:
  - key: "spot"
    operator: "Equal"
    value: "true"
    effect: "NoSchedule"
```

### Issue 5: Service Discovery Problems

#### **Symptoms**
```bash
# Cannot reach services by name
curl: (6) Could not resolve host: backend-service
```

#### **Diagnostic Commands**
```bash
# Check services
kubectl get services -A

# Check endpoints
kubectl get endpoints <service-name>

# Check CoreDNS
kubectl get pods -n kube-system | grep coredns
kubectl logs -n kube-system deployment/coredns
```

#### **Solutions**

##### **CoreDNS Configuration**
```yaml
# Check CoreDNS ConfigMap
kubectl get configmap coredns -n kube-system -o yaml

# Common fix: Update CoreDNS
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns
  namespace: kube-system
data:
  Corefile: |
    .:53 {
        errors
        health {
           lameduck 5s
        }
        ready
        kubernetes cluster.local in-addr.arpa ip6.arpa {
           pods insecure
           fallthrough in-addr.arpa ip6.arpa
           ttl 30
        }
        prometheus :9153
        forward . /etc/resolv.conf
        cache 30
        loop
        reload
        loadbalance
    }
```

##### **Service Configuration**
```yaml
# Ensure proper service setup
apiVersion: v1
kind: Service
metadata:
  name: backend-service
spec:
  selector:
    app: backend  # Must match pod labels
  ports:
  - port: 80
    targetPort: 8080
    protocol: TCP
```

### Issue 6: Ingress Not Working

#### **Symptoms**
- External traffic not reaching services
- 404 or 503 errors from load balancer
- SSL certificate issues

#### **Diagnostic Commands**
```bash
# Check ingress controller
kubectl get pods -n ingress-nginx
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller

# Check ingress resources
kubectl get ingress -A
kubectl describe ingress <ingress-name>

# Check AWS Load Balancer
aws elbv2 describe-load-balancers
aws elbv2 describe-target-groups
```

#### **Solutions**

##### **AWS Load Balancer Controller Issues**
```bash
# Check if controller is running
kubectl get deployment -n kube-system aws-load-balancer-controller

# Check logs
kubectl logs -n kube-system deployment/aws-load-balancer-controller

# Common fix: Update IAM permissions
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "elbv2:*",
        "ec2:DescribeSubnets",
        "ec2:DescribeSecurityGroups"
      ],
      "Resource": "*"
    }
  ]
}
```

##### **Ingress Configuration**
```yaml
# Proper ingress setup
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-ingress
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS":443}]'
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:region:account:certificate/cert-id
spec:
  rules:
  - host: myapp.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend-service
            port:
              number: 80
```

---

## 🌐 AWS Integration Issues

### Issue 7: EKS Node Groups Failing

#### **Symptoms**
```bash
# Nodes not joining cluster
kubectl get nodes  # No nodes or nodes in NotReady state
```

#### **Diagnostic Commands**
```bash
# Check node group status
aws eks describe-nodegroup --cluster-name <cluster> --nodegroup-name <nodegroup>

# Check node group events
aws eks describe-nodegroup --cluster-name <cluster> --nodegroup-name <nodegroup> --query 'nodegroup.health'

# Check EC2 instances
aws ec2 describe-instances --filters "Name=tag:eks:cluster-name,Values=<cluster-name>"
```

#### **Common Causes & Solutions**

##### **IAM Role Issues**
```json
// Ensure proper IAM policies attached
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}

// Required policies:
// - AmazonEKSWorkerNodePolicy  
// - AmazonEKS_CNI_Policy
// - AmazonEC2ContainerRegistryReadOnly
```

##### **Subnet Configuration**
```bash
# Check subnet tags - required for EKS
aws ec2 describe-subnets --subnet-ids <subnet-id> --query 'Subnets[0].Tags'

# Required tags:
# kubernetes.io/cluster/<cluster-name> = shared|owned
# kubernetes.io/role/internal-elb = 1 (for private subnets)
# kubernetes.io/role/elb = 1 (for public subnets)
```

##### **Security Group Rules**
```hcl
# Ensure proper security group rules
resource "aws_security_group_rule" "cluster_ingress_workstation_https" {
  description              = "Allow workstation to communicate with the cluster API Server"
  from_port                = 443
  protocol                 = "tcp"
  security_group_id        = aws_eks_cluster.cluster.vpc_config[0].cluster_security_group_id
  source_security_group_id = aws_security_group.workstation.id
  to_port                  = 443
  type                     = "ingress"
}
```

### Issue 8: IRSA (IAM Roles for Service Accounts) Problems

#### **Symptoms**
```bash
# Pods cannot access AWS services
# Error: AccessDenied, UnauthorizedOperation
```

#### **Diagnostic Commands**
```bash
# Check OIDC provider
aws eks describe-cluster --name <cluster-name> --query 'cluster.identity.oidc.issuer'
aws iam list-open-id-connect-providers

# Check service account annotations
kubectl describe serviceaccount <sa-name> -n <namespace>

# Test permissions from pod
kubectl exec -it <pod-name> -- aws sts get-caller-identity
```

#### **Solution**
```hcl
# Proper IRSA setup
module "irsa_role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name = "aws-load-balancer-controller"

  attach_load_balancer_controller_policy = true

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
}

# Service account with proper annotation
resource "kubernetes_service_account" "aws_load_balancer_controller" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = module.irsa_role.iam_role_arn
    }
  }
}
```

---

## 🔄 GitOps Issues

### Issue 9: FluxCD Reconciliation Failures

#### **Symptoms**
```bash
# Resources not updating from Git
flux get sources git
flux get kustomizations
```

#### **Diagnostic Commands**
```bash
# Check Flux system status
kubectl get pods -n flux-system

# Check source status
flux get sources git --all-namespaces

# Check reconciliation status
flux get kustomizations --all-namespaces

# View events
kubectl get events -n flux-system --sort-by='.lastTimestamp'
```

#### **Common Solutions**

##### **Git Access Issues**
```bash
# Check SSH key
flux get sources git <source-name> -o yaml

# Recreate SSH secret
flux create secret git <secret-name> \
  --url=ssh://git@github.com/owner/repo \
  --ssh-key-algorithm=rsa \
  --ssh-rsa-bits=4096

# Update GitRepository
flux create source git <source-name> \
  --url=ssh://git@github.com/owner/repo \
  --branch=main \
  --secret-ref=<secret-name>
```

##### **Kustomization Errors**
```yaml
# Fix kustomization syntax
apiVersion: kustomize.toolkit.fluxcd.io/v1beta2
kind: Kustomization
metadata:
  name: apps
  namespace: flux-system
spec:
  interval: 10m
  sourceRef:
    kind: GitRepository
    name: flux-system
  path: "./clusters/production"
  prune: true
  wait: true
  timeout: 5m
```

### Issue 10: Terraform Controller Issues

#### **Symptoms**
```bash
# Terraform resources not applying
kubectl get terraform -A
```

#### **Diagnostic Commands**
```bash
# Check Tofu Controller logs
kubectl logs -n flux-system deployment/tofu-controller

# Check Terraform resource status
kubectl describe terraform <terraform-name> -n <namespace>

# Check runner pods
kubectl get pods -l app.kubernetes.io/name=tofu-controller
```

#### **Solutions**

##### **Resource Configuration**
```yaml
# Proper Terraform resource definition
apiVersion: infra.contrib.fluxcd.io/v1alpha1
kind: Terraform
metadata:
  name: helloworld
  namespace: flux-system
spec:
  interval: 1m
  path: ./terraform
  sourceRef:
    kind: GitRepository
    name: helloworld
    namespace: flux-system
  vars:
    - name: subject
      value: "Hello World"
  writeOutputsToSecret:
    name: helloworld-outputs
  runnerPodTemplate:
    spec:
      resources:
        limits:
          cpu: 200m
          memory: 256Mi
        requests:
          cpu: 100m
          memory: 128Mi
```

---

## 🔍 Monitoring and Debugging

### Issue 11: Prometheus Not Scraping Metrics

#### **Symptoms**
- Missing metrics in Grafana
- Prometheus targets down
- High cardinality warnings

#### **Diagnostic Commands**
```bash
# Check Prometheus targets
kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090
# Visit http://localhost:9090/targets

# Check service monitors
kubectl get servicemonitor -A

# Check prometheus logs
kubectl logs -n monitoring prometheus-kube-prometheus-stack-prometheus-0
```

#### **Solutions**

##### **Service Monitor Configuration**
```yaml
# Proper ServiceMonitor setup
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: app-metrics
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: myapp
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
```

##### **Prometheus Configuration**
```yaml
# Check Prometheus config
kubectl get secret prometheus-kube-prometheus-stack-prometheus -n monitoring -o yaml
```

### Issue 12: Log Aggregation Problems

#### **Symptoms**
- Logs not appearing in centralized system
- High memory usage on nodes
- Log parsing errors

#### **Diagnostic Commands**
```bash
# Check Fluent Bit status
kubectl get pods -n logging | grep fluent

# Check logs
kubectl logs -n logging daemonset/fluent-bit

# Check CloudWatch log groups
aws logs describe-log-groups --log-group-name-prefix "/aws/eks"
```

#### **Solutions**

##### **Fluent Bit Configuration**
```yaml
# Proper Fluent Bit setup
apiVersion: v1
kind: ConfigMap
metadata:
  name: fluent-bit-config
data:
  fluent-bit.conf: |
    [SERVICE]
        Flush         1
        Log_Level     info
        Daemon        off
        Parsers_File  parsers.conf

    [INPUT]
        Name              tail
        Tag               kube.*
        Path              /var/log/containers/*.log
        Parser            docker
        DB                /var/log/flb_kube.db
        Mem_Buf_Limit     50MB

    [OUTPUT]
        Name cloudwatch_logs
        Match *
        region us-west-2
        log_group_name /aws/eks/cluster-name/application
        auto_create_group true
```

---

## 💰 Cost Optimization Issues

### Issue 13: Unexpected AWS Costs

#### **Symptoms**
- Higher than expected AWS bills
- NAT Gateway costs
- EBS volume costs

#### **Diagnostic Commands**
```bash
# Check running resources
aws ec2 describe-instances --query 'Reservations[].Instances[?State.Name==`running`]'
aws elbv2 describe-load-balancers
aws ec2 describe-nat-gateways

# Check EBS volumes
aws ec2 describe-volumes --filters "Name=state,Values=available"
```

#### **Solutions**

##### **Spot Instance Configuration**
```hcl
# Use spot instances for non-critical workloads
eks_managed_node_groups = {
  spot = {
    instance_types = ["m5.large", "m5.xlarge", "m4.large"]
    capacity_type  = "SPOT"
    
    min_size     = 0
    max_size     = 10
    desired_size = 3
    
    # Spot instance interruption handling
    taints = [
      {
        key    = "spot"
        value  = "true"
        effect = "NO_SCHEDULE"
      }
    ]
  }
}
```

##### **Resource Cleanup**
```bash
# Clean up unused resources
# Delete unused EBS volumes
aws ec2 describe-volumes --filters "Name=state,Values=available" --query 'Volumes[].VolumeId' --output text | xargs -I {} aws ec2 delete-volume --volume-id {}

# Clean up unused security groups
aws ec2 describe-security-groups --query 'SecurityGroups[?length(IpPermissions)==`0` && length(IpPermissionsEgress)==`1`].GroupId' --output text
```

---

## 🚨 Emergency Procedures

### Complete Cluster Recovery

#### **When to Use**
- Cluster completely unresponsive
- Control plane issues
- Mass node failures

#### **Recovery Steps**
```bash
# 1. Assess the situation
aws eks describe-cluster --name <cluster-name>
aws eks describe-nodegroup --cluster-name <cluster-name> --nodegroup-name <nodegroup-name>

# 2. Check etcd backup (if available)
aws s3 ls s3://my-etcd-backups/

# 3. Restore from Terraform state
cd terraform/
terraform refresh
terraform plan
terraform apply

# 4. Restore applications from GitOps
flux resume source git flux-system
flux resume kustomization apps
```

### Data Recovery

#### **Persistent Volume Recovery**
```bash
# Check PV status
kubectl get pv

# Create PV from existing EBS volume
apiVersion: v1
kind: PersistentVolume
metadata:
  name: recovered-pv
spec:
  capacity:
    storage: 100Gi
  accessModes:
    - ReadWriteOnce
  awsElasticBlockStore:
    volumeID: vol-1234567890abcdef0
    fsType: ext4
```

---

## 📚 Additional Resources

### Debugging Tools
```bash
# Install useful debugging tools
kubectl apply -f https://raw.githubusercontent.com/nicolaka/netshoot/master/netshoot.yaml

# Debug DNS issues
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup kubernetes.default

# Debug network connectivity
kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -- bash
```

### Monitoring Commands
```bash
# Resource usage
kubectl top nodes
kubectl top pods --all-namespaces

# Cluster events
kubectl get events --all-namespaces --sort-by='.lastTimestamp'

# Node conditions
kubectl get nodes -o custom-columns=NAME:.metadata.name,STATUS:.status.conditions[-1].type,REASON:.status.conditions[-1].reason
```

### Log Analysis
```bash
# Tail logs from multiple pods
kubectl logs -f deployment/app --all-containers=true

# Search logs for errors
kubectl logs deployment/app | grep -i error

# Export logs for analysis
kubectl logs deployment/app > app.log
```

---

## 🔗 Quick Reference Links

### Project-Specific Troubleshooting
- [terraform-aws-eks Issues](https://github.com/terraform-aws-modules/terraform-aws-eks/issues)
- [FluxCD Troubleshooting](https://fluxcd.io/docs/troubleshooting/)
- [EKS Troubleshooting](https://docs.aws.amazon.com/eks/latest/userguide/troubleshooting.html)

### Community Resources
- **Kubernetes Slack** - #troubleshooting channel
- **AWS Forums** - EKS specific discussions
- **Stack Overflow** - Terraform and Kubernetes tags

---

## Navigation
← [Learning Path](./learning-path.md) | → [Template Examples](./template-examples.md) | ↑ [README](./README.md)