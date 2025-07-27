# Authentication Security in Production React/Next.js Applications

## 🎯 Overview

Security implementation patterns for authentication and authorization in production React/Next.js applications, based on analysis of real-world open source projects. This document covers secure authentication flows, session management, and protection strategies.

## 🔐 Authentication Patterns Analysis

### NextAuth.js Implementation (Most Common - 60% of projects)

Projects using NextAuth.js: Cal.com, many T3 Stack applications

```typescript
// app/api/auth/[...nextauth]/route.ts - Production pattern from Cal.com
import NextAuth from 'next-auth';
import GoogleProvider from 'next-auth/providers/google';
import CredentialsProvider from 'next-auth/providers/credentials';
import { PrismaAdapter } from '@auth/prisma-adapter';
import { prisma } from '@/lib/prisma';
import bcrypt from 'bcryptjs';

const handler = NextAuth({
  adapter: PrismaAdapter(prisma),
  providers: [
    GoogleProvider({
      clientId: process.env.GOOGLE_CLIENT_ID!,
      clientSecret: process.env.GOOGLE_CLIENT_SECRET!,
      allowDangerousEmailAccountLinking: true, // For production use
    }),
    CredentialsProvider({
      name: 'credentials',
      credentials: {
        email: { label: 'Email', type: 'email' },
        password: { label: 'Password', type: 'password' },
      },
      async authorize(credentials) {
        if (!credentials?.email || !credentials?.password) {
          throw new Error('Email and password required');
        }

        // Rate limiting check
        const rateLimitKey = `auth:${credentials.email}`;
        const attempts = await redis.get(rateLimitKey);
        if (attempts && parseInt(attempts) > 5) {
          throw new Error('Too many failed attempts. Try again later.');
        }

        const user = await prisma.user.findUnique({
          where: { email: credentials.email.toLowerCase() },
          select: {
            id: true,
            email: true,
            hashedPassword: true,
            name: true,
            role: true,
            emailVerified: true,
            locked: true,
          },
        });

        if (!user || !user.hashedPassword) {
          // Increment failed attempts
          await redis.incr(rateLimitKey);
          await redis.expire(rateLimitKey, 900); // 15 minutes
          throw new Error('Invalid credentials');
        }

        if (user.locked) {
          throw new Error('Account is locked. Contact support.');
        }

        if (!user.emailVerified) {
          throw new Error('Please verify your email before signing in');
        }

        const isValid = await bcrypt.compare(
          credentials.password,
          user.hashedPassword
        );

        if (!isValid) {
          // Increment failed attempts
          await redis.incr(rateLimitKey);
          await redis.expire(rateLimitKey, 900);
          throw new Error('Invalid credentials');
        }

        // Clear failed attempts on successful login
        await redis.del(rateLimitKey);

        // Log successful login
        await prisma.loginEvent.create({
          data: {
            userId: user.id,
            ip: headers.get('x-forwarded-for') || 'unknown',
            userAgent: headers.get('user-agent') || 'unknown',
            success: true,
          },
        });

        return {
          id: user.id,
          email: user.email,
          name: user.name,
          role: user.role,
        };
      },
    }),
  ],
  session: {
    strategy: 'jwt',
    maxAge: 30 * 24 * 60 * 60, // 30 days
    updateAge: 24 * 60 * 60, // 24 hours
  },
  callbacks: {
    async jwt({ token, user, account }) {
      if (user) {
        token.role = user.role;
        token.id = user.id;
      }
      
      // Refresh user data periodically
      if (token.iat && Date.now() - token.iat * 1000 > 24 * 60 * 60 * 1000) {
        const updatedUser = await prisma.user.findUnique({
          where: { id: token.id },
          select: { role: true, locked: true },
        });
        
        if (updatedUser?.locked) {
          throw new Error('Account has been locked');
        }
        
        token.role = updatedUser?.role;
      }
      
      return token;
    },
    async session({ session, token }) {
      if (session.user) {
        session.user.id = token.id as string;
        session.user.role = token.role as string;
      }
      return session;
    },
    async signIn({ user, account, profile }) {
      // Additional security checks
      if (account?.provider === 'google') {
        // Verify Google account
        if (!profile?.email_verified) {
          throw new Error('Google account email not verified');
        }
      }
      
      return true;
    },
  },
  events: {
    async signIn({ user, account, isNewUser }) {
      // Log sign-in events
      await prisma.loginEvent.create({
        data: {
          userId: user.id,
          provider: account?.provider || 'credentials',
          success: true,
        },
      });
    },
    async signOut({ token }) {
      // Log sign-out events
      if (token?.id) {
        await prisma.loginEvent.create({
          data: {
            userId: token.id as string,
            action: 'signout',
            success: true,
          },
        });
      }
    },
  },
  pages: {
    signIn: '/auth/signin',
    signUp: '/auth/signup',
    error: '/auth/error',
    verifyRequest: '/auth/verify-request',
  },
});

export { handler as GET, handler as POST };
```

