# Best Practices: Next.js Full Stack Development

## 🎯 Overview

This document outlines proven best practices for developing full-stack educational platforms with Next.js, covering code organization, performance optimization, security patterns, and maintainability strategies specifically tailored for educational technology applications.

## 🏗️ Project Architecture & Code Organization

### Folder Structure Best Practices

```
src/
├── app/                           # App Router (Next.js 13+)
│   ├── (auth)/                   # Route groups for authentication
│   │   ├── login/
│   │   ├── register/
│   │   └── layout.tsx            # Auth-specific layout
│   ├── (dashboard)/              # Protected dashboard routes
│   │   ├── courses/
│   │   ├── progress/
│   │   ├── settings/
│   │   └── layout.tsx            # Dashboard layout
│   ├── (marketing)/              # Public marketing pages
│   │   ├── about/
│   │   ├── pricing/
│   │   └── layout.tsx            # Marketing layout
│   ├── api/                      # API routes
│   │   ├── auth/
│   │   ├── courses/
│   │   ├── users/
│   │   └── webhooks/             # External service webhooks
│   ├── globals.css
│   ├── layout.tsx                # Root layout
│   ├── loading.tsx               # Global loading UI
│   ├── error.tsx                 # Global error UI
│   ├── not-found.tsx             # 404 page
│   └── page.tsx                  # Home page
├── components/                   # Reusable components
│   ├── ui/                      # Base UI components (shadcn/ui style)
│   │   ├── button.tsx
│   │   ├── input.tsx
│   │   ├── modal.tsx
│   │   └── index.ts             # Barrel exports
│   ├── forms/                   # Form-specific components
│   │   ├── auth-forms/
│   │   ├── course-forms/
│   │   └── user-forms/
│   ├── layouts/                 # Layout components
│   │   ├── header.tsx
│   │   ├── footer.tsx
│   │   ├── sidebar.tsx
│   │   └── navigation.tsx
│   └── features/                # Feature-specific components
│       ├── courses/
│       ├── authentication/
│       ├── user-progress/
│       └── analytics/
├── lib/                         # Utility libraries
│   ├── auth.ts                  # Authentication configuration
│   ├── db.ts                    # Database connection
│   ├── utils.ts                 # General utilities
│   ├── validations.ts           # Zod schemas
│   ├── constants.ts             # Application constants
│   └── api-client.ts            # API client configuration
├── hooks/                       # Custom React hooks
│   ├── use-auth.ts
│   ├── use-courses.ts
│   ├── use-progress.ts
│   └── use-debounce.ts
├── types/                       # TypeScript type definitions
│   ├── auth.ts
│   ├── course.ts
│   ├── user.ts
│   └── api.ts
├── stores/                      # State management (Zustand)
│   ├── auth-store.ts
│   ├── course-store.ts
│   └── ui-store.ts
└── styles/                      # Additional styles
    ├── components.css
    └── utilities.css
```

### Component Organization Patterns

#### 1. Feature-Based Component Structure

```typescript
// ✅ Good: Feature-based organization
components/
├── features/
│   ├── courses/
│   │   ├── course-card.tsx
│   │   ├── course-list.tsx
│   │   ├── course-detail.tsx
│   │   ├── enroll-button.tsx
│   │   └── index.ts            # Barrel export
│   ├── authentication/
│   │   ├── login-form.tsx
│   │   ├── register-form.tsx
│   │   ├── auth-provider.tsx
│   │   └── index.ts
│   └── user-progress/
│       ├── progress-bar.tsx
│       ├── lesson-tracker.tsx
│       └── index.ts

// ❌ Avoid: Generic component organization
components/
├── cards.tsx                   # Too generic
├── forms.tsx                   # Everything in one file
└── buttons.tsx                 # Not feature-specific
```

#### 2. Component Composition Patterns

