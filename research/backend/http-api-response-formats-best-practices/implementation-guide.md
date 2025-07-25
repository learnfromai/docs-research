# Implementation Guide

## 🚀 Step-by-Step Implementation

This guide provides practical, production-ready implementation steps to enhance your current HTTP API response format with industry best practices while maintaining backward compatibility.

## 📋 Prerequisites

### Required Dependencies
```bash
npm install --save express zod
npm install --save-dev @types/express @types/node typescript
```

### Recommended Development Dependencies  
```bash
npm install --save-dev jest supertest nodemon ts-node
```

## 🏗️ Phase 1: Foundation Setup (1-2 Days)

### Step 1: Create Core Types

Create `src/types/api-response.types.ts`:

```typescript
// Core response metadata
export interface ResponseMetadata {
  timestamp: string;
  requestId: string;
  version: string;
  execution?: {
    duration: number;
    cached: boolean;
  };
  pagination?: PaginationMeta;
  rateLimit?: RateLimitMeta;
}

// Pagination metadata
export interface PaginationMeta {
  page: number;
  limit: number;
  total: number;
  pages: number;
  hasNext: boolean;
  hasPrev: boolean;
  links: {
    first: string;
    prev?: string;
    next?: string;
    last: string;
  };
}

// Rate limiting metadata
export interface RateLimitMeta {
  remaining: number;
  limit: number;
  resetTime: string;
}

// Base response types
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

// RFC 7807 Problem Details
export interface ProblemDetails {
  type: string;
  title: string;
  status: number;
  detail?: string;
  instance?: string;
  violations?: ValidationViolation[];
  code?: string; // Backward compatibility
  fieldErrors?: Record<string, string[]>; // Backward compatibility
  help?: string;
}

// Validation violation details
export interface ValidationViolation {
  field: string;
  code: string;
  message: string;
  value?: any;
  expected?: string;
  severity?: 'error' | 'warning';
}
```

### Step 2: Request ID Middleware

Create `src/middleware/request-id.middleware.ts`:

```typescript
import { Request, Response, NextFunction } from 'express';
import { randomUUID } from 'crypto';

// Extend Express Request interface
declare global {
  namespace Express {
    interface Request {
      requestId: string;
      startTime: number;
    }
  }
}

export const requestIdMiddleware = (
  req: Request,
  res: Response,
  next: NextFunction
): void => {
  // Generate or use existing request ID
  req.requestId = (req.headers['x-request-id'] as string) || randomUUID();
  req.startTime = Date.now();
  
  // Set response headers
  res.setHeader('X-Request-ID', req.requestId);
  res.setHeader('X-API-Version', '1.0');
  
  next();
};
```

### Step 3: Response Builder Class

Create `src/utils/response-builder.ts`:

```typescript
import { ResponseMetadata, SuccessResponse, ErrorResponse, ProblemDetails } from '../types/api-response.types';

export class ApiResponseBuilder {
  private requestId: string;
  private timestamp: string;
  private startTime: number;

  constructor(requestId: string, startTime: number = Date.now()) {
    this.requestId = requestId;
    this.timestamp = new Date().toISOString();
    this.startTime = startTime;
  }

  // Success response builder
  success<T>(data?: T, message?: string): SuccessResponse<T> {
    return {
      success: true,
      ...(data !== undefined && { data }),
      ...(message && { message }),
      meta: this.buildBasicMeta()
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
      meta: this.buildBasicMeta()
    };
  }

  // Collection response builder
  collection<T>(
    data: T[], 
    total: number, 
    page: number = 1, 
    limit: number = 20,
    baseUrl: string = ''
  ): SuccessResponse<T[]> {
    const pages = Math.ceil(total / limit);
    const hasNext = page < pages;
    const hasPrev = page > 1;

    return {
      success: true,
      data,
      meta: {
        ...this.buildBasicMeta(),
        collection: {
          total,
          count: data.length,
          hasMore: hasNext
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
            ...(hasPrev && { prev: `${baseUrl}?page=${page - 1}&limit=${limit}` }),
            ...(hasNext && { next: `${baseUrl}?page=${page + 1}&limit=${limit}` }),
            last: `${baseUrl}?page=${pages}&limit=${limit}`
          }
        }
      }
    };
  }

  // Private helper to build basic metadata
  private buildBasicMeta(): ResponseMetadata {
    return {
      timestamp: this.timestamp,
      requestId: this.requestId,
      version: '1.0',
      execution: {
        duration: Date.now() - this.startTime,
        cached: false // Can be enhanced based on cache headers
      }
    };
  }
}
```

