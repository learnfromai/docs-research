# Conditional Types Mastery - Advanced TypeScript Techniques

## 🎯 Overview

Conditional types are one of TypeScript's most powerful features, enabling dynamic type generation based on type relationships. This document provides comprehensive coverage of conditional type patterns essential for building type-safe EdTech platforms and competing in senior-level remote positions.

## 🔧 Fundamental Conditional Type Patterns

### Basic Syntax and Mechanics
```typescript
// Basic conditional type syntax: T extends U ? X : Y
type IsString<T> = T extends string ? true : false

// Examples
type Test1 = IsString<string>    // true
type Test2 = IsString<number>    // false
type Test3 = IsString<'hello'>   // true (string literal extends string)
```

### The `infer` Keyword
```typescript
// Extract types from complex structures using infer
type GetReturnType<T> = T extends (...args: any[]) => infer R ? R : never

// Examples
type StringReturn = GetReturnType<() => string>        // string
type NumberReturn = GetReturnType<(x: number) => number> // number
type VoidReturn = GetReturnType<() => void>            // void

// Extract array element types
type GetArrayElement<T> = T extends (infer U)[] ? U : never

type StringArray = GetArrayElement<string[]>           // string
type NumberArray = GetArrayElement<number[]>           // number
type MixedArray = GetArrayElement<(string | number)[]> // string | number
```

## 📚 EdTech Platform Application Patterns

### 1. Dynamic API Response Types
```typescript
// EdTech entities
interface Student {
  id: string
  name: string
  email: string
  grade: number
  enrolledCourses: Course[]
}

interface Course {
  id: string
  title: string
  description: string
  modules: Module[]
  instructor: Instructor
}

interface Module {
  id: string
  title: string
  lessons: Lesson[]
  assessments: Assessment[]
}

interface Lesson {
  id: string
  title: string
  content: string
  videoUrl?: string
  duration: number
}

// Conditional type for API responses with error handling
type ApiResult<TData, TError = string> = 
  | { success: true; data: TData }
  | { success: false; error: TError }

// Enhanced error types based on operation
type OperationError<TOperation extends string> = 
  TOperation extends 'fetch' ? 'NOT_FOUND' | 'ACCESS_DENIED' :
  TOperation extends 'create' ? 'VALIDATION_ERROR' | 'DUPLICATE_ENTRY' :
  TOperation extends 'update' ? 'NOT_FOUND' | 'VALIDATION_ERROR' | 'VERSION_CONFLICT' :
  TOperation extends 'delete' ? 'NOT_FOUND' | 'CANNOT_DELETE' :
  'UNKNOWN_ERROR'

// Usage in API design
type FetchStudentResult = ApiResult<Student, OperationError<'fetch'>>
type CreateCourseResult = ApiResult<Course, OperationError<'create'>>
type UpdateModuleResult = ApiResult<Module, OperationError<'update'>>

// Implementation example
async function fetchStudent(id: string): Promise<FetchStudentResult> {
  try {
    const student = await database.student.findUnique({ where: { id } })
    if (!student) {
      return { success: false, error: 'NOT_FOUND' }
    }
    return { success: true, data: student }
  } catch (error) {
    return { success: false, error: 'ACCESS_DENIED' }
  }
}
```

### 2. Progressive Data Loading Types
```typescript
// Loading states for different data types
type LoadingState<T> = 
  | { status: 'idle' }
  | { status: 'loading' }
  | { status: 'success'; data: T }
  | { status: 'error'; error: string }

// Enhanced loading with relationship awareness
type EntityWithRelations<TEntity, TRelations extends keyof TEntity> = 
  TEntity & {
    [K in TRelations]: TEntity[K] extends any[] 
      ? LoadingState<TEntity[K]>
      : LoadingState<TEntity[K]>
  }

// Student with progressively loaded relations
type StudentWithRelations = EntityWithRelations<Student, 'enrolledCourses'>
// Result: Student & {
//   enrolledCourses: LoadingState<Course[]>
// }

// Dynamic loading based on user preferences
type UserPreferences = {
  preloadCourses: boolean
  preloadProgress: boolean
  preloadAssessments: boolean
}

type ConditionallyLoadedStudent<TPrefs extends UserPreferences> = Student & {
  enrolledCourses: TPrefs['preloadCourses'] extends true ? Course[] : LoadingState<Course[]>
  progress: TPrefs['preloadProgress'] extends true ? StudentProgress : LoadingState<StudentProgress>
  assessments: TPrefs['preloadAssessments'] extends true ? Assessment[] : LoadingState<Assessment[]>
}
```

