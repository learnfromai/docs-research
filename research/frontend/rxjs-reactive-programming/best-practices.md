# Best Practices: RxJS Reactive Programming

Comprehensive best practices for implementing reactive programming with RxJS, focusing on maintainable, performant, and scalable code patterns for educational technology platforms and team development.

## Code Organization & Architecture

### 1. Service Layer Architecture

```typescript
// ✅ GOOD: Well-structured service with clear separation of concerns
@Injectable({
  providedIn: 'root'
})
export class UserProgressService {
  // Private subjects for internal state management
  private progressSubject = new BehaviorSubject<UserProgress>(this.getInitialProgress());
  private syncingSubject = new BehaviorSubject<boolean>(false);
  
  // Public observables (read-only)
  public readonly progress$ = this.progressSubject.asObservable();
  public readonly isSyncing$ = this.syncingSubject.asObservable();
  
  // Computed observables
  public readonly completionPercentage$ = this.progress$.pipe(
    map(progress => this.calculateCompletionPercentage(progress)),
    distinctUntilChanged()
  );
  
  constructor(private apiService: ApiService) {
    this.setupAutoSync();
  }
  
  // Public methods with clear return types
  updateProgress(lessonId: string): Observable<UserProgress> {
    return this.performProgressUpdate(lessonId).pipe(
      tap(progress => this.progressSubject.next(progress)),
      catchError(error => this.handleError(error))
    );
  }
  
  private setupAutoSync(): void {
    // Auto-save every 30 seconds if there are changes
    this.progress$.pipe(
      debounceTime(30000),
      distinctUntilChanged(),
      switchMap(progress => this.syncProgress(progress))
    ).subscribe();
  }
  
  private getInitialProgress(): UserProgress {
    // Initialize with default values
    return {
      completedLessons: [],
      currentStreak: 0,
      totalTimeSpent: 0,
      lastActivity: new Date()
    };
  }
}
```

### 2. Naming Conventions

```typescript
// ✅ GOOD: Clear naming conventions
class QuizService {
  // Subjects (internal state) - use 'Subject' suffix
  private questionsSubject = new BehaviorSubject<Question[]>([]);
  private loadingSubject = new BehaviorSubject<boolean>(false);
  
  // Observables (external API) - use '$' suffix
  public readonly questions$ = this.questionsSubject.asObservable();
  public readonly loading$ = this.loadingSubject.asObservable();
  public readonly isReady$ = this.questions$.pipe(map(q => q.length > 0));
  
  // Methods that return observables - use descriptive names
  loadQuestions(courseId: string): Observable<Question[]> { /* ... */ }
  submitAnswer(answer: Answer): Observable<SubmissionResult> { /* ... */ }
  getNextQuestion(): Observable<Question | null> { /* ... */ }
}

// ❌ BAD: Unclear naming
class BadQuizService {
  private qs = new BehaviorSubject([]);  // Unclear abbreviation
  public questions = this.qs.asObservable();  // Missing $ suffix
  
  load(id) { /* ... */ }  // Unclear method name and parameter
  next() { /* ... */ }    // Too generic
}
```

### 3. File Organization

```
src/
├── services/
│   ├── core/
│   │   ├── api.service.ts           # HTTP client wrapper
│   │   ├── websocket.service.ts     # WebSocket management
│   │   └── error-handler.service.ts # Centralized error handling
│   ├── domain/
│   │   ├── user.service.ts          # User-related operations
│   │   ├── course.service.ts        # Course management
│   │   └── quiz.service.ts          # Quiz functionality
│   └── utils/
│       ├── rx-operators.ts          # Custom operators
│       └── rx-utils.ts             # Utility functions
├── models/
│   ├── user.model.ts
│   ├── course.model.ts
│   └── quiz.model.ts
└── operators/
    ├── custom-operators.ts
    └── debug-operators.ts
```

## Observable Creation Patterns

### 1. Factory Functions for Complex Observables

