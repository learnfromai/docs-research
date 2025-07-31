# Migration Guide - Legacy to Modern React Patterns

## 🎯 Overview

Comprehensive guide for migrating legacy React applications to modern advanced patterns. This document provides step-by-step migration strategies for EdTech applications, focusing on minimal disruption and gradual adoption.

## 📊 Migration Assessment

### **1. Legacy Code Audit**

#### **Identifying Legacy Patterns**
```typescript
// ❌ Legacy patterns to identify and migrate

// Class components with lifecycle methods
class LegacyQuizComponent extends Component {
  constructor(props) {
    super(props);
    this.state = {
      questions: [],
      currentIndex: 0,
      loading: true
    };
  }

  componentDidMount() {
    this.fetchQuestions();
  }

  componentDidUpdate(prevProps) {
    if (prevProps.quizId !== this.props.quizId) {
      this.fetchQuestions();
    }
  }

  fetchQuestions = async () => {
    try {
      const response = await fetch(`/api/quiz/${this.props.quizId}`);
      const data = await response.json();
      this.setState({ questions: data.questions, loading: false });
    } catch (error) {
      this.setState({ error: error.message, loading: false });
    }
  };

  render() {
    const { questions, currentIndex, loading } = this.state;
    
    if (loading) return <div>Loading...</div>;
    
    return (
      <div>
        {questions[currentIndex] && (
          <QuestionComponent question={questions[currentIndex]} />
        )}
      </div>
    );
  }
}

// Higher-Order Components (HOCs)
const withAuth = (WrappedComponent) => {
  return class extends Component {
    componentDidMount() {
      if (!this.props.user) {
        this.props.redirectToLogin();
      }
    }

    render() {
      return this.props.user ? <WrappedComponent {...this.props} /> : null;
    }
  };
};

// Render props pattern
class DataProvider extends Component {
  state = { data: null, loading: true };

  componentDidMount() {
    this.fetchData();
  }

  fetchData = async () => {
    const data = await api.getData();
    this.setState({ data, loading: false });
  };

  render() {
    return this.props.children(this.state);
  }
}

// Usage
<DataProvider>
  {({ data, loading }) => (
    loading ? <Spinner /> : <DataDisplay data={data} />
  )}
</DataProvider>
```

#### **Migration Priority Matrix**
```typescript
// ✅ Migration priority assessment tool
interface MigrationAssessment {
  componentName: string;
  complexity: 'low' | 'medium' | 'high';
  businessCritical: boolean;
  testCoverage: number;
  dependencies: string[];
  estimatedEffort: number; // hours
  modernizationBenefit: 'low' | 'medium' | 'high';
}

const assessComponent = (componentPath: string): MigrationAssessment => {
  const component = analyzeComponent(componentPath);
  
  return {
    componentName: component.name,
    complexity: calculateComplexity(component),
    businessCritical: isBusinessCritical(component),
    testCoverage: getTestCoverage(component),
    dependencies: getDependencies(component),
    estimatedEffort: estimateEffort(component),
    modernizationBenefit: calculateBenefit(component)
  };
};

const createMigrationPlan = (assessments: MigrationAssessment[]) => {
  return assessments
    .sort((a, b) => {
      // Prioritize by: low risk, high benefit, low effort, high business value
      const scoreA = calculateMigrationScore(a);
      const scoreB = calculateMigrationScore(b);
      return scoreB - scoreA;
    })
    .map((assessment, index) => ({
      ...assessment,
      phase: Math.floor(index / 5) + 1, // Group into phases of 5 components
      startWeek: Math.floor(index / 5) * 2 + 1
    }));
};
```

## 🔄 Phase 1: Foundation Migration

### **1. React 18 Upgrade**

#### **Upgrading to React 18**
```bash
# ✅ Step 1: Update React and ReactDOM
npm install react@^18.2.0 react-dom@^18.2.0

# Update TypeScript types if using TypeScript
npm install --save-dev @types/react@^18.0.0 @types/react-dom@^18.0.0

# Update testing libraries
npm install --save-dev @testing-library/react@^13.4.0
```

```typescript
// ✅ Step 2: Update root rendering
// Before (React 17)
import ReactDOM from 'react-dom';
import App from './App';

ReactDOM.render(<App />, document.getElementById('root'));

// After (React 18)
import { createRoot } from 'react-dom/client';
import App from './App';

const container = document.getElementById('root')!;
const root = createRoot(container);
root.render(<App />);
```

