# Troubleshooting: Kubernetes Deployment Strategies

> **Comprehensive debugging guide, common issues, and resolution strategies for EdTech platform deployments**

## 🎯 Troubleshooting Overview

This document provides systematic troubleshooting approaches for common Kubernetes deployment issues in EdTech environments, with focus on production incident resolution and preventive measures.

## 🚨 Emergency Response Procedures

### Critical Incident Response Checklist

```bash
#!/bin/bash
# Emergency incident response script
# Usage: ./emergency-response.sh <incident-type> <namespace>

INCIDENT_TYPE="$1"
NAMESPACE="${2:-production}"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_DIR="/tmp/incident_logs_${TIMESTAMP}"

emergency_response() {
    echo "🚨 EMERGENCY INCIDENT RESPONSE INITIATED"
    echo "Incident Type: $INCIDENT_TYPE"
    echo "Namespace: $NAMESPACE"
    echo "Timestamp: $TIMESTAMP"
    echo "=========================================="
    
    # Create log directory
    mkdir -p "$LOG_DIR"
    
    case "$INCIDENT_TYPE" in
        "service-down")
            handle_service_outage
            ;;
        "high-latency")
            handle_performance_degradation
            ;;
        "pod-crashloop")
            handle_crashloop_backoff
            ;;
        "resource-exhaustion")
            handle_resource_exhaustion
            ;;
        "security-breach")
            handle_security_incident
            ;;
        "database-failure")
            handle_database_issues
            ;;
        *)
            echo "Unknown incident type: $INCIDENT_TYPE"
            general_diagnostic
            ;;
    esac
    
    echo -e "\n📋 Incident logs saved to: $LOG_DIR"
    echo "📧 Sending incident report to operations team..."
    send_incident_report
}

handle_service_outage() {
    echo -e "\n🔍 DIAGNOSING SERVICE OUTAGE"
    echo "================================"
    
    # Check pod status
    echo "1. Checking pod status..."
    kubectl get pods -n "$NAMESPACE" -o wide > "$LOG_DIR/pods_status.log"
    kubectl describe pods -n "$NAMESPACE" > "$LOG_DIR/pods_describe.log"
    
    # Check service endpoints
    echo "2. Checking service endpoints..."
    kubectl get endpoints -n "$NAMESPACE" > "$LOG_DIR/endpoints.log"
    kubectl get services -n "$NAMESPACE" -o wide > "$LOG_DIR/services.log"
    
    # Check ingress
    echo "3. Checking ingress status..."
    kubectl get ingress -n "$NAMESPACE" > "$LOG_DIR/ingress.log"
    kubectl describe ingress -n "$NAMESPACE" > "$LOG_DIR/ingress_describe.log"
    
    # Check recent events
    echo "4. Checking recent events..."
    kubectl get events -n "$NAMESPACE" --sort-by='.lastTimestamp' > "$LOG_DIR/events.log"
    
    # Get pod logs
    echo "5. Collecting pod logs..."
    for pod in $(kubectl get pods -n "$NAMESPACE" --no-headers -o custom-columns=":metadata.name"); do
        kubectl logs "$pod" -n "$NAMESPACE" --tail=500 > "$LOG_DIR/logs_${pod}.log" 2>&1
        kubectl logs "$pod" -n "$NAMESPACE" --previous --tail=500 > "$LOG_DIR/logs_${pod}_previous.log" 2>&1 || true
    done
    
    # Quick remediation attempts
    echo -e "\n🔧 ATTEMPTING QUICK REMEDIATION"
    echo "===================================="
    
    # Restart failed pods
    failed_pods=$(kubectl get pods -n "$NAMESPACE" --field-selector=status.phase!=Running --no-headers -o custom-columns=":metadata.name" | grep -v "Completed")
    if [ -n "$failed_pods" ]; then
        echo "Restarting failed pods: $failed_pods"
        echo "$failed_pods" | xargs kubectl delete pod -n "$NAMESPACE"
    fi
    
    # Check for deployment issues and rollback if needed
    for deployment in $(kubectl get deployments -n "$NAMESPACE" --no-headers -o custom-columns=":metadata.name"); do
        if ! kubectl rollout status deployment/"$deployment" -n "$NAMESPACE" --timeout=30s; then
            echo "Rolling back deployment: $deployment"
            kubectl rollout undo deployment/"$deployment" -n "$NAMESPACE"
        fi
    done
}

handle_performance_degradation() {
    echo -e "\n📊 DIAGNOSING PERFORMANCE ISSUES"
    echo "=================================="
    
    # Resource utilization
    echo "1. Checking resource utilization..."
    kubectl top nodes > "$LOG_DIR/node_resources.log"
    kubectl top pods -n "$NAMESPACE" --sort-by=cpu > "$LOG_DIR/pod_cpu.log"
    kubectl top pods -n "$NAMESPACE" --sort-by=memory > "$LOG_DIR/pod_memory.log"
    
    # HPA status
    echo "2. Checking autoscaler status..."
    kubectl get hpa -n "$NAMESPACE" > "$LOG_DIR/hpa_status.log"
    kubectl describe hpa -n "$NAMESPACE" > "$LOG_DIR/hpa_describe.log"
    
    # Network policies
    echo "3. Checking network policies..."
    kubectl get networkpolicies -n "$NAMESPACE" > "$LOG_DIR/network_policies.log"
    
    # Service mesh (if using Istio)
    if kubectl get pods -n istio-system &>/dev/null; then
        echo "4. Checking service mesh..."
        kubectl get virtualservices -n "$NAMESPACE" > "$LOG_DIR/virtual_services.log"
        kubectl get destinationrules -n "$NAMESPACE" > "$LOG_DIR/destination_rules.log"
    fi
    
    # Database connections (if applicable)
    echo "5. Checking database connectivity..."
    check_database_connections
}

check_database_connections() {
    # Test database connectivity from pods
    for pod in $(kubectl get pods -n "$NAMESPACE" -l tier=backend --no-headers -o custom-columns=":metadata.name"); do
        echo "Testing DB connection from $pod..."
        kubectl exec "$pod" -n "$NAMESPACE" -- nc -zv postgres 5432 > "$LOG_DIR/db_connectivity_${pod}.log" 2>&1 || true
    done
}

send_incident_report() {
    # Generate incident summary
    cat > "$LOG_DIR/incident_summary.md" << EOF
# Incident Report

**Incident ID**: INC-${TIMESTAMP}
**Type**: ${INCIDENT_TYPE}
**Namespace**: ${NAMESPACE}
**Time**: $(date -u)
**Status**: Investigation in progress

## Quick Diagnostic Results

### Pod Status
\`\`\`
$(kubectl get pods -n "$NAMESPACE" 2>/dev/null | head -10)
\`\`\`

### Recent Events
\`\`\`
$(kubectl get events -n "$NAMESPACE" --sort-by='.lastTimestamp' 2>/dev/null | tail -5)
\`\`\`

### Resource Utilization
\`\`\`
$(kubectl top pods -n "$NAMESPACE" 2>/dev/null | head -10)
\`\`\`

## Actions Taken
- Emergency diagnostic procedures executed
- Logs collected for analysis
- Quick remediation attempts performed

## Next Steps
- Detailed log analysis required
- Root cause investigation needed
- Communication to stakeholders required

---
Generated by: \$(hostname)
Log Location: ${LOG_DIR}
EOF

    # Send to Slack (if webhook configured)
    if [ -n "$SLACK_WEBHOOK_URL" ]; then
        curl -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"🚨 **INCIDENT ALERT**\n**Type**: $INCIDENT_TYPE\n**Namespace**: $NAMESPACE\n**Time**: $(date -u)\n**Logs**: $LOG_DIR\"}" \
            "$SLACK_WEBHOOK_URL"
    fi
}

# Main execution
emergency_response "$@"
```

