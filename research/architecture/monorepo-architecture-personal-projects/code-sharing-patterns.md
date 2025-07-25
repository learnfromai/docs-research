# Code Sharing Patterns in Monorepo

## Overview

Effective code sharing patterns in monorepos maximize reusability while maintaining clear boundaries, type safety, and maintainability across applications and services.

## Core Sharing Patterns

### 1. Shared Types and Interfaces

```typescript
// packages/shared/types/src/domain/expense.types.ts
export interface BaseEntity {
  id: string;
  createdAt: Date;
  updatedAt: Date;
  version: number;
}

export interface Expense extends BaseEntity {
  userId: string;
  amount: number;
  currency: string;
  category: string;
  description: string;
  date: Date;
  tags: string[];
  receiptUrl?: string;
  metadata?: Record<string, any>;
}

export interface ExpenseFilters {
  userId?: string;
  category?: string;
  dateRange?: {
    start: Date;
    end: Date;
  };
  amountRange?: {
    min: number;
    max: number;
  };
  tags?: string[];
}

export interface PaginationOptions {
  page: number;
  limit: number;
  sortBy?: keyof Expense;
  sortOrder?: 'asc' | 'desc';
}

export interface PaginatedResponse<T> {
  data: T[];
  pagination: {
    page: number;
    limit: number;
    total: number;
    totalPages: number;
    hasNext: boolean;
    hasPrev: boolean;
  };
}

// Business logic types
export interface ExpenseStatistics {
  totalAmount: number;
  totalCount: number;
  averageAmount: number;
  categoryBreakdown: Record<string, {
    amount: number;
    count: number;
    percentage: number;
  }>;
  monthlyTrends: Array<{
    month: string;
    amount: number;
    count: number;
  }>;
}
```

### 2. Domain-Driven Design Patterns

```typescript
// packages/shared/domain/src/expense/expense.entity.ts
import { BaseEntity } from '../base/base.entity';
import { DomainEvent } from '../events/domain-event';

export class ExpenseEntity extends BaseEntity {
  constructor(
    public readonly userId: string,
    public amount: number,
    public readonly currency: string,
    public category: string,
    public description: string,
    public readonly date: Date,
    public tags: string[] = [],
    public receiptUrl?: string
  ) {
    super();
    this.validateInvariants();
  }

  static create(props: {
    userId: string;
    amount: number;
    currency: string;
    category: string;
    description: string;
    date: Date;
    tags?: string[];
    receiptUrl?: string;
  }): ExpenseEntity {
    const expense = new ExpenseEntity(
      props.userId,
      props.amount,
      props.currency,
      props.category,
      props.description,
      props.date,
      props.tags,
      props.receiptUrl
    );

    // Emit domain event
    expense.addDomainEvent(new ExpenseCreatedEvent(expense.id, props.userId, props.amount));
    
    return expense;
  }

  updateAmount(newAmount: number): void {
    if (newAmount <= 0) {
      throw new Error('Amount must be positive');
    }

    const oldAmount = this.amount;
    this.amount = newAmount;
    this.touch();

    this.addDomainEvent(new ExpenseAmountUpdatedEvent(this.id, oldAmount, newAmount));
  }

  categorize(newCategory: string): void {
    if (!newCategory.trim()) {
      throw new Error('Category cannot be empty');
    }

    const oldCategory = this.category;
    this.category = newCategory.trim();
    this.touch();

    this.addDomainEvent(new ExpenseCategorizedEvent(this.id, oldCategory, newCategory));
  }

  addTag(tag: string): void {
    if (!tag.trim()) {
      throw new Error('Tag cannot be empty');
    }

    const normalizedTag = tag.trim().toLowerCase();
    if (!this.tags.includes(normalizedTag)) {
      this.tags.push(normalizedTag);
      this.touch();
    }
  }

  removeTag(tag: string): void {
    const normalizedTag = tag.trim().toLowerCase();
    const index = this.tags.indexOf(normalizedTag);
    if (index > -1) {
      this.tags.splice(index, 1);
      this.touch();
    }
  }

  private validateInvariants(): void {
    if (this.amount <= 0) {
      throw new Error('Expense amount must be positive');
    }

    if (!this.currency || this.currency.length !== 3) {
      throw new Error('Currency must be a valid 3-character code');
    }

    if (!this.category.trim()) {
      throw new Error('Category is required');
    }

    if (!this.description.trim()) {
      throw new Error('Description is required');
    }

    if (this.date > new Date()) {
      throw new Error('Expense date cannot be in the future');
    }
  }
}

// Domain events
export class ExpenseCreatedEvent extends DomainEvent {
  constructor(
    public readonly expenseId: string,
    public readonly userId: string,
    public readonly amount: number
  ) {
    super('expense.created');
  }
}

export class ExpenseAmountUpdatedEvent extends DomainEvent {
  constructor(
    public readonly expenseId: string,
    public readonly oldAmount: number,
    public readonly newAmount: number
  ) {
    super('expense.amount.updated');
  }
}
```

