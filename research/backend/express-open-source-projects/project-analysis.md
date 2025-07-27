# Project Analysis: Express.js Open Source Projects

## 🎯 Overview

Detailed technical analysis of 15+ production-grade Express.js open source projects, examining their architecture, implementation patterns, and production practices.

## 📊 Project Selection & Analysis

### 1. Ghost (Blogging Platform)
**Repository**: [TryGhost/Ghost](https://github.com/TryGhost/Ghost)
**Stars**: 46k+ | **Production Usage**: Millions of websites

#### Architecture Highlights
```javascript
// Ghost's layered architecture
core/
├── server/
│   ├── api/          # API endpoints and controllers
│   ├── services/     # Business logic services  
│   ├── models/       # Data models (Bookshelf.js)
│   ├── middleware/   # Custom middleware
│   └── web/          # Route definitions
├── shared/           # Shared utilities
└── frontend/         # Theme engine
```

#### Key Patterns
- **Plugin Architecture**: Modular themes and extensions
- **Service Layer**: Clear separation of business logic
- **Event-Driven**: Extensive use of events for decoupling
- **Database Abstraction**: Bookshelf.js ORM with migrations

#### Security Implementation
```javascript
// Authentication middleware
const authenticate = (req, res, next) => {
    return passport.authenticate(['bearer', 'ghost'], 
        { session: false }, (err, user, info) => {
            if (err) return next(err);
            if (!user) return errors.NoPermissionError();
            req.user = user;
            next();
        })(req, res, next);
};

// Rate limiting
const rateLimit = require('express-rate-limit');
const limiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 100 // limit each IP to 100 requests per windowMs
});
```

#### Notable Dependencies
```json
{
  "express": "4.18.2",
  "passport": "0.6.0",
  "helmet": "7.0.0",
  "compression": "1.7.4",
  "cors": "2.8.5",
  "mysql2": "3.6.0",
  "bookshelf": "1.2.0"
}
```

### 2. Strapi (Headless CMS)
**Repository**: [strapi/strapi](https://github.com/strapi/strapi)
**Stars**: 61k+ | **Production Usage**: 1M+ projects

#### Architecture Highlights
```javascript
// Strapi's plugin-based architecture
packages/
├── core/
│   ├── strapi/        # Core framework
│   ├── database/      # Database layer
│   ├── utils/         # Shared utilities
│   └── admin/         # Admin panel
├── plugins/           # Core plugins
│   ├── users-permissions/  # Auth plugin
│   ├── upload/        # File upload
│   └── email/         # Email plugin
└── generators/        # Code generators
```

#### Key Patterns
- **Plugin Architecture**: Everything is a plugin
- **Lifecycle Hooks**: Extensive hook system for customization
- **Auto-generated APIs**: RESTful APIs from content types
- **Role-Based Access Control**: Fine-grained permissions

#### Security Implementation
```javascript
// JWT authentication strategy
const strategy = new JwtStrategy({
    jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
    secretOrKey: process.env.JWT_SECRET,
}, async (payload, done) => {
    try {
        const user = await strapi.query('plugin::users-permissions.user')
            .findOne({ where: { id: payload.id } });
        return done(null, user || false);
    } catch (error) {
        return done(error, false);
    }
});

// Permission middleware
const authorize = (permissions = []) => async (ctx, next) => {
    const { user } = ctx.state;
    if (!user) throw new UnauthorizedError();
    
    const userPermissions = await getUserPermissions(user);
    const hasPermission = permissions.every(p => 
        userPermissions.includes(p));
    
    if (!hasPermission) throw new ForbiddenError();
    await next();
};
```

#### Testing Strategy
```javascript
// Strapi's testing approach
const request = require('supertest');
const { setupStrapi, cleanupStrapi } = require('./helpers/strapi');

describe('Auth endpoints', () => {
    beforeAll(async () => {
        await setupStrapi();
    });

    afterAll(async () => {
        await cleanupStrapi();
    });

    test('Should login user', async () => {
        const response = await request(strapi.server.httpServer)
            .post('/api/auth/local')
            .send({ identifier: 'test@test.com', password: 'password' })
            .expect(200);

        expect(response.body.jwt).toBeDefined();
    });
});
```

### 3. Medusa (E-commerce Platform)
**Repository**: [medusajs/medusa](https://github.com/medusajs/medusa)
**Stars**: 24k+ | **Production Usage**: E-commerce stores

#### Architecture Highlights
```javascript
// Medusa's microservice-oriented architecture
packages/
├── medusa/            # Core commerce engine
├── admin-ui/          # Admin dashboard
├── medusa-js/         # JavaScript SDK
├── storefront/        # Example storefront
└── plugins/           # Payment, fulfillment plugins
    ├── payment-stripe/
    ├── payment-paypal/
    └── fulfillment-manual/
```

#### Key Patterns
- **Service Pattern**: Business logic in service classes
- **Event Architecture**: Async event handling for workflows
- **Plugin System**: Extensible payment and fulfillment providers
- **TypeScript First**: Full TypeScript implementation

#### Security Implementation
```typescript
// Medusa's authentication middleware
import { authenticate } from '@medusajs/medusa';

export default authenticate('api', 'bearer');

// Custom authorization
export const requireCustomer = async (req, res, next) => {
    const customerId = req.user?.customer_id;
    if (!customerId) {
        return res.status(401).json({ message: 'Customer authentication required' });
    }
    next();
};

// Rate limiting for APIs
export const rateLimitMiddleware = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: (req) => {
        if (req.user?.role === 'admin') return 1000;
        return 100; // Standard user limit
    },
    message: 'Too many requests from this IP'
});
```

#### Database Patterns
```typescript
// Medusa's repository pattern
export class ProductService extends TransactionBaseService {
    protected productRepository_: Repository<Product>;
    protected variantRepository_: Repository<ProductVariant>;

    async create(productData: CreateProductInput): Promise<Product> {
        return this.atomicPhase_(async (manager) => {
            const productRepo = manager.getCustomRepository(this.productRepository_);
            const product = productRepo.create(productData);
            return await productRepo.save(product);
        });
    }

    async update(productId: string, update: UpdateProductInput): Promise<Product> {
        return this.atomicPhase_(async (manager) => {
            const productRepo = manager.getCustomRepository(this.productRepository_);
            await productRepo.update(productId, update);
            return await this.retrieve(productId);
        });
    }
}
```

### 4. KeystoneJS (GraphQL CMS)
**Repository**: [keystonejs/keystone](https://github.com/keystonejs/keystone)
**Stars**: 8.9k+ | **Production Usage**: Enterprise CMSs

#### Architecture Highlights
```javascript
// KeystoneJS schema-first approach
// keystone.ts
export default withAuth(
    config({
        db: { provider: 'postgresql', url: process.env.DATABASE_URL },
        lists: {
            User: list({
                fields: {
                    name: text({ validation: { isRequired: true } }),
                    email: text({ validation: { isRequired: true }, isIndexed: 'unique' }),
                    password: password({ validation: { isRequired: true } }),
                    role: select({
                        options: [
                            { label: 'Admin', value: 'admin' },
                            { label: 'User', value: 'user' },
                        ],
                        defaultValue: 'user',
                    }),
                },
            }),
            Post: list({
                fields: {
                    title: text({ validation: { isRequired: true } }),
                    content: text({ ui: { displayMode: 'textarea' } }),
                    author: relationship({ ref: 'User' }),
                },
                access: {
                    operation: {
                        create: isSignedIn,
                        query: () => true,
                        update: isOwner,
                        delete: isOwner,
                    },
                },
            }),
        },
        session,
    })
);
```

#### Key Patterns
- **Schema-First Development**: Type-safe GraphQL API generation
- **Declarative Access Control**: Permission rules in schema
- **Auto-generated Admin UI**: Dynamic admin interface
- **TypeScript Integration**: Full type safety across stack

### 5. Feathers.js Applications
**Repository**: [feathersjs/feathers](https://github.com/feathersjs/feathers)
**Stars**: 15k+ | **Production Usage**: Real-time APIs

#### Architecture Highlights
```javascript
// Feathers real-time API structure
const feathers = require('@feathersjs/feathers');
const express = require('@feathersjs/express');
const socketio = require('@feathersjs/socketio');

const app = express(feathers());

// Configure Express middleware
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Configure Socket.io real-time APIs
app.configure(socketio());

// Configure services
app.use('/users', new UserService());
app.use('/messages', new MessageService());

// Real-time events
app.service('messages').on('created', (message) => {
    app.channel('general').send('message-created', message);
});
```

#### Key Patterns
- **Service-Oriented**: Everything is a service
- **Real-time First**: Built-in WebSocket support
- **Database Agnostic**: Multiple database adapters
- **Hook System**: Middleware for services

### 6. NestJS Examples
**Repository**: [nestjs/nest](https://github.com/nestjs/nest)
**Stars**: 66k+ | **Production Usage**: Enterprise applications

#### Architecture Highlights
```typescript
// NestJS decorator-based architecture
@Controller('users')
@UseGuards(JwtAuthGuard)
export class UsersController {
    constructor(private readonly usersService: UsersService) {}

    @Get()
    @UseInterceptors(CacheInterceptor)
    async findAll(@Query() query: FindUsersDto): Promise<User[]> {
        return this.usersService.findAll(query);
    }

    @Post()
    @UseGuards(RolesGuard)
    @Roles('admin')
    async create(@Body() createUserDto: CreateUserDto): Promise<User> {
        return this.usersService.create(createUserDto);
    }
}

// Service with dependency injection
@Injectable()
export class UsersService {
    constructor(
        @InjectRepository(User)
        private usersRepository: Repository<User>,
        private readonly cacheManager: Cache,
    ) {}

    async findAll(query: FindUsersDto): Promise<User[]> {
        const cacheKey = `users:${JSON.stringify(query)}`;
        const cached = await this.cacheManager.get(cacheKey);
        
        if (cached) return cached;
        
        const users = await this.usersRepository.find(query);
        await this.cacheManager.set(cacheKey, users, 300); // 5 minutes
        
        return users;
    }
}
```

#### Key Patterns
- **Decorator-Based**: Heavy use of decorators for configuration
- **Dependency Injection**: IoC container for service management
- **Module System**: Organized feature modules
- **TypeScript First**: Full TypeScript integration

### 7. Rocket.Chat
**Repository**: [RocketChat/Rocket.Chat](https://github.com/RocketChat/Rocket.Chat)
**Stars**: 39k+ | **Production Usage**: Team communication

#### Architecture Highlights
```javascript
// Rocket.Chat's real-time architecture
Meteor.startup(() => {
    // WebSocket connections
    Meteor.publish('stream-room-messages', function(rid) {
        if (!this.userId || !hasPermission(this.userId, 'view-room', rid)) {
            return this.ready();
        }
        
        return Messages.find({ rid }, {
            fields: { usernames: 0, importIds: 0 },
            sort: { ts: -1 },
            limit: 50
        });
    });

    // REST API endpoints
    API.v1.addRoute('chat.sendMessage', { authRequired: true }, {
        post() {
            const { message } = this.bodyParams;
            
            if (!hasPermission(this.userId, 'post-readonly', message.rid)) {
                return API.v1.unauthorized();
            }
            
            const messageObj = Meteor.call('sendMessage', message);
            return API.v1.success({ message: messageObj });
        }
    });
});
```

#### Key Patterns
- **Real-time Architecture**: WebSocket-first communication
- **Permission System**: Fine-grained access control
- **Plugin Architecture**: Extensible app system
- **Microservice Ready**: Distributed deployment support

### 8. Appsmith (Low-code Platform)
**Repository**: [appsmithorg/appsmith](https://github.com/appsmithorg/appsmith)
**Stars**: 32k+ | **Production Usage**: Internal tools

#### Architecture Highlights
```javascript
// Appsmith's plugin architecture
class RestApiPlugin extends BasePlugin {
    async execute(params) {
        const { method, url, headers, body } = params;
        
        // Security validation
        if (!this.validateDomain(url)) {
            throw new SecurityError('Domain not allowed');
        }
        
        // Rate limiting
        await this.checkRateLimit(params.userId);
        
        // Execute request
        const response = await this.httpClient.request({
            method,
            url,
            headers: this.sanitizeHeaders(headers),
            data: body,
            timeout: 30000
        });
        
        return this.formatResponse(response);
    }
    
    validateDomain(url) {
        const allowedDomains = process.env.ALLOWED_DOMAINS?.split(',') || [];
        const domain = new URL(url).hostname;
        return allowedDomains.includes(domain) || domain.endsWith('.internal');
    }
}
```

### 9. Grafana Backend APIs
**Repository**: [grafana/grafana](https://github.com/grafana/grafana)
**Stars**: 61k+ | **Production Usage**: Monitoring dashboards

#### Architecture Highlights
```go
// Grafana's Go backend with Express-like patterns
// (Included for comparison of patterns translated to Go)

// Middleware pattern
func AuthMiddleware() gin.HandlerFunc {
    return func(c *gin.Context) {
        token := c.GetHeader("Authorization")
        if token == "" {
            c.JSON(401, gin.H{"error": "Authentication required"})
            c.Abort()
            return
        }
        
        user, err := validateToken(token)
        if err != nil {
            c.JSON(401, gin.H{"error": "Invalid token"})
            c.Abort()
            return
        }
        
        c.Set("user", user)
        c.Next()
    }
}
```

### 10. Plausible Analytics
**Repository**: [plausible/analytics](https://github.com/plausible/analytics)
**Stars**: 19k+ | **Production Usage**: Website analytics

#### Architecture Highlights (Elixir Phoenix, but similar patterns)
```elixir
# Similar patterns to Express.js but in Phoenix
defmodule PlausibleWeb.API.StatsController do
  use PlausibleWeb, :controller
  
  def timeseries(conn, params) do
    with {:ok, site} <- get_site(params["site_id"]),
         :ok <- check_permission(conn, site),
         {:ok, query} <- build_query(params) do
      
      result = Stats.timeseries(site, query)
      json(conn, result)
    else
      {:error, :not_found} -> not_found(conn)
      {:error, :forbidden} -> forbidden(conn)
    end
  end
  
  defp check_permission(conn, site) do
    user = get_current_user(conn)
    if user && has_access?(user, site) do
      :ok
    else
      {:error, :forbidden}
    end
  end
end
```

## 🔧 Common Implementation Patterns

### 1. Error Handling Patterns

**Centralized Error Handler**
```javascript
// Global error handling middleware
const errorHandler = (err, req, res, next) => {
    logger.error(err.stack);
    
    if (err.type === 'ValidationError') {
        return res.status(400).json({
            success: false,
            error: {
                code: 'VALIDATION_ERROR',
                message: 'Invalid input data',
                details: err.details
            }
        });
    }
    
    if (err.type === 'UnauthorizedError') {
        return res.status(401).json({
            success: false,
            error: {
                code: 'UNAUTHORIZED',
                message: 'Authentication required'
            }
        });
    }
    
    // Default error response
    res.status(500).json({
        success: false,
        error: {
            code: 'INTERNAL_ERROR',
            message: 'Something went wrong'
        }
    });
};
```

**Custom Error Classes**
```javascript
class AppError extends Error {
    constructor(message, statusCode = 500, code = 'INTERNAL_ERROR') {
        super(message);
        this.statusCode = statusCode;
        this.code = code;
        this.isOperational = true;
        
        Error.captureStackTrace(this, this.constructor);
    }
}

class ValidationError extends AppError {
    constructor(message, details = []) {
        super(message, 400, 'VALIDATION_ERROR');
        this.details = details;
    }
}

class NotFoundError extends AppError {
    constructor(resource = 'Resource') {
        super(`${resource} not found`, 404, 'NOT_FOUND');
    }
}
```

### 2. Authentication Patterns

**JWT with Refresh Tokens**
```javascript
const jwt = require('jsonwebtoken');
const { promisify } = require('util');

class AuthService {
    generateTokens(user) {
        const accessToken = jwt.sign(
            { userId: user.id, role: user.role },
            process.env.JWT_SECRET,
            { expiresIn: '15m' }
        );
        
        const refreshToken = jwt.sign(
            { userId: user.id, tokenVersion: user.tokenVersion },
            process.env.REFRESH_SECRET,
            { expiresIn: '7d' }
        );
        
        return { accessToken, refreshToken };
    }
    
    async verifyToken(token) {
        try {
            const verify = promisify(jwt.verify);
            return await verify(token, process.env.JWT_SECRET);
        } catch (error) {
            throw new UnauthorizedError('Invalid token');
        }
    }
    
    async refreshTokens(refreshToken) {
        const payload = await this.verifyRefreshToken(refreshToken);
        const user = await User.findById(payload.userId);
        
        if (!user || user.tokenVersion !== payload.tokenVersion) {
            throw new UnauthorizedError('Invalid refresh token');
        }
        
        return this.generateTokens(user);
    }
}
```

### 3. Validation Patterns

**Joi Schema Validation**
```javascript
const Joi = require('joi');

const createUserSchema = Joi.object({
    email: Joi.string().email().required(),
    password: Joi.string().min(8).pattern(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/).required(),
    name: Joi.string().min(2).max(50).required(),
    role: Joi.string().valid('user', 'admin').default('user')
});

const validateRequest = (schema) => {
    return (req, res, next) => {
        const { error, value } = schema.validate(req.body);
        
        if (error) {
            return next(new ValidationError('Invalid input', error.details));
        }
        
        req.validatedBody = value;
        next();
    };
};

// Usage
app.post('/users', validateRequest(createUserSchema), createUser);
```

**Zod Schema Validation (TypeScript)**
```typescript
import { z } from 'zod';

const CreateUserSchema = z.object({
    email: z.string().email(),
    password: z.string().min(8).regex(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/),
    name: z.string().min(2).max(50),
    role: z.enum(['user', 'admin']).default('user')
});

type CreateUserInput = z.infer<typeof CreateUserSchema>;

const validateZod = <T>(schema: z.ZodSchema<T>) => {
    return (req: Request, res: Response, next: NextFunction) => {
        try {
            req.validatedBody = schema.parse(req.body);
            next();
        } catch (error) {
            if (error instanceof z.ZodError) {
                return next(new ValidationError('Invalid input', error.errors));
            }
            next(error);
        }
    };
};
```

### 4. Database Patterns

**Repository Pattern with TypeORM**
```typescript
@Entity()
export class User {
    @PrimaryGeneratedColumn('uuid')
    id: string;

    @Column({ unique: true })
    email: string;

    @Column()
    password: string;

    @Column({ default: 'user' })
    role: string;

    @CreateDateColumn()
    createdAt: Date;

    @UpdateDateColumn()
    updatedAt: Date;
}

@Injectable()
export class UserRepository {
    constructor(
        @InjectRepository(User)
        private repository: Repository<User>
    ) {}

    async findByEmail(email: string): Promise<User | null> {
        return this.repository.findOne({ where: { email } });
    }

    async create(userData: Partial<User>): Promise<User> {
        const user = this.repository.create(userData);
        return this.repository.save(user);
    }

    async findWithPagination(page: number, limit: number): Promise<[User[], number]> {
        return this.repository.findAndCount({
            skip: (page - 1) * limit,
            take: limit,
            order: { createdAt: 'DESC' }
        });
    }
}
```

**Prisma Pattern**
```typescript
import { PrismaClient } from '@prisma/client';

class UserService {
    constructor(private prisma: PrismaClient) {}

    async createUser(data: { email: string; password: string; name: string }) {
        return this.prisma.user.create({
            data: {
                ...data,
                password: await bcrypt.hash(data.password, 12)
            },
            select: {
                id: true,
                email: true,
                name: true,
                role: true,
                createdAt: true
            }
        });
    }

    async findUsers(params: {
        skip?: number;
        take?: number;
        where?: any;
        orderBy?: any;
    }) {
        return this.prisma.user.findMany({
            ...params,
            select: {
                id: true,
                email: true,
                name: true,
                role: true,
                createdAt: true
            }
        });
    }
}
```

## 📊 Performance Patterns Analysis

### Caching Strategies

**Redis Implementation**
```javascript
const redis = require('redis');
const client = redis.createClient(process.env.REDIS_URL);

class CacheService {
    async get(key) {
        try {
            const value = await client.get(key);
            return value ? JSON.parse(value) : null;
        } catch (error) {
            console.error('Cache get error:', error);
            return null;
        }
    }

    async set(key, value, ttl = 3600) {
        try {
            await client.setex(key, ttl, JSON.stringify(value));
        } catch (error) {
            console.error('Cache set error:', error);
        }
    }

    async del(key) {
        try {
            await client.del(key);
        } catch (error) {
            console.error('Cache delete error:', error);
        }
    }
}

// Usage in controllers
const getCachedUser = async (req, res, next) => {
    const cacheKey = `user:${req.params.id}`;
    const cached = await cacheService.get(cacheKey);
    
    if (cached) {
        return res.json({ success: true, data: cached });
    }
    
    next();
};
```

## 🔗 Navigation

← [Executive Summary](./executive-summary.md) | [Authentication Patterns](./authentication-patterns.md) →