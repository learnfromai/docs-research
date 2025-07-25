# Deployment Strategies for Monorepo

## Overview

Effective deployment strategies for monorepos require careful orchestration of multiple services while maintaining zero-downtime deployments, rollback capabilities, and environment consistency across development, staging, and production.

## Deployment Architecture

### Multi-Environment Strategy

```yaml
# environments/production.yml
environments:
  development:
    region: us-east-1
    services:
      api-gateway: 
        replicas: 1
        cpu: 256
        memory: 512
      user-service:
        replicas: 1
        cpu: 256
        memory: 512
      expense-service:
        replicas: 1
        cpu: 256
        memory: 512
    database:
      tier: t3.micro
      backup: disabled
      
  staging:
    region: us-east-1
    services:
      api-gateway:
        replicas: 2
        cpu: 512
        memory: 1024
      user-service:
        replicas: 2
        cpu: 512
        memory: 1024
      expense-service:
        replicas: 2
        cpu: 512
        memory: 1024
    database:
      tier: t3.small
      backup: daily
      
  production:
    region: us-east-1
    services:
      api-gateway:
        replicas: 3
        cpu: 1024
        memory: 2048
        autoscaling:
          min: 3
          max: 10
          targetCPU: 70
      user-service:
        replicas: 3
        cpu: 1024
        memory: 2048
        autoscaling:
          min: 3
          max: 8
          targetCPU: 70
      expense-service:
        replicas: 3
        cpu: 1024
        memory: 2048
        autoscaling:
          min: 3
          max: 8
          targetCPU: 70
    database:
      tier: t3.medium
      backup: continuous
      multiAZ: true
```

### Infrastructure as Code

```typescript
// infrastructure/aws-stack.ts
import * as aws from '@pulumi/aws';
import * as awsx from '@pulumi/awsx';

export class ExpenseTrackerStack {
  private cluster: aws.ecs.Cluster;
  private vpc: awsx.ec2.Vpc;
  private loadBalancer: awsx.elasticloadbalancingv2.ApplicationLoadBalancer;

  constructor(private environment: string) {
    this.createNetworking();
    this.createCluster();
    this.createLoadBalancer();
    this.deployServices();
  }

  private createNetworking() {
    this.vpc = new awsx.ec2.Vpc(`expense-tracker-vpc-${this.environment}`, {
      cidrBlock: "10.0.0.0/16",
      numberOfAvailabilityZones: 2,
      enableDnsHostnames: true,
      enableDnsSupport: true,
      tags: {
        Environment: this.environment,
        Project: "expense-tracker"
      }
    });
  }

  private createCluster() {
    this.cluster = new aws.ecs.Cluster(`expense-tracker-cluster-${this.environment}`, {
      capacityProviders: ["FARGATE"],
      defaultCapacityProviderStrategies: [{
        capacityProvider: "FARGATE",
        weight: 1,
      }],
      tags: {
        Environment: this.environment,
        Project: "expense-tracker"
      }
    });
  }

  private createLoadBalancer() {
    this.loadBalancer = new awsx.elasticloadbalancingv2.ApplicationLoadBalancer(
      `expense-tracker-alb-${this.environment}`,
      {
        vpc: this.vpc,
        tags: {
          Environment: this.environment,
          Project: "expense-tracker"
        }
      }
    );
  }

  private deployServices() {
    this.deployApiGateway();
    this.deployUserService();
    this.deployExpenseService();
    this.deployWebApp();
  }

  private deployApiGateway() {
    const service = new awsx.ecs.FargateService(`api-gateway-${this.environment}`, {
      cluster: this.cluster.arn,
      taskDefinitionArgs: {
        container: {
          image: "expense-tracker/api-gateway:latest",
          memory: this.getServiceConfig().apiGateway.memory,
          cpu: this.getServiceConfig().apiGateway.cpu,
          environment: [
            { name: "NODE_ENV", value: this.environment },
            { name: "USER_SERVICE_URL", value: "http://user-service:3001" },
            { name: "EXPENSE_SERVICE_URL", value: "http://expense-service:3002" }
          ],
          portMappings: [{
            containerPort: 3000,
            protocol: "tcp"
          }]
        }
      },
      desiredCount: this.getServiceConfig().apiGateway.replicas
    });

    // Attach to load balancer
    const target = this.loadBalancer.defaultTargetGroup.createListener("api-gateway", {
      port: 3000,
      protocol: "HTTP",
      defaultAction: {
        type: "forward",
        targetGroupArn: service.targetGroup.arn
      }
    });
  }

  private getServiceConfig() {
    // Return environment-specific configuration
    const configs = {
      development: {
        apiGateway: { replicas: 1, cpu: 256, memory: 512 },
        userService: { replicas: 1, cpu: 256, memory: 512 },
        expenseService: { replicas: 1, cpu: 256, memory: 512 }
      },
      production: {
        apiGateway: { replicas: 3, cpu: 1024, memory: 2048 },
        userService: { replicas: 3, cpu: 1024, memory: 2048 },
        expenseService: { replicas: 3, cpu: 1024, memory: 2048 }
      }
    };
    return configs[this.environment] || configs.development;
  }
}
```