### Custom JWT Implementation (25% of projects)

Pattern from Plane, enterprise applications requiring full control:

```typescript
// lib/auth.ts - Custom JWT implementation
import jwt from 'jsonwebtoken';
import bcrypt from 'bcryptjs';
import { cookies } from 'next/headers';

interface TokenPayload {
  userId: string;
  email: string;
  role: string;
  sessionId: string;
}

interface RefreshTokenPayload {
  userId: string;
  sessionId: string;
  tokenVersion: number;
}

export class AuthService {
  private static ACCESS_TOKEN_SECRET = process.env.ACCESS_TOKEN_SECRET!;
  private static REFRESH_TOKEN_SECRET = process.env.REFRESH_TOKEN_SECRET!;
  private static ACCESS_TOKEN_EXPIRY = '15m';
  private static REFRESH_TOKEN_EXPIRY = '7d';

  static async login(email: string, password: string): Promise<{
    accessToken: string;
    refreshToken: string;
    user: User;
  }> {
    // Rate limiting
    const rateLimitKey = `login:${email}`;
    const attempts = await redis.get(rateLimitKey);
    if (attempts && parseInt(attempts) > 5) {
      throw new Error('Too many login attempts. Try again later.');
    }

    const user = await prisma.user.findUnique({
      where: { email: email.toLowerCase() },
      include: { sessions: true },
    });

    if (!user || !user.hashedPassword) {
      await redis.incr(rateLimitKey);
      await redis.expire(rateLimitKey, 900);
      throw new Error('Invalid credentials');
    }

    const isValid = await bcrypt.compare(password, user.hashedPassword);
    if (!isValid) {
      await redis.incr(rateLimitKey);
      await redis.expire(rateLimitKey, 900);
      throw new Error('Invalid credentials');
    }

    // Clear rate limit on successful login
    await redis.del(rateLimitKey);

    // Create session
    const session = await prisma.session.create({
      data: {
        userId: user.id,
        expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000), // 7 days
        tokenVersion: user.tokenVersion,
        ip: getClientIP(),
        userAgent: getUserAgent(),
      },
    });

    // Generate tokens
    const accessToken = this.generateAccessToken({
      userId: user.id,
      email: user.email,
      role: user.role,
      sessionId: session.id,
    });

    const refreshToken = this.generateRefreshToken({
      userId: user.id,
      sessionId: session.id,
      tokenVersion: user.tokenVersion,
    });

    // Set secure cookies
    this.setTokenCookies(accessToken, refreshToken);

    return {
      accessToken,
      refreshToken,
      user: this.sanitizeUser(user),
    };
  }

  static generateAccessToken(payload: TokenPayload): string {
    return jwt.sign(payload, this.ACCESS_TOKEN_SECRET, {
      expiresIn: this.ACCESS_TOKEN_EXPIRY,
      issuer: 'your-app',
      audience: 'your-app-users',
    });
  }

  static generateRefreshToken(payload: RefreshTokenPayload): string {
    return jwt.sign(payload, this.REFRESH_TOKEN_SECRET, {
      expiresIn: this.REFRESH_TOKEN_EXPIRY,
      issuer: 'your-app',
      audience: 'your-app-users',
    });
  }

  static verifyAccessToken(token: string): TokenPayload {
    try {
      return jwt.verify(token, this.ACCESS_TOKEN_SECRET, {
        issuer: 'your-app',
        audience: 'your-app-users',
      }) as TokenPayload;
    } catch (error) {
      throw new Error('Invalid access token');
    }
  }

  static verifyRefreshToken(token: string): RefreshTokenPayload {
    try {
      return jwt.verify(token, this.REFRESH_TOKEN_SECRET, {
        issuer: 'your-app',
        audience: 'your-app-users',
      }) as RefreshTokenPayload;
    } catch (error) {
      throw new Error('Invalid refresh token');
    }
  }

  static async refreshTokens(refreshToken: string): Promise<{
    accessToken: string;
    refreshToken: string;
  }> {
    const payload = this.verifyRefreshToken(refreshToken);
    
    // Verify session exists and is valid
    const session = await prisma.session.findUnique({
      where: { id: payload.sessionId },
      include: { user: true },
    });

    if (!session || session.expiresAt < new Date()) {
      throw new Error('Session expired');
    }

    if (session.user.tokenVersion !== payload.tokenVersion) {
      throw new Error('Token version mismatch');
    }

    // Generate new tokens
    const newAccessToken = this.generateAccessToken({
      userId: session.userId,
      email: session.user.email,
      role: session.user.role,
      sessionId: session.id,
    });

    const newRefreshToken = this.generateRefreshToken({
      userId: session.userId,
      sessionId: session.id,
      tokenVersion: session.user.tokenVersion,
    });

    // Update session last used
    await prisma.session.update({
      where: { id: session.id },
      data: { lastUsedAt: new Date() },
    });

    this.setTokenCookies(newAccessToken, newRefreshToken);

    return {
      accessToken: newAccessToken,
      refreshToken: newRefreshToken,
    };
  }

  static setTokenCookies(accessToken: string, refreshToken: string) {
    const cookieStore = cookies();
    
    cookieStore.set('access-token', accessToken, {
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'strict',
      maxAge: 15 * 60, // 15 minutes
      path: '/',
    });

    cookieStore.set('refresh-token', refreshToken, {
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'strict',
      maxAge: 7 * 24 * 60 * 60, // 7 days
      path: '/auth',
    });
  }

  static async logout(sessionId: string) {
    await prisma.session.delete({
      where: { id: sessionId },
    });

    const cookieStore = cookies();
    cookieStore.delete('access-token');
    cookieStore.delete('refresh-token');
  }

  static async revokeAllSessions(userId: string) {
    // Increment token version to invalidate all tokens
    await prisma.user.update({
      where: { id: userId },
      data: { tokenVersion: { increment: 1 } },
    });

    // Delete all sessions
    await prisma.session.deleteMany({
      where: { userId },
    });
  }
}
```

