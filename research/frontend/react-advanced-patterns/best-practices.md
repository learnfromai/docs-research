# Best Practices - React Advanced Patterns

## 🎯 Overview

This document outlines industry-standard best practices for React advanced patterns, focusing on maintainable, performant, and scalable code suitable for EdTech applications and international development teams.

## 🔧 Custom Hooks Best Practices

### **1. Single Responsibility Principle**

#### ✅ Good: Focused Hook
```typescript
// ✅ Single responsibility - only handles API calls
const useApi = <T>(url: string) => {
  const [data, setData] = useState<T | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const fetchData = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const response = await fetch(url);
      if (!response.ok) throw new Error('Network error');
      const result = await response.json();
      setData(result);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Unknown error');
    } finally {
      setLoading(false);
    }
  }, [url]);

  return { data, loading, error, refetch: fetchData };
};
```

#### ❌ Bad: Multiple Responsibilities
```typescript
// ❌ Does too many things - API calls, local storage, validation
const useEverything = (url: string, storageKey: string) => {
  // ... handles API calls
  // ... manages local storage
  // ... validates data
  // ... formats display
  // This violates single responsibility principle
};
```

### **2. Proper Dependency Management**

#### ✅ Good: Optimized Dependencies
```typescript
const useDebounce = <T>(value: T, delay: number) => {
  const [debouncedValue, setDebouncedValue] = useState(value);

  useEffect(() => {
    const handler = setTimeout(() => {
      setDebouncedValue(value);
    }, delay);

    return () => {
      clearTimeout(handler);
    };
  }, [value, delay]); // Only re-run when value or delay changes

  return debouncedValue;
};
```

#### ❌ Bad: Missing or Excessive Dependencies
```typescript
// ❌ Missing dependencies - could cause stale closures
useEffect(() => {
  fetchUserData(userId);
}, []); // Missing userId dependency

// ❌ Excessive dependencies - causes unnecessary re-renders
useEffect(() => {
  console.log('Component rendered');
}, [props]); // Don't depend on entire props object
```

### **3. Custom Hook Naming and Structure**

#### ✅ Good: Clear Naming Convention
```typescript
// ✅ Clear prefix, descriptive name, typed return
const useQuizProgress = (quizId: string) => {
  // Implementation
  return {
    progress: number,
    isComplete: boolean,
    updateProgress: (questionId: string) => void,
    resetProgress: () => void
  } as const; // Use 'as const' for better type inference
};

// ✅ Boolean hooks should start with 'is', 'has', 'can'
const useIsOnline = () => {
  const [isOnline, setIsOnline] = useState(navigator.onLine);
  
  useEffect(() => {
    const handleOnline = () => setIsOnline(true);
    const handleOffline = () => setIsOnline(false);
    
    window.addEventListener('online', handleOnline);
    window.addEventListener('offline', handleOffline);
    
    return () => {
      window.removeEventListener('online', handleOnline);
      window.removeEventListener('offline', handleOffline);
    };
  }, []);
  
  return isOnline;
};
```

## 🔄 Context API Best Practices

### **1. Context Splitting Strategy**

#### ✅ Good: Split Contexts by Concern
```typescript
// ✅ Separate contexts for different concerns
// auth-context.tsx
interface AuthContextValue {
  user: User | null;
  login: (credentials: LoginCredentials) => Promise<void>;
  logout: () => void;
}

// theme-context.tsx
interface ThemeContextValue {
  theme: 'light' | 'dark';
  toggleTheme: () => void;
}

// quiz-context.tsx
interface QuizContextValue {
  currentQuiz: Quiz | null;
  progress: QuizProgress;
  submitAnswer: (answer: Answer) => void;
}
```

#### ❌ Bad: Monolithic Context
```typescript
// ❌ Everything in one context - causes unnecessary re-renders
interface AppContextValue {
  user: User | null;
  theme: string;
  currentQuiz: Quiz | null;
  notifications: Notification[];
  settings: UserSettings;
  // ... too many responsibilities
}
```

### **2. Context Provider Composition**

