# Grafana Dashboard Guide

> Complete guide for creating custom dashboards, visualizations, and alerting in Grafana with focus on EdTech platform monitoring needs.

## 🎨 Dashboard Design Philosophy

### EdTech Platform Monitoring Hierarchy

```
📊 Executive Level (C-Suite, Investors)
   ├── Business KPIs: Revenue, User Growth, Course Completion
   ├── Service Availability: 99.9% Uptime SLA
   └── Customer Satisfaction: Response Times, Error Rates

🔧 Operational Level (Engineering Teams)
   ├── System Health: Infrastructure, Database, APIs
   ├── Performance Monitoring: Response Times, Throughput
   └── Alert Management: Active Incidents, Escalations

🔍 Debugging Level (DevOps, SREs)
   ├── Detailed Metrics: Per-service Performance
   ├── Infrastructure Deep Dive: CPU, Memory, Disk
   └── Troubleshooting: Error Analysis, Log Correlation
```

## 🚀 Initial Setup and Configuration

### Data Source Configuration

Create automatic Prometheus data source setup:

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
      queryTimeout: 60s
      defaultEditor: code
    secureJsonData:
      # Add basic auth if needed
      basicAuthPassword: 'your-password'
```

### Dashboard Provisioning

```yaml
# grafana/provisioning/dashboards/default.yml
apiVersion: 1

