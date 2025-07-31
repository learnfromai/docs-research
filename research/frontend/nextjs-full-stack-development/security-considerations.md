# Security Considerations: Next.js Educational Platform

## 🔒 Overview

Security is paramount for educational platforms that handle student data, payment information, and intellectual property. This comprehensive guide covers security best practices, compliance requirements, and implementation strategies specific to Next.js educational platforms operating in international markets (AU, UK, US) while serving Philippine students.

## 🛡️ Security Framework

### Security Principles for Educational Platforms

1. **Data Privacy** - Protect student personal and academic information
2. **Access Control** - Role-based permissions for students, instructors, and administrators
3. **Content Protection** - Secure course materials and intellectual property
4. **Payment Security** - Safe handling of financial transactions
5. **Compliance** - FERPA, GDPR, COPPA compliance requirements
6. **Audit Trail** - Complete logging of user actions and system events

## 🔐 Authentication & Authorization

### NextAuth.js Implementation

```typescript
// lib/auth.ts - Secure authentication configuration
import { NextAuthOptions } from 'next-auth'
import { PrismaAdapter } from '@auth/prisma-adapter'
import GoogleProvider from 'next-auth/providers/google'
import CredentialsProvider from 'next-auth/providers/credentials'
import { prisma } from './db'
import bcrypt from 'bcryptjs'
import { randomBytes, scrypt } from 'crypto'
import { promisify } from 'util'

const scryptAsync = promisify(scrypt)

// Secure password hashing
export async function hashPassword(password: string): Promise<string> {
  const salt = randomBytes(16).toString('hex')
  const derivedKey = (await scryptAsync(password, salt, 64)) as Buffer
  return `${salt}:${derivedKey.toString('hex')}`
}

export async function verifyPassword(password: string, hashedPassword: string): Promise<boolean> {
  const [salt, hash] = hashedPassword.split(':')
  const derivedKey = (await scryptAsync(password, salt, 64)) as Buffer
  return hash === derivedKey.toString('hex')
}

export const authOptions: NextAuthOptions = {
  adapter: PrismaAdapter(prisma),
  providers: [
    GoogleProvider({
      clientId: process.env.GOOGLE_CLIENT_ID!,
      clientSecret: process.env.GOOGLE_CLIENT_SECRET!,
      authorization: {
        params: {
          prompt: 'consent',
          access_type: 'offline',
          response_type: 'code',
        },
      },
    }),
    CredentialsProvider({
      name: 'credentials',
      credentials: {
        email: { label: 'Email', type: 'email' },
        password: { label: 'Password', type: 'password' },
      },
      async authorize(credentials) {
        if (!credentials?.email || !credentials?.password) {
          throw new Error('Invalid credentials')
        }

        const user = await prisma.user.findUnique({
          where: { email: credentials.email },
          select: {
            id: true,
            email: true,
            name: true,
            password: true,
            role: true,
            emailVerified: true,
            active: true,
            lastLoginAt: true,
            failedLoginAttempts: true,
            lockedUntil: true,
          },
        })

        if (!user) {
          throw new Error('No user found with this email')
        }

        // Check if account is locked due to failed attempts
        if (user.lockedUntil && user.lockedUntil > new Date()) {
          throw new Error('Account temporarily locked due to failed login attempts')
        }

        // Check if account is active
        if (!user.active) {
          throw new Error('Account has been deactivated')
        }

        // Verify email for security
        if (process.env.NODE_ENV === 'production' && !user.emailVerified) {
          throw new Error('Please verify your email before logging in')
        }

        const isValidPassword = await verifyPassword(credentials.password, user.password)

        if (!isValidPassword) {
          // Increment failed attempts
          await prisma.user.update({
            where: { id: user.id },
            data: {
              failedLoginAttempts: { increment: 1 },
              lockedUntil: user.failedLoginAttempts >= 4 
                ? new Date(Date.now() + 15 * 60 * 1000) // Lock for 15 minutes
                : undefined,
            },
          })
          throw new Error('Invalid password')
        }

        // Reset failed attempts on successful login
        await prisma.user.update({
          where: { id: user.id },
          data: {
            failedLoginAttempts: 0,
            lockedUntil: null,
            lastLoginAt: new Date(),
          },
        })

        return {
          id: user.id,
          email: user.email,
          name: user.name,
          role: user.role,
        }
      },
    }),
  ],
  session: {
    strategy: 'jwt',
    maxAge: 24 * 60 * 60, // 24 hours
  },
  jwt: {
    maxAge: 24 * 60 * 60, // 24 hours
    secret: process.env.NEXTAUTH_SECRET,
  },
  callbacks: {
    async jwt({ token, user, account }) {
      if (user) {
        token.role = user.role
        token.userId = user.id
      }
      
      // Add security timestamp to detect token replay attacks
      if (!token.iat) {
        token.iat = Math.floor(Date.now() / 1000)
      }
      
      return token
    },
    async session({ session, token }) {
      if (session?.user) {
        session.user.id = token.userId as string
        session.user.role = token.role as string
      }
      return session
    },
    async signIn({ user, account, profile, email, credentials }) {
      // Additional security checks
      if (account?.provider === 'google') {
        // Verify Google email is verified
        if (!profile?.email_verified) {
          return false
        }
      }
      
      // Log sign-in attempt for security monitoring
      await prisma.auditLog.create({
        data: {
          action: 'SIGN_IN',
          userId: user.id,
          details: {
            provider: account?.provider,
            userAgent: process.env.USER_AGENT,
            ip: process.env.CLIENT_IP,
          },
        },
      })
      
      return true
    },
  },
  pages: {
    signIn: '/auth/signin',
    signUp: '/auth/signup',
    error: '/auth/error',
    verifyRequest: '/auth/verify-request',
  },
  events: {
    async signOut({ token }) {
      // Log sign-out for security monitoring
      if (token?.userId) {
        await prisma.auditLog.create({
          data: {
            action: 'SIGN_OUT',
            userId: token.userId as string,
            details: {
              timestamp: new Date().toISOString(),
            },
          },
        })
      }
    },
  },
}
```

