# Technology Stack Analysis: Modern Frameworks and Tools for LMS Development

## Modern LMS Technology Stack Overview

### Full-Stack Architecture Recommendations

**Optimal Technology Stack for Personal Learning Management System:**

```typescript
interface OptimalLMSStack {
  // Frontend Development
  frontend: {
    framework: 'Next.js 14'           // React-based with SSR/SSG capabilities
    language: 'TypeScript'            // Type safety and developer experience
    styling: 'Tailwind CSS'           // Rapid UI development and consistency
    stateManagement: 'Zustand'        // Lightweight and flexible state management
    uiComponents: 'Shadcn/UI'         // High-quality, accessible components
    animations: 'Framer Motion'       // Smooth animations and transitions
    forms: 'React Hook Form'          // Efficient form handling
    dataFetching: 'TanStack Query'    // Server state management
  }
  
  // Backend Development
  backend: {
    runtime: 'Node.js 20'             // Latest LTS version
    framework: 'Express.js'           // Mature and flexible web framework
    language: 'TypeScript'            // Consistent language across stack
    validation: 'Zod'                 // Schema validation
    authentication: 'NextAuth.js'     // Comprehensive auth solution
    apiDocumentation: 'OpenAPI/Swagger' // API specification and docs
    testing: 'Jest + Supertest'       // Unit and integration testing
  }
  
  // Database and Storage
  database: {
    primary: 'PostgreSQL 16'          // Relational database for structured data
    cache: 'Redis 7'                  // In-memory caching and sessions
    orm: 'Prisma'                     // Type-safe database toolkit
    migrations: 'Prisma Migrate'      // Database schema management
    search: 'PostgreSQL Full-Text'    // Built-in search capabilities
    fileStorage: 'AWS S3'             // Scalable file storage
  }
  
  // Infrastructure and DevOps
  infrastructure: {
    hosting: 'Vercel'                 // Serverless deployment platform
    database: 'Supabase/Railway'      // Managed PostgreSQL hosting
    cdn: 'Vercel Edge Network'        // Global content delivery
    monitoring: 'Sentry'              // Error tracking and performance
    analytics: 'PostHog'              // Product analytics and feature flags
    cicd: 'GitHub Actions'            // Continuous integration and deployment
  }
}
```

### Alternative Stack Configurations

**Budget-Conscious Stack:**

```typescript
interface BudgetFriendlyStack {
  hosting: 'Netlify/Railway'          // Free tiers available
  database: 'SQLite/PostgreSQL'      // Start with SQLite, upgrade to PostgreSQL
  authentication: 'Clerk/Auth0 Free' // Free tier authentication
  storage: 'Cloudinary Free'         // Free tier for media storage
  monitoring: 'LogRocket Free'       // Free tier for basic monitoring
  totalMonthlyCost: 0-50              // USD per month
}
```

**Enterprise-Grade Stack:**

```typescript
interface EnterpriseStack {
  hosting: 'AWS ECS/EKS'              // Container orchestration
  database: 'AWS RDS Aurora'          // Managed enterprise database
  cache: 'AWS ElastiCache'            // Managed Redis/Memcached
  storage: 'AWS S3 + CloudFront'      // Enterprise storage and CDN
  monitoring: 'DataDog'               // Comprehensive monitoring suite
  security: 'AWS WAF + Shield'        // Web application firewall
  totalMonthlyCost: 500-2000          // USD per month
}
```

## Frontend Technology Deep Dive

### 1. Next.js 14 for LMS Development

**Next.js Advantages for Learning Platforms:**

```typescript
// Next.js 14 App Router Configuration for LMS
// app/layout.tsx
import type { Metadata } from 'next'
import { Inter } from 'next/font/google'
import { Providers } from './providers'
import './globals.css'

const inter = Inter({ subsets: ['latin'] })

export const metadata: Metadata = {
  title: 'Personal Learning Management System',
  description: 'Structured approach to continuous education',
  keywords: ['learning', 'education', 'skills', 'career development'],
  authors: [{ name: 'Your Name' }],
  openGraph: {
    title: 'Personal Learning Management System',
    description: 'Structured approach to continuous education',
    url: 'https://your-domain.com',
    siteName: 'PLMS',
    images: [
      {
        url: 'https://your-domain.com/og-image.jpg',
        width: 1200,
        height: 630,
      },
    ],
  },
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en">
      <body className={inter.className}>
        <Providers>
          {children}
        </Providers>
      </body>
    </html>
  )
}

// Progressive Web App Configuration
// next.config.js
/** @type {import('next').NextConfig} */
const nextConfig = {
  experimental: {
    appDir: true,
    serverComponentsExternalPackages: ['@prisma/client'],
  },
  images: {
    domains: ['your-cdn-domain.com', 'images.unsplash.com'],
    deviceSizes: [640, 750, 828, 1080, 1200, 1920, 2048, 3840],
  },
  // Enable PWA features
  async headers() {
    return [
      {
        source: '/(.*)',
        headers: [
          {
            key: 'X-Frame-Options',
            value: 'DENY',
          },
          {
            key: 'X-Content-Type-Options',
            value: 'nosniff',
          },
          {
            key: 'Referrer-Policy',
            value: 'strict-origin-when-cross-origin',
          },
        ],
      },
    ]
  },
}

module.exports = nextConfig
```

