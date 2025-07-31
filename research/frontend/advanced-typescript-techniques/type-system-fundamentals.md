# Type System Fundamentals - Advanced TypeScript Techniques

## 🎯 Overview

Understanding TypeScript's type system at a fundamental level is crucial for mastering advanced techniques. This document explores the core concepts, type theory principles, and systematic approaches that underpin sophisticated TypeScript development for EdTech platforms and enterprise applications.

## 🔧 Core Type System Concepts

### 1. Structural vs Nominal Typing
```typescript
// TypeScript uses structural typing (duck typing)
interface Student {
  id: string
  name: string
  email: string
}

interface Person {
  id: string
  name: string
  email: string
}

// These are considered the same type structurally
function processStudent(student: Student): void {
  console.log(student.name)
}

const person: Person = { id: '1', name: 'John', email: 'john@example.com' }
processStudent(person) // ✅ Works because structure matches

// Nominal typing with branded types when needed
declare const __brand: unique symbol
type StudentId = string & { [__brand]: 'StudentId' }
type PersonId = string & { [__brand]: 'PersonId' }

function getStudent(id: StudentId): Student | null { return null }

const studentId = 'student-123' as StudentId
const personId = 'person-123' as PersonId

getStudent(studentId) // ✅ Valid
// getStudent(personId) // ❌ TypeScript error - different brands
```

### 2. Type Compatibility and Assignability
```typescript
// Subtype relationships in TypeScript
interface BaseUser {
  id: string
  name: string
}

interface Student extends BaseUser {
  grade: number
  courses: string[]
}

interface Instructor extends BaseUser {
  department: string
  courses: string[]
}

// Assignability rules
let user: BaseUser
let student: Student = { id: '1', name: 'John', grade: 10, courses: ['math'] }
let instructor: Instructor = { id: '2', name: 'Jane', department: 'CS', courses: ['typescript'] }

user = student    // ✅ Student is assignable to BaseUser (subtype)
user = instructor // ✅ Instructor is assignable to BaseUser (subtype)

// student = user // ❌ BaseUser is not assignable to Student (missing properties)

// Function assignability (contravariant parameters, covariant return types)
type UserProcessor<T extends BaseUser> = (user: T) => string

const processAnyUser: UserProcessor<BaseUser> = (user) => user.name
const processStudent: UserProcessor<Student> = (student) => `${student.name} (Grade ${student.grade})`

// Function subtyping
let anyProcessor: UserProcessor<BaseUser> = processAnyUser
anyProcessor = processStudent // ❌ Not assignable - Student processor expects more specific type

let studentProcessor: UserProcessor<Student> = processStudent
// studentProcessor = processAnyUser // ✅ Would work - can handle more general type
```

### 3. Type Widening and Narrowing
```typescript
// Type widening
let message = 'hello' // Type widened to string, not 'hello'
const greeting = 'hello' // Type narrowed to 'hello' literal

// Preventing widening with const assertions
const userRoles = ['student', 'instructor', 'admin'] as const
// Type: readonly ['student', 'instructor', 'admin']

const config = {
  apiVersion: 'v1',
  timeout: 5000,
  retries: 3
} as const
// Properties maintain literal types

// Type narrowing with type guards
function isStudent(user: BaseUser): user is Student {
  return 'grade' in user && 'courses' in user
}

function processUser(user: BaseUser): string {
  if (isStudent(user)) {
    // user is narrowed to Student type here
    return `Student: ${user.name}, Grade: ${user.grade}`
  }
  return `User: ${user.name}`
}

// Discriminated unions for type narrowing
interface StudentEvent {
  type: 'student'
  userId: string
  grade: number
}

interface InstructorEvent {
  type: 'instructor'
  userId: string
  department: string
}

type UserEvent = StudentEvent | InstructorEvent

function handleEvent(event: UserEvent): string {
  switch (event.type) {
    case 'student':
      // event is narrowed to StudentEvent
      return `Student event for grade ${event.grade}`
    case 'instructor':
      // event is narrowed to InstructorEvent
      return `Instructor event for ${event.department}`
  }
}
```

## 📚 Advanced Type Relationships

