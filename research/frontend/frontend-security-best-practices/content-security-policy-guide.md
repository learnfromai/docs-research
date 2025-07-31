# Content Security Policy (CSP): Complete Implementation Guide

Content Security Policy (CSP) is a powerful security feature that helps prevent Cross-Site Scripting (XSS), data injection attacks, and clickjacking by controlling which resources a web page is allowed to load. This comprehensive guide provides practical implementation strategies for deploying robust CSP policies in modern web applications.

## Understanding Content Security Policy

### What is CSP?

CSP is an HTTP header that instructs the browser to only load resources from trusted sources. It acts as a whitelist system that significantly reduces the attack surface for code injection vulnerabilities.

#### CSP Protection Mechanisms
- **Script Injection Prevention**: Blocks unauthorized JavaScript execution
- **Data Exfiltration Protection**: Prevents unauthorized data transmission
- **Clickjacking Mitigation**: Controls iframe embedding permissions
- **Mixed Content Prevention**: Enforces HTTPS resource loading
- **Plugin Control**: Manages Flash and other plugin execution

### CSP Directive Categories

#### Fetch Directives (Resource Loading Control)
```http
Content-Security-Policy: 
  default-src 'self';
  script-src 'self' 'unsafe-inline' 'unsafe-eval' https://cdn.example.com;
  style-src 'self' 'unsafe-inline' https://fonts.googleapis.com;
  img-src 'self' data: https://images.unsplash.com;
  font-src 'self' https://fonts.gstatic.com;
  connect-src 'self' https://api.example.com;
  media-src 'self';
  object-src 'none';
  child-src 'self';
  frame-src 'self';
  worker-src 'self';
  manifest-src 'self';
```

#### Document Directives (Document Behavior Control)
```http
Content-Security-Policy:
  base-uri 'self';
  form-action 'self' https://secure-forms.example.com;
  frame-ancestors 'none';
  sandbox allow-forms allow-scripts allow-same-origin;
```

#### Navigation Directives (Navigation Control)
```http
Content-Security-Policy:
  navigate-to 'self' https://trusted-external.com;
```

#### Reporting Directives (Violation Monitoring)
```http
Content-Security-Policy:
  report-uri /api/csp-violation-report;
  report-to csp-endpoint;
```

## Advanced CSP Implementation Strategies

### 1. Nonce-Based CSP (Recommended Approach)

#### Server-Side Nonce Generation

