# Hands-On Experience Guide: Practical AWS Labs for Certification Success

## Overview

This comprehensive guide provides practical, hands-on exercises designed specifically for Full Stack Engineers pursuing AWS certifications. Each lab builds upon previous knowledge while introducing new concepts through real-world scenarios relevant to startup environments and DevOps practices.

## Hands-On Learning Philosophy

### 🎯 Learning by Building Approach

**70/30 Practical Focus**: 70% hands-on implementation, 30% theoretical knowledge
- **Build Real Solutions**: Create functional applications and infrastructure
- **Learn Through Troubleshooting**: Develop problem-solving skills through debugging
- **Document Everything**: Maintain detailed notes for future reference
- **Iterate and Improve**: Continuously enhance projects with new knowledge

**Progressive Complexity**: Each phase builds upon previous learning
- **Foundation Projects**: Simple, single-service implementations
- **Integration Projects**: Multi-service architectures
- **Advanced Projects**: Production-ready, enterprise-grade solutions

### 🔧 Lab Environment Setup

**Required Tools and Accounts:**
- AWS Free Tier account with billing alerts configured
- AWS CLI installed and configured
- Code editor (VS Code recommended) with AWS extensions
- Git repository for project version control
- Local Docker installation for container exercises

**Cost Management Strategy:**
- Utilize AWS Free Tier limits effectively
- Set up billing alerts at $5, $10, and $20 thresholds
- Clean up resources immediately after lab completion
- Use AWS Cost Calculator for project estimation

## Phase 1: Cloud Practitioner Hands-On Labs (Weeks 1-6)

### 🏗️ Lab 1.1: AWS Account Setup and Basic Services Exploration

**Objective**: Familiarize with AWS Console and basic service interactions

**Duration**: 3-4 hours over Week 1

**Prerequisites**: AWS account creation

**Step-by-Step Implementation:**

1. **Account Configuration (45 minutes)**
   ```bash
   # Configure AWS CLI
   aws configure
   # Set up MFA for root account
   # Create IAM user with appropriate permissions
   # Configure billing alerts and budgets
   ```

2. **S3 Bucket Operations (60 minutes)**
   ```bash
   # Create S3 bucket
   aws s3 mb s3://your-unique-bucket-name-learning
   
   # Upload files with different storage classes
   aws s3 cp local-file.txt s3://your-bucket/standard/
   aws s3 cp large-file.zip s3://your-bucket/ia/ --storage-class STANDARD_IA
   
   # Configure bucket versioning and lifecycle policies
   aws s3api put-bucket-versioning --bucket your-bucket --versioning-configuration Status=Enabled
   ```

3. **EC2 Instance Management (90 minutes)**
   ```bash
   # Launch EC2 instance
   aws ec2 run-instances --image-id ami-0abcdef1234567890 --count 1 --instance-type t2.micro --key-name MyKeyPair
   
   # Connect to instance
   ssh -i MyKeyPair.pem ec2-user@public-ip
   
   # Install basic web server
   sudo yum update -y
   sudo yum install -y httpd
   sudo systemctl start httpd
   sudo systemctl enable httpd
   ```

4. **Basic VPC Exploration (45 minutes)**
   - Navigate VPC console and understand default VPC
   - Explore subnets, route tables, and internet gateways
   - Review security groups and NACLs

**Deliverables:**
- [ ] Functional S3 bucket with versioning and lifecycle policies
- [ ] Running EC2 instance with web server
- [ ] Documentation of AWS console navigation
- [ ] Cost analysis of resources used

**Learning Outcomes:**
- Understand AWS service interaction patterns
- Gain familiarity with AWS CLI and console
- Establish cost management practices
- Build confidence with basic AWS operations

### 🗄️ Lab 1.2: Database Services and Basic Architecture

**Objective**: Implement database solutions and understand service integration

**Duration**: 4-5 hours over Week 2

**Prerequisites**: Completion of Lab 1.1

**Architecture Overview:**
```
[Web Server (EC2)] --> [RDS MySQL Database]
         |
         v
[S3 Static Content Storage]
```

**Implementation Steps:**

1. **RDS Database Setup (90 minutes)**
   ```bash
   # Create RDS MySQL instance
   aws rds create-db-instance \
       --db-instance-identifier myapp-database \
       --db-instance-class db.t3.micro \
       --engine mysql \
       --master-username admin \
       --master-user-password mypassword123 \
       --allocated-storage 20 \
       --vpc-security-group-ids sg-12345678
   ```

