# Best Practices: Building a Railway.com-Like Platform

## 🎯 Overview

This document outlines essential best practices for building, deploying, and operating a modern Platform-as-a-Service (PaaS) similar to Railway.com. These practices are derived from industry standards, battle-tested patterns, and lessons learned from successful platform companies.

## 🏗️ Development Best Practices

### Code Quality & Standards

#### TypeScript Configuration
```json
// tsconfig.json - Strict TypeScript configuration
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "lib": ["ES2022", "DOM", "DOM.Iterable"],
    "allowJs": false,
    "checkJs": false,
    "declaration": true,
    "declarationMap": true,
    "sourceMap": true,
    "removeComments": false,
    "importHelpers": true,
    "downlevelIteration": true,
    "isolatedModules": true,
    "allowSyntheticDefaultImports": true,
    "esModuleInterop": true,
    "preserveSymlinks": true,
    "forceConsistentCasingInFileNames": true,
    "strict": true,
    "noImplicitReturns": true,
    "noFallthroughCasesInSwitch": true,
    "noUncheckedIndexedAccess": true,
    "noImplicitOverride": true,
    "exactOptionalPropertyTypes": true,
    "skipLibCheck": true
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist", "**/*.test.ts"]
}
```

#### ESLint Configuration
```javascript
// .eslintrc.js - Comprehensive linting rules
module.exports = {
  extends: [
    '@typescript-eslint/recommended',
    '@typescript-eslint/recommended-requiring-type-checking',
    'plugin:security/recommended',
    'plugin:import/errors',
    'plugin:import/warnings',
    'plugin:import/typescript'
  ],
  parser: '@typescript-eslint/parser',
  parserOptions: {
    project: './tsconfig.json',
    ecmaVersion: 2022,
    sourceType: 'module'
  },
  plugins: ['@typescript-eslint', 'security', 'import'],
  rules: {
    // Security
    'security/detect-object-injection': 'error',
    'security/detect-non-literal-regexp': 'error',
    'security/detect-unsafe-regex': 'error',
    
    // TypeScript
    '@typescript-eslint/no-unused-vars': 'error',
    '@typescript-eslint/explicit-function-return-type': 'warn',
    '@typescript-eslint/no-explicit-any': 'error',
    '@typescript-eslint/prefer-nullish-coalescing': 'error',
    '@typescript-eslint/prefer-optional-chain': 'error',
    
    // Import organization
    'import/order': ['error', {
      'groups': [
        'builtin',
        'external',
        'internal',
        'parent',
        'sibling',
        'index'
      ],
      'newlines-between': 'always'
    }],
    
    // General code quality
    'no-console': 'warn',
    'prefer-const': 'error',
    'no-var': 'error'
  }
};
```

#### Git Workflow Standards
```yaml
# .github/pull_request_template.md
## Description
Brief description of changes and motivation

## Type of Change
- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update

## Testing
- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Manual testing completed
- [ ] Performance impact assessed

## Security
- [ ] Security implications reviewed
- [ ] Input validation implemented
- [ ] Authorization checks in place
- [ ] Secrets not committed

## Checklist
- [ ] Code follows project style guidelines
- [ ] Self-review completed
- [ ] Documentation updated
- [ ] Breaking changes documented
```

### API Design Best Practices

#### RESTful API Standards
```typescript
// Consistent API response format
interface ApiResponse<T> {
  success: boolean;
  data?: T;
  error?: {
    code: string;
    message: string;
    details?: Record<string, any>;
  };
  meta?: {
    pagination?: PaginationMeta;
    requestId: string;
    timestamp: string;
  };
}

interface PaginationMeta {
  page: number;
  limit: number;
  total: number;
  totalPages: number;
  hasNext: boolean;
  hasPrev: boolean;
}

// API versioning strategy
app.use('/api/v1', v1Router);
app.use('/api/v2', v2Router);

// Consistent error handling
class ApiError extends Error {
  constructor(
    public statusCode: number,
    public code: string,
    message: string,
    public details?: Record<string, any>
  ) {
    super(message);
    this.name = 'ApiError';
  }
}

const errorHandler = (error: Error, req: Request, res: Response, next: NextFunction) => {
  const requestId = req.headers['x-request-id'] as string || crypto.randomUUID();
  
  if (error instanceof ApiError) {
    res.status(error.statusCode).json({
      success: false,
      error: {
        code: error.code,
        message: error.message,
        details: error.details
      },
      meta: {
        requestId,
        timestamp: new Date().toISOString()
      }
    });
  } else {
    // Log unexpected errors
    logger.error('Unexpected error', { error, requestId });
    
    res.status(500).json({
      success: false,
      error: {
        code: 'INTERNAL_SERVER_ERROR',
        message: 'An unexpected error occurred'
      },
      meta: {
        requestId,
        timestamp: new Date().toISOString()
      }
    });
  }
};
```

