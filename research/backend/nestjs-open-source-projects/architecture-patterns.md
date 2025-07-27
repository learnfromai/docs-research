# Architecture Patterns in NestJS Projects

## 🏗️ Overview

Analysis of architectural patterns, project structures, and design approaches used across 23+ production NestJS projects. This research identifies common patterns, best practices, and architectural decisions that enable scalable, maintainable applications.

---

## 📊 Architecture Distribution

Based on analyzed projects:
- **Modular Monolith**: 60% (14 projects)
- **Microservices**: 25% (6 projects)
- **Hybrid/Monorepo**: 15% (3 projects)

---

## 🏢 Modular Monolith Pattern

### Overview
Most popular pattern for NestJS applications, offering a balance between simplicity and scalability.

### Characteristics
- **Single deployment unit** with multiple modules
- **Clear module boundaries** with defined interfaces
- **Shared infrastructure** and cross-cutting concerns
- **Feature-based organization** around business domains

### Project Structure Example

**From brocoders/nestjs-boilerplate**:
```
src/
├── modules/                    # Business modules
│   ├── auth/                  # Authentication module
│   │   ├── auth.controller.ts
│   │   ├── auth.service.ts
│   │   ├── auth.module.ts
│   │   ├── strategies/        # Passport strategies
│   │   └── guards/           # Authentication guards
│   ├── users/                # User management
│   │   ├── users.controller.ts
│   │   ├── users.service.ts
│   │   ├── users.module.ts
│   │   ├── entities/         # User entities
│   │   └── dto/             # Data transfer objects
│   └── files/               # File management
├── common/                  # Shared utilities
│   ├── decorators/          # Custom decorators
│   ├── guards/             # Reusable guards
│   ├── interceptors/       # Cross-cutting concerns
│   ├── pipes/              # Validation pipes
│   └── filters/            # Exception filters
├── config/                 # Configuration
│   ├── database.config.ts
│   ├── auth.config.ts
│   └── app.config.ts
├── database/               # Database-related
│   ├── migrations/
│   ├── seeds/
│   └── factories/
└── utils/                  # Pure utility functions
```

### Module Design Pattern

**Feature Module Example**:
```typescript
@Module({
  imports: [
    TypeOrmModule.forFeature([User, UserProfile]),
    ConfigModule,
    EmailModule,
  ],
  controllers: [UsersController],
  providers: [
    UsersService,
    UserRepository,
    UserProfileService,
    {
      provide: 'USER_REPOSITORY',
      useClass: TypeOrmUserRepository,
    },
  ],
  exports: [UsersService], // Export only what other modules need
})
export class UsersModule {}
```

### Dependency Management

**Clear Module Boundaries**:
```typescript
// Users module should not directly import AuthModule
// Instead, use events or shared services

@Injectable()
export class UsersService {
  constructor(
    @Inject('USER_REPOSITORY') private userRepo: UserRepository,
    private eventEmitter: EventEmitter2, // For loose coupling
  ) {}

  async createUser(userData: CreateUserDto): Promise<User> {
    const user = await this.userRepo.save(userData);
    
    // Emit event instead of direct service call
    this.eventEmitter.emit('user.created', {
      userId: user.id,
      email: user.email,
    });
    
    return user;
  }
}

// Auth module listens to user events
@Injectable()
export class AuthService {
  @OnEvent('user.created')
  async handleUserCreated(payload: UserCreatedEvent) {
    // Send welcome email, create default permissions, etc.
  }
}
```

### Shared Module Pattern

**Common Module for Cross-Cutting Concerns**:
```typescript
@Global()
@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    LoggerModule.forRoot(),
    CacheModule.forRoot(),
  ],
  providers: [
    DatabaseService,
    EncryptionService,
    NotificationService,
    {
      provide: 'REDIS_CLIENT',
      useFactory: (config: ConfigService) => {
        return new Redis(config.get('REDIS_URL'));
      },
      inject: [ConfigService],
    },
  ],
  exports: [
    DatabaseService,
    EncryptionService,
    NotificationService,
    'REDIS_CLIENT',
  ],
})
export class CommonModule {}
```

