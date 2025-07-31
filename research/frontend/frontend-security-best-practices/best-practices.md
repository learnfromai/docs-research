# Frontend Security Best Practices: Production Implementation Guide

This document consolidates security best practices for modern frontend applications, focusing on practical implementation strategies that provide robust protection while maintaining optimal user experience and development efficiency.

## Core Security Principles

### 1. Defense in Depth Strategy

Implement multiple layers of security controls to ensure that if one layer fails, others provide continued protection.

```typescript
// Multi-layered security implementation
class SecurityLayerManager {
  private layers = {
    input: new InputValidationLayer(),
    output: new OutputEncodingLayer(),
    csrf: new CSRFProtectionLayer(),
    csp: new CSPLayer(),
    authentication: new AuthenticationLayer(),
    authorization: new AuthorizationLayer(),
    monitoring: new SecurityMonitoringLayer()
  };

  async processRequest(request: SecurityRequest): Promise<SecurityResponse> {
    let processedRequest = request;
    
    // Apply each security layer in sequence
    for (const [layerName, layer] of Object.entries(this.layers)) {
      try {
        processedRequest = await layer.process(processedRequest);
      } catch (error) {
        console.error(`Security layer ${layerName} failed:`, error);
        
        // Critical layers should block request
        if (layer.isCritical()) {
          throw new SecurityError(`Critical security layer ${layerName} failed`);
        }
      }
    }
    
    return processedRequest.response;
  }
}
```

### 2. Zero Trust Architecture

Never trust, always verify. Validate all inputs and authenticate all requests regardless of source.

```typescript
// Zero trust implementation
interface ZeroTrustValidator {
  validateInput(input: any): ValidationResult;
  authenticateRequest(request: Request): AuthenticationResult;
  authorizeAction(user: User, action: string, resource: string): AuthorizationResult;
}

class ZeroTrustSecurityManager implements ZeroTrustValidator {
  validateInput(input: any): ValidationResult {
    // Always validate input regardless of source
    const schemas = {
      userProfile: Joi.object({
        name: Joi.string().min(2).max(50).pattern(/^[a-zA-Z\s]+$/).required(),
        email: Joi.string().email().required(),
        bio: Joi.string().max(500).optional()
      }),
      
      courseContent: Joi.object({
        title: Joi.string().min(5).max(100).required(),
        description: Joi.string().max(1000).required(),
        content: Joi.string().max(10000).required(),
        category: Joi.string().valid('math', 'science', 'language', 'history').required()
      })
    };

    // Determine appropriate schema
    const schema = this.determineSchema(input);
    const { error, value } = schema.validate(input, { stripUnknown: true });
    
    return {
      isValid: !error,
      sanitizedData: value,
      errors: error?.details || []
    };
  }

  authenticateRequest(request: Request): AuthenticationResult {
    // Multi-factor authentication verification
    const token = this.extractToken(request);
    const csrfToken = this.extractCSRFToken(request);
    const sessionInfo = this.extractSessionInfo(request);
    
    return {
      isAuthenticated: this.verifyToken(token) && 
                      this.verifyCSRF(csrfToken) && 
                      this.verifySession(sessionInfo),
      user: this.getUserFromToken(token),
      permissions: this.getUserPermissions(token)
    };
  }

  authorizeAction(user: User, action: string, resource: string): AuthorizationResult {
    // Role-based access control with resource-level permissions
    const userRoles = user.roles;
    const requiredPermissions = this.getRequiredPermissions(action, resource);
    
    const hasPermission = requiredPermissions.every(permission => 
      userRoles.some(role => role.permissions.includes(permission))
    );
    
    return {
      isAuthorized: hasPermission,
      grantedPermissions: this.getGrantedPermissions(userRoles),
      deniedReason: hasPermission ? null : 'Insufficient permissions'
    };
  }
}
```

### 3. Principle of Least Privilege

Grant minimum necessary permissions and access rights to users and applications.