```typescript
// ✅ GOOD: Factory function for reusable observable creation
function createApiCall<T>(url: string, options: RequestOptions = {}): Observable<T> {
  return from(fetch(url, options)).pipe(
    switchMap(response => {
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }
      return response.json();
    }),
    retry(3),
    timeout(10000),
    catchError(error => {
      console.error(`API call failed for ${url}:`, error);
      return throwError(() => error);
    })
  );
}

// Usage
const users$ = createApiCall<User[]>('/api/users');
const courses$ = createApiCall<Course[]>('/api/courses');
```

### 2. Subject Usage Guidelines

```typescript
// ✅ GOOD: Appropriate subject selection
class StateService {
  // BehaviorSubject for state that always has a current value
  private userSubject = new BehaviorSubject<User | null>(null);
  
  // Subject for events/actions
  private actionSubject = new Subject<UserAction>();
  
  // ReplaySubject for historical data (limited buffer)
  private auditLogSubject = new ReplaySubject<AuditEvent>(50);
  
  // Expose as read-only observables
  public readonly user$ = this.userSubject.asObservable();
  public readonly actions$ = this.actionSubject.asObservable();
  public readonly auditLog$ = this.auditLogSubject.asObservable();
}

// ❌ BAD: Wrong subject type selection
class BadStateService {
  // Wrong: Using Subject for state (no initial value)
  private userSubject = new Subject<User>();
  
  // Wrong: Using BehaviorSubject for events (unnecessary memory)
  private eventSubject = new BehaviorSubject<Event>(null);
  
  // Wrong: Using ReplaySubject without buffer limit (memory leak)
  private logSubject = new ReplaySubject<LogEntry>();
}
```

## Operator Usage Best Practices

### 1. Transformation Operator Selection

```typescript
// ✅ GOOD: Correct operator selection based on use case
class SearchService {
  // switchMap: Cancel previous requests for search
  search(term: string): Observable<SearchResult[]> {
    return of(term).pipe(
      debounceTime(300),
      distinctUntilChanged(),
      switchMap(searchTerm => 
        this.apiService.search(searchTerm)
      )
    );
  }
  
  // concatMap: Sequential processing (order matters)
  processQueue(tasks: Task[]): Observable<TaskResult> {
    return from(tasks).pipe(
      concatMap(task => this.processTask(task))
    );
  }
  
  // mergeMap: Parallel processing (order doesn't matter)
  loadUserProfiles(userIds: string[]): Observable<UserProfile> {
    return from(userIds).pipe(
      mergeMap(id => this.loadProfile(id), 5) // Limit concurrency to 5
    );
  }
  
  // exhaustMap: Ignore new emissions while current is processing
  saveData(data: any): Observable<SaveResult> {
    return this.saveButton$.pipe(
      exhaustMap(() => this.apiService.save(data))
    );
  }
}
```

### 2. Error Handling Strategies

```typescript
// ✅ GOOD: Comprehensive error handling strategy
class ResilientApiService {
  private readonly retryConfig = {
    maxRetries: 3,
    baseDelay: 1000,
    maxDelay: 10000
  };
  
  getData<T>(url: string): Observable<T> {
    return this.http.get<T>(url).pipe(
      // Retry with exponential backoff
      retryWhen(errors => errors.pipe(
        scan((retryCount, error) => {
          if (retryCount >= this.retryConfig.maxRetries) {
            throw error;
          }
          console.log(`Retry attempt ${retryCount + 1} for ${url}`);
          return retryCount + 1;
        }, 0),
        delayWhen(retryCount => {
          const delay = Math.min(
            this.retryConfig.baseDelay * Math.pow(2, retryCount),
            this.retryConfig.maxDelay
          );
          return timer(delay);
        })
      )),
      
      // Global error handling
      catchError(error => {
        this.errorLogger.logError(error, { url, timestamp: new Date() });
        
        // Return fallback data or re-throw based on context
        if (this.hasCachedData(url)) {
          return this.getCachedData<T>(url);
        }
        
        return throwError(() => new ApiError(error.message, error.status));
      })
    );
  }
}
```

### 3. Memory Management

