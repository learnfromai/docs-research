# Architecture Patterns in Production Express.js Projects

## 🎯 Overview

This document analyzes the common architectural patterns found across production-ready Express.js projects, providing insights into how successful applications structure their code, manage complexity, and scale effectively.

## 🏗️ Core Architecture Patterns

### 1. Modular MVC with Service Layer (60% Adoption)

**Used by**: Ghost, Parse Server, parts of Strapi

This pattern separates concerns into distinct layers while maintaining modularity for team development and testing.

#### Structure
```
src/
├── controllers/         # HTTP request handling
├── services/           # Business logic and operations
├── models/             # Data models and validation
├── middleware/         # Cross-cutting concerns
├── routes/             # URL routing and parameter handling
├── utils/              # Shared utilities and helpers
└── config/             # Configuration management
```

#### Implementation Example
```typescript
// User Controller
export class UserController {
  constructor(
    private userService: UserService,
    private logger: Logger
  ) {}
  
  async createUser(req: Request, res: Response) {
    try {
      const userData = req.body;
      const user = await this.userService.createUser(userData);
      res.status(201).json({ user });
    } catch (error) {
      this.logger.error('User creation failed', error);
      res.status(400).json({ error: error.message });
    }
  }
  
  async getUser(req: Request, res: Response) {
    const userId = req.params.id;
    const user = await this.userService.getUserById(userId);
    
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    res.json({ user });
  }
}

// User Service
export class UserService {
  constructor(
    private userModel: UserModel,
    private emailService: EmailService,
    private eventBus: EventBus
  ) {}
  
  async createUser(userData: CreateUserData): Promise<User> {
    // Validation
    await this.validateUserData(userData);
    
    // Business logic
    const hashedPassword = await this.hashPassword(userData.password);
    const user = await this.userModel.create({
      ...userData,
      password: hashedPassword
    });
    
    // Side effects
    await this.emailService.sendWelcomeEmail(user.email);
    this.eventBus.emit('user.created', user);
    
    return user;
  }
  
  async getUserById(id: string): Promise<User | null> {
    return this.userModel.findById(id);
  }
  
  private async validateUserData(data: CreateUserData): Promise<void> {
    const schema = Joi.object({
      email: Joi.string().email().required(),
      password: Joi.string().min(8).required(),
      name: Joi.string().min(2).required()
    });
    
    const { error } = schema.validate(data);
    if (error) {
      throw new ValidationError(error.details[0].message);
    }
  }
}

// Route Configuration
export const userRoutes = (userController: UserController) => {
  const router = express.Router();
  
  router.post('/users', 
    validateRequest(createUserSchema),
    authenticateOptional,
    userController.createUser.bind(userController)
  );
  
  router.get('/users/:id',
    authenticateRequired,
    authorizeUserAccess,
    userController.getUser.bind(userController)
  );
  
  return router;
};
```

#### Benefits
- **Clear separation of concerns**: Each layer has a specific responsibility
- **High testability**: Services can be unit tested independently
- **Team scalability**: Different teams can work on different layers
- **Maintainability**: Changes are localized to specific layers

#### Trade-offs
- **Boilerplate code**: More files and structure to maintain
- **Over-engineering risk**: Can be overkill for simple applications
- **Learning curve**: New developers need to understand the pattern

---

### 2. Plugin/Extension Architecture (40% Adoption)

**Used by**: Strapi, Express Gateway

This pattern creates a core system that can be extended through plugins, enabling modular functionality and third-party extensions.

#### Core System Structure
```
core/
├── plugin-manager/      # Plugin lifecycle management
├── event-system/        # Event bus for plugin communication
├── config/              # Configuration registry
├── api/                 # Core API interfaces
└── runtime/             # Plugin execution environment

plugins/
├── authentication/      # Auth plugin
├── content-manager/     # Content management plugin
├── email/               # Email service plugin
└── custom-plugin/       # Custom business logic
```

