# Testing Strategies for Monorepo Architecture

## Overview

This document outlines comprehensive testing strategies for monorepo-based personal projects, specifically the Expense Tracker MVP. It covers unit testing, integration testing, end-to-end testing, and testing workflows optimized for monorepo development patterns.

## Testing Architecture Philosophy

### 1. Testing Pyramid for Monorepos

```
        /\
       /  \
      / E2E \     <- Few, high-value end-to-end tests
     /______\
    /        \
   /Integration\ <- More integration tests than E2E
  /__________\
 /            \
/     Unit     \ <- Many fast, isolated unit tests
/___________\
```

**Unit Tests (70-80%)**
- Fast, isolated tests for individual functions and components
- Shared libraries and business logic
- Mock external dependencies

**Integration Tests (15-20%)**
- Test interactions between packages
- API contract testing
- Database integration testing

**End-to-End Tests (5-10%)**
- Critical user journeys across all applications
- Full system integration
- Browser and mobile testing

### 2. Monorepo Testing Benefits

**Shared Test Utilities**
- Common test setup and configuration
- Shared mocks and fixtures
- Consistent testing patterns

**Cross-Package Testing**
- Test package interactions directly
- Validate API contracts between services
- End-to-end testing with real integrations

**Unified Testing Commands**
- Run tests across all packages
- Affected testing based on changes
- Parallel test execution

## Unit Testing Strategy

### 1. Shared Library Testing

#### Business Logic Testing

```typescript
// packages/business-logic/src/calculations/expense-calculator.spec.ts
import { ExpenseCalculator } from './expense-calculator';
import { Expense, Category } from '@expense-tracker/shared-types';

describe('ExpenseCalculator', () => {
  const mockCategory: Category = {
    id: 'cat-1',
    name: 'Food',
    icon: '🍔',
    color: '#FF5722',
    userId: 'user-1',
  };

  const mockExpenses: Expense[] = [
    {
      id: 'exp-1',
      userId: 'user-1',
      amount: 25.50,
      currency: 'USD',
      category: mockCategory,
      description: 'Lunch',
      date: new Date('2023-01-15'),
      tags: ['restaurant'],
      createdAt: new Date('2023-01-15'),
      updatedAt: new Date('2023-01-15'),
    },
    {
      id: 'exp-2',
      userId: 'user-1',
      amount: 15.75,
      currency: 'USD',
      category: mockCategory,
      description: 'Coffee',
      date: new Date('2023-01-16'),
      tags: ['coffee'],
      createdAt: new Date('2023-01-16'),
      updatedAt: new Date('2023-01-16'),
    },
  ];

  describe('calculateTotal', () => {
    it('should calculate total expense amount correctly', () => {
      const total = ExpenseCalculator.calculateTotal(mockExpenses);
      expect(total).toBe(41.25);
    });

    it('should return 0 for empty expense array', () => {
      const total = ExpenseCalculator.calculateTotal([]);
      expect(total).toBe(0);
    });
  });

  describe('groupByCategory', () => {
    it('should group expenses by category correctly', () => {
      const grouped = ExpenseCalculator.groupByCategory(mockExpenses);
      expect(grouped['cat-1']).toHaveLength(2);
      expect(grouped['cat-1']).toEqual(mockExpenses);
    });
  });

  describe('calculateMonthlyAverage', () => {
    it('should calculate monthly average correctly', () => {
      const average = ExpenseCalculator.calculateMonthlyAverage(mockExpenses);
      // Same month, so average equals total
      expect(average).toBe(41.25);
    });

    it('should handle expenses from different months', () => {
      const expensesFromDifferentMonths = [
        { ...mockExpenses[0], date: new Date('2023-01-15') },
        { ...mockExpenses[1], date: new Date('2023-02-15') },
      ];
      const average = ExpenseCalculator.calculateMonthlyAverage(expensesFromDifferentMonths);
      expect(average).toBe(20.625); // 41.25 / 2 months
    });
  });
});
```

