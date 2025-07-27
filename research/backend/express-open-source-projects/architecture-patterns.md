# Architecture Patterns in Express.js Applications

## 🏗️ Architectural Overview

Production-ready Express.js applications employ various architectural patterns to achieve scalability, maintainability, and testability. This analysis examines the most effective patterns found in successful open source projects.

---

## 🎯 Core Architecture Patterns

### 1. Model-View-Controller (MVC) Pattern

The traditional MVC pattern remains popular for its simplicity and clear separation of concerns.

#### Traditional MVC Structure
```
project/
├── controllers/     # Handle HTTP requests and responses
├── models/         # Data models and business logic
├── views/          # Template rendering (if applicable)
├── routes/         # Route definitions
├── middleware/     # Custom middleware
└── config/         # Configuration files
```

#### Implementation Example (Sails.js approach)
```javascript
// models/User.js
module.exports = {
  attributes: {
    email: {
      type: 'string',
      required: true,
      unique: true,
    },
    password: {
      type: 'string',
      required: true,
    },
    role: {
      type: 'string',
      isIn: ['user', 'admin'],
      defaultsTo: 'user',
    },
  },
  
  beforeCreate: async function(values, proceed) {
    values.password = await bcrypt.hash(values.password, 10);
    return proceed();
  },
};

// controllers/UserController.js
module.exports = {
  async create(req, res) {
    try {
      const user = await User.create(req.body).fetch();
      delete user.password;
      return res.status(201).json(user);
    } catch (error) {
      return res.status(400).json({ error: error.message });
    }
  },

  async find(req, res) {
    const users = await User.find().select(['id', 'email', 'role']);
    return res.json(users);
  },
};

// routes/user.js
module.exports = function(app) {
  app.get('/api/users', UserController.find);
  app.post('/api/users', UserController.create);
};
```

#### Pros & Cons
**Advantages:**
- Simple to understand and implement
- Clear separation of concerns
- Familiar to most developers
- Good for traditional web applications

**Disadvantages:**
- Can become monolithic
- Limited scalability for complex applications
- Tight coupling between components

---

### 2. Clean Architecture (Hexagonal Architecture)

Advanced projects adopt Clean Architecture for better testability and independence from external concerns.

#### Clean Architecture Structure
```
project/
├── domain/              # Business logic and entities
│   ├── entities/        # Core business entities
│   ├── repositories/    # Repository interfaces
│   └── services/        # Domain services
├── application/         # Application use cases
│   ├── use-cases/       # Application use cases
│   ├── interfaces/      # Port definitions
│   └── services/        # Application services
├── infrastructure/      # External concerns
│   ├── database/        # Database implementations
│   ├── web/            # HTTP controllers
│   ├── auth/           # Authentication
│   └── external/       # External service clients
└── presentation/        # API presentation layer
    ├── controllers/     # HTTP controllers
    ├── middleware/      # HTTP middleware
    └── routes/         # Route definitions
```

