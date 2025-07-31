# Implementation Guide - React Advanced Patterns

## 🚀 Getting Started

This guide provides step-by-step implementation instructions for React advanced patterns, from basic hooks to concurrent features. Each section includes practical examples suitable for EdTech applications.

## 📋 Prerequisites

### **Development Environment**
```bash
# Node.js version (LTS recommended)
node --version  # >= 16.14.0

# React version with concurrent features
npm install react@^18.2.0 react-dom@^18.2.0

# TypeScript for better development experience
npm install typescript @types/react @types/react-dom

# Development tools
npm install @vitejs/plugin-react vite
npm install @testing-library/react @testing-library/jest-dom
```

### **Project Structure**
```
src/
├── hooks/              # Custom hooks
├── contexts/           # Context providers
├── components/
│   ├── ui/            # Reusable UI components
│   └── features/      # Feature-specific components
├── utils/             # Utility functions
└── types/             # TypeScript type definitions
```

## 🔧 Implementation Steps

### **Step 1: Basic Hook Patterns**

#### **1.1 useState Pattern for Form Handling**
```typescript
// hooks/useFormState.ts
import { useState, useCallback } from 'react';

interface FormState<T> {
  values: T;
  errors: Partial<Record<keyof T, string>>;
  touched: Partial<Record<keyof T, boolean>>;
}

export function useFormState<T extends Record<string, any>>(
  initialValues: T
) {
  const [state, setState] = useState<FormState<T>>({
    values: initialValues,
    errors: {},
    touched: {}
  });

  const setValue = useCallback((field: keyof T, value: any) => {
    setState(prev => ({
      ...prev,
      values: { ...prev.values, [field]: value },
      touched: { ...prev.touched, [field]: true }
    }));
  }, []);

  const setError = useCallback((field: keyof T, error: string) => {
    setState(prev => ({
      ...prev,
      errors: { ...prev.errors, [field]: error }
    }));
  }, []);

  return { state, setValue, setError };
}
```

#### **1.2 Using the Form Hook in Components**
```typescript
// components/features/QuizForm.tsx
import React from 'react';
import { useFormState } from '../../hooks/useFormState';

interface QuizFormData {
  title: string;
  description: string;
  timeLimit: number;
}

export const QuizForm: React.FC = () => {
  const { state, setValue, setError } = useFormState<QuizFormData>({
    title: '',
    description: '',
    timeLimit: 30
  });

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    // Validation logic
    if (!state.values.title.trim()) {
      setError('title', 'Title is required');
      return;
    }
    // Submit logic
    console.log('Submitting:', state.values);
  };

  return (
    <form onSubmit={handleSubmit}>
      <input
        type="text"
        value={state.values.title}
        onChange={(e) => setValue('title', e.target.value)}
        placeholder="Quiz Title"
      />
      {state.errors.title && (
        <span className="error">{state.errors.title}</span>
      )}
      
      <textarea
        value={state.values.description}
        onChange={(e) => setValue('description', e.target.value)}
        placeholder="Quiz Description"
      />
      
      <input
        type="number"
        value={state.values.timeLimit}
        onChange={(e) => setValue('timeLimit', parseInt(e.target.value))}
        min={1}
        max={180}
      />
      
      <button type="submit">Create Quiz</button>
    </form>
  );
};
```

### **Step 2: useReducer for Complex State**

