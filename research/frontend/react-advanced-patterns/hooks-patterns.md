# React Hooks Patterns - Advanced Implementation Guide

## 🎯 Overview

Comprehensive guide to React hooks patterns for building scalable EdTech applications. This document covers built-in hooks, custom hook patterns, and advanced techniques for optimal performance and maintainability.

## 🔧 Built-in Hooks Mastery

### **1. useState Advanced Patterns**

#### **Functional Updates for Performance**
```typescript
// ✅ Functional updates prevent stale closures
const useCounter = (initialValue = 0) => {
  const [count, setCount] = useState(initialValue);

  const increment = useCallback(() => {
    setCount(prev => prev + 1); // Always uses latest value
  }, []);

  const decrement = useCallback(() => {
    setCount(prev => prev - 1);
  }, []);

  const reset = useCallback(() => {
    setCount(initialValue);
  }, [initialValue]);

  return { count, increment, decrement, reset };
};

// Usage in quiz scoring
const QuizScoreTracker: React.FC = () => {
  const { count: score, increment: addPoint, reset: resetScore } = useCounter(0);
  
  return (
    <div className="score-tracker">
      <span>Score: {score}</span>
      <button onClick={addPoint}>Correct Answer</button>
      <button onClick={resetScore}>Reset Quiz</button>
    </div>
  );
};
```

#### **Complex State with Reducer Pattern**
```typescript
// ✅ useState with reducer-like pattern for complex state
interface QuizFormState {
  title: string;
  description: string;
  questions: Question[];
  settings: QuizSettings;
  errors: Record<string, string>;
  isDirty: boolean;
}

type QuizFormAction = 
  | { type: 'SET_FIELD'; field: keyof QuizFormState; value: any }
  | { type: 'ADD_QUESTION'; question: Question }
  | { type: 'REMOVE_QUESTION'; questionId: string }
  | { type: 'SET_ERROR'; field: string; error: string }
  | { type: 'CLEAR_ERRORS' }
  | { type: 'RESET_FORM' };

const quizFormReducer = (state: QuizFormState, action: QuizFormAction): QuizFormState => {
  switch (action.type) {
    case 'SET_FIELD':
      return {
        ...state,
        [action.field]: action.value,
        isDirty: true,
        errors: { ...state.errors, [action.field]: '' }
      };
    
    case 'ADD_QUESTION':
      return {
        ...state,
        questions: [...state.questions, action.question],
        isDirty: true
      };
    
    case 'REMOVE_QUESTION':
      return {
        ...state,
        questions: state.questions.filter(q => q.id !== action.questionId),
        isDirty: true
      };
    
    case 'SET_ERROR':
      return {
        ...state,
        errors: { ...state.errors, [action.field]: action.error }
      };
    
    case 'CLEAR_ERRORS':
      return { ...state, errors: {} };
    
    case 'RESET_FORM':
      return initialQuizFormState;
    
    default:
      return state;
  }
};

const useQuizForm = (initialData?: Partial<QuizFormState>) => {
  const [state, dispatch] = useState(() => 
    quizFormReducer({ ...initialQuizFormState, ...initialData }, { type: 'RESET_FORM' })
  );

  const updateField = useCallback((field: keyof QuizFormState, value: any) => {
    dispatch({ type: 'SET_FIELD', field, value });
  }, []);

  const addQuestion = useCallback((question: Question) => {
    dispatch({ type: 'ADD_QUESTION', question });
  }, []);

  return { state, updateField, addQuestion, dispatch };
};
```

### **2. useEffect Advanced Patterns**

#### **Cleanup and Dependency Management**
```typescript
// ✅ Proper cleanup for subscriptions and timers
const useQuizTimer = (duration: number, onTimeUp: () => void) => {
  const [timeLeft, setTimeLeft] = useState(duration);
  const [isActive, setIsActive] = useState(false);
  const intervalRef = useRef<NodeJS.Timeout | null>(null);

  useEffect(() => {
    if (isActive && timeLeft > 0) {
      intervalRef.current = setInterval(() => {
        setTimeLeft(prev => {
          if (prev <= 1) {
            setIsActive(false);
            onTimeUp();
            return 0;
          }
          return prev - 1;
        });
      }, 1000);
    } else {
      if (intervalRef.current) {
        clearInterval(intervalRef.current);
        intervalRef.current = null;
      }
    }

    // Cleanup function
    return () => {
      if (intervalRef.current) {
        clearInterval(intervalRef.current);
      }
    };
  }, [isActive, timeLeft, onTimeUp]);

  // Cleanup on unmount
  useEffect(() => {
    return () => {
      if (intervalRef.current) {
        clearInterval(intervalRef.current);
      }
    };
  }, []);

  const start = useCallback(() => setIsActive(true), []);
  const pause = useCallback(() => setIsActive(false), []);
  const reset = useCallback(() => {
    setTimeLeft(duration);
    setIsActive(false);
  }, [duration]);

  return { timeLeft, isActive, start, pause, reset };
};
```