### Step 4: Response Builder Middleware

Create `src/middleware/response-builder.middleware.ts`:

```typescript
import { Request, Response, NextFunction } from 'express';
import { ApiResponseBuilder } from '../utils/response-builder';

export const responseBuilderMiddleware = (
  req: Request,
  res: Response,
  next: NextFunction
): void => {
  // Attach response builder to response locals
  res.locals.responseBuilder = new ApiResponseBuilder(req.requestId, req.startTime);
  next();
};
```

## 🔧 Phase 2: Enhanced Error Handling (1-2 Weeks)

### Step 5: Error Type Classification

Create `src/constants/error-types.ts`:

```typescript
export const ErrorTypes = {
  VALIDATION: '/errors/validation-failed',
  AUTHENTICATION: '/errors/authentication',
  AUTHORIZATION: '/errors/authorization',
  NOT_FOUND: '/errors/not-found',
  CONFLICT: '/errors/conflict',
  RATE_LIMIT: '/errors/rate-limit',
  INTERNAL: '/errors/internal-server-error',
  MAINTENANCE: '/errors/maintenance'
} as const;

export const ErrorTitles = {
  [ErrorTypes.VALIDATION]: 'Validation Failed',
  [ErrorTypes.AUTHENTICATION]: 'Authentication Failed',
  [ErrorTypes.AUTHORIZATION]: 'Unauthorized',
  [ErrorTypes.NOT_FOUND]: 'Resource Not Found',
  [ErrorTypes.CONFLICT]: 'Resource Conflict',
  [ErrorTypes.RATE_LIMIT]: 'Rate Limit Exceeded',
  [ErrorTypes.INTERNAL]: 'Internal Server Error',
  [ErrorTypes.MAINTENANCE]: 'Service Unavailable'
} as const;

// Map your current error codes to RFC 7807 types
export const CodeToTypeMapping = {
  'VALIDATION_ERROR': ErrorTypes.VALIDATION,
  'AUTH_INVALID_CREDENTIALS': ErrorTypes.AUTHENTICATION,
  'REG_EMAIL_EXISTS': ErrorTypes.CONFLICT,
  // Add more mappings as needed
} as const;
```

### Step 6: Enhanced Validation Error Handler

Create `src/utils/validation-error-handler.ts`:

```typescript
import { ZodError, ZodIssue } from 'zod';
import { ValidationViolation, ProblemDetails } from '../types/api-response.types';
import { ErrorTypes, ErrorTitles } from '../constants/error-types';

export class ValidationErrorHandler {
  static fromZodError(zodError: ZodError, requestId: string): ProblemDetails {
    const violations = this.mapZodIssues(zodError.issues);
    const fieldErrors = this.createFieldErrorsMap(violations);

    return {
      type: ErrorTypes.VALIDATION,
      title: ErrorTitles[ErrorTypes.VALIDATION],
      status: 400,
      detail: `${violations.length} field(s) failed validation`,
      instance: requestId,
      violations,
      fieldErrors, // Backward compatibility
      code: 'VALIDATION_ERROR' // Backward compatibility
    };
  }

  private static mapZodIssues(issues: ZodIssue[]): ValidationViolation[] {
    return issues.map(issue => ({
      field: issue.path.join('.'),
      code: issue.code,
      message: issue.message,
      ...(issue.received && { value: issue.received }),
      ...(issue.expected && { expected: issue.expected }),
      severity: 'error' as const
    }));
  }

  private static createFieldErrorsMap(violations: ValidationViolation[]): Record<string, string[]> {
    return violations.reduce((acc, violation) => {
      if (!acc[violation.field]) {
        acc[violation.field] = [];
      }
      acc[violation.field].push(violation.message);
      return acc;
    }, {} as Record<string, string[]>);
  }

  // Remove duplicate messages for the same field
  static deduplicateFieldErrors(fieldErrors: Record<string, string[]>): Record<string, string[]> {
    const result: Record<string, string[]> = {};
    
    for (const [field, messages] of Object.entries(fieldErrors)) {
      result[field] = [...new Set(messages)]; // Remove duplicates
    }
    
    return result;
  }
}
```