#### Plugin Interface
```typescript
// Plugin interface definition
interface Plugin {
  name: string;
  version: string;
  dependencies?: string[];
  
  register?(context: PluginContext): void | Promise<void>;
  bootstrap?(context: PluginContext): void | Promise<void>;
  destroy?(): void | Promise<void>;
}

// Plugin context provides access to core systems
interface PluginContext {
  strapi: StrapiInstance;
  config: ConfigService;
  services: ServiceRegistry;
  models: ModelRegistry;
  controllers: ControllerRegistry;
}

// Example plugin implementation
export const authenticationPlugin: Plugin = {
  name: 'authentication',
  version: '1.0.0',
  dependencies: ['users-permissions'],
  
  register({ strapi }) {
    // Register services
    strapi.service('auth', AuthService);
    
    // Register middleware
    strapi.middleware('authenticate', authenticateMiddleware);
    
    // Register routes
    strapi.route('POST', '/auth/login', 'auth.login');
    strapi.route('POST', '/auth/logout', 'auth.logout');
  },
  
  bootstrap({ strapi }) {
    // Initialize authentication strategies
    strapi.service('auth').initializeStrategies();
    
    // Set up event listeners
    strapi.eventBus.on('user.created', (user) => {
      strapi.service('auth').createDefaultRole(user);
    });
  },
  
  destroy() {
    // Cleanup resources
  }
};
```

#### Plugin Manager Implementation
```typescript
export class PluginManager {
  private plugins = new Map<string, Plugin>();
  private loadOrder: string[] = [];
  
  async loadPlugin(plugin: Plugin): Promise<void> {
    // Validate plugin
    this.validatePlugin(plugin);
    
    // Check dependencies
    await this.resolveDependencies(plugin);
    
    // Register plugin
    if (plugin.register) {
      await plugin.register(this.createContext());
    }
    
    this.plugins.set(plugin.name, plugin);
    this.loadOrder.push(plugin.name);
  }
  
  async bootstrapPlugins(): Promise<void> {
    // Bootstrap in dependency order
    for (const pluginName of this.loadOrder) {
      const plugin = this.plugins.get(pluginName);
      if (plugin?.bootstrap) {
        await plugin.bootstrap(this.createContext());
      }
    }
  }
  
  async unloadPlugin(name: string): Promise<void> {
    const plugin = this.plugins.get(name);
    if (plugin?.destroy) {
      await plugin.destroy();
    }
    this.plugins.delete(name);
  }
  
  private async resolveDependencies(plugin: Plugin): Promise<void> {
    if (!plugin.dependencies) return;
    
    for (const dep of plugin.dependencies) {
      if (!this.plugins.has(dep)) {
        throw new Error(`Plugin ${plugin.name} requires ${dep} but it's not loaded`);
      }
    }
  }
}
```

#### Configuration System
```typescript
// Plugin configuration
export interface PluginConfig {
  enabled: boolean;
  resolve?: string;
  config?: Record<string, any>;
}

// Configuration management
export class ConfigService {
  private config: Map<string, any> = new Map();
  
  setPluginConfig(pluginName: string, config: PluginConfig): void {
    this.config.set(`plugin.${pluginName}`, config);
  }
  
  getPluginConfig(pluginName: string): PluginConfig | undefined {
    return this.config.get(`plugin.${pluginName}`);
  }
  
  isPluginEnabled(pluginName: string): boolean {
    const config = this.getPluginConfig(pluginName);
    return config?.enabled ?? false;
  }
}

// Usage in configuration files
module.exports = {
  plugins: {
    'authentication': {
      enabled: true,
      config: {
        jwtSecret: process.env.JWT_SECRET,
        tokenExpiration: '1h'
      }
    },
    'email': {
      enabled: true,
      resolve: './plugins/email',
      config: {
        provider: 'smtp',
        settings: {
          host: process.env.SMTP_HOST,
          port: process.env.SMTP_PORT
        }
      }
    }
  }
};
```

#### Benefits
- **Extensibility**: Easy to add new functionality without modifying core
- **Modularity**: Features can be developed and tested independently
- **Community ecosystem**: Third-party plugins can extend functionality
- **Configuration-driven**: Enable/disable features without code changes

#### Trade-offs
- **Complexity**: Plugin system adds architectural complexity
- **Debugging difficulty**: Issues can span across multiple plugins
- **Performance overhead**: Plugin management and event system overhead
- **Version management**: Plugin compatibility and dependency management

---

### 3. Service-Oriented Architecture (25% Adoption)

**Used by**: Feathers.js, parts of Meteor

This pattern organizes the application around services that handle specific business capabilities, with automatic API generation and real-time capabilities.

#### Service Structure
```typescript
// Base service interface
interface Service {
  find?(params?: Params): Promise<Paginated<any> | any[]>;
  get?(id: Id, params?: Params): Promise<any>;
  create?(data: Partial<any> | Partial<any>[], params?: Params): Promise<any>;
  update?(id: Id, data: any, params?: Params): Promise<any>;
  patch?(id: NullableId, data: Partial<any>, params?: Params): Promise<any>;
  remove?(id: NullableId, params?: Params): Promise<any>;
  setup?(app: Application, path: string): void;
}

