# Troubleshooting Guide - Advanced TypeScript Techniques

## 🎯 Overview

This comprehensive troubleshooting guide addresses common issues encountered when implementing advanced TypeScript techniques in EdTech platforms and enterprise applications. Includes diagnostic strategies, solutions, and prevention techniques.

## 🚨 Compilation Errors and Solutions

### 1. "Type instantiation is excessively deep and possibly infinite"

#### Problem
```typescript
// ❌ Problematic recursive type without depth limit
type DeepReadonly<T> = {
  readonly [P in keyof T]: T[P] extends object ? DeepReadonly<T[P]> : T[P]
}

interface Course {
  id: string
  title: string
  modules: Module[]
}

interface Module {
  id: string
  title: string
  course: Course  // Circular reference
  lessons: Lesson[]
}

interface Lesson {
  id: string
  title: string
  module: Module  // Another circular reference
}

type ReadonlyCourse = DeepReadonly<Course>  // ❌ Error: Type instantiation is excessively deep
```

#### Solutions

**Solution 1: Limit Recursion Depth**
```typescript
// ✅ Fixed with depth limiting
type DeepReadonly<T, Depth extends number = 3> = 
  Depth extends 0 
    ? T
    : T extends object
    ? {
        readonly [P in keyof T]: DeepReadonly<T[P], Prev<Depth>>
      }
    : T

type Prev<T extends number> = 
  T extends 4 ? 3 :
  T extends 3 ? 2 :
  T extends 2 ? 1 :
  T extends 1 ? 0 : 0

// Now works with limited depth
type ReadonlyCourse = DeepReadonly<Course, 2>
```

**Solution 2: Break Circular References**
```typescript
// ✅ Better: Avoid circular references in type definitions
interface CourseData {
  id: string
  title: string
  moduleIds: string[]  // Reference by ID instead
}

interface ModuleData {
  id: string
  title: string
  courseId: string     // Reference by ID instead
  lessonIds: string[]  // Reference by ID instead
}

interface LessonData {
  id: string
  title: string
  moduleId: string     // Reference by ID instead
}

// Now DeepReadonly works fine
type ReadonlyCourseData = DeepReadonly<CourseData>
```

**Solution 3: Use Interface Instead of Type for Recursive Structures**
```typescript
// ✅ Interfaces handle recursion better
interface ReadonlyNestedCourse {
  readonly id: string
  readonly title: string
  readonly modules: readonly ReadonlyNestedModule[]
}

interface ReadonlyNestedModule {
  readonly id: string
  readonly title: string
  readonly lessons: readonly ReadonlyNestedLesson[]
}

interface ReadonlyNestedLesson {
  readonly id: string
  readonly title: string
}
```

### 2. "Excessive stack depth comparing types"

#### Problem
```typescript
// ❌ Complex conditional type causing stack overflow
type ComplexConditional<T> = 
  T extends string ? 
    T extends `${infer P}@${infer D}` ? 
      D extends 'gmail.com' | 'yahoo.com' | 'hotmail.com' | 'outlook.com' ? 
        T extends `${P}@gmail.com` ? 'gmail' :
        T extends `${P}@yahoo.com` ? 'yahoo' :
        T extends `${P}@hotmail.com` ? 'hotmail' :
        T extends `${P}@outlook.com` ? 'outlook' :
        never :
      'other' :
    'invalid' :
  never

type TestMany = ComplexConditional<'user@gmail.com' | 'user@yahoo.com' | 'user@hotmail.com'>  // ❌ Stack overflow
```

#### Solutions

**Solution 1: Simplify Conditional Logic**
```typescript
// ✅ Break down into smaller, focused types
type ExtractDomain<T extends string> = T extends `${string}@${infer D}` ? D : never

type ClassifyDomain<T extends string> = 
  T extends 'gmail.com' ? 'gmail' :
  T extends 'yahoo.com' ? 'yahoo' :
  T extends 'hotmail.com' ? 'hotmail' :
  T extends 'outlook.com' ? 'outlook' :
  'other'

type ClassifyEmail<T extends string> = ClassifyDomain<ExtractDomain<T>>

// Now works efficiently
type TestClassification = ClassifyEmail<'user@gmail.com'>  // 'gmail'
```