## Container Registry Strategy

### Docker Build and Push Automation

```typescript
// tools/scripts/docker-build-push.ts
import { execSync } from 'child_process';
import { readFileSync } from 'fs';

interface BuildConfig {
  service: string;
  dockerfile: string;
  context: string;
  registry: string;
  tags: string[];
}

export class DockerBuildPush {
  private configs: BuildConfig[] = [
    {
      service: 'api-gateway',
      dockerfile: 'apps/microservices/api-gateway/Dockerfile',
      context: '.',
      registry: process.env.DOCKER_REGISTRY || 'expense-tracker',
      tags: ['latest', process.env.BUILD_NUMBER || 'dev']
    },
    {
      service: 'user-service',
      dockerfile: 'apps/microservices/user-service/Dockerfile',
      context: '.',
      registry: process.env.DOCKER_REGISTRY || 'expense-tracker',
      tags: ['latest', process.env.BUILD_NUMBER || 'dev']
    },
    {
      service: 'expense-service',
      dockerfile: 'apps/microservices/expense-service/Dockerfile',
      context: '.',
      registry: process.env.DOCKER_REGISTRY || 'expense-tracker',
      tags: ['latest', process.env.BUILD_NUMBER || 'dev']
    }
  ];

  async buildAndPush(serviceNames?: string[]) {
    const servicesToBuild = serviceNames 
      ? this.configs.filter(config => serviceNames.includes(config.service))
      : this.configs;

    console.log(`🐳 Building and pushing ${servicesToBuild.length} services...`);

    for (const config of servicesToBuild) {
      await this.buildService(config);
      await this.pushService(config);
    }

    console.log('✅ All services built and pushed successfully!');
  }

  private async buildService(config: BuildConfig) {
    console.log(`🔨 Building ${config.service}...`);
    
    const tags = config.tags.map(tag => 
      `-t ${config.registry}/${config.service}:${tag}`
    ).join(' ');

    const buildCommand = `docker build ${tags} -f ${config.dockerfile} ${config.context}`;
    
    try {
      execSync(buildCommand, { stdio: 'inherit' });
      console.log(`✅ Successfully built ${config.service}`);
    } catch (error) {
      console.error(`❌ Failed to build ${config.service}:`, error);
      throw error;
    }
  }

  private async pushService(config: BuildConfig) {
    console.log(`📤 Pushing ${config.service}...`);
    
    for (const tag of config.tags) {
      const pushCommand = `docker push ${config.registry}/${config.service}:${tag}`;
      
      try {
        execSync(pushCommand, { stdio: 'inherit' });
        console.log(`✅ Successfully pushed ${config.service}:${tag}`);
      } catch (error) {
        console.error(`❌ Failed to push ${config.service}:${tag}:`, error);
        throw error;
      }
    }
  }

  async getAffectedServices(): Promise<string[]> {
    try {
      const output = execSync('npx nx print-affected --type=app --select=projects', { 
        encoding: 'utf8' 
      });
      
      return output
        .split('\n')
        .filter(line => line.trim())
        .filter(project => this.configs.some(config => config.service === project));
    } catch (error) {
      console.warn('Could not determine affected services, building all');
      return this.configs.map(config => config.service);
    }
  }
}

// Usage
async function main() {
  const builder = new DockerBuildPush();
  const affectedServices = await builder.getAffectedServices();
  
  if (affectedServices.length > 0) {
    await builder.buildAndPush(affectedServices);
  } else {
    console.log('🎉 No services affected, skipping build');
  }
}

if (require.main === module) {
  main().catch(console.error);
}
```

