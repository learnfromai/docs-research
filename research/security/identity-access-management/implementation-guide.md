# Implementation Guide: Identity & Access Management

> **Step-by-step guide for implementing OAuth2, SAML, and MFA in EdTech platforms**

## 🏁 Prerequisites & Environment Setup

### **Development Environment**

```bash
# Required Tools
node -v    # v18+ required
npm -v     # v8+ required
docker -v  # v20+ required
git --version

# Optional but recommended
kubectl version  # For Kubernetes deployment
terraform --version  # For infrastructure as code
```

### **Initial Project Structure**

```
edtech-iam/
├── auth-service/           # OAuth2/SAML service
├── user-service/          # User management
├── mfa-service/           # Multi-factor authentication
├── api-gateway/           # Routing and rate limiting
├── infrastructure/        # Terraform/Docker configs
├── tests/                # Integration and security tests
└── docs/                 # Documentation
```

## 🚀 Phase 1: OAuth2 Implementation

### **Step 1: OAuth2 Provider Setup**

#### Option A: Auth0 Implementation

```bash
# Install Auth0 SDK
npm install @auth0/auth0-react @auth0/nextjs-auth0

# Environment Configuration
echo "AUTH0_SECRET='$(openssl rand -hex 32)'" >> .env.local
echo "AUTH0_BASE_URL=http://localhost:3000" >> .env.local
echo "AUTH0_ISSUER_BASE_URL=https://your-domain.auth0.com" >> .env.local
echo "AUTH0_CLIENT_ID=your-client-id" >> .env.local
echo "AUTH0_CLIENT_SECRET=your-client-secret" >> .env.local
```

**Auth0 Dashboard Configuration:**

```javascript
// auth0-config.js
export const auth0Config = {
  domain: process.env.AUTH0_ISSUER_BASE_URL,
  clientId: process.env.AUTH0_CLIENT_ID,
  redirectUri: `${process.env.AUTH0_BASE_URL}/api/auth/callback`,
  scope: 'openid profile email read:user_metadata',
  audience: 'https://your-api.example.com'
};
```

#### Option B: Keycloak Self-Hosted

```yaml
# docker-compose.yml
version: '3.8'
services:
  keycloak:
    image: quay.io/keycloak/keycloak:22.0
    environment:
      KEYCLOAK_ADMIN: admin
      KEYCLOAK_ADMIN_PASSWORD: admin
      KC_DB: postgres
      KC_DB_URL: jdbc:postgresql://postgres:5432/keycloak
      KC_DB_USERNAME: keycloak
      KC_DB_PASSWORD: password
    ports:
      - "8080:8080"
    command: start-dev
    depends_on:
      - postgres

  postgres:
    image: postgres:15
    environment:
      POSTGRES_DB: keycloak
      POSTGRES_USER: keycloak
      POSTGRES_PASSWORD: password
    volumes:
      - keycloak_data:/var/lib/postgresql/data

volumes:
  keycloak_data:
```

### **Step 2: OAuth2 Client Implementation**

```typescript
// lib/oauth2-client.ts
import { AuthorizationCode } from 'simple-oauth2';

export class OAuth2Client {
  private client: AuthorizationCode;

  constructor() {
    this.client = new AuthorizationCode({
      client: {
        id: process.env.OAUTH2_CLIENT_ID!,
        secret: process.env.OAUTH2_CLIENT_SECRET!,
      },
      auth: {
        tokenHost: process.env.OAUTH2_TOKEN_HOST!,
        tokenPath: '/oauth2/token',
        authorizePath: '/oauth2/auth',
      },
    });
  }

  getAuthorizationUrl(state: string, scopes: string[] = ['read', 'write']) {
    return this.client.authorizeURL({
      redirect_uri: process.env.OAUTH2_REDIRECT_URI!,
      scope: scopes.join(' '),
      state,
    });
  }

  async getAccessToken(code: string) {
    const tokenParams = {
      code,
      redirect_uri: process.env.OAUTH2_REDIRECT_URI!,
    };

    try {
      const accessToken = await this.client.getToken(tokenParams);
      return accessToken.token;
    } catch (error) {
      console.error('Access Token Error', error.message);
      throw error;
    }
  }
}
```

