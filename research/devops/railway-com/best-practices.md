# Railway.com Best Practices

This document outlines proven patterns, recommendations, and best practices for deploying and managing applications on Railway.com, with specific focus on production-ready deployments and cost optimization.

## Project Organization and Structure

### 1. Service Architecture Best Practices

#### Microservices vs Monolithic Approach
```
Recommended Service Structure for Nx Monorepo:

┌─ Frontend Service (web)
│  ├─ React/Vite static site
│  ├─ CDN-optimized assets  
│  └─ Environment-specific configs
│
├─ Backend Service (api)
│  ├─ Express.js API server
│  ├─ Authentication middleware
│  ├─ Business logic
│  └─ Database connections
│
├─ Database Service (mysql)
│  ├─ Managed MySQL instance
│  ├─ Automated backups
│  └─ Connection pooling
│
└─ Optional Services
   ├─ Redis (caching/sessions)
   ├─ File Storage (uploads)
   └─ Background Jobs (cron/queues)
```

#### Service Separation Guidelines
- **Frontend and Backend**: Always deploy as separate services for better scaling and debugging
- **Database**: Use managed Railway databases instead of self-hosted containers
- **Static Assets**: Leverage Railway's CDN for frontend assets
- **Background Jobs**: Consider separate service for long-running tasks

### 2. Environment Management

#### Environment Strategy
```bash
# Recommended environment structure
production/     # Live production environment
├─ web-prod    # Production frontend
├─ api-prod    # Production backend  
└─ mysql-prod  # Production database

staging/       # Pre-production testing
├─ web-stage   # Staging frontend
├─ api-stage   # Staging backend
└─ mysql-stage # Staging database (optional - can share dev)

development/   # Development environment
├─ web-dev     # Development frontend
├─ api-dev     # Development backend
└─ mysql-dev   # Development database
```

#### Environment Variable Management
```typescript
// Create environment configuration utility
export const config = {
  // Environment detection
  environment: process.env.NODE_ENV || 'development',
  isProduction: process.env.NODE_ENV === 'production',
  isDevelopment: process.env.NODE_ENV === 'development',
  
  // API configuration
  api: {
    port: parseInt(process.env.PORT || '3333'),
    baseUrl: process.env.API_BASE_URL || 'http://localhost:3333',
    corsOrigins: process.env.CORS_ORIGINS?.split(',') || ['http://localhost:4200'],
  },
  
  // Database configuration
  database: {
    url: process.env.DATABASE_URL,
    host: process.env.MYSQLHOST,
    port: parseInt(process.env.MYSQLPORT || '3306'),
    username: process.env.MYSQLUSER,
    password: process.env.MYSQLPASSWORD,
    database: process.env.MYSQLDATABASE,
    ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false,
    connectionLimit: parseInt(process.env.DB_CONNECTION_LIMIT || '10'),
  },
  
  // Security configuration
  security: {
    jwtSecret: process.env.JWT_SECRET,
    jwtExpiry: process.env.JWT_EXPIRY || '24h',
    hashRounds: parseInt(process.env.HASH_ROUNDS || '12'),
  },
  
  // Logging configuration
  logging: {
    level: process.env.LOG_LEVEL || 'info',
    enableConsole: process.env.ENABLE_CONSOLE_LOGS !== 'false',
  }
};

// Validation
const requiredEnvVars = ['DATABASE_URL', 'JWT_SECRET'];
const missingVars = requiredEnvVars.filter(varName => !process.env[varName]);

if (missingVars.length > 0) {
  throw new Error(`Missing required environment variables: ${missingVars.join(', ')}`);
}
```

## Performance Optimization

### 1. Database Optimization

#### Connection Pooling Best Practices
```typescript
import mysql from 'mysql2/promise';

// Optimized connection pool configuration
export const createConnectionPool = () => {
  return mysql.createPool({
    host: config.database.host,
    port: config.database.port,
    user: config.database.username,
    password: config.database.password,
    database: config.database.database,
    
    // Connection pool settings
    waitForConnections: true,
    connectionLimit: config.database.connectionLimit,
    queueLimit: 0,
    
    // Connection health
    acquireTimeout: 60000,
    timeout: 60000,
    reconnect: true,
    
    // SSL configuration
    ssl: config.database.ssl,
    
    // Performance optimizations
    supportBigNumbers: true,
    bigNumberStrings: true,
    dateStrings: true,
  });
};

// Connection management utility
class DatabaseManager {
  private pool: mysql.Pool;

  constructor() {
    this.pool = createConnectionPool();
    this.setupEventHandlers();
  }

  private setupEventHandlers() {
    this.pool.on('connection', (connection) => {
      console.log('New database connection established', connection.threadId);
    });

    this.pool.on('error', (error) => {
      console.error('Database pool error:', error);
      if (error.code === 'PROTOCOL_CONNECTION_LOST') {
        this.recreatePool();
      }
    });
  }

  private recreatePool() {
    console.log('Recreating database connection pool');
    this.pool.end();
    this.pool = createConnectionPool();
  }

  async execute<T>(query: string, params?: any[]): Promise<T> {
    try {
      const [rows] = await this.pool.execute(query, params);
      return rows as T;
    } catch (error) {
      console.error('Database query error:', error);
      throw error;
    }
  }

  async transaction<T>(callback: (connection: mysql.PoolConnection) => Promise<T>): Promise<T> {
    const connection = await this.pool.getConnection();
    
    try {
      await connection.beginTransaction();
      const result = await callback(connection);
      await connection.commit();
      return result;
    } catch (error) {
      await connection.rollback();
      throw error;
    } finally {
      connection.release();
    }
  }

  async healthCheck(): Promise<boolean> {
    try {
      await this.pool.execute('SELECT 1');
      return true;
    } catch (error) {
      console.error('Database health check failed:', error);
      return false;
    }
  }
}

export const db = new DatabaseManager();
```