// Example service implementation
export class MessagesService implements Service {
  constructor(
    private database: Database,
    private validator: Validator,
    private eventBus: EventBus
  ) {}
  
  async find(params?: Params): Promise<Paginated<Message>> {
    const { query = {}, user } = params || {};
    
    // Apply user-specific filters
    const finalQuery = this.applyUserContext(query, user);
    
    // Execute query with pagination
    const result = await this.database.find('messages', {
      ...finalQuery,
      $limit: params?.$limit || 25,
      $skip: params?.$skip || 0
    });
    
    return {
      total: result.total,
      limit: result.limit,
      skip: result.skip,
      data: result.data
    };
  }
  
  async create(data: Partial<Message>, params?: Params): Promise<Message> {
    // Validation
    const validatedData = await this.validator.validate('message.create', data);
    
    // Add metadata
    const messageData = {
      ...validatedData,
      createdBy: params?.user?.id,
      createdAt: new Date(),
      id: generateId()
    };
    
    // Save to database
    const message = await this.database.create('messages', messageData);
    
    // Emit events for real-time updates
    this.eventBus.emit('messages.created', message);
    
    return message;
  }
  
  async patch(id: Id, data: Partial<Message>, params?: Params): Promise<Message> {
    // Authorization check
    await this.checkUpdatePermission(id, params?.user);
    
    // Validation
    const validatedData = await this.validator.validate('message.update', data);
    
    // Update
    const updatedMessage = await this.database.patch('messages', id, {
      ...validatedData,
      updatedAt: new Date()
    });
    
    // Emit events
    this.eventBus.emit('messages.patched', updatedMessage);
    
    return updatedMessage;
  }
  
  private applyUserContext(query: any, user?: User): any {
    if (!user) return query;
    
    // Users can only see their own messages or public messages
    return {
      ...query,
      $or: [
        { createdBy: user.id },
        { visibility: 'public' }
      ]
    };
  }
  
  private async checkUpdatePermission(messageId: Id, user?: User): Promise<void> {
    if (!user) throw new Forbidden('Authentication required');
    
    const message = await this.database.get('messages', messageId);
    if (message.createdBy !== user.id && user.role !== 'admin') {
      throw new Forbidden('Cannot modify message created by another user');
    }
  }
}
```

#### Auto-Generated API
```typescript
// Service registration automatically creates REST endpoints
app.use('messages', new MessagesService(database, validator, eventBus));

// Automatically available endpoints:
// GET    /messages           -> messagesService.find()
// GET    /messages/:id       -> messagesService.get(id)
// POST   /messages           -> messagesService.create(data)
// PUT    /messages/:id       -> messagesService.update(id, data)
// PATCH  /messages/:id       -> messagesService.patch(id, data)
// DELETE /messages/:id       -> messagesService.remove(id)
```

#### Real-time Integration
```typescript
// Real-time event handling
export class RealTimeManager {
  constructor(private io: SocketIOServer) {}
  
  setupServiceEvents(serviceName: string): void {
    const service = app.service(serviceName);
    
    // Broadcast service events to connected clients
    service.on('created', (data) => {
      this.io.emit(`${serviceName} created`, data);
    });
    
    service.on('updated', (data) => {
      this.io.emit(`${serviceName} updated`, data);
    });
    
    service.on('patched', (data) => {
      this.io.emit(`${serviceName} patched`, data);
    });
    
    service.on('removed', (data) => {
      this.io.emit(`${serviceName} removed`, data);
    });
  }
}

// Client-side real-time subscriptions
const client = feathers();
const socket = io('ws://localhost:3030');
client.configure(socketio(socket));

// Listen for real-time updates
client.service('messages').on('created', message => {
  console.log('New message:', message);
  updateUI(message);
});
```

#### Hook System for Cross-Cutting Concerns
```typescript
// Hooks provide middleware-like functionality for services
const messageHooks = {
  before: {
    all: [
      authenticate('jwt'),
      rateLimit({ max: 100, windowMs: 60000 })
    ],
    find: [
      addUserContext
    ],
    create: [
      validateInput(messageSchema),
      addTimestamps
    ],
    update: [
      validateInput(messageSchema),
      checkOwnership
    ],
    patch: [
      validateInput(messageSchema),
      checkOwnership
    ],
    remove: [
      checkOwnership
    ]
  },
  
  after: {
    all: [
      removePrivateFields(['password', 'internalId'])
    ],
    create: [
      sendNotifications,
      updateSearchIndex
    ]
  },
  
  error: {
    all: [
      logErrors
    ]
  }
};