## 🛡️ Security Middleware and Protection

### Authentication Middleware
```typescript
// middleware.ts - Next.js middleware for authentication
import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';
import { getToken } from 'next-auth/jwt';

const publicPaths = ['/auth/signin', '/auth/signup', '/api/auth', '/'];
const adminPaths = ['/admin'];

export async function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl;
  
  // Skip middleware for public paths and static files
  if (
    publicPaths.some(path => pathname.startsWith(path)) ||
    pathname.includes('.')
  ) {
    return NextResponse.next();
  }

  // Check authentication
  const token = await getToken({ 
    req: request,
    secret: process.env.NEXTAUTH_SECRET 
  });

  if (!token) {
    const url = new URL('/auth/signin', request.url);
    url.searchParams.set('callbackUrl', pathname);
    return NextResponse.redirect(url);
  }

  // Check admin access
  if (adminPaths.some(path => pathname.startsWith(path))) {
    if (token.role !== 'admin') {
      return NextResponse.redirect(new URL('/unauthorized', request.url));
    }
  }

  // Add security headers
  const response = NextResponse.next();
  
  response.headers.set('X-Frame-Options', 'DENY');
  response.headers.set('X-Content-Type-Options', 'nosniff');
  response.headers.set('Referrer-Policy', 'strict-origin-when-cross-origin');
  response.headers.set('X-XSS-Protection', '1; mode=block');
  
  // Content Security Policy
  response.headers.set(
    'Content-Security-Policy',
    [
      "default-src 'self'",
      "script-src 'self' 'unsafe-inline' 'unsafe-eval'",
      "style-src 'self' 'unsafe-inline'",
      "img-src 'self' data: https:",
      "font-src 'self'",
      "connect-src 'self'",
      "frame-ancestors 'none'",
    ].join('; ')
  );

  return response;
}

export const config = {
  matcher: [
    '/((?!api|_next/static|_next/image|favicon.ico).*)',
  ],
};
```

