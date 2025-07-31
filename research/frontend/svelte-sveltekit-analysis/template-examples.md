# Template Examples - Svelte/SvelteKit

## 📁 Working Examples and Starter Templates

Comprehensive collection of working code examples, starter templates, and practical implementations for building EdTech applications with Svelte/SvelteKit.

{% hint style="success" %}
**Ready to Use**: All examples are production-ready and follow best practices established in previous sections of this research.
{% endhint %}

## 🎯 Template Overview

### Available Templates

| Template | Description | Complexity | Use Case |
|----------|-------------|------------|----------|
| **Minimal Quiz App** | Basic quiz functionality | Beginner | Learning Svelte basics |
| **Full EdTech Platform** | Complete exam review system | Advanced | Production deployment |
| **Component Library** | Reusable UI components | Intermediate | Design system |
| **PWA Quiz App** | Offline-capable quiz app | Intermediate | Mobile-first learning |
| **Multi-tenant Platform** | Multiple exam categories | Advanced | Scalable platform |

## 🚀 Quick Start Templates

### 1. Minimal Quiz Application

Perfect for learning Svelte/SvelteKit fundamentals.

```bash
# Create project
npx sv create minimal-quiz-app
cd minimal-quiz-app
npm install

# Add dependencies
npm install @types/uuid uuid date-fns
```

#### Project Structure
```
minimal-quiz-app/
├── src/
│   ├── routes/
│   │   ├── +layout.svelte
│   │   ├── +page.svelte
│   │   └── quiz/
│   │       └── +page.svelte
│   ├── lib/
│   │   ├── components/
│   │   │   ├── Quiz.svelte
│   │   │   ├── Question.svelte
│   │   │   └── Results.svelte
│   │   ├── stores/
│   │   │   └── quiz.ts
│   │   └── data/
│   │       └── questions.ts
│   └── app.html
└── package.json
```

#### Core Implementation

```typescript
// src/lib/data/questions.ts
export interface Question {
  id: string;
  text: string;
  options: string[];
  correctAnswer: number;
  explanation: string;
}

export const questions: Question[] = [
  {
    id: '1',
    text: 'What is the capital of the Philippines?',
    options: ['Manila', 'Cebu', 'Davao', 'Quezon City'],
    correctAnswer: 0,
    explanation: 'Manila is the capital and second-most populous city of the Philippines.'
  },
  {
    id: '2',
    text: 'Which of the following is a programming language?',
    options: ['HTML', 'CSS', 'JavaScript', 'All of the above'],
    correctAnswer: 2,
    explanation: 'JavaScript is a programming language, while HTML and CSS are markup and styling languages respectively.'
  },
  {
    id: '3',
    text: 'What does API stand for?',
    options: ['Application Programming Interface', 'Advanced Programming Interface', 'Automated Programming Interface', 'Application Process Interface'],
    correctAnswer: 0,
    explanation: 'API stands for Application Programming Interface, which allows different software applications to communicate with each other.'
  }
];
```

```typescript
// src/lib/stores/quiz.ts
import { writable, derived } from 'svelte/store';
import type { Question } from '$lib/data/questions';

interface QuizState {
  questions: Question[];
  currentIndex: number;
  answers: (number | null)[];
  isComplete: boolean;
}

const initialState: QuizState = {
  questions: [],
  currentIndex: 0,
  answers: [],
  isComplete: false
};

function createQuizStore() {
  const { subscribe, set, update } = writable<QuizState>(initialState);

  return {
    subscribe,
    
    startQuiz: (questions: Question[]) => {
      set({
        questions,
        currentIndex: 0,
        answers: new Array(questions.length).fill(null),
        isComplete: false
      });
    },
    
    answerQuestion: (answerIndex: number) => {
      update(state => {
        const newAnswers = [...state.answers];
        newAnswers[state.currentIndex] = answerIndex;
        return { ...state, answers: newAnswers };
      });
    },
    
    nextQuestion: () => {
      update(state => {
        const nextIndex = state.currentIndex + 1;
        const isComplete = nextIndex >= state.questions.length;
        return {
          ...state,
          currentIndex: nextIndex,
          isComplete
        };
      });
    },
    
    reset: () => set(initialState)
  };
}

export const quizStore = createQuizStore();

export const currentQuestion = derived(
  quizStore,
  $quiz => $quiz.questions[$quiz.currentIndex] || null
);

export const progress = derived(
  quizStore,
  $quiz => ({
    current: $quiz.currentIndex + 1,
    total: $quiz.questions.length,
    percentage: $quiz.questions.length > 0 ? 
      (($quiz.currentIndex + 1) / $quiz.questions.length) * 100 : 0
  })
);

export const results = derived(
  quizStore,
  $quiz => {
    if (!$quiz.isComplete) return null;
    
    const correctCount = $quiz.answers.filter((answer, index) => 
      answer === $quiz.questions[index]?.correctAnswer
    ).length;
    
    return {
      correct: correctCount,
      total: $quiz.questions.length,
      percentage: Math.round((correctCount / $quiz.questions.length) * 100),
      passed: (correctCount / $quiz.questions.length) >= 0.7
    };
  }
);
```

