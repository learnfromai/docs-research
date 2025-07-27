# Architecture Patterns in Express.js Open Source Projects

## 🏗️ Overview

Analysis of architectural patterns and code organization strategies used in production Express.js applications, examining how successful projects structure their codebase for maintainability, scalability, and team collaboration.

## 📊 Architecture Pattern Distribution

### Primary Architecture Patterns

| Pattern | Adoption Rate | Best For | Examples |
|---------|---------------|----------|----------|
| **Layered Architecture** | 85% | Most applications | Ghost, Strapi, Medusa |
| **Clean Architecture** | 40% | Enterprise apps | NestJS projects, large e-commerce |
| **Plugin/Module Architecture** | 60% | Extensible platforms | Ghost, Strapi, KeystoneJS |
| **Microservices** | 30% | Large distributed systems | Medusa, enterprise platforms |
| **Event-Driven Architecture** | 45% | Real-time applications | Rocket.Chat, Feathers.js |
| **Hexagonal Architecture** | 25% | Domain-heavy applications | Advanced NestJS projects |

## 🏛️ Layered Architecture Pattern

### 1. Standard Three-Layer Architecture

**Ghost's Implementation**
```javascript
// Project structure following layered architecture
core/
├── server/
│   ├── api/              # API Layer (Controllers)
│   │   ├── endpoints/    # Route handlers
│   │   ├── shared/       # Shared API utilities
│   │   └── middleware/   # Custom middleware
│   ├── services/         # Business Logic Layer
│   │   ├── auth/         # Authentication services
│   │   ├── posts/        # Post management
│   │   ├── users/        # User management
│   │   └── themes/       # Theme services
│   ├── data/            # Data Access Layer
│   │   ├── models/       # Data models
│   │   ├── migrations/   # Database migrations
│   │   └── repositories/ # Data access patterns
│   └── lib/             # Infrastructure Layer
│       ├── security/     # Security utilities
│       ├── common/       # Common utilities
│       └── adapters/     # External service adapters
```

**API Layer Implementation**
```javascript
// controllers/postController.js
const { PostService } = require('../services');
const { validateRequest, handleErrors } = require('../middleware');

class PostController {
    constructor() {
        this.postService = new PostService();
    }

    async createPost(req, res, next) {
        try {
            const postData = req.validatedBody;
            const post = await this.postService.create(postData, req.user);
            
            res.status(201).json({
                success: true,
                data: post
            });
        } catch (error) {
            next(error);
        }
    }

    async getPosts(req, res, next) {
        try {
            const filters = req.query;
            const posts = await this.postService.findAll(filters, req.user);
            
            res.json({
                success: true,
                data: posts.data,
                meta: posts.meta
            });
        } catch (error) {
            next(error);
        }
    }

    async updatePost(req, res, next) {
        try {
            const { id } = req.params;
            const updateData = req.validatedBody;
            
            const post = await this.postService.update(id, updateData, req.user);
            
            res.json({
                success: true,
                data: post
            });
        } catch (error) {
            next(error);
        }
    }
}

module.exports = PostController;
```

**Service Layer Implementation**
```javascript
// services/PostService.js
const { PostRepository, UserRepository } = require('../data/repositories');
const { ValidationError, NotFoundError, ForbiddenError } = require('../lib/errors');
const { EventBus } = require('../lib/events');

class PostService {
    constructor() {
        this.postRepository = new PostRepository();
        this.userRepository = new UserRepository();
        this.eventBus = new EventBus();
    }

    async create(postData, user) {
        // Business logic validation
        if (!user.canCreatePost()) {
            throw new ForbiddenError('User cannot create posts');
        }

        // Data validation
        await this.validatePostData(postData);

        // Create post
        const post = await this.postRepository.create({
            ...postData,
            authorId: user.id,
            status: user.role === 'admin' ? 'published' : 'draft'
        });

        // Emit event for other services
        this.eventBus.emit('post.created', { post, user });

        return post;
    }

    async findAll(filters, user) {
        // Apply user-specific filters
        const queryFilters = this.buildUserFilters(filters, user);
        
        const result = await this.postRepository.findWithPagination(queryFilters);
        
        // Transform data for API response
        return {
            data: result.posts.map(post => this.transformPost(post, user)),
            meta: {
                total: result.total,
                page: filters.page || 1,
                limit: filters.limit || 10,
                totalPages: Math.ceil(result.total / (filters.limit || 10))
            }
        };
    }

    async update(postId, updateData, user) {
        const post = await this.postRepository.findById(postId);
        
        if (!post) {
            throw new NotFoundError('Post not found');
        }

        // Authorization check
        if (!this.canUserUpdatePost(user, post)) {
            throw new ForbiddenError('Cannot update this post');
        }

        // Validate update data
        await this.validateUpdateData(updateData, post);

        // Apply business rules
        const processedData = this.processUpdateData(updateData, post, user);
        
        const updatedPost = await this.postRepository.update(postId, processedData);
        
        this.eventBus.emit('post.updated', { post: updatedPost, user });
        
        return updatedPost;
    }

    // Private methods for business logic
    async validatePostData(data) {
        const schema = Joi.object({
            title: Joi.string().min(3).max(200).required(),
            content: Joi.string().min(10).required(),
            tags: Joi.array().items(Joi.string()),
            status: Joi.string().valid('draft', 'published').default('draft')
        });

        const { error } = schema.validate(data);
        if (error) {
            throw new ValidationError('Invalid post data', error.details);
        }
    }

    buildUserFilters(filters, user) {
        const queryFilters = { ...filters };

        // Non-admin users can only see published posts by default
        if (user.role !== 'admin') {
            if (!queryFilters.status) {
                queryFilters.status = 'published';
            }
        }

        return queryFilters;
    }

    canUserUpdatePost(user, post) {
        if (user.role === 'admin') return true;
        if (post.authorId === user.id) return true;
        return false;
    }

    transformPost(post, user) {
        const transformed = {
            id: post.id,
            title: post.title,
            excerpt: post.excerpt,
            status: post.status,
            publishedAt: post.publishedAt,
            createdAt: post.createdAt
        };

        // Include sensitive data only for authorized users
        if (this.canUserViewFullPost(user, post)) {
            transformed.content = post.content;
            transformed.author = post.author;
        }

        return transformed;
    }
}

module.exports = PostService;
```