### API Route Protection
```typescript
// lib/api-auth.ts - API route authentication
import { getServerSession } from 'next-auth';
import { NextRequest, NextResponse } from 'next/server';
import { AuthService } from './auth';

export async function withAuth(
  handler: (req: NextRequest, context: { user: User }) => Promise<NextResponse>,
  options: { requireRole?: string } = {}
) {
  return async (req: NextRequest) => {
    try {
      // Try NextAuth session first
      const session = await getServerSession();
      let user = session?.user;

      // Fallback to custom JWT
      if (!user) {
        const token = req.cookies.get('access-token')?.value;
        if (token) {
          const payload = AuthService.verifyAccessToken(token);
          user = await prisma.user.findUnique({
            where: { id: payload.userId },
          });
        }
      }

      if (!user) {
        return NextResponse.json(
          { error: 'Unauthorized' },
          { status: 401 }
        );
      }

      // Check role requirement
      if (options.requireRole && user.role !== options.requireRole) {
        return NextResponse.json(
          { error: 'Forbidden' },
          { status: 403 }
        );
      }

      return handler(req, { user });
    } catch (error) {
      return NextResponse.json(
        { error: 'Authentication error' },
        { status: 401 }
      );
    }
  };
}

// Usage in API route
// app/api/admin/users/route.ts
export const GET = withAuth(
  async (req, { user }) => {
    const users = await prisma.user.findMany();
    return NextResponse.json(users);
  },
  { requireRole: 'admin' }
);
```

## 🔒 Password Security

### Password Hashing and Validation
```typescript
// lib/password.ts - Secure password handling
import bcrypt from 'bcryptjs';
import zxcvbn from 'zxcvbn';

export class PasswordService {
  private static SALT_ROUNDS = 12;

  static async hash(password: string): Promise<string> {
    return bcrypt.hash(password, this.SALT_ROUNDS);
  }

  static async verify(password: string, hash: string): Promise<boolean> {
    return bcrypt.compare(password, hash);
  }

  static validateStrength(password: string): {
    isValid: boolean;
    score: number;
    feedback: string[];
  } {
    const result = zxcvbn(password);
    
    const requirements = [
      {
        test: password.length >= 8,
        message: 'Password must be at least 8 characters long',
      },
      {
        test: /[A-Z]/.test(password),
        message: 'Password must contain at least one uppercase letter',
      },
      {
        test: /[a-z]/.test(password),
        message: 'Password must contain at least one lowercase letter',
      },
      {
        test: /\d/.test(password),
        message: 'Password must contain at least one number',
      },
      {
        test: /[!@#$%^&*(),.?":{}|<>]/.test(password),
        message: 'Password must contain at least one special character',
      },
    ];

    const feedback = requirements
      .filter(req => !req.test)
      .map(req => req.message);

    return {
      isValid: feedback.length === 0 && result.score >= 3,
      score: result.score,
      feedback: [...feedback, ...result.feedback.suggestions],
    };
  }

  static generateSecurePassword(length: number = 16): string {
    const charset = 
      'abcdefghijklmnopqrstuvwxyz' +
      'ABCDEFGHIJKLMNOPQRSTUVWXYZ' +
      '0123456789' +
      '!@#$%^&*()_+-=[]{}|;:,.<>?';
    
    let password = '';
    for (let i = 0; i < length; i++) {
      password += charset.charAt(Math.floor(Math.random() * charset.length));
    }
    
    return password;
  }
}
```

