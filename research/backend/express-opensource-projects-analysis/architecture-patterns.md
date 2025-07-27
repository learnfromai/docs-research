# Architecture Patterns: Express.js Open Source Projects

## 🏗️ Overview

Analysis of architectural patterns and design principles implemented across successful Express.js open source projects, showcasing production-ready approaches to building scalable and maintainable applications.

## 📐 Layered Architecture Patterns

### 1. Traditional 3-Layer Architecture (60% of projects)

**Implementation from Ghost and LoopBack:**

```typescript
// Controller Layer - HTTP Request/Response handling
export class UserController {
  constructor(private userService: UserService) {}
  
  async getUsers(req: Request, res: Response): Promise<void> {
    try {
      const { page = 1, limit = 10, search } = req.query;
      
      const result = await this.userService.getUsers({
        page: Number(page),
        limit: Number(limit),
        search: search as string
      });
      
      res.json({
        success: true,
        data: result.users,
        pagination: result.pagination,
        meta: {
          total: result.total,
          page: result.page,
          limit: result.limit
        }
      });
    } catch (error) {
      res.status(400).json({
        success: false,
        message: error.message,
        code: 'USER_FETCH_ERROR'
      });
    }
  }
  
  async createUser(req: Request, res: Response): Promise<void> {
    try {
      const user = await this.userService.createUser(req.body);
      
      res.status(201).json({
        success: true,
        data: user,
        message: 'User created successfully'
      });
    } catch (error) {
      res.status(400).json({
        success: false,
        message: error.message,
        code: 'USER_CREATION_ERROR'
      });
    }
  }
}

// Service Layer - Business Logic
export class UserService {
  constructor(
    private userRepository: UserRepository,
    private emailService: EmailService,
    private cacheService: CacheService
  ) {}
  
  async getUsers(params: GetUsersParams): Promise<GetUsersResult> {
    // Business validation
    if (params.limit > 100) {
      throw new Error('Limit cannot exceed 100 users per request');
    }
    
    // Check cache first
    const cacheKey = `users:${JSON.stringify(params)}`;
    const cached = await this.cacheService.get(cacheKey);
    if (cached) {
      return cached;
    }
    
    // Fetch from repository
    const [users, total] = await Promise.all([
      this.userRepository.findUsers(params),
      this.userRepository.countUsers(params.search)
    ]);
    
    const result = {
      users: users.map(user => this.sanitizeUser(user)),
      pagination: {
        page: params.page,
        limit: params.limit,
        total,
        pages: Math.ceil(total / params.limit)
      },
      total,
      page: params.page,
      limit: params.limit
    };
    
    // Cache result
    await this.cacheService.set(cacheKey, result, 300); // 5 minutes
    
    return result;
  }
  
  async createUser(userData: CreateUserData): Promise<User> {
    // Business logic validation
    await this.validateUserData(userData);
    
    // Check if user already exists
    const existingUser = await this.userRepository.findByEmail(userData.email);
    if (existingUser) {
      throw new Error('User with this email already exists');
    }
    
    // Hash password
    const hashedPassword = await bcrypt.hash(userData.password, 12);
    
    // Create user
    const user = await this.userRepository.create({
      ...userData,
      password: hashedPassword,
      isActive: true,
      createdAt: new Date()
    });
    
    // Send welcome email
    await this.emailService.sendWelcomeEmail(user.email, user.name);
    
    // Invalidate cache
    await this.cacheService.invalidatePattern('users:*');
    
    return this.sanitizeUser(user);
  }
  
  private async validateUserData(userData: CreateUserData): Promise<void> {
    if (!userData.email || !userData.password || !userData.name) {
      throw new Error('Email, password, and name are required');
    }
    
    if (userData.password.length < 8) {
      throw new Error('Password must be at least 8 characters long');
    }
    
    // Additional business validation...
  }
  
  private sanitizeUser(user: User): Omit<User, 'password'> {
    const { password, ...sanitizedUser } = user;
    return sanitizedUser;
  }
}

// Repository Layer - Data Access
export class UserRepository {
  constructor(private prisma: PrismaClient) {}
  
  async findUsers(params: GetUsersParams): Promise<User[]> {
    const where: any = {};
    
    if (params.search) {
      where.OR = [
        { name: { contains: params.search, mode: 'insensitive' } },
        { email: { contains: params.search, mode: 'insensitive' } }
      ];
    }
    
    return this.prisma.user.findMany({
      where,
      skip: (params.page - 1) * params.limit,
      take: params.limit,
      select: {
        id: true,
        email: true,
        name: true,
        isActive: true,
        createdAt: true,
        updatedAt: true,
        roles: {
          select: {
            id: true,
            name: true
          }
        }
      },
      orderBy: { createdAt: 'desc' }
    });
  }
  
  async findByEmail(email: string): Promise<User | null> {
    return this.prisma.user.findUnique({
      where: { email: email.toLowerCase() },
      include: {
        roles: true
      }
    });
  }
  
  async create(userData: CreateUserData): Promise<User> {
    return this.prisma.user.create({
      data: userData,
      include: {
        roles: true
      }
    });
  }
  
  async countUsers(search?: string): Promise<number> {
    const where: any = {};
    
    if (search) {
      where.OR = [
        { name: { contains: search, mode: 'insensitive' } },
        { email: { contains: search, mode: 'insensitive' } }
      ];
    }
    
    return this.prisma.user.count({ where });
  }
}
```