### 3. Repository Pattern Sharing

```typescript
// packages/shared/data-access/src/repository/base.repository.ts
export interface Repository<T, ID> {
  findById(id: ID): Promise<T | null>;
  findAll(filters?: any): Promise<T[]>;
  findWithPagination(options: PaginationOptions, filters?: any): Promise<PaginatedResponse<T>>;
  save(entity: T): Promise<T>;
  delete(id: ID): Promise<void>;
  exists(id: ID): Promise<boolean>;
}

export abstract class BaseRepository<T extends BaseEntity, ID = string> implements Repository<T, ID> {
  constructor(protected readonly connection: any) {}

  abstract findById(id: ID): Promise<T | null>;
  abstract findAll(filters?: any): Promise<T[]>;
  abstract save(entity: T): Promise<T>;
  abstract delete(id: ID): Promise<void>;

  async exists(id: ID): Promise<boolean> {
    const entity = await this.findById(id);
    return entity !== null;
  }

  async findWithPagination(
    options: PaginationOptions, 
    filters?: any
  ): Promise<PaginatedResponse<T>> {
    const offset = (options.page - 1) * options.limit;
    
    const [data, total] = await Promise.all([
      this.findAllWithOffsetAndLimit(offset, options.limit, filters, options.sortBy, options.sortOrder),
      this.count(filters)
    ]);

    const totalPages = Math.ceil(total / options.limit);

    return {
      data,
      pagination: {
        page: options.page,
        limit: options.limit,
        total,
        totalPages,
        hasNext: options.page < totalPages,
        hasPrev: options.page > 1
      }
    };
  }

  protected abstract findAllWithOffsetAndLimit(
    offset: number, 
    limit: number, 
    filters?: any,
    sortBy?: string,
    sortOrder?: 'asc' | 'desc'
  ): Promise<T[]>;
  
  protected abstract count(filters?: any): Promise<number>;
}

// Specific repository implementation
// packages/shared/data-access/src/repository/expense.repository.ts
export class ExpenseRepository extends BaseRepository<ExpenseEntity> {
  async findById(id: string): Promise<ExpenseEntity | null> {
    const result = await this.connection.query(
      'SELECT * FROM expenses WHERE id = $1',
      [id]
    );
    
    return result.rows.length > 0 ? this.mapToEntity(result.rows[0]) : null;
  }

  async findAll(filters?: ExpenseFilters): Promise<ExpenseEntity[]> {
    const query = this.buildQuery(filters);
    const result = await this.connection.query(query.sql, query.params);
    
    return result.rows.map(row => this.mapToEntity(row));
  }

  async findByUserId(userId: string): Promise<ExpenseEntity[]> {
    const result = await this.connection.query(
      'SELECT * FROM expenses WHERE user_id = $1 ORDER BY date DESC',
      [userId]
    );
    
    return result.rows.map(row => this.mapToEntity(row));
  }

  async save(entity: ExpenseEntity): Promise<ExpenseEntity> {
    if (entity.id) {
      return this.update(entity);
    } else {
      return this.create(entity);
    }
  }

  async delete(id: string): Promise<void> {
    await this.connection.query('DELETE FROM expenses WHERE id = $1', [id]);
  }

  private async create(entity: ExpenseEntity): Promise<ExpenseEntity> {
    const result = await this.connection.query(`
      INSERT INTO expenses (id, user_id, amount, currency, category, description, date, tags, receipt_url, created_at, updated_at)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
      RETURNING *
    `, [
      entity.id,
      entity.userId,
      entity.amount,
      entity.currency,
      entity.category,
      entity.description,
      entity.date,
      JSON.stringify(entity.tags),
      entity.receiptUrl,
      entity.createdAt,
      entity.updatedAt
    ]);

    return this.mapToEntity(result.rows[0]);
  }

  private async update(entity: ExpenseEntity): Promise<ExpenseEntity> {
    const result = await this.connection.query(`
      UPDATE expenses 
      SET amount = $2, category = $3, description = $4, tags = $5, receipt_url = $6, updated_at = $7, version = version + 1
      WHERE id = $1 AND version = $8
      RETURNING *
    `, [
      entity.id,
      entity.amount,
      entity.category,
      entity.description,
      JSON.stringify(entity.tags),
      entity.receiptUrl,
      new Date(),
      entity.version
    ]);

    if (result.rows.length === 0) {
      throw new Error('Optimistic concurrency violation');
    }

    return this.mapToEntity(result.rows[0]);
  }

  private mapToEntity(row: any): ExpenseEntity {
    const entity = new ExpenseEntity(
      row.user_id,
      row.amount,
      row.currency,
      row.category,
      row.description,
      row.date,
      JSON.parse(row.tags || '[]'),
      row.receipt_url
    );

    // Set private fields
    (entity as any).id = row.id;
    (entity as any).createdAt = row.created_at;
    (entity as any).updatedAt = row.updated_at;
    (entity as any).version = row.version;

    return entity;
  }
}
```

