# Testing Strategies: RxJS Reactive Programming

Comprehensive testing approaches for reactive code using RxJS, including unit testing, integration testing, marble testing, and testing strategies specifically tailored for educational technology applications.

## Testing Fundamentals

### 1. Marble Testing Basics

Marble testing is RxJS's built-in testing framework that allows you to test observable sequences using ASCII marble diagrams.

#### Setting Up Marble Testing
```typescript
import { TestScheduler } from 'rxjs/testing';
import { map, delay, debounceTime } from 'rxjs/operators';

describe('RxJS Marble Testing', () => {
  let testScheduler: TestScheduler;
  
  beforeEach(() => {
    testScheduler = new TestScheduler((actual, expected) => {
      expect(actual).toEqual(expected);
    });
  });
  
  it('should test simple mapping', () => {
    testScheduler.run(({ cold, expectObservable }) => {
      const source$ = cold('a-b-c|', { a: 1, b: 2, c: 3 });
      const expected = 'x-y-z|';
      const expectedValues = { x: 2, y: 4, z: 6 };
      
      const result$ = source$.pipe(map(x => x * 2));
      
      expectObservable(result$).toBe(expected, expectedValues);
    });
  });
});
```

#### Marble Diagram Syntax
```typescript
// Marble diagram symbols:
// '-' : represents 10ms of time passing
// '|' : completion of the observable
// '#' : error
// 'a', 'b', 'c' : values emitted by the observable
// '()' : sync grouping - multiple values emitted synchronously
// '^' : subscription point
// '!' : unsubscription point

// Examples:
'a-b-c|'        // emit a, b, c then complete
'a-b-c#'        // emit a, b, c then error
'a-b-(cd)|'     // emit a, b, then c and d synchronously, then complete
'---a---b---c|' // emit a, b, c with longer delays
```

### 2. Testing Observable Patterns

#### Testing Hot vs Cold Observables
```typescript
describe('Hot vs Cold Observable Testing', () => {
  let testScheduler: TestScheduler;
  
  beforeEach(() => {
    testScheduler = new TestScheduler((actual, expected) => {
      expect(actual).toEqual(expected);
    });
  });
  
  it('should test cold observable', () => {
    testScheduler.run(({ cold, expectObservable }) => {
      const source$ = cold('a-b-c|', { a: 1, b: 2, c: 3 });
      
      // Each subscription gets its own execution
      expectObservable(source$).toBe('a-b-c|', { a: 1, b: 2, c: 3 });
      expectObservable(source$.pipe(delay(10))).toBe('----------a-b-c|', { a: 1, b: 2, c: 3 });
    });
  });
  
  it('should test hot observable', () => {
    testScheduler.run(({ hot, expectObservable }) => {
      const source$ = hot('a-b-c|', { a: 1, b: 2, c: 3 });
      
      // All subscribers share the same execution
      expectObservable(source$).toBe('a-b-c|', { a: 1, b: 2, c: 3 });
      expectObservable(source$, '^--!').toBe('a-b-', { a: 1, b: 2 });
    });
  });
  
  it('should test subject behavior', () => {
    testScheduler.run(({ hot, expectObservable }) => {
      const subject = new Subject<number>();
      const source$ = hot('a-b-c|', { a: 1, b: 2, c: 3 });
      
      source$.subscribe(value => subject.next(value));
      
      expectObservable(subject.asObservable()).toBe('a-b-c|', { a: 1, b: 2, c: 3 });
    });
  });
});
```

#### Testing Async Operations
```typescript
describe('Async Operations Testing', () => {
  let testScheduler: TestScheduler;
  
  beforeEach(() => {
    testScheduler = new TestScheduler((actual, expected) => {
      expect(actual).toEqual(expected);
    });
  });
  
  it('should test debounced user input', () => {
    testScheduler.run(({ hot, expectObservable }) => {
      const userInput$ = hot('a-bc--d-e-f|', {
        a: 'h',
        b: 'he',
        c: 'hel',
        d: 'hell',
        e: 'hello',
        f: 'hello!'
      });
      
      const debounced$ = userInput$.pipe(
        debounceTime(20, testScheduler),
        distinctUntilChanged()
      );
      
      expectObservable(debounced$).toBe('---c--d-e-f|', {
        c: 'hel',
        d: 'hell',
        e: 'hello',
        f: 'hello!'
      });
    });
  });
  
  it('should test API call with retry', () => {
    testScheduler.run(({ cold, expectObservable }) => {
      let callCount = 0;
      const apiCall$ = cold('#').pipe(
        tap(() => callCount++),
        retry(2),
        catchError(() => of('fallback'))
      );
      
      expectObservable(apiCall$).toBe('(f|)', { f: 'fallback' });
      
      // Verify retry count
      expect(callCount).toBe(3); // Original + 2 retries
    });
  });
});
```