### 1. Variance in TypeScript
```typescript
// Covariance: T<A> is assignable to T<B> if A is assignable to B
interface ReadOnlyList<T> {
  readonly items: readonly T[]
  get(index: number): T
}

const studentList: ReadOnlyList<Student> = { items: [], get: (i) => null! }
const userList: ReadOnlyList<BaseUser> = studentList // ✅ Covariant - safe

// Contravariance: T<A> is assignable to T<B> if B is assignable to A
interface Writer<T> {
  write(item: T): void
}

const userWriter: Writer<BaseUser> = { write: (user) => console.log(user.name) }
const studentWriter: Writer<Student> = userWriter // ✅ Contravariant - safe

// Invariance: exact type match required
interface MutableList<T> {
  items: T[]
  add(item: T): void
  get(index: number): T
}

const mutableStudents: MutableList<Student> = { items: [], add: () => {}, get: () => null! }
// const mutableUsers: MutableList<BaseUser> = mutableStudents // ❌ Not safe - invariant
```

### 2. Higher-Kinded Types Simulation
```typescript
// Simulate higher-kinded types with interface patterns
interface Functor<F> {
  map<A, B>(fa: F, f: (a: A) => B): F
}

interface ArrayFunctor extends Functor<unknown[]> {
  map<A, B>(fa: A[], f: (a: A) => B): B[]
}

const arrayFunctor: ArrayFunctor = {
  map: (arr, fn) => arr.map(fn)
}

// Promise functor
interface PromiseFunctor extends Functor<Promise<unknown>> {
  map<A, B>(fa: Promise<A>, f: (a: A) => B): Promise<B>
}

const promiseFunctor: PromiseFunctor = {
  map: (promise, fn) => promise.then(fn)
}

// Usage in EdTech context
interface Course {
  id: string
  title: string
  lessons: Lesson[]
}

interface Lesson {
  id: string
  title: string
  duration: number
}

// Transform array of courses
const courses: Course[] = []
const courseTitles = arrayFunctor.map(courses, course => course.title)

// Transform async course data
const asyncCourse: Promise<Course> = Promise.resolve(courses[0])
const asyncTitle = promiseFunctor.map(asyncCourse, course => course.title)
```

### 3. Type-Level Programming Patterns
```typescript
// Boolean logic at type level
type And<A extends boolean, B extends boolean> = A extends true 
  ? B extends true 
    ? true 
    : false 
  : false

type Or<A extends boolean, B extends boolean> = A extends true 
  ? true 
  : B extends true 
  ? true 
  : false

type Not<A extends boolean> = A extends true ? false : true

// Type-level arithmetic (limited)
type Increment<N extends number> = 
  N extends 0 ? 1 :
  N extends 1 ? 2 :
  N extends 2 ? 3 :
  N extends 3 ? 4 :
  N extends 4 ? 5 :
  never // Limited implementation

// Type-level list operations
type Head<T extends readonly unknown[]> = T extends readonly [infer H, ...unknown[]] ? H : never
type Tail<T extends readonly unknown[]> = T extends readonly [unknown, ...infer Tail] ? Tail : never
type Length<T extends readonly unknown[]> = T['length']

// Examples
type FirstElement = Head<['a', 'b', 'c']>      // 'a'
type RestElements = Tail<['a', 'b', 'c']>      // ['b', 'c']
type ArrayLength = Length<['a', 'b', 'c']>     // 3

// Recursive type programming
type Reverse<T extends readonly unknown[]> = T extends readonly [...infer Rest, infer Last]
  ? [Last, ...Reverse<Rest>]
  : []

type ReversedArray = Reverse<['a', 'b', 'c']>  // ['c', 'b', 'a']

// EdTech application: Course prerequisite chain validation
type PrerequisiteChain<T extends readonly string[]> = T extends readonly [infer First, ...infer Rest]
  ? First extends string
    ? Rest extends readonly string[]
      ? [First, ...PrerequisiteChain<Rest>]
      : [First]
    : []
  : []

type CourseChain = PrerequisiteChain<['intro-js', 'advanced-js', 'typescript', 'advanced-ts']>
```

## 🎯 Type System Best Practices

### 1. Designing Composable Type Systems
```typescript
// Base types for composition
interface WithId {
  id: string
}

interface WithTimestamp {
  createdAt: Date
  updatedAt: Date
}

interface WithSoftDelete {
  deletedAt?: Date
}

interface WithMetadata {
  metadata: Record<string, unknown>
}

// Composable entity types
type BaseEntity = WithId & WithTimestamp
type SoftDeletableEntity = BaseEntity & WithSoftDelete
type MetadataEntity = BaseEntity & WithMetadata

// EdTech domain entities
interface StudentData {
  name: string
  email: string
  grade: number
}

interface CourseData {
  title: string
  description: string
  instructorId: string
}

interface LessonData {
  title: string
  content: string
  courseId: string
  duration: number
}

// Composed final types
type Student = BaseEntity & StudentData
type Course = SoftDeletableEntity & MetadataEntity & CourseData
type Lesson = BaseEntity & LessonData

// Generic repository pattern using composition
interface Repository<T extends WithId> {
  findById(id: string): Promise<T | null>
  create(data: Omit<T, keyof WithId>): Promise<T>
  update(id: string, data: Partial<Omit<T, keyof WithId>>): Promise<T>
}

interface SoftDeleteRepository<T extends WithId & WithSoftDelete> extends Repository<T> {
  softDelete(id: string): Promise<void>
  restore(id: string): Promise<void>
}

// Usage
const studentRepository: Repository<Student> = null!
const courseRepository: SoftDeleteRepository<Course> = null!
```

