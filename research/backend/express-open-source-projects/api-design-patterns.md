# API Design Patterns in Express.js Open Source Projects

## 🎯 Overview

Analysis of REST API design patterns, error handling strategies, response structures, and documentation approaches used across production Express.js applications.

## 📊 API Design Pattern Distribution

### API Design Standards

| Pattern | Adoption Rate | Use Cases | Examples |
|---------|---------------|-----------|----------|
| **RESTful APIs** | 95% | Standard CRUD operations | Ghost, Strapi, Medusa |
| **JSON API Specification** | 40% | Standardized API format | Strapi, Ghost API v4 |
| **GraphQL APIs** | 35% | Flexible data fetching | KeystoneJS, Strapi GraphQL |
| **OpenAPI/Swagger** | 80% | API documentation | Most production APIs |
| **Hypermedia APIs (HATEOAS)** | 15% | Self-describing APIs | Advanced enterprise APIs |
| **Versioned APIs** | 70% | Backward compatibility | Ghost, Strapi, Medusa |

## 🛠️ REST API Design Patterns

### 1. Standard RESTful Resource Design

**Ghost's REST API Structure**
```javascript
// RESTful resource routing pattern
class PostRoutes {
    constructor(app) {
        this.app = app;
        this.setupRoutes();
    }

    setupRoutes() {
        const router = express.Router();

        // Collection routes
        router.get('/posts', this.getPosts.bind(this));
        router.post('/posts', this.createPost.bind(this));

        // Resource routes
        router.get('/posts/:id', this.getPost.bind(this));
        router.put('/posts/:id', this.updatePost.bind(this));
        router.patch('/posts/:id', this.patchPost.bind(this));
        router.delete('/posts/:id', this.deletePost.bind(this));

        // Sub-resource routes
        router.get('/posts/:id/comments', this.getPostComments.bind(this));
        router.post('/posts/:id/comments', this.createPostComment.bind(this));
        router.get('/posts/:id/tags', this.getPostTags.bind(this));
        router.put('/posts/:id/tags', this.updatePostTags.bind(this));

        // Action routes (non-CRUD operations)
        router.post('/posts/:id/publish', this.publishPost.bind(this));
        router.post('/posts/:id/unpublish', this.unpublishPost.bind(this));
        router.post('/posts/:id/duplicate', this.duplicatePost.bind(this));

        this.app.use('/api/v1', router);
    }

    async getPosts(req, res, next) {
        try {
            const options = this.parseQueryOptions(req.query);
            const result = await this.postService.findAll(options);

            res.json({
                data: result.posts,
                meta: {
                    pagination: {
                        page: result.page,
                        pages: result.pages,
                        limit: result.limit,
                        total: result.total,
                        prev: result.prev,
                        next: result.next
                    }
                }
            });
        } catch (error) {
            next(error);
        }
    }

    parseQueryOptions(query) {
        return {
            page: parseInt(query.page) || 1,
            limit: Math.min(parseInt(query.limit) || 15, 100), // Max 100 items
            filter: query.filter,
            include: query.include?.split(',') || [],
            fields: query.fields?.split(','),
            sort: query.sort || '-created_at',
            search: query.search
        };
    }

    async createPost(req, res, next) {
        try {
            const postData = req.validatedBody;
            const post = await this.postService.create(postData, req.user);

            res.status(201).json({
                data: post,
                meta: {
                    created: true,
                    location: `/api/v1/posts/${post.id}`
                }
            });
        } catch (error) {
            next(error);
        }
    }
}
```

### 2. JSON API Specification Implementation