```svelte
<!-- src/lib/components/Question.svelte -->
<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import type { Question } from '$lib/data/questions';
  
  export let question: Question;
  export let questionNumber: number;
  export let totalQuestions: number;
  export let selectedAnswer: number | null;
  
  const dispatch = createEventDispatcher<{
    answer: number;
    next: void;
  }>();
  
  let showExplanation = false;
  
  function handleAnswer(answerIndex: number) {
    if (selectedAnswer !== null) return;
    
    dispatch('answer', answerIndex);
    showExplanation = true;
  }
  
  function handleNext() {
    dispatch('next');
    showExplanation = false;
  }
</script>

<div class="question-container">
  <div class="question-header">
    <span class="question-number">Question {questionNumber} of {totalQuestions}</span>
  </div>
  
  <h2 class="question-text">{question.text}</h2>
  
  <div class="options">
    {#each question.options as option, index}
      <button
        class="option"
        class:selected={selectedAnswer === index}
        class:correct={showExplanation && index === question.correctAnswer}
        class:incorrect={showExplanation && selectedAnswer === index && index !== question.correctAnswer}
        disabled={selectedAnswer !== null}
        on:click={() => handleAnswer(index)}
      >
        <span class="option-letter">{String.fromCharCode(65 + index)}</span>
        <span class="option-text">{option}</span>
      </button>
    {/each}
  </div>
  
  {#if showExplanation}
    <div class="explanation">
      <h3>Explanation:</h3>
      <p>{question.explanation}</p>
      
      <div class="result">
        {#if selectedAnswer === question.correctAnswer}
          <span class="correct-result">✅ Correct!</span>
        {:else}
          <span class="incorrect-result">❌ Incorrect</span>
        {/if}
      </div>
      
      <button class="next-button" on:click={handleNext}>
        {questionNumber < totalQuestions ? 'Next Question' : 'View Results'}
      </button>
    </div>
  {/if}
</div>

<style>
  .question-container {
    max-width: 800px;
    margin: 0 auto;
    padding: 2rem;
  }
  
  .question-header {
    margin-bottom: 1rem;
    text-align: center;
  }
  
  .question-number {
    color: #666;
    font-size: 0.9rem;
  }
  
  .question-text {
    font-size: 1.5rem;
    margin-bottom: 2rem;
    line-height: 1.4;
  }
  
  .options {
    display: flex;
    flex-direction: column;
    gap: 1rem;
    margin-bottom: 2rem;
  }
  
  .option {
    display: flex;
    align-items: center;
    padding: 1rem;
    border: 2px solid #e0e0e0;
    border-radius: 8px;
    background: white;
    cursor: pointer;
    transition: all 0.2s;
    text-align: left;
  }
  
  .option:hover:not(:disabled) {
    border-color: #2196f3;
    background: #f5f5f5;
  }
  
  .option:disabled {
    cursor: not-allowed;
  }
  
  .option.selected {
    border-color: #2196f3;
    background: #e3f2fd;
  }
  
  .option.correct {
    border-color: #4caf50;
    background: #e8f5e8;
  }
  
  .option.incorrect {
    border-color: #f44336;
    background: #ffebee;
  }
  
  .option-letter {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 2rem;
    height: 2rem;
    background: #666;
    color: white;
    border-radius: 50%;
    font-weight: bold;
    margin-right: 1rem;
    flex-shrink: 0;
  }
  
  .option.correct .option-letter {
    background: #4caf50;
  }
  
  .option.incorrect .option-letter {
    background: #f44336;
  }
  
  .option-text {
    flex: 1;
  }
  
  .explanation {
    background: #f0f9ff;
    border: 1px solid #bae6fd;
    border-radius: 8px;
    padding: 1.5rem;
    margin-top: 2rem;
  }
  
  .explanation h3 {
    color: #0369a1;
    margin-bottom: 1rem;
  }
  
  .explanation p {
    line-height: 1.6;
    margin-bottom: 1rem;
  }
  
  .result {
    margin-bottom: 1.5rem;
  }
  
  .correct-result {
    color: #4caf50;
    font-weight: bold;
  }
  
  .incorrect-result {
    color: #f44336;
    font-weight: bold;
  }
  
  .next-button {
    background: #2196f3;
    color: white;
    border: none;
    padding: 0.75rem 1.5rem;
    border-radius: 6px;
    cursor: pointer;
    font-size: 1rem;
    transition: background 0.2s;
  }
  
  .next-button:hover {
    background: #1976d2;
  }
</style>
```