```typescript
// Role-based access control with minimal permissions
interface Permission {
  resource: string;
  actions: string[];
  conditions?: Record<string, any>;
}

interface Role {
  name: string;
  permissions: Permission[];
  inherits?: string[];
}

class PermissionManager {
  private roles: Map<string, Role> = new Map();

  constructor() {
    this.initializeRoles();
  }

  private initializeRoles() {
    // Student role - minimal permissions
    this.roles.set('student', {
      name: 'student',
      permissions: [
        { resource: 'course', actions: ['read', 'enroll'] },
        { resource: 'assignment', actions: ['read', 'submit'] },
        { resource: 'profile', actions: ['read', 'update'], conditions: { ownProfile: true } },
        { resource: 'quiz', actions: ['take'] }
      ]
    });

    // Instructor role - course management permissions
    this.roles.set('instructor', {
      name: 'instructor',
      inherits: ['student'],
      permissions: [
        { resource: 'course', actions: ['create', 'update', 'delete'], conditions: { ownCourse: true } },
        { resource: 'assignment', actions: ['create', 'update', 'delete', 'grade'], conditions: { ownCourse: true } },
        { resource: 'student', actions: ['read'], conditions: { enrolledInOwnCourse: true } }
      ]
    });

    // Admin role - system administration
    this.roles.set('admin', {
      name: 'admin',
      inherits: ['instructor'],
      permissions: [
        { resource: '*', actions: ['*'] }
      ]
    });
  }

  hasPermission(userRoles: string[], resource: string, action: string, context?: any): boolean {
    for (const roleName of userRoles) {
      const role = this.roles.get(roleName);
      if (!role) continue;

      // Check inherited roles
      if (role.inherits) {
        if (this.hasPermission(role.inherits, resource, action, context)) {
          return true;
        }
      }

      // Check direct permissions
      for (const permission of role.permissions) {
        if (this.matchesPermission(permission, resource, action, context)) {
          return true;
        }
      }
    }

    return false;
  }

  private matchesPermission(permission: Permission, resource: string, action: string, context?: any): boolean {
    // Check resource match
    if (permission.resource !== '*' && permission.resource !== resource) {
      return false;
    }

    // Check action match
    if (!permission.actions.includes('*') && !permission.actions.includes(action)) {
      return false;
    }

    // Check conditions
    if (permission.conditions && context) {
      for (const [condition, expectedValue] of Object.entries(permission.conditions)) {
        if (context[condition] !== expectedValue) {
          return false;
        }
      }
    }

    return true;
  }
}
```

## Input Security Best Practices

### 1. Comprehensive Input Validation

Implement both client-side and server-side validation with strict schemas.

```typescript
// Advanced input validation system
class InputValidationSystem {
  private validators = new Map<string, Joi.Schema>();
  private sanitizers = new Map<string, (input: string) => string>();

  constructor() {
    this.initializeValidators();
    this.initializeSanitizers();
  }

  private initializeValidators() {
    // Email validation with domain restrictions for educational institutions
    this.validators.set('institutionalEmail', Joi.string()
      .email()
      .pattern(/^[a-zA-Z0-9._%+-]+@(edu\.ph|ateneo\.edu|up\.edu\.ph|dlsu\.edu\.ph)$/i)
      .required()
      .messages({
        'string.pattern.base': 'Email must be from a recognized Philippine educational institution'
      })
    );

    // Course content validation
    this.validators.set('courseContent', Joi.object({
      title: Joi.string()
        .min(5)
        .max(100)
        .pattern(/^[a-zA-Z0-9\s\-:(),.!?]+$/)
        .required(),
      
      description: Joi.string()
        .min(20)
        .max(500)
        .required(),
      
      content: Joi.string()
        .min(100)
        .max(50000)
        .custom(this.validateRichContent)
        .required(),
      
      difficulty: Joi.string()
        .valid('beginner', 'intermediate', 'advanced')
        .required(),
      
      tags: Joi.array()
        .items(Joi.string().alphanum().max(20))
        .max(10)
        .unique()
    }));

    // User registration validation
    this.validators.set('userRegistration', Joi.object({
      email: this.validators.get('institutionalEmail'),
      
      password: Joi.string()
        .min(12)
        .max(128)
        .pattern(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]/)
        .required()
        .messages({
          'string.pattern.base': 'Password must contain at least one uppercase letter, one lowercase letter, one number, and one special character'
        }),
      
      confirmPassword: Joi.string()
        .valid(Joi.ref('password'))
        .required()
        .messages({
          'any.only': 'Passwords must match'
        }),
      
      firstName: Joi.string()
        .min(2)
        .max(50)
        .pattern(/^[a-zA-Z\s\u00C0-\u017F]+$/) // Allow international characters
        .required(),
      
      lastName: Joi.string()
        .min(2)
        .max(50)
        .pattern(/^[a-zA-Z\s\u00C0-\u017F]+$/)
        .required(),
      
      dateOfBirth: Joi.date()
        .max('now')
        .min('1900-01-01')
        .required(),
      
      agreeToTerms: Joi.boolean()
        .valid(true)
        .required()
        .messages({
          'any.only': 'You must agree to the terms and conditions'
        })
    }));
  }

  private initializeSanitizers() {
    // HTML sanitizer for rich content
    this.sanitizers.set('richContent', (input: string) => {
      return DOMPurify.sanitize(input, {
        ALLOWED_TAGS: [
          'p', 'br', 'strong', 'em', 'u', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6',
          'ul', 'ol', 'li', 'blockquote', 'a', 'img', 'table', 'thead', 'tbody',
          'tr', 'td', 'th', 'pre', 'code', 'math', 'mfrac', 'msup', 'msub'
        ],
        ALLOWED_ATTR: [
          'href', 'src', 'alt', 'title', 'class', 'id',
          'width', 'height', 'colspan', 'rowspan'
        ],
        STRIP_IGNORE_TAG: true,
        STRIP_IGNORE_TAG_BODY: ['script', 'style'],
        ALLOW_DATA_ATTR: false
      });
    });

    // Plain text sanitizer
    this.sanitizers.set('plainText', (input: string) => {
      return input
        .replace(/[<>&"']/g, (char) => {
          const entityMap: Record<string, string> = {
            '<': '&lt;',
            '>': '&gt;',
            '&': '&amp;',
            '"': '&quot;',
            "'": '&#x27;'
          };
          return entityMap[char];
        })
        .trim();
    });
  }

  validate(data: any, schemaName: string): ValidationResult {
    const schema = this.validators.get(schemaName);
    if (!schema) {
      throw new Error(`Unknown validation schema: ${schemaName}`);
    }

    const { error, value } = schema.validate(data, {
      stripUnknown: true,
      abortEarly: false
    });

    return {
      isValid: !error,
      data: value,
      errors: error?.details.map(detail => ({
        field: detail.path.join('.'),
        message: detail.message,
        code: detail.type
      })) || []
    };
  }

  sanitize(input: string, sanitizerName: string): string {
    const sanitizer = this.sanitizers.get(sanitizerName);
    if (!sanitizer) {
      throw new Error(`Unknown sanitizer: ${sanitizerName}`);
    }

    return sanitizer(input);
  }

  // Custom validator for rich content
  private validateRichContent(value: string, helpers: any) {
    // Check for suspicious patterns
    const suspiciousPatterns = [
      /<script/i,
      /javascript:/i,
      /on\w+\s*=/i,
      /<iframe/i,
      /<object/i,
      /<embed/i
    ];

    for (const pattern of suspiciousPatterns) {
      if (pattern.test(value)) {
        return helpers.error('custom.suspicious', { pattern: pattern.source });
      }
    }

    return value;
  }
}
```