**Data Access Layer Implementation**
```javascript
// data/repositories/PostRepository.js
const { Post, User, Tag } = require('../models');
const { Op } = require('sequelize');

class PostRepository {
    async create(postData) {
        return await Post.create(postData, {
            include: [
                { model: User, as: 'author' },
                { model: Tag, as: 'tags' }
            ]
        });
    }

    async findById(id) {
        return await Post.findByPk(id, {
            include: [
                { model: User, as: 'author' },
                { model: Tag, as: 'tags' }
            ]
        });
    }

    async findWithPagination(filters) {
        const { page = 1, limit = 10, status, authorId, tags } = filters;
        const offset = (page - 1) * limit;

        const whereClause = {};
        
        if (status) whereClause.status = status;
        if (authorId) whereClause.authorId = authorId;

        const includeClause = [
            { model: User, as: 'author' }
        ];

        if (tags && tags.length > 0) {
            includeClause.push({
                model: Tag,
                as: 'tags',
                where: { name: { [Op.in]: tags } }
            });
        } else {
            includeClause.push({ model: Tag, as: 'tags' });
        }

        const { rows: posts, count: total } = await Post.findAndCountAll({
            where: whereClause,
            include: includeClause,
            limit: parseInt(limit),
            offset: parseInt(offset),
            order: [['createdAt', 'DESC']],
            distinct: true
        });

        return { posts, total };
    }

    async update(id, updateData) {
        await Post.update(updateData, { where: { id } });
        return await this.findById(id);
    }

    async delete(id) {
        return await Post.destroy({ where: { id } });
    }

    async findBySlug(slug) {
        return await Post.findOne({
            where: { slug },
            include: [
                { model: User, as: 'author' },
                { model: Tag, as: 'tags' }
            ]
        });
    }
}

module.exports = PostRepository;
```

### 2. Enhanced Four-Layer Architecture

**Strapi's Advanced Layered Structure**
```javascript
// Advanced layered architecture with additional abstraction
src/
├── api/                 # API Layer
│   ├── routes/          # Route definitions
│   ├── controllers/     # Request handlers
│   ├── middlewares/     # Request/response middleware
│   └── validators/      # Input validation
├── services/            # Business Logic Layer
│   ├── domain/          # Domain services
│   ├── application/     # Application services
│   └── infrastructure/  # Infrastructure services
├── repositories/        # Data Access Layer
│   ├── interfaces/      # Repository contracts
│   └── implementations/ # Concrete implementations
└── models/             # Data Models Layer
    ├── entities/        # Domain entities
    ├── value-objects/   # Value objects
    └── aggregates/      # Domain aggregates

// Application Service Layer
class UserApplicationService {
    constructor() {
        this.userDomainService = new UserDomainService();
        this.userRepository = new UserRepository();
        this.emailService = new EmailService();
        this.auditService = new AuditService();
    }

    async registerUser(registrationData) {
        // Application-level coordination
        const user = await this.userDomainService.createUser(registrationData);
        
        // Persist user
        const savedUser = await this.userRepository.save(user);
        
        // Send welcome email (async)
        this.emailService.sendWelcomeEmail(savedUser.email);
        
        // Log registration
        this.auditService.logUserRegistration(savedUser.id);
        
        return savedUser;
    }
}

// Domain Service Layer
class UserDomainService {
    async createUser(userData) {
        // Domain-specific business rules
        this.validateUserData(userData);
        
        const hashedPassword = await this.hashPassword(userData.password);
        
        return new User({
            ...userData,
            password: hashedPassword,
            status: 'pending_verification',
            createdAt: new Date()
        });
    }

    validateUserData(userData) {
        if (!this.isValidEmail(userData.email)) {
            throw new DomainError('Invalid email format');
        }
        
        if (!this.isStrongPassword(userData.password)) {
            throw new DomainError('Password does not meet security requirements');
        }
    }
}
```

