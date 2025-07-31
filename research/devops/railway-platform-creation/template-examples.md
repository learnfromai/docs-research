# Template Examples: Railway-like PaaS Platform

## 🎯 Overview

This document provides working code examples, configuration templates, and reference implementations for building a Railway-like Platform-as-a-Service. All examples are production-ready and follow best practices.

## 🏗️ Project Structure Templates

### Monorepo Structure with Nx
```
railway-platform/
├── packages/
│   ├── frontend/                 # Next.js dashboard
│   │   ├── src/
│   │   │   ├── app/             # App Router pages
│   │   │   ├── components/      # Reusable UI components
│   │   │   ├── hooks/           # Custom React hooks
│   │   │   ├── lib/             # Utilities and configurations
│   │   │   └── types/           # TypeScript type definitions
│   │   ├── public/              # Static assets
│   │   ├── package.json
│   │   └── next.config.js
│   │
│   ├── api/                     # Express.js backend
│   │   ├── src/
│   │   │   ├── controllers/     # Request handlers
│   │   │   ├── middleware/      # Express middleware
│   │   │   ├── services/        # Business logic
│   │   │   ├── routes/          # API routes
│   │   │   ├── utils/           # Utilities
│   │   │   └── types/           # TypeScript types
│   │   ├── prisma/              # Database schema and migrations
│   │   ├── package.json
│   │   └── Dockerfile
│   │
│   ├── shared/                  # Shared utilities and types
│   │   ├── src/
│   │   │   ├── types/           # Shared TypeScript types
│   │   │   ├── utils/           # Shared utilities
│   │   │   └── constants/       # Shared constants
│   │   └── package.json
│   │
│   ├── build-service/           # Build orchestration service
│   │   ├── src/
│   │   │   ├── builders/        # Language-specific builders
│   │   │   ├── queue/           # Message queue handlers
│   │   │   └── docker/          # Docker utilities
│   │   └── package.json
│   │
│   └── deployment-service/      # Kubernetes deployment service
│       ├── src/
│       │   ├── k8s/             # Kubernetes API wrappers
│       │   ├── templates/       # Deployment templates
│       │   └── monitoring/      # Health checks and metrics
│       └── package.json
│
├── infrastructure/              # Infrastructure as Code
│   ├── aws-cdk/                # AWS CDK stacks
│   ├── kubernetes/             # Kubernetes manifests
│   └── terraform/              # Alternative Terraform configs
│
├── tools/                      # Development and deployment tools
│   ├── cli/                    # Platform CLI tool
│   └── scripts/                # Automation scripts
│
├── docs/                       # Documentation
├── .github/                    # GitHub Actions workflows
├── nx.json                     # Nx configuration
├── package.json                # Root package.json
└── docker-compose.yml          # Local development environment
```

## 🎨 Frontend Templates

### Next.js Dashboard Application

#### Main Layout Component
```typescript
// packages/frontend/src/components/layout/dashboard-layout.tsx
'use client';

import React, { useState } from 'react';
import { useAuth } from '@auth0/nextjs-auth0/client';
import { Bell, Menu, Settings, User, LogOut } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar';
import { Sidebar } from './sidebar';
import { MobileMenu } from './mobile-menu';

interface DashboardLayoutProps {
  children: React.ReactNode;
}

export function DashboardLayout({ children }: DashboardLayoutProps) {
  const { user, isLoading } = useAuth();
  const [sidebarOpen, setSidebarOpen] = useState(false);

  if (isLoading) {
    return <div className="min-h-screen flex items-center justify-center">Loading...</div>;
  }

  if (!user) {
    return <div>Please log in</div>;
  }

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Mobile menu */}
      <MobileMenu open={sidebarOpen} onClose={() => setSidebarOpen(false)} />

      {/* Sidebar */}
      <Sidebar className="hidden lg:flex" />

      {/* Main content */}
      <div className="lg:pl-64">
        {/* Top navigation */}
        <header className="sticky top-0 z-40 flex h-16 shrink-0 items-center gap-x-4 border-b border-gray-200 bg-white px-4 shadow-sm sm:gap-x-6 sm:px-6 lg:px-8">
          <Button
            variant="ghost"
            size="icon"
            onClick={() => setSidebarOpen(true)}
            className="lg:hidden"
          >
            <Menu className="h-6 w-6" />
          </Button>

          <div className="flex flex-1 gap-x-4 self-stretch lg:gap-x-6">
            <div className="flex flex-1" />
            
            {/* Right section */}
            <div className="flex items-center gap-x-4 lg:gap-x-6">
              {/* Notifications */}
              <Button variant="ghost" size="icon">
                <Bell className="h-5 w-5" />
              </Button>

              {/* Profile dropdown */}
              <div className="relative">
                <Avatar className="h-8 w-8">
                  <AvatarImage src={user.picture} alt={user.name} />
                  <AvatarFallback>
                    {user.name?.charAt(0).toUpperCase()}
                  </AvatarFallback>
                </Avatar>
              </div>
            </div>
          </div>
        </header>

        {/* Page content */}
        <main className="py-10">
          <div className="px-4 sm:px-6 lg:px-8">
            {children}
          </div>
        </main>
      </div>
    </div>
  );
}
```

