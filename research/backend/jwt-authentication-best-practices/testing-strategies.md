# Testing Strategies for JWT Authentication

## 🧪 Comprehensive Testing Approach

Testing JWT authentication requires covering security, functionality, performance, and edge cases. This guide provides practical testing strategies for Express.js/TypeScript JWT implementations.

## 🎯 Testing Categories

### 1. Security Testing
- Algorithm validation and manipulation attempts
- Token tampering and signature verification
- Expiration and timing attack scenarios
- Input validation and injection attempts

### 2. Functional Testing
- Authentication flow validation
- Token generation and verification
- Refresh token mechanisms
- Authorization and permission checks

### 3. Performance Testing
- Token generation/verification speed
- Memory usage under load
- Concurrent authentication handling
- Cache efficiency testing

### 4. Integration Testing
- End-to-end authentication flows
- Database integration
- External service interactions
- Cross-browser compatibility

## 🔒 Security Test Suite

### 1. Algorithm Security Tests

```typescript
// __tests__/security/jwt-algorithm.test.ts
import jwt from 'jsonwebtoken';
import { JWTService } from '../../src/services/JWTService';

describe('JWT Algorithm Security', () => {
  let jwtService: JWTService;
  
  beforeEach(() => {
    jwtService = new JWTService();
  });
  
  test('should reject tokens with algorithm none', async () => {
    // Attempt to create a token with 'none' algorithm
    const maliciousToken = Buffer.from(JSON.stringify({
      alg: 'none',
      typ: 'JWT'
    })).toString('base64url') + '.' +
    Buffer.from(JSON.stringify({
      sub: '1234567890',
      name: 'John Doe',
      iat: 1516239022
    })).toString('base64url') + '.';
    
    await expect(
      jwtService.verifyAccessToken(maliciousToken)
    ).rejects.toThrow('Token verification failed');
  });
  
  test('should reject tokens with wrong algorithm', async () => {
    // Create token with HS256 when RS256 is expected
    const wrongAlgToken = jwt.sign(
      { userId: '123', email: 'test@example.com' },
      'secret',
      { algorithm: 'HS256' }
    );
    
    await expect(
      jwtService.verifyAccessToken(wrongAlgToken)
    ).rejects.toThrow('Token verification failed');
  });
  
  test('should accept only allowed algorithms', async () => {
    const user = {
      id: '123',
      email: 'test@example.com',
      roles: ['user'],
      permissions: ['read']
    };
    
    const validToken = await jwtService.generateAccessToken(user, 'session123');
    const decoded = await jwtService.verifyAccessToken(validToken);
    
    expect(decoded.userId).toBe('123');
    expect(decoded.email).toBe('test@example.com');
  });
  
  test('should prevent key confusion attacks', async () => {
    // Attempt to use public key as HMAC secret
    const publicKey = process.env.JWT_PUBLIC_KEY!;
    
    const confusionToken = jwt.sign(
      { userId: '123', email: 'attacker@example.com' },
      publicKey,
      { algorithm: 'HS256' }
    );
    
    await expect(
      jwtService.verifyAccessToken(confusionToken)
    ).rejects.toThrow();
  });
});
```

### 2. Token Manipulation Tests

```typescript
// __tests__/security/jwt-tampering.test.ts
describe('JWT Token Tampering', () => {
  test('should reject tokens with modified payload', async () => {
    const user = { 
      id: '123', 
      email: 'user@example.com',
      roles: ['user'],
      permissions: ['read']
    };
    
    const validToken = await jwtService.generateAccessToken(user, 'session123');
    const [header, payload, signature] = validToken.split('.');
    
    // Modify payload to escalate privileges
    const decodedPayload = JSON.parse(
      Buffer.from(payload, 'base64url').toString()
    );
    decodedPayload.roles = ['admin'];
    
    const modifiedPayload = Buffer.from(
      JSON.stringify(decodedPayload)
    ).toString('base64url');
    
    const tamperedToken = `${header}.${modifiedPayload}.${signature}`;
    
    await expect(
      jwtService.verifyAccessToken(tamperedToken)
    ).rejects.toThrow('invalid signature');
  });
  
  test('should reject tokens with modified header', async () => {
    const validToken = await jwtService.generateAccessToken(
      { id: '123', email: 'test@example.com', roles: ['user'], permissions: ['read'] },
      'session123'
    );
    
    const [header, payload, signature] = validToken.split('.');
    
    // Modify header algorithm
    const modifiedHeader = Buffer.from(JSON.stringify({
      alg: 'none',
      typ: 'JWT'
    })).toString('base64url');
    
    const tamperedToken = `${modifiedHeader}.${payload}.${signature}`;
    
    await expect(
      jwtService.verifyAccessToken(tamperedToken)
    ).rejects.toThrow();
  });
  
  test('should reject tokens with invalid signature', async () => {
    const validToken = await jwtService.generateAccessToken(
      { id: '123', email: 'test@example.com', roles: ['user'], permissions: ['read'] },
      'session123'
    );
    
    const [header, payload] = validToken.split('.');
    const fakeSignature = 'fake-signature';
    
    const tamperedToken = `${header}.${payload}.${fakeSignature}`;
    
    await expect(
      jwtService.verifyAccessToken(tamperedToken)
    ).rejects.toThrow('invalid signature');
  });
});
```

