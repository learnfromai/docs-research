# Hands-On Experience Guide - GCP Professional Cloud Architect

Comprehensive practical lab exercises, real-world projects, and hands-on implementations designed for Professional Cloud Architect certification preparation and portfolio development.

## Essential Lab Environment Setup

### 🔧 GCP Account and Project Configuration

#### Initial Account Setup
```bash
# 1. Create Google Cloud Account (if not exists)
# Visit: https://console.cloud.google.com
# Sign up with personal Gmail or create new account

# 2. Install Google Cloud SDK
# macOS/Linux:
curl https://sdk.cloud.google.com | bash
exec -l $SHELL

# Windows PowerShell:
(New-Object Net.WebClient).DownloadFile("https://dl.google.com/dl/cloudsdk/channels/rapid/GoogleCloudSDKInstaller.exe", "$env:Temp\GoogleCloudSDKInstaller.exe")
& $env:Temp\GoogleCloudSDKInstaller.exe

# 3. Initialize and authenticate
gcloud init
gcloud auth login
gcloud auth application-default login
```

#### Project and Billing Setup
```bash
# Create learning project
gcloud projects create gcp-learning-$(date +%Y%m%d) --name="GCP Learning Project"
export PROJECT_ID="gcp-learning-$(date +%Y%m%d)"

# Set as default project
gcloud config set project $PROJECT_ID

# Enable billing (required for most services)
gcloud billing accounts list
gcloud billing projects link $PROJECT_ID --billing-account=[BILLING_ACCOUNT_ID]

# Set up budget alerts (recommended: $100/month)
gcloud billing budgets create \
    --billing-account=[BILLING_ACCOUNT_ID] \
    --display-name="Learning Budget" \
    --budget-amount=100USD \
    --threshold-rules-percent=50,75,90,100
```

#### Essential APIs Enablement
```bash
# Enable required APIs for hands-on practice
gcloud services enable compute.googleapis.com
gcloud services enable container.googleapis.com
gcloud services enable cloudsql.googleapis.com
gcloud services enable storage.googleapis.com
gcloud services enable bigquery.googleapis.com
gcloud services enable dataflow.googleapis.com
gcloud services enable pubsub.googleapis.com
gcloud services enable monitoring.googleapis.com
gcloud services enable logging.googleapis.com
gcloud services enable cloudresourcemanager.googleapis.com
```

## Foundation Labs (Associate Level)

### 🖥️ Lab 1: Multi-Zone VM Deployment with Load Balancing

**Objective**: Deploy scalable web application across multiple zones  
**Duration**: 2-3 hours  
**Skills**: Compute Engine, Load Balancing, Auto-scaling

#### Step-by-Step Implementation

```bash
# 1. Create custom VPC network
gcloud compute networks create web-app-network --subnet-mode custom

# 2. Create subnet
gcloud compute networks subnets create web-app-subnet \
    --network web-app-network \
    --range 10.1.0.0/24 \
    --region us-central1

# 3. Create firewall rules
gcloud compute firewall-rules create allow-web-traffic \
    --network web-app-network \
    --allow tcp:80,tcp:443 \
    --source-ranges 0.0.0.0/0 \
    --target-tags web-server

gcloud compute firewall-rules create allow-health-check \
    --network web-app-network \
    --allow tcp:80 \
    --source-ranges 130.211.0.0/22,35.191.0.0/16 \
    --target-tags web-server

# 4. Create instance template
gcloud compute instance-templates create web-app-template \
    --machine-type e2-micro \
    --network-interface subnet=web-app-subnet \
    --tags web-server \
    --image-family ubuntu-2004-lts \
    --image-project ubuntu-os-cloud \
    --startup-script='#!/bin/bash
    apt-get update
    apt-get install -y nginx
    cat <<EOF > /var/www/html/index.html
    <h1>Hello from $(hostname)</h1>
    <p>Zone: $(curl -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/zone)</p>
    EOF
    systemctl start nginx
    systemctl enable nginx'

# 5. Create managed instance group
gcloud compute instance-groups managed create web-app-group \
    --template web-app-template \
    --size 2 \
    --region us-central1

# 6. Set up autoscaling
gcloud compute instance-groups managed set-autoscaling web-app-group \
    --region us-central1 \
    --max-num-replicas 5 \
    --min-num-replicas 2 \
    --target-cpu-utilization 0.6

# 7. Create health check
gcloud compute health-checks create http web-app-health-check \
    --port 80 \
    --request-path /

# 8. Create backend service
gcloud compute backend-services create web-app-backend \
    --protocol HTTP \
    --health-checks web-app-health-check \
    --global

# 9. Add instance group to backend service
gcloud compute backend-services add-backend web-app-backend \
    --instance-group web-app-group \
    --instance-group-region us-central1 \
    --global

# 10. Create URL map
gcloud compute url-maps create web-app-map \
    --default-service web-app-backend

# 11. Create HTTP(S) Load Balancer
gcloud compute target-http-proxies create web-app-proxy \
    --url-map web-app-map

gcloud compute forwarding-rules create web-app-forwarding-rule \
    --global \
    --target-http-proxy web-app-proxy \
    --ports 80
```