#### Query Optimization
```typescript
// Efficient pagination with proper indexing
export const getPaginatedPatients = async (page = 1, limit = 20, search?: string) => {
  const offset = (page - 1) * limit;
  
  let query = `
    SELECT 
      id, first_name, last_name, email, phone, 
      DATE_FORMAT(date_of_birth, '%Y-%m-%d') as date_of_birth,
      created_at
    FROM patients
  `;
  
  const params: any[] = [];
  
  if (search) {
    query += ` WHERE CONCAT(first_name, ' ', last_name) LIKE ? OR email LIKE ?`;
    params.push(`%${search}%`, `%${search}%`);
  }
  
  query += ` ORDER BY created_at DESC LIMIT ? OFFSET ?`;
  params.push(limit, offset);
  
  return db.execute<Patient[]>(query, params);
};

// Efficient appointment queries with joins
export const getAppointmentsByDate = async (date: string) => {
  const query = `
    SELECT 
      a.id, a.appointment_date, a.duration_minutes, a.status, a.notes,
      p.id as patient_id, p.first_name, p.last_name, p.phone
    FROM appointments a
    JOIN patients p ON a.patient_id = p.id
    WHERE DATE(a.appointment_date) = ?
    ORDER BY a.appointment_date ASC
  `;
  
  return db.execute<AppointmentWithPatient[]>(query, [date]);
};

// Batch operations for efficiency
export const createMultiplePatients = async (patients: Omit<Patient, 'id'>[]) => {
  if (patients.length === 0) return [];
  
  const query = `
    INSERT INTO patients (first_name, last_name, email, phone, date_of_birth, address)
    VALUES ${patients.map(() => '(?, ?, ?, ?, ?, ?)').join(', ')}
  `;
  
  const params = patients.flatMap(p => [
    p.first_name, p.last_name, p.email, p.phone, p.date_of_birth, p.address
  ]);
  
  return db.execute(query, params);
};
```

### 2. Caching Strategies

#### Application-Level Caching
```typescript
import NodeCache from 'node-cache';

class CacheService {
  private cache: NodeCache;

  constructor() {
    this.cache = new NodeCache({
      stdTTL: 300, // 5 minutes default TTL
      checkperiod: 60, // Check for expired keys every minute
      useClones: false, // Better performance, but be careful with object mutations
    });
  }

  get<T>(key: string): T | undefined {
    return this.cache.get<T>(key);
  }

  set(key: string, value: any, ttl?: number): boolean {
    return this.cache.set(key, value, ttl);
  }

  del(key: string): number {
    return this.cache.del(key);
  }

  // Cache patterns for common operations
  async getOrSet<T>(
    key: string,
    fetchFunction: () => Promise<T>,
    ttl: number = 300
  ): Promise<T> {
    const cached = this.get<T>(key);
    if (cached !== undefined) {
      return cached;
    }

    const fresh = await fetchFunction();
    this.set(key, fresh, ttl);
    return fresh;
  }

  // Invalidate related cache entries
  invalidatePattern(pattern: string): void {
    const keys = this.cache.keys();
    const matchingKeys = keys.filter(key => key.includes(pattern));
    matchingKeys.forEach(key => this.cache.del(key));
  }
}

export const cacheService = new CacheService();

// Usage in controllers
export const getPatients = async (req: Request, res: Response) => {
  const cacheKey = `patients:${req.query.page || 1}:${req.query.search || ''}`;
  
  try {
    const patients = await cacheService.getOrSet(
      cacheKey,
      () => getPaginatedPatients(
        parseInt(req.query.page as string) || 1,
        20,
        req.query.search as string
      ),
      300 // 5 minutes cache
    );
    
    res.json(patients);
  } catch (error) {
    console.error('Error fetching patients:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

// Invalidate cache when data changes
export const createPatient = async (req: Request, res: Response) => {
  try {
    const patient = await createPatientInDB(req.body);
    
    // Invalidate relevant cache entries
    cacheService.invalidatePattern('patients:');
    
    res.status(201).json(patient);
  } catch (error) {
    console.error('Error creating patient:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};
```

