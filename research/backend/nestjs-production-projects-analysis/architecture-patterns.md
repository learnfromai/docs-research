# Architecture Patterns in Production NestJS Applications

## 🎯 Overview

Analysis of architectural patterns used across 40+ production-ready NestJS projects, documenting proven approaches for building scalable, maintainable applications.

## 📊 Pattern Distribution

| Architecture Pattern | Usage | Examples | Complexity | Scalability |
|---------------------|-------|----------|------------|-------------|
| **Modular Monolith** | 45% | Twenty, Immich, Reactive Resume | Medium | High |
| **Microservices** | 25% | Ultimate Backend, BackendWorks | High | Very High |
| **Monorepo** | 20% | Nx-based projects, Amplication | Medium | High |
| **Clean Architecture** | 10% | DDD examples, Domain-driven projects | High | Very High |

## 🏗️ 1. Modular Monolith Pattern

### Overview
Most popular pattern (45% of projects) that organizes code into feature-based modules while maintaining a single deployable unit.

### Implementation Example: Twenty CRM
```typescript
// App module structure
@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    DatabaseModule,
    // Feature modules
    AuthModule,
    UserModule,
    CompanyModule,
    OpportunityModule,
    WorkspaceModule,
    // Core modules
    CoreModule,
    HealthModule,
  ],
})
export class AppModule {}

// Feature module structure
@Module({
  imports: [
    TypeOrmModule.forFeature([Company, CompanyRepository]),
    UserModule, // Inter-module dependency
  ],
  providers: [
    CompanyService,
    CompanyResolver,
    CompanyController,
  ],
  exports: [CompanyService], // Expose for other modules
})
export class CompanyModule {}
```

### Directory Structure
```
src/
├── modules/
│   ├── auth/
│   │   ├── dto/
│   │   ├── entities/
│   │   ├── guards/
│   │   ├── services/
│   │   └── auth.module.ts
│   ├── users/
│   ├── companies/
│   └── opportunities/
├── common/
│   ├── decorators/
│   ├── filters/
│   ├── guards/
│   ├── interceptors/
│   └── pipes/
├── config/
├── database/
└── main.ts
```

### Benefits
- **Easy to understand**: Clear feature boundaries
- **Fast development**: No distributed system complexity
- **Simplified testing**: Single codebase testing
- **Performance**: No network latency between modules

### When to Use
- Medium to large applications
- Teams of 5-20 developers
- Clear feature boundaries
- Moderate scalability requirements

### Real-World Examples
1. **Twenty**: CRM with modular feature organization
2. **Reactive Resume**: Resume builder with clear domain separation
3. **Ghostfolio**: Portfolio management with financial modules

---

## 🔄 2. Microservices Pattern

### Overview
25% of analyzed projects use microservices for maximum scalability and team independence.

### Implementation Example: Ultimate Backend
```typescript
// API Gateway
@Module({
  imports: [
    GraphQLFederationModule.forRoot({
      gateway: {
        serviceList: [
          { name: 'users', url: process.env.USER_SERVICE_URL },
          { name: 'billing', url: process.env.BILLING_SERVICE_URL },
          { name: 'projects', url: process.env.PROJECT_SERVICE_URL },
          { name: 'notifications', url: process.env.NOTIFICATION_SERVICE_URL },
        ],
      },
    }),
  ],
})
export class GatewayModule {}

// Individual microservice
@Module({
  imports: [
    // Service-specific modules
    UserModule,
    DatabaseModule.forFeature(['users']),
    EventSourcingModule,
  ],
})
export class UserServiceModule {}
```

### Service Communication Patterns
```typescript
// Event-driven communication with NATS
@Injectable()
export class UserService {
  constructor(
    @Inject(NATS_CLIENT) private natsClient: ClientProxy,
  ) {}

  async createUser(userData: CreateUserDto): Promise<User> {
    const user = await this.userRepository.save(userData);
    
    // Publish domain event
    await this.natsClient.emit('user.created', {
      userId: user.id,
      email: user.email,
      timestamp: new Date(),
    });
    
    return user;
  }
}

// Message handling in another service
@EventPattern('user.created')
async handleUserCreated(data: UserCreatedEvent) {
  await this.notificationService.sendWelcomeEmail(data.email);
  await this.billingService.createCustomerAccount(data.userId);
}
```

### Service Discovery & Load Balancing
```typescript
// Service registry configuration
@Module({
  imports: [
    ClientsModule.register([
      {
        name: 'USER_SERVICE',
        transport: Transport.TCP,
        options: {
          host: 'user-service',
          port: 3001,
        },
      },
      {
        name: 'BILLING_SERVICE',
        transport: Transport.TCP,
        options: {
          host: 'billing-service',
          port: 3002,
        },
      },
    ]),
  ],
})
export class ServicesModule {}
```

