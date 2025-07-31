# Troubleshooting Guide: Metrics & Alerting Systems

> Comprehensive troubleshooting guide for Prometheus, Grafana, and related monitoring infrastructure with specific focus on common issues in EdTech environments.

## 🚨 Emergency Response Procedures

### Critical System Down Checklist

**Step 1: Immediate Assessment (0-5 minutes)**
```bash
# Quick health checks
curl -f http://prometheus:9090/-/healthy || echo "Prometheus DOWN"
curl -f http://grafana:3000/api/health || echo "Grafana DOWN"
curl -f http://alertmanager:9093/-/healthy || echo "Alertmanager DOWN"

# Check container status
docker ps --filter name=prometheus --format "table {{.Names}}\t{{.Status}}"
docker ps --filter name=grafana --format "table {{.Names}}\t{{.Status}}"
```

**Step 2: Service Recovery (5-15 minutes)**
```bash
# Restart monitoring stack
docker-compose restart prometheus grafana alertmanager

# Check logs for startup issues
docker-compose logs -f --tail=50 prometheus
docker-compose logs -f --tail=50 grafana
```

**Step 3: Escalation (15+ minutes)**
- If services don't recover, escalate to senior engineer
- Check infrastructure (disk space, memory, network)
- Consider rollback to last known good configuration

## 🔍 Prometheus Troubleshooting

### Issue: High Memory Usage

**Symptoms:**
- Prometheus consuming >8GB RAM
- OOM (Out of Memory) kills
- Slow query performance

**Diagnosis:**
```bash
# Check memory usage
curl http://localhost:9090/api/v1/status/tsdb | jq '.data.headStats'

# Check series count
promtool query instant 'prometheus_tsdb_head_series'

# Find high cardinality metrics
curl http://localhost:9090/api/v1/label/__name__/values | jq -r '.data[]' | head -20
```

**Solutions:**
```yaml
# 1. Reduce retention period
prometheus:
  command:
    - '--storage.tsdb.retention.time=7d'  # Reduce from 15d
    - '--storage.tsdb.retention.size=5GB' # Add size limit

# 2. Filter high cardinality metrics
scrape_configs:
  - job_name: 'application'
    metric_relabel_configs:
      # Drop metrics with user_id labels
      - source_labels: [__name__]
        regex: '.*_user_id_.*'
        action: drop
      # Keep only essential metrics
      - source_labels: [__name__]
        regex: 'http_requests_total|http_request_duration_seconds|up'
        action: keep
```

### Issue: Missing Metrics/Targets Down

**Symptoms:**
- Targets showing as DOWN in Prometheus
- Missing data in Grafana dashboards
- Alert: "Target down" notifications

**Diagnosis:**
```bash
# Check target status
curl http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | select(.health != "up")'

# Test connectivity
docker exec prometheus nc -zv target-host 9100

# Check target logs
docker logs application-container | grep -i "metrics\|prometheus"
```

**Solutions:**
```bash
# 1. Network connectivity
# Ensure containers can communicate
docker network ls
docker network inspect monitoring-network

# 2. Verify metrics endpoint
curl http://application:3001/metrics

# 3. Check firewall rules
sudo ufw status numbered
sudo ufw allow from 172.0.0.0/8 to any port 9100
```

### Issue: Slow Queries

**Symptoms:**
- Grafana dashboards loading slowly (>10 seconds)
- Query timeout errors
- High CPU usage on Prometheus

**Diagnosis:**
```bash
# Check slow queries in logs
docker logs prometheus 2>&1 | grep "slow query"

# Query metrics about queries
promtool query instant 'prometheus_engine_query_duration_seconds{quantile="0.9"}'
```

