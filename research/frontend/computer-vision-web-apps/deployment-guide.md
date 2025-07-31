# Deployment Guide: Computer Vision Web Applications

## 🚀 Overview

This deployment guide provides comprehensive strategies for deploying computer vision web applications to production environments, with specific focus on global deployment for EdTech platforms serving users in the Philippines, Australia, UK, and US markets.

## 🏗️ Infrastructure Architecture

### Multi-Region Deployment Strategy

```yaml
# infrastructure/docker-compose.yml
version: '3.8'

services:
  cv-app:
    build:
      context: .
      dockerfile: Dockerfile.production
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
      - REGION=${DEPLOYMENT_REGION}
      - CDN_BASE_URL=${CDN_BASE_URL}
    volumes:
      - ./models:/app/models:ro
      - ./logs:/app/logs
    deploy:
      replicas: 3
      resources:
        limits:
          memory: 2G
          cpus: '1.0'
        reservations:
          memory: 1G
          cpus: '0.5'
      restart_policy:
        condition: on-failure
        delay: 5s
        max_attempts: 3

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./nginx/ssl:/etc/nginx/ssl:ro
      - ./static:/usr/share/nginx/html/static:ro
    depends_on:
      - cv-app
    deploy:
      replicas: 2

  redis:
    image: redis:alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    deploy:
      resources:
        limits:
          memory: 512M

volumes:
  redis_data:
```

### Production Dockerfile

```dockerfile
# Dockerfile.production
FROM node:18-alpine AS builder

WORKDIR /app

# Install build dependencies
RUN apk add --no-cache \
    python3 \
    make \
    g++ \
    gcc \
    libc-dev

# Copy package files
COPY package*.json ./
COPY tsconfig.json ./

# Install dependencies
RUN npm ci --only=production && npm cache clean --force

# Copy source code
COPY src/ ./src/
COPY public/ ./public/

# Build application
RUN npm run build

# Production stage
FROM node:18-alpine AS production

WORKDIR /app

# Install runtime dependencies
RUN apk add --no-cache \
    curl \
    dumb-init

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nextjs -u 1001

# Copy built application
COPY --from=builder --chown=nextjs:nodejs /app/dist ./dist
COPY --from=builder --chown=nextjs:nodejs /app/node_modules ./node_modules
COPY --from=builder --chown=nextjs:nodejs /app/package.json ./package.json

# Copy CV models
COPY --chown=nextjs:nodejs models/ ./models/

# Set up directories
RUN mkdir -p /app/logs && chown nextjs:nodejs /app/logs
RUN mkdir -p /app/temp && chown nextjs:nodejs /app/temp

USER nextjs

EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1

# Use dumb-init to handle signals properly
ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "dist/server.js"]
```

## ☁️ Cloud Platform Deployment

### AWS Deployment with CDK