#### Frontend Caching with React Query
```typescript
import { QueryClient, QueryClientProvider, useQuery, useMutation, useQueryClient } from 'react-query';

// Optimized QueryClient configuration
const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 5 * 60 * 1000, // 5 minutes
      cacheTime: 10 * 60 * 1000, // 10 minutes
      retry: 3,
      retryDelay: (attemptIndex) => Math.min(1000 * 2 ** attemptIndex, 30000),
    },
    mutations: {
      retry: 1,
    },
  },
});

// Custom hooks for data fetching
export const usePatients = (page = 1, search = '') => {
  return useQuery(
    ['patients', page, search],
    () => apiService.getPatients(page, search),
    {
      keepPreviousData: true, // Smooth pagination
      staleTime: 2 * 60 * 1000, // 2 minutes for frequently changing data
    }
  );
};

export const useCreatePatient = () => {
  const queryClient = useQueryClient();

  return useMutation(
    (patientData: CreatePatientData) => apiService.createPatient(patientData),
    {
      onSuccess: (newPatient) => {
        // Optimistic update
        queryClient.setQueryData<Patient[]>(['patients'], (old) => {
          return old ? [newPatient, ...old] : [newPatient];
        });

        // Invalidate and refetch related queries
        queryClient.invalidateQueries(['patients']);
        queryClient.invalidateQueries(['patient-stats']);
      },
      onError: (error) => {
        console.error('Failed to create patient:', error);
        // Show error notification
      },
    }
  );
};

// Prefetching for better UX
export const usePatientDetail = (patientId: number) => {
  const queryClient = useQueryClient();

  // Prefetch appointments when viewing patient details
  React.useEffect(() => {
    queryClient.prefetchQuery(
      ['appointments', patientId],
      () => apiService.getPatientAppointments(patientId),
      { staleTime: 5 * 60 * 1000 }
    );
  }, [patientId, queryClient]);

  return useQuery(
    ['patient', patientId],
    () => apiService.getPatient(patientId),
    {
      enabled: !!patientId,
    }
  );
};
```

### 3. Asset Optimization

#### Frontend Build Optimization
```typescript
// Optimized Vite configuration
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { resolve } from 'path';

export default defineConfig({
  plugins: [react()],
  
  build: {
    outDir: '../../dist/apps/web',
    
    // Code splitting optimization
    rollupOptions: {
      output: {
        manualChunks: {
          vendor: ['react', 'react-dom'],
          router: ['react-router-dom'],
          ui: ['@mui/material', '@mui/icons-material'],
          query: ['react-query'],
        },
      },
    },
    
    // Asset optimization
    assetsInlineLimit: 4096, // 4kb inline limit
    chunkSizeWarningLimit: 1000, // 1MB warning limit
    
    // Minification
    minify: 'terser',
    terserOptions: {
      compress: {
        drop_console: true, // Remove console.log in production
        drop_debugger: true,
      },
    },
  },
  
  // Development optimizations
  optimizeDeps: {
    include: ['react', 'react-dom', 'react-router-dom'],
  },
});
```

#### Image and Asset Management
```typescript
// Image optimization utility
export const optimizeImage = (file: File, maxWidth = 800, quality = 0.8): Promise<Blob> => {
  return new Promise((resolve) => {
    const canvas = document.createElement('canvas');
    const ctx = canvas.getContext('2d')!;
    const img = new Image();
    
    img.onload = () => {
      const ratio = Math.min(maxWidth / img.width, maxWidth / img.height);
      canvas.width = img.width * ratio;
      canvas.height = img.height * ratio;
      
      ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
      
      canvas.toBlob(resolve, 'image/jpeg', quality);
    };
    
    img.src = URL.createObjectURL(file);
  });
};

// Lazy image loading component
export const LazyImage: React.FC<{
  src: string;
  alt: string;
  className?: string;
}> = ({ src, alt, className }) => {
  const [isLoaded, setIsLoaded] = React.useState(false);
  const [isInView, setIsInView] = React.useState(false);
  const imgRef = React.useRef<HTMLImageElement>(null);

  React.useEffect(() => {
    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) {
          setIsInView(true);
          observer.disconnect();
        }
      },
      { threshold: 0.1 }
    );

    if (imgRef.current) {
      observer.observe(imgRef.current);
    }

    return () => observer.disconnect();
  }, []);

  return (
    <div className={className} ref={imgRef}>
      {isInView && (
        <img
          src={src}
          alt={alt}
          onLoad={() => setIsLoaded(true)}
          style={{
            opacity: isLoaded ? 1 : 0,
            transition: 'opacity 0.3s ease',
          }}
        />
      )}
    </div>
  );
};
```