### 3. Testing EdTech-Specific Scenarios

#### Testing Quiz Timer
```typescript
describe('Quiz Timer Service', () => {
  let testScheduler: TestScheduler;
  let quizTimerService: QuizTimerService;
  
  beforeEach(() => {
    testScheduler = new TestScheduler((actual, expected) => {
      expect(actual).toEqual(expected);
    });
    quizTimerService = new QuizTimerService();
  });
  
  it('should countdown from specified duration', () => {
    testScheduler.run(({ expectObservable }) => {
      const timer$ = quizTimerService.createTimer(3000, testScheduler); // 3 seconds
      
      expectObservable(timer$).toBe('a-b-c-d|', {
        a: { timeRemaining: 3000, progress: 0, finished: false },
        b: { timeRemaining: 2000, progress: 33.33, finished: false },
        c: { timeRemaining: 1000, progress: 66.67, finished: false },
        d: { timeRemaining: 0, progress: 100, finished: true }
      });
    });
  });
  
  it('should handle timer pause and resume', () => {
    testScheduler.run(({ hot, expectObservable }) => {
      const pauseSignal$ = hot('--p-r--|', { p: true, r: false });
      const timer$ = quizTimerService.createPausableTimer(2000, pauseSignal$, testScheduler);
      
      expectObservable(timer$).toBe('a-b---c|', {
        a: { timeRemaining: 2000, paused: false },
        b: { timeRemaining: 1000, paused: true },
        c: { timeRemaining: 0, paused: false }
      });
    });
  });
});
```

#### Testing Progress Tracking
```typescript
describe('User Progress Service', () => {
  let testScheduler: TestScheduler;
  let progressService: UserProgressService;
  let mockApiService: jasmine.SpyObj<ApiService>;
  
  beforeEach(() => {
    testScheduler = new TestScheduler((actual, expected) => {
      expect(actual).toEqual(expected);
    });
    
    mockApiService = jasmine.createSpyObj('ApiService', ['syncProgress']);
    progressService = new UserProgressService('user-123', mockApiService);
  });
  
  it('should update progress when lesson is completed', () => {
    testScheduler.run(({ cold, expectObservable }) => {
      mockApiService.syncProgress.and.returnValue(
        cold('--a|', { a: { success: true } })
      );
      
      const completion$ = progressService.completeLesson('lesson-1', 300, 85);
      
      expectObservable(completion$).toBe('--a|', {
        a: jasmine.objectContaining({
          totalLessonsCompleted: 1,
          totalTimeSpent: 300,
          experiencePoints: jasmine.any(Number)
        })
      });
    });
  });
  
  it('should handle streak calculation correctly', () => {
    testScheduler.run(({ cold, hot, expectObservable }) => {
      const lessonCompletions$ = hot('a---b---c|', {
        a: { lessonId: 'lesson-1', day: 1 },
        b: { lessonId: 'lesson-2', day: 2 },
        c: { lessonId: 'lesson-3', day: 3 }
      });
      
      const streaks$ = lessonCompletions$.pipe(
        scan((streak, completion) => {
          return progressService.calculateStreak(streak, completion.day);
        }, 0)
      );
      
      expectObservable(streaks$).toBe('a---b---c|', {
        a: 1,
        b: 2,
        c: 3
      });
    });
  });
});
```