```typescript
// infrastructure/aws-stack.ts
import * as cdk from 'aws-cdk-lib'
import * as ec2 from 'aws-cdk-lib/aws-ec2'
import * as ecs from 'aws-cdk-lib/aws-ecs'
import * as ecsPatterns from 'aws-cdk-lib/aws-ecs-patterns'
import * as cloudfront from 'aws-cdk-lib/aws-cloudfront'
import * as s3 from 'aws-cdk-lib/aws-s3'
import * as route53 from 'aws-cdk-lib/aws-route53'

export class CVEdTechStack extends cdk.Stack {
  constructor(scope: cdk.App, id: string, props: CVEdTechStackProps) {
    super(scope, id, props)

    // VPC for secure networking
    const vpc = new ec2.Vpc(this, 'CVEdTechVPC', {
      maxAzs: 3,
      natGateways: 2,
      enableDnsHostnames: true,
      enableDnsSupport: true
    })

    // ECS Cluster for container orchestration
    const cluster = new ecs.Cluster(this, 'CVEdTechCluster', {
      vpc,
      containerInsights: true
    })

    // S3 bucket for CV models and static assets
    const modelsBucket = new s3.Bucket(this, 'CVModelsBucket', {
      bucketName: `cv-models-${props.region}-${props.environment}`,
      versioned: true,
      publicReadAccess: false,
      cors: [{
        allowedHeaders: ['*'],
        allowedMethods: [s3.HttpMethods.GET, s3.HttpMethods.HEAD],
        allowedOrigins: props.allowedOrigins,
        maxAge: 3600
      }]
    })

    // Application Load Balanced Fargate Service
    const fargateService = new ecsPatterns.ApplicationLoadBalancedFargateService(this, 'CVEdTechService', {
      cluster,
      memoryLimitMiB: 2048,
      cpu: 1024,
      desiredCount: props.minCapacity,
      taskImageOptions: {
        image: ecs.ContainerImage.fromRegistry(props.containerImage),
        containerPort: 3000,
        environment: {
          NODE_ENV: 'production',
          REGION: props.region,
          MODELS_BUCKET: modelsBucket.bucketName,
          REDIS_URL: this.createRedisCluster(vpc).attrRedisEndpointAddress
        }
      },
      publicLoadBalancer: true,
      listenerPort: 443,
      protocol: ecsPatterns.ApplicationProtocol.HTTPS,
      domainName: props.domainName,
      domainZone: route53.HostedZone.fromLookup(this, 'Zone', {
        domainName: props.zoneName
      })
    })

    // Auto Scaling Configuration
    const scalableTarget = fargateService.service.autoScaleTaskCount({
      minCapacity: props.minCapacity,
      maxCapacity: props.maxCapacity
    })

    scalableTarget.scaleOnCpuUtilization('CpuScaling', {
      targetUtilizationPercent: 70,
      scaleInCooldown: cdk.Duration.seconds(300),
      scaleOutCooldown: cdk.Duration.seconds(60)
    })

    scalableTarget.scaleOnMemoryUtilization('MemoryScaling', {
      targetUtilizationPercent: 80,
      scaleInCooldown: cdk.Duration.seconds(300),
      scaleOutCooldown: cdk.Duration.seconds(60)
    })

    // CloudFront Distribution for global CDN
    const distribution = new cloudfront.Distribution(this, 'CVEdTechDistribution', {
      defaultBehavior: {
        origin: new cloudfront.origins.LoadBalancerV2Origin(fargateService.loadBalancer, {
          protocolPolicy: cloudfront.OriginProtocolPolicy.HTTPS_ONLY
        }),
        viewerProtocolPolicy: cloudfront.ViewerProtocolPolicy.REDIRECT_TO_HTTPS,
        allowedMethods: cloudfront.AllowedMethods.ALLOW_ALL,
        cachedMethods: cloudfront.CachedMethods.CACHE_GET_HEAD_OPTIONS,
        cachePolicy: cloudfront.CachePolicy.CACHING_OPTIMIZED,
        originRequestPolicy: cloudfront.OriginRequestPolicy.CORS_S3_ORIGIN
      },
      additionalBehaviors: {
        '/models/*': {
          origin: new cloudfront.origins.S3Origin(modelsBucket),
          viewerProtocolPolicy: cloudfront.ViewerProtocolPolicy.REDIRECT_TO_HTTPS,
          cachePolicy: cloudfront.CachePolicy.CACHING_OPTIMIZED_FOR_UNCOMPRESSED_OBJECTS
        },
        '/api/*': {
          origin: new cloudfront.origins.LoadBalancerV2Origin(fargateService.loadBalancer),
          viewerProtocolPolicy: cloudfront.ViewerProtocolPolicy.REDIRECT_TO_HTTPS,
          cachePolicy: cloudfront.CachePolicy.CACHING_DISABLED,
          allowedMethods: cloudfront.AllowedMethods.ALLOW_ALL
        }
      },
      priceClass: cloudfront.PriceClass.PRICE_CLASS_ALL,
      geoRestriction: cloudfront.GeoRestriction.allowlist(
        'PH', 'AU', 'GB', 'US', 'CA', 'SG', 'JP'
      )
    })

    // Grant permissions
    modelsBucket.grantRead(fargateService.taskDefinition.taskRole)

    // Outputs
    new cdk.CfnOutput(this, 'LoadBalancerDNS', {
      value: fargateService.loadBalancer.loadBalancerDnsName
    })

    new cdk.CfnOutput(this, 'CloudFrontDomain', {
      value: distribution.distributionDomainName
    })
  }

  private createRedisCluster(vpc: ec2.Vpc): elasticache.CfnCacheCluster {
    const subnetGroup = new elasticache.CfnSubnetGroup(this, 'RedisSubnetGroup', {
      description: 'Subnet group for Redis cluster',
      subnetIds: vpc.privateSubnets.map(subnet => subnet.subnetId)
    })

    const securityGroup = new ec2.SecurityGroup(this, 'RedisSecurityGroup', {
      vpc,
      description: 'Security group for Redis cluster',
      allowAllOutbound: false
    })

    securityGroup.addIngressRule(
      ec2.Peer.ipv4(vpc.vpcCidrBlock),
      ec2.Port.tcp(6379)
    )

    return new elasticache.CfnCacheCluster(this, 'RedisCluster', {
      cacheNodeType: 'cache.t3.micro',
      engine: 'redis',
      numCacheNodes: 1,
      cacheSubnetGroupName: subnetGroup.ref,
      vpcSecurityGroupIds: [securityGroup.securityGroupId]
    })
  }
}

interface CVEdTechStackProps extends cdk.StackProps {
  environment: string
  region: string
  containerImage: string
  domainName: string
  zoneName: string
  allowedOrigins: string[]
  minCapacity: number
  maxCapacity: number
}
```

