# Testing Strategies - Advanced React Patterns

## 🎯 Overview

Comprehensive testing strategies for advanced React patterns in EdTech applications. This document covers testing hooks, context providers, performance optimizations, concurrent features, and real-world testing scenarios.

## 🧪 Testing Philosophy for Advanced React

### **1. Testing Pyramid for React Applications**

#### **Testing Strategy Overview**
```typescript
// ✅ Testing levels for EdTech React applications

// Unit Tests (70% of tests) - Fast, isolated, focused
// - Custom hooks
// - Pure components
// - Utility functions
// - Reducers

// Integration Tests (20% of tests) - Component interactions
// - Context providers with consumers
// - Component composition
// - Data flow between components
// - API integrations

// End-to-End Tests (10% of tests) - Full user workflows
// - Quiz taking flow
// - User authentication
// - Progress tracking
// - Critical user journeys
```

### **2. Testing Environment Setup**

#### **Modern Testing Stack Configuration**
```typescript
// ✅ Jest configuration for React advanced patterns
// jest.config.js
module.exports = {
  testEnvironment: 'jsdom',
  setupFilesAfterEnv: ['<rootDir>/src/test/setup.ts'],
  moduleNameMapping: {
    '^@/(.*)$': '<rootDir>/src/$1',
    '\\.(css|less|scss|sass)$': 'identity-obj-proxy'
  },
  collectCoverageFrom: [
    'src/**/*.{ts,tsx}',
    '!src/**/*.d.ts',
    '!src/test/**/*',
    '!src/**/*.stories.{ts,tsx}'
  ],
  coverageThreshold: {
    global: {
      branches: 80,
      functions: 80,
      lines: 80,
      statements: 80
    }
  },
  transform: {
    '^.+\\.(ts|tsx)$': ['ts-jest', {
      tsconfig: 'tsconfig.json'
    }]
  }
};

// ✅ Test setup file
// src/test/setup.ts
import '@testing-library/jest-dom';
import { cleanup } from '@testing-library/react';
import { server } from './mocks/server';

// Enable API mocking with MSW
beforeAll(() => server.listen());
afterEach(() => {
  cleanup();
  server.resetHandlers();
});
afterAll(() => server.close());

// Mock ResizeObserver for tests
global.ResizeObserver = jest.fn().mockImplementation(() => ({
  observe: jest.fn(),
  unobserve: jest.fn(),
  disconnect: jest.fn()
}));

// Mock IntersectionObserver
global.IntersectionObserver = jest.fn().mockImplementation(() => ({
  observe: jest.fn(),
  unobserve: jest.fn(),
  disconnect: jest.fn()
}));

// Performance API mock
Object.defineProperty(window, 'performance', {
  value: {
    now: jest.fn(() => Date.now()),
    mark: jest.fn(),
    measure: jest.fn()
  }
});
```

## 🎣 Testing Custom Hooks

### **1. Basic Hook Testing Patterns**

