# Template Examples

## 🎯 Production-Ready Response Templates

This document provides comprehensive, copy-paste ready templates and utilities for implementing enhanced HTTP API response formats while maintaining backward compatibility with your current system.

## 🏗️ Core Response Builder Template

### Complete Response Builder Class

```typescript
// src/utils/api-response-builder.ts
import { randomUUID } from 'crypto';

// Core interfaces
export interface ResponseMetadata {
  timestamp: string;
  requestId: string;
  version: string;
  execution?: ExecutionMeta;
  pagination?: PaginationMeta;
  collection?: CollectionMeta;
  resource?: ResourceMeta;
  rateLimit?: RateLimitMeta;
}

export interface ExecutionMeta {
  duration: number;
  cached: boolean;
  dbQueries?: number;
  memoryUsage?: number;
}

export interface PaginationMeta {
  page: number;
  limit: number;
  total: number;
  pages: number;
  hasNext: boolean;
  hasPrev: boolean;
  links: PaginationLinks;
}

export interface PaginationLinks {
  first: string;
  prev?: string;
  next?: string;
  last: string;
}

export interface CollectionMeta {
  total: number;
  count: number;
  hasMore: boolean;
  filtered?: boolean;
  sortBy?: string;
  sortOrder?: 'asc' | 'desc';
}

export interface ResourceMeta {
  type: string;
  etag?: string;
  lastModified?: string;
  version?: string;
}

export interface RateLimitMeta {
  remaining: number;
  limit: number;
  resetTime: string;
  retryAfter?: number;
}

// RFC 7807 Problem Details
export interface ProblemDetails {
  type: string;
  title: string;
  status: number;
  detail?: string;
  instance?: string;
  violations?: ValidationViolation[];
  help?: string;
  
  // Backward compatibility
  code?: string;
  fieldErrors?: Record<string, string[]>;
}

export interface ValidationViolation {
  field: string;
  code: string;
  message: string;
  value?: any;
  expected?: string;
  severity?: 'error' | 'warning';
}

// Response types
export interface BaseResponse {
  success: boolean;
  meta: ResponseMetadata;
}

export interface SuccessResponse<T = any> extends BaseResponse {
  success: true;
  data?: T;
  message?: string;
}

export interface ErrorResponse extends BaseResponse {
  success: false;
  error: ProblemDetails;
}

// Main response builder class
export class ApiResponseBuilder {
  private requestId: string;
  private timestamp: string;
  private startTime: number;
  private version: string;

  constructor(
    requestId?: string, 
    startTime: number = Date.now(),
    version: string = '1.0'
  ) {
    this.requestId = requestId || randomUUID();
    this.startTime = startTime;
    this.timestamp = new Date().toISOString();
    this.version = version;
  }

  // Success response for single resource
  success<T>(
    data?: T, 
    message?: string,
    resourceMeta?: Partial<ResourceMeta>
  ): SuccessResponse<T> {
    return {
      success: true,
      ...(data !== undefined && { data }),
      ...(message && { message }),
      meta: {
        ...this.buildBaseMeta(),
        ...(resourceMeta && { resource: resourceMeta })
      }
    };
  }

  // Success response for collections with pagination
  collection<T>(
    data: T[],
    total: number,
    page: number = 1,
    limit: number = 20,
    baseUrl: string = '',
    options: {
      filtered?: boolean;
      sortBy?: string;
      sortOrder?: 'asc' | 'desc';
    } = {}
  ): SuccessResponse<T[]> {
    const pages = Math.ceil(total / limit);
    const hasNext = page < pages;
    const hasPrev = page > 1;

    return {
      success: true,
      data,
      meta: {
        ...this.buildBaseMeta(),
        collection: {
          total,
          count: data.length,
          hasMore: hasNext,
          filtered: options.filtered || false,
          ...(options.sortBy && { sortBy: options.sortBy }),
          ...(options.sortOrder && { sortOrder: options.sortOrder })
        },
        pagination: {
          page,
          limit,
          total,
          pages,
          hasNext,
          hasPrev,
          links: {
            first: `${baseUrl}?page=1&limit=${limit}`,
            ...(hasPrev && { 
              prev: `${baseUrl}?page=${page - 1}&limit=${limit}` 
            }),
            ...(hasNext && { 
              next: `${baseUrl}?page=${page + 1}&limit=${limit}` 
            }),
            last: `${baseUrl}?page=${pages}&limit=${limit}`
          }
        }
      }
    };
  }

  // Error response builder
  error(problemDetails: ProblemDetails): ErrorResponse {
    return {
      success: false,
      error: {
        ...problemDetails,
        instance: problemDetails.instance || this.requestId
      },
      meta: this.buildBaseMeta()
    };
  }

  // Validation error builder (maintains backward compatibility)
  validationError(
    violations: ValidationViolation[],
    legacyFieldErrors?: Record<string, string[]>
  ): ErrorResponse {
    const fieldErrors = legacyFieldErrors || this.createFieldErrorsMap(violations);
    
    return this.error({
      type: '/errors/validation-failed',
      title: 'Validation Failed',
      status: 400,
      detail: `${violations.length} field(s) failed validation`,
      violations,
      fieldErrors, // Backward compatibility
      code: 'VALIDATION_ERROR' // Backward compatibility
    });
  }

  // Domain error builder
  domainError(
    type: string,
    title: string,
    status: number,
    detail: string,
    code?: string,
    help?: string
  ): ErrorResponse {
    return this.error({
      type,
      title,
      status,
      detail,
      ...(code && { code }),
      ...(help && { help })
    });
  }

  // Authentication error template
  authenticationError(
    detail: string = 'Invalid email/username or password',
    code: string = 'AUTH_INVALID_CREDENTIALS'
  ): ErrorResponse {
    return this.domainError(
      '/errors/authentication/invalid-credentials',
      'Authentication Failed',
      401,
      detail,
      code,
      '/docs/authentication'
    );
  }

  // Conflict error template
  conflictError(
    detail: string,
    code: string,
    help?: string
  ): ErrorResponse {
    return this.domainError(
      '/errors/conflict',
      'Resource Conflict',
      409,
      detail,
      code,
      help
    );
  }

  // Not found error template
  notFoundError(
    resource: string,
    identifier?: string
  ): ErrorResponse {
    const detail = identifier 
      ? `${resource} with identifier '${identifier}' not found`
      : `${resource} not found`;
      
    return this.domainError(
      '/errors/not-found',
      'Resource Not Found',
      404,
      detail,
      `${resource.toUpperCase()}_NOT_FOUND`
    );
  }

  // Rate limit error template
  rateLimitError(
    retryAfter: number,
    limit: number = 100,
    window: string = '15 minutes'
  ): ErrorResponse {
    const response = this.domainError(
      '/errors/rate-limit',
      'Rate Limit Exceeded',
      429,
      `Too many requests. Rate limit: ${limit} requests per ${window}`,
      'RATE_LIMIT_EXCEEDED',
      '/docs/rate-limiting'
    );

    // Add rate limit metadata
    response.meta.rateLimit = {
      remaining: 0,
      limit,
      resetTime: new Date(Date.now() + retryAfter * 1000).toISOString(),
      retryAfter
    };

    return response;
  }

  // Add rate limiting info to any response
  withRateLimit(
    response: SuccessResponse | ErrorResponse,
    remaining: number,
    limit: number,
    resetTime: Date
  ): typeof response {
    response.meta.rateLimit = {
      remaining,
      limit,
      resetTime: resetTime.toISOString()
    };
    return response;
  }

  // Add caching info to success responses
  withCaching(
    response: SuccessResponse,
    etag: string,
    lastModified?: Date,
    maxAge?: number
  ): SuccessResponse {
    response.meta.resource = {
      ...response.meta.resource,
      etag,
      ...(lastModified && { 
        lastModified: lastModified.toISOString() 
      })
    };

    if (response.meta.execution) {
      response.meta.execution.cached = true;
    }

    return response;
  }

  // Private helpers
  private buildBaseMeta(): ResponseMetadata {
    return {
      timestamp: this.timestamp,
      requestId: this.requestId,
      version: this.version,
      execution: {
        duration: Date.now() - this.startTime,
        cached: false
      }
    };
  }

  private createFieldErrorsMap(violations: ValidationViolation[]): Record<string, string[]> {
    return violations.reduce((acc, violation) => {
      if (!acc[violation.field]) {
        acc[violation.field] = [];
      }
      acc[violation.field].push(violation.message);
      return acc;
    }, {} as Record<string, string[]>);
  }
}
```

