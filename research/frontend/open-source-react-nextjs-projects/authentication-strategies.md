# Authentication Strategies in Open Source React/Next.js Projects

## Overview

This comprehensive analysis examines authentication and security patterns implemented in production React and Next.js applications. The research covers authentication flows, session management, security best practices, and real-world implementations from successful open source projects.

## Authentication Approaches Analysis

### 1. NextAuth.js Implementations

**Cal.com - Enterprise Multi-Provider Authentication**

Cal.com demonstrates sophisticated authentication with NextAuth.js v5, supporting multiple providers and team management.

```typescript
// auth.config.ts
import { NextAuthConfig } from 'next-auth';
import Google from 'next-auth/providers/google';
import GitHub from 'next-auth/providers/github';
import Credentials from 'next-auth/providers/credentials';

export const authConfig: NextAuthConfig = {
  providers: [
    Google({
      clientId: process.env.GOOGLE_CLIENT_ID,
      clientSecret: process.env.GOOGLE_CLIENT_SECRET,
    }),
    GitHub({
      clientId: process.env.GITHUB_CLIENT_ID,
      clientSecret: process.env.GITHUB_CLIENT_SECRET,
    }),
    Credentials({
      credentials: {
        email: { label: 'Email', type: 'email' },
        password: { label: 'Password', type: 'password' },
      },
      async authorize(credentials) {
        const user = await authenticateUser(credentials);
        return user ? { id: user.id, email: user.email, name: user.name } : null;
      },
    }),
  ],
  callbacks: {
    async jwt({ token, user, account, profile }) {
      if (user) {
        token.id = user.id;
        token.role = user.role;
        token.teamId = user.teamId;
      }
      return token;
    },
    async session({ session, token }) {
      if (token) {
        session.user.id = token.id as string;
        session.user.role = token.role as string;
        session.user.teamId = token.teamId as string;
      }
      return session;
    },
    async redirect({ url, baseUrl }) {
      // Redirect to dashboard after login
      if (url.startsWith('/auth')) return `${baseUrl}/dashboard`;
      return url.startsWith(baseUrl) ? url : baseUrl;
    },
  },
  pages: {
    signIn: '/auth/signin',
    signOut: '/auth/signout',
    error: '/auth/error',
    verifyRequest: '/auth/verify-request',
  },
  events: {
    async signIn({ user, account, profile, isNewUser }) {
      // Track sign-in events
      await trackUserSignIn(user.id, account?.provider);
    },
    async signOut({ token }) {
      // Clean up user sessions
      await invalidateUserSessions(token.id as string);
    },
  },
};
```

**Key Cal.com Authentication Patterns:**

- **Team-based access control** with role-based permissions
- **Multi-provider support** for enterprise SSO integration
- **Session management** with automatic cleanup
- **Event tracking** for security monitoring
- **Custom redirect logic** for different user types

### 2. Supabase Authentication Patterns

**Supabase Dashboard - Row Level Security (RLS)**

The Supabase dashboard showcases advanced authentication with built-in RLS and real-time features.

```typescript
// lib/supabase.ts
import { createClientComponentClient } from '@supabase/auth-helpers-nextjs';
import { Database } from '@/types/database';

export const supabase = createClientComponentClient<Database>();

// Authentication helper
export class AuthService {
  static async signInWithEmail(email: string, password: string) {
    const { data, error } = await supabase.auth.signInWithPassword({
      email,
      password,
    });
    
    if (error) throw error;
    return data;
  }

  static async signInWithProvider(provider: 'google' | 'github') {
    const { data, error } = await supabase.auth.signInWithOAuth({
      provider,
      options: {
        redirectTo: `${location.origin}/auth/callback`,
      },
    });
    
    if (error) throw error;
    return data;
  }

  static async signUp(email: string, password: string, metadata?: object) {
    const { data, error } = await supabase.auth.signUp({
      email,
      password,
      options: {
        data: metadata,
      },
    });
    
    if (error) throw error;
    return data;
  }

  static async signOut() {
    const { error } = await supabase.auth.signOut();
    if (error) throw error;
  }

  static async resetPassword(email: string) {
    const { error } = await supabase.auth.resetPasswordForEmail(email, {
      redirectTo: `${location.origin}/auth/reset-password`,
    });
    
    if (error) throw error;
  }

  static async updatePassword(password: string) {
    const { error } = await supabase.auth.updateUser({ password });
    if (error) throw error;
  }
}
```

