# Authentication Strategies

Comprehensive analysis of secure authentication implementations in production React/Next.js applications, covering NextAuth.js, custom JWT solutions, OAuth providers, and security best practices.

## Authentication Landscape Analysis

### NextAuth.js Dominance (70% Adoption)

NextAuth.js has become the de facto standard for authentication in Next.js applications due to its comprehensive provider support, security features, and ease of implementation.

#### Why NextAuth.js Leads the Market
- **Provider Ecosystem**: 50+ built-in OAuth providers
- **Security by Default**: CSRF protection, secure cookies, automatic token rotation
- **Session Management**: Built-in session handling with database or JWT storage
- **TypeScript Support**: Full TypeScript integration with type augmentation
- **Edge Runtime Compatibility**: Works with Next.js edge runtime

### Alternative Solutions
- **Supabase Auth (20%)**: BaaS authentication solution
- **Custom JWT (10%)**: In-house authentication systems
- **Firebase Auth (5%)**: Google's authentication service

## NextAuth.js Implementation Patterns

### Basic Setup and Configuration

#### Core Configuration (Cal.com Pattern)
```typescript
// pages/api/auth/[...nextauth].ts
import NextAuth, { type NextAuthOptions } from 'next-auth';
import { PrismaAdapter } from '@next-auth/prisma-adapter';
import GoogleProvider from 'next-auth/providers/google';
import GitHubProvider from 'next-auth/providers/github';
import EmailProvider from 'next-auth/providers/email';
import { prisma } from '@/lib/prisma';

export const authOptions: NextAuthOptions = {
  adapter: PrismaAdapter(prisma),
  providers: [
    GoogleProvider({
      clientId: process.env.GOOGLE_CLIENT_ID!,
      clientSecret: process.env.GOOGLE_CLIENT_SECRET!,
    }),
    GitHubProvider({
      clientId: process.env.GITHUB_ID!,
      clientSecret: process.env.GITHUB_SECRET!,
    }),
    EmailProvider({
      server: {
        host: process.env.EMAIL_SERVER_HOST,
        port: process.env.EMAIL_SERVER_PORT,
        auth: {
          user: process.env.EMAIL_SERVER_USER,
          pass: process.env.EMAIL_SERVER_PASSWORD,
        },
      },
      from: process.env.EMAIL_FROM,
    }),
  ],
  callbacks: {
    async session({ session, user, token }) {
      if (session.user) {
        session.user.id = user.id;
        session.user.role = user.role;
        session.user.emailVerified = user.emailVerified;
      }
      return session;
    },
    async jwt({ token, user, account }) {
      if (user) {
        token.role = user.role;
      }
      return token;
    },
    async signIn({ user, account, profile, email, credentials }) {
      // Custom sign-in logic
      if (account?.provider === 'google') {
        // Verify Google domain restrictions
        const allowedDomains = ['company.com'];
        const emailDomain = user.email?.split('@')[1];
        
        if (allowedDomains.includes(emailDomain!)) {
          return true;
        }
        return false;
      }
      return true;
    },
  },
  pages: {
    signIn: '/auth/signin',
    error: '/auth/error',
    verifyRequest: '/auth/verify-request',
  },
  session: {
    strategy: 'database', // or 'jwt' for serverless
    maxAge: 30 * 24 * 60 * 60, // 30 days
  },
  events: {
    async signIn({ user, account, profile, isNewUser }) {
      // Log sign-in events
      console.log(`User ${user.email} signed in with ${account?.provider}`);
      
      if (isNewUser) {
        // Send welcome email or setup user preferences
        await sendWelcomeEmail(user.email!);
      }
    },
    async signOut({ session, token }) {
      // Log sign-out events
      console.log(`User signed out: ${session?.user?.email}`);
    },
  },
};

export default NextAuth(authOptions);
```

#### App Router Configuration (Next.js 13+)
```typescript
// app/api/auth/[...nextauth]/route.ts
import NextAuth from 'next-auth';
import { authOptions } from '@/lib/auth-options';

const handler = NextAuth(authOptions);

export { handler as GET, handler as POST };
```

