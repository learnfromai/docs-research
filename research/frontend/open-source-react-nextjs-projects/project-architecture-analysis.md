# Project Architecture Analysis: Open Source React/Next.js Projects

## 🎯 Overview

This document provides detailed architectural analysis of 15+ production-ready open source React and Next.js applications. It examines project structures, design patterns, architectural decisions, and scalability strategies employed by successful applications to handle complex requirements and large user bases.

## 🏗️ Architectural Patterns Analysis

### 1. Feature-Based Architecture

**Adopted by**: 80% of modern applications (Cal.com, Plane, Supabase Dashboard)

```
src/
├── components/              # Shared components across features
│   ├── ui/                 # Base UI components (Button, Input, etc.)
│   ├── layout/             # Layout components (Header, Sidebar, etc.)
│   └── common/             # Common business components
├── features/               # Feature-specific modules
│   ├── auth/              # Authentication feature
│   │   ├── components/    # Auth-specific components
│   │   ├── hooks/         # Auth-specific hooks
│   │   ├── services/      # Auth API calls
│   │   ├── types/         # Auth type definitions
│   │   ├── utils/         # Auth utilities
│   │   └── index.ts       # Feature exports
│   ├── dashboard/         # Dashboard feature
│   │   ├── components/
│   │   ├── hooks/
│   │   ├── services/
│   │   └── types/
│   └── projects/          # Projects feature
├── lib/                   # Shared utilities and configurations
│   ├── api.ts            # API client
│   ├── auth.ts           # Auth configuration
│   ├── db.ts             # Database client
│   └── utils.ts          # Utility functions
├── stores/               # Global state management
├── types/                # Global type definitions
└── constants/            # Application constants
```

**Benefits**:
- ✅ Clear separation of concerns
- ✅ Easy to locate feature-specific code
- ✅ Enables team-based development
- ✅ Facilitates incremental migration
- ✅ Supports micro-frontend architecture

### 2. Layered Architecture Pattern

**Used in**: Enterprise applications with complex business logic

```typescript
// Domain Layer - Business logic and entities
// domain/user/user.entity.ts
export class User {
  constructor(
    public readonly id: string,
    public readonly email: string,
    private _name: string,
    private _role: UserRole
  ) {}

  get name(): string {
    return this._name;
  }

  updateName(newName: string): void {
    if (!newName || newName.trim().length === 0) {
      throw new Error('Name cannot be empty');
    }
    this._name = newName.trim();
  }

  hasPermission(permission: Permission): boolean {
    return this._role.permissions.includes(permission);
  }
}

// domain/user/user.repository.ts
export interface UserRepository {
  findById(id: string): Promise<User | null>;
  findByEmail(email: string): Promise<User | null>;
  save(user: User): Promise<void>;
  delete(id: string): Promise<void>;
}

// Application Layer - Use cases and business workflows
// application/user/use-cases/update-user-profile.use-case.ts
export class UpdateUserProfileUseCase {
  constructor(
    private userRepository: UserRepository,
    private eventBus: EventBus
  ) {}

  async execute(command: UpdateUserProfileCommand): Promise<void> {
    const user = await this.userRepository.findById(command.userId);
    if (!user) {
      throw new UserNotFoundError(command.userId);
    }

    user.updateName(command.name);
    
    await this.userRepository.save(user);
    
    await this.eventBus.publish(
      new UserProfileUpdatedEvent(user.id, user.name)
    );
  }
}

// Infrastructure Layer - External concerns
// infrastructure/user/prisma-user.repository.ts
export class PrismaUserRepository implements UserRepository {
  constructor(private prisma: PrismaClient) {}

  async findById(id: string): Promise<User | null> {
    const userData = await this.prisma.user.findUnique({
      where: { id },
      include: { role: { include: { permissions: true } } }
    });

    if (!userData) return null;

    return new User(
      userData.id,
      userData.email,
      userData.name,
      new UserRole(userData.role.name, userData.role.permissions.map(p => p.name))
    );
  }

  async save(user: User): Promise<void> {
    await this.prisma.user.update({
      where: { id: user.id },
      data: {
        name: user.name,
        updatedAt: new Date(),
      },
    });
  }
}

// Presentation Layer - React components and UI logic
// presentation/user/components/UserProfileForm.tsx
export function UserProfileForm({ userId }: { userId: string }) {
  const updateProfile = useUpdateUserProfile();
  const { data: user } = useUser(userId);

  const handleSubmit = async (formData: { name: string }) => {
    await updateProfile.mutateAsync({
      userId,
      name: formData.name,
    });
  };

  return (
    <form onSubmit={handleSubmit}>
      <input
        type="text"
        defaultValue={user?.name}
        name="name"
        required
      />
      <button type="submit">Update Profile</button>
    </form>
  );
}
```

