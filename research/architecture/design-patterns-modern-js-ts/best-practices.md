# Best Practices: Modern JavaScript/TypeScript Design Patterns

## 🎯 Core Principles for Pattern Implementation Success

This guide provides essential best practices for implementing design patterns in modern JavaScript/TypeScript applications, with focus on maintainability, performance, and team collaboration in international remote work environments.

## 🏗️ General Pattern Implementation Principles

### 1. **Choose Patterns Wisely - Don't Over-Engineer**

```typescript
// ❌ Over-engineered: Using Strategy pattern for simple conditional
class PaymentProcessor {
  private strategy: PaymentStrategy;
  
  setStrategy(strategy: PaymentStrategy) {
    this.strategy = strategy;
  }
  
  processPayment(amount: number) {
    return this.strategy.process(amount);
  }
}

// ✅ Simple and effective: Direct conditional for simple cases
class PaymentProcessor {
  processPayment(amount: number, method: 'credit' | 'paypal' | 'crypto') {
    switch (method) {
      case 'credit':
        return this.processCreditCard(amount);
      case 'paypal':
        return this.processPayPal(amount);
      case 'crypto':
        return this.processCrypto(amount);
      default:
        throw new Error(`Unsupported payment method: ${method}`);
    }
  }
}
```

### 2. **Favor Composition Over Inheritance**

```typescript
// ❌ Heavy inheritance hierarchy
abstract class User {
  abstract getPermissions(): string[];
}

class Student extends User {
  getPermissions() { return ['read_content', 'submit_assignment']; }
}

class PremiumStudent extends Student {
  getPermissions() { return [...super.getPermissions(), 'access_premium']; }
}

// ✅ Composition-based approach with interfaces
interface UserPermissions {
  read_content: boolean;
  submit_assignment: boolean;
  access_premium: boolean;
  admin_access: boolean;
}

interface User {
  id: string;
  email: string;
  permissions: UserPermissions;
}

class UserService {
  createStudent(id: string, email: string): User {
    return {
      id,
      email,
      permissions: {
        read_content: true,
        submit_assignment: true,
        access_premium: false,
        admin_access: false
      }
    };
  }
  
  createPremiumStudent(id: string, email: string): User {
    return {
      id,
      email,
      permissions: {
        read_content: true,
        submit_assignment: true,
        access_premium: true,
        admin_access: false
      }
    };
  }
}
```

### 3. **Use TypeScript's Type System Effectively**

```typescript
// ✅ Leverage discriminated unions for type safety
type AssessmentQuestion = 
  | { type: 'multiple-choice'; options: string[]; correctIndex: number }
  | { type: 'true-false'; correctAnswer: boolean }
  | { type: 'essay'; maxWords: number }
  | { type: 'code'; language: string; expectedOutput: string };

class QuestionProcessor {
  processQuestion(question: AssessmentQuestion): string {
    switch (question.type) {
      case 'multiple-choice':
        // TypeScript knows question has options and correctIndex
        return `MC: ${question.options.join(', ')} (Answer: ${question.correctIndex})`;
      case 'true-false':
        // TypeScript knows question has correctAnswer
        return `T/F: ${question.correctAnswer}`;
      case 'essay':
        // TypeScript knows question has maxWords
        return `Essay: Max ${question.maxWords} words`;
      case 'code':
        // TypeScript knows question has language and expectedOutput
        return `Code (${question.language}): Expected ${question.expectedOutput}`;
      default:
        // TypeScript ensures this is unreachable
        const _exhaustive: never = question;
        throw new Error(`Unhandled question type`);
    }
  }
}
```

## 🚀 Performance Optimization Best Practices

### 1. **Lazy Loading and Dynamic Imports**