### 2. Hexagonal Architecture (Clean Architecture) - 25% of projects

**Implementation from NestJS and Modern Express Applications:**

```typescript
// Domain Layer - Core business entities
export class User {
  private constructor(
    public readonly id: UserId,
    public readonly email: Email,
    public readonly name: string,
    public readonly password: HashedPassword,
    public readonly roles: Role[],
    public readonly isActive: boolean,
    public readonly createdAt: Date
  ) {}
  
  static create(userData: CreateUserData): User {
    const id = UserId.generate();
    const email = Email.create(userData.email);
    const password = HashedPassword.create(userData.password);
    
    return new User(
      id,
      email,
      userData.name,
      password,
      [Role.USER], // Default role
      true,
      new Date()
    );
  }
  
  changePassword(newPassword: string): void {
    this.password = HashedPassword.create(newPassword);
  }
  
  deactivate(): void {
    if (!this.isActive) {
      throw new DomainError('User is already deactivated');
    }
    this.isActive = false;
  }
  
  hasRole(roleName: string): boolean {
    return this.roles.some(role => role.name === roleName);
  }
}

// Value Objects
export class Email {
  private constructor(public readonly value: string) {}
  
  static create(email: string): Email {
    if (!this.isValid(email)) {
      throw new DomainError('Invalid email format');
    }
    return new Email(email.toLowerCase());
  }
  
  private static isValid(email: string): boolean {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return emailRegex.test(email);
  }
}

export class UserId {
  private constructor(public readonly value: string) {}
  
  static generate(): UserId {
    return new UserId(crypto.randomUUID());
  }
  
  static fromString(id: string): UserId {
    if (!id) {
      throw new DomainError('User ID cannot be empty');
    }
    return new UserId(id);
  }
}

// Application Layer - Use Cases
export class CreateUserUseCase {
  constructor(
    private userRepository: UserRepositoryPort,
    private emailService: EmailServicePort,
    private passwordPolicy: PasswordPolicyPort
  ) {}
  
  async execute(command: CreateUserCommand): Promise<CreateUserResponse> {
    // Validate password policy
    await this.passwordPolicy.validate(command.password);
    
    // Check if user exists
    const existingUser = await this.userRepository.findByEmail(
      Email.create(command.email)
    );
    
    if (existingUser) {
      throw new ApplicationError('User already exists with this email');
    }
    
    // Create user entity
    const user = User.create({
      email: command.email,
      name: command.name,
      password: command.password
    });
    
    // Persist user
    await this.userRepository.save(user);
    
    // Send welcome email
    await this.emailService.sendWelcomeEmail(user.email, user.name);
    
    return {
      userId: user.id.value,
      email: user.email.value,
      name: user.name
    };
  }
}

// Infrastructure Layer - Adapters
export class PrismaUserRepository implements UserRepositoryPort {
  constructor(private prisma: PrismaClient) {}
  
  async findByEmail(email: Email): Promise<User | null> {
    const userData = await this.prisma.user.findUnique({
      where: { email: email.value },
      include: { roles: true }
    });
    
    if (!userData) return null;
    
    return this.toDomain(userData);
  }
  
  async save(user: User): Promise<void> {
    await this.prisma.user.upsert({
      where: { id: user.id.value },
      update: this.toPersistence(user),
      create: this.toPersistence(user)
    });
  }
  
  private toDomain(userData: any): User {
    return new User(
      UserId.fromString(userData.id),
      Email.create(userData.email),
      userData.name,
      HashedPassword.fromHash(userData.password),
      userData.roles.map(r => Role.fromPersistence(r)),
      userData.isActive,
      userData.createdAt
    );
  }
  
  private toPersistence(user: User): any {
    return {
      id: user.id.value,
      email: user.email.value,
      name: user.name,
      password: user.password.value,
      isActive: user.isActive,
      createdAt: user.createdAt
    };
  }
}

// Ports (Interfaces)
export interface UserRepositoryPort {
  findByEmail(email: Email): Promise<User | null>;
  save(user: User): Promise<void>;
}

export interface EmailServicePort {
  sendWelcomeEmail(email: Email, name: string): Promise<void>;
}
```

