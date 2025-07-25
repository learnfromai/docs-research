# TypeScript Interview Questions & Answers

## Basic TypeScript Concepts

### 1. What is TypeScript and what are its advantages over JavaScript?

**Answer:**
TypeScript is a strongly typed, object-oriented, compiled programming language developed by Microsoft. It's a superset of JavaScript that adds static type definitions and compiles to plain JavaScript.

**Key Advantages:**

```typescript
// 1. Static Type Checking
function add(a: number, b: number): number {
  return a + b;
}

add(5, 10);     // ✓ Correct
add('5', '10'); // ✗ Compile-time error

// 2. Better IDE Support
interface User {
  id: number;
  name: string;
  email: string;
}

const user: User = {
  id: 1,
  name: 'John',
  email: 'john@example.com'
};

// IntelliSense shows available properties
user.name; // IDE provides autocomplete

// 3. Early Error Detection
function getUserName(user: User): string {
  return user.name; // ✓ TypeScript knows user has name property
  // return user.firstName; // ✗ Compile-time error
}

// 4. Modern JavaScript Features
// Classes, modules, arrow functions, destructuring, etc.
class Person {
  constructor(private name: string, private age: number) {}
  
  greet(): string {
    return `Hello, I'm ${this.name}`;
  }
}

// 5. Code Documentation through Types
type Theme = 'light' | 'dark';
type ButtonSize = 'small' | 'medium' | 'large';

interface ButtonProps {
  text: string;
  onClick: () => void;
  theme?: Theme;
  size?: ButtonSize;
  disabled?: boolean;
}
```

**Benefits:**

- **Compile-time error catching**
- **Enhanced IDE support** (autocomplete, refactoring)
- **Better code documentation**
- **Easier refactoring** in large codebases
- **Improved team collaboration**
- **Gradual adoption** (can be added incrementally)

### 2. What are the basic types in TypeScript?

**Answer:**
TypeScript provides several built-in types for type annotations:

```typescript
// Primitive Types
let isDone: boolean = false;
let decimal: number = 6;
let color: string = "blue";
let notSure: unknown = 4;
let unusable: void = undefined;
let u: undefined = undefined;
let n: null = null;

// Object Types
let person: object = { name: "John" };
let numbers: number[] = [1, 2, 3];
let items: Array<number> = [1, 2, 3]; // Generic array

// Tuple Types
let tuple: [string, number] = ["hello", 10];

// Enum Types
enum Color {
  Red,
  Green,
  Blue
}
let c: Color = Color.Green;

// Function Types
let myAdd: (x: number, y: number) => number = 
  function(x: number, y: number): number { return x + y; };

// Union Types
let value: string | number = 42;
value = "hello"; // Also valid

// Literal Types
let direction: "north" | "south" | "east" | "west" = "north";

// Any Type (use sparingly)
let notTyped: any = 42;
notTyped = "hello";
notTyped = false;

// Never Type
function error(message: string): never {
  throw new Error(message);
}

function infiniteLoop(): never {
  while (true) {}
}

// Type Assertions
let someValue: unknown = "this is a string";
let strLength: number = (someValue as string).length;
// or
let strLength2: number = (<string>someValue).length;

// Optional and Default Parameters
function buildName(firstName: string, lastName?: string): string {
  if (lastName) return firstName + " " + lastName;
  return firstName;
}

function buildFullName(firstName: string, lastName = "Smith"): string {
  return firstName + " " + lastName;
}

// Rest Parameters
function buildNameList(firstName: string, ...restOfName: string[]): string {
  return firstName + " " + restOfName.join(" ");
}
```

### 3. What are interfaces in TypeScript and how do you use them?

**Answer:**
Interfaces define the structure of objects, describing the shape of data. They're used for type checking and don't generate any JavaScript code.

```typescript
// Basic Interface
interface User {
  id: number;
  name: string;
  email: string;
}

const user: User = {
  id: 1,
  name: "John Doe",
  email: "john@example.com"
};

// Optional Properties
interface Config {
  apiUrl: string;
  timeout?: number; // Optional property
  retries?: number;
}

const config: Config = {
  apiUrl: "https://api.example.com"
  // timeout and retries are optional
};

// Readonly Properties
interface Point {
  readonly x: number;
  readonly y: number;
}

const origin: Point = { x: 0, y: 0 };
// origin.x = 5; // Error: Cannot assign to 'x' because it is readonly

// Function Types in Interfaces
interface SearchFunc {
  (source: string, subString: string): boolean;
}

const mySearch: SearchFunc = function(src: string, sub: string): boolean {
  return src.search(sub) > -1;
};

// Indexable Types
interface StringArray {
  [index: number]: string;
}

const myArray: StringArray = ["Bob", "Fred"];

interface StringDictionary {
  [key: string]: string;
}

const myDict: StringDictionary = {
  name: "John",
  email: "john@example.com"
};

// Class Implementation
interface Drivable {
  speed: number;
  drive(): void;
}

class Car implements Drivable {
  speed: number = 0;
  
  drive(): void {
    this.speed = 60;
    console.log("Driving at", this.speed, "mph");
  }
}

// Extending Interfaces
interface Animal {
  name: string;
}

interface Dog extends Animal {
  breed: string;
}

