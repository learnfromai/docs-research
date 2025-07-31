# Observable Patterns Deep Dive

Comprehensive exploration of observable creation patterns, hot/cold observables, subjects, and advanced reactive patterns for building robust educational technology applications.

## Observable Creation Patterns

### 1. Basic Observable Creation

#### From Scratch Observable
```typescript
// Creating custom observables for specific use cases
function createProgressTracker(): Observable<ProgressEvent> {
  return new Observable<ProgressEvent>(observer => {
    let progress = 0;
    const startTime = Date.now();
    
    const interval = setInterval(() => {
      progress += Math.random() * 10;
      
      if (progress >= 100) {
        observer.next({
          progress: 100,
          completed: true,
          duration: Date.now() - startTime
        });
        observer.complete();
        clearInterval(interval);
      } else {
        observer.next({
          progress: Math.floor(progress),
          completed: false,
          duration: Date.now() - startTime
        });
      }
    }, 100);
    
    // Cleanup function
    return () => {
      clearInterval(interval);
      console.log('Progress tracker cleanup');
    };
  });
}
```

#### Factory Functions for Reusable Patterns
```typescript
// Quiz timer factory
function createQuizTimer(durationMs: number): Observable<TimerEvent> {
  return new Observable<TimerEvent>(observer => {
    const startTime = Date.now();
    const endTime = startTime + durationMs;
    
    const tick = () => {
      const now = Date.now();
      const remaining = Math.max(0, endTime - now);
      const elapsed = now - startTime;
      const progress = (elapsed / durationMs) * 100;
      
      if (remaining <= 0) {
        observer.next({
          timeRemaining: 0,
          progress: 100,
          finished: true
        });
        observer.complete();
      } else {
        observer.next({
          timeRemaining: remaining,
          progress: Math.min(progress, 100),
          finished: false
        });
        requestAnimationFrame(tick);
      }
    };
    
    requestAnimationFrame(tick);
    
    return () => {
      console.log('Quiz timer stopped');
    };
  });
}

// Usage
const quizTimer$ = createQuizTimer(60000); // 1 minute quiz
quizTimer$.subscribe({
  next: event => updateTimerDisplay(event),
  complete: () => handleQuizTimeout()
});
```

### 2. Advanced Creation Operators

#### Custom fromCallback Operator
```typescript
// Convert Node.js-style callbacks to observables
function fromCallback<T>(
  callbackFunc: (callback: (error: any, result: T) => void) => void
): Observable<T> {
  return new Observable<T>(observer => {
    callbackFunc((error, result) => {
      if (error) {
        observer.error(error);
      } else {
        observer.next(result);
        observer.complete();
      }
    });
  });
}

// Convert file reading to observable
const readFile$ = fromCallback<string>(callback => {
  fs.readFile('quiz-data.json', 'utf8', callback);
});
```

#### Smart HTTP Observable
```typescript
function createSmartHttpCall<T>(
  url: string,
  options: RequestInit = {}
): Observable<T> {
  return new Observable<T>(observer => {
    const controller = new AbortController();
    const signal = controller.signal;
    
    fetch(url, { ...options, signal })
      .then(async response => {
        if (!response.ok) {
          throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }
        
        const contentType = response.headers.get('content-type');
        let data: T;
        
        if (contentType?.includes('application/json')) {
          data = await response.json();
        } else if (contentType?.includes('text/')) {
          data = await response.text() as unknown as T;
        } else {
          data = await response.blob() as unknown as T;
        }
        
        observer.next(data);
        observer.complete();
      })
      .catch(error => {
        if (error.name !== 'AbortError') {
          observer.error(error);
        }
      });
    
    // Return cleanup function
    return () => {
      controller.abort();
    };
  });
}
```

## Hot vs Cold Observables

### Cold Observable Patterns

#### Data Fetching Pattern
```typescript
// Cold observable - new execution for each subscriber
class QuizDataService {
  getQuizQuestions(quizId: string): Observable<Question[]> {
    return createSmartHttpCall<Question[]>(`/api/quiz/${quizId}/questions`).pipe(
      tap(() => console.log('Fetching questions for quiz:', quizId)),
      map(questions => questions.map(q => this.processQuestion(q)))
    );
  }
  
  // Each component that subscribes gets its own HTTP request
  // Component A: HTTP request triggered
  // Component B: Another HTTP request triggered
}
```