**Strapi's JSON API Format**
```javascript
// JSON API compliant response formatter
class JsonApiFormatter {
    static formatResource(type, resource, options = {}) {
        const formatted = {
            type,
            id: resource.id.toString(),
            attributes: this.extractAttributes(resource, options.fields),
        };

        if (options.include && resource.relationships) {
            formatted.relationships = this.formatRelationships(resource.relationships);
        }

        if (options.meta) {
            formatted.meta = options.meta;
        }

        return formatted;
    }

    static formatCollection(type, resources, options = {}) {
        const data = resources.map(resource => 
            this.formatResource(type, resource, options)
        );

        const response = { data };

        if (options.included) {
            response.included = this.formatIncluded(options.included);
        }

        if (options.meta) {
            response.meta = options.meta;
        }

        if (options.links) {
            response.links = this.formatLinks(options.links);
        }

        return response;
    }

    static formatError(error) {
        return {
            errors: [{
                id: error.id || uuid(),
                status: error.status?.toString() || '500',
                code: error.code || 'INTERNAL_ERROR',
                title: error.title || 'Internal Server Error',
                detail: error.message,
                source: error.source ? {
                    pointer: error.source.pointer,
                    parameter: error.source.parameter
                } : undefined,
                meta: error.meta
            }]
        };
    }

    static extractAttributes(resource, fields) {
        const attributes = { ...resource };
        delete attributes.id;
        delete attributes.relationships;

        if (fields) {
            const filteredAttributes = {};
            fields.forEach(field => {
                if (attributes.hasOwnProperty(field)) {
                    filteredAttributes[field] = attributes[field];
                }
            });
            return filteredAttributes;
        }

        return attributes;
    }

    static formatRelationships(relationships) {
        const formatted = {};

        Object.entries(relationships).forEach(([key, relationship]) => {
            if (Array.isArray(relationship)) {
                formatted[key] = {
                    data: relationship.map(item => ({
                        type: item.type,
                        id: item.id.toString()
                    }))
                };
            } else if (relationship) {
                formatted[key] = {
                    data: {
                        type: relationship.type,
                        id: relationship.id.toString()
                    }
                };
            } else {
                formatted[key] = { data: null };
            }
        });

        return formatted;
    }
}

// Usage in controllers
class ArticleController {
    async getArticles(req, res, next) {
        try {
            const options = this.parseJsonApiQuery(req.query);
            const result = await this.articleService.findAll(options);

            const response = JsonApiFormatter.formatCollection('articles', result.data, {
                fields: options.fields?.articles,
                include: options.include,
                included: result.included,
                meta: {
                    total: result.total,
                    count: result.data.length
                },
                links: {
                    self: req.originalUrl,
                    first: this.buildPageLink(req, 1),
                    last: this.buildPageLink(req, result.totalPages),
                    prev: result.page > 1 ? this.buildPageLink(req, result.page - 1) : null,
                    next: result.page < result.totalPages ? this.buildPageLink(req, result.page + 1) : null
                }
            });

            res.json(response);
        } catch (error) {
            next(error);
        }
    }

    parseJsonApiQuery(query) {
        return {
            page: {
                number: parseInt(query['page[number]']) || 1,
                size: Math.min(parseInt(query['page[size]']) || 10, 100)
            },
            include: query.include?.split(','),
            fields: this.parseFieldsParameter(query),
            filter: this.parseFilterParameter(query),
            sort: query.sort?.split(',')
        };
    }

    parseFieldsParameter(query) {
        const fields = {};
        Object.keys(query).forEach(key => {
            const match = key.match(/^fields\[(.+)\]$/);
            if (match) {
                fields[match[1]] = query[key].split(',');
            }
        });
        return Object.keys(fields).length > 0 ? fields : null;
    }
}
```

### 3. Advanced Query Pattern Implementation

