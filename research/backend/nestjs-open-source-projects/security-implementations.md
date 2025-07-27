# Security Implementations: NestJS Best Practices

This document examines comprehensive security implementations found in production NestJS applications, providing practical examples and best practices for building secure applications.

## 🔐 Authentication Strategies

### 1. JWT Authentication with Refresh Tokens

Most production NestJS applications implement JWT authentication with refresh token rotation for enhanced security.

#### Implementation from Brocoders Boilerplate

```typescript
// auth.service.ts
@Injectable()
export class AuthService {
  constructor(
    private readonly jwtService: JwtService,
    private readonly usersService: UsersService,
    private readonly sessionService: SessionService,
  ) {}

  async login(loginDto: AuthEmailLoginDto): Promise<LoginResponseType> {
    const user = await this.usersService.findOne({
      email: loginDto.email,
    });

    if (!user || !await bcrypt.compare(loginDto.password, user.password)) {
      throw new UnprocessableEntityException({
        status: HttpStatus.UNPROCESSABLE_ENTITY,
        errors: {
          email: 'notFound',
        },
      });
    }

    const session = await this.sessionService.create({
      userId: user.id,
    });

    const { token, refreshToken, tokenExpires } = await this.getTokensData({
      id: user.id,
      role: user.role,
      sessionId: session.id,
    });

    return {
      token,
      refreshToken,
      tokenExpires,
      user,
    };
  }

  async getTokensData(data: {
    id: User['id'];
    role: User['role'];
    sessionId: Session['id'];
  }): Promise<{
    token: string;
    refreshToken: string;
    tokenExpires: number;
  }> {
    const tokenExpiresIn = this.configService.getOrThrow('auth.expires', {
      infer: true,
    });

    const tokenExpires = Date.now() + ms(tokenExpiresIn);

    const [token, refreshToken] = await Promise.all([
      await this.jwtService.signAsync(
        {
          id: data.id,
          role: data.role,
          sessionId: data.sessionId,
        },
        {
          secret: this.configService.getOrThrow('auth.secret', { infer: true }),
          expiresIn: tokenExpiresIn,
        },
      ),
      await this.jwtService.signAsync(
        {
          sessionId: data.sessionId,
        },
        {
          secret: this.configService.getOrThrow('auth.refreshSecret', {
            infer: true,
          }),
          expiresIn: this.configService.getOrThrow('auth.refreshExpires', {
            infer: true,
          }),
        },
      ),
    ]);

    return {
      token,
      refreshToken,
      tokenExpires,
    };
  }

  async refreshToken(
    data: Pick<RefreshResponseType, 'token' | 'refreshToken'>,
  ): Promise<Omit<LoginResponseType, 'user'>> {
    let payload: JwtRefreshPayloadType;

    try {
      payload = this.jwtService.verify(data.refreshToken, {
        secret: this.configService.getOrThrow('auth.refreshSecret', {
          infer: true,
        }),
      });
    } catch {
      throw new UnauthorizedException();
    }

    const session = await this.sessionService.findOne({
      where: {
        id: payload.sessionId,
      },
    });

    if (!session) {
      throw new UnauthorizedException();
    }

    const { token, refreshToken, tokenExpires } = await this.getTokensData({
      id: session.user.id,
      role: session.user.role,
      sessionId: session.id,
    });

    return {
      token,
      refreshToken,
      tokenExpires,
    };
  }
}
```

#### JWT Strategy Implementation

```typescript
// jwt.strategy.ts
@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy, 'jwt') {
  constructor(
    private configService: ConfigService<AllConfigType>,
    private sessionService: SessionService,
  ) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      secretOrKey: configService.getOrThrow('auth.secret', { infer: true }),
    });
  }

  public async validate(payload: JwtPayloadType): Promise<User> {
    if (!payload.id) {
      throw new UnauthorizedException();
    }

    const session = await this.sessionService.findOne({
      where: {
        id: payload.sessionId,
      },
      relations: ['user'],
    });

    if (!session) {
      throw new UnauthorizedException();
    }

    return session.user;
  }
}
```

#### Session Management