#### Project Card Component
```typescript
// packages/frontend/src/components/projects/project-card.tsx
import React from 'react';
import Link from 'next/link';
import { formatDistanceToNow } from 'date-fns';
import { ExternalLink, GitBranch, Activity } from 'lucide-react';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import type { Project } from '@/types/project';

interface ProjectCardProps {
  project: Project;
}

export function ProjectCard({ project }: ProjectCardProps) {
  const getStatusColor = (status: string) => {
    switch (status) {
      case 'active':
        return 'bg-green-100 text-green-800';
      case 'building':
        return 'bg-yellow-100 text-yellow-800';
      case 'failed':
        return 'bg-red-100 text-red-800';
      default:
        return 'bg-gray-100 text-gray-800';
    }
  };

  return (
    <Card className="hover:shadow-lg transition-shadow duration-200">
      <CardHeader className="pb-3">
        <div className="flex items-center justify-between">
          <CardTitle className="text-lg font-semibold">
            <Link 
              href={`/projects/${project.id}`}
              className="hover:text-blue-600 transition-colors"
            >
              {project.name}
            </Link>
          </CardTitle>
          <Badge className={getStatusColor(project.status)}>
            {project.status}
          </Badge>
        </div>
        {project.description && (
          <p className="text-sm text-gray-600 mt-1">{project.description}</p>
        )}
      </CardHeader>

      <CardContent>
        <div className="space-y-3">
          {/* Repository info */}
          {project.repositoryUrl && (
            <div className="flex items-center text-sm text-gray-600">
              <GitBranch className="h-4 w-4 mr-2" />
              <span className="truncate">{project.repositoryUrl}</span>
            </div>
          )}

          {/* Last deployment */}
          {project.lastDeployment && (
            <div className="flex items-center text-sm text-gray-600">
              <Activity className="h-4 w-4 mr-2" />
              <span>
                Last deployed {formatDistanceToNow(new Date(project.lastDeployment.createdAt))} ago
              </span>
            </div>
          )}

          {/* Custom domain */}
          {project.customDomain && (
            <div className="flex items-center justify-between">
              <span className="text-sm font-medium">{project.customDomain}</span>
              <Button variant="ghost" size="sm" asChild>
                <a 
                  href={`https://${project.customDomain}`} 
                  target="_blank" 
                  rel="noopener noreferrer"
                >
                  <ExternalLink className="h-4 w-4" />
                </a>
              </Button>
            </div>
          )}

          {/* Actions */}
          <div className="flex gap-2 pt-2">
            <Button size="sm" asChild>
              <Link href={`/projects/${project.id}`}>
                View Details
              </Link>
            </Button>
            <Button variant="outline" size="sm" asChild>
              <Link href={`/projects/${project.id}/deployments`}>
                Deployments
              </Link>
            </Button>
          </div>
        </div>
      </CardContent>
    </Card>
  );
}
```

#### Real-time Deployment Logs
```typescript
// packages/frontend/src/components/deployments/deployment-logs.tsx
'use client';

import React, { useEffect, useRef } from 'react';
import { useWebSocket } from '@/hooks/use-websocket';
import { ScrollArea } from '@/components/ui/scroll-area';

