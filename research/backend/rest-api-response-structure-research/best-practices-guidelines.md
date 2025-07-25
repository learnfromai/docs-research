# Best Practices Guidelines for REST API Response Structure

## 📋 Overview

This document provides comprehensive best practices and implementation guidelines for REST API response structures, based on industry standards analysis and TodoController improvement requirements.

## 🎯 Core Principles

### 1. Consistency Above All

**Principle**: All API endpoints should return responses in the same structural format.

**Implementation**:

```typescript
// Consistent response wrapper for all endpoints
interface ApiResponse<T = any> {
  success: boolean;
  data?: T;
  error?: ProblemDetails;
  meta: ResponseMetadata;
}

// Every endpoint returns this structure
async getAllTodos(): Promise<ApiResponse<TodoDto[]>>
async createTodo(body: CreateTodoCommand): Promise<ApiResponse<TodoDto>>
async updateTodo(id: string, body: UpdateTodoCommand): Promise<ApiResponse<TodoDto>>
async deleteTodo(id: string): Promise<ApiResponse<void>>
```

### 2. HTTP Semantics Compliance

**Principle**: Response structure should align with HTTP status codes and methods.

**Status Code Mapping**:

| HTTP Method | Success Status | Response Body | Error Scenarios |
|-------------|----------------|---------------|-----------------|
| **GET** | 200 OK | Data in `data` field | 404 Not Found, 500 Internal Error |
| **POST** | 201 Created | Created resource in `data` | 400 Bad Request, 409 Conflict, 422 Unprocessable |
| **PUT** | 200 OK | Updated resource in `data` | 400 Bad Request, 404 Not Found, 422 Unprocessable |
| **PATCH** | 200 OK | Updated resource in `data` | 400 Bad Request, 404 Not Found, 422 Unprocessable |
| **DELETE** | 204 No Content | Empty body (no wrapper) | 404 Not Found, 409 Conflict |

### 3. Type Safety First

**Principle**: Eliminate `Promise<any>` and use strongly typed responses.

**Implementation**:

```typescript
// Define specific DTOs for each operation
interface TodoDto {
  id: string;
  title: string;
  description?: string;
  completed: boolean;
  createdAt: string;
  updatedAt: string;
}

interface CreateTodoCommand {
  title: string;
  description?: string;
}

interface UpdateTodoCommand {
  title?: string;
  description?: string;
  completed?: boolean;
}

// Type-safe controller methods
class TodoController {
  async getAllTodos(): Promise<ApiResponse<TodoDto[]>> {
    // Implementation
  }
  
  async createTodo(
    @Body() body: CreateTodoCommand
  ): Promise<ApiResponse<TodoDto>> {
    // Implementation
  }
}
```

## 🔧 Response Structure Design

### Success Response Format

```typescript
interface SuccessResponse<T> {
  success: true;
  data: T;
  meta: ResponseMetadata;
}

interface ResponseMetadata {
  timestamp: string;          // ISO 8601 format
  requestId: string;          // Unique request identifier
  version: string;            // API version
  executionTime?: number;     // Response time in milliseconds
  pagination?: PaginationMeta; // For collection responses
  links?: HypermediaLinks;    // HATEOAS links (optional)
}

interface PaginationMeta {
  page: number;
  limit: number;
  total: number;
  totalPages: number;
  hasNext: boolean;
  hasPrev: boolean;
}
```

### Error Response Format (RFC 7807 Compliant)

```typescript
interface ErrorResponse {
  success: false;
  error: ProblemDetails;
  meta: ResponseMetadata;
}

interface ProblemDetails {
  type: string;               // URI identifying problem type
  title: string;              // Human-readable summary
  status: number;             // HTTP status code
  detail?: string;            // Instance-specific details
  instance?: string;          // URI identifying occurrence
  [key: string]: any;         // Extension properties
}

// Example error responses
{
  "success": false,
  "error": {
    "type": "https://api.example.com/problems/validation-error",
    "title": "Validation Failed",
    "status": 400,
    "detail": "The request contains invalid data",
    "instance": "/todos",
    "violations": [
      {
        "field": "title",
        "message": "Title is required and must be at least 3 characters"
      }
    ]
  },
  "meta": {
    "timestamp": "2025-07-19T10:30:00.000Z",
    "requestId": "req-abc123",
    "version": "1.0.0"
  }
}
```

## 📝 Implementation Patterns

### 1. Response Builder Utility