```typescript
// ✅ Step 3: Enable Strict Mode and Concurrent Features
const App: React.FC = () => {
  return (
    <React.StrictMode>
      <ErrorBoundary fallback={<ErrorFallback />}>
        <Suspense fallback={<GlobalLoadingSpinner />}>
          <BrowserRouter>
            <AppProviders>
              <AppRoutes />
            </AppProviders>
          </BrowserRouter>
        </Suspense>
      </ErrorBoundary>
    </React.StrictMode>
  );
};
```

### **2. Class Component to Hooks Migration**

#### **Systematic Class to Function Component Migration**
```typescript
// ❌ Legacy class component
class LegacyQuizPlayer extends Component<QuizPlayerProps, QuizPlayerState> {
  private timerRef: NodeJS.Timeout | null = null;

  constructor(props: QuizPlayerProps) {
    super(props);
    this.state = {
      currentQuestionIndex: 0,
      answers: {},
      timeRemaining: props.timeLimit,
      isCompleted: false,
      score: null
    };
  }

  componentDidMount() {
    this.startTimer();
    this.loadQuizData();
  }

  componentDidUpdate(prevProps: QuizPlayerProps, prevState: QuizPlayerState) {
    if (prevProps.quizId !== this.props.quizId) {
      this.resetQuiz();
      this.loadQuizData();
    }

    if (prevState.timeRemaining !== this.state.timeRemaining && this.state.timeRemaining === 0) {
      this.handleTimeUp();
    }
  }

  componentWillUnmount() {
    if (this.timerRef) {
      clearInterval(this.timerRef);
    }
  }

  startTimer = () => {
    this.timerRef = setInterval(() => {
      this.setState(prevState => ({
        timeRemaining: Math.max(0, prevState.timeRemaining - 1)
      }));
    }, 1000);
  };

  loadQuizData = async () => {
    try {
      const quiz = await fetchQuiz(this.props.quizId);
      this.setState({ 
        quiz,
        timeRemaining: quiz.timeLimit 
      });
    } catch (error) {
      this.setState({ error: error.message });
    }
  };

  // ... more methods
}

// ✅ Migrated to hooks with incremental approach
const ModernQuizPlayer: React.FC<QuizPlayerProps> = ({ 
  quizId, 
  timeLimit,
  onComplete 
}) => {
  // Step 1: Convert state to useState hooks
  const [currentQuestionIndex, setCurrentQuestionIndex] = useState(0);
  const [answers, setAnswers] = useState<Record<string, Answer>>({});
  const [timeRemaining, setTimeRemaining] = useState(timeLimit);
  const [isCompleted, setIsCompleted] = useState(false);
  const [score, setScore] = useState<number | null>(null);
  const [quiz, setQuiz] = useState<Quiz | null>(null);
  const [error, setError] = useState<string | null>(null);

  // Step 2: Convert refs to useRef
  const timerRef = useRef<NodeJS.Timeout | null>(null);

  // Step 3: Convert lifecycle methods to useEffect
  // componentDidMount equivalent
  useEffect(() => {
    loadQuizData();
    startTimer();

    // componentWillUnmount equivalent
    return () => {
      if (timerRef.current) {
        clearInterval(timerRef.current);
      }
    };
  }, []); // Empty dependency array = componentDidMount

  // componentDidUpdate equivalent for quizId changes
  useEffect(() => {
    resetQuiz();
    loadQuizData();
  }, [quizId]);

  // componentDidUpdate equivalent for timeRemaining changes
  useEffect(() => {
    if (timeRemaining === 0) {
      handleTimeUp();
    }
  }, [timeRemaining]);

  // Step 4: Convert methods to useCallback for optimization
  const startTimer = useCallback(() => {
    timerRef.current = setInterval(() => {
      setTimeRemaining(prev => Math.max(0, prev - 1));
    }, 1000);
  }, []);

  const loadQuizData = useCallback(async () => {
    try {
      const quizData = await fetchQuiz(quizId);
      setQuiz(quizData);
      setTimeRemaining(quizData.timeLimit);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load quiz');
    }
  }, [quizId]);

  const resetQuiz = useCallback(() => {
    setCurrentQuestionIndex(0);
    setAnswers({});
    setIsCompleted(false);
    setScore(null);
    setError(null);
    
    if (timerRef.current) {
      clearInterval(timerRef.current);
    }
  }, []);

  const handleTimeUp = useCallback(() => {
    setIsCompleted(true);
    if (timerRef.current) {
      clearInterval(timerRef.current);
    }
    onComplete?.(answers);
  }, [answers, onComplete]);

  // ... rest of component logic

  if (error) {
    return <QuizError error={error} onRetry={loadQuizData} />;
  }

  if (!quiz) {
    return <QuizLoadingSkeleton />;
  }

  return (
    <div className="modern-quiz-player">
      {/* Component JSX */}
    </div>
  );
};
```

