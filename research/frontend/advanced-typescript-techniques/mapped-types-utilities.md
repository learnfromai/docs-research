# Mapped Types & Utilities - Advanced TypeScript Techniques

## 🎯 Overview

Mapped types are TypeScript's mechanism for creating new types by transforming properties of existing types. They're essential for building flexible APIs, form systems, and state management in EdTech platforms. This document covers advanced mapped type patterns critical for senior-level TypeScript development.

## 🔧 Fundamental Mapped Type Patterns

### Basic Syntax and Transformations
```typescript
// Basic mapped type syntax: { [K in keyof T]: T[K] }
type ReadonlyVersion<T> = {
  readonly [K in keyof T]: T[K]
}

type OptionalVersion<T> = {
  [K in keyof T]?: T[K]
}

// Example with EdTech entity
interface Student {
  id: string
  name: string
  email: string
  grade: number
  enrollmentDate: Date
}

type ReadonlyStudent = ReadonlyVersion<Student>
// Result: {
//   readonly id: string
//   readonly name: string
//   readonly email: string
//   readonly grade: number
//   readonly enrollmentDate: Date
// }

type PartialStudent = OptionalVersion<Student>
// Result: {
//   id?: string
//   name?: string
//   email?: string
//   grade?: number
//   enrollmentDate?: Date
// }
```

### Key Remapping in Mapped Types
```typescript
// Key remapping with 'as' clause (TypeScript 4.1+)
type Getters<T> = {
  [K in keyof T as `get${Capitalize<string & K>}`]: () => T[K]
}

type Setters<T> = {
  [K in keyof T as `set${Capitalize<string & K>}`]: (value: T[K]) => void
}

// EdTech example: Student getters and setters
type StudentGetters = Getters<Student>
// Result: {
//   getId: () => string
//   getName: () => string
//   getEmail: () => string
//   getGrade: () => number
//   getEnrollmentDate: () => Date
// }

type StudentSetters = Setters<Student>
// Result: {
//   setId: (value: string) => void
//   setName: (value: string) => void
//   setEmail: (value: string) => void
//   setGrade: (value: number) => void
//   setEnrollmentDate: (value: Date) => void
// }
```

## 📚 EdTech Platform Application Patterns

### 1. Advanced Form State Management
```typescript
// Comprehensive form field state
interface FieldState<T> {
  value: T
  error?: string
  touched: boolean
  dirty: boolean
  validating: boolean
}

// Form configuration with validation rules
interface FieldConfig<T> {
  required?: boolean
  validate?: (value: T) => string | undefined
  transform?: (value: T) => T
  dependsOn?: string[]
}

// Complete form state type
type FormState<T> = {
  [K in keyof T]: FieldState<T[K]> & {
    config: FieldConfig<T[K]>
  }
}

// Course creation form
interface CourseFormData {
  title: string
  description: string
  duration: number
  difficulty: 'beginner' | 'intermediate' | 'advanced'
  tags: string[]
  isPublished: boolean
  price: number
}

type CourseFormState = FormState<CourseFormData>

// Form handlers with key remapping
type FormHandlers<T> = {
  [K in keyof T as `handle${Capitalize<string & K>}Change`]: (value: T[K]) => void
} & {
  [K in keyof T as `validate${Capitalize<string & K>}`]: () => void
} & {
  [K in keyof T as `reset${Capitalize<string & K>}`]: () => void
}

type CourseFormHandlers = FormHandlers<CourseFormData>
// Result includes:
// - handleTitleChange: (value: string) => void
// - handleDescriptionChange: (value: string) => void
// - validateTitle: () => void
// - resetTitle: () => void
// etc.

// Implementation class
class FormManager<T extends Record<string, any>> {
  private state: FormState<T>
  
  constructor(initialData: T, configs: { [K in keyof T]: FieldConfig<T[K]> }) {
    this.state = {} as FormState<T>
    
    // Initialize form state
    for (const key in initialData) {
      this.state[key] = {
        value: initialData[key],
        touched: false,
        dirty: false,
        validating: false,
        config: configs[key]
      }
    }
  }

  getValue<K extends keyof T>(field: K): T[K] {
    return this.state[field].value
  }

  setValue<K extends keyof T>(field: K, value: T[K]): void {
    this.state[field] = {
      ...this.state[field],
      value,
      dirty: true,
      error: this.state[field].config.validate?.(value)
    }
  }

  getFormData(): T {
    const result = {} as T
    for (const key in this.state) {
      result[key] = this.state[key].value
    }
    return result
  }
}
```