### Role-Based Access Control (RBAC)

```typescript
// lib/rbac.ts - Role-based access control
export enum Role {
  STUDENT = 'STUDENT',
  INSTRUCTOR = 'INSTRUCTOR',
  ADMIN = 'ADMIN',
  SUPER_ADMIN = 'SUPER_ADMIN',
}

export enum Permission {
  // Course permissions
  VIEW_COURSE = 'VIEW_COURSE',
  CREATE_COURSE = 'CREATE_COURSE',
  EDIT_COURSE = 'EDIT_COURSE',
  DELETE_COURSE = 'DELETE_COURSE',
  PUBLISH_COURSE = 'PUBLISH_COURSE',
  
  // User permissions
  VIEW_USERS = 'VIEW_USERS',
  EDIT_USERS = 'EDIT_USERS',
  DELETE_USERS = 'DELETE_USERS',
  MANAGE_ROLES = 'MANAGE_ROLES',
  
  // Financial permissions
  VIEW_PAYMENTS = 'VIEW_PAYMENTS',
  PROCESS_REFUNDS = 'PROCESS_REFUNDS',
  VIEW_ANALYTICS = 'VIEW_ANALYTICS',
  
  // System permissions
  MANAGE_SYSTEM = 'MANAGE_SYSTEM',
  VIEW_LOGS = 'VIEW_LOGS',
  BACKUP_DATA = 'BACKUP_DATA',
}

const ROLE_PERMISSIONS: Record<Role, Permission[]> = {
  [Role.STUDENT]: [
    Permission.VIEW_COURSE,
  ],
  [Role.INSTRUCTOR]: [
    Permission.VIEW_COURSE,
    Permission.CREATE_COURSE,
    Permission.EDIT_COURSE,
    Permission.PUBLISH_COURSE,
    Permission.VIEW_ANALYTICS,
  ],
  [Role.ADMIN]: [
    Permission.VIEW_COURSE,
    Permission.CREATE_COURSE,
    Permission.EDIT_COURSE,
    Permission.DELETE_COURSE,
    Permission.PUBLISH_COURSE,
    Permission.VIEW_USERS,
    Permission.EDIT_USERS,
    Permission.VIEW_PAYMENTS,
    Permission.PROCESS_REFUNDS,
    Permission.VIEW_ANALYTICS,
    Permission.VIEW_LOGS,
  ],
  [Role.SUPER_ADMIN]: Object.values(Permission),
}

export function hasPermission(userRole: Role, permission: Permission): boolean {
  return ROLE_PERMISSIONS[userRole]?.includes(permission) ?? false
}

export function requirePermission(userRole: Role, permission: Permission) {
  if (!hasPermission(userRole, permission)) {
    throw new Error(`Insufficient permissions. Required: ${permission}`)
  }
}

// HOC for protecting components
export function withPermission<T extends object>(
  Component: React.ComponentType<T>,
  requiredPermission: Permission
) {
  return function ProtectedComponent(props: T) {
    const { data: session } = useSession()
    
    if (!session) {
      return <div>Please log in to access this content.</div>
    }
    
    if (!hasPermission(session.user.role as Role, requiredPermission)) {
      return <div>You don't have permission to access this content.</div>
    }
    
    return <Component {...props} />
  }
}

// API route protection
export function requireAuth(handler: NextApiHandler): NextApiHandler {
  return async (req, res) => {
    const session = await getServerSession(req, res, authOptions)
    
    if (!session) {
      return res.status(401).json({ error: 'Unauthorized' })
    }
    
    return handler(req, res)
  }
}

export function requireRole(roles: Role[]) {
  return function (handler: NextApiHandler): NextApiHandler {
    return async (req, res) => {
      const session = await getServerSession(req, res, authOptions)
      
      if (!session) {
        return res.status(401).json({ error: 'Unauthorized' })
      }
      
      if (!roles.includes(session.user.role as Role)) {
        return res.status(403).json({ error: 'Forbidden' })
      }
      
      return handler(req, res)
    }
  }
}
```