## 🔧 Express.js Integration Templates

### Complete Middleware Stack

```typescript
// src/middleware/api-middleware.ts
import { Request, Response, NextFunction } from 'express';
import { randomUUID } from 'crypto';
import { ZodError } from 'zod';
import { ApiResponseBuilder } from '../utils/api-response-builder';

// Extend Express types
declare global {
  namespace Express {
    interface Request {
      requestId: string;
      startTime: number;
    }
    interface Response {
      apiResponse: ApiResponseBuilder;
    }
  }
}

// Request ID and timing middleware
export const requestTrackingMiddleware = (
  req: Request,
  res: Response,
  next: NextFunction
): void => {
  req.requestId = (req.headers['x-request-id'] as string) || randomUUID();
  req.startTime = Date.now();
  
  // Set response headers
  res.setHeader('X-Request-ID', req.requestId);
  res.setHeader('X-API-Version', process.env.API_VERSION || '1.0');
  
  next();
};

// Response builder middleware
export const responseBuilderMiddleware = (
  req: Request,
  res: Response,
  next: NextFunction
): void => {
  res.apiResponse = new ApiResponseBuilder(
    req.requestId, 
    req.startTime,
    process.env.API_VERSION || '1.0'
  );
  next();
};

// Global error handler
export const globalErrorHandler = (
  error: Error,
  req: Request,
  res: Response,
  next: NextFunction
): void => {
  const { apiResponse } = res;

  // Handle Zod validation errors
  if (error instanceof ZodError) {
    const violations = error.issues.map(issue => ({
      field: issue.path.join('.'),
      code: issue.code,
      message: issue.message,
      ...(issue.received && { value: issue.received }),
      ...(issue.expected && { expected: issue.expected }),
      severity: 'error' as const
    }));

    const response = apiResponse.validationError(violations);
    res.status(400).json(response);
    return;
  }

  // Handle custom domain errors
  if (error.name === 'DomainError') {
    const domainError = error as any;
    const response = apiResponse.domainError(
      domainError.type || '/errors/domain',
      domainError.title || 'Domain Error',
      domainError.statusCode || 400,
      domainError.message,
      domainError.code
    );
    res.status(domainError.statusCode || 400).json(response);
    return;
  }

  // Handle generic errors
  const response = apiResponse.domainError(
    '/errors/internal-server-error',
    'Internal Server Error',
    500,
    process.env.NODE_ENV === 'production' 
      ? 'An unexpected error occurred'
      : error.message,
    'INTERNAL_SERVER_ERROR'
  );

  // Log error in production
  if (process.env.NODE_ENV === 'production') {
    console.error('Unhandled error:', {
      requestId: req.requestId,
      error: error.message,
      stack: error.stack,
      url: req.originalUrl,
      method: req.method
    });
  }

  res.status(500).json(response);
};

// Rate limiting middleware
export const rateLimitMiddleware = (
  windowMs: number = 15 * 60 * 1000, // 15 minutes
  maxRequests: number = 100
) => {
  const requests = new Map<string, { count: number; resetTime: number }>();

  return (req: Request, res: Response, next: NextFunction): void => {
    const clientId = req.ip || 'unknown';
    const now = Date.now();
    const windowStart = now - windowMs;
    
    // Clean old entries
    for (const [key, value] of requests.entries()) {
      if (value.resetTime < windowStart) {
        requests.delete(key);
      }
    }

    // Get or create client data
    let clientData = requests.get(clientId);
    if (!clientData || clientData.resetTime < windowStart) {
      clientData = { count: 0, resetTime: now + windowMs };
      requests.set(clientId, clientData);
    }

    clientData.count++;

    // Set rate limit headers
    const remaining = Math.max(0, maxRequests - clientData.count);
    const resetTime = new Date(clientData.resetTime);
    
    res.setHeader('X-RateLimit-Limit', maxRequests);
    res.setHeader('X-RateLimit-Remaining', remaining);
    res.setHeader('X-RateLimit-Reset', Math.ceil(clientData.resetTime / 1000));

    // Check if rate limit exceeded
    if (clientData.count > maxRequests) {
      const retryAfter = Math.ceil((clientData.resetTime - now) / 1000);
      const response = res.apiResponse.rateLimitError(retryAfter, maxRequests);
      res.status(429).json(response);
      return;
    }

    next();
  };
};
```