## Security Best Practices

### 1. Authentication and Authorization

#### JWT Implementation
```typescript
import jwt from 'jsonwebtoken';
import bcrypt from 'bcrypt';
import rateLimit from 'express-rate-limit';

// Rate limiting for auth endpoints
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 5, // 5 attempts per window
  message: 'Too many authentication attempts, please try again later',
  standardHeaders: true,
  legacyHeaders: false,
});

// Secure JWT utility
class AuthService {
  private readonly jwtSecret: string;
  private readonly jwtExpiry: string;

  constructor() {
    this.jwtSecret = config.security.jwtSecret;
    this.jwtExpiry = config.security.jwtExpiry;
  }

  async hashPassword(password: string): Promise<string> {
    return bcrypt.hash(password, config.security.hashRounds);
  }

  async verifyPassword(password: string, hash: string): Promise<boolean> {
    return bcrypt.compare(password, hash);
  }

  generateToken(payload: { userId: number; role: string }): string {
    return jwt.sign(
      payload,
      this.jwtSecret,
      {
        expiresIn: this.jwtExpiry,
        issuer: 'clinic-management-system',
        audience: 'clinic-users',
      }
    );
  }

  verifyToken(token: string): any {
    return jwt.verify(token, this.jwtSecret, {
      issuer: 'clinic-management-system',
      audience: 'clinic-users',
    });
  }

  generateRefreshToken(): string {
    return jwt.sign(
      { type: 'refresh' },
      this.jwtSecret,
      { expiresIn: '7d' }
    );
  }
}

export const authService = new AuthService();

// Authentication middleware
export const authenticateToken = (req: Request, res: Response, next: NextFunction) => {
  const authHeader = req.headers.authorization;
  const token = authHeader?.split(' ')[1];

  if (!token) {
    return res.status(401).json({ error: 'Access token required' });
  }

  try {
    const decoded = authService.verifyToken(token);
    req.user = decoded;
    next();
  } catch (error) {
    if (error.name === 'TokenExpiredError') {
      return res.status(401).json({ error: 'Token expired' });
    }
    return res.status(403).json({ error: 'Invalid token' });
  }
};

// Role-based authorization
export const requireRole = (roles: string[]) => {
  return (req: Request, res: Response, next: NextFunction) => {
    if (!req.user || !roles.includes(req.user.role)) {
      return res.status(403).json({ error: 'Insufficient permissions' });
    }
    next();
  };
};

// Login endpoint with security measures
app.post('/api/auth/login', authLimiter, async (req, res) => {
  try {
    const { email, password } = req.body;

    // Input validation
    if (!email || !password) {
      return res.status(400).json({ error: 'Email and password required' });
    }

    // Find user
    const user = await getUserByEmail(email);
    if (!user) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    // Verify password
    const isValidPassword = await authService.verifyPassword(password, user.password);
    if (!isValidPassword) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    // Generate tokens
    const accessToken = authService.generateToken({
      userId: user.id,
      role: user.role,
    });
    const refreshToken = authService.generateRefreshToken();

    // Update last login
    await updateUserLastLogin(user.id);

    res.json({
      accessToken,
      refreshToken,
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        role: user.role,
      },
    });
  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});
```

### 2. Data Validation and Sanitization

#### Input Validation with Joi
```typescript
import Joi from 'joi';

// Validation schemas
export const schemas = {
  patient: Joi.object({
    first_name: Joi.string().trim().min(2).max(50).required(),
    last_name: Joi.string().trim().min(2).max(50).required(),
    email: Joi.string().email().optional().allow(''),
    phone: Joi.string().pattern(/^[\d\s\-\+\(\)]+$/).max(20).optional().allow(''),
    date_of_birth: Joi.date().max('now').optional(),
    address: Joi.string().max(200).optional().allow(''),
    medical_notes: Joi.string().max(1000).optional().allow(''),
  }),

  appointment: Joi.object({
    patient_id: Joi.number().integer().positive().required(),
    appointment_date: Joi.date().min('now').required(),
    duration_minutes: Joi.number().integer().min(15).max(240).default(30),
    notes: Joi.string().max(500).optional().allow(''),
  }),

  user: Joi.object({
    name: Joi.string().trim().min(2).max(100).required(),
    email: Joi.string().email().required(),
    password: Joi.string().min(8).pattern(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]/).required(),
    role: Joi.string().valid('doctor', 'nurse', 'admin', 'receptionist').required(),
    phone: Joi.string().pattern(/^[\d\s\-\+\(\)]+$/).max(20).optional(),
  }),

  login: Joi.object({
    email: Joi.string().email().required(),
    password: Joi.string().required(),
  }),
};

// Validation middleware factory
export const validateBody = (schema: Joi.ObjectSchema) => {
  return (req: Request, res: Response, next: NextFunction) => {
    const { error, value } = schema.validate(req.body, {
      abortEarly: false,
      stripUnknown: true,
    });

    if (error) {
      const errors = error.details.map(detail => ({
        field: detail.path.join('.'),
        message: detail.message,
      }));
      
      return res.status(400).json({
        error: 'Validation failed',
        details: errors,
      });
    }

    req.body = value; // Use sanitized data
    next();
  };
};

// Usage in routes
app.post('/api/patients', 
  authenticateToken, 
  requireRole(['doctor', 'nurse', 'admin']),
  validateBody(schemas.patient),
  createPatient
);
```

