# Fundamentals & Concepts - Functional Programming in JavaScript

## 🎯 Overview

This document provides a comprehensive exploration of core functional programming concepts as they apply to JavaScript development. Understanding these fundamentals is essential for building maintainable, testable applications and succeeds in technical interviews for remote positions in international markets.

## 🧩 Core Functional Programming Principles

### 1. Pure Functions

Pure functions are the foundation of functional programming - they produce the same output for the same input and have no side effects.

#### Definition & Characteristics
```javascript
// ✅ Pure function - deterministic and side-effect free
const add = (a, b) => a + b;
const multiply = (x, y) => x * y;
const calculateArea = (length, width) => length * width;

// ✅ Pure function with complex logic
const calculateStudentGrade = (scores, weights) => {
  const weightedSum = scores.reduce((sum, score, index) => 
    sum + (score * weights[index]), 0
  );
  const totalWeight = weights.reduce((sum, weight) => sum + weight, 0);
  return weightedSum / totalWeight;
};

// ❌ Impure function - depends on external state
let taxRate = 0.08;
const calculateTax = (amount) => amount * taxRate; // External dependency

// ❌ Impure function - has side effects
const logAndCalculate = (a, b) => {
  console.log(`Calculating ${a} + ${b}`); // Side effect
  return a + b;
};

// ❌ Impure function - modifies input
const addScore = (student, score) => {
  student.scores.push(score); // Mutation
  return student;
};
```

#### EdTech Application Examples
```javascript
// ✅ Pure functions for educational data processing
const calculateQuizScore = (answers, correctAnswers) =>
  answers.reduce((score, answer, index) => 
    answer === correctAnswers[index] ? score + 1 : score, 0
  ) / correctAnswers.length * 100;

const determinePassingStatus = (score, passingThreshold = 70) =>
  score >= passingThreshold ? 'PASSED' : 'FAILED';

const calculateStudyStreak = (sessionDates) => {
  const sortedDates = sessionDates
    .map(date => new Date(date).getTime())
    .sort((a, b) => a - b);
  
  let streak = 1;
  let maxStreak = 1;
  
  for (let i = 1; i < sortedDates.length; i++) {
    const daysDiff = (sortedDates[i] - sortedDates[i-1]) / (1000 * 60 * 60 * 24);
    if (daysDiff <= 1) {
      streak++;
      maxStreak = Math.max(maxStreak, streak);
    } else {
      streak = 1;
    }
  }
  
  return maxStreak;
};
```

### 2. Immutability

Immutability means data structures don't change after creation. Instead of modifying existing data, we create new versions.

#### Basic Immutable Operations
```javascript
// ✅ Immutable array operations
const originalArray = [1, 2, 3];
const newArray = [...originalArray, 4]; // [1, 2, 3, 4]
const filteredArray = originalArray.filter(x => x > 1); // [2, 3]
const mappedArray = originalArray.map(x => x * 2); // [2, 4, 6]

// ✅ Immutable object operations
const originalStudent = {
  id: 1,
  name: 'John Doe',
  grades: { math: 85, science: 92 }
};

const updatedStudent = {
  ...originalStudent,
  grades: {
    ...originalStudent.grades,
    english: 88
  }
};

// ✅ Functional array updates
const updateStudentById = (students, id, updates) =>
  students.map(student => 
    student.id === id ? { ...student, ...updates } : student
  );

const removeStudentById = (students, id) =>
  students.filter(student => student.id !== id);

const addStudent = (students, newStudent) =>
  [...students, { ...newStudent, id: generateId() }];
```

#### Advanced Immutable Patterns
```javascript
// ✅ Deep immutable updates with lens concept
const updateNestedProperty = (obj, path, value) => {
  const [head, ...tail] = path;
  
  if (tail.length === 0) {
    return { ...obj, [head]: value };
  }
  
  return {
    ...obj,
    [head]: updateNestedProperty(obj[head] || {}, tail, value)
  };
};

// Usage: updateNestedProperty(student, ['grades', 'math'], 95)

// ✅ Immutable state management for EdTech
const updateCourseProgress = (state, courseId, lessonId, progress) => ({
  ...state,
  courses: {
    ...state.courses,
    [courseId]: {
      ...state.courses[courseId],
      lessons: {
        ...state.courses[courseId].lessons,
        [lessonId]: {
          ...state.courses[courseId].lessons[lessonId],
          progress: Math.max(
            state.courses[courseId].lessons[lessonId]?.progress || 0,
            progress
          ),
          completedAt: progress === 100 ? new Date().toISOString() : null
        }
      }
    }
  }
});
```

