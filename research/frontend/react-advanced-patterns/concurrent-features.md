# Concurrent Features - React 18+ Advanced Patterns

## 🎯 Overview

Comprehensive guide to React 18+ concurrent features including Suspense, concurrent rendering, transitions, and streaming for building responsive EdTech applications with enhanced user experience.

## 🚀 Concurrent Rendering Fundamentals

### **1. Understanding Concurrent Mode**

#### **Concurrent vs Non-Concurrent Rendering**
```typescript
// ❌ Non-concurrent (blocking) rendering
const BlockingQuizSearch: React.FC = () => {
  const [searchTerm, setSearchTerm] = useState('');
  const [results, setResults] = useState<Quiz[]>([]);

  // This blocks all other updates while filtering
  const handleSearch = (term: string) => {
    setSearchTerm(term);
    
    // Expensive operation blocks UI updates
    const filtered = allQuizzes.filter(quiz => 
      quiz.title.toLowerCase().includes(term.toLowerCase()) ||
      quiz.description.toLowerCase().includes(term.toLowerCase()) ||
      quiz.tags.some(tag => tag.toLowerCase().includes(term.toLowerCase()))
    );
    
    setResults(filtered);
  };

  return (
    <div>
      {/* Input becomes unresponsive during filtering */}
      <input
        value={searchTerm}
        onChange={(e) => handleSearch(e.target.value)}
        placeholder="Search quizzes..."
      />
      <QuizList quizzes={results} />
    </div>
  );
};

// ✅ Concurrent rendering with transitions
const ConcurrentQuizSearch: React.FC = () => {
  const [searchTerm, setSearchTerm] = useState('');
  const [results, setResults] = useState<Quiz[]>([]);
  const [isPending, startTransition] = useTransition();
  
  // Deferred value prevents blocking urgent updates
  const deferredSearchTerm = useDeferredValue(searchTerm);

  // Search effect runs with deferred value
  useEffect(() => {
    if (deferredSearchTerm) {
      startTransition(() => {
        // This expensive operation doesn't block urgent updates
        const filtered = allQuizzes.filter(quiz => 
          quiz.title.toLowerCase().includes(deferredSearchTerm.toLowerCase()) ||
          quiz.description.toLowerCase().includes(deferredSearchTerm.toLowerCase()) ||
          quiz.tags.some(tag => tag.toLowerCase().includes(deferredSearchTerm.toLowerCase()))
        );
        
        setResults(filtered);
      });
    } else {
      setResults([]);
    }
  }, [deferredSearchTerm]);

  return (
    <div>
      {/* Input remains responsive */}
      <input
        value={searchTerm}
        onChange={(e) => setSearchTerm(e.target.value)}
        placeholder="Search quizzes..."
      />
      
      {isPending && <div className="search-indicator">Searching...</div>}
      
      {/* Results update when ready, without blocking input */}
      <QuizList quizzes={results} />
    </div>
  );
};
```

### **2. Transition APIs**