2. **Database Connection from EC2 (60 minutes)**
   ```bash
   # Install MySQL client on EC2
   sudo yum install -y mysql
   
   # Connect to RDS database
   mysql -h myapp-database.123456789.us-west-2.rds.amazonaws.com -u admin -p
   
   # Create sample database and tables
   CREATE DATABASE myapp;
   USE myapp;
   CREATE TABLE users (id INT PRIMARY KEY, name VARCHAR(50), email VARCHAR(100));
   INSERT INTO users VALUES (1, 'John Doe', 'john@example.com');
   ```

3. **Simple Web Application (120 minutes)**
   ```php
   <?php
   // Simple PHP application connecting to RDS
   $servername = "myapp-database.123456789.us-west-2.rds.amazonaws.com";
   $username = "admin";
   $password = "mypassword123";
   $dbname = "myapp";

   $conn = new mysqli($servername, $username, $password, $dbname);
   
   if ($conn->connect_error) {
       die("Connection failed: " . $conn->connect_error);
   }
   
   $sql = "SELECT id, name, email FROM users";
   $result = $conn->query($sql);
   
   while($row = $result->fetch_assoc()) {
       echo "ID: " . $row["id"]. " - Name: " . $row["name"]. " - Email: " . $row["email"]. "<br>";
   }
   $conn->close();
   ?>
   ```

4. **Static Content on S3 (60 minutes)**
   - Upload CSS, JavaScript, and image files to S3
   - Configure S3 bucket for static website hosting
   - Update web application to reference S3-hosted static content

**Deliverables:**
- [ ] Functional RDS MySQL database
- [ ] Web application connecting to database
- [ ] Static content served from S3
- [ ] Architecture diagram of the solution

**Learning Outcomes:**
- Understand database service configuration
- Learn service-to-service communication patterns
- Practice basic web application deployment
- Understand separation of static and dynamic content

### 🌐 Lab 1.3: Networking and Security Implementation

**Objective**: Configure VPC networking and implement security best practices

**Duration**: 5-6 hours over Week 3-4

**Prerequisites**: Completion of previous labs

**Architecture Enhancement:**
```
Internet Gateway
       |
[Public Subnet - Web Servers]
       |
   NAT Gateway
       |
[Private Subnet - Database Servers]
```

**Implementation Steps:**

1. **Custom VPC Creation (90 minutes)**
   ```bash
   # Create VPC
   aws ec2 create-vpc --cidr-block 10.0.0.0/16
   
   # Create subnets
   aws ec2 create-subnet --vpc-id vpc-12345678 --cidr-block 10.0.1.0/24 # Public
   aws ec2 create-subnet --vpc-id vpc-12345678 --cidr-block 10.0.2.0/24 # Private
   
   # Create and attach Internet Gateway
   aws ec2 create-internet-gateway
   aws ec2 attach-internet-gateway --vpc-id vpc-12345678 --internet-gateway-id igw-12345678
   ```

2. **NAT Gateway Configuration (60 minutes)**
   ```bash
   # Allocate Elastic IP for NAT Gateway
   aws ec2 allocate-address --domain vpc
   
   # Create NAT Gateway
   aws ec2 create-nat-gateway --subnet-id subnet-12345678 --allocation-id eipalloc-12345678
   ```

3. **Route Table Configuration (45 minutes)**
   ```bash
   # Create route tables
   aws ec2 create-route-table --vpc-id vpc-12345678
   
   # Add routes
   aws ec2 create-route --route-table-id rtb-12345678 --destination-cidr-block 0.0.0.0/0 --gateway-id igw-12345678
   
   # Associate subnets with route tables
   aws ec2 associate-route-table --subnet-id subnet-12345678 --route-table-id rtb-12345678
   ```

4. **Security Group Implementation (90 minutes)**
   ```bash
   # Create security groups
   aws ec2 create-security-group --group-name web-servers --description "Web servers security group" --vpc-id vpc-12345678
   
   # Add security group rules
   aws ec2 authorize-security-group-ingress --group-id sg-12345678 --protocol tcp --port 80 --cidr 0.0.0.0/0
   aws ec2 authorize-security-group-ingress --group-id sg-12345678 --protocol tcp --port 443 --cidr 0.0.0.0/0
   aws ec2 authorize-security-group-ingress --group-id sg-12345678 --protocol tcp --port 22 --cidr 10.0.0.0/16
   ```

5. **Application Migration (120 minutes)**
   - Migrate EC2 instances to new VPC architecture
   - Move RDS to private subnet
   - Test connectivity and functionality
   - Validate security group restrictions

**Deliverables:**
- [ ] Custom VPC with public/private subnet architecture
- [ ] NAT Gateway for private subnet internet access
- [ ] Properly configured security groups
- [ ] Migrated application with enhanced security

