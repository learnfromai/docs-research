# Implementation Guide: Prometheus & Grafana Monitoring Stack

> Complete step-by-step guide for implementing a production-ready monitoring system using Prometheus, Grafana, and custom dashboards.

## 🎯 Prerequisites

### System Requirements
- **Linux Server**: Ubuntu 20.04+ or CentOS 8+ (minimum 4GB RAM, 2 CPU cores)
- **Storage**: 50GB+ SSD for metrics storage (scales with retention period)
- **Network**: Stable internet connection, ports 9090 (Prometheus), 3000 (Grafana)
- **Domain**: Optional but recommended for SSL/HTTPS setup

### Required Skills
- Basic Linux administration
- Docker and containerization concepts
- Understanding of HTTP/REST APIs
- Familiarity with YAML configuration files

### Tools Installation
```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Install Docker and Docker Compose
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Install essential utilities
sudo apt install -y curl wget git htop tree
```

## 🏗️ Phase 1: Prometheus Setup

### 1.1 Directory Structure Setup
Create organized directory structure for configuration files:

```bash
# Create project directory
mkdir -p ~/monitoring-stack/{prometheus,grafana,alertmanager,exporters}
cd ~/monitoring-stack

# Create Prometheus configuration directory
mkdir -p prometheus/{config,data,rules}
chmod 777 prometheus/data  # Ensure Prometheus can write data
```

### 1.2 Prometheus Configuration
Create the main Prometheus configuration file:

```yaml
# prometheus/config/prometheus.yml
global:
  scrape_interval: 15s      # Scrape targets every 15 seconds
  evaluation_interval: 15s  # Evaluate rules every 15 seconds
  external_labels:
    cluster: 'development'
    region: 'ap-southeast-1'

# Rule files for alerting
rule_files:
  - "/etc/prometheus/rules/*.yml"

# Alert manager configuration
alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - alertmanager:9093

# Scrape configurations
scrape_configs:
  # Prometheus self-monitoring
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
    scrape_interval: 5s
    metrics_path: /metrics

  # Node Exporter for system metrics
  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']
    scrape_interval: 10s

  # Application monitoring (customize for your app)
  - job_name: 'application'
    static_configs:
      - targets: ['host.docker.internal:3001']  # Adjust port for your app
    scrape_interval: 10s
    metrics_path: /metrics

  # Blackbox exporter for URL monitoring
  - job_name: 'blackbox'
    metrics_path: /probe
    params:
      module: [http_2xx]
    static_configs:
      - targets:
        - https://your-edtech-platform.com
        - https://api.your-platform.com/health
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: blackbox-exporter:9115
```

### 1.3 Alert Rules Configuration
Create comprehensive alerting rules:

```yaml
# prometheus/rules/application-alerts.yml
groups:
  - name: application.rules
    rules:
      # High HTTP error rate
      - alert: HighErrorRate
        expr: |
          (
            rate(http_requests_total{status=~"5.."}[5m]) /
            rate(http_requests_total[5m])
          ) > 0.05
        for: 5m
        labels:
          severity: critical
          team: backend
        annotations:
          summary: "High HTTP error rate detected"
          description: "Error rate is {{ $value | humanizePercentage }} for {{ $labels.instance }}"
          runbook_url: "https://docs.your-platform.com/runbooks/high-error-rate"

      # High response time
      - alert: HighResponseTime
        expr: |
          histogram_quantile(0.95, 
            rate(http_request_duration_seconds_bucket[5m])
          ) > 2
        for: 10m
        labels:
          severity: warning
          team: backend
        annotations:
          summary: "High response time detected"
          description: "95th percentile response time is {{ $value }}s for {{ $labels.instance }}"

      # Database connection issues
      - alert: DatabaseConnectionFailure
        expr: |
          db_connections_active / db_connections_max > 0.8
        for: 5m
        labels:
          severity: warning
          team: database
        annotations:
          summary: "Database connection pool nearly exhausted"
          description: "{{ $labels.instance }} is using {{ $value | humanizePercentage }} of database connections"

  - name: infrastructure.rules
    rules:
      # High CPU usage
      - alert: HighCPUUsage
        expr: |
          100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 10m
        labels:
          severity: warning
          team: infrastructure
        annotations:
          summary: "High CPU usage detected"
          description: "CPU usage is {{ $value }}% on {{ $labels.instance }}"

      # High memory usage
      - alert: HighMemoryUsage
        expr: |
          (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 85
        for: 10m
        labels:
          severity: warning
          team: infrastructure
        annotations:
          summary: "High memory usage detected"
          description: "Memory usage is {{ $value }}% on {{ $labels.instance }}"

      # Disk space low
      - alert: DiskSpaceLow
        expr: |
          (node_filesystem_avail_bytes / node_filesystem_size_bytes) * 100 < 10
        for: 5m
        labels:
          severity: critical
          team: infrastructure
        annotations:
          summary: "Disk space critically low"
          description: "Disk space is {{ $value }}% available on {{ $labels.instance }}:{{ $labels.mountpoint }}"
```

