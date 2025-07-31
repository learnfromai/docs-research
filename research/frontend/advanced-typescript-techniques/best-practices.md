# Best Practices - Advanced TypeScript Techniques

## 🎯 Overview

This document outlines industry best practices for advanced TypeScript development, compiled from leading tech companies (Google, Microsoft, Airbnb, Stripe) and the TypeScript community. These practices are essential for remote work opportunities and building scalable EdTech platforms.

## 🏗️ Type Design Principles

### 1. Design for Discoverability
```typescript
// ❌ Poor: Unclear purpose and usage
type Util<T, K> = T extends K ? T : never

// ✅ Good: Self-documenting with clear naming
type ExtractMatchingTypes<TUnion, TMatch> = TUnion extends TMatch ? TUnion : never

// ✅ Better: Include documentation
/**
 * Extracts types from a union that are assignable to the target type.
 * Useful for filtering union types based on structure.
 * 
 * @example
 * type StringOrNumber = ExtractMatchingTypes<string | number | boolean, string>
 * // Result: string
 */
type ExtractMatchingTypes<TUnion, TMatch> = TUnion extends TMatch ? TUnion : never
```

### 2. Prefer Composition Over Complex Inheritance
```typescript
// ❌ Avoid: Deep inheritance hierarchies
interface BaseEntity {
  id: string
}

interface TimestampedEntity extends BaseEntity {
  createdAt: Date
  updatedAt: Date
}

interface SoftDeletableEntity extends TimestampedEntity {
  deletedAt?: Date
}

interface AuditableEntity extends SoftDeletableEntity {
  createdBy: string
  updatedBy: string
}

// ✅ Prefer: Composable mixins
interface WithId {
  id: string
}

interface WithTimestamps {
  createdAt: Date
  updatedAt: Date
}

interface WithSoftDelete {
  deletedAt?: Date
}

interface WithAudit {
  createdBy: string
  updatedBy: string
}

// Compose as needed
type Student = WithId & WithTimestamps & {
  name: string
  email: string
  grade: number
}

type Course = WithId & WithTimestamps & WithSoftDelete & WithAudit & {
  title: string
  description: string
  modules: Module[]
}
```

## 🔧 Conditional Types Best Practices

### 1. Use Meaningful Conditional Patterns
```typescript
// ❌ Poor: Complex nested conditions
type Complex<T> = T extends string 
  ? T extends `${infer P}@${infer D}` 
    ? D extends 'gmail.com' | 'yahoo.com' 
      ? `Valid email: ${T}` 
      : `Invalid domain: ${D}`
    : `Invalid format: ${T}`
  : never

// ✅ Good: Break down into smaller, focused types
type IsEmail<T extends string> = T extends `${string}@${string}` ? true : false
type IsTrustedDomain<T extends string> = T extends `${string}@${'gmail.com' | 'yahoo.com' | 'company.edu'}` ? true : false

type ValidateEmail<T extends string> = 
  IsEmail<T> extends true
    ? IsTrustedDomain<T> extends true
      ? `Valid: ${T}`
      : `Untrusted domain: ${T}`
    : `Invalid format: ${T}`
```

### 2. Handle Edge Cases Explicitly
```typescript
// ✅ Good: Explicit handling of undefined/null
type SafeExtract<T, K extends keyof T> = 
  T extends undefined | null 
    ? never 
    : T[K]

// ✅ Good: Default fallbacks for union types
type GetProperty<T, K extends string, Default = never> = 
  T extends Record<K, infer V> ? V : Default

// EdTech example: Safe property access
interface StudentProfile {
  basic: {
    name: string
    email: string
  }
  academic?: {
    grade: number
    gpa: number
  }
  preferences?: {
    theme: 'light' | 'dark'
    notifications: boolean
  }
}

type AcademicInfo = GetProperty<StudentProfile, 'academic', {}>
// Result: { grade: number; gpa: number } | {}
```

## 🗺️ Mapped Types Best Practices

### 1. Use Key Remapping for Better APIs
```typescript
// ✅ Excellent: Create intuitive API surfaces
type CreateFormHandlers<T> = {
  [K in keyof T as `handle${Capitalize<string & K>}Change`]: (value: T[K]) => void
} & {
  [K in keyof T as `validate${Capitalize<string & K>}`]: (value: T[K]) => string | undefined
}

// Usage for EdTech forms
interface CourseForm {
  title: string
  description: string
  duration: number
  difficulty: 'beginner' | 'intermediate' | 'advanced'
}

type CourseFormHandlers = CreateFormHandlers<CourseForm>
// Result: {
//   handleTitleChange: (value: string) => void
//   handleDescriptionChange: (value: string) => void
//   handleDurationChange: (value: number) => void
//   handleDifficultyChange: (value: 'beginner' | 'intermediate' | 'advanced') => void
//   validateTitle: (value: string) => string | undefined
//   validateDescription: (value: string) => string | undefined
//   // ... etc
// }
```