## 🔧 Common Deployment Issues

### 1. Pod Startup and CrashLoopBackOff

#### Diagnosis Steps

```bash
# Comprehensive pod diagnostic script
#!/bin/bash
diagnose_pod_issues() {
    local pod_name="$1"
    local namespace="$2"
    
    echo "🔍 Diagnosing pod: $pod_name in namespace: $namespace"
    
    # Basic pod information
    echo "=== POD STATUS ==="
    kubectl get pod "$pod_name" -n "$namespace" -o wide
    
    echo -e "\n=== POD DESCRIPTION ==="
    kubectl describe pod "$pod_name" -n "$namespace"
    
    # Container logs
    echo -e "\n=== CURRENT LOGS ==="
    kubectl logs "$pod_name" -n "$namespace" --tail=50
    
    echo -e "\n=== PREVIOUS LOGS (if any) ==="
    kubectl logs "$pod_name" -n "$namespace" --previous --tail=50 2>/dev/null || echo "No previous logs available"
    
    # Resource requests vs limits
    echo -e "\n=== RESOURCE ALLOCATION ==="
    kubectl get pod "$pod_name" -n "$namespace" -o json | jq '.spec.containers[] | {name, resources}'
    
    # Security context
    echo -e "\n=== SECURITY CONTEXT ==="
    kubectl get pod "$pod_name" -n "$namespace" -o json | jq '.spec.securityContext, .spec.containers[].securityContext'
    
    # Volume mounts
    echo -e "\n=== VOLUME MOUNTS ==="
    kubectl get pod "$pod_name" -n "$namespace" -o json | jq '.spec.containers[].volumeMounts'
    
    # Environment variables
    echo -e "\n=== ENVIRONMENT VARIABLES ==="
    kubectl get pod "$pod_name" -n "$namespace" -o json | jq '.spec.containers[].env'
    
    # Events related to this pod
    echo -e "\n=== RELATED EVENTS ==="
    kubectl get events -n "$namespace" --field-selector involvedObject.name="$pod_name" --sort-by='.lastTimestamp'
}

# Common CrashLoopBackOff solutions
fix_crashloop_backoff() {
    local pod_name="$1"
    local namespace="$2"
    
    echo "🔧 Attempting to fix CrashLoopBackOff for $pod_name"
    
    # Check common issues
    
    # 1. Image pull issues
    echo -e "\n1. Checking image pull status..."
    image_status=$(kubectl get pod "$pod_name" -n "$namespace" -o json | jq -r '.status.containerStatuses[0].state.waiting.reason // "Unknown"')
    
    if [[ "$image_status" == "ImagePullBackOff" || "$image_status" == "ErrImagePull" ]]; then
        echo "❌ Image pull issue detected"
        kubectl get pod "$pod_name" -n "$namespace" -o json | jq '.spec.containers[].image'
        echo "💡 Check if image exists and pull secrets are configured"
        return 1
    fi
    
    # 2. Resource constraints
    echo -e "\n2. Checking resource constraints..."
    kubectl describe pod "$pod_name" -n "$namespace" | grep -A 10 "Resource"
    
    # 3. Health check failures
    echo -e "\n3. Checking health check configuration..."
    kubectl get pod "$pod_name" -n "$namespace" -o json | jq '.spec.containers[] | {name, livenessProbe, readinessProbe}'
    
    # 4. Permission issues
    echo -e "\n4. Checking permissions..."
    kubectl get pod "$pod_name" -n "$namespace" -o json | jq '.spec.securityContext'
    
    # 5. Volume mount issues
    echo -e "\n5. Checking volume mounts..."
    kubectl describe pod "$pod_name" -n "$namespace" | grep -A 20 "Volumes:"
    
    # Suggest fixes based on logs
    echo -e "\n💡 SUGGESTED FIXES:"
    logs=$(kubectl logs "$pod_name" -n "$namespace" --tail=100 2>/dev/null)
    
    if echo "$logs" | grep -q "permission denied"; then
        echo "- Fix file permissions or security context"
        echo "- Add runAsUser/runAsGroup to securityContext"
    fi
    
    if echo "$logs" | grep -q "connection refused\|connection timeout"; then
        echo "- Check service endpoints and network policies"
        echo "- Verify database/external service connectivity"
    fi
    
    if echo "$logs" | grep -q "out of memory\|OOMKilled"; then
        echo "- Increase memory limits in deployment"
        echo "- Check for memory leaks in application"
    fi
    
    if echo "$logs" | grep -q "No space left on device"; then
        echo "- Increase ephemeral storage limits"
        echo "- Check for log file accumulation"
    fi
}
```

