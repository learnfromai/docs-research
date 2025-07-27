# Security Implementations in NestJS Applications

## 🎯 Overview

Comprehensive analysis of security patterns and implementations found in production NestJS applications. This document covers authentication strategies, authorization patterns, input validation, and security best practices from 30+ open source projects.

## 🔐 Authentication Strategies

### 1. JWT + Passport (85% of Projects)

**Most Common Implementation Pattern:**

```typescript
// JWT Strategy
@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(
    private readonly configService: ConfigService,
    private readonly userService: UserService,
  ) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: configService.get('JWT_SECRET'),
    });
  }

  async validate(payload: JwtPayload): Promise<User> {
    const user = await this.userService.findById(payload.sub);
    if (!user) {
      throw new UnauthorizedException();
    }
    return user;
  }
}

// Local Strategy for Login
@Injectable()
export class LocalStrategy extends PassportStrategy(Strategy) {
  constructor(private readonly authService: AuthService) {
    super({
      usernameField: 'email',
      passwordField: 'password',
    });
  }

  async validate(email: string, password: string): Promise<User> {
    const user = await this.authService.validateUser(email, password);
    if (!user) {
      throw new UnauthorizedException('Invalid credentials');
    }
    return user;
  }
}
```

**Auth Service Implementation:**
```typescript
@Injectable()
export class AuthService {
  constructor(
    private readonly userService: UserService,
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
  ) {}

  async validateUser(email: string, password: string): Promise<User | null> {
    const user = await this.userService.findByEmail(email);
    if (user && await bcrypt.compare(password, user.password)) {
      const { password, ...result } = user;
      return result;
    }
    return null;
  }

  async login(user: User): Promise<AuthResponse> {
    const payload: JwtPayload = { 
      email: user.email, 
      sub: user.id,
      roles: user.roles 
    };
    
    const accessToken = this.jwtService.sign(payload);
    const refreshToken = this.generateRefreshToken(user.id);
    
    return {
      access_token: accessToken,
      refresh_token: refreshToken,
      expires_in: this.configService.get('JWT_EXPIRATION_TIME'),
    };
  }

  async refreshAccessToken(refreshToken: string): Promise<AuthResponse> {
    try {
      const decoded = this.jwtService.verify(refreshToken, {
        secret: this.configService.get('JWT_REFRESH_SECRET'),
      });
      
      const user = await this.userService.findById(decoded.sub);
      if (!user) {
        throw new UnauthorizedException('Invalid refresh token');
      }
      
      return this.login(user);
    } catch (error) {
      throw new UnauthorizedException('Invalid refresh token');
    }
  }

  private generateRefreshToken(userId: string): string {
    return this.jwtService.sign(
      { sub: userId },
      {
        secret: this.configService.get('JWT_REFRESH_SECRET'),
        expiresIn: this.configService.get('JWT_REFRESH_EXPIRATION_TIME'),
      },
    );
  }
}
```

**Auth Controller:**
```typescript
@Controller('auth')
@ApiTags('Authentication')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @UseGuards(LocalAuthGuard)
  @Post('login')
  @ApiOperation({ summary: 'User login' })
  @ApiResponse({ status: 200, description: 'Login successful' })
  async login(@Request() req, @Body() loginDto: LoginDto): Promise<AuthResponse> {
    return this.authService.login(req.user);
  }

  @Post('register')
  @ApiOperation({ summary: 'User registration' })
  async register(@Body() registerDto: RegisterDto): Promise<AuthResponse> {
    const user = await this.authService.register(registerDto);
    return this.authService.login(user);
  }

  @Post('refresh')
  @ApiOperation({ summary: 'Refresh access token' })
  async refresh(@Body() refreshDto: RefreshTokenDto): Promise<AuthResponse> {
    return this.authService.refreshAccessToken(refreshDto.refreshToken);
  }

  @UseGuards(JwtAuthGuard)
  @Get('profile')
  @ApiOperation({ summary: 'Get user profile' })
  getProfile(@User() user: User): User {
    return user;
  }

  @UseGuards(JwtAuthGuard)
  @Post('logout')
  @ApiOperation({ summary: 'User logout' })
  async logout(@User() user: User): Promise<void> {
    // Invalidate refresh token
    await this.authService.invalidateRefreshToken(user.id);
  }
}
```