```svelte
<!-- src/lib/components/Results.svelte -->
<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  
  export let results: {
    correct: number;
    total: number;
    percentage: number;
    passed: boolean;
  };
  
  const dispatch = createEventDispatcher<{
    restart: void;
  }>();
  
  function handleRestart() {
    dispatch('restart');
  }
</script>

<div class="results-container">
  <div class="results-header">
    <h1>Quiz Complete! 🎉</h1>
  </div>
  
  <div class="score-display">
    <div class="score-circle" class:passed={results.passed}>
      <span class="score-percentage">{results.percentage}%</span>
    </div>
    
    <div class="score-details">
      <p class="score-text">
        You scored {results.correct} out of {results.total} questions correctly
      </p>
      
      <div class="pass-status" class:passed={results.passed}>
        {#if results.passed}
          <span class="pass-icon">✅</span>
          <span>Congratulations! You passed!</span>
        {:else}
          <span class="fail-icon">❌</span>
          <span>Keep studying and try again!</span>
        {/if}
      </div>
    </div>
  </div>
  
  <div class="performance-breakdown">
    <h3>Performance Breakdown</h3>
    <div class="progress-bar">
      <div 
        class="progress-fill" 
        style="width: {results.percentage}%"
        class:passed={results.passed}
      ></div>
    </div>
    
    <div class="stats">
      <div class="stat">
        <span class="stat-label">Correct Answers</span>
        <span class="stat-value">{results.correct}</span>
      </div>
      <div class="stat">
        <span class="stat-label">Incorrect Answers</span>
        <span class="stat-value">{results.total - results.correct}</span>
      </div>
      <div class="stat">
        <span class="stat-label">Passing Score</span>
        <span class="stat-value">70%</span>
      </div>
    </div>
  </div>
  
  <div class="actions">
    <button class="restart-button" on:click={handleRestart}>
      Take Quiz Again
    </button>
  </div>
</div>

<style>
  .results-container {
    max-width: 600px;
    margin: 0 auto;
    padding: 2rem;
    text-align: center;
  }
  
  .results-header h1 {
    color: #333;
    margin-bottom: 2rem;
  }
  
  .score-display {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 2rem;
    margin-bottom: 3rem;
  }
  
  .score-circle {
    width: 150px;
    height: 150px;
    border-radius: 50%;
    border: 8px solid #f44336;
    display: flex;
    align-items: center;
    justify-content: center;
    background: white;
    position: relative;
  }
  
  .score-circle.passed {
    border-color: #4caf50;
  }
  
  .score-percentage {
    font-size: 2rem;
    font-weight: bold;
    color: #333;
  }
  
  .score-details {
    text-align: center;
  }
  
  .score-text {
    font-size: 1.1rem;
    color: #666;
    margin-bottom: 1rem;
  }
  
  .pass-status {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 0.5rem;
    font-size: 1.2rem;
    font-weight: bold;
    color: #f44336;
  }
  
  .pass-status.passed {
    color: #4caf50;
  }
  
  .performance-breakdown {
    background: #f9f9f9;
    border-radius: 8px;
    padding: 2rem;
    margin-bottom: 2rem;
  }
  
  .performance-breakdown h3 {
    margin-bottom: 1rem;
    color: #333;
  }
  
  .progress-bar {
    width: 100%;
    height: 20px;
    background: #e0e0e0;
    border-radius: 10px;
    overflow: hidden;
    margin-bottom: 2rem;
  }
  
  .progress-fill {
    height: 100%;
    background: #f44336;
    transition: width 0.5s ease;
  }
  
  .progress-fill.passed {
    background: #4caf50;
  }
  
  .stats {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
    gap: 1rem;
  }
  
  .stat {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 0.5rem;
  }
  
  .stat-label {
    font-size: 0.9rem;
    color: #666;
  }
  
  .stat-value {
    font-size: 1.5rem;
    font-weight: bold;
    color: #333;
  }
  
  .restart-button {
    background: #2196f3;
    color: white;
    border: none;
    padding: 1rem 2rem;
    border-radius: 8px;
    font-size: 1.1rem;
    cursor: pointer;
    transition: background 0.2s;
  }
  
  .restart-button:hover {
    background: #1976d2;
  }
</style>
```

```svelte
<!-- src/lib/components/Quiz.svelte -->
<script lang="ts">
  import { onMount } from 'svelte';
  import { quizStore, currentQuestion, progress, results } from '$lib/stores/quiz';
  import { questions } from '$lib/data/questions';
  import Question from './Question.svelte';
  import Results from './Results.svelte';
  
  let selectedAnswer: number | null = null;
  
  onMount(() => {
    quizStore.startQuiz(questions);
  });
  
  function handleAnswer(event: CustomEvent<number>) {
    selectedAnswer = event.detail;
    quizStore.answerQuestion(selectedAnswer);
  }
  
  function handleNext() {
    quizStore.nextQuestion();
    selectedAnswer = null;
  }
  
  function handleRestart() {
    quizStore.reset();
    quizStore.startQuiz(questions);
    selectedAnswer = null;
  }
  
  $: isComplete = $quizStore.isComplete;
</script>

<div class="quiz-container">
  {#if !isComplete && $currentQuestion}
    <div class="progress-header">
      <div class="progress-bar">
        <div 
          class="progress-fill" 
          style="width: {$progress.percentage}%"
        ></div>
      </div>
      <span class="progress-text">
        {$progress.current} of {$progress.total} questions
      </span>
    </div>
    
    <Question
      question={$currentQuestion}
      questionNumber={$progress.current}
      totalQuestions={$progress.total}
      {selectedAnswer}
      on:answer={handleAnswer}
      on:next={handleNext}
    />
  {:else if $results}
    <Results 
      results={$results}
      on:restart={handleRestart}
    />
  {/if}
</div>

<style>
  .quiz-container {
    min-height: 100vh;
    background: #f5f5f5;
    padding: 2rem 0;
  }
  
  .progress-header {
    max-width: 800px;
    margin: 0 auto 2rem;
    padding: 0 2rem;
  }
  
  .progress-bar {
    width: 100%;
    height: 8px;
    background: #e0e0e0;
    border-radius: 4px;
    overflow: hidden;
    margin-bottom: 0.5rem;
  }
  
  .progress-fill {
    height: 100%;
    background: #2196f3;
    transition: width 0.3s ease;
  }
  
  .progress-text {
    font-size: 0.9rem;
    color: #666;
  }
</style>
```

```svelte
<!-- src/routes/+layout.svelte -->
<style>
  :global(body) {
    margin: 0;
    padding: 0;
    font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    background: #f5f5f5;
  }
  
  :global(*) {
    box-sizing: border-box;
  }
</style>

<main>
  <slot />
</main>
```