#### **Testing State Hooks**
```typescript
// ✅ Testing custom state management hooks
import { renderHook, act } from '@testing-library/react';
import { useQuizState } from '../hooks/useQuizState';

describe('useQuizState', () => {
  const mockQuestions: Question[] = [
    {
      id: 'q1',
      text: 'What is React?',
      options: ['Library', 'Framework', 'Language', 'Tool'],
      correctAnswer: 0
    },
    {
      id: 'q2',
      text: 'What is JSX?',
      options: ['Syntax Extension', 'Framework', 'Library', 'Tool'],
      correctAnswer: 0
    }
  ];

  it('should initialize with default state', () => {
    const { result } = renderHook(() => useQuizState());

    expect(result.current.state.currentQuestionIndex).toBe(0);
    expect(result.current.state.answers).toEqual({});
    expect(result.current.state.isCompleted).toBe(false);
    expect(result.current.state.score).toBeNull();
  });

  it('should load questions correctly', () => {
    const { result } = renderHook(() => useQuizState());

    act(() => {
      result.current.actions.loadQuestions(mockQuestions);
    });

    expect(result.current.state.questions).toEqual(mockQuestions);
    expect(result.current.state.currentQuestionIndex).toBe(0);
  });

  it('should handle answer submission', () => {
    const { result } = renderHook(() => useQuizState());

    act(() => {
      result.current.actions.loadQuestions(mockQuestions);
    });

    act(() => {
      result.current.actions.answerQuestion('q1', 0);
    });

    expect(result.current.state.answers).toEqual({ q1: 0 });
  });

  it('should navigate between questions', () => {
    const { result } = renderHook(() => useQuizState());

    act(() => {
      result.current.actions.loadQuestions(mockQuestions);
    });

    act(() => {
      result.current.actions.nextQuestion();
    });

    expect(result.current.state.currentQuestionIndex).toBe(1);

    act(() => {
      result.current.actions.previousQuestion();
    });

    expect(result.current.state.currentQuestionIndex).toBe(0);
  });

  it('should complete quiz and calculate score', () => {
    const { result } = renderHook(() => useQuizState());

    act(() => {
      result.current.actions.loadQuestions(mockQuestions);
    });

    // Answer both questions correctly
    act(() => {
      result.current.actions.answerQuestion('q1', 0);
      result.current.actions.answerQuestion('q2', 0);
    });

    act(() => {
      result.current.actions.completeQuiz();
    });

    expect(result.current.state.isCompleted).toBe(true);
    expect(result.current.state.score).toBe(2); // Both correct
  });

  it('should handle timer functionality', async () => {
    jest.useFakeTimers();
    
    const { result } = renderHook(() => useQuizState(60)); // 60 seconds

    act(() => {
      result.current.actions.startTimer();
    });

    expect(result.current.state.timeRemaining).toBe(60);

    // Fast-forward 30 seconds
    act(() => {
      jest.advanceTimersByTime(30000);
    });

    expect(result.current.state.timeRemaining).toBe(30);

    // Fast-forward to completion
    act(() => {
      jest.advanceTimersByTime(30000);
    });

    expect(result.current.state.timeRemaining).toBe(0);
    expect(result.current.state.isCompleted).toBe(true);

    jest.useRealTimers();
  });
});
```

### **2. Testing Async Hooks**

#### **Testing Data Fetching Hooks**
```typescript
// ✅ Testing async data fetching hooks
import { renderHook, waitFor } from '@testing-library/react';
import { useAsyncData } from '../hooks/useAsyncData';

describe('useAsyncData', () => {
  const mockData = { id: '1', title: 'Test Quiz' };
  const mockError = new Error('Network error');

  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('should handle successful data fetching', async () => {
    const mockFetcher = jest.fn().mockResolvedValue(mockData);
    
    const { result } = renderHook(() => 
      useAsyncData(mockFetcher, [])
    );

    // Initial state
    expect(result.current.loading).toBe(true);
    expect(result.current.data).toBeNull();
    expect(result.current.error).toBeNull();

    // Wait for data to load
    await waitFor(() => {
      expect(result.current.loading).toBe(false);
    });

    expect(result.current.data).toEqual(mockData);
    expect(result.current.error).toBeNull();
    expect(mockFetcher).toHaveBeenCalledTimes(1);
  });

  it('should handle fetch errors', async () => {
    const mockFetcher = jest.fn().mockRejectedValue(mockError);
    
    const { result } = renderHook(() => 
      useAsyncData(mockFetcher, [])
    );

    await waitFor(() => {
      expect(result.current.loading).toBe(false);
    });

    expect(result.current.data).toBeNull();
    expect(result.current.error).toEqual(mockError);
  });

  it('should refetch when dependencies change', async () => {
    const mockFetcher = jest.fn()
      .mockResolvedValueOnce({ id: '1', title: 'Quiz 1' })
      .mockResolvedValueOnce({ id: '2', title: 'Quiz 2' });

    const { result, rerender } = renderHook(
      ({ id }) => useAsyncData(() => mockFetcher(id), [id]),
      { initialProps: { id: '1' } }
    );

    await waitFor(() => {
      expect(result.current.loading).toBe(false);
    });

    expect(result.current.data).toEqual({ id: '1', title: 'Quiz 1' });

    // Change dependency
    rerender({ id: '2' });

    await waitFor(() => {
      expect(result.current.loading).toBe(false);
    });

    expect(result.current.data).toEqual({ id: '2', title: 'Quiz 2' });
    expect(mockFetcher).toHaveBeenCalledTimes(2);
  });

  it('should cancel previous requests when dependencies change', async () => {
    const abortedRequests: AbortSignal[] = [];
    const mockFetcher = jest.fn().mockImplementation((signal: AbortSignal) => {
      abortedRequests.push(signal);
      return new Promise((resolve) => {
        setTimeout(() => resolve({ data: 'test' }), 1000);
      });
    });

    const { rerender } = renderHook(
      ({ id }) => useAsyncData(() => mockFetcher(id), [id]),
      { initialProps: { id: '1' } }
    );

    // Change dependency before first request completes
    rerender({ id: '2' });

    // First request should be aborted
    expect(abortedRequests[0]?.aborted).toBe(true);
  });
});
```