#### **startTransition for Non-Urgent Updates**
```typescript
// ✅ Quiz navigation with smooth transitions
const useQuizNavigation = (quiz: Quiz) => {
  const [currentQuestionIndex, setCurrentQuestionIndex] = useState(0);
  const [answers, setAnswers] = useState<Record<string, Answer>>({});
  const [isPending, startTransition] = useTransition();

  const navigateToQuestion = useCallback((index: number) => {
    // Question navigation is not urgent - use transition
    startTransition(() => {
      setCurrentQuestionIndex(index);
      
      // Expensive operations that can be interrupted
      updateQuizProgress(index);
      preloadNextQuestionAssets(index + 1);
      saveProgressToLocalStorage(index, answers);
    });
  }, [answers]);

  const submitAnswer = useCallback((questionId: string, answer: Answer) => {
    // Answer submission is urgent - don't use transition
    setAnswers(prev => ({ ...prev, [questionId]: answer }));
    
    // Progress update can be deferred
    startTransition(() => {
      updateAnalytics(questionId, answer);
      saveAnswerToCloud(questionId, answer);
    });
  }, []);

  return {
    currentQuestionIndex,
    answers,
    isPending,
    navigateToQuestion,
    submitAnswer
  };
};

// ✅ Quiz player with concurrent features
const ConcurrentQuizPlayer: React.FC<{ quiz: Quiz }> = ({ quiz }) => {
  const {
    currentQuestionIndex,
    answers,
    isPending,
    navigateToQuestion,
    submitAnswer
  } = useQuizNavigation(quiz);

  const currentQuestion = quiz.questions[currentQuestionIndex];

  return (
    <div className="quiz-player">
      {/* Navigation remains responsive even during transitions */}
      <QuizNavigation
        currentIndex={currentQuestionIndex}
        totalQuestions={quiz.questions.length}
        onNavigate={navigateToQuestion}
        isPending={isPending}
      />
      
      {/* Question content can update smoothly */}
      <Suspense fallback={<QuestionSkeleton />}>
        <QuizQuestion
          question={currentQuestion}
          selectedAnswer={answers[currentQuestion.id]}
          onAnswerSelect={(answer) => submitAnswer(currentQuestion.id, answer)}
        />
      </Suspense>
      
      {/* Progress indicator shows transition state */}
      {isPending && (
        <div className="transition-indicator">
          Updating question...
        </div>
      )}
    </div>
  );
};
```

#### **useDeferredValue for Expensive Computations**
```typescript
// ✅ Deferred value for real-time quiz analytics
const QuizAnalyticsDashboard: React.FC<{ quizAttempts: QuizAttempt[] }> = ({
  quizAttempts
}) => {
  const [selectedTimeRange, setSelectedTimeRange] = useState('7d');
  const [selectedMetric, setSelectedMetric] = useState('score');
  
  // Defer expensive analytics calculations
  const deferredTimeRange = useDeferredValue(selectedTimeRange);
  const deferredMetric = useDeferredValue(selectedMetric);
  
  // Expensive analytics calculation
  const analyticsData = useMemo(() => {
    const startTime = performance.now();
    
    // Filter attempts by time range
    const filteredAttempts = filterAttemptsByTimeRange(quizAttempts, deferredTimeRange);
    
    // Calculate complex metrics
    const data = {
      averageScore: calculateAverageScore(filteredAttempts),
      trendData: calculateTrendData(filteredAttempts, deferredMetric),
      distributionData: calculateScoreDistribution(filteredAttempts),
      topPerformers: getTopPerformers(filteredAttempts),
      improvementMetrics: calculateImprovement(filteredAttempts)
    };
    
    const endTime = performance.now();
    console.log(`Analytics calculation took ${endTime - startTime}ms`);
    
    return data;
  }, [quizAttempts, deferredTimeRange, deferredMetric]);

  return (
    <div className="analytics-dashboard">
      {/* Controls remain responsive */}
      <div className="analytics-controls">
        <select
          value={selectedTimeRange}
          onChange={(e) => setSelectedTimeRange(e.target.value)}
        >
          <option value="24h">Last 24 Hours</option>
          <option value="7d">Last 7 Days</option>
          <option value="30d">Last 30 Days</option>
          <option value="90d">Last 90 Days</option>
        </select>
        
        <select
          value={selectedMetric}
          onChange={(e) => setSelectedMetric(e.target.value)}
        >
          <option value="score">Score</option>
          <option value="completion">Completion Rate</option>
          <option value="time">Time Spent</option>
        </select>
      </div>
      
      {/* Charts update when calculations are complete */}
      <Suspense fallback={<AnalyticsChartsSkeleton />}>
        <AnalyticsCharts data={analyticsData} />
      </Suspense>
    </div>
  );
};
```

## 💫 Advanced Suspense Patterns