```typescript
class ResponseBuilder {
  private static generateRequestId(): string {
    return `req-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
  }

  private static createBaseMeta(): ResponseMetadata {
    return {
      timestamp: new Date().toISOString(),
      requestId: this.generateRequestId(),
      version: process.env.API_VERSION || '1.0.0'
    };
  }

  static success<T>(
    data: T,
    metaOverrides?: Partial<ResponseMetadata>
  ): SuccessResponse<T> {
    return {
      success: true,
      data,
      meta: {
        ...this.createBaseMeta(),
        ...metaOverrides
      }
    };
  }

  static error(
    problem: ProblemDetails,
    instance?: string,
    metaOverrides?: Partial<ResponseMetadata>
  ): ErrorResponse {
    return {
      success: false,
      error: {
        ...problem,
        instance: instance || problem.instance
      },
      meta: {
        ...this.createBaseMeta(),
        ...metaOverrides
      }
    };
  }

  static paginated<T>(
    data: T[],
    pagination: PaginationMeta,
    metaOverrides?: Partial<ResponseMetadata>
  ): SuccessResponse<T[]> {
    return {
      success: true,
      data,
      meta: {
        ...this.createBaseMeta(),
        pagination,
        ...metaOverrides
      }
    };
  }
}
```

### 2. Custom Error Classes

```typescript
abstract class ApiError extends Error {
  abstract readonly type: string;
  abstract readonly title: string;
  abstract readonly status: number;

  constructor(
    message: string,
    public readonly detail?: string,
    public readonly extensions?: Record<string, any>
  ) {
    super(message);
    this.name = this.constructor.name;
  }

  toProblemDetails(instance?: string): ProblemDetails {
    return {
      type: this.type,
      title: this.title,
      status: this.status,
      detail: this.detail || this.message,
      instance,
      ...this.extensions
    };
  }
}

class ValidationError extends ApiError {
  readonly type = 'https://api.example.com/problems/validation-error';
  readonly title = 'Validation Failed';
  readonly status = 400;

  constructor(
    message: string,
    public readonly violations: Array<{ field: string; message: string }>
  ) {
    super(message);
    this.extensions = { violations };
  }
}

class NotFoundError extends ApiError {
  readonly type = 'https://api.example.com/problems/not-found';
  readonly title = 'Resource Not Found';
  readonly status = 404;
}

class BusinessLogicError extends ApiError {
  readonly type = 'https://api.example.com/problems/business-logic';
  readonly title = 'Business Logic Violation';
  readonly status = 422;
}
```

### 3. Global Error Handler

```typescript
@Middleware({ type: 'after' })
export class GlobalErrorHandler implements ExpressErrorMiddlewareInterface {
  error(
    error: any,
    request: any,
    response: any,
    next: (err?: any) => any
  ): void {
    console.error('API Error:', error);

    if (error instanceof ApiError) {
      const errorResponse = ResponseBuilder.error(
        error.toProblemDetails(request.path)
      );
      response.status(error.status).json(errorResponse);
      return;
    }

    if (error.name === 'ValidationError') {
      const validationError = new ValidationError(
        'Validation failed',
        this.parseValidationErrors(error)
      );
      const errorResponse = ResponseBuilder.error(
        validationError.toProblemDetails(request.path)
      );
      response.status(400).json(errorResponse);
      return;
    }

    // Fallback for unexpected errors
    const internalError: ProblemDetails = {
      type: 'https://api.example.com/problems/internal-server-error',
      title: 'Internal Server Error',
      status: 500,
      detail: 'An unexpected error occurred'
    };

    const errorResponse = ResponseBuilder.error(internalError, request.path);
    response.status(500).json(errorResponse);
  }

  private parseValidationErrors(error: any): Array<{ field: string; message: string }> {
    // Parse validation errors based on your validation library
    return [];
  }
}
```

## 🎭 Controller Implementation Examples

### Updated TodoController

```typescript
@Controller('/todos')
@injectable()
export class TodoController {
  private validationSchemas = createCommandValidationSchema();

  constructor(
    @inject(TOKENS.CreateTodoUseCase)
    private createTodoUseCase: CreateTodoUseCase,
    @inject(TOKENS.UpdateTodoUseCase)
    private updateTodoUseCase: UpdateTodoUseCase,
    @inject(TOKENS.DeleteTodoUseCase)
    private deleteTodoUseCase: DeleteTodoUseCase,
    @inject(TOKENS.ToggleTodoUseCase)
    private toggleTodoUseCase: ToggleTodoUseCase,
    @inject(TOKENS.GetAllTodosQueryHandler)
    private getAllTodosQueryHandler: GetAllTodosQueryHandler,
    @inject(TOKENS.GetTodoByIdQueryHandler)
    private getTodoByIdQueryHandler: GetTodoByIdQueryHandler,
  ) {}