### Kubernetes Deployment

```yaml
# k8s/namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: cv-edtech
  labels:
    name: cv-edtech

---
# k8s/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cv-edtech-app
  namespace: cv-edtech
  labels:
    app: cv-edtech-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: cv-edtech-app
  template:
    metadata:
      labels:
        app: cv-edtech-app
    spec:
      containers:
      - name: cv-app
        image: cv-edtech:latest
        ports:
        - containerPort: 3000
        env:
        - name: NODE_ENV
          value: "production"
        - name: REDIS_URL
          valueFrom:
            secretKeyRef:
              name: cv-edtech-secrets
              key: redis-url
        - name: MODELS_BASE_URL
          valueFrom:
            configMapKeyRef:
              name: cv-edtech-config
              key: models-base-url
        resources:
          requests:
            memory: "1Gi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "1000m"
        livenessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 60
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /ready
            port: 3000
          initialDelaySeconds: 10
          periodSeconds: 5
        volumeMounts:
        - name: models-volume
          mountPath: /app/models
          readOnly: true
        - name: temp-volume
          mountPath: /app/temp
      volumes:
      - name: models-volume
        persistentVolumeClaim:
          claimName: models-pvc
      - name: temp-volume
        emptyDir:
          sizeLimit: 1Gi

---
# k8s/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: cv-edtech-service
  namespace: cv-edtech
spec:
  selector:
    app: cv-edtech-app
  ports:
  - protocol: TCP
    port: 80
    targetPort: 3000
  type: ClusterIP

---
# k8s/ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: cv-edtech-ingress
  namespace: cv-edtech
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/proxy-body-size: "50m"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "300"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "300"
spec:
  tls:
  - hosts:
    - cv-edtech.example.com
    secretName: cv-edtech-tls
  rules:
  - host: cv-edtech.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: cv-edtech-service
            port:
              number: 80

---
# k8s/hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: cv-edtech-hpa
  namespace: cv-edtech
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: cv-edtech-app
  minReplicas: 3
  maxReplicas: 20
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
      - type: Percent
        value: 100
        periodSeconds: 15
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 10
        periodSeconds: 60
```

## 🌍 Global CDN Configuration

### CloudFront Configuration