### 2. File Upload Security

Implement comprehensive file upload validation and security measures.

```typescript
// Secure file upload system
class SecureFileUploadManager {
  private readonly allowedMimeTypes = new Set([
    'image/jpeg', 'image/png', 'image/gif', 'image/webp',
    'application/pdf', 'text/plain', 'text/csv',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation'
  ]);

  private readonly maxFileSizes = new Map([
    ['image', 5 * 1024 * 1024], // 5MB for images
    ['document', 10 * 1024 * 1024], // 10MB for documents
    ['video', 100 * 1024 * 1024] // 100MB for videos
  ]);

  async validateFile(file: File, context: 'profile' | 'course' | 'assignment'): Promise<FileValidationResult> {
    const errors: string[] = [];

    // 1. File size validation
    const fileCategory = this.categorizeFile(file.type);
    const maxSize = this.maxFileSizes.get(fileCategory) || 1024 * 1024; // 1MB default

    if (file.size > maxSize) {
      errors.push(`File size exceeds maximum allowed size of ${maxSize / 1024 / 1024}MB`);
    }

    // 2. MIME type validation
    if (!this.allowedMimeTypes.has(file.type)) {
      errors.push(`File type ${file.type} is not allowed`);
    }

    // 3. File signature validation (magic number check)
    const buffer = await file.arrayBuffer();
    const isValidSignature = this.validateFileSignature(new Uint8Array(buffer), file.type);
    
    if (!isValidSignature) {
      errors.push('File signature does not match file extension');
    }

    // 4. Content scanning for malicious patterns
    if (fileCategory === 'document') {
      const textContent = await this.extractTextContent(file);
      const hasmaliciousContent = this.scanForMaliciousContent(textContent);
      
      if (hasmaliciousContent) {
        errors.push('File contains potentially malicious content');
      }
    }

    // 5. Context-specific validation
    const contextErrors = this.validateForContext(file, context);
    errors.push(...contextErrors);

    return {
      isValid: errors.length === 0,
      errors,
      sanitizedFileName: this.sanitizeFileName(file.name),
      detectedMimeType: file.type,
      fileCategory
    };
  }

  private validateFileSignature(buffer: Uint8Array, mimeType: string): boolean {
    const signatures: Record<string, Uint8Array[]> = {
      'image/jpeg': [
        new Uint8Array([0xFF, 0xD8, 0xFF]), // JPEG
      ],
      'image/png': [
        new Uint8Array([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]), // PNG
      ],
      'application/pdf': [
        new Uint8Array([0x25, 0x50, 0x44, 0x46]), // PDF
      ],
      'image/gif': [
        new Uint8Array([0x47, 0x49, 0x46, 0x38, 0x37, 0x61]), // GIF87a
        new Uint8Array([0x47, 0x49, 0x46, 0x38, 0x39, 0x61]), // GIF89a
      ]
    };

    const expectedSignatures = signatures[mimeType];
    if (!expectedSignatures) {
      return true; // Unknown type, skip signature check
    }

    return expectedSignatures.some(signature => {
      if (buffer.length < signature.length) return false;
      
      for (let i = 0; i < signature.length; i++) {
        if (buffer[i] !== signature[i]) return false;
      }
      return true;
    });
  }

  private categorizeFile(mimeType: string): string {
    if (mimeType.startsWith('image/')) return 'image';
    if (mimeType.startsWith('video/')) return 'video';
    if (mimeType.startsWith('audio/')) return 'audio';
    return 'document';
  }

  private sanitizeFileName(fileName: string): string {
    return fileName
      .replace(/[^a-zA-Z0-9.-]/g, '_') // Replace special characters
      .replace(/\.+/g, '.') // Replace multiple dots
      .replace(/^\./, '') // Remove leading dot
      .substring(0, 100); // Limit length
  }

  private async extractTextContent(file: File): Promise<string> {
    // Implementation would use appropriate libraries for different file types
    // For example: pdf-parse for PDF, mammoth for DOCX, etc.
    return ''; // Placeholder
  }

  private scanForMaliciousContent(content: string): boolean {
    const maliciousPatterns = [
      /<script/i,
      /javascript:/i,
      /vbscript:/i,
      /on\w+\s*=/i,
      /data:text\/html/i
    ];

    return maliciousPatterns.some(pattern => pattern.test(content));
  }

  private validateForContext(file: File, context: string): string[] {
    const errors: string[] = [];

    switch (context) {
      case 'profile':
        if (!file.type.startsWith('image/')) {
          errors.push('Profile pictures must be images');
        }
        if (file.size > 2 * 1024 * 1024) { // 2MB for profile pics
          errors.push('Profile pictures must be smaller than 2MB');
        }
        break;

      case 'course':
        // Allow images and documents for course materials
        if (!file.type.startsWith('image/') && !file.type.startsWith('application/')) {
          errors.push('Course materials must be images or documents');
        }
        break;

      case 'assignment':
        // Restrict to documents only for assignments
        if (file.type.startsWith('image/')) {
          errors.push('Assignment submissions cannot be images');
        }
        break;
    }

    return errors;
  }
}
```