## Kubernetes Deployment

### Helm Charts for Service Deployment

```yaml
# helm/expense-tracker/templates/api-gateway.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "expense-tracker.fullname" . }}-api-gateway
  labels:
    {{- include "expense-tracker.labels" . | nindent 4 }}
    app.kubernetes.io/component: api-gateway
spec:
  replicas: {{ .Values.apiGateway.replicas }}
  selector:
    matchLabels:
      {{- include "expense-tracker.selectorLabels" . | nindent 6 }}
      app.kubernetes.io/component: api-gateway
  template:
    metadata:
      labels:
        {{- include "expense-tracker.selectorLabels" . | nindent 8 }}
        app.kubernetes.io/component: api-gateway
    spec:
      containers:
        - name: api-gateway
          image: "{{ .Values.apiGateway.image.repository }}:{{ .Values.apiGateway.image.tag }}"
          imagePullPolicy: {{ .Values.apiGateway.image.pullPolicy }}
          ports:
            - name: http
              containerPort: 3000
              protocol: TCP
          env:
            - name: NODE_ENV
              value: {{ .Values.environment }}
            - name: USER_SERVICE_URL
              value: "http://{{ include "expense-tracker.fullname" . }}-user-service:3001"
            - name: EXPENSE_SERVICE_URL
              value: "http://{{ include "expense-tracker.fullname" . }}-expense-service:3002"
            - name: REDIS_URL
              valueFrom:
                secretKeyRef:
                  name: {{ include "expense-tracker.fullname" . }}-secrets
                  key: redis-url
            - name: JWT_SECRET
              valueFrom:
                secretKeyRef:
                  name: {{ include "expense-tracker.fullname" . }}-secrets
                  key: jwt-secret
          livenessProbe:
            httpGet:
              path: /health
              port: http
            initialDelaySeconds: 30
            periodSeconds: 10
          readinessProbe:
            httpGet:
              path: /health
              port: http
            initialDelaySeconds: 5
            periodSeconds: 5
          resources:
            {{- toYaml .Values.apiGateway.resources | nindent 12 }}

---
apiVersion: v1
kind: Service
metadata:
  name: {{ include "expense-tracker.fullname" . }}-api-gateway
  labels:
    {{- include "expense-tracker.labels" . | nindent 4 }}
    app.kubernetes.io/component: api-gateway
spec:
  type: {{ .Values.apiGateway.service.type }}
  ports:
    - port: {{ .Values.apiGateway.service.port }}
      targetPort: http
      protocol: TCP
      name: http
  selector:
    {{- include "expense-tracker.selectorLabels" . | nindent 4 }}
    app.kubernetes.io/component: api-gateway
```

```yaml
# helm/expense-tracker/values.yaml
nameOverride: ""
fullnameOverride: ""

environment: production

apiGateway:
  replicas: 3
  image:
    repository: expense-tracker/api-gateway
    tag: latest
    pullPolicy: IfNotPresent
  service:
    type: ClusterIP
    port: 3000
  resources:
    limits:
      cpu: 1000m
      memory: 2Gi
    requests:
      cpu: 500m
      memory: 1Gi
  autoscaling:
    enabled: true
    minReplicas: 3
    maxReplicas: 10
    targetCPUUtilizationPercentage: 70

userService:
  replicas: 3
  image:
    repository: expense-tracker/user-service
    tag: latest
    pullPolicy: IfNotPresent
  service:
    type: ClusterIP
    port: 3001
  resources:
    limits:
      cpu: 1000m
      memory: 2Gi
    requests:
      cpu: 500m
      memory: 1Gi

expenseService:
  replicas: 3
  image:
    repository: expense-tracker/expense-service
    tag: latest
    pullPolicy: IfNotPresent
  service:
    type: ClusterIP
    port: 3002
  resources:
    limits:
      cpu: 1000m
      memory: 2Gi
    requests:
      cpu: 500m
      memory: 1Gi

ingress:
  enabled: true
  className: "nginx"
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/rate-limit: "100"
  hosts:
    - host: api.expense-tracker.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: expense-tracker-tls
      hosts:
        - api.expense-tracker.com

database:
  enabled: true
  type: mongodb
  connectionString: ""  # Set via secret

redis:
  enabled: true
  auth:
    enabled: true
    password: ""  # Set via secret

monitoring:
  enabled: true
  prometheus:
    enabled: true
  grafana:
    enabled: true
```

