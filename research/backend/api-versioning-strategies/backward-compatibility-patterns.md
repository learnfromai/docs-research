# Backward Compatibility Patterns

## 🎯 Overview

Backward compatibility is the cornerstone of successful API evolution. This guide explores proven patterns and techniques for maintaining API compatibility while enabling continuous improvement and feature development.

## 🔄 Core Compatibility Principles

### The Robustness Principle (Postel's Law)

> "Be conservative in what you send, be liberal in what you accept"

This principle, fundamental to API design, means:
- **Conservative output**: Always send complete, well-formed responses
- **Liberal input**: Accept and gracefully handle various input formats

```javascript
// Example: Liberal input handling
function validateUserInput(userData, version) {
  const baseSchema = {
    name: { type: 'string', required: true },
    email: { type: 'string', required: true }
  };
  
  // Version-specific extensions
  const versionSchemas = {
    '1.0': baseSchema,
    '2.0': {
      ...baseSchema,
      profile: { 
        type: 'object', 
        required: false,
        properties: {
          bio: { type: 'string', required: false },
          avatar_url: { type: 'string', required: false }
        }
      }
    }
  };
  
  const schema = versionSchemas[version] || versionSchemas['2.0'];
  
  // Liberal: Accept extra fields, ignore unknown properties
  const validatedData = {};
  
  for (const [key, rules] of Object.entries(schema)) {
    if (userData.hasOwnProperty(key)) {
      if (rules.required && !userData[key]) {
        throw new ValidationError(`${key} is required`);
      }
      validatedData[key] = userData[key];
    } else if (rules.required) {
      throw new ValidationError(`${key} is required`);
    }
  }
  
  return validatedData;
}
```

### Additive-Only Changes

The safest approach to API evolution is making only additive changes:

```javascript
// ✅ Safe additive changes
const v1Response = {
  id: 1,
  name: "John Doe",
  email: "john@example.com"
};

const v2Response = {
  id: 1,
  name: "John Doe",
  email: "john@example.com",
  // New fields added (safe)
  profile: {
    bio: "Software Developer",
    avatar_url: "https://example.com/avatar.jpg"
  },
  preferences: {
    theme: "dark",
    notifications: true
  }
};

// ❌ Dangerous changes to avoid
const brokenResponse = {
  user_id: 1, // Changed from 'id' - BREAKING
  full_name: "John Doe", // Changed from 'name' - BREAKING
  email_address: "john@example.com", // Changed from 'email' - BREAKING
  created: "2023-01-01" // Different format - BREAKING
};
```

## 🏗️ Compatibility Patterns

### Pattern 1: Field Aliasing

Provide both old and new field names during transition periods:

```javascript
class BackwardCompatiblePresenter {
  static formatUser(user, version) {
    const baseResponse = {
      id: user.id,
      email: user.email,
      created_at: user.createdAt,
      updated_at: user.updatedAt
    };
    
    switch (version) {
      case '1.0':
        return {
          ...baseResponse,
          name: `${user.firstName} ${user.lastName}`, // Computed field for v1
          profile_url: user.profileUrl // Old field name
        };
        
      case '1.1':
        // Transition period - provide both old and new formats
        return {
          ...baseResponse,
          name: `${user.firstName} ${user.lastName}`, // Legacy
          first_name: user.firstName, // New format
          last_name: user.lastName, // New format
          profile_url: user.profileUrl, // Legacy
          avatar_url: user.profileUrl // New format
        };
        
      case '2.0':
        return {
          ...baseResponse,
          first_name: user.firstName,
          last_name: user.lastName,
          avatar_url: user.profileUrl,
          // New fields in v2
          bio: user.bio,
          location: user.location
        };
        
      default:
        return this.formatUser(user, '2.0');
    }
  }
}
```

### Pattern 2: Response Envelope Evolution

Gradually introduce structured response formats:

```javascript
class ResponseEnvelope {
  static wrap(data, version, metadata = {}) {
    switch (version) {
      case '1.0':
        // V1: Direct data response
        return Array.isArray(data) ? data : data;
        
      case '1.5':
        // Transition: Optional envelope
        if (metadata.useEnvelope) {
          return {
            data: data,
            success: true,
            version: version
          };
        }
        return data;
        
      case '2.0':
        // V2: Always use envelope
        return {
          data: data,
          meta: {
            version: version,
            timestamp: new Date().toISOString(),
            count: Array.isArray(data) ? data.length : 1,
            ...metadata
          },
          links: this.generateLinks(data, metadata)
        };
        
      default:
        return this.wrap(data, '2.0', metadata);
    }
  }
  
  static generateLinks(data, metadata) {
    const links = {
      self: metadata.currentUrl
    };
    
    // Add pagination links if applicable
    if (metadata.pagination) {
      const { page, limit, total } = metadata.pagination;
      const totalPages = Math.ceil(total / limit);
      
      if (page > 1) {
        links.prev = `${metadata.baseUrl}?page=${page - 1}&limit=${limit}`;
      }
      if (page < totalPages) {
        links.next = `${metadata.baseUrl}?page=${page + 1}&limit=${limit}`;
      }
      
      links.first = `${metadata.baseUrl}?page=1&limit=${limit}`;
      links.last = `${metadata.baseUrl}?page=${totalPages}&limit=${limit}`;
    }
    
    return links;
  }
}

// Usage
app.get('/api/users', async (req, res) => {
  const version = req.apiVersion;
  const users = await UserService.getUsers(req.query);
  
  const metadata = {
    currentUrl: req.originalUrl,
    baseUrl: `${req.protocol}://${req.get('host')}/api/users`,
    pagination: req.pagination,
    useEnvelope: req.query.envelope === 'true' // Optional in transition
  };
  
  const response = ResponseEnvelope.wrap(users, version, metadata);
  res.json(response);
});
```

### Pattern 3: Error Response Evolution

Maintain backward-compatible error handling:

```javascript
class ErrorHandler {
  static formatError(error, version, context = {}) {
    const baseError = {
      message: error.message,
      timestamp: new Date().toISOString()
    };
    
    switch (version) {
      case '1.0':
        // V1: Simple string or basic object
        return typeof error === 'string' ? error : baseError.message;
        
      case '1.1':
        // V1.1: Basic structured error
        return {
          error: baseError.message,
          code: error.code || 'UNKNOWN_ERROR',
          timestamp: baseError.timestamp
        };
        
      case '2.0':
        // V2: Full structured error with context
        return {
          error: {
            code: error.code || 'UNKNOWN_ERROR',
            message: baseError.message,
            details: error.details || null,
            context: {
              api_version: version,
              request_id: context.requestId,
              endpoint: context.endpoint,
              timestamp: baseError.timestamp
            },
            // Help information
            help: {
              documentation: error.helpUrl || `${context.docsUrl}/errors/${error.code}`,
              support: context.supportUrl
            }
          }
        };
        
      default:
        return this.formatError(error, '2.0', context);
    }
  }
  
  static createErrorMiddleware() {
    return (error, req, res, next) => {
      const version = req.apiVersion || '2.0';
      const context = {
        requestId: req.id || 'unknown',
        endpoint: req.path,
        docsUrl: 'https://docs.api.example.com',
        supportUrl: 'https://support.example.com'
      };
      
      const statusCode = error.statusCode || 500;
      const formattedError = this.formatError(error, version, context);
      
      // Log error for monitoring
      this.logError(error, version, context);
      
      res.status(statusCode).json(formattedError);
    };
  }
  
  static logError(error, version, context) {
    console.error(`API Error [v${version}]:`, {
      error: error.message,
      code: error.code,
      stack: error.stack,
      context
    });
  }
}
```

### Pattern 4: Input Parameter Compatibility

Handle different input formats gracefully:

```javascript
class InputNormalizer {
  static normalizeCreateUserRequest(reqBody, version) {
    switch (version) {
      case '1.0':
        // V1: Flat structure
        return {
          firstName: this.extractFirstName(reqBody.name),
          lastName: this.extractLastName(reqBody.name),
          email: reqBody.email,
          profile: {
            bio: reqBody.bio || null,
            avatarUrl: reqBody.profile_url || null
          }
        };
        
      case '1.1':
        // V1.1: Support both old and new formats
        if (reqBody.name && !reqBody.first_name && !reqBody.last_name) {
          // Old format
          return {
            firstName: this.extractFirstName(reqBody.name),
            lastName: this.extractLastName(reqBody.name),
            email: reqBody.email,
            profile: {
              bio: reqBody.bio || null,
              avatarUrl: reqBody.profile_url || reqBody.avatar_url || null
            }
          };
        } else {
          // New format
          return {
            firstName: reqBody.first_name,
            lastName: reqBody.last_name,
            email: reqBody.email,
            profile: {
              bio: reqBody.bio || null,
              avatarUrl: reqBody.avatar_url || reqBody.profile_url || null
            }
          };
        }
        
      case '2.0':
        // V2: Structured input expected
        return {
          firstName: reqBody.first_name,
          lastName: reqBody.last_name,
          email: reqBody.email,
          profile: reqBody.profile || {},
          preferences: reqBody.preferences || {}
        };
        
      default:
        return this.normalizeCreateUserRequest(reqBody, '2.0');
    }
  }
  