  /**
   * GET /api/todos - Get all todos with pagination
   */
  @Get('/')
  async getAllTodos(
    @QueryParam('page') page: number = 1,
    @QueryParam('limit') limit: number = 10,
    @QueryParam('filter') filter?: string
  ): Promise<ApiResponse<TodoDto[]>> {
    try {
      const result = await this.getAllTodosQueryHandler.execute({
        page,
        limit,
        filter
      });
      
      const todoDtos = TodoMapper.toDtoArray(result.todos);
      
      return ResponseBuilder.paginated(todoDtos, {
        page,
        limit,
        total: result.total,
        totalPages: Math.ceil(result.total / limit),
        hasNext: page * limit < result.total,
        hasPrev: page > 1
      });
    } catch (error) {
      throw new ApiError(
        'TODOS_FETCH_FAILED',
        'Failed to retrieve todos',
        500,
        error.message
      );
    }
  }

  /**
   * GET /api/todos/:id - Get todo by ID
   */
  @Get('/:id')
  async getTodoById(@Param('id') id: string): Promise<ApiResponse<TodoDto>> {
    try {
      const todo = await this.getTodoByIdQueryHandler.execute({ id });
      
      if (!todo) {
        throw new NotFoundError(`Todo with ID ${id} not found`);
      }
      
      const todoDto = TodoMapper.toDto(todo);
      return ResponseBuilder.success(todoDto);
    } catch (error) {
      if (error instanceof NotFoundError) {
        throw error;
      }
      throw new ApiError(
        'TODO_FETCH_FAILED',
        'Failed to retrieve todo',
        500,
        error.message
      );
    }
  }

  /**
   * POST /api/todos - Create a new todo
   */
  @Post('/')
  @HttpCode(201)
  async createTodo(
    @Body() body: CreateTodoCommand
  ): Promise<ApiResponse<TodoDto>> {
    try {
      // Validation
      const validatedData = this.validateCommand(
        this.validationSchemas.CreateTodoCommandSchema,
        body
      );

      const todo = await this.createTodoUseCase.execute(validatedData);
      const todoDto = TodoMapper.toDto(todo);

      return ResponseBuilder.success(todoDto);
    } catch (error) {
      if (error instanceof ValidationError) {
        throw error;
      }
      throw new BusinessLogicError('Failed to create todo', error.message);
    }
  }

  /**
   * PUT /api/todos/:id - Update a todo
   */
  @Put('/:id')
  async updateTodo(
    @Param('id') id: string,
    @Body() body: UpdateTodoCommand
  ): Promise<ApiResponse<TodoDto>> {
    try {
      // Validation
      const validatedData = this.validateCommand(
        this.validationSchemas.UpdateTodoCommandSchema,
        { ...body, id }
      );

      const updatedTodo = await this.updateTodoUseCase.execute(validatedData);
      
      if (!updatedTodo) {
        throw new NotFoundError(`Todo with ID ${id} not found`);
      }
      
      const todoDto = TodoMapper.toDto(updatedTodo);
      return ResponseBuilder.success(todoDto);
    } catch (error) {
      if (error instanceof NotFoundError || error instanceof ValidationError) {
        throw error;
      }
      throw new BusinessLogicError('Failed to update todo', error.message);
    }
  }

  /**
   * PATCH /api/todos/:id/toggle - Toggle todo completion
   */
  @Patch('/:id/toggle')
  async toggleTodo(@Param('id') id: string): Promise<ApiResponse<TodoDto>> {
    try {
      const validatedData = this.validateCommand(
        this.validationSchemas.ToggleTodoCommandSchema,
        { id }
      );

      const toggledTodo = await this.toggleTodoUseCase.execute(validatedData);
      
      if (!toggledTodo) {
        throw new NotFoundError(`Todo with ID ${id} not found`);
      }
      
      const todoDto = TodoMapper.toDto(toggledTodo);
      return ResponseBuilder.success(todoDto);
    } catch (error) {
      if (error instanceof NotFoundError || error instanceof ValidationError) {
        throw error;
      }
      throw new BusinessLogicError('Failed to toggle todo', error.message);
    }
  }

  /**
   * DELETE /api/todos/:id - Delete a todo
   * Note: Returns HTTP 204 No Content with empty body
   */
  @Delete('/:id')
  @HttpCode(204)
  async deleteTodo(@Param('id') id: string): Promise<void> {
    try {
      const validatedData = this.validateCommand(
        this.validationSchemas.DeleteTodoCommandSchema,
        { id }
      );

      const deleted = await this.deleteTodoUseCase.execute(validatedData);
      
      if (!deleted) {
        throw new NotFoundError(`Todo with ID ${id} not found`);
      }

      // HTTP 204 No Content - no response body
      return;
    } catch (error) {
      if (error instanceof NotFoundError || error instanceof ValidationError) {
        throw error;
      }
      throw new BusinessLogicError('Failed to delete todo', error.message);
    }
  }