#### **2.1 Quiz State Management**
```typescript
// hooks/useQuizState.ts
import { useReducer, useCallback } from 'react';

interface Question {
  id: string;
  text: string;
  options: string[];
  correctAnswer: number;
}

interface QuizState {
  questions: Question[];
  currentQuestionIndex: number;
  answers: Record<string, number>;
  timeRemaining: number;
  isCompleted: boolean;
  score: number;
}

type QuizAction =
  | { type: 'LOAD_QUESTIONS'; payload: Question[] }
  | { type: 'ANSWER_QUESTION'; payload: { questionId: string; answer: number } }
  | { type: 'NEXT_QUESTION' }
  | { type: 'PREVIOUS_QUESTION' }
  | { type: 'TICK_TIMER' }
  | { type: 'COMPLETE_QUIZ' }
  | { type: 'CALCULATE_SCORE' };

const quizReducer = (state: QuizState, action: QuizAction): QuizState => {
  switch (action.type) {
    case 'LOAD_QUESTIONS':
      return {
        ...state,
        questions: action.payload,
        currentQuestionIndex: 0
      };
      
    case 'ANSWER_QUESTION':
      return {
        ...state,
        answers: {
          ...state.answers,
          [action.payload.questionId]: action.payload.answer
        }
      };
      
    case 'NEXT_QUESTION':
      return {
        ...state,
        currentQuestionIndex: Math.min(
          state.currentQuestionIndex + 1,
          state.questions.length - 1
        )
      };
      
    case 'PREVIOUS_QUESTION':
      return {
        ...state,
        currentQuestionIndex: Math.max(state.currentQuestionIndex - 1, 0)
      };
      
    case 'TICK_TIMER':
      const newTime = state.timeRemaining - 1;
      return {
        ...state,
        timeRemaining: newTime,
        isCompleted: newTime <= 0 ? true : state.isCompleted
      };
      
    case 'COMPLETE_QUIZ':
      return { ...state, isCompleted: true };
      
    case 'CALCULATE_SCORE':
      const score = state.questions.reduce((acc, question) => {
        const userAnswer = state.answers[question.id];
        return userAnswer === question.correctAnswer ? acc + 1 : acc;
      }, 0);
      return { ...state, score };
      
    default:
      return state;
  }
};

export const useQuizState = (initialTimeLimit: number = 1800) => {
  const [state, dispatch] = useReducer(quizReducer, {
    questions: [],
    currentQuestionIndex: 0,
    answers: {},
    timeRemaining: initialTimeLimit,
    isCompleted: false,
    score: 0
  });

  const loadQuestions = useCallback((questions: Question[]) => {
    dispatch({ type: 'LOAD_QUESTIONS', payload: questions });
  }, []);

  const answerQuestion = useCallback((questionId: string, answer: number) => {
    dispatch({ type: 'ANSWER_QUESTION', payload: { questionId, answer } });
  }, []);

  const nextQuestion = useCallback(() => {
    dispatch({ type: 'NEXT_QUESTION' });
  }, []);

  const previousQuestion = useCallback(() => {
    dispatch({ type: 'PREVIOUS_QUESTION' });
  }, []);

  const completeQuiz = useCallback(() => {
    dispatch({ type: 'COMPLETE_QUIZ' });
    dispatch({ type: 'CALCULATE_SCORE' });
  }, []);

  return {
    state,
    actions: {
      loadQuestions,
      answerQuestion,
      nextQuestion,
      previousQuestion,
      completeQuiz
    }
  };
};
```

### **Step 3: Context API Patterns**

#### **3.1 Authentication Context**
```typescript
// contexts/AuthContext.tsx
import React, { createContext, useContext, useReducer, useEffect } from 'react';

interface User {
  id: string;
  email: string;
  name: string;
  role: 'student' | 'teacher' | 'admin';
}

interface AuthState {
  user: User | null;
  isLoading: boolean;
  error: string | null;
}

type AuthAction =
  | { type: 'AUTH_START' }
  | { type: 'AUTH_SUCCESS'; payload: User }
  | { type: 'AUTH_ERROR'; payload: string }
  | { type: 'AUTH_LOGOUT' };

const authReducer = (state: AuthState, action: AuthAction): AuthState => {
  switch (action.type) {
    case 'AUTH_START':
      return { ...state, isLoading: true, error: null };
    case 'AUTH_SUCCESS':
      return { ...state, isLoading: false, user: action.payload, error: null };
    case 'AUTH_ERROR':
      return { ...state, isLoading: false, error: action.payload };
    case 'AUTH_LOGOUT':
      return { ...state, user: null, isLoading: false, error: null };
    default:
      return state;
  }
};

interface AuthContextValue extends AuthState {
  login: (email: string, password: string) => Promise<void>;
  logout: () => void;
  register: (userData: RegisterData) => Promise<void>;
}

const AuthContext = createContext<AuthContextValue | undefined>(undefined);

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};

interface RegisterData {
  email: string;
  password: string;
  name: string;
  role: 'student' | 'teacher';
}

export const AuthProvider: React.FC<{ children: React.ReactNode }> = ({ 
  children 
}) => {
  const [state, dispatch] = useReducer(authReducer, {
    user: null,
    isLoading: false,
    error: null
  });

  const login = async (email: string, password: string) => {
    dispatch({ type: 'AUTH_START' });
    try {
      // API call simulation
      const response = await fetch('/api/auth/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password })
      });
      
      if (!response.ok) {
        throw new Error('Login failed');
      }
      
      const user = await response.json();
      dispatch({ type: 'AUTH_SUCCESS', payload: user });
      
      // Store token in localStorage
      localStorage.setItem('authToken', user.token);
    } catch (error) {
      dispatch({ 
        type: 'AUTH_ERROR', 
        payload: error instanceof Error ? error.message : 'Login failed' 
      });
    }
  };

  const logout = () => {
    localStorage.removeItem('authToken');
    dispatch({ type: 'AUTH_LOGOUT' });
  };

  const register = async (userData: RegisterData) => {
    dispatch({ type: 'AUTH_START' });
    try {
      const response = await fetch('/api/auth/register', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(userData)
      });
      
      if (!response.ok) {
        throw new Error('Registration failed');
      }
      
      const user = await response.json();
      dispatch({ type: 'AUTH_SUCCESS', payload: user });
    } catch (error) {
      dispatch({ 
        type: 'AUTH_ERROR', 
        payload: error instanceof Error ? error.message : 'Registration failed' 
      });
    }
  };

  // Check for existing auth token on mount
  useEffect(() => {
    const token = localStorage.getItem('authToken');
    if (token) {
      // Validate token and restore user state
      // This would typically involve an API call
    }
  }, []);

  const value: AuthContextValue = {
    ...state,
    login,
    logout,
    register
  };

  return (
    <AuthContext.Provider value={value}>
      {children}
    </AuthContext.Provider>
  );
};
```

