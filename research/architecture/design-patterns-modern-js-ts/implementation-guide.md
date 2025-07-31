# Implementation Guide: Modern JavaScript/TypeScript Design Patterns

## 🚀 Getting Started with Modern Pattern Implementation

This comprehensive guide provides step-by-step implementations of all 23 Gang of Four design patterns using modern JavaScript/TypeScript, with focus on contemporary development contexts including React components, Node.js services, and EdTech platform requirements.

## 🏗️ Development Environment Setup

### Prerequisites & Tool Configuration

```bash
# Node.js and Package Manager Setup
node --version # Requires Node.js 18+
npm --version  # or yarn/pnpm

# Create New Pattern Implementation Project
mkdir design-patterns-modern
cd design-patterns-modern
npm init -y

# Essential Dependencies
npm install typescript @types/node
npm install -D jest @types/jest ts-jest
npm install -D eslint @typescript-eslint/parser @typescript-eslint/eslint-plugin
npm install -D prettier

# Optional: React/Frontend Patterns
npm install react @types/react react-dom @types/react-dom

# Optional: Node.js/Backend Patterns  
npm install express @types/express
```

### TypeScript Configuration (tsconfig.json)

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "experimentalDecorators": true,
    "emitDecoratorMetadata": true,
    "resolveJsonModule": true,
    "declaration": true,
    "outDir": "./dist",
    "rootDir": "./src"
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist", "**/*.test.ts"]
}
```

## 🏭 Creational Patterns Implementation

### 1. Factory Method Pattern

**Modern TypeScript Implementation**

```typescript
// Abstract Product Interface
interface DatabaseConnection {
  connect(): Promise<void>;
  query(sql: string): Promise<any>;
  disconnect(): Promise<void>;
}

// Concrete Products
class PostgreSQLConnection implements DatabaseConnection {
  constructor(private config: DatabaseConfig) {}
  
  async connect(): Promise<void> {
    console.log(`Connecting to PostgreSQL: ${this.config.host}`);
    // Actual connection logic
  }
  
  async query(sql: string): Promise<any> {
    console.log(`Executing PostgreSQL query: ${sql}`);
    return { rows: [], rowCount: 0 };
  }
  
  async disconnect(): Promise<void> {
    console.log('Disconnecting from PostgreSQL');
  }
}

class MongoDBConnection implements DatabaseConnection {
  constructor(private config: DatabaseConfig) {}
  
  async connect(): Promise<void> {
    console.log(`Connecting to MongoDB: ${this.config.host}`);
  }
  
  async query(sql: string): Promise<any> {
    console.log(`Executing MongoDB query: ${sql}`);
    return { documents: [], count: 0 };
  }
  
  async disconnect(): Promise<void> {
    console.log('Disconnecting from MongoDB');
  }
}

// Abstract Factory
abstract class DatabaseConnectionFactory {
  abstract createConnection(config: DatabaseConfig): DatabaseConnection;
  
  // Template method using the factory
  async executeQuery(config: DatabaseConfig, query: string): Promise<any> {
    const connection = this.createConnection(config);
    await connection.connect();
    try {
      return await connection.query(query);
    } finally {
      await connection.disconnect();
    }
  }
}

// Concrete Factories
class PostgreSQLFactory extends DatabaseConnectionFactory {
  createConnection(config: DatabaseConfig): DatabaseConnection {
    return new PostgreSQLConnection(config);
  }
}

class MongoDBFactory extends DatabaseConnectionFactory {
  createConnection(config: DatabaseConfig): DatabaseConnection {
    return new MongoDBConnection(config);
  }
}

// Usage in EdTech Context
interface DatabaseConfig {
  host: string;
  port: number;
  database: string;
  username?: string;
  password?: string;
}

class EdTechDatabaseService {
  private factory: DatabaseConnectionFactory;
  
  constructor(dbType: 'postgresql' | 'mongodb') {
    this.factory = dbType === 'postgresql' 
      ? new PostgreSQLFactory() 
      : new MongoDBFactory();
  }
  
  async getStudentProgress(studentId: string): Promise<any> {
    const config: DatabaseConfig = {
      host: process.env.DB_HOST || 'localhost',
      port: parseInt(process.env.DB_PORT || '5432'),
      database: 'edtech_platform'
    };
    
    return this.factory.executeQuery(
      config, 
      `SELECT * FROM student_progress WHERE student_id = '${studentId}'`
    );
  }
}
```

### 2. Builder Pattern

**Fluent API Implementation for Complex Object Construction**

```typescript
// Product: Assessment Configuration
interface Assessment {
  id: string;
  title: string;
  questions: Question[];
  timeLimit?: number;
  passingScore: number;
  randomizeQuestions: boolean;
  allowRetakes: boolean;
  metadata: AssessmentMetadata;
}

interface Question {
  id: string;
  type: 'multiple-choice' | 'true-false' | 'essay' | 'code';
  content: string;
  options?: string[];
  correctAnswer?: string | number;
  points: number;
}

interface AssessmentMetadata {
  subject: string;
  difficulty: 'beginner' | 'intermediate' | 'advanced';
  tags: string[];
  createdBy: string;
  createdAt: Date;
}

// Builder Implementation
class AssessmentBuilder {
  private assessment: Partial<Assessment> = {
    questions: [],
    randomizeQuestions: false,
    allowRetakes: true,
    metadata: {
      tags: [],
      createdAt: new Date()
    } as AssessmentMetadata
  };

  setId(id: string): AssessmentBuilder {
    this.assessment.id = id;
    return this;
  }

  setTitle(title: string): AssessmentBuilder {
    this.assessment.title = title;
    return this;
  }

  addMultipleChoiceQuestion(
    content: string, 
    options: string[], 
    correctAnswer: number, 
    points: number = 1
  ): AssessmentBuilder {
    const question: Question = {
      id: `q_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
      type: 'multiple-choice',
      content,
      options,
      correctAnswer,
      points
    };
    this.assessment.questions!.push(question);
    return this;
  }

  addEssayQuestion(content: string, points: number = 5): AssessmentBuilder {
    const question: Question = {
      id: `q_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
      type: 'essay',
      content,
      points
    };
    this.assessment.questions!.push(question);
    return this;
  }

  setTimeLimit(minutes: number): AssessmentBuilder {
    this.assessment.timeLimit = minutes;
    return this;
  }

  setPassingScore(score: number): AssessmentBuilder {
    this.assessment.passingScore = score;
    return this;
  }

  enableQuestionRandomization(): AssessmentBuilder {
    this.assessment.randomizeQuestions = true;
    return this;
  }

  disableRetakes(): AssessmentBuilder {
    this.assessment.allowRetakes = false;
    return this;
  }

  setSubject(subject: string): AssessmentBuilder {
    this.assessment.metadata!.subject = subject;
    return this;
  }

  setDifficulty(difficulty: 'beginner' | 'intermediate' | 'advanced'): AssessmentBuilder {
    this.assessment.metadata!.difficulty = difficulty;
    return this;
  }

  addTags(...tags: string[]): AssessmentBuilder {
    this.assessment.metadata!.tags.push(...tags);
    return this;
  }

  setCreator(creatorId: string): AssessmentBuilder {
    this.assessment.metadata!.createdBy = creatorId;
    return this;
  }

  build(): Assessment {
    // Validation
    if (!this.assessment.id || !this.assessment.title) {
      throw new Error('Assessment must have id and title');
    }
    
    if (!this.assessment.questions || this.assessment.questions.length === 0) {
      throw new Error('Assessment must have at least one question');
    }

    if (this.assessment.passingScore === undefined) {
      // Default passing score to 70% of total points
      const totalPoints = this.assessment.questions.reduce((sum, q) => sum + q.points, 0);
      this.assessment.passingScore = Math.ceil(totalPoints * 0.7);
    }

    return this.assessment as Assessment;
  }
}

// Usage in EdTech Platform
class PhilippineLicensureExamService {
  createNursingExamSample(): Assessment {
    return new AssessmentBuilder()
      .setId('nursing_2024_sample')
      .setTitle('Philippine Nursing Licensure Examination - Sample Test')
      .setSubject('Nursing')
      .setDifficulty('intermediate')
      .addTags('licensure', 'nursing', 'philippines', 'sample')
      .setCreator('system')
      .setTimeLimit(120) // 2 hours
      .setPassingScore(75)
      .enableQuestionRandomization()
      .disableRetakes()
      .addMultipleChoiceQuestion(
        'What is the normal range for adult heart rate?',
        ['40-60 bpm', '60-100 bpm', '100-120 bpm', '120-140 bpm'],
        1, // Index of correct answer
        2
      )
      .addMultipleChoiceQuestion(
        'Which vital sign indicates potential hypertension?',
        ['BP 120/80', 'BP 130/85', 'BP 140/90', 'BP 160/100'],
        3,
        2
      )
      .addEssayQuestion(
        'Describe the nursing care plan for a patient with diabetes mellitus.',
        10
      )
      .build();
  }

  createEngineeringExamModule(): Assessment {
    return new AssessmentBuilder()
      .setId('engineering_2024_module1')
      .setTitle('Philippine Engineering Licensure - Mathematics Module')
      .setSubject('Engineering Mathematics')
      .setDifficulty('advanced')
      .addTags('licensure', 'engineering', 'mathematics')
      .setCreator('admin_user')
      .setTimeLimit(180) // 3 hours
      .addMultipleChoiceQuestion(
        'What is the derivative of x² + 3x + 2?',
        ['2x + 3', 'x² + 3', '2x + 2', '3x + 2'],
        0,
        3
      )
      .build();
  }
}
```

### 3. Singleton Pattern (Modern Implementation)

**Module-based Singleton with TypeScript**

```typescript
// Configuration Singleton for EdTech Platform
class EdTechConfigManager {
  private static instance: EdTechConfigManager;
  private config: Map<string, any> = new Map();
  private initialized: boolean = false;

  private constructor() {}

  static getInstance(): EdTechConfigManager {
    if (!EdTechConfigManager.instance) {
      EdTechConfigManager.instance = new EdTechConfigManager();
    }
    return EdTechConfigManager.instance;
  }

  async initialize(): Promise<void> {
    if (this.initialized) return;

    // Load configuration from environment, database, or external service
    const defaultConfig = {
      database: {
        host: process.env.DB_HOST || 'localhost',
        port: parseInt(process.env.DB_PORT || '5432'),
        name: process.env.DB_NAME || 'edtech_db'
      },
      authentication: {
        jwtSecret: process.env.JWT_SECRET || 'default-secret',
        tokenExpiry: process.env.TOKEN_EXPIRY || '24h'
      },
      features: {
        allowGuestAccess: process.env.ALLOW_GUEST === 'true',
        maxAssessmentRetries: parseInt(process.env.MAX_RETRIES || '3'),
        enableAnalytics: process.env.ENABLE_ANALYTICS !== 'false'
      },
      philippines: {
        supportedLicenseTypes: ['nursing', 'engineering', 'teaching', 'accounting'],
        prcIntegration: process.env.PRC_API_ENABLED === 'true'
      }
    };

    for (const [key, value] of Object.entries(defaultConfig)) {
      this.config.set(key, value);
    }

    this.initialized = true;
  }

  get<T>(key: string): T | undefined {
    return this.config.get(key) as T;
  }

  set(key: string, value: any): void {
    this.config.set(key, value);
  }

  getDatabaseConfig(): any {
    return this.get('database');
  }

  getPhilippinesConfig(): any {
    return this.get('philippines');
  }

  isFeatureEnabled(feature: string): boolean {
    const features = this.get<any>('features') || {};
    return features[feature] === true;
  }
}

// Alternative: Module-based Singleton (Recommended for Modern JS)
class DatabaseConnectionPool {
  private connections: Map<string, any> = new Map();
  private maxConnections: number = 10;
  private currentConnections: number = 0;

  async getConnection(connectionString: string): Promise<any> {
    if (this.connections.has(connectionString)) {
      return this.connections.get(connectionString);
    }

    if (this.currentConnections >= this.maxConnections) {
      throw new Error('Maximum connections reached');
    }

    // Create new connection (mock implementation)
    const connection = {
      id: `conn_${Date.now()}`,
      connectionString,
      connected: false,
      connect: async () => { /* connection logic */ },
      disconnect: async () => { /* disconnection logic */ }
    };

    this.connections.set(connectionString, connection);
    this.currentConnections++;
    
    return connection;
  }

  async closeAllConnections(): Promise<void> {
    for (const [key, connection] of this.connections) {
      await connection.disconnect();
      this.connections.delete(key);
    }
    this.currentConnections = 0;
  }
}

