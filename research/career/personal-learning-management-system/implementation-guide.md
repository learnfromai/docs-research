# Implementation Guide: Personal Learning Management System

## Phase 1: Foundation Setup (Weeks 1-4)

### 1.1 Environment Preparation

**Development Environment Setup:**

```bash
# Node.js and Package Manager Setup
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
nvm install 20
nvm use 20
npm install -g yarn pnpm

# Create Project Structure
mkdir personal-lms
cd personal-lms
npx create-next-app@latest . --typescript --tailwind --eslint --app
```

**Essential Dependencies:**

```json
{
  "dependencies": {
    "next": "^14.0.0",
    "react": "^18.0.0",
    "typescript": "^5.0.0",
    "@prisma/client": "^5.7.0",
    "next-auth": "^4.24.0",
    "@tanstack/react-query": "^5.0.0",
    "framer-motion": "^10.16.0",
    "recharts": "^2.8.0",
    "lucide-react": "^0.294.0"
  },
  "devDependencies": {
    "prisma": "^5.7.0",
    "@types/node": "^20.0.0",
    "tailwindcss": "^3.3.0",
    "eslint": "^8.0.0",
    "prettier": "^3.0.0"
  }
}
```

### 1.2 Database Schema Design

**Core Database Schema (PostgreSQL):**

```sql
-- Users and Authentication
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Learning Tracks (Main Categories)
CREATE TABLE learning_tracks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(255) NOT NULL,
    description TEXT,
    difficulty_level INTEGER CHECK (difficulty_level >= 1 AND difficulty_level <= 5),
    estimated_hours INTEGER,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Modules within Learning Tracks
CREATE TABLE modules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    track_id UUID REFERENCES learning_tracks(id),
    title VARCHAR(255) NOT NULL,
    description TEXT,
    order_index INTEGER,
    is_required BOOLEAN DEFAULT true,
    estimated_hours INTEGER,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Individual Lessons
CREATE TABLE lessons (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    module_id UUID REFERENCES modules(id),
    title VARCHAR(255) NOT NULL,
    content JSONB, -- Flexible content structure
    lesson_type VARCHAR(50), -- video, article, exercise, quiz
    order_index INTEGER,
    estimated_minutes INTEGER,
    created_at TIMESTAMP DEFAULT NOW()
);

-- User Progress Tracking
CREATE TABLE user_progress (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id),
    lesson_id UUID REFERENCES lessons(id),
    status VARCHAR(50) DEFAULT 'not_started', -- not_started, in_progress, completed
    progress_percentage INTEGER DEFAULT 0,
    time_spent_minutes INTEGER DEFAULT 0,
    completed_at TIMESTAMP,
    last_accessed_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(user_id, lesson_id)
);

-- Assessment and Quiz Results
CREATE TABLE assessments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    lesson_id UUID REFERENCES lessons(id),
    title VARCHAR(255) NOT NULL,
    questions JSONB, -- Array of question objects
    passing_score INTEGER DEFAULT 70,
    time_limit_minutes INTEGER,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE assessment_attempts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id),
    assessment_id UUID REFERENCES assessments(id),
    score INTEGER,
    answers JSONB,
    time_taken_minutes INTEGER,
    passed BOOLEAN,
    attempted_at TIMESTAMP DEFAULT NOW()
);

-- Spaced Repetition System
CREATE TABLE flashcards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    lesson_id UUID REFERENCES lessons(id),
    front_content TEXT NOT NULL,
    back_content TEXT NOT NULL,
    difficulty_level INTEGER DEFAULT 1,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE user_flashcard_reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id),
    flashcard_id UUID REFERENCES flashcards(id),
    ease_factor DECIMAL(3,2) DEFAULT 2.5,
    interval_days INTEGER DEFAULT 1,
    repetitions INTEGER DEFAULT 0,
    next_review_date DATE,
    last_reviewed_at TIMESTAMP DEFAULT NOW(),
    quality_rating INTEGER CHECK (quality_rating >= 0 AND quality_rating <= 5),
    UNIQUE(user_id, flashcard_id)
);
```

### 1.3 Project Structure Setup