```typescript
// ✅ Lazy load pattern implementations
class FeatureManager {
  private loadedFeatures = new Map<string, any>();

  async loadFeature(featureName: string): Promise<any> {
    if (this.loadedFeatures.has(featureName)) {
      return this.loadedFeatures.get(featureName);
    }

    let feature;
    switch (featureName) {
      case 'advanced-analytics':
        const { AdvancedAnalytics } = await import('./features/advanced-analytics');
        feature = new AdvancedAnalytics();
        break;
      case 'ai-tutoring':
        const { AITutoringService } = await import('./features/ai-tutoring');
        feature = new AITutoringService();
        break;
      case 'live-chat':
        const { LiveChatService } = await import('./features/live-chat');
        feature = new LiveChatService();
        break;
      default:
        throw new Error(`Unknown feature: ${featureName}`);
    }

    this.loadedFeatures.set(featureName, feature);
    return feature;
  }
}

// Usage in EdTech platform
class EdTechPlatform {
  private featureManager = new FeatureManager();

  async enablePremiumFeatures(userId: string): Promise<void> {
    const [analytics, aiTutoring] = await Promise.all([
      this.featureManager.loadFeature('advanced-analytics'),
      this.featureManager.loadFeature('ai-tutoring')
    ]);

    analytics.trackUser(userId);
    aiTutoring.initializeForUser(userId);
  }
}
```

### 2. **Memory-Efficient Pattern Implementations**

```typescript
// ✅ Flyweight pattern for efficient content sharing
class ContentFlyweight {
  private static instances = new Map<string, ContentFlyweight>();
  
  private constructor(
    private readonly subject: string,
    private readonly difficulty: string,
    private readonly template: string
  ) {}

  static getInstance(subject: string, difficulty: string, template: string): ContentFlyweight {
    const key = `${subject}-${difficulty}-${template}`;
    
    if (!this.instances.has(key)) {
      this.instances.set(key, new ContentFlyweight(subject, difficulty, template));
    }
    
    return this.instances.get(key)!;
  }

  renderContent(specificData: { studentId: string; progress: number }): string {
    // Combine flyweight (shared) data with context (specific) data
    return this.template
      .replace('{{subject}}', this.subject)
      .replace('{{difficulty}}', this.difficulty)
      .replace('{{studentId}}', specificData.studentId)
      .replace('{{progress}}', specificData.progress.toString());
  }

  // Intrinsic state getters
  getSubject(): string { return this.subject; }
  getDifficulty(): string { return this.difficulty; }
}

// Context class that uses flyweight
class LessonContent {
  private flyweight: ContentFlyweight;
  private extrinsicState: { studentId: string; progress: number };

  constructor(subject: string, difficulty: string, template: string, studentId: string, progress: number) {
    this.flyweight = ContentFlyweight.getInstance(subject, difficulty, template);
    this.extrinsicState = { studentId, progress };
  }

  render(): string {
    return this.flyweight.renderContent(this.extrinsicState);
  }
}

// Factory for managing lesson content efficiently
class LessonContentFactory {
  createNursingLesson(studentId: string, progress: number): LessonContent {
    return new LessonContent(
      'Nursing',
      'Intermediate',
      'Welcome {{studentId}} to {{subject}} ({{difficulty}})! Progress: {{progress}}%',
      studentId,
      progress
    );
  }

  createEngineeringLesson(studentId: string, progress: number): LessonContent {
    return new LessonContent(
      'Engineering',
      'Advanced',
      'Hello {{studentId}}! {{subject}} {{difficulty}} content. You are {{progress}}% complete.',
      studentId,
      progress
    );
  }
}
```

### 3. **Async Pattern Optimization**