// Export singleton instance
export const dbPool = new DatabaseConnectionPool();
export const configManager = EdTechConfigManager.getInstance();

// Usage in Application
class EdTechApplication {
  async bootstrap(): Promise<void> {
    await configManager.initialize();
    
    const dbConfig = configManager.getDatabaseConfig();
    const connection = await dbPool.getConnection(
      `postgresql://${dbConfig.host}:${dbConfig.port}/${dbConfig.name}`
    );

    console.log('Application bootstrapped with singleton configuration');
  }
}
```

## 🧩 Structural Patterns Implementation

### 4. Adapter Pattern

**Third-party Integration Adapter**

```typescript
// Target Interface (What our application expects)
interface PaymentProcessor {
  processPayment(amount: number, currency: string, cardToken: string): Promise<PaymentResult>;
  refundPayment(transactionId: string, amount?: number): Promise<RefundResult>;
  getTransactionStatus(transactionId: string): Promise<TransactionStatus>;
}

interface PaymentResult {
  success: boolean;
  transactionId: string;
  message: string;
  fees?: number;
}

interface RefundResult {
  success: boolean;
  refundId: string;
  amount: number;
  message: string;
}

interface TransactionStatus {
  id: string;
  status: 'pending' | 'completed' | 'failed' | 'refunded';
  amount: number;
  currency: string;
  createdAt: Date;
}