### 4. Service Layer Patterns

```typescript
// packages/shared/application/src/services/base.service.ts
export abstract class BaseService<T, CreateDTO, UpdateDTO> {
  constructor(
    protected readonly repository: Repository<T, string>,
    protected readonly eventBus: EventBus,
    protected readonly logger: Logger
  ) {}

  async findById(id: string): Promise<T | null> {
    this.logger.debug(`Finding entity by id: ${id}`);
    return await this.repository.findById(id);
  }

  async findAll(filters?: any): Promise<T[]> {
    this.logger.debug('Finding all entities', { filters });
    return await this.repository.findAll(filters);
  }

  async create(dto: CreateDTO): Promise<T> {
    this.logger.debug('Creating entity', { dto });
    
    await this.validateCreate(dto);
    const entity = await this.mapCreateDtoToEntity(dto);
    const savedEntity = await this.repository.save(entity);
    
    await this.afterCreate(savedEntity, dto);
    
    return savedEntity;
  }

  async update(id: string, dto: UpdateDTO): Promise<T> {
    this.logger.debug(`Updating entity ${id}`, { dto });
    
    const existing = await this.repository.findById(id);
    if (!existing) {
      throw new Error(`Entity with id ${id} not found`);
    }

    await this.validateUpdate(existing, dto);
    const updated = await this.mapUpdateDtoToEntity(existing, dto);
    const savedEntity = await this.repository.save(updated);
    
    await this.afterUpdate(savedEntity, dto);
    
    return savedEntity;
  }

  async delete(id: string): Promise<void> {
    this.logger.debug(`Deleting entity ${id}`);
    
    const existing = await this.repository.findById(id);
    if (!existing) {
      throw new Error(`Entity with id ${id} not found`);
    }

    await this.validateDelete(existing);
    await this.repository.delete(id);
    await this.afterDelete(existing);
  }

  // Template methods for subclasses to implement
  protected abstract validateCreate(dto: CreateDTO): Promise<void>;
  protected abstract validateUpdate(existing: T, dto: UpdateDTO): Promise<void>;
  protected abstract validateDelete(existing: T): Promise<void>;
  protected abstract mapCreateDtoToEntity(dto: CreateDTO): Promise<T>;
  protected abstract mapUpdateDtoToEntity(existing: T, dto: UpdateDTO): Promise<T>;

  // Hooks for subclasses to override
  protected async afterCreate(entity: T, dto: CreateDTO): Promise<void> {}
  protected async afterUpdate(entity: T, dto: UpdateDTO): Promise<void> {}
  protected async afterDelete(entity: T): Promise<void> {}
}

// Concrete service implementation
// packages/shared/application/src/services/expense.service.ts
export class ExpenseService extends BaseService<ExpenseEntity, CreateExpenseDto, UpdateExpenseDto> {
  constructor(
    repository: ExpenseRepository,
    eventBus: EventBus,
    logger: Logger,
    private readonly categoryService: CategoryService
  ) {
    super(repository, eventBus, logger);
  }

  async getExpensesByUserId(userId: string): Promise<ExpenseEntity[]> {
    return (this.repository as ExpenseRepository).findByUserId(userId);
  }

  async getExpenseStatistics(userId: string, dateRange?: { start: Date; end: Date }): Promise<ExpenseStatistics> {
    const expenses = await this.getExpensesByUserId(userId);
    const filteredExpenses = dateRange 
      ? expenses.filter(e => e.date >= dateRange.start && e.date <= dateRange.end)
      : expenses;

    return this.calculateStatistics(filteredExpenses);
  }

  protected async validateCreate(dto: CreateExpenseDto): Promise<void> {
    if (dto.amount <= 0) {
      throw new Error('Amount must be positive');
    }

    if (!await this.categoryService.exists(dto.category)) {
      throw new Error(`Category '${dto.category}' does not exist`);
    }

    if (dto.date > new Date()) {
      throw new Error('Expense date cannot be in the future');
    }
  }

  protected async validateUpdate(existing: ExpenseEntity, dto: UpdateExpenseDto): Promise<void> {
    if (dto.amount !== undefined && dto.amount <= 0) {
      throw new Error('Amount must be positive');
    }

    if (dto.category && !await this.categoryService.exists(dto.category)) {
      throw new Error(`Category '${dto.category}' does not exist`);
    }
  }

  protected async validateDelete(existing: ExpenseEntity): Promise<void> {
    // Business rule: Cannot delete expenses older than 1 year
    const oneYearAgo = new Date();
    oneYearAgo.setFullYear(oneYearAgo.getFullYear() - 1);
    
    if (existing.date < oneYearAgo) {
      throw new Error('Cannot delete expenses older than 1 year');
    }
  }

  protected async mapCreateDtoToEntity(dto: CreateExpenseDto): Promise<ExpenseEntity> {
    return ExpenseEntity.create({
      userId: dto.userId,
      amount: dto.amount,
      currency: dto.currency,
      category: dto.category,
      description: dto.description,
      date: dto.date,
      tags: dto.tags,
      receiptUrl: dto.receiptUrl
    });
  }

  protected async mapUpdateDtoToEntity(existing: ExpenseEntity, dto: UpdateExpenseDto): Promise<ExpenseEntity> {
    if (dto.amount !== undefined) {
      existing.updateAmount(dto.amount);
    }

    if (dto.category) {
      existing.categorize(dto.category);
    }

    if (dto.description) {
      existing.description = dto.description;
    }

    if (dto.tags) {
      // Replace all tags
      existing.tags = [];
      dto.tags.forEach(tag => existing.addTag(tag));
    }

    return existing;
  }

  protected async afterCreate(entity: ExpenseEntity, dto: CreateExpenseDto): Promise<void> {
    await this.eventBus.publish('expense.created', {
      expenseId: entity.id,
      userId: entity.userId,
      amount: entity.amount,
      category: entity.category
    });
  }

  private calculateStatistics(expenses: ExpenseEntity[]): ExpenseStatistics {
    const totalAmount = expenses.reduce((sum, e) => sum + e.amount, 0);
    const totalCount = expenses.length;
    const averageAmount = totalCount > 0 ? totalAmount / totalCount : 0;

    const categoryBreakdown = expenses.reduce((acc, expense) => {
      if (!acc[expense.category]) {
        acc[expense.category] = { amount: 0, count: 0, percentage: 0 };
      }
      acc[expense.category].amount += expense.amount;
      acc[expense.category].count += 1;
      return acc;
    }, {} as Record<string, { amount: number; count: number; percentage: number }>);

    // Calculate percentages
    Object.keys(categoryBreakdown).forEach(category => {
      categoryBreakdown[category].percentage = 
        totalAmount > 0 ? (categoryBreakdown[category].amount / totalAmount) * 100 : 0;
    });

    // Monthly trends (simplified)
    const monthlyTrends = this.calculateMonthlyTrends(expenses);

    return {
      totalAmount,
      totalCount,
      averageAmount,
      categoryBreakdown,
      monthlyTrends
    };
  }

  private calculateMonthlyTrends(expenses: ExpenseEntity[]): Array<{ month: string; amount: number; count: number }> {
    const monthlyData = expenses.reduce((acc, expense) => {
      const monthKey = expense.date.toISOString().slice(0, 7); // YYYY-MM
      if (!acc[monthKey]) {
        acc[monthKey] = { amount: 0, count: 0 };
      }
      acc[monthKey].amount += expense.amount;
      acc[monthKey].count += 1;
      return acc;
    }, {} as Record<string, { amount: number; count: number }>);

    return Object.entries(monthlyData)
      .map(([month, data]) => ({ month, ...data }))
      .sort((a, b) => a.month.localeCompare(b.month));
  }
}
```