```typescript
// middleware/cspNonce.ts
import crypto from 'crypto';
import { Request, Response, NextFunction } from 'express';

interface NonceRequest extends Request {
  nonce?: string;
}

interface CSPConfig {
  reportOnly?: boolean;
  reportUri?: string;
  allowedDomains?: {
    scripts?: string[];
    styles?: string[];
    images?: string[];
    fonts?: string[];
    connect?: string[];
  };
  unsafeInline?: {
    scripts?: boolean;
    styles?: boolean;
  };
  unsafeEval?: boolean;
}

export class CSPNonceManager {
  private static readonly NONCE_LENGTH = 32;
  
  static generateNonce(): string {
    return crypto.randomBytes(this.NONCE_LENGTH).toString('base64');
  }

  static buildCSPHeader(nonce: string, config: CSPConfig = {}): string {
    const {
      reportOnly = false,
      reportUri = '/api/csp-violation-report',
      allowedDomains = {},
      unsafeInline = { scripts: false, styles: false },
      unsafeEval = false
    } = config;

    // Base policy - most restrictive
    const directives: string[] = [
      "default-src 'self'",
      
      // Script sources with nonce
      `script-src 'self' 'nonce-${nonce}'${unsafeEval ? " 'unsafe-eval'" : ""}${unsafeInline.scripts ? " 'unsafe-inline'" : ""} ${(allowedDomains.scripts || []).join(' ')}`.trim(),
      
      // Style sources with nonce
      `style-src 'self' 'nonce-${nonce}'${unsafeInline.styles ? " 'unsafe-inline'" : ""} ${(allowedDomains.styles || []).join(' ')}`.trim(),
      
      // Image sources
      `img-src 'self' data: blob: ${(allowedDomains.images || []).join(' ')}`.trim(),
      
      // Font sources
      `font-src 'self' ${(allowedDomains.fonts || []).join(' ')}`.trim(),
      
      // Connection sources (API endpoints)
      `connect-src 'self' ${(allowedDomains.connect || []).join(' ')}`.trim(),
      
      // Media sources
      "media-src 'self'",
      
      // Object/Plugin restrictions
      "object-src 'none'",
      
      // Frame restrictions
      "frame-src 'self'",
      "frame-ancestors 'none'",
      
      // Base URI restriction
      "base-uri 'self'",
      
      // Form action restriction
      "form-action 'self'",
      
      // Upgrade insecure requests in production
      ...(process.env.NODE_ENV === 'production' ? ['upgrade-insecure-requests'] : []),
      
      // Reporting
      `report-uri ${reportUri}`
    ];

    const policy = directives.join('; ');
    return reportOnly ? `${policy}; report-only` : policy;
  }
}

export const cspNonceMiddleware = (config: CSPConfig = {}) => {
  return (req: NonceRequest, res: Response, next: NextFunction) => {
    // Generate unique nonce for this request
    const nonce = CSPNonceManager.generateNonce();
    req.nonce = nonce;
    res.locals.nonce = nonce;

    // Build and set CSP header
    const cspHeader = CSPNonceManager.buildCSPHeader(nonce, config);
    const headerName = config.reportOnly ? 'Content-Security-Policy-Report-Only' : 'Content-Security-Policy';
    
    res.setHeader(headerName, cspHeader);
    
    // Store nonce for potential logging
    res.on('finish', () => {
      if (process.env.NODE_ENV === 'development') {
        console.log(`CSP Nonce for ${req.path}: ${nonce}`);
      }
    });

    next();
  };
};

// Production CSP configuration for EdTech platform
export const productionCSPConfig: CSPConfig = {
  reportOnly: false,
  reportUri: '/api/csp-violation-report',
  allowedDomains: {
    scripts: [
      'https://cdn.jsdelivr.net',
      'https://unpkg.com',
      'https://www.googletagmanager.com', // Analytics
      'https://www.google-analytics.com'
    ],
    styles: [
      'https://fonts.googleapis.com',
      'https://cdn.jsdelivr.net',
      'https://unpkg.com'
    ],
    images: [
      'https://images.unsplash.com',
      'https://via.placeholder.com',
      'https://www.google-analytics.com', // Analytics pixels
      'https://stats.g.doubleclick.net'
    ],
    fonts: [
      'https://fonts.gstatic.com',
      'https://cdn.jsdelivr.net'
    ],
    connect: [
      'https://api.yourapp.com',
      'https://auth.yourapp.com',
      'https://www.google-analytics.com'
    ]
  },
  unsafeInline: {
    scripts: false, // Never allow unsafe-inline for scripts
    styles: false   // Use nonces for styles too
  },
  unsafeEval: false // Never allow eval()
};

// Apply CSP middleware
app.use(cspNonceMiddleware(productionCSPConfig));
```

#### React CSP Integration with Nonces