#### Implementation Example (NestJS-inspired)
```typescript
// domain/entities/User.ts
export class User {
  constructor(
    public readonly id: string,
    public readonly email: string,
    private password: string,
    public readonly role: UserRole,
    public readonly createdAt: Date,
  ) {}

  public validatePassword(password: string): boolean {
    return bcrypt.compareSync(password, this.password);
  }

  public updatePassword(newPassword: string): void {
    this.password = bcrypt.hashSync(newPassword, 10);
  }
}

// domain/repositories/UserRepository.ts
export interface UserRepository {
  findById(id: string): Promise<User | null>;
  findByEmail(email: string): Promise<User | null>;
  save(user: User): Promise<User>;
  delete(id: string): Promise<void>;
}

// application/use-cases/CreateUser.ts
export class CreateUserUseCase {
  constructor(
    private userRepository: UserRepository,
    private emailService: EmailService,
  ) {}

  async execute(userData: CreateUserDto): Promise<User> {
    // Validate business rules
    const existingUser = await this.userRepository.findByEmail(userData.email);
    if (existingUser) {
      throw new ConflictException('Email already exists');
    }

    // Create user entity
    const user = new User(
      generateId(),
      userData.email,
      userData.password,
      UserRole.USER,
      new Date(),
    );

    // Save user
    const savedUser = await this.userRepository.save(user);

    // Send welcome email
    await this.emailService.sendWelcomeEmail(user.email);

    return savedUser;
  }
}

// infrastructure/database/UserRepositoryImpl.ts
@Injectable()
export class UserRepositoryImpl implements UserRepository {
  constructor(
    @InjectRepository(UserEntity)
    private userRepo: Repository<UserEntity>,
  ) {}

  async findById(id: string): Promise<User | null> {
    const userEntity = await this.userRepo.findOne({ where: { id } });
    return userEntity ? this.toDomain(userEntity) : null;
  }

  async save(user: User): Promise<User> {
    const userEntity = this.toEntity(user);
    const saved = await this.userRepo.save(userEntity);
    return this.toDomain(saved);
  }

  private toDomain(entity: UserEntity): User {
    return new User(
      entity.id,
      entity.email,
      entity.password,
      entity.role,
      entity.createdAt,
    );
  }
}

// presentation/controllers/UserController.ts
@Controller('users')
export class UserController {
  constructor(
    private createUserUseCase: CreateUserUseCase,
    private getUserUseCase: GetUserUseCase,
  ) {}

  @Post()
  @UsePipes(new ValidationPipe())
  async createUser(@Body() userData: CreateUserDto): Promise<UserResponseDto> {
    const user = await this.createUserUseCase.execute(userData);
    return new UserResponseDto(user);
  }
}
```

---

### 3. Microservices Architecture

Large-scale applications break monoliths into focused microservices for better scalability and team autonomy.

#### Microservices Structure
```
microservices/
├── user-service/
│   ├── src/
│   ├── package.json
│   └── Dockerfile
├── auth-service/
│   ├── src/
│   ├── package.json
│   └── Dockerfile
├── product-service/
│   ├── src/
│   ├── package.json
│   └── Dockerfile
├── api-gateway/
│   ├── src/
│   ├── package.json
│   └── Dockerfile
└── shared/
    ├── events/
    ├── types/
    └── utils/
```

#### Implementation Example
```typescript
// user-service/src/app.ts
import express from 'express';
import { createProxyMiddleware } from 'http-proxy-middleware';

const app = express();

// User service routes
app.use('/api/users', userRoutes);

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'healthy', service: 'user-service' });
});

// Event publishing
class UserService {
  async createUser(userData: CreateUserDto): Promise<User> {
    const user = await this.userRepository.save(userData);
    
    // Publish user created event
    await this.eventBus.publish('user.created', {
      userId: user.id,
      email: user.email,
      timestamp: new Date(),
    });
    
    return user;
  }
}

// api-gateway/src/app.ts
const app = express();

// Rate limiting
app.use(rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // limit each IP to 100 requests per windowMs
}));

// Service proxies
app.use('/api/users', createProxyMiddleware({
  target: 'http://user-service:3001',
  changeOrigin: true,
  onProxyReq: (proxyReq, req) => {
    // Add authentication headers
    proxyReq.setHeader('x-user-id', req.user?.id);
    proxyReq.setHeader('x-user-role', req.user?.role);
  },
}));

app.use('/api/products', createProxyMiddleware({
  target: 'http://product-service:3002',
  changeOrigin: true,
}));

// Event communication between services
class EventBus {
  constructor(private redis: Redis) {}

  async publish(event: string, data: any): Promise<void> {
    await this.redis.publish(event, JSON.stringify(data));
  }

  subscribe(event: string, handler: (data: any) => void): void {
    this.redis.subscribe(event);
    this.redis.on('message', (channel, message) => {
      if (channel === event) {
        handler(JSON.parse(message));
      }
    });
  }
}
```

---

### 4. Event-Driven Architecture

Applications handling real-time features or complex workflows benefit from event-driven patterns.