// Apply hooks to service
app.service('messages').hooks(messageHooks);
```

#### Benefits
- **Rapid development**: Auto-generated APIs reduce boilerplate
- **Real-time by default**: Automatic WebSocket integration
- **Consistent interface**: All services follow the same pattern
- **Composability**: Services can easily interact with each other

#### Trade-offs
- **Less flexibility**: Constrained to the service interface
- **Learning curve**: Different from traditional REST API development
- **Debugging complexity**: Hooks and auto-generation can obscure flow
- **Performance considerations**: Real-time events can create overhead

---

### 4. Event-Driven Architecture (30% Adoption)

**Used by**: Ghost, Parse Server, Strapi (partially)

This pattern uses events to decouple components and handle side effects, making the system more modular and easier to extend.

#### Event System Implementation
```typescript
// Event bus interface
interface EventBus {
  emit(eventName: string, payload: any): void;
  on(eventName: string, handler: EventHandler): void;
  off(eventName: string, handler: EventHandler): void;
  once(eventName: string, handler: EventHandler): void;
}

// Event-driven service
export class UserService {
  constructor(
    private userModel: UserModel,
    private eventBus: EventBus
  ) {}
  
  async createUser(userData: CreateUserData): Promise<User> {
    // Create user
    const user = await this.userModel.create(userData);
    
    // Emit event for side effects
    this.eventBus.emit('user.created', {
      user,
      timestamp: new Date(),
      source: 'user-service'
    });
    
    return user;
  }
  
  async updateUser(id: string, updates: Partial<User>): Promise<User> {
    const oldUser = await this.userModel.findById(id);
    const user = await this.userModel.update(id, updates);
    
    this.eventBus.emit('user.updated', {
      user,
      oldUser,
      changes: updates,
      timestamp: new Date()
    });
    
    return user;
  }
}

// Event handlers for side effects
export class UserEventHandlers {
  constructor(
    private emailService: EmailService,
    private analyticsService: AnalyticsService,
    private cacheService: CacheService
  ) {}
  
  setupEventHandlers(eventBus: EventBus): void {
    eventBus.on('user.created', this.handleUserCreated.bind(this));
    eventBus.on('user.updated', this.handleUserUpdated.bind(this));
    eventBus.on('user.deleted', this.handleUserDeleted.bind(this));
  }
  
  private async handleUserCreated(event: UserCreatedEvent): Promise<void> {
    const { user } = event;
    
    // Send welcome email (non-blocking)
    this.emailService.sendWelcomeEmail(user.email)
      .catch(error => console.error('Failed to send welcome email:', error));
    
    // Track analytics
    this.analyticsService.track('user_registered', {
      userId: user.id,
      email: user.email,
      source: event.source
    });
    
    // Update cache
    await this.cacheService.invalidate(`user:${user.id}`);
  }
  
  private async handleUserUpdated(event: UserUpdatedEvent): Promise<void> {
    const { user, changes } = event;
    
    // If email changed, send confirmation
    if (changes.email) {
      await this.emailService.sendEmailChangeConfirmation(user.email);
    }
    
    // Update search index
    if (changes.name || changes.bio) {
      await this.searchService.updateUserIndex(user);
    }
    
    // Invalidate related caches
    await this.cacheService.invalidatePattern(`user:${user.id}:*`);
  }
}
```

#### Saga Pattern for Complex Workflows
```typescript
// Saga for handling complex business processes
export class UserRegistrationSaga {
  constructor(
    private userService: UserService,
    private emailService: EmailService,
    private paymentService: PaymentService,
    private eventBus: EventBus
  ) {
    this.setupSagaHandlers();
  }
  
  private setupSagaHandlers(): void {
    this.eventBus.on('user.registration.started', this.handleRegistrationStarted.bind(this));
    this.eventBus.on('user.email.verified', this.handleEmailVerified.bind(this));
    this.eventBus.on('user.payment.completed', this.handlePaymentCompleted.bind(this));
    this.eventBus.on('user.registration.failed', this.handleRegistrationFailed.bind(this));
  }
  