#### GraphQL Best Practices
```typescript
// Schema organization
// schema/user.graphql
type User {
  id: ID!
  email: String!
  username: String
  projects(first: Int, after: String): ProjectConnection!
  createdAt: DateTime!
}

type ProjectConnection {
  edges: [ProjectEdge!]!
  pageInfo: PageInfo!
  totalCount: Int!
}

// Resolver patterns
const userResolvers = {
  User: {
    projects: async (parent: User, args: PaginationArgs, context: Context) => {
      // Implement DataLoader for N+1 prevention
      return context.dataloaders.projectsByUserId.load({
        userId: parent.id,
        ...args
      });
    }
  },
  
  Query: {
    user: async (_: any, { id }: { id: string }, context: Context) => {
      if (!context.user) {
        throw new ForbiddenError('Authentication required');
      }
      
      if (context.user.id !== id && !context.user.isAdmin) {
        throw new ForbiddenError('Access denied');
      }
      
      return context.dataloaders.userById.load(id);
    }
  }
};

// DataLoader implementation for efficient data fetching
class DataLoaders {
  public readonly userById = new DataLoader(async (ids: readonly string[]) => {
    const users = await prisma.user.findMany({
      where: { id: { in: [...ids] } }
    });
    
    return ids.map(id => users.find(user => user.id === id) || null);
  });
  
  public readonly projectsByUserId = new DataLoader(
    async (keys: readonly { userId: string; first?: number; after?: string }[]) => {
      // Implement efficient batch loading
      const results = await Promise.all(
        keys.map(({ userId, first = 10, after }) =>
          this.loadProjectsForUser(userId, first, after)
        )
      );
      
      return results;
    }
  );
}
```

### Testing Strategy

#### Test Pyramid Implementation
```typescript
// Unit Tests - Fast, isolated, numerous
// __tests__/unit/user-service.test.ts
describe('UserService', () => {
  let userService: UserService;
  let mockPrisma: DeepMockProxy<PrismaClient>;

  beforeEach(() => {
    mockPrisma = mockDeep<PrismaClient>();
    userService = new UserService(mockPrisma);
  });

  describe('createUser', () => {
    it('should create user with valid data', async () => {
      const userData = {
        email: 'test@example.com',
        username: 'testuser'
      };
      
      const expectedUser = { id: '123', ...userData, createdAt: new Date() };
      mockPrisma.user.create.mockResolvedValue(expectedUser);

      const result = await userService.createUser(userData);

      expect(result).toEqual(expectedUser);
      expect(mockPrisma.user.create).toHaveBeenCalledWith({
        data: userData
      });
    });

    it('should throw error for duplicate email', async () => {
      const userData = { email: 'test@example.com', username: 'testuser' };
      
      mockPrisma.user.create.mockRejectedValue(
        new Error('Unique constraint failed')
      );

      await expect(userService.createUser(userData))
        .rejects.toThrow('Email already exists');
    });
  });
});

// Integration Tests - Moderate speed, test component interaction
// __tests__/integration/auth-flow.test.ts
describe('Authentication Flow', () => {
  let app: Express;
  let testDb: PrismaClient;

  beforeAll(async () => {
    testDb = new PrismaClient({
      datasources: { db: { url: process.env.TEST_DATABASE_URL } }
    });
    app = createApp(testDb);
  });

  afterAll(async () => {
    await testDb.$disconnect();
  });

  beforeEach(async () => {
    await testDb.user.deleteMany();
  });

  it('should complete OAuth flow successfully', async () => {
    // Mock GitHub OAuth response
    nock('https://github.com')
      .post('/login/oauth/access_token')
      .reply(200, { access_token: 'github_token' });
    
    nock('https://api.github.com')
      .get('/user')
      .reply(200, {
        id: 12345,
        login: 'testuser',
        email: 'test@example.com'
      });

    const response = await request(app)
      .post('/api/auth/github')
      .send({ code: 'oauth_code' })
      .expect(200);

    expect(response.body).toHaveProperty('token');
    expect(response.body.user).toMatchObject({
      email: 'test@example.com',
      username: 'testuser'
    });

    // Verify user was created in database
    const user = await testDb.user.findUnique({
      where: { email: 'test@example.com' }
    });
    expect(user).toBeTruthy();
  });
});

// E2E Tests - Slow, test complete user journeys
// __tests__/e2e/deployment-flow.spec.ts
import { test, expect, Page } from '@playwright/test';

test.describe('Deployment Flow', () => {
  test('user can deploy application from GitHub', async ({ page }) => {
    // Login
    await page.goto('/login');
    await page.click('[data-testid="github-login"]');
    await page.waitForURL('/dashboard');

    // Create new project
    await page.click('[data-testid="new-project"]');
    await page.fill('[data-testid="project-name"]', 'Test App');
    await page.fill('[data-testid="github-repo"]', 'https://github.com/user/test-app');
    await page.click('[data-testid="create-project"]');

    // Wait for project creation
    await expect(page.locator('[data-testid="project-card"]')).toBeVisible();

    // Trigger deployment
    await page.click('[data-testid="deploy-button"]');
    await expect(page.locator('[data-testid="deployment-status"]')).toContainText('Building');

    // Wait for deployment completion (with timeout)
    await expect(page.locator('[data-testid="deployment-status"]'))
      .toContainText('Success', { timeout: 120000 });

    // Verify deployment URL is accessible
    const deploymentUrl = await page.locator('[data-testid="deployment-url"]').textContent();
    const response = await page.request.get(deploymentUrl!);
    expect(response.status()).toBe(200);
  });
});
```

