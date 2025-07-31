# Testing Security Implementations: Comprehensive Security Testing Guide

This document provides comprehensive guidance on testing security implementations in frontend applications, covering automated testing, penetration testing, vulnerability assessment, and continuous security monitoring for educational technology platforms.

## Security Testing Strategy

### 1. Security Testing Pyramid

```typescript
// Security testing layers implementation
interface SecurityTestLayer {
  level: 'unit' | 'integration' | 'system' | 'acceptance';
  testTypes: string[];
  automationLevel: 'fully' | 'partially' | 'manual';
  frequency: 'every-commit' | 'daily' | 'weekly' | 'release';
  tools: string[];
}

class SecurityTestingStrategy {
  private testLayers: SecurityTestLayer[] = [
    {
      level: 'unit',
      testTypes: [
        'Input validation tests',
        'Output encoding tests',
        'Cryptographic function tests',
        'Authentication logic tests'
      ],
      automationLevel: 'fully',
      frequency: 'every-commit',
      tools: ['Jest', 'Mocha', 'Vitest']
    },
    {
      level: 'integration',
      testTypes: [
        'API security tests',
        'Database security tests',
        'Service integration tests',
        'Authentication flow tests'
      ],
      automationLevel: 'fully',
      frequency: 'every-commit',
      tools: ['Supertest', 'Playwright', 'Newman']
    },
    {
      level: 'system',
      testTypes: [
        'End-to-end security tests',
        'Browser security tests',
        'Network security tests',
        'Configuration tests'
      ],
      automationLevel: 'partially',
      frequency: 'daily',
      tools: ['Cypress', 'Selenium', 'OWASP ZAP']
    },
    {
      level: 'acceptance',
      testTypes: [
        'Penetration testing',
        'Vulnerability assessment',
        'Compliance testing',
        'Performance security tests'
      ],
      automationLevel: 'manual',
      frequency: 'weekly',
      tools: ['Burp Suite', 'Nessus', 'Manual testing']
    }
  ];

  getTestPlan(projectPhase: 'development' | 'staging' | 'production'): SecurityTestPlan {
    const applicableLayers = this.testLayers.filter(layer => {
      switch (projectPhase) {
        case 'development':
          return ['unit', 'integration'].includes(layer.level);
        case 'staging':
          return ['unit', 'integration', 'system'].includes(layer.level);
        case 'production':
          return layer.level === 'acceptance';
        default:
          return true;
      }
    });

    return {
      phase: projectPhase,
      layers: applicableLayers,
      estimatedTime: this.calculateEstimatedTime(applicableLayers),
      requiredTools: this.getRequiredTools(applicableLayers),
      skillRequirements: this.getSkillRequirements(applicableLayers)
    };
  }

  private calculateEstimatedTime(layers: SecurityTestLayer[]): string {
    const timeEstimates = {
      unit: 2,      // 2 hours
      integration: 4, // 4 hours
      system: 8,    // 8 hours
      acceptance: 16 // 16 hours
    };

    const totalHours = layers.reduce((sum, layer) => sum + timeEstimates[layer.level], 0);
    return `${totalHours} hours`;
  }

  private getRequiredTools(layers: SecurityTestLayer[]): string[] {
    const tools = new Set<string>();
    layers.forEach(layer => {
      layer.tools.forEach(tool => tools.add(tool));
    });
    return Array.from(tools);
  }

  private getSkillRequirements(layers: SecurityTestLayer[]): string[] {
    const skillMap = {
      unit: ['JavaScript/TypeScript', 'Testing frameworks'],
      integration: ['API testing', 'Database knowledge'],
      system: ['Browser automation', 'Network knowledge'],
      acceptance: ['Security expertise', 'Penetration testing']
    };

    const skills = new Set<string>();
    layers.forEach(layer => {
      skillMap[layer.level].forEach(skill => skills.add(skill));
    });
    return Array.from(skills);
  }
}
```

### 2. Automated Security Testing

#### Unit Testing for Security Functions

