# Deployment Guide: Log Management & Analysis Solutions

## 🚀 Overview

This guide provides comprehensive deployment strategies for log management solutions across different cloud providers and infrastructure setups, specifically tailored for EdTech platforms targeting international markets (AU, UK, US).

## 📋 Pre-Deployment Checklist

### Infrastructure Requirements
- [ ] Cloud provider account with appropriate permissions
- [ ] Domain name and DNS management access
- [ ] SSL/TLS certificates
- [ ] Network security groups and firewall rules configured
- [ ] Storage provisioning (min 100GB, recommended 500GB+)
- [ ] Monitoring and alerting infrastructure

### Compliance Requirements
- [ ] Data residency requirements identified (AU, UK, US)
- [ ] Encryption at rest and in transit configured
- [ ] Access control and RBAC policies defined
- [ ] Audit logging requirements documented
- [ ] Data retention policies established

### Operational Requirements
- [ ] Backup and disaster recovery plan
- [ ] Capacity planning and scaling strategy
- [ ] Maintenance windows defined
- [ ] On-call procedures established
- [ ] Cost monitoring and alerting configured

## ☁️ Cloud Provider Deployments

### AWS Deployment

#### Option 1: ELK Stack on AWS

```yaml
# terraform/aws-elk-stack.tf
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# VPC Configuration
resource "aws_vpc" "elk_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "elk-vpc-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_subnet" "private_subnets" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.elk_vpc.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 1)
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "elk-private-subnet-${count.index + 1}"
    Type = "Private"
  }
}

resource "aws_subnet" "public_subnets" {
  count                   = length(var.availability_zones)
  vpc_id                  = aws_vpc.elk_vpc.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index + 10)
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "elk-public-subnet-${count.index + 1}"
    Type = "Public"
  }
}

# Internet Gateway and NAT Gateway
resource "aws_internet_gateway" "elk_igw" {
  vpc_id = aws_vpc.elk_vpc.id

  tags = {
    Name = "elk-igw-${var.environment}"
  }
}

resource "aws_eip" "nat_eips" {
  count  = length(var.availability_zones)
  domain = "vpc"

  tags = {
    Name = "elk-nat-eip-${count.index + 1}"
  }
}

resource "aws_nat_gateway" "nat_gateways" {
  count         = length(var.availability_zones)
  allocation_id = aws_eip.nat_eips[count.index].id
  subnet_id     = aws_subnet.public_subnets[count.index].id

  tags = {
    Name = "elk-nat-gateway-${count.index + 1}"
  }

  depends_on = [aws_internet_gateway.elk_igw]
}

# Route Tables
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.elk_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.elk_igw.id
  }

  tags = {
    Name = "elk-public-rt"
  }
}

resource "aws_route_table" "private_rt" {
  count  = length(var.availability_zones)
  vpc_id = aws_vpc.elk_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateways[count.index].id
  }

  tags = {
    Name = "elk-private-rt-${count.index + 1}"
  }
}

# Route Table Associations
resource "aws_route_table_association" "public_rta" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.public_subnets[count.index].id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "private_rta" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.private_subnets[count.index].id
  route_table_id = aws_route_table.private_rt[count.index].id
}

# Security Groups
resource "aws_security_group" "elasticsearch_sg" {
  name_prefix = "elasticsearch-"
  vpc_id      = aws_vpc.elk_vpc.id

  ingress {
    from_port   = 9200
    to_port     = 9200
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    from_port   = 9300
    to_port     = 9300
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "elasticsearch-sg"
  }
}

resource "aws_security_group" "kibana_sg" {
  name_prefix = "kibana-"
  vpc_id      = aws_vpc.elk_vpc.id

  ingress {
    from_port   = 5601
    to_port     = 5601
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr_blocks]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "kibana-sg"
  }
}

# Application Load Balancer
resource "aws_lb" "elk_alb" {
  name               = "elk-alb-${var.environment}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = aws_subnet.public_subnets[*].id

  enable_deletion_protection = var.environment == "production"

  tags = {
    Name        = "elk-alb-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_security_group" "alb_sg" {
  name_prefix = "elk-alb-"
  vpc_id      = aws_vpc.elk_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "elk-alb-sg"
  }
}

# Elasticsearch Cluster
resource "aws_instance" "elasticsearch_nodes" {
  count                  = var.elasticsearch_node_count
  ami                    = var.elasticsearch_ami
  instance_type          = var.elasticsearch_instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.elasticsearch_sg.id]
  subnet_id              = aws_subnet.private_subnets[count.index % length(aws_subnet.private_subnets)].id

  root_block_device {
    volume_type = "gp3"
    volume_size = var.elasticsearch_volume_size
    encrypted   = true
  }

  user_data = base64encode(templatefile("${path.module}/userdata/elasticsearch.sh", {
    cluster_name    = "edtech-${var.environment}"
    node_name       = "es-node-${count.index + 1}"
    master_nodes    = [for i in range(var.elasticsearch_node_count) : "es-node-${i + 1}"]
    heap_size       = var.elasticsearch_heap_size
    environment     = var.environment
  }))

  tags = {
    Name        = "elasticsearch-node-${count.index + 1}"
    Environment = var.environment
    Role        = "elasticsearch"
  }
}

# Kibana Instance
resource "aws_instance" "kibana" {
  ami                    = var.kibana_ami
  instance_type          = var.kibana_instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.kibana_sg.id]
  subnet_id              = aws_subnet.private_subnets[0].id

  root_block_device {
    volume_type = "gp3"
    volume_size = 50
    encrypted   = true
  }

  user_data = base64encode(templatefile("${path.module}/userdata/kibana.sh", {
    elasticsearch_hosts = [for instance in aws_instance.elasticsearch_nodes : "${instance.private_ip}:9200"]
    kibana_host        = "0.0.0.0"
    environment        = var.environment
  }))

  tags = {
    Name        = "kibana-${var.environment}"
    Environment = var.environment
    Role        = "kibana"
  }
}

# Outputs
output "elasticsearch_private_ips" {
  value = aws_instance.elasticsearch_nodes[*].private_ip
}

output "kibana_private_ip" {
  value = aws_instance.kibana.private_ip
}

output "load_balancer_dns" {
  value = aws_lb.elk_alb.dns_name
}
```