### 5. Event-Driven Patterns

```typescript
// packages/shared/events/src/event-bus.ts
export interface DomainEvent {
  id: string;
  type: string;
  aggregateId: string;
  data: any;
  timestamp: Date;
  version: number;
}

export interface EventHandler<T extends DomainEvent = DomainEvent> {
  handle(event: T): Promise<void>;
}

export class EventBus {
  private handlers = new Map<string, EventHandler[]>();
  private eventStore: EventStore;

  constructor(eventStore: EventStore) {
    this.eventStore = eventStore;
  }

  subscribe<T extends DomainEvent>(eventType: string, handler: EventHandler<T>): void {
    if (!this.handlers.has(eventType)) {
      this.handlers.set(eventType, []);
    }
    this.handlers.get(eventType)!.push(handler as EventHandler);
  }

  async publish(event: DomainEvent): Promise<void> {
    // Store event
    await this.eventStore.save(event);

    // Notify handlers
    const handlers = this.handlers.get(event.type) || [];
    await Promise.all(handlers.map(handler => handler.handle(event)));
  }

  async publishMany(events: DomainEvent[]): Promise<void> {
    for (const event of events) {
      await this.publish(event);
    }
  }
}

// Event handlers
export class ExpenseCreatedHandler implements EventHandler<ExpenseCreatedEvent> {
  constructor(
    private readonly analyticsService: AnalyticsService,
    private readonly notificationService: NotificationService
  ) {}

  async handle(event: ExpenseCreatedEvent): Promise<void> {
    // Update analytics
    await this.analyticsService.recordExpenseCreated({
      userId: event.userId,
      amount: event.amount,
      category: event.category,
      timestamp: event.timestamp
    });

    // Check if user needs budget notifications
    const monthlyTotal = await this.analyticsService.getMonthlyTotal(event.userId);
    const userBudget = await this.analyticsService.getUserBudget(event.userId);

    if (userBudget && monthlyTotal > userBudget * 0.8) {
      await this.notificationService.sendBudgetWarning(event.userId, {
        currentSpending: monthlyTotal,
        budget: userBudget,
        percentage: (monthlyTotal / userBudget) * 100
      });
    }
  }
}
```