### **Step 3: JWT Token Management**

```typescript
// lib/jwt-service.ts
import jwt from 'jsonwebtoken';
import { Redis } from 'ioredis';

export class JWTService {
  private redis: Redis;
  private accessTokenSecret: string;
  private refreshTokenSecret: string;

  constructor() {
    this.redis = new Redis(process.env.REDIS_URL);
    this.accessTokenSecret = process.env.JWT_ACCESS_SECRET!;
    this.refreshTokenSecret = process.env.JWT_REFRESH_SECRET!;
  }

  generateTokens(userId: string, roles: string[]) {
    const payload = { userId, roles };
    
    const accessToken = jwt.sign(payload, this.accessTokenSecret, {
      expiresIn: '15m',
      issuer: 'edtech-platform',
      audience: 'api-access',
    });

    const refreshToken = jwt.sign(payload, this.refreshTokenSecret, {
      expiresIn: '30d',
      issuer: 'edtech-platform',
      audience: 'token-refresh',
    });

    // Store refresh token in Redis
    this.redis.setex(`refresh:${userId}`, 30 * 24 * 60 * 60, refreshToken);

    return { accessToken, refreshToken };
  }

  async verifyAccessToken(token: string) {
    try {
      const decoded = jwt.verify(token, this.accessTokenSecret) as any;
      return decoded;
    } catch (error) {
      throw new Error('Invalid access token');
    }
  }

  async refreshAccessToken(refreshToken: string) {
    try {
      const decoded = jwt.verify(refreshToken, this.refreshTokenSecret) as any;
      
      // Check if refresh token exists in Redis
      const storedToken = await this.redis.get(`refresh:${decoded.userId}`);
      if (storedToken !== refreshToken) {
        throw new Error('Invalid refresh token');
      }

      return this.generateTokens(decoded.userId, decoded.roles);
    } catch (error) {
      throw new Error('Invalid refresh token');
    }
  }
}
```

## 🏢 Phase 2: SAML SSO Implementation

### **Step 1: SAML Identity Provider Setup**

```typescript
// lib/saml-provider.ts
import * as saml from 'samlify';

export class SAMLProvider {
  private idp: any;
  private sp: any;

  constructor() {
    this.idp = saml.IdentityProvider({
      metadata: this.getIdPMetadata(),
      privateKey: process.env.SAML_PRIVATE_KEY!,
      privateKeyPass: process.env.SAML_PRIVATE_KEY_PASS,
      isAssertionEncrypted: true,
    });

    this.sp = saml.ServiceProvider({
      metadata: this.getSPMetadata(),
      privateKey: process.env.SAML_SP_PRIVATE_KEY!,
    });
  }

  private getIdPMetadata() {
    return `<?xml version="1.0"?>
<EntityDescriptor entityID="https://your-edtech-platform.com/saml/metadata"
                  xmlns="urn:oasis:names:tc:SAML:2.0:metadata">
  <IDPSSODescriptor protocolSupportEnumeration="urn:oasis:names:tc:SAML:2.0:protocol">
    <KeyDescriptor use="signing">
      <KeyInfo xmlns="http://www.w3.org/2000/09/xmldsig#">
        <X509Data>
          <X509Certificate>${process.env.SAML_CERT}</X509Certificate>
        </X509Data>
      </KeyInfo>
    </KeyDescriptor>
    <SingleSignOnService Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect"
                         Location="https://your-edtech-platform.com/saml/sso"/>
  </IDPSSODescriptor>
</EntityDescriptor>`;
  }

  private getSPMetadata() {
    return `<?xml version="1.0"?>
<EntityDescriptor entityID="https://client-school-district.edu/saml/metadata"
                  xmlns="urn:oasis:names:tc:SAML:2.0:metadata">
  <SPSSODescriptor protocolSupportEnumeration="urn:oasis:names:tc:SAML:2.0:protocol">
    <AssertionConsumerService Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST"
                              Location="https://client-school-district.edu/saml/acs"
                              index="1"/>
  </SPSSODescriptor>