```typescript
// ✅ Optimized async patterns with proper error handling
class DatabaseService {
  private connectionPool: any[] = [];
  private readonly maxRetries = 3;
  private readonly retryDelay = 1000;

  async executeWithRetry<T>(operation: () => Promise<T>): Promise<T> {
    let lastError: Error;
    
    for (let attempt = 1; attempt <= this.maxRetries; attempt++) {
      try {
        return await operation();
      } catch (error) {
        lastError = error as Error;
        
        if (attempt === this.maxRetries) {
          throw new Error(`Operation failed after ${this.maxRetries} attempts: ${lastError.message}`);
        }
        
        // Exponential backoff
        await this.delay(this.retryDelay * Math.pow(2, attempt - 1));
      }
    }
    
    throw lastError!;
  }

  async batchProcess<T, R>(
    items: T[], 
    processor: (item: T) => Promise<R>, 
    batchSize: number = 10
  ): Promise<R[]> {
    const results: R[] = [];
    
    for (let i = 0; i < items.length; i += batchSize) {
      const batch = items.slice(i, i + batchSize);
      const batchResults = await Promise.all(
        batch.map(item => this.executeWithRetry(() => processor(item)))
      );
      results.push(...batchResults);
    }
    
    return results;
  }

  private delay(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}

// Usage in EdTech context
class StudentProgressService {
  private dbService = new DatabaseService();

  async updateMultipleStudentProgress(updates: StudentProgressUpdate[]): Promise<void> {
    await this.dbService.batchProcess(
      updates,
      async (update) => {
        return this.updateSingleStudentProgress(update);
      },
      5 // Process 5 updates at a time
    );
  }

  private async updateSingleStudentProgress(update: StudentProgressUpdate): Promise<void> {
    // Individual update logic
    console.log(`Updating progress for student ${update.studentId}`);
  }
}

interface StudentProgressUpdate {
  studentId: string;
  lessonId: string;
  progress: number;
  completedAt: Date;
}
```

## 🔧 Code Organization and Maintainability

### 1. **Modular Pattern Organization**

```typescript
// patterns/index.ts - Centralized pattern exports
export { Factory } from './creational/factory';
export { Builder } from './creational/builder';
export { Singleton } from './creational/singleton';

export { Adapter } from './structural/adapter';
export { Decorator } from './structural/decorator';
export { Facade } from './structural/facade';

export { Observer } from './behavioral/observer';
export { Strategy } from './behavioral/strategy';
export { Command } from './behavioral/command';

// services/pattern-registry.ts - Pattern discovery and registration
interface PatternMetadata {
  name: string;
  category: 'creational' | 'structural' | 'behavioral';
  complexity: 'low' | 'medium' | 'high';
  useCase: string[];
  implementation: any;
}

class PatternRegistry {
  private patterns = new Map<string, PatternMetadata>();

  register(metadata: PatternMetadata): void {
    this.patterns.set(metadata.name, metadata);
  }

  getPattern(name: string): PatternMetadata | undefined {
    return this.patterns.get(name);
  }

  getPatternsByCategory(category: PatternMetadata['category']): PatternMetadata[] {
    return Array.from(this.patterns.values())
      .filter(p => p.category === category);
  }

  getPatternsByComplexity(complexity: PatternMetadata['complexity']): PatternMetadata[] {
    return Array.from(this.patterns.values())
      .filter(p => p.complexity === complexity);
  }

  listAvailablePatterns(): string[] {
    return Array.from(this.patterns.keys());
  }
}

// Initialize pattern registry
export const patternRegistry = new PatternRegistry();

// Register patterns
patternRegistry.register({
  name: 'Factory',
  category: 'creational',
  complexity: 'low',
  useCase: ['object-creation', 'dependency-injection', 'configuration'],
  implementation: Factory
});
```

### 2. **Documentation and Type Safety**