### 3. Timing Attack Tests

```typescript
// __tests__/security/timing-attacks.test.ts
describe('JWT Timing Attack Prevention', () => {
  test('should have consistent timing for invalid tokens', async () => {
    const timings: number[] = [];
    const iterations = 100;
    
    for (let i = 0; i < iterations; i++) {
      const invalidToken = `invalid.token.${i}`;
      const start = process.hrtime.bigint();
      
      try {
        await jwtService.verifyAccessToken(invalidToken);
      } catch (error) {
        // Expected to fail
      }
      
      const end = process.hrtime.bigint();
      timings.push(Number(end - start) / 1e6); // Convert to milliseconds
    }
    
    // Check that timing variance is within acceptable range
    const mean = timings.reduce((a, b) => a + b, 0) / timings.length;
    const variance = timings.reduce((a, b) => a + Math.pow(b - mean, 2), 0) / timings.length;
    const stdDev = Math.sqrt(variance);
    
    // Standard deviation should be less than 50% of mean (adjust based on requirements)
    expect(stdDev / mean).toBeLessThan(0.5);
  });
});
```

## ⚡ Performance Testing

### 1. Token Generation Performance

```typescript
// __tests__/performance/jwt-generation.test.ts
describe('JWT Generation Performance', () => {
  test('should generate tokens within acceptable time', async () => {
    const user = {
      id: '123',
      email: 'test@example.com',
      roles: ['user'],
      permissions: ['read', 'write']
    };
    
    const iterations = 1000;
    const start = process.hrtime.bigint();
    
    const promises = Array.from({ length: iterations }, (_, i) =>
      jwtService.generateAccessToken(user, `session${i}`)
    );
    
    await Promise.all(promises);
    
    const end = process.hrtime.bigint();
    const totalTime = Number(end - start) / 1e6; // Convert to milliseconds
    const avgTime = totalTime / iterations;
    
    // Should generate token in less than 10ms on average
    expect(avgTime).toBeLessThan(10);
    
    console.log(`Average token generation time: ${avgTime.toFixed(2)}ms`);
  });
  
  test('should verify tokens within acceptable time', async () => {
    const user = {
      id: '123',
      email: 'test@example.com',
      roles: ['user'],
      permissions: ['read']
    };
    
    // Pre-generate tokens
    const tokens = await Promise.all(
      Array.from({ length: 1000 }, (_, i) =>
        jwtService.generateAccessToken(user, `session${i}`)
      )
    );
    
    const start = process.hrtime.bigint();
    
    const promises = tokens.map(token => jwtService.verifyAccessToken(token));
    await Promise.all(promises);
    
    const end = process.hrtime.bigint();
    const totalTime = Number(end - start) / 1e6;
    const avgTime = totalTime / tokens.length;
    
    // Should verify token in less than 5ms on average
    expect(avgTime).toBeLessThan(5);
    
    console.log(`Average token verification time: ${avgTime.toFixed(2)}ms`);
  });
});
```

### 2. Memory Usage Testing

```typescript
// __tests__/performance/memory-usage.test.ts
describe('JWT Memory Usage', () => {
  test('should not leak memory during token operations', async () => {
    const getMemoryUsage = () => process.memoryUsage().heapUsed / 1024 / 1024; // MB
    
    const user = {
      id: '123',
      email: 'test@example.com',
      roles: ['user'],
      permissions: ['read']
    };
    
    const initialMemory = getMemoryUsage();
    
    // Perform many token operations
    for (let i = 0; i < 10000; i++) {
      const token = await jwtService.generateAccessToken(user, `session${i}`);
      await jwtService.verifyAccessToken(token);
      
      // Force garbage collection every 1000 iterations
      if (i % 1000 === 0 && global.gc) {
        global.gc();
      }
    }
    
    const finalMemory = getMemoryUsage();
    const memoryIncrease = finalMemory - initialMemory;
    
    // Memory increase should be minimal (less than 50MB)
    expect(memoryIncrease).toBeLessThan(50);
    
    console.log(`Memory increase: ${memoryIncrease.toFixed(2)}MB`);
  });
});
```

## 🔧 Integration Testing

### 1. End-to-End Authentication Flow

