# Resource Management on Railway.com

## 🎯 Overview

Railway.com provides automatic resource allocation and scaling for applications, with transparent usage-based billing. This guide covers resource management strategies, monitoring, optimization, and cost control for clinic management systems and other healthcare applications.

## 📊 Resource Types and Allocation

### Available Resources

| Resource Type | Description | Billing Model | Clinic Usage |
|---------------|-------------|---------------|--------------|
| **RAM** | Memory allocation per service | $0.000231/MB/hour | 256MB-1GB typical |
| **vCPU** | Virtual CPU cores per service | $0.000463/vCPU/hour | 0.25-1 vCPU typical |
| **Storage** | Persistent disk storage | $0.25/GB/month | 1-5GB typical |
| **Bandwidth** | Data transfer in/out | $0.10/GB | <10GB/month typical |
| **Database I/O** | Database operations | Included in storage | Minimal for clinic |

### Resource Limits by Plan

| Plan | RAM per Service | vCPU per Service | Total Services | Concurrent Builds |
|------|----------------|------------------|----------------|-------------------|
| **Developer** | 8 GB | 8 vCPU | 10 | 1 |
| **Pro** | 32 GB | 32 vCPU | Unlimited | 3 |
| **Team** | 32 GB | 32 vCPU | Unlimited | 5 |

## 🏥 Clinic Management Resource Planning

### Service Resource Allocation

#### API Service (Express.js)
```typescript
const apiResourcePlanning = {
  minimal: {
    ram: "256 MB",
    cpu: "0.25 vCPU",
    usage: "2-3 concurrent users",
    cost: "~$2-3/month"
  },
  
  standard: {
    ram: "512 MB", 
    cpu: "0.5 vCPU",
    usage: "5-10 concurrent users",
    cost: "~$4-6/month"
  },
  
  scaled: {
    ram: "1 GB",
    cpu: "1 vCPU",
    usage: "10-20 concurrent users", 
    cost: "~$8-12/month"
  }
};
```

#### Web Service (React/Vite Static)
```typescript
const webResourcePlanning = {
  static: {
    ram: "CDN hosting",
    cpu: "Edge compute",
    storage: "50-100 MB built assets",
    bandwidth: "2-10 GB/month",
    cost: "~$1-3/month"
  },
  
  features: [
    "Global CDN distribution",
    "Automatic compression",
    "Edge caching",
    "SSL termination"
  ]
};
```

#### Database Service (MySQL)
```typescript
const databaseResourcePlanning = {
  small: {
    storage: "1-2 GB",
    connections: "5 concurrent",
    iops: "1000/day",
    cost: "~$1-2/month"
  },
  
  medium: {
    storage: "3-5 GB",
    connections: "10 concurrent",
    iops: "5000/day",
    cost: "~$2-4/month"
  },
  
  large: {
    storage: "5-10 GB",
    connections: "15 concurrent", 
    iops: "10000/day",
    cost: "~$3-6/month"
  }
};
```

## 📈 Auto-Scaling Configuration

### Railway's Auto-Scaling Behavior
```typescript
const autoScaling = {
  triggers: [
    "CPU usage > 80% for 2 minutes",
    "Memory usage > 85% for 2 minutes", 
    "Request queue backing up",
    "Response times increasing"
  ],
  
  scaling: {
    up: "Automatically adds resources within service limits",
    down: "Gradually reduces resources when demand decreases",
    cooldown: "5-10 minute intervals between scaling events"
  },
  
  billing: "Pay only for actual resource consumption during scaling"
};
```

### Custom Scaling Configuration
```typescript
// Environment-based resource allocation
export class ResourceManager {
  static getResourceConfig(environment: string) {
    const configs = {
      development: {
        ram: '256MB',
        cpu: '0.25',
        replicas: 1,
        autoScale: false
      },
      
      staging: {
        ram: '512MB',
        cpu: '0.5', 
        replicas: 1,
        autoScale: true
      },
      
      production: {
        ram: '1GB',
        cpu: '1',
        replicas: 2,
        autoScale: true,
        maxReplicas: 5
      }
    };
    
    return configs[environment] || configs.development;
  }
  
  // Monitor resource usage
  static async monitorResources(): Promise<ResourceMetrics> {
    return {
      memory: process.memoryUsage(),
      cpu: process.cpuUsage(),
      uptime: process.uptime(),
      timestamp: new Date().toISOString()
    };
  }
}

interface ResourceMetrics {
  memory: NodeJS.MemoryUsage;
  cpu: NodeJS.CpuUsage;
  uptime: number;
  timestamp: string;
}
```

## 🔍 Resource Monitoring and Optimization