**Performance Optimizations:**

```typescript
// Dynamic Imports for Code Splitting
import dynamic from 'next/dynamic'
import { Suspense } from 'react'

// Lazy load heavy components
const VideoPlayer = dynamic(() => import('@/components/VideoPlayer'), {
  loading: () => <VideoPlayerSkeleton />,
  ssr: false, // Disable SSR for client-side only components
})

const LearningDashboard = dynamic(() => import('@/components/LearningDashboard'), {
  loading: () => <DashboardSkeleton />,
})

// Optimized Learning Content Page
export default function LessonPage({ params }: { params: { id: string } }) {
  return (
    <div className="lesson-container">
      <Suspense fallback={<ContentSkeleton />}>
        <LessonContent lessonId={params.id} />
      </Suspense>
      
      <Suspense fallback={<VideoPlayerSkeleton />}>
        <VideoPlayer lessonId={params.id} />
      </Suspense>
      
      <Suspense fallback={<ProgressSkeleton />}>
        <ProgressTracker lessonId={params.id} />
      </Suspense>
    </div>
  )
}

// Image Optimization for Learning Materials
import Image from 'next/image'

const OptimizedLearningImage = ({ src, alt, ...props }) => {
  return (
    <Image
      src={src}
      alt={alt}
      quality={85}
      placeholder="blur"
      blurDataURL="data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAYEBQYFBAYGBQYHBwYIChAKCgkJChQODwwQFxQYGBcUFhYaHSUfGhsjHBYWICwgIyYnKSopGR8tMC0oMCUoKSj/2wBDAQcHBwoIChMKChMoGhYaKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCj/wAARCAABAAEDASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAUCBAQEBQUAAAAAAAECAxEEBSExBhJBUWETInEHMoGRoSNCUgiBBfDx4TSDQ3F0g5KisLF1VNdwNGJSNFdSkUUoIiMQZyOCshXjQpFTRBN0HJVIGiIZH4T0RVgcKx4jJyc0SjRVdNdGNDU1QzNj4qKystDRYpFSYpP/aAAwDAQACEQMRAD8A8+ooooA//9k="
      sizes="(max-width: 768px) 100vw, (max-width: 1200px) 50vw, 33vw"
      {...props}
    />
  )
}
```

### 2. TypeScript Integration

**Type-Safe LMS Development:**

```typescript
// Domain Types for Learning Management
// types/learning.ts
export interface User {
  id: string
  email: string
  name: string
  profile: UserProfile
  createdAt: Date
  updatedAt: Date
}

export interface UserProfile {
  avatarUrl?: string
  bio?: string
  learningGoals: LearningGoal[]
  skillLevel: SkillLevel
  preferences: UserPreferences
}

export interface LearningTrack {
  id: string
  title: string
  description: string
  modules: LearningModule[]
  prerequisites: string[]
  estimatedHours: number
  difficultyLevel: DifficultyLevel
  tags: string[]
  createdAt: Date
}

export interface LearningModule {
  id: string
  trackId: string
  title: string
  description: string
  lessons: Lesson[]
  orderIndex: number
  isRequired: boolean
  estimatedHours: number
}

export interface Lesson {
  id: string
  moduleId: string
  title: string
  content: LessonContent
  type: LessonType
  orderIndex: number
  estimatedMinutes: number
  resources: Resource[]
}

export type LessonType = 'video' | 'article' | 'exercise' | 'quiz' | 'project'
export type DifficultyLevel = 'beginner' | 'intermediate' | 'advanced'
export type SkillLevel = 'novice' | 'beginner' | 'intermediate' | 'advanced' | 'expert'

// API Response Types
export interface ApiResponse<T> {
  success: boolean
  data?: T
  error?: {
    code: string
    message: string
    details?: Record<string, any>
  }
  pagination?: {
    page: number
    limit: number
    total: number
    totalPages: number
  }
}

// Learning Progress Types
export interface UserProgress {
  id: string
  userId: string
  lessonId: string
  status: ProgressStatus
  progressPercentage: number
  timeSpentMinutes: number
  completedAt?: Date
  lastAccessedAt: Date
}

export type ProgressStatus = 'not_started' | 'in_progress' | 'completed' | 'paused'

// Spaced Repetition Types
export interface FlashcardReview {
  id: string
  userId: string
  flashcardId: string
  easeFactor: number
  interval: number
  repetitions: number
  nextReviewDate: Date
  lastReviewedAt: Date
  qualityRating: number // 0-5 scale
}
```