**Learning Outcomes:**
- Master VPC networking concepts
- Understand public vs. private subnet patterns
- Implement defense-in-depth security strategies
- Practice infrastructure migration techniques

## Phase 2: Solutions Architect Associate Labs (Weeks 7-18)

### 🏗️ Lab 2.1: High Availability Web Application

**Objective**: Design and implement a highly available, scalable web application

**Duration**: 8-10 hours over Weeks 7-9

**Target Architecture:**
```
[Route 53] --> [CloudFront CDN] --> [Application Load Balancer]
                                            |
                        [Auto Scaling Group - Multiple AZs]
                        |                               |
                [EC2 - AZ-1a]                   [EC2 - AZ-1b]
                        |                               |
                        +----------- RDS (Multi-AZ) ---+
```

**Implementation Phases:**

**Phase 1: Load Balancing and Auto Scaling (4 hours)**

1. **Application Load Balancer Setup**
   ```bash
   # Create Application Load Balancer
   aws elbv2 create-load-balancer \
       --name my-app-alb \
       --subnets subnet-12345678 subnet-87654321 \
       --security-groups sg-12345678
   
   # Create target group
   aws elbv2 create-target-group \
       --name my-app-targets \
       --protocol HTTP \
       --port 80 \
       --vpc-id vpc-12345678 \
       --health-check-path /health
   ```

2. **Auto Scaling Group Configuration**
   ```bash
   # Create launch template
   aws ec2 create-launch-template \
       --launch-template-name my-app-template \
       --launch-template-data file://launch-template.json
   
   # Create Auto Scaling Group
   aws autoscaling create-auto-scaling-group \
       --auto-scaling-group-name my-app-asg \
       --launch-template LaunchTemplateName=my-app-template,Version=1 \
       --min-size 2 \
       --max-size 6 \
       --desired-capacity 2 \
       --target-group-arns arn:aws:elasticloadbalancing:region:account:targetgroup/my-app-targets/1234567890123456 \
       --vpc-zone-identifier "subnet-12345678,subnet-87654321"
   ```

**Phase 2: Database High Availability (2 hours)**

3. **RDS Multi-AZ Configuration**
   ```bash
   # Modify RDS for Multi-AZ deployment
   aws rds modify-db-instance \
       --db-instance-identifier myapp-database \
       --multi-az \
       --apply-immediately
   
   # Create read replica for read scaling
   aws rds create-db-instance-read-replica \
       --db-instance-identifier myapp-read-replica \
       --source-db-instance-identifier myapp-database
   ```

**Phase 3: Content Delivery and DNS (2 hours)**

4. **CloudFront Distribution Setup**
   ```json
   {
     "CallerReference": "my-app-distribution-2023",
     "Comment": "My App CDN Distribution",
     "Origins": {
       "Quantity": 1,
       "Items": [{
         "Id": "my-app-origin",
         "DomainName": "my-app-alb-123456789.us-west-2.elb.amazonaws.com",
         "CustomOriginConfig": {
           "HTTPPort": 80,
           "HTTPSPort": 443,
           "OriginProtocolPolicy": "http-only"
         }
       }]
     },
     "DefaultCacheBehavior": {
       "TargetOriginId": "my-app-origin",
       "ViewerProtocolPolicy": "redirect-to-https"
     }
   }
   ```

5. **Route 53 DNS Configuration**
   ```bash
   # Create hosted zone
   aws route53 create-hosted-zone \
       --name myapp.example.com \
       --caller-reference $(date +%s)
   
   # Create alias record to CloudFront
   aws route53 change-resource-record-sets \
       --hosted-zone-id Z123456789 \
       --change-batch file://route53-changeset.json
   ```

**Testing and Validation (2 hours)**
- Load testing with Apache Bench or similar
- Failure testing by stopping instances
- Performance monitoring setup
- Cost analysis and optimization

**Deliverables:**
- [ ] Multi-AZ, auto-scaling web application
- [ ] Application Load Balancer with health checks
- [ ] CloudFront CDN distribution
- [ ] Route 53 DNS configuration
- [ ] Comprehensive monitoring dashboard
- [ ] Performance and availability test results

### 🔧 Lab 2.2: Infrastructure as Code with CloudFormation

**Objective**: Automate infrastructure deployment using CloudFormation templates

**Duration**: 6-8 hours over Weeks 10-12

**Template Structure:**
```yaml
# VPC and Networking Stack
# Application Stack
# Database Stack
# Monitoring Stack
```

**Implementation Approach:**