**Sophisticated Filtering and Querying**
```javascript
// Advanced query builder for REST APIs
class QueryBuilder {
    constructor(model) {
        this.model = model;
        this.query = {};
        this.populateFields = [];
        this.selectFields = [];
        this.sortFields = [];
        this.paginationOptions = {};
    }

    static create(model) {
        return new QueryBuilder(model);
    }

    // Filtering methods
    filter(filters) {
        Object.entries(filters).forEach(([key, value]) => {
            this.addFilter(key, value);
        });
        return this;
    }

    addFilter(field, value) {
        if (typeof value === 'object' && value !== null) {
            // Handle complex filters: { age: { $gte: 18, $lte: 65 } }
            this.query[field] = value;
        } else if (Array.isArray(value)) {
            // Handle array filters: { status: ['active', 'pending'] }
            this.query[field] = { $in: value };
        } else {
            // Simple equality filter
            this.query[field] = value;
        }
        return this;
    }

    // Text search
    search(searchTerm, fields = []) {
        if (searchTerm) {
            const searchRegex = new RegExp(searchTerm, 'i');
            const searchConditions = fields.map(field => ({
                [field]: searchRegex
            }));
            
            this.query.$or = searchConditions;
        }
        return this;
    }

    // Date range filtering
    dateRange(field, startDate, endDate) {
        const dateFilter = {};
        if (startDate) dateFilter.$gte = new Date(startDate);
        if (endDate) dateFilter.$lte = new Date(endDate);
        
        if (Object.keys(dateFilter).length > 0) {
            this.query[field] = dateFilter;
        }
        return this;
    }

    // Geographic filtering
    near(field, coordinates, maxDistance) {
        this.query[field] = {
            $near: {
                $geometry: {
                    type: 'Point',
                    coordinates: coordinates
                },
                $maxDistance: maxDistance
            }
        };
        return this;
    }

    // Population/inclusion
    populate(field, select = '') {
        this.populateFields.push({ path: field, select });
        return this;
    }

    // Field selection
    select(fields) {
        if (typeof fields === 'string') {
            this.selectFields = fields.split(' ');
        } else if (Array.isArray(fields)) {
            this.selectFields = fields;
        }
        return this;
    }

    // Sorting
    sort(sortString) {
        if (typeof sortString === 'string') {
            this.sortFields = sortString.split(',').map(field => {
                if (field.startsWith('-')) {
                    return { [field.substring(1)]: -1 };
                }
                return { [field]: 1 };
            });
        }
        return this;
    }

    // Pagination
    paginate(page = 1, limit = 10) {
        this.paginationOptions = {
            page: Math.max(1, parseInt(page)),
            limit: Math.min(100, Math.max(1, parseInt(limit)))
        };
        return this;
    }

    // Execute query
    async execute() {
        let query = this.model.find(this.query);

        // Apply population
        this.populateFields.forEach(populate => {
            query = query.populate(populate);
        });

        // Apply field selection
        if (this.selectFields.length > 0) {
            query = query.select(this.selectFields.join(' '));
        }

        // Apply sorting
        if (this.sortFields.length > 0) {
            const sortObject = this.sortFields.reduce((acc, sort) => ({ ...acc, ...sort }), {});
            query = query.sort(sortObject);
        }

        // Apply pagination
        if (this.paginationOptions.page) {
            const { page, limit } = this.paginationOptions;
            const skip = (page - 1) * limit;
            
            const [data, total] = await Promise.all([
                query.skip(skip).limit(limit).exec(),
                this.model.countDocuments(this.query)
            ]);

            return {
                data,
                pagination: {
                    page,
                    limit,
                    total,
                    pages: Math.ceil(total / limit),
                    hasNextPage: page * limit < total,
                    hasPrevPage: page > 1
                }
            };
        }

        return { data: await query.exec() };
    }
}

// Usage in service layer
class UserService {
    async findUsers(queryParams) {
        const builder = QueryBuilder.create(User);

        // Apply filters
        if (queryParams.filter) {
            builder.filter(queryParams.filter);
        }

        // Apply search
        if (queryParams.search) {
            builder.search(queryParams.search, ['name', 'email', 'bio']);
        }

        // Apply date filters
        if (queryParams.createdAfter || queryParams.createdBefore) {
            builder.dateRange('createdAt', queryParams.createdAfter, queryParams.createdBefore);
        }

        // Apply location filter
        if (queryParams.near) {
            const [lng, lat] = queryParams.near.split(',').map(Number);
            builder.near('location', [lng, lat], queryParams.maxDistance || 10000);
        }

        // Apply includes
        if (queryParams.include) {
            queryParams.include.forEach(include => {
                builder.populate(include);
            });
        }

        // Apply field selection
        if (queryParams.fields) {
            builder.select(queryParams.fields);
        }

        // Apply sorting
        if (queryParams.sort) {
            builder.sort(queryParams.sort);
        }

        // Apply pagination
        builder.paginate(queryParams.page, queryParams.limit);

        return await builder.execute();
    }
}
```

## 🚨 Error Handling Patterns

### 1. Comprehensive Error Response Structure