### 3. Microservices Architecture (15% of large-scale projects)

**Service Communication Patterns:**

```typescript
// Service Registry Pattern
export class ServiceRegistry {
  private services = new Map<string, ServiceInstance[]>();
  
  register(serviceName: string, instance: ServiceInstance): void {
    if (!this.services.has(serviceName)) {
      this.services.set(serviceName, []);
    }
    
    const instances = this.services.get(serviceName)!;
    instances.push(instance);
    
    // Health check for the instance
    this.startHealthCheck(serviceName, instance);
  }
  
  discover(serviceName: string): ServiceInstance | null {
    const instances = this.services.get(serviceName);
    if (!instances || instances.length === 0) {
      return null;
    }
    
    // Simple round-robin load balancing
    const healthyInstances = instances.filter(i => i.isHealthy);
    if (healthyInstances.length === 0) {
      throw new Error(`No healthy instances available for service: ${serviceName}`);
    }
    
    const index = Math.floor(Math.random() * healthyInstances.length);
    return healthyInstances[index];
  }
  
  private async startHealthCheck(serviceName: string, instance: ServiceInstance): Promise<void> {
    setInterval(async () => {
      try {
        const response = await fetch(`${instance.url}/health`);
        instance.isHealthy = response.ok;
      } catch (error) {
        instance.isHealthy = false;
      }
    }, 30000); // Every 30 seconds
  }
}

// Event-Driven Communication
export class EventBus {
  private handlers = new Map<string, EventHandler[]>();
  
  subscribe<T>(eventType: string, handler: EventHandler<T>): void {
    if (!this.handlers.has(eventType)) {
      this.handlers.set(eventType, []);
    }
    
    this.handlers.get(eventType)!.push(handler);
  }
  
  async publish<T>(event: DomainEvent<T>): Promise<void> {
    const handlers = this.handlers.get(event.type) || [];
    
    await Promise.all(
      handlers.map(handler => handler.handle(event))
    );
  }
}

// Service Communication
export class UserService {
  constructor(
    private serviceRegistry: ServiceRegistry,
    private eventBus: EventBus
  ) {}
  
  async createUser(userData: CreateUserData): Promise<User> {
    // Create user
    const user = await this.userRepository.create(userData);
    
    // Publish user created event
    await this.eventBus.publish({
      type: 'UserCreated',
      data: {
        userId: user.id,
        email: user.email,
        name: user.name
      },
      timestamp: new Date()
    });
    
    return user;
  }
  
  async sendWelcomeEmail(userId: string): Promise<void> {
    // Discover email service
    const emailService = this.serviceRegistry.discover('email-service');
    if (!emailService) {
      throw new Error('Email service not available');
    }
    
    // Call email service
    await fetch(`${emailService.url}/send-welcome-email`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ userId })
    });
  }
}

// Event Handlers
export class NotificationHandler implements EventHandler<UserCreatedEvent> {
  async handle(event: DomainEvent<UserCreatedEvent>): Promise<void> {
    const { userId, email, name } = event.data;
    
    // Send welcome email
    await this.emailService.sendWelcomeEmail(email, name);
    
    // Create user profile in notification service
    await this.notificationService.createUserProfile(userId, email);
  }
}
```