**Row Level Security Policies**:
```sql
-- Users can only see their own data
CREATE POLICY "Users can view own profile" ON profiles
  FOR SELECT USING (auth.uid() = user_id);

-- Team members can view team data
CREATE POLICY "Team members can view team data" ON projects
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM team_members 
      WHERE team_id = projects.team_id 
      AND user_id = auth.uid()
    )
  );

-- Admin users can manage everything
CREATE POLICY "Admin full access" ON projects
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE user_id = auth.uid() 
      AND role = 'admin'
    )
  );
```

### 3. Custom JWT Authentication

**Outline - Team Workspace Authentication**

Outline implements custom JWT authentication with workspace-based access control.

```typescript
// lib/auth.ts
import jwt from 'jsonwebtoken';
import bcrypt from 'bcryptjs';
import { User, Team } from '@/types';

export class AuthService {
  private static readonly JWT_SECRET = process.env.JWT_SECRET!;
  private static readonly JWT_EXPIRES_IN = '7d';
  private static readonly REFRESH_TOKEN_EXPIRES_IN = '30d';

  static async authenticate(email: string, password: string): Promise<AuthResult> {
    const user = await User.findOne({ 
      where: { email },
      include: [Team],
    });

    if (!user || !await bcrypt.compare(password, user.passwordHash)) {
      throw new Error('Invalid credentials');
    }

    const tokens = this.generateTokens(user);
    await this.saveRefreshToken(user.id, tokens.refreshToken);

    return {
      user: this.sanitizeUser(user),
      tokens,
    };
  }

  static generateTokens(user: User): TokenPair {
    const payload = {
      id: user.id,
      email: user.email,
      teamId: user.teamId,
      role: user.role,
    };

    const accessToken = jwt.sign(payload, this.JWT_SECRET, {
      expiresIn: this.JWT_EXPIRES_IN,
    });

    const refreshToken = jwt.sign(
      { id: user.id, type: 'refresh' },
      this.JWT_SECRET,
      { expiresIn: this.REFRESH_TOKEN_EXPIRES_IN }
    );

    return { accessToken, refreshToken };
  }

  static async refreshTokens(refreshToken: string): Promise<TokenPair> {
    try {
      const decoded = jwt.verify(refreshToken, this.JWT_SECRET) as any;
      
      const user = await User.findByPk(decoded.id, { include: [Team] });
      if (!user) throw new Error('User not found');

      const isValidRefreshToken = await this.validateRefreshToken(
        user.id, 
        refreshToken
      );
      if (!isValidRefreshToken) throw new Error('Invalid refresh token');

      // Rotate refresh token
      await this.invalidateRefreshToken(user.id, refreshToken);
      
      const tokens = this.generateTokens(user);
      await this.saveRefreshToken(user.id, tokens.refreshToken);

      return tokens;
    } catch (error) {
      throw new Error('Invalid refresh token');
    }
  }

  static async validateAccessToken(token: string): Promise<User | null> {
    try {
      const decoded = jwt.verify(token, this.JWT_SECRET) as any;
      const user = await User.findByPk(decoded.id, { include: [Team] });
      return user;
    } catch (error) {
      return null;
    }
  }

  private static async saveRefreshToken(userId: string, token: string) {
    const hashedToken = await bcrypt.hash(token, 10);
    await RefreshToken.create({
      userId,
      tokenHash: hashedToken,
      expiresAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000), // 30 days
    });
  }

  private static async validateRefreshToken(userId: string, token: string): Promise<boolean> {
    const storedTokens = await RefreshToken.findAll({
      where: { userId, expiresAt: { [Op.gt]: new Date() } },
    });

    for (const storedToken of storedTokens) {
      if (await bcrypt.compare(token, storedToken.tokenHash)) {
        return true;
      }
    }

    return false;
  }
}
```

### 4. Frontend Authentication Hooks

