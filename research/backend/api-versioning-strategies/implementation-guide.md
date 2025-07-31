# Implementation Guide - API Versioning Strategies

## 🚀 Getting Started

This guide provides step-by-step instructions for implementing API versioning strategies, from basic setup to advanced patterns. Each section includes working code examples and configuration templates.

## 📋 Prerequisites

### Required Knowledge
- REST API design principles
- HTTP headers and status codes
- Basic understanding of semantic versioning (SemVer)
- Experience with Node.js/Express.js or similar frameworks

### Technology Stack
- **Backend**: Node.js with Express.js or Fastify
- **Documentation**: OpenAPI/Swagger specifications
- **Testing**: Jest, Supertest, and Pact for contract testing
- **Monitoring**: API analytics and version tracking tools

## 🏗️ Implementation Strategies

### Strategy 1: Header-Based Versioning (Recommended)

Header-based versioning provides the best balance of flexibility and backward compatibility.

#### Step 1: Setup Version Middleware

```javascript
// middleware/apiVersion.js
const supportedVersions = ['1.0', '1.1', '2.0'];
const defaultVersion = '2.0';

const apiVersionMiddleware = (req, res, next) => {
  // Check for Accept-Version header
  let requestedVersion = req.headers['accept-version'] || req.headers['api-version'];
  
  // Fallback to query parameter for testing
  if (!requestedVersion && req.query.version) {
    requestedVersion = req.query.version;
  }
  
  // Default to latest version
  if (!requestedVersion) {
    requestedVersion = defaultVersion;
  }
  
  // Validate version format
  if (!supportedVersions.includes(requestedVersion)) {
    return res.status(400).json({
      error: 'Unsupported API version',
      supported_versions: supportedVersions,
      requested_version: requestedVersion
    });
  }
  
  // Add version to request object
  req.apiVersion = requestedVersion;
  
  // Add version headers to response
  res.set('API-Version', requestedVersion);
  res.set('Supported-Versions', supportedVersions.join(', '));
  
  next();
};

module.exports = apiVersionMiddleware;
```

#### Step 2: Version-Aware Route Handling

```javascript
// routes/users.js
const express = require('express');
const router = express.Router();
const { getUsersV1, getUsersV2 } = require('../controllers/userController');

router.get('/users', (req, res, next) => {
  switch (req.apiVersion) {
    case '1.0':
    case '1.1':
      return getUsersV1(req, res, next);
    case '2.0':
      return getUsersV2(req, res, next);
    default:
      return res.status(400).json({ error: 'Unsupported version' });
  }
});

module.exports = router;
```

#### Step 3: Version-Specific Controllers

```javascript
// controllers/userController.js
const getUsersV1 = async (req, res) => {
  try {
    const users = await User.findAll();
    
    // V1 response format - simple structure
    const v1Response = users.map(user => ({
      id: user.id,
      name: user.name,
      email: user.email,
      created_at: user.createdAt
    }));
    
    res.json(v1Response);
  } catch (error) {
    res.status(500).json({ error: 'Internal server error' });
  }
};

const getUsersV2 = async (req, res) => {
  try {
    const users = await User.findAll();
    
    // V2 response format - enhanced structure with metadata
    const v2Response = {
      data: users.map(user => ({
        id: user.id,
        attributes: {
          name: user.name,
          email: user.email,
          profile: {
            avatar_url: user.avatarUrl,
            bio: user.bio,
            location: user.location
          }
        },
        timestamps: {
          created_at: user.createdAt,
          updated_at: user.updatedAt
        }
      })),
      meta: {
        total_count: users.length,
        api_version: '2.0',
        generated_at: new Date().toISOString()
      }
    };
    
    res.json(v2Response);
  } catch (error) {
    res.status(500).json({ 
      error: { 
        code: 'INTERNAL_ERROR',
        message: 'Internal server error',
        api_version: '2.0'
      } 
    });
  }
};

module.exports = { getUsersV1, getUsersV2 };
```

### Strategy 2: URI-Based Versioning

URI versioning is straightforward and widely understood, making it ideal for public APIs.

#### Step 1: Route Organization

```javascript
// app.js
const express = require('express');
const app = express();

// Import version-specific routes
const v1Routes = require('./routes/v1');
const v2Routes = require('./routes/v2');

// Mount versioned routes
app.use('/api/v1', v1Routes);
app.use('/api/v2', v2Routes);

// Default to latest version
app.use('/api', v2Routes);

module.exports = app;
```

#### Step 2: Version-Specific Route Files

```javascript
// routes/v1/users.js
const express = require('express');
const router = express.Router();
const UserController = require('../../controllers/v1/userController');

router.get('/users', UserController.getUsers);
router.post('/users', UserController.createUser);
router.get('/users/:id', UserController.getUserById);

module.exports = router;
```