## Authentication Security Best Practices

### 1. Multi-Factor Authentication (MFA)

Implement robust MFA for enhanced account security.

```typescript
// Multi-factor authentication system
class MFAManager {
  private totpSecret = new Map<string, string>();
  private backupCodes = new Map<string, string[]>();

  async setupTOTP(userId: string): Promise<TOTPSetupResult> {
    const secret = this.generateTOTPSecret();
    const qrCodeUrl = this.generateQRCode(secret, userId);
    
    // Store secret temporarily until verified
    this.totpSecret.set(`temp_${userId}`, secret);
    
    return {
      secret,
      qrCodeUrl,
      backupCodes: this.generateBackupCodes(userId)
    };
  }

  async verifyTOTPSetup(userId: string, token: string): Promise<boolean> {
    const secret = this.totpSecret.get(`temp_${userId}`);
    if (!secret) return false;

    const isValid = this.verifyTOTPToken(secret, token);
    
    if (isValid) {
      // Move from temporary to permanent storage
      this.totpSecret.set(userId, secret);
      this.totpSecret.delete(`temp_${userId}`);
      
      // Enable MFA for user
      await this.enableMFAForUser(userId);
    }

    return isValid;
  }

  async verifyMFA(userId: string, token: string, isBackupCode = false): Promise<MFAVerificationResult> {
    if (isBackupCode) {
      return this.verifyBackupCode(userId, token);
    }

    const secret = this.totpSecret.get(userId);
    if (!secret) {
      return { isValid: false, error: 'MFA not configured' };
    }

    const isValid = this.verifyTOTPToken(secret, token);
    return {
      isValid,
      remainingAttempts: isValid ? undefined : await this.getRemainingAttempts(userId)
    };
  }

  private generateTOTPSecret(): string {
    return crypto.randomBytes(20).toString('base32');
  }

  private generateQRCode(secret: string, userId: string): string {
    const issuer = 'EdTech Platform';
    const label = `${issuer}:${userId}`;
    return `otpauth://totp/${encodeURIComponent(label)}?secret=${secret}&issuer=${encodeURIComponent(issuer)}`;
  }

  private generateBackupCodes(userId: string): string[] {
    const codes = Array.from({ length: 10 }, () => 
      Math.random().toString(36).substr(2, 8).toUpperCase()
    );
    
    this.backupCodes.set(userId, codes);
    return codes;
  }

  private verifyTOTPToken(secret: string, token: string): boolean {
    // Implementation would use a TOTP library like speakeasy
    // This is a simplified version
    const timeStep = Math.floor(Date.now() / 30000);
    const expectedToken = this.generateTOTPToken(secret, timeStep);
    
    // Allow for time drift (check previous and next time steps)
    for (let i = -1; i <= 1; i++) {
      const checkToken = this.generateTOTPToken(secret, timeStep + i);
      if (checkToken === token) return true;
    }
    
    return false;
  }

  private generateTOTPToken(secret: string, timeStep: number): string {
    // Simplified TOTP implementation
    // In production, use a proper TOTP library
    const hash = crypto.createHmac('sha1', secret);
    hash.update(timeStep.toString());
    const hmac = hash.digest();
    
    const offset = hmac[hmac.length - 1] & 0xf;
    const code = ((hmac[offset] & 0x7f) << 24) |
                 ((hmac[offset + 1] & 0xff) << 16) |
                 ((hmac[offset + 2] & 0xff) << 8) |
                 (hmac[offset + 3] & 0xff);
    
    return (code % 1000000).toString().padStart(6, '0');
  }

  private async verifyBackupCode(userId: string, code: string): Promise<MFAVerificationResult> {
    const codes = this.backupCodes.get(userId);
    if (!codes || !codes.includes(code)) {
      return { isValid: false, error: 'Invalid backup code' };
    }

    // Remove used backup code
    const updatedCodes = codes.filter(c => c !== code);
    this.backupCodes.set(userId, updatedCodes);

    return {
      isValid: true,
      warningMessage: `Backup code used. ${updatedCodes.length} codes remaining.`
    };
  }
}
```

### 2. Session Management

Implement secure session handling with proper lifecycle management.

```typescript
// Secure session management
class SecureSessionManager {
  private sessions = new Map<string, SessionData>();
  private readonly sessionTimeout = 30 * 60 * 1000; // 30 minutes
  private readonly maxSessions = 5; // Maximum concurrent sessions per user

