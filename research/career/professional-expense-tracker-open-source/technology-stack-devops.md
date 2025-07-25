# Technology Stack & DevOps Pipeline

## 🛠️ Modern Technology Stack

### Frontend Technologies

#### Web Application Stack

**Next.js 14 + React 18**

- **Server-Side Rendering (SSR)**: Improved SEO and initial load performance
- **Static Site Generation (SSG)**: Pre-built pages for optimal performance
- **App Router**: Modern file-based routing with layouts
- **React Server Components**: Reduced client-side JavaScript bundle

**TypeScript 5.0+**

- **Strict Type Safety**: Comprehensive type checking and inference
- **Modern ES Features**: Latest JavaScript features with type support
- **Developer Experience**: Enhanced IDE support and error detection
- **API Type Safety**: End-to-end type safety from API to UI

**Styling & UI Framework**

```json
{
  "ui-libraries": {
    "primary": "Tailwind CSS 3.0",
    "components": "Headless UI + Radix UI",
    "animations": "Framer Motion",
    "icons": "Lucide React + Heroicons"
  }
}
```

**State Management**

- **Zustand**: Lightweight state management for client state
- **TanStack Query (React Query)**: Server state management and caching
- **React Hook Form**: Form state and validation
- **Jotai**: Atomic state management for complex state

#### Mobile Application

**React Native with Expo**

- **Cross-platform Development**: iOS and Android from single codebase
- **Native Performance**: Near-native performance with optimized components
- **Expo SDK**: Comprehensive set of APIs and services
- **Over-the-Air Updates**: Deploy updates without app store approval

### Backend Technologies

#### API Server Architecture

**Node.js + Express.js/Fastify**

```typescript
// Backend Technology Configuration
interface BackendStack {
  runtime: 'Node.js 20 LTS';
  framework: 'Express.js' | 'Fastify';
  language: 'TypeScript 5.0+';
  validation: 'Zod' | 'Joi';
  documentation: 'OpenAPI 3.0 + Swagger';
}

// Alternative: NestJS for enterprise-grade applications
interface EnterpriseStack {
  framework: 'NestJS';
  architecture: 'Modular + Dependency Injection';
  decorators: 'TypeScript Decorators';
  validation: 'class-validator + class-transformer';
}
```

**API Design & Documentation**

- **RESTful API**: Standard REST conventions with resource-based URLs
- **OpenAPI 3.0**: Comprehensive API documentation and specification
- **Swagger UI**: Interactive API documentation interface
- **Postman Collections**: Pre-configured API testing collections

#### Authentication & Authorization

**Auth0 / NextAuth.js**

```typescript
// Authentication Configuration
interface AuthConfig {
  providers: {
    email: 'Email/Password with verification';
    oauth: ['Google', 'GitHub', 'Apple'];
    twoFactor: 'TOTP with authenticator apps';
  };
  jwt: {
    algorithm: 'RS256';
    expiration: '15m access, 7d refresh';
    rotation: true;
  };
  session: {
    storage: 'Database sessions';
    security: 'httpOnly cookies + CSRF protection';
  };
}
```

### Database & Data Layer

#### Primary Database

**PostgreSQL 15+**

- **ACID Compliance**: Reliable transaction processing
- **JSON Support**: Native JSON/JSONB for flexible data structures
- **Full-Text Search**: Built-in search capabilities
- **Extensibility**: PostGIS for location data, pg_cron for scheduling

**Database Schema Design**

```sql
-- Example Core Tables
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email VARCHAR(255) UNIQUE NOT NULL,
  password_hash VARCHAR(255),
  profile JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE expenses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  amount DECIMAL(12,2) NOT NULL,
  currency VARCHAR(3) NOT NULL,
  description TEXT NOT NULL,
  category_id UUID REFERENCES categories(id),
  expense_date DATE NOT NULL,
  metadata JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_expenses_user_date ON expenses(user_id, expense_date);
CREATE INDEX idx_expenses_category ON expenses(category_id);
```

#### ORM & Query Builder

**Prisma ORM**

