# Testing Strategies: Next.js Educational Platform

## 🎯 Overview

Comprehensive testing is crucial for educational platforms to ensure reliability, security, and user experience. This guide covers testing strategies for Next.js applications, from unit tests to end-to-end testing, with specific focus on educational platform features like user progress tracking, payment processing, and content delivery.

## 🧪 Testing Strategy Overview

### Testing Pyramid for Educational Platforms

```
        /\
       /  \
      / E2E \     ← 10% (Critical user journeys)
     /______\
    /        \
   / INTEGRATION \ ← 20% (API routes, database interactions)
  /______________\
 /                \
/   UNIT TESTS     \ ← 70% (Components, utilities, business logic)
\__________________/
```

### Test Categories

1. **Unit Tests** - Individual components and functions
2. **Integration Tests** - API routes and database interactions
3. **End-to-End Tests** - Complete user workflows
4. **Performance Tests** - Load testing and optimization
5. **Security Tests** - Authentication and authorization
6. **Accessibility Tests** - WCAG compliance testing

## 🔧 Testing Environment Setup

### Core Testing Dependencies

```json
{
  "devDependencies": {
    "@testing-library/react": "^14.0.0",
    "@testing-library/jest-dom": "^6.1.0",
    "@testing-library/user-event": "^14.5.0",
    "jest": "^29.7.0",
    "jest-environment-jsdom": "^29.7.0",
    "@types/jest": "^29.5.0",
    "playwright": "^1.40.0",
    "@playwright/test": "^1.40.0",
    "msw": "^2.0.0",
    "supertest": "^6.3.0",
    "prisma-mock": "^0.9.0",
    "nock": "^13.4.0"
  }
}
```

### Jest Configuration

```javascript
// jest.config.js
const nextJest = require('next/jest')

const createJestConfig = nextJest({
  // Provide the path to your Next.js app to load next.config.js and .env files
  dir: './',
})

const customJestConfig = {
  setupFilesAfterEnv: ['<rootDir>/jest.setup.js'],
  testEnvironment: 'jest-environment-jsdom',
  testPathIgnorePatterns: ['<rootDir>/.next/', '<rootDir>/node_modules/'],
  collectCoverageFrom: [
    'src/**/*.{js,jsx,ts,tsx}',
    '!src/**/*.d.ts',
    '!src/**/*.stories.{js,jsx,ts,tsx}',
    '!src/pages/_app.tsx',
    '!src/pages/_document.tsx',
  ],
  coverageThreshold: {
    global: {
      branches: 80,
      functions: 80,
      lines: 80,
      statements: 80,
    },
  },
  moduleNameMapping: {
    '^@/(.*)$': '<rootDir>/src/$1',
  },
  testTimeout: 10000,
}

module.exports = createJestConfig(customJestConfig)
```

```javascript
// jest.setup.js
import '@testing-library/jest-dom'
import 'whatwg-fetch'
import { server } from './src/__mocks__/server'

// Mock Next.js router
jest.mock('next/router', () => ({
  useRouter() {
    return {
      route: '/',
      pathname: '/',
      query: {},
      asPath: '/',
      push: jest.fn(),
      pop: jest.fn(),
      reload: jest.fn(),
      back: jest.fn(),
      prefetch: jest.fn(),
      beforePopState: jest.fn(),
      events: {
        on: jest.fn(),
        off: jest.fn(),
        emit: jest.fn(),
      },
    }
  },
}))

// Mock NextAuth
jest.mock('next-auth/react', () => ({
  useSession: jest.fn(),
  signIn: jest.fn(),
  signOut: jest.fn(),
  SessionProvider: ({ children }) => children,
}))

// Setup MSW
beforeAll(() => server.listen())
afterEach(() => server.resetHandlers())
afterAll(() => server.close())

// Mock IntersectionObserver
global.IntersectionObserver = jest.fn().mockImplementation(() => ({
  observe: jest.fn(),
  unobserve: jest.fn(),
  disconnect: jest.fn(),
}))

// Mock ResizeObserver
global.ResizeObserver = jest.fn().mockImplementation(() => ({
  observe: jest.fn(),
  unobserve: jest.fn(),
  disconnect: jest.fn(),
}))
```

## 🧩 Unit Testing

### Component Testing