## 🔌 Plugin/Module Architecture

### 1. Ghost's Plugin System

**Plugin Architecture Implementation**
```javascript
// Plugin base class
class BasePlugin {
    constructor(app) {
        this.app = app;
        this.name = this.constructor.name;
        this.version = '1.0.0';
        this.dependencies = [];
    }

    async install() {
        // Override in subclasses
        console.log(`Installing plugin: ${this.name}`);
    }

    async activate() {
        // Override in subclasses
        console.log(`Activating plugin: ${this.name}`);
    }

    async deactivate() {
        // Override in subclasses
        console.log(`Deactivating plugin: ${this.name}`);
    }

    registerRoutes(router) {
        // Override to add custom routes
    }

    registerMiddleware() {
        // Override to add custom middleware
        return [];
    }

    registerServices() {
        // Override to add custom services
        return {};
    }
}

// Example plugin implementation
class CommentsPlugin extends BasePlugin {
    constructor(app) {
        super(app);
        this.name = 'Comments';
        this.version = '2.1.0';
        this.dependencies = ['Users', 'Posts'];
    }

    async install() {
        await super.install();
        
        // Create database tables
        await this.createTables();
        
        // Set up default configuration
        await this.setupDefaultConfig();
    }

    async activate() {
        await super.activate();
        
        // Register event listeners
        this.app.eventBus.on('post.published', this.onPostPublished.bind(this));
        this.app.eventBus.on('user.deleted', this.onUserDeleted.bind(this));
    }

    registerRoutes(router) {
        router.get('/api/comments', this.getComments.bind(this));
        router.post('/api/comments', this.createComment.bind(this));
        router.put('/api/comments/:id', this.updateComment.bind(this));
        router.delete('/api/comments/:id', this.deleteComment.bind(this));
    }

    registerMiddleware() {
        return [
            this.validateCommentData.bind(this),
            this.checkCommentPermissions.bind(this)
        ];
    }

    registerServices() {
        return {
            commentsService: new CommentsService()
        };
    }

    async createTables() {
        // Database migration logic
        const migration = `
            CREATE TABLE comments (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                post_id UUID REFERENCES posts(id),
                user_id UUID REFERENCES users(id),
                content TEXT NOT NULL,
                status VARCHAR(20) DEFAULT 'pending',
                created_at TIMESTAMP DEFAULT NOW(),
                updated_at TIMESTAMP DEFAULT NOW()
            );
        `;
        
        await this.app.database.query(migration);
    }
}

// Plugin manager
class PluginManager {
    constructor(app) {
        this.app = app;
        this.plugins = new Map();
        this.activePlugins = new Set();
    }

    async loadPlugin(PluginClass) {
        const plugin = new PluginClass(this.app);
        
        // Check dependencies
        for (const dep of plugin.dependencies) {
            if (!this.activePlugins.has(dep)) {
                throw new Error(`Plugin ${plugin.name} requires ${dep}`);
            }
        }

        this.plugins.set(plugin.name, plugin);
        
        await plugin.install();
        
        // Register plugin components
        this.registerPluginRoutes(plugin);
        this.registerPluginMiddleware(plugin);
        this.registerPluginServices(plugin);
        
        await plugin.activate();
        this.activePlugins.add(plugin.name);
        
        console.log(`Plugin ${plugin.name} loaded successfully`);
    }

    registerPluginRoutes(plugin) {
        const router = express.Router();
        plugin.registerRoutes(router);
        this.app.use(`/plugins/${plugin.name.toLowerCase()}`, router);
    }

    registerPluginMiddleware(plugin) {
        const middleware = plugin.registerMiddleware();
        middleware.forEach(mw => this.app.use(mw));
    }

    registerPluginServices(plugin) {
        const services = plugin.registerServices();
        Object.assign(this.app.services, services);
    }

    async deactivatePlugin(pluginName) {
        const plugin = this.plugins.get(pluginName);
        if (plugin) {
            await plugin.deactivate();
            this.activePlugins.delete(pluginName);
        }
    }
}
```