```typescript
// Security unit tests
describe('Security Functions', () => {
  describe('Input Validation', () => {
    const inputValidator = new InputValidationSystem();

    test('should validate email addresses correctly', () => {
      const validEmails = [
        'user@edu.ph',
        'student@ateneo.edu',
        'faculty@up.edu.ph'
      ];

      const invalidEmails = [
        'user@gmail.com',
        'invalid-email',
        'user@malicious.com',
        'script@<script>alert()</script>.com'
      ];

      validEmails.forEach(email => {
        const result = inputValidator.validate({ email }, 'institutionalEmail');
        expect(result.isValid).toBe(true);
      });

      invalidEmails.forEach(email => {
        const result = inputValidator.validate({ email }, 'institutionalEmail');
        expect(result.isValid).toBe(false);
      });
    });

    test('should sanitize HTML content properly', () => {
      const maliciousInputs = [
        '<script>alert("XSS")</script>',
        '<img src="x" onerror="alert(1)">',
        '<iframe src="javascript:alert(\'XSS\')"></iframe>',
        '"><script>malicious()</script>',
        '<svg onload="alert(\'XSS\')">',
        'javascript:alert("XSS")'
      ];

      maliciousInputs.forEach(input => {
        const sanitized = inputValidator.sanitize(input, 'richContent');
        
        expect(sanitized).not.toContain('<script>');
        expect(sanitized).not.toContain('javascript:');
        expect(sanitized).not.toContain('onerror=');
        expect(sanitized).not.toContain('onload=');
        expect(sanitized).not.toContain('alert(');
      });
    });

    test('should preserve safe HTML content', () => {
      const safeInputs = [
        '<p>This is a <strong>safe</strong> paragraph.</p>',
        '<h1>Title</h1><p>Content with <em>emphasis</em>.</p>',
        '<ul><li>Item 1</li><li>Item 2</li></ul>'
      ];

      safeInputs.forEach(input => {
        const sanitized = inputValidator.sanitize(input, 'richContent');
        
        expect(sanitized).toContain('<p>');
        expect(sanitized).toContain('<strong>');
        expect(sanitized).toContain('<em>');
        expect(sanitized).toContain('safe');
      });
    });
  });

  describe('CSRF Protection', () => {
    const csrfManager = new CSRFTokenManager();

    test('should generate valid CSRF tokens', () => {
      const secret = csrfManager.generateSecret();
      const token = csrfManager.generateToken(secret);
      
      expect(token).toBeDefined();
      expect(token.split(':')).toHaveLength(3); // timestamp:random:signature
      
      const isValid = csrfManager.validateToken(secret, token);
      expect(isValid).toBe(true);
    });

    test('should reject invalid CSRF tokens', () => {
      const secret = csrfManager.generateSecret();
      const invalidTokens = [
        'invalid-token',
        '',
        'a:b:c', // Invalid format
        '1000000000:random:invalid-signature' // Old timestamp
      ];

      invalidTokens.forEach(token => {
        const isValid = csrfManager.validateToken(secret, token);
        expect(isValid).toBe(false);
      });
    });

    test('should reject tokens with wrong secret', () => {
      const secret1 = csrfManager.generateSecret();
      const secret2 = csrfManager.generateSecret();
      const token = csrfManager.generateToken(secret1);
      
      const isValid = csrfManager.validateToken(secret2, token);
      expect(isValid).toBe(false);
    });
  });

  describe('Authentication Token Management', () => {
    const jwtManager = new SecureJWTManager();
    
    test('should generate valid JWT tokens', async () => {
      const user = {
        id: 'user123',
        email: 'user@edu.ph',
        role: 'student',
        permissions: ['read:courses', 'submit:assignments']
      };

      const tokenPair = jwtManager.generateTokenPair(user);
      
      expect(tokenPair.accessToken).toBeDefined();
      expect(tokenPair.refreshToken).toBeDefined();
      expect(tokenPair.tokenType).toBe('Bearer');
      expect(tokenPair.expiresIn).toBe(15 * 60); // 15 minutes
    });

    test('should validate JWT tokens correctly', async () => {
      const user = {
        id: 'user123',
        email: 'user@edu.ph',
        role: 'student',
        permissions: ['read:courses']
      };

      const { accessToken } = jwtManager.generateTokenPair(user);
      const validation = await jwtManager.validateAccessToken(accessToken);
      
      expect(validation.isValid).toBe(true);
      expect(validation.payload?.sub).toBe(user.id);
      expect(validation.payload?.role).toBe(user.role);
    });

    test('should reject expired tokens', async () => {
      // Mock expired token
      const expiredToken = 'header.eyJzdWIiOiJ1c2VyMTIzIiwiZXhwIjoxMDAwfQ.signature';
      const validation = await jwtManager.validateAccessToken(expiredToken);
      
      expect(validation.isValid).toBe(false);
      expect(validation.error).toContain('expired');
    });
  });

  describe('Output Encoding', () => {
    const encoder = new ContextAwareEncoder();

    test('should encode HTML context properly', () => {
      const maliciousInput = '<script>alert("XSS")</script>';
      const encoded = encoder.encode(maliciousInput, 'html');
      
      expect(encoded).toBe('&lt;script&gt;alert(&quot;XSS&quot;)&lt;/script&gt;');
      expect(encoded).not.toContain('<script>');
    });

    test('should encode JavaScript context properly', () => {
      const maliciousInput = 'alert("XSS");//';
      const encoded = encoder.encode(maliciousInput, 'javascript');
      
      expect(encoded).toContain('\\"');
      expect(encoded).not.toContain('alert("');
    });

    test('should encode URL context properly', () => {
      const maliciousInput = 'javascript:alert("XSS")';
      const encoded = encoder.encode(maliciousInput, 'url');
      
      expect(encoded).toContain('%3A'); // Encoded colon
      expect(encoded).not.toContain('javascript:');
    });
  });
});
```

#### Integration Testing for Security APIs