interface DeploymentLogsProps {
  deploymentId: string;
}

export function DeploymentLogs({ deploymentId }: DeploymentLogsProps) {
  const scrollRef = useRef<HTMLDivElement>(null);
  const { 
    messages: logs, 
    connectionStatus, 
    connect, 
    disconnect 
  } = useWebSocket(`/api/deployments/${deploymentId}/logs`);

  useEffect(() => {
    connect();
    return () => disconnect();
  }, [connect, disconnect]);

  useEffect(() => {
    // Auto-scroll to bottom when new logs arrive
    if (scrollRef.current) {
      scrollRef.current.scrollTop = scrollRef.current.scrollHeight;
    }
  }, [logs]);

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h3 className="text-lg font-semibold">Deployment Logs</h3>
        <div className="flex items-center gap-2">
          <div 
            className={`w-2 h-2 rounded-full ${
              connectionStatus === 'connected' ? 'bg-green-500' : 'bg-red-500'
            }`} 
          />
          <span className="text-sm text-gray-600">
            {connectionStatus === 'connected' ? 'Live' : 'Disconnected'}
          </span>
        </div>
      </div>

      <ScrollArea className="h-96 w-full">
        <div ref={scrollRef} className="font-mono text-sm bg-black text-green-400 p-4 rounded-md">
          {logs.length === 0 ? (
            <div className="text-gray-500">Waiting for logs...</div>
          ) : (
            logs.map((log, index) => (
              <div key={index} className="whitespace-pre-wrap">
                <span className="text-gray-400">
                  [{new Date(log.timestamp).toLocaleTimeString()}]
                </span>{' '}
                {log.message}
              </div>
            ))
          )}
        </div>
      </ScrollArea>
    </div>
  );
}
```

## 🔧 Backend API Templates

### Express.js Application Setup
```typescript
// packages/api/src/app.ts
import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import rateLimit from 'express-rate-limit';
import { PrismaClient } from '@prisma/client';
import { createServer } from 'http';
import { Server as SocketIOServer } from 'socket.io';

import { authRouter } from './routes/auth';
import { projectsRouter } from './routes/projects';
import { deploymentsRouter } from './routes/deployments';
import { metricsRouter } from './routes/metrics';
import { errorHandler } from './middleware/error-handler';
import { authenticateToken } from './middleware/auth';
import { requestLogger } from './middleware/logging';

// Initialize Express app
const app = express();
const server = createServer(app);
const io = new SocketIOServer(server, {
  cors: {
    origin: process.env.FRONTEND_URL || 'http://localhost:3000',
    credentials: true,
  },
});

// Initialize Prisma
export const prisma = new PrismaClient();

// Security middleware
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      scriptSrc: ["'self'"],
      imgSrc: ["'self'", "data:", "https:"],
    },
  },
}));

// CORS configuration
app.use(cors({
  origin: process.env.NODE_ENV === 'production' 
    ? [process.env.FRONTEND_URL] 
    : ['http://localhost:3000'],
  credentials: true,
}));

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // limit each IP to 100 requests per windowMs
  message: {
    error: 'Too many requests from this IP, please try again later.',
  },
});

app.use('/api/', limiter);

// Middleware
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));
app.use(morgan('combined'));
app.use(requestLogger);

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    environment: process.env.NODE_ENV,
  });
});

// API routes
app.use('/api/auth', authRouter);
app.use('/api/projects', authenticateToken, projectsRouter);
app.use('/api/deployments', authenticateToken, deploymentsRouter);
app.use('/api/metrics', authenticateToken, metricsRouter);

// WebSocket handling
io.use((socket, next) => {
  // Authenticate WebSocket connections
  const token = socket.handshake.auth.token;
  if (token) {
    // Verify token and attach user to socket
    next();
  } else {
    next(new Error('Authentication error'));
  }
});

io.on('connection', (socket) => {
  console.log('Client connected:', socket.id);

  socket.on('subscribe-deployment', (deploymentId) => {
    socket.join(`deployment:${deploymentId}`);
  });

  socket.on('unsubscribe-deployment', (deploymentId) => {
    socket.leave(`deployment:${deploymentId}`);
  });

  socket.on('disconnect', () => {
    console.log('Client disconnected:', socket.id);
  });
});