```typescript
/**
 * Advanced Observer pattern implementation with type safety and error handling
 * 
 * @example
 * ```typescript
 * const subject = new TypedSubject<UserAction>();
 * const observer = new UserActionObserver();
 * subject.subscribe(observer);
 * subject.notify({ type: 'login', userId: '123' });
 * ```
 */
class TypedSubject<T> {
  private observers: TypedObserver<T>[] = [];
  private errorHandler?: (error: Error, observer: TypedObserver<T>) => void;

  /**
   * Subscribe an observer to this subject
   * @param observer The observer to add
   * @param errorHandler Optional error handler for this observer
   */
  subscribe(
    observer: TypedObserver<T>, 
    errorHandler?: (error: Error) => void
  ): () => void {
    this.observers.push(observer);
    
    if (errorHandler) {
      // Store error handler for this specific observer
      const observerWithErrorHandler = {
        ...observer,
        errorHandler
      };
      this.observers[this.observers.length - 1] = observerWithErrorHandler;
    }

    // Return unsubscribe function
    return () => {
      const index = this.observers.indexOf(observer);
      if (index > -1) {
        this.observers.splice(index, 1);
      }
    };
  }

  /**
   * Notify all observers with data
   * @param data The data to send to observers
   */
  async notify(data: T): Promise<void> {
    const notifications = this.observers.map(async (observer) => {
      try {
        if ('update' in observer && typeof observer.update === 'function') {
          await observer.update(data);
        }
      } catch (error) {
        if ('errorHandler' in observer && observer.errorHandler) {
          observer.errorHandler(error as Error);
        } else if (this.errorHandler) {
          this.errorHandler(error as Error, observer);
        } else {
          console.error(`Observer error:`, error);
        }
      }
    });

    await Promise.allSettled(notifications);
  }

  /**
   * Set global error handler for all observers
   */
  setErrorHandler(handler: (error: Error, observer: TypedObserver<T>) => void): void {
    this.errorHandler = handler;
  }
}

interface TypedObserver<T> {
  update(data: T): void | Promise<void>;
  errorHandler?: (error: Error) => void;
}

// Usage with strong typing
interface UserAction {
  type: 'login' | 'logout' | 'purchase' | 'lesson_complete';
  userId: string;
  timestamp: Date;
  metadata?: Record<string, any>;
}

class UserAnalyticsObserver implements TypedObserver<UserAction> {
  async update(action: UserAction): Promise<void> {
    switch (action.type) {
      case 'login':
        await this.trackLogin(action.userId, action.timestamp);
        break;
      case 'lesson_complete':
        await this.trackLessonCompletion(action.userId, action.metadata?.lessonId);
        break;
      // TypeScript ensures all cases are handled
    }
  }

  private async trackLogin(userId: string, timestamp: Date): Promise<void> {
    console.log(`📊 User ${userId} logged in at ${timestamp}`);
  }

  private async trackLessonCompletion(userId: string, lessonId: string): Promise<void> {
    console.log(`📚 User ${userId} completed lesson ${lessonId}`);
  }
}
```

## 🌐 Remote Work and International Team Best Practices

### 1. **Clear Communication Patterns**

```typescript
// ✅ Self-documenting pattern implementations
interface PaymentProcessorConfig {
  /** Payment provider (stripe, paypal, etc.) */
  provider: string;
  /** API key for the payment provider */
  apiKey: string;
  /** Currency code (USD, PHP, GBP, AUD) */
  currency: string;
  /** Enable sandbox mode for testing */
  sandbox: boolean;
  /** Webhook endpoint for payment notifications */
  webhookUrl?: string;
}

/**
 * Payment processor using Adapter pattern for multiple payment providers
 * 
 * Supports international payment methods for EdTech platform:
 * - US: Stripe, PayPal
 * - Philippines: GCash, PayMaya (via Paymongo)
 * - UK: Stripe, PayPal, GoCardless
 * - Australia: Stripe, PayPal, BPay
 */
class InternationalPaymentProcessor {
  private adapter: PaymentAdapter;

  constructor(config: PaymentProcessorConfig) {
    this.adapter = PaymentAdapterFactory.create(config);
  }

  /**
   * Process payment with comprehensive error handling
   * 
   * @param amount Payment amount in cents/centavos
   * @param currency Currency code (USD, PHP, GBP, AUD)
   * @param paymentMethod Payment method token
   * @returns Promise<PaymentResult>
   * 
   * @example
   * ```typescript
   * const processor = new InternationalPaymentProcessor(config);
   * const result = await processor.processPayment(5000, 'USD', 'tok_visa');
   * ```
   */
  async processPayment(
    amount: number, 
    currency: string, 
    paymentMethod: string
  ): Promise<PaymentResult> {
    try {
      return await this.adapter.processPayment(amount, currency, paymentMethod);
    } catch (error) {
      throw new PaymentProcessingError(
        `Payment failed: ${error}`,
        { amount, currency, paymentMethod }
      );
    }
  }
}

// Custom error classes for better error handling
class PaymentProcessingError extends Error {
  constructor(
    message: string,
    public readonly context: Record<string, any>
  ) {
    super(message);
    this.name = 'PaymentProcessingError';
  }
}
```