```typescript
// components/CSPScript.tsx
import React from 'react';

interface CSPScriptProps {
  nonce: string;
  src?: string;
  children?: string;
  async?: boolean;
  defer?: boolean;
  type?: string;
}

export const CSPScript: React.FC<CSPScriptProps> = ({
  nonce,
  src,
  children,
  async = false,
  defer = false,
  type = 'text/javascript'
}) => {
  const scriptProps: React.ScriptHTMLAttributes<HTMLScriptElement> = {
    nonce,
    type,
    async,
    defer,
    ...(src && { src })
  };

  if (src) {
    return <script {...scriptProps} />;
  }

  if (children) {
    return (
      <script 
        {...scriptProps}
        dangerouslySetInnerHTML={{ __html: children }}
      />
    );
  }

  return null;
};

// components/CSPStyle.tsx
interface CSPStyleProps {
  nonce: string;
  href?: string;
  children?: string;
  media?: string;
}

export const CSPStyle: React.FC<CSPStyleProps> = ({
  nonce,
  href,
  children,
  media = 'all'
}) => {
  if (href) {
    return (
      <link
        rel="stylesheet"
        href={href}
        media={media}
        nonce={nonce}
      />
    );
  }

  if (children) {
    return (
      <style
        nonce={nonce}
        media={media}
        dangerouslySetInnerHTML={{ __html: children }}
      />
    );
  }

  return null;
};

// Higher-order component for CSP-aware components
interface WithCSPProps {
  nonce: string;
}

export function withCSP<P extends object>(
  Component: React.ComponentType<P>
) {
  return function CSPWrappedComponent(props: P & WithCSPProps) {
    const { nonce, ...componentProps } = props;
    
    return (
      <div data-csp-nonce={nonce}>
        <Component {...(componentProps as P)} />
      </div>
    );
  };
}

// Example usage in a React page component
interface PageProps {
  nonce: string;
  analyticsId?: string;
}

const HomePage: React.FC<PageProps> = ({ nonce, analyticsId }) => {
  return (
    <html>
      <head>
        <title>Secure EdTech Platform</title>
        
        {/* External stylesheet with nonce */}
        <CSPStyle 
          nonce={nonce}
          href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600&display=swap"
        />
        
        {/* Inline styles with nonce */}
        <CSPStyle nonce={nonce}>
          {`
            body {
              font-family: 'Inter', sans-serif;
              margin: 0;
              padding: 0;
            }
            .hero-section {
              background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
              min-height: 100vh;
              display: flex;
              align-items: center;
              justify-content: center;
            }
          `}
        </CSPStyle>
      </head>
      
      <body>
        <div className="hero-section">
          <h1>Welcome to Secure Learning</h1>
        </div>
        
        {/* Analytics script with nonce */}
        {analyticsId && (
          <CSPScript nonce={nonce} src={`https://www.googletagmanager.com/gtag/js?id=${analyticsId}`} async />
        )}
        
        {/* Inline analytics configuration */}
        {analyticsId && (
          <CSPScript nonce={nonce}>
            {`
              window.dataLayer = window.dataLayer || [];
              function gtag(){dataLayer.push(arguments);}
              gtag('js', new Date());
              gtag('config', '${analyticsId}', {
                page_title: 'Home Page',
                page_location: window.location.href
              });
            `}
          </CSPScript>
        )}
      </body>
    </html>
  );
};

export default withCSP(HomePage);
```

### 2. Hash-Based CSP (Alternative Approach)

#### Static Content Hashing

```typescript
// utils/cspHashGenerator.ts
import crypto from 'crypto';

export class CSPHashGenerator {
  static generateSHA256Hash(content: string): string {
    return crypto
      .createHash('sha256')
      .update(content, 'utf8')
      .digest('base64');
  }

  static generateSHA384Hash(content: string): string {
    return crypto
      .createHash('sha384')
      .update(content, 'utf8')
      .digest('base64');
  }

  static buildHashDirective(content: string, algorithm: 'sha256' | 'sha384' = 'sha256'): string {
    const hash = algorithm === 'sha256' 
      ? this.generateSHA256Hash(content)
      : this.generateSHA384Hash(content);
    
    return `'${algorithm}-${hash}'`;
  }

  // Pre-calculate hashes for static assets
  static preCalculateAssetHashes(assets: Record<string, string>): Record<string, string> {
    const hashes: Record<string, string> = {};
    
    for (const [key, content] of Object.entries(assets)) {
      hashes[key] = this.buildHashDirective(content);
    }
    
    return hashes;
  }
}

// Build-time hash generation for static assets
const staticAssets = {
  mainScript: `
    document.addEventListener('DOMContentLoaded', function() {
      console.log('Application initialized');
      // Main application logic
    });
  `,
  
  analyticsScript: `
    window.dataLayer = window.dataLayer || [];
    function gtag(){dataLayer.push(arguments);}
    gtag('js', new Date());
  `,
  
  mainStyles: `
    body { margin: 0; font-family: 'Inter', sans-serif; }
    .container { max-width: 1200px; margin: 0 auto; padding: 20px; }
  `
};

const assetHashes = CSPHashGenerator.preCalculateAssetHashes(staticAssets);