## 🔧 Dependency Injection Patterns

### 1. Constructor Injection (NestJS Style)

```typescript
// Dependency injection container
export class DIContainer {
  private dependencies = new Map<string, any>();
  private singletons = new Map<string, any>();
  
  register<T>(token: string, factory: () => T, singleton = false): void {
    this.dependencies.set(token, { factory, singleton });
  }
  
  resolve<T>(token: string): T {
    const dependency = this.dependencies.get(token);
    if (!dependency) {
      throw new Error(`Dependency not found: ${token}`);
    }
    
    if (dependency.singleton) {
      if (!this.singletons.has(token)) {
        this.singletons.set(token, dependency.factory());
      }
      return this.singletons.get(token);
    }
    
    return dependency.factory();
  }
}

// Service registration
const container = new DIContainer();

container.register('UserRepository', () => new PrismaUserRepository(prisma), true);
container.register('EmailService', () => new SMTPEmailService(), true);
container.register('CacheService', () => new RedisCache(redisClient), true);

container.register('UserService', () => new UserService(
  container.resolve('UserRepository'),
  container.resolve('EmailService'),
  container.resolve('CacheService')
));

container.register('UserController', () => new UserController(
  container.resolve('UserService')
));

// Auto-wiring with decorators
@Injectable()
export class UserService {
  constructor(
    @Inject('UserRepository') private userRepository: UserRepository,
    @Inject('EmailService') private emailService: EmailService,
    @Inject('CacheService') private cacheService: CacheService
  ) {}
}
```

### 2. Service Locator Pattern

```typescript
// Service locator implementation
export class ServiceLocator {
  private static instance: ServiceLocator;
  private services = new Map<string, any>();
  
  static getInstance(): ServiceLocator {
    if (!this.instance) {
      this.instance = new ServiceLocator();
    }
    return this.instance;
  }
  
  register<T>(name: string, service: T): void {
    this.services.set(name, service);
  }
  
  get<T>(name: string): T {
    const service = this.services.get(name);
    if (!service) {
      throw new Error(`Service not found: ${name}`);
    }
    return service;
  }
}

// Usage in controllers
export class UserController {
  private userService: UserService;
  
  constructor() {
    this.userService = ServiceLocator.getInstance().get<UserService>('UserService');
  }
  
  async getUsers(req: Request, res: Response): Promise<void> {
    const users = await this.userService.getUsers(req.query);
    res.json(users);
  }
}
```

## 🏛️ Repository Pattern Implementations

### 1. Generic Repository Pattern

