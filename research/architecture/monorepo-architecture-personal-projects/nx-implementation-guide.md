# Nx Implementation Guide for Expense Tracker Monorepo

## Overview

This guide provides step-by-step instructions for implementing the Expense Tracker MVP using Nx as the monorepo tool. It covers workspace setup, package creation, configuration, and development workflows optimized for AI coding agent effectiveness.

## Prerequisites

### System Requirements

```bash
# Node.js (version 18 or higher)
node --version
# npm version 8 or higher
npm --version
# Git
git --version
```

### Development Tools

```bash
# VS Code with Nx Console extension
code --install-extension nrwl.angular-console

# Optional: GitHub CLI for repository management
gh --version
```

## Phase 1: Workspace Initialization

### Step 1: Create Nx Workspace

```bash
# Create new Nx workspace
npx create-nx-workspace@latest expense-tracker --preset=ts --nx-cloud=true

# Navigate to workspace
cd expense-tracker

# Verify installation
nx --version
```

### Step 2: Workspace Configuration

#### Configure nx.json

```json
{
  "tasksRunnerOptions": {
    "default": {
      "runner": "nx/tasks-runners/default",
      "options": {
        "cacheableOperations": [
          "build",
          "test",
          "lint",
          "e2e",
          "type-check"
        ],
        "parallel": 3,
        "useDaemonProcess": true
      }
    }
  },
  "targetDefaults": {
    "build": {
      "cache": true,
      "dependsOn": ["^build"],
      "inputs": ["production", "^production"]
    },
    "test": {
      "cache": true,
      "inputs": ["default", "^production", "{workspaceRoot}/jest.preset.js"]
    },
    "lint": {
      "cache": true,
      "inputs": [
        "default",
        "{workspaceRoot}/.eslintrc.json",
        "{workspaceRoot}/.eslintignore"
      ]
    }
  },
  "generators": {
    "@nx/react": {
      "application": {
        "babel": true,
        "style": "css",
        "linter": "eslint",
        "bundler": "vite"
      },
      "component": {
        "style": "css"
      },
      "library": {
        "style": "css",
        "linter": "eslint"
      }
    },
    "@nx/node": {
      "application": {
        "linter": "eslint"
      },
      "library": {
        "linter": "eslint"
      }
    }
  }
}
```

#### Configure TypeScript Base Configuration

```json
// tsconfig.base.json
{
  "compileOnSave": false,
  "compilerOptions": {
    "rootDir": ".",
    "sourceMap": true,
    "declaration": false,
    "moduleResolution": "node",
    "emitDecoratorMetadata": true,
    "experimentalDecorators": true,
    "importHelpers": true,
    "target": "es2015",
    "module": "esnext",
    "lib": ["es2020", "dom"],
    "skipLibCheck": true,
    "skipDefaultLibCheck": true,
    "strict": true,
    "baseUrl": ".",
    "paths": {
      "@expense-tracker/shared-types": ["packages/shared-types/src/index.ts"],
      "@expense-tracker/business-logic": ["packages/business-logic/src/index.ts"],
      "@expense-tracker/ui-components": ["packages/ui-components/src/index.ts"],
      "@expense-tracker/api-client": ["packages/api-client/src/index.ts"],
      "@expense-tracker/validation": ["libs/validation/src/index.ts"],
      "@expense-tracker/auth": ["libs/auth/src/index.ts"],
      "@expense-tracker/database": ["libs/database/src/index.ts"],
      "@expense-tracker/config": ["packages/config/src/index.ts"]
    }
  },
  "exclude": ["node_modules", "tmp"]
}
```

### Step 3: Install Core Dependencies

```bash
# Install shared dependencies
npm install --save react react-dom next express
npm install --save-dev @types/react @types/node @types/express

# Install Nx plugins
npm install --save-dev @nx/react @nx/next @nx/node @nx/express @nx/jest @nx/cypress @nx/eslint

# Install additional tools
npm install --save-dev prettier eslint-config-prettier
```

## Phase 2: Shared Libraries Creation

### Step 1: Create Shared Types Library

```bash
# Generate shared types library
nx generate @nx/js:library shared-types --directory=packages --importPath=@expense-tracker/shared-types --tags=scope:shared,type:types
```

#### Setup Shared Types Structure