  static extractFirstName(fullName) {
    return fullName ? fullName.split(' ')[0] : '';
  }
  
  static extractLastName(fullName) {
    if (!fullName) return '';
    const parts = fullName.split(' ');
    return parts.length > 1 ? parts.slice(1).join(' ') : '';
  }
  
  static createNormalizationMiddleware() {
    return (req, res, next) => {
      const version = req.apiVersion;
      
      // Only normalize for POST/PUT/PATCH requests
      if (['POST', 'PUT', 'PATCH'].includes(req.method) && req.body) {
        try {
          // Route-specific normalization
          if (req.path === '/api/users' && req.method === 'POST') {
            req.body = this.normalizeCreateUserRequest(req.body, version);
          }
          // Add more route-specific normalizations as needed
          
        } catch (error) {
          return res.status(400).json({
            error: 'Invalid input format',
            details: error.message,
            api_version: version
          });
        }
      }
      
      next();
    };
  }
}
```

## 🔍 Compatibility Testing Strategies

### Contract Testing with Multiple Versions

```javascript
// tests/compatibility/contractTests.js
const { Pact, Matchers } = require('@pact-foundation/pact');
const { like, eachLike, term } = Matchers;

describe('Multi-Version Contract Tests', () => {
  const versions = ['1.0', '1.1', '2.0'];
  
  versions.forEach(version => {
    describe(`API Version ${version}`, () => {
      const provider = new Pact({
        consumer: `Client-v${version}`,
        provider: 'UserAPI',
        port: 1234
      });
      
      beforeAll(() => provider.setup());
      afterEach(() => provider.verify());
      afterAll(() => provider.finalize());
      
      it(`should handle user creation for version ${version}`, async () => {
        const expectedRequest = this.getExpectedRequest(version);
        const expectedResponse = this.getExpectedResponse(version);
        
        await provider.addInteraction({
          state: 'user can be created',
          uponReceiving: `a request to create user (v${version})`,
          withRequest: expectedRequest,
          willRespondWith: expectedResponse
        });
        
        // Test the interaction
        const client = new ApiClient({ version });
        const result = await client.createUser(expectedRequest.body);
        
        expect(result).toBeDefined();
        this.validateResponseFormat(result, version);
      });
    });
  });
  
  getExpectedRequest(version) {
    const requests = {
      '1.0': {
        method: 'POST',
        path: '/api/users',
        headers: { 'Accept-Version': '1.0' },
        body: {
          name: like('John Doe'),
          email: like('john@example.com')
        }
      },
      '1.1': {
        method: 'POST',
        path: '/api/users',
        headers: { 'Accept-Version': '1.1' },
        body: {
          first_name: like('John'),
          last_name: like('Doe'),
          email: like('john@example.com')
        }
      },
      '2.0': {
        method: 'POST',
        path: '/api/users',
        headers: { 'Accept-Version': '2.0' },
        body: {
          first_name: like('John'),
          last_name: like('Doe'),
          email: like('john@example.com'),
          profile: like({
            bio: 'Software Developer'
          })
        }
      }
    };
    
    return requests[version];
  }
  
  getExpectedResponse(version) {
    const responses = {
      '1.0': {
        status: 201,
        headers: { 'API-Version': '1.0' },
        body: {
          id: like(1),
          name: like('John Doe'),
          email: like('john@example.com'),
          created_at: term({
            matcher: /\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z/,
            generate: '2023-01-01T00:00:00Z'
          })
        }
      },
      '1.1': {
        status: 201,
        headers: { 'API-Version': '1.1' },
        body: {
          id: like(1),
          first_name: like('John'),
          last_name: like('Doe'),
          email: like('john@example.com'),
          created_at: like('2023-01-01T00:00:00Z')
        }
      },
      '2.0': {
        status: 201,
        headers: { 'API-Version': '2.0' },
        body: {
          data: {
            id: like(1),
            type: 'user',
            attributes: {
              first_name: like('John'),
              last_name: like('Doe'),
              email: like('john@example.com')
            }
          },
          meta: {
            api_version: '2.0',
            created_at: like('2023-01-01T00:00:00Z')
          }
        }
      }
    };
    
    return responses[version];
  }
  
  validateResponseFormat(response, version) {
    switch (version) {
      case '1.0':
        expect(response).toHaveProperty('id');
        expect(response).toHaveProperty('name');
        expect(response).not.toHaveProperty('data');
        break;
        
      case '1.1':
        expect(response).toHaveProperty('id');
        expect(response).toHaveProperty('first_name');
        expect(response).toHaveProperty('last_name');
        expect(response).not.toHaveProperty('data');
        break;
        
      case '2.0':
        expect(response).toHaveProperty('data');
        expect(response).toHaveProperty('meta');
        expect(response.data).toHaveProperty('attributes');
        break;
    }
  }
});
```

### Regression Testing Suite

```javascript
// tests/compatibility/regressionTests.js
class RegressionTestSuite {
  constructor(baseUrl) {
    this.baseUrl = baseUrl;
    this.knownCompatibilityIssues = new Map();
  }
  
