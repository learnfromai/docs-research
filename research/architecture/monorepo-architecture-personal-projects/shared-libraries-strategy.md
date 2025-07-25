# Shared Libraries Strategy for Monorepo

## Overview

Shared libraries are the cornerstone of effective monorepo architecture, enabling code reuse across multiple applications and services while maintaining consistency and reducing duplication.

## Library Types and Categories

### 1. Core Business Logic Libraries

```typescript
// packages/shared/expense-core/src/index.ts
export interface Expense {
  id: string;
  amount: number;
  currency: string;
  category: string;
  description: string;
  date: Date;
  userId: string;
  tags: string[];
}

export class ExpenseCalculator {
  static calculateMonthlyTotal(expenses: Expense[]): number {
    return expenses.reduce((sum, expense) => sum + expense.amount, 0);
  }

  static groupByCategory(expenses: Expense[]): Record<string, Expense[]> {
    return expenses.reduce((groups, expense) => {
      const category = expense.category;
      groups[category] = groups[category] || [];
      groups[category].push(expense);
      return groups;
    }, {} as Record<string, Expense[]>);
  }
}
```

### 2. Validation Libraries

```typescript
// packages/shared/validation/src/expense-validators.ts
import { z } from 'zod';

export const ExpenseSchema = z.object({
  amount: z.number().positive('Amount must be positive'),
  currency: z.string().length(3, 'Currency must be 3 characters'),
  category: z.string().min(1, 'Category is required'),
  description: z.string().min(1, 'Description is required'),
  date: z.date(),
  tags: z.array(z.string()).optional().default([])
});

export const CreateExpenseSchema = ExpenseSchema.omit({ id: true, userId: true });

export type CreateExpenseInput = z.infer<typeof CreateExpenseSchema>;
export type ExpenseInput = z.infer<typeof ExpenseSchema>;
```

### 3. UI Component Libraries

```typescript
// packages/shared/ui-components/src/ExpenseCard.tsx
import React from 'react';
import { Expense } from '@expense-tracker/expense-core';

interface ExpenseCardProps {
  expense: Expense;
  onEdit?: (expense: Expense) => void;
  onDelete?: (expenseId: string) => void;
  variant?: 'compact' | 'detailed';
}

export const ExpenseCard: React.FC<ExpenseCardProps> = ({
  expense,
  onEdit,
  onDelete,
  variant = 'detailed'
}) => {
  return (
    <div className="expense-card" data-testid="expense-card">
      <div className="expense-header">
        <span className="amount">${expense.amount.toFixed(2)}</span>
        <span className="category">{expense.category}</span>
      </div>
      {variant === 'detailed' && (
        <div className="expense-details">
          <p>{expense.description}</p>
          <div className="tags">
            {expense.tags.map(tag => (
              <span key={tag} className="tag">{tag}</span>
            ))}
          </div>
        </div>
      )}
    </div>
  );
};
```

### 4. API Client Libraries

```typescript
// packages/shared/api-client/src/expense-api.ts
import { CreateExpenseInput, Expense } from '@expense-tracker/expense-core';

export class ExpenseApiClient {
  constructor(private baseUrl: string, private apiKey?: string) {}

  async createExpense(expense: CreateExpenseInput): Promise<Expense> {
    const response = await fetch(`${this.baseUrl}/expenses`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        ...(this.apiKey && { 'Authorization': `Bearer ${this.apiKey}` })
      },
      body: JSON.stringify(expense)
    });

    if (!response.ok) {
      throw new Error(`Failed to create expense: ${response.statusText}`);
    }

    return response.json();
  }

  async getExpenses(userId: string): Promise<Expense[]> {
    const response = await fetch(`${this.baseUrl}/expenses?userId=${userId}`, {
      headers: {
        ...(this.apiKey && { 'Authorization': `Bearer ${this.apiKey}` })
      }
    });

    if (!response.ok) {
      throw new Error(`Failed to fetch expenses: ${response.statusText}`);
    }

    return response.json();
  }
}
```

### 5. Utility Libraries

```typescript
// packages/shared/utils/src/date-utils.ts
export class DateUtils {
  static formatCurrency(amount: number, currency: string = 'USD'): string {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency
    }).format(amount);
  }

  static formatDate(date: Date, format: 'short' | 'long' = 'short'): string {
    return new Intl.DateTimeFormat('en-US', {
      dateStyle: format
    }).format(date);
  }

  static getMonthRange(date: Date): { start: Date; end: Date } {
    const start = new Date(date.getFullYear(), date.getMonth(), 1);
    const end = new Date(date.getFullYear(), date.getMonth() + 1, 0);
    return { start, end };
  }
}
```

