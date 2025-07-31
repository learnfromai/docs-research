# CSRF Protection Methods: Complete Implementation Guide

Cross-Site Request Forgery (CSRF) attacks exploit the trust relationship between a user's browser and a web application, forcing authenticated users to perform unintended actions. This comprehensive guide provides practical implementation strategies for robust CSRF protection in modern web applications.

## Understanding CSRF Attacks

### How CSRF Attacks Work

#### Attack Scenario Example
```html
<!-- Malicious website with hidden form -->
<html>
<body onload="document.forms[0].submit()">
  <form action="https://bank.com/transfer" method="POST">
    <input type="hidden" name="to" value="attacker-account" />
    <input type="hidden" name="amount" value="10000" />
  </form>
</body>
</html>
```

When an authenticated user visits this malicious page, their browser automatically includes authentication cookies with the request, potentially transferring money without the user's knowledge.

### CSRF Attack Vectors

#### 1. Form-Based Attacks
```typescript
// Vulnerable endpoint without CSRF protection
app.post('/api/user/update-profile', authenticateUser, (req, res) => {
  // VULNERABLE: No CSRF token validation
  const { name, email, bio } = req.body;
  
  // Update user profile directly
  User.findByIdAndUpdate(req.user.id, { name, email, bio });
  res.json({ success: true });
});

// Malicious form on attacker's site
/*
<form action="https://victim-site.com/api/user/update-profile" method="POST">
  <input type="hidden" name="name" value="Hacked User" />
  <input type="hidden" name="email" value="hacker@evil.com" />
  <input type="hidden" name="bio" value="Account compromised" />
  <input type="submit" value="Click for free gift!" />
</form>
*/
```

#### 2. AJAX-Based Attacks
```javascript
// Malicious JavaScript on attacker's site
fetch('https://victim-site.com/api/user/delete-account', {
  method: 'DELETE',
  credentials: 'include' // Includes authentication cookies
});
```

#### 3. Image/Link-Based Attacks
```html
<!-- State-changing GET request (vulnerable design) -->
<img src="https://bank.com/api/transfer?to=attacker&amount=1000" 
     style="display:none" />
```

## Comprehensive CSRF Protection Strategies

### 1. Synchronizer Token Pattern

#### Server-Side CSRF Token Implementation

