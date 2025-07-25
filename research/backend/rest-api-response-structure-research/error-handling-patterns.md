# Error Handling Patterns: RFC 7807 Compliance

## 🎯 Overview

This document provides comprehensive error handling patterns that comply with RFC 7807 Problem Details for HTTP APIs. It demonstrates how to implement standardized, machine-readable error responses that enhance debugging capabilities and improve client integration.

## 📋 Table of Contents

1. [RFC 7807 Problem Details Standard](#rfc-7807-problem-details-standard)
2. [Error Classification System](#error-classification-system)
3. [Standard Error Types](#standard-error-types)
4. [Custom Error Classes](#custom-error-classes)
5. [Validation Error Handling](#validation-error-handling)
6. [Business Logic Error Patterns](#business-logic-error-patterns)
7. [Global Error Middleware](#global-error-middleware)
8. [Error Response Examples](#error-response-examples)
9. [Client Error Handling Guidelines](#client-error-handling-guidelines)

## 📖 RFC 7807 Problem Details Standard

### Core Principles

RFC 7807 defines a standard format for representing problems in HTTP API responses. The standard provides:

- **Machine-readable format** for error details
- **Extensible structure** for additional context
- **Consistent error representation** across different APIs
- **Better debugging capabilities** with structured information

### Required Fields

```typescript
interface ProblemDetails {
  type: string;     // URI identifying the problem type
  title: string;    // Human-readable summary
  status: number;   // HTTP status code
  detail?: string;  // Instance-specific explanation
  instance?: string; // URI identifying the problem instance
}
```

### Extension Fields

```typescript
interface ExtendedProblemDetails extends ProblemDetails {
  [key: string]: any; // Additional problem-specific properties
}
```

## 🏷️ Error Classification System

### HTTP Status Code Mapping

```typescript
// types/error-classification.ts
export enum ErrorCategory {
  CLIENT_ERROR = 'CLIENT_ERROR',
  SERVER_ERROR = 'SERVER_ERROR',
  VALIDATION_ERROR = 'VALIDATION_ERROR',
  AUTHENTICATION_ERROR = 'AUTHENTICATION_ERROR',
  AUTHORIZATION_ERROR = 'AUTHORIZATION_ERROR',
  BUSINESS_LOGIC_ERROR = 'BUSINESS_LOGIC_ERROR',
  EXTERNAL_SERVICE_ERROR = 'EXTERNAL_SERVICE_ERROR'
}

export interface ErrorType {
  code: string;
  httpStatus: number;
  category: ErrorCategory;
  type: string; // RFC 7807 type URI
  title: string;
  retryable: boolean;
}

export const ERROR_TYPES: Record<string, ErrorType> = {
  // 4xx Client Errors
  VALIDATION_ERROR: {
    code: 'VALIDATION_ERROR',
    httpStatus: 400,
    category: ErrorCategory.VALIDATION_ERROR,
    type: 'https://api.example.com/problems/validation-error',
    title: 'Validation Failed',
    retryable: false
  },
  UNAUTHORIZED: {
    code: 'UNAUTHORIZED',
    httpStatus: 401,
    category: ErrorCategory.AUTHENTICATION_ERROR,
    type: 'https://api.example.com/problems/unauthorized',
    title: 'Authentication Required',
    retryable: false
  },
  FORBIDDEN: {
    code: 'FORBIDDEN',
    httpStatus: 403,
    category: ErrorCategory.AUTHORIZATION_ERROR,
    type: 'https://api.example.com/problems/forbidden',
    title: 'Access Forbidden',
    retryable: false
  },
  NOT_FOUND: {
    code: 'NOT_FOUND',
    httpStatus: 404,
    category: ErrorCategory.CLIENT_ERROR,
    type: 'https://api.example.com/problems/not-found',
    title: 'Resource Not Found',
    retryable: false
  },
  CONFLICT: {
    code: 'CONFLICT',
    httpStatus: 409,
    category: ErrorCategory.BUSINESS_LOGIC_ERROR,
    type: 'https://api.example.com/problems/conflict',
    title: 'Resource Conflict',
    retryable: false
  },
  RATE_LIMIT_EXCEEDED: {
    code: 'RATE_LIMIT_EXCEEDED',
    httpStatus: 429,
    category: ErrorCategory.CLIENT_ERROR,
    type: 'https://api.example.com/problems/rate-limit-exceeded',
    title: 'Rate Limit Exceeded',
    retryable: true
  },
  
  // 5xx Server Errors
  INTERNAL_SERVER_ERROR: {
    code: 'INTERNAL_SERVER_ERROR',
    httpStatus: 500,
    category: ErrorCategory.SERVER_ERROR,
    type: 'https://api.example.com/problems/internal-error',
    title: 'Internal Server Error',
    retryable: true
  },
  SERVICE_UNAVAILABLE: {
    code: 'SERVICE_UNAVAILABLE',
    httpStatus: 503,
    category: ErrorCategory.EXTERNAL_SERVICE_ERROR,
    type: 'https://api.example.com/problems/service-unavailable',
    title: 'Service Temporarily Unavailable',
    retryable: true
  },
  GATEWAY_TIMEOUT: {
    code: 'GATEWAY_TIMEOUT',
    httpStatus: 504,
    category: ErrorCategory.EXTERNAL_SERVICE_ERROR,
    type: 'https://api.example.com/problems/gateway-timeout',
    title: 'Gateway Timeout',
    retryable: true
  }
};
```

## 🔧 Standard Error Types

### Base Error Interface

```typescript
// types/error-responses.ts
import { ApiResponse, ProblemDetails } from './api-response';

export interface BaseErrorResponse extends ApiResponse<never> {
  success: false;
  error: ProblemDetails;
  meta: {
    timestamp: string;
    requestId: string;
    version: string;
    errorId?: string;
  };
}

export interface ValidationErrorResponse extends BaseErrorResponse {
  error: ProblemDetails & {
    type: 'https://api.example.com/problems/validation-error';
    violations: ValidationViolation[];
  };
}

export interface NotFoundErrorResponse extends BaseErrorResponse {
  error: ProblemDetails & {
    type: 'https://api.example.com/problems/not-found';
    resourceType: string;
    resourceId: string;
  };
}

export interface ConflictErrorResponse extends BaseErrorResponse {
  error: ProblemDetails & {
    type: 'https://api.example.com/problems/conflict';
    resource: string;
    conflictReason: string;
  };
}

export interface RateLimitErrorResponse extends BaseErrorResponse {
  error: ProblemDetails & {
    type: 'https://api.example.com/problems/rate-limit-exceeded';
    retryAfter: number; // seconds
    limit: number;
    remaining: number;
    resetTime: string;
  };
}

export interface InternalErrorResponse extends BaseErrorResponse {
  error: ProblemDetails & {
    type: 'https://api.example.com/problems/internal-error';
    errorId: string;
    timestamp: string;
  };
}
```

## 🏗️ Custom Error Classes

### Base HTTP Error Class

```typescript
// errors/http-error.ts
import { ErrorType, ERROR_TYPES } from '../types/error-classification';
import { BaseErrorResponse } from '../types/error-responses';

export class HttpError extends Error {
  public readonly status: number;
  public readonly code: string;
  public readonly category: string;
  public readonly response: BaseErrorResponse;
  public readonly retryable: boolean;
  public readonly errorId: string;

  constructor(
    errorType: ErrorType,
    options: {
      detail?: string;
      instance?: string;
      requestId: string;
      extensions?: Record<string, any>;
    }
  ) {
    super(errorType.title);
    
    this.status = errorType.httpStatus;
    this.code = errorType.code;
    this.category = errorType.category;
    this.retryable = errorType.retryable;
    this.errorId = `err_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;

    this.response = {
      success: false,
      error: {
        type: errorType.type,
        title: errorType.title,
        status: errorType.httpStatus,
        detail: options.detail,
        instance: options.instance,
        ...options.extensions
      },
      meta: {
        timestamp: new Date().toISOString(),
        requestId: options.requestId,
        version: process.env.API_VERSION || '1.0.0',
        errorId: this.errorId
      }
    };

    Error.captureStackTrace(this, HttpError);
  }

  static validation(options: {
    violations: ValidationViolation[];
    detail?: string;
    instance: string;
    requestId: string;
  }): HttpError {
    return new HttpError(ERROR_TYPES.VALIDATION_ERROR, {
      detail: options.detail || 'Request validation failed',
      instance: options.instance,
      requestId: options.requestId,
      extensions: {
        violations: options.violations
      }
    });
  }

  static notFound(options: {
    resourceType: string;
    resourceId: string;
    instance: string;
    requestId: string;
  }): HttpError {
    return new HttpError(ERROR_TYPES.NOT_FOUND, {
      detail: `The requested ${options.resourceType} with ID '${options.resourceId}' was not found`,
      instance: options.instance,
      requestId: options.requestId,
      extensions: {
        resourceType: options.resourceType,
        resourceId: options.resourceId
      }
    });
  }

  static conflict(options: {
    resource: string;
    conflictReason: string;
    instance: string;
    requestId: string;
  }): HttpError {
    return new HttpError(ERROR_TYPES.CONFLICT, {
      detail: `Cannot process request due to conflict: ${options.conflictReason}`,
      instance: options.instance,
      requestId: options.requestId,
      extensions: {
        resource: options.resource,
        conflictReason: options.conflictReason
      }
    });
  }

  static unauthorized(options: {
    realm?: string;
    instance: string;
    requestId: string;
  }): HttpError {
    return new HttpError(ERROR_TYPES.UNAUTHORIZED, {
      detail: 'Valid authentication credentials are required',
      instance: options.instance,
      requestId: options.requestId,
      extensions: {
        realm: options.realm || 'API'
      }
    });
  }

  static forbidden(options: {
    resource?: string;
    action?: string;
    instance: string;
    requestId: string;
  }): HttpError {
    const detail = options.resource && options.action
      ? `Insufficient permissions to ${options.action} ${options.resource}`
      : 'Insufficient permissions to access this resource';

    return new HttpError(ERROR_TYPES.FORBIDDEN, {
      detail,
      instance: options.instance,
      requestId: options.requestId,
      extensions: {
        resource: options.resource,
        action: options.action
      }
    });
  }

  static rateLimit(options: {
    retryAfter: number;
    limit: number;
    remaining: number;
    resetTime: string;
    instance: string;
    requestId: string;
  }): HttpError {
    return new HttpError(ERROR_TYPES.RATE_LIMIT_EXCEEDED, {
      detail: `Rate limit exceeded. Try again in ${options.retryAfter} seconds`,
      instance: options.instance,
      requestId: options.requestId,
      extensions: {
        retryAfter: options.retryAfter,
        limit: options.limit,
        remaining: options.remaining,
        resetTime: options.resetTime
      }
    });
  }

  static internal(options: {
    originalError?: Error;
    instance: string;
    requestId: string;
  }): HttpError {
    // Log the original error for debugging (don't expose to client)
    if (options.originalError) {
      console.error('Internal Error:', options.originalError);
    }

    return new HttpError(ERROR_TYPES.INTERNAL_SERVER_ERROR, {
      detail: 'An unexpected error occurred while processing your request',
      instance: options.instance,
      requestId: options.requestId
    });
  }
}
```

### Specialized Error Classes

```typescript
// errors/business-errors.ts
import { HttpError } from './http-error';

export class TodoBusinessError extends HttpError {
  static duplicateTitle(options: {
    title: string;
    existingId: string;
    instance: string;
    requestId: string;
  }): HttpError {
    return HttpError.conflict({
      resource: 'Todo',
      conflictReason: `A todo with title '${options.title}' already exists (ID: ${options.existingId})`,
      instance: options.instance,
      requestId: options.requestId
    });
  }

  static invalidStatusTransition(options: {
    currentStatus: string;
    targetStatus: string;
    todoId: string;
    instance: string;
    requestId: string;
  }): HttpError {
    return HttpError.conflict({
      resource: 'Todo',
      conflictReason: `Cannot transition from '${options.currentStatus}' to '${options.targetStatus}' for todo ${options.todoId}`,
      instance: options.instance,
      requestId: options.requestId
    });
  }

  static completedTodoModification(options: {
    todoId: string;
    instance: string;
    requestId: string;
  }): HttpError {
    return HttpError.conflict({
      resource: 'Todo',
      conflictReason: `Cannot modify completed todo ${options.todoId}`,
      instance: options.instance,
      requestId: options.requestId
    });
  }
}

export class DatabaseError extends HttpError {
  static connectionFailed(options: {
    instance: string;
    requestId: string;
  }): HttpError {
    return new HttpError(ERROR_TYPES.SERVICE_UNAVAILABLE, {
      detail: 'Database connection is currently unavailable',
      instance: options.instance,
      requestId: options.requestId,
      extensions: {
        service: 'database',
        retryable: true
      }
    });
  }

  static queryTimeout(options: {
    query: string;
    timeout: number;
    instance: string;
    requestId: string;
  }): HttpError {
    return new HttpError(ERROR_TYPES.GATEWAY_TIMEOUT, {
      detail: `Database query timed out after ${options.timeout}ms`,
      instance: options.instance,
      requestId: options.requestId,
      extensions: {
        service: 'database',
        query: options.query,
        timeout: options.timeout
      }
    });
  }
}
```

## ✅ Validation Error Handling

### Enhanced Validation Error Mapping

```typescript
// utils/validation-error-mapper.ts
import { ValidationError } from 'class-validator';
import { HttpError } from '../errors/http-error';
import { ValidationViolation } from '../types/api-response';

export class ValidationErrorMapper {
  static mapValidationErrors(
    errors: ValidationError[],
    instance: string,
    requestId: string
  ): HttpError {
    const violations: ValidationViolation[] = [];

    const processError = (error: ValidationError, parentPath = ''): void => {
      const fieldPath = parentPath ? `${parentPath}.${error.property}` : error.property;

      if (error.constraints) {
        Object.entries(error.constraints).forEach(([constraintKey, message]) => {
          violations.push({
            field: fieldPath,
            message: message,
            code: this.mapConstraintToCode(constraintKey),
            rejectedValue: error.value
          });
        });
      }

      if (error.children && error.children.length > 0) {
        error.children.forEach(child => processError(child, fieldPath));
      }
    };

    errors.forEach(error => processError(error));

    return HttpError.validation({
      violations,
      detail: `Validation failed for ${violations.length} field(s)`,
      instance,
      requestId
    });
  }

  private static mapConstraintToCode(constraintKey: string): string {
    const constraintMap: Record<string, string> = {
      isNotEmpty: 'REQUIRED',
      isString: 'INVALID_TYPE',
      isEmail: 'INVALID_EMAIL',
      isUrl: 'INVALID_URL',
      isUUID: 'INVALID_UUID',
      min: 'MIN_VALUE',
      max: 'MAX_VALUE',
      minLength: 'MIN_LENGTH',
      maxLength: 'MAX_LENGTH',
      isPositive: 'MUST_BE_POSITIVE',
      isIn: 'INVALID_CHOICE',
      matches: 'INVALID_FORMAT'
    };

    return constraintMap[constraintKey] || 'VALIDATION_FAILED';
  }
}
```

### Custom Validation Decorators

```typescript
// decorators/validation.decorators.ts
import { 
  registerDecorator, 
  ValidationOptions, 
  ValidationArguments,
  ValidatorConstraint,
  ValidatorConstraintInterface
} from 'class-validator';

@ValidatorConstraint({ async: false })
export class IsTodoStatusConstraint implements ValidatorConstraintInterface {
  validate(status: any, args: ValidationArguments) {
    return typeof status === 'string' && ['pending', 'in-progress', 'completed'].includes(status);
  }

  defaultMessage(args: ValidationArguments) {
    return 'Status must be one of: pending, in-progress, completed';
  }
}

export function IsTodoStatus(validationOptions?: ValidationOptions) {
  return function (object: Object, propertyName: string) {
    registerDecorator({
      target: object.constructor,
      propertyName: propertyName,
      options: validationOptions,
      constraints: [],
      validator: IsTodoStatusConstraint,
    });
  };
}

@ValidatorConstraint({ async: true })
export class IsUniqueEmailConstraint implements ValidatorConstraintInterface {
  async validate(email: string, args: ValidationArguments) {
    // Mock implementation - replace with actual database check
    const existingUser = await this.checkEmailExists(email);
    return !existingUser;
  }

  defaultMessage(args: ValidationArguments) {
    return 'Email $value is already registered';
  }

  private async checkEmailExists(email: string): Promise<boolean> {
    // Implementation would check database
    return false;
  }
}

export function IsUniqueEmail(validationOptions?: ValidationOptions) {
  return function (object: Object, propertyName: string) {
    registerDecorator({
      target: object.constructor,
      propertyName: propertyName,
      options: validationOptions,
      constraints: [],
      validator: IsUniqueEmailConstraint,
    });
  };
}
```

## 🔄 Business Logic Error Patterns

### Domain-Specific Error Handling

```typescript
// services/todo.service.ts - Enhanced with business logic error handling
import { inject, injectable } from 'tsyringe';
import { TodoRepository } from '../repositories/todo.repository';
import { TodoDto } from '../dtos/todo.dto';
import { TodoMapper } from '../mappers/todo.mapper';
import { CreateTodoCommand, UpdateTodoCommand } from '../commands/todo.commands';
import { TodoBusinessError } from '../errors/business-errors';
import { HttpError } from '../errors/http-error';

@injectable()
export class TodoService {
  constructor(
    @inject('TodoRepository') private todoRepository: TodoRepository,
    @inject('TodoMapper') private todoMapper: TodoMapper
  ) {}

  async createTodo(command: CreateTodoCommand, requestContext: RequestContext): Promise<TodoDto> {
    try {
      // Business rule: Check for duplicate titles
      const existingTodo = await this.todoRepository.findByTitle(command.title);
      if (existingTodo) {
        throw TodoBusinessError.duplicateTitle({
          title: command.title,
          existingId: existingTodo.id,
          instance: requestContext.instance,
          requestId: requestContext.requestId
        });
      }

      const todo = await this.todoRepository.create(command);
      return this.todoMapper.toDto(todo);
    } catch (error) {
      if (error instanceof HttpError) {
        throw error; // Re-throw known business errors
      }
      
      // Handle unexpected database errors
      throw HttpError.internal({
        originalError: error,
        instance: requestContext.instance,
        requestId: requestContext.requestId
      });
    }
  }

  async updateTodoStatus(
    id: string, 
    newStatus: string, 
    requestContext: RequestContext
  ): Promise<TodoDto> {
    try {
      const todo = await this.todoRepository.findById(id);
      
      if (!todo) {
        throw HttpError.notFound({
          resourceType: 'Todo',
          resourceId: id,
          instance: requestContext.instance,
          requestId: requestContext.requestId
        });
      }

      // Business rule: Cannot modify completed todos
      if (todo.status === 'completed' && newStatus !== 'completed') {
        throw TodoBusinessError.completedTodoModification({
          todoId: id,
          instance: requestContext.instance,
          requestId: requestContext.requestId
        });
      }

      // Business rule: Validate status transitions
      if (!this.isValidStatusTransition(todo.status, newStatus)) {
        throw TodoBusinessError.invalidStatusTransition({
          currentStatus: todo.status,
          targetStatus: newStatus,
          todoId: id,
          instance: requestContext.instance,
          requestId: requestContext.requestId
        });
      }

      const updatedTodo = await this.todoRepository.updateStatus(id, newStatus);
      return this.todoMapper.toDto(updatedTodo);
    } catch (error) {
      if (error instanceof HttpError) {
        throw error;
      }
      
      throw HttpError.internal({
        originalError: error,
        instance: requestContext.instance,
        requestId: requestContext.requestId
      });
    }
  }

  private isValidStatusTransition(current: string, target: string): boolean {
    const validTransitions: Record<string, string[]> = {
      'pending': ['in-progress', 'completed'],
      'in-progress': ['pending', 'completed'],
      'completed': [] // No transitions allowed from completed
    };

    return validTransitions[current]?.includes(target) || false;
  }
}

interface RequestContext {
  instance: string;
  requestId: string;
  userId?: string;
}
```

## 🌐 Global Error Middleware

### Comprehensive Error Handler

```typescript
// middleware/global-error-handler.ts
import { Request, Response, NextFunction } from 'express';
import { ValidationError as ClassValidatorError } from 'class-validator';
import { HttpError } from '../errors/http-error';
import { ValidationErrorMapper } from '../utils/validation-error-mapper';
import { ErrorLogger } from '../utils/error-logger';

export function globalErrorHandler(
  error: any,
  req: Request,
  res: Response,
  next: NextFunction
): void {
  const requestId = req.headers['x-request-id'] as string;
  const instance = req.originalUrl;

  // Log error for monitoring and debugging
  ErrorLogger.logError(error, { requestId, instance, userAgent: req.get('User-Agent') });

  if (error instanceof HttpError) {
    // Handle our custom HTTP errors
    handleHttpError(error, res);
  } else if (error.name === 'ValidationError' || error instanceof ClassValidatorError) {
    // Handle class-validator validation errors
    handleValidationError(error, instance, requestId, res);
  } else if (error.name === 'SyntaxError' && error.type === 'entity.parse.failed') {
    // Handle JSON parsing errors
    handleJsonParseError(instance, requestId, res);
  } else if (error.code === 'ECONNREFUSED' || error.code === 'ENOTFOUND') {
    // Handle database/external service connection errors
    handleConnectionError(error, instance, requestId, res);
  } else if (error.name === 'TimeoutError') {
    // Handle timeout errors
    handleTimeoutError(error, instance, requestId, res);
  } else {
    // Handle all other unexpected errors
    handleUnexpectedError(error, instance, requestId, res);
  }
}

function handleHttpError(error: HttpError, res: Response): void {
  res.status(error.status).json(error.response);
}

function handleValidationError(
  error: any,
  instance: string,
  requestId: string,
  res: Response
): void {
  const httpError = ValidationErrorMapper.mapValidationErrors(
    Array.isArray(error) ? error : [error],
    instance,
    requestId
  );
  
  res.status(httpError.status).json(httpError.response);
}

function handleJsonParseError(
  instance: string,
  requestId: string,
  res: Response
): void {
  const httpError = HttpError.validation({
    violations: [
      {
        field: 'body',
        message: 'Invalid JSON format in request body',
        code: 'INVALID_JSON',
        rejectedValue: undefined
      }
    ],
    detail: 'Request body contains malformed JSON',
    instance,
    requestId
  });

  res.status(httpError.status).json(httpError.response);
}

function handleConnectionError(
  error: any,
  instance: string,
  requestId: string,
  res: Response
): void {
  const httpError = new HttpError(ERROR_TYPES.SERVICE_UNAVAILABLE, {
    detail: 'External service is temporarily unavailable',
    instance,
    requestId,
    extensions: {
      service: 'database',
      errorCode: error.code
    }
  });

  res.status(httpError.status).json(httpError.response);
}

function handleTimeoutError(
  error: any,
  instance: string,
  requestId: string,
  res: Response
): void {
  const httpError = new HttpError(ERROR_TYPES.GATEWAY_TIMEOUT, {
    detail: 'Request timed out while processing',
    instance,
    requestId,
    extensions: {
      timeout: error.timeout || 'unknown'
    }
  });

  res.status(httpError.status).json(httpError.response);
}

function handleUnexpectedError(
  error: any,
  instance: string,
  requestId: string,
  res: Response
): void {
  const httpError = HttpError.internal({
    originalError: error,
    instance,
    requestId
  });

  res.status(httpError.status).json(httpError.response);
}
```

### Error Logging Utility

```typescript
// utils/error-logger.ts
import { ErrorCategory } from '../types/error-classification';
import { HttpError } from '../errors/http-error';

export interface ErrorLogContext {
  requestId: string;
  instance: string;
  userAgent?: string;
  userId?: string;
  ip?: string;
}

export class ErrorLogger {
  static logError(error: any, context: ErrorLogContext): void {
    const logEntry = {
      timestamp: new Date().toISOString(),
      requestId: context.requestId,
      instance: context.instance,
      userAgent: context.userAgent,
      userId: context.userId,
      ip: context.ip,
      error: this.serializeError(error)
    };

    if (error instanceof HttpError) {
      this.logHttpError(error, logEntry);
    } else {
      this.logUnexpectedError(error, logEntry);
    }
  }

  private static logHttpError(error: HttpError, logEntry: any): void {
    const severity = this.getErrorSeverity(error.status);
    
    const httpLogEntry = {
      ...logEntry,
      severity,
      errorCode: error.code,
      errorCategory: error.category,
      httpStatus: error.status,
      retryable: error.retryable,
      errorId: error.errorId
    };

    if (severity === 'error') {
      console.error('HTTP Error:', JSON.stringify(httpLogEntry, null, 2));
    } else {
      console.warn('HTTP Warning:', JSON.stringify(httpLogEntry, null, 2));
    }
  }

  private static logUnexpectedError(error: any, logEntry: any): void {
    const unexpectedLogEntry = {
      ...logEntry,
      severity: 'error',
      errorType: 'UNEXPECTED_ERROR',
      stack: error.stack
    };

    console.error('Unexpected Error:', JSON.stringify(unexpectedLogEntry, null, 2));
  }

  private static serializeError(error: any): any {
    return {
      name: error.name,
      message: error.message,
      code: error.code,
      ...(error instanceof HttpError && {
        status: error.status,
        category: error.category,
        errorId: error.errorId
      })
    };
  }

  private static getErrorSeverity(status: number): 'warning' | 'error' {
    return status >= 500 ? 'error' : 'warning';
  }
}
```

## 📝 Error Response Examples

### Validation Error Response

```json
{
  "success": false,
  "error": {
    "type": "https://api.example.com/problems/validation-error",
    "title": "Validation Failed",
    "status": 400,
    "detail": "Validation failed for 2 field(s)",
    "instance": "/todos",
    "violations": [
      {
        "field": "title",
        "message": "Title is required",
        "code": "REQUIRED",
        "rejectedValue": ""
      },
      {
        "field": "priority",
        "message": "Priority must be one of: low, medium, high",
        "code": "INVALID_CHOICE",
        "rejectedValue": "urgent"
      }
    ]
  },
  "meta": {
    "timestamp": "2025-07-19T10:30:00.000Z",
    "requestId": "req-123456789",
    "version": "1.0.0",
    "errorId": "err_1721382600_abc123xyz"
  }
}
```

### Business Logic Error Response

```json
{
  "success": false,
  "error": {
    "type": "https://api.example.com/problems/conflict",
    "title": "Resource Conflict",
    "status": 409,
    "detail": "Cannot transition from 'completed' to 'in-progress' for todo 123",
    "instance": "/todos/123/status",
    "resource": "Todo",
    "conflictReason": "Cannot transition from 'completed' to 'in-progress' for todo 123"
  },
  "meta": {
    "timestamp": "2025-07-19T10:30:00.000Z",
    "requestId": "req-987654321",
    "version": "1.0.0",
    "errorId": "err_1721382600_def456uvw"
  }
}
```

### Rate Limit Error Response

```json
{
  "success": false,
  "error": {
    "type": "https://api.example.com/problems/rate-limit-exceeded",
    "title": "Rate Limit Exceeded",
    "status": 429,
    "detail": "Rate limit exceeded. Try again in 60 seconds",
    "instance": "/todos",
    "retryAfter": 60,
    "limit": 100,
    "remaining": 0,
    "resetTime": "2025-07-19T11:00:00.000Z"
  },
  "meta": {
    "timestamp": "2025-07-19T10:30:00.000Z",
    "requestId": "req-555666777",
    "version": "1.0.0",
    "errorId": "err_1721382600_ghi789rst"
  }
}
```

### Internal Server Error Response

```json
{
  "success": false,
  "error": {
    "type": "https://api.example.com/problems/internal-error",
    "title": "Internal Server Error",
    "status": 500,
    "detail": "An unexpected error occurred while processing your request",
    "instance": "/todos/123",
    "errorId": "err_1721382600_jkl012mno"
  },
  "meta": {
    "timestamp": "2025-07-19T10:30:00.000Z",
    "requestId": "req-888999000",
    "version": "1.0.0",
    "errorId": "err_1721382600_jkl012mno"
  }
}
```

## 📱 Client Error Handling Guidelines

### TypeScript Client Error Handler

```typescript
// client/error-handler.ts
interface ApiErrorResponse {
  success: false;
  error: {
    type: string;
    title: string;
    status: number;
    detail?: string;
    instance?: string;
    [key: string]: any;
  };
  meta: {
    timestamp: string;
    requestId: string;
    version: string;
    errorId?: string;
  };
}

export class ApiErrorHandler {
  static handle(errorResponse: ApiErrorResponse): void {
    const { error } = errorResponse;
    
    switch (error.type) {
      case 'https://api.example.com/problems/validation-error':
        this.handleValidationError(error);
        break;
      case 'https://api.example.com/problems/not-found':
        this.handleNotFoundError(error);
        break;
      case 'https://api.example.com/problems/rate-limit-exceeded':
        this.handleRateLimitError(error);
        break;
      case 'https://api.example.com/problems/internal-error':
        this.handleInternalError(error, errorResponse.meta);
        break;
      default:
        this.handleGenericError(error);
    }
  }

  private static handleValidationError(error: any): void {
    const violations = error.violations || [];
    violations.forEach((violation: any) => {
      console.error(`Validation error in ${violation.field}: ${violation.message}`);
      // Show field-specific error in UI
      this.showFieldError(violation.field, violation.message);
    });
  }

  private static handleNotFoundError(error: any): void {
    console.error(`Resource not found: ${error.detail}`);
    // Redirect to 404 page or show not found message
    this.showNotFoundMessage(error.resourceType);
  }

  private static handleRateLimitError(error: any): void {
    console.warn(`Rate limit exceeded. Retry after: ${error.retryAfter}s`);
    // Show rate limit message and implement retry logic
    this.showRateLimitMessage(error.retryAfter);
  }

  private static handleInternalError(error: any, meta: any): void {
    console.error(`Internal server error. Error ID: ${meta.errorId}`);
    // Show generic error message and log error ID for support
    this.showInternalErrorMessage(meta.errorId);
  }

  private static handleGenericError(error: any): void {
    console.error(`API Error: ${error.title} - ${error.detail}`);
    // Show generic error message
    this.showGenericErrorMessage(error.title);
  }

  private static showFieldError(field: string, message: string): void {
    // Implementation depends on UI framework
  }

  private static showNotFoundMessage(resourceType: string): void {
    // Implementation depends on UI framework
  }

  private static showRateLimitMessage(retryAfter: number): void {
    // Implementation depends on UI framework
  }

  private static showInternalErrorMessage(errorId: string): void {
    // Implementation depends on UI framework
  }

  private static showGenericErrorMessage(title: string): void {
    // Implementation depends on UI framework
  }
}
```

## 🔗 Navigation

### Previous: [Implementation Examples](./implementation-examples.md)

### Next: [Migration Strategy](./migration-strategy.md)

---

## Related Documentation

- [Best Practices Guidelines](./best-practices-guidelines.md)
- [Testing Recommendations](./testing-recommendations.md)
- [Industry Standards Comparison](./industry-standards-comparison.md)

---

## 📚 References

- [RFC 7807 - Problem Details for HTTP APIs](https://tools.ietf.org/html/rfc7807)
- [MDN HTTP Status Codes](https://developer.mozilla.org/en-US/docs/Web/HTTP/Status)
- [Express.js Error Handling](https://expressjs.com/en/guide/error-handling.html)
- [class-validator Documentation](https://github.com/typestack/class-validator)

---

*Error Handling Patterns completed on July 19, 2025*  
*Based on RFC 7807 Problem Details standard and industry best practices*