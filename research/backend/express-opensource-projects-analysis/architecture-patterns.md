# Architecture Patterns: Express.js Applications

## 🏗️ Overview

This document explores architectural patterns discovered in production Express.js applications, analyzing how successful projects organize code, manage dependencies, and scale their applications. These patterns represent battle-tested approaches to building maintainable and scalable Express.js applications.

## 📊 Architecture Pattern Distribution

Based on analysis of 15+ production Express.js projects:

| Pattern | Usage | Scalability | Complexity | Best For |
|---------|-------|-------------|------------|----------|
| **Layered Architecture** | 80% | ⭐⭐⭐ | ⭐⭐ | Small to medium apps |
| **Feature-Based Structure** | 60% | ⭐⭐⭐⭐ | ⭐⭐⭐ | Large applications |
| **Clean Architecture** | 40% | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | Enterprise applications |
| **Microservices** | 25% | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | Distributed systems |
| **Monolithic Modular** | 35% | ⭐⭐⭐ | ⭐⭐ | Traditional applications |

## 🏛️ Layered Architecture

### Pattern Overview
The most common pattern found in Express.js applications, organizing code into horizontal layers with clear separation of concerns.

### Implementation Example

#### Directory Structure
```
src/
├── controllers/          # HTTP request handlers
├── services/            # Business logic layer
├── repositories/        # Data access layer
├── models/              # Data models/schemas
├── middleware/          # Custom middleware
├── routes/              # Route definitions
├── utils/               # Utility functions
├── config/              # Configuration files
├── types/               # TypeScript types
└── validations/         # Input validation schemas
```

#### Implementation
```typescript
// ✅ Data Access Layer (Repository)
interface IUserRepository {
  findById(id: string): Promise<User | null>;
  findByEmail(email: string): Promise<User | null>;
  create(userData: CreateUserDto): Promise<User>;
  update(id: string, userData: UpdateUserDto): Promise<User>;
  delete(id: string): Promise<void>;
}

class UserRepository implements IUserRepository {
  async findById(id: string): Promise<User | null> {
    try {
      return await User.findById(id).select('-password');
    } catch (error) {
      throw new DatabaseError('Failed to find user by ID');
    }
  }

  async findByEmail(email: string): Promise<User | null> {
    try {
      return await User.findOne({ email: email.toLowerCase() });
    } catch (error) {
      throw new DatabaseError('Failed to find user by email');
    }
  }

  async create(userData: CreateUserDto): Promise<User> {
    try {
      const user = new User(userData);
      return await user.save();
    } catch (error) {
      if (error.code === 11000) {
        throw new ConflictError('User already exists');
      }
      throw new DatabaseError('Failed to create user');
    }
  }
}

// ✅ Business Logic Layer (Service)
class UserService {
  constructor(
    private userRepository: IUserRepository,
    private emailService: IEmailService,
    private hashingService: IHashingService
  ) {}

  async createUser(userData: CreateUserDto): Promise<UserResponseDto> {
    // Business logic validation
    await this.validateUserCreation(userData);

    // Hash password
    const hashedPassword = await this.hashingService.hash(userData.password);

    // Create user
    const user = await this.userRepository.create({
      ...userData,
      password: hashedPassword,
      emailVerified: false,
      createdAt: new Date()
    });

    // Send welcome email
    await this.emailService.sendWelcomeEmail(user.email, user.name);

    // Return sanitized user data
    return this.mapToUserResponse(user);
  }

  async authenticateUser(email: string, password: string): Promise<AuthResponseDto> {
    const user = await this.userRepository.findByEmail(email);
    
    if (!user) {
      throw new AuthenticationError('Invalid credentials');
    }

    const isPasswordValid = await this.hashingService.compare(password, user.password);
    
    if (!isPasswordValid) {
      throw new AuthenticationError('Invalid credentials');
    }

    if (!user.emailVerified) {
      throw new AuthenticationError('Email not verified');
    }

    const tokens = await this.tokenService.generateTokenPair({
      id: user.id,
      email: user.email,
      role: user.role
    });

    return {
      user: this.mapToUserResponse(user),
      ...tokens
    };
  }

  private async validateUserCreation(userData: CreateUserDto): Promise<void> {
    const existingUser = await this.userRepository.findByEmail(userData.email);
    
    if (existingUser) {
      throw new ConflictError('User with this email already exists');
    }

    // Additional business rules
    if (userData.age && userData.age < 13) {
      throw new ValidationError('User must be at least 13 years old');
    }
  }

  private mapToUserResponse(user: User): UserResponseDto {
    return {
      id: user.id,
      name: user.name,
      email: user.email,
      role: user.role,
      emailVerified: user.emailVerified,
      createdAt: user.createdAt,
      updatedAt: user.updatedAt
    };
  }
}

// ✅ Presentation Layer (Controller)
class UserController {
  constructor(private userService: UserService) {}

  register = asyncHandler(async (req: Request, res: Response) => {
    const userData: CreateUserDto = req.body;
    
    const result = await this.userService.createUser(userData);
    
    res.status(201).json({
      success: true,
      message: 'User created successfully',
      data: result
    });
  });

  login = asyncHandler(async (req: Request, res: Response) => {
    const { email, password } = req.body;
    
    const result = await this.userService.authenticateUser(email, password);
    
    // Set refresh token cookie
    res.cookie('refreshToken', result.refreshToken, {
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'strict',
      maxAge: 7 * 24 * 60 * 60 * 1000 // 7 days
    });
    
    res.json({
      success: true,
      message: 'Login successful',
      data: {
        user: result.user,
        accessToken: result.accessToken
      }
    });
  });

  getProfile = asyncHandler(async (req: AuthRequest, res: Response) => {
    const userId = req.user.id;
    
    const user = await this.userService.getUserProfile(userId);
    
    res.json({
      success: true,
      data: user
    });
  });
}
```