```svelte
<!-- src/routes/+page.svelte -->
<script>
  import { goto } from '$app/navigation';
  
  function startQuiz() {
    goto('/quiz');
  }
</script>

<svelte:head>
  <title>Simple Quiz App</title>
  <meta name="description" content="Test your knowledge with our interactive quiz" />
</svelte:head>

<div class="hero">
  <div class="hero-content">
    <h1>Welcome to Quiz App</h1>
    <p>Test your knowledge with our interactive quiz featuring questions on various topics.</p>
    
    <div class="quiz-info">
      <div class="info-item">
        <span class="info-number">3</span>
        <span class="info-label">Questions</span>
      </div>
      <div class="info-item">
        <span class="info-number">70%</span>
        <span class="info-label">Passing Score</span>
      </div>
      <div class="info-item">
        <span class="info-number">5 min</span>
        <span class="info-label">Estimated Time</span>
      </div>
    </div>
    
    <button class="start-button" on:click={startQuiz}>
      Start Quiz
    </button>
  </div>
</div>

<style>
  .hero {
    min-height: 100vh;
    display: flex;
    align-items: center;
    justify-content: center;
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    color: white;
    text-align: center;
    padding: 2rem;
  }
  
  .hero-content {
    max-width: 600px;
  }
  
  h1 {
    font-size: 3rem;
    margin-bottom: 1rem;
    font-weight: 700;
  }
  
  p {
    font-size: 1.2rem;
    margin-bottom: 3rem;
    opacity: 0.9;
    line-height: 1.6;
  }
  
  .quiz-info {
    display: flex;
    justify-content: center;
    gap: 3rem;
    margin-bottom: 3rem;
  }
  
  .info-item {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 0.5rem;
  }
  
  .info-number {
    font-size: 2rem;
    font-weight: bold;
  }
  
  .info-label {
    font-size: 0.9rem;
    opacity: 0.8;
  }
  
  .start-button {
    background: white;
    color: #667eea;
    border: none;
    padding: 1rem 2rem;
    font-size: 1.2rem;
    font-weight: 600;
    border-radius: 50px;
    cursor: pointer;
    transition: transform 0.2s, box-shadow 0.2s;
  }
  
  .start-button:hover {
    transform: translateY(-2px);
    box-shadow: 0 8px 25px rgba(0, 0, 0, 0.2);
  }
  
  @media (max-width: 768px) {
    h1 {
      font-size: 2rem;
    }
    
    .quiz-info {
      flex-direction: column;
      gap: 1.5rem;
    }
  }
</style>
```

```svelte
<!-- src/routes/quiz/+page.svelte -->
<script>
  import Quiz from '$lib/components/Quiz.svelte';
</script>

<svelte:head>
  <title>Quiz - Test Your Knowledge</title>
</svelte:head>

<Quiz />
```

### 2. Complete EdTech Platform Template

Production-ready template with advanced features.

```bash
# Create project
npx sv create edtech-platform
cd edtech-platform

# Install dependencies
npm install \
  @types/uuid uuid \
  date-fns \
  zod \
  @lucia-auth/adapter-postgresql lucia \
  postgres \
  stripe \
  @sendgrid/mail \
  chart.js
```

#### Advanced Features Implementation

```typescript
// src/lib/server/database.ts
import postgres from 'postgres';

const sql = postgres(process.env.DATABASE_URL!, {
  host: process.env.DB_HOST,
  port: Number(process.env.DB_PORT),
  database: process.env.DB_NAME,
  username: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  ssl: process.env.NODE_ENV === 'production'
});

export { sql };

// User management
export async function createUser(email: string, hashedPassword: string, name: string) {
  const [user] = await sql`
    INSERT INTO users (email, password_hash, name)
    VALUES (${email}, ${hashedPassword}, ${name})
    RETURNING id, email, name, role, created_at
  `;
  return user;
}

export async function getUserByEmail(email: string) {
  const [user] = await sql`
    SELECT * FROM users WHERE email = ${email}
  `;
  return user;
}

// Question management
export async function getQuestionsByCategory(category: string, limit = 20) {
  const questions = await sql`
    SELECT * FROM questions 
    WHERE category = ${category}
    ORDER BY RANDOM()
    LIMIT ${limit}
  `;
  return questions;
}

export async function saveQuizSession(session: QuizSessionData) {
  const [savedSession] = await sql`
    INSERT INTO quiz_sessions (
      user_id, category, questions, answers, 
      started_at, completed_at, score
    )
    VALUES (
      ${session.userId}, 
      ${session.category}, 
      ${JSON.stringify(session.questions)},
      ${JSON.stringify(session.answers)},
      ${session.startedAt},
      ${session.completedAt},
      ${session.score}
    )
    RETURNING *
  `;
  return savedSession;
}

// User progress tracking
export async function updateUserProgress(userId: string, category: string, performance: PerformanceData) {
  await sql`
    INSERT INTO user_progress (
      user_id, category, questions_attempted, 
      questions_correct, total_time_spent
    )
    VALUES (
      ${userId}, ${category}, ${performance.attempted},
      ${performance.correct}, ${performance.timeSpent}
    )
    ON CONFLICT (user_id, category)
    DO UPDATE SET
      questions_attempted = user_progress.questions_attempted + ${performance.attempted},
      questions_correct = user_progress.questions_correct + ${performance.correct},
      total_time_spent = user_progress.total_time_spent + ${performance.timeSpent},
      last_activity = NOW()
  `;
}
```

```typescript
// src/lib/server/auth.ts
import { Lucia } from 'lucia';
import { PostgresJsAdapter } from '@lucia-auth/adapter-postgresql';
import { sql } from './database';
import { dev } from '$app/environment';

const adapter = new PostgresJsAdapter(sql, {
  user: 'users',
  session: 'sessions'
});

export const lucia = new Lucia(adapter, {
  sessionCookie: {
    attributes: {
      secure: !dev
    }
  },
  getUserAttributes: (attributes) => {
    return {
      email: attributes.email,
      name: attributes.name,
      role: attributes.role
    };
  }
});

declare module 'lucia' {
  interface Register {
    Lucia: typeof lucia;
    DatabaseUserAttributes: {
      email: string;
      name: string;
      role: string;
    };
  }
}
```