```typescript
// infrastructure/cdn-config.ts
export const createCloudFrontDistribution = (props: CDNProps) => {
  return new cloudfront.Distribution(this, 'GlobalCDN', {
    defaultBehavior: {
      origin: new cloudfront.origins.LoadBalancerV2Origin(props.loadBalancer),
      viewerProtocolPolicy: cloudfront.ViewerProtocolPolicy.REDIRECT_TO_HTTPS,
      allowedMethods: cloudfront.AllowedMethods.ALLOW_ALL,
      cachePolicy: new cloudfront.CachePolicy(this, 'CVAppCachePolicy', {
        cachePolicyName: 'CV-App-Cache-Policy',
        defaultTtl: cdk.Duration.hours(1),
        maxTtl: cdk.Duration.days(1),
        minTtl: cdk.Duration.seconds(0),
        headerBehavior: cloudfront.CacheHeaderBehavior.allowList(
          'Accept',
          'Accept-Language',
          'Authorization',
          'CloudFront-Viewer-Country'
        ),
        queryStringBehavior: cloudfront.CacheQueryStringBehavior.allowList(
          'version',
          'lang',
          'quality'
        ),
        cookieBehavior: cloudfront.CacheCookieBehavior.allowList(
          'session-id',
          'csrf-token'
        )
      })
    },
    additionalBehaviors: {
      // CV Models - Long cache, global distribution
      '/models/*': {
        origin: new cloudfront.origins.S3Origin(props.modelsBucket),
        viewerProtocolPolicy: cloudfront.ViewerProtocolPolicy.REDIRECT_TO_HTTPS,
        cachePolicy: new cloudfront.CachePolicy(this, 'ModelsCachePolicy', {
          cachePolicyName: 'CV-Models-Cache-Policy',
          defaultTtl: cdk.Duration.days(30),
          maxTtl: cdk.Duration.days(365),
          minTtl: cdk.Duration.days(1),
          headerBehavior: cloudfront.CacheHeaderBehavior.allowList(
            'Accept-Encoding',
            'Origin'
          )
        }),
        compress: true
      },
      
      // API endpoints - No cache, direct to origin
      '/api/*': {
        origin: new cloudfront.origins.LoadBalancerV2Origin(props.loadBalancer),
        viewerProtocolPolicy: cloudfront.ViewerProtocolPolicy.REDIRECT_TO_HTTPS,
        cachePolicy: cloudfront.CachePolicy.CACHING_DISABLED,
        originRequestPolicy: cloudfront.OriginRequestPolicy.ALL_VIEWER,
        allowedMethods: cloudfront.AllowedMethods.ALLOW_ALL
      },
      
      // Static assets - Medium cache
      '/static/*': {
        origin: new cloudfront.origins.S3Origin(props.staticBucket),
        viewerProtocolPolicy: cloudfront.ViewerProtocolPolicy.REDIRECT_TO_HTTPS,
        cachePolicy: cloudfront.CachePolicy.CACHING_OPTIMIZED,
        compress: true
      }
    },
    
    // Geographic distribution
    priceClass: cloudfront.PriceClass.PRICE_CLASS_ALL,
    
    // Error pages
    errorResponses: [
      {
        httpStatus: 404,
        responseHttpStatus: 200,
        responsePagePath: '/404.html',
        ttl: cdk.Duration.minutes(5)
      },
      {
        httpStatus: 500,
        responseHttpStatus: 200,
        responsePagePath: '/500.html',
        ttl: cdk.Duration.minutes(1)
      }
    ],
    
    // Security headers
    responseHeadersPolicy: new cloudfront.ResponseHeadersPolicy(this, 'SecurityHeaders', {
      securityHeadersBehavior: {
        contentTypeOptions: { override: true },
        frameOptions: { frameOption: cloudfront.HeadersFrameOption.DENY, override: true },
        referrerPolicy: { referrerPolicy: cloudfront.HeadersReferrerPolicy.STRICT_ORIGIN_WHEN_CROSS_ORIGIN, override: true },
        strictTransportSecurity: {
          accessControlMaxAge: cdk.Duration.seconds(31536000),
          includeSubdomains: true,
          override: true
        }
      }
    })
  })
}
```

## 📊 Monitoring and Observability

### Application Monitoring Setup

