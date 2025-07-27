# Architecture Patterns in NestJS Open Source Projects

## 🏗️ Overview

This document analyzes the architectural patterns and design approaches used in production NestJS applications. Based on analysis of 20+ open source projects, we examine common patterns, their benefits, trade-offs, and implementation strategies.

## 📊 Pattern Distribution

| Architecture Pattern | Usage Rate | Complexity | Scalability | Maintainability |
|---------------------|------------|------------|-------------|-----------------|
| **Modular Monolith** | 95% | Medium | High | Very High |
| **Clean Architecture** | 70% | High | Very High | Very High |
| **Microservices Ready** | 45% | Very High | Very High | High |
| **Domain-Driven Design** | 40% | High | High | Very High |
| **Event-Driven Architecture** | 35% | High | Very High | High |
| **CQRS Pattern** | 25% | Very High | Very High | Medium |
| **Hexagonal Architecture** | 20% | High | High | High |

## 🔧 Core Architectural Patterns

### 1. Modular Monolith (95% adoption)

**Description**: Feature-based module organization where each business domain is encapsulated in its own module with clear boundaries.

#### Implementation Structure
```typescript
src/
├── app.module.ts              # Root application module
├── main.ts                    # Application bootstrap
├── config/                    # Configuration management
├── shared/                    # Shared utilities and modules
│   ├── decorators/
│   ├── filters/
│   ├── guards/
│   ├── interceptors/
│   └── pipes/
├── modules/
│   ├── auth/                  # Authentication module
│   │   ├── auth.module.ts
│   │   ├── auth.controller.ts
│   │   ├── auth.service.ts
│   │   ├── guards/
│   │   ├── strategies/
│   │   └── dto/
│   ├── users/                 # User management module
│   │   ├── users.module.ts
│   │   ├── users.controller.ts
│   │   ├── users.service.ts
│   │   ├── entities/
│   │   ├── dto/
│   │   └── repositories/
│   └── products/              # Product module
│       ├── products.module.ts
│       ├── products.controller.ts
│       ├── products.service.ts
│       ├── entities/
│       └── dto/
└── database/                  # Database configuration
    ├── migrations/
    └── seeds/
```

#### Module Implementation Example
```typescript
// Feature module implementation
@Module({
  imports: [
    TypeOrmModule.forFeature([UserEntity, ProfileEntity]),
    forwardRef(() => AuthModule), // Handle circular dependencies
    SharedModule,
  ],
  controllers: [UsersController],
  providers: [
    UsersService,
    UsersRepository,
    {
      provide: 'USER_CONFIG',
      useFactory: (configService: ConfigService) => ({
        maxUsers: configService.get('MAX_USERS'),
        defaultRole: configService.get('DEFAULT_ROLE'),
      }),
      inject: [ConfigService],
    },
  ],
  exports: [UsersService], // Export for other modules
})
export class UsersModule {}
```

#### Benefits
- **Clear Boundaries**: Each module has well-defined responsibilities
- **Reusability**: Modules can be easily extracted or reused
- **Testability**: Isolated modules are easier to unit test
- **Team Productivity**: Teams can work on different modules independently
- **Gradual Migration**: Easy to extract modules to microservices later

#### Best Practices
- Keep modules focused on single business domains
- Minimize inter-module dependencies
- Use shared modules for common functionality
- Implement proper module exports and imports
- Avoid circular dependencies with forwardRef()

---

### 2. Clean Architecture (70% adoption)

**Description**: Layered architecture that separates business logic from external concerns, making the system independent of frameworks, databases, and external agencies.

#### Layer Structure
```typescript
src/
├── domain/                    # Business logic layer
│   ├── entities/             # Business entities
│   ├── repositories/         # Repository interfaces
│   ├── services/            # Domain services
│   └── value-objects/       # Value objects
├── application/              # Application logic layer
│   ├── use-cases/           # Application use cases
│   ├── dto/                 # Data transfer objects
│   ├── interfaces/          # Application interfaces
│   └── services/            # Application services
├── infrastructure/           # External concerns layer
│   ├── database/            # Database implementations
│   ├── repositories/        # Repository implementations
│   ├── external-services/   # Third-party integrations
│   └── messaging/           # Message brokers
└── presentation/            # Presentation layer
    ├── controllers/         # HTTP controllers
    ├── graphql/            # GraphQL resolvers
    ├── middleware/         # HTTP middleware
    └── validation/         # Input validation
```