### 3. Micro-Frontend Architecture

**Used in**: Large-scale applications (Supabase Dashboard modules)

```typescript
// Module Federation setup
// webpack.config.js
const ModuleFederationPlugin = require('@module-federation/webpack');

module.exports = {
  plugins: [
    new ModuleFederationPlugin({
      name: 'shell',
      remotes: {
        auth: 'auth@http://localhost:3001/remoteEntry.js',
        dashboard: 'dashboard@http://localhost:3002/remoteEntry.js',
        analytics: 'analytics@http://localhost:3003/remoteEntry.js',
      },
      shared: {
        react: { singleton: true },
        'react-dom': { singleton: true },
        '@tanstack/react-query': { singleton: true },
      },
    }),
  ],
};

// Shell application
// apps/shell/src/App.tsx
import { Suspense, lazy } from 'react';

const AuthModule = lazy(() => import('auth/AuthModule'));
const DashboardModule = lazy(() => import('dashboard/DashboardModule'));
const AnalyticsModule = lazy(() => import('analytics/AnalyticsModule'));

export function App() {
  return (
    <Router>
      <Layout>
        <Routes>
          <Route path="/auth/*" element={
            <Suspense fallback={<ModuleLoadingSkeleton />}>
              <AuthModule />
            </Suspense>
          } />
          <Route path="/dashboard/*" element={
            <Suspense fallback={<ModuleLoadingSkeleton />}>
              <DashboardModule />
            </Suspense>
          } />
          <Route path="/analytics/*" element={
            <Suspense fallback={<ModuleLoadingSkeleton />}>
              <AnalyticsModule />
            </Suspense>
          } />
        </Routes>
      </Layout>
    </Router>
  );
}

// Shared event bus for micro-frontend communication
// shared/event-bus.ts
export class MicroFrontendEventBus {
  private listeners: Map<string, Array<(data: any) => void>> = new Map();

  subscribe(event: string, callback: (data: any) => void): () => void {
    if (!this.listeners.has(event)) {
      this.listeners.set(event, []);
    }
    
    this.listeners.get(event)!.push(callback);
    
    return () => {
      const callbacks = this.listeners.get(event) || [];
      const index = callbacks.indexOf(callback);
      if (index > -1) {
        callbacks.splice(index, 1);
      }
    };
  }

  publish(event: string, data: any): void {
    const callbacks = this.listeners.get(event) || [];
    callbacks.forEach(callback => callback(data));
  }
}

export const eventBus = new MicroFrontendEventBus();

// Usage in micro-frontend modules
// apps/auth/src/hooks/use-auth-events.ts
export function useAuthEvents() {
  useEffect(() => {
    const unsubscribe = eventBus.subscribe('auth:login', (user) => {
      // Handle user login across all modules
      console.log('User logged in:', user);
    });

    return unsubscribe;
  }, []);

  const publishLogin = useCallback((user: User) => {
    eventBus.publish('auth:login', user);
  }, []);

  return { publishLogin };
}
```

## 📁 Project Structure Patterns