## 🏗️ Testing Context Providers

### **1. Context Provider Testing**

#### **Testing Auth Context**
```typescript
// ✅ Testing context providers with proper mocking
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { AuthProvider, useAuth } from '../contexts/AuthContext';
import { server } from '../test/mocks/server';
import { rest } from 'msw';

// Test component that uses auth context
const TestAuthComponent: React.FC = () => {
  const { user, login, logout, isLoading, error } = useAuth();

  return (
    <div>
      {isLoading && <div data-testid="loading">Loading...</div>}
      {error && <div data-testid="error">{error}</div>}
      
      {user ? (
        <div>
          <span data-testid="user-name">Welcome, {user.name}</span>
          <button onClick={logout} data-testid="logout-btn">
            Logout
          </button>
        </div>
      ) : (
        <button 
          onClick={() => login('test@example.com', 'password')}
          data-testid="login-btn"
        >
          Login
        </button>
      )}
    </div>
  );
};

const renderWithAuthProvider = (ui: React.ReactElement) => {
  return render(
    <AuthProvider>
      {ui}
    </AuthProvider>
  );
};

describe('AuthProvider', () => {
  it('should provide initial auth state', () => {
    renderWithAuthProvider(<TestAuthComponent />);

    expect(screen.getByTestId('login-btn')).toBeInTheDocument();
    expect(screen.queryByTestId('user-name')).not.toBeInTheDocument();
    expect(screen.queryByTestId('loading')).not.toBeInTheDocument();
  });

  it('should handle successful login', async () => {
    const mockUser = {
      id: '1',
      name: 'John Doe',
      email: 'test@example.com',
      role: 'student' as const
    };

    // Mock successful login response
    server.use(
      rest.post('/api/auth/login', (req, res, ctx) => {
        return res(
          ctx.json({
            user: mockUser,
            token: 'mock-token'
          })
        );
      })
    );

    renderWithAuthProvider(<TestAuthComponent />);

    const loginBtn = screen.getByTestId('login-btn');
    fireEvent.click(loginBtn);

    // Should show loading state
    expect(screen.getByTestId('loading')).toBeInTheDocument();

    // Wait for login to complete
    await waitFor(() => {
      expect(screen.getByTestId('user-name')).toHaveTextContent('Welcome, John Doe');
    });

    expect(screen.queryByTestId('loading')).not.toBeInTheDocument();
    expect(screen.getByTestId('logout-btn')).toBeInTheDocument();
  });

  it('should handle login failure', async () => {
    // Mock login failure
    server.use(
      rest.post('/api/auth/login', (req, res, ctx) => {
        return res(
          ctx.status(401),
          ctx.json({
            message: 'Invalid credentials'
          })
        );
      })
    );

    renderWithAuthProvider(<TestAuthComponent />);

    const loginBtn = screen.getByTestId('login-btn');
    fireEvent.click(loginBtn);

    await waitFor(() => {
      expect(screen.getByTestId('error')).toHaveTextContent('Invalid credentials');
    });

    expect(screen.queryByTestId('loading')).not.toBeInTheDocument();
    expect(screen.queryByTestId('user-name')).not.toBeInTheDocument();
  });

  it('should handle logout', async () => {
    // First, set up successful login
    const mockUser = {
      id: '1',
      name: 'John Doe',
      email: 'test@example.com',
      role: 'student' as const
    };

    server.use(
      rest.post('/api/auth/login', (req, res, ctx) => {
        return res(ctx.json({ user: mockUser, token: 'mock-token' }));
      }),
      rest.post('/api/auth/logout', (req, res, ctx) => {
        return res(ctx.status(200));
      })
    );

    renderWithAuthProvider(<TestAuthComponent />);

    // Login first
    fireEvent.click(screen.getByTestId('login-btn'));
    
    await waitFor(() => {
      expect(screen.getByTestId('user-name')).toBeInTheDocument();
    });

    // Now logout
    fireEvent.click(screen.getByTestId('logout-btn'));

    await waitFor(() => {
      expect(screen.getByTestId('login-btn')).toBeInTheDocument();
    });

    expect(screen.queryByTestId('user-name')).not.toBeInTheDocument();
  });

  it('should restore auth state from localStorage', async () => {
    const mockUser = {
      id: '1',
      name: 'John Doe',
      email: 'test@example.com',
      role: 'student' as const
    };

    // Mock token verification
    server.use(
      rest.get('/api/auth/verify', (req, res, ctx) => {
        return res(ctx.json(mockUser));
      })
    );

    // Set token in localStorage
    localStorage.setItem('authToken', 'valid-token');

    renderWithAuthProvider(<TestAuthComponent />);

    await waitFor(() => {
      expect(screen.getByTestId('user-name')).toHaveTextContent('Welcome, John Doe');
    });
  });
});
```