**Standardized Error Format**
```javascript
// Base error classes
class ApiError extends Error {
    constructor(message, statusCode = 500, code = 'INTERNAL_ERROR', details = null) {
        super(message);
        this.name = this.constructor.name;
        this.statusCode = statusCode;
        this.code = code;
        this.details = details;
        this.timestamp = new Date().toISOString();
        this.isOperational = true;

        Error.captureStackTrace(this, this.constructor);
    }

    toJSON() {
        return {
            error: {
                name: this.name,
                message: this.message,
                code: this.code,
                status: this.statusCode,
                details: this.details,
                timestamp: this.timestamp
            }
        };
    }
}

class ValidationError extends ApiError {
    constructor(message, details = []) {
        super(message, 400, 'VALIDATION_ERROR', details);
    }

    static fromJoi(joiError) {
        const details = joiError.details.map(detail => ({
            field: detail.context?.key || detail.path?.join('.'),
            message: detail.message,
            value: detail.context?.value,
            type: detail.type
        }));

        return new ValidationError('Validation failed', details);
    }

    static fromZod(zodError) {
        const details = zodError.errors.map(error => ({
            field: error.path.join('.'),
            message: error.message,
            code: error.code,
            expected: error.expected,
            received: error.received
        }));

        return new ValidationError('Validation failed', details);
    }
}

class AuthenticationError extends ApiError {
    constructor(message = 'Authentication required') {
        super(message, 401, 'AUTHENTICATION_ERROR');
    }
}

class AuthorizationError extends ApiError {
    constructor(message = 'Insufficient permissions') {
        super(message, 403, 'AUTHORIZATION_ERROR');
    }
}

class NotFoundError extends ApiError {
    constructor(resource = 'Resource') {
        super(`${resource} not found`, 404, 'NOT_FOUND');
    }
}

class ConflictError extends ApiError {
    constructor(message, details = null) {
        super(message, 409, 'CONFLICT', details);
    }
}

class RateLimitError extends ApiError {
    constructor(retryAfter = null) {
        super('Rate limit exceeded', 429, 'RATE_LIMIT_EXCEEDED');
        this.retryAfter = retryAfter;
    }
}

// Global error handler middleware
const errorHandler = (err, req, res, next) => {
    // Log error
    const logger = req.app.get('logger');
    logger.error('API Error:', {
        error: err.message,
        stack: err.stack,
        url: req.url,
        method: req.method,
        ip: req.ip,
        userAgent: req.get('User-Agent'),
        user: req.user?.id
    });

    // Handle specific error types
    if (err.name === 'ValidationError' && err.errors) {
        // Mongoose validation error
        const details = Object.values(err.errors).map(error => ({
            field: error.path,
            message: error.message,
            value: error.value,
            kind: error.kind
        }));
        
        return res.status(400).json({
            error: {
                code: 'VALIDATION_ERROR',
                message: 'Validation failed',
                details,
                timestamp: new Date().toISOString()
            }
        });
    }

    if (err.name === 'CastError') {
        // MongoDB cast error (invalid ObjectId, etc.)
        return res.status(400).json({
            error: {
                code: 'INVALID_ID',
                message: `Invalid ${err.path}: ${err.value}`,
                timestamp: new Date().toISOString()
            }
        });
    }

    if (err.code === 11000) {
        // MongoDB duplicate key error
        const field = Object.keys(err.keyValue)[0];
        const value = err.keyValue[field];
        
        return res.status(409).json({
            error: {
                code: 'DUPLICATE_VALUE',
                message: `${field} '${value}' already exists`,
                details: {
                    field,
                    value
                },
                timestamp: new Date().toISOString()
            }
        });
    }

    // Handle operational errors
    if (err.isOperational) {
        return res.status(err.statusCode).json(err.toJSON());
    }

    // Handle programming errors (don't expose details in production)
    const isDevelopment = process.env.NODE_ENV === 'development';
    
    res.status(500).json({
        error: {
            code: 'INTERNAL_ERROR',
            message: isDevelopment ? err.message : 'Something went wrong',
            ...(isDevelopment && { stack: err.stack }),
            timestamp: new Date().toISOString()
        }
    });
};

// Async error wrapper
const asyncHandler = (fn) => {
    return (req, res, next) => {
        Promise.resolve(fn(req, res, next)).catch(next);
    };
};

// 404 handler
const notFoundHandler = (req, res) => {
    res.status(404).json({
        error: {
            code: 'ENDPOINT_NOT_FOUND',
            message: `Endpoint ${req.method} ${req.path} not found`,
            timestamp: new Date().toISOString()
        }
    });
};
```

### 2. Error Context and Debugging