### Built-in Railway Monitoring
```typescript
const railwayMonitoring = {
  metrics: [
    "CPU usage over time",
    "Memory consumption",
    "Request volume and response times",
    "Error rates and status codes",
    "Database connection counts"
  ],
  
  alerts: [
    "High resource usage warnings",
    "Service health check failures",
    "Deployment success/failure notifications",
    "Cost threshold alerts"
  ],
  
  access: "Available through Railway dashboard and API"
};
```

### Custom Application Monitoring
```typescript
// Resource monitoring middleware
export class ResourceMonitor {
  private static metrics: Map<string, any[]> = new Map();
  
  // Middleware to track request resources
  static trackRequest() {
    return (req: Request, res: Response, next: NextFunction) => {
      const startTime = process.hrtime();
      const startMemory = process.memoryUsage();
      
      res.on('finish', () => {
        const [seconds, nanoseconds] = process.hrtime(startTime);
        const duration = seconds * 1000 + nanoseconds / 1000000; // Convert to ms
        const endMemory = process.memoryUsage();
        
        const metrics = {
          endpoint: req.path,
          method: req.method,
          statusCode: res.statusCode,
          duration,
          memoryDelta: endMemory.heapUsed - startMemory.heapUsed,
          timestamp: new Date().toISOString()
        };
        
        this.logMetrics(metrics);
      });
      
      next();
    };
  }
  
  private static logMetrics(metrics: any): void {
    // Store metrics for analysis
    const endpoint = metrics.endpoint;
    if (!this.metrics.has(endpoint)) {
      this.metrics.set(endpoint, []);
    }
    
    const endpointMetrics = this.metrics.get(endpoint)!;
    endpointMetrics.push(metrics);
    
    // Keep only last 100 requests per endpoint
    if (endpointMetrics.length > 100) {
      endpointMetrics.shift();
    }
    
    // Alert on slow requests
    if (metrics.duration > 5000) {
      console.warn('Slow request detected:', metrics);
    }
    
    // Alert on high memory usage
    if (metrics.memoryDelta > 50 * 1024 * 1024) { // 50MB
      console.warn('High memory usage in request:', metrics);
    }
  }
  
  // Generate performance report
  static getPerformanceReport(): any {
    const report: any = {};
    
    for (const [endpoint, metrics] of this.metrics.entries()) {
      const durations = metrics.map(m => m.duration);
      const memoryUsage = metrics.map(m => m.memoryDelta);
      
      report[endpoint] = {
        requestCount: metrics.length,
        averageDuration: durations.reduce((a, b) => a + b, 0) / durations.length,
        maxDuration: Math.max(...durations),
        averageMemoryDelta: memoryUsage.reduce((a, b) => a + b, 0) / memoryUsage.length,
        maxMemoryDelta: Math.max(...memoryUsage)
      };
    }
    
    return report;
  }
}
```

### Database Resource Optimization
```typescript
// Database connection pool management
export class DatabaseResourceManager {
  private static pool: any;
  
  static configurePool(environment: string) {
    const configs = {
      development: {
        min: 1,
        max: 3,
        idle: 10000,
        acquire: 30000
      },
      
      production: {
        min: 2,
        max: 10,
        idle: 30000,
        acquire: 60000,
        evict: 1000
      }
    };
    
    return configs[environment] || configs.development;
  }
  
  // Monitor connection pool health
  static async getPoolMetrics(): Promise<any> {
    if (!this.pool) return null;
    
    return {
      totalConnections: this.pool.totalCount,
      idleConnections: this.pool.idleCount,
      busyConnections: this.pool.totalCount - this.pool.idleCount,
      pendingRequests: this.pool.pendingCount,
      timestamp: new Date().toISOString()
    };
  }
  
  // Optimize query performance
  static async optimizeQueries(): Promise<void> {
    // Identify slow queries
    const slowQueries = await this.getSlowQueries();
    
    if (slowQueries.length > 0) {
      console.warn(`Found ${slowQueries.length} slow queries`);
      
      // Log details for optimization
      slowQueries.forEach(query => {
        console.warn('Slow query:', {
          sql: query.sql,
          duration: query.duration,
          rowsExamined: query.rowsExamined
        });
      });
    }
  }
  
  private static async getSlowQueries(): Promise<any[]> {
    // Implementation depends on database type
    // For MySQL: query the slow_log table
    // For PostgreSQL: use pg_stat_statements
    return [];
  }
}
```

## 💰 Cost Optimization Strategies

### Resource Right-Sizing
```typescript
const rightSizing = {
  // Start small and scale up based on actual usage
  strategy: "Conservative initial allocation with monitoring",
  
  initialAllocation: {
    api: "256MB RAM, 0.25 vCPU",
    web: "Static hosting",
    database: "1GB storage"
  },
  
  scalingTriggers: [
    "CPU > 70% for 5+ minutes",
    "Memory > 80% for 5+ minutes", 
    "Response times > 2 seconds",
    "Error rates > 1%"
  ],
  
  optimizationCycle: "Weekly review and adjustment"
};
```