// Adaptees (Third-party payment services)
class StripePaymentService {
  async charge(amountInCents: number, source: string, currency: string) {
    // Stripe-specific implementation
    return {
      id: `ch_${Math.random().toString(36).substr(2, 9)}`,
      status: 'succeeded',
      amount: amountInCents,
      currency: currency.toLowerCase(),
      created: Math.floor(Date.now() / 1000)
    };
  }

  async refund(chargeId: string, amountInCents?: number) {
    return {
      id: `re_${Math.random().toString(36).substr(2, 9)}`,
      charge: chargeId,
      amount: amountInCents || 0,
      status: 'succeeded'
    };
  }

  async retrieve(chargeId: string) {
    return {
      id: chargeId,
      status: 'succeeded',
      amount: 5000, // $50.00
      currency: 'usd',
      created: Math.floor(Date.now() / 1000)
    };
  }
}

class PayPalPaymentService {
  async createPayment(payment: any) {
    return {
      id: `PAY-${Math.random().toString(36).substr(2, 9)}`,
      state: 'approved',
      transactions: [{
        amount: { total: payment.amount, currency: payment.currency }
      }],
      create_time: new Date().toISOString()
    };
  }

  async executePayment(paymentId: string, payerId: string) {
    return {
      id: paymentId,
      state: 'approved',
      payer: { payer_info: { payer_id: payerId } }
    };
  }

