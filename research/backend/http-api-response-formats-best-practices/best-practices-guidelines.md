# Best Practices Guidelines

## 🎯 Comprehensive Response Format Guidelines

This document provides production-ready best practices for HTTP API response formats, building upon your current implementation strengths while incorporating industry standards and operational excellence patterns.

## 🏗️ Response Structure Principles

### 1. Consistency First

**Core Principle**: Every API response should follow predictable patterns regardless of success or failure state.

```typescript
// Consistent wrapper pattern (maintains your current approach)
interface BaseResponse {
  success: boolean;
  meta: ResponseMetadata;
}

interface SuccessResponse<T> extends BaseResponse {
  success: true;
  data?: T;
  message?: string;
}

interface ErrorResponse extends BaseResponse {
  success: false;
  error: ProblemDetails;
}
```

### 2. Rich Metadata Strategy

**Best Practice**: Include operational metadata in every response for debugging, monitoring, and analytics.

```typescript
interface ResponseMetadata {
  timestamp: string;           // ISO 8601 timestamp
  requestId: string;          // Unique request identifier
  version: string;            // API version
  execution?: {
    duration: number;         // Response time in milliseconds
    cached: boolean;          // Cache hit indicator
  };
  pagination?: PaginationMeta;
  rateLimit?: RateLimitMeta;
}
```

### 3. HTTP Status Code Alignment

**Best Practice**: Response status in body should match HTTP status codes for consistency.

```typescript
const STATUS_CODE_MAPPING = {
  // Success responses
  200: 'OK',
  201: 'CREATED', 
  202: 'ACCEPTED',
  204: 'NO_CONTENT',
  
  // Client error responses
  400: 'BAD_REQUEST',
  401: 'UNAUTHORIZED',
  403: 'FORBIDDEN',
  404: 'NOT_FOUND',
  409: 'CONFLICT',
  422: 'UNPROCESSABLE_ENTITY',
  429: 'TOO_MANY_REQUESTS',
  
  // Server error responses
  500: 'INTERNAL_SERVER_ERROR',
  502: 'BAD_GATEWAY',
  503: 'SERVICE_UNAVAILABLE'
} as const;
```

## 🚨 Error Response Best Practices

### 1. RFC 7807 Problem Details Implementation

**Recommended Structure** (Enhancement of your current pattern):

```typescript
interface ProblemDetails {
  type: string;               // Error type URI or identifier
  title: string;              // Human-readable error category
  status: number;             // HTTP status code
  detail?: string;            // Specific error description
  instance?: string;          // Request-specific identifier
  violations?: ValidationViolation[];  // Field-level errors
  help?: string;              // Documentation or help URL
  code?: string;              // Legacy support for your current codes
}

interface ValidationViolation {
  field: string;              // Field path (from your current path array)
  code: string;               // Error code (from your current issues)
  message: string;            // User-friendly message
  value?: any;                // Invalid value (for debugging)
  expected?: string;          // Expected format/type
}
```

### 2. Error Classification System

**Best Practice**: Categorize errors by type and severity for better client handling.

```typescript
enum ErrorType {
  VALIDATION = '/errors/validation',
  AUTHENTICATION = '/errors/authentication',
  AUTHORIZATION = '/errors/authorization',
  NOT_FOUND = '/errors/not-found',
  CONFLICT = '/errors/conflict',
  RATE_LIMIT = '/errors/rate-limit',
  INTERNAL = '/errors/internal',
  MAINTENANCE = '/errors/maintenance'
}

enum ErrorSeverity {
  LOW = 'low',        // Warning, operation can continue
  MEDIUM = 'medium',  // Error, operation failed but recoverable
  HIGH = 'high',      // Critical, immediate attention required
  CRITICAL = 'critical' // System-level error
}
```

### 3. Enhanced Validation Error Format

**Recommendation**: Improve your current validation pattern with RFC 7807 compliance.

```typescript
// Your current format enhanced
interface ValidationErrorResponse {
  success: false;
  error: {
    type: '/errors/validation-failed';
    title: 'Validation Failed';
    status: 400;
    detail: 'One or more fields failed validation';
    instance: string;           // Request ID
    violations: Array<{
      field: string;            // From your current "path"
      code: string;             // From your current "code"
      message: string;          // From your current "message"
      expected?: string;        // From your current "expected"
      severity: 'error' | 'warning';
    }>;
    // Maintain your current fieldErrors for backward compatibility
    fieldErrors?: Record<string, string[]>;
  };
  meta: ResponseMetadata;
}
```

### 4. Domain Error Enhancement

**Recommendation**: Enhance your domain errors with RFC 7807 structure.

```typescript
// Enhanced version of your AUTH_INVALID_CREDENTIALS
interface DomainErrorResponse {
  success: false;
  error: {
    type: '/errors/authentication/invalid-credentials';
    title: 'Authentication Failed';
    status: 401;
    detail: 'Invalid email/username or password';
    instance: string;
    code: 'AUTH_INVALID_CREDENTIALS';  // Maintain current code
    help: '/docs/authentication';
    retryAfter?: number;              // For rate-limited auth attempts
  };
  meta: ResponseMetadata;
}
```