```typescript
// ✅ Good: Compound component pattern
export function CourseCard({ children, ...props }: CourseCardProps) {
  return (
    <div className="course-card" {...props}>
      {children}
    </div>
  )
}

CourseCard.Header = function CourseCardHeader({ children }: { children: React.ReactNode }) {
  return <div className="course-card-header">{children}</div>
}

CourseCard.Content = function CourseCardContent({ children }: { children: React.ReactNode }) {
  return <div className="course-card-content">{children}</div>
}

CourseCard.Actions = function CourseCardActions({ children }: { children: React.ReactNode }) {
  return <div className="course-card-actions">{children}</div>
}

// Usage
<CourseCard>
  <CourseCard.Header>
    <h3>{course.title}</h3>
  </CourseCard.Header>
  <CourseCard.Content>
    <p>{course.description}</p>
  </CourseCard.Content>
  <CourseCard.Actions>
    <EnrollButton courseId={course.id} />
  </CourseCard.Actions>
</CourseCard>
```

## ⚡ Performance Optimization

### Rendering Strategy Selection

#### When to Use SSG (Static Site Generation)
```typescript
// ✅ Perfect for: Course catalog pages, marketing content
export async function generateStaticParams() {
  const courses = await prisma.course.findMany({
    where: { published: true },
    select: { slug: true },
  })

  return courses.map((course) => ({
    slug: course.slug,
  }))
}

// With ISR (Incremental Static Regeneration)
export const revalidate = 3600 // Revalidate every hour

export default async function CoursePage({ params }: { params: { slug: string } }) {
  const course = await getCourseBySlug(params.slug)
  return <CourseDetail course={course} />
}
```

#### When to Use SSR (Server-Side Rendering)
```typescript
// ✅ Perfect for: User dashboards, personalized content
export default async function DashboardPage() {
  const session = await getServerSession(authOptions)
  
  if (!session) {
    redirect('/auth/login')
  }

  // Fresh data on every request
  const userProgress = await getUserProgress(session.user.id)
  const enrolledCourses = await getUserCourses(session.user.id)

  return (
    <Dashboard 
      progress={userProgress} 
      courses={enrolledCourses} 
    />
  )
}
```

#### When to Use Client-Side Rendering
```typescript
// ✅ Perfect for: Interactive components, real-time features
'use client'

export function InteractiveQuiz({ questionId }: { questionId: string }) {
  const [answer, setAnswer] = useState('')
  const [feedback, setFeedback] = useState<string | null>(null)

  const submitAnswer = async () => {
    const result = await fetch(`/api/quiz/${questionId}/submit`, {
      method: 'POST',
      body: JSON.stringify({ answer }),
    })
    const data = await result.json()
    setFeedback(data.feedback)
  }

  return (
    <div>
      <input 
        value={answer} 
        onChange={(e) => setAnswer(e.target.value)} 
      />
      <button onClick={submitAnswer}>Submit</button>
      {feedback && <div>{feedback}</div>}
    </div>
  )
}
```

### Image Optimization

```typescript
// ✅ Best practices for educational content images
import Image from 'next/image'

export function CourseImage({ course }: { course: Course }) {
  return (
    <div className="relative aspect-video">
      <Image
        src={course.thumbnail || '/default-course.jpg'}
        alt={course.title}
        fill
        className="object-cover rounded-lg"
        sizes="(max-width: 768px) 100vw, (max-width: 1200px) 50vw, 33vw"
        priority={false} // Only true for above-the-fold images
        placeholder="blur"
        blurDataURL="data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD..."
      />
    </div>
  )
}

// next.config.js
module.exports = {
  images: {
    domains: ['cdn.education-platform.com', 'storage.googleapis.com'],
    formats: ['image/webp', 'image/avif'],
    deviceSizes: [640, 750, 828, 1080, 1200, 1920, 2048, 3840],
    imageSizes: [16, 32, 48, 64, 96, 128, 256, 384],
  },
}
```

### Code Splitting & Dynamic Imports

```typescript
// ✅ Lazy load heavy components
import dynamic from 'next/dynamic'

const VideoPlayer = dynamic(() => import('@/components/video-player'), {
  loading: () => <div className="animate-pulse bg-gray-200 aspect-video rounded" />,
  ssr: false, // Client-side only for video players
})

const ChartComponent = dynamic(() => import('@/components/analytics-chart'), {
  loading: () => <div>Loading chart...</div>,
})

// ✅ Bundle splitting for large libraries
const ReactQuill = dynamic(() => import('react-quill'), {
  ssr: false,
  loading: () => <div>Loading editor...</div>,
})
```