  async createSession(userId: string, deviceInfo: DeviceInfo): Promise<SessionCreationResult> {
    // Check for existing sessions
    const userSessions = this.getUserSessions(userId);
    
    // Enforce maximum sessions limit
    if (userSessions.length >= this.maxSessions) {
      // Remove oldest session
      const oldestSession = userSessions.sort((a, b) => a.createdAt - b.createdAt)[0];
      this.revokeSession(oldestSession.id);
    }

    const sessionId = this.generateSecureSessionId();
    const session: SessionData = {
      id: sessionId,
      userId,
      createdAt: Date.now(),
      lastActivity: Date.now(),
      deviceInfo,
      ipAddress: deviceInfo.ipAddress,
      isValid: true,
      permissions: await this.getUserPermissions(userId),
      csrfToken: this.generateCSRFToken()
    };

    this.sessions.set(sessionId, session);
    
    // Schedule session cleanup
    setTimeout(() => this.cleanupExpiredSessions(), this.sessionTimeout);

    return {
      sessionId,
      expiresAt: Date.now() + this.sessionTimeout,
      csrfToken: session.csrfToken
    };
  }

  async validateSession(sessionId: string, ipAddress?: string): Promise<SessionValidationResult> {
    const session = this.sessions.get(sessionId);
    
    if (!session || !session.isValid) {
      return { isValid: false, error: 'Invalid session' };
    }

    // Check session expiry
    if (Date.now() - session.lastActivity > this.sessionTimeout) {
      this.revokeSession(sessionId);
      return { isValid: false, error: 'Session expired' };
    }

    // Check IP address consistency (optional)
    if (ipAddress && session.ipAddress !== ipAddress) {
      // Log suspicious activity
      console.warn('Session IP mismatch:', {
        sessionId,
        originalIP: session.ipAddress,
        currentIP: ipAddress,
        userId: session.userId
      });
      
      // Optionally revoke session for security
      // this.revokeSession(sessionId);
      // return { isValid: false, error: 'IP address mismatch' };
    }

    // Update last activity
    session.lastActivity = Date.now();

    return {
      isValid: true,
      session,
      expiresAt: session.lastActivity + this.sessionTimeout
    };
  }