```
personal-lms/
├── app/                          # Next.js App Router
│   ├── (auth)/                   # Authentication pages
│   ├── dashboard/                # Main learning dashboard
│   ├── tracks/                   # Learning tracks pages
│   ├── progress/                 # Progress tracking
│   └── api/                      # API endpoints
├── components/                   # Reusable UI components
│   ├── ui/                       # Base UI components
│   ├── learning/                 # Learning-specific components
│   └── dashboard/                # Dashboard components
├── lib/                          # Utility functions
│   ├── db.ts                     # Database connection
│   ├── auth.ts                   # Authentication logic
│   └── spaced-repetition.ts      # SRS algorithm
├── prisma/                       # Database schema and migrations
├── public/                       # Static assets
└── types/                        # TypeScript type definitions
```

## Phase 2: Core Features Development (Weeks 5-8)

### 2.1 Authentication System

**NextAuth.js Configuration:**

```typescript
// lib/auth.ts
import NextAuth from 'next-auth'
import GoogleProvider from 'next-auth/providers/google'
import { PrismaAdapter } from "@auth/prisma-adapter"
import { prisma } from './db'

export const authOptions = {
  adapter: PrismaAdapter(prisma),
  providers: [
    GoogleProvider({
      clientId: process.env.GOOGLE_CLIENT_ID!,
      clientSecret: process.env.GOOGLE_CLIENT_SECRET!,
    }),
  ],
  callbacks: {
    session: ({ session, user }) => ({
      ...session,
      user: {
        ...session.user,
        id: user.id,
      },
    }),
  },
}

export default NextAuth(authOptions)
```

### 2.2 Learning Dashboard Implementation

**Dashboard Component:**

```typescript
// components/dashboard/LearningDashboard.tsx
import { useQuery } from '@tanstack/react-query'
import { Progress } from '@/components/ui/progress'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'

interface DashboardStats {
  totalTracks: number
  completedLessons: number
  totalLessons: number
  currentStreak: number
  weeklyHours: number
}

export function LearningDashboard() {
  const { data: stats } = useQuery<DashboardStats>({
    queryKey: ['dashboard-stats'],
    queryFn: () => fetch('/api/dashboard/stats').then(res => res.json())
  })

  if (!stats) return <div>Loading...</div>

  const completionRate = Math.round((stats.completedLessons / stats.totalLessons) * 100)

  return (
    <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-4">
      <Card>
        <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
          <CardTitle className="text-sm font-medium">Overall Progress</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="text-2xl font-bold">{completionRate}%</div>
          <Progress value={completionRate} className="mt-2" />
          <p className="text-xs text-muted-foreground mt-2">
            {stats.completedLessons} of {stats.totalLessons} lessons completed
          </p>
        </CardContent>
      </Card>
      
      <Card>
        <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
          <CardTitle className="text-sm font-medium">Current Streak</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="text-2xl font-bold">{stats.currentStreak}</div>
          <p className="text-xs text-muted-foreground">
            days of consistent learning
          </p>
        </CardContent>
      </Card>

      <Card>
        <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
          <CardTitle className="text-sm font-medium">This Week</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="text-2xl font-bold">{stats.weeklyHours}h</div>
          <p className="text-xs text-muted-foreground">
            hours of focused learning
          </p>
        </CardContent>
      </Card>

      <Card>
        <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
          <CardTitle className="text-sm font-medium">Active Tracks</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="text-2xl font-bold">{stats.totalTracks}</div>
          <p className="text-xs text-muted-foreground">
            learning tracks in progress
          </p>
        </CardContent>
      </Card>
    </div>
  )
}
```

### 2.3 Content Management System

**Lesson Content Structure:**

```typescript
// types/learning.ts
export interface LessonContent {
  type: 'video' | 'article' | 'exercise' | 'quiz'
  title: string
  data: VideoContent | ArticleContent | ExerciseContent | QuizContent
}

export interface VideoContent {
  videoUrl: string
  duration: number // seconds
  transcript?: string
  subtitles?: SubtitleTrack[]
}

export interface ArticleContent {
  content: string // Markdown content
  readingTimeMinutes: number
  codeExamples?: CodeExample[]
}

export interface QuizContent {
  questions: QuizQuestion[]
  passingScore: number
  timeLimit?: number
}

export interface QuizQuestion {
  id: string
  type: 'multiple-choice' | 'true-false' | 'code-completion'
  question: string
  options?: string[]
  correctAnswer: string | string[]
  explanation: string
}
```