## 🔐 Multi-Factor Authentication

### TOTP Implementation
```typescript
// lib/mfa.ts - Multi-factor authentication
import speakeasy from 'speakeasy';
import QRCode from 'qrcode';

export class MFAService {
  static generateSecret(userEmail: string): {
    secret: string;
    qrCode: string;
    backupCodes: string[];
  } {
    const secret = speakeasy.generateSecret({
      name: userEmail,
      issuer: 'Your App Name',
      length: 32,
    });

    const backupCodes = Array.from({ length: 10 }, () =>
      Math.random().toString(36).substring(2, 8).toUpperCase()
    );

    return {
      secret: secret.base32,
      qrCode: secret.otpauth_url!,
      backupCodes,
    };
  }

  static async generateQRCode(otpUrl: string): Promise<string> {
    return QRCode.toDataURL(otpUrl);
  }

  static verifyToken(secret: string, token: string): boolean {
    return speakeasy.totp.verify({
      secret,
      encoding: 'base32',
      token,
      window: 2, // Allow 2 time steps (60 seconds) tolerance
    });
  }

  static async setupMFA(userId: string): Promise<{
    qrCodeUrl: string;
    backupCodes: string[];
  }> {
    const user = await prisma.user.findUnique({
      where: { id: userId },
    });

    if (!user) {
      throw new Error('User not found');
    }

    const { secret, qrCode, backupCodes } = this.generateSecret(user.email);
    const qrCodeUrl = await this.generateQRCode(qrCode);

    // Store temporarily (user needs to verify before enabling)
    await prisma.user.update({
      where: { id: userId },
      data: {
        mfaSecret: secret,
        mfaBackupCodes: backupCodes,
        mfaEnabled: false, // Not enabled until verified
      },
    });

    return { qrCodeUrl, backupCodes };
  }

  static async enableMFA(userId: string, token: string): Promise<boolean> {
    const user = await prisma.user.findUnique({
      where: { id: userId },
    });

    if (!user?.mfaSecret) {
      throw new Error('MFA not set up');
    }

    const isValid = this.verifyToken(user.mfaSecret, token);
    
    if (isValid) {
      await prisma.user.update({
        where: { id: userId },
        data: { mfaEnabled: true },
      });
    }

    return isValid;
  }

  static async verifyMFA(userId: string, token: string): Promise<boolean> {
    const user = await prisma.user.findUnique({
      where: { id: userId },
    });

    if (!user?.mfaEnabled || !user.mfaSecret) {
      return false;
    }

    // Check if it's a backup code
    if (user.mfaBackupCodes.includes(token.toUpperCase())) {
      // Remove used backup code
      await prisma.user.update({
        where: { id: userId },
        data: {
          mfaBackupCodes: user.mfaBackupCodes.filter(
            code => code !== token.toUpperCase()
          ),
        },
      });
      return true;
    }

    // Verify TOTP token
    return this.verifyToken(user.mfaSecret, token);
  }
}
```

## 🚨 Security Monitoring and Logging