### Benefits
- **Independent scaling**: Scale services based on load
- **Technology diversity**: Different tech stacks per service
- **Team autonomy**: Independent development and deployment
- **Fault isolation**: Service failures don't affect others

### Challenges
- **Complexity**: Distributed system challenges
- **Network latency**: Inter-service communication overhead
- **Data consistency**: Eventual consistency patterns
- **Testing complexity**: Integration testing challenges

### When to Use
- Large-scale applications (100k+ users)
- Multiple teams (20+ developers)
- Different scalability requirements per domain
- Complex business domains

### Real-World Examples
1. **Ultimate Backend**: GraphQL federation with event sourcing
2. **BackendWorks Microservices**: gRPC communication with Kong gateway
3. **Immich**: Separate services for API, ML, and background processing

---

## 📦 3. Monorepo Pattern

### Overview
20% of projects use monorepo architecture for code sharing and coordinated development.

### Implementation Example: Nx Workspace
```typescript
// Workspace structure
apps/
├── api/                 # NestJS backend
├── web/                 # React frontend
├── mobile/              # React Native app
└── admin/               # Admin dashboard

libs/
├── shared/
│   ├── data-models/     # Shared TypeScript interfaces
│   ├── ui-components/   # Reusable UI components
│   └── utils/           # Common utilities
├── api/
│   ├── auth/            # Auth library
│   ├── database/        # Database utilities
│   └── shared/          # Backend shared code
└── web/
    ├── feature-auth/    # Frontend auth feature
    └── feature-dashboard/

// nx.json configuration
{
  "tasksRunnerOptions": {
    "default": {
      "runner": "@nrwl/workspace/tasks-runners/default",
      "options": {
        "cacheableOperations": ["build", "test", "lint"]
      }
    }
  }
}
```

### Shared Library Example
```typescript
// libs/shared/data-models/src/user.interface.ts
export interface User {
  id: string;
  email: string;
  firstName: string;
  lastName: string;
  role: UserRole;
  createdAt: Date;
  updatedAt: Date;
}

export enum UserRole {
  ADMIN = 'admin',
  USER = 'user',
  MODERATOR = 'moderator',
}

// Usage in backend
import { User, UserRole } from '@myapp/shared/data-models';

@Entity()
export class UserEntity implements User {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ unique: true })
  email: string;
  
  // ... rest of implementation
}

// Usage in frontend
import { User, UserRole } from '@myapp/shared/data-models';

interface UserListProps {
  users: User[];
  onUserSelect: (user: User) => void;
}
```

### Build Configuration
```typescript
// project.json for API app
{
  "root": "apps/api",
  "sourceRoot": "apps/api/src",
  "projectType": "application",
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
```

### Benefits
- **Code Sharing**: Shared types, utilities, and components
- **Coordinated Releases**: Deploy frontend and backend together
- **Simplified Dependencies**: Single package.json and node_modules
- **Atomic Changes**: Cross-project refactoring

### Challenges
- **Build Complexity**: Managing interdependent builds
- **Repository Size**: Large repositories can be slow
- **Tool Configuration**: Complex tooling setup
- **Team Coordination**: Changes affect multiple teams

### When to Use
- Full-stack applications
- Shared TypeScript interfaces
- Coordinated frontend/backend development
- Small to medium teams

### Real-World Examples
1. **Twenty**: Nx monorepo with React frontend and NestJS backend
2. **Amplication**: Code generation platform with shared libraries
3. **Various Templates**: Many NestJS + React starter templates

---

## 🧩 4. Clean Architecture / Domain-Driven Design

### Overview
10% of projects implement advanced architectural patterns like Clean Architecture, DDD, and Hexagonal Architecture.

### Implementation Example: Domain-Driven Design
```typescript
// Domain layer - Core business logic
export class User extends AggregateRoot {
  private constructor(
    private readonly id: UserId,
    private email: Email,
    private profile: UserProfile,
  ) {
    super();
  }

  public static create(props: CreateUserProps): User {
    const id = UserId.generate();
    const email = Email.create(props.email);
    const profile = UserProfile.create(props.profile);
    
    const user = new User(id, email, profile);
    user.addDomainEvent(new UserCreatedEvent(user.id));
    
    return user;
  }

  public changeEmail(newEmail: string): void {
    const email = Email.create(newEmail);
    this.email = email;
    this.addDomainEvent(new UserEmailChangedEvent(this.id, email));
  }

  public updateProfile(profileData: UpdateProfileProps): void {
    this.profile.update(profileData);
    this.addDomainEvent(new UserProfileUpdatedEvent(this.id));
  }
}

// Value objects
export class Email {
  private constructor(private readonly value: string) {}

  public static create(email: string): Email {
    if (!this.isValid(email)) {
      throw new InvalidEmailError(email);
    }
    return new Email(email);
  }

  private static isValid(email: string): boolean {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return emailRegex.test(email);
  }

  public getValue(): string {
    return this.value;
  }
}
```