```typescript
// Prisma Schema Example
model User {
  id        String   @id @default(cuid())
  email     String   @unique
  expenses  Expense[]
  budgets   Budget[]
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt

  @@map("users")
}

model Expense {
  id          String   @id @default(cuid())
  amount      Decimal  @db.Decimal(12, 2)
  currency    String   @db.VarChar(3)
  description String
  categoryId  String?
  userId      String
  date        DateTime @db.Date
  
  user        User      @relation(fields: [userId], references: [id])
  category    Category? @relation(fields: [categoryId], references: [id])

  @@map("expenses")
}
```

**Alternative: TypeORM/Drizzle**

- **TypeORM**: Decorator-based ORM with Active Record pattern
- **Drizzle**: Type-safe SQL query builder with excellent TypeScript integration

#### Caching & Performance

**Redis**

- **Session Storage**: User session management
- **API Caching**: Frequently accessed data caching
- **Rate Limiting**: API rate limiting and throttling
- **Real-time Features**: Pub/Sub for live updates

### DevOps & Infrastructure

#### Containerization

**Docker Configuration**

```dockerfile
# Frontend Dockerfile
FROM node:20-alpine AS base
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

FROM base AS build
COPY . .
RUN npm run build

FROM nginx:alpine AS production
COPY --from=build /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/nginx.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

**Docker Compose for Development**

```yaml
version: '3.8'
services:
  web:
    build: ./apps/web-app
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=development
    volumes:
      - ./apps/web-app:/app
      - /app/node_modules
    depends_on:
      - api
      - database

  api:
    build: ./apps/api-server
    ports:
      - "4000:4000"
    environment:
      - DATABASE_URL=postgresql://user:pass@database:5432/expensetracker
      - REDIS_URL=redis://redis:6379
    depends_on:
      - database
      - redis

  database:
    image: postgres:15-alpine
    environment:
      - POSTGRES_DB=expensetracker
      - POSTGRES_USER=user
      - POSTGRES_PASSWORD=pass
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"

volumes:
  postgres_data:
```

#### CI/CD Pipeline

**GitHub Actions Workflow**

```yaml
name: CI/CD Pipeline

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

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
          node-version: '20'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Run linting
        run: nx lint

      - name: Run type checking
        run: nx type-check

      - name: Run unit tests
        run: nx test --coverage

      - name: Run E2E tests
        run: nx e2e

      - name: Upload coverage reports
        uses: codecov/codecov-action@v3

  build:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Build applications
        run: |
          nx build web-app
          nx build api-server

      - name: Build Docker images
        run: |
          docker build -t expense-tracker-web ./apps/web-app
          docker build -t expense-tracker-api ./apps/api-server

  deploy:
    needs: [test, build]
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - name: Deploy to staging
        run: echo "Deploy to staging environment"
      
      - name: Run smoke tests
        run: echo "Run smoke tests"
      
      - name: Deploy to production
        run: echo "Deploy to production environment"
```

#### Infrastructure as Code

**Terraform Configuration**

```hcl
# AWS Infrastructure Setup
provider "aws" {
  region = var.aws_region
}

# ECS Cluster for container orchestration
resource "aws_ecs_cluster" "expense_tracker" {
  name = "expense-tracker-cluster"
}

# RDS PostgreSQL instance
resource "aws_db_instance" "postgres" {
  identifier     = "expense-tracker-db"
  engine         = "postgres"
  engine_version = "15.4"
  instance_class = "db.t3.micro"
  
  allocated_storage     = 20
  max_allocated_storage = 100
  storage_encrypted     = true
  
  db_name  = "expensetracker"
  username = var.db_username
  password = var.db_password
  
  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"
  
  skip_final_snapshot = false
  deletion_protection = true
}

# ElastiCache Redis cluster
resource "aws_elasticache_cluster" "redis" {
  cluster_id         = "expense-tracker-cache"
  engine             = "redis"
  node_type         = "cache.t3.micro"
  num_cache_nodes   = 1
  parameter_group_name = "default.redis7"
  port              = 6379
}
```

### Testing Strategy

#### Testing Pyramid

**Unit Testing (70%)**

```typescript
// Jest + Testing Library Example
import { render, screen, fireEvent } from '@testing-library/react';
import { ExpenseForm } from './ExpenseForm';