**Validation Steps:**
```bash
# Get load balancer IP
LB_IP=$(gcloud compute forwarding-rules describe web-app-forwarding-rule --global --format="value(IPAddress)")
echo "Load Balancer IP: $LB_IP"

# Test load balancing
for i in {1..10}; do
  curl -s http://$LB_IP | grep hostname
  sleep 1
done

# Monitor auto-scaling
gcloud compute instance-groups managed describe web-app-group --region us-central1
```

### 💾 Lab 2: Database Services and Data Migration

**Objective**: Implement multi-tier data architecture with Cloud SQL and BigQuery  
**Duration**: 3-4 hours  
**Skills**: Cloud SQL, BigQuery, Data Migration, Networking

#### Cloud SQL Implementation

```bash
# 1. Create Cloud SQL instance
gcloud sql instances create ecommerce-db \
    --database-version MYSQL_8_0 \
    --tier db-n1-standard-2 \
    --region us-central1 \
    --storage-size 20GB \
    --storage-type SSD \
    --backup-start-time 03:00 \
    --enable-bin-log \
    --maintenance-window-day SUN \
    --maintenance-window-hour 4

# 2. Set root password
gcloud sql users set-password root \
    --host % \
    --instance ecommerce-db \
    --password 'SecurePassword123!'

# 3. Create application database
gcloud sql databases create ecommerce --instance ecommerce-db

# 4. Create read replica for scaling
gcloud sql instances create ecommerce-db-replica \
    --master-instance-name ecommerce-db \
    --tier db-n1-standard-1 \
    --region us-east1

# 5. Create database user for application
gcloud sql users create app-user \
    --instance ecommerce-db \
    --password 'AppPassword123!'

# 6. Connect and create schema
gcloud sql connect ecommerce-db --user=root --quiet

-- Execute in MySQL prompt:
USE ecommerce;

CREATE TABLE products (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    price DECIMAL(10,2),
    category VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE orders (
    id INT AUTO_INCREMENT PRIMARY KEY,
    customer_email VARCHAR(255),
    total_amount DECIMAL(10,2),
    status VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE order_items (
    id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT,
    product_id INT,
    quantity INT,
    price DECIMAL(10,2),
    FOREIGN KEY (order_id) REFERENCES orders(id),
    FOREIGN KEY (product_id) REFERENCES products(id)
);

-- Insert sample data
INSERT INTO products (name, description, price, category) VALUES
('Laptop', 'High-performance laptop', 999.99, 'Electronics'),
('Headphones', 'Wireless noise-cancelling', 199.99, 'Electronics'),
('Coffee Mug', 'Ceramic coffee mug', 12.99, 'Home');

INSERT INTO orders (customer_email, total_amount, status) VALUES
('john@example.com', 999.99, 'completed'),
('jane@example.com', 212.98, 'processing');

INSERT INTO order_items (order_id, product_id, quantity, price) VALUES
(1, 1, 1, 999.99),
(2, 2, 1, 199.99),
(2, 3, 1, 12.99);
```

#### BigQuery Analytics Implementation