### Step 7: Domain Error Classes

Create `src/errors/domain-errors.ts`:

```typescript
import { ProblemDetails } from '../types/api-response.types';
import { ErrorTypes, ErrorTitles, CodeToTypeMapping } from '../constants/error-types';

export class DomainError extends Error {
  public readonly code: string;
  public readonly statusCode: number;
  public readonly type: string;
  public readonly title: string;

  constructor(
    message: string,
    code: string,
    statusCode: number = 400,
    type?: string
  ) {
    super(message);
    this.name = 'DomainError';
    this.code = code;
    this.statusCode = statusCode;
    this.type = type || CodeToTypeMapping[code as keyof typeof CodeToTypeMapping] || ErrorTypes.INTERNAL;
    this.title = ErrorTitles[this.type as keyof typeof ErrorTitles] || 'Error';
  }

  toProblemDetails(requestId: string): ProblemDetails {
    return {
      type: this.type,
      title: this.title,
      status: this.statusCode,
      detail: this.message,
      instance: requestId,
      code: this.code // Backward compatibility
    };
  }
}

// Specific error classes
export class AuthenticationError extends DomainError {
  constructor(message: string = 'Invalid email/username or password') {
    super(message, 'AUTH_INVALID_CREDENTIALS', 401, ErrorTypes.AUTHENTICATION);
  }
}

export class ConflictError extends DomainError {
  constructor(message: string, code: string) {
    super(message, code, 409, ErrorTypes.CONFLICT);
  }
}

export class EmailExistsError extends ConflictError {
  constructor() {
    super('Email address already registered', 'REG_EMAIL_EXISTS');
  }
}
```

### Step 8: Global Error Handler Middleware

Create `src/middleware/error-handler.middleware.ts`:

```typescript
import { Request, Response, NextFunction } from 'express';
import { ZodError } from 'zod';
import { ApiResponseBuilder } from '../utils/response-builder';
import { DomainError } from '../errors/domain-errors';
import { ValidationErrorHandler } from '../utils/validation-error-handler';
import { ErrorTypes, ErrorTitles } from '../constants/error-types';

export const errorHandlerMiddleware = (
  error: Error,
  req: Request,
  res: Response,
  next: NextFunction
): void => {
  const builder = res.locals.responseBuilder as ApiResponseBuilder;

  // Handle Zod validation errors
  if (error instanceof ZodError) {
    const problemDetails = ValidationErrorHandler.fromZodError(error, req.requestId);
    const response = builder.error(problemDetails);
    res.status(400).json(response);
    return;
  }

  // Handle domain errors
  if (error instanceof DomainError) {
    const problemDetails = error.toProblemDetails(req.requestId);
    const response = builder.error(problemDetails);
    res.status(error.statusCode).json(response);
    return;
  }

  // Handle generic errors
  const problemDetails = {
    type: ErrorTypes.INTERNAL,
    title: ErrorTitles[ErrorTypes.INTERNAL],
    status: 500,
    detail: process.env.NODE_ENV === 'production' 
      ? 'An unexpected error occurred' 
      : error.message,
    instance: req.requestId
  };

  const response = builder.error(problemDetails);
  res.status(500).json(response);
};
```

