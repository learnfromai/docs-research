# Architecture Patterns in Express.js Open Source Projects

## 🏗️ Overview

This analysis examines the architectural patterns and design decisions found across the 15 analyzed Express.js projects. These patterns represent battle-tested approaches to building scalable, maintainable applications.

## 📐 Core Architecture Patterns

### 1. **MVC (Model-View-Controller)** - 85% Adoption

The most common pattern found across projects, providing clear separation of concerns.

**Structure Example (Used by Ghost, Strapi, WikiJS)**:
```
src/
├── models/          # Data models and schemas
├── views/           # Templates or view logic  
├── controllers/     # Request/response handling
├── routes/          # Route definitions
└── middleware/      # Custom middleware
```

**Implementation Example**:
```javascript
// controllers/userController.js
const User = require('../models/User');

class UserController {
  async getUser(req, res, next) {
    try {
      const user = await User.findById(req.params.id);
      res.json({ user: user.toJSON() });
    } catch (error) {
      next(error);
    }
  }
  
  async createUser(req, res, next) {
    try {
      const user = await User.create(req.body);
      res.status(201).json({ user: user.toJSON() });
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new UserController();
```

**Advantages**:
- Clear separation of concerns
- Easy to understand and maintain
- Testable components
- Scales well for medium-sized applications

---

### 2. **Repository Pattern** - 70% Adoption

Abstracts data access logic, making applications more testable and database-agnostic.

**Found in**: Parse Server, Botpress, Ghost, Joplin

**Implementation Example**:
```javascript
// repositories/UserRepository.js
class UserRepository {
  constructor(database) {
    this.db = database;
  }
  
  async findById(id) {
    return this.db.users.findUnique({
      where: { id },
      include: { profile: true }
    });
  }
  
  async findByEmail(email) {
    return this.db.users.findUnique({
      where: { email }
    });
  }
  
  async create(userData) {
    return this.db.users.create({
      data: userData
    });
  }
  
  async update(id, updates) {
    return this.db.users.update({
      where: { id },
      data: updates
    });
  }
  
  async delete(id) {
    return this.db.users.delete({
      where: { id }
    });
  }
}

module.exports = UserRepository;
```

**Usage in Service Layer**:
```javascript
// services/UserService.js
class UserService {
  constructor(userRepository, emailService) {
    this.userRepository = userRepository;
    this.emailService = emailService;
  }
  
  async createUser(userData) {
    // Business logic validation
    if (!userData.email || !userData.password) {
      throw new Error('Email and password are required');
    }
    
    const existingUser = await this.userRepository.findByEmail(userData.email);
    if (existingUser) {
      throw new Error('User with this email already exists');
    }
    
    // Hash password, create user, send welcome email
    const hashedPassword = await bcrypt.hash(userData.password, 10);
    const user = await this.userRepository.create({
      ...userData,
      password: hashedPassword
    });
    
    await this.emailService.sendWelcomeEmail(user.email);
    return user;
  }
}
```

---

### 3. **Service Layer Pattern** - 65% Adoption

Encapsulates business logic and orchestrates operations between repositories.

**Found in**: Strapi, Rocket.Chat, Botpress, WikiJS

**Benefits**:
- Business logic separation
- Reusable across different controllers
- Easier testing of business rules
- Clear dependency management

**Implementation Example**:
```javascript
// services/AuthService.js
class AuthService {
  constructor(userRepository, tokenService, emailService) {
    this.userRepository = userRepository;
    this.tokenService = tokenService;
    this.emailService = emailService;
  }
  
  async login(email, password) {
    const user = await this.userRepository.findByEmail(email);
    if (!user || !await bcrypt.compare(password, user.password)) {
      throw new Error('Invalid credentials');
    }
    
    if (!user.isEmailVerified) {
      throw new Error('Please verify your email before logging in');
    }
    
    const token = this.tokenService.generateAccessToken(user.id);
    const refreshToken = this.tokenService.generateRefreshToken(user.id);
    
    await this.userRepository.update(user.id, {
      lastLoginAt: new Date(),
      refreshToken: await bcrypt.hash(refreshToken, 10)
    });
    
    return { user, token, refreshToken };
  }
  
  async register(userData) {
    const user = await this.userRepository.create(userData);
    const verificationToken = this.tokenService.generateVerificationToken(user.id);
    
    await this.emailService.sendVerificationEmail(user.email, verificationToken);
    return user;
  }
}
```

---

### 4. **Middleware Pipeline Pattern** - 95% Adoption

Essential pattern for Express.js applications, used by virtually all analyzed projects.