### **1. Data Fetching with Suspense**

#### **Suspense-Enabled Data Hooks**
```typescript
// ✅ Suspense-compatible data fetching
interface SuspenseQueryOptions<T> {
  queryKey: string[];
  queryFn: () => Promise<T>;
  enabled?: boolean;
  staleTime?: number;
  cacheTime?: number;
}

const createSuspenseQuery = <T>(options: SuspenseQueryOptions<T>) => {
  const { queryKey, queryFn, enabled = true, staleTime = 0, cacheTime = 5 * 60 * 1000 } = options;
  
  const cacheKey = JSON.stringify(queryKey);
  
  // Simple cache implementation
  if (!queryCache.has(cacheKey) && enabled) {
    const promise = queryFn()
      .then(data => {
        queryCache.set(cacheKey, {
          data,
          timestamp: Date.now(),
          promise: null
        });
        return data;
      })
      .catch(error => {
        queryCache.delete(cacheKey);
        throw error;
      });
    
    queryCache.set(cacheKey, {
      data: null,
      timestamp: Date.now(),
      promise
    });
  }
  
  const cached = queryCache.get(cacheKey);
  
  if (!cached || !enabled) {
    throw new Promise(() => {}); // Suspend indefinitely if disabled
  }
  
  if (cached.promise) {
    throw cached.promise; // Still loading
  }
  
  // Check if data is stale
  if (Date.now() - cached.timestamp > staleTime) {
    // Background refetch
    const refreshPromise = queryFn()
      .then(data => {
        queryCache.set(cacheKey, {
          data,
          timestamp: Date.now(),
          promise: null
        });
      })
      .catch(console.error);
  }
  
  return cached.data;
};

// ✅ Suspense hook for quiz data
const useSuspenseQuiz = (quizId: string) => {
  return createSuspenseQuery({
    queryKey: ['quiz', quizId],
    queryFn: () => fetchQuiz(quizId),
    staleTime: 5 * 60 * 1000 // 5 minutes
  });
};

// ✅ Quiz component using Suspense
const QuizContent: React.FC<{ quizId: string }> = ({ quizId }) => {
  const quiz = useSuspenseQuiz(quizId);
  
  return (
    <div className="quiz-content">
      <h1>{quiz.title}</h1>
      <p>{quiz.description}</p>
      <QuizQuestionList questions={quiz.questions} />
    </div>
  );
};

// ✅ Quiz page with nested suspense boundaries
const QuizPage: React.FC<{ quizId: string }> = ({ quizId }) => {
  return (
    <div className="quiz-page">
      {/* High-priority content */}
      <Suspense fallback={<QuizHeaderSkeleton />}>
        <QuizHeader quizId={quizId} />
      </Suspense>
      
      {/* Main content */}
      <Suspense fallback={<QuizContentSkeleton />}>
        <QuizContent quizId={quizId} />
      </Suspense>
      
      {/* Low-priority sidebar */}
      <Suspense fallback={<SidebarSkeleton />}>
        <QuizSidebar quizId={quizId} />
      </Suspense>
    </div>
  );
};
```

### **2. Selective Hydration with Suspense**

