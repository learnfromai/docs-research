# Best Practices: Identity & Access Management

> **Security patterns, recommendations, and industry standards for OAuth2, SAML, and MFA implementations**

## 🛡️ Security First Principles

### **Zero Trust Architecture**

```typescript
// Example: Zero Trust API Design
export class ZeroTrustMiddleware {
  private verify = async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
    // 1. Verify identity (Who are you?)
    const identity = await this.verifyIdentity(req);
    
    // 2. Verify device (What device are you using?)
    const device = await this.verifyDevice(req);
    
    // 3. Verify context (Where are you? When?)
    const context = await this.verifyContext(req);
    
    // 4. Verify permissions (What can you access?)
    const permissions = await this.verifyPermissions(identity, req.path);
    
    // 5. Continuous monitoring
    this.logAccess(identity, device, context, permissions);
    
    if (this.calculateTrustScore([identity, device, context, permissions]) > 70) {
      next();
    } else {
      res.status(403).json({ error: 'Access denied - insufficient trust score' });
    }
  };
}
```

### **Defense in Depth Strategy**

| Layer | Security Measure | Implementation |
|-------|-----------------|----------------|
| **Network** | TLS 1.3, HSTS | Nginx/CloudFlare configuration |
| **Application** | Input validation, CSRF protection | Express middleware |
| **Authentication** | MFA, risk assessment | Custom auth service |
| **Authorization** | RBAC, attribute-based control | Permission engine |
| **Data** | Encryption at rest/transit | AES-256, database encryption |
| **Monitoring** | SIEM, anomaly detection | ELK stack, alerts |

## 🔐 OAuth2 Best Practices

### **Authorization Code Flow with PKCE**

```typescript
// PKCE Implementation for Enhanced Security
export class PKCEOAuth2Client {
  private generateCodeChallenge(codeVerifier: string): string {
    return crypto
      .createHash('sha256')
      .update(codeVerifier)
      .digest('base64url');
  }

  async initiateAuth(clientId: string, redirectUri: string) {
    // Generate cryptographically secure code verifier
    const codeVerifier = crypto.randomBytes(32).toString('base64url');
    const codeChallenge = this.generateCodeChallenge(codeVerifier);
    
    // Store code verifier securely (encrypted in session)
    const sessionData = {
      codeVerifier,
      timestamp: Date.now(),
      clientId,
      redirectUri,
    };
    
    await this.secureSession.set(
      sessionId, 
      this.encrypt(JSON.stringify(sessionData)),
      { ttl: 600 } // 10 minutes
    );

    const authUrl = new URL(this.authEndpoint);
    authUrl.searchParams.set('response_type', 'code');
    authUrl.searchParams.set('client_id', clientId);
    authUrl.searchParams.set('redirect_uri', redirectUri);
    authUrl.searchParams.set('code_challenge', codeChallenge);
    authUrl.searchParams.set('code_challenge_method', 'S256');
    authUrl.searchParams.set('state', await this.generateSecureState());
    authUrl.searchParams.set('scope', 'openid profile email');

    return authUrl.toString();
  }
}
```

### **Token Security Standards**

```typescript
// Secure Token Configuration
export const tokenConfig = {
  access: {
    algorithm: 'RS256', // Use asymmetric keys for better security
    expiresIn: '15m',   // Short-lived for security
    issuer: 'edtech-platform.com',
    audience: ['api.edtech-platform.com'],
    keyRotation: '30d', // Regular key rotation
  },
  refresh: {
    algorithm: 'HS256', // Symmetric for refresh tokens
    expiresIn: '30d',
    storage: 'secure-database', // Not in JWT payload
    singleUse: true,    // Implement refresh token rotation
    familyTracking: true, // Track token families for security
  },
  session: {
    httpOnly: true,
    secure: true,
    sameSite: 'strict',
    domain: '.edtech-platform.com',
    maxAge: 15 * 60 * 1000, // Match access token expiry
  },
};

// Token rotation implementation
export class SecureTokenService {
  async refreshTokens(refreshToken: string): Promise<TokenPair> {
    // Verify and invalidate current refresh token
    const tokenData = await this.verifyAndInvalidateRefreshToken(refreshToken);
    
    // Generate new token pair
    const newTokens = await this.generateTokenPair(tokenData.userId, tokenData.roles);
    
    // Update token family to detect reuse
    await this.updateTokenFamily(tokenData.familyId, newTokens.refresh.jti);
    
    return newTokens;
  }
  
  private async detectTokenReuse(familyId: string, tokenId: string): Promise<boolean> {
    const family = await this.redis.get(`token_family:${familyId}`);
    if (family && !family.includes(tokenId)) {
      // Token reuse detected - invalidate entire family
      await this.invalidateTokenFamily(familyId);
      return true;
    }
    return false;
  }
}
```

### **Scope Management**