#### Testing Real-Time Features
```typescript
describe('Live Quiz WebSocket Service', () => {
  let testScheduler: TestScheduler;
  let liveQuizService: LiveQuizService;
  let mockWebSocket: jasmine.SpyObj<WebSocketSubject<any>>;
  
  beforeEach(() => {
    testScheduler = new TestScheduler((actual, expected) => {
      expect(actual).toEqual(expected);
    });
    
    mockWebSocket = jasmine.createSpyObj('WebSocketSubject', ['next', 'subscribe']);
    liveQuizService = new LiveQuizService('quiz-123');
    (liveQuizService as any).socket$ = mockWebSocket;
  });
  
  it('should handle incoming quiz state updates', () => {
    testScheduler.run(({ hot, expectObservable }) => {
      const webSocketMessages$ = hot('a-b-c|', {
        a: { type: 'QUIZ_STATE_UPDATE', data: { currentQuestion: 1 } },
        b: { type: 'QUIZ_STATE_UPDATE', data: { currentQuestion: 2 } },
        c: { type: 'QUIZ_ENDED', data: { finalScore: 85 } }
      });
      
      mockWebSocket.subscribe.and.returnValue(webSocketMessages$);
      
      const quizState$ = liveQuizService.quizState$;
      
      expectObservable(quizState$).toBe('a-b-c|', {
        a: jasmine.objectContaining({ currentQuestion: 1 }),
        b: jasmine.objectContaining({ currentQuestion: 2 }),
        c: jasmine.objectContaining({ isActive: false, finalScore: 85 })
      });
    });
  });
  
  it('should handle WebSocket reconnection', () => {
    testScheduler.run(({ cold, expectObservable }) => {
      const connectionAttempts$ = cold('#-#-a|', { a: 'connected' }).pipe(
        retry(2)
      );
      
      expectObservable(connectionAttempts$).toBe('-----a|', { a: 'connected' });
    });
  });
});
```

## Integration Testing

### 1. Testing Component Integration

#### Testing React Components with RxJS
```typescript
import { render, fireEvent, waitFor } from '@testing-library/react';
import { TestScheduler } from 'rxjs/testing';
import { SearchComponent } from './SearchComponent';
import { SearchService } from './SearchService';

describe('SearchComponent Integration', () => {
  let testScheduler: TestScheduler;
  let mockSearchService: jasmine.SpyObj<SearchService>;
  
  beforeEach(() => {
    testScheduler = new TestScheduler((actual, expected) => {
      expect(actual).toEqual(expected);
    });
    
    mockSearchService = jasmine.createSpyObj('SearchService', ['search']);
  });
  
  it('should debounce search input and display results', async () => {
    testScheduler.run(({ cold }) => {
      const searchResults$ = cold('--a|', {
        a: [
          { id: '1', title: 'React Basics', type: 'course' },
          { id: '2', title: 'Advanced React', type: 'course' }
        ]
      });
      
      mockSearchService.search.and.returnValue(searchResults$);
      
      const { getByPlaceholderText, getByText } = render(
        <SearchComponent searchService={mockSearchService} />
      );
      
      const searchInput = getByPlaceholderText('Search courses...');
      
      // Simulate rapid typing
      fireEvent.change(searchInput, { target: { value: 'r' } });
      fireEvent.change(searchInput, { target: { value: 're' } });
      fireEvent.change(searchInput, { target: { value: 'rea' } });
      fireEvent.change(searchInput, { target: { value: 'react' } });
      
      // Wait for debounced search
      await waitFor(() => {
        expect(mockSearchService.search).toHaveBeenCalledWith('react');
        expect(getByText('React Basics')).toBeInTheDocument();
        expect(getByText('Advanced React')).toBeInTheDocument();
      });
    });
  });
});
```