## Blue-Green Deployment Strategy

### Blue-Green Deployment Script

```typescript
// tools/scripts/blue-green-deploy.ts
import { execSync } from 'child_process';

interface DeploymentConfig {
  environment: string;
  services: string[];
  healthCheckTimeout: number;
  rollbackOnFailure: boolean;
}

export class BlueGreenDeployment {
  constructor(private config: DeploymentConfig) {}

  async deploy(): Promise<void> {
    console.log(`🔄 Starting blue-green deployment for ${this.config.environment}...`);

    try {
      // Step 1: Deploy to green environment
      await this.deployToGreen();

      // Step 2: Run health checks
      await this.runHealthChecks();

      // Step 3: Run smoke tests
      await this.runSmokeTests();

      // Step 4: Switch traffic to green
      await this.switchTraffic();

      // Step 5: Monitor for issues
      await this.monitorDeployment();

      // Step 6: Cleanup blue environment
      await this.cleanupBlue();

      console.log('✅ Blue-green deployment completed successfully!');
    } catch (error) {
      console.error('❌ Deployment failed:', error);
      
      if (this.config.rollbackOnFailure) {
        await this.rollback();
      }
      
      throw error;
    }
  }

  private async deployToGreen(): Promise<void> {
    console.log('🟢 Deploying to green environment...');
    
    // Update Kubernetes deployment with new image tags
    for (const service of this.config.services) {
      const deploymentName = `${service}-green`;
      const imageName = `expense-tracker/${service}:${process.env.BUILD_NUMBER}`;
      
      execSync(`kubectl set image deployment/${deploymentName} ${service}=${imageName}`, {
        stdio: 'inherit'
      });
      
      // Wait for rollout to complete
      execSync(`kubectl rollout status deployment/${deploymentName} --timeout=300s`, {
        stdio: 'inherit'
      });
    }
  }

  private async runHealthChecks(): Promise<void> {
    console.log('🏥 Running health checks...');
    
    const healthCheckPromises = this.config.services.map(async (service) => {
      const healthUrl = `http://${service}-green-service:3000/health`;
      
      for (let i = 0; i < 30; i++) {
        try {
          const response = await fetch(healthUrl);
          if (response.ok) {
            console.log(`✅ Health check passed for ${service}`);
            return;
          }
        } catch (error) {
          console.log(`⏳ Waiting for ${service} to be healthy... (${i + 1}/30)`);
          await new Promise(resolve => setTimeout(resolve, 10000)); // Wait 10 seconds
        }
      }
      
      throw new Error(`Health check failed for ${service}`);
    });

    await Promise.all(healthCheckPromises);
  }

  private async runSmokeTests(): Promise<void> {
    console.log('🧪 Running smoke tests...');
    
    try {
      execSync('npm run test:smoke:green', { stdio: 'inherit' });
    } catch (error) {
      throw new Error('Smoke tests failed');
    }
  }

  private async switchTraffic(): Promise<void> {
    console.log('🔀 Switching traffic to green environment...');
    
    // Update ingress to point to green services
    execSync(`kubectl patch ingress expense-tracker-ingress -p '{"spec":{"rules":[{"host":"api.expense-tracker.com","http":{"paths":[{"path":"/","pathType":"Prefix","backend":{"service":{"name":"api-gateway-green-service","port":{"number":3000}}}}]}}]}}'`, {
      stdio: 'inherit'
    });
    
    // Wait for ingress update to propagate
    await new Promise(resolve => setTimeout(resolve, 30000));
  }

  private async monitorDeployment(): Promise<void> {
    console.log('📊 Monitoring deployment for 5 minutes...');
    
    // Monitor error rates, response times, etc.
    for (let i = 0; i < 30; i++) {
      try {
        const response = await fetch('https://api.expense-tracker.com/health');
        if (!response.ok) {
          throw new Error(`Health check failed with status: ${response.status}`);
        }
        
        console.log(`✅ Monitoring check ${i + 1}/30 passed`);
        await new Promise(resolve => setTimeout(resolve, 10000));
      } catch (error) {
        throw new Error(`Monitoring failed: ${error.message}`);
      }
    }
  }

  private async cleanupBlue(): Promise<void> {
    console.log('🧹 Cleaning up blue environment...');
    
    // Scale down blue deployments
    for (const service of this.config.services) {
      execSync(`kubectl scale deployment ${service}-blue --replicas=0`, {
        stdio: 'inherit'
      });
    }
  }

  private async rollback(): Promise<void> {
    console.log('🔙 Rolling back to blue environment...');
    
    // Switch traffic back to blue
    execSync(`kubectl patch ingress expense-tracker-ingress -p '{"spec":{"rules":[{"host":"api.expense-tracker.com","http":{"paths":[{"path":"/","pathType":"Prefix","backend":{"service":{"name":"api-gateway-blue-service","port":{"number":3000}}}}]}}]}}'`, {
      stdio: 'inherit'
    });
    
    // Scale up blue deployments
    for (const service of this.config.services) {
      execSync(`kubectl scale deployment ${service}-blue --replicas=3`, {
        stdio: 'inherit'
      });
    }
    
    console.log('✅ Rollback completed');
  }
}

