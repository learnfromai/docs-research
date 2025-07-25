# Microservices Organization in Monorepo

## Overview

Organizing microservices within a monorepo provides unique advantages for personal projects, enabling shared code, unified tooling, and simplified deployment while maintaining service autonomy and scalability.

## Service Architecture Strategy

### Service Categorization

```typescript
// Service types and their responsibilities
interface ServiceCategory {
  core: {          // Essential business services
    userService: 'User management and authentication';
    expenseService: 'Expense CRUD operations';
    categoryService: 'Category management';
  };
  
  integration: {   // External service integrations
    notificationService: 'Email/SMS notifications';
    analyticsService: 'Usage tracking and insights';
    reportingService: 'Financial report generation';
  };
  
  utility: {       // Supporting services
    fileUploadService: 'Receipt and document handling';
    auditService: 'Activity logging and compliance';
    searchService: 'Full-text search capabilities';
  };
}
```

### Directory Structure

```text
apps/
├── microservices/
│   ├── user-service/
│   │   ├── src/
│   │   │   ├── controllers/
│   │   │   ├── services/
│   │   │   ├── repositories/
│   │   │   ├── middleware/
│   │   │   └── main.ts
│   │   ├── Dockerfile
│   │   ├── docker-compose.yml
│   │   └── project.json
│   │
│   ├── expense-service/
│   │   ├── src/
│   │   │   ├── controllers/
│   │   │   │   ├── expense.controller.ts
│   │   │   │   └── category.controller.ts
│   │   │   ├── services/
│   │   │   │   ├── expense.service.ts
│   │   │   │   └── validation.service.ts
│   │   │   ├── repositories/
│   │   │   │   └── expense.repository.ts
│   │   │   ├── dto/
│   │   │   │   ├── create-expense.dto.ts
│   │   │   │   └── update-expense.dto.ts
│   │   │   └── main.ts
│   │   ├── Dockerfile
│   │   └── project.json
│   │
│   ├── notification-service/
│   ├── analytics-service/
│   ├── file-upload-service/
│   └── api-gateway/
│
├── lambda-functions/
│   ├── expense-processor/
│   ├── report-generator/
│   ├── data-sync/
│   └── scheduled-tasks/
│
└── clients/
    ├── web-pwa/
    ├── mobile-app/
    └── admin-dashboard/
```

## Service Implementation Patterns

### 1. Express.js Microservice Template

```typescript
// apps/microservices/expense-service/src/main.ts
import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import { ExpenseController } from './controllers/expense.controller';
import { DatabaseConnection } from '@expense-tracker/database';
import { createLogger } from '@expense-tracker/utils';

const app = express();
const logger = createLogger('expense-service');

// Middleware
app.use(helmet());
app.use(cors());
app.use(express.json());

// Health check
app.get('/health', (req, res) => {
  res.json({ 
    status: 'healthy', 
    service: 'expense-service',
    timestamp: new Date().toISOString() 
  });
});

// Routes
const expenseController = new ExpenseController();
app.use('/api/v1/expenses', expenseController.router);

// Error handling
app.use((error: Error, req: express.Request, res: express.Response, next: express.NextFunction) => {
  logger.error('Unhandled error:', error);
  res.status(500).json({ error: 'Internal server error' });
});

const PORT = process.env.PORT || 3001;

async function startServer() {
  try {
    await DatabaseConnection.initialize();
    logger.info('Database connected');
    
    app.listen(PORT, () => {
      logger.info(`Expense service listening on port ${PORT}`);
    });
  } catch (error) {
    logger.error('Failed to start server:', error);
    process.exit(1);
  }
}

startServer();
```

### 2. Service Controller Pattern

```typescript
// apps/microservices/expense-service/src/controllers/expense.controller.ts
import { Router } from 'express';
import { ExpenseService } from '../services/expense.service';
import { CreateExpenseDto, UpdateExpenseDto } from '../dto';
import { validateRequest } from '@expense-tracker/validation';
import { authenticate } from '@expense-tracker/auth';

export class ExpenseController {
  public router = Router();
  private expenseService = new ExpenseService();

  constructor() {
    this.initializeRoutes();
  }

  private initializeRoutes() {
    this.router.get('/', authenticate, this.getExpenses.bind(this));
    this.router.post('/', authenticate, validateRequest(CreateExpenseDto), this.createExpense.bind(this));
    this.router.get('/:id', authenticate, this.getExpenseById.bind(this));
    this.router.put('/:id', authenticate, validateRequest(UpdateExpenseDto), this.updateExpense.bind(this));
    this.router.delete('/:id', authenticate, this.deleteExpense.bind(this));
  }

  async getExpenses(req: any, res: any) {
    try {
      const userId = req.user.id;
      const { page = 1, limit = 10, category, startDate, endDate } = req.query;
      
      const expenses = await this.expenseService.getExpenses({
        userId,
        pagination: { page: Number(page), limit: Number(limit) },
        filters: { category, startDate, endDate }
      });
      
      res.json(expenses);
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  }

  async createExpense(req: any, res: any) {
    try {
      const userId = req.user.id;
      const expenseData = req.body;
      
      const expense = await this.expenseService.createExpense({
        ...expenseData,
        userId
      });
      
      res.status(201).json(expense);
    } catch (error) {
      res.status(400).json({ error: error.message });
    }
  }

  // Additional methods...
}
```