```typescript
// __tests__/components/CourseCard.test.tsx
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { useSession } from 'next-auth/react'
import { CourseCard } from '@/components/features/course-card'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'

// Mock data
const mockCourse = {
  id: '1',
  title: 'Introduction to Web Development',
  description: 'Learn the basics of HTML, CSS, and JavaScript',
  slug: 'intro-web-dev',
  price: 999,
  studentsCount: 1250,
  thumbnail: '/course-thumbnails/web-dev.jpg',
  instructor: {
    name: 'John Doe',
    avatar: '/avatars/john-doe.jpg',
  },
}

const mockEnrollment = {
  id: '1',
  userId: 'user-1',
  courseId: '1',
  createdAt: new Date(),
}

// Test utilities
const createTestQueryClient = () =>
  new QueryClient({
    defaultOptions: {
      queries: {
        retry: false,
      },
      mutations: {
        retry: false,
      },
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
  beforeEach(() => {
    ;(useSession as jest.Mock).mockReturnValue({
      data: null,
      status: 'unauthenticated',
    })
  })

  afterEach(() => {
    jest.clearAllMocks()
  })

  it('renders course information correctly', () => {
    renderWithProviders(<CourseCard course={mockCourse} />)
    
    expect(screen.getByText('Introduction to Web Development')).toBeInTheDocument()
    expect(screen.getByText(/Learn the basics of HTML, CSS, and JavaScript/)).toBeInTheDocument()
    expect(screen.getByText('₱999')).toBeInTheDocument()
    expect(screen.getByText('1,250 students')).toBeInTheDocument()
    expect(screen.getByText('John Doe')).toBeInTheDocument()
  })

  it('displays course thumbnail with proper alt text', () => {
    renderWithProviders(<CourseCard course={mockCourse} />)
    
    const thumbnail = screen.getByAltText('Introduction to Web Development')
    expect(thumbnail).toBeInTheDocument()
    expect(thumbnail).toHaveAttribute('src', '/course-thumbnails/web-dev.jpg')
  })

  it('shows enroll button for unauthenticated users', () => {
    renderWithProviders(<CourseCard course={mockCourse} />)
    
    const enrollButton = screen.getByRole('button', { name: /enroll now/i })
    expect(enrollButton).toBeInTheDocument()
  })

  it('redirects to login when unauthenticated user clicks enroll', async () => {
    const user = userEvent.setup()
    const mockPush = jest.fn()
    
    jest.mock('next/router', () => ({
      useRouter: () => ({
        push: mockPush,
      }),
    }))
    
    renderWithProviders(<CourseCard course={mockCourse} />)
    
    const enrollButton = screen.getByRole('button', { name: /enroll now/i })
    await user.click(enrollButton)
    
    expect(mockPush).toHaveBeenCalledWith('/auth/signin')
  })

  it('shows enrolled status for enrolled users', () => {
    ;(useSession as jest.Mock).mockReturnValue({
      data: { user: { id: 'user-1' } },
      status: 'authenticated',
    })
    
    renderWithProviders(
      <CourseCard course={mockCourse} enrollment={mockEnrollment} />
    )
    
    expect(screen.getByText(/enrolled/i)).toBeInTheDocument()
    expect(screen.getByRole('link', { name: /continue learning/i })).toBeInTheDocument()
  })

  it('handles enrollment mutation correctly', async () => {
    const user = userEvent.setup()
    const mockEnrollMutation = jest.fn().mockResolvedValue({ success: true })
    
    ;(useSession as jest.Mock).mockReturnValue({
      data: { user: { id: 'user-1' } },
      status: 'authenticated',
    })
    
    // Mock the enrollment API
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      json: () => Promise.resolve({ success: true }),
    })
    
    renderWithProviders(<CourseCard course={mockCourse} />)
    
    const enrollButton = screen.getByRole('button', { name: /enroll now/i })
    await user.click(enrollButton)
    
    expect(enrollButton).toBeDisabled()
    expect(screen.getByText(/enrolling.../i)).toBeInTheDocument()
    
    await waitFor(() => {
      expect(fetch).toHaveBeenCalledWith('/api/enrollments', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ courseId: '1' }),
      })
    })
  })

  it('shows error message when enrollment fails', async () => {
    const user = userEvent.setup()
    
    ;(useSession as jest.Mock).mockReturnValue({
      data: { user: { id: 'user-1' } },
      status: 'authenticated',
    })
    
    global.fetch = jest.fn().mockRejectedValue(new Error('Enrollment failed'))
    
    renderWithProviders(<CourseCard course={mockCourse} />)
    
    const enrollButton = screen.getByRole('button', { name: /enroll now/i })
    await user.click(enrollButton)
    
    await waitFor(() => {
      expect(screen.getByText(/enrollment failed/i)).toBeInTheDocument()
    })
  })

  it('meets accessibility requirements', () => {
    renderWithProviders(<CourseCard course={mockCourse} />)
    
    // Check for proper heading structure
    const heading = screen.getByRole('heading', { level: 3 })
    expect(heading).toHaveTextContent('Introduction to Web Development')
    
    // Check for proper button labeling
    const enrollButton = screen.getByRole('button', { name: /enroll now/i })
    expect(enrollButton).toBeInTheDocument()
    
    // Check for proper image alt text
    const image = screen.getByAltText('Introduction to Web Development')
    expect(image).toBeInTheDocument()
  })
})
```

### Utility Function Testing

