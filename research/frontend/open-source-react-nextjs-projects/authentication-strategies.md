# Authentication Strategies in React/Next.js Projects

## 🎯 Overview

Comprehensive analysis of authentication and authorization patterns used in production React/Next.js applications, covering security best practices, implementation strategies, and real-world examples.

## 🔐 Authentication Landscape

### **Authentication vs Authorization**

```typescript
// Authentication - "Who are you?"
interface AuthenticationUser {
  id: string;
  email: string;
  isVerified: boolean;
  mfaEnabled: boolean;
}

// Authorization - "What can you do?"
interface AuthorizationContext {
  user: User;
  permissions: string[];
  roles: Role[];
  scopes: string[];
}
```

## 🛠️ Authentication Solutions Analysis

### **1. NextAuth.js**

**Used by**: Cal.com, many Next.js applications  
**Best for**: Next.js apps with multiple OAuth providers

#### **Core Implementation Patterns**

```typescript
// pages/api/auth/[...nextauth].ts
import NextAuth from 'next-auth';
import GoogleProvider from 'next-auth/providers/google';
import GitHubProvider from 'next-auth/providers/github';
import CredentialsProvider from 'next-auth/providers/credentials';
import { PrismaAdapter } from '@next-auth/prisma-adapter';

export default NextAuth({
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
    CredentialsProvider({
      name: 'credentials',
      credentials: {
        email: { label: 'Email', type: 'email' },
        password: { label: 'Password', type: 'password' }
      },
      async authorize(credentials) {
        if (!credentials?.email || !credentials?.password) {
          return null;
        }

        const user = await prisma.user.findUnique({
          where: { email: credentials.email }
        });

        if (!user) {
          return null;
        }

        const isPasswordValid = await bcrypt.compare(
          credentials.password,
          user.password
        );

        if (!isPasswordValid) {
          return null;
        }

        return {
          id: user.id,
          email: user.email,
          name: user.name,
        };
      }
    })
  ],
  session: {
    strategy: 'jwt',
    maxAge: 30 * 24 * 60 * 60, // 30 days
  },
  jwt: {
    maxAge: 30 * 24 * 60 * 60, // 30 days
  },
  callbacks: {
    async jwt({ token, user, account }) {
      // Persist the OAuth access_token to the token right after signin
      if (account) {
        token.accessToken = account.access_token;
        token.provider = account.provider;
      }
      
      if (user) {
        token.id = user.id;
      }
      
      return token;
    },
    async session({ session, token }) {
      // Send properties to the client
      session.accessToken = token.accessToken;
      session.user.id = token.id;
      
      return session;
    },
    async signIn({ user, account, profile }) {
      // Custom sign-in logic
      if (account?.provider === 'google') {
        return profile?.email_verified ?? false;
      }
      return true;
    },
    async redirect({ url, baseUrl }) {
      // Allows relative callback URLs
      if (url.startsWith('/')) return `${baseUrl}${url}`;
      // Allows callback URLs on the same origin
      else if (new URL(url).origin === baseUrl) return url;
      return baseUrl;
    }
  },
  pages: {
    signIn: '/auth/signin',
    signUp: '/auth/signup',
    error: '/auth/error',
  },
  events: {
    async signIn(message) {
      // Log successful sign-ins
      console.log('User signed in:', message.user.email);
    },
    async signOut(message) {
      // Log sign-outs
      console.log('User signed out:', message.token);
    },
  },
  debug: process.env.NODE_ENV === 'development',
});
```

#### **Client-Side Usage**

```typescript
// hooks/useAuth.ts
import { useSession, signIn, signOut } from 'next-auth/react';
import { useRouter } from 'next/router';

export const useAuth = () => {
  const { data: session, status } = useSession();
  const router = useRouter();

  const login = async (provider?: string) => {
    const result = await signIn(provider, {
      callbackUrl: router.query.callbackUrl as string || '/',
    });
    return result;
  };

  const logout = async () => {
    await signOut({
      callbackUrl: '/',
    });
  };

  return {
    user: session?.user,
    isAuthenticated: !!session,
    isLoading: status === 'loading',
    login,
    logout,
  };
};

// components/ProtectedRoute.tsx
interface ProtectedRouteProps {
  children: React.ReactNode;
  requiredRole?: string;
}

export const ProtectedRoute: React.FC<ProtectedRouteProps> = ({
  children,
  requiredRole,
}) => {
  const { data: session, status } = useSession();
  const router = useRouter();

  useEffect(() => {
    if (status === 'loading') return; // Still loading

    if (!session) {
      router.push('/auth/signin');
      return;
    }

    if (requiredRole && !session.user.roles?.includes(requiredRole)) {
      router.push('/unauthorized');
      return;
    }
  }, [session, status, router, requiredRole]);

  if (status === 'loading') {
    return <LoadingSpinner />;
  }

  if (!session) {
    return null;
  }

  return <>{children}</>;
};
```