```typescript
// ✅ GOOD: Proper subscription management
class ComponentBase implements OnDestroy {
  protected destroy$ = new Subject<void>();
  
  protected addSubscription<T>(observable: Observable<T>): Observable<T> {
    return observable.pipe(takeUntil(this.destroy$));
  }
  
  ngOnDestroy(): void {
    this.destroy$.next();
    this.destroy$.complete();
  }
}

class QuizComponent extends ComponentBase implements OnInit {
  quiz$ = this.quizService.getCurrentQuiz();
  timeRemaining$ = this.timerService.timeRemaining$;
  
  ngOnInit(): void {
    // Automatic cleanup with base class
    this.addSubscription(
      combineLatest([this.quiz$, this.timeRemaining$])
    ).subscribe(([quiz, time]) => {
      this.handleQuizUpdate(quiz, time);
    });
    
    // Multiple subscriptions with shared cleanup
    this.addSubscription(
      merge(
        this.quiz$.pipe(map(quiz => ({ type: 'quiz', data: quiz }))),
        this.timeRemaining$.pipe(map(time => ({ type: 'timer', data: time })))
      )
    ).subscribe(event => {
      this.handleEvent(event);
    });
  }
}
```

## Performance Optimization

### 1. Sharing Expensive Operations

```typescript
// ✅ GOOD: Share expensive operations
class DataService {
  private userCache$ = this.loadUsers().pipe(
    shareReplay(1), // Cache the result
    refCount()      // Unsubscribe when no subscribers
  );
  
  private configCache$ = this.loadConfig().pipe(
    shareReplay({ bufferSize: 1, refCount: true })
  );
  
  // Multiple components can subscribe without triggering multiple API calls
  getUsers(): Observable<User[]> {
    return this.userCache$;
  }
  
  getConfig(): Observable<Config> {
    return this.configCache$;
  }
  
  private loadUsers(): Observable<User[]> {
    return this.http.get<User[]>('/api/users').pipe(
      tap(() => console.log('Loading users from API'))
    );
  }
}

// ❌ BAD: Creating new observables for each call
class BadDataService {
  getUsers(): Observable<User[]> {
    // New HTTP request for each subscription
    return this.http.get<User[]>('/api/users');
  }
}
```

### 2. Optimizing Hot Observables

```typescript
// ✅ GOOD: Efficient WebSocket management
class WebSocketService {
  private socket$: Observable<MessageEvent>;
  private connectionSubject = new BehaviorSubject<boolean>(false);
  
  constructor() {
    this.socket$ = new Observable(observer => {
      const socket = new WebSocket('wss://api.example.com');
      
      socket.onmessage = event => observer.next(event);
      socket.onerror = error => observer.error(error);
      socket.onclose = () => observer.complete();
      
      socket.onopen = () => this.connectionSubject.next(true);
      socket.onclose = () => this.connectionSubject.next(false);
      
      return () => socket.close();
    }).pipe(
      share(), // Share the WebSocket connection
      retry(3) // Reconnect on failure
    );
  }
  
  // Filter messages by type efficiently
  getMessages<T>(messageType: string): Observable<T> {
    return this.socket$.pipe(
      map(event => JSON.parse(event.data)),
      filter(message => message.type === messageType),
      map(message => message.data),
      share() // Share the filtered stream
    );
  }
  
  // Connection status
  get isConnected$(): Observable<boolean> {
    return this.connectionSubject.asObservable();
  }
}
```

### 3. Backpressure Handling

```typescript
// ✅ GOOD: Handle high-frequency events
class EventProcessingService {
  processHighFrequencyEvents(events$: Observable<Event>): Observable<ProcessedEvent> {
    return events$.pipe(
      // Buffer events to process in batches
      bufferTime(1000, null, 100), // Every 1 second or 100 events
      filter(events => events.length > 0),
      
      // Process batches concurrently but limit concurrency
      mergeMap(eventBatch => 
        this.processBatch(eventBatch), 
        3 // Max 3 concurrent batch processes
      ),
      
      // Flatten results
      mergeMap(results => from(results))
    );
  }
  
  // Debounce user input
  processUserInput(input$: Observable<string>): Observable<SearchResult[]> {
    return input$.pipe(
      debounceTime(300),           // Wait for pause in typing
      distinctUntilChanged(),      // Only if value changed
      filter(term => term.length >= 2), // Minimum search length
      switchMap(term => this.search(term)) // Cancel previous searches
    );
  }
}
```

