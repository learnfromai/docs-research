# Best Practices - API Versioning Strategies

## 🎯 Core Principles

### 1. Semantic Versioning for APIs

Follow semantic versioning principles adapted for API contracts:

- **Major Version (X.0.0)**: Breaking changes that require client modifications
- **Minor Version (X.Y.0)**: Backward-compatible feature additions
- **Patch Version (X.Y.Z)**: Backward-compatible bug fixes and documentation updates

```javascript
// Example versioning scheme
const API_VERSIONS = {
  '1.0.0': { // Initial release
    breaking_changes: [],
    features: ['User CRUD', 'Basic authentication'],
    stability: 'stable'
  },
  '1.1.0': { // Minor update - new features
    breaking_changes: [],
    features: ['Password reset', 'Email verification'],
    stability: 'stable'
  },
  '2.0.0': { // Major update - breaking changes
    breaking_changes: [
      'Changed response format to JSON:API',
      'Removed deprecated /login endpoint',
      'Modified error response structure'
    ],
    features: ['GraphQL support', 'Advanced filtering'],
    stability: 'stable'
  }
};
```

### 2. Design for Evolution from Day One

```javascript
// ✅ Good: Extensible response structure
{
  "data": {
    "id": "user_123",
    "type": "user",
    "attributes": {
      "name": "John Doe",
      "email": "john@example.com"
    },
    // Easy to add new fields without breaking clients
    "relationships": {},
    "meta": {}
  }
}

// ❌ Poor: Flat structure difficult to extend
{
  "id": "user_123",
  "name": "John Doe",
  "email": "john@example.com"
  // Adding new top-level fields might break clients
}
```

### 3. Graceful Deprecation Strategy

Implement a structured deprecation process with clear timelines:

```javascript
// middleware/deprecationWarning.js
const deprecationWarning = (version, sunsetDate, successor) => {
  return (req, res, next) => {
    if (req.apiVersion === version) {
      res.set({
        'Sunset': sunsetDate,
        'Deprecation': 'true',
        'Link': `<${successor}>; rel="successor-version"`,
        'Warning': `299 - "API version ${version} is deprecated. Please migrate to ${successor}"`
      });
    }
    next();
  };
};

// Usage with 6-month deprecation period
app.use(deprecationWarning('1.0', 'Sun, 31 Jan 2026 23:59:59 GMT', '/api/v2'));
```

## 🏗️ Architecture Best Practices

### 1. Version-Agnostic Business Logic

Separate business logic from API presentation logic:

```javascript
// services/userService.js - Version-agnostic business logic
class UserService {
  async getUsers(filters = {}) {
    // Business logic remains consistent across versions
    const users = await User.findAll({
      where: filters,
      include: [Profile, Preferences]
    });
    
    return users;
  }
  
  async createUser(userData) {
    // Validation and business rules
    if (!userData.email || !this.isValidEmail(userData.email)) {
      throw new ValidationError('Valid email is required');
    }
    
    return await User.create(userData);
  }
  
  isValidEmail(email) {
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
  }
}

// presenters/userPresenter.js - Version-specific formatting
class UserPresenter {
  static formatForVersion(users, version) {
    switch (version) {
      case '1.0':
        return this.formatV1(users);
      case '2.0':
        return this.formatV2(users);
      default:
        return this.formatLatest(users);
    }
  }
  
  static formatV1(users) {
    return users.map(user => ({
      id: user.id,
      name: user.name,
      email: user.email,
      created_at: user.createdAt
    }));
  }
  
  static formatV2(users) {
    return {
      data: users.map(user => ({
        id: user.id,
        type: 'user',
        attributes: {
          name: user.name,
          email: user.email,
          profile: user.Profile ? {
            avatar_url: user.Profile.avatarUrl,
            bio: user.Profile.bio
          } : null
        },
        meta: {
          created_at: user.createdAt,
          updated_at: user.updatedAt
        }
      })),
      meta: {
        total_count: users.length,
        api_version: '2.0'
      }
    };
  }
}
```

### 2. Middleware-Based Version Routing

Implement clean version routing with middleware:

```javascript
// middleware/versionRouter.js
class VersionRouter {
  constructor() {
    this.handlers = new Map();
  }
  
  version(versionSpec, handler) {
    // Support version ranges: '>=1.0', '1.x', '~1.1'
    this.handlers.set(versionSpec, handler);
    return this;
  }
  
  middleware() {
    return (req, res, next) => {
      const requestedVersion = req.apiVersion;
      
      // Find matching handler
      for (const [versionSpec, handler] of this.handlers) {
        if (this.matchesVersion(requestedVersion, versionSpec)) {
          return handler(req, res, next);
        }
      }
      
      // No matching version found
      return res.status(400).json({
        error: 'Unsupported API version',
        requested: requestedVersion,
        supported: Array.from(this.handlers.keys())
      });
    };
  }
  
  matchesVersion(version, spec) {
    // Implement semver matching logic
    if (spec.startsWith('>=')) {
      return this.compareVersions(version, spec.slice(2)) >= 0;
    }
    if (spec.endsWith('.x')) {
      const major = spec.slice(0, -2);
      return version.startsWith(major + '.');
    }
    return version === spec;
  }
  
  compareVersions(a, b) {
    const aParts = a.split('.').map(Number);
    const bParts = b.split('.').map(Number);
    
    for (let i = 0; i < Math.max(aParts.length, bParts.length); i++) {
      const aPart = aParts[i] || 0;
      const bPart = bParts[i] || 0;
      
      if (aPart > bPart) return 1;
      if (aPart < bPart) return -1;
    }
    
    return 0;
  }
}

// Usage
const versionRouter = new VersionRouter()
  .version('1.0', getUsersV1)
  .version('1.1', getUsersV1) // Same handler for minor version
  .version('>=2.0', getUsersV2);

app.get('/users', versionRouter.middleware());
```

### 3. Database Schema Evolution

Handle database changes across API versions:

```javascript
// models/user.js with version-aware field handling
class User extends Model {
  static associate(models) {
    // Associations remain consistent
  }
  
  // Method to get user data formatted for specific API version
  toApiResponse(version = '2.0') {
    const baseData = {
      id: this.id,
      email: this.email,
      createdAt: this.createdAt
    };
    
    switch (version) {
      case '1.0':
        return {
          ...baseData,
          name: this.firstName + ' ' + this.lastName, // Computed field for v1
          created_at: this.createdAt // Different date format
        };
        
      case '2.0':
        return {
          ...baseData,
          firstName: this.firstName,
          lastName: this.lastName,
          profile: {
            avatar_url: this.avatarUrl,
            bio: this.bio,
            preferences: this.preferences
          },
          timestamps: {
            created_at: this.createdAt,
            updated_at: this.updatedAt
          }
        };
        
      default:
        return this.toApiResponse('2.0');
    }
  }
}

// Database migration strategy
// Migration: 20250731000000-add-user-names.js
module.exports = {
  up: async (queryInterface, Sequelize) => {
    // Add new fields without breaking existing API versions
    await queryInterface.addColumn('Users', 'firstName', {
      type: Sequelize.STRING,
      allowNull: true // Allow null for backward compatibility
    });
    
    await queryInterface.addColumn('Users', 'lastName', {
      type: Sequelize.STRING,
      allowNull: true
    });
    
    // Migrate existing 'name' field data
    const users = await queryInterface.sequelize.query(
      'SELECT id, name FROM Users WHERE name IS NOT NULL',
      { type: Sequelize.QueryTypes.SELECT }
    );
    
    for (const user of users) {
      const [firstName, ...lastName] = user.name.split(' ');
      await queryInterface.sequelize.query(
        'UPDATE Users SET firstName = ?, lastName = ? WHERE id = ?',
        {
          replacements: [firstName, lastName.join(' '), user.id],
          type: Sequelize.QueryTypes.UPDATE
        }
      );
    }
  },
  
  down: async (queryInterface, Sequelize) => {
    await queryInterface.removeColumn('Users', 'firstName');
    await queryInterface.removeColumn('Users', 'lastName');
  }
};
```

## 🔒 Security Best Practices

### 1. Version-Specific Security Policies

```javascript
// middleware/versionSecurity.js
const versionSecurityMiddleware = (req, res, next) => {
  const version = req.apiVersion;
  
  switch (version) {
    case '1.0':
      // Legacy version with basic security
      if (!req.headers.authorization) {
        return res.status(401).json({ error: 'Authorization required' });
      }
      break;
      
    case '2.0':
      // Enhanced security for newer version
      if (!req.headers.authorization) {
        return res.status(401).json({
          error: {
            code: 'UNAUTHORIZED',
            message: 'Bearer token required',
            api_version: '2.0'
          }
        });
      }
      
      // Additional security headers for v2
      res.set({
        'X-Content-Type-Options': 'nosniff',
        'X-Frame-Options': 'DENY',
        'X-XSS-Protection': '1; mode=block'
      });
      break;
  }
  
  next();
};
```