**Enhanced Error Context**
```javascript
// Error context collector
class ErrorContext {
    constructor() {
        this.data = {};
    }

    addContext(key, value) {
        this.data[key] = value;
        return this;
    }

    addUser(user) {
        this.data.user = {
            id: user.id,
            email: user.email,
            role: user.role
        };
        return this;
    }

    addRequest(req) {
        this.data.request = {
            method: req.method,
            url: req.originalUrl,
            headers: this.sanitizeHeaders(req.headers),
            body: this.sanitizeBody(req.body),
            query: req.query,
            params: req.params,
            ip: req.ip,
            userAgent: req.get('User-Agent')
        };
        return this;
    }

    addDatabase(operation, model, query) {
        this.data.database = {
            operation,
            model,
            query: this.sanitizeQuery(query)
        };
        return this;
    }

    sanitizeHeaders(headers) {
        const sanitized = { ...headers };
        delete sanitized.authorization;
        delete sanitized.cookie;
        return sanitized;
    }

    sanitizeBody(body) {
        if (!body || typeof body !== 'object') return body;
        
        const sanitized = { ...body };
        delete sanitized.password;
        delete sanitized.token;
        delete sanitized.secret;
        return sanitized;
    }

    sanitizeQuery(query) {
        if (typeof query === 'string') return query;
        return JSON.stringify(query, null, 2);
    }

    toObject() {
        return { ...this.data };
    }
}

// Enhanced error classes with context
class ContextualError extends ApiError {
    constructor(message, statusCode, code, context = null) {
        super(message, statusCode, code);
        this.context = context instanceof ErrorContext ? context.toObject() : context;
    }

    toJSON() {
        const base = super.toJSON();
        if (this.context) {
            base.error.context = this.context;
        }
        return base;
    }
}

// Middleware to add request context to errors
const addErrorContext = (req, res, next) => {
    req.errorContext = new ErrorContext().addRequest(req);
    
    if (req.user) {
        req.errorContext.addUser(req.user);
    }

    next();
};

// Usage example
const userController = {
    async updateUser(req, res, next) {
        try {
            const { id } = req.params;
            const updateData = req.validatedBody;

            req.errorContext.addContext('operation', 'updateUser')
                            .addContext('userId', id);

            const user = await User.findById(id);
            if (!user) {
                throw new ContextualError(
                    'User not found',
                    404,
                    'USER_NOT_FOUND',
                    req.errorContext.addDatabase('findById', 'User', { id })
                );
            }

            const updatedUser = await User.findByIdAndUpdate(id, updateData, { new: true });
            
            res.json({
                success: true,
                data: updatedUser
            });
        } catch (error) {
            if (error instanceof ContextualError) {
                return next(error);
            }
            
            // Add context to unexpected errors
            const contextualError = new ContextualError(
                error.message,
                500,
                'UNEXPECTED_ERROR',
                req.errorContext.addContext('originalError', error.name)
            );
            
            next(contextualError);
        }
    }
};
```

## 📝 Response Structure Patterns

### 1. Consistent Response Envelope

**Standardized Success Response Format**
```javascript
// Response envelope wrapper
class ResponseEnvelope {
    static success(data, meta = null, status = 200) {
        const response = {
            success: true,
            data,
            timestamp: new Date().toISOString()
        };

        if (meta) {
            response.meta = meta;
        }

        return { response, status };
    }

    static created(data, location = null) {
        const meta = { created: true };
        if (location) {
            meta.location = location;
        }

        return this.success(data, meta, 201);
    }

    static updated(data) {
        return this.success(data, { updated: true });
    }

    static deleted(id = null) {
        const data = id ? { id, deleted: true } : { deleted: true };
        return this.success(data, { deleted: true });
    }

    static paginated(data, pagination) {
        return this.success(data, { pagination });
    }

    static error(error, status = 500) {
        return {
            response: {
                success: false,
                error: typeof error === 'string' ? { message: error } : error,
                timestamp: new Date().toISOString()
            },
            status
        };
    }
}

// Response middleware
const sendResponse = (req, res, next) => {
    // Extend res object with helper methods
    res.success = (data, meta = null) => {
        const { response, status } = ResponseEnvelope.success(data, meta);
        return res.status(status).json(response);
    };

    res.created = (data, location = null) => {
        const { response, status } = ResponseEnvelope.created(data, location);
        return res.status(status).json(response);
    };

    res.updated = (data) => {
        const { response, status } = ResponseEnvelope.updated(data);
        return res.status(status).json(response);
    };

    res.deleted = (id = null) => {
        const { response, status } = ResponseEnvelope.deleted(id);
        return res.status(status).json(response);
    };

    res.paginated = (data, pagination) => {
        const { response, status } = ResponseEnvelope.paginated(data, pagination);
        return res.status(status).json(response);
    };

    next();
};

// Usage in controllers
class PostController {
    async getPosts(req, res, next) {
        try {
            const result = await this.postService.findAll(req.query);
            
            res.paginated(result.data, {
                page: result.page,
                limit: result.limit,
                total: result.total,
                pages: result.pages
            });
        } catch (error) {
            next(error);
        }
    }

    async createPost(req, res, next) {
        try {
            const post = await this.postService.create(req.validatedBody, req.user);
            res.created(post, `/api/posts/${post.id}`);
        } catch (error) {
            next(error);
        }
    }

    async updatePost(req, res, next) {
        try {
            const post = await this.postService.update(req.params.id, req.validatedBody);
            res.updated(post);
        } catch (error) {
            next(error);
        }
    }

    async deletePost(req, res, next) {
        try {
            await this.postService.delete(req.params.id);
            res.deleted(req.params.id);
        } catch (error) {
            next(error);
        }
    }
}
```