#### **Conditional Effects and Async Operations**
```typescript
// ✅ Handling async operations in useEffect
const useAsyncData = <T>(
  asyncFunction: () => Promise<T>,
  dependencies: React.DependencyList,
  immediate = true
) => {
  const [data, setData] = useState<T | null>(null);
  const [loading, setLoading] = useState(immediate);
  const [error, setError] = useState<Error | null>(null);
  const cancelRef = useRef<AbortController | null>(null);

  const execute = useCallback(async () => {
    // Cancel previous request
    if (cancelRef.current) {
      cancelRef.current.abort();
    }

    cancelRef.current = new AbortController();
    
    setLoading(true);
    setError(null);

    try {
      const result = await asyncFunction();
      
      // Check if request was cancelled
      if (!cancelRef.current.signal.aborted) {
        setData(result);
      }
    } catch (err) {
      if (!cancelRef.current.signal.aborted) {
        setError(err instanceof Error ? err : new Error('Unknown error'));
      }
    } finally {
      if (!cancelRef.current.signal.aborted) {
        setLoading(false);
      }
    }
  }, dependencies);

  useEffect(() => {
    if (immediate) {
      execute();
    }

    return () => {
      if (cancelRef.current) {
        cancelRef.current.abort();
      }
    };
  }, [execute, immediate]);

  return { data, loading, error, execute };
};

// Usage for quiz data fetching
const QuizLoader: React.FC<{ quizId: string }> = ({ quizId }) => {
  const { data: quiz, loading, error } = useAsyncData(
    () => fetchQuiz(quizId),
    [quizId]
  );

  if (loading) return <div>Loading quiz...</div>;
  if (error) return <div>Error: {error.message}</div>;
  if (!quiz) return <div>Quiz not found</div>;

  return <QuizContent quiz={quiz} />;
};
```

### **3. useReducer Advanced Patterns**

#### **Complex State Machines**
```typescript
// ✅ State machine pattern for quiz flow
type QuizState = 
  | { status: 'idle'; quiz: null; error: null }
  | { status: 'loading'; quiz: null; error: null }
  | { status: 'loaded'; quiz: Quiz; error: null }
  | { status: 'taking'; quiz: Quiz; currentQuestion: number; answers: Answer[]; timeLeft: number }
  | { status: 'completed'; quiz: Quiz; answers: Answer[]; score: number }
  | { status: 'error'; quiz: null; error: string };

type QuizAction =
  | { type: 'LOAD_QUIZ' }
  | { type: 'QUIZ_LOADED'; payload: Quiz }
  | { type: 'QUIZ_ERROR'; payload: string }
  | { type: 'START_QUIZ' }
  | { type: 'ANSWER_QUESTION'; payload: Answer }
  | { type: 'NEXT_QUESTION' }
  | { type: 'PREVIOUS_QUESTION' }
  | { type: 'TICK_TIMER' }
  | { type: 'COMPLETE_QUIZ' }
  | { type: 'RESET_QUIZ' };

const quizReducer = (state: QuizState, action: QuizAction): QuizState => {
  switch (action.type) {
    case 'LOAD_QUIZ':
      if (state.status === 'idle') {
        return { status: 'loading', quiz: null, error: null };
      }
      return state;

    case 'QUIZ_LOADED':
      if (state.status === 'loading') {
        return { status: 'loaded', quiz: action.payload, error: null };
      }
      return state;

    case 'QUIZ_ERROR':
      return { status: 'error', quiz: null, error: action.payload };

    case 'START_QUIZ':
      if (state.status === 'loaded') {
        return {
          status: 'taking',
          quiz: state.quiz,
          currentQuestion: 0,
          answers: [],
          timeLeft: state.quiz.duration
        };
      }
      return state;

    case 'ANSWER_QUESTION':
      if (state.status === 'taking') {
        const newAnswers = [...state.answers];
        newAnswers[state.currentQuestion] = action.payload;
        return { ...state, answers: newAnswers };
      }
      return state;

    case 'NEXT_QUESTION':
      if (state.status === 'taking' && state.currentQuestion < state.quiz.questions.length - 1) {
        return { ...state, currentQuestion: state.currentQuestion + 1 };
      }
      return state;

    case 'COMPLETE_QUIZ':
      if (state.status === 'taking') {
        const score = calculateScore(state.quiz.questions, state.answers);
        return {
          status: 'completed',
          quiz: state.quiz,
          answers: state.answers,
          score
        };
      }
      return state;

    case 'TICK_TIMER':
      if (state.status === 'taking') {
        const newTimeLeft = state.timeLeft - 1;
        if (newTimeLeft <= 0) {
          const score = calculateScore(state.quiz.questions, state.answers);
          return {
            status: 'completed',
            quiz: state.quiz,
            answers: state.answers,
            score
          };
        }
        return { ...state, timeLeft: newTimeLeft };
      }
      return state;

    case 'RESET_QUIZ':
      return { status: 'idle', quiz: null, error: null };

    default:
      return state;
  }
};

const useQuizStateMachine = () => {
  const [state, dispatch] = useReducer(quizReducer, {
    status: 'idle',
    quiz: null,
    error: null
  });

  // Timer effect
  useEffect(() => {
    if (state.status === 'taking') {
      const interval = setInterval(() => {
        dispatch({ type: 'TICK_TIMER' });
      }, 1000);

      return () => clearInterval(interval);
    }
  }, [state.status]);

  return { state, dispatch };
};
```