### 3. SQL Injection Prevention

#### Parameterized Queries
```typescript
// Always use parameterized queries
export const searchPatients = async (searchTerm: string, limit = 20) => {
  // GOOD: Parameterized query
  const query = `
    SELECT id, first_name, last_name, email, phone
    FROM patients
    WHERE CONCAT(first_name, ' ', last_name) LIKE ?
       OR email LIKE ?
    ORDER BY last_name, first_name
    LIMIT ?
  `;
  
  const searchPattern = `%${searchTerm}%`;
  return db.execute<Patient[]>(query, [searchPattern, searchPattern, limit]);
};

// BAD: String concatenation (vulnerable to SQL injection)
// const query = `SELECT * FROM patients WHERE name = '${userName}'`;

// Query builder for complex queries
class QueryBuilder {
  private query: string = '';
  private params: any[] = [];

  select(columns: string[]): this {
    this.query += `SELECT ${columns.join(', ')} `;
    return this;
  }

  from(table: string): this {
    this.query += `FROM ${table} `;
    return this;
  }

  where(condition: string, value: any): this {
    const operator = this.query.includes('WHERE') ? 'AND' : 'WHERE';
    this.query += `${operator} ${condition} `;
    this.params.push(value);
    return this;
  }

  orderBy(column: string, direction: 'ASC' | 'DESC' = 'ASC'): this {
    this.query += `ORDER BY ${column} ${direction} `;
    return this;
  }

  limit(count: number): this {
    this.query += `LIMIT ? `;
    this.params.push(count);
    return this;
  }

  build(): { query: string; params: any[] } {
    return { query: this.query.trim(), params: this.params };
  }
}

// Usage
export const getFilteredPatients = async (filters: PatientFilters) => {
  const builder = new QueryBuilder()
    .select(['id', 'first_name', 'last_name', 'email', 'phone'])
    .from('patients');

  if (filters.name) {
    builder.where("CONCAT(first_name, ' ', last_name) LIKE ?", `%${filters.name}%`);
  }

  if (filters.email) {
    builder.where("email LIKE ?", `%${filters.email}%`);
  }

  if (filters.dateFrom) {
    builder.where("created_at >= ?", filters.dateFrom);
  }

  const { query, params } = builder
    .orderBy('created_at', 'DESC')
    .limit(filters.limit || 20)
    .build();

  return db.execute<Patient[]>(query, params);
};
```

## Cost Optimization Strategies

### 1. Resource Management

#### Efficient Database Usage
```typescript
// Connection pool optimization for low-traffic applications
const createOptimizedPool = () => {
  return mysql.createPool({
    // Reduced connection limits for cost optimization
    connectionLimit: 3, // Small clinic usage
    queueLimit: 5,
    
    // Aggressive timeout settings
    acquireTimeout: 10000,
    timeout: 30000,
    
    // Connection lifecycle management
    idleTimeout: 300000, // 5 minutes
    maxIdle: 2, // Keep 2 idle connections
    
    // Enable query caching
    queryTimeout: 60000,
  });
};

// Lazy loading for database connections
class LazyDatabaseManager {
  private pool?: mysql.Pool;

  private getPool(): mysql.Pool {
    if (!this.pool) {
      this.pool = createOptimizedPool();
    }
    return this.pool;
  }

  async execute<T>(query: string, params?: any[]): Promise<T> {
    const pool = this.getPool();
    const [rows] = await pool.execute(query, params);
    return rows as T;
  }

  // Graceful shutdown to release resources
  async close(): Promise<void> {
    if (this.pool) {
      await this.pool.end();
      this.pool = undefined;
    }
  }
}

// Process cleanup
process.on('SIGTERM', async () => {
  console.log('Received SIGTERM, gracefully shutting down');
  await db.close();
  process.exit(0);
});
```