```typescript
// packages/shared-types/src/entities/expense.ts
export interface Expense {
  id: string;
  userId: string;
  amount: number;
  currency: string;
  category: Category;
  description: string;
  date: Date;
  tags: string[];
  receipt?: Receipt;
  createdAt: Date;
  updatedAt: Date;
}

export interface Category {
  id: string;
  name: string;
  icon: string;
  color: string;
  parentId?: string;
  userId: string;
}

export interface Receipt {
  id: string;
  fileName: string;
  fileUrl: string;
  fileSize: number;
  mimeType: string;
  uploadedAt: Date;
}
```

```typescript
// packages/shared-types/src/api/requests.ts
export interface CreateExpenseRequest {
  amount: number;
  currency: string;
  categoryId: string;
  description: string;
  date: string;
  tags?: string[];
}

export interface UpdateExpenseRequest extends Partial<CreateExpenseRequest> {
  id: string;
}

export interface ExpenseFiltersRequest {
  categoryIds?: string[];
  startDate?: string;
  endDate?: string;
  minAmount?: number;
  maxAmount?: number;
  tags?: string[];
  page?: number;
  limit?: number;
}
```

### Step 2: Create Business Logic Library

```bash
# Generate business logic library
nx generate @nx/js:library business-logic --directory=packages --importPath=@expense-tracker/business-logic --tags=scope:shared,type:logic
```

#### Setup Business Logic Structure

```typescript
// packages/business-logic/src/calculations/expense-calculator.ts
import { Expense } from '@expense-tracker/shared-types';

export class ExpenseCalculator {
  static calculateTotal(expenses: Expense[]): number {
    return expenses.reduce((total, expense) => total + expense.amount, 0);
  }

  static calculateMonthlyAverage(expenses: Expense[]): number {
    if (expenses.length === 0) return 0;
    
    const monthsSet = new Set(
      expenses.map(expense => 
        `${expense.date.getFullYear()}-${expense.date.getMonth()}`
      )
    );
    
    const uniqueMonths = monthsSet.size;
    return uniqueMonths > 0 ? this.calculateTotal(expenses) / uniqueMonths : 0;
  }

  static groupByCategory(expenses: Expense[]): Record<string, Expense[]> {
    return expenses.reduce((groups, expense) => {
      const categoryId = expense.category.id;
      groups[categoryId] = groups[categoryId] || [];
      groups[categoryId].push(expense);
      return groups;
    }, {} as Record<string, Expense[]>);
  }

  static calculateCategoryTotals(expenses: Expense[]): Record<string, number> {
    const grouped = this.groupByCategory(expenses);
    return Object.entries(grouped).reduce((totals, [categoryId, categoryExpenses]) => {
      totals[categoryId] = this.calculateTotal(categoryExpenses);
      return totals;
    }, {} as Record<string, number>);
  }
}
```

```typescript
// packages/business-logic/src/formatters/currency-formatter.ts
export class CurrencyFormatter {
  private static readonly CURRENCY_SYMBOLS: Record<string, string> = {
    USD: '$',
    EUR: '€',
    GBP: '£',
    JPY: '¥',
  };

  static format(amount: number, currency: string): string {
    const symbol = this.CURRENCY_SYMBOLS[currency] || currency;
    return `${symbol}${amount.toFixed(2)}`;
  }

  static formatWithCode(amount: number, currency: string): string {
    return `${amount.toFixed(2)} ${currency}`;
  }

  static parse(formattedAmount: string): { amount: number; currency: string } | null {
    const match = formattedAmount.match(/^([^0-9]*)([0-9,]+\.?[0-9]*)\s*([A-Z]{3})?$/);
    if (!match) return null;

    const [, symbol, amountStr, currencyCode] = match;
    const amount = parseFloat(amountStr.replace(/,/g, ''));
    
    if (currencyCode) {
      return { amount, currency: currencyCode };
    }

    // Try to identify currency by symbol
    const currency = Object.entries(this.CURRENCY_SYMBOLS)
      .find(([, sym]) => sym === symbol)?.[0] || 'USD';
    
    return { amount, currency };
  }
}
```

### Step 3: Create UI Components Library

```bash
# Generate UI components library with React support
nx generate @nx/react:library ui-components --directory=packages --importPath=@expense-tracker/ui-components --tags=scope:shared,type:ui
```

#### Setup UI Components Structure