### **Step 4: Performance Optimization Patterns**

#### **4.1 Memoized Components**
```typescript
// components/ui/QuestionCard.tsx
import React, { memo } from 'react';

interface QuestionCardProps {
  question: {
    id: string;
    text: string;
    options: string[];
  };
  selectedAnswer?: number;
  onAnswerSelect: (questionId: string, answerIndex: number) => void;
  disabled?: boolean;
}

export const QuestionCard = memo<QuestionCardProps>(({
  question,
  selectedAnswer,
  onAnswerSelect,
  disabled = false
}) => {
  return (
    <div className="question-card">
      <h3>{question.text}</h3>
      <div className="options">
        {question.options.map((option, index) => (
          <button
            key={index}
            className={`option ${selectedAnswer === index ? 'selected' : ''}`}
            onClick={() => onAnswerSelect(question.id, index)}
            disabled={disabled}
          >
            {option}
          </button>
        ))}
      </div>
    </div>
  );
}, (prevProps, nextProps) => {
  // Custom comparison function for optimal re-rendering
  return (
    prevProps.question.id === nextProps.question.id &&
    prevProps.selectedAnswer === nextProps.selectedAnswer &&
    prevProps.disabled === nextProps.disabled
  );
});

QuestionCard.displayName = 'QuestionCard';
```

#### **4.2 useMemo and useCallback Patterns**
```typescript
// hooks/useQuizStatistics.ts
import { useMemo, useCallback } from 'react';

interface QuizAttempt {
  id: string;
  score: number;
  totalQuestions: number;
  timeSpent: number;
  completedAt: Date;
}

export const useQuizStatistics = (attempts: QuizAttempt[]) => {
  const statistics = useMemo(() => {
    if (attempts.length === 0) {
      return {
        averageScore: 0,
        bestScore: 0,
        averageTime: 0,
        totalAttempts: 0,
        improvementTrend: 0
      };
    }

    const averageScore = attempts.reduce((sum, attempt) => 
      sum + (attempt.score / attempt.totalQuestions), 0) / attempts.length;
    
    const bestScore = Math.max(...attempts.map(attempt => 
      attempt.score / attempt.totalQuestions));
    
    const averageTime = attempts.reduce((sum, attempt) => 
      sum + attempt.timeSpent, 0) / attempts.length;
    
    // Calculate improvement trend (last 5 vs first 5 attempts)
    const recentAttempts = attempts.slice(-5);
    const earlierAttempts = attempts.slice(0, 5);
    const recentAverage = recentAttempts.reduce((sum, attempt) => 
      sum + (attempt.score / attempt.totalQuestions), 0) / recentAttempts.length;
    const earlierAverage = earlierAttempts.reduce((sum, attempt) => 
      sum + (attempt.score / attempt.totalQuestions), 0) / earlierAttempts.length;
    
    return {
      averageScore: Math.round(averageScore * 100),
      bestScore: Math.round(bestScore * 100),
      averageTime: Math.round(averageTime / 60), // Convert to minutes
      totalAttempts: attempts.length,
      improvementTrend: Math.round((recentAverage - earlierAverage) * 100)
    };
  }, [attempts]);

  const getScoreColor = useCallback((score: number) => {
    if (score >= 80) return 'green';
    if (score >= 60) return 'orange';
    return 'red';
  }, []);

  const formatTime = useCallback((seconds: number) => {
    const minutes = Math.floor(seconds / 60);
    const remainingSeconds = seconds % 60;
    return `${minutes}:${remainingSeconds.toString().padStart(2, '0')}`;
  }, []);

  return {
    statistics,
    getScoreColor,
    formatTime
  };
};
```

