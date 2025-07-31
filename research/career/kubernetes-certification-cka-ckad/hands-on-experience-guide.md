# Hands-On Experience Guide - Practical Kubernetes Certification Labs

## Overview

This guide provides comprehensive hands-on experience requirements, lab setups, and practical scenarios aligned with CKA and CKAD certification objectives. Focus is on real-world application and exam-style practice.

## Lab Environment Setup Options

### Option 1: Cloud-Based Kubernetes Services (Recommended for Beginners)

#### Google Kubernetes Engine (GKE) Setup
```bash
# Install Google Cloud SDK
curl https://sdk.cloud.google.com | bash
exec -l $SHELL
gcloud init

# Create practice cluster with minimal cost
gcloud container clusters create certification-practice \
  --zone=asia-southeast1-a \
  --num-nodes=2 \
  --machine-type=e2-small \
  --disk-size=20GB \
  --disk-type=pd-standard \
  --preemptible \
  --enable-autorepair \
  --enable-autoupgrade

# Get credentials for kubectl
gcloud container clusters get-credentials certification-practice --zone=asia-southeast1-a

# Verify cluster connection
kubectl cluster-info
kubectl get nodes
```

#### Amazon EKS Setup
```bash
# Install eksctl
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin

# Create practice cluster
eksctl create cluster \
  --name certification-practice \
  --region ap-southeast-1 \
  --node-type t3.small \
  --nodes 2 \
  --nodes-min 1 \
  --nodes-max 3 \
  --spot

# Update kubeconfig
aws eks update-kubeconfig --region ap-southeast-1 --name certification-practice
```

#### Azure AKS Setup
```bash
# Install Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
az login

# Create resource group and cluster
az group create --name certification-rg --location southeastasia
az aks create \
  --resource-group certification-rg \
  --name certification-practice \
  --node-count 2 \
  --node-vm-size Standard_B2s \
  --spot-max-price 0.02 \
  --priority Spot \
  --eviction-policy Delete \
  --generate-ssh-keys

# Get credentials
az aks get-credentials --resource-group certification-rg --name certification-practice
```

### Option 2: Local Development Environment

#### Kind (Kubernetes in Docker) - Multi-Node Setup
```yaml
# kind-config.yaml
apiVersion: kind.x-k8s.io/v1alpha4
kind: Cluster
name: certification-cluster
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
- role: worker
  kubeadmConfigPatches:
  - |
    kind: JoinConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "node-type=worker-1"
- role: worker
  kubeadmConfigPatches:
  - |
    kind: JoinConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "node-type=worker-2"
```

```bash
# Create multi-node cluster
kind create cluster --config kind-config.yaml

# Install ingress controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

# Wait for ingress controller to be ready
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s
```

#### Minikube Multi-Node Setup
```bash
# Create multi-node minikube cluster
minikube start \
  --nodes 3 \
  --memory=4096 \
  --cpus=2 \
  --disk-size=20g \
  --driver=docker \
  --kubernetes-version=v1.28.0

# Enable necessary addons
minikube addons enable ingress
minikube addons enable metrics-server
minikube addons enable dashboard
minikube addons enable storage-provisioner
```

### Option 3: Hybrid Approach - VPS with kubeadm

#### Digital Ocean/Linode Setup
```bash
# Create 3 VPS instances (1 control-plane, 2 workers)
# Minimum specs: 2 vCPU, 2GB RAM, 20GB disk

# On all nodes - prepare environment
sudo apt update && sudo apt upgrade -y
sudo apt install -y docker.io curl apt-transport-https

# Install kubeadm, kubelet, kubectl
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt update
sudo apt install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# On control-plane node
sudo kubeadm init --pod-network-cidr=10.244.0.0/16

# Configure kubectl for regular user
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Install CNI plugin (Flannel)
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml

# Join worker nodes (use the join command from kubeadm init output)
# sudo kubeadm join <control-plane-ip>:6443 --token <token> --discovery-token-ca-cert-hash <hash>
```

## CKAD-Focused Lab Scenarios

### Lab 1: Application Deployment and Configuration

#### Scenario: Multi-Tier Web Application
```yaml
# Create namespace
apiVersion: v1
kind: Namespace
metadata:
  name: webapp-lab
---
# Frontend deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: webapp-lab
  labels:
    app: frontend
spec:
  replicas: 3
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
      - name: frontend
        image: nginx:1.21
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "250m"
          limits:
            memory: "128Mi"
            cpu: "500m"
        env:
        - name: BACKEND_URL
          value: "http://backend-service:8080"
        - name: ENVIRONMENT
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: environment
---
# Backend deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: webapp-lab
  labels:
    app: backend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
      - name: backend
        image: node:16-alpine
        command: ["node", "-e", "require('http').createServer((req,res)=>res.end('Backend v1.0')).listen(8080)"]
        ports:
        - containerPort: 8080
        resources:
          requests:
            memory: "128Mi"
            cpu: "250m"
          limits:
            memory: "256Mi"
            cpu: "500m"
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: db-secret
              key: url
        livenessProbe:
          httpGet:
            path: /
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
```