#### **Cal.com's Advanced Patterns**

```typescript
// Advanced session management with role-based access
export const getServerSideProps: GetServerSideProps = async (context) => {
  const session = await getSession(context);
  
  if (!session) {
    return {
      redirect: {
        destination: '/auth/login',
        permanent: false,
      },
    };
  }

  // Check user permissions
  const user = await prisma.user.findUnique({
    where: { id: session.user.id },
    include: {
      teams: {
        include: {
          team: true,
        },
      },
    },
  });

  if (!user) {
    return {
      redirect: {
        destination: '/auth/login',
        permanent: false,
      },
    };
  }

  return {
    props: {
      user: JSON.parse(JSON.stringify(user)),
    },
  };
};

// API Route Protection
export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse
) {
  const session = await getSession({ req });
  
  if (!session) {
    return res.status(401).json({ message: 'Unauthorized' });
  }

  // Additional authorization checks
  const user = await prisma.user.findUnique({
    where: { id: session.user.id },
  });

  if (!user?.isActive) {
    return res.status(403).json({ message: 'Account suspended' });
  }

  // Handle the request
  switch (req.method) {
    case 'GET':
      // GET logic
      break;
    case 'POST':
      // POST logic
      break;
    default:
      res.setHeader('Allow', ['GET', 'POST']);
      res.status(405).end(`Method ${req.method} Not Allowed`);
  }
}
```

### **2. Custom JWT Authentication**

**Used by**: Medusa, Mattermost, custom API-first applications  
**Best for**: Maximum control, API-first architectures

#### **Backend Implementation**

```typescript
// utils/jwt.ts
import jwt from 'jsonwebtoken';
import bcrypt from 'bcryptjs';

interface JWTPayload {
  userId: string;
  email: string;
  roles: string[];
}

export class AuthService {
  private readonly JWT_SECRET = process.env.JWT_SECRET!;
  private readonly JWT_REFRESH_SECRET = process.env.JWT_REFRESH_SECRET!;
  private readonly ACCESS_TOKEN_EXPIRY = '15m';
  private readonly REFRESH_TOKEN_EXPIRY = '7d';

  async generateTokens(user: User): Promise<{ accessToken: string; refreshToken: string }> {
    const payload: JWTPayload = {
      userId: user.id,
      email: user.email,
      roles: user.roles,
    };

    const accessToken = jwt.sign(payload, this.JWT_SECRET, {
      expiresIn: this.ACCESS_TOKEN_EXPIRY,
    });

    const refreshToken = jwt.sign(
      { userId: user.id },
      this.JWT_REFRESH_SECRET,
      { expiresIn: this.REFRESH_TOKEN_EXPIRY }
    );

    // Store refresh token in database
    await this.storeRefreshToken(user.id, refreshToken);

    return { accessToken, refreshToken };
  }

  async verifyAccessToken(token: string): Promise<JWTPayload | null> {
    try {
      const decoded = jwt.verify(token, this.JWT_SECRET) as JWTPayload;
      return decoded;
    } catch (error) {
      return null;
    }
  }

  async refreshAccessToken(refreshToken: string): Promise<string | null> {
    try {
      const decoded = jwt.verify(refreshToken, this.JWT_REFRESH_SECRET) as { userId: string };
      
      // Check if refresh token exists in database
      const storedToken = await this.getStoredRefreshToken(decoded.userId);
      if (storedToken !== refreshToken) {
        throw new Error('Invalid refresh token');
      }

      const user = await this.getUserById(decoded.userId);
      if (!user) {
        throw new Error('User not found');
      }

      const { accessToken } = await this.generateTokens(user);
      return accessToken;
    } catch (error) {
      return null;
    }
  }

  async login(email: string, password: string) {
    const user = await this.getUserByEmail(email);
    if (!user) {
      throw new Error('Invalid credentials');
    }

    const isValidPassword = await bcrypt.compare(password, user.password);
    if (!isValidPassword) {
      throw new Error('Invalid credentials');
    }

    const tokens = await this.generateTokens(user);
    
    // Update last login
    await this.updateLastLogin(user.id);

    return {
      user: this.sanitizeUser(user),
      ...tokens,
    };
  }

  async logout(userId: string, refreshToken: string) {
    await this.revokeRefreshToken(userId, refreshToken);
  }

  private sanitizeUser(user: User) {
    const { password, ...sanitized } = user;
    return sanitized;
  }
}

// middleware/auth.ts
export const authMiddleware = (requiredRoles?: string[]) => {
  return async (req: Request, res: Response, next: NextFunction) => {
    try {
      const authHeader = req.headers.authorization;
      if (!authHeader?.startsWith('Bearer ')) {
        return res.status(401).json({ error: 'No token provided' });
      }

      const token = authHeader.substring(7);
      const authService = new AuthService();
      const payload = await authService.verifyAccessToken(token);

      if (!payload) {
        return res.status(401).json({ error: 'Invalid token' });
      }

      // Check roles if required
      if (requiredRoles && !requiredRoles.some(role => payload.roles.includes(role))) {
        return res.status(403).json({ error: 'Insufficient permissions' });
      }

      req.user = payload;
      next();
    } catch (error) {
      res.status(401).json({ error: 'Authentication failed' });
    }
  };
};
```

