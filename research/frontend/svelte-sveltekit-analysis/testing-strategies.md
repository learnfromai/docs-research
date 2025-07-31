# Testing Strategies - Svelte/SvelteKit

## 🧪 Comprehensive Testing Approach

Complete testing strategy for SvelteKit EdTech applications, covering unit testing, integration testing, end-to-end testing, and performance testing with specific focus on educational platform requirements.

{% hint style="info" %}
**Testing Philosophy**: Testing should ensure educational content is delivered reliably and accurately, as student learning outcomes depend on platform stability and correctness.
{% endhint %}

## 🎯 Testing Strategy Overview

### Testing Pyramid for EdTech Applications

```
                    ▲
                   ╱ ╲
                  ╱ E2E ╲
                 ╱ Tests ╲
                ╱_________╲
               ╱           ╲
              ╱ Integration ╲
             ╱    Tests     ╲
            ╱_______________╲
           ╱                 ╲
          ╱   Unit Tests      ╲
         ╱   (Components,     ╲
        ╱   Utils, Stores)    ╲
       ╱_____________________╲

70% Unit Tests - Fast, isolated, comprehensive coverage
20% Integration Tests - API, database, service interactions  
10% E2E Tests - Critical user journeys, quiz workflows
```

### Testing Tools Stack

| Testing Type | Primary Tool | Alternative | Purpose |
|--------------|-------------|-------------|---------|
| **Unit Testing** | Vitest | Jest | Component and utility testing |
| **Component Testing** | @testing-library/svelte | Svelte Testing Library | DOM-based component testing |
| **Integration Testing** | Vitest + MSW | Supertest | API and service testing |
| **E2E Testing** | Playwright | Cypress | Full user journey testing |
| **Visual Testing** | Percy/Chromatic | Storybook | UI regression testing |
| **Performance Testing** | Lighthouse CI | WebPageTest | Performance regression testing |
| **Accessibility Testing** | axe-core | Pa11y | A11y compliance testing |

## 🔧 Test Environment Setup

### Project Configuration

```typescript
// vitest.config.ts
import { defineConfig } from 'vitest/config';
import { sveltekit } from '@sveltejs/kit/vite';
import { svelte } from '@sveltejs/vite-plugin-svelte';

export default defineConfig({
  plugins: [sveltekit()],
  
  test: {
    include: ['src/**/*.{test,spec}.{js,ts}'],
    environment: 'jsdom',
    setupFiles: ['src/test-setup.ts'],
    coverage: {
      provider: 'v8',
      reporter: ['text', 'json', 'html'],
      exclude: [
        'node_modules/',
        'src/test-setup.ts',
        '**/*.d.ts',
        '**/*.config.*',
        'build/',
        '.svelte-kit/'
      ],
      thresholds: {
        global: {
          branches: 80,
          functions: 80,
          lines: 80,
          statements: 80
        }
      }
    },
    reporters: ['verbose', 'junit'],
    outputFile: {
      junit: './test-results/junit.xml'
    }
  },
  
  resolve: {
    alias: {
      $lib: new URL('./src/lib', import.meta.url).pathname,
      $app: new URL('./node_modules/@sveltejs/kit/src/runtime/app', import.meta.url).pathname
    }
  }
});
```

### Test Setup File

```typescript
// src/test-setup.ts
import '@testing-library/jest-dom';
import { vi } from 'vitest';

// Mock SvelteKit modules
vi.mock('$app/environment', () => ({
  browser: false,
  dev: true,
  building: false
}));

vi.mock('$app/navigation', () => ({
  goto: vi.fn(),
  invalidate: vi.fn(),
  invalidateAll: vi.fn(),
  preloadData: vi.fn(),
  preloadCode: vi.fn(),
  onNavigate: vi.fn(),
  beforeNavigate: vi.fn(),
  afterNavigate: vi.fn()
}));

vi.mock('$app/stores', () => {
  const { readable, writable } = require('svelte/store');
  
  return {
    page: readable({
      url: new URL('http://localhost:3000'),
      params: {},
      route: { id: null },
      status: 200,
      error: null,
      data: {},
      form: undefined
    }),
    navigating: readable(null),
    updated: readable(false)
  };
});

// Mock fetch globally
global.fetch = vi.fn();

// Mock IntersectionObserver
global.IntersectionObserver = vi.fn(() => ({
  observe: vi.fn(),
  disconnect: vi.fn(),
  unobserve: vi.fn()
}));

// Mock ResizeObserver
global.ResizeObserver = vi.fn(() => ({
  observe: vi.fn(),
  disconnect: vi.fn(),
  unobserve: vi.fn()
}));

// Mock localStorage
Object.defineProperty(window, 'localStorage', {
  value: {
    getItem: vi.fn(),
    setItem: vi.fn(),
    removeItem: vi.fn(),
    clear: vi.fn()
  }
});

// Mock window.matchMedia
Object.defineProperty(window, 'matchMedia', {
  writable: true,
  value: vi.fn().mockImplementation(query => ({
    matches: false,
    media: query,
    onchange: null,
    addListener: vi.fn(), // deprecated
    removeListener: vi.fn(), // deprecated
    addEventListener: vi.fn(),
    removeEventListener: vi.fn(),
    dispatchEvent: vi.fn()
  }))
});

// Console error suppression for known issues
const originalError = console.error;
console.error = (...args) => {
  if (
    typeof args[0] === 'string' &&
    args[0].includes('Error: Could not resolve')
  ) {
    return;
  }
  originalError.call(console, ...args);
};
```