**Universal Authentication Hook**:
```typescript
// hooks/useAuth.ts
import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';

interface AuthState {
  user: User | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  error: string | null;
}

export function useAuth(): AuthState & AuthActions {
  const [state, setState] = useState<AuthState>({
    user: null,
    isAuthenticated: false,
    isLoading: true,
    error: null,
  });
  
  const router = useRouter();

  useEffect(() => {
    checkAuthStatus();
  }, []);

  const checkAuthStatus = async () => {
    try {
      setState(prev => ({ ...prev, isLoading: true, error: null }));
      
      const token = localStorage.getItem('accessToken');
      if (!token) {
        setState(prev => ({ ...prev, isLoading: false }));
        return;
      }

      const user = await validateToken(token);
      setState({
        user,
        isAuthenticated: !!user,
        isLoading: false,
        error: null,
      });
    } catch (error) {
      // Token expired, try refresh
      try {
        await refreshAuthToken();
      } catch (refreshError) {
        setState({
          user: null,
          isAuthenticated: false,
          isLoading: false,
          error: 'Session expired',
        });
        logout();
      }
    }
  };

  const login = async (email: string, password: string) => {
    try {
      setState(prev => ({ ...prev, isLoading: true, error: null }));
      
      const { user, tokens } = await AuthService.authenticate(email, password);
      
      localStorage.setItem('accessToken', tokens.accessToken);
      localStorage.setItem('refreshToken', tokens.refreshToken);
      
      setState({
        user,
        isAuthenticated: true,
        isLoading: false,
        error: null,
      });
      
      router.push('/dashboard');
    } catch (error) {
      setState(prev => ({
        ...prev,
        isLoading: false,
        error: error.message,
      }));
    }
  };

  const logout = async () => {
    try {
      const refreshToken = localStorage.getItem('refreshToken');
      if (refreshToken) {
        await AuthService.logout(refreshToken);
      }
    } catch (error) {
      console.error('Logout error:', error);
    } finally {
      localStorage.removeItem('accessToken');
      localStorage.removeItem('refreshToken');
      setState({
        user: null,
        isAuthenticated: false,
        isLoading: false,
        error: null,
      });
      router.push('/auth/login');
    }
  };

  return {
    ...state,
    login,
    logout,
    checkAuthStatus,
  };
}

// Protected route hook
export function useRequireAuth() {
  const { isAuthenticated, isLoading } = useAuth();
  const router = useRouter();

  useEffect(() => {
    if (!isLoading && !isAuthenticated) {
      router.push('/auth/login');
    }
  }, [isAuthenticated, isLoading, router]);

  return { isAuthenticated, isLoading };
}
```

## Role-Based Access Control (RBAC)

### 1. Permission System Design

**Twenty CRM - Workspace Permissions**:
```typescript
// types/permissions.ts
export enum Permission {
  // User management
  USER_READ = 'user:read',
  USER_WRITE = 'user:write',
  USER_DELETE = 'user:delete',
  
  // Project management
  PROJECT_READ = 'project:read',
  PROJECT_WRITE = 'project:write',
  PROJECT_DELETE = 'project:delete',
  
  // Admin permissions
  WORKSPACE_MANAGE = 'workspace:manage',
  BILLING_MANAGE = 'billing:manage',
}

export enum Role {
  OWNER = 'owner',
  ADMIN = 'admin',
  MEMBER = 'member',
  VIEWER = 'viewer',
}

export const ROLE_PERMISSIONS: Record<Role, Permission[]> = {
  [Role.OWNER]: Object.values(Permission),
  [Role.ADMIN]: [
    Permission.USER_READ,
    Permission.USER_WRITE,
    Permission.PROJECT_READ,
    Permission.PROJECT_WRITE,
    Permission.PROJECT_DELETE,
  ],
  [Role.MEMBER]: [
    Permission.USER_READ,
    Permission.PROJECT_READ,
    Permission.PROJECT_WRITE,
  ],
  [Role.VIEWER]: [
    Permission.USER_READ,
    Permission.PROJECT_READ,
  ],
};

// Permission checker
export class PermissionService {
  static hasPermission(userRole: Role, permission: Permission): boolean {
    return ROLE_PERMISSIONS[userRole]?.includes(permission) ?? false;
  }

  static hasAnyPermission(userRole: Role, permissions: Permission[]): boolean {
    return permissions.some(permission => 
      this.hasPermission(userRole, permission)
    );
  }

  static hasAllPermissions(userRole: Role, permissions: Permission[]): boolean {
    return permissions.every(permission => 
      this.hasPermission(userRole, permission)
    );
  }
}
```

### 2. Frontend Permission Components