#### User Data Scripts

```bash
#!/bin/bash
# userdata/elasticsearch.sh

# Update system
yum update -y

# Install Docker
amazon-linux-extras install docker -y
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Configure sysctl for Elasticsearch
echo "vm.max_map_count=262144" >> /etc/sysctl.conf
sysctl -p

# Create Elasticsearch configuration
mkdir -p /opt/elasticsearch
cat > /opt/elasticsearch/docker-compose.yml << EOF
version: '3.8'
services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.11.0
    container_name: elasticsearch
    environment:
      - node.name=${node_name}
      - cluster.name=${cluster_name}
      - cluster.initial_master_nodes=${join(",", master_nodes)}
      - discovery.seed_hosts=${join(",", [for node in master_nodes : node if node != "${node_name}"])}
      - bootstrap.memory_lock=true
      - "ES_JAVA_OPTS=-Xms${heap_size} -Xmx${heap_size}"
      - xpack.security.enabled=true
      - xpack.security.transport.ssl.enabled=true
      - xpack.security.http.ssl.enabled=true
    ulimits:
      memlock:
        soft: -1
        hard: -1
    volumes:
      - es-data:/usr/share/elasticsearch/data
      - es-logs:/usr/share/elasticsearch/logs
    ports:
      - "9200:9200"
      - "9300:9300"
    restart: unless-stopped

volumes:
  es-data:
  es-logs:
EOF

# Start Elasticsearch
cd /opt/elasticsearch
docker-compose up -d

# Configure CloudWatch agent
wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
rpm -U ./amazon-cloudwatch-agent.rpm

cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << EOF
{
  "metrics": {
    "namespace": "ELK/Elasticsearch",
    "metrics_collected": {
      "cpu": {
        "measurement": ["cpu_usage_idle", "cpu_usage_iowait", "cpu_usage_user", "cpu_usage_system"],
        "metrics_collection_interval": 60
      },
      "disk": {
        "measurement": ["used_percent"],
        "metrics_collection_interval": 60,
        "resources": ["*"]
      },
      "diskio": {
        "measurement": ["io_time"],
        "metrics_collection_interval": 60,
        "resources": ["*"]
      },
      "mem": {
        "measurement": ["mem_used_percent"],
        "metrics_collection_interval": 60
      },
      "netstat": {
        "measurement": ["tcp_established", "tcp_time_wait"],
        "metrics_collection_interval": 60
      }
    }
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/opt/elasticsearch/logs/*.log",
            "log_group_name": "/aws/elk/elasticsearch",
            "log_stream_name": "{instance_id}-{hostname}"
          }
        ]
      }
    }
  }
}
EOF

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s
```

