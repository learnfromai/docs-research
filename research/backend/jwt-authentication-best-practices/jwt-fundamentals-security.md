# JWT Fundamentals and Security

## 🔒 JSON Web Token Overview

JSON Web Tokens (JWTs) are compact, URL-safe tokens used for securely transmitting information between parties. A JWT consists of three parts separated by dots: Header.Payload.Signature.

### JWT Structure Breakdown

```
eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiYWRtaW4iOnRydWV9.signature
│─────────── Header ────────────│────────────── Payload ──────────────│signature│
```

### 1. Header Component
```json
{
  "alg": "RS256",    // Signing algorithm
  "typ": "JWT",      // Token type
  "kid": "key-id"    // Key identifier (optional)
}
```

### 2. Payload Component
```json
{
  "iss": "issuer",           // Issuer (who created the token)
  "sub": "subject",          // Subject (who the token refers to)
  "aud": "audience",         // Audience (who can use the token)
  "exp": 1735689600,         // Expiration time (Unix timestamp)
  "nbf": 1735603200,         // Not before time
  "iat": 1735603200,         // Issued at time
  "jti": "unique-id",        // JWT ID (unique identifier)
  
  // Custom claims
  "userId": "12345",
  "email": "user@example.com",
  "roles": ["user", "admin"],
  "permissions": ["read", "write"]
}
```

### 3. Signature Component
The signature ensures token integrity and authenticity:

```typescript
// RS256 Signature Creation (Asymmetric)
const signature = sign(
  base64UrlEncode(header) + "." + base64UrlEncode(payload),
  privateKey,
  "RS256"
);
```

## 🛡️ Security Considerations

### Critical JWT Security Rules

#### 1. Algorithm Confusion Attacks
```typescript
// ❌ VULNERABLE: Accepts any algorithm
jwt.verify(token, secret);

// ✅ SECURE: Explicitly specify algorithm
jwt.verify(token, publicKey, { algorithms: ['RS256'] });
```

#### 2. None Algorithm Attack Prevention
```typescript
// ❌ NEVER allow 'none' algorithm
const decoded = jwt.verify(token, '', { algorithms: ['none'] });

// ✅ Always specify strong algorithms
const ALLOWED_ALGORITHMS = ['RS256', 'ES256'] as const;
const decoded = jwt.verify(token, publicKey, { 
  algorithms: ALLOWED_ALGORITHMS 
});
```

#### 3. Secret Management
```typescript
// ❌ Hard-coded secrets
const JWT_SECRET = 'my-secret-key';

// ✅ Environment-based secrets with validation
const JWT_PRIVATE_KEY = process.env.JWT_PRIVATE_KEY?.replace(/\\n/g, '\n');
if (!JWT_PRIVATE_KEY) {
  throw new Error('JWT_PRIVATE_KEY environment variable is required');
}

// ✅ Key rotation support
const getSigningKey = (keyId?: string): string => {
  const keyMap = new Map([
    ['current', process.env.JWT_PRIVATE_KEY_CURRENT],
    ['previous', process.env.JWT_PRIVATE_KEY_PREVIOUS]
  ]);
  
  return keyMap.get(keyId || 'current') || JWT_PRIVATE_KEY;
};
```

## 🔐 Signing Algorithms Comparison

### Algorithm Security Analysis

| Algorithm | Type | Security Level | Key Management | Performance | Use Case |
|-----------|------|---------------|----------------|-------------|----------|
| **RS256** | Asymmetric | 🟢 High | 🟢 Excellent | 🟡 Moderate | **Production APIs** |
| **RS384** | Asymmetric | 🟢 High | 🟢 Excellent | 🟡 Moderate | High-security systems |
| **RS512** | Asymmetric | 🟢 High | 🟢 Excellent | 🟡 Moderate | Maximum security |
| **HS256** | Symmetric | 🟡 Medium | 🔴 Challenging | 🟢 Fast | Development only |
| **HS384** | Symmetric | 🟡 Medium | 🔴 Challenging | 🟢 Fast | Development only |
| **HS512** | Symmetric | 🟡 Medium | 🔴 Challenging | 🟢 Fast | Development only |
| **ES256** | Asymmetric | 🟢 High | 🟡 Moderate | 🟢 Fast | Modern systems |
| **PS256** | Asymmetric | 🟢 High | 🟢 Excellent | 🟡 Moderate | FIPS compliance |

### RS256 Implementation (Recommended)