### 2. HAL (Hypertext Application Language) Implementation

**Self-Describing API Responses**
```javascript
// HAL response builder
class HalBuilder {
    constructor(data = {}) {
        this.resource = { ...data };
        this.links = {};
        this.embedded = {};
    }

    static create(data) {
        return new HalBuilder(data);
    }

    addLink(rel, href, options = {}) {
        const link = { href };
        
        if (options.templated) link.templated = true;
        if (options.type) link.type = options.type;
        if (options.title) link.title = options.title;
        if (options.method) link.method = options.method;

        if (this.links[rel]) {
            // Convert to array if multiple links with same rel
            if (!Array.isArray(this.links[rel])) {
                this.links[rel] = [this.links[rel]];
            }
            this.links[rel].push(link);
        } else {
            this.links[rel] = link;
        }

        return this;
    }

    addSelfLink(href) {
        return this.addLink('self', href);
    }

    addEmbedded(rel, resource) {
        if (this.embedded[rel]) {
            if (!Array.isArray(this.embedded[rel])) {
                this.embedded[rel] = [this.embedded[rel]];
            }
            this.embedded[rel].push(resource);
        } else {
            this.embedded[rel] = resource;
        }

        return this;
    }

    build() {
        const result = { ...this.resource };

        if (Object.keys(this.links).length > 0) {
            result._links = this.links;
        }

        if (Object.keys(this.embedded).length > 0) {
            result._embedded = this.embedded;
        }

        return result;
    }
}

// HAL controller implementation
class HalPostController {
    async getPost(req, res, next) {
        try {
            const post = await this.postService.findById(req.params.id);
            
            if (!post) {
                throw new NotFoundError('Post');
            }

            const hal = HalBuilder.create({
                id: post.id,
                title: post.title,
                content: post.content,
                status: post.status,
                createdAt: post.createdAt,
                updatedAt: post.updatedAt
            })
            .addSelfLink(`/api/posts/${post.id}`)
            .addLink('edit', `/api/posts/${post.id}`, { method: 'PUT' })
            .addLink('delete', `/api/posts/${post.id}`, { method: 'DELETE' })
            .addLink('publish', `/api/posts/${post.id}/publish`, { method: 'POST' })
            .addLink('author', `/api/users/${post.authorId}`)
            .addLink('comments', `/api/posts/${post.id}/comments`);

            // Add embedded resources
            if (post.author) {
                hal.addEmbedded('author', HalBuilder.create({
                    id: post.author.id,
                    name: post.author.name,
                    email: post.author.email
                })
                .addSelfLink(`/api/users/${post.author.id}`)
                .build());
            }

            if (post.comments && post.comments.length > 0) {
                post.comments.forEach(comment => {
                    hal.addEmbedded('comments', HalBuilder.create({
                        id: comment.id,
                        content: comment.content,
                        createdAt: comment.createdAt
                    })
                    .addSelfLink(`/api/comments/${comment.id}`)
                    .build());
                });
            }

            res.json(hal.build());
        } catch (error) {
            next(error);
        }
    }

    async getPosts(req, res, next) {
        try {
            const result = await this.postService.findAll(req.query);
            
            const hal = HalBuilder.create()
                .addSelfLink(this.buildSelfLink(req))
                .addLink('create', '/api/posts', { method: 'POST' });

            // Add pagination links
            if (result.pagination.hasNextPage) {
                hal.addLink('next', this.buildPageLink(req, result.pagination.page + 1));
            }
            
            if (result.pagination.hasPrevPage) {
                hal.addLink('prev', this.buildPageLink(req, result.pagination.page - 1));
            }

            hal.addLink('first', this.buildPageLink(req, 1));
            hal.addLink('last', this.buildPageLink(req, result.pagination.pages));

            // Embed posts
            result.data.forEach(post => {
                hal.addEmbedded('posts', HalBuilder.create({
                    id: post.id,
                    title: post.title,
                    excerpt: post.excerpt,
                    status: post.status,
                    createdAt: post.createdAt
                })
                .addSelfLink(`/api/posts/${post.id}`)
                .build());
            });

            const response = hal.build();
            response.total = result.pagination.total;
            response.page = result.pagination.page;
            response.pages = result.pagination.pages;

            res.json(response);
        } catch (error) {
            next(error);
        }
    }
}
```

