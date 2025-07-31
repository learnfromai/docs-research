# Best Practices - Functional Programming in JavaScript

## 🎯 Overview

This document outlines industry-standard best practices for functional programming in JavaScript, covering code organization, performance optimization, testing strategies, and team collaboration patterns. These practices are derived from successful implementations in production environments and align with remote work standards in AU, UK, and US markets.

## 🏗️ Code Organization & Architecture

### 1. Pure Functions First

#### ✅ Best Practices
```javascript
// ✅ Pure function - predictable and testable
const calculateTax = (amount, rate, exemptions = 0) => 
  (amount - exemptions) * rate;

// ✅ Pure function with explicit dependencies
const formatStudentReport = (student, gradeCalculator, formatter) =>
  formatter(gradeCalculator(student.scores));

// ✅ Pure async function
const fetchUserData = async (userId, apiClient) => {
  const response = await apiClient.get(`/users/${userId}`);
  return response.data;
};
```

#### ❌ Common Mistakes
```javascript
// ❌ Impure - depends on external state
let taxRate = 0.08;
const calculateTax = (amount) => amount * taxRate;

// ❌ Impure - modifies input parameter
const processUser = (user) => {
  user.lastLogin = new Date();
  return user;
};

// ❌ Impure - side effects in calculation
const calculateGrade = (scores) => {
  console.log('Calculating grade...'); // side effect
  return scores.reduce((sum, score) => sum + score, 0) / scores.length;
};
```

### 2. Immutability Patterns

#### ✅ Recommended Approaches
```javascript
// ✅ Immutable array operations
const addStudent = (students, newStudent) => [...students, newStudent];
const updateStudent = (students, id, updates) =>
  students.map(student => 
    student.id === id ? { ...student, ...updates } : student
  );
const removeStudent = (students, id) =>
  students.filter(student => student.id !== id);

// ✅ Immutable object updates with Ramda
import { assocPath, over, lensProp } from 'ramda';

const updateNestedProperty = (obj, path, value) =>
  assocPath(path, value, obj);

const updateStudentGrade = (student, subject, grade) =>
  assocPath(['grades', subject], grade, student);

// ✅ Immutable deep updates
import { produce } from 'immer';

const updateCourseStructure = (course, updates) =>
  produce(course, draft => {
    draft.modules.forEach(module => {
      if (updates[module.id]) {
        Object.assign(module, updates[module.id]);
      }
    });
  });
```

#### ❌ Mutation Antipatterns
```javascript
// ❌ Direct mutation
const addScore = (student, score) => {
  student.scores.push(score); // mutates original
  return student;
};

// ❌ Shallow copy trap
const updateStudent = (student, updates) => {
  const updated = { ...student }; // shallow copy
  updated.grades.math = 95; // still mutates nested object
  return updated;
};
```

### 3. Function Composition Strategies

#### ✅ Composable Design
```javascript
import { pipe, map, filter, sortBy, prop } from 'ramda';

// ✅ Small, focused functions
const isActiveStudent = student => student.status === 'active';
const hasMinimumGrade = minGrade => student => student.gpa >= minGrade;
const byGpaDescending = sortBy(prop('gpa')).reverse();
const toDisplayFormat = map(student => ({
  name: `${student.firstName} ${student.lastName}`,
  gpa: student.gpa.toFixed(2),
  status: student.status
}));

// ✅ Composed pipeline
const getTopStudents = pipe(
  filter(isActiveStudent),
  filter(hasMinimumGrade(3.5)),
  byGpaDescending,
  take(10),
  toDisplayFormat
);

// ✅ Reusable compositions
const createDataProcessor = (filters, transforms, sorters) =>
  pipe(...filters, ...transforms, ...sorters);

const academicDataProcessor = createDataProcessor(
  [filter(isActiveStudent), filter(hasMinimumGrade(2.0))],
  [map(addGpaCalculation), map(addRanking)],
  [sortBy(prop('ranking'))]
);
```