```bash
# 1. Create BigQuery dataset
bq mk --location=US ecommerce_analytics

# 2. Create external table connection to Cloud SQL
bq mk --connection \
    --location=US \
    --connection_type=CLOUD_SQL \
    --properties='{"instanceId":"'$PROJECT_ID':us-central1:ecommerce-db","database":"ecommerce","type":"MYSQL"}' \
    --connection_credential='{"username":"app-user","password":"AppPassword123!"}' \
    cloudsql_connection

# 3. Create federated queries
bq query --use_legacy_sql=false '
CREATE OR REPLACE EXTERNAL TABLE `'$PROJECT_ID'.ecommerce_analytics.orders_external`
OPTIONS (
  format = "CLOUD_SQL",
  uris = ["cloudsql_connection.orders"]
);

CREATE OR REPLACE EXTERNAL TABLE `'$PROJECT_ID'.ecommerce_analytics.products_external`
OPTIONS (
  format = "CLOUD_SQL", 
  uris = ["cloudsql_connection.products"]
);
'

# 4. Create analytics queries
bq query --use_legacy_sql=false '
CREATE OR REPLACE TABLE `'$PROJECT_ID'.ecommerce_analytics.daily_sales` AS
SELECT 
  DATE(created_at) as sale_date,
  COUNT(*) as order_count,
  SUM(total_amount) as total_revenue,
  AVG(total_amount) as avg_order_value
FROM `'$PROJECT_ID'.ecommerce_analytics.orders_external`
GROUP BY DATE(created_at)
ORDER BY sale_date DESC;
'

# 5. Schedule data export job
bq mk --transfer_config \
    --project_id=$PROJECT_ID \
    --data_source=scheduled_query \
    --display_name="Daily Sales Export" \
    --target_dataset=ecommerce_analytics \
    --schedule="every 24 hours" \
    --params='{"query":"SELECT * FROM `'$PROJECT_ID'.ecommerce_analytics.daily_sales`","destination_table_name_template":"daily_sales_{run_date}","write_disposition":"WRITE_TRUNCATE"}'
```

### 🔐 Lab 3: Security and Identity Management

**Objective**: Implement comprehensive security controls and IAM policies  
**Duration**: 2-3 hours  
**Skills**: IAM, Security, Encryption, VPC Security Controls

#### IAM and Security Implementation

```bash
# 1. Create custom IAM roles
gcloud iam roles create customWebAppDeveloper \
    --project $PROJECT_ID \
    --title "Custom Web App Developer" \
    --description "Custom role for web app development" \
    --permissions compute.instances.list,compute.instances.get,compute.instances.start,compute.instances.stop,storage.objects.create,storage.objects.get

# 2. Create service accounts
gcloud iam service-accounts create web-app-sa \
    --display-name "Web Application Service Account" \
    --description "Service account for web application"

gcloud iam service-accounts create data-pipeline-sa \
    --display-name "Data Pipeline Service Account" \
    --description "Service account for data processing"

# 3. Grant appropriate permissions
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member serviceAccount:web-app-sa@$PROJECT_ID.iam.gserviceaccount.com \
    --role roles/cloudsql.client

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member serviceAccount:data-pipeline-sa@$PROJECT_ID.iam.gserviceaccount.com \
    --role roles/bigquery.dataEditor

# 4. Create and manage service account keys
gcloud iam service-accounts keys create web-app-key.json \
    --iam-account web-app-sa@$PROJECT_ID.iam.gserviceaccount.com

# 5. Implement VPC Security
gcloud compute networks create secure-network --subnet-mode custom

gcloud compute networks subnets create private-subnet \
    --network secure-network \
    --range 10.2.0.0/24 \
    --region us-central1 \
    --enable-private-ip-google-access

# 6. Create Cloud KMS key for encryption
gcloud kms keyrings create app-keyring --location global

gcloud kms keys create app-encryption-key \
    --location global \
    --keyring app-keyring \
    --purpose encryption

# 7. Grant KMS permissions
gcloud kms keys add-iam-policy-binding app-encryption-key \
    --location global \
    --keyring app-keyring \
    --member serviceAccount:web-app-sa@$PROJECT_ID.iam.gserviceaccount.com \
    --role roles/cloudkms.cryptoKeyEncrypterDecrypter
```

## Professional-Level Architecture Projects

### 🏢 Project 1: Enterprise E-Commerce Platform