### 2. Database Schema Transformations
```typescript
// Database entity base
interface BaseEntity {
  id: string
  createdAt: Date
  updatedAt: Date
}

// Transform entity for different contexts
type CreateInput<T extends BaseEntity> = Omit<T, 'id' | 'createdAt' | 'updatedAt'>
type UpdateInput<T extends BaseEntity> = Partial<Omit<T, 'id' | 'createdAt' | 'updatedAt'>>
type ApiResponse<T extends BaseEntity> = T & {
  _links: {
    self: string
    edit?: string
    delete?: string
  }
}

// EdTech entities
interface Course extends BaseEntity {
  title: string
  description: string
  instructorId: string
  modules: Module[]
  enrollmentCount: number
  isPublished: boolean
}

interface Module extends BaseEntity {
  title: string
  description: string
  courseId: string
  lessons: Lesson[]
  order: number
}

interface Lesson extends BaseEntity {
  title: string
  content: string
  moduleId: string
  videoUrl?: string
  duration: number
  order: number
}

// Usage examples
type CreateCourseInput = CreateInput<Course>
// Result: {
//   title: string
//   description: string
//   instructorId: string
//   modules: Module[]
//   enrollmentCount: number
//   isPublished: boolean
// }

type UpdateCourseInput = UpdateInput<Course>
// Result: Partial<{
//   title: string
//   description: string
//   instructorId: string
//   modules: Module[]
//   enrollmentCount: number
//   isPublished: boolean
// }>

type CourseApiResponse = ApiResponse<Course>
// Result: Course & {
//   _links: {
//     self: string
//     edit?: string
//     delete?: string
//   }
// }
```

### 3. Advanced State Management Patterns
```typescript
// Redux-style action creators with mapped types
type ActionCreators<T> = {
  [K in keyof T as `set${Capitalize<string & K>}`]: (payload: T[K]) => {
    type: `SET_${Uppercase<string & K>}`
    payload: T[K]
  }
} & {
  [K in keyof T as `reset${Capitalize<string & K>}`]: () => {
    type: `RESET_${Uppercase<string & K>}`
  }
}

// Student state
interface StudentState {
  profile: Student
  courses: Course[]
  progress: StudentProgress
  preferences: UserPreferences
}

type StudentActionCreators = ActionCreators<StudentState>
// Result includes:
// - setProfile: (payload: Student) => { type: 'SET_PROFILE', payload: Student }
// - setCourses: (payload: Course[]) => { type: 'SET_COURSES', payload: Course[] }
// - resetProfile: () => { type: 'RESET_PROFILE' }
// etc.

// Action type union extraction
type ExtractActions<T> = T[keyof T] extends (...args: any[]) => infer R ? R : never
type StudentActions = ExtractActions<StudentActionCreators>

// Reducer type with mapped action handling
type StateReducer<TState, TActions> = (
  state: TState,
  action: TActions
) => TState

// Advanced selector patterns
type Selectors<TState> = {
  [K in keyof TState as `get${Capitalize<string & K>}`]: (state: TState) => TState[K]
} & {
  [K in keyof TState as `select${Capitalize<string & K>}`]: <TSelected>(
    state: TState,
    selector: (value: TState[K]) => TSelected
  ) => TSelected
}

type StudentSelectors = Selectors<StudentState>
// Result includes:
// - getProfile: (state: StudentState) => Student
// - selectProfile: <TSelected>(state: StudentState, selector: (Student) => TSelected) => TSelected
// etc.
```

## 🚀 Advanced Mapped Type Patterns