#### ✅ Good: Composable Providers
```typescript
// ✅ Composable provider pattern
const AppProviders: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  return (
    <AuthProvider>
      <ThemeProvider>
        <NotificationProvider>
          <QueryClientProvider client={queryClient}>
            {children}
          </QueryClientProvider>
        </NotificationProvider>
      </ThemeProvider>
    </AuthProvider>
  );
};

// Usage
const App = () => (
  <AppProviders>
    <Router>
      <Routes>
        {/* Your routes */}
      </Routes>
    </Router>
  </AppProviders>
);
```

### **3. Context Performance Optimization**

#### ✅ Good: Memoized Context Values
```typescript
const QuizProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [state, dispatch] = useReducer(quizReducer, initialState);
  
  // ✅ Memoize actions to prevent unnecessary re-renders
  const actions = useMemo(() => ({
    startQuiz: (quizId: string) => dispatch({ type: 'START_QUIZ', payload: quizId }),
    submitAnswer: (answer: Answer) => dispatch({ type: 'SUBMIT_ANSWER', payload: answer }),
    completeQuiz: () => dispatch({ type: 'COMPLETE_QUIZ' })
  }), []);

  // ✅ Memoize the entire context value
  const contextValue = useMemo(() => ({
    ...state,
    ...actions
  }), [state, actions]);

  return (
    <QuizContext.Provider value={contextValue}>
      {children}
    </QuizContext.Provider>
  );
};
```

## ⚡ Performance Optimization Best Practices

### **1. Memoization Strategies**

#### ✅ Good: Strategic Memoization
```typescript
// ✅ Memoize expensive calculations
const ExpensiveComponent: React.FC<{ data: ComplexData[] }> = ({ data }) => {
  const processedData = useMemo(() => {
    // Expensive operation
    return data
      .filter(item => item.isActive)
      .sort((a, b) => a.priority - b.priority)
      .map(item => ({
        ...item,
        formattedDate: formatDate(item.createdAt),
        calculatedScore: calculateComplexScore(item)
      }));
  }, [data]); // Only recalculate when data changes

  const handleItemClick = useCallback((itemId: string) => {
    // Event handler that doesn't change on every render
    onItemSelect(itemId);
  }, [onItemSelect]);

  return (
    <div>
      {processedData.map(item => (
        <ItemCard
          key={item.id}
          item={item}
          onClick={handleItemClick}
        />
      ))}
    </div>
  );
};

// ✅ Proper component memoization
const ItemCard = memo<ItemCardProps>(({ item, onClick }) => {
  return (
    <div onClick={() => onClick(item.id)}>
      <h3>{item.title}</h3>
      <p>{item.formattedDate}</p>
      <span>Score: {item.calculatedScore}</span>
    </div>
  );
}, (prevProps, nextProps) => {
  // Custom comparison for complex objects
  return (
    prevProps.item.id === nextProps.item.id &&
    prevProps.item.updatedAt === nextProps.item.updatedAt
  );
});
```

#### ❌ Bad: Over-memoization
```typescript
// ❌ Unnecessary memoization for simple values
const SimpleComponent = ({ name }) => {
  const greeting = useMemo(() => `Hello, ${name}!`, [name]); // Unnecessary
  const isLongName = useMemo(() => name.length > 10, [name]); // Unnecessary
  
  return <div>{greeting}</div>;
};
```

### **2. Code Splitting Best Practices**

#### ✅ Good: Strategic Code Splitting
```typescript
// ✅ Route-level code splitting
const Dashboard = lazy(() => import('./pages/Dashboard'));
const QuizManager = lazy(() => import('./pages/QuizManager'));
const StudentProgress = lazy(() => import('./pages/StudentProgress'));

// ✅ Feature-based splitting
const AdvancedEditor = lazy(() => 
  import('./components/AdvancedEditor').then(module => ({
    default: module.AdvancedEditor
  }))
);

// ✅ Conditional loading
const AdminPanel = lazy(() => import('./components/AdminPanel'));

const App = () => {
  const { user } = useAuth();
  
  return (
    <Suspense fallback={<LoadingSpinner />}>
      <Routes>
        <Route path="/dashboard" element={<Dashboard />} />
        <Route path="/quiz" element={<QuizManager />} />
        {user?.role === 'admin' && (
          <Route path="/admin" element={<AdminPanel />} />
        )}
      </Routes>
    </Suspense>
  );
};
```