#### ❌ Composition Antipatterns
```javascript
// ❌ Monolithic function
const processStudentData = (students) => {
  const result = [];
  for (const student of students) {
    if (student.status === 'active' && student.gpa >= 3.0) {
      const processed = {
        name: `${student.firstName} ${student.lastName}`,
        gpa: student.gpa.toFixed(2),
        rank: calculateRank(student, students),
        courses: student.courses.map(c => c.name).join(', ')
      };
      result.push(processed);
    }
  }
  return result.sort((a, b) => b.gpa - a.gpa);
};

// ❌ Nested function calls (hard to read)
const result = sortByGpa(
  formatForDisplay(
    addRanking(
      filterByGpa(
        filterActiveStudents(students),
        3.0
      )
    )
  )
);
```

## 📊 Performance Best Practices

### 1. Optimization Strategies

#### ✅ Performance-Conscious FP
```javascript
// ✅ Memoization for expensive calculations
import { memoizeWith, identity } from 'ramda';

const expensiveCalculation = (data) => {
  // Complex computation
  return data.reduce((acc, item) => acc + heavyOperation(item), 0);
};

const memoizedCalculation = memoizeWith(identity, expensiveCalculation);

// ✅ Lazy evaluation for large datasets
function* lazyFilter(predicate, iterable) {
  for (const item of iterable) {
    if (predicate(item)) {
      yield item;
    }
  }
}

function* lazyMap(transformer, iterable) {
  for (const item of iterable) {
    yield transformer(item);
  }
}

// Usage: processes only what's needed
const processLargeDataset = (data) => {
  const pipeline = lazyMap(
    transform,
    lazyFilter(isValid, data)
  );
  
  // Only process first 100 items
  return Array.from(take(100, pipeline));
};

// ✅ Transducers for efficient processing
import { transduce, map, filter, take } from 'ramda';

const processWithTransducers = transduce(
  compose(
    filter(isValid),
    map(transform),
    take(100)
  ),
  (acc, item) => [...acc, item],
  [],
  largeDataset
);
```

#### ❌ Performance Antipatterns
```javascript
// ❌ Inefficient chaining
const inefficientProcessing = (data) =>
  data
    .filter(item => item.active) // Full iteration 1
    .map(item => ({ ...item, processed: true })) // Full iteration 2
    .filter(item => item.score > 80) // Full iteration 3
    .map(item => item.name) // Full iteration 4
    .sort(); // Full iteration 5

// ❌ Unnecessary immutable operations
const inefficientUpdate = (largeArray, updates) =>
  updates.reduce((acc, update) =>
    acc.map(item => // Creates new array for each update
      item.id === update.id ? { ...item, ...update } : item
    ), largeArray
  );
```

### 2. Memory Management

#### ✅ Memory-Efficient Patterns
```javascript
// ✅ Streaming for large datasets
import { Readable, Transform } from 'stream';

const createStudentProcessor = () =>
  new Transform({
    objectMode: true,
    transform(student, encoding, callback) {
      if (student.active && student.gpa >= 3.0) {
        callback(null, {
          id: student.id,
          name: `${student.firstName} ${student.lastName}`,
          gpa: student.gpa
        });
      } else {
        callback();
      }
    }
  });

// ✅ Garbage collection friendly
const processInBatches = async (data, batchSize = 1000) => {
  const results = [];
  
  for (let i = 0; i < data.length; i += batchSize) {
    const batch = data.slice(i, i + batchSize);
    const processedBatch = batch.map(processItem);
    results.push(...processedBatch);
    
    // Allow GC between batches
    if (i % (batchSize * 10) === 0) {
      await new Promise(resolve => setImmediate(resolve));
    }
  }
  
  return results;
};
```

## 🧪 Testing Best Practices

### 1. Property-Based Testing