## Testing Best Practices

### 1. Marble Testing Patterns

```typescript
// ✅ GOOD: Comprehensive marble testing
describe('UserProgressService', () => {
  let service: UserProgressService;
  let testScheduler: TestScheduler;
  
  beforeEach(() => {
    testScheduler = new TestScheduler((actual, expected) => {
      expect(actual).toEqual(expected);
    });
  });
  
  it('should debounce progress updates', () => {
    testScheduler.run(({ cold, hot, expectObservable, flush }) => {
      // Arrange
      const progressUpdates = hot('a-b-c-d-|', {
        a: { lessonId: '1' },
        b: { lessonId: '2' },
        c: { lessonId: '3' },
        d: { lessonId: '4' }
      });
      
      // Act
      const result$ = progressUpdates.pipe(
        debounceTime(500, testScheduler),
        map(update => update.lessonId)
      );
      
      // Assert
      expectObservable(result$).toBe('-------d|', { d: '4' });
    });
  });
  
  it('should handle retry logic correctly', () => {
    testScheduler.run(({ cold, expectObservable }) => {
      const error = new Error('Network error');
      const source$ = cold('#', null, error);
      
      const result$ = source$.pipe(
        retry(2),
        catchError(() => of('fallback'))
      );
      
      expectObservable(result$).toBe('(f|)', { f: 'fallback' });
    });
  });
});
```

### 2. Integration Testing

```typescript
// ✅ GOOD: Integration testing with real observables
describe('QuizService Integration', () => {
  let service: QuizService;
  let httpMock: HttpTestingController;
  
  beforeEach(() => {
    TestBed.configureTestingModule({
      imports: [HttpClientTestingModule],
      providers: [QuizService]
    });
    
    service = TestBed.inject(QuizService);
    httpMock = TestBed.inject(HttpTestingController);
  });
  
  it('should handle complete quiz flow', fakeAsync(() => {
    // Arrange
    const mockQuiz = { id: '1', questions: [/* ... */] };
    const mockAnswers = [{ questionId: '1', answer: 'A' }];
    
    let quizResult: QuizResult | undefined;
    
    // Act
    service.startQuiz('quiz-1').pipe(
      switchMap(quiz => service.submitAnswers(quiz.id, mockAnswers)),
      tap(result => quizResult = result)
    ).subscribe();
    
    // Verify HTTP calls
    const quizRequest = httpMock.expectOne('/api/quiz/quiz-1');
    quizRequest.flush(mockQuiz);
    
    tick(100); // Allow observables to process
    
    const submitRequest = httpMock.expectOne('/api/quiz/quiz-1/submit');
    submitRequest.flush({ score: 85, passed: true });
    
    tick(100);
    
    // Assert
    expect(quizResult).toEqual({ score: 85, passed: true });
    httpMock.verify();
  }));
});
```

## Error Handling & Resilience

### 1. Hierarchical Error Handling

```typescript
// ✅ GOOD: Multi-level error handling
class ApiService {
  // Application-level error handler
  private handleApplicationError = (error: any): Observable<never> => {
    // Log to monitoring service
    this.monitoring.logError(error);
    
    // Show user-friendly message
    this.notification.showError('An unexpected error occurred. Please try again.');
    
    return EMPTY; // Complete the stream
  };
  
  // Network-level error handler
  private handleNetworkError = (error: HttpErrorResponse): Observable<any> => {
    if (error.status === 0) {
      // Network connectivity issue
      this.notification.showError('Please check your internet connection.');
      return this.retryWithDelay(3, 2000);
    }
    
    if (error.status >= 500) {
      // Server error - retry
      return this.retryWithDelay(2, 1000);
    }
    
    // Client error - don't retry
    throw error;
  };
  
  // Business-level error handler
  private handleBusinessError = (error: any): Observable<any> => {
    if (error.code === 'QUOTA_EXCEEDED') {
      this.notification.showWarning('Daily limit reached. Please try again tomorrow.');
      return of({ error: 'quota_exceeded', retryAfter: error.retryAfter });
    }
    
    throw error;
  };
  
  getData<T>(url: string): Observable<T> {
    return this.http.get<T>(url).pipe(
      catchError(this.handleNetworkError),
      catchError(this.handleBusinessError),
      catchError(this.handleApplicationError)
    );
  }
  
  private retryWithDelay(times: number, delay: number): Observable<any> {
    return throwError('retry').pipe(
      retryWhen(errors => errors.pipe(
        take(times),
        delayWhen(() => timer(delay))
      ))
    );
  }
}
```