```typescript
// __tests__/lib/utils.test.ts
import {
  formatPrice,
  formatDuration,
  calculateProgress,
  sanitizeHtml,
  validateEmail,
  generateSlug,
} from '@/lib/utils'

describe('Utils', () => {
  describe('formatPrice', () => {
    it('formats price correctly for PHP currency', () => {
      expect(formatPrice(1000, 'PHP')).toBe('₱1,000')
      expect(formatPrice(99.99, 'PHP')).toBe('₱99.99')
      expect(formatPrice(0, 'PHP')).toBe('Free')
    })

    it('formats price correctly for USD currency', () => {
      expect(formatPrice(1000, 'USD')).toBe('$1,000')
      expect(formatPrice(99.99, 'USD')).toBe('$99.99')
    })

    it('handles null and undefined prices', () => {
      expect(formatPrice(null, 'PHP')).toBe('Free')
      expect(formatPrice(undefined, 'PHP')).toBe('Free')
    })
  })

  describe('formatDuration', () => {
    it('formats duration in minutes correctly', () => {
      expect(formatDuration(30)).toBe('30 minutes')
      expect(formatDuration(1)).toBe('1 minute')
    })

    it('formats duration in hours correctly', () => {
      expect(formatDuration(60)).toBe('1 hour')
      expect(formatDuration(90)).toBe('1 hour 30 minutes')
      expect(formatDuration(120)).toBe('2 hours')
    })

    it('handles edge cases', () => {
      expect(formatDuration(0)).toBe('0 minutes')
      expect(formatDuration(1440)).toBe('24 hours')
    })
  })

  describe('calculateProgress', () => {
    it('calculates progress percentage correctly', () => {
      expect(calculateProgress(5, 10)).toBe(50)
      expect(calculateProgress(3, 4)).toBe(75)
      expect(calculateProgress(0, 5)).toBe(0)
      expect(calculateProgress(5, 5)).toBe(100)
    })

    it('handles edge cases', () => {
      expect(calculateProgress(0, 0)).toBe(0)
      expect(calculateProgress(5, 0)).toBe(0)
      expect(calculateProgress(-1, 5)).toBe(0)
    })
  })

  describe('sanitizeHtml', () => {
    it('removes dangerous script tags', () => {
      const maliciousHtml = '<p>Hello</p><script>alert("XSS")</script>'
      const sanitized = sanitizeHtml(maliciousHtml)
      expect(sanitized).toBe('<p>Hello</p>')
      expect(sanitized).not.toContain('<script>')
    })

    it('preserves safe HTML tags', () => {
      const safeHtml = '<p>Hello <strong>world</strong>!</p><ul><li>Item 1</li></ul>'
      const sanitized = sanitizeHtml(safeHtml)
      expect(sanitized).toContain('<p>')
      expect(sanitized).toContain('<strong>')
      expect(sanitized).toContain('<ul>')
      expect(sanitized).toContain('<li>')
    })

    it('removes unsafe attributes', () => {
      const htmlWithUnsafeAttrs = '<p onclick="alert()">Hello</p><a href="javascript:void(0)">Link</a>'
      const sanitized = sanitizeHtml(htmlWithUnsafeAttrs)
      expect(sanitized).not.toContain('onclick')
      expect(sanitized).not.toContain('javascript:')
    })
  })

  describe('validateEmail', () => {
    it('validates correct email addresses', () => {
      expect(validateEmail('user@example.com')).toBe(true)
      expect(validateEmail('test.email+tag@domain.co.uk')).toBe(true)
    })

    it('rejects invalid email addresses', () => {
      expect(validateEmail('invalid-email')).toBe(false)
      expect(validateEmail('user@')).toBe(false)
      expect(validateEmail('@domain.com')).toBe(false)
      expect(validateEmail('')).toBe(false)
    })
  })

  describe('generateSlug', () => {
    it('generates proper slugs from titles', () => {
      expect(generateSlug('Introduction to Web Development')).toBe('introduction-to-web-development')
      expect(generateSlug('Advanced JavaScript & React')).toBe('advanced-javascript-react')
      expect(generateSlug('C++ Programming 101')).toBe('c-programming-101')
    })

    it('handles special characters and spacing', () => {
      expect(generateSlug('  Multiple   Spaces  ')).toBe('multiple-spaces')
      expect(generateSlug('Special!@#$%Characters')).toBe('special-characters')
      expect(generateSlug('UPPERCASE TEXT')).toBe('uppercase-text')
    })

    it('handles empty and null inputs', () => {
      expect(generateSlug('')).toBe('')
      expect(generateSlug(null)).toBe('')
      expect(generateSlug(undefined)).toBe('')
    })
  })
})
```

## 🔗 Integration Testing

### API Route Testing