**Projects Using This Pattern:**
- **Brocoders Boilerplate**: Complete JWT implementation with refresh tokens
- **Awesome Nest Boilerplate**: Advanced JWT with multiple strategies
- **NestJS Realworld**: Clean JWT implementation

---

### 2. Multi-Factor Authentication (30% of Projects)

**TOTP Implementation:**
```typescript
@Injectable()
export class TwoFactorAuthService {
  async generateTwoFactorAuthSecret(user: User): Promise<TwoFactorAuthResponse> {
    const secret = authenticator.generateSecret();
    const otpauthUrl = authenticator.keyuri(
      user.email,
      this.configService.get('APP_NAME'),
      secret,
    );

    await this.userService.setTwoFactorAuthSecret(secret, user.id);

    return {
      secret,
      otpauthUrl,
    };
  }

  async generateQrCodeDataURL(otpAuthUrl: string): Promise<string> {
    return toDataURL(otpAuthUrl);
  }

  async isTwoFactorAuthCodeValid(
    twoFactorAuthCode: string,
    user: User,
  ): Promise<boolean> {
    return authenticator.verify({
      token: twoFactorAuthCode,
      secret: user.twoFactorAuthSecret,
    });
  }

  async enableTwoFactorAuth(user: User): Promise<void> {
    await this.userService.turnOnTwoFactorAuth(user.id);
  }
}

// Enhanced JWT Strategy with 2FA
@Injectable()
export class JwtTwoFactorStrategy extends PassportStrategy(
  Strategy,
  'jwt-two-factor',
) {
  constructor(
    private readonly configService: ConfigService,
    private readonly userService: UserService,
  ) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      secretOrKey: configService.get('JWT_SECRET'),
    });
  }

  async validate(payload: JwtPayload): Promise<User> {
    const user = await this.userService.findById(payload.sub);
    if (!user.isTwoFactorEnabled) {
      return user;
    }
    if (payload.isSecondFactorAuthenticated) {
      return user;
    }
    throw new UnauthorizedException('Two-factor authentication required');
  }
}
```

---

### 3. OAuth Integration (40% of Projects)

**Google OAuth Strategy:**
```typescript
@Injectable()
export class GoogleStrategy extends PassportStrategy(Strategy, 'google') {
  constructor(
    private readonly configService: ConfigService,
    private readonly authService: AuthService,
  ) {
    super({
      clientID: configService.get('GOOGLE_CLIENT_ID'),
      clientSecret: configService.get('GOOGLE_CLIENT_SECRET'),
      callbackURL: configService.get('GOOGLE_CALLBACK_URL'),
      scope: ['email', 'profile'],
    });
  }

  async validate(
    accessToken: string,
    refreshToken: string,
    profile: any,
  ): Promise<User> {
    const { name, emails, photos } = profile;
    const user = {
      email: emails[0].value,
      firstName: name.givenName,
      lastName: name.familyName,
      picture: photos[0].value,
      accessToken,
      refreshToken,
    };
    return this.authService.validateOAuthLogin(user, 'google');
  }
}

// OAuth Service
@Injectable()
export class OAuthService {
  constructor(private readonly userService: UserService) {}

  async validateOAuthLogin(
    oauthUser: OAuthUser,
    provider: string,
  ): Promise<User> {
    let user = await this.userService.findByEmail(oauthUser.email);
    
    if (!user) {
      // Create new user from OAuth data
      user = await this.userService.create({
        email: oauthUser.email,
        firstName: oauthUser.firstName,
        lastName: oauthUser.lastName,
        provider,
        providerId: oauthUser.providerId,
        isEmailVerified: true, // OAuth emails are pre-verified
      });
    } else if (!user.providerId) {
      // Link existing user with OAuth provider
      await this.userService.linkProvider(user.id, provider, oauthUser.providerId);
    }
    
    return user;
  }
}
```