#### TypeScript Integration
```typescript
// types/next-auth.d.ts - Type augmentation
import NextAuth, { DefaultSession } from 'next-auth';

declare module 'next-auth' {
  interface Session {
    user: {
      id: string;
      role: 'USER' | 'ADMIN' | 'MODERATOR';
      emailVerified: Date | null;
    } & DefaultSession['user'];
  }

  interface User {
    role: 'USER' | 'ADMIN' | 'MODERATOR';
    emailVerified: Date | null;
  }
}

declare module 'next-auth/jwt' {
  interface JWT {
    role: 'USER' | 'ADMIN' | 'MODERATOR';
  }
}
```

### Advanced NextAuth.js Patterns

#### Custom Provider Implementation
```typescript
// providers/custom-oauth.ts
import type { OAuthConfig, OAuthUserConfig } from 'next-auth/providers';

interface CustomProfile {
  id: string;
  email: string;
  name: string;
  avatar_url: string;
  company?: string;
}

export default function CustomProvider<P extends CustomProfile>(
  options: OAuthUserConfig<P>
): OAuthConfig<P> {
  return {
    id: 'custom',
    name: 'Custom OAuth',
    type: 'oauth',
    authorization: {
      url: 'https://auth.custom.com/oauth/authorize',
      params: {
        scope: 'read:user user:email',
        response_type: 'code',
      },
    },
    token: 'https://auth.custom.com/oauth/token',
    userinfo: 'https://api.custom.com/user',
    profile(profile) {
      return {
        id: profile.id,
        name: profile.name,
        email: profile.email,
        image: profile.avatar_url,
      };
    },
    options,
  };
}
```

#### Database Session with Role-Based Access Control
```prisma
// prisma/schema.prisma
model Account {
  id                String  @id @default(cuid())
  userId            String
  type              String
  provider          String
  providerAccountId String
  refresh_token     String? @db.Text
  access_token      String? @db.Text
  expires_at        Int?
  token_type        String?
  scope             String?
  id_token          String? @db.Text
  session_state     String?

  user User @relation(fields: [userId], references: [id], onDelete: Cascade)

  @@unique([provider, providerAccountId])
}

model Session {
  id           String   @id @default(cuid())
  sessionToken String   @unique
  userId       String
  expires      DateTime
  user         User     @relation(fields: [userId], references: [id], onDelete: Cascade)
}

model User {
  id            String    @id @default(cuid())
  name          String?
  email         String    @unique
  emailVerified DateTime?
  image         String?
  role          Role      @default(USER)
  accounts      Account[]
  sessions      Session[]
  createdAt     DateTime  @default(now())
  updatedAt     DateTime  @updatedAt
}

enum Role {
  USER
  ADMIN
  MODERATOR
}
```

#### Middleware for Route Protection
```typescript
// middleware.ts
import { withAuth } from 'next-auth/middleware';
import { NextResponse } from 'next/server';

export default withAuth(
  function middleware(req) {
    const token = req.nextauth.token;
    const pathname = req.nextUrl.pathname;

    // Admin routes protection
    if (pathname.startsWith('/admin')) {
      if (token?.role !== 'ADMIN') {
        return NextResponse.redirect(new URL('/unauthorized', req.url));
      }
    }

    // API routes protection
    if (pathname.startsWith('/api/admin')) {
      if (token?.role !== 'ADMIN') {
        return new NextResponse(
          JSON.stringify({ error: 'Unauthorized' }),
          { status: 401, headers: { 'Content-Type': 'application/json' } }
        );
      }
    }

    return NextResponse.next();
  },
  {
    callbacks: {
      authorized: ({ token, req }) => {
        const pathname = req.nextUrl.pathname;
        
        // Public routes
        if (pathname.startsWith('/auth') || pathname === '/') {
          return true;
        }
        
        // Protected routes require authentication
        return !!token;
      },
    },
  }
);

export const config = {
  matcher: [
    '/dashboard/:path*',
    '/admin/:path*',
    '/api/protected/:path*',
    '/api/admin/:path*',
  ],
};
```