## 🔍 Input Validation & Sanitization

### Comprehensive Validation Schema

```typescript
// lib/validations.ts - Input validation schemas
import { z } from 'zod'
import DOMPurify from 'isomorphic-dompurify'

// User validation
export const userRegistrationSchema = z.object({
  name: z
    .string()
    .min(2, 'Name must be at least 2 characters')
    .max(100, 'Name must be less than 100 characters')
    .regex(/^[a-zA-Z\s'-]+$/, 'Name contains invalid characters'),
  
  email: z
    .string()
    .email('Invalid email address')
    .max(255, 'Email must be less than 255 characters')
    .transform(email => email.toLowerCase().trim()),
  
  password: z
    .string()
    .min(8, 'Password must be at least 8 characters')
    .max(128, 'Password must be less than 128 characters')
    .regex(
      /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]/,
      'Password must contain at least one uppercase letter, one lowercase letter, one number, and one special character'
    ),
  
  confirmPassword: z.string(),
  
  terms: z.boolean().refine(val => val === true, 'Must accept terms and conditions'),
  
  dateOfBirth: z
    .string()
    .transform(str => new Date(str))
    .refine(date => {
      const age = new Date().getFullYear() - date.getFullYear()
      return age >= 13 && age <= 120
    }, 'Must be between 13 and 120 years old'),
}).refine(data => data.password === data.confirmPassword, {
  message: 'Passwords do not match',
  path: ['confirmPassword'],
})

// Course validation
export const courseSchema = z.object({
  title: z
    .string()
    .min(5, 'Title must be at least 5 characters')
    .max(200, 'Title must be less than 200 characters')
    .transform(title => DOMPurify.sanitize(title.trim())),
  
  description: z
    .string()
    .min(20, 'Description must be at least 20 characters')
    .max(2000, 'Description must be less than 2000 characters')
    .transform(desc => DOMPurify.sanitize(desc)),
  
  content: z
    .string()
    .min(100, 'Content must be at least 100 characters')
    .max(50000, 'Content must be less than 50000 characters')
    .transform(content => {
      // Allow only safe HTML tags for educational content
      return DOMPurify.sanitize(content, {
        ALLOWED_TAGS: [
          'p', 'br', 'strong', 'em', 'u', 'ol', 'ul', 'li',
          'h1', 'h2', 'h3', 'h4', 'h5', 'h6',
          'a', 'img', 'code', 'pre', 'blockquote',
          'table', 'thead', 'tbody', 'tr', 'th', 'td'
        ],
        ALLOWED_ATTR: ['href', 'src', 'alt', 'title', 'target'],
        ALLOWED_URI_REGEXP: /^https?:\/\//
      })
    }),
  
  slug: z
    .string()
    .min(3, 'Slug must be at least 3 characters')
    .max(100, 'Slug must be less than 100 characters')
    .regex(/^[a-z0-9-]+$/, 'Slug must contain only lowercase letters, numbers, and hyphens')
    .transform(slug => slug.toLowerCase()),
  
  price: z
    .number()
    .min(0, 'Price cannot be negative')
    .max(50000, 'Price cannot exceed ₱50,000')
    .optional(),
  
  tags: z
    .array(z.string().min(1).max(50))
    .max(10, 'Maximum 10 tags allowed')
    .optional()
    .transform(tags => tags?.map(tag => DOMPurify.sanitize(tag.trim().toLowerCase()))),
  
  categoryId: z.string().uuid('Invalid category ID'),
  
  difficulty: z.enum(['BEGINNER', 'INTERMEDIATE', 'ADVANCED']),
  
  estimatedHours: z
    .number()
    .min(1, 'Estimated hours must be at least 1')
    .max(1000, 'Estimated hours cannot exceed 1000')
    .optional(),
})

// File upload validation
export const fileUploadSchema = z.object({
  filename: z
    .string()
    .min(1, 'Filename is required')
    .max(255, 'Filename too long')
    .regex(/^[a-zA-Z0-9._-]+$/, 'Invalid filename format'),
  
  mimetype: z
    .string()
    .refine(type => {
      const allowedTypes = [
        'image/jpeg',
        'image/png',
        'image/webp',
        'video/mp4',
        'video/webm',
        'application/pdf',
        'text/plain',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
      ]
      return allowedTypes.includes(type)
    }, 'File type not allowed'),
  
  size: z
    .number()
    .max(100 * 1024 * 1024, 'File size cannot exceed 100MB'), // 100MB limit
})

// API request validation middleware
export function validateRequest<T>(schema: z.ZodSchema<T>) {
  return (handler: (req: NextApiRequest & { body: T }, res: NextApiResponse) => Promise<void>) => {
    return async (req: NextApiRequest, res: NextApiResponse) => {
      try {
        req.body = schema.parse(req.body)
        return handler(req as NextApiRequest & { body: T }, res)
      } catch (error) {
        if (error instanceof z.ZodError) {
          return res.status(400).json({
            error: 'Validation failed',
            details: error.errors.map(err => ({
              field: err.path.join('.'),
              message: err.message,
            })),
          })
        }
        
        console.error('Validation error:', error)
        return res.status(500).json({ error: 'Internal server error' })
      }
    }
  }
}
```