## 🔒 Security Best Practices

### Authentication & Authorization

```typescript
// ✅ Secure API route pattern
import { getServerSession } from 'next-auth'
import { authOptions } from '@/lib/auth'
import { z } from 'zod'

const updateCourseSchema = z.object({
  title: z.string().min(1).max(200),
  description: z.string().max(1000),
  published: z.boolean(),
})

export async function PUT(
  request: Request,
  { params }: { params: { id: string } }
) {
  try {
    // Authentication check
    const session = await getServerSession(authOptions)
    if (!session) {
      return new Response('Unauthorized', { status: 401 })
    }

    // Authorization check
    if (session.user.role !== 'ADMIN' && session.user.role !== 'INSTRUCTOR') {
      return new Response('Forbidden', { status: 403 })
    }

    // Input validation
    const body = await request.json()
    const validatedData = updateCourseSchema.parse(body)

    // Additional authorization: Can user edit this specific course?
    const course = await prisma.course.findUnique({
      where: { id: params.id },
      select: { instructorId: true },
    })

    if (!course) {
      return new Response('Course not found', { status: 404 })
    }

    if (
      session.user.role !== 'ADMIN' && 
      course.instructorId !== session.user.id
    ) {
      return new Response('Forbidden', { status: 403 })
    }

    // Update course
    const updatedCourse = await prisma.course.update({
      where: { id: params.id },
      data: validatedData,
    })

    return Response.json(updatedCourse)

  } catch (error) {
    if (error instanceof z.ZodError) {
      return Response.json(
        { error: 'Invalid input', details: error.errors },
        { status: 400 }
      )
    }

    console.error('Course update error:', error)
    return new Response('Internal Server Error', { status: 500 })
  }
}
```

### Input Validation & Sanitization

```typescript
// ✅ Comprehensive validation schemas
import { z } from 'zod'

export const courseSchema = z.object({
  title: z
    .string()
    .min(1, 'Title is required')
    .max(200, 'Title must be less than 200 characters')
    .refine((val) => val.trim().length > 0, 'Title cannot be empty'),
  
  description: z
    .string()
    .max(2000, 'Description must be less than 2000 characters')
    .optional(),
  
  slug: z
    .string()
    .min(1, 'Slug is required')
    .regex(/^[a-z0-9-]+$/, 'Slug must contain only lowercase letters, numbers, and hyphens')
    .max(100, 'Slug must be less than 100 characters'),
  
  price: z
    .number()
    .min(0, 'Price cannot be negative')
    .max(10000, 'Price cannot exceed ₱10,000')
    .optional(),
  
  tags: z
    .array(z.string().min(1).max(50))
    .max(10, 'Maximum 10 tags allowed')
    .optional(),
})

export const lessonSchema = z.object({
  title: z.string().min(1).max(200),
  content: z.string().min(1, 'Content is required'),
  videoUrl: z.string().url().optional().or(z.literal('')),
  order: z.number().int().min(0),
  duration: z.number().int().min(0).optional(), // in seconds
})

// Form validation hook
export function useFormValidation<T>(schema: z.ZodSchema<T>) {
  const validateField = (data: unknown): { success: boolean; errors?: string[] } => {
    try {
      schema.parse(data)
      return { success: true }
    } catch (error) {
      if (error instanceof z.ZodError) {
        return {
          success: false,
          errors: error.errors.map(err => err.message),
        }
      }
      return { success: false, errors: ['Validation failed'] }
    }
  }

  return { validateField }
}
```

### CSRF Protection & Rate Limiting