**Permission-based Rendering**:
```typescript
// components/PermissionGate.tsx
import { useAuth } from '@/hooks/useAuth';
import { Permission, PermissionService } from '@/lib/permissions';

interface PermissionGateProps {
  permission: Permission | Permission[];
  children: React.ReactNode;
  fallback?: React.ReactNode;
  requireAll?: boolean;
}

export function PermissionGate({
  permission,
  children,
  fallback = null,
  requireAll = false,
}: PermissionGateProps) {
  const { user } = useAuth();

  if (!user) return fallback;

  const permissions = Array.isArray(permission) ? permission : [permission];
  const hasPermission = requireAll
    ? PermissionService.hasAllPermissions(user.role, permissions)
    : PermissionService.hasAnyPermission(user.role, permissions);

  return hasPermission ? <>{children}</> : <>{fallback}</>;
}

// Usage examples
function ProjectSettings() {
  return (
    <PermissionGate permission={Permission.PROJECT_WRITE}>
      <button>Edit Project</button>
    </PermissionGate>
  );
}

function AdminPanel() {
  return (
    <PermissionGate
      permission={[Permission.USER_WRITE, Permission.WORKSPACE_MANAGE]}
      requireAll
    >
      <AdminDashboard />
    </PermissionGate>
  );
}
```

**Permission Hook**:
```typescript
// hooks/usePermissions.ts
import { useAuth } from './useAuth';
import { Permission, PermissionService } from '@/lib/permissions';

export function usePermissions() {
  const { user } = useAuth();

  const hasPermission = (permission: Permission): boolean => {
    if (!user) return false;
    return PermissionService.hasPermission(user.role, permission);
  };

  const hasAnyPermission = (permissions: Permission[]): boolean => {
    if (!user) return false;
    return PermissionService.hasAnyPermission(user.role, permissions);
  };

  const hasAllPermissions = (permissions: Permission[]): boolean => {
    if (!user) return false;
    return PermissionService.hasAllPermissions(user.role, permissions);
  };

  return {
    hasPermission,
    hasAnyPermission,
    hasAllPermissions,
    userRole: user?.role,
  };
}

// Usage in components
function ProjectActions() {
  const { hasPermission } = usePermissions();
  
  return (
    <div>
      {hasPermission(Permission.PROJECT_WRITE) && (
        <button>Edit</button>
      )}
      {hasPermission(Permission.PROJECT_DELETE) && (
        <button>Delete</button>
      )}
    </div>
  );
}
```

## Security Best Practices

### 1. Token Security

**Secure Token Storage**:
```typescript
// lib/tokenStorage.ts
class SecureTokenStorage {
  private static readonly ACCESS_TOKEN_KEY = 'accessToken';
  private static readonly REFRESH_TOKEN_KEY = 'refreshToken';

  static setTokens(accessToken: string, refreshToken: string) {
    // Use httpOnly cookies for refresh tokens in production
    if (typeof window !== 'undefined') {
      // Temporary storage for access token (shorter lived)
      sessionStorage.setItem(this.ACCESS_TOKEN_KEY, accessToken);
      
      // Use secure cookie for refresh token
      document.cookie = `${this.REFRESH_TOKEN_KEY}=${refreshToken}; HttpOnly; Secure; SameSite=Strict; Max-Age=2592000`; // 30 days
    }
  }

  static getAccessToken(): string | null {
    if (typeof window !== 'undefined') {
      return sessionStorage.getItem(this.ACCESS_TOKEN_KEY);
    }
    return null;
  }

  static getRefreshToken(): string | null {
    if (typeof window !== 'undefined') {
      return this.getCookie(this.REFRESH_TOKEN_KEY);
    }
    return null;
  }

  static clearTokens() {
    if (typeof window !== 'undefined') {
      sessionStorage.removeItem(this.ACCESS_TOKEN_KEY);
      document.cookie = `${this.REFRESH_TOKEN_KEY}=; expires=Thu, 01 Jan 1970 00:00:00 UTC; path=/;`;
    }
  }

  private static getCookie(name: string): string | null {
    const value = `; ${document.cookie}`;
    const parts = value.split(`; ${name}=`);
    if (parts.length === 2) {
      return parts.pop()?.split(';').shift() ?? null;
    }
    return null;
  }
}
```

### 2. API Security Middleware