### 2. Circuit Breaker Pattern

```typescript
// ✅ GOOD: Circuit breaker for resilient API calls
class CircuitBreakerService {
  private failureCount = 0;
  private lastFailureTime = 0;
  private state: 'CLOSED' | 'OPEN' | 'HALF_OPEN' = 'CLOSED';
  
  private readonly config = {
    failureThreshold: 5,
    recoveryTimeout: 30000, // 30 seconds
    monitoringPeriod: 60000  // 1 minute
  };
  
  execute<T>(operation: () => Observable<T>): Observable<T> {
    return defer(() => {
      if (this.state === 'OPEN') {
        if (Date.now() - this.lastFailureTime > this.config.recoveryTimeout) {
          this.state = 'HALF_OPEN';
        } else {
          return throwError(() => new Error('Circuit breaker is OPEN'));
        }
      }
      
      return operation().pipe(
        tap(() => this.onSuccess()),
        catchError(error => {
          this.onFailure();
          return throwError(() => error);
        })
      );
    });
  }
  
  private onSuccess(): void {
    this.failureCount = 0;
    this.state = 'CLOSED';
  }
  
  private onFailure(): void {
    this.failureCount++;
    this.lastFailureTime = Date.now();
    
    if (this.failureCount >= this.config.failureThreshold) {
      this.state = 'OPEN';
    }
  }
}
```

## Development & Debugging

### 1. Debug Operators

```typescript
// ✅ GOOD: Custom debug operators
function debug<T>(tag: string) {
  return tap<T>({
    next: value => console.log(`[${tag}] Next:`, value),
    error: error => console.error(`[${tag}] Error:`, error),
    complete: () => console.log(`[${tag}] Complete`)
  });
}

function logTime<T>(tag: string) {
  return tap<T>({
    next: () => console.time(tag),
    complete: () => console.timeEnd(tag),
    error: () => console.timeEnd(tag)
  });
}

// Usage in development
const data$ = this.apiService.getData().pipe(
  debug('API Response'),
  logTime('Data Processing'),
  map(data => this.processData(data)),
  debug('Processed Data')
);
```

### 2. Environment-Specific Behavior

```typescript
// ✅ GOOD: Environment-specific operators
function devOnly<T>() {
  return (source: Observable<T>) => {
    if (!environment.production) {
      return source.pipe(debug('DEV'));
    }
    return source;
  };
}

function prodOptimized<T>() {
  return (source: Observable<T>) => {
    if (environment.production) {
      return source.pipe(
        shareReplay(1),
        catchError(error => {
          // Production error handling
          this.errorReporter.report(error);
          return EMPTY;
        })
      );
    }
    return source;
  };
}
```

## Team Development Guidelines

### 1. Code Review Checklist

**Observable Creation:**
- [ ] Using appropriate observable creation method
- [ ] Hot vs cold observables correctly identified
- [ ] Subject types appropriately selected

**Operators:**
- [ ] Correct transformation operators (switchMap vs mergeMap vs concatMap)
- [ ] Proper error handling with catchError
- [ ] Memory leaks prevented with takeUntil or unsubscribe

**Performance:**
- [ ] Expensive operations shared with shareReplay
- [ ] Appropriate debouncing/throttling for user input
- [ ] Subscription management properly implemented

**Testing:**
- [ ] Marble tests for complex observable chains
- [ ] Integration tests for service interactions
- [ ] Error scenarios covered

### 2. Documentation Standards