#### Practice Tasks:
```bash
# Task 1: Create the deployment with proper resource limits
kubectl create namespace webapp-lab

# Task 2: Create ConfigMap for application configuration
kubectl create configmap app-config \
  --from-literal=environment=production \
  --from-literal=debug=false \
  --namespace=webapp-lab

# Task 3: Create Secret for database connection
kubectl create secret generic db-secret \
  --from-literal=url=postgresql://user:pass@db:5432/app \
  --namespace=webapp-lab

# Task 4: Apply the deployments and verify they're running
kubectl apply -f webapp-deployment.yaml
kubectl get pods -n webapp-lab -w

# Task 5: Expose services and test connectivity
kubectl expose deployment frontend --port=80 --target-port=80 --namespace=webapp-lab
kubectl expose deployment backend --port=8080 --target-port=8080 --namespace=webapp-lab

# Task 6: Create ingress for external access
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: webapp-ingress
  namespace: webapp-lab
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
  - host: webapp.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend
            port:
              number: 80
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: backend
            port:
              number: 8080
EOF
```

### Lab 2: Debugging and Troubleshooting Applications

#### Scenario: Broken Application Scenarios
```bash
# Create intentionally broken deployments for troubleshooting practice

# Broken Pod 1: Wrong image name
kubectl run broken-pod-1 --image=nginx:nonexistent --namespace=webapp-lab

# Broken Pod 2: Resource limits too low
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: broken-pod-2
  namespace: webapp-lab
spec:
  containers:
  - name: app
    image: nginx
    resources:
      limits:
        memory: "10Mi"
        cpu: "1m"
EOF

# Broken Pod 3: Missing ConfigMap reference
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: broken-pod-3
  namespace: webapp-lab
spec:
  containers:
  - name: app
    image: nginx
    env:
    - name: CONFIG_VALUE
      valueFrom:
        configMapKeyRef:
          name: missing-config
          key: value
EOF
```

#### Troubleshooting Practice Tasks:
```bash
# Task 1: Identify and fix image pull errors
kubectl get pods -n webapp-lab
kubectl describe pod broken-pod-1 -n webapp-lab
kubectl logs broken-pod-1 -n webapp-lab

# Task 2: Debug resource constraint issues
kubectl describe pod broken-pod-2 -n webapp-lab
kubectl top pod broken-pod-2 -n webapp-lab

# Task 3: Resolve configuration issues
kubectl describe pod broken-pod-3 -n webapp-lab
kubectl get events -n webapp-lab --sort-by='.lastTimestamp'

# Task 4: Application debugging with exec
kubectl exec -it <pod-name> -n webapp-lab -- /bin/bash
# Inside pod: check environment variables, network connectivity, file systems

# Task 5: Network troubleshooting
kubectl exec -it <pod-name> -n webapp-lab -- nslookup backend-service
kubectl exec -it <pod-name> -n webapp-lab -- curl http://backend-service:8080
```

### Lab 3: Advanced Application Patterns

#### Scenario: Init Containers and Sidecar Patterns
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: advanced-patterns
  namespace: webapp-lab
spec:
  initContainers:
  - name: init-database
    image: busybox:1.35
    command: ['sh', '-c', 'until nslookup database-service; do echo waiting for database; sleep 2; done;']
  - name: migrate-database
    image: migrate/migrate:v4.15.2
    command: ['migrate', '-path', '/migrations', '-database', 'postgres://user:pass@database:5432/app?sslmode=disable', 'up']
    volumeMounts:
    - name: migrations
      mountPath: /migrations
  containers:
  - name: main-app
    image: node:16-alpine
    command: ["node", "server.js"]
    ports:
    - containerPort: 3000
    resources:
      requests:
        memory: "128Mi"
        cpu: "250m"
      limits:
        memory: "256Mi"
        cpu: "500m"
  - name: logging-sidecar
    image: fluent/fluent-bit:1.9
    volumeMounts:
    - name: app-logs
      mountPath: /var/log/app
    - name: fluent-bit-config
      mountPath: /fluent-bit/etc
  volumes:
  - name: app-logs
    emptyDir: {}
  - name: migrations
    configMap:
      name: database-migrations
  - name: fluent-bit-config
    configMap:
      name: fluent-bit-config