### Controller Templates

```typescript
// src/controllers/base.controller.ts
import { Request, Response, NextFunction } from 'express';
import { z } from 'zod';
import { ApiResponseBuilder } from '../utils/api-response-builder';

export abstract class BaseController {
  // Helper method to get response builder
  protected getResponseBuilder(res: Response): ApiResponseBuilder {
    return res.apiResponse;
  }

  // Validation helper
  protected validate<T>(schema: z.ZodSchema<T>, data: unknown): T {
    return schema.parse(data);
  }

  // Pagination helper
  protected getPaginationParams(req: Request): {
    page: number;
    limit: number;
    offset: number;
  } {
    const page = Math.max(1, parseInt(req.query.page as string) || 1);
    const limit = Math.min(100, Math.max(1, parseInt(req.query.limit as string) || 20));
    const offset = (page - 1) * limit;
    
    return { page, limit, offset };
  }

  // Base URL helper for pagination
  protected getBaseUrl(req: Request): string {
    const protocol = req.secure ? 'https' : 'http';
    const host = req.get('host');
    return `${protocol}://${host}${req.baseUrl}${req.path}`;
  }

  // Async handler wrapper
  protected asyncHandler = (
    fn: (req: Request, res: Response, next: NextFunction) => Promise<void>
  ) => {
    return (req: Request, res: Response, next: NextFunction): void => {
      Promise.resolve(fn(req, res, next)).catch(next);
    };
  };
}
```

```typescript
// src/controllers/todo.controller.ts
import { Request, Response, NextFunction } from 'express';
import { z } from 'zod';
import { BaseController } from './base.controller';

