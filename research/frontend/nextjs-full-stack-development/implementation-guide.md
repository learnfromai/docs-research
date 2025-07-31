# Implementation Guide: Next.js Full Stack Development

## 🚀 Getting Started

This comprehensive guide provides step-by-step instructions for implementing a Next.js full-stack educational platform, covering everything from initial setup to production deployment.

## 📋 Prerequisites

### System Requirements
- **Node.js**: Version 18.17 or later
- **Package Manager**: npm, yarn, or pnpm
- **Git**: Version control system
- **Code Editor**: VS Code (recommended) with Next.js extensions

### Recommended VS Code Extensions
```json
{
  "recommendations": [
    "bradlc.vscode-tailwindcss",
    "ms-vscode.vscode-typescript-next",
    "esbenp.prettier-vscode",
    "ms-vscode.vscode-eslint",
    "formulahendry.auto-rename-tag",
    "christian-kohler.path-intellisense"
  ]
}
```

## 🏗️ Project Setup

### 1. Create Next.js Application

```bash
# Using create-next-app with TypeScript
npx create-next-app@latest education-platform \
  --typescript \
  --tailwind \
  --eslint \
  --app \
  --src-dir \
  --import-alias "@/*"

cd education-platform
```

### 2. Project Structure Setup

```
education-platform/
├── src/
│   ├── app/                    # App Router (Next.js 13+)
│   │   ├── (auth)/            # Route groups
│   │   │   ├── login/
│   │   │   └── register/
│   │   ├── (dashboard)/
│   │   │   ├── courses/
│   │   │   ├── progress/
│   │   │   └── settings/
│   │   ├── api/               # API routes
│   │   │   ├── auth/
│   │   │   ├── courses/
│   │   │   └── users/
│   │   ├── globals.css
│   │   ├── layout.tsx         # Root layout
│   │   ├── loading.tsx        # Global loading UI
│   │   ├── error.tsx          # Global error UI
│   │   └── page.tsx           # Home page
│   ├── components/            # Reusable components
│   │   ├── ui/               # Base UI components
│   │   ├── forms/            # Form components
│   │   ├── layouts/          # Layout components
│   │   └── features/         # Feature-specific components
│   ├── lib/                  # Utility libraries
│   │   ├── auth.ts          # Authentication logic
│   │   ├── db.ts            # Database connection
│   │   ├── utils.ts         # Utility functions
│   │   └── validations.ts   # Schema validations
│   ├── hooks/               # Custom React hooks
│   ├── types/               # TypeScript type definitions
│   └── styles/              # Additional styles
├── public/                  # Static assets
├── prisma/                 # Database schema (if using Prisma)
├── tests/                  # Test files
├── docs/                   # Documentation
├── .env.local             # Environment variables
├── next.config.js         # Next.js configuration
├── tailwind.config.js     # Tailwind CSS configuration
├── tsconfig.json          # TypeScript configuration
└── package.json           # Dependencies and scripts
```

### 3. Essential Dependencies Installation

```bash
# Authentication
npm install next-auth @auth/prisma-adapter

# Database (choose one)
npm install prisma @prisma/client  # For SQL databases
npm install mongoose              # For MongoDB

# UI and Styling
npm install @headlessui/react @heroicons/react
npm install clsx tailwind-merge

# Form Handling
npm install react-hook-form @hookform/resolvers zod

# State Management
npm install zustand @tanstack/react-query

# Development Dependencies
npm install -D @types/node @types/react @types/react-dom
npm install -D prettier prettier-plugin-tailwindcss
npm install -D jest @testing-library/react @testing-library/jest-dom
```

## 🔧 Core Configuration

### 1. Next.js Configuration

```javascript
// next.config.js
/** @type {import('next').NextConfig} */
const nextConfig = {
  experimental: {
    appDir: true,
  },
  images: {
    domains: ['example.com', 'cdn.education-platform.com'],
    formats: ['image/webp', 'image/avif'],
  },
  compiler: {
    removeConsole: process.env.NODE_ENV === 'production',
  },
  env: {
    CUSTOM_KEY: process.env.CUSTOM_KEY,
  },
}

module.exports = nextConfig
```