```typescript
// Granular Permission System
export class PermissionManager {
  private readonly scopeHierarchy = {
    'admin': ['read:all', 'write:all', 'delete:all'],
    'teacher': ['read:students', 'write:grades', 'read:courses'],
    'student': ['read:own_profile', 'write:assignments', 'read:grades'],
    'parent': ['read:child_profile', 'read:child_grades'],
  };

  validateScope(userRoles: string[], requestedScope: string[]): boolean {
    const userPermissions = this.getUserPermissions(userRoles);
    return requestedScope.every(scope => 
      userPermissions.includes(scope) || this.hasImplicitPermission(userPermissions, scope)
    );
  }

  // Principle of least privilege
  generateMinimalScope(userRoles: string[], resourceType: string, action: string): string[] {
    const permission = `${action}:${resourceType}`;
    const userPermissions = this.getUserPermissions(userRoles);
    
    if (userPermissions.includes(permission)) {
      return [permission];
    }
    
    throw new Error('Insufficient permissions');
  }
}
```

## 🏢 SAML Best Practices

### **Secure SAML Configuration**

```xml
<!-- Secure SAML SP Configuration -->
<EntityDescriptor entityID="https://edtech-platform.com/sp"
                  xmlns="urn:oasis:names:tc:SAML:2.0:metadata">
  <SPSSODescriptor protocolSupportEnumeration="urn:oasis:names:tc:SAML:2.0:protocol"
                   AuthnRequestsSigned="true"
                   WantAssertionsSigned="true">
    
    <!-- Signing Certificate -->
    <KeyDescriptor use="signing">
      <KeyInfo xmlns="http://www.w3.org/2000/09/xmldsig#">
        <X509Data>
          <X509Certificate><!-- Your certificate here --></X509Certificate>
        </X509Data>
      </KeyInfo>
    </KeyDescriptor>
    
    <!-- Encryption Certificate -->
    <KeyDescriptor use="encryption">
      <KeyInfo xmlns="http://www.w3.org/2000/09/xmldsig#">
        <X509Data>
          <X509Certificate><!-- Your encryption certificate --></X509Certificate>
        </X509Data>
      </KeyInfo>
    </KeyDescriptor>
    
    <!-- Assertion Consumer Service -->
    <AssertionConsumerService Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST"
                              Location="https://edtech-platform.com/saml/acs"
                              index="1"/>
  </SPSSODescriptor>
</EntityDescriptor>
```

```typescript
// SAML Security Implementation
export class SecureSAMLHandler {
  private readonly securityRequirements = {
    signatureAlgorithm: 'http://www.w3.org/2001/04/xmldsig-more#rsa-sha256',
    digestAlgorithm: 'http://www.w3.org/2001/04/xmlenc#sha256',
    encryptionAlgorithm: 'http://www.w3.org/2001/04/xmlenc#aes256-cbc',
    clockSkew: 300, // 5 minutes maximum
    assertionExpiry: 300, // 5 minutes maximum
  };

  async validateSAMLResponse(samlResponse: string): Promise<SAMLAssertion> {
    // 1. Signature validation
    await this.validateSignature(samlResponse);
    
    // 2. Timestamp validation
    await this.validateTimestamps(samlResponse);
    
    // 3. Audience restriction
    await this.validateAudience(samlResponse);
    
    // 4. Replay attack prevention
    await this.preventReplayAttack(samlResponse);
    
    // 5. Assertion validation
    return this.extractAssertion(samlResponse);
  }

  private async preventReplayAttack(samlResponse: string): Promise<void> {
    const assertionId = this.extractAssertionId(samlResponse);
    const cacheKey = `saml:assertion:${assertionId}`;
    
    const exists = await this.redis.exists(cacheKey);
    if (exists) {
      throw new Error('SAML assertion replay detected');
    }
    
    // Cache assertion ID for maximum assertion lifetime
    await this.redis.setex(cacheKey, this.securityRequirements.assertionExpiry, '1');
  }
}
```

### **Identity Federation Patterns**

```typescript
// Multi-IdP Federation Management
export class IdentityFederationManager {
  private readonly trustedIdPs = new Map<string, IdPConfiguration>();

  async federateIdentity(idpEntityId: string, samlAssertion: SAMLAssertion): Promise<User> {
    const idpConfig = this.trustedIdPs.get(idpEntityId);
    if (!idpConfig) {
      throw new Error('Untrusted identity provider');
    }

    // Apply IdP-specific attribute mapping
    const mappedAttributes = this.mapAttributes(samlAssertion.attributes, idpConfig.attributeMap);
    
    // Create or update federated identity
    const federatedIdentity: FederatedIdentity = {
      localUserId: await this.findOrCreateUser(mappedAttributes),
      externalUserId: samlAssertion.nameId,
      idpEntityId,
      attributes: mappedAttributes,
      lastAuthentication: new Date(),
    };

    await this.storeFederatedIdentity(federatedIdentity);
    return this.getUser(federatedIdentity.localUserId);
  }

  // Attribute mapping for different IdPs
  private mapAttributes(attributes: any, attributeMap: AttributeMapping): UserAttributes {
    const mapped: UserAttributes = {};
    
    for (const [localAttribute, idpAttribute] of Object.entries(attributeMap)) {
      const value = attributes[idpAttribute];
      if (value) {
        mapped[localAttribute] = this.transformAttribute(localAttribute, value);
      }
    }

    return mapped;
  }
}
```