// Validation schemas
const CreateTodoSchema = z.object({
  title: z.string().min(1, 'Title is required').max(200, 'Title too long'),
  description: z.string().optional(),
  priority: z.enum(['low', 'medium', 'high']).default('medium'),
  dueDate: z.string().datetime().optional(),
  tags: z.array(z.string()).optional()
});

const UpdateTodoSchema = CreateTodoSchema.partial();

const TodoQuerySchema = z.object({
  page: z.string().optional(),
  limit: z.string().optional(),
  status: z.enum(['pending', 'completed', 'all']).default('all'),
  priority: z.enum(['low', 'medium', 'high']).optional(),
  search: z.string().optional(),
  sortBy: z.enum(['createdAt', 'updatedAt', 'priority', 'dueDate']).default('createdAt'),
  sortOrder: z.enum(['asc', 'desc']).default('desc')
});

export class TodoController extends BaseController {
  // GET /api/todos - List todos with filtering and pagination
  public listTodos = this.asyncHandler(async (
    req: Request, 
    res: Response, 
    next: NextFunction
  ): Promise<void> => {
    const builder = this.getResponseBuilder(res);
    const { page, limit } = this.getPaginationParams(req);
    
    // Validate query parameters
    const query = this.validate(TodoQuerySchema, req.query);
    
    // Your business logic
    const { todos, total } = await todoService.getTodos({
      page,
      limit,
      status: query.status,
      priority: query.priority,
      search: query.search,
      sortBy: query.sortBy,
      sortOrder: query.sortOrder
    });

    const baseUrl = this.getBaseUrl(req);
    const response = builder.collection(todos, total, page, limit, baseUrl, {
      filtered: !!(query.search || query.priority || query.status !== 'all'),
      sortBy: query.sortBy,
      sortOrder: query.sortOrder
    });

    res.status(200).json(response);
  });