```typescript
// Security integration tests
describe('Security API Integration', () => {
  let app: Application;
  let agent: request.SuperAgentTest;

  beforeAll(async () => {
    app = await createTestApp();
    agent = request.agent(app);
  });

  describe('Authentication Endpoints', () => {
    test('should authenticate valid users', async () => {
      const credentials = {
        email: 'student@edu.ph',
        password: 'SecurePass123!'
      };

      const response = await agent
        .post('/api/auth/login')
        .send(credentials)
        .expect(200);

      expect(response.body).toHaveProperty('accessToken');
      expect(response.body).toHaveProperty('refreshToken');
      expect(response.body).toHaveProperty('user');
      expect(response.body.user.email).toBe(credentials.email);
    });

    test('should reject invalid credentials', async () => {
      const invalidCredentials = [
        { email: 'student@edu.ph', password: 'wrongpassword' },
        { email: 'nonexistent@edu.ph', password: 'SecurePass123!' },
        { email: 'invalid-email', password: 'SecurePass123!' },
        { email: '', password: '' }
      ];

      for (const credentials of invalidCredentials) {
        const response = await agent
          .post('/api/auth/login')
          .send(credentials)
          .expect(401);

        expect(response.body.success).toBe(false);
        expect(response.body).toHaveProperty('message');
      }
    });

    test('should implement rate limiting on login attempts', async () => {
      const credentials = {
        email: 'student@edu.ph',
        password: 'wrongpassword'
      };

      // Make multiple failed login attempts
      for (let i = 0; i < 5; i++) {
        await agent
          .post('/api/auth/login')
          .send(credentials)
          .expect(401);
      }

      // 6th attempt should be rate limited
      const response = await agent
        .post('/api/auth/login')
        .send(credentials)
        .expect(429);

      expect(response.body.message).toContain('rate limit');
    });

    test('should refresh tokens correctly', async () => {
      // First, login to get tokens
      const loginResponse = await agent
        .post('/api/auth/login')
        .send({
          email: 'student@edu.ph',
          password: 'SecurePass123!'
        })
        .expect(200);

      const { refreshToken } = loginResponse.body;

      // Use refresh token to get new access token
      const refreshResponse = await agent
        .post('/api/auth/refresh')
        .send({ refreshToken })
        .expect(200);

      expect(refreshResponse.body).toHaveProperty('accessToken');
      expect(refreshResponse.body.accessToken).not.toBe(loginResponse.body.accessToken);
    });
  });

  describe('CSRF Protection', () => {
    let csrfToken: string;
    let authenticatedAgent: request.SuperAgentTest;

    beforeEach(async () => {
      authenticatedAgent = request.agent(app);
      
      // Login first
      await authenticatedAgent
        .post('/api/auth/login')
        .send({
          email: 'student@edu.ph',
          password: 'SecurePass123!'
        });

      // Get CSRF token
      const tokenResponse = await authenticatedAgent
        .get('/api/csrf-token')
        .expect(200);

      csrfToken = tokenResponse.body.csrfToken;
    });

    test('should require CSRF token for state-changing requests', async () => {
      const response = await authenticatedAgent
        .post('/api/user/profile')
        .send({ name: 'Updated Name' })
        .expect(403);

      expect(response.body.code).toBe('CSRF_TOKEN_MISSING');
    });

    test('should accept requests with valid CSRF token', async () => {
      const response = await authenticatedAgent
        .post('/api/user/profile')
        .set('X-CSRF-Token', csrfToken)
        .send({ name: 'Updated Name' })
        .expect(200);

      expect(response.body.success).toBe(true);
    });

    test('should reject requests with invalid CSRF token', async () => {
      const response = await authenticatedAgent
        .post('/api/user/profile')
        .set('X-CSRF-Token', 'invalid-token')
        .send({ name: 'Updated Name' })
        .expect(403);

      expect(response.body.code).toBe('CSRF_TOKEN_INVALID');
    });
  });

  describe('Input Validation Endpoints', () => {
    test('should validate and sanitize user profile updates', async () => {
      const maliciousProfile = {
        name: '<script>alert("XSS")</script>John Doe',
        bio: '<img src="x" onerror="alert(\'XSS\')">Student bio',
        email: 'invalid-email-format'
      };

      const response = await agent
        .post('/api/user/profile')
        .set('Authorization', 'Bearer ' + await getValidToken())
        .set('X-CSRF-Token', await getCSRFToken())
        .send(maliciousProfile)
        .expect(400);

      expect(response.body.errors).toBeDefined();
      expect(response.body.errors.some((e: any) => e.field === 'email')).toBe(true);
    });

    test('should accept valid profile data', async () => {
      const validProfile = {
        name: 'John Doe',
        bio: 'I am a <strong>dedicated</strong> student.',
        email: 'john@edu.ph'
      };

      const response = await agent
        .post('/api/user/profile')
        .set('Authorization', 'Bearer ' + await getValidToken())
        .set('X-CSRF-Token', await getCSRFToken())
        .send(validProfile)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.user.name).toBe(validProfile.name);
    });
  });
});
```

### 3. Browser-Based Security Testing

#### Playwright Security Tests