// Usage
async function main() {
  const deployment = new BlueGreenDeployment({
    environment: process.env.ENVIRONMENT || 'production',
    services: ['api-gateway', 'user-service', 'expense-service'],
    healthCheckTimeout: 300000, // 5 minutes
    rollbackOnFailure: true
  });

  await deployment.deploy();
}

if (require.main === module) {
  main().catch(console.error);
}
```

## Serverless Deployment (AWS Lambda)

### SAM Template for Lambda Functions

```yaml
# template.yaml
AWSTemplateFormatVersion: '2010-09-09'
Transform: AWS::Serverless-2016-10-31
Description: Expense Tracker Lambda Functions

Globals:
  Function:
    Timeout: 30
    MemorySize: 1024
    Runtime: nodejs18.x
    Environment:
      Variables:
        NODE_ENV: !Ref Environment
        
Parameters:
  Environment:
    Type: String
    Default: production
    AllowedValues: [development, staging, production]

Resources:
  ExpenseProcessorFunction:
    Type: AWS::Serverless::Function
    Properties:
      CodeUri: dist/apps/lambda-functions/expense-processor/
      Handler: handler.handler
      Events:
        Api:
          Type: Api
          Properties:
            Path: /process-expense
            Method: post
            RestApiId: !Ref ExpenseTrackerApi
      Environment:
        Variables:
          DATABASE_URL: !Ref DatabaseUrl
          
  ReportGeneratorFunction:
    Type: AWS::Serverless::Function
    Properties:
      CodeUri: dist/apps/lambda-functions/report-generator/
      Handler: scheduled-handler.monthlyReportHandler
      Events:
        MonthlyReport:
          Type: Schedule
          Properties:
            Schedule: cron(0 8 1 * ? *)  # First day of every month at 8 AM
            
  DataSyncFunction:
    Type: AWS::Serverless::Function
    Properties:
      CodeUri: dist/apps/lambda-functions/data-sync/
      Handler: handler.handler
      Events:
        DynamoDBEvent:
          Type: DynamoDB
          Properties:
            Stream: !GetAtt ExpenseTable.StreamArn
            StartingPosition: TRIM_HORIZON

  ExpenseTrackerApi:
    Type: AWS::Serverless::Api
    Properties:
      StageName: !Ref Environment
      Cors:
        AllowMethods: "'GET,POST,PUT,DELETE,OPTIONS'"
        AllowHeaders: "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
        AllowOrigin: "'*'"

  ExpenseTable:
    Type: AWS::DynamoDB::Table
    Properties:
      TableName: !Sub "${Environment}-expenses"
      BillingMode: PAY_PER_REQUEST
      StreamSpecification:
        StreamViewType: NEW_AND_OLD_IMAGES
      AttributeDefinitions:
        - AttributeName: userId
          AttributeType: S
        - AttributeName: expenseId
          AttributeType: S
      KeySchema:
        - AttributeName: userId
          KeyType: HASH
        - AttributeName: expenseId
          KeyType: RANGE

