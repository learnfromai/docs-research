# Node.js Interview Questions & Answers

## Basic Node.js Concepts

### 1. What is Node.js and what are its key features?

**Answer:**
Node.js is a JavaScript runtime built on Chrome's V8 JavaScript engine that allows you to run JavaScript on the server side. It uses an event-driven, non-blocking I/O model.

**Key Features:**

```javascript
// 1. Event-Driven Architecture
const EventEmitter = require('events');

class MyEmitter extends EventEmitter {}
const myEmitter = new MyEmitter();

myEmitter.on('event', (data) => {
  console.log('Event received:', data);
});

myEmitter.emit('event', 'Hello World!');

// 2. Non-blocking I/O
const fs = require('fs');

// Blocking (synchronous) - NOT recommended
// const data = fs.readFileSync('large-file.txt', 'utf8');
// console.log(data);

// Non-blocking (asynchronous) - Recommended
fs.readFile('large-file.txt', 'utf8', (err, data) => {
  if (err) {
    console.error('Error reading file:', err);
    return;
  }
  console.log('File content:', data);
});

console.log('This executes immediately, not waiting for file read');

// 3. Single-threaded Event Loop
// Node.js runs on a single thread but uses libuv for I/O operations
process.nextTick(() => {
  console.log('Next tick callback');
});

setImmediate(() => {
  console.log('Set immediate callback');
});

setTimeout(() => {
  console.log('Timeout callback');
}, 0);

console.log('Synchronous operation');

// Output order:
// Synchronous operation
// Next tick callback
// Timeout callback
// Set immediate callback

// 4. Built-in Modules
const path = require('path');
const url = require('url');
const crypto = require('crypto');
const util = require('util');

// Path manipulation
const fullPath = path.join(__dirname, 'files', 'data.txt');
const extension = path.extname('file.txt'); // .txt

// URL parsing
const parsedUrl = url.parse('https://example.com/path?query=value');

// Crypto operations
const hash = crypto.createHash('sha256').update('data').digest('hex');

// 5. Package Management with npm
// package.json example
{
  "name": "my-node-app",
  "version": "1.0.0",
  "description": "A Node.js application",
  "main": "index.js",
  "scripts": {
    "start": "node index.js",
    "dev": "nodemon index.js",
    "test": "jest"
  },
  "dependencies": {
    "express": "^4.18.0",
    "lodash": "^4.17.21"
  },
  "devDependencies": {
    "nodemon": "^2.0.15",
    "jest": "^28.1.0"
  }
}

// 6. Cross-platform Compatibility
const os = require('os');

console.log('Platform:', os.platform()); // win32, darwin, linux
console.log('Architecture:', os.arch()); // x64, arm64
console.log('CPU cores:', os.cpus().length);
console.log('Free memory:', os.freemem());
console.log('Total memory:', os.totalmem());

// 7. Streams for Efficient Data Processing
const { Readable, Writable, Transform } = require('stream');

// Create a readable stream
const readableStream = new Readable({
  read() {
    this.push('Hello ');
    this.push('World!');
    this.push(null); // End stream
  }
});

// Create a transform stream (uppercase)
const upperCaseTransform = new Transform({
  transform(chunk, encoding, callback) {
    this.push(chunk.toString().toUpperCase());
    callback();
  }
});

// Create a writable stream
const writableStream = new Writable({
  write(chunk, encoding, callback) {
    console.log('Received:', chunk.toString());
    callback();
  }
});

// Pipe streams together
readableStream
  .pipe(upperCaseTransform)
  .pipe(writableStream);
```

**Advantages:**

- **Fast execution** (V8 engine)
- **Scalable** (handles many concurrent connections)
- **Large ecosystem** (npm packages)
- **JavaScript everywhere** (same language for frontend/backend)
- **Active community** and enterprise support

**Common Use Cases:**