## 🚀 Deployment & Infrastructure Best Practices

### Container Best Practices

#### Dockerfile Optimization
```dockerfile
# Multi-stage build for minimal production image
FROM node:18-alpine AS base
WORKDIR /app
RUN addgroup -g 1001 -S nodejs
RUN adduser -S nextjs -u 1001

# Dependencies stage
FROM base AS deps
COPY package.json pnpm-lock.yaml* ./
RUN corepack enable pnpm && pnpm install --frozen-lockfile

# Build stage
FROM base AS builder
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Build application
RUN npm run build

# Production stage
FROM base AS runner
ENV NODE_ENV=production

# Copy built application
COPY --from=builder --chown=nextjs:nodejs /app/dist ./dist
COPY --from=builder --chown=nextjs:nodejs /app/public ./public
COPY --from=deps --chown=nextjs:nodejs /app/node_modules ./node_modules
COPY --from=builder --chown=nextjs:nodejs /app/package.json ./package.json

USER nextjs

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1

EXPOSE 3000
CMD ["node", "dist/index.js"]
```

#### Kubernetes Resource Management
```yaml
# Resource requests and limits
apiVersion: apps/v1
kind: Deployment
metadata:
  name: railway-api
spec:
  template:
    spec:
      containers:
      - name: api
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 3
        env:
        - name: NODE_ENV
          value: "production"
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: database-secret
              key: url
```

### CI/CD Pipeline Optimization

#### GitHub Actions Best Practices
```yaml
name: Production Deployment
on:
  push:
    branches: [main]

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_PASSWORD: postgres
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
    
    steps:
    - uses: actions/checkout@v4
    
    - name: Setup Node.js
      uses: actions/setup-node@v4
      with:
        node-version: '18'
        cache: 'npm'
    
    - name: Install dependencies
      run: npm ci
    
    - name: Run type checking
      run: npm run type-check
    
    - name: Run linting
      run: npm run lint
    
    - name: Run unit tests
      run: npm run test:unit
      env:
        CI: true
    
    - name: Run integration tests
      run: npm run test:integration
      env:
        DATABASE_URL: postgresql://postgres:postgres@localhost:5432/test
    
    - name: Upload coverage reports
      uses: codecov/codecov-action@v3
      with:
        files: ./coverage/lcov.info

  security:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    
    - name: Run Snyk security scan
      uses: snyk/actions/node@master
      env:
        SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
    
    - name: Run Trivy vulnerability scanner
      uses: aquasecurity/trivy-action@master
      with:
        scan-type: 'fs'
        scan-ref: '.'
        format: 'sarif'
        output: 'trivy-results.sarif'
    
    - name: Upload Trivy scan results
      uses: github/codeql-action/upload-sarif@v2
      with:
        sarif_file: 'trivy-results.sarif'

  build-and-deploy:
    needs: [test, security]
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
      
    steps:
    - uses: actions/checkout@v4
    
    - name: Login to Container Registry
      uses: docker/login-action@v2
      with:
        registry: ${{ env.REGISTRY }}
        username: ${{ github.actor }}
        password: ${{ secrets.GITHUB_TOKEN }}
    
    - name: Build and push Docker image
      uses: docker/build-push-action@v4
      with:
        context: .
        push: true
        tags: |
          ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:latest
          ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}
        cache-from: type=gha
        cache-to: type=gha,mode=max
    
    - name: Deploy to Kubernetes
      run: |
        echo "${{ secrets.KUBECONFIG }}" | base64 -d > kubeconfig
        export KUBECONFIG=kubeconfig
        
        helm upgrade --install railway-platform ./k8s/helm \
          --set image.tag=${{ github.sha }} \
          --set secrets.databaseUrl="${{ secrets.DATABASE_URL }}" \
          --wait --timeout=10m
```

### Database Best Practices