### 3. Form Validation and Type Safety
```typescript
// Validation result types based on field type
type ValidationResult<T> = 
  T extends string ? 'REQUIRED' | 'TOO_SHORT' | 'TOO_LONG' | 'INVALID_FORMAT' :
  T extends number ? 'REQUIRED' | 'TOO_SMALL' | 'TOO_LARGE' | 'NOT_INTEGER' :
  T extends boolean ? never : // booleans don't typically need validation
  T extends Date ? 'REQUIRED' | 'INVALID_DATE' | 'FUTURE_DATE' | 'PAST_DATE' :
  'UNKNOWN_TYPE'

// Form field configuration with validation
interface FormFieldConfig<T> {
  value: T
  required: boolean
  validator?: (value: T) => ValidationResult<T> | null
}

// Dynamic form type generation
type FormConfig<T> = {
  [K in keyof T]: FormFieldConfig<T[K]>
}

// Student registration form
interface StudentRegistrationData {
  name: string
  email: string
  birthDate: Date
  grade: number
  parentConsent: boolean
}

type StudentRegistrationForm = FormConfig<StudentRegistrationData>
// Result: {
//   name: FormFieldConfig<string>
//   email: FormFieldConfig<string>
//   birthDate: FormFieldConfig<Date>
//   grade: FormFieldConfig<number>
//   parentConsent: FormFieldConfig<boolean>
// }

// Validation implementation
const validateStudentForm = (
  form: StudentRegistrationForm
): Record<keyof StudentRegistrationData, ValidationResult<any> | null> => {
  return {
    name: form.name.value.length < 2 ? 'TOO_SHORT' : null,
    email: /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(form.email.value) ? null : 'INVALID_FORMAT',
    birthDate: form.birthDate.value > new Date() ? 'FUTURE_DATE' : null,
    grade: form.grade.value < 1 || form.grade.value > 12 ? 'TOO_SMALL' : null,
    parentConsent: null // boolean fields don't need validation
  }
}
```

## 🚀 Advanced Conditional Type Patterns

### 1. Distributed Conditional Types
```typescript
// When T is a union, conditional types distribute over each member
type ToArray<T> = T extends any ? T[] : never

type UnionToArrays = ToArray<string | number | boolean>
// Result: string[] | number[] | boolean[] (distributed)

// Practical example: Event handling in EdTech platform
type StudentEvent = 
  | { type: 'ENROLLED'; courseId: string }
  | { type: 'COMPLETED_LESSON'; lessonId: string; duration: number }
  | { type: 'FAILED_ASSESSMENT'; assessmentId: string; score: number }
  | { type: 'UPGRADED_PLAN'; planId: string }

// Extract events by type
type EventsOfType<TEvents, TType extends string> = 
  TEvents extends { type: TType } ? TEvents : never

type EnrollmentEvents = EventsOfType<StudentEvent, 'ENROLLED'>
// Result: { type: 'ENROLLED'; courseId: string }

type CompletionEvents = EventsOfType<StudentEvent, 'COMPLETED_LESSON'>
// Result: { type: 'COMPLETED_LESSON'; lessonId: string; duration: number }

// Event handler mapping
type EventHandlers<TEvents> = {
  [K in TEvents as K extends { type: infer T } ? T : never]: 
    (event: K) => void
}

type StudentEventHandlers = EventHandlers<StudentEvent>
// Result: {
//   ENROLLED: (event: { type: 'ENROLLED'; courseId: string }) => void
//   COMPLETED_LESSON: (event: { type: 'COMPLETED_LESSON'; lessonId: string; duration: number }) => void
//   FAILED_ASSESSMENT: (event: { type: 'FAILED_ASSESSMENT'; assessmentId: string; score: number }) => void
//   UPGRADED_PLAN: (event: { type: 'UPGRADED_PLAN'; planId: string }) => void
// }
```