**Request Interceptor with Auto-Refresh**:
```typescript
// lib/apiClient.ts
import axios, { AxiosResponse, InternalAxiosRequestConfig } from 'axios';
import { SecureTokenStorage } from './tokenStorage';

class APIClient {
  private api = axios.create({
    baseURL: process.env.NEXT_PUBLIC_API_URL,
    timeout: 10000,
  });

  private isRefreshing = false;
  private failedQueue: Array<{
    resolve: (value: any) => void;
    reject: (error: any) => void;
  }> = [];

  constructor() {
    this.setupInterceptors();
  }

  private setupInterceptors() {
    // Request interceptor
    this.api.interceptors.request.use(
      (config: InternalAxiosRequestConfig) => {
        const token = SecureTokenStorage.getAccessToken();
        if (token) {
          config.headers.Authorization = `Bearer ${token}`;
        }
        return config;
      },
      (error) => Promise.reject(error)
    );

    // Response interceptor
    this.api.interceptors.response.use(
      (response: AxiosResponse) => response,
      async (error) => {
        const originalRequest = error.config;

        if (error.response?.status === 401 && !originalRequest._retry) {
          if (this.isRefreshing) {
            // Queue the request
            return new Promise((resolve, reject) => {
              this.failedQueue.push({ resolve, reject });
            }).then(token => {
              originalRequest.headers.Authorization = `Bearer ${token}`;
              return this.api(originalRequest);
            }).catch(err => {
              return Promise.reject(err);
            });
          }

          originalRequest._retry = true;
          this.isRefreshing = true;

          try {
            const refreshToken = SecureTokenStorage.getRefreshToken();
            if (!refreshToken) {
              throw new Error('No refresh token');
            }

            const response = await this.refreshToken(refreshToken);
            const { accessToken, refreshToken: newRefreshToken } = response.data;

            SecureTokenStorage.setTokens(accessToken, newRefreshToken);
            
            // Process failed queue
            this.processQueue(null, accessToken);
            
            originalRequest.headers.Authorization = `Bearer ${accessToken}`;
            return this.api(originalRequest);
          } catch (refreshError) {
            this.processQueue(refreshError, null);
            SecureTokenStorage.clearTokens();
            window.location.href = '/auth/login';
            return Promise.reject(refreshError);
          } finally {
            this.isRefreshing = false;
          }
        }

        return Promise.reject(error);
      }
    );
  }

  private async refreshToken(refreshToken: string) {
    return axios.post('/api/auth/refresh', { refreshToken });
  }

  private processQueue(error: any, token: string | null) {
    this.failedQueue.forEach(({ resolve, reject }) => {
      if (error) {
        reject(error);
      } else {
        resolve(token);
      }
    });
    
    this.failedQueue = [];
  }

  async get<T>(url: string, config?: any): Promise<T> {
    const response = await this.api.get<T>(url, config);
    return response.data;
  }

  async post<T>(url: string, data?: any, config?: any): Promise<T> {
    const response = await this.api.post<T>(url, data, config);
    return response.data;
  }

  // ... other HTTP methods
}

export const apiClient = new APIClient();
```

### 3. Input Validation and Sanitization

**Form Validation with Security**:
```typescript
// lib/validation.ts
import { z } from 'zod';
import DOMPurify from 'dompurify';

// Security-focused validation schemas
export const authSchemas = {
  email: z
    .string()
    .email('Invalid email format')
    .max(254, 'Email too long')
    .transform(email => email.toLowerCase().trim()),
    
  password: z
    .string()
    .min(8, 'Password must be at least 8 characters')
    .max(128, 'Password too long')
    .regex(
      /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]/,
      'Password must contain uppercase, lowercase, number, and special character'
    ),
    
  name: z
    .string()
    .min(1, 'Name is required')
    .max(100, 'Name too long')
    .transform(name => DOMPurify.sanitize(name.trim())),
};

export const loginSchema = z.object({
  email: authSchemas.email,
  password: z.string().min(1, 'Password is required'),
});

export const registerSchema = z.object({
  email: authSchemas.email,
  password: authSchemas.password,
  name: authSchemas.name,
  confirmPassword: z.string(),
}).refine(data => data.password === data.confirmPassword, {
  message: "Passwords don't match",
  path: ["confirmPassword"],
});

// Rate limiting helper
export class RateLimiter {
  private attempts = new Map<string, { count: number; resetTime: number }>();

  isAllowed(key: string, maxAttempts: number = 5, windowMs: number = 15 * 60 * 1000): boolean {
    const now = Date.now();
    const attempt = this.attempts.get(key);

    if (!attempt || now > attempt.resetTime) {
      this.attempts.set(key, { count: 1, resetTime: now + windowMs });
      return true;
    }

    if (attempt.count >= maxAttempts) {
      return false;
    }

    attempt.count++;
    return true;
  }

  reset(key: string) {
    this.attempts.delete(key);
  }
}

export const authRateLimiter = new RateLimiter();
```