### 2. Preserve Optional Properties Correctly
```typescript
// ❌ Poor: Loses optional property information
type BadPartial<T> = {
  [K in keyof T]: T[K] | undefined
}

// ✅ Good: Preserves optionality semantics
type GoodPartial<T> = {
  [K in keyof T]?: T[K]
}

// ✅ Advanced: Conditional optionality
type PartialExcept<T, K extends keyof T> = Partial<T> & Pick<T, K>

// EdTech example: Student update requires ID but other fields optional
interface Student {
  id: string
  name: string
  email: string
  grade: number
  enrollmentDate: Date
}

type StudentUpdate = PartialExcept<Student, 'id'>
// Result: {
//   id: string                    // Required
//   name?: string                 // Optional
//   email?: string               // Optional
//   grade?: number               // Optional
//   enrollmentDate?: Date        // Optional
// }
```

## 🔤 Template Literal Types Best Practices

### 1. Build Composable String Types
```typescript
// ✅ Good: Modular string type building
type HTTPMethod = 'GET' | 'POST' | 'PUT' | 'DELETE'
type APIVersion = 'v1' | 'v2'
type ResourceType = 'users' | 'courses' | 'modules' | 'lessons' | 'assessments'

// Composable path building
type APIPath = `/api/${APIVersion}/${ResourceType}`
type APIEndpoint<Method extends HTTPMethod = HTTPMethod> = `${Method} ${APIPath}`

// Dynamic parameters
type WithId<Path extends string> = `${Path}/:id`
type WithQuery<Path extends string> = `${Path}?${string}`

// Usage examples
type GetStudents = APIEndpoint<'GET'>          // "GET /api/v1/users" | "GET /api/v1/courses" | ...
type StudentById = WithId<'/api/v1/users'>     // "/api/v1/users/:id"
type SearchCourses = WithQuery<'/api/v1/courses'> // "/api/v1/courses?${string}"
```

### 2. Type-Safe Configuration
```typescript
// ✅ Excellent: Type-safe environment configuration
type EnvironmentKey = 'development' | 'staging' | 'production'
type ConfigKey = 'DATABASE_URL' | 'API_KEY' | 'JWT_SECRET' | 'REDIS_URL'

type EnvVarName<
  TEnv extends EnvironmentKey,
  TKey extends ConfigKey
> = `${Uppercase<TEnv>}_${TKey}`

// Generated environment variable names
type DevDatabaseUrl = EnvVarName<'development', 'DATABASE_URL'>
// Result: "DEVELOPMENT_DATABASE_URL"

type ProdApiKey = EnvVarName<'production', 'API_KEY'>
// Result: "PRODUCTION_API_KEY"

// Type-safe configuration object
type EnvironmentConfig<TEnv extends EnvironmentKey> = {
  [TKey in ConfigKey as EnvVarName<TEnv, TKey>]: string
}

type DevelopmentConfig = EnvironmentConfig<'development'>
// Result: {
//   DEVELOPMENT_DATABASE_URL: string
//   DEVELOPMENT_API_KEY: string
//   DEVELOPMENT_JWT_SECRET: string
//   DEVELOPMENT_REDIS_URL: string
// }
```

## 🎁 Generic Constraints Best Practices

### 1. Use Constraints to Provide Better Error Messages
```typescript
// ❌ Poor: Unclear error messages
function process<T>(data: T): T {
  return data.toLowerCase() // Error: Property 'toLowerCase' does not exist on type 'T'
}

// ✅ Good: Clear constraints with helpful errors
function processString<T extends string>(data: T): Lowercase<T> {
  return data.toLowerCase() as Lowercase<T>
}

// ✅ Better: Multiple constraint options with clear intent
function processTextData<T extends { toString(): string }>(data: T): string {
  return data.toString().toLowerCase()
}

// ✅ Best: Conditional processing based on type
function smartProcess<T>(data: T): T extends string ? Lowercase<T> : string {
  const str = typeof data === 'string' ? data : String(data)
  return str.toLowerCase() as T extends string ? Lowercase<T> : string
}
```