```typescript
// src/routes/api/auth/register/+server.ts
import { json } from '@sveltejs/kit';
import { hash } from '@node-rs/argon2';
import { generateId } from 'lucia';
import { lucia } from '$lib/server/auth';
import { createUser } from '$lib/server/database';
import { z } from 'zod';

const registerSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8),
  name: z.string().min(2).max(100)
});

export async function POST({ request, cookies }) {
  try {
    const body = await request.json();
    const { email, password, name } = registerSchema.parse(body);
    
    const userId = generateId(15);
    const hashedPassword = await hash(password, {
      memoryCost: 19456,
      timeCost: 2,
      outputLen: 32,
      parallelism: 1
    });
    
    const user = await createUser(email, hashedPassword, name);
    
    const session = await lucia.createSession(userId, {});
    const sessionCookie = lucia.createSessionCookie(session.id);
    
    cookies.set(sessionCookie.name, sessionCookie.value, {
      path: '.',
      ...sessionCookie.attributes
    });
    
    return json({
      success: true,
      user: {
        id: user.id,
        email: user.email,
        name: user.name
      }
    });
  } catch (error) {
    return json(
      { success: false, error: 'Registration failed' },
      { status: 400 }
    );
  }
}
```

```svelte
<!-- src/lib/components/advanced/AdminDashboard.svelte -->
<script lang="ts">
  import { onMount } from 'svelte';
  import Chart from 'chart.js/auto';
  
  let canvas: HTMLCanvasElement;
  let chart: Chart;
  
  export let analytics: {
    totalUsers: number;
    activeUsers: number;
    quizzesCompleted: number;
    averageScore: number;
    categoryPerformance: { category: string; avgScore: number }[];
    dailyActivity: { date: string; users: number }[];
  };
  
  onMount(() => {
    if (canvas) {
      chart = new Chart(canvas, {
        type: 'line',
        data: {
          labels: analytics.dailyActivity.map(d => d.date),
          datasets: [{
            label: 'Daily Active Users',
            data: analytics.dailyActivity.map(d => d.users),
            borderColor: 'rgb(59, 130, 246)',
            backgroundColor: 'rgba(59, 130, 246, 0.1)',
            tension: 0.4
          }]
        },
        options: {
          responsive: true,
          plugins: {
            title: {
              display: true,
              text: 'User Activity Over Time'
            }
          },
          scales: {
            y: {
              beginAtZero: true
            }
          }
        }
      });
    }
    
    return () => {
      if (chart) {
        chart.destroy();
      }
    };
  });
</script>

<div class="admin-dashboard">
  <div class="dashboard-header">
    <h1>Admin Dashboard</h1>
    <p>Platform analytics and management</p>
  </div>
  
  <div class="stats-grid">
    <div class="stat-card">
      <div class="stat-icon">👥</div>
      <div class="stat-content">
        <h3>Total Users</h3>
        <p class="stat-number">{analytics.totalUsers.toLocaleString()}</p>
      </div>
    </div>
    
    <div class="stat-card">
      <div class="stat-icon">🟢</div>
      <div class="stat-content">
        <h3>Active Users</h3>
        <p class="stat-number">{analytics.activeUsers.toLocaleString()}</p>
      </div>
    </div>
    
    <div class="stat-card">
      <div class="stat-icon">📝</div>
      <div class="stat-content">
        <h3>Quizzes Completed</h3>
        <p class="stat-number">{analytics.quizzesCompleted.toLocaleString()}</p>
      </div>
    </div>
    
    <div class="stat-card">
      <div class="stat-icon">🎯</div>
      <div class="stat-content">
        <h3>Average Score</h3>
        <p class="stat-number">{analytics.averageScore.toFixed(1)}%</p>
      </div>
    </div>
  </div>
  
  <div class="charts-section">
    <div class="chart-container">
      <canvas bind:this={canvas}></canvas>
    </div>
    
    <div class="category-performance">
      <h3>Category Performance</h3>
      <div class="performance-list">
        {#each analytics.categoryPerformance as category}
          <div class="performance-item">
            <span class="category-name">{category.category}</span>
            <div class="performance-bar">
              <div 
                class="performance-fill" 
                style="width: {category.avgScore}%"
              ></div>
            </div>
            <span class="performance-score">{category.avgScore.toFixed(1)}%</span>
          </div>
        {/each}
      </div>
    </div>
  </div>
</div>

<style>
  .admin-dashboard {
    padding: 2rem;
    max-width: 1200px;
    margin: 0 auto;
  }
  
  .dashboard-header {
    margin-bottom: 2rem;
  }
  
  .dashboard-header h1 {
    font-size: 2.5rem;
    margin-bottom: 0.5rem;
  }
  
  .dashboard-header p {
    color: #666;
    font-size: 1.1rem;
  }
  
  .stats-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
    gap: 1.5rem;
    margin-bottom: 3rem;
  }
  
  .stat-card {
    background: white;
    border-radius: 12px;
    padding: 1.5rem;
    box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
    display: flex;
    align-items: center;
    gap: 1rem;
  }
  
  .stat-icon {
    font-size: 2rem;
    background: #f0f9ff;
    width: 60px;
    height: 60px;
    border-radius: 12px;
    display: flex;
    align-items: center;
    justify-content: center;
  }
  
  .stat-content h3 {
    font-size: 0.9rem;
    color: #666;
    margin-bottom: 0.5rem;
    text-transform: uppercase;
    font-weight: 500;
  }
  
  .stat-number {
    font-size: 2rem;
    font-weight: bold;
    color: #333;
    margin: 0;
  }
  
  .charts-section {
    display: grid;
    grid-template-columns: 2fr 1fr;
    gap: 2rem;
  }
  
  .chart-container {
    background: white;
    border-radius: 12px;
    padding: 1.5rem;
    box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
  }
  
  .category-performance {
    background: white;
    border-radius: 12px;
    padding: 1.5rem;
    box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
  }
  
  .category-performance h3 {
    margin-bottom: 1rem;
    color: #333;
  }
  
  .performance-list {
    display: flex;
    flex-direction: column;
    gap: 1rem;
  }
  
  .performance-item {
    display: flex;
    align-items: center;
    gap: 1rem;
  }
  
  .category-name {
    font-weight: 500;
    min-width: 80px;
    font-size: 0.9rem;
  }
  
  .performance-bar {
    flex: 1;
    height: 8px;
    background: #e0e0e0;
    border-radius: 4px;
    overflow: hidden;
  }
  
  .performance-fill {
    height: 100%;
    background: #3b82f6;
    transition: width 0.5s ease;
  }
  
  .performance-score {
    font-weight: bold;
    color: #3b82f6;
    min-width: 40px;
    text-align: right;
    font-size: 0.9rem;
  }
  
  @media (max-width: 768px) {
    .charts-section {
      grid-template-columns: 1fr;
    }
    
    .stats-grid {
      grid-template-columns: 1fr;
    }
  }
</style>
```

