# Performance Optimization - Advanced React Patterns

## 🎯 Overview

Comprehensive guide to React performance optimization techniques for EdTech applications. This document covers memoization, code splitting, bundle optimization, and real-world performance monitoring strategies.

## ⚡ Core Performance Concepts

### **1. React Rendering Behavior**

#### **Understanding React Reconciliation**
```typescript
// ❌ Common performance anti-patterns
const SlowQuizList: React.FC<{ quizzes: Quiz[] }> = ({ quizzes }) => {
  return (
    <div>
      {quizzes.map((quiz, index) => (
        // ❌ Using index as key causes unnecessary re-renders
        <div key={index}>
          <h3>{quiz.title}</h3>
          {/* ❌ Creating new objects/functions on every render */}
          <button onClick={() => handleQuizSelect(quiz)}>
            Start Quiz
          </button>
          {/* ❌ Expensive calculations on every render */}
          <p>Difficulty: {calculateDifficulty(quiz.questions)}</p>
        </div>
      ))}
    </div>
  );
};

// ✅ Optimized version
const OptimizedQuizList: React.FC<{ quizzes: Quiz[] }> = ({ quizzes }) => {
  const handleQuizSelect = useCallback((quiz: Quiz) => {
    // Handle quiz selection
    console.log('Selected quiz:', quiz.id);
  }, []);

  return (
    <div>
      {quizzes.map((quiz) => (
        <OptimizedQuizCard
          key={quiz.id} // ✅ Stable key
          quiz={quiz}
          onSelect={handleQuizSelect}
        />
      ))}
    </div>
  );
};

// ✅ Memoized quiz card component
const OptimizedQuizCard = memo<{
  quiz: Quiz;
  onSelect: (quiz: Quiz) => void;
}>(({ quiz, onSelect }) => {
  // ✅ Memoize expensive calculations
  const difficulty = useMemo(() => 
    calculateDifficulty(quiz.questions), 
    [quiz.questions]
  );

  // ✅ Stable event handler
  const handleClick = useCallback(() => {
    onSelect(quiz);
  }, [quiz, onSelect]);

  return (
    <div className="quiz-card">
      <h3>{quiz.title}</h3>
      <button onClick={handleClick}>Start Quiz</button>
      <p>Difficulty: {difficulty}</p>
    </div>
  );
}, (prevProps, nextProps) => {
  // ✅ Custom comparison for optimal re-rendering
  return (
    prevProps.quiz.id === nextProps.quiz.id &&
    prevProps.quiz.title === nextProps.quiz.title &&
    prevProps.quiz.updatedAt === nextProps.quiz.updatedAt
  );
});
```

### **2. Profiling and Measurement**

#### **React DevTools Profiler Integration**
```typescript
// ✅ Performance monitoring hook
const usePerformanceProfiler = (componentName: string) => {
  const renderStartTime = useRef<number>(0);
  const [renderMetrics, setRenderMetrics] = useState<{
    renderTime: number;
    renderCount: number;
    averageRenderTime: number;
  }>({
    renderTime: 0,
    renderCount: 0,
    averageRenderTime: 0
  });

  // Mark render start
  useLayoutEffect(() => {
    renderStartTime.current = performance.now();
  });

  // Calculate render time
  useEffect(() => {
    const renderTime = performance.now() - renderStartTime.current;
    
    setRenderMetrics(prev => {
      const newRenderCount = prev.renderCount + 1;
      const newAverageRenderTime = 
        (prev.averageRenderTime * prev.renderCount + renderTime) / newRenderCount;
      
      return {
        renderTime,
        renderCount: newRenderCount,
        averageRenderTime: newAverageRenderTime
      };
    });

    // Log slow renders in development
    if (process.env.NODE_ENV === 'development' && renderTime > 16) {
      console.warn(
        `Slow render detected in ${componentName}: ${renderTime.toFixed(2)}ms`
      );
    }
  });

  return renderMetrics;
};

// ✅ Usage in components
const QuizQuestion: React.FC<{ question: Question }> = ({ question }) => {
  const metrics = usePerformanceProfiler('QuizQuestion');
  
  // Component logic here...
  
  return (
    <div className="quiz-question">
      {/* Component content */}
      {process.env.NODE_ENV === 'development' && (
        <div className="debug-info">
          Renders: {metrics.renderCount}, 
          Avg: {metrics.averageRenderTime.toFixed(2)}ms
        </div>
      )}
    </div>
  );
};
```