#### Common CrashLoopBackOff Fixes

| Issue | Symptoms | Solution |
|-------|----------|----------|
| **Image Pull Failure** | `ErrImagePull`, `ImagePullBackOff` | Check image name, registry credentials, network connectivity |
| **Memory Limit Exceeded** | `OOMKilled` in events | Increase memory limits, optimize application memory usage |
| **Health Check Failure** | Liveness probe failures | Adjust probe timing, fix application health endpoint |
| **Permission Denied** | "Permission denied" in logs | Fix securityContext, file permissions, or volumes |
| **Missing Dependencies** | Service connection errors | Check database connectivity, external service endpoints |
| **Configuration Errors** | Application startup errors | Validate ConfigMaps, Secrets, environment variables |

### 2. Service Discovery and Networking Issues

#### DNS Resolution Problems

```bash
# DNS troubleshooting toolkit
#!/bin/bash
debug_dns_issues() {
    local namespace="$1"
    local service_name="$2"
    
    echo "🔍 Debugging DNS issues for service: $service_name in namespace: $namespace"
    
    # Check CoreDNS status
    echo "=== COREDNS STATUS ==="
    kubectl get pods -n kube-system -l k8s-app=kube-dns
    kubectl logs -n kube-system -l k8s-app=kube-dns --tail=20
    
    # Test DNS resolution from a test pod
    echo -e "\n=== DNS RESOLUTION TEST ==="
    kubectl run dns-test --image=busybox --rm -it --restart=Never -- nslookup "$service_name.$namespace.svc.cluster.local"
    
    # Check service endpoints
    echo -e "\n=== SERVICE ENDPOINTS ==="
    kubectl get svc "$service_name" -n "$namespace" -o wide
    kubectl get endpoints "$service_name" -n "$namespace"
    
    # Test internal connectivity
    echo -e "\n=== CONNECTIVITY TEST ==="
    # Get a running pod to test from
    test_pod=$(kubectl get pods -n "$namespace" --field-selector=status.phase=Running --no-headers -o custom-columns=":metadata.name" | head -1)
    
    if [ -n "$test_pod" ]; then
        echo "Testing from pod: $test_pod"
        kubectl exec "$test_pod" -n "$namespace" -- nc -zv "$service_name" 80 2>&1 || echo "Connection failed"
        kubectl exec "$test_pod" -n "$namespace" -- curl -m 5 "http://$service_name/health" 2>&1 || echo "HTTP check failed"
    fi
    
    # Check network policies
    echo -e "\n=== NETWORK POLICIES ==="
    kubectl get networkpolicies -n "$namespace"
    kubectl describe networkpolicies -n "$namespace"
}

# Service mesh debugging (Istio)
debug_service_mesh() {
    local namespace="$1"
    local service_name="$2"
    
    echo "🕸️  Debugging service mesh issues"
    
    # Check Istio injection
    echo "=== ISTIO INJECTION STATUS ==="
    kubectl get namespace "$namespace" -o json | jq '.metadata.labels'
    
    # Check sidecar status
    echo -e "\n=== SIDECAR STATUS ==="
    kubectl get pods -n "$namespace" -o json | jq '.items[] | {name: .metadata.name, containers: [.spec.containers[].name]}'
    
    # Check virtual services
    echo -e "\n=== VIRTUAL SERVICES ==="
    kubectl get virtualservices -n "$namespace"
    kubectl describe virtualservices -n "$namespace"
    
    # Check destination rules
    echo -e "\n=== DESTINATION RULES ==="
    kubectl get destinationrules -n "$namespace"
    kubectl describe destinationrules -n "$namespace"
    
    # Check Envoy configuration
    echo -e "\n=== ENVOY CONFIG DUMP ==="
    test_pod=$(kubectl get pods -n "$namespace" --field-selector=status.phase=Running --no-headers -o custom-columns=":metadata.name" | head -1)
    if [ -n "$test_pod" ]; then
        kubectl exec "$test_pod" -n "$namespace" -c istio-proxy -- curl -s localhost:15000/config_dump | jq '.configs[] | select(.["@type"] | contains("Cluster")) | .dynamic_active_clusters[] | .cluster.name' | head -10
    fi
}
```