### 3. UI Component Library with Shadcn/UI

**Accessible Learning Components:**

```typescript
// components/ui/progress-card.tsx
import * as React from "react"
import { cn } from "@/lib/utils"
import { Progress } from "@/components/ui/progress"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"

interface ProgressCardProps extends React.HTMLAttributes<HTMLDivElement> {
  title: string
  progress: number
  totalLessons: number
  completedLessons: number
  estimatedTime?: number
  difficulty?: "beginner" | "intermediate" | "advanced"
}

const ProgressCard = React.forwardRef<HTMLDivElement, ProgressCardProps>(
  ({ className, title, progress, totalLessons, completedLessons, estimatedTime, difficulty, ...props }, ref) => {
    const difficultyColors = {
      beginner: "bg-green-100 text-green-800",
      intermediate: "bg-yellow-100 text-yellow-800",
      advanced: "bg-red-100 text-red-800"
    }

    return (
      <Card ref={ref} className={cn("w-full", className)} {...props}>
        <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
          <CardTitle className="text-sm font-medium line-clamp-2">{title}</CardTitle>
          {difficulty && (
            <Badge variant="secondary" className={difficultyColors[difficulty]}>
              {difficulty}
            </Badge>
          )}
        </CardHeader>
        <CardContent>
          <div className="space-y-3">
            <div className="flex items-center justify-between text-sm">
              <span className="text-muted-foreground">Progress</span>
              <span className="font-medium">{Math.round(progress)}%</span>
            </div>
            <Progress value={progress} className="h-2" />
            <div className="flex items-center justify-between text-sm text-muted-foreground">
              <span>{completedLessons} of {totalLessons} lessons</span>
              {estimatedTime && <span>~{estimatedTime}h remaining</span>}
            </div>
          </div>
        </CardContent>
      </Card>
    )
  }
)
ProgressCard.displayName = "ProgressCard"

export { ProgressCard }

// components/learning/lesson-video-player.tsx
import React, { useState, useRef, useEffect } from 'react'
import { Play, Pause, Volume2, VolumeX, Maximize, RotateCcw } from 'lucide-react'
import { Button } from '@/components/ui/button'
import { Slider } from '@/components/ui/slider'
import { cn } from '@/lib/utils'

interface VideoPlayerProps {
  src: string
  poster?: string
  onProgress?: (progress: number) => void
  onComplete?: () => void
  className?: string
}

export function LessonVideoPlayer({ 
  src, 
  poster, 
  onProgress, 
  onComplete, 
  className 
}: VideoPlayerProps) {
  const videoRef = useRef<HTMLVideoElement>(null)
  const [isPlaying, setIsPlaying] = useState(false)
  const [currentTime, setCurrentTime] = useState(0)
  const [duration, setDuration] = useState(0)
  const [volume, setVolume] = useState(1)
  const [isMuted, setIsMuted] = useState(false)
  const [isFullscreen, setIsFullscreen] = useState(false)

  const handlePlayPause = () => {
    if (videoRef.current) {
      if (isPlaying) {
        videoRef.current.pause()
      } else {
        videoRef.current.play()
      }
      setIsPlaying(!isPlaying)
    }
  }

  const handleTimeUpdate = () => {
    if (videoRef.current) {
      const progress = (videoRef.current.currentTime / videoRef.current.duration) * 100
      setCurrentTime(videoRef.current.currentTime)
      onProgress?.(progress)
    }
  }

  const handleVideoEnd = () => {
    setIsPlaying(false)
    onComplete?.()
  }

  const handleSeek = (value: number[]) => {
    if (videoRef.current) {
      const seekTime = (value[0] / 100) * duration
      videoRef.current.currentTime = seekTime
      setCurrentTime(seekTime)
    }
  }

  const toggleMute = () => {
    if (videoRef.current) {
      videoRef.current.muted = !isMuted
      setIsMuted(!isMuted)
    }
  }

  const handleVolumeChange = (value: number[]) => {
    if (videoRef.current) {
      videoRef.current.volume = value[0] / 100
      setVolume(value[0] / 100)
    }
  }

  const formatTime = (time: number) => {
    const minutes = Math.floor(time / 60)
    const seconds = Math.floor(time % 60)
    return `${minutes}:${seconds.toString().padStart(2, '0')}`
  }

  const handleRewind = () => {
    if (videoRef.current) {
      videoRef.current.currentTime = Math.max(0, currentTime - 10)
    }
  }

  return (
    <div className={cn("relative bg-black rounded-lg overflow-hidden", className)}>
      <video
        ref={videoRef}
        src={src}
        poster={poster}
        className="w-full h-full"
        onTimeUpdate={handleTimeUpdate}
        onLoadedMetadata={() => {
          if (videoRef.current) {
            setDuration(videoRef.current.duration)
          }
        }}
        onEnded={handleVideoEnd}
        onPlay={() => setIsPlaying(true)}
        onPause={() => setIsPlaying(false)}
      />
      
      {/* Video Controls Overlay */}
      <div className="absolute bottom-0 left-0 right-0 bg-gradient-to-t from-black/80 to-transparent p-4">
        {/* Progress Bar */}
        <div className="mb-4">
          <Slider
            value={[duration ? (currentTime / duration) * 100 : 0]}
            onValueChange={handleSeek}
            max={100}
            step={0.1}
            className="w-full"
          />
        </div>
        
        {/* Control Buttons */}
        <div className="flex items-center justify-between">
          <div className="flex items-center space-x-2">
            <Button
              size="sm"
              variant="ghost"
              onClick={handlePlayPause}
              className="text-white hover:bg-white/20"
            >
              {isPlaying ? <Pause className="h-4 w-4" /> : <Play className="h-4 w-4" />}
            </Button>
            
            <Button
              size="sm"
              variant="ghost"
              onClick={handleRewind}
              className="text-white hover:bg-white/20"
            >
              <RotateCcw className="h-4 w-4" />
            </Button>
            
            <span className="text-white text-sm">
              {formatTime(currentTime)} / {formatTime(duration)}
            </span>
          </div>
          
          <div className="flex items-center space-x-2">
            <Button
              size="sm"
              variant="ghost"
              onClick={toggleMute}
              className="text-white hover:bg-white/20"
            >
              {isMuted ? <VolumeX className="h-4 w-4" /> : <Volume2 className="h-4 w-4" />}
            </Button>
            
            <div className="w-20">
              <Slider
                value={[isMuted ? 0 : volume * 100]}
                onValueChange={handleVolumeChange}
                max={100}
                step={1}
                className="w-full"
              />
            </div>
            
            <Button
              size="sm"
              variant="ghost"
              onClick={() => {
                if (videoRef.current) {
                  if (isFullscreen) {
                    document.exitFullscreen()
                  } else {
                    videoRef.current.requestFullscreen()
                  }
                  setIsFullscreen(!isFullscreen)
                }
              }}
              className="text-white hover:bg-white/20"
            >
              <Maximize className="h-4 w-4" />
            </Button>
          </div>
        </div>
      </div>
    </div>
  )
}
```