### Security Event Logging
```typescript
// lib/security-logger.ts - Security event monitoring
interface SecurityEvent {
  type: 'login' | 'logout' | 'failed_login' | 'password_change' | 'mfa_enabled' | 'suspicious_activity';
  userId?: string;
  ip: string;
  userAgent: string;
  metadata?: Record<string, any>;
  severity: 'low' | 'medium' | 'high' | 'critical';
}

export class SecurityLogger {
  static async logEvent(event: SecurityEvent) {
    // Log to database
    await prisma.securityEvent.create({
      data: {
        type: event.type,
        userId: event.userId,
        ip: event.ip,
        userAgent: event.userAgent,
        metadata: event.metadata,
        severity: event.severity,
        timestamp: new Date(),
      },
    });

    // Send to monitoring service (e.g., Sentry, DataDog)
    if (event.severity === 'high' || event.severity === 'critical') {
      await this.sendAlert(event);
    }

    // Rate limiting detection
    if (event.type === 'failed_login') {
      await this.checkForBruteForce(event.ip, event.userId);
    }
  }

  private static async sendAlert(event: SecurityEvent) {
    // Implementation depends on your monitoring setup
    console.error('Security Alert:', event);
    
    // Example: Send to Slack webhook
    if (process.env.SLACK_WEBHOOK_URL) {
      await fetch(process.env.SLACK_WEBHOOK_URL, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          text: `🚨 Security Alert: ${event.type}`,
          blocks: [
            {
              type: 'section',
              text: {
                type: 'mrkdwn',
                text: `*Type:* ${event.type}\n*Severity:* ${event.severity}\n*IP:* ${event.ip}\n*User:* ${event.userId || 'Unknown'}`,
              },
            },
          ],
        }),
      });
    }
  }

  private static async checkForBruteForce(ip: string, userId?: string) {
    const timeWindow = 15 * 60 * 1000; // 15 minutes
    const threshold = 10; // 10 failed attempts

    const recentFailures = await prisma.securityEvent.count({
      where: {
        type: 'failed_login',
        ip,
        timestamp: {
          gte: new Date(Date.now() - timeWindow),
        },
      },
    });

    if (recentFailures >= threshold) {
      await this.logEvent({
        type: 'suspicious_activity',
        userId,
        ip,
        userAgent: '',
        metadata: { 
          reason: 'brute_force_detected',
          failedAttempts: recentFailures 
        },
        severity: 'high',
      });

      // Temporarily block IP
      await redis.setex(`blocked:${ip}`, 3600, 'brute_force'); // 1 hour block
    }
  }

  static async checkBlockedIP(ip: string): Promise<boolean> {
    const blocked = await redis.get(`blocked:${ip}`);
    return !!blocked;
  }
}
```

## 🔄 Session Management