### 6. Validation Patterns

```typescript
// packages/shared/validation/src/validators/expense.validators.ts
import { z } from 'zod';

export const CreateExpenseSchema = z.object({
  userId: z.string().uuid('Invalid user ID'),
  amount: z.number().positive('Amount must be positive'),
  currency: z.string().length(3, 'Currency must be 3 characters').toUpperCase(),
  category: z.string().min(1, 'Category is required').max(100, 'Category too long'),
  description: z.string().min(1, 'Description is required').max(500, 'Description too long'),
  date: z.date().max(new Date(), 'Date cannot be in the future'),
  tags: z.array(z.string().min(1).max(50)).max(10, 'Too many tags').optional().default([]),
  receiptUrl: z.string().url('Invalid receipt URL').optional()
});

export const UpdateExpenseSchema = CreateExpenseSchema.partial().omit({ userId: true });

export const ExpenseQuerySchema = z.object({
  userId: z.string().uuid().optional(),
  category: z.string().optional(),
  startDate: z.string().datetime().optional(),
  endDate: z.string().datetime().optional(),
  minAmount: z.number().positive().optional(),
  maxAmount: z.number().positive().optional(),
  tags: z.array(z.string()).optional(),
  page: z.number().int().positive().default(1),
  limit: z.number().int().positive().max(100).default(20),
  sortBy: z.enum(['date', 'amount', 'category']).default('date'),
  sortOrder: z.enum(['asc', 'desc']).default('desc')
});

// Validation decorator
export function ValidateDto(schema: z.ZodSchema) {
  return function(target: any, propertyName: string, descriptor: PropertyDescriptor) {
    const method = descriptor.value;

    descriptor.value = async function(...args: any[]) {
      const dto = args[0];
      
      try {
        const validatedDto = schema.parse(dto);
        args[0] = validatedDto;
      } catch (error) {
        if (error instanceof z.ZodError) {
          throw new ValidationError('Validation failed', error.errors);
        }
        throw error;
      }

      return method.apply(this, args);
    };
  };
}

// Usage in service
export class ExpenseController {
  constructor(private expenseService: ExpenseService) {}

  @ValidateDto(CreateExpenseSchema)
  async createExpense(dto: CreateExpenseDto): Promise<ExpenseEntity> {
    return await this.expenseService.create(dto);
  }

  @ValidateDto(UpdateExpenseSchema)
  async updateExpense(id: string, dto: UpdateExpenseDto): Promise<ExpenseEntity> {
    return await this.expenseService.update(id, dto);
  }
}
```