  // GET /api/todos/:id - Get single todo
  public getTodo = this.asyncHandler(async (
    req: Request,
    res: Response,
    next: NextFunction
  ): Promise<void> => {
    const builder = this.getResponseBuilder(res);
    const { id } = req.params;

    const todo = await todoService.getTodoById(id);
    
    if (!todo) {
      const response = builder.notFoundError('Todo', id);
      res.status(404).json(response);
      return;
    }

    const response = builder.success(todo, undefined, {
      type: 'todo',
      etag: `W/"${todo.updatedAt}"`,
      lastModified: todo.updatedAt
    });

    res.status(200).json(response);
  });

  // POST /api/todos - Create todo
  public createTodo = this.asyncHandler(async (
    req: Request,
    res: Response,
    next: NextFunction
  ): Promise<void> => {
    const builder = this.getResponseBuilder(res);
    
    const validatedData = this.validate(CreateTodoSchema, req.body);
    const todo = await todoService.createTodo(validatedData);
    
    const response = builder.success(todo, 'Todo created successfully', {
      type: 'todo',
      version: '1.0'
    });

    res.status(201).json(response);
  });

  // PUT /api/todos/:id - Update todo
  public updateTodo = this.asyncHandler(async (
    req: Request,
    res: Response,
    next: NextFunction
  ): Promise<void> => {
    const builder = this.getResponseBuilder(res);
    const { id } = req.params;
    
    const validatedData = this.validate(UpdateTodoSchema, req.body);
    const todo = await todoService.updateTodo(id, validatedData);
    
    if (!todo) {
      const response = builder.notFoundError('Todo', id);
      res.status(404).json(response);
      return;
    }

    const response = builder.success(todo, 'Todo updated successfully', {
      type: 'todo',
      etag: `W/"${todo.updatedAt}"`,
      lastModified: todo.updatedAt
    });

    res.status(200).json(response);
  });

  // DELETE /api/todos/:id - Delete todo
  public deleteTodo = this.asyncHandler(async (
    req: Request,
    res: Response,
    next: NextFunction
  ): Promise<void> => {
    const builder = this.getResponseBuilder(res);
    const { id } = req.params;

    const deleted = await todoService.deleteTodo(id);
    
    if (!deleted) {
      const response = builder.notFoundError('Todo', id);
      res.status(404).json(response);
      return;
    }

    const response = builder.success(undefined, 'Todo deleted successfully');
    res.status(200).json(response);
  });
}
```

### Authentication Controller Template

```typescript
// src/controllers/auth.controller.ts
import { Request, Response, NextFunction } from 'express';
import { z } from 'zod';
import { BaseController } from './base.controller';

const LoginSchema = z.object({
  email: z.string().email('Please provide a valid email address'),
  password: z.string().min(1, 'Password is required')
});

const RegisterSchema = z.object({
  firstName: z.string().min(1, 'First name is required').max(50),
  lastName: z.string().min(1, 'Last name is required').max(50),
  email: z.string().email('Please provide a valid email address'),
  password: z.string()
    .min(8, 'Password must be at least 8 characters long')
    .regex(
      /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/,
      'Password must contain at least one uppercase letter, one lowercase letter, and one number'
    )
});

export class AuthController extends BaseController {
  // POST /api/auth/login
  public login = this.asyncHandler(async (
    req: Request,
    res: Response,
    next: NextFunction
  ): Promise<void> => {
    const builder = this.getResponseBuilder(res);
    
    const { email, password } = this.validate(LoginSchema, req.body);
    
    const result = await authService.login(email, password);
    
    if (!result) {
      const response = builder.authenticationError();
      res.status(401).json(response);
      return;
    }

    const response = builder.success(result, 'Login successful');
    res.status(200).json(response);
  });

  // POST /api/auth/register
  public register = this.asyncHandler(async (
    req: Request,
    res: Response,
    next: NextFunction
  ): Promise<void> => {
    const builder = this.getResponseBuilder(res);
    
    const userData = this.validate(RegisterSchema, req.body);
    
    // Check if email exists
    const existingUser = await userService.findByEmail(userData.email);
    if (existingUser) {
      const response = builder.conflictError(
        'Email address already registered',
        'REG_EMAIL_EXISTS',
        '/docs/registration'
      );
      res.status(409).json(response);
      return;
    }

    const user = await userService.createUser(userData);
    
    const response = builder.success(user, 'User registered successfully');
    res.status(201).json(response);
  });