## 🧩 Unit Testing

### Component Testing Best Practices

```typescript
// src/lib/components/quiz/QuestionCard.test.ts
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/svelte';
import userEvent from '@testing-library/user-event';
import QuestionCard from './QuestionCard.svelte';
import type { Question } from '$lib/types';

const mockQuestion: Question = {
  id: '1',
  text: 'What is the capital of Philippines?',
  options: ['Manila', 'Cebu', 'Davao', 'Quezon City'],
  correctAnswer: 0,
  explanation: 'Manila is the capital city of the Philippines.',
  category: 'geography',
  difficulty: 'easy',
  tags: ['geography', 'philippines'],
  metadata: {
    createdAt: new Date('2024-01-01'),
    updatedAt: new Date('2024-01-01'),
    author: 'test-author',
    usageCount: 100,
    averageTime: 30,
    successRate: 85
  }
};

describe('QuestionCard', () => {
  const user = userEvent.setup();
  
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('renders question text and all options', () => {
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
    
    expect(screen.getByText('Question 1 of 10')).toBeInTheDocument();
  });

  it('shows timer countdown', async () => {
    vi.useFakeTimers();
    
    render(QuestionCard, {
      props: {
        question: mockQuestion,
        questionNumber: 1,
        totalQuestions: 10,
        selectedAnswer: null,
        timeLimit: 60
      }
    });

    expect(screen.getByText('⏱️ 60s')).toBeInTheDocument();
    
    // Advance timer by 1 second
    vi.advanceTimersByTime(1000);
    await waitFor(() => {
      expect(screen.getByText('⏱️ 59s')).toBeInTheDocument();
    });
    
    vi.useRealTimers();
  });

  it('dispatches answer event when option is clicked', async () => {
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
    await user.click(firstOption);

    expect(answerHandler).toHaveBeenCalledWith(
      expect.objectContaining({
        detail: 0
      })
    );
  });

  it('shows explanation after answer is selected', () => {
    render(QuestionCard, {
      props: {
        question: mockQuestion,
        questionNumber: 1,
        totalQuestions: 10,
        selectedAnswer: 0 // Answer already selected
      }
    });

    expect(screen.getByText('Explanation:')).toBeInTheDocument();
    expect(screen.getByText(mockQuestion.explanation)).toBeInTheDocument();
  });

  it('shows correct/incorrect feedback', () => {
    // Test correct answer
    render(QuestionCard, {
      props: {
        question: mockQuestion,
        questionNumber: 1,
        totalQuestions: 10,
        selectedAnswer: 0 // Correct answer
      }
    });

    expect(screen.getByText('✅ Correct!')).toBeInTheDocument();
  });

  it('handles timeout correctly', async () => {
    vi.useFakeTimers();
    
    const component = render(QuestionCard, {
      props: {
        question: mockQuestion,
        questionNumber: 1,
        totalQuestions: 10,
        selectedAnswer: null,
        timeLimit: 2
      }
    });

    const timeoutHandler = vi.fn();
    component.component.$on('timeout', timeoutHandler);

    // Advance timer past timeout
    vi.advanceTimersByTime(3000);

    await waitFor(() => {
      expect(timeoutHandler).toHaveBeenCalled();
    });
    
    vi.useRealTimers();
  });

  it('is accessible', async () => {
    const { container } = render(QuestionCard, {
      props: {
        question: mockQuestion,
        questionNumber: 1,
        totalQuestions: 10,
        selectedAnswer: null
      }
    });

    // Check for proper ARIA labels
    expect(screen.getByRole('group')).toBeInTheDocument();
    
    const radioButtons = screen.getAllByRole('radio');
    expect(radioButtons).toHaveLength(4);
    
    // Each radio button should have a label
    radioButtons.forEach(radio => {
      expect(radio).toHaveAccessibleName();
    });
  });

  it('handles keyboard navigation', async () => {
    render(QuestionCard, {
      props: {
        question: mockQuestion,
        questionNumber: 1,
        totalQuestions: 10,
        selectedAnswer: null
      }
    });

    const firstRadio = screen.getAllByRole('radio')[0];
    
    // Focus first radio button
    firstRadio.focus();
    expect(document.activeElement).toBe(firstRadio);
    
    // Navigate with arrow keys
    await user.keyboard('{ArrowDown}');
    
    const secondRadio = screen.getAllByRole('radio')[1];
    expect(document.activeElement).toBe(secondRadio);
  });
});
```