### 2. Recursive Conditional Types
```typescript
// Deep type transformations for nested EdTech data structures
type DeepPartial<T> = {
  [P in keyof T]?: T[P] extends object 
    ? T[P] extends any[]
      ? T[P]
      : DeepPartial<T[P]>
    : T[P]
}

// Apply to complex course structure
type PartialCourse = DeepPartial<Course>
// Result: All properties are optional, including nested ones

// Deep readonly for immutable state management
type DeepReadonly<T> = {
  readonly [P in keyof T]: T[P] extends object
    ? T[P] extends any[]
      ? ReadonlyArray<DeepReadonly<T[P][number]>>
      : DeepReadonly<T[P]>
    : T[P]
}

// Immutable course state
type ImmutableCourse = DeepReadonly<Course>

// Path-based property extraction (advanced)
type PathsToStringProps<T> = T extends string 
  ? []
  : {
      [K in Extract<keyof T, string>]: T[K] extends string
        ? [K]
        : T[K] extends object
        ? [K, ...PathsToStringProps<T[K]>]
        : never
    }[Extract<keyof T, string>]

type CourseStringPaths = PathsToStringProps<Course>
// Result: Union of all paths to string properties like ['title'] | ['description'] | ['modules', number, 'title']
```

### 3. Performance-Optimized Conditional Types
```typescript
// Tail-call optimized recursive types to prevent "Type instantiation is excessively deep"
type Flatten<T, Depth extends number = 3> = 
  Depth extends 0 
    ? T
    : T extends ReadonlyArray<infer U>
    ? Flatten<U, Prev<Depth>>
    : T

type Prev<T extends number> = 
  T extends 4 ? 3 :
  T extends 3 ? 2 :
  T extends 2 ? 1 :
  T extends 1 ? 0 : 0

// Efficient union filtering
type FilterUnion<T, U> = T extends U ? T : never

// Example: Filter numeric assessment scores
type AssessmentScore = 0 | 25 | 50 | 75 | 100 | 'incomplete' | 'not_attempted'
type NumericScores = FilterUnion<AssessmentScore, number>
// Result: 0 | 25 | 50 | 75 | 100

// Conditional type caching for complex computations
type ComplexTransform<T> = 
  T extends Student ? TransformedStudent :
  T extends Course ? TransformedCourse :
  T extends Module ? TransformedModule :
  never

// Cache the results with type aliases
type TransformedStudent = { /* complex transformation */ }
type TransformedCourse = { /* complex transformation */ }
type TransformedModule = { /* complex transformation */ }
```

## 🎯 Real-World Use Cases

### 1. Database Query Builder with Type Safety
```typescript
// Dynamic query builder using conditional types
interface QueryBuilder<TEntity> {
  where<TField extends keyof TEntity>(
    field: TField,
    operator: TEntity[TField] extends string 
      ? 'equals' | 'contains' | 'startsWith' | 'endsWith'
      : TEntity[TField] extends number
      ? 'equals' | 'gt' | 'gte' | 'lt' | 'lte'
      : TEntity[TField] extends boolean
      ? 'equals'
      : TEntity[TField] extends Date
      ? 'equals' | 'before' | 'after'
      : 'equals',
    value: TEntity[TField]
  ): QueryBuilder<TEntity>

  select<TFields extends keyof TEntity>(
    ...fields: TFields[]
  ): QueryBuilder<Pick<TEntity, TFields>>

  execute(): Promise<TEntity[]>
}

// Usage example
const students = await new QueryBuilder<Student>()
  .where('grade', 'gte', 9)        // Only valid operators for number
  .where('name', 'contains', 'John') // Only valid operators for string
  .select('id', 'name', 'email')    // Type-safe field selection
  .execute()
// Result type: Pick<Student, 'id' | 'name' | 'email'>[]
```