#### Making Cold Observables Hot
```typescript
class OptimizedQuizDataService {
  private questionsCache = new Map<string, Observable<Question[]>>();
  
  getQuizQuestions(quizId: string): Observable<Question[]> {
    if (!this.questionsCache.has(quizId)) {
      const questions$ = createSmartHttpCall<Question[]>(`/api/quiz/${quizId}/questions`).pipe(
        map(questions => questions.map(q => this.processQuestion(q))),
        shareReplay({
          bufferSize: 1,
          refCount: true // Unsubscribe when no more subscribers
        })
      );
      
      this.questionsCache.set(quizId, questions$);
    }
    
    return this.questionsCache.get(quizId)!;
  }
  
  // Now multiple subscribers share the same HTTP request
}
```

### Hot Observable Patterns

#### WebSocket Integration
```typescript
class LiveQuizService {
  private socket$: Observable<MessageEvent>;
  private connectionSubject = new BehaviorSubject<boolean>(false);
  
  constructor(private quizId: string) {
    this.socket$ = this.createWebSocketObservable();
  }
  
  private createWebSocketObservable(): Observable<MessageEvent> {
    return new Observable<MessageEvent>(observer => {
      const socket = new WebSocket(`wss://quiz.example.com/${this.quizId}`);
      
      socket.onopen = () => {
        console.log('WebSocket connected');
        this.connectionSubject.next(true);
      };
      
      socket.onmessage = event => observer.next(event);
      socket.onerror = error => observer.error(error);
      
      socket.onclose = () => {
        console.log('WebSocket disconnected');
        this.connectionSubject.next(false);
        observer.complete();
      };
      
      return () => {
        socket.close();
      };
    }).pipe(
      retry({
        delay: (error, retryCount) => {
          console.log(`WebSocket retry attempt ${retryCount}`);
          return timer(Math.min(1000 * Math.pow(2, retryCount), 30000));
        }
      }),
      share() // Make it hot - share the WebSocket connection
    );
  }
  
  // Get filtered message streams
  getAnswerSubmissions(): Observable<AnswerSubmission> {
    return this.socket$.pipe(
      map(event => JSON.parse(event.data)),
      filter(message => message.type === 'ANSWER_SUBMISSION'),
      map(message => message.data)
    );
  }
  
  getScoreUpdates(): Observable<ScoreUpdate> {
    return this.socket$.pipe(
      map(event => JSON.parse(event.data)),
      filter(message => message.type === 'SCORE_UPDATE'),
      map(message => message.data)
    );
  }
}
```

#### DOM Event Streams
```typescript
class UserInteractionService {
  // Hot observables from DOM events
  private clickStream$ = fromEvent(document, 'click').pipe(
    share() // Share the event listener
  );
  
  private keyboardStream$ = fromEvent(document, 'keydown').pipe(
    share()
  );
  
  private mouseStream$ = fromEvent(document, 'mousemove').pipe(
    throttleTime(16), // 60 FPS
    share()
  );
  
  // Derived streams
  getButtonClicks(selector: string): Observable<MouseEvent> {
    return this.clickStream$.pipe(
      filter(event => (event.target as Element).matches(selector)),
      map(event => event as MouseEvent)
    );
  }
  
  getKeyboardShortcuts(): Observable<KeyboardShortcut> {
    return this.keyboardStream$.pipe(
      filter(event => event.ctrlKey || event.metaKey),
      map(event => ({
        key: event.key,
        ctrlKey: event.ctrlKey,
        metaKey: event.metaKey,
        altKey: event.altKey,
        shiftKey: event.shiftKey
      }))
    );
  }
}
```

## Subject Patterns

### 1. Basic Subject Usage

#### Event Bus Pattern
```typescript
class EventBusService {
  private eventSubject = new Subject<AppEvent>();
  
  // Public observable for subscriptions
  public events$ = this.eventSubject.asObservable();
  
  // Emit events
  emit<T>(eventType: string, data: T): void {
    this.eventSubject.next({
      type: eventType,
      data,
      timestamp: Date.now(),
      id: this.generateId()
    });
  }
  
  // Subscribe to specific event types
  on<T>(eventType: string): Observable<T> {
    return this.events$.pipe(
      filter(event => event.type === eventType),
      map(event => event.data)
    );
  }
  
  private generateId(): string {
    return Math.random().toString(36).substr(2, 9);
  }
}

// Usage
const eventBus = new EventBusService();

// Listen for quiz completion events
eventBus.on<QuizCompletionData>('QUIZ_COMPLETED')
  .subscribe(data => {
    console.log('Quiz completed:', data);
    this.updateUserProgress(data);
  });