```typescript
// session.service.ts
@Injectable()
export class SessionService {
  constructor(
    @InjectRepository(Session)
    private sessionRepository: Repository<Session>,
  ) {}

  async create(data: { userId: User['id'] }): Promise<Session> {
    return this.sessionRepository.save(
      this.sessionRepository.create({
        user: { id: data.userId },
      }),
    );
  }

  async findOne(options: FindOneOptions<Session>): Promise<Session> {
    return this.sessionRepository.findOne(options);
  }

  async softDelete(criteria: {
    id: Session['id'];
    user: Pick<User, 'id'>;
  }): Promise<void> {
    await this.sessionRepository.softDelete({
      id: criteria.id,
      user: {
        id: criteria.user.id,
      },
    });
  }

  async deleteAll(criteria: { user: Pick<User, 'id'> }): Promise<void> {
    await this.sessionRepository.delete({
      user: {
        id: criteria.user.id,
      },
    });
  }
}
```

### 2. OAuth Social Authentication

Production applications implement multiple OAuth providers for better user experience.

#### Google OAuth Strategy

```typescript
// google.strategy.ts
@Injectable()
export class GoogleStrategy extends PassportStrategy(Strategy, 'google') {
  constructor(
    private configService: ConfigService<AllConfigType>,
    private authService: AuthService,
  ) {
    super({
      clientID: configService.getOrThrow('google.clientId', { infer: true }),
      clientSecret: configService.getOrThrow('google.clientSecret', {
        infer: true,
      }),
      callbackURL: configService.getOrThrow('google.callbackURL', {
        infer: true,
      }),
      scope: ['email', 'profile'],
    });
  }

  async validate(
    accessToken: string,
    refreshToken: string,
    profile: any,
    done: VerifyCallback,
  ): Promise<any> {
    const { name, emails, photos } = profile;

    const user = {
      provider: 'google',
      socialId: profile.id,
      email: emails[0].value,
      firstName: name.givenName,
      lastName: name.familyName,
      picture: photos[0].value,
    };

    done(null, user);
  }
}
```

#### Facebook OAuth Strategy

```typescript
// facebook.strategy.ts
@Injectable()
export class FacebookStrategy extends PassportStrategy(Strategy, 'facebook') {
  constructor(
    private configService: ConfigService<AllConfigType>,
    private authService: AuthService,
  ) {
    super({
      clientID: configService.getOrThrow('facebook.appId', { infer: true }),
      clientSecret: configService.getOrThrow('facebook.appSecret', {
        infer: true,
      }),
      callbackURL: configService.getOrThrow('facebook.callbackURL', {
        infer: true,
      }),
      scope: 'email',
      profileFields: ['emails', 'name'],
    });
  }

  async validate(
    accessToken: string,
    refreshToken: string,
    profile: any,
    done: VerifyCallback,
  ): Promise<any> {
    const { name, emails } = profile;

    const user = {
      provider: 'facebook',
      socialId: profile.id,
      email: emails[0].value,
      firstName: name.givenName,
      lastName: name.familyName,
    };

    done(null, user);
  }
}
```

### 3. Multi-Factor Authentication (MFA)

Advanced applications implement TOTP-based MFA for enhanced security.

#### TOTP Implementation

```typescript
// mfa.service.ts
@Injectable()
export class MfaService {
  constructor(
    private readonly usersService: UsersService,
    private readonly configService: ConfigService,
  ) {}

  generateSecret(): { secret: string; qrCode: string } {
    const secret = authenticator.generateSecret();
    const appName = this.configService.get('app.name');
    
    const qrCode = authenticator.keyuri(
      user.email,
      appName,
      secret,
    );

    return { secret, qrCode };
  }

  async enableMfa(userId: string, token: string): Promise<void> {
    const user = await this.usersService.findOne({ id: userId });
    
    if (!user.mfaSecret) {
      throw new BadRequestException('MFA secret not generated');
    }

    const isValid = authenticator.verify({
      token,
      secret: user.mfaSecret,
    });

    if (!isValid) {
      throw new BadRequestException('Invalid MFA token');
    }

    await this.usersService.update(userId, {
      mfaEnabled: true,
    });
  }

  async verifyMfaToken(userId: string, token: string): Promise<boolean> {
    const user = await this.usersService.findOne({ id: userId });
    
    if (!user.mfaEnabled || !user.mfaSecret) {
      return false;
    }

    return authenticator.verify({
      token,
      secret: user.mfaSecret,
      window: 2, // Allow 2 time windows for clock drift
    });
  }

  async generateBackupCodes(userId: string): Promise<string[]> {
    const codes = Array.from({ length: 10 }, () => 
      crypto.randomBytes(4).toString('hex').toUpperCase()
    );

    const hashedCodes = await Promise.all(
      codes.map(code => bcrypt.hash(code, 12))
    );

    await this.usersService.update(userId, {
      mfaBackupCodes: hashedCodes,
    });

    return codes;
  }
}
```