## 🛡️ CSRF & XSS Protection

### CSRF Protection Implementation

```typescript
// middleware.ts - CSRF protection
import { NextRequest, NextResponse } from 'next/server'
import { getToken } from 'next-auth/jwt'

const CSRF_TOKEN_HEADER = 'x-csrf-token'
const CSRF_TOKEN_COOKIE = 'csrf-token'

export async function middleware(request: NextRequest) {
  const { pathname, method } = request.nextUrl
  
  // Skip CSRF for safe methods and auth routes
  if (['GET', 'HEAD', 'OPTIONS'].includes(method) || pathname.startsWith('/api/auth/')) {
    return NextResponse.next()
  }
  
  // CSRF protection for state-changing requests
  if (pathname.startsWith('/api/')) {
    const token = await getToken({ req: request, secret: process.env.NEXTAUTH_SECRET })
    
    if (!token) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }
    
    const csrfToken = request.headers.get(CSRF_TOKEN_HEADER)
    const csrfCookie = request.cookies.get(CSRF_TOKEN_COOKIE)?.value
    
    if (!csrfToken || !csrfCookie || csrfToken !== csrfCookie) {
      return NextResponse.json({ error: 'CSRF token mismatch' }, { status: 403 })
    }
  }
  
  // Rate limiting by IP
  const ip = request.ip || request.headers.get('x-forwarded-for') || 'anonymous'
  const rateLimitResult = await checkRateLimit(ip, pathname)
  
  if (!rateLimitResult.success) {
    return NextResponse.json(
      { error: 'Too many requests' },
      { 
        status: 429,
        headers: {
          'Retry-After': rateLimitResult.retryAfter?.toString() || '60',
        },
      }
    )
  }
  
  // Security headers
  const response = NextResponse.next()
  
  response.headers.set('X-Frame-Options', 'DENY')
  response.headers.set('X-Content-Type-Options', 'nosniff')
  response.headers.set('X-XSS-Protection', '1; mode=block')
  response.headers.set('Referrer-Policy', 'strict-origin-when-cross-origin')
  response.headers.set(
    'Content-Security-Policy',
    [
      "default-src 'self'",
      "script-src 'self' 'unsafe-inline' 'unsafe-eval' https://js.stripe.com",
      "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com",
      "font-src 'self' https://fonts.gstatic.com",
      "img-src 'self' data: https:",
      "media-src 'self' https:",
      "frame-src https://js.stripe.com",
      "connect-src 'self' https://api.stripe.com",
    ].join('; ')
  )
  
  return response
}

export const config = {
  matcher: ['/api/:path*', '/dashboard/:path*', '/admin/:path*'],
}
```

### XSS Protection & Content Security Policy

```typescript
// lib/security.ts - XSS protection utilities
import DOMPurify from 'isomorphic-dompurify'

export function sanitizeHtml(html: string, options?: {
  allowedTags?: string[]
  allowedAttributes?: string[]
}): string {
  const defaultConfig = {
    ALLOWED_TAGS: [
      'p', 'br', 'strong', 'em', 'u', 'ol', 'ul', 'li',
      'h1', 'h2', 'h3', 'h4', 'h5', 'h6',
      'a', 'img', 'code', 'pre', 'blockquote'
    ],
    ALLOWED_ATTR: ['href', 'src', 'alt', 'title'],
    ALLOWED_URI_REGEXP: /^https?:\/\//,
  }
  
  const config = {
    ...defaultConfig,
    ...(options?.allowedTags && { ALLOWED_TAGS: options.allowedTags }),
    ...(options?.allowedAttributes && { ALLOWED_ATTR: options.allowedAttributes }),
  }
  
  return DOMPurify.sanitize(html, config)
}

export function escapeHtml(text: string): string {
  const htmlEscapes: Record<string, string> = {
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#x27;',
    '/': '&#x2F;',
  }
  
  return text.replace(/[&<>"'/]/g, (match) => htmlEscapes[match])
}

// React component for safe content rendering
interface SafeContentProps {
  content: string
  allowedTags?: string[]
  className?: string
}

export function SafeContent({ content, allowedTags, className }: SafeContentProps) {
  const sanitizedContent = sanitizeHtml(content, { allowedTags })
  
  return (
    <div
      className={className}
      dangerouslySetInnerHTML={{ __html: sanitizedContent }}
    />
  )
}
```

