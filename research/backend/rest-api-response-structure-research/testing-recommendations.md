# Testing Recommendations: API Response Structure

## 🎯 Overview

This document provides comprehensive testing strategies and recommendations for validating REST API response structures. It covers unit testing, integration testing, contract testing, and end-to-end testing approaches to ensure reliable and consistent API behavior.

## 📋 Table of Contents

1. [Testing Strategy Overview](#testing-strategy-overview)
2. [Unit Testing Patterns](#unit-testing-patterns)
3. [Integration Testing](#integration-testing)
4. [Contract Testing](#contract-testing)
5. [End-to-End Testing](#end-to-end-testing)
6. [Performance Testing](#performance-testing)
7. [Security Testing](#security-testing)
8. [Error Scenario Testing](#error-scenario-testing)
9. [Testing Tools and Setup](#testing-tools-and-setup)
10. [CI/CD Integration](#cicd-integration)

## 🎯 Testing Strategy Overview

### Testing Pyramid for API Responses

```
    🔺 E2E Tests (10%)
      📊 Contract Tests (20%)
        🏗️ Integration Tests (30%)
          🧱 Unit Tests (40%)
```

### Testing Dimensions

| Dimension | Coverage | Purpose |
|-----------|----------|---------|
| **Response Structure** | 100% | Validate schema compliance and field presence |
| **HTTP Status Codes** | 100% | Ensure correct status mapping for all scenarios |
| **Error Handling** | 100% | RFC 7807 compliance and error message accuracy |
| **Pagination** | 100% | Validate metadata and link generation |
| **HATEOAS Links** | 95% | Ensure navigation links are correct |
| **Performance** | 90% | Response time and payload size validation |
| **Security** | 100% | Authentication, authorization, and data leakage |

### Test Data Strategy

```typescript
// tests/fixtures/test-data.ts
export const TestDataBuilder = {
  todo: {
    valid: () => ({
      id: 'todo-123',
      title: 'Test Todo',
      description: 'Test Description',
      status: 'pending',
      priority: 'medium',
      createdAt: '2025-07-19T10:00:00.000Z',
      updatedAt: '2025-07-19T10:00:00.000Z'
    }),
    
    withStatus: (status: string) => ({
      ...TestDataBuilder.todo.valid(),
      status
    }),
    
    withoutRequired: (field: string) => {
      const todo = TestDataBuilder.todo.valid();
      delete (todo as any)[field];
      return todo;
    },
    
    invalid: () => ({
      id: '',
      title: '',
      description: null,
      status: 'invalid-status',
      priority: 'invalid-priority'
    })
  },
  
  pagination: {
    default: () => ({ page: 1, limit: 10 }),
    firstPage: () => ({ page: 1, limit: 5 }),
    middlePage: () => ({ page: 3, limit: 5 }),
    lastPage: (total: number, limit: number) => ({ 
      page: Math.ceil(total / limit), 
      limit 
    })
  },
  
  request: {
    withRequestId: (id: string = 'test-req-123') => ({
      headers: { 'x-request-id': id },
      originalUrl: '/todos'
    })
  }
};
```

## 🧱 Unit Testing Patterns

### Response Builder Testing

```typescript
// tests/unit/response-builder.test.ts
import { ResponseBuilder } from '../../src/utils/response-builder';
import { FeatureFlagService } from '../../src/config/feature-flags';
import { TestDataBuilder } from '../fixtures/test-data';

describe('ResponseBuilder', () => {
  let responseBuilder: ResponseBuilder;
  let featureFlags: FeatureFlagService;
  let mockRequest: any;

  beforeEach(() => {
    featureFlags = new FeatureFlagService();
    responseBuilder = new ResponseBuilder(featureFlags);
    mockRequest = TestDataBuilder.request.withRequestId();
  });

  describe('success responses', () => {
    it('should create standardized success response when feature flag enabled', () => {
      // Arrange
      featureFlags.setFlag('standardizedResponses', true);
      featureFlags.setFlag('responseMetadata', true);
      const todoData = TestDataBuilder.todo.valid();

      // Act
      const result = responseBuilder.success({
        data: todoData,
        req: mockRequest
      });

      // Assert
      expect(result).toMatchObject({
        success: true,
        data: todoData,
        meta: {
          timestamp: expect.stringMatching(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}.\d{3}Z$/),
          requestId: 'test-req-123',
          version: expect.any(String)
        }
      });
    });

    it('should return raw data when standardized responses disabled', () => {
      // Arrange
      featureFlags.setFlag('standardizedResponses', false);
      const todoData = TestDataBuilder.todo.valid();

      // Act
      const result = responseBuilder.success({
        data: todoData,
        req: mockRequest
      });

      // Assert
      expect(result).toEqual(todoData);
    });

    it('should include pagination metadata when provided', () => {
      // Arrange
      featureFlags.setFlag('standardizedResponses', true);
      featureFlags.setFlag('responseMetadata', true);
      const todos = [TestDataBuilder.todo.valid()];
      const paginationMeta = {
        page: 1,
        limit: 10,
        total: 25,
        totalPages: 3,
        hasNext: true,
        hasPrevious: false
      };

      // Act
      const result = responseBuilder.success({
        data: todos,
        meta: { pagination: paginationMeta },
        req: mockRequest
      });

      // Assert
      expect(result.meta.pagination).toEqual(paginationMeta);
    });

    it('should include HATEOAS links when provided', () => {
      // Arrange
      featureFlags.setFlag('standardizedResponses', true);
      featureFlags.setFlag('hateoasLinks', true);
      const todoData = TestDataBuilder.todo.valid();
      const links = {
        self: '/todos/todo-123',
        edit: '/todos/todo-123',
        delete: '/todos/todo-123',
        collection: '/todos'
      };

      // Act
      const result = responseBuilder.success({
        data: todoData,
        meta: { links },
        req: mockRequest
      });

      // Assert
      expect(result.meta.links).toEqual(links);
    });
  });

  describe('error responses', () => {
    it('should create RFC 7807 compliant validation error', () => {
      // Arrange
      const violations = [
        {
          field: 'title',
          message: 'Title is required',
          code: 'REQUIRED',
          rejectedValue: ''
        }
      ];

      // Act
      const result = responseBuilder.validationError({
        violations,
        req: mockRequest
      });

      // Assert
      expect(result.response).toMatchObject({
        success: false,
        error: {
          type: 'https://api.example.com/problems/validation-error',
          title: 'Validation Failed',
          status: 400,
          detail: expect.any(String),
          instance: '/todos',
          violations
        },
        meta: {
          timestamp: expect.any(String),
          requestId: 'test-req-123',
          version: expect.any(String)
        }
      });
    });

    it('should create not found error with resource context', () => {
      // Arrange
      const resourceType = 'Todo';
      const resourceId = 'nonexistent-id';

      // Act
      const result = responseBuilder.notFoundError({
        resourceType,
        resourceId,
        req: mockRequest
      });

      // Assert
      expect(result.response.error).toMatchObject({
        type: 'https://api.example.com/problems/not-found',
        title: 'Resource Not Found',
        status: 404,
        detail: `The requested ${resourceType} with ID '${resourceId}' was not found`,
        instance: '/todos',
        resourceType,
        resourceId
      });
    });
  });
});
```

### Error Handler Testing

```typescript
// tests/unit/error-handler.test.ts
import { HttpError } from '../../src/errors/http-error';
import { ValidationErrorMapper } from '../../src/utils/validation-error-mapper';
import { ERROR_TYPES } from '../../src/types/error-classification';

describe('HttpError', () => {
  describe('static factory methods', () => {
    it('should create validation error with violations', () => {
      // Arrange
      const violations = [
        {
          field: 'email',
          message: 'Invalid email format',
          code: 'INVALID_EMAIL',
          rejectedValue: 'invalid-email'
        }
      ];

      // Act
      const error = HttpError.validation({
        violations,
        instance: '/users',
        requestId: 'req-123'
      });

      // Assert
      expect(error.status).toBe(400);
      expect(error.code).toBe('VALIDATION_ERROR');
      expect(error.response.error.violations).toEqual(violations);
    });

    it('should create conflict error with business context', () => {
      // Arrange
      const resource = 'Todo';
      const conflictReason = 'Cannot modify completed todo';

      // Act
      const error = HttpError.conflict({
        resource,
        conflictReason,
        instance: '/todos/123',
        requestId: 'req-456'
      });

      // Assert
      expect(error.status).toBe(409);
      expect(error.response.error.resource).toBe(resource);
      expect(error.response.error.conflictReason).toBe(conflictReason);
    });

    it('should create rate limit error with retry information', () => {
      // Arrange
      const retryAfter = 60;
      const limit = 100;
      const remaining = 0;
      const resetTime = '2025-07-19T11:00:00.000Z';

      // Act
      const error = HttpError.rateLimit({
        retryAfter,
        limit,
        remaining,
        resetTime,
        instance: '/todos',
        requestId: 'req-789'
      });

      // Assert
      expect(error.status).toBe(429);
      expect(error.response.error.retryAfter).toBe(retryAfter);
      expect(error.response.error.limit).toBe(limit);
      expect(error.response.error.remaining).toBe(remaining);
      expect(error.response.error.resetTime).toBe(resetTime);
    });
  });
});

describe('ValidationErrorMapper', () => {
  it('should map class-validator errors to violations', () => {
    // Arrange
    const validationErrors = [
      {
        property: 'title',
        value: '',
        constraints: {
          isNotEmpty: 'title should not be empty',
          minLength: 'title must be longer than or equal to 3 characters'
        }
      },
      {
        property: 'email',
        value: 'invalid-email',
        constraints: {
          isEmail: 'email must be a valid email'
        }
      }
    ];

    // Act
    const httpError = ValidationErrorMapper.mapValidationErrors(
      validationErrors as any,
      '/users',
      'req-123'
    );

    // Assert
    expect(httpError.response.error.violations).toHaveLength(3);
    expect(httpError.response.error.violations).toContainEqual({
      field: 'title',
      message: 'title should not be empty',
      code: 'REQUIRED',
      rejectedValue: ''
    });
    expect(httpError.response.error.violations).toContainEqual({
      field: 'title',
      message: 'title must be longer than or equal to 3 characters',
      code: 'MIN_LENGTH',
      rejectedValue: ''
    });
    expect(httpError.response.error.violations).toContainEqual({
      field: 'email',
      message: 'email must be a valid email',
      code: 'INVALID_EMAIL',
      rejectedValue: 'invalid-email'
    });
  });
});
```

## 🏗️ Integration Testing

### Controller Integration Tests

```typescript
// tests/integration/todo-controller.test.ts
import request from 'supertest';
import { app } from '../../src/app';
import { TestDatabase } from '../helpers/test-database';
import { TestDataBuilder } from '../fixtures/test-data';

describe('TodoController Integration', () => {
  let testDb: TestDatabase;

  beforeAll(async () => {
    testDb = new TestDatabase();
    await testDb.setup();
  });

  afterAll(async () => {
    await testDb.cleanup();
  });

  beforeEach(async () => {
    await testDb.clearData();
  });

  describe('GET /todos', () => {
    it('should return standardized response with pagination', async () => {
      // Arrange
      const todos = await testDb.seedTodos(15);

      // Act
      const response = await request(app)
        .get('/todos?page=2&limit=5')
        .set('X-API-Version', 'v2')
        .expect(200);

      // Assert
      expect(response.body).toMatchObject({
        success: true,
        data: expect.arrayContaining([
          expect.objectContaining({
            id: expect.any(String),
            title: expect.any(String),
            status: expect.any(String)
          })
        ]),
        meta: {
          timestamp: expect.any(String),
          requestId: expect.any(String),
          version: expect.any(String),
          pagination: {
            page: 2,
            limit: 5,
            total: 15,
            totalPages: 3,
            hasNext: true,
            hasPrevious: true
          },
          links: {
            self: expect.stringContaining('page=2&limit=5'),
            first: expect.stringContaining('page=1&limit=5'),
            last: expect.stringContaining('page=3&limit=5'),
            next: expect.stringContaining('page=3&limit=5'),
            previous: expect.stringContaining('page=1&limit=5')
          }
        }
      });

      expect(response.body.data).toHaveLength(5);
    });

    it('should return empty array when no todos exist', async () => {
      // Act
      const response = await request(app)
        .get('/todos')
        .set('X-API-Version', 'v2')
        .expect(200);

      // Assert
      expect(response.body).toMatchObject({
        success: true,
        data: [],
        meta: {
          pagination: {
            page: 1,
            limit: 10,
            total: 0,
            totalPages: 0,
            hasNext: false,
            hasPrevious: false
          }
        }
      });
    });

    it('should handle invalid pagination parameters', async () => {
      // Act
      const response = await request(app)
        .get('/todos?page=0&limit=101')
        .set('X-API-Version', 'v2')
        .expect(400);

      // Assert
      expect(response.body).toMatchObject({
        success: false,
        error: {
          type: 'https://api.example.com/problems/validation-error',
          title: 'Validation Failed',
          status: 400,
          violations: expect.arrayContaining([
            expect.objectContaining({
              field: 'page',
              code: 'MIN_VALUE'
            }),
            expect.objectContaining({
              field: 'limit',
              code: 'MAX_VALUE'
            })
          ])
        }
      });
    });
  });

  describe('GET /todos/:id', () => {
    it('should return single todo with HATEOAS links', async () => {
      // Arrange
      const todo = await testDb.createTodo(TestDataBuilder.todo.valid());

      // Act
      const response = await request(app)
        .get(`/todos/${todo.id}`)
        .set('X-API-Version', 'v2')
        .expect(200);

      // Assert
      expect(response.body).toMatchObject({
        success: true,
        data: {
          id: todo.id,
          title: todo.title,
          description: todo.description,
          status: todo.status
        },
        meta: {
          timestamp: expect.any(String),
          requestId: expect.any(String),
          links: {
            self: `/todos/${todo.id}`,
            edit: `/todos/${todo.id}`,
            delete: `/todos/${todo.id}`,
            collection: '/todos'
          }
        }
      });
    });

    it('should return 404 for nonexistent todo', async () => {
      // Act
      const response = await request(app)
        .get('/todos/nonexistent-id')
        .set('X-API-Version', 'v2')
        .expect(404);

      // Assert
      expect(response.body).toMatchObject({
        success: false,
        error: {
          type: 'https://api.example.com/problems/not-found',
          title: 'Resource Not Found',
          status: 404,
          detail: expect.stringContaining('Todo'),
          instance: '/todos/nonexistent-id',
          resourceType: 'Todo',
          resourceId: 'nonexistent-id'
        }
      });
    });
  });

  describe('POST /todos', () => {
    it('should create todo and return 201 with location header', async () => {
      // Arrange
      const todoData = {
        title: 'New Todo',
        description: 'New Description',
        priority: 'high'
      };

      // Act
      const response = await request(app)
        .post('/todos')
        .send(todoData)
        .set('X-API-Version', 'v2')
        .expect(201);

      // Assert
      expect(response.body).toMatchObject({
        success: true,
        data: {
          id: expect.any(String),
          title: todoData.title,
          description: todoData.description,
          priority: todoData.priority,
          status: 'pending',
          createdAt: expect.any(String),
          updatedAt: expect.any(String)
        },
        meta: {
          timestamp: expect.any(String),
          requestId: expect.any(String),
          links: {
            self: expect.stringMatching(/^\/todos\/[\w-]+$/),
            edit: expect.stringMatching(/^\/todos\/[\w-]+$/),
            delete: expect.stringMatching(/^\/todos\/[\w-]+$/),
            collection: '/todos'
          }
        }
      });

      expect(response.headers.location).toBe(`/todos/${response.body.data.id}`);
    });

    it('should return validation error for invalid data', async () => {
      // Arrange
      const invalidData = {
        title: '', // Required field empty
        description: null, // Invalid type
        priority: 'invalid-priority' // Invalid enum value
      };

      // Act
      const response = await request(app)
        .post('/todos')
        .send(invalidData)
        .set('X-API-Version', 'v2')
        .expect(400);

      // Assert
      expect(response.body).toMatchObject({
        success: false,
        error: {
          type: 'https://api.example.com/problems/validation-error',
          title: 'Validation Failed',
          status: 400,
          violations: expect.arrayContaining([
            expect.objectContaining({
              field: 'title',
              code: 'REQUIRED'
            }),
            expect.objectContaining({
              field: 'priority',
              code: 'INVALID_CHOICE'
            })
          ])
        }
      });
    });

    it('should return conflict error for duplicate title', async () => {
      // Arrange
      const existingTodo = await testDb.createTodo(TestDataBuilder.todo.valid());
      const duplicateData = {
        title: existingTodo.title,
        description: 'Different description'
      };

      // Act
      const response = await request(app)
        .post('/todos')
        .send(duplicateData)
        .set('X-API-Version', 'v2')
        .expect(409);

      // Assert
      expect(response.body).toMatchObject({
        success: false,
        error: {
          type: 'https://api.example.com/problems/conflict',
          title: 'Resource Conflict',
          status: 409,
          detail: expect.stringContaining(existingTodo.title),
          resource: 'Todo',
          conflictReason: expect.stringContaining('already exists')
        }
      });
    });
  });

  describe('PUT /todos/:id', () => {
    it('should update todo and return updated data', async () => {
      // Arrange
      const todo = await testDb.createTodo(TestDataBuilder.todo.valid());
      const updateData = {
        title: 'Updated Title',
        description: 'Updated Description',
        status: 'in-progress'
      };

      // Act
      const response = await request(app)
        .put(`/todos/${todo.id}`)
        .send(updateData)
        .set('X-API-Version', 'v2')
        .expect(200);

      // Assert
      expect(response.body).toMatchObject({
        success: true,
        data: {
          id: todo.id,
          title: updateData.title,
          description: updateData.description,
          status: updateData.status,
          updatedAt: expect.any(String)
        }
      });

      // Verify the updated timestamp is more recent
      expect(new Date(response.body.data.updatedAt).getTime())
        .toBeGreaterThan(new Date(todo.updatedAt).getTime());
    });

    it('should return conflict error for invalid status transition', async () => {
      // Arrange
      const completedTodo = await testDb.createTodo(
        TestDataBuilder.todo.withStatus('completed')
      );
      const updateData = { status: 'pending' };

      // Act
      const response = await request(app)
        .put(`/todos/${completedTodo.id}`)
        .send(updateData)
        .set('X-API-Version', 'v2')
        .expect(409);

      // Assert
      expect(response.body.error).toMatchObject({
        type: 'https://api.example.com/problems/conflict',
        title: 'Resource Conflict',
        status: 409,
        resource: 'Todo',
        conflictReason: expect.stringContaining('Cannot transition from \'completed\' to \'pending\'')
      });
    });
  });

  describe('DELETE /todos/:id', () => {
    it('should delete todo and return 204 No Content', async () => {
      // Arrange
      const todo = await testDb.createTodo(TestDataBuilder.todo.valid());

      // Act
      const response = await request(app)
        .delete(`/todos/${todo.id}`)
        .set('X-API-Version', 'v2')
        .expect(204);

      // Assert
      expect(response.body).toEqual({});

      // Verify todo is deleted
      const verifyResponse = await request(app)
        .get(`/todos/${todo.id}`)
        .expect(404);
    });

    it('should return 404 for nonexistent todo deletion', async () => {
      // Act
      const response = await request(app)
        .delete('/todos/nonexistent-id')
        .set('X-API-Version', 'v2')
        .expect(404);

      // Assert
      expect(response.body.error).toMatchObject({
        type: 'https://api.example.com/problems/not-found',
        resourceType: 'Todo',
        resourceId: 'nonexistent-id'
      });
    });
  });
});
```

## 📋 Contract Testing

### OpenAPI Schema Validation

```typescript
// tests/contract/openapi-validation.test.ts
import request from 'supertest';
import { app } from '../../src/app';
import OpenAPIResponseValidator from 'openapi-response-validator';
import { openApiSpec } from '../../src/config/openapi-spec';

describe('OpenAPI Contract Validation', () => {
  let validator: OpenAPIResponseValidator;

  beforeAll(() => {
    validator = new OpenAPIResponseValidator(openApiSpec);
  });

  describe('Todo endpoints', () => {
    it('should validate GET /todos response schema', async () => {
      // Act
      const response = await request(app)
        .get('/todos')
        .expect(200);

      // Assert
      const validation = validator.validateResponse('get', '/todos', {
        status: response.status,
        body: response.body
      });

      expect(validation.errors).toEqual([]);
    });

    it('should validate POST /todos response schema', async () => {
      // Arrange
      const todoData = {
        title: 'Test Todo',
        description: 'Test Description'
      };

      // Act
      const response = await request(app)
        .post('/todos')
        .send(todoData)
        .expect(201);

      // Assert
      const validation = validator.validateResponse('post', '/todos', {
        status: response.status,
        body: response.body
      });

      expect(validation.errors).toEqual([]);
    });

    it('should validate error response schemas', async () => {
      // Act
      const response = await request(app)
        .get('/todos/nonexistent-id')
        .expect(404);

      // Assert
      const validation = validator.validateResponse('get', '/todos/{id}', {
        status: response.status,
        body: response.body
      });

      expect(validation.errors).toEqual([]);
    });
  });
});
```

### Pact Contract Testing

```typescript
// tests/contract/todo-api.pact.test.ts
import { Pact } from '@pact-foundation/pact';
import { TodoApiClient } from '../../src/clients/todo-api-client';

describe('Todo API Pact', () => {
  const provider = new Pact({
    consumer: 'TodoClient',
    provider: 'TodoAPI',
    port: 3001
  });

  beforeAll(() => provider.setup());
  afterEach(() => provider.verify());
  afterAll(() => provider.finalize());

  describe('GET /todos', () => {
    it('should return todo list with standardized response', async () => {
      // Arrange
      await provider
        .given('todos exist')
        .uponReceiving('a request for all todos')
        .withRequest({
          method: 'GET',
          path: '/todos',
          headers: {
            'X-API-Version': 'v2'
          }
        })
        .willRespondWith({
          status: 200,
          headers: {
            'Content-Type': 'application/json'
          },
          body: {
            success: true,
            data: [
              {
                id: 'todo-1',
                title: 'Test Todo',
                description: 'Test Description',
                status: 'pending',
                priority: 'medium',
                createdAt: '2025-07-19T10:00:00.000Z',
                updatedAt: '2025-07-19T10:00:00.000Z'
              }
            ],
            meta: {
              timestamp: '2025-07-19T10:00:00.000Z',
              requestId: 'req-123',
              version: '1.0.0',
              pagination: {
                page: 1,
                limit: 10,
                total: 1,
                totalPages: 1,
                hasNext: false,
                hasPrevious: false
              },
              links: {
                self: '/todos?page=1&limit=10',
                first: '/todos?page=1&limit=10',
                last: '/todos?page=1&limit=10'
              }
            }
          }
        });

      // Act
      const client = new TodoApiClient('http://localhost:3001');
      const response = await client.getAllTodos();

      // Assert
      expect(response.success).toBe(true);
      expect(response.data).toHaveLength(1);
      expect(response.meta.pagination.total).toBe(1);
    });
  });

  describe('POST /todos', () => {
    it('should create todo and return standardized response', async () => {
      // Arrange
      const todoData = {
        title: 'New Todo',
        description: 'New Description',
        priority: 'high'
      };

      await provider
        .given('I am authenticated')
        .uponReceiving('a request to create a todo')
        .withRequest({
          method: 'POST',
          path: '/todos',
          headers: {
            'Content-Type': 'application/json',
            'X-API-Version': 'v2'
          },
          body: todoData
        })
        .willRespondWith({
          status: 201,
          headers: {
            'Content-Type': 'application/json',
            'Location': '/todos/new-todo-id'
          },
          body: {
            success: true,
            data: {
              id: 'new-todo-id',
              ...todoData,
              status: 'pending',
              createdAt: '2025-07-19T10:00:00.000Z',
              updatedAt: '2025-07-19T10:00:00.000Z'
            },
            meta: {
              timestamp: '2025-07-19T10:00:00.000Z',
              requestId: 'req-456',
              version: '1.0.0',
              links: {
                self: '/todos/new-todo-id',
                edit: '/todos/new-todo-id',
                delete: '/todos/new-todo-id',
                collection: '/todos'
              }
            }
          }
        });

      // Act
      const client = new TodoApiClient('http://localhost:3001');
      const response = await client.createTodo(todoData);

      // Assert
      expect(response.success).toBe(true);
      expect(response.data.id).toBe('new-todo-id');
      expect(response.meta.links.self).toBe('/todos/new-todo-id');
    });
  });
});
```

## 🚀 End-to-End Testing

### Playwright E2E Tests

```typescript
// tests/e2e/todo-api.e2e.test.ts
import { test, expect } from '@playwright/test';

test.describe('Todo API E2E', () => {
  const baseURL = process.env.API_BASE_URL || 'http://localhost:3000';

  test('complete todo workflow', async ({ request }) => {
    // 1. Create a new todo
    const createResponse = await request.post(`${baseURL}/todos`, {
      data: {
        title: 'E2E Test Todo',
        description: 'Testing complete workflow',
        priority: 'high'
      },
      headers: {
        'X-API-Version': 'v2'
      }
    });

    expect(createResponse.status()).toBe(201);
    const createBody = await createResponse.json();
    expect(createBody.success).toBe(true);
    expect(createBody.data.id).toBeDefined();
    
    const todoId = createBody.data.id;

    // 2. Retrieve the created todo
    const getResponse = await request.get(`${baseURL}/todos/${todoId}`, {
      headers: {
        'X-API-Version': 'v2'
      }
    });

    expect(getResponse.status()).toBe(200);
    const getBody = await getResponse.json();
    expect(getBody.success).toBe(true);
    expect(getBody.data.title).toBe('E2E Test Todo');
    expect(getBody.meta.links.self).toBe(`/todos/${todoId}`);

    // 3. Update the todo status
    const updateResponse = await request.put(`${baseURL}/todos/${todoId}`, {
      data: {
        status: 'in-progress'
      },
      headers: {
        'X-API-Version': 'v2'
      }
    });

    expect(updateResponse.status()).toBe(200);
    const updateBody = await updateResponse.json();
    expect(updateBody.data.status).toBe('in-progress');

    // 4. List todos and verify it appears
    const listResponse = await request.get(`${baseURL}/todos`, {
      headers: {
        'X-API-Version': 'v2'
      }
    });

    expect(listResponse.status()).toBe(200);
    const listBody = await listResponse.json();
    expect(listBody.success).toBe(true);
    expect(listBody.data.some((todo: any) => todo.id === todoId)).toBe(true);
    expect(listBody.meta.pagination).toBeDefined();

    // 5. Delete the todo
    const deleteResponse = await request.delete(`${baseURL}/todos/${todoId}`, {
      headers: {
        'X-API-Version': 'v2'
      }
    });

    expect(deleteResponse.status()).toBe(204);

    // 6. Verify todo is deleted
    const verifyDeleteResponse = await request.get(`${baseURL}/todos/${todoId}`, {
      headers: {
        'X-API-Version': 'v2'
      }
    });

    expect(verifyDeleteResponse.status()).toBe(404);
    const errorBody = await verifyDeleteResponse.json();
    expect(errorBody.success).toBe(false);
    expect(errorBody.error.type).toContain('not-found');
  });

  test('pagination workflow', async ({ request }) => {
    // Create multiple todos for pagination testing
    const todoPromises = Array.from({ length: 25 }, (_, i) =>
      request.post(`${baseURL}/todos`, {
        data: {
          title: `Pagination Test Todo ${i + 1}`,
          description: `Description ${i + 1}`
        },
        headers: {
          'X-API-Version': 'v2'
        }
      })
    );

    await Promise.all(todoPromises);

    // Test first page
    const firstPageResponse = await request.get(`${baseURL}/todos?page=1&limit=10`, {
      headers: {
        'X-API-Version': 'v2'
      }
    });

    expect(firstPageResponse.status()).toBe(200);
    const firstPageBody = await firstPageResponse.json();
    expect(firstPageBody.data).toHaveLength(10);
    expect(firstPageBody.meta.pagination.page).toBe(1);
    expect(firstPageBody.meta.pagination.total).toBeGreaterThanOrEqual(25);
    expect(firstPageBody.meta.pagination.hasNext).toBe(true);
    expect(firstPageBody.meta.pagination.hasPrevious).toBe(false);

    // Test middle page
    const middlePageResponse = await request.get(`${baseURL}/todos?page=2&limit=10`, {
      headers: {
        'X-API-Version': 'v2'
      }
    });

    expect(middlePageResponse.status()).toBe(200);
    const middlePageBody = await middlePageResponse.json();
    expect(middlePageBody.data).toHaveLength(10);
    expect(middlePageBody.meta.pagination.page).toBe(2);
    expect(middlePageBody.meta.pagination.hasNext).toBe(true);
    expect(middlePageBody.meta.pagination.hasPrevious).toBe(true);

    // Verify HATEOAS links
    expect(middlePageBody.meta.links.self).toContain('page=2&limit=10');
    expect(middlePageBody.meta.links.first).toContain('page=1&limit=10');
    expect(middlePageBody.meta.links.next).toContain('page=3&limit=10');
    expect(middlePageBody.meta.links.previous).toContain('page=1&limit=10');
  });

  test('error handling workflow', async ({ request }) => {
    // Test validation error
    const validationErrorResponse = await request.post(`${baseURL}/todos`, {
      data: {
        title: '', // Invalid empty title
        priority: 'invalid-priority' // Invalid enum
      },
      headers: {
        'X-API-Version': 'v2'
      }
    });

    expect(validationErrorResponse.status()).toBe(400);
    const validationErrorBody = await validationErrorResponse.json();
    expect(validationErrorBody.success).toBe(false);
    expect(validationErrorBody.error.type).toContain('validation-error');
    expect(validationErrorBody.error.violations).toBeInstanceOf(Array);
    expect(validationErrorBody.error.violations.length).toBeGreaterThan(0);

    // Test not found error
    const notFoundResponse = await request.get(`${baseURL}/todos/nonexistent-id`, {
      headers: {
        'X-API-Version': 'v2'
      }
    });

    expect(notFoundResponse.status()).toBe(404);
    const notFoundBody = await notFoundResponse.json();
    expect(notFoundBody.success).toBe(false);
    expect(notFoundBody.error.type).toContain('not-found');
    expect(notFoundBody.error.resourceType).toBe('Todo');
    expect(notFoundBody.error.resourceId).toBe('nonexistent-id');
  });
});
```

## ⚡ Performance Testing

### K6 Load Testing

```typescript
// tests/performance/load-test.js
import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate } from 'k6/metrics';

// Custom metrics
const errorRate = new Rate('errors');

export let options = {
  stages: [
    { duration: '2m', target: 100 }, // Ramp up to 100 users
    { duration: '5m', target: 100 }, // Stay at 100 users
    { duration: '2m', target: 200 }, // Ramp up to 200 users
    { duration: '5m', target: 200 }, // Stay at 200 users
    { duration: '2m', target: 0 },   // Ramp down to 0 users
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'], // 95% of requests must complete below 500ms
    http_req_failed: ['rate<0.01'],   // Error rate must be below 1%
    errors: ['rate<0.01'],            // Custom error rate threshold
  },
};

const BASE_URL = 'http://localhost:3000';

export default function() {
  // Test GET /todos with pagination
  const listResponse = http.get(`${BASE_URL}/todos?page=1&limit=10`, {
    headers: {
      'X-API-Version': 'v2',
    },
  });

  check(listResponse, {
    'GET /todos status is 200': (r) => r.status === 200,
    'GET /todos response time < 200ms': (r) => r.timings.duration < 200,
    'GET /todos has success field': (r) => {
      try {
        const body = JSON.parse(r.body);
        return body.success === true;
      } catch (e) {
        return false;
      }
    },
    'GET /todos has pagination metadata': (r) => {
      try {
        const body = JSON.parse(r.body);
        return body.meta && body.meta.pagination;
      } catch (e) {
        return false;
      }
    },
  }) || errorRate.add(1);

  // Test POST /todos
  const createPayload = JSON.stringify({
    title: `Load Test Todo ${Math.random()}`,
    description: 'Created during load test',
    priority: 'medium'
  });

  const createResponse = http.post(`${BASE_URL}/todos`, createPayload, {
    headers: {
      'Content-Type': 'application/json',
      'X-API-Version': 'v2',
    },
  });

  check(createResponse, {
    'POST /todos status is 201': (r) => r.status === 201,
    'POST /todos response time < 300ms': (r) => r.timings.duration < 300,
    'POST /todos returns created todo': (r) => {
      try {
        const body = JSON.parse(r.body);
        return body.success === true && body.data && body.data.id;
      } catch (e) {
        return false;
      }
    },
    'POST /todos has HATEOAS links': (r) => {
      try {
        const body = JSON.parse(r.body);
        return body.meta && body.meta.links && body.meta.links.self;
      } catch (e) {
        return false;
      }
    },
  }) || errorRate.add(1);

  // Extract todo ID for further operations
  let todoId;
  try {
    const createBody = JSON.parse(createResponse.body);
    todoId = createBody.data && createBody.data.id;
  } catch (e) {
    // Handle parse error
  }

  if (todoId) {
    // Test GET /todos/:id
    const getResponse = http.get(`${BASE_URL}/todos/${todoId}`, {
      headers: {
        'X-API-Version': 'v2',
      },
    });

    check(getResponse, {
      'GET /todos/:id status is 200': (r) => r.status === 200,
      'GET /todos/:id response time < 150ms': (r) => r.timings.duration < 150,
      'GET /todos/:id returns correct todo': (r) => {
        try {
          const body = JSON.parse(r.body);
          return body.success === true && body.data && body.data.id === todoId;
        } catch (e) {
          return false;
        }
      },
    }) || errorRate.add(1);

    // Test PUT /todos/:id
    const updatePayload = JSON.stringify({
      status: 'in-progress'
    });

    const updateResponse = http.put(`${BASE_URL}/todos/${todoId}`, updatePayload, {
      headers: {
        'Content-Type': 'application/json',
        'X-API-Version': 'v2',
      },
    });

    check(updateResponse, {
      'PUT /todos/:id status is 200': (r) => r.status === 200,
      'PUT /todos/:id response time < 250ms': (r) => r.timings.duration < 250,
      'PUT /todos/:id updates status': (r) => {
        try {
          const body = JSON.parse(r.body);
          return body.success === true && body.data && body.data.status === 'in-progress';
        } catch (e) {
          return false;
        }
      },
    }) || errorRate.add(1);
  }

  sleep(1);
}

// Test error scenarios
export function teardown() {
  // Test 404 error response
  const notFoundResponse = http.get(`${BASE_URL}/todos/nonexistent-id`, {
    headers: {
      'X-API-Version': 'v2',
    },
  });

  check(notFoundResponse, {
    '404 error has correct structure': (r) => {
      if (r.status !== 404) return false;
      try {
        const body = JSON.parse(r.body);
        return body.success === false && 
               body.error && 
               body.error.type && 
               body.error.type.includes('not-found');
      } catch (e) {
        return false;
      }
    },
  });

  // Test validation error response
  const validationErrorResponse = http.post(`${BASE_URL}/todos`, 
    JSON.stringify({ title: '' }), {
    headers: {
      'Content-Type': 'application/json',
      'X-API-Version': 'v2',
    },
  });

  check(validationErrorResponse, {
    'Validation error has correct structure': (r) => {
      if (r.status !== 400) return false;
      try {
        const body = JSON.parse(r.body);
        return body.success === false && 
               body.error && 
               body.error.violations && 
               Array.isArray(body.error.violations);
      } catch (e) {
        return false;
      }
    },
  });
}
```

## 🔐 Security Testing

### Security Test Suite

```typescript
// tests/security/api-security.test.ts
import request from 'supertest';
import { app } from '../../src/app';

describe('API Security', () => {
  describe('Input Validation Security', () => {
    it('should prevent SQL injection in query parameters', async () => {
      const maliciousQuery = "'; DROP TABLE todos; --";
      
      const response = await request(app)
        .get(`/todos?title=${encodeURIComponent(maliciousQuery)}`)
        .expect(400);

      expect(response.body.error.type).toContain('validation-error');
    });

    it('should prevent XSS in response data', async () => {
      const xssPayload = '<script>alert("xss")</script>';
      
      const response = await request(app)
        .post('/todos')
        .send({
          title: xssPayload,
          description: 'Test'
        })
        .expect(400);

      expect(response.body.error.violations).toContainEqual(
        expect.objectContaining({
          field: 'title',
          code: 'INVALID_FORMAT'
        })
      );
    });

    it('should prevent NoSQL injection', async () => {
      const noSqlInjection = { $ne: null };
      
      const response = await request(app)
        .post('/todos')
        .send({
          title: noSqlInjection,
          description: 'Test'
        })
        .expect(400);

      expect(response.body.error.type).toContain('validation-error');
    });
  });

  describe('Error Information Disclosure', () => {
    it('should not expose sensitive error details in production', async () => {
      // Set production environment
      const originalEnv = process.env.NODE_ENV;
      process.env.NODE_ENV = 'production';

      try {
        // Trigger an internal error
        const response = await request(app)
          .get('/todos/trigger-error')
          .expect(500);

        expect(response.body.error.detail).not.toContain('stack trace');
        expect(response.body.error.detail).not.toContain('file path');
        expect(response.body.error.detail).not.toContain('database');
      } finally {
        process.env.NODE_ENV = originalEnv;
      }
    });

    it('should include error ID for debugging without exposing details', async () => {
      const response = await request(app)
        .get('/todos/trigger-error')
        .expect(500);

      expect(response.body.error.type).toContain('internal-error');
      expect(response.body.meta.errorId).toMatch(/^err_\d+_[a-zA-Z0-9]+$/);
    });
  });

  describe('Rate Limiting', () => {
    it('should enforce rate limits and return proper error structure', async () => {
      // Make multiple rapid requests to trigger rate limiting
      const requests = Array.from({ length: 50 }, () =>
        request(app).get('/todos')
      );

      const responses = await Promise.all(requests);
      const rateLimitedResponse = responses.find(r => r.status === 429);

      if (rateLimitedResponse) {
        expect(rateLimitedResponse.body).toMatchObject({
          success: false,
          error: {
            type: expect.stringContaining('rate-limit'),
            title: 'Rate Limit Exceeded',
            status: 429,
            retryAfter: expect.any(Number)
          }
        });
      }
    });
  });

  describe('Response Headers Security', () => {
    it('should include security headers', async () => {
      const response = await request(app)
        .get('/todos')
        .expect(200);

      expect(response.headers['x-content-type-options']).toBe('nosniff');
      expect(response.headers['x-frame-options']).toBe('DENY');
      expect(response.headers['x-xss-protection']).toBe('1; mode=block');
    });

    it('should not expose sensitive server information', async () => {
      const response = await request(app)
        .get('/todos')
        .expect(200);

      expect(response.headers['server']).toBeUndefined();
      expect(response.headers['x-powered-by']).toBeUndefined();
    });
  });
});
```

## 🛠️ Testing Tools and Setup

### Test Configuration

```typescript
// jest.config.js
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  roots: ['<rootDir>/src', '<rootDir>/tests'],
  testMatch: [
    '**/__tests__/**/*.ts',
    '**/?(*.)+(spec|test).ts'
  ],
  transform: {
    '^.+\\.ts$': 'ts-jest',
  },
  collectCoverageFrom: [
    'src/**/*.ts',
    '!src/**/*.d.ts',
    '!src/index.ts',
    '!src/**/__tests__/**',
  ],
  coverageThreshold: {
    global: {
      branches: 80,
      functions: 80,
      lines: 80,
      statements: 80,
    },
  },
  setupFilesAfterEnv: ['<rootDir>/tests/setup.ts'],
  testTimeout: 30000,
};
```

### Test Database Helper

```typescript
// tests/helpers/test-database.ts
import { Pool } from 'pg';
import { TodoEntity } from '../../src/entities/todo.entity';

export class TestDatabase {
  private pool: Pool;

  constructor() {
    this.pool = new Pool({
      connectionString: process.env.TEST_DATABASE_URL,
      max: 10
    });
  }

  async setup(): Promise<void> {
    await this.pool.query(`
      CREATE TABLE IF NOT EXISTS todos (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        title VARCHAR(255) NOT NULL,
        description TEXT,
        status VARCHAR(50) DEFAULT 'pending',
        priority VARCHAR(50) DEFAULT 'medium',
        created_at TIMESTAMP DEFAULT NOW(),
        updated_at TIMESTAMP DEFAULT NOW()
      )
    `);
  }

  async cleanup(): Promise<void> {
    await this.pool.query('DROP TABLE IF EXISTS todos');
    await this.pool.end();
  }

  async clearData(): Promise<void> {
    await this.pool.query('DELETE FROM todos');
  }

  async createTodo(todoData: Partial<TodoEntity>): Promise<TodoEntity> {
    const query = `
      INSERT INTO todos (title, description, status, priority)
      VALUES ($1, $2, $3, $4)
      RETURNING *
    `;
    
    const values = [
      todoData.title,
      todoData.description,
      todoData.status || 'pending',
      todoData.priority || 'medium'
    ];

    const result = await this.pool.query(query, values);
    return result.rows[0];
  }

  async seedTodos(count: number): Promise<TodoEntity[]> {
    const todos: TodoEntity[] = [];
    
    for (let i = 0; i < count; i++) {
      const todo = await this.createTodo({
        title: `Test Todo ${i + 1}`,
        description: `Description for todo ${i + 1}`,
        status: i % 3 === 0 ? 'completed' : i % 2 === 0 ? 'in-progress' : 'pending',
        priority: ['low', 'medium', 'high'][i % 3]
      });
      todos.push(todo);
    }

    return todos;
  }
}
```

## 🔄 CI/CD Integration

### GitHub Actions Workflow

```yaml
# .github/workflows/api-testing.yml
name: API Testing

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  unit-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'
          cache: 'npm'
      
      - name: Install dependencies
        run: npm ci
      
      - name: Run unit tests
        run: npm run test:unit
        env:
          NODE_ENV: test
      
      - name: Upload coverage to Codecov
        uses: codecov/codecov-action@v3
        with:
          file: ./coverage/lcov.info

  integration-tests:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:14
        env:
          POSTGRES_PASSWORD: test
          POSTGRES_DB: todo_test
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 5432:5432

    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'
          cache: 'npm'
      
      - name: Install dependencies
        run: npm ci
      
      - name: Run integration tests
        run: npm run test:integration
        env:
          NODE_ENV: test
          TEST_DATABASE_URL: postgresql://postgres:test@localhost:5432/todo_test

  contract-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'
          cache: 'npm'
      
      - name: Install dependencies
        run: npm ci
      
      - name: Run contract tests
        run: npm run test:contract
      
      - name: Publish Pact contracts
        run: npm run pact:publish
        env:
          PACT_BROKER_BASE_URL: ${{ secrets.PACT_BROKER_URL }}
          PACT_BROKER_TOKEN: ${{ secrets.PACT_BROKER_TOKEN }}

  e2e-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'
          cache: 'npm'
      
      - name: Install dependencies
        run: npm ci
      
      - name: Install Playwright
        run: npx playwright install
      
      - name: Start API server
        run: npm run start:test &
        env:
          NODE_ENV: test
      
      - name: Wait for server
        run: npx wait-on http://localhost:3000/health
      
      - name: Run E2E tests
        run: npm run test:e2e

  performance-tests:
    runs-on: ubuntu-latest
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'
          cache: 'npm'
      
      - name: Install dependencies
        run: npm ci
      
      - name: Install k6
        run: |
          sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys C5AD17C747E3415A3642D57D77C6C491D6AC1D69
          echo "deb https://dl.k6.io/deb stable main" | sudo tee /etc/apt/sources.list.d/k6.list
          sudo apt-get update
          sudo apt-get install k6
      
      - name: Start API server
        run: npm run start:test &
        env:
          NODE_ENV: test
      
      - name: Wait for server
        run: npx wait-on http://localhost:3000/health
      
      - name: Run performance tests
        run: k6 run tests/performance/load-test.js
      
      - name: Upload performance results
        uses: actions/upload-artifact@v3
        with:
          name: performance-results
          path: performance-results.json
```

### Test Scripts in package.json

```json
{
  "scripts": {
    "test": "jest",
    "test:unit": "jest --testPathPattern=tests/unit",
    "test:integration": "jest --testPathPattern=tests/integration",
    "test:contract": "jest --testPathPattern=tests/contract && npm run pact:verify",
    "test:e2e": "playwright test tests/e2e",
    "test:performance": "k6 run tests/performance/load-test.js",
    "test:security": "jest --testPathPattern=tests/security",
    "test:coverage": "jest --coverage",
    "test:watch": "jest --watch",
    "pact:verify": "pact-broker verify --provider TodoAPI",
    "pact:publish": "pact-broker publish pacts --provider-version $npm_package_version"
  }
}
```

## 🔗 Navigation

### Previous: [Migration Strategy](./migration-strategy.md)

### Next: [Research Overview](./README.md)

---

## Related Documentation

- [Implementation Examples](./implementation-examples.md)
- [Error Handling Patterns](./error-handling-patterns.md)
- [Best Practices Guidelines](./best-practices-guidelines.md)

---

## 📚 References

- [Jest Testing Framework](https://jestjs.io/)
- [Supertest HTTP Testing](https://github.com/visionmedia/supertest)
- [Playwright E2E Testing](https://playwright.dev/)
- [K6 Performance Testing](https://k6.io/)
- [Pact Contract Testing](https://docs.pact.io/)
- [OpenAPI Response Validator](https://github.com/kogosoftwarellc/open-api/tree/master/packages/openapi-response-validator)

---

*Testing Recommendations completed on July 19, 2025*  
*Comprehensive testing strategy for API response structure validation*