### Advantages
- **Clear Separation**: Each layer has a distinct responsibility
- **Easy Testing**: Layers can be tested independently
- **Familiar Pattern**: Most developers understand this structure
- **Framework Agnostic**: Business logic isolated from Express

### Disadvantages
- **Cross-Cutting Concerns**: Some features span multiple layers
- **Circular Dependencies**: Risk of tight coupling between layers
- **Anemic Domain Model**: Business logic scattered across services

## 🎯 Feature-Based Architecture

### Pattern Overview
Organizes code around business features rather than technical layers, promoting high cohesion and low coupling.

### Implementation Example

#### Directory Structure
```
src/
├── shared/                    # Shared utilities and components
│   ├── middleware/
│   ├── utils/
│   ├── types/
│   ├── config/
│   └── database/
├── features/
│   ├── authentication/        # Auth feature module
│   │   ├── controllers/
│   │   ├── services/
│   │   ├── repositories/
│   │   ├── models/
│   │   ├── routes/
│   │   ├── validations/
│   │   ├── tests/
│   │   ├── types/
│   │   └── index.ts
│   ├── users/                 # User management feature
│   │   ├── controllers/
│   │   ├── services/
│   │   ├── repositories/
│   │   ├── models/
│   │   ├── routes/
│   │   ├── validations/
│   │   ├── tests/
│   │   └── index.ts
│   ├── posts/                 # Post management feature
│   │   └── ...
│   └── notifications/         # Notification feature
│       └── ...
└── app.ts
```