#### Migration Strategy
```typescript
// Database migration management
// migrations/001_initial_schema.ts
import { Knex } from 'knex';

export async function up(knex: Knex): Promise<void> {
  // Create users table
  await knex.schema.createTable('users', (table) => {
    table.uuid('id').primary().defaultTo(knex.raw('gen_random_uuid()'));
    table.string('email').unique().notNullable();
    table.string('username').unique();
    table.string('github_id').unique();
    table.string('avatar_url');
    table.enum('tier', ['free', 'pro', 'enterprise']).defaultTo('free');
    table.timestamps(true, true);
    
    // Indexes
    table.index(['email']);
    table.index(['github_id']);
  });

  // Create projects table
  await knex.schema.createTable('projects', (table) => {
    table.uuid('id').primary().defaultTo(knex.raw('gen_random_uuid()'));
    table.uuid('user_id').references('id').inTable('users').onDelete('CASCADE');
    table.string('name').notNullable();
    table.text('description');
    table.string('github_repo');
    table.string('github_branch').defaultTo('main');
    table.string('framework');
    table.jsonb('env_vars').defaultTo('{}');
    table.string('custom_domain');
    table.enum('status', ['active', 'inactive', 'archived']).defaultTo('active');
    table.timestamps(true, true);
    
    // Indexes
    table.index(['user_id']);
    table.index(['status']);
    table.index(['created_at']);
  });
}

export async function down(knex: Knex): Promise<void> {
  await knex.schema.dropTable('projects');
  await knex.schema.dropTable('users');
}

// Database query optimization
class OptimizedUserService {
  // Use transactions for consistency
  async createUserWithProject(userData: CreateUserData, projectData: CreateProjectData) {
    return await prisma.$transaction(async (tx) => {
      const user = await tx.user.create({
        data: userData
      });
      
      const project = await tx.project.create({
        data: {
          ...projectData,
          userId: user.id
        }
      });
      
      return { user, project };
    });
  }

  // Implement proper pagination
  async getUserProjects(userId: string, page = 1, limit = 20) {
    const offset = (page - 1) * limit;
    
    const [projects, total] = await Promise.all([
      prisma.project.findMany({
        where: { userId },
        include: {
          deployments: {
            orderBy: { createdAt: 'desc' },
            take: 1
          }
        },
        orderBy: { createdAt: 'desc' },
        skip: offset,
        take: limit
      }),
      prisma.project.count({ where: { userId } })
    ]);
    
    return {
      projects,
      pagination: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
        hasNext: page * limit < total,
        hasPrev: page > 1
      }
    };
  }

  // Use database-level aggregations
  async getUserStats(userId: string) {
    const stats = await prisma.project.aggregate({
      where: { userId },
      _count: { id: true },
      _avg: { buildDuration: true }
    });
    
    const deploymentStats = await prisma.deployment.groupBy({
      by: ['status'],
      where: {
        project: { userId }
      },
      _count: { status: true }
    });
    
    return {
      totalProjects: stats._count.id,
      avgBuildDuration: stats._avg.buildDuration,
      deploymentsByStatus: deploymentStats.reduce((acc, stat) => {
        acc[stat.status] = stat._count.status;
        return acc;
      }, {} as Record<string, number>)
    };
  }
}
```

## 🔐 Security Best Practices

### Authentication & Authorization