## 🧠 Advanced Memoization Patterns

### **1. Strategic React.memo Usage**

#### **Complex Component Memoization**
```typescript
// ✅ Advanced memoization for complex quiz components
interface QuizPlayerProps {
  quiz: Quiz;
  currentQuestionIndex: number;
  userAnswers: Record<string, Answer>;
  timeRemaining: number;
  isSubmitting: boolean;
  onAnswerSelect: (questionId: string, answer: Answer) => void;
  onNext: () => void;
  onPrevious: () => void;
  onSubmit: () => void;
}

const QuizPlayer = memo<QuizPlayerProps>(({
  quiz,
  currentQuestionIndex,
  userAnswers,
  timeRemaining,
  isSubmitting,
  onAnswerSelect,
  onNext,
  onPrevious,
  onSubmit
}) => {
  const currentQuestion = quiz.questions[currentQuestionIndex];
  const currentAnswer = userAnswers[currentQuestion.id];

  // ✅ Memoize expensive progress calculation
  const progress = useMemo(() => ({
    completed: Object.keys(userAnswers).length,
    total: quiz.questions.length,
    percentage: Math.round((Object.keys(userAnswers).length / quiz.questions.length) * 100)
  }), [userAnswers, quiz.questions.length]);

  // ✅ Memoize navigation state
  const navigationState = useMemo(() => ({
    canGoNext: currentQuestionIndex < quiz.questions.length - 1,
    canGoPrevious: currentQuestionIndex > 0,
    canSubmit: Object.keys(userAnswers).length === quiz.questions.length
  }), [currentQuestionIndex, quiz.questions.length, userAnswers]);

  return (
    <div className="quiz-player">
      <QuizHeader 
        title={quiz.title}
        progress={progress}
        timeRemaining={timeRemaining}
      />
      
      <QuizQuestion
        question={currentQuestion}
        selectedAnswer={currentAnswer}
        onAnswerSelect={onAnswerSelect}
      />
      
      <QuizNavigation
        {...navigationState}
        isSubmitting={isSubmitting}
        onNext={onNext}
        onPrevious={onPrevious}
        onSubmit={onSubmit}
      />
    </div>
  );
}, (prevProps, nextProps) => {
  // ✅ Custom comparison focusing on what actually matters
  return (
    prevProps.quiz.id === nextProps.quiz.id &&
    prevProps.currentQuestionIndex === nextProps.currentQuestionIndex &&
    prevProps.timeRemaining === nextProps.timeRemaining &&
    prevProps.isSubmitting === nextProps.isSubmitting &&
    // Deep comparison for answers (only if keys changed)
    Object.keys(prevProps.userAnswers).length === Object.keys(nextProps.userAnswers).length &&
    Object.keys(prevProps.userAnswers).every(key => 
      prevProps.userAnswers[key] === nextProps.userAnswers[key]
    )
  );
});
```

### **2. useMemo and useCallback Optimization**