#### ✅ Comprehensive Property Tests
```javascript
import fc from 'fast-check';

// ✅ Test mathematical properties
describe('GPA Calculator', () => {
  test('should always return value between 0 and 4', () => {
    fc.assert(fc.property(
      fc.array(fc.float(0, 4), { minLength: 1, maxLength: 20 }),
      (grades) => {
        const gpa = calculateGPA(grades);
        return gpa >= 0 && gpa <= 4;
      }
    ));
  });

  test('should be commutative', () => {
    fc.assert(fc.property(
      fc.array(fc.float(0, 4), { minLength: 2 }),
      (grades) => {
        const gpa1 = calculateGPA(grades);
        const gpa2 = calculateGPA([...grades].reverse());
        return Math.abs(gpa1 - gpa2) < 0.001;
      }
    ));
  });
});

// ✅ Test data transformation properties
describe('Student Data Processing', () => {
  test('should preserve student count when filtering by valid criteria', () => {
    fc.assert(fc.property(
      fc.array(fc.record({
        id: fc.integer(),
        active: fc.boolean(),
        gpa: fc.float(0, 4)
      })),
      (students) => {
        const activeStudents = students.filter(s => s.active);
        const result = processStudents(students);
        return result.length <= activeStudents.length;
      }
    ));
  });
});
```

### 2. Pure Function Testing

#### ✅ Focused Unit Tests
```javascript
// ✅ Test pure functions in isolation
describe('Pure Function Tests', () => {
  test('calculateLetterGrade should map numeric grades correctly', () => {
    expect(calculateLetterGrade(95)).toBe('A');
    expect(calculateLetterGrade(85)).toBe('B');
    expect(calculateLetterGrade(75)).toBe('C');
    expect(calculateLetterGrade(65)).toBe('D');
    expect(calculateLetterGrade(55)).toBe('F');
  });

  test('filterStudentsByGPA should work with edge cases', () => {
    const students = [
      { id: 1, gpa: 3.5 },
      { id: 2, gpa: 3.0 },
      { id: 3, gpa: 2.5 }
    ];

    expect(filterStudentsByGPA(3.0)(students)).toHaveLength(2);
    expect(filterStudentsByGPA(4.0)(students)).toHaveLength(0);
    expect(filterStudentsByGPA(0)(students)).toHaveLength(3);
  });
});

// ✅ Test compositions
describe('Function Composition Tests', () => {
  test('student processing pipeline should work correctly', () => {
    const input = [
      { id: 1, firstName: 'John', lastName: 'Doe', gpa: 3.8, active: true },
      { id: 2, firstName: 'Jane', lastName: 'Smith', gpa: 2.9, active: false }
    ];

    const result = processTopStudents(input);
    
    expect(result).toHaveLength(1);
    expect(result[0].name).toBe('John Doe');
    expect(result[0].gpa).toBe('3.80');
  });
});
```

### 3. Integration Testing

#### ✅ State Management Testing
```javascript
// ✅ Test immutable state updates
describe('Student Store', () => {
  test('should handle student updates immutably', () => {
    const initialState = fromJS({
      students: { '1': { id: '1', name: 'John', gpa: 3.0 } }
    });

    const updatedState = updateStudentGPA(initialState, '1', 3.5);
    
    // Original state unchanged
    expect(initialState.getIn(['students', '1', 'gpa'])).toBe(3.0);
    
    // New state has update
    expect(updatedState.getIn(['students', '1', 'gpa'])).toBe(3.5);
    
    // States are different objects
    expect(initialState).not.toBe(updatedState);
  });
});
```

## 🔒 Error Handling Best Practices

### 1. Monadic Error Handling