describe('ExpenseForm', () => {
  it('should submit expense with valid data', async () => {
    const onSubmit = jest.fn();
    render(<ExpenseForm onSubmit={onSubmit} />);
    
    fireEvent.change(screen.getByLabelText(/amount/i), {
      target: { value: '25.99' }
    });
    fireEvent.change(screen.getByLabelText(/description/i), {
      target: { value: 'Coffee' }
    });
    
    fireEvent.click(screen.getByRole('button', { name: /save/i }));
    
    await waitFor(() => {
      expect(onSubmit).toHaveBeenCalledWith({
        amount: 25.99,
        description: 'Coffee'
      });
    });
  });
});
```

**Integration Testing (20%)**

```typescript
// API Integration Tests
import request from 'supertest';
import { app } from '../app';

describe('Expenses API', () => {
  it('should create new expense', async () => {
    const response = await request(app)
      .post('/api/expenses')
      .set('Authorization', `Bearer ${authToken}`)
      .send({
        amount: 50.00,
        description: 'Lunch',
        categoryId: 'food-category-id'
      });
    
    expect(response.status).toBe(201);
    expect(response.body.amount).toBe(50.00);
  });
});
```

**E2E Testing (10%)**

```typescript
// Playwright E2E Tests
import { test, expect } from '@playwright/test';

test('complete expense creation flow', async ({ page }) => {
  await page.goto('/login');
  await page.fill('[data-testid=email]', 'user@example.com');
  await page.fill('[data-testid=password]', 'password');
  await page.click('[data-testid=login-button]');
  
  await page.click('[data-testid=add-expense]');
  await page.fill('[data-testid=amount]', '29.99');
  await page.fill('[data-testid=description]', 'Dinner');
  await page.selectOption('[data-testid=category]', 'food');
  await page.click('[data-testid=save-expense]');
  
  await expect(page.locator('[data-testid=expense-list]')).toContainText('Dinner');
});
```

### Monitoring & Observability

#### Application Monitoring

**Sentry for Error Tracking**

```typescript
import * as Sentry from '@sentry/nextjs';

Sentry.init({
  dsn: process.env.SENTRY_DSN,
  environment: process.env.NODE_ENV,
  tracesSampleRate: 1.0,
  beforeSend(event) {
    // Filter sensitive information
    return event;
  }
});
```

**Analytics & Performance**

- **Vercel Analytics**: Web vitals and performance monitoring
- **Mixpanel/PostHog**: User behavior analytics
- **DataDog/New Relic**: Infrastructure monitoring
- **Lighthouse CI**: Automated performance auditing

### Security Implementation

#### Security Best Practices

**Authentication Security**

```typescript
// JWT Configuration
const jwtConfig = {
  accessTokenExpiry: '15m',
  refreshTokenExpiry: '7d',
  algorithm: 'RS256',
  issuer: 'expense-tracker-api',
  audience: 'expense-tracker-client'
};

// Rate Limiting
const rateLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // Limit each IP to 100 requests per windowMs
  message: 'Too many requests from this IP'
});
```

**Data Protection**

- **Encryption at Rest**: Database encryption using AWS KMS
- **Encryption in Transit**: TLS 1.3 for all communications
- **Input Validation**: Comprehensive input sanitization
- **SQL Injection Prevention**: Parameterized queries and ORM usage

#### Compliance & Auditing

**Security Standards**

- **OWASP Top 10**: Address all major web security risks
- **SOC 2 Type II**: Security, availability, and confidentiality controls
- **GDPR Compliance**: European data protection regulations
- **PCI DSS**: Payment card industry security standards

---

## 🔗 Navigation

| Previous | Current | Next |
|----------|---------|------|
| [← Expense Tracker Features](./expense-tracker-features.md) | **Technology Stack & DevOps** | [Portfolio Best Practices →](./portfolio-best-practices.md) |

---

## 📚 References

- [Next.js 14 Documentation](https://nextjs.org/docs)
- [Nx Monorepo Tools](https://nx.dev/)
- [Docker Best Practices](https://docs.docker.com/develop/best-practices/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [OWASP Security Guidelines](https://owasp.org/www-project-top-ten/)