## Backend Technology Deep Dive

### 1. Express.js with TypeScript

**Robust API Architecture:**

```typescript
// server/src/app.ts
import express from 'express'
import cors from 'cors'
import helmet from 'helmet'
import rateLimit from 'express-rate-limit'
import { PrismaClient } from '@prisma/client'
import { authRouter } from './routes/auth'
import { learningRouter } from './routes/learning'
import { progressRouter } from './routes/progress'
import { analyticsRouter } from './routes/analytics'
import { errorHandler } from './middleware/errorHandler'
import { authMiddleware } from './middleware/auth'

const app = express()
const prisma = new PrismaClient()

// Security middleware
app.use(helmet())
app.use(cors({
  origin: process.env.FRONTEND_URL,
  credentials: true
}))

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // limit each IP to 100 requests per windowMs
  message: 'Too many requests from this IP, please try again later.'
})
app.use(limiter)

// Body parsing middleware
app.use(express.json({ limit: '10mb' }))
app.use(express.urlencoded({ extended: true }))

// Routes
app.use('/api/auth', authRouter)
app.use('/api/learning', authMiddleware, learningRouter)
app.use('/api/progress', authMiddleware, progressRouter)
app.use('/api/analytics', authMiddleware, analyticsRouter)

// Error handling
app.use(errorHandler)

// Graceful shutdown
process.on('SIGINT', async () => {
  await prisma.$disconnect()
  process.exit(0)
})

export default app

// server/src/routes/learning.ts
import { Router } from 'express'
import { z } from 'zod'
import { PrismaClient } from '@prisma/client'
import { validate } from '../middleware/validation'
import { asyncHandler } from '../utils/asyncHandler'

const router = Router()
const prisma = new PrismaClient()

// Get learning tracks
const getTracksSchema = z.object({
  query: z.object({
    difficulty: z.enum(['beginner', 'intermediate', 'advanced']).optional(),
    tags: z.string().optional(),
    limit: z.string().transform(Number).optional(),
    offset: z.string().transform(Number).optional(),
  })
})

router.get('/tracks', validate(getTracksSchema), asyncHandler(async (req, res) => {
  const { difficulty, tags, limit = 20, offset = 0 } = req.query

  const where = {
    ...(difficulty && { difficultyLevel: difficulty }),
    ...(tags && { tags: { hasSome: tags.split(',') } })
  }

  const [tracks, totalCount] = await Promise.all([
    prisma.learningTrack.findMany({
      where,
      include: {
        modules: {
          include: {
            lessons: {
              select: { id: true, estimatedMinutes: true }
            }
          }
        },
        _count: {
          select: { enrollments: true }
        }
      },
      take: limit,
      skip: offset,
      orderBy: { createdAt: 'desc' }
    }),
    prisma.learningTrack.count({ where })
  ])

  // Calculate derived fields
  const tracksWithMetadata = tracks.map(track => ({
    ...track,
    totalLessons: track.modules.reduce((sum, module) => sum + module.lessons.length, 0),
    totalMinutes: track.modules.reduce((sum, module) => 
      sum + module.lessons.reduce((lessonSum, lesson) => lessonSum + lesson.estimatedMinutes, 0), 0
    ),
    enrollmentCount: track._count.enrollments
  }))

  res.json({
    success: true,
    data: tracksWithMetadata,
    pagination: {
      page: Math.floor(offset / limit) + 1,
      limit,
      total: totalCount,
      totalPages: Math.ceil(totalCount / limit)
    }
  })
}))

// Get lesson content
const getLessonSchema = z.object({
  params: z.object({
    lessonId: z.string().uuid()
  })
})

router.get('/lessons/:lessonId', validate(getLessonSchema), asyncHandler(async (req, res) => {
  const { lessonId } = req.params
  const userId = req.user.id

  const lesson = await prisma.lesson.findUnique({
    where: { id: lessonId },
    include: {
      module: {
        include: {
          track: {
            select: { id: true, title: true }
          }
        }
      },
      resources: true,
      assessments: true
    }
  })

  if (!lesson) {
    return res.status(404).json({
      success: false,
      error: {
        code: 'LESSON_NOT_FOUND',
        message: 'Lesson not found'
      }
    })
  }

  // Get user's progress for this lesson
  const progress = await prisma.userProgress.findUnique({
    where: {
      userId_lessonId: {
        userId,
        lessonId
      }
    }
  })

  // Log lesson access
  await prisma.lessonAccess.create({
    data: {
      userId,
      lessonId,
      accessedAt: new Date()
    }
  })

  res.json({
    success: true,
    data: {
      ...lesson,
      userProgress: progress
    }
  })
}))

export { router as learningRouter }
```