#### Option 2: AWS OpenSearch Service

```yaml
# terraform/aws-opensearch.tf
resource "aws_opensearch_domain" "edtech_logs" {
  domain_name    = "edtech-logs-${var.environment}"
  engine_version = "OpenSearch_2.3"

  cluster_config {
    instance_type            = var.opensearch_instance_type
    instance_count           = var.opensearch_instance_count
    dedicated_master_enabled = var.opensearch_instance_count >= 3
    master_instance_type     = var.opensearch_master_instance_type
    master_instance_count    = 3
    zone_awareness_enabled   = true

    zone_awareness_config {
      availability_zone_count = length(var.availability_zones)
    }

    warm_enabled = var.environment == "production"
    warm_count   = var.environment == "production" ? 2 : 0
    warm_type    = var.environment == "production" ? "ultrawarm1.medium.search" : null

    cold_storage_options {
      enabled = var.environment == "production"
    }
  }

  ebs_options {
    ebs_enabled = true
    volume_type = "gp3"
    volume_size = var.opensearch_volume_size
    iops        = var.opensearch_iops
    throughput  = var.opensearch_throughput
  }

  vpc_options {
    subnet_ids         = aws_subnet.private_subnets[*].id
    security_group_ids = [aws_security_group.opensearch_sg.id]
  }

  domain_endpoint_options {
    enforce_https                   = true
    tls_security_policy            = "Policy-Min-TLS-1-2-2019-07"
    custom_endpoint_enabled        = true
    custom_endpoint                = "logs.${var.domain_name}"
    custom_endpoint_certificate_arn = var.acm_certificate_arn
  }

  encrypt_at_rest {
    enabled = true
  }

  node_to_node_encryption {
    enabled = true
  }

  advanced_security_options {
    enabled                        = true
    anonymous_auth_enabled         = false
    internal_user_database_enabled = false

    saml_options {
      enabled = var.saml_enabled
      idp {
        metadata_content = var.saml_metadata
        entity_id        = var.saml_entity_id
      }
      master_user_name     = var.saml_master_username
      master_backend_role  = var.saml_master_backend_role
    }
  }

  # Index templates and policies
  advanced_options = {
    "indices.fielddata.cache.size"  = "20%"
    "indices.query.bool.max_clause_count" = "1024"
    "override_main_response_version" = "false"
  }

  log_publishing_options {
    enabled                  = true
    log_type                = "INDEX_SLOW_LOGS"
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.opensearch_index_slow_logs.arn
  }

  log_publishing_options {
    enabled                  = true
    log_type                = "SEARCH_SLOW_LOGS"
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.opensearch_search_slow_logs.arn
  }

  log_publishing_options {
    enabled                  = true
    log_type                = "ES_APPLICATION_LOGS"
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.opensearch_application_logs.arn
  }

  auto_tune_options {
    desired_state       = "ENABLED"
    rollback_policy     = "NO_ROLLBACK"
    
    maintenance_schedule {
      start_at                       = "2023-01-01T00:00:00Z"
      duration_value                 = 2
      duration_unit                  = "HOURS"
      cron_expression_for_recurrence = "cron(0 2 ? * SUN *)"
    }
  }

  tags = merge(var.common_tags, {
    Name        = "edtech-opensearch-${var.environment}"
    Environment = var.environment
    Service     = "logging"
  })
}

# Security Group for OpenSearch
resource "aws_security_group" "opensearch_sg" {
  name_prefix = "opensearch-${var.environment}-"
  vpc_id      = aws_vpc.elk_vpc.id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "HTTP from VPC (for internal communication)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name = "opensearch-sg-${var.environment}"
  })
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "opensearch_index_slow_logs" {
  name              = "/aws/opensearch/domains/${aws_opensearch_domain.edtech_logs.domain_name}/index-slow-logs"
  retention_in_days = 14

  tags = var.common_tags
}

resource "aws_cloudwatch_log_group" "opensearch_search_slow_logs" {
  name              = "/aws/opensearch/domains/${aws_opensearch_domain.edtech_logs.domain_name}/search-slow-logs"
  retention_in_days = 14

  tags = var.common_tags
}

resource "aws_cloudwatch_log_group" "opensearch_application_logs" {
  name              = "/aws/opensearch/domains/${aws_opensearch_domain.edtech_logs.domain_name}/application-logs"
  retention_in_days = 30

  tags = var.common_tags
}

# Data Lifecycle Management
resource "aws_opensearch_domain_policy" "edtech_logs_policy" {
  domain_name = aws_opensearch_domain.edtech_logs.domain_name

  access_policies = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = [
            "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/edtech-logstash-role",
            "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/edtech-application-role"
          ]
        }
        Action   = "es:*"
        Resource = "${aws_opensearch_domain.edtech_logs.arn}/*"
      }
    ]
  })
}

# Outputs
output "opensearch_endpoint" {
  description = "OpenSearch domain endpoint"
  value       = aws_opensearch_domain.edtech_logs.endpoint
}

output "opensearch_kibana_endpoint" {
  description = "OpenSearch Kibana endpoint"
  value       = aws_opensearch_domain.edtech_logs.kibana_endpoint
}

output "opensearch_domain_arn" {
  description = "OpenSearch domain ARN"
  value       = aws_opensearch_domain.edtech_logs.arn
}
```