```typescript
// utils/csrfTokenManager.ts
import crypto from 'crypto';
import { Request } from 'express';

interface CSRFSession {
  secret: string;
  tokens: Set<string>;
  createdAt: Date;
}

export class CSRFTokenManager {
  private static readonly TOKEN_LIFETIME = 60 * 60 * 1000; // 1 hour
  private static readonly MAX_TOKENS_PER_SESSION = 10;

  static generateSecret(): string {
    return crypto.randomBytes(32).toString('hex');
  }

  static generateToken(secret: string): string {
    const timestamp = Date.now().toString();
    const randomBytes = crypto.randomBytes(16).toString('hex');
    const payload = `${timestamp}:${randomBytes}`;
    
    const hmac = crypto.createHmac('sha256', secret);
    hmac.update(payload);
    const signature = hmac.digest('hex');
    
    return `${payload}:${signature}`;
  }

  static validateToken(secret: string, token: string): boolean {
    if (!secret || !token) {
      return false;
    }

    try {
      const parts = token.split(':');
      if (parts.length !== 3) {
        return false;
      }

      const [timestamp, randomBytes, signature] = parts;
      const payload = `${timestamp}:${randomBytes}`;
      
      // Verify signature
      const hmac = crypto.createHmac('sha256', secret);
      hmac.update(payload);
      const expectedSignature = hmac.digest('hex');
      
      if (!crypto.timingSafeEqual(
        Buffer.from(signature, 'hex'),
        Buffer.from(expectedSignature, 'hex')
      )) {
        return false;
      }

      // Check token expiration
      const tokenTime = parseInt(timestamp, 10);
      const now = Date.now();
      
      if (now - tokenTime > this.TOKEN_LIFETIME) {
        return false;
      }

      return true;
    } catch (error) {
      return false;
    }
  }

  static manageSessionTokens(req: Request & { session: any }): void {
    if (!req.session.csrf) {
      req.session.csrf = {
        secret: this.generateSecret(),
        tokens: new Set<string>(),
        createdAt: new Date()
      };
    }

    const csrfSession: CSRFSession = req.session.csrf;
    
    // Clean up expired tokens
    const now = Date.now();
    const expiredTime = now - this.TOKEN_LIFETIME;
    
    for (const token of csrfSession.tokens) {
      try {
        const timestamp = parseInt(token.split(':')[0], 10);
        if (timestamp < expiredTime) {
          csrfSession.tokens.delete(token);
        }
      } catch (error) {
        csrfSession.tokens.delete(token);
      }
    }

    // Limit number of tokens per session
    if (csrfSession.tokens.size > this.MAX_TOKENS_PER_SESSION) {
      const tokensArray = Array.from(csrfSession.tokens);
      const oldestTokens = tokensArray.slice(0, -this.MAX_TOKENS_PER_SESSION);
      oldestTokens.forEach(token => csrfSession.tokens.delete(token));
    }
  }
}

// middleware/csrfProtection.ts
import { Request, Response, NextFunction } from 'express';
import { CSRFTokenManager } from '../utils/csrfTokenManager';

interface CSRFRequest extends Request {
  session: {
    csrf?: {
      secret: string;
      tokens: Set<string>;
      createdAt: Date;
    };
  };
  csrfToken?: string;
}

interface CSRFOptions {
  excludePaths?: string[];
  tokenHeader?: string;
  tokenField?: string;
  safeMethods?: string[];
  enableDoubleSubmitCookie?: boolean;
}

export const csrfProtection = (options: CSRFOptions = {}) => {
  const {
    excludePaths = [],
    tokenHeader = 'x-csrf-token',
    tokenField = '_csrf',
    safeMethods = ['GET', 'HEAD', 'OPTIONS'],
    enableDoubleSubmitCookie = false
  } = options;

  return (req: CSRFRequest, res: Response, next: NextFunction) => {
    // Skip CSRF protection for excluded paths
    if (excludePaths.some(path => req.path.startsWith(path))) {
      return next();
    }

    // Initialize or manage CSRF session
    CSRFTokenManager.manageSessionTokens(req);

    const csrfSession = req.session.csrf!;

    // Generate new token for response
    const newToken = CSRFTokenManager.generateToken(csrfSession.secret);
    csrfSession.tokens.add(newToken);
    
    // Make token available in response locals
    res.locals.csrfToken = newToken;
    req.csrfToken = newToken;

    // Set double-submit cookie if enabled
    if (enableDoubleSubmitCookie) {
      res.cookie('csrf-token', newToken, {
        httpOnly: false, // JavaScript needs to read this
        secure: process.env.NODE_ENV === 'production',
        sameSite: 'strict'
      });
    }

    // Skip validation for safe methods
    if (safeMethods.includes(req.method)) {
      return next();
    }

    // Extract token from request
    const token = req.headers[tokenHeader] as string ||
                  req.body[tokenField] ||
                  req.query[tokenField] as string;

    if (!token) {
      return res.status(403).json({
        success: false,
        message: 'CSRF token missing',
        code: 'CSRF_TOKEN_MISSING'
      });
    }

    // Validate token
    if (!CSRFTokenManager.validateToken(csrfSession.secret, token)) {
      return res.status(403).json({
        success: false,
        message: 'Invalid CSRF token',
        code: 'CSRF_TOKEN_INVALID'
      });
    }

    // Check if token was previously used (optional replay protection)
    if (!csrfSession.tokens.has(token)) {
      return res.status(403).json({
        success: false,
        message: 'CSRF token already used',
        code: 'CSRF_TOKEN_REUSED'
      });
    }

    // Remove token after successful validation (one-time use)
    csrfSession.tokens.delete(token);

    next();
  };
};

// Apply CSRF protection globally
app.use(csrfProtection({
  excludePaths: ['/api/auth/login', '/api/public'],
  enableDoubleSubmitCookie: true
}));

// Endpoint to get new CSRF token
app.get('/api/csrf-token', (req: CSRFRequest, res: Response) => {
  res.json({
    success: true,
    csrfToken: req.csrfToken,
    expiresIn: 3600 // 1 hour
  });
});
```