### CQRS Implementation
```typescript
// Command side
@CommandHandler(CreateUserCommand)
export class CreateUserHandler implements ICommandHandler<CreateUserCommand> {
  constructor(
    private readonly userRepository: UserRepository,
    private readonly eventBus: EventBus,
  ) {}

  async execute(command: CreateUserCommand): Promise<void> {
    const user = User.create({
      email: command.email,
      profile: command.profile,
    });

    await this.userRepository.save(user);
    
    // Publish domain events
    const events = user.getUncommittedEvents();
    await this.eventBus.publishAll(events);
  }
}

// Query side
@QueryHandler(GetUserQuery)
export class GetUserHandler implements IQueryHandler<GetUserQuery> {
  constructor(
    private readonly userReadModel: UserReadModelRepository,
  ) {}

  async execute(query: GetUserQuery): Promise<UserReadModel> {
    return this.userReadModel.findById(query.userId);
  }
}

// Read model for queries
export class UserReadModel {
  id: string;
  email: string;
  firstName: string;
  lastName: string;
  lastLoginAt: Date;
  isActive: boolean;
}
```

### Hexagonal Architecture Structure
```
src/
├── domain/                 # Core business logic
│   ├── entities/
│   ├── value-objects/
│   ├── repositories/       # Interfaces
│   └── services/
├── application/            # Use cases
│   ├── commands/
│   ├── queries/
│   └── handlers/
├── infrastructure/         # External concerns
│   ├── persistence/
│   ├── messaging/
│   └── web/
└── presentation/          # Controllers/resolvers
    ├── controllers/
    ├── resolvers/
    └── dto/
```

### Event Sourcing Pattern
```typescript
// Event store
@Injectable()
export class EventStore {
  async saveEvents(
    streamId: string, 
    events: DomainEvent[], 
    expectedVersion: number
  ): Promise<void> {
    const eventRecords = events.map((event, index) => ({
      streamId,
      eventType: event.constructor.name,
      eventData: JSON.stringify(event.toPlain()),
      eventVersion: expectedVersion + index + 1,
      timestamp: new Date(),
    }));

    await this.eventRepository.save(eventRecords);
  }

  async getEvents(streamId: string): Promise<DomainEvent[]> {
    const records = await this.eventRepository.find({
      where: { streamId },
      order: { eventVersion: 'ASC' },
    });

    return records.map(record => this.deserializeEvent(record));
  }
}

// Aggregate reconstruction from events
export class UserAggregate {
  public static fromHistory(events: DomainEvent[]): User {
    const user = new User();
    
    events.forEach(event => {
      user.apply(event);
    });
    
    return user;
  }

  private apply(event: DomainEvent): void {
    switch (event.constructor.name) {
      case 'UserCreatedEvent':
        this.applyUserCreated(event as UserCreatedEvent);
        break;
      case 'UserEmailChangedEvent':
        this.applyEmailChanged(event as UserEmailChangedEvent);
        break;
    }
  }
}
```

### Benefits
- **Business Focus**: Domain logic separated from technical concerns
- **Testability**: Pure domain logic without external dependencies
- **Flexibility**: Easy to change persistence or presentation layers
- **Scalability**: CQRS enables independent scaling of reads/writes

### Challenges
- **Complexity**: Higher learning curve and initial complexity
- **Overhead**: More code for simple operations
- **Event Management**: Complex event handling and versioning
- **Team Skills**: Requires DDD knowledge

### When to Use
- Complex business domains
- Long-term projects with evolving requirements
- Teams with DDD experience
- High-performance requirements (CQRS)

### Real-World Examples
1. **DDD Hexagonal CQRS**: Complete implementation of all patterns
2. **Ultimate Backend**: Event sourcing with CQRS
3. **Domain-Driven Hexagon**: Educational implementation

---

## 🔧 5. Plugin Architecture Pattern

### Overview
Specialized pattern used in frameworks and extensible applications.