## 🎨 Component Library Template

Reusable UI components for EdTech applications.

```svelte
<!-- src/lib/components/ui/Button.svelte -->
<script lang="ts">
  type ButtonVariant = 'primary' | 'secondary' | 'danger' | 'ghost';
  type ButtonSize = 'sm' | 'md' | 'lg';
  
  export let variant: ButtonVariant = 'primary';
  export let size: ButtonSize = 'md';
  export let disabled = false;
  export let loading = false;
  export let href: string | undefined = undefined;
  export let type: 'button' | 'submit' | 'reset' = 'button';
</script>

{#if href}
  <a 
    {href}
    class="btn btn-{variant} btn-{size}"
    class:disabled
    class:loading
    role="button"
  >
    {#if loading}
      <div class="spinner"></div>
    {/if}
    <slot />
  </a>
{:else}
  <button
    {type}
    {disabled}
    class="btn btn-{variant} btn-{size}"
    class:loading
    on:click
  >
    {#if loading}
      <div class="spinner"></div>
    {/if}
    <slot />
  </button>
{/if}

<style>
  .btn {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    gap: 0.5rem;
    font-weight: 500;
    border-radius: 8px;
    border: 1px solid transparent;
    cursor: pointer;
    transition: all 0.2s;
    text-decoration: none;
    font-family: inherit;
    position: relative;
    overflow: hidden;
  }
  
  .btn:disabled,
  .btn.disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }
  
  .btn.loading {
    color: transparent;
  }
  
  /* Sizes */
  .btn-sm {
    padding: 0.5rem 1rem;
    font-size: 0.875rem;
  }
  
  .btn-md {
    padding: 0.75rem 1.5rem;
    font-size: 1rem;
  }
  
  .btn-lg {
    padding: 1rem 2rem;
    font-size: 1.125rem;
  }
  
  /* Variants */
  .btn-primary {
    background: #3b82f6;
    color: white;
  }
  
  .btn-primary:hover:not(:disabled):not(.disabled) {
    background: #2563eb;
  }
  
  .btn-secondary {
    background: #6b7280;
    color: white;
  }
  
  .btn-secondary:hover:not(:disabled):not(.disabled) {
    background: #4b5563;
  }
  
  .btn-danger {
    background: #ef4444;
    color: white;
  }
  
  .btn-danger:hover:not(:disabled):not(.disabled) {
    background: #dc2626;
  }
  
  .btn-ghost {
    background: transparent;
    color: #3b82f6;
    border-color: #3b82f6;
  }
  
  .btn-ghost:hover:not(:disabled):not(.disabled) {
    background: #3b82f6;
    color: white;
  }
  
  /* Loading spinner */
  .spinner {
    position: absolute;
    width: 1rem;
    height: 1rem;
    border: 2px solid transparent;
    border-top: 2px solid currentColor;
    border-radius: 50%;
    animation: spin 1s linear infinite;
  }
  
  @keyframes spin {
    to {
      transform: rotate(360deg);
    }
  }
</style>
```