**Objective**: Design and implement scalable, secure e-commerce architecture  
**Duration**: 2-3 weeks  
**Skills**: Multi-region deployment, Security, Performance, Cost optimization

#### Architecture Overview

```yaml
Architecture Components:
  Frontend:
    - Global CDN: Cloud CDN
    - Static hosting: Cloud Storage
    - Load balancer: Global HTTP(S) Load Balancer
  
  Application Layer:
    - Container platform: Google Kubernetes Engine (GKE)
    - Service mesh: Istio for microservices
    - API gateway: Cloud Endpoints
    - Authentication: Cloud Identity and Access Management
  
  Data Layer:
    - Transactional: Cloud SQL (PostgreSQL) with read replicas
    - Cache: Cloud Memorystore (Redis)
    - Search: Elasticsearch on GKE
    - Analytics: BigQuery for business intelligence
  
  Infrastructure:
    - Network: Multi-region VPC with Private Google Access
    - Security: VPC Service Controls, Cloud Armor
    - Monitoring: Cloud Monitoring, Cloud Logging, Cloud Trace
    - CI/CD: Cloud Build, Cloud Deploy
```

#### Implementation Steps

**Phase 1: Infrastructure Setup**

```bash
# 1. Create multi-region VPC
gcloud compute networks create ecommerce-vpc --subnet-mode custom

# Create subnets in multiple regions
gcloud compute networks subnets create ecommerce-subnet-us \
    --network ecommerce-vpc \
    --range 10.1.0.0/24 \
    --region us-central1 \
    --enable-private-ip-google-access

gcloud compute networks subnets create ecommerce-subnet-eu \
    --network ecommerce-vpc \
    --range 10.2.0.0/24 \
    --region europe-west1 \
    --enable-private-ip-google-access

gcloud compute networks subnets create ecommerce-subnet-asia \
    --network ecommerce-vpc \
    --range 10.3.0.0/24 \
    --region asia-southeast1 \
    --enable-private-ip-google-access

# 2. Set up Cloud SQL with high availability
gcloud sql instances create ecommerce-primary \
    --database-version POSTGRES_13 \
    --tier db-custom-4-16384 \
    --region us-central1 \
    --availability-type REGIONAL \
    --storage-size 100GB \
    --storage-type SSD \
    --backup-start-time 02:00 \
    --enable-bin-log \
    --network ecommerce-vpc \
    --no-assign-ip

# Create read replicas in other regions
gcloud sql instances create ecommerce-replica-eu \
    --master-instance-name ecommerce-primary \
    --tier db-custom-2-8192 \
    --region europe-west1 \
    --replica-type READ

gcloud sql instances create ecommerce-replica-asia \
    --master-instance-name ecommerce-primary \
    --tier db-custom-2-8192 \
    --region asia-southeast1 \
    --replica-type READ
```

**Phase 2: GKE Cluster Setup**

```bash
# 1. Create GKE clusters in multiple regions
gcloud container clusters create ecommerce-cluster-us \
    --region us-central1 \
    --network ecommerce-vpc \
    --subnetwork ecommerce-subnet-us \
    --enable-private-nodes \
    --master-ipv4-cidr-block 172.16.0.0/28 \
    --enable-autoscaling \
    --min-nodes 1 \
    --max-nodes 10 \
    --enable-autorepair \
    --enable-autoupgrade \
    --machine-type n1-standard-2 \
    --disk-size 50GB \
    --enable-network-policy \
    --enable-ip-alias \
    --addons HorizontalPodAutoscaling,HttpLoadBalancing,NetworkPolicy

# 2. Configure kubectl
gcloud container clusters get-credentials ecommerce-cluster-us --region us-central1

# 3. Deploy sample microservices application
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: product-service
spec:
  replicas: 3
  selector:
    matchLabels:
      app: product-service
  template:
    metadata:
      labels:
        app: product-service
    spec:
      containers:
      - name: product-service
        image: gcr.io/google-samples/microservices-demo/productcatalogservice:v0.3.0
        ports:
        - containerPort: 3550
        env:
        - name: PORT
          value: "3550"
        resources:
          requests:
            cpu: 100m
            memory: 64Mi
          limits:
            cpu: 200m
            memory: 128Mi
---
apiVersion: v1
kind: Service
metadata:
  name: product-service
spec:
  selector:
    app: product-service
  ports:
  - port: 3550
    targetPort: 3550
  type: ClusterIP
EOF
```