Outputs:
  ExpenseTrackerApiUrl:
    Description: "API Gateway endpoint URL"
    Value: !Sub "https://${ExpenseTrackerApi}.execute-api.${AWS::Region}.amazonaws.com/${Environment}/"
    
  ExpenseProcessorFunctionArn:
    Description: "Expense Processor Lambda Function ARN"
    Value: !GetAtt ExpenseProcessorFunction.Arn
```

### Lambda Deployment Script

```typescript
// tools/scripts/deploy-lambda.ts
import { execSync } from 'child_process';
import { readFileSync, writeFileSync } from 'fs';

export class LambdaDeployment {
  private functions = [
    'expense-processor',
    'report-generator', 
    'data-sync',
    'scheduled-tasks'
  ];

  async deploy(environment: string = 'production'): Promise<void> {
    console.log(`🚀 Deploying Lambda functions to ${environment}...`);

    try {
      // Build Lambda functions
      await this.buildFunctions();

      // Package functions
      await this.packageFunctions();

      // Deploy with SAM
      await this.deploySAM(environment);

      console.log('✅ Lambda deployment completed successfully!');
    } catch (error) {
      console.error('❌ Lambda deployment failed:', error);
      throw error;
    }
  }

  private async buildFunctions(): Promise<void> {
    console.log('🔨 Building Lambda functions...');
    
    for (const func of this.functions) {
      execSync(`npx nx build lambda-${func} --configuration=production`, {
        stdio: 'inherit'
      });
    }
  }

  private async packageFunctions(): Promise<void> {
    console.log('📦 Packaging Lambda functions...');
    
    // Create deployment package
    execSync('sam build --template-file template.yaml', {
      stdio: 'inherit'
    });
  }

  private async deploySAM(environment: string): Promise<void> {
    console.log(`🚢 Deploying SAM stack to ${environment}...`);
    
    const stackName = `expense-tracker-${environment}`;
    
    execSync(`sam deploy --stack-name ${stackName} --parameter-overrides Environment=${environment} --capabilities CAPABILITY_IAM --no-confirm-changeset`, {
      stdio: 'inherit'
    });
  }

  async getAffectedLambdas(): Promise<string[]> {
    try {
      const output = execSync('npx nx print-affected --type=app --select=projects', { 
        encoding: 'utf8' 
      });
      
      return output
        .split('\n')
        .filter(line => line.trim())
        .filter(project => project.startsWith('lambda-'))
        .map(project => project.replace('lambda-', ''));
    } catch (error) {
      console.warn('Could not determine affected Lambda functions, deploying all');
      return this.functions;
    }
  }
}
```

## Frontend Deployment (PWA & Mobile)

### Static Site Deployment

```typescript
// tools/scripts/deploy-frontend.ts
import { execSync } from 'child_process';
import AWS from 'aws-sdk';

export class FrontendDeployment {
  private s3 = new AWS.S3();
  private cloudfront = new AWS.CloudFront();

  async deployWebPWA(environment: string): Promise<void> {
    console.log(`🌐 Deploying Web PWA to ${environment}...`);

    try {
      // Build PWA
      execSync(`npx nx build web-pwa --configuration=${environment}`, {
        stdio: 'inherit'
      });

      // Deploy to S3
      await this.deployToS3('web-pwa', environment);

      // Invalidate CloudFront cache
      await this.invalidateCloudFront(environment);

      console.log('✅ Web PWA deployment completed!');
    } catch (error) {
      console.error('❌ Web PWA deployment failed:', error);
      throw error;
    }
  }