### Azure Deployment

#### ELK Stack on Azure

```yaml
# terraform/azure-elk-stack.tf
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Resource Group
resource "azurerm_resource_group" "elk_rg" {
  name     = "rg-elk-${var.environment}-${var.location}"
  location = var.location

  tags = var.common_tags
}

# Virtual Network
resource "azurerm_virtual_network" "elk_vnet" {
  name                = "vnet-elk-${var.environment}"
  address_space       = [var.vnet_cidr]
  location            = azurerm_resource_group.elk_rg.location
  resource_group_name = azurerm_resource_group.elk_rg.name

  tags = var.common_tags
}

# Subnets
resource "azurerm_subnet" "private_subnet" {
  name                 = "subnet-private"
  resource_group_name  = azurerm_resource_group.elk_rg.name
  virtual_network_name = azurerm_virtual_network.elk_vnet.name
  address_prefixes     = [var.private_subnet_cidr]
}

resource "azurerm_subnet" "public_subnet" {
  name                 = "subnet-public"
  resource_group_name  = azurerm_resource_group.elk_rg.name
  virtual_network_name = azurerm_virtual_network.elk_vnet.name
  address_prefixes     = [var.public_subnet_cidr]
}

# Network Security Groups
resource "azurerm_network_security_group" "elasticsearch_nsg" {
  name                = "nsg-elasticsearch"
  location            = azurerm_resource_group.elk_rg.location
  resource_group_name = azurerm_resource_group.elk_rg.name

  security_rule {
    name                       = "AllowElasticsearchHTTP"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "9200"
    source_address_prefix      = var.vnet_cidr
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowElasticsearchTransport"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "9300"
    source_address_prefix      = var.vnet_cidr
    destination_address_prefix = "*"
  }

  tags = var.common_tags
}

# Container Registry
resource "azurerm_container_registry" "elk_acr" {
  name                = "acr${var.project_name}${var.environment}"
  resource_group_name = azurerm_resource_group.elk_rg.name
  location            = azurerm_resource_group.elk_rg.location
  sku                 = "Standard"
  admin_enabled       = true

  tags = var.common_tags
}

# Container Instances for Elasticsearch
resource "azurerm_container_group" "elasticsearch" {
  count               = var.elasticsearch_node_count
  name                = "ci-elasticsearch-${count.index + 1}"
  location            = azurerm_resource_group.elk_rg.location
  resource_group_name = azurerm_resource_group.elk_rg.name
  ip_address_type     = "Private"
  subnet_ids          = [azurerm_subnet.private_subnet.id]
  os_type             = "Linux"

  container {
    name   = "elasticsearch"
    image  = "docker.elastic.co/elasticsearch/elasticsearch:8.11.0"
    cpu    = var.elasticsearch_cpu
    memory = var.elasticsearch_memory

    ports {
      port     = 9200
      protocol = "TCP"
    }

    ports {
      port     = 9300
      protocol = "TCP"
    }

    environment_variables = {
      "node.name"                      = "es-node-${count.index + 1}"
      "cluster.name"                   = "edtech-${var.environment}"
      "cluster.initial_master_nodes"   = join(",", [for i in range(var.elasticsearch_node_count) : "es-node-${i + 1}"])
      "discovery.seed_hosts"           = join(",", [for i in range(var.elasticsearch_node_count) : "es-node-${i + 1}" if i != count.index])
      "bootstrap.memory_lock"          = "true"
      "ES_JAVA_OPTS"                  = "-Xms${var.elasticsearch_heap_size} -Xmx${var.elasticsearch_heap_size}"
      "xpack.security.enabled"         = "true"
      "xpack.security.transport.ssl.enabled" = "true"
    }

    volume {
      name                 = "elasticsearch-data"
      mount_path           = "/usr/share/elasticsearch/data"
      storage_account_name = azurerm_storage_account.elk_storage.name
      storage_account_key  = azurerm_storage_account.elk_storage.primary_access_key
      share_name          = azurerm_storage_share.elasticsearch_data[count.index].name
    }
  }

  tags = var.common_tags
}

# Storage Account for persistent volumes
resource "azurerm_storage_account" "elk_storage" {
  name                     = "st${var.project_name}${var.environment}"
  resource_group_name      = azurerm_resource_group.elk_rg.name
  location                 = azurerm_resource_group.elk_rg.location
  account_tier             = "Standard"
  account_replication_type = "GRS"

  tags = var.common_tags
}

resource "azurerm_storage_share" "elasticsearch_data" {
  count                = var.elasticsearch_node_count
  name                 = "elasticsearch-data-${count.index + 1}"
  storage_account_name = azurerm_storage_account.elk_storage.name
  quota                = var.elasticsearch_storage_gb
}

# Application Gateway for load balancing
resource "azurerm_public_ip" "elk_gateway_ip" {
  name                = "pip-elk-gateway"
  location            = azurerm_resource_group.elk_rg.location
  resource_group_name = azurerm_resource_group.elk_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = var.common_tags
}

resource "azurerm_application_gateway" "elk_gateway" {
  name                = "agw-elk-${var.environment}"
  resource_group_name = azurerm_resource_group.elk_rg.name
  location            = azurerm_resource_group.elk_rg.location

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 2
  }

  gateway_ip_configuration {
    name      = "gateway-ip-config"
    subnet_id = azurerm_subnet.public_subnet.id
  }

  frontend_port {
    name = "frontend-port-80"
    port = 80
  }

  frontend_port {
    name = "frontend-port-443"
    port = 443
  }

  frontend_ip_configuration {
    name                 = "frontend-ip-config"
    public_ip_address_id = azurerm_public_ip.elk_gateway_ip.id
  }

  backend_address_pool {
    name = "elasticsearch-backend-pool"
    ip_addresses = [for cg in azurerm_container_group.elasticsearch : cg.ip_address]
  }

  backend_http_settings {
    name                  = "elasticsearch-http-settings"
    cookie_based_affinity = "Disabled"
    path                  = "/"
    port                  = 9200
    protocol              = "Http"
    request_timeout       = 60
  }

  http_listener {
    name                           = "elasticsearch-listener"
    frontend_ip_configuration_name = "frontend-ip-config"
    frontend_port_name             = "frontend-port-80"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = "elasticsearch-routing-rule"
    rule_type                  = "Basic"
    http_listener_name         = "elasticsearch-listener"
    backend_address_pool_name  = "elasticsearch-backend-pool"
    backend_http_settings_name = "elasticsearch-http-settings"
    priority                   = 100
  }

  tags = var.common_tags
}
```

