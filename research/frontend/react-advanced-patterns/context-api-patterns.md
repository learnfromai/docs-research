# Context API Advanced Patterns

## 🎯 Overview

Comprehensive guide to advanced Context API patterns for scalable state management in EdTech applications. This document covers provider composition, performance optimization, and real-world implementation strategies.

## 🔧 Context API Fundamentals

### **1. Basic Context Pattern**

#### **Type-Safe Context Creation**
```typescript
// ✅ Type-safe context with proper error handling
interface User {
  id: string;
  name: string;
  email: string;
  role: 'student' | 'teacher' | 'admin';
  preferences: UserPreferences;
}

interface AuthContextValue {
  user: User | null;
  isLoading: boolean;
  error: string | null;
  login: (email: string, password: string) => Promise<void>;
  logout: () => void;
  updateProfile: (updates: Partial<User>) => Promise<void>;
}

// Create context with undefined default to force provider usage
const AuthContext = createContext<AuthContextValue | undefined>(undefined);

// Custom hook with proper error handling
export const useAuth = (): AuthContextValue => {
  const context = useContext(AuthContext);
  
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  
  return context;
};

// Display name for better debugging
AuthContext.displayName = 'AuthContext';
```

#### **Provider Implementation with useReducer**
```typescript
// ✅ Robust provider implementation
interface AuthState {
  user: User | null;
  isLoading: boolean;
  error: string | null;
}

type AuthAction =
  | { type: 'AUTH_START' }
  | { type: 'AUTH_SUCCESS'; payload: User }
  | { type: 'AUTH_ERROR'; payload: string }
  | { type: 'AUTH_LOGOUT' }
  | { type: 'UPDATE_USER'; payload: Partial<User> }
  | { type: 'CLEAR_ERROR' };

const authReducer = (state: AuthState, action: AuthAction): AuthState => {
  switch (action.type) {
    case 'AUTH_START':
      return {
        ...state,
        isLoading: true,
        error: null
      };
      
    case 'AUTH_SUCCESS':
      return {
        user: action.payload,
        isLoading: false,
        error: null
      };
      
    case 'AUTH_ERROR':
      return {
        ...state,
        isLoading: false,
        error: action.payload
      };
      
    case 'AUTH_LOGOUT':
      return {
        user: null,
        isLoading: false,
        error: null
      };
      
    case 'UPDATE_USER':
      return {
        ...state,
        user: state.user ? { ...state.user, ...action.payload } : null
      };
      
    case 'CLEAR_ERROR':
      return {
        ...state,
        error: null
      };
      
    default:
      return state;
  }
};

export const AuthProvider: React.FC<{ children: React.ReactNode }> = ({ 
  children 
}) => {
  const [state, dispatch] = useReducer(authReducer, {
    user: null,
    isLoading: false,
    error: null
  });

  // Memoize actions to prevent unnecessary re-renders
  const login = useCallback(async (email: string, password: string) => {
    dispatch({ type: 'AUTH_START' });
    
    try {
      const response = await fetch('/api/auth/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password })
      });
      
      if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.message || 'Login failed');
      }
      
      const userData = await response.json();
      
      // Store token securely
      localStorage.setItem('authToken', userData.token);
      
      dispatch({ type: 'AUTH_SUCCESS', payload: userData.user });
    } catch (error) {
      dispatch({ 
        type: 'AUTH_ERROR', 
        payload: error instanceof Error ? error.message : 'Login failed' 
      });
    }
  }, []);

  const logout = useCallback(async () => {
    try {
      await fetch('/api/auth/logout', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${localStorage.getItem('authToken')}`
        }
      });
    } catch (error) {
      console.error('Logout error:', error);
    } finally {
      localStorage.removeItem('authToken');
      dispatch({ type: 'AUTH_LOGOUT' });
    }
  }, []);

  const updateProfile = useCallback(async (updates: Partial<User>) => {
    if (!state.user) return;
    
    try {
      const response = await fetch('/api/users/profile', {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${localStorage.getItem('authToken')}`
        },
        body: JSON.stringify(updates)
      });
      
      if (!response.ok) {
        throw new Error('Profile update failed');
      }
      
      dispatch({ type: 'UPDATE_USER', payload: updates });
    } catch (error) {
      dispatch({ 
        type: 'AUTH_ERROR', 
        payload: error instanceof Error ? error.message : 'Update failed' 
      });
    }
  }, [state.user]);

  // Auto-restore authentication on mount
  useEffect(() => {
    const token = localStorage.getItem('authToken');
    if (token) {
      // Validate token and restore user state
      dispatch({ type: 'AUTH_START' });
      
      fetch('/api/auth/verify', {
        headers: {
          'Authorization': `Bearer ${token}`
        }
      })
      .then(response => {
        if (response.ok) {
          return response.json();
        }
        throw new Error('Token validation failed');
      })
      .then(userData => {
        dispatch({ type: 'AUTH_SUCCESS', payload: userData });
      })
      .catch(() => {
        localStorage.removeItem('authToken');
        dispatch({ type: 'AUTH_LOGOUT' });
      });
    }
  }, []);

  // Memoize the context value to prevent unnecessary re-renders
  const contextValue = useMemo(() => ({
    ...state,
    login,
    logout,
    updateProfile
  }), [state, login, logout, updateProfile]);

  return (
    <AuthContext.Provider value={contextValue}>
      {children}
    </AuthContext.Provider>
  );
};
```

## 🏗️ Advanced Context Patterns

### **1. Context Splitting Strategy**

#### **Separate Read and Write Contexts**
```typescript
// ✅ Split contexts for better performance
interface QuizState {
  currentQuiz: Quiz | null;
  questions: Question[];
  answers: Record<string, Answer>;
  progress: QuizProgress;
  timeRemaining: number;
}

interface QuizActions {
  loadQuiz: (quizId: string) => Promise<void>;
  submitAnswer: (questionId: string, answer: Answer) => void;
  nextQuestion: () => void;
  previousQuestion: () => void;
  completeQuiz: () => Promise<void>;
}

// Separate contexts for state and actions
const QuizStateContext = createContext<QuizState | undefined>(undefined);
const QuizActionsContext = createContext<QuizActions | undefined>(undefined);

// Separate hooks for state and actions
export const useQuizState = (): QuizState => {
  const context = useContext(QuizStateContext);
  if (!context) {
    throw new Error('useQuizState must be used within QuizProvider');
  }
  return context;
};

export const useQuizActions = (): QuizActions => {
  const context = useContext(QuizActionsContext);
  if (!context) {
    throw new Error('useQuizActions must be used within QuizProvider');
  }
  return context;
};

// Provider that creates both contexts
export const QuizProvider: React.FC<{ children: React.ReactNode }> = ({ 
  children 
}) => {
  const [state, dispatch] = useReducer(quizReducer, initialQuizState);

  // Actions object is stable (won't cause re-renders)
  const actions = useMemo(() => ({
    loadQuiz: async (quizId: string) => {
      dispatch({ type: 'LOAD_QUIZ_START' });
      try {
        const quiz = await fetchQuiz(quizId);
        dispatch({ type: 'LOAD_QUIZ_SUCCESS', payload: quiz });
      } catch (error) {
        dispatch({ type: 'LOAD_QUIZ_ERROR', payload: error.message });
      }
    },
    
    submitAnswer: (questionId: string, answer: Answer) => {
      dispatch({ type: 'SUBMIT_ANSWER', payload: { questionId, answer } });
    },
    
    nextQuestion: () => {
      dispatch({ type: 'NEXT_QUESTION' });
    },
    
    previousQuestion: () => {
      dispatch({ type: 'PREVIOUS_QUESTION' });
    },
    
    completeQuiz: async () => {
      dispatch({ type: 'COMPLETE_QUIZ_START' });
      try {
        const results = await submitQuizResults(state.answers);
        dispatch({ type: 'COMPLETE_QUIZ_SUCCESS', payload: results });
      } catch (error) {
        dispatch({ type: 'COMPLETE_QUIZ_ERROR', payload: error.message });
      }
    }
  }), [state.answers]); // Only depend on what's actually used

  return (
    <QuizStateContext.Provider value={state}>
      <QuizActionsContext.Provider value={actions}>
        {children}
      </QuizActionsContext.Provider>
    </QuizStateContext.Provider>
  );
};
```

### **2. Compound Context Pattern**

#### **Multiple Related Contexts**
```typescript
// ✅ Theme context for UI consistency
interface ThemeContextValue {
  theme: 'light' | 'dark' | 'auto';
  colors: ColorPalette;
  typography: Typography;
  toggleTheme: () => void;
  setTheme: (theme: 'light' | 'dark' | 'auto') => void;
}

const ThemeContext = createContext<ThemeContextValue | undefined>(undefined);

export const useTheme = () => {
  const context = useContext(ThemeContext);
  if (!context) {
    throw new Error('useTheme must be used within ThemeProvider');
  }
  return context;
};

// ✅ Settings context for user preferences
interface SettingsContextValue {
  language: string;
  timezone: string;
  notifications: NotificationSettings;
  accessibility: AccessibilitySettings;
  updateSetting: <K extends keyof SettingsContextValue>(
    key: K, 
    value: SettingsContextValue[K]
  ) => void;
}

const SettingsContext = createContext<SettingsContextValue | undefined>(undefined);

export const useSettings = () => {
  const context = useContext(SettingsContext);
  if (!context) {
    throw new Error('useSettings must be used within SettingsProvider');
  }
  return context;
};

// ✅ Compound provider pattern
export const AppProvider: React.FC<{ children: React.ReactNode }> = ({ 
  children 
}) => {
  return (
    <AuthProvider>
      <ThemeProvider>
        <SettingsProvider>
          <QuizProvider>
            {children}
          </QuizProvider>
        </SettingsProvider>
      </ThemeProvider>
    </AuthProvider>
  );
};

// ✅ Compound hook for related contexts
export const useAppContext = () => {
  const auth = useAuth();
  const theme = useTheme();
  const settings = useSettings();
  
  return {
    auth,
    theme,
    settings
  };
};
```

### **3. Context with Custom Selectors**

#### **Selective Context Subscriptions**
```typescript
// ✅ Context with selector pattern to minimize re-renders
interface AppState {
  user: User | null;
  quizzes: Quiz[];
  currentQuiz: Quiz | null;
  ui: UIState;
  notifications: Notification[];
}

const AppStateContext = createContext<AppState | undefined>(undefined);

// Generic selector hook
export const useAppSelector = <T>(
  selector: (state: AppState) => T,
  equalityFn?: (left: T, right: T) => boolean
): T => {
  const context = useContext(AppStateContext);
  if (!context) {
    throw new Error('useAppSelector must be used within AppStateProvider');
  }

  const [selectedState, setSelectedState] = useState(() => selector(context));
  const previousSelectedRef = useRef(selectedState);
  const selectorRef = useRef(selector);
  const equalityFnRef = useRef(equalityFn);

  // Update refs
  selectorRef.current = selector;
  equalityFnRef.current = equalityFn;

  useEffect(() => {
    const newSelectedState = selectorRef.current(context);
    const areEqual = equalityFnRef.current 
      ? equalityFnRef.current(previousSelectedRef.current, newSelectedState)
      : Object.is(previousSelectedRef.current, newSelectedState);

    if (!areEqual) {
      previousSelectedRef.current = newSelectedState;
      setSelectedState(newSelectedState);
    }
  }, [context]);

  return selectedState;
};

// Specific selector hooks
export const useCurrentUser = () => {
  return useAppSelector(state => state.user);
};

export const useQuizzes = () => {
  return useAppSelector(state => state.quizzes);
};

export const useCurrentQuiz = () => {
  return useAppSelector(state => state.currentQuiz);
};

export const useUIState = () => {
  return useAppSelector(state => state.ui);
};

// Usage in components
const QuizList: React.FC = () => {
  // Only re-renders when quizzes array changes
  const quizzes = useQuizzes();
  
  return (
    <div>
      {quizzes.map(quiz => (
        <QuizCard key={quiz.id} quiz={quiz} />
      ))}
    </div>
  );
};
```

## 🚀 Performance Optimization Patterns

### **1. Context Value Optimization**

#### **Preventing Unnecessary Re-renders**
```typescript
// ✅ Optimized context value with proper memoization
export const OptimizedQuizProvider: React.FC<{ children: React.ReactNode }> = ({ 
  children 
}) => {
  const [state, dispatch] = useReducer(quizReducer, initialState);

  // Separate state and actions to prevent action re-creation
  const stateValue = useMemo(() => state, [state]);
  
  const actionsValue = useMemo(() => ({
    startQuiz: (quizId: string) => {
      dispatch({ type: 'START_QUIZ', payload: quizId });
    },
    
    submitAnswer: (questionId: string, answer: Answer) => {
      dispatch({ type: 'SUBMIT_ANSWER', payload: { questionId, answer } });
    },
    
    completeQuiz: () => {
      dispatch({ type: 'COMPLETE_QUIZ' });
    }
  }), []); // Empty dependency array - actions are always the same

  return (
    <QuizStateContext.Provider value={stateValue}>
      <QuizActionsContext.Provider value={actionsValue}>
        {children}
      </QuizActionsContext.Provider>
    </QuizStateContext.Provider>
  );
};

// ✅ Component-level optimization
const QuizQuestion = memo<{ questionId: string }>(({ questionId }) => {
  // Only subscribes to the specific question data
  const question = useAppSelector(
    state => state.currentQuiz?.questions.find(q => q.id === questionId),
    (prev, next) => prev?.id === next?.id && prev?.text === next?.text
  );
  
  const { submitAnswer } = useQuizActions();

  if (!question) return null;

  return (
    <div className="quiz-question">
      <h3>{question.text}</h3>
      {question.options.map((option, index) => (
        <button
          key={index}
          onClick={() => submitAnswer(questionId, { optionIndex: index })}
        >
          {option}
        </button>
      ))}
    </div>
  );
});
```

### **2. Context Composition Patterns**

#### **Layered Context Architecture**
```typescript
// ✅ Layered context for complex applications
interface CoreContexts {
  auth: AuthContextValue;
  theme: ThemeContextValue;
  settings: SettingsContextValue;
}

interface FeatureContexts {
  quiz: QuizContextValue;
  progress: ProgressContextValue;
  analytics: AnalyticsContextValue;
}

// Core providers (always present)
const CoreProviders: React.FC<{ children: React.ReactNode }> = ({ children }) => (
  <AuthProvider>
    <ThemeProvider>
      <SettingsProvider>
        {children}
      </SettingsProvider>
    </ThemeProvider>
  </AuthProvider>
);

// Feature providers (conditionally rendered)
const FeatureProviders: React.FC<{ 
  children: React.ReactNode;
  features: string[];
}> = ({ children, features }) => {
  let content = children;

  if (features.includes('quiz')) {
    content = <QuizProvider>{content}</QuizProvider>;
  }

  if (features.includes('progress')) {
    content = <ProgressProvider>{content}</ProgressProvider>;
  }

  if (features.includes('analytics')) {
    content = <AnalyticsProvider>{content}</AnalyticsProvider>;
  }

  return <>{content}</>;
};

// Main app wrapper
export const AppProviders: React.FC<{ 
  children: React.ReactNode;
  features?: string[];
}> = ({ children, features = [] }) => (
  <CoreProviders>
    <FeatureProviders features={features}>
      {children}
    </FeatureProviders>
  </CoreProviders>
);

// Usage
const App = () => (
  <AppProviders features={['quiz', 'progress', 'analytics']}>
    <Router>
      <Routes>
        <Route path="/quiz/:id" element={<QuizPage />} />
        <Route path="/dashboard" element={<Dashboard />} />
      </Routes>
    </Router>
  </AppProviders>
);
```

## 🧪 Testing Context Providers

### **1. Provider Testing Utilities**

#### **Test Helpers for Context**
```typescript
// ✅ Testing utilities for context providers
interface TestProviderOptions {
  initialState?: Partial<QuizState>;
  user?: User;
  theme?: 'light' | 'dark';
}

export const createTestProviders = (options: TestProviderOptions = {}) => {
  const TestProviders: React.FC<{ children: React.ReactNode }> = ({ children }) => {
    // Mock auth provider
    const mockAuthValue: AuthContextValue = {
      user: options.user || null,
      isLoading: false,
      error: null,
      login: jest.fn(),
      logout: jest.fn(),
      updateProfile: jest.fn()
    };

    // Mock theme provider
    const mockThemeValue: ThemeContextValue = {
      theme: options.theme || 'light',
      colors: lightTheme.colors,
      typography: lightTheme.typography,
      toggleTheme: jest.fn(),
      setTheme: jest.fn()
    };

    return (
      <AuthContext.Provider value={mockAuthValue}>
        <ThemeContext.Provider value={mockThemeValue}>
          {children}
        </ThemeContext.Provider>
      </AuthContext.Provider>
    );
  };

  return TestProviders;
};

// ✅ Custom render function for testing
export const renderWithProviders = (
  ui: React.ReactElement,
  options: TestProviderOptions & RenderOptions = {}
) => {
  const { initialState, user, theme, ...renderOptions } = options;
  const TestProviders = createTestProviders({ initialState, user, theme });

  return render(ui, { wrapper: TestProviders, ...renderOptions });
};

// ✅ Hook testing with context
export const renderHookWithProviders = <TProps, TResult>(
  hook: (props: TProps) => TResult,
  options: TestProviderOptions & { hookProps?: TProps } = {}
) => {
  const { hookProps, ...providerOptions } = options;
  const TestProviders = createTestProviders(providerOptions);

  return renderHook(hook, {
    wrapper: TestProviders,
    initialProps: hookProps
  });
};
```

### **2. Context Integration Tests**

#### **Testing Context Interactions**
```typescript
// ✅ Integration tests for context providers
describe('QuizProvider Integration', () => {
  const mockQuiz: Quiz = {
    id: 'quiz-1',
    title: 'Test Quiz',
    questions: [
      {
        id: 'q1',
        text: 'What is React?',
        options: ['Library', 'Framework', 'Language', 'Tool'],
        correctAnswer: 0
      }
    ]
  };

  beforeEach(() => {
    // Mock API calls
    (global.fetch as jest.Mock) = jest.fn();
  });

  it('should load quiz successfully', async () => {
    (global.fetch as jest.Mock).mockResolvedValueOnce({
      ok: true,
      json: () => Promise.resolve(mockQuiz)
    });

    const TestComponent = () => {
      const { currentQuiz, loadQuiz } = useQuiz();
      
      React.useEffect(() => {
        loadQuiz('quiz-1');
      }, [loadQuiz]);

      return (
        <div>
          {currentQuiz ? (
            <div data-testid="quiz-title">{currentQuiz.title}</div>
          ) : (
            <div data-testid="loading">Loading...</div>
          )}
        </div>
      );
    };

    renderWithProviders(<TestComponent />);

    // Should show loading initially
    expect(screen.getByTestId('loading')).toBeInTheDocument();

    // Should load quiz
    await waitFor(() => {
      expect(screen.getByTestId('quiz-title')).toHaveTextContent('Test Quiz');
    });

    // Should have made API call
    expect(global.fetch).toHaveBeenCalledWith('/api/quizzes/quiz-1');
  });

  it('should handle quiz completion', async () => {
    const TestComponent = () => {
      const { submitAnswer, completeQuiz, score } = useQuiz();
      
      return (
        <div>
          <button 
            onClick={() => submitAnswer('q1', { optionIndex: 0 })}
            data-testid="submit-answer"
          >
            Submit Answer
          </button>
          <button 
            onClick={() => completeQuiz()}
            data-testid="complete-quiz"
          >
            Complete Quiz
          </button>
          {score !== null && (
            <div data-testid="score">Score: {score}</div>
          )}
        </div>
      );
    };

    renderWithProviders(<TestComponent />, {
      initialState: { currentQuiz: mockQuiz }
    });

    // Submit answer
    fireEvent.click(screen.getByTestId('submit-answer'));
    
    // Complete quiz
    fireEvent.click(screen.getByTestId('complete-quiz'));

    // Should show score
    await waitFor(() => {
      expect(screen.getByTestId('score')).toHaveTextContent('Score: 1');
    });
  });
});
```

## 📱 Context for Mobile-First EdTech

### **1. Offline Context Pattern**

#### **Offline-First Context Implementation**
```typescript
// ✅ Offline-first context for EdTech apps
interface OfflineContextValue {
  isOnline: boolean;
  pendingActions: PendingAction[];
  queueAction: (action: PendingAction) => void;
  syncPendingActions: () => Promise<void>;
}

interface PendingAction {
  id: string;
  type: string;
  payload: any;
  timestamp: number;
  retryCount: number;
}

const OfflineContext = createContext<OfflineContextValue | undefined>(undefined);

export const useOffline = () => {
  const context = useContext(OfflineContext);
  if (!context) {
    throw new Error('useOffline must be used within OfflineProvider');
  }
  return context;
};

export const OfflineProvider: React.FC<{ children: React.ReactNode }> = ({ 
  children 
}) => {
  const [isOnline, setIsOnline] = useState(navigator.onLine);
  const [pendingActions, setPendingActions] = useState<PendingAction[]>([]);

  // Listen for online/offline events
  useEffect(() => {
    const handleOnline = () => {
      setIsOnline(true);
      // Sync pending actions when coming back online
      syncPendingActions();
    };
    
    const handleOffline = () => setIsOnline(false);

    window.addEventListener('online', handleOnline);
    window.addEventListener('offline', handleOffline);

    return () => {
      window.removeEventListener('online', handleOnline);
      window.removeEventListener('offline', handleOffline);
    };
  }, []);

  const queueAction = useCallback((action: PendingAction) => {
    setPendingActions(prev => [...prev, action]);
    
    // Store in localStorage for persistence
    const stored = localStorage.getItem('pendingActions') || '[]';
    const actions = JSON.parse(stored);
    actions.push(action);
    localStorage.setItem('pendingActions', JSON.stringify(actions));
  }, []);

  const syncPendingActions = useCallback(async () => {
    if (!isOnline || pendingActions.length === 0) return;

    for (const action of pendingActions) {
      try {
        await executeAction(action);
        
        // Remove successful action
        setPendingActions(prev => prev.filter(a => a.id !== action.id));
        
        // Update localStorage
        const stored = localStorage.getItem('pendingActions') || '[]';
        const actions = JSON.parse(stored);
        const filtered = actions.filter((a: PendingAction) => a.id !== action.id);
        localStorage.setItem('pendingActions', JSON.stringify(filtered));
        
      } catch (error) {
        console.error('Failed to sync action:', action, error);
        
        // Increment retry count
        setPendingActions(prev => 
          prev.map(a => 
            a.id === action.id 
              ? { ...a, retryCount: a.retryCount + 1 }
              : a
          )
        );
      }
    }
  }, [isOnline, pendingActions]);

  // Load pending actions from localStorage on mount
  useEffect(() => {
    const stored = localStorage.getItem('pendingActions');
    if (stored) {
      setPendingActions(JSON.parse(stored));
    }
  }, []);

  const contextValue = useMemo(() => ({
    isOnline,
    pendingActions,
    queueAction,
    syncPendingActions
  }), [isOnline, pendingActions, queueAction, syncPendingActions]);

  return (
    <OfflineContext.Provider value={contextValue}>
      {children}
    </OfflineContext.Provider>
  );
};

// Usage in quiz components
const QuizAnswerSubmission: React.FC<{ questionId: string; answer: Answer }> = ({
  questionId,
  answer
}) => {
  const { isOnline, queueAction } = useOffline();
  const { submitAnswer } = useQuizActions();

  const handleSubmit = () => {
    if (isOnline) {
      // Submit immediately
      submitAnswer(questionId, answer);
    } else {
      // Queue for later submission
      queueAction({
        id: `submit-${questionId}-${Date.now()}`,
        type: 'SUBMIT_ANSWER',
        payload: { questionId, answer },
        timestamp: Date.now(),
        retryCount: 0
      });
      
      // Optimistically update UI
      submitAnswer(questionId, answer);
    }
  };

  return (
    <button onClick={handleSubmit}>
      Submit Answer {!isOnline && '(Offline)'}
    </button>
  );
};
```

## 🔗 Navigation

**← Previous:** [React Hooks Patterns](./hooks-patterns.md)  
**→ Next:** [Performance Optimization](./performance-optimization.md)

---

*Advanced Context API patterns for scalable EdTech application state management*