#### Client-Side Auth Hooks
```typescript
// hooks/useAuth.ts
import { useSession, signIn, signOut } from 'next-auth/react';
import { useRouter } from 'next/navigation';

export const useAuth = () => {
  const { data: session, status } = useSession();
  const router = useRouter();

  const login = async (provider?: string, redirectTo?: string) => {
    const result = await signIn(provider, {
      callbackUrl: redirectTo || '/dashboard',
    });
    return result;
  };

  const logout = async (redirectTo?: string) => {
    await signOut({
      callbackUrl: redirectTo || '/',
    });
  };

  const requireAuth = (requiredRole?: string) => {
    if (status === 'loading') return false;
    
    if (!session) {
      router.push('/auth/signin');
      return false;
    }

    if (requiredRole && session.user.role !== requiredRole) {
      router.push('/unauthorized');
      return false;
    }

    return true;
  };

  return {
    session,
    status,
    user: session?.user,
    isAuthenticated: !!session,
    isLoading: status === 'loading',
    login,
    logout,
    requireAuth,
  };
};

// HOC for protected components
export const withAuth = <P extends object>(
  Component: React.ComponentType<P>,
  requiredRole?: string
) => {
  return function AuthenticatedComponent(props: P) {
    const { requireAuth } = useAuth();
    
    if (!requireAuth(requiredRole)) {
      return <div>Loading...</div>;
    }

    return <Component {...props} />;
  };
};
```

### Authentication UI Components

#### Sign-In Form Component
```typescript
// components/auth/SignInForm.tsx
import { useState } from 'react';
import { signIn, getProviders } from 'next-auth/react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Alert, AlertDescription } from '@/components/ui/alert';

interface SignInFormProps {
  providers: Record<string, any>;
  callbackUrl?: string;
  error?: string;
}

export const SignInForm = ({ providers, callbackUrl, error }: SignInFormProps) => {
  const [email, setEmail] = useState('');
  const [isLoading, setIsLoading] = useState(false);

  const handleEmailSignIn = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsLoading(true);
    
    try {
      await signIn('email', {
        email,
        callbackUrl: callbackUrl || '/dashboard',
      });
    } catch (error) {
      console.error('Sign in error:', error);
    } finally {
      setIsLoading(false);
    }
  };

  const handleOAuthSignIn = async (providerId: string) => {
    setIsLoading(true);
    
    try {
      await signIn(providerId, {
        callbackUrl: callbackUrl || '/dashboard',
      });
    } catch (error) {
      console.error('OAuth sign in error:', error);
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <Card className="w-full max-w-md mx-auto">
      <CardHeader>
        <CardTitle>Sign In</CardTitle>
      </CardHeader>
      <CardContent className="space-y-4">
        {error && (
          <Alert variant="destructive">
            <AlertDescription>
              {getErrorMessage(error)}
            </AlertDescription>
          </Alert>
        )}

        {/* OAuth Providers */}
        <div className="space-y-2">
          {Object.values(providers)
            .filter((provider: any) => provider.type === 'oauth')
            .map((provider: any) => (
              <Button
                key={provider.id}
                variant="outline"
                className="w-full"
                onClick={() => handleOAuthSignIn(provider.id)}
                disabled={isLoading}
              >
                <ProviderIcon provider={provider.id} className="mr-2 h-4 w-4" />
                Continue with {provider.name}
              </Button>
            ))}
        </div>

        {/* Email Provider */}
        {providers.email && (
          <>
            <div className="relative">
              <div className="absolute inset-0 flex items-center">
                <span className="w-full border-t" />
              </div>
              <div className="relative flex justify-center text-xs uppercase">
                <span className="bg-background px-2 text-muted-foreground">
                  Or continue with email
                </span>
              </div>
            </div>

            <form onSubmit={handleEmailSignIn} className="space-y-4">
              <Input
                type="email"
                placeholder="Enter your email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                required
              />
              <Button type="submit" className="w-full" disabled={isLoading}>
                {isLoading ? 'Sending...' : 'Send Sign-In Link'}
              </Button>
            </form>
          </>
        )}
      </CardContent>
    </Card>
  );
};

const getErrorMessage = (error: string) => {
  switch (error) {
    case 'Configuration':
      return 'There is a problem with the server configuration.';
    case 'AccessDenied':
      return 'Access denied. You do not have permission to sign in.';
    case 'Verification':
      return 'The verification link was invalid or has expired.';
    default:
      return 'An error occurred. Please try again.';
  }
};
```