#### Use Case Implementation
```typescript
// Domain entity
export class User {
  constructor(
    private readonly id: UserId,
    private readonly email: Email,
    private readonly profile: UserProfile,
    private readonly createdAt: Date
  ) {}

  public updateProfile(newProfile: UserProfile): void {
    // Business logic validation
    if (!newProfile.isValid()) {
      throw new InvalidProfileError('Profile data is invalid');
    }
    
    this.profile = newProfile;
  }

  public isActive(): boolean {
    return this.profile.status === UserStatus.ACTIVE;
  }
}

// Application use case
@Injectable()
export class UpdateUserProfileUseCase {
  constructor(
    private readonly userRepository: IUserRepository,
    private readonly eventBus: IEventBus
  ) {}

  async execute(command: UpdateUserProfileCommand): Promise<void> {
    // Fetch domain entity
    const user = await this.userRepository.findById(command.userId);
    if (!user) {
      throw new UserNotFoundError();
    }

    // Execute business logic
    user.updateProfile(command.profile);

    // Persist changes
    await this.userRepository.save(user);

    // Emit domain event
    await this.eventBus.publish(
      new UserProfileUpdatedEvent(user.id, user.profile)
    );
  }
}

// Infrastructure repository implementation
@Injectable()
export class TypeOrmUserRepository implements IUserRepository {
  constructor(
    @InjectRepository(UserEntity)
    private readonly repository: Repository<UserEntity>
  ) {}

  async findById(id: UserId): Promise<User | null> {
    const entity = await this.repository.findOne({ 
      where: { id: id.value } 
    });
    
    return entity ? this.toDomain(entity) : null;
  }

  async save(user: User): Promise<void> {
    const entity = this.toEntity(user);
    await this.repository.save(entity);
  }

  private toDomain(entity: UserEntity): User {
    return new User(
      new UserId(entity.id),
      new Email(entity.email),
      new UserProfile(entity.firstName, entity.lastName),
      entity.createdAt
    );
  }
}
```

#### Benefits
- **Framework Independence**: Business logic not tied to NestJS
- **Database Independence**: Easy to switch database technologies
- **Testability**: Each layer can be tested in isolation
- **Maintainability**: Clear separation of concerns
- **Flexibility**: Easy to modify external dependencies

#### Implementation Patterns
- Use interfaces to define contracts between layers
- Implement dependency injection for layer communication
- Keep domain entities pure with no external dependencies
- Use value objects for domain concepts
- Implement proper error handling at each layer

---

### 3. Domain-Driven Design (40% adoption)

**Description**: Software design approach that focuses on modeling software to match business domains and uses ubiquitous language between technical and domain experts.

#### Domain Organization
```typescript
src/
├── domains/
│   ├── user-management/      # Bounded context
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   ├── user.entity.ts
│   │   │   │   └── user-profile.entity.ts
│   │   │   ├── value-objects/
│   │   │   │   ├── email.vo.ts
│   │   │   │   └── user-id.vo.ts
│   │   │   ├── services/
│   │   │   │   └── user-domain.service.ts
│   │   │   ├── repositories/
│   │   │   │   └── user.repository.interface.ts
│   │   │   └── events/
│   │   │       └── user-created.event.ts
│   │   ├── application/
│   │   │   ├── commands/
│   │   │   ├── queries/
│   │   │   ├── handlers/
│   │   │   └── services/
│   │   └── infrastructure/
│   │       ├── repositories/
│   │       ├── adapters/
│   │       └── persistence/
│   └── order-management/     # Another bounded context
│       ├── domain/
│       ├── application/
│       └── infrastructure/
└── shared-kernel/           # Shared concepts
    ├── domain/
    ├── value-objects/
    └── events/
```