### **Step 5: Concurrent Features Implementation**

#### **5.1 Suspense for Data Fetching**
```typescript
// hooks/useQuizData.ts
import { useMemo } from 'react';

interface Quiz {
  id: string;
  title: string;
  questions: Question[];
}

// Create a cache for quiz data
const quizCache = new Map<string, Promise<Quiz>>();

const fetchQuiz = (quizId: string): Promise<Quiz> => {
  if (quizCache.has(quizId)) {
    return quizCache.get(quizId)!;
  }

  const promise = fetch(`/api/quizzes/${quizId}`)
    .then(response => {
      if (!response.ok) {
        throw new Error('Failed to fetch quiz');
      }
      return response.json();
    });

  quizCache.set(quizId, promise);
  return promise;
};

export const useQuizData = (quizId: string) => {
  const quiz = useMemo(() => {
    const promise = fetchQuiz(quizId);
    
    // This will suspend the component until the promise resolves
    let status = 'pending';
    let result: Quiz;
    
    promise.then(
      (data) => {
        status = 'fulfilled';
        result = data;
      },
      (error) => {
        status = 'rejected';
        result = error;
      }
    );

    if (status === 'pending') {
      throw promise; // This causes Suspense to show fallback
    }
    
    if (status === 'rejected') {
      throw result; // This triggers the nearest error boundary
    }
    
    return result;
  }, [quizId]);

  return quiz;
};
```

#### **5.2 Using Suspense in Components**
```typescript
// components/features/QuizViewer.tsx
import React, { Suspense } from 'react';
import { ErrorBoundary } from 'react-error-boundary';
import { useQuizData } from '../../hooks/useQuizData';

const QuizContent: React.FC<{ quizId: string }> = ({ quizId }) => {
  const quiz = useQuizData(quizId);
  
  return (
    <div className="quiz-content">
      <h1>{quiz.title}</h1>
      <div className="questions">
        {quiz.questions.map((question, index) => (
          <QuestionCard
            key={question.id}
            question={question}
            onAnswerSelect={(questionId, answerIndex) => {
              // Handle answer selection
            }}
          />
        ))}
      </div>
    </div>
  );
};

const QuizLoadingFallback = () => (
  <div className="quiz-loading">
    <div className="spinner" />
    <p>Loading quiz content...</p>
  </div>
);

const QuizErrorFallback: React.FC<{ error: Error; resetErrorBoundary: () => void }> = ({
  error,
  resetErrorBoundary
}) => (
  <div className="quiz-error">
    <h2>Failed to load quiz</h2>
    <p>{error.message}</p>
    <button onClick={resetErrorBoundary}>Try Again</button>
  </div>
);

export const QuizViewer: React.FC<{ quizId: string }> = ({ quizId }) => {
  return (
    <ErrorBoundary FallbackComponent={QuizErrorFallback}>
      <Suspense fallback={<QuizLoadingFallback />}>
        <QuizContent quizId={quizId} />
      </Suspense>
    </ErrorBoundary>
  );
};
```