### **2. Testing Complex Context Interactions**

#### **Testing Quiz Context with State Management**
```typescript
// ✅ Testing complex context state management
import { renderHook, act } from '@testing-library/react';
import { QuizProvider, useQuizState, useQuizActions } from '../contexts/QuizContext';

const wrapper: React.FC<{ children: React.ReactNode }> = ({ children }) => (
  <QuizProvider>
    {children}
  </QuizProvider>
);

describe('QuizContext Integration', () => {
  const mockQuiz: Quiz = {
    id: 'quiz-1',
    title: 'Test Quiz',
    questions: [
      {
        id: 'q1',
        text: 'Question 1',
        options: ['A', 'B', 'C', 'D'],
        correctAnswer: 0
      },
      {
        id: 'q2',
        text: 'Question 2',
        options: ['A', 'B', 'C', 'D'],
        correctAnswer: 1
      }
    ]
  };

  it('should manage quiz state and actions together', async () => {
    const { result } = renderHook(
      () => ({
        state: useQuizState(),
        actions: useQuizActions()
      }),
      { wrapper }
    );

    // Initial state
    expect(result.current.state.currentQuiz).toBeNull();
    expect(result.current.state.isLoading).toBe(false);

    // Load quiz
    await act(async () => {
      await result.current.actions.loadQuiz(mockQuiz.id);
    });

    expect(result.current.state.currentQuiz).toEqual(mockQuiz);
    expect(result.current.state.currentQuestionIndex).toBe(0);
    expect(result.current.state.answers).toEqual({});

    // Submit answer
    act(() => {
      result.current.actions.submitAnswer('q1', 0);
    });

    expect(result.current.state.answers).toEqual({ q1: 0 });

    // Navigate to next question
    act(() => {
      result.current.actions.nextQuestion();
    });

    expect(result.current.state.currentQuestionIndex).toBe(1);

    // Submit second answer
    act(() => {
      result.current.actions.submitAnswer('q2', 1);
    });

    expect(result.current.state.answers).toEqual({ q1: 0, q2: 1 });

    // Complete quiz
    await act(async () => {
      await result.current.actions.completeQuiz();
    });

    expect(result.current.state.isCompleted).toBe(true);
    expect(result.current.state.score).toBe(2); // Both answers correct
  });

  it('should handle concurrent state updates', async () => {
    const { result } = renderHook(
      () => ({
        state: useQuizState(),
        actions: useQuizActions()
      }),
      { wrapper }
    );

    await act(async () => {
      await result.current.actions.loadQuiz(mockQuiz.id);
    });

    // Simulate rapid concurrent updates
    await act(async () => {
      // These should all be handled correctly without race conditions
      result.current.actions.submitAnswer('q1', 0);
      result.current.actions.nextQuestion();
      result.current.actions.submitAnswer('q2', 1);
      result.current.actions.previousQuestion();
    });

    expect(result.current.state.currentQuestionIndex).toBe(0);
    expect(result.current.state.answers).toEqual({ q1: 0, q2: 1 });
  });
});
```

