# Implementation Guide: Frontend Security Best Practices

Step-by-step implementation guide for deploying comprehensive frontend security measures including XSS prevention, CSRF protection, and Content Security Policy configuration.

## Prerequisites

### Development Environment Setup
```bash
# Node.js and npm (recommended versions)
node --version  # v18.0.0 or higher
npm --version   # v8.0.0 or higher

# TypeScript for type safety
npm install -g typescript@latest
```

### Required Dependencies
```bash
# Core security libraries
npm install --save dompurify
npm install --save csrf
npm install --save helmet
npm install --save express-validator
npm install --save bcryptjs
npm install --save jsonwebtoken

# Development and testing
npm install --save-dev @types/dompurify
npm install --save-dev @types/bcryptjs
npm install --save-dev @types/jsonwebtoken
npm install --save-dev jest
npm install --save-dev supertest
```

## Phase 1: Input Sanitization & XSS Prevention

### 1.1 DOMPurify Implementation

#### Frontend Implementation (React/TypeScript)
```typescript
// utils/sanitizer.ts
import DOMPurify from 'dompurify';

interface SanitizerConfig {
  allowedTags?: string[];
  allowedAttributes?: string[];
  stripIgnoreTag?: boolean;
}

export class HTMLSanitizer {
  private static defaultConfig: SanitizerConfig = {
    allowedTags: ['b', 'i', 'em', 'strong', 'a', 'p', 'br'],
    allowedAttributes: ['href', 'target'],
    stripIgnoreTag: true
  };

  static sanitizeHTML(
    dirty: string, 
    config: SanitizerConfig = this.defaultConfig
  ): string {
    const cleanConfig = {
      ALLOWED_TAGS: config.allowedTags,
      ALLOWED_ATTR: config.allowedAttributes,
      STRIP_IGNORE_TAG: config.stripIgnoreTag
    };

    return DOMPurify.sanitize(dirty, cleanConfig);
  }

  static sanitizeForDisplay(userInput: string): string {
    // For displaying user-generated content
    return this.sanitizeHTML(userInput, {
      allowedTags: ['b', 'i', 'em', 'strong', 'p', 'br'],
      allowedAttributes: [],
      stripIgnoreTag: true
    });
  }

  static sanitizeRichText(richContent: string): string {
    // For rich text editor content
    return this.sanitizeHTML(richContent, {
      allowedTags: [
        'h1', 'h2', 'h3', 'h4', 'h5', 'h6',
        'p', 'br', 'strong', 'em', 'u', 'ol', 'ul', 'li',
        'a', 'img', 'blockquote', 'code', 'pre'
      ],
      allowedAttributes: ['href', 'src', 'alt', 'title', 'target'],
      stripIgnoreTag: true
    });
  }
}
```

#### React Component Implementation
```typescript
// components/SafeContent.tsx
import React from 'react';
import { HTMLSanitizer } from '../utils/sanitizer';

interface SafeContentProps {
  content: string;
  className?: string;
  contentType?: 'display' | 'richText';
}

export const SafeContent: React.FC<SafeContentProps> = ({
  content,
  className = '',
  contentType = 'display'
}) => {
  const sanitizedContent = contentType === 'richText' 
    ? HTMLSanitizer.sanitizeRichText(content)
    : HTMLSanitizer.sanitizeForDisplay(content);

  return (
    <div 
      className={className}
      dangerouslySetInnerHTML={{ __html: sanitizedContent }}
    />
  );
};

// Usage example
const UserProfile: React.FC<{ user: User }> = ({ user }) => {
  return (
    <div>
      <h2>{user.name}</h2>
      <SafeContent 
        content={user.bio} 
        contentType="richText"
        className="user-bio"
      />
    </div>
  );
};
```

### 1.2 Server-Side Validation (Express.js)