#### **Frontend Implementation**

```typescript
// hooks/useAuth.ts
import { create } from 'zustand';
import { persist } from 'zustand/middleware';

interface AuthState {
  user: User | null;
  accessToken: string | null;
  refreshToken: string | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  login: (email: string, password: string) => Promise<void>;
  logout: () => void;
  refreshAccessToken: () => Promise<boolean>;
}

export const useAuthStore = create<AuthState>()(
  persist(
    (set, get) => ({
      user: null,
      accessToken: null,
      refreshToken: null,
      isAuthenticated: false,
      isLoading: false,

      login: async (email: string, password: string) => {
        set({ isLoading: true });
        try {
          const response = await api.post('/auth/login', { email, password });
          const { user, accessToken, refreshToken } = response.data;
          
          set({
            user,
            accessToken,
            refreshToken,
            isAuthenticated: true,
            isLoading: false,
          });
        } catch (error) {
          set({ isLoading: false });
          throw error;
        }
      },

      logout: () => {
        const { refreshToken } = get();
        if (refreshToken) {
          api.post('/auth/logout', { refreshToken }).catch(console.error);
        }
        set({
          user: null,
          accessToken: null,
          refreshToken: null,
          isAuthenticated: false,
        });
      },

      refreshAccessToken: async () => {
        const { refreshToken } = get();
        if (!refreshToken) return false;

        try {
          const response = await api.post('/auth/refresh', { refreshToken });
          const { accessToken } = response.data;
          
          set({ accessToken });
          return true;
        } catch (error) {
          // Refresh failed, logout user
          get().logout();
          return false;
        }
      },
    }),
    {
      name: 'auth-storage',
      partialize: (state) => ({
        accessToken: state.accessToken,
        refreshToken: state.refreshToken,
        user: state.user,
        isAuthenticated: state.isAuthenticated,
      }),
    }
  )
);

// API interceptor for automatic token refresh
import axios from 'axios';

const api = axios.create({
  baseURL: process.env.NEXT_PUBLIC_API_URL,
});

api.interceptors.request.use((config) => {
  const { accessToken } = useAuthStore.getState();
  if (accessToken) {
    config.headers.Authorization = `Bearer ${accessToken}`;
  }
  return config;
});

api.interceptors.response.use(
  (response) => response,
  async (error) => {
    const originalRequest = error.config;
    
    if (error.response?.status === 401 && !originalRequest._retry) {
      originalRequest._retry = true;
      
      const { refreshAccessToken } = useAuthStore.getState();
      const success = await refreshAccessToken();
      
      if (success) {
        const { accessToken } = useAuthStore.getState();
        originalRequest.headers.Authorization = `Bearer ${accessToken}`;
        return api(originalRequest);
      }
    }
    
    return Promise.reject(error);
  }
);
```

#### **Medusa's E-commerce Auth Patterns**