### 2. TypeScript Configuration

```json
// tsconfig.json
{
  "compilerOptions": {
    "target": "es5",
    "lib": ["dom", "dom.iterable", "es6"],
    "allowJs": true,
    "skipLibCheck": true,
    "strict": true,
    "noEmit": true,
    "esModuleInterop": true,
    "module": "esnext",
    "moduleResolution": "bundler",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "jsx": "preserve",
    "incremental": true,
    "plugins": [
      {
        "name": "next"
      }
    ],
    "baseUrl": ".",
    "paths": {
      "@/*": ["./src/*"]
    }
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx", ".next/types/**/*.ts"],
  "exclude": ["node_modules"]
}
```

### 3. Environment Variables Setup

```bash
# .env.local
# Database
DATABASE_URL="postgresql://username:password@localhost:5432/education_platform"

# Authentication
NEXTAUTH_URL="http://localhost:3000"
NEXTAUTH_SECRET="your-secret-key-here"

# OAuth Providers (optional)
GOOGLE_CLIENT_ID="your-google-client-id"
GOOGLE_CLIENT_SECRET="your-google-client-secret"

# External APIs
STRIPE_SECRET_KEY="sk_test_your-stripe-secret-key"
STRIPE_PUBLISHABLE_KEY="pk_test_your-stripe-publishable-key"

# Email Service
EMAIL_SERVER_USER="your-email"
EMAIL_SERVER_PASSWORD="your-password"
EMAIL_SERVER_HOST="smtp.gmail.com"
EMAIL_SERVER_PORT="587"
EMAIL_FROM="noreply@education-platform.com"
```

## 🗄️ Database Setup (Prisma + PostgreSQL)

### 1. Initialize Prisma

```bash
npx prisma init
```

### 2. Database Schema

```prisma
// prisma/schema.prisma
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

model User {
  id            String    @id @default(cuid())
  name          String?
  email         String    @unique
  emailVerified DateTime?
  image         String?
  role          Role      @default(STUDENT)
  createdAt     DateTime  @default(now())
  updatedAt     DateTime  @updatedAt

  accounts      Account[]
  sessions      Session[]
  enrollments   Enrollment[]
  progress      Progress[]

  @@map("users")
}

model Account {
  id                String  @id @default(cuid())
  userId            String
  type              String
  provider          String
  providerAccountId String
  refresh_token     String? @db.Text
  access_token      String? @db.Text
  expires_at        Int?
  token_type        String?
  scope             String?
  id_token          String? @db.Text
  session_state     String?

  user User @relation(fields: [userId], references: [id], onDelete: Cascade)

  @@unique([provider, providerAccountId])
  @@map("accounts")
}

model Session {
  id           String   @id @default(cuid())
  sessionToken String   @unique
  userId       String
  expires      DateTime
  user         User     @relation(fields: [userId], references: [id], onDelete: Cascade)

  @@map("sessions")
}

model Course {
  id          String   @id @default(cuid())
  title       String
  description String?
  slug        String   @unique
  published   Boolean  @default(false)
  createdAt   DateTime @default(now())
  updatedAt   DateTime @updatedAt

  lessons     Lesson[]
  enrollments Enrollment[]

  @@map("courses")
}

model Lesson {
  id          String   @id @default(cuid())
  title       String
  content     String   @db.Text
  videoUrl    String?
  order       Int
  published   Boolean  @default(false)
  courseId    String
  createdAt   DateTime @default(now())
  updatedAt   DateTime @updatedAt

  course   Course     @relation(fields: [courseId], references: [id], onDelete: Cascade)
  progress Progress[]

  @@map("lessons")
}

model Enrollment {
  id        String   @id @default(cuid())
  userId    String
  courseId  String
  createdAt DateTime @default(now())

  user   User   @relation(fields: [userId], references: [id], onDelete: Cascade)
  course Course @relation(fields: [courseId], references: [id], onDelete: Cascade)

  @@unique([userId, courseId])
  @@map("enrollments")
}

model Progress {
  id         String   @id @default(cuid())
  userId     String
  lessonId   String
  completed  Boolean  @default(false)
  completedAt DateTime?
  createdAt  DateTime @default(now())
  updatedAt  DateTime @updatedAt

  user   User   @relation(fields: [userId], references: [id], onDelete: Cascade)
  lesson Lesson @relation(fields: [lessonId], references: [id], onDelete: Cascade)

  @@unique([userId, lessonId])
  @@map("progress")
}

enum Role {
  ADMIN
  INSTRUCTOR
  STUDENT
}
```