**Solution 2: Use Lookup Types**
```typescript
// ✅ More efficient with lookup types
interface DomainClassification {
  'gmail.com': 'gmail'
  'yahoo.com': 'yahoo'
  'hotmail.com': 'hotmail'
  'outlook.com': 'outlook'
}

type ClassifyEmailEfficient<T extends string> = 
  ExtractDomain<T> extends keyof DomainClassification
    ? DomainClassification[ExtractDomain<T>]
    : 'other'

type EfficientTest = ClassifyEmailEfficient<'user@gmail.com'>  // 'gmail'
```

### 3. "Cannot find name" for Generated Types

#### Problem
```typescript
// ❌ Generated types not being recognized
type StudentEvents = {
  enrolled: { courseId: string; timestamp: Date }
  completed: { lessonId: string; score: number }
}

type EventHandlers = {
  [K in keyof StudentEvents as `on${Capitalize<string & K>}`]: (data: StudentEvents[K]) => void
}

// ❌ Error: Cannot find name 'onEnrolled'
const handlers: EventHandlers = {
  onEnrolled: (data) => console.log(data.courseId),  // Type error
  onCompleted: (data) => console.log(data.score)
}
```

#### Solutions

**Solution 1: Use Type Assertion Temporarily**
```typescript
// ✅ Quick fix with assertion
const handlers = {
  onEnrolled: (data: StudentEvents['enrolled']) => console.log(data.courseId),
  onCompleted: (data: StudentEvents['completed']) => console.log(data.score)
} as EventHandlers
```

**Solution 2: Create Explicit Interface**
```typescript
// ✅ Better: Create explicit interface for better IDE support
interface StudentEventHandlers {
  onEnrolled: (data: StudentEvents['enrolled']) => void
  onCompleted: (data: StudentEvents['completed']) => void
}

const handlers: StudentEventHandlers = {
  onEnrolled: (data) => console.log(data.courseId),   // ✅ Works
  onCompleted: (data) => console.log(data.score)     // ✅ Works
}
```

**Solution 3: Use Module Declaration**
```typescript
// ✅ Advanced: Declare types globally if needed
declare global {
  interface StudentEventHandlers {
    onEnrolled: (data: StudentEvents['enrolled']) => void
    onCompleted: (data: StudentEvents['completed']) => void
  }
}

// Now available throughout the project
const handlers: StudentEventHandlers = {
  onEnrolled: (data) => console.log(data.courseId),
  onCompleted: (data) => console.log(data.score)
}
```

## ⚡ Performance Issues and Optimizations

### 1. Slow TypeScript Compilation

#### Diagnosis
```bash
# Enable TypeScript compiler diagnostics
tsc --diagnostics
# Shows: Files: 250, Lines: 50000, Nodes: 180000, Identifiers: 40000
# Check time: 15000ms

# More detailed analysis
tsc --extendedDiagnostics
# Shows specific phase timings
```

#### Solutions

**Solution 1: Optimize tsconfig.json**
```json
{
  "compilerOptions": {
    "target": "ES2020",           // Use modern target
    "module": "ESNext",
    "moduleResolution": "bundler", // Faster resolution
    "skipLibCheck": true,         // Skip type checking of .d.ts files
    "skipDefaultLibCheck": true,
    "incremental": true,          // Enable incremental compilation
    "tsBuildInfoFile": "./dist/.tsbuildinfo",
    
    // Performance optimizations
    "importsNotUsedAsValues": "remove",
    "preserveValueImports": false,
    
    // Exclude unnecessary files
    "exclude": [
      "node_modules",
      "dist",
      "build",
      "**/*.test.ts",
      "**/*.spec.ts"
    ]
  }
}
```

**Solution 2: Use Type Aliases for Complex Types**
```typescript
// ❌ Slow: Repeating complex types
function processStudentData(
  data: { 
    [K in keyof Student]: Student[K] extends string ? Uppercase<Student[K]> : Student[K] 
  }
): void { }

function validateStudentData(
  data: { 
    [K in keyof Student]: Student[K] extends string ? Uppercase<Student[K]> : Student[K] 
  }
): boolean { return true }

// ✅ Fast: Cache complex types
type ProcessedStudent = {
  [K in keyof Student]: Student[K] extends string ? Uppercase<Student[K]> : Student[K]
}

function processStudentData(data: ProcessedStudent): void { }
function validateStudentData(data: ProcessedStudent): boolean { return true }
```

**Solution 3: Project References for Large Codebases**
```json
// tsconfig.json (root)
{
  "references": [
    { "path": "./packages/core" },
    { "path": "./packages/ui" },
    { "path": "./packages/api" }
  ],
  "files": []
}

// packages/core/tsconfig.json
{
  "extends": "../../tsconfig.base.json",
  "compilerOptions": {
    "composite": true,
    "outDir": "./dist",
    "rootDir": "./src"
  },
  "include": ["src/**/*"]
}
```