```typescript
// Customer authentication with guest cart merging
class MedusaAuthService {
  async customerLogin(email: string, password: string) {
    const response = await medusaClient.auth.authenticate({
      email,
      password,
    });

    // Merge guest cart with customer cart
    const guestCartId = localStorage.getItem('cart_id');
    if (guestCartId && response.customer) {
      await this.mergeGuestCart(guestCartId, response.customer.id);
    }

    return response;
  }

  async mergeGuestCart(guestCartId: string, customerId: string) {
    try {
      // Get guest cart
      const guestCart = await medusaClient.carts.retrieve(guestCartId);
      
      // Get or create customer cart
      let customerCart = await medusaClient.carts.create({
        customer_id: customerId,
      });

      // Merge line items
      for (const item of guestCart.cart.items) {
        await medusaClient.carts.lineItems.create(customerCart.cart.id, {
          variant_id: item.variant_id,
          quantity: item.quantity,
        });
      }

      // Update cart ID
      localStorage.setItem('cart_id', customerCart.cart.id);
      localStorage.removeItem('guest_cart_id');
      
      return customerCart.cart;
    } catch (error) {
      console.error('Failed to merge guest cart:', error);
    }
  }
}
```

### **3. Third-Party Authentication Services**

#### **Auth0 Integration**

```typescript
// Auth0 Provider setup
import { Auth0Provider } from '@auth0/nextjs-auth0/client';

function MyApp({ Component, pageProps }: AppProps) {
  return (
    <Auth0Provider>
      <Component {...pageProps} />
    </Auth0Provider>
  );
}

// Using Auth0 hooks
import { useUser, withPageAuthRequired } from '@auth0/nextjs-auth0/client';

const ProtectedPage = () => {
  const { user, error, isLoading } = useUser();

  if (isLoading) return <div>Loading...</div>;
  if (error) return <div>{error.message}</div>;

  return (
    <div>
      <h1>Welcome {user?.name}</h1>
      <p>{user?.email}</p>
    </div>
  );
};

export default withPageAuthRequired(ProtectedPage);

// API route protection
import { withApiAuthRequired, getSession } from '@auth0/nextjs-auth0';

export default withApiAuthRequired(async function handler(req, res) {
  const session = await getSession(req, res);
  res.json({ user: session?.user });
});
```

#### **Supabase Auth Integration**

```typescript
// Supabase auth setup
import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
);

// Auth hook
export const useSupabaseAuth = () => {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    // Get initial session
    const getInitialSession = async () => {
      const { data: { session } } = await supabase.auth.getSession();
      setUser(session?.user ?? null);
      setLoading(false);
    };

    getInitialSession();

    // Listen for auth changes
    const { data: { subscription } } = supabase.auth.onAuthStateChange(
      (event, session) => {
        setUser(session?.user ?? null);
        setLoading(false);
      }
    );

    return () => subscription.unsubscribe();
  }, []);

  const signIn = async (email: string, password: string) => {
    const { data, error } = await supabase.auth.signInWithPassword({
      email,
      password,
    });
    return { data, error };
  };

  const signUp = async (email: string, password: string) => {
    const { data, error } = await supabase.auth.signUp({
      email,
      password,
    });
    return { data, error };
  };

  const signOut = async () => {
    const { error } = await supabase.auth.signOut();
    return { error };
  };

  return {
    user,
    loading,
    signIn,
    signUp,
    signOut,
  };
};
```

## 🔒 Security Best Practices

### **1. Token Security**

```typescript
// Secure token storage
const SecureTokenStorage = {
  setTokens: (accessToken: string, refreshToken: string) => {
    // Store access token in memory (most secure)
    sessionStorage.setItem('accessToken', accessToken);
    
    // Store refresh token in httpOnly cookie (server-side only)
    document.cookie = `refreshToken=${refreshToken}; Path=/; HttpOnly; Secure; SameSite=Strict; Max-Age=604800`;
  },

  getAccessToken: () => {
    return sessionStorage.getItem('accessToken');
  },

  clearTokens: () => {
    sessionStorage.removeItem('accessToken');
    document.cookie = 'refreshToken=; Path=/; Expires=Thu, 01 Jan 1970 00:00:01 GMT;';
  },
};

// CSRF protection
export const csrfMiddleware = (req: Request, res: Response, next: NextFunction) => {
  const token = req.headers['x-csrf-token'];
  const sessionToken = req.session.csrfToken;

  if (!token || token !== sessionToken) {
    return res.status(403).json({ error: 'CSRF token mismatch' });
  }

  next();
};
```