### Google Cloud Platform (GCP) Deployment

#### ELK Stack on GCP

```yaml
# terraform/gcp-elk-stack.tf
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# VPC Network
resource "google_compute_network" "elk_network" {
  name                    = "elk-network-${var.environment}"
  auto_create_subnetworks = false
}

# Subnet
resource "google_compute_subnetwork" "elk_subnet" {
  name          = "elk-subnet-${var.environment}"
  ip_cidr_range = var.subnet_cidr
  region        = var.region
  network       = google_compute_network.elk_network.id

  secondary_ip_range {
    range_name    = "pod-range"
    ip_cidr_range = var.pod_cidr
  }

  secondary_ip_range {
    range_name    = "service-range"
    ip_cidr_range = var.service_cidr
  }
}

# Firewall Rules
resource "google_compute_firewall" "elasticsearch_firewall" {
  name    = "elasticsearch-firewall"
  network = google_compute_network.elk_network.name

  allow {
    protocol = "tcp"
    ports    = ["9200", "9300"]
  }

  source_ranges = [var.subnet_cidr]
  target_tags   = ["elasticsearch"]
}

resource "google_compute_firewall" "kibana_firewall" {
  name    = "kibana-firewall"
  network = google_compute_network.elk_network.name

  allow {
    protocol = "tcp"
    ports    = ["5601"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["kibana"]
}

# GKE Cluster for ELK Stack
resource "google_container_cluster" "elk_cluster" {
  name     = "elk-cluster-${var.environment}"
  location = var.region

  # Remove default node pool
  remove_default_node_pool = true
  initial_node_count       = 1

  network    = google_compute_network.elk_network.name
  subnetwork = google_compute_subnetwork.elk_subnet.name

  ip_allocation_policy {
    cluster_secondary_range_name  = "pod-range"
    services_secondary_range_name = "service-range"
  }

  # Enable network policy
  network_policy {
    enabled = true
  }

  addons_config {
    network_policy_config {
      disabled = false
    }
  }

  # Workload Identity
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Enable logging and monitoring
  logging_service    = "logging.googleapis.com/kubernetes"
  monitoring_service = "monitoring.googleapis.com/kubernetes"
}

# Node Pool
resource "google_container_node_pool" "elk_node_pool" {
  name       = "elk-node-pool"
  location   = var.region
  cluster    = google_container_cluster.elk_cluster.name
  node_count = var.node_count

  node_config {
    preemptible  = false
    machine_type = var.node_machine_type
    disk_size_gb = var.node_disk_size
    disk_type    = "pd-ssd"

    # Scopes for the node pool
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]

    # Workload Identity
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    tags = ["elasticsearch", "kibana"]
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
  }
}

# Persistent Disks for Elasticsearch
resource "google_compute_disk" "elasticsearch_data" {
  count = var.elasticsearch_node_count
  name  = "elasticsearch-data-${count.index + 1}"
  type  = "pd-ssd"
  zone  = var.zone
  size  = var.elasticsearch_disk_size
}

# Cloud SQL for metadata (optional)
resource "google_sql_database_instance" "elk_metadata" {
  count            = var.enable_cloud_sql ? 1 : 0
  name             = "elk-metadata-${var.environment}"
  database_version = "POSTGRES_14"
  region           = var.region

  settings {
    tier = var.cloud_sql_tier

    backup_configuration {
      enabled    = true
      start_time = "03:00"
    }

    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.elk_network.id
    }

    disk_size         = 20
    disk_type         = "PD_SSD"
    disk_autoresize   = true
    availability_type = "REGIONAL"
  }

  deletion_protection = var.environment == "production"
}

# Cloud Storage for backups
resource "google_storage_bucket" "elk_backups" {
  name     = "${var.project_id}-elk-backups-${var.environment}"
  location = var.region

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type = "Delete"
    }
  }

  lifecycle_rule {
    condition {
      age = 7
    }
    action {
      type          = "SetStorageClass"
      storage_class = "COLDLINE"
    }
  }
}

# Service Account for Elasticsearch
resource "google_service_account" "elasticsearch_sa" {
  account_id   = "elasticsearch-sa"
  display_name = "Elasticsearch Service Account"
}

resource "google_project_iam_member" "elasticsearch_storage" {
  project = var.project_id
  role    = "roles/storage.objectAdmin"
  member  = "serviceAccount:${google_service_account.elasticsearch_sa.email}"
}

# Kubernetes Service Account
resource "google_service_account_iam_member" "elasticsearch_workload_identity" {
  service_account_id = google_service_account.elasticsearch_sa.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[logging/elasticsearch]"
}
```