```svelte
<!-- src/lib/components/ui/Modal.svelte -->
<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { fly, fade } from 'svelte/transition';
  
  export let open = false;
  export let title = '';
  export let size: 'sm' | 'md' | 'lg' | 'xl' = 'md';
  export let closable = true;
  
  const dispatch = createEventDispatcher<{
    close: void;
  }>();
  
  function handleClose() {
    if (closable) {
      open = false;
      dispatch('close');
    }
  }
  
  function handleBackdropClick(event: MouseEvent) {
    if (event.target === event.currentTarget) {
      handleClose();
    }
  }
  
  function handleKeydown(event: KeyboardEvent) {
    if (event.key === 'Escape' && closable) {
      handleClose();
    }
  }
</script>

{#if open}
  <div 
    class="modal-backdrop" 
    transition:fade={{ duration: 200 }}
    on:click={handleBackdropClick}
    on:keydown={handleKeydown}
    role="dialog"
    aria-modal="true"
    aria-labelledby={title ? 'modal-title' : undefined}
  >
    <div 
      class="modal modal-{size}"
      transition:fly={{ y: 50, duration: 300 }}
    >
      {#if title || closable}
        <div class="modal-header">
          {#if title}
            <h2 id="modal-title" class="modal-title">{title}</h2>
          {/if}
          
          {#if closable}
            <button 
              class="close-button"
              on:click={handleClose}
              aria-label="Close modal"
            >
              ×
            </button>
          {/if}
        </div>
      {/if}
      
      <div class="modal-body">
        <slot />
      </div>
      
      {#if $$slots.footer}
        <div class="modal-footer">
          <slot name="footer" />
        </div>
      {/if}
    </div>
  </div>
{/if}

<style>
  .modal-backdrop {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(0, 0, 0, 0.5);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 1000;
    padding: 1rem;
  }
  
  .modal {
    background: white;
    border-radius: 12px;
    box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.25);
    max-height: 90vh;
    overflow: hidden;
    display: flex;
    flex-direction: column;
  }
  
  .modal-sm {
    width: 100%;
    max-width: 24rem;
  }
  
  .modal-md {
    width: 100%;
    max-width: 32rem;
  }
  
  .modal-lg {
    width: 100%;
    max-width: 48rem;
  }
  
  .modal-xl {
    width: 100%;
    max-width: 64rem;
  }
  
  .modal-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 1.5rem;
    border-bottom: 1px solid #e5e7eb;
  }
  
  .modal-title {
    margin: 0;
    font-size: 1.25rem;
    font-weight: 600;
    color: #111827;
  }
  
  .close-button {
    background: none;
    border: none;
    font-size: 1.5rem;
    cursor: pointer;
    padding: 0.25rem;
    line-height: 1;
    color: #6b7280;
  }
  
  .close-button:hover {
    color: #111827;
  }
  
  .modal-body {
    padding: 1.5rem;
    overflow-y: auto;
    flex: 1;
  }
  
  .modal-footer {
    padding: 1.5rem;
    border-top: 1px solid #e5e7eb;
    display: flex;
    gap: 1rem;
    justify-content: flex-end;
  }
  
  @media (max-width: 640px) {
    .modal {
      margin: 0;
      min-height: 100vh;
      border-radius: 0;
    }
    
    .modal-backdrop {
      padding: 0;
    }
  }
</style>
```

## 📱 PWA Template

Progressive Web App with offline capabilities.

```javascript
// src/service-worker.js
import { build, files, version } from '$service-worker';

const CACHE_NAME = `edtech-pwa-${version}`;
const ASSETS = [...build, ...files];

// Install event
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then((cache) => cache.addAll(ASSETS))
      .then(() => self.skipWaiting())
  );
});

// Activate event
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then(async (keys) => {
      for (const key of keys) {
        if (key !== CACHE_NAME) {
          await caches.delete(key);
        }
      }
      self.clients.claim();
    })
  );
});

// Fetch event
self.addEventListener('fetch', (event) => {
  if (event.request.method !== 'GET') return;
  
  event.respondWith(
    caches.open(CACHE_NAME).then(async (cache) => {
      const cachedResponse = await cache.match(event.request);
      
      if (cachedResponse) {
        // Serve from cache
        return cachedResponse;
      }
      
      try {
        // Try network
        const networkResponse = await fetch(event.request);
        
        // Cache successful responses
        if (networkResponse.ok && event.request.url.startsWith('http')) {
          cache.put(event.request, networkResponse.clone());
        }
        
        return networkResponse;
      } catch {
        // Network failed
        if (event.request.mode === 'navigate') {
          return cache.match('/offline.html') || 
                 new Response('You are offline', { status: 503 });
        }
        
        throw new Error('Network unavailable');
      }
    })
  );
});

// Background sync
self.addEventListener('sync', (event) => {
  if (event.tag === 'quiz-sync') {
    event.waitUntil(syncQuizData());
  }
});

async function syncQuizData() {
  // Sync offline quiz data when online
  try {
    const db = await openDB();
    const pendingQuizzes = await db.getAll('pending-quizzes');
    
    for (const quiz of pendingQuizzes) {
      await fetch('/api/quiz/submit', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(quiz.data)
      });
      
      await db.delete('pending-quizzes', quiz.id);
    }
  } catch (error) {
    console.error('Sync failed:', error);
  }
}
```

```json
// static/manifest.json
{
  "name": "EdTech Quiz Platform",
  "short_name": "EduQuiz",
  "description": "Interactive quiz platform for educational excellence",
  "start_url": "/",
  "display": "standalone",
  "background_color": "#ffffff",
  "theme_color": "#3b82f6",
  "orientation": "portrait-primary",
  "scope": "/",
  "lang": "en",
  "categories": ["education", "productivity"],
  "icons": [
    {
      "src": "/icon-192.png",
      "sizes": "192x192",
      "type": "image/png",
      "purpose": "any maskable"
    },
    {
      "src": "/icon-512.png",
      "sizes": "512x512",
      "type": "image/png",
      "purpose": "any maskable"
    }
  ],
  "shortcuts": [
    {
      "name": "Start Quiz",
      "short_name": "Quiz",
      "description": "Jump straight into a quiz",
      "url": "/quiz",
      "icons": [
        {
          "src": "/shortcut-quiz.png",
          "sizes": "96x96"
        }
      ]
    },
    {
      "name": "Dashboard",
      "short_name": "Dashboard",
      "description": "View your progress",
      "url": "/dashboard",
      "icons": [
        {
          "src": "/shortcut-dashboard.png",
          "sizes": "96x96"
        }
      ]
    }
  ]
}
```

## 🚀 Deployment Templates

### Vercel Deployment