**Solutions:**
```yaml
# 1. Use recording rules for complex queries
rules:
  - record: job:http_request_rate5m
    expr: sum(rate(http_requests_total[5m])) by (job)
  
  - record: job:http_error_rate5m  
    expr: sum(rate(http_requests_total{status=~"5.."}[5m])) by (job)

# 2. Optimize query configuration
global:
  query_timeout: 2m
  query_max_concurrency: 10
  query_max_samples: 50000000

# 3. Use more specific label filters
# Instead of: sum(rate(http_requests_total[5m]))
# Use: sum(rate(http_requests_total{job="application"}[5m]))
```

## 📊 Grafana Troubleshooting

### Issue: Dashboard Not Loading

**Symptoms:**
- White screen or infinite loading
- Panel error: "Query failed"
- Browser console errors

**Diagnosis:**
```bash
# Check Grafana logs
docker logs grafana | tail -50

# Test data source connection
curl -H "Authorization: Bearer $API_KEY" \
  http://localhost:3000/api/datasources/proxy/1/api/v1/query?query=up

# Check browser network tab for failed requests
```

**Solutions:**
```bash
# 1. Restart Grafana with clean state
docker-compose stop grafana
docker volume rm grafana_data  # CAUTION: Loses dashboards
docker-compose up -d grafana

# 2. Fix data source configuration
# Update datasource URL if Prometheus moved
# Check authentication settings
# Verify proxy vs direct access mode

# 3. Check panel queries
# Simplify complex queries
# Verify metric names exist in Prometheus
# Check template variable values
```

### Issue: Alerts Not Firing

**Symptoms:**
- Expected alerts not triggering
- No notifications received
- Alert rules showing as inactive

**Diagnosis:**
```bash
# Check alert rule evaluation
curl http://localhost:9090/api/v1/rules | jq '.data.groups[].rules[] | select(.type=="alerting")'

# Test alert query manually
promtool query instant 'up{job="application"} == 0'

# Check Alertmanager status
curl http://localhost:9093/api/v1/alerts
```

**Solutions:**
```yaml
# 1. Fix alert rule syntax
groups:
  - name: application.rules
    rules:
      - alert: ApplicationDown
        # Fix: Use correct operator
        expr: up{job="application"} == 0  # Not =
        for: 1m  # Add appropriate duration
        labels:
          severity: critical
        annotations:
          summary: "Application is down"

# 2. Check Alertmanager routing
route:
  receiver: 'default'
  routes:
    - match:
        severity: critical
      receiver: 'critical-alerts'  # Ensure receiver exists

# 3. Verify notification channels
receivers:
  - name: 'critical-alerts'
    slack_configs:
      - api_url: 'https://hooks.slack.com/...'  # Verify URL
        channel: '#alerts'  # Ensure channel exists
```

## 🏗️ Infrastructure Issues

### Issue: Disk Space Full

**Symptoms:**
- Prometheus fails to start
- Error: "no space left on device"
- Metrics collection stops

**Diagnosis:**
```bash
# Check disk usage
df -h
du -sh /var/lib/prometheus/*
du -sh /var/lib/grafana/*

# Check Prometheus storage usage
curl http://localhost:9090/api/v1/status/tsdb | jq '.data.seriesCountByMetricName | to_entries | sort_by(.value) | reverse | .[0:10]'
```

**Solutions:**
```bash
# 1. Emergency cleanup
# Stop Prometheus safely
docker-compose stop prometheus

# Clean old data (CAREFUL!)
find /var/lib/prometheus -name "*.tmp" -delete
find /var/lib/prometheus -type f -mtime +7 -delete

# 2. Reduce retention
# Edit prometheus.yml
storage:
  tsdb:
    retention.time: 7d      # Reduce from 15d
    retention.size: 10GB    # Add size limit

# 3. Setup log rotation
# Add to /etc/logrotate.d/docker
/var/lib/docker/containers/*/*.log {
    rotate 7
    daily
    compress
    missingok
    delaycompress
    copytruncate
}
```

### Issue: High Load/CPU Usage

**Symptoms:**
- Server load average >4.0
- Prometheus queries timing out
- System unresponsive

