# Prometheus Setup Guide

> Detailed guide for installing, configuring, and optimizing Prometheus for production environments, with specific focus on EdTech applications.

## 🎯 Architecture Overview

### Prometheus Ecosystem Components

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Applications  │    │    Exporters    │    │   Prometheus    │
│                 │    │                 │    │     Server      │
│ ┌─────────────┐ │    │ ┌─────────────┐ │    │ ┌─────────────┐ │
│ │ Node.js App │ │───▶│ │Node Exporter│ │───▶│ │Time Series  │ │
│ │/metrics     │ │    │ │/metrics     │ │    │ │ Database    │ │
│ └─────────────┘ │    │ └─────────────┘ │    │ └─────────────┘ │
│                 │    │                 │    │                 │
│ ┌─────────────┐ │    │ ┌─────────────┐ │    │ ┌─────────────┐ │
│ │ PostgreSQL  │ │───▶│ │Postgres Exp │ │───▶│ │ Alert Rules │ │
│ │Database     │ │    │ │/metrics     │ │    │ │Engine       │ │
│ └─────────────┘ │    │ └─────────────┘ │    │ └─────────────┘ │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                                       │
                       ┌─────────────────┐            │
                       │   Alertmanager  │◀───────────┘
                       │                 │
                       │ ┌─────────────┐ │    ┌─────────────────┐
                       │ │Notification │ │───▶│    Grafana      │
                       │ │  Routing    │ │    │                 │
                       │ └─────────────┘ │    │ ┌─────────────┐ │
                       └─────────────────┘    │ │ Dashboards  │ │
                                              │ │ & Alerts    │ │
                                              │ └─────────────┘ │
                                              └─────────────────┘
```

## 🏗️ Installation Methods

### Method 1: Docker Deployment (Recommended for Development)

**Prerequisites:**
```bash
# Install Docker and Docker Compose
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

**Directory Structure:**
```bash
mkdir -p ~/prometheus-setup/{prometheus/{config,data,rules},grafana/{provisioning/{datasources,dashboards},dashboards}}
cd ~/prometheus-setup
```

**Docker Compose Configuration:**
```yaml
# docker-compose.yml
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:v2.45.0
    container_name: prometheus
    restart: unless-stopped
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus/config:/etc/prometheus
      - ./prometheus/data:/prometheus
      - ./prometheus/rules:/etc/prometheus/rules
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--storage.tsdb.retention.time=15d'
      - '--storage.tsdb.retention.size=10GB'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--web.enable-lifecycle'
      - '--web.enable-admin-api'
      - '--web.external-url=http://localhost:9090'
    user: "65534:65534" # nobody:nobody for security
    networks:
      - monitoring

  node-exporter:
    image: prom/node-exporter:v1.6.0
    container_name: node-exporter
    restart: unless-stopped
    pid: host
    ports:
      - "9100:9100"
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.rootfs=/rootfs'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'
      - '--web.listen-address=0.0.0.0:9100'
    networks:
      - monitoring

volumes:
  prometheus_data:

networks:
  monitoring:
    driver: bridge
```

### Method 2: Binary Installation (Production)

**Download and Install:**
```bash
# Create prometheus user
sudo useradd --no-create-home --shell /bin/false prometheus

# Create directories
sudo mkdir /etc/prometheus
sudo mkdir /var/lib/prometheus
sudo chown prometheus:prometheus /etc/prometheus
sudo chown prometheus:prometheus /var/lib/prometheus

# Download Prometheus
cd /tmp
wget https://github.com/prometheus/prometheus/releases/download/v2.45.0/prometheus-2.45.0.linux-amd64.tar.gz
tar -xvf prometheus-2.45.0.linux-amd64.tar.gz
cd prometheus-2.45.0.linux-amd64

# Install binaries
sudo cp prometheus /usr/local/bin/
sudo cp promtool /usr/local/bin/
sudo chown prometheus:prometheus /usr/local/bin/prometheus
sudo chown prometheus:prometheus /usr/local/bin/promtool

# Install console files
sudo cp -r consoles /etc/prometheus
sudo cp -r console_libraries /etc/prometheus
sudo chown -R prometheus:prometheus /etc/prometheus/consoles
sudo chown -R prometheus:prometheus /etc/prometheus/console_libraries

# Clean up
cd /
rm -rf /tmp/prometheus-2.45.0.linux-amd64*
```