#### **Expensive Computation Memoization**
```typescript
// ✅ Optimizing expensive quiz analytics
const useQuizAnalytics = (quizzes: Quiz[], userAttempts: QuizAttempt[]) => {
  // ✅ Memoize expensive statistical calculations
  const analytics = useMemo(() => {
    const startTime = performance.now();
    
    const stats = {
      totalQuizzes: quizzes.length,
      totalAttempts: userAttempts.length,
      averageScore: 0,
      difficultyDistribution: {} as Record<string, number>,
      topicPerformance: {} as Record<string, { attempts: number; averageScore: number }>,
      learningProgress: [] as { date: string; score: number }[]
    };

    // Calculate average score
    if (userAttempts.length > 0) {
      stats.averageScore = userAttempts.reduce((sum, attempt) => 
        sum + (attempt.score / attempt.totalQuestions), 0) / userAttempts.length * 100;
    }

    // Calculate difficulty distribution
    quizzes.forEach(quiz => {
      const difficulty = calculateDifficultyLevel(quiz);
      stats.difficultyDistribution[difficulty] = 
        (stats.difficultyDistribution[difficulty] || 0) + 1;
    });

    // Calculate topic performance
    userAttempts.forEach(attempt => {
      const quiz = quizzes.find(q => q.id === attempt.quizId);
      if (quiz) {
        const topic = quiz.topic;
        if (!stats.topicPerformance[topic]) {
          stats.topicPerformance[topic] = { attempts: 0, averageScore: 0 };
        }
        
        const topicStats = stats.topicPerformance[topic];
        topicStats.averageScore = 
          (topicStats.averageScore * topicStats.attempts + 
           (attempt.score / attempt.totalQuestions) * 100) / 
          (topicStats.attempts + 1);
        topicStats.attempts += 1;
      }
    });

    // Calculate learning progress (last 30 days)
    const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
    const recentAttempts = userAttempts
      .filter(attempt => new Date(attempt.completedAt) >= thirtyDaysAgo)
      .sort((a, b) => new Date(a.completedAt).getTime() - new Date(b.completedAt).getTime());

    stats.learningProgress = recentAttempts.map(attempt => ({
      date: new Date(attempt.completedAt).toISOString().split('T')[0],
      score: (attempt.score / attempt.totalQuestions) * 100
    }));

    const endTime = performance.now();
    console.log(`Analytics calculation took ${endTime - startTime} milliseconds`);
    
    return stats;
  }, [quizzes, userAttempts]);

  // ✅ Memoize chart data transformations
  const chartData = useMemo(() => ({
    difficultyChart: Object.entries(analytics.difficultyDistribution).map(([key, value]) => ({
      name: key,
      value
    })),
    
    topicChart: Object.entries(analytics.topicPerformance).map(([topic, stats]) => ({
      topic,
      score: Math.round(stats.averageScore),
      attempts: stats.attempts
    })),
    
    progressChart: analytics.learningProgress.map((point, index) => ({
      ...point,
      trend: index > 0 ? point.score - analytics.learningProgress[index - 1].score : 0
    }))
  }), [analytics]);

  return { analytics, chartData };
};

// ✅ Optimized callback functions
const useOptimizedQuizHandlers = (dispatch: React.Dispatch<QuizAction>) => {
  const handlers = useMemo(() => ({
    onAnswerSelect: (questionId: string, answer: Answer) => {
      dispatch({
        type: 'ANSWER_QUESTION',
        payload: { questionId, answer }
      });
    },

    onNavigateToQuestion: (questionIndex: number) => {
      dispatch({
        type: 'NAVIGATE_TO_QUESTION',
        payload: { questionIndex }
      });
    },

    onTimeUpdate: (timeRemaining: number) => {
      dispatch({
        type: 'UPDATE_TIME',
        payload: { timeRemaining }
      });
    },

    onSubmitQuiz: async (answers: Record<string, Answer>) => {
      dispatch({ type: 'SUBMIT_QUIZ_START' });
      
      try {
        const results = await submitQuizAnswers(answers);
        dispatch({
          type: 'SUBMIT_QUIZ_SUCCESS',
          payload: results
        });
      } catch (error) {
        dispatch({
          type: 'SUBMIT_QUIZ_ERROR',
          payload: { error: error.message }
        });
      }
    }
  }), [dispatch]);

  return handlers;
};
```

## 📦 Code Splitting and Lazy Loading

### **1. Route-Based Code Splitting**

#### **Strategic Route Splitting**
```typescript
// ✅ Route-level code splitting for EdTech app
import { lazy, Suspense } from 'react';
import { Routes, Route } from 'react-router-dom';

// ✅ Lazy load main sections
const Dashboard = lazy(() => 
  import('../pages/Dashboard').then(module => ({
    default: module.Dashboard
  }))
);

const QuizSection = lazy(() => 
  import('../pages/QuizSection').then(module => ({
    default: module.QuizSection
  }))
);

const ProgressSection = lazy(() => 
  import('../pages/ProgressSection').then(module => ({
    default: module.ProgressSection
  }))
);

const AdminPanel = lazy(() => 
  import('../pages/AdminPanel').then(module => ({
    default: module.AdminPanel
  }))
);

// ✅ Loading components with skeleton UI
const DashboardSkeleton = () => (
  <div className="dashboard-skeleton">
    <div className="skeleton-header" />
    <div className="skeleton-stats-grid">
      {[...Array(4)].map((_, i) => (
        <div key={i} className="skeleton-stat-card" />
      ))}
    </div>
    <div className="skeleton-chart" />
  </div>
);

const QuizSkeleton = () => (
  <div className="quiz-skeleton">
    <div className="skeleton-quiz-header" />
    <div className="skeleton-question" />
    <div className="skeleton-options">
      {[...Array(4)].map((_, i) => (
        <div key={i} className="skeleton-option" />
      ))}
    </div>
  </div>
);

// ✅ App routing with suspense boundaries
const AppRoutes: React.FC = () => {
  const { user } = useAuth();

  return (
    <Routes>
      <Route 
        path="/dashboard" 
        element={
          <Suspense fallback={<DashboardSkeleton />}>
            <Dashboard />
          </Suspense>
        } 
      />
      
      <Route 
        path="/quiz/*" 
        element={
          <Suspense fallback={<QuizSkeleton />}>
            <QuizSection />
          </Suspense>
        } 
      />
      
      <Route 
        path="/progress" 
        element={
          <Suspense fallback={<div>Loading progress...</div>}>
            <ProgressSection />
          </Suspense>
        } 
      />
      
      {user?.role === 'admin' && (
        <Route 
          path="/admin/*" 
          element={
            <Suspense fallback={<div>Loading admin panel...</div>}>
              <AdminPanel />
            </Suspense>
          } 
        />
      )}
    </Routes>
  );
};
```

