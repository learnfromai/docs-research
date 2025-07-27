# Security Considerations: Secure NestJS Application Development

## 🔐 Authentication & Authorization

### 1. JWT Security Implementation

**Secure JWT Configuration:**
```typescript
// config/jwt.config.ts
import { registerAs } from '@nestjs/config';

export default registerAs('jwt', () => ({
  secret: process.env.JWT_SECRET, // Use strong, randomly generated secret
  accessTokenTtl: process.env.JWT_ACCESS_TOKEN_TTL || '15m',
  refreshTokenTtl: process.env.JWT_REFRESH_TOKEN_TTL || '7d',
  issuer: process.env.JWT_ISSUER || 'your-app-name',
  audience: process.env.JWT_AUDIENCE || 'your-app-users',
  algorithm: 'HS256', // Consider RS256 for microservices
}));

// JWT payload should be minimal and non-sensitive
interface JwtPayload {
  sub: string; // User ID
  email: string;
  roles: string[];
  iat: number;
  exp: number;
  iss: string;
  aud: string;
}
```

**Advanced JWT Strategy with Security Checks:**
```typescript
@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(
    private configService: ConfigService,
    private usersService: UsersService,
    private blacklistService: BlacklistService,
  ) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: configService.get('jwt.secret'),
      issuer: configService.get('jwt.issuer'),
      audience: configService.get('jwt.audience'),
      passReqToCallback: true,
    });
  }

  async validate(request: Request, payload: JwtPayload) {
    // Extract token from request
    const token = ExtractJwt.fromAuthHeaderAsBearerToken()(request);
    
    // Check if token is blacklisted (for logout)
    if (await this.blacklistService.isBlacklisted(token)) {
      throw new UnauthorizedException('Token has been revoked');
    }

    // Verify user still exists and is active
    const user = await this.usersService.findById(payload.sub);
    if (!user || !user.isActive) {
      throw new UnauthorizedException('User not found or inactive');
    }

    // Check for password change (invalidate old tokens)
    if (user.passwordChangedAt && payload.iat * 1000 < user.passwordChangedAt.getTime()) {
      throw new UnauthorizedException('Password changed, please login again');
    }

    // Add token to request for later use (e.g., logout)
    user.currentToken = token;
    
    return user;
  }
}
```

### 2. Secure Password Management

```typescript
@Injectable()
export class PasswordService {
  private readonly saltRounds = 12; // Minimum 10, 12 is better

  async hashPassword(password: string): Promise<string> {
    // Validate password strength
    this.validatePasswordStrength(password);
    
    return bcrypt.hash(password, this.saltRounds);
  }

  async validatePassword(password: string, hashedPassword: string): Promise<boolean> {
    return bcrypt.compare(password, hashedPassword);
  }

  private validatePasswordStrength(password: string): void {
    const minLength = 8;
    const hasUpperCase = /[A-Z]/.test(password);
    const hasLowerCase = /[a-z]/.test(password);
    const hasNumbers = /\d/.test(password);
    const hasSpecialChar = /[!@#$%^&*(),.?":{}|<>]/.test(password);

    if (password.length < minLength) {
      throw new BadRequestException('Password must be at least 8 characters long');
    }

    if (!hasUpperCase || !hasLowerCase || !hasNumbers || !hasSpecialChar) {
      throw new BadRequestException(
        'Password must contain at least one uppercase letter, lowercase letter, number, and special character'
      );
    }

    // Check against common passwords
    if (this.isCommonPassword(password)) {
      throw new BadRequestException('Password is too common, please choose a stronger password');
    }
  }

  private isCommonPassword(password: string): boolean {
    const commonPasswords = [
      'password', '123456', 'password123', 'admin', 'qwerty',
      'letmein', 'welcome', '123456789', 'password1', 'abc123'
    ];
    return commonPasswords.includes(password.toLowerCase());
  }

  // Password reset with secure token
  async generateResetToken(): Promise<string> {
    return crypto.randomBytes(32).toString('hex');
  }

  async hashResetToken(token: string): Promise<string> {
    return crypto.createHash('sha256').update(token).digest('hex');
  }
}
```

### 3. Multi-Factor Authentication (MFA)