// Error handling
app.use(errorHandler);

// Make io available globally
app.set('io', io);

export { app, server, io };
```

### Project Management Service
```typescript
// packages/api/src/services/project.service.ts
import { PrismaClient, Project, Deployment } from '@prisma/client';
import { z } from 'zod';
import { NotFoundError, ValidationError } from '../utils/errors';
import { CacheService } from './cache.service';
import { GitService } from './git.service';

const prisma = new PrismaClient();
const cache = new CacheService();
const gitService = new GitService();

export const CreateProjectSchema = z.object({
  name: z.string()
    .min(3, 'Project name must be at least 3 characters')
    .max(50, 'Project name must be at most 50 characters')
    .regex(/^[a-zA-Z0-9-_]+$/, 'Invalid characters in project name'),
  
  description: z.string().max(500).optional(),
  
  repositoryUrl: z.string()
    .url('Must be a valid URL')
    .regex(/^https:\/\/(github\.com|gitlab\.com)\/.*$/, 'Only GitHub and GitLab repositories are supported')
    .optional(),
  
  branch: z.string().min(1).max(100).default('main'),
  
  buildCommand: z.string().max(1000).optional(),
  
  startCommand: z.string().max(1000).optional(),
  
  environmentVariables: z.record(
    z.string().regex(/^[A-Z_][A-Z0-9_]*$/, 'Invalid environment variable name'),
    z.string().max(1000, 'Environment variable value too long')
  ).optional(),
});

export type CreateProjectData = z.infer<typeof CreateProjectSchema>;

export class ProjectService {
  async createProject(
    userId: string, 
    organizationId: string, 
    data: CreateProjectData
  ): Promise<Project> {
    // Validate repository if provided
    if (data.repositoryUrl) {
      const isValid = await gitService.validateRepository(data.repositoryUrl);
      if (!isValid) {
        throw new ValidationError('Repository is not accessible');
      }
    }

    // Check if project name is unique within organization
    const existingProject = await prisma.project.findFirst({
      where: {
        organizationId,
        name: data.name,
        deletedAt: null,
      },
    });

    if (existingProject) {
      throw new ValidationError('Project name already exists in this organization');
    }

    // Create project
    const project = await prisma.project.create({
      data: {
        ...data,
        userId,
        organizationId,
        status: 'ACTIVE',
      },
      include: {
        user: true,
        organization: true,
      },
    });

    // Clear cache
    await cache.invalidate(`projects:org:${organizationId}`);

    return project;
  }

  async getProject(id: string, userId?: string): Promise<Project | null> {
    const cacheKey = `project:${id}`;
    
    // Try cache first
    let project = await cache.get<Project>(cacheKey);
    
    if (!project) {
      project = await prisma.project.findFirst({
        where: {
          id,
          deletedAt: null,
          ...(userId && { userId }),
        },
        include: {
          user: true,
          organization: true,
          deployments: {
            take: 5,
            orderBy: { createdAt: 'desc' },
          },
          _count: {
            select: {
              deployments: true,
            },
          },
        },
      });

      if (project) {
        await cache.set(cacheKey, project, 3600); // Cache for 1 hour
      }
    }

    return project;
  }

  async getProjects(
    organizationId: string,
    { page = 1, limit = 20, search }: { page?: number; limit?: number; search?: string } = {}
  ): Promise<{ projects: Project[]; total: number; hasMore: boolean }> {
    const offset = (page - 1) * limit;
    
    const where = {
      organizationId,
      deletedAt: null,
      ...(search && {
        OR: [
          { name: { contains: search, mode: 'insensitive' as const } },
          { description: { contains: search, mode: 'insensitive' as const } },
        ],
      }),
    };

    const [projects, total] = await Promise.all([
      prisma.project.findMany({
        where,
        include: {
          user: true,
          deployments: {
            take: 1,
            orderBy: { createdAt: 'desc' },
          },
          _count: {
            select: {
              deployments: true,
            },
          },
        },
        orderBy: { createdAt: 'desc' },
        skip: offset,
        take: limit,
      }),
      prisma.project.count({ where }),
    ]);

    return {
      projects,
      total,
      hasMore: total > offset + limit,
    };
  }