#### JWT Security Implementation
```typescript
// Secure JWT implementation with refresh tokens
class AuthTokenService {
  private readonly ACCESS_TOKEN_EXPIRY = '15m';
  private readonly REFRESH_TOKEN_EXPIRY = '7d';
  private readonly ALGORITHM = 'RS256'; // Use asymmetric keys for better security

  constructor(
    private readonly privateKey: string,
    private readonly publicKey: string
  ) {}

  generateTokenPair(user: User): TokenPair {
    const payload = {
      sub: user.id,
      email: user.email,
      role: user.role,
      type: 'access'
    };

    const accessToken = jwt.sign(payload, this.privateKey, {
      algorithm: this.ALGORITHM,
      expiresIn: this.ACCESS_TOKEN_EXPIRY,
      issuer: 'railway-platform',
      audience: 'railway-api'
    });

    const refreshToken = jwt.sign(
      { ...payload, type: 'refresh' },
      this.privateKey,
      {
        algorithm: this.ALGORITHM,
        expiresIn: this.REFRESH_TOKEN_EXPIRY,
        issuer: 'railway-platform',
        audience: 'railway-api'
      }
    );

    return { accessToken, refreshToken };
  }

  async validateAccessToken(token: string): Promise<JWTPayload> {
    try {
      const payload = jwt.verify(token, this.publicKey, {
        algorithms: [this.ALGORITHM],
        issuer: 'railway-platform',
        audience: 'railway-api'
      }) as JWTPayload;

      if (payload.type !== 'access') {
        throw new Error('Invalid token type');
      }

      // Check token blacklist
      const isBlacklisted = await redis.get(`blacklist:${payload.jti}`);
      if (isBlacklisted) {
        throw new Error('Token has been revoked');
      }

      return payload;
    } catch (error) {
      throw new AuthenticationError('Invalid access token');
    }
  }

  async refreshAccessToken(refreshToken: string): Promise<TokenPair> {
    try {
      const payload = jwt.verify(refreshToken, this.publicKey, {
        algorithms: [this.ALGORITHM],
        issuer: 'railway-platform',
        audience: 'railway-api'
      }) as JWTPayload;

      if (payload.type !== 'refresh') {
        throw new Error('Invalid token type');
      }

      // Verify user still exists and is active
      const user = await prisma.user.findUnique({
        where: { id: payload.sub }
      });

      if (!user) {
        throw new Error('User not found');
      }

      return this.generateTokenPair(user);
    } catch (error) {
      throw new AuthenticationError('Invalid refresh token');
    }
  }

  async revokeToken(token: string): Promise<void> {
    try {
      const payload = jwt.verify(token, this.publicKey, {
        algorithms: [this.ALGORITHM],
        ignoreExpiration: true
      }) as JWTPayload;

      // Add to blacklist with TTL equal to remaining token lifetime
      const remainingTTL = payload.exp - Math.floor(Date.now() / 1000);
      if (remainingTTL > 0) {
        await redis.setex(`blacklist:${payload.jti}`, remainingTTL, '1');
      }
    } catch (error) {
      // Token is invalid, nothing to revoke
    }
  }
}
```

### Input Validation & Sanitization

#### Comprehensive Validation Layer
```typescript
// Input validation with Zod schemas
import { z } from 'zod';

// Common validation patterns
const commonSchemas = {
  uuid: z.string().uuid(),
  email: z.string().email().toLowerCase(),
  url: z.string().url(),
  githubRepo: z.string().regex(
    /^https:\/\/github\.com\/[\w\-\.]+\/[\w\-\.]+$/,
    'Invalid GitHub repository URL'
  ),
  envVarName: z.string().regex(
    /^[A-Z_][A-Z0-9_]*$/,
    'Environment variable names must be uppercase with underscores'
  ),
  projectName: z.string()
    .min(1, 'Project name is required')
    .max(100, 'Project name must be less than 100 characters')
    .regex(/^[a-zA-Z0-9\-_\s]+$/, 'Project name contains invalid characters')
};

// API request schemas
const apiSchemas = {
  createProject: z.object({
    name: commonSchemas.projectName,
    description: z.string().max(500).optional(),
    githubRepo: commonSchemas.githubRepo.optional(),
    framework: z.enum(['nodejs', 'python', 'golang', 'rust']).optional(),
    envVars: z.record(commonSchemas.envVarName, z.string()).optional()
  }),

  updateProject: z.object({
    name: commonSchemas.projectName.optional(),
    description: z.string().max(500).optional(),
    envVars: z.record(commonSchemas.envVarName, z.string()).optional()
  }),

  createDeployment: z.object({
    projectId: commonSchemas.uuid,
    commitSha: z.string().regex(/^[a-f0-9]{40}$/, 'Invalid commit SHA').optional()
  })
};

// Validation middleware
const validateBody = <T>(schema: z.ZodSchema<T>) => {
  return (req: Request, res: Response, next: NextFunction) => {
    try {
      req.body = schema.parse(req.body);
      next();
    } catch (error) {
      if (error instanceof z.ZodError) {
        res.status(400).json({
          success: false,
          error: {
            code: 'VALIDATION_ERROR',
            message: 'Invalid request data',
            details: error.issues.map(issue => ({
              field: issue.path.join('.'),
              message: issue.message
            }))
          }
        });
      } else {
        next(error);
      }
    }
  };
};

// Usage in routes
app.post('/api/projects', 
  authMiddleware,
  validateBody(apiSchemas.createProject),
  async (req: AuthenticatedRequest, res: Response) => {
    const project = await projectService.create(req.user.id, req.body);
    res.status(201).json({ success: true, data: project });
  }
);

// SQL injection prevention (even with ORM)
class SafeQueryBuilder {
  static buildUserProjectsQuery(userId: string, filters: ProjectFilters) {
    // Always use parameterized queries
    const where: Prisma.ProjectWhereInput = {
      userId,
      ...(filters.status && { status: filters.status }),
      ...(filters.framework && { framework: filters.framework }),
      ...(filters.search && {
        OR: [
          { name: { contains: filters.search, mode: 'insensitive' } },
          { description: { contains: filters.search, mode: 'insensitive' } }
        ]
      })
    };

    return where;
  }
}
```

## 🔍 Monitoring & Observability Best Practices

### Application Performance Monitoring