### 7. API Response Patterns

```typescript
// packages/shared/api/src/responses/api-response.ts
export interface ApiResponse<T = any> {
  success: boolean;
  data?: T;
  error?: {
    code: string;
    message: string;
    details?: any;
  };
  metadata?: {
    timestamp: string;
    requestId: string;
    version: string;
  };
}

export interface PaginatedApiResponse<T> extends ApiResponse<T[]> {
  pagination?: {
    page: number;
    limit: number;
    total: number;
    totalPages: number;
    hasNext: boolean;
    hasPrev: boolean;
  };
}

export class ApiResponseBuilder {
  static success<T>(data: T, metadata?: any): ApiResponse<T> {
    return {
      success: true,
      data,
      metadata: {
        timestamp: new Date().toISOString(),
        requestId: generateRequestId(),
        version: process.env.API_VERSION || '1.0.0',
        ...metadata
      }
    };
  }

  static error(code: string, message: string, details?: any): ApiResponse {
    return {
      success: false,
      error: {
        code,
        message,
        details
      },
      metadata: {
        timestamp: new Date().toISOString(),
        requestId: generateRequestId(),
        version: process.env.API_VERSION || '1.0.0'
      }
    };
  }

  static paginated<T>(
    data: T[], 
    pagination: PaginationOptions & { total: number }
  ): PaginatedApiResponse<T> {
    const totalPages = Math.ceil(pagination.total / pagination.limit);
    
    return {
      success: true,
      data,
      pagination: {
        page: pagination.page,
        limit: pagination.limit,
        total: pagination.total,
        totalPages,
        hasNext: pagination.page < totalPages,
        hasPrev: pagination.page > 1
      },
      metadata: {
        timestamp: new Date().toISOString(),
        requestId: generateRequestId(),
        version: process.env.API_VERSION || '1.0.0'
      }
    };
  }
}

function generateRequestId(): string {
  return Math.random().toString(36).substring(2, 15) + 
         Math.random().toString(36).substring(2, 15);
}
```

## Testing Patterns for Shared Code

### Unit Testing Shared Libraries