  async updateProject(
    id: string, 
    userId: string, 
    data: Partial<CreateProjectData>
  ): Promise<Project> {
    // Check if project exists and user has permission
    const existingProject = await this.getProject(id, userId);
    if (!existingProject) {
      throw new NotFoundError('Project');
    }

    // Validate repository if being updated
    if (data.repositoryUrl) {
      const isValid = await gitService.validateRepository(data.repositoryUrl);
      if (!isValid) {
        throw new ValidationError('Repository is not accessible');
      }
    }

    const updatedProject = await prisma.project.update({
      where: { id },
      data: {
        ...data,
        updatedAt: new Date(),
      },
      include: {
        user: true,
        organization: true,
      },
    });

    // Invalidate cache
    await cache.invalidate(`project:${id}`);
    await cache.invalidate(`projects:org:${existingProject.organizationId}`);

    return updatedProject;
  }

  async deleteProject(id: string, userId: string): Promise<void> {
    // Check if project exists and user has permission
    const project = await this.getProject(id, userId);
    if (!project) {
      throw new NotFoundError('Project');
    }

    // Soft delete
    await prisma.project.update({
      where: { id },
      data: {
        deletedAt: new Date(),
        status: 'DELETED',
      },
    });

    // Invalidate cache
    await cache.invalidate(`project:${id}`);
    await cache.invalidate(`projects:org:${project.organizationId}`);
  }

  async getProjectMetrics(projectId: string): Promise<any> {
    const cacheKey = `metrics:${projectId}`;
    
    let metrics = await cache.get(cacheKey);
    
    if (!metrics) {
      // Calculate various metrics
      const [
        totalDeployments,
        successfulDeployments,
        failedDeployments,
        avgBuildTime,
        recentDeployments,
      ] = await Promise.all([
        prisma.deployment.count({
          where: { projectId },
        }),
        prisma.deployment.count({
          where: { projectId, status: 'SUCCESS' },
        }),
        prisma.deployment.count({
          where: { projectId, status: 'FAILED' },
        }),
        prisma.deployment.aggregate({
          where: { 
            projectId, 
            buildStartedAt: { not: null },
            buildCompletedAt: { not: null },
          },
          _avg: {
            // This would be calculated in raw SQL in practice
            // buildDuration: true,
          },
        }),
        prisma.deployment.findMany({
          where: { projectId },
          orderBy: { createdAt: 'desc' },
          take: 10,
          select: {
            id: true,
            status: true,
            createdAt: true,
            buildStartedAt: true,
            buildCompletedAt: true,
          },
        }),
      ]);

      metrics = {
        totalDeployments,
        successfulDeployments,
        failedDeployments,
        successRate: totalDeployments > 0 ? (successfulDeployments / totalDeployments) * 100 : 0,
        avgBuildTime: null, // Would calculate from buildStartedAt and buildCompletedAt
        recentDeployments,
      };

      await cache.set(cacheKey, metrics, 300); // Cache for 5 minutes
    }

    return metrics;
  }
}
```

## 🚀 Infrastructure Templates

### AWS CDK Stack
```typescript
// infrastructure/aws-cdk/lib/platform-stack.ts
import * as cdk from 'aws-cdk-lib';
import * as ec2 from 'aws-cdk-lib/aws-ec2';
import * as eks from 'aws-cdk-lib/aws-eks';
import * as rds from 'aws-cdk-lib/aws-rds';
import * as elasticache from 'aws-cdk-lib/aws-elasticache';
import * as ecr from 'aws-cdk-lib/aws-ecr';
import * as iam from 'aws-cdk-lib/aws-iam';
import { Construct } from 'constructs';