```typescript
// middleware.ts
import { NextResponse } from 'next/server'
import type { NextRequest } from 'next/server'
import { rateLimiter } from '@/lib/rate-limiter'

export async function middleware(request: NextRequest) {
  // Rate limiting for API routes
  if (request.nextUrl.pathname.startsWith('/api/')) {
    const ip = request.ip || request.headers.get('x-forwarded-for') || 'anonymous'
    const rateLimitResult = await rateLimiter.check(ip, request.nextUrl.pathname)
    
    if (!rateLimitResult.success) {
      return new NextResponse('Too Many Requests', { 
        status: 429,
        headers: {
          'Retry-After': rateLimitResult.retryAfter?.toString() || '60',
        },
      })
    }
  }

  // CSRF protection for state-changing operations
  if (['POST', 'PUT', 'DELETE', 'PATCH'].includes(request.method)) {
    const origin = request.headers.get('origin')
    const host = request.headers.get('host')
    
    if (origin && `${new URL(origin).host}` !== host) {
      return new NextResponse('Forbidden', { status: 403 })
    }
  }

  return NextResponse.next()
}

export const config = {
  matcher: ['/api/:path*', '/dashboard/:path*'],
}
```

## 🎨 UI/UX Best Practices

### Responsive Design Patterns

```typescript
// ✅ Mobile-first responsive components
export function CourseGrid({ courses }: { courses: Course[] }) {
  return (
    <div className="
      grid 
      grid-cols-1 
      sm:grid-cols-2 
      lg:grid-cols-3 
      xl:grid-cols-4 
      gap-4 
      sm:gap-6 
      lg:gap-8
    ">
      {courses.map((course) => (
        <CourseCard key={course.id} course={course} />
      ))}
    </div>
  )
}

// ✅ Responsive typography
const responsiveTextStyles = {
  heading1: "text-2xl sm:text-3xl lg:text-4xl xl:text-5xl font-bold",
  heading2: "text-xl sm:text-2xl lg:text-3xl font-semibold",
  body: "text-sm sm:text-base lg:text-lg",
  caption: "text-xs sm:text-sm",
}
```

### Loading States & Skeleton UI

```typescript
// ✅ Skeleton components for better UX
export function CourseCardSkeleton() {
  return (
    <div className="bg-white rounded-lg shadow-sm overflow-hidden animate-pulse">
      <div className="h-48 bg-gray-200" />
      <div className="p-4 space-y-3">
        <div className="h-6 bg-gray-200 rounded w-3/4" />
        <div className="space-y-2">
          <div className="h-4 bg-gray-200 rounded" />
          <div className="h-4 bg-gray-200 rounded w-5/6" />
        </div>
        <div className="flex justify-between items-center">
          <div className="h-5 bg-gray-200 rounded w-16" />
          <div className="h-8 bg-gray-200 rounded w-20" />
        </div>
      </div>
    </div>
  )
}

// ✅ Loading boundary pattern
import { Suspense } from 'react'

export function CoursesSection() {
  return (
    <section>
      <h2>Featured Courses</h2>
      <Suspense fallback={<CoursesGridSkeleton />}>
        <CoursesGrid />
      </Suspense>
    </section>
  )
}
```

### Error Boundaries & Error Handling

```typescript
// ✅ Global error boundary
'use client'

import { Component, ReactNode } from 'react'

interface Props {
  children: ReactNode
  fallback?: ReactNode
}

interface State {
  hasError: boolean
  error?: Error
}

export class ErrorBoundary extends Component<Props, State> {
  constructor(props: Props) {
    super(props)
    this.state = { hasError: false }
  }

  static getDerivedStateFromError(error: Error): State {
    return { hasError: true, error }
  }

  componentDidCatch(error: Error, errorInfo: any) {
    console.error('Error boundary caught an error:', error, errorInfo)
    // Send to error reporting service
  }

  render() {
    if (this.state.hasError) {
      return this.props.fallback || (
        <div className="min-h-screen flex items-center justify-center">
          <div className="text-center">
            <h2 className="text-2xl font-bold text-gray-900 mb-4">
              Oops! Something went wrong
            </h2>
            <p className="text-gray-600 mb-6">
              We're sorry for the inconvenience. Please try refreshing the page.
            </p>
            <button
              onClick={() => window.location.reload()}
              className="bg-blue-600 text-white px-6 py-2 rounded-lg hover:bg-blue-700"
            >
              Refresh Page
            </button>
          </div>
        </div>
      )
    }

    return this.props.children
  }
}
```