## 🛡️ Authorization Patterns

### 1. Role-Based Access Control (RBAC)

Most enterprise applications implement sophisticated RBAC systems.

#### Role and Permission Entities

```typescript
// role.entity.ts
@Entity('roles')
export class Role {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ unique: true })
  name: string;

  @Column({ nullable: true })
  description: string;

  @ManyToMany(() => Permission, permission => permission.roles)
  @JoinTable()
  permissions: Permission[];

  @OneToMany(() => User, user => user.role)
  users: User[];
}

// permission.entity.ts
@Entity('permissions')
export class Permission {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ unique: true })
  name: string;

  @Column({ nullable: true })
  description: string;

  @Column()
  resource: string;

  @Column()
  action: string;

  @ManyToMany(() => Role, role => role.permissions)
  roles: Role[];
}
```

#### Permission Guard Implementation

```typescript
// permissions.guard.ts
@Injectable()
export class PermissionsGuard implements CanActivate {
  constructor(private reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const requiredPermissions = this.reflector.getAllAndOverride<string[]>(
      PERMISSIONS_KEY,
      [context.getHandler(), context.getClass()],
    );

    if (!requiredPermissions) {
      return true;
    }

    const { user } = context.switchToHttp().getRequest();
    
    if (!user || !user.role) {
      return false;
    }

    return this.hasRequiredPermissions(user.role.permissions, requiredPermissions);
  }

  private hasRequiredPermissions(
    userPermissions: Permission[],
    requiredPermissions: string[],
  ): boolean {
    const userPermissionNames = userPermissions.map(p => p.name);
    
    return requiredPermissions.every(permission =>
      userPermissionNames.includes(permission)
    );
  }
}

// permissions.decorator.ts
export const PERMISSIONS_KEY = 'permissions';
export const RequirePermissions = (...permissions: string[]) =>
  SetMetadata(PERMISSIONS_KEY, permissions);

// Usage in controllers
@Controller('users')
export class UsersController {
  @Get()
  @RequirePermissions('users:read')
  @UseGuards(JwtAuthGuard, PermissionsGuard)
  async findAll(): Promise<User[]> {
    return this.usersService.findAll();
  }

  @Post()
  @RequirePermissions('users:create')
  @UseGuards(JwtAuthGuard, PermissionsGuard)
  async create(@Body() createUserDto: CreateUserDto): Promise<User> {
    return this.usersService.create(createUserDto);
  }
}
```

### 2. Resource-Based Authorization

For applications requiring fine-grained access control, resource-based authorization is implemented.

#### Resource Guard Implementation