  async revokeSession(sessionId: string): Promise<void> {
    const session = this.sessions.get(sessionId);
    if (session) {
      session.isValid = false;
      
      // Log session revocation
      console.log('Session revoked:', {
        sessionId,
        userId: session.userId,
        reason: 'Manual revocation'
      });
    }
    
    this.sessions.delete(sessionId);
  }

  async revokeAllUserSessions(userId: string, exceptSession?: string): Promise<void> {
    const userSessions = this.getUserSessions(userId);
    
    for (const session of userSessions) {
      if (session.id !== exceptSession) {
        await this.revokeSession(session.id);
      }
    }
  }

  private generateSecureSessionId(): string {
    return crypto.randomBytes(32).toString('hex');
  }

  private generateCSRFToken(): string {
    return crypto.randomBytes(32).toString('base64');
  }

  private getUserSessions(userId: string): SessionData[] {
    return Array.from(this.sessions.values())
      .filter(session => session.userId === userId && session.isValid);
  }

  private cleanupExpiredSessions(): void {
    const now = Date.now();
    
    for (const [sessionId, session] of this.sessions.entries()) {
      if (now - session.lastActivity > this.sessionTimeout) {
        this.revokeSession(sessionId);
      }
    }
  }

  // Get active sessions for user dashboard
  async getUserActiveSessions(userId: string): Promise<ActiveSessionInfo[]> {
    return this.getUserSessions(userId).map(session => ({
      id: session.id,
      deviceInfo: session.deviceInfo,
      ipAddress: session.ipAddress,
      createdAt: new Date(session.createdAt),
      lastActivity: new Date(session.lastActivity),
      isCurrent: false // Would be determined by comparing with current session
    }));
  }
}
```

## Output Security Best Practices

### 1. Context-Aware Output Encoding

Implement encoding based on output context to prevent injection attacks.

```typescript
// Context-aware output encoding system
class ContextAwareEncoder {
  private encoders = new Map<string, (input: string) => string>();

  constructor() {
    this.initializeEncoders();
  }

  private initializeEncoders() {
    // HTML content encoding
    this.encoders.set('html', (input: string) => {
      return input.replace(/[&<>"']/g, (char) => {
        const entities: Record<string, string> = {
          '&': '&amp;',
          '<': '&lt;',
          '>': '&gt;',
          '"': '&quot;',
          "'": '&#x27;'
        };
        return entities[char];
      });
    });

    // HTML attribute encoding
    this.encoders.set('htmlAttribute', (input: string) => {
      return input.replace(/[&<>"'\s]/g, (char) => {
        const entities: Record<string, string> = {
          '&': '&amp;',
          '<': '&lt;',
          '>': '&gt;',
          '"': '&quot;',
          "'": '&#x27;',
          ' ': '&#x20;'
        };
        return entities[char] || `&#x${char.charCodeAt(0).toString(16)};`;
      });
    });

    // JavaScript string encoding
    this.encoders.set('javascript', (input: string) => {
      return input.replace(/[\\'"<>&\r\n\u2028\u2029]/g, (char) => {
        const entities: Record<string, string> = {
          '\\': '\\\\',
          "'": "\\'",
          '"': '\\"',
          '<': '\\u003C',
          '>': '\\u003E',
          '&': '\\u0026',
          '\r': '\\r',
          '\n': '\\n',
          '\u2028': '\\u2028',
          '\u2029': '\\u2029'
        };
        return entities[char];
      });
    });

    // CSS encoding
    this.encoders.set('css', (input: string) => {
      return input.replace(/[<>&"'\\()]/g, (char) => {
        return '\\' + char.charCodeAt(0).toString(16).padStart(6, '0');
      });
    });

    // URL encoding
    this.encoders.set('url', (input: string) => {
      return encodeURIComponent(input);
    });

    // JSON encoding
    this.encoders.set('json', (input: string) => {
      return JSON.stringify(input).slice(1, -1); // Remove surrounding quotes
    });
  }

  encode(input: string, context: string): string {
    const encoder = this.encoders.get(context);
    if (!encoder) {
      throw new Error(`Unknown encoding context: ${context}`);
    }
    
    return encoder(input);
  }

  // Template helper for safe output
  safeOutput(input: string, context: string = 'html'): string {
    if (input === null || input === undefined) {
      return '';
    }
    
    return this.encode(String(input), context);
  }
}

