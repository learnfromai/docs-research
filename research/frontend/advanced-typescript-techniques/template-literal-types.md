# Template Literal Types - Advanced TypeScript Techniques

## 🎯 Overview

Template literal types (introduced in TypeScript 4.1) enable string manipulation and validation at the type level. They're crucial for building type-safe routing systems, configuration validation, and dynamic API endpoints in EdTech platforms. This document covers advanced patterns for leveraging template literals in production applications.

## 🔧 Fundamental Template Literal Patterns

### Basic String Manipulation
```typescript
// Basic template literal type syntax
type Greeting<T extends string> = `Hello, ${T}!`

type WelcomeMessage = Greeting<'Student'>  // "Hello, Student!"
type AdminMessage = Greeting<'Admin'>      // "Hello, Admin!"

// String transformation utilities
type Uppercase<S extends string> = S extends `${infer First}${infer Rest}`
  ? `${Uppercase<First>}${Uppercase<Rest>}`
  : S

type Lowercase<S extends string> = S extends `${infer First}${infer Rest}`
  ? `${Lowercase<First>}${Lowercase<Rest>}`
  : S

type Capitalize<S extends string> = S extends `${infer First}${infer Rest}`
  ? `${Uppercase<First>}${Lowercase<Rest>}`
  : S

// EdTech example: Dynamic role-based greetings
type UserRole = 'student' | 'instructor' | 'admin' | 'parent'
type RoleGreeting<T extends UserRole> = `Welcome, ${Capitalize<T>}!`

type StudentGreeting = RoleGreeting<'student'>      // "Welcome, Student!"
type InstructorGreeting = RoleGreeting<'instructor'> // "Welcome, Instructor!"
```

### String Parsing and Validation
```typescript
// Email validation at type level
type IsEmail<T extends string> = T extends `${string}@${string}.${string}` ? true : false

type ValidEmail = IsEmail<'user@example.com'>    // true
type InvalidEmail = IsEmail<'not-an-email'>      // false

// Extract domain from email
type ExtractDomain<T extends string> = T extends `${string}@${infer Domain}` ? Domain : never

type EmailDomain = ExtractDomain<'student@university.edu'>  // "university.edu"

// Advanced: Educational email validation
type EducationalDomains = 'edu' | 'ac.uk' | 'edu.au' | 'ac.jp'
type IsEducationalEmail<T extends string> = 
  T extends `${string}@${string}.${EducationalDomains}` ? true : false

type ValidEduEmail = IsEducationalEmail<'student@university.edu'>     // true
type InvalidEduEmail = IsEducationalEmail<'user@gmail.com'>           // false
```

## 📚 EdTech Platform Routing and API Patterns

### 1. Type-Safe Routing System
```typescript
// Base route structure
type HTTPMethod = 'GET' | 'POST' | 'PUT' | 'DELETE' | 'PATCH'
type APIVersion = 'v1' | 'v2'
type ResourceType = 'students' | 'courses' | 'lessons' | 'assessments' | 'instructors'

// Dynamic route generation
type APIRoute<
  TMethod extends HTTPMethod = HTTPMethod,
  TVersion extends APIVersion = APIVersion,
  TResource extends ResourceType = ResourceType
> = `${TMethod} /api/${TVersion}/${TResource}`

// Specific route examples
type GetStudents = APIRoute<'GET', 'v1', 'students'>        // "GET /api/v1/students"
type CreateCourse = APIRoute<'POST', 'v1', 'courses'>       // "POST /api/v1/courses"
type UpdateLesson = APIRoute<'PUT', 'v1', 'lessons'>        // "PUT /api/v1/lessons"

// Dynamic parameters
type WithId<T extends string> = `${T}/:id`
type WithQuery<T extends string, Q extends string = string> = `${T}?${Q}`
type WithFragment<T extends string> = `${T}#${string}`

// Complex route patterns
type StudentDetailRoute = WithId<'/api/v1/students'>                    // "/api/v1/students/:id"
type CourseSearchRoute = WithQuery<'/api/v1/courses', 'search=${string}'> // "/api/v1/courses?search=${string}"
type LessonWithAnchor = WithFragment<'/lessons/intro-to-typescript'>    // "/lessons/intro-to-typescript#${string}"

// Nested resource routes
type NestedRoute<
  TParent extends ResourceType,
  TChild extends ResourceType
> = `/api/v1/${TParent}/:${TParent}Id/${TChild}`