## 🔐 Data Encryption & Storage

### Sensitive Data Encryption

```typescript
// lib/encryption.ts - Data encryption utilities
import crypto from 'crypto'

const ALGORITHM = 'aes-256-gcm'
const SECRET_KEY = process.env.ENCRYPTION_SECRET! // 32 bytes key

export function encrypt(text: string): string {
  const iv = crypto.randomBytes(16)
  const cipher = crypto.createCipher(ALGORITHM, SECRET_KEY)
  cipher.setAAD(Buffer.from('education-platform', 'utf8'))
  
  let encrypted = cipher.update(text, 'utf8', 'hex')
  encrypted += cipher.final('hex')
  
  const authTag = cipher.getAuthTag()
  
  return `${iv.toString('hex')}:${authTag.toString('hex')}:${encrypted}`
}

export function decrypt(encryptedText: string): string {
  const [ivHex, authTagHex, encrypted] = encryptedText.split(':')
  
  const iv = Buffer.from(ivHex, 'hex')
  const authTag = Buffer.from(authTagHex, 'hex')
  
  const decipher = crypto.createDecipher(ALGORITHM, SECRET_KEY)
  decipher.setAAD(Buffer.from('education-platform', 'utf8'))
  decipher.setAuthTag(authTag)
  
  let decrypted = decipher.update(encrypted, 'hex', 'utf8')
  decrypted += decipher.final('utf8')
  
  return decrypted
}

// Database field encryption
export class EncryptedField {
  constructor(private value: string) {}
  
  static fromEncrypted(encryptedValue: string): EncryptedField {
    return new EncryptedField(decrypt(encryptedValue))
  }
  
  toEncrypted(): string {
    return encrypt(this.value)
  }
  
  getValue(): string {
    return this.value
  }
}

// Prisma middleware for automatic encryption
export function createEncryptionMiddleware() {
  return prisma.$use(async (params, next) => {
    // Encrypt sensitive fields before storage
    if (params.action === 'create' || params.action === 'update') {
      if (params.model === 'User' && params.args.data) {
        const data = params.args.data
        
        // Encrypt sensitive fields
        if (data.phoneNumber) {
          data.phoneNumber = encrypt(data.phoneNumber)
        }
        
        if (data.address) {
          data.address = encrypt(data.address)
        }
      }
      
      if (params.model === 'Payment' && params.args.data) {
        const data = params.args.data
        
        // Encrypt payment details (never store full card numbers)
        if (data.lastFourDigits) {
          data.lastFourDigits = encrypt(data.lastFourDigits)
        }
      }
    }
    
    const result = await next(params)
    
    // Decrypt sensitive fields after retrieval
    if (params.action === 'findUnique' || params.action === 'findMany') {
      if (params.model === 'User' && result) {
        const users = Array.isArray(result) ? result : [result]
        
        users.forEach(user => {
          if (user.phoneNumber) {
            user.phoneNumber = decrypt(user.phoneNumber)
          }
          if (user.address) {
            user.address = decrypt(user.address)
          }
        })
      }
    }
    
    return result
  })
}
```

## 📊 Audit Logging & Monitoring

### Comprehensive Audit System