```typescript
// middleware/validation.ts
import { body, validationResult, ValidationChain } from 'express-validator';
import { Request, Response, NextFunction } from 'express';

export const validateInput = (validations: ValidationChain[]) => {
  return async (req: Request, res: Response, next: NextFunction) => {
    // Run all validations
    await Promise.all(validations.map(validation => validation.run(req)));

    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        success: false,
        message: 'Validation failed',
        errors: errors.array()
      });
    }

    next();
  };
};

// validation/userValidation.ts
export const userRegistrationValidation = [
  body('email')
    .isEmail()
    .normalizeEmail()
    .withMessage('Valid email is required'),
  
  body('password')
    .isLength({ min: 8 })
    .matches(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]/)
    .withMessage('Password must contain at least 8 characters with uppercase, lowercase, number, and special character'),
  
  body('name')
    .trim()
    .isLength({ min: 2, max: 50 })
    .matches(/^[a-zA-Z\s]+$/)
    .withMessage('Name must contain only letters and spaces'),
  
  body('bio')
    .optional()
    .trim()
    .isLength({ max: 500 })
    .escape() // HTML escape special characters
    .withMessage('Bio must be less than 500 characters')
];

// Usage in routes
app.post('/api/users/register', 
  validateInput(userRegistrationValidation),
  async (req: Request, res: Response) => {
    // Registration logic here - validation already passed
    const { email, password, name, bio } = req.body;
    // ... registration implementation
  }
);
```

## Phase 2: CSRF Protection Implementation

### 2.1 CSRF Token Configuration

```typescript
// middleware/csrf.ts
import csrf from 'csrf';
import { Request, Response, NextFunction } from 'express';

const tokens = new csrf();

export interface CSRFRequest extends Request {
  csrfToken?: string;
  session: {
    csrfSecret?: string;
  };
}

export const csrfProtection = (req: CSRFRequest, res: Response, next: NextFunction) => {
  // Generate secret for session if doesn't exist
  if (!req.session.csrfSecret) {
    req.session.csrfSecret = tokens.secretSync();
  }

  // Add CSRF token to response locals for templates
  res.locals.csrfToken = tokens.create(req.session.csrfSecret);

  // Skip verification for GET, HEAD, OPTIONS requests
  if (['GET', 'HEAD', 'OPTIONS'].includes(req.method)) {
    return next();
  }

  // Verify CSRF token for state-changing requests
  const token = req.headers['x-csrf-token'] as string || 
                req.body._csrf || 
                req.query._csrf;

  if (!token || !tokens.verify(req.session.csrfSecret, token)) {
    return res.status(403).json({
      success: false,
      message: 'Invalid CSRF token',
      code: 'CSRF_INVALID'
    });
  }

  next();
};

// Apply CSRF protection to all routes
app.use(csrfProtection);

// Endpoint to get CSRF token
app.get('/api/csrf-token', (req: Request, res: Response) => {
  res.json({
    success: true,
    csrfToken: res.locals.csrfToken
  });
});
```

### 2.2 Frontend CSRF Implementation

```typescript
// services/csrfService.ts
class CSRFService {
  private static instance: CSRFService;
  private csrfToken: string | null = null;

  private constructor() {}

  static getInstance(): CSRFService {
    if (!CSRFService.instance) {
      CSRFService.instance = new CSRFService();
    }
    return CSRFService.instance;
  }

  async getToken(): Promise<string> {
    if (!this.csrfToken) {
      await this.refreshToken();
    }
    return this.csrfToken!;
  }

  async refreshToken(): Promise<void> {
    try {
      const response = await fetch('/api/csrf-token', {
        credentials: 'include'
      });
      const data = await response.json();
      
      if (data.success) {
        this.csrfToken = data.csrfToken;
      } else {
        throw new Error('Failed to get CSRF token');
      }
    } catch (error) {
      console.error('CSRF token refresh failed:', error);
      throw error;
    }
  }

  clearToken(): void {
    this.csrfToken = null;
  }
}

// HTTP client with CSRF protection
export class SecureHTTPClient {
  private csrfService = CSRFService.getInstance();

  async request(url: string, options: RequestInit = {}): Promise<Response> {
    const token = await this.csrfService.getToken();
    
    const secureOptions: RequestInit = {
      ...options,
      credentials: 'include',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': token,
        ...options.headers
      }
    };

    const response = await fetch(url, secureOptions);

    // Refresh CSRF token if expired
    if (response.status === 403) {
      await this.csrfService.refreshToken();
      const newToken = await this.csrfService.getToken();
      
      secureOptions.headers = {
        ...secureOptions.headers,
        'X-CSRF-Token': newToken
      };
      
      return fetch(url, secureOptions);
    }

    return response;
  }

  async post(url: string, data: any): Promise<Response> {
    return this.request(url, {
      method: 'POST',
      body: JSON.stringify(data)
    });
  }

  async put(url: string, data: any): Promise<Response> {
    return this.request(url, {
      method: 'PUT',
      body: JSON.stringify(data)
    });
  }

  async delete(url: string): Promise<Response> {
    return this.request(url, {
      method: 'DELETE'
    });
  }
}
```