```javascript
// routes/v2/users.js
const express = require('express');
const router = express.Router();
const UserController = require('../../controllers/v2/userController');

router.get('/users', UserController.getUsers);
router.post('/users', UserController.createUser);
router.get('/users/:id', UserController.getUserById);
router.patch('/users/:id', UserController.updateUser); // New in v2
router.delete('/users/:id', UserController.deleteUser); // New in v2

module.exports = router;
```

### Strategy 3: Parameter-Based Versioning

Parameter versioning is useful for optional version specification and testing scenarios.

#### Step 1: Parameter Version Middleware

```javascript
// middleware/parameterVersion.js
const parameterVersionMiddleware = (req, res, next) => {
  const version = req.query.v || req.body.version || '2.0'; // Default to latest
  
  // Validate version format
  const versionRegex = /^\d+\.\d+$/;
  if (!versionRegex.test(version)) {
    return res.status(400).json({
      error: 'Invalid version format. Use format: X.Y (e.g., 1.0, 2.0)'
    });
  }
  
  req.apiVersion = version;
  res.set('API-Version', version);
  
  next();
};

module.exports = parameterVersionMiddleware;
```

#### Step 2: Version-Aware Response Transformation

```javascript
// utils/responseTransformer.js
const transformResponse = (data, version, resourceType) => {
  switch (version) {
    case '1.0':
      return transformV1(data, resourceType);
    case '2.0':
      return transformV2(data, resourceType);
    default:
      return transformV2(data, resourceType); // Default to latest
  }
};

const transformV1 = (data, resourceType) => {
  // Simple flat structure for v1
  return Array.isArray(data) ? data : [data];
};

const transformV2 = (data, resourceType) => {
  // JSON:API-like structure for v2
  return {
    data: Array.isArray(data) ? data : [data],
    meta: {
      version: '2.0',
      resource_type: resourceType,
      count: Array.isArray(data) ? data.length : 1
    }
  };
};

module.exports = { transformResponse };
```

## 🔧 Advanced Implementation Patterns

### Deprecation Management

```javascript
// middleware/deprecation.js
const deprecationMiddleware = (deprecatedVersion, sunsetDate) => {
  return (req, res, next) => {
    if (req.apiVersion === deprecatedVersion) {
      res.set('Sunset', sunsetDate);
      res.set('Deprecation', 'true');
      res.set('Link', '</api/v2>; rel="successor-version"');
      
      // Optional: Log deprecation usage for analytics
      console.warn(`Deprecated API version ${deprecatedVersion} used`, {
        endpoint: req.path,
        user_agent: req.get('User-Agent'),
        ip: req.ip,
        timestamp: new Date().toISOString()
      });
    }
    next();
  };
};

// Usage
app.use(deprecationMiddleware('1.0', 'Sun, 31 Dec 2025 23:59:59 GMT'));
```

### Version Negotiation

```javascript
// middleware/contentNegotiation.js
const contentNegotiationMiddleware = (req, res, next) => {
  const acceptHeader = req.get('Accept');
  
  if (acceptHeader && acceptHeader.includes('application/vnd.api')) {
    // Parse custom media type: application/vnd.api+json;version=2.0
    const versionMatch = acceptHeader.match(/version=(\d+\.\d+)/);
    if (versionMatch) {
      req.apiVersion = versionMatch[1];
    }
  }
  
  next();
};
```

### Error Handling with Version Context

```javascript
// middleware/errorHandler.js
const errorHandler = (err, req, res, next) => {
  const version = req.apiVersion || '2.0';
  
  switch (version) {
    case '1.0':
      return res.status(err.status || 500).json({
        error: err.message || 'Internal Server Error'
      });
      
    case '2.0':
      return res.status(err.status || 500).json({
        error: {
          code: err.code || 'INTERNAL_ERROR',
          message: err.message || 'Internal Server Error',
          details: err.details || null,
          api_version: version,
          timestamp: new Date().toISOString()
        }
      });
      
    default:
      next(err);
  }
};
```

## 📊 Testing Implementation

### Contract Testing Setup

```javascript
// tests/contracts/userApi.pact.js
const { Pact } = require('@pact-foundation/pact');
const { like, eachLike } = require('@pact-foundation/pact').Matchers;

describe('User API Contract Tests', () => {
  const provider = new Pact({
    consumer: 'Frontend App',
    provider: 'User API',
    port: 1234,
    log: path.resolve(process.cwd(), 'logs', 'pact.log'),
    dir: path.resolve(process.cwd(), 'pacts'),
    logLevel: 'INFO'
  });

  describe('API Version 1.0', () => {
    beforeAll(() => provider.setup());
    afterEach(() => provider.verify());
    afterAll(() => provider.finalize());

    it('should return users in v1 format', async () => {
      await provider.addInteraction({
        state: 'users exist',
        uponReceiving: 'a request for users with version 1.0',
        withRequest: {
          method: 'GET',
          path: '/api/users',
          headers: {
            'Accept-Version': '1.0'
          }
        },
        willRespondWith: {
          status: 200,
          headers: {
            'Content-Type': 'application/json',
            'API-Version': '1.0'
          },
          body: eachLike({
            id: like(1),
            name: like('John Doe'),
            email: like('john@example.com'),
            created_at: like('2023-01-01T00:00:00Z')
          })
        }
      });

      const response = await fetch('http://localhost:1234/api/users', {
        headers: { 'Accept-Version': '1.0' }
      });
      
      expect(response.status).toBe(200);
      expect(response.headers.get('API-Version')).toBe('1.0');
    });
  });
});
```