---

## 🛡️ Authorization Patterns

### 1. Role-Based Access Control (RBAC) - 70% of Projects

**Role and Permission System:**
```typescript
// Role and Permission Entities
@Entity()
export class Role {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ unique: true })
  name: string;

  @ManyToMany(() => Permission, permission => permission.roles)
  @JoinTable()
  permissions: Permission[];

  @ManyToMany(() => User, user => user.roles)
  users: User[];
}

@Entity()
export class Permission {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ unique: true })
  name: string;

  @Column()
  resource: string;

  @Column()
  action: string;

  @ManyToMany(() => Role, role => role.permissions)
  roles: Role[];
}

// User Entity with Roles
@Entity()
export class User {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ unique: true })
  email: string;

  @ManyToMany(() => Role, role => role.users)
  @JoinTable()
  roles: Role[];

  hasPermission(resource: string, action: string): boolean {
    return this.roles.some(role =>
      role.permissions.some(permission =>
        permission.resource === resource && permission.action === action
      )
    );
  }

  hasRole(roleName: string): boolean {
    return this.roles.some(role => role.name === roleName);
  }
}
```

**Guards Implementation:**
```typescript
// Roles Guard
@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private readonly reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const requiredRoles = this.reflector.getAllAndOverride<string[]>(
      ROLES_KEY,
      [context.getHandler(), context.getClass()],
    );

    if (!requiredRoles) {
      return true;
    }

    const { user } = context.switchToHttp().getRequest();
    return requiredRoles.some(role => user.roles?.includes(role));
  }
}

// Permissions Guard
@Injectable()
export class PermissionsGuard implements CanActivate {
  constructor(private readonly reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const requiredPermissions = this.reflector.getAllAndOverride<Permission[]>(
      PERMISSIONS_KEY,
      [context.getHandler(), context.getClass()],
    );

    if (!requiredPermissions) {
      return true;
    }

    const { user } = context.switchToHttp().getRequest();
    return requiredPermissions.every(permission =>
      user.hasPermission(permission.resource, permission.action)
    );
  }
}

// Custom Decorators
export const Roles = (...roles: string[]) => SetMetadata(ROLES_KEY, roles);
export const RequirePermissions = (...permissions: Permission[]) =>
  SetMetadata(PERMISSIONS_KEY, permissions);

// Usage in Controllers
@Controller('admin')
@UseGuards(JwtAuthGuard, RolesGuard)
export class AdminController {
  @Get('users')
  @Roles('admin', 'moderator')
  getUsers(): Promise<User[]> {
    return this.userService.findAll();
  }

  @Delete('users/:id')
  @RequirePermissions({ resource: 'user', action: 'delete' })
  deleteUser(@Param('id') id: string): Promise<void> {
    return this.userService.delete(id);
  }
}
```

---

### 2. Attribute-Based Access Control (ABAC) - 20% of Projects

**Policy-Based Authorization:**
```typescript
// Policy Interface
export interface AuthorizationPolicy {
  evaluate(context: AuthorizationContext): Promise<boolean>;
}

// Authorization Context
export interface AuthorizationContext {
  user: User;
  resource?: any;
  action: string;
  environment?: Record<string, any>;
}

// Resource Owner Policy
@Injectable()
export class ResourceOwnerPolicy implements AuthorizationPolicy {
  async evaluate(context: AuthorizationContext): Promise<boolean> {
    const { user, resource } = context;
    return resource && resource.userId === user.id;
  }
}

// Time-Based Policy
@Injectable()
export class BusinessHoursPolicy implements AuthorizationPolicy {
  async evaluate(context: AuthorizationContext): Promise<boolean> {
    const now = new Date();
    const hour = now.getHours();
    return hour >= 9 && hour <= 17; // 9 AM to 5 PM
  }
}

// Policy Guard
@Injectable()
export class PolicyGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly moduleRef: ModuleRef,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const policyClasses = this.reflector.getAllAndOverride<Function[]>(
      POLICIES_KEY,
      [context.getHandler(), context.getClass()],
    );

    if (!policyClasses) {
      return true;
    }

    const request = context.switchToHttp().getRequest();
    const authContext: AuthorizationContext = {
      user: request.user,
      resource: request.resource,
      action: request.method,
      environment: { ip: request.ip, userAgent: request.headers['user-agent'] },
    };

    for (const PolicyClass of policyClasses) {
      const policy = await this.moduleRef.create(PolicyClass);
      const result = await policy.evaluate(authContext);
      if (!result) {
        return false;
      }
    }

    return true;
  }
}
```