## ✅ Success Response Best Practices

### 1. Data Response Patterns

**Best Practice**: Consistent data wrapping with rich metadata.

```typescript
// Single resource response
interface ResourceResponse<T> {
  success: true;
  data: T;
  meta: ResponseMetadata & {
    resource: {
      type: string;           // Resource type identifier
      version?: string;       // Resource version
      etag?: string;         // Entity tag for caching
    };
  };
}

// Collection response
interface CollectionResponse<T> {
  success: true;
  data: T[];
  meta: ResponseMetadata & {
    collection: {
      total: number;          // Total items available
      count: number;          // Items in current response
      hasMore: boolean;       // More items available
    };
    pagination: PaginationMeta;
  };
}
```

### 2. Operation Response Patterns

**Best Practice**: Clear confirmation for state-changing operations.

```typescript
// Create operation response
interface CreateResponse<T> {
  success: true;
  data: T;
  message: string;            // "User created successfully"
  meta: ResponseMetadata & {
    operation: {
      type: 'CREATE';
      resource: string;       // Resource identifier
      location?: string;      // Location header URL
    };
  };
}

// Update operation response
interface UpdateResponse<T> {
  success: true;
  data: T;
  message: string;            // "User updated successfully"
  meta: ResponseMetadata & {
    operation: {
      type: 'UPDATE';
      resource: string;
      changes: string[];      // Modified fields
    };
  };
}

// Delete operation response
interface DeleteResponse {
  success: true;
  message: string;            // "User deleted successfully"
  meta: ResponseMetadata & {
    operation: {
      type: 'DELETE';
      resource: string;
    };
  };
}
```

### 3. Pagination Best Practices

**Best Practice**: Comprehensive pagination information for collections.

```typescript
interface PaginationMeta {
  page: number;               // Current page (1-based)
  limit: number;              // Items per page
  total: number;              // Total items
  pages: number;              // Total pages
  hasNext: boolean;           // Has next page
  hasPrev: boolean;           // Has previous page
  links: {
    first: string;            // First page URL
    prev?: string;            // Previous page URL
    next?: string;            // Next page URL
    last: string;             // Last page URL
  };
}
```

## 🔧 Implementation Utilities

### 1. Response Builder Functions

```typescript
class ApiResponseBuilder {
  private requestId: string;
  private timestamp: string;

  constructor(requestId: string) {
    this.requestId = requestId;
    this.timestamp = new Date().toISOString();
  }

  success<T>(data?: T, message?: string): SuccessResponse<T> {
    return {
      success: true,
      ...(data !== undefined && { data }),
      ...(message && { message }),
      meta: this.buildMeta()
    };
  }

  error(error: ProblemDetails): ErrorResponse {
    return {
      success: false,
      error,
      meta: this.buildMeta()
    };
  }

  validationError(violations: ValidationViolation[]): ErrorResponse {
    const fieldErrors = violations.reduce((acc, violation) => {
      acc[violation.field] = acc[violation.field] || [];
      acc[violation.field].push(violation.message);
      return acc;
    }, {} as Record<string, string[]>);

    return this.error({
      type: '/errors/validation-failed',
      title: 'Validation Failed',
      status: 400,
      detail: `${violations.length} field(s) failed validation`,
      instance: this.requestId,
      violations,
      fieldErrors // Backward compatibility
    });
  }

  private buildMeta(): ResponseMetadata {
    return {
      timestamp: this.timestamp,
      requestId: this.requestId,
      version: '1.0'
    };
  }
}
```

### 2. Express.js Middleware Integration

```typescript
// Request ID middleware
export const requestIdMiddleware = (
  req: Request, 
  res: Response, 
  next: NextFunction
) => {
  req.requestId = req.headers['x-request-id'] as string || 
                  crypto.randomUUID();
  
  res.setHeader('X-Request-ID', req.requestId);
  next();
};

// Response builder middleware
export const responseBuilderMiddleware = (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  res.locals.responseBuilder = new ApiResponseBuilder(req.requestId);
  next();
};

// Error handling middleware
export const errorHandlerMiddleware = (
  error: Error,
  req: Request,
  res: Response,
  next: NextFunction
) => {
  const builder = res.locals.responseBuilder as ApiResponseBuilder;
  
  if (error instanceof ValidationError) {
    const response = builder.validationError(error.violations);
    return res.status(400).json(response);
  }
  
  if (error instanceof DomainError) {
    const response = builder.error({
      type: `/errors/${error.category}/${error.code.toLowerCase()}`,
      title: error.title,
      status: error.statusCode,
      detail: error.message,
      instance: req.requestId,
      code: error.code
    });
    return res.status(error.statusCode).json(response);
  }
  
  // Generic error fallback
  const response = builder.error({
    type: '/errors/internal',
    title: 'Internal Server Error',
    status: 500,
    detail: 'An unexpected error occurred',
    instance: req.requestId
  });
  
  res.status(500).json(response);
};
```