```typescript
// __tests__/api/courses.test.ts
import { createMocks } from 'node-mocks-http'
import handler from '@/pages/api/courses'
import { getServerSession } from 'next-auth'
import { prisma } from '@/lib/db'

// Mock dependencies
jest.mock('next-auth')
jest.mock('@/lib/db', () => ({
  prisma: {
    course: {
      findMany: jest.fn(),
      create: jest.fn(),
      findUnique: jest.fn(),
      update: jest.fn(),
      delete: jest.fn(),
    },
  },
}))

const mockGetServerSession = getServerSession as jest.MockedFunction<typeof getServerSession>
const mockPrisma = prisma as jest.Mocked<typeof prisma>

describe('/api/courses', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('GET /api/courses', () => {
    it('returns courses list successfully', async () => {
      const mockCourses = [
        {
          id: '1',
          title: 'Course 1',
          slug: 'course-1',
          published: true,
          _count: { enrollments: 10 },
        },
        {
          id: '2',
          title: 'Course 2',
          slug: 'course-2',
          published: true,
          _count: { enrollments: 5 },
        },
      ]

      mockPrisma.course.findMany.mockResolvedValue(mockCourses)

      const { req, res } = createMocks({
        method: 'GET',
        query: { page: '1', limit: '10' },
      })

      await handler(req, res)

      expect(res._getStatusCode()).toBe(200)
      
      const data = JSON.parse(res._getData())
      expect(data.courses).toHaveLength(2)
      expect(data.courses[0].title).toBe('Course 1')
      expect(mockPrisma.course.findMany).toHaveBeenCalledWith({
        where: { published: true },
        include: {
          _count: { select: { enrollments: true } },
        },
        skip: 0,
        take: 10,
        orderBy: { createdAt: 'desc' },
      })
    })

    it('handles search query correctly', async () => {
      mockPrisma.course.findMany.mockResolvedValue([])

      const { req, res } = createMocks({
        method: 'GET',
        query: { search: 'javascript' },
      })

      await handler(req, res)

      expect(mockPrisma.course.findMany).toHaveBeenCalledWith({
        where: {
          published: true,
          OR: [
            { title: { contains: 'javascript', mode: 'insensitive' } },
            { description: { contains: 'javascript', mode: 'insensitive' } },
          ],
        },
        include: {
          _count: { select: { enrollments: true } },
        },
        skip: 0,
        take: 10,
        orderBy: { createdAt: 'desc' },
      })
    })

    it('handles pagination correctly', async () => {
      mockPrisma.course.findMany.mockResolvedValue([])

      const { req, res } = createMocks({
        method: 'GET',
        query: { page: '3', limit: '20' },
      })

      await handler(req, res)

      expect(mockPrisma.course.findMany).toHaveBeenCalledWith({
        where: { published: true },
        include: {
          _count: { select: { enrollments: true } },
        },
        skip: 40, // (3 - 1) * 20
        take: 20,
        orderBy: { createdAt: 'desc' },
      })
    })
  })

  describe('POST /api/courses', () => {
    it('creates course successfully for admin user', async () => {
      mockGetServerSession.mockResolvedValue({
        user: { id: 'admin-1', role: 'ADMIN' },
      })

      const newCourse = {
        id: '1',
        title: 'New Course',
        slug: 'new-course',
        description: 'Course description',
        published: false,
      }

      mockPrisma.course.create.mockResolvedValue(newCourse)

      const { req, res } = createMocks({
        method: 'POST',
        body: {
          title: 'New Course',
          slug: 'new-course',
          description: 'Course description',
        },
      })

      await handler(req, res)

      expect(res._getStatusCode()).toBe(201)
      
      const data = JSON.parse(res._getData())
      expect(data.title).toBe('New Course')
      expect(mockPrisma.course.create).toHaveBeenCalledWith({
        data: {
          title: 'New Course',
          slug: 'new-course',
          description: 'Course description',
        },
      })
    })

    it('returns 401 for unauthenticated users', async () => {
      mockGetServerSession.mockResolvedValue(null)

      const { req, res } = createMocks({
        method: 'POST',
        body: {
          title: 'New Course',
          slug: 'new-course',
        },
      })

      await handler(req, res)

      expect(res._getStatusCode()).toBe(401)
      expect(mockPrisma.course.create).not.toHaveBeenCalled()
    })

    it('returns 403 for non-admin users', async () => {
      mockGetServerSession.mockResolvedValue({
        user: { id: 'user-1', role: 'STUDENT' },
      })

      const { req, res } = createMocks({
        method: 'POST',
        body: {
          title: 'New Course',
          slug: 'new-course',
        },
      })

      await handler(req, res)

      expect(res._getStatusCode()).toBe(403)
      expect(mockPrisma.course.create).not.toHaveBeenCalled()
    })

    it('validates required fields', async () => {
      mockGetServerSession.mockResolvedValue({
        user: { id: 'admin-1', role: 'ADMIN' },
      })

      const { req, res } = createMocks({
        method: 'POST',
        body: {
          title: '', // Invalid: empty title
        },
      })

      await handler(req, res)

      expect(res._getStatusCode()).toBe(400)
      expect(mockPrisma.course.create).not.toHaveBeenCalled()
    })
  })

  describe('Error handling', () => {
    it('handles database errors gracefully', async () => {
      mockPrisma.course.findMany.mockRejectedValue(new Error('Database error'))

      const { req, res } = createMocks({
        method: 'GET',
      })

      await handler(req, res)

      expect(res._getStatusCode()).toBe(500)
      
      const data = JSON.parse(res._getData())
      expect(data.error).toBe('Failed to fetch courses')
    })

    it('returns 405 for unsupported methods', async () => {
      const { req, res } = createMocks({
        method: 'DELETE',
      })

      await handler(req, res)

      expect(res._getStatusCode()).toBe(405)
    })
  })
})
```