#### ✅ Safe Error Propagation
```javascript
// ✅ Either monad for error handling
const Either = {
  of: (value) => Right(value),
  left: (error) => Left(error),
  right: (value) => Right(value)
};

const Left = (value) => ({
  map: () => Left(value),
  flatMap: () => Left(value),
  fold: (left, right) => left(value),
  isLeft: true,
  isRight: false
});

const Right = (value) => ({
  map: (fn) => Right(fn(value)),
  flatMap: (fn) => fn(value),
  fold: (left, right) => right(value),
  isLeft: false,
  isRight: true
});

// ✅ Safe data processing pipeline
const safeProcessStudent = (rawData) =>
  Either.of(rawData)
    .flatMap(validateStudentData)
    .flatMap(enrichWithGrades)
    .flatMap(calculateRanking)
    .fold(
      error => ({ success: false, error: error.message }),
      data => ({ success: true, data })
    );

// ✅ Validation functions
const validateStudentData = (data) => {
  const errors = [];
  if (!data.id) errors.push('Missing student ID');
  if (!data.firstName) errors.push('Missing first name');
  if (!Array.isArray(data.grades)) errors.push('Invalid grades format');
  
  return errors.length > 0 
    ? Left(new Error(errors.join(', ')))
    : Right(data);
};
```

### 2. Async Error Handling

#### ✅ Functional Async Patterns
```javascript
// ✅ Safe async composition
const safeAsyncPipe = (...fns) => async (input) =>
  fns.reduce(async (acc, fn) => {
    try {
      const value = await acc;
      return await fn(value);
    } catch (error) {
      throw error;
    }
  }, Promise.resolve(input));

// ✅ Task monad for async operations
const Task = (computation) => ({
  map: (fn) => Task(async () => fn(await computation())),
  flatMap: (fn) => Task(async () => {
    const value = await computation();
    return await fn(value).run();
  }),
  run: computation,
  catch: (handler) => Task(async () => {
    try {
      return await computation();
    } catch (error) {
      return await handler(error);
    }
  })
});

// Usage
const fetchAndProcessStudent = (id) =>
  Task(() => fetchStudent(id))
    .flatMap(student => Task(() => enrichStudentData(student)))
    .flatMap(student => Task(() => calculateMetrics(student)))
    .catch(error => Task(() => getDefaultStudent(id)));
```

## 👥 Team Collaboration Best Practices

### 1. Code Review Guidelines

#### ✅ FP Code Review Checklist
```markdown
## Functional Programming Code Review Checklist

### Purity & Side Effects
- [ ] Are all functions pure where possible?
- [ ] Are side effects clearly isolated and documented?
- [ ] Do functions have single responsibilities?

### Immutability
- [ ] Are data structures treated as immutable?
- [ ] Are new objects/arrays created instead of mutations?
- [ ] Is deep immutability maintained in nested structures?

### Composition
- [ ] Are complex operations broken into composable functions?
- [ ] Is the data flow clear and logical?
- [ ] Are function names descriptive and intention-revealing?

### Error Handling
- [ ] Are errors handled functionally (Maybe/Either patterns)?
- [ ] Is error propagation explicit and safe?
- [ ] Are edge cases properly addressed?

### Performance
- [ ] Are expensive operations memoized where appropriate?
- [ ] Is lazy evaluation used for large datasets?
- [ ] Are there any unnecessary iterations or transformations?

### Testing
- [ ] Are pure functions thoroughly unit tested?
- [ ] Are property-based tests used where appropriate?
- [ ] Is error handling tested comprehensively?
```

### 2. Documentation Standards