## 📊 State Management Best Practices

### Zustand Store Organization

```typescript
// ✅ Feature-based store structure
import { create } from 'zustand'
import { persist } from 'zustand/middleware'

interface AuthState {
  user: User | null
  isLoading: boolean
  login: (email: string, password: string) => Promise<void>
  logout: () => void
  updateProfile: (data: Partial<User>) => Promise<void>
}

export const useAuthStore = create<AuthState>()(
  persist(
    (set, get) => ({
      user: null,
      isLoading: false,
      
      login: async (email: string, password: string) => {
        set({ isLoading: true })
        try {
          const response = await signIn('credentials', { email, password })
          if (response?.user) {
            set({ user: response.user, isLoading: false })
          }
        } catch (error) {
          set({ isLoading: false })
          throw error
        }
      },
      
      logout: () => {
        signOut()
        set({ user: null })
      },
      
      updateProfile: async (data: Partial<User>) => {
        const currentUser = get().user
        if (!currentUser) return
        
        try {
          const updatedUser = await updateUserProfile(currentUser.id, data)
          set({ user: updatedUser })
        } catch (error) {
          throw error
        }
      },
    }),
    {
      name: 'auth-storage',
      partialize: (state) => ({ user: state.user }), // Only persist user data
    }
  )
)
```

### React Query Integration

```typescript
// ✅ API query hooks with proper caching
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'

export function useCourses(filters?: CourseFilters) {
  return useQuery({
    queryKey: ['courses', filters],
    queryFn: () => fetchCourses(filters),
    staleTime: 5 * 60 * 1000, // 5 minutes
    cacheTime: 10 * 60 * 1000, // 10 minutes
    refetchOnWindowFocus: false,
  })
}

export function useCourseDetail(slug: string) {
  return useQuery({
    queryKey: ['course', slug],
    queryFn: () => fetchCourseBySlug(slug),
    enabled: !!slug,
    staleTime: 10 * 60 * 1000, // 10 minutes
  })
}

export function useEnrollCourse() {
  const queryClient = useQueryClient()
  
  return useMutation({
    mutationFn: enrollInCourse,
    onSuccess: (data, variables) => {
      // Update courses list
      queryClient.invalidateQueries({ queryKey: ['courses'] })
      // Update user enrollments
      queryClient.invalidateQueries({ queryKey: ['user-enrollments'] })
      // Update specific course
      queryClient.setQueryData(['course', variables.courseSlug], (old: any) => ({
        ...old,
        isEnrolled: true,
        studentsCount: old.studentsCount + 1,
      }))
    },
  })
}
```

## 🧪 Testing Best Practices

### Unit Testing Components

```typescript
// ✅ Comprehensive component testing
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { CourseCard } from '@/components/features/course-card'

const mockCourse = {
  id: '1',
  title: 'Test Course',
  description: 'Test Description',
  slug: 'test-course',
  price: 99,
  studentsCount: 150,
}

const createTestQueryClient = () =>
  new QueryClient({
    defaultOptions: {
      queries: { retry: false },
      mutations: { retry: false },
    },
  })

function renderWithProviders(ui: React.ReactElement) {
  const testQueryClient = createTestQueryClient()
  
  return render(
    <QueryClientProvider client={testQueryClient}>
      {ui}
    </QueryClientProvider>
  )
}

describe('CourseCard', () => {
  it('displays course information correctly', () => {
    renderWithProviders(<CourseCard course={mockCourse} />)
    
    expect(screen.getByText('Test Course')).toBeInTheDocument()
    expect(screen.getByText('Test Description')).toBeInTheDocument()
    expect(screen.getByText('₱99')).toBeInTheDocument()
    expect(screen.getByText('150 students')).toBeInTheDocument()
  })

  it('handles enrollment click', async () => {
    const mockEnroll = jest.fn()
    renderWithProviders(
      <CourseCard course={mockCourse} onEnroll={mockEnroll} />
    )
    
    const enrollButton = screen.getByText('Enroll Now')
    fireEvent.click(enrollButton)
    
    await waitFor(() => {
      expect(mockEnroll).toHaveBeenCalledWith(mockCourse.id)
    })
  })
})
```