</EntityDescriptor>`;
  }

  async createSSOUrl(spEntityId: string, relayState?: string) {
    const { id, context } = this.idp.createLoginRequest(
      this.sp,
      'redirect',
      relayState ? { relayState } : undefined
    );
    return context;
  }

  async handleSSOResponse(samlResponse: string) {
    try {
      const { extract } = await this.sp.parseLoginResponse(this.idp, 'post', {
        body: { SAMLResponse: samlResponse }
      });
      
      return {
        nameId: extract.nameId,
        attributes: extract.attributes,
        sessionIndex: extract.sessionIndex,
      };
    } catch (error) {
      throw new Error('SAML response validation failed');
    }
  }
}
```

### **Step 2: SAML Integration with Express.js**

```typescript
// routes/saml.ts
import express from 'express';
import { SAMLProvider } from '../lib/saml-provider';

const router = express.Router();
const samlProvider = new SAMLProvider();

// SSO Initiation
router.get('/sso/:institutionId', async (req, res) => {
  try {
    const { institutionId } = req.params;
    const relayState = req.query.RelayState as string;
    
    const ssoUrl = await samlProvider.createSSOUrl(institutionId, relayState);
    res.redirect(ssoUrl);
  } catch (error) {
    res.status(500).json({ error: 'SSO initiation failed' });
  }
});

// SSO Callback
router.post('/acs', async (req, res) => {
  try {
    const { SAMLResponse } = req.body;
    const userInfo = await samlProvider.handleSSOResponse(SAMLResponse);
    
    // Create or update user in your system
    const user = await createOrUpdateUser(userInfo);
    
    // Generate JWT tokens
    const jwtService = new JWTService();
    const tokens = jwtService.generateTokens(user.id, user.roles);
    
    // Set secure cookies
    res.cookie('accessToken', tokens.accessToken, {
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'strict',
      maxAge: 15 * 60 * 1000, // 15 minutes
    });
    
    res.redirect('/dashboard');
  } catch (error) {
    res.status(400).json({ error: 'SAML authentication failed' });
  }
});

export default router;
```

## 🔐 Phase 3: Multi-Factor Authentication

### **Step 1: TOTP Implementation**

```typescript
// lib/mfa-service.ts
import * as speakeasy from 'speakeasy';
import * as qrcode from 'qrcode';

export class MFAService {
  private redis: Redis;

  constructor() {
    this.redis = new Redis(process.env.REDIS_URL);
  }

  async generateTOTPSecret(userId: string) {
    const secret = speakeasy.generateSecret({
      name: `EdTech Platform (${userId})`,
      issuer: 'EdTech Platform',
      length: 32,
    });

    // Store secret temporarily (expires in 10 minutes)
    await this.redis.setex(`totp:setup:${userId}`, 600, secret.base32);

    const qrCodeUrl = await qrcode.toDataURL(secret.otpauth_url!);
    
    return {
      secret: secret.base32,
      qrCode: qrCodeUrl,
      manualEntryKey: secret.base32,
    };
  }

  async verifyTOTPSetup(userId: string, token: string) {
    const secret = await this.redis.get(`totp:setup:${userId}`);
    if (!secret) {
      throw new Error('Setup session expired');
    }

    const verified = speakeasy.totp.verify({
      secret,
      encoding: 'base32',
      token,
      window: 2,
    });

    if (verified) {
      // Move to permanent storage
      await this.redis.set(`totp:secret:${userId}`, secret);
      await this.redis.del(`totp:setup:${userId}`);
      return true;
    }

    return false;
  }

  async verifyTOTP(userId: string, token: string) {
    const secret = await this.redis.get(`totp:secret:${userId}`);
    if (!secret) {
      throw new Error('TOTP not configured');
    }

    // Check if token was recently used (prevent replay attacks)
    const recentUse = await this.redis.get(`totp:used:${userId}:${token}`);
    if (recentUse) {
      throw new Error('Token already used');
    }

    const verified = speakeasy.totp.verify({
      secret,
      encoding: 'base32',
      token,
      window: 2,
    });

    if (verified) {
      // Mark token as used for 90 seconds
      await this.redis.setex(`totp:used:${userId}:${token}`, 90, '1');
      return true;
    }

    return false;
  }
}
```