### 2. Large Bundle Size from Types

#### Problem
```typescript
// ❌ Types that generate large runtime code
enum LargeEnum {
  VALUE_1 = "value_1",
  VALUE_2 = "value_2",
  // ... 500 more values
  VALUE_500 = "value_500"
}

// ❌ Large object for type checking
const VALID_DOMAINS = {
  'gmail.com': true,
  'yahoo.com': true,
  // ... 1000 more domains
} as const

type ValidDomain = keyof typeof VALID_DOMAINS
```

#### Solutions

**Solution 1: Use const assertions and type-only imports**
```typescript
// ✅ Type-only enum
const enum CompactEnum {
  VALUE_1 = "value_1",
  VALUE_2 = "value_2",
  // ... more values (no runtime overhead)
}

// ✅ Or use union types
type ValidDomain = 'gmail.com' | 'yahoo.com' | 'outlook.com'  // No runtime code

// ✅ Type-only imports
import type { LargeType } from './types'  // Won't be in bundle
```

**Solution 2: Runtime validation separation**
```typescript
// ✅ Separate type definitions from runtime validation
// types.ts - Type-only file
export type ValidDomain = 'gmail.com' | 'yahoo.com' | 'outlook.com'

// validators.ts - Runtime validation
export const validateDomain = (domain: string): domain is ValidDomain => {
  const validDomains = new Set(['gmail.com', 'yahoo.com', 'outlook.com'])
  return validDomains.has(domain)
}

// usage.ts
import type { ValidDomain } from './types'    // Type-only import
import { validateDomain } from './validators'  // Runtime import

function processDomain(domain: string) {
  if (validateDomain(domain)) {
    // domain is now typed as ValidDomain
    return domain.toUpperCase()
  }
  throw new Error('Invalid domain')
}
```

## 🔧 Runtime Type Issues

### 1. Type Guards Not Working as Expected

#### Problem
```typescript
// ❌ Problematic type guard
function isStudent(user: any): user is Student {
  return user && user.grade !== undefined  // Too simple
}

const userData = { id: '1', name: 'John', grade: 'A' }  // Wrong type for grade
if (isStudent(userData)) {
  // TypeScript thinks this is safe, but it's not
  console.log(`Grade: ${userData.grade}`)  // Runtime error: expected number
}
```

#### Solutions

**Solution 1: Comprehensive Type Guards**
```typescript
// ✅ Robust type guard
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
    (user as any).grade >= 1 &&
    (user as any).grade <= 12 &&
    (user as any).createdAt instanceof Date &&
    (user as any).updatedAt instanceof Date
  )
}

// Test with proper validation
const userData = { id: '1', name: 'John', grade: 'A' }
if (isStudent(userData)) {
  console.log(`Grade: ${userData.grade}`)  // This block won't execute
} else {
  console.log('Invalid student data')  // This will execute
}
```

**Solution 2: Use Runtime Validation Libraries**
```typescript
// ✅ Using Zod for runtime validation
import { z } from 'zod'

const StudentSchema = z.object({
  id: z.string(),
  name: z.string().min(1),
  email: z.string().email(),
  grade: z.number().int().min(1).max(12),
  createdAt: z.date(),
  updatedAt: z.date()
})

type Student = z.infer<typeof StudentSchema>

function isStudent(user: unknown): user is Student {
  return StudentSchema.safeParse(user).success
}

function assertIsStudent(user: unknown): asserts user is Student {
  StudentSchema.parse(user)  // Throws if invalid
}

// Usage
try {
  assertIsStudent(userData)
  console.log(`Grade: ${userData.grade}`)  // Type-safe and runtime-safe
} catch (error) {
  console.error('Invalid student data:', error.message)
}
```

### 2. Generic Constraints Not Working

#### Problem
```typescript
// ❌ Generic constraint not specific enough
function processEntity<T extends { id: string }>(entity: T): T {
  // Assuming entity has more properties than just id
  return {
    ...entity,
    updatedAt: new Date()  // ❌ Error: Type 'Date' is not assignable to type 'T'
  }
}
```

#### Solutions