```typescript
// Browser-based security testing with Playwright
import { test, expect, Page, BrowserContext } from '@playwright/test';

describe('Browser Security Tests', () => {
  let page: Page;
  let context: BrowserContext;

  test.beforeEach(async ({ browser }) => {
    context = await browser.newContext();
    page = await context.newPage();
    
    // Monitor console errors and CSP violations
    page.on('console', msg => {
      if (msg.type() === 'error') {
        console.log('Browser error:', msg.text());
      }
    });

    page.on('pageerror', error => {
      console.log('Page error:', error.message);
    });
  });

  test('should enforce Content Security Policy', async () => {
    const cspViolations: any[] = [];
    
    // Monitor network requests for CSP violations
    page.on('response', response => {
      if (response.url().includes('csp-violation-report')) {
        cspViolations.push(response);
      }
    });

    await page.goto('/test-page');

    // Try to inject inline script (should be blocked by CSP)
    await page.evaluate(() => {
      try {
        const script = document.createElement('script');
        script.innerHTML = 'console.log("This should be blocked by CSP");';
        document.head.appendChild(script);
      } catch (error) {
        console.log('Script injection blocked:', error);
      }
    });

    // Wait for potential CSP violation reports
    await page.waitForTimeout(1000);

    // Verify CSP headers are present
    const response = await page.goto('/');
    const cspHeader = response?.headers()['content-security-policy'];
    expect(cspHeader).toBeDefined();
    expect(cspHeader).toContain("default-src 'self'");
  });

  test('should prevent XSS in user input fields', async () => {
    await page.goto('/profile');
    
    const maliciousInputs = [
      '<script>alert("XSS")</script>',
      '<img src="x" onerror="alert(\'XSS\')">',
      'javascript:alert("XSS")',
      '"><script>malicious()</script>'
    ];

    for (const input of maliciousInputs) {
      await page.fill('#bio-field', input);
      await page.click('#save-button');

      // Check that the malicious content is not executed
      const bioContent = await page.textContent('#bio-display');
      expect(bioContent).not.toContain('<script>');
      expect(bioContent).not.toContain('javascript:');

      // Verify no alert dialogs appear
      const dialogs = await page.locator('dialog').count();
      expect(dialogs).toBe(0);
    }
  });

  test('should secure authentication flow', async () => {
    await page.goto('/login');

    // Test failed login attempts
    for (let i = 0; i < 3; i++) {
      await page.fill('#email', 'user@edu.ph');
      await page.fill('#password', 'wrongpassword');
      await page.click('#login-button');

      await expect(page.locator('.error-message')).toBeVisible();
    }

    // Test successful login
    await page.fill('#email', 'student@edu.ph');
    await page.fill('#password', 'SecurePass123!');
    await page.click('#login-button');

    // Should redirect to dashboard
    await expect(page).toHaveURL('/dashboard');

    // Check that authentication token is properly stored
    const tokenExists = await page.evaluate(() => {
      return localStorage.getItem('app_access_token') !== null ||
             sessionStorage.getItem('app_access_token') !== null;
    });
    expect(tokenExists).toBe(true);
  });

  test('should protect against CSRF attacks', async () => {
    // Login first
    await page.goto('/login');
    await page.fill('#email', 'student@edu.ph');
    await page.fill('#password', 'SecurePass123!');
    await page.click('#login-button');
    await expect(page).toHaveURL('/dashboard');

    // Try to make a state-changing request without CSRF token
    const response = await page.evaluate(async () => {
      try {
        const result = await fetch('/api/user/profile', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ name: 'Hacked Name' })
        });
        return { status: result.status, ok: result.ok };
      } catch (error) {
        return { error: error.message };
      }
    });

    expect(response.status).toBe(403); // Should be blocked
  });

  test('should handle session timeout properly', async () => {
    // Login
    await page.goto('/login');
    await page.fill('#email', 'student@edu.ph');
    await page.fill('#password', 'SecurePass123!');
    await page.click('#login-button');
    await expect(page).toHaveURL('/dashboard');

    // Simulate session expiration by manipulating token
    await page.evaluate(() => {
      const expiredToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyLCJleHAiOjEwMDB9.invalid';
      localStorage.setItem('app_access_token', expiredToken);
    });

    // Try to access protected resource
    await page.goto('/protected-page');

    // Should redirect to login page
    await expect(page).toHaveURL('/login');
    await expect(page.locator('.session-expired-message')).toBeVisible();
  });

  test('should implement secure password requirements', async () => {
    await page.goto('/register');

    const weakPasswords = [
      '123456',
      'password',
      'qwerty',
      'abc123',
      'Password1' // Missing special character
    ];

    for (const password of weakPasswords) {
      await page.fill('#password', password);
      await page.fill('#confirmPassword', password);
      await page.blur('#password');

      const errorMessage = await page.locator('.password-error').textContent();
      expect(errorMessage).toContain('Password must contain');
    }

    // Test strong password
    await page.fill('#password', 'SecurePass123!@#');
    await page.fill('#confirmPassword', 'SecurePass123!@#');
    await page.blur('#password');

    const successMessage = await page.locator('.password-success');
    await expect(successMessage).toBeVisible();
  });
});
```

### 4. Penetration Testing Automation