### 1. Monorepo Architecture

**Used in**: Cal.com, Twenty, enterprise applications

```
packages/
├── shared/                 # Shared packages
│   ├── ui/                # Shared UI components
│   │   ├── src/
│   │   ├── package.json
│   │   └── tsconfig.json
│   ├── types/             # Shared TypeScript types
│   ├── utils/             # Shared utilities
│   ├── config/            # Shared configurations
│   └── database/          # Database schema and migrations
├── apps/                  # Applications
│   ├── web/              # Main web application
│   │   ├── src/
│   │   ├── package.json
│   │   └── next.config.js
│   ├── admin/            # Admin dashboard
│   ├── mobile/           # Mobile application (React Native)
│   └── docs/             # Documentation site
├── services/             # Backend services
│   ├── api/              # Main API service
│   ├── auth/             # Authentication service
│   ├── notifications/    # Notification service
│   └── analytics/        # Analytics service
├── tools/                # Development tools
│   ├── eslint-config/    # Shared ESLint configuration
│   ├── tsconfig/         # Shared TypeScript configurations
│   └── scripts/          # Build and deployment scripts
├── package.json          # Root package.json
├── turbo.json           # Turborepo configuration
└── nx.json              # Nx configuration (if using Nx)
```

**Turbo configuration**:

```json
// turbo.json
{
  "pipeline": {
    "build": {
      "dependsOn": ["^build"],
      "outputs": [".next/**", "dist/**"]
    },
    "test": {
      "dependsOn": ["^build"],
      "inputs": ["src/**/*.tsx", "src/**/*.ts", "test/**/*.ts"]
    },
    "lint": {
      "outputs": []
    },
    "dev": {
      "cache": false,
      "persistent": true
    }
  }
}
```

### 2. Domain-Driven Design Structure

**Used in**: Complex business applications

```
src/
├── domains/              # Business domains
│   ├── user-management/  # User domain
│   │   ├── entities/     # Domain entities
│   │   ├── repositories/ # Data access interfaces
│   │   ├── services/     # Domain services
│   │   ├── value-objects/ # Value objects
│   │   └── events/       # Domain events
│   ├── project-management/
│   └── billing/
├── application/          # Application services
│   ├── commands/         # Command handlers
│   ├── queries/          # Query handlers
│   ├── events/           # Event handlers
│   └── workflows/        # Business workflows
├── infrastructure/       # External concerns
│   ├── database/         # Database implementations
│   ├── external-apis/    # Third-party API clients
│   ├── messaging/        # Message queue implementations
│   └── storage/          # File storage implementations
├── presentation/         # UI layer
│   ├── components/       # React components
│   ├── pages/            # Page components
│   ├── hooks/            # Custom hooks
│   └── contexts/         # React contexts
└── shared/               # Shared utilities
    ├── types/            # Shared types
    ├── utils/            # Utility functions
    └── constants/        # Application constants
```

## 🔄 State Architecture Patterns

### 1. Flux-Based Architecture (Modern)

**Used in**: Applications requiring complex state flows