### 3. Database Migration

```bash
# Generate Prisma client
npx prisma generate

# Create and run migration
npx prisma migrate dev --name init

# Seed database (optional)
npx prisma db seed
```

## 🔐 Authentication Setup (NextAuth.js)

### 1. NextAuth Configuration

```typescript
// src/lib/auth.ts
import { NextAuthOptions } from 'next-auth'
import { PrismaAdapter } from '@auth/prisma-adapter'
import GoogleProvider from 'next-auth/providers/google'
import CredentialsProvider from 'next-auth/providers/credentials'
import { prisma } from './db'
import bcrypt from 'bcryptjs'

export const authOptions: NextAuthOptions = {
  adapter: PrismaAdapter(prisma),
  providers: [
    GoogleProvider({
      clientId: process.env.GOOGLE_CLIENT_ID!,
      clientSecret: process.env.GOOGLE_CLIENT_SECRET!,
    }),
    CredentialsProvider({
      name: 'credentials',
      credentials: {
        email: { label: 'Email', type: 'email' },
        password: { label: 'Password', type: 'password' }
      },
      async authorize(credentials) {
        if (!credentials?.email || !credentials?.password) {
          return null
        }

        const user = await prisma.user.findUnique({
          where: { email: credentials.email }
        })

        if (!user) {
          return null
        }

        const isPasswordValid = await bcrypt.compare(
          credentials.password,
          user.password
        )

        if (!isPasswordValid) {
          return null
        }

        return {
          id: user.id,
          email: user.email,
          name: user.name,
          role: user.role,
        }
      }
    })
  ],
  session: {
    strategy: 'jwt',
  },
  callbacks: {
    jwt: async ({ token, user }) => {
      if (user) {
        token.role = user.role
      }
      return token
    },
    session: async ({ session, token }) => {
      if (session?.user) {
        session.user.id = token.sub!
        session.user.role = token.role as string
      }
      return session
    },
  },
  pages: {
    signIn: '/auth/signin',
    signUp: '/auth/signup',
  },
}
```

### 2. API Route Handler

```typescript
// src/app/api/auth/[...nextauth]/route.ts
import NextAuth from 'next-auth'
import { authOptions } from '@/lib/auth'

const handler = NextAuth(authOptions)

export { handler as GET, handler as POST }
```

## 🎨 UI Components Setup

### 1. Base Button Component

```typescript
// src/components/ui/button.tsx
import { ButtonHTMLAttributes, forwardRef } from 'react'
import { cva, type VariantProps } from 'class-variance-authority'
import { cn } from '@/lib/utils'

const buttonVariants = cva(
  'inline-flex items-center justify-center rounded-md text-sm font-medium transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:opacity-50 disabled:pointer-events-none ring-offset-background',
  {
    variants: {
      variant: {
        default: 'bg-primary text-primary-foreground hover:bg-primary/90',
        destructive: 'bg-destructive text-destructive-foreground hover:bg-destructive/90',
        outline: 'border border-input hover:bg-accent hover:text-accent-foreground',
        secondary: 'bg-secondary text-secondary-foreground hover:bg-secondary/80',
        ghost: 'hover:bg-accent hover:text-accent-foreground',
        link: 'underline-offset-4 hover:underline text-primary',
      },
      size: {
        default: 'h-10 py-2 px-4',
        sm: 'h-9 px-3 rounded-md',
        lg: 'h-11 px-8 rounded-md',
      },
    },
    defaultVariants: {
      variant: 'default',
      size: 'default',
    },
  }
)

export interface ButtonProps
  extends ButtonHTMLAttributes<HTMLButtonElement>,
    VariantProps<typeof buttonVariants> {}

const Button = forwardRef<HTMLButtonElement, ButtonProps>(
  ({ className, variant, size, ...props }, ref) => {
    return (
      <button
        className={cn(buttonVariants({ variant, size, className }))}
        ref={ref}
        {...props}
      />
    )
  }
)
Button.displayName = 'Button'

export { Button, buttonVariants }
```