type StudentCoursesRoute = NestedRoute<'students', 'courses'>  // "/api/v1/students/:studentsId/courses"
type CourseModulesRoute = NestedRoute<'courses', 'lessons'>    // "/api/v1/courses/:coursesId/lessons"

// Route parameter extraction
type ExtractParams<T extends string> = 
  T extends `${string}:${infer Param}/${infer Rest}`
    ? Param | ExtractParams<Rest>
    : T extends `${string}:${infer Param}`
    ? Param
    : never

type StudentRouteParams = ExtractParams<'/api/v1/students/:id/courses/:courseId'>
// Result: "id" | "courseId"
```

### 2. Configuration and Environment Variables
```typescript
// Environment-specific configuration
type Environment = 'development' | 'staging' | 'production'
type ServiceName = 'database' | 'redis' | 'api' | 'storage' | 'email'
type ConfigKey = 'url' | 'key' | 'secret' | 'port' | 'timeout'

// Dynamic environment variable names
type EnvVarName<
  TEnv extends Environment,
  TService extends ServiceName,
  TKey extends ConfigKey
> = `${Uppercase<TEnv>}_${Uppercase<TService>}_${Uppercase<TKey>}`

// Examples
type DevDatabaseUrl = EnvVarName<'development', 'database', 'url'>
// Result: "DEVELOPMENT_DATABASE_URL"

type ProdApiKey = EnvVarName<'production', 'api', 'key'>
// Result: "PRODUCTION_API_KEY"

// Configuration object generation
type ConfigObject<TEnv extends Environment> = {
  [TService in ServiceName]: {
    [TKey in ConfigKey as EnvVarName<TEnv, TService, TKey>]: string
  }
}

type DevelopmentConfig = ConfigObject<'development'>
// Result: {
//   database: {
//     DEVELOPMENT_DATABASE_URL: string
//     DEVELOPMENT_DATABASE_KEY: string
//     // ... etc
//   },
//   redis: {
//     DEVELOPMENT_REDIS_URL: string
//     // ... etc
//   }
//   // ... etc
// }

// Type-safe environment variable access
declare global {
  namespace NodeJS {
    interface ProcessEnv {
      [K in EnvVarName<Environment, ServiceName, ConfigKey>]: string
    }
  }
}

// Usage with full type safety
const databaseUrl = process.env.DEVELOPMENT_DATABASE_URL  // string
const redisPort = process.env.PRODUCTION_REDIS_PORT      // string
```

### 3. Event System with Template Literals
```typescript
// Event naming patterns
type EventCategory = 'user' | 'course' | 'lesson' | 'assessment' | 'system'
type EventAction = 'created' | 'updated' | 'deleted' | 'viewed' | 'completed'

// Dynamic event names
type EventName<
  TCategory extends EventCategory,
  TAction extends EventAction
> = `${TCategory}.${TAction}`

// Specific events
type UserCreated = EventName<'user', 'created'>              // "user.created"
type CourseCompleted = EventName<'course', 'completed'>      // "course.completed"
type LessonViewed = EventName<'lesson', 'viewed'>            // "lesson.viewed"

// Event payload mapping
type EventPayloads = {
  'user.created': { userId: string; email: string; role: string }
  'user.updated': { userId: string; changes: Record<string, any> }
  'course.created': { courseId: string; instructorId: string; title: string }
  'course.completed': { courseId: string; studentId: string; completionDate: Date }
  'lesson.viewed': { lessonId: string; studentId: string; duration: number }
  'assessment.completed': { assessmentId: string; studentId: string; score: number }
}

// Event handler type generation
type EventHandler<T extends keyof EventPayloads> = (payload: EventPayloads[T]) => void

// Event emitter with type safety
class TypedEventEmitter {
  private handlers: {
    [K in keyof EventPayloads]?: EventHandler<K>[]
  } = {}

  on<T extends keyof EventPayloads>(event: T, handler: EventHandler<T>): void {
    if (!this.handlers[event]) {
      this.handlers[event] = []
    }
    this.handlers[event]!.push(handler)
  }

  emit<T extends keyof EventPayloads>(event: T, payload: EventPayloads[T]): void {
    const eventHandlers = this.handlers[event]
    if (eventHandlers) {
      eventHandlers.forEach(handler => handler(payload))
    }
  }

  off<T extends keyof EventPayloads>(event: T, handler: EventHandler<T>): void {
    const eventHandlers = this.handlers[event]
    if (eventHandlers) {
      const index = eventHandlers.indexOf(handler)
      if (index !== -1) {
        eventHandlers.splice(index, 1)
      }
    }
  }
}