### API Route Testing

```typescript
// ✅ API route testing with mocked dependencies
import { POST } from '@/app/api/courses/route'
import { NextRequest } from 'next/server'
import { prismaMock } from '@/__mocks__/prisma'

jest.mock('@/lib/db', () => ({
  prisma: prismaMock,
}))

jest.mock('next-auth/next', () => ({
  getServerSession: jest.fn(),
}))

describe('/api/courses', () => {
  afterEach(() => {
    jest.clearAllMocks()
  })

  it('creates a new course successfully', async () => {
    const mockSession = {
      user: { id: '1', role: 'ADMIN' },
    }

    ;(require('next-auth/next').getServerSession as jest.Mock).mockResolvedValue(
      mockSession
    )

    prismaMock.course.create.mockResolvedValue({
      id: '1',
      title: 'New Course',
      slug: 'new-course',
      description: 'Course description',
      published: false,
      createdAt: new Date(),
      updatedAt: new Date(),
    })

    const request = new NextRequest('http://localhost:3000/api/courses', {
      method: 'POST',
      body: JSON.stringify({
        title: 'New Course',
        slug: 'new-course',
        description: 'Course description',
      }),
    })

    const response = await POST(request)
    const data = await response.json()

    expect(response.status).toBe(201)
    expect(data.title).toBe('New Course')
    expect(prismaMock.course.create).toHaveBeenCalledWith({
      data: {
        title: 'New Course',
        slug: 'new-course',
        description: 'Course description',
      },
    })
  })

  it('returns 401 for unauthorized users', async () => {
    ;(require('next-auth/next').getServerSession as jest.Mock).mockResolvedValue(
      null
    )

    const request = new NextRequest('http://localhost:3000/api/courses', {
      method: 'POST',
      body: JSON.stringify({
        title: 'New Course',
        slug: 'new-course',
      }),
    })

    const response = await POST(request)
    expect(response.status).toBe(401)
  })
})
```

## 🚀 Deployment & Production Best Practices

### Environment Configuration

```typescript
// ✅ Environment variable validation
import { z } from 'zod'

const envSchema = z.object({
  DATABASE_URL: z.string().url(),
  NEXTAUTH_SECRET: z.string().min(32),
  NEXTAUTH_URL: z.string().url(),
  GOOGLE_CLIENT_ID: z.string().optional(),
  GOOGLE_CLIENT_SECRET: z.string().optional(),
  STRIPE_SECRET_KEY: z.string().startsWith('sk_'),
  STRIPE_PUBLISHABLE_KEY: z.string().startsWith('pk_'),
  EMAIL_SERVER_HOST: z.string(),
  EMAIL_SERVER_PORT: z.string().transform(Number),
  EMAIL_FROM: z.string().email(),
  REDIS_URL: z.string().url().optional(),
  SENTRY_DSN: z.string().url().optional(),
})

export const env = envSchema.parse(process.env)
```

### Performance Monitoring

```typescript
// ✅ Performance monitoring setup
// next.config.js
const { withSentryConfig } = require('@sentry/nextjs')

/** @type {import('next').NextConfig} */
const nextConfig = {
  experimental: {
    instrumentationHook: true,
  },
  // Performance optimizations
  compiler: {
    removeConsole: process.env.NODE_ENV === 'production',
  },
  swcMinify: true,
  poweredByHeader: false,
  reactStrictMode: true,
}

module.exports = withSentryConfig(nextConfig, {
  silent: true,
  org: 'your-org',
  project: 'education-platform',
})
```

## 📈 Analytics & Monitoring

### User Analytics Implementation