### 2. Course Card Component

```typescript
// src/components/features/course-card.tsx
import Image from 'next/image'
import Link from 'next/link'
import { Button } from '@/components/ui/button'
import { Clock, Users } from 'lucide-react'

interface CourseCardProps {
  course: {
    id: string
    title: string
    description: string
    slug: string
    thumbnail?: string
    duration?: string
    studentsCount?: number
    price?: number
  }
}

export function CourseCard({ course }: CourseCardProps) {
  return (
    <div className="bg-white rounded-lg shadow-md overflow-hidden hover:shadow-lg transition-shadow">
      <div className="relative h-48 bg-gray-200">
        {course.thumbnail ? (
          <Image
            src={course.thumbnail}
            alt={course.title}
            fill
            className="object-cover"
          />
        ) : (
          <div className="flex items-center justify-center h-full text-gray-400">
            <span>No Image</span>
          </div>
        )}
      </div>
      
      <div className="p-6">
        <h3 className="font-semibold text-lg mb-2 line-clamp-2">
          {course.title}
        </h3>
        
        <p className="text-gray-600 text-sm mb-4 line-clamp-3">
          {course.description}
        </p>
        
        <div className="flex items-center justify-between text-sm text-gray-500 mb-4">
          {course.duration && (
            <div className="flex items-center">
              <Clock className="w-4 h-4 mr-1" />
              {course.duration}
            </div>
          )}
          
          {course.studentsCount && (
            <div className="flex items-center">
              <Users className="w-4 h-4 mr-1" />
              {course.studentsCount} students
            </div>
          )}
        </div>
        
        <div className="flex items-center justify-between">
          <div className="text-lg font-bold text-green-600">
            {course.price ? `₱${course.price}` : 'Free'}
          </div>
          
          <Button asChild>
            <Link href={`/courses/${course.slug}`}>
              View Course
            </Link>
          </Button>
        </div>
      </div>
    </div>
  )
}
```

## 🛣️ API Routes Implementation

### 1. Courses API Route

```typescript
// src/app/api/courses/route.ts
import { NextRequest, NextResponse } from 'next/server'
import { getServerSession } from 'next-auth'
import { prisma } from '@/lib/db'
import { authOptions } from '@/lib/auth'

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url)
    const page = parseInt(searchParams.get('page') || '1')
    const limit = parseInt(searchParams.get('limit') || '10')
    const search = searchParams.get('search') || ''

    const courses = await prisma.course.findMany({
      where: {
        published: true,
        ...(search && {
          OR: [
            { title: { contains: search, mode: 'insensitive' } },
            { description: { contains: search, mode: 'insensitive' } },
          ],
        }),
      },
      include: {
        _count: {
          select: {
            enrollments: true,
            lessons: true,
          },
        },
      },
      skip: (page - 1) * limit,
      take: limit,
      orderBy: { createdAt: 'desc' },
    })

    const total = await prisma.course.count({
      where: {
        published: true,
        ...(search && {
          OR: [
            { title: { contains: search, mode: 'insensitive' } },
            { description: { contains: search, mode: 'insensitive' } },
          ],
        }),
      },
    })

    return NextResponse.json({
      courses,
      pagination: {
        page,
        limit,
        total,
        pages: Math.ceil(total / limit),
      },
    })
  } catch (error) {
    console.error('Courses API Error:', error)
    return NextResponse.json(
      { error: 'Failed to fetch courses' },
      { status: 500 }
    )
  }
}

export async function POST(request: NextRequest) {
  try {
    const session = await getServerSession(authOptions)
    
    if (!session || session.user.role !== 'ADMIN') {
      return NextResponse.json(
        { error: 'Unauthorized' },
        { status: 401 }
      )
    }

    const body = await request.json()
    const { title, description, slug } = body

    const course = await prisma.course.create({
      data: {
        title,
        description,
        slug,
      },
    })

    return NextResponse.json(course, { status: 201 })
  } catch (error) {
    console.error('Create Course Error:', error)
    return NextResponse.json(
      { error: 'Failed to create course' },
      { status: 500 }
    )
  }
}
```