## 📝 Phase 3: Controller Implementation (1 Week)

### Step 9: Enhanced Controller Example

Create `src/controllers/todo.controller.ts`:

```typescript
import { Request, Response, NextFunction } from 'express';
import { z } from 'zod';
import { ApiResponseBuilder } from '../utils/response-builder';
import { AuthenticationError, EmailExistsError } from '../errors/domain-errors';

// Zod schemas for validation
const CreateTodoSchema = z.object({
  title: z.string().min(1, 'Title is required'),
  priority: z.enum(['low', 'medium', 'high']).default('medium'),
  completed: z.boolean().default(false)
});

const UpdateTodoSchema = CreateTodoSchema.partial();

export class TodoController {
  // GET /api/todos - List todos with pagination
  static async getTodos(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const builder = res.locals.responseBuilder as ApiResponseBuilder;
      const page = parseInt(req.query.page as string) || 1;
      const limit = parseInt(req.query.limit as string) || 20;

      // Your existing business logic
      const { todos, total } = await todoService.getTodos(page, limit);

      const response = builder.collection(todos, total, page, limit, '/api/todos');
      res.status(200).json(response);
    } catch (error) {
      next(error);
    }
  }

  // GET /api/todos/:id - Get single todo
  static async getTodo(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const builder = res.locals.responseBuilder as ApiResponseBuilder;
      const { id } = req.params;

      const todo = await todoService.getTodoById(id);
      
      if (!todo) {
        throw new DomainError('Todo not found', 'TODO_NOT_FOUND', 404);
      }

      const response = builder.success(todo);
      res.status(200).json(response);
    } catch (error) {
      next(error);
    }
  }

  // POST /api/todos - Create todo
  static async createTodo(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const builder = res.locals.responseBuilder as ApiResponseBuilder;
      
      // Zod validation (will throw ZodError if invalid)
      const validatedData = CreateTodoSchema.parse(req.body);

      const todo = await todoService.createTodo(validatedData);
      
      const response = builder.success(todo, 'Todo created successfully');
      res.status(201).json(response);
    } catch (error) {
      next(error); // Let error middleware handle ZodError
    }
  }

  // PUT /api/todos/:id - Update todo
  static async updateTodo(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const builder = res.locals.responseBuilder as ApiResponseBuilder;
      const { id } = req.params;
      
      const validatedData = UpdateTodoSchema.parse(req.body);
      const todo = await todoService.updateTodo(id, validatedData);
      
      if (!todo) {
        throw new DomainError('Todo not found', 'TODO_NOT_FOUND', 404);
      }

      const response = builder.success(todo, 'Todo updated successfully');
      res.status(200).json(response);
    } catch (error) {
      next(error);
    }
  }

  // DELETE /api/todos/:id - Delete todo
  static async deleteTodo(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const builder = res.locals.responseBuilder as ApiResponseBuilder;
      const { id } = req.params;

      const deleted = await todoService.deleteTodo(id);
      
      if (!deleted) {
        throw new DomainError('Todo not found', 'TODO_NOT_FOUND', 404);
      }

      const response = builder.success(undefined, 'Todo deleted successfully');
      res.status(200).json(response);
    } catch (error) {
      next(error);
    }
  }
}
```

### Step 10: Authentication Controller Example

Create `src/controllers/auth.controller.ts`:

```typescript
import { Request, Response, NextFunction } from 'express';
import { z } from 'zod';
import { ApiResponseBuilder } from '../utils/response-builder';
import { AuthenticationError, EmailExistsError } from '../errors/domain-errors';

// Validation schemas
const LoginSchema = z.object({
  email: z.string().email('Please provide a valid email address'),
  password: z.string().min(1, 'Password is required')
});

const RegisterSchema = z.object({
  firstName: z.string().min(1, 'First name is required'),
  lastName: z.string().min(1, 'Last name is required'),
  email: z.string().email('Please provide a valid email address'),
  password: z.string()
    .min(8, 'Password must be at least 8 characters long')
    .regex(
      /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/,
      'Password must contain at least one uppercase letter, one lowercase letter, and one number'
    )
});

export class AuthController {
  // POST /api/auth/login
  static async login(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const builder = res.locals.responseBuilder as ApiResponseBuilder;
      
      const { email, password } = LoginSchema.parse(req.body);
      
      const result = await authService.login(email, password);
      
      if (!result) {
        throw new AuthenticationError();
      }

      const response = builder.success(result, 'Login successful');
      res.status(200).json(response);
    } catch (error) {
      next(error);
    }
  }

  // POST /api/auth/register
  static async register(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const builder = res.locals.responseBuilder as ApiResponseBuilder;
      
      const userData = RegisterSchema.parse(req.body);
      
      // Check if email exists
      const existingUser = await userService.findByEmail(userData.email);
      if (existingUser) {
        throw new EmailExistsError();
      }

      const user = await userService.createUser(userData);
      
      const response = builder.success(user, 'User registered successfully');
      res.status(201).json(response);
    } catch (error) {
      next(error);
    }
  }
}
```

## 🔗 Phase 4: Express App Integration

### Step 11: Complete Express App Setup

Create `src/app.ts`:

```typescript
import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import { requestIdMiddleware } from './middleware/request-id.middleware';
import { responseBuilderMiddleware } from './middleware/response-builder.middleware';
import { errorHandlerMiddleware } from './middleware/error-handler.middleware';
import { todoRoutes } from './routes/todo.routes';
import { authRoutes } from './routes/auth.routes';

const app = express();

// Security middleware
app.use(helmet());
app.use(cors());

// Body parsing
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Core middleware
app.use(requestIdMiddleware);
app.use(responseBuilderMiddleware);

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/todos', todoRoutes);

// Health check endpoint
app.get('/health', (req, res) => {
  const builder = res.locals.responseBuilder;
  const response = builder.success({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime()
  });
  res.status(200).json(response);
});

// 404 handler
app.use('*', (req, res) => {
  const builder = res.locals.responseBuilder;
  const response = builder.error({
    type: '/errors/not-found',
    title: 'Not Found',
    status: 404,
    detail: `Cannot ${req.method} ${req.originalUrl}`,
    instance: req.requestId
  });
  res.status(404).json(response);
});

// Global error handler (must be last)
app.use(errorHandlerMiddleware);

export default app;
```

## 🧪 Testing Implementation

### Step 12: Response Testing Utilities

Create `src/test/response-test-utils.ts`:

```typescript
import { Response } from 'supertest';
import { SuccessResponse, ErrorResponse, ProblemDetails } from '../types/api-response.types';

export class ResponseTestUtils {
  static expectSuccessResponse<T>(response: Response): SuccessResponse<T> {
    expect(response.body).toHaveProperty('success', true);
    expect(response.body).toHaveProperty('meta');
    expect(response.body.meta).toHaveProperty('timestamp');
    expect(response.body.meta).toHaveProperty('requestId');
    expect(response.body.meta).toHaveProperty('version');
    return response.body as SuccessResponse<T>;
  }

  static expectErrorResponse(response: Response): ErrorResponse {
    expect(response.body).toHaveProperty('success', false);
    expect(response.body).toHaveProperty('error');
    expect(response.body).toHaveProperty('meta');
    expect(response.body.error).toHaveProperty('type');
    expect(response.body.error).toHaveProperty('title');
    expect(response.body.error).toHaveProperty('status');
    return response.body as ErrorResponse;
  }

  static expectValidationError(response: Response): ErrorResponse {
    const errorResponse = this.expectErrorResponse(response);
    expect(errorResponse.error.type).toBe('/errors/validation-failed');
    expect(errorResponse.error).toHaveProperty('violations');
    expect(errorResponse.error).toHaveProperty('fieldErrors');
    return errorResponse;
  }

  static expectPaginatedResponse<T>(response: Response): SuccessResponse<T[]> {
    const successResponse = this.expectSuccessResponse<T[]>(response);
    expect(successResponse.meta).toHaveProperty('pagination');
    expect(successResponse.meta).toHaveProperty('collection');
    return successResponse;
  }
}
```

