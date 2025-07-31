# Best Practices: Metrics & Alerting Systems

> Production-ready patterns, recommendations, and lessons learned from implementing Prometheus and Grafana monitoring systems at scale.

## 🎯 Fundamental Principles

### 1. The Four Golden Signals
Focus monitoring efforts on these critical metrics:

```yaml
Golden Signals:
  Latency: "How long does it take to serve a request?"
    - HTTP response times
    - Database query times
    - API call durations
  
  Traffic: "How much demand is being placed on your system?"
    - Requests per second
    - Active users
    - Database connections
  
  Errors: "What is the rate of requests that fail?"
    - HTTP 4xx/5xx responses
    - Exception rates
    - Failed database queries
  
  Saturation: "How full is your service?"
    - CPU utilization
    - Memory usage
    - Disk I/O
    - Network bandwidth
```

### 2. Monitoring Strategy Hierarchy
Structure your monitoring approach in layers:

```
📊 Business Metrics (KPIs)
   ├── User engagement rates
   ├── Course completion rates
   └── Revenue per user

🔧 Application Metrics (SLIs)
   ├── API response times
   ├── Error rates
   └── Feature usage

⚙️ Infrastructure Metrics
   ├── Server health
   ├── Database performance
   └── Network connectivity

🔍 Synthetic Monitoring
   ├── Uptime checks
   ├── API health probes
   └── User journey tests
```

## 📏 Metrics Collection Best Practices

### 1. Naming Conventions
Follow consistent metric naming patterns:

```prometheus
# Good naming patterns
http_requests_total{method="GET", handler="/api/users", status="200"}
http_request_duration_seconds{method="POST", handler="/api/login"}
database_query_duration_seconds{query="select_user", database="postgresql"}
user_sessions_active{course_type="licensure_exam"}

# Avoid these patterns
requestsTotal              # Missing units and context
HTTP_Requests             # Inconsistent case
db-query-time             # Wrong separator
userCount                 # Ambiguous scope
```

### 2. Label Design Principles
Design labels for efficient querying and aggregation:

```yaml
# ✅ Good Label Design
labels:
  - method: "GET"         # Low cardinality
  - handler: "/api/users" # Bounded cardinality
  - status: "200"         # Known values
  - region: "ap-southeast-1" # Geographic context

# ❌ Avoid High Cardinality Labels
bad_labels:
  - user_id: "12345"      # Unbounded cardinality
  - timestamp: "2024-01-15" # Time-based labels
  - request_id: "abc123"  # Unique identifiers
  - ip_address: "1.2.3.4" # Too many possible values
```

### 3. Metric Types Usage
Choose appropriate metric types for different use cases:

```javascript
// Counter - Monotonically increasing values
const httpRequestsTotal = new promClient.Counter({
  name: 'http_requests_total',
  help: 'Total HTTP requests',
  labelNames: ['method', 'status', 'handler']
});

// Gauge - Values that can go up and down
const activeUsers = new promClient.Gauge({
  name: 'active_users',
  help: 'Currently active users',
  labelNames: ['course_type']
});

// Histogram - Distribution of measurements
const httpDuration = new promClient.Histogram({
  name: 'http_request_duration_seconds',
  help: 'HTTP request duration in seconds',
  labelNames: ['method', 'handler'],
  buckets: [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10]
});

// Summary - Similar to histogram but different quantiles
const responseSize = new promClient.Summary({
  name: 'http_response_size_bytes',
  help: 'HTTP response size in bytes',
  labelNames: ['method', 'handler'],
  percentiles: [0.5, 0.9, 0.95, 0.99]
});
```

## 🚨 Alerting Best Practices

### 1. Alert Design Philosophy
Create alerts that require human action:

```yaml
Alert Categories:
  Actionable: "Something is broken and needs immediate attention"
    - Service is down
    - Error rate > 5%
    - Disk space < 10%
  
  Informational: "Someone should be aware but no immediate action needed"
    - Deployment notifications
    - Performance degradation warnings
    - Capacity planning alerts
  
  Not Alerts: "Interesting but not requiring human intervention"
    - Individual request failures
    - Temporary spikes
    - Normal operational variations
```

### 2. Alert Rule Patterns
Use these proven alert rule patterns:

```yaml
# Pattern 1: Rate-based alerts for sudden changes
- alert: HighErrorRateSudden
  expr: |
    (
      rate(http_requests_total{status=~"5.."}[5m]) /
      rate(http_requests_total[5m])
    ) > 0.05
  for: 2m  # Short duration for sudden issues

# Pattern 2: Threshold-based alerts with hysteresis
- alert: HighMemoryUsage
  expr: |
    (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 85
  for: 10m  # Longer duration to avoid flapping

# Pattern 3: Absence alerts for critical services
- alert: ServiceDown
  expr: |
    up{job="application"} == 0
  for: 1m

# Pattern 4: Burn rate alerts for SLO monitoring
- alert: HighBurnRate
  expr: |
    (
      (1 - (rate(http_requests_total{status!~"5.."}[1h]) / rate(http_requests_total[1h]))) * 100
    ) > 2  # 2% error rate
  for: 2m
```

### 3. Alert Severity Levels
Implement consistent severity levels:

```yaml
Severity Levels:
  critical:
    description: "Service is completely down or severely impacted"
    response_time: "5 minutes"
    escalation: "Page on-call engineer immediately"
    examples:
      - Application completely unreachable
      - Database server down
      - Critical security breach
      - Data corruption detected
  
  warning:
    description: "Service is degraded but functional"
    response_time: "30 minutes during business hours"
    escalation: "Slack notification to team channel"
    examples:
      - High response times (>2 seconds)
      - Error rate elevated (>1%)
      - Resource utilization high (>80%)
      - Non-critical component failure
  
  info:
    description: "Informational events worth tracking"
    response_time: "Next business day"
    escalation: "Email notification or dashboard"
    examples:
      - Deployment notifications
      - Scheduled maintenance
      - Capacity planning triggers
      - Performance improvement opportunities
```

## 📊 Dashboard Design Best Practices

### 1. Dashboard Hierarchy
Organize dashboards by audience and detail level:

```
📊 Executive Dashboards
   ├── Business KPIs (daily/weekly views)
   ├── Service availability overview
   └── Customer satisfaction metrics

🔧 Operational Dashboards
   ├── Service health overview
   ├── Infrastructure monitoring
   └── Alert summary

🔍 Debugging Dashboards
   ├── Detailed service metrics
   ├── Infrastructure deep dive
   └── Application performance analysis

📈 Planning Dashboards
   ├── Capacity planning
   ├── Growth trend analysis
   └── Cost optimization
```

### 2. Panel Design Principles
Create effective visualizations:

```json
{
  "panel_design_rules": {
    "single_stat_panels": {
      "use_for": "Key metrics that need immediate attention",
      "examples": ["Current error rate", "Active users", "Response time"],
      "thresholds": "Use colors (green/yellow/red) for quick status indication",
      "units": "Always include appropriate units (%, ms, GB/s)"
    },
    "time_series_panels": {
      "use_for": "Trending data over time",
      "time_range": "Default to 1-6 hours for operational, 24h+ for planning",
      "legend": "Keep concise, use template variables for filtering",
      "multiple_series": "Limit to 5-7 lines for readability"
    },
    "heatmap_panels": {
      "use_for": "Distribution analysis (response time percentiles)",
      "bucket_size": "Choose bucket sizes that match your SLOs",
      "color_scheme": "Use color schemes that highlight problems (reds)"
    }
  }
}
```

### 3. Template Variables
Use template variables for interactive dashboards:

```json
{
  "template_variables": [
    {
      "name": "environment",
      "type": "query",
      "query": "label_values(up, environment)",
      "multi": false,
      "include_all": false
    },
    {
      "name": "service",
      "type": "query", 
      "query": "label_values(up{environment=\"$environment\"}, job)",
      "multi": true,
      "include_all": true
    },
    {
      "name": "instance",
      "type": "query",
      "query": "label_values(up{job=\"$service\"}, instance)",
      "multi": true,
      "include_all": true
    }
  ]
}
```

## 🏗️ Infrastructure Best Practices

### 1. Prometheus Configuration Optimization

```yaml
# Optimized Prometheus configuration
global:
  scrape_interval: 15s          # Balance between granularity and storage
  evaluation_interval: 15s      # Match scrape interval
  external_labels:
    cluster: 'production'       # Add cluster context
    datacenter: 'ap-southeast-1'

# Storage optimization
storage:
  tsdb:
    retention.time: 15d         # Adjust based on needs and storage
    retention.size: 50GB        # Prevent disk space issues
    min-block-duration: 2h     # Optimize for your query patterns
    max-block-duration: 25h    # Balance compression vs query performance

# Memory optimization
query:
  max-concurrency: 20         # Limit concurrent queries
  timeout: 2m                 # Prevent runaway queries
  max-samples: 50000000       # Limit sample processing
```

### 2. Service Discovery Patterns
Implement dynamic service discovery:

```yaml
# Kubernetes service discovery
scrape_configs:
  - job_name: 'kubernetes-pods'
    kubernetes_sd_configs:
      - role: pod
    relabel_configs:
      # Only scrape pods with prometheus.io/scrape annotation
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
        action: keep
        regex: true
      # Use custom port if specified
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_port]
        action: replace
        target_label: __address__
        regex: (.+)
        replacement: ${1}
      # Use custom path if specified
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
        action: replace
        target_label: __metrics_path__
        regex: (.+)

# Consul service discovery
  - job_name: 'consul-services'
    consul_sd_configs:
      - server: 'consul.service.consul:8500'
        tags: ['monitoring']
    relabel_configs:
      - source_labels: [__meta_consul_service]
        target_label: job
      - source_labels: [__meta_consul_node]
        target_label: instance
```

### 3. High Availability Setup
Design for reliability:

```yaml
# HA Prometheus setup with federation
global:
  external_labels:
    replica: '1'              # Unique identifier for each instance

# Federation configuration
scrape_configs:
  - job_name: 'federate'
    scrape_interval: 15s
    honor_labels: true
    metrics_path: '/federate'
    params:
      'match[]':
        - '{job=~"application.*"}'    # Federate application metrics
        - '{__name__=~"job:.*"}'      # Federate recording rules
    static_configs:
      - targets:
        - 'prometheus-1:9090'
        - 'prometheus-2:9090'

# Recording rules for aggregation
rule_files:
  - "recording_rules/*.yml"
```

## 🔐 Security Best Practices

### 1. Authentication and Authorization
Secure your monitoring infrastructure:

```yaml
# Grafana RBAC configuration
rbac:
  viewers:
    permissions:
      - "read dashboards"
      - "read alerts"
    restrictions:
      - "cannot modify dashboards"
      - "cannot access admin settings"
  
  editors:
    permissions:
      - "create/edit dashboards"
      - "manage alerts"
    restrictions:
      - "cannot access data sources"
      - "cannot manage users"
  
  admins:
    permissions:
      - "full access"
    responsibilities:
      - "user management"
      - "data source configuration"
      - "system administration"
```

### 2. Network Security
Implement network isolation:

```bash
# Firewall rules for monitoring stack
# Allow only necessary ports and sources

# Internal monitoring network (adjust CIDR as needed)
MONITOR_NETWORK="10.0.0.0/24"

# Prometheus (only internal access)
ufw allow from $MONITOR_NETWORK to any port 9090

# Grafana (web interface access)
ufw allow from anywhere to any port 443  # HTTPS only
ufw deny from anywhere to any port 3000  # Block direct access

# Node exporter (only Prometheus access)
ufw allow from $MONITOR_NETWORK to any port 9100
ufw deny from anywhere to any port 9100

# Alertmanager (only internal access)
ufw allow from $MONITOR_NETWORK to any port 9093
```

### 3. Data Protection
Protect sensitive monitoring data:

```yaml
# Sensitive data handling
prometheus_config:
  scrape_configs:
    # Remove sensitive labels
    - job_name: 'application'
      metric_relabel_configs:
        - regex: 'password|secret|token|key'
          action: labeldrop
        - source_labels: [__name__]
          regex: '.*_(password|secret|token|key).*'
          action: drop

# Grafana data source security
grafana_datasource:
  secureJsonData:
    httpHeaderValue1: "$API_TOKEN"  # Use environment variables
  jsonData:
    httpHeaderName1: "Authorization"
    tlsSkipVerify: false            # Always verify SSL
```

## 📈 Performance Optimization

### 1. Query Optimization
Write efficient PromQL queries:

```promql
# ✅ Efficient queries
# Use recording rules for complex calculations
rate(http_requests_total[5m])  # Simple rate calculation

# Use appropriate time ranges
avg_over_time(cpu_usage[10m])  # Match your scrape interval

# Limit label cardinality
http_requests_total{status!="200"}  # Exclude common values

# ❌ Inefficient queries  
# Avoid regex when possible
http_requests_total{path=~"/api/.*"}  # Use specific labels instead

# Don't use unnecessarily long time ranges
rate(http_requests_total[1d])  # Too long for rate calculations

# Avoid high cardinality grouping
sum by (instance, path, method, status, user_id) (http_requests_total)
```

### 2. Storage Optimization
Manage storage efficiently:

```yaml
# Retention policies by importance
retention_policies:
  critical_metrics: "90d"      # Business-critical data
  application_metrics: "30d"   # Application performance
  infrastructure_metrics: "15d" # System health
  debug_metrics: "7d"          # Troubleshooting data

# Downsampling strategy
downsampling:
  raw_data: "0-7d"            # Keep full resolution for 1 week
  hourly_aggregates: "7d-30d" # Hourly resolution for 1 month
  daily_aggregates: "30d+"    # Daily resolution for long-term
```