**Solution 1: More Specific Constraints**
```typescript
// ✅ Better constraint definition
interface BaseEntity {
  id: string
  updatedAt: Date
}

function processEntity<T extends BaseEntity>(entity: T): T {
  return {
    ...entity,
    updatedAt: new Date()  // ✅ Now works
  }
}

// Or use intersection types
function processEntityAlternative<T extends { id: string }>(
  entity: T
): T & { updatedAt: Date } {
  return {
    ...entity,
    updatedAt: new Date()
  }
}
```

**Solution 2: Conditional Return Types**
```typescript
// ✅ Use conditional types for flexible returns
type ProcessedEntity<T> = T extends { updatedAt: Date }
  ? T
  : T & { updatedAt: Date }

function processEntity<T extends { id: string }>(entity: T): ProcessedEntity<T> {
  if ('updatedAt' in entity) {
    return { ...entity, updatedAt: new Date() } as ProcessedEntity<T>
  }
  return { ...entity, updatedAt: new Date() } as ProcessedEntity<T>
}
```

## 🚫 Common Anti-Patterns and Fixes

### 1. Overuse of `any`

#### Problem
```typescript
// ❌ Heavy use of any defeats TypeScript's purpose
function processApiResponse(response: any): any {
  if (response.success) {
    return response.data
  }
  throw new Error(response.error)
}

const studentData = processApiResponse(apiCall())  // No type safety
console.log(studentData.invalidProperty)  // Runtime error waiting to happen
```

#### Solutions

**Solution 1: Use Proper Generic Types**
```typescript
// ✅ Type-safe API response handling
type ApiResponse<T> = 
  | { success: true; data: T }
  | { success: false; error: string }

function processApiResponse<T>(response: ApiResponse<T>): T {
  if (response.success) {
    return response.data  // Type-safe
  }
  throw new Error(response.error)
}

// Usage with proper types
const studentResponse: ApiResponse<Student> = await apiCall()
const studentData = processApiResponse(studentResponse)  // Typed as Student
console.log(studentData.name)  // ✅ Type-safe property access
```

**Solution 2: Gradual Migration from `any`**
```typescript
// ✅ Step-by-step migration strategy
// Step 1: Replace any with unknown
function processData(data: unknown): unknown {
  // Forces type checking
  if (typeof data === 'object' && data !== null) {
    return data
  }
  return null
}

// Step 2: Add type guards
function processDataWithGuards(data: unknown): Student | null {
  if (isStudent(data)) {
    return data  // Now typed as Student
  }
  return null
}

// Step 3: Full type safety
function processStudentData(data: Student): ProcessedStudent {
  return transformStudent(data)
}
```

### 2. Incorrect Generic Variance Usage

#### Problem
```typescript
// ❌ Incorrect variance usage
interface Repository<T> {
  items: T[]  // Invariant - can cause issues
  add(item: T): void
  get(): T[]
}

const studentRepo: Repository<Student> = new StudentRepository()
const userRepo: Repository<BaseUser> = studentRepo  // ❌ Not safe for invariant type
```

#### Solutions

**Solution 1: Use Covariant Read-Only Interfaces**
```typescript
// ✅ Separate read and write operations
interface ReadOnlyRepository<out T> {  // Covariant
  readonly items: readonly T[]
  get(): readonly T[]
  find(predicate: (item: T) => boolean): T | undefined
}

interface WriteRepository<in T> {  // Contravariant
  add(item: T): void
  update(item: T): void
  delete(id: string): void
}

interface Repository<T> extends ReadOnlyRepository<T>, WriteRepository<T> {}

// Now this works safely
const studentReadRepo: ReadOnlyRepository<Student> = new StudentRepository()
const userReadRepo: ReadOnlyRepository<BaseUser> = studentReadRepo  // ✅ Safe covariance
```

**Solution 2: Use Branded Types for Strict Typing**
```typescript
// ✅ Branded types prevent incorrect assignments
declare const __repositoryBrand: unique symbol
type BrandedRepository<T> = Repository<T> & { [__repositoryBrand]: T }

function createStudentRepository(): BrandedRepository<Student> {
  return new StudentRepository() as BrandedRepository<Student>
}

function createUserRepository(): BrandedRepository<BaseUser> {
  return new UserRepository() as BrandedRepository<BaseUser>
}

const studentRepo = createStudentRepository()
const userRepo = createUserRepository()
// const mixedRepo: BrandedRepository<BaseUser> = studentRepo  // ❌ Prevented by branding
```

## 🔍 Debugging Advanced Types

### 1. Type Debugging Utilities