### Database Integration Testing

```typescript
// __tests__/integration/enrollment.test.ts
import { prisma } from '@/lib/db'
import { enrollUserInCourse, getUserEnrollments } from '@/lib/enrollments'

// This test requires a test database
describe('Enrollment Integration', () => {
  let testUser: any
  let testCourse: any

  beforeAll(async () => {
    // Create test data
    testUser = await prisma.user.create({
      data: {
        email: 'test@example.com',
        name: 'Test User',
        password: 'hashed_password',
      },
    })

    testCourse = await prisma.course.create({
      data: {
        title: 'Test Course',
        slug: 'test-course',
        description: 'Test course description',
        published: true,
      },
    })
  })

  afterAll(async () => {
    // Clean up test data
    await prisma.enrollment.deleteMany({
      where: { userId: testUser.id },
    })
    await prisma.user.delete({
      where: { id: testUser.id },
    })
    await prisma.course.delete({
      where: { id: testCourse.id },
    })
  })

  it('enrolls user in course successfully', async () => {
    const enrollment = await enrollUserInCourse(testUser.id, testCourse.id)

    expect(enrollment).toBeDefined()
    expect(enrollment.userId).toBe(testUser.id)
    expect(enrollment.courseId).toBe(testCourse.id)
    expect(enrollment.createdAt).toBeInstanceOf(Date)
  })

  it('prevents duplicate enrollments', async () => {
    // Try to enroll again
    await expect(
      enrollUserInCourse(testUser.id, testCourse.id)
    ).rejects.toThrow('User is already enrolled in this course')
  })

  it('retrieves user enrollments correctly', async () => {
    const enrollments = await getUserEnrollments(testUser.id)

    expect(enrollments).toHaveLength(1)
    expect(enrollments[0].course.title).toBe('Test Course')
    expect(enrollments[0].userId).toBe(testUser.id)
  })

  it('handles non-existent user', async () => {
    await expect(
      enrollUserInCourse('non-existent-id', testCourse.id)
    ).rejects.toThrow('User not found')
  })

  it('handles non-existent course', async () => {
    await expect(
      enrollUserInCourse(testUser.id, 'non-existent-id')
    ).rejects.toThrow('Course not found')
  })
})
```

## 🎭 End-to-End Testing with Playwright

### Playwright Configuration

```typescript
// playwright.config.ts
import { defineConfig, devices } from '@playwright/test'

export default defineConfig({
  testDir: './e2e',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: 'html',
  
  use: {
    baseURL: 'http://localhost:3000',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
  },

  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
    {
      name: 'firefox',
      use: { ...devices['Desktop Firefox'] },
    },
    {
      name: 'webkit',
      use: { ...devices['Desktop Safari'] },
    },
    {
      name: 'Mobile Chrome',
      use: { ...devices['Pixel 5'] },
    },
    {
      name: 'Mobile Safari',
      use: { ...devices['iPhone 12'] },
    },
  ],

  webServer: {
    command: 'npm run dev',
    url: 'http://localhost:3000',
    reuseExistingServer: !process.env.CI,
  },
})
```

### Critical User Journey Tests