### **2. Component-Level Code Splitting**

#### **Conditional Component Loading**
```typescript
// ✅ Lazy load heavy components conditionally
const useConditionalComponent = <T extends React.ComponentType<any>>(
  condition: boolean,
  importFn: () => Promise<{ default: T }>
) => {
  const [Component, setComponent] = useState<T | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<Error | null>(null);

  useEffect(() => {
    if (condition && !Component) {
      setLoading(true);
      setError(null);
      
      importFn()
        .then(module => {
          setComponent(() => module.default);
        })
        .catch(err => {
          setError(err);
        })
        .finally(() => {
          setLoading(false);
        });
    }
  }, [condition, Component, importFn]);

  return { Component, loading, error };
};

// ✅ Usage for advanced quiz features
const QuizPlayer: React.FC<{ quiz: Quiz }> = ({ quiz }) => {
  const [showAdvancedFeatures, setShowAdvancedFeatures] = useState(false);
  
  // Only load advanced chart library when needed
  const { 
    Component: AdvancedAnalytics, 
    loading: analyticsLoading 
  } = useConditionalComponent(
    showAdvancedFeatures,
    () => import('../components/AdvancedAnalytics')
  );

  // Only load equation editor for math quizzes
  const { 
    Component: EquationEditor, 
    loading: editorLoading 
  } = useConditionalComponent(
    quiz.type === 'math',
    () => import('../components/EquationEditor')
  );

  return (
    <div className="quiz-player">
      <QuizContent quiz={quiz} />
      
      {quiz.type === 'math' && (
        <div className="equation-section">
          {editorLoading ? (
            <div>Loading equation editor...</div>
          ) : EquationEditor ? (
            <EquationEditor />
          ) : null}
        </div>
      )}
      
      <button onClick={() => setShowAdvancedFeatures(!showAdvancedFeatures)}>
        {showAdvancedFeatures ? 'Hide' : 'Show'} Advanced Analytics
      </button>
      
      {showAdvancedFeatures && (
        <div className="advanced-analytics">
          {analyticsLoading ? (
            <div>Loading analytics...</div>
          ) : AdvancedAnalytics ? (
            <AdvancedAnalytics quizData={quiz} />
          ) : null}
        </div>
      )}
    </div>
  );
};
```

## 🗜️ Bundle Optimization

### **1. Webpack Bundle Analysis**

#### **Bundle Optimization Configuration**
```typescript
// ✅ Webpack optimization configuration
// webpack.config.js (or vite.config.ts)
export default {
  optimization: {
    splitChunks: {
      chunks: 'all',
      cacheGroups: {
        // Vendor chunk for stable dependencies
        vendor: {
          test: /[\\/]node_modules[\\/]/,
          name: 'vendors',
          chunks: 'all',
          priority: 20
        },
        
        // UI library chunk
        ui: {
          test: /[\\/]node_modules[\\/](@mui|antd|react-bootstrap)[\\/]/,
          name: 'ui',
          chunks: 'all',
          priority: 30
        },
        
        // Chart libraries chunk
        charts: {
          test: /[\\/]node_modules[\\/](chart\.js|recharts|d3)[\\/]/,
          name: 'charts',
          chunks: 'all',
          priority: 30
        },
        
        // Common application code
        common: {
          name: 'common',
          minChunks: 2,
          chunks: 'all',
          priority: 10,
          reuseExistingChunk: true
        }
      }
    }
  }
};

// ✅ Dynamic imports for tree shaking
// Instead of importing entire libraries
import * as _ from 'lodash'; // ❌ Imports entire library

// Use specific imports
import { debounce } from 'lodash-es'; // ✅ Tree-shakable
import { format } from 'date-fns/format'; // ✅ Tree-shakable
import { Button, TextField } from '@mui/material'; // ✅ Tree-shakable
```