### Environment-Based Resource Management
```typescript
export class EnvironmentResourceManager {
  // Different resource allocations per environment
  static getEnvironmentConfig(env: string) {
    const configs = {
      development: {
        schedule: "9 AM - 6 PM weekdays", // Sleep outside hours
        resources: "Minimal (256MB/0.25 vCPU)",
        costSaving: "60-70%"
      },
      
      staging: {
        schedule: "Active during testing phases",
        resources: "Standard (512MB/0.5 vCPU)",
        costSaving: "40-50%"
      },
      
      production: {
        schedule: "Always available",
        resources: "Auto-scaling (512MB-2GB)",
        costSaving: "Optimized usage patterns"
      }
    };
    
    return configs[env];
  }
  
  // Implement environment sleeping
  static async scheduleEnvironmentSleep(environment: string): Promise<void> {
    if (environment === 'development') {
      // Sleep development environment outside business hours
      const now = new Date();
      const hour = now.getHours();
      const isWeekend = now.getDay() === 0 || now.getDay() === 6;
      
      if (hour < 9 || hour > 18 || isWeekend) {
        // Scale down to minimal resources
        await this.scaleEnvironment(environment, 'minimal');
      }
    }
  }
  
  private static async scaleEnvironment(env: string, level: string): Promise<void> {
    // Implementation would use Railway API to adjust resources
    console.log(`Scaling ${env} environment to ${level} level`);
  }
}
```

### Cache Implementation for Resource Efficiency
```typescript
// Redis caching to reduce database load
export class CacheManager {
  private static redis: any; // Redis client
  
  // Cache frequently accessed data
  static async getCachedData<T>(
    key: string,
    fetcher: () => Promise<T>,
    ttlSeconds: number = 300
  ): Promise<T> {
    try {
      // Try to get from cache first
      const cached = await this.redis.get(key);
      if (cached) {
        return JSON.parse(cached);
      }
      
      // Fetch fresh data
      const data = await fetcher();
      
      // Cache the result
      await this.redis.setex(key, ttlSeconds, JSON.stringify(data));
      
      return data;
    } catch (error) {
      console.warn('Cache error, falling back to direct fetch:', error);
      return fetcher();
    }
  }
  
  // Cache patient data with appropriate TTL
  static async getCachedPatients(clinicId: string): Promise<any[]> {
    return this.getCachedData(
      `patients:${clinicId}`,
      () => PatientService.getPatients(clinicId),
      600 // 10 minutes
    );
  }
  
  // Cache daily schedule with short TTL
  static async getCachedSchedule(date: string): Promise<any[]> {
    return this.getCachedData(
      `schedule:${date}`,
      () => AppointmentService.getDaySchedule(date),
      60 // 1 minute
    );
  }
  
  // Clear cache when data changes
  static async invalidateCache(pattern: string): Promise<void> {
    const keys = await this.redis.keys(pattern);
    if (keys.length > 0) {
      await this.redis.del(keys);
    }
  }
}
```

## 📊 Cost Monitoring and Alerts

### Usage Tracking
```typescript
export class CostMonitor {
  // Track service usage over time
  static async trackUsage(): Promise<UsageMetrics> {
    const metrics = {
      timestamp: new Date().toISOString(),
      services: await this.getServiceUsage(),
      totalCost: await this.calculateCurrentCost(),
      projectedMonthlyCost: await this.projectMonthlyCost()
    };
    
    // Alert if approaching plan limits
    await this.checkCostAlerts(metrics);
    
    return metrics;
  }
  
  private static async getServiceUsage(): Promise<any> {
    return {
      api: {
        ram: process.memoryUsage().heapUsed / (1024 * 1024), // MB
        cpu: process.cpuUsage(),
        uptime: process.uptime()
      },
      database: {
        connections: await this.getDatabaseConnections(),
        storageUsed: await this.getDatabaseStorageUsage()
      }
    };
  }
  
  private static async calculateCurrentCost(): Promise<number> {
    const usage = await this.getServiceUsage();
    
    // Railway pricing: $0.000231/MB/hour, $0.000463/vCPU/hour
    const hourlyCost = 
      (usage.api.ram * 0.000231) +  // RAM cost
      (0.5 * 0.000463);  // Estimated 0.5 vCPU
      
    return hourlyCost;
  }
  
  private static async projectMonthlyCost(): Promise<number> {
    const hourlyCost = await this.calculateCurrentCost();
    return hourlyCost * 24 * 30; // 30 days
  }
  
  private static async checkCostAlerts(metrics: UsageMetrics): Promise<void> {
    // Alert if projected cost exceeds plan
    if (metrics.projectedMonthlyCost > 15) { // 75% of Pro plan
      console.warn('Cost alert: Projected monthly cost approaching plan limit', {
        projected: metrics.projectedMonthlyCost,
        planLimit: 20
      });
    }
    
    // Alert on unusual usage spikes
    if (metrics.services.api.ram > 800) { // >800MB usage
      console.warn('Resource alert: High memory usage detected', {
        currentUsage: metrics.services.api.ram
      });
    }
  }
  
  // Generate cost optimization recommendations
  static generateOptimizationRecommendations(usage: UsageMetrics): string[] {
    const recommendations: string[] = [];
    
    if (usage.services.api.ram > 512) {
      recommendations.push("Consider implementing caching to reduce memory usage");
    }
    
    if (usage.projectedMonthlyCost < 10) {
      recommendations.push("Usage is well below plan capacity - consider optimizing for cost");
    }
    
    if (usage.services.database.connections > 5) {
      recommendations.push("High database connection count - review connection pooling");
    }
    
    return recommendations;
  }
  
  private static async getDatabaseConnections(): Promise<number> {
    // Implementation depends on database
    return 0;
  }
  
  private static async getDatabaseStorageUsage(): Promise<number> {
    // Implementation depends on database
    return 0;
  }
}

interface UsageMetrics {
  timestamp: string;
  services: any;
  totalCost: number;
  projectedMonthlyCost: number;
}
```