### **3. Custom Hook Extraction**

#### **Extracting Reusable Logic into Custom Hooks**
```typescript
// ✅ Step 1: Extract timer logic to custom hook
const useQuizTimer = (initialTime: number, onTimeUp?: () => void) => {
  const [timeRemaining, setTimeRemaining] = useState(initialTime);
  const [isActive, setIsActive] = useState(false);
  const timerRef = useRef<NodeJS.Timeout | null>(null);

  const start = useCallback(() => {
    setIsActive(true);
  }, []);

  const pause = useCallback(() => {
    setIsActive(false);
  }, []);

  const reset = useCallback(() => {
    setTimeRemaining(initialTime);
    setIsActive(false);
  }, [initialTime]);

  useEffect(() => {
    if (isActive && timeRemaining > 0) {
      timerRef.current = setInterval(() => {
        setTimeRemaining(prev => {
          const newTime = prev - 1;
          if (newTime === 0) {
            setIsActive(false);
            onTimeUp?.();
          }
          return Math.max(0, newTime);
        });
      }, 1000);
    } else {
      if (timerRef.current) {
        clearInterval(timerRef.current);
        timerRef.current = null;
      }
    }

    return () => {
      if (timerRef.current) {
        clearInterval(timerRef.current);
      }
    };
  }, [isActive, timeRemaining, onTimeUp]);

  return {
    timeRemaining,
    isActive,
    start,
    pause,
    reset
  };
};

// ✅ Step 2: Extract quiz state management
const useQuizState = (quizId: string) => {
  const [quiz, setQuiz] = useState<Quiz | null>(null);
  const [currentQuestionIndex, setCurrentQuestionIndex] = useState(0);
  const [answers, setAnswers] = useState<Record<string, Answer>>({});
  const [isCompleted, setIsCompleted] = useState(false);
  const [score, setScore] = useState<number | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const loadQuiz = useCallback(async () => {
    setLoading(true);
    setError(null);
    
    try {
      const quizData = await fetchQuiz(quizId);
      setQuiz(quizData);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load quiz');
    } finally {
      setLoading(false);
    }
  }, [quizId]);

  const submitAnswer = useCallback((questionId: string, answer: Answer) => {
    setAnswers(prev => ({ ...prev, [questionId]: answer }));
  }, []);

  const navigateToQuestion = useCallback((index: number) => {
    if (quiz && index >= 0 && index < quiz.questions.length) {
      setCurrentQuestionIndex(index);
    }
  }, [quiz]);

  const completeQuiz = useCallback(() => {
    if (quiz) {
      const calculatedScore = calculateScore(quiz.questions, answers);
      setScore(calculatedScore);
      setIsCompleted(true);
    }
  }, [quiz, answers]);

  const resetQuiz = useCallback(() => {
    setCurrentQuestionIndex(0);
    setAnswers({});
    setIsCompleted(false);
    setScore(null);
    setError(null);
  }, []);

  useEffect(() => {
    loadQuiz();
  }, [loadQuiz]);

  return {
    quiz,
    currentQuestionIndex,
    answers,
    isCompleted,
    score,
    loading,
    error,
    submitAnswer,
    navigateToQuestion,
    completeQuiz,
    resetQuiz,
    refetch: loadQuiz
  };
};

// ✅ Step 3: Simplified component using custom hooks
const SimplifiedQuizPlayer: React.FC<QuizPlayerProps> = ({ 
  quizId, 
  timeLimit,
  onComplete 
}) => {
  const quizState = useQuizState(quizId);
  const timer = useQuizTimer(timeLimit, () => {
    quizState.completeQuiz();
    onComplete?.(quizState.answers);
  });

  // Start timer when quiz loads
  useEffect(() => {
    if (quizState.quiz && !quizState.isCompleted) {
      timer.start();
    }
  }, [quizState.quiz, quizState.isCompleted, timer]);

  if (quizState.loading) {
    return <QuizLoadingSkeleton />;
  }

  if (quizState.error) {
    return <QuizError error={quizState.error} onRetry={quizState.refetch} />;
  }

  if (!quizState.quiz) {
    return <div>Quiz not found</div>;
  }

  return (
    <div className="simplified-quiz-player">
      <QuizHeader 
        title={quizState.quiz.title}
        timeRemaining={timer.timeRemaining}
        progress={{
          current: quizState.currentQuestionIndex + 1,
          total: quizState.quiz.questions.length
        }}
      />
      
      <QuizContent
        question={quizState.quiz.questions[quizState.currentQuestionIndex]}
        selectedAnswer={quizState.answers[quizState.quiz.questions[quizState.currentQuestionIndex].id]}
        onAnswerSelect={(answer) => 
          quizState.submitAnswer(
            quizState.quiz!.questions[quizState.currentQuestionIndex].id,
            answer
          )
        }
      />
      
      <QuizNavigation
        canGoNext={quizState.currentQuestionIndex < quizState.quiz.questions.length - 1}
        canGoPrevious={quizState.currentQuestionIndex > 0}
        canSubmit={Object.keys(quizState.answers).length === quizState.quiz.questions.length}
        onNext={() => quizState.navigateToQuestion(quizState.currentQuestionIndex + 1)}
        onPrevious={() => quizState.navigateToQuestion(quizState.currentQuestionIndex - 1)}
        onSubmit={quizState.completeQuiz}
      />
    </div>
  );
};
```