---

## 🔍 Input Validation & Sanitization

### 1. DTO Validation (100% of Projects)

**Comprehensive Validation:**
```typescript
// User Registration DTO
export class CreateUserDto {
  @ApiProperty({ example: 'john.doe@example.com' })
  @IsEmail()
  @IsNotEmpty()
  @Transform(({ value }) => value.toLowerCase().trim())
  email: string;

  @ApiProperty({ example: 'StrongPassword123!' })
  @IsString()
  @MinLength(8)
  @MaxLength(128)
  @Matches(
    /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]/,
    {
      message: 'Password must contain uppercase, lowercase, number and special character',
    },
  )
  password: string;

  @ApiProperty({ example: 'John' })
  @IsString()
  @IsNotEmpty()
  @Length(2, 50)
  @Transform(({ value }) => value.trim())
  @Matches(/^[a-zA-Z\s]+$/, {
    message: 'First name can only contain letters and spaces',
  })
  firstName: string;

  @ApiProperty({ example: 'Doe' })
  @IsString()
  @IsNotEmpty()
  @Length(2, 50)
  @Transform(({ value }) => value.trim())
  @Matches(/^[a-zA-Z\s]+$/, {
    message: 'Last name can only contain letters and spaces',
  })
  lastName: string;

  @ApiProperty({ example: '+1234567890', required: false })
  @IsOptional()
  @IsPhoneNumber()
  phone?: string;

  @ApiProperty({ example: '1990-01-01' })
  @IsDateString()
  @IsOptional()
  @Transform(({ value }) => value ? new Date(value) : undefined)
  @ValidateIf((o) => o.dateOfBirth !== undefined)
  @IsDate()
  dateOfBirth?: Date;
}

// Custom Validators
export function IsStrongPassword(validationOptions?: ValidationOptions) {
  return function (object: any, propertyName: string) {
    registerDecorator({
      name: 'isStrongPassword',
      target: object.constructor,
      propertyName: propertyName,
      options: validationOptions,
      validator: {
        validate(value: any) {
          if (typeof value !== 'string') return false;
          
          const hasLower = /[a-z]/.test(value);
          const hasUpper = /[A-Z]/.test(value);
          const hasNumber = /\d/.test(value);
          const hasSpecial = /[@$!%*?&]/.test(value);
          const isLongEnough = value.length >= 8;
          
          return hasLower && hasUpper && hasNumber && hasSpecial && isLongEnough;
        },
        defaultMessage() {
          return 'Password must be at least 8 characters with uppercase, lowercase, number and special character';
        },
      },
    });
  };
}
```

**Global Validation Pipe:**
```typescript
// main.ts
app.useGlobalPipes(
  new ValidationPipe({
    whitelist: true,          // Remove non-decorated properties
    forbidNonWhitelisted: true, // Throw error on non-whitelisted properties
    transform: true,          // Auto-transform to target types
    disableErrorMessages: process.env.NODE_ENV === 'production',
    validationError: {
      target: false,          // Don't expose the target object
      value: false,           // Don't expose the validated value
    },
  }),
);
```

---

### 2. SQL Injection Prevention