// Usage with full type safety
const emitter = new TypedEventEmitter()

emitter.on('user.created', (payload) => {
  // payload is typed as { userId: string; email: string; role: string }
  console.log(`New user created: ${payload.email}`)
})

emitter.emit('user.created', {
  userId: 'user-123',
  email: 'student@university.edu',
  role: 'student'
})
```

## 🚀 Advanced Template Literal Patterns

### 1. SQL Query Builder with Type Safety
```typescript
// SQL operation types
type SQLOperation = 'SELECT' | 'INSERT' | 'UPDATE' | 'DELETE'
type ComparisonOperator = '=' | '!=' | '>' | '<' | '>=' | '<=' | 'LIKE' | 'IN'

// Table and column definitions
interface StudentTable {
  id: string
  name: string
  email: string
  grade: number
  enrollment_date: Date
}

interface CourseTable {
  id: string
  title: string
  description: string
  instructor_id: string
  created_at: Date
}

type Tables = {
  students: StudentTable
  courses: CourseTable
}

// Dynamic SQL query generation
type SelectQuery<
  TTable extends keyof Tables,
  TColumns extends keyof Tables[TTable] = keyof Tables[TTable]
> = `SELECT ${TColumns extends string ? TColumns : string} FROM ${TTable & string}`

type WhereClause<
  TTable extends keyof Tables,
  TColumn extends keyof Tables[TTable],
  TOperator extends ComparisonOperator
> = `WHERE ${TColumn & string} ${TOperator} $${TColumn & string}`

// Example queries
type GetAllStudents = SelectQuery<'students'>  // "SELECT id | name | email | ... FROM students"
type GetStudentNames = SelectQuery<'students', 'name' | 'email'>  // "SELECT name | email FROM students"

// Complex query building
type ComplexQuery<
  TTable extends keyof Tables,
  TColumns extends keyof Tables[TTable],
  TWhereColumn extends keyof Tables[TTable]
> = `${SelectQuery<TTable, TColumns>} ${WhereClause<TTable, TWhereColumn, '='>}`

// Type-safe query builder
class QueryBuilder<TTable extends keyof Tables> {
  constructor(private tableName: TTable) {}

  select<TColumns extends keyof Tables[TTable]>(
    ...columns: TColumns[]
  ): QueryBuilder<TTable> {
    // Implementation would build SELECT clause
    return this
  }

  where<TColumn extends keyof Tables[TTable]>(
    column: TColumn,
    operator: ComparisonOperator,
    value: Tables[TTable][TColumn]
  ): QueryBuilder<TTable> {
    // Implementation would build WHERE clause
    return this
  }

  build(): string {
    // Implementation would return the final SQL string
    return ''
  }
}

// Usage with type safety
const query = new QueryBuilder('students')
  .select('name', 'email', 'grade')
  .where('grade', '>=', 10)
  .build()
```

### 2. CSS-in-JS Type Safety
```typescript
// CSS units and values
type CSSUnit = 'px' | 'rem' | 'em' | '%' | 'vh' | 'vw' | 'ch' | 'ex'
type CSSValue<TUnit extends CSSUnit> = `${number}${TUnit}`

// Color definitions
type HexColor = `#${string}`
type RGBColor = `rgb(${number}, ${number}, ${number})`
type RGBAColor = `rgba(${number}, ${number}, ${number}, ${number})`
type HSLColor = `hsl(${number}, ${number}%, ${number}%)`
type CSSColor = HexColor | RGBColor | RGBAColor | HSLColor | 'transparent' | 'inherit'

// CSS property types
type CSSLength = CSSValue<'px' | 'rem' | 'em' | '%'>
type CSSPercentage = CSSValue<'%'>

// EdTech theme system
interface EdTechTheme {
  colors: {
    primary: CSSColor
    secondary: CSSColor
    success: CSSColor
    warning: CSSColor
    error: CSSColor
    background: CSSColor
    text: CSSColor
  }
  spacing: {
    xs: CSSLength
    sm: CSSLength
    md: CSSLength
    lg: CSSLength
    xl: CSSLength
  }
  typography: {
    fontFamily: string
    fontSize: {
      small: CSSLength
      medium: CSSLength
      large: CSSLength
    }
  }
}