## 🏗️ Phase 2: State Management Migration

### **1. HOC to Hooks Migration**

#### **Converting Higher-Order Components**
```typescript
// ❌ Legacy HOC pattern
const withAuth = <P extends object>(WrappedComponent: React.ComponentType<P>) => {
  const AuthenticatedComponent: React.FC<P> = (props) => {
    const [user, setUser] = useState<User | null>(null);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
      const checkAuth = async () => {
        try {
          const userData = await getCurrentUser();
          setUser(userData);
        } catch (error) {
          // Redirect to login
          window.location.href = '/login';
        } finally {
          setLoading(false);
        }
      };

      checkAuth();
    }, []);

    if (loading) {
      return <div>Loading...</div>;
    }

    if (!user) {
      return <div>Access denied</div>;
    }

    return <WrappedComponent {...props} user={user} />;
  };

  return AuthenticatedComponent;
};

// Usage
const ProtectedQuizPage = withAuth(QuizPage);

// ✅ Modern custom hook approach
const useAuth = () => {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const checkAuth = async () => {
      try {
        const userData = await getCurrentUser();
        setUser(userData);
      } catch (err) {
        setError(err instanceof Error ? err.message : 'Authentication failed');
      } finally {
        setLoading(false);
      }
    };

    checkAuth();
  }, []);

  const login = useCallback(async (credentials: LoginCredentials) => {
    setLoading(true);
    setError(null);
    
    try {
      const userData = await authenticateUser(credentials);
      setUser(userData);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Login failed');
      throw err;
    } finally {
      setLoading(false);
    }
  }, []);

  const logout = useCallback(async () => {
    try {
      await logoutUser();
      setUser(null);
    } catch (err) {
      console.error('Logout error:', err);
    }
  }, []);

  return {
    user,
    loading,
    error,
    login,
    logout,
    isAuthenticated: !!user
  };
};

// ✅ Modern component using hook
const ModernProtectedQuizPage: React.FC = () => {
  const { user, loading, error, isAuthenticated } = useAuth();

  if (loading) {
    return <AuthLoadingSkeleton />;
  }

  if (error) {
    return <AuthError error={error} />;
  }

  if (!isAuthenticated) {
    return <Navigate to="/login" replace />;
  }

  return <QuizPage user={user} />;
};
```

### **2. Render Props to Hooks Migration**