```typescript
// packages/shared/domain/src/expense/__tests__/expense.entity.spec.ts
describe('ExpenseEntity', () => {
  const validExpenseProps = {
    userId: 'user-123',
    amount: 100.50,
    currency: 'USD',
    category: 'Food',
    description: 'Lunch at restaurant',
    date: new Date('2024-01-15'),
    tags: ['meal', 'restaurant']
  };

  describe('create', () => {
    it('should create a valid expense entity', () => {
      const expense = ExpenseEntity.create(validExpenseProps);

      expect(expense.userId).toBe(validExpenseProps.userId);
      expect(expense.amount).toBe(validExpenseProps.amount);
      expect(expense.currency).toBe(validExpenseProps.currency);
      expect(expense.category).toBe(validExpenseProps.category);
      expect(expense.description).toBe(validExpenseProps.description);
      expect(expense.date).toEqual(validExpenseProps.date);
      expect(expense.tags).toEqual(validExpenseProps.tags);
    });

    it('should emit ExpenseCreatedEvent when created', () => {
      const expense = ExpenseEntity.create(validExpenseProps);
      const events = expense.getDomainEvents();

      expect(events).toHaveLength(1);
      expect(events[0]).toBeInstanceOf(ExpenseCreatedEvent);
      expect((events[0] as ExpenseCreatedEvent).userId).toBe(validExpenseProps.userId);
    });

    it('should throw error for invalid amount', () => {
      expect(() => {
        ExpenseEntity.create({ ...validExpenseProps, amount: -10 });
      }).toThrow('Expense amount must be positive');
    });

    it('should throw error for future date', () => {
      const futureDate = new Date();
      futureDate.setDate(futureDate.getDate() + 1);

      expect(() => {
        ExpenseEntity.create({ ...validExpenseProps, date: futureDate });
      }).toThrow('Expense date cannot be in the future');
    });
  });

  describe('updateAmount', () => {
    it('should update amount and emit event', () => {
      const expense = ExpenseEntity.create(validExpenseProps);
      expense.clearDomainEvents(); // Clear creation event

      expense.updateAmount(200);

      expect(expense.amount).toBe(200);
      
      const events = expense.getDomainEvents();
      expect(events).toHaveLength(1);
      expect(events[0]).toBeInstanceOf(ExpenseAmountUpdatedEvent);
    });

    it('should throw error for negative amount', () => {
      const expense = ExpenseEntity.create(validExpenseProps);

      expect(() => {
        expense.updateAmount(-50);
      }).toThrow('Amount must be positive');
    });
  });
});
```

### Integration Testing for Shared Services

```typescript
// packages/shared/application/src/services/__tests__/expense.service.integration.spec.ts
describe('ExpenseService Integration', () => {
  let service: ExpenseService;
  let repository: ExpenseRepository;
  let eventBus: EventBus;
  let categoryService: CategoryService;

  beforeEach(async () => {
    // Setup test database
    const connection = await createTestConnection();
    repository = new ExpenseRepository(connection);
    eventBus = createMockEventBus();
    categoryService = createMockCategoryService();
    
    service = new ExpenseService(repository, eventBus, logger, categoryService);
  });

  afterEach(async () => {
    await cleanupTestDatabase();
  });

  describe('create', () => {
    it('should create expense and publish event', async () => {
      const dto: CreateExpenseDto = {
        userId: 'user-123',
        amount: 100,
        currency: 'USD',
        category: 'Food',
        description: 'Test expense',
        date: new Date(),
        tags: ['test']
      };

      const expense = await service.create(dto);

      expect(expense.id).toBeDefined();
      expect(expense.amount).toBe(dto.amount);
      
      // Verify event was published
      expect(eventBus.publish).toHaveBeenCalledWith(
        expect.objectContaining({
          type: 'expense.created',
          data: expect.objectContaining({
            expenseId: expense.id,
            userId: dto.userId
          })
        })
      );
    });

    it('should throw error for invalid category', async () => {
      jest.spyOn(categoryService, 'exists').mockResolvedValue(false);

      const dto: CreateExpenseDto = {
        userId: 'user-123',
        amount: 100,
        currency: 'USD',
        category: 'NonExistentCategory',
        description: 'Test expense',
        date: new Date(),
        tags: []
      };

      await expect(service.create(dto)).rejects.toThrow(
        "Category 'NonExistentCategory' does not exist"
      );
    });
  });

  describe('getExpenseStatistics', () => {
    it('should calculate correct statistics', async () => {
      // Setup test data
      const expenses = [
        await service.create({ userId: 'user-123', amount: 100, category: 'Food', description: 'Lunch', date: new Date('2024-01-01'), currency: 'USD', tags: [] }),
        await service.create({ userId: 'user-123', amount: 50, category: 'Transport', description: 'Bus', date: new Date('2024-01-02'), currency: 'USD', tags: [] }),
        await service.create({ userId: 'user-123', amount: 200, category: 'Food', description: 'Dinner', date: new Date('2024-01-03'), currency: 'USD', tags: [] })
      ];

      const stats = await service.getExpenseStatistics('user-123');

      expect(stats.totalAmount).toBe(350);
      expect(stats.totalCount).toBe(3);
      expect(stats.averageAmount).toBe(350 / 3);
      expect(stats.categoryBreakdown.Food.amount).toBe(300);
      expect(stats.categoryBreakdown.Transport.amount).toBe(50);
    });
  });
});
```

This comprehensive code sharing pattern ensures maximum reusability while maintaining clear boundaries, strong typing, and testability across your monorepo applications.