  async refundSale(saleId: string, refund: any) {
    return {
      id: `RF-${Math.random().toString(36).substr(2, 9)}`,
      sale_id: saleId,
      state: 'completed',
      amount: refund.amount
    };
  }
}

// Adapters
class StripeAdapter implements PaymentProcessor {
  constructor(private stripeService: StripePaymentService) {}

  async processPayment(amount: number, currency: string, cardToken: string): Promise<PaymentResult> {
    try {
      const amountInCents = Math.round(amount * 100);
      const charge = await this.stripeService.charge(amountInCents, cardToken, currency);
      
      return {
        success: charge.status === 'succeeded',
        transactionId: charge.id,
        message: charge.status === 'succeeded' ? 'Payment processed successfully' : 'Payment failed',
        fees: amountInCents * 0.029 + 30 // Stripe fees: 2.9% + 30¢
      };
    } catch (error) {
      return {
        success: false,
        transactionId: '',
        message: `Payment failed: ${error}`
      };
    }
  }

  async refundPayment(transactionId: string, amount?: number): Promise<RefundResult> {
    try {
      const amountInCents = amount ? Math.round(amount * 100) : undefined;
      const refund = await this.stripeService.refund(transactionId, amountInCents);
      
      return {
        success: refund.status === 'succeeded',
        refundId: refund.id,
        amount: refund.amount / 100,
        message: 'Refund processed successfully'
      };
    } catch (error) {
      return {
        success: false,
        refundId: '',
        amount: 0,
        message: `Refund failed: ${error}`
      };
    }
  }