```typescript
// lib/audit.ts - Audit logging system
import { prisma } from './db'

export enum AuditAction {
  // Authentication
  SIGN_IN = 'SIGN_IN',
  SIGN_OUT = 'SIGN_OUT',
  FAILED_LOGIN = 'FAILED_LOGIN',
  PASSWORD_RESET = 'PASSWORD_RESET',
  
  // User management
  USER_CREATED = 'USER_CREATED',
  USER_UPDATED = 'USER_UPDATED',
  USER_DELETED = 'USER_DELETED',
  ROLE_CHANGED = 'ROLE_CHANGED',
  
  // Course management
  COURSE_CREATED = 'COURSE_CREATED',
  COURSE_UPDATED = 'COURSE_UPDATED',
  COURSE_DELETED = 'COURSE_DELETED',
  COURSE_PUBLISHED = 'COURSE_PUBLISHED',
  
  // Financial
  PAYMENT_PROCESSED = 'PAYMENT_PROCESSED',
  REFUND_ISSUED = 'REFUND_ISSUED',
  
  // Data access
  SENSITIVE_DATA_ACCESSED = 'SENSITIVE_DATA_ACCESSED',
  BULK_DATA_EXPORT = 'BULK_DATA_EXPORT',
  
  // Security
  PERMISSION_DENIED = 'PERMISSION_DENIED',
  SUSPICIOUS_ACTIVITY = 'SUSPICIOUS_ACTIVITY',
}

interface AuditDetails {
  [key: string]: any
  userAgent?: string
  ip?: string
  previousValues?: Record<string, any>
  newValues?: Record<string, any>
}

export async function createAuditLog(
  action: AuditAction,
  userId?: string,
  targetId?: string,
  details?: AuditDetails
) {
  try {
    await prisma.auditLog.create({
      data: {
        action,
        userId,
        targetId,
        details: details || {},
        timestamp: new Date(),
        ip: details?.ip,
        userAgent: details?.userAgent,
      },
    })
  } catch (error) {
    console.error('Failed to create audit log:', error)
    // Don't throw error to avoid breaking main functionality
  }
}

// Audit middleware for API routes
export function withAudit(action: AuditAction) {
  return function (handler: NextApiHandler): NextApiHandler {
    return async (req, res) => {
      const startTime = Date.now()
      const session = await getServerSession(req, res, authOptions)
      
      try {
        const result = await handler(req, res)
        
        // Log successful action
        await createAuditLog(action, session?.user?.id, undefined, {
          method: req.method,
          url: req.url,
          userAgent: req.headers['user-agent'],
          ip: req.socket.remoteAddress,
          duration: Date.now() - startTime,
          success: true,
        })
        
        return result
      } catch (error) {
        // Log failed action
        await createAuditLog(action, session?.user?.id, undefined, {
          method: req.method,
          url: req.url,
          userAgent: req.headers['user-agent'],
          ip: req.socket.remoteAddress,
          duration: Date.now() - startTime,
          success: false,
          error: error.message,
        })
        
        throw error
      }
    }
  }
}

// Security monitoring
export class SecurityMonitor {
  private static instance: SecurityMonitor
  private suspiciousActivityThreshold = 5
  private timeWindowMs = 15 * 60 * 1000 // 15 minutes
  
  static getInstance(): SecurityMonitor {
    if (!this.instance) {
      this.instance = new SecurityMonitor()
    }
    return this.instance
  }
  
  async checkSuspiciousActivity(userId: string, action: AuditAction): Promise<boolean> {
    const recentLogs = await prisma.auditLog.findMany({
      where: {
        userId,
        action,
        timestamp: {
          gte: new Date(Date.now() - this.timeWindowMs),
        },
      },
    })
    
    if (recentLogs.length >= this.suspiciousActivityThreshold) {
      await createAuditLog(AuditAction.SUSPICIOUS_ACTIVITY, userId, undefined, {
        suspiciousAction: action,
        occurrences: recentLogs.length,
        timeWindow: this.timeWindowMs,
      })
      
      // Optionally lock account or require additional verification
      await this.handleSuspiciousActivity(userId, action)
      
      return true
    }
    
    return false
  }
  
  private async handleSuspiciousActivity(userId: string, action: AuditAction) {
    // Implement appropriate response (account lock, notification, etc.)
    if (action === AuditAction.FAILED_LOGIN) {
      await prisma.user.update({
        where: { id: userId },
        data: {
          lockedUntil: new Date(Date.now() + 30 * 60 * 1000), // Lock for 30 minutes
        },
      })
    }
    
    // Send alert to administrators
    await this.sendSecurityAlert(userId, action)
  }
  
  private async sendSecurityAlert(userId: string, action: AuditAction) {
    // Implementation depends on your notification system
    console.log(`SECURITY ALERT: Suspicious activity detected for user ${userId}: ${action}`)
    
    // Send email to security team
    // await sendEmail({
    //   to: process.env.SECURITY_EMAIL,
    //   subject: 'Security Alert: Suspicious Activity Detected',
    //   body: `Suspicious activity detected for user ${userId}: ${action}`,
    // })
  }
}
```

## 🌍 Compliance & Data Protection

### GDPR Compliance Implementation