### 1.4 Docker Compose Configuration
Create a comprehensive Docker Compose setup:

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
      - '--storage.tsdb.retention.time=30d'
      - '--storage.tsdb.retention.size=10GB'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--web.enable-lifecycle'
      - '--web.enable-admin-api'
    networks:
      - monitoring
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.prometheus.rule=Host(`prometheus.your-domain.com`)"

  grafana:
    image: grafana/grafana:10.0.0
    container_name: grafana
    restart: unless-stopped
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=secure_admin_password_here
      - GF_SECURITY_ADMIN_USER=admin
      - GF_USERS_ALLOW_SIGN_UP=false
      - GF_SECURITY_ALLOW_EMBEDDING=true
      - GF_AUTH_ANONYMOUS_ENABLED=false
      - GF_INSTALL_PLUGINS=grafana-piechart-panel,grafana-worldmap-panel
    volumes:
      - grafana_data:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning
      - ./grafana/dashboards:/var/lib/grafana/dashboards
    networks:
      - monitoring
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.grafana.rule=Host(`grafana.your-domain.com`)"

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
    networks:
      - monitoring

  blackbox-exporter:
    image: prom/blackbox-exporter:v0.24.0
    container_name: blackbox-exporter
    restart: unless-stopped
    ports:
      - "9115:9115"
    volumes:
      - ./blackbox/config:/etc/blackbox_exporter
    networks:
      - monitoring

  alertmanager:
    image: prom/alertmanager:v0.25.0
    container_name: alertmanager
    restart: unless-stopped
    ports:
      - "9093:9093"
    volumes:
      - ./alertmanager/config:/etc/alertmanager
      - alertmanager_data:/alertmanager
    command:
      - '--config.file=/etc/alertmanager/alertmanager.yml'
      - '--storage.path=/alertmanager'
      - '--web.external-url=http://localhost:9093'
    networks:
      - monitoring

volumes:
  grafana_data:
  alertmanager_data:

networks:
  monitoring:
    driver: bridge
```

## 🎨 Phase 2: Grafana Dashboard Setup

### 2.1 Data Source Configuration
Create automatic Prometheus data source provisioning:

```yaml
# grafana/provisioning/datasources/prometheus.yml
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    version: 1
    editable: false
    jsonData:
      httpMethod: POST
      manageAlerts: true
      prometheusType: Prometheus
      prometheusVersion: 2.45.0
      cacheLevel: 'High'
      incrementalQueryOverlapWindow: 10m
```

### 2.2 Dashboard Provisioning
Create dashboard provisioning configuration:

```yaml
# grafana/provisioning/dashboards/default.yml
apiVersion: 1

providers:
  - name: 'default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /var/lib/grafana/dashboards