## 🔧 Kubernetes Deployment Manifests

### Namespace and RBAC

```yaml
# k8s/namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: logging
  labels:
    name: logging

---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: elasticsearch
  namespace: logging

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: elasticsearch
rules:
- apiGroups: [""]
  resources: ["nodes", "nodes/stats", "services", "endpoints", "pods"]
  verbs: ["get", "list", "watch"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: elasticsearch
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: elasticsearch
subjects:
- kind: ServiceAccount
  name: elasticsearch
  namespace: logging
```

### Elasticsearch StatefulSet

```yaml
# k8s/elasticsearch-statefulset.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: elasticsearch
  namespace: logging
spec:
  serviceName: elasticsearch
  replicas: 3
  selector:
    matchLabels:
      app: elasticsearch
  template:
    metadata:
      labels:
        app: elasticsearch
    spec:
      serviceAccountName: elasticsearch
      securityContext:
        fsGroup: 1000
      initContainers:
      - name: configure-sysctl
        image: docker.elastic.co/elasticsearch/elasticsearch:8.11.0
        command: ["sh", "-c", "sysctl -w vm.max_map_count=262144"]
        securityContext:
          privileged: true
      - name: configure-ownership
        image: docker.elastic.co/elasticsearch/elasticsearch:8.11.0
        command: ["sh", "-c", "chown -R 1000:1000 /usr/share/elasticsearch/data"]
        securityContext:
          privileged: true
        volumeMounts:
        - name: data
          mountPath: /usr/share/elasticsearch/data
      containers:
      - name: elasticsearch
        image: docker.elastic.co/elasticsearch/elasticsearch:8.11.0
        resources:
          limits:
            memory: 4Gi
            cpu: 2
          requests:
            memory: 2Gi
            cpu: 1
        ports:
        - containerPort: 9200
          name: rest
        - containerPort: 9300
          name: inter-node
        volumeMounts:
        - name: data
          mountPath: /usr/share/elasticsearch/data
        - name: config
          mountPath: /usr/share/elasticsearch/config/elasticsearch.yml
          subPath: elasticsearch.yml
        env:
        - name: cluster.name
          value: edtech-k8s-cluster
        - name: node.name
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: discovery.seed_hosts
          value: "elasticsearch-0.elasticsearch,elasticsearch-1.elasticsearch,elasticsearch-2.elasticsearch"
        - name: cluster.initial_master_nodes
          value: "elasticsearch-0,elasticsearch-1,elasticsearch-2"
        - name: ES_JAVA_OPTS
          value: "-Xms2g -Xmx2g"
        - name: xpack.security.enabled
          value: "true"
        - name: xpack.security.transport.ssl.enabled
          value: "true"
        - name: xpack.security.http.ssl.enabled
          value: "true"
        readinessProbe:
          httpGet:
            scheme: HTTP
            path: /_cluster/health?local=true
            port: 9200
          initialDelaySeconds: 5
        livenessProbe:
          httpGet:
            scheme: HTTP
            path: /_cluster/health?local=true
            port: 9200
          initialDelaySeconds: 90
      volumes:
      - name: config
        configMap:
          name: elasticsearch-config
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: [ "ReadWriteOnce" ]
      storageClassName: fast-ssd
      resources:
        requests:
          storage: 100Gi
```