1. **Modular Template Design (2 hours)**
   ```yaml
   # vpc-template.yaml
   AWSTemplateFormatVersion: '2010-09-09'
   Description: 'VPC with public and private subnets'
   
   Parameters:
     Environment:
       Type: String
       Default: dev
       AllowedValues: [dev, staging, prod]
   
   Resources:
     VPC:
       Type: AWS::EC2::VPC
       Properties:
         CidrBlock: 10.0.0.0/16
         EnableDnsHostnames: true
         EnableDnsSupport: true
         Tags:
           - Key: Name
             Value: !Sub ${Environment}-vpc
   
   Outputs:
     VPCId:
       Description: VPC ID
       Value: !Ref VPC
       Export:
         Name: !Sub ${Environment}-vpc-id
   ```

2. **Application Stack Template (3 hours)**
   ```yaml
   # app-template.yaml
   Parameters:
     Environment:
       Type: String
     InstanceType:
       Type: String
       Default: t3.micro
   
   Resources:
     LaunchTemplate:
       Type: AWS::EC2::LaunchTemplate
       Properties:
         LaunchTemplateName: !Sub ${Environment}-app-template
         LaunchTemplateData:
           ImageId: ami-0abcdef1234567890
           InstanceType: !Ref InstanceType
           SecurityGroupIds:
             - !Ref WebServerSecurityGroup
           UserData:
             Fn::Base64: !Sub |
               #!/bin/bash
               yum update -y
               yum install -y httpd php mysql
               systemctl start httpd
               systemctl enable httpd
   
     AutoScalingGroup:
       Type: AWS::AutoScaling::AutoScalingGroup
       Properties:
         AutoScalingGroupName: !Sub ${Environment}-asg
         LaunchTemplate:
           LaunchTemplateId: !Ref LaunchTemplate
           Version: !GetAtt LaunchTemplate.LatestVersionNumber
         MinSize: 2
         MaxSize: 6
         DesiredCapacity: 2
         VPCZoneIdentifier:
           - Fn::ImportValue: !Sub ${Environment}-private-subnet-1
           - Fn::ImportValue: !Sub ${Environment}-private-subnet-2
   ```

3. **Database Stack Template (2 hours)**
   ```yaml
   # database-template.yaml
   Resources:
     DBSubnetGroup:
       Type: AWS::RDS::DBSubnetGroup
       Properties:
         DBSubnetGroupDescription: Subnet group for RDS database
         SubnetIds:
           - Fn::ImportValue: !Sub ${Environment}-private-subnet-1
           - Fn::ImportValue: !Sub ${Environment}-private-subnet-2
   
     Database:
       Type: AWS::RDS::DBInstance
       Properties:
         DBInstanceIdentifier: !Sub ${Environment}-database
         DBInstanceClass: db.t3.micro
         Engine: mysql
         MasterUsername: admin
         MasterUserPassword: !Ref DatabasePassword
         AllocatedStorage: 20
         MultiAZ: true
         DBSubnetGroupName: !Ref DBSubnetGroup
         VPCSecurityGroups:
           - !Ref DatabaseSecurityGroup
   ```

4. **Stack Deployment Automation (1 hour)**
   ```bash
   #!/bin/bash
   # deploy-stack.sh
   
   ENVIRONMENT=$1
   STACK_NAME="myapp-${ENVIRONMENT}"
   
   # Deploy VPC stack
   aws cloudformation deploy \
       --template-file vpc-template.yaml \
       --stack-name ${STACK_NAME}-vpc \
       --parameter-overrides Environment=${ENVIRONMENT}
   
   # Deploy application stack
   aws cloudformation deploy \
       --template-file app-template.yaml \
       --stack-name ${STACK_NAME}-app \
       --parameter-overrides Environment=${ENVIRONMENT} \
       --capabilities CAPABILITY_IAM
   
   # Deploy database stack
   aws cloudformation deploy \
       --template-file database-template.yaml \
       --stack-name ${STACK_NAME}-db \
       --parameter-overrides Environment=${ENVIRONMENT}
   ```

**Deliverables:**
- [ ] Modular CloudFormation templates
- [ ] Automated deployment scripts
- [ ] Multi-environment deployment capability
- [ ] Stack dependency management
- [ ] Template validation and testing

### 🔍 Lab 2.3: Comprehensive Monitoring and Alerting

**Objective**: Implement comprehensive monitoring, logging, and alerting solutions

**Duration**: 4-6 hours over Weeks 13-15

**Monitoring Architecture:**
```
[Application] --> [CloudWatch Logs] --> [CloudWatch Insights]
      |                    |
      v                    v
[Custom Metrics] --> [CloudWatch Dashboards]
      |                    |
      v                    v
[CloudWatch Alarms] --> [SNS Topics] --> [Email/SMS/Slack]
```