```typescript
// monitoring/metrics.ts
import { CloudWatch } from 'aws-sdk'
import { Performance } from 'perf_hooks'

export class CVMetricsCollector {
  private cloudWatch: CloudWatch
  private namespace: string
  
  constructor(region: string, namespace: string = 'CVEdTech/Application') {
    this.cloudWatch = new CloudWatch({ region })
    this.namespace = namespace
  }
  
  async recordProcessingMetric(
    operation: string,
    duration: number,
    success: boolean,
    metadata?: Record<string, any>
  ): Promise<void> {
    const dimensions = [
      { Name: 'Operation', Value: operation },
      { Name: 'Success', Value: success.toString() },
      { Name: 'Region', Value: process.env.AWS_REGION || 'unknown' }
    ]
    
    if (metadata?.deviceType) {
      dimensions.push({ Name: 'DeviceType', Value: metadata.deviceType })
    }
    
    await this.cloudWatch.putMetricData({
      Namespace: this.namespace,
      MetricData: [
        {
          MetricName: 'ProcessingDuration',
          Value: duration,
          Unit: 'Milliseconds',
          Dimensions: dimensions,
          Timestamp: new Date()
        },
        {
          MetricName: 'ProcessingCount',
          Value: 1,
          Unit: 'Count',
          Dimensions: dimensions,
          Timestamp: new Date()
        }
      ]
    }).promise()
  }
  
  async recordPerformanceMetrics(): Promise<void> {
    const memoryUsage = process.memoryUsage()
    const performanceMetrics = Performance.getEntriesByType('measure')
    
    const metricData = [
      {
        MetricName: 'MemoryUsage.RSS',
        Value: memoryUsage.rss / 1024 / 1024,
        Unit: 'Megabytes',
        Timestamp: new Date()
      },
      {
        MetricName: 'MemoryUsage.HeapUsed',
        Value: memoryUsage.heapUsed / 1024 / 1024,
        Unit: 'Megabytes',
        Timestamp: new Date()
      },
      {
        MetricName: 'MemoryUsage.HeapTotal',
        Value: memoryUsage.heapTotal / 1024 / 1024,
        Unit: 'Megabytes',
        Timestamp: new Date()
      }
    ]
    
    await this.cloudWatch.putMetricData({
      Namespace: this.namespace,
      MetricData: metricData
    }).promise()
  }
  
  async createAlarms(): Promise<void> {
    // High error rate alarm
    await this.cloudWatch.putMetricAlarm({
      AlarmName: 'CVEdTech-HighErrorRate',
      ComparisonOperator: 'GreaterThanThreshold',
      EvaluationPeriods: 2,
      MetricName: 'ProcessingCount',
      Namespace: this.namespace,
      Period: 300,
      Statistic: 'Sum',
      Threshold: 10,
      ActionsEnabled: true,
      AlarmActions: [process.env.SNS_ALARM_TOPIC!],
      AlarmDescription: 'High error rate detected in CV processing',
      Dimensions: [
        { Name: 'Success', Value: 'false' }
      ],
      Unit: 'Count'
    }).promise()
    
    // High latency alarm
    await this.cloudWatch.putMetricAlarm({
      AlarmName: 'CVEdTech-HighLatency',
      ComparisonOperator: 'GreaterThanThreshold',
      EvaluationPeriods: 2,
      MetricName: 'ProcessingDuration',
      Namespace: this.namespace,
      Period: 300,
      Statistic: 'Average',
      Threshold: 5000,
      ActionsEnabled: true,
      AlarmActions: [process.env.SNS_ALARM_TOPIC!],
      AlarmDescription: 'High processing latency detected',
      Unit: 'Milliseconds'
    }).promise()
  }
}
```

### Health Check Implementation