  async runFullCompatibilityTest() {
    const versions = ['1.0', '1.1', '2.0'];
    const testResults = new Map();
    
    for (const version of versions) {
      console.log(`🧪 Testing compatibility for version ${version}`);
      
      const results = await this.testVersionCompatibility(version);
      testResults.set(version, results);
      
      // Check for regressions
      const regressions = this.detectRegressions(version, results);
      if (regressions.length > 0) {
        console.warn(`⚠️ Regressions detected in version ${version}:`, regressions);
      }
    }
    
    return this.generateCompatibilityReport(testResults);
  }
  
  async testVersionCompatibility(version) {
    const tests = [
      this.testResponseStructure,
      this.testFieldPresence,
      this.testDataTypes,
      this.testErrorFormats,
      this.testPaginationCompatibility,
      this.testFilteringCompatibility
    ];
    
    const results = [];
    
    for (const test of tests) {
      try {
        const result = await test.call(this, version);
        results.push({
          test: test.name,
          status: 'passed',
          version,
          ...result
        });
      } catch (error) {
        results.push({
          test: test.name,
          status: 'failed',
          version,
          error: error.message,
          stack: error.stack
        });
      }
    }
    
    return results;
  }
  
  async testResponseStructure(version) {
    const response = await fetch(`${this.baseUrl}/users?limit=1`, {
      headers: { 'Accept-Version': version }
    });
    
    const data = await response.json();
    
    // Version-specific structure validation
    const expectations = {
      '1.0': () => Array.isArray(data),
      '1.1': () => Array.isArray(data),
      '2.0': () => data.data && data.meta
    };
    
    const validator = expectations[version];
    if (!validator || !validator()) {
      throw new Error(`Invalid response structure for version ${version}`);
    }
    
    return { responseStructureValid: true };
  }
  
  async testFieldPresence(version) {
    const response = await fetch(`${this.baseUrl}/users?limit=1`, {
      headers: { 'Accept-Version': version }
    });
    
    const data = await response.json();
    const firstUser = version === '2.0' ? data.data[0] : data[0];
    
    if (!firstUser) {
      throw new Error('No user data returned');
    }
    
    // Version-specific field expectations
    const requiredFields = {
      '1.0': ['id', 'name', 'email'],
      '1.1': ['id', 'first_name', 'last_name', 'email'],
      '2.0': ['id', 'type', 'attributes']
    };
    
    const fields = requiredFields[version];
    const missingFields = fields.filter(field => !firstUser.hasOwnProperty(field));
    
    if (missingFields.length > 0) {
      throw new Error(`Missing required fields: ${missingFields.join(', ')}`);
    }
    
    return { requiredFieldsPresent: true, fieldCount: Object.keys(firstUser).length };
  }
  
  async testDataTypes(version) {
    const response = await fetch(`${this.baseUrl}/users?limit=1`, {
      headers: { 'Accept-Version': version }
    });
    
    const data = await response.json();
    const firstUser = version === '2.0' ? data.data[0] : data[0];
    
    // Type validations
    const typeValidations = {
      '1.0': {
        id: (val) => typeof val === 'number',
        name: (val) => typeof val === 'string',
        email: (val) => typeof val === 'string'
      },
      '1.1': {
        id: (val) => typeof val === 'number',
        first_name: (val) => typeof val === 'string',
        last_name: (val) => typeof val === 'string',
        email: (val) => typeof val === 'string'
      },
      '2.0': {
        id: (val) => typeof val === 'number',
        type: (val) => typeof val === 'string',
        attributes: (val) => typeof val === 'object'
      }
    };
    
    const validations = typeValidations[version];
    const typeErrors = [];
    
    for (const [field, validator] of Object.entries(validations)) {
      if (firstUser.hasOwnProperty(field) && !validator(firstUser[field])) {
        typeErrors.push(`${field} has invalid type`);
      }
    }
    
    if (typeErrors.length > 0) {
      throw new Error(`Type validation errors: ${typeErrors.join(', ')}`);
    }
    
    return { dataTypesValid: true };
  }
  