### Monitoring and Alerting

```yaml
# k8s/monitoring.yaml
apiVersion: v1
kind: ServiceMonitor
metadata:
  name: elasticsearch
  namespace: logging
spec:
  selector:
    matchLabels:
      app: elasticsearch
  endpoints:
  - port: rest
    interval: 30s
    path: /_prometheus/metrics

---
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: elasticsearch-alerts
  namespace: logging
spec:
  groups:
  - name: elasticsearch.rules
    rules:
    - alert: ElasticsearchClusterRed
      expr: elasticsearch_cluster_health_status{color="red"} == 1
      for: 1m
      labels:
        severity: critical
      annotations:
        summary: "Elasticsearch cluster is red"
        description: "Elasticsearch cluster {{ $labels.cluster }} is red"

    - alert: ElasticsearchClusterYellow
      expr: elasticsearch_cluster_health_status{color="yellow"} == 1
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "Elasticsearch cluster is yellow"
        description: "Elasticsearch cluster {{ $labels.cluster }} is yellow"

    - alert: ElasticsearchHighMemoryUsage
      expr: elasticsearch_jvm_memory_used_bytes / elasticsearch_jvm_memory_max_bytes > 0.9
      for: 2m
      labels:
        severity: warning
      annotations:
        summary: "Elasticsearch high memory usage"
        description: "Elasticsearch node {{ $labels.node }} memory usage is above 90%"

    - alert: ElasticsearchHighDiskUsage
      expr: elasticsearch_filesystem_data_used_percent > 85
      for: 2m
      labels:
        severity: warning
      annotations:
        summary: "Elasticsearch high disk usage"
        description: "Elasticsearch node {{ $labels.node }} disk usage is above 85%"
```

## 🔗 Navigation

**← Previous**: [Fluentd Configuration](./fluentd-configuration.md)  
**→ Next**: [Performance Analysis](./performance-analysis.md)

---

*Deployment Guide | Log Management & Analysis Research | January 2025*