#### Comprehensive Metrics Collection
```typescript
// Custom metrics with Prometheus
import { register, Counter, Histogram, Gauge } from 'prom-client';

class MetricsService {
  private readonly httpRequestDuration = new Histogram({
    name: 'http_request_duration_seconds',
    help: 'Duration of HTTP requests in seconds',
    labelNames: ['method', 'route', 'status_code'],
    buckets: [0.1, 0.3, 0.5, 0.7, 1, 3, 5, 7, 10]
  });

  private readonly httpRequestTotal = new Counter({
    name: 'http_requests_total',
    help: 'Total number of HTTP requests',
    labelNames: ['method', 'route', 'status_code']
  });

  private readonly deploymentDuration = new Histogram({
    name: 'deployment_duration_seconds',
    help: 'Duration of deployments in seconds',
    labelNames: ['project_id', 'status'],
    buckets: [30, 60, 120, 300, 600, 1200, 1800]
  });

  private readonly activeDeployments = new Gauge({
    name: 'active_deployments',
    help: 'Number of active deployments',
    labelNames: ['status']
  });

  private readonly databaseConnections = new Gauge({
    name: 'database_connections_active',
    help: 'Number of active database connections'
  });

  constructor() {
    // Register all metrics
    register.registerMetric(this.httpRequestDuration);
    register.registerMetric(this.httpRequestTotal);
    register.registerMetric(this.deploymentDuration);
    register.registerMetric(this.activeDeployments);
    register.registerMetric(this.databaseConnections);
  }

  // Middleware for HTTP metrics
  httpMetricsMiddleware() {
    return (req: Request, res: Response, next: NextFunction) => {
      const start = Date.now();
      
      res.on('finish', () => {
        const duration = (Date.now() - start) / 1000;
        const labels = {
          method: req.method,
          route: req.route?.path || req.path,
          status_code: res.statusCode.toString()
        };
        
        this.httpRequestDuration.observe(labels, duration);
        this.httpRequestTotal.inc(labels);
      });
      
      next();
    };
  }

  recordDeployment(projectId: string, status: string, duration: number) {
    this.deploymentDuration.observe({ project_id: projectId, status }, duration);
  }

  updateActiveDeployments(status: string, count: number) {
    this.activeDeployments.set({ status }, count);
  }

  updateDatabaseConnections(count: number) {
    this.databaseConnections.set(count);
  }
}

// Health checks
class HealthCheckService {
  async checkHealth(): Promise<HealthStatus> {
    const checks = await Promise.allSettled([
      this.checkDatabase(),
      this.checkRedis(),
      this.checkKubernetes(),
      this.checkExternalServices()
    ]);

    const results = checks.map((check, index) => ({
      name: ['database', 'redis', 'kubernetes', 'external'][index],
      status: check.status === 'fulfilled' ? 'healthy' : 'unhealthy',
      message: check.status === 'fulfilled' ? 'OK' : check.reason?.message,
      responseTime: check.status === 'fulfilled' ? check.value.responseTime : null
    }));

    const overallStatus = results.every(r => r.status === 'healthy') ? 'healthy' : 'unhealthy';

    return {
      status: overallStatus,
      timestamp: new Date().toISOString(),
      checks: results,
      uptime: process.uptime(),
      version: process.env.APP_VERSION || 'unknown'
    };
  }

  private async checkDatabase(): Promise<{ responseTime: number }> {
    const start = Date.now();
    await prisma.$queryRaw`SELECT 1`;
    return { responseTime: Date.now() - start };
  }

  private async checkRedis(): Promise<{ responseTime: number }> {
    const start = Date.now();
    await redis.ping();
    return { responseTime: Date.now() - start };
  }

  private async checkKubernetes(): Promise<{ responseTime: number }> {
    const start = Date.now();
    const k8sApi = kc.makeApiClient(CoreV1Api);
    await k8sApi.listNamespace();
    return { responseTime: Date.now() - start };
  }

  private async checkExternalServices(): Promise<{ responseTime: number }> {
    const start = Date.now();
    // Check GitHub API connectivity
    const response = await fetch('https://api.github.com/rate_limit');
    if (!response.ok) throw new Error(`GitHub API error: ${response.status}`);
    return { responseTime: Date.now() - start };
  }
}
```

### Structured Logging