## 🔐 Multi-Factor Authentication Best Practices

### **Adaptive MFA Implementation**

```typescript
// Risk-Based MFA Decision Engine
export class AdaptiveMFAEngine {
  private readonly riskFactors = {
    location: { weight: 0.3, threshold: 0.7 },
    device: { weight: 0.25, threshold: 0.6 },
    behavior: { weight: 0.2, threshold: 0.5 },
    time: { weight: 0.15, threshold: 0.4 },
    network: { weight: 0.1, threshold: 0.8 },
  };

  async evaluateMFARequirement(userId: string, context: AuthContext): Promise<MFADecision> {
    const riskScore = await this.calculateRiskScore(userId, context);
    const userPreferences = await this.getUserMFAPreferences(userId);
    
    if (riskScore.total > 0.7) {
      return {
        required: true,
        methods: ['totp', 'sms'], // Multiple options for high risk
        reason: 'High-risk authentication detected',
        riskScore: riskScore.total,
      };
    }
    
    if (riskScore.total > 0.4 && context.resourceSensitivity === 'high') {
      return {
        required: true,
        methods: userPreferences.preferredMethods,
        reason: 'Accessing sensitive resources',
        riskScore: riskScore.total,
      };
    }

    return {
      required: false,
      riskScore: riskScore.total,
    };
  }

  private async calculateRiskScore(userId: string, context: AuthContext): Promise<RiskScore> {
    const factors = await Promise.all([
      this.assessLocationRisk(userId, context.location),
      this.assessDeviceRisk(userId, context.device),
      this.assessBehaviorRisk(userId, context.behavior),
      this.assessTimeRisk(userId, context.timestamp),
      this.assessNetworkRisk(context.network),
    ]);

    const weightedScore = factors.reduce((sum, factor, index) => {
      const weight = Object.values(this.riskFactors)[index].weight;
      return sum + (factor.score * weight);
    }, 0);

    return {
      total: Math.min(weightedScore, 1.0),
      factors: factors.reduce((acc, factor, index) => {
        acc[Object.keys(this.riskFactors)[index]] = factor;
        return acc;
      }, {}),
    };
  }
}
```

### **TOTP Security Enhancements**

```typescript
// Enhanced TOTP with Security Features
export class SecureTOTPService {
  private readonly config = {
    window: 1, // Accept 1 time step before/after current
    step: 30,  // 30-second time steps
    digits: 6, // 6-digit codes
    algorithm: 'sha256', // Use SHA-256 instead of SHA-1
    rateLimit: 3, // Maximum 3 attempts per time window
    backupCodes: 10, // Generate 10 backup codes
  };

  async setupTOTP(userId: string): Promise<TOTPSetup> {
    const secret = this.generateSecret();
    const backupCodes = this.generateBackupCodes();
    
    // Store setup data temporarily
    await this.redis.setex(
      `totp:setup:${userId}`,
      300, // 5 minutes
      JSON.stringify({
        secret: this.encrypt(secret),
        backupCodes: backupCodes.map(code => this.hash(code)),
        timestamp: Date.now(),
      })
    );

    return {
      secret,
      qrCode: await this.generateQRCode(userId, secret),
      backupCodes: backupCodes.map(code => this.obfuscateBackupCode(code)),
      recoveryInstructions: this.getRecoveryInstructions(),
    };
  }

  async verifyTOTP(userId: string, token: string, isBackupCode = false): Promise<boolean> {
    // Check rate limiting
    await this.checkRateLimit(userId);

    if (isBackupCode) {
      return this.verifyBackupCode(userId, token);
    }

    // Prevent replay attacks
    const replayKey = `totp:used:${userId}:${token}`;
    if (await this.redis.exists(replayKey)) {
      throw new Error('Token already used');
    }

    const secret = await this.getUserTOTPSecret(userId);
    const verified = speakeasy.totp.verify({
      secret,
      encoding: 'base32',
      token,
      window: this.config.window,
      step: this.config.step,
    });

    if (verified) {
      // Mark token as used
      await this.redis.setex(replayKey, this.config.step * 2, '1');
      await this.recordSuccessfulAuth(userId);
      return true;
    }

    await this.recordFailedAuth(userId);
    return false;
  }

  private async verifyBackupCode(userId: string, code: string): Promise<boolean> {
    const hashedCode = this.hash(code);
    const backupCodes = await this.getUserBackupCodes(userId);
    
    const codeIndex = backupCodes.indexOf(hashedCode);
    if (codeIndex === -1) {
      return false;
    }

    // Remove used backup code
    backupCodes.splice(codeIndex, 1);
    await this.updateUserBackupCodes(userId, backupCodes);
    
    // Warn user about remaining backup codes
    if (backupCodes.length <= 2) {
      await this.notifyLowBackupCodes(userId, backupCodes.length);
    }

    return true;
  }
}
```