providers:
  - name: 'edtech-dashboards'
    orgId: 1
    folder: 'EdTech Platform'
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /var/lib/grafana/dashboards

  - name: 'infrastructure-dashboards'
    orgId: 1
    folder: 'Infrastructure'
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /var/lib/grafana/dashboards/infrastructure
```

## 📊 Executive Dashboard

### Business KPIs Dashboard

```json
{
  "dashboard": {
    "id": null,
    "title": "EdTech Platform - Executive Overview",
    "tags": ["edtech", "business", "executive"],
    "timezone": "browser",
    "refresh": "5m",
    "time": {
      "from": "now-24h",
      "to": "now"
    },
    "templating": {
      "list": [
        {
          "name": "environment",
          "type": "query",
          "query": "label_values(up, environment)",
          "current": {
            "value": "production",
            "text": "production"
          }
        }
      ]
    },
    "panels": [
      {
        "id": 1,
        "title": "Platform Availability",
        "type": "stat",
        "gridPos": {"h": 8, "w": 6, "x": 0, "y": 0},
        "targets": [
          {
            "expr": "avg(up{job=\"edtech-application\", environment=\"$environment\"}) * 100",
            "legendFormat": "Uptime %"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "percent",
            "min": 95,
            "max": 100,
            "color": {
              "mode": "thresholds"
            },
            "thresholds": {
              "steps": [
                {"color": "red", "value": 0},
                {"color": "yellow", "value": 99},
                {"color": "green", "value": 99.9}
              ]
            }
          }
        },
        "options": {
          "colorMode": "background",
          "graphMode": "area",
          "justifyMode": "center",
          "orientation": "horizontal"
        }
      },
      {
        "id": 2,
        "title": "Active Users (24h)",
        "type": "stat",
        "gridPos": {"h": 8, "w": 6, "x": 6, "y": 0},
        "targets": [
          {
            "expr": "sum(edtech:active_users:total{environment=\"$environment\"})",
            "legendFormat": "Active Users"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "short",
            "color": {
              "mode": "palette-classic"
            }
          }
        }
      },
      {
        "id": 3,
        "title": "Average Response Time",
        "type": "stat",
        "gridPos": {"h": 8, "w": 6, "x": 12, "y": 0},
        "targets": [
          {
            "expr": "job:http_request_duration:p95{job=\"edtech-application\", environment=\"$environment\"}",
            "legendFormat": "95th Percentile"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "s",
            "color": {
              "mode": "thresholds"
            },
            "thresholds": {
              "steps": [
                {"color": "green", "value": 0},
                {"color": "yellow", "value": 1},
                {"color": "red", "value": 3}
              ]
            }
          }
        }
      },
      {
        "id": 4,
        "title": "Error Rate",
        "type": "stat",
        "gridPos": {"h": 8, "w": 6, "x": 18, "y": 0},
        "targets": [
          {
            "expr": "job:http_error_percentage:rate5m{job=\"edtech-application\", environment=\"$environment\"}",
            "legendFormat": "Error Rate %"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "percent",
            "max": 5,
            "color": {
              "mode": "thresholds"
            },
            "thresholds": {
              "steps": [
                {"color": "green", "value": 0},
                {"color": "yellow", "value": 1},
                {"color": "red", "value": 3}
              ]
            }
          }
        }
      },
      {
        "id": 5,
        "title": "Course Completions (24h)",
        "type": "timeseries",
        "gridPos": {"h": 9, "w": 12, "x": 0, "y": 8},
        "targets": [
          {
            "expr": "increase(course_completions_total{environment=\"$environment\"}[1h])",
            "legendFormat": "{{course_type}} Completions"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "short",
            "custom": {
              "drawStyle": "line",
              "lineInterpolation": "smooth",
              "fillOpacity": 10,
              "pointSize": 5
            }
          }
        }
      },
      {
        "id": 6,
        "title": "Revenue Metrics (24h)",
        "type": "timeseries",
        "gridPos": {"h": 9, "w": 12, "x": 12, "y": 8},
        "targets": [
          {
            "expr": "increase(payment_transactions_total{environment=\"$environment\", type=\"successful\"}[1h]) * 50",
            "legendFormat": "Revenue (USD)"
          },
          {
            "expr": "increase(user_registrations_total{environment=\"$environment\"}[1h])",
            "legendFormat": "New Registrations"
          }
        ]
      }
    ]
  }
}
```

## 🔧 Operational Dashboard

### Application Performance Monitoring

```json
{
  "dashboard": {
    "title": "EdTech Platform - Application Performance",
    "tags": ["edtech", "application", "performance"],
    "templating": {
      "list": [
        {
          "name": "service",
          "type": "query",
          "query": "label_values(http_requests_total, job)",
          "multi": true,
          "includeAll": true
        },
        {
          "name": "instance",
          "type": "query",
          "query": "label_values(http_requests_total{job=~\"$service\"}, instance)",
          "multi": true,
          "includeAll": true
        }
      ]
    },
    "panels": [
      {
        "title": "Request Rate",
        "type": "timeseries",
        "targets": [
          {
            "expr": "sum(rate(http_requests_total{job=~\"$service\", instance=~\"$instance\"}[5m])) by (job)",
            "legendFormat": "{{job}} - Requests/sec"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "reqps",
            "custom": {
              "drawStyle": "line",
              "lineWidth": 2,
              "fillOpacity": 10
            }
          }
        }
      },
      {
        "title": "Response Time Distribution",
        "type": "heatmap",
        "targets": [
          {
            "expr": "sum(increase(http_request_duration_seconds_bucket{job=~\"$service\", instance=~\"$instance\"}[5m])) by (le)",
            "format": "heatmap",
            "legendFormat": "{{le}}"
          }
        ],
        "options": {
          "calculate": true,
          "yAxis": {
            "unit": "s",
            "min": "0.001",
            "max": "10"
          },
          "color": {
            "mode": "spectrum",
            "scheme": "Spectral",
            "exponent": 0.5
          }
        }
      },
      {
        "title": "Error Rate by Status Code",
        "type": "timeseries",
        "targets": [
          {
            "expr": "sum(rate(http_requests_total{job=~\"$service\", instance=~\"$instance\", status=~\"4..|5..\"}[5m])) by (status)",
            "legendFormat": "HTTP {{status}}"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "reqps",
            "color": {
              "mode": "palette-classic"
            }
          }
        }
      },
      {
        "title": "Database Performance",
        "type": "timeseries",
        "targets": [
          {
            "expr": "histogram_quantile(0.95, sum(rate(db_query_duration_seconds_bucket{job=~\"$service\"}[5m])) by (le, query_type))",
            "legendFormat": "{{query_type}} - 95th percentile"
          },
          {
            "expr": "histogram_quantile(0.50, sum(rate(db_query_duration_seconds_bucket{job=~\"$service\"}[5m])) by (le, query_type))",
            "legendFormat": "{{query_type}} - 50th percentile"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "s",
            "custom": {
              "lineWidth": 2
            }
          }
        }
      }
    ]
  }
}
```

## 🏗️ Infrastructure Dashboard

### System Health Monitoring

```json
{
  "dashboard": {
    "title": "Infrastructure Health - System Metrics",
    "tags": ["infrastructure", "system", "health"],
    "templating": {
      "list": [
        {
          "name": "instance",
          "type": "query",
          "query": "label_values(node_uname_info, instance)",
          "multi": true,
          "includeAll": true
        }
      ]
    },
    "panels": [
      {
        "title": "CPU Usage",
        "type": "timeseries",
        "targets": [
          {
            "expr": "100 - (avg by(instance) (irate(node_cpu_seconds_total{mode=\"idle\", instance=~\"$instance\"}[5m])) * 100)",
            "legendFormat": "{{instance}} - CPU Usage %"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "percent",
            "max": 100,
            "custom": {
              "fillOpacity": 20
            }
          }
        }
      },
      {
        "title": "Memory Usage",
        "type": "timeseries",
        "targets": [
          {
            "expr": "(1 - (node_memory_MemAvailable_bytes{instance=~\"$instance\"} / node_memory_MemTotal_bytes{instance=~\"$instance\"})) * 100",
            "legendFormat": "{{instance}} - Memory Usage %"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "percent",
            "max": 100
          }
        }
      },
      {
        "title": "Disk Usage",
        "type": "table",
        "targets": [
          {
            "expr": "100 - ((node_filesystem_avail_bytes{instance=~\"$instance\", mountpoint!~\"/boot|/var/lib.*\"} / node_filesystem_size_bytes{instance=~\"$instance\", mountpoint!~\"/boot|/var/lib.*\"}) * 100)",
            "format": "table",
            "instant": true
          }
        ],
        "transformations": [
          {
            "id": "organize",
            "options": {
              "excludeByName": {
                "__name__": true,
                "job": true
              },
              "renameByName": {
                "Value": "Usage %",
                "instance": "Instance",
                "mountpoint": "Mount Point",
                "device": "Device"
              }
            }
          }
        ],
        "fieldConfig": {
          "defaults": {
            "custom": {
              "width": 120
            }
          },
          "overrides": [
            {
              "matcher": {"id": "byName", "options": "Usage %"},
              "properties": [
                {
                  "id": "unit",
                  "value": "percent"
                },
                {
                  "id": "color",
                  "value": {
                    "mode": "thresholds"
                  }
                },
                {
                  "id": "thresholds",
                  "value": {
                    "steps": [
                      {"color": "green", "value": 0},
                      {"color": "yellow", "value": 80},
                      {"color": "red", "value": 90}
                    ]
                  }
                }
              ]
            }
          ]
        }
      },
      {
        "title": "Network I/O",
        "type": "timeseries",
        "targets": [
          {
            "expr": "rate(node_network_receive_bytes_total{instance=~\"$instance\", device!~\"lo|docker.*|veth.*\"}[5m]) * 8",
            "legendFormat": "{{instance}} - {{device}} - Inbound"
          },
          {
            "expr": "rate(node_network_transmit_bytes_total{instance=~\"$instance\", device!~\"lo|docker.*|veth.*\"}[5m]) * 8 * -1",
            "legendFormat": "{{instance}} - {{device}} - Outbound"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "bps",
            "custom": {
              "drawStyle": "line",
              "lineWidth": 1,
              "fillOpacity": 10
            }
          }
        }
      }
    ]
  }
}
```

## 🚨 Alerting Dashboard

### Alert Management and Incident Response

```json
{
  "dashboard": {
    "title": "Alert Management - Incident Response",
    "tags": ["alerts", "incidents", "operations"],
    "panels": [
      {
        "title": "Active Alerts",
        "type": "table",
        "targets": [
          {
            "expr": "ALERTS{alertstate=\"firing\"}",
            "format": "table",
            "instant": true
          }
        ],
        "transformations": [
          {
            "id": "organize",
            "options": {
              "excludeByName": {
                "__name__": true,
                "alertstate": true
              },
              "renameByName": {
                "alertname": "Alert",
                "severity": "Severity",
                "instance": "Instance",
                "service": "Service",
                "Value": "Duration"
              }
            }
          }
        ],
        "fieldConfig": {
          "overrides": [
            {
              "matcher": {"id": "byName", "options": "Severity"},
              "properties": [
                {
                  "id": "color",
                  "value": {
                    "mode": "value"
                  }
                },
                {
                  "id": "mappings",
                  "value": [
                    {
                      "options": {
                        "critical": {"color": "red", "index": 0}
                      },
                      "type": "value"
                    },
                    {
                      "options": {
                        "warning": {"color": "yellow", "index": 1}
                      },
                      "type": "value"
                    }
                  ]
                }
              ]
            }
          ]
        }
      },
      {
        "title": "Alert Trends (24h)",
        "type": "timeseries",
        "targets": [
          {
            "expr": "sum(rate(prometheus_notifications_total[5m])) by (instance)",
            "legendFormat": "Notifications Sent"
          },
          {
            "expr": "sum(ALERTS{alertstate=\"firing\"}) by (severity)",
            "legendFormat": "{{severity}} Alerts"
          }
        ]
      },
      {
        "title": "Mean Time to Resolution",
        "type": "stat",
        "targets": [
          {
            "expr": "avg(alert_resolution_time_seconds) / 60",
            "legendFormat": "MTTR (minutes)"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "m",
            "color": {
              "mode": "thresholds"
            },
            "thresholds": {
              "steps": [
                {"color": "green", "value": 0},
                {"color": "yellow", "value": 30},
                {"color": "red", "value": 60}
              ]
            }
          }
        }
      }
    ]
  }
}
```

## 📱 Mobile-Responsive Design

### Mobile Dashboard Configuration

```json
{
  "dashboard": {
    "title": "EdTech Mobile Overview",
    "tags": ["mobile", "overview"],
    "graphTooltip": 1,
    "panels": [
      {
        "title": "System Status",
        "type": "stat",
        "gridPos": {"h": 4, "w": 24, "x": 0, "y": 0},
        "targets": [
          {
            "expr": "up{job=\"edtech-application\"}",
            "legendFormat": "Application"
          },
          {
            "expr": "up{job=\"postgresql\"}",
            "legendFormat": "Database"
          },
          {
            "expr": "up{job=\"redis\"}",
            "legendFormat": "Cache"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "mappings": [
              {
                "options": {
                  "0": {"text": "DOWN", "color": "red"},
                  "1": {"text": "UP", "color": "green"}
                },
                "type": "value"
              }
            ],
            "color": {
              "mode": "value"
            }
          }
        },
        "options": {
          "colorMode": "background",
          "orientation": "horizontal",
          "displayMode": "list"
        }
      }
    ]
  }
}
```

## 🎨 Advanced Visualization Techniques

### Custom Panel Types

**1. Business Metrics Gauge**
```json
{
  "type": "gauge",
  "targets": [
    {
      "expr": "course_completion_rate{course_type=\"licensure_exam\"} * 100",
      "legendFormat": "Completion Rate %"
    }
  ],
  "fieldConfig": {
    "defaults": {
      "unit": "percent",
      "min": 0,
      "max": 100,
      "thresholds": {
        "steps": [
          {"color": "red", "value": 0},
          {"color": "yellow", "value": 60},
          {"color": "green", "value": 80}
        ]
      }
    }
  },
  "options": {
    "showThresholdLabels": true,
    "showThresholdMarkers": true
  }
}
```

**2. User Journey Funnel**
```json
{
  "type": "barchart",
  "targets": [
    {
      "expr": "user_registrations_total",
      "legendFormat": "Registrations"
    },
    {
      "expr": "user_first_course_access_total",
      "legendFormat": "First Access"
    },
    {
      "expr": "user_course_completions_total", 
      "legendFormat": "Completions"
    }
  ],
  "fieldConfig": {
    "defaults": {
      "unit": "short",
      "color": {
        "mode": "palette-classic"
      }
    }
  },
  "options": {
    "orientation": "horizontal",
    "displayMode": "gradient"
  }
}
```

## 🔧 Template Variables and Dynamic Dashboards

### Advanced Template Variables

```json
{
  "templating": {
    "list": [
      {
        "name": "datasource",
        "type": "datasource",
        "query": "prometheus",
        "current": {
          "value": "Prometheus",
          "text": "Prometheus"
        }
      },
      {
        "name": "environment",
        "type": "query",
        "query": "label_values(up, environment)",
        "datasource": "$datasource",
        "refresh": 1,
        "multi": false,
        "includeAll": false
      },
      {
        "name": "service",
        "type": "query",
        "query": "label_values(up{environment=\"$environment\"}, job)",
        "datasource": "$datasource",
        "refresh": 1,
        "multi": true,
        "includeAll": true,
        "current": {
          "text": "All",
          "value": "$__all"
        }
      },
      {
        "name": "time_range",
        "type": "interval",
        "query": "1m,5m,10m,30m,1h,6h,12h,1d,7d,14d,30d",
        "current": {
          "text": "5m",
          "value": "5m"
        }
      }
    ]
  }
}
```

### Dynamic Query Construction

```promql
# Using template variables in queries
sum(rate(http_requests_total{job=~"$service", environment="$environment"}[$time_range])) by (job)