#### **Server-Side Rendering with Streaming**
```typescript
// ✅ Server-side streaming setup (Next.js App Router)
// app/quiz/[id]/page.tsx
import { Suspense } from 'react';

export default async function QuizPage({ params }: { params: { id: string } }) {
  return (
    <div className="quiz-page-container">
      {/* Immediately available content */}
      <QuizBreadcrumb quizId={params.id} />
      
      {/* Streamed content with suspense boundaries */}
      <Suspense fallback={<QuizHeaderSkeleton />}>
        <QuizHeaderAsync quizId={params.id} />
      </Suspense>
      
      <div className="quiz-main-content">
        <Suspense fallback={<QuizPlayerSkeleton />}>
          <QuizPlayerAsync quizId={params.id} />
        </Suspense>
        
        <aside className="quiz-sidebar">
          <Suspense fallback={<SidebarSkeleton />}>
            <QuizStatsAsync quizId={params.id} />
          </Suspense>
        </aside>
      </div>
    </div>
  );
}

// ✅ Async components for streaming
const QuizHeaderAsync: React.FC<{ quizId: string }> = async ({ quizId }) => {
  // This runs on the server and streams when ready
  const quiz = await fetchQuizMetadata(quizId);
  
  return (
    <header className="quiz-header">
      <h1>{quiz.title}</h1>
      <div className="quiz-meta">
        <span>{quiz.questionCount} questions</span>
        <span>{quiz.duration} minutes</span>
        <span>Difficulty: {quiz.difficulty}</span>
      </div>
    </header>
  );
};

const QuizPlayerAsync: React.FC<{ quizId: string }> = async ({ quizId }) => {
  const [quiz, userProgress] = await Promise.all([
    fetchQuizDetails(quizId),
    fetchUserProgress(quizId)
  ]);
  
  return (
    <Suspense fallback={<QuizInteractionSkeleton />}>
      <QuizPlayer quiz={quiz} initialProgress={userProgress} />
    </Suspense>
  );
};
```

### **3. Error Boundaries with Concurrent Features**

#### **Concurrent-Aware Error Handling**
```typescript
// ✅ Error boundary with concurrent features support
interface ConcurrentErrorBoundaryState {
  hasError: boolean;
  error: Error | null;
  errorInfo: React.ErrorInfo | null;
  retryCount: number;
}

class ConcurrentErrorBoundary extends React.Component<
  { 
    children: React.ReactNode;
    fallback?: React.ComponentType<{ error: Error; retry: () => void }>;
    onError?: (error: Error, errorInfo: React.ErrorInfo) => void;
    maxRetries?: number;
  },
  ConcurrentErrorBoundaryState
> {
  private retryTimeoutId: NodeJS.Timeout | null = null;

  constructor(props: any) {
    super(props);
    this.state = {
      hasError: false,
      error: null,
      errorInfo: null,
      retryCount: 0
    };
  }

  static getDerivedStateFromError(error: Error): Partial<ConcurrentErrorBoundaryState> {
    return {
      hasError: true,
      error
    };
  }

  componentDidCatch(error: Error, errorInfo: React.ErrorInfo) {
    this.setState({ errorInfo });
    
    // Handle concurrent rendering errors
    if (error.message.includes('ChunkLoadError') || error.message.includes('Loading CSS chunk')) {
      // Retry chunk loading errors automatically
      this.handleRetry();
      return;
    }
    
    // Log error to monitoring service
    this.props.onError?.(error, errorInfo);
    
    console.error('Concurrent Error Boundary caught an error:', error, errorInfo);
  }

  handleRetry = () => {
    const { maxRetries = 3 } = this.props;
    
    if (this.state.retryCount < maxRetries) {
      this.setState(prevState => ({
        hasError: false,
        error: null,
        errorInfo: null,
        retryCount: prevState.retryCount + 1
      }));
    }
  };

  componentWillUnmount() {
    if (this.retryTimeoutId) {
      clearTimeout(this.retryTimeoutId);
    }
  }

  render() {
    if (this.state.hasError) {
      const FallbackComponent = this.props.fallback || DefaultErrorFallback;
      
      return (
        <FallbackComponent 
          error={this.state.error!} 
          retry={this.handleRetry}
        />
      );
    }

    return this.props.children;
  }
}

// ✅ Default error fallback with retry functionality
const DefaultErrorFallback: React.FC<{
  error: Error;
  retry: () => void;
}> = ({ error, retry }) => {
  const [isRetrying, startTransition] = useTransition();

  const handleRetry = () => {
    startTransition(() => {
      retry();
    });
  };

  return (
    <div className="error-fallback">
      <h2>Something went wrong</h2>
      <p>{error.message}</p>
      <button 
        onClick={handleRetry} 
        disabled={isRetrying}
        className="retry-button"
      >
        {isRetrying ? 'Retrying...' : 'Try Again'}
      </button>
    </div>
  );
};

// ✅ Usage with nested error boundaries
const QuizApplication: React.FC = () => {
  return (
    <ConcurrentErrorBoundary 
      fallback={AppErrorFallback}
      onError={(error, errorInfo) => {
        // Send to error tracking service
        console.error('App-level error:', error, errorInfo);
      }}
    >
      <AppHeader />
      
      <main className="app-main">
        <ConcurrentErrorBoundary 
          fallback={QuizErrorFallback}
          onError={(error) => {
            // Log quiz-specific errors
            console.error('Quiz error:', error);
          }}
        >
          <Suspense fallback={<QuizLoadingSkeleton />}>
            <QuizRouter />
          </Suspense>
        </ConcurrentErrorBoundary>
      </main>
    </ConcurrentErrorBoundary>
  );
};
```