### Store Testing

```typescript
// src/lib/stores/quiz.test.ts
import { describe, it, expect, beforeEach } from 'vitest';
import { get } from 'svelte/store';
import { quizStore, quizProgress } from './quiz';
import type { Question } from '$lib/types';

const mockQuestions: Question[] = [
  {
    id: '1',
    text: 'Question 1',
    options: ['A', 'B', 'C', 'D'],
    correctAnswer: 0,
    explanation: 'Explanation 1',
    category: 'test',
    difficulty: 'easy',
    tags: [],
    metadata: {
      createdAt: new Date(),
      updatedAt: new Date(),
      author: 'test',
      usageCount: 0,
      averageTime: 30,
      successRate: 100
    }
  },
  {
    id: '2',
    text: 'Question 2',
    options: ['A', 'B', 'C', 'D'],
    correctAnswer: 1,
    explanation: 'Explanation 2',
    category: 'test',
    difficulty: 'medium',
    tags: [],
    metadata: {
      createdAt: new Date(),
      updatedAt: new Date(),
      author: 'test',
      usageCount: 0,
      averageTime: 45,
      successRate: 80
    }
  }
];

describe('Quiz Store', () => {
  beforeEach(() => {
    quizStore.reset();
  });

  it('initializes with empty state', () => {
    const state = get(quizStore);
    
    expect(state.currentSession).toBeNull();
    expect(state.questions).toEqual([]);
    expect(state.isLoading).toBe(false);
    expect(state.error).toBeNull();
  });

  it('starts quiz correctly', () => {
    quizStore.startQuiz(mockQuestions);
    
    const state = get(quizStore);
    
    expect(state.currentSession).toBeDefined();
    expect(state.currentSession?.questions).toEqual(mockQuestions);
    expect(state.currentSession?.answers).toEqual([null, null]);
    expect(state.currentSession?.currentQuestionIndex).toBe(0);
    expect(state.questions).toEqual(mockQuestions);
  });

  it('answers questions correctly', () => {
    quizStore.startQuiz(mockQuestions);
    quizStore.answerQuestion(0, 2); // Answer first question with option 2
    
    const state = get(quizStore);
    
    expect(state.currentSession?.answers[0]).toBe(2);
    expect(state.currentSession?.answers[1]).toBeNull();
  });

  it('progresses to next question', () => {
    quizStore.startQuiz(mockQuestions);
    quizStore.nextQuestion();
    
    const state = get(quizStore);
    
    expect(state.currentSession?.currentQuestionIndex).toBe(1);
  });

  it('calculates progress correctly', () => {
    quizStore.startQuiz(mockQuestions);
    
    // No answers yet
    let progress = get(quizProgress);
    expect(progress.answered).toBe(0);
    expect(progress.total).toBe(2);
    expect(progress.percentage).toBe(0);
    
    // Answer first question
    quizStore.answerQuestion(0, 1);
    
    progress = get(quizProgress);
    expect(progress.answered).toBe(1);
    expect(progress.total).toBe(2);
    expect(progress.percentage).toBe(50);
    
    // Answer second question
    quizStore.answerQuestion(1, 0);
    
    progress = get(quizProgress);
    expect(progress.answered).toBe(2);
    expect(progress.total).toBe(2);
    expect(progress.percentage).toBe(100);
  });

  it('resets state correctly', () => {
    quizStore.startQuiz(mockQuestions);
    quizStore.answerQuestion(0, 1);
    
    quizStore.reset();
    
    const state = get(quizStore);
    expect(state.currentSession).toBeNull();
    expect(state.questions).toEqual([]);
  });
});
```

### Utility Function Testing