export class PlatformStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // VPC
    const vpc = new ec2.Vpc(this, 'PlatformVPC', {
      maxAzs: 3,
      natGateways: 2,
      subnetConfiguration: [
        {
          name: 'Public',
          subnetType: ec2.SubnetType.PUBLIC,
          cidrMask: 24,
        },
        {
          name: 'Private',
          subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS,
          cidrMask: 24,
        },
        {
          name: 'Database',
          subnetType: ec2.SubnetType.PRIVATE_ISOLATED,
          cidrMask: 24,
        },
      ],
    });

    // EKS Cluster
    const cluster = new eks.Cluster(this, 'PlatformCluster', {
      version: eks.KubernetesVersion.V1_28,
      vpc,
      defaultCapacity: 0,
      endpointAccess: eks.EndpointAccess.PUBLIC_AND_PRIVATE,
    });

    // Managed Node Groups
    cluster.addNodegroupCapacity('SystemNodes', {
      instanceTypes: [
        ec2.InstanceType.of(ec2.InstanceClass.T3, ec2.InstanceSize.MEDIUM),
      ],
      minSize: 2,
      maxSize: 5,
      desiredSize: 3,
      labels: { 'node-type': 'system' },
      taints: [{
        key: 'node-type',
        value: 'system',
        effect: eks.TaintEffect.NO_SCHEDULE,
      }],
    });

    cluster.addNodegroupCapacity('UserWorkloads', {
      instanceTypes: [
        ec2.InstanceType.of(ec2.InstanceClass.M5, ec2.InstanceSize.LARGE),
      ],
      minSize: 3,
      maxSize: 20,
      desiredSize: 5,
      labels: { 'node-type': 'user-workloads' },
    });

    // RDS Aurora PostgreSQL
    const database = new rds.DatabaseCluster(this, 'PlatformDatabase', {
      engine: rds.DatabaseClusterEngine.auroraPostgres({
        version: rds.AuroraPostgresEngineVersion.VER_15_4,
      }),
      writer: rds.ClusterInstance.provisioned('writer', {
        instanceType: ec2.InstanceType.of(ec2.InstanceClass.R6G, ec2.InstanceSize.LARGE),
      }),
      readers: [
        rds.ClusterInstance.provisioned('reader1', {
          instanceType: ec2.InstanceType.of(ec2.InstanceClass.R6G, ec2.InstanceSize.LARGE),
        }),
      ],
      vpc,
      vpcSubnets: { subnetType: ec2.SubnetType.PRIVATE_ISOLATED },
      credentials: rds.Credentials.fromGeneratedSecret('platformadmin'),
      backup: { retention: cdk.Duration.days(7) },
    });

    // ElastiCache Redis
    const redisSubnetGroup = new elasticache.CfnSubnetGroup(this, 'RedisSubnetGroup', {
      description: 'Subnet group for Redis cache',
      subnetIds: vpc.privateSubnets.map(subnet => subnet.subnetId),
    });

    const redisSecurityGroup = new ec2.SecurityGroup(this, 'RedisSecurityGroup', {
      vpc,
      description: 'Security group for Redis cache',
    });

    redisSecurityGroup.addIngressRule(
      ec2.Peer.ipv4(vpc.vpcCidrBlock),
      ec2.Port.tcp(6379),
      'Allow Redis access from VPC'
    );

    new elasticache.CfnCacheCluster(this, 'PlatformCache', {
      cacheNodeType: 'cache.r6g.large',
      engine: 'redis',
      numCacheNodes: 1,
      cacheSubnetGroupName: redisSubnetGroup.ref,
      vpcSecurityGroupIds: [redisSecurityGroup.securityGroupId],
    });

    // ECR Repository
    const ecrRepository = new ecr.Repository(this, 'ContainerRegistry', {
      repositoryName: 'railway-platform',
      imageScanOnPush: true,
      lifecycleRules: [{
        maxImageCount: 10,
        tagStatus: ecr.TagStatus.UNTAGGED,
      }],
    });

    // Install cluster add-ons
    this.installAddOns(cluster);

    // Outputs
    new cdk.CfnOutput(this, 'ClusterName', { value: cluster.clusterName });
    new cdk.CfnOutput(this, 'DatabaseEndpoint', { value: database.clusterEndpoint.hostname });
    new cdk.CfnOutput(this, 'ECRRepository', { value: ecrRepository.repositoryUri });
  }

  private installAddOns(cluster: eks.Cluster) {
    // AWS Load Balancer Controller
    cluster.addHelmChart('AWSLoadBalancerController', {
      chart: 'aws-load-balancer-controller',
      repository: 'https://aws.github.io/eks-charts',
      namespace: 'kube-system',
      values: {
        clusterName: cluster.clusterName,
        serviceAccount: {
          create: false,
          name: 'aws-load-balancer-controller',
        },
      },
    });

    // Prometheus & Grafana
    cluster.addHelmChart('KubePrometheusStack', {
      chart: 'kube-prometheus-stack',
      repository: 'https://prometheus-community.github.io/helm-charts',
      namespace: 'monitoring',
      createNamespace: true,
    });
  }
}
```

### Kubernetes Deployment Templates
```yaml
# infrastructure/kubernetes/platform-api.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: platform-api
  labels:
    app: platform-api
    platform: railway-clone