  async startRegistration(registrationData: RegistrationData): Promise<void> {
    try {
      // Step 1: Create pending user
      const user = await this.userService.createPendingUser(registrationData);
      
      // Step 2: Send verification email
      await this.emailService.sendVerificationEmail(user.email);
      
      this.eventBus.emit('user.registration.started', {
        userId: user.id,
        email: user.email,
        plan: registrationData.plan
      });
      
    } catch (error) {
      this.eventBus.emit('user.registration.failed', {
        error: error.message,
        data: registrationData
      });
    }
  }
  
  private async handleEmailVerified(event: EmailVerifiedEvent): Promise<void> {
    const { userId } = event;
    
    try {
      // Activate user account
      await this.userService.activateUser(userId);
      
      // If paid plan, initiate payment
      const user = await this.userService.getUser(userId);
      if (user.plan !== 'free') {
        await this.paymentService.createPaymentIntent(userId, user.plan);
        this.eventBus.emit('user.payment.initiated', { userId, plan: user.plan });
      } else {
        this.eventBus.emit('user.registration.completed', { userId });
      }
      
    } catch (error) {
      this.eventBus.emit('user.registration.failed', { userId, error: error.message });
    }
  }
  
  private async handleRegistrationFailed(event: RegistrationFailedEvent): Promise<void> {
    // Cleanup and rollback
    if (event.userId) {
      await this.userService.deletePendingUser(event.userId);
    }
    
    // Send error notification to admin
    await this.emailService.sendAdminAlert('Registration failed', event);
  }
}
```

#### Benefits
- **Loose coupling**: Components don't directly depend on each other
- **Extensibility**: Easy to add new event handlers without modifying existing code
- **Auditability**: Events provide a natural audit trail
- **Scalability**: Events can be processed asynchronously

#### Trade-offs
- **Complexity**: Event flow can be harder to follow and debug
- **Eventual consistency**: System state may be temporarily inconsistent
- **Error handling**: Distributed error handling is more complex
- **Testing**: Integration testing becomes more challenging

---

## 📊 Pattern Selection Guide

### Decision Matrix

| Pattern | Best For | Team Size | Complexity | Learning Curve |
|---------|----------|-----------|------------|----------------|
| **Modular MVC** | Traditional web apps | 3-10 devs | 🟡 Medium | 🟢 Low |
| **Plugin Architecture** | Extensible platforms | 5-20 devs | 🔴 High | 🔴 High |
| **Service-Oriented** | API-first applications | 2-8 devs | 🟡 Medium | 🟡 Medium |
| **Event-Driven** | Complex business logic | 5-15 devs | 🔴 High | 🔴 High |

### Selection Criteria

**Choose Modular MVC when:**
- Building traditional web applications
- Team is familiar with MVC patterns
- Need clear separation of concerns
- Testing is a high priority

**Choose Plugin Architecture when:**
- Building a platform that others will extend
- Need maximum flexibility and extensibility
- Have resources for complex architecture
- Community contributions are important

**Choose Service-Oriented when:**
- Building API-first applications
- Need real-time capabilities
- Want rapid development with consistent patterns
- Team size is small to medium

**Choose Event-Driven when:**
- Have complex business workflows
- Need high scalability and loose coupling
- Side effects and integrations are common
- Team has experience with event systems

## 🔗 References

### Architecture Resources
- [Clean Architecture by Robert C. Martin](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)
- [Microservices Architecture Patterns](https://microservices.io/patterns/)
- [Domain-Driven Design Reference](https://www.domainlanguage.com/wp-content/uploads/2016/05/DDD_Reference_2015-03.pdf)

### Project-Specific Documentation
- [Ghost Architecture Overview](https://github.com/TryGhost/Ghost/wiki/Architecture-Overview)
- [Strapi Plugin Development Guide](https://docs.strapi.io/developer-docs/latest/development/plugin-development.html)
- [Feathers.js Service Architecture](https://feathersjs.com/guides/basics/services.html)
- [Parse Server Cloud Code Guide](https://docs.parseplatform.org/cloudcode/guide/)

---

*Analysis conducted January 2025 | Based on production implementations and architectural best practices*

**Navigation**
- ← Back to: [Project Analysis](./project-analysis.md)
- ↑ Back to: [Main Research Hub](./README.md)
- → Next: [Security Patterns](./security-patterns.md)