```typescript
// resource.guard.ts
@Injectable()
export class ResourceGuard implements CanActivate {
  constructor(
    private reflector: Reflector,
    private moduleRef: ModuleRef,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const resourceConfig = this.reflector.get<ResourceConfig>(
      RESOURCE_KEY,
      context.getHandler(),
    );

    if (!resourceConfig) {
      return true;
    }

    const request = context.switchToHttp().getRequest();
    const { user, params } = request;

    if (!user) {
      return false;
    }

    // Get resource service dynamically
    const service = this.moduleRef.get(resourceConfig.service, { strict: false });
    const resource = await service.findOne(params[resourceConfig.param]);

    if (!resource) {
      throw new NotFoundException();
    }

    // Check ownership or permissions
    return this.checkResourceAccess(user, resource, resourceConfig);
  }

  private checkResourceAccess(
    user: User,
    resource: any,
    config: ResourceConfig,
  ): boolean {
    // Check if user owns the resource
    if (config.ownerField && resource[config.ownerField] === user.id) {
      return true;
    }

    // Check admin permissions
    if (user.role?.permissions?.some(p => p.name === config.adminPermission)) {
      return true;
    }

    // Check specific resource permissions
    return user.role?.permissions?.some(p => 
      p.name === config.permission && 
      p.resource === config.resource
    );
  }
}

// Usage
@Get(':id')
@ResourceProtected({
  service: ArticlesService,
  param: 'id',
  ownerField: 'authorId',
  permission: 'articles:read',
  adminPermission: 'articles:admin',
})
@UseGuards(JwtAuthGuard, ResourceGuard)
async findOne(@Param('id') id: string): Promise<Article> {
  return this.articlesService.findOne(id);
}
```

## 🔒 Input Validation & Sanitization

### 1. Comprehensive DTO Validation

Production applications use extensive DTO validation to prevent injection attacks and ensure data integrity.

#### Advanced Validation Patterns

```typescript
// create-user.dto.ts
export class CreateUserDto {
  @ApiProperty({ example: 'user@example.com' })
  @IsEmail()
  @IsNotEmpty()
  @Transform(({ value }) => value?.toLowerCase()?.trim())
  @IsNotSameAsOtherProperty('firstName')
  email: string;

  @ApiProperty({ example: 'password123' })
  @IsString()
  @MinLength(8)
  @MaxLength(128)
  @Matches(
    /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]/,
    {
      message: 'Password must contain at least one uppercase letter, one lowercase letter, one number and one special character',
    },
  )
  password: string;

  @ApiProperty({ example: 'John' })
  @IsString()
  @IsNotEmpty()
  @MinLength(1)
  @MaxLength(100)
  @Transform(({ value }) => value?.trim())
  @Matches(/^[a-zA-ZÀ-ÿ\s]*$/, {
    message: 'First name can only contain letters and spaces',
  })
  firstName: string;

  @ApiProperty({ example: 'Doe' })
  @IsString()
  @IsNotEmpty()
  @MinLength(1)
  @MaxLength(100)
  @Transform(({ value }) => value?.trim())
  @Matches(/^[a-zA-ZÀ-ÿ\s]*$/, {
    message: 'Last name can only contain letters and spaces',
  })
  lastName: string;

  @ApiProperty({ example: '+1234567890' })
  @IsOptional()
  @IsPhoneNumber()
  @Transform(({ value }) => value?.replace(/\s/g, ''))
  phone?: string;

  @ApiProperty({ example: 'https://example.com/avatar.jpg' })
  @IsOptional()
  @IsUrl({
    protocols: ['https'],
    require_protocol: true,
  })
  @MaxLength(500)
  avatar?: string;

  @ApiProperty({ example: ['en', 'es'] })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(5)
  @IsString({ each: true })
  @IsIn(['en', 'es', 'fr', 'de', 'it'], { each: true })
  languages?: string[];
}

// Custom validation decorator
export function IsNotSameAsOtherProperty(
  property: string,
  validationOptions?: ValidationOptions,
) {
  return function (object: any, propertyName: string) {
    registerDecorator({
      name: 'isNotSameAsOtherProperty',
      target: object.constructor,
      propertyName: propertyName,
      constraints: [property],
      options: validationOptions,
      validator: {
        validate(value: any, args: ValidationArguments) {
          const [relatedPropertyName] = args.constraints;
          const relatedValue = (args.object as any)[relatedPropertyName];
          return value !== relatedValue;
        },
        defaultMessage(args: ValidationArguments) {
          const [relatedPropertyName] = args.constraints;
          return `${args.property} cannot be the same as ${relatedPropertyName}`;
        },
      },
    });
  };
}
```

#### Global Validation Pipe Configuration