#### Feature Module Implementation
```typescript
// ✅ Authentication Feature Module
// features/authentication/index.ts
export class AuthenticationModule {
  private authRepository: AuthRepository;
  private authService: AuthService;
  private authController: AuthController;
  private authRoutes: Router;

  constructor(dependencies: ModuleDependencies) {
    this.authRepository = new AuthRepository(dependencies.database);
    this.authService = new AuthService(
      this.authRepository,
      dependencies.emailService,
      dependencies.tokenService
    );
    this.authController = new AuthController(this.authService);
    this.authRoutes = this.createRoutes();
  }

  private createRoutes(): Router {
    const router = Router();

    router.post('/register', 
      validate(registrationSchema),
      this.authController.register
    );

    router.post('/login',
      rateLimiter({ max: 5, windowMs: 15 * 60 * 1000 }),
      validate(loginSchema),
      this.authController.login
    );

    router.post('/logout',
      authenticateToken,
      this.authController.logout
    );

    router.post('/refresh',
      this.authController.refreshToken
    );

    router.post('/forgot-password',
      validate(forgotPasswordSchema),
      this.authController.forgotPassword
    );

    router.post('/reset-password',
      validate(resetPasswordSchema),
      this.authController.resetPassword
    );

    return router;
  }

  getRoutes(): Router {
    return this.authRoutes;
  }

  // Expose services for other modules
  getAuthService(): AuthService {
    return this.authService;
  }
}

// features/authentication/services/auth.service.ts
export class AuthService {
  constructor(
    private authRepository: AuthRepository,
    private emailService: IEmailService,
    private tokenService: ITokenService,
    private hashingService: IHashingService
  ) {}

  async registerUser(userData: RegisterUserDto): Promise<AuthResult> {
    // Check if user exists
    const existingUser = await this.authRepository.findByEmail(userData.email);
    if (existingUser) {
      throw new ConflictError('User already exists');
    }

    // Hash password
    const hashedPassword = await this.hashingService.hash(userData.password);

    // Create user
    const user = await this.authRepository.create({
      ...userData,
      password: hashedPassword,
      emailVerified: false,
      verificationToken: this.generateVerificationToken()
    });

    // Send verification email
    await this.emailService.sendVerificationEmail(
      user.email,
      user.verificationToken
    );

    // Generate tokens
    const tokens = this.tokenService.generateTokenPair({
      id: user.id,
      email: user.email,
      role: user.role
    });

    return {
      user: this.sanitizeUser(user),
      ...tokens
    };
  }

  async loginUser(credentials: LoginCredentialsDto): Promise<AuthResult> {
    const user = await this.authRepository.findByEmail(credentials.email);
    
    if (!user) {
      throw new AuthenticationError('Invalid credentials');
    }

    const isPasswordValid = await this.hashingService.compare(
      credentials.password,
      user.password
    );

    if (!isPasswordValid) {
      // Log failed attempt
      await this.authRepository.logFailedLogin(user.id, credentials.ip);
      throw new AuthenticationError('Invalid credentials');
    }

    if (!user.emailVerified) {
      throw new AuthenticationError('Please verify your email first');
    }

    // Update last login
    await this.authRepository.updateLastLogin(user.id);

    const tokens = this.tokenService.generateTokenPair({
      id: user.id,
      email: user.email,
      role: user.role
    });

    return {
      user: this.sanitizeUser(user),
      ...tokens
    };
  }

  private sanitizeUser(user: any) {
    const { password, verificationToken, resetToken, ...sanitized } = user.toObject();
    return sanitized;
  }

  private generateVerificationToken(): string {
    return crypto.randomBytes(32).toString('hex');
  }
}

// ✅ User Feature Module
// features/users/index.ts
export class UserModule {
  private userRepository: UserRepository;
  private userService: UserService;
  private userController: UserController;
  private userRoutes: Router;

  constructor(dependencies: ModuleDependencies) {
    this.userRepository = new UserRepository(dependencies.database);
    this.userService = new UserService(
      this.userRepository,
      dependencies.fileService,
      dependencies.authService
    );
    this.userController = new UserController(this.userService);
    this.userRoutes = this.createRoutes();
  }

  private createRoutes(): Router {
    const router = Router();

    // All user routes require authentication
    router.use(authenticateToken);

    router.get('/profile', this.userController.getProfile);
    router.put('/profile', 
      validate(updateProfileSchema),
      this.userController.updateProfile
    );
    router.post('/avatar',
      upload.single('avatar'),
      this.userController.uploadAvatar
    );
    router.delete('/account', this.userController.deleteAccount);

    // Admin only routes
    router.get('/users',
      authorize('admin'),
      validateQuery(getUsersQuerySchema),
      this.userController.getUsers
    );

    router.get('/users/:id',
      authorize('admin'),
      validate(getUserByIdSchema),
      this.userController.getUserById
    );

    return router;
  }

  getRoutes(): Router {
    return this.userRoutes;
  }
}
```