### Integration Testing

```javascript
// tests/integration/apiVersioning.test.js
const request = require('supertest');
const app = require('../../app');

describe('API Versioning Integration', () => {
  describe('Header-based versioning', () => {
    it('should handle v1.0 requests', async () => {
      const response = await request(app)
        .get('/api/users')
        .set('Accept-Version', '1.0')
        .expect(200);
        
      expect(response.headers['api-version']).toBe('1.0');
      expect(response.body).toHaveProperty('length');
      expect(response.body[0]).not.toHaveProperty('attributes');
    });

    it('should handle v2.0 requests', async () => {
      const response = await request(app)
        .get('/api/users')
        .set('Accept-Version', '2.0')
        .expect(200);
        
      expect(response.headers['api-version']).toBe('2.0');
      expect(response.body).toHaveProperty('data');
      expect(response.body).toHaveProperty('meta');
    });

    it('should default to latest version', async () => {
      const response = await request(app)
        .get('/api/users')
        .expect(200);
        
      expect(response.headers['api-version']).toBe('2.0');
    });

    it('should reject unsupported versions', async () => {
      await request(app)
        .get('/api/users')
        .set('Accept-Version', '3.0')
        .expect(400);
    });
  });
});
```

## 🌍 EdTech-Specific Implementation

### Philippine Licensure Exam API Example

```javascript
// routes/examCategories.js
const express = require('express');
const router = express.Router();

// Version-aware exam categories endpoint
router.get('/exam-categories', (req, res) => {
  const version = req.apiVersion;
  
  switch (version) {
    case '1.0':
      // Simple list for v1
      return res.json([
        'Nursing Board Exam',
        'Civil Engineering Board Exam',
        'Mechanical Engineering Board Exam'
      ]);
      
    case '2.0':
      // Enhanced structure with metadata for v2
      return res.json({
        data: [
          {
            id: 'nursing',
            name: 'Nursing Board Exam',
            board: 'PRC',
            subjects: ['Fundamentals of Nursing', 'Medical-Surgical Nursing'],
            next_exam_date: '2025-12-07',
            passing_rate: 85.6
          },
          {
            id: 'civil-engineering',
            name: 'Civil Engineering Board Exam', 
            board: 'PRC',
            subjects: ['Mathematics', 'Engineering Mechanics'],
            next_exam_date: '2025-11-15',
            passing_rate: 72.3
          }
        ],
        meta: {
          total_categories: 2,
          last_updated: '2025-07-31T00:00:00Z',
          api_version: '2.0'
        }
      });
  }
});

module.exports = router;
```

## 📝 Configuration Examples

### OpenAPI Specification with Versioning

```yaml
# openapi-v2.yaml
openapi: 3.0.3
info:
  title: Philippine Licensure Exam API
  version: 2.0.0
  description: API for managing licensure exam content and practice tests
  
servers:
  - url: https://api.examprep.ph/v2
    description: Production API v2.0
  - url: https://api.examprep.ph/v1
    description: Legacy API v1.0 (deprecated)

paths:
  /exam-categories:
    get:
      summary: Get exam categories
      parameters:
        - name: Accept-Version  
          in: header
          schema:
            type: string
            enum: ['1.0', '2.0']
            default: '2.0'
      responses:
        '200':
          description: List of exam categories
          headers:
            API-Version:
              schema:
                type: string
              description: API version used for this response
          content:
            application/json:
              schema:
                oneOf:
                  - $ref: '#/components/schemas/ExamCategoriesV1'
                  - $ref: '#/components/schemas/ExamCategoriesV2'

components:
  schemas:
    ExamCategoriesV1:
      type: array
      items:
        type: string
    
    ExamCategoriesV2:
      type: object
      properties:
        data:
          type: array
          items:
            $ref: '#/components/schemas/ExamCategory'
        meta:
          $ref: '#/components/schemas/Meta'
```

## 🎯 Next Steps

1. **Choose Your Strategy**: Select the versioning approach that best fits your use case
2. **Implement Gradually**: Start with basic versioning and add advanced features iteratively
3. **Test Thoroughly**: Implement comprehensive testing for version compatibility
4. **Document Everything**: Maintain clear documentation for each API version
5. **Monitor Usage**: Track version adoption and plan deprecation timelines

---

## 🧭 Navigation

← [Executive Summary](./executive-summary.md) | **[Best Practices](./best-practices.md)** →

---

*Implementation Guide | API Versioning Strategies Research | July 2025*