```typescript
// packages/ui-components/src/components/expense-card/expense-card.tsx
import React from 'react';
import { Expense } from '@expense-tracker/shared-types';
import { CurrencyFormatter } from '@expense-tracker/business-logic';
import './expense-card.css';

interface ExpenseCardProps {
  expense: Expense;
  onEdit?: (expense: Expense) => void;
  onDelete?: (expenseId: string) => void;
  className?: string;
}

export const ExpenseCard: React.FC<ExpenseCardProps> = ({
  expense,
  onEdit,
  onDelete,
  className = '',
}) => {
  const handleEdit = () => onEdit?.(expense);
  const handleDelete = () => onDelete?.(expense.id);

  return (
    <div className={`expense-card ${className}`}>
      <div className="expense-card__header">
        <h3 className="expense-card__description">{expense.description}</h3>
        <span className="expense-card__amount">
          {CurrencyFormatter.format(expense.amount, expense.currency)}
        </span>
      </div>
      
      <div className="expense-card__details">
        <div className="expense-card__category">
          <span 
            className="expense-card__category-icon"
            style={{ backgroundColor: expense.category.color }}
          >
            {expense.category.icon}
          </span>
          <span className="expense-card__category-name">
            {expense.category.name}
          </span>
        </div>
        
        <span className="expense-card__date">
          {expense.date.toLocaleDateString()}
        </span>
      </div>

      {expense.tags.length > 0 && (
        <div className="expense-card__tags">
          {expense.tags.map(tag => (
            <span key={tag} className="expense-card__tag">
              {tag}
            </span>
          ))}
        </div>
      )}

      <div className="expense-card__actions">
        {onEdit && (
          <button 
            className="expense-card__action expense-card__action--edit"
            onClick={handleEdit}
          >
            Edit
          </button>
        )}
        {onDelete && (
          <button 
            className="expense-card__action expense-card__action--delete"
            onClick={handleDelete}
          >
            Delete
          </button>
        )}
      </div>
    </div>
  );
};

export default ExpenseCard;
```

### Step 4: Create API Client Library

```bash
# Generate API client library
nx generate @nx/js:library api-client --directory=packages --importPath=@expense-tracker/api-client --tags=scope:shared,type:api
```

#### Setup API Client Structure

```typescript
// packages/api-client/src/clients/base-client.ts
export class BaseApiClient {
  private baseUrl: string;
  private defaultHeaders: Record<string, string>;

  constructor(baseUrl: string = process.env['NX_API_BASE_URL'] || 'http://localhost:3000/api') {
    this.baseUrl = baseUrl;
    this.defaultHeaders = {
      'Content-Type': 'application/json',
    };
  }

  setAuthToken(token: string): void {
    this.defaultHeaders['Authorization'] = `Bearer ${token}`;
  }

  removeAuthToken(): void {
    delete this.defaultHeaders['Authorization'];
  }

  private async request<T>(
    endpoint: string,
    options: RequestInit = {}
  ): Promise<T> {
    const url = `${this.baseUrl}${endpoint}`;
    const config: RequestInit = {
      ...options,
      headers: {
        ...this.defaultHeaders,
        ...options.headers,
      },
    };

    const response = await fetch(url, config);

    if (!response.ok) {
      const error = await response.json().catch(() => ({ message: 'Unknown error' }));
      throw new Error(error.message || `HTTP ${response.status}`);
    }

    return response.json();
  }

  protected async get<T>(endpoint: string): Promise<T> {
    return this.request<T>(endpoint, { method: 'GET' });
  }

  protected async post<T>(endpoint: string, data?: unknown): Promise<T> {
    return this.request<T>(endpoint, {
      method: 'POST',
      body: data ? JSON.stringify(data) : undefined,
    });
  }

  protected async put<T>(endpoint: string, data?: unknown): Promise<T> {
    return this.request<T>(endpoint, {
      method: 'PUT',
      body: data ? JSON.stringify(data) : undefined,
    });
  }

  protected async delete<T>(endpoint: string): Promise<T> {
    return this.request<T>(endpoint, { method: 'DELETE' });
  }
}
```