**Create Systemd Service:**
```ini
# /etc/systemd/system/prometheus.service
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \
    --config.file /etc/prometheus/prometheus.yml \
    --storage.tsdb.path /var/lib/prometheus/ \
    --storage.tsdb.retention.time=15d \
    --storage.tsdb.retention.size=10GB \
    --web.console.templates=/etc/prometheus/consoles \
    --web.console.libraries=/etc/prometheus/console_libraries \
    --web.listen-address=0.0.0.0:9090 \
    --web.enable-lifecycle \
    --web.enable-admin-api

[Install]
WantedBy=multi-user.target
```

## ⚙️ Configuration

### Main Configuration File

```yaml
# prometheus/config/prometheus.yml
global:
  scrape_interval: 15s        # Default scrape interval
  evaluation_interval: 15s    # Rule evaluation interval
  external_labels:
    cluster: 'production'
    datacenter: 'ap-southeast-1'
    environment: 'prod'

# Rule files for alerting and recording rules
rule_files:
  - "/etc/prometheus/rules/*.yml"

# Alertmanager configuration
alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - alertmanager:9093
      timeout: 10s
      api_version: v2

# Scrape configurations
scrape_configs:
  # Prometheus self-monitoring
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
    scrape_interval: 5s
    metrics_path: '/metrics'
    
  # Node Exporter for system metrics
  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']
    scrape_interval: 10s
    scrape_timeout: 5s
    
  # EdTech Application monitoring
  - job_name: 'edtech-application'
    static_configs:
      - targets: 
        - 'app-server-1:3001'
        - 'app-server-2:3001'
    scrape_interval: 10s
    metrics_path: '/metrics'
    relabel_configs:
      - source_labels: [__address__]
        target_label: instance
      - source_labels: [__address__]
        regex: '([^:]+):.*'
        target_label: host
        replacement: '${1}'
        
  # PostgreSQL monitoring
  - job_name: 'postgresql'
    static_configs:
      - targets: ['postgres-exporter:9187']
    scrape_interval: 30s
    
  # Redis monitoring
  - job_name: 'redis'
    static_configs:
      - targets: ['redis-exporter:9121']
    scrape_interval: 30s
    
  # Nginx monitoring
  - job_name: 'nginx'
    static_configs:
      - targets: ['nginx-exporter:9113']
    scrape_interval: 30s
    
  # Blackbox monitoring for external URLs
  - job_name: 'blackbox-http'
    metrics_path: /probe
    params:
      module: [http_2xx]
    static_configs:
      - targets:
        - https://your-edtech-platform.com
        - https://api.your-platform.com/health
        - https://admin.your-platform.com/health
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: blackbox-exporter:9115
        
  # SSL certificate monitoring
  - job_name: 'blackbox-ssl'
    metrics_path: /probe
    params:
      module: [tcp_connect]
    static_configs:
      - targets:
        - your-edtech-platform.com:443
        - api.your-platform.com:443
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: blackbox-exporter:9115
```

### Recording Rules for Performance

Create pre-computed metrics for faster dashboard queries:

```yaml
# prometheus/rules/recording-rules.yml
groups:
  - name: edtech.recording.rules
    interval: 30s
    rules:
      # HTTP request rate by job
      - record: job:http_requests:rate5m
        expr: sum(rate(http_requests_total[5m])) by (job)
        
      # HTTP error rate by job
      - record: job:http_errors:rate5m
        expr: sum(rate(http_requests_total{status=~"5.."}[5m])) by (job)
        
      # HTTP error percentage by job
      - record: job:http_error_percentage:rate5m
        expr: |
          (
            job:http_errors:rate5m / job:http_requests:rate5m
          ) * 100
          
      # HTTP request duration 95th percentile by job
      - record: job:http_request_duration:p95
        expr: |
          histogram_quantile(0.95,
            sum(rate(http_request_duration_seconds_bucket[5m])) by (job, le)
          )
          
      # Active user count by course type
      - record: edtech:active_users:total
        expr: sum(active_users_total) by (course_type)
        
      # Database connection utilization
      - record: postgresql:connection_utilization:percentage
        expr: |
          (
            postgresql_stat_database_numbackends / 
            postgresql_settings_max_connections
          ) * 100
          
      # System load average normalized by CPU count
      - record: node:load1_per_cpu:ratio
        expr: |
          (
            node_load1 / 
            count(count(node_cpu_seconds_total) by (cpu))
          )
```

### Alert Rules for EdTech Platform