```typescript
// __tests__/integration/auth-flow.test.ts
import request from 'supertest';
import { createApp } from '../../src/app';

describe('Authentication Flow Integration', () => {
  let app: any;
  
  beforeEach(() => {
    app = createApp();
  });
  
  test('complete authentication flow', async () => {
    // 1. Login
    const loginResponse = await request(app)
      .post('/api/auth/login')
      .send({
        email: 'test@example.com',
        password: 'password123'
      })
      .expect(200);
    
    expect(loginResponse.body.success).toBe(true);
    expect(loginResponse.body.user).toBeDefined();
    
    // Extract cookies
    const cookies = loginResponse.headers['set-cookie'];
    const accessTokenCookie = cookies.find(cookie => cookie.startsWith('accessToken='));
    const refreshTokenCookie = cookies.find(cookie => cookie.startsWith('refreshToken='));
    
    expect(accessTokenCookie).toBeDefined();
    expect(refreshTokenCookie).toBeDefined();
    
    // 2. Access protected route
    const profileResponse = await request(app)
      .get('/api/profile')
      .set('Cookie', cookies)
      .expect(200);
    
    expect(profileResponse.body.user.userId).toBe(loginResponse.body.user.id);
    
    // 3. Refresh token
    const refreshResponse = await request(app)
      .post('/api/auth/refresh')
      .set('Cookie', cookies)
      .expect(200);
    
    expect(refreshResponse.body.success).toBe(true);
    
    // 4. Logout
    const logoutResponse = await request(app)
      .post('/api/auth/logout')
      .set('Cookie', cookies)
      .expect(200);
    
    expect(logoutResponse.body.success).toBe(true);
    
    // 5. Verify access is revoked
    await request(app)
      .get('/api/profile')
      .set('Cookie', cookies)
      .expect(401);
  });
  
  test('should handle concurrent authentication requests', async () => {
    const loginRequests = Array.from({ length: 10 }, () =>
      request(app)
        .post('/api/auth/login')
        .send({
          email: 'test@example.com',
          password: 'password123'
        })
    );
    
    const responses = await Promise.all(loginRequests);
    
    // All requests should succeed
    responses.forEach(response => {
      expect(response.status).toBe(200);
      expect(response.body.success).toBe(true);
    });
  });
});
```

### 2. Error Handling Tests

```typescript
// __tests__/integration/error-handling.test.ts
describe('Authentication Error Handling', () => {
  test('should handle malformed requests gracefully', async () => {
    // Test various malformed inputs
    const malformedRequests = [
      { email: 'invalid-email', password: 'short' },
      { email: '', password: 'password123' },
      { email: 'test@example.com', password: '' },
      { email: null, password: 'password123' },
      { email: 'test@example.com', password: null },
      {},
      'invalid-json'
    ];
    
    for (const body of malformedRequests) {
      const response = await request(app)
        .post('/api/auth/login')
        .send(body);
      
      // Should return 400 Bad Request, not 500 Internal Server Error
      expect(response.status).toBe(400);
      expect(response.body.error).toBeDefined();
    }
  });
  
  test('should not leak sensitive information in errors', async () => {
    // Test with non-existent user
    const response = await request(app)
      .post('/api/auth/login')
      .send({
        email: 'nonexistent@example.com',
        password: 'password123'
      })
      .expect(401);
    
    // Should return generic error, not reveal user existence
    expect(response.body.error).toBe('Invalid credentials');
    expect(response.body.error).not.toContain('user not found');
    expect(response.body.error).not.toContain('email');
  });
});
```

## 🔍 Security Penetration Testing

### 1. Automated Security Tests

```typescript
// __tests__/security/penetration.test.ts
describe('JWT Security Penetration Testing', () => {
  test('should resist common JWT attacks', async () => {
    const attacks = [
      // Algorithm confusion
      { type: 'alg_confusion', token: 'eyJhbGciOiJub25lIiwidHlwIjoiSldUIn0.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.' },
      
      // Key confusion
      { type: 'key_confusion', token: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c' },
      
      // Blank password
      { type: 'blank_password', token: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.' },
      
      // Invalid structure
      { type: 'invalid_structure', token: 'invalid.token' },
      { type: 'missing_parts', token: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0' },
    ];
    
    for (const attack of attacks) {
      await expect(
        jwtService.verifyAccessToken(attack.token)
      ).rejects.toThrow();
    }
  });
  
  test('should handle extremely long tokens', async () => {
    // Generate a very long token
    const longPayload = {
      userId: '123',
      data: 'x'.repeat(100000) // 100KB of data
    };
    
    // Should either reject during generation or verification
    await expect(async () => {
      const longToken = jwt.sign(longPayload, process.env.JWT_PRIVATE_KEY!, {
        algorithm: 'RS256'
      });
      
      await jwtService.verifyAccessToken(longToken);
    }).rejects.toThrow();
  });
});
```