```typescript
// packages/api-client/src/clients/expense-client.ts
import { BaseApiClient } from './base-client';
import {
  Expense,
  CreateExpenseRequest,
  UpdateExpenseRequest,
  ExpenseFiltersRequest,
} from '@expense-tracker/shared-types';

export class ExpenseClient extends BaseApiClient {
  async getExpenses(filters?: ExpenseFiltersRequest): Promise<Expense[]> {
    const queryParams = new URLSearchParams();
    
    if (filters) {
      Object.entries(filters).forEach(([key, value]) => {
        if (value !== undefined) {
          if (Array.isArray(value)) {
            value.forEach(v => queryParams.append(key, v.toString()));
          } else {
            queryParams.append(key, value.toString());
          }
        }
      });
    }

    const endpoint = `/expenses${queryParams.toString() ? `?${queryParams}` : ''}`;
    return this.get<Expense[]>(endpoint);
  }

  async getExpense(id: string): Promise<Expense> {
    return this.get<Expense>(`/expenses/${id}`);
  }

  async createExpense(data: CreateExpenseRequest): Promise<Expense> {
    return this.post<Expense>('/expenses', data);
  }

  async updateExpense(id: string, data: UpdateExpenseRequest): Promise<Expense> {
    return this.put<Expense>(`/expenses/${id}`, data);
  }

  async deleteExpense(id: string): Promise<void> {
    return this.delete<void>(`/expenses/${id}`);
  }

  async getExpensesByCategory(categoryId: string): Promise<Expense[]> {
    return this.get<Expense[]>(`/expenses/category/${categoryId}`);
  }

  async getExpenseStats(period: 'month' | 'year' = 'month'): Promise<{
    total: number;
    average: number;
    categoryBreakdown: Record<string, number>;
  }> {
    return this.get(`/expenses/stats?period=${period}`);
  }
}
```

## Phase 3: Application Development

### Step 1: Create Web PWA Application

```bash
# Generate Next.js application for web PWA
nx generate @nx/next:application web-pwa --directory=apps --tags=scope:frontend,type:app
```

#### Configure Next.js for PWA

```javascript
// apps/web-pwa/next.config.js
const withNx = require('@nx/next/plugins/with-nx');

const nextConfig = {
  nx: {
    svgr: false,
  },
  experimental: {
    appDir: true,
  },
  compiler: {
    styledComponents: true,
  },
  env: {
    NX_API_BASE_URL: process.env.NX_API_BASE_URL,
  },
};

module.exports = withNx(nextConfig);
```

#### Setup App Structure

```typescript
// apps/web-pwa/src/app/layout.tsx
import { Metadata } from 'next';
import './global.css';

export const metadata: Metadata = {
  title: 'Expense Tracker',
  description: 'Track your expenses efficiently',
  manifest: '/manifest.json',
  themeColor: '#000000',
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body>
        <div id="root">{children}</div>
      </body>
    </html>
  );
}
```

### Step 2: Create Mobile Application

```bash
# Install React Native plugin
npm install --save-dev @nx/react-native

# Generate React Native application
nx generate @nx/react-native:application mobile --directory=apps --tags=scope:mobile,type:app
```

#### Configure Expo Setup

```json
// apps/mobile/app.json
{
  "expo": {
    "name": "Expense Tracker",
    "slug": "expense-tracker",
    "version": "1.0.0",
    "orientation": "portrait",
    "icon": "./assets/icon.png",
    "userInterfaceStyle": "light",
    "splash": {
      "image": "./assets/splash.png",
      "resizeMode": "contain",
      "backgroundColor": "#ffffff"
    },
    "assetBundlePatterns": ["**/*"],
    "ios": {
      "supportsTablet": true
    },
    "android": {
      "adaptiveIcon": {
        "foregroundImage": "./assets/adaptive-icon.png",
        "backgroundColor": "#ffffff"
      }
    },
    "web": {
      "favicon": "./assets/favicon.png"
    }
  }
}
```

### Step 3: Create API Gateway

```bash
# Generate Express application for API gateway
nx generate @nx/express:application api-gateway --directory=apps --tags=scope:backend,type:app
```

#### Setup Express Configuration

```typescript
// apps/api-gateway/src/main.ts
import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import compression from 'compression';
import { expenseRouter } from './routes/expense-routes';
import { categoryRouter } from './routes/category-routes';
import { authMiddleware } from '@expense-tracker/auth';

const app = express();
const port = process.env.PORT || 3000;

// Middleware
app.use(helmet());
app.use(cors());
app.use(compression());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'OK', timestamp: new Date().toISOString() });
});

// API routes
app.use('/api/expenses', authMiddleware, expenseRouter);
app.use('/api/categories', authMiddleware, categoryRouter);

// Error handling
app.use((err: Error, req: express.Request, res: express.Response, next: express.NextFunction) => {
  console.error(err.stack);
  res.status(500).json({ message: 'Internal server error' });
});

// Start server
app.listen(port, () => {
  console.log(`API Gateway listening on port ${port}`);
});
```

## Phase 4: Development Workflows

### Step 1: Development Scripts