#### Type Validation Testing

```typescript
// packages/shared-types/src/entities/expense.spec.ts
import { Expense, Category } from './expense';

describe('Type Definitions', () => {
  describe('Expense', () => {
    it('should have all required properties', () => {
      const expense: Expense = {
        id: 'exp-1',
        userId: 'user-1',
        amount: 25.50,
        currency: 'USD',
        category: {
          id: 'cat-1',
          name: 'Food',
          icon: '🍔',
          color: '#FF5722',
          userId: 'user-1',
        },
        description: 'Test expense',
        date: new Date(),
        tags: ['test'],
        createdAt: new Date(),
        updatedAt: new Date(),
      };

      expect(expense.id).toBeDefined();
      expect(expense.amount).toBeGreaterThan(0);
      expect(expense.currency).toBe('USD');
      expect(expense.category).toBeDefined();
    });
  });
});
```

### 2. UI Component Testing

#### React Component Testing

```typescript
// packages/ui-components/src/components/expense-card/expense-card.spec.tsx
import React from 'react';
import { render, screen, fireEvent } from '@testing-library/react';
import { ExpenseCard } from './expense-card';
import { Expense } from '@expense-tracker/shared-types';

const mockExpense: Expense = {
  id: 'exp-1',
  userId: 'user-1',
  amount: 25.50,
  currency: 'USD',
  category: {
    id: 'cat-1',
    name: 'Food',
    icon: '🍔',
    color: '#FF5722',
    userId: 'user-1',
  },
  description: 'Lunch at restaurant',
  date: new Date('2023-01-15'),
  tags: ['restaurant', 'lunch'],
  createdAt: new Date('2023-01-15'),
  updatedAt: new Date('2023-01-15'),
};

describe('ExpenseCard', () => {
  it('should render expense information correctly', () => {
    render(<ExpenseCard expense={mockExpense} />);

    expect(screen.getByText('Lunch at restaurant')).toBeInTheDocument();
    expect(screen.getByText('$25.50')).toBeInTheDocument();
    expect(screen.getByText('Food')).toBeInTheDocument();
    expect(screen.getByText('🍔')).toBeInTheDocument();
    expect(screen.getByText('1/15/2023')).toBeInTheDocument();
  });

  it('should render tags when present', () => {
    render(<ExpenseCard expense={mockExpense} />);

    expect(screen.getByText('restaurant')).toBeInTheDocument();
    expect(screen.getByText('lunch')).toBeInTheDocument();
  });

  it('should call onEdit when edit button is clicked', () => {
    const onEdit = jest.fn();
    render(<ExpenseCard expense={mockExpense} onEdit={onEdit} />);

    const editButton = screen.getByText('Edit');
    fireEvent.click(editButton);

    expect(onEdit).toHaveBeenCalledWith(mockExpense);
  });

  it('should call onDelete when delete button is clicked', () => {
    const onDelete = jest.fn();
    render(<ExpenseCard expense={mockExpense} onDelete={onDelete} />);

    const deleteButton = screen.getByText('Delete');
    fireEvent.click(deleteButton);

    expect(onDelete).toHaveBeenCalledWith('exp-1');
  });

  it('should not render action buttons when handlers are not provided', () => {
    render(<ExpenseCard expense={mockExpense} />);

    expect(screen.queryByText('Edit')).not.toBeInTheDocument();
    expect(screen.queryByText('Delete')).not.toBeInTheDocument();
  });
});
```

### 3. API Client Testing