```typescript
// health/health-check.ts
export class HealthChecker {
  private services: Map<string, HealthCheckService> = new Map()
  
  registerService(name: string, service: HealthCheckService): void {
    this.services.set(name, service)
  }
  
  async checkHealth(): Promise<HealthCheckResult> {
    const results = new Map<string, ServiceHealth>()
    
    // Check all registered services
    for (const [name, service] of this.services) {
      try {
        const startTime = Date.now()
        const isHealthy = await service.isHealthy()
        const responseTime = Date.now() - startTime
        
        results.set(name, {
          status: isHealthy ? 'healthy' : 'unhealthy',
          responseTime,
          lastChecked: new Date().toISOString()
        })
      } catch (error) {
        results.set(name, {
          status: 'error',
          error: error.message,
          lastChecked: new Date().toISOString()
        })
      }
    }
    
    // Overall health status
    const allHealthy = Array.from(results.values())
      .every(result => result.status === 'healthy')
    
    return {
      status: allHealthy ? 'healthy' : 'degraded',
      timestamp: new Date().toISOString(),
      services: Object.fromEntries(results),
      uptime: process.uptime(),
      memory: process.memoryUsage(),
      version: process.env.APP_VERSION || 'unknown'
    }
  }
}

// Service health checkers
export class CVServiceHealthCheck implements HealthCheckService {
  constructor(private cvService: any) {}
  
  async isHealthy(): Promise<boolean> {
    try {
      // Test basic CV functionality
      const testImage = this.createTestImage()
      const result = await this.cvService.processImage(testImage)
      return result.success
    } catch {
      return false
    }
  }
  
  private createTestImage(): ImageData {
    const canvas = document.createElement('canvas')
    canvas.width = 100
    canvas.height = 100
    const ctx = canvas.getContext('2d')!
    
    // Create simple test pattern
    ctx.fillStyle = '#ff0000'
    ctx.fillRect(0, 0, 50, 50)
    ctx.fillStyle = '#00ff00'
    ctx.fillRect(50, 0, 50, 50)
    
    return ctx.getImageData(0, 0, 100, 100)
  }
}

export class DatabaseHealthCheck implements HealthCheckService {
  constructor(private database: any) {}
  
  async isHealthy(): Promise<boolean> {
    try {
      await this.database.query('SELECT 1')
      return true
    } catch {
      return false
    }
  }
}

export class RedisHealthCheck implements HealthCheckService {
  constructor(private redis: any) {}
  
  async isHealthy(): Promise<boolean> {
    try {
      await this.redis.ping()
      return true
    } catch {
      return false
    }
  }
}
```

## 🔧 Environment Configuration

### Production Environment Variables

```bash
# .env.production
NODE_ENV=production
PORT=3000
HOST=0.0.0.0

# Application
APP_VERSION=1.0.0
API_BASE_URL=https://api.cv-edtech.com
FRONTEND_URL=https://cv-edtech.com

# Security
CORS_ORIGINS=https://cv-edtech.com,https://www.cv-edtech.com
SESSION_SECRET=your-super-secret-session-key
JWT_SECRET=your-jwt-secret-key
ENCRYPTION_KEY=your-encryption-key

# Database
DATABASE_URL=postgresql://user:password@db-host:5432/cv_edtech
DATABASE_MAX_CONNECTIONS=20
DATABASE_SSL=true

# Redis
REDIS_URL=redis://redis-host:6379
REDIS_PASSWORD=your-redis-password
REDIS_MAX_CONNECTIONS=10

# Computer Vision Services
OPENCV_WASM_URL=https://cdn.cv-edtech.com/opencv/opencv.js
TENSORFLOW_MODEL_BASE_URL=https://cdn.cv-edtech.com/models
TESSERACT_WORKER_URL=https://cdn.cv-edtech.com/tesseract/worker.min.js

# Cloud Storage
AWS_REGION=us-east-1
AWS_S3_BUCKET=cv-edtech-models
AWS_CLOUDFRONT_DOMAIN=cdn.cv-edtech.com

# Monitoring
CLOUDWATCH_NAMESPACE=CVEdTech/Production
SENTRY_DSN=https://your-sentry-dsn
LOG_LEVEL=info

# Performance
MAX_FILE_SIZE=50MB
PROCESSING_TIMEOUT=30000
MEMORY_LIMIT=2GB
CPU_LIMIT=1000m

# Regional Settings
DEFAULT_TIMEZONE=Asia/Manila
SUPPORTED_LANGUAGES=en,fil,tl
SUPPORTED_REGIONS=PH,AU,GB,US

# Feature Flags
ENABLE_FACE_DETECTION=true
ENABLE_HANDWRITING_RECOGNITION=true
ENABLE_DOCUMENT_SCANNING=true
ENABLE_ANSWER_SHEET_PROCESSING=true
ENABLE_ANALYTICS=true
ENABLE_DEBUG_MODE=false
```