## 🎯 Resource Management Best Practices

### Development Workflow
```typescript
const resourceBestPractices = {
  development: [
    "Use minimal resources for development environments",
    "Implement environment sleeping for non-production",
    "Monitor resource usage patterns during development",
    "Test scaling behavior in staging before production"
  ],
  
  production: [
    "Start with conservative resource allocation",
    "Enable auto-scaling for traffic spikes",
    "Implement comprehensive monitoring and alerting",
    "Regular resource usage reviews and optimization"
  ],
  
  optimization: [
    "Cache frequently accessed data",
    "Optimize database queries and indexes", 
    "Implement connection pooling",
    "Use CDN for static assets",
    "Regular performance profiling"
  ]
};
```

### Health Checks and Alerting
```typescript
// Comprehensive health check
app.get('/health', async (req, res) => {
  try {
    const health = {
      status: 'healthy',
      timestamp: new Date().toISOString(),
      service: 'clinic-api',
      version: process.env.APP_VERSION,
      
      resources: {
        memory: process.memoryUsage(),
        cpu: process.cpuUsage(),
        uptime: process.uptime()
      },
      
      dependencies: {
        database: await checkDatabaseHealth(),
        cache: await checkCacheHealth()
      },
      
      metrics: {
        requestsPerMinute: await getRequestRate(),
        averageResponseTime: await getAverageResponseTime(),
        errorRate: await getErrorRate()
      }
    };
    
    // Check if any critical thresholds are exceeded
    const alerts = checkHealthAlerts(health);
    if (alerts.length > 0) {
      health.alerts = alerts;
      health.status = 'warning';
    }
    
    res.json(health);
  } catch (error) {
    res.status(503).json({
      status: 'unhealthy',
      error: error.message,
      timestamp: new Date().toISOString()
    });
  }
});

function checkHealthAlerts(health: any): string[] {
  const alerts: string[] = [];
  
  // Memory usage alerts
  if (health.resources.memory.heapUsed > 400 * 1024 * 1024) { // 400MB
    alerts.push('High memory usage detected');
  }
  
  // Response time alerts
  if (health.metrics.averageResponseTime > 2000) { // 2 seconds
    alerts.push('High average response time');
  }
  
  // Error rate alerts
  if (health.metrics.errorRate > 0.01) { // 1%
    alerts.push('High error rate detected');
  }
  
  return alerts;
}
```

## 📋 Resource Management Checklist

### Initial Setup
- [ ] Resource requirements analyzed for each service
- [ ] Auto-scaling enabled for production services
- [ ] Resource monitoring implemented
- [ ] Cost tracking and alerting configured
- [ ] Environment-specific resource allocation defined

### Ongoing Management
- [ ] Weekly resource usage reviews
- [ ] Monthly cost optimization analysis
- [ ] Performance metrics monitored continuously
- [ ] Scaling events logged and analyzed
- [ ] Resource allocation adjusted based on actual usage

### Optimization
- [ ] Caching implemented for frequent operations
- [ ] Database queries optimized
- [ ] Connection pooling configured correctly
- [ ] Static assets served via CDN
- [ ] Unnecessary resource usage eliminated

### Monitoring
- [ ] Health checks implemented for all services
- [ ] Alerting configured for resource thresholds
- [ ] Performance baselines established
- [ ] Cost projections updated monthly
- [ ] Resource recommendations reviewed and implemented

---

## 🔗 Navigation

- **Previous**: [Database Hosting](./database-hosting.md)
- **Next**: [Troubleshooting Guide](./troubleshooting-guide.md)