```typescript
// lib/gdpr.ts - GDPR compliance utilities
import { prisma } from './db'

export enum DataProcessingPurpose {
  ACCOUNT_MANAGEMENT = 'ACCOUNT_MANAGEMENT',
  COURSE_DELIVERY = 'COURSE_DELIVERY',
  PAYMENT_PROCESSING = 'PAYMENT_PROCESSING',
  MARKETING = 'MARKETING',
  ANALYTICS = 'ANALYTICS',
}

export enum LegalBasis {
  CONSENT = 'CONSENT',
  CONTRACT = 'CONTRACT',
  LEGAL_OBLIGATION = 'LEGAL_OBLIGATION',
  VITAL_INTERESTS = 'VITAL_INTERESTS',
  PUBLIC_TASK = 'PUBLIC_TASK',
  LEGITIMATE_INTERESTS = 'LEGITIMATE_INTERESTS',
}

// Data processing record
export async function recordDataProcessing(
  userId: string,
  purpose: DataProcessingPurpose,
  legalBasis: LegalBasis,
  dataTypes: string[],
  retentionPeriod: number // in days
) {
  await prisma.dataProcessingRecord.create({
    data: {
      userId,
      purpose,
      legalBasis,
      dataTypes,
      retentionPeriod,
      createdAt: new Date(),
    },
  })
}

// Consent management
export class ConsentManager {
  static async recordConsent(
    userId: string,
    purpose: DataProcessingPurpose,
    granted: boolean
  ) {
    await prisma.userConsent.upsert({
      where: {
        userId_purpose: {
          userId,
          purpose,
        },
      },
      update: {
        granted,
        grantedAt: granted ? new Date() : null,
        revokedAt: !granted ? new Date() : null,
      },
      create: {
        userId,
        purpose,
        granted,
        grantedAt: granted ? new Date() : null,
        revokedAt: !granted ? new Date() : null,
      },
    })
  }
  
  static async checkConsent(
    userId: string,
    purpose: DataProcessingPurpose
  ): Promise<boolean> {
    const consent = await prisma.userConsent.findUnique({
      where: {
        userId_purpose: {
          userId,
          purpose,
        },
      },
    })
    
    return consent?.granted ?? false
  }
  
  static async getUserConsents(userId: string) {
    return await prisma.userConsent.findMany({
      where: { userId },
    })
  }
}

// Data subject rights
export class DataSubjectRights {
  static async exportUserData(userId: string) {
    const user = await prisma.user.findUnique({
      where: { id: userId },
      include: {
        enrollments: {
          include: {
            course: {
              select: { title: true, slug: true },
            },
          },
        },
        progress: {
          include: {
            lesson: {
              select: { title: true },
            },
          },
        },
        payments: {
          select: {
            id: true,
            amount: true,
            status: true,
            createdAt: true,
            // Exclude sensitive payment details
          },
        },
        auditLogs: {
          select: {
            action: true,
            timestamp: true,
            // Exclude sensitive details
          },
        },
      },
    })
    
    if (!user) {
      throw new Error('User not found')
    }
    
    // Remove sensitive fields
    const { password, ...exportData } = user
    
    return {
      exportDate: new Date().toISOString(),
      userData: exportData,
    }
  }
  
  static async deleteUserData(userId: string, retainLegal = true) {
    await prisma.$transaction(async (tx) => {
      if (retainLegal) {
        // Anonymize user data while retaining legally required information
        await tx.user.update({
          where: { id: userId },
          data: {
            name: 'Deleted User',
            email: `deleted_${userId}@example.com`,
            password: 'DELETED',
            phoneNumber: null,
            address: null,
            dateOfBirth: null,
            deletedAt: new Date(),
          },
        })
      } else {
        // Complete deletion (use carefully - may violate legal requirements)
        await tx.progress.deleteMany({ where: { userId } })
        await tx.enrollment.deleteMany({ where: { userId } })
        await tx.auditLog.deleteMany({ where: { userId } })
        await tx.user.delete({ where: { id: userId } })
      }
    })
    
    await createAuditLog(AuditAction.USER_DELETED, userId, undefined, {
      retainLegal,
      deletedAt: new Date().toISOString(),
    })
  }
  
  static async rectifyUserData(userId: string, updates: Record<string, any>) {
    const previousData = await prisma.user.findUnique({
      where: { id: userId },
      select: Object.keys(updates).reduce((acc, key) => {
        acc[key] = true
        return acc
      }, {} as Record<string, boolean>),
    })
    
    await prisma.user.update({
      where: { id: userId },
      data: updates,
    })
    
    await createAuditLog(AuditAction.USER_UPDATED, userId, undefined, {
      previousValues: previousData,
      newValues: updates,
      reason: 'Data rectification request',
    })
  }
}
```

### FERPA Compliance for Educational Records

```typescript
// lib/ferpa.ts - FERPA compliance for educational records
import { prisma } from './db'

export enum EducationalRecordType {
  GRADES = 'GRADES',
  ATTENDANCE = 'ATTENDANCE',
  PROGRESS = 'PROGRESS',
  DISCIPLINARY = 'DISCIPLINARY',
  HEALTH = 'HEALTH',
  FINANCIAL = 'FINANCIAL',
}

export class FERPACompliance {
  static async recordAccess(
    studentId: string,
    accessorId: string,
    recordType: EducationalRecordType,
    purpose: string
  ) {
    await prisma.educationalRecordAccess.create({
      data: {
        studentId,
        accessorId,
        recordType,
        purpose,
        accessedAt: new Date(),
      },
    })
  }
  
  static async checkAccessPermission(
    studentId: string,
    accessorId: string,
    recordType: EducationalRecordType
  ): Promise<boolean> {
    // Student can always access their own records
    if (studentId === accessorId) {
      return true
    }
    
    const accessor = await prisma.user.findUnique({
      where: { id: accessorId },
      select: { role: true },
    })
    
    // Administrators and instructors have access to educational records
    if (accessor?.role === 'ADMIN' || accessor?.role === 'SUPER_ADMIN') {
      return true
    }
    
    // Instructors can access records for their students
    if (accessor?.role === 'INSTRUCTOR') {
      const enrollment = await prisma.enrollment.findFirst({
        where: {
          userId: studentId,
          course: {
            instructorId: accessorId,
          },
        },
      })
      
      return !!enrollment
    }
    
    return false
  }
  
  static async getAccessLog(studentId: string) {
    return await prisma.educationalRecordAccess.findMany({
      where: { studentId },
      include: {
        accessor: {
          select: {
            name: true,
            email: true,
            role: true,
          },
        },
      },
      orderBy: { accessedAt: 'desc' },
    })
  }
}
```