## ⚡ Testing Performance Optimizations

### **1. Testing Memoization**

#### **Testing React.memo and Memoization Hooks**
```typescript
// ✅ Testing memoization effectiveness
import { render, screen, fireEvent } from '@testing-library/react';
import { QuizCard } from '../components/QuizCard';

describe('QuizCard Memoization', () => {
  const mockQuiz: Quiz = {
    id: 'quiz-1',
    title: 'Test Quiz',
    description: 'A test quiz',
    questionCount: 10,
    difficulty: 'medium'
  };

  it('should not re-render when unrelated props change', () => {
    const mockOnSelect = jest.fn();
    const renderSpy = jest.fn();

    // Wrap component to track renders
    const SpiedQuizCard: React.FC<{
      quiz: Quiz;
      onSelect: (quiz: Quiz) => void;
      unrelatedProp: string;
    }> = (props) => {
      renderSpy();
      return <QuizCard quiz={props.quiz} onSelect={props.onSelect} />;
    };

    const { rerender } = render(
      <SpiedQuizCard
        quiz={mockQuiz}
        onSelect={mockOnSelect}
        unrelatedProp="initial"
      />
    );

    expect(renderSpy).toHaveBeenCalledTimes(1);

    // Change unrelated prop
    rerender(
      <SpiedQuizCard
        quiz={mockQuiz}
        onSelect={mockOnSelect}
        unrelatedProp="changed"
      />
    );

    // Should not re-render due to memoization
    expect(renderSpy).toHaveBeenCalledTimes(1);
  });

  it('should re-render when quiz data changes', () => {
    const mockOnSelect = jest.fn();
    const renderSpy = jest.fn();

    const SpiedQuizCard: React.FC<{
      quiz: Quiz;
      onSelect: (quiz: Quiz) => void;
    }> = (props) => {
      renderSpy();
      return <QuizCard quiz={props.quiz} onSelect={props.onSelect} />;
    };

    const { rerender } = render(
      <SpiedQuizCard quiz={mockQuiz} onSelect={mockOnSelect} />
    );

    expect(renderSpy).toHaveBeenCalledTimes(1);

    // Change quiz data
    const updatedQuiz = { ...mockQuiz, title: 'Updated Quiz' };
    rerender(
      <SpiedQuizCard quiz={updatedQuiz} onSelect={mockOnSelect} />
    );

    // Should re-render when quiz changes
    expect(renderSpy).toHaveBeenCalledTimes(2);
  });
});

// ✅ Testing useMemo optimization
describe('Quiz Analytics Memoization', () => {
  it('should only recalculate when dependencies change', () => {
    const expensiveCalculation = jest.fn().mockReturnValue({
      averageScore: 85,
      totalAttempts: 100
    });

    const TestComponent: React.FC<{
      attempts: QuizAttempt[];
      timeRange: string;
      unrelatedProp: string;
    }> = ({ attempts, timeRange, unrelatedProp }) => {
      const analytics = useMemo(() => {
        return expensiveCalculation(attempts, timeRange);
      }, [attempts, timeRange]);

      return <div>{analytics.averageScore}</div>;
    };

    const mockAttempts: QuizAttempt[] = [
      { id: '1', score: 80, totalQuestions: 10, completedAt: new Date() }
    ];

    const { rerender } = render(
      <TestComponent
        attempts={mockAttempts}
        timeRange="7d"
        unrelatedProp="initial"
      />
    );

    expect(expensiveCalculation).toHaveBeenCalledTimes(1);

    // Change unrelated prop
    rerender(
      <TestComponent
        attempts={mockAttempts}
        timeRange="7d"
        unrelatedProp="changed"
      />
    );

    // Should not recalculate
    expect(expensiveCalculation).toHaveBeenCalledTimes(1);

    // Change dependency
    rerender(
      <TestComponent
        attempts={mockAttempts}
        timeRange="30d"
        unrelatedProp="changed"
      />
    );

    // Should recalculate
    expect(expensiveCalculation).toHaveBeenCalledTimes(2);
  });
});
```