const myDog: Dog = {
  name: "Buddy",
  breed: "Golden Retriever"
};

// Multiple Interface Extension
interface Flyable {
  fly(): void;
}

interface Swimmable {
  swim(): void;
}

interface Duck extends Flyable, Swimmable {
  quack(): void;
}

const duck: Duck = {
  fly() { console.log("Flying"); },
  swim() { console.log("Swimming"); },
  quack() { console.log("Quack!"); }
};

// Hybrid Types (Object with call signature)
interface Counter {
  (start: number): string;
  interval: number;
  reset(): void;
}

function getCounter(): Counter {
  const counter = function(start: number) {
    return `Started at ${start}`;
  } as Counter;
  
  counter.interval = 123;
  counter.reset = function() {
    console.log("Reset");
  };
  
  return counter;
}

// Generic Interfaces
interface GenericIdentityFn<T> {
  (arg: T): T;
}

function identity<T>(arg: T): T {
  return arg;
}

const myIdentity: GenericIdentityFn<number> = identity;

// Interface for API Response
interface ApiResponse<T> {
  data: T;
  status: number;
  message: string;
  timestamp: string;
}

interface UserData {
  id: number;
  username: string;
  profile: {
    firstName: string;
    lastName: string;
  };
}

const userResponse: ApiResponse<UserData> = {
  data: {
    id: 1,
    username: "johndoe",
    profile: {
      firstName: "John",
      lastName: "Doe"
    }
  },
  status: 200,
  message: "Success",
  timestamp: "2023-01-01T00:00:00Z"
};
```

### 4. What are generics in TypeScript and why are they useful?

**Answer:**
Generics provide a way to create reusable components that can work with multiple types while preserving type information. They enable writing flexible, type-safe code.

```typescript
// Basic Generic Function
function identity<T>(arg: T): T {
  return arg;
}

// Usage
let output1 = identity<string>("hello");    // output1 is string
let output2 = identity<number>(42);         // output2 is number
let output3 = identity("hello");            // Type inference

// Generic with Array
function getFirst<T>(array: T[]): T | undefined {
  return array[0];
}

const numbers = [1, 2, 3];
const firstNumber = getFirst(numbers); // number | undefined

const strings = ["a", "b", "c"];
const firstString = getFirst(strings); // string | undefined

// Generic Interface
interface Repository<T> {
  save(entity: T): void;
  findById(id: number): T | undefined;
  findAll(): T[];
}

interface User {
  id: number;
  name: string;
}

class UserRepository implements Repository<User> {
  private users: User[] = [];
  
  save(user: User): void {
    this.users.push(user);
  }
  
  findById(id: number): User | undefined {
    return this.users.find(user => user.id === id);
  }
  
  findAll(): User[] {
    return [...this.users];
  }
}

// Generic Classes
class Stack<T> {
  private items: T[] = [];
  
  push(item: T): void {
    this.items.push(item);
  }
  
  pop(): T | undefined {
    return this.items.pop();
  }
  
  peek(): T | undefined {
    return this.items[this.items.length - 1];
  }
  
  isEmpty(): boolean {
    return this.items.length === 0;
  }
}

const numberStack = new Stack<number>();
numberStack.push(1);
numberStack.push(2);

const stringStack = new Stack<string>();
stringStack.push("hello");
stringStack.push("world");

// Generic Constraints
interface Lengthwise {
  length: number;
}

function logLength<T extends Lengthwise>(arg: T): T {
  console.log(arg.length); // OK, T has length property
  return arg;
}

logLength("hello");        // OK, string has length
logLength([1, 2, 3]);      // OK, array has length
logLength({ length: 10 }); // OK, object has length
// logLength(123);         // Error, number doesn't have length

// Using Type Parameters in Generic Constraints
function getProperty<T, K extends keyof T>(obj: T, key: K): T[K] {
  return obj[key];
}

const person = { name: "John", age: 30, email: "john@example.com" };

const name = getProperty(person, "name");   // string
const age = getProperty(person, "age");     // number
// const invalid = getProperty(person, "invalid"); // Error

// Conditional Types with Generics
type NonNullable<T> = T extends null | undefined ? never : T;

type ExampleType = NonNullable<string | null>; // string

// Utility Types using Generics
type Partial<T> = {
  [P in keyof T]?: T[P];
};

type Required<T> = {
  [P in keyof T]-?: T[P];
};

interface UserProfile {
  name: string;
  email: string;
  age: number;
}

type PartialUserProfile = Partial<UserProfile>;
// { name?: string; email?: string; age?: number; }

// Generic API Client Example
class ApiClient<TResponse> {
  constructor(private baseUrl: string) {}
  
  async get<T = TResponse>(endpoint: string): Promise<T> {
    const response = await fetch(`${this.baseUrl}${endpoint}`);
    return response.json();
  }
  