// CSP header with hashes
const hashBasedCSP = `
  default-src 'self';
  script-src 'self' ${assetHashes.mainScript} ${assetHashes.analyticsScript} https://cdn.jsdelivr.net;
  style-src 'self' ${assetHashes.mainStyles} https://fonts.googleapis.com;
  img-src 'self' data: https://images.unsplash.com;
  font-src 'self' https://fonts.gstatic.com;
  connect-src 'self' https://api.yourapp.com;
  object-src 'none';
  frame-ancestors 'none';
  base-uri 'self';
  form-action 'self';
  report-uri /api/csp-violation-report;
`.replace(/\s+/g, ' ').trim();
```

### 3. CSP Violation Reporting and Monitoring

#### Comprehensive Violation Reporting System

```typescript
// models/cspViolation.ts
export interface CSPViolationReport {
  'document-uri': string;
  'referrer': string;
  'blocked-uri': string;
  'violated-directive': string;
  'original-policy': string;
  'disposition': 'enforce' | 'report';
  'status-code': number;
  'script-sample'?: string;
  'source-file'?: string;
  'line-number'?: number;
  'column-number'?: number;
}

export interface CSPViolationLog {
  id: string;
  timestamp: Date;
  report: CSPViolationReport;
  userAgent: string;
  ipAddress: string;
  sessionId?: string;
  userId?: string;
  severity: 'low' | 'medium' | 'high' | 'critical';
  category: 'script' | 'style' | 'image' | 'font' | 'connect' | 'other';
  resolved: boolean;
  notes?: string;
}

// services/cspViolationService.ts
export class CSPViolationService {
  private static readonly VIOLATION_PATTERNS = {
    // High-risk violations
    critical: [
      /eval/i,
      /javascript:/i,
      /data:text\/html/i,
      /<script/i
    ],
    
    // Suspicious but potentially legitimate
    high: [
      /inline/i,
      /unsafe-eval/i,
      /chrome-extension:/i
    ],
    
    // Common false positives
    medium: [
      /about:blank/i,
      /browser-extension:/i,
      /moz-extension:/i
    ]
  };

  static analyzeSeverity(report: CSPViolationReport): 'low' | 'medium' | 'high' | 'critical' {
    const blockedUri = report['blocked-uri'];
    const violatedDirective = report['violated-directive'];
    const scriptSample = report['script-sample'] || '';

    // Check for critical violations
    for (const pattern of this.VIOLATION_PATTERNS.critical) {
      if (pattern.test(blockedUri) || pattern.test(scriptSample)) {
        return 'critical';
      }
    }

    // Check for high-risk violations
    for (const pattern of this.VIOLATION_PATTERNS.high) {
      if (pattern.test(blockedUri) || pattern.test(violatedDirective)) {
        return 'high';
      }
    }

    // Check for medium-risk violations
    for (const pattern of this.VIOLATION_PATTERNS.medium) {
      if (pattern.test(blockedUri)) {
        return 'medium';
      }
    }

    return 'low';
  }

  static categorizeViolation(report: CSPViolationReport): CSPViolationLog['category'] {
    const directive = report['violated-directive'];
    
    if (directive.includes('script-src')) return 'script';
    if (directive.includes('style-src')) return 'style';
    if (directive.includes('img-src')) return 'image';
    if (directive.includes('font-src')) return 'font';
    if (directive.includes('connect-src')) return 'connect';
    
    return 'other';
  }

  static async processViolation(
    report: CSPViolationReport,
    metadata: {
      userAgent: string;
      ipAddress: string;
      sessionId?: string;
      userId?: string;
    }
  ): Promise<CSPViolationLog> {
    const violation: CSPViolationLog = {
      id: crypto.randomUUID(),
      timestamp: new Date(),
      report,
      userAgent: metadata.userAgent,
      ipAddress: metadata.ipAddress,
      sessionId: metadata.sessionId,
      userId: metadata.userId,
      severity: this.analyzeSeverity(report),
      category: this.categorizeViolation(report),
      resolved: false
    };

    // Store violation in database
    await this.storeViolation(violation);

    // Send alerts for critical violations
    if (violation.severity === 'critical') {
      await this.sendSecurityAlert(violation);
    }

    return violation;
  }

  private static async storeViolation(violation: CSPViolationLog): Promise<void> {
    // Database storage implementation
    // await CSPViolationModel.create(violation);
    console.log('CSP Violation stored:', {
      id: violation.id,
      severity: violation.severity,
      category: violation.category,
      blockedUri: violation.report['blocked-uri']
    });
  }