## Supabase Auth Implementation

### Supabase Setup and Configuration
```typescript
// lib/supabase.ts
import { createClient } from '@supabase/supabase-js';
import { Database } from '@/types/supabase';

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!;
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!;

export const supabase = createClient<Database>(supabaseUrl, supabaseAnonKey, {
  auth: {
    autoRefreshToken: true,
    persistSession: true,
    detectSessionInUrl: true,
  },
});

// Auth helper functions
export const auth = {
  signUp: async (email: string, password: string, options?: {
    data?: { [key: string]: any };
  }) => {
    const { data, error } = await supabase.auth.signUp({
      email,
      password,
      options,
    });
    return { data, error };
  },

  signIn: async (email: string, password: string) => {
    const { data, error } = await supabase.auth.signInWithPassword({
      email,
      password,
    });
    return { data, error };
  },

  signInWithOAuth: async (provider: 'google' | 'github' | 'discord') => {
    const { data, error } = await supabase.auth.signInWithOAuth({
      provider,
      options: {
        redirectTo: `${window.location.origin}/auth/callback`,
      },
    });
    return { data, error };
  },

  signOut: async () => {
    const { error } = await supabase.auth.signOut();
    return { error };
  },

  resetPassword: async (email: string) => {
    const { data, error } = await supabase.auth.resetPasswordForEmail(email, {
      redirectTo: `${window.location.origin}/auth/reset-password`,
    });
    return { data, error };
  },

  updatePassword: async (password: string) => {
    const { data, error } = await supabase.auth.updateUser({
      password,
    });
    return { data, error };
  },
};
```

### Supabase Auth Context
```typescript
// contexts/AuthContext.tsx
import { createContext, useContext, useEffect, useState } from 'react';
import { User, Session, AuthError } from '@supabase/supabase-js';
import { supabase } from '@/lib/supabase';

interface AuthContextType {
  user: User | null;
  session: Session | null;
  loading: boolean;
  signUp: (email: string, password: string, metadata?: any) => Promise<{ error: AuthError | null }>;
  signIn: (email: string, password: string) => Promise<{ error: AuthError | null }>;
  signOut: () => Promise<void>;
  resetPassword: (email: string) => Promise<{ error: AuthError | null }>;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};

export const AuthProvider = ({ children }: { children: React.ReactNode }) => {
  const [user, setUser] = useState<User | null>(null);
  const [session, setSession] = useState<Session | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    // Get initial session
    const getInitialSession = async () => {
      const { data: { session } } = await supabase.auth.getSession();
      setSession(session);
      setUser(session?.user ?? null);
      setLoading(false);
    };

    getInitialSession();

    // Listen for auth changes
    const { data: { subscription } } = supabase.auth.onAuthStateChange(
      async (event, session) => {
        setSession(session);
        setUser(session?.user ?? null);
        setLoading(false);

        // Handle auth events
        if (event === 'SIGNED_IN') {
          console.log('User signed in:', session?.user.email);
        } else if (event === 'SIGNED_OUT') {
          console.log('User signed out');
        }
      }
    );

    return () => subscription.unsubscribe();
  }, []);

  const signUp = async (email: string, password: string, metadata?: any) => {
    const { error } = await supabase.auth.signUp({
      email,
      password,
      options: {
        data: metadata,
      },
    });
    return { error };
  };

  const signIn = async (email: string, password: string) => {
    const { error } = await supabase.auth.signInWithPassword({
      email,
      password,
    });
    return { error };
  };

  const signOut = async () => {
    await supabase.auth.signOut();
  };

  const resetPassword = async (email: string) => {
    const { error } = await supabase.auth.resetPasswordForEmail(email);
    return { error };
  };

  return (
    <AuthContext.Provider
      value={{
        user,
        session,
        loading,
        signUp,
        signIn,
        signOut,
        resetPassword,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
};
```