**Diagnosis:**
```bash
# Check system load
uptime
top -p $(pgrep prometheus)

# Check Prometheus query load
curl http://localhost:9090/api/v1/status/runtimeinfo

# Identify expensive queries
grep "slow query" /var/log/prometheus.log | tail -10
```

**Solutions:**
```yaml
# 1. Limit concurrent queries
global:
  query_max_concurrency: 5    # Reduce from default 20
  query_timeout: 30s          # Reduce timeout

# 2. Optimize scrape intervals
scrape_configs:
  - job_name: 'heavy-metrics'
    scrape_interval: 60s      # Increase from 15s
    scrape_timeout: 10s

# 3. Use recording rules for dashboard queries
rules:
  - record: dashboard:cpu_usage:avg
    expr: avg(100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100))
```

## 🚨 Alerting Issues

### Issue: Alert Fatigue

**Symptoms:**
- Too many notifications
- Team ignoring alerts
- False positive alerts

**Solutions:**
```yaml
# 1. Implement alert severity levels
labels:
  severity: critical    # Page immediately
  severity: warning     # Slack notification
  severity: info        # Email only

# 2. Add alert grouping
route:
  group_by: ['alertname', 'cluster']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 12h

# 3. Use inhibition rules
inhibit_rules:
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname', 'instance']

# 4. Improve alert thresholds
# Before: cpu > 50%
# After: cpu > 80% for 10 minutes
expr: avg(cpu_usage) > 80
for: 10m
```

### Issue: Missing Notifications

**Symptoms:**
- Alerts firing but no notifications
- Slack/email not received
- Notification channels silent

**Diagnosis:**
```bash
# Check Alertmanager logs
docker logs alertmanager | grep -i "error\|failed"

# Test webhook manually
curl -X POST https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK \
  -H 'Content-type: application/json' \
  -d '{"text":"Test notification"}'

# Check notification queue
curl http://localhost:9093/api/v1/status
```

**Solutions:**
```yaml
# 1. Fix webhook URLs
receivers:
  - name: 'slack-alerts'
    slack_configs:
      - api_url: 'https://hooks.slack.com/services/T00/B00/XXXX'  # Verify URL
        channel: '#alerts'
        username: 'Alertmanager'
        icon_emoji: ':warning:'
        title: 'Alert: {{ .GroupLabels.alertname }}'

# 2. Add email fallback
receivers:
  - name: 'critical-alerts'
    slack_configs: [...]
    email_configs:
      - to: 'oncall@company.com'
        subject: 'CRITICAL: {{ .GroupLabels.alertname }}'
        html: |
          <h3>Alert Details</h3>
          {{ range .Alerts }}
          <p><strong>{{ .Annotations.summary }}</strong></p>
          <p>{{ .Annotations.description }}</p>
          {{ end }}
```

## 📱 Application-Specific Issues

### Issue: Custom Metrics Not Appearing

**Symptoms:**
- Application metrics missing from Prometheus
- Instrumentation code not working
- /metrics endpoint returns empty

**Diagnosis:**
```bash
# Check application metrics endpoint
curl http://application:3001/metrics

# Verify Prometheus scraping
curl http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | select(.labels.job=="application")'

# Check application logs
docker logs application | grep -i "metrics\|prometheus"
```

**Solutions:**
```javascript
// Fix Node.js instrumentation
const promClient = require('prom-client');

// Ensure register is configured
const register = new promClient.Registry();
promClient.collectDefaultMetrics({ register });

// Register custom metrics
const httpRequestsTotal = new promClient.Counter({
  name: 'http_requests_total',
  help: 'Total HTTP requests',
  labelNames: ['method', 'status', 'route']
});
register.registerMetric(httpRequestsTotal);

// Ensure metrics endpoint
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  const metrics = await register.metrics();
  res.end(metrics);
});

// Fix metric updates
app.use((req, res, next) => {
  res.on('finish', () => {
    httpRequestsTotal
      .labels(req.method, res.statusCode, req.route?.path || 'unknown')
      .inc();
  });
  next();
});
```

### Issue: Database Metrics Missing