```typescript
import { generateKeyPairSync, sign, verify } from 'crypto';
import jwt from 'jsonwebtoken';

// Generate RSA key pair (do this once, store securely)
const { publicKey, privateKey } = generateKeyPairSync('rsa', {
  modulusLength: 2048,
  publicKeyEncoding: {
    type: 'spki',
    format: 'pem'
  },
  privateKeyEncoding: {
    type: 'pkcs8',
    format: 'pem'
  }
});

// Token signing (server-side only)
const signToken = (payload: object): string => {
  return jwt.sign(payload, privateKey, {
    algorithm: 'RS256',
    expiresIn: '15m',
    issuer: 'your-api.com',
    audience: 'your-client-app'
  });
};

// Token verification (can be distributed)
const verifyToken = (token: string): jwt.JwtPayload => {
  return jwt.verify(token, publicKey, {
    algorithms: ['RS256'],
    issuer: 'your-api.com',
    audience: 'your-client-app'
  }) as jwt.JwtPayload;
};
```

## 🎯 JWT Claims Best Practices

### Standard Claims (RFC 7519)

```typescript
interface StandardJWTClaims {
  iss: string;      // Issuer - who issued the token
  sub: string;      // Subject - user/entity identifier
  aud: string;      // Audience - intended recipients
  exp: number;      // Expiration - Unix timestamp
  nbf?: number;     // Not before - token valid from
  iat: number;      // Issued at - creation timestamp
  jti?: string;     // JWT ID - unique token identifier
}
```

### Custom Claims Implementation

```typescript
interface CustomJWTClaims extends StandardJWTClaims {
  // User identification
  userId: string;
  email: string;
  username?: string;
  
  // Authorization
  roles: string[];
  permissions: string[];
  scope: string[];
  
  // Session management
  sessionId: string;
  deviceId?: string;
  
  // Security context
  authMethod: 'password' | 'oauth' | 'mfa';
  securityLevel: 'basic' | 'elevated';
  ipAddress?: string;
}

const createSecureToken = (user: User, session: Session): string => {
  const now = Math.floor(Date.now() / 1000);
  
  const payload: CustomJWTClaims = {
    // Standard claims
    iss: 'https://api.yourapp.com',
    sub: user.id,
    aud: 'yourapp-clients',
    exp: now + (15 * 60), // 15 minutes
    iat: now,
    jti: generateUniqueId(),
    
    // Custom claims
    userId: user.id,
    email: user.email,
    roles: user.roles,
    permissions: user.permissions,
    scope: user.scope,
    sessionId: session.id,
    authMethod: session.authMethod,
    securityLevel: session.securityLevel
  };
  
  return signToken(payload);
};
```

## ⚠️ Common JWT Vulnerabilities

### 1. Token Storage Vulnerabilities

```typescript
// ❌ CRITICAL: Never store JWTs in localStorage
localStorage.setItem('jwt', token);     // Vulnerable to XSS
sessionStorage.setItem('jwt', token);   // Vulnerable to XSS

// ❌ RISKY: Insecure cookie storage
res.cookie('jwt', token, {
  secure: false,        // Transmitted over HTTP
  httpOnly: false,      // Accessible via JavaScript
  sameSite: 'none'      // CSRF vulnerable
});

// ✅ SECURE: Proper cookie storage
res.cookie('accessToken', token, {
  httpOnly: true,                                    // XSS protection
  secure: process.env.NODE_ENV === 'production',    // HTTPS only
  sameSite: 'strict',                               // CSRF protection
  maxAge: 15 * 60 * 1000,                          // 15 minutes
  path: '/api'                                      // Scope limitation
});
```

### 2. Token Validation Vulnerabilities

```typescript
// ❌ Insufficient validation
const payload = jwt.decode(token); // No signature verification!

// ❌ Algorithm confusion
jwt.verify(token, secret); // Accepts any algorithm

// ❌ Missing expiration check
jwt.verify(token, publicKey, { ignoreExpiration: true });

// ✅ Comprehensive validation
const verifyTokenSecurely = (token: string): CustomJWTClaims => {
  try {
    const payload = jwt.verify(token, publicKey, {
      algorithms: ['RS256'],              // Explicit algorithm
      issuer: 'https://api.yourapp.com',  // Verify issuer
      audience: 'yourapp-clients',        // Verify audience
      clockTolerance: 30,                 // Allow 30s clock skew
      ignoreExpiration: false,            // Check expiration
      ignoreNotBefore: false              // Check nbf claim
    }) as CustomJWTClaims;
    
    // Additional custom validation
    if (!payload.userId || !payload.sessionId) {
      throw new Error('Invalid token claims');
    }
    
    // Check token blacklist
    if (await isTokenRevoked(payload.jti)) {
      throw new Error('Token has been revoked');
    }
    
    return payload;
  } catch (error) {
    throw new Error('Token validation failed');
  }
};
```