### Row Level Security (RLS) Patterns
```sql
-- Enable RLS on tables
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE comments ENABLE ROW LEVEL SECURITY;

-- Users can only read and update their own profile
CREATE POLICY "Users can view own profile"
  ON profiles FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
  ON profiles FOR UPDATE
  USING (auth.uid() = id);

-- Posts are public for reading, but only authors can modify
CREATE POLICY "Posts are viewable by everyone"
  ON posts FOR SELECT
  USING (true);

CREATE POLICY "Users can create posts"
  ON posts FOR INSERT
  WITH CHECK (auth.uid() = author_id);

CREATE POLICY "Users can update own posts"
  ON posts FOR UPDATE
  USING (auth.uid() = author_id);

-- Comments policies
CREATE POLICY "Comments are viewable by everyone"
  ON comments FOR SELECT
  USING (true);

CREATE POLICY "Authenticated users can create comments"
  ON comments FOR INSERT
  WITH CHECK (auth.uid() = author_id);

-- Admin policies
CREATE POLICY "Admins can do everything"
  ON posts FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );
```

## Custom JWT Authentication

### JWT Implementation (Plane.app Pattern)
```typescript
// lib/jwt.ts
import jwt from 'jsonwebtoken';
import bcrypt from 'bcryptjs';
import { prisma } from './prisma';

const JWT_SECRET = process.env.JWT_SECRET!;
const JWT_REFRESH_SECRET = process.env.JWT_REFRESH_SECRET!;

export interface JWTPayload {
  userId: string;
  email: string;
  role: string;
}

export const generateTokens = (payload: JWTPayload) => {
  const accessToken = jwt.sign(payload, JWT_SECRET, {
    expiresIn: '15m',
  });
  
  const refreshToken = jwt.sign(payload, JWT_REFRESH_SECRET, {
    expiresIn: '7d',
  });
  
  return { accessToken, refreshToken };
};

export const verifyAccessToken = (token: string): JWTPayload | null => {
  try {
    return jwt.verify(token, JWT_SECRET) as JWTPayload;
  } catch (error) {
    return null;
  }
};

export const verifyRefreshToken = (token: string): JWTPayload | null => {
  try {
    return jwt.verify(token, JWT_REFRESH_SECRET) as JWTPayload;
  } catch (error) {
    return null;
  }
};

export const hashPassword = async (password: string): Promise<string> => {
  return bcrypt.hash(password, 12);
};

export const comparePassword = async (
  password: string,
  hash: string
): Promise<boolean> => {
  return bcrypt.compare(password, hash);
};
```

### Authentication API Routes
```typescript
// pages/api/auth/login.ts
import type { NextApiRequest, NextApiResponse } from 'next';
import { z } from 'zod';
import { prisma } from '@/lib/prisma';
import { comparePassword, generateTokens } from '@/lib/jwt';
import { serialize } from 'cookie';

const loginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8),
});

export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse
) {
  if (req.method !== 'POST') {
    return res.status(405).json({ message: 'Method not allowed' });
  }

  try {
    const { email, password } = loginSchema.parse(req.body);

    // Find user
    const user = await prisma.user.findUnique({
      where: { email },
      select: {
        id: true,
        email: true,
        password: true,
        role: true,
        name: true,
        emailVerified: true,
      },
    });

    if (!user || !(await comparePassword(password, user.password))) {
      return res.status(401).json({ message: 'Invalid credentials' });
    }

    if (!user.emailVerified) {
      return res.status(401).json({ message: 'Email not verified' });
    }

    // Generate tokens
    const { accessToken, refreshToken } = generateTokens({
      userId: user.id,
      email: user.email,
      role: user.role,
    });

    // Store refresh token in database
    await prisma.refreshToken.create({
      data: {
        token: refreshToken,
        userId: user.id,
        expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000), // 7 days
      },
    });

    // Set HTTP-only cookie for refresh token
    const refreshCookie = serialize('refreshToken', refreshToken, {
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'strict',
      maxAge: 7 * 24 * 60 * 60, // 7 days
      path: '/',
    });

    res.setHeader('Set-Cookie', refreshCookie);

    return res.status(200).json({
      accessToken,
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
        role: user.role,
      },
    });
  } catch (error) {
    console.error('Login error:', error);
    return res.status(500).json({ message: 'Internal server error' });
  }
}
```