## Authentication UI Components

### 1. Login Form with Security Features

```typescript
// components/auth/LoginForm.tsx
import { useState } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { loginSchema } from '@/lib/validation';
import { useAuth } from '@/hooks/useAuth';
import { authRateLimiter } from '@/lib/validation';

type LoginFormData = z.infer<typeof loginSchema>;

export function LoginForm() {
  const [showPassword, setShowPassword] = useState(false);
  const [isRateLimited, setIsRateLimited] = useState(false);
  const { login } = useAuth();

  const form = useForm<LoginFormData>({
    resolver: zodResolver(loginSchema),
    defaultValues: {
      email: '',
      password: '',
    },
  });

  const onSubmit = async (data: LoginFormData) => {
    const clientIP = await getClientIP(); // Implement IP detection
    
    if (!authRateLimiter.isAllowed(`login:${clientIP}`)) {
      setIsRateLimited(true);
      return;
    }

    try {
      await login(data.email, data.password);
      authRateLimiter.reset(`login:${clientIP}`);
    } catch (error) {
      // Handle login error
      form.setError('root', {
        message: error.message,
      });
    }
  };

  if (isRateLimited) {
    return (
      <div className="text-center p-6">
        <h2 className="text-xl font-semibold text-red-600">Too Many Attempts</h2>
        <p className="text-gray-600">Please try again in 15 minutes.</p>
      </div>
    );
  }

  return (
    <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-4">
      <div>
        <label htmlFor="email" className="block text-sm font-medium">
          Email
        </label>
        <input
          {...form.register('email')}
          type="email"
          autoComplete="email"
          className="mt-1 block w-full rounded-md border border-gray-300 px-3 py-2"
        />
        {form.formState.errors.email && (
          <p className="mt-1 text-sm text-red-600">
            {form.formState.errors.email.message}
          </p>
        )}
      </div>

      <div>
        <label htmlFor="password" className="block text-sm font-medium">
          Password
        </label>
        <div className="relative">
          <input
            {...form.register('password')}
            type={showPassword ? 'text' : 'password'}
            autoComplete="current-password"
            className="mt-1 block w-full rounded-md border border-gray-300 px-3 py-2 pr-10"
          />
          <button
            type="button"
            onClick={() => setShowPassword(!showPassword)}
            className="absolute inset-y-0 right-0 pr-3 flex items-center"
          >
            {showPassword ? <EyeOffIcon /> : <EyeIcon />}
          </button>
        </div>
        {form.formState.errors.password && (
          <p className="mt-1 text-sm text-red-600">
            {form.formState.errors.password.message}
          </p>
        )}
      </div>

      {form.formState.errors.root && (
        <p className="text-sm text-red-600">
          {form.formState.errors.root.message}
        </p>
      )}

      <button
        type="submit"
        disabled={form.formState.isSubmitting}
        className="w-full flex justify-center py-2 px-4 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-blue-600 hover:bg-blue-700 disabled:opacity-50"
      >
        {form.formState.isSubmitting ? 'Signing in...' : 'Sign in'}
      </button>
    </form>
  );
}
```

## Comparison Table: Authentication Solutions

| Feature | NextAuth.js | Supabase Auth | Custom JWT | Auth0 |
|---------|-------------|---------------|------------|-------|
| **Setup Complexity** | Medium | Low | High | Low |
| **Provider Support** | Excellent | Good | Manual | Excellent |
| **Customization** | High | Medium | Complete | Medium |
| **Security Features** | Built-in | Built-in | Manual | Enterprise |
| **Database Integration** | Required | Built-in | Manual | External |
| **Real-time Features** | No | Yes | Manual | Limited |
| **Cost** | Free | Freemium | Development time | Paid |
| **Learning Curve** | Medium | Low | High | Low |

---

## Navigation

- ← Back to: [State Management Patterns](state-management-patterns.md)
- → Next: [Component Library Management](component-library-management.md)
- 🏠 Home: [Research Overview](../../README.md)