```typescript
// ✅ Helpful debugging types
type Debug<T> = T extends (...args: any[]) => any
  ? T
  : T extends object
  ? { [K in keyof T]: Debug<T[K]> }
  : T

type Expand<T> = T extends (...args: infer A) => infer R
  ? (...args: Expand<A>) => Expand<R>
  : T extends infer O
  ? { [K in keyof O]: O[K] }
  : never

type DeepExpand<T> = T extends (...args: infer A) => infer R
  ? (...args: DeepExpand<A>) => DeepExpand<R>
  : T extends object
  ? T extends infer O
    ? { [K in keyof O]: DeepExpand<O[K]> }
    : never
  : T

// Usage for debugging complex types
type ComplexType = {
  nested: {
    deep: {
      property: string
    }
  }
}

type DebugComplex = Debug<ComplexType>     // Expands for inspection
type ExpandedComplex = Expand<ComplexType> // Different expansion strategy
```

### 2. Conditional Type Debugging

```typescript
// ✅ Debug conditional types step by step
type DebugConditional<T> = 
  T extends string 
    ? { matched: 'string'; type: T }
    : T extends number
    ? { matched: 'number'; type: T }
    : T extends boolean
    ? { matched: 'boolean'; type: T }
    : { matched: 'other'; type: T }

// Test with different types
type TestString = DebugConditional<'hello'>   // { matched: 'string'; type: 'hello' }
type TestNumber = DebugConditional<42>        // { matched: 'number'; type: 42 }
type TestOther = DebugConditional<Date>       // { matched: 'other'; type: Date }
```

### 3. IDE Configuration for Better Debugging

```json
// .vscode/settings.json
{
  "typescript.preferences.includePackageJsonAutoImports": "off",
  "typescript.preferences.useAliasesForRenames": false,
  "typescript.displayPartsForJSDoc": true,
  "typescript.suggest.includeAutomaticOptionalChainCompletions": false,
  
  // Show more detailed type information
  "typescript.preferences.includeCompletionsForModuleExports": true,
  "typescript.preferences.includeCompletionsWithInsertText": true,
  
  // Better error reporting
  "typescript.reportStyleChecksAsWarnings": true,
  "typescript.validate.enable": true
}
```

## 📊 Monitoring and Prevention

### 1. Type Coverage Monitoring

```bash
# Install type coverage tool
npm install -g type-coverage

# Check type coverage
type-coverage --detail

# Example output:
# 2367/2411 95.05%
# type-coverage success.
# path/to/file.ts:23:10 error TS7006: Parameter 'data' implicitly has an 'any' type.
```

### 2. ESLint Rules for Type Safety

```json
// .eslintrc.json
{
  "extends": [
    "@typescript-eslint/recommended",
    "@typescript-eslint/recommended-requiring-type-checking"
  ],
  "rules": {
    "@typescript-eslint/no-explicit-any": "error",
    "@typescript-eslint/no-unsafe-assignment": "error",
    "@typescript-eslint/no-unsafe-call": "error",
    "@typescript-eslint/no-unsafe-member-access": "error",
    "@typescript-eslint/no-unsafe-return": "error",
    "@typescript-eslint/prefer-as-const": "error",
    "@typescript-eslint/prefer-readonly": "error",
    "@typescript-eslint/prefer-readonly-parameter-types": "warn",
    "@typescript-eslint/strict-boolean-expressions": "error"
  }
}
```

### 3. Automated Type Testing

```typescript
// type-tests/advanced-types.test.ts
import { Expect, Equal } from '../src/test-utils'

// Automated testing of type relationships
type TypeTests = [
  // Test API response types
  Expect<Equal<
    ApiResponse<Student, 'NOT_FOUND'>,
    | { success: true; data: Student }
    | { success: false; error: 'NOT_FOUND' }
  >>,
  
  // Test form state generation
  Expect<Equal<
    keyof FormState<{ name: string; age: number }>,
    'name' | 'age'
  >>,
  
  // Test branded types distinctness
  Expect<Equal<StudentId extends CourseId ? false : true, true>>,
  
  // Test conditional type behavior
  Expect<Equal<
    ValidationResult<string>,
    'REQUIRED' | 'TOO_SHORT' | 'TOO_LONG' | 'INVALID_FORMAT'
  >>
]

// This file will show TypeScript errors if any type tests fail
```

---

### 📖 Document Navigation

| Previous | Current | Next |
|----------|---------|------|
| [Comparison Analysis](./comparison-analysis.md) | **Troubleshooting Guide** | [README](./README.md) |

---

*Last updated: January 2025*  
*Comprehensive solutions for advanced TypeScript development challenges*