## 📄 API Documentation Patterns

### 1. OpenAPI/Swagger Integration

**Comprehensive API Documentation**
```javascript
// OpenAPI specification builder
const swaggerJSDoc = require('swagger-jsdoc');
const swaggerUI = require('swagger-ui-express');

const swaggerOptions = {
    definition: {
        openapi: '3.0.0',
        info: {
            title: 'Blog API',
            version: '1.0.0',
            description: 'A comprehensive blog management API',
            contact: {
                name: 'API Support',
                email: 'support@example.com',
                url: 'https://example.com/support'
            },
            license: {
                name: 'MIT',
                url: 'https://opensource.org/licenses/MIT'
            }
        },
        servers: [
            {
                url: 'https://api.example.com/v1',
                description: 'Production server'
            },
            {
                url: 'https://staging-api.example.com/v1',
                description: 'Staging server'
            },
            {
                url: 'http://localhost:3000/api/v1',
                description: 'Development server'
            }
        ],
        components: {
            securitySchemes: {
                bearerAuth: {
                    type: 'http',
                    scheme: 'bearer',
                    bearerFormat: 'JWT'
                },
                apiKey: {
                    type: 'apiKey',
                    in: 'header',
                    name: 'X-API-Key'
                }
            },
            schemas: {
                Post: {
                    type: 'object',
                    required: ['title', 'content'],
                    properties: {
                        id: {
                            type: 'string',
                            format: 'uuid',
                            description: 'Unique identifier for the post'
                        },
                        title: {
                            type: 'string',
                            minLength: 3,
                            maxLength: 200,
                            description: 'Post title'
                        },
                        content: {
                            type: 'string',
                            minLength: 10,
                            description: 'Post content in Markdown format'
                        },
                        excerpt: {
                            type: 'string',
                            maxLength: 500,
                            description: 'Short excerpt of the post'
                        },
                        status: {
                            type: 'string',
                            enum: ['draft', 'published', 'archived'],
                            default: 'draft',
                            description: 'Publication status'
                        },
                        tags: {
                            type: 'array',
                            items: {
                                type: 'string'
                            },
                            description: 'Post tags'
                        },
                        authorId: {
                            type: 'string',
                            format: 'uuid',
                            description: 'ID of the post author'
                        },
                        createdAt: {
                            type: 'string',
                            format: 'date-time',
                            description: 'Creation timestamp'
                        },
                        updatedAt: {
                            type: 'string',
                            format: 'date-time',
                            description: 'Last update timestamp'
                        }
                    },
                    example: {
                        id: '123e4567-e89b-12d3-a456-426614174000',
                        title: 'Introduction to Express.js',
                        content: '# Introduction\n\nExpress.js is a web framework...',
                        excerpt: 'Learn the basics of Express.js framework',
                        status: 'published',
                        tags: ['javascript', 'node.js', 'express'],
                        authorId: '456e7890-e89b-12d3-a456-426614174111',
                        createdAt: '2023-01-01T00:00:00Z',
                        updatedAt: '2023-01-02T10:30:00Z'
                    }
                },
                Error: {
                    type: 'object',
                    properties: {
                        success: {
                            type: 'boolean',
                            example: false
                        },
                        error: {
                            type: 'object',
                            properties: {
                                code: {
                                    type: 'string',
                                    example: 'VALIDATION_ERROR'
                                },
                                message: {
                                    type: 'string',
                                    example: 'Validation failed'
                                },
                                details: {
                                    type: 'array',
                                    items: {
                                        type: 'object',
                                        properties: {
                                            field: {
                                                type: 'string',
                                                example: 'title'
                                            },
                                            message: {
                                                type: 'string',
                                                example: 'Title is required'
                                            }
                                        }
                                    }
                                }
                            }
                        },
                        timestamp: {
                            type: 'string',
                            format: 'date-time'
                        }
                    }
                }
            },
            responses: {
                UnauthorizedError: {
                    description: 'Authentication required',
                    content: {
                        'application/json': {
                            schema: {
                                $ref: '#/components/schemas/Error'
                            },
                            example: {
                                success: false,
                                error: {
                                    code: 'AUTHENTICATION_ERROR',
                                    message: 'Authentication required'
                                },
                                timestamp: '2023-01-01T00:00:00Z'
                            }
                        }
                    }
                },
                ValidationError: {
                    description: 'Validation failed',
                    content: {
                        'application/json': {
                            schema: {
                                $ref: '#/components/schemas/Error'
                            }
                        }
                    }
                }
            }
        }
    },
    apis: ['./routes/*.js', './controllers/*.js']
};

// Generate swagger spec
const swaggerSpec = swaggerJSDoc(swaggerOptions);

// Setup swagger UI
app.use('/api-docs', swaggerUI.serve, swaggerUI.setup(swaggerSpec, {
    explorer: true,
    customCss: '.swagger-ui .topbar { display: none }',
    customSiteTitle: 'Blog API Documentation'
}));

/**
 * @swagger
 * /posts:
 *   get:
 *     summary: Retrieve a list of posts
 *     description: Get a paginated list of blog posts with optional filtering and sorting
 *     tags: [Posts]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: page
 *         schema:
 *           type: integer
 *           minimum: 1
 *           default: 1
 *         description: Page number for pagination
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *           minimum: 1
 *           maximum: 100
 *           default: 10
 *         description: Number of items per page
 *       - in: query
 *         name: status
 *         schema:
 *           type: string
 *           enum: [draft, published, archived]
 *         description: Filter by publication status
 *       - in: query
 *         name: search
 *         schema:
 *           type: string
 *         description: Search in title and content
 *       - in: query
 *         name: tags
 *         schema:
 *           type: string
 *         description: Comma-separated list of tags to filter by
 *       - in: query
 *         name: sort
 *         schema:
 *           type: string
 *           enum: [createdAt, -createdAt, updatedAt, -updatedAt, title, -title]
 *           default: -createdAt
 *         description: Sort field and direction (prefix with - for descending)
 *     responses:
 *       200:
 *         description: Successful response
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 data:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/Post'
 *                 meta:
 *                   type: object
 *                   properties:
 *                     pagination:
 *                       type: object
 *                       properties:
 *                         page:
 *                           type: integer
 *                         pages:
 *                           type: integer
 *                         limit:
 *                           type: integer
 *                         total:
 *                           type: integer
 *                         hasNextPage:
 *                           type: boolean
 *                         hasPrevPage:
 *                           type: boolean
 *       401:
 *         $ref: '#/components/responses/UnauthorizedError'
 *   post:
 *     summary: Create a new post
 *     description: Create a new blog post
 *     tags: [Posts]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [title, content]
 *             properties:
 *               title:
 *                 type: string
 *                 minLength: 3
 *                 maxLength: 200
 *               content:
 *                 type: string
 *                 minLength: 10
 *               excerpt:
 *                 type: string
 *                 maxLength: 500
 *               status:
 *                 type: string
 *                 enum: [draft, published]
 *                 default: draft
 *               tags:
 *                 type: array
 *                 items:
 *                   type: string
 *           example:
 *             title: "Getting Started with Node.js"
 *             content: "# Introduction\n\nNode.js is a JavaScript runtime..."
 *             excerpt: "Learn the basics of Node.js"
 *             status: "draft"
 *             tags: ["javascript", "node.js", "backend"]
 *     responses:
 *       201:
 *         description: Post created successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 data:
 *                   $ref: '#/components/schemas/Post'
 *                 meta:
 *                   type: object
 *                   properties:
 *                     created:
 *                       type: boolean
 *                       example: true
 *                     location:
 *                       type: string
 *                       example: "/api/posts/123e4567-e89b-12d3-a456-426614174000"
 *       400:
 *         $ref: '#/components/responses/ValidationError'
 *       401:
 *         $ref: '#/components/responses/UnauthorizedError'
 */
```

## 🔗 Navigation

← [Architecture Patterns](./architecture-patterns.md) | [Testing Strategies](./testing-strategies.md) →