### 3. Information Disclosure

```typescript
// ❌ Sensitive data in payload (always visible!)
const payload = {
  userId: '123',
  password: 'secret123',      // NEVER!
  ssn: '123-45-6789',        // NEVER!
  creditCard: '4111...'      // NEVER!
};

// ✅ Only include necessary, non-sensitive data
const payload = {
  sub: '123',
  email: 'user@example.com',
  roles: ['user'],
  permissions: ['read'],
  sessionId: 'sess_abc123'
};
```

## 🔄 Token Lifecycle Management

### 1. Token Generation Flow

```typescript
class JWTService {
  private readonly ACCESS_TOKEN_TTL = 15 * 60;        // 15 minutes
  private readonly REFRESH_TOKEN_TTL = 7 * 24 * 60 * 60; // 7 days
  
  async generateTokenPair(user: User, session: Session): Promise<TokenPair> {
    const now = Math.floor(Date.now() / 1000);
    
    // Access token - short-lived, contains user context
    const accessToken = jwt.sign({
      iss: this.config.issuer,
      sub: user.id,
      aud: this.config.audience,
      exp: now + this.ACCESS_TOKEN_TTL,
      iat: now,
      jti: generateUniqueId(),
      
      userId: user.id,
      email: user.email,
      roles: user.roles,
      sessionId: session.id
    }, this.privateKey, { algorithm: 'RS256' });
    
    // Refresh token - long-lived, minimal payload
    const refreshToken = jwt.sign({
      iss: this.config.issuer,
      sub: user.id,
      aud: this.config.refreshAudience,
      exp: now + this.REFRESH_TOKEN_TTL,
      iat: now,
      jti: generateUniqueId(),
      
      sessionId: session.id,
      tokenType: 'refresh'
    }, this.privateKey, { algorithm: 'RS256' });
    
    // Store refresh token hash in database
    await this.storeRefreshToken(user.id, session.id, refreshToken);
    
    return { accessToken, refreshToken };
  }
}
```

### 2. Token Verification Middleware

```typescript
interface AuthenticatedRequest extends Request {
  user?: CustomJWTClaims;
  sessionId?: string;
}

export const authenticateToken = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    // Extract token from cookies (preferred) or Authorization header
    const token = req.cookies?.accessToken || 
                  req.headers.authorization?.replace('Bearer ', '');
    
    if (!token) {
      return res.status(401).json({ 
        error: 'Access token required',
        code: 'TOKEN_MISSING'
      });
    }
    
    // Verify token with caching for performance
    const payload = await verifyTokenWithCache(token);
    
    // Additional security checks
    await performSecurityChecks(req, payload);
    
    // Attach user context to request
    req.user = payload;
    req.sessionId = payload.sessionId;
    
    next();
  } catch (error) {
    // Log security events
    logger.warn('Authentication failed', {
      ip: req.ip,
      userAgent: req.get('User-Agent'),
      error: error.message
    });
    
    return res.status(401).json({ 
      error: 'Authentication failed',
      code: 'TOKEN_INVALID'
    });
  }
};

const performSecurityChecks = async (
  req: Request, 
  payload: CustomJWTClaims
): Promise<void> => {
  // Check if session is still valid
  const session = await getSession(payload.sessionId);
  if (!session || !session.active) {
    throw new Error('Session expired or invalid');
  }
  
  // IP address validation (optional, configure per use case)
  if (session.enforceIPBinding && session.ipAddress !== req.ip) {
    throw new Error('IP address mismatch');
  }
  
  // Device fingerprinting (if implemented)
  if (session.deviceId && req.headers['x-device-id'] !== session.deviceId) {
    throw new Error('Device mismatch detected');
  }
  
  // Rate limiting check
  await checkRateLimit(payload.userId, req.ip);
};
```

### 3. Token Caching for Performance