### 3. Resource and Performance Issues

#### Memory and CPU Troubleshooting

```javascript
// Node.js memory debugging utilities for EdTech applications
class MemoryDebugger {
  constructor() {
    this.memorySnapshots = [];
    this.performanceMetrics = new Map();
  }
  
  // Monitor memory usage patterns
  startMemoryMonitoring() {
    setInterval(() => {
      const memUsage = process.memoryUsage();
      const timestamp = Date.now();
      
      this.memorySnapshots.push({
        timestamp,
        ...memUsage,
        heapUsedMB: Math.round(memUsage.heapUsed / 1024 / 1024),
        heapTotalMB: Math.round(memUsage.heapTotal / 1024 / 1024),
        externalMB: Math.round(memUsage.external / 1024 / 1024)
      });
      
      // Keep only last hour of data
      const oneHourAgo = timestamp - (60 * 60 * 1000);
      this.memorySnapshots = this.memorySnapshots.filter(s => s.timestamp > oneHourAgo);
      
      // Detect memory leaks
      this.detectMemoryLeak();
      
    }, 30000); // Every 30 seconds
  }
  
  detectMemoryLeak() {
    if (this.memorySnapshots.length < 10) return;
    
    const recent = this.memorySnapshots.slice(-10);
    const trend = this.calculateMemoryTrend(recent);
    
    // Alert if consistent memory growth
    if (trend.slope > 1 && trend.correlation > 0.7) {
      console.warn('🚨 Potential memory leak detected:', {
        growthRate: `${trend.slope.toFixed(2)} MB/minute`,
        correlation: trend.correlation.toFixed(3),
        currentUsage: `${recent[recent.length - 1].heapUsedMB} MB`
      });
      
      // Trigger garbage collection
      if (global.gc) {
        console.log('🗑️  Triggering garbage collection...');
        global.gc();
      }
      
      // Generate heap dump for analysis
      this.generateHeapDump();
    }
  }
  
  calculateMemoryTrend(snapshots) {
    const n = snapshots.length;
    const sumX = snapshots.reduce((sum, _, i) => sum + i, 0);
    const sumY = snapshots.reduce((sum, s) => sum + s.heapUsedMB, 0);
    const sumXY = snapshots.reduce((sum, s, i) => sum + (i * s.heapUsedMB), 0);
    const sumXX = snapshots.reduce((sum, _, i) => sum + (i * i), 0);
    
    const slope = (n * sumXY - sumX * sumY) / (n * sumXX - sumX * sumX);
    const correlation = this.calculateCorrelation(snapshots);
    
    return { slope, correlation };
  }
  
  generateHeapDump() {
    const heapdump = require('heapdump');
    const filename = `/tmp/heapdump-${Date.now()}.heapsnapshot`;
    
    heapdump.writeSnapshot(filename, (err, filename) => {
      if (err) {
        console.error('Failed to generate heap dump:', err);
      } else {
        console.log(`💾 Heap dump saved: ${filename}`);
      }
    });
  }
  
  // API endpoint for memory diagnostics
  getMemoryDiagnostics() {
    const current = process.memoryUsage();
    const trend = this.memorySnapshots.length > 1 ? 
      this.calculateMemoryTrend(this.memorySnapshots.slice(-10)) : null;
    
    return {
      current: {
        heapUsed: Math.round(current.heapUsed / 1024 / 1024),
        heapTotal: Math.round(current.heapTotal / 1024 / 1024),
        external: Math.round(current.external / 1024 / 1024),
        rss: Math.round(current.rss / 1024 / 1024)
      },
      trend: trend ? {
        slope: trend.slope.toFixed(2),
        correlation: trend.correlation.toFixed(3),
        status: trend.slope > 1 && trend.correlation > 0.7 ? 'WARNING' : 'OK'
      } : null,
      snapshots: this.memorySnapshots.length,
      recommendations: this.generateRecommendations(current, trend)
    };
  }
  
  generateRecommendations(current, trend) {
    const recommendations = [];
    
    const heapUsedMB = Math.round(current.heapUsed / 1024 / 1024);
    const heapTotalMB = Math.round(current.heapTotal / 1024 / 1024);
    
    // High memory usage
    if (heapUsedMB > 400) {
      recommendations.push('Consider increasing memory limits or optimizing memory usage');
    }
    
    // Memory fragmentation
    if ((heapTotalMB - heapUsedMB) > 100) {
      recommendations.push('High memory fragmentation detected, consider restarting the service');
    }
    
    // Growing trend
    if (trend && trend.slope > 1) {
      recommendations.push('Memory usage is increasing, investigate for potential memory leaks');
    }
    
    // High external memory
    const externalMB = Math.round(current.external / 1024 / 1024);
    if (externalMB > 50) {
      recommendations.push('High external memory usage, check Buffer usage and external libraries');
    }
    
    return recommendations;
  }
}

// Usage in Express application
const memoryDebugger = new MemoryDebugger();
memoryDebugger.startMemoryMonitoring();

// Debug endpoint
app.get('/debug/memory', (req, res) => {
  res.json(memoryDebugger.getMemoryDiagnostics());
});

// Manual garbage collection endpoint
app.post('/debug/gc', (req, res) => {
  if (global.gc) {
    const before = process.memoryUsage();
    global.gc();
    const after = process.memoryUsage();
    
    res.json({
      before: Math.round(before.heapUsed / 1024 / 1024),
      after: Math.round(after.heapUsed / 1024 / 1024),
      freed: Math.round((before.heapUsed - after.heapUsed) / 1024 / 1024)
    });
  } else {
    res.status(400).json({ error: 'Garbage collection not exposed. Start with --expose-gc flag.' });
  }
});
```