### 1. Conditional Property Transformation
```typescript
// Transform properties based on their types
type StringToUppercase<T> = {
  [K in keyof T]: T[K] extends string ? Uppercase<T[K]> : T[K]
}

// Transform optional properties differently
type RequireOptional<T> = {
  [K in keyof T]-?: T[K] // Remove optionality with -?
}

type MakeOptional<T> = {
  [K in keyof T]?: T[K] // Add optionality with ?
}

// Conditional optionality based on property type
type ConditionalOptional<T> = {
  [K in keyof T]: T[K] extends string ? T[K] : T[K] | undefined
} & {
  [K in keyof T as T[K] extends string ? never : K]?: T[K]
}

// EdTech example: API serialization
interface StudentData {
  id: string
  name: string
  email: string
  grade: number
  enrollmentDate: Date
  metadata?: Record<string, any>
}

type SerializedStudent = {
  [K in keyof StudentData]: StudentData[K] extends Date 
    ? string  // Dates become strings in JSON
    : StudentData[K] extends Record<string, any>
    ? string  // Objects become JSON strings
    : StudentData[K]
}
// Result: {
//   id: string
//   name: string
//   email: string
//   grade: number
//   enrollmentDate: string  // Date → string
//   metadata?: string       // Object → string
// }
```

### 2. Deep Transformation Patterns
```typescript
// Deep readonly transformation
type DeepReadonly<T> = {
  readonly [P in keyof T]: T[P] extends object
    ? T[P] extends any[]
      ? ReadonlyArray<DeepReadonly<T[P][number]>>
      : DeepReadonly<T[P]>
    : T[P]
}

// Deep partial transformation
type DeepPartial<T> = {
  [P in keyof T]?: T[P] extends object
    ? T[P] extends any[]
      ? Array<DeepPartial<T[P][number]>>
      : DeepPartial<T[P]>
    : T[P]
}

// Deep nullable transformation
type DeepNullable<T> = {
  [P in keyof T]: T[P] extends object
    ? T[P] extends any[]
      ? Array<DeepNullable<T[P][number]>> | null
      : DeepNullable<T[P]> | null
    : T[P] | null
}

// Course with nested modules and lessons
interface NestedCourse {
  id: string
  title: string
  modules: {
    id: string
    title: string
    lessons: {
      id: string
      title: string
      content: string
    }[]
  }[]
}

type ImmutableCourse = DeepReadonly<NestedCourse>
type PartialCourseUpdate = DeepPartial<NestedCourse>
type NullableCourse = DeepNullable<NestedCourse>
```

### 3. Template Literal Key Mapping
```typescript
// Combine template literals with mapped types
type PrefixKeys<T, P extends string> = {
  [K in keyof T as `${P}${Capitalize<string & K>}`]: T[K]
}

type SuffixKeys<T, S extends string> = {
  [K in keyof T as `${string & K}${Capitalize<S>}`]: T[K]
}

// Event system for EdTech platform
interface StudentEvents {
  enrolled: { courseId: string; timestamp: Date }
  completed: { lessonId: string; score: number }
  failed: { assessmentId: string; attempts: number }
}

// Create event handlers
type StudentEventHandlers = PrefixKeys<StudentEvents, 'on'>
// Result: {
//   onEnrolled: { courseId: string; timestamp: Date }
//   onCompleted: { lessonId: string; score: number }
//   onFailed: { assessmentId: string; attempts: number }
// }

// Create event emitters
type StudentEventEmitters = PrefixKeys<StudentEvents, 'emit'>
// Result: {
//   emitEnrolled: { courseId: string; timestamp: Date }
//   emitCompleted: { lessonId: string; score: number }
//   emitFailed: { assessmentId: string; attempts: number }
// }

// Advanced: Nested property paths
type NestedKeyPaths<T, P extends string = ''> = {
  [K in keyof T]: T[K] extends object
    ? T[K] extends any[]
      ? `${P}${string & K}` | NestedKeyPaths<T[K][number], `${P}${string & K}.${number}.`>
      : `${P}${string & K}` | NestedKeyPaths<T[K], `${P}${string & K}.`>
    : `${P}${string & K}`
}[keyof T]

type CourseKeyPaths = NestedKeyPaths<NestedCourse>
// Result: "id" | "title" | "modules" | "modules.0.id" | "modules.0.title" | "modules.0.lessons" | ...
```

## 🎯 Utility Type Creation