```typescript
/**
 * Manages user progress tracking with real-time updates and offline support.
 * 
 * @example
 * ```typescript
 * const progressService = new UserProgressService();
 * 
 * // Subscribe to progress updates
 * progressService.progress$.subscribe(progress => {
 *   console.log('Current progress:', progress);
 * });
 * 
 * // Update progress
 * progressService.completeLesson('lesson-123').subscribe();
 * ```
 */
export class UserProgressService {
  /**
   * Observable stream of user progress updates.
   * Emits whenever progress is updated locally or synced from server.
   */
  public readonly progress$: Observable<UserProgress>;
  
  /**
   * Marks a lesson as completed and updates user progress.
   * 
   * @param lessonId - Unique identifier for the lesson
   * @returns Observable that emits the updated progress
   * @throws {ProgressUpdateError} When the lesson cannot be marked as completed
   */
  completeLesson(lessonId: string): Observable<UserProgress> {
    // Implementation...
  }
}
```

### 3. Migration Strategies

```typescript
// ✅ GOOD: Gradual migration from callbacks/promises
class MigrationService {
  // Step 1: Wrap existing callback-based code
  private legacyApiCall(callback: (error: any, data: any) => void): void {
    // Existing callback-based implementation
  }
  
  private wrappedLegacyCall(): Observable<any> {
    return new Observable(observer => {
      this.legacyApiCall((error, data) => {
        if (error) {
          observer.error(error);
        } else {
          observer.next(data);
          observer.complete();
        }
      });
    });
  }
  
  // Step 2: Create RxJS-based methods alongside existing ones
  getData(): Observable<any> {
    return this.wrappedLegacyCall().pipe(
      map(data => this.transformData(data)),
      catchError(error => this.handleError(error))
    );
  }
  
  // Step 3: Gradually replace usage throughout the application
  // Step 4: Remove legacy methods once migration is complete
}
```

## Common Anti-Patterns to Avoid

### 1. Observable Creation Anti-Patterns

```typescript
// ❌ BAD: Creating observables in getters
class BadService {
  get data$(): Observable<any> {
    return this.http.get('/api/data'); // New observable every time!
  }
}

// ✅ GOOD: Create observable once
class GoodService {
  private data$ = this.http.get('/api/data').pipe(shareReplay(1));
  
  getData(): Observable<any> {
    return this.data$;
  }
}

// ❌ BAD: Nested subscriptions
badMethod() {
  this.service1.getData().subscribe(data1 => {
    this.service2.getData(data1.id).subscribe(data2 => {
      // Nested subscription hell
    });
  });
}

// ✅ GOOD: Flat subscription with operators
goodMethod() {
  this.service1.getData().pipe(
    switchMap(data1 => this.service2.getData(data1.id))
  ).subscribe(data2 => {
    // Clean, flat structure
  });
}
```

### 2. Error Handling Anti-Patterns

```typescript
// ❌ BAD: Swallowing errors silently
badErrorHandling() {
  return this.apiCall().pipe(
    catchError(() => of(null)) // Error information lost!
  );
}

// ✅ GOOD: Proper error handling
goodErrorHandling() {
  return this.apiCall().pipe(
    catchError(error => {
      this.logger.error('API call failed:', error);
      this.notificationService.showError('Data could not be loaded');
      return of(this.getDefaultData());
    })
  );
}
```

### 3. Memory Management Anti-Patterns

```typescript
// ❌ BAD: Not unsubscribing
class BadComponent {
  ngOnInit() {
    this.dataService.getData().subscribe(data => {
      // Subscription never cleaned up - memory leak!
    });
  }
}

// ✅ GOOD: Proper cleanup
class GoodComponent implements OnDestroy {
  private destroy$ = new Subject<void>();
  
  ngOnInit() {
    this.dataService.getData().pipe(
      takeUntil(this.destroy$)
    ).subscribe(data => {
      // Automatically cleaned up
    });
  }
  
  ngOnDestroy() {
    this.destroy$.next();
    this.destroy$.complete();
  }
}
```

---

## Navigation

- ← Previous: [Implementation Guide](implementation-guide.md)
- → Next: [Comparison Analysis](comparison-analysis.md)
- ↑ Back to: [RxJS Research Overview](README.md)

---

*These best practices are compiled from production experience with RxJS in educational technology platforms and enterprise applications.*