```

### 2.3 Application Dashboard
Create a comprehensive application monitoring dashboard:

```json
# grafana/dashboards/application-overview.json
{
  "dashboard": {
    "title": "EdTech Application Overview",
    "tags": ["application", "overview"],
    "timezone": "browser",
    "refresh": "30s",
    "time": {
      "from": "now-1h",
      "to": "now"
    },
    "panels": [
      {
        "title": "Request Rate",
        "type": "stat",
        "targets": [
          {
            "expr": "rate(http_requests_total[5m])",
            "legendFormat": "Requests/sec"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "reqps",
            "color": {
              "mode": "thresholds"
            },
            "thresholds": {
              "steps": [
                {"color": "green", "value": null},
                {"color": "yellow", "value": 100},
                {"color": "red", "value": 500}
              ]
            }
          }
        }
      },
      {
        "title": "Error Rate",
        "type": "stat",
        "targets": [
          {
            "expr": "rate(http_requests_total{status=~\"5..\"}[5m]) / rate(http_requests_total[5m]) * 100",
            "legendFormat": "Error %"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "percent",
            "color": {
              "mode": "thresholds"
            },
            "thresholds": {
              "steps": [
                {"color": "green", "value": null},
                {"color": "yellow", "value": 1},
                {"color": "red", "value": 5}
              ]
            }
          }
        }
      },
      {
        "title": "Response Time (95th percentile)",
        "type": "timeseries",
        "targets": [
          {
            "expr": "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))",
            "legendFormat": "95th percentile"
          },
          {
            "expr": "histogram_quantile(0.50, rate(http_request_duration_seconds_bucket[5m]))",
            "legendFormat": "50th percentile"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "s",
            "custom": {
              "drawStyle": "line",
              "lineInterpolation": "smooth"
            }
          }
        }
      }
    ]
  }
}
```

## 🚨 Phase 3: Alertmanager Configuration

### 3.1 Alertmanager Setup
Configure alert routing and notification channels:

```yaml
# alertmanager/config/alertmanager.yml
global:
  smtp_smarthost: 'smtp.gmail.com:587'
  smtp_from: 'alerts@your-edtech-platform.com'
  smtp_auth_username: 'alerts@your-edtech-platform.com'
  smtp_auth_password: 'your-app-password'

route:
  group_by: ['alertname', 'cluster', 'service']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'default-receiver'
  routes:
    - match:
        severity: critical
      receiver: 'critical-alerts'
      group_wait: 0s
      repeat_interval: 5m
    - match:
        severity: warning
      receiver: 'warning-alerts'
      repeat_interval: 30m

receivers:
  - name: 'default-receiver'
    email_configs:
      - to: 'team@your-platform.com'
        subject: 'Alert: {{ .GroupLabels.alertname }}'
        body: |
          {{ range .Alerts }}
          Alert: {{ .Annotations.summary }}
          Description: {{ .Annotations.description }}
          {{ end }}

  - name: 'critical-alerts'
    slack_configs:
      - api_url: 'https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK'
        channel: '#alerts-critical'
        title: 'Critical Alert: {{ .GroupLabels.alertname }}'
        text: |
          {{ range .Alerts }}
          *Alert:* {{ .Annotations.summary }}
          *Description:* {{ .Annotations.description }}
          *Severity:* {{ .Labels.severity }}
          {{ end }}
        actions:
          - type: button
            text: 'Runbook'
            url: '{{ .CommonAnnotations.runbook_url }}'
          - type: button
            text: 'Silence'
            url: '{{ .GeneratorURL }}'
    email_configs:
      - to: 'oncall@your-platform.com'
        subject: 'CRITICAL: {{ .GroupLabels.alertname }}'

  - name: 'warning-alerts'
    slack_configs:
      - api_url: 'https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK'
        channel: '#alerts-warning'
        title: 'Warning: {{ .GroupLabels.alertname }}'
```

## 🚀 Phase 4: Deployment and Testing

### 4.1 Initial Deployment
Deploy the monitoring stack:

```bash
# Navigate to project directory
cd ~/monitoring-stack

# Start all services
docker-compose up -d

# Verify services are running
docker-compose ps

# Check logs for any issues
docker-compose logs -f prometheus
docker-compose logs -f grafana
```

### 4.2 Service Verification
Verify all components are working correctly:

```bash
# Test Prometheus is scraping targets
curl http://localhost:9090/api/v1/targets

# Test Grafana is accessible
curl http://localhost:3000/api/health

# Test Node Exporter metrics
curl http://localhost:9100/metrics

# Test Alertmanager
curl http://localhost:9093/api/v1/status
```

### 4.3 Application Instrumentation
Add monitoring to your Node.js application:

```javascript
// app.js - Express.js application
const express = require('express');
const promClient = require('prom-client');

const app = express();

// Create a Registry to register the metrics
const register = new promClient.Registry();

// Add a default label which is added to all metrics
register.setDefaultLabels({
  app: 'edtech-platform'
});

// Enable the collection of default metrics
promClient.collectDefaultMetrics({ register });

// Create custom metrics
const httpRequestDuration = new promClient.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status_code'],
  buckets: [0.1, 0.3, 0.5, 0.7, 1, 3, 5, 7, 10]
});

const httpRequestsTotal = new promClient.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status_code']
});

const activeUsers = new promClient.Gauge({
  name: 'active_users_total',
  help: 'Number of active users',
  labelNames: ['course_type']
});