#### Frontend CSRF Token Management

```typescript
// services/csrfService.ts
interface CSRFTokenResponse {
  success: boolean;
  csrfToken: string;
  expiresIn: number;
}

export class CSRFService {
  private static instance: CSRFService;
  private token: string | null = null;
  private tokenExpiry: number = 0;
  private refreshPromise: Promise<void> | null = null;

  private constructor() {
    // Auto-refresh token before expiry
    this.scheduleTokenRefresh();
  }

  static getInstance(): CSRFService {
    if (!CSRFService.instance) {
      CSRFService.instance = new CSRFService();
    }
    return CSRFService.instance;
  }

  async getToken(): Promise<string> {
    // Check if token is expired or about to expire
    const now = Date.now();
    const bufferTime = 5 * 60 * 1000; // 5 minutes buffer
    
    if (!this.token || now > (this.tokenExpiry - bufferTime)) {
      await this.refreshToken();
    }

    return this.token!;
  }

  async refreshToken(): Promise<void> {
    // Prevent multiple simultaneous refresh requests
    if (this.refreshPromise) {
      return this.refreshPromise;
    }

    this.refreshPromise = this.performTokenRefresh();
    
    try {
      await this.refreshPromise;
    } finally {
      this.refreshPromise = null;
    }
  }

  private async performTokenRefresh(): Promise<void> {
    try {
      const response = await fetch('/api/csrf-token', {
        method: 'GET',
        credentials: 'include',
        headers: {
          'Content-Type': 'application/json'
        }
      });

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }

      const data: CSRFTokenResponse = await response.json();
      
      if (data.success && data.csrfToken) {
        this.token = data.csrfToken;
        this.tokenExpiry = Date.now() + (data.expiresIn * 1000);
        this.scheduleTokenRefresh();
      } else {
        throw new Error('Invalid CSRF token response');
      }
    } catch (error) {
      console.error('CSRF token refresh failed:', error);
      this.token = null;
      this.tokenExpiry = 0;
      
      // Retry after delay
      setTimeout(() => this.refreshToken(), 5000);
      throw error;
    }
  }

  private scheduleTokenRefresh(): void {
    const now = Date.now();
    const refreshTime = this.tokenExpiry - (10 * 60 * 1000); // 10 minutes before expiry
    const delay = Math.max(0, refreshTime - now);

    setTimeout(() => {
      this.refreshToken().catch(error => {
        console.error('Scheduled CSRF token refresh failed:', error);
      });
    }, delay);
  }

  clearToken(): void {
    this.token = null;
    this.tokenExpiry = 0;
  }

  // For testing purposes
  getTokenInfo(): { token: string | null; expiry: number } {
    return {
      token: this.token,
      expiry: this.tokenExpiry
    };
  }
}

// HTTP client with automatic CSRF protection
export class SecureHTTPClient {
  private csrfService = CSRFService.getInstance();
  private maxRetries = 3;

  async request(url: string, options: RequestInit = {}): Promise<Response> {
    return this.requestWithRetry(url, options, 0);
  }

  private async requestWithRetry(
    url: string, 
    options: RequestInit, 
    retryCount: number
  ): Promise<Response> {
    try {
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

      // Handle CSRF token errors with retry
      if (response.status === 403 && retryCount < this.maxRetries) {
        const errorData = await response.json().catch(() => ({}));
        
        if (errorData.code?.includes('CSRF')) {
          console.warn('CSRF token error, refreshing and retrying:', errorData.code);
          await this.csrfService.refreshToken();
          return this.requestWithRetry(url, options, retryCount + 1);
        }
      }

      return response;
    } catch (error) {
      if (retryCount < this.maxRetries) {
        console.warn(`Request failed, retrying (${retryCount + 1}/${this.maxRetries}):`, error);
        await new Promise(resolve => setTimeout(resolve, 1000 * (retryCount + 1)));
        return this.requestWithRetry(url, options, retryCount + 1);
      }
      
      throw error;
    }
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

  async patch(url: string, data: any): Promise<Response> {
    return this.request(url, {
      method: 'PATCH',
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

### 2. Double Submit Cookie Pattern

#### Implementation with Cookie-based CSRF Protection

```typescript
// middleware/doubleSubmitCSRF.ts
import crypto from 'crypto';
import { Request, Response, NextFunction } from 'express';