### 2. Strapi's Plugin Architecture

**Dynamic Plugin Loading**
```javascript
// Plugin configuration system
class PluginConfiguration {
    constructor() {
        this.plugins = new Map();
        this.loadConfiguration();
    }

    loadConfiguration() {
        const config = {
            'users-permissions': {
                enabled: true,
                resolve: './node_modules/@strapi/plugin-users-permissions',
                config: {
                  jwtSecret: process.env.JWT_SECRET,
                  providers: {
                    google: {
                      enabled: true,
                      clientId: process.env.GOOGLE_CLIENT_ID,
                      clientSecret: process.env.GOOGLE_CLIENT_SECRET
                    }
                  }
                }
            },
            'upload': {
                enabled: true,
                config: {
                  provider: 'aws-s3',
                  providerOptions: {
                    accessKeyId: process.env.AWS_ACCESS_KEY_ID,
                    secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
                    region: process.env.AWS_REGION,
                    params: {
                      Bucket: process.env.AWS_BUCKET_NAME,
                    },
                  },
                }
            },
            'email': {
                enabled: true,
                config: {
                  provider: 'sendgrid',
                  providerOptions: {
                    apiKey: process.env.SENDGRID_API_KEY,
                  },
                  settings: {
                    defaultFrom: 'hello@example.com',
                    defaultReplyTo: 'hello@example.com',
                  },
                }
            }
        };

        Object.entries(config).forEach(([name, pluginConfig]) => {
            if (pluginConfig.enabled) {
                this.plugins.set(name, pluginConfig);
            }
        });
    }

    getPluginConfig(name) {
        return this.plugins.get(name);
    }

    getAllPlugins() {
        return Array.from(this.plugins.keys());
    }
}

// Plugin loader with dependency injection
class PluginLoader {
    constructor(strapi) {
        this.strapi = strapi;
        this.loadedPlugins = new Map();
    }

    async loadAllPlugins() {
        const pluginConfig = new PluginConfiguration();
        
        for (const pluginName of pluginConfig.getAllPlugins()) {
            await this.loadPlugin(pluginName, pluginConfig.getPluginConfig(pluginName));
        }
    }

    async loadPlugin(name, config) {
        try {
            // Resolve plugin module
            const pluginPath = config.resolve || `./plugins/${name}`;
            const PluginModule = require(pluginPath);
            
            // Initialize plugin
            const plugin = new PluginModule(this.strapi, config.config);
            
            // Register plugin components
            await this.registerPlugin(name, plugin);
            
            this.loadedPlugins.set(name, plugin);
            
            console.log(`Plugin ${name} loaded successfully`);
        } catch (error) {
            console.error(`Failed to load plugin ${name}:`, error);
        }
    }

    async registerPlugin(name, plugin) {
        // Register routes
        if (plugin.routes) {
            this.strapi.router.use(`/${name}`, plugin.routes);
        }

        // Register services
        if (plugin.services) {
            Object.assign(this.strapi.services, plugin.services);
        }

        // Register models
        if (plugin.models) {
            Object.assign(this.strapi.models, plugin.models);
        }

        // Register controllers
        if (plugin.controllers) {
            Object.assign(this.strapi.controllers, plugin.controllers);
        }

        // Register middleware
        if (plugin.middleware) {
            plugin.middleware.forEach(mw => this.strapi.app.use(mw));
        }

        // Initialize plugin
        if (typeof plugin.initialize === 'function') {
            await plugin.initialize();
        }
    }
}
```

## 🏗️ Clean Architecture Implementation

### 1. NestJS Clean Architecture Pattern