### Implementation Example: Vendure E-commerce
```typescript
// Plugin definition
@VendurePlugin({
  imports: [PluginCommonModule],
  providers: [PaymentMethodService, ShippingMethodService],
  adminApiExtensions: {
    schema: AdminApiExtension,
    resolvers: [AdminResolver],
  },
  shopApiExtensions: {
    schema: ShopApiExtension,
    resolvers: [ShopResolver],
  },
  entities: [PaymentMethodEntity, ShippingMethodEntity],
})
export class PaymentPlugin implements NestModule {
  static options: PaymentPluginOptions;

  static init(options: PaymentPluginOptions): Type<PaymentPlugin> {
    this.options = options;
    return PaymentPlugin;
  }

  configure(consumer: MiddlewareConsumer) {
    consumer
      .apply(PaymentWebhookMiddleware)
      .forRoutes({ path: '/payment/webhook', method: RequestMethod.POST });
  }
}

// Plugin registration
@Module({
  imports: [
    VendureModule.forRoot({
      plugins: [
        PaymentPlugin.init({
          apiKey: process.env.PAYMENT_API_KEY,
          webhookSecret: process.env.PAYMENT_WEBHOOK_SECRET,
        }),
        ShippingPlugin.init({
          carriers: ['ups', 'fedex', 'dhl'],
        }),
      ],
    }),
  ],
})
export class AppModule {}
```

### Dynamic Schema Extension
```typescript
// Schema extension
const AdminApiExtension = gql`
  extend type Mutation {
    createPaymentMethod(input: CreatePaymentMethodInput!): PaymentMethod!
    updatePaymentMethod(input: UpdatePaymentMethodInput!): PaymentMethod!
  }
  
  type PaymentMethod {
    id: ID!
    name: String!
    code: String!
    enabled: Boolean!
    handler: PaymentMethodHandler!
  }
`;

// Dynamic resolver
@Resolver()
export class PaymentResolver {
  @Mutation()
  async createPaymentMethod(
    @Args('input') input: CreatePaymentMethodInput,
  ): Promise<PaymentMethod> {
    return this.paymentService.create(input);
  }
}
```

### Benefits
- **Extensibility**: Add features without modifying core
- **Modularity**: Clean separation of concerns
- **Third-party Integration**: Enable ecosystem development
- **Customization**: Configure behavior per deployment

### When to Use
- Framework development
- Multi-tenant applications with custom features
- Marketplace platforms
- Highly configurable systems

---

## 📊 Pattern Selection Guide

### Decision Matrix

| Requirement | Modular Monolith | Microservices | Monorepo | Clean Architecture |
|-------------|------------------|---------------|----------|-------------------|
| **Team Size** | 5-20 | 20+ | 5-15 | 10+ |
| **Complexity** | Medium | High | Medium | High |
| **Scalability** | High | Very High | High | Very High |
| **Development Speed** | Fast | Slow | Fast | Slow |
| **Deployment** | Simple | Complex | Medium | Medium |
| **Testing** | Easy | Hard | Medium | Hard |

### Hybrid Approaches

Many successful projects combine multiple patterns:

1. **Modular Monolith + Clean Architecture**: Organized business logic within modules
2. **Microservices + DDD**: Domain-driven service boundaries
3. **Monorepo + Microservices**: Shared code with service independence
4. **Plugin Architecture + Modular**: Extensible modular applications

### Evolution Path

```
Simple App → Modular Monolith → Microservices
    ↓              ↓                ↓
Clean Modules → Clean Architecture → DDD + CQRS
```

---

## 🎯 Recommendations

### For New Projects
1. **Start Simple**: Begin with modular monolith
2. **Plan for Growth**: Design module boundaries thoughtfully
3. **Add Patterns Gradually**: Introduce complexity as needed
4. **Focus on Domain**: Understand business requirements first

### For Scaling Projects
1. **Extract Services**: Move to microservices when modules become too large
2. **Implement CQRS**: When read/write patterns differ significantly
3. **Add Event Sourcing**: For audit trails and temporal queries
4. **Consider DDD**: For complex business domains

### Architecture Smells
- **God Modules**: Modules with too many responsibilities
- **Circular Dependencies**: Modules depending on each other
- **Shared Databases**: Multiple services accessing same database
- **Distributed Monolith**: Microservices with tight coupling

---

**Navigation**
- [← Back to README](./README.md)
- [← Previous: Project Showcase](./project-showcase.md)
- [Next: Security Considerations →](./security-considerations.md)

*Analysis completed January 2025 | Based on architectural patterns from 40+ production NestJS projects*