  async post<TRequest, TResponse = any>(
    endpoint: string, 
    data: TRequest
  ): Promise<TResponse> {
    const response = await fetch(`${this.baseUrl}${endpoint}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data)
    });
    return response.json();
  }
}

// Usage
interface ApiUser {
  id: number;
  username: string;
}

interface CreateUserRequest {
  username: string;
  email: string;
}

const apiClient = new ApiClient<ApiUser>('/api');

// Get user - returns Promise<ApiUser>
const user = await apiClient.get('/users/1');

// Create user - returns Promise<ApiUser>
const newUser = await apiClient.post<CreateUserRequest, ApiUser>('/users', {
  username: 'johndoe',
  email: 'john@example.com'
});

// Advanced Generic Example: Event Emitter
type EventHandler<T> = (event: T) => void;

class EventEmitter<TEvents extends Record<string, any>> {
  private listeners: {
    [K in keyof TEvents]?: EventHandler<TEvents[K]>[]
  } = {};
  
  on<K extends keyof TEvents>(
    eventName: K, 
    handler: EventHandler<TEvents[K]>
  ): void {
    if (!this.listeners[eventName]) {
      this.listeners[eventName] = [];
    }
    this.listeners[eventName]!.push(handler);
  }
  
  emit<K extends keyof TEvents>(
    eventName: K, 
    event: TEvents[K]
  ): void {
    const handlers = this.listeners[eventName];
    if (handlers) {
      handlers.forEach(handler => handler(event));
    }
  }
}

// Define event types
interface AppEvents {
  'user-login': { userId: number; timestamp: Date };
  'user-logout': { userId: number };
  'error': { message: string; code: number };
}

const emitter = new EventEmitter<AppEvents>();

// Type-safe event handling
emitter.on('user-login', (event) => {
  console.log(`User ${event.userId} logged in at ${event.timestamp}`);
});

emitter.emit('user-login', {
  userId: 123,
  timestamp: new Date()
});

// Benefits of Generics:
// 1. Type Safety - Catch errors at compile time
// 2. Code Reusability - Write once, use with multiple types
// 3. Better IntelliSense - IDE provides accurate suggestions
// 4. Performance - No runtime overhead
// 5. Self-documenting - Types serve as documentation
```

### 5. What is the difference between `type` and `interface` in TypeScript?

**Answer:**
Both `type` and `interface` can be used to define object shapes, but they have different capabilities and use cases.

```typescript
// INTERFACE EXAMPLES

// Basic object shape
interface User {
  id: number;
  name: string;
  email?: string;
}

// Extending interfaces
interface AdminUser extends User {
  permissions: string[];
}

// Declaration merging (interfaces can be reopened)
interface User {
  createdAt: Date; // This gets merged with the above User interface
}

// The User interface now has: id, name, email, createdAt

// Interface for function
interface MathOperation {
  (a: number, b: number): number;
}

const add: MathOperation = (a, b) => a + b;

// TYPE ALIAS EXAMPLES

// Basic object shape (same as interface)
type UserType = {
  id: number;
  name: string;
  email?: string;
};

// Union types (interface cannot do this)
type Status = 'loading' | 'success' | 'error';
type ID = string | number;

// Intersection types
type AdminUserType = UserType & {
  permissions: string[];
};

// Complex type operations
type UserKeys = keyof UserType; // 'id' | 'name' | 'email'
type UserValues = UserType[keyof UserType]; // number | string | undefined

// Conditional types
type NonNullable<T> = T extends null | undefined ? never : T;
type RequiredUser = Required<UserType>; // All properties become required

// Function type alias
type MathOperationType = (a: number, b: number) => number;

// Generic type alias
type ApiResponse<T> = {
  data: T;
  status: number;
  message: string;
};

// COMPARISON TABLE

/*
Feature                    | Interface | Type Alias
---------------------------|-----------|------------
Object shapes              | ✓         | ✓
Declaration merging        | ✓         | ✗
Extends/Implements         | ✓         | ✓ (intersection)
Union types                | ✗         | ✓
Intersection types         | ✗         | ✓
Computed properties        | ✗         | ✓
Conditional types          | ✗         | ✓
Primitive types            | ✗         | ✓
Tuple types                | ✗         | ✓
Function types             | ✓         | ✓
Generic constraints        | ✓         | ✓
*/

// PRACTICAL EXAMPLES

// Use interface for object shapes that might be extended
interface BaseComponent {
  id: string;
  className?: string;
}

interface Button extends BaseComponent {
  onClick: () => void;
  disabled?: boolean;
}

// Use type for unions and complex type operations
type Theme = 'light' | 'dark' | 'auto';
type Size = 'sm' | 'md' | 'lg';

type ButtonVariant = 'primary' | 'secondary' | 'danger';
type ButtonProps = {
  variant: ButtonVariant;
  size: Size;
  theme: Theme;
} & BaseComponent;

// Declaration merging with interfaces (useful for extending library types)
interface Window {
  customProperty: string;
}

// Now window.customProperty is available globally

// Type aliases for complex mapped types
type Partial<T> = {
  [P in keyof T]?: T[P];
};

type Pick<T, K extends keyof T> = {
  [P in K]: T[P];
};

type UserSummary = Pick<User, 'id' | 'name'>;

// Conditional type example
type ApiResponseType<T> = T extends string 
  ? { message: T } 
  : { data: T };

type StringResponse = ApiResponseType<string>; // { message: string }
type UserResponse = ApiResponseType<User>;     // { data: User }

// WHEN TO USE WHICH

// Use Interface when:
// 1. Defining object shapes
// 2. You might need to extend or implement
// 3. Working with classes
// 4. Building public APIs (declaration merging)

interface DatabaseEntity {
  id: string;
  createdAt: Date;
  updatedAt: Date;
}

interface UserEntity extends DatabaseEntity {
  username: string;
  email: string;
}

class UserModel implements UserEntity {
  id: string;
  createdAt: Date;
  updatedAt: Date;
  username: string;
  email: string;
  
  constructor(data: UserEntity) {
    Object.assign(this, data);
  }
}

// Use Type when:
// 1. Creating union types
// 2. Using intersection types
// 3. Conditional types
// 4. Computed/mapped types
// 5. Aliasing primitive types

type EventType = 'click' | 'hover' | 'focus';
type EventHandler<T extends EventType> = T extends 'click' 
  ? (event: MouseEvent) => void
  : T extends 'hover'
  ? (event: MouseEvent) => void
  : (event: FocusEvent) => void;

type ComponentState = 'idle' | 'loading' | 'success' | 'error';

type AsyncData<T> = {
  state: ComponentState;
  data?: T;
  error?: string;
};

// Hybrid approach - use both when appropriate
interface BaseUser {
  id: string;
  name: string;
}

type UserWithPermissions = BaseUser & {
  permissions: string[];
  role: 'admin' | 'user' | 'guest';
};

type AuthenticatedUser = UserWithPermissions & {
  token: string;
  expiresAt: Date;
};

// Best Practice: Be consistent within your codebase
// Many teams choose one as the default and use the other for specific cases
```

## Advanced TypeScript Concepts

### 6. What are mapped types and how do you use them?

**Answer:**
Mapped types allow you to create new types by transforming properties of an existing type. They're fundamental for creating utility types and type transformations.

```typescript
// Basic Mapped Type Syntax
type MappedType<T> = {
  [K in keyof T]: T[K];
};

// Built-in Utility Types (implemented as mapped types)

// Partial - makes all properties optional
type Partial<T> = {
  [P in keyof T]?: T[P];
};

// Required - makes all properties required
type Required<T> = {
  [P in keyof T]-?: T[P]; // -? removes optional modifier
};

// Readonly - makes all properties readonly
type Readonly<T> = {
  readonly [P in keyof T]: T[P];
};

// Pick - selects specific properties
type Pick<T, K extends keyof T> = {
  [P in K]: T[P];
};

// Omit - excludes specific properties
type Omit<T, K extends keyof T> = Pick<T, Exclude<keyof T, K>>;

// PRACTICAL EXAMPLES

interface User {
  id: number;
  name: string;
  email: string;
  age: number;
  isActive: boolean;
}

// Using built-in utility types
type PartialUser = Partial<User>;
// { id?: number; name?: string; email?: string; age?: number; isActive?: boolean; }

type UserSummary = Pick<User, 'id' | 'name'>;
// { id: number; name: string; }

type UserWithoutId = Omit<User, 'id'>;
// { name: string; email: string; age: number; isActive: boolean; }

// CUSTOM MAPPED TYPES

// Convert all properties to strings
type Stringify<T> = {
  [K in keyof T]: string;
};

type StringifiedUser = Stringify<User>;
// { id: string; name: string; email: string; age: string; isActive: string; }

// Add null to all properties
type Nullable<T> = {
  [K in keyof T]: T[K] | null;
};

type NullableUser = Nullable<User>;
// { id: number | null; name: string | null; ... }

// Convert all properties to Promises
type Promisify<T> = {
  [K in keyof T]: Promise<T[K]>;
};

type PromiseUser = Promisify<User>;
// { id: Promise<number>; name: Promise<string>; ... }

// CONDITIONAL MAPPED TYPES

// Only include string properties
type StringProperties<T> = {
  [K in keyof T]: T[K] extends string ? T[K] : never;
};

type UserStringProps = StringProperties<User>;
// { id: never; name: string; email: string; age: never; isActive: never; }

// Filter out never types
type NonNever<T> = {
  [K in keyof T as T[K] extends never ? never : K]: T[K];
};

type FilteredStringProps = NonNever<StringProperties<User>>;
// { name: string; email: string; }

// TEMPLATE LITERAL TYPES WITH MAPPED TYPES

// Convert property names to getters
type Getters<T> = {
  [K in keyof T as `get${Capitalize<string & K>}`]: () => T[K];
};

type UserGetters = Getters<User>;
// {
//   getId: () => number;
//   getName: () => string;
//   getEmail: () => string;
//   getAge: () => number;
//   getIsActive: () => boolean;
// }

// Convert to setters
type Setters<T> = {
  [K in keyof T as `set${Capitalize<string & K>}`]: (value: T[K]) => void;
};

type UserSetters = Setters<User>;

// ADVANCED MAPPING EXAMPLES

// Deep readonly
type DeepReadonly<T> = {
  readonly [P in keyof T]: T[P] extends object ? DeepReadonly<T[P]> : T[P];
};

interface NestedUser {
  profile: {
    name: string;
    settings: {
      theme: string;
      notifications: boolean;
    };
  };
}

type ReadonlyNestedUser = DeepReadonly<NestedUser>;
// All nested properties become readonly

// Event handlers for component props
type EventHandlers<T> = {
  [K in keyof T as `on${Capitalize<string & K>}Change`]: (value: T[K]) => void;
};

interface FormData {
  username: string;
  email: string;
  age: number;
}

type FormEventHandlers = EventHandlers<FormData>;
// {
//   onUsernameChange: (value: string) => void;
//   onEmailChange: (value: string) => void;
//   onAgeChange: (value: number) => void;
// }

// API response wrapper
type ApiWrapper<T> = {
  [K in keyof T]: {
    data: T[K];
    loading: boolean;
    error: string | null;
  };
};

interface ApiData {
  user: User;
  posts: Post[];
  comments: Comment[];
}

type WrappedApiData = ApiWrapper<ApiData>;
// Each property becomes { data: T, loading: boolean, error: string | null }

// PRACTICAL USE CASE: Form Validation

interface ValidationResult {
  isValid: boolean;
  message?: string;
}

type Validators<T> = {
  [K in keyof T]?: (value: T[K]) => ValidationResult;
};

type FormValidators = Validators<FormData>;
// {
//   username?: (value: string) => ValidationResult;
//   email?: (value: string) => ValidationResult;
//   age?: (value: number) => ValidationResult;
// }

const userValidators: FormValidators = {
  username: (value) => ({
    isValid: value.length >= 3,
    message: value.length < 3 ? 'Username must be at least 3 characters' : undefined
  }),
  email: (value) => ({
    isValid: /\S+@\S+\.\S+/.test(value),
    message: !/\S+@\S+\.\S+/.test(value) ? 'Invalid email format' : undefined
  })
};

// Database operations mapping
type DbOperations<T> = {
  [K in keyof T as `findBy${Capitalize<string & K>}`]: (value: T[K]) => Promise<T[]>;
} & {
  [K in keyof T as `updateBy${Capitalize<string & K>}`]: (
    filter: T[K], 
    update: Partial<T>
  ) => Promise<T>;
};

type UserDbOperations = DbOperations<Pick<User, 'id' | 'email'>>;
// {
//   findById: (value: number) => Promise<User[]>;
//   findByEmail: (value: string) => Promise<User[]>;
//   updateById: (filter: number, update: Partial<User>) => Promise<User>;
//   updateByEmail: (filter: string, update: Partial<User>) => Promise<User>;
// }

// State management with mapped types
type Actions<T> = {
  [K in keyof T as `set${Capitalize<string & K>}`]: {
    type: `SET_${Uppercase<string & K>}`;
    payload: T[K];
  };
}[keyof T];

type UserActions = Actions<User>;
// Union of action types: 
// | { type: "SET_ID"; payload: number; }
// | { type: "SET_NAME"; payload: string; }
// | { type: "SET_EMAIL"; payload: string; }
// | { type: "SET_AGE"; payload: number; }
// | { type: "SET_ISACTIVE"; payload: boolean; }

// Reducer for the actions
type Reducer<T> = (state: T, action: Actions<T>) => T;

const userReducer: Reducer<User> = (state, action) => {
  switch (action.type) {
    case 'SET_NAME':
      return { ...state, name: action.payload };
    case 'SET_EMAIL':
      return { ...state, email: action.payload };
    // ... other cases
    default:
      return state;
  }
};

// Benefits of Mapped Types:
// 1. Type safety - Ensures consistency across related types
// 2. DRY principle - Avoid repeating type definitions
// 3. Maintainability - Changes to base type propagate automatically
// 4. Code generation - Generate related types automatically
// 5. API consistency - Ensure consistent patterns across your codebase
```

### 7. What are conditional types and how do you use them?

**Answer:**
Conditional types allow you to create types that depend on a condition, similar to conditional expressions in JavaScript. They follow the pattern `T extends U ? X : Y`.

```typescript
// Basic Conditional Type Syntax
type ConditionalType<T> = T extends string ? string[] : number[];

type StringArray = ConditionalType<string>; // string[]
type NumberArray = ConditionalType<number>; // number[]

// BUILT-IN CONDITIONAL UTILITY TYPES

// NonNullable - removes null and undefined
type NonNullable<T> = T extends null | undefined ? never : T;

type NotNull = NonNullable<string | null | undefined>; // string

// Extract - extracts types from union that are assignable to U
type Extract<T, U> = T extends U ? T : never;

type StringsOnly = Extract<string | number | boolean, string>; // string

// Exclude - excludes types from union that are assignable to U  
type Exclude<T, U> = T extends U ? never : T;

type WithoutStrings = Exclude<string | number | boolean, string>; // number | boolean

// ReturnType - gets return type of function
type ReturnType<T extends (...args: any) => any> = T extends (...args: any) => infer R ? R : any;

function getUser(): { id: number; name: string } {
  return { id: 1, name: 'John' };
}

type UserType = ReturnType<typeof getUser>; // { id: number; name: string }

// INFER KEYWORD

// Infer allows you to extract types from within conditional types
type ArrayElementType<T> = T extends (infer U)[] ? U : never;

type StringElement = ArrayElementType<string[]>; // string
type NumberElement = ArrayElementType<number[]>; // number

// Extract function parameters
type Parameters<T extends (...args: any) => any> = T extends (...args: infer P) => any ? P : never;

function processUser(id: number, name: string, active: boolean): void {}

type ProcessUserParams = Parameters<typeof processUser>; // [number, string, boolean]

// Extract Promise resolution type
type UnwrapPromise<T> = T extends Promise<infer U> ? U : T;

type ResolvedString = UnwrapPromise<Promise<string>>; // string
type StillNumber = UnwrapPromise<number>; // number

// COMPLEX CONDITIONAL TYPES

// Check if type is array
type IsArray<T> = T extends any[] ? true : false;

type CheckString = IsArray<string>; // false
type CheckArray = IsArray<string[]>; // true

// Flatten arrays
type Flatten<T> = T extends (infer U)[] 
  ? U extends any[] 
    ? Flatten<U> 
    : U 
  : T;

type NestedArray = string[][];
type Flattened = Flatten<NestedArray>; // string

// Deep property access
type DeepGet<T, K> = K extends `${infer First}.${infer Rest}`
  ? First extends keyof T
    ? DeepGet<T[First], Rest>
    : never
  : K extends keyof T
  ? T[K]
  : never;

interface User {
  profile: {
    address: {
      street: string;
      city: string;
    };
  };
}

type Street = DeepGet<User, 'profile.address.street'>; // string

// DISTRIBUTED CONDITIONAL TYPES

// When T is a union type, conditional types distribute over the union
type ToArray<T> = T extends any ? T[] : never;

type UnionArrays = ToArray<string | number>; // string[] | number[]

// This distribution can be prevented by wrapping in tuples
type NoDistribute<T> = [T] extends [any] ? T[] : never;

type SingleArray = NoDistribute<string | number>; // (string | number)[]

// PRACTICAL EXAMPLES

// 1. API Response Type Based on Status
type ApiResponse<TData, TStatus = 'success'> = TStatus extends 'success'
  ? { status: 'success'; data: TData }
  : TStatus extends 'error'
  ? { status: 'error'; error: string }
  : { status: 'loading' };

type SuccessResponse = ApiResponse<User, 'success'>; // { status: 'success'; data: User }
type ErrorResponse = ApiResponse<never, 'error'>; // { status: 'error'; error: string }

// 2. Form Field Types Based on Input Type
type FieldType<T> = T extends 'text' | 'email' | 'password'
  ? string
  : T extends 'number'
  ? number
  : T extends 'checkbox'
  ? boolean
  : T extends 'select'
  ? string
  : unknown;

interface FormField<T extends string> {
  type: T;
  value: FieldType<T>;
  onChange: (value: FieldType<T>) => void;
}

const textField: FormField<'text'> = {
  type: 'text',
  value: 'hello', // must be string
  onChange: (value) => console.log(value) // value is string
};

// 3. Event Handler Types
type EventMap = {
  click: MouseEvent;
  hover: MouseEvent;
  focus: FocusEvent;
  input: InputEvent;
};

type EventHandler<T extends keyof EventMap> = (event: EventMap[T]) => void;

type ClickHandler = EventHandler<'click'>; // (event: MouseEvent) => void

// 4. Database Query Builder
type QueryBuilder<T> = {
  where: <K extends keyof T>(field: K, value: T[K]) => QueryBuilder<T>;
  select: <K extends keyof T>(...fields: K[]) => QueryBuilder<Pick<T, K>>;
  execute: () => Promise<T[]>;
};

// 5. State Machine Types
type StateConfig<TStates extends string, TEvents extends string> = {
  [State in TStates]: {
    on: {
      [Event in TEvents]?: TStates;
    };
  };
};

type TrafficLightStates = 'red' | 'yellow' | 'green';
type TrafficLightEvents = 'TIMER' | 'EMERGENCY';

type TrafficLightConfig = StateConfig<TrafficLightStates, TrafficLightEvents>;

const config: TrafficLightConfig = {
  red: {
    on: {
      TIMER: 'green',
      EMERGENCY: 'yellow'
    }
  },
  yellow: {
    on: {
      TIMER: 'red'
    }
  },
  green: {
    on: {
      TIMER: 'yellow',
      EMERGENCY: 'red'
    }
  }
};

// 6. HTTP Method Type Safety
type HttpMethods = 'GET' | 'POST' | 'PUT' | 'DELETE';

type RequestConfig<TMethod extends HttpMethods> = {
  method: TMethod;
  url: string;
} & (TMethod extends 'GET' | 'DELETE' 
  ? {} 
  : { body: any });

const getRequest: RequestConfig<'GET'> = {
  method: 'GET',
  url: '/api/users'
  // body not allowed for GET
};

const postRequest: RequestConfig<'POST'> = {
  method: 'POST',
  url: '/api/users',
  body: { name: 'John' } // body required for POST
};

// 7. Component Props Based on Variant
type ButtonVariant = 'primary' | 'secondary' | 'link';

type ButtonProps<T extends ButtonVariant> = {
  variant: T;
  children: React.ReactNode;
} & (T extends 'link' 
  ? { href: string; target?: string } 
  : { onClick: () => void });

const primaryButton: ButtonProps<'primary'> = {
  variant: 'primary',
  children: 'Click me',
  onClick: () => console.log('clicked')
};

const linkButton: ButtonProps<'link'> = {
  variant: 'link',
  children: 'Visit link',
  href: 'https://example.com'
};

// 8. Advanced Type Manipulation
// Convert union to intersection
type UnionToIntersection<U> = (U extends any ? (k: U) => void : never) extends (k: infer I) => void ? I : never;

type Union = { a: string } | { b: number };
type Intersection = UnionToIntersection<Union>; // { a: string } & { b: number }

// Get all possible keys from union of objects
type AllKeys<T> = T extends any ? keyof T : never;

type ObjectUnion = { a: string; b: number } | { b: number; c: boolean };
type AllPossibleKeys = AllKeys<ObjectUnion>; // "a" | "b" | "c"

// Benefits of Conditional Types:
// 1. Type safety based on runtime conditions
// 2. Advanced type manipulation and transformation
// 3. Better API design with type constraints
// 4. Improved IDE support and autocomplete
// 5. Compile-time validation of complex logic
```

### 8. What are decorators in TypeScript and how do you use them?

**Answer:**
Decorators are a design pattern that allows you to add metadata and modify the behavior of classes, methods, properties, and parameters. They're implemented as functions that take specific arguments based on what they're decorating.

**Note:** Decorators are experimental in TypeScript and require enabling the `experimentalDecorators` compiler option.

```typescript
// tsconfig.json
{
  "compilerOptions": {
    "experimentalDecorators": true,
    "emitDecoratorMetadata": true
  }
}

// CLASS DECORATORS

// Basic class decorator
function Component(constructor: Function) {
  console.log('Component decorator called');
  // Add metadata to the class
  constructor.prototype.isComponent = true;
}

@Component
class UserComponent {
  name: string = 'UserComponent';
}

const instance = new UserComponent();
console.log((instance as any).isComponent); // true

// Class decorator with parameters (decorator factory)
function Serializable(tableName: string) {
  return function(constructor: Function) {
    constructor.prototype.tableName = tableName;
    constructor.prototype.serialize = function() {
      return JSON.stringify(this);
    };
  };
}

@Serializable('users')
class User {
  id: number = 1;
  name: string = 'John';
}

const user = new User();
console.log((user as any).tableName); // 'users'
console.log((user as any).serialize()); // JSON string

// METHOD DECORATORS

// Basic method decorator
function LogMethod(target: any, propertyName: string, descriptor: PropertyDescriptor) {
  const method = descriptor.value;
  
  descriptor.value = function(...args: any[]) {
    console.log(`Calling method ${propertyName} with args:`, args);
    const result = method.apply(this, args);
    console.log(`Method ${propertyName} returned:`, result);
    return result;
  };
}

class Calculator {
  @LogMethod
  add(a: number, b: number): number {
    return a + b;
  }
}

const calc = new Calculator();
calc.add(5, 3); // Logs method call and result

// Method decorator with parameters
function Throttle(delay: number) {
  return function(target: any, propertyName: string, descriptor: PropertyDescriptor) {
    const method = descriptor.value;
    let timeout: NodeJS.Timeout;
    
    descriptor.value = function(...args: any[]) {
      clearTimeout(timeout);
      timeout = setTimeout(() => {
        method.apply(this, args);
      }, delay);
    };
  };
}

class SearchComponent {
  @Throttle(300)
  search(query: string) {
    console.log('Searching for:', query);
    // API call would go here
  }
}

// PROPERTY DECORATORS

// Basic property decorator
function Required(target: any, propertyName: string) {
  let value: any;
  
  const getter = () => {
    return value;
  };
  
  const setter = (newValue: any) => {
    if (newValue === null || newValue === undefined) {
      throw new Error(`Property ${propertyName} is required`);
    }
    value = newValue;
  };
  
  Object.defineProperty(target, propertyName, {
    get: getter,
    set: setter,
    enumerable: true,
    configurable: true
  });
}

class Product {
  @Required
  name: string = '';
  
  @Required
  price: number = 0;
}

const product = new Product();
// product.name = null; // Would throw error

// Property decorator with validation
function MinLength(length: number) {
  return function(target: any, propertyName: string) {
    let value: string;
    
    Object.defineProperty(target, propertyName, {
      get: () => value,
      set: (newValue: string) => {
        if (newValue.length < length) {
          throw new Error(`${propertyName} must be at least ${length} characters`);
        }
        value = newValue;
      },
      enumerable: true,
      configurable: true
    });
  };
}

class UserProfile {
  @MinLength(3)
  username: string = '';
  
  @MinLength(8)
  password: string = '';
}

// PARAMETER DECORATORS

// Basic parameter decorator
function LogParameter(target: any, propertyName: string, parameterIndex: number) {
  const existingParameters = Reflect.getMetadata('logParameters', target, propertyName) || [];
  existingParameters[parameterIndex] = true;
  Reflect.defineMetadata('logParameters', existingParameters, target, propertyName);
}

function LogParametersMethod(target: any, propertyName: string, descriptor: PropertyDescriptor) {
  const method = descriptor.value;
  const logParameters = Reflect.getMetadata('logParameters', target, propertyName);
  
  descriptor.value = function(...args: any[]) {
    if (logParameters) {
      logParameters.forEach((shouldLog: boolean, index: number) => {
        if (shouldLog) {
          console.log(`Parameter ${index}:`, args[index]);
        }
      });
    }
    return method.apply(this, args);
  };
}

class UserService {
  @LogParametersMethod
  createUser(@LogParameter name: string, age: number, @LogParameter email: string) {
    return { name, age, email };
  }
}

// REAL-WORLD EXAMPLES

// 1. Validation Decorators
function IsEmail(target: any, propertyName: string) {
  let value: string;
  
  Object.defineProperty(target, propertyName, {
    get: () => value,
    set: (newValue: string) => {
      if (!/\S+@\S+\.\S+/.test(newValue)) {
        throw new Error('Invalid email format');
      }
      value = newValue;
    }
  });
}

function IsNumber(target: any, propertyName: string) {
  let value: number;
  
  Object.defineProperty(target, propertyName, {
    get: () => value,
    set: (newValue: any) => {
      if (typeof newValue !== 'number' || isNaN(newValue)) {
        throw new Error('Value must be a number');
      }
      value = newValue;
    }
  });
}

class UserRegistration {
  @IsEmail
  email: string = '';
  
  @IsNumber
  age: number = 0;
}

// 2. HTTP Route Decorators (Express-like)
function Controller(basePath: string) {
  return function(constructor: Function) {
    constructor.prototype.basePath = basePath;
  };
}

function Get(path: string) {
  return function(target: any, propertyName: string, descriptor: PropertyDescriptor) {
    target.routes = target.routes || [];
    target.routes.push({
      method: 'GET',
      path,
      handler: propertyName
    });
  };
}

function Post(path: string) {
  return function(target: any, propertyName: string, descriptor: PropertyDescriptor) {
    target.routes = target.routes || [];
    target.routes.push({
      method: 'POST',
      path,
      handler: propertyName
    });
  };
}

@Controller('/api/users')
class UserController {
  @Get('/')
  getUsers() {
    return 'Get all users';
  }
  
  @Post('/')
  createUser() {
    return 'Create user';
  }
  
  @Get('/:id')
  getUserById() {
    return 'Get user by ID';
  }
}

// 3. Caching Decorator
function Cache(ttl: number = 60000) { // TTL in milliseconds
  return function(target: any, propertyName: string, descriptor: PropertyDescriptor) {
    const method = descriptor.value;
    const cache = new Map();
    
    descriptor.value = function(...args: any[]) {
      const key = JSON.stringify(args);
      const cached = cache.get(key);
      
      if (cached && Date.now() - cached.timestamp < ttl) {
        console.log('Cache hit');
        return cached.value;
      }
      
      const result = method.apply(this, args);
      cache.set(key, { value: result, timestamp: Date.now() });
      console.log('Cache miss');
      return result;
    };
  };
}

class DataService {
  @Cache(30000) // Cache for 30 seconds
  async fetchUser(id: number) {
    console.log('Fetching user from API...');
    // Simulate API call
    return { id, name: `User ${id}` };
  }
}

// 4. Authorization Decorator
function Authorize(roles: string[]) {
  return function(target: any, propertyName: string, descriptor: PropertyDescriptor) {
    const method = descriptor.value;
    
    descriptor.value = function(...args: any[]) {
      // In real app, get current user from context
      const currentUser = { roles: ['admin'] }; // Mock current user
      
      const hasPermission = roles.some(role => currentUser.roles.includes(role));
      
      if (!hasPermission) {
        throw new Error('Unauthorized');
      }
      
      return method.apply(this, args);
    };
  };
}

class AdminService {
  @Authorize(['admin'])
  deleteUser(id: number) {
    console.log(`Deleting user ${id}`);
  }
  
  @Authorize(['admin', 'moderator'])
  moderateContent(contentId: number) {
    console.log(`Moderating content ${contentId}`);
  }
}

// 5. Database Entity Decorator
function Entity(tableName: string) {
  return function(constructor: Function) {
    constructor.prototype.tableName = tableName;
    constructor.prototype.save = function() {
      console.log(`Saving to table: ${this.tableName}`);
    };
  };
}

function Column(columnName?: string) {
  return function(target: any, propertyName: string) {
    target.columns = target.columns || [];
    target.columns.push({
      property: propertyName,
      column: columnName || propertyName
    });
  };
}

@Entity('users')
class UserEntity {
  @Column('user_id')
  id: number = 0;
  
  @Column()
  name: string = '';
  
  @Column('email_address')
  email: string = '';
}

// 6. Decorator Composition
function compose(...decorators: any[]) {
  return function(target: any, propertyName: string, descriptor: PropertyDescriptor) {
    decorators.reverse().forEach(decorator => {
      decorator(target, propertyName, descriptor);
    });
  };
}

class ApiService {
  @compose(
    LogMethod,
    Cache(60000),
    Authorize(['user'])
  )
  getData() {
    return 'Important data';
  }
}

// Benefits of Decorators:
// 1. Clean separation of concerns
// 2. Reusable cross-cutting functionality
// 3. Declarative programming style
// 4. Framework integration (Angular, NestJS)
// 5. Metadata-driven programming

// Common Use Cases:
// - Dependency injection
// - Logging and monitoring
// - Validation
// - Authorization
// - Caching
// - Database ORM mapping
// - API routing
// - Testing (mocking, test configuration)
```

---

## Navigation

⬅️ **[Previous: JavaScript Questions](./javascript-questions.md)**  
➡️ **[Next: React Questions](./react-questions.md)**  
🏠 **[Home: Research Index](../README.md)**

---

*These TypeScript questions cover fundamental to advanced concepts essential for type-safe development in the Dev Partners Senior Full Stack Developer position.*