// React hook for safe output
export const useSafeOutput = () => {
  const encoder = new ContextAwareEncoder();
  
  return useCallback((input: string, context: string = 'html') => {
    return encoder.safeOutput(input, context);
  }, [encoder]);
};

// React component for safe content display
interface SafeOutputProps {
  content: string;
  context?: 'html' | 'htmlAttribute' | 'javascript' | 'css' | 'url' | 'json';
  tag?: keyof JSX.IntrinsicElements;
  className?: string;
}

export const SafeOutput: React.FC<SafeOutputProps> = ({
  content,
  context = 'html',
  tag: Tag = 'span',
  className = ''
}) => {
  const safeOutput = useSafeOutput();
  const encodedContent = safeOutput(content, context);
  
  return <Tag className={className}>{encodedContent}</Tag>;
};
```

## Security Monitoring and Incident Response

### 1. Security Event Monitoring

Implement comprehensive security event logging and monitoring.

```typescript
// Security monitoring system
class SecurityMonitor {
  private events: SecurityEvent[] = [];
  private alertThresholds = new Map<string, number>();
  private suspiciousIPs = new Set<string>();

  constructor() {
    this.initializeThresholds();
    this.startMonitoring();
  }

  private initializeThresholds() {
    this.alertThresholds.set('failedLogins', 5); // 5 failed logins in 15 minutes
    this.alertThresholds.set('xssAttempts', 3); // 3 XSS attempts in 5 minutes
    this.alertThresholds.set('csrfViolations', 2); // 2 CSRF violations in 10 minutes
    this.alertThresholds.set('cspViolations', 10); // 10 CSP violations in 1 hour
  }

  logSecurityEvent(event: SecurityEventData): void {
    const securityEvent: SecurityEvent = {
      id: crypto.randomUUID(),
      timestamp: Date.now(),
      type: event.type,
      severity: event.severity,
      details: event.details,
      userId: event.userId,
      ipAddress: event.ipAddress,
      userAgent: event.userAgent,
      sessionId: event.sessionId
    };

    this.events.push(securityEvent);
    
    // Check for alert conditions
    this.checkAlertConditions(securityEvent);
    
    // Store in persistent storage
    this.persistEvent(securityEvent);
  }

  private checkAlertConditions(event: SecurityEvent): void {
    const now = Date.now();
    const timeWindows = {
      failedLogins: 15 * 60 * 1000, // 15 minutes
      xssAttempts: 5 * 60 * 1000,   // 5 minutes
      csrfViolations: 10 * 60 * 1000, // 10 minutes
      cspViolations: 60 * 60 * 1000   // 1 hour
    };

    const window = timeWindows[event.type];
    if (!window) return;

    const recentEvents = this.events.filter(e => 
      e.type === event.type && 
      e.ipAddress === event.ipAddress &&
      (now - e.timestamp) <= window
    );

    const threshold = this.alertThresholds.get(event.type) || 10;
    
    if (recentEvents.length >= threshold) {
      this.triggerAlert(event, recentEvents);
    }
  }

  private triggerAlert(triggerEvent: SecurityEvent, relatedEvents: SecurityEvent[]): void {
    const alert: SecurityAlert = {
      id: crypto.randomUUID(),
      type: triggerEvent.type,
      severity: 'high',
      triggerEvent,
      relatedEvents,
      timestamp: Date.now(),
      status: 'active',
      description: this.generateAlertDescription(triggerEvent, relatedEvents.length)
    };

    // Mark IP as suspicious
    this.suspiciousIPs.add(triggerEvent.ipAddress);

    // Send notification
    this.sendAlertNotification(alert);

    // Log alert
    console.error('SECURITY ALERT:', alert);
  }

  private generateAlertDescription(event: SecurityEvent, eventCount: number): string {
    const descriptions = {
      failedLogins: `${eventCount} failed login attempts detected from IP ${event.ipAddress}`,
      xssAttempts: `${eventCount} XSS attempts detected from IP ${event.ipAddress}`,
      csrfViolations: `${eventCount} CSRF violations detected from IP ${event.ipAddress}`,
      cspViolations: `${eventCount} CSP violations detected from IP ${event.ipAddress}`
    };

    return descriptions[event.type] || `${eventCount} security events of type ${event.type}`;
  }

  private async sendAlertNotification(alert: SecurityAlert): Promise<void> {
    // Implementation would send to security team via email, Slack, etc.
    console.log('Sending security alert notification:', alert.description);
  }

  private async persistEvent(event: SecurityEvent): Promise<void> {
    // Implementation would store in database
    console.log('Security event logged:', {
      type: event.type,
      severity: event.severity,
      timestamp: new Date(event.timestamp).toISOString()
    });
  }