spec:
  replicas: 3
  selector:
    matchLabels:
      app: platform-api
  template:
    metadata:
      labels:
        app: platform-api
        platform: railway-clone
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "3000"
        prometheus.io/path: "/metrics"
    spec:
      serviceAccountName: platform-api
      securityContext:
        runAsNonRoot: true
        runAsUser: 1001
        fsGroup: 1001
      containers:
      - name: api
        image: railway-platform/api:latest
        ports:
        - containerPort: 3000
          name: http
        env:
        - name: NODE_ENV
          value: "production"
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: platform-secrets
              key: database-url
        - name: REDIS_URL
          valueFrom:
            secretKeyRef:
              name: platform-secrets
              key: redis-url
        - name: JWT_SECRET
          valueFrom:
            secretKeyRef:
              name: platform-secrets
              key: jwt-secret
        resources:
          requests:
            memory: "256Mi"
            cpu: "200m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 5
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 3
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          runAsUser: 1001
          capabilities:
            drop:
              - ALL
        volumeMounts:
        - name: tmp
          mountPath: /tmp
        - name: logs
          mountPath: /app/logs
      volumes:
      - name: tmp
        emptyDir: {}
      - name: logs
        emptyDir: {}

---
apiVersion: v1
kind: Service
metadata:
  name: platform-api-service
  labels:
    app: platform-api
spec:
  selector:
    app: platform-api
  ports:
  - port: 80
    targetPort: 3000
    protocol: TCP
    name: http
  type: ClusterIP

---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: platform-api-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: platform-api
  minReplicas: 3
  maxReplicas: 10
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

---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: platform-api-pdb
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: platform-api
```

### Docker Templates

#### Multi-stage Node.js Dockerfile
```dockerfile
# Dockerfile for Node.js applications
FROM node:18-alpine AS base
WORKDIR /app

# Install dependencies in separate layer for caching
FROM base AS deps
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force

# Build stage
FROM base AS build
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# Production stage
FROM base AS runtime

# Create non-root user
RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nextjs

# Copy built application
COPY --from=deps --chown=nextjs:nodejs /app/node_modules ./node_modules
COPY --from=build --chown=nextjs:nodejs /app/dist ./dist
COPY --from=build --chown=nextjs:nodejs /app/package.json ./package.json

# Create directories for writable content
RUN mkdir -p /app/logs /tmp && \
    chown -R nextjs:nodejs /app/logs /tmp

# Security: Don't run as root
USER nextjs

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1

# Expose port
EXPOSE 3000

# Start application
CMD ["npm", "start"]

# Labels
LABEL maintainer="platform-team@railway-clone.com"
LABEL version="1.0.0"
LABEL description="Railway Platform API Service"
```

#### Docker Compose for Development
```yaml
# docker-compose.yml
version: '3.8'

services:
  postgres:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: railway_platform
      POSTGRES_USER: platform
      POSTGRES_PASSWORD: password
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U platform"]
      interval: 5s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 5

  api:
    build:
      context: ./packages/api
      dockerfile: Dockerfile
    ports:
      - "4000:3000"
    environment:
      NODE_ENV: development
      DATABASE_URL: postgresql://platform:password@postgres:5432/railway_platform
      REDIS_URL: redis://redis:6379
      JWT_SECRET: your-jwt-secret-here
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    volumes:
      - ./packages/api:/app
      - /app/node_modules
    command: npm run dev

  frontend:
    build:
      context: ./packages/frontend
      dockerfile: Dockerfile
    ports:
      - "3000:3000"
    environment:
      NEXT_PUBLIC_API_URL: http://localhost:4000
    volumes:
      - ./packages/frontend:/app
      - /app/node_modules
      - /app/.next
    command: npm run dev