```yaml
# prometheus/rules/edtech-alerts.yml
groups:
  - name: edtech.critical.alerts
    rules:
      # Application completely down
      - alert: ApplicationDown
        expr: up{job="edtech-application"} == 0
        for: 1m
        labels:
          severity: critical
          team: backend
          service: application
        annotations:
          summary: "EdTech application is down"
          description: "Application instance {{ $labels.instance }} has been down for more than 1 minute"
          runbook_url: "https://docs.your-platform.com/runbooks/application-down"
          
      # High error rate
      - alert: HighErrorRate
        expr: job:http_error_percentage:rate5m > 5
        for: 5m
        labels:
          severity: critical
          team: backend
          service: application
        annotations:
          summary: "High HTTP error rate detected"
          description: "Error rate is {{ $value | humanizePercentage }} for {{ $labels.job }}"
          runbook_url: "https://docs.your-platform.com/runbooks/high-error-rate"
          
      # Database connection failure
      - alert: DatabaseConnectionHigh
        expr: postgresql:connection_utilization:percentage > 90
        for: 5m
        labels:
          severity: critical
          team: database
          service: postgresql
        annotations:
          summary: "Database connection pool nearly exhausted"
          description: "PostgreSQL connection utilization is {{ $value }}%"
          runbook_url: "https://docs.your-platform.com/runbooks/database-connections"
          
      # SSL certificate expiring
      - alert: SSLCertificateExpiringSoon
        expr: probe_ssl_earliest_cert_expiry - time() < 86400 * 7
        for: 1h
        labels:
          severity: warning
          team: infrastructure
          service: ssl
        annotations:
          summary: "SSL certificate expires in less than 7 days"
          description: "SSL certificate for {{ $labels.instance }} expires in {{ $value | humanizeDuration }}"
          
  - name: edtech.performance.alerts
    rules:
      # High response time
      - alert: HighResponseTime
        expr: job:http_request_duration:p95 > 2
        for: 10m
        labels:
          severity: warning
          team: backend
          service: application
        annotations:
          summary: "High response time detected"
          description: "95th percentile response time is {{ $value }}s for {{ $labels.job }}"
          
      # High system load
      - alert: HighSystemLoad
        expr: node:load1_per_cpu:ratio > 2
        for: 15m
        labels:
          severity: warning
          team: infrastructure
          service: system
        annotations:
          summary: "High system load detected"
          description: "Load average per CPU is {{ $value }} on {{ $labels.instance }}"
          
  - name: edtech.business.alerts
    rules:
      # Unusual drop in active users
      - alert: ActiveUsersDropped
        expr: |
          (
            edtech:active_users:total - 
            edtech:active_users:total offset 1h
          ) / edtech:active_users:total offset 1h * 100 < -50
        for: 30m
        labels:
          severity: warning
          team: product
          service: platform
        annotations:
          summary: "Significant drop in active users"
          description: "Active users dropped by {{ $value | humanizePercentage }} in the last hour"
```

## 🚀 Optimization for EdTech Workloads

### Storage Configuration

```yaml
# Optimized for EdTech metrics patterns
storage:
  # Retention based on metric importance
  retention_policies:
    # Business metrics - keep longer for analysis
    - match: '{__name__=~"user_.*|course_.*|payment_.*"}'
      retention: "90d"
    
    # Application metrics - medium retention
    - match: '{__name__=~"http_.*|db_.*"}'
      retention: "30d"
      
    # Infrastructure metrics - shorter retention
    - match: '{__name__=~"node_.*|container_.*"}'
      retention: "15d"
      
  # Block configuration for better performance
  tsdb:
    min_block_duration: "2h"
    max_block_duration: "25h"
    retention_size: "50GB"
```

### Query Performance Optimization

```yaml
# Global query settings
global:
  query_timeout: "2m"
  query_max_concurrency: 20
  query_max_samples: 50000000

# Remote read configuration for long-term storage
remote_read:
  - url: "http://cortex:8080/api/prom/read"
    read_recent: true
    
# Remote write for backup/long-term storage
remote_write:
  - url: "http://cortex:8080/api/prom/push"
    write_relabel_configs:
      # Only send important metrics to long-term storage
      - source_labels: [__name__]
        regex: 'user_.*|course_.*|payment_.*|up|job:.*'
        action: keep
```

### Service Discovery for Dynamic Environments