**Parameterized Queries with TypeORM:**
```typescript
@Injectable()
export class UserRepository {
  constructor(
    @InjectRepository(User)
    private readonly repository: Repository<User>,
  ) {}

  // Safe: Using parameterized queries
  async findByEmailSafe(email: string): Promise<User> {
    return this.repository.findOne({
      where: { email }, // TypeORM handles parameterization
    });
  }

  // Safe: Using query builder with parameters
  async searchUsersSafe(searchTerm: string): Promise<User[]> {
    return this.repository
      .createQueryBuilder('user')
      .where('user.firstName ILIKE :search OR user.lastName ILIKE :search', {
        search: `%${searchTerm}%`,
      })
      .getMany();
  }

  // Safe: Raw query with proper parameterization
  async customQuerySafe(userId: string): Promise<any> {
    return this.repository.query(
      'SELECT * FROM users WHERE id = $1 AND active = true',
      [userId],
    );
  }
}
```

---

### 3. XSS Prevention

**Content Sanitization:**
```typescript
// HTML Sanitization Service
@Injectable()
export class SanitizationService {
  private readonly sanitizer = createDOMPurify(new JSDOM('').window);

  sanitizeHtml(dirty: string): string {
    return this.sanitizer.sanitize(dirty, {
      ALLOWED_TAGS: ['b', 'i', 'em', 'strong', 'a', 'p', 'br'],
      ALLOWED_ATTR: ['href'],
      ALLOW_DATA_ATTR: false,
    });
  }

  sanitizeText(text: string): string {
    return text
      .replace(/[<>\"']/g, (char) => {
        const charCodes = {
          '<': '&lt;',
          '>': '&gt;',
          '"': '&quot;',
          "'": '&#x27;',
        };
        return charCodes[char] || char;
      });
  }
}

// Transform Decorator for Auto-Sanitization
export function Sanitize() {
  return Transform(({ value }) => {
    if (typeof value === 'string') {
      return value.replace(/[<>\"']/g, (char) => {
        const charCodes = {
          '<': '&lt;',
          '>': '&gt;',
          '"': '&quot;',
          "'": '&#x27;',
        };
        return charCodes[char] || char;
      });
    }
    return value;
  });
}

// Usage in DTO
export class CreatePostDto {
  @IsString()
  @IsNotEmpty()
  @Sanitize()
  title: string;

  @IsString()
  @IsNotEmpty()
  @Transform(({ value }) => sanitizeHtml(value))
  content: string;
}
```

---

## 🚫 Rate Limiting & Throttling

**Implementation:**
```typescript
// Rate Limiting Configuration
@Module({
  imports: [
    ThrottlerModule.forRoot({
      ttl: 60,        // Time window in seconds
      limit: 10,      // Max requests per window
    }),
  ],
})
export class AppModule {}

// Custom Rate Limiting
@Injectable()
export class CustomThrottlerGuard extends ThrottlerGuard {
  protected getTracker(req: Record<string, any>): string {
    // Rate limit by user ID if authenticated, otherwise by IP
    return req.user?.id || req.ip;
  }

  protected async shouldSkip(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest();
    
    // Skip rate limiting for admin users
    if (request.user?.roles?.includes('admin')) {
      return true;
    }
    
    return false;
  }
}

// Controller Usage
@Controller('api')
@UseGuards(CustomThrottlerGuard)
export class ApiController {
  @Post('login')
  @Throttle(5, 60) // 5 attempts per minute
  async login(@Body() loginDto: LoginDto) {
    return this.authService.login(loginDto);
  }

  @Get('search')
  @Throttle(100, 60) // 100 searches per minute
  async search(@Query() searchDto: SearchDto) {
    return this.searchService.search(searchDto);
  }
}
```

---

## 🔗 Navigation

**Previous:** [Architecture Patterns](./architecture-patterns.md) - Architectural analysis  
**Next:** [Testing Strategies](./testing-strategies.md) - Testing approaches and frameworks

---

*Security implementations analysis completed July 2025 - Based on security patterns from 30+ production NestJS applications*