**Implementation Steps:**

1. **Application Logging Setup (90 minutes)**
   ```bash
   # Install CloudWatch agent
   wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
   sudo rpm -U ./amazon-cloudwatch-agent.rpm
   
   # Configure CloudWatch agent
   sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-config-wizard
   ```

   ```json
   // cloudwatch-config.json
   {
     "logs": {
       "logs_collected": {
         "files": {
           "collect_list": [
             {
               "file_path": "/var/log/httpd/access_log",
               "log_group_name": "myapp-access-logs",
               "log_stream_name": "{instance_id}"
             },
             {
               "file_path": "/var/log/httpd/error_log",
               "log_group_name": "myapp-error-logs",
               "log_stream_name": "{instance_id}"
             }
           ]
         }
       }
     },
     "metrics": {
       "metrics_collected": {
         "cpu": {
           "measurement": ["cpu_usage_idle", "cpu_usage_iowait", "cpu_usage_user", "cpu_usage_system"]
         },
         "disk": {
           "measurement": ["used_percent"],
           "resources": ["*"]
         },
         "mem": {
           "measurement": ["mem_used_percent"]
         }
       }
     }
   }
   ```

2. **Custom Metrics Implementation (60 minutes)**
   ```python
   import boto3
   import time
   
   cloudwatch = boto3.client('cloudwatch')
   
   def send_custom_metric(metric_name, value, unit='Count'):
       cloudwatch.put_metric_data(
           Namespace='MyApp/Business',
           MetricData=[
               {
                   'MetricName': metric_name,
                   'Value': value,
                   'Unit': unit,
                   'Timestamp': time.time()
               }
           ]
       )
   
   # Example usage in application
   send_custom_metric('UserRegistrations', 1)
   send_custom_metric('PageViews', 1)
   send_custom_metric('ErrorRate', error_count / total_requests * 100, 'Percent')
   ```

3. **Dashboard Creation (90 minutes)**
   ```json
   {
     "widgets": [
       {
         "type": "metric",
         "properties": {
           "metrics": [
             ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", "app/my-app-alb/50dc6c495c0c9188"],
             [".", "TargetResponseTime", ".", "."],
             [".", "HTTPCode_Target_2XX_Count", ".", "."],
             [".", "HTTPCode_Target_4XX_Count", ".", "."],
             [".", "HTTPCode_Target_5XX_Count", ".", "."]
           ],
           "period": 300,
           "stat": "Sum",
           "region": "us-west-2",
           "title": "Application Load Balancer Metrics"
         }
       },
       {
         "type": "log",
         "properties": {
           "query": "SOURCE '/aws/rds/instance/myapp-database/error'\n| fields @timestamp, @message\n| filter @message like /ERROR/\n| sort @timestamp desc\n| limit 20",
           "region": "us-west-2",
           "title": "Database Errors"
         }
       }
     ]
   }
   ```

4. **Alerting Configuration (90 minutes)**
   ```bash
   # Create SNS topic
   aws sns create-topic --name myapp-alerts
   
   # Subscribe to topic
   aws sns subscribe \
       --topic-arn arn:aws:sns:us-west-2:123456789012:myapp-alerts \
       --protocol email \
       --notification-endpoint your-email@example.com
   
   # Create CloudWatch alarm
   aws cloudwatch put-metric-alarm \
       --alarm-name "High-CPU-Usage" \
       --alarm-description "Alarm when CPU exceeds 80%" \
       --metric-name CPUUtilization \
       --namespace AWS/EC2 \
       --statistic Average \
       --period 300 \
       --threshold 80 \
       --comparison-operator GreaterThanThreshold \
       --evaluation-periods 2 \
       --alarm-actions arn:aws:sns:us-west-2:123456789012:myapp-alerts
   ```

**Deliverables:**
- [ ] Comprehensive logging configuration
- [ ] Custom business metrics implementation
- [ ] Multi-layer monitoring dashboards
- [ ] Proactive alerting system
- [ ] Runbook for alert response procedures

## Phase 3: DevOps Professional Labs (Weeks 19-34)

### 🚀 Lab 3.1: Advanced CI/CD Pipeline Implementation

**Objective**: Build enterprise-grade CI/CD pipeline with multiple deployment strategies

**Duration**: 10-12 hours over Weeks 19-22

**Pipeline Architecture:**
```
[GitHub] --> [CodePipeline] --> [CodeBuild] --> [CodeDeploy]
                |                    |              |
                v                    v              v
        [Source Stage]      [Build & Test]    [Deploy Stages]
                                               |
                                         [Dev] --> [Staging] --> [Prod]
                                               |              |
                                         [Blue/Green]    [Canary]
```