```typescript
@Injectable()
export class MfaService {
  constructor(
    private readonly usersService: UsersService,
    private readonly smsService: SmsService,
    private readonly emailService: EmailService,
  ) {}

  // TOTP (Time-based One-Time Password) setup
  async setupTOTP(userId: string): Promise<{ secret: string; qrCode: string }> {
    const secret = speakeasy.generateSecret({
      name: `YourApp (${user.email})`,
      issuer: 'YourApp',
      length: 32,
    });

    // Store secret temporarily (not yet verified)
    await this.usersService.updateMfaTempSecret(userId, secret.base32);

    const qrCodeUrl = speakeasy.otpauthURL({
      secret: secret.ascii,
      label: user.email,
      issuer: 'YourApp',
      encoding: 'ascii',
    });

    const qrCode = await QRCode.toDataURL(qrCodeUrl);

    return {
      secret: secret.base32,
      qrCode,
    };
  }

  async verifyTOTP(userId: string, token: string): Promise<boolean> {
    const user = await this.usersService.findById(userId);
    const secret = user.mfaSecret || user.mfaTempSecret;

    if (!secret) {
      throw new BadRequestException('MFA not set up');
    }

    const verified = speakeasy.totp.verify({
      secret,
      encoding: 'base32',
      token,
      window: 2, // Allow 2 time steps tolerance
    });

    if (verified && user.mfaTempSecret) {
      // First time verification - activate MFA
      await this.usersService.activateMfa(userId, user.mfaTempSecret);
    }

    return verified;
  }

  // SMS-based MFA
  async sendSmsCode(userId: string): Promise<void> {
    const user = await this.usersService.findById(userId);
    if (!user.phoneNumber) {
      throw new BadRequestException('Phone number not set');
    }

    const code = Math.floor(100000 + Math.random() * 900000).toString();
    const expiresAt = new Date(Date.now() + 5 * 60 * 1000); // 5 minutes

    await this.usersService.storeSmsCode(userId, code, expiresAt);
    await this.smsService.sendCode(user.phoneNumber, code);
  }

  async verifySmsCode(userId: string, code: string): Promise<boolean> {
    const storedCode = await this.usersService.getSmsCode(userId);
    
    if (!storedCode || storedCode.expiresAt < new Date()) {
      throw new BadRequestException('Code expired or not found');
    }

    const verified = storedCode.code === code;
    
    if (verified) {
      await this.usersService.clearSmsCode(userId);
    }

    return verified;
  }
}

// MFA Guard
@Injectable()
export class MfaGuard implements CanActivate {
  constructor(
    private readonly mfaService: MfaService,
    private readonly reflector: Reflector,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const requiresMfa = this.reflector.getAllAndOverride<boolean>('requiresMfa', [
      context.getHandler(),
      context.getClass(),
    ]);

    if (!requiresMfa) {
      return true;
    }

    const request = context.switchToHttp().getRequest();
    const user = request.user;

    if (!user.mfaEnabled) {
      throw new UnauthorizedException('MFA is required but not set up');
    }

    // Check if MFA was already verified in this session
    if (request.session?.mfaVerified) {
      return true;
    }

    throw new UnauthorizedException('MFA verification required');
  }
}
```

## 🛡️ Input Validation & Sanitization

### 1. Comprehensive Input Validation

```typescript
// Custom validation decorators
export function IsStrongPassword() {
  return applyDecorators(
    IsString(),
    MinLength(8),
    MaxLength(128),
    Matches(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[!@#$%^&*(),.?":{}|<>])/, {
      message: 'Password must contain uppercase, lowercase, number and special character',
    }),
    Validate(IsNotCommonPasswordConstraint),
  );
}

@ValidatorConstraint({ name: 'isNotCommonPassword', async: false })
export class IsNotCommonPasswordConstraint implements ValidatorConstraintInterface {
  validate(password: string): boolean {
    const commonPasswords = [
      'password', '123456', 'password123', 'admin', 'qwerty',
      'letmein', 'welcome', '123456789', 'password1', 'abc123'
    ];
    return !commonPasswords.includes(password.toLowerCase());
  }

  defaultMessage(): string {
    return 'Password is too common';
  }
}

// Sanitization decorators
export function SanitizeHtml() {
  return Transform(({ value }) => {
    if (typeof value === 'string') {
      return DOMPurify.sanitize(value, { ALLOWED_TAGS: [] }); // Strip all HTML
    }
    return value;
  });
}

export function TrimAndLowercase() {
  return Transform(({ value }) => {
    if (typeof value === 'string') {
      return value.trim().toLowerCase();
    }
    return value;
  });
}

// Usage in DTOs
export class CreateUserDto {
  @ApiProperty()
  @IsEmail()
  @TrimAndLowercase()
  email: string;

  @ApiProperty()
  @IsStrongPassword()
  password: string;

  @ApiProperty()
  @IsString()
  @MinLength(2)
  @MaxLength(50)
  @Matches(/^[a-zA-Z\s]+$/, { message: 'Name can only contain letters and spaces' })
  @SanitizeHtml()
  firstName: string;

  @ApiProperty()
  @IsOptional()
  @IsString()
  @MaxLength(500)
  @SanitizeHtml()
  bio?: string;

  @ApiProperty()
  @IsOptional()
  @IsPhoneNumber()
  phoneNumber?: string;
}
```