---

## 🔄 Microservices Pattern

### Overview
Used in complex applications requiring independent scaling and deployment.

### Examples
- **Immich**: Photo management with ML services
- **Twenty**: CRM with separated concerns
- **Ultimate Backend**: Multi-tenant SaaS platform

### Service Architecture

**From Immich Project**:
```
services/
├── api/                    # Main API service
│   ├── src/
│   │   ├── controllers/
│   │   ├── services/
│   │   └── modules/
│   └── Dockerfile
├── machine-learning/       # Python ML service
│   ├── app/
│   │   ├── models/
│   │   └── api/
│   └── Dockerfile
├── microservices/         # Background processing
│   ├── src/
│   │   ├── processors/
│   │   └── queues/
│   └── Dockerfile
└── web/                   # Frontend application
```

### Inter-Service Communication

**Event-Driven Communication**:
```typescript
// Asset service publishes events
@Injectable()
export class AssetService {
  constructor(
    private eventBus: EventBus,
    private assetRepository: AssetRepository,
  ) {}

  async uploadAsset(file: UploadFile): Promise<Asset> {
    const asset = await this.assetRepository.save({
      originalPath: file.path,
      mimeType: file.mimeType,
      size: file.size,
    });

    // Publish event for other services
    await this.eventBus.publish(new AssetUploadedEvent({
      assetId: asset.id,
      userId: asset.userId,
      mimeType: asset.mimeType,
    }));

    return asset;
  }
}

// ML service subscribes to events
@EventsHandler(AssetUploadedEvent)
export class AssetUploadedHandler implements IEventHandler<AssetUploadedEvent> {
  constructor(private mlService: MachineLearningService) {}

  async handle(event: AssetUploadedEvent): Promise<void> {
    if (event.mimeType.startsWith('image/')) {
      await this.mlService.processImage(event.assetId);
    }
  }
}
```

### Service Discovery & Configuration

**Service Registry Pattern**:
```typescript
@Injectable()
export class ServiceRegistry {
  private services = new Map<string, ServiceInstance>();

  registerService(name: string, instance: ServiceInstance): void {
    this.services.set(name, instance);
  }

  getService(name: string): ServiceInstance | undefined {
    return this.services.get(name);
  }
}

@Injectable()
export class ServiceClient {
  constructor(
    private httpService: HttpService,
    private serviceRegistry: ServiceRegistry,
  ) {}

  async callService<T>(
    serviceName: string,
    endpoint: string,
    data?: any,
  ): Promise<T> {
    const service = this.serviceRegistry.getService(serviceName);
    if (!service) {
      throw new Error(`Service ${serviceName} not found`);
    }

    const response = await this.httpService.axiosRef.post(
      `${service.baseUrl}${endpoint}`,
      data,
      {
        timeout: 5000,
        headers: {
          'Authorization': `Bearer ${service.token}`,
        },
      },
    );

    return response.data;
  }
}
```

---

## 🔄 Hybrid/Monorepo Pattern

### Overview
Combines benefits of monolith and microservices using monorepo tools like Nx.

### Examples
- **Ghostfolio**: Nx workspace with Angular + NestJS
- **Twenty**: Multiple apps with shared packages

### Nx Workspace Structure

**From Ghostfolio**:
```
workspace/
├── apps/
│   ├── api/               # NestJS API application
│   │   ├── src/
│   │   ├── project.json
│   │   └── Dockerfile
│   └── client/            # Angular frontend
│       ├── src/
│       └── project.json
├── libs/                  # Shared libraries
│   ├── common/           # Common utilities
│   │   ├── interfaces/
│   │   ├── types/
│   │   └── utils/
│   ├── ui/               # UI components
│   └── api-interfaces/   # API contracts
├── tools/                # Build tools and scripts
├── nx.json              # Nx configuration
└── workspace.json       # Workspace configuration
```

### Shared Library Pattern