#### ✅ Functional Code Documentation
```javascript
/**
 * Calculates weighted GPA for a student based on course credits and grades
 * 
 * @pure
 * @param {Array<{course: string, credits: number, grade: number}>} courses
 * @returns {number} Weighted GPA (0.0 - 4.0)
 * 
 * @example
 * const courses = [
 *   { course: 'Math', credits: 3, grade: 3.7 },
 *   { course: 'Physics', credits: 4, grade: 3.3 }
 * ];
 * calculateWeightedGPA(courses); // Returns 3.46
 * 
 * @since 1.2.0
 */
const calculateWeightedGPA = (courses) => {
  const totalCredits = courses.reduce((sum, c) => sum + c.credits, 0);
  const weightedSum = courses.reduce((sum, c) => sum + (c.grade * c.credits), 0);
  return totalCredits > 0 ? weightedSum / totalCredits : 0;
};

/**
 * Higher-order function that creates a grade filter based on minimum GPA
 * 
 * @pure
 * @curried
 * @param {number} minGPA - Minimum GPA threshold (0.0 - 4.0)
 * @returns {Function} Filter function for student arrays
 * 
 * @example
 * const honorsFilter = createGPAFilter(3.5);
 * const honorsStudents = students.filter(honorsFilter);
 * 
 * @since 1.0.0
 */
const createGPAFilter = curry((minGPA, student) => student.gpa >= minGPA);
```

### 3. Architecture Documentation

#### ✅ FP Architecture ADRs
```markdown
# ADR-001: Functional Programming Adoption

## Status
Accepted

## Context
Our edtech platform requires predictable, testable code for handling complex 
student data processing and real-time analytics.

## Decision
Adopt functional programming patterns throughout the application with focus on:
- Pure functions for all business logic
- Immutable state management with Immutable.js
- Ramda for utility functions and composition
- Maybe/Either monads for error handling

## Consequences

### Positive
- Improved testability and code quality
- Better handling of complex data transformations
- Reduced bugs through immutability
- Enhanced team productivity with predictable code

### Negative
- Learning curve for team members new to FP
- Potential performance overhead in some scenarios
- Additional library dependencies

## Implementation Plan
1. Team training on FP concepts (2 weeks)
2. Gradual migration starting with new features
3. Establish FP coding standards and review process
4. Performance monitoring and optimization
```

## 🚀 EdTech-Specific Best Practices

### 1. Student Data Processing

#### ✅ Safe Student Information Handling
```javascript
// ✅ Privacy-preserving data processing
const sanitizeStudentData = pipe(
  pick(['id', 'firstName', 'lastName', 'gradeLevel']), // Only necessary fields
  over(lensProp('firstName'), (name) => name.charAt(0) + '.'), // Anonymize
  assoc('processedAt', new Date().toISOString())
);

// ✅ GDPR/COPPA compliant data handling
const createStudentDataProcessor = (permissions) => {
  const allowedFields = permissions.allowedFields || ['id', 'gradeLevel'];
  
  return pipe(
    pick(allowedFields),
    when(
      () => permissions.anonymize,
      over(lensProp('name'), anonymizeName)
    ),
    assoc('dataRetentionExpiry', calculateRetentionDate(permissions.retentionPeriod))
  );
};
```

### 2. Learning Analytics

#### ✅ Performance Metrics Processing
```javascript
// ✅ Real-time learning analytics
const processLearningSession = pipe(
  validateSessionData,
  calculateEngagementMetrics,
  updateProgressTracking,
  generateRecommendations
);

const calculateEngagementMetrics = (session) => ({
  ...session,
  engagementScore: calculateEngagement(
    session.timeSpent,
    session.interactions,
    session.completionRate
  ),
  difficultyProgression: analyzeDifficultyTrend(session.attempts),
  knowledgeGaps: identifyWeakAreas(session.responses)
});

// ✅ Adaptive difficulty adjustment
const adaptiveDifficulty = curry((targetAccuracy, performanceHistory, currentLevel) => {
  const recentPerformance = takeLast(10, performanceHistory);
  const avgAccuracy = mean(map(prop('accuracy'), recentPerformance));
  
  return cond([
    [() => avgAccuracy > targetAccuracy + 0.1, () => Math.min(currentLevel + 0.1, 1.0)],
    [() => avgAccuracy < targetAccuracy - 0.1, () => Math.max(currentLevel - 0.1, 0.1)],
    [T, () => currentLevel]
  ])();
});
```

### 3. Content Management