```typescript
// packages/api-client/src/clients/expense-client.spec.ts
import { ExpenseClient } from './expense-client';
import { CreateExpenseRequest } from '@expense-tracker/shared-types';

// Mock fetch globally
global.fetch = jest.fn();

describe('ExpenseClient', () => {
  let client: ExpenseClient;
  const mockFetch = fetch as jest.MockedFunction<typeof fetch>;

  beforeEach(() => {
    client = new ExpenseClient('http://test-api.com');
    mockFetch.mockClear();
  });

  describe('getExpenses', () => {
    it('should fetch expenses without filters', async () => {
      const mockExpenses = [
        { id: 'exp-1', description: 'Test expense' },
      ];

      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => mockExpenses,
      } as Response);

      const result = await client.getExpenses();

      expect(mockFetch).toHaveBeenCalledWith(
        'http://test-api.com/expenses',
        expect.objectContaining({
          method: 'GET',
        })
      );
      expect(result).toEqual(mockExpenses);
    });

    it('should fetch expenses with filters', async () => {
      const filters = {
        categoryIds: ['cat-1', 'cat-2'],
        startDate: '2023-01-01',
        minAmount: 10,
      };

      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => [],
      } as Response);

      await client.getExpenses(filters);

      expect(mockFetch).toHaveBeenCalledWith(
        expect.stringContaining('categoryIds=cat-1&categoryIds=cat-2&startDate=2023-01-01&minAmount=10'),
        expect.any(Object)
      );
    });
  });

  describe('createExpense', () => {
    it('should create expense with correct data', async () => {
      const expenseData: CreateExpenseRequest = {
        amount: 25.50,
        currency: 'USD',
        categoryId: 'cat-1',
        description: 'Test expense',
        date: '2023-01-15',
        tags: ['test'],
      };

      const mockResponse = { id: 'exp-1', ...expenseData };

      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => mockResponse,
      } as Response);

      const result = await client.createExpense(expenseData);

      expect(mockFetch).toHaveBeenCalledWith(
        'http://test-api.com/expenses',
        expect.objectContaining({
          method: 'POST',
          body: JSON.stringify(expenseData),
        })
      );
      expect(result).toEqual(mockResponse);
    });
  });

  describe('error handling', () => {
    it('should throw error when API returns error status', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: false,
        status: 400,
        json: async () => ({ message: 'Invalid data' }),
      } as Response);

      await expect(client.getExpenses()).rejects.toThrow('Invalid data');
    });
  });
});
```

## Integration Testing Strategy

### 1. API Integration Testing

```typescript
// apps/api-gateway/src/routes/expense-routes.spec.ts
import request from 'supertest';
import express from 'express';
import { expenseRouter } from './expense-routes';
import { authMiddleware } from '@expense-tracker/auth';

// Mock dependencies
jest.mock('@expense-tracker/auth');
jest.mock('@expense-tracker/database');

const app = express();
app.use(express.json());
app.use('/api/expenses', authMiddleware, expenseRouter);

describe('Expense Routes Integration', () => {
  beforeEach(() => {
    // Mock authenticated user
    (authMiddleware as jest.Mock).mockImplementation((req, res, next) => {
      req.user = { id: 'user-1', email: 'test@example.com' };
      next();
    });
  });

  describe('GET /api/expenses', () => {
    it('should return user expenses', async () => {
      const response = await request(app)
        .get('/api/expenses')
        .expect(200);

      expect(response.body).toBeInstanceOf(Array);
    });

    it('should filter expenses by category', async () => {
      const response = await request(app)
        .get('/api/expenses?categoryIds=cat-1,cat-2')
        .expect(200);

      expect(response.body).toBeInstanceOf(Array);
    });
  });

  describe('POST /api/expenses', () => {
    it('should create new expense', async () => {
      const expenseData = {
        amount: 25.50,
        currency: 'USD',
        categoryId: 'cat-1',
        description: 'Test expense',
        date: '2023-01-15',
      };

      const response = await request(app)
        .post('/api/expenses')
        .send(expenseData)
        .expect(201);

      expect(response.body).toMatchObject({
        amount: 25.50,
        currency: 'USD',
        description: 'Test expense',
      });
    });

    it('should validate required fields', async () => {
      const invalidData = {
        amount: 25.50,
        // Missing required fields
      };

      await request(app)
        .post('/api/expenses')
        .send(invalidData)
        .expect(400);
    });
  });
});
```