  // POST /api/auth/refresh
  public refreshToken = this.asyncHandler(async (
    req: Request,
    res: Response,
    next: NextFunction
  ): Promise<void> => {
    const builder = this.getResponseBuilder(res);
    const { refreshToken } = req.body;
    
    if (!refreshToken) {
      const response = builder.domainError(
        '/errors/authentication/missing-refresh-token',
        'Authentication Failed',
        401,
        'Refresh token is required',
        'AUTH_REFRESH_TOKEN_REQUIRED'
      );
      res.status(401).json(response);
      return;
    }

    const result = await authService.refreshToken(refreshToken);
    
    if (!result) {
      const response = builder.domainError(
        '/errors/authentication/invalid-refresh-token',
        'Authentication Failed',
        401,
        'Invalid or expired refresh token',
        'AUTH_INVALID_REFRESH_TOKEN'
      );
      res.status(401).json(response);
      return;
    }

    const response = builder.success(result, 'Token refreshed successfully');
    res.status(200).json(response);
  });
}
```

## 🧪 Testing Templates

### Response Testing Utilities

```typescript
// src/test/response-test-utils.ts
import { Response } from 'supertest';
import { 
  SuccessResponse, 
  ErrorResponse, 
  ResponseMetadata,
  PaginationMeta 
} from '../utils/api-response-builder';

export class ResponseTestUtils {
  // Assert basic response structure
  static assertResponseStructure(response: Response): void {
    expect(response.body).toHaveProperty('success');
    expect(response.body).toHaveProperty('meta');
    expect(response.body.meta).toHaveProperty('timestamp');
    expect(response.body.meta).toHaveProperty('requestId');
    expect(response.body.meta).toHaveProperty('version');
    expect(response.body.meta).toHaveProperty('execution');
  }

  // Assert success response
  static assertSuccessResponse<T>(
    response: Response,
    expectedStatus: number = 200
  ): SuccessResponse<T> {
    expect(response.status).toBe(expectedStatus);
    this.assertResponseStructure(response);
    expect(response.body).toHaveProperty('success', true);
    
    return response.body as SuccessResponse<T>;
  }

  // Assert error response
  static assertErrorResponse(
    response: Response,
    expectedStatus: number,
    expectedType?: string
  ): ErrorResponse {
    expect(response.status).toBe(expectedStatus);
    this.assertResponseStructure(response);
    expect(response.body).toHaveProperty('success', false);
    expect(response.body).toHaveProperty('error');
    expect(response.body.error).toHaveProperty('type');
    expect(response.body.error).toHaveProperty('title');
    expect(response.body.error).toHaveProperty('status', expectedStatus);
    
    if (expectedType) {
      expect(response.body.error.type).toBe(expectedType);
    }
    
    return response.body as ErrorResponse;
  }

  // Assert validation error
  static assertValidationError(response: Response): ErrorResponse {
    const errorResponse = this.assertErrorResponse(
      response, 
      400, 
      '/errors/validation-failed'
    );
    
    expect(errorResponse.error).toHaveProperty('violations');
    expect(errorResponse.error).toHaveProperty('fieldErrors');
    expect(errorResponse.error).toHaveProperty('code', 'VALIDATION_ERROR');
    
    return errorResponse;
  }

  // Assert paginated response
  static assertPaginatedResponse<T>(
    response: Response,
    expectedTotal?: number
  ): SuccessResponse<T[]> {
    const successResponse = this.assertSuccessResponse<T[]>(response);
    
    expect(successResponse.meta).toHaveProperty('pagination');
    expect(successResponse.meta).toHaveProperty('collection');
    
    const pagination = successResponse.meta.pagination!;
    expect(pagination).toHaveProperty('page');
    expect(pagination).toHaveProperty('limit');
    expect(pagination).toHaveProperty('total');
    expect(pagination).toHaveProperty('pages');
    expect(pagination).toHaveProperty('hasNext');
    expect(pagination).toHaveProperty('hasPrev');
    expect(pagination).toHaveProperty('links');
    
    if (expectedTotal !== undefined) {
      expect(pagination.total).toBe(expectedTotal);
    }
    
    return successResponse;
  }