interface DoubleSubmitOptions {
  cookieName?: string;
  headerName?: string;
  secure?: boolean;
  sameSite?: 'strict' | 'lax' | 'none';
  domain?: string;
  maxAge?: number;
}

export const doubleSubmitCSRF = (options: DoubleSubmitOptions = {}) => {
  const {
    cookieName = 'csrf-token',
    headerName = 'x-csrf-token',
    secure = process.env.NODE_ENV === 'production',
    sameSite = 'strict',
    domain,
    maxAge = 60 * 60 * 1000 // 1 hour
  } = options;

  return (req: Request, res: Response, next: NextFunction) => {
    // Generate CSRF token if not present
    let csrfToken = req.cookies[cookieName];
    
    if (!csrfToken) {
      csrfToken = crypto.randomBytes(32).toString('hex');
      
      res.cookie(cookieName, csrfToken, {
        httpOnly: false, // JavaScript needs to read this
        secure,
        sameSite,
        domain,
        maxAge
      });
    }

    // Make token available to templates/responses
    res.locals.csrfToken = csrfToken;

    // Skip validation for safe methods
    if (['GET', 'HEAD', 'OPTIONS'].includes(req.method)) {
      return next();
    }

    // Validate CSRF token for state-changing requests
    const headerToken = req.headers[headerName] as string;
    
    if (!headerToken) {
      return res.status(403).json({
        success: false,
        message: 'CSRF token missing in headers',
        code: 'CSRF_HEADER_MISSING'
      });
    }

    if (!crypto.timingSafeEqual(
      Buffer.from(csrfToken, 'hex'),
      Buffer.from(headerToken, 'hex')
    )) {
      return res.status(403).json({
        success: false,
        message: 'CSRF token mismatch',
        code: 'CSRF_TOKEN_MISMATCH'
      });
    }

    next();
  };
};

// Frontend implementation for double submit pattern
export class DoubleSubmitCSRFClient {
  private cookieName: string;

  constructor(cookieName: string = 'csrf-token') {
    this.cookieName = cookieName;
  }

  private getCsrfTokenFromCookie(): string | null {
    const cookies = document.cookie.split(';');
    
    for (const cookie of cookies) {
      const [name, value] = cookie.trim().split('=');
      if (name === this.cookieName) {
        return decodeURIComponent(value);
      }
    }
    
    return null;
  }

  async request(url: string, options: RequestInit = {}): Promise<Response> {
    const token = this.getCsrfTokenFromCookie();
    
    if (!token && !['GET', 'HEAD', 'OPTIONS'].includes(options.method || 'GET')) {
      throw new Error('CSRF token not found in cookies');
    }

    const headers = new Headers(options.headers);
    
    if (token && !['GET', 'HEAD', 'OPTIONS'].includes(options.method || 'GET')) {
      headers.set('X-CSRF-Token', token);
    }

    return fetch(url, {
      ...options,
      credentials: 'include',
      headers
    });
  }
}
```

### 3. SameSite Cookie Configuration

#### Advanced Cookie Security Configuration

```typescript
// middleware/secureCookies.ts
import { Request, Response, NextFunction } from 'express';