### **3. Bundle Optimization**

#### ✅ Good: Optimized Imports
```typescript
// ✅ Tree-shakable imports
import { debounce } from 'lodash-es/debounce';
import { format } from 'date-fns/format';

// ✅ Selective imports from UI libraries
import { Button, TextField, Chip } from '@mui/material';

// ✅ Dynamic imports for heavy libraries
const loadChartLibrary = async () => {
  const { Chart } = await import('chart.js');
  return Chart;
};
```

#### ❌ Bad: Inefficient Imports
```typescript
// ❌ Imports entire libraries
import * as _ from 'lodash';
import * as MUI from '@mui/material';

// ❌ Default imports from large libraries
import moment from 'moment'; // Use date-fns instead
```

## 🧪 Testing Best Practices

### **1. Hook Testing Patterns**

#### ✅ Good: Comprehensive Hook Testing
```typescript
// ✅ Test all hook behaviors
describe('useFormValidation', () => {
  const mockValidationRules = {
    email: (value: string) => /\S+@\S+\.\S+/.test(value) || 'Invalid email',
    password: (value: string) => value.length >= 8 || 'Password too short'
  };

  it('should validate fields correctly', () => {
    const { result } = renderHook(() => 
      useFormValidation(mockValidationRules)
    );

    act(() => {
      result.current.validateField('email', 'invalid-email');
    });

    expect(result.current.errors.email).toBe('Invalid email');
  });

  it('should clear errors when field becomes valid', () => {
    const { result } = renderHook(() => 
      useFormValidation(mockValidationRules)
    );

    act(() => {
      result.current.validateField('email', 'invalid-email');
    });
    
    expect(result.current.errors.email).toBe('Invalid email');

    act(() => {
      result.current.validateField('email', 'valid@email.com');
    });

    expect(result.current.errors.email).toBeUndefined();
  });

  it('should handle async validation', async () => {
    const asyncRule = async (value: string) => {
      // Simulate API call
      await new Promise(resolve => setTimeout(resolve, 100));
      return value === 'taken@email.com' ? 'Email already taken' : null;
    };

    const { result } = renderHook(() => 
      useFormValidation({ email: asyncRule })
    );

    await act(async () => {
      await result.current.validateField('email', 'taken@email.com');
    });

    expect(result.current.errors.email).toBe('Email already taken');
  });
});
```

### **2. Context Testing Patterns**

#### ✅ Good: Context Integration Testing
```typescript
// ✅ Test context provider behavior
const renderWithAuthProvider = (ui: React.ReactElement, options = {}) => {
  const AuthWrapper: React.FC<{ children: React.ReactNode }> = ({ children }) => (
    <AuthProvider>{children}</AuthProvider>
  );

  return render(ui, { wrapper: AuthWrapper, ...options });
};

describe('AuthProvider Integration', () => {
  beforeEach(() => {
    // Clear any stored auth state
    localStorage.clear();
    jest.clearAllMocks();
  });

  it('should provide login functionality', async () => {
    const TestComponent = () => {
      const { login, user, isLoading } = useAuth();
      
      return (
        <div>
          {isLoading && <div data-testid="loading">Loading...</div>}
          {user && <div data-testid="user-name">{user.name}</div>}
          <button 
            onClick={() => login('test@example.com', 'password')}
            data-testid="login-button"
          >
            Login
          </button>
        </div>
      );
    };

    const mockUser = { id: '1', name: 'John Doe', email: 'test@example.com' };
    
    // Mock successful API response
    (global.fetch as jest.Mock).mockResolvedValueOnce({
      ok: true,
      json: async () => mockUser
    });

    renderWithAuthProvider(<TestComponent />);

    const loginButton = screen.getByTestId('login-button');
    fireEvent.click(loginButton);

    // Should show loading state
    expect(screen.getByTestId('loading')).toBeInTheDocument();

    // Wait for login to complete
    await waitFor(() => {
      expect(screen.getByTestId('user-name')).toHaveTextContent('John Doe');
    });

    // Should store auth token
    expect(localStorage.getItem('authToken')).toBe(mockUser.token);
  });
});
```

## 🔒 Error Handling Best Practices