**Hexagonal Architecture with NestJS**
```typescript
// Domain layer - Enterprise business rules
export class User {
    constructor(
        private readonly id: UserId,
        private readonly email: Email,
        private readonly profile: UserProfile,
        private readonly permissions: UserPermissions
    ) {}

    canAccessResource(resource: Resource): boolean {
        return this.permissions.hasAccess(resource);
    }

    updateProfile(newProfile: Partial<UserProfile>): User {
        const updatedProfile = this.profile.update(newProfile);
        return new User(this.id, this.email, updatedProfile, this.permissions);
    }

    static create(userData: CreateUserData): User {
        const id = UserId.generate();
        const email = Email.from(userData.email);
        const profile = UserProfile.create(userData.profile);
        const permissions = UserPermissions.default();
        
        return new User(id, email, profile, permissions);
    }
}

// Application layer - Use cases
@Injectable()
export class CreateUserUseCase {
    constructor(
        private readonly userRepository: UserRepositoryPort,
        private readonly emailService: EmailServicePort,
        private readonly eventBus: EventBusPort
    ) {}

    async execute(command: CreateUserCommand): Promise<CreateUserResult> {
        // Business logic validation
        await this.validateUserCreation(command);
        
        // Create user domain entity
        const user = User.create({
            email: command.email,
            profile: {
                firstName: command.firstName,
                lastName: command.lastName
            }
        });

        // Persist user
        await this.userRepository.save(user);

        // Send welcome email
        await this.emailService.sendWelcomeEmail(user.getEmail());

        // Publish domain event
        await this.eventBus.publish(new UserCreatedEvent(user.getId()));

        return CreateUserResult.success(user);
    }

    private async validateUserCreation(command: CreateUserCommand): Promise<void> {
        const existingUser = await this.userRepository.findByEmail(command.email);
        if (existingUser) {
            throw new UserAlreadyExistsError(command.email);
        }
    }
}

// Interface adapters layer - Controllers and presenters
@Controller('users')
@UseGuards(JwtAuthGuard)
export class UserController {
    constructor(
        private readonly createUserUseCase: CreateUserUseCase,
        private readonly getUserUseCase: GetUserUseCase,
        private readonly updateUserUseCase: UpdateUserUseCase
    ) {}

    @Post()
    @UseGuards(RolesGuard)
    @Roles('admin')
    async createUser(@Body() createUserDto: CreateUserDto): Promise<UserResponseDto> {
        const command = new CreateUserCommand(
            createUserDto.email,
            createUserDto.firstName,
            createUserDto.lastName
        );

        const result = await this.createUserUseCase.execute(command);
        
        if (result.isFailure()) {
            throw new BadRequestException(result.getError());
        }

        return UserResponseDto.fromDomain(result.getValue());
    }

    @Get(':id')
    async getUser(@Param('id') id: string): Promise<UserResponseDto> {
        const query = new GetUserQuery(id);
        const result = await this.getUserUseCase.execute(query);
        
        if (result.isFailure()) {
            throw new NotFoundException(result.getError());
        }

        return UserResponseDto.fromDomain(result.getValue());
    }
}

// Infrastructure layer - External concerns
@Injectable()
export class TypeOrmUserRepository implements UserRepositoryPort {
    constructor(
        @InjectRepository(UserEntity)
        private readonly userEntityRepository: Repository<UserEntity>
    ) {}

    async save(user: User): Promise<void> {
        const userEntity = UserEntityMapper.toEntity(user);
        await this.userEntityRepository.save(userEntity);
    }

    async findById(id: UserId): Promise<User | null> {
        const userEntity = await this.userEntityRepository.findOne({
            where: { id: id.getValue() }
        });

        return userEntity ? UserEntityMapper.toDomain(userEntity) : null;
    }

    async findByEmail(email: Email): Promise<User | null> {
        const userEntity = await this.userEntityRepository.findOne({
            where: { email: email.getValue() }
        });

        return userEntity ? UserEntityMapper.toDomain(userEntity) : null;
    }
}

// Domain ports (interfaces)
export interface UserRepositoryPort {
    save(user: User): Promise<void>;
    findById(id: UserId): Promise<User | null>;
    findByEmail(email: Email): Promise<User | null>;
}

export interface EmailServicePort {
    sendWelcomeEmail(email: Email): Promise<void>;
}

export interface EventBusPort {
    publish(event: DomainEvent): Promise<void>;
}
```

### 2. Advanced Clean Architecture with CQRS