### **2. Multi-Factor Authentication**

```typescript
// TOTP implementation
import speakeasy from 'speakeasy';
import QRCode from 'qrcode';

export class MFAService {
  generateSecret(userEmail: string) {
    const secret = speakeasy.generateSecret({
      name: userEmail,
      issuer: 'Your App Name',
    });

    return {
      secret: secret.base32,
      qrCode: secret.otpauth_url,
    };
  }

  async generateQRCode(otpauth_url: string) {
    return await QRCode.toDataURL(otpauth_url);
  }

  verifyToken(token: string, secret: string) {
    return speakeasy.totp.verify({
      secret,
      encoding: 'base32',
      token,
      window: 1, // Allow 1 step before/after for clock drift
    });
  }

  async enableMFA(userId: string, token: string, secret: string) {
    const isValid = this.verifyToken(token, secret);
    
    if (!isValid) {
      throw new Error('Invalid MFA token');
    }

    // Store secret in database
    await prisma.user.update({
      where: { id: userId },
      data: {
        mfaSecret: secret,
        mfaEnabled: true,
      },
    });

    // Generate backup codes
    const backupCodes = this.generateBackupCodes();
    await this.storeBackupCodes(userId, backupCodes);

    return { backupCodes };
  }
}
```

### **3. Rate Limiting and Brute Force Protection**

```typescript
// Rate limiting middleware
import rateLimit from 'express-rate-limit';
import slowDown from 'express-slow-down';

const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 5, // 5 attempts per window
  message: 'Too many login attempts, please try again later',
  standardHeaders: true,
  legacyHeaders: false,
});

const speedLimiter = slowDown({
  windowMs: 15 * 60 * 1000, // 15 minutes
  delayAfter: 2, // allow 2 requests per windowMs without delay
  delayMs: 500, // add 500ms delay per request after delayAfter
});

// Account lockout
class AccountSecurity {
  private readonly MAX_FAILED_ATTEMPTS = 5;
  private readonly LOCKOUT_DURATION = 30 * 60 * 1000; // 30 minutes

  async recordFailedAttempt(email: string) {
    await prisma.user.update({
      where: { email },
      data: {
        failedLoginAttempts: { increment: 1 },
        lastFailedAttempt: new Date(),
      },
    });

    const user = await prisma.user.findUnique({
      where: { email },
      select: { failedLoginAttempts: true },
    });

    if (user && user.failedLoginAttempts >= this.MAX_FAILED_ATTEMPTS) {
      await this.lockAccount(email);
    }
  }

  async lockAccount(email: string) {
    await prisma.user.update({
      where: { email },
      data: {
        accountLockedUntil: new Date(Date.now() + this.LOCKOUT_DURATION),
      },
    });
  }

  async isAccountLocked(email: string): Promise<boolean> {
    const user = await prisma.user.findUnique({
      where: { email },
      select: { accountLockedUntil: true },
    });

    if (!user?.accountLockedUntil) return false;

    return user.accountLockedUntil > new Date();
  }
}
```

## 📊 Authentication Decision Matrix

| Criteria | NextAuth.js | Custom JWT | Auth0 | Supabase |
|----------|-------------|------------|--------|----------|
| **Setup Complexity** | Low | High | Medium | Low |
| **Customization** | Medium | High | Medium | Medium |
| **Cost** | Free | Free | Paid tiers | Free tier |
| **OAuth Support** | Excellent | Manual | Excellent | Good |
| **Enterprise Features** | Limited | Custom | Excellent | Growing |
| **TypeScript Support** | Good | Excellent | Good | Excellent |
| **Community** | Large | N/A | Large | Growing |

## 🔗 Navigation

← [State Management Patterns](./state-management-patterns.md) | [API Integration Patterns →](./api-integration-patterns.md)

---

## 📚 References

1. [NextAuth.js Documentation](https://next-auth.js.org/)
2. [JWT Best Practices](https://tools.ietf.org/html/rfc8725)
3. [Auth0 Documentation](https://auth0.com/docs)
4. [Supabase Auth Documentation](https://supabase.com/docs/guides/auth)
5. [OWASP Authentication Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html)
6. [OAuth 2.0 Security Best Practices](https://tools.ietf.org/html/draft-ietf-oauth-security-topics)

*Last updated: January 2025*