### 3. Service Layer Implementation

```typescript
// apps/microservices/expense-service/src/services/expense.service.ts
import { ExpenseRepository } from '../repositories/expense.repository';
import { Expense, CreateExpenseInput } from '@expense-tracker/expense-core';
import { EventBus } from '@expense-tracker/events';
import { CacheService } from '@expense-tracker/cache';

export interface GetExpensesOptions {
  userId: string;
  pagination: { page: number; limit: number };
  filters: {
    category?: string;
    startDate?: string;
    endDate?: string;
  };
}

export class ExpenseService {
  constructor(
    private expenseRepository = new ExpenseRepository(),
    private eventBus = new EventBus(),
    private cache = new CacheService()
  ) {}

  async createExpense(input: CreateExpenseInput & { userId: string }): Promise<Expense> {
    // Validate business rules
    await this.validateExpenseCreation(input);
    
    // Create expense
    const expense = await this.expenseRepository.create(input);
    
    // Cache invalidation
    await this.cache.deletePattern(`expenses:${input.userId}:*`);
    
    // Emit event for other services
    await this.eventBus.publish('expense.created', {
      expenseId: expense.id,
      userId: expense.userId,
      amount: expense.amount,
      category: expense.category
    });
    
    return expense;
  }

  async getExpenses(options: GetExpensesOptions): Promise<{ 
    expenses: Expense[]; 
    total: number; 
    hasMore: boolean 
  }> {
    const cacheKey = `expenses:${options.userId}:${JSON.stringify(options)}`;
    
    // Try cache first
    const cached = await this.cache.get(cacheKey);
    if (cached) {
      return cached;
    }
    
    // Fetch from database
    const result = await this.expenseRepository.findWithFilters(options);
    
    // Cache result
    await this.cache.set(cacheKey, result, 300); // 5 minutes
    
    return result;
  }

  private async validateExpenseCreation(input: CreateExpenseInput & { userId: string }): Promise<void> {
    // Business rule: Check daily spending limit
    const today = new Date();
    const todayExpenses = await this.expenseRepository.findByDateRange(
      input.userId,
      today,
      today
    );
    
    const dailyTotal = todayExpenses.reduce((sum, exp) => sum + exp.amount, 0);
    const DAILY_LIMIT = 1000; // $1000 daily limit
    
    if (dailyTotal + input.amount > DAILY_LIMIT) {
      throw new Error(`Daily spending limit of $${DAILY_LIMIT} would be exceeded`);
    }
  }
}
```

## Lambda Function Organization

### 1. Serverless Function Structure

```typescript
// apps/lambda-functions/expense-processor/src/handler.ts
import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { ExpenseProcessor } from './expense-processor';
import { createLogger } from '@expense-tracker/utils';

const logger = createLogger('expense-processor-lambda');
const processor = new ExpenseProcessor();

export const handler = async (
  event: APIGatewayProxyEvent
): Promise<APIGatewayProxyResult> => {
  try {
    logger.info('Processing expense event', { event });
    
    const result = await processor.processExpense(JSON.parse(event.body || '{}'));
    
    return {
      statusCode: 200,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
      body: JSON.stringify(result)
    };
  } catch (error) {
    logger.error('Error processing expense:', error);
    
    return {
      statusCode: 500,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
      body: JSON.stringify({ error: 'Internal server error' })
    };
  }
};
```

### 2. Scheduled Lambda Functions

```typescript
// apps/lambda-functions/report-generator/src/scheduled-handler.ts
import { ScheduledEvent } from 'aws-lambda';
import { ReportService } from './report.service';
import { NotificationService } from '@expense-tracker/notifications';

const reportService = new ReportService();
const notificationService = new NotificationService();

export const monthlyReportHandler = async (event: ScheduledEvent) => {
  console.log('Generating monthly reports:', event);
  
  try {
    // Get all active users
    const users = await reportService.getActiveUsers();
    
    // Generate reports in batches
    const batchSize = 10;
    for (let i = 0; i < users.length; i += batchSize) {
      const batch = users.slice(i, i + batchSize);
      
      await Promise.all(
        batch.map(async (user) => {
          const report = await reportService.generateMonthlyReport(user.id);
          await notificationService.sendReportEmail(user.email, report);
        })
      );
    }
    
    console.log(`Monthly reports generated for ${users.length} users`);
  } catch (error) {
    console.error('Error generating monthly reports:', error);
    throw error;
  }
};
```