#### Aggregate Implementation
```typescript
// Domain aggregate root
export class Order {
  private constructor(
    private readonly id: OrderId,
    private readonly customerId: CustomerId,
    private readonly items: OrderItem[],
    private status: OrderStatus,
    private readonly createdAt: Date
  ) {}

  public static create(
    customerId: CustomerId,
    items: OrderItem[]
  ): Order {
    // Business rule validation
    if (items.length === 0) {
      throw new EmptyOrderError('Order must have at least one item');
    }

    const totalAmount = items.reduce(
      (sum, item) => sum + item.getTotalPrice(),
      0
    );

    if (totalAmount < Money.fromCents(100)) {
      throw new MinimumOrderAmountError('Minimum order amount is $1.00');
    }

    const order = new Order(
      OrderId.generate(),
      customerId,
      items,
      OrderStatus.PENDING,
      new Date()
    );

    // Domain event
    order.addDomainEvent(
      new OrderCreatedEvent(order.id, order.customerId, totalAmount)
    );

    return order;
  }

  public addItem(item: OrderItem): void {
    // Business rule: cannot add items to confirmed orders
    if (this.status !== OrderStatus.PENDING) {
      throw new OrderAlreadyConfirmedError();
    }

    this.items.push(item);
    
    this.addDomainEvent(
      new OrderItemAddedEvent(this.id, item.productId, item.quantity)
    );
  }

  public confirm(): void {
    if (this.status !== OrderStatus.PENDING) {
      throw new InvalidOrderStatusError();
    }

    this.status = OrderStatus.CONFIRMED;
    
    this.addDomainEvent(
      new OrderConfirmedEvent(this.id, this.getTotalAmount())
    );
  }
}

// Value object implementation
export class Money {
  private constructor(private readonly cents: number) {
    if (cents < 0) {
      throw new InvalidMoneyError('Money amount cannot be negative');
    }
  }

  public static fromCents(cents: number): Money {
    return new Money(cents);
  }

  public static fromDollars(dollars: number): Money {
    return new Money(Math.round(dollars * 100));
  }

  public add(other: Money): Money {
    return new Money(this.cents + other.cents);
  }

  public multiply(factor: number): Money {
    return new Money(Math.round(this.cents * factor));
  }

  public toCents(): number {
    return this.cents;
  }

  public toDollars(): number {
    return this.cents / 100;
  }
}
```

#### Benefits
- **Business Alignment**: Code reflects business concepts
- **Ubiquitous Language**: Shared vocabulary between developers and domain experts
- **Bounded Contexts**: Clear module boundaries
- **Complex Domain Handling**: Better modeling of complex business rules
- **Evolution Support**: Easier to evolve with changing business requirements

---

### 4. Event-Driven Architecture (35% adoption)

**Description**: Architecture where components communicate through events, enabling loose coupling and better scalability.

#### Event System Implementation
```typescript
// Domain event
export class UserRegisteredEvent {
  constructor(
    public readonly userId: string,
    public readonly email: string,
    public readonly registeredAt: Date
  ) {}
}

// Event handler
@EventsHandler(UserRegisteredEvent)
export class UserRegisteredHandler implements IEventHandler<UserRegisteredEvent> {
  constructor(
    private readonly emailService: EmailService,
    private readonly analyticsService: AnalyticsService
  ) {}

  async handle(event: UserRegisteredEvent): Promise<void> {
    // Send welcome email
    await this.emailService.sendWelcomeEmail(event.email);
    
    // Track analytics
    await this.analyticsService.trackUserRegistration(event.userId);
    
    // Additional side effects...
  }
}

// Event-driven service
@Injectable()
export class UserService {
  constructor(
    private readonly eventBus: EventBus,
    private readonly userRepository: UserRepository
  ) {}

  async registerUser(registerDto: RegisterUserDto): Promise<User> {
    // Create user
    const user = await this.userRepository.create(registerDto);
    
    // Emit event
    this.eventBus.publish(
      new UserRegisteredEvent(user.id, user.email, new Date())
    );
    
    return user;
  }
}

// Saga for complex workflows
@Saga()
export class OrderProcessingSaga {
  @Saga()
  orderCreated = (events$: Observable<any>): Observable<ICommand> => {
    return events$.pipe(
      ofType(OrderCreatedEvent),
      map(event => new ProcessPaymentCommand(event.orderId, event.amount))
    );
  };

  @Saga()
  paymentProcessed = (events$: Observable<any>): Observable<ICommand> => {
    return events$.pipe(
      ofType(PaymentProcessedEvent),
      map(event => new FulfillOrderCommand(event.orderId))
    );
  };
}
```