### 2. Database Architecture with Prisma

**Comprehensive Database Schema:**

```typescript
// prisma/schema.prisma
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

model User {
  id        String   @id @default(cuid())
  email     String   @unique
  name      String
  image     String?
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt

  // Profile Information
  profile UserProfile?

  // Learning Relationships
  enrollments     Enrollment[]
  progress        UserProgress[]
  assessmentAttempts AssessmentAttempt[]
  flashcardReviews UserFlashcardReview[]
  lessonAccesses  LessonAccess[]
  achievements    UserAchievement[]

  // Social Features
  followedBy User[] @relation("UserFollows")
  following  User[] @relation("UserFollows")
  posts      Post[]
  comments   Comment[]

  @@map("users")
}

model UserProfile {
  id     String @id @default(cuid())
  userId String @unique
  user   User   @relation(fields: [userId], references: [id], onDelete: Cascade)

  bio         String?
  avatarUrl   String?
  timezone    String?
  language    String   @default("en")
  
  // Learning Preferences
  learningStyle   LearningStyle @default(MIXED)
  difficultyLevel DifficultyLevel @default(BEGINNER)
  dailyGoalMinutes Int @default(60)
  preferredSchedule Json? // Flexible schedule storage
  
  // Gamification
  totalPoints     Int @default(0)
  currentStreak   Int @default(0)
  longestStreak   Int @default(0)
  lastActiveDate  DateTime?

  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt

  @@map("user_profiles")
}

model LearningTrack {
  id          String @id @default(cuid())
  title       String
  description String
  slug        String @unique

  // Content Organization
  modules     LearningModule[]
  tags        String[]
  
  // Metadata
  difficultyLevel  DifficultyLevel
  estimatedHours   Int
  prerequisites    String[] // Array of skill/track IDs
  learningObjectives String[]
  
  // Engagement
  enrollments      Enrollment[]
  reviews          TrackReview[]
  
  // Content Management
  isPublished      Boolean @default(false)
  publishedAt      DateTime?
  authorId         String?
  
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt

  @@map("learning_tracks")
}

model LearningModule {
  id      String @id @default(cuid())
  trackId String
  track   LearningTrack @relation(fields: [trackId], references: [id], onDelete: Cascade)

  title       String
  description String
  orderIndex  Int
  isRequired  Boolean @default(true)
  
  lessons     Lesson[]
  
  estimatedHours Int
  
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt

  @@unique([trackId, orderIndex])
  @@map("learning_modules")
}

model Lesson {
  id       String @id @default(cuid())
  moduleId String
  module   LearningModule @relation(fields: [moduleId], references: [id], onDelete: Cascade)

  title       String
  description String?
  content     Json // Flexible content structure
  type        LessonType
  orderIndex  Int
  
  estimatedMinutes Int
  
  // Associated Content
  resources    Resource[]
  assessments  Assessment[]
  flashcards   Flashcard[]
  
  // User Interactions
  progress     UserProgress[]
  accesses     LessonAccess[]
  
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt

  @@unique([moduleId, orderIndex])
  @@map("lessons")
}

model UserProgress {
  id       String @id @default(cuid())
  userId   String
  user     User   @relation(fields: [userId], references: [id], onDelete: Cascade)
  lessonId String
  lesson   Lesson @relation(fields: [lessonId], references: [id], onDelete: Cascade)

  status               ProgressStatus @default(NOT_STARTED)
  progressPercentage   Int @default(0)
  timeSpentMinutes     Int @default(0)
  completedAt          DateTime?
  lastAccessedAt       DateTime @default(now())
  
  // Detailed Progress Tracking
  sectionsCompleted    String[] // Track granular progress
  bookmarks           Json? // User bookmarks within content
  notes               String?
  
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt

  @@unique([userId, lessonId])
  @@map("user_progress")
}

model Assessment {
  id       String @id @default(cuid())
  lessonId String
  lesson   Lesson @relation(fields: [lessonId], references: [id], onDelete: Cascade)

  title       String
  description String?
  questions   Json // Flexible question structure
  
  passingScore     Int @default(70)
  timeLimitMinutes Int?
  maxAttempts      Int @default(3)
  
  attempts AssessmentAttempt[]
  
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt

  @@map("assessments")
}

model AssessmentAttempt {
  id           String @id @default(cuid())
  userId       String
  user         User   @relation(fields: [userId], references: [id], onDelete: Cascade)
  assessmentId String
  assessment   Assessment @relation(fields: [assessmentId], references: [id], onDelete: Cascade)

  answers      Json // User's answers
  score        Int
  timeTakenMinutes Int
  passed       Boolean
  feedback     Json? // Detailed feedback
  
  attemptedAt DateTime @default(now())

  @@map("assessment_attempts")
}

// Spaced Repetition System
model Flashcard {
  id       String @id @default(cuid())
  lessonId String
  lesson   Lesson @relation(fields: [lessonId], references: [id], onDelete: Cascade)

  frontContent String
  backContent  String
  tags         String[]
  
  difficultyLevel Int @default(1)
  
  reviews UserFlashcardReview[]
  
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt

  @@map("flashcards")
}

model UserFlashcardReview {
  id          String @id @default(cuid())
  userId      String
  user        User   @relation(fields: [userId], references: [id], onDelete: Cascade)
  flashcardId String
  flashcard   Flashcard @relation(fields: [flashcardId], references: [id], onDelete: Cascade)

  easeFactor      Float @default(2.5)
  interval        Int   @default(1)
  repetitions     Int   @default(0)
  nextReviewDate  DateTime
  
  qualityRating   Int // 0-5 scale (SuperMemo-2)
  reviewTime      Int // Time spent reviewing (seconds)
  
  lastReviewedAt  DateTime @default(now())

  @@unique([userId, flashcardId])
  @@map("user_flashcard_reviews")
}

// Enums
enum LearningStyle {
  VISUAL
  AUDITORY
  KINESTHETIC
  READING_WRITING
  MIXED
}

enum DifficultyLevel {
  BEGINNER
  INTERMEDIATE
  ADVANCED
}

enum LessonType {
  VIDEO
  ARTICLE
  EXERCISE
  QUIZ
  PROJECT
  DISCUSSION
}

enum ProgressStatus {
  NOT_STARTED
  IN_PROGRESS
  COMPLETED
  PAUSED
}
```