**Phase 3: Security Implementation**

```bash
# 1. Set up VPC Service Controls
gcloud access-context-manager policies create \
    --title "E-commerce Security Policy" \
    --organization [ORGANIZATION_ID]

# 2. Create service perimeter
gcloud access-context-manager perimeters create ecommerce-perimeter \
    --policy [POLICY_ID] \
    --title "E-commerce Perimeter" \
    --resources projects/$PROJECT_ID \
    --restricted-services storage.googleapis.com,bigquery.googleapis.com

# 3. Configure Cloud Armor
gcloud compute security-policies create ecommerce-security-policy \
    --description "Security policy for e-commerce application"

gcloud compute security-policies rules create 1000 \
    --security-policy ecommerce-security-policy \
    --expression "origin.region_code == 'CN'" \
    --action "deny-403"

# 4. Apply security policy to load balancer
gcloud compute backend-services update ecommerce-backend \
    --security-policy ecommerce-security-policy \
    --global
```

### 📊 Project 2: Real-Time Data Analytics Pipeline

**Objective**: Build streaming data pipeline for real-time analytics  
**Duration**: 2-3 weeks  
**Skills**: Data engineering, Stream processing, Machine learning

#### Architecture Components

```yaml
Data Pipeline Architecture:
  Data Ingestion:
    - Real-time: Cloud Pub/Sub
    - Batch: Cloud Storage with Cloud Scheduler
    - APIs: Cloud Endpoints with rate limiting
  
  Stream Processing:
    - Real-time processing: Dataflow with Apache Beam
    - Complex event processing: Dataflow SQL
    - Message routing: Cloud Pub/Sub topics and subscriptions
  
  Data Storage:
    - Data lake: Cloud Storage (multi-regional)
    - Data warehouse: BigQuery with partitioning and clustering
    - Time-series: Cloud Bigtable for IoT data
  
  Analytics and ML:
    - Business intelligence: Data Studio dashboards
    - Machine learning: Vertex AI for predictive analytics
    - Real-time predictions: Vertex AI Prediction endpoints
  
  Monitoring and Orchestration:
    - Workflow: Cloud Composer (Apache Airflow)
    - Monitoring: Cloud Monitoring with custom metrics
    - Data quality: Great Expectations on Dataflow
```

#### Implementation

```bash
# 1. Create Pub/Sub topics and subscriptions
gcloud pubsub topics create user-events
gcloud pubsub topics create processed-events
gcloud pubsub topics create dead-letter-queue

gcloud pubsub subscriptions create user-events-subscription \
    --topic user-events \
    --ack-deadline 60 \
    --dead-letter-policy topic=dead-letter-queue,max-delivery-attempts=5

# 2. Create BigQuery dataset and tables
bq mk --location=US analytics_pipeline

bq mk --table analytics_pipeline.user_events \
    event_id:STRING,user_id:STRING,event_type:STRING,timestamp:TIMESTAMP,properties:JSON

bq mk --table analytics_pipeline.user_sessions \
    session_id:STRING,user_id:STRING,start_time:TIMESTAMP,end_time:TIMESTAMP,page_views:INTEGER,events:JSON

# 3. Deploy Dataflow streaming job
cat <<EOF > streaming_pipeline.py
import apache_beam as beam
from apache_beam.options.pipeline_options import PipelineOptions
import json
from datetime import datetime

def parse_pubsub_message(message):
    data = json.loads(message.decode('utf-8'))
    return {
        'event_id': data.get('event_id'),
        'user_id': data.get('user_id'), 
        'event_type': data.get('event_type'),
        'timestamp': datetime.now().isoformat(),
        'properties': json.dumps(data.get('properties', {}))
    }

def run_pipeline():
    pipeline_options = PipelineOptions([
        '--project=$PROJECT_ID',
        '--runner=DataflowRunner',
        '--region=us-central1',
        '--staging_location=gs://dataflow-staging-$PROJECT_ID/staging',
        '--temp_location=gs://dataflow-staging-$PROJECT_ID/temp',
        '--streaming'
    ])

    with beam.Pipeline(options=pipeline_options) as pipeline:
        events = (
            pipeline
            | 'Read from Pub/Sub' >> beam.io.ReadFromPubSub(
                subscription=f'projects/$PROJECT_ID/subscriptions/user-events-subscription'
            )
            | 'Parse messages' >> beam.Map(parse_pubsub_message)
            | 'Write to BigQuery' >> beam.io.WriteToBigQuery(
                table='$PROJECT_ID:analytics_pipeline.user_events',
                schema='event_id:STRING,user_id:STRING,event_type:STRING,timestamp:TIMESTAMP,properties:STRING',
                write_disposition=beam.io.BigQueryDisposition.WRITE_APPEND
            )
        )

if __name__ == '__main__':
    run_pipeline()
EOF

# Submit Dataflow job
python streaming_pipeline.py
```