### 2. Database Integration Testing

```typescript
// libs/database/src/repositories/expense-repository.spec.ts
import { ExpenseRepository } from './expense-repository';
import { DatabaseTestHelper } from '../test-helpers/database-test-helper';
import { CreateExpenseDto } from '@expense-tracker/shared-types';

describe('ExpenseRepository Integration', () => {
  let repository: ExpenseRepository;
  let dbHelper: DatabaseTestHelper;

  beforeAll(async () => {
    dbHelper = new DatabaseTestHelper();
    await dbHelper.setup();
    repository = new ExpenseRepository(dbHelper.getConnection());
  });

  afterAll(async () => {
    await dbHelper.cleanup();
  });

  beforeEach(async () => {
    await dbHelper.clearTables(['expenses', 'categories']);
    await dbHelper.seedTestData();
  });

  describe('create', () => {
    it('should create expense and return with ID', async () => {
      const expenseData: CreateExpenseDto = {
        userId: 'user-1',
        amount: 25.50,
        currency: 'USD',
        categoryId: 'cat-1',
        description: 'Test expense',
        date: new Date('2023-01-15'),
        tags: ['test'],
      };

      const result = await repository.create(expenseData);

      expect(result.id).toBeDefined();
      expect(result.amount).toBe(25.50);
      expect(result.description).toBe('Test expense');
      expect(result.createdAt).toBeInstanceOf(Date);
    });
  });

  describe('findByUserId', () => {
    it('should return user expenses only', async () => {
      await repository.create({
        userId: 'user-1',
        amount: 25.50,
        currency: 'USD',
        categoryId: 'cat-1',
        description: 'User 1 expense',
        date: new Date(),
        tags: [],
      });

      await repository.create({
        userId: 'user-2',
        amount: 15.25,
        currency: 'USD',
        categoryId: 'cat-1',
        description: 'User 2 expense',
        date: new Date(),
        tags: [],
      });

      const user1Expenses = await repository.findByUserId('user-1');
      const user2Expenses = await repository.findByUserId('user-2');

      expect(user1Expenses).toHaveLength(1);
      expect(user2Expenses).toHaveLength(1);
      expect(user1Expenses[0].description).toBe('User 1 expense');
      expect(user2Expenses[0].description).toBe('User 2 expense');
    });
  });
});
```

### 3. Cross-Package Integration Testing

```typescript
// test/integration/expense-workflow.spec.ts
import { ExpenseCalculator } from '@expense-tracker/business-logic';
import { ExpenseClient } from '@expense-tracker/api-client';
import { ExpenseRepository } from '@expense-tracker/database';
import { CreateExpenseRequest } from '@expense-tracker/shared-types';

describe('Expense Workflow Integration', () => {
  let expenseClient: ExpenseClient;
  let expenseRepository: ExpenseRepository;

  beforeAll(async () => {
    // Setup test environment
    expenseClient = new ExpenseClient('http://localhost:3001/api');
    expenseRepository = new ExpenseRepository();
  });

  it('should handle complete expense creation workflow', async () => {
    // 1. Create expense via API
    const expenseData: CreateExpenseRequest = {
      amount: 25.50,
      currency: 'USD',
      categoryId: 'cat-1',
      description: 'Integration test expense',
      date: '2023-01-15',
      tags: ['test', 'integration'],
    };

    const createdExpense = await expenseClient.createExpense(expenseData);
    expect(createdExpense.id).toBeDefined();

    // 2. Verify expense exists in database
    const dbExpense = await expenseRepository.findById(createdExpense.id);
    expect(dbExpense).toBeDefined();
    expect(dbExpense?.amount).toBe(25.50);

    // 3. Test business logic calculations
    const userExpenses = await expenseClient.getExpenses();
    const total = ExpenseCalculator.calculateTotal(userExpenses);
    expect(total).toBeGreaterThanOrEqual(25.50);

    // 4. Clean up
    await expenseClient.deleteExpense(createdExpense.id);
  });
});
```