## Phase 3: Advanced Features (Weeks 9-12)

### 3.1 Spaced Repetition System Implementation

**SuperMemo-2 Algorithm Implementation:**

```typescript
// lib/spaced-repetition.ts
export interface ReviewCard {
  id: string
  easeFactor: number
  interval: number
  repetitions: number
  nextReviewDate: Date
}

export function calculateNextReview(
  card: ReviewCard,
  qualityRating: number // 0-5 scale
): ReviewCard {
  let { easeFactor, interval, repetitions } = card
  
  // SuperMemo-2 algorithm
  if (qualityRating >= 3) {
    if (repetitions === 0) {
      interval = 1
    } else if (repetitions === 1) {
      interval = 6
    } else {
      interval = Math.round(interval * easeFactor)
    }
    repetitions += 1
  } else {
    repetitions = 0
    interval = 1
  }
  
  // Update ease factor
  easeFactor = easeFactor + (0.1 - (5 - qualityRating) * (0.08 + (5 - qualityRating) * 0.02))
  if (easeFactor < 1.3) easeFactor = 1.3
  
  const nextReviewDate = new Date()
  nextReviewDate.setDate(nextReviewDate.getDate() + interval)
  
  return {
    ...card,
    easeFactor,
    interval,
    repetitions,
    nextReviewDate
  }
}

export async function getDueCards(userId: string): Promise<ReviewCard[]> {
  const today = new Date()
  today.setHours(0, 0, 0, 0)
  
  return await prisma.userFlashcardReviews.findMany({
    where: {
      userId,
      nextReviewDate: {
        lte: today
      }
    },
    include: {
      flashcard: true
    }
  })
}
```

### 3.2 Learning Analytics Dashboard

**Progress Analytics Component:**

```typescript
// components/analytics/ProgressAnalytics.tsx
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts'

interface ProgressData {
  date: string
  hoursStudied: number
  lessonsCompleted: number
  quizScore: number
}

export function ProgressAnalytics() {
  const { data: progressData } = useQuery<ProgressData[]>({
    queryKey: ['progress-analytics'],
    queryFn: () => fetch('/api/analytics/progress').then(res => res.json())
  })

  return (
    <div className="space-y-8">
      <div>
        <h3 className="text-lg font-medium mb-4">Learning Progress Over Time</h3>
        <ResponsiveContainer width="100%" height={400}>
          <LineChart data={progressData}>
            <CartesianGrid strokeDasharray="3 3" />
            <XAxis dataKey="date" />
            <YAxis />
            <Tooltip />
            <Line 
              type="monotone" 
              dataKey="hoursStudied" 
              stroke="#8884d8" 
              strokeWidth={2}
              name="Hours Studied"
            />
            <Line 
              type="monotone" 
              dataKey="lessonsCompleted" 
              stroke="#82ca9d" 
              strokeWidth={2}
              name="Lessons Completed"
            />
          </LineChart>
        </ResponsiveContainer>
      </div>
    </div>
  )
}
```

## Phase 4: Deployment and Optimization (Weeks 13-16)

### 4.1 Production Deployment

**Vercel Deployment Configuration:**

```json
{
  "version": 2,
  "builds": [
    {
      "src": "package.json",
      "use": "@vercel/next"
    }
  ],
  "env": {
    "DATABASE_URL": "@database-url",
    "NEXTAUTH_SECRET": "@nextauth-secret",
    "NEXTAUTH_URL": "https://your-domain.vercel.app"
  }
}
```

**Environment Variables Setup:**

```bash
# .env.local
DATABASE_URL="postgresql://username:password@host:port/database"
NEXTAUTH_SECRET="your-secret-key"
NEXTAUTH_URL="http://localhost:3000"
GOOGLE_CLIENT_ID="your-google-client-id"
GOOGLE_CLIENT_SECRET="your-google-client-secret"
```