  async getTransactionStatus(transactionId: string): Promise<TransactionStatus> {
    const charge = await this.stripeService.retrieve(transactionId);
    
    return {
      id: charge.id,
      status: this.mapStripeStatus(charge.status),
      amount: charge.amount / 100,
      currency: charge.currency.toUpperCase(),
      createdAt: new Date(charge.created * 1000)
    };
  }

  private mapStripeStatus(stripeStatus: string): TransactionStatus['status'] {
    switch (stripeStatus) {
      case 'succeeded': return 'completed';
      case 'pending': return 'pending';
      case 'failed': return 'failed';
      default: return 'pending';
    }
  }
}

class PayPalAdapter implements PaymentProcessor {
  constructor(private paypalService: PayPalPaymentService) {}

  async processPayment(amount: number, currency: string, cardToken: string): Promise<PaymentResult> {
    try {
      const payment = await this.paypalService.createPayment({
        amount: amount.toFixed(2),
        currency: currency.toUpperCase()
      });
      
      const execution = await this.paypalService.executePayment(payment.id, 'mock-payer-id');
      
      return {
        success: execution.state === 'approved',
        transactionId: execution.id,
        message: 'Payment processed via PayPal',
        fees: amount * 0.034 + 0.49 // PayPal fees: 3.4% + $0.49
      };
    } catch (error) {
      return {
        success: false,
        transactionId: '',
        message: `PayPal payment failed: ${error}`
      };
    }
  }

  async refundPayment(transactionId: string, amount?: number): Promise<RefundResult> {
    try {
      const refund = await this.paypalService.refundSale(transactionId, {
        amount: { total: amount?.toFixed(2) || '0.00', currency: 'USD' }
      });
      
      return {
        success: refund.state === 'completed',
        refundId: refund.id,
        amount: parseFloat(refund.amount.total),
        message: 'PayPal refund completed'
      };
    } catch (error) {
      return {
        success: false,
        refundId: '',
        amount: 0,
        message: `PayPal refund failed: ${error}`
      };
    }
  }

  async getTransactionStatus(transactionId: string): Promise<TransactionStatus> {
    // Mock implementation - in real scenario, would query PayPal API
    return {
      id: transactionId,
      status: 'completed',
      amount: 0,
      currency: 'USD',
      createdAt: new Date()
    };
  }
}

// Usage in EdTech Platform
class EdTechPaymentService {
  private processor: PaymentProcessor;

  constructor(provider: 'stripe' | 'paypal') {
    switch (provider) {
      case 'stripe':
        this.processor = new StripeAdapter(new StripePaymentService());
        break;
      case 'paypal':
        this.processor = new PayPalAdapter(new PayPalPaymentService());
        break;
      default:
        throw new Error(`Unsupported payment provider: ${provider}`);
    }
  }

  async processSubscriptionPayment(
    studentId: string, 
    planId: string, 
    amount: number, 
    cardToken: string
  ): Promise<PaymentResult> {
    console.log(`Processing subscription for student ${studentId}, plan ${planId}`);
    return await this.processor.processPayment(amount, 'USD', cardToken);
  }

  async processExamFee(
    examId: string, 
    studentId: string, 
    amount: number, 
    cardToken: string
  ): Promise<PaymentResult> {
    console.log(`Processing exam fee for ${examId}, student ${studentId}`);
    return await this.processor.processPayment(amount, 'PHP', cardToken);
  }

  async refundExamFee(transactionId: string, amount?: number): Promise<RefundResult> {
    return await this.processor.refundPayment(transactionId, amount);
  }
}
```

[Continue with more patterns...]

## 🔄 Behavioral Patterns Implementation

### 5. Observer Pattern

**Event-Driven Learning Progress Tracking**

```typescript
// Subject Interface
interface Subject<T> {
  attach(observer: Observer<T>): void;
  detach(observer: Observer<T>): void;
  notify(data: T): void;
}

// Observer Interface  
interface Observer<T> {
  update(data: T): void;
}