```json
// vercel.json
{
  "framework": "sveltekit",
  "regions": ["sin1", "hnd1", "syd1"],
  "functions": {
    "src/routes/api/**/*.ts": {
      "maxDuration": 30
    }
  },
  "headers": [
    {
      "source": "/service-worker.js",
      "headers": [
        {
          "key": "Cache-Control",
          "value": "public, max-age=0, must-revalidate"
        },
        {
          "key": "Service-Worker-Allowed",
          "value": "/"
        }
      ]
    },
    {
      "source": "/manifest.json",
      "headers": [
        {
          "key": "Cache-Control",
          "value": "public, max-age=31536000, immutable"
        }
      ]
    }
  ],
  "rewrites": [
    {
      "source": "/api/health",
      "destination": "/api/health"
    }
  ]
}
```

### Docker Deployment

```dockerfile
# Dockerfile.production
FROM node:18-alpine AS base

# Install dependencies
FROM base AS deps
RUN apk add --no-cache libc6-compat
WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm ci --only=production

# Build application
FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

ENV NODE_ENV production
RUN npm run build

# Production image
FROM base AS runner
WORKDIR /app

ENV NODE_ENV production
ENV ORIGIN https://yourdomain.com

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 sveltekit

COPY --from=builder /app/build ./build
COPY --from=builder /app/package.json ./package.json
COPY --from=deps /app/node_modules ./node_modules

USER sveltekit

EXPOSE 3000
ENV PORT 3000
ENV HOST 0.0.0.0

CMD ["node", "build"]
```

## 📦 Package Scripts Template

```json
// package.json
{
  "name": "edtech-platform",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "dev": "vite dev",
    "build": "vite build",
    "preview": "vite preview",
    "test": "vitest",
    "test:unit": "vitest run",
    "test:integration": "vitest run src/**/*.integration.test.ts",
    "test:e2e": "playwright test",
    "test:coverage": "vitest run --coverage",
    "lint": "prettier --check . && eslint .",
    "format": "prettier --write .",
    "typecheck": "svelte-kit sync && svelte-check --tsconfig ./tsconfig.json",
    "db:generate": "drizzle-kit generate:pg",
    "db:migrate": "tsx scripts/migrate.ts",
    "db:seed": "tsx scripts/seed.ts",
    "deploy:vercel": "vercel --prod",
    "deploy:docker": "docker build -t edtech-platform .",
    "start:prod": "NODE_ENV=production node build"
  },
  "devDependencies": {
    "@playwright/test": "^1.40.0",
    "@sveltejs/adapter-auto": "^2.0.0",
    "@sveltejs/kit": "^1.20.4",
    "@sveltejs/vite-plugin-svelte": "^2.4.2",
    "@testing-library/jest-dom": "^6.1.4",
    "@testing-library/svelte": "^4.0.5",
    "@testing-library/user-event": "^14.5.1",
    "@types/uuid": "^9.0.7",
    "eslint": "^8.52.0",
    "eslint-config-prettier": "^9.0.0",
    "jsdom": "^23.0.1",
    "prettier": "^3.0.0",
    "prettier-plugin-svelte": "^3.0.0",
    "svelte": "^4.0.5",
    "svelte-check": "^3.6.0",
    "tslib": "^2.4.1",
    "typescript": "^5.0.0",
    "vite": "^4.4.2",
    "vitest": "^0.34.0"
  },
  "dependencies": {
    "@lucia-auth/adapter-postgresql": "^3.0.0",
    "@sendgrid/mail": "^8.1.0",
    "chart.js": "^4.4.0",
    "date-fns": "^2.30.0",
    "lucia": "^3.0.0",
    "postgres": "^3.4.3",
    "stripe": "^14.7.0",
    "uuid": "^9.0.1",
    "zod": "^3.22.4"
  }
}
```

## 🎯 Usage Instructions

### Getting Started with Templates

1. **Choose Your Template**:
```bash
# Minimal quiz app (learning)
npx degit your-repo/minimal-quiz-app my-quiz-app

# Full platform (production)
npx degit your-repo/edtech-platform my-platform

# Component library (design system)
npx degit your-repo/svelte-ui-components my-components
```

2. **Install Dependencies**:
```bash
cd my-project
npm install
```

3. **Configure Environment**:
```bash
cp .env.example .env.local
# Edit .env.local with your configuration
```

4. **Start Development**:
```bash
npm run dev
```

### Customization Guide

1. **Branding**: Update colors, fonts, and logos in `src/app.html` and CSS variables
2. **Features**: Enable/disable features in configuration files
3. **Database**: Modify schema in `migrations/` directory
4. **Styling**: Customize component styles or add Tailwind CSS
5. **Deployment**: Configure for your preferred hosting platform

---

## 🔗 Continue Reading

- **Previous**: [Testing Strategies](./testing-strategies.md) - Quality assurance approaches
- **Main Guide**: [README](./README.md) - Research overview and navigation
- **Implementation**: [Implementation Guide](./implementation-guide.md) - Detailed setup instructions

---

## 📚 Template References

1. **[SvelteKit Examples](https://github.com/sveltejs/kit/tree/master/examples)** - Official example applications
2. **[Svelte Society Templates](https://sveltesociety.dev/templates)** - Community-maintained templates
3. **[Skeleton UI Toolkit](https://www.skeleton.dev/)** - Svelte UI component library
4. **[SvelteKit PWA](https://vite-pwa-org.netlify.app/frameworks/sveltekit.html)** - PWA integration guide
5. **[SvelteKit Auth Examples](https://lucia-auth.com/getting-started/sveltekit)** - Authentication templates
6. **[Svelte Component Library Template](https://github.com/YogliB/svelte-component-template)** - Component library setup

---

*Template Examples completed January 2025 | Production-ready code templates for immediate use*