  async testErrorFormats(version) {
    // Test 404 error format
    const response = await fetch(`${this.baseUrl}/users/999999`, {
      headers: { 'Accept-Version': version }
    });
    
    if (response.status !== 404) {
      throw new Error(`Expected 404 status, got ${response.status}`);
    }
    
    const errorData = await response.json();
    
    // Version-specific error format validation
    const errorValidations = {
      '1.0': () => typeof errorData === 'string' || (errorData.error && typeof errorData.error === 'string'),
      '1.1': () => errorData.error && errorData.code,
      '2.0': () => errorData.error && errorData.error.code && errorData.error.message
    };
    
    const validator = errorValidations[version];
    if (!validator || !validator()) {
      throw new Error(`Invalid error format for version ${version}`);
    }
    
    return { errorFormatValid: true };
  }
  
  async testPaginationCompatibility(version) {
    const response = await fetch(`${this.baseUrl}/users?page=1&limit=5`, {
      headers: { 'Accept-Version': version }
    });
    
    const data = await response.json();
    
    // Check pagination handling
    if (version === '2.0') {
      if (!data.meta || typeof data.meta.count !== 'number') {
        throw new Error('Missing pagination metadata in v2.0');
      }
    } else {
      // V1.x should still handle pagination parameters gracefully
      const users = Array.isArray(data) ? data : data.data;
      if (users.length > 5) {
        throw new Error('Pagination limit not respected');
      }
    }
    
    return { paginationWorking: true };
  }
  
  async testFilteringCompatibility(version) {
    const response = await fetch(`${this.baseUrl}/users?email=test@example.com`, {
      headers: { 'Accept-Version': version }
    });
    
    if (!response.ok) {
      throw new Error(`Filter request failed: ${response.status}`);
    }
    
    const data = await response.json();
    const users = version === '2.0' ? data.data : data;
    
    // Verify filtering works (even if no results)
    if (!Array.isArray(users)) {
      throw new Error('Filtering response not an array');
    }
    
    return { filteringWorking: true, resultCount: users.length };
  }
  
  detectRegressions(version, results) {
    const regressions = [];
    const knownIssues = this.knownCompatibilityIssues.get(version) || [];
    
    results.forEach(result => {
      if (result.status === 'failed') {
        // Check if this is a new issue
        const isKnownIssue = knownIssues.some(issue => 
          issue.test === result.test && issue.error === result.error
        );
        
        if (!isKnownIssue) {
          regressions.push({
            test: result.test,
            error: result.error,
            version
          });
        }
      }
    });
    
    return regressions;
  }
  
  generateCompatibilityReport(testResults) {
    const report = {
      timestamp: new Date().toISOString(),
      summary: {
        totalVersions: testResults.size,
        passedVersions: 0,
        failedVersions: 0
      },
      versions: {},
      recommendations: []
    };
    
    for (const [version, results] of testResults) {
      const passed = results.filter(r => r.status === 'passed').length;
      const total = results.length;
      
      report.versions[version] = {
        testsRun: total,
        testsPassed: passed,
        testsFailed: total - passed,
        successRate: Math.round((passed / total) * 100),
        details: results
      };
      
      if (passed === total) {
        report.summary.passedVersions++;
      } else {
        report.summary.failedVersions++;
        
        // Add recommendations for failed versions
        const failedTests = results.filter(r => r.status === 'failed');
        failedTests.forEach(test => {
          report.recommendations.push({
            version,
            test: test.test,
            issue: test.error,
            suggestion: this.generateSuggestion(test.test, test.error)
          });
        });
      }
    }
    
    return report;
  }
  
  generateSuggestion(testName, error) {
    const suggestions = {
      'testResponseStructure': 'Review response formatting middleware for version consistency',
      'testFieldPresence': 'Ensure all required fields are included in version-specific responses',
      'testDataTypes': 'Validate data type conversions in presentation layer',
      'testErrorFormats': 'Standardize error response formats across versions',
      'testPaginationCompatibility': 'Verify pagination logic handles all version requirements',
      'testFilteringCompatibility': 'Check query parameter processing for version compatibility'
    };
    
    return suggestions[testName] || 'Review implementation for compatibility issues';
  }
}