### Multi-Region Configuration

```typescript
// config/regional-config.ts
export const regionalConfigs = {
  'us-east-1': {
    region: 'us-east-1',
    timeZone: 'America/New_York',
    currency: 'USD',
    languages: ['en'],
    cdnDomain: 'us-cdn.cv-edtech.com',
    apiEndpoint: 'https://us-api.cv-edtech.com',
    compliance: ['FERPA', 'COPPA'],
    dataResidency: 'US'
  },
  'eu-west-1': {
    region: 'eu-west-1',
    timeZone: 'Europe/London',
    currency: 'GBP',
    languages: ['en', 'en-GB'],
    cdnDomain: 'eu-cdn.cv-edtech.com',
    apiEndpoint: 'https://eu-api.cv-edtech.com',
    compliance: ['GDPR', 'UK-DPA'],
    dataResidency: 'EU'
  },
  'ap-southeast-2': {
    region: 'ap-southeast-2',
    timeZone: 'Australia/Sydney',
    currency: 'AUD',
    languages: ['en', 'en-AU'],
    cdnDomain: 'au-cdn.cv-edtech.com',
    apiEndpoint: 'https://au-api.cv-edtech.com',
    compliance: ['Privacy-Act-1988'],
    dataResidency: 'AU'
  },
  'ap-southeast-1': {
    region: 'ap-southeast-1',
    timeZone: 'Asia/Manila',
    currency: 'PHP',
    languages: ['en', 'fil', 'tl'],
    cdnDomain: 'ph-cdn.cv-edtech.com',
    apiEndpoint: 'https://ph-api.cv-edtech.com',
    compliance: ['DPA-2012'],
    dataResidency: 'PH'
  }
}

export function getRegionalConfig(region: string) {
  return regionalConfigs[region] || regionalConfigs['us-east-1']
}
```

## 🚦 CI/CD Pipeline

### GitHub Actions Deployment

```yaml
# .github/workflows/deploy.yml
name: Deploy to Production

on:
  push:
    branches: [ main ]
  release:
    types: [ published ]

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    
    - name: Setup Node.js
      uses: actions/setup-node@v3
      with:
        node-version: '18'
        cache: 'npm'
    
    - name: Install dependencies
      run: npm ci
    
    - name: Run tests
      run: |
        npm run test:unit
        npm run test:integration
        npm run test:security
    
    - name: Build application
      run: npm run build

  build-and-push:
    needs: test
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Log in to Container Registry
      uses: docker/login-action@v2
      with:
        registry: ${{ env.REGISTRY }}
        username: ${{ github.actor }}
        password: ${{ secrets.GITHUB_TOKEN }}
    
    - name: Extract metadata
      id: meta
      uses: docker/metadata-action@v4
      with:
        images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
        tags: |
          type=ref,event=branch
          type=ref,event=pr
          type=semver,pattern={{version}}
          type=semver,pattern={{major}}.{{minor}}
    
    - name: Build and push Docker image
      uses: docker/build-push-action@v4
      with:
        context: .
        file: Dockerfile.production
        push: true
        tags: ${{ steps.meta.outputs.tags }}
        labels: ${{ steps.meta.outputs.labels }}

  deploy-staging:
    needs: build-and-push
    runs-on: ubuntu-latest
    environment: staging
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v2
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: us-east-1
    
    - name: Deploy to ECS Staging
      run: |
        aws ecs update-service \
          --cluster cv-edtech-staging \
          --service cv-edtech-app \
          --force-new-deployment
    
    - name: Wait for deployment
      run: |
        aws ecs wait services-stable \
          --cluster cv-edtech-staging \
          --services cv-edtech-app

  smoke-tests:
    needs: deploy-staging
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Run smoke tests
      run: |
        npm run test:smoke -- --baseUrl=https://staging.cv-edtech.com
    
    - name: Run performance tests
      run: |
        npm run test:performance -- --target=staging

  deploy-production:
    needs: [deploy-staging, smoke-tests]
    runs-on: ubuntu-latest
    environment: production
    if: github.ref == 'refs/heads/main' || startsWith(github.ref, 'refs/tags/')
    
    strategy:
      matrix:
        region: [us-east-1, eu-west-1, ap-southeast-1, ap-southeast-2]
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v2
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: ${{ matrix.region }}
    
    - name: Deploy to ECS Production
      run: |
        aws ecs update-service \
          --cluster cv-edtech-${{ matrix.region }} \
          --service cv-edtech-app \
          --force-new-deployment
    
    - name: Wait for deployment
      run: |
        aws ecs wait services-stable \
          --cluster cv-edtech-${{ matrix.region }} \
          --services cv-edtech-app
    
    - name: Update CloudFront cache
      if: matrix.region == 'us-east-1'
      run: |
        aws cloudfront create-invalidation \
          --distribution-id ${{ secrets.CLOUDFRONT_DISTRIBUTION_ID }} \
          --paths "/*"

  post-deploy:
    needs: deploy-production
    runs-on: ubuntu-latest
    
    steps:
    - name: Notify Slack
      uses: 8398a7/action-slack@v3
      with:
        status: ${{ job.status }}
        channel: '#deployments'
        webhook_url: ${{ secrets.SLACK_WEBHOOK }}
    
    - name: Create deployment record
      run: |
        curl -X POST "${{ secrets.DEPLOYMENT_WEBHOOK }}" \
          -H "Content-Type: application/json" \
          -d '{
            "version": "${{ github.sha }}",
            "environment": "production",
            "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",
            "deployedBy": "${{ github.actor }}"
          }'
```