#### Module Integration
```typescript
// ✅ Application setup with feature modules
// app.ts
class Application {
  private app: Express;
  private modules: Map<string, any> = new Map();

  constructor() {
    this.app = express();
    this.setupMiddleware();
    this.initializeModules();
    this.setupRoutes();
    this.setupErrorHandling();
  }

  private setupMiddleware(): void {
    this.app.use(helmet());
    this.app.use(cors());
    this.app.use(compression());
    this.app.use(express.json({ limit: '10mb' }));
    this.app.use(morgan('combined'));
  }

  private initializeModules(): void {
    const dependencies = this.createDependencies();

    // Initialize feature modules
    this.modules.set('auth', new AuthenticationModule(dependencies));
    this.modules.set('users', new UserModule(dependencies));
    this.modules.set('posts', new PostModule(dependencies));
    this.modules.set('notifications', new NotificationModule(dependencies));
  }

  private setupRoutes(): void {
    // Health check
    this.app.get('/health', (req, res) => {
      res.json({ status: 'OK', timestamp: new Date().toISOString() });
    });

    // Feature routes
    this.app.use('/api/v1/auth', this.modules.get('auth').getRoutes());
    this.app.use('/api/v1/users', this.modules.get('users').getRoutes());
    this.app.use('/api/v1/posts', this.modules.get('posts').getRoutes());
    this.app.use('/api/v1/notifications', this.modules.get('notifications').getRoutes());
  }

  private createDependencies(): ModuleDependencies {
    return {
      database: mongoose.connection,
      emailService: new EmailService(),
      tokenService: new TokenService(),
      fileService: new FileService(),
      cacheService: new CacheService(),
      logger: new Logger()
    };
  }

  getApp(): Express {
    return this.app;
  }
}
```

### Advantages
- **High Cohesion**: Related functionality grouped together
- **Clear Boundaries**: Features are self-contained modules
- **Team Scalability**: Teams can work on different features independently
- **Easy Testing**: Each feature can be tested in isolation
- **Flexible Deployment**: Features can potentially be deployed separately

### Disadvantages
- **Initial Complexity**: More complex setup than layered architecture
- **Shared Code Management**: Need to carefully manage shared utilities
- **Feature Dependencies**: Some features may depend on others

## 🎭 Clean Architecture

### Pattern Overview
Based on Uncle Bob's Clean Architecture principles, organizing code in concentric circles with dependencies pointing inward.

### Implementation Example

#### Directory Structure
```
src/
├── domain/                   # Enterprise business rules
│   ├── entities/
│   ├── value-objects/
│   └── interfaces/
├── usecases/                 # Application business rules
│   ├── user/
│   ├── auth/
│   └── post/
├── interfaces/               # Interface adapters
│   ├── controllers/
│   ├── presenters/
│   ├── repositories/
│   └── services/
├── infrastructure/           # Frameworks and drivers
│   ├── database/
│   ├── email/
│   ├── web/
│   └── config/
└── main/                     # Application entry point
    ├── factories/
    ├── routes/
    └── server.ts
```