**Common Interfaces Library**:
```typescript
// libs/api-interfaces/src/lib/user.interface.ts
export interface User {
  id: string;
  email: string;
  firstName: string;
  lastName: string;
  roles: Role[];
}

export interface CreateUserRequest {
  email: string;
  password: string;
  firstName: string;
  lastName: string;
}

export interface UserResponse {
  user: User;
  permissions: Permission[];
}
```

**Shared Service Library**:
```typescript
// libs/common/src/lib/validation.service.ts
@Injectable()
export class ValidationService {
  validateEmail(email: string): boolean {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return emailRegex.test(email);
  }

  validatePassword(password: string): ValidationResult {
    const errors: string[] = [];
    
    if (password.length < 8) {
      errors.push('Password must be at least 8 characters long');
    }
    
    if (!/[A-Z]/.test(password)) {
      errors.push('Password must contain at least one uppercase letter');
    }
    
    return {
      isValid: errors.length === 0,
      errors,
    };
  }
}
```

### Build Configuration

**Nx Build Targets**:
```json
{
  "projects": {
    "api": {
      "targets": {
        "build": {
          "executor": "@nrwl/node:build",
          "options": {
            "outputPath": "dist/apps/api",
            "main": "apps/api/src/main.ts",
            "tsConfig": "apps/api/tsconfig.app.json"
          }
        },
        "serve": {
          "executor": "@nrwl/node:execute",
          "options": {
            "buildTarget": "api:build"
          }
        }
      }
    }
  }
}
```

---

## 🧩 Domain-Driven Design (DDD)

### Hexagonal Architecture

**From Sairyss/domain-driven-hexagon**:

```
src/
├── application/              # Application layer
│   ├── commands/            # Command handlers (CQRS)
│   │   ├── create-user/
│   │   │   ├── create-user.command.ts
│   │   │   └── create-user.handler.ts
│   │   └── update-user/
│   ├── queries/             # Query handlers
│   │   ├── get-user/
│   │   └── list-users/
│   └── services/            # Application services
├── domain/                  # Domain layer
│   ├── entities/           # Domain entities
│   │   ├── user/
│   │   │   ├── user.entity.ts
│   │   │   ├── user.errors.ts
│   │   │   └── user.types.ts
│   │   └── value-objects/
│   ├── repositories/       # Repository interfaces
│   └── events/            # Domain events
├── infrastructure/         # Infrastructure layer
│   ├── database/          # Data persistence
│   │   ├── repositories/  # Repository implementations
│   │   └── entities/      # ORM entities
│   ├── external/          # External services
│   └── messaging/         # Event handling
└── interface/             # Interface layer
    ├── controllers/       # HTTP controllers
    ├── dto/              # Data transfer objects
    └── guards/           # Security guards
```

### Domain Entity Implementation

```typescript
export interface UserProps {
  email: Email;
  firstName: string;
  lastName: string;
  createdAt: Date;
  updatedAt: Date;
}

export class User extends AggregateRoot<UserProps> {
  protected readonly _id: UserId;

  public static create(props: CreateUserProps): User {
    const id = UserId.generate();
    
    const userProps: UserProps = {
      ...props,
      createdAt: new Date(),
      updatedAt: new Date(),
    };
    
    const user = new User({ id, props: userProps });
    
    // Domain event
    user.addEvent(new UserCreatedDomainEvent({
      aggregateId: id.value,
      email: props.email.value,
    }));
    
    return user;
  }

  public updateProfile(firstName: string, lastName: string): void {
    this.props.firstName = firstName;
    this.props.lastName = lastName;
    this.props.updatedAt = new Date();
    
    this.addEvent(new UserProfileUpdatedDomainEvent({
      aggregateId: this._id.value,
      firstName,
      lastName,
    }));
  }

  get email(): Email {
    return this.props.email;
  }
  
  get fullName(): string {
    return `${this.props.firstName} ${this.props.lastName}`;
  }
}
```

### Repository Pattern