## Library Organization Strategy

### Package Structure

```text
packages/
├── shared/
│   ├── expense-core/          # Business logic and types
│   ├── validation/            # Schema validation
│   ├── ui-components/         # React components
│   ├── api-client/           # HTTP client utilities
│   ├── utils/                # Utility functions
│   ├── database/             # Database abstractions
│   ├── auth/                 # Authentication utilities
│   └── testing-utils/        # Test helpers
├── apps/
│   ├── web-pwa/
│   ├── mobile/
│   ├── backend-api/
│   └── lambda-services/
└── tools/
    ├── build-scripts/
    ├── deployment/
    └── generators/
```

### Dependency Management

```json
// packages/shared/expense-core/package.json
{
  "name": "@expense-tracker/expense-core",
  "version": "1.0.0",
  "main": "dist/index.js",
  "types": "dist/index.d.ts",
  "dependencies": {
    "zod": "^3.22.0"
  },
  "peerDependencies": {
    "typescript": "^5.0.0"
  }
}
```

## Code Generation for Shared Libraries

### Nx Generator for New Shared Library

```typescript
// tools/generators/shared-lib/index.ts
import { Tree, formatFiles, installPackagesTask, generateFiles, joinPathFragments } from '@nx/devkit';

export interface SharedLibGeneratorSchema {
  name: string;
  directory?: string;
  tags?: string;
  buildable?: boolean;
  publishable?: boolean;
}

export default async function (tree: Tree, options: SharedLibGeneratorSchema) {
  const projectRoot = `packages/shared/${options.name}`;
  
  generateFiles(tree, joinPathFragments(__dirname, 'files'), projectRoot, {
    ...options,
    template: ''
  });

  await formatFiles(tree);
  
  return () => {
    installPackagesTask(tree);
  };
}
```

## Testing Shared Libraries

### Unit Testing Strategy

```typescript
// packages/shared/expense-core/src/expense-calculator.spec.ts
import { ExpenseCalculator } from './expense-calculator';
import { Expense } from './types';

describe('ExpenseCalculator', () => {
  const mockExpenses: Expense[] = [
    {
      id: '1',
      amount: 100,
      currency: 'USD',
      category: 'Food',
      description: 'Lunch',
      date: new Date('2024-01-01'),
      userId: 'user1',
      tags: ['meal']
    },
    {
      id: '2',
      amount: 50,
      currency: 'USD',
      category: 'Transport',
      description: 'Bus fare',
      date: new Date('2024-01-01'),
      userId: 'user1',
      tags: ['commute']
    }
  ];

  describe('calculateMonthlyTotal', () => {
    it('should calculate correct total', () => {
      const total = ExpenseCalculator.calculateMonthlyTotal(mockExpenses);
      expect(total).toBe(150);
    });

    it('should handle empty array', () => {
      const total = ExpenseCalculator.calculateMonthlyTotal([]);
      expect(total).toBe(0);
    });
  });

  describe('groupByCategory', () => {
    it('should group expenses by category', () => {
      const grouped = ExpenseCalculator.groupByCategory(mockExpenses);
      expect(grouped).toEqual({
        Food: [mockExpenses[0]],
        Transport: [mockExpenses[1]]
      });
    });
  });
});
```

### Integration Testing

```typescript
// packages/shared/api-client/src/expense-api.integration.spec.ts
import { ExpenseApiClient } from './expense-api';
import { setupTestServer } from '@expense-tracker/testing-utils';

describe('ExpenseApiClient Integration', () => {
  let client: ExpenseApiClient;
  let server: any;

  beforeAll(async () => {
    server = await setupTestServer();
    client = new ExpenseApiClient(`http://localhost:${server.port}`);
  });

  afterAll(async () => {
    await server.close();
  });

  it('should create and retrieve expenses', async () => {
    const expenseData = {
      amount: 100,
      currency: 'USD',
      category: 'Food',
      description: 'Test expense',
      date: new Date(),
      tags: ['test']
    };

    const created = await client.createExpense(expenseData);
    expect(created.id).toBeDefined();
    expect(created.amount).toBe(100);

    const expenses = await client.getExpenses('test-user');
    expect(expenses).toContainEqual(created);
  });
});
```

## Versioning Strategy

### Semantic Versioning for Libraries

```json
// nx.json
{
  "release": {
    "projects": ["packages/shared/*"],
    "version": {
      "conventionalCommits": true,
      "generatorOptions": {
        "packageRoot": "packages/shared/{projectName}",
        "currentVersionResolver": "git-tag"
      }
    },
    "changelog": {
      "workspaceChangelog": {
        "createRelease": "github"
      }
    }
  }
}
```

### Automated Release Process

```typescript
// tools/scripts/release-shared-libs.ts
import { execSync } from 'child_process';