### 2. Design Flexible Generic APIs
```typescript
// ✅ Excellent: Flexible repository pattern for EdTech
interface Entity {
  id: string
}

interface QueryOptions<T> {
  where?: Partial<T>
  orderBy?: keyof T
  limit?: number
}

interface FindOptions<T, K extends keyof T = keyof T> extends QueryOptions<T> {
  select?: K[]
}

class TypedRepository<TEntity extends Entity> {
  constructor(private entityName: string) {}

  // Flexible find method with selective returns
  async find<TSelect extends keyof TEntity = keyof TEntity>(
    options?: FindOptions<TEntity, TSelect>
  ): Promise<Pick<TEntity, TSelect | 'id'>[]> {
    // Implementation would use options to build query
    // Always include 'id' even if not in select
    return [] as Pick<TEntity, TSelect | 'id'>[]
  }

  // Type-safe updates
  async update(
    id: string,
    data: Partial<Omit<TEntity, 'id'>>
  ): Promise<TEntity> {
    // Implementation would update entity
    return {} as TEntity
  }

  // Flexible creation with defaults
  async create<TDefaults extends Partial<TEntity>>(
    data: Omit<TEntity, 'id' | keyof TDefaults>,
    defaults?: TDefaults
  ): Promise<TEntity> {
    // Implementation would merge data with defaults
    return {} as TEntity
  }
}

// Usage with EdTech entities
interface Course extends Entity {
  title: string
  description: string
  instructorId: string
  isPublished: boolean
  createdAt: Date
}

const courseRepo = new TypedRepository<Course>('courses')

// Type-safe queries
const courses = await courseRepo.find({
  select: ['title', 'isPublished'],  // Only these fields returned
  where: { isPublished: true },
  orderBy: 'title',
  limit: 10
})
// Type: Pick<Course, 'title' | 'isPublished' | 'id'>[]

// Type-safe creation with defaults
const newCourse = await courseRepo.create(
  {
    title: 'Advanced TypeScript',
    description: 'Learn advanced TypeScript patterns',
    instructorId: 'instructor-123'
  },
  { isPublished: false }  // Default values
)
```

## 🚀 Performance Best Practices

### 1. Optimize Compilation Speed
```typescript
// ✅ Use type aliases to cache complex computations
type ComplexUnion = 'user' | 'admin' | 'moderator' | 'guest' | 'premium' | 'enterprise'

// Instead of repeating the complex type everywhere
type UserPermissions = {
  [K in ComplexUnion]: {
    read: boolean
    write: boolean
    delete: boolean
  }
}

// Create specific aliases
type StandardUserPermissions = UserPermissions['user']
type AdminUserPermissions = UserPermissions['admin']

// ✅ Prefer interfaces for object types (better performance)
interface StudentData {
  id: string
  name: string
  courses: CourseData[]
}

interface CourseData {
  id: string
  title: string
  students: StudentData[]
}

// ❌ Avoid: Type aliases for recursive structures (slower compilation)
type StudentDataBad = {
  id: string
  name: string
  courses: CourseDataBad[]
}

type CourseDataBad = {
  id: string
  title: string
  students: StudentDataBad[]
}
```

### 2. Limit Recursive Type Depth
```typescript
// ✅ Good: Controlled recursion with depth limits
type DeepReadonly<T, Depth extends number = 3> = 
  Depth extends 0 
    ? T
    : T extends object
    ? {
        readonly [K in keyof T]: DeepReadonly<T[K], Prev<Depth>>
      }
    : T

type Prev<T extends number> = T extends 4 ? 3 : T extends 3 ? 2 : T extends 2 ? 1 : 0

// ✅ Alternative: Use branded types for performance
declare const __brand: unique symbol
type Brand<T, TBrand> = T & { [__brand]: TBrand }

type StudentId = Brand<string, 'StudentId'>
type CourseId = Brand<string, 'CourseId'>

// Now these are distinct types but with minimal runtime cost
function getStudent(id: StudentId): Promise<Student> {
  return database.students.findUnique({ where: { id } })
}

function getCourse(id: CourseId): Promise<Course> {
  return database.courses.findUnique({ where: { id } })
}

// Usage requires explicit casting but provides type safety
const studentId = 'student-123' as StudentId
const courseId = 'course-456' as CourseId

getStudent(studentId)  // ✅ Valid
getCourse(courseId)    // ✅ Valid
// getStudent(courseId) // ❌ TypeScript error
```

## 🧪 Testing and Validation Best Practices