// Usage
const regressionTester = new RegressionTestSuite('https://api.example.com');
regressionTester.runFullCompatibilityTest()
  .then(report => {
    console.log('📊 Compatibility Test Report:');
    console.log(JSON.stringify(report, null, 2));
    
    if (report.summary.failedVersions > 0) {
      process.exit(1); // Fail CI/CD pipeline if compatibility issues found
    }
  })
  .catch(error => {
    console.error('Compatibility testing failed:', error);
    process.exit(1);
  });
```

## 🛡️ Advanced Compatibility Techniques

### Graceful Field Deprecation

```javascript
class FieldDeprecationHandler {
  constructor() {
    this.deprecatedFields = new Map();
    this.fieldMappings = new Map();
  }
  
  addDeprecation(field, replacement, version, sunsetVersion) {
    this.deprecatedFields.set(field, {
      replacement,
      deprecatedInVersion: version,
      sunsetVersion,
      warningCount: 0
    });
    
    if (replacement) {
      this.fieldMappings.set(field, replacement);
    }
  }
  
  processResponse(data, version, req) {
    if (!data || typeof data !== 'object') return data;
    
    const processedData = { ...data };
    
    // Handle deprecated fields
    for (const [field, info] of this.deprecatedFields) {
      if (this.shouldIncludeDeprecatedField(field, version, info)) {
        const replacementValue = this.getReplacementValue(data, info.replacement);
        if (replacementValue !== undefined) {
          processedData[field] = replacementValue;
          
          // Add deprecation warning
          this.addDeprecationWarning(req.res, field, info);
        }
      }
    }
    
    return processedData;
  }
  
  shouldIncludeDeprecatedField(field, version, info) {
    // Include if version is before sunset version
    return this.compareVersions(version, info.sunsetVersion) < 0;
  }
  
  getReplacementValue(data, replacementField) {
    if (!replacementField) return undefined;
    
    // Handle nested field access
    const fieldPath = replacementField.split('.');
    let value = data;
    
    for (const segment of fieldPath) {
      if (value && typeof value === 'object' && value.hasOwnProperty(segment)) {
        value = value[segment];
      } else {
        return undefined;
      }
    }
    
    return value;
  }
  