### **SMS Security Considerations**

```typescript
// Secure SMS MFA Implementation
export class SecureSMSService {
  private readonly securityConfig = {
    codeLength: 6,
    codeExpiry: 300, // 5 minutes
    rateLimit: 3, // 3 SMS per hour
    phoneVerification: true,
    allowedCountries: ['PH', 'AU', 'GB', 'US'], // Business requirement
    suspiciousPatterns: [
      /(\d)\1{3,}/, // Repeated digits
      /123456|654321/, // Sequential patterns
    ],
  };

  async sendSMSCode(userId: string, phoneNumber: string): Promise<boolean> {
    // Validate phone number format and country
    await this.validatePhoneNumber(phoneNumber);
    
    // Check rate limiting
    await this.checkSMSRateLimit(userId);
    
    // Generate secure code
    const code = this.generateSecureCode();
    
    // Store code with expiry
    await this.redis.setex(
      `sms:code:${userId}`,
      this.securityConfig.codeExpiry,
      JSON.stringify({
        code: this.hash(code),
        phoneNumber: this.encrypt(phoneNumber),
        attempts: 0,
        timestamp: Date.now(),
      })
    );

    // Send SMS through multiple providers for reliability
    return this.sendSMSWithFallback(phoneNumber, code);
  }

  private generateSecureCode(): string {
    let code: string;
    do {
      code = crypto.randomInt(100000, 999999).toString();
    } while (this.isSuspiciousCode(code));
    
    return code;
  }

  private isSuspiciousCode(code: string): boolean {
    return this.securityConfig.suspiciousPatterns.some(pattern => 
      pattern.test(code)
    );
  }

  private async sendSMSWithFallback(phoneNumber: string, code: string): Promise<boolean> {
    const providers = ['twilio', 'aws-sns', 'messagebird'];
    
    for (const provider of providers) {
      try {
        await this.sendSMSViaProvider(provider, phoneNumber, code);
        return true;
      } catch (error) {
        console.warn(`SMS provider ${provider} failed:`, error.message);
        continue;
      }
    }
    
    throw new Error('All SMS providers failed');
  }
}
```

## 🔒 Session Management Best Practices

### **Secure Session Handling**

```typescript
// Advanced Session Management
export class SecureSessionManager {
  private readonly sessionConfig = {
    maxAge: 15 * 60 * 1000, // 15 minutes
    renewThreshold: 5 * 60 * 1000, // Renew if < 5 minutes left
    maxSessions: 3, // Maximum concurrent sessions
    securityChecks: {
      ipValidation: true,
      userAgentValidation: true,
      deviceFingerprinting: true,
    },
  };

  async createSession(userId: string, authContext: AuthContext): Promise<Session> {
    // Limit concurrent sessions
    await this.enforceConcurrentSessionLimit(userId);
    
    const sessionId = this.generateSessionId();
    const session: Session = {
      id: sessionId,
      userId,
      createdAt: new Date(),
      lastActivity: new Date(),
      ipAddress: authContext.ipAddress,
      userAgent: authContext.userAgent,
      deviceFingerprint: this.generateDeviceFingerprint(authContext),
      mfaVerified: authContext.mfaVerified || false,
      riskScore: authContext.riskScore || 0,
    };

    // Store session with expiry
    await this.redis.setex(
      `session:${sessionId}`,
      this.sessionConfig.maxAge / 1000,
      JSON.stringify(session)
    );

    // Track user sessions
    await this.redis.sadd(`user:sessions:${userId}`, sessionId);
    
    return session;
  }

  async validateSession(sessionId: string, request: Request): Promise<Session | null> {
    const sessionData = await this.redis.get(`session:${sessionId}`);
    if (!sessionData) {
      return null;
    }

    const session: Session = JSON.parse(sessionData);
    
    // Security validations
    if (this.sessionConfig.securityChecks.ipValidation) {
      if (session.ipAddress !== request.ip) {
        await this.invalidateSession(sessionId);
        throw new Error('Session IP mismatch');
      }
    }

    if (this.sessionConfig.securityChecks.userAgentValidation) {
      if (session.userAgent !== request.headers['user-agent']) {
        await this.invalidateSession(sessionId);
        throw new Error('Session User-Agent mismatch');
      }
    }

    // Update last activity
    session.lastActivity = new Date();
    await this.redis.setex(
      `session:${sessionId}`,
      this.sessionConfig.maxAge / 1000,
      JSON.stringify(session)
    );

    // Check if session needs renewal
    if (this.shouldRenewSession(session)) {
      return this.renewSession(session);
    }

    return session;
  }

  private async enforceConcurrentSessionLimit(userId: string): Promise<void> {
    const activeSessions = await this.redis.smembers(`user:sessions:${userId}`);
    
    if (activeSessions.length >= this.sessionConfig.maxSessions) {
      // Remove oldest session
      const oldestSession = await this.findOldestSession(activeSessions);
      await this.invalidateSession(oldestSession);
    }
  }
}
```