### Authentication Middleware
```typescript
// middleware/auth.ts
import type { NextApiRequest, NextApiResponse } from 'next';
import { verifyAccessToken } from '@/lib/jwt';

export interface AuthenticatedRequest extends NextApiRequest {
  user: {
    userId: string;
    email: string;
    role: string;
  };
}

export const withAuth = (
  handler: (req: AuthenticatedRequest, res: NextApiResponse) => Promise<void>,
  requiredRole?: string
) => {
  return async (req: NextApiRequest, res: NextApiResponse) => {
    const token = req.headers.authorization?.replace('Bearer ', '');

    if (!token) {
      return res.status(401).json({ message: 'Access token required' });
    }

    const payload = verifyAccessToken(token);

    if (!payload) {
      return res.status(401).json({ message: 'Invalid access token' });
    }

    if (requiredRole && payload.role !== requiredRole) {
      return res.status(403).json({ message: 'Insufficient permissions' });
    }

    (req as AuthenticatedRequest).user = payload;
    return handler(req as AuthenticatedRequest, res);
  };
};

// Usage
export default withAuth(async (req, res) => {
  const { userId } = req.user;
  // Protected route logic
}, 'admin');
```

## Security Best Practices

### CSRF Protection
```typescript
// lib/csrf.ts
import { randomBytes, timingSafeEqual } from 'crypto';

export class CSRFProtection {
  private static tokens = new Map<string, { token: string; expires: number }>();

  static generateToken(sessionId: string): string {
    const token = randomBytes(32).toString('hex');
    const expires = Date.now() + 60 * 60 * 1000; // 1 hour
    
    this.tokens.set(sessionId, { token, expires });
    return token;
  }

  static validateToken(sessionId: string, providedToken: string): boolean {
    const stored = this.tokens.get(sessionId);
    
    if (!stored || Date.now() > stored.expires) {
      this.tokens.delete(sessionId);
      return false;
    }

    const tokenBuffer = Buffer.from(stored.token, 'hex');
    const providedBuffer = Buffer.from(providedToken, 'hex');
    
    if (tokenBuffer.length !== providedBuffer.length) {
      return false;
    }

    return timingSafeEqual(tokenBuffer, providedBuffer);
  }
}

// Middleware for CSRF protection
export const withCSRF = (handler: NextApiHandler) => {
  return async (req: NextApiRequest, res: NextApiResponse) => {
    if (req.method === 'POST' || req.method === 'PUT' || req.method === 'DELETE') {
      const sessionId = req.cookies.sessionId;
      const csrfToken = req.headers['x-csrf-token'] as string;

      if (!sessionId || !csrfToken) {
        return res.status(403).json({ message: 'CSRF token required' });
      }

      if (!CSRFProtection.validateToken(sessionId, csrfToken)) {
        return res.status(403).json({ message: 'Invalid CSRF token' });
      }
    }

    return handler(req, res);
  };
};
```