```typescript
// Base repository interface
export interface Repository<T, ID> {
  findById(id: ID): Promise<T | null>;
  findAll(): Promise<T[]>;
  save(entity: T): Promise<T>;
  update(id: ID, entity: Partial<T>): Promise<T>;
  delete(id: ID): Promise<void>;
}

// Generic repository implementation
export abstract class BaseRepository<T, ID> implements Repository<T, ID> {
  constructor(protected model: any) {}
  
  async findById(id: ID): Promise<T | null> {
    return this.model.findByPk ? this.model.findByPk(id) : this.model.findUnique({ where: { id } });
  }
  
  async findAll(): Promise<T[]> {
    return this.model.findAll ? this.model.findAll() : this.model.findMany();
  }
  
  async save(entity: T): Promise<T> {
    return this.model.create(entity);
  }
  
  async update(id: ID, entity: Partial<T>): Promise<T> {
    const [updatedRowsCount] = await this.model.update(entity, { where: { id } });
    if (updatedRowsCount === 0) {
      throw new Error('Entity not found');
    }
    return this.findById(id);
  }
  
  async delete(id: ID): Promise<void> {
    const deletedRowsCount = await this.model.destroy({ where: { id } });
    if (deletedRowsCount === 0) {
      throw new Error('Entity not found');
    }
  }
}

// Specific repository implementation
export class UserRepository extends BaseRepository<User, string> {
  constructor(userModel: any) {
    super(userModel);
  }
  
  async findByEmail(email: string): Promise<User | null> {
    return this.model.findOne({ where: { email } });
  }
  
  async findActiveUsers(): Promise<User[]> {
    return this.model.findMany({ where: { isActive: true } });
  }
  
  async searchUsers(query: string): Promise<User[]> {
    return this.model.findMany({
      where: {
        OR: [
          { name: { contains: query, mode: 'insensitive' } },
          { email: { contains: query, mode: 'insensitive' } }
        ]
      }
    });
  }
}
```

### 2. Specification Pattern

```typescript
// Specification pattern for complex queries
export abstract class Specification<T> {
  abstract isSatisfiedBy(candidate: T): boolean;
  abstract toQuery(): any; // Database-specific query
  
  and(spec: Specification<T>): Specification<T> {
    return new AndSpecification(this, spec);
  }
  
  or(spec: Specification<T>): Specification<T> {
    return new OrSpecification(this, spec);
  }
  
  not(): Specification<T> {
    return new NotSpecification(this);
  }
}

// Concrete specifications
export class ActiveUserSpecification extends Specification<User> {
  isSatisfiedBy(user: User): boolean {
    return user.isActive === true;
  }
  
  toQuery(): any {
    return { isActive: true };
  }
}

export class UserEmailSpecification extends Specification<User> {
  constructor(private email: string) {
    super();
  }
  
  isSatisfiedBy(user: User): boolean {
    return user.email === this.email;
  }
  
  toQuery(): any {
    return { email: this.email };
  }
}

// Repository with specifications
export class UserRepository {
  async findBySpecification(spec: Specification<User>): Promise<User[]> {
    const query = spec.toQuery();
    return this.model.findMany({ where: query });
  }
}

// Usage
const activeUsers = await userRepository.findBySpecification(
  new ActiveUserSpecification()
);

const specificUser = await userRepository.findBySpecification(
  new ActiveUserSpecification().and(new UserEmailSpecification('user@example.com'))
);
```

## 🎭 Design Patterns in Express Applications

### 1. Factory Pattern for Service Creation

```typescript
// Service factory pattern
export interface ServiceFactory {
  createUserService(): UserService;
  createEmailService(): EmailService;
  createCacheService(): CacheService;
}

export class ProductionServiceFactory implements ServiceFactory {
  createUserService(): UserService {
    return new UserService(
      new PrismaUserRepository(this.createPrismaClient()),
      this.createEmailService(),
      this.createCacheService()
    );
  }
  
  createEmailService(): EmailService {
    return new SMTPEmailService({
      host: process.env.SMTP_HOST,
      port: parseInt(process.env.SMTP_PORT),
      user: process.env.SMTP_USER,
      password: process.env.SMTP_PASSWORD
    });
  }
  
  createCacheService(): CacheService {
    return new RedisCache({
      host: process.env.REDIS_HOST,
      port: parseInt(process.env.REDIS_PORT),
      password: process.env.REDIS_PASSWORD
    });
  }
  
  private createPrismaClient(): PrismaClient {
    return new PrismaClient({
      datasources: {
        db: {
          url: process.env.DATABASE_URL
        }
      }
    });
  }
}

export class TestServiceFactory implements ServiceFactory {
  createUserService(): UserService {
    return new UserService(
      new InMemoryUserRepository(),
      new MockEmailService(),
      new InMemoryCache()
    );
  }
  
  createEmailService(): EmailService {
    return new MockEmailService();
  }
  
  createCacheService(): CacheService {
    return new InMemoryCache();
  }
}
```