  private validateCommand<T>(schema: any, data: unknown): T {
    if (!schema) {
      return data as T;
    }

    try {
      return schema.parse(data);
    } catch (error) {
      if (error.name === 'ZodError') {
        const violations = error.errors.map((err: any) => ({
          field: err.path.join('.'),
          message: err.message
        }));
        throw new ValidationError('Validation failed', violations);
      }
      throw error;
    }
  }
}
```

## 🚀 Performance Considerations

### 1. Response Size Optimization

```typescript
// Use field selection for large responses
interface FieldSelection {
  fields?: string[];
}

async getAllTodos(
  @QueryParam('fields') fields?: string
): Promise<ApiResponse<Partial<TodoDto>[]>> {
  const selectedFields = fields ? fields.split(',') : undefined;
  
  const result = await this.getAllTodosQueryHandler.execute({
    fields: selectedFields
  });
  
  const todoDtos = TodoMapper.toDtoArray(result.todos, selectedFields);
  return ResponseBuilder.success(todoDtos);
}
```

### 2. Caching Headers

```typescript
@Get('/:id')
async getTodoById(
  @Param('id') id: string,
  @Res() response: express.Response
): Promise<ApiResponse<TodoDto>> {
  const todo = await this.getTodoByIdQueryHandler.execute({ id });
  
  // Set cache headers
  response.set({
    'Cache-Control': 'public, max-age=300', // 5 minutes
    'ETag': `"${todo.updatedAt}"`,
    'Last-Modified': new Date(todo.updatedAt).toUTCString()
  });

  const todoDto = TodoMapper.toDto(todo);
  return ResponseBuilder.success(todoDto);
}
```

## 📊 Testing Best Practices

### Response Contract Testing

```typescript
describe('TodoController Response Structure', () => {
  it('should return consistent success response format', async () => {
    const response = await request(app)
      .get('/api/todos')
      .expect(200);

    // Validate response structure
    expect(response.body).toHaveProperty('success', true);
    expect(response.body).toHaveProperty('data');
    expect(response.body).toHaveProperty('meta');
    expect(response.body.meta).toHaveProperty('timestamp');
    expect(response.body.meta).toHaveProperty('requestId');
    expect(response.body.meta).toHaveProperty('version');
  });

  it('should return RFC 7807 compliant error response', async () => {
    const response = await request(app)
      .post('/api/todos')
      .send({}) // Invalid body
      .expect(400);

    expect(response.body).toHaveProperty('success', false);
    expect(response.body).toHaveProperty('error');
    expect(response.body.error).toHaveProperty('type');
    expect(response.body.error).toHaveProperty('title');
    expect(response.body.error).toHaveProperty('status', 400);
  });

  it('should include pagination metadata for collections', async () => {
    const response = await request(app)
      .get('/api/todos?page=1&limit=10')
      .expect(200);

    expect(response.body.meta).toHaveProperty('pagination');
    expect(response.body.meta.pagination).toMatchObject({
      page: 1,
      limit: 10,
      total: expect.any(Number),
      totalPages: expect.any(Number),
      hasNext: expect.any(Boolean),
      hasPrev: expect.any(Boolean)
    });
  });
});
```

## 📚 Documentation Integration

### OpenAPI Schema Generation

```typescript
// Use decorators for OpenAPI documentation
@ApiResponse({
  status: 200,
  description: 'Successfully retrieved todos',
  schema: {
    type: 'object',
    properties: {
      success: { type: 'boolean', example: true },
      data: {
        type: 'array',
        items: { $ref: '#/components/schemas/TodoDto' }
      },
      meta: { $ref: '#/components/schemas/ResponseMetadata' }
    }
  }
})
@ApiResponse({
  status: 400,
  description: 'Bad Request',
  schema: { $ref: '#/components/schemas/ErrorResponse' }
})
@Get('/')
async getAllTodos(): Promise<ApiResponse<TodoDto[]>> {
  // Implementation
}
```

## 🔄 Migration Strategy

### Gradual Implementation Approach

1. **Phase 1**: Implement response types and utilities
2. **Phase 2**: Update error handling with global middleware
3. **Phase 3**: Migrate existing endpoints one by one
4. **Phase 4**: Add advanced features (pagination, caching, HATEOAS)

### Backward Compatibility

```typescript
// Support both old and new response formats during migration
class ResponseBuilder {
  static success<T>(data: T, legacy: boolean = false): any {
    if (legacy) {
      return { success: true, data }; // Old format
    }
    
    return {
      success: true,
      data,
      meta: this.createBaseMeta()
    }; // New format
  }
}
```

---

## 🔗 Navigation

### Previous: [Industry Standards Comparison](./industry-standards-comparison.md)

### Next: [Implementation Examples](./implementation-examples.md)

---

*Best practices guidelines completed on July 19, 2025*  
*Based on industry standards and TodoController analysis*