interface SecureCookieOptions {
  sessionCookieName?: string;
  csrfCookieName?: string;
  domain?: string;
  secure?: boolean;
  sameSite?: 'strict' | 'lax' | 'none';
  httpOnly?: boolean;
  maxAge?: number;
}

export const configureSameSiteCookies = (options: SecureCookieOptions = {}) => {
  const {
    sessionCookieName = 'sessionId',
    csrfCookieName = 'csrf-token',
    domain,
    secure = process.env.NODE_ENV === 'production',
    sameSite = 'strict',
    httpOnly = true,
    maxAge = 24 * 60 * 60 * 1000 // 24 hours
  } = options;

  return (req: Request, res: Response, next: NextFunction) => {
    // Override res.cookie to apply secure defaults
    const originalCookie = res.cookie.bind(res);
    
    res.cookie = function(name: string, value: any, options: any = {}) {
      const secureOptions = {
        domain,
        secure,
        sameSite,
        httpOnly: name !== csrfCookieName, // CSRF token needs to be readable by JS
        maxAge,
        ...options
      };

      // Special handling for session cookies
      if (name === sessionCookieName) {
        secureOptions.httpOnly = true;
        secureOptions.sameSite = 'strict';
      }

      // Special handling for CSRF cookies
      if (name === csrfCookieName) {
        secureOptions.httpOnly = false;
        secureOptions.sameSite = 'strict';
      }

      return originalCookie(name, value, secureOptions);
    };

    next();
  };
};

// Session configuration with SameSite protection
export const sessionConfig = {
  name: 'sessionId',
  secret: process.env.SESSION_SECRET!,
  resave: false,
  saveUninitialized: false,
  cookie: {
    secure: process.env.NODE_ENV === 'production',
    httpOnly: true,
    maxAge: 24 * 60 * 60 * 1000, // 24 hours
    sameSite: 'strict' as const // Strong CSRF protection
  },
  // Additional security options
  genid: () => {
    return crypto.randomBytes(32).toString('hex');
  }
};
```

### 4. Advanced CSRF Protection Techniques

#### Origin and Referer Header Validation

```typescript
// middleware/originValidation.ts
export const validateOrigin = (allowedOrigins: string[] = []) => {
  return (req: Request, res: Response, next: NextFunction) => {
    // Skip validation for safe methods
    if (['GET', 'HEAD', 'OPTIONS'].includes(req.method)) {
      return next();
    }

    const origin = req.headers.origin;
    const referer = req.headers.referer;
    const host = req.headers.host;

    // Build allowed origins list
    const allowed = new Set([
      ...allowedOrigins,
      `https://${host}`,
      `http://${host}` // Only for development
    ]);

    // Validate Origin header
    if (origin && !allowed.has(origin)) {
      console.warn('CSRF attempt detected - invalid origin:', {
        origin,
        host,
        userAgent: req.headers['user-agent'],
        ip: req.ip
      });

      return res.status(403).json({
        success: false,
        message: 'Invalid origin',
        code: 'INVALID_ORIGIN'
      });
    }

    // Validate Referer header as fallback
    if (!origin && referer) {
      const refererURL = new URL(referer);
      const refererOrigin = `${refererURL.protocol}//${refererURL.host}`;
      
      if (!allowed.has(refererOrigin)) {
        console.warn('CSRF attempt detected - invalid referer:', {
          referer: refererOrigin,
          host,
          userAgent: req.headers['user-agent'],
          ip: req.ip
        });

        return res.status(403).json({
          success: false,
          message: 'Invalid referer',
          code: 'INVALID_REFERER'
        });
      }
    }

    next();
  };
};
```

#### Custom Header CSRF Protection

```typescript
// middleware/customHeaderCSRF.ts
export const customHeaderCSRF = (headerName: string = 'x-requested-with') => {
  return (req: Request, res: Response, next: NextFunction) => {
    // Skip for safe methods
    if (['GET', 'HEAD', 'OPTIONS'].includes(req.method)) {
      return next();
    }

    const customHeader = req.headers[headerName.toLowerCase()];
    
    if (!customHeader) {
      return res.status(403).json({
        success: false,
        message: `Required header '${headerName}' missing`,
        code: 'CUSTOM_HEADER_MISSING'
      });
    }

    // Common values: 'XMLHttpRequest', 'fetch', custom application identifier
    const validValues = ['XMLHttpRequest', 'fetch', 'MyApp'];
    
    if (!validValues.includes(customHeader as string)) {
      return res.status(403).json({
        success: false,
        message: `Invalid header value for '${headerName}'`,
        code: 'CUSTOM_HEADER_INVALID'
      });
    }

    next();
  };
};