### Secure Session Handling
```typescript
// lib/session-manager.ts - Advanced session management
export class SessionManager {
  static async createSession(userId: string, req: NextRequest): Promise<string> {
    const sessionId = crypto.randomUUID();
    const ip = this.getClientIP(req);
    const userAgent = req.headers.get('user-agent') || '';
    
    // Detect device/browser fingerprint
    const fingerprint = await this.generateFingerprint(req);
    
    await prisma.session.create({
      data: {
        id: sessionId,
        userId,
        ip,
        userAgent,
        fingerprint,
        expiresAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000), // 30 days
        lastUsedAt: new Date(),
      },
    });

    return sessionId;
  }

  static async validateSession(sessionId: string, req: NextRequest): Promise<{
    valid: boolean;
    user?: User;
    warnings?: string[];
  }> {
    const session = await prisma.session.findUnique({
      where: { id: sessionId },
      include: { user: true },
    });

    if (!session || session.expiresAt < new Date()) {
      return { valid: false };
    }

    const warnings: string[] = [];
    const currentIP = this.getClientIP(req);
    const currentFingerprint = await this.generateFingerprint(req);

    // Check for suspicious activity
    if (session.ip !== currentIP) {
      warnings.push('IP address changed');
      
      // Log security event
      await SecurityLogger.logEvent({
        type: 'suspicious_activity',
        userId: session.userId,
        ip: currentIP,
        userAgent: req.headers.get('user-agent') || '',
        metadata: { 
          reason: 'ip_change',
          originalIP: session.ip,
          newIP: currentIP 
        },
        severity: 'medium',
      });
    }

    if (session.fingerprint !== currentFingerprint) {
      warnings.push('Device fingerprint changed');
    }

    // Update last used timestamp
    await prisma.session.update({
      where: { id: sessionId },
      data: { 
        lastUsedAt: new Date(),
        ip: currentIP, // Update to current IP
      },
    });

    return {
      valid: true,
      user: session.user,
      warnings,
    };
  }

  private static getClientIP(req: NextRequest): string {
    return req.headers.get('x-forwarded-for')?.split(',')[0] ||
           req.headers.get('x-real-ip') ||
           'unknown';
  }

  private static async generateFingerprint(req: NextRequest): Promise<string> {
    const components = [
      req.headers.get('user-agent') || '',
      req.headers.get('accept-language') || '',
      req.headers.get('accept-encoding') || '',
      req.headers.get('sec-ch-ua') || '',
    ];

    const fingerprint = components.join('|');
    
    // Hash the fingerprint for privacy
    const hash = await crypto.subtle.digest(
      'SHA-256',
      new TextEncoder().encode(fingerprint)
    );
    
    return Array.from(new Uint8Array(hash))
      .map(b => b.toString(16).padStart(2, '0'))
      .join('');
  }

  static async revokeSession(sessionId: string) {
    await prisma.session.delete({
      where: { id: sessionId },
    });
  }

  static async getUserSessions(userId: string) {
    return prisma.session.findMany({
      where: { 
        userId,
        expiresAt: { gt: new Date() },
      },
      orderBy: { lastUsedAt: 'desc' },
    });
  }

  static async revokeAllUserSessions(userId: string, exceptSessionId?: string) {
    await prisma.session.deleteMany({
      where: {
        userId,
        ...(exceptSessionId && { id: { not: exceptSessionId } }),
      },
    });
  }
}
```

## 🔍 Security Best Practices Summary

### Implementation Checklist

#### Authentication
- ✅ Use strong password requirements (length, complexity, entropy)
- ✅ Implement rate limiting for login attempts
- ✅ Hash passwords with bcrypt (12+ rounds)
- ✅ Support multi-factor authentication
- ✅ Validate email addresses before account activation
- ✅ Implement account lockout after failed attempts

#### Session Management
- ✅ Use secure, HTTP-only cookies
- ✅ Implement proper session expiration
- ✅ Generate new session IDs after authentication
- ✅ Monitor for session hijacking attempts
- ✅ Provide session management UI for users
- ✅ Revoke sessions on password change

#### Authorization
- ✅ Implement role-based access control (RBAC)
- ✅ Use principle of least privilege
- ✅ Validate permissions on every request
- ✅ Implement resource-level authorization
- ✅ Use middleware for route protection
- ✅ Handle authorization errors gracefully

#### Security Monitoring
- ✅ Log all authentication events
- ✅ Monitor for suspicious activity patterns
- ✅ Implement automated alerting
- ✅ Track failed login attempts
- ✅ Monitor for unusual IP/device changes
- ✅ Implement security dashboards

#### Data Protection
- ✅ Encrypt sensitive data at rest
- ✅ Use HTTPS everywhere
- ✅ Implement proper CORS policies
- ✅ Set security headers (CSP, HSTS, etc.)
- ✅ Sanitize user inputs
- ✅ Use parameterized queries

---

## 🔗 Navigation

**Previous:** [API Integration Approaches](./api-integration-approaches.md) | **Next:** [Performance Optimization](./performance-optimization.md)