### **Step 2: SMS-Based MFA**

```typescript
// lib/sms-mfa.ts
import twilio from 'twilio';

export class SMSMFAService {
  private client: any;
  private redis: Redis;

  constructor() {
    this.client = twilio(
      process.env.TWILIO_ACCOUNT_SID,
      process.env.TWILIO_AUTH_TOKEN
    );
    this.redis = new Redis(process.env.REDIS_URL);
  }

  async sendSMSCode(userId: string, phoneNumber: string) {
    const code = Math.floor(100000 + Math.random() * 900000).toString();
    
    try {
      await this.client.messages.create({
        body: `Your EdTech Platform verification code is: ${code}`,
        from: process.env.TWILIO_PHONE_NUMBER,
        to: phoneNumber,
      });

      // Store code with 5-minute expiry
      await this.redis.setex(`sms:code:${userId}`, 300, code);
      
      return true;
    } catch (error) {
      console.error('SMS sending failed:', error);
      throw new Error('Failed to send SMS code');
    }
  }

  async verifySMSCode(userId: string, code: string) {
    const storedCode = await this.redis.get(`sms:code:${userId}`);
    
    if (storedCode === code) {
      await this.redis.del(`sms:code:${userId}`);
      return true;
    }
    
    return false;
  }
}
```

### **Step 3: Risk-Based Authentication**

```typescript
// lib/risk-assessment.ts
import geoip from 'geoip-lite';
import UAParser from 'ua-parser-js';

export class RiskAssessmentService {
  private redis: Redis;

  constructor() {
    this.redis = new Redis(process.env.REDIS_URL);
  }

  async assessLoginRisk(userId: string, req: Request): Promise<number> {
    const factors: any = {};
    let riskScore = 0;

    // IP Geolocation
    const ip = req.ip;
    const geo = geoip.lookup(ip);
    factors.location = geo;

    // Device fingerprinting
    const ua = new UAParser(req.headers['user-agent'] as string);
    factors.device = {
      browser: ua.getBrowser(),
      os: ua.getOS(),
      device: ua.getDevice(),
    };

    // Time-based analysis
    const currentHour = new Date().getHours();
    factors.timeOfDay = currentHour;

    // Historical behavior analysis
    const userProfile = await this.getUserProfile(userId);
    
    // Location risk
    if (geo && userProfile.commonLocations) {
      const isKnownLocation = userProfile.commonLocations.some(
        (loc: any) => loc.country === geo.country
      );
      if (!isKnownLocation) riskScore += 30;
    }

    // Device risk
    const deviceFingerprint = this.createDeviceFingerprint(factors.device);
    if (!userProfile.knownDevices?.includes(deviceFingerprint)) {
      riskScore += 25;
    }

    // Time-based risk
    if (currentHour < 6 || currentHour > 22) {
      riskScore += 10;
    }

    // Failed login attempts
    const failedAttempts = await this.getFailedAttempts(userId);
    riskScore += Math.min(failedAttempts * 5, 25);

    return Math.min(riskScore, 100);
  }

  private async getUserProfile(userId: string) {
    const profile = await this.redis.get(`user:profile:${userId}`);
    return profile ? JSON.parse(profile) : {};
  }

  private createDeviceFingerprint(device: any) {
    return Buffer.from(JSON.stringify(device)).toString('base64');
  }

  private async getFailedAttempts(userId: string): Promise<number> {
    const attempts = await this.redis.get(`failed:attempts:${userId}`);
    return attempts ? parseInt(attempts) : 0;
  }
}
```