## 🔐 Payment Security

### PCI Compliance for Payment Processing

```typescript
// lib/payment-security.ts - Secure payment handling
import Stripe from 'stripe'

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, {
  apiVersion: '2023-10-16',
})

export class PaymentSecurity {
  // Never store card details - use Stripe's secure tokenization
  static async createPaymentIntent(
    amount: number,
    currency: string,
    studentId: string,
    courseId: string
  ) {
    try {
      const paymentIntent = await stripe.paymentIntents.create({
        amount: amount * 100, // Stripe uses cents
        currency: currency.toLowerCase(),
        metadata: {
          studentId,
          courseId,
          platform: 'education-platform',
        },
        // Enable 3D Secure authentication
        confirmation_method: 'manual',
        confirm: false,
      })
      
      // Log payment attempt
      await createAuditLog(AuditAction.PAYMENT_PROCESSED, studentId, courseId, {
        paymentIntentId: paymentIntent.id,
        amount,
        currency,
        status: 'intent_created',
      })
      
      return {
        clientSecret: paymentIntent.client_secret,
        paymentIntentId: paymentIntent.id,
      }
    } catch (error) {
      console.error('Payment intent creation failed:', error)
      throw new Error('Payment processing failed')
    }
  }
  
  static async confirmPayment(paymentIntentId: string, studentId: string) {
    try {
      const paymentIntent = await stripe.paymentIntents.confirm(paymentIntentId)
      
      if (paymentIntent.status === 'succeeded') {
        // Store minimal payment information
        await prisma.payment.create({
          data: {
            stripePaymentIntentId: paymentIntentId,
            userId: studentId,
            courseId: paymentIntent.metadata.courseId,
            amount: paymentIntent.amount / 100,
            currency: paymentIntent.currency.toUpperCase(),
            status: 'COMPLETED',
            // Never store card details - only last 4 digits from Stripe
            lastFourDigits: paymentIntent.charges.data[0]?.payment_method_details?.card?.last4,
            cardBrand: paymentIntent.charges.data[0]?.payment_method_details?.card?.brand,
          },
        })
        
        await createAuditLog(AuditAction.PAYMENT_PROCESSED, studentId, paymentIntent.metadata.courseId, {
          paymentIntentId,
          amount: paymentIntent.amount / 100,
          status: 'succeeded',
        })
      }
      
      return paymentIntent
    } catch (error) {
      console.error('Payment confirmation failed:', error)
      
      await createAuditLog(AuditAction.PAYMENT_PROCESSED, studentId, undefined, {
        paymentIntentId,
        status: 'failed',
        error: error.message,
      })
      
      throw new Error('Payment confirmation failed')
    }
  }
  
  // Secure refund processing
  static async processRefund(
    paymentId: string,
    adminId: string,
    reason: string,
    amount?: number
  ) {
    const payment = await prisma.payment.findUnique({
      where: { id: paymentId },
    })
    
    if (!payment) {
      throw new Error('Payment not found')
    }
    
    try {
      const refund = await stripe.refunds.create({
        payment_intent: payment.stripePaymentIntentId,
        amount: amount ? amount * 100 : undefined, // Partial or full refund
        reason: 'requested_by_customer',
        metadata: {
          adminId,
          reason,
          originalPaymentId: paymentId,
        },
      })
      
      await prisma.refund.create({
        data: {
          stripeRefundId: refund.id,
          paymentId,
          amount: refund.amount / 100,
          reason,
          status: 'COMPLETED',
          processedBy: adminId,
        },
      })
      
      await createAuditLog(AuditAction.REFUND_ISSUED, adminId, payment.userId, {
        paymentId,
        refundId: refund.id,
        amount: refund.amount / 100,
        reason,
      })
      
      return refund
    } catch (error) {
      console.error('Refund processing failed:', error)
      throw new Error('Refund processing failed')
    }
  }
}
```

## 🔗 Related Documentation

### Previous: [Comparison Analysis](./comparison-analysis.md)
### Next: [Testing Strategies](./testing-strategies.md)

---

*Security Considerations | Next.js Full Stack Development | 2024*