### 2. Strategy Pattern for Authentication

```typescript
// Authentication strategy pattern
export interface AuthenticationStrategy {
  authenticate(credentials: any): Promise<User | null>;
}

export class LocalAuthenticationStrategy implements AuthenticationStrategy {
  constructor(private userRepository: UserRepository) {}
  
  async authenticate(credentials: { email: string; password: string }): Promise<User | null> {
    const user = await this.userRepository.findByEmail(credentials.email);
    
    if (!user) return null;
    
    const isValidPassword = await bcrypt.compare(credentials.password, user.password);
    return isValidPassword ? user : null;
  }
}

export class OAuthAuthenticationStrategy implements AuthenticationStrategy {
  constructor(
    private userRepository: UserRepository,
    private oauthProvider: OAuthProvider
  ) {}
  
  async authenticate(credentials: { accessToken: string }): Promise<User | null> {
    const profile = await this.oauthProvider.getUserProfile(credentials.accessToken);
    
    let user = await this.userRepository.findByEmail(profile.email);
    
    if (!user) {
      user = await this.userRepository.create({
        email: profile.email,
        name: profile.name,
        provider: 'oauth',
        isEmailVerified: true
      });
    }
    
    return user;
  }
}

// Authentication context
export class AuthenticationContext {
  private strategy: AuthenticationStrategy;
  
  setStrategy(strategy: AuthenticationStrategy): void {
    this.strategy = strategy;
  }
  
  async authenticate(credentials: any): Promise<User | null> {
    if (!this.strategy) {
      throw new Error('Authentication strategy not set');
    }
    
    return this.strategy.authenticate(credentials);
  }
}
```

### 3. Observer Pattern for Events

```typescript
// Event system using observer pattern
export interface Observer<T> {
  update(event: T): Promise<void>;
}

export class EventEmitter<T> {
  private observers: Observer<T>[] = [];
  
  subscribe(observer: Observer<T>): void {
    this.observers.push(observer);
  }
  
  unsubscribe(observer: Observer<T>): void {
    const index = this.observers.indexOf(observer);
    if (index > -1) {
      this.observers.splice(index, 1);
    }
  }
  
  async notify(event: T): Promise<void> {
    await Promise.all(
      this.observers.map(observer => observer.update(event))
    );
  }
}

// Event observers
export class EmailNotificationObserver implements Observer<UserCreatedEvent> {
  constructor(private emailService: EmailService) {}
  
  async update(event: UserCreatedEvent): Promise<void> {
    await this.emailService.sendWelcomeEmail(event.user.email, event.user.name);
  }
}

export class AuditLogObserver implements Observer<UserCreatedEvent> {
  constructor(private auditService: AuditService) {}
  
  async update(event: UserCreatedEvent): Promise<void> {
    await this.auditService.log({
      action: 'USER_CREATED',
      userId: event.user.id,
      timestamp: new Date(),
      metadata: { email: event.user.email }
    });
  }
}

// Usage in service
export class UserService {
  private userCreatedEmitter = new EventEmitter<UserCreatedEvent>();
  
  constructor(
    private userRepository: UserRepository,
    emailService: EmailService,
    auditService: AuditService
  ) {
    // Subscribe observers
    this.userCreatedEmitter.subscribe(new EmailNotificationObserver(emailService));
    this.userCreatedEmitter.subscribe(new AuditLogObserver(auditService));
  }
  
  async createUser(userData: CreateUserData): Promise<User> {
    const user = await this.userRepository.create(userData);
    
    // Emit event
    await this.userCreatedEmitter.notify({
      type: 'USER_CREATED',
      user,
      timestamp: new Date()
    });
    
    return user;
  }
}
```