### 2. SQL Injection Prevention

```typescript
// Always use parameterized queries with TypeORM
@Injectable()
export class UserRepository {
  constructor(
    @InjectRepository(User)
    private readonly userRepo: Repository<User>,
  ) {}

  // Good: Parameterized query
  async findByEmailAndStatus(email: string, status: UserStatus): Promise<User[]> {
    return this.userRepo
      .createQueryBuilder('user')
      .where('user.email = :email AND user.status = :status', { email, status })
      .getMany();
  }

  // Good: Using QueryBuilder with parameters
  async searchUsers(searchTerm: string, limit: number = 10): Promise<User[]> {
    return this.userRepo
      .createQueryBuilder('user')
      .where('user.firstName ILIKE :search OR user.lastName ILIKE :search', {
        search: `%${searchTerm}%`,
      })
      .orderBy('user.createdAt', 'DESC')
      .limit(limit)
      .getMany();
  }

  // Bad: String concatenation (DON'T DO THIS)
  // async badExample(email: string): Promise<User[]> {
  //   return this.userRepo.query(`SELECT * FROM users WHERE email = '${email}'`);
  // }
}

// Custom validation pipe for additional security
@Injectable()
export class SqlInjectionValidationPipe implements PipeTransform {
  transform(value: any): any {
    if (typeof value === 'string') {
      // Check for common SQL injection patterns
      const sqlInjectionPatterns = [
        /(\%27)|(\')|(\-\-)|(\%23)|(#)/i,
        /((\%3D)|(=))[^\n]*((\%27)|(\')|(\-\-)|(\%3B)|(;))/i,
        /\w*((\%27)|(\'))((\%6F)|o|(\%4F))((\%72)|r|(\%52))/i,
        /((\%27)|(\'))union/i,
      ];

      const containsSqlInjection = sqlInjectionPatterns.some(pattern => 
        pattern.test(value)
      );

      if (containsSqlInjection) {
        throw new BadRequestException('Invalid input detected');
      }
    }

    return value;
  }
}
```

## 🔒 Data Protection & Privacy

### 1. Data Encryption

```typescript
@Injectable()
export class EncryptionService {
  private readonly algorithm = 'aes-256-gcm';
  private readonly keyLength = 32;
  private readonly ivLength = 16;
  private readonly tagLength = 16;

  constructor(private readonly configService: ConfigService) {}

  private getKey(): Buffer {
    const key = this.configService.get('ENCRYPTION_KEY');
    if (!key) {
      throw new Error('ENCRYPTION_KEY not set');
    }
    return Buffer.from(key, 'hex');
  }

  encrypt(text: string): string {
    const iv = crypto.randomBytes(this.ivLength);
    const cipher = crypto.createCipher(this.algorithm, this.getKey());
    cipher.setAAD(Buffer.from('additional authenticated data'));

    let encrypted = cipher.update(text, 'utf8', 'hex');
    encrypted += cipher.final('hex');

    const tag = cipher.getAuthTag();

    return iv.toString('hex') + ':' + tag.toString('hex') + ':' + encrypted;
  }

  decrypt(encryptedData: string): string {
    const [ivHex, tagHex, encrypted] = encryptedData.split(':');
    
    const iv = Buffer.from(ivHex, 'hex');
    const tag = Buffer.from(tagHex, 'hex');
    
    const decipher = crypto.createDecipher(this.algorithm, this.getKey());
    decipher.setAAD(Buffer.from('additional authenticated data'));
    decipher.setAuthTag(tag);

    let decrypted = decipher.update(encrypted, 'hex', 'utf8');
    decrypted += decipher.final('utf8');

    return decrypted;
  }
}

// Encryption transformer for TypeORM
export class EncryptionTransformer implements ValueTransformer {
  constructor(private readonly encryptionService: EncryptionService) {}

  to(value: string): string {
    return value ? this.encryptionService.encrypt(value) : value;
  }

  from(value: string): string {
    return value ? this.encryptionService.decrypt(value) : value;
  }
}

// Usage in entity
@Entity()
export class User {
  @Column({
    transformer: new EncryptionTransformer(new EncryptionService()),
  })
  ssn: string; // Social Security Number - encrypted

  @Column({
    transformer: new EncryptionTransformer(new EncryptionService()),
  })
  creditCardNumber: string; // Credit card - encrypted
}
```