### 4. Database Connectivity Issues

#### Database Connection Debugging

```javascript
// Database connection pool debugging
class DatabaseDebugger {
  constructor(dbPool) {
    this.pool = dbPool;
    this.connectionHistory = [];
    this.errorCounts = new Map();
  }
  
  async diagnoseConnectionIssues() {
    console.log('🔍 Diagnosing database connection issues...');
    
    // Check pool status
    const poolInfo = this.getPoolInfo();
    console.log('📊 Connection Pool Status:', poolInfo);
    
    // Test basic connectivity
    const connectivityTest = await this.testConnectivity();
    console.log('🔌 Connectivity Test:', connectivityTest);
    
    // Analyze connection patterns
    const analysis = this.analyzeConnectionPatterns();
    console.log('📈 Connection Analysis:', analysis);
    
    // Check for slow queries
    const slowQueries = await this.identifySlowQueries();
    console.log('🐌 Slow Queries:', slowQueries);
    
    return {
      poolStatus: poolInfo,
      connectivity: connectivityTest,
      analysis: analysis,
      slowQueries: slowQueries,
      recommendations: this.generateDatabaseRecommendations(poolInfo, analysis)
    };
  }
  
  getPoolInfo() {
    return {
      total: this.pool.totalCount,
      idle: this.pool.idleCount,
      waiting: this.pool.waitingCount,
      acquired: this.pool.totalCount - this.pool.idleCount,
      utilization: ((this.pool.totalCount - this.pool.idleCount) / this.pool.totalCount * 100).toFixed(1) + '%',
      config: {
        min: this.pool.min,
        max: this.pool.max,
        acquireTimeoutMillis: this.pool.acquireTimeoutMillis,
        idleTimeoutMillis: this.pool.idleTimeoutMillis
      }
    };
  }
  
  async testConnectivity() {
    const tests = {
      basicConnection: false,
      queryExecution: false,
      transactionSupport: false,
      responseTime: null
    };
    
    try {
      const startTime = Date.now();
      
      // Test basic connection
      const client = await this.pool.connect();
      tests.basicConnection = true;
      
      // Test query execution
      const result = await client.query('SELECT 1 as test');
      tests.queryExecution = result.rows[0].test === 1;
      
      // Test transaction support
      await client.query('BEGIN');
      await client.query('SELECT 1');
      await client.query('COMMIT');
      tests.transactionSupport = true;
      
      tests.responseTime = Date.now() - startTime;
      
      client.release();
      
    } catch (error) {
      console.error('Database connectivity test failed:', error.message);
      tests.error = error.message;
    }
    
    return tests;
  }
  
  async identifySlowQueries() {
    try {
      // This would integrate with your specific database monitoring
      const client = await this.pool.connect();
      
      // PostgreSQL slow query identification
      const slowQueries = await client.query(`
        SELECT 
          query,
          calls,
          total_time,
          mean_time,
          rows
        FROM pg_stat_statements 
        WHERE mean_time > 1000  -- Queries taking more than 1 second
        ORDER BY mean_time DESC 
        LIMIT 10
      `);
      
      client.release();
      
      return slowQueries.rows.map(row => ({
        query: row.query.substring(0, 100) + '...',
        calls: row.calls,
        totalTime: Math.round(row.total_time),
        avgTime: Math.round(row.mean_time),
        rows: row.rows
      }));
      
    } catch (error) {
      console.warn('Could not retrieve slow query stats:', error.message);
      return [];
    }
  }
  
  generateDatabaseRecommendations(poolInfo, analysis) {
    const recommendations = [];
    
    // Pool utilization recommendations
    const utilization = parseFloat(poolInfo.utilization);
    if (utilization > 90) {
      recommendations.push('High connection pool utilization. Consider increasing pool size.');
    } else if (utilization < 20) {
      recommendations.push('Low connection pool utilization. Consider reducing pool size to save resources.');
    }
    
    // Waiting connections
    if (poolInfo.waiting > 0) {
      recommendations.push('Connections are waiting for available pool slots. Increase pool size or optimize query performance.');
    }
    
    // Connection patterns
    if (analysis.avgConnectionTime > 5000) {
      recommendations.push('Long connection acquisition times detected. Check network latency and pool configuration.');
    }
    
    // Error patterns
    if (analysis.errorRate > 0.05) {
      recommendations.push('High database error rate detected. Check connection stability and query optimization.');
    }
    
    return recommendations;
  }
}

// Integration with health checks
app.get('/health/database', async (req, res) => {
  try {
    const dbDebugger = new DatabaseDebugger(dbPool);
    const diagnostics = await dbDebugger.diagnoseConnectionIssues();
    
    const isHealthy = diagnostics.connectivity.basicConnection && 
                     diagnostics.connectivity.queryExecution &&
                     diagnostics.connectivity.responseTime < 5000;
    
    res.status(isHealthy ? 200 : 503).json({
      status: isHealthy ? 'healthy' : 'unhealthy',
      diagnostics: diagnostics
    });
    
  } catch (error) {
    res.status(503).json({
      status: 'unhealthy',
      error: error.message
    });
  }
});
```