#### Production Logging Strategy
```typescript
// Winston logger configuration
import winston from 'winston';

const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  defaultMeta: {
    service: 'railway-platform',
    version: process.env.APP_VERSION,
    environment: process.env.NODE_ENV
  },
  transports: [
    // Console transport for development
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.colorize(),
        winston.format.simple()
      )
    }),

    // File transport for production
    new winston.transports.File({
      filename: 'logs/error.log',
      level: 'error',
      maxsize: 5242880, // 5MB
      maxFiles: 5
    }),

    new winston.transports.File({
      filename: 'logs/combined.log',
      maxsize: 5242880, // 5MB
      maxFiles: 10
    })
  ]
});

// Centralized logging service
class LoggingService {
  static logUserAction(userId: string, action: string, details: Record<string, any>) {
    logger.info('User action', {
      userId,
      action,
      details,
      timestamp: new Date().toISOString()
    });
  }

  static logDeployment(deployment: Deployment, status: string, details: Record<string, any>) {
    logger.info('Deployment event', {
      deploymentId: deployment.id,
      projectId: deployment.projectId,
      status,
      details,
      timestamp: new Date().toISOString()
    });
  }

  static logSecurityEvent(event: SecurityEvent) {
    logger.warn('Security event', {
      type: event.type,
      severity: event.severity,
      userId: event.userId,
      ip: event.ip,
      details: event.details,
      timestamp: event.timestamp
    });
  }

  static logError(error: Error, context: Record<string, any>) {
    logger.error('Application error', {
      message: error.message,
      stack: error.stack,
      context,
      timestamp: new Date().toISOString()
    });
  }

  static logPerformance(operation: string, duration: number, metadata: Record<string, any>) {
    logger.info('Performance metric', {
      operation,
      duration,
      metadata,
      timestamp: new Date().toISOString()
    });
  }
}

// Request logging middleware
const requestLoggingMiddleware = (req: Request, res: Response, next: NextFunction) => {
  const start = Date.now();
  const requestId = crypto.randomUUID();
  
  req.requestId = requestId;
  res.setHeader('X-Request-ID', requestId);

  logger.info('Request started', {
    requestId,
    method: req.method,
    url: req.url,
    userAgent: req.get('User-Agent'),
    ip: req.ip,
    userId: req.user?.id
  });

  res.on('finish', () => {
    const duration = Date.now() - start;
    
    logger.info('Request completed', {
      requestId,
      method: req.method,
      url: req.url,
      statusCode: res.statusCode,
      duration,
      userId: req.user?.id
    });
  });

  next();
};
```

## 📈 Performance Optimization Best Practices

### Database Optimization

#### Query Performance Tuning
```sql
-- Index optimization examples
-- Composite indexes for common query patterns
CREATE INDEX CONCURRENTLY idx_deployments_project_status_created 
ON deployments(project_id, status, created_at DESC);

CREATE INDEX CONCURRENTLY idx_projects_user_status_updated 
ON projects(user_id, status, updated_at DESC);

-- Partial indexes for filtered queries
CREATE INDEX CONCURRENTLY idx_active_projects 
ON projects(user_id, created_at DESC) 
WHERE status = 'active';

-- GIN indexes for JSONB queries
CREATE INDEX CONCURRENTLY idx_projects_env_vars_gin 
ON projects USING gin(env_vars);

-- Performance monitoring queries
-- Find slow queries
SELECT 
  query,
  calls,
  total_time,
  mean_time,
  rows,
  100.0 * shared_blks_hit / nullif(shared_blks_hit + shared_blks_read, 0) AS hit_percent
FROM pg_stat_statements 
ORDER BY total_time DESC 
LIMIT 10;

-- Check index usage
SELECT 
  schemaname,
  tablename,
  indexname,
  idx_tup_read,
  idx_tup_fetch,
  idx_scan
FROM pg_stat_user_indexes 
ORDER BY idx_scan DESC;
```

### Application Caching Strategy