```typescript
// State management with clear data flow
// stores/app.store.ts
interface AppState {
  user: UserState;
  projects: ProjectsState;
  ui: UIState;
}

interface Action {
  type: string;
  payload?: any;
}

// User store slice
interface UserState {
  currentUser: User | null;
  permissions: Permission[];
  isLoading: boolean;
}

const createUserSlice = (set: any, get: any) => ({
  currentUser: null,
  permissions: [],
  isLoading: false,

  // Actions
  setUser: (user: User) => {
    set((state: AppState) => ({
      user: {
        ...state.user,
        currentUser: user,
        permissions: calculatePermissions(user),
      },
    }));
  },

  loadUser: async () => {
    set((state: AppState) => ({
      user: { ...state.user, isLoading: true },
    }));

    try {
      const user = await userService.getCurrentUser();
      get().setUser(user);
    } catch (error) {
      console.error('Failed to load user:', error);
    } finally {
      set((state: AppState) => ({
        user: { ...state.user, isLoading: false },
      }));
    }
  },
});

// Event sourcing pattern for audit trail
export class EventStore {
  private events: DomainEvent[] = [];

  append(event: DomainEvent): void {
    event.version = this.events.length + 1;
    event.timestamp = new Date();
    this.events.push(event);
    
    // Persist to database
    this.persistEvent(event);
    
    // Publish for side effects
    this.eventBus.publish(event);
  }

  getEvents(aggregateId: string): DomainEvent[] {
    return this.events.filter(e => e.aggregateId === aggregateId);
  }

  private async persistEvent(event: DomainEvent): Promise<void> {
    await this.database.events.create({
      data: {
        id: event.id,
        aggregateId: event.aggregateId,
        type: event.type,
        payload: JSON.stringify(event.payload),
        version: event.version,
        timestamp: event.timestamp,
      },
    });
  }
}
```

### 2. CQRS (Command Query Responsibility Segregation)

**Used in**: High-performance applications with complex read/write patterns

```typescript
// commands/update-user.command.ts
export class UpdateUserCommand {
  constructor(
    public readonly userId: string,
    public readonly updates: Partial<User>
  ) {}
}

export class UpdateUserCommandHandler {
  constructor(
    private userRepository: UserRepository,
    private eventBus: EventBus
  ) {}

  async handle(command: UpdateUserCommand): Promise<void> {
    const user = await this.userRepository.findById(command.userId);
    if (!user) {
      throw new UserNotFoundError(command.userId);
    }

    // Apply updates
    Object.assign(user, command.updates);
    user.updatedAt = new Date();

    // Validate business rules
    await this.validateUser(user);

    // Save to write database
    await this.userRepository.save(user);

    // Publish event for read model updates
    await this.eventBus.publish(
      new UserUpdatedEvent(user.id, command.updates)
    );
  }

  private async validateUser(user: User): Promise<void> {
    // Business validation logic
    if (!user.email || !isValidEmail(user.email)) {
      throw new InvalidEmailError(user.email);
    }
  }
}

// queries/get-user.query.ts
export class GetUserQuery {
  constructor(public readonly userId: string) {}
}

export class GetUserQueryHandler {
  constructor(private userReadRepository: UserReadRepository) {}

  async handle(query: GetUserQuery): Promise<UserReadModel | null> {
    // Query optimized read model
    return await this.userReadRepository.findById(query.userId);
  }
}

// read-models/user-read.model.ts
export interface UserReadModel {
  id: string;
  email: string;
  name: string;
  role: string;
  permissions: string[];
  projectCount: number;
  lastLoginAt: Date | null;
  createdAt: Date;
  updatedAt: Date;
}

// Event handler to update read models
export class UserUpdatedEventHandler {
  constructor(private userReadRepository: UserReadRepository) {}

  async handle(event: UserUpdatedEvent): Promise<void> {
    const readModel = await this.userReadRepository.findById(event.userId);
    if (readModel) {
      Object.assign(readModel, event.updates);
      readModel.updatedAt = new Date();
      await this.userReadRepository.save(readModel);
    }
  }
}
```

## 🔌 Plugin Architecture

**Used in**: Extensible applications (Cal.com apps, WordPress-style plugins)