### 2. User Progress API Route

```typescript
// src/app/api/progress/route.ts
import { NextRequest, NextResponse } from 'next/server'
import { getServerSession } from 'next-auth'
import { prisma } from '@/lib/db'
import { authOptions } from '@/lib/auth'

export async function POST(request: NextRequest) {
  try {
    const session = await getServerSession(authOptions)
    
    if (!session) {
      return NextResponse.json(
        { error: 'Unauthorized' },
        { status: 401 }
      )
    }

    const body = await request.json()
    const { lessonId, completed } = body
    const userId = session.user.id

    const progress = await prisma.progress.upsert({
      where: {
        userId_lessonId: {
          userId,
          lessonId,
        },
      },
      update: {
        completed,
        completedAt: completed ? new Date() : null,
        updatedAt: new Date(),
      },
      create: {
        userId,
        lessonId,
        completed,
        completedAt: completed ? new Date() : null,
      },
    })

    return NextResponse.json(progress)
  } catch (error) {
    console.error('Progress API Error:', error)
    return NextResponse.json(
      { error: 'Failed to update progress' },
      { status: 500 }
    )
  }
}

export async function GET(request: NextRequest) {
  try {
    const session = await getServerSession(authOptions)
    
    if (!session) {
      return NextResponse.json(
        { error: 'Unauthorized' },
        { status: 401 }
      )
    }

    const { searchParams } = new URL(request.url)
    const courseId = searchParams.get('courseId')
    const userId = session.user.id

    if (!courseId) {
      return NextResponse.json(
        { error: 'Course ID is required' },
        { status: 400 }
      )
    }

    const progress = await prisma.progress.findMany({
      where: {
        userId,
        lesson: {
          courseId,
        },
      },
      include: {
        lesson: true,
      },
    })

    return NextResponse.json(progress)
  } catch (error) {
    console.error('Get Progress Error:', error)
    return NextResponse.json(
      { error: 'Failed to fetch progress' },
      { status: 500 }
    )
  }
}
```

## 📱 Pages Implementation

### 1. Home Page with SSG