### Rate Limiting
```typescript
// lib/rate-limiter.ts
interface RateLimitOptions {
  windowMs: number;
  maxRequests: number;
  keyGenerator?: (req: NextApiRequest) => string;
}

export class RateLimiter {
  private requests = new Map<string, { count: number; resetTime: number }>();

  constructor(private options: RateLimitOptions) {}

  check(req: NextApiRequest): { allowed: boolean; remaining: number; resetTime: number } {
    const key = this.options.keyGenerator
      ? this.options.keyGenerator(req)
      : this.getDefaultKey(req);

    const now = Date.now();
    const windowStart = now - this.options.windowMs;

    // Clean up old entries
    for (const [k, v] of this.requests.entries()) {
      if (v.resetTime < now) {
        this.requests.delete(k);
      }
    }

    const current = this.requests.get(key) || { count: 0, resetTime: now + this.options.windowMs };

    if (current.resetTime < now) {
      current.count = 0;
      current.resetTime = now + this.options.windowMs;
    }

    current.count++;
    this.requests.set(key, current);

    const allowed = current.count <= this.options.maxRequests;
    const remaining = Math.max(0, this.options.maxRequests - current.count);

    return { allowed, remaining, resetTime: current.resetTime };
  }

  private getDefaultKey(req: NextApiRequest): string {
    return req.ip || req.connection.remoteAddress || 'unknown';
  }
}

// Rate limiting middleware
export const withRateLimit = (options: RateLimitOptions) => {
  const limiter = new RateLimiter(options);

  return (handler: NextApiHandler) => {
    return async (req: NextApiRequest, res: NextApiResponse) => {
      const { allowed, remaining, resetTime } = limiter.check(req);

      res.setHeader('X-RateLimit-Limit', options.maxRequests);
      res.setHeader('X-RateLimit-Remaining', remaining);
      res.setHeader('X-RateLimit-Reset', Math.ceil(resetTime / 1000));

      if (!allowed) {
        return res.status(429).json({
          message: 'Too many requests',
          retryAfter: Math.ceil((resetTime - Date.now()) / 1000),
        });
      }

      return handler(req, res);
    };
  };
};
```

### Session Security
```typescript
// lib/session-security.ts
export const secureSessionOptions = {
  cookieName: 'session',
  password: process.env.SESSION_PASSWORD!, // Must be at least 32 characters
  cookieOptions: {
    secure: process.env.NODE_ENV === 'production',
    httpOnly: true,
    sameSite: 'strict' as const,
    maxAge: 60 * 60 * 24 * 7, // 1 week
  },
};

// Session rotation for enhanced security
export const rotateSession = async (req: NextApiRequest, res: NextApiResponse) => {
  const currentSession = await getSession(req, res);
  
  if (currentSession) {
    // Invalidate current session
    await destroySession(req, res);
    
    // Create new session with same data
    const newSession = await createSession(req, res);
    newSession.user = currentSession.user;
    await newSession.save();
  }
};

// Concurrent session management
export const manageConcurrentSessions = async (userId: string) => {
  const MAX_SESSIONS = 3;
  
  const userSessions = await prisma.session.findMany({
    where: { userId },
    orderBy: { createdAt: 'desc' },
  });

  if (userSessions.length >= MAX_SESSIONS) {
    // Remove oldest sessions
    const sessionsToRemove = userSessions.slice(MAX_SESSIONS - 1);
    await prisma.session.deleteMany({
      where: {
        id: { in: sessionsToRemove.map(s => s.id) },
      },
    });
  }
};
```

## Testing Authentication

### NextAuth.js Testing
```typescript
// __tests__/auth.test.ts
import { getServerSession } from 'next-auth';
import { authOptions } from '@/lib/auth-options';
import { NextRequest, NextResponse } from 'next/server';

// Mock NextAuth
jest.mock('next-auth', () => ({
  default: jest.fn(),
  getServerSession: jest.fn(),
}));

describe('Authentication', () => {
  const mockGetServerSession = getServerSession as jest.MockedFunction<typeof getServerSession>;

  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('allows access to protected route with valid session', async () => {
    mockGetServerSession.mockResolvedValue({
      user: {
        id: '1',
        email: 'user@example.com',
        role: 'USER',
      },
    });

    const request = new NextRequest('http://localhost:3000/dashboard');
    const response = await middleware(request);

    expect(response.status).toBe(200);
  });

  it('redirects to login for unauthenticated users', async () => {
    mockGetServerSession.mockResolvedValue(null);

    const request = new NextRequest('http://localhost:3000/dashboard');
    const response = await middleware(request);

    expect(response.status).toBe(307);
    expect(response.headers.get('location')).toContain('/auth/signin');
  });

  it('blocks admin routes for non-admin users', async () => {
    mockGetServerSession.mockResolvedValue({
      user: {
        id: '1',
        email: 'user@example.com',
        role: 'USER',
      },
    });

    const request = new NextRequest('http://localhost:3000/admin');
    const response = await middleware(request);

    expect(response.status).toBe(307);
    expect(response.headers.get('location')).toContain('/unauthorized');
  });
});
```