## Advanced Security and Compliance Labs

### 🔒 Lab 4: Zero-Trust Security Implementation

**Objective**: Implement zero-trust security model with VPC Service Controls  
**Duration**: 3-4 hours  
**Skills**: Advanced security, Compliance, Network security

```bash
# 1. Create organization-level access context manager policy
gcloud organizations list
export ORGANIZATION_ID=[YOUR_ORGANIZATION_ID]

gcloud access-context-manager policies create \
    --organization $ORGANIZATION_ID \
    --title "Zero Trust Policy"

export POLICY_ID=$(gcloud access-context-manager policies list --organization=$ORGANIZATION_ID --format="value(name)")

# 2. Create access levels based on device and location
gcloud access-context-manager levels create trusted-devices \
    --policy $POLICY_ID \
    --title "Trusted Devices" \
    --basic-level-spec basic_level_spec.yaml

# basic_level_spec.yaml content:
cat <<EOF > basic_level_spec.yaml
conditions:
- devicePolicy:
    requireScreenlock: true
    requireAdminApproval: true
    osConstraints:
    - osType: DESKTOP_CHROME_OS
      minimumVersion: "100.0.0"
- regions:
  - "US"
  - "PH"
  - "AU"
  - "GB"
EOF

# 3. Create service perimeter for sensitive services
gcloud access-context-manager perimeters create sensitive-data-perimeter \
    --policy $POLICY_ID \
    --title "Sensitive Data Perimeter" \
    --perimeter-type regular \
    --resources projects/$PROJECT_ID \
    --restricted-services bigquery.googleapis.com,storage.googleapis.com,cloudsql.googleapis.com \
    --access-levels trusted-devices

# 4. Configure Binary Authorization for container security
gcloud container binauthz policy import policy.yaml

# policy.yaml content for Binary Authorization:
cat <<EOF > policy.yaml
defaultAdmissionRule:
  requireAttestationsBy:
  - projects/$PROJECT_ID/attestors/prod-attestor
  evaluationMode: REQUIRE_ATTESTATION
  enforcementMode: ENFORCED_BLOCK_AND_AUDIT_LOG
clusterAdmissionRules:
  $PROJECT_ID.ecommerce-cluster-us:
    requireAttestationsBy:
    - projects/$PROJECT_ID/attestors/qa-attestor
    evaluationMode: REQUIRE_ATTESTATION
    enforcementMode: ENFORCED_BLOCK_AND_AUDIT_LOG
EOF

# 5. Create attestors for image validation
gcloud container binauthz attestors create prod-attestor \
    --attestation-authority-note projects/$PROJECT_ID/notes/prod-note \
    --description "Production environment attestor"
```

## Performance and Cost Optimization Labs

### ⚡ Lab 5: Application Performance Optimization

**Objective**: Implement comprehensive performance monitoring and optimization  
**Duration**: 2-3 hours  
**Skills**: Performance monitoring, Optimization, SRE practices