// CSS class name generation
type ComponentVariant = 'primary' | 'secondary' | 'outline' | 'ghost'
type ComponentSize = 'small' | 'medium' | 'large'
type ComponentState = 'default' | 'hover' | 'active' | 'disabled'

type CSSClassName<
  TComponent extends string,
  TVariant extends ComponentVariant = ComponentVariant,
  TSize extends ComponentSize = ComponentSize,
  TState extends ComponentState = ComponentState
> = `${TComponent}--${TVariant}--${TSize}--${TState}`

// Button class examples
type PrimaryButton = CSSClassName<'button', 'primary', 'medium', 'default'>
// Result: "button--primary--medium--default"

type LargeOutlineButton = CSSClassName<'button', 'outline', 'large', 'hover'>
// Result: "button--outline--large--hover"

// Dynamic CSS custom property names
type CSSCustomProperty<TCategory extends string, TName extends string> = 
  `--${TCategory}-${TName}`

type ThemeVariables = {
  [K in keyof EdTechTheme['colors'] as CSSCustomProperty<'color', K>]: CSSColor
} & {
  [K in keyof EdTechTheme['spacing'] as CSSCustomProperty<'spacing', K>]: CSSLength
}

// Result: {
//   '--color-primary': CSSColor
//   '--color-secondary': CSSColor
//   '--spacing-xs': CSSLength
//   '--spacing-sm': CSSLength
//   // ... etc
// }
```

### 3. GraphQL Schema Generation
```typescript
// GraphQL scalar types
type GraphQLScalar = 'String' | 'Int' | 'Float' | 'Boolean' | 'ID' | 'Date'

// GraphQL field definition
type GraphQLField<TType extends string, TNullable extends boolean = false> = 
  TNullable extends true ? `${TType}` : `${TType}!`

// Generate GraphQL type definitions
interface StudentEntity {
  id: string
  name: string
  email: string
  grade: number
  enrollmentDate: Date
}

type GraphQLTypeDefinition<T> = {
  [K in keyof T]: T[K] extends string 
    ? GraphQLField<'String'>
    : T[K] extends number 
    ? GraphQLField<'Int'>
    : T[K] extends boolean 
    ? GraphQLField<'Boolean'>
    : T[K] extends Date 
    ? GraphQLField<'Date'>
    : GraphQLField<'String'>  // fallback
}

type StudentGraphQLType = GraphQLTypeDefinition<StudentEntity>
// Result: {
//   id: 'String!'
//   name: 'String!'
//   email: 'String!'
//   grade: 'Int!'
//   enrollmentDate: 'Date!'
// }

// Query and mutation names
type QueryName<TEntity extends string, TOperation extends string> = 
  `${TOperation}${Capitalize<TEntity>}`

type StudentQueries = 
  | QueryName<'student', 'get'>        // "getStudent"
  | QueryName<'student', 'list'>       // "listStudent"
  | QueryName<'student', 'search'>     // "searchStudent"

type StudentMutations = 
  | QueryName<'student', 'create'>     // "createStudent"
  | QueryName<'student', 'update'>     // "updateStudent"
  | QueryName<'student', 'delete'>     // "deleteStudent"

// GraphQL resolver type generation
type Resolver<TArgs, TReturn> = (args: TArgs) => Promise<TReturn>

type StudentResolvers = {
  [K in StudentQueries | StudentMutations]: K extends `get${string}`
    ? Resolver<{ id: string }, StudentEntity | null>
    : K extends `list${string}`
    ? Resolver<{ limit?: number; offset?: number }, StudentEntity[]>
    : K extends `create${string}`
    ? Resolver<{ input: Omit<StudentEntity, 'id'> }, StudentEntity>
    : K extends `update${string}`
    ? Resolver<{ id: string; input: Partial<StudentEntity> }, StudentEntity>
    : K extends `delete${string}`
    ? Resolver<{ id: string }, boolean>
    : never
}
```

## 🧪 Testing Template Literal Types

### Type-Level Testing
```typescript
// Test utilities
type Expect<T extends true> = T
type Equal<X, Y> = (<T>() => T extends X ? 1 : 2) extends (<T>() => T extends Y ? 1 : 2) ? true : false

// Test route generation
type TestRouteGeneration = Expect<Equal<
  APIRoute<'GET', 'v1', 'students'>,
  'GET /api/v1/students'
>>

// Test parameter extraction
type TestParamExtraction = Expect<Equal<
  ExtractParams<'/api/v1/students/:id/courses/:courseId'>,
  'id' | 'courseId'
>>