```typescript
// e2e/student-enrollment.spec.ts
import { test, expect } from '@playwright/test'

test.describe('Student Enrollment Journey', () => {
  test.beforeEach(async ({ page }) => {
    // Set up test data
    await page.goto('/')
  })

  test('complete enrollment flow', async ({ page }) => {
    // Navigate to course catalog
    await page.click('text=Browse Courses')
    await expect(page).toHaveURL('/courses')

    // Search for a course
    await page.fill('[data-testid=search-input]', 'JavaScript')
    await page.press('[data-testid=search-input]', 'Enter')

    // Select a course
    await page.click('[data-testid=course-card]')
    await expect(page).toHaveURL(/\/courses\/.*/)

    // Check course details are displayed
    await expect(page.locator('h1')).toBeVisible()
    await expect(page.locator('[data-testid=course-description]')).toBeVisible()
    await expect(page.locator('[data-testid=lessons-list]')).toBeVisible()

    // Click enroll button (should redirect to login)
    await page.click('[data-testid=enroll-button]')
    await expect(page).toHaveURL('/auth/signin')

    // Login
    await page.fill('[data-testid=email-input]', 'student@example.com')
    await page.fill('[data-testid=password-input]', 'password123')
    await page.click('[data-testid=signin-button]')

    // Should redirect back to course page
    await expect(page).toHaveURL(/\/courses\/.*/)

    // Now enroll in course
    await page.click('[data-testid=enroll-button]')
    
    // Wait for enrollment to complete
    await expect(page.locator('[data-testid=enrollment-success]')).toBeVisible()
    await expect(page.locator('text=Continue Learning')).toBeVisible()

    // Navigate to first lesson
    await page.click('text=Continue Learning')
    await expect(page).toHaveURL(/\/courses\/.*\/learn/)

    // Verify lesson content is displayed
    await expect(page.locator('[data-testid=lesson-content]')).toBeVisible()
    await expect(page.locator('[data-testid=progress-bar]')).toBeVisible()
  })

  test('handles payment flow for paid courses', async ({ page }) => {
    // Navigate to paid course
    await page.goto('/courses/premium-javascript-course')

    // Login first
    await page.goto('/auth/signin')
    await page.fill('[data-testid=email-input]', 'student@example.com')
    await page.fill('[data-testid=password-input]', 'password123')
    await page.click('[data-testid=signin-button]')

    // Go back to course
    await page.goto('/courses/premium-javascript-course')

    // Click enroll button for paid course
    await page.click('[data-testid=enroll-button]')

    // Should show payment modal
    await expect(page.locator('[data-testid=payment-modal]')).toBeVisible()
    await expect(page.locator('text=₱999')).toBeVisible()

    // Fill in test card details
    await page.fill('[data-testid=card-number]', '4242424242424242')
    await page.fill('[data-testid=card-expiry]', '12/25')
    await page.fill('[data-testid=card-cvc]', '123')

    // Submit payment
    await page.click('[data-testid=pay-button]')

    // Wait for payment processing
    await expect(page.locator('[data-testid=payment-processing]')).toBeVisible()
    
    // Wait for success
    await expect(page.locator('[data-testid=payment-success]')).toBeVisible({
      timeout: 10000,
    })

    // Should now be enrolled
    await expect(page.locator('text=Continue Learning')).toBeVisible()
  })

  test('tracks learning progress', async ({ page }) => {
    // Login and navigate to enrolled course
    await page.goto('/auth/signin')
    await page.fill('[data-testid=email-input]', 'student@example.com')
    await page.fill('[data-testid=password-input]', 'password123')
    await page.click('[data-testid=signin-button]')

    await page.goto('/courses/javascript-fundamentals/learn')

    // Check initial progress is 0%
    await expect(page.locator('[data-testid=progress-text]')).toContainText('0%')

    // Complete first lesson
    await page.scrollToElement('[data-testid=lesson-content]', { behavior: 'smooth' })
    await page.click('[data-testid=mark-complete-button]')

    // Progress should update
    await expect(page.locator('[data-testid=progress-text]')).toContainText('20%')

    // Navigate to next lesson
    await page.click('[data-testid=next-lesson-button]')
    await expect(page).toHaveURL(/\/courses\/.*\/learn\/lesson-2/)

    // Complete second lesson
    await page.click('[data-testid=mark-complete-button]')
    await expect(page.locator('[data-testid=progress-text]')).toContainText('40%')

    // Check progress on dashboard
    await page.goto('/dashboard')
    await expect(page.locator('[data-testid=course-progress]')).toContainText('40%')
  })

  test('quiz functionality', async ({ page }) => {
    // Navigate to course with quiz
    await page.goto('/auth/signin')
    await page.fill('[data-testid=email-input]', 'student@example.com')
    await page.fill('[data-testid=password-input]', 'password123')
    await page.click('[data-testid=signin-button]')

    await page.goto('/courses/javascript-fundamentals/learn/quiz-1')

    // Check quiz is displayed
    await expect(page.locator('[data-testid=quiz-question]')).toBeVisible()
    await expect(page.locator('[data-testid=quiz-options]')).toBeVisible()

    // Answer first question
    await page.click('[data-testid=option-a]')
    await page.click('[data-testid=next-question-button]')

    // Answer second question
    await page.click('[data-testid=option-c]')
    await page.click('[data-testid=next-question-button]')

    // Submit quiz
    await page.click('[data-testid=submit-quiz-button]')

    // Check results
    await expect(page.locator('[data-testid=quiz-results]')).toBeVisible()
    await expect(page.locator('[data-testid=quiz-score]')).toBeVisible()

    // Should show correct/incorrect answers
    await expect(page.locator('[data-testid=answer-feedback]')).toBeVisible()
  })
})
```