## 🎨 Custom Hook Patterns

### **1. Data Fetching Hooks**

#### **Generic API Hook with Caching**
```typescript
// ✅ Reusable API hook with built-in caching
interface UseApiOptions<T> {
  initialData?: T;
  onSuccess?: (data: T) => void;
  onError?: (error: Error) => void;
  enabled?: boolean;
  refetchInterval?: number;
  cacheTime?: number;
}

const apiCache = new Map<string, { data: any; timestamp: number; ttl: number }>();

const useApi = <T>(
  url: string,
  options: UseApiOptions<T> = {}
) => {
  const {
    initialData,
    onSuccess,
    onError,
    enabled = true,
    refetchInterval,
    cacheTime = 5 * 60 * 1000 // 5 minutes default
  } = options;

  const [data, setData] = useState<T | null>(initialData || null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<Error | null>(null);
  const abortControllerRef = useRef<AbortController | null>(null);

  const fetchData = useCallback(async (force = false) => {
    // Check cache first
    if (!force) {
      const cached = apiCache.get(url);
      if (cached && Date.now() - cached.timestamp < cached.ttl) {
        setData(cached.data);
        onSuccess?.(cached.data);
        return cached.data;
      }
    }

    // Cancel previous request
    if (abortControllerRef.current) {
      abortControllerRef.current.abort();
    }

    abortControllerRef.current = new AbortController();
    setLoading(true);
    setError(null);

    try {
      const response = await fetch(url, {
        signal: abortControllerRef.current.signal
      });

      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }

      const result = await response.json();
      
      // Cache the result
      apiCache.set(url, {
        data: result,
        timestamp: Date.now(),
        ttl: cacheTime
      });

      setData(result);
      onSuccess?.(result);
      return result;
    } catch (err) {
      if (err.name !== 'AbortError') {
        const error = err instanceof Error ? err : new Error('Unknown error');
        setError(error);
        onError?.(error);
      }
    } finally {
      setLoading(false);
    }
  }, [url, onSuccess, onError, cacheTime]);

  // Initial fetch
  useEffect(() => {
    if (enabled) {
      fetchData();
    }

    return () => {
      if (abortControllerRef.current) {
        abortControllerRef.current.abort();
      }
    };
  }, [fetchData, enabled]);

  // Refetch interval
  useEffect(() => {
    if (refetchInterval && enabled) {
      const interval = setInterval(() => {
        fetchData();
      }, refetchInterval);

      return () => clearInterval(interval);
    }
  }, [fetchData, refetchInterval, enabled]);

  const refetch = useCallback(() => fetchData(true), [fetchData]);

  return {
    data,
    loading,
    error,
    refetch
  };
};

// Usage examples
const QuizDashboard: React.FC = () => {
  const { data: quizzes, loading, error, refetch } = useApi<Quiz[]>('/api/quizzes', {
    refetchInterval: 30000, // Refetch every 30 seconds
    onSuccess: (data) => console.log(`Loaded ${data.length} quizzes`),
    onError: (error) => console.error('Failed to load quizzes:', error)
  });

  return (
    <div>
      {loading && <div>Loading quizzes...</div>}
      {error && <div>Error: {error.message}</div>}
      {quizzes && (
        <div>
          {quizzes.map(quiz => (
            <QuizCard key={quiz.id} quiz={quiz} />
          ))}
          <button onClick={refetch}>Refresh</button>
        </div>
      )}
    </div>
  );
};
```