#### **Converting Render Props Pattern**
```typescript
// ❌ Legacy render props pattern
class DataProvider extends Component<
  { 
    url: string;
    children: (state: { data: any; loading: boolean; error: string | null }) => React.ReactNode;
  },
  { data: any; loading: boolean; error: string | null }
> {
  state = {
    data: null,
    loading: true,
    error: null
  };

  componentDidMount() {
    this.fetchData();
  }

  componentDidUpdate(prevProps: any) {
    if (prevProps.url !== this.props.url) {
      this.fetchData();
    }
  }

  fetchData = async () => {
    this.setState({ loading: true, error: null });
    
    try {
      const response = await fetch(this.props.url);
      if (!response.ok) {
        throw new Error('Network error');
      }
      const data = await response.json();
      this.setState({ data, loading: false });
    } catch (error) {
      this.setState({ error: error.message, loading: false });
    }
  };

  render() {
    return this.props.children(this.state);
  }
}

// Usage
<DataProvider url="/api/quiz/1">
  {({ data, loading, error }) => (
    <>
      {loading && <div>Loading...</div>}
      {error && <div>Error: {error}</div>}
      {data && <QuizDisplay quiz={data} />}
    </>
  )}
</DataProvider>

// ✅ Modern custom hook approach
const useApiData = <T>(url: string) => {
  const [data, setData] = useState<T | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchData = useCallback(async () => {
    setLoading(true);
    setError(null);
    
    try {
      const response = await fetch(url);
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }
      const result = await response.json();
      setData(result);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to fetch data');
    } finally {
      setLoading(false);
    }
  }, [url]);

  useEffect(() => {
    fetchData();
  }, [fetchData]);

  const refetch = useCallback(() => {
    fetchData();
  }, [fetchData]);

  return { data, loading, error, refetch };
};

// ✅ Modern component using hook
const ModernQuizLoader: React.FC<{ quizId: string }> = ({ quizId }) => {
  const { data: quiz, loading, error, refetch } = useApiData<Quiz>(`/api/quiz/${quizId}`);

  if (loading) {
    return <QuizLoadingSkeleton />;
  }

  if (error) {
    return <QuizError error={error} onRetry={refetch} />;
  }

  if (!quiz) {
    return <div>Quiz not found</div>;
  }

  return <QuizDisplay quiz={quiz} />;
};
```

## 🚀 Phase 3: Performance and Concurrent Features

### **1. Introducing Suspense Boundaries**

#### **Gradual Suspense Adoption**
```typescript
// ✅ Step 1: Add Suspense boundaries around existing components
const SuspenseWrapper: React.FC<{
  children: React.ReactNode;
  fallback?: React.ReactNode;
  errorFallback?: React.ComponentType<{ error: Error; retry: () => void }>;
}> = ({ 
  children, 
  fallback = <div>Loading...</div>,
  errorFallback: ErrorFallback = DefaultErrorFallback
}) => {
  return (
    <ErrorBoundary FallbackComponent={ErrorFallback}>
      <Suspense fallback={fallback}>
        {children}
      </Suspense>
    </ErrorBoundary>
  );
};

// ✅ Step 2: Wrap route components with Suspense
const AppRoutes: React.FC = () => {
  return (
    <Routes>
      <Route 
        path="/quiz/:id" 
        element={
          <SuspenseWrapper fallback={<QuizPageSkeleton />}>
            <QuizPage />
          </SuspenseWrapper>
        } 
      />
      
      <Route 
        path="/dashboard" 
        element={
          <SuspenseWrapper fallback={<DashboardSkeleton />}>
            <Dashboard />
          </SuspenseWrapper>
        } 
      />
    </Routes>
  );
};

// ✅ Step 3: Convert data fetching to Suspense-compatible patterns
const SuspenseQuizLoader: React.FC<{ quizId: string }> = ({ quizId }) => {
  // Use a Suspense-compatible data fetching library
  const quiz = useSuspenseQuery({
    queryKey: ['quiz', quizId],
    queryFn: () => fetchQuiz(quizId)
  });

  return <QuizDisplay quiz={quiz} />;
};
```

### **2. Adding Concurrent Features**