## 🔒 Phase 4: Security Middleware & API Protection

### **Step 1: Authentication Middleware**

```typescript
// middleware/auth.ts
import { Request, Response, NextFunction } from 'express';
import { JWTService } from '../lib/jwt-service';
import { RiskAssessmentService } from '../lib/risk-assessment';

export interface AuthenticatedRequest extends Request {
  user?: {
    userId: string;
    roles: string[];
    mfaVerified?: boolean;
  };
}

export class AuthMiddleware {
  private jwtService: JWTService;
  private riskService: RiskAssessmentService;

  constructor() {
    this.jwtService = new JWTService();
    this.riskService = new RiskAssessmentService();
  }

  // Basic authentication
  authenticate = async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
    try {
      const token = this.extractToken(req);
      if (!token) {
        return res.status(401).json({ error: 'No token provided' });
      }

      const decoded = await this.jwtService.verifyAccessToken(token);
      req.user = decoded;
      next();
    } catch (error) {
      res.status(401).json({ error: 'Invalid token' });
    }
  };

  // MFA required for sensitive operations
  requireMFA = async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
    if (!req.user?.mfaVerified) {
      return res.status(403).json({ 
        error: 'MFA verification required',
        mfaChallenge: true 
      });
    }
    next();
  };

  // Risk-based authentication
  riskBasedAuth = async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
    try {
      const riskScore = await this.riskService.assessLoginRisk(req.user!.userId, req as any);
      
      if (riskScore > 70 && !req.user?.mfaVerified) {
        return res.status(403).json({
          error: 'High-risk login detected',
          mfaRequired: true,
          riskScore
        });
      }
      
      next();
    } catch (error) {
      console.error('Risk assessment failed:', error);
      next(); // Continue on risk assessment failure
    }
  };

  private extractToken(req: Request): string | null {
    const authHeader = req.headers.authorization;
    if (authHeader && authHeader.startsWith('Bearer ')) {
      return authHeader.substring(7);
    }
    
    // Check for cookie-based auth
    const cookieToken = req.cookies?.accessToken;
    if (cookieToken) {
      return cookieToken;
    }
    
    return null;
  }
}
```

### **Step 2: Rate Limiting & API Protection**

```typescript
// middleware/rate-limiting.ts
import rateLimit from 'express-rate-limit';
import { Redis } from 'ioredis';

const redis = new Redis(process.env.REDIS_URL);

// General API rate limiting
export const generalRateLimit = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // Limit each IP to 100 requests per windowMs
  message: 'Too many requests from this IP',
  standardHeaders: true,
  legacyHeaders: false,
  store: {
    async increment(key: string) {
      const current = await redis.incr(key);
      if (current === 1) {
        await redis.expire(key, 15 * 60); // 15 minutes
      }
      return { totalCount: current, resetTime: new Date(Date.now() + 15 * 60 * 1000) };
    },
    async decrement(key: string) {
      await redis.decr(key);
    },
    async resetKey(key: string) {
      await redis.del(key);
    },
  },
});

// Strict rate limiting for authentication endpoints
export const authRateLimit = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 5, // Limit each IP to 5 auth requests per windowMs
  message: 'Too many authentication attempts',
  skipSuccessfulRequests: true,
});

// MFA verification rate limiting
export const mfaRateLimit = rateLimit({
  windowMs: 5 * 60 * 1000, // 5 minutes
  max: 3, // Limit to 3 MFA attempts per 5 minutes
  message: 'Too many MFA verification attempts',
});
```

## 🧪 Phase 5: Testing Implementation

### **Step 1: Unit Tests**