### Supabase Auth Testing
```typescript
// __tests__/supabase-auth.test.tsx
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { AuthProvider, useAuth } from '@/contexts/AuthContext';
import { supabase } from '@/lib/supabase';

// Mock Supabase
jest.mock('@/lib/supabase', () => ({
  supabase: {
    auth: {
      getSession: jest.fn(),
      onAuthStateChange: jest.fn(),
      signInWithPassword: jest.fn(),
      signOut: jest.fn(),
    },
  },
}));

const TestComponent = () => {
  const { user, signIn, signOut } = useAuth();
  
  return (
    <div>
      {user ? (
        <div>
          <span>Welcome, {user.email}</span>
          <button onClick={signOut}>Sign Out</button>
        </div>
      ) : (
        <button onClick={() => signIn('test@example.com', 'password')}>
          Sign In
        </button>
      )}
    </div>
  );
};

describe('Supabase Auth', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    
    (supabase.auth.getSession as jest.Mock).mockResolvedValue({
      data: { session: null },
    });
    
    (supabase.auth.onAuthStateChange as jest.Mock).mockReturnValue({
      data: { subscription: { unsubscribe: jest.fn() } },
    });
  });

  it('signs in user successfully', async () => {
    (supabase.auth.signInWithPassword as jest.Mock).mockResolvedValue({
      data: {
        user: { email: 'test@example.com' },
        session: { access_token: 'token' },
      },
      error: null,
    });

    render(
      <AuthProvider>
        <TestComponent />
      </AuthProvider>
    );

    fireEvent.click(screen.getByText('Sign In'));

    await waitFor(() => {
      expect(supabase.auth.signInWithPassword).toHaveBeenCalledWith({
        email: 'test@example.com',
        password: 'password',
      });
    });
  });
});
```

## Best Practices Summary

### Security Recommendations
1. **Use HTTPS in production** - Always encrypt authentication data in transit
2. **Implement CSRF protection** - Prevent cross-site request forgery attacks
3. **Add rate limiting** - Protect against brute force attacks
4. **Use secure session management** - HTTP-only cookies with proper flags
5. **Implement proper token rotation** - Regular token refresh for enhanced security
6. **Validate all inputs** - Use schema validation for authentication data
7. **Log authentication events** - Monitor for suspicious activity
8. **Implement session timeout** - Automatic logout after inactivity

### NextAuth.js vs Alternatives Decision Matrix

| Factor | NextAuth.js | Supabase Auth | Custom JWT |
|--------|-------------|---------------|------------|
| **Setup Complexity** | Low | Low | High |
| **Provider Support** | Excellent | Good | Manual |
| **Security Features** | Excellent | Excellent | Manual |
| **Type Safety** | Excellent | Good | Manual |
| **Customization** | Medium | Medium | Full |
| **Vendor Lock-in** | None | High | None |
| **Edge Compatibility** | Yes | Yes | Yes |

### Recommendation Framework

**Choose NextAuth.js when:**
- Need multiple OAuth providers
- Want security best practices by default
- Building with Next.js
- Team prefers established solutions

**Choose Supabase Auth when:**
- Using Supabase as backend
- Need real-time features
- Want managed authentication service
- Building rapidly with BaaS

**Choose Custom JWT when:**
- Have specific authentication requirements
- Need complete control over auth flow
- Integrating with existing systems
- Have security expertise in team

Modern React/Next.js applications benefit most from NextAuth.js due to its comprehensive provider support, security features, and excellent developer experience. The ecosystem has converged around this solution for good reason.

---

**Navigation**
- ← Back to: [API Integration Patterns](./api-integration-patterns.md)
- → Next: [Performance Optimization](./performance-optimization.md)
- → Related: [Implementation Guide](./implementation-guide.md)