### 2. Permission System with Role-Based Access
```typescript
// Role-based permission system
type Role = 'student' | 'instructor' | 'admin' | 'parent'
type Resource = 'course' | 'lesson' | 'assessment' | 'student_data' | 'gradebook'
type Action = 'read' | 'write' | 'delete' | 'create'

// Define permissions matrix
type RolePermissions = {
  student: {
    course: 'read'
    lesson: 'read'
    assessment: 'read' | 'write'
    student_data: 'read'
    gradebook: never
  }
  instructor: {
    course: 'read' | 'write'
    lesson: 'read' | 'write' | 'create'
    assessment: 'read' | 'write' | 'create'
    student_data: 'read'
    gradebook: 'read' | 'write'
  }
  admin: {
    course: 'read' | 'write' | 'create' | 'delete'
    lesson: 'read' | 'write' | 'create' | 'delete'
    assessment: 'read' | 'write' | 'create' | 'delete'
    student_data: 'read' | 'write' | 'delete'
    gradebook: 'read' | 'write' | 'delete'
  }
  parent: {
    course: 'read'
    lesson: never
    assessment: never
    student_data: 'read'
    gradebook: 'read'
  }
}

// Check if action is allowed for role and resource
type CanPerformAction<
  TRole extends Role,
  TResource extends Resource,
  TAction extends Action
> = TAction extends RolePermissions[TRole][TResource] ? true : false

// Usage examples
type StudentCanReadCourse = CanPerformAction<'student', 'course', 'read'>      // true
type StudentCanDeleteCourse = CanPerformAction<'student', 'course', 'delete'>  // false
type InstructorCanWriteLesson = CanPerformAction<'instructor', 'lesson', 'write'> // true

// Runtime permission checker
function hasPermission<
  TRole extends Role,
  TResource extends Resource,
  TAction extends Action
>(
  role: TRole,
  resource: TResource,
  action: TAction
): CanPerformAction<TRole, TResource, TAction> {
  const permissions = rolePermissions[role]
  const resourcePermissions = permissions[resource]
  return (resourcePermissions as string[]).includes(action) as CanPerformAction<TRole, TResource, TAction>
}
```

### 3. Course Content Pipeline with Type Transformations
```typescript
// Content processing pipeline with type transformations
type ContentType = 'video' | 'text' | 'quiz' | 'assignment' | 'discussion'

interface BaseContent {
  id: string
  title: string
  type: ContentType
  createdAt: Date
}

// Specialized content types
interface VideoContent extends BaseContent {
  type: 'video'
  videoUrl: string
  duration: number
  transcript?: string
}

interface TextContent extends BaseContent {
  type: 'text'
  content: string
  readingTime: number
}

interface QuizContent extends BaseContent {
  type: 'quiz'
  questions: QuizQuestion[]
  timeLimit?: number
  attempts: number
}

type Content = VideoContent | TextContent | QuizContent

// Processing pipeline based on content type
type ProcessingResult<T extends Content> = 
  T extends VideoContent ? {
    thumbnailUrl: string
    chapters: VideoChapter[]
    captions: Caption[]
  } :
  T extends TextContent ? {
    wordCount: number
    summary: string
    keywords: string[]
  } :
  T extends QuizContent ? {
    averageScore: number
    completionRate: number
    commonMistakes: string[]
  } :
  never

// Content processor with type-safe results
class ContentProcessor {
  async process<T extends Content>(content: T): Promise<ProcessingResult<T>> {
    switch (content.type) {
      case 'video':
        return {
          thumbnailUrl: 'generated-thumbnail.jpg',
          chapters: [],
          captions: []
        } as ProcessingResult<T>
      
      case 'text':
        return {
          wordCount: content.content.split(' ').length,
          summary: 'Generated summary',
          keywords: ['keyword1', 'keyword2']
        } as ProcessingResult<T>
      
      case 'quiz':
        return {
          averageScore: 85,
          completionRate: 0.92,
          commonMistakes: ['Common mistake 1']
        } as ProcessingResult<T>
      
      default:
        throw new Error('Unknown content type')
    }
  }
}
```