```typescript
// src/app/page.tsx
import { Metadata } from 'next'
import { prisma } from '@/lib/db'
import { CourseCard } from '@/components/features/course-card'
import { Button } from '@/components/ui/button'
import Link from 'next/link'

export const metadata: Metadata = {
  title: 'Education Platform - Philippine Licensure Exam Reviews',
  description: 'Comprehensive online courses for Philippine professional licensure examinations',
}

async function getFeaturedCourses() {
  const courses = await prisma.course.findMany({
    where: { published: true },
    include: {
      _count: {
        select: { enrollments: true },
      },
    },
    take: 6,
    orderBy: { createdAt: 'desc' },
  })

  return courses
}

export default async function HomePage() {
  const featuredCourses = await getFeaturedCourses()

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Hero Section */}
      <section className="bg-blue-600 text-white py-20">
        <div className="container mx-auto px-4 text-center">
          <h1 className="text-4xl md:text-6xl font-bold mb-6">
            Master Your Licensure Exams
          </h1>
          <p className="text-xl md:text-2xl mb-8 opacity-90">
            Comprehensive online courses designed for Philippine professional examinations
          </p>
          <div className="space-x-4">
            <Button size="lg" asChild>
              <Link href="/courses">Browse Courses</Link>
            </Button>
            <Button size="lg" variant="outline" asChild>
              <Link href="/auth/register">Get Started Free</Link>
            </Button>
          </div>
        </div>
      </section>

      {/* Featured Courses */}
      <section className="py-16">
        <div className="container mx-auto px-4">
          <h2 className="text-3xl font-bold text-center mb-12">
            Featured Courses
          </h2>
          
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
            {featuredCourses.map((course) => (
              <CourseCard
                key={course.id}
                course={{
                  id: course.id,
                  title: course.title,
                  description: course.description || '',
                  slug: course.slug,
                  studentsCount: course._count.enrollments,
                }}
              />
            ))}
          </div>
          
          <div className="text-center mt-12">
            <Button asChild>
              <Link href="/courses">View All Courses</Link>
            </Button>
          </div>
        </div>
      </section>

      {/* Features Section */}
      <section className="py-16 bg-white">
        <div className="container mx-auto px-4">
          <h2 className="text-3xl font-bold text-center mb-12">
            Why Choose Our Platform?
          </h2>
          
          <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
            <div className="text-center">
              <div className="bg-blue-100 w-16 h-16 rounded-full flex items-center justify-center mx-auto mb-4">
                <span className="text-2xl">📚</span>
              </div>
              <h3 className="text-xl font-semibold mb-2">Expert Content</h3>
              <p className="text-gray-600">
                Curated by licensed professionals and industry experts
              </p>
            </div>
            
            <div className="text-center">
              <div className="bg-green-100 w-16 h-16 rounded-full flex items-center justify-center mx-auto mb-4">
                <span className="text-2xl">⚡</span>
              </div>
              <h3 className="text-xl font-semibold mb-2">Interactive Learning</h3>
              <p className="text-gray-600">
                Engaging exercises, quizzes, and progress tracking
              </p>
            </div>
            
            <div className="text-center">
              <div className="bg-purple-100 w-16 h-16 rounded-full flex items-center justify-center mx-auto mb-4">
                <span className="text-2xl">🏆</span>
              </div>
              <h3 className="text-xl font-semibold mb-2">Proven Results</h3>
              <p className="text-gray-600">
                High pass rates and successful graduates
              </p>
            </div>
          </div>
        </div>
      </section>
    </div>
  )
}
```

### 2. Course Detail Page with SSR