### **1. Error Boundaries**

#### ✅ Good: Comprehensive Error Boundaries
```typescript
// ✅ Feature-specific error boundary
class QuizErrorBoundary extends Component<
  { children: ReactNode; fallback?: ComponentType<{ error: Error; resetError: () => void }> },
  { hasError: boolean; error: Error | null }
> {
  constructor(props: any) {
    super(props);
    this.state = { hasError: false, error: null };
  }

  static getDerivedStateFromError(error: Error) {
    return { hasError: true, error };
  }

  componentDidCatch(error: Error, errorInfo: ErrorInfo) {
    // Log error to monitoring service
    console.error('Quiz Error:', error, errorInfo);
    
    // Report to error tracking service
    if (window.gtag) {
      window.gtag('event', 'exception', {
        description: error.message,
        fatal: false
      });
    }
  }

  resetError = () => {
    this.setState({ hasError: false, error: null });
  };

  render() {
    if (this.state.hasError) {
      const FallbackComponent = this.props.fallback || DefaultErrorFallback;
      return (
        <FallbackComponent 
          error={this.state.error!} 
          resetError={this.resetError} 
        />
      );
    }

    return this.props.children;
  }
}

// ✅ Usage with specific fallbacks
const QuizSection = () => (
  <QuizErrorBoundary fallback={QuizErrorFallback}>
    <QuizContent />
  </QuizErrorBoundary>
);
```

### **2. Async Error Handling**

#### ✅ Good: Robust Async Error Handling
```typescript
// ✅ Comprehensive async error handling
const useAsyncOperation = <T>() => {
  const [state, setState] = useState<{
    data: T | null;
    loading: boolean;
    error: string | null;
  }>({
    data: null,
    loading: false,
    error: null
  });

  const execute = useCallback(async (asyncFunction: () => Promise<T>) => {
    setState(prev => ({ ...prev, loading: true, error: null }));
    
    try {
      const result = await asyncFunction();
      setState({ data: result, loading: false, error: null });
      return { success: true, data: result };
    } catch (error) {
      const errorMessage = getErrorMessage(error);
      setState({ data: null, loading: false, error: errorMessage });
      
      // Log error for debugging
      console.error('Async operation failed:', error);
      
      return { success: false, error: errorMessage };
    }
  }, []);

  const reset = useCallback(() => {
    setState({ data: null, loading: false, error: null });
  }, []);

  return { ...state, execute, reset };
};

// ✅ Error message standardization
const getErrorMessage = (error: unknown): string => {
  if (error instanceof Error) {
    return error.message;
  }
  
  if (typeof error === 'string') {
    return error;
  }
  
  if (error && typeof error === 'object' && 'message' in error) {
    return String(error.message);
  }
  
  return 'An unexpected error occurred';
};
```

## 🌐 Accessibility Best Practices

### **1. Keyboard Navigation**

#### ✅ Good: Keyboard Accessible Components
```typescript
// ✅ Proper keyboard navigation for quiz components
const QuizQuestion: React.FC<QuizQuestionProps> = ({ 
  question, 
  selectedAnswer, 
  onAnswerSelect 
}) => {
  const [focusedOption, setFocusedOption] = useState<number | null>(null);

  const handleKeyDown = (event: KeyboardEvent<HTMLDivElement>) => {
    const optionCount = question.options.length;
    
    switch (event.key) {
      case 'ArrowDown':
        event.preventDefault();
        setFocusedOption(prev => 
          prev === null ? 0 : (prev + 1) % optionCount
        );
        break;
        
      case 'ArrowUp':
        event.preventDefault();
        setFocusedOption(prev => 
          prev === null ? optionCount - 1 : (prev - 1 + optionCount) % optionCount
        );
        break;
        
      case 'Enter':
      case ' ':
        event.preventDefault();
        if (focusedOption !== null) {
          onAnswerSelect(focusedOption);
        }
        break;
        
      case 'Escape':
        setFocusedOption(null);
        break;
    }
  };

  return (
    <div 
      className="quiz-question"
      onKeyDown={handleKeyDown}
      tabIndex={0}
      role="radiogroup"
      aria-labelledby={`question-${question.id}`}
    >
      <h3 id={`question-${question.id}`}>{question.text}</h3>
      <div className="options">
        {question.options.map((option, index) => (
          <button
            key={index}
            className={`option ${selectedAnswer === index ? 'selected' : ''}`}
            onClick={() => onAnswerSelect(index)}
            onFocus={() => setFocusedOption(index)}
            onBlur={() => setFocusedOption(null)}
            role="radio"
            aria-checked={selectedAnswer === index}
            aria-describedby={`option-${question.id}-${index}`}
          >
            <span id={`option-${question.id}-${index}`}>{option}</span>
          </button>
        ))}
      </div>
    </div>
  );
};
```