#### Smart Caching for Cost Reduction
```typescript
// Tiered caching strategy
class TieredCacheService {
  private memoryCache: NodeCache;
  private diskCache?: any; // Optional disk cache for larger data

  constructor() {
    this.memoryCache = new NodeCache({
      stdTTL: 600, // 10 minutes for memory cache
      maxKeys: 100, // Limit memory usage
    });
  }

  // Cache frequently accessed, rarely changing data
  async getCachedPatientStats(): Promise<PatientStats> {
    const cacheKey = 'patient-stats';
    
    // Try memory cache first
    let stats = this.memoryCache.get<PatientStats>(cacheKey);
    if (stats) return stats;
    
    // Calculate stats (expensive operation)
    stats = await this.calculatePatientStats();
    
    // Cache for 30 minutes (stats don't change frequently)
    this.memoryCache.set(cacheKey, stats, 1800);
    
    return stats;
  }

  private async calculatePatientStats(): Promise<PatientStats> {
    const [totalPatients] = await db.execute<any>('SELECT COUNT(*) as count FROM patients');
    const [newThisMonth] = await db.execute<any>(`
      SELECT COUNT(*) as count FROM patients 
      WHERE created_at >= DATE_SUB(NOW(), INTERVAL 1 MONTH)
    `);
    
    return {
      total: totalPatients.count,
      newThisMonth: newThisMonth.count,
      lastUpdated: new Date(),
    };
  }
}

// Conditional feature loading
class FeatureManager {
  private enabledFeatures: Set<string> = new Set();

  constructor() {
    // Load features based on environment/subscription
    this.loadFeatures();
  }

  private loadFeatures(): void {
    // Essential features always enabled
    this.enabledFeatures.add('patient-management');
    this.enabledFeatures.add('appointment-scheduling');
    
    // Optional features based on usage/cost
    if (process.env.ENABLE_REPORTING === 'true') {
      this.enabledFeatures.add('advanced-reporting');
    }
    
    if (process.env.ENABLE_NOTIFICATIONS === 'true') {
      this.enabledFeatures.add('email-notifications');
    }
  }

  isEnabled(feature: string): boolean {
    return this.enabledFeatures.has(feature);
  }

  // Middleware to conditionally enable expensive features
  requireFeature(feature: string) {
    return (req: Request, res: Response, next: NextFunction) => {
      if (!this.isEnabled(feature)) {
        return res.status(404).json({ error: 'Feature not available' });
      }
      next();
    };
  }
}

export const featureManager = new FeatureManager();
```

### 2. Development Environment Optimization

#### Environment-Aware Resource Allocation
```typescript
// Environment-specific configurations
const getEnvironmentConfig = () => {
  const env = process.env.NODE_ENV || 'development';
  
  const configs = {
    development: {
      database: {
        connectionLimit: 2,
        enableQueryLogging: true,
      },
      cache: {
        ttl: 60, // Short cache in dev
        maxKeys: 10,
      },
      features: {
        enableAllFeatures: true,
        enableDebugMode: true,
      },
    },
    
    staging: {
      database: {
        connectionLimit: 3,
        enableQueryLogging: false,
      },
      cache: {
        ttl: 300,
        maxKeys: 50,
      },
      features: {
        enableAllFeatures: true,
        enableDebugMode: false,
      },
    },
    
    production: {
      database: {
        connectionLimit: 5,
        enableQueryLogging: false,
      },
      cache: {
        ttl: 600,
        maxKeys: 100,
      },
      features: {
        enableAllFeatures: false, // Selective feature enablement
        enableDebugMode: false,
      },
    },
  };
  
  return configs[env] || configs.development;
};

// Auto-scaling configuration
const configureAutoScaling = () => {
  // In Railway, configure through environment variables
  const config = {
    // Minimum resources for cost optimization
    minReplicas: 1,
    maxReplicas: process.env.NODE_ENV === 'production' ? 3 : 1,
    
    // CPU and Memory targets
    targetCPUUtilization: 70, // Scale up at 70% CPU
    targetMemoryUtilization: 80, // Scale up at 80% memory
    
    // Scale down policy (aggressive for cost optimization)
    scaleDownStabilizationWindow: 300, // 5 minutes
    scaleUpStabilizationWindow: 60, // 1 minute
  };
  
  return config;
};
```

### 3. Monitoring and Cost Tracking

#### Usage Monitoring
```typescript
// Cost tracking middleware
class CostTracker {
  private requestCount = 0;
  private startTime = Date.now();

  track() {
    return (req: Request, res: Response, next: NextFunction) => {
      this.requestCount++;
      
      // Log expensive operations
      const startTime = process.hrtime.bigint();
      
      res.on('finish', () => {
        const endTime = process.hrtime.bigint();
        const duration = Number(endTime - startTime) / 1000000; // Convert to ms
        
        if (duration > 1000) { // Log slow requests (>1s)
          console.warn(`Slow request: ${req.method} ${req.url} - ${duration}ms`);
        }
        
        // Track database-heavy endpoints
        if (req.url.includes('/api/reports') || req.url.includes('/api/analytics')) {
          console.log(`Expensive endpoint accessed: ${req.url} - ${duration}ms`);
        }
      });
      
      next();
    };
  }

  getStats() {
    const uptime = Date.now() - this.startTime;
    return {
      requestCount: this.requestCount,
      uptime: uptime,
      requestsPerMinute: (this.requestCount / (uptime / 60000)).toFixed(2),
    };
  }
}

export const costTracker = new CostTracker();

// Health check with cost metrics
app.get('/health', (req, res) => {
  const stats = costTracker.getStats();
  const memoryUsage = process.memoryUsage();
  
  res.json({
    status: 'OK',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    memory: {
      used: `${Math.round(memoryUsage.heapUsed / 1024 / 1024)}MB`,
      total: `${Math.round(memoryUsage.heapTotal / 1024 / 1024)}MB`,
    },
    performance: stats,
    environment: process.env.NODE_ENV,
  });
});
```