```typescript
// tests/jwt-service.test.ts
import { JWTService } from '../lib/jwt-service';
import Redis from 'ioredis-mock';

describe('JWTService', () => {
  let jwtService: JWTService;
  
  beforeEach(() => {
    // Mock Redis for testing
    jest.clearAllMocks();
    jwtService = new JWTService();
  });

  describe('generateTokens', () => {
    it('should generate valid access and refresh tokens', () => {
      const userId = 'user123';
      const roles = ['student', 'premium'];
      
      const tokens = jwtService.generateTokens(userId, roles);
      
      expect(tokens.accessToken).toBeDefined();
      expect(tokens.refreshToken).toBeDefined();
      expect(typeof tokens.accessToken).toBe('string');
      expect(typeof tokens.refreshToken).toBe('string');
    });
  });

  describe('verifyAccessToken', () => {
    it('should verify valid access token', async () => {
      const userId = 'user123';
      const roles = ['student'];
      const tokens = jwtService.generateTokens(userId, roles);
      
      const decoded = await jwtService.verifyAccessToken(tokens.accessToken);
      
      expect(decoded.userId).toBe(userId);
      expect(decoded.roles).toEqual(roles);
    });

    it('should reject invalid access token', async () => {
      await expect(
        jwtService.verifyAccessToken('invalid-token')
      ).rejects.toThrow('Invalid access token');
    });
  });
});
```

### **Step 2: Integration Tests**

```typescript
// tests/auth-integration.test.ts
import request from 'supertest';
import { app } from '../app';

describe('Authentication Integration', () => {
  describe('POST /api/auth/login', () => {
    it('should login with valid credentials', async () => {
      const response = await request(app)
        .post('/api/auth/login')
        .send({
          email: 'test@example.com',
          password: 'validPassword123',
        })
        .expect(200);

      expect(response.body).toHaveProperty('accessToken');
      expect(response.body).toHaveProperty('user');
      expect(response.body.user.email).toBe('test@example.com');
    });

    it('should require MFA for high-risk login', async () => {
      const response = await request(app)
        .post('/api/auth/login')
        .set('X-Forwarded-For', '1.2.3.4') // Unknown IP
        .set('User-Agent', 'Unknown Browser')
        .send({
          email: 'test@example.com',
          password: 'validPassword123',
        })
        .expect(403);

      expect(response.body).toHaveProperty('mfaRequired', true);
    });
  });

  describe('SAML SSO Flow', () => {
    it('should redirect to IdP for SSO', async () => {
      const response = await request(app)
        .get('/api/saml/sso/school-district-1')
        .expect(302);

      expect(response.headers.location).toContain('SAMLRequest');
    });
  });
});
```

### **Step 3: Security Tests**

```typescript
// tests/security.test.ts
import request from 'supertest';
import { app } from '../app';

describe('Security Tests', () => {
  describe('Rate Limiting', () => {
    it('should rate limit authentication attempts', async () => {
      const loginData = {
        email: 'test@example.com',
        password: 'wrongPassword',
      };

      // Make 6 failed login attempts
      for (let i = 0; i < 6; i++) {
        await request(app)
          .post('/api/auth/login')
          .send(loginData);
      }

      // 6th attempt should be rate limited
      const response = await request(app)
        .post('/api/auth/login')
        .send(loginData)
        .expect(429);

      expect(response.body.error).toContain('Too many');
    });
  });

  describe('Token Security', () => {
    it('should reject expired tokens', async () => {
      // This would require setting up a token with past expiry
      const expiredToken = 'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...'; // Expired token
      
      const response = await request(app)
        .get('/api/protected')
        .set('Authorization', `Bearer ${expiredToken}`)
        .expect(401);

      expect(response.body.error).toBe('Invalid token');
    });
  });

  describe('Input Validation', () => {
    it('should sanitize user input', async () => {
      const maliciousInput = {
        email: '<script>alert("xss")</script>@example.com',
        password: 'password123',
      };

      const response = await request(app)
        .post('/api/auth/register')
        .send(maliciousInput)
        .expect(400);

      expect(response.body.error).toContain('Invalid email format');
    });
  });
});
```

## 🚀 Deployment Configuration

### **Environment Variables**