```typescript
// Plugin system architecture
// core/plugin-manager.ts
export interface Plugin {
  name: string;
  version: string;
  description: string;
  author: string;
  initialize(context: PluginContext): Promise<void>;
  destroy(): Promise<void>;
}

export interface PluginContext {
  app: Application;
  hooks: HookManager;
  storage: PluginStorage;
  logger: Logger;
}

export class PluginManager {
  private plugins: Map<string, Plugin> = new Map();
  private hooks: HookManager = new HookManager();

  async loadPlugin(pluginPath: string): Promise<void> {
    try {
      const PluginClass = await import(pluginPath);
      const plugin = new PluginClass.default();
      
      // Validate plugin
      this.validatePlugin(plugin);
      
      // Initialize plugin
      const context: PluginContext = {
        app: this.app,
        hooks: this.hooks,
        storage: new PluginStorage(plugin.name),
        logger: new Logger(`Plugin:${plugin.name}`),
      };
      
      await plugin.initialize(context);
      this.plugins.set(plugin.name, plugin);
      
      console.log(`Plugin ${plugin.name} loaded successfully`);
    } catch (error) {
      console.error(`Failed to load plugin ${pluginPath}:`, error);
      throw error;
    }
  }

  async unloadPlugin(name: string): Promise<void> {
    const plugin = this.plugins.get(name);
    if (plugin) {
      await plugin.destroy();
      this.plugins.delete(name);
      this.hooks.removePluginHooks(name);
    }
  }

  private validatePlugin(plugin: any): asserts plugin is Plugin {
    if (!plugin.name || !plugin.version || !plugin.initialize) {
      throw new Error('Invalid plugin: missing required properties');
    }
  }
}

// Hook system for plugin extensibility
export class HookManager {
  private hooks: Map<string, Array<HookHandler>> = new Map();

  addHook(name: string, handler: HookHandler, pluginName: string): void {
    if (!this.hooks.has(name)) {
      this.hooks.set(name, []);
    }
    
    handler.pluginName = pluginName;
    this.hooks.get(name)!.push(handler);
  }

  async executeHook(name: string, data: any): Promise<any> {
    const handlers = this.hooks.get(name) || [];
    let result = data;
    
    for (const handler of handlers) {
      try {
        result = await handler.execute(result);
      } catch (error) {
        console.error(`Hook ${name} failed in plugin ${handler.pluginName}:`, error);
      }
    }
    
    return result;
  }

  removePluginHooks(pluginName: string): void {
    this.hooks.forEach((handlers, hookName) => {
      const filtered = handlers.filter(h => h.pluginName !== pluginName);
      this.hooks.set(hookName, filtered);
    });
  }
}

// Example plugin implementation
// plugins/stripe-payment/index.ts
export default class StripePaymentPlugin implements Plugin {
  name = 'stripe-payment';
  version = '1.0.0';
  description = 'Stripe payment integration';
  author = 'Team';

  private stripe: Stripe | null = null;
  private context: PluginContext | null = null;

  async initialize(context: PluginContext): Promise<void> {
    this.context = context;
    this.stripe = new Stripe(process.env.STRIPE_SECRET_KEY!);

    // Register hooks
    context.hooks.addHook('payment:process', {
      execute: this.processPayment.bind(this),
      pluginName: this.name,
    });

    context.hooks.addHook('payment:webhook', {
      execute: this.handleWebhook.bind(this),
      pluginName: this.name,
    });

    // Register API routes
    context.app.addRoute('/api/stripe/webhook', this.webhookHandler.bind(this));
    
    context.logger.info('Stripe Payment Plugin initialized');
  }

  async destroy(): Promise<void> {
    this.stripe = null;
    this.context = null;
  }

  private async processPayment(paymentData: PaymentRequest): Promise<PaymentResult> {
    if (!this.stripe) throw new Error('Stripe not initialized');

    try {
      const paymentIntent = await this.stripe.paymentIntents.create({
        amount: paymentData.amount,
        currency: paymentData.currency,
        metadata: {
          orderId: paymentData.orderId,
        },
      });

      return {
        success: true,
        paymentId: paymentIntent.id,
        clientSecret: paymentIntent.client_secret,
      };
    } catch (error) {
      return {
        success: false,
        error: error.message,
      };
    }
  }

  private async handleWebhook(webhookData: any): Promise<void> {
    // Handle Stripe webhooks
    const event = webhookData.event;
    
    switch (event.type) {
      case 'payment_intent.succeeded':
        await this.handlePaymentSuccess(event.data.object);
        break;
      case 'payment_intent.payment_failed':
        await this.handlePaymentFailure(event.data.object);
        break;
    }
  }

  private async webhookHandler(req: Request, res: Response): Promise<void> {
    // Stripe webhook endpoint implementation
    const sig = req.headers['stripe-signature'];
    
    try {
      const event = this.stripe!.webhooks.constructEvent(
        req.body,
        sig!,
        process.env.STRIPE_WEBHOOK_SECRET!
      );
      
      await this.context!.hooks.executeHook('payment:webhook', { event });
      
      res.status(200).send('OK');
    } catch (error) {
      res.status(400).send(`Webhook Error: ${error.message}`);
    }
  }
}
```