### 4.2 Performance Optimization

**Next.js Optimization:**

```typescript
// next.config.js
/** @type {import('next').NextConfig} */
const nextConfig = {
  experimental: {
    appDir: true,
  },
  images: {
    domains: ['your-cdn-domain.com'],
  },
  compiler: {
    styledComponents: true,
  },
  // Enable PWA
  pwa: {
    dest: 'public',
    disable: process.env.NODE_ENV === 'development',
  }
}

module.exports = nextConfig
```

### 4.3 Monitoring and Analytics

**Analytics Integration:**

```typescript
// lib/analytics.ts
import { Analytics } from '@segment/analytics-node'

const analytics = new Analytics({
  writeKey: process.env.SEGMENT_WRITE_KEY!,
})

export function trackLessonCompleted(userId: string, lessonId: string, timeSpent: number) {
  analytics.track({
    userId,
    event: 'Lesson Completed',
    properties: {
      lessonId,
      timeSpentMinutes: timeSpent,
      timestamp: new Date().toISOString()
    }
  })
}

export function trackQuizAttempt(userId: string, quizId: string, score: number) {
  analytics.track({
    userId,
    event: 'Quiz Attempted',
    properties: {
      quizId,
      score,
      passed: score >= 70,
      timestamp: new Date().toISOString()
    }
  })
}
```

## Phase 5: Philippine EdTech Adaptation (Weeks 17-20)

### 5.1 Licensure Exam Content Structure

**Philippine Professional Licensing Integration:**

```typescript
// types/philippine-licensing.ts
export interface LicensureExam {
  id: string
  profession: string // 'civil-engineer', 'electrical-engineer', 'nurse', etc.
  board: string // Professional Regulation Commission board
  subjects: LicensureSubject[]
  passingRate: number
  examSchedule: ExamSchedule[]
}

export interface LicensureSubject {
  id: string
  name: string
  weightPercentage: number
  topics: Topic[]
  sampleQuestions: Question[]
}

export interface ExamSchedule {
  date: Date
  registrationDeadline: Date
  location: string[]
  fees: {
    application: number
    examination: number
  }
}
```

### 5.2 Local Payment Integration

**GCash and PayMaya Integration:**

```typescript
// lib/payments/philippine-payments.ts
import { PayMongo } from '@paymongo/paymongo-js'

const paymongo = new PayMongo(process.env.PAYMONGO_SECRET_KEY!)

export async function createGCashPayment(amount: number, description: string) {
  const source = await paymongo.sources.create({
    type: 'gcash',
    amount: amount * 100, // Convert to centavos
    currency: 'PHP',
    redirect: {
      success: `${process.env.NEXTAUTH_URL}/payment/success`,
      failed: `${process.env.NEXTAUTH_URL}/payment/failed`
    }
  })
  
  return source
}

export async function createPayMayaPayment(amount: number, description: string) {
  const source = await paymongo.sources.create({
    type: 'paymaya',
    amount: amount * 100,
    currency: 'PHP',
    redirect: {
      success: `${process.env.NEXTAUTH_URL}/payment/success`,
      failed: `${process.env.NEXTAUTH_URL}/payment/failed`
    }
  })
  
  return source
}
```

## Success Metrics and KPIs

### Technical Metrics
- **Page Load Speed**: Target <2 seconds
- **Mobile Performance**: Lighthouse score >90
- **Database Query Time**: Average <100ms
- **API Response Time**: Average <200ms

### User Engagement Metrics
- **Daily Active Users**: Target 70% of registered users
- **Session Duration**: Target >25 minutes average
- **Course Completion Rate**: Target >60%
- **User Retention**: 80% weekly, 50% monthly

### Business Metrics (for EdTech Platform)
- **Customer Acquisition Cost**: <₱450 per user
- **Lifetime Value**: >₱12,000 per user
- **Monthly Recurring Revenue Growth**: 15% monthly
- **Churn Rate**: <5% monthly

---

This implementation guide provides a comprehensive roadmap for building a Personal Learning Management System from foundation to production deployment, with specific adaptations for the Philippine edtech market.

---

← [Executive Summary](./executive-summary.md) | [Best Practices →](./best-practices.md)