#### OWASP ZAP Integration

```typescript
// Automated penetration testing with OWASP ZAP
class SecurityPenetrationTester {
  private zapClient: any;
  private baseUrl: string;

  constructor(zapApiUrl: string = 'http://localhost:8080', targetUrl: string) {
    // Initialize ZAP API client
    this.zapClient = new ZapClient({
      proxy: zapApiUrl
    });
    this.baseUrl = targetUrl;
  }

  async runFullSecurityScan(): Promise<SecurityScanResult> {
    const results: SecurityScanResult = {
      timestamp: Date.now(),
      targetUrl: this.baseUrl,
      scanDuration: 0,
      vulnerabilities: [],
      summary: {
        high: 0,
        medium: 0,
        low: 0,
        informational: 0
      }
    };

    const startTime = Date.now();

    try {
      // 1. Spider the application
      console.log('Starting spider scan...');
      await this.spiderScan();

      // 2. Active security scan
      console.log('Starting active security scan...');
      await this.activeScan();

      // 3. Collect results
      console.log('Collecting scan results...');
      results.vulnerabilities = await this.getVulnerabilities();
      results.summary = this.calculateSummary(results.vulnerabilities);

      results.scanDuration = Date.now() - startTime;
      
      // 4. Generate report
      await this.generateReport(results);

      return results;
    } catch (error) {
      console.error('Security scan failed:', error);
      throw error;
    }
  }

  private async spiderScan(): Promise<void> {
    return new Promise(async (resolve, reject) => {
      try {
        // Start spider
        const spiderScanId = await this.zapClient.spider.scan(this.baseUrl);
        
        // Wait for spider to complete
        let progress = 0;
        while (progress < 100) {
          await new Promise(resolve => setTimeout(resolve, 2000));
          const status = await this.zapClient.spider.status(spiderScanId);
          progress = parseInt(status.status);
          console.log(`Spider progress: ${progress}%`);
        }

        resolve();
      } catch (error) {
        reject(error);
      }
    });
  }

  private async activeScan(): Promise<void> {
    return new Promise(async (resolve, reject) => {
      try {
        // Start active scan
        const activeScanId = await this.zapClient.ascan.scan(this.baseUrl);
        
        // Wait for active scan to complete
        let progress = 0;
        while (progress < 100) {
          await new Promise(resolve => setTimeout(resolve, 5000));
          const status = await this.zapClient.ascan.status(activeScanId);
          progress = parseInt(status.status);
          console.log(`Active scan progress: ${progress}%`);
        }

        resolve();
      } catch (error) {
        reject(error);
      }
    });
  }

  private async getVulnerabilities(): Promise<SecurityVulnerability[]> {
    const alerts = await this.zapClient.core.alerts(this.baseUrl);
    
    return alerts.alerts.map((alert: any) => ({
      id: alert.pluginId,
      name: alert.alert,
      severity: alert.risk.toLowerCase(),
      confidence: alert.confidence.toLowerCase(),
      description: alert.desc,
      solution: alert.solution,
      reference: alert.reference,
      instances: alert.instances?.map((instance: any) => ({
        uri: instance.uri,
        method: instance.method,
        param: instance.param,
        attack: instance.attack,
        evidence: instance.evidence
      })) || []
    }));
  }

  private calculateSummary(vulnerabilities: SecurityVulnerability[]): VulnerabilitySummary {
    return vulnerabilities.reduce((summary, vuln) => {
      switch (vuln.severity) {
        case 'high':
          summary.high++;
          break;
        case 'medium':
          summary.medium++;
          break;
        case 'low':
          summary.low++;
          break;
        default:
          summary.informational++;
      }
      return summary;
    }, { high: 0, medium: 0, low: 0, informational: 0 });
  }

  private async generateReport(results: SecurityScanResult): Promise<void> {
    const reportPath = `security-scan-${Date.now()}.json`;
    const fs = require('fs');
    
    fs.writeFileSync(reportPath, JSON.stringify(results, null, 2));
    console.log(`Security scan report saved to: ${reportPath}`);

    // Generate HTML report if needed
    const htmlReport = this.generateHTMLReport(results);
    fs.writeFileSync(reportPath.replace('.json', '.html'), htmlReport);
  }

  private generateHTMLReport(results: SecurityScanResult): string {
    return `