// Emit quiz completion
eventBus.emit('QUIZ_COMPLETED', {
  quizId: 'quiz-123',
  score: 85,
  completionTime: 120000
});
```

### 2. BehaviorSubject Patterns

#### State Management Pattern
```typescript
class UserStateService {
  // BehaviorSubject always has a current value
  private userSubject = new BehaviorSubject<User | null>(null);
  private loadingSubject = new BehaviorSubject<boolean>(false);
  private errorSubject = new BehaviorSubject<string | null>(null);
  
  // Public observables
  public user$ = this.userSubject.asObservable();
  public loading$ = this.loadingSubject.asObservable();
  public error$ = this.errorSubject.asObservable();
  
  // Computed observables
  public isAuthenticated$ = this.user$.pipe(
    map(user => user !== null)
  );
  
  public userPermissions$ = this.user$.pipe(
    map(user => user?.permissions || []),
    distinctUntilChanged()
  );
  
  // Actions
  login(credentials: LoginCredentials): Observable<User> {
    this.loadingSubject.next(true);
    this.errorSubject.next(null);
    
    return this.authApi.login(credentials).pipe(
      tap(user => {
        this.userSubject.next(user);
        this.loadingSubject.next(false);
      }),
      catchError(error => {
        this.errorSubject.next(error.message);
        this.loadingSubject.next(false);
        return throwError(() => error);
      })
    );
  }
  
  logout(): void {
    this.userSubject.next(null);
    this.errorSubject.next(null);
  }
  
  // Get current state synchronously
  getCurrentUser(): User | null {
    return this.userSubject.value;
  }
  
  isCurrentlyLoading(): boolean {
    return this.loadingSubject.value;
  }
}
```

#### Configuration Management
```typescript
class ConfigurationService {
  private configSubject = new BehaviorSubject<AppConfig>(this.getDefaultConfig());
  public config$ = this.configSubject.asObservable();
  
  // Specific configuration observables
  public theme$ = this.config$.pipe(
    map(config => config.theme),
    distinctUntilChanged()
  );
  
  public language$ = this.config$.pipe(
    map(config => config.language),
    distinctUntilChanged()
  );
  
  public features$ = this.config$.pipe(
    map(config => config.features),
    distinctUntilChanged()
  );
  
  constructor() {
    this.loadConfiguration();
  }
  
  updateConfig(updates: Partial<AppConfig>): void {
    const currentConfig = this.configSubject.value;
    const newConfig = { ...currentConfig, ...updates };
    
    this.configSubject.next(newConfig);
    this.saveConfiguration(newConfig);
  }
  
  private loadConfiguration(): void {
    const savedConfig = localStorage.getItem('app-config');
    if (savedConfig) {
      try {
        const parsed = JSON.parse(savedConfig);
        this.configSubject.next({ ...this.getDefaultConfig(), ...parsed });
      } catch (e) {
        console.warn('Failed to parse saved configuration');
      }
    }
  }
  
  private saveConfiguration(config: AppConfig): void {
    localStorage.setItem('app-config', JSON.stringify(config));
  }
  
  private getDefaultConfig(): AppConfig {
    return {
      theme: 'light',
      language: 'en',
      features: {
        darkMode: false,
        notifications: true,
        analytics: true
      }
    };
  }
}
```

### 3. ReplaySubject Patterns

#### Activity Logging
```typescript
class ActivityLogService {
  // Replay last 100 activities for new subscribers
  private activitySubject = new ReplaySubject<Activity>(100);
  public activities$ = this.activitySubject.asObservable();
  
  // Filtered activity streams
  public userActions$ = this.activities$.pipe(
    filter(activity => activity.category === 'USER_ACTION')
  );
  
  public systemEvents$ = this.activities$.pipe(
    filter(activity => activity.category === 'SYSTEM_EVENT')
  );
  
  public errors$ = this.activities$.pipe(
    filter(activity => activity.level === 'ERROR')
  );
  
  logActivity(activity: Omit<Activity, 'id' | 'timestamp'>): void {
    const fullActivity: Activity = {
      ...activity,
      id: this.generateId(),
      timestamp: Date.now()
    };
    
    this.activitySubject.next(fullActivity);
  }
  
  logUserAction(action: string, details?: any): void {
    this.logActivity({
      category: 'USER_ACTION',
      level: 'INFO',
      message: action,
      details
    });
  }
  