// Register custom metrics
register.registerMetric(httpRequestDuration);
register.registerMetric(httpRequestsTotal);
register.registerMetric(activeUsers);

// Middleware to collect metrics
app.use((req, res, next) => {
  const startTime = Date.now();
  
  res.on('finish', () => {
    const endTime = Date.now();
    const duration = (endTime - startTime) / 1000;
    
    httpRequestDuration
      .labels(req.method, req.route?.path || req.path, res.statusCode)
      .observe(duration);
    
    httpRequestsTotal
      .labels(req.method, req.route?.path || req.path, res.statusCode)
      .inc();
  });
  
  next();
});

// Metrics endpoint
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  const metrics = await register.metrics();
  res.end(metrics);
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'healthy', timestamp: new Date().toISOString() });
});

// Update active users periodically (example)
setInterval(async () => {
  // Your logic to count active users
  const licensureExamUsers = await getUserCount('licensure-exam');
  const reviewUsers = await getUserCount('review-courses');
  
  activeUsers.labels('licensure-exam').set(licensureExamUsers);
  activeUsers.labels('review-courses').set(reviewUsers);
}, 30000); // Update every 30 seconds

app.listen(3001, () => {
  console.log('Application running on port 3001');
  console.log('Metrics available at http://localhost:3001/metrics');
});
```

### 4.4 Testing Alert Rules
Test that alerts are firing correctly:

```bash
# Generate test alert by stopping a service
docker-compose stop node-exporter

# Wait a few minutes and check Alertmanager
curl http://localhost:9093/api/v1/alerts

# Check Grafana alerting dashboard
# Navigate to http://localhost:3000/alerting/list

# Restart the service
docker-compose start node-exporter
```

## 🔒 Phase 5: Security and Production Hardening

### 5.1 Enable HTTPS
Configure SSL/TLS certificates:

```bash
# Install Certbot for Let's Encrypt
sudo apt install certbot

# Generate certificates
sudo certbot certonly --standalone -d grafana.your-domain.com -d prometheus.your-domain.com

# Update Docker Compose with SSL
# Add Traefik or Nginx proxy with SSL termination
```

### 5.2 Authentication Setup
Configure authentication for Grafana:

```yaml
# grafana/config/grafana.ini
[auth]
disable_login_form = false
disable_signout_menu = false

[auth.github]
enabled = true
allow_sign_up = true
client_id = your_github_oauth_client_id
client_secret = your_github_oauth_client_secret
scopes = user:email,read:org
auth_url = https://github.com/login/oauth/authorize
token_url = https://github.com/login/oauth/access_token
api_url = https://api.github.com/user
allowed_organizations = your-organization
team_ids = your-team-id
```

### 5.3 Network Security
Configure firewall rules:

```bash
# Configure UFW firewall
sudo ufw enable
sudo ufw allow 22    # SSH
sudo ufw allow 80    # HTTP
sudo ufw allow 443   # HTTPS
sudo ufw allow 3000  # Grafana (if not behind proxy)
sudo ufw allow 9090  # Prometheus (if not behind proxy)

# Block direct access to monitoring ports from external networks
sudo ufw deny from any to any port 9090
sudo ufw deny from any to any port 9093
sudo ufw allow from 10.0.0.0/8 to any port 9090
sudo ufw allow from 10.0.0.0/8 to any port 9093
```

## ✅ Verification Checklist

After deployment, verify all components:

- [ ] **Prometheus**: Accessible at http://localhost:9090, targets showing as UP
- [ ] **Grafana**: Accessible at http://localhost:3000, data source connected
- [ ] **Node Exporter**: System metrics visible in Prometheus
- [ ] **Application Metrics**: Custom metrics appearing in Prometheus
- [ ] **Alerting**: Test alerts firing and notifications received
- [ ] **Dashboards**: All panels displaying data correctly
- [ ] **Security**: Authentication enabled, HTTPS configured
- [ ] **Backup**: Configuration files backed up to version control

## 🔗 Navigation

| Previous | Current | Next |
|----------|---------|------|
| [Executive Summary](./executive-summary.md) | **Implementation Guide** | [Best Practices](./best-practices.md) |

---

**Implementation Timeline**: Plan for 1-2 weeks for complete setup including testing and fine-tuning. Start with basic monitoring and gradually add advanced features.

**Support Resources**: Join the [Prometheus Community](https://prometheus.io/community/) and [Grafana Community](https://community.grafana.com/) for additional help and best practices.