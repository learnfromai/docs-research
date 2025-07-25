# Migration Strategy: REST API Response Structure

## 🎯 Overview

This document provides a comprehensive, step-by-step migration strategy for implementing standardized REST API response structures in the existing TodoController codebase. The strategy emphasizes minimal risk, backward compatibility, and progressive enhancement.

## 📋 Table of Contents

1. [Migration Approach](#migration-approach)
2. [Phase 1: Foundation Setup](#phase-1-foundation-setup)
3. [Phase 2: Core Response Structure](#phase-2-core-response-structure)
4. [Phase 3: Error Handling Enhancement](#phase-3-error-handling-enhancement)
5. [Phase 4: Advanced Features](#phase-4-advanced-features)
6. [Phase 5: Cleanup and Optimization](#phase-5-cleanup-and-optimization)
7. [Risk Mitigation](#risk-mitigation)
8. [Testing Strategy](#testing-strategy)
9. [Rollback Procedures](#rollback-procedures)
10. [Monitoring and Metrics](#monitoring-and-metrics)

## 🚀 Migration Approach

### Core Principles

1. **Zero Downtime**: No service interruption during migration
2. **Backward Compatibility**: Existing clients continue to work
3. **Progressive Enhancement**: Gradual improvement over time
4. **Feature Flags**: Safe deployment with instant rollback capability
5. **Comprehensive Testing**: Validate each step thoroughly
6. **Monitoring**: Track performance and error rates

### Migration Timeline

| Phase | Duration | Risk Level | Dependencies |
|-------|----------|------------|--------------|
| Phase 1 | 1-2 weeks | Low | None |
| Phase 2 | 2-3 weeks | Medium | Phase 1 |
| Phase 3 | 2-3 weeks | Medium | Phase 2 |
| Phase 4 | 3-4 weeks | Medium | Phase 3 |
| Phase 5 | 1-2 weeks | Low | Phase 4 |
| **Total** | **9-14 weeks** | **Managed** | **Sequential** |

## 📦 Phase 1: Foundation Setup

### Week 1: Project Setup and Planning

#### Day 1-2: Environment Preparation

```bash
# 1. Create feature branch
git checkout -b feature/standardized-api-responses
git push -u origin feature/standardized-api-responses

# 2. Install required dependencies
npm install --save uuid class-validator class-transformer
npm install --save-dev @types/uuid supertest
```

#### Day 3-5: Core Type Definitions

Create the foundational types that will support the new response structure:

```typescript
// src/types/api-response.ts
export interface ApiResponse<T = any> {
  success: boolean;
  data?: T;
  error?: ProblemDetails;
  meta?: ResponseMetadata;
}

export interface ProblemDetails {
  type: string;
  title: string;
  status: number;
  detail?: string;
  instance?: string;
  [key: string]: any;
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
  edit?: string;
  delete?: string;
  collection?: string;
}

export interface ValidationViolation {
  field: string;
  message: string;
  code: string;
  rejectedValue?: any;
}
```

#### Day 6-7: Feature Flag Infrastructure

```typescript
// src/config/feature-flags.ts
export interface FeatureFlags {
  standardizedResponses: boolean;
  rfc7807Errors: boolean;
  responseMetadata: boolean;
  hateoasLinks: boolean;
  paginationSupport: boolean;
}

export class FeatureFlagService {
  private flags: FeatureFlags;

  constructor() {
    this.flags = {
      standardizedResponses: process.env.FEATURE_STANDARDIZED_RESPONSES === 'true',
      rfc7807Errors: process.env.FEATURE_RFC7807_ERRORS === 'true',
      responseMetadata: process.env.FEATURE_RESPONSE_METADATA === 'true',
      hateoasLinks: process.env.FEATURE_HATEOAS_LINKS === 'true',
      paginationSupport: process.env.FEATURE_PAGINATION_SUPPORT === 'true'
    };
  }

  isEnabled(flag: keyof FeatureFlags): boolean {
    return this.flags[flag] || false;
  }

  setFlag(flag: keyof FeatureFlags, value: boolean): void {
    this.flags[flag] = value;
  }
}
```

### Week 2: Basic Utilities

#### Day 1-3: Response Builder Utility

```typescript
// src/utils/response-builder.ts
import { Request } from 'express';
import { injectable } from 'tsyringe';
import { v4 as uuidv4 } from 'uuid';
import { ApiResponse, ResponseMetadata } from '../types/api-response';
import { FeatureFlagService } from '../config/feature-flags';

@injectable()
export class ResponseBuilder {
  constructor(private featureFlags: FeatureFlagService) {}

  success<T>(options: {
    data: T;
    meta?: Partial<ResponseMetadata>;
    req: Request;
  }): ApiResponse<T> | T {
    // Return legacy format if feature flag is disabled
    if (!this.featureFlags.isEnabled('standardizedResponses')) {
      return options.data;
    }

    const response: ApiResponse<T> = {
      success: true,
      data: options.data
    };

    if (this.featureFlags.isEnabled('responseMetadata')) {
      response.meta = {
        timestamp: new Date().toISOString(),
        requestId: this.getRequestId(options.req),
        version: process.env.API_VERSION || '1.0.0',
        ...options.meta
      };
    }

    return response;
  }

  private getRequestId(req: Request): string {
    return req.headers['x-request-id'] as string || uuidv4();
  }
}
```

#### Day 4-5: Request ID Middleware

```typescript
// src/middleware/request-id.middleware.ts
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

#### Day 6-7: Integration and Testing

```typescript
// src/app.ts - Add middleware
import express from 'express';
import { requestIdMiddleware } from './middleware/request-id.middleware';

const app = express();

// Add request ID middleware early in the stack
app.use(requestIdMiddleware);

// ... rest of middleware and routes

export { app };
```

**Deliverables:**
- ✅ Core type definitions implemented
- ✅ Feature flag infrastructure ready
- ✅ Basic response builder utility
- ✅ Request ID middleware integrated
- ✅ Unit tests for all utilities
- ✅ Documentation updated

## 🏗️ Phase 2: Core Response Structure

### Week 3-4: Gradual Controller Migration

#### Day 1-3: Create Parallel Endpoints

Create new endpoints alongside existing ones to test the new response structure:

```typescript
// src/controllers/todo.controller.ts - Add new methods
import { ResponseBuilder } from '../utils/response-builder';
import { FeatureFlagService } from '../config/feature-flags';

@JsonController('/todos')
@injectable()
export class TodoController {
  constructor(
    @inject('TodoService') private todoService: TodoService,
    @inject('ResponseBuilder') private responseBuilder: ResponseBuilder,
    @inject('FeatureFlagService') private featureFlags: FeatureFlagService
  ) {}

  // Existing method (unchanged)
  @Get('')
  async getAllTodos(): Promise<any> {
    // Keep existing implementation
    const todos = await this.todoService.getAllTodos();
    return { success: true, data: todos };
  }

  // New method with standardized response
  @Get('/v2')
  async getAllTodosV2(@Req() req: Request): Promise<ApiResponse<TodoDto[]> | TodoDto[]> {
    const todos = await this.todoService.getAllTodos();
    
    return this.responseBuilder.success({
      data: todos,
      req
    });
  }
}
```

#### Day 4-5: A/B Testing Implementation

```typescript
// src/middleware/ab-testing.middleware.ts
import { Request, Response, NextFunction } from 'express';

export function abTestingMiddleware(req: Request, res: Response, next: NextFunction): void {
  // Determine which version to use based on header or user ID
  const useNewResponse = req.headers['x-api-version'] === 'v2' || 
                        Math.random() < 0.1; // 10% traffic to new version

  req.useNewResponseFormat = useNewResponse;
  next();
}
```

#### Day 6-7: Unified Endpoint with Feature Flag

```typescript
// Updated controller method
@Get('')
async getAllTodos(@Req() req: Request): Promise<ApiResponse<TodoDto[]> | any> {
  const todos = await this.todoService.getAllTodos();
  
  // Use feature flag or A/B test flag
  if (this.featureFlags.isEnabled('standardizedResponses') || req.useNewResponseFormat) {
    return this.responseBuilder.success({
      data: todos,
      req
    });
  }
  
  // Return legacy format
  return { success: true, data: todos };
}
```

### Week 5: Type Safety Enhancement

#### Day 1-3: Update Return Types

```typescript
// Update method signatures progressively
@Get('')
async getAllTodos(@Req() req: Request): Promise<TodoListResponse | LegacyTodoResponse> {
  // Implementation remains the same
}

@Get('/:id')
async getTodoById(
  @Param('id') id: string,
  @Req() req: Request
): Promise<TodoSingleResponse | LegacyTodoResponse> {
  // Implementation remains the same
}

// Type definitions for backward compatibility
type LegacyTodoResponse = { success: boolean; data: TodoDto | TodoDto[] };
```

#### Day 4-5: Response Type Guards

```typescript
// src/utils/type-guards.ts
import { ApiResponse } from '../types/api-response';

export function isStandardizedResponse<T>(response: any): response is ApiResponse<T> {
  return response && typeof response === 'object' && 
         'success' in response && 
         (response.data !== undefined || response.error !== undefined);
}

export function isLegacyResponse(response: any): boolean {
  return response && typeof response === 'object' && 
         'success' in response && 
         'data' in response && 
         !('meta' in response);
}
```

#### Day 6-7: Client Compatibility Layer

```typescript
// src/utils/response-transformer.ts
export class ResponseTransformer {
  static toLegacyFormat<T>(standardResponse: ApiResponse<T>): any {
    if (standardResponse.success) {
      return {
        success: true,
        data: standardResponse.data
      };
    } else {
      return {
        success: false,
        error: standardResponse.error?.detail || 'An error occurred'
      };
    }
  }

  static toStandardFormat<T>(legacyResponse: any): ApiResponse<T> {
    return {
      success: legacyResponse.success,
      data: legacyResponse.data,
      error: legacyResponse.success ? undefined : {
        type: 'https://api.example.com/problems/legacy-error',
        title: 'Error',
        status: 500,
        detail: legacyResponse.error || 'An error occurred'
      }
    };
  }
}
```

**Deliverables:**
- ✅ Parallel endpoints created and tested
- ✅ A/B testing infrastructure implemented
- ✅ Feature flag integration completed
- ✅ Type safety improvements deployed
- ✅ Response compatibility layer implemented
- ✅ Performance metrics baseline established

## 🛡️ Phase 3: Error Handling Enhancement

### Week 6-7: RFC 7807 Implementation

#### Day 1-3: Error Class Implementation

```typescript
// src/errors/http-error.ts - Progressive enhancement
import { HttpError as BaseHttpError } from './base-http-error';
import { FeatureFlagService } from '../config/feature-flags';

export class HttpError extends BaseHttpError {
  constructor(
    status: number,
    response: any,
    private featureFlags?: FeatureFlagService
  ) {
    super(status, response);
  }

  toResponse(): any {
    if (this.featureFlags?.isEnabled('rfc7807Errors')) {
      return this.response; // RFC 7807 format
    }
    
    // Legacy error format
    return {
      success: false,
      error: this.response.error?.detail || this.message
    };
  }
}
```

#### Day 4-5: Global Error Handler Migration

```typescript
// src/middleware/error-handler.middleware.ts
export function globalErrorHandler(
  error: any,
  req: Request,
  res: Response,
  next: NextFunction
): void {
  const featureFlags = container.resolve<FeatureFlagService>('FeatureFlagService');
  
  if (error instanceof HttpError) {
    const response = error.toResponse();
    res.status(error.status).json(response);
  } else {
    // Handle other errors with feature flag support
    const response = featureFlags.isEnabled('rfc7807Errors') 
      ? buildRfc7807Error(error, req)
      : buildLegacyError(error);
    
    res.status(500).json(response);
  }
}
```

#### Day 6-7: Validation Error Enhancement

```typescript
// Enhanced validation error handling
function handleValidationError(error: any, req: Request): any {
  const featureFlags = container.resolve<FeatureFlagService>('FeatureFlagService');
  
  if (featureFlags.isEnabled('rfc7807Errors')) {
    return {
      success: false,
      error: {
        type: 'https://api.example.com/problems/validation-error',
        title: 'Validation Failed',
        status: 400,
        detail: 'Request validation failed',
        instance: req.originalUrl,
        violations: mapValidationErrors(error)
      },
      meta: {
        timestamp: new Date().toISOString(),
        requestId: req.headers['x-request-id'],
        version: process.env.API_VERSION || '1.0.0'
      }
    };
  }
  
  // Legacy format
  return {
    success: false,
    error: 'Validation failed',
    details: mapValidationErrors(error)
  };
}
```

### Week 8: Business Logic Error Integration

#### Day 1-4: Domain-Specific Errors

```typescript
// src/services/todo.service.ts - Enhanced with error handling
async createTodo(command: CreateTodoCommand, req: Request): Promise<TodoDto> {
  try {
    // Business logic validation
    const existingTodo = await this.todoRepository.findByTitle(command.title);
    if (existingTodo) {
      throw new HttpError(409, this.buildConflictError(command.title, existingTodo.id, req));
    }

    const todo = await this.todoRepository.create(command);
    return this.todoMapper.toDto(todo);
  } catch (error) {
    if (error instanceof HttpError) {
      throw error;
    }
    
    // Wrap unexpected errors
    throw new HttpError(500, this.buildInternalError(error, req));
  }
}

private buildConflictError(title: string, existingId: string, req: Request): any {
  const featureFlags = container.resolve<FeatureFlagService>('FeatureFlagService');
  
  if (featureFlags.isEnabled('rfc7807Errors')) {
    return {
      success: false,
      error: {
        type: 'https://api.example.com/problems/duplicate-resource',
        title: 'Duplicate Resource',
        status: 409,
        detail: `A todo with title '${title}' already exists`,
        instance: req.originalUrl,
        existingResourceId: existingId
      },
      meta: this.buildResponseMetadata(req)
    };
  }
  
  return {
    success: false,
    error: `A todo with title '${title}' already exists`
  };
}
```

#### Day 5-7: Error Monitoring Integration

```typescript
// src/utils/error-monitor.ts
export class ErrorMonitor {
  static trackError(error: HttpError, context: any): void {
    const errorData = {
      timestamp: new Date().toISOString(),
      errorId: error.errorId,
      errorCode: error.code,
      httpStatus: error.status,
      category: error.category,
      requestId: context.requestId,
      endpoint: context.instance,
      userAgent: context.userAgent
    };

    // Send to monitoring service (e.g., Sentry, DataDog)
    console.error('Error tracked:', errorData);
    
    // Update error metrics
    this.updateErrorMetrics(error.status, error.category);
  }

  private static updateErrorMetrics(status: number, category: string): void {
    // Implementation depends on metrics service
  }
}
```

**Deliverables:**
- ✅ RFC 7807 compliant error responses implemented
- ✅ Global error handler with feature flag support
- ✅ Business logic error patterns established
- ✅ Error monitoring and metrics integrated
- ✅ Backward compatibility maintained
- ✅ Comprehensive error testing completed

## 🚀 Phase 4: Advanced Features

### Week 9-10: Pagination and Metadata

#### Day 1-3: Pagination Implementation

```typescript
// src/controllers/todo.controller.ts - Enhanced with pagination
@Get('')
async getAllTodos(
  @QueryParams() pagination: PaginationQuery,
  @Req() req: Request
): Promise<TodoListResponse | any> {
  const result = await this.todoService.getAllTodos(pagination);
  
  if (this.featureFlags.isEnabled('standardizedResponses')) {
    return this.responseBuilder.success({
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
        links: this.featureFlags.isEnabled('hateoasLinks') 
          ? this.buildPaginationLinks(req, pagination, result.total)
          : undefined
      },
      req
    });
  }
  
  // Legacy format with pagination info
  return {
    success: true,
    data: result.items,
    pagination: {
      page: pagination.page || 1,
      total: result.total,
      hasNext: result.hasNext
    }
  };
}
```

#### Day 4-5: HATEOAS Links Implementation

```typescript
// src/utils/hateoas-builder.ts
export class HateoasBuilder {
  static buildResourceLinks(req: Request, resourceId: string, resourceType: string): HateoasLinks {
    const baseUrl = this.getBaseUrl(req);
    const resourcePath = this.getResourcePath(resourceType);
    
    return {
      self: `${baseUrl}${resourcePath}/${resourceId}`,
      edit: `${baseUrl}${resourcePath}/${resourceId}`,
      delete: `${baseUrl}${resourcePath}/${resourceId}`,
      collection: `${baseUrl}${resourcePath}`
    };
  }

  static buildCollectionLinks(
    req: Request, 
    pagination: PaginationQuery, 
    total: number
  ): HateoasLinks {
    const baseUrl = this.getBaseUrl(req);
    const basePath = req.path;
    const page = pagination.page || 1;
    const limit = pagination.limit || 10;
    const totalPages = Math.ceil(total / limit);

    const links: HateoasLinks = {
      self: this.buildPaginationUrl(baseUrl, basePath, page, limit),
      first: this.buildPaginationUrl(baseUrl, basePath, 1, limit),
      last: this.buildPaginationUrl(baseUrl, basePath, totalPages, limit)
    };

    if (page < totalPages) {
      links.next = this.buildPaginationUrl(baseUrl, basePath, page + 1, limit);
    }

    if (page > 1) {
      links.previous = this.buildPaginationUrl(baseUrl, basePath, page - 1, limit);
    }

    return links;
  }

  private static buildPaginationUrl(baseUrl: string, path: string, page: number, limit: number): string {
    return `${baseUrl}${path}?page=${page}&limit=${limit}`;
  }

  private static getBaseUrl(req: Request): string {
    return `${req.protocol}://${req.get('host')}`;
  }

  private static getResourcePath(resourceType: string): string {
    return `/${resourceType.toLowerCase()}s`;
  }
}
```

#### Day 6-7: Response Caching Headers

```typescript
// src/middleware/cache-headers.middleware.ts
export function cacheHeadersMiddleware(req: Request, res: Response, next: NextFunction): void {
  // Set default cache headers
  res.set({
    'Cache-Control': 'no-cache, no-store, must-revalidate',
    'Pragma': 'no-cache',
    'Expires': '0'
  });

  // Override for specific endpoints
  if (req.method === 'GET' && req.path.includes('/todos')) {
    res.set({
      'Cache-Control': 'public, max-age=300', // 5 minutes
      'ETag': generateETag(req.path, req.query)
    });
  }

  next();
}
```

### Week 11-12: Performance Optimization

#### Day 1-3: Response Compression

```typescript
// src/middleware/response-optimization.middleware.ts
import compression from 'compression';

export const compressionMiddleware = compression({
  filter: (req, res) => {
    // Compress responses larger than 1KB
    return res.get('Content-Length') > 1024;
  },
  threshold: 1024
});
```

#### Day 4-5: Response Time Tracking

```typescript
// src/middleware/performance.middleware.ts
export function performanceMiddleware(req: Request, res: Response, next: NextFunction): void {
  const startTime = Date.now();
  
  res.on('finish', () => {
    const responseTime = Date.now() - startTime;
    const requestId = req.headers['x-request-id'];
    
    // Log performance metrics
    console.log(`[${requestId}] ${req.method} ${req.path} - ${res.statusCode} - ${responseTime}ms`);
    
    // Add response time header
    res.set('X-Response-Time', `${responseTime}ms`);
    
    // Send metrics to monitoring service
    this.trackPerformanceMetrics(req, res, responseTime);
  });
  
  next();
}
```

#### Day 6-7: Database Query Optimization

```typescript
// src/repositories/todo.repository.ts - Optimized queries
@injectable()
export class TodoRepository {
  async findMany(options: {
    offset: number;
    limit: number;
    sortBy: string;
    sortOrder: 'asc' | 'desc';
  }): Promise<[Todo[], number]> {
    // Use Promise.all for parallel execution
    const [todos, total] = await Promise.all([
      this.db.query(`
        SELECT * FROM todos 
        ORDER BY ${options.sortBy} ${options.sortOrder}
        LIMIT $1 OFFSET $2
      `, [options.limit, options.offset]),
      this.db.query('SELECT COUNT(*) FROM todos')
    ]);

    return [todos.rows, parseInt(total.rows[0].count)];
  }
}
```

**Deliverables:**
- ✅ Pagination support with metadata
- ✅ HATEOAS links implementation
- ✅ Response caching and optimization
- ✅ Performance monitoring integration
- ✅ Database query optimization
- ✅ Load testing with new response structure

## 🧹 Phase 5: Cleanup and Optimization

### Week 13: Legacy Code Removal

#### Day 1-3: Feature Flag Graduation

```typescript
// Gradually remove feature flags for stable features
export class FeatureFlagService {
  isEnabled(flag: keyof FeatureFlags): boolean {
    // Graduate stable features to always-on
    if (flag === 'standardizedResponses' || flag === 'responseMetadata') {
      return true; // These are now default
    }
    
    return this.flags[flag] || false;
  }
}
```

#### Day 4-5: Code Simplification

```typescript
// Remove conditional logic for graduated features
@Get('')
async getAllTodos(@Req() req: Request): Promise<TodoListResponse> {
  const result = await this.todoService.getAllTodos(pagination);
  
  // Always use standardized response (no more feature flag check)
  return this.responseBuilder.success({
    data: result.items,
    meta: {
      pagination: this.buildPaginationMeta(result, pagination),
      links: this.buildHateoasLinks(req, pagination, result.total)
    },
    req
  });
}
```

#### Day 6-7: Documentation Updates

```typescript
// Update OpenAPI documentation
export const todoSwaggerSpec = {
  '/todos': {
    get: {
      summary: 'Get all todos',
      responses: {
        200: {
          description: 'Successful response with standardized format',
          content: {
            'application/json': {
              schema: { $ref: '#/components/schemas/TodoListResponse' }
            }
          }
        }
      }
    }
  }
};
```

### Week 14: Final Testing and Deployment

#### Day 1-3: Comprehensive Testing

```bash
# Run full test suite
npm run test:unit
npm run test:integration
npm run test:e2e

# Performance testing
npm run test:load

# Security testing
npm run test:security
```

#### Day 4-5: Production Deployment

```typescript
// Final configuration check
const productionConfig = {
  features: {
    standardizedResponses: true,
    rfc7807Errors: true,
    responseMetadata: true,
    hateoasLinks: true,
    paginationSupport: true
  },
  monitoring: {
    errorTracking: true,
    performanceMetrics: true,
    responseTimeTracking: true
  }
};
```

#### Day 6-7: Monitoring and Validation

```typescript
// Post-deployment monitoring
export class DeploymentValidator {
  async validateDeployment(): Promise<boolean> {
    const checks = [
      this.checkResponseFormat(),
      this.checkErrorHandling(),
      this.checkPerformanceMetrics(),
      this.checkBackwardCompatibility()
    ];

    const results = await Promise.all(checks);
    return results.every(result => result === true);
  }
}
```

**Deliverables:**
- ✅ Feature flags graduated or removed
- ✅ Legacy code removed
- ✅ Documentation updated
- ✅ Comprehensive testing completed
- ✅ Production deployment successful
- ✅ Post-deployment validation passed

## 🛡️ Risk Mitigation

### Risk Assessment Matrix

| Risk | Probability | Impact | Mitigation Strategy |
|------|-------------|--------|-------------------|
| **Breaking Changes** | Medium | High | Feature flags, A/B testing, backward compatibility |
| **Performance Degradation** | Low | Medium | Load testing, monitoring, rollback procedures |
| **Client Integration Issues** | Medium | Medium | Parallel endpoints, gradual migration, documentation |
| **Data Inconsistency** | Low | High | Comprehensive testing, database migrations |
| **Security Vulnerabilities** | Low | High | Security testing, code reviews, dependency audits |

### Rollback Procedures

#### Immediate Rollback (< 5 minutes)

```bash
# 1. Disable feature flags
kubectl set env deployment/api FEATURE_STANDARDIZED_RESPONSES=false
kubectl set env deployment/api FEATURE_RFC7807_ERRORS=false

# 2. Scale back to previous version
kubectl rollout undo deployment/api

# 3. Verify rollback
kubectl rollout status deployment/api
```

#### Selective Rollback (Feature-specific)

```typescript
// Disable specific features via admin API
POST /admin/feature-flags
{
  "standardizedResponses": false,
  "rfc7807Errors": false
}
```

#### Database Rollback (If needed)

```sql
-- Rollback database changes (if any schema changes were made)
ALTER TABLE todos DROP COLUMN IF EXISTS created_at_iso;
ALTER TABLE todos DROP COLUMN IF EXISTS updated_at_iso;
```

## 📊 Testing Strategy

### Unit Testing

```typescript
// src/__tests__/response-builder.test.ts
describe('ResponseBuilder', () => {
  let responseBuilder: ResponseBuilder;
  let featureFlags: FeatureFlagService;

  beforeEach(() => {
    featureFlags = new FeatureFlagService();
    responseBuilder = new ResponseBuilder(featureFlags);
  });

  it('should return legacy format when feature flag is disabled', () => {
    featureFlags.setFlag('standardizedResponses', false);
    const data = { id: 1, title: 'Test' };
    
    const result = responseBuilder.success({ data, req: mockRequest });
    
    expect(result).toEqual(data);
  });

  it('should return standardized format when feature flag is enabled', () => {
    featureFlags.setFlag('standardizedResponses', true);
    const data = { id: 1, title: 'Test' };
    
    const result = responseBuilder.success({ data, req: mockRequest });
    
    expect(result).toMatchObject({
      success: true,
      data: data
    });
  });
});
```

### Integration Testing

```typescript
// src/__tests__/integration/todo-controller.test.ts
describe('TodoController Integration', () => {
  it('should handle both legacy and new response formats', async () => {
    // Test legacy format
    const legacyResponse = await request(app)
      .get('/todos')
      .set('X-API-Version', 'v1')
      .expect(200);

    expect(legacyResponse.body).toMatchObject({
      success: true,
      data: expect.any(Array)
    });

    // Test new format
    const newResponse = await request(app)
      .get('/todos')
      .set('X-API-Version', 'v2')
      .expect(200);

    expect(newResponse.body).toMatchObject({
      success: true,
      data: expect.any(Array),
      meta: expect.objectContaining({
        timestamp: expect.any(String),
        requestId: expect.any(String)
      })
    });
  });
});
```

### Load Testing

```typescript
// tests/load/api-response-structure.js
import http from 'k6/http';
import { check } from 'k6';

export let options = {
  stages: [
    { duration: '2m', target: 100 },
    { duration: '5m', target: 100 },
    { duration: '2m', target: 200 },
    { duration: '5m', target: 200 },
    { duration: '2m', target: 0 }
  ]
};

export default function() {
  // Test both legacy and new formats
  const responses = http.batch([
    ['GET', 'http://api.example.com/todos', null, { headers: { 'X-API-Version': 'v1' } }],
    ['GET', 'http://api.example.com/todos', null, { headers: { 'X-API-Version': 'v2' } }]
  ]);

  responses.forEach((response, index) => {
    check(response, {
      'status is 200': (r) => r.status === 200,
      'response time < 500ms': (r) => r.timings.duration < 500,
      'has correct format': (r) => {
        const body = JSON.parse(r.body);
        return body.success === true && body.data !== undefined;
      }
    });
  });
}
```

## 📈 Monitoring and Metrics

### Key Performance Indicators (KPIs)

| Metric | Target | Monitoring Method |
|--------|--------|-------------------|
| **Response Time** | < 200ms (95th percentile) | Application monitoring |
| **Error Rate** | < 0.1% | Error tracking service |
| **Availability** | > 99.9% | Uptime monitoring |
| **Memory Usage** | < 80% baseline | Resource monitoring |
| **Client Compatibility** | > 99% success rate | Client telemetry |

### Monitoring Implementation

```typescript
// src/utils/metrics-collector.ts
export class MetricsCollector {
  static trackResponseFormat(req: Request, res: Response, format: 'legacy' | 'standard'): void {
    const metric = {
      timestamp: new Date().toISOString(),
      requestId: req.headers['x-request-id'],
      endpoint: req.path,
      method: req.method,
      responseFormat: format,
      statusCode: res.statusCode,
      userAgent: req.get('User-Agent')
    };

    // Send to metrics service
    this.sendMetric('api.response.format', metric);
  }

  static trackError(error: HttpError, context: any): void {
    const metric = {
      timestamp: new Date().toISOString(),
      errorId: error.errorId,
      errorType: error.code,
      httpStatus: error.status,
      endpoint: context.instance,
      requestId: context.requestId
    };

    this.sendMetric('api.error.occurred', metric);
  }

  private static sendMetric(metricName: string, data: any): void {
    // Implementation depends on monitoring service (DataDog, CloudWatch, etc.)
    console.log(`Metric: ${metricName}`, data);
  }
}
```

### Alerting Rules

```yaml
# monitoring/alerts.yml
alerts:
  - name: high_error_rate
    condition: error_rate > 0.5%
    duration: 5m
    actions:
      - notify_team
      - auto_rollback

  - name: slow_response_times
    condition: p95_response_time > 500ms
    duration: 2m
    actions:
      - notify_team
      - scale_up

  - name: feature_flag_errors
    condition: feature_flag_errors > 10
    duration: 1m
    actions:
      - disable_feature_flags
      - notify_team
```

## 🎯 Success Criteria

### Phase Completion Criteria

| Phase | Success Criteria |
|-------|------------------|
| **Phase 1** | ✅ Foundation types created, feature flags functional, middleware integrated |
| **Phase 2** | ✅ Parallel endpoints working, A/B testing active, type safety improved |
| **Phase 3** | ✅ RFC 7807 errors implemented, global error handler deployed, monitoring active |
| **Phase 4** | ✅ Pagination working, HATEOAS links functional, performance optimized |
| **Phase 5** | ✅ Legacy code removed, documentation updated, production deployment stable |

### Overall Success Metrics

- ✅ **Zero downtime** during entire migration
- ✅ **Backward compatibility** maintained throughout
- ✅ **Performance improvement** or no degradation
- ✅ **Error rate reduction** with better error handling
- ✅ **Developer satisfaction** with improved API structure
- ✅ **Client integration** success rate > 99%

## 🔗 Navigation

### Previous: [Error Handling Patterns](./error-handling-patterns.md)

### Next: [Testing Recommendations](./testing-recommendations.md)

---

## Related Documentation

- [Implementation Examples](./implementation-examples.md)
- [Best Practices Guidelines](./best-practices-guidelines.md)
- [Current Implementation Analysis](./current-implementation-analysis.md)

---

*Migration Strategy completed on July 19, 2025*  
*Progressive enhancement approach with comprehensive risk mitigation*