#### Multi-Layer Caching Implementation
```typescript
// Redis caching service
class CacheService {
  private readonly redis: Redis;
  private readonly defaultTTL = 300; // 5 minutes

  constructor() {
    this.redis = new Redis(process.env.REDIS_URL!);
  }

  // Application-level caching
  async get<T>(key: string): Promise<T | null> {
    try {
      const value = await this.redis.get(key);
      return value ? JSON.parse(value) : null;
    } catch (error) {
      logger.error('Cache get error', { key, error });
      return null;
    }
  }

  async set<T>(key: string, value: T, ttl = this.defaultTTL): Promise<void> {
    try {
      await this.redis.setex(key, ttl, JSON.stringify(value));
    } catch (error) {
      logger.error('Cache set error', { key, error });
    }
  }

  async invalidate(pattern: string): Promise<void> {
    try {
      const keys = await this.redis.keys(pattern);
      if (keys.length > 0) {
        await this.redis.del(...keys);
      }
    } catch (error) {
      logger.error('Cache invalidation error', { pattern, error });
    }
  }

  // Cache-aside pattern for user projects
  async getUserProjects(userId: string): Promise<Project[]> {
    const cacheKey = `user:${userId}:projects`;
    
    // Try cache first
    let projects = await this.get<Project[]>(cacheKey);
    
    if (!projects) {
      // Cache miss - fetch from database
      projects = await prisma.project.findMany({
        where: { userId },
        include: {
          deployments: {
            orderBy: { createdAt: 'desc' },
            take: 1
          }
        },
        orderBy: { createdAt: 'desc' }
      });
      
      // Store in cache
      await this.set(cacheKey, projects, 600); // 10 minutes
    }
    
    return projects;
  }

  // Write-through pattern for project updates
  async updateProject(projectId: string, data: UpdateProjectData): Promise<Project> {
    const project = await prisma.project.update({
      where: { id: projectId },
      data,
      include: {
        deployments: {
          orderBy: { createdAt: 'desc' },
          take: 1
        }
      }
    });

    // Update cache
    const cacheKey = `project:${projectId}`;
    await this.set(cacheKey, project);
    
    // Invalidate related caches
    await this.invalidate(`user:${project.userId}:projects`);
    
    return project;
  }
}

// In-memory caching with node-cache
import NodeCache from 'node-cache';

class MemoryCache {
  private cache = new NodeCache({
    stdTTL: 300, // 5 minutes default
    checkperiod: 60, // Check for expired keys every minute
    useClones: false // Return references for better performance
  });

  // Cache expensive computations
  async getOrCompute<T>(
    key: string,
    computeFn: () => Promise<T>,
    ttl = 300
  ): Promise<T> {
    let value = this.cache.get<T>(key);
    
    if (value === undefined) {
      value = await computeFn();
      this.cache.set(key, value, ttl);
    }
    
    return value;
  }

  // Example: Cache user dashboard data
  async getUserDashboard(userId: string): Promise<DashboardData> {
    return this.getOrCompute(
      `dashboard:${userId}`,
      async () => {
        const [projects, deployments, usage] = await Promise.all([
          prisma.project.count({ where: { userId } }),
          prisma.deployment.count({
            where: { project: { userId } }
          }),
          this.getUserResourceUsage(userId)
        ]);
        
        return { projects, deployments, usage };
      },
      180 // 3 minutes
    );
  }
}
```

### Frontend Performance Optimization

#### React Performance Best Practices
```typescript
// Optimized React components
import { memo, useMemo, useCallback, useState, useEffect } from 'react';

// Memoized component to prevent unnecessary re-renders
const ProjectCard = memo<ProjectCardProps>(({ project, onDeploy }) => {
  const deploymentStatus = useMemo(() => {
    const latestDeployment = project.deployments[0];
    return latestDeployment?.status || 'idle';
  }, [project.deployments]);

  const handleDeploy = useCallback(() => {
    onDeploy(project.id);
  }, [project.id, onDeploy]);

  return (
    <div className="project-card">
      <h3>{project.name}</h3>
      <StatusBadge status={deploymentStatus} />
      <button onClick={handleDeploy}>Deploy</button>
    </div>
  );
});

// Virtual scrolling for large lists
import { FixedSizeList as List } from 'react-window';

const ProjectList: React.FC<{ projects: Project[] }> = ({ projects }) => {
  const Row = useCallback(({ index, style }: { index: number; style: React.CSSProperties }) => (
    <div style={style}>
      <ProjectCard project={projects[index]} onDeploy={handleDeploy} />
    </div>
  ), [projects]);

  return (
    <List
      height={600}
      itemCount={projects.length}
      itemSize={120}
      width="100%"
    >
      {Row}
    </List>
  );
};

// Optimized data fetching with SWR
import useSWR from 'swr';

const useProjects = (userId: string) => {
  const { data, error, mutate } = useSWR(
    `/api/users/${userId}/projects`,
    fetcher,
    {
      revalidateOnFocus: false,
      revalidateOnReconnect: true,
      dedupingInterval: 60000, // Dedupe requests within 1 minute
      errorRetryCount: 3
    }
  );

  return {
    projects: data?.projects || [],
    isLoading: !error && !data,
    isError: error,
    mutate
  };
};

// Code splitting with lazy loading
import { lazy, Suspense } from 'react';

const ProjectSettings = lazy(() => import('./ProjectSettings'));
const DeploymentLogs = lazy(() => import('./DeploymentLogs'));

const App: React.FC = () => {
  return (
    <Router>
      <Routes>
        <Route path="/projects/:id/settings" element={
          <Suspense fallback={<LoadingSpinner />}>
            <ProjectSettings />
          </Suspense>
        } />
        <Route path="/projects/:id/logs" element={
          <Suspense fallback={<LoadingSpinner />}>
            <DeploymentLogs />
          </Suspense>
        } />
      </Routes>
    </Router>
  );
};
```

## 🔄 Navigation

**Previous**: [Security Considerations](./security-considerations.md) | **Next**: [Research Overview](../README.md)

---

*Best Practices | Research completed: January 2025*