## End-to-End Testing Strategy

### 1. Web Application E2E Testing with Playwright

```typescript
// e2e/playwright/tests/expense-management.spec.ts
import { test, expect } from '@playwright/test';

test.describe('Expense Management', () => {
  test.beforeEach(async ({ page }) => {
    // Navigate to application and login
    await page.goto('http://localhost:4200');
    await page.getByTestId('login-email').fill('test@example.com');
    await page.getByTestId('login-password').fill('password');
    await page.getByTestId('login-submit').click();
    
    // Wait for navigation to expenses page
    await expect(page).toHaveURL(/.*\/expenses/);
  });

  test('should create, edit, and delete expense', async ({ page }) => {
    // Create new expense
    await page.getByTestId('add-expense-button').click();
    await page.getByTestId('expense-amount').fill('25.50');
    await page.getByTestId('expense-description').fill('Test expense');
    await page.getByTestId('expense-category').selectOption({ label: 'Food' });
    await page.getByTestId('expense-save').click();

    // Verify expense appears in list
    await expect(page.getByText('Test expense')).toBeVisible();
    await expect(page.getByText('$25.50')).toBeVisible();

    // Edit expense
    await page.getByTestId('expense-edit-button').first().click();
    await page.getByTestId('expense-description').fill('Updated test expense');
    await page.getByTestId('expense-save').click();

    // Verify updated expense
    await expect(page.getByText('Updated test expense')).toBeVisible();

    // Delete expense
    await page.getByTestId('expense-delete-button').first().click();
    await page.getByTestId('confirm-delete').click();

    // Verify expense is removed
    await expect(page.getByText('Updated test expense')).not.toBeVisible();
  });

  test('should filter expenses by category', async ({ page }) => {
    // Ensure we have test data
    await page.getByTestId('category-filter').selectOption({ label: 'Food' });
    
    // Verify only food expenses are shown
    const expenseCards = page.getByTestId('expense-card');
    const count = await expenseCards.count();
    
    for (let i = 0; i < count; i++) {
      const card = expenseCards.nth(i);
      await expect(card.getByText('Food')).toBeVisible();
    }
  });

  test('should display expense statistics', async ({ page }) => {
    await page.getByTestId('stats-tab').click();
    
    // Verify statistics are displayed
    await expect(page.getByTestId('total-expenses')).toBeVisible();
    await expect(page.getByTestId('monthly-average')).toBeVisible();
    await expect(page.getByTestId('category-breakdown')).toBeVisible();
  });
});
```

### 2. Mobile Application E2E Testing

```typescript
// e2e/detox/tests/expense-management.e2e.ts
import { device, element, by, expect } from 'detox';

describe('Mobile Expense Management', () => {
  beforeAll(async () => {
    await device.launchApp();
  });

  beforeEach(async () => {
    await device.reloadReactNative();
    
    // Login
    await element(by.id('loginEmail')).typeText('test@example.com');
    await element(by.id('loginPassword')).typeText('password');
    await element(by.id('loginSubmit')).tap();
    
    // Wait for expenses screen
    await expect(element(by.id('expensesScreen'))).toBeVisible();
  });

  it('should create expense on mobile', async () => {
    // Tap add expense button
    await element(by.id('addExpenseButton')).tap();
    
    // Fill expense form
    await element(by.id('expenseAmount')).typeText('25.50');
    await element(by.id('expenseDescription')).typeText('Mobile test expense');
    await element(by.id('expenseCategory')).tap();
    await element(by.text('Food')).tap();
    await element(by.id('expenseSave')).tap();
    
    // Verify expense in list
    await expect(element(by.text('Mobile test expense'))).toBeVisible();
    await expect(element(by.text('$25.50'))).toBeVisible();
  });

  it('should sync expenses across devices', async () => {
    // Create expense on mobile
    await element(by.id('addExpenseButton')).tap();
    await element(by.id('expenseAmount')).typeText('15.25');
    await element(by.id('expenseDescription')).typeText('Sync test expense');
    await element(by.id('expenseSave')).tap();
    
    // Force sync
    await element(by.id('syncButton')).tap();
    
    // Verify sync status
    await expect(element(by.text('Synced'))).toBeVisible();
  });
});
```