### 2. Personal Data Handling (GDPR Compliance)

```typescript
@Injectable()
export class DataProtectionService {
  constructor(
    private readonly userRepository: UserRepository,
    private readonly auditService: AuditService,
  ) {}

  // Data anonymization
  async anonymizeUser(userId: string): Promise<void> {
    const user = await this.userRepository.findById(userId);
    if (!user) {
      throw new NotFoundException('User not found');
    }

    const anonymizedData = {
      firstName: 'Anonymous',
      lastName: 'User',
      email: `anonymous-${userId}@deleted.com`,
      phoneNumber: null,
      address: null,
      dateOfBirth: null,
      // Keep account creation date for analytics
      isAnonymized: true,
      anonymizedAt: new Date(),
    };

    await this.userRepository.update(userId, anonymizedData);
    await this.auditService.log('USER_ANONYMIZED', userId);
  }

  // Data export (GDPR right to data portability)
  async exportUserData(userId: string): Promise<UserDataExport> {
    const user = await this.userRepository.findById(userId);
    const orders = await this.ordersService.findByUserId(userId);
    const preferences = await this.preferencesService.findByUserId(userId);

    return {
      personalData: {
        firstName: user.firstName,
        lastName: user.lastName,
        email: user.email,
        phoneNumber: user.phoneNumber,
        dateOfBirth: user.dateOfBirth,
        createdAt: user.createdAt,
      },
      orderHistory: orders.map(order => ({
        id: order.id,
        date: order.createdAt,
        total: order.total,
        items: order.items.map(item => ({
          name: item.name,
          quantity: item.quantity,
          price: item.price,
        })),
      })),
      preferences: preferences,
      exportedAt: new Date(),
    };
  }

  // Data deletion (GDPR right to erasure)
  async deleteUserData(userId: string, reason: string): Promise<void> {
    // 1. Check if user can be deleted (e.g., no pending orders)
    const pendingOrders = await this.ordersService.findPendingByUserId(userId);
    if (pendingOrders.length > 0) {
      throw new BadRequestException('Cannot delete user with pending orders');
    }

    // 2. Soft delete related data
    await this.ordersService.softDeleteByUserId(userId);
    await this.preferencesService.deleteByUserId(userId);

    // 3. Delete user account
    await this.userRepository.softDelete(userId);

    // 4. Audit trail
    await this.auditService.log('USER_DELETED', userId, { reason });
  }
}

// GDPR controller
@Controller('data-protection')
@UseGuards(JwtAuthGuard)
export class DataProtectionController {
  constructor(private readonly dataProtectionService: DataProtectionService) {}

  @Get('export')
  @ApiOperation({ summary: 'Export user data (GDPR compliance)' })
  async exportData(@GetUser() user: User): Promise<UserDataExport> {
    return this.dataProtectionService.exportUserData(user.id);
  }

  @Delete('delete-account')
  @ApiOperation({ summary: 'Delete user account and data' })
  async deleteAccount(
    @GetUser() user: User,
    @Body() deleteAccountDto: DeleteAccountDto,
  ): Promise<void> {
    // Verify password for sensitive operation
    const isValidPassword = await user.validatePassword(deleteAccountDto.password);
    if (!isValidPassword) {
      throw new UnauthorizedException('Invalid password');
    }

    await this.dataProtectionService.deleteUserData(user.id, deleteAccountDto.reason);
  }
}
```

## 🚫 Rate Limiting & DDoS Protection

### 1. Advanced Rate Limiting