```json
// package.json
{
  "scripts": {
    "dev": "nx run-many --target=serve --projects=web-pwa,mobile,api-gateway --parallel",
    "dev:web": "nx serve web-pwa",
    "dev:mobile": "nx serve mobile",
    "dev:api": "nx serve api-gateway",
    "build": "nx run-many --target=build --all",
    "build:affected": "nx affected --target=build",
    "test": "nx run-many --target=test --all",
    "test:affected": "nx affected --target=test",
    "lint": "nx run-many --target=lint --all",
    "lint:affected": "nx affected --target=lint",
    "e2e": "nx run-many --target=e2e --all",
    "dep-graph": "nx dep-graph",
    "workspace-generator": "nx workspace-generator"
  }
}
```

### Step 2: Development Environment Setup

```bash
# Start all services in development mode
npm run dev

# Start specific services
npm run dev:web     # Starts web PWA on http://localhost:4200
npm run dev:mobile  # Starts Expo dev server
npm run dev:api     # Starts API gateway on http://localhost:3000
```

### Step 3: Code Generation Workflows

```bash
# Generate new shared component
nx generate @nx/react:component expense-form --project=ui-components --export

# Generate new API endpoint
nx generate @nx/node:library expense-service --directory=services --importPath=@expense-tracker/expense-service

# Generate new page component
nx generate @nx/next:page expenses --project=web-pwa --directory=app
```

### Step 4: Testing Workflows

```bash
# Run all tests
npm run test

# Run tests for affected projects only
npm run test:affected

# Run specific project tests
nx test shared-types
nx test business-logic
nx test ui-components

# Run with coverage
nx test ui-components --coverage

# Run in watch mode
nx test ui-components --watch
```

### Step 5: Build and Deployment

```bash
# Build all projects
npm run build

# Build only affected projects
npm run build:affected

# Build specific projects
nx build web-pwa
nx build api-gateway

# Check dependency graph
npm run dep-graph
```

## Development Best Practices

### 1. Package Boundaries

```typescript
// .eslintrc.json
{
  "rules": {
    "@nx/enforce-module-boundaries": [
      "error",
      {
        "enforceBuildableLibDependency": true,
        "allow": [],
        "depConstraints": [
          {
            "sourceTag": "scope:shared",
            "onlyDependOnLibsWithTags": ["scope:shared"]
          },
          {
            "sourceTag": "scope:frontend",
            "onlyDependOnLibsWithTags": ["scope:shared", "scope:frontend"]
          },
          {
            "sourceTag": "scope:backend",
            "onlyDependOnLibsWithTags": ["scope:shared", "scope:backend"]
          }
        ]
      }
    ]
  }
}
```

### 2. Import Organization

```typescript
// Consistent import ordering
import React from 'react';                              // External libraries
import { NextPage } from 'next';                        // Framework imports
import { Expense } from '@expense-tracker/shared-types'; // Shared types
import { ExpenseCalculator } from '@expense-tracker/business-logic'; // Business logic
import { ExpenseCard } from '@expense-tracker/ui-components'; // UI components
import { useExpenses } from '../hooks/use-expenses';     // Local imports
import './expenses-page.css';                           // Styles
```

### 3. Type Safety

```typescript
// Strict TypeScript configuration for all packages
{
  "compilerOptions": {
    "strict": true,
    "noImplicitAny": true,
    "noImplicitReturns": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true
  }
}
```

## Troubleshooting Common Issues

### 1. Module Resolution Issues

```bash
# Clear Nx cache
nx reset

# Reinstall dependencies
rm -rf node_modules package-lock.json
npm install

# Check dependency graph for issues
nx dep-graph
```

### 2. Build Performance Issues

```bash
# Enable daemon for faster builds
nx daemon --start

# Check cache utilization
nx run-many --target=build --all --verbose

# Analyze build performance
nx run web-pwa:build --statsJson
```

### 3. TypeScript Path Mapping Issues

```typescript
// Ensure tsconfig.base.json paths are correctly configured
{
  "paths": {
    "@expense-tracker/*": ["packages/*/src/index.ts", "libs/*/src/index.ts"]
  }
}
```

## Next Steps

1. **Continue with Service Creation**: Implement microservices for authentication, notifications, and analytics
2. **Add Testing Infrastructure**: Set up comprehensive testing with Jest and Cypress
3. **Configure CI/CD**: Implement GitHub Actions workflows for automated building and deployment
4. **Add Monitoring**: Integrate logging and monitoring solutions
5. **Documentation**: Create comprehensive API documentation and development guides

This Nx implementation provides a solid foundation for the Expense Tracker MVP with optimal code sharing, development efficiency, and AI coding agent effectiveness.