### 2. **Configuration Management for Global Deployment**

```typescript
// config/environment-config.ts
interface EdTechEnvironmentConfig {
  database: DatabaseConfig;
  payment: PaymentConfig;
  features: FeatureFlags;
  localization: LocalizationConfig;
  integrations: IntegrationConfig;
}

interface DatabaseConfig {
  host: string;
  port: number;
  database: string;
  ssl: boolean;
  poolSize: number;
}

interface PaymentConfig {
  providers: {
    us: string[];      // ['stripe', 'paypal']
    ph: string[];      // ['paymongo', 'gcash']
    uk: string[];      // ['stripe', 'gocardless']
    au: string[];      // ['stripe', 'bpay']
  };
  currencies: {
    us: string;        // 'USD'
    ph: string;        // 'PHP'
    uk: string;        // 'GBP'  
    au: string;        // 'AUD'
  };
}

interface LocalizationConfig {
  defaultLanguage: string;
  supportedLanguages: string[];
  timeZones: {
    us: string;        // 'America/New_York'
    ph: string;        // 'Asia/Manila'
    uk: string;        // 'Europe/London'
    au: string;        // 'Australia/Sydney'
  };
}

// Singleton configuration manager with environment-specific loading
class ConfigurationManager {
  private static instance: ConfigurationManager;
  private config: EdTechEnvironmentConfig;

  private constructor() {
    this.loadConfiguration();
  }

  static getInstance(): ConfigurationManager {
    if (!ConfigurationManager.instance) {
      ConfigurationManager.instance = new ConfigurationManager();
    }
    return ConfigurationManager.instance;
  }

  private loadConfiguration(): void {
    const environment = process.env.NODE_ENV || 'development';
    const region = process.env.DEPLOYMENT_REGION || 'us';

    this.config = {
      database: this.loadDatabaseConfig(environment, region),
      payment: this.loadPaymentConfig(region),
      features: this.loadFeatureFlags(environment),
      localization: this.loadLocalizationConfig(region),
      integrations: this.loadIntegrationsConfig(region)
    };
  }

  getConfig(): EdTechEnvironmentConfig {
    return this.config;
  }

  getRegionSpecificConfig<T>(key: keyof EdTechEnvironmentConfig): T {
    return this.config[key] as T;
  }

  private loadDatabaseConfig(environment: string, region: string): DatabaseConfig {
    const baseConfig = {
      host: process.env.DB_HOST || 'localhost',
      port: parseInt(process.env.DB_PORT || '5432'),
      database: process.env.DB_NAME || 'edtech',
      ssl: environment === 'production',
      poolSize: environment === 'production' ? 20 : 5
    };

    // Region-specific overrides
    if (region === 'au' && environment === 'production') {
      baseConfig.poolSize = 15; // Lower latency requirements
    }

    return baseConfig;
  }

  private loadPaymentConfig(region: string): PaymentConfig {
    return {
      providers: {
        us: ['stripe', 'paypal'],
        ph: ['paymongo', 'gcash', 'paymaya'],
        uk: ['stripe', 'paypal', 'gocardless'],
        au: ['stripe', 'paypal', 'bpay']
      },
      currencies: {
        us: 'USD',
        ph: 'PHP', 
        uk: 'GBP',
        au: 'AUD'
      }
    };
  }
}
```

### 3. **Testing Patterns for Remote Teams**