```typescript
// ✅ Privacy-conscious analytics
'use client'

import { useEffect } from 'react'
import { usePathname, useSearchParams } from 'next/navigation'

export function Analytics() {
  const pathname = usePathname()
  const searchParams = useSearchParams()

  useEffect(() => {
    if (typeof window !== 'undefined') {
      // Only track page views, not personal data
      window.gtag('config', 'GA_ID', {
        page_path: pathname,
        // Anonymize IP addresses
        anonymize_ip: true,
        // Respect user privacy preferences
        allow_google_signals: false,
        allow_ad_personalization_signals: false,
      })
    }
  }, [pathname, searchParams])

  return null
}

// Learning analytics for educational insights
export function trackLearningEvent(event: {
  action: 'lesson_started' | 'lesson_completed' | 'quiz_submitted'
  courseId: string
  lessonId?: string
  score?: number
  timeSpent?: number
}) {
  // Send to your analytics service (e.g., Mixpanel, PostHog)
  fetch('/api/analytics/learning', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      ...event,
      timestamp: new Date().toISOString(),
      sessionId: getSessionId(),
    }),
  })
}
```

## 📖 Documentation Best Practices

### API Documentation

```typescript
// ✅ Self-documenting API routes with OpenAPI
/**
 * @swagger
 * /api/courses:
 *   get:
 *     summary: Retrieve a list of courses
 *     parameters:
 *       - in: query
 *         name: page
 *         schema:
 *           type: integer
 *           minimum: 1
 *         description: Page number
 *       - in: query
 *         name: search
 *         schema:
 *           type: string
 *         description: Search term
 *     responses:
 *       200:
 *         description: List of courses
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 courses:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/Course'
 *                 pagination:
 *                   $ref: '#/components/schemas/Pagination'
 */
export async function GET(request: NextRequest) {
  // Implementation
}
```

### Component Documentation

```typescript
// ✅ Well-documented components with Storybook
import type { Meta, StoryObj } from '@storybook/react'
import { CourseCard } from './course-card'

const meta: Meta<typeof CourseCard> = {
  title: 'Features/CourseCard',
  component: CourseCard,
  parameters: {
    layout: 'centered',
    docs: {
      description: {
        component: 'A card component for displaying course information in the course catalog.',
      },
    },
  },
  argTypes: {
    course: {
      description: 'Course data object',
      control: 'object',
    },
    onEnroll: {
      description: 'Callback function called when user clicks enroll button',
      action: 'enrolled',
    },
  },
}

export default meta
type Story = StoryObj<typeof meta>

export const Default: Story = {
  args: {
    course: {
      id: '1',
      title: 'Introduction to Web Development',
      description: 'Learn the basics of HTML, CSS, and JavaScript',
      slug: 'intro-web-dev',
      price: 999,
      studentsCount: 1250,
      rating: 4.8,
      thumbnail: '/course-thumbnails/web-dev.jpg',
    },
  },
}

export const Free: Story = {
  args: {
    course: {
      ...Default.args.course,
      price: 0,
    },
  },
}

export const Popular: Story = {
  args: {
    course: {
      ...Default.args.course,
      studentsCount: 5000,
      rating: 4.9,
    },
  },
}
```

## 🔄 Continuous Integration

### GitHub Actions Workflow

```yaml
# .github/workflows/ci.yml
name: CI/CD Pipeline

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    
    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_PASSWORD: postgres
          POSTGRES_DB: test_db
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 5432:5432

    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '18'
          cache: 'npm'
      
      - name: Install dependencies
        run: npm ci
      
      - name: Run type checking
        run: npm run type-check
      
      - name: Run linting
        run: npm run lint
      
      - name: Run unit tests
        run: npm run test -- --coverage
        env:
          DATABASE_URL: postgresql://postgres:postgres@localhost:5432/test_db
      
      - name: Run E2E tests
        run: npm run test:e2e
        env:
          DATABASE_URL: postgresql://postgres:postgres@localhost:5432/test_db
      
      - name: Upload coverage to Codecov
        uses: codecov/codecov-action@v3

  build:
    needs: test
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '18'
          cache: 'npm'
      
      - name: Install dependencies
        run: npm ci
      
      - name: Build application
        run: npm run build
        env:
          SKIP_ENV_VALIDATION: true
      
      - name: Export static files (if applicable)
        run: npm run export
        if: github.ref == 'refs/heads/main'
```

## 🔗 Related Resources

### Previous: [Implementation Guide](./implementation-guide.md)
### Next: [Performance Analysis](./performance-analysis.md)

---

*Best Practices Guide | Next.js Full Stack Development | 2024*