### 2. Rate Limiting by Version

```javascript
// middleware/rateLimiting.js
const rateLimit = require('express-rate-limit');

const createVersionedRateLimit = () => {
  return (req, res, next) => {
    const version = req.apiVersion;
    let windowMs, maxRequests;
    
    switch (version) {
      case '1.0':
        // More restrictive for older versions
        windowMs = 15 * 60 * 1000; // 15 minutes
        maxRequests = 100;
        break;
        
      case '2.0':
        // More generous for newer versions
        windowMs = 15 * 60 * 1000; // 15 minutes  
        maxRequests = 1000;
        break;
        
      default:
        windowMs = 15 * 60 * 1000;
        maxRequests = 500;
    }
    
    const limiter = rateLimit({
      windowMs,
      max: maxRequests,
      message: {
        error: `Too many requests for API version ${version}`,
        retry_after: Math.ceil(windowMs / 1000)
      },
      standardHeaders: true,
      legacyHeaders: false
    });
    
    limiter(req, res, next);
  };
};
```

## 📊 Monitoring and Analytics

### 1. Version Usage Tracking

```javascript
// middleware/analytics.js
const analytics = require('./utils/analytics');

const versionAnalyticsMiddleware = (req, res, next) => {
  const version = req.apiVersion;
  const endpoint = req.path;
  const userAgent = req.get('User-Agent');
  
  // Track version usage
  analytics.track('api_version_usage', {
    version,
    endpoint,
    user_agent: userAgent,
    client_ip: req.ip,
    timestamp: new Date(),
    response_time: null // Will be set in response middleware
  });
  
  // Measure response time
  const startTime = Date.now();
  
  res.on('finish', () => {
    const responseTime = Date.now() - startTime;
    
    analytics.track('api_response_time', {
      version,
      endpoint,
      response_time: responseTime,
      status_code: res.statusCode,
      timestamp: new Date()
    });
  });
  
  next();
};

// utils/analytics.js
class Analytics {
  constructor() {
    this.metrics = new Map();
  }
  
  track(event, data) {
    const key = `${event}_${data.version}`;
    
    if (!this.metrics.has(key)) {
      this.metrics.set(key, []);
    }
    
    this.metrics.get(key).push(data);
    
    // Periodic reporting
    this.reportPeriodically();
  }
  
  getVersionUsageStats() {
    const stats = {};
    
    for (const [key, events] of this.metrics) {
      if (key.startsWith('api_version_usage_')) {
        const version = key.replace('api_version_usage_', '');
        stats[version] = {
          total_requests: events.length,
          unique_endpoints: new Set(events.map(e => e.endpoint)).size,
          avg_response_time: this.calculateAverageResponseTime(version)
        };
      }
    }
    
    return stats;
  }
  
  calculateAverageResponseTime(version) {
    const responseTimeKey = `api_response_time_${version}`;
    const events = this.metrics.get(responseTimeKey) || [];
    
    if (events.length === 0) return 0;
    
    const total = events.reduce((sum, event) => sum + event.response_time, 0);
    return Math.round(total / events.length);
  }
  
  reportPeriodically() {
    // Report metrics every hour
    if (!this.reportInterval) {
      this.reportInterval = setInterval(() => {
        console.log('API Version Usage Stats:', this.getVersionUsageStats());
      }, 60 * 60 * 1000);
    }
  }
}

module.exports = new Analytics();
```

### 2. Health Checks with Version Information