## Error Handling and Logging

### 1. Comprehensive Error Handling

#### Centralized Error Handler
```typescript
import winston from 'winston';

// Logger configuration
const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  transports: [
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.colorize(),
        winston.format.simple()
      ),
    }),
  ],
});

// Custom error classes
export class AppError extends Error {
  public statusCode: number;
  public isOperational: boolean;

  constructor(message: string, statusCode: number) {
    super(message);
    this.statusCode = statusCode;
    this.isOperational = true;

    Error.captureStackTrace(this, this.constructor);
  }
}

export class ValidationError extends AppError {
  constructor(message: string) {
    super(message, 400);
  }
}

export class NotFoundError extends AppError {
  constructor(resource: string) {
    super(`${resource} not found`, 404);
  }
}

export class UnauthorizedError extends AppError {
  constructor(message = 'Unauthorized access') {
    super(message, 401);
  }
}

// Global error handler
export const errorHandler = (
  error: Error,
  req: Request,
  res: Response,
  next: NextFunction
) => {
  let { statusCode = 500, message } = error as AppError;

  // Log error details
  logger.error({
    message: error.message,
    stack: error.stack,
    url: req.url,
    method: req.method,
    ip: req.ip,
    userAgent: req.get('User-Agent'),
  });

  // Handle specific error types
  if (error.name === 'ValidationError') {
    statusCode = 400;
    message = 'Validation failed';
  } else if (error.name === 'CastError') {
    statusCode = 400;
    message = 'Invalid data format';
  } else if (error.code === 'ER_DUP_ENTRY') {
    statusCode = 409;
    message = 'Duplicate entry';
  }

  // Don't leak error details in production
  if (process.env.NODE_ENV === 'production' && statusCode === 500) {
    message = 'Internal server error';
  }

  res.status(statusCode).json({
    error: message,
    ...(process.env.NODE_ENV === 'development' && { stack: error.stack }),
  });
};

// Async error wrapper
export const asyncHandler = (fn: Function) => {
  return (req: Request, res: Response, next: NextFunction) => {
    Promise.resolve(fn(req, res, next)).catch(next);
  };
};
```

### 2. Request Logging and Monitoring

#### Request Tracking
```typescript
import morgan from 'morgan';
import { v4 as uuidv4 } from 'uuid';

// Request ID middleware
export const requestId = (req: Request, res: Response, next: NextFunction) => {
  req.id = uuidv4();
  res.setHeader('X-Request-ID', req.id);
  next();
};

// Custom morgan tokens
morgan.token('id', (req: any) => req.id);
morgan.token('user', (req: any) => req.user?.userId || 'anonymous');

// Logging format
const logFormat = ':id :remote-addr - :user [:date[clf]] ":method :url HTTP/:http-version" :status :res[content-length] ":referrer" ":user-agent" :response-time ms';

// Request logger
export const requestLogger = morgan(logFormat, {
  stream: {
    write: (message: string) => {
      logger.info(message.trim());
    },
  },
});

// Performance monitoring
export const performanceMonitor = (req: Request, res: Response, next: NextFunction) => {
  const start = process.hrtime.bigint();
  
  res.on('finish', () => {
    const end = process.hrtime.bigint();
    const duration = Number(end - start) / 1000000; // Convert to ms
    
    // Log slow requests
    if (duration > 1000) {
      logger.warn({
        message: 'Slow request detected',
        requestId: req.id,
        url: req.url,
        method: req.method,
        duration: `${duration}ms`,
        userId: req.user?.userId,
      });
    }
    
    // Track endpoint performance
    logger.info({
      requestId: req.id,
      method: req.method,
      url: req.url,
      statusCode: res.statusCode,
      duration: `${duration}ms`,
      userId: req.user?.userId,
    });
  });
  
  next();
};
```

## Deployment and CI/CD Best Practices

### 1. Railway Deployment Configuration