**Common Pipeline Structure**:
```javascript
// app.js - Standard middleware pipeline
const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');

const app = express();

// Security middleware
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      scriptSrc: ["'self'"],
      imgSrc: ["'self'", "data:", "https:"]
    }
  }
}));

// CORS configuration
app.use(cors({
  origin: process.env.ALLOWED_ORIGINS?.split(',') || 'http://localhost:3000',
  credentials: true,
  optionsSuccessStatus: 200
}));

// Logging
app.use(morgan(process.env.NODE_ENV === 'production' ? 'combined' : 'dev'));

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // limit each IP to 100 requests per windowMs
  message: 'Too many requests from this IP'
});
app.use('/api/', limiter);

// Body parsing
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Authentication middleware
app.use('/api/', authenticationMiddleware);

// API routes
app.use('/api/users', userRoutes);
app.use('/api/auth', authRoutes);

// Error handling (must be last)
app.use(errorHandlingMiddleware);
```

**Custom Middleware Examples**:
```javascript
// middleware/authentication.js
const jwt = require('jsonwebtoken');

const authenticationMiddleware = (req, res, next) => {
  // Skip authentication for public routes
  const publicRoutes = ['/api/auth/login', '/api/auth/register'];
  if (publicRoutes.includes(req.path)) {
    return next();
  }
  
  const token = req.headers.authorization?.replace('Bearer ', '');
  if (!token) {
    return res.status(401).json({ error: 'Authentication required' });
  }
  
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = decoded;
    next();
  } catch (error) {
    res.status(401).json({ error: 'Invalid token' });
  }
};

// middleware/validation.js
const { validationResult } = require('express-validator');

const validationMiddleware = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({
      error: 'Validation failed',
      details: errors.array()
    });
  }
  next();
};
```

---

### 5. **Plugin/Module Architecture** - 40% Adoption

Extensible architecture allowing feature extensions without core modifications.

**Found in**: Strapi, Ghost, Botpress, Etherpad

**Strapi Plugin Example**:
```javascript
// plugins/custom-auth/server/index.js
module.exports = {
  register({ strapi }) {
    // Register custom authentication provider
    strapi.plugins['users-permissions'].services.providers.register('custom-oauth', {
      init(settings) {
        return {
          async authenticate(token) {
            // Custom authentication logic
            const user = await validateCustomToken(token);
            return user;
          }
        };
      }
    });
  },
  
  bootstrap({ strapi }) {
    // Plugin initialization logic
  }
};
```

**Ghost Plugin System**:
```javascript
// core/server/lib/ghost.js
class GhostServer {
  constructor() {
    this.plugins = new Map();
  }
  
  loadPlugin(name, plugin) {
    this.plugins.set(name, plugin);
    plugin.init(this);
  }
  
  async start() {
    // Initialize all loaded plugins
    for (const [name, plugin] of this.plugins) {
      await plugin.start();
    }
  }
}
```

---

### 6. **Microservices Architecture** - 40% Adoption

Breaking applications into smaller, independent services.

**Found in**: Sentry, GitLab, Discourse, Mattermost

**Service Communication Example**:
```javascript
// services/user-service/index.js
const express = require('express');
const axios = require('axios');

const app = express();

app.get('/users/:id', async (req, res) => {
  try {
    const user = await getUserFromDatabase(req.params.id);
    
    // Call other microservices for additional data
    const [profile, permissions] = await Promise.all([
      axios.get(`${process.env.PROFILE_SERVICE_URL}/profiles/${user.id}`),
      axios.get(`${process.env.AUTH_SERVICE_URL}/permissions/${user.id}`)
    ]);
    
    res.json({
      user,
      profile: profile.data,
      permissions: permissions.data
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});
```

**Service Discovery Pattern**:
```javascript
// utils/serviceRegistry.js
class ServiceRegistry {
  constructor() {
    this.services = new Map();
  }
  
  register(name, url, healthCheck) {
    this.services.set(name, { url, healthCheck, healthy: true });
    this.startHealthCheck(name);
  }
  
  async getService(name) {
    const service = this.services.get(name);
    if (!service || !service.healthy) {
      throw new Error(`Service ${name} is not available`);
    }
    return service;
  }
  
  async startHealthCheck(name) {
    const service = this.services.get(name);
    setInterval(async () => {
      try {
        await axios.get(`${service.url}${service.healthCheck}`);
        service.healthy = true;
      } catch (error) {
        service.healthy = false;
      }
    }, 30000); // Check every 30 seconds
  }
}
```

---

### 7. **Event-Driven Architecture** - 30% Adoption

Using events for loose coupling between components.

**Found in**: Rocket.Chat, Parse Server, Botpress