## 🚨 Security Monitoring & Incident Response

### **Security Event Logging**

```typescript
// Comprehensive Security Logging
export class SecurityAuditLogger {
  private readonly eventTypes = {
    AUTHENTICATION_SUCCESS: 'auth.success',
    AUTHENTICATION_FAILURE: 'auth.failure',
    MFA_CHALLENGE: 'mfa.challenge',
    MFA_SUCCESS: 'mfa.success',
    MFA_FAILURE: 'mfa.failure',
    SESSION_CREATED: 'session.created',
    SESSION_EXPIRED: 'session.expired',
    SUSPICIOUS_ACTIVITY: 'security.suspicious',
    PERMISSION_DENIED: 'authz.denied',
    TOKEN_REFRESH: 'token.refresh',
  };

  async logSecurityEvent(eventType: string, context: SecurityEventContext): Promise<void> {
    const event: SecurityEvent = {
      id: this.generateEventId(),
      type: eventType,
      timestamp: new Date().toISOString(),
      userId: context.userId,
      sessionId: context.sessionId,
      ipAddress: context.ipAddress,
      userAgent: context.userAgent,
      resource: context.resource,
      action: context.action,
      result: context.result,
      riskScore: context.riskScore,
      metadata: context.metadata,
    };

    // Store in multiple locations for redundancy
    await Promise.all([
      this.storeInElasticsearch(event),
      this.storeInDatabase(event),
      this.sendToSIEM(event),
    ]);

    // Real-time alerting for critical events
    if (this.isCriticalEvent(event)) {
      await this.triggerSecurityAlert(event);
    }
  }

  private isCriticalEvent(event: SecurityEvent): boolean {
    const criticalEvents = [
      this.eventTypes.SUSPICIOUS_ACTIVITY,
      'multiple.failed.attempts',
      'admin.privilege.escalation',
      'data.breach.attempt',
    ];

    return criticalEvents.includes(event.type) || 
           (event.riskScore && event.riskScore > 0.8);
  }

  async detectAnomalies(userId: string): Promise<SecurityAlert[]> {
    const recentEvents = await this.getRecentEvents(userId, 24); // Last 24 hours
    const userBaseline = await this.getUserBaseline(userId);
    const alerts: SecurityAlert[] = [];

    // Location anomaly detection
    const locationAnomaly = this.detectLocationAnomaly(recentEvents, userBaseline);
    if (locationAnomaly.score > 0.7) {
      alerts.push({
        type: 'LOCATION_ANOMALY',
        severity: 'HIGH',
        description: 'Login from unusual location',
        evidence: locationAnomaly.evidence,
      });
    }

    // Time-based anomaly detection
    const timeAnomaly = this.detectTimeAnomaly(recentEvents, userBaseline);
    if (timeAnomaly.score > 0.6) {
      alerts.push({
        type: 'TIME_ANOMALY',
        severity: 'MEDIUM',
        description: 'Login at unusual time',
        evidence: timeAnomaly.evidence,
      });
    }

    // Velocity anomaly detection
    const velocityAnomaly = this.detectVelocityAnomaly(recentEvents);
    if (velocityAnomaly.score > 0.8) {
      alerts.push({
        type: 'VELOCITY_ANOMALY',
        severity: 'CRITICAL',
        description: 'Impossible travel detected',
        evidence: velocityAnomaly.evidence,
      });
    }

    return alerts;
  }
}
```

### **Incident Response Automation**