### 1. Custom Utility Types for EdTech
```typescript
// Pick properties by type
type PickByType<T, U> = {
  [K in keyof T as T[K] extends U ? K : never]: T[K]
}

// Omit properties by type
type OmitByType<T, U> = {
  [K in keyof T as T[K] extends U ? never : K]: T[K]
}

// EdTech example: Extract string properties for text search
interface SearchableStudent {
  id: string
  name: string
  email: string
  grade: number
  enrollmentDate: Date
  isActive: boolean
}

type StringProperties = PickByType<SearchableStudent, string>
// Result: {
//   id: string
//   name: string
//   email: string
// }

type NonStringProperties = OmitByType<SearchableStudent, string>
// Result: {
//   grade: number
//   enrollmentDate: Date
//   isActive: boolean
// }

// Required/Optional property manipulation
type RequiredKeys<T> = {
  [K in keyof T]-?: {} extends Pick<T, K> ? never : K
}[keyof T]

type OptionalKeys<T> = {
  [K in keyof T]-?: {} extends Pick<T, K> ? K : never
}[keyof T]

type RequiredProperties<T> = Pick<T, RequiredKeys<T>>
type OptionalProperties<T> = Pick<T, OptionalKeys<T>>

// Split interface into required and optional parts
interface MixedInterface {
  required1: string
  required2: number
  optional1?: string
  optional2?: boolean
}

type RequiredPart = RequiredProperties<MixedInterface>
// Result: { required1: string; required2: number }

type OptionalPart = OptionalProperties<MixedInterface>
// Result: { optional1?: string; optional2?: boolean }
```

### 2. Validation and Constraint Utilities
```typescript
// Validate object shape
type ValidateShape<T, Shape> = {
  [K in keyof Shape]: K extends keyof T
    ? T[K] extends Shape[K]
      ? T[K]
      : never
    : never
} & {
  [K in Exclude<keyof T, keyof Shape>]: never
}

// Ensure all properties are present
type Complete<T> = {
  [K in keyof Required<T>]: T[K]
}

// Branded types for type safety
declare const __brand: unique symbol
type Brand<T, TBrand> = T & { [__brand]: TBrand }

// EdTech branded types
type StudentId = Brand<string, 'StudentId'>
type CourseId = Brand<string, 'CourseId'>
type LessonId = Brand<string, 'LessonId'>

// Type-safe ID relationships
interface TypedRelationships {
  student: StudentId
  enrolledCourses: CourseId[]
  completedLessons: LessonId[]
}

// Utility to create branded IDs
function createStudentId(id: string): StudentId {
  return id as StudentId
}

function createCourseId(id: string): CourseId {
  return id as CourseId
}

// Usage prevents mixing different ID types
const studentId = createStudentId('student-123')
const courseId = createCourseId('course-456')

// This would be a TypeScript error:
// function enrollStudent(studentId: StudentId, courseId: StudentId) { ... }
// enrollStudent(studentId, courseId) // ❌ courseId is not StudentId
```

### 3. Advanced Filtering and Transformation
```typescript
// Filter keys by value type and condition
type FilterKeys<T, C> = {
  [K in keyof T]: T[K] extends C ? K : never
}[keyof T]

// Non-nullable version
type NonNullableKeys<T> = FilterKeys<T, NonNullable<T[keyof T]>>

// Function property keys
type FunctionKeys<T> = FilterKeys<T, (...args: any[]) => any>

// Create method interface from class
type Methods<T> = Pick<T, FunctionKeys<T>>

// EdTech student class example
class StudentManager {
  private students: Student[] = []

  addStudent(student: Student): void {
    this.students.push(student)
  }

  getStudent(id: string): Student | undefined {
    return this.students.find(s => s.id === id)
  }

  updateStudent(id: string, updates: Partial<Student>): void {
    const index = this.students.findIndex(s => s.id === id)
    if (index !== -1) {
      this.students[index] = { ...this.students[index], ...updates }
    }
  }

  deleteStudent(id: string): boolean {
    const index = this.students.findIndex(s => s.id === id)
    if (index !== -1) {
      this.students.splice(index, 1)
      return true
    }
    return false
  }

  get studentCount(): number {
    return this.students.length
  }
}

type StudentManagerMethods = Methods<StudentManager>
// Result: {
//   addStudent: (student: Student) => void
//   getStudent: (id: string) => Student | undefined
//   updateStudent: (id: string, updates: Partial<Student>) => void
//   deleteStudent: (id: string) => boolean
// }

// Transform async methods
type Promisify<T> = {
  [K in keyof T]: T[K] extends (...args: infer A) => infer R
    ? R extends Promise<any>
      ? T[K]
      : (...args: A) => Promise<R>
    : T[K]
}

type AsyncStudentManager = Promisify<StudentManagerMethods>
// Result: All methods return Promises
```