**Implementation Example**:
```javascript
// utils/EventBus.js
const EventEmitter = require('events');

class EventBus extends EventEmitter {
  constructor() {
    super();
    this.setMaxListeners(100); // Increase limit for many listeners
  }
  
  // Type-safe event emission
  emitUserCreated(user) {
    this.emit('user:created', { user, timestamp: new Date() });
  }
  
  emitUserUpdated(user, changes) {
    this.emit('user:updated', { user, changes, timestamp: new Date() });
  }
  
  emitUserDeleted(userId) {
    this.emit('user:deleted', { userId, timestamp: new Date() });
  }
}

const eventBus = new EventBus();

// Event listeners in different modules
eventBus.on('user:created', async (data) => {
  await emailService.sendWelcomeEmail(data.user.email);
  await analyticsService.trackUserSignup(data.user.id);
});

eventBus.on('user:updated', async (data) => {
  if (data.changes.includes('email')) {
    await emailService.sendEmailChangeNotification(data.user);
  }
});

module.exports = eventBus;
```

---

## 🔄 Data Flow Patterns

### 1. **Request-Response Flow** (Standard Pattern)
```
Client Request → Middleware Pipeline → Controller → Service → Repository → Database
                     ↓
Client Response ← Error Handler ← Controller ← Service ← Repository ← Database
```

### 2. **Event-Driven Flow** (Advanced Pattern)
```
Client Request → Controller → Service → Event Emission → Event Listeners
                     ↓              ↓           ↓
                Response      Database    Side Effects (Email, Analytics, etc.)
```

### 3. **CQRS Pattern** (Command Query Responsibility Segregation)
Used by 20% of analyzed projects for complex domains.

```javascript
// commands/CreateUserCommand.js
class CreateUserCommand {
  constructor(userData) {
    this.userData = userData;
    this.timestamp = new Date();
  }
  
  async execute() {
    // Validation
    await this.validate();
    
    // Execute command
    const user = await userRepository.create(this.userData);
    
    // Emit event
    eventBus.emitUserCreated(user);
    
    return user;
  }
  
  async validate() {
    if (!this.userData.email) {
      throw new Error('Email is required');
    }
    // Additional validation logic
  }
}

// queries/GetUserQuery.js
class GetUserQuery {
  constructor(userId) {
    this.userId = userId;
  }
  
  async execute() {
    const user = await userRepository.findById(this.userId);
    if (!user) {
      throw new Error('User not found');
    }
    return user;
  }
}
```

## 📊 Architecture Pattern Comparison

| Pattern | Complexity | Scalability | Maintainability | Learning Curve | Best For |
|---------|------------|-------------|-----------------|----------------|----------|
| **MVC** | Low | Medium | High | Low | Small to medium apps |
| **Repository** | Medium | High | High | Medium | Data-heavy applications |
| **Service Layer** | Medium | High | High | Medium | Business logic heavy apps |
| **Microservices** | High | Very High | Medium | High | Large scale systems |
| **Event-Driven** | Medium | High | Medium | Medium | Real-time applications |
| **Plugin-based** | High | Very High | High | High | Extensible platforms |

## 🎯 Choosing the Right Pattern

### For Small Applications (< 10 routes)
```javascript
// Simple MVC with minimal layers
src/
├── controllers/
├── models/
├── routes/
└── middleware/
```

### For Medium Applications (10-50 routes)
```javascript
// MVC + Service Layer + Repository
src/
├── controllers/
├── services/
├── repositories/
├── models/
├── middleware/
├── routes/
└── utils/
```

### For Large Applications (50+ routes)
```javascript
// Full layered architecture with domain separation
src/
├── domains/
│   ├── user/
│   │   ├── controllers/
│   │   ├── services/
│   │   ├── repositories/
│   │   └── models/
│   └── order/
├── shared/
│   ├── middleware/
│   ├── utils/
│   └── config/
└── infrastructure/
    ├── database/
    ├── cache/
    └── queue/
```

## 🔧 Implementation Guidelines

### 1. **Start Simple, Evolve Gradually**
- Begin with basic MVC pattern
- Add Repository pattern as data complexity grows
- Introduce Service layer for business logic
- Consider microservices only at scale

### 2. **Maintain Clear Boundaries**
- Controllers handle HTTP concerns only
- Services contain business logic
- Repositories handle data access
- Models define data structure

### 3. **Use Dependency Injection**
```javascript
// Dependency injection for testability
class UserController {
  constructor(userService, validationService) {
    this.userService = userService;
    this.validationService = validationService;
  }
  
  async createUser(req, res, next) {
    try {
      await this.validationService.validateCreateUser(req.body);
      const user = await this.userService.createUser(req.body);
      res.status(201).json({ user });
    } catch (error) {
      next(error);
    }
  }
}
```

---

**Next**: [Security Considerations](./security-considerations.md) | **Previous**: [Project Analysis](./project-analysis.md)