## 📏 Response Size Optimization

### 1. Conditional Field Inclusion

```typescript
interface ResponseOptions {
  includeMetadata?: boolean;
  includePagination?: boolean;
  fields?: string[];          // Field selection
  expand?: string[];          // Relationship expansion
}

class OptimizedResponseBuilder extends ApiResponseBuilder {
  success<T>(
    data?: T, 
    message?: string, 
    options: ResponseOptions = {}
  ): SuccessResponse<T> {
    const response = super.success(data, message);
    
    if (!options.includeMetadata) {
      delete response.meta?.execution;
    }
    
    if (options.fields && data) {
      response.data = this.selectFields(data, options.fields);
    }
    
    return response;
  }
  
  private selectFields<T>(data: T, fields: string[]): Partial<T> {
    // Implementation for field selection
    return Object.keys(data as any)
      .filter(key => fields.includes(key))
      .reduce((obj, key) => {
        obj[key] = (data as any)[key];
        return obj;
      }, {} as any);
  }
}
```

### 2. Compression Strategy

```typescript
// Response compression middleware
export const compressionStrategy = (req: Request, res: Response, next: NextFunction) => {
  const acceptEncoding = req.headers['accept-encoding'] || '';
  
  if (acceptEncoding.includes('gzip')) {
    res.setHeader('Content-Encoding', 'gzip');
  }
  
  // Large response detection
  const originalJson = res.json;
  res.json = function(data: any) {
    const size = JSON.stringify(data).length;
    
    if (size > 1024 * 10) { // 10KB threshold
      res.setHeader('X-Response-Size', size.toString());
      res.setHeader('X-Large-Response', 'true');
    }
    
    return originalJson.call(this, data);
  };
  
  next();
};
```

## 🔍 Monitoring and Observability

### 1. Response Analytics

```typescript
interface ResponseAnalytics {
  timestamp: string;
  requestId: string;
  endpoint: string;
  method: string;
  statusCode: number;
  success: boolean;
  responseTime: number;
  responseSize: number;
  errorType?: string;
  userId?: string;
}

export const analyticsMiddleware = (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  const startTime = Date.now();
  
  const originalJson = res.json;
  res.json = function(data: any) {
    const analytics: ResponseAnalytics = {
      timestamp: new Date().toISOString(),
      requestId: req.requestId,
      endpoint: req.route?.path || req.path,
      method: req.method,
      statusCode: res.statusCode,
      success: data.success,
      responseTime: Date.now() - startTime,
      responseSize: JSON.stringify(data).length,
      errorType: data.error?.type,
      userId: req.user?.id
    };
    
    // Send to analytics service
    analyticsService.track(analytics);
    
    return originalJson.call(this, data);
  };
  
  next();
};
```

### 2. Health Check Responses

```typescript
interface HealthCheckResponse {
  success: true;
  status: 'healthy' | 'degraded' | 'unhealthy';
  checks: Record<string, {
    status: 'up' | 'down';
    responseTime?: number;
    error?: string;
  }>;
  meta: ResponseMetadata;
}

export const healthCheckHandler = async (req: Request, res: Response) => {
  const builder = res.locals.responseBuilder as ApiResponseBuilder;
  
  const checks = await Promise.allSettled([
    checkDatabase(),
    checkRedis(),
    checkExternalAPIs()
  ]);
  
  const healthData = {
    status: determineOverallHealth(checks),
    checks: formatHealthChecks(checks)
  };
  
  const response = builder.success(healthData);
  const statusCode = healthData.status === 'healthy' ? 200 : 503;
  
  res.status(statusCode).json(response);
};
```

## 📋 Implementation Checklist

### Phase 1: Foundation (Week 1)
- [ ] Implement `ApiResponseBuilder` class
- [ ] Add request ID middleware
- [ ] Create TypeScript interfaces
- [ ] Add basic metadata to responses
- [ ] Test backward compatibility

### Phase 2: RFC 7807 Integration (Week 2)
- [ ] Enhance error responses with Problem Details
- [ ] Implement error type classification
- [ ] Add instance tracking
- [ ] Maintain backward compatibility with current codes
- [ ] Update error handling middleware

### Phase 3: Advanced Features (Week 3)
- [ ] Add pagination support
- [ ] Implement response optimization
- [ ] Add analytics middleware
- [ ] Create health check endpoints
- [ ] Add comprehensive testing

### Phase 4: Monitoring & Observability (Week 4)
- [ ] Implement response analytics
- [ ] Add performance monitoring
- [ ] Create debugging utilities
- [ ] Add API documentation generation
- [ ] Performance optimization

---

### Navigation
- **Previous**: [Industry Standards Comparison](./industry-standards-comparison.md)
- **Next**: [Comparison Analysis](./comparison-analysis.md)

---

*These best practices build upon your current implementation strengths while adding industry-standard patterns for production-ready APIs. Focus on incremental adoption to maintain system stability.*