#### Testing Angular Components with RxJS
```typescript
import { ComponentFixture, TestBed, fakeAsync, tick } from '@angular/core/testing';
import { TestScheduler } from 'rxjs/testing';
import { QuizComponent } from './quiz.component';
import { QuizService } from './quiz.service';
import { of, BehaviorSubject } from 'rxjs';

describe('QuizComponent Integration', () => {
  let component: QuizComponent;
  let fixture: ComponentFixture<QuizComponent>;
  let testScheduler: TestScheduler;
  let mockQuizService: jasmine.SpyObj<QuizService>;
  
  beforeEach(() => {
    testScheduler = new TestScheduler((actual, expected) => {
      expect(actual).toEqual(expected);
    });
    
    mockQuizService = jasmine.createSpyObj('QuizService', 
      ['loadQuiz', 'submitAnswer'], 
      {
        currentQuestion$: new BehaviorSubject(null),
        timeRemaining$: new BehaviorSubject(60),
        score$: new BehaviorSubject(0)
      }
    );
    
    TestBed.configureTestingModule({
      declarations: [QuizComponent],
      providers: [
        { provide: QuizService, useValue: mockQuizService }
      ]
    });
    
    fixture = TestBed.createComponent(QuizComponent);
    component = fixture.componentInstance;
  });
  
  it('should load quiz and display first question', fakeAsync(() => {
    testScheduler.run(({ cold }) => {
      const mockQuiz = {
        id: 'quiz-1',
        questions: [
          { id: 'q1', text: 'What is React?', options: ['Library', 'Framework'] }
        ]
      };
      
      mockQuizService.loadQuiz.and.returnValue(cold('--a|', { a: mockQuiz }));
      
      component.ngOnInit();
      tick();
      
      expect(mockQuizService.loadQuiz).toHaveBeenCalledWith('quiz-1');
      
      // Simulate question loading
      (mockQuizService.currentQuestion$ as BehaviorSubject<any>).next(mockQuiz.questions[0]);
      
      fixture.detectChanges();
      tick();
      
      expect(fixture.nativeElement.textContent).toContain('What is React?');
    });
  }));
  
  it('should handle answer submission', fakeAsync(() => {
    testScheduler.run(({ cold }) => {
      mockQuizService.submitAnswer.and.returnValue(cold('--a|', { a: { correct: true } }));
      
      component.submitAnswer(0);
      tick();
      
      expect(mockQuizService.submitAnswer).toHaveBeenCalledWith(0);
    });
  }));
});
```

### 2. End-to-End Testing

#### Testing Complete User Workflows
```typescript
import { TestScheduler } from 'rxjs/testing';
import { UserProgressService } from './user-progress.service';
import { QuizService } from './quiz.service';
import { AchievementService } from './achievement.service';

describe('Complete Learning Workflow E2E', () => {
  let testScheduler: TestScheduler;
  let progressService: UserProgressService;
  let quizService: QuizService;
  let achievementService: AchievementService;
  
  beforeEach(() => {
    testScheduler = new TestScheduler((actual, expected) => {
      expect(actual).toEqual(expected);
    });
    
    // Setup services with real implementations
    progressService = new UserProgressService('user-123');
    quizService = new QuizService();
    achievementService = new AchievementService();
  });
  
  it('should complete full learning session workflow', () => {
    testScheduler.run(({ cold, expectObservable }) => {
      // 1. User starts quiz
      const quizStart$ = quizService.startQuiz('quiz-1');
      
      // 2. User completes quiz
      const quizCompletion$ = quizStart$.pipe(
        switchMap(() => quizService.submitAnswers([0, 1, 2, 0])),
        tap(result => progressService.recordQuizCompletion('quiz-1', result))
      );
      
      // 3. Check for achievements
      const achievements$ = quizCompletion$.pipe(
        switchMap(() => achievementService.checkForNewAchievements('user-123'))
      );
      
      // 4. Update user progress
      const finalProgress$ = achievements$.pipe(
        switchMap(() => progressService.getCurrentProgress())
      );
      
      expectObservable(finalProgress$).toBe('----------a|', {
        a: jasmine.objectContaining({
          totalQuizzesCompleted: jasmine.any(Number),
          experiencePoints: jasmine.any(Number),
          achievements: jasmine.any(Array)
        })
      });
    });
  });
});
```

## Testing Utilities and Helpers

### 1. Custom Test Utilities