```typescript
// test/patterns/test-helpers.ts
export class PatternTestHelper {
  /**
   * Create mock observer for testing Observer pattern
   */
  static createMockObserver<T>(): jest.Mocked<TypedObserver<T>> {
    return {
      update: jest.fn()
    };
  }

  /**
   * Create test database configuration
   */
  static createTestDatabaseConfig(): DatabaseConfig {
    return {
      host: 'localhost',
      port: 5432,
      database: 'test_edtech',
      ssl: false,
      poolSize: 2
    };
  }

  /**
   * Simulate async operations with controlled timing
   */
  static async simulateNetworkDelay(ms: number = 100): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  /**
   * Generate test data for EdTech scenarios
   */
  static generateTestStudent(overrides?: Partial<Student>): Student {
    return {
      id: `student_${Math.random().toString(36).substr(2, 9)}`,
      email: 'test@example.com',
      name: 'Test Student',
      enrolledCourses: [],
      progress: 0,
      ...overrides
    };
  }

  static generateTestAssessment(overrides?: Partial<Assessment>): Assessment {
    return {
      id: `assessment_${Math.random().toString(36).substr(2, 9)}`,
      title: 'Test Assessment',
      questions: [
        {
          id: 'q1',
          type: 'multiple-choice',
          content: 'Test question?',
          options: ['A', 'B', 'C', 'D'],
          correctAnswer: 0,
          points: 1
        }
      ],
      passingScore: 70,
      randomizeQuestions: false,
      allowRetakes: true,
      metadata: {
        subject: 'Test Subject',
        difficulty: 'beginner',
        tags: ['test'],
        createdBy: 'test-user',
        createdAt: new Date()
      },
      ...overrides
    };
  }
}

// test/integration/payment-processing.test.ts
describe('International Payment Processing Integration', () => {
  describe('US Market Payment Processing', () => {
    test('should process USD payment via Stripe', async () => {
      const config = {
        provider: 'stripe',
        apiKey: 'test_key',
        currency: 'USD',
        sandbox: true
      };

      const processor = new InternationalPaymentProcessor(config);
      const result = await processor.processPayment(5000, 'USD', 'tok_visa');

      expect(result.success).toBe(true);
      expect(result.currency).toBe('USD');
    });
  });

  describe('Philippines Market Payment Processing', () => {
    test('should process PHP payment via Paymongo', async () => {
      const config = {
        provider: 'paymongo',
        apiKey: 'test_key',
        currency: 'PHP',
        sandbox: true
      };

      const processor = new InternationalPaymentProcessor(config);
      const result = await processor.processPayment(25000, 'PHP', 'gcash_token');

      expect(result.success).toBe(true);
      expect(result.currency).toBe('PHP');
    });
  });
});
```

## ⚠️ Common Anti-Patterns to Avoid

### 1. **Overuse of Singleton Pattern**

```typescript
// ❌ Anti-pattern: Everything as Singleton
class DatabaseSingleton {
  private static instance: DatabaseSingleton;
  // ... singleton implementation
}

class LoggerSingleton {
  private static instance: LoggerSingleton; 
  // ... singleton implementation
}

class ConfigSingleton {
  private static instance: ConfigSingleton;
  // ... singleton implementation
}

// ✅ Better approach: Dependency Injection
interface Database {
  query(sql: string): Promise<any>;
}

interface Logger {
  log(message: string): void;
}

interface Config {
  get(key: string): any;
}

class EdTechService {
  constructor(
    private database: Database,
    private logger: Logger,
    private config: Config
  ) {}

  async processStudentEnrollment(studentId: string): Promise<void> {
    this.logger.log(`Processing enrollment for ${studentId}`);
    
    const dbConfig = this.config.get('database');
    await this.database.query(`INSERT INTO enrollments...`);
  }
}

// Dependency injection container
class ServiceContainer {
  private services = new Map<string, any>();

  register<T>(name: string, factory: () => T): void {
    this.services.set(name, factory);
  }

  get<T>(name: string): T {
    const factory = this.services.get(name);
    if (!factory) {
      throw new Error(`Service ${name} not found`);
    }
    return factory();
  }
}
```

### 2. **Inappropriate Observer Usage**