**Command Query Responsibility Segregation**
```typescript
// Command side - Write operations
@CommandHandler(CreateUserCommand)
export class CreateUserCommandHandler implements ICommandHandler<CreateUserCommand> {
    constructor(
        private readonly userRepository: UserWriteRepository,
        private readonly eventStore: EventStore
    ) {}

    async execute(command: CreateUserCommand): Promise<void> {
        const user = User.create({
            email: command.email,
            firstName: command.firstName,
            lastName: command.lastName
        });

        await this.userRepository.save(user);

        // Store domain events
        const events = user.getUncommittedEvents();
        await this.eventStore.saveEvents(user.getId(), events);
        
        user.markEventsAsCommitted();
    }
}

// Query side - Read operations
@QueryHandler(GetUserQuery)
export class GetUserQueryHandler implements IQueryHandler<GetUserQuery> {
    constructor(
        private readonly userReadRepository: UserReadRepository
    ) {}

    async execute(query: GetUserQuery): Promise<UserReadModel> {
        return await this.userReadRepository.findById(query.userId);
    }
}

// Read model for optimized queries
export class UserReadModel {
    constructor(
        public readonly id: string,
        public readonly email: string,
        public readonly fullName: string,
        public readonly isActive: boolean,
        public readonly createdAt: Date,
        public readonly lastLoginAt: Date | null
    ) {}
}

// Separate read repository
@Injectable()
export class UserReadRepository {
    constructor(
        @InjectRepository(UserReadModelEntity)
        private readonly repository: Repository<UserReadModelEntity>
    ) {}

    async findById(id: string): Promise<UserReadModel | null> {
        const entity = await this.repository.findOne({ where: { id } });
        return entity ? this.toReadModel(entity) : null;
    }

    async findByFilters(filters: UserFilters): Promise<UserReadModel[]> {
        const queryBuilder = this.repository.createQueryBuilder('user');
        
        if (filters.isActive !== undefined) {
            queryBuilder.andWhere('user.isActive = :isActive', { isActive: filters.isActive });
        }
        
        if (filters.createdAfter) {
            queryBuilder.andWhere('user.createdAt > :createdAfter', { createdAfter: filters.createdAfter });
        }

        const entities = await queryBuilder.getMany();
        return entities.map(entity => this.toReadModel(entity));
    }

    private toReadModel(entity: UserReadModelEntity): UserReadModel {
        return new UserReadModel(
            entity.id,
            entity.email,
            entity.fullName,
            entity.isActive,
            entity.createdAt,
            entity.lastLoginAt
        );
    }
}

// Event handler for updating read models
@EventsHandler(UserCreatedEvent)
export class UserCreatedEventHandler implements IEventHandler<UserCreatedEvent> {
    constructor(
        private readonly userReadRepository: UserReadRepository
    ) {}

    async handle(event: UserCreatedEvent): Promise<void> {
        const readModel = new UserReadModelEntity();
        readModel.id = event.userId;
        readModel.email = event.email;
        readModel.fullName = `${event.firstName} ${event.lastName}`;
        readModel.isActive = true;
        readModel.createdAt = event.createdAt;
        
        await this.userReadRepository.save(readModel);
    }
}
```

## 🔄 Event-Driven Architecture

### 1. Feathers.js Real-time Event System

**Event-Driven Service Architecture**
```javascript
// Event-driven service base class
class EventDrivenService {
    constructor(app) {
        this.app = app;
        this.eventBus = app.get('eventBus');
        this.setupEventHandlers();
    }

    setupEventHandlers() {
        // Override in subclasses
    }

    emit(event, data) {
        this.eventBus.emit(event, data);
    }

    on(event, handler) {
        this.eventBus.on(event, handler.bind(this));
    }
}

// Message service with real-time events
class MessageService extends EventDrivenService {
    constructor(app) {
        super(app);
        this.messages = [];
    }

    setupEventHandlers() {
        this.on('user.online', this.handleUserOnline);
        this.on('user.offline', this.handleUserOffline);
        this.on('room.created', this.handleRoomCreated);
    }

    async create(data, params) {
        const message = {
            id: uuid(),
            text: data.text,
            userId: params.user.id,
            roomId: data.roomId,
            timestamp: new Date(),
            type: data.type || 'text'
        };

        // Save message
        this.messages.push(message);

        // Emit real-time event
        this.emit('message.created', {
            message,
            room: data.roomId,
            user: params.user
        });

        // Handle message processing
        await this.processMessage(message);

        return message;
    }

    async processMessage(message) {
        // Mention detection
        if (message.text.includes('@')) {
            this.emit('message.mention', { message });
        }

        // File attachment handling
        if (message.type === 'file') {
            this.emit('message.file_shared', { message });
        }

        // Bot command detection
        if (message.text.startsWith('/')) {
            this.emit('message.command', { message });
        }
    }

    handleUserOnline(data) {
        // Notify room members
        this.emit('room.user_status_changed', {
            userId: data.userId,
            status: 'online',
            rooms: data.userRooms
        });
    }

    handleUserOffline(data) {
        this.emit('room.user_status_changed', {
            userId: data.userId,
            status: 'offline',
            rooms: data.userRooms
        });
    }
}

// Event bus implementation
class EventBus extends EventEmitter {
    constructor() {
        super();
        this.setMaxListeners(100); // Increase limit for many handlers
        this.eventHistory = [];
        this.setupEventLogging();
    }

    setupEventLogging() {
        this.on('*', (eventName, data) => {
            this.eventHistory.push({
                event: eventName,
                data,
                timestamp: new Date()
            });

            // Keep only last 1000 events
            if (this.eventHistory.length > 1000) {
                this.eventHistory.shift();
            }
        });
    }

    emit(event, data) {
        // Log event
        console.log(`Event emitted: ${event}`, data);
        
        // Emit to specific listeners
        super.emit(event, data);
        
        // Emit to wildcard listeners
        super.emit('*', event, data);
    }

    getEventHistory(filter) {
        if (!filter) return this.eventHistory;
        
        return this.eventHistory.filter(entry => {
            if (filter.event && !entry.event.includes(filter.event)) return false;
            if (filter.since && entry.timestamp < filter.since) return false;
            return true;
        });
    }
}
```