### 3. Higher-Order Functions

Functions that take other functions as arguments or return functions as results.

#### Built-in Higher-Order Functions
```javascript
// ✅ Array methods as higher-order functions
const numbers = [1, 2, 3, 4, 5];

// map: transforms each element
const doubled = numbers.map(x => x * 2); // [2, 4, 6, 8, 10]

// filter: selects elements based on predicate
const evens = numbers.filter(x => x % 2 === 0); // [2, 4]

// reduce: accumulates values
const sum = numbers.reduce((acc, x) => acc + x, 0); // 15

// find: returns first matching element
const firstEven = numbers.find(x => x % 2 === 0); // 2

// some/every: tests conditions
const hasEven = numbers.some(x => x % 2 === 0); // true
const allPositive = numbers.every(x => x > 0); // true
```

#### Custom Higher-Order Functions
```javascript
// ✅ Creating reusable higher-order functions
const createValidator = (predicate, errorMessage) => (value) => ({
  isValid: predicate(value),
  error: predicate(value) ? null : errorMessage
});

// Factory functions for common validations
const isRequired = createValidator(
  value => value != null && value !== '',
  'This field is required'
);

const isEmail = createValidator(
  value => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value),
  'Please enter a valid email address'
);

const minLength = (min) => createValidator(
  value => value && value.length >= min,
  `Minimum length is ${min} characters`
);

// ✅ Function composition utilities
const pipe = (...functions) => (value) =>
  functions.reduce((acc, fn) => fn(acc), value);

const compose = (...functions) => (value) =>
  functions.reduceRight((acc, fn) => fn(acc), value);

// EdTech example: Student data processing pipeline
const processStudentData = pipe(
  validateStudentInput,
  normalizeStudentName,
  calculateGPA,
  assignStudentLevel,
  formatForDatabase
);

// ✅ Event handling with higher-order functions
const withLogging = (fn, actionName) => (...args) => {
  console.log(`Starting ${actionName}`, args);
  const result = fn(...args);
  console.log(`Completed ${actionName}`, result);
  return result;
};

const withErrorHandling = (fn, fallback) => (...args) => {
  try {
    return fn(...args);
  } catch (error) {
    console.error('Function error:', error);
    return fallback;
  }
};

// Usage
const safeCalculateGrade = withErrorHandling(
  calculateGrade,
  { score: 0, error: 'Calculation failed' }
);
```

### 4. Closures in Functional Context

Closures capture variables from their outer scope, enabling powerful patterns like partial application and data privacy.

#### Practical Closure Examples
```javascript
// ✅ Configuration through closures
const createGradeCalculator = (gradingScale) => {
  const scale = { ...gradingScale }; // Private copy
  
  return {
    calculateLetter: (numericGrade) => {
      for (const [letter, threshold] of Object.entries(scale)) {
        if (numericGrade >= threshold) return letter;
      }
      return 'F';
    },
    
    calculateGPA: (letterGrade) => scale[letterGrade] || 0,
    
    updateScale: (newScale) => createGradeCalculator(newScale)
  };
};

const standardCalculator = createGradeCalculator({
  'A': 90, 'B': 80, 'C': 70, 'D': 60
});

// ✅ Stateful functions without mutation
const createCounter = (initialValue = 0) => {
  let count = initialValue;
  
  return {
    increment: () => ++count,
    decrement: () => --count,
    getValue: () => count,
    reset: () => { count = initialValue; return count; }
  };
};

// ✅ EdTech example: Progress tracking
const createProgressTracker = (courseId) => {
  let progress = {
    lessonsCompleted: 0,
    totalLessons: 0,
    timeSpent: 0,
    lastAccessed: null
  };
  
  return {
    completeLesson: (lessonId, timeSpent) => {
      progress = {
        ...progress,
        lessonsCompleted: progress.lessonsCompleted + 1,
        timeSpent: progress.timeSpent + timeSpent,
        lastAccessed: new Date().toISOString()
      };
      return progress;
    },
    
    getProgress: () => ({ ...progress }), // Return copy
    
    getCompletionRate: () => 
      progress.totalLessons > 0 
        ? progress.lessonsCompleted / progress.totalLessons 
        : 0
  };
};
```