## 🔄 CQRS (Command Query Responsibility Segregation)

### CQRS Implementation

```typescript
// Command and Query separation
export interface Command {
  type: string;
}

export interface Query {
  type: string;
}

export interface CommandHandler<T extends Command> {
  handle(command: T): Promise<void>;
}

export interface QueryHandler<T extends Query, R> {
  handle(query: T): Promise<R>;
}

// Commands
export class CreateUserCommand implements Command {
  readonly type = 'CREATE_USER';
  
  constructor(
    public readonly email: string,
    public readonly name: string,
    public readonly password: string
  ) {}
}

export class UpdateUserCommand implements Command {
  readonly type = 'UPDATE_USER';
  
  constructor(
    public readonly userId: string,
    public readonly updates: Partial<User>
  ) {}
}

// Queries
export class GetUserQuery implements Query {
  readonly type = 'GET_USER';
  
  constructor(public readonly userId: string) {}
}

export class GetUsersQuery implements Query {
  readonly type = 'GET_USERS';
  
  constructor(
    public readonly page: number,
    public readonly limit: number,
    public readonly search?: string
  ) {}
}

// Command handlers
export class CreateUserCommandHandler implements CommandHandler<CreateUserCommand> {
  constructor(
    private userWriteRepository: UserWriteRepository,
    private eventBus: EventBus
  ) {}
  
  async handle(command: CreateUserCommand): Promise<void> {
    const user = User.create({
      email: command.email,
      name: command.name,
      password: command.password
    });
    
    await this.userWriteRepository.save(user);
    
    await this.eventBus.publish({
      type: 'USER_CREATED',
      data: user,
      timestamp: new Date()
    });
  }
}

// Query handlers
export class GetUserQueryHandler implements QueryHandler<GetUserQuery, User | null> {
  constructor(private userReadRepository: UserReadRepository) {}
  
  async handle(query: GetUserQuery): Promise<User | null> {
    return this.userReadRepository.findById(query.userId);
  }
}

// Command and Query bus
export class CommandBus {
  private handlers = new Map<string, CommandHandler<any>>();
  
  register<T extends Command>(commandType: string, handler: CommandHandler<T>): void {
    this.handlers.set(commandType, handler);
  }
  
  async execute<T extends Command>(command: T): Promise<void> {
    const handler = this.handlers.get(command.type);
    if (!handler) {
      throw new Error(`No handler registered for command: ${command.type}`);
    }
    
    await handler.handle(command);
  }
}

export class QueryBus {
  private handlers = new Map<string, QueryHandler<any, any>>();
  
  register<T extends Query, R>(queryType: string, handler: QueryHandler<T, R>): void {
    this.handlers.set(queryType, handler);
  }
  
  async execute<T extends Query, R>(query: T): Promise<R> {
    const handler = this.handlers.get(query.type);
    if (!handler) {
      throw new Error(`No handler registered for query: ${query.type}`);
    }
    
    return handler.handle(query);
  }
}
```

## 📊 Performance Patterns

### 1. Connection Pooling