## 🌊 Streaming and Progressive Enhancement

### **1. Streaming Server-Side Rendering**

#### **Progressive Quiz Loading**
```typescript
// ✅ Progressive quiz content streaming
const ProgressiveQuizLoader: React.FC<{ quizId: string }> = ({ quizId }) => {
  return (
    <div className="progressive-quiz-loader">
      {/* Immediately available - no data fetching needed */}
      <QuizLayoutShell />
      
      {/* Stream 1: Basic quiz metadata */}
      <Suspense fallback={<QuizTitleSkeleton />}>
        <QuizBasicInfo quizId={quizId} />
      </Suspense>
      
      {/* Stream 2: Quiz questions (higher priority) */}
      <Suspense fallback={<QuizQuestionsSkeleton />}>
        <QuizQuestions quizId={quizId} />
      </Suspense>
      
      {/* Stream 3: User progress (medium priority) */}
      <Suspense fallback={<ProgressSkeleton />}>
        <QuizProgress quizId={quizId} />
      </Suspense>
      
      {/* Stream 4: Related quizzes (low priority) */}
      <Suspense fallback={<RelatedQuizzesSkeleton />}>
        <RelatedQuizzes quizId={quizId} />
      </Suspense>
      
      {/* Stream 5: Analytics (lowest priority) */}
      <Suspense fallback={<AnalyticsSkeleton />}>
        <QuizAnalytics quizId={quizId} />
      </Suspense>
    </div>
  );
};

// ✅ Prioritized data fetching
const useStreamingData = <T>(
  fetcher: () => Promise<T>,
  priority: 'high' | 'medium' | 'low' = 'medium'
) => {
  const [data, setData] = useState<T | null>(null);
  const [isPending, startTransition] = useTransition();

  useEffect(() => {
    const loadData = async () => {
      try {
        const result = await fetcher();
        
        if (priority === 'high') {
          // High priority updates immediately
          setData(result);
        } else {
          // Lower priority updates use transition
          startTransition(() => {
            setData(result);
          });
        }
      } catch (error) {
        console.error('Streaming data error:', error);
      }
    };

    loadData();
  }, [fetcher, priority]);

  return { data, isPending };
};
```

### **2. Selective Hydration Patterns**