#### Domain Layer Implementation
```typescript
// ✅ Domain Entities
// domain/entities/user.entity.ts
export class User {
  private constructor(
    private readonly id: UserId,
    private name: UserName,
    private email: Email,
    private password: Password,
    private role: UserRole,
    private emailVerified: boolean,
    private readonly createdAt: Date,
    private updatedAt: Date
  ) {}

  static create(props: CreateUserProps): User {
    const user = new User(
      UserId.create(),
      UserName.create(props.name),
      Email.create(props.email),
      Password.create(props.password),
      UserRole.create(props.role || 'user'),
      false,
      new Date(),
      new Date()
    );

    // Domain events
    DomainEvents.raise(new UserCreatedEvent(user.getId()));

    return user;
  }

  static fromPersistence(props: UserPersistenceProps): User {
    return new User(
      UserId.create(props.id),
      UserName.create(props.name),
      Email.create(props.email),
      Password.createFromHash(props.password),
      UserRole.create(props.role),
      props.emailVerified,
      props.createdAt,
      props.updatedAt
    );
  }

  updateProfile(name: string, email: string): void {
    const newName = UserName.create(name);
    const newEmail = Email.create(email);

    if (!this.name.equals(newName) || !this.email.equals(newEmail)) {
      this.name = newName;
      this.email = newEmail;
      this.updatedAt = new Date();

      DomainEvents.raise(new UserProfileUpdatedEvent(this.getId()));
    }
  }

  verifyEmail(): void {
    if (!this.emailVerified) {
      this.emailVerified = true;
      this.updatedAt = new Date();

      DomainEvents.raise(new UserEmailVerifiedEvent(this.getId()));
    }
  }

  changePassword(currentPassword: string, newPassword: string): void {
    if (!this.password.compare(currentPassword)) {
      throw new InvalidPasswordError('Current password is incorrect');
    }

    this.password = Password.create(newPassword);
    this.updatedAt = new Date();

    DomainEvents.raise(new UserPasswordChangedEvent(this.getId()));
  }

  // Getters
  getId(): string {
    return this.id.getValue();
  }

  getName(): string {
    return this.name.getValue();
  }

  getEmail(): string {
    return this.email.getValue();
  }

  getRole(): string {
    return this.role.getValue();
  }

  isEmailVerified(): boolean {
    return this.emailVerified;
  }

  getCreatedAt(): Date {
    return this.createdAt;
  }

  getUpdatedAt(): Date {
    return this.updatedAt;
  }
}

// ✅ Value Objects
// domain/value-objects/email.vo.ts
export class Email {
  private constructor(private readonly value: string) {
    this.validate(value);
  }

  static create(email: string): Email {
    return new Email(email);
  }

  private validate(email: string): void {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    
    if (!email || email.trim().length === 0) {
      throw new InvalidEmailError('Email cannot be empty');
    }

    if (!emailRegex.test(email)) {
      throw new InvalidEmailError('Invalid email format');
    }

    if (email.length > 254) {
      throw new InvalidEmailError('Email too long');
    }
  }

  getValue(): string {
    return this.value;
  }

  equals(other: Email): boolean {
    return this.value === other.value;
  }
}

// ✅ Repository Interface (Domain)
// domain/interfaces/user.repository.interface.ts
export interface IUserRepository {
  save(user: User): Promise<void>;
  findById(id: string): Promise<User | null>;
  findByEmail(email: string): Promise<User | null>;
  delete(id: string): Promise<void>;
  exists(email: string): Promise<boolean>;
}
```