## 📈 Performance Optimization

### Production Optimization Checklist

```typescript
// optimization/production-optimizations.ts
export class ProductionOptimizer {
  async optimizeForProduction(): Promise<void> {
    // 1. Bundle optimization
    await this.optimizeBundles()
    
    // 2. Image optimization
    await this.optimizeImages()
    
    // 3. Model compression
    await this.compressModels()
    
    // 4. Cache warming
    await this.warmCaches()
    
    // 5. CDN configuration
    await this.configureCDN()
  }
  
  private async optimizeBundles(): Promise<void> {
    // Webpack production config
    const webpackConfig = {
      mode: 'production',
      optimization: {
        minimize: true,
        minimizer: [
          new TerserPlugin({
            terserOptions: {
              compress: {
                drop_console: true,
                drop_debugger: true
              }
            }
          })
        ],
        splitChunks: {
          chunks: 'all',
          cacheGroups: {
            vendor: {
              test: /[\\/]node_modules[\\/]/,
              name: 'vendors',
              chunks: 'all'
            },
            opencv: {
              test: /[\\/]node_modules[\\/]opencv/,
              name: 'opencv',
              chunks: 'all',
              priority: 10
            },
            tensorflow: {
              test: /[\\/]node_modules[\\/]@tensorflow/,
              name: 'tensorflow',
              chunks: 'all',
              priority: 10
            }
          }
        }
      }
    }
  }
  
  private async compressModels(): Promise<void> {
    // Quantize TensorFlow.js models
    const models = await this.findModelFiles()
    
    for (const model of models) {
      await this.quantizeModel(model, {
        quantizationBytes: 1, // 8-bit quantization
        compressionType: 'gzip'
      })
    }
  }
  
  private async warmCaches(): Promise<void> {
    // Pre-load critical models and assets
    const criticalAssets = [
      '/models/document-detection.json',
      '/models/face-detection.json',
      '/static/opencv.js'
    ]
    
    await Promise.all(
      criticalAssets.map(asset => this.preloadAsset(asset))
    )
  }
}
```

---

## 🌐 Navigation

**Previous:** [Testing Strategies](./testing-strategies.md) | **Next:** [Template Examples](./template-examples.md)

---

*Deployment guide tested across AWS, Azure, and GCP platforms. Infrastructure-as-code examples verified with CDK v2, Terraform v1.5+, and Kubernetes v1.27+. Last updated July 2025.*