### **2. Form Management Hooks**

#### **Advanced Form Hook with Validation**
```typescript
// ✅ Comprehensive form management hook
interface ValidationRule<T> {
  required?: boolean;
  minLength?: number;
  maxLength?: number;
  pattern?: RegExp;
  custom?: (value: T) => string | null;
  asyncValidation?: (value: T) => Promise<string | null>;
}

interface FormConfig<T> {
  initialValues: T;
  validationRules?: Partial<Record<keyof T, ValidationRule<any>>>;
  onSubmit?: (values: T) => void | Promise<void>;
  validateOnChange?: boolean;
  validateOnBlur?: boolean;
}

const useAdvancedForm = <T extends Record<string, any>>(config: FormConfig<T>) => {
  const {
    initialValues,
    validationRules = {},
    onSubmit,
    validateOnChange = true,
    validateOnBlur = true
  } = config;

  const [values, setValues] = useState<T>(initialValues);
  const [errors, setErrors] = useState<Partial<Record<keyof T, string>>>({});
  const [touched, setTouched] = useState<Partial<Record<keyof T, boolean>>>({});
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [isDirty, setIsDirty] = useState(false);

  const validateField = useCallback(async (field: keyof T, value: any): Promise<string | null> => {
    const rules = validationRules[field];
    if (!rules) return null;

    // Required validation
    if (rules.required && (!value || (typeof value === 'string' && !value.trim()))) {
      return `${String(field)} is required`;
    }

    // Length validations
    if (typeof value === 'string') {
      if (rules.minLength && value.length < rules.minLength) {
        return `${String(field)} must be at least ${rules.minLength} characters`;
      }
      if (rules.maxLength && value.length > rules.maxLength) {
        return `${String(field)} must be no more than ${rules.maxLength} characters`;
      }
    }

    // Pattern validation
    if (rules.pattern && typeof value === 'string' && !rules.pattern.test(value)) {
      return `${String(field)} format is invalid`;
    }

    // Custom validation
    if (rules.custom) {
      const customError = rules.custom(value);
      if (customError) return customError;
    }

    // Async validation
    if (rules.asyncValidation) {
      try {
        const asyncError = await rules.asyncValidation(value);
        if (asyncError) return asyncError;
      } catch (error) {
        return 'Validation failed';
      }
    }

    return null;
  }, [validationRules]);

  const validateAllFields = useCallback(async (): Promise<boolean> => {
    const newErrors: Partial<Record<keyof T, string>> = {};
    let isValid = true;

    for (const field in values) {
      const error = await validateField(field, values[field]);
      if (error) {
        newErrors[field] = error;
        isValid = false;
      }
    }

    setErrors(newErrors);
    return isValid;
  }, [values, validateField]);

  const setValue = useCallback(async (field: keyof T, value: any) => {
    const newValues = { ...values, [field]: value };
    setValues(newValues);
    setIsDirty(true);

    if (validateOnChange) {
      const error = await validateField(field, value);
      setErrors(prev => ({ ...prev, [field]: error || undefined }));
    }
  }, [values, validateField, validateOnChange]);

  const setFieldTouched = useCallback(async (field: keyof T) => {
    setTouched(prev => ({ ...prev, [field]: true }));

    if (validateOnBlur) {
      const error = await validateField(field, values[field]);
      setErrors(prev => ({ ...prev, [field]: error || undefined }));
    }
  }, [values, validateField, validateOnBlur]);

  const handleSubmit = useCallback(async (event?: React.FormEvent) => {
    if (event) {
      event.preventDefault();
    }

    setIsSubmitting(true);
    
    const isValid = await validateAllFields();
    if (isValid && onSubmit) {
      try {
        await onSubmit(values);
      } catch (error) {
        console.error('Form submission error:', error);
      }
    }

    setIsSubmitting(false);
  }, [values, validateAllFields, onSubmit]);

  const reset = useCallback(() => {
    setValues(initialValues);
    setErrors({});
    setTouched({});
    setIsSubmitting(false);
    setIsDirty(false);
  }, [initialValues]);

  const getFieldProps = useCallback((field: keyof T) => ({
    value: values[field],
    onChange: (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) => 
      setValue(field, e.target.value),
    onBlur: () => setFieldTouched(field),
    error: touched[field] ? errors[field] : undefined
  }), [values, errors, touched, setValue, setFieldTouched]);

  return {
    values,
    errors,
    touched,
    isSubmitting,
    isDirty,
    setValue,
    setFieldTouched,
    handleSubmit,
    reset,
    getFieldProps,
    validateField,
    validateAllFields
  };
};

// Usage example
const QuizCreationForm: React.FC = () => {
  const form = useAdvancedForm({
    initialValues: {
      title: '',
      description: '',
      timeLimit: 30,
      passingScore: 80
    },
    validationRules: {
      title: {
        required: true,
        minLength: 3,
        maxLength: 100
      },
      description: {
        required: true,
        minLength: 10
      },
      timeLimit: {
        required: true,
        custom: (value: number) => value < 5 ? 'Time limit must be at least 5 minutes' : null
      },
      passingScore: {
        required: true,
        custom: (value: number) => (value < 0 || value > 100) ? 'Score must be between 0 and 100' : null
      }
    },
    onSubmit: async (values) => {
      await createQuiz(values);
      alert('Quiz created successfully!');
    }
  });

  return (
    <form onSubmit={form.handleSubmit}>
      <div>
        <label htmlFor="title">Quiz Title</label>
        <input
          id="title"
          type="text"
          {...form.getFieldProps('title')}
        />
        {form.errors.title && <span className="error">{form.errors.title}</span>}
      </div>

      <div>
        <label htmlFor="description">Description</label>
        <textarea
          id="description"
          {...form.getFieldProps('description')}
        />
        {form.errors.description && <span className="error">{form.errors.description}</span>}
      </div>

      <div>
        <label htmlFor="timeLimit">Time Limit (minutes)</label>
        <input
          id="timeLimit"
          type="number"
          min="1"
          {...form.getFieldProps('timeLimit')}
          onChange={(e) => form.setValue('timeLimit', parseInt(e.target.value))}
        />
        {form.errors.timeLimit && <span className="error">{form.errors.timeLimit}</span>}
      </div>

      <button type="submit" disabled={form.isSubmitting}>
        {form.isSubmitting ? 'Creating...' : 'Create Quiz'}
      </button>
    </form>
  );
};
```