  private static async sendSecurityAlert(violation: CSPViolationLog): Promise<void> {
    // Security team notification
    console.error('CRITICAL CSP VIOLATION:', {
      timestamp: violation.timestamp,
      blockedUri: violation.report['blocked-uri'],
      violatedDirective: violation.report['violated-directive'],
      userAgent: violation.userAgent,
      ipAddress: violation.ipAddress
    });

    // In production, send to security monitoring system
    // await SecurityAlerts.send({
    //   type: 'CSP_VIOLATION_CRITICAL',
    //   data: violation
    // });
  }

  // Analytics and reporting
  static async getViolationStats(timeframe: 'day' | 'week' | 'month' = 'day') {
    // Implementation would query database for violation statistics
    return {
      totalViolations: 0,
      bySeverity: { critical: 0, high: 0, medium: 0, low: 0 },
      byCategory: { script: 0, style: 0, image: 0, font: 0, connect: 0, other: 0 },
      topBlockedUris: [],
      topViolatedDirectives: []
    };
  }
}

// middleware/cspViolationReporting.ts
export const cspViolationReporting = (req: Request, res: Response, next: NextFunction) => {
  if (req.path === '/api/csp-violation-report' && req.method === 'POST') {
    const report: CSPViolationReport = req.body['csp-report'];
    
    if (!report) {
      return res.status(400).json({ error: 'Invalid CSP report format' });
    }

    // Process violation asynchronously
    CSPViolationService.processViolation(report, {
      userAgent: req.headers['user-agent'] || 'unknown',
      ipAddress: req.ip || 'unknown',
      sessionId: req.sessionID,
      userId: (req as any).user?.id
    }).catch(error => {
      console.error('Failed to process CSP violation:', error);
    });

    return res.status(204).end();
  }

  next();
};

app.use(cspViolationReporting);
```

### 4. CSP Deployment Strategies

#### Gradual CSP Deployment

```typescript
// middleware/gradualCSPDeployment.ts
interface CSPDeploymentConfig {
  stage: 'monitoring' | 'partial' | 'full';
  reportOnlyPercentage?: number;
  userSegments?: {
    internal: boolean;
    beta: boolean;
    production: boolean;
  };
}

export const gradualCSPDeployment = (config: CSPDeploymentConfig) => {
  return (req: Request, res: Response, next: NextFunction) => {
    const { stage, reportOnlyPercentage = 10, userSegments } = config;
    
    let useReportOnly = false;
    
    switch (stage) {
      case 'monitoring':
        useReportOnly = true;
        break;
        
      case 'partial':
        // Gradual rollout based on percentage
        const random = Math.random() * 100;
        useReportOnly = random < reportOnlyPercentage;
        break;
        
      case 'full':
        useReportOnly = false;
        break;
    }

    // Override based on user segments
    if (userSegments) {
      const isInternalUser = req.headers['x-internal-user'] === 'true';
      const isBetaUser = req.headers['x-beta-user'] === 'true';
      
      if (isInternalUser && userSegments.internal) {
        useReportOnly = false; // Always enforce for internal users
      } else if (isBetaUser && userSegments.beta) {
        useReportOnly = false; // Always enforce for beta users
      }
    }

    // Apply CSP with appropriate mode
    const cspConfig: CSPConfig = {
      ...productionCSPConfig,
      reportOnly: useReportOnly
    };

    // Continue with normal CSP middleware
    return cspNonceMiddleware(cspConfig)(req, res, next);
  };
};

// Deployment stages
const deploymentStages = {
  // Stage 1: Monitor violations without blocking
  monitoring: gradualCSPDeployment({
    stage: 'monitoring',
    userSegments: { internal: true, beta: false, production: false }
  }),
  
  // Stage 2: Partial enforcement
  partial: gradualCSPDeployment({
    stage: 'partial',
    reportOnlyPercentage: 50,
    userSegments: { internal: true, beta: true, production: false }
  }),
  
  // Stage 3: Full enforcement
  full: gradualCSPDeployment({
    stage: 'full',
    userSegments: { internal: true, beta: true, production: true }
  })
};

// Use appropriate stage based on environment
const currentStage = process.env.CSP_DEPLOYMENT_STAGE || 'monitoring';
app.use(deploymentStages[currentStage] || deploymentStages.monitoring);
```

### 5. CSP Testing and Validation

#### Automated CSP Testing Suite

```typescript
// tests/csp.test.ts
import request from 'supertest';
import { app } from '../src/app';
import { CSPNonceManager } from '../src/middleware/cspNonce';

