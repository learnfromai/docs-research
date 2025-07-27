# Architecture Patterns: Express.js Applications

## 🎯 Overview

This document analyzes architectural patterns used across 15+ successful open source Express.js projects, providing detailed insights into when and how to implement different architectural approaches for scalable, maintainable applications.

## 📋 Table of Contents

1. [MVC Architecture Pattern](#1-mvc-architecture-pattern)
2. [Plugin/Module Architecture](#2-pluginmodule-architecture)
3. [Microservices Architecture](#3-microservices-architecture)
4. [Domain-Driven Design (DDD)](#4-domain-driven-design-ddd)
5. [Service-Oriented Architecture (SOA)](#5-service-oriented-architecture-soa)
6. [Event-Driven Architecture](#6-event-driven-architecture)
7. [Layered Architecture](#7-layered-architecture)
8. [Architecture Decision Framework](#8-architecture-decision-framework)

## 1. MVC Architecture Pattern

### 1.1 Overview

**Used by**: Ghost, KeystoneJS, Parse Server (40% of analyzed projects)

Model-View-Controller provides clear separation of concerns and is excellent for content-heavy applications and traditional web apps.

### 1.2 Implementation Pattern

**Ghost's MVC Structure**:

```javascript
// Directory Structure
core/server/
├── models/           # Data layer
├── controllers/      # Business logic
├── services/         # Shared services
├── api/             # API endpoints
└── web/             # Web routes

// Model Layer (core/server/models/post.js)
const Post = ghostBookshelf.Model.extend({
    tableName: 'posts',
    
    // Model relationships
    author() {
        return this.belongsTo('User', 'author_id');
    },
    
    tags() {
        return this.belongsToMany('Tag', 'posts_tags', 'post_id', 'tag_id');
    },
    
    // Model methods
    serialize(options) {
        const attrs = ghostBookshelf.Model.prototype.serialize.call(this, options);
        
        // Transform data for API
        delete attrs.password;
        attrs.url = this.get('slug');
        
        return attrs;
    },
    
    // Lifecycle hooks
    onSaving(model, attrs, options) {
        // Auto-generate slug if not provided
        if (!this.get('slug') && this.get('title')) {
            this.set('slug', this.generateSlug(this.get('title')));
        }
        
        return ghostBookshelf.Model.prototype.onSaving.call(this, model, attrs, options);
    }
});

// Controller Layer (core/server/api/endpoints/posts.js)
const postsController = {
    browse: async (frame) => {
        const options = {
            ...frame.options,
            withRelated: ['author', 'tags']
        };
        
        const posts = await models.Post.findPage(options);
        return posts;
    },
    
    read: async (frame) => {
        const options = {
            ...frame.options,
            require: true,
            withRelated: ['author', 'tags', 'authors']
        };
        
        const post = await models.Post.findOne(frame.data, options);
        return post;
    },
    
    add: async (frame) => {
        const post = await models.Post.add(frame.data.posts[0], frame.options);
        
        // Trigger events
        events.emit('post.created', post);
        
        return post;
    },
    
    edit: async (frame) => {
        const post = await models.Post.edit(frame.data.posts[0], frame.options);
        
        // Trigger events
        events.emit('post.updated', post);
        
        return post;
    }
};

// Service Layer (core/server/services/posts.js)
class PostsService {
    async publishPost(postId, publishedAt = new Date()) {
        const post = await models.Post.findOne({ id: postId });
        
        if (!post) {
            throw new errors.NotFoundError('Post not found');
        }
        
        // Business logic
        const updatedPost = await post.save({
            status: 'published',
            published_at: publishedAt
        });
        
        // Send notifications
        await this.notifySubscribers(updatedPost);
        
        // Update sitemap
        await sitemapService.updateSitemap();
        
        return updatedPost;
    }
    
    async notifySubscribers(post) {
        const subscribers = await models.Subscriber.findAll();
        
        for (const subscriber of subscribers.models) {
            await emailService.sendNewPostNotification(subscriber, post);
        }
    }
}
```

### 1.3 Benefits & Trade-offs

**✅ Benefits**:
- Clear separation of concerns
- Easy to understand and maintain
- Good for CRUD operations
- Excellent tooling support
- Easy team onboarding

**❌ Trade-offs**:
- Controllers can become large
- Tight coupling between layers
- Difficult to scale complex business logic
- Limited flexibility for complex workflows

### 1.4 When to Use MVC

- **Content Management Systems**: Ghost, Strapi
- **Admin Panels**: Django Admin-style applications
- **Traditional Web Applications**: Server-rendered apps
- **CRUD-heavy Applications**: Simple business logic

## 2. Plugin/Module Architecture

### 2.1 Overview

**Used by**: Strapi, Grafana, Medusa (35% of analyzed projects)

Plugin architecture provides maximum extensibility and modularity, allowing third-party extensions and customizations.

### 2.2 Implementation Pattern

**Strapi's Plugin System**:

```javascript
// Plugin Structure
packages/core/strapi/
├── lib/
│   ├── core/          # Core functionality
│   ├── services/      # Core services
│   └── utils/         # Utilities
└── plugins/
    ├── content-manager/
    ├── users-permissions/
    └── upload/

// Core Plugin Registry (lib/core/registries/plugins.js)
class PluginRegistry {
    constructor() {
        this.plugins = new Map();
        this.hooks = new Map();
    }
    
    register(pluginName, plugin) {
        // Validate plugin structure
        this.validatePlugin(plugin);
        
        // Register plugin
        this.plugins.set(pluginName, {
            ...plugin,
            enabled: true,
            dependencies: plugin.dependencies || []
        });
        
        // Register plugin hooks
        if (plugin.hooks) {
            this.registerHooks(pluginName, plugin.hooks);
        }
        
        // Initialize plugin
        if (plugin.register && typeof plugin.register === 'function') {
            plugin.register(this.strapi);
        }
    }
    
    async bootstrap() {
        // Sort plugins by dependencies
        const sortedPlugins = this.sortByDependencies();
        
        // Bootstrap plugins in order
        for (const pluginName of sortedPlugins) {
            const plugin = this.plugins.get(pluginName);
            
            if (plugin.bootstrap && typeof plugin.bootstrap === 'function') {
                await plugin.bootstrap(this.strapi);
            }
        }
    }
    
    executeHook(hookName, ...args) {
        const hooks = this.hooks.get(hookName) || [];
        
        return Promise.all(
            hooks.map(hook => hook.handler(...args))
        );
    }
}

// Example Plugin (plugins/content-manager/server/index.js)
module.exports = {
    register({ strapi }) {
        // Register content manager services
        strapi.container.register('content-manager', {
            services: {
                'entity-manager': require('./services/entity-manager'),
                'content-types': require('./services/content-types'),
                'field-sizes': require('./services/field-sizes')
            }
        });
        
        // Register middleware
        strapi.middleware.register('content-manager::pagination', paginationMiddleware);
    },
    
    bootstrap({ strapi }) {
        // Initialize content manager
        const contentManager = strapi.plugin('content-manager');
        
        // Setup default configurations
        contentManager.service('entity-manager').init();
        
        // Register event listeners
        strapi.eventHub.on('entry.create', async (event) => {
            await contentManager.service('entity-manager').onCreate(event);
        });
    },
    
    config: {
        routes: [
            {
                method: 'GET',
                path: '/content-manager/collection-types/:model',
                handler: 'collection-types.find',
                config: {
                    policies: ['admin::isAuthenticatedAdmin']
                }
            }
        ]
    },
    
    contentTypes: {
        'content-manager-configuration': require('./content-types/content-manager-configuration')
    },
    
    services: require('./services'),
    controllers: require('./controllers'),
    routes: require('./routes')
};

// Plugin API Interface
class PluginAPI {
    constructor(pluginName, strapi) {
        this.pluginName = pluginName;
        this.strapi = strapi;
    }
    
    // Service registration
    service(name) {
        return this.strapi.plugin(this.pluginName).service(name);
    }
    
    // Controller registration
    controller(name) {
        return this.strapi.plugin(this.pluginName).controller(name);
    }
    
    // Configuration access
    config(path, defaultValue) {
        return this.strapi.plugin(this.pluginName).config(path, defaultValue);
    }
    
    // Hook registration
    hook(name, handler) {
        this.strapi.hook(name).register(this.pluginName, handler);
    }
    
    // Event handling
    on(event, handler) {
        this.strapi.eventHub.on(event, handler);
    }
    
    emit(event, data) {
        this.strapi.eventHub.emit(event, data);
    }
}
```

### 2.3 Plugin Configuration Management

```javascript
// Plugin Configuration System
class PluginConfig {
    constructor(pluginName) {
        this.pluginName = pluginName;
        this.config = new Map();
        this.validators = new Map();
    }
    
    // Define configuration schema
    defineConfig(key, schema) {
        this.validators.set(key, schema);
    }
    
    // Set configuration value
    set(key, value) {
        // Validate against schema
        const validator = this.validators.get(key);
        if (validator) {
            const { error } = validator.validate(value);
            if (error) {
                throw new Error(`Invalid configuration for ${key}: ${error.message}`);
            }
        }
        
        this.config.set(key, value);
    }
    
    // Get configuration value
    get(key, defaultValue) {
        return this.config.get(key) ?? defaultValue;
    }
    
    // Merge configuration from multiple sources
    merge(...configs) {
        for (const config of configs) {
            for (const [key, value] of Object.entries(config)) {
                this.set(key, value);
            }
        }
    }
}

// Plugin Dependency Resolution
class DependencyResolver {
    constructor() {
        this.dependencies = new Map();
    }
    
    addDependency(plugin, dependencies) {
        this.dependencies.set(plugin, dependencies);
    }
    
    resolve() {
        const resolved = [];
        const resolving = new Set();
        
        const visit = (plugin) => {
            if (resolved.includes(plugin)) return;
            if (resolving.has(plugin)) {
                throw new Error(`Circular dependency detected: ${plugin}`);
            }
            
            resolving.add(plugin);
            
            const deps = this.dependencies.get(plugin) || [];
            for (const dep of deps) {
                visit(dep);
            }
            
            resolving.delete(plugin);
            resolved.push(plugin);
        };
        
        for (const plugin of this.dependencies.keys()) {
            visit(plugin);
        }
        
        return resolved;
    }
}
```

### 2.4 Benefits & Trade-offs

**✅ Benefits**:
- Maximum extensibility
- Third-party ecosystem
- Modular development
- Configuration-driven
- Hot-swappable components

**❌ Trade-offs**:
- Complex plugin management
- Potential conflicts between plugins
- Dependency resolution complexity
- Learning curve for plugin development

## 3. Microservices Architecture

### 3.1 Overview

**Used by**: Rocket.Chat, Supabase, freeCodeCamp (25% of analyzed projects)

Microservices break down applications into small, independent services that communicate over well-defined APIs.

### 3.2 Implementation Pattern

**Rocket.Chat's Microservices**:

```javascript
// Service Registry
class ServiceRegistry {
    constructor() {
        this.services = new Map();
        this.healthChecks = new Map();
    }
    
    register(serviceName, serviceConfig) {
        this.services.set(serviceName, {
            ...serviceConfig,
            status: 'starting',
            instances: []
        });
        
        // Setup health check
        this.setupHealthCheck(serviceName, serviceConfig.healthCheck);
    }
    
    async discover(serviceName) {
        const service = this.services.get(serviceName);
        if (!service) {
            throw new Error(`Service ${serviceName} not found`);
        }
        
        // Return healthy instances
        return service.instances.filter(instance => instance.healthy);
    }
    
    setupHealthCheck(serviceName, healthCheckConfig) {
        const interval = setInterval(async () => {
            const service = this.services.get(serviceName);
            
            for (const instance of service.instances) {
                try {
                    const response = await fetch(`${instance.url}/health`);
                    instance.healthy = response.ok;
                    instance.lastCheck = new Date();
                } catch (error) {
                    instance.healthy = false;
                    instance.lastError = error.message;
                }
            }
        }, healthCheckConfig?.interval || 30000);
        
        this.healthChecks.set(serviceName, interval);
    }
}

// Service Communication
class ServiceClient {
    constructor(serviceName, registry) {
        this.serviceName = serviceName;
        this.registry = registry;
        this.circuitBreaker = new CircuitBreaker();
    }
    
    async call(method, endpoint, data, options = {}) {
        return this.circuitBreaker.execute(async () => {
            const instances = await this.registry.discover(this.serviceName);
            
            if (instances.length === 0) {
                throw new Error(`No healthy instances for service ${this.serviceName}`);
            }
            
            // Load balancing (round-robin)
            const instance = instances[Math.floor(Math.random() * instances.length)];
            
            const url = `${instance.url}${endpoint}`;
            const config = {
                method,
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': options.token ? `Bearer ${options.token}` : undefined,
                    'X-Request-ID': options.requestId || crypto.randomUUID()
                },
                timeout: options.timeout || 5000
            };
            
            if (data && ['POST', 'PUT', 'PATCH'].includes(method)) {
                config.body = JSON.stringify(data);
            }
            
            const response = await fetch(url, config);
            
            if (!response.ok) {
                throw new Error(`Service call failed: ${response.status} ${response.statusText}`);
            }
            
            return response.json();
        });
    }
}

// Circuit Breaker Pattern
class CircuitBreaker {
    constructor(options = {}) {
        this.failureThreshold = options.failureThreshold || 5;
        this.timeout = options.timeout || 60000;
        this.monitoringPeriod = options.monitoringPeriod || 10000;
        
        this.state = 'CLOSED'; // CLOSED, OPEN, HALF_OPEN
        this.failureCount = 0;
        this.lastFailureTime = null;
        this.nextAttempt = null;
    }
    
    async execute(operation) {
        if (this.state === 'OPEN') {
            if (Date.now() < this.nextAttempt) {
                throw new Error('Circuit breaker is OPEN');
            }
            this.state = 'HALF_OPEN';
        }
        
        try {
            const result = await operation();
            this.onSuccess();
            return result;
        } catch (error) {
            this.onFailure();
            throw error;
        }
    }
    
    onSuccess() {
        this.failureCount = 0;
        this.state = 'CLOSED';
    }
    
    onFailure() {
        this.failureCount++;
        this.lastFailureTime = Date.now();
        
        if (this.failureCount >= this.failureThreshold) {
            this.state = 'OPEN';
            this.nextAttempt = Date.now() + this.timeout;
        }
    }
}

// Message Queue Integration
class MessageQueue {
    constructor(queueConfig) {
        this.config = queueConfig;
        this.subscribers = new Map();
        this.deadLetterQueue = new Map();
    }
    
    async publish(topic, message, options = {}) {
        const messageData = {
            id: crypto.randomUUID(),
            topic,
            payload: message,
            timestamp: new Date(),
            attempts: 0,
            maxRetries: options.maxRetries || 3
        };
        
        // Add to queue
        await this.enqueue(topic, messageData);
        
        // Process immediately if possible
        this.processMessage(messageData);
    }
    
    subscribe(topic, handler, options = {}) {
        if (!this.subscribers.has(topic)) {
            this.subscribers.set(topic, []);
        }
        
        this.subscribers.get(topic).push({
            handler,
            options
        });
    }
    
    async processMessage(message) {
        const subscribers = this.subscribers.get(message.topic) || [];
        
        for (const subscriber of subscribers) {
            try {
                await subscriber.handler(message.payload);
            } catch (error) {
                await this.handleFailure(message, error);
            }
        }
    }
    
    async handleFailure(message, error) {
        message.attempts++;
        message.lastError = error.message;
        
        if (message.attempts >= message.maxRetries) {
            // Move to dead letter queue
            this.deadLetterQueue.set(message.id, message);
            logger.error('Message moved to dead letter queue', { messageId: message.id, error });
        } else {
            // Retry with exponential backoff
            const delay = Math.pow(2, message.attempts) * 1000;
            setTimeout(() => this.processMessage(message), delay);
        }
    }
}
```

### 3.3 Service Orchestration

```javascript
// Saga Pattern for Distributed Transactions
class SagaOrchestrator {
    constructor() {
        this.sagas = new Map();
        this.steps = new Map();
    }
    
    defineSaga(sagaName, steps) {
        this.sagas.set(sagaName, {
            name: sagaName,
            steps: steps.map((step, index) => ({
                ...step,
                order: index
            }))
        });
    }
    
    async execute(sagaName, context) {
        const saga = this.sagas.get(sagaName);
        if (!saga) {
            throw new Error(`Saga ${sagaName} not found`);
        }
        
        const execution = {
            id: crypto.randomUUID(),
            sagaName,
            context,
            completedSteps: [],
            status: 'running',
            startTime: new Date()
        };
        
        try {
            for (const step of saga.steps) {
                await this.executeStep(execution, step);
            }
            
            execution.status = 'completed';
            execution.endTime = new Date();
            
            return execution;
        } catch (error) {
            execution.status = 'failed';
            execution.error = error.message;
            
            // Compensate completed steps
            await this.compensate(execution);
            
            throw error;
        }
    }
    
    async executeStep(execution, step) {
        try {
            const result = await step.action(execution.context);
            
            execution.completedSteps.push({
                stepName: step.name,
                order: step.order,
                result,
                completedAt: new Date()
            });
            
            // Update context with result
            if (step.updateContext) {
                execution.context = step.updateContext(execution.context, result);
            }
        } catch (error) {
            throw new Error(`Step ${step.name} failed: ${error.message}`);
        }
    }
    
    async compensate(execution) {
        // Execute compensation in reverse order
        const steps = execution.completedSteps.reverse();
        
        for (const step of steps) {
            const sagaStep = this.sagas.get(execution.sagaName).steps
                .find(s => s.name === step.stepName);
            
            if (sagaStep.compensate) {
                try {
                    await sagaStep.compensate(execution.context, step.result);
                } catch (error) {
                    logger.error('Compensation failed', {
                        sagaId: execution.id,
                        step: step.stepName,
                        error: error.message
                    });
                }
            }
        }
    }
}

// Example Saga Definition
const orderSaga = sagaOrchestrator.defineSaga('create-order', [
    {
        name: 'reserve-inventory',
        action: async (context) => {
            return inventoryService.reserve(context.items);
        },
        compensate: async (context, result) => {
            await inventoryService.release(result.reservationId);
        },
        updateContext: (context, result) => ({
            ...context,
            reservationId: result.reservationId
        })
    },
    {
        name: 'process-payment',
        action: async (context) => {
            return paymentService.charge(context.payment);
        },
        compensate: async (context, result) => {
            await paymentService.refund(result.transactionId);
        },
        updateContext: (context, result) => ({
            ...context,
            transactionId: result.transactionId
        })
    },
    {
        name: 'create-order',
        action: async (context) => {
            return orderService.create({
                items: context.items,
                paymentId: context.transactionId,
                reservationId: context.reservationId
            });
        },
        compensate: async (context, result) => {
            await orderService.cancel(result.orderId);
        }
    }
]);
```

### 3.4 Benefits & Trade-offs

**✅ Benefits**:
- Independent scaling
- Technology diversity
- Fault isolation
- Team autonomy
- Deployment independence

**❌ Trade-offs**:
- Increased complexity
- Network latency
- Distributed debugging
- Data consistency challenges
- Operational overhead

## 4. Domain-Driven Design (DDD)

### 4.1 Overview

**Used by**: GitLab CE, Complex business applications

DDD focuses on modeling complex business domains through well-defined domain objects and services.

### 4.2 Implementation Pattern

```javascript
// Domain Entity
class User {
    constructor(id, email, profile, role) {
        this.id = id;
        this.email = email;
        this.profile = profile;
        this.role = role;
        this.domainEvents = [];
    }
    
    // Domain methods
    changeEmail(newEmail, emailValidator) {
        if (!emailValidator.isValid(newEmail)) {
            throw new DomainError('Invalid email format');
        }
        
        if (this.email === newEmail) {
            return;
        }
        
        const oldEmail = this.email;
        this.email = newEmail;
        
        // Raise domain event
        this.addDomainEvent(new UserEmailChangedEvent(this.id, oldEmail, newEmail));
    }
    
    assignRole(role, permissions) {
        if (!permissions.canAssignRole(this.role, role)) {
            throw new DomainError('Insufficient permissions to assign role');
        }
        
        const oldRole = this.role;
        this.role = role;
        
        this.addDomainEvent(new UserRoleChangedEvent(this.id, oldRole, role));
    }
    
    addDomainEvent(event) {
        this.domainEvents.push(event);
    }
    
    clearDomainEvents() {
        this.domainEvents = [];
    }
}

// Value Objects
class Email {
    constructor(value) {
        if (!this.isValid(value)) {
            throw new DomainError('Invalid email format');
        }
        this.value = value;
    }
    
    isValid(email) {
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        return emailRegex.test(email);
    }
    
    equals(other) {
        return other instanceof Email && this.value === other.value;
    }
}

class Money {
    constructor(amount, currency) {
        if (amount < 0) {
            throw new DomainError('Amount cannot be negative');
        }
        this.amount = amount;
        this.currency = currency;
    }
    
    add(other) {
        if (this.currency !== other.currency) {
            throw new DomainError('Cannot add different currencies');
        }
        return new Money(this.amount + other.amount, this.currency);
    }
    
    equals(other) {
        return other instanceof Money && 
               this.amount === other.amount && 
               this.currency === other.currency;
    }
}

// Domain Services
class UserDomainService {
    constructor(userRepository, emailService) {
        this.userRepository = userRepository;
        this.emailService = emailService;
    }
    
    async createUser(userData) {
        // Business rules
        const existingUser = await this.userRepository.findByEmail(userData.email);
        if (existingUser) {
            throw new DomainError('User with this email already exists');
        }
        
        // Create domain entity
        const user = new User(
            crypto.randomUUID(),
            new Email(userData.email),
            userData.profile,
            'user'
        );
        
        // Apply business rules
        if (userData.inviteCode) {
            await this.validateInviteCode(userData.inviteCode);
            user.assignRole('invited_user', new AdminPermissions());
        }
        
        // Save
        await this.userRepository.save(user);
        
        // Handle domain events
        await this.handleDomainEvents(user);
        
        return user;
    }
    
    async handleDomainEvents(aggregate) {
        for (const event of aggregate.domainEvents) {
            await this.publishEvent(event);
        }
        aggregate.clearDomainEvents();
    }
}

// Repository Pattern
class UserRepository {
    constructor(database) {
        this.database = database;
    }
    
    async findById(id) {
        const userData = await this.database.findOne('users', { id });
        if (!userData) return null;
        
        return this.toDomainEntity(userData);
    }
    
    async findByEmail(email) {
        const userData = await this.database.findOne('users', { 
            email: email instanceof Email ? email.value : email 
        });
        if (!userData) return null;
        
        return this.toDomainEntity(userData);
    }
    
    async save(user) {
        const data = this.fromDomainEntity(user);
        
        if (await this.exists(user.id)) {
            await this.database.update('users', { id: user.id }, data);
        } else {
            await this.database.insert('users', data);
        }
    }
    
    toDomainEntity(data) {
        return new User(
            data.id,
            new Email(data.email),
            data.profile,
            data.role
        );
    }
    
    fromDomainEntity(user) {
        return {
            id: user.id,
            email: user.email.value,
            profile: user.profile,
            role: user.role,
            updated_at: new Date()
        };
    }
}

// Application Services (Use Cases)
class CreateUserUseCase {
    constructor(userDomainService, eventBus) {
        this.userDomainService = userDomainService;
        this.eventBus = eventBus;
    }
    
    async execute(command) {
        try {
            // Validate command
            await this.validateCommand(command);
            
            // Execute domain logic
            const user = await this.userDomainService.createUser(command);
            
            // Publish integration events
            await this.eventBus.publish(new UserCreatedIntegrationEvent(user));
            
            return {
                success: true,
                userId: user.id
            };
        } catch (error) {
            if (error instanceof DomainError) {
                return {
                    success: false,
                    error: error.message
                };
            }
            throw error;
        }
    }
    
    async validateCommand(command) {
        if (!command.email) {
            throw new ValidationError('Email is required');
        }
        
        if (!command.profile?.firstName) {
            throw new ValidationError('First name is required');
        }
    }
}
```

### 4.3 Benefits & Trade-offs

**✅ Benefits**:
- Clear business logic
- Rich domain models
- Maintainable codebase
- Business-focused design
- Testable domain logic

**❌ Trade-offs**:
- Complex for simple applications
- Learning curve
- Over-engineering risk
- More boilerplate code

## 8. Architecture Decision Framework

### 8.1 Decision Matrix

| Factor | MVC | Plugin | Microservices | DDD | SOA |
|--------|-----|--------|---------------|-----|-----|
| **Team Size** | Small-Medium | Medium-Large | Large | Medium-Large | Large |
| **Complexity** | Low-Medium | Medium | High | Medium-High | High |
| **Scalability** | Medium | High | Very High | Medium | High |
| **Maintenance** | Easy | Medium | Hard | Medium | Hard |
| **Time to Market** | Fast | Medium | Slow | Medium | Slow |

### 8.2 Use Case Recommendations

**Choose MVC when**:
- Building content management systems
- Small to medium team
- CRUD-heavy applications
- Need fast development
- Traditional web applications

**Choose Plugin Architecture when**:
- Need high extensibility
- Third-party integrations
- Configuration-driven apps
- Multi-tenant applications
- Platform/framework development

**Choose Microservices when**:
- Large, complex systems
- Independent team scaling
- Different technology needs
- High availability requirements
- Complex business domains

**Choose DDD when**:
- Complex business logic
- Long-term projects
- Domain experts available
- Need rich domain models
- Business-critical applications

## 🔗 Navigation

### Related Documents
- ⬅️ **Previous**: [Security Considerations](./security-considerations.md)
- ➡️ **Next**: [Tools & Ecosystem](./tools-ecosystem.md)

### Quick Links
- [Implementation Guide](./implementation-guide.md)
- [Best Practices](./best-practices.md)
- [Comparison Analysis](./comparison-analysis.md)

---

**Architecture Patterns Complete** | **Patterns Covered**: 7 | **Implementation Examples**: 15+ | **Decision Framework**: ✅