// Concrete Subject: Student Progress Tracker
class StudentProgressTracker implements Subject<ProgressUpdate> {
  private observers: Observer<ProgressUpdate>[] = [];
  private studentId: string;
  private currentProgress: StudentProgress;

  constructor(studentId: string) {
    this.studentId = studentId;
    this.currentProgress = {
      studentId,
      completedLessons: [],
      currentModule: '',
      overallProgress: 0,
      lastActivity: new Date()
    };
  }

  attach(observer: Observer<ProgressUpdate>): void {
    const isExist = this.observers.includes(observer);
    if (!isExist) {
      this.observers.push(observer);
      console.log(`Observer attached to student ${this.studentId}`);
    }
  }

  detach(observer: Observer<ProgressUpdate>): void {
    const observerIndex = this.observers.indexOf(observer);
    if (observerIndex !== -1) {
      this.observers.splice(observerIndex, 1);
      console.log(`Observer detached from student ${this.studentId}`);
    }
  }

  notify(data: ProgressUpdate): void {
    console.log(`Notifying ${this.observers.length} observers of progress update`);
    this.observers.forEach(observer => observer.update(data));
  }

  completeLesson(lessonId: string, score: number): void {
    this.currentProgress.completedLessons.push({
      lessonId,
      completedAt: new Date(),
      score
    });
    
    this.updateOverallProgress();
    
    const progressUpdate: ProgressUpdate = {
      studentId: this.studentId,
      type: 'lesson_completed',
      lessonId,
      score,
      overallProgress: this.currentProgress.overallProgress,
      timestamp: new Date()
    };

    this.notify(progressUpdate);
  }

  startModule(moduleId: string): void {
    this.currentProgress.currentModule = moduleId;
    this.currentProgress.lastActivity = new Date();

    const progressUpdate: ProgressUpdate = {
      studentId: this.studentId,
      type: 'module_started',
      moduleId,
      overallProgress: this.currentProgress.overallProgress,
      timestamp: new Date()
    };

    this.notify(progressUpdate);
  }

  private updateOverallProgress(): void {
    // Calculate progress based on completed lessons
    const totalLessons = 100; // This would come from course configuration
    const completedCount = this.currentProgress.completedLessons.length;
    this.currentProgress.overallProgress = (completedCount / totalLessons) * 100;
  }
}

// Concrete Observers
class ProgressAnalyticsObserver implements Observer<ProgressUpdate> {
  update(data: ProgressUpdate): void {
    console.log(`📊 Analytics: Recording progress for student ${data.studentId}`);
    
    // Send to analytics service
    this.recordAnalytics({
      event: data.type,
      studentId: data.studentId,
      progress: data.overallProgress,
      timestamp: data.timestamp,
      metadata: {
        lessonId: data.lessonId,
        moduleId: data.moduleId, 
        score: data.score
      }
    });
  }

  private recordAnalytics(event: any): void {
    // Mock analytics recording
    console.log('Analytics recorded:', JSON.stringify(event, null, 2));
  }
}

class BadgeAwardObserver implements Observer<ProgressUpdate> {
  update(data: ProgressUpdate): void {
    console.log(`🎖️ Badge System: Checking badges for student ${data.studentId}`);
    
    if (data.type === 'lesson_completed' && data.score && data.score >= 90) {
      this.awardBadge(data.studentId, 'high_achiever', 'Scored 90% or higher on a lesson');
    }
    
    if (data.type === 'module_started') {
      this.awardBadge(data.studentId, 'dedicated_learner', 'Started a new learning module');
    }

    if (data.overallProgress >= 50) {
      this.awardBadge(data.studentId, 'halfway_hero', '50% course completion');
    }
  }

  private awardBadge(studentId: string, badgeType: string, description: string): void {
    console.log(`🏆 Badge awarded to ${studentId}: ${badgeType} - ${description}`);
    // Badge awarding logic
  }
}

class NotificationObserver implements Observer<ProgressUpdate> {
  update(data: ProgressUpdate): void {
    console.log(`🔔 Notifications: Processing for student ${data.studentId}`);
    
    if (data.type === 'lesson_completed') {
      this.sendNotification(
        data.studentId, 
        `Great job! You completed a lesson with ${data.score}% score!`
      );
    }

    if (data.overallProgress >= 100) {
      this.sendNotification(
        data.studentId,
        '🎉 Congratulations! You have completed the entire course!'
      );
    }
  }