### 5. Currying and Partial Application

Breaking functions into single-argument functions or pre-filling some arguments.

#### Currying Fundamentals
```javascript
// ✅ Manual currying
const add = (a) => (b) => a + b;
const multiply = (a) => (b) => (c) => a * b * c;

// Usage
const add5 = add(5);
const result = add5(3); // 8

const multiplyBy2 = multiply(2);
const multiplyBy2And3 = multiplyBy2(3);
const result2 = multiplyBy2And3(4); // 24

// ✅ Automatic currying with utility
const curry = (fn) => {
  return function curried(...args) {
    if (args.length >= fn.length) {
      return fn.apply(this, args);
    } else {
      return function(...args2) {
        return curried.apply(this, args.concat(args2));
      };
    }
  };
};

// ✅ EdTech currying examples
const calculateScore = curry((totalQuestions, correctAnswers, studentAnswers) => {
  const correct = studentAnswers.filter((answer, index) => 
    answer === correctAnswers[index]
  ).length;
  return (correct / totalQuestions) * 100;
});

// Reusable scorers for different quiz types
const mathQuizScorer = calculateScore(20);
const scienceQuizScorer = calculateScore(15);

// Usage
const mathScore = mathQuizScorer(mathAnswers, studentMathAnswers);
const scienceScore = scienceQuizScorer(scienceAnswers, studentScienceAnswers);

// ✅ Partial application for filtering
const filterBy = curry((property, value, array) =>
  array.filter(item => item[property] === value)
);

const filterByGrade = filterBy('grade');
const filterBySubject = filterBy('subject');

const freshmen = filterByGrade('freshman', students);
const mathStudents = filterBySubject('mathematics', students);
```

### 6. Function Composition

Combining simple functions to create complex operations.

#### Composition Techniques
```javascript
// ✅ Basic composition utilities
const pipe = (...fns) => (value) => fns.reduce((acc, fn) => fn(acc), value);
const compose = (...fns) => (value) => fns.reduceRight((acc, fn) => fn(acc), value);

// ✅ EdTech data processing pipeline
const processExamResults = pipe(
  validateExamData,           // Check data integrity
  calculateRawScores,         // Sum correct answers
  normalizeScores,           // Convert to percentage
  applyGradingCurve,        // Apply statistical adjustments
  assignLetterGrades,       // Convert to letter grades
  generateStudentReports    // Create final reports
);

// Individual functions
const validateExamData = (examData) => {
  if (!examData.answers || !examData.studentId) {
    throw new Error('Invalid exam data');
  }
  return examData;
};

const calculateRawScores = (examData) => ({
  ...examData,
  rawScore: examData.answers.filter(Boolean).length
});

const normalizeScores = (examData) => ({
  ...examData,
  percentage: (examData.rawScore / examData.totalQuestions) * 100
});

// ✅ Async composition for API calls
const asyncPipe = (...fns) => (value) =>
  fns.reduce(async (acc, fn) => fn(await acc), Promise.resolve(value));

const processStudentEnrollment = asyncPipe(
  validateStudentData,
  saveToDatabase,
  sendWelcomeEmail,
  enrollInDefaultCourses,
  generateStudentDashboard
);

// ✅ Conditional composition
const conditionalPipe = (...steps) => (value) => {
  return steps.reduce((acc, step) => {
    if (typeof step === 'function') {
      return step(acc);
    }
    
    // Step is [condition, function]
    const [condition, fn] = step;
    return condition(acc) ? fn(acc) : acc;
  }, value);
};

// Usage with conditional steps
const processStudentGrade = conditionalPipe(
  calculateRawScore,
  [grade => grade.rawScore > 0, applyBonusPoints],
  normalizeToPercentage,
  [grade => grade.percentage >= 90, addHonorsRecognition],
  assignFinalGrade
);
```

### 7. Recursion

Solving problems by breaking them down into smaller, similar problems.