## Service Communication Patterns

### 1. Event-Driven Communication

```typescript
// packages/shared/events/src/event-bus.ts
export interface DomainEvent {
  id: string;
  type: string;
  data: any;
  timestamp: Date;
  source: string;
}

export class EventBus {
  async publish(eventType: string, data: any, source = 'unknown'): Promise<void> {
    const event: DomainEvent = {
      id: generateEventId(),
      type: eventType,
      data,
      timestamp: new Date(),
      source
    };
    
    // Publish to message queue (SQS, RabbitMQ, etc.)
    await this.publishToQueue(event);
    
    // Also publish to local event store for debugging
    await this.storeEvent(event);
  }

  async subscribe(eventType: string, handler: (event: DomainEvent) => Promise<void>): Promise<void> {
    // Implementation depends on message queue choice
  }
}

// Event definitions
export const ExpenseEvents = {
  CREATED: 'expense.created',
  UPDATED: 'expense.updated',
  DELETED: 'expense.deleted'
} as const;

export const UserEvents = {
  REGISTERED: 'user.registered',
  PROFILE_UPDATED: 'user.profile.updated',
  DELETED: 'user.deleted'
} as const;
```

### 2. API Gateway Pattern

```typescript
// apps/microservices/api-gateway/src/gateway.ts
import express from 'express';
import httpProxy from 'http-proxy-middleware';
import { authenticate, authorize } from '@expense-tracker/auth';
import { rateLimiter } from '@expense-tracker/rate-limiting';

const app = express();

// Service registry
const services = {
  user: process.env.USER_SERVICE_URL || 'http://localhost:3001',
  expense: process.env.EXPENSE_SERVICE_URL || 'http://localhost:3002',
  notification: process.env.NOTIFICATION_SERVICE_URL || 'http://localhost:3003',
  analytics: process.env.ANALYTICS_SERVICE_URL || 'http://localhost:3004'
};

// Middleware
app.use(express.json());
app.use(rateLimiter);

// Route to user service
app.use('/api/v1/users', 
  authenticate,
  httpProxy({
    target: services.user,
    changeOrigin: true,
    pathRewrite: {
      '^/api/v1/users': '/api/v1/users'
    }
  })
);

// Route to expense service
app.use('/api/v1/expenses',
  authenticate,
  authorize(['user', 'admin']),
  httpProxy({
    target: services.expense,
    changeOrigin: true,
    pathRewrite: {
      '^/api/v1/expenses': '/api/v1/expenses'
    }
  })
);

// Health check aggregation
app.get('/health', async (req, res) => {
  const healthChecks = await Promise.allSettled([
    fetch(`${services.user}/health`),
    fetch(`${services.expense}/health`),
    fetch(`${services.notification}/health`),
    fetch(`${services.analytics}/health`)
  ]);

  const results = healthChecks.map((check, index) => ({
    service: Object.keys(services)[index],
    status: check.status === 'fulfilled' ? 'healthy' : 'unhealthy',
    error: check.status === 'rejected' ? check.reason : null
  }));

  const allHealthy = results.every(result => result.status === 'healthy');

  res.status(allHealthy ? 200 : 503).json({
    status: allHealthy ? 'healthy' : 'degraded',
    services: results,
    timestamp: new Date().toISOString()
  });
});

export { app };
```

## Database Strategy per Service

### 1. Database per Service Pattern

```typescript
// apps/microservices/user-service/src/database/user.repository.ts
import { Repository } from '@expense-tracker/database';
import { User } from '@expense-tracker/user-core';

export class UserRepository extends Repository<User, string> {
  constructor() {
    super('users', process.env.USER_DB_URL);
  }

  async findByEmail(email: string): Promise<User | null> {
    return this.db.collection('users').findOne({ email });
  }

  async existsByEmail(email: string): Promise<boolean> {
    const count = await this.db.collection('users').countDocuments({ email });
    return count > 0;
  }
}
```

### 2. Shared Database Access Layer