## 🧪 Testing Conditional Types

### Type-Level Testing
```typescript
// Test utilities for conditional types
type Expect<T extends true> = T
type Equal<X, Y> = (<T>() => T extends X ? 1 : 2) extends (<T>() => T extends Y ? 1 : 2) ? true : false
type NotEqual<X, Y> = Equal<X, Y> extends true ? false : true

// Test API response types
type TestApiResult = Expect<Equal<
  ApiResult<Student, 'NOT_FOUND'>,
  | { success: true; data: Student }
  | { success: false; error: 'NOT_FOUND' }
>>

// Test permission system
type TestStudentPermissions = Expect<Equal<
  CanPerformAction<'student', 'course', 'read'>,
  true
>>

type TestStudentCannotDelete = Expect<Equal<
  CanPerformAction<'student', 'course', 'delete'>,
  false
>>

// Test content processing
type TestVideoProcessing = Expect<Equal<
  ProcessingResult<VideoContent>,
  {
    thumbnailUrl: string
    chapters: VideoChapter[]
    captions: Caption[]
  }
>>
```

### Runtime Testing
```typescript
import { describe, it, expect } from 'vitest'

describe('Conditional Types in Runtime', () => {
  it('should handle API responses correctly', async () => {
    const result = await fetchStudent('student-123')
    
    if (result.success) {
      // TypeScript knows result.data is Student
      expect(result.data).toHaveProperty('id')
      expect(result.data).toHaveProperty('name')
      expect(result.data).toHaveProperty('email')
    } else {
      // TypeScript knows result.error is OperationError<'fetch'>
      expect(['NOT_FOUND', 'ACCESS_DENIED']).toContain(result.error)
    }
  })

  it('should process different content types correctly', async () => {
    const processor = new ContentProcessor()
    
    const videoContent: VideoContent = {
      id: 'video-1',
      title: 'Intro to TypeScript',
      type: 'video',
      createdAt: new Date(),
      videoUrl: 'video.mp4',
      duration: 600
    }
    
    const result = await processor.process(videoContent)
    
    // TypeScript knows result has video-specific properties
    expect(result).toHaveProperty('thumbnailUrl')
    expect(result).toHaveProperty('chapters')
    expect(result).toHaveProperty('captions')
    
    // TypeScript prevents accessing properties from other content types
    // expect(result).toHaveProperty('wordCount') // ❌ Would be TypeScript error
  })
})
```

## 📊 Performance Considerations

### Compilation Performance Tips
```typescript
// ✅ Cache complex conditional types
type ComplexCondition<T> = /* complex logic */
type CachedResult<T> = ComplexCondition<T>

// ✅ Use type aliases instead of repeating complex conditions
type IsValidStudent<T> = T extends { id: string; name: string; email: string } ? true : false
type ValidStudent = IsValidStudent<Student>

// ❌ Avoid deeply nested conditional types
type BadNesting<T> = 
  T extends string ? 
    T extends `${infer P}@${infer D}` ? 
      D extends 'gmail.com' ? 
        'gmail' : 
        D extends 'yahoo.com' ? 
          'yahoo' : 
          'other' 
        : 'invalid' 
    : 'not-string'

// ✅ Break down into smaller, composable types
type ExtractDomain<T extends string> = T extends `${string}@${infer D}` ? D : never
type ClassifyDomain<T extends string> = 
  T extends 'gmail.com' ? 'gmail' :
  T extends 'yahoo.com' ? 'yahoo' :
  'other'

type ClassifyEmail<T extends string> = ClassifyDomain<ExtractDomain<T>>
```

---

### 📖 Document Navigation

| Previous | Current | Next |
|----------|---------|------|
| [Best Practices](./best-practices.md) | **Conditional Types Mastery** | [Mapped Types & Utilities](./mapped-types-utilities.md) |

---

*Last updated: January 2025*  
*Essential patterns for EdTech platforms and senior-level TypeScript development*