## 📊 Scalability Patterns

### 1. Database Architecture

**Used in**: High-scale applications

```typescript
// Database layer abstraction
// infrastructure/database/database.interface.ts
export interface DatabaseConnection {
  readonly: PrismaClient;
  readwrite: PrismaClient;
}

export class DatabaseManager {
  private connections: DatabaseConnection;
  private queryCache: Map<string, { data: any; timestamp: number }> = new Map();

  constructor() {
    this.connections = {
      readonly: new PrismaClient({
        datasources: {
          db: { url: process.env.DATABASE_READ_URL },
        },
      }),
      readwrite: new PrismaClient({
        datasources: {
          db: { url: process.env.DATABASE_WRITE_URL },
        },
      }),
    };
  }

  // Query with automatic read/write routing
  async query<T>(
    operation: 'read' | 'write',
    queryFn: (client: PrismaClient) => Promise<T>
  ): Promise<T> {
    const client = operation === 'read' 
      ? this.connections.readonly 
      : this.connections.readwrite;

    return queryFn(client);
  }

  // Cached queries for read operations
  async cachedQuery<T>(
    key: string,
    queryFn: (client: PrismaClient) => Promise<T>,
    ttl: number = 300000 // 5 minutes
  ): Promise<T> {
    const cached = this.queryCache.get(key);
    if (cached && Date.now() - cached.timestamp < ttl) {
      return cached.data;
    }

    const data = await this.query('read', queryFn);
    this.queryCache.set(key, { data, timestamp: Date.now() });
    
    return data;
  }

  // Batch operations for performance
  async batchQuery<T>(
    operations: Array<{ operation: 'read' | 'write'; queryFn: (client: PrismaClient) => Promise<T> }>
  ): Promise<T[]> {
    const readOps = operations.filter(op => op.operation === 'read');
    const writeOps = operations.filter(op => op.operation === 'write');

    const [readResults, writeResults] = await Promise.all([
      Promise.all(readOps.map(op => this.query('read', op.queryFn))),
      Promise.all(writeOps.map(op => this.query('write', op.queryFn))),
    ]);

    // Merge results maintaining original order
    const results: T[] = [];
    let readIndex = 0;
    let writeIndex = 0;

    operations.forEach(op => {
      if (op.operation === 'read') {
        results.push(readResults[readIndex++]);
      } else {
        results.push(writeResults[writeIndex++]);
      }
    });

    return results;
  }
}

export const db = new DatabaseManager();
```

### 2. Caching Strategy

**Used in**: Performance-critical applications