#### Railway.json Configuration
```json
{
  "build": {
    "builder": "NIXPACKS",
    "buildCommand": "npm run build",
    "watchPatterns": [
      "apps/**/*",
      "libs/**/*",
      "package.json",
      "nx.json"
    ]
  },
  "deploy": {
    "startCommand": "npm run start:prod",
    "restartPolicyType": "ON_FAILURE",
    "restartPolicyMaxRetries": 3,
    "numReplicas": 1,
    "sleepApplication": false
  },
  "environments": {
    "production": {
      "variables": {
        "NODE_ENV": "production",
        "LOG_LEVEL": "warn"
      }
    },
    "staging": {
      "variables": {
        "NODE_ENV": "staging",
        "LOG_LEVEL": "info"
      }
    }
  }
}
```

#### Multi-Service Deployment Script
```bash
#!/bin/bash
# deploy.sh - Multi-service deployment script

set -e

echo "🚀 Starting Railway deployment..."

# Build applications
echo "📦 Building applications..."
npx nx build web --prod
npx nx build api --prod

# Deploy frontend
echo "🌐 Deploying frontend service..."
railway service select web
railway up --detach

# Deploy backend
echo "⚙️  Deploying backend service..."
railway service select api
railway up --detach

# Run database migrations (if needed)
echo "🗄️  Running database migrations..."
railway run --service api npm run db:migrate

# Health checks
echo "🔍 Running health checks..."
sleep 30

FRONTEND_URL=$(railway service url web)
BACKEND_URL=$(railway service url api)

# Check frontend
if curl -f "$FRONTEND_URL" > /dev/null 2>&1; then
  echo "✅ Frontend deployment successful: $FRONTEND_URL"
else
  echo "❌ Frontend deployment failed"
  exit 1
fi

# Check backend
if curl -f "$BACKEND_URL/health" > /dev/null 2>&1; then
  echo "✅ Backend deployment successful: $BACKEND_URL"
else
  echo "❌ Backend deployment failed"
  exit 1
fi

echo "🎉 Deployment completed successfully!"
```

### 2. GitHub Actions Integration

#### Automated Deployment Workflow
```yaml
name: Deploy to Railway

on:
  push:
    branches: [main, staging]
  pull_request:
    branches: [main]

env:
  NODE_VERSION: '18'

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: 'npm'
      
      - name: Install dependencies
        run: npm ci
      
      - name: Run linting
        run: npx nx run-many --target=lint --all
      
      - name: Run tests
        run: npx nx run-many --target=test --all --coverage
      
      - name: Build applications
        run: |
          npx nx build web --prod
          npx nx build api --prod

  deploy-staging:
    if: github.ref == 'refs/heads/staging'
    needs: test
    runs-on: ubuntu-latest
    environment: staging
    steps:
      - uses: actions/checkout@v3
      
      - name: Install Railway CLI
        run: npm install -g @railway/cli
      
      - name: Deploy to Railway Staging
        env:
          RAILWAY_TOKEN: ${{ secrets.RAILWAY_STAGING_TOKEN }}
        run: |
          railway login --token $RAILWAY_TOKEN
          railway environment select staging
          railway up --service web --detach
          railway up --service api --detach

  deploy-production:
    if: github.ref == 'refs/heads/main'
    needs: test
    runs-on: ubuntu-latest
    environment: production
    steps:
      - uses: actions/checkout@v3
      
      - name: Install Railway CLI
        run: npm install -g @railway/cli
      
      - name: Deploy to Railway Production
        env:
          RAILWAY_TOKEN: ${{ secrets.RAILWAY_PRODUCTION_TOKEN }}
        run: |
          railway login --token $RAILWAY_TOKEN
          railway environment select production
          railway up --service web --detach
          railway up --service api --detach
          
      - name: Run health checks
        run: |
          sleep 30
          curl -f https://your-app.railway.app/health
          curl -f https://your-api.railway.app/health
```

---

## Conclusion

These best practices provide a comprehensive foundation for deploying and managing production applications on Railway.com. By following these patterns, you can ensure:

- **Optimal Performance**: Through efficient database usage, caching strategies, and resource optimization
- **Strong Security**: With proper authentication, validation, and error handling
- **Cost Effectiveness**: Through smart resource management and monitoring
- **Operational Excellence**: With comprehensive logging, monitoring, and deployment automation

Remember to regularly review and update these practices based on your application's specific needs and Railway's evolving features.

---

## References

- [Railway.com Best Practices](https://docs.railway.app/guides/best-practices)
- [Node.js Security Best Practices](https://nodejs.org/en/docs/guides/security/)
- [Express.js Security Guidelines](https://expressjs.com/en/advanced/best-practice-security.html)
- [MySQL Performance Optimization](https://dev.mysql.com/doc/refman/8.0/en/optimization.html)
- [React Performance Optimization](https://reactjs.org/docs/optimizing-performance.html)

---

← [Back to Implementation Guide](./implementation-guide.md) | [Next: Troubleshooting](./troubleshooting.md) →