### Performance Testing

```typescript
// e2e/performance.spec.ts
import { test, expect } from '@playwright/test'

test.describe('Performance Tests', () => {
  test('course catalog page loads within performance budget', async ({ page }) => {
    const startTime = Date.now()
    
    await page.goto('/courses')
    
    // Wait for the page to be fully loaded
    await page.waitForLoadState('networkidle')
    
    const loadTime = Date.now() - startTime
    
    // Assert load time is under 2 seconds
    expect(loadTime).toBeLessThan(2000)
    
    // Check Core Web Vitals
    const metrics = await page.evaluate(() => {
      return new Promise((resolve) => {
        new PerformanceObserver((list) => {
          const entries = list.getEntries()
          const lcp = entries.find((entry) => entry.entryType === 'largest-contentful-paint')
          if (lcp) {
            resolve({
              lcp: lcp.startTime,
              cls: 0, // Simplified for demo
              fid: 0, // Simplified for demo
            })
          }
        }).observe({ entryTypes: ['largest-contentful-paint'] })
      })
    })
    
    // Assert LCP is under 2.5 seconds
    expect(metrics.lcp).toBeLessThan(2500)
  })

  test('video player performance', async ({ page }) => {
    await page.goto('/courses/javascript-fundamentals/learn/lesson-1')
    
    // Start video
    await page.click('[data-testid=play-button]')
    
    // Wait for video to start playing
    await page.waitForFunction(() => {
      const video = document.querySelector('video')
      return video && !video.paused
    })
    
    // Check video metrics
    const videoMetrics = await page.evaluate(() => {
      const video = document.querySelector('video')
      return {
        buffered: video.buffered.length > 0 ? video.buffered.end(0) : 0,
        currentTime: video.currentTime,
        duration: video.duration,
      }
    })
    
    // Video should start playing within 3 seconds
    expect(videoMetrics.buffered).toBeGreaterThan(0)
    expect(videoMetrics.currentTime).toBeGreaterThan(0)
  })
})
```

## 🔒 Security Testing

```typescript
// e2e/security.spec.ts
import { test, expect } from '@playwright/test'

test.describe('Security Tests', () => {
  test('prevents unauthorized access to admin routes', async ({ page }) => {
    // Try to access admin page without login
    await page.goto('/admin/dashboard')
    
    // Should redirect to login
    await expect(page).toHaveURL('/auth/signin')
    
    // Login as regular user
    await page.fill('[data-testid=email-input]', 'student@example.com')
    await page.fill('[data-testid=password-input]', 'password123')
    await page.click('[data-testid=signin-button]')
    
    // Try to access admin page as student
    await page.goto('/admin/dashboard')
    
    // Should show access denied
    await expect(page.locator('text=Access denied')).toBeVisible()
  })

  test('prevents XSS attacks in course content', async ({ page }) => {
    // Login as instructor
    await page.goto('/auth/signin')
    await page.fill('[data-testid=email-input]', 'instructor@example.com')
    await page.fill('[data-testid=password-input]', 'password123')
    await page.click('[data-testid=signin-button]')
    
    // Navigate to course creation
    await page.goto('/instructor/courses/new')
    
    // Try to inject script in course content
    const maliciousContent = '<script>alert("XSS")</script><p>Normal content</p>'
    
    await page.fill('[data-testid=course-title]', 'Test Course')
    await page.fill('[data-testid=course-content]', maliciousContent)
    await page.click('[data-testid=save-course]')
    
    // Navigate to the created course
    await page.goto('/courses/test-course')
    
    // Script should be sanitized
    const content = await page.locator('[data-testid=course-content]').innerHTML()
    expect(content).not.toContain('<script>')
    expect(content).toContain('<p>Normal content</p>')
  })

  test('implements CSRF protection', async ({ page }) => {
    // Login
    await page.goto('/auth/signin')
    await page.fill('[data-testid=email-input]', 'student@example.com')
    await page.fill('[data-testid=password-input]', 'password123')
    await page.click('[data-testid=signin-button]')
    
    // Get CSRF token
    const csrfToken = await page.evaluate(() => {
      const metaTag = document.querySelector('meta[name="csrf-token"]')
      return metaTag ? metaTag.getAttribute('content') : null
    })
    
    expect(csrfToken).toBeTruthy()
    
    // Make API request without CSRF token (should fail)
    const response = await page.evaluate(async () => {
      return fetch('/api/enrollments', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ courseId: 'test-course-id' }),
      })
    })
    
    expect(response.status).toBe(403)
  })
})
```

## 📱 Accessibility Testing