#### **Incremental Concurrent Features Adoption**
```typescript
// ✅ Step 1: Add transitions for non-urgent updates
const ConcurrentSearchResults: React.FC = () => {
  const [searchTerm, setSearchTerm] = useState('');
  const [results, setResults] = useState<Quiz[]>([]);
  const [isPending, startTransition] = useTransition();

  // Urgent update - immediate response to user input
  const handleSearchChange = (value: string) => {
    setSearchTerm(value);
    
    // Non-urgent update - search results can be deferred
    startTransition(() => {
      const filtered = performExpensiveSearch(value);
      setResults(filtered);
    });
  };

  return (
    <div>
      <input
        value={searchTerm}
        onChange={(e) => handleSearchChange(e.target.value)}
        placeholder="Search quizzes..."
      />
      
      {isPending && <div className="search-pending">Searching...</div>}
      
      <SearchResultsList results={results} />
    </div>
  );
};

// ✅ Step 2: Use deferred values for expensive computations
const DeferredAnalytics: React.FC<{ data: QuizData[] }> = ({ data }) => {
  const [timeRange, setTimeRange] = useState('7d');
  const deferredTimeRange = useDeferredValue(timeRange);

  // Expensive computation uses deferred value
  const analytics = useMemo(() => {
    return calculateExpensiveAnalytics(data, deferredTimeRange);
  }, [data, deferredTimeRange]);

  return (
    <div>
      <select value={timeRange} onChange={(e) => setTimeRange(e.target.value)}>
        <option value="24h">Last 24 Hours</option>
        <option value="7d">Last 7 Days</option>
        <option value="30d">Last 30 Days</option>
      </select>
      
      <AnalyticsChart data={analytics} />
    </div>
  );
};
```

## 📊 Migration Testing Strategy

### **1. Parallel Testing Approach**

#### **Side-by-Side Component Testing**
```typescript
// ✅ A/B testing during migration
const useFeatureFlag = (flagName: string): boolean => {
  // In production, this would connect to a feature flag service
  const flags = {
    'modernQuizPlayer': process.env.NODE_ENV === 'development' ? true : false,
    'concurrentSearch': false,
    'suspenseDataFetching': false
  };
  
  return flags[flagName] || false;
};

const ConditionalQuizPlayer: React.FC<QuizPlayerProps> = (props) => {
  const useModernVersion = useFeatureFlag('modernQuizPlayer');
  
  if (useModernVersion) {
    return (
      <ErrorBoundary fallback={<LegacyQuizPlayer {...props} />}>
        <ModernQuizPlayer {...props} />
      </ErrorBoundary>
    );
  }
  
  return <LegacyQuizPlayer {...props} />;
};

// ✅ Performance comparison testing
const usePerformanceComparison = (componentName: string) => {
  const startTime = useRef(performance.now());
  const [metrics, setMetrics] = useState<{
    renderTime: number;
    memoryUsage: number;
  } | null>(null);

  useEffect(() => {
    const endTime = performance.now();
    const renderTime = endTime - startTime.current;
    
    // Log performance metrics for comparison
    const memoryUsage = (performance as any).memory?.usedJSHeapSize || 0;
    
    setMetrics({ renderTime, memoryUsage });
    
    // Send to analytics
    if (window.gtag) {
      window.gtag('event', 'component_performance', {
        component_name: componentName,
        render_time: renderTime,
        memory_usage: memoryUsage
      });
    }
  });

  return metrics;
};

// Usage in migrated components
const ModernQuizPlayer: React.FC<QuizPlayerProps> = (props) => {
  const metrics = usePerformanceComparison('ModernQuizPlayer');
  
  // Component implementation...
  
  return (
    <div className="modern-quiz-player">
      {/* Component content */}
      {process.env.NODE_ENV === 'development' && metrics && (
        <div className="perf-metrics">
          Render: {metrics.renderTime.toFixed(2)}ms
        </div>
      )}
    </div>
  );
};
```

### **2. Automated Migration Testing**