const SHARED_LIBS = [
  'expense-core',
  'validation',
  'ui-components',
  'api-client',
  'utils'
];

function releaseLibraries() {
  console.log('🚀 Starting shared library release process...');
  
  // Run tests
  execSync('nx run-many --target=test --projects=packages/shared/*', { 
    stdio: 'inherit' 
  });
  
  // Build libraries
  execSync('nx run-many --target=build --projects=packages/shared/*', { 
    stdio: 'inherit' 
  });
  
  // Version and publish
  execSync('nx release', { stdio: 'inherit' });
  
  console.log('✅ Release process completed!');
}

releaseLibraries();
```

## Best Practices

### 1. Circular Dependency Prevention

```typescript
// Use dependency injection to avoid circular dependencies
// packages/shared/expense-core/src/services/expense-service.ts
export interface IExpenseRepository {
  save(expense: Expense): Promise<void>;
  findByUserId(userId: string): Promise<Expense[]>;
}

export class ExpenseService {
  constructor(private repository: IExpenseRepository) {}
  
  async createExpense(input: CreateExpenseInput, userId: string): Promise<Expense> {
    const expense: Expense = {
      id: generateId(),
      ...input,
      userId
    };
    
    await this.repository.save(expense);
    return expense;
  }
}
```

### 2. API Consistency

```typescript
// Maintain consistent API patterns across libraries
export interface Repository<T, ID> {
  findById(id: ID): Promise<T | null>;
  findAll(): Promise<T[]>;
  save(entity: T): Promise<T>;
  delete(id: ID): Promise<void>;
}

export interface Service<T, CreateInput, UpdateInput> {
  create(input: CreateInput): Promise<T>;
  update(id: string, input: UpdateInput): Promise<T>;
  delete(id: string): Promise<void>;
  findById(id: string): Promise<T | null>;
}
```

### 3. Documentation Standards

```typescript
/**
 * Calculates financial metrics for expense tracking
 * 
 * @example
 * ```typescript
 * const expenses = await getExpenses();
 * const total = ExpenseCalculator.calculateMonthlyTotal(expenses);
 * console.log(`Monthly total: ${total}`);
 * ```
 */
export class ExpenseCalculator {
  /**
   * Calculates the total amount for a given array of expenses
   * 
   * @param expenses - Array of expense objects
   * @returns Sum of all expense amounts
   * 
   * @throws {Error} When expenses contain invalid amounts
   */
  static calculateMonthlyTotal(expenses: Expense[]): number {
    // Implementation...
  }
}
```

## Performance Considerations

### 1. Tree Shaking

```typescript
// Ensure libraries support tree shaking
// packages/shared/utils/src/index.ts
export { DateUtils } from './date-utils';
export { CurrencyUtils } from './currency-utils';
export { ValidationUtils } from './validation-utils';

// Don't use default exports for better tree shaking
// ❌ export default { DateUtils, CurrencyUtils };
```

### 2. Bundle Analysis

```json
// package.json scripts for bundle analysis
{
  "scripts": {
    "analyze:bundle": "nx run-many --target=bundle-analyzer --projects=packages/shared/*",
    "check:circular": "madge --circular packages/shared/*/src"
  }
}
```

## Migration Strategies

### Extracting Code to Shared Libraries

```typescript
// Before: Code in web-pwa app
// apps/web-pwa/src/utils/expense-utils.ts

// After: Moved to shared library
// packages/shared/expense-core/src/utils.ts
// Then import in app:
import { ExpenseCalculator } from '@expense-tracker/expense-core';
```

### Gradual Migration Plan

1. **Phase 1**: Extract types and interfaces
2. **Phase 2**: Move utility functions
3. **Phase 3**: Extract business logic
4. **Phase 4**: Create UI component library
5. **Phase 5**: Consolidate API clients

This shared libraries strategy ensures maximum code reuse while maintaining clear boundaries and testability across your monorepo applications.