describe('Content Security Policy', () => {
  describe('CSP Header Generation', () => {
    it('should generate CSP header with nonce', async () => {
      const response = await request(app).get('/');
      
      const cspHeader = response.headers['content-security-policy'];
      expect(cspHeader).toBeDefined();
      expect(cspHeader).toContain("default-src 'self'");
      expect(cspHeader).toMatch(/nonce-[A-Za-z0-9+/]+=*/);
    });

    it('should generate unique nonces for each request', async () => {
      const response1 = await request(app).get('/');
      const response2 = await request(app).get('/');
      
      const nonce1 = response1.headers['content-security-policy'].match(/nonce-([A-Za-z0-9+/=]+)/)[1];
      const nonce2 = response2.headers['content-security-policy'].match(/nonce-([A-Za-z0-9+/=]+)/)[1];
      
      expect(nonce1).not.toBe(nonce2);
    });

    it('should include report-uri directive', async () => {
      const response = await request(app).get('/');
      const cspHeader = response.headers['content-security-policy'];
      
      expect(cspHeader).toContain('report-uri /api/csp-violation-report');
    });
  });

  describe('CSP Violation Reporting', () => {
    it('should accept valid CSP violation reports', async () => {
      const violationReport = {
        'csp-report': {
          'document-uri': 'https://example.com/page',
          'referrer': 'https://example.com',
          'blocked-uri': 'https://malicious.com/script.js',
          'violated-directive': 'script-src',
          'original-policy': "default-src 'self'",
          'disposition': 'enforce' as const,
          'status-code': 200
        }
      };

      const response = await request(app)
        .post('/api/csp-violation-report')
        .send(violationReport);
      
      expect(response.status).toBe(204);
    });

    it('should reject invalid CSP violation reports', async () => {
      const invalidReport = { invalid: 'data' };

      const response = await request(app)
        .post('/api/csp-violation-report')
        .send(invalidReport);
      
      expect(response.status).toBe(400);
    });
  });

  describe('CSP Nonce Functionality', () => {
    it('should generate cryptographically secure nonces', () => {
      const nonce1 = CSPNonceManager.generateNonce();
      const nonce2 = CSPNonceManager.generateNonce();
      
      expect(nonce1).not.toBe(nonce2);
      expect(nonce1).toMatch(/^[A-Za-z0-9+/]+=*$/); // Base64 format
      expect(Buffer.from(nonce1, 'base64').length).toBe(32); // 32 bytes
    });

    it('should build proper CSP header format', () => {
      const nonce = 'test-nonce-123';
      const header = CSPNonceManager.buildCSPHeader(nonce);
      
      expect(header).toContain(`'nonce-${nonce}'`);
      expect(header).toContain("default-src 'self'");
      expect(header).toContain("object-src 'none'");
      expect(header).toContain("frame-ancestors 'none'");
    });
  });

  describe('CSP Policy Effectiveness', () => {
    it('should block unauthorized inline scripts', async () => {
      // This would require browser automation testing
      // Using tools like Puppeteer or Playwright
      // Example structure:
      
      // const page = await browser.newPage();
      // const consoleLogs = [];
      // 
      // page.on('console', msg => consoleLogs.push(msg.text()));
      // page.on('pageerror', error => consoleLogs.push(`Error: ${error.message}`));
      // 
      // await page.goto('http://localhost:3000/test-page');
      // await page.evaluate(() => {
      //   const script = document.createElement('script');
      //   script.innerHTML = 'console.log("Unauthorized script");';
      //   document.head.appendChild(script);
      // });
      // 
      // expect(consoleLogs).toContain(expect.stringContaining('CSP'));
    });
  });
});