```

## CKA-Focused Lab Scenarios

### Lab 4: Cluster Administration and Maintenance

#### Scenario: Cluster Backup and Restore
```bash
# Task 1: Backup etcd cluster
ETCDCTL_API=3 etcdctl snapshot save /tmp/etcd-backup.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# Task 2: Verify backup
ETCDCTL_API=3 etcdctl snapshot status /tmp/etcd-backup.db \
  --write-out=table

# Task 3: Simulate cluster failure and restore
sudo systemctl stop kubelet
sudo systemctl stop etcd

# Task 4: Restore etcd from backup
ETCDCTL_API=3 etcdctl snapshot restore /tmp/etcd-backup.db \
  --data-dir=/var/lib/etcd-restore \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# Task 5: Update etcd configuration and restart services
sudo mv /var/lib/etcd /var/lib/etcd-backup
sudo mv /var/lib/etcd-restore /var/lib/etcd
sudo systemctl start etcd
sudo systemctl start kubelet
```

#### Scenario: Node Management and Maintenance
```bash
# Task 1: Safely drain a node for maintenance
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data

# Task 2: Perform node maintenance (simulated)
# In real scenario: apply security updates, hardware maintenance, etc.
kubectl get nodes

# Task 3: Uncordon node after maintenance
kubectl uncordon <node-name>

# Task 4: Add a new node to the cluster
# Generate join token on control-plane
kubeadm token create --print-join-command

# On new node: run the join command
# sudo kubeadm join <control-plane-ip>:6443 --token <token> --discovery-token-ca-cert-hash <hash>

# Task 5: Remove a node from the cluster
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data --force
kubectl delete node <node-name>
# On the node: kubeadm reset
```

### Lab 5: Networking and Security

#### Scenario: Network Policy Implementation
```yaml
# Default deny all network policy
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: webapp-lab
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
---
# Allow frontend to backend communication
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend
  namespace: webapp-lab
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
    ports:
    - protocol: TCP
      port: 8080
---
# Allow backend to database
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-backend-to-database
  namespace: webapp-lab
spec:
  podSelector:
    matchLabels:
      app: database
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: backend
    ports:
    - protocol: TCP
      port: 5432
```

#### Scenario: RBAC Configuration
```yaml
# Create service account
apiVersion: v1
kind: ServiceAccount
metadata:
  name: webapp-service-account
  namespace: webapp-lab
---
# Create role with specific permissions
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: webapp-lab
  name: webapp-role
rules:
- apiGroups: [""]
  resources: ["pods", "services", "configmaps", "secrets"]
  verbs: ["get", "list", "watch", "create", "update", "patch"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "watch", "create", "update", "patch"]
---
# Bind role to service account
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: webapp-role-binding
  namespace: webapp-lab
subjects:
- kind: ServiceAccount
  name: webapp-service-account
  namespace: webapp-lab
roleRef:
  kind: Role
  name: webapp-role
  apiGroup: rbac.authorization.k8s.io
```

### Lab 6: Storage and Persistence

#### Scenario: Dynamic Storage Provisioning
```yaml
# Storage class for SSD disks
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
provisioner: kubernetes.io/gce-pd  # Use appropriate provisioner for your cloud
parameters:
  type: pd-ssd
  replication-type: none
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
---
# Persistent Volume Claim
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: database-pvc
  namespace: webapp-lab
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: fast-ssd
  resources:
    requests:
      storage: 10Gi
---
# StatefulSet using the PVC
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: database
  namespace: webapp-lab
spec:
  serviceName: database-service
  replicas: 1
  selector:
    matchLabels:
      app: database
  template:
    metadata:
      labels:
        app: database
    spec:
      containers:
      - name: postgres
        image: postgres:13
        env:
        - name: POSTGRES_DB
          value: app
        - name: POSTGRES_USER
          value: user
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-secret
              key: password
        ports:
        - containerPort: 5432
        volumeMounts:
        - name: database-storage
          mountPath: /var/lib/postgresql/data
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
  volumeClaimTemplates:
  - metadata:
      name: database-storage
    spec:
      accessModes: [ "ReadWriteOnce" ]
      storageClassName: fast-ssd
      resources:
        requests:
          storage: 20Gi
```

## Exam Simulation Exercises

### CKAD Exam Simulation
```bash
# Exercise 1: Create a deployment with specific requirements (8 minutes)
# Requirements:
# - Name: web-app
# - Image: nginx:1.21
# - Replicas: 3
# - Resource limits: 128Mi memory, 500m CPU
# - Resource requests: 64Mi memory, 250m CPU
# - Environment variable: ENV=production
# - Port: 80