```yaml
# Kubernetes service discovery
scrape_configs:
  - job_name: 'kubernetes-pods'
    kubernetes_sd_configs:
      - role: pod
        namespaces:
          names: ['default', 'edtech-production']
    relabel_configs:
      # Only scrape pods with monitoring annotation
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
        action: keep
        regex: true
      # Use custom port if specified
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_port]
        action: replace
        target_label: __address__
        regex: (.+)
        replacement: ${1}
      # Add service name label
      - source_labels: [__meta_kubernetes_pod_label_app]
        target_label: service
      # Add environment label
      - source_labels: [__meta_kubernetes_namespace]
        target_label: environment
        
  # Consul service discovery for traditional deployments
  - job_name: 'consul-services'
    consul_sd_configs:
      - server: 'consul.service.consul:8500'
        tags: ['monitoring', 'edtech']
    relabel_configs:
      - source_labels: [__meta_consul_service]
        target_label: service
      - source_labels: [__meta_consul_node]
        target_label: node
      - source_labels: [__meta_consul_tags]
        regex: '.*,environment=([^,]+),.*'
        target_label: environment
```

## 🔧 Troubleshooting

### Common Issues and Solutions

**1. High Memory Usage**
```bash
# Check current memory usage
curl http://localhost:9090/api/v1/status/tsdb

# Optimize retention and storage
# Edit prometheus.yml:
storage:
  tsdb:
    retention.time: "7d"      # Reduce if needed
    retention.size: "10GB"    # Add size limit
```

**2. Slow Queries**
```bash
# Check query performance
curl http://localhost:9090/api/v1/status/runtimeinfo

# Monitor slow queries in logs
docker logs prometheus | grep "slow query"

# Use recording rules for complex queries
# Replace dashboard queries with pre-computed metrics
```

**3. High Cardinality Issues**
```bash
# Find high cardinality metrics
curl http://localhost:9090/api/v1/label/__name__/values | jq '.'

# Check series count per metric
promtool query instant 'prometheus_tsdb_symbol_table_size_bytes'

# Fix by reducing label cardinality
# Remove user_id, request_id, and other unique labels
```

**4. Target Discovery Issues**
```bash
# Check target status
curl http://localhost:9090/api/v1/targets

# Verify network connectivity
docker exec prometheus nc -zv target-host 9100

# Check service discovery
curl http://localhost:9090/api/v1/targets?state=active
```

### Health Checks and Monitoring

```bash
# Prometheus health check
curl http://localhost:9090/-/healthy

# Ready check (for load balancers)
curl http://localhost:9090/-/ready

# Configuration reload (after changes)
curl -X POST http://localhost:9090/-/reload

# TSDB statistics
curl http://localhost:9090/api/v1/status/tsdb

# Build information
curl http://localhost:9090/api/v1/status/buildinfo
```

## 📊 Performance Monitoring

### Key Metrics to Monitor

```promql
# Prometheus self-monitoring queries

# Ingestion rate (samples per second)
rate(prometheus_tsdb_samples_appended_total[5m])

# Memory usage
prometheus_tsdb_head_series

# Query duration
histogram_quantile(0.95, rate(prometheus_http_request_duration_seconds_bucket[5m]))

# Storage size
prometheus_tsdb_size_bytes

# Rule evaluation duration
histogram_quantile(0.95, rate(prometheus_rule_evaluation_duration_seconds_bucket[5m]))
```

### Capacity Planning

```yaml
# Resource requirements estimation
capacity_planning:
  metrics_ingestion:
    # Estimate: 1-2 bytes per sample
    samples_per_second: 10000
    storage_per_day: "1.7GB"    # 10k samples/s * 86400s * 2 bytes
    
  memory_requirements:
    # Estimate: 1-3 bytes per series in memory
    active_series: 100000
    memory_for_series: "300MB"   # 100k series * 3 bytes
    overhead: "700MB"            # OS, queries, buffers
    total_memory: "1GB"          # Minimum recommended
    
  storage_planning:
    retention_days: 15
    total_storage: "25GB"        # 1.7GB/day * 15 days
    recommended_disk: "50GB"     # 2x for safety and growth
```

## 🔗 Navigation

| Previous | Current | Next |
|----------|---------|------|
| [Comparison Analysis](./comparison-analysis.md) | **Prometheus Setup Guide** | [Grafana Dashboard Guide](./grafana-dashboard-guide.md) |

---

**Setup Timeline**: Allow 1-2 days for initial setup, 1 week for comprehensive configuration and testing.

**Next Steps**: Once Prometheus is running, proceed to [Grafana Dashboard Guide](./grafana-dashboard-guide.md) to create visualization and alerting dashboards.