```typescript
// e2e/accessibility.spec.ts
import { test, expect } from '@playwright/test'
import AxeBuilder from '@axe-core/playwright'

test.describe('Accessibility Tests', () => {
  test('course catalog meets WCAG standards', async ({ page }) => {
    await page.goto('/courses')
    
    const accessibilityScanResults = await new AxeBuilder({ page }).analyze()
    
    expect(accessibilityScanResults.violations).toEqual([])
  })

  test('course player is accessible', async ({ page }) => {
    // Login and navigate to course
    await page.goto('/auth/signin')
    await page.fill('[data-testid=email-input]', 'student@example.com')
    await page.fill('[data-testid=password-input]', 'password123')
    await page.click('[data-testid=signin-button]')
    
    await page.goto('/courses/javascript-fundamentals/learn/lesson-1')
    
    // Check video player accessibility
    const accessibilityScanResults = await new AxeBuilder({ page })
      .include('[data-testid=video-player]')
      .analyze()
    
    expect(accessibilityScanResults.violations).toEqual([])
    
    // Check keyboard navigation
    await page.keyboard.press('Tab')
    await expect(page.locator('[data-testid=play-button]')).toBeFocused()
    
    await page.keyboard.press('Space')
    // Video should start playing
    await page.waitForFunction(() => {
      const video = document.querySelector('video')
      return video && !video.paused
    })
  })

  test('forms are accessible', async ({ page }) => {
    await page.goto('/auth/signin')
    
    // Check form accessibility
    const accessibilityScanResults = await new AxeBuilder({ page })
      .include('form')
      .analyze()
    
    expect(accessibilityScanResults.violations).toEqual([])
    
    // Check proper labeling
    await expect(page.locator('label[for="email"]')).toBeVisible()
    await expect(page.locator('label[for="password"]')).toBeVisible()
    
    // Check error handling accessibility
    await page.click('[data-testid=signin-button]')
    
    const errorMessage = page.locator('[data-testid=form-error]')
    await expect(errorMessage).toBeVisible()
    await expect(errorMessage).toHaveAttribute('role', 'alert')
  })
})
```

## 📊 Test Reporting & CI Integration

### GitHub Actions Workflow

```yaml
# .github/workflows/test.yml
name: Test Suite

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  unit-tests:
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
      
      - name: Run unit tests
        run: npm run test -- --coverage --watchAll=false
      
      - name: Upload coverage to Codecov
        uses: codecov/codecov-action@v3
        with:
          token: ${{ secrets.CODECOV_TOKEN }}

  integration-tests:
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
      
      - name: Run database migrations
        run: npx prisma migrate deploy
        env:
          DATABASE_URL: postgresql://postgres:postgres@localhost:5432/test_db
      
      - name: Run integration tests
        run: npm run test:integration
        env:
          DATABASE_URL: postgresql://postgres:postgres@localhost:5432/test_db

  e2e-tests:
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
      
      - name: Install Playwright browsers
        run: npx playwright install --with-deps
      
      - name: Run E2E tests
        run: npm run test:e2e
      
      - name: Upload Playwright report
        uses: actions/upload-artifact@v3
        if: always()
        with:
          name: playwright-report
          path: playwright-report/
          retention-days: 30
```

### Test Coverage Configuration

```json
{
  "jest": {
    "collectCoverageFrom": [
      "src/**/*.{js,jsx,ts,tsx}",
      "!src/**/*.d.ts",
      "!src/**/*.stories.{js,jsx,ts,tsx}",
      "!src/**/*.test.{js,jsx,ts,tsx}",
      "!src/**/__tests__/**",
      "!src/pages/_app.tsx",
      "!src/pages/_document.tsx"
    ],
    "coverageThreshold": {
      "global": {
        "branches": 80,
        "functions": 80,
        "lines": 80,
        "statements": 80
      },
      "src/components/": {
        "branches": 85,
        "functions": 85,
        "lines": 85,
        "statements": 85
      },
      "src/lib/": {
        "branches": 90,
        "functions": 90,
        "lines": 90,
        "statements": 90
      }
    }
  }
}
```

## 🎯 Testing Best Practices Summary

### 1. Test Structure
- **Arrange**: Set up test data and mocks
- **Act**: Execute the functionality being tested
- **Assert**: Verify the expected outcomes

### 2. Test Naming Convention
```typescript
describe('ComponentName', () => {
  it('should perform expected behavior when given specific input', () => {
    // Test implementation
  })
})
```

### 3. Mock Strategy
- Mock external dependencies (APIs, databases)
- Use real implementations for business logic
- Reset mocks between tests

### 4. Test Data Management
- Use factories for creating test data
- Keep test data minimal and focused
- Clean up test data after tests

### 5. Continuous Testing
- Run tests on every commit
- Fail builds on test failures
- Monitor test coverage trends

## 🔗 Related Documentation

### Previous: [Security Considerations](./security-considerations.md)
### Next: Back to [README](./README.md)

---

*Testing Strategies | Next.js Full Stack Development | 2024*