```typescript
// Custom rate limiting strategy
@Injectable()
export class CustomThrottlerGuard extends ThrottlerGuard {
  async handleRequest(
    context: ExecutionContext,
    limit: number,
    ttl: number,
    throttler: ThrottlerOptions,
  ): Promise<boolean> {
    const request = context.switchToHttp().getRequest();
    
    // Different limits for authenticated vs anonymous users
    const user = request.user;
    if (user) {
      // Authenticated users get higher limits
      limit = limit * 2;
    }

    // IP-based tracking
    const key = this.generateKey(context, request.ip, throttler.name);
    
    // Check rate limit
    const { totalHits, timeToExpire } = await this.storageService.increment(key, ttl);

    if (totalHits > limit) {
      // Log potential abuse
      this.logger.warn(`Rate limit exceeded for IP: ${request.ip}`, {
        ip: request.ip,
        userAgent: request.get('User-Agent'),
        totalHits,
        limit,
      });

      throw new ThrottlerException();
    }

    return true;
  }
}

// Progressive rate limiting
@Injectable()
export class ProgressiveRateLimitGuard implements CanActivate {
  constructor(
    private readonly redis: Redis,
    private readonly logger: Logger,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest();
    const ip = request.ip;
    const key = `rate_limit:${ip}`;

    // Get current attempt count
    const attempts = await this.redis.incr(key);
    
    if (attempts === 1) {
      // First attempt - set 1 hour expiry
      await this.redis.expire(key, 3600);
    }

    // Progressive delays
    let delay = 0;
    if (attempts > 5) delay = 1000; // 1 second
    if (attempts > 10) delay = 5000; // 5 seconds  
    if (attempts > 20) delay = 30000; // 30 seconds
    if (attempts > 50) delay = 300000; // 5 minutes

    if (delay > 0) {
      this.logger.warn(`Progressive rate limit applied for IP: ${ip}`, {
        attempts,
        delay,
      });
      
      await new Promise(resolve => setTimeout(resolve, delay));
    }

    // Block after too many attempts
    if (attempts > 100) {
      this.logger.error(`IP blocked due to excessive requests: ${ip}`, {
        attempts,
      });
      throw new TooManyRequestsException('Too many requests');
    }

    return true;
  }
}
```

### 2. DDoS Protection Strategies

```typescript
// IP whitelist/blacklist service
@Injectable()
export class IpFilterService {
  private readonly whitelist = new Set<string>();
  private readonly blacklist = new Set<string>();

  constructor(
    private readonly redis: Redis,
    private readonly configService: ConfigService,
  ) {
    this.loadIpLists();
  }

  private async loadIpLists(): Promise<void> {
    // Load from database or configuration
    const whitelistedIps = this.configService.get('WHITELISTED_IPS', '').split(',');
    const blacklistedIps = await this.redis.smembers('blacklisted_ips');

    whitelistedIps.forEach(ip => ip && this.whitelist.add(ip.trim()));
    blacklistedIps.forEach(ip => this.blacklist.add(ip));
  }

  isWhitelisted(ip: string): boolean {
    return this.whitelist.has(ip);
  }

  isBlacklisted(ip: string): boolean {
    return this.blacklist.has(ip);
  }

  async addToBlacklist(ip: string, ttl: number = 3600): Promise<void> {
    this.blacklist.add(ip);
    await this.redis.sadd('blacklisted_ips', ip);
    await this.redis.expire(`blacklisted_ips:${ip}`, ttl);
  }

  async removeFromBlacklist(ip: string): Promise<void> {
    this.blacklist.delete(ip);
    await this.redis.srem('blacklisted_ips', ip);
  }
}

// DDoS protection middleware
@Injectable()
export class DdosProtectionMiddleware implements NestMiddleware {
  constructor(
    private readonly ipFilterService: IpFilterService,
    private readonly redis: Redis,
    private readonly logger: Logger,
  ) {}

  async use(req: Request, res: Response, next: NextFunction) {
    const ip = req.ip;
    const userAgent = req.get('User-Agent') || '';

    // Check blacklist
    if (this.ipFilterService.isBlacklisted(ip)) {
      this.logger.warn(`Blocked request from blacklisted IP: ${ip}`);
      return res.status(403).json({ message: 'Access denied' });
    }

    // Skip checks for whitelisted IPs
    if (this.ipFilterService.isWhitelisted(ip)) {
      return next();
    }

    // Detect suspicious patterns
    const suspiciousPatterns = [
      /bot|crawler|spider|scraper/i,
      /curl|wget|python|php/i,
      /sqlmap|nikto|nmap/i,
    ];

    const isSuspicious = suspiciousPatterns.some(pattern => 
      pattern.test(userAgent)
    );

    if (isSuspicious) {
      const key = `suspicious:${ip}`;
      const count = await this.redis.incr(key);
      
      if (count === 1) {
        await this.redis.expire(key, 3600); // 1 hour
      }

      if (count > 10) {
        await this.ipFilterService.addToBlacklist(ip, 86400); // 24 hours
        this.logger.error(`Auto-blacklisted suspicious IP: ${ip}`, {
          userAgent,
          count,
        });
        return res.status(403).json({ message: 'Access denied' });
      }
    }

    // Request size check
    const contentLength = parseInt(req.get('Content-Length') || '0');
    const maxSize = 10 * 1024 * 1024; // 10MB

    if (contentLength > maxSize) {
      this.logger.warn(`Large request from IP: ${ip}`, { contentLength });
      return res.status(413).json({ message: 'Request too large' });
    }

    next();
  }
}
```