```typescript
// src/lib/utils/validation.test.ts
import { describe, it, expect } from 'vitest';
import { validateEmail, validatePassword, validateQuizAnswer } from './validation';

describe('Validation Utilities', () => {
  describe('validateEmail', () => {
    it('accepts valid email addresses', () => {
      const validEmails = [
        'test@example.com',
        'user123@domain.co.uk',
        'name.surname@company.ph',
        'student@university.edu.ph'
      ];

      validEmails.forEach(email => {
        expect(validateEmail(email)).toBe(true);
      });
    });

    it('rejects invalid email addresses', () => {
      const invalidEmails = [
        'notanemail',
        '@domain.com',
        'user@',
        'user space@domain.com',
        'user..double@domain.com'
      ];

      invalidEmails.forEach(email => {
        expect(validateEmail(email)).toBe(false);
      });
    });
  });

  describe('validatePassword', () => {
    it('accepts strong passwords', () => {
      const strongPasswords = [
        'StrongPass123!',
        'MySecure@Password1',
        'Complex#Pass99'
      ];

      strongPasswords.forEach(password => {
        const result = validatePassword(password);
        expect(result.isValid).toBe(true);
        expect(result.errors).toEqual([]);
      });
    });

    it('rejects weak passwords', () => {
      const weakPasswords = [
        { password: '123', expectedErrors: ['too_short', 'no_uppercase', 'no_lowercase', 'no_special'] },
        { password: 'password', expectedErrors: ['no_uppercase', 'no_number', 'no_special'] },
        { password: 'PASSWORD123', expectedErrors: ['no_lowercase', 'no_special'] }
      ];

      weakPasswords.forEach(({ password, expectedErrors }) => {
        const result = validatePassword(password);
        expect(result.isValid).toBe(false);
        expect(result.errors).toEqual(expect.arrayContaining(expectedErrors));
      });
    });
  });

  describe('validateQuizAnswer', () => {
    const question = {
      id: '1',
      options: ['Option A', 'Option B', 'Option C', 'Option D']
    };

    it('accepts valid answer indices', () => {
      [0, 1, 2, 3].forEach(answer => {
        expect(validateQuizAnswer(answer, question)).toBe(true);
      });
    });

    it('rejects invalid answer indices', () => {
      [-1, 4, 10, null, undefined].forEach(answer => {
        expect(validateQuizAnswer(answer, question)).toBe(false);
      });
    });
  });
});
```

## 🔗 Integration Testing

### API Testing with MSW

```typescript
// src/lib/test-utils/server.ts
import { setupServer } from 'msw/node';
import { http, HttpResponse } from 'msw';
import type { Question, QuizSession } from '$lib/types';

const mockQuestions: Question[] = [
  {
    id: '1',
    text: 'Sample question 1',
    options: ['A', 'B', 'C', 'D'],
    correctAnswer: 0,
    explanation: 'Sample explanation',
    category: 'nursing',
    difficulty: 'easy',
    tags: ['basics'],
    metadata: {
      createdAt: new Date('2024-01-01'),
      updatedAt: new Date('2024-01-01'),
      author: 'system',
      usageCount: 50,
      averageTime: 30,
      successRate: 80
    }
  }
];

export const handlers = [
  // Questions API
  http.get('/api/questions', ({ request }) => {
    const url = new URL(request.url);
    const category = url.searchParams.get('category');
    const limit = Number(url.searchParams.get('limit')) || 10;
    
    let filteredQuestions = mockQuestions;
    if (category) {
      filteredQuestions = mockQuestions.filter(q => q.category === category);
    }
    
    return HttpResponse.json({
      questions: filteredQuestions.slice(0, limit),
      total: filteredQuestions.length
    });
  }),

  // Quiz submission
  http.post('/api/quiz/submit', async ({ request }) => {
    const body = await request.json() as {
      sessionId: string;
      answers: number[];
      timeSpent: number;
    };
    
    const correctCount = body.answers.filter((answer, index) => 
      answer === mockQuestions[index]?.correctAnswer
    ).length;
    
    const score = Math.round((correctCount / body.answers.length) * 100);
    
    return HttpResponse.json({
      sessionId: body.sessionId,
      score,
      correctAnswers: correctCount,
      totalQuestions: body.answers.length,
      passed: score >= 70,
      timeSpent: body.timeSpent
    });
  }),

  // User authentication
  http.post('/api/auth/login', async ({ request }) => {
    const { email, password } = await request.json() as {
      email: string;
      password: string;
    };
    
    // Mock authentication logic
    if (email === 'test@example.com' && password === 'password123') {
      return HttpResponse.json({
        user: {
          id: 'user-1',
          email: 'test@example.com',
          name: 'Test User',
          role: 'student'
        },
        token: 'mock-jwt-token'
      });
    }
    
    return HttpResponse.json(
      { error: 'Invalid credentials' },
      { status: 401 }
    );
  }),

  // Error simulation
  http.get('/api/error', () => {
    return HttpResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  })
];

export const server = setupServer(...handlers);
```

### Quiz Integration Tests