## 📊 Test Coverage and Reporting

### 1. Coverage Configuration

```json
// jest.config.js
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  collectCoverageFrom: [
    'src/**/*.ts',
    '!src/**/*.d.ts',
    '!src/types/**/*'
  ],
  coverageReporters: ['text', 'lcov', 'html'],
  coverageThresholds: {
    global: {
      branches: 80,
      functions: 80,
      lines: 80,
      statements: 80
    },
    './src/services/JWTService.ts': {
      branches: 95,
      functions: 95,
      lines: 95,
      statements: 95
    },
    './src/middleware/auth.ts': {
      branches: 90,
      functions: 90,
      lines: 90,
      statements: 90
    }
  }
};
```

### 2. Security Test Report

```typescript
// scripts/security-test-report.ts
import { execSync } from 'child_process';
import fs from 'fs';

interface SecurityTestResult {
  testSuite: string;
  passed: number;
  failed: number;
  vulnerabilities: string[];
}

class SecurityTestReporter {
  private results: SecurityTestResult[] = [];
  
  async runSecurityTests(): Promise<void> {
    console.log('🔒 Running JWT Security Tests...\n');
    
    const testSuites = [
      'algorithm-security',
      'token-tampering',
      'timing-attacks',
      'penetration'
    ];
    
    for (const suite of testSuites) {
      const result = await this.runTestSuite(suite);
      this.results.push(result);
    }
    
    this.generateReport();
  }
  
  private async runTestSuite(suite: string): Promise<SecurityTestResult> {
    try {
      const output = execSync(
        `npm test -- --testNamePattern="${suite}" --json`,
        { encoding: 'utf-8' }
      );
      
      const result = JSON.parse(output);
      
      return {
        testSuite: suite,
        passed: result.numPassedTests,
        failed: result.numFailedTests,
        vulnerabilities: result.testResults
          .filter(test => test.status === 'failed')
          .map(test => test.message)
      };
      
    } catch (error) {
      return {
        testSuite: suite,
        passed: 0,
        failed: 1,
        vulnerabilities: ['Test execution failed']
      };
    }
  }
  
  private generateReport(): void {
    const totalPassed = this.results.reduce((sum, result) => sum + result.passed, 0);
    const totalFailed = this.results.reduce((sum, result) => sum + result.failed, 0);
    const total = totalPassed + totalFailed;
    
    const report = `
# JWT Security Test Report

**Generated:** ${new Date().toISOString()}

## Summary
- **Total Tests:** ${total}
- **Passed:** ${totalPassed} (${((totalPassed / total) * 100).toFixed(1)}%)
- **Failed:** ${totalFailed} (${((totalFailed / total) * 100).toFixed(1)}%)

## Test Suite Results

${this.results.map(result => `
### ${result.testSuite}
- Passed: ${result.passed}
- Failed: ${result.failed}
${result.vulnerabilities.length > 0 ? `
**Vulnerabilities Found:**
${result.vulnerabilities.map(v => `- ${v}`).join('\n')}
` : '✅ No vulnerabilities detected'}
`).join('\n')}

## Recommendations

${totalFailed > 0 ? `
⚠️ **Action Required:** ${totalFailed} security tests failed. Review and fix vulnerabilities before production deployment.
` : `
✅ **Security Status:** All security tests passed. JWT implementation appears secure.
`}
    `;
    
    fs.writeFileSync('security-test-report.md', report.trim());
    console.log('\n📋 Security test report generated: security-test-report.md');
  }
}

// Run security tests
const reporter = new SecurityTestReporter();
reporter.runSecurityTests().catch(console.error);
```

## 🚀 Continuous Security Testing

### 1. GitHub Actions Security Pipeline

```yaml
# .github/workflows/security-tests.yml
name: JWT Security Tests

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  security-tests:
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
    
    - name: Generate test keys
      run: |
        openssl genpkey -algorithm RSA -out private-key.pem -keysize 2048
        openssl rsa -pubout -in private-key.pem -out public-key.pem
    
    - name: Run security tests
      run: |
        export JWT_PRIVATE_KEY="$(cat private-key.pem)"
        export JWT_PUBLIC_KEY="$(cat public-key.pem)"
        npm run test:security
      env:
        JWT_ISSUER: "https://test.example.com"
        JWT_AUDIENCE: "test-app"
    
    - name: Upload coverage reports
      uses: codecov/codecov-action@v3
      
    - name: Security audit
      run: npm audit --audit-level high
```

---

**Navigation**
- ← Back to: [Refresh Token Strategies](./refresh-token-strategies.md)
- → Next: [Performance Optimization](./performance-optimization.md)
- ↑ Back to: [JWT Authentication Research](./README.md)