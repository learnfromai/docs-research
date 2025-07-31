# Best Practices - Svelte/SvelteKit Development

## 🎯 Comprehensive Development Guidelines

Essential best practices for building scalable, maintainable, and high-performance EdTech applications with Svelte/SvelteKit.

{% hint style="info" %}
**Focus**: These practices are specifically tailored for educational technology platforms, with considerations for Philippine market conditions and international deployment requirements.
{% endhint %}

## 📚 Table of Contents

1. [Project Architecture & Structure](#-project-architecture--structure)
2. [Component Design Patterns](#-component-design-patterns)
3. [State Management Best Practices](#-state-management-best-practices)
4. [Performance Optimization](#-performance-optimization)
5. [Code Organization & Standards](#-code-organization--standards)
6. [Testing Strategies](#-testing-strategies)
7. [SEO & Accessibility](#-seo--accessibility)
8. [Security Considerations](#-security-considerations)
9. [EdTech-Specific Patterns](#-edtech-specific-patterns)
10. [Deployment & Monitoring](#-deployment--monitoring)

## 🏗️ Project Architecture & Structure

### Recommended Directory Structure

```
src/
├── routes/                     # SvelteKit file-based routing
│   ├── (app)/                 # Route groups for authenticated pages
│   │   ├── dashboard/
│   │   ├── quiz/
│   │   └── profile/
│   ├── (auth)/                # Authentication routes
│   │   ├── login/
│   │   └── register/
│   ├── api/                   # API endpoints
│   │   ├── auth/
│   │   ├── questions/
│   │   └── progress/
│   ├── +layout.svelte         # Root layout
│   ├── +page.svelte          # Home page
│   └── +error.svelte         # Error boundary
├── lib/                       # Shared application code
│   ├── components/            # Reusable UI components
│   │   ├── ui/               # Basic UI elements
│   │   ├── forms/            # Form components
│   │   ├── quiz/             # Quiz-specific components
│   │   └── charts/           # Data visualization
│   ├── stores/               # Svelte stores
│   │   ├── auth.ts
│   │   ├── quiz.ts
│   │   └── progress.ts
│   ├── utils/                # Utility functions
│   │   ├── validation.ts
│   │   ├── formatting.ts
│   │   └── analytics.ts
│   ├── types/                # TypeScript type definitions
│   ├── services/             # API services
│   └── config/              # Configuration files
├── static/                    # Static assets
├── tests/                     # Test files
└── docs/                      # Project documentation
```

### Route Organization Best Practices

```typescript
// Use route groups for logical organization
// (app) - Authenticated pages
// (auth) - Authentication pages
// (public) - Public pages

// src/routes/(app)/quiz/[category]/+page.svelte
// src/routes/(app)/dashboard/+page.svelte
// src/routes/(auth)/login/+page.svelte
// src/routes/(public)/about/+page.svelte

// Shared layouts for route groups
// src/routes/(app)/+layout.svelte - Authenticated layout
// src/routes/(auth)/+layout.svelte - Authentication layout
```

### Configuration Management

```typescript
// src/lib/config/environment.ts
import { dev } from '$app/environment';
import { env } from '$env/dynamic/private';

export const config = {
  app: {
    name: 'Philippine Licensure Exam Review',
    version: '1.0.0',
    isDevelopment: dev
  },
  
  database: {
    url: env.DATABASE_URL,
    ssl: !dev
  },
  
  auth: {
    jwtSecret: env.JWT_SECRET,
    sessionTimeout: 24 * 60 * 60 * 1000, // 24 hours
    passwordMinLength: 8
  },
  
  quiz: {
    defaultTimeLimit: 60, // seconds per question
    maxQuestionsPerSession: 50,
    passingScore: 70 // percentage
  },
  
  analytics: {
    enabled: !dev,
    googleAnalyticsId: env.GA_MEASUREMENT_ID
  }
} as const;

// Type-safe configuration access
export type Config = typeof config;
```

## 🧩 Component Design Patterns

### Component Composition Pattern

```svelte
<!-- ✅ Good: Composable components -->
<!-- src/lib/components/quiz/QuizContainer.svelte -->
<script lang="ts">
  import QuizHeader from './QuizHeader.svelte';
  import QuestionCard from './QuestionCard.svelte';
  import QuizProgress from './QuizProgress.svelte';
  import QuizResults from './QuizResults.svelte';
  
  export let quiz: Quiz;
  export let currentQuestion: number;
</script>

<div class="quiz-container">
  <QuizHeader {quiz} />
  <QuizProgress current={currentQuestion} total={quiz.questions.length} />
  
  {#if currentQuestion < quiz.questions.length}
    <QuestionCard 
      question={quiz.questions[currentQuestion]}
      on:answer
      on:next
    />
  {:else}
    <QuizResults {quiz} />
  {/if}
</div>
```

### Props and Event Pattern

```svelte
<!-- ✅ Good: Clear prop definitions and event dispatching -->
<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  
  // Props with types and defaults
  export let question: Question;
  export let timeLimit: number = 60;
  export let showTimer: boolean = true;
  export let disabled: boolean = false;
  
  // Event dispatcher
  const dispatch = createEventDispatcher<{
    answer: { questionId: string; answer: number; timeUsed: number };
    timeout: { questionId: string };
  }>();
  
  // Internal state
  let selectedAnswer: number | null = null;
  let timeRemaining = timeLimit;
  
  // Computed values
  $: isAnswered = selectedAnswer !== null;
  $: timePercentage = (timeRemaining / timeLimit) * 100;
  
  function handleSubmit() {
    if (selectedAnswer !== null) {
      dispatch('answer', {
        questionId: question.id,
        answer: selectedAnswer,
        timeUsed: timeLimit - timeRemaining
      });
    }
  }
</script>
```

### Slot Pattern for Flexibility

```svelte
<!-- ✅ Good: Flexible component with slots -->
<!-- src/lib/components/ui/Modal.svelte -->
<script lang="ts">
  export let open: boolean = false;
  export let title: string = '';
  export let size: 'sm' | 'md' | 'lg' = 'md';
  
  function closeModal() {
    open = false;
  }
</script>

{#if open}
  <div class="modal-backdrop" on:click={closeModal}>
    <div class="modal modal-{size}" on:click|stopPropagation>
      <header class="modal-header">
        <slot name="header">
          <h2>{title}</h2>
        </slot>
        <button on:click={closeModal}>×</button>
      </header>
      
      <main class="modal-body">
        <slot />
      </main>
      
      <footer class="modal-footer">
        <slot name="footer">
          <button on:click={closeModal}>Close</button>
        </slot>
      </footer>
    </div>
  </div>
{/if}

<!-- Usage -->
<!-- 
<Modal bind:open={showModal} title="Quiz Results">
  <svelte:fragment slot="header">
    <h2>🎉 Quiz Completed!</h2>
  </svelte:fragment>
  
  <QuizResultsContent {results} />
  
  <svelte:fragment slot="footer">
    <button on:click={retakeQuiz}>Retake Quiz</button>
    <button on:click={viewExplanations}>View Explanations</button>
  </svelte:fragment>
</Modal>
-->
```

### Component Lifecycle Best Practices

```svelte
<script lang="ts">
  import { onMount, onDestroy, beforeUpdate, afterUpdate } from 'svelte';
  
  let mounted = false;
  let cleanup: (() => void)[] = [];
  
  // ✅ Good: Proper lifecycle management
  onMount(async () => {
    mounted = true;
    
    // Initialize analytics
    const analytics = await import('$lib/utils/analytics');
    analytics.trackPageView(window.location.pathname);
    
    // Set up event listeners
    const handleBeforeUnload = (e: BeforeUnloadEvent) => {
      if (hasUnsavedChanges) {
        e.preventDefault();
        e.returnValue = '';
      }
    };
    
    window.addEventListener('beforeunload', handleBeforeUnload);
    cleanup.push(() => window.removeEventListener('beforeunload', handleBeforeUnload));
    
    // Set up intervals
    const interval = setInterval(saveProgress, 30000); // Save every 30 seconds
    cleanup.push(() => clearInterval(interval));
  });
  
  onDestroy(() => {
    // Clean up all resources
    cleanup.forEach(fn => fn());
  });
  
  beforeUpdate(() => {
    // Validate props before update
    if (mounted && !question) {
      console.warn('Question prop is required');
    }
  });
  
  afterUpdate(() => {
    // Update analytics after DOM changes
    if (mounted) {
      analytics.trackInteraction('component_updated');
    }
  });
</script>
```

## 🗄️ State Management Best Practices

### Store Organization Pattern

```typescript
// src/lib/stores/quiz.ts
import { writable, derived, readable } from 'svelte/store';
import type { Question, QuizSession, QuizSettings } from '$lib/types';

// ✅ Good: Organized store structure
interface QuizState {
  currentSession: QuizSession | null;
  questions: Question[];
  settings: QuizSettings;
  isLoading: boolean;
  error: string | null;
}

const initialState: QuizState = {
  currentSession: null,
  questions: [],
  settings: {
    timeLimit: 60,
    showExplanations: true,
    shuffleQuestions: false
  },
  isLoading: false,
  error: null
};

function createQuizStore() {
  const { subscribe, set, update } = writable<QuizState>(initialState);
  
  return {
    subscribe,
    
    // Actions
    async startQuiz(category: string, questionCount: number) {
      update(state => ({ ...state, isLoading: true, error: null }));
      
      try {
        const response = await fetch(`/api/questions?category=${category}&limit=${questionCount}`);
        const data = await response.json();
        
        if (!response.ok) throw new Error(data.error);
        
        const session: QuizSession = {
          id: crypto.randomUUID(),
          category,
          questions: data.questions,
          answers: new Array(data.questions.length).fill(null),
          startTime: new Date(),
          currentQuestionIndex: 0
        };
        
        update(state => ({
          ...state,
          currentSession: session,
          questions: data.questions,
          isLoading: false
        }));
      } catch (error) {
        update(state => ({
          ...state,
          error: error.message,
          isLoading: false
        }));
      }
    },
    
    answerQuestion(questionIndex: number, answer: number) {
      update(state => {
        if (state.currentSession) {
          state.currentSession.answers[questionIndex] = answer;
        }
        return state;
      });
    },
    
    nextQuestion() {
      update(state => {
        if (state.currentSession) {
          state.currentSession.currentQuestionIndex++;
        }
        return state;
      });
    },
    
    updateSettings(newSettings: Partial<QuizSettings>) {
      update(state => ({
        ...state,
        settings: { ...state.settings, ...newSettings }
      }));
    },
    
    reset() {
      set(initialState);
    }
  };
}

export const quizStore = createQuizStore();

// Derived stores for computed values
export const currentQuestion = derived(
  quizStore,
  $quiz => $quiz.currentSession?.questions[$quiz.currentSession.currentQuestionIndex]
);

export const quizProgress = derived(
  quizStore,
  $quiz => {
    if (!$quiz.currentSession) return { answered: 0, total: 0, percentage: 0 };
    
    const answered = $quiz.currentSession.answers.filter(a => a !== null).length;
    const total = $quiz.currentSession.questions.length;
    
    return {
      answered,
      total,
      percentage: total > 0 ? (answered / total) * 100 : 0
    };
  }
);
```

### Persistent Store Pattern

```typescript
// src/lib/stores/persistent.ts
import { writable } from 'svelte/store';
import { browser } from '$app/environment';

function createPersistentStore<T>(key: string, initialValue: T) {
  let stored: T = initialValue;
  
  if (browser) {
    const item = localStorage.getItem(key);
    if (item) {
      try {
        stored = JSON.parse(item);
      } catch (e) {
        console.warn(`Failed to parse stored value for ${key}:`, e);
      }
    }
  }
  
  const { subscribe, set, update } = writable<T>(stored);
  
  return {
    subscribe,
    set: (value: T) => {
      if (browser) {
        localStorage.setItem(key, JSON.stringify(value));
      }
      set(value);
    },
    update: (fn: (value: T) => T) => {
      update((value) => {
        const newValue = fn(value);
        if (browser) {
          localStorage.setItem(key, JSON.stringify(newValue));
        }
        return newValue;
      });
    }
  };
}

// Usage
export const userPreferences = createPersistentStore('user-preferences', {
  theme: 'light',
  language: 'en',
  notificationsEnabled: true
});
```

## ⚡ Performance Optimization

### Code Splitting and Lazy Loading

```typescript
// ✅ Good: Route-based code splitting (automatic in SvelteKit)
// Each route is automatically code-split

// Manual code splitting for heavy components
// src/lib/components/ChartContainer.svelte
<script lang="ts">
  import { onMount } from 'svelte';
  
  let ChartComponent: any = null;
  let loading = true;
  
  onMount(async () => {
    // Lazy load heavy chart library
    const module = await import('./Chart.svelte');
    ChartComponent = module.default;
    loading = false;
  });
</script>

{#if loading}
  <div class="chart-skeleton">Loading chart...</div>
{:else if ChartComponent}
  <svelte:component this={ChartComponent} {...$$props} />
{/if}
```

### Image Optimization

```svelte
<!-- ✅ Good: Optimized image loading -->
<script lang="ts">
  export let src: string;
  export let alt: string;
  export let width: number;
  export let height: number;
  
  let loaded = false;
  let error = false;
  
  function handleLoad() {
    loaded = true;
  }
  
  function handleError() {
    error = true;
  }
</script>

<div class="image-container" style="width: {width}px; height: {height}px;">
  {#if !loaded && !error}
    <div class="image-skeleton"></div>
  {/if}
  
  <img
    {src}
    {alt}
    {width}
    {height}
    loading="lazy"
    decoding="async"
    class:loaded
    on:load={handleLoad}
    on:error={handleError}
  />
  
  {#if error}
    <div class="image-error">Failed to load image</div>
  {/if}
</div>

<style>
  .image-container {
    position: relative;
    overflow: hidden;
  }
  
  img {
    opacity: 0;
    transition: opacity 0.3s;
  }
  
  img.loaded {
    opacity: 1;
  }
  
  .image-skeleton {
    position: absolute;
    inset: 0;
    background: linear-gradient(90deg, #f0f0f0 25%, #e0e0e0 50%, #f0f0f0 75%);
    background-size: 200% 100%;
    animation: loading 1.5s infinite;
  }
  
  @keyframes loading {
    0% { background-position: 200% 0; }
    100% { background-position: -200% 0; }
  }
</style>
```

### Bundle Size Optimization

```javascript
// vite.config.js
import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vite';

export default defineConfig({
  plugins: [sveltekit()],
  
  build: {
    rollupOptions: {
      output: {
        manualChunks: {
          // Separate vendor code
          vendor: ['svelte', '@sveltejs/kit'],
          // Group related utilities
          utils: ['date-fns', 'lodash-es'],
          // Separate heavy libraries
          charts: ['chart.js', 'd3'],
          // UI components
          ui: ['$lib/components/ui']
        }
      }
    }
  },
  
  // Optimize dependencies
  optimizeDeps: {
    include: ['chart.js', 'date-fns']
  }
});
```

### Memory Management

```svelte
<script lang="ts">
  import { onDestroy } from 'svelte';
  
  let observers: IntersectionObserver[] = [];
  let intervals: NodeJS.Timeout[] = [];
  let eventCleanup: (() => void)[] = [];
  
  // ✅ Good: Proper cleanup
  function setupIntersectionObserver(element: HTMLElement) {
    const observer = new IntersectionObserver((entries) => {
      // Handle intersection
    });
    
    observer.observe(element);
    observers.push(observer);
  }
  
  function startPolling() {
    const interval = setInterval(() => {
      // Polling logic
    }, 5000);
    
    intervals.push(interval);
  }
  
  onDestroy(() => {
    // Clean up observers
    observers.forEach(observer => observer.disconnect());
    
    // Clear intervals
    intervals.forEach(interval => clearInterval(interval));
    
    // Clean up event listeners
    eventCleanup.forEach(cleanup => cleanup());
  });
</script>
```

## 📝 Code Organization & Standards

### TypeScript Best Practices

```typescript
// src/lib/types/quiz.ts
// ✅ Good: Comprehensive type definitions

export interface Question {
  readonly id: string;
  readonly text: string;
  readonly options: readonly string[];
  readonly correctAnswer: number;
  readonly explanation: string;
  readonly category: QuestionCategory;
  readonly difficulty: QuestionDifficulty;
  readonly tags: readonly string[];
  readonly metadata: QuestionMetadata;
}

export interface QuestionMetadata {
  readonly createdAt: Date;
  readonly updatedAt: Date;
  readonly author: string;
  readonly reviewedBy?: string;
  readonly usageCount: number;
  readonly averageTime: number; // seconds
  readonly successRate: number; // percentage
}

export type QuestionCategory = 
  | 'nursing'
  | 'engineering'
  | 'teaching'
  | 'cpa'
  | 'medical'
  | 'law';

export type QuestionDifficulty = 'easy' | 'medium' | 'hard';

export interface QuizSession {
  readonly id: string;
  readonly userId: string;
  readonly category: QuestionCategory;
  readonly questions: readonly Question[];
  readonly answers: (number | null)[];
  readonly startTime: Date;
  readonly endTime?: Date;
  currentQuestionIndex: number;
  readonly settings: QuizSettings;
}

export interface QuizSettings {
  readonly timeLimit: number; // seconds per question
  readonly showExplanations: boolean;
  readonly shuffleQuestions: boolean;
  readonly shuffleOptions: boolean;
  readonly allowReview: boolean;
}

// Utility types for API responses
export interface ApiResponse<T> {
  readonly success: boolean;
  readonly data?: T;
  readonly error?: string;
  readonly metadata?: {
    readonly page: number;
    readonly limit: number;
    readonly total: number;
  };
}

export type QuestionResponse = ApiResponse<Question[]>;
export type QuizSessionResponse = ApiResponse<QuizSession>;
```

### Naming Conventions

```typescript
// ✅ Good: Consistent naming conventions

// Constants - SCREAMING_SNAKE_CASE
export const MAX_QUESTIONS_PER_QUIZ = 50;
export const DEFAULT_TIME_LIMIT = 60;

// Types and Interfaces - PascalCase
export interface UserProfile { }
export type QuizResult = { };

// Variables and functions - camelCase
const currentUser = getCurrentUser();
const isQuizActive = checkQuizStatus();

// Components - PascalCase
// QuestionCard.svelte
// QuizContainer.svelte
// UserProfile.svelte

// Stores - camelCase
export const userStore = createUserStore();
export const quizProgress = derived(/* ... */);

// CSS classes - kebab-case
.quiz-container { }
.question-card { }
.user-profile { }

// File names - kebab-case for routes, PascalCase for components
// routes/quiz/[category]/+page.svelte
// components/QuestionCard.svelte
// utils/format-date.ts
```

### Error Handling Patterns

```typescript
// src/lib/utils/error-handling.ts

export class AppError extends Error {
  constructor(
    message: string,
    public code: string,
    public statusCode: number = 500,
    public metadata?: Record<string, any>
  ) {
    super(message);
    this.name = 'AppError';
  }
}

export class ValidationError extends AppError {
  constructor(message: string, field: string) {
    super(message, 'VALIDATION_ERROR', 400, { field });
    this.name = 'ValidationError';
  }
}

export class NetworkError extends AppError {
  constructor(message: string, originalError?: Error) {
    super(message, 'NETWORK_ERROR', 0, { originalError });
    this.name = 'NetworkError';
  }
}

// Error handling utility
export async function handleAsync<T>(
  promise: Promise<T>
): Promise<[T | null, AppError | null]> {
  try {
    const data = await promise;
    return [data, null];
  } catch (error) {
    if (error instanceof AppError) {
      return [null, error];
    }
    
    // Convert unknown errors to AppError
    return [null, new AppError(
      error.message || 'Unknown error occurred',
      'UNKNOWN_ERROR',
      500,
      { originalError: error }
    )];
  }
}

// Usage in components
// const [data, error] = await handleAsync(fetchQuestions());
```

## 🧪 Testing Strategies

### Unit Testing Best Practices

```typescript
// tests/components/QuestionCard.test.ts
import { describe, it, expect, vi } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/svelte';
import QuestionCard from '$lib/components/quiz/QuestionCard.svelte';
import type { Question } from '$lib/types';

const mockQuestion: Question = {
  id: '1',
  text: 'What is the capital of Philippines?',
  options: ['Manila', 'Cebu', 'Davao', 'Quezon City'],
  correctAnswer: 0,
  explanation: 'Manila is the capital city.',
  category: 'geography',
  difficulty: 'easy',
  tags: ['geography', 'philippines'],
  metadata: {
    createdAt: new Date(),
    updatedAt: new Date(),
    author: 'test-author',
    usageCount: 0,
    averageTime: 30,
    successRate: 85
  }
};

describe('QuestionCard', () => {
  it('renders question text and options', () => {
    render(QuestionCard, {
      props: {
        question: mockQuestion,
        questionNumber: 1,
        totalQuestions: 10,
        selectedAnswer: null
      }
    });
    
    expect(screen.getByText(mockQuestion.text)).toBeInTheDocument();
    mockQuestion.options.forEach(option => {
      expect(screen.getByText(option)).toBeInTheDocument();
    });
  });
  
  it('dispatches answer event when option is selected', async () => {
    const component = render(QuestionCard, {
      props: {
        question: mockQuestion,
        questionNumber: 1,
        totalQuestions: 10,
        selectedAnswer: null
      }
    });
    
    const answerHandler = vi.fn();
    component.component.$on('answer', answerHandler);
    
    const firstOption = screen.getByText(mockQuestion.options[0]);
    await fireEvent.click(firstOption);
    
    expect(answerHandler).toHaveBeenCalledWith(
      expect.objectContaining({
        detail: expect.objectContaining({
          questionId: mockQuestion.id,
          answer: 0
        })
      })
    );
  });
  
  it('shows explanation after answer is selected', async () => {
    render(QuestionCard, {
      props: {
        question: mockQuestion,
        questionNumber: 1,
        totalQuestions: 10,
        selectedAnswer: 0
      }
    });
    
    expect(screen.getByText(mockQuestion.explanation)).toBeInTheDocument();
  });
});
```

### Integration Testing

```typescript
// tests/integration/quiz-flow.test.ts
import { describe, it, expect, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/svelte';
import Quiz from '$lib/components/Quiz.svelte';

// Mock API responses
beforeEach(() => {
  global.fetch = vi.fn(() =>
    Promise.resolve({
      ok: true,
      json: () => Promise.resolve({
        questions: [
          {
            id: '1',
            text: 'Sample question?',
            options: ['A', 'B', 'C', 'D'],
            correctAnswer: 0,
            explanation: 'Sample explanation'
          }
        ]
      })
    })
  );
});

describe('Quiz Flow Integration', () => {
  it('completes full quiz workflow', async () => {
    render(Quiz, { props: { category: 'nursing' } });
    
    // Wait for questions to load
    await waitFor(() => {
      expect(screen.getByText('Sample question?')).toBeInTheDocument();
    });
    
    // Select an answer
    const option = screen.getByText('A');
    await fireEvent.click(option);
    
    // Check explanation appears
    expect(screen.getByText('Sample explanation')).toBeInTheDocument();
    
    // Complete quiz
    const finishButton = screen.getByText('Finish Quiz');
    await fireEvent.click(finishButton);
    
    // Verify results are shown
    await waitFor(() => {
      expect(screen.getByText(/Quiz Results/i)).toBeInTheDocument();
    });
  });
});
```

## 🔍 SEO & Accessibility

### SEO Optimization

```svelte
<!-- src/routes/quiz/[category]/+page.svelte -->
<script lang="ts">
  import { page } from '$app/stores';
  
  $: category = $page.params.category;
  $: categoryName = getCategoryDisplayName(category);
  
  $: metaTitle = `${categoryName} Practice Quiz - Philippine Licensure Exam Review`;
  $: metaDescription = `Master your ${categoryName} with our comprehensive practice quiz. Over 1000+ questions designed for Philippine licensure exam success.`;
</script>

<svelte:head>
  <!-- Essential meta tags -->
  <title>{metaTitle}</title>
  <meta name="description" content={metaDescription} />
  
  <!-- Open Graph / Facebook -->
  <meta property="og:type" content="website" />
  <meta property="og:url" content={$page.url.href} />
  <meta property="og:title" content={metaTitle} />
  <meta property="og:description" content={metaDescription} />
  <meta property="og:image" content="/images/quiz-{category}-preview.jpg" />
  
  <!-- Twitter -->
  <meta property="twitter:card" content="summary_large_image" />
  <meta property="twitter:url" content={$page.url.href} />
  <meta property="twitter:title" content={metaTitle} />
  <meta property="twitter:description" content={metaDescription} />
  <meta property="twitter:image" content="/images/quiz-{category}-preview.jpg" />
  
  <!-- Structured data -->
  <script type="application/ld+json">
    {JSON.stringify({
      "@context": "https://schema.org",
      "@type": "Quiz",
      "name": metaTitle,
      "description": metaDescription,
      "about": {
        "@type": "Thing",
        "name": categoryName
      },
      "educationalLevel": "Professional",
      "assesses": `${categoryName} knowledge for Philippine licensure exam`,
      "typicalAgeRange": "22-"
    })}
  </script>
</svelte:head>
```

### Accessibility Best Practices

```svelte
<!-- ✅ Good: Accessible quiz component -->
<script lang="ts">
  export let question: Question;
  export let selectedAnswer: number | null;
  
  let questionElement: HTMLElement;
  
  // Announce question changes to screen readers
  $: if (questionElement && question) {
    questionElement.focus();
  }
</script>

<div class="question-container" role="group" aria-labelledby="question-text">
  <h2 
    id="question-text" 
    bind:this={questionElement}
    tabindex="-1"
    class="question-text"
  >
    {question.text}
  </h2>
  
  <fieldset class="options">
    <legend class="sr-only">Select your answer</legend>
    
    {#each question.options as option, index}
      <label class="option-label">
        <input
          type="radio"
          name="answer"
          value={index}
          bind:group={selectedAnswer}
          aria-describedby={selectedAnswer === index ? `explanation-${question.id}` : undefined}
        />
        <span class="option-text">{option}</span>
      </label>
    {/each}
  </fieldset>
  
  {#if selectedAnswer !== null}
    <div 
      id="explanation-{question.id}"
      class="explanation"
      role="region"
      aria-label="Answer explanation"
    >
      <h3>Explanation:</h3>
      <p>{question.explanation}</p>
    </div>
  {/if}
</div>

<style>
  /* Screen reader only class */
  .sr-only {
    position: absolute;
    width: 1px;
    height: 1px;
    padding: 0;
    margin: -1px;
    overflow: hidden;
    clip: rect(0, 0, 0, 0);
    white-space: nowrap;
    border: 0;
  }
  
  .question-text:focus {
    outline: 2px solid #3b82f6;
    outline-offset: 2px;
  }
  
  .option-label {
    display: block;
    padding: 1rem;
    cursor: pointer;
    border: 2px solid transparent;
    border-radius: 0.5rem;
    transition: border-color 0.2s;
  }
  
  .option-label:hover,
  .option-label:focus-within {
    border-color: #3b82f6;
  }
  
  input[type="radio"] {
    margin-right: 0.5rem;
  }
  
  input[type="radio"]:focus {
    outline: 2px solid #3b82f6;
    outline-offset: 2px;
  }
</style>
```

## 🔒 Security Considerations

### Input Validation and Sanitization

```typescript
// src/lib/utils/validation.ts
import { z } from 'zod';

// ✅ Good: Comprehensive validation schemas
export const QuestionSchema = z.object({
  text: z.string().min(10).max(500),
  options: z.array(z.string().min(1).max(200)).min(2).max(6),
  correctAnswer: z.number().int().min(0),
  explanation: z.string().min(10).max(1000),
  category: z.enum(['nursing', 'engineering', 'teaching', 'cpa']),
  difficulty: z.enum(['easy', 'medium', 'hard'])
});

export const UserRegistrationSchema = z.object({
  email: z.string().email().max(255),
  password: z.string().min(8).max(128)
    .regex(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]/, 
           'Password must contain uppercase, lowercase, number, and special character'),
  name: z.string().min(2).max(100).regex(/^[a-zA-Z\s]+$/, 'Name can only contain letters and spaces'),
  phoneNumber: z.string().regex(/^\+63\d{10}$/, 'Please enter a valid Philippine phone number')
});

export function validateInput<T>(schema: z.ZodSchema<T>, data: unknown): 
  { success: true; data: T } | { success: false; errors: string[] } {
  try {
    const validated = schema.parse(data);
    return { success: true, data: validated };
  } catch (error) {
    if (error instanceof z.ZodError) {
      return { 
        success: false, 
        errors: error.errors.map(e => `${e.path.join('.')}: ${e.message}`) 
      };
    }
    return { success: false, errors: ['Validation failed'] };
  }
}
```

### Authentication Security

```typescript
// src/routes/api/auth/login/+server.ts
import { json } from '@sveltejs/kit';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { rateLimit } from '$lib/utils/rate-limit';

export const POST: RequestHandler = async ({ request, cookies, clientAddress }) => {
  // ✅ Good: Rate limiting
  const rateLimitResult = await rateLimit('login', clientAddress, {
    maxAttempts: 5,
    windowMs: 15 * 60 * 1000 // 15 minutes
  });
  
  if (!rateLimitResult.allowed) {
    return json(
      { error: 'Too many login attempts. Please try again later.' },
      { status: 429 }
    );
  }
  
  const { email, password } = await request.json();
  
  // Validate input
  const validation = validateInput(LoginSchema, { email, password });
  if (!validation.success) {
    return json({ error: validation.errors[0] }, { status: 400 });
  }
  
  try {
    const user = await getUserByEmail(validation.data.email);
    
    // ✅ Good: Constant-time comparison to prevent timing attacks
    const isValidPassword = user && 
      await bcrypt.compare(validation.data.password, user.hashedPassword);
    
    if (!user || !isValidPassword) {
      // Don't reveal whether email exists
      return json({ error: 'Invalid email or password' }, { status: 401 });
    }
    
    // Generate secure session token
    const sessionToken = jwt.sign(
      { userId: user.id, email: user.email },
      JWT_SECRET,
      { expiresIn: '24h', issuer: 'edtech-platform' }
    );
    
    // ✅ Good: Secure cookie settings
    cookies.set('session', sessionToken, {
      path: '/',
      httpOnly: true,
      secure: true,
      sameSite: 'strict',
      maxAge: 24 * 60 * 60 // 24 hours
    });
    
    return json({
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        role: user.role
      }
    });
  } catch (error) {
    console.error('Login error:', error);
    return json({ error: 'Login failed' }, { status: 500 });
  }
};
```

## 🎓 EdTech-Specific Patterns

### Progress Tracking Implementation

```typescript
// src/lib/stores/progress.ts
import { writable, derived } from 'svelte/store';
import { browser } from '$app/environment';

interface UserProgress {
  questionsAttempted: number;
  questionsCorrect: number;
  categoriesStudied: string[];
  timeSpent: number; // minutes
  streakDays: number;
  lastActiveDate: string;
  weakAreas: { category: string; accuracy: number }[];
  achievements: Achievement[];
}

interface Achievement {
  id: string;
  name: string;
  description: string;
  unlockedAt: Date;
  icon: string;
}

function createProgressStore() {
  const { subscribe, set, update } = writable<UserProgress>({
    questionsAttempted: 0,
    questionsCorrect: 0,
    categoriesStudied: [],
    timeSpent: 0,
    streakDays: 0,
    lastActiveDate: new Date().toISOString().split('T')[0],
    weakAreas: [],
    achievements: []
  });
  
  return {
    subscribe,
    
    recordQuizSession(session: QuizSession) {
      update(progress => {
        const correctAnswers = session.answers.filter((answer, index) => 
          answer === session.questions[index].correctAnswer
        ).length;
        
        const sessionTime = session.endTime ? 
          (session.endTime.getTime() - session.startTime.getTime()) / (1000 * 60) : 0;
        
        // Update basic stats
        progress.questionsAttempted += session.questions.length;
        progress.questionsCorrect += correctAnswers;
        progress.timeSpent += sessionTime;
        
        // Update categories studied
        if (!progress.categoriesStudied.includes(session.category)) {
          progress.categoriesStudied.push(session.category);
        }
        
        // Update streak
        const today = new Date().toISOString().split('T')[0];
        const lastActive = new Date(progress.lastActiveDate);
        const todayDate = new Date(today);
        const daysDiff = Math.floor((todayDate.getTime() - lastActive.getTime()) / (1000 * 60 * 60 * 24));
        
        if (daysDiff === 1) {
          progress.streakDays++;
        } else if (daysDiff > 1) {
          progress.streakDays = 1;
        }
        progress.lastActiveDate = today;
        
        // Update weak areas
        const accuracy = (correctAnswers / session.questions.length) * 100;
        const existingWeakArea = progress.weakAreas.find(w => w.category === session.category);
        
        if (existingWeakArea) {
          existingWeakArea.accuracy = (existingWeakArea.accuracy + accuracy) / 2;
        } else {
          progress.weakAreas.push({ category: session.category, accuracy });
        }
        
        // Check for achievements
        progress.achievements = [
          ...progress.achievements,
          ...checkForNewAchievements(progress)
        ];
        
        return progress;
      });
      
      // Persist to server
      if (browser) {
        this.syncToServer();
      }
    },
    
    async syncToServer() {
      const currentProgress = get(this);
      
      try {
        await fetch('/api/user/progress', {
          method: 'PUT',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(currentProgress)
        });
      } catch (error) {
        console.error('Failed to sync progress:', error);
      }
    }
  };
}

function checkForNewAchievements(progress: UserProgress): Achievement[] {
  const newAchievements: Achievement[] = [];
  
  // Check for streak achievements
  if (progress.streakDays === 7 && !progress.achievements.find(a => a.id === 'week_streak')) {
    newAchievements.push({
      id: 'week_streak',
      name: 'Week Warrior',
      description: 'Studied for 7 consecutive days',
      unlockedAt: new Date(),
      icon: '🔥'
    });
  }
  
  // Check for question milestones
  if (progress.questionsAttempted >= 100 && !progress.achievements.find(a => a.id === 'century')) {
    newAchievements.push({
      id: 'century',
      name: 'Century Club',
      description: 'Answered 100 questions',
      unlockedAt: new Date(),
      icon: '💯'
    });
  }
  
  return newAchievements;
}

export const progressStore = createProgressStore();

// Derived stores for analytics
export const progressAnalytics = derived(
  progressStore,
  $progress => ({
    overallAccuracy: $progress.questionsAttempted > 0 ? 
      ($progress.questionsCorrect / $progress.questionsAttempted) * 100 : 0,
    averageTimePerQuestion: $progress.questionsAttempted > 0 ?
      ($progress.timeSpent * 60) / $progress.questionsAttempted : 0,
    strongestCategory: $progress.weakAreas.length > 0 ?
      $progress.weakAreas.reduce((max, area) => area.accuracy > max.accuracy ? area : max) : null,
    weakestCategory: $progress.weakAreas.length > 0 ?
      $progress.weakAreas.reduce((min, area) => area.accuracy < min.accuracy ? area : min) : null
  })
);
```

### Adaptive Learning Algorithm

```typescript
// src/lib/utils/adaptive-learning.ts
interface QuestionAttempt {
  questionId: string;
  correct: boolean;
  timeSpent: number;
  difficulty: 'easy' | 'medium' | 'hard';
  category: string;
}

interface LearningProfile {
  strongCategories: string[];
  weakCategories: string[];
  optimalDifficulty: 'easy' | 'medium' | 'hard';
  averageResponseTime: number;
  learningVelocity: number; // improvement rate
}

export class AdaptiveLearningEngine {
  private attempts: QuestionAttempt[] = [];
  
  recordAttempt(attempt: QuestionAttempt) {
    this.attempts.push(attempt);
    
    // Keep only recent attempts for analysis
    if (this.attempts.length > 1000) {
      this.attempts = this.attempts.slice(-500);
    }
  }
  
  generateLearningProfile(): LearningProfile {
    const recentAttempts = this.attempts.slice(-100);
    
    if (recentAttempts.length === 0) {
      return {
        strongCategories: [],
        weakCategories: [],
        optimalDifficulty: 'easy',
        averageResponseTime: 60,
        learningVelocity: 0
      };
    }
    
    // Analyze performance by category
    const categoryPerformance = new Map<string, { correct: number; total: number }>();
    
    recentAttempts.forEach(attempt => {
      const current = categoryPerformance.get(attempt.category) || { correct: 0, total: 0 };
      current.total++;
      if (attempt.correct) current.correct++;
      categoryPerformance.set(attempt.category, current);
    });
    
    const categoryAccuracies = Array.from(categoryPerformance.entries())
      .map(([category, stats]) => ({
        category,
        accuracy: stats.correct / stats.total
      }))
      .sort((a, b) => b.accuracy - a.accuracy);
    
    const strongCategories = categoryAccuracies
      .filter(c => c.accuracy >= 0.8)
      .map(c => c.category);
    
    const weakCategories = categoryAccuracies
      .filter(c => c.accuracy < 0.6)
      .map(c => c.category);
    
    // Determine optimal difficulty
    const difficultyPerformance = ['easy', 'medium', 'hard'].map(difficulty => {
      const attempts = recentAttempts.filter(a => a.difficulty === difficulty);
      const accuracy = attempts.length > 0 ? 
        attempts.filter(a => a.correct).length / attempts.length : 0;
      
      return { difficulty, accuracy, count: attempts.length };
    });
    
    // Find difficulty with 70-80% accuracy (optimal challenge)
    const optimalDifficulty = difficultyPerformance
      .find(d => d.accuracy >= 0.7 && d.accuracy <= 0.8 && d.count >= 5)?.difficulty ||
      (difficultyPerformance.find(d => d.accuracy >= 0.6)?.difficulty) ||
      'easy';
    
    // Calculate learning velocity (improvement over time)
    const oldAttempts = this.attempts.slice(0, 50);
    const newAttempts = this.attempts.slice(-50);
    
    const oldAccuracy = oldAttempts.length > 0 ?
      oldAttempts.filter(a => a.correct).length / oldAttempts.length : 0;
    const newAccuracy = newAttempts.length > 0 ?
      newAttempts.filter(a => a.correct).length / newAttempts.length : 0;
    
    const learningVelocity = newAccuracy - oldAccuracy;
    
    const averageResponseTime = recentAttempts.reduce((sum, a) => sum + a.timeSpent, 0) / 
      recentAttempts.length;
    
    return {
      strongCategories,
      weakCategories,
      optimalDifficulty: optimalDifficulty as 'easy' | 'medium' | 'hard',
      averageResponseTime,
      learningVelocity
    };
  }
  
  recommendNextQuestions(
    availableQuestions: Question[],
    count: number = 10
  ): Question[] {
    const profile = this.generateLearningProfile();
    
    // Prioritize weak categories (60%), maintain strong categories (30%), explore new (10%)
    const weakCount = Math.floor(count * 0.6);
    const strongCount = Math.floor(count * 0.3);
    const exploreCount = count - weakCount - strongCount;
    
    const recommendations: Question[] = [];
    
    // Add questions from weak categories
    const weakQuestions = availableQuestions.filter(q => 
      profile.weakCategories.includes(q.category) &&
      (q.difficulty === 'easy' || q.difficulty === profile.optimalDifficulty)
    );
    recommendations.push(...this.selectRandomQuestions(weakQuestions, weakCount));
    
    // Add questions from strong categories
    const strongQuestions = availableQuestions.filter(q =>
      profile.strongCategories.includes(q.category) &&
      q.difficulty === profile.optimalDifficulty
    );
    recommendations.push(...this.selectRandomQuestions(strongQuestions, strongCount));
    
    // Add exploratory questions
    const exploreCategories = availableQuestions
      .map(q => q.category)
      .filter(c => !profile.strongCategories.includes(c) && !profile.weakCategories.includes(c));
    
    const exploreQuestions = availableQuestions.filter(q =>
      exploreCategories.includes(q.category) &&
      q.difficulty === 'easy'
    );
    recommendations.push(...this.selectRandomQuestions(exploreQuestions, exploreCount));
    
    // Fill remaining with any available questions
    const remaining = count - recommendations.length;
    if (remaining > 0) {
      const allQuestions = availableQuestions.filter(q => 
        !recommendations.some(r => r.id === q.id)
      );
      recommendations.push(...this.selectRandomQuestions(allQuestions, remaining));
    }
    
    return recommendations.slice(0, count);
  }
  
  private selectRandomQuestions(questions: Question[], count: number): Question[] {
    if (count >= questions.length) return [...questions];
    
    const shuffled = [...questions].sort(() => Math.random() - 0.5);
    return shuffled.slice(0, count);
  }
}
```

## 🚀 Deployment & Monitoring

### Production Configuration

```typescript
// src/hooks.server.ts
import { sequence } from '@sveltejs/kit/hooks';
import { handleAuth } from '$lib/server/auth';
import { handleLogging } from '$lib/server/logging';
import { handleRateLimit } from '$lib/server/rate-limit';
import { handleSecurity } from '$lib/server/security';

export const handle = sequence(
  handleSecurity,
  handleRateLimit,
  handleAuth,
  handleLogging
);

// Error handling
export const handleError = ({ error, event }) => {
  console.error('Server error:', error, {
    url: event.url.pathname,
    method: event.request.method,
    userAgent: event.request.headers.get('user-agent')
  });
  
  return {
    message: 'Internal server error',
    code: 'INTERNAL_ERROR'
  };
};
```

### Performance Monitoring

```typescript
// src/lib/utils/performance-monitor.ts
export class PerformanceMonitor {
  private static instance: PerformanceMonitor;
  private metrics: Map<string, number[]> = new Map();
  
  static getInstance(): PerformanceMonitor {
    if (!this.instance) {
      this.instance = new PerformanceMonitor();
    }
    return this.instance;
  }
  
  startMeasure(name: string): () => void {
    const startTime = performance.now();
    
    return () => {
      const endTime = performance.now();
      const duration = endTime - startTime;
      
      this.recordMetric(name, duration);
    };
  }
  
  recordMetric(name: string, value: number) {
    const existing = this.metrics.get(name) || [];
    existing.push(value);
    
    // Keep only recent measurements
    if (existing.length > 100) {
      existing.splice(0, existing.length - 100);
    }
    
    this.metrics.set(name, existing);
  }
  
  getMetrics() {
    const result: Record<string, {
      count: number;
      average: number;
      min: number;
      max: number;
      p95: number;
    }> = {};
    
    this.metrics.forEach((values, name) => {
      const sorted = [...values].sort((a, b) => a - b);
      const sum = values.reduce((a, b) => a + b, 0);
      
      result[name] = {
        count: values.length,
        average: sum / values.length,
        min: sorted[0],
        max: sorted[sorted.length - 1],
        p95: sorted[Math.floor(sorted.length * 0.95)]
      };
    });
    
    return result;
  }
  
  async reportMetrics() {
    const metrics = this.getMetrics();
    
    try {
      await fetch('/api/metrics', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          timestamp: new Date().toISOString(),
          metrics,
          userAgent: navigator.userAgent,
          url: window.location.href
        })
      });
    } catch (error) {
      console.error('Failed to report metrics:', error);
    }
  }
}

// Usage in components
export function withPerformanceTracking<T extends (...args: any[]) => any>(
  fn: T,
  name: string
): T {
  return ((...args: Parameters<T>) => {
    const monitor = PerformanceMonitor.getInstance();
    const stopMeasure = monitor.startMeasure(name);
    
    try {
      const result = fn(...args);
      
      if (result instanceof Promise) {
        return result.finally(stopMeasure);
      }
      
      stopMeasure();
      return result;
    } catch (error) {
      stopMeasure();
      throw error;
    }
  }) as T;
}
```

## 📈 Key Performance Indicators

### Metrics to Track

1. **Technical Performance**
   - Page load times (target: < 2s on 3G)
   - Time to Interactive (target: < 3s)
   - Core Web Vitals scores
   - Bundle size growth
   - API response times

2. **User Experience**
   - Quiz completion rates
   - Average session duration
   - Question response times
   - Error rates and types
   - Mobile vs desktop usage

3. **Educational Effectiveness**
   - Learning progress velocity
   - Knowledge retention rates
   - Difficulty progression success
   - Category mastery rates
   - User engagement patterns

### Implementation Example

```typescript
// src/lib/utils/analytics.ts
interface AnalyticsEvent {
  event: string;
  category: string;
  label?: string;
  value?: number;
  properties?: Record<string, any>;
}

export class EducationAnalytics {
  trackQuizStart(category: string, questionCount: number) {
    this.track({
      event: 'quiz_started',
      category: 'engagement',
      label: category,
      value: questionCount,
      properties: {
        quiz_category: category,
        question_count: questionCount,
        timestamp: new Date().toISOString()
      }
    });
  }
  
  trackQuestionAnswer(
    questionId: string, 
    correct: boolean, 
    timeSpent: number,
    difficulty: string
  ) {
    this.track({
      event: 'question_answered',
      category: 'learning',
      label: correct ? 'correct' : 'incorrect',
      value: timeSpent,
      properties: {
        question_id: questionId,
        correct,
        time_spent: timeSpent,
        difficulty
      }
    });
  }
  
  private track(event: AnalyticsEvent) {
    // Send to multiple analytics providers
    this.sendToGoogleAnalytics(event);
    this.sendToCustomAnalytics(event);
  }
  
  private sendToGoogleAnalytics(event: AnalyticsEvent) {
    if (typeof gtag !== 'undefined') {
      gtag('event', event.event, {
        event_category: event.category,
        event_label: event.label,
        value: event.value,
        custom_parameters: event.properties
      });
    }
  }
  
  private async sendToCustomAnalytics(event: AnalyticsEvent) {
    try {
      await fetch('/api/analytics', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(event)
      });
    } catch (error) {
      console.error('Analytics error:', error);
    }
  }
}
```

---

## 🔗 Continue Reading

- **Next**: [Migration Strategy](./migration-strategy.md) - Framework migration planning
- **Previous**: [Implementation Guide](./implementation-guide.md) - Getting started guide
- **Testing**: [Testing Strategies](./testing-strategies.md) - Quality assurance approaches

---

## 📚 Best Practices References

1. **[Svelte Best Practices](https://svelte.dev/docs/best-practices)** - Official Svelte guidelines
2. **[SvelteKit Documentation](https://kit.svelte.dev/docs)** - Framework-specific patterns
3. **[Web.dev Performance](https://web.dev/performance/)** - Web performance best practices
4. **[A11y Project](https://www.a11yproject.com/)** - Accessibility guidelines
5. **[OWASP Security Guide](https://owasp.org/www-project-web-security-testing-guide/)** - Web security practices
6. **[TypeScript Handbook](https://www.typescriptlang.org/docs/)** - TypeScript best practices
7. **[EdTech Development Guidelines](https://www.edtechtools.org/development-guidelines)** - Educational technology standards

---

*Best Practices Guide completed January 2025 | Comprehensive guidelines for scalable EdTech development*