### **2. Image and Asset Optimization**

#### **Optimized Asset Loading**
```typescript
// ✅ Progressive image loading hook
const useProgressiveImage = (src: string, placeholder?: string) => {
  const [imgSrc, setImgSrc] = useState(placeholder);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const img = new Image();
    
    img.onload = () => {
      setImgSrc(src);
      setIsLoading(false);
    };
    
    img.onerror = () => {
      setError('Failed to load image');
      setIsLoading(false);
    };
    
    img.src = src;
    
    return () => {
      img.onload = null;
      img.onerror = null;
    };
  }, [src]);

  return { imgSrc, isLoading, error };
};

// ✅ Optimized quiz image component
const QuizImage: React.FC<{
  src: string;
  alt: string;
  placeholder?: string;
}> = ({ src, alt, placeholder = '/images/quiz-placeholder.webp' }) => {
  const { imgSrc, isLoading, error } = useProgressiveImage(src, placeholder);

  if (error) {
    return <div className="image-error">Failed to load image</div>;
  }

  return (
    <div className="quiz-image-container">
      <img
        src={imgSrc}
        alt={alt}
        className={`quiz-image ${isLoading ? 'loading' : 'loaded'}`}
        loading="lazy" // Native lazy loading
        decoding="async" // Non-blocking decoding
      />
      {isLoading && (
        <div className="image-skeleton" />
      )}
    </div>
  );
};

// ✅ WebP with fallback support
const OptimizedImage: React.FC<{
  src: string;
  alt: string;
  webpSrc?: string;
}> = ({ src, alt, webpSrc }) => {
  return (
    <picture>
      {webpSrc && <source srcSet={webpSrc} type="image/webp" />}
      <img src={src} alt={alt} loading="lazy" />
    </picture>
  );
};
```

## 📊 Performance Monitoring

### **1. Real-User Monitoring (RUM)**

#### **Performance Metrics Collection**
```typescript
// ✅ Performance monitoring hook
const usePerformanceMonitoring = () => {
  const [metrics, setMetrics] = useState<{
    fcp: number | null; // First Contentful Paint
    lcp: number | null; // Largest Contentful Paint
    fid: number | null; // First Input Delay
    cls: number | null; // Cumulative Layout Shift
  }>({
    fcp: null,
    lcp: null,
    fid: null,
    cls: null
  });

  useEffect(() => {
    // Measure FCP and LCP
    const observer = new PerformanceObserver((list) => {
      list.getEntries().forEach((entry) => {
        if (entry.entryType === 'paint') {
          if (entry.name === 'first-contentful-paint') {
            setMetrics(prev => ({ ...prev, fcp: entry.startTime }));
          }
        }
        
        if (entry.entryType === 'largest-contentful-paint') {
          setMetrics(prev => ({ ...prev, lcp: entry.startTime }));
        }
        
        if (entry.entryType === 'first-input') {
          setMetrics(prev => ({ ...prev, fid: entry.processingStart - entry.startTime }));
        }
        
        if (entry.entryType === 'layout-shift' && !entry.hadRecentInput) {
          setMetrics(prev => ({ ...prev, cls: (prev.cls || 0) + entry.value }));
        }
      });
    });

    observer.observe({ entryTypes: ['paint', 'largest-contentful-paint', 'first-input', 'layout-shift'] });

    return () => observer.disconnect();
  }, []);

  // Send metrics to analytics
  useEffect(() => {
    const sendMetrics = () => {
      if (metrics.fcp && metrics.lcp) {
        // Send to your analytics service
        if (window.gtag) {
          window.gtag('event', 'timing_complete', {
            name: 'page_load',
            value: Math.round(metrics.lcp)
          });
        }
        
        // Log performance issues
        if (metrics.lcp > 2500) {
          console.warn('Poor LCP performance:', metrics.lcp);
        }
        
        if (metrics.fid && metrics.fid > 100) {
          console.warn('Poor FID performance:', metrics.fid);
        }
        
        if (metrics.cls && metrics.cls > 0.1) {
          console.warn('Poor CLS performance:', metrics.cls);
        }
      }
    };

    // Send metrics after a delay to ensure all measurements are complete
    const timer = setTimeout(sendMetrics, 5000);
    return () => clearTimeout(timer);
  }, [metrics]);

  return metrics;
};

// ✅ Performance debugging component (dev only)
const PerformanceDebugger: React.FC = () => {
  const metrics = usePerformanceMonitoring();
  
  if (process.env.NODE_ENV !== 'development') {
    return null;
  }

  return (
    <div className="performance-debugger">
      <h4>Performance Metrics</h4>
      <ul>
        <li>FCP: {metrics.fcp ? `${metrics.fcp.toFixed(2)}ms` : 'Measuring...'}</li>
        <li>LCP: {metrics.lcp ? `${metrics.lcp.toFixed(2)}ms` : 'Measuring...'}</li>
        <li>FID: {metrics.fid ? `${metrics.fid.toFixed(2)}ms` : 'Measuring...'}</li>
        <li>CLS: {metrics.cls ? metrics.cls.toFixed(3) : 'Measuring...'}</li>
      </ul>
    </div>
  );
};
```