// Frontend implementation
export class CustomHeaderClient {
  private headerName: string;
  private headerValue: string;

  constructor(headerName: string = 'X-Requested-With', headerValue: string = 'XMLHttpRequest') {
    this.headerName = headerName;
    this.headerValue = headerValue;
  }

  async request(url: string, options: RequestInit = {}): Promise<Response> {
    const headers = new Headers(options.headers);
    
    // Add custom header for CSRF protection
    if (!['GET', 'HEAD', 'OPTIONS'].includes(options.method || 'GET')) {
      headers.set(this.headerName, this.headerValue);
    }

    return fetch(url, {
      ...options,
      credentials: 'include',
      headers
    });
  }
}
```

### 5. React Integration with CSRF Protection

#### React Hooks for CSRF Protection

```typescript
// hooks/useCSRFProtection.ts
import { useState, useEffect, useCallback } from 'react';
import { CSRFService } from '../services/csrfService';

interface CSRFState {
  token: string | null;
  loading: boolean;
  error: string | null;
}

export const useCSRFProtection = () => {
  const [state, setState] = useState<CSRFState>({
    token: null,
    loading: true,
    error: null
  });

  const csrfService = CSRFService.getInstance();

  const refreshToken = useCallback(async () => {
    setState(prev => ({ ...prev, loading: true, error: null }));
    
    try {
      const token = await csrfService.getToken();
      setState({ token, loading: false, error: null });
    } catch (error) {
      setState({
        token: null,
        loading: false,
        error: error instanceof Error ? error.message : 'Failed to get CSRF token'
      });
    }
  }, [csrfService]);

  useEffect(() => {
    refreshToken();
  }, [refreshToken]);

  return {
    ...state,
    refreshToken
  };
};

// Protected form component
interface ProtectedFormProps {
  onSubmit: (data: any, csrfToken: string) => Promise<void>;
  children: React.ReactNode;
  className?: string;
}

export const ProtectedForm: React.FC<ProtectedFormProps> = ({
  onSubmit,
  children,
  className = ''
}) => {
  const { token, loading, error } = useCSRFProtection();
  const [submitting, setSubmitting] = useState(false);

  const handleSubmit = async (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    
    if (!token || submitting) {
      return;
    }

    setSubmitting(true);
    
    try {
      const formData = new FormData(event.currentTarget);
      const data = Object.fromEntries(formData.entries());
      
      await onSubmit(data, token);
    } catch (error) {
      console.error('Form submission failed:', error);
    } finally {
      setSubmitting(false);
    }
  };

  if (loading) {
    return <div>Loading secure form...</div>;
  }

  if (error) {
    return <div>Error: {error}</div>;
  }

  return (
    <form onSubmit={handleSubmit} className={className}>
      {children}
      <input type="hidden" name="_csrf" value={token || ''} />
      <button type="submit" disabled={submitting || !token}>
        {submitting ? 'Submitting...' : 'Submit'}
      </button>
    </form>
  );
};