## 🔍 Performance Debugging

### Application Performance Monitoring

```javascript
// APM integration for EdTech applications
class EdTechAPM {
  constructor() {
    this.metrics = new Map();
    this.traces = [];
    this.alerts = [];
  }
  
  // Request tracing middleware
  createTracingMiddleware() {
    return (req, res, next) => {
      const traceId = req.headers['x-trace-id'] || this.generateTraceId();
      const startTime = Date.now();
      
      req.trace = {
        id: traceId,
        startTime: startTime,
        spans: []
      };
      
      // Add trace ID to response headers
      res.setHeader('X-Trace-ID', traceId);
      
      // Override res.json to capture response time
      const originalJson = res.json;
      res.json = function(data) {
        const endTime = Date.now();
        const duration = endTime - startTime;
        
        // Record metrics
        this.recordRequestMetrics(req, res, duration);
        
        // Store trace
        this.storeTrace({
          id: traceId,
          method: req.method,
          url: req.url,
          statusCode: res.statusCode,
          duration: duration,
          userAgent: req.headers['user-agent'],
          userId: req.user?.id,
          spans: req.trace.spans
        });
        
        return originalJson.call(this, data);
      }.bind(this);
      
      next();
    };
  }
  
  // Database query tracing
  traceQuery(queryText, params = []) {
    return async (queryFunction) => {
      const startTime = Date.now();
      const spanId = this.generateSpanId();
      
      try {
        const result = await queryFunction();
        const duration = Date.now() - startTime;
        
        // Record successful query
        this.recordQueryMetrics(queryText, duration, true);
        
        return result;
        
      } catch (error) {
        const duration = Date.now() - startTime;
        
        // Record failed query
        this.recordQueryMetrics(queryText, duration, false, error);
        
        throw error;
      }
    };
  }
  
  recordRequestMetrics(req, res, duration) {
    const key = `${req.method}:${req.route?.path || req.url}`;
    
    if (!this.metrics.has(key)) {
      this.metrics.set(key, {
        count: 0,
        totalTime: 0,
        errors: 0,
        p95: [],
        p99: []
      });
    }
    
    const metric = this.metrics.get(key);
    metric.count++;
    metric.totalTime += duration;
    
    if (res.statusCode >= 400) {
      metric.errors++;
    }
    
    // Store for percentile calculation
    metric.p95.push(duration);
    metric.p99.push(duration);
    
    // Keep only last 1000 samples for percentiles
    if (metric.p95.length > 1000) {
      metric.p95.shift();
      metric.p99.shift();
    }
    
    // Alert on performance degradation
    if (duration > 5000) { // 5 second threshold
      this.createAlert({
        type: 'SLOW_REQUEST',
        endpoint: key,
        duration: duration,
        threshold: 5000,
        traceId: req.trace?.id
      });
    }
    
    // Alert on high error rate
    const errorRate = metric.errors / metric.count;
    if (errorRate > 0.1 && metric.count > 10) { // 10% error rate
      this.createAlert({
        type: 'HIGH_ERROR_RATE',
        endpoint: key,
        errorRate: errorRate,
        threshold: 0.1
      });
    }
  }
  
  // Generate performance report
  generatePerformanceReport() {
    const report = {
      timestamp: new Date().toISOString(),
      endpoints: [],
      topSlowEndpoints: [],
      topErrorEndpoints: [],
      systemMetrics: this.getSystemMetrics()
    };
    
    for (const [endpoint, metrics] of this.metrics.entries()) {
      const avgTime = metrics.totalTime / metrics.count;
      const errorRate = metrics.errors / metrics.count;
      const p95 = this.calculatePercentile(metrics.p95, 95);
      const p99 = this.calculatePercentile(metrics.p99, 99);
      
      const endpointReport = {
        endpoint,
        requestCount: metrics.count,
        avgResponseTime: Math.round(avgTime),
        p95ResponseTime: Math.round(p95),
        p99ResponseTime: Math.round(p99),
        errorRate: (errorRate * 100).toFixed(2) + '%',
        errorsCount: metrics.errors
      };
      
      report.endpoints.push(endpointReport);
      
      // Identify problematic endpoints
      if (avgTime > 2000) {
        report.topSlowEndpoints.push(endpointReport);
      }
      
      if (errorRate > 0.05) {
        report.topErrorEndpoints.push(endpointReport);
      }
    }
    
    // Sort by performance issues
    report.topSlowEndpoints.sort((a, b) => b.avgResponseTime - a.avgResponseTime);
    report.topErrorEndpoints.sort((a, b) => parseFloat(b.errorRate) - parseFloat(a.errorRate));
    
    return report;
  }
  
  calculatePercentile(values, percentile) {
    if (values.length === 0) return 0;
    
    const sorted = [...values].sort((a, b) => a - b);
    const index = Math.ceil((percentile / 100) * sorted.length) - 1;
    return sorted[index];
  }
}

// Usage in Express application
const apm = new EdTechAPM();

// Apply tracing middleware
app.use(apm.createTracingMiddleware());

// Performance monitoring endpoint
app.get('/debug/performance', (req, res) => {
  res.json(apm.generatePerformanceReport());
});

// Trace specific database operations
app.get('/api/students/:id/exams', async (req, res) => {
  try {
    // Trace the database query
    const exams = await apm.traceQuery(
      'SELECT * FROM exams WHERE student_id = $1',
      [req.params.id]
    )(async () => {
      return await db.query('SELECT * FROM exams WHERE student_id = $1', [req.params.id]);
    });
    
    res.json(exams.rows);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});
```