#### Event-Driven Structure
```typescript
// Event system implementation
interface DomainEvent {
  eventType: string;
  aggregateId: string;
  data: any;
  timestamp: Date;
  version: number;
}

class EventStore {
  constructor(private db: Database) {}

  async append(streamId: string, events: DomainEvent[]): Promise<void> {
    await this.db.transaction(async (trx) => {
      for (const event of events) {
        await trx('events').insert({
          stream_id: streamId,
          event_type: event.eventType,
          data: JSON.stringify(event.data),
          timestamp: event.timestamp,
          version: event.version,
        });
      }
    });
  }

  async getEvents(streamId: string, fromVersion = 0): Promise<DomainEvent[]> {
    const rows = await this.db('events')
      .where('stream_id', streamId)
      .where('version', '>', fromVersion)
      .orderBy('version');

    return rows.map(row => ({
      eventType: row.event_type,
      aggregateId: row.stream_id,
      data: JSON.parse(row.data),
      timestamp: row.timestamp,
      version: row.version,
    }));
  }
}

// Aggregate root with event sourcing
class Order {
  private events: DomainEvent[] = [];
  
  constructor(
    public readonly id: string,
    public readonly customerId: string,
    private status: OrderStatus = OrderStatus.PENDING,
    private items: OrderItem[] = [],
    private version = 0,
  ) {}

  addItem(product: Product, quantity: number): void {
    if (this.status !== OrderStatus.PENDING) {
      throw new Error('Cannot modify confirmed order');
    }

    const item = new OrderItem(product.id, product.price, quantity);
    this.items.push(item);

    this.addEvent(new OrderItemAddedEvent(
      this.id,
      product.id,
      quantity,
      product.price,
    ));
  }

  confirm(): void {
    if (this.items.length === 0) {
      throw new Error('Cannot confirm empty order');
    }

    this.status = OrderStatus.CONFIRMED;
    this.addEvent(new OrderConfirmedEvent(this.id, this.calculateTotal()));
  }

  private addEvent(event: DomainEvent): void {
    this.version++;
    event.version = this.version;
    this.events.push(event);
  }

  getUncommittedEvents(): DomainEvent[] {
    return [...this.events];
  }

  markEventsAsCommitted(): void {
    this.events = [];
  }
}

// Event handlers for read models
class OrderProjectionHandler {
  constructor(
    private orderReadModel: OrderReadModelRepository,
    private inventoryService: InventoryService,
  ) {}

  @EventHandler(OrderConfirmedEvent)
  async handleOrderConfirmed(event: OrderConfirmedEvent): Promise<void> {
    // Update read model
    await this.orderReadModel.updateStatus(event.orderId, 'confirmed');
    
    // Update inventory
    await this.inventoryService.reserveItems(event.orderId);
    
    // Send notification
    await this.notificationService.sendOrderConfirmation(event.orderId);
  }
}
```

---

### 5. CQRS (Command Query Responsibility Segregation)

Complex applications separate read and write operations for better performance and scalability.

#### CQRS Implementation
```typescript
// Command side - Write operations
interface Command {
  execute(): Promise<void>;
}

class CreateOrderCommand implements Command {
  constructor(
    private orderId: string,
    private customerId: string,
    private items: CreateOrderItemDto[],
    private orderRepository: OrderRepository,
  ) {}

  async execute(): Promise<void> {
    const order = new Order(this.orderId, this.customerId);
    
    for (const item of this.items) {
      order.addItem(item.productId, item.quantity, item.price);
    }

    await this.orderRepository.save(order);
  }
}

// Query side - Read operations
interface Query<T> {
  execute(): Promise<T>;
}

class GetOrdersByCustomerQuery implements Query<OrderSummary[]> {
  constructor(
    private customerId: string,
    private orderReadModel: OrderReadModelRepository,
  ) {}

  async execute(): Promise<OrderSummary[]> {
    return await this.orderReadModel.findByCustomerId(this.customerId);
  }
}

// CQRS bus implementation
class CommandBus {
  private handlers = new Map<string, Command>();

  register<T extends Command>(commandType: string, handler: new (...args: any[]) => T): void {
    this.handlers.set(commandType, handler);
  }

  async execute<T extends Command>(command: T): Promise<void> {
    const handler = this.handlers.get(command.constructor.name);
    if (!handler) {
      throw new Error(`No handler registered for ${command.constructor.name}`);
    }
    await command.execute();
  }
}

class QueryBus {
  private handlers = new Map<string, Query<any>>();

  register<T>(queryType: string, handler: new (...args: any[]) => Query<T>): void {
    this.handlers.set(queryType, handler);
  }

  async execute<T>(query: Query<T>): Promise<T> {
    return await query.execute();
  }
}
```