## 🔍 Security Monitoring & Audit

### 1. Security Event Logging

```typescript
@Injectable()
export class SecurityAuditService {
  constructor(
    private readonly logger: Logger,
    private readonly redis: Redis,
  ) {}

  async logSecurityEvent(event: SecurityEvent): Promise<void> {
    const logEntry = {
      timestamp: new Date().toISOString(),
      event: event.type,
      severity: event.severity,
      ip: event.ip,
      userId: event.userId,
      userAgent: event.userAgent,
      details: event.details,
      sessionId: event.sessionId,
    };

    // Log to application logs
    this.logger.log(JSON.stringify(logEntry), 'SecurityAudit');

    // Store in Redis for real-time monitoring
    await this.redis.lpush('security_events', JSON.stringify(logEntry));
    await this.redis.ltrim('security_events', 0, 1000); // Keep last 1000 events

    // Trigger alerts for high severity events
    if (event.severity === 'HIGH' || event.severity === 'CRITICAL') {
      await this.triggerSecurityAlert(logEntry);
    }
  }

  private async triggerSecurityAlert(event: any): Promise<void> {
    // Send to monitoring system (Slack, email, etc.)
    this.logger.error('SECURITY ALERT', event);
    
    // Could integrate with external alerting services
    // await this.slackService.sendAlert(event);
    // await this.emailService.sendSecurityAlert(event);
  }

  // Log failed login attempts
  async logFailedLogin(ip: string, email: string, userAgent: string): Promise<void> {
    await this.logSecurityEvent({
      type: 'FAILED_LOGIN',
      severity: 'MEDIUM',
      ip,
      userAgent,
      details: { email, attemptedEmail: email },
    });

    // Track failed attempts per IP
    const key = `failed_logins:${ip}`;
    const attempts = await this.redis.incr(key);
    
    if (attempts === 1) {
      await this.redis.expire(key, 3600); // 1 hour window
    }

    // Auto-ban after too many failures
    if (attempts >= 10) {
      await this.logSecurityEvent({
        type: 'IP_AUTO_BANNED',
        severity: 'HIGH',
        ip,
        details: { attempts, reason: 'Excessive failed login attempts' },
      });
    }
  }

  // Log suspicious activities
  async logSuspiciousActivity(
    type: string,
    userId: string,
    ip: string,
    details: any,
  ): Promise<void> {
    await this.logSecurityEvent({
      type: `SUSPICIOUS_${type.toUpperCase()}`,
      severity: 'MEDIUM',
      ip,
      userId,
      details,
    });
  }
}

// Security audit interceptor
@Injectable()
export class SecurityAuditInterceptor implements NestInterceptor {
  constructor(private readonly securityAudit: SecurityAuditService) {}

  intercept(context: ExecutionContext, next: CallHandler): Observable<any> {
    const request = context.switchToHttp().getRequest();
    const response = context.switchToHttp().getResponse();

    return next.handle().pipe(
      tap(() => {
        // Log successful sensitive operations
        const sensitiveEndpoints = [
          '/auth/login',
          '/auth/register',
          '/users/change-password',
          '/admin/',
        ];

        const isSensitive = sensitiveEndpoints.some(endpoint =>
          request.url.includes(endpoint)
        );

        if (isSensitive && response.statusCode < 400) {
          this.securityAudit.logSecurityEvent({
            type: 'SENSITIVE_OPERATION',
            severity: 'LOW',
            ip: request.ip,
            userId: request.user?.id,
            userAgent: request.get('User-Agent'),
            details: {
              method: request.method,
              url: request.url,
              statusCode: response.statusCode,
            },
          });
        }
      }),
      catchError((error) => {
        // Log failed operations
        this.securityAudit.logSecurityEvent({
          type: 'OPERATION_FAILED',
          severity: 'MEDIUM',
          ip: request.ip,
          userId: request.user?.id,
          userAgent: request.get('User-Agent'),
          details: {
            method: request.method,
            url: request.url,
            error: error.message,
          },
        });

        throw error;
      }),
    );
  }
}
```