<!DOCTYPE html>
<html>
<head>
    <title>Security Scan Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f0f0f0; padding: 20px; border-radius: 5px; }
        .summary { display: flex; justify-content: space-around; margin: 20px 0; }
        .summary-item { text-align: center; padding: 10px; background: #f9f9f9; border-radius: 5px; }
        .vulnerability { margin: 10px 0; padding: 15px; border-left: 4px solid #ddd; }
        .high { border-color: #d32f2f; }
        .medium { border-color: #f57c00; }
        .low { border-color: #388e3c; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Security Scan Report</h1>
        <p><strong>Target:</strong> ${results.targetUrl}</p>
        <p><strong>Scan Date:</strong> ${new Date(results.timestamp).toLocaleString()}</p>
        <p><strong>Duration:</strong> ${Math.round(results.scanDuration / 1000)} seconds</p>
    </div>

    <div class="summary">
        <div class="summary-item">
            <h3>${results.summary.high}</h3>
            <p>High Risk</p>
        </div>
        <div class="summary-item">
            <h3>${results.summary.medium}</h3>
            <p>Medium Risk</p>
        </div>
        <div class="summary-item">
            <h3>${results.summary.low}</h3>
            <p>Low Risk</p>
        </div>
        <div class="summary-item">
            <h3>${results.summary.informational}</h3>
            <p>Informational</p>
        </div>
    </div>

    <h2>Vulnerabilities</h2>
    ${results.vulnerabilities.map(vuln => `
        <div class="vulnerability ${vuln.severity}">
            <h3>${vuln.name}</h3>
            <p><strong>Severity:</strong> ${vuln.severity.toUpperCase()}</p>
            <p><strong>Confidence:</strong> ${vuln.confidence.toUpperCase()}</p>
            <p><strong>Description:</strong> ${vuln.description}</p>
            <p><strong>Solution:</strong> ${vuln.solution}</p>
            ${vuln.instances.length > 0 ? `
                <details>
                    <summary>Instances (${vuln.instances.length})</summary>
                    ${vuln.instances.map(instance => `
                        <div style="margin-left: 20px; border-left: 2px solid #eee; padding-left: 10px;">
                            <p><strong>URI:</strong> ${instance.uri}</p>
                            <p><strong>Method:</strong> ${instance.method}</p>
                            ${instance.param ? `<p><strong>Parameter:</strong> ${instance.param}</p>` : ''}
                            ${instance.evidence ? `<p><strong>Evidence:</strong> <code>${instance.evidence}</code></p>` : ''}
                        </div>
                    `).join('')}
                </details>
            ` : ''}
        </div>
    `).join('')}
</body>
</html>`;
  }
}
```

### 5. Continuous Security Monitoring

#### Security Testing in CI/CD Pipeline

```typescript
// CI/CD security testing integration
class ContinuousSecurityTesting {
  private config: SecurityTestingConfig;

  constructor(config: SecurityTestingConfig) {
    this.config = config;
  }

  async runSecurityGate(branch: string, commitHash: string): Promise<SecurityGateResult> {
    const results: SecurityGateResult = {
      branch,
      commitHash,
      timestamp: Date.now(),
      tests: [],
      overallStatus: 'pending',
      blockingIssues: [],
      warnings: []
    };

    try {
      // 1. Dependency vulnerability scan
      console.log('Running dependency vulnerability scan...');
      const depScanResult = await this.runDependencyVulnerabilityScan();
      results.tests.push(depScanResult);

      // 2. Static security analysis
      console.log('Running static security analysis...');
      const staticAnalysisResult = await this.runStaticSecurityAnalysis();
      results.tests.push(staticAnalysisResult);

      // 3. Security unit tests
      console.log('Running security unit tests...');
      const unitTestResult = await this.runSecurityUnitTests();
      results.tests.push(unitTestResult);

      // 4. Integration security tests
      console.log('Running security integration tests...');
      const integrationTestResult = await this.runSecurityIntegrationTests();
      results.tests.push(integrationTestResult);

      // 5. Basic penetration testing (if enabled)
      if (this.config.enablePenetrationTesting) {
        console.log('Running basic penetration tests...');
        const penTestResult = await this.runBasicPenetrationTests();
        results.tests.push(penTestResult);
      }

      // Analyze results
      results.overallStatus = this.analyzeResults(results.tests);
      results.blockingIssues = this.extractBlockingIssues(results.tests);
      results.warnings = this.extractWarnings(results.tests);

      // Generate reports
      await this.generateSecurityReport(results);

      return results;
    } catch (error) {
      results.overallStatus = 'failed';
      results.blockingIssues.push({
        type: 'pipeline_error',
        severity: 'critical',
        message: `Security pipeline failed: ${error.message}`
      });
      return results;
    }
  }

  private async runDependencyVulnerabilityScan(): Promise<SecurityTestResult> {
    const startTime = Date.now();
    
    try {
      // Run npm audit
      const { execSync } = require('child_process');
      const auditOutput = execSync('npm audit --json', { 
        encoding: 'utf8',
        maxBuffer: 1024 * 1024 * 10 // 10MB buffer
      });
      
      const auditResults = JSON.parse(auditOutput);
      const vulnerabilities = auditResults.vulnerabilities || {};
      
      const criticalCount = Object.values(vulnerabilities).filter(
        (v: any) => v.severity === 'critical'
      ).length;
      
      const highCount = Object.values(vulnerabilities).filter(
        (v: any) => v.severity === 'high'
      ).length;

      return {
        testType: 'dependency_vulnerabilities',
        status: criticalCount > 0 ? 'failed' : highCount > 0 ? 'warning' : 'passed',
        duration: Date.now() - startTime,
        details: {
          totalVulnerabilities: Object.keys(vulnerabilities).length,
          critical: criticalCount,
          high: highCount,
          medium: Object.values(vulnerabilities).filter((v: any) => v.severity === 'medium').length,
          low: Object.values(vulnerabilities).filter((v: any) => v.severity === 'low').length
        },
        recommendations: criticalCount > 0 ? ['Update critical dependencies immediately'] : []
      };
    } catch (error) {
      return {
        testType: 'dependency_vulnerabilities',
        status: 'failed',
        duration: Date.now() - startTime,
        error: error.message,
        recommendations: ['Fix dependency vulnerability scan issues']
      };
    }
  }

  private async runStaticSecurityAnalysis(): Promise<SecurityTestResult> {
    const startTime = Date.now();
    
    try {
      // Run ESLint with security rules
      const { execSync } = require('child_process');
      const eslintOutput = execSync(
        'npx eslint . --ext .js,.ts,.tsx --format json --config .eslintrc.security.js',
        { encoding: 'utf8', maxBuffer: 1024 * 1024 }
      );
      
      const eslintResults = JSON.parse(eslintOutput);
      const securityIssues = eslintResults.reduce((total: number, file: any) => {
        return total + file.messages.filter((msg: any) => 
          msg.ruleId && msg.ruleId.includes('security')
        ).length;
      }, 0);

      return {
        testType: 'static_security_analysis',
        status: securityIssues > 0 ? 'warning' : 'passed',
        duration: Date.now() - startTime,
        details: {
          filesScanned: eslintResults.length,
          securityIssues,
          totalIssues: eslintResults.reduce((total: number, file: any) => total + file.messages.length, 0)
        },
        recommendations: securityIssues > 0 ? ['Review and fix security-related code issues'] : []
      };
    } catch (error) {
      return {
        testType: 'static_security_analysis',
        status: 'failed',
        duration: Date.now() - startTime,
        error: error.message,
        recommendations: ['Fix static analysis configuration']
      };
    }
  }

  private async runSecurityUnitTests(): Promise<SecurityTestResult> {
    const startTime = Date.now();
    
    try {
      const { execSync } = require('child_process');
      const testOutput = execSync(
        'npm test -- --testPathPattern=security --json',
        { encoding: 'utf8', maxBuffer: 1024 * 1024 }
      );
      
      const testResults = JSON.parse(testOutput);
      const passedTests = testResults.numPassedTests || 0;
      const failedTests = testResults.numFailedTests || 0;
      const totalTests = passedTests + failedTests;

      return {
        testType: 'security_unit_tests',
        status: failedTests > 0 ? 'failed' : 'passed',
        duration: Date.now() - startTime,
        details: {
          totalTests,
          passed: passedTests,
          failed: failedTests,
          coverage: testResults.coverageMap ? this.calculateSecurityCoverage(testResults.coverageMap) : 0
        },
        recommendations: failedTests > 0 ? ['Fix failing security tests'] : []
      };
    } catch (error) {
      return {
        testType: 'security_unit_tests',
        status: 'failed',
        duration: Date.now() - startTime,
        error: error.message,
        recommendations: ['Fix security unit test execution']
      };
    }
  }

  private async runSecurityIntegrationTests(): Promise<SecurityTestResult> {
    const startTime = Date.now();
    
    try {
      const { execSync } = require('child_process');
      const testOutput = execSync(
        'npm run test:integration -- --grep="security"',
        { encoding: 'utf8', maxBuffer: 1024 * 1024 }
      );
      
      // Parse test output (format depends on test runner)
      const passed = (testOutput.match(/✓/g) || []).length;
      const failed = (testOutput.match(/✗|×/g) || []).length;

      return {
        testType: 'security_integration_tests',
        status: failed > 0 ? 'failed' : 'passed',
        duration: Date.now() - startTime,
        details: {
          totalTests: passed + failed,
          passed,
          failed
        },
        recommendations: failed > 0 ? ['Fix failing security integration tests'] : []
      };
    } catch (error) {
      return {
        testType: 'security_integration_tests',
        status: 'failed',
        duration: Date.now() - startTime,
        error: error.message,
        recommendations: ['Fix security integration test execution']
      };
    }
  }

  private async runBasicPenetrationTests(): Promise<SecurityTestResult> {
    const startTime = Date.now();
    
    try {
      // Run basic OWASP ZAP baseline scan
      const penetrationTester = new SecurityPenetrationTester(
        'http://localhost:8080',
        this.config.targetUrl
      );
      
      const scanResults = await penetrationTester.runFullSecurityScan();
      const criticalVulns = scanResults.vulnerabilities.filter(v => v.severity === 'high').length;
      const mediumVulns = scanResults.vulnerabilities.filter(v => v.severity === 'medium').length;

      return {
        testType: 'basic_penetration_tests',
        status: criticalVulns > 0 ? 'failed' : mediumVulns > 5 ? 'warning' : 'passed',
        duration: Date.now() - startTime,
        details: {
          totalVulnerabilities: scanResults.vulnerabilities.length,
          critical: criticalVulns,
          medium: mediumVulns,
          low: scanResults.vulnerabilities.filter(v => v.severity === 'low').length
        },
        recommendations: criticalVulns > 0 ? ['Address critical security vulnerabilities immediately'] : []
      };
    } catch (error) {
      return {
        testType: 'basic_penetration_tests',
        status: 'warning', // Don't fail pipeline for pen test issues
        duration: Date.now() - startTime,
        error: error.message,
        recommendations: ['Review penetration testing configuration']
      };
    }
  }

  private analyzeResults(tests: SecurityTestResult[]): 'passed' | 'warning' | 'failed' {
    const failedTests = tests.filter(t => t.status === 'failed');
    const warningTests = tests.filter(t => t.status === 'warning');

    if (failedTests.length > 0) return 'failed';
    if (warningTests.length > 0) return 'warning';
    return 'passed';
  }

  private extractBlockingIssues(tests: SecurityTestResult[]): SecurityIssue[] {
    const issues: SecurityIssue[] = [];

    tests.forEach(test => {
      if (test.status === 'failed') {
        issues.push({
          type: test.testType,
          severity: 'critical',
          message: test.error || `${test.testType} failed`,
          details: test.details
        });
      }
    });

    return issues;
  }

  private extractWarnings(tests: SecurityTestResult[]): SecurityIssue[] {
    const warnings: SecurityIssue[] = [];

    tests.forEach(test => {
      if (test.status === 'warning') {
        warnings.push({
          type: test.testType,
          severity: 'medium',
          message: `${test.testType} has warnings`,
          details: test.details
        });
      }
    });

    return warnings;
  }

  private async generateSecurityReport(results: SecurityGateResult): Promise<void> {
    const reportData = {
      ...results,
      reportGenerated: new Date().toISOString(),
      recommendations: this.generateRecommendations(results)
    };

    const fs = require('fs');
    const reportPath = `security-gate-report-${results.commitHash.substring(0, 8)}.json`;
    
    fs.writeFileSync(reportPath, JSON.stringify(reportData, null, 2));
    console.log(`Security gate report saved to: ${reportPath}`);
  }

  private generateRecommendations(results: SecurityGateResult): string[] {
    const recommendations: string[] = [];

    if (results.overallStatus === 'failed') {
      recommendations.push('Address all blocking security issues before deployment');
    }

    if (results.overallStatus === 'warning') {
      recommendations.push('Review security warnings and plan remediation');
    }

    recommendations.push('Continue regular security testing and monitoring');
    recommendations.push('Consider additional security training for the team');

    return recommendations;
  }

  private calculateSecurityCoverage(coverageMap: any): number {
    // Simplified security coverage calculation
    // In practice, this would analyze coverage of security-critical code paths
    return 85; // Placeholder
  }
}
```

## Security Testing Best Practices Checklist

### Test Planning
- [ ] **Security Test Strategy**: Comprehensive security testing strategy
- [ ] **Test Coverage**: Security tests cover all critical components
- [ ] **Test Automation**: Maximum automation for repeatable tests
- [ ] **Test Environment**: Dedicated security testing environment
- [ ] **Test Data**: Secure test data management

### Automated Testing
- [ ] **Unit Tests**: Security-focused unit tests for all critical functions
- [ ] **Integration Tests**: API and service integration security tests
- [ ] **Browser Tests**: Client-side security validation tests
- [ ] **Regression Tests**: Security regression test suite
- [ ] **Performance Tests**: Security performance impact testing

### Vulnerability Assessment
- [ ] **Static Analysis**: Automated static security code analysis
- [ ] **Dynamic Analysis**: Runtime security vulnerability scanning
- [ ] **Dependency Scanning**: Third-party dependency vulnerability checks
- [ ] **Container Scanning**: Container image security scanning (if applicable)
- [ ] **Infrastructure Scanning**: Infrastructure security assessment

### Penetration Testing
- [ ] **Automated Pen Testing**: Regular automated penetration testing
- [ ] **Manual Pen Testing**: Periodic manual penetration testing
- [ ] **Red Team Exercises**: Advanced threat simulation exercises
- [ ] **Bug Bounty Program**: External security researcher engagement
- [ ] **Social Engineering Tests**: Human factor security testing

### Continuous Monitoring
- [ ] **CI/CD Integration**: Security gates in deployment pipeline
- [ ] **Real-time Monitoring**: Production security monitoring
- [ ] **Incident Detection**: Automated security incident detection
- [ ] **Threat Intelligence**: Integration with threat intelligence feeds
- [ ] **Security Metrics**: KPI tracking and reporting

### Compliance Testing
- [ ] **FERPA Compliance Testing**: Educational data privacy compliance
- [ ] **GDPR Compliance Testing**: European data protection compliance
- [ ] **SOC 2 Testing**: Service organization control compliance
- [ ] **PCI DSS Testing**: Payment card industry compliance (if applicable)
- [ ] **Accessibility Testing**: Security accessibility compliance

---

## Navigation

- ← Back to: [Frontend Security Best Practices](./README.md)
- ← Previous: [Secure Authentication Patterns](./secure-authentication-patterns.md)
- → Related: [Implementation Guide](./implementation-guide.md)
- → Related: [Best Practices](./best-practices.md)