---

## 📊 Architecture Pattern Comparison

### Complexity vs. Scalability
| Pattern | Implementation Complexity | Scalability | Team Size | Use Case |
|---------|---------------------------|-------------|-----------|----------|
| MVC | Low | Medium | 1-5 | Simple web apps |
| Clean Architecture | High | High | 3-10 | Enterprise apps |
| Microservices | Very High | Very High | 10+ | Large-scale systems |
| Event-Driven | High | High | 5-15 | Real-time systems |
| CQRS | Very High | Very High | 8+ | Complex domains |

### Feature Support Matrix
| Pattern | Real-time | Multi-tenant | Offline | Testing | Maintenance |
|---------|-----------|--------------|---------|---------|-------------|
| MVC | Manual | Manual | Limited | Easy | Easy |
| Clean Architecture | Manual | Good | Good | Excellent | Good |
| Microservices | Excellent | Excellent | Good | Medium | Complex |
| Event-Driven | Excellent | Good | Excellent | Medium | Medium |
| CQRS | Excellent | Excellent | Excellent | Good | Complex |

---

## 🎯 Pattern Selection Guidelines

### For Small Projects (1-3 developers)
- **Start with MVC**: Simple, proven, fast development
- **Add Clean Architecture**: As complexity grows
- **Consider Event-Driven**: For real-time features

### For Medium Projects (3-8 developers)
- **Clean Architecture**: Better testability and maintainability
- **Selective Microservices**: Split critical components
- **Event-Driven**: For complex workflows

### For Large Projects (8+ developers)
- **Microservices**: Team autonomy and scalability
- **CQRS**: For complex read/write patterns
- **Event Sourcing**: For audit trails and complex state

---

## 🔄 Migration Strategies

### From MVC to Clean Architecture
```typescript
// Step 1: Extract domain entities
// Before: In controllers
class UserController {
  async createUser(req, res) {
    const hashedPassword = await bcrypt.hash(req.body.password, 10);
    const user = await User.create({
      email: req.body.email,
      password: hashedPassword,
    });
    res.json(user);
  }
}

// After: Domain entity
class User {
  constructor(email: string, password: string) {
    this.validateEmail(email);
    this.email = email;
    this.password = this.hashPassword(password);
  }

  private validateEmail(email: string): void {
    if (!email.includes('@')) {
      throw new InvalidEmailError('Invalid email format');
    }
  }

  private hashPassword(password: string): string {
    return bcrypt.hashSync(password, 10);
  }
}

// Step 2: Create use cases
class CreateUserUseCase {
  constructor(private userRepository: UserRepository) {}

  async execute(userData: CreateUserDto): Promise<User> {
    const user = new User(userData.email, userData.password);
    return await this.userRepository.save(user);
  }
}

// Step 3: Update controllers
class UserController {
  constructor(private createUserUseCase: CreateUserUseCase) {}

  async createUser(req, res) {
    try {
      const user = await this.createUserUseCase.execute(req.body);
      res.json(user);
    } catch (error) {
      res.status(400).json({ error: error.message });
    }
  }
}
```

---

## 🔗 Navigation

← [Project Analysis](./project-analysis.md) | [Security Best Practices](./security-best-practices.md) →

---

*Architecture analysis: July 2025 | Patterns reviewed: 5 major architectural approaches*