**Implementation Phases:**

**Phase 1: Source and Build Configuration (3 hours)**

1. **CodeCommit Repository Setup**
   ```bash
   # Create CodeCommit repository
   aws codecommit create-repository \
       --repository-name myapp-source \
       --repository-description "Source code for MyApp"
   
   # Clone and set up repository
   git clone https://git-codecommit.us-west-2.amazonaws.com/v1/repos/myapp-source
   cd myapp-source
   
   # Add sample application with buildspec
   ```

2. **buildspec.yml Configuration**
   ```yaml
   version: 0.2
   
   phases:
     install:
       runtime-versions:
         nodejs: 14
       commands:
         - npm install
         - pip install pytest
         
     pre_build:
       commands:
         - echo Logging in to Amazon ECR...
         - aws ecr get-login-password --region $AWS_DEFAULT_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com
         
     build:
       commands:
         - echo Build started on `date`
         - echo Running unit tests
         - npm test
         - echo Building the Docker image...
         - docker build -t $IMAGE_REPO_NAME:$IMAGE_TAG .
         - docker tag $IMAGE_REPO_NAME:$IMAGE_TAG $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$IMAGE_REPO_NAME:$IMAGE_TAG
         
     post_build:
       commands:
         - echo Build completed on `date`
         - echo Pushing the Docker image...
         - docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$IMAGE_REPO_NAME:$IMAGE_TAG
         - printf '[{"name":"myapp-container","imageUri":"%s"}]' $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$IMAGE_REPO_NAME:$IMAGE_TAG > imagedefinitions.json
         
   artifacts:
     files:
       - imagedefinitions.json
       - appspec.yml
       - scripts/*
   ```

**Phase 2: Advanced Deployment Strategies (4 hours)**

3. **Blue/Green Deployment Configuration**
   ```yaml
   # appspec.yml for CodeDeploy
   version: 0.0
   Resources:
     - TargetService:
         Type: AWS::ECS::Service
         Properties:
           TaskDefinition: <TASK_DEFINITION>
           LoadBalancerInfo:
             ContainerName: "myapp-container"
             ContainerPort: 80
   
   Hooks:
     - BeforeInstall:
         - Location: "scripts/install_dependencies.sh"
           Timeout: 300
           Runas: root
     - ApplicationStart:
         - Location: "scripts/start_server.sh"
           Timeout: 300
           Runas: root
     - ApplicationStop:
         - Location: "scripts/stop_server.sh"
           Timeout: 300
           Runas: root
     - ValidateService:
         - Location: "scripts/validate_service.sh"
           Timeout: 300
   ```

4. **Canary Deployment Implementation**
   ```python
   # Lambda function for canary deployment validation
   import boto3
   import json
   
   def lambda_handler(event, context):
       codedeploy = boto3.client('codedeploy')
       cloudwatch = boto3.client('cloudwatch')
       
       # Get deployment ID from event
       deployment_id = event['DeploymentId']
       
       # Check key metrics during canary phase
       metrics = cloudwatch.get_metric_statistics(
           Namespace='AWS/ApplicationELB',
           MetricName='HTTPCode_Target_5XX_Count',
           StartTime=datetime.utcnow() - timedelta(minutes=10),
           EndTime=datetime.utcnow(),
           Period=300,
           Statistics=['Sum']
       )
       
       error_count = sum([point['Sum'] for point in metrics['Datapoints']])
       
       if error_count > 5:  # Threshold for errors
           # Stop deployment
           codedeploy.stop_deployment(
               deploymentId=deployment_id,
               autoRollbackEnabled=True
           )
           return {'status': 'FAILED', 'reason': 'High error rate detected'}
       
       return {'status': 'SUCCEEDED'}
   ```

**Phase 3: Pipeline Orchestration (3 hours)**