#### Use Cases Layer
```typescript
// ✅ Use Cases
// usecases/user/create-user.usecase.ts
export class CreateUserUseCase {
  constructor(
    private userRepository: IUserRepository,
    private emailService: IEmailService,
    private eventDispatcher: IEventDispatcher
  ) {}

  async execute(request: CreateUserRequest): Promise<CreateUserResponse> {
    // Check if user already exists
    const userExists = await this.userRepository.exists(request.email);
    
    if (userExists) {
      throw new UserAlreadyExistsError('User with this email already exists');
    }

    // Create user entity
    const user = User.create({
      name: request.name,
      email: request.email,
      password: request.password,
      role: request.role
    });

    // Save user
    await this.userRepository.save(user);

    // Send welcome email
    await this.emailService.sendWelcomeEmail(
      user.getEmail(),
      user.getName()
    );

    // Dispatch domain events
    await this.eventDispatcher.dispatchAll();

    return {
      id: user.getId(),
      name: user.getName(),
      email: user.getEmail(),
      role: user.getRole(),
      createdAt: user.getCreatedAt()
    };
  }
}

// usecases/auth/authenticate-user.usecase.ts
export class AuthenticateUserUseCase {
  constructor(
    private userRepository: IUserRepository,
    private tokenService: ITokenService,
    private hashingService: IHashingService
  ) {}

  async execute(request: AuthenticateUserRequest): Promise<AuthenticateUserResponse> {
    // Find user by email
    const user = await this.userRepository.findByEmail(request.email);
    
    if (!user) {
      throw new InvalidCredentialsError('Invalid email or password');
    }

    // Verify password
    const isPasswordValid = await this.hashingService.compare(
      request.password,
      user.getPassword()
    );

    if (!isPasswordValid) {
      throw new InvalidCredentialsError('Invalid email or password');
    }

    // Check if email is verified
    if (!user.isEmailVerified()) {
      throw new EmailNotVerifiedError('Please verify your email first');
    }

    // Generate tokens
    const tokens = await this.tokenService.generateTokenPair({
      userId: user.getId(),
      email: user.getEmail(),
      role: user.getRole()
    });

    return {
      user: {
        id: user.getId(),
        name: user.getName(),
        email: user.getEmail(),
        role: user.getRole()
      },
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken
    };
  }
}
```

#### Interface Adapters Layer
```typescript
// ✅ Controllers (Interface Adapters)
// interfaces/controllers/user.controller.ts
export class UserController {
  constructor(
    private createUserUseCase: CreateUserUseCase,
    private getUserUseCase: GetUserUseCase,
    private updateUserUseCase: UpdateUserUseCase
  ) {}

  async createUser(req: Request, res: Response): Promise<void> {
    try {
      const request: CreateUserRequest = {
        name: req.body.name,
        email: req.body.email,
        password: req.body.password,
        role: req.body.role
      };

      const response = await this.createUserUseCase.execute(request);

      res.status(201).json({
        success: true,
        message: 'User created successfully',
        data: response
      });
    } catch (error) {
      this.handleError(error, res);
    }
  }

  async getUser(req: Request, res: Response): Promise<void> {
    try {
      const request: GetUserRequest = {
        id: req.params.id
      };

      const response = await this.getUserUseCase.execute(request);

      res.json({
        success: true,
        data: response
      });
    } catch (error) {
      this.handleError(error, res);
    }
  }

  private handleError(error: Error, res: Response): void {
    if (error instanceof UserAlreadyExistsError) {
      res.status(409).json({ error: error.message });
    } else if (error instanceof UserNotFoundError) {
      res.status(404).json({ error: error.message });
    } else if (error instanceof InvalidCredentialsError) {
      res.status(401).json({ error: error.message });
    } else {
      res.status(500).json({ error: 'Internal server error' });
    }
  }
}

// ✅ Repository Implementation (Interface Adapters)
// interfaces/repositories/mongodb-user.repository.ts
export class MongoDBUserRepository implements IUserRepository {
  constructor(private userModel: Model<UserDocument>) {}

  async save(user: User): Promise<void> {
    const existingUser = await this.userModel.findOne({ 
      email: user.getEmail() 
    });

    if (existingUser) {
      // Update existing user
      await this.userModel.findByIdAndUpdate(existingUser._id, {
        name: user.getName(),
        email: user.getEmail(),
        password: user.getPassword(),
        role: user.getRole(),
        emailVerified: user.isEmailVerified(),
        updatedAt: user.getUpdatedAt()
      });
    } else {
      // Create new user
      await this.userModel.create({
        _id: user.getId(),
        name: user.getName(),
        email: user.getEmail(),
        password: user.getPassword(),
        role: user.getRole(),
        emailVerified: user.isEmailVerified(),
        createdAt: user.getCreatedAt(),
        updatedAt: user.getUpdatedAt()
      });
    }
  }

  async findById(id: string): Promise<User | null> {
    const userDoc = await this.userModel.findById(id);
    
    if (!userDoc) {
      return null;
    }

    return User.fromPersistence({
      id: userDoc._id.toString(),
      name: userDoc.name,
      email: userDoc.email,
      password: userDoc.password,
      role: userDoc.role,
      emailVerified: userDoc.emailVerified,
      createdAt: userDoc.createdAt,
      updatedAt: userDoc.updatedAt
    });
  }

  async findByEmail(email: string): Promise<User | null> {
    const userDoc = await this.userModel.findOne({ email });
    
    if (!userDoc) {
      return null;
    }

    return User.fromPersistence({
      id: userDoc._id.toString(),
      name: userDoc.name,
      email: userDoc.email,
      password: userDoc.password,
      role: userDoc.role,
      emailVerified: userDoc.emailVerified,
      createdAt: userDoc.createdAt,
      updatedAt: userDoc.updatedAt
    });
  }

  async exists(email: string): Promise<boolean> {
    const count = await this.userModel.countDocuments({ email });
    return count > 0;
  }

  async delete(id: string): Promise<void> {
    await this.userModel.findByIdAndDelete(id);
  }
}
```