### 2.3 SameSite Cookie Configuration

```typescript
// middleware/cookieConfig.ts
import session from 'express-session';
import MongoStore from 'connect-mongo';

const cookieConfig = {
  name: 'sessionId',
  secret: process.env.SESSION_SECRET!,
  resave: false,
  saveUninitialized: false,
  store: MongoStore.create({
    mongoUrl: process.env.MONGODB_URI!,
    touchAfter: 24 * 3600 // lazy session update
  }),
  cookie: {
    secure: process.env.NODE_ENV === 'production', // HTTPS only in production
    httpOnly: true, // Prevent XSS
    maxAge: 24 * 60 * 60 * 1000, // 24 hours
    sameSite: 'strict' as const // CSRF protection
  }
};

app.use(session(cookieConfig));
```

## Phase 3: Content Security Policy (CSP) Implementation

### 3.1 Basic CSP Configuration

```typescript
// middleware/csp.ts
import helmet from 'helmet';

export const cspConfig = {
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      
      // Scripts - use nonces for inline scripts
      scriptSrc: [
        "'self'",
        "'nonce-{{nonce}}'", // Will be replaced with actual nonce
        "https://cdn.jsdelivr.net",
        "https://unpkg.com"
      ],
      
      // Styles - allow inline styles with nonces
      styleSrc: [
        "'self'",
        "'nonce-{{nonce}}'",
        "https://fonts.googleapis.com",
        "https://cdn.jsdelivr.net"
      ],
      
      // Images
      imgSrc: [
        "'self'",
        "data:",
        "https://images.unsplash.com",
        "https://via.placeholder.com"
      ],
      
      // Fonts
      fontSrc: [
        "'self'",
        "https://fonts.gstatic.com",
        "https://cdn.jsdelivr.net"
      ],
      
      // API endpoints
      connectSrc: [
        "'self'",
        process.env.API_BASE_URL || "http://localhost:3001"
      ],
      
      // Frames
      frameSrc: ["'self'"],
      frameAncestors: ["'none'"], // Prevent clickjacking
      
      // Objects and plugins
      objectSrc: ["'none'"],
      pluginTypes: [],
      
      // Base URI
      baseUri: ["'self'"],
      
      // Form actions
      formAction: ["'self'"],
      
      // Upgrade insecure requests in production
      ...(process.env.NODE_ENV === 'production' && {
        upgradeInsecureRequests: []
      }),
      
      // Report violations
      reportUri: ['/api/csp-violation-report']
    },
    reportOnly: process.env.NODE_ENV !== 'production' // Report-only in development
  }
};

app.use(helmet(cspConfig));
```

### 3.2 Nonce-Based CSP Implementation