5. **CodePipeline Configuration**
   ```json
   {
     "pipeline": {
       "name": "myapp-pipeline",
       "roleArn": "arn:aws:iam::123456789012:role/service-role/AWSCodePipelineServiceRole",
       "stages": [
         {
           "name": "Source",
           "actions": [{
             "name": "Source",
             "actionTypeId": {
               "category": "Source",
               "owner": "AWS",
               "provider": "CodeCommit",
               "version": "1"
             },
             "configuration": {
               "RepositoryName": "myapp-source",
               "BranchName": "main"
             },
             "outputArtifacts": [{"name": "SourceOutput"}]
           }]
         },
         {
           "name": "Build",
           "actions": [{
             "name": "Build",
             "actionTypeId": {
               "category": "Build",
               "owner": "AWS",
               "provider": "CodeBuild",
               "version": "1"
             },
             "configuration": {
               "ProjectName": "myapp-build"
             },
             "inputArtifacts": [{"name": "SourceOutput"}],
             "outputArtifacts": [{"name": "BuildOutput"}]
           }]
         },
         {
           "name": "Deploy-Dev",
           "actions": [{
             "name": "Deploy",
             "actionTypeId": {
               "category": "Deploy",
               "owner": "AWS",
               "provider": "CodeDeployToECS",
               "version": "1"
             },
             "configuration": {
               "ApplicationName": "myapp-dev",
               "DeploymentGroupName": "myapp-dev-dg"
             },
             "inputArtifacts": [{"name": "BuildOutput"}]
           }]
         }
       ]
     }
   }
   ```

**Testing and Validation (2 hours)**
- End-to-end pipeline testing
- Deployment rollback scenarios
- Performance impact analysis
- Security scanning integration

**Deliverables:**
- [ ] Complete CI/CD pipeline with multiple environments
- [ ] Blue/green deployment capability
- [ ] Canary deployment with automated validation
- [ ] Comprehensive testing and rollback procedures
- [ ] Pipeline monitoring and alerting

### 🐳 Lab 3.2: Container Orchestration with EKS

**Objective**: Deploy and manage containerized applications using Amazon EKS

**Duration**: 8-10 hours over Weeks 27-30

**Container Architecture:**
```
[EKS Cluster] --> [Node Groups] --> [Pods]
      |               |              |
      v               v              v
[Load Balancer] [Auto Scaling]  [Microservices]
      |               |              |
      v               v              v
[Ingress Controller] [HPA] [Service Mesh (Istio)]
```

**Implementation Phases:**

**Phase 1: EKS Cluster Setup (3 hours)**

1. **Cluster Creation with eksctl**
   ```bash
   # Install eksctl
   curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
   sudo mv /tmp/eksctl /usr/local/bin
   
   # Create EKS cluster
   eksctl create cluster \
     --name myapp-cluster \
     --region us-west-2 \
     --nodegroup-name myapp-nodes \
     --node-type t3.medium \
     --nodes 3 \
     --nodes-min 1 \
     --nodes-max 4 \
     --ssh-access \
     --ssh-public-key mykey \
     --managed
   ```

2. **kubectl Configuration**
   ```bash
   # Update kubeconfig
   aws eks update-kubeconfig --region us-west-2 --name myapp-cluster
   
   # Verify cluster connectivity
   kubectl get nodes
   kubectl get pods --all-namespaces
   ```

**Phase 2: Application Deployment (3 hours)**

3. **Microservices Deployment**
   ```yaml
   # frontend-deployment.yaml
   apiVersion: apps/v1
   kind: Deployment
   metadata:
     name: frontend
   spec:
     replicas: 3
     selector:
       matchLabels:
         app: frontend
     template:
       metadata:
         labels:
           app: frontend
       spec:
         containers:
         - name: frontend
           image: your-account.dkr.ecr.us-west-2.amazonaws.com/myapp-frontend:latest
           ports:
           - containerPort: 80
           env:
           - name: API_ENDPOINT
             value: "http://backend-service:8080"
   
   ---
   apiVersion: v1
   kind: Service
   metadata:
     name: frontend-service
   spec:
     selector:
       app: frontend
     ports:
       - protocol: TCP
         port: 80
         targetPort: 80
     type: LoadBalancer
   ```

4. **Backend Service Deployment**
   ```yaml
   # backend-deployment.yaml
   apiVersion: apps/v1
   kind: Deployment
   metadata:
     name: backend
   spec:
     replicas: 2
     selector:
       matchLabels:
         app: backend
     template:
       metadata:
         labels:
           app: backend
       spec:
         containers:
         - name: backend
           image: your-account.dkr.ecr.us-west-2.amazonaws.com/myapp-backend:latest
           ports:
           - containerPort: 8080
           env:
           - name: DB_HOST
             valueFrom:
               secretKeyRef:
                 name: db-credentials
                 key: host
           - name: DB_PASSWORD
             valueFrom:
               secretKeyRef:
                 name: db-credentials
                 key: password
   
   ---
   apiVersion: v1
   kind: Service
   metadata:
     name: backend-service
   spec:
     selector:
       app: backend
     ports:
       - protocol: TCP
         port: 8080
         targetPort: 8080
     type: ClusterIP
   ```

**Phase 3: Advanced Kubernetes Features (2 hours)**