#### Recursion Fundamentals
```javascript
// ✅ Basic recursion examples
const factorial = (n) => 
  n <= 1 ? 1 : n * factorial(n - 1);

const fibonacci = (n) => 
  n <= 1 ? n : fibonacci(n - 1) + fibonacci(n - 2);

// ✅ Tail recursion optimization
const factorialTailRecursive = (n, acc = 1) =>
  n <= 1 ? acc : factorialTailRecursive(n - 1, n * acc);

const fibonacciTailRecursive = (n, a = 0, b = 1) =>
  n === 0 ? a : fibonacciTailRecursive(n - 1, b, a + b);

// ✅ EdTech recursion examples
const calculateNestedTopicProgress = (topic) => {
  if (!topic.subtopics || topic.subtopics.length === 0) {
    return topic.completed ? 1 : 0;
  }
  
  const subtopicProgress = topic.subtopics
    .map(calculateNestedTopicProgress)
    .reduce((sum, progress) => sum + progress, 0);
  
  return subtopicProgress / topic.subtopics.length;
};

// ✅ Tree traversal for course structure
const findLessonInCourse = (courseStructure, lessonId) => {
  if (courseStructure.id === lessonId) {
    return courseStructure;
  }
  
  if (courseStructure.children) {
    for (const child of courseStructure.children) {
      const found = findLessonInCourse(child, lessonId);
      if (found) return found;
    }
  }
  
  return null;
};

// ✅ Recursive data flattening
const flattenCourseStructure = (course, level = 0) => {
  const current = { ...course, level };
  
  if (!course.children || course.children.length === 0) {
    return [current];
  }
  
  const flattened = course.children
    .flatMap(child => flattenCourseStructure(child, level + 1));
  
  return [current, ...flattened];
};
```

## 🔄 Advanced Functional Concepts

### 1. Monads (Maybe, Either, IO)

Monads provide a way to wrap values and chain operations while handling edge cases.

#### Maybe Monad Implementation
```javascript
// ✅ Maybe monad for null/undefined safety
const Maybe = {
  of(value) {
    return value == null ? Nothing : Just(value);
  },
  
  nothing() {
    return Nothing;
  },
  
  isNothing(maybe) {
    return maybe === Nothing;
  }
};

const Nothing = {
  map: () => Nothing,
  flatMap: () => Nothing,
  filter: () => Nothing,
  fold: (_, nothing) => nothing(),
  toString: () => 'Nothing'
};

const Just = (value) => ({
  map: (fn) => Maybe.of(fn(value)),
  flatMap: (fn) => fn(value),
  filter: (pred) => pred(value) ? Just(value) : Nothing,
  fold: (just, _) => just(value),
  toString: () => `Just(${value})`
});

// ✅ EdTech usage examples
const getStudentById = (students, id) =>
  Maybe.of(students.find(student => student.id === id));

const getStudentGrade = (students, studentId, subject) =>
  getStudentById(students, studentId)
    .map(student => student.grades)
    .map(grades => grades[subject])
    .fold(
      grade => `Grade: ${grade}`,
      () => 'Student or grade not found'
    );

// ✅ Chaining operations safely
const processStudentData = (studentId) =>
  getStudentById(students, studentId)
    .filter(student => student.active)
    .map(student => ({ ...student, fullName: `${student.firstName} ${student.lastName}` }))
    .map(calculateStudentMetrics)
    .fold(
      processedStudent => ({ success: true, data: processedStudent }),
      () => ({ success: false, error: 'Student not found or inactive' })
    );
```

#### Either Monad for Error Handling
```javascript
// ✅ Either monad implementation
const Either = {
  left: (value) => Left(value),
  right: (value) => Right(value),
  of: (value) => Right(value)
};

const Left = (value) => ({
  map: () => Left(value),
  flatMap: () => Left(value),
  fold: (left, _) => left(value),
  isLeft: true,
  isRight: false
});

const Right = (value) => ({
  map: (fn) => Right(fn(value)),
  flatMap: (fn) => fn(value),
  fold: (_, right) => right(value),
  isLeft: false,
  isRight: true
});

// ✅ EdTech validation pipeline
const validateStudentRegistration = (data) => {
  return validateEmail(data.email)
    .flatMap(() => validateAge(data.age))
    .flatMap(() => validateGradeLevel(data.gradeLevel))
    .map(() => ({ ...data, validated: true }))
    .fold(
      error => ({ success: false, error }),
      validData => ({ success: true, data: validData })
    );
};

const validateEmail = (email) =>
  /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)
    ? Either.right(email)
    : Either.left('Invalid email format');

const validateAge = (age) =>
  age >= 13 && age <= 100
    ? Either.right(age)
    : Either.left('Age must be between 13 and 100');
```