```typescript
// main.ts
async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  app.useGlobalPipes(
    new ValidationPipe({
      transform: true,
      whitelist: true,
      forbidNonWhitelisted: true,
      transformOptions: {
        enableImplicitConversion: true,
      },
      exceptionFactory: (errors: ValidationError[]) => {
        const messages = errors.map(error => {
          return {
            property: error.property,
            constraints: error.constraints,
            children: error.children?.map(child => ({
              property: child.property,
              constraints: child.constraints,
            })),
          };
        });
        return new BadRequestException({
          statusCode: HttpStatus.BAD_REQUEST,
          message: 'Validation failed',
          errors: messages,
        });
      },
    }),
  );

  await app.listen(3000);
}
```

### 2. SQL Injection Prevention

Production applications use parameterized queries and ORM features to prevent SQL injection.

#### Safe Query Patterns with TypeORM

```typescript
// users.service.ts
@Injectable()
export class UsersService {
  constructor(
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
  ) {}

  // Safe: Using parameterized queries
  async findByEmailSafe(email: string): Promise<User | null> {
    return this.userRepository.findOne({
      where: { email },
      relations: ['role', 'role.permissions'],
    });
  }

  // Safe: Using query builder with parameters
  async searchUsersSafe(searchTerm: string, page: number = 1): Promise<User[]> {
    return this.userRepository
      .createQueryBuilder('user')
      .leftJoinAndSelect('user.role', 'role')
      .where('user.firstName ILIKE :search', { search: `%${searchTerm}%` })
      .orWhere('user.lastName ILIKE :search', { search: `%${searchTerm}%` })
      .orWhere('user.email ILIKE :search', { search: `%${searchTerm}%` })
      .skip((page - 1) * 10)
      .take(10)
      .getMany();
  }

  // Safe: Raw query with proper parameterization
  async getUserStatsSafe(userId: string): Promise<UserStats> {
    const result = await this.userRepository.query(
      `
      SELECT 
        COUNT(DISTINCT a.id) as article_count,
        COUNT(DISTINCT c.id) as comment_count,
        AVG(a.likes) as avg_likes
      FROM users u
      LEFT JOIN articles a ON u.id = a.author_id
      LEFT JOIN comments c ON u.id = c.author_id
      WHERE u.id = $1
      GROUP BY u.id
      `,
      [userId]
    );

    return result[0] || { article_count: 0, comment_count: 0, avg_likes: 0 };
  }
}
```

## 🚫 Rate Limiting & Throttling

Production applications implement comprehensive rate limiting to prevent abuse.

### Advanced Rate Limiting Implementation

```typescript
// rate-limit.config.ts
export const rateLimitConfig = {
  // Global rate limit
  global: {
    ttl: 60, // 1 minute
    limit: 1000, // 1000 requests per minute
  },
  // Auth endpoints
  auth: {
    ttl: 60, // 1 minute
    limit: 5, // 5 login attempts per minute
  },
  // Password reset
  passwordReset: {
    ttl: 3600, // 1 hour
    limit: 3, // 3 password reset attempts per hour
  },
  // Email verification
  emailVerification: {
    ttl: 300, // 5 minutes
    limit: 3, // 3 verification emails per 5 minutes
  },
  // API endpoints
  api: {
    ttl: 60, // 1 minute
    limit: 100, // 100 API calls per minute
  },
};

// Custom rate limit decorator
export const RateLimit = (
  ttl: number,
  limit: number,
  message?: string,
) => {
  return applyDecorators(
    UseGuards(ThrottlerGuard),
    Throttle(limit, ttl),
    SetMetadata('throttle_message', message),
  );
};

// Usage in controllers
@Controller('auth')
export class AuthController {
  @Post('login')
  @RateLimit(
    rateLimitConfig.auth.ttl,
    rateLimitConfig.auth.limit,
    'Too many login attempts. Please try again later.',
  )
  async login(@Body() loginDto: AuthEmailLoginDto): Promise<LoginResponseType> {
    return this.authService.login(loginDto);
  }

  @Post('forgot-password')
  @RateLimit(
    rateLimitConfig.passwordReset.ttl,
    rateLimitConfig.passwordReset.limit,
    'Too many password reset requests. Please try again later.',
  )
  async forgotPassword(
    @Body() forgotPasswordDto: AuthForgotPasswordDto,
  ): Promise<void> {
    return this.authService.forgotPassword(forgotPasswordDto.email);
  }
}
```