## 🛡️ Environment & Configuration Security

### 1. Secure Configuration Management

```typescript
// Configuration validation schema
const configValidationSchema = Joi.object({
  NODE_ENV: Joi.string().valid('development', 'production', 'test').required(),
  PORT: Joi.number().default(3000),
  
  // Database
  DB_HOST: Joi.string().required(),
  DB_PORT: Joi.number().default(5432),
  DB_NAME: Joi.string().required(),
  DB_USERNAME: Joi.string().required(),
  DB_PASSWORD: Joi.string().min(8).required(),
  
  // JWT secrets (must be strong in production)
  JWT_SECRET: Joi.string().min(32).required(),
  JWT_REFRESH_SECRET: Joi.string().min(32).required(),
  
  // Encryption
  ENCRYPTION_KEY: Joi.string().length(64).pattern(/^[0-9a-f]+$/i).required(),
  
  // External services
  REDIS_URL: Joi.string().uri().required(),
  EMAIL_API_KEY: Joi.string().required(),
  
  // Security settings
  CORS_ORIGINS: Joi.string().required(),
  RATE_LIMIT_TTL: Joi.number().default(60),
  RATE_LIMIT_MAX: Joi.number().default(100),
});

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      validationSchema: configValidationSchema,
      validationOptions: {
        allowUnknown: true,
        abortEarly: false,
      },
    }),
  ],
})
export class AppModule {}

// Environment-specific security settings
@Injectable()
export class SecurityConfigService {
  constructor(private configService: ConfigService) {}

  getSecurityConfig() {
    const isProduction = this.configService.get('NODE_ENV') === 'production';
    
    return {
      cors: {
        origin: this.configService.get('CORS_ORIGINS').split(','),
        credentials: true,
        methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH'],
        allowedHeaders: ['Content-Type', 'Authorization'],
      },
      helmet: {
        contentSecurityPolicy: isProduction ? {
          directives: {
            defaultSrc: ["'self'"],
            styleSrc: ["'self'", "'unsafe-inline'"],
            scriptSrc: ["'self'"],
            imgSrc: ["'self'", "data:", "https:"],
          },
        } : false,
        hsts: isProduction ? {
          maxAge: 31536000,
          includeSubDomains: true,
          preload: true,
        } : false,
      },
      rateLimit: {
        ttl: this.configService.get('RATE_LIMIT_TTL'),
        limit: this.configService.get('RATE_LIMIT_MAX'),
      },
    };
  }

  // Validate secrets strength in production
  validateSecrets(): void {
    const isProduction = this.configService.get('NODE_ENV') === 'production';
    
    if (isProduction) {
      const jwtSecret = this.configService.get('JWT_SECRET');
      const refreshSecret = this.configService.get('JWT_REFRESH_SECRET');
      
      if (jwtSecret.length < 32) {
        throw new Error('JWT_SECRET must be at least 32 characters in production');
      }
      
      if (refreshSecret.length < 32) {
        throw new Error('JWT_REFRESH_SECRET must be at least 32 characters in production');
      }
      
      // Check for common weak secrets
      const weakSecrets = ['secret', 'password', 'admin', 'jwt_secret'];
      if (weakSecrets.some(weak => jwtSecret.toLowerCase().includes(weak))) {
        throw new Error('JWT_SECRET appears to be weak');
      }
    }
  }
}
```

## 🔗 Next Steps

1. **Explore** [Comparison Analysis](./comparison-analysis.md) for different security approaches
2. **Use** [Template Examples](./template-examples.md) for secure project setup
3. **Review** [Implementation Guide](./implementation-guide.md) for putting these practices into action

---

## 🔗 Navigation

**Previous:** [Best Practices](./best-practices.md)  
**Next:** [Comparison Analysis](./comparison-analysis.md)

---

*Last updated: July 27, 2025*