```typescript
// middleware/nonceCSP.ts
import crypto from 'crypto';
import { Request, Response, NextFunction } from 'express';

export interface NonceRequest extends Request {
  nonce?: string;
}

export const generateNonce = (req: NonceRequest, res: Response, next: NextFunction) => {
  // Generate cryptographically secure nonce
  req.nonce = crypto.randomBytes(16).toString('base64');
  res.locals.nonce = req.nonce;
  
  // Set CSP header with nonce
  const cspHeader = `
    default-src 'self';
    script-src 'self' 'nonce-${req.nonce}' https://cdn.jsdelivr.net;
    style-src 'self' 'nonce-${req.nonce}' https://fonts.googleapis.com;
    img-src 'self' data: https://images.unsplash.com;
    font-src 'self' https://fonts.gstatic.com;
    connect-src 'self' ${process.env.API_BASE_URL || 'http://localhost:3001'};
    frame-ancestors 'none';
    object-src 'none';
    base-uri 'self';
    form-action 'self';
    report-uri /api/csp-violation-report;
  `.replace(/\s+/g, ' ').trim();

  res.setHeader('Content-Security-Policy', cspHeader);
  next();
};

// CSP violation reporting endpoint
app.post('/api/csp-violation-report', express.json(), (req: Request, res: Response) => {
  const report = req.body;
  
  // Log CSP violations for monitoring
  console.warn('CSP Violation:', {
    timestamp: new Date().toISOString(),
    userAgent: req.headers['user-agent'],
    violation: report['csp-report']
  });
  
  // Store in database for analysis
  // await CSPViolation.create({
  //   blockedUri: report['csp-report']['blocked-uri'],
  //   documentUri: report['csp-report']['document-uri'],
  //   violatedDirective: report['csp-report']['violated-directive'],
  //   originalPolicy: report['csp-report']['original-policy'],
  //   userAgent: req.headers['user-agent'],
  //   timestamp: new Date()
  // });
  
  res.status(204).end();
});
```

### 3.3 React CSP Integration

```typescript
// components/CSPScript.tsx
import React from 'react';

interface CSPScriptProps {
  nonce: string;
  children: string;
}

export const CSPScript: React.FC<CSPScriptProps> = ({ nonce, children }) => {
  return (
    <script 
      nonce={nonce}
      dangerouslySetInnerHTML={{ __html: children }}
    />
  );
};

// components/CSPStyle.tsx
interface CSPStyleProps {
  nonce: string;
  children: string;
}

export const CSPStyle: React.FC<CSPStyleProps> = ({ nonce, children }) => {
  return (
    <style 
      nonce={nonce}
      dangerouslySetInnerHTML={{ __html: children }}
    />
  );
};

// Usage in React components
const App: React.FC<{ nonce: string }> = ({ nonce }) => {
  return (
    <html>
      <head>
        <CSPStyle nonce={nonce}>
          {`
            .secure-component {
              background-color: #f0f0f0;
              padding: 1rem;
            }
          `}
        </CSPStyle>
      </head>
      <body>
        <div className="secure-component">
          Secure content with CSP protection
        </div>
        
        <CSPScript nonce={nonce}>
          {`
            console.log('Script executed with CSP nonce');
            // Analytics or other necessary inline scripts
          `}
        </CSPScript>
      </body>
    </html>
  );
};
```

## Phase 4: Security Testing Implementation

### 4.1 Automated Security Testing

```typescript
// tests/security.test.ts
import request from 'supertest';
import { app } from '../src/app';

describe('Security Tests', () => {
  describe('XSS Prevention', () => {
    it('should sanitize malicious script tags', async () => {
      const maliciousInput = '<script>alert("XSS")</script>Hello World';
      
      const response = await request(app)
        .post('/api/content')
        .send({ content: maliciousInput })
        .expect(200);
      
      expect(response.body.sanitizedContent).not.toContain('<script>');
      expect(response.body.sanitizedContent).toContain('Hello World');
    });

    it('should prevent DOM-based XSS', async () => {
      const maliciousInput = 'javascript:alert("XSS")';
      
      const response = await request(app)
        .post('/api/links')
        .send({ url: maliciousInput })
        .expect(400);
      
      expect(response.body.message).toContain('Invalid URL');
    });
  });

  describe('CSRF Protection', () => {
    it('should reject requests without CSRF token', async () => {
      const response = await request(app)
        .post('/api/users/update')
        .send({ name: 'Updated Name' })
        .expect(403);
      
      expect(response.body.code).toBe('CSRF_INVALID');
    });

    it('should accept requests with valid CSRF token', async () => {
      // Get CSRF token
      const tokenResponse = await request(app)
        .get('/api/csrf-token')
        .expect(200);
      
      const csrfToken = tokenResponse.body.csrfToken;
      
      // Use token in request
      const response = await request(app)
        .post('/api/users/update')
        .set('X-CSRF-Token', csrfToken)
        .send({ name: 'Updated Name' })
        .expect(200);
      
      expect(response.body.success).toBe(true);
    });
  });

  describe('Content Security Policy', () => {
    it('should set CSP headers', async () => {
      const response = await request(app)
        .get('/')
        .expect(200);
      
      expect(response.headers['content-security-policy']).toBeDefined();
      expect(response.headers['content-security-policy']).toContain("default-src 'self'");
    });

    it('should include nonce in CSP header', async () => {
      const response = await request(app)
        .get('/')
        .expect(200);
      
      const cspHeader = response.headers['content-security-policy'];
      expect(cspHeader).toMatch(/nonce-[A-Za-z0-9+/]+=*/);
    });
  });
});
```