5. **Horizontal Pod Autoscaler**
   ```yaml
   apiVersion: autoscaling/v2
   kind: HorizontalPodAutoscaler
   metadata:
     name: frontend-hpa
   spec:
     scaleTargetRef:
       apiVersion: apps/v1
       kind: Deployment
       name: frontend
     minReplicas: 3
     maxReplicas: 10
     metrics:
     - type: Resource
       resource:
         name: cpu
         target:
           type: Utilization
           averageUtilization: 70
   ```

6. **Ingress Controller Configuration**
   ```yaml
   apiVersion: networking.k8s.io/v1
   kind: Ingress
   metadata:
     name: myapp-ingress
     annotations:
       kubernetes.io/ingress.class: aws-load-balancer-controller
       alb.ingress.kubernetes.io/scheme: internet-facing
       alb.ingress.kubernetes.io/target-type: ip
   spec:
     rules:
     - host: myapp.example.com
       http:
         paths:
         - path: /
           pathType: Prefix
           backend:
             service:
               name: frontend-service
               port:
                 number: 80
         - path: /api
           pathType: Prefix
           backend:
             service:
               name: backend-service
               port:
                 number: 8080
   ```

**Testing and Monitoring (2 hours)**
- Load testing with kubectl and curl
- Pod scaling validation
- Service mesh implementation (bonus)
- Logging with Fluent Bit
- Monitoring with Prometheus and Grafana

**Deliverables:**
- [ ] Production-ready EKS cluster
- [ ] Multi-tier containerized application
- [ ] Automated scaling configuration
- [ ] Ingress and load balancing setup
- [ ] Comprehensive monitoring and logging

## Cost Management and Optimization

### 💰 AWS Free Tier Maximization

**Free Tier Limits Monitoring:**
- EC2: 750 hours t2.micro or t3.micro instances
- S3: 5GB storage, 20,000 GET requests, 2,000 PUT requests
- RDS: 750 hours db.t2.micro, 20GB storage
- Lambda: 1M requests, 400,000 GB-seconds compute time
- CloudWatch: 10 custom metrics, 5GB log ingestion

**Cost Optimization Strategies:**
1. **Resource Scheduling**: Stop non-production instances during off-hours
2. **Right-Sizing**: Use appropriate instance types for workloads
3. **Spot Instances**: Use spot instances for non-critical development work
4. **Reserved Instances**: Consider reserved instances for long-term projects
5. **Lifecycle Policies**: Implement S3 lifecycle policies for storage optimization

### 📊 Lab Cost Tracking Template

**Weekly Cost Review Checklist:**
- [ ] Review AWS billing dashboard
- [ ] Identify top 5 cost-driving services
- [ ] Verify all resources are properly tagged
- [ ] Check for orphaned resources (unattached EBS volumes, etc.)
- [ ] Review free tier usage and remaining limits
- [ ] Plan resource cleanup for completed labs

**Cost Estimation for Each Lab:**
- Lab 1.1 (Basic Setup): $2-5
- Lab 1.2 (Database Integration): $5-10
- Lab 1.3 (VPC and Security): $3-7
- Lab 2.1 (High Availability): $15-25
- Lab 2.2 (Infrastructure as Code): $8-15
- Lab 2.3 (Monitoring): $5-12
- Lab 3.1 (CI/CD Pipeline): $20-35
- Lab 3.2 (Container Orchestration): $25-45

**Total Estimated Lab Costs: $85-155** (spread over 6-10 months)

## Documentation and Portfolio Development

### 📝 Lab Documentation Template

**For Each Lab:**
1. **Architecture Diagram**: Visual representation of implemented solution
2. **Configuration Files**: All scripts, templates, and configuration files
3. **Implementation Notes**: Challenges faced and solutions implemented
4. **Cost Analysis**: Actual costs incurred and optimization opportunities
5. **Lessons Learned**: Key takeaways and knowledge gained
6. **Next Steps**: Potential improvements and extensions

### 🎯 Portfolio Project Curation

**Portfolio Highlights:**
- High availability web application with auto-scaling
- Infrastructure as Code templates for multi-environment deployment
- CI/CD pipeline with advanced deployment strategies
- Container orchestration with Kubernetes
- Comprehensive monitoring and alerting implementation

**GitHub Repository Structure:**
```
aws-certification-portfolio/
├── cloud-practitioner-labs/
├── solutions-architect-labs/
├── devops-professional-labs/
├── documentation/
├── cost-analysis/
└── README.md
```

---

## Navigation

- ← Previous: [Study Plans](./study-plans.md)
- → Next: [Best Practices](./best-practices.md)
- ↑ Back to: [AWS Certification Research Overview](./README.md)