```typescript
// src/app/courses/[slug]/page.tsx
import { Metadata } from 'next'
import { notFound } from 'next/navigation'
import { getServerSession } from 'next-auth'
import { prisma } from '@/lib/db'
import { authOptions } from '@/lib/auth'
import { Button } from '@/components/ui/button'
import { EnrollButton } from '@/components/features/enroll-button'

interface CoursePageProps {
  params: {
    slug: string
  }
}

async function getCourse(slug: string) {
  const course = await prisma.course.findUnique({
    where: { slug },
    include: {
      lessons: {
        where: { published: true },
        orderBy: { order: 'asc' },
      },
      _count: {
        select: { enrollments: true },
      },
    },
  })

  return course
}

async function getUserEnrollment(courseId: string, userId?: string) {
  if (!userId) return null

  const enrollment = await prisma.enrollment.findUnique({
    where: {
      userId_courseId: {
        userId,
        courseId,
      },
    },
  })

  return enrollment
}

export async function generateMetadata({ params }: CoursePageProps): Promise<Metadata> {
  const course = await getCourse(params.slug)

  if (!course) {
    return {
      title: 'Course Not Found',
    }
  }

  return {
    title: `${course.title} - Education Platform`,
    description: course.description,
  }
}

export default async function CoursePage({ params }: CoursePageProps) {
  const course = await getCourse(params.slug)
  const session = await getServerSession(authOptions)
  
  if (!course) {
    notFound()
  }

  const enrollment = await getUserEnrollment(course.id, session?.user?.id)
  const isEnrolled = !!enrollment

  return (
    <div className="min-h-screen bg-gray-50">
      <div className="container mx-auto px-4 py-8">
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
          {/* Main Content */}
          <div className="lg:col-span-2">
            <h1 className="text-3xl font-bold mb-4">{course.title}</h1>
            
            {course.description && (
              <div className="bg-white p-6 rounded-lg shadow-sm mb-6">
                <h2 className="text-xl font-semibold mb-3">About This Course</h2>
                <p className="text-gray-700 leading-relaxed">
                  {course.description}
                </p>
              </div>
            )}

            {/* Course Content */}
            <div className="bg-white p-6 rounded-lg shadow-sm">
              <h2 className="text-xl font-semibold mb-4">Course Content</h2>
              
              <div className="space-y-3">
                {course.lessons.map((lesson, index) => (
                  <div
                    key={lesson.id}
                    className="flex items-center p-3 border rounded-lg hover:bg-gray-50"
                  >
                    <div className="flex-shrink-0 w-8 h-8 bg-blue-100 rounded-full flex items-center justify-center text-sm font-medium text-blue-600 mr-3">
                      {index + 1}
                    </div>
                    <div className="flex-grow">
                      <h3 className="font-medium">{lesson.title}</h3>
                    </div>
                    {!isEnrolled && (
                      <div className="text-sm text-gray-500">🔒</div>
                    )}
                  </div>
                ))}
              </div>
            </div>
          </div>

          {/* Sidebar */}
          <div className="lg:col-span-1">
            <div className="bg-white p-6 rounded-lg shadow-sm sticky top-6">
              <div className="text-center mb-6">
                <div className="text-3xl font-bold text-green-600 mb-2">
                  Free
                </div>
                <p className="text-sm text-gray-600">
                  {course._count.enrollments} students enrolled
                </p>
              </div>

              <div className="space-y-4 mb-6">
                <div className="flex justify-between">
                  <span className="text-gray-600">Lessons:</span>
                  <span className="font-medium">{course.lessons.length}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-600">Level:</span>
                  <span className="font-medium">Beginner</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-600">Certificate:</span>
                  <span className="font-medium">Yes</span>
                </div>
              </div>

              <EnrollButton
                courseId={course.id}
                isEnrolled={isEnrolled}
                isAuthenticated={!!session}
              />

              {isEnrolled && (
                <Button asChild className="w-full mt-3">
                  <Link href={`/courses/${course.slug}/learn`}>
                    Continue Learning
                  </Link>
                </Button>
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}
```

## 🔄 Development Workflow

### 1. Development Scripts

```json
// package.json scripts
{
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "lint": "next lint",
    "lint:fix": "next lint --fix",
    "type-check": "tsc --noEmit",
    "format": "prettier --write .",
    "db:push": "prisma db push",
    "db:migrate": "prisma migrate dev",
    "db:generate": "prisma generate",
    "db:seed": "prisma db seed",
    "db:studio": "prisma studio",
    "test": "jest",
    "test:watch": "jest --watch",
    "test:coverage": "jest --coverage"
  }
}
```

### 2. Development Workflow Commands

```bash
# Start development server
npm run dev

# Run database operations
npm run db:push          # Push schema changes
npm run db:migrate       # Create migration
npm run db:generate      # Generate Prisma client
npm run db:studio        # Open Prisma Studio

# Code quality
npm run lint             # Check for linting issues
npm run lint:fix         # Fix linting issues
npm run type-check       # TypeScript type checking
npm run format           # Format code with Prettier

# Testing
npm run test             # Run tests
npm run test:watch       # Run tests in watch mode
npm run test:coverage    # Run tests with coverage
```

## 🚀 Next Steps

1. **[Best Practices](./best-practices.md)** - Code organization and optimization strategies
2. **[Performance Analysis](./performance-analysis.md)** - SSR vs SSG performance optimization
3. **[Deployment Guide](./deployment-guide.md)** - Production deployment strategies
4. **[Security Considerations](./security-considerations.md)** - Authentication and data protection

---

*Implementation Guide | Next.js Full Stack Development | 2024*