```typescript
// src/lib/components/Quiz.integration.test.ts
import { describe, it, expect, beforeAll, afterAll, afterEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/svelte';
import userEvent from '@testing-library/user-event';
import { server } from '$lib/test-utils/server';
import Quiz from './Quiz.svelte';

describe('Quiz Integration', () => {
  const user = userEvent.setup();

  beforeAll(() => server.listen());
  afterEach(() => server.resetHandlers());
  afterAll(() => server.close());

  it('loads questions and allows quiz completion', async () => {
    render(Quiz, {
      props: { category: 'nursing' }
    });

    // Wait for questions to load
    await waitFor(() => {
      expect(screen.getByText('Sample question 1')).toBeInTheDocument();
    });

    // Verify all options are displayed
    ['A', 'B', 'C', 'D'].forEach(option => {
      expect(screen.getByText(option)).toBeInTheDocument();
    });

    // Select an answer
    const optionA = screen.getByText('A');
    await user.click(optionA);

    // Verify explanation appears
    await waitFor(() => {
      expect(screen.getByText('Sample explanation')).toBeInTheDocument();
    });

    // Submit quiz
    const submitButton = screen.getByText('Finish Quiz');
    await user.click(submitButton);

    // Verify results are shown
    await waitFor(() => {
      expect(screen.getByText(/Quiz Results/i)).toBeInTheDocument();
    });
  });

  it('handles API errors gracefully', async () => {
    // Override handler to simulate error
    server.use(
      http.get('/api/questions', () => {
        return HttpResponse.json(
          { error: 'Service unavailable' },
          { status: 503 }
        );
      })
    );

    render(Quiz, {
      props: { category: 'nursing' }
    });

    await waitFor(() => {
      expect(screen.getByText(/Failed to load questions/i)).toBeInTheDocument();
    });
  });

  it('shows loading state initially', () => {
    render(Quiz, {
      props: { category: 'nursing' }
    });

    expect(screen.getByText('Loading questions...')).toBeInTheDocument();
  });

  it('supports keyboard navigation', async () => {
    render(Quiz, {
      props: { category: 'nursing' }
    });

    await waitFor(() => {
      expect(screen.getByText('Sample question 1')).toBeInTheDocument();
    });

    const radioButtons = screen.getAllByRole('radio');
    
    // Tab to first radio button
    await user.tab();
    expect(document.activeElement).toBe(radioButtons[0]);
    
    // Use arrow keys to navigate
    await user.keyboard('{ArrowDown}');
    expect(document.activeElement).toBe(radioButtons[1]);
    
    // Select with space
    await user.keyboard(' ');
    expect(radioButtons[1]).toBeChecked();
  });
});
```

## 🎭 End-to-End Testing

### Playwright Configuration

```typescript
// playwright.config.ts
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './tests/e2e',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: [
    ['html'],
    ['junit', { outputFile: 'test-results/e2e-results.xml' }]
  ],
  
  use: {
    baseURL: 'http://localhost:4173',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
    
    // Global test context
    extraHTTPHeaders: {
      'Accept': 'application/json'
    }
  },

  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] }
    },
    {
      name: 'firefox',
      use: { ...devices['Desktop Firefox'] }
    },
    {
      name: 'webkit',
      use: { ...devices['Desktop Safari'] }
    },
    {
      name: 'Mobile Chrome',
      use: { ...devices['Pixel 5'] }
    },
    {
      name: 'Mobile Safari',
      use: { ...devices['iPhone 12'] }
    }
  ],

  webServer: {
    command: 'npm run build && npm run preview',
    port: 4173,
    reuseExistingServer: !process.env.CI,
    stdout: 'ignore',
    stderr: 'pipe'
  }
});
```

### E2E Test Examples

```typescript
// tests/e2e/quiz-flow.spec.ts
import { test, expect } from '@playwright/test';

test.describe('Quiz Flow', () => {
  test.beforeEach(async ({ page }) => {
    // Set up test data or login if needed
    await page.goto('/');
  });

  test('complete nursing quiz successfully', async ({ page }) => {
    // Navigate to nursing quiz
    await page.getByText('Nursing Board Exam').click();
    await expect(page).toHaveURL(/.*\/quiz\/nursing/);

    // Wait for first question to load
    await expect(page.getByRole('heading', { level: 3 })).toBeVisible();
    
    // Verify timer is running
    await expect(page.getByText(/⏱️ \d+s/)).toBeVisible();

    // Answer questions
    let questionCount = 0;
    while (questionCount < 5) { // Answer 5 questions
      // Wait for question to be visible
      await expect(page.getByRole('radio').first()).toBeVisible();
      
      // Select first option
      await page.getByRole('radio').first().click();
      
      // Wait for explanation
      await expect(page.getByText('Explanation:')).toBeVisible();
      
      // Check if this is the last question
      const finishButton = page.getByText('Finish Quiz');
      const nextButton = page.getByText('Next Question');
      
      if (await finishButton.isVisible()) {
        await finishButton.click();
        break;
      } else {
        await nextButton.click();
      }
      
      questionCount++;
    }

    // Verify results page
    await expect(page.getByText('Quiz Results')).toBeVisible();
    await expect(page.getByText(/Score:/)).toBeVisible();
    await expect(page.getByText(/You answered \d+ questions/)).toBeVisible();
  });

  test('handles timeout correctly', async ({ page }) => {
    await page.goto('/quiz/nursing');
    
    // Wait for question to load
    await expect(page.getByRole('heading', { level: 3 })).toBeVisible();
    
    // Don't answer - wait for timeout
    await expect(page.getByText('⏰ Time\'s up!')).toBeVisible({ timeout: 65000 });
    
    // Should show explanation automatically
    await expect(page.getByText('Explanation:')).toBeVisible();
  });

  test('shows progress correctly', async ({ page }) => {
    await page.goto('/quiz/nursing');
    
    // Check initial progress
    await expect(page.getByText('Question 1 of')).toBeVisible();
    
    // Answer first question
    await page.getByRole('radio').first().click();
    await page.getByText('Next Question').click();
    
    // Check updated progress
    await expect(page.getByText('Question 2 of')).toBeVisible();
    
    // Verify progress bar
    const progressBar = page.locator('[role="progressbar"]');
    await expect(progressBar).toBeVisible();
  });

  test('supports keyboard navigation', async ({ page }) => {
    await page.goto('/quiz/nursing');
    
    // Wait for question
    await expect(page.getByRole('radio').first()).toBeVisible();
    
    // Tab to first radio button
    await page.keyboard.press('Tab');
    await expect(page.getByRole('radio').first()).toBeFocused();
    
    // Navigate with arrow keys
    await page.keyboard.press('ArrowDown');
    await expect(page.getByRole('radio').nth(1)).toBeFocused();
    
    // Select with space
    await page.keyboard.press('Space');
    await expect(page.getByRole('radio').nth(1)).toBeChecked();
  });

  test('works on mobile devices', async ({ page, isMobile }) => {
    test.skip(!isMobile, 'Mobile-specific test');
    
    await page.goto('/quiz/nursing');
    
    // Wait for question
    await expect(page.getByRole('heading', { level: 3 })).toBeVisible();
    
    // Verify mobile-friendly layout
    const questionCard = page.locator('.question-card');
    await expect(questionCard).toBeVisible();
    
    // Touch interactions should work
    await page.getByRole('radio').first().tap();
    await expect(page.getByText('Explanation:')).toBeVisible();
  });
});
```