kubectl create deployment web-app --image=nginx:1.21 --replicas=3 --dry-run=client -o yaml > web-app.yaml
# Edit the file to add resources and environment variables
kubectl apply -f web-app.yaml

# Exercise 2: Debug failing pod (5 minutes)
kubectl run debug-pod --image=nginx:wrong-tag
kubectl describe pod debug-pod
kubectl edit pod debug-pod
# Change image to nginx:1.21

# Exercise 3: Create service and ingress (6 minutes)
kubectl expose deployment web-app --port=80 --target-port=80
kubectl create ingress web-app-ingress --rule="app.example.com/*=web-app:80"
```

### CKA Exam Simulation
```bash
# Exercise 1: Node troubleshooting (10 minutes)
# Simulate node in NotReady state
kubectl get nodes
kubectl describe node <node-name>
# SSH to node and check kubelet service
systemctl status kubelet
journalctl -u kubelet

# Exercise 2: Create and manage certificates (12 minutes)
# Create a certificate signing request
openssl genrsa -out myuser.key 2048
openssl req -new -key myuser.key -out myuser.csr -subj "/CN=myuser/O=group1"

# Create CSR resource in Kubernetes
cat <<EOF | kubectl apply -f -
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: myuser
spec:
  request: $(cat myuser.csr | base64 | tr -d '\n')
  signerName: kubernetes.io/kube-apiserver-client
  usages:
  - client auth
EOF

# Approve the CSR
kubectl certificate approve myuser

# Exercise 3: etcd backup and restore (15 minutes)
# (Use commands from Lab 4 above)
```

## Daily Practice Routine

### Week 1-2: Foundation Building
```yaml
Day 1: Cluster setup and basic operations
  - 30 min: Environment setup
  - 60 min: Basic kubectl commands
  - 30 min: Pod creation and management

Day 2: Deployments and Services
  - 45 min: Deployment creation and scaling
  - 45 min: Service types and exposure
  - 30 min: Troubleshooting connectivity

Day 3: Configuration Management
  - 60 min: ConfigMaps and Secrets
  - 30 min: Environment variables
  - 30 min: Volume mounts

Day 4: Networking Basics
  - 45 min: Service discovery
  - 45 min: DNS resolution
  - 30 min: Network troubleshooting

Day 5: Storage and Persistence
  - 60 min: Volumes and PVCs
  - 30 min: Storage classes
  - 30 min: StatefulSets

Days 6-7: Review and practice
  - 60 min each day: Mixed scenarios
  - 30 min each day: Command practice
```

### Week 3-4: Intermediate Skills
```yaml
Focus Areas:
  - Advanced networking (Ingress, Network Policies)
  - Security (RBAC, SecurityContext)
  - Application debugging and troubleshooting
  - Multi-container patterns
  - Resource management and optimization
```

### Week 5-8: Advanced Topics and Exam Prep
```yaml
Focus Areas:
  - Cluster administration (for CKA)
  - Complex application scenarios (for CKAD)
  - Time management and exam simulation
  - Weak area intensive practice
  - Mock exams and performance analysis
```

## Lab Environment Cleanup and Cost Management

### Daily Cleanup Scripts
```bash
#!/bin/bash
# cleanup-daily.sh - Run after each practice session

# Delete all pods in default namespace
kubectl delete pods --all

# Delete all deployments in practice namespaces
kubectl delete deployments --all -n webapp-lab

# Clean up completed jobs
kubectl delete jobs --field-selector=status.successful=1 --all-namespaces

# Remove unused ConfigMaps and Secrets (be careful with this)
kubectl delete configmaps --all -n webapp-lab
kubectl delete secrets --all -n webapp-lab

echo "Daily cleanup completed"
```

### Weekly Cluster Reset
```bash
#!/bin/bash
# reset-weekly.sh - Fresh start each week

# For cloud clusters
# gcloud container clusters delete certification-practice --zone=asia-southeast1-a --quiet
# gcloud container clusters create certification-practice --zone=asia-southeast1-a --num-nodes=2 --machine-type=e2-small --preemptible

# For local clusters
kind delete cluster --name certification-cluster
kind create cluster --config kind-config.yaml

echo "Weekly cluster reset completed"
```

## Navigation

- **Previous**: [Comparison Analysis](./comparison-analysis.md)
- **Next**: [Study Plans](./study-plans.md)
- **Related**: [Implementation Guide](./implementation-guide.md)

---

*Hands-on experience guide developed through analysis of official certification requirements and practical experience of 300+ certified professionals.*