```javascript
// routes/health.js
const express = require('express');
const router = express.Router();
const packageJson = require('../package.json');

router.get('/health', (req, res) => {
  const version = req.apiVersion || 'unknown';
  
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    version: {
      api: version,
      application: packageJson.version,
      node: process.version
    },
    uptime: process.uptime(),
    environment: process.env.NODE_ENV || 'development'
  });
});

// Version-specific health endpoint
router.get('/health/versions', (req, res) => {
  const supportedVersions = ['1.0', '1.1', '2.0'];
  const deprecatedVersions = ['1.0'];
  
  res.json({
    supported_versions: supportedVersions,
    deprecated_versions: deprecatedVersions,
    latest_version: '2.0',
    version_info: {
      '1.0': {
        status: 'deprecated',
        sunset_date: '2026-01-31T23:59:59Z',
        migration_guide: '/docs/migration/v1-to-v2'
      },
      '1.1': {
        status: 'maintenance',
        end_of_life: '2026-06-30T23:59:59Z'
      },
      '2.0': {
        status: 'current',
        features: ['Enhanced response format', 'GraphQL support', 'Improved error handling']
      }
    }
  });
});

module.exports = router;
```

## 🧪 Testing Best Practices

### 1. Contract Testing Across Versions

```javascript
// tests/contracts/userApiContracts.test.js
const { PactV3 } = require('@pact-foundation/pact');
const { MatchersV3 } = require('@pact-foundation/pact');

describe('User API Contracts', () => {
  const provider = new PactV3({
    consumer: 'Frontend App',
    provider: 'User API'
  });

  // Test contract for each supported version
  const versions = ['1.0', '2.0'];
  
  versions.forEach(version => {
    describe(`API Version ${version}`, () => {
      it(`should handle user creation for v${version}`, async () => {
        const expectedResponse = version === '1.0' 
          ? {
              id: MatchersV3.integer(1),
              name: MatchersV3.string('John Doe'),
              email: MatchersV3.string('john@example.com'),
              created_at: MatchersV3.iso8601DateTime()
            }
          : {
              data: {
                id: MatchersV3.integer(1),
                type: 'user',
                attributes: {
                  name: MatchersV3.string('John Doe'),
                  email: MatchersV3.string('john@example.com')
                }
              },
              meta: {
                api_version: version,
                created_at: MatchersV3.iso8601DateTime()
              }
            };
        
        await provider
          .given('a user can be created')
          .uponReceiving(`a request to create a user (v${version})`)
          .withRequest({
            method: 'POST',
            path: '/api/users',
            headers: {
              'Accept-Version': version,
              'Content-Type': 'application/json'
            },
            body: {
              name: 'John Doe',
              email: 'john@example.com'
            }
          })
          .willRespondWith({
            status: 201,
            headers: {
              'Content-Type': 'application/json',
              'API-Version': version
            },
            body: expectedResponse
          })
          .executeTest(async (mockServer) => {
            const response = await fetch(`${mockServer.url}/api/users`, {
              method: 'POST',
              headers: {
                'Accept-Version': version,
                'Content-Type': 'application/json'
              },
              body: JSON.stringify({
                name: 'John Doe',
                email: 'john@example.com'
              })
            });
            
            expect(response.status).toBe(201);
            expect(response.headers.get('API-Version')).toBe(version);
          });
      });
    });
  });
});
```

### 2. Backward Compatibility Testing

```javascript
// tests/compatibility/backwardCompatibility.test.js
const request = require('supertest');
const app = require('../../app');

describe('Backward Compatibility Tests', () => {
  const testCases = [
    {
      version: '1.0',
      description: 'Legacy version with simple response format',
      expectedFields: ['id', 'name', 'email', 'created_at'],
      unexpectedFields: ['attributes', 'meta', 'type']
    },
    {
      version: '2.0', 
      description: 'Current version with enhanced response format',
      expectedFields: ['data', 'meta'],
      unexpectedFields: []
    }
  ];
  
  testCases.forEach(({ version, description, expectedFields, unexpectedFields }) => {
    describe(`Version ${version}: ${description}`, () => {
      let response;
      
      beforeAll(async () => {
        response = await request(app)
          .get('/api/users')
          .set('Accept-Version', version)
          .expect(200);
      });
      
      it('should return correct response structure', () => {
        expectedFields.forEach(field => {
          expect(response.body).toHaveProperty(field);
        });
        
        unexpectedFields.forEach(field => {
          expect(response.body).not.toHaveProperty(field);
        });
      });
      
      it('should include version headers', () => {
        expect(response.headers['api-version']).toBe(version);
        expect(response.headers['supported-versions']).toBeDefined();
      });
      
      it('should handle errors consistently', async () => {
        const errorResponse = await request(app)
          .get('/api/users/nonexistent')
          .set('Accept-Version', version)
          .expect(404);
          
        if (version === '1.0') {
          expect(errorResponse.body).toHaveProperty('error');
          expect(typeof errorResponse.body.error).toBe('string');
        } else {
          expect(errorResponse.body).toHaveProperty('error');
          expect(errorResponse.body.error).toHaveProperty('code');
          expect(errorResponse.body.error).toHaveProperty('message');
        }
      });
    });
  });
  
  describe('Version compatibility matrix', () => {
    it('should not break existing client integrations', async () => {
      // Test that old clients still work with new server
      const v1Response = await request(app)
        .get('/api/users')
        .set('Accept-Version', '1.0')
        .expect(200);
        
      const v2Response = await request(app)
        .get('/api/users')
        .set('Accept-Version', '2.0')
        .expect(200);
        
      // Both should succeed but with different structures
      expect(Array.isArray(v1Response.body)).toBe(true);
      expect(v2Response.body).toHaveProperty('data');
    });
  });
});
```