#### ✅ Question Bank Processing
```javascript
// ✅ Functional question selection algorithm
const selectExamQuestions = curry((criteria, questionBank) =>
  pipe(
    filter(matchesCriteria(criteria)),
    groupBy(prop('topic')),
    mapObjIndexed((questions, topic) =>
      pipe(
        sortBy(prop('difficulty')),
        distributeByDifficulty(criteria.difficultyDistribution),
        shuffle,
        take(criteria.questionsPerTopic)
      )(questions)
    ),
    values,
    flatten,
    shuffle
  )(questionBank)
);

// ✅ Content versioning with immutability
const updateQuestionContent = curry((questionId, updates, questionBank) =>
  map(
    when(
      propEq('id', questionId),
      pipe(
        assoc('version', increment(prop('version'))),
        merge(updates),
        assoc('updatedAt', new Date()),
        over(lensProp('changeHistory'), append({
          timestamp: new Date(),
          changes: updates,
          editor: getCurrentUser()
        }))
      )
    ),
    questionBank
  )
);
```

## 📏 Code Quality Metrics

### 1. Functional Code Metrics

#### ✅ Quality Measurement
```javascript
// Automated FP compliance checking
const fpCompliance = {
  purityScore: (functions) => {
    const pureFunctions = functions.filter(isPure);
    return (pureFunctions.length / functions.length) * 100;
  },

  immutabilityScore: (codebase) => {
    const mutations = findMutations(codebase);
    const totalOperations = findAllOperations(codebase);
    return ((totalOperations - mutations) / totalOperations) * 100;
  },

  compositionScore: (functions) => {
    const composedFunctions = functions.filter(isComposed);
    return (composedFunctions.length / functions.length) * 100;
  }
};

// Target metrics for FP adoption
const qualityTargets = {
  purityScore: 85, // 85% of functions should be pure
  immutabilityScore: 95, // 95% immutable operations
  compositionScore: 60, // 60% of complex functions use composition
  testCoverage: 90, // 90% test coverage for pure functions
  performanceRegression: 5 // <5% performance impact
};
```

### 2. Monitoring & Alerting

#### ✅ Production Monitoring
```javascript
// Performance monitoring for FP code
const withMetrics = (name, fn) => (...args) => {
  const start = performance.now();
  const startMemory = process.memoryUsage().heapUsed;
  
  try {
    const result = fn(...args);
    const duration = performance.now() - start;
    const memoryDelta = process.memoryUsage().heapUsed - startMemory;
    
    metrics.record(`${name}.duration`, duration);
    metrics.record(`${name}.memory`, memoryDelta);
    metrics.increment(`${name}.success`);
    
    return result;
  } catch (error) {
    metrics.increment(`${name}.error`);
    throw error;
  }
};

// Usage
const monitoredProcessStudents = withMetrics(
  'processStudents',
  processStudents
);
```

## 🎯 Success Criteria & KPIs

### Development Quality KPIs
- **Code Quality**: 85%+ pure functions, 95%+ immutable operations
- **Bug Reduction**: 60% fewer production bugs in FP modules
- **Test Coverage**: 90%+ coverage with property-based tests
- **Performance**: <5% overhead from FP patterns
- **Developer Productivity**: 25% faster feature development after ramp-up

### Business Impact KPIs
- **User Experience**: 40% fewer error states in UI
- **Data Integrity**: 99.9% accuracy in student data processing
- **Scalability**: Handle 10x user growth without architectural changes
- **Maintenance**: 50% reduction in time spent debugging
- **Team Velocity**: 30% improvement in story completion rate

---

**← Previous:** [Implementation Guide](./implementation-guide.md)  
**→ Next:** [Fundamentals & Concepts](./fundamentals-concepts.md)  
**↑ Parent:** [Functional Programming JavaScript](./README.md)

---

*Best Practices Guide | Functional Programming in JavaScript | Industry standards and proven patterns*