## 🚨 Security Incident Response

### Security Troubleshooting Procedures

```bash
#!/bin/bash
# Security incident response procedures

security_incident_response() {
    local incident_type="$1"
    local affected_resource="$2"
    local namespace="${3:-production}"
    
    echo "🚨 SECURITY INCIDENT RESPONSE"
    echo "Type: $incident_type"
    echo "Resource: $affected_resource"
    echo "Namespace: $namespace"
    echo "============================="
    
    case "$incident_type" in
        "unauthorized-access")
            handle_unauthorized_access "$affected_resource" "$namespace"
            ;;
        "privilege-escalation")
            handle_privilege_escalation "$affected_resource" "$namespace"
            ;;
        "data-breach")
            handle_data_breach "$affected_resource" "$namespace"
            ;;
        "malware-detected")
            handle_malware_detection "$affected_resource" "$namespace"
            ;;
        *)
            echo "Unknown incident type: $incident_type"
            general_security_response "$affected_resource" "$namespace"
            ;;
    esac
}

handle_unauthorized_access() {
    local resource="$1"
    local namespace="$2"
    
    echo "🔒 Handling unauthorized access incident"
    
    # Immediate containment
    echo "1. Implementing immediate containment..."
    
    # Isolate affected pods
    kubectl patch deployment "$resource" -n "$namespace" -p '{"spec":{"template":{"metadata":{"labels":{"security.status":"quarantined"}}}}}'
    
    # Apply restrictive network policy
    cat << EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: security-quarantine-${resource}
  namespace: ${namespace}
spec:
  podSelector:
    matchLabels:
      security.status: quarantined
  policyTypes:
  - Ingress
  - Egress
  # No rules = deny all traffic
EOF
    
    # Collect evidence
    echo "2. Collecting evidence..."
    
    # Get current pod information
    kubectl get pods -n "$namespace" -l app="$resource" -o wide > "/tmp/incident_pods_${resource}.log"
    kubectl describe pods -n "$namespace" -l app="$resource" > "/tmp/incident_describe_${resource}.log"
    
    # Collect logs
    for pod in $(kubectl get pods -n "$namespace" -l app="$resource" --no-headers -o custom-columns=":metadata.name"); do
        kubectl logs "$pod" -n "$namespace" --tail=1000 > "/tmp/incident_logs_${pod}.log"
        kubectl logs "$pod" -n "$namespace" --previous --tail=1000 > "/tmp/incident_logs_${pod}_previous.log" 2>/dev/null || true
    done
    
    # Check RBAC permissions
    echo "3. Analyzing RBAC permissions..."
    kubectl get rolebindings,clusterrolebindings -n "$namespace" -o wide > "/tmp/incident_rbac_${resource}.log"
    
    # Check recent events
    kubectl get events -n "$namespace" --sort-by='.lastTimestamp' > "/tmp/incident_events_${resource}.log"
    
    # Revoke potentially compromised credentials
    echo "4. Revoking credentials..."
    
    # Rotate service account token
    kubectl delete secret -n "$namespace" -l kubernetes.io/service-account.name="${resource}-sa" 2>/dev/null || true
    
    # Update JWT secrets if applicable
    kubectl delete secret jwt-secret -n "$namespace" 2>/dev/null || true
    kubectl create secret generic jwt-secret -n "$namespace" \
        --from-literal=key="$(openssl rand -base64 32)" \
        --from-literal=refresh-key="$(openssl rand -base64 32)"
    
    echo "✅ Immediate response completed. Manual investigation required."
}

handle_data_breach() {
    local resource="$1"
    local namespace="$2"
    
    echo "🚨 CRITICAL: Data breach incident response"
    
    # FERPA/GDPR compliance procedures
    echo "1. Initiating compliance procedures..."
    
    # Immediate isolation
    kubectl scale deployment "$resource" --replicas=0 -n "$namespace"
    
    # Block all external traffic
    cat << EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: data-breach-lockdown-${resource}
  namespace: ${namespace}
spec:
  podSelector:
    matchLabels:
      app: ${resource}
  policyTypes:
  - Ingress
  - Egress
  # Complete isolation
EOF
    
    # Evidence collection
    echo "2. Preserving evidence..."
    
    # Create forensic snapshots
    timestamp=$(date +"%Y%m%d_%H%M%S")
    evidence_dir="/tmp/data_breach_evidence_${timestamp}"
    mkdir -p "$evidence_dir"
    
    # Collect all relevant information
    kubectl get all -n "$namespace" -o yaml > "$evidence_dir/kubernetes_state.yaml"
    kubectl get secrets -n "$namespace" -o yaml > "$evidence_dir/secrets.yaml"
    kubectl get configmaps -n "$namespace" -o yaml > "$evidence_dir/configmaps.yaml"
    kubectl get networkpolicies -n "$namespace" -o yaml > "$evidence_dir/network_policies.yaml"
    
    # Database snapshot (if accessible)
    echo "3. Creating database snapshot..."
    kubectl exec -n "$namespace" $(kubectl get pods -n "$namespace" -l app=postgres --no-headers -o custom-columns=":metadata.name" | head -1) -- pg_dump edtech_production > "$evidence_dir/database_snapshot.sql" 2>/dev/null || echo "Database snapshot failed"
    
    # Notification requirements
    echo "4. Preparing breach notifications..."
    
    cat > "$evidence_dir/breach_notification_template.md" << EOF
# Data Breach Incident Report

**Incident ID**: BREACH-${timestamp}
**Discovery Time**: $(date -u)
**Affected System**: ${resource} in ${namespace}
**Status**: Under Investigation

## Immediate Actions Taken
- Affected system isolated and shut down
- Network access completely blocked
- Evidence collection initiated
- Security team notified

## Compliance Requirements
- [ ] Legal team notification (within 1 hour)
- [ ] Regulatory notification preparation (within 24 hours for FERPA)
- [ ] User notification preparation (within 72 hours for GDPR)
- [ ] Forensic analysis initiation

## Evidence Location
${evidence_dir}

## Next Steps
1. Forensic analysis by security team
2. Impact assessment
3. Regulatory notifications
4. User communications
5. System hardening and recovery planning
EOF
    
    echo "🚨 CRITICAL: Data breach response initiated"
    echo "Evidence stored in: $evidence_dir"
    echo "Manual review and legal consultation required immediately"
    
    # Alert security team immediately
    if [ -n "$SECURITY_ALERT_WEBHOOK" ]; then
        curl -X POST "$SECURITY_ALERT_WEBHOOK" \
            -H "Content-Type: application/json" \
            -d "{\"text\":\"🚨 CRITICAL DATA BREACH: $resource in $namespace. Evidence: $evidence_dir\"}"
    fi
}

# Main security response dispatcher
if [ $# -lt 2 ]; then
    echo "Usage: $0 <incident-type> <resource> [namespace]"
    echo "Incident types: unauthorized-access, privilege-escalation, data-breach, malware-detected"
    exit 1
fi

security_incident_response "$1" "$2" "$3"
```