## Philippine EdTech Technology Considerations

### 1. Connectivity Optimization

**Offline-First Architecture:**

```typescript
// utils/offline-manager.ts
interface OfflineManager {
  // Content Synchronization
  syncContent(): Promise<void>
  downloadContentForOffline(contentIds: string[]): Promise<void>
  getOfflineContent(): Promise<OfflineContent[]>
  
  // Progress Synchronization
  syncProgress(): Promise<void>
  storeProgressOffline(progress: UserProgress): void
  
  // Conflict Resolution
  resolveConflicts(conflicts: SyncConflict[]): Promise<void>
}

class PWAOfflineManager implements OfflineManager {
  private db: IDBDatabase
  private syncQueue: SyncOperation[] = []

  constructor() {
    this.initIndexedDB()
    this.setupServiceWorker()
  }

  async syncContent(): Promise<void> {
    if (!navigator.onLine) return

    try {
      // Sync pending operations
      for (const operation of this.syncQueue) {
        await this.executeSyncOperation(operation)
      }
      
      // Download new content
      const newContent = await fetch('/api/content/sync').then(r => r.json())
      await this.storeContentOffline(newContent)
      
      this.syncQueue = []
    } catch (error) {
      console.error('Sync failed:', error)
    }
  }

  async downloadContentForOffline(contentIds: string[]): Promise<void> {
    const content = await Promise.all(
      contentIds.map(id => fetch(`/api/content/${id}`).then(r => r.json()))
    )

    // Store in IndexedDB
    const transaction = this.db.transaction(['content'], 'readwrite')
    const store = transaction.objectStore('content')
    
    for (const item of content) {
      await store.put(item)
    }
  }

  private async initIndexedDB(): Promise<void> {
    return new Promise((resolve, reject) => {
      const request = indexedDB.open('PLMS_Offline', 1)
      
      request.onerror = () => reject(request.error)
      request.onsuccess = () => {
        this.db = request.result
        resolve()
      }
      
      request.onupgradeneeded = () => {
        const db = request.result
        
        // Create object stores
        if (!db.objectStoreNames.contains('content')) {
          db.createObjectStore('content', { keyPath: 'id' })
        }
        
        if (!db.objectStoreNames.contains('progress')) {
          db.createObjectStore('progress', { keyPath: 'id' })
        }
        
        if (!db.objectStoreNames.contains('syncQueue')) {
          db.createObjectStore('syncQueue', { keyPath: 'id' })
        }
      }
    })
  }
}

// Service Worker for Offline Caching
// public/sw.js
const CACHE_NAME = 'plms-v1'
const STATIC_CACHE = 'plms-static-v1'
const DYNAMIC_CACHE = 'plms-dynamic-v1'

const STATIC_ASSETS = [
  '/',
  '/offline',
  '/manifest.json',
  // CSS and JS bundles
  '/_next/static/css/',
  '/_next/static/js/',
  // Critical images
  '/icons/icon-192x192.png',
  '/icons/icon-512x512.png'
]

// Install event - cache static assets
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(STATIC_CACHE)
      .then(cache => cache.addAll(STATIC_ASSETS))
      .then(() => self.skipWaiting())
  )
})

// Fetch event - serve from cache with network fallback
self.addEventListener('fetch', (event) => {
  const { request } = event
  
  // Handle API requests
  if (request.url.includes('/api/')) {
    event.respondWith(
      fetch(request)
        .then(response => {
          // Cache successful API responses
          if (response.ok) {
            const responseClone = response.clone()
            caches.open(DYNAMIC_CACHE)
              .then(cache => cache.put(request, responseClone))
          }
          return response
        })
        .catch(() => {
          // Serve from cache if network fails
          return caches.match(request)
            .then(cachedResponse => {
              if (cachedResponse) {
                return cachedResponse
              }
              // Return offline page for failed requests
              return caches.match('/offline')
            })
        })
    )
    return
  }

  // Handle page requests
  event.respondWith(
    caches.match(request)
      .then(cachedResponse => {
        if (cachedResponse) {
          return cachedResponse
        }
        
        return fetch(request)
          .then(response => {
            // Cache successful responses
            if (response.ok) {
              const responseClone = response.clone()
              caches.open(DYNAMIC_CACHE)
                .then(cache => cache.put(request, responseClone))
            }
            return response
          })
          .catch(() => {
            // Serve offline page for failed page requests
            return caches.match('/offline')
          })
      })
  )
})
```