#### **Migration Validation Tests**
```typescript
// ✅ Automated tests to validate migration success
describe('Quiz Player Migration Validation', () => {
  const testProps: QuizPlayerProps = {
    quizId: 'test-quiz-1',
    timeLimit: 300,
    onComplete: jest.fn()
  };

  it('should maintain functional parity between legacy and modern versions', async () => {
    // Test legacy version
    const { unmount: unmountLegacy } = render(<LegacyQuizPlayer {...testProps} />);
    
    await waitFor(() => {
      expect(screen.getByText('React Fundamentals')).toBeInTheDocument();
    });
    
    const legacyTimerValue = screen.getByTestId('timer').textContent;
    const legacyQuestionText = screen.getByTestId('question').textContent;
    
    unmountLegacy();

    // Test modern version
    render(<ModernQuizPlayer {...testProps} />);
    
    await waitFor(() => {
      expect(screen.getByText('React Fundamentals')).toBeInTheDocument();
    });
    
    const modernTimerValue = screen.getByTestId('timer').textContent;
    const modernQuestionText = screen.getByTestId('question').textContent;

    // Verify functional equivalence
    expect(modernTimerValue).toBe(legacyTimerValue);
    expect(modernQuestionText).toBe(legacyQuestionText);
  });

  it('should handle user interactions consistently', async () => {
    const user = userEvent.setup();
    
    render(<ModernQuizPlayer {...testProps} />);
    
    await waitFor(() => {
      expect(screen.getByText('What is React?')).toBeInTheDocument();
    });

    // Test answer selection
    await user.click(screen.getByText('Library'));
    
    expect(screen.getByLabelText('Library')).toBeChecked();

    // Test navigation
    await user.click(screen.getByText('Next'));
    
    await waitFor(() => {
      expect(screen.getByText('What is JSX?')).toBeInTheDocument();
    });
  });

  it('should perform better than legacy version', async () => {
    const legacyStartTime = performance.now();
    const { unmount: unmountLegacy } = render(<LegacyQuizPlayer {...testProps} />);
    
    await waitFor(() => {
      expect(screen.getByText('React Fundamentals')).toBeInTheDocument();
    });
    
    const legacyRenderTime = performance.now() - legacyStartTime;
    unmountLegacy();

    const modernStartTime = performance.now();
    render(<ModernQuizPlayer {...testProps} />);
    
    await waitFor(() => {
      expect(screen.getByText('React Fundamentals')).toBeInTheDocument();
    });
    
    const modernRenderTime = performance.now() - modernStartTime;

    // Modern version should be faster or at least not significantly slower
    expect(modernRenderTime).toBeLessThanOrEqual(legacyRenderTime * 1.1);
  });
});
```

## 🚦 Migration Rollout Strategy

### **1. Gradual Rollout Plan**

#### **Feature Flag Based Rollout**
```typescript
// ✅ Progressive rollout configuration
interface RolloutConfig {
  componentName: string;
  rolloutPercentage: number;
  enabledForRoles: string[];
  enabledEnvironments: string[];
  rollbackThreshold: {
    errorRate: number;
    performanceDegradation: number;
  };
}

const migrationConfig: RolloutConfig[] = [
  {
    componentName: 'QuizPlayer',
    rolloutPercentage: 10, // Start with 10% of users
    enabledForRoles: ['developer', 'admin'],
    enabledEnvironments: ['development', 'staging'],
    rollbackThreshold: {
      errorRate: 0.05, // 5% error rate triggers rollback
      performanceDegradation: 0.2 // 20% performance degradation triggers rollback
    }
  }
];

const useMigrationRollout = (componentName: string): boolean => {
  const { user } = useAuth();
  const environment = process.env.NODE_ENV;
  
  const config = migrationConfig.find(c => c.componentName === componentName);
  
  if (!config) return false;
  
  // Check environment
  if (!config.enabledEnvironments.includes(environment)) {
    return false;
  }
  
  // Check user role
  if (user && config.enabledForRoles.includes(user.role)) {
    return true;
  }
  
  // Check rollout percentage
  const userHash = hashUserId(user?.id || 'anonymous');
  return (userHash % 100) < config.rolloutPercentage;
};

// ✅ Monitoring and rollback mechanism
const useRolloutMonitoring = (componentName: string) => {
  const [metrics, setMetrics] = useState<{
    errorRate: number;
    averageRenderTime: number;
    userSatisfaction: number;
  } | null>(null);

  useEffect(() => {
    const monitoringInterval = setInterval(async () => {
      const currentMetrics = await fetchComponentMetrics(componentName);
      setMetrics(currentMetrics);
      
      const config = migrationConfig.find(c => c.componentName === componentName);
      if (config && currentMetrics) {
        // Check for rollback conditions
        if (currentMetrics.errorRate > config.rollbackThreshold.errorRate) {
          console.warn(`High error rate detected for ${componentName}, consider rollback`);
          // Trigger alert to development team
        }
      }
    }, 60000); // Check every minute

    return () => clearInterval(monitoringInterval);
  }, [componentName]);

  return metrics;
};
```

## 🔗 Navigation

**← Previous:** [Testing Strategies](./testing-strategies.md)  
**→ Next:** [README.md](./README.md)

---

*Comprehensive migration guide for modernizing React applications with advanced patterns*