# Conditional queries based on selections
sum(rate(http_requests_total{job=~"${service:regex}", environment="$environment"}[$time_range])) by (${group_by})

# Advanced regex for multi-select
sum(rate(http_requests_total{job=~"${service:pipe}", environment="$environment"}[$time_range])) by (job)
```

## ✅ Dashboard Best Practices Checklist

### Design Principles
- [ ] **Single Purpose**: Each dashboard serves a specific audience
- [ ] **5-Second Rule**: Key information visible within 5 seconds
- [ ] **Color Consistency**: Use consistent color schemes across dashboards
- [ ] **Mobile Responsive**: Test on mobile devices
- [ ] **Template Variables**: Use variables for interactive filtering

### Performance Optimization
- [ ] **Query Efficiency**: Use recording rules for complex calculations
- [ ] **Time Range Limits**: Set appropriate default time ranges
- [ ] **Panel Limits**: Keep dashboards under 20 panels for performance
- [ ] **Refresh Rates**: Match refresh rates to data update frequency

### Maintenance
- [ ] **Version Control**: Store dashboard JSON in Git
- [ ] **Documentation**: Document dashboard purpose and queries
- [ ] **Regular Review**: Monthly dashboard optimization reviews
- [ ] **User Feedback**: Collect and act on user feedback

## 🔗 Navigation

| Previous | Current | Next |
|----------|---------|------|
| [Prometheus Setup Guide](./prometheus-setup-guide.md) | **Grafana Dashboard Guide** | [Alerting Strategies](./alerting-strategies.md) |

---

**Dashboard Development Timeline**: Plan 1-2 weeks for initial dashboard creation, ongoing refinement based on user feedback and changing requirements.

**Key Success Metrics**: Dashboard adoption rate, time to insight, and reduction in manual monitoring tasks.