```typescript
// Automated Incident Response
export class IncidentResponseSystem {
  private readonly responseMatrix = {
    'BRUTE_FORCE_ATTACK': {
      severity: 'HIGH',
      autoResponse: ['block_ip', 'require_mfa', 'notify_user'],
      escalation: 'security_team',
    },
    'CREDENTIAL_STUFFING': {
      severity: 'HIGH',
      autoResponse: ['temporary_lockout', 'force_password_reset'],
      escalation: 'security_team',
    },
    'SUSPICIOUS_LOGIN': {
      severity: 'MEDIUM',
      autoResponse: ['require_mfa', 'log_event'],
      escalation: 'automated_only',
    },
    'DATA_BREACH_ATTEMPT': {
      severity: 'CRITICAL',
      autoResponse: ['immediate_lockout', 'preserve_evidence', 'emergency_alert'],
      escalation: 'ciso',
    },
  };

  async handleSecurityIncident(incident: SecurityIncident): Promise<IncidentResponse> {
    const responseConfig = this.responseMatrix[incident.type];
    if (!responseConfig) {
      throw new Error(`Unknown incident type: ${incident.type}`);
    }

    const response: IncidentResponse = {
      incidentId: incident.id,
      timestamp: new Date(),
      actions: [],
      notifications: [],
    };

    // Execute automated responses
    for (const action of responseConfig.autoResponse) {
      try {
        await this.executeResponse(action, incident);
        response.actions.push({
          action,
          status: 'SUCCESS',
          timestamp: new Date(),
        });
      } catch (error) {
        response.actions.push({
          action,
          status: 'FAILED',
          error: error.message,
          timestamp: new Date(),
        });
      }
    }

    // Handle escalation
    if (responseConfig.escalation !== 'automated_only') {
      await this.escalateIncident(incident, responseConfig.escalation);
      response.notifications.push({
        recipient: responseConfig.escalation,
        status: 'SENT',
        timestamp: new Date(),
      });
    }

    // Store incident response
    await this.storeIncidentResponse(response);
    
    return response;
  }

  private async executeResponse(action: string, incident: SecurityIncident): Promise<void> {
    switch (action) {
      case 'block_ip':
        await this.ipBlockingService.blockIP(incident.sourceIP, '24h');
        break;
      
      case 'require_mfa':
        await this.userService.setMFARequired(incident.userId, true);
        break;
      
      case 'temporary_lockout':
        await this.userService.lockAccount(incident.userId, '1h');
        break;
      
      case 'immediate_lockout':
        await this.userService.lockAccount(incident.userId, 'indefinite');
        break;
      
      case 'force_password_reset':
        await this.userService.invalidateAllSessions(incident.userId);
        await this.userService.requirePasswordReset(incident.userId);
        break;
      
      case 'preserve_evidence':
        await this.evidenceService.preserveUserActivity(incident.userId, '30d');
        break;
      
      case 'emergency_alert':
        await this.notificationService.sendEmergencyAlert(incident);
        break;
    }
  }
}
```

## 📊 Performance & Scalability Best Practices

### **Caching Strategies**

```typescript
// Multi-Level Caching for IAM
export class IAMCacheManager {
  private readonly cacheConfig = {
    levels: {
      l1: { type: 'memory', ttl: 60 }, // 1 minute in-memory cache
      l2: { type: 'redis', ttl: 300 }, // 5 minutes in Redis
      l3: { type: 'database', ttl: 3600 }, // 1 hour database cache
    },
    strategies: {
      userProfile: 'write-through',
      permissions: 'cache-aside',
      sessions: 'write-behind',
      tokens: 'refresh-ahead',
    },
  };

  async getCachedUserPermissions(userId: string, resource?: string): Promise<Permission[]> {
    const cacheKey = `permissions:${userId}:${resource || 'all'}`;
    
    // L1 Cache (Memory)
    let permissions = this.memoryCache.get(cacheKey);
    if (permissions) {
      this.metrics.increment('cache.hit.l1');
      return permissions;
    }

    // L2 Cache (Redis)
    const cachedData = await this.redis.get(cacheKey);
    if (cachedData) {
      permissions = JSON.parse(cachedData);
      this.memoryCache.set(cacheKey, permissions, this.cacheConfig.levels.l1.ttl);
      this.metrics.increment('cache.hit.l2');
      return permissions;
    }

    // L3 Cache (Database)
    permissions = await this.permissionService.getUserPermissions(userId, resource);
    
    // Store in all cache levels
    await this.redis.setex(cacheKey, this.cacheConfig.levels.l2.ttl, JSON.stringify(permissions));
    this.memoryCache.set(cacheKey, permissions, this.cacheConfig.levels.l1.ttl);
    
    this.metrics.increment('cache.miss');
    return permissions;
  }

  // Cache warming for frequently accessed data
  async warmupCache(): Promise<void> {
    const criticalUsers = await this.getUsersRequiringWarmup();
    
    await Promise.all(
      criticalUsers.map(async (userId) => {
        await this.getCachedUserPermissions(userId);
        await this.getCachedUserProfile(userId);
        await this.getCachedUserPreferences(userId);
      })
    );
  }
}
```

### **Database Optimization**

