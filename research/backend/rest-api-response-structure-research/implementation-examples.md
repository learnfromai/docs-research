# Implementation Examples: REST API Response Structure

## 🎯 Overview

This document provides concrete TypeScript/Express.js implementation examples that demonstrate the recommended REST API response structure best practices. All examples build upon the current TodoController implementation while incorporating industry standards like RFC 7807 Problem Details.

## 📋 Table of Contents

1. [Core Response Types](#core-response-types)
2. [Updated TodoController Implementation](#updated-todocontroller-implementation)
3. [Error Handling Middleware](#error-handling-middleware)
4. [Response Utilities](#response-utilities)
5. [Validation Integration](#validation-integration)
6. [Pagination Implementation](#pagination-implementation)
7. [Testing Examples](#testing-examples)

## 🔧 Core Response Types

### Base Response Interface

```typescript
// types/api-response.ts
export interface ApiResponse<T = any> {
  success: boolean;
  data?: T;
  error?: ProblemDetails;
  meta?: ResponseMetadata;
}

export interface ProblemDetails {
  type: string;           // URI identifying the problem type
  title: string;          // Human-readable summary
  status: number;         // HTTP status code
  detail?: string;        // Instance-specific explanation
  instance?: string;      // URI identifying the problem instance
  [key: string]: any;     // Extension properties for additional context
}

export interface ResponseMetadata {
  timestamp: string;
  requestId: string;
  version: string;
  pagination?: PaginationMeta;
  links?: HateoasLinks;
}

export interface PaginationMeta {
  page: number;
  limit: number;
  total: number;
  totalPages: number;
  hasNext: boolean;
  hasPrevious: boolean;
}

export interface HateoasLinks {
  self: string;
  first?: string;
  last?: string;
  next?: string;
  previous?: string;
}

export interface ValidationViolation {
  field: string;
  message: string;
  code: string;
  rejectedValue?: any;
}
```

### Success Response Types

```typescript
// types/success-responses.ts
export interface TodoListResponse extends ApiResponse<TodoDto[]> {
  data: TodoDto[];
  meta: ResponseMetadata & {
    pagination: PaginationMeta;
  };
}

export interface TodoSingleResponse extends ApiResponse<TodoDto> {
  data: TodoDto;
  meta: ResponseMetadata;
}

export interface TodoCreatedResponse extends ApiResponse<TodoDto> {
  data: TodoDto;
  meta: ResponseMetadata & {
    links: {
      self: string;
      edit: string;
      delete: string;
    };
  };
}
```

### Error Response Types

```typescript
// types/error-responses.ts
export interface ValidationErrorResponse extends ApiResponse<never> {
  success: false;
  error: ProblemDetails & {
    type: 'https://api.example.com/problems/validation-error';
    violations: ValidationViolation[];
  };
}

export interface NotFoundErrorResponse extends ApiResponse<never> {
  success: false;
  error: ProblemDetails & {
    type: 'https://api.example.com/problems/not-found';
    resourceType: string;
    resourceId: string;
  };
}

export interface InternalErrorResponse extends ApiResponse<never> {
  success: false;
  error: ProblemDetails & {
    type: 'https://api.example.com/problems/internal-error';
    errorId: string;
  };
}
```

## 🏗️ Updated TodoController Implementation

### Improved TodoController

```typescript
// controllers/todo.controller.ts
import { Request, Response } from 'express';
import { Get, Post, Put, Delete, JsonController, Body, Param, Req, Res, QueryParams } from 'routing-controllers';
import { inject, injectable } from 'tsyringe';
import { TodoService } from '../services/todo.service';
import { CreateTodoCommand, UpdateTodoCommand } from '../commands/todo.commands';
import { TodoDto } from '../dtos/todo.dto';
import { ResponseBuilder } from '../utils/response-builder';
import { ApiResponse, TodoListResponse, TodoSingleResponse, TodoCreatedResponse } from '../types/api-response';
import { PaginationQuery } from '../types/pagination';

@JsonController('/todos')
@injectable()
export class TodoController {
  constructor(
    @inject('TodoService') private todoService: TodoService,
    @inject('ResponseBuilder') private responseBuilder: ResponseBuilder
  ) {}

  @Get('')
  async getAllTodos(
    @QueryParams() pagination: PaginationQuery,
    @Req() req: Request,
    @Res() res: Response
  ): Promise<TodoListResponse> {
    try {
      const result = await this.todoService.getAllTodos(pagination);
      
      return this.responseBuilder.success<TodoDto[]>({
        data: result.items,
        meta: {
          pagination: {
            page: pagination.page || 1,
            limit: pagination.limit || 10,
            total: result.total,
            totalPages: Math.ceil(result.total / (pagination.limit || 10)),
            hasNext: result.hasNext,
            hasPrevious: result.hasPrevious
          },
          links: {
            self: req.originalUrl,
            first: this.buildPaginationUrl(req, { page: 1, limit: pagination.limit }),
            last: this.buildPaginationUrl(req, { 
              page: Math.ceil(result.total / (pagination.limit || 10)), 
              limit: pagination.limit 
            }),
            ...(result.hasNext && {
              next: this.buildPaginationUrl(req, { 
                page: (pagination.page || 1) + 1, 
                limit: pagination.limit 
              })
            }),
            ...(result.hasPrevious && {
              previous: this.buildPaginationUrl(req, { 
                page: (pagination.page || 1) - 1, 
                limit: pagination.limit 
              })
            })
          }
        },
        req
      });
    } catch (error) {
      throw this.responseBuilder.internalError(error, req);
    }
  }

  @Get('/:id')
  async getTodoById(
    @Param('id') id: string,
    @Req() req: Request,
    @Res() res: Response
  ): Promise<TodoSingleResponse> {
    try {
      const todo = await this.todoService.getTodoById(id);
      
      if (!todo) {
        throw this.responseBuilder.notFoundError({
          resourceType: 'Todo',
          resourceId: id,
          req
        });
      }

      return this.responseBuilder.success<TodoDto>({
        data: todo,
        meta: {
          links: {
            self: req.originalUrl,
            edit: `/todos/${id}`,
            delete: `/todos/${id}`,
            collection: '/todos'
          }
        },
        req
      });
    } catch (error) {
      if (error.status) {
        throw error; // Re-throw known errors
      }
      throw this.responseBuilder.internalError(error, req);
    }
  }

  @Post('')
  async createTodo(
    @Body() body: CreateTodoCommand,
    @Req() req: Request,
    @Res() res: Response
  ): Promise<TodoCreatedResponse> {
    try {
      const todo = await this.todoService.createTodo(body);
      
      // Set 201 Created status
      res.status(201);
      
      return this.responseBuilder.success<TodoDto>({
        data: todo,
        meta: {
          links: {
            self: `/todos/${todo.id}`,
            edit: `/todos/${todo.id}`,
            delete: `/todos/${todo.id}`,
            collection: '/todos'
          }
        },
        req
      });
    } catch (error) {
      throw this.responseBuilder.internalError(error, req);
    }
  }

  @Put('/:id')
  async updateTodo(
    @Param('id') id: string,
    @Body() body: UpdateTodoCommand,
    @Req() req: Request,
    @Res() res: Response
  ): Promise<TodoSingleResponse> {
    try {
      const existingTodo = await this.todoService.getTodoById(id);
      
      if (!existingTodo) {
        throw this.responseBuilder.notFoundError({
          resourceType: 'Todo',
          resourceId: id,
          req
        });
      }

      const updatedTodo = await this.todoService.updateTodo(id, body);
      
      return this.responseBuilder.success<TodoDto>({
        data: updatedTodo,
        meta: {
          links: {
            self: req.originalUrl,
            view: `/todos/${id}`,
            delete: `/todos/${id}`,
            collection: '/todos'
          }
        },
        req
      });
    } catch (error) {
      if (error.status) {
        throw error; // Re-throw known errors
      }
      throw this.responseBuilder.internalError(error, req);
    }
  }

  @Delete('/:id')
  async deleteTodo(
    @Param('id') id: string,
    @Req() req: Request,
    @Res() res: Response
  ): Promise<ApiResponse<null>> {
    try {
      const existingTodo = await this.todoService.getTodoById(id);
      
      if (!existingTodo) {
        throw this.responseBuilder.notFoundError({
          resourceType: 'Todo',
          resourceId: id,
          req
        });
      }

      await this.todoService.deleteTodo(id);
      
      // Set 204 No Content status
      res.status(204);
      
      return this.responseBuilder.success<null>({
        data: null,
        meta: {
          links: {
            collection: '/todos'
          }
        },
        req
      });
    } catch (error) {
      if (error.status) {
        throw error; // Re-throw known errors
      }
      throw this.responseBuilder.internalError(error, req);
    }
  }

  private buildPaginationUrl(req: Request, params: { page: number; limit?: number }): string {
    const baseUrl = `${req.protocol}://${req.get('host')}${req.baseUrl}${req.path}`;
    const query = new URLSearchParams();
    query.set('page', params.page.toString());
    if (params.limit) {
      query.set('limit', params.limit.toString());
    }
    return `${baseUrl}?${query.toString()}`;
  }
}
```

## 🛠️ Response Utilities

### ResponseBuilder Utility

```typescript
// utils/response-builder.ts
import { Request } from 'express';
import { injectable } from 'tsyringe';
import { v4 as uuidv4 } from 'uuid';
import { 
  ApiResponse, 
  ProblemDetails, 
  ResponseMetadata,
  ValidationViolation 
} from '../types/api-response';
import { HttpError } from '../errors/http-error';

@injectable()
export class ResponseBuilder {
  success<T>(options: {
    data: T;
    meta?: Partial<ResponseMetadata>;
    req: Request;
  }): ApiResponse<T> {
    return {
      success: true,
      data: options.data,
      meta: {
        timestamp: new Date().toISOString(),
        requestId: this.getRequestId(options.req),
        version: process.env.API_VERSION || '1.0.0',
        ...options.meta
      }
    };
  }

  validationError(options: {
    violations: ValidationViolation[];
    req: Request;
    detail?: string;
  }): HttpError {
    const error: ProblemDetails = {
      type: 'https://api.example.com/problems/validation-error',
      title: 'Validation Failed',
      status: 400,
      detail: options.detail || 'The request contains invalid data',
      instance: options.req.originalUrl,
      violations: options.violations
    };

    return new HttpError(400, {
      success: false,
      error,
      meta: this.buildErrorMetadata(options.req)
    });
  }

  notFoundError(options: {
    resourceType: string;
    resourceId: string;
    req: Request;
  }): HttpError {
    const error: ProblemDetails = {
      type: 'https://api.example.com/problems/not-found',
      title: 'Resource Not Found',
      status: 404,
      detail: `The requested ${options.resourceType} with ID '${options.resourceId}' was not found`,
      instance: options.req.originalUrl,
      resourceType: options.resourceType,
      resourceId: options.resourceId
    };

    return new HttpError(404, {
      success: false,
      error,
      meta: this.buildErrorMetadata(options.req)
    });
  }

  internalError(originalError: any, req: Request): HttpError {
    const errorId = uuidv4();
    
    // Log the actual error for debugging (don't expose to client)
    console.error(`Internal Error [${errorId}]:`, originalError);
    
    const error: ProblemDetails = {
      type: 'https://api.example.com/problems/internal-error',
      title: 'Internal Server Error',
      status: 500,
      detail: 'An unexpected error occurred while processing your request',
      instance: req.originalUrl,
      errorId
    };

    return new HttpError(500, {
      success: false,
      error,
      meta: this.buildErrorMetadata(req)
    });
  }

  conflictError(options: {
    resource: string;
    conflict: string;
    req: Request;
  }): HttpError {
    const error: ProblemDetails = {
      type: 'https://api.example.com/problems/conflict',
      title: 'Resource Conflict',
      status: 409,
      detail: `Cannot process request due to conflict: ${options.conflict}`,
      instance: options.req.originalUrl,
      resource: options.resource,
      conflict: options.conflict
    };

    return new HttpError(409, {
      success: false,
      error,
      meta: this.buildErrorMetadata(options.req)
    });
  }

  private buildErrorMetadata(req: Request): ResponseMetadata {
    return {
      timestamp: new Date().toISOString(),
      requestId: this.getRequestId(req),
      version: process.env.API_VERSION || '1.0.0'
    };
  }

  private getRequestId(req: Request): string {
    // Check if request ID is already set by middleware
    return req.headers['x-request-id'] as string || uuidv4();
  }
}
```

### HTTP Error Class

```typescript
// errors/http-error.ts
import { ApiResponse } from '../types/api-response';

export class HttpError extends Error {
  public readonly status: number;
  public readonly response: ApiResponse<never>;

  constructor(status: number, response: ApiResponse<never>) {
    super(response.error?.title || 'HTTP Error');
    this.status = status;
    this.response = response;
    
    // Maintains proper stack trace for where error was thrown
    Error.captureStackTrace(this, HttpError);
  }
}
```

## 🔧 Middleware Implementation

### Request ID Middleware

```typescript
// middleware/request-id.middleware.ts
import { Request, Response, NextFunction } from 'express';
import { v4 as uuidv4 } from 'uuid';

export function requestIdMiddleware(req: Request, res: Response, next: NextFunction): void {
  const requestId = req.headers['x-request-id'] as string || uuidv4();
  
  // Store in request for use in controllers and services
  req.headers['x-request-id'] = requestId;
  
  // Send back in response headers
  res.setHeader('X-Request-ID', requestId);
  
  next();
}
```

### Global Error Handler

```typescript
// middleware/error-handler.middleware.ts
import { Request, Response, NextFunction } from 'express';
import { HttpError } from '../errors/http-error';
import { ResponseBuilder } from '../utils/response-builder';

export function globalErrorHandler(
  error: any,
  req: Request,
  res: Response,
  next: NextFunction
): void {
  const responseBuilder = new ResponseBuilder();

  if (error instanceof HttpError) {
    // Handle our custom HTTP errors
    res.status(error.status).json(error.response);
  } else if (error.name === 'ValidationError') {
    // Handle validation errors from routing-controllers
    const violations = error.errors?.map((err: any) => ({
      field: err.property,
      message: Object.values(err.constraints || {}).join(', '),
      code: 'VALIDATION_FAILED',
      rejectedValue: err.value
    })) || [];

    const httpError = responseBuilder.validationError({
      violations,
      req,
      detail: 'Request validation failed'
    });

    res.status(httpError.status).json(httpError.response);
  } else {
    // Handle unexpected errors
    const httpError = responseBuilder.internalError(error, req);
    res.status(httpError.status).json(httpError.response);
  }
}
```

## 📊 Pagination Implementation

### Pagination Query Types

```typescript
// types/pagination.ts
import { IsOptional, IsPositive, Max, Min } from 'class-validator';
import { Transform } from 'class-transformer';

export class PaginationQuery {
  @IsOptional()
  @Transform(({ value }) => parseInt(value))
  @IsPositive()
  @Min(1)
  page?: number = 1;

  @IsOptional()
  @Transform(({ value }) => parseInt(value))
  @IsPositive()
  @Min(1)
  @Max(100)
  limit?: number = 10;

  @IsOptional()
  sortBy?: string = 'createdAt';

  @IsOptional()
  sortOrder?: 'asc' | 'desc' = 'desc';
}

export interface PaginatedResult<T> {
  items: T[];
  total: number;
  hasNext: boolean;
  hasPrevious: boolean;
}
```

### Service Layer Pagination

```typescript
// services/todo.service.ts - Updated with pagination
import { inject, injectable } from 'tsyringe';
import { TodoRepository } from '../repositories/todo.repository';
import { TodoDto } from '../dtos/todo.dto';
import { TodoMapper } from '../mappers/todo.mapper';
import { CreateTodoCommand, UpdateTodoCommand } from '../commands/todo.commands';
import { PaginationQuery, PaginatedResult } from '../types/pagination';

@injectable()
export class TodoService {
  constructor(
    @inject('TodoRepository') private todoRepository: TodoRepository,
    @inject('TodoMapper') private todoMapper: TodoMapper
  ) {}

  async getAllTodos(pagination: PaginationQuery): Promise<PaginatedResult<TodoDto>> {
    const offset = ((pagination.page || 1) - 1) * (pagination.limit || 10);
    
    const [todos, total] = await Promise.all([
      this.todoRepository.findMany({
        offset,
        limit: pagination.limit || 10,
        sortBy: pagination.sortBy || 'createdAt',
        sortOrder: pagination.sortOrder || 'desc'
      }),
      this.todoRepository.count()
    ]);

    const items = todos.map(todo => this.todoMapper.toDto(todo));
    const currentPage = pagination.page || 1;
    const pageSize = pagination.limit || 10;

    return {
      items,
      total,
      hasNext: currentPage * pageSize < total,
      hasPrevious: currentPage > 1
    };
  }

  // ... other methods remain the same
}
```

## 🧪 Testing Examples

### Response Structure Tests

```typescript
// tests/todo-controller.test.ts
import request from 'supertest';
import { app } from '../app';
import { ApiResponse, TodoListResponse, TodoSingleResponse } from '../types/api-response';

describe('TodoController Response Structure', () => {
  describe('GET /todos', () => {
    it('should return properly structured paginated response', async () => {
      const response = await request(app)
        .get('/todos?page=1&limit=5')
        .expect(200);

      const body: TodoListResponse = response.body;

      // Test response structure
      expect(body).toHaveProperty('success', true);
      expect(body).toHaveProperty('data');
      expect(body).toHaveProperty('meta');
      expect(body.data).toBeInstanceOf(Array);

      // Test metadata structure
      expect(body.meta).toHaveProperty('timestamp');
      expect(body.meta).toHaveProperty('requestId');
      expect(body.meta).toHaveProperty('version');
      expect(body.meta).toHaveProperty('pagination');

      // Test pagination metadata
      expect(body.meta.pagination).toHaveProperty('page', 1);
      expect(body.meta.pagination).toHaveProperty('limit', 5);
      expect(body.meta.pagination).toHaveProperty('total');
      expect(body.meta.pagination).toHaveProperty('totalPages');
      expect(body.meta.pagination).toHaveProperty('hasNext');
      expect(body.meta.pagination).toHaveProperty('hasPrevious');

      // Test HATEOAS links
      expect(body.meta).toHaveProperty('links');
      expect(body.meta.links).toHaveProperty('self');
      expect(body.meta.links).toHaveProperty('first');
      expect(body.meta.links).toHaveProperty('last');
    });
  });

  describe('GET /todos/:id', () => {
    it('should return properly structured single resource response', async () => {
      const response = await request(app)
        .get('/todos/123')
        .expect(200);

      const body: TodoSingleResponse = response.body;

      // Test response structure
      expect(body).toHaveProperty('success', true);
      expect(body).toHaveProperty('data');
      expect(body).toHaveProperty('meta');
      expect(body.data).toHaveProperty('id');

      // Test metadata
      expect(body.meta).toHaveProperty('timestamp');
      expect(body.meta).toHaveProperty('requestId');
      expect(body.meta).toHaveProperty('version');

      // Test HATEOAS links
      expect(body.meta).toHaveProperty('links');
      expect(body.meta.links).toHaveProperty('self');
      expect(body.meta.links).toHaveProperty('edit');
      expect(body.meta.links).toHaveProperty('delete');
      expect(body.meta.links).toHaveProperty('collection');
    });

    it('should return RFC 7807 compliant error for not found resource', async () => {
      const response = await request(app)
        .get('/todos/nonexistent')
        .expect(404);

      const body: ApiResponse<never> = response.body;

      // Test error structure
      expect(body).toHaveProperty('success', false);
      expect(body).toHaveProperty('error');
      expect(body).toHaveProperty('meta');

      // Test RFC 7807 compliance
      expect(body.error).toHaveProperty('type');
      expect(body.error).toHaveProperty('title');
      expect(body.error).toHaveProperty('status', 404);
      expect(body.error).toHaveProperty('detail');
      expect(body.error).toHaveProperty('instance');
      expect(body.error).toHaveProperty('resourceType', 'Todo');
      expect(body.error).toHaveProperty('resourceId', 'nonexistent');
    });
  });

  describe('POST /todos', () => {
    it('should return 201 with properly structured created response', async () => {
      const createData = {
        title: 'Test Todo',
        description: 'Test Description'
      };

      const response = await request(app)
        .post('/todos')
        .send(createData)
        .expect(201);

      const body: TodoSingleResponse = response.body;

      // Test response structure
      expect(body).toHaveProperty('success', true);
      expect(body).toHaveProperty('data');
      expect(body.data).toHaveProperty('id');
      expect(body.data).toHaveProperty('title', createData.title);

      // Test HATEOAS links for created resource
      expect(body.meta.links).toHaveProperty('self');
      expect(body.meta.links).toHaveProperty('edit');
      expect(body.meta.links).toHaveProperty('delete');
      expect(body.meta.links).toHaveProperty('collection');
    });

    it('should return validation error with proper structure', async () => {
      const invalidData = {
        title: '', // Invalid empty title
        description: 'Test Description'
      };

      const response = await request(app)
        .post('/todos')
        .send(invalidData)
        .expect(400);

      const body: ApiResponse<never> = response.body;

      // Test validation error structure
      expect(body).toHaveProperty('success', false);
      expect(body).toHaveProperty('error');
      expect(body.error).toHaveProperty('type');
      expect(body.error.type).toContain('validation-error');
      expect(body.error).toHaveProperty('violations');
      expect(body.error.violations).toBeInstanceOf(Array);
      expect(body.error.violations[0]).toHaveProperty('field');
      expect(body.error.violations[0]).toHaveProperty('message');
      expect(body.error.violations[0]).toHaveProperty('code');
    });
  });
});
```

## 📝 Integration Examples

### OpenAPI Documentation Integration

```typescript
// config/swagger.ts
import { ApiResponse, ProblemDetails } from '../types/api-response';

export const swaggerDefinition = {
  openapi: '3.0.0',
  info: {
    title: 'Todo API',
    version: '1.0.0',
    description: 'REST API with standardized response structure'
  },
  components: {
    schemas: {
      ApiResponse: {
        type: 'object',
        properties: {
          success: { type: 'boolean' },
          data: { type: 'object' },
          error: { $ref: '#/components/schemas/ProblemDetails' },
          meta: { $ref: '#/components/schemas/ResponseMetadata' }
        }
      },
      ProblemDetails: {
        type: 'object',
        required: ['type', 'title', 'status'],
        properties: {
          type: { type: 'string', format: 'uri' },
          title: { type: 'string' },
          status: { type: 'integer' },
          detail: { type: 'string' },
          instance: { type: 'string', format: 'uri' }
        }
      },
      ResponseMetadata: {
        type: 'object',
        properties: {
          timestamp: { type: 'string', format: 'date-time' },
          requestId: { type: 'string', format: 'uuid' },
          version: { type: 'string' },
          pagination: { $ref: '#/components/schemas/PaginationMeta' },
          links: { $ref: '#/components/schemas/HateoasLinks' }
        }
      }
    }
  }
};
```

## 🔗 Navigation

### Previous: [Best Practices Guidelines](./best-practices-guidelines.md)

### Next: [Error Handling Patterns](./error-handling-patterns.md)

---

## Related Documentation

- [Current Implementation Analysis](./current-implementation-analysis.md)
- [Industry Standards Comparison](./industry-standards-comparison.md)
- [Migration Strategy](./migration-strategy.md)

---

*Implementation Examples completed on July 19, 2025*  
*Based on industry standards and TypeScript best practices*