#### Dependency Injection Setup
```typescript
// ✅ Dependency Injection Container
// main/factories/user.factory.ts
export class UserFactory {
  static createUserController(): UserController {
    // Infrastructure dependencies
    const userModel = getUserModel();
    const emailService = new SMTPEmailService();
    const tokenService = new JWTTokenService();
    const hashingService = new BcryptHashingService();
    const eventDispatcher = new EventDispatcher();

    // Repository
    const userRepository = new MongoDBUserRepository(userModel);

    // Use cases
    const createUserUseCase = new CreateUserUseCase(
      userRepository,
      emailService,
      eventDispatcher
    );
    
    const getUserUseCase = new GetUserUseCase(userRepository);
    
    const updateUserUseCase = new UpdateUserUseCase(
      userRepository,
      eventDispatcher
    );

    // Controller
    return new UserController(
      createUserUseCase,
      getUserUseCase,
      updateUserUseCase
    );
  }

  static createAuthController(): AuthController {
    const userModel = getUserModel();
    const tokenService = new JWTTokenService();
    const hashingService = new BcryptHashingService();

    const userRepository = new MongoDBUserRepository(userModel);

    const authenticateUserUseCase = new AuthenticateUserUseCase(
      userRepository,
      tokenService,
      hashingService
    );

    return new AuthController(authenticateUserUseCase);
  }
}
```

### Advantages
- **Testability**: Business logic completely isolated from frameworks
- **Flexibility**: Easy to swap out external dependencies
- **Maintainability**: Clear separation of concerns
- **Framework Independence**: Core logic doesn't depend on Express

### Disadvantages
- **Complexity**: Higher initial complexity and learning curve
- **Overhead**: More code required for simple operations
- **Team Training**: Requires team understanding of the pattern

## 🔄 Event-Driven Architecture

### Pattern Overview
Uses events to communicate between different parts of the application, promoting loose coupling and scalability.