// Usage example
const UserProfileForm: React.FC = () => {
  const handleSubmit = async (data: any, csrfToken: string) => {
    const response = await fetch('/api/user/profile', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': csrfToken
      },
      credentials: 'include',
      body: JSON.stringify(data)
    });

    if (!response.ok) {
      throw new Error('Profile update failed');
    }

    console.log('Profile updated successfully');
  };

  return (
    <ProtectedForm onSubmit={handleSubmit} className="profile-form">
      <input name="name" placeholder="Full Name" required />
      <input name="email" type="email" placeholder="Email" required />
      <textarea name="bio" placeholder="Bio"></textarea>
    </ProtectedForm>
  );
};
```

### 6. Testing CSRF Protection

#### Comprehensive CSRF Testing Suite

```typescript
// tests/csrf-protection.test.ts
import request from 'supertest';
import { app } from '../src/app';
import { CSRFTokenManager } from '../src/utils/csrfTokenManager';

describe('CSRF Protection', () => {
  let agent: request.SuperAgentTest;
  let csrfToken: string;

  beforeEach(async () => {
    agent = request.agent(app);
    
    // Get CSRF token
    const response = await agent.get('/api/csrf-token');
    csrfToken = response.body.csrfToken;
  });

  describe('Token Generation and Validation', () => {
    it('should generate valid CSRF tokens', () => {
      const secret = CSRFTokenManager.generateSecret();
      const token = CSRFTokenManager.generateToken(secret);
      const isValid = CSRFTokenManager.validateToken(secret, token);
      
      expect(isValid).toBe(true);
    });

    it('should reject invalid tokens', () => {
      const secret = CSRFTokenManager.generateSecret();
      const invalidToken = 'invalid-token';
      const isValid = CSRFTokenManager.validateToken(secret, invalidToken);
      
      expect(isValid).toBe(false);
    });

    it('should reject expired tokens', () => {
      const secret = CSRFTokenManager.generateSecret();
      const expiredToken = '1000000000000:randomBytes:signature'; // Old timestamp
      const isValid = CSRFTokenManager.validateToken(secret, expiredToken);
      
      expect(isValid).toBe(false);
    });
  });

  describe('HTTP Request Protection', () => {
    it('should allow GET requests without CSRF token', async () => {
      const response = await agent.get('/api/user/profile');
      expect(response.status).not.toBe(403);
    });

    it('should reject POST requests without CSRF token', async () => {
      const response = await agent
        .post('/api/user/profile')
        .send({ name: 'Test User' });
      
      expect(response.status).toBe(403);
      expect(response.body.code).toBe('CSRF_TOKEN_MISSING');
    });

    it('should accept POST requests with valid CSRF token', async () => {
      const response = await agent
        .post('/api/user/profile')
        .set('X-CSRF-Token', csrfToken)
        .send({ name: 'Test User' });
      
      expect(response.status).not.toBe(403);
    });

    it('should reject POST requests with invalid CSRF token', async () => {
      const response = await agent
        .post('/api/user/profile')
        .set('X-CSRF-Token', 'invalid-token')
        .send({ name: 'Test User' });
      
      expect(response.status).toBe(403);
      expect(response.body.code).toBe('CSRF_TOKEN_INVALID');
    });
  });

  describe('CSRF Attack Simulation', () => {
    it('should prevent cross-origin form submissions', async () => {
      // Simulate malicious cross-origin request
      const response = await request(app)
        .post('/api/user/delete')
        .set('Origin', 'https://evil.com')
        .set('Referer', 'https://evil.com/malicious-page')
        .send({});
      
      expect(response.status).toBe(403);
    });

    it('should prevent CSRF via image tags', async () => {
      // Simulate GET request with state change (bad design)
      const response = await request(app)
        .get('/api/user/delete?confirm=true')
        .set('Referer', 'https://evil.com');
      
      expect(response.status).toBe(403);
    });
  });

  describe('Double Submit Cookie Pattern', () => {
    it('should set CSRF cookie and validate matching header', async () => {
      const response = await agent.get('/api/csrf-token');
      const cookieHeader = response.headers['set-cookie'];
      
      expect(cookieHeader).toBeDefined();
      expect(cookieHeader[0]).toContain('csrf-token=');
      
      // Extract token from cookie
      const tokenMatch = cookieHeader[0].match(/csrf-token=([^;]+)/);
      const cookieToken = tokenMatch ? tokenMatch[1] : null;
      
      expect(cookieToken).toBe(response.body.csrfToken);
    });
  });
});