  logError(error: Error, context?: any): void {
    this.logActivity({
      category: 'ERROR',
      level: 'ERROR',
      message: error.message,
      details: {
        stack: error.stack,
        context
      }
    });
  }
  
  // Get recent activities
  getRecentActivities(count: number = 20): Observable<Activity[]> {
    return this.activities$.pipe(
      scan((acc: Activity[], activity: Activity) => {
        const newAcc = [activity, ...acc];
        return newAcc.slice(0, count);
      }, []),
      startWith([])
    );
  }
  
  private generateId(): string {
    return `${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
  }
}
```

### 4. AsyncSubject Patterns

#### Operation Result Pattern
```typescript
class QuizSubmissionService {
  submitQuiz(quizId: string, answers: Answer[]): Observable<QuizResult> {
    // AsyncSubject only emits the last value when completed
    const submissionSubject = new AsyncSubject<QuizResult>();
    
    this.processSubmission(quizId, answers)
      .subscribe({
        next: result => submissionSubject.next(result),
        error: error => submissionSubject.error(error),
        complete: () => submissionSubject.complete()
      });
    
    return submissionSubject.asObservable();
  }
  
  private processSubmission(quizId: string, answers: Answer[]): Observable<QuizResult> {
    return from(this.validateAnswers(answers)).pipe(
      switchMap(validAnswers => this.calculateScore(quizId, validAnswers)),
      switchMap(score => this.saveResult(quizId, score)),
      tap(result => this.logSubmission(quizId, result))
    );
  }
}
```

## Advanced Observable Patterns

### 1. Multi-Source Coordination

#### Dashboard Data Aggregation
```typescript
class DashboardService {
  loadDashboardData(userId: string): Observable<DashboardData> {
    // Combine multiple data sources
    return combineLatest([
      this.userService.getUser(userId),
      this.progressService.getUserProgress(userId),
      this.achievementService.getUserAchievements(userId),
      this.statisticsService.getUserStats(userId)
    ]).pipe(
      map(([user, progress, achievements, stats]) => ({
        user,
        progress,
        achievements,
        stats,
        lastUpdated: Date.now()
      })),
      // Cache result for 5 minutes
      shareReplay({
        bufferSize: 1,
        windowTime: 5 * 60 * 1000,
        refCount: true
      })
    );
  }
  
  // Real-time dashboard updates
  getDashboardUpdates(userId: string): Observable<DashboardUpdate> {
    return merge(
      this.progressService.getProgressUpdates(userId).pipe(
        map(progress => ({ type: 'PROGRESS_UPDATE', data: progress }))
      ),
      this.achievementService.getAchievementUpdates(userId).pipe(
        map(achievement => ({ type: 'ACHIEVEMENT_UPDATE', data: achievement }))
      ),
      this.statisticsService.getStatUpdates(userId).pipe(
        map(stats => ({ type: 'STATS_UPDATE', data: stats }))
      )
    );
  }
}
```

### 2. State Machine Pattern

#### Quiz State Management
```typescript
type QuizState = 'IDLE' | 'LOADING' | 'READY' | 'IN_PROGRESS' | 'PAUSED' | 'COMPLETED' | 'ERROR';

class QuizStateMachine {
  private stateSubject = new BehaviorSubject<QuizState>('IDLE');
  private contextSubject = new BehaviorSubject<QuizContext>({});
  
  public state$ = this.stateSubject.asObservable();
  public context$ = this.contextSubject.asObservable();
  
  // State-specific observables
  public isLoading$ = this.state$.pipe(map(state => state === 'LOADING'));
  public isReady$ = this.state$.pipe(map(state => state === 'READY'));
  public isInProgress$ = this.state$.pipe(map(state => state === 'IN_PROGRESS'));
  public isCompleted$ = this.state$.pipe(map(state => state === 'COMPLETED'));
  
  // Actions
  loadQuiz(quizId: string): Observable<void> {
    return this.transitionTo('LOADING').pipe(
      switchMap(() => this.quizService.loadQuiz(quizId)),
      tap(quiz => {
        this.updateContext({ quiz });
        this.transitionTo('READY');
      }),
      catchError(error => {
        this.updateContext({ error });
        this.transitionTo('ERROR');
        return throwError(() => error);
      }),
      map(() => void 0)
    );
  }
  
  startQuiz(): Observable<void> {
    const currentState = this.stateSubject.value;
    
    if (currentState !== 'READY') {
      return throwError(() => new Error(`Cannot start quiz from state: ${currentState}`));
    }
    
    return this.transitionTo('IN_PROGRESS').pipe(
      tap(() => {
        this.updateContext({
          startTime: Date.now(),
          currentQuestionIndex: 0
        });
      }),
      map(() => void 0)
    );
  }
  
  submitAnswer(answer: Answer): Observable<void> {
    const currentState = this.stateSubject.value;
    
    if (currentState !== 'IN_PROGRESS') {
      return throwError(() => new Error(`Cannot submit answer from state: ${currentState}`));
    }
    
    const context = this.contextSubject.value;
    const answers = [...(context.answers || []), answer];
    const nextQuestionIndex = context.currentQuestionIndex + 1;
    const totalQuestions = context.quiz?.questions.length || 0;
    
    this.updateContext({
      answers,
      currentQuestionIndex: nextQuestionIndex
    });
    
    if (nextQuestionIndex >= totalQuestions) {
      return this.completeQuiz();
    }
    
    return of(void 0);
  }
  
  private completeQuiz(): Observable<void> {
    return this.transitionTo('COMPLETED').pipe(
      tap(() => {
        const context = this.contextSubject.value;
        this.updateContext({
          endTime: Date.now(),
          totalTime: Date.now() - (context.startTime || 0)
        });
      }),
      map(() => void 0)
    );
  }
  
  private transitionTo(newState: QuizState): Observable<QuizState> {
    const currentState = this.stateSubject.value;
    
    if (this.isValidTransition(currentState, newState)) {
      this.stateSubject.next(newState);
      return of(newState);
    }
    
    return throwError(() => new Error(`Invalid transition from ${currentState} to ${newState}`));
  }
  
  private isValidTransition(from: QuizState, to: QuizState): boolean {
    const transitions: Record<QuizState, QuizState[]> = {
      'IDLE': ['LOADING'],
      'LOADING': ['READY', 'ERROR'],
      'READY': ['IN_PROGRESS', 'LOADING'],
      'IN_PROGRESS': ['PAUSED', 'COMPLETED', 'ERROR'],
      'PAUSED': ['IN_PROGRESS', 'ERROR'],
      'COMPLETED': ['IDLE'],
      'ERROR': ['IDLE', 'LOADING']
    };
    
    return transitions[from]?.includes(to) || false;
  }
  
  private updateContext(updates: Partial<QuizContext>): void {
    const current = this.contextSubject.value;
    this.contextSubject.next({ ...current, ...updates });
  }
}
```

### 3. Observable Composition Patterns

#### Data Pipeline Pattern
```typescript
class DataProcessingPipeline {
  processUserData(userId: string): Observable<ProcessedUserData> {
    return this.fetchRawUserData(userId).pipe(
      // Stage 1: Data validation
      switchMap(rawData => this.validateData(rawData)),
      
      // Stage 2: Data enrichment
      switchMap(validData => this.enrichData(validData)),
      
      // Stage 3: Data transformation
      map(enrichedData => this.transformData(enrichedData)),
      
      // Stage 4: Data aggregation
      switchMap(transformedData => this.aggregateData(transformedData)),
      
      // Error handling and retry
      retry({
        count: 3,
        delay: (error, retryCount) => {
          console.log(`Retry attempt ${retryCount} for user ${userId}`);
          return timer(1000 * retryCount);
        }
      }),
      
      // Final result
      tap(result => console.log('Processing completed for user:', userId))
    );
  }
  
  private fetchRawUserData(userId: string): Observable<RawUserData> {
    return forkJoin({
      profile: this.userApi.getProfile(userId),
      activities: this.activityApi.getActivities(userId),
      preferences: this.preferencesApi.getPreferences(userId)
    });
  }
  
  private validateData(data: RawUserData): Observable<ValidatedUserData> {
    return new Observable(observer => {
      const errors: string[] = [];
      
      if (!data.profile.email) errors.push('Email is required');
      if (!data.profile.name) errors.push('Name is required');
      if (data.activities.length === 0) errors.push('No activities found');
      
      if (errors.length > 0) {
        observer.error(new Error(`Validation failed: ${errors.join(', ')}`));
      } else {
        observer.next(data as ValidatedUserData);
        observer.complete();
      }
    });
  }
}
```

---

## Navigation

- ← Previous: [Comparison Analysis](comparison-analysis.md)
- → Next: [Operators Mastery Guide](operators-mastery-guide.md)
- ↑ Back to: [RxJS Research Overview](README.md)

---

*This deep dive into observable patterns provides the foundation for building sophisticated reactive applications with RxJS.*