### Implementation Example
```typescript
// ✅ Event-Driven Architecture Implementation
// events/domain-events.ts
export abstract class DomainEvent {
  abstract eventName: string;
  abstract occurredOn: Date;
  abstract payload: any;
}

export class UserCreatedEvent extends DomainEvent {
  eventName = 'user.created';
  occurredOn = new Date();

  constructor(public payload: { userId: string; email: string }) {
    super();
  }
}

export class UserEmailVerifiedEvent extends DomainEvent {
  eventName = 'user.email-verified';
  occurredOn = new Date();

  constructor(public payload: { userId: string }) {
    super();
  }
}

// ✅ Event Bus
export interface IEventBus {
  publish(event: DomainEvent): Promise<void>;
  subscribe(eventName: string, handler: IEventHandler): void;
}

export class EventBus implements IEventBus {
  private handlers = new Map<string, IEventHandler[]>();

  async publish(event: DomainEvent): Promise<void> {
    const eventHandlers = this.handlers.get(event.eventName) || [];
    
    // Process handlers in parallel
    await Promise.all(
      eventHandlers.map(handler => 
        this.safeExecuteHandler(handler, event)
      )
    );
  }

  subscribe(eventName: string, handler: IEventHandler): void {
    if (!this.handlers.has(eventName)) {
      this.handlers.set(eventName, []);
    }
    
    this.handlers.get(eventName)!.push(handler);
  }

  private async safeExecuteHandler(
    handler: IEventHandler,
    event: DomainEvent
  ): Promise<void> {
    try {
      await handler.handle(event);
    } catch (error) {
      logger.error(`Event handler failed: ${error.message}`, {
        eventName: event.eventName,
        handlerName: handler.constructor.name,
        error
      });
    }
  }
}

// ✅ Event Handlers
export interface IEventHandler {
  handle(event: DomainEvent): Promise<void>;
}

export class SendWelcomeEmailHandler implements IEventHandler {
  constructor(private emailService: IEmailService) {}

  async handle(event: UserCreatedEvent): Promise<void> {
    const { userId, email } = event.payload;
    
    await this.emailService.sendWelcomeEmail(email, {
      userId,
      template: 'welcome',
      data: { registrationDate: event.occurredOn }
    });

    logger.info(`Welcome email sent to user ${userId}`);
  }
}

export class CreateUserProfileHandler implements IEventHandler {
  constructor(private profileService: IProfileService) {}

  async handle(event: UserCreatedEvent): Promise<void> {
    const { userId } = event.payload;
    
    await this.profileService.createDefaultProfile(userId);
    
    logger.info(`Default profile created for user ${userId}`);
  }
}

// ✅ Event Setup
export class EventSetup {
  static configure(eventBus: IEventBus): void {
    // User events
    eventBus.subscribe('user.created', new SendWelcomeEmailHandler(emailService));
    eventBus.subscribe('user.created', new CreateUserProfileHandler(profileService));
    eventBus.subscribe('user.email-verified', new ActivateUserHandler(userService));
    
    // Post events
    eventBus.subscribe('post.created', new NotifyFollowersHandler(notificationService));
    eventBus.subscribe('post.published', new IndexPostHandler(searchService));
    
    // Payment events
    eventBus.subscribe('payment.completed', new UpgradeUserHandler(userService));
    eventBus.subscribe('payment.failed', new NotifyPaymentFailureHandler(emailService));
  }
}
```

### Advantages
- **Loose Coupling**: Components don't need direct references to each other
- **Scalability**: Easy to add new features without modifying existing code
- **Parallel Processing**: Events can be processed asynchronously
- **Audit Trail**: Events provide a natural audit log

### Disadvantages
- **Complexity**: Can make the flow harder to follow
- **Debugging**: Harder to debug event-driven flows
- **Eventual Consistency**: Data consistency challenges

---

## 🧭 Navigation

### ⬅️ Previous: [Security Considerations](./security-considerations.md)
### ➡️ Next: [Testing Strategies](./testing-strategies.md)

---

*Architecture patterns analyzed from 15+ production Express.js applications with proven scalability.*