### 3. API E2E Testing

```typescript
// e2e/api/tests/expense-api.spec.ts
import axios from 'axios';
import { CreateExpenseRequest } from '@expense-tracker/shared-types';

describe('Expense API E2E', () => {
  const baseURL = 'http://localhost:3000/api';
  let authToken: string;
  let createdExpenseId: string;

  beforeAll(async () => {
    // Authenticate and get token
    const loginResponse = await axios.post(`${baseURL}/auth/login`, {
      email: 'test@example.com',
      password: 'password',
    });
    authToken = loginResponse.data.token;
  });

  const apiClient = axios.create({
    baseURL,
    headers: {
      Authorization: `Bearer ${authToken}`,
    },
  });

  it('should handle complete CRUD operations', async () => {
    // Create expense
    const expenseData: CreateExpenseRequest = {
      amount: 25.50,
      currency: 'USD',
      categoryId: 'cat-1',
      description: 'API E2E test expense',
      date: '2023-01-15',
      tags: ['test', 'api'],
    };

    const createResponse = await apiClient.post('/expenses', expenseData);
    expect(createResponse.status).toBe(201);
    expect(createResponse.data.id).toBeDefined();
    createdExpenseId = createResponse.data.id;

    // Read expense
    const getResponse = await apiClient.get(`/expenses/${createdExpenseId}`);
    expect(getResponse.status).toBe(200);
    expect(getResponse.data.amount).toBe(25.50);

    // Update expense
    const updateData = { description: 'Updated API test expense' };
    const updateResponse = await apiClient.put(`/expenses/${createdExpenseId}`, updateData);
    expect(updateResponse.status).toBe(200);
    expect(updateResponse.data.description).toBe('Updated API test expense');

    // Delete expense
    const deleteResponse = await apiClient.delete(`/expenses/${createdExpenseId}`);
    expect(deleteResponse.status).toBe(204);

    // Verify deletion
    try {
      await apiClient.get(`/expenses/${createdExpenseId}`);
      fail('Expected 404 error');
    } catch (error) {
      expect(error.response.status).toBe(404);
    }
  });

  it('should validate expense data', async () => {
    const invalidData = {
      amount: -10, // Invalid negative amount
      currency: 'INVALID',
      description: '', // Empty description
    };

    try {
      await apiClient.post('/expenses', invalidData);
      fail('Expected validation error');
    } catch (error) {
      expect(error.response.status).toBe(400);
      expect(error.response.data.errors).toBeDefined();
    }
  });
});
```

## Testing Configuration and Setup

### 1. Jest Configuration for Monorepo

```javascript
// jest.config.js
const { getJestProjects } = require('@nx/jest');

module.exports = {
  projects: getJestProjects(),
  collectCoverageFrom: [
    'packages/**/*.{ts,tsx}',
    'apps/**/*.{ts,tsx}',
    'libs/**/*.{ts,tsx}',
    '!**/*.d.ts',
    '!**/node_modules/**',
    '!**/coverage/**',
  ],
  coverageThreshold: {
    global: {
      branches: 80,
      functions: 80,
      lines: 80,
      statements: 80,
    },
  },
};
```

### 2. Test Utilities and Shared Fixtures