### **2. Testing Concurrent Features**

#### **Testing useTransition and Suspense**
```typescript
// ✅ Testing concurrent features
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { Suspense } from 'react';
import { ConcurrentQuizSearch } from '../components/ConcurrentQuizSearch';

describe('Concurrent Features', () => {
  it('should handle transitions without blocking urgent updates', async () => {
    render(
      <Suspense fallback={<div>Loading...</div>}>
        <ConcurrentQuizSearch />
      </Suspense>
    );

    const searchInput = screen.getByPlaceholderText('Search quizzes...');

    // Type in search input rapidly
    fireEvent.change(searchInput, { target: { value: 'r' } });
    fireEvent.change(searchInput, { target: { value: 're' } });
    fireEvent.change(searchInput, { target: { value: 'rea' } });
    fireEvent.change(searchInput, { target: { value: 'reac' } });
    fireEvent.change(searchInput, { target: { value: 'react' } });

    // Input should remain responsive (show latest value)
    expect(searchInput).toHaveValue('react');

    // Search results should eventually appear
    await waitFor(() => {
      expect(screen.getByText(/searching/i)).toBeInTheDocument();
    });

    await waitFor(() => {
      expect(screen.queryByText(/searching/i)).not.toBeInTheDocument();
    });
  });

  it('should show pending state during transitions', async () => {
    const { container } = render(
      <Suspense fallback={<div>Loading...</div>}>
        <ConcurrentQuizSearch />
      </Suspense>
    );

    const searchInput = screen.getByPlaceholderText('Search quizzes...');

    fireEvent.change(searchInput, { target: { value: 'test' } });

    // Should show pending indicator
    await waitFor(() => {
      expect(screen.getByText(/searching/i)).toBeInTheDocument();
    });
  });
});

// ✅ Testing Suspense error boundaries
describe('Suspense Error Handling', () => {
  it('should handle suspense errors gracefully', async () => {
    const ThrowingComponent: React.FC = () => {
      throw new Promise((resolve, reject) => {
        setTimeout(() => reject(new Error('Network error')), 100);
      });
    };

    const ErrorFallback: React.FC<{ error: Error }> = ({ error }) => (
      <div>Error: {error.message}</div>
    );

    const TestErrorBoundary: React.FC<{ children: React.ReactNode }> = ({ children }) => {
      const [hasError, setHasError] = useState(false);
      const [error, setError] = useState<Error | null>(null);

      const componentDidCatch = (error: Error) => {
        setHasError(true);
        setError(error);
      };

      if (hasError) {
        return <ErrorFallback error={error!} />;
      }

      return (
        <Suspense
          fallback={<div>Loading...</div>}
        >
          {children}
        </Suspense>
      );
    };

    render(
      <TestErrorBoundary>
        <ThrowingComponent />
      </TestErrorBoundary>
    );

    // Should show loading initially
    expect(screen.getByText('Loading...')).toBeInTheDocument();

    // Should eventually show error
    await waitFor(() => {
      expect(screen.getByText('Error: Network error')).toBeInTheDocument();
    });
  });
});
```

## 🚀 Integration Testing Patterns

### **1. Component Integration Tests**