  async deployMobileApp(): Promise<void> {
    console.log('📱 Deploying Mobile App...');

    try {
      // Build for production
      execSync('npx nx build mobile --configuration=production', {
        stdio: 'inherit'
      });

      // Deploy to Expo
      execSync('npx nx run mobile:submit --platform=all', {
        stdio: 'inherit'
      });

      console.log('✅ Mobile app deployment completed!');
    } catch (error) {
      console.error('❌ Mobile app deployment failed:', error);
      throw error;
    }
  }

  private async deployToS3(app: string, environment: string): Promise<void> {
    const bucketName = `expense-tracker-${app}-${environment}`;
    
    execSync(`aws s3 sync dist/apps/${app} s3://${bucketName} --delete --cache-control max-age=31536000,public`, {
      stdio: 'inherit'
    });

    // Set cache control for index.html
    execSync(`aws s3 cp dist/apps/${app}/index.html s3://${bucketName}/index.html --cache-control max-age=0,no-cache,no-store,must-revalidate`, {
      stdio: 'inherit'
    });
  }

  private async invalidateCloudFront(environment: string): Promise<void> {
    const distributionId = process.env[`CLOUDFRONT_DISTRIBUTION_ID_${environment.toUpperCase()}`];
    
    if (!distributionId) {
      console.warn('CloudFront distribution ID not found, skipping invalidation');
      return;
    }

    const params = {
      DistributionId: distributionId,
      InvalidationBatch: {
        Paths: {
          Quantity: 1,
          Items: ['/*']
        },
        CallerReference: `deployment-${Date.now()}`
      }
    };

    await this.cloudfront.createInvalidation(params).promise();
    console.log('✅ CloudFront cache invalidated');
  }
}
```

## Monitoring and Rollback

### Deployment Monitoring

```typescript
// tools/scripts/deployment-monitor.ts
export class DeploymentMonitor {
  async monitorDeployment(environment: string, duration: number = 600000): Promise<boolean> {
    console.log(`📊 Monitoring deployment for ${duration / 1000} seconds...`);

    const startTime = Date.now();
    const endTime = startTime + duration;

    while (Date.now() < endTime) {
      try {
        // Check service health
        const healthOk = await this.checkServiceHealth(environment);
        
        // Check error rates
        const errorRatesOk = await this.checkErrorRates(environment);
        
        // Check response times
        const responseTimesOk = await this.checkResponseTimes(environment);

        if (!healthOk || !errorRatesOk || !responseTimesOk) {
          console.error('❌ Deployment monitoring failed');
          return false;
        }

        console.log('✅ Monitoring check passed');
        await new Promise(resolve => setTimeout(resolve, 30000)); // Check every 30 seconds
      } catch (error) {
        console.error('❌ Monitoring error:', error);
        return false;
      }
    }

    console.log('✅ Deployment monitoring completed successfully');
    return true;
  }

  private async checkServiceHealth(environment: string): Promise<boolean> {
    const services = ['api-gateway', 'user-service', 'expense-service'];
    
    for (const service of services) {
      const healthUrl = `https://api.expense-tracker.com/health`;
      try {
        const response = await fetch(healthUrl);
        if (!response.ok) {
          console.error(`❌ Health check failed for ${service}: ${response.status}`);
          return false;
        }
      } catch (error) {
        console.error(`❌ Health check error for ${service}:`, error);
        return false;
      }
    }
    
    return true;
  }

  private async checkErrorRates(environment: string): Promise<boolean> {
    // Implementation would check CloudWatch metrics, Prometheus, etc.
    // For example purposes, we'll simulate a check
    console.log('📈 Checking error rates...');
    return true;
  }

  private async checkResponseTimes(environment: string): Promise<boolean> {
    // Implementation would check response time metrics
    console.log('⏱️ Checking response times...');
    return true;
  }
}
```

This comprehensive deployment strategy ensures reliable, scalable, and monitorable deployments across all environments while providing quick rollback capabilities and zero-downtime deployments for your monorepo architecture.