## 📚 Documentation Best Practices

### 1. Version-Specific Documentation

```markdown
<!-- docs/api/v2/users.md -->
# Users API v2.0

## Overview
The Users API v2.0 provides enhanced user management with improved response formats and additional metadata.

### Migration from v1.0
- Response format changed from array to object with `data` and `meta` properties
- Error responses now include structured error objects
- Added support for user profile information

## Endpoints

### GET /api/users
Returns a list of users with enhanced metadata.

#### Headers
- `Accept-Version: 2.0` (required)
- `Authorization: Bearer <token>` (required)

#### Response Format
```json
{
  "data": [
    {
      "id": 1,
      "type": "user",
      "attributes": {
        "name": "John Doe",
        "email": "john@example.com",
        "profile": {
          "avatar_url": "https://example.com/avatar.jpg",
          "bio": "Software Developer"
        }
      },
      "meta": {
        "created_at": "2023-01-01T00:00:00Z",
        "updated_at": "2023-01-15T12:00:00Z"
      }
    }
  ],
  "meta": {
    "total_count": 1,
    "api_version": "2.0",
    "generated_at": "2023-01-15T12:30:00Z"
  }
}
```

#### Breaking Changes from v1.0
1. **Response Structure**: Changed from simple array to object with `data` and `meta`
2. **User Object**: Restructured with `attributes` and `meta` separation
3. **Date Format**: All timestamps now in ISO 8601 format
```

### 2. API Change Log

```markdown
<!-- CHANGELOG.md -->
# API Changelog

## [2.0.0] - 2025-07-31

### Added
- Enhanced user response format with metadata
- GraphQL endpoint support
- Advanced filtering and pagination
- Structured error responses

### Changed
- **BREAKING**: Response format for all endpoints
- **BREAKING**: Error response structure
- Improved performance for large datasets

### Deprecated
- v1.0 API endpoints (sunset date: 2026-01-31)

### Migration Guide
See [Migration Guide v1 to v2](./docs/migration/v1-to-v2.md)

## [1.1.0] - 2025-06-15

### Added
- Password reset functionality
- Email verification endpoints

### Fixed
- Memory leak in authentication middleware
- Rate limiting edge cases

## [1.0.0] - 2025-01-01

### Added
- Initial API release
- User CRUD operations
- Basic authentication
```

## 🌟 EdTech-Specific Best Practices

### 1. Learning Progress Versioning

```javascript
// Handle learning progress data across versions
const formatLearningProgress = (progress, version) => {
  switch (version) {
    case '1.0':
      // Simple progress tracking
      return {
        user_id: progress.userId,
        course_id: progress.courseId,
        completed_lessons: progress.completedLessons,
        progress_percentage: progress.progressPercentage,
        last_accessed: progress.lastAccessed
      };
      
    case '2.0':
      // Enhanced progress with analytics
      return {
        data: {
          id: progress.id,
          type: 'learning_progress',
          attributes: {
            user_id: progress.userId,
            course: {
              id: progress.Course.id,
              title: progress.Course.title,
              category: progress.Course.category
            },
            progress: {
              completed_lessons: progress.completedLessons,
              total_lessons: progress.Course.totalLessons,
              percentage: progress.progressPercentage,
              estimated_completion: progress.estimatedCompletion
            },
            performance: {
              average_score: progress.averageScore,
              time_spent_minutes: progress.timeSpentMinutes,
              streak_days: progress.streakDays
            }
          },
          meta: {
            last_accessed: progress.lastAccessed,
            created_at: progress.createdAt,
            updated_at: progress.updatedAt
          }
        }
      };
  }
};
```