// Browser-based CSP testing with Playwright
describe('CSP Browser Tests', () => {
  let browser: any;
  let page: any;

  beforeAll(async () => {
    // browser = await playwright.chromium.launch();
    // page = await browser.newPage();
  });

  afterAll(async () => {
    // await browser.close();
  });

  it('should block inline scripts without nonce', async () => {
    // const violations = [];
    // 
    // page.on('response', response => {
    //   if (response.url().includes('csp-violation-report')) {
    //     violations.push(response);
    //   }
    // });
    // 
    // await page.goto('http://localhost:3000/test-page');
    // 
    // await page.evaluate(() => {
    //   const script = document.createElement('script');
    //   script.innerHTML = 'alert("This should be blocked");';
    //   document.body.appendChild(script);
    // });
    // 
    // await page.waitForTimeout(1000);
    // expect(violations.length).toBeGreaterThan(0);
  });

  it('should allow scripts with correct nonce', async () => {
    // Implementation for testing nonce-based script execution
  });
});
```

### 6. CSP Best Practices for EdTech Platforms

#### EdTech-Specific CSP Configuration

```typescript
// config/edtechCSP.ts
export const edtechCSPConfig: CSPConfig = {
  reportOnly: false,
  reportUri: '/api/csp-violation-report',
  allowedDomains: {
    scripts: [
      // CDN for educational libraries
      'https://cdn.jsdelivr.net',
      'https://unpkg.com',
      
      // Math rendering (MathJax/KaTeX)
      'https://cdn.mathjax.org',
      'https://cdn.jsdelivr.net/npm/katex@0.16.0/dist/',
      
      // Video platforms for educational content
      'https://www.youtube.com',
      'https://vimeo.com',
      'https://player.vimeo.com',
      
      // Analytics and monitoring
      'https://www.googletagmanager.com',
      'https://www.google-analytics.com',
      'https://connect.facebook.net', // Facebook Pixel
      
      // Payment processing
      'https://js.stripe.com',
      'https://checkout.stripe.com',
      
      // Authentication providers
      'https://apis.google.com', // Google OAuth
      'https://connect.facebook.net', // Facebook Login
      
      // Educational APIs
      'https://api.quizlet.com',
      'https://api.khan-academy.org'
    ],
    
    styles: [
      'https://fonts.googleapis.com',
      'https://cdn.jsdelivr.net',
      'https://unpkg.com',
      'https://cdn.mathjax.org',
      'https://cdn.jsdelivr.net/npm/katex@0.16.0/dist/'
    ],
    
    images: [
      // Educational content sources
      'https://images.unsplash.com',
      'https://via.placeholder.com',
      'https://picsum.photos',
      
      // User uploads (should be from your own CDN)
      'https://cdn.yourdomain.com',
      'https://uploads.yourdomain.com',
      
      // Video thumbnails
      'https://img.youtube.com',
      'https://i.vimeocdn.com',
      
      // Analytics pixels
      'https://www.google-analytics.com',
      'https://www.facebook.com',
      
      // Payment provider images
      'https://q.stripe.com'
    ],
    
    fonts: [
      'https://fonts.gstatic.com',
      'https://cdn.jsdelivr.net'
    ],
    
    connect: [
      // Your API endpoints
      'https://api.yourdomain.com',
      'https://auth.yourdomain.com',
      
      // Analytics
      'https://www.google-analytics.com',
      'https://analytics.facebook.com',
      
      // Payment processing
      'https://api.stripe.com',
      
      // Educational content APIs
      'https://api.quizlet.com',
      'https://api.khan-academy.org',
      
      // Video streaming
      'https://www.youtube.com',
      'https://vimeo.com'
    ]
  },
  unsafeInline: {
    scripts: false, // Never allow for security
    styles: false   // Use nonces instead
  },
  unsafeEval: false // Never allow eval
};

// Special CSP for quiz/assessment pages (more restrictive)
export const assessmentCSPConfig: CSPConfig = {
  ...edtechCSPConfig,
  allowedDomains: {
    scripts: [
      // Only essential scripts for assessments
      'https://cdn.jsdelivr.net/npm/katex@0.16.0/dist/' // Math rendering only
    ],
    styles: [
      'https://fonts.googleapis.com',
      'https://cdn.jsdelivr.net/npm/katex@0.16.0/dist/'
    ],
    images: [
      'https://cdn.yourdomain.com', // Only your own images
      'https://uploads.yourdomain.com'
    ],
    fonts: [
      'https://fonts.gstatic.com'
    ],
    connect: [
      'https://api.yourdomain.com' // Only your own API
    ]
  }
};