## 📚 Common Kubectl Commands for Troubleshooting

### Essential Diagnostic Commands

```bash
# Pod diagnostics
kubectl get pods -o wide --sort-by='.status.startTime'
kubectl describe pod <pod-name>
kubectl logs <pod-name> --tail=100 --follow
kubectl logs <pod-name> --previous
kubectl exec -it <pod-name> -- /bin/sh

# Service and networking
kubectl get svc,endpoints
kubectl describe svc <service-name>
kubectl get ingress -o wide
kubectl get networkpolicies

# Resource usage
kubectl top nodes
kubectl top pods --sort-by=cpu
kubectl top pods --sort-by=memory

# Events and troubleshooting
kubectl get events --sort-by='.lastTimestamp'
kubectl get events --field-selector type=Warning
kubectl get events --field-selector involvedObject.name=<resource-name>

# Configuration debugging
kubectl get configmaps
kubectl describe configmap <configmap-name>
kubectl get secrets
kubectl describe secret <secret-name>

# Deployment and rollout issues
kubectl rollout status deployment/<deployment-name>
kubectl rollout history deployment/<deployment-name>
kubectl rollout undo deployment/<deployment-name>

# Resource quotas and limits
kubectl describe limits
kubectl describe quota
kubectl get limitranges

# RBAC debugging
kubectl auth can-i <verb> <resource> --as=<user>
kubectl get rolebindings,clusterrolebindings -o wide
kubectl describe rolebinding <binding-name>
```

## 🔗 Next Steps

Complete your troubleshooting toolkit with:
- [Template Examples](./template-examples.md) - Production-ready manifests with debugging features
- [Security Considerations](./security-considerations.md) - Security-specific troubleshooting procedures

---

### 🔗 Navigation
- [← Back to Main Research](./README.md)
- [← Previous: Security Considerations](./security-considerations.md)
- [Next: Template Examples →](./template-examples.md)