#### Observable Testing Utilities
```typescript
export class RxTestUtils {
  static createMockObservable<T>(values: T[], scheduler?: TestScheduler): Observable<T> {
    const marble = values.map((_, i) => String.fromCharCode(97 + i)).join('-') + '|';
    const valueMap = values.reduce((acc, value, i) => {
      acc[String.fromCharCode(97 + i)] = value;
      return acc;
    }, {} as any);
    
    return scheduler ? scheduler.createColdObservable(marble, valueMap) : of(...values);
  }
  
  static expectObservableToEmit<T>(
    observable$: Observable<T>,
    expectedValues: T[],
    scheduler?: TestScheduler
  ): void {
    if (scheduler) {
      scheduler.run(({ expectObservable }) => {
        const marble = expectedValues.map((_, i) => String.fromCharCode(97 + i)).join('-') + '|';
        const valueMap = expectedValues.reduce((acc, value, i) => {
          acc[String.fromCharCode(97 + i)] = value;
          return acc;
        }, {} as any);
        
        expectObservable(observable$).toBe(marble, valueMap);
      });
    } else {
      // Fallback for non-marble testing
      const actualValues: T[] = [];
      observable$.subscribe(value => actualValues.push(value));
      expect(actualValues).toEqual(expectedValues);
    }
  }
  
  static createTimerMock(duration: number, scheduler: TestScheduler): Observable<number> {
    const frames = Math.ceil(duration / 10); // 10ms per frame
    const marble = Array(frames).fill('-').join('') + 'a|';
    return scheduler.createColdObservable(marble, { a: 0 });
  }
}
```

#### Mock Service Factories
```typescript
export class MockServiceFactory {
  static createMockApiService(): jasmine.SpyObj<ApiService> {
    const spy = jasmine.createSpyObj('ApiService', [
      'get',
      'post',
      'put',
      'delete',
      'search'
    ]);
    
    // Default mock implementations
    spy.get.and.returnValue(of({}));
    spy.post.and.returnValue(of({}));
    spy.put.and.returnValue(of({}));
    spy.delete.and.returnValue(of({}));
    spy.search.and.returnValue(of([]));
    
    return spy;
  }
  
  static createMockWebSocketService(): jasmine.SpyObj<WebSocketService> {
    const spy = jasmine.createSpyObj('WebSocketService', [
      'connect',
      'disconnect',
      'send'
    ], {
      messages$: new Subject(),
      connectionStatus$: new BehaviorSubject('disconnected')
    });
    
    return spy;
  }
  
  static createMockProgressService(): jasmine.SpyObj<UserProgressService> {
    const spy = jasmine.createSpyObj('UserProgressService', [
      'completeLesson',
      'updateProgress',
      'syncProgress'
    ], {
      progress$: new BehaviorSubject({
        totalLessonsCompleted: 0,
        experiencePoints: 0,
        currentStreak: 0
      }),
      level$: new BehaviorSubject(1)
    });
    
    return spy;
  }
}
```

### 2. Test Data Builders

#### Test Data Factory
```typescript
export class TestDataFactory {
  static createUser(overrides: Partial<User> = {}): User {
    return {
      id: 'user-123',
      name: 'Test User',
      email: 'test@example.com',
      avatar: 'https://example.com/avatar.jpg',
      createdAt: new Date(),
      ...overrides
    };
  }
  
  static createQuizQuestion(overrides: Partial<QuizQuestion> = {}): QuizQuestion {
    return {
      id: 'question-123',
      text: 'What is the capital of France?',
      options: ['London', 'Berlin', 'Paris', 'Madrid'],
      correctAnswer: 2,
      explanation: 'Paris is the capital of France.',
      timeLimit: 30,
      points: 10,
      ...overrides
    };
  }
  
  static createQuiz(questionCount: number = 3, overrides: Partial<Quiz> = {}): Quiz {
    return {
      id: 'quiz-123',
      title: 'Geography Quiz',
      description: 'Test your geography knowledge',
      questions: Array.from({ length: questionCount }, (_, i) => 
        this.createQuizQuestion({ id: `question-${i + 1}` })
      ),
      timeLimit: questionCount * 30,
      passingScore: 70,
      ...overrides
    };
  }
  
  static createProgressData(overrides: Partial<UserProgress> = {}): UserProgress {
    return {
      userId: 'user-123',
      totalLessonsCompleted: 5,
      totalTimeSpent: 3600,
      currentStreak: 3,
      longestStreak: 7,
      level: 2,
      experiencePoints: 150,
      badges: [],
      weeklyGoal: 5,
      weeklyProgress: 3,
      lastActivity: new Date(),
      completedLessons: [],
      ...overrides
    };
  }
}
```

## Performance Testing

### 1. Memory Leak Detection