  // Clean up old events to prevent memory leaks
  private startMonitoring(): void {
    setInterval(() => {
      const cutoff = Date.now() - (24 * 60 * 60 * 1000); // 24 hours
      this.events = this.events.filter(event => event.timestamp > cutoff);
    }, 60 * 60 * 1000); // Clean up every hour
  }

  // Get security dashboard data
  getSecurityDashboard(timeframe: number = 24 * 60 * 60 * 1000): SecurityDashboard {
    const cutoff = Date.now() - timeframe;
    const recentEvents = this.events.filter(event => event.timestamp > cutoff);

    return {
      totalEvents: recentEvents.length,
      eventsByType: this.groupEventsByType(recentEvents),
      eventsBySeverity: this.groupEventsBySeverity(recentEvents),
      suspiciousIPs: Array.from(this.suspiciousIPs),
      topAttackedEndpoints: this.getTopAttackedEndpoints(recentEvents),
      timeSeriesData: this.generateTimeSeriesData(recentEvents)
    };
  }

  private groupEventsByType(events: SecurityEvent[]): Record<string, number> {
    return events.reduce((acc, event) => {
      acc[event.type] = (acc[event.type] || 0) + 1;
      return acc;
    }, {} as Record<string, number>);
  }

  private groupEventsBySeverity(events: SecurityEvent[]): Record<string, number> {
    return events.reduce((acc, event) => {
      acc[event.severity] = (acc[event.severity] || 0) + 1;
      return acc;
    }, {} as Record<string, number>);
  }

  private getTopAttackedEndpoints(events: SecurityEvent[]): Array<{ endpoint: string; count: number }> {
    const endpointCounts = events.reduce((acc, event) => {
      const endpoint = event.details.endpoint || 'unknown';
      acc[endpoint] = (acc[endpoint] || 0) + 1;
      return acc;
    }, {} as Record<string, number>);

    return Object.entries(endpointCounts)
      .map(([endpoint, count]) => ({ endpoint, count }))
      .sort((a, b) => b.count - a.count)
      .slice(0, 10);
  }

  private generateTimeSeriesData(events: SecurityEvent[]): Array<{ timestamp: number; count: number }> {
    const hourlyBuckets = new Map<number, number>();
    
    events.forEach(event => {
      const hour = Math.floor(event.timestamp / (60 * 60 * 1000)) * (60 * 60 * 1000);
      hourlyBuckets.set(hour, (hourlyBuckets.get(hour) || 0) + 1);
    });

    return Array.from(hourlyBuckets.entries())
      .map(([timestamp, count]) => ({ timestamp, count }))
      .sort((a, b) => a.timestamp - b.timestamp);
  }
}
```

## Security Configuration Checklist

### Development Environment
- [ ] **Security Libraries**: Install and configure security libraries (DOMPurify, helmet, etc.)
- [ ] **HTTPS Local**: Set up HTTPS for local development
- [ ] **Environment Variables**: Store secrets in environment variables
- [ ] **CSP Development**: Configure CSP in report-only mode
- [ ] **Security Linting**: Set up security-focused ESLint rules
- [ ] **Dependency Scanning**: Configure automated dependency vulnerability scanning

### Testing Environment
- [ ] **Security Tests**: Comprehensive security test suite
- [ ] **Penetration Testing**: Regular security testing with tools like OWASP ZAP
- [ ] **Code Review**: Security-focused code review process
- [ ] **Vulnerability Assessment**: Regular security assessments
- [ ] **Mock Security Services**: Test with realistic security configurations

### Production Environment
- [ ] **HTTPS Enforcement**: Strict HTTPS with HSTS headers
- [ ] **Security Headers**: Complete security header configuration
- [ ] **CSP Enforcement**: Full CSP policy enforcement
- [ ] **Rate Limiting**: API and authentication rate limiting
- [ ] **Security Monitoring**: Real-time security event monitoring
- [ ] **Incident Response**: Security incident response procedures
- [ ] **Regular Updates**: Automated security patch management
- [ ] **Backup Security**: Secure backup and recovery procedures

### Ongoing Maintenance
- [ ] **Security Audits**: Regular third-party security audits
- [ ] **Team Training**: Ongoing security awareness training
- [ ] **Threat Modeling**: Regular threat model updates
- [ ] **Compliance Reviews**: Regular compliance assessments
- [ ] **Documentation Updates**: Keep security documentation current

---

## Navigation

- ← Back to: [Frontend Security Best Practices](./README.md)
- → Next: [Security Considerations](./security-considerations.md)
- → Previous: [Content Security Policy Guide](./content-security-policy-guide.md)
- → Implementation: [Implementation Guide](./implementation-guide.md)