## 🧪 Testing Mapped Types

### Type-Level Testing
```typescript
// Test utilities
type Expect<T extends true> = T
type Equal<X, Y> = (<T>() => T extends X ? 1 : 2) extends (<T>() => T extends Y ? 1 : 2) ? true : false

// Test form state generation
type TestFormState = Expect<Equal<
  keyof FormState<{ name: string; age: number }>,
  'name' | 'age'
>>

// Test key remapping
type TestGetters = Expect<Equal<
  keyof Getters<{ name: string; age: number }>,
  'getName' | 'getAge'
>>

// Test branded types
type TestBrandedTypes = Expect<Equal<
  StudentId extends string ? true : false,
  true
>>

// Test deep transformations
type TestDeepReadonly = Expect<Equal<
  DeepReadonly<{ nested: { value: string } }>,
  { readonly nested: { readonly value: string } }
>>
```

### Runtime Testing
```typescript
import { describe, it, expect } from 'vitest'

describe('Mapped Types in Practice', () => {
  it('should manage form state correctly', () => {
    const formManager = new FormManager(
      { name: 'John', age: 25 },
      {
        name: { required: true, validate: (v) => v.length < 2 ? 'Too short' : undefined },
        age: { required: true, validate: (v) => v < 0 ? 'Invalid age' : undefined }
      }
    )

    expect(formManager.getValue('name')).toBe('John')
    expect(formManager.getValue('age')).toBe(25)

    formManager.setValue('name', 'Jane')
    expect(formManager.getValue('name')).toBe('Jane')

    const formData = formManager.getFormData()
    expect(formData).toEqual({ name: 'Jane', age: 25 })
  })

  it('should handle branded types correctly', () => {
    const studentId = createStudentId('student-123')
    const courseId = createCourseId('course-456')

    // These should be treated as different types
    expect(typeof studentId).toBe('string')
    expect(typeof courseId).toBe('string')
    
    // But TypeScript should prevent mixing them
    // This would be caught at compile time
  })

  it('should transform objects correctly', () => {
    const student: Student = {
      id: 'student-1',
      name: 'John Doe',
      email: 'john@example.com',
      grade: 10,
      enrollmentDate: new Date('2024-01-01')
    }

    // Test serialization logic
    const serialized = JSON.stringify(student)
    const parsed = JSON.parse(serialized)
    
    expect(typeof parsed.enrollmentDate).toBe('string')
    expect(parsed.enrollmentDate).toBe('2024-01-01T00:00:00.000Z')
  })
})
```

## 📊 Performance Optimization for Mapped Types

### Compilation Performance
```typescript
// ✅ Use type aliases for complex mapped types
type ComplexTransformation<T> = {
  [K in keyof T]: T[K] extends string ? Uppercase<T[K]> : T[K]
}

// Cache the result
type TransformedStudent = ComplexTransformation<Student>

// ✅ Avoid deeply nested mapped types
// Instead of:
type BadDeepTransform<T> = {
  [K in keyof T]: T[K] extends object ? {
    [P in keyof T[K]]: T[K][P] extends object ? {
      [Q in keyof T[K][P]]: T[K][P][Q]
    } : T[K][P]
  } : T[K]
}

// Use:
type DeepTransformStep1<T> = {
  [K in keyof T]: T[K] extends object ? TransformObject<T[K]> : T[K]
}

type TransformObject<T> = {
  [K in keyof T]: T[K] extends object ? TransformNestedObject<T[K]> : T[K]
}

type TransformNestedObject<T> = {
  [K in keyof T]: T[K]
}

// ✅ Use conditional types to limit transformation scope
type SelectiveTransform<T> = {
  [K in keyof T]: K extends 'id' | 'createdAt' | 'updatedAt' 
    ? T[K]  // Don't transform these
    : T[K] extends string 
    ? Uppercase<T[K]>  // Transform only strings
    : T[K]  // Leave others unchanged
}
```

---

### 📖 Document Navigation

| Previous | Current | Next |
|----------|---------|------|
| [Conditional Types Mastery](./conditional-types-mastery.md) | **Mapped Types & Utilities** | [Template Literal Types](./template-literal-types.md) |

---

*Last updated: January 2025*  
*Comprehensive patterns for EdTech form management, state transformation, and type safety*