  addDeprecationWarning(res, field, info) {
    const warningMessage = `Field '${field}' is deprecated since version ${info.deprecatedInVersion}. ` +
                          `Will be removed in version ${info.sunsetVersion}. ` +
                          (info.replacement ? `Use '${info.replacement}' instead.` : 'No replacement available.');
    
    res.set('Warning', `299 - "${warningMessage}"`);
    
    // Log for analytics
    info.warningCount++;
    console.warn(`Deprecated field usage: ${field} (count: ${info.warningCount})`);
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
const deprecationHandler = new FieldDeprecationHandler();

// Configure field deprecations
deprecationHandler.addDeprecation('profile_url', 'avatar_url', '1.1', '2.0');
deprecationHandler.addDeprecation('full_name', 'name', '1.5', '2.0');
deprecationHandler.addDeprecation('created', 'created_at', '1.0', '1.5');

// Middleware
app.use((req, res, next) => {
  const originalJson = res.json.bind(res);
  
  res.json = (data) => {
    const processedData = deprecationHandler.processResponse(data, req.apiVersion, { res });
    return originalJson(processedData);
  };
  
  next();
});
```

### Version-Aware Caching

```javascript
class VersionAwareCacheManager {
  constructor(cacheClient) {
    this.cache = cacheClient;
    this.versionTags = new Map();
  }
  
  generateCacheKey(baseKey, version, params = {}) {
    const paramString = Object.keys(params)
      .sort()
      .map(key => `${key}:${params[key]}`)
      .join('|');
    
    return `${baseKey}:v${version}:${paramString}`;
  }
  
  async get(baseKey, version, params = {}) {
    const cacheKey = this.generateCacheKey(baseKey, version, params);
    
    try {
      const cached = await this.cache.get(cacheKey);
      if (cached) {
        return JSON.parse(cached);
      }
    } catch (error) {
      console.warn('Cache get error:', error.message);
    }
    
    return null;
  }
  
  async set(baseKey, version, params = {}, data, ttl = 300) {
    const cacheKey = this.generateCacheKey(baseKey, version, params);
    
    try {
      await this.cache.setex(cacheKey, ttl, JSON.stringify(data));
      
      // Track version tags for selective invalidation
      this.trackVersionTag(version, cacheKey);
    } catch (error) {
      console.warn('Cache set error:', error.message);
    }
  }
  
  trackVersionTag(version, cacheKey) {
    if (!this.versionTags.has(version)) {
      this.versionTags.set(version, new Set());
    }
    this.versionTags.get(version).add(cacheKey);
  }
  
  async invalidateVersion(version) {
    const keys = this.versionTags.get(version);
    if (!keys || keys.size === 0) return;
    
    try {
      const keyArray = Array.from(keys);
      if (keyArray.length > 0) {
        await this.cache.del(...keyArray);
        console.log(`Invalidated ${keyArray.length} cache entries for version ${version}`);
      }
      
      // Clear the tag tracking
      this.versionTags.delete(version);
    } catch (error) {
      console.warn('Cache invalidation error:', error.message);
    }
  }
  
  async invalidateAll() {
    try {
      const allKeys = new Set();
      for (const keys of this.versionTags.values()) {
        keys.forEach(key => allKeys.add(key));
      }
      
      if (allKeys.size > 0) {
        await this.cache.del(...Array.from(allKeys));
        console.log(`Invalidated ${allKeys.size} total cache entries`);
      }
      
      this.versionTags.clear();
    } catch (error) {
      console.warn('Full cache invalidation error:', error.message);
    }
  }
  
  getCacheStats() {
    const stats = {
      totalVersions: this.versionTags.size,
      versions: {}
    };
    
    for (const [version, keys] of this.versionTags) {
      stats.versions[version] = {
        cachedEntries: keys.size,
        sampleKeys: Array.from(keys).slice(0, 5) // Show first 5 keys as samples
      };
    }
    
    return stats;
  }
}

// Usage
const cacheManager = new VersionAwareCacheManager(redisClient);

// Middleware for cache handling
app.use(async (req, res, next) => {
  if (req.method !== 'GET') return next();
  
  const cacheKey = req.path.replace('/api/', '');
  const version = req.apiVersion;
  const cached = await cacheManager.get(cacheKey, version, req.query);
  
  if (cached) {
    res.set('X-Cache', 'HIT');
    return res.json(cached);
  }
  
  // Store original json method
  const originalJson = res.json.bind(res);
  
  res.json = (data) => {
    // Cache the response
    cacheManager.set(cacheKey, version, req.query, data, 300);
    res.set('X-Cache', 'MISS');
    return originalJson(data);
  };
  
  next();
});
```

## 📈 Monitoring Compatibility Health

### Compatibility Metrics Dashboard

```javascript
class CompatibilityMetrics {
  constructor() {
    this.metrics = {
      versionUsage: new Map(),
      compatibilityErrors: new Map(),
      deprecationWarnings: new Map(),
      fieldUsage: new Map()
    };
  }
  
  trackVersionUsage(version, endpoint, success = true) {
    const key = `${version}:${endpoint}`;
    
    if (!this.metrics.versionUsage.has(key)) {
      this.metrics.versionUsage.set(key, {
        requests: 0,
        errors: 0,
        lastUsed: null
      });
    }
    
    const stats = this.metrics.versionUsage.get(key);
    stats.requests++;
    stats.lastUsed = new Date();
    
    if (!success) {
      stats.errors++;
    }
  }
  
  trackCompatibilityError(version, error, context) {
    const key = `${version}:${error.code || 'UNKNOWN'}`;
    
    if (!this.metrics.compatibilityErrors.has(key)) {
      this.metrics.compatibilityErrors.set(key, {
        count: 0,
        examples: [],
        firstSeen: new Date(),
        lastSeen: null
      });
    }
    
    const errorStats = this.metrics.compatibilityErrors.get(key);
    errorStats.count++;
    errorStats.lastSeen = new Date();
    
    // Keep last 5 examples
    errorStats.examples.push({
      message: error.message,
      context,
      timestamp: new Date()
    });
    
    if (errorStats.examples.length > 5) {
      errorStats.examples.shift();
    }
  }
  
  trackDeprecationWarning(version, field, replacement) {
    const key = `${version}:${field}`;
    
    if (!this.metrics.deprecationWarnings.has(key)) {
      this.metrics.deprecationWarnings.set(key, {
        count: 0,
        field,
        replacement,
        firstWarning: new Date(),
        lastWarning: null
      });
    }
    
    const warning = this.metrics.deprecationWarnings.get(key);
    warning.count++;
    warning.lastWarning = new Date();
  }
  
  generateHealthReport() {
    const now = new Date();
    const dayAgo = new Date(now.getTime() - 24 * 60 * 60 * 1000);
    
    return {
      timestamp: now.toISOString(),
      summary: {
        activeVersions: this.getActiveVersions(),
        totalRequests: this.getTotalRequests(),
        errorRate: this.calculateErrorRate(),
        deprecationWarnings: this.metrics.deprecationWarnings.size
      },
      versionHealth: this.getVersionHealthScores(),
      topCompatibilityIssues: this.getTopCompatibilityIssues(),
      deprecationReport: this.getDeprecationReport(),
      recommendations: this.generateRecommendations()
    };
  }
  
  getActiveVersions() {
    const versions = new Set();
    for (const [key] of this.metrics.versionUsage) {
      const version = key.split(':')[0];
      versions.add(version);
    }
    return Array.from(versions);
  }
  
  getTotalRequests() {
    let total = 0;
    for (const [, stats] of this.metrics.versionUsage) {
      total += stats.requests;
    }
    return total;
  }
  
  calculateErrorRate() {
    let totalRequests = 0;
    let totalErrors = 0;
    
    for (const [, stats] of this.metrics.versionUsage) {
      totalRequests += stats.requests;
      totalErrors += stats.errors;
    }
    
    return totalRequests > 0 ? (totalErrors / totalRequests) * 100 : 0;
  }
  
  getVersionHealthScores() {
    const scores = {};
    
    for (const version of this.getActiveVersions()) {
      let totalRequests = 0;
      let totalErrors = 0;
      let endpointCount = 0;
      
      for (const [key, stats] of this.metrics.versionUsage) {
        if (key.startsWith(`${version}:`)) {
          totalRequests += stats.requests;
          totalErrors += stats.errors;
          endpointCount++;
        }
      }
      
      const errorRate = totalRequests > 0 ? (totalErrors / totalRequests) * 100 : 0;
      const healthScore = Math.max(0, 100 - errorRate);
      
      scores[version] = {
        healthScore: Math.round(healthScore),
        totalRequests,
        errorRate: Math.round(errorRate * 100) / 100,
        endpointCount
      };
    }
    
    return scores;
  }
  
  getTopCompatibilityIssues() {
    const issues = Array.from(this.metrics.compatibilityErrors.entries())
      .map(([key, stats]) => ({
        version: key.split(':')[0],
        error: key.split(':')[1],
        count: stats.count,
        lastSeen: stats.lastSeen,
        examples: stats.examples
      }))
      .sort((a, b) => b.count - a.count)
      .slice(0, 10);
    
    return issues;
  }
  
  getDeprecationReport() {
    const report = {};
    
    for (const [key, warning] of this.metrics.deprecationWarnings) {
      const version = key.split(':')[0];
      
      if (!report[version]) {
        report[version] = [];
      }
      
      report[version].push({
        field: warning.field,
        replacement: warning.replacement,
        usageCount: warning.count,
        lastUsed: warning.lastWarning
      });
    }
    
    return report;
  }
  
  generateRecommendations() {
    const recommendations = [];
    
    // High error rate recommendations
    const versionHealth = this.getVersionHealthScores();
    for (const [version, health] of Object.entries(versionHealth)) {
      if (health.errorRate > 5) {
        recommendations.push({
          type: 'error_rate',
          priority: 'high',
          message: `Version ${version} has high error rate (${health.errorRate}%). Review compatibility issues.`,
          version
        });
      }
    }
    
    // Deprecation recommendations
    const now = new Date();
    for (const [key, warning] of this.metrics.deprecationWarnings) {
      const daysSinceLastUsage = (now - warning.lastWarning) / (1000 * 60 * 60 * 24);
      
      if (warning.count > 100 && daysSinceLastUsage < 7) {
        recommendations.push({
          type: 'deprecation',
          priority: 'medium',
          message: `Field '${warning.field}' is heavily used (${warning.count} times) but deprecated. Consider migration communication.`,
          field: warning.field
        });
      }
    }
    
    return recommendations;
  }
}

// Integration with existing API
const compatibilityMetrics = new CompatibilityMetrics();

// Middleware to track metrics
app.use((req, res, next) => {
  const startTime = Date.now();
  
  res.on('finish', () => {
    const success = res.statusCode < 400;
    compatibilityMetrics.trackVersionUsage(req.apiVersion, req.path, success);
    
    if (!success) {
      compatibilityMetrics.trackCompatibilityError(req.apiVersion, {
        code: `HTTP_${res.statusCode}`,
        message: 'Request failed'
      }, {
        endpoint: req.path,
        method: req.method,
        responseTime: Date.now() - startTime
      });
    }
  });
  
  next();
});

// Health report endpoint
app.get('/api/health/compatibility', (req, res) => {
  const report = compatibilityMetrics.generateHealthReport();
  res.json(report);
});
```

---

## 🧭 Navigation

← [Migration Strategy](./migration-strategy.md) | **[Testing Strategies](./testing-strategies.md)** →

---

*Backward Compatibility Patterns | API Versioning Strategies Research | July 2025*