#### **Lazy Hydration for Heavy Components**
```typescript
// ✅ Lazy hydration hook
const useLazyHydration = (
  condition: boolean = true,
  delay: number = 0
): boolean => {
  const [shouldHydrate, setShouldHydrate] = useState(false);

  useEffect(() => {
    if (condition) {
      const timer = setTimeout(() => {
        startTransition(() => {
          setShouldHydrate(true);
        });
      }, delay);

      return () => clearTimeout(timer);
    }
  }, [condition, delay]);

  return shouldHydrate;
};

// ✅ Heavy interactive component with lazy hydration
const InteractiveQuizChart: React.FC<{ data: QuizAnalyticsData }> = ({ data }) => {
  const [isVisible, setIsVisible] = useState(false);
  const shouldHydrate = useLazyHydration(isVisible, 1000);
  
  // Use Intersection Observer to detect when component is visible
  const ref = useRef<HTMLDivElement>(null);
  
  useEffect(() => {
    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) {
          setIsVisible(true);
          observer.disconnect();
        }
      },
      { threshold: 0.1 }
    );

    if (ref.current) {
      observer.observe(ref.current);
    }

    return () => observer.disconnect();
  }, []);

  return (
    <div ref={ref} className="quiz-chart-container">
      {shouldHydrate ? (
        // Full interactive chart
        <Suspense fallback={<ChartSkeleton />}>
          <LazyQuizChart data={data} />
        </Suspense>
      ) : (
        // Static placeholder until hydration
        <StaticChartPlaceholder data={data} />
      )}
    </div>
  );
};

// ✅ Lazy loaded chart component
const LazyQuizChart = lazy(async () => {
  // Dynamically import heavy chart library
  const [chartModule, dataModule] = await Promise.all([
    import('recharts'),
    import('../utils/chartUtils')
  ]);
  
  const QuizChart: React.FC<{ data: QuizAnalyticsData }> = ({ data }) => {
    const { LineChart, Line, XAxis, YAxis, Tooltip, ResponsiveContainer } = chartModule;
    const { processChartData } = dataModule;
    
    const chartData = useMemo(() => processChartData(data), [data]);
    
    return (
      <ResponsiveContainer width="100%" height={300}>
        <LineChart data={chartData}>
          <XAxis dataKey="date" />
          <YAxis />
          <Tooltip />
          <Line type="monotone" dataKey="score" stroke="#8884d8" />
        </LineChart>
      </ResponsiveContainer>
    );
  };
  
  return { default: QuizChart };
});
```

## 🎮 Real-World EdTech Applications

### **1. Live Quiz Session with Concurrent Features**

#### **Real-Time Quiz Implementation**
```typescript
// ✅ Concurrent live quiz session
const LiveQuizSession: React.FC<{ sessionId: string }> = ({ sessionId }) => {
  const [participants, setParticipants] = useState<Participant[]>([]);
  const [currentQuestion, setCurrentQuestion] = useState<Question | null>(null);
  const [leaderboard, setLeaderboard] = useState<LeaderboardEntry[]>([]);
  const [isPending, startTransition] = useTransition();

  // Real-time updates don't block UI
  useEffect(() => {
    const eventSource = new EventSource(`/api/quiz/live/${sessionId}/stream`);
    
    eventSource.onmessage = (event) => {
      const data = JSON.parse(event.data);
      
      switch (data.type) {
        case 'PARTICIPANT_JOINED':
          // Urgent update - show immediately
          setParticipants(prev => [...prev, data.participant]);
          break;
          
        case 'QUESTION_CHANGED':
          // Urgent update - new question
          setCurrentQuestion(data.question);
          break;
          
        case 'LEADERBOARD_UPDATED':
          // Non-urgent update - can be deferred
          startTransition(() => {
            setLeaderboard(data.leaderboard);
          });
          break;
      }
    };

    return () => eventSource.close();
  }, [sessionId]);

  return (
    <div className="live-quiz-session">
      {/* Participant count updates immediately */}
      <LiveQuizHeader 
        participantCount={participants.length}
        sessionId={sessionId}
      />
      
      {/* Current question updates immediately */}
      <Suspense fallback={<QuestionSkeleton />}>
        <LiveQuizQuestion 
          question={currentQuestion}
          onAnswer={(answer) => {
            // Answer submission is urgent
            submitLiveAnswer(sessionId, answer);
          }}
        />
      </Suspense>
      
      {/* Leaderboard can update with transitions */}
      <div className="leaderboard-section">
        {isPending && (
          <div className="leaderboard-updating">
            Updating leaderboard...
          </div>
        )}
        
        <Suspense fallback={<LeaderboardSkeleton />}>
          <LiveLeaderboard entries={leaderboard} />
        </Suspense>
      </div>
    </div>
  );
};
```