// Test event name generation
type TestEventNames = Expect<Equal<
  EventName<'user', 'created'>,
  'user.created'
>>

// Test CSS class generation
type TestCSSClass = Expect<Equal<
  CSSClassName<'button', 'primary', 'large'>,
  'button--primary--large--default'
>>

// Test email validation
type TestEmailValidation = Expect<Equal<
  IsEmail<'test@example.com'>,
  true
>>

type TestInvalidEmail = Expect<Equal<
  IsEmail<'not-an-email'>,
  false
>>
```

### Runtime Testing
```typescript
import { describe, it, expect } from 'vitest'

describe('Template Literal Types in Practice', () => {
  it('should handle event system correctly', () => {
    const emitter = new TypedEventEmitter()
    let receivedPayload: any

    emitter.on('user.created', (payload) => {
      receivedPayload = payload
    })

    emitter.emit('user.created', {
      userId: 'user-123',
      email: 'test@example.com',
      role: 'student'
    })

    expect(receivedPayload).toEqual({
      userId: 'user-123',
      email: 'test@example.com',
      role: 'student'
    })
  })

  it('should build queries with type safety', () => {
    const queryBuilder = new QueryBuilder('students')
    const query = queryBuilder
      .select('name', 'email')
      .where('grade', '>=', 10)
      .build()

    // The actual SQL would be built in a real implementation
    expect(typeof query).toBe('string')
  })

  it('should validate routes at runtime', () => {
    const routes = [
      'GET /api/v1/students',
      'POST /api/v1/courses',
      'PUT /api/v1/lessons'
    ]

    routes.forEach(route => {
      expect(route).toMatch(/^(GET|POST|PUT|DELETE) \/api\/v[12]\/\w+$/)
    })
  })
})
```

## 📊 Performance Considerations

### Compilation Performance
```typescript
// ✅ Use type aliases for complex template literal types
type ComplexRoute<T extends string, U extends string> = `${T}/api/${U}`
type CachedRoute = ComplexRoute<'GET', 'v1'>

// ✅ Limit template literal complexity
// Instead of deeply nested template literals:
type BadComplexType<A, B, C, D> = `${A}-${B}-${C}-${D}-${A}-${B}-${C}-${D}`

// Use composition:
type SimpleComposition<A, B> = `${A}-${B}`
type GoodComplexType<A, B, C, D> = `${SimpleComposition<A, B>}-${SimpleComposition<C, D>}`

// ✅ Use union types efficiently
type HTTPMethodUnion = 'GET' | 'POST' | 'PUT' | 'DELETE'
type EfficientRoute<M extends HTTPMethodUnion> = `${M} /api/endpoint`

// ❌ Avoid excessive template literal computation
type IneffientRoute = `${'GET' | 'POST' | 'PUT' | 'DELETE'} /api/${'v1' | 'v2'}/${'users' | 'courses' | 'lessons'}`
// This creates 4 × 2 × 3 = 24 combinations

// ✅ Better: Use parameters
type EfficientRouteBuilder<
  M extends 'GET' | 'POST' | 'PUT' | 'DELETE',
  V extends 'v1' | 'v2',
  R extends 'users' | 'courses' | 'lessons'
> = `${M} /api/${V}/${R}`
```

### Runtime Performance
```typescript
// ✅ Use template literal types for compile-time validation
// but simple strings for runtime operations
function buildRoute<T extends string>(template: T): T {
  // Runtime implementation uses regular string operations
  return template
}

// ✅ Cache frequently computed template literals
const COMMON_ROUTES = {
  GET_STUDENTS: 'GET /api/v1/students' as const,
  POST_COURSES: 'POST /api/v1/courses' as const,
  PUT_LESSONS: 'PUT /api/v1/lessons' as const
} satisfies Record<string, `${HTTPMethod} /api/${APIVersion}/${ResourceType}`>

// ✅ Use branded types instead of complex template literals for IDs
type EntityId<T extends string> = string & { __brand: T }
type StudentId = EntityId<'Student'>
type CourseId = EntityId<'Course'>

// Instead of:
type ComplexStudentId = `student_${string}_${number}_${string}`
```

---

### 📖 Document Navigation

| Previous | Current | Next |
|----------|---------|------|
| [Mapped Types & Utilities](./mapped-types-utilities.md) | **Template Literal Types** | [Advanced Generics Patterns](./advanced-generics-patterns.md) |

---

*Last updated: January 2025*  
*Type-safe string manipulation for EdTech routing, configuration, and API design*