### 2. Type-Safe Error Handling
```typescript
// Result type for functional error handling
type Result<T, E = Error> = 
  | { success: true; data: T }
  | { success: false; error: E }

// Specific error types for EdTech domain
type ValidationError = {
  type: 'validation'
  field: string
  message: string
}

type NotFoundError = {
  type: 'not_found'
  resource: string
  id: string
}

type PermissionError = {
  type: 'permission'
  action: string
  resource: string
}

type DomainError = ValidationError | NotFoundError | PermissionError

// Result helpers
namespace Result {
  export function success<T>(data: T): Result<T, never> {
    return { success: true, data }
  }

  export function failure<E>(error: E): Result<never, E> {
    return { success: false, error }
  }

  export function map<T, U, E>(
    result: Result<T, E>,
    fn: (data: T) => U
  ): Result<U, E> {
    return result.success ? success(fn(result.data)) : result
  }

  export function flatMap<T, U, E>(
    result: Result<T, E>,
    fn: (data: T) => Result<U, E>
  ): Result<U, E> {
    return result.success ? fn(result.data) : result
  }

  export function mapError<T, E, F>(
    result: Result<T, E>,
    fn: (error: E) => F
  ): Result<T, F> {
    return result.success ? result : failure(fn(result.error))
  }
}

// Usage in EdTech service
class StudentService {
  async createStudent(data: Omit<Student, 'id' | 'createdAt' | 'updatedAt'>): Promise<Result<Student, DomainError>> {
    // Validation
    if (!data.email.includes('@')) {
      return Result.failure({
        type: 'validation',
        field: 'email',
        message: 'Invalid email format'
      })
    }

    // Check for existing student
    const existing = await this.findByEmail(data.email)
    if (existing.success) {
      return Result.failure({
        type: 'validation',
        field: 'email',
        message: 'Email already exists'
      })
    }

    // Create student
    const student: Student = {
      ...data,
      id: crypto.randomUUID(),
      createdAt: new Date(),
      updatedAt: new Date()
    }

    return Result.success(student)
  }

  private async findByEmail(email: string): Promise<Result<Student, NotFoundError>> {
    // Implementation would query database
    return Result.failure({
      type: 'not_found',
      resource: 'student',
      id: email
    })
  }
}
```

### 3. Advanced Type Guards and Assertions
```typescript
// Comprehensive type guards for EdTech entities
function isStudent(user: unknown): user is Student {
  return (
    typeof user === 'object' &&
    user !== null &&
    'id' in user &&
    'name' in user &&
    'email' in user &&
    'grade' in user &&
    'createdAt' in user &&
    'updatedAt' in user &&
    typeof (user as any).id === 'string' &&
    typeof (user as any).name === 'string' &&
    typeof (user as any).email === 'string' &&
    typeof (user as any).grade === 'number' &&
    (user as any).createdAt instanceof Date &&
    (user as any).updatedAt instanceof Date
  )
}

// Generic type guard factory
function createEntityGuard<T extends WithId>(
  entityName: string,
  additionalChecks: (obj: any) => boolean
) {
  return function(obj: unknown): obj is T {
    return (
      typeof obj === 'object' &&
      obj !== null &&
      'id' in obj &&
      typeof (obj as any).id === 'string' &&
      additionalChecks(obj)
    )
  }
}

// Usage
const isCourse = createEntityGuard<Course>('course', (obj) => 
  'title' in obj &&
  'description' in obj &&
  'instructorId' in obj &&
  typeof obj.title === 'string' &&
  typeof obj.description === 'string' &&
  typeof obj.instructorId === 'string'
)

// Assertion functions for runtime validation
function assertIsStudent(obj: unknown): asserts obj is Student {
  if (!isStudent(obj)) {
    throw new Error('Object is not a valid Student')
  }
}

function assertIsValidEmail(email: string): asserts email is string & { __valid: 'email' } {
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    throw new Error('Invalid email format')
  }
}

// Usage in API handlers
function handleCreateStudent(request: unknown) {
  assertIsStudent(request)
  // TypeScript now knows request is Student
  
  assertIsValidEmail(request.email)
  // TypeScript now knows email is valid
  
  // Process the validated student data
  return processValidatedStudent(request)
}

function processValidatedStudent(student: Student): void {
  // Implementation
}
```