### Authentication E2E Tests

```typescript
// tests/e2e/authentication.spec.ts
import { test, expect } from '@playwright/test';

test.describe('Authentication', () => {
  test('user can register and login', async ({ page }) => {
    // Go to registration page
    await page.goto('/register');
    
    // Fill registration form
    await page.getByLabel('Email').fill('test@example.com');
    await page.getByLabel('Password').fill('StrongPass123!');
    await page.getByLabel('Confirm Password').fill('StrongPass123!');
    await page.getByLabel('Full Name').fill('Test User');
    
    // Submit registration
    await page.getByRole('button', { name: 'Register' }).click();
    
    // Should redirect to dashboard or verification page
    await expect(page).toHaveURL(/\/(dashboard|verify)/);
    
    // Logout
    await page.getByRole('button', { name: 'Logout' }).click();
    
    // Login with same credentials
    await page.goto('/login');
    await page.getByLabel('Email').fill('test@example.com');
    await page.getByLabel('Password').fill('StrongPass123!');
    await page.getByRole('button', { name: 'Login' }).click();
    
    // Should be on dashboard
    await expect(page).toHaveURL('/dashboard');
    await expect(page.getByText('Welcome, Test User')).toBeVisible();
  });

  test('shows validation errors for invalid inputs', async ({ page }) => {
    await page.goto('/register');
    
    // Try to submit with invalid email
    await page.getByLabel('Email').fill('invalid-email');
    await page.getByLabel('Password').fill('weak');
    await page.getByRole('button', { name: 'Register' }).click();
    
    // Should show validation errors
    await expect(page.getByText('Please enter a valid email address')).toBeVisible();
    await expect(page.getByText('Password must be at least 8 characters')).toBeVisible();
  });

  test('handles login errors gracefully', async ({ page }) => {
    await page.goto('/login');
    
    // Try invalid credentials
    await page.getByLabel('Email').fill('wrong@example.com');
    await page.getByLabel('Password').fill('wrongpassword');
    await page.getByRole('button', { name: 'Login' }).click();
    
    // Should show error message
    await expect(page.getByText('Invalid email or password')).toBeVisible();
    
    // Should stay on login page
    await expect(page).toHaveURL('/login');
  });
});
```

## 📊 Performance Testing

### Lighthouse CI Configuration

```javascript
// .lighthouserc.js
module.exports = {
  ci: {
    collect: {
      url: [
        'http://localhost:4173/',
        'http://localhost:4173/quiz/nursing',
        'http://localhost:4173/dashboard',
        'http://localhost:4173/login'
      ],
      numberOfRuns: 3,
      settings: {
        chromeFlags: '--no-sandbox --headless',
        preset: 'desktop'
      }
    },
    assert: {
      assertions: {
        'categories:performance': ['warn', { minScore: 0.9 }],
        'categories:accessibility': ['error', { minScore: 0.95 }],
        'categories:best-practices': ['warn', { minScore: 0.9 }],
        'categories:seo': ['warn', { minScore: 0.9 }],
        'categories:pwa': ['warn', { minScore: 0.8 }]
      }
    },
    upload: {
      target: 'filesystem',
      outputDir: './lighthouse-results'
    }
  }
};
```