### 2. Payment Integration for Philippine Market

**Local Payment Gateway Integration:**

```typescript
// lib/payments/paymongo.ts
import axios from 'axios'

interface PayMongoConfig {
  secretKey: string
  publicKey: string
  webhookSecret: string
}

class PayMongoPaymentService {
  private config: PayMongoConfig
  private baseURL = 'https://api.paymongo.com/v1'

  constructor(config: PayMongoConfig) {
    this.config = config
  }

  async createGCashSource(amount: number, description: string): Promise<PaymentSource> {
    const response = await axios.post(
      `${this.baseURL}/sources`,
      {
        data: {
          type: 'source',
          attributes: {
            type: 'gcash',
            amount: amount * 100, // Convert to centavos
            currency: 'PHP',
            description,
            redirect: {
              success: `${process.env.FRONTEND_URL}/payment/success`,
              failed: `${process.env.FRONTEND_URL}/payment/failed`
            }
          }
        }
      },
      {
        headers: {
          'Authorization': `Basic ${Buffer.from(this.config.secretKey + ':').toString('base64')}`,
          'Content-Type': 'application/json'
        }
      }
    )

    return response.data.data
  }

  async createPayMayaSource(amount: number, description: string): Promise<PaymentSource> {
    const response = await axios.post(
      `${this.baseURL}/sources`,
      {
        data: {
          type: 'source',
          attributes: {
            type: 'paymaya',
            amount: amount * 100,
            currency: 'PHP',
            description,
            redirect: {
              success: `${process.env.FRONTEND_URL}/payment/success`,
              failed: `${process.env.FRONTEND_URL}/payment/failed`
            }
          }
        }
      },
      {
        headers: {
          'Authorization': `Basic ${Buffer.from(this.config.secretKey + ':').toString('base64')}`,
          'Content-Type': 'application/json'
        }
      }
    )

    return response.data.data
  }

  async createBankTransferSource(amount: number, description: string): Promise<PaymentSource> {
    const response = await axios.post(
      `${this.baseURL}/sources`,
      {
        data: {
          type: 'source',
          attributes: {
            type: 'online_banking',
            amount: amount * 100,
            currency: 'PHP',
            description,
            redirect: {
              success: `${process.env.FRONTEND_URL}/payment/success`,
              failed: `${process.env.FRONTEND_URL}/payment/failed`
            }
          }
        }
      },
      {
        headers: {
          'Authorization': `Basic ${Buffer.from(this.config.secretKey + ':').toString('base64')}`,
          'Content-Type': 'application/json'
        }
      }
    )

    return response.data.data
  }

  async handleWebhook(payload: string, signature: string): Promise<WebhookEvent> {
    // Verify webhook signature
    const crypto = require('crypto')
    const computedSignature = crypto
      .createHmac('sha256', this.config.webhookSecret)
      .update(payload)
      .digest('hex')

    if (computedSignature !== signature) {
      throw new Error('Invalid webhook signature')
    }

    return JSON.parse(payload)
  }
}

// API route for handling payments
// pages/api/payments/create.ts
import type { NextApiRequest, NextApiResponse } from 'next'
import { z } from 'zod'
import { PayMongoPaymentService } from '@/lib/payments/paymongo'

const createPaymentSchema = z.object({
  amount: z.number().min(20).max(50000), // PHP 20 to 50,000
  method: z.enum(['gcash', 'paymaya', 'online_banking']),
  description: z.string().min(1).max(255),
  courseId: z.string().optional(),
  subscriptionType: z.enum(['monthly', 'annual']).optional()
})

export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse
) {
  if (req.method !== 'POST') {
    return res.status(405).json({ message: 'Method not allowed' })
  }

  try {
    const { amount, method, description, courseId, subscriptionType } = createPaymentSchema.parse(req.body)
    
    const paymentService = new PayMongoPaymentService({
      secretKey: process.env.PAYMONGO_SECRET_KEY!,
      publicKey: process.env.PAYMONGO_PUBLIC_KEY!,
      webhookSecret: process.env.PAYMONGO_WEBHOOK_SECRET!
    })

    let source: PaymentSource

    switch (method) {
      case 'gcash':
        source = await paymentService.createGCashSource(amount, description)
        break
      case 'paymaya':
        source = await paymentService.createPayMayaSource(amount, description)
        break
      case 'online_banking':
        source = await paymentService.createBankTransferSource(amount, description)
        break
      default:
        return res.status(400).json({ message: 'Invalid payment method' })
    }

    // Store payment record in database
    await prisma.payment.create({
      data: {
        sourceId: source.id,
        amount,
        currency: 'PHP',
        method,
        status: 'pending',
        description,
        courseId,
        subscriptionType,
        userId: req.user.id // From auth middleware
      }
    })

    res.json({
      success: true,
      data: {
        checkoutUrl: source.attributes.redirect.checkout_url,
        sourceId: source.id
      }
    })
  } catch (error) {
    console.error('Payment creation error:', error)
    res.status(500).json({
      success: false,
      error: {
        code: 'PAYMENT_CREATION_FAILED',
        message: 'Failed to create payment'
      }
    })
  }
}
```

---

This technology stack analysis provides a comprehensive overview of modern tools and frameworks optimized for building Personal Learning Management Systems, with specific considerations for the Philippine market including connectivity challenges and local payment integration.

---

← [Content Management Strategy](./content-management-strategy.md) | [Philippine EdTech Business Strategy →](./philippine-edtech-business-strategy.md)