```typescript
// test/utils/test-helpers.ts
import { render, RenderOptions } from '@testing-library/react';
import { ReactElement } from 'react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';

// Custom render function with providers
const AllTheProviders = ({ children }: { children: React.ReactNode }) => {
  const queryClient = new QueryClient({
    defaultOptions: {
      queries: {
        retry: false,
      },
    },
  });

  return (
    <QueryClientProvider client={queryClient}>
      {children}
    </QueryClientProvider>
  );
};

export const renderWithProviders = (
  ui: ReactElement,
  options?: Omit<RenderOptions, 'wrapper'>
) => render(ui, { wrapper: AllTheProviders, ...options });

// Mock data factories
export const createMockExpense = (overrides: Partial<Expense> = {}): Expense => ({
  id: 'exp-1',
  userId: 'user-1',
  amount: 25.50,
  currency: 'USD',
  category: {
    id: 'cat-1',
    name: 'Food',
    icon: '🍔',
    color: '#FF5722',
    userId: 'user-1',
  },
  description: 'Test expense',
  date: new Date('2023-01-15'),
  tags: ['test'],
  createdAt: new Date('2023-01-15'),
  updatedAt: new Date('2023-01-15'),
  ...overrides,
});
```

### 3. Testing Commands and Scripts

```json
{
  "scripts": {
    "test": "nx run-many --target=test --all",
    "test:affected": "nx affected --target=test",
    "test:unit": "nx run-many --target=test --projects=shared-types,business-logic,ui-components",
    "test:integration": "nx run-many --target=test --projects=api-gateway,expense-service",
    "test:e2e": "nx run-many --target=e2e --all",
    "test:coverage": "nx run-many --target=test --all --coverage",
    "test:watch": "nx run-many --target=test --all --watch"
  }
}
```

## Continuous Integration Testing

### 1. GitHub Actions Workflow

```yaml
# .github/workflows/test.yml
name: Test

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
        image: postgres:14
        env:
          POSTGRES_PASSWORD: test
          POSTGRES_DB: expense_tracker_test
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    steps:
      - uses: actions/checkout@v3
        with:
          fetch-depth: 0

      - uses: actions/setup-node@v3
        with:
          node-version: 18
          cache: 'npm'

      - run: npm ci

      - name: Run affected tests
        run: npx nx affected --target=test --parallel=3 --ci

      - name: Run affected E2E tests
        run: npx nx affected --target=e2e --parallel=1 --ci

      - name: Upload coverage to Codecov
        uses: codecov/codecov-action@v3
        with:
          directory: ./coverage
```

## Best Practices and Guidelines

### 1. Test Organization

**File Naming Conventions**
- Unit tests: `*.spec.ts` or `*.test.ts`
- Integration tests: `*.integration.spec.ts`
- E2E tests: `*.e2e.spec.ts`

**Test Structure**
- Use descriptive test names
- Follow AAA pattern (Arrange, Act, Assert)
- Group related tests with `describe` blocks
- Use meaningful variable names

### 2. Mock Strategies

**External Dependencies**
- Mock API calls and external services
- Use dependency injection for testability
- Create realistic mock data
- Avoid over-mocking internal code

**Database Mocking**
- Use in-memory databases for unit tests
- Use test databases for integration tests
- Clean up test data between tests
- Seed realistic test data

### 3. Performance Considerations

**Test Speed**
- Keep unit tests fast (< 50ms each)
- Run expensive tests only when necessary
- Use test parallelization
- Cache test dependencies

**Test Reliability**
- Avoid flaky tests with proper waits
- Use deterministic test data
- Clean up side effects
- Isolate tests from each other

## Conclusion

This comprehensive testing strategy ensures high code quality and confidence in the monorepo-based Expense Tracker application. By implementing unit tests for shared libraries, integration tests for service interactions, and end-to-end tests for critical user journeys, we achieve thorough coverage while maintaining fast feedback loops and development velocity.

The key to success is:
1. **Start with unit tests** for shared business logic
2. **Add integration tests** for service boundaries
3. **Include E2E tests** for critical user paths
4. **Automate everything** in CI/CD pipelines
5. **Monitor coverage** and quality metrics