```typescript
// packages/shared/database/src/repository.base.ts
export abstract class Repository<T, ID> {
  protected db: any;

  constructor(
    protected collection: string,
    protected connectionString: string
  ) {
    this.initializeConnection();
  }

  private async initializeConnection() {
    // Database connection logic
  }

  async findById(id: ID): Promise<T | null> {
    return this.db.collection(this.collection).findOne({ _id: id });
  }

  async findAll(filter: any = {}): Promise<T[]> {
    return this.db.collection(this.collection).find(filter).toArray();
  }

  async create(entity: Omit<T, 'id'>): Promise<T> {
    const result = await this.db.collection(this.collection).insertOne(entity);
    return { ...entity, id: result.insertedId } as T;
  }

  async update(id: ID, updates: Partial<T>): Promise<T | null> {
    const result = await this.db.collection(this.collection)
      .findOneAndUpdate(
        { _id: id },
        { $set: updates },
        { returnDocument: 'after' }
      );
    return result.value;
  }

  async delete(id: ID): Promise<boolean> {
    const result = await this.db.collection(this.collection).deleteOne({ _id: id });
    return result.deletedCount > 0;
  }
}
```

## Containerization Strategy

### 1. Docker Configuration per Service

```dockerfile
# apps/microservices/expense-service/Dockerfile
FROM node:18-alpine AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./
COPY nx.json ./
COPY tsconfig*.json ./

# Copy source code
COPY packages/shared packages/shared
COPY apps/microservices/expense-service apps/microservices/expense-service

# Install dependencies and build
RUN npm ci --only=production
RUN npx nx build expense-service

# Production stage
FROM node:18-alpine AS production

WORKDIR /app

# Copy built application
COPY --from=builder /app/dist/apps/microservices/expense-service ./
COPY --from=builder /app/node_modules ./node_modules

# Add health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:${PORT:-3000}/health || exit 1

EXPOSE 3000

CMD ["node", "main.js"]
```

### 2. Docker Compose for Local Development

```yaml
# docker-compose.yml
version: '3.8'

services:
  api-gateway:
    build: ./apps/microservices/api-gateway
    ports:
      - "3000:3000"
    environment:
      - USER_SERVICE_URL=http://user-service:3001
      - EXPENSE_SERVICE_URL=http://expense-service:3002
    depends_on:
      - user-service
      - expense-service

  user-service:
    build: ./apps/microservices/user-service
    ports:
      - "3001:3001"
    environment:
      - DATABASE_URL=mongodb://mongo:27017/users
      - JWT_SECRET=your-secret-key
    depends_on:
      - mongo
      - redis

  expense-service:
    build: ./apps/microservices/expense-service
    ports:
      - "3002:3002"
    environment:
      - DATABASE_URL=mongodb://mongo:27017/expenses
      - REDIS_URL=redis://redis:6379
    depends_on:
      - mongo
      - redis

  notification-service:
    build: ./apps/microservices/notification-service
    ports:
      - "3003:3003"
    environment:
      - EMAIL_SERVICE_URL=http://email-service:3004
      - SMS_SERVICE_URL=http://sms-service:3005

  mongo:
    image: mongo:6.0
    ports:
      - "27017:27017"
    volumes:
      - mongo_data:/data/db

  redis:
    image: redis:7.0-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data

volumes:
  mongo_data:
  redis_data:
```

## Monitoring and Observability

### 1. Service Metrics

```typescript
// packages/shared/monitoring/src/metrics.ts
import { register, Counter, Histogram, Gauge } from 'prom-client';

export class ServiceMetrics {
  private httpRequestDuration = new Histogram({
    name: 'http_request_duration_seconds',
    help: 'Duration of HTTP requests in seconds',
    labelNames: ['service', 'method', 'route', 'status_code']
  });

  private httpRequestTotal = new Counter({
    name: 'http_requests_total',
    help: 'Total number of HTTP requests',
    labelNames: ['service', 'method', 'route', 'status_code']
  });

  private activeConnections = new Gauge({
    name: 'active_connections',
    help: 'Number of active connections',
    labelNames: ['service']
  });

  constructor(private serviceName: string) {
    register.registerMetric(this.httpRequestDuration);
    register.registerMetric(this.httpRequestTotal);
    register.registerMetric(this.activeConnections);
  }

  recordHttpRequest(method: string, route: string, statusCode: number, duration: number) {
    this.httpRequestDuration
      .labels(this.serviceName, method, route, statusCode.toString())
      .observe(duration);
    
    this.httpRequestTotal
      .labels(this.serviceName, method, route, statusCode.toString())
      .inc();
  }

  setActiveConnections(count: number) {
    this.activeConnections.labels(this.serviceName).set(count);
  }

  getMetrics() {
    return register.metrics();
  }
}
```

This comprehensive microservices organization strategy ensures scalable, maintainable, and observable service architecture within your monorepo while maximizing code reuse and development efficiency.