### **3. Performance Optimization Hooks**

#### **Debounce and Throttle Hooks**
```typescript
// ✅ Debounce hook for search functionality
const useDebounce = <T>(value: T, delay: number): T => {
  const [debouncedValue, setDebouncedValue] = useState<T>(value);

  useEffect(() => {
    const handler = setTimeout(() => {
      setDebouncedValue(value);
    }, delay);

    return () => {
      clearTimeout(handler);
    };
  }, [value, delay]);

  return debouncedValue;
};

// ✅ Throttle hook for scroll events
const useThrottle = <T>(value: T, limit: number): T => {
  const [throttledValue, setThrottledValue] = useState<T>(value);
  const lastRan = useRef(Date.now());

  useEffect(() => {
    const handler = setTimeout(() => {
      if (Date.now() - lastRan.current >= limit) {
        setThrottledValue(value);
        lastRan.current = Date.now();
      }
    }, limit - (Date.now() - lastRan.current));

    return () => {
      clearTimeout(handler);
    };
  }, [value, limit]);

  return throttledValue;
};

// Usage in search component
const QuizSearch: React.FC = () => {
  const [searchTerm, setSearchTerm] = useState('');
  const debouncedSearchTerm = useDebounce(searchTerm, 300);

  const { data: searchResults, loading } = useApi<Quiz[]>(
    `/api/quizzes/search?q=${encodeURIComponent(debouncedSearchTerm)}`,
    { enabled: debouncedSearchTerm.length > 2 }
  );

  return (
    <div>
      <input
        type="text"
        value={searchTerm}
        onChange={(e) => setSearchTerm(e.target.value)}
        placeholder="Search quizzes..."
      />
      
      {loading && <div>Searching...</div>}
      
      {searchResults && (
        <div>
          {searchResults.map(quiz => (
            <QuizCard key={quiz.id} quiz={quiz} />
          ))}
        </div>
      )}
    </div>
  );
};
```

## 🔗 Navigation

**← Previous:** [Comparison Analysis](./comparison-analysis.md)  
**→ Next:** [Context API Patterns](./context-api-patterns.md)

---

*Advanced React hooks patterns for building scalable EdTech applications*