```bash
# .env.production
NODE_ENV=production

# OAuth2 Configuration
OAUTH2_CLIENT_ID=your-client-id
OAUTH2_CLIENT_SECRET=your-client-secret
OAUTH2_TOKEN_HOST=https://auth.your-domain.com
OAUTH2_REDIRECT_URI=https://your-domain.com/auth/callback

# JWT Configuration
JWT_ACCESS_SECRET=your-super-secret-access-key-here
JWT_REFRESH_SECRET=your-super-secret-refresh-key-here

# SAML Configuration
SAML_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----"
SAML_CERT="-----BEGIN CERTIFICATE-----\n...\n-----END CERTIFICATE-----"

# MFA Configuration
TWILIO_ACCOUNT_SID=your-twilio-sid
TWILIO_AUTH_TOKEN=your-twilio-token
TWILIO_PHONE_NUMBER=+1234567890

# Database & Cache
DATABASE_URL=postgresql://user:pass@localhost:5432/edtech
REDIS_URL=redis://localhost:6379

# Security
ALLOWED_ORIGINS=https://your-frontend.com,https://admin.your-domain.com
COOKIE_SECRET=your-cookie-secret-here
```

### **Docker Configuration**

```dockerfile
# Dockerfile
FROM node:18-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force

# Copy source code
COPY . .

# Build application
RUN npm run build

# Create non-root user
RUN addgroup -g 1001 -S nodejs
RUN adduser -S nodejs -u 1001

# Change ownership and switch to non-root user
RUN chown -R nodejs:nodejs /app
USER nodejs

EXPOSE 3000

CMD ["npm", "start"]
```

### **Kubernetes Deployment**

```yaml
# k8s/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: edtech-auth-service
spec:
  replicas: 3
  selector:
    matchLabels:
      app: edtech-auth-service
  template:
    metadata:
      labels:
        app: edtech-auth-service
    spec:
      containers:
      - name: auth-service
        image: your-registry/edtech-auth:latest
        ports:
        - containerPort: 3000
        env:
        - name: NODE_ENV
          value: "production"
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: edtech-secrets
              key: database-url
        - name: REDIS_URL
          valueFrom:
            secretKeyRef:
              name: edtech-secrets
              key: redis-url
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 3000
          initialDelaySeconds: 5
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: edtech-auth-service
spec:
  selector:
    app: edtech-auth-service
  ports:
  - port: 80
    targetPort: 3000
  type: ClusterIP
```

## ✅ Verification Checklist

### **Pre-Production Checklist**

- [ ] **Security Configuration**
  - [ ] JWT secrets are cryptographically secure (32+ chars)
  - [ ] HTTPS enforced in production
  - [ ] CORS properly configured
  - [ ] Rate limiting implemented
  - [ ] Input validation on all endpoints

- [ ] **OAuth2 Setup**
  - [ ] Client credentials configured
  - [ ] Redirect URIs whitelisted
  - [ ] Scopes properly defined
  - [ ] Token expiry configured

- [ ] **SAML Configuration**
  - [ ] Certificates valid and properly configured
  - [ ] Metadata endpoints accessible
  - [ ] Assertion encryption enabled
  - [ ] Clock skew tolerance configured

- [ ] **MFA Implementation**
  - [ ] TOTP secrets properly secured
  - [ ] SMS provider configured and tested
  - [ ] Backup codes generated
  - [ ] Recovery mechanisms in place

- [ ] **Monitoring & Logging**
  - [ ] Authentication events logged
  - [ ] Failed login attempts tracked
  - [ ] Performance metrics collected
  - [ ] Security alerts configured

### **Go-Live Steps**

1. **DNS Configuration**: Update DNS records for auth endpoints
2. **SSL Certificates**: Ensure valid certificates for all domains
3. **Load Balancer**: Configure health checks and routing
4. **Database Migration**: Run any pending schema updates
5. **Cache Warmup**: Pre-populate Redis with common data
6. **Monitoring Setup**: Verify all monitoring systems are active
7. **Backup Verification**: Confirm backup and recovery procedures

---

### Navigation
**Previous**: [Executive Summary](./executive-summary.md) | **Next**: [Best Practices](./best-practices.md)

---

*Implementation Guide for EdTech IAM Platform | July 2025*