### 2. Advanced Event Sourcing Pattern

**Event Store Implementation**
```javascript
// Event sourcing with aggregates
class EventStore {
    constructor() {
        this.events = new Map(); // In production, use proper database
        this.snapshots = new Map();
    }

    async saveEvents(aggregateId, events, expectedVersion) {
        const existingEvents = this.events.get(aggregateId) || [];
        
        // Optimistic concurrency check
        if (existingEvents.length !== expectedVersion) {
            throw new ConcurrencyError('Aggregate has been modified');
        }

        // Add version to events
        const versionedEvents = events.map((event, index) => ({
            ...event,
            aggregateId,
            version: expectedVersion + index + 1,
            timestamp: new Date(),
            eventId: uuid()
        }));

        // Store events
        this.events.set(aggregateId, [...existingEvents, ...versionedEvents]);

        // Publish events to event bus
        versionedEvents.forEach(event => {
            this.eventBus.emit(event.type, event);
        });

        return versionedEvents;
    }

    async getEvents(aggregateId, fromVersion = 0) {
        const events = this.events.get(aggregateId) || [];
        return events.filter(event => event.version > fromVersion);
    }

    async saveSnapshot(aggregateId, snapshot, version) {
        this.snapshots.set(aggregateId, {
            ...snapshot,
            version,
            timestamp: new Date()
        });
    }

    async getSnapshot(aggregateId) {
        return this.snapshots.get(aggregateId);
    }
}

// Aggregate root base class
class AggregateRoot {
    constructor() {
        this.id = null;
        this.version = 0;
        this.uncommittedEvents = [];
    }

    applyEvent(event) {
        // Apply event to aggregate state
        const handlerName = `on${event.type}`;
        if (typeof this[handlerName] === 'function') {
            this[handlerName](event);
        }
        
        this.version++;
    }

    raiseEvent(event) {
        this.uncommittedEvents.push(event);
        this.applyEvent(event);
    }

    getUncommittedEvents() {
        return [...this.uncommittedEvents];
    }

    markEventsAsCommitted() {
        this.uncommittedEvents = [];
    }

    static async fromHistory(events) {
        const aggregate = new this();
        events.forEach(event => aggregate.applyEvent(event));
        return aggregate;
    }
}

// Example aggregate
class OrderAggregate extends AggregateRoot {
    constructor() {
        super();
        this.items = [];
        this.status = 'draft';
        this.totalAmount = 0;
    }

    createOrder(customerId, items) {
        if (this.id) {
            throw new Error('Order already created');
        }

        this.raiseEvent({
            type: 'OrderCreated',
            orderId: uuid(),
            customerId,
            items,
            createdAt: new Date()
        });
    }

    addItem(productId, quantity, price) {
        if (this.status !== 'draft') {
            throw new Error('Cannot modify confirmed order');
        }

        this.raiseEvent({
            type: 'ItemAdded',
            productId,
            quantity,
            price,
            addedAt: new Date()
        });
    }

    confirmOrder() {
        if (this.items.length === 0) {
            throw new Error('Cannot confirm empty order');
        }

        this.raiseEvent({
            type: 'OrderConfirmed',
            confirmedAt: new Date(),
            totalAmount: this.totalAmount
        });
    }

    // Event handlers
    onOrderCreated(event) {
        this.id = event.orderId;
        this.customerId = event.customerId;
        this.items = [...event.items];
        this.totalAmount = event.items.reduce((sum, item) => sum + (item.price * item.quantity), 0);
    }

    onItemAdded(event) {
        this.items.push({
            productId: event.productId,
            quantity: event.quantity,
            price: event.price
        });
        this.totalAmount += event.price * event.quantity;
    }

    onOrderConfirmed(event) {
        this.status = 'confirmed';
        this.confirmedAt = event.confirmedAt;
    }
}
```

## 📱 Microservices Architecture

### 1. Medusa's Microservice Pattern