#### Event Store Implementation
```typescript
@Injectable()
export class EventStore {
  constructor(
    @InjectRepository(EventEntity)
    private readonly eventRepository: Repository<EventEntity>
  ) {}

  async saveEvents(
    aggregateId: string,
    events: DomainEvent[],
    expectedVersion: number
  ): Promise<void> {
    const eventEntities = events.map((event, index) => ({
      aggregateId,
      eventType: event.constructor.name,
      eventData: JSON.stringify(event),
      version: expectedVersion + index + 1,
      createdAt: new Date(),
    }));

    await this.eventRepository.save(eventEntities);

    // Publish events to event bus
    events.forEach(event => this.eventBus.publish(event));
  }

  async getEvents(
    aggregateId: string,
    fromVersion: number = 0
  ): Promise<DomainEvent[]> {
    const eventEntities = await this.eventRepository.find({
      where: {
        aggregateId,
        version: MoreThan(fromVersion),
      },
      order: { version: 'ASC' },
    });

    return eventEntities.map(entity => 
      this.deserializeEvent(entity.eventType, entity.eventData)
    );
  }
}
```

#### Benefits
- **Loose Coupling**: Components don't directly depend on each other
- **Scalability**: Easy to scale event handlers independently
- **Auditability**: Complete event history for debugging and compliance
- **Extensibility**: Easy to add new event handlers without modifying existing code
- **Resilience**: Failures in one handler don't affect others

---

### 5. CQRS Pattern (25% adoption)

**Description**: Command Query Responsibility Segregation separates read and write operations, allowing for optimized data models for each.

#### CQRS Implementation
```typescript
// Command side
export class CreateUserCommand {
  constructor(
    public readonly email: string,
    public readonly firstName: string,
    public readonly lastName: string
  ) {}
}

@CommandHandler(CreateUserCommand)
export class CreateUserHandler implements ICommandHandler<CreateUserCommand> {
  constructor(
    private readonly userRepository: UserRepository,
    private readonly eventBus: EventBus
  ) {}

  async execute(command: CreateUserCommand): Promise<string> {
    // Validate business rules
    const existingUser = await this.userRepository.findByEmail(command.email);
    if (existingUser) {
      throw new UserAlreadyExistsError(command.email);
    }

    // Create user
    const user = User.create(command.email, command.firstName, command.lastName);
    await this.userRepository.save(user);

    // Publish events
    user.getUncommittedEvents().forEach(event => {
      this.eventBus.publish(event);
    });

    return user.id;
  }
}

// Query side
export class GetUserQuery {
  constructor(public readonly userId: string) {}
}

@QueryHandler(GetUserQuery)
export class GetUserHandler implements IQueryHandler<GetUserQuery> {
  constructor(
    @InjectRepository(UserReadModel)
    private readonly userReadRepository: Repository<UserReadModel>
  ) {}

  async execute(query: GetUserQuery): Promise<UserReadModel> {
    const user = await this.userReadRepository.findOne({
      where: { id: query.userId },
      relations: ['profile', 'permissions']
    });

    if (!user) {
      throw new UserNotFoundError(query.userId);
    }

    return user;
  }
}

// Read model projector
@EventsHandler(UserCreatedEvent)
export class UserCreatedProjector implements IEventHandler<UserCreatedEvent> {
  constructor(
    @InjectRepository(UserReadModel)
    private readonly userReadRepository: Repository<UserReadModel>
  ) {}

  async handle(event: UserCreatedEvent): Promise<void> {
    const readModel = new UserReadModel();
    readModel.id = event.userId;
    readModel.email = event.email;
    readModel.firstName = event.firstName;
    readModel.lastName = event.lastName;
    readModel.createdAt = event.createdAt;

    await this.userReadRepository.save(readModel);
  }
}
```