### Step 13: Example Tests

Create `src/test/todo.controller.test.ts`:

```typescript
import request from 'supertest';
import app from '../app';
import { ResponseTestUtils } from './response-test-utils';

describe('Todo Controller', () => {
  describe('GET /api/todos', () => {
    it('should return paginated todos with metadata', async () => {
      const response = await request(app)
        .get('/api/todos')
        .expect(200);

      const successResponse = ResponseTestUtils.expectPaginatedResponse(response);
      expect(Array.isArray(successResponse.data)).toBe(true);
      expect(successResponse.meta.pagination).toBeDefined();
      expect(successResponse.meta.collection).toBeDefined();
    });
  });

  describe('POST /api/todos', () => {
    it('should create todo with success response', async () => {
      const todoData = {
        title: 'Test todo',
        priority: 'high'
      };

      const response = await request(app)
        .post('/api/todos')
        .send(todoData)
        .expect(201);

      const successResponse = ResponseTestUtils.expectSuccessResponse(response);
      expect(successResponse.data).toHaveProperty('id');
      expect(successResponse.message).toBe('Todo created successfully');
    });

    it('should return validation error for invalid data', async () => {
      const response = await request(app)
        .post('/api/todos')
        .send({}) // Empty body
        .expect(400);

      const errorResponse = ResponseTestUtils.expectValidationError(response);
      expect(errorResponse.error.violations).toHaveLength(1);
      expect(errorResponse.error.fieldErrors).toHaveProperty('title');
    });
  });
});
```

## 🚀 Deployment Checklist

### Environment Configuration
```bash
# .env.example
NODE_ENV=production
API_VERSION=1.0
LOG_LEVEL=info
REQUEST_TIMEOUT=30000
RATE_LIMIT_WINDOW=900000  # 15 minutes
RATE_LIMIT_MAX_REQUESTS=100
```

### Production Middleware
```typescript
// Add to production app setup
import rateLimit from 'express-rate-limit';
import compression from 'compression';

// Rate limiting
const limiter = rateLimit({
  windowMs: process.env.RATE_LIMIT_WINDOW || 15 * 60 * 1000,
  max: process.env.RATE_LIMIT_MAX_REQUESTS || 100,
  message: {
    success: false,
    error: {
      type: '/errors/rate-limit',
      title: 'Rate Limit Exceeded',
      status: 429,
      detail: 'Too many requests, please try again later'
    }
  }
});

app.use(limiter);
app.use(compression());
```

### Monitoring Integration
```typescript
// Add to response builder for production monitoring
private buildMeta(): ResponseMetadata {
  const meta = {
    timestamp: this.timestamp,
    requestId: this.requestId,
    version: process.env.API_VERSION || '1.0',
    execution: {
      duration: Date.now() - this.startTime,
      cached: false
    }
  };

  // Send metrics to monitoring service
  if (process.env.NODE_ENV === 'production') {
    monitoringService.trackApiResponse({
      requestId: this.requestId,
      duration: meta.execution.duration,
      timestamp: this.timestamp
    });
  }

  return meta;
}
```

---

### Navigation
- **Previous**: [Comparison Analysis](./comparison-analysis.md)
- **Next**: [Migration Strategy](./migration-strategy.md)

---

*This implementation guide provides production-ready code that enhances your current API response format while maintaining backward compatibility. Each phase can be implemented incrementally to minimize risk.*