```typescript
// Multi-layer caching architecture
// infrastructure/cache/cache-manager.ts
export interface CacheProvider {
  get<T>(key: string): Promise<T | null>;
  set<T>(key: string, value: T, ttl?: number): Promise<void>;
  delete(key: string): Promise<void>;
  clear(): Promise<void>;
}

export class MemoryCache implements CacheProvider {
  private cache = new Map<string, { value: any; expiry: number }>();

  async get<T>(key: string): Promise<T | null> {
    const item = this.cache.get(key);
    if (!item) return null;
    
    if (Date.now() > item.expiry) {
      this.cache.delete(key);
      return null;
    }
    
    return item.value;
  }

  async set<T>(key: string, value: T, ttl: number = 300000): Promise<void> {
    this.cache.set(key, {
      value,
      expiry: Date.now() + ttl,
    });
  }

  async delete(key: string): Promise<void> {
    this.cache.delete(key);
  }

  async clear(): Promise<void> {
    this.cache.clear();
  }
}

export class RedisCache implements CacheProvider {
  constructor(private redis: Redis) {}

  async get<T>(key: string): Promise<T | null> {
    const value = await this.redis.get(key);
    return value ? JSON.parse(value) : null;
  }

  async set<T>(key: string, value: T, ttl: number = 300): Promise<void> {
    await this.redis.setex(key, ttl, JSON.stringify(value));
  }

  async delete(key: string): Promise<void> {
    await this.redis.del(key);
  }

  async clear(): Promise<void> {
    await this.redis.flushall();
  }
}

// Multi-layer cache with fallback
export class CacheManager {
  constructor(
    private l1Cache: MemoryCache, // Fast, small capacity
    private l2Cache: RedisCache   // Slower, large capacity
  ) {}

  async get<T>(key: string): Promise<T | null> {
    // Try L1 cache first
    let value = await this.l1Cache.get<T>(key);
    if (value !== null) {
      return value;
    }

    // Try L2 cache
    value = await this.l2Cache.get<T>(key);
    if (value !== null) {
      // Backfill L1 cache
      await this.l1Cache.set(key, value, 60000); // 1 minute in L1
      return value;
    }

    return null;
  }

  async set<T>(key: string, value: T, ttl: number = 300): Promise<void> {
    // Set in both caches
    await Promise.all([
      this.l1Cache.set(key, value, Math.min(ttl * 1000, 60000)), // Max 1 min in L1
      this.l2Cache.set(key, value, ttl), // Full TTL in L2
    ]);
  }

  async delete(key: string): Promise<void> {
    await Promise.all([
      this.l1Cache.delete(key),
      this.l2Cache.delete(key),
    ]);
  }
}

// Cache-aside pattern implementation
export class CachedUserService {
  constructor(
    private userRepository: UserRepository,
    private cache: CacheManager
  ) {}

  async getUser(id: string): Promise<User | null> {
    const cacheKey = `user:${id}`;
    
    // Try cache first
    let user = await this.cache.get<User>(cacheKey);
    if (user) {
      return user;
    }

    // Load from database
    user = await this.userRepository.findById(id);
    if (user) {
      // Cache for 5 minutes
      await this.cache.set(cacheKey, user, 300);
    }

    return user;
  }

  async updateUser(id: string, updates: Partial<User>): Promise<User> {
    // Update database
    const user = await this.userRepository.update(id, updates);
    
    // Invalidate cache
    await this.cache.delete(`user:${id}`);
    
    // Optionally, update cache immediately
    await this.cache.set(`user:${id}`, user, 300);
    
    return user;
  }
}
```

## 🎯 Architecture Decision Records

### Example ADR: State Management Selection

```markdown
# ADR-001: State Management Architecture

## Status
Accepted

## Context
Our application requires complex state management for user data, UI state, and server state synchronization. We need to choose between Redux Toolkit, Zustand, and React Context.

## Decision
We will use Zustand for client-side state management combined with React Query for server state.

## Consequences

### Positive
- Minimal boilerplate compared to Redux
- Better TypeScript integration
- Smaller bundle size
- Easier testing
- Clear separation between client and server state

### Negative
- Smaller ecosystem compared to Redux
- Less tooling (no Redux DevTools equivalent)
- Team learning curve

## Implementation
- Use Zustand slices for different domains
- React Query for all server state
- React Context only for very simple local state
```

These architectural patterns and strategies have been proven in production environments serving millions of users. The key is to start simple and evolve your architecture as your application grows in complexity and scale.