### **2. Adaptive Quiz Player**

#### **Performance-Aware Quiz Rendering**
```typescript
// ✅ Adaptive quiz player that adjusts to device performance
const AdaptiveQuizPlayer: React.FC<{ quiz: Quiz }> = ({ quiz }) => {
  const [devicePerformance, setDevicePerformance] = useState<'high' | 'medium' | 'low'>('medium');
  const [currentQuestion, setCurrentQuestion] = useState(0);
  const [isPending, startTransition] = useTransition();

  // Detect device performance
  useEffect(() => {
    const detectPerformance = () => {
      const connection = (navigator as any).connection;
      const memory = (performance as any).memory;
      
      let score = 0;
      
      // Network speed
      if (connection) {
        if (connection.effectiveType === '4g') score += 2;
        else if (connection.effectiveType === '3g') score += 1;
      }
      
      // Available memory
      if (memory) {
        if (memory.jsHeapSizeLimit > 1073741824) score += 2; // > 1GB
        else if (memory.jsHeapSizeLimit > 536870912) score += 1; // > 512MB
      }
      
      // Hardware concurrency
      if (navigator.hardwareConcurrency >= 8) score += 2;
      else if (navigator.hardwareConcurrency >= 4) score += 1;
      
      if (score >= 5) setDevicePerformance('high');
      else if (score >= 3) setDevicePerformance('medium');
      else setDevicePerformance('low');
    };

    detectPerformance();
  }, []);

  const navigateToQuestion = useCallback((index: number) => {
    if (devicePerformance === 'high') {
      // High-performance devices can handle immediate updates
      setCurrentQuestion(index);
    } else {
      // Lower-performance devices use transitions
      startTransition(() => {
        setCurrentQuestion(index);
      });
    }
  }, [devicePerformance]);

  const questionComponent = useMemo(() => {
    const question = quiz.questions[currentQuestion];
    
    switch (devicePerformance) {
      case 'high':
        // Full-featured question with animations and rich media
        return (
          <Suspense fallback={<QuestionSkeleton />}>
            <RichQuizQuestion 
              question={question}
              enableAnimations={true}
              enableRichMedia={true}
            />
          </Suspense>
        );
        
      case 'medium':
        // Standard question with limited animations
        return (
          <Suspense fallback={<QuestionSkeleton />}>
            <StandardQuizQuestion 
              question={question}
              enableAnimations={false}
              enableRichMedia={true}
            />
          </Suspense>
        );
        
      case 'low':
        // Minimal question for low-end devices
        return (
          <BasicQuizQuestion 
            question={question}
            enableAnimations={false}
            enableRichMedia={false}
          />
        );
        
      default:
        return <QuestionSkeleton />;
    }
  }, [quiz.questions, currentQuestion, devicePerformance]);

  return (
    <div className={`adaptive-quiz-player performance-${devicePerformance}`}>
      <QuizProgress 
        current={currentQuestion + 1}
        total={quiz.questions.length}
        showDetailed={devicePerformance !== 'low'}
      />
      
      {questionComponent}
      
      <QuizNavigation
        currentIndex={currentQuestion}
        totalQuestions={quiz.questions.length}
        onNavigate={navigateToQuestion}
        isPending={isPending}
        adaptiveMode={devicePerformance}
      />
    </div>
  );
};
```

## 🔗 Navigation

**← Previous:** [Performance Optimization](./performance-optimization.md)  
**→ Next:** [Testing Strategies](./testing-strategies.md)

---

*React 18+ concurrent features for building responsive and efficient EdTech applications*