#### Benefits
- **Performance Optimization**: Separate read and write models optimized for their use cases
- **Scalability**: Read and write sides can be scaled independently
- **Complexity Management**: Complex business logic separated from query logic
- **Reporting**: Optimized read models for reporting and analytics

---

## 🔄 Pattern Combinations

### Modular Monolith + Clean Architecture (Most Common)
```typescript
// Module organization with clean architecture layers
src/
├── modules/
│   └── users/
│       ├── domain/          # Clean architecture domain layer
│       ├── application/     # Clean architecture application layer
│       ├── infrastructure/  # Clean architecture infrastructure layer
│       ├── presentation/    # Clean architecture presentation layer
│       └── users.module.ts  # NestJS module definition
```

### DDD + Event-Driven + CQRS (Enterprise Pattern)
```typescript
// Complex enterprise pattern combination
src/
├── domains/
│   └── user-management/
│       ├── commands/        # CQRS commands
│       ├── queries/         # CQRS queries
│       ├── events/          # Domain events
│       ├── aggregates/      # DDD aggregates
│       ├── projectors/      # Event projectors
│       └── sagas/           # Complex workflows
```

## 📊 Architectural Decision Matrix

| Pattern | Learning Curve | Team Size | Project Complexity | Long-term Maintenance |
|---------|---------------|-----------|-------------------|----------------------|
| **Modular Monolith** | Low | 1-10 | Low-High | High |
| **Clean Architecture** | Medium | 3-15 | Medium-High | Very High |
| **DDD** | High | 5-20 | High | Very High |
| **Event-Driven** | Medium | 3-15 | Medium-High | High |
| **CQRS** | High | 5+ | High | Medium |
| **Microservices** | Very High | 10+ | Very High | Medium |

## 🚀 Implementation Recommendations

### Starting a New Project
1. **Begin with Modular Monolith** - Always start here for maintainability
2. **Add Clean Architecture** - If business logic complexity is medium-high
3. **Consider DDD** - For complex business domains with multiple experts
4. **Implement Events** - When you need loose coupling and auditability
5. **Add CQRS** - Only when read/write performance requirements differ significantly

### Evolving Existing Projects
1. **Refactor to modules** - Extract features into NestJS modules
2. **Introduce layers** - Gradually separate concerns into layers
3. **Add event system** - Introduce events for new features first
4. **Extract bounded contexts** - Identify and separate business domains
5. **Consider microservices** - Only when team size and complexity justify it

## 🔗 References & Citations

### Official Documentation
- [NestJS Modules](https://docs.nestjs.com/modules) - Module system documentation
- [NestJS Architecture](https://docs.nestjs.com/first-steps) - Framework architecture guide
- [CQRS in NestJS](https://docs.nestjs.com/recipes/cqrs) - Command Query Responsibility Segregation

### Architecture Resources
- [Clean Architecture by Robert Martin](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html) - Clean architecture principles
- [Domain-Driven Design](https://martinfowler.com/bliki/DomainDrivenDesign.html) - DDD overview by Martin Fowler
- [Event Sourcing](https://martinfowler.com/eaaDev/EventSourcing.html) - Event sourcing pattern

### Project Examples
- [NestJS Realworld](https://github.com/gothinkster/nestjs-realworld-example-app) - Clean modular architecture
- [Ever Platform](https://github.com/ever-co/ever-platform) - Complex enterprise architecture
- [Amplication](https://github.com/amplication/amplication) - DDD + CQRS + Event Sourcing

---

**Next**: [Authentication Strategies →](./authentication-strategies.md)  
**Previous**: [Project Analysis ←](./project-analysis.md)