#### **Testing Complex Quiz Flow**
```typescript
// ✅ Integration test for complete quiz flow
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { QuizApplication } from '../components/QuizApplication';
import { server } from '../test/mocks/server';
import { rest } from 'msw';

describe('Quiz Application Integration', () => {
  const mockQuiz: Quiz = {
    id: 'quiz-1',
    title: 'React Fundamentals',
    description: 'Test your React knowledge',
    questions: [
      {
        id: 'q1',
        text: 'What is React?',
        options: ['Library', 'Framework', 'Language', 'Tool'],
        correctAnswer: 0
      },
      {
        id: 'q2',
        text: 'What is JSX?',
        options: ['Syntax Extension', 'Framework', 'Library', 'Tool'],
        correctAnswer: 0
      }
    ],
    timeLimit: 300,
    passingScore: 50
  };

  beforeEach(() => {
    // Mock API responses
    server.use(
      rest.get('/api/quizzes/:id', (req, res, ctx) => {
        return res(ctx.json(mockQuiz));
      }),
      rest.post('/api/quizzes/:id/submit', (req, res, ctx) => {
        return res(ctx.json({
          score: 2,
          totalQuestions: 2,
          passed: true,
          answers: req.body
        }));
      })
    );
  });

  it('should complete full quiz flow', async () => {
    const user = userEvent.setup();
    
    render(<QuizApplication quizId="quiz-1" />);

    // Wait for quiz to load
    await waitFor(() => {
      expect(screen.getByText('React Fundamentals')).toBeInTheDocument();
    });

    // Start quiz
    await user.click(screen.getByText('Start Quiz'));

    // Answer first question
    await waitFor(() => {
      expect(screen.getByText('What is React?')).toBeInTheDocument();
    });

    await user.click(screen.getByText('Library'));
    await user.click(screen.getByText('Next'));

    // Answer second question
    await waitFor(() => {
      expect(screen.getByText('What is JSX?')).toBeInTheDocument();
    });

    await user.click(screen.getByText('Syntax Extension'));
    await user.click(screen.getByText('Submit Quiz'));

    // Check results
    await waitFor(() => {
      expect(screen.getByText(/Quiz Complete/i)).toBeInTheDocument();
      expect(screen.getByText(/Score: 2\/2/i)).toBeInTheDocument();
      expect(screen.getByText(/Passed/i)).toBeInTheDocument();
    });
  });

  it('should handle navigation between questions', async () => {
    const user = userEvent.setup();
    
    render(<QuizApplication quizId="quiz-1" />);

    await waitFor(() => {
      expect(screen.getByText('React Fundamentals')).toBeInTheDocument();
    });

    await user.click(screen.getByText('Start Quiz'));

    // Answer first question
    await user.click(screen.getByText('Library'));
    await user.click(screen.getByText('Next'));

    // Go back to first question
    await user.click(screen.getByText('Previous'));

    // Should show first question with selected answer
    await waitFor(() => {
      expect(screen.getByText('What is React?')).toBeInTheDocument();
    });

    const libraryOption = screen.getByLabelText('Library');
    expect(libraryOption).toBeChecked();
  });

  it('should handle quiz timer', async () => {
    jest.useFakeTimers();
    
    render(<QuizApplication quizId="quiz-1" />);

    await waitFor(() => {
      expect(screen.getByText('React Fundamentals')).toBeInTheDocument();
    });

    fireEvent.click(screen.getByText('Start Quiz'));

    // Should show initial time
    await waitFor(() => {
      expect(screen.getByText(/5:00/)).toBeInTheDocument();
    });

    // Fast-forward 1 minute
    act(() => {
      jest.advanceTimersByTime(60000);
    });

    // Should show updated time
    await waitFor(() => {
      expect(screen.getByText(/4:00/)).toBeInTheDocument();
    });

    jest.useRealTimers();
  });
});
```

## 🔗 Navigation

**← Previous:** [Concurrent Features](./concurrent-features.md)  
**→ Next:** [Migration Guide](./migration-guide.md)

---

*Comprehensive testing strategies for advanced React patterns in EdTech applications*