**Symptoms:**
- PostgreSQL metrics not in Prometheus
- Database performance not visible
- Connection issues not detected

**Solutions:**
```yaml
# Deploy postgres_exporter
services:
  postgres-exporter:
    image: prometheuscommunity/postgres-exporter:v0.12.0
    environment:
      DATA_SOURCE_NAME: "postgresql://monitoring:password@postgres:5432/app?sslmode=disable"
    ports:
      - "9187:9187"
    depends_on:
      - postgres

# Add to prometheus.yml
scrape_configs:
  - job_name: 'postgresql'
    static_configs:
      - targets: ['postgres-exporter:9187']
    scrape_interval: 30s
```

## 🔧 Performance Optimization

### Query Optimization

```promql
# ❌ Inefficient queries
sum(rate(http_requests_total[5m])) by (instance, method, status, path, user_id)

# ✅ Optimized queries  
sum(rate(http_requests_total[5m])) by (instance, status)

# ❌ Avoid long time ranges for rate()
rate(http_requests_total[1d])

# ✅ Use appropriate time ranges
rate(http_requests_total[5m])

# ❌ Complex aggregations in dashboards
histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le, job, instance, method))

# ✅ Use recording rules
job_method:http_request_duration:p95
```

### Storage Optimization

```bash
# Clean up old data
find /var/lib/prometheus -name "*.tmp" -mtime +1 -delete

# Compact storage (Prometheus 2.0+)
promtool tsdb compact /var/lib/prometheus

# Check storage usage by metric
curl http://localhost:9090/api/v1/status/tsdb | \
  jq '.data.seriesCountByMetricName | to_entries | sort_by(.value) | reverse | .[0:20]'
```

## 🆘 Emergency Procedures

### Complete System Recovery

**When monitoring is completely down:**

```bash
# 1. Stop all services
docker-compose down

# 2. Backup current configuration
tar -czf monitoring-backup-$(date +%Y%m%d).tar.gz prometheus/ grafana/ alertmanager/

# 3. Start with basic configuration
# Use minimal prometheus.yml with only self-monitoring
global:
  scrape_interval: 15s
scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

# 4. Start Prometheus only
docker-compose up -d prometheus

# 5. Gradually add other services
docker-compose up -d grafana
docker-compose up -d alertmanager

# 6. Restore full configuration incrementally
```

### Data Recovery

```bash
# Restore from backup
docker-compose down
rm -rf prometheus/data/*
tar -xzf prometheus-data-backup.tar.gz -C prometheus/data/
docker-compose up -d prometheus

# Or start fresh with configuration only
docker volume rm monitoring_prometheus_data
docker-compose up -d prometheus
# Reconfigure targets and rules
```

## 📋 Troubleshooting Checklist

### Daily Health Checks
- [ ] All targets UP in Prometheus
- [ ] No critical alerts firing unexpectedly
- [ ] Grafana dashboards loading properly
- [ ] Alert notifications working
- [ ] Disk space >20% available
- [ ] Memory usage <80%

### Weekly Maintenance
- [ ] Review slow query logs
- [ ] Check storage growth trends
- [ ] Validate backup procedures
- [ ] Update alert thresholds based on trends
- [ ] Review and clean up unused metrics

### Monthly Reviews
- [ ] Analyze alert effectiveness (false positives/negatives)
- [ ] Optimize recording rules and queries
- [ ] Review and update documentation
- [ ] Capacity planning based on growth
- [ ] Security review of access controls

## 🔗 Navigation

| Previous | Current | Next |
|----------|---------|------|
| [Grafana Dashboard Guide](./grafana-dashboard-guide.md) | **Troubleshooting Guide** | [Research Hub](./README.md) |

---

**Emergency Contacts**: Maintain an up-to-date list of team members and escalation procedures. Test notification channels monthly to ensure reliability during actual incidents.

**Documentation Updates**: Keep this troubleshooting guide updated with new issues and solutions discovered during operations. Include timestamps and context for future reference.