### 1. Design Types for Testability
```typescript
// ✅ Good: Create testable type utilities
type Expect<T extends true> = T
type Equal<X, Y> = (<T>() => T extends X ? 1 : 2) extends (<T>() => T extends Y ? 1 : 2) ? true : false

// Test your types
type TestStudentUpdate = Expect<Equal<
  StudentUpdate,
  { id: string } & Partial<Pick<Student, 'name' | 'email' | 'grade' | 'enrollmentDate'>>
>>

// ✅ Use assertion functions for runtime validation
function assertIsStudent(obj: unknown): asserts obj is Student {
  if (typeof obj !== 'object' || obj === null) {
    throw new Error('Expected object')
  }
  
  const candidate = obj as Record<string, unknown>
  
  if (typeof candidate.id !== 'string') {
    throw new Error('Expected string id')
  }
  
  if (typeof candidate.name !== 'string') {
    throw new Error('Expected string name')
  }
  
  // Additional validations...
}

// Usage
function processStudentData(data: unknown) {
  assertIsStudent(data)
  // Now TypeScript knows data is Student
  console.log(data.name) // ✅ Type-safe
}
```

### 2. Runtime Validation with Static Types
```typescript
import { z } from 'zod'

// ✅ Excellent: Zod schemas that generate TypeScript types
const StudentSchema = z.object({
  id: z.string().uuid(),
  name: z.string().min(1).max(100),
  email: z.string().email(),
  grade: z.number().int().min(1).max(12),
  enrollmentDate: z.date(),
  courses: z.array(z.string().uuid()).optional().default([])
})

// Automatically inferred TypeScript type
type Student = z.infer<typeof StudentSchema>

// Runtime validation with full type safety
function createStudent(data: unknown): Student {
  return StudentSchema.parse(data) // Throws if invalid
}

function validateStudent(data: unknown): data is Student {
  return StudentSchema.safeParse(data).success
}

// ✅ API integration with validation
async function handleCreateStudent(req: Request): Promise<Response> {
  try {
    const studentData = StudentSchema.parse(req.body)
    const student = await createStudent(studentData)
    return Response.json({ success: true, data: student })
  } catch (error) {
    if (error instanceof z.ZodError) {
      return Response.json({ 
        success: false, 
        errors: error.errors 
      }, { status: 400 })
    }
    throw error
  }
}
```

## 📋 Code Review Checklist

### Type Design Review
- [ ] Are type names descriptive and follow project conventions?
- [ ] Do complex types have documentation comments?
- [ ] Are type parameters constrained appropriately?
- [ ] Do conditional types handle edge cases?
- [ ] Are mapped types preserving optionality correctly?
- [ ] Do template literal types compose well?

### Performance Review
- [ ] Are interfaces used instead of type aliases for object types?
- [ ] Is recursive type depth limited?
- [ ] Are complex types cached with aliases?
- [ ] Do generic constraints provide helpful error messages?
- [ ] Are there any unnecessary type computations?

### Maintainability Review
- [ ] Are types broken down into composable pieces?
- [ ] Do types follow the single responsibility principle?
- [ ] Are utility types reusable across the codebase?
- [ ] Is there adequate test coverage for type utilities?
- [ ] Are runtime validations aligned with static types?

## 🎯 Team Adoption Guidelines

### 1. Gradual Migration Strategy
```typescript
// Phase 1: Basic types with strict mode
// Enable strict: true, but allow gradual adoption

// Phase 2: Introduce utility types
type ApiResponse<T> = { success: true; data: T } | { success: false; error: string }

// Phase 3: Advanced patterns in new code
// Use conditional types, mapped types in new features

// Phase 4: Refactor legacy code
// Apply advanced patterns to existing code systematically
```

### 2. Training and Documentation
- Create internal type libraries with examples
- Conduct code review sessions focusing on type design
- Maintain a style guide for TypeScript patterns
- Set up linting rules to enforce best practices

### 3. Tooling Configuration
```json
{
  "compilerOptions": {
    "strict": true,
    "exactOptionalPropertyTypes": true,
    "noUncheckedIndexedAccess": true,
    "noImplicitReturns": true
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "**/*.test.ts"]
}
```

---

### 📖 Document Navigation

| Previous | Current | Next |
|----------|---------|------|
| [Implementation Guide](./implementation-guide.md) | **Best Practices** | [Type System Fundamentals](./type-system-fundamentals.md) |

---

*Last updated: January 2025*  
*Based on practices from Google, Microsoft, Airbnb, Stripe, and the TypeScript community*