### 2. Functors and Applicatives

Advanced patterns for working with wrapped values.

```javascript
// ✅ Functor laws compliance
const testFunctorLaws = (Functor, value) => {
  const id = x => x;
  const f = x => x * 2;
  const g = x => x + 1;
  
  // Identity law: F.of(a).map(id) === F.of(a)
  const identity = Functor.of(value).map(id).equals(Functor.of(value));
  
  // Composition law: F.of(a).map(compose(f, g)) === F.of(a).map(g).map(f)
  const composition = Functor.of(value)
    .map(x => f(g(x)))
    .equals(Functor.of(value).map(g).map(f));
  
  return { identity, composition };
};

// ✅ Applicative functor for multi-parameter functions
const liftA2 = (fn) => (fa) => (fb) =>
  fa.flatMap(a => fb.map(b => fn(a)(b)));

const validateStudentForm = (name, email, age) =>
  liftA2(curry((n) => (e) => (a) => ({ name: n, email: e, age: a })))
    (validateName(name))
    (validateEmail(email))
    (validateAge(age));
```

## 🚀 Real-World Applications

### 1. State Management

```javascript
// ✅ Functional state management
const createStore = (reducer, initialState) => {
  let state = initialState;
  const listeners = [];
  
  return {
    getState: () => state,
    
    dispatch: (action) => {
      const newState = reducer(state, action);
      if (newState !== state) {
        state = newState;
        listeners.forEach(listener => listener(state));
      }
    },
    
    subscribe: (listener) => {
      listeners.push(listener);
      return () => {
        const index = listeners.indexOf(listener);
        listeners.splice(index, 1);
      };
    }
  };
};

// ✅ EdTech reducer example
const courseReducer = (state = { courses: [], selectedCourse: null }, action) => {
  switch (action.type) {
    case 'ADD_COURSE':
      return {
        ...state,
        courses: [...state.courses, action.payload]
      };
      
    case 'UPDATE_PROGRESS':
      return {
        ...state,
        courses: state.courses.map(course =>
          course.id === action.courseId
            ? updateCourseProgress(course, action.lessonId, action.progress)
            : course
        )
      };
      
    case 'SELECT_COURSE':
      return {
        ...state,
        selectedCourse: action.courseId
      };
      
    default:
      return state;
  }
};
```

### 2. Async Operations

```javascript
// ✅ Functional async patterns
const createAsyncPipeline = (...operations) => async (initialValue) => {
  let result = initialValue;
  
  for (const operation of operations) {
    result = await operation(result);
  }
  
  return result;
};

// ✅ EdTech async example
const enrollStudentWorkflow = createAsyncPipeline(
  validateStudentData,
  checkEnrollmentEligibility,
  createStudentAccount,
  enrollInCourses,
  sendWelcomeEmail,
  logEnrollmentEvent
);

// Usage
const result = await enrollStudentWorkflow({
  name: 'John Doe',
  email: 'john@example.com',
  courses: ['math-101', 'science-201']
});
```

## 📚 Key Takeaways

### Core Principles Summary
1. **Pure Functions**: Predictable, testable, side-effect free
2. **Immutability**: Create new data instead of modifying existing
3. **Higher-Order Functions**: Functions as first-class citizens
4. **Composition**: Build complex operations from simple functions
5. **Currying**: Create specialized functions from general ones
6. **Monads**: Handle edge cases and errors functionally

### EdTech Applications
- **Student Data Processing**: Pure functions for grade calculations
- **Progress Tracking**: Immutable state updates
- **Content Management**: Functional pipelines for question selection
- **Analytics**: Functional data transformations
- **Error Handling**: Monadic patterns for robust applications

### Career Benefits
- **Debugging**: Easier to reason about pure functions
- **Testing**: Pure functions are trivial to test
- **Scalability**: Immutable data prevents many concurrency issues
- **Maintainability**: Functional code is more predictable
- **Interview Success**: FP concepts are increasingly common in technical interviews

---

**← Previous:** [Best Practices](./best-practices.md)  
**→ Next:** [Libraries & Ecosystem](./libraries-ecosystem.md)  
**↑ Parent:** [Functional Programming JavaScript](./README.md)

---

*Fundamentals & Concepts | Functional Programming in JavaScript | Core principles and practical applications*