### 4.2 Security Vulnerability Scanning

```typescript
// scripts/security-scan.ts
import { execSync } from 'child_process';
import fs from 'fs';

interface SecurityScanResult {
  vulnerabilities: number;
  critical: number;
  high: number;
  medium: number;
  low: number;
}

export class SecurityScanner {
  static async runNpmAudit(): Promise<SecurityScanResult> {
    try {
      const result = execSync('npm audit --json', { encoding: 'utf8' });
      const auditData = JSON.parse(result);
      
      return {
        vulnerabilities: auditData.metadata.vulnerabilities.total,
        critical: auditData.metadata.vulnerabilities.critical,
        high: auditData.metadata.vulnerabilities.high,
        medium: auditData.metadata.vulnerabilities.medium,
        low: auditData.metadata.vulnerabilities.low
      };
    } catch (error) {
      console.error('npm audit failed:', error);
      throw error;
    }
  }

  static async generateSecurityReport(): Promise<void> {
    const scanResult = await this.runNpmAudit();
    
    const report = {
      timestamp: new Date().toISOString(),
      scan: 'dependency-vulnerabilities',
      results: scanResult,
      recommendations: this.generateRecommendations(scanResult)
    };

    fs.writeFileSync(
      `security-report-${Date.now()}.json`,
      JSON.stringify(report, null, 2)
    );

    console.log('Security report generated:', report);
  }

  private static generateRecommendations(result: SecurityScanResult): string[] {
    const recommendations: string[] = [];

    if (result.critical > 0) {
      recommendations.push('CRITICAL: Update dependencies immediately');
    }
    
    if (result.high > 0) {
      recommendations.push('HIGH: Schedule dependency updates within 24 hours');
    }

    if (result.vulnerabilities === 0) {
      recommendations.push('All dependencies are secure');
    }

    return recommendations;
  }
}

// Run security scan
if (require.main === module) {
  SecurityScanner.generateSecurityReport()
    .then(() => console.log('Security scan completed'))
    .catch(error => console.error('Security scan failed:', error));
}
```

## Deployment Checklist

### Production Security Checklist
- [ ] **Environment Variables**: All secrets in environment variables, not code
- [ ] **HTTPS Configuration**: SSL certificates installed and HSTS enabled
- [ ] **Security Headers**: Helmet.js configured for production
- [ ] **CSP Deployment**: Content Security Policy headers active
- [ ] **CSRF Protection**: CSRF tokens implemented on all forms
- [ ] **Input Sanitization**: DOMPurify sanitization on all user content
- [ ] **Session Security**: Secure cookie configuration active
- [ ] **Dependency Security**: No critical vulnerabilities in npm audit
- [ ] **Error Handling**: No sensitive information in error messages
- [ ] **Monitoring**: Security violation logging and alerting configured

### Verification Commands
```bash
# Security audit
npm audit --audit-level high

# CSP testing
curl -I https://your-domain.com | grep -i content-security

# SSL testing
openssl s_client -connect your-domain.com:443 -verify_return_error

# Headers verification
curl -I https://your-domain.com | grep -E "(X-Frame|X-Content|Strict-Transport)"
```

---

## Navigation

- ← Back to: [Frontend Security Best Practices](./README.md)
- → Next: [Best Practices](./best-practices.md)
- → Specialized: [XSS Prevention Strategies](./xss-prevention-strategies.md)