**Domain Repository Interface**:
```typescript
export interface UserRepository {
  save(user: User): Promise<void>;
  findById(id: UserId): Promise<User | null>;
  findByEmail(email: Email): Promise<User | null>;
  delete(id: UserId): Promise<void>;
}
```

**Infrastructure Implementation**:
```typescript
@Injectable()
export class TypeOrmUserRepository implements UserRepository {
  constructor(
    @InjectRepository(UserOrmEntity)
    private readonly userRepository: Repository<UserOrmEntity>,
    private readonly mapper: UserMapper,
  ) {}

  async save(user: User): Promise<void> {
    const ormEntity = this.mapper.toPersistence(user);
    await this.userRepository.save(ormEntity);
  }

  async findById(id: UserId): Promise<User | null> {
    const ormEntity = await this.userRepository.findOne({
      where: { id: id.value },
    });
    
    return ormEntity ? this.mapper.toDomain(ormEntity) : null;
  }
}
```

### CQRS Implementation

**Command Handler**:
```typescript
@CommandHandler(CreateUserCommand)
export class CreateUserHandler implements ICommandHandler<CreateUserCommand> {
  constructor(
    @Inject('USER_REPOSITORY') private userRepo: UserRepository,
    private eventBus: EventBus,
  ) {}

  async execute(command: CreateUserCommand): Promise<UserCreatedResponse> {
    const { email, firstName, lastName, password } = command;
    
    // Check if user already exists
    const existingUser = await this.userRepo.findByEmail(email);
    if (existingUser) {
      throw new UserAlreadyExistsError();
    }

    // Create domain entity
    const user = User.create({
      email: Email.create(email),
      firstName,
      lastName,
      password: Password.create(password),
    });

    // Save to repository
    await this.userRepo.save(user);

    // Publish domain events
    await this.eventBus.publishAll(user.getUncommittedEvents());
    user.markEventsAsCommitted();

    return new UserCreatedResponse(user.id.value);
  }
}
```

---

## 🔧 Layered Architecture

### Traditional N-Tier Pattern

**Layer Structure**:
```
src/
├── presentation/           # Controllers, DTOs, Validation
│   ├── controllers/
│   ├── dto/
│   └── validators/
├── business/              # Business logic and services
│   ├── services/
│   ├── interfaces/
│   └── models/
├── data/                  # Data access layer
│   ├── repositories/
│   ├── entities/
│   └── migrations/
└── cross-cutting/         # Infrastructure concerns
    ├── logging/
    ├── security/
    └── configuration/
```

### Service Layer Pattern

```typescript
@Injectable()
export class UserBusinessService {
  constructor(
    private userRepository: UserRepository,
    private emailService: EmailService,
    private auditService: AuditService,
  ) {}

  async createUser(userData: CreateUserData): Promise<User> {
    // Business validation
    await this.validateUserCreation(userData);
    
    // Create user
    const user = await this.userRepository.create({
      ...userData,
      password: await this.hashPassword(userData.password),
    });
    
    // Business logic
    await this.emailService.sendWelcomeEmail(user.email);
    await this.auditService.logUserCreation(user.id);
    
    return user;
  }

  private async validateUserCreation(userData: CreateUserData): Promise<void> {
    const existingUser = await this.userRepository.findByEmail(userData.email);
    if (existingUser) {
      throw new BusinessException('User already exists');
    }
    
    if (!this.isValidBusinessEmail(userData.email)) {
      throw new BusinessException('Invalid business email domain');
    }
  }
}
```

---

## 📦 Plugin Architecture

### Plugin System Design

**From APItable Project**:
```typescript
export interface Plugin {
  name: string;
  version: string;
  initialize(context: PluginContext): Promise<void>;
  destroy(): Promise<void>;
}

@Injectable()
export class PluginManager {
  private plugins = new Map<string, Plugin>();

  async loadPlugin(pluginPath: string): Promise<void> {
    const PluginClass = await import(pluginPath);
    const plugin = new PluginClass.default();
    
    await plugin.initialize(this.createContext());
    this.plugins.set(plugin.name, plugin);
  }

  getPlugin(name: string): Plugin | undefined {
    return this.plugins.get(name);
  }

  private createContext(): PluginContext {
    return {
      database: this.databaseService,
      eventBus: this.eventBus,
      httpService: this.httpService,
    };
  }
}
```