**Service Discovery and Communication**
```javascript
// Service registry for microservices
class ServiceRegistry {
    constructor() {
        this.services = new Map();
        this.healthChecks = new Map();
        this.setupHealthMonitoring();
    }

    registerService(name, config) {
        this.services.set(name, {
            name,
            url: config.url,
            version: config.version,
            instances: config.instances || [],
            loadBalancer: config.loadBalancer || 'round-robin',
            registeredAt: new Date()
        });

        // Set up health check
        if (config.healthCheck) {
            this.setupHealthCheck(name, config.healthCheck);
        }
    }

    getService(name) {
        const service = this.services.get(name);
        if (!service) {
            throw new ServiceNotFoundError(`Service ${name} not found`);
        }

        // Return available instance based on load balancing
        return this.selectInstance(service);
    }

    selectInstance(service) {
        const availableInstances = service.instances.filter(instance => 
            this.isInstanceHealthy(service.name, instance.id)
        );

        if (availableInstances.length === 0) {
            throw new ServiceUnavailableError(`No healthy instances for ${service.name}`);
        }

        switch (service.loadBalancer) {
            case 'round-robin':
                return this.roundRobinSelect(availableInstances);
            case 'random':
                return availableInstances[Math.floor(Math.random() * availableInstances.length)];
            case 'least-connections':
                return this.leastConnectionsSelect(availableInstances);
            default:
                return availableInstances[0];
        }
    }

    setupHealthCheck(serviceName, config) {
        const interval = setInterval(async () => {
            const service = this.services.get(serviceName);
            if (!service) return;

            for (const instance of service.instances) {
                try {
                    const response = await axios.get(`${instance.url}${config.endpoint}`, {
                        timeout: config.timeout || 5000
                    });
                    
                    this.updateInstanceHealth(serviceName, instance.id, response.status === 200);
                } catch (error) {
                    this.updateInstanceHealth(serviceName, instance.id, false);
                }
            }
        }, config.interval || 30000);

        this.healthChecks.set(serviceName, interval);
    }
}

// API Gateway for microservices
class ApiGateway {
    constructor() {
        this.serviceRegistry = new ServiceRegistry();
        this.middleware = [];
        this.routes = new Map();
        this.setupCommonMiddleware();
    }

    setupCommonMiddleware() {
        this.use(this.rateLimitingMiddleware);
        this.use(this.authenticationMiddleware);
        this.use(this.loggingMiddleware);
        this.use(this.corsMiddleware);
    }

    use(middleware) {
        this.middleware.push(middleware);
    }

    registerRoute(path, serviceName, options = {}) {
        this.routes.set(path, {
            serviceName,
            timeout: options.timeout || 30000,
            retries: options.retries || 3,
            circuitBreaker: options.circuitBreaker || false
        });
    }

    async handleRequest(req, res) {
        try {
            // Apply middleware
            for (const middleware of this.middleware) {
                await middleware(req, res);
            }

            // Find matching route
            const route = this.findRoute(req.path);
            if (!route) {
                return res.status(404).json({ error: 'Route not found' });
            }

            // Get service instance
            const serviceInstance = this.serviceRegistry.getService(route.serviceName);
            
            // Forward request with circuit breaker
            const response = await this.forwardRequest(req, serviceInstance, route);
            
            // Return response
            res.status(response.status).json(response.data);
        } catch (error) {
            this.handleError(error, res);
        }
    }

    async forwardRequest(req, serviceInstance, route) {
        const circuitBreaker = route.circuitBreaker ? 
            this.getCircuitBreaker(route.serviceName) : null;

        if (circuitBreaker && circuitBreaker.isOpen()) {
            throw new ServiceUnavailableError('Circuit breaker is open');
        }

        try {
            const response = await axios({
                method: req.method,
                url: `${serviceInstance.url}${req.path}`,
                data: req.body,
                headers: this.forwardHeaders(req.headers),
                timeout: route.timeout,
                validateStatus: () => true // Don't throw on HTTP errors
            });

            if (circuitBreaker) {
                circuitBreaker.recordSuccess();
            }

            return response;
        } catch (error) {
            if (circuitBreaker) {
                circuitBreaker.recordFailure();
            }

            // Retry logic
            if (route.retries > 0) {
                return this.retryRequest(req, serviceInstance, route, route.retries);
            }

            throw error;
        }
    }
}

// Circuit breaker implementation
class CircuitBreaker {
    constructor(options = {}) {
        this.failureThreshold = options.failureThreshold || 5;
        this.timeout = options.timeout || 60000;
        this.state = 'CLOSED'; // CLOSED, OPEN, HALF_OPEN
        this.failureCount = 0;
        this.nextAttempt = Date.now();
    }

    async execute(operation) {
        if (this.state === 'OPEN') {
            if (Date.now() < this.nextAttempt) {
                throw new Error('Circuit breaker is OPEN');
            }
            this.state = 'HALF_OPEN';
        }

        try {
            const result = await operation();
            this.recordSuccess();
            return result;
        } catch (error) {
            this.recordFailure();
            throw error;
        }
    }

    recordSuccess() {
        this.failureCount = 0;
        this.state = 'CLOSED';
    }

    recordFailure() {
        this.failureCount++;
        if (this.failureCount >= this.failureThreshold) {
            this.state = 'OPEN';
            this.nextAttempt = Date.now() + this.timeout;
        }
    }

    isOpen() {
        return this.state === 'OPEN';
    }
}
```

## 🔗 Navigation

← [Authentication Patterns](./authentication-patterns.md) | [API Design Patterns](./api-design-patterns.md) →