```typescript
describe('Memory Leak Testing', () => {
  it('should not leak memory with multiple subscriptions', () => {
    const service = new UserProgressService('user-123');
    const subscriptions: Subscription[] = [];
    
    // Create many subscriptions
    for (let i = 0; i < 1000; i++) {
      subscriptions.push(
        service.progress$.subscribe()
      );
    }
    
    // Measure memory before cleanup
    const memoryBefore = (performance as any).memory?.usedJSHeapSize || 0;
    
    // Unsubscribe all
    subscriptions.forEach(sub => sub.unsubscribe());
    
    // Force garbage collection (if available)
    if ((global as any).gc) {
      (global as any).gc();
    }
    
    // Measure memory after cleanup
    const memoryAfter = (performance as any).memory?.usedJSHeapSize || 0;
    
    // Memory should not increase significantly
    expect(memoryAfter - memoryBefore).toBeLessThan(1000000); // 1MB threshold
  });
});
```

### 2. Performance Benchmarking

```typescript
describe('Performance Benchmarks', () => {
  it('should process large datasets efficiently', () => {
    testScheduler.run(({ cold, expectObservable }) => {
      const largeDataset = Array.from({ length: 10000 }, (_, i) => i);
      const source$ = from(largeDataset);
      
      const startTime = performance.now();
      
      const processed$ = source$.pipe(
        filter(x => x % 2 === 0),
        map(x => x * 2),
        scan((acc, x) => acc + x, 0),
        takeLast(1)
      );
      
      processed$.subscribe(result => {
        const endTime = performance.now();
        const processingTime = endTime - startTime;
        
        expect(processingTime).toBeLessThan(100); // Should complete in < 100ms
        expect(result).toBe(49995000); // Expected sum
      });
    });
  });
});
```

## Best Practices for Testing RxJS

### 1. Testing Guidelines

- **Use marble testing** for complex observable chains
- **Test error scenarios** explicitly with `#` marble syntax
- **Test subscription timing** with subscription markers `^` and `!`
- **Mock external dependencies** (HTTP, WebSocket, timers)
- **Test memory management** by verifying subscriptions are cleaned up
- **Use TestScheduler** for all time-dependent tests
- **Test both happy path and error cases**
- **Verify side effects** using `tap` operator in tests

### 2. Common Testing Pitfalls

```typescript
// ❌ DON'T: Test without TestScheduler for time-dependent operations
it('should debounce - WRONG', (done) => {
  const source$ = of('test').pipe(debounceTime(300));
  setTimeout(() => {
    source$.subscribe(value => {
      expect(value).toBe('test');
      done();
    });
  }, 400);
});

// ✅ DO: Use TestScheduler for predictable timing
it('should debounce - CORRECT', () => {
  testScheduler.run(({ cold, expectObservable }) => {
    const source$ = cold('a|', { a: 'test' }).pipe(
      debounceTime(300, testScheduler)
    );
    expectObservable(source$).toBe('---a|', { a: 'test' });
  });
});

// ❌ DON'T: Forget to test error cases
it('should handle success only - INCOMPLETE', () => {
  const result$ = apiService.getData();
  expectObservable(result$).toBe('--a|', { a: mockData });
});

// ✅ DO: Test both success and error scenarios
describe('API Service', () => {
  it('should handle successful response', () => {
    // Test success case
  });
  
  it('should handle network errors', () => {
    testScheduler.run(({ cold, expectObservable }) => {
      const error$ = cold('#', null, new Error('Network error'));
      const result$ = error$.pipe(catchError(() => of('fallback')));
      expectObservable(result$).toBe('(f|)', { f: 'fallback' });
    });
  });
});

// ❌ DON'T: Test without cleanup verification
it('should subscribe - INCOMPLETE', () => {
  const service = new MyService();
  service.data$.subscribe();
  // Missing cleanup verification
});

// ✅ DO: Verify proper cleanup
it('should cleanup subscriptions', () => {
  const service = new MyService();
  const subscription = service.data$.subscribe();
  
  subscription.unsubscribe();
  expect(subscription.closed).toBe(true);
});
```

---

## Navigation

- ← Previous: [Memory Management & Performance](memory-management-performance.md)
- → Next: [Template Examples](template-examples.md)
- ↑ Back to: [RxJS Research Overview](README.md)

---

*These testing strategies ensure robust, maintainable reactive code in educational technology applications.*