- **Web APIs** and RESTful services
- **Real-time applications** (chat, gaming)
- **Microservices** architecture
- **Build tools** and CLI applications
- **IoT applications**
- **Server-side rendering** (SSR)

### 2. Explain the Node.js Event Loop and how it works

**Answer:**
The Event Loop is the heart of Node.js's non-blocking I/O model. It allows Node.js to perform asynchronous operations by delegating operations to the system when possible.

```javascript
// EVENT LOOP PHASES

// 1. Timer Phase - executes setTimeout() and setInterval() callbacks
console.log('=== TIMER PHASE ===');

setTimeout(() => {
  console.log('Timer 1 (0ms)');
}, 0);

setTimeout(() => {
  console.log('Timer 2 (1ms)');
}, 1);

// 2. Pending Callbacks Phase - executes I/O callbacks deferred to the next loop iteration
console.log('=== PENDING CALLBACKS PHASE ===');

// 3. Idle, Prepare Phase - only used internally
// (Not directly accessible in application code)

// 4. Poll Phase - fetches new I/O events; executes I/O related callbacks
console.log('=== POLL PHASE ===');

const fs = require('fs');

fs.readFile(__filename, (err, data) => {
  console.log('File read callback (Poll phase)');
});

// 5. Check Phase - executes setImmediate() callbacks
console.log('=== CHECK PHASE ===');

setImmediate(() => {
  console.log('Set immediate 1');
});

setImmediate(() => {
  console.log('Set immediate 2');
});

// 6. Close Callbacks Phase - executes close event callbacks
console.log('=== CLOSE CALLBACKS PHASE ===');

const net = require('net');
const server = net.createServer();

server.on('close', () => {
  console.log('Server closed');
});

// MICROTASKS (executed between phases)
console.log('=== MICROTASKS ===');

// process.nextTick() has highest priority
process.nextTick(() => {
  console.log('Next tick 1');
});

process.nextTick(() => {
  console.log('Next tick 2');
});

// Promise callbacks are also microtasks
Promise.resolve().then(() => {
  console.log('Promise 1');
});

Promise.resolve().then(() => {
  console.log('Promise 2');
});

console.log('Synchronous code');

/* Expected output order:
Synchronous code
Next tick 1
Next tick 2
Promise 1
Promise 2
Timer 1 (0ms)
Timer 2 (1ms)
Set immediate 1
Set immediate 2
File read callback (Poll phase)
*/

// DETAILED EXAMPLE: Understanding Execution Order

function demonstrateEventLoop() {
  console.log('Start');
  
  // Microtasks (highest priority)
  process.nextTick(() => console.log('1: process.nextTick'));
  Promise.resolve().then(() => console.log('2: Promise.resolve'));
  
  // Timers
  setTimeout(() => console.log('3: setTimeout'), 0);
  
  // Check phase
  setImmediate(() => console.log('4: setImmediate'));
  
  // I/O operations
  fs.readFile(__filename, () => {
    console.log('5: fs.readFile');
    
    // Inside I/O callback
    setTimeout(() => console.log('6: setTimeout inside I/O'), 0);
    setImmediate(() => console.log('7: setImmediate inside I/O'));
  });
  
  console.log('End');
}

demonstrateEventLoop();

// BLOCKING VS NON-BLOCKING OPERATIONS

// Blocking operation (bad practice)
function blockingExample() {
  console.log('Before blocking operation');
  
  // This blocks the event loop
  const start = Date.now();
  while (Date.now() - start < 1000) {
    // Busy wait for 1 second
  }
  
  console.log('After blocking operation');
}

// Non-blocking operation (good practice)
function nonBlockingExample() {
  console.log('Before non-blocking operation');
  
  // This doesn't block the event loop
  setTimeout(() => {
    console.log('After non-blocking operation');
  }, 1000);
  
  console.log('This executes immediately');
}

// EVENT LOOP MONITORING

// Monitor event loop lag
function monitorEventLoop() {
  const start = process.hrtime();
  
  setImmediate(() => {
    const delta = process.hrtime(start);
    const nanosec = delta[0] * 1e9 + delta[1];
    const millisec = nanosec / 1e6;
    
    console.log(`Event loop lag: ${millisec.toFixed(2)}ms`);
  });
}

// Run monitoring every second
setInterval(monitorEventLoop, 1000);

// WORKER THREADS FOR CPU-INTENSIVE TASKS

const { Worker, isMainThread, parentPort } = require('worker_threads');

if (isMainThread) {
  // Main thread
  function runCPUIntensiveTask() {
    return new Promise((resolve, reject) => {
      const worker = new Worker(__filename);
      
      worker.postMessage(1000000);
      
      worker.on('message', (result) => {
        resolve(result);
      });
      
      worker.on('error', reject);
      worker.on('exit', (code) => {
        if (code !== 0) {
          reject(new Error(`Worker stopped with exit code ${code}`));
        }
      });
    });
  }
  
  // This doesn't block the main event loop
  runCPUIntensiveTask().then((result) => {
    console.log('CPU intensive task result:', result);
  });
  
} else {
  // Worker thread
  parentPort.on('message', (n) => {
    // CPU intensive calculation
    let result = 0;
    for (let i = 0; i < n; i++) {
      result += Math.sqrt(i);
    }
    parentPort.postMessage(result);
  });
}

// CLUSTER MODULE FOR SCALING

const cluster = require('cluster');
const numCPUs = require('os').cpus().length;

if (cluster.isMaster) {
  console.log(`Master ${process.pid} is running`);
  
  // Fork workers
  for (let i = 0; i < numCPUs; i++) {
    cluster.fork();
  }
  
  cluster.on('exit', (worker, code, signal) => {
    console.log(`Worker ${worker.process.pid} died`);
    cluster.fork(); // Restart worker
  });
  
} else {
  // Worker process
  const http = require('http');
  
  const server = http.createServer((req, res) => {
    res.writeHead(200);
    res.end(`Hello from worker ${process.pid}`);
  });
  
  server.listen(3000);
  console.log(`Worker ${process.pid} started`);
}

// CUSTOM EVENT EMITTER EXAMPLE

class TaskQueue extends EventEmitter {
  constructor() {
    super();
    this.tasks = [];
    this.processing = false;
  }
  
  addTask(task) {
    this.tasks.push(task);
    this.emit('taskAdded', task);
    this.processNext();
  }
  
  async processNext() {
    if (this.processing || this.tasks.length === 0) return;
    
    this.processing = true;
    const task = this.tasks.shift();
    
    this.emit('taskStarted', task);
    
    try {
      const result = await task();
      this.emit('taskCompleted', result);
    } catch (error) {
      this.emit('taskFailed', error);
    }
    
    this.processing = false;
    
    // Process next task
    if (this.tasks.length > 0) {
      setImmediate(() => this.processNext());
    }
  }
}

const queue = new TaskQueue();

queue.on('taskAdded', (task) => {
  console.log('Task added to queue');
});

queue.on('taskStarted', (task) => {
  console.log('Task started');
});

queue.on('taskCompleted', (result) => {
  console.log('Task completed:', result);
});

queue.on('taskFailed', (error) => {
  console.error('Task failed:', error);
});

// Add tasks
queue.addTask(async () => {
  await new Promise(resolve => setTimeout(resolve, 100));
  return 'Task 1 result';
});

queue.addTask(async () => {
  await new Promise(resolve => setTimeout(resolve, 200));
  return 'Task 2 result';
});
```