### IP-based Rate Limiting with Redis

```typescript
// redis-rate-limiter.service.ts
@Injectable()
export class RedisRateLimiterService {
  constructor(
    @InjectRedis() private readonly redis: Redis,
  ) {}

  async checkRateLimit(
    identifier: string,
    windowMs: number,
    maxRequests: number,
  ): Promise<{ allowed: boolean; remaining: number; resetTime: number }> {
    const key = `rate_limit:${identifier}`;
    const now = Date.now();
    const windowStart = now - windowMs;

    // Use Redis pipeline for atomic operations
    const pipeline = this.redis.pipeline();
    
    // Remove expired entries
    pipeline.zremrangebyscore(key, '-inf', windowStart);
    
    // Count current requests in window
    pipeline.zcard(key);
    
    // Add current request
    pipeline.zadd(key, now, `${now}-${Math.random()}`);
    
    // Set expiration
    pipeline.expire(key, Math.ceil(windowMs / 1000));

    const results = await pipeline.exec();
    const currentCount = results[1][1] as number;

    if (currentCount >= maxRequests) {
      return {
        allowed: false,
        remaining: 0,
        resetTime: now + windowMs,
      };
    }

    return {
      allowed: true,
      remaining: maxRequests - currentCount - 1,
      resetTime: now + windowMs,
    };
  }

  async checkBurstLimit(
    identifier: string,
    burstLimit: number,
    burstWindowMs: number,
  ): Promise<boolean> {
    const key = `burst_limit:${identifier}`;
    const now = Date.now();

    const count = await this.redis.incr(key);
    
    if (count === 1) {
      await this.redis.expire(key, Math.ceil(burstWindowMs / 1000));
    }

    return count <= burstLimit;
  }
}
```

## 🔐 Security Headers & CORS

### Comprehensive Security Configuration

```typescript
// security.config.ts
export function setupSecurity(app: INestApplication): void {
  // Helmet for security headers
  app.use(helmet({
    contentSecurityPolicy: {
      directives: {
        defaultSrc: ["'self'"],
        styleSrc: ["'self'", "'unsafe-inline'", 'https://fonts.googleapis.com'],
        fontSrc: ["'self'", 'https://fonts.gstatic.com'],
        imgSrc: ["'self'", 'data:', 'https:'],
        scriptSrc: ["'self'"],
        objectSrc: ["'none'"],
        upgradeInsecureRequests: [],
      },
    },
    crossOriginEmbedderPolicy: false,
    crossOriginResourcePolicy: { policy: 'cross-origin' },
    hsts: {
      maxAge: 31536000,
      includeSubDomains: true,
      preload: true,
    },
  }));

  // CORS configuration
  app.enableCors({
    origin: (origin, callback) => {
      const allowedOrigins = process.env.ALLOWED_ORIGINS?.split(',') || [];
      
      // Allow requests with no origin (mobile apps, curl, etc.)
      if (!origin) return callback(null, true);
      
      if (allowedOrigins.includes(origin)) {
        return callback(null, true);
      }
      
      // Development mode
      if (process.env.NODE_ENV === 'development') {
        return callback(null, true);
      }
      
      callback(new Error('Not allowed by CORS'));
    },
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
    allowedHeaders: [
      'Content-Type',
      'Authorization',
      'X-Requested-With',
      'Accept',
      'Origin',
      'X-CSRF-Token',
    ],
    exposedHeaders: ['X-Total-Count', 'X-Page-Count'],
  });

  // Additional security middleware
  app.use(compression());
  app.use(express.json({ limit: '10mb' }));
  app.use(express.urlencoded({ extended: true, limit: '10mb' }));
}
```

### CSRF Protection