### **2. Memory Leak Detection**

#### **Memory Management Patterns**
```typescript
// ✅ Memory leak detection hook
const useMemoryLeakDetection = (componentName: string) => {
  const mountTime = useRef(Date.now());
  const memoryCheckInterval = useRef<NodeJS.Timeout | null>(null);
  
  useEffect(() => {
    if (process.env.NODE_ENV === 'development') {
      const checkMemory = () => {
        if ('memory' in performance) {
          const memInfo = (performance as any).memory;
          const memoryUsage = {
            usedJSHeapSize: memInfo.usedJSHeapSize,
            totalJSHeapSize: memInfo.totalJSHeapSize,
            jsHeapSizeLimit: memInfo.jsHeapSizeLimit
          };
          
          // Warn if memory usage is high
          const usagePercent = (memoryUsage.usedJSHeapSize / memoryUsage.jsHeapSizeLimit) * 100;
          
          if (usagePercent > 80) {
            console.warn(
              `High memory usage in ${componentName}: ${usagePercent.toFixed(2)}%`,
              memoryUsage
            );
          }
        }
      };

      // Check memory every 30 seconds
      memoryCheckInterval.current = setInterval(checkMemory, 30000);
      
      return () => {
        if (memoryCheckInterval.current) {
          clearInterval(memoryCheckInterval.current);
        }
      };
    }
  }, [componentName]);

  useEffect(() => {
    return () => {
      const lifetime = Date.now() - mountTime.current;
      
      // Log long-lived components
      if (lifetime > 300000) { // 5 minutes
        console.log(
          `Long-lived component unmounted: ${componentName}, lifetime: ${lifetime}ms`
        );
      }
    };
  }, [componentName]);
};

// ✅ Cleanup patterns for subscriptions
const useCleanupSubscriptions = () => {
  const subscriptionsRef = useRef<Array<() => void>>([]);

  const addCleanup = useCallback((cleanup: () => void) => {
    subscriptionsRef.current.push(cleanup);
  }, []);

  useEffect(() => {
    return () => {
      // Clean up all subscriptions
      subscriptionsRef.current.forEach(cleanup => {
        try {
          cleanup();
        } catch (error) {
          console.error('Cleanup error:', error);
        }
      });
      subscriptionsRef.current = [];
    };
  }, []);

  return addCleanup;
};

// ✅ Usage in components
const QuizPlayer: React.FC<{ quizId: string }> = ({ quizId }) => {
  useMemoryLeakDetection('QuizPlayer');
  const addCleanup = useCleanupSubscriptions();
  
  useEffect(() => {
    // WebSocket connection
    const ws = new WebSocket(`/api/quiz/${quizId}/live`);
    
    ws.onmessage = (event) => {
      // Handle real-time updates
    };
    
    // Register cleanup
    addCleanup(() => {
      ws.close();
    });
    
    // Timer
    const timer = setInterval(() => {
      // Update timer
    }, 1000);
    
    addCleanup(() => {
      clearInterval(timer);
    });
    
    // Event listeners
    const handleVisibilityChange = () => {
      // Handle tab visibility
    };
    
    document.addEventListener('visibilitychange', handleVisibilityChange);
    
    addCleanup(() => {
      document.removeEventListener('visibilitychange', handleVisibilityChange);
    });
  }, [quizId, addCleanup]);

  return <div>Quiz Player Content</div>;
};
```

## 🔗 Navigation

**← Previous:** [Context API Patterns](./context-api-patterns.md)  
**→ Next:** [Concurrent Features](./concurrent-features.md)

---

*Advanced React performance optimization techniques for scalable EdTech applications*