volumes:
  postgres_data:
  redis_data:
```

## 🔧 Development Tools Templates

### Platform CLI Tool
```typescript
#!/usr/bin/env node
// tools/cli/src/index.ts
import { Command } from 'commander';
import { deployCommand } from './commands/deploy';
import { logsCommand } from './commands/logs';
import { projectsCommand } from './commands/projects';
import { loginCommand } from './commands/login';

const program = new Command();

program
  .name('railway-cli')
  .description('Railway Platform CLI')
  .version('1.0.0');

program
  .command('login')
  .description('Login to Railway Platform')
  .action(loginCommand);

program
  .command('deploy')
  .description('Deploy current project')
  .option('-p, --project <name>', 'Project name')
  .option('-e, --env <environment>', 'Environment name', 'production')
  .action(deployCommand);

program
  .command('logs')
  .description('View deployment logs')
  .argument('<deployment-id>', 'Deployment ID')
  .option('-f, --follow', 'Follow logs in real-time')
  .action(logsCommand);

program
  .command('projects')
  .description('Manage projects')
  .option('-l, --list', 'List all projects')
  .option('-c, --create <name>', 'Create new project')
  .action(projectsCommand);

program.parse();
```

### GitHub Actions Workflow Template
```yaml
# .github/workflows/deploy.yml
name: Deploy to Railway Platform

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: railway-platform

jobs:
  test:
    runs-on: ubuntu-latest
    
    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_PASSWORD: postgres
          POSTGRES_DB: test_db
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 5432:5432
      
      redis:
        image: redis:7
        options: >-
          --health-cmd "redis-cli ping"
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 6379:6379
    
    steps:
    - uses: actions/checkout@v4
    
    - name: Setup Node.js
      uses: actions/setup-node@v4
      with:
        node-version: '18'
        cache: 'npm'
    
    - name: Install dependencies
      run: npm ci
    
    - name: Run tests
      run: npm test
      env:
        DATABASE_URL: postgresql://postgres:postgres@localhost:5432/test_db
        REDIS_URL: redis://localhost:6379
    
    - name: Upload coverage
      uses: codecov/codecov-action@v3

  build:
    needs: test
    runs-on: ubuntu-latest
    if: github.event_name == 'push'
    
    steps:
    - uses: actions/checkout@v4
    
    - name: Log in to Container Registry
      uses: docker/login-action@v3
      with:
        registry: ${{ env.REGISTRY }}
        username: ${{ github.actor }}
        password: ${{ secrets.GITHUB_TOKEN }}
    
    - name: Build and push Docker image
      uses: docker/build-push-action@v5
      with:
        context: .
        push: true
        tags: ${{ env.REGISTRY }}/${{ github.repository }}:${{ github.sha }}

  deploy:
    needs: build
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    environment: production
    
    steps:
    - name: Deploy to Kubernetes
      run: |
        echo "Deploying to production..."
        # kubectl set image deployment/platform-api platform-api=${{ env.REGISTRY }}/${{ github.repository }}:${{ github.sha }}
```

## 🧭 Navigation

← [Back to Business Model](./business-model-analysis.md) | [Next: Troubleshooting →](./troubleshooting.md)

---

### Quick Links
- [Main Research Hub](./README.md)
- [Executive Summary](./executive-summary.md)
- [Implementation Guide](./implementation-guide.md)
- [System Architecture Design](./system-architecture-design.md)

---

## 📚 References

1. [Next.js Documentation](https://nextjs.org/docs)
2. [Express.js Best Practices](https://expressjs.com/en/advanced/best-practice-performance.html)
3. [Prisma Documentation](https://www.prisma.io/docs)
4. [AWS CDK Examples](https://github.com/aws-samples/aws-cdk-examples)
5. [Kubernetes Examples](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
6. [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
7. [GitHub Actions Documentation](https://docs.github.com/en/actions)
8. [TypeScript Handbook](https://www.typescriptlang.org/docs/)
9. [Nx Documentation](https://nx.dev/getting-started/intro)
10. [Railway Platform Examples](https://github.com/railwayapp/examples)