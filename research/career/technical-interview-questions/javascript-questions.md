# JavaScript Interview Questions & Answers

Comprehensive collection of JavaScript interview questions covering fundamental concepts, ES6+ features, asynchronous programming, and advanced topics for technical interview preparation.

{% hint style="info" %}
**Skill Level**: 3+ years experience
**Question Count**: 50+ questions covering beginner to advanced concepts
**Focus Areas**: ES6+, async/await, closures, prototypes, performance optimization
{% endhint %}

## Table of Contents

1. [Fundamental JavaScript Concepts](#fundamental-javascript-concepts)
2. [ES6+ Features](#es6-features)
3. [Asynchronous Programming](#asynchronous-programming)
4. [Object-Oriented Programming](#object-oriented-programming)
5. [Performance & Optimization](#performance--optimization)
6. [Advanced Topics](#advanced-topics)

---

## Fundamental JavaScript Concepts

### 1. What are the different data types in JavaScript?

**Answer:**
JavaScript has **8 data types** divided into two categories:

**Primitive Types (7):**
1. **Number** - Integers and floating-point numbers
2. **String** - Text data
3. **Boolean** - true or false
4. **Undefined** - Variable declared but not assigned
5. **Null** - Intentional absence of value
6. **Symbol** - Unique identifier (ES6+)
7. **BigInt** - Large integers beyond Number.MAX_SAFE_INTEGER (ES2020)

**Non-Primitive Type (1):**
8. **Object** - Collections of key-value pairs (includes arrays, functions, dates)

```javascript
// Examples
let num = 42;                    // Number
let str = "Hello";               // String
let bool = true;                 // Boolean
let undef;                       // Undefined
let empty = null;                // Null
let sym = Symbol('id');          // Symbol
let bigNum = 123456789012345678901234567890n; // BigInt
let obj = { name: "John" };      // Object
```

### 2. Explain the difference between `let`, `const`, and `var`.

**Answer:**

| Feature | var | let | const |
|---------|-----|-----|-------|
| **Scope** | Function-scoped | Block-scoped | Block-scoped |
| **Hoisting** | Hoisted, initialized with `undefined` | Hoisted, not initialized (TDZ) | Hoisted, not initialized (TDZ) |
| **Re-declaration** | Allowed | Not allowed | Not allowed |
| **Re-assignment** | Allowed | Allowed | Not allowed |

```javascript
// Scope differences
function example() {
  if (true) {
    var varVariable = "I'm function-scoped";
    let letVariable = "I'm block-scoped";
    const constVariable = "I'm also block-scoped";
  }
  
  console.log(varVariable);    // "I'm function-scoped" ✓
  console.log(letVariable);    // ReferenceError ✗
  console.log(constVariable);  // ReferenceError ✗
}

// Hoisting behavior
console.log(varHoisted);    // undefined (hoisted)
console.log(letHoisted);    // ReferenceError (TDZ)
console.log(constHoisted);  // ReferenceError (TDZ)

var varHoisted = "var";
let letHoisted = "let";
const constHoisted = "const";
```

### 3. What is hoisting in JavaScript?

**Answer:**
**Hoisting** is JavaScript's behavior of moving variable and function declarations to the top of their containing scope during compilation, before code execution.

```javascript
// What you write:
console.log(myVar);  // undefined (not ReferenceError)
var myVar = 5;

// How JavaScript interprets it:
var myVar;           // Declaration hoisted
console.log(myVar);  // undefined
myVar = 5;           // Assignment stays in place

// Function hoisting
sayHello();  // "Hello!" - works due to hoisting

function sayHello() {
  console.log("Hello!");
}

// Function expressions are NOT hoisted
sayGoodbye();  // TypeError: sayGoodbye is not a function

var sayGoodbye = function() {
  console.log("Goodbye!");
};
```

### 4. Explain closures in JavaScript with an example.

**Answer:**
A **closure** is a function that has access to variables in its outer (enclosing) scope even after the outer function has returned. Closures give you access to an outer function's scope from an inner function.

```javascript
function outerFunction(x) {
  // Outer function's variable
  
  function innerFunction(y) {
    // Inner function has access to outer function's variables
    console.log(x + y);  // x is from outer scope
  }
  
  return innerFunction;
}

const addFive = outerFunction(5);
addFive(3);  // Outputs: 8

// Practical example: Counter
function createCounter() {
  let count = 0;
  
  return {
    increment: () => ++count,
    decrement: () => --count,
    getCount: () => count
  };
}

const counter = createCounter();
console.log(counter.increment()); // 1
console.log(counter.increment()); // 2
console.log(counter.getCount());  // 2
// count variable is private and can't be accessed directly
```

### 5. What is the difference between `==` and `===`?

**Answer:**

| Operator | Name | Type Coercion | Example |
|----------|------|---------------|---------|
| `==` | Equality | Performs type conversion | `'5' == 5` → `true` |
| `===` | Strict Equality | No type conversion | `'5' === 5` → `false` |

```javascript
// == (Equality with type coercion)
console.log(5 == '5');        // true (string converted to number)
console.log(true == 1);       // true (boolean converted to number)
console.log(null == undefined); // true (special case)
console.log(0 == false);      // true (boolean converted to number)

// === (Strict equality)
console.log(5 === '5');       // false (different types)
console.log(true === 1);      // false (different types)
console.log(null === undefined); // false (different types)
console.log(0 === false);     // false (different types)

// Best practice: Always use === unless you specifically need type coercion
```

## Advanced JavaScript Concepts

### 6. Explain the concept of "this" in JavaScript.

**Answer:**
The `this` keyword refers to the object that is currently executing the function. Its value depends on how the function is called.

```javascript
// 1. Global context
console.log(this); // Window object (browser) or global object (Node.js)

// 2. Object method
const person = {
  name: 'John',
  greet() {
    console.log(this.name); // 'John' - this refers to person object
  }
};

// 3. Constructor function
function Person(name) {
  this.name = name;  // this refers to the new instance
}
const john = new Person('John');

// 4. Arrow functions - inherit this from enclosing scope
const obj = {
  name: 'John',
  regularFunction() {
    console.log(this.name); // 'John'
    
    const arrowFunction = () => {
      console.log(this.name); // 'John' - inherited from regularFunction
    };
    arrowFunction();
  }
};

// 5. Explicit binding with call, apply, bind
function greet() {
  console.log(`Hello, ${this.name}`);
}

const person1 = { name: 'Alice' };
const person2 = { name: 'Bob' };

greet.call(person1);    // "Hello, Alice"
greet.apply(person2);   // "Hello, Bob"
const boundGreet = greet.bind(person1);
boundGreet();           // "Hello, Alice"
```

### 7. What are Promises and how do they work?

**Answer:**
A **Promise** is an object representing the eventual completion (or failure) of an asynchronous operation and its resulting value. Promises have three states: pending, fulfilled, or rejected.

```javascript
// Creating a Promise
const myPromise = new Promise((resolve, reject) => {
  const success = Math.random() > 0.5;
  
  setTimeout(() => {
    if (success) {
      resolve("Operation successful!");
    } else {
      reject("Operation failed!");
    }
  }, 1000);
});

// Consuming a Promise
myPromise
  .then(result => {
    console.log(result); // "Operation successful!"
  })
  .catch(error => {
    console.log(error);  // "Operation failed!"
  })
  .finally(() => {
    console.log("Operation completed");
  });

// Promise chaining
fetch('/api/user/1')
  .then(response => response.json())
  .then(user => fetch(`/api/posts/${user.id}`))
  .then(response => response.json())
  .then(posts => console.log(posts))
  .catch(error => console.error('Error:', error));

// Modern async/await syntax
async function fetchUserPosts() {
  try {
    const userResponse = await fetch('/api/user/1');
    const user = await userResponse.json();
    const postsResponse = await fetch(`/api/posts/${user.id}`);
    const posts = await postsResponse.json();
    console.log(posts);
  } catch (error) {
    console.error('Error:', error);
  }
}
```

### 8. Explain event delegation in JavaScript.

**Answer:**
**Event delegation** is a technique where you add a single event listener to a parent element to manage events for multiple child elements, taking advantage of event bubbling.

```javascript
// Without event delegation (inefficient)
document.querySelectorAll('.button').forEach(button => {
  button.addEventListener('click', handleClick);
});

// With event delegation (efficient)
document.getElementById('container').addEventListener('click', function(event) {
  if (event.target.classList.contains('button')) {
    handleClick(event);
  }
});

// Practical example
const todoList = document.getElementById('todo-list');

todoList.addEventListener('click', function(event) {
  const target = event.target;
  
  if (target.classList.contains('delete-btn')) {
    // Handle delete
    target.closest('li').remove();
  } else if (target.classList.contains('edit-btn')) {
    // Handle edit
    editTodo(target.closest('li'));
  } else if (target.classList.contains('complete-btn')) {
    // Handle complete
    target.closest('li').classList.toggle('completed');
  }
});

// Benefits:
// 1. Memory efficient - only one event listener
// 2. Works with dynamically added elements
// 3. Easier to manage
```

### 9. What is the difference between `call`, `apply`, and `bind`?

**Answer:**
All three methods are used to set the `this` context of a function, but they work differently:

```javascript
const person = {
  firstName: 'John',
  lastName: 'Doe',
  getFullName() {
    return `${this.firstName} ${this.lastName}`;
  }
};

const person2 = {
  firstName: 'Jane',
  lastName: 'Smith'
};

// call() - invokes function immediately with individual arguments
function greet(greeting, punctuation) {
  console.log(`${greeting}, ${this.firstName}${punctuation}`);
}

greet.call(person2, 'Hello', '!');  // "Hello, Jane!"

// apply() - invokes function immediately with arguments as array
greet.apply(person2, ['Hi', '.']);  // "Hi, Jane."

// bind() - returns new function with bound context
const boundGreet = greet.bind(person2);
boundGreet('Hey', '!!!');  // "Hey, Jane!!!"

// Practical example with bind for event handlers
class Timer {
  constructor() {
    this.seconds = 0;
    // Without bind, this would refer to the button element
    document.getElementById('start').addEventListener('click', this.start.bind(this));
  }
  
  start() {
    setInterval(() => {
      this.seconds++;
      console.log(this.seconds);
    }, 1000);
  }
}
```

### 10. What are arrow functions and how do they differ from regular functions?

**Answer:**
Arrow functions are a concise way to write functions introduced in ES6. They have several key differences from regular functions:

```javascript
// Regular function
function regularFunction(a, b) {
  return a + b;
}

// Arrow function
const arrowFunction = (a, b) => a + b;

// Key differences:

// 1. Syntax variations
const single = x => x * 2;           // Single parameter, no parentheses
const multiple = (x, y) => x + y;    // Multiple parameters
const block = x => {                 // Block body
  const result = x * 2;
  return result;
};

// 2. 'this' binding - Arrow functions inherit 'this' from enclosing scope
class Counter {
  constructor() {
    this.count = 0;
  }
  
  // Regular function - 'this' depends on how it's called
  regularIncrement: function() {
    setTimeout(function() {
      this.count++; // 'this' is undefined or global object
    }, 1000);
  }
  
  // Arrow function - 'this' inherited from Counter instance
  arrowIncrement: function() {
    setTimeout(() => {
      this.count++; // 'this' refers to Counter instance
    }, 1000);
  }
}

// 3. Cannot be used as constructors
const ArrowConstructor = () => {};
// new ArrowConstructor(); // TypeError: ArrowConstructor is not a constructor

// 4. No 'arguments' object
function regularFunc() {
  console.log(arguments); // Available
}

const arrowFunc = () => {
  console.log(arguments); // ReferenceError
};

// Use rest parameters instead
const arrowWithRest = (...args) => {
  console.log(args); // Works fine
};

// 5. Cannot be hoisted (function expressions)
// arrowFunc(); // ReferenceError
const arrowFunc = () => console.log('Arrow');
```

## ES6+ Features

### 11. Explain destructuring assignment in JavaScript.

**Answer:**
Destructuring assignment allows you to extract values from arrays or properties from objects into distinct variables using a syntax that mirrors array and object literals.

```javascript
// Array Destructuring
const numbers = [1, 2, 3, 4, 5];

// Traditional way
const first = numbers[0];
const second = numbers[1];

// Destructuring way
const [first, second, ...rest] = numbers;
console.log(first);  // 1
console.log(second); // 2
console.log(rest);   // [3, 4, 5]

// Skipping elements
const [a, , c] = numbers;  // Skip second element
console.log(a, c);  // 1, 3

// Default values
const [x = 0, y = 0] = [1];  // x = 1, y = 0

// Object Destructuring
const person = {
  name: 'John',
  age: 30,
  city: 'New York',
  country: 'USA'
};

// Traditional way
const name = person.name;
const age = person.age;

// Destructuring way
const { name, age, city } = person;

// Renaming variables
const { name: personName, age: personAge } = person;

// Default values
const { height = 180 } = person;  // height = 180 (default)

// Nested destructuring
const user = {
  id: 1,
  profile: {
    name: 'John',
    address: {
      street: '123 Main St',
      city: 'Boston'
    }
  }
};

const {
  profile: {
    name: userName,
    address: { city: userCity }
  }
} = user;

// Function parameter destructuring
function greet({ name, age = 25 }) {
  console.log(`Hello ${name}, you are ${age} years old`);
}

greet({ name: 'Alice', age: 30 });  // "Hello Alice, you are 30 years old"
greet({ name: 'Bob' });             // "Hello Bob, you are 25 years old"

// Array destructuring in function returns
function getCoordinates() {
  return [10, 20];
}

const [x, y] = getCoordinates();
```

### 12. What are template literals and their advantages?

**Answer:**
Template literals are string literals that allow embedded expressions, multi-line strings, and string interpolation using backticks (`) instead of quotes.

```javascript
// Traditional string concatenation
const name = 'John';
const age = 30;
const message = 'Hello, my name is ' + name + ' and I am ' + age + ' years old.';

// Template literals
const messageTemplate = `Hello, my name is ${name} and I am ${age} years old.`;

// Advantages:

// 1. Expression interpolation
const a = 5, b = 10;
console.log(`The sum of ${a} and ${b} is ${a + b}.`);
// "The sum of 5 and 10 is 15."

// 2. Multi-line strings
const multiLine = `
  This is a
  multi-line
  string without
  escape characters
`;

// Traditional multi-line (ugly)
const traditionalMultiLine = 'This is a\n' +
  'multi-line\n' +
  'string with\n' +
  'escape characters';

// 3. Function calls in expressions
function formatCurrency(amount) {
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'USD'
  }).format(amount);
}

const price = 1234.56;
console.log(`The price is ${formatCurrency(price)}`);
// "The price is $1,234.56"

// 4. Conditional expressions
const isLoggedIn = true;
const greeting = `Welcome ${isLoggedIn ? 'back' : 'guest'}!`;

// 5. HTML template generation
function createUserCard(user) {
  return `
    <div class="user-card">
      <h2>${user.name}</h2>
      <p>Email: ${user.email}</p>
      <p>Role: ${user.role}</p>
      ${user.isActive ? '<span class="active">Active</span>' : '<span class="inactive">Inactive</span>'}
    </div>
  `;
}

// 6. Tagged template literals (advanced)
function highlight(strings, ...values) {
  return strings.reduce((result, string, i) => {
    const value = values[i] ? `<mark>${values[i]}</mark>` : '';
    return result + string + value;
  }, '');
}

const term = 'JavaScript';
const highlighted = highlight`Learning ${term} is fun!`;
// "Learning <mark>JavaScript</mark> is fun!"
```

### 13. Explain the rest and spread operators.

**Answer:**
The rest (`...`) and spread (`...`) operators use the same syntax but serve opposite purposes:

**Rest Operator** - Collects multiple elements into an array
**Spread Operator** - Expands elements from an array/object

```javascript
// REST OPERATOR

// 1. Function parameters
function sum(...numbers) {
  return numbers.reduce((total, num) => total + num, 0);
}

console.log(sum(1, 2, 3, 4, 5)); // 15

// 2. Array destructuring
const [first, second, ...others] = [1, 2, 3, 4, 5];
console.log(first);  // 1
console.log(second); // 2
console.log(others); // [3, 4, 5]

// 3. Object destructuring
const { name, age, ...details } = {
  name: 'John',
  age: 30,
  city: 'NYC',
  country: 'USA',
  job: 'Developer'
};
console.log(details); // { city: 'NYC', country: 'USA', job: 'Developer' }

// SPREAD OPERATOR

// 1. Array spreading
const arr1 = [1, 2, 3];
const arr2 = [4, 5, 6];
const combined = [...arr1, ...arr2]; // [1, 2, 3, 4, 5, 6]

// Array cloning
const original = [1, 2, 3];
const copy = [...original]; // Shallow copy

// Adding elements
const extended = [0, ...original, 4]; // [0, 1, 2, 3, 4]

// 2. Object spreading
const obj1 = { a: 1, b: 2 };
const obj2 = { c: 3, d: 4 };
const merged = { ...obj1, ...obj2 }; // { a: 1, b: 2, c: 3, d: 4 }

// Object cloning and updating
const user = { name: 'John', age: 30 };
const updatedUser = { ...user, age: 31, city: 'NYC' };
// { name: 'John', age: 31, city: 'NYC' }

// 3. Function arguments
function greet(greeting, name, punctuation) {
  console.log(`${greeting}, ${name}${punctuation}`);
}

const args = ['Hello', 'John', '!'];
greet(...args); // "Hello, John!"

// 4. Converting NodeList to Array
const elements = document.querySelectorAll('.item');
const elementsArray = [...elements];

// 5. Finding max/min in array
const numbers = [1, 5, 3, 9, 2];
const max = Math.max(...numbers); // 9
const min = Math.min(...numbers); // 1

// 6. String to array
const string = 'hello';
const chars = [...string]; // ['h', 'e', 'l', 'l', 'o']

// Practical example: Removing duplicates
const duplicates = [1, 2, 2, 3, 3, 4];
const unique = [...new Set(duplicates)]; // [1, 2, 3, 4]
```

## Asynchronous JavaScript

### 14. What is the Event Loop in JavaScript?

**Answer:**
The Event Loop is the mechanism that handles asynchronous operations in JavaScript. It allows JavaScript to perform non-blocking operations despite being single-threaded.

```javascript
// Event Loop Components:
// 1. Call Stack - Where function calls are stored
// 2. Web APIs - Browser/Node.js APIs (setTimeout, fetch, DOM events)
// 3. Callback Queue (Task Queue) - Where callbacks wait
// 4. Microtask Queue - Higher priority queue for Promises
// 5. Event Loop - Moves tasks from queues to call stack

// Example demonstrating execution order
console.log('1'); // Synchronous - goes to call stack

setTimeout(() => {
  console.log('2'); // Macro task - goes to callback queue
}, 0);

Promise.resolve().then(() => {
  console.log('3'); // Micro task - goes to microtask queue
});

console.log('4'); // Synchronous - goes to call stack

// Output: 1, 4, 3, 2
// Explanation:
// 1. '1' executes immediately (call stack)
// 2. setTimeout callback goes to callback queue
// 3. Promise.then goes to microtask queue
// 4. '4' executes immediately (call stack)
// 5. Event loop checks microtask queue first - executes '3'
// 6. Event loop checks callback queue - executes '2'

// More complex example
console.log('Start');

setTimeout(() => console.log('Timeout 1'), 0);
setTimeout(() => console.log('Timeout 2'), 0);

Promise.resolve().then(() => {
  console.log('Promise 1');
  return Promise.resolve();
}).then(() => {
  console.log('Promise 2');
});

Promise.resolve().then(() => {
  console.log('Promise 3');
});

console.log('End');

// Output: Start, End, Promise 1, Promise 3, Promise 2, Timeout 1, Timeout 2

// Event Loop Priority:
// 1. Call Stack (synchronous code)
// 2. Microtask Queue (Promises, queueMicrotask)
// 3. Callback Queue (setTimeout, setInterval, DOM events)
```

### 15. Explain async/await and how it differs from Promises.

**Answer:**
`async/await` is syntactic sugar built on top of Promises that makes asynchronous code look and behave more like synchronous code.

```javascript
// Promise-based approach
function fetchUserData() {
  return fetch('/api/user')
    .then(response => response.json())
    .then(user => {
      console.log('User:', user);
      return fetch(`/api/posts/${user.id}`);
    })
    .then(response => response.json())
    .then(posts => {
      console.log('Posts:', posts);
      return posts;
    })
    .catch(error => {
      console.error('Error:', error);
      throw error;
    });
}

// async/await approach
async function fetchUserDataAsync() {
  try {
    const response = await fetch('/api/user');
    const user = await response.json();
    console.log('User:', user);
    
    const postsResponse = await fetch(`/api/posts/${user.id}`);
    const posts = await postsResponse.json();
    console.log('Posts:', posts);
    
    return posts;
  } catch (error) {
    console.error('Error:', error);
    throw error;
  }
}

// Key Differences:

// 1. Readability - async/await is more readable
// 2. Error handling - try/catch vs .catch()
// 3. Debugging - easier to debug with async/await
// 4. Conditional logic - easier with async/await

// Conditional async operations
async function conditionalFetch(includeComments) {
  const user = await fetchUser();
  
  if (includeComments) {
    const comments = await fetchComments(user.id);
    return { user, comments };
  }
  
  return { user };
}

// Parallel execution
async function fetchParallel() {
  // Sequential (slow)
  const user = await fetchUser();
  const posts = await fetchPosts();
  
  // Parallel (fast)
  const [userParallel, postsParallel] = await Promise.all([
    fetchUser(),
    fetchPosts()
  ]);
  
  return { userParallel, postsParallel };
}

// Error handling differences
async function errorHandling() {
  try {
    const result1 = await operation1();
    const result2 = await operation2();
    const result3 = await operation3();
    return { result1, result2, result3 };
  } catch (error) {
    // Catches any error from any of the operations
    console.error('Operation failed:', error);
    throw error;
  }
}

// Promise equivalent (more verbose)
function errorHandlingPromise() {
  return operation1()
    .then(result1 => {
      return operation2()
        .then(result2 => {
          return operation3()
            .then(result3 => ({ result1, result2, result3 }));
        });
    })
    .catch(error => {
      console.error('Operation failed:', error);
      throw error;
    });
}

// Important notes:
// 1. async functions always return a Promise
// 2. await can only be used inside async functions
// 3. await pauses function execution until Promise resolves
// 4. Multiple awaits are sequential unless wrapped in Promise.all()

// Top-level await (ES2022)
// In modules, you can use await at the top level
const config = await fetch('/api/config').then(r => r.json());
```

### 16. What is the difference between `setTimeout`, `setInterval`, and `requestAnimationFrame`?

**Answer:**
These are three different ways to schedule code execution in JavaScript, each with specific use cases:

```javascript
// 1. SETTIMEOUT - Executes code once after a specified delay
setTimeout(() => {
  console.log('Executed after 1 second');
}, 1000);

// Clearing timeout
const timeoutId = setTimeout(() => {
  console.log('This might not execute');
}, 5000);

clearTimeout(timeoutId); // Cancels the timeout

// 2. SETINTERVAL - Executes code repeatedly at specified intervals
const intervalId = setInterval(() => {
  console.log('Executed every 2 seconds');
}, 2000);

// Clearing interval
setTimeout(() => {
  clearInterval(intervalId);
  console.log('Interval cleared');
}, 10000);

// 3. REQUESTANIMATIONFRAME - Optimized for animations
function animate() {
  // Animation logic here
  console.log('Frame rendered');
  
  // Continue animation
  requestAnimationFrame(animate);
}

requestAnimationFrame(animate);

// PRACTICAL COMPARISONS

// Timer-based animation (not recommended)
let position = 0;
setInterval(() => {
  position += 5;
  element.style.left = position + 'px';
}, 16); // ~60fps

// RAF-based animation (recommended)
let position = 0;
function animate() {
  position += 5;
  element.style.left = position + 'px';
  
  if (position < 500) {
    requestAnimationFrame(animate);
  }
}
requestAnimationFrame(animate);

// KEY DIFFERENCES:

// setTimeout:
// - Executes once
// - Minimum delay ~4ms (HTML5 spec)
// - Not frame-synchronized
const delayedExecution = () => {
  setTimeout(() => {
    console.log('Single execution');
  }, 1000);
};

// setInterval:
// - Executes repeatedly
// - Can drift over time
// - Continues even when tab is not visible
let counter = 0;
const intervalExample = () => {
  const id = setInterval(() => {
    counter++;
    console.log(`Count: ${counter}`);
    
    if (counter >= 5) {
      clearInterval(id);
    }
  }, 1000);
};

// requestAnimationFrame:
// - Synced with display refresh rate (usually 60fps)
// - Pauses when tab is not visible (battery optimization)
// - Ideal for smooth animations
let startTime = null;
function animationExample(timestamp) {
  if (!startTime) startTime = timestamp;
  const progress = timestamp - startTime;
  
  // Move element based on time
  element.style.transform = `translateX(${progress / 10}px)`;
  
  if (progress < 2000) { // Run for 2 seconds
    requestAnimationFrame(animationExample);
  }
}
requestAnimationFrame(animationExample);

// PERFORMANCE CONSIDERATIONS

// Bad: Using setInterval for animations
let badPosition = 0;
setInterval(() => {
  badPosition += 2;
  element.style.left = badPosition + 'px';
}, 16); // Tries for 60fps but not guaranteed

// Good: Using requestAnimationFrame
let goodPosition = 0;
function smoothAnimation() {
  goodPosition += 2;
  element.style.left = goodPosition + 'px';
  
  if (goodPosition < 500) {
    requestAnimationFrame(smoothAnimation);
  }
}
requestAnimationFrame(smoothAnimation);

// Debouncing with setTimeout
function debounce(func, wait) {
  let timeout;
  return function executedFunction(...args) {
    const later = () => {
      clearTimeout(timeout);
      func(...args);
    };
    clearTimeout(timeout);
    timeout = setTimeout(later, wait);
  };
}

// Usage
const debouncedSearch = debounce((query) => {
  console.log('Searching for:', query);
}, 300);
```

## Common JavaScript Challenges

### 17. How do you deep clone an object in JavaScript?

**Answer:**
There are several methods to deep clone objects, each with different capabilities and limitations:

```javascript
// Method 1: JSON.parse(JSON.stringify()) - Limited but common
const original = {
  name: 'John',
  age: 30,
  hobbies: ['reading', 'gaming'],
  address: {
    city: 'NYC',
    country: 'USA'
  }
};

// Simple JSON method (limitations: no functions, undefined, Symbol, Date)
const jsonClone = JSON.parse(JSON.stringify(original));

// Method 2: Custom recursive function
function deepClone(obj) {
  if (obj === null || typeof obj !== 'object') {
    return obj;
  }
  
  if (obj instanceof Date) {
    return new Date(obj);
  }
  
  if (obj instanceof Array) {
    return obj.map(item => deepClone(item));
  }
  
  if (obj instanceof Object) {
    const clonedObj = {};
    for (let key in obj) {
      if (obj.hasOwnProperty(key)) {
        clonedObj[key] = deepClone(obj[key]);
      }
    }
    return clonedObj;
  }
}

// Method 3: Using structuredClone (modern browsers)
const modernClone = structuredClone(original);

// Method 4: Lodash library
// const lodashClone = _.cloneDeep(original);

// COMPARISON OF METHODS

const complexObject = {
  string: 'Hello',
  number: 42,
  boolean: true,
  nullValue: null,
  undefinedValue: undefined,
  date: new Date(),
  regex: /hello/gi,
  func: function() { return 'hello'; },
  symbol: Symbol('id'),
  nested: {
    array: [1, 2, { deep: 'value' }],
    set: new Set([1, 2, 3]),
    map: new Map([['key', 'value']])
  }
};

// JSON method limitations
console.log('Original has function:', typeof complexObject.func); // 'function'
const jsonCloned = JSON.parse(JSON.stringify(complexObject));
console.log('JSON clone has function:', typeof jsonCloned.func); // 'undefined'

// Custom deep clone handles most cases
const customCloned = deepClone(complexObject);
console.log('Custom clone preserves most properties');

// structuredClone handles more types
const structuredCloned = structuredClone(complexObject);
console.log('Structured clone handles Date, RegExp, etc.');

// PERFORMANCE COMPARISON
function performanceTest() {
  const largeObject = {
    data: new Array(1000).fill().map((_, i) => ({
      id: i,
      name: `Item ${i}`,
      nested: { value: i * 2 }
    }))
  };
  
  console.time('JSON method');
  JSON.parse(JSON.stringify(largeObject));
  console.timeEnd('JSON method');
  
  console.time('Custom function');
  deepClone(largeObject);
  console.timeEnd('Custom function');
  
  console.time('structuredClone');
  structuredClone(largeObject);
  console.timeEnd('structuredClone');
}

// PRACTICAL USAGE EXAMPLES

// Redux state updates
const updateUserState = (state, updates) => {
  return {
    ...state,
    user: {
      ...state.user,
      ...updates
    }
  };
};

// Form data backup
class FormManager {
  constructor() {
    this.originalData = null;
    this.currentData = null;
  }
  
  saveSnapshot(formData) {
    this.originalData = deepClone(formData);
    this.currentData = deepClone(formData);
  }
  
  hasChanges() {
    return JSON.stringify(this.originalData) !== JSON.stringify(this.currentData);
  }
  
  reset() {
    this.currentData = deepClone(this.originalData);
  }
}

// Configuration object cloning
const defaultConfig = {
  api: {
    baseUrl: 'https://api.example.com',
    timeout: 5000,
    retries: 3
  },
  features: {
    authentication: true,
    analytics: false
  }
};

function createUserConfig(overrides = {}) {
  const config = deepClone(defaultConfig);
  return Object.assign(config, overrides);
}
```

### 18. Explain debouncing and throttling with examples.

**Answer:**
Debouncing and throttling are techniques to control how often a function executes, particularly useful for performance optimization with events like scrolling, resizing, or user input.

```javascript
// DEBOUNCING - Delays execution until after a period of inactivity

function debounce(func, wait, immediate = false) {
  let timeout;
  
  return function executedFunction(...args) {
    const later = () => {
      timeout = null;
      if (!immediate) func.apply(this, args);
    };
    
    const callNow = immediate && !timeout;
    clearTimeout(timeout);
    timeout = setTimeout(later, wait);
    
    if (callNow) func.apply(this, args);
  };
}

// THROTTLING - Limits execution to once per specified interval

function throttle(func, limit) {
  let inThrottle;
  
  return function(...args) {
    if (!inThrottle) {
      func.apply(this, args);
      inThrottle = true;
      setTimeout(() => inThrottle = false, limit);
    }
  };
}

// PRACTICAL EXAMPLES

// 1. Search Input Debouncing
const searchInput = document.getElementById('search');
const searchAPI = (query) => {
  console.log('Searching for:', query);
  // API call here
};

const debouncedSearch = debounce((event) => {
  searchAPI(event.target.value);
}, 300);

searchInput.addEventListener('input', debouncedSearch);

// Without debouncing: API called on every keystroke
// With debouncing: API called only after user stops typing for 300ms

// 2. Scroll Event Throttling
const handleScroll = () => {
  console.log('Scroll position:', window.scrollY);
  // Expensive operations here
};

const throttledScroll = throttle(handleScroll, 100);
window.addEventListener('scroll', throttledScroll);

// Without throttling: Function called hundreds of times per second
// With throttling: Function called at most once every 100ms

// 3. Button Click Debouncing (preventing double-clicks)
const submitButton = document.getElementById('submit');
const submitForm = () => {
  console.log('Form submitted');
  // Form submission logic
};

const debouncedSubmit = debounce(submitForm, 1000, true); // immediate = true
submitButton.addEventListener('click', debouncedSubmit);

// 4. Window Resize Debouncing
const handleResize = () => {
  console.log('Window resized:', window.innerWidth, window.innerHeight);
  // Layout recalculations
};

const debouncedResize = debounce(handleResize, 250);
window.addEventListener('resize', debouncedResize);

// ADVANCED IMPLEMENTATIONS

// Debounce with cancellation
function advancedDebounce(func, wait) {
  let timeout;
  
  const debounced = function(...args) {
    clearTimeout(timeout);
    timeout = setTimeout(() => func.apply(this, args), wait);
  };
  
  debounced.cancel = () => {
    clearTimeout(timeout);
    timeout = null;
  };
  
  debounced.flush = function(...args) {
    if (timeout) {
      clearTimeout(timeout);
      func.apply(this, args);
    }
  };
  
  return debounced;
}

// Usage with cancellation
const debouncedFunction = advancedDebounce(() => {
  console.log('Executed');
}, 1000);

debouncedFunction(); // Will execute after 1000ms
debouncedFunction.cancel(); // Cancels execution

// Throttle with leading and trailing options
function advancedThrottle(func, limit, options = {}) {
  let timeout;
  let previous = 0;
  const { leading = true, trailing = true } = options;
  
  return function(...args) {
    const now = Date.now();
    
    if (!previous && !leading) previous = now;
    const remaining = limit - (now - previous);
    
    if (remaining <= 0 || remaining > limit) {
      if (timeout) {
        clearTimeout(timeout);
        timeout = null;
      }
      previous = now;
      func.apply(this, args);
    } else if (!timeout && trailing) {
      timeout = setTimeout(() => {
        previous = leading ? Date.now() : 0;
        timeout = null;
        func.apply(this, args);
      }, remaining);
    }
  };
}

// REAL-WORLD USE CASES

// Auto-save functionality
class AutoSave {
  constructor(saveFunction, delay = 2000) {
    this.save = debounce(saveFunction, delay);
  }
  
  onContentChange(content) {
    this.save(content);
  }
}

const autoSave = new AutoSave((content) => {
  console.log('Saving:', content);
  // Save to server
}, 2000);

// Infinite scroll
class InfiniteScroll {
  constructor(loadMore, threshold = 100) {
    this.loadMore = throttle(loadMore, 1000);
    this.threshold = threshold;
    this.bindEvents();
  }
  
  bindEvents() {
    window.addEventListener('scroll', () => {
      const { scrollTop, scrollHeight, clientHeight } = document.documentElement;
      
      if (scrollTop + clientHeight >= scrollHeight - this.threshold) {
        this.loadMore();
      }
    });
  }
}

// Rate limiting API calls
class APIRateLimit {
  constructor(maxCalls = 10, timeWindow = 60000) {
    this.calls = [];
    this.maxCalls = maxCalls;
    this.timeWindow = timeWindow;
  }
  
  throttledRequest = throttle(this.makeRequest.bind(this), 1000);
  
  makeRequest(url, options) {
    const now = Date.now();
    this.calls = this.calls.filter(time => now - time < this.timeWindow);
    
    if (this.calls.length >= this.maxCalls) {
      throw new Error('Rate limit exceeded');
    }
    
    this.calls.push(now);
    return fetch(url, options);
  }
}

// COMPARISON SUMMARY
/*
Debouncing:
- Use for: Search inputs, form validation, auto-save
- Behavior: Waits for pause in activity
- Example: Only search after user stops typing

Throttling:
- Use for: Scroll events, mouse movements, resize events
- Behavior: Limits frequency of execution
- Example: Update scroll position at most once every 100ms
*/
```

### 19. What are JavaScript modules and how do they work?

**Answer:**
JavaScript modules are reusable pieces of code that can export functionality for use in other modules. They help organize code, avoid global namespace pollution, and enable code reuse.

```javascript
// ES6 MODULES (ESM) - Modern Standard

// math.js - Exporting module
export const PI = 3.14159;

export function add(a, b) {
  return a + b;
}

export function multiply(a, b) {
  return a * b;
}

// Default export
export default function subtract(a, b) {
  return a - b;
}

// Alternative export syntax
const divide = (a, b) => a / b;
const power = (base, exponent) => Math.pow(base, exponent);

export { divide, power };

// app.js - Importing module
import subtract, { add, multiply, PI } from './math.js';
import { divide as div, power } from './math.js';
import * as MathUtils from './math.js';

console.log(add(5, 3));           // 8
console.log(subtract(5, 3));      // 2 (default import)
console.log(div(6, 2));           // 3 (renamed import)
console.log(MathUtils.PI);        // 3.14159 (namespace import)

// COMMONJS MODULES (Node.js)

// math.js - CommonJS export
const PI = 3.14159;

function add(a, b) {
  return a + b;
}

function multiply(a, b) {
  return a * b;
}

// Multiple exports
module.exports = {
  PI,
  add,
  multiply
};

// Or individual exports
exports.divide = (a, b) => a / b;

// Default export equivalent
module.exports = function subtract(a, b) {
  return a - b;
};

// app.js - CommonJS import
const { add, multiply, PI } = require('./math');
const MathUtils = require('./math');
const subtract = require('./math'); // If module.exports is function

// ADVANCED MODULE PATTERNS

// 1. Conditional/Dynamic Imports
async function loadModule(moduleName) {
  if (moduleName === 'math') {
    const mathModule = await import('./math.js');
    return mathModule;
  }
}

// Usage
loadModule('math').then(math => {
  console.log(math.add(2, 3));
});

// 2. Module factory pattern
// logger.js
export function createLogger(level = 'info') {
  return {
    info: (msg) => level === 'info' && console.log(`[INFO] ${msg}`),
    warn: (msg) => ['warn', 'info'].includes(level) && console.warn(`[WARN] ${msg}`),
    error: (msg) => console.error(`[ERROR] ${msg}`)
  };
}

// Usage
import { createLogger } from './logger.js';
const logger = createLogger('warn');

// 3. Module with private variables (closure)
// counter.js
let count = 0;

export function increment() {
  return ++count;
}

export function decrement() {
  return --count;
}

export function getCount() {
  return count;
}

// count variable is private and can't be accessed directly

// 4. Class modules
// User.js
export default class User {
  constructor(name, email) {
    this.name = name;
    this.email = email;
  }
  
  getProfile() {
    return {
      name: this.name,
      email: this.email
    };
  }
  
  static validateEmail(email) {
    return /\S+@\S+\.\S+/.test(email);
  }
}

// Usage
import User from './User.js';
const user = new User('John', 'john@example.com');

// 5. Configuration modules
// config.js
const config = {
  development: {
    apiUrl: 'http://localhost:3000',
    debug: true
  },
  production: {
    apiUrl: 'https://api.example.com',
    debug: false
  }
};

export default config[process.env.NODE_ENV || 'development'];

// 6. Utility modules with multiple functions
// utils.js
export const formatDate = (date) => {
  return new Intl.DateTimeFormat('en-US').format(date);
};

export const debounce = (func, wait) => {
  let timeout;
  return function(...args) {
    clearTimeout(timeout);
    timeout = setTimeout(() => func.apply(this, args), wait);
  };
};

export const generateId = () => {
  return Math.random().toString(36).substr(2, 9);
};

// Re-exporting from other modules
export { default as ApiClient } from './api-client.js';
export * from './validators.js';

// PRACTICAL EXAMPLES

// API module structure
// api/
//   index.js
//   users.js
//   posts.js

// api/users.js
const BASE_URL = '/api/users';

export async function getUsers() {
  const response = await fetch(BASE_URL);
  return response.json();
}

export async function getUserById(id) {
  const response = await fetch(`${BASE_URL}/${id}`);
  return response.json();
}

export async function createUser(userData) {
  const response = await fetch(BASE_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(userData)
  });
  return response.json();
}

// api/index.js - Barrel export
export * from './users.js';
export * from './posts.js';

// Usage
import { getUsers, createUser } from './api/index.js';

// MODULE LOADING STRATEGIES

// 1. Tree shaking (bundler optimization)
// Only imports used functions, reducing bundle size
import { debounce } from './utils.js'; // Only debounce is included in bundle

// 2. Code splitting with dynamic imports
async function loadFeature() {
  const { AdvancedFeature } = await import('./advanced-feature.js');
  return new AdvancedFeature();
}

// 3. Lazy loading
const LazyComponent = React.lazy(() => import('./LazyComponent.js'));

// MODULE BEST PRACTICES

// 1. Use named exports for utilities, default for main functionality
// 2. Keep modules focused on single responsibility
// 3. Avoid circular dependencies
// 4. Use barrel exports (index.js) for clean imports
// 5. Consider file naming conventions
// 6. Use TypeScript for better module interfaces

// Example of circular dependency issue:
// moduleA.js
import { functionB } from './moduleB.js';
export function functionA() {
  return functionB();
}

// moduleB.js
import { functionA } from './moduleA.js'; // Circular dependency!
export function functionB() {
  return functionA();
}

// Solution: Extract shared functionality to a third module
```

### 20. How do you handle errors in JavaScript?

**Answer:**
Error handling in JavaScript involves anticipating, catching, and responding to runtime errors to prevent application crashes and provide better user experience.

```javascript
// 1. TRY-CATCH-FINALLY

// Basic try-catch
try {
  const result = riskyOperation();
  console.log(result);
} catch (error) {
  console.error('Error occurred:', error.message);
} finally {
  console.log('This always executes');
}

// Catching specific error types
try {
  JSON.parse(invalidJSON);
} catch (error) {
  if (error instanceof SyntaxError) {
    console.error('Invalid JSON format');
  } else if (error instanceof ReferenceError) {
    console.error('Variable not defined');
  } else {
    console.error('Unknown error:', error);
  }
}

// 2. CUSTOM ERROR TYPES

class ValidationError extends Error {
  constructor(message, field) {
    super(message);
    this.name = 'ValidationError';
    this.field = field;
  }
}

class NetworkError extends Error {
  constructor(message, statusCode) {
    super(message);
    this.name = 'NetworkError';
    this.statusCode = statusCode;
  }
}

// Using custom errors
function validateUser(user) {
  if (!user.email) {
    throw new ValidationError('Email is required', 'email');
  }
  if (!user.name) {
    throw new ValidationError('Name is required', 'name');
  }
}

try {
  validateUser({ name: 'John' }); // Missing email
} catch (error) {
  if (error instanceof ValidationError) {
    console.error(`Validation failed for ${error.field}: ${error.message}`);
  }
}

// 3. ASYNC ERROR HANDLING

// Promise-based error handling
function fetchUserData(id) {
  return fetch(`/api/users/${id}`)
    .then(response => {
      if (!response.ok) {
        throw new NetworkError(`HTTP ${response.status}`, response.status);
      }
      return response.json();
    })
    .catch(error => {
      if (error instanceof NetworkError) {
        console.error('Network issue:', error.message);
      } else {
        console.error('Unexpected error:', error);
      }
      throw error; // Re-throw for caller to handle
    });
}

// async/await error handling
async function getUserData(id) {
  try {
    const response = await fetch(`/api/users/${id}`);
    
    if (!response.ok) {
      throw new NetworkError(`HTTP ${response.status}`, response.status);
    }
    
    const userData = await response.json();
    return userData;
  } catch (error) {
    if (error instanceof NetworkError) {
      console.error('Network error:', error.message);
      // Maybe show user-friendly message
      showErrorMessage('Unable to load user data. Please try again.');
    } else if (error instanceof SyntaxError) {
      console.error('Invalid JSON response');
    } else {
      console.error('Unexpected error:', error);
    }
    
    // Return default value or re-throw
    return null;
  }
}

// 4. GLOBAL ERROR HANDLING

// Unhandled promise rejections
window.addEventListener('unhandledrejection', (event) => {
  console.error('Unhandled promise rejection:', event.reason);
  
  // Prevent default browser behavior
  event.preventDefault();
  
  // Log to error reporting service
  errorReportingService.log({
    type: 'unhandledPromiseRejection',
    error: event.reason,
    timestamp: new Date().toISOString()
  });
});

// Global error handler
window.addEventListener('error', (event) => {
  console.error('Global error:', {
    message: event.message,
    filename: event.filename,
    line: event.lineno,
    column: event.colno,
    error: event.error
  });
  
  // Log to error reporting service
  errorReportingService.log({
    type: 'globalError',
    message: event.message,
    stack: event.error?.stack,
    timestamp: new Date().toISOString()
  });
});

// 5. ERROR BOUNDARY PATTERN (React-like)

class ErrorHandler {
  constructor() {
    this.errorListeners = [];
  }
  
  addErrorListener(callback) {
    this.errorListeners.push(callback);
  }
  
  handleError(error, context = '') {
    console.error(`Error in ${context}:`, error);
    
    // Notify all listeners
    this.errorListeners.forEach(listener => {
      try {
        listener(error, context);
      } catch (listenerError) {
        console.error('Error in error listener:', listenerError);
      }
    });
  }
  
  async executeWithErrorHandling(fn, context = '') {
    try {
      return await fn();
    } catch (error) {
      this.handleError(error, context);
      throw error;
    }
  }
}

// Usage
const errorHandler = new ErrorHandler();

errorHandler.addErrorListener((error, context) => {
  // Send to analytics
  analytics.track('error', { error: error.message, context });
});

// 6. RETRY PATTERN WITH ERROR HANDLING

async function retryOperation(operation, maxRetries = 3, delay = 1000) {
  let lastError;
  
  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      return await operation();
    } catch (error) {
      lastError = error;
      
      if (attempt === maxRetries) {
        throw new Error(`Operation failed after ${maxRetries} attempts: ${error.message}`);
      }
      
      console.warn(`Attempt ${attempt} failed, retrying in ${delay}ms...`);
      await new Promise(resolve => setTimeout(resolve, delay));
      
      // Exponential backoff
      delay *= 2;
    }
  }
}

// Usage
try {
  const data = await retryOperation(() => fetch('/api/data').then(r => r.json()));
} catch (error) {
  console.error('All retry attempts failed:', error);
}

// 7. CIRCUIT BREAKER PATTERN

class CircuitBreaker {
  constructor(threshold = 5, timeout = 60000) {
    this.threshold = threshold;
    this.timeout = timeout;
    this.failureCount = 0;
    this.lastFailureTime = null;
    this.state = 'CLOSED'; // CLOSED, OPEN, HALF_OPEN
  }
  
  async execute(operation) {
    if (this.state === 'OPEN') {
      if (Date.now() - this.lastFailureTime > this.timeout) {
        this.state = 'HALF_OPEN';
      } else {
        throw new Error('Circuit breaker is OPEN');
      }
    }
    
    try {
      const result = await operation();
      this.onSuccess();
      return result;
    } catch (error) {
      this.onFailure();
      throw error;
    }
  }
  
  onSuccess() {
    this.failureCount = 0;
    this.state = 'CLOSED';
  }
  
  onFailure() {
    this.failureCount++;
    this.lastFailureTime = Date.now();
    
    if (this.failureCount >= this.threshold) {
      this.state = 'OPEN';
    }
  }
}

// 8. PRACTICAL ERROR HANDLING UTILITIES

// Error logging utility
class Logger {
  static error(message, error, context = {}) {
    const errorInfo = {
      message,
      error: error.message,
      stack: error.stack,
      timestamp: new Date().toISOString(),
      userAgent: navigator.userAgent,
      url: window.location.href,
      ...context
    };
    
    console.error('Error logged:', errorInfo);
    
    // Send to logging service
    this.sendToService(errorInfo);
  }
  
  static async sendToService(errorInfo) {
    try {
      await fetch('/api/errors', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(errorInfo)
      });
    } catch (loggingError) {
      console.error('Failed to log error to service:', loggingError);
    }
  }
}

// Form validation with error handling
class FormValidator {
  constructor(form) {
    this.form = form;
    this.errors = new Map();
  }
  
  validate() {
    this.errors.clear();
    
    try {
      const formData = new FormData(this.form);
      
      for (const [field, value] of formData) {
        this.validateField(field, value);
      }
      
      if (this.errors.size > 0) {
        throw new ValidationError('Form validation failed');
      }
      
      return true;
    } catch (error) {
      this.displayErrors();
      Logger.error('Form validation error', error);
      return false;
    }
  }
  
  validateField(field, value) {
    if (field === 'email' && !this.isValidEmail(value)) {
      this.errors.set(field, 'Invalid email format');
    }
    
    if (field === 'password' && value.length < 8) {
      this.errors.set(field, 'Password must be at least 8 characters');
    }
  }
  
  isValidEmail(email) {
    return /\S+@\S+\.\S+/.test(email);
  }
  
  displayErrors() {
    this.errors.forEach((message, field) => {
      const fieldElement = this.form.querySelector(`[name="${field}"]`);
      // Display error message near field
      this.showFieldError(fieldElement, message);
    });
  }
  
  showFieldError(field, message) {
    // Implementation for showing error message
    console.error(`${field.name}: ${message}`);
  }
}

// API client with comprehensive error handling
class ApiClient {
  constructor(baseUrl) {
    this.baseUrl = baseUrl;
    this.circuitBreaker = new CircuitBreaker();
  }
  
  async request(endpoint, options = {}) {
    try {
      return await this.circuitBreaker.execute(async () => {
        const url = `${this.baseUrl}${endpoint}`;
        const response = await fetch(url, {
          ...options,
          headers: {
            'Content-Type': 'application/json',
            ...options.headers
          }
        });
        
        if (!response.ok) {
          const errorData = await response.json().catch(() => ({}));
          throw new NetworkError(
            errorData.message || `HTTP ${response.status}`,
            response.status
          );
        }
        
        return response.json();
      });
    } catch (error) {
      Logger.error('API request failed', error, {
        endpoint,
        method: options.method || 'GET'
      });
      
      throw error;
    }
  }
}

// Best Practices Summary:
// 1. Use specific error types for different scenarios
// 2. Always log errors with context
// 3. Provide user-friendly error messages
// 4. Implement graceful degradation
// 5. Use global error handlers for unhandled errors
// 6. Consider retry mechanisms for transient failures
// 7. Implement circuit breakers for external services
// 8. Validate inputs early and thoroughly
// 9. Test error scenarios
// 10. Monitor and alert on error patterns
```

---

## Navigation

- ← Previous: [Technical Interview Questions Overview](README.md)
- → Next: [TypeScript Questions](typescript-questions.md)
- ↑ Back to: [Career Development Research](../README.md)

---

*These JavaScript questions cover fundamental to advanced concepts essential for senior full-stack developer positions.*