  private sendNotification(studentId: string, message: string): void {
    console.log(`📱 Notification sent to ${studentId}: ${message}`);
    // Push notification or email logic
  }
}

// Supporting interfaces
interface StudentProgress {
  studentId: string;
  completedLessons: CompletedLesson[];
  currentModule: string;
  overallProgress: number;
  lastActivity: Date;
}

interface CompletedLesson {
  lessonId: string;
  completedAt: Date;
  score: number;
}

interface ProgressUpdate {
  studentId: string;
  type: 'lesson_completed' | 'module_started' | 'course_completed';
  lessonId?: string;
  moduleId?: string;
  score?: number;
  overallProgress: number;
  timestamp: Date;
}

// Usage in EdTech Platform
class EdTechLearningPlatform {
  private progressTrackers: Map<string, StudentProgressTracker> = new Map();
  private analyticsObserver = new ProgressAnalyticsObserver();
  private badgeObserver = new BadgeAwardObserver();
  private notificationObserver = new NotificationObserver();

  enrollStudent(studentId: string): void {
    const tracker = new StudentProgressTracker(studentId);
    
    // Attach observers
    tracker.attach(this.analyticsObserver);
    tracker.attach(this.badgeObserver);
    tracker.attach(this.notificationObserver);
    
    this.progressTrackers.set(studentId, tracker);
    console.log(`Student ${studentId} enrolled with progress tracking`);
  }

  recordLessonCompletion(studentId: string, lessonId: string, score: number): void {
    const tracker = this.progressTrackers.get(studentId);
    if (tracker) {
      tracker.completeLesson(lessonId, score);
    }
  }

  startNewModule(studentId: string, moduleId: string): void {
    const tracker = this.progressTrackers.get(studentId);
    if (tracker) {
      tracker.startModule(moduleId);
    }
  }
}
```

## 🧪 Testing Your Pattern Implementations

### Unit Testing Setup

```typescript
// test/patterns/factory.test.ts
import { AssessmentBuilder } from '../../src/patterns/builder';
import { EdTechDatabaseService } from '../../src/patterns/factory';

describe('Factory Method Pattern', () => {
  test('should create PostgreSQL connection factory', async () => {
    const service = new EdTechDatabaseService('postgresql');
    const result = await service.getStudentProgress('student_123');
    
    expect(result).toBeDefined();
    // Additional assertions
  });

  test('should create MongoDB connection factory', async () => {
    const service = new EdTechDatabaseService('mongodb');
    const result = await service.getStudentProgress('student_123');
    
    expect(result).toBeDefined();
  });
});

describe('Builder Pattern', () => {
  test('should build complete assessment', () => {
    const assessment = new AssessmentBuilder()
      .setId('test_assessment')
      .setTitle('Test Assessment')
      .addMultipleChoiceQuestion('Test question', ['A', 'B', 'C'], 0, 1)
      .setPassingScore(70)
      .build();

    expect(assessment.id).toBe('test_assessment');
    expect(assessment.questions).toHaveLength(1);
    expect(assessment.passingScore).toBe(70);
  });
});

describe('Observer Pattern', () => {
  test('should notify observers of progress updates', () => {
    const tracker = new StudentProgressTracker('student_123');
    const mockObserver = {
      update: jest.fn()
    };

    tracker.attach(mockObserver);
    tracker.completeLesson('lesson_1', 95);

    expect(mockObserver.update).toHaveBeenCalledWith(
      expect.objectContaining({
        studentId: 'student_123',
        type: 'lesson_completed',
        score: 95
      })
    );
  });
});
```

## 🚀 Next Steps

1. **Continue to [Best Practices](./best-practices.md)** - Learn optimization techniques and common pitfalls
2. **Review [Pattern Catalog](./pattern-catalog.md)** - Complete reference of all 23 patterns
3. **Study [Real-World Examples](./real-world-examples.md)** - EdTech platform implementations

---

[🏠 Back to Overview](./README.md) | [📋 Best Practices →](./best-practices.md) | [📚 Pattern Catalog →](./pattern-catalog.md)