  // Assert rate limit headers
  static assertRateLimitHeaders(response: Response): void {
    expect(response.headers).toHaveProperty('x-ratelimit-limit');
    expect(response.headers).toHaveProperty('x-ratelimit-remaining');
    expect(response.headers).toHaveProperty('x-ratelimit-reset');
  }

  // Assert request tracking headers
  static assertRequestHeaders(response: Response): void {
    expect(response.headers).toHaveProperty('x-request-id');
    expect(response.headers).toHaveProperty('x-api-version');
  }

  // Assert backward compatibility
  static assertBackwardCompatibility(response: Response): void {
    const body = response.body;
    
    if (!body.success && body.error && typeof body.error === 'object') {
      // RFC 7807 error should maintain backward compatible fields
      if (body.error.violations) {
        expect(body.error).toHaveProperty('fieldErrors');
        expect(body.error).toHaveProperty('code');
      }
    }
  }
}
```

### Complete Test Examples

```typescript
// src/test/todo.controller.test.ts
import request from 'supertest';
import app from '../app';
import { ResponseTestUtils } from './response-test-utils';

describe('Todo Controller', () => {
  describe('GET /api/todos', () => {
    it('should return paginated todos with proper structure', async () => {
      const response = await request(app)
        .get('/api/todos')
        .expect(200);

      const successResponse = ResponseTestUtils.assertPaginatedResponse(response);
      
      expect(Array.isArray(successResponse.data)).toBe(true);
      expect(successResponse.meta.collection.count).toBe(successResponse.data.length);
      
      ResponseTestUtils.assertRequestHeaders(response);
    });

    it('should handle pagination parameters correctly', async () => {
      const response = await request(app)
        .get('/api/todos?page=2&limit=5')
        .expect(200);

      const successResponse = ResponseTestUtils.assertPaginatedResponse(response);
      const pagination = successResponse.meta.pagination!;
      
      expect(pagination.page).toBe(2);
      expect(pagination.limit).toBe(5);
      expect(pagination.links.first).toContain('page=1');
      expect(pagination.links.prev).toContain('page=1');
    });

    it('should handle filtering and sorting', async () => {
      const response = await request(app)
        .get('/api/todos?status=completed&sortBy=priority&sortOrder=desc')
        .expect(200);

      const successResponse = ResponseTestUtils.assertPaginatedResponse(response);
      
      expect(successResponse.meta.collection.filtered).toBe(true);
      expect(successResponse.meta.collection.sortBy).toBe('priority');
      expect(successResponse.meta.collection.sortOrder).toBe('desc');
    });
  });

  describe('POST /api/todos', () => {
    it('should create todo with success response', async () => {
      const todoData = {
        title: 'Test todo',
        description: 'Test description',
        priority: 'high',
        tags: ['work', 'urgent']
      };

      const response = await request(app)
        .post('/api/todos')
        .send(todoData)
        .expect(201);

      const successResponse = ResponseTestUtils.assertSuccessResponse(response, 201);
      
      expect(successResponse.data).toHaveProperty('id');
      expect(successResponse.data.title).toBe(todoData.title);
      expect(successResponse.message).toBe('Todo created successfully');
      expect(successResponse.meta.resource?.type).toBe('todo');
      
      ResponseTestUtils.assertBackwardCompatibility(response);
    });

    it('should return validation error for invalid data', async () => {
      const response = await request(app)
        .post('/api/todos')
        .send({
          title: '', // Invalid: empty title
          priority: 'invalid', // Invalid: not in enum
          dueDate: 'not-a-date' // Invalid: invalid date format
        })
        .expect(400);

      const errorResponse = ResponseTestUtils.assertValidationError(response);
      
      expect(errorResponse.error.violations).toHaveLength(3);
      expect(errorResponse.error.fieldErrors).toHaveProperty('title');
      expect(errorResponse.error.fieldErrors).toHaveProperty('priority');
      expect(errorResponse.error.fieldErrors).toHaveProperty('dueDate');
      
      ResponseTestUtils.assertBackwardCompatibility(response);
    });
  });

  describe('Authentication endpoints', () => {
    it('should return authentication error for invalid credentials', async () => {
      const response = await request(app)
        .post('/api/auth/login')
        .send({
          email: 'invalid@example.com',
          password: 'wrongpassword'
        })
        .expect(401);

      const errorResponse = ResponseTestUtils.assertErrorResponse(
        response,
        401,
        '/errors/authentication/invalid-credentials'
      );
      
      expect(errorResponse.error.code).toBe('AUTH_INVALID_CREDENTIALS');
      expect(errorResponse.error.help).toBe('/docs/authentication');
      
      ResponseTestUtils.assertBackwardCompatibility(response);
    });

    it('should return conflict error for existing email', async () => {
      const response = await request(app)
        .post('/api/auth/register')
        .send({
          firstName: 'John',
          lastName: 'Doe',
          email: 'existing@example.com', // Already exists
          password: 'ValidPassword123'
        })
        .expect(409);

      const errorResponse = ResponseTestUtils.assertErrorResponse(
        response,
        409,
        '/errors/conflict'
      );
      
      expect(errorResponse.error.code).toBe('REG_EMAIL_EXISTS');
      expect(errorResponse.error.detail).toBe('Email address already registered');
      
      ResponseTestUtils.assertBackwardCompatibility(response);
    });
  });

  describe('Rate limiting', () => {
    it('should return rate limit error when exceeded', async () => {
      // Make multiple requests to exceed rate limit
      const promises = Array(110).fill(null).map(() => 
        request(app).get('/api/todos')
      );
      
      const responses = await Promise.allSettled(promises);
      const rateLimitResponse = responses.find(
        result => result.status === 'fulfilled' && result.value.status === 429
      );
      
      expect(rateLimitResponse).toBeDefined();
      
      if (rateLimitResponse && rateLimitResponse.status === 'fulfilled') {
        const errorResponse = ResponseTestUtils.assertErrorResponse(
          rateLimitResponse.value,
          429,
          '/errors/rate-limit'
        );
        
        expect(errorResponse.error.code).toBe('RATE_LIMIT_EXCEEDED');
        expect(errorResponse.meta.rateLimit).toBeDefined();
        expect(errorResponse.meta.rateLimit!.remaining).toBe(0);
        
        ResponseTestUtils.assertRateLimitHeaders(rateLimitResponse.value);
      }
    });
  });
});
```

## 🚀 Production Deployment Template

### Environment Configuration

```bash
# .env.production
NODE_ENV=production
API_VERSION=1.0
PORT=3000