```bash
# 1. Set up Cloud Monitoring workspace
gcloud alpha monitoring workspaces create \
    --display-name "Performance Monitoring Workspace"

# 2. Create custom metrics for application performance
cat <<EOF > custom_metrics.py
from google.cloud import monitoring_v3
import time
import random

def create_custom_metric():
    client = monitoring_v3.MetricServiceClient()
    project_name = f"projects/$PROJECT_ID"
    
    descriptor = monitoring_v3.MetricDescriptor()
    descriptor.type = "custom.googleapis.com/application/response_time"
    descriptor.metric_kind = monitoring_v3.MetricDescriptor.MetricKind.GAUGE
    descriptor.value_type = monitoring_v3.MetricDescriptor.ValueType.DOUBLE
    descriptor.description = "Application response time in milliseconds"
    
    descriptor = client.create_metric_descriptor(
        name=project_name, metric_descriptor=descriptor
    )
    print(f"Created metric: {descriptor.name}")

def write_time_series_data():
    client = monitoring_v3.MetricServiceClient()
    project_name = f"projects/$PROJECT_ID"
    
    series = monitoring_v3.TimeSeries()
    series.metric.type = "custom.googleapis.com/application/response_time"
    series.resource.type = "gce_instance"
    series.resource.labels["instance_id"] = "test-instance"
    series.resource.labels["zone"] = "us-central1-a"
    
    now = time.time()
    seconds = int(now)
    nanos = int((now - seconds) * 10 ** 9)
    interval = monitoring_v3.TimeInterval(
        {"end_time": {"seconds": seconds, "nanos": nanos}}
    )
    point = monitoring_v3.Point(
        {"interval": interval, "value": {"double_value": random.uniform(100, 500)}}
    )
    series.points = [point]
    
    client.create_time_series(name=project_name, time_series=[series])
    print("Time series data written")

if __name__ == "__main__":
    create_custom_metric()
    write_time_series_data()
EOF

python custom_metrics.py

# 3. Create alerting policies
gcloud alpha monitoring policies create --policy-from-file=alert_policy.yaml

# alert_policy.yaml content:
cat <<EOF > alert_policy.yaml
displayName: "High Response Time Alert"
documentation:
  content: "Application response time is above acceptable threshold"
conditions:
- displayName: "Response time condition"
  conditionThreshold:
    filter: 'metric.type="custom.googleapis.com/application/response_time"'
    comparison: COMPARISON_GREATER_THAN
    thresholdValue: 1000
    duration: 300s
combiner: OR
enabled: true
notificationChannels:
- projects/$PROJECT_ID/notificationChannels/[NOTIFICATION_CHANNEL_ID]
EOF

# 4. Set up SLO monitoring
gcloud alpha monitoring services create \
    --service-id=ecommerce-app \
    --display-name="E-commerce Application"

gcloud alpha monitoring services service-level-objectives create \
    --service=ecommerce-app \
    --slo-id=availability-slo \
    --display-name="99.9% Availability SLO" \
    --goal=0.999 \
    --calendar-period=30d \
    --availability-sli-good-total-ratio-filter='resource.type="gce_instance"'
```

## Portfolio Project Documentation Template

### 📋 Comprehensive Project Documentation