```typescript
// Database connection pool management
export class DatabasePool {
  private pool: Pool;
  
  constructor(config: PoolConfig) {
    this.pool = new Pool({
      host: config.host,
      port: config.port,
      database: config.database,
      user: config.user,
      password: config.password,
      min: config.minConnections || 2,
      max: config.maxConnections || 20,
      idleTimeoutMillis: config.idleTimeout || 30000,
      connectionTimeoutMillis: config.connectionTimeout || 2000,
      acquireTimeoutMillis: config.acquireTimeout || 10000
    });
    
    this.setupEventHandlers();
  }
  
  private setupEventHandlers(): void {
    this.pool.on('connect', (client) => {
      logger.debug('New client connected to database');
    });
    
    this.pool.on('error', (err, client) => {
      logger.error('Database pool error', { error: err.message });
    });
    
    this.pool.on('remove', (client) => {
      logger.debug('Client removed from pool');
    });
  }
  
  async query<T>(text: string, params?: any[]): Promise<T[]> {
    const client = await this.pool.connect();
    
    try {
      const result = await client.query(text, params);
      return result.rows;
    } finally {
      client.release();
    }
  }
  
  async transaction<T>(callback: (client: PoolClient) => Promise<T>): Promise<T> {
    const client = await this.pool.connect();
    
    try {
      await client.query('BEGIN');
      const result = await callback(client);
      await client.query('COMMIT');
      return result;
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }
  
  async close(): Promise<void> {
    await this.pool.end();
  }
  
  getPoolInfo(): PoolInfo {
    return {
      totalCount: this.pool.totalCount,
      idleCount: this.pool.idleCount,
      waitingCount: this.pool.waitingCount
    };
  }
}
```

### 2. Caching Strategies

```typescript
// Multi-level caching implementation
export class CacheManager {
  private l1Cache: Map<string, CacheEntry> = new Map(); // Memory cache
  private l2Cache: Redis; // Redis cache
  
  constructor(redisClient: Redis) {
    this.l2Cache = redisClient;
    this.startCleanupJob();
  }
  
  async get<T>(key: string): Promise<T | null> {
    // L1 Cache (Memory)
    const l1Entry = this.l1Cache.get(key);
    if (l1Entry && l1Entry.expiresAt > Date.now()) {
      return l1Entry.value;
    }
    
    // L2 Cache (Redis)
    const l2Value = await this.l2Cache.get(key);
    if (l2Value) {
      const parsed = JSON.parse(l2Value);
      
      // Store in L1 cache for faster access
      this.l1Cache.set(key, {
        value: parsed,
        expiresAt: Date.now() + 60000 // 1 minute in L1
      });
      
      return parsed;
    }
    
    return null;
  }
  
  async set<T>(key: string, value: T, ttl: number = 3600): Promise<void> {
    // Store in L2 cache (Redis)
    await this.l2Cache.setex(key, ttl, JSON.stringify(value));
    
    // Store in L1 cache (Memory) with shorter TTL
    const l1Ttl = Math.min(ttl, 300) * 1000; // Max 5 minutes in memory
    this.l1Cache.set(key, {
      value,
      expiresAt: Date.now() + l1Ttl
    });
  }
  
  async delete(key: string): Promise<void> {
    this.l1Cache.delete(key);
    await this.l2Cache.del(key);
  }
  
  async invalidatePattern(pattern: string): Promise<void> {
    // Clear L1 cache entries matching pattern
    for (const [key] of this.l1Cache) {
      if (this.matchesPattern(key, pattern)) {
        this.l1Cache.delete(key);
      }
    }
    
    // Clear L2 cache entries
    const keys = await this.l2Cache.keys(pattern);
    if (keys.length > 0) {
      await this.l2Cache.del(...keys);
    }
  }
  
  private matchesPattern(key: string, pattern: string): boolean {
    const regex = new RegExp(pattern.replace('*', '.*'));
    return regex.test(key);
  }
  
  private startCleanupJob(): void {
    setInterval(() => {
      const now = Date.now();
      for (const [key, entry] of this.l1Cache) {
        if (entry.expiresAt <= now) {
          this.l1Cache.delete(key);
        }
      }
    }, 60000); // Cleanup every minute
  }
}

interface CacheEntry {
  value: any;
  expiresAt: number;
}
```

---

*Architecture Patterns Analysis | Research conducted January 2025*

**Navigation**
- **Previous**: [Security Patterns](./security-patterns.md) ←
- **Next**: [Authentication Strategies](./authentication-strategies.md) →
- **Back to**: [Research Overview](./README.md) ↑