// Content creation tools CSP (more permissive for educators)
export const contentCreationCSPConfig: CSPConfig = {
  ...edtechCSPConfig,
  allowedDomains: {
    ...edtechCSPConfig.allowedDomains,
    scripts: [
      ...edtechCSPConfig.allowedDomains.scripts,
      
      // Rich text editors
      'https://cdn.tiny.cloud', // TinyMCE
      'https://cdn.ckeditor.com', // CKEditor
      
      // Media libraries
      'https://widget.cloudinary.com',
      'https://upload-widget.cloudinary.com'
    ],
    connect: [
      ...edtechCSPConfig.allowedDomains.connect,
      
      // File upload services
      'https://api.cloudinary.com',
      'https://upload.cloudinary.com'
    ]
  }
};
```

## CSP Implementation Checklist

### Development Phase
- [ ] **CSP Strategy**: Choose between nonce-based, hash-based, or hybrid approach
- [ ] **Directive Configuration**: Configure all necessary CSP directives
- [ ] **Nonce Generation**: Implement cryptographically secure nonce generation
- [ ] **React Integration**: Update React components to use CSP-compatible patterns
- [ ] **Asset Management**: Ensure all static assets work with CSP policy
- [ ] **Third-Party Integration**: Configure CSP for required third-party services

### Testing Phase
- [ ] **Violation Monitoring**: Set up CSP violation reporting and monitoring
- [ ] **Browser Testing**: Test CSP policy across different browsers
- [ ] **Functionality Testing**: Ensure all application features work with CSP
- [ ] **Performance Testing**: Measure CSP performance impact
- [ ] **Security Testing**: Verify CSP effectively blocks malicious content

### Deployment Phase
- [ ] **Gradual Rollout**: Implement staged CSP deployment
- [ ] **Report-Only Mode**: Start with report-only to identify issues
- [ ] **Violation Analysis**: Analyze and resolve CSP violations
- [ ] **Policy Refinement**: Refine CSP policy based on real-world usage
- [ ] **Full Enforcement**: Enable full CSP enforcement
- [ ] **Monitoring Setup**: Set up ongoing CSP violation monitoring

### Maintenance Phase
- [ ] **Regular Review**: Regularly review and update CSP policy
- [ ] **Violation Analysis**: Analyze new violations for security threats
- [ ] **Policy Updates**: Update CSP for new features and third-party services
- [ ] **Security Audits**: Include CSP in regular security audits
- [ ] **Team Training**: Train team on CSP best practices
- [ ] **Documentation**: Maintain up-to-date CSP documentation

## Advanced CSP Considerations

### 1. CSP for Single Page Applications (SPAs)

```typescript
// Special considerations for React/Vue/Angular SPAs
export const spaCSPConfig = {
  // Allow dynamic imports for code splitting
  'script-src': "'self' 'nonce-{nonce}' 'strict-dynamic'",
  
  // Handle dynamic style injection
  'style-src': "'self' 'nonce-{nonce}' 'unsafe-hashes'",
  
  // WebSocket connections for real-time features
  'connect-src': "'self' ws: wss: https://api.yourdomain.com"
};
```

### 2. CSP for Progressive Web Apps (PWAs)

```typescript
// PWA-specific CSP considerations
export const pwaCSPConfig = {
  // Service Worker
  'worker-src': "'self'",
  
  // Web App Manifest
  'manifest-src': "'self'",
  
  // Offline functionality
  'connect-src': "'self' 'unsafe-inline'"
};
```

## Additional Resources

### Official Documentation
- [MDN Content Security Policy](https://developer.mozilla.org/en-US/docs/Web/HTTP/CSP)
- [W3C CSP Level 3 Specification](https://w3c.github.io/webappsec-csp/)
- [Google CSP Evaluator](https://csp-evaluator.withgoogle.com/)

### Security Tools
- [CSP Scanner by Mozilla Observatory](https://observatory.mozilla.org/)
- [Report URI CSP Analyzer](https://report-uri.com/home/analyse)
- [CSP Hash Generator](https://report-uri.com/home/hash)

### Educational Resources
- [OWASP CSP Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Content_Security_Policy_Cheat_Sheet.html)
- [Google Web Fundamentals CSP Guide](https://developers.google.com/web/fundamentals/security/csp)

---

## Navigation

- ← Back to: [Frontend Security Best Practices](./README.md)
- → Next: [Best Practices](./best-practices.md)
- → Previous: [CSRF Protection Methods](./csrf-protection-methods.md)
- → Related: [XSS Prevention Strategies](./xss-prevention-strategies.md)