```typescript
// ❌ Anti-pattern: Synchronous heavy operations in observers
class SlowAnalyticsObserver implements Observer<StudentAction> {
  update(action: StudentAction): void {
    // Heavy synchronous operation - blocks the main thread
    this.generateComplexReport(action);
    this.sendEmailNotification(action);
    this.updateDashboards(action);
  }
}

// ✅ Better approach: Async queue-based processing
class EfficientAnalyticsObserver implements Observer<StudentAction> {
  private queue: StudentAction[] = [];
  private processing = false;

  update(action: StudentAction): void {
    this.queue.push(action);
    this.processQueue(); // Non-blocking
  }

  private async processQueue(): Promise<void> {
    if (this.processing) return;
    this.processing = true;

    while (this.queue.length > 0) {
      const batch = this.queue.splice(0, 10); // Process in batches
      await Promise.all(batch.map(action => this.processAction(action)));
    }

    this.processing = false;
  }

  private async processAction(action: StudentAction): Promise<void> {
    try {
      await this.generateComplexReport(action);
      await this.sendEmailNotification(action);
      await this.updateDashboards(action);
    } catch (error) {
      console.error('Failed to process action:', error);
      // Add to retry queue or dead letter queue
    }
  }
}
```

## 📊 Performance Monitoring and Optimization

### Pattern Performance Metrics

```typescript
// Performance monitoring decorator for patterns
function measurePerformance<T extends (...args: any[]) => any>(
  target: any,
  propertyName: string,
  descriptor: TypedPropertyDescriptor<T>
): TypedPropertyDescriptor<T> {
  const method = descriptor.value!;

  descriptor.value = (async function(this: any, ...args: any[]) {
    const start = performance.now();
    const result = await method.apply(this, args);
    const end = performance.now();
    
    console.log(`${target.constructor.name}.${propertyName} took ${end - start} milliseconds`);
    
    // Send metrics to monitoring service
    if (typeof window !== 'undefined' && window.gtag) {
      window.gtag('event', 'pattern_performance', {
        event_category: 'performance',
        event_label: `${target.constructor.name}.${propertyName}`,
        value: Math.round(end - start)
      });
    }
    
    return result;
  }) as any;

  return descriptor;
}

// Usage
class OptimizedStudentService {
  @measurePerformance
  async createStudent(studentData: CreateStudentRequest): Promise<Student> {
    // Implementation with performance tracking
    return new Student(studentData);
  }

  @measurePerformance
  async processEnrollment(studentId: string, courseId: string): Promise<void> {
    // Implementation with performance tracking
  }
}
```

## 🎯 Summary of Best Practices

### Do's for International Success ✅

1. **Use TypeScript extensively** for type safety and better IDE support
2. **Document pattern decisions** with clear rationale and examples
3. **Implement proper error handling** with custom error types
4. **Use async/await consistently** for better readability
5. **Apply patterns selectively** - don't over-engineer simple solutions
6. **Write comprehensive tests** for pattern implementations
7. **Consider performance implications** of pattern choices
8. **Use dependency injection** instead of excessive singletons
9. **Implement proper logging** and monitoring for distributed teams
10. **Follow consistent naming conventions** across patterns

### Don'ts That Limit Success ❌

1. **Don't implement patterns without understanding the problem**
2. **Don't use inheritance when composition would work better**
3. **Don't ignore memory leaks** in Observer pattern implementations
4. **Don't block the main thread** with heavy synchronous operations
5. **Don't hardcode configuration** for different deployment regions
6. **Don't skip error handling** in pattern implementations
7. **Don't forget to clean up resources** (event listeners, subscriptions)
8. **Don't use patterns to show off** - prioritize code clarity
9. **Don't ignore team skill levels** when choosing complex patterns
10. **Don't forget accessibility** and internationalization requirements

---

**Next Steps**: Continue to [Comparison Analysis](./comparison-analysis.md) for detailed pattern comparisons or explore [Pattern Catalog](./pattern-catalog.md) for complete implementations.

[🏠 Back to Overview](./README.md) | [📊 Comparison Analysis →](./comparison-analysis.md) | [📚 Pattern Catalog →](./pattern-catalog.md)