### Extension Points

```typescript
export interface FieldPlugin extends Plugin {
  createField(config: FieldConfig): Field;
  validateValue(value: any, config: FieldConfig): ValidationResult;
  formatValue(value: any, config: FieldConfig): string;
}

@Plugin('text-field')
export class TextFieldPlugin implements FieldPlugin {
  createField(config: FieldConfig): TextField {
    return new TextField(config);
  }

  validateValue(value: any, config: FieldConfig): ValidationResult {
    if (typeof value !== 'string') {
      return { isValid: false, error: 'Value must be a string' };
    }
    
    if (config.maxLength && value.length > config.maxLength) {
      return { isValid: false, error: 'Value too long' };
    }
    
    return { isValid: true };
  }

  formatValue(value: string, config: FieldConfig): string {
    return config.uppercase ? value.toUpperCase() : value;
  }
}
```

---

## 🎯 Architecture Selection Guidelines

### Choose Modular Monolith When:
- **Team Size**: Small to medium (2-10 developers)
- **Complexity**: Low to medium business complexity
- **Scale**: Up to 100k active users
- **Requirements**: Simple deployment and operations
- **Timeline**: Fast time to market needed

### Choose Microservices When:
- **Team Size**: Large (10+ developers) with multiple teams
- **Complexity**: High business complexity with distinct domains
- **Scale**: 100k+ users with independent scaling needs
- **Requirements**: Independent deployment and technology choices
- **Expertise**: Team has microservices experience

### Choose Hybrid/Monorepo When:
- **Team Size**: Medium to large with shared components
- **Complexity**: Multiple applications sharing business logic
- **Scale**: Variable scaling needs across applications
- **Requirements**: Code reuse and consistent tooling
- **Migration**: Gradual migration from monolith to microservices

---

## 📊 Architecture Comparison

| Aspect | Modular Monolith | Microservices | Hybrid/Monorepo |
|--------|------------------|---------------|------------------|
| **Complexity** | Low | High | Medium |
| **Development Speed** | Fast | Slow | Medium |
| **Deployment** | Simple | Complex | Medium |
| **Scaling** | Vertical | Horizontal | Mixed |
| **Testing** | Easy | Complex | Medium |
| **Team Coordination** | Low | High | Medium |
| **Technology Freedom** | Limited | High | Medium |
| **Operational Overhead** | Low | High | Medium |

---

## 🏗️ Architecture Evolution Path

### Stage 1: Start Simple
```
Single NestJS App → Modular Structure → Clear Boundaries
```

### Stage 2: Extract Services
```
Modular Monolith → Shared Libraries → Independent Services
```

### Stage 3: Full Microservices
```
Multiple Services → Event-Driven → Service Mesh
```

### Migration Strategy

**Gradual Extraction Pattern**:
```typescript
// Step 1: Create clear module boundaries
@Module({
  imports: [],
  providers: [NotificationService],
  exports: [NotificationService],
})
export class NotificationModule {}

// Step 2: Abstract behind interface
export interface INotificationService {
  sendEmail(to: string, subject: string, body: string): Promise<void>;
}

// Step 3: Create HTTP client implementation
@Injectable()
export class HttpNotificationService implements INotificationService {
  async sendEmail(to: string, subject: string, body: string): Promise<void> {
    await this.httpClient.post('/notifications/email', {
      to, subject, body
    });
  }
}

// Step 4: Replace implementation
@Module({
  providers: [
    {
      provide: 'NOTIFICATION_SERVICE',
      useClass: HttpNotificationService, // Changed from NotificationService
    },
  ],
})
export class NotificationModule {}
```

---

**Navigation**
- ← Previous: [Security Patterns](./security-patterns.md)
- → Next: [Tool Ecosystem](./tool-ecosystem.md)
- ↑ Back to: [Main Overview](./README.md)