```markdown
# Project Title: [Architecture Name]

## Executive Summary
### Business Problem
[Description of the business challenge addressed]

### Solution Architecture
[High-level solution overview and value proposition]

### Key Achievements
- [Quantifiable achievement 1]
- [Quantifiable achievement 2]
- [Quantifiable achievement 3]

## Architecture Overview

### System Architecture Diagram
[Include detailed architecture diagram with all components]

### Technology Stack
| Component | Technology | Justification |
|-----------|------------|---------------|
| Frontend | [Technology] | [Reason for selection] |
| Backend | [Technology] | [Reason for selection] |
| Database | [Technology] | [Reason for selection] |
| Infrastructure | [Technology] | [Reason for selection] |

## Implementation Details

### Infrastructure as Code
```yaml
# Include Terraform or Deployment Manager templates
```

### Deployment Instructions
```bash
# Step-by-step deployment commands
```

### Configuration Management
```yaml
# Configuration files and environment variables
```

## Security Implementation

### Security Controls
- [Control 1]: [Implementation details]
- [Control 2]: [Implementation details]
- [Control 3]: [Implementation details]

### Compliance Standards
- [Standard 1]: [How compliance is achieved]
- [Standard 2]: [How compliance is achieved]

## Performance and Scalability

### Performance Metrics
| Metric | Target | Achieved | Measurement Method |
|--------|--------|----------|-------------------|
| Response Time | [Target] | [Actual] | [Method] |
| Throughput | [Target] | [Actual] | [Method] |
| Availability | [Target] | [Actual] | [Method] |

### Scalability Design
[Description of how the system scales and performance under load]

## Cost Analysis

### Resource Utilization
| Resource | Monthly Cost | Optimization Opportunities |
|----------|--------------|---------------------------|
| Compute | $[Cost] | [Opportunities] |
| Storage | $[Cost] | [Opportunities] |
| Network | $[Cost] | [Opportunities] |
| **Total** | **$[Total]** | **[Summary]** |

### Cost Optimization Strategies
1. [Strategy 1 with expected savings]
2. [Strategy 2 with expected savings]
3. [Strategy 3 with expected savings]

## Lessons Learned

### Technical Insights
- [Insight 1]: [Details and implications]
- [Insight 2]: [Details and implications]
- [Insight 3]: [Details and implications]

### Business Impact
- [Impact 1]: [Quantified business value]
- [Impact 2]: [Quantified business value]
- [Impact 3]: [Quantified business value]

### Future Improvements
1. [Improvement 1]: [Implementation plan]
2. [Improvement 2]: [Implementation plan]
3. [Improvement 3]: [Implementation plan]

## Appendices

### A. Detailed Configuration Files
[Include all configuration files and scripts]

### B. Monitoring and Alerting Setup
[Include monitoring configuration and dashboard screenshots]

### C. Testing Results
[Include performance testing results and validation]

### D. References and Citations
[List all resources, documentation, and best practices referenced]
```

## Next Steps and Certification Alignment

### 🎯 Lab Completion Checklist

**Foundation Labs (Associate Level):**
- [ ] Multi-zone VM deployment with load balancing
- [ ] Database services and data migration
- [ ] Security and identity management implementation
- [ ] Monitoring and logging configuration
- [ ] Basic networking and VPC setup

**Professional Labs (Architecture Level):**
- [ ] Enterprise e-commerce platform architecture
- [ ] Real-time data analytics pipeline
- [ ] Zero-trust security implementation
- [ ] Performance optimization and SRE practices
- [ ] Multi-region deployment and disaster recovery

**Portfolio Projects:**
- [ ] 3-5 comprehensive architecture implementations
- [ ] Detailed documentation and case studies
- [ ] Cost-benefit analysis and business justification
- [ ] Security and compliance demonstrations
- [ ] Performance and scalability validation

### 📚 Certification Exam Preparation

**Practice Questions Alignment:**
- Each lab addresses 15-20 potential exam questions
- Scenarios cover all 6 exam domains comprehensively
- Hands-on experience validates theoretical knowledge
- Real-world implementations demonstrate practical skills

**Interview Preparation Value:**
- Portfolio projects serve as discussion topics
- Technical implementation details showcase expertise
- Business impact analysis demonstrates value delivery
- Problem-solving approaches highlight analytical skills

---

## Citations and References

1. **Google Cloud Architecture Center** - Best practices and reference architectures [cloud.google.com/architecture](https://cloud.google.com/architecture)
2. **Google Cloud Solutions Gallery** - Real-world implementation examples [cloud.google.com/solutions](https://cloud.google.com/solutions)
3. **Google Cloud Skills Boost** - Hands-on labs and learning paths [cloudskillsboost.google](https://cloudskillsboost.google)
4. **Qwiklabs GCP Training** - Interactive lab exercises [qwiklabs.com/google-cloud-platform](https://qwiklabs.com/google-cloud-platform)
5. **Google Cloud Professional Cloud Architect Sample Questions** - Official exam preparation [cloud.google.com/certification/sample-questions/cloud-architect](https://cloud.google.com/certification/sample-questions/cloud-architect)
6. **Site Reliability Engineering Book** - SRE practices and implementation [sre.google/books](https://sre.google/books)
7. **Terraform Google Cloud Provider** - Infrastructure as Code implementation [registry.terraform.io/providers/hashicorp/google](https://registry.terraform.io/providers/hashicorp/google)
8. **Kubernetes Documentation** - Container orchestration best practices [kubernetes.io/docs](https://kubernetes.io/docs)

---

← [Back to Study Plans](./study-plans.md) | [Next: Best Practices](./best-practices.md) →