```sql
-- Optimized Database Schema for IAM
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    email_verified BOOLEAN DEFAULT FALSE,
    password_hash VARCHAR(255),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    last_login_at TIMESTAMP,
    login_count INTEGER DEFAULT 0,
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'locked', 'suspended')),
    metadata JSONB DEFAULT '{}',
    
    -- Indexes for performance
    INDEX idx_users_email (email),
    INDEX idx_users_status (status),
    INDEX idx_users_last_login (last_login_at)
);

CREATE TABLE user_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    session_token VARCHAR(255) UNIQUE NOT NULL,
    ip_address INET NOT NULL,
    user_agent TEXT,
    device_fingerprint VARCHAR(255),
    created_at TIMESTAMP DEFAULT NOW(),
    expires_at TIMESTAMP NOT NULL,
    last_activity TIMESTAMP DEFAULT NOW(),
    
    -- Partitioning by month for performance
    PARTITION BY RANGE (created_at),
    
    -- Indexes
    INDEX idx_sessions_token (session_token),
    INDEX idx_sessions_user_id (user_id),
    INDEX idx_sessions_expires (expires_at)
);

-- Create monthly partitions
CREATE TABLE user_sessions_2024_07 PARTITION OF user_sessions
    FOR VALUES FROM ('2024-07-01') TO ('2024-08-01');

CREATE TABLE user_sessions_2024_08 PARTITION OF user_sessions
    FOR VALUES FROM ('2024-08-01') TO ('2024-09-01');

-- Roles and permissions with efficient hierarchy
CREATE TABLE roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) UNIQUE NOT NULL,
    description TEXT,
    parent_role_id UUID REFERENCES roles(id),
    level INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    resource VARCHAR(100) NOT NULL,
    action VARCHAR(50) NOT NULL,
    description TEXT,
    
    UNIQUE(resource, action)
);

-- Materialized view for role hierarchy
CREATE MATERIALIZED VIEW role_hierarchy AS
WITH RECURSIVE role_tree AS (
    SELECT id, name, parent_role_id, level, ARRAY[id] as path
    FROM roles
    WHERE parent_role_id IS NULL
    
    UNION ALL
    
    SELECT r.id, r.name, r.parent_role_id, r.level, rt.path || r.id
    FROM roles r
    JOIN role_tree rt ON r.parent_role_id = rt.id
)
SELECT * FROM role_tree;

-- Refresh materialized view periodically
CREATE OR REPLACE FUNCTION refresh_role_hierarchy()
RETURNS TRIGGER AS $$
BEGIN
    REFRESH MATERIALIZED VIEW role_hierarchy;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER refresh_role_hierarchy_trigger
    AFTER INSERT OR UPDATE OR DELETE ON roles
    FOR EACH STATEMENT
    EXECUTE FUNCTION refresh_role_hierarchy();
```

## 🔍 Compliance & Audit Best Practices

### **GDPR Compliance Implementation**

```typescript
// GDPR Compliance Service
export class GDPRComplianceService {
  private readonly dataRetentionPolicies = {
    userProfiles: '7 years',
    authLogs: '2 years',
    sessionData: '90 days',
    auditLogs: '6 years',
  };

  async handleDataSubjectRequest(request: DataSubjectRequest): Promise<DataSubjectResponse> {
    switch (request.type) {
      case 'ACCESS':
        return this.handleAccessRequest(request);
      case 'RECTIFICATION':
        return this.handleRectificationRequest(request);
      case 'ERASURE':
        return this.handleErasureRequest(request);
      case 'PORTABILITY':
        return this.handlePortabilityRequest(request);
      case 'RESTRICTION':
        return this.handleRestrictionRequest(request);
      default:
        throw new Error(`Unsupported request type: ${request.type}`);
    }
  }

  private async handleAccessRequest(request: DataSubjectRequest): Promise<DataSubjectResponse> {
    const userId = await this.verifyDataSubject(request);
    
    const personalData = await this.collectPersonalData(userId);
    const processingActivities = await this.getProcessingActivities(userId);
    const dataSharing = await this.getDataSharingHistory(userId);

    return {
      requestId: request.id,
      type: 'ACCESS',
      data: {
        personalData,
        processingActivities,
        dataSharing,
        retentionPeriods: this.dataRetentionPolicies,
      },
      format: 'JSON', // Machine-readable format
      completedAt: new Date(),
    };
  }

  private async handleErasureRequest(request: DataSubjectRequest): Promise<DataSubjectResponse> {
    const userId = await this.verifyDataSubject(request);
    
    // Check if erasure is legally possible
    const legalBasis = await this.checkErasureLegalBasis(userId);
    if (!legalBasis.canErase) {
      return {
        requestId: request.id,
        type: 'ERASURE',
        status: 'REJECTED',
        reason: legalBasis.reason,
        completedAt: new Date(),
      };
    }

    // Perform erasure
    await this.performDataErasure(userId);
    
    return {
      requestId: request.id,
      type: 'ERASURE',
      status: 'COMPLETED',
      erasedData: legalBasis.erasableData,
      retainedData: legalBasis.retainedData,
      completedAt: new Date(),
    };
  }

  // Automated data retention enforcement
  async enforceDataRetention(): Promise<void> {
    for (const [dataType, retentionPeriod] of Object.entries(this.dataRetentionPolicies)) {
      const cutoffDate = this.calculateCutoffDate(retentionPeriod);
      await this.purgeExpiredData(dataType, cutoffDate);
    }
  }
}
```

### **Audit Trail Implementation**