```typescript
// csrf.config.ts
@Injectable()
export class CsrfMiddleware implements NestMiddleware {
  use(req: Request, res: Response, next: NextFunction) {
    // Skip CSRF for API routes with proper authentication
    if (req.path.startsWith('/api/') && req.headers.authorization) {
      return next();
    }

    // Implement CSRF protection for form-based requests
    const token = req.headers['x-csrf-token'] || req.body._csrf;
    const sessionToken = req.session?.csrfToken;

    if (req.method !== 'GET' && token !== sessionToken) {
      throw new ForbiddenException('Invalid CSRF token');
    }

    next();
  }
}
```

## 🔍 Security Monitoring & Logging

### Security Event Logging

```typescript
// security-logger.service.ts
@Injectable()
export class SecurityLoggerService {
  private readonly logger = new Logger(SecurityLoggerService.name);

  logAuthSuccess(userId: string, ip: string, userAgent: string): void {
    this.logger.log({
      event: 'AUTH_SUCCESS',
      userId,
      ip,
      userAgent,
      timestamp: new Date().toISOString(),
    });
  }

  logAuthFailure(email: string, ip: string, reason: string): void {
    this.logger.warn({
      event: 'AUTH_FAILURE',
      email,
      ip,
      reason,
      timestamp: new Date().toISOString(),
    });
  }

  logSuspiciousActivity(
    userId: string,
    activity: string,
    details: Record<string, any>,
  ): void {
    this.logger.warn({
      event: 'SUSPICIOUS_ACTIVITY',
      userId,
      activity,
      details,
      timestamp: new Date().toISOString(),
    });
  }

  logSecurityIncident(
    severity: 'low' | 'medium' | 'high' | 'critical',
    incident: string,
    details: Record<string, any>,
  ): void {
    this.logger.error({
      event: 'SECURITY_INCIDENT',
      severity,
      incident,
      details,
      timestamp: new Date().toISOString(),
    });
  }
}
```

### Intrusion Detection

```typescript
// intrusion-detection.service.ts
@Injectable()
export class IntrusionDetectionService {
  constructor(
    @InjectRedis() private readonly redis: Redis,
    private readonly securityLogger: SecurityLoggerService,
  ) {}

  async checkFailedLogins(ip: string, email: string): Promise<void> {
    const ipKey = `failed_logins:ip:${ip}`;
    const emailKey = `failed_logins:email:${email}`;

    const [ipFailures, emailFailures] = await Promise.all([
      this.redis.incr(ipKey),
      this.redis.incr(emailKey),
    ]);

    // Set expiration on first failure
    if (ipFailures === 1) {
      await this.redis.expire(ipKey, 3600); // 1 hour
    }
    if (emailFailures === 1) {
      await this.redis.expire(emailKey, 3600); // 1 hour
    }

    // Check thresholds
    if (ipFailures >= 10) {
      await this.blockIp(ip, 3600); // Block for 1 hour
      this.securityLogger.logSecurityIncident(
        'high',
        'IP_BLOCKED_MULTIPLE_FAILURES',
        { ip, failures: ipFailures },
      );
    }

    if (emailFailures >= 5) {
      await this.lockAccount(email, 1800); // Lock for 30 minutes
      this.securityLogger.logSecurityIncident(
        'medium',
        'ACCOUNT_LOCKED_MULTIPLE_FAILURES',
        { email, failures: emailFailures },
      );
    }
  }

  private async blockIp(ip: string, duration: number): Promise<void> {
    await this.redis.setex(`blocked_ip:${ip}`, duration, '1');
  }

  private async lockAccount(email: string, duration: number): Promise<void> {
    await this.redis.setex(`locked_account:${email}`, duration, '1');
  }

  async isIpBlocked(ip: string): Promise<boolean> {
    const blocked = await this.redis.get(`blocked_ip:${ip}`);
    return !!blocked;
  }

  async isAccountLocked(email: string): Promise<boolean> {
    const locked = await this.redis.get(`locked_account:${email}`);
    return !!locked;
  }
}
```

This comprehensive security implementation guide demonstrates how production NestJS applications handle authentication, authorization, input validation, rate limiting, and security monitoring. These patterns ensure robust protection against common web application vulnerabilities while maintaining good user experience.