## 🧪 Type System Testing

### Comprehensive Type Testing
```typescript
// Advanced type testing utilities
type Expect<T extends true> = T
type Equal<X, Y> = (<T>() => T extends X ? 1 : 2) extends (<T>() => T extends Y ? 1 : 2) ? true : false
type NotEqual<X, Y> = Equal<X, Y> extends true ? false : true
type Extends<X, Y> = X extends Y ? true : false
type NotExtends<X, Y> = Extends<X, Y> extends true ? false : true

// Test type relationships
type TestStudentExtendsBaseUser = Expect<Extends<Student, BaseUser>>
type TestBaseUserNotExtendsStudent = Expect<NotExtends<BaseUser, Student>>

// Test composition
type TestComposedStudent = Expect<Equal<
  Student,
  BaseEntity & StudentData
>>

// Test variance
type TestArrayCovariance = Expect<Extends<Student[], BaseUser[]>>
type TestFunctionContravariance = Expect<Extends<
  (user: BaseUser) => void,
  (student: Student) => void
>>

// Test type guards
type TestStudentGuard = Expect<Equal<
  ReturnType<typeof isStudent>,
  boolean
>>

// Test error handling
type TestResultSuccess = Expect<Equal<
  Result<Student, never>,
  { success: true; data: Student }
>>

type TestResultFailure = Expect<Equal<
  Result<never, DomainError>,
  { success: false; error: DomainError }
>>
```

### Runtime Type System Validation
```typescript
import { describe, it, expect } from 'vitest'

describe('Type System Fundamentals', () => {
  it('should handle structural typing correctly', () => {
    const student: Student = {
      id: '1',
      name: 'John',
      email: 'john@example.com',
      grade: 10,
      createdAt: new Date(),
      updatedAt: new Date()
    }

    const person: Person = {
      id: '1',
      name: 'John',
      email: 'john@example.com'
    }

    // Both should be accepted by processStudent due to structural typing
    expect(() => processStudent(student)).not.toThrow()
    expect(() => processStudent(person)).not.toThrow()
  })

  it('should validate types with type guards', () => {
    const validStudent = {
      id: '1',
      name: 'John',
      email: 'john@example.com',
      grade: 10,
      createdAt: new Date(),
      updatedAt: new Date()
    }

    const invalidStudent = {
      id: '1',
      name: 'John'
      // Missing required fields
    }

    expect(isStudent(validStudent)).toBe(true)
    expect(isStudent(invalidStudent)).toBe(false)
  })

  it('should handle Result type correctly', async () => {
    const service = new StudentService()
    
    // Valid student data
    const validData = {
      name: 'John Doe',
      email: 'john@example.com',
      grade: 10
    }

    const result = await service.createStudent(validData)
    
    if (result.success) {
      expect(result.data).toHaveProperty('id')
      expect(result.data.name).toBe('John Doe')
    } else {
      // Handle error case
      expect(result.error).toHaveProperty('type')
    }
  })

  it('should chain Result operations', () => {
    const result = Result.success(5)
    
    const doubled = Result.map(result, x => x * 2)
    expect(doubled.success && doubled.data).toBe(10)
    
    const stringified = Result.map(doubled, x => x.toString())
    expect(stringified.success && stringified.data).toBe('10')
  })

  it('should handle assertion functions', () => {
    const validStudent = {
      id: '1',
      name: 'John',
      email: 'john@example.com',
      grade: 10,
      createdAt: new Date(),
      updatedAt: new Date()
    }

    expect(() => assertIsStudent(validStudent)).not.toThrow()
    expect(() => assertIsStudent({})).toThrow()
    
    expect(() => assertIsValidEmail('test@example.com')).not.toThrow()
    expect(() => assertIsValidEmail('invalid-email')).toThrow()
  })
})
```

---

### 📖 Document Navigation

| Previous | Current | Next |
|----------|---------|------|
| [Template Literal Types](./template-literal-types.md) | **Type System Fundamentals** | [Advanced Generics Patterns](./advanced-generics-patterns.md) |

---

*Last updated: January 2025*  
*Core type system principles for advanced TypeScript development*