// Integration test for React components
describe('React CSRF Integration', () => {
  it('should handle CSRF token in protected forms', async () => {
    // Mock CSRF service
    const mockToken = 'mock-csrf-token';
    jest.spyOn(CSRFService.prototype, 'getToken').mockResolvedValue(mockToken);
    
    // Test protected form submission
    const formData = { name: 'Test User', email: 'test@example.com' };
    
    const mockFetch = jest.fn().mockResolvedValue({
      ok: true,
      json: () => Promise.resolve({ success: true })
    });
    
    global.fetch = mockFetch;
    
    // Simulate form submission with CSRF token
    await fetch('/api/user/profile', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': mockToken
      },
      body: JSON.stringify(formData)
    });
    
    expect(mockFetch).toHaveBeenCalledWith('/api/user/profile', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': mockToken
      },
      body: JSON.stringify(formData)
    });
  });
});
```

## CSRF Protection Checklist

### Implementation Checklist
- [ ] **Token Generation**: Cryptographically secure CSRF token generation
- [ ] **Token Validation**: Server-side token validation for all state-changing requests
- [ ] **SameSite Cookies**: Strict SameSite cookie configuration
- [ ] **Origin Validation**: Origin and Referer header validation
- [ ] **Custom Headers**: Custom header requirement for AJAX requests
- [ ] **Token Rotation**: Regular token rotation and expiration
- [ ] **Error Handling**: Proper error responses for CSRF failures

### Security Verification
- [ ] **Cross-Origin Testing**: Verify protection against cross-origin attacks
- [ ] **Token Replay**: Ensure tokens cannot be reused maliciously
- [ ] **Token Leakage**: Verify tokens are not exposed in logs or URLs
- [ ] **Session Security**: Secure session configuration
- [ ] **HTTPS Enforcement**: HTTPS-only cookies in production
- [ ] **Penetration Testing**: Manual CSRF attack testing
- [ ] **Automated Testing**: Comprehensive test suite coverage

### Frontend Integration
- [ ] **Automatic Token Handling**: Seamless token inclusion in requests
- [ ] **Token Refresh**: Automatic token refresh before expiration
- [ ] **Error Recovery**: Graceful handling of CSRF errors
- [ ] **Form Protection**: All forms protected with CSRF tokens
- [ ] **AJAX Protection**: All AJAX requests include CSRF protection
- [ ] **File Upload**: CSRF protection for file upload endpoints
- [ ] **API Integration**: CSRF protection for API endpoints

## Additional Resources

### Official Documentation
- [OWASP CSRF Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html)
- [MDN SameSite Cookie Documentation](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Set-Cookie/SameSite)
- [RFC 6265 - HTTP State Management Mechanism](https://tools.ietf.org/html/rfc6265)

### Security Tools
- [OWASP ZAP CSRF Testing](https://www.zaproxy.org/docs/desktop/addons/csrf/)
- [Burp Suite CSRF Detection](https://portswigger.net/burp/documentation/desktop/tools/scanner/scan-launcher/scan-types/crawl-and-audit/csrf)

### Educational Resources
- [OWASP WebGoat CSRF Lessons](https://webgoat.github.io/WebGoat/)
- [PortSwigger CSRF Labs](https://portswigger.net/web-security/csrf)

---

## Navigation

- ← Back to: [Frontend Security Best Practices](./README.md)
- → Next: [Content Security Policy Guide](./content-security-policy-guide.md)
- → Previous: [XSS Prevention Strategies](./xss-prevention-strategies.md)
- → Implementation: [Implementation Guide](./implementation-guide.md)