# Response Configuration
ENABLE_ENHANCED_RESPONSES=true
USE_RFC7807_ERRORS=true
ENABLE_PAGINATION=true
MAX_RESPONSE_SIZE=10485760  # 10MB

# Rate Limiting
RATE_LIMIT_WINDOW_MS=900000  # 15 minutes
RATE_LIMIT_MAX_REQUESTS=100
RATE_LIMIT_SKIP_SUCCESSFUL_REQUESTS=false

# Monitoring
ENABLE_RESPONSE_MONITORING=true
ENABLE_PERFORMANCE_TRACKING=true
LOG_LEVEL=info

# Security
HELMET_ENABLED=true
CORS_ORIGIN=*
REQUEST_TIMEOUT=30000
```

### Docker Configuration

```dockerfile
# Production Dockerfile
FROM node:18-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./
RUN npm ci --only=production

# Copy source code
COPY . .

# Build application
RUN npm run build

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1

# Start application
CMD ["npm", "start"]
```

---

### Navigation
- **Previous**: [Migration Strategy](./migration-strategy.md)
- **Next**: [Research Overview](./README.md)

---

*These templates provide production-ready, copy-paste solutions for implementing enhanced HTTP API response formats. Each template maintains backward compatibility while adding industry-standard features and monitoring capabilities.*