### Custom Performance Tests

```typescript
// tests/performance/quiz-performance.spec.ts
import { test, expect } from '@playwright/test';

test('quiz page loads within performance budget', async ({ page }) => {
  // Start performance measurement
  const startTime = Date.now();
  
  await page.goto('/quiz/nursing');
  
  // Wait for first meaningful paint
  await page.waitForSelector('h3', { state: 'visible' });
  
  const loadTime = Date.now() - startTime;
  
  // Performance assertions
  expect(loadTime).toBeLessThan(2000); // Page should load in under 2 seconds
  
  // Check Core Web Vitals
  const vitals = await page.evaluate(() => {
    return new Promise((resolve) => {
      let fcpValue = 0;
      let lcpValue = 0;
      let clsValue = 0;
      
      new PerformanceObserver((list) => {
        for (const entry of list.getEntries()) {
          if (entry.name === 'first-contentful-paint') {
            fcpValue = entry.startTime;
          }
        }
      }).observe({ entryTypes: ['paint'] });
      
      new PerformanceObserver((list) => {
        for (const entry of list.getEntries()) {
          lcpValue = entry.startTime;
        }
      }).observe({ entryTypes: ['largest-contentful-paint'] });
      
      new PerformanceObserver((list) => {
        for (const entry of list.getEntries()) {
          clsValue += entry.value;
        }
      }).observe({ entryTypes: ['layout-shift'] });
      
      setTimeout(() => {
        resolve({ fcp: fcpValue, lcp: lcpValue, cls: clsValue });
      }, 1000);
    });
  });
  
  // Web Vitals thresholds
  expect(vitals.fcp).toBeLessThan(1800); // FCP < 1.8s
  expect(vitals.lcp).toBeLessThan(2500); // LCP < 2.5s
  expect(vitals.cls).toBeLessThan(0.1);  // CLS < 0.1
});

test('quiz handles high question count efficiently', async ({ page }) => {
  // Navigate to a category with many questions
  await page.goto('/quiz/nursing?count=100');
  
  const startTime = Date.now();
  
  // Wait for questions to load
  await page.waitForSelector('.question-card', { state: 'visible' });
  
  const initialLoadTime = Date.now() - startTime;
  expect(initialLoadTime).toBeLessThan(3000);
  
  // Measure answer response time
  const answerStartTime = Date.now();
  await page.getByRole('radio').first().click();
  await page.waitForSelector('.explanation', { state: 'visible' });
  const answerTime = Date.now() - answerStartTime;
  
  expect(answerTime).toBeLessThan(100); // Answer feedback should be instant
});
```

## ♿ Accessibility Testing

### Automated A11y Testing

```typescript
// tests/accessibility/a11y.spec.ts
import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

test.describe('Accessibility Tests', () => {
  test('homepage is accessible', async ({ page }) => {
    await page.goto('/');
    
    const accessibilityScanResults = await new AxeBuilder({ page })
      .withTags(['wcag2a', 'wcag2aa', 'wcag21aa'])
      .analyze();
    
    expect(accessibilityScanResults.violations).toEqual([]);
  });

  test('quiz page is accessible', async ({ page }) => {
    await page.goto('/quiz/nursing');
    
    // Wait for content to load
    await page.waitForSelector('.question-card', { state: 'visible' });
    
    const accessibilityScanResults = await new AxeBuilder({ page })
      .withTags(['wcag2a', 'wcag2aa', 'wcag21aa'])
      .exclude('.advertisement') // Exclude third-party content
      .analyze();
    
    expect(accessibilityScanResults.violations).toEqual([]);
  });

  test('forms are accessible', async ({ page }) => {
    await page.goto('/login');
    
    const accessibilityScanResults = await new AxeBuilder({ page }).analyze();
    expect(accessibilityScanResults.violations).toEqual([]);
    
    // Test keyboard navigation
    await page.keyboard.press('Tab');
    await expect(page.getByLabel('Email')).toBeFocused();
    
    await page.keyboard.press('Tab');
    await expect(page.getByLabel('Password')).toBeFocused();
    
    await page.keyboard.press('Tab');
    await expect(page.getByRole('button', { name: 'Login' })).toBeFocused();
  });

  test('screen reader landmarks are present', async ({ page }) => {
    await page.goto('/');
    
    // Check for proper landmarks
    await expect(page.locator('main')).toBeVisible();
    await expect(page.locator('nav')).toBeVisible();
    await expect(page.locator('header')).toBeVisible();
    await expect(page.locator('footer')).toBeVisible();
  });

  test('images have alt text', async ({ page }) => {
    await page.goto('/');
    
    const images = await page.locator('img').all();
    
    for (const img of images) {
      const alt = await img.getAttribute('alt');
      expect(alt).toBeTruthy();
      expect(alt?.length).toBeGreaterThan(0);
    }
  });
});
```