### **2. Screen Reader Support**

#### ✅ Good: Screen Reader Optimized
```typescript
// ✅ Progress indicators with screen reader support
const QuizProgress: React.FC<{ current: number; total: number }> = ({ 
  current, 
  total 
}) => {
  const percentage = Math.round((current / total) * 100);
  
  return (
    <div className="quiz-progress">
      <div className="progress-bar" role="progressbar" 
           aria-valuenow={current} 
           aria-valuemin={0} 
           aria-valuemax={total}
           aria-label={`Question ${current} of ${total}`}>
        <div 
          className="progress-fill" 
          style={{ width: `${percentage}%` }}
        />
      </div>
      <span className="progress-text" aria-live="polite">
        Question {current} of {total} ({percentage}% complete)
      </span>
    </div>
  );
};

// ✅ Loading states with proper announcements
const LoadingSpinner: React.FC<{ message?: string }> = ({ 
  message = 'Loading...' 
}) => (
  <div className="loading-spinner" role="status" aria-live="polite">
    <div className="spinner" aria-hidden="true" />
    <span className="sr-only">{message}</span>
  </div>
);
```

## 📱 Mobile-First Best Practices

### **1. Touch-Friendly Interactions**

#### ✅ Good: Mobile-Optimized Components
```typescript
// ✅ Touch-friendly quiz interface
const MobileQuizOption: React.FC<{
  option: string;
  index: number;
  isSelected: boolean;
  onSelect: (index: number) => void;
}> = ({ option, index, isSelected, onSelect }) => {
  const [isTouched, setIsTouched] = useState(false);

  return (
    <button
      className={`mobile-option ${isSelected ? 'selected' : ''} ${isTouched ? 'touched' : ''}`}
      onClick={() => onSelect(index)}
      onTouchStart={() => setIsTouched(true)}
      onTouchEnd={() => setIsTouched(false)}
      onTouchCancel={() => setIsTouched(false)}
      style={{
        minHeight: '48px', // Minimum touch target size
        padding: '12px 16px',
        marginBottom: '8px'
      }}
    >
      <span className="option-letter">{String.fromCharCode(65 + index)}.</span>
      <span className="option-text">{option}</span>
      {isSelected && (
        <span className="checkmark" aria-hidden="true">✓</span>
      )}
    </button>
  );
};
```

### **2. Responsive Design Patterns**

#### ✅ Good: Container Query Patterns
```typescript
// ✅ Responsive quiz layout using container queries
const ResponsiveQuizContainer: React.FC<{ children: React.ReactNode }> = ({ 
  children 
}) => {
  const containerRef = useRef<HTMLDivElement>(null);
  const [containerWidth, setContainerWidth] = useState(0);

  useEffect(() => {
    const observer = new ResizeObserver(entries => {
      for (const entry of entries) {
        setContainerWidth(entry.contentRect.width);
      }
    });

    if (containerRef.current) {
      observer.observe(containerRef.current);
    }

    return () => observer.disconnect();
  }, []);

  const getLayoutClass = () => {
    if (containerWidth < 400) return 'quiz-mobile';
    if (containerWidth < 768) return 'quiz-tablet';
    return 'quiz-desktop';
  };

  return (
    <div 
      ref={containerRef}
      className={`quiz-container ${getLayoutClass()}`}
    >
      {children}
    </div>
  );
};
```

## 🔗 Navigation

**← Previous:** [Implementation Guide](./implementation-guide.md)  
**→ Next:** [Comparison Analysis](./comparison-analysis.md)

---

*Best practices for building maintainable and scalable React applications with advanced patterns*