#### **5.3 Concurrent Rendering with startTransition**
```typescript
// hooks/useSearchQuizzes.ts
import { useState, useTransition, useDeferredValue } from 'react';

export const useSearchQuizzes = () => {
  const [searchTerm, setSearchTerm] = useState('');
  const [results, setResults] = useState<Quiz[]>([]);
  const [isPending, startTransition] = useTransition();
  
  // Defer the search term to avoid blocking urgent updates
  const deferredSearchTerm = useDeferredValue(searchTerm);

  const performSearch = (term: string) => {
    startTransition(() => {
      // This search operation won't block other updates
      const filteredResults = allQuizzes.filter(quiz =>
        quiz.title.toLowerCase().includes(term.toLowerCase()) ||
        quiz.description.toLowerCase().includes(term.toLowerCase())
      );
      setResults(filteredResults);
    });
  };

  // Effect runs when deferred search term changes
  useEffect(() => {
    if (deferredSearchTerm) {
      performSearch(deferredSearchTerm);
    } else {
      setResults([]);
    }
  }, [deferredSearchTerm]);

  return {
    searchTerm,
    setSearchTerm,
    results,
    isPending
  };
};
```

### **Step 6: Testing Implementation**

#### **6.1 Testing Custom Hooks**
```typescript
// __tests__/hooks/useFormState.test.ts
import { renderHook, act } from '@testing-library/react';
import { useFormState } from '../../src/hooks/useFormState';

describe('useFormState', () => {
  it('should initialize with provided values', () => {
    const initialValues = { name: 'John', email: 'john@example.com' };
    const { result } = renderHook(() => useFormState(initialValues));

    expect(result.current.state.values).toEqual(initialValues);
    expect(result.current.state.errors).toEqual({});
    expect(result.current.state.touched).toEqual({});
  });

  it('should update field values', () => {
    const { result } = renderHook(() => 
      useFormState({ name: '', email: '' })
    );

    act(() => {
      result.current.setValue('name', 'Jane');
    });

    expect(result.current.state.values.name).toBe('Jane');
    expect(result.current.state.touched.name).toBe(true);
  });

  it('should set field errors', () => {
    const { result } = renderHook(() => 
      useFormState({ name: '', email: '' })
    );

    act(() => {
      result.current.setError('email', 'Invalid email format');
    });

    expect(result.current.state.errors.email).toBe('Invalid email format');
  });
});
```

#### **6.2 Testing Context Providers**
```typescript
// __tests__/contexts/AuthContext.test.tsx
import React from 'react';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { AuthProvider, useAuth } from '../../src/contexts/AuthContext';

// Mock fetch
global.fetch = jest.fn();

const TestComponent = () => {
  const { user, login, logout, isLoading, error } = useAuth();
  
  return (
    <div>
      {isLoading && <div>Loading...</div>}
      {error && <div>Error: {error}</div>}
      {user ? (
        <div>
          <span>Welcome, {user.name}</span>
          <button onClick={logout}>Logout</button>
        </div>
      ) : (
        <button onClick={() => login('test@example.com', 'password')}>
          Login
        </button>
      )}
    </div>
  );
};

describe('AuthContext', () => {
  beforeEach(() => {
    (fetch as jest.Mock).mockClear();
  });

  it('should login successfully', async () => {
    const mockUser = { id: '1', name: 'John', email: 'john@example.com' };
    (fetch as jest.Mock).mockResolvedValueOnce({
      ok: true,
      json: async () => mockUser
    });

    render(
      <AuthProvider>
        <TestComponent />
      </AuthProvider>
    );

    const loginButton = screen.getByText('Login');
    await userEvent.click(loginButton);

    await waitFor(() => {
      expect(screen.getByText('Welcome, John')).toBeInTheDocument();
    });
  });

  it('should handle login errors', async () => {
    (fetch as jest.Mock).mockResolvedValueOnce({
      ok: false,
      status: 401
    });

    render(
      <AuthProvider>
        <TestComponent />
      </AuthProvider>
    );

    const loginButton = screen.getByText('Login');
    await userEvent.click(loginButton);

    await waitFor(() => {
      expect(screen.getByText(/Error:/)).toBeInTheDocument();
    });
  });
});
```

## 🎯 Next Steps

1. **Practice Implementation**: Start with basic hooks and gradually add complexity
2. **Performance Testing**: Use React DevTools Profiler to measure improvements
3. **Error Handling**: Implement proper error boundaries and loading states
4. **Testing Coverage**: Achieve 90%+ test coverage for critical components
5. **Code Reviews**: Establish team standards for advanced React patterns

## 🔗 Navigation

**← Previous:** [Executive Summary](./executive-summary.md)  
**→ Next:** [Best Practices](./best-practices.md)

---

*Implementation guide for building scalable EdTech applications with modern React patterns*