## 📈 Test Reports and CI Integration

### GitHub Actions Test Workflow

```yaml
# .github/workflows/test.yml
name: Test Suite

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

jobs:
  test:
    runs-on: ubuntu-latest
    
    strategy:
      matrix:
        node-version: [18, 20]
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Node.js ${{ matrix.node-version }}
        uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node-version }}
          cache: 'npm'
      
      - name: Install dependencies
        run: npm ci
      
      - name: Run unit tests
        run: npm run test:unit
      
      - name: Run integration tests
        run: npm run test:integration
      
      - name: Generate coverage report
        run: npm run test:coverage
      
      - name: Upload coverage to Codecov
        uses: codecov/codecov-action@v3
        with:
          file: ./coverage/coverage-final.json
      
      - name: Build application
        run: npm run build
      
      - name: Install Playwright
        run: npx playwright install --with-deps
      
      - name: Run E2E tests
        run: npm run test:e2e
      
      - name: Run Lighthouse CI
        run: npm run test:lighthouse
      
      - name: Upload test results
        uses: actions/upload-artifact@v3
        if: always()
        with:
          name: test-results-${{ matrix.node-version }}
          path: |
            test-results/
            lighthouse-results/
            coverage/
            playwright-report/
```

### Test Coverage Configuration

```json
// package.json scripts
{
  "scripts": {
    "test": "vitest",
    "test:unit": "vitest run --reporter=verbose --reporter=junit --outputFile=test-results/unit-results.xml",
    "test:integration": "vitest run src/**/*.integration.test.ts",
    "test:coverage": "vitest run --coverage",
    "test:e2e": "playwright test",
    "test:lighthouse": "lhci autorun",
    "test:a11y": "playwright test tests/accessibility/",
    "test:all": "npm run test:unit && npm run test:integration && npm run build && npm run test:e2e && npm run test:lighthouse"
  }
}
```

### Custom Test Reporter

```typescript
// test-utils/custom-reporter.ts
import type { Reporter, TestResult } from 'vitest';

export class EdTechTestReporter implements Reporter {
  onInit() {
    console.log('🎓 Starting EdTech Platform Test Suite');
  }

  onTaskUpdate(packs: TestResult[]) {
    const results = {
      total: packs.length,
      passed: packs.filter(p => p.result?.state === 'pass').length,
      failed: packs.filter(p => p.result?.state === 'fail').length,
      skipped: packs.filter(p => p.result?.state === 'skip').length
    };

    if (results.failed > 0) {
      console.log(`❌ Tests failing: ${results.failed}/${results.total}`);
      
      // Log critical failures
      packs
        .filter(p => p.result?.state === 'fail')
        .forEach(pack => {
          if (pack.tasks[0]?.name.includes('quiz') || pack.tasks[0]?.name.includes('auth')) {
            console.log(`🚨 Critical test failure: ${pack.tasks[0]?.name}`);
          }
        });
    }
  }

  onFinished(files: TestResult[]) {
    const totalTests = files.reduce((acc, file) => acc + file.tasks.length, 0);
    const passedTests = files.reduce((acc, file) => 
      acc + file.tasks.filter(task => task.result?.state === 'pass').length, 0
    );
    
    const passRate = (passedTests / totalTests) * 100;
    
    console.log('\n📊 Test Summary:');
    console.log(`Total Tests: ${totalTests}`);
    console.log(`Passed: ${passedTests}`);
    console.log(`Pass Rate: ${passRate.toFixed(1)}%`);
    
    if (passRate < 90) {
      console.log('⚠️  Pass rate below 90% - investigate failures');
    } else {
      console.log('✅ All tests passing - ready for deployment');
    }
  }
}
```

---

## 🔗 Continue Reading

- **Next**: [Template Examples](./template-examples.md) - Working examples and starter templates
- **Previous**: [Deployment Guide](./deployment-guide.md) - Production deployment strategies
- **Performance**: [Performance Analysis](./performance-analysis.md) - Detailed benchmarks

---

## 📚 Testing References

1. **[Vitest Documentation](https://vitest.dev/)** - Unit testing framework
2. **[Testing Library Svelte](https://testing-library.com/docs/svelte-testing-library/intro/)** - Component testing utilities
3. **[Playwright Documentation](https://playwright.dev/)** - End-to-end testing framework
4. **[MSW Documentation](https://mswjs.io/)** - API mocking for tests
5. **[Lighthouse CI](https://github.com/GoogleChrome/lighthouse-ci)** - Performance testing automation
6. **[Axe Accessibility Testing](https://www.deque.com/axe/)** - Automated accessibility testing
7. **[Web Content Accessibility Guidelines](https://www.w3.org/WAI/WCAG21/quickref/)** - A11y standards

---

*Testing Strategies completed January 2025 | Comprehensive quality assurance for EdTech applications*