**Key Points:**

- **Single-threaded** but uses **libuv** for I/O operations
- **Six phases** in each event loop iteration
- **Microtasks** (nextTick, Promises) have highest priority
- **Non-blocking I/O** keeps the event loop responsive
- **Worker threads** for CPU-intensive tasks
- **Cluster module** for utilizing multiple CPU cores

### 3. What is Express.js and how do you create a RESTful API?

**Answer:**
Express.js is a minimal and flexible Node.js web application framework that provides a robust set of features for web and mobile applications.

```javascript
// BASIC EXPRESS SETUP

const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');

const app = express();
const PORT = process.env.PORT || 3000;

// MIDDLEWARE SETUP

// Security middleware
app.use(helmet());

// CORS configuration
app.use(cors({
  origin: process.env.ALLOWED_ORIGINS?.split(',') || 'http://localhost:3000',
  credentials: true
}));

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // Limit each IP to 100 requests per windowMs
  message: 'Too many requests from this IP'
});
app.use(limiter);

// Body parsing middleware
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Logging middleware
app.use((req, res, next) => {
  console.log(`${new Date().toISOString()} - ${req.method} ${req.path}`);
  next();
});

// MOCK DATABASE (in real apps, use MongoDB, PostgreSQL, etc.)
let users = [
  { id: 1, name: 'John Doe', email: 'john@example.com', age: 30 },
  { id: 2, name: 'Jane Smith', email: 'jane@example.com', age: 25 },
  { id: 3, name: 'Bob Johnson', email: 'bob@example.com', age: 35 }
];

let nextUserId = 4;

// VALIDATION MIDDLEWARE
function validateUser(req, res, next) {
  const { name, email, age } = req.body;
  const errors = [];
  
  if (!name || name.trim().length < 2) {
    errors.push('Name must be at least 2 characters long');
  }
  
  if (!email || !/\S+@\S+\.\S+/.test(email)) {
    errors.push('Valid email is required');
  }
  
  if (!age || age < 0 || age > 150) {
    errors.push('Age must be between 0 and 150');
  }
  
  if (errors.length > 0) {
    return res.status(400).json({
      success: false,
      message: 'Validation failed',
      errors
    });
  }
  
  next();
}

// ERROR HANDLING MIDDLEWARE
function errorHandler(err, req, res, next) {
  console.error(err.stack);
  
  if (err.type === 'entity.parse.failed') {
    return res.status(400).json({
      success: false,
      message: 'Invalid JSON in request body'
    });
  }
  
  res.status(500).json({
    success: false,
    message: 'Internal server error'
  });
}

// RESTFUL API ROUTES

// GET /api/users - Get all users
app.get('/api/users', (req, res) => {
  const { page = 1, limit = 10, search } = req.query;
  
  let filteredUsers = users;
  
  // Search functionality
  if (search) {
    filteredUsers = users.filter(user =>
      user.name.toLowerCase().includes(search.toLowerCase()) ||
      user.email.toLowerCase().includes(search.toLowerCase())
    );
  }
  
  // Pagination
  const startIndex = (page - 1) * limit;
  const endIndex = page * limit;
  const paginatedUsers = filteredUsers.slice(startIndex, endIndex);
  
  res.json({
    success: true,
    data: paginatedUsers,
    pagination: {
      page: parseInt(page),
      limit: parseInt(limit),
      total: filteredUsers.length,
      pages: Math.ceil(filteredUsers.length / limit)
    }
  });
});

// GET /api/users/:id - Get user by ID
app.get('/api/users/:id', (req, res) => {
  const id = parseInt(req.params.id);
  const user = users.find(u => u.id === id);
  
  if (!user) {
    return res.status(404).json({
      success: false,
      message: 'User not found'
    });
  }
  
  res.json({
    success: true,
    data: user
  });
});

// POST /api/users - Create new user
app.post('/api/users', validateUser, (req, res) => {
  const { name, email, age } = req.body;
  
  // Check if email already exists
  const existingUser = users.find(u => u.email === email);
  if (existingUser) {
    return res.status(409).json({
      success: false,
      message: 'User with this email already exists'
    });
  }
  
  const newUser = {
    id: nextUserId++,
    name: name.trim(),
    email: email.toLowerCase(),
    age: parseInt(age)
  };
  
  users.push(newUser);
  
  res.status(201).json({
    success: true,
    message: 'User created successfully',
    data: newUser
  });
});

// PUT /api/users/:id - Update user
app.put('/api/users/:id', validateUser, (req, res) => {
  const id = parseInt(req.params.id);
  const userIndex = users.findIndex(u => u.id === id);
  
  if (userIndex === -1) {
    return res.status(404).json({
      success: false,
      message: 'User not found'
    });
  }
  
  const { name, email, age } = req.body;
  
  // Check if email is taken by another user
  const existingUser = users.find(u => u.email === email && u.id !== id);
  if (existingUser) {
    return res.status(409).json({
      success: false,
      message: 'Email is already taken by another user'
    });
  }
  
  users[userIndex] = {
    ...users[userIndex],
    name: name.trim(),
    email: email.toLowerCase(),
    age: parseInt(age)
  };
  
  res.json({
    success: true,
    message: 'User updated successfully',
    data: users[userIndex]
  });
});

// PATCH /api/users/:id - Partial update user
app.patch('/api/users/:id', (req, res) => {
  const id = parseInt(req.params.id);
  const userIndex = users.findIndex(u => u.id === id);
  
  if (userIndex === -1) {
    return res.status(404).json({
      success: false,
      message: 'User not found'
    });
  }
  
  const updates = {};
  const { name, email, age } = req.body;
  
  // Validate and prepare updates
  if (name !== undefined) {
    if (!name || name.trim().length < 2) {
      return res.status(400).json({
        success: false,
        message: 'Name must be at least 2 characters long'
      });
    }
    updates.name = name.trim();
  }
  
  if (email !== undefined) {
    if (!/\S+@\S+\.\S+/.test(email)) {
      return res.status(400).json({
        success: false,
        message: 'Valid email is required'
      });
    }
    
    // Check if email is taken
    const existingUser = users.find(u => u.email === email && u.id !== id);
    if (existingUser) {
      return res.status(409).json({
        success: false,
        message: 'Email is already taken by another user'
      });
    }
    
    updates.email = email.toLowerCase();
  }
  
  if (age !== undefined) {
    if (age < 0 || age > 150) {
      return res.status(400).json({
        success: false,
        message: 'Age must be between 0 and 150'
      });
    }
    updates.age = parseInt(age);
  }
  
  users[userIndex] = { ...users[userIndex], ...updates };
  
  res.json({
    success: true,
    message: 'User updated successfully',
    data: users[userIndex]
  });
});

// DELETE /api/users/:id - Delete user
app.delete('/api/users/:id', (req, res) => {
  const id = parseInt(req.params.id);
  const userIndex = users.findIndex(u => u.id === id);
  
  if (userIndex === -1) {
    return res.status(404).json({
      success: false,
      message: 'User not found'
    });
  }
  
  const deletedUser = users.splice(userIndex, 1)[0];
  
  res.json({
    success: true,
    message: 'User deleted successfully',
    data: deletedUser
  });
});

// ADVANCED FEATURES

// Bulk operations
app.post('/api/users/bulk', (req, res) => {
  const { users: bulkUsers } = req.body;
  
  if (!Array.isArray(bulkUsers)) {
    return res.status(400).json({
      success: false,
      message: 'Expected array of users'
    });
  }
  
  const createdUsers = [];
  const errors = [];
  
  bulkUsers.forEach((userData, index) => {
    const { name, email, age } = userData;
    
    // Validation
    if (!name || !email || !age) {
      errors.push({
        index,
        message: 'Missing required fields',
        data: userData
      });
      return;
    }
    
    // Check for duplicate email
    if (users.find(u => u.email === email)) {
      errors.push({
        index,
        message: 'Email already exists',
        data: userData
      });
      return;
    }
    
    const newUser = {
      id: nextUserId++,
      name: name.trim(),
      email: email.toLowerCase(),
      age: parseInt(age)
    };
    
    users.push(newUser);
    createdUsers.push(newUser);
  });
  
  res.status(201).json({
    success: true,
    message: `Created ${createdUsers.length} users`,
    data: createdUsers,
    errors
  });
});

// Search endpoint with advanced filtering
app.get('/api/users/search', (req, res) => {
  const { q, minAge, maxAge, sortBy = 'id', order = 'asc' } = req.query;
  
  let filteredUsers = users;
  
  // Text search
  if (q) {
    filteredUsers = filteredUsers.filter(user =>
      user.name.toLowerCase().includes(q.toLowerCase()) ||
      user.email.toLowerCase().includes(q.toLowerCase())
    );
  }
  
  // Age range filtering
  if (minAge) {
    filteredUsers = filteredUsers.filter(user => user.age >= parseInt(minAge));
  }
  
  if (maxAge) {
    filteredUsers = filteredUsers.filter(user => user.age <= parseInt(maxAge));
  }
  
  // Sorting
  filteredUsers.sort((a, b) => {
    if (order === 'desc') {
      return b[sortBy] > a[sortBy] ? 1 : -1;
    }
    return a[sortBy] > b[sortBy] ? 1 : -1;
  });
  
  res.json({
    success: true,
    data: filteredUsers,
    query: { q, minAge, maxAge, sortBy, order }
  });
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    success: true,
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    memory: process.memoryUsage(),
    version: process.version
  });
});

// API documentation endpoint
app.get('/api/docs', (req, res) => {
  const apiDocs = {
    endpoints: [
      {
        method: 'GET',
        path: '/api/users',
        description: 'Get all users with pagination and search',
        query: ['page', 'limit', 'search']
      },
      {
        method: 'GET',
        path: '/api/users/:id',
        description: 'Get user by ID'
      },
      {
        method: 'POST',
        path: '/api/users',
        description: 'Create new user',
        body: { name: 'string', email: 'string', age: 'number' }
      },
      {
        method: 'PUT',
        path: '/api/users/:id',
        description: 'Update user completely',
        body: { name: 'string', email: 'string', age: 'number' }
      },
      {
        method: 'PATCH',
        path: '/api/users/:id',
        description: 'Update user partially',
        body: { name: 'string?', email: 'string?', age: 'number?' }
      },
      {
        method: 'DELETE',
        path: '/api/users/:id',
        description: 'Delete user'
      }
    ]
  };
  
  res.json(apiDocs);
});

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({
    success: false,
    message: 'Endpoint not found'
  });
});

// Error handling middleware (must be last)
app.use(errorHandler);

// SERVER STARTUP
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
  console.log(`API Documentation: http://localhost:${PORT}/api/docs`);
  console.log(`Health Check: http://localhost:${PORT}/health`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received. Shutting down gracefully...');
  process.exit(0);
});

process.on('SIGINT', () => {
  console.log('SIGINT received. Shutting down gracefully...');
  process.exit(0);
});

module.exports = app; // For testing
```

**Key Express.js Concepts:**

1. **Middleware**: Functions that execute during request-response cycle
2. **Routing**: Define endpoints for different HTTP methods
3. **Request/Response**: Handle incoming requests and send responses
4. **Error Handling**: Centralized error management
5. **Static Files**: Serve static assets
6. **Template Engines**: Render dynamic HTML (EJS, Pug, Handlebars)

**RESTful API Best Practices:**

- Use proper HTTP methods (GET, POST, PUT, PATCH, DELETE)
- Implement consistent response format
- Add validation and error handling
- Use status codes correctly
- Implement pagination for lists
- Add rate limiting and security headers
- Document your API

---

## Navigation

⬅️ **[Previous: React Questions](./react-questions.md)**  
➡️ **[Next: PostgreSQL Questions](./postgresql-questions.md)**  
🏠 **[Home: Research Index](../README.md)**

---

*These Node.js questions cover fundamental concepts, Express.js framework, and API development patterns essential for the Dev Partners Senior Full Stack Developer position.*