```typescript
import NodeCache from 'node-cache';

class TokenVerificationCache {
  private cache = new NodeCache({ 
    stdTTL: 300,        // 5 minutes default TTL
    checkperiod: 60,    // Check for expired keys every minute
    maxKeys: 10000      // Maximum number of cached tokens
  });
  
  async verifyWithCache(token: string): Promise<CustomJWTClaims> {
    // Create cache key from token hash (don't store full token)
    const tokenHash = createHash('sha256').update(token).digest('hex');
    
    // Check cache first
    const cached = this.cache.get<CustomJWTClaims>(tokenHash);
    if (cached) {
      // Verify expiration hasn't passed since caching
      if (cached.exp > Math.floor(Date.now() / 1000)) {
        return cached;
      }
      this.cache.del(tokenHash);
    }
    
    // Verify token and cache result
    const payload = verifyTokenSecurely(token);
    
    // Calculate appropriate TTL (don't cache longer than token lifetime)
    const now = Math.floor(Date.now() / 1000);
    const ttl = Math.min(payload.exp - now, 300); // Max 5 minutes
    
    if (ttl > 0) {
      this.cache.set(tokenHash, payload, ttl);
    }
    
    return payload;
  }
  
  invalidateToken(token: string): void {
    const tokenHash = createHash('sha256').update(token).digest('hex');
    this.cache.del(tokenHash);
  }
}
```

## 📊 Security Metrics and Monitoring

### Essential JWT Security Metrics

```typescript
class JWTSecurityMonitor {
  private metrics = {
    tokenValidationFailures: 0,
    suspiciousTokenActivity: 0,
    algorithmConfusionAttempts: 0,
    expiredTokenUseAttempts: 0,
    invalidIssuerAttempts: 0
  };
  
  recordTokenValidationFailure(reason: string, context: any): void {
    this.metrics.tokenValidationFailures++;
    
    logger.warn('JWT validation failure', {
      reason,
      timestamp: new Date().toISOString(),
      ip: context.ip,
      userAgent: context.userAgent,
      tokenPreview: context.token?.substring(0, 20) + '...'
    });
    
    // Alert on suspicious patterns
    if (this.detectSuspiciousActivity(reason, context)) {
      this.alertSecurityTeam('Suspicious JWT activity detected', context);
    }
  }
  
  private detectSuspiciousActivity(reason: string, context: any): boolean {
    // Multiple failed attempts from same IP
    const recentFailures = this.getRecentFailures(context.ip);
    if (recentFailures > 10) return true;
    
    // Algorithm confusion attempts
    if (reason.includes('algorithm')) {
      this.metrics.algorithmConfusionAttempts++;
      return true;
    }
    
    // Expired token reuse attempts
    if (reason.includes('expired') && this.isRepeatedExpiredToken(context.token)) {
      this.metrics.expiredTokenUseAttempts++;
      return true;
    }
    
    return false;
  }
}
```

## 📚 References and Further Reading

### Security Standards and Guidelines
- **[OWASP JWT Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/JSON_Web_Token_for_Java_Cheat_Sheet.html)** - Comprehensive security guidelines
- **[RFC 7519 - JSON Web Token](https://tools.ietf.org/html/rfc7519)** - Official JWT specification
- **[RFC 7515 - JSON Web Signature](https://tools.ietf.org/html/rfc7515)** - JWS specification
- **[RFC 7516 - JSON Web Encryption](https://tools.ietf.org/html/rfc7516)** - JWE specification

### Security Research and Vulnerabilities
- **[Auth0: Critical Vulnerabilities in JSON Web Token Libraries](https://auth0.com/blog/critical-vulnerabilities-in-json-web-token-libraries/)** (2015)
- **[JWT Best Practices](https://datatracker.ietf.org/doc/html/draft-ietf-oauth-jwt-bcp)** - IETF Draft
- **[Common JWT Implementation Mistakes](https://research.securitum.com/jwt-json-web-token-security/)** - Security research

### Implementation Resources
- **[jsonwebtoken NPM Package](https://www.npmjs.com/package/jsonwebtoken)** - Most popular Node.js JWT library
- **[node-jose](https://github.com/cisco/node-jose)** - JSON Object Signing and Encryption library
- **[TypeScript JWT Types](https://www.npmjs.com/package/@types/jsonwebtoken)** - TypeScript definitions

---

**Navigation**
- ← Back to: [Executive Summary](./executive-summary.md)
- → Next: [Express.js Implementation Guide](./expressjs-implementation-guide.md)
- ↑ Back to: [JWT Authentication Research](./README.md)