```typescript
// Comprehensive Audit Trail
export class AuditTrailService {
  private readonly auditEvents = {
    USER_CREATED: 'user.created',
    USER_UPDATED: 'user.updated',
    USER_DELETED: 'user.deleted',
    ROLE_ASSIGNED: 'role.assigned',
    PERMISSION_GRANTED: 'permission.granted',
    PERMISSION_REVOKED: 'permission.revoked',
    DATA_ACCESS: 'data.access',
    DATA_MODIFICATION: 'data.modification',
    CONFIGURATION_CHANGE: 'config.change',
  };

  async createAuditLog(event: AuditEvent): Promise<void> {
    const auditRecord: AuditRecord = {
      id: this.generateAuditId(),
      eventType: event.type,
      timestamp: new Date(),
      actor: {
        userId: event.actorId,
        role: event.actorRole,
        sessionId: event.sessionId,
      },
      target: {
        resourceType: event.resourceType,
        resourceId: event.resourceId,
        resourceName: event.resourceName,
      },
      action: event.action,
      outcome: event.outcome,
      details: event.details,
      context: {
        ipAddress: event.ipAddress,
        userAgent: event.userAgent,
        requestId: event.requestId,
      },
      hash: '', // Will be calculated
    };

    // Calculate integrity hash
    auditRecord.hash = this.calculateIntegrityHash(auditRecord);
    
    // Store in tamper-evident storage
    await this.storeAuditRecord(auditRecord);
    
    // Real-time SIEM integration
    await this.sendToSIEM(auditRecord);
  }

  private calculateIntegrityHash(record: AuditRecord): string {
    const data = {
      ...record,
      hash: undefined, // Exclude hash from hash calculation
    };
    
    return crypto
      .createHash('sha256')
      .update(JSON.stringify(data) + process.env.AUDIT_SALT)
      .digest('hex');
  }

  async verifyAuditIntegrity(recordId: string): Promise<boolean> {
    const record = await this.getAuditRecord(recordId);
    const storedHash = record.hash;
    
    // Recalculate hash
    record.hash = '';
    const calculatedHash = this.calculateIntegrityHash(record);
    
    return storedHash === calculatedHash;
  }

  // Audit query interface for compliance reporting
  async generateComplianceReport(criteria: ComplianceReportCriteria): Promise<ComplianceReport> {
    const auditRecords = await this.queryAuditRecords(criteria);
    
    return {
      reportId: this.generateReportId(),
      period: criteria.period,
      generatedAt: new Date(),
      summary: {
        totalEvents: auditRecords.length,
        eventsByType: this.groupEventsByType(auditRecords),
        riskEvents: this.filterRiskEvents(auditRecords),
        complianceViolations: this.identifyViolations(auditRecords),
      },
      details: auditRecords,
      integrityVerification: await this.verifyBatchIntegrity(auditRecords),
    };
  }
}
```

## 🔧 Configuration Management

### **Environment-Specific Configurations**

```typescript
// Configuration Management for Different Environments
export class IAMConfigManager {
  private readonly environments = {
    development: {
      security: {
        tokenExpiry: '60m', // Longer for development
        mfaRequired: false,
        rateLimiting: false,
        httpsRequired: false,
      },
      logging: {
        level: 'debug',
        auditEnabled: true,
        performanceMetrics: true,
      },
    },
    staging: {
      security: {
        tokenExpiry: '15m',
        mfaRequired: true,
        rateLimiting: true,
        httpsRequired: true,
      },
      logging: {
        level: 'info',
        auditEnabled: true,
        performanceMetrics: true,
      },
    },
    production: {
      security: {
        tokenExpiry: '15m',
        mfaRequired: true,
        rateLimiting: true,
        httpsRequired: true,
        additionalSecurityHeaders: true,
      },
      logging: {
        level: 'warn',
        auditEnabled: true,
        performanceMetrics: true,
        alerting: true,
      },
    },
  };

  getConfig(environment: string = process.env.NODE_ENV || 'development') {
    const baseConfig = this.environments[environment];
    if (!baseConfig) {
      throw new Error(`Unknown environment: ${environment}`);
    }

    // Merge with environment variables
    return {
      ...baseConfig,
      database: {
        url: process.env.DATABASE_URL,
        poolSize: parseInt(process.env.DB_POOL_SIZE || '10'),
        ssl: environment === 'production',
      },
      cache: {
        url: process.env.REDIS_URL,
        cluster: environment === 'production',
      },
      oauth2: {
        clientId: process.env.OAUTH2_CLIENT_ID,
        clientSecret: process.env.OAUTH2_CLIENT_SECRET,
        redirectUri: process.env.OAUTH2_REDIRECT_URI,
      },
      monitoring: {
        metricsEndpoint: process.env.METRICS_ENDPOINT,
        alertingWebhook: process.env.ALERT_WEBHOOK_URL,
      },
    };
  }
}
```

---

### Navigation
**Previous**: [Implementation Guide](./implementation-guide.md) | **Next**: [Comparison Analysis](./comparison-analysis.md)

---

*Best Practices Guide for EdTech IAM Security | July 2025*