### 2. Exam Content Versioning

```javascript
// Handle different exam board requirements
const formatExamContent = (content, version, examBoard = 'PRC') => {
  const baseContent = {
    question_id: content.id,
    question_text: content.text,
    options: content.options,
    correct_answer: content.correctAnswer
  };
  
  switch (version) {
    case '1.0':
      return baseContent;
      
    case '2.0':
      return {
        data: {
          ...baseContent,
          metadata: {
            exam_board: examBoard,
            subject: content.subject,
            topic: content.topic,
            difficulty_level: content.difficultyLevel,
            bloom_taxonomy: content.bloomTaxonomy,
            references: content.references
          },
          analytics: {
            success_rate: content.successRate,
            average_time_seconds: content.averageTimeSeconds,
            times_answered: content.timesAnswered
          }
        },
        meta: {
          api_version: '2.0',
          exam_board: examBoard,
          last_updated: content.updatedAt
        }
      };
  }
};
```

## 🎯 Performance Optimization

### 1. Caching Strategy by Version

```javascript
// utils/cache.js
const redis = require('redis');
const client = redis.createClient();

class VersionedCache {
  static generateKey(endpoint, version, params = {}) {
    const paramString = Object.keys(params)
      .sort()
      .map(key => `${key}:${params[key]}`)
      .join('|');
    
    return `api:${version}:${endpoint}:${paramString}`;
  }
  
  static async get(endpoint, version, params = {}) {
    const key = this.generateKey(endpoint, version, params);
    const cached = await client.get(key);
    
    return cached ? JSON.parse(cached) : null;
  }
  
  static async set(endpoint, version, params = {}, data, ttl = 300) {
    const key = this.generateKey(endpoint, version, params);
    await client.setex(key, ttl, JSON.stringify(data));
  }
  
  static async invalidateVersion(version) {
    const pattern = `api:${version}:*`;
    const keys = await client.keys(pattern);
    
    if (keys.length > 0) {
      await client.del(...keys);
    }
  }
}

// Usage in route handler
app.get('/api/users', async (req, res) => {
  const version = req.apiVersion;
  const cacheKey = 'users';
  
  // Try cache first
  let cachedData = await VersionedCache.get(cacheKey, version, req.query);
  
  if (cachedData) {
    res.set('X-Cache', 'HIT');
    return res.json(cachedData);
  }
  
  // Fetch from database
  const users = await UserService.getUsers(req.query);
  const formattedData = UserPresenter.formatForVersion(users, version);
  
  // Cache the response
  await VersionedCache.set(cacheKey, version, req.query, formattedData);
  
  res.set('X-Cache', 'MISS');
  res.json(formattedData);
});
```

### 2. Lazy Loading for Version Features

```javascript
// Dynamic loading of version-specific modules
class VersionManager {
  constructor() {
    this.handlers = new Map();
  }
  
  async getHandler(version) {
    if (!this.handlers.has(version)) {
      try {
        const handler = await import(`./handlers/v${version.replace('.', '_')}`);
        this.handlers.set(version, handler.default);
      } catch (error) {
        throw new Error(`Unsupported version: ${version}`);
      }
    }
    
    return this.handlers.get(version);
  }
}

// handlers/v1_0.js
export default {
  formatResponse: (data) => {
    // V1.0 formatting logic
    return data.map(item => ({
      id: item.id,
      name: item.name,
      created_at: item.createdAt
    }));
  },
  
  validateRequest: (req) => {
    // V1.0 validation logic
    return req.body.name && req.body.email;
  }
};

// handlers/v2_0.js  
export default {
  formatResponse: (data) => {
    // V2.0 formatting logic
    return {
      data: data.map(item => ({
        id: item.id,
        type: 'user',
        attributes: {
          name: item.name,
          email: item.email
        }
      })),
      meta: {
        count: data.length,
        version: '2.0'
      }
    };
  },
  
  validateRequest: (req) => {
    // V2.0 validation logic (more strict)
    return req.body.name && 
           req.body.email && 
           /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(req.body.email);
  }
};
```

---

## 🧭 Navigation

← [Implementation Guide](./implementation-guide.md) | **[Comparison Analysis](./comparison-analysis.md)** →

---

*Best Practices | API Versioning Strategies Research | July 2025*