### 3. Resource Planning
Size your monitoring infrastructure:

```yaml
resource_planning:
  prometheus_server:
    cpu_cores: 4                 # 2-4 cores for most workloads
    memory_gb: 16                # 2GB per million series
    storage_gb: 500              # Plan for 1-2 bytes per sample
    network_mbps: 100            # Sufficient for most scraping
  
  grafana_server:
    cpu_cores: 2                 # CPU-light for most dashboards
    memory_gb: 4                 # Memory for dashboard rendering
    storage_gb: 50               # Configuration and session data
  
  scaling_triggers:
    cpu_utilization: 70          # Scale up at 70% CPU
    memory_utilization: 80       # Scale up at 80% memory
    query_latency: 5000          # Scale up at 5s query latency
```

## 🔄 Operational Excellence

### 1. Backup and Recovery
Implement comprehensive backup strategies:

```bash
#!/bin/bash
# Backup script for monitoring infrastructure

BACKUP_DIR="/backup/monitoring/$(date +%Y%m%d)"
mkdir -p $BACKUP_DIR

# Backup Prometheus data
rsync -av /opt/prometheus/data/ $BACKUP_DIR/prometheus/

# Backup Grafana configuration
docker exec grafana grafana-cli admin export-dashboard > $BACKUP_DIR/grafana-dashboards.json
cp -r /opt/grafana/provisioning $BACKUP_DIR/grafana/

# Backup alert rules and configurations
cp -r /opt/prometheus/rules $BACKUP_DIR/prometheus/
cp /opt/alertmanager/alertmanager.yml $BACKUP_DIR/

# Upload to cloud storage
aws s3 sync $BACKUP_DIR s3://monitoring-backups/$(date +%Y%m%d)/

# Cleanup old backups (keep 30 days)
find /backup/monitoring -type d -mtime +30 -exec rm -rf {} \;
```

### 2. Change Management
Implement safe change procedures:

```yaml
change_management:
  configuration_changes:
    - "Test in development environment first"
    - "Use infrastructure as code (Terraform/Ansible)"
    - "Implement gradual rollouts"
    - "Monitor for issues after changes"
    
  alert_rule_changes:
    - "Test alert rules with historical data"
    - "Validate notification channels"
    - "Document alert runbooks"
    - "Review with team before deployment"
    
  dashboard_changes:
    - "Use dashboard versioning"
    - "Test with different time ranges"
    - "Validate template variables"
    - "Get stakeholder approval for business dashboards"
```

### 3. Documentation Standards
Maintain comprehensive documentation:

```markdown
# Required Documentation
1. **Runbooks**: Step-by-step procedures for each alert
2. **Architecture Diagrams**: Visual representation of monitoring setup
3. **Configuration Management**: Git repository with all configs
4. **Disaster Recovery**: Procedures for complete system recovery
5. **Onboarding Guide**: How new team members can learn the system
6. **Troubleshooting Guide**: Common issues and their solutions
```

## ✅ Checklist for Production Readiness

### Pre-Deployment Checklist
- [ ] **Configuration validated** in development environment
- [ ] **Alert rules tested** with historical data
- [ ] **Dashboards reviewed** by stakeholders
- [ ] **Security implemented** (authentication, network isolation)
- [ ] **Backup procedures** tested and documented
- [ ] **Monitoring team trained** on procedures
- [ ] **Runbooks created** for all critical alerts
- [ ] **Disaster recovery plan** documented and tested

### Post-Deployment Checklist
- [ ] **All services healthy** and collecting metrics
- [ ] **Alerts firing correctly** (test with controlled failures)
- [ ] **Dashboards loading** without errors
- [ ] **Notification channels working** (Slack, email, PagerDuty)
- [ ] **Performance acceptable** (query response times <5s)
- [ ] **Storage growth trending** as expected
- [ ] **Team comfortable** with operational procedures
- [ ] **Feedback collected** and improvements planned

## 🔗 Navigation

| Previous | Current | Next |
|----------|---------|------|
| [Implementation Guide](./implementation-guide.md) | **Best Practices** | [Comparison Analysis](./comparison-analysis.md) |

---

**Key Takeaway**: Focus on actionable alerts, efficient queries, and comprehensive documentation. A well-configured monitoring system prevents issues rather than just reporting them.

**Continuous Improvement**: Regularly review and optimize your monitoring setup based on operational experience and changing requirements.