# Secure Authentication Patterns: Frontend Implementation Guide

This document provides comprehensive guidance on implementing secure authentication patterns for frontend applications, with special focus on educational technology platforms requiring robust user identity verification and session management.

## Modern Authentication Architecture

### 1. Token-Based Authentication with JWT

JWT (JSON Web Tokens) provide a stateless authentication mechanism ideal for modern web applications.

```typescript
// Secure JWT authentication implementation
interface JWTPayload {
  sub: string; // Subject (user ID)
  iss: string; // Issuer
  aud: string; // Audience
  exp: number; // Expiration time
  iat: number; // Issued at
  nbf: number; // Not before
  jti: string; // JWT ID
  scope: string[]; // User permissions
  role: string; // User role
  sessionId: string; // Session identifier
}

class SecureJWTManager {
  private readonly algorithm = 'HS256';
  private readonly issuer = 'edtech-platform';
  private readonly audience = 'edtech-users';
  private readonly accessTokenExpiry = 15 * 60; // 15 minutes
  private readonly refreshTokenExpiry = 7 * 24 * 60 * 60; // 7 days

  generateTokenPair(user: AuthenticatedUser): TokenPair {
    const now = Math.floor(Date.now() / 1000);
    const sessionId = this.generateSessionId();

    const accessTokenPayload: JWTPayload = {
      sub: user.id,
      iss: this.issuer,
      aud: this.audience,
      exp: now + this.accessTokenExpiry,
      iat: now,
      nbf: now,
      jti: this.generateJTI(),
      scope: user.permissions,
      role: user.role,
      sessionId
    };

    const refreshTokenPayload = {
      sub: user.id,
      iss: this.issuer,
      aud: this.audience,
      exp: now + this.refreshTokenExpiry,
      iat: now,
      tokenType: 'refresh',
      sessionId
    };

    const accessToken = this.signToken(accessTokenPayload);
    const refreshToken = this.signToken(refreshTokenPayload);

    // Store refresh token securely (database/Redis)
    this.storeRefreshToken(refreshToken, user.id, sessionId);

    return {
      accessToken,
      refreshToken,
      expiresIn: this.accessTokenExpiry,
      tokenType: 'Bearer'
    };
  }

  async validateAccessToken(token: string): Promise<ValidationResult> {
    try {
      const payload = this.verifyToken(token) as JWTPayload;
      
      // Additional security checks
      if (!this.isValidIssuer(payload.iss)) {
        return { isValid: false, error: 'Invalid issuer' };
      }

      if (!this.isValidAudience(payload.aud)) {
        return { isValid: false, error: 'Invalid audience' };
      }

      // Check if session is still active
      const sessionActive = await this.isSessionActive(payload.sessionId);
      if (!sessionActive) {
        return { isValid: false, error: 'Session expired' };
      }

      return {
        isValid: true,
        payload,
        expiresAt: payload.exp * 1000
      };
    } catch (error) {
      return {
        isValid: false,
        error: error instanceof Error ? error.message : 'Token validation failed'
      };
    }
  }

  async refreshAccessToken(refreshToken: string): Promise<TokenRefreshResult> {
    try {
      const payload = this.verifyToken(refreshToken);
      
      if (payload.tokenType !== 'refresh') {
        throw new Error('Invalid token type');
      }

      // Verify refresh token exists in storage
      const storedToken = await this.getStoredRefreshToken(payload.sub, payload.sessionId);
      if (!storedToken || storedToken !== refreshToken) {
        throw new Error('Invalid refresh token');
      }

      // Get current user data
      const user = await this.getUserById(payload.sub);
      if (!user) {
        throw new Error('User not found');
      }

      // Generate new access token
      const newTokenPair = this.generateTokenPair(user);
      
      // Optionally rotate refresh token for enhanced security
      if (this.shouldRotateRefreshToken()) {
        await this.revokeRefreshToken(refreshToken);
        return {
          success: true,
          ...newTokenPair
        };
      }

      return {
        success: true,
        accessToken: newTokenPair.accessToken,
        expiresIn: newTokenPair.expiresIn,
        tokenType: newTokenPair.tokenType
      };
    } catch (error) {
      return {
        success: false,
        error: error instanceof Error ? error.message : 'Token refresh failed'
      };
    }
  }

  private signToken(payload: any): string {
    // In production, use a proper JWT library like jsonwebtoken
    const header = Buffer.from(JSON.stringify({ alg: this.algorithm, typ: 'JWT' })).toString('base64url');
    const payloadStr = Buffer.from(JSON.stringify(payload)).toString('base64url');
    const signature = this.createSignature(`${header}.${payloadStr}`);
    
    return `${header}.${payloadStr}.${signature}`;
  }

  private verifyToken(token: string): any {
    const [header, payload, signature] = token.split('.');
    
    // Verify signature
    const expectedSignature = this.createSignature(`${header}.${payload}`);
    if (signature !== expectedSignature) {
      throw new Error('Invalid token signature');
    }

    const decodedPayload = JSON.parse(Buffer.from(payload, 'base64url').toString());
    
    // Check expiration
    const now = Math.floor(Date.now() / 1000);
    if (decodedPayload.exp && decodedPayload.exp < now) {
      throw new Error('Token expired');
    }

    // Check not before
    if (decodedPayload.nbf && decodedPayload.nbf > now) {
      throw new Error('Token not yet valid');
    }

    return decodedPayload;
  }

  private createSignature(data: string): string {
    // Simplified signature creation - use proper HMAC in production
    const crypto = require('crypto');
    return crypto.createHmac('sha256', process.env.JWT_SECRET).update(data).digest('base64url');
  }

  private generateSessionId(): string {
    return crypto.randomBytes(32).toString('hex');
  }

  private generateJTI(): string {
    return crypto.randomBytes(16).toString('hex');
  }

  private shouldRotateRefreshToken(): boolean {
    // Implement refresh token rotation policy
    return Math.random() < 0.1; // 10% chance of rotation
  }
}
```

### 2. Frontend Authentication State Management

Implement secure authentication state management with automatic token refresh.

```typescript
// React authentication context with secure token management
interface AuthState {
  isAuthenticated: boolean;
  user: User | null;
  loading: boolean;
  error: string | null;
}

interface AuthContextType extends AuthState {
  login: (credentials: LoginCredentials) => Promise<void>;
  logout: () => Promise<void>;
  refreshToken: () => Promise<void>;
  updateUserProfile: (updates: Partial<User>) => Promise<void>;
}

const AuthContext = createContext<AuthContextType | null>(null);

export const AuthProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [state, setState] = useState<AuthState>({
    isAuthenticated: false,
    user: null,
    loading: true,
    error: null
  });

  const tokenManager = useMemo(() => new SecureTokenManager(), []);

  // Auto-refresh token before expiration
  useEffect(() => {
    const scheduleTokenRefresh = async () => {
      const token = await tokenManager.getAccessToken();
      if (token) {
        const payload = tokenManager.decodeToken(token);
        const expiresAt = payload.exp * 1000;
        const refreshTime = expiresAt - (5 * 60 * 1000); // 5 minutes before expiry
        const delay = Math.max(0, refreshTime - Date.now());

        setTimeout(async () => {
          try {
            await refreshToken();
            scheduleTokenRefresh(); // Schedule next refresh
          } catch (error) {
            console.error('Auto token refresh failed:', error);
            await logout();
          }
        }, delay);
      }
    };

    if (state.isAuthenticated) {
      scheduleTokenRefresh();
    }
  }, [state.isAuthenticated]);

  // Initialize authentication state on app start
  useEffect(() => {
    const initializeAuth = async () => {
      try {
        const storedToken = await tokenManager.getAccessToken();
        if (storedToken) {
          const isValid = await tokenManager.validateToken(storedToken);
          if (isValid) {
            const user = await fetchUserProfile();
            setState({
              isAuthenticated: true,
              user,
              loading: false,
              error: null
            });
          } else {
            // Try to refresh token
            await refreshToken();
          }
        } else {
          setState(prev => ({ ...prev, loading: false }));
        }
      } catch (error) {
        setState({
          isAuthenticated: false,
          user: null,
          loading: false,
          error: 'Authentication initialization failed'
        });
      }
    };

    initializeAuth();
  }, []);

  const login = async (credentials: LoginCredentials): Promise<void> => {
    setState(prev => ({ ...prev, loading: true, error: null }));

    try {
      const response = await fetch('/api/auth/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(credentials)
      });

      if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.message || 'Login failed');
      }

      const { accessToken, refreshToken, user } = await response.json();

      // Store tokens securely
      await tokenManager.storeTokens(accessToken, refreshToken);

      setState({
        isAuthenticated: true,
        user,
        loading: false,
        error: null
      });
    } catch (error) {
      setState({
        isAuthenticated: false,
        user: null,
        loading: false,
        error: error instanceof Error ? error.message : 'Login failed'
      });
      throw error;
    }
  };

  const logout = async (): Promise<void> => {
    setState(prev => ({ ...prev, loading: true }));

    try {
      // Revoke tokens on server
      await fetch('/api/auth/logout', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${await tokenManager.getAccessToken()}`
        }
      });
    } catch (error) {
      console.error('Server logout failed:', error);
    } finally {
      // Clear local tokens regardless of server response
      await tokenManager.clearTokens();
      
      setState({
        isAuthenticated: false,
        user: null,
        loading: false,
        error: null
      });
    }
  };

  const refreshToken = async (): Promise<void> => {
    try {
      const currentRefreshToken = await tokenManager.getRefreshToken();
      if (!currentRefreshToken) {
        throw new Error('No refresh token available');
      }

      const response = await fetch('/api/auth/refresh', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ refreshToken: currentRefreshToken })
      });

      if (!response.ok) {
        throw new Error('Token refresh failed');
      }

      const { accessToken, refreshToken: newRefreshToken } = await response.json();

      await tokenManager.storeTokens(accessToken, newRefreshToken || currentRefreshToken);

      // Update user data if needed
      if (state.isAuthenticated) {
        const user = await fetchUserProfile();
        setState(prev => ({ ...prev, user }));
      }
    } catch (error) {
      console.error('Token refresh failed:', error);
      await logout();
      throw error;
    }
  };

  const updateUserProfile = async (updates: Partial<User>): Promise<void> => {
    if (!state.user) return;

    setState(prev => ({ ...prev, loading: true }));

    try {
      const response = await fetch('/api/user/profile', {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${await tokenManager.getAccessToken()}`
        },
        body: JSON.stringify(updates)
      });

      if (!response.ok) {
        throw new Error('Profile update failed');
      }

      const updatedUser = await response.json();
      
      setState(prev => ({
        ...prev,
        user: updatedUser,
        loading: false
      }));
    } catch (error) {
      setState(prev => ({
        ...prev,
        loading: false,
        error: error instanceof Error ? error.message : 'Profile update failed'
      }));
      throw error;
    }
  };

  const contextValue: AuthContextType = {
    ...state,
    login,
    logout,
    refreshToken,
    updateUserProfile
  };

  return (
    <AuthContext.Provider value={contextValue}>
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = (): AuthContextType => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};
```

### 3. Secure Token Storage

Implement secure client-side token storage with multiple fallback options.

```typescript
// Secure token storage manager
class SecureTokenManager {
  private readonly ACCESS_TOKEN_KEY = 'app_access_token';
  private readonly REFRESH_TOKEN_KEY = 'app_refresh_token';
  
  private storageStrategy: TokenStorageStrategy;

  constructor() {
    this.storageStrategy = this.selectBestStorageStrategy();
  }

  private selectBestStorageStrategy(): TokenStorageStrategy {
    // Priority: Memory > Encrypted LocalStorage > SessionStorage > LocalStorage
    if (this.isMemoryStorageAvailable()) {
      return new MemoryTokenStorage();
    } else if (this.isEncryptedStorageAvailable()) {
      return new EncryptedLocalStorage();
    } else if (this.isSessionStorageAvailable()) {
      return new SessionStorageStrategy();
    } else {
      return new LocalStorageStrategy();
    }
  }

  async storeTokens(accessToken: string, refreshToken: string): Promise<void> {
    await this.storageStrategy.setItem(this.ACCESS_TOKEN_KEY, accessToken);
    await this.storageStrategy.setItem(this.REFRESH_TOKEN_KEY, refreshToken, { httpOnly: true });
  }

  async getAccessToken(): Promise<string | null> {
    return this.storageStrategy.getItem(this.ACCESS_TOKEN_KEY);
  }

  async getRefreshToken(): Promise<string | null> {
    return this.storageStrategy.getItem(this.REFRESH_TOKEN_KEY);
  }

  async clearTokens(): Promise<void> {
    await this.storageStrategy.removeItem(this.ACCESS_TOKEN_KEY);
    await this.storageStrategy.removeItem(this.REFRESH_TOKEN_KEY);
  }

  async validateToken(token: string): Promise<boolean> {
    try {
      const payload = this.decodeToken(token);
      const now = Math.floor(Date.now() / 1000);
      
      return payload.exp > now;
    } catch {
      return false;
    }
  }

  decodeToken(token: string): any {
    try {
      const [, payload] = token.split('.');
      return JSON.parse(atob(payload));
    } catch {
      throw new Error('Invalid token format');
    }
  }

  private isMemoryStorageAvailable(): boolean {
    return typeof window !== 'undefined';
  }

  private isEncryptedStorageAvailable(): boolean {
    return typeof window !== 'undefined' && 'crypto' in window && 'subtle' in window.crypto;
  }

  private isSessionStorageAvailable(): boolean {
    try {
      return typeof window !== 'undefined' && 'sessionStorage' in window;
    } catch {
      return false;
    }
  }
}

// Storage strategy implementations
interface TokenStorageStrategy {
  setItem(key: string, value: string, options?: StorageOptions): Promise<void>;
  getItem(key: string): Promise<string | null>;
  removeItem(key: string): Promise<void>;
}

interface StorageOptions {
  httpOnly?: boolean;
  secure?: boolean;
  sameSite?: 'strict' | 'lax' | 'none';
}

class MemoryTokenStorage implements TokenStorageStrategy {
  private storage = new Map<string, string>();

  async setItem(key: string, value: string): Promise<void> {
    this.storage.set(key, value);
  }

  async getItem(key: string): Promise<string | null> {
    return this.storage.get(key) || null;
  }

  async removeItem(key: string): Promise<void> {
    this.storage.delete(key);
  }
}

class EncryptedLocalStorage implements TokenStorageStrategy {
  private readonly encryptionKey: CryptoKey | null = null;

  constructor() {
    this.initializeEncryption();
  }

  private async initializeEncryption(): Promise<void> {
    if (typeof window !== 'undefined' && window.crypto && window.crypto.subtle) {
      try {
        // Generate or retrieve encryption key
        const keyData = localStorage.getItem('storage_key');
        if (keyData) {
          const keyBuffer = Uint8Array.from(atob(keyData), c => c.charCodeAt(0));
          // @ts-ignore - Type issues with CryptoKey
          this.encryptionKey = await window.crypto.subtle.importKey(
            'raw',
            keyBuffer,
            { name: 'AES-GCM' },
            false,
            ['encrypt', 'decrypt']
          );
        } else {
          // @ts-ignore - Type issues with CryptoKey
          this.encryptionKey = await window.crypto.subtle.generateKey(
            { name: 'AES-GCM', length: 256 },
            true,
            ['encrypt', 'decrypt']
          );
          
          const exportedKey = await window.crypto.subtle.exportKey('raw', this.encryptionKey);
          const keyString = btoa(String.fromCharCode(...new Uint8Array(exportedKey)));
          localStorage.setItem('storage_key', keyString);
        }
      } catch (error) {
        console.error('Failed to initialize encryption:', error);
      }
    }
  }

  async setItem(key: string, value: string): Promise<void> {
    if (!this.encryptionKey) {
      localStorage.setItem(key, value);
      return;
    }

    try {
      const iv = window.crypto.getRandomValues(new Uint8Array(12));
      const encodedValue = new TextEncoder().encode(value);
      
      const encryptedData = await window.crypto.subtle.encrypt(
        { name: 'AES-GCM', iv },
        this.encryptionKey,
        encodedValue
      );

      const encryptedString = btoa(String.fromCharCode(...new Uint8Array(encryptedData)));
      const ivString = btoa(String.fromCharCode(...iv));
      
      localStorage.setItem(key, `${ivString}:${encryptedString}`);
    } catch (error) {
      console.error('Encryption failed, falling back to plain storage:', error);
      localStorage.setItem(key, value);
    }
  }

  async getItem(key: string): Promise<string | null> {
    const stored = localStorage.getItem(key);
    if (!stored || !this.encryptionKey) {
      return stored;
    }

    try {
      const [ivString, encryptedString] = stored.split(':');
      if (!ivString || !encryptedString) {
        return stored; // Fallback for non-encrypted data
      }

      const iv = Uint8Array.from(atob(ivString), c => c.charCodeAt(0));
      const encryptedData = Uint8Array.from(atob(encryptedString), c => c.charCodeAt(0));

      const decryptedData = await window.crypto.subtle.decrypt(
        { name: 'AES-GCM', iv },
        this.encryptionKey,
        encryptedData
      );

      return new TextDecoder().decode(decryptedData);
    } catch (error) {
      console.error('Decryption failed:', error);
      return null;
    }
  }

  async removeItem(key: string): Promise<void> {
    localStorage.removeItem(key);
  }
}

class SessionStorageStrategy implements TokenStorageStrategy {
  async setItem(key: string, value: string): Promise<void> {
    sessionStorage.setItem(key, value);
  }

  async getItem(key: string): Promise<string | null> {
    return sessionStorage.getItem(key);
  }

  async removeItem(key: string): Promise<void> {
    sessionStorage.removeItem(key);
  }
}

class LocalStorageStrategy implements TokenStorageStrategy {
  async setItem(key: string, value: string): Promise<void> {
    localStorage.setItem(key, value);
  }

  async getItem(key: string): Promise<string | null> {
    return localStorage.getItem(key);
  }

  async removeItem(key: string): Promise<void> {
    localStorage.removeItem(key);
  }
}
```

### 4. Multi-Factor Authentication (MFA) Integration

Implement comprehensive MFA support for enhanced security.

```typescript
// Multi-factor authentication manager
class MFAManager {
  private readonly mfaMethods = ['totp', 'sms', 'email', 'backup_codes'] as const;
  
  async initiateSetup(userId: string, method: MFAMethod): Promise<MFASetupResult> {
    switch (method) {
      case 'totp':
        return this.setupTOTP(userId);
      case 'sms':
        return this.setupSMS(userId);
      case 'email':
        return this.setupEmail(userId);
      default:
        throw new Error(`Unsupported MFA method: ${method}`);
    }
  }

  private async setupTOTP(userId: string): Promise<MFASetupResult> {
    const secret = this.generateTOTPSecret();
    const qrCode = await this.generateQRCode(userId, secret);
    const backupCodes = this.generateBackupCodes();

    // Store setup temporarily until verification
    await this.storeTempMFASetup(userId, {
      method: 'totp',
      secret,
      backupCodes,
      expiresAt: Date.now() + (10 * 60 * 1000) // 10 minutes
    });

    return {
      method: 'totp',
      secret,
      qrCode,
      backupCodes,
      setupToken: this.generateSetupToken(userId, 'totp')
    };
  }

  async verifySetup(userId: string, setupToken: string, verificationCode: string): Promise<MFAVerificationResult> {
    const setup = await this.getTempMFASetup(userId, setupToken);
    if (!setup || setup.expiresAt < Date.now()) {
      return { success: false, error: 'Setup expired or not found' };
    }

    let isValid = false;

    switch (setup.method) {
      case 'totp':
        isValid = this.verifyTOTPCode(setup.secret, verificationCode);
        break;
      case 'sms':
      case 'email':
        isValid = await this.verifyOTPCode(userId, verificationCode);
        break;
      default:
        return { success: false, error: 'Invalid setup method' };
    }

    if (isValid) {
      // Finalize MFA setup
      await this.finalizeMFASetup(userId, setup);
      await this.clearTempMFASetup(userId, setupToken);

      return {
        success: true,
        backupCodes: setup.backupCodes,
        recoveryInstructions: this.getRecoveryInstructions(setup.method)
      };
    }

    return { success: false, error: 'Invalid verification code' };
  }

  async challengeMFA(userId: string, preferredMethod?: MFAMethod): Promise<MFAChallengeResult> {
    const userMFAMethods = await this.getUserMFAMethods(userId);
    if (userMFAMethods.length === 0) {
      return { success: false, error: 'MFA not configured' };
    }

    const method = preferredMethod && userMFAMethods.includes(preferredMethod) 
      ? preferredMethod 
      : userMFAMethods[0];

    const challengeId = this.generateChallengeId();

    switch (method) {
      case 'totp':
        return {
          success: true,
          challengeId,
          method: 'totp',
          message: 'Enter the code from your authenticator app'
        };

      case 'sms':
        const smsResult = await this.sendSMSCode(userId, challengeId);
        return {
          success: smsResult.success,
          challengeId,
          method: 'sms',
          message: smsResult.message,
          maskedPhone: smsResult.maskedPhone
        };

      case 'email':
        const emailResult = await this.sendEmailCode(userId, challengeId);
        return {
          success: emailResult.success,
          challengeId,
          method: 'email',
          message: emailResult.message,
          maskedEmail: emailResult.maskedEmail
        };

      default:
        return { success: false, error: 'Invalid MFA method' };
    }
  }

  async verifyMFAChallenge(
    userId: string, 
    challengeId: string, 
    code: string, 
    isBackupCode = false
  ): Promise<MFAVerificationResult> {
    const challenge = await this.getMFAChallenge(challengeId);
    if (!challenge || challenge.userId !== userId || challenge.expiresAt < Date.now()) {
      return { success: false, error: 'Invalid or expired challenge' };
    }

    let isValid = false;

    if (isBackupCode) {
      isValid = await this.verifyBackupCode(userId, code);
    } else {
      switch (challenge.method) {
        case 'totp':
          const userTOTPSecret = await this.getUserTOTPSecret(userId);
          isValid = this.verifyTOTPCode(userTOTPSecret, code);
          break;
        case 'sms':
        case 'email':
          isValid = await this.verifyOTPCode(userId, code, challengeId);
          break;
      }
    }

    // Clear challenge after verification attempt
    await this.clearMFAChallenge(challengeId);

    if (isValid) {
      return {
        success: true,
        mfaToken: this.generateMFAToken(userId),
        validFor: 5 * 60 * 1000 // 5 minutes
      };
    }

    // Increment failed attempts
    await this.incrementFailedMFAAttempts(userId);

    return { success: false, error: 'Invalid verification code' };
  }

  private generateTOTPSecret(): string {
    return crypto.randomBytes(20).toString('base32');
  }

  private async generateQRCode(userId: string, secret: string): Promise<string> {
    const issuer = 'EdTech Platform';
    const label = `${issuer}:${userId}`;
    const otpauth = `otpauth://totp/${encodeURIComponent(label)}?secret=${secret}&issuer=${encodeURIComponent(issuer)}`;
    
    // Generate QR code (would use a QR code library in production)
    return `data:image/svg+xml;base64,${Buffer.from(`<svg>QR Code for ${otpauth}</svg>`).toString('base64')}`;
  }

  private generateBackupCodes(): string[] {
    return Array.from({ length: 8 }, () => 
      Array.from({ length: 2 }, () => 
        Math.random().toString(36).substr(2, 4).toUpperCase()
      ).join('-')
    );
  }

  private verifyTOTPCode(secret: string, code: string): boolean {
    // Implementation would use a TOTP library like speakeasy
    const timeStep = Math.floor(Date.now() / 30000);
    
    // Check current time step and adjacent ones for clock drift
    for (let i = -1; i <= 1; i++) {
      const expectedCode = this.generateTOTPCode(secret, timeStep + i);
      if (expectedCode === code) return true;
    }
    
    return false;
  }

  private generateTOTPCode(secret: string, timeStep: number): string {
    // Simplified TOTP implementation - use proper library in production
    const hash = crypto.createHmac('sha1', Buffer.from(secret, 'base32'));
    hash.update(Buffer.from([
      (timeStep >> 24) & 0xff,
      (timeStep >> 16) & 0xff,
      (timeStep >> 8) & 0xff,
      timeStep & 0xff
    ]));
    
    const hmac = hash.digest();
    const offset = hmac[hmac.length - 1] & 0xf;
    const code = ((hmac[offset] & 0x7f) << 24) |
                 ((hmac[offset + 1] & 0xff) << 16) |
                 ((hmac[offset + 2] & 0xff) << 8) |
                 (hmac[offset + 3] & 0xff);
    
    return (code % 1000000).toString().padStart(6, '0');
  }

  private generateChallengeId(): string {
    return crypto.randomBytes(16).toString('hex');
  }

  private generateSetupToken(userId: string, method: string): string {
    return crypto.createHash('sha256')
      .update(`${userId}:${method}:${Date.now()}:${crypto.randomBytes(16).toString('hex')}`)
      .digest('hex');
  }

  private generateMFAToken(userId: string): string {
    return crypto.createHash('sha256')
      .update(`${userId}:mfa:${Date.now()}:${crypto.randomBytes(16).toString('hex')}`)
      .digest('hex');
  }

  private async sendSMSCode(userId: string, challengeId: string): Promise<SMSResult> {
    // Implementation would integrate with SMS service
    const code = Math.floor(100000 + Math.random() * 900000).toString();
    const userPhone = await this.getUserPhone(userId);
    
    if (!userPhone) {
      return { success: false, message: 'No phone number configured' };
    }

    // Store code for verification
    await this.storeOTPCode(userId, challengeId, code, 5 * 60 * 1000); // 5 minutes

    // Send SMS (mock implementation)
    console.log(`SMS code ${code} sent to ${userPhone}`);

    return {
      success: true,
      message: 'Verification code sent to your phone',
      maskedPhone: this.maskPhoneNumber(userPhone)
    };
  }

  private async sendEmailCode(userId: string, challengeId: string): Promise<EmailResult> {
    // Implementation would integrate with email service
    const code = Math.floor(100000 + Math.random() * 900000).toString();
    const userEmail = await this.getUserEmail(userId);
    
    if (!userEmail) {
      return { success: false, message: 'No email address configured' };
    }

    // Store code for verification
    await this.storeOTPCode(userId, challengeId, code, 10 * 60 * 1000); // 10 minutes

    // Send email (mock implementation)
    console.log(`Email code ${code} sent to ${userEmail}`);

    return {
      success: true,
      message: 'Verification code sent to your email',
      maskedEmail: this.maskEmail(userEmail)
    };
  }

  private maskPhoneNumber(phone: string): string {
    return phone.replace(/(\d{3})\d{3}(\d{4})/, '$1***$2');
  }

  private maskEmail(email: string): string {
    const [local, domain] = email.split('@');
    const maskedLocal = local.length > 2 
      ? local[0] + '*'.repeat(local.length - 2) + local[local.length - 1]
      : local;
    return `${maskedLocal}@${domain}`;
  }

  // Helper methods (would be implemented with actual database/cache)
  private async storeTempMFASetup(userId: string, setup: any): Promise<void> {}
  private async getTempMFASetup(userId: string, token: string): Promise<any> { return null; }
  private async clearTempMFASetup(userId: string, token: string): Promise<void> {}
  private async finalizeMFASetup(userId: string, setup: any): Promise<void> {}
  private async getUserMFAMethods(userId: string): Promise<MFAMethod[]> { return []; }
  private async getMFAChallenge(challengeId: string): Promise<any> { return null; }
  private async clearMFAChallenge(challengeId: string): Promise<void> {}
  private async storeOTPCode(userId: string, challengeId: string, code:string, ttl: number): Promise<void> {}
  private async verifyOTPCode(userId: string, code: string, challengeId?: string): Promise<boolean> { return false; }
  private async verifyBackupCode(userId: string, code: string): Promise<boolean> { return false; }
  private async getUserTOTPSecret(userId: string): Promise<string> { return ''; }
  private async getUserPhone(userId: string): Promise<string | null> { return null; }
  private async getUserEmail(userId: string): Promise<string | null> { return null; }
  private async incrementFailedMFAAttempts(userId: string): Promise<void> {}
  private getRecoveryInstructions(method: MFAMethod): string {
    return `If you lose access to your ${method} device, use backup codes or contact support.`;
  }
}
```

### 5. React Components for Authentication UI

Create reusable, secure authentication components.

```typescript
// Login component with security features
interface LoginFormProps {
  onLogin: (credentials: LoginCredentials) => Promise<void>;
  onForgotPassword: (email: string) => Promise<void>;
  loading?: boolean;
  error?: string;
}

export const SecureLoginForm: React.FC<LoginFormProps> = ({
  onLogin,
  onForgotPassword,
  loading = false,
  error
}) => {
  const [formData, setFormData] = useState({
    email: '',
    password: '',
    rememberMe: false
  });
  
  const [showPassword, setShowPassword] = useState(false);
  const [loginAttempts, setLoginAttempts] = useState(0);
  const [isLocked, setIsLocked] = useState(false);
  const [lockTimeRemaining, setLockTimeRemaining] = useState(0);

  // Rate limiting for login attempts
  useEffect(() => {
    if (loginAttempts >= 5) {
      setIsLocked(true);
      setLockTimeRemaining(300); // 5 minutes lockout
      
      const interval = setInterval(() => {
        setLockTimeRemaining(prev => {
          if (prev <= 1) {
            setIsLocked(false);
            setLoginAttempts(0);
            clearInterval(interval);
            return 0;
          }
          return prev - 1;
        });
      }, 1000);
      
      return () => clearInterval(interval);
    }
  }, [loginAttempts]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    if (isLocked) {
      return;
    }

    try {
      await onLogin({
        email: formData.email.trim().toLowerCase(),
        password: formData.password,
        rememberMe: formData.rememberMe
      });
      
      // Reset attempts on successful login
      setLoginAttempts(0);
    } catch (error) {
      setLoginAttempts(prev => prev + 1);
      throw error;
    }
  };

  const handleForgotPassword = async () => {
    if (!formData.email) {
      alert('Please enter your email address first');
      return;
    }
    
    try {
      await onForgotPassword(formData.email.trim().toLowerCase());
      alert('Password reset instructions sent to your email');
    } catch (error) {
      console.error('Forgot password failed:', error);
    }
  };

  const formatLockTime = (seconds: number): string => {
    const minutes = Math.floor(seconds / 60);
    const remainingSeconds = seconds % 60;
    return `${minutes}:${remainingSeconds.toString().padStart(2, '0')}`;
  };

  return (
    <div className={styles.loginContainer}>
      <form onSubmit={handleSubmit} className={styles.loginForm}>
        <h2>Sign In</h2>
        
        {error && (
          <div className={styles.errorMessage} role="alert">
            {error}
          </div>
        )}
        
        {isLocked && (
          <div className={styles.lockoutMessage} role="alert">
            Too many failed login attempts. Please wait {formatLockTime(lockTimeRemaining)} before trying again.
          </div>
        )}

        <div className={styles.formGroup}>
          <label htmlFor="email">Email Address</label>
          <input
            id="email"
            type="email"
            value={formData.email}
            onChange={(e) => setFormData(prev => ({ ...prev, email: e.target.value }))}
            required
            disabled={loading || isLocked}
            autoComplete="email"
            className={styles.formInput}
          />
        </div>

        <div className={styles.formGroup}>
          <label htmlFor="password">Password</label>
          <div className={styles.passwordInput}>
            <input
              id="password"
              type={showPassword ? 'text' : 'password'}
              value={formData.password}
              onChange={(e) => setFormData(prev => ({ ...prev, password: e.target.value }))}
              required
              disabled={loading || isLocked}
              autoComplete="current-password"
              className={styles.formInput}
            />
            <button
              type="button"
              onClick={() => setShowPassword(!showPassword)}
              className={styles.passwordToggle}
              aria-label={showPassword ? 'Hide password' : 'Show password'}
              disabled={loading || isLocked}
            >
              {showPassword ? '👁️' : '👁️‍🗨️'}
            </button>
          </div>
        </div>

        <div className={styles.formOptions}>
          <label className={styles.checkbox}>
            <input
              type="checkbox"
              checked={formData.rememberMe}
              onChange={(e) => setFormData(prev => ({ ...prev, rememberMe: e.target.checked }))}
              disabled={loading || isLocked}
            />
            Remember me
          </label>
          
          <button
            type="button"
            onClick={handleForgotPassword}
            className={styles.linkButton}
            disabled={loading || isLocked}
          >
            Forgot password?
          </button>
        </div>

        <button
          type="submit"
          disabled={loading || isLocked || !formData.email || !formData.password}
          className={styles.submitButton}
        >
          {loading ? 'Signing in...' : 'Sign In'}
        </button>

        {loginAttempts > 0 && loginAttempts < 5 && (
          <div className={styles.attemptWarning}>
            {5 - loginAttempts} attempts remaining before temporary lockout
          </div>
        )}
      </form>
    </div>
  );
};

// MFA verification component
interface MFAVerificationProps {
  challengeResult: MFAChallengeResult;
  onVerify: (code: string, isBackupCode?: boolean) => Promise<void>;
  onCancel: () => void;
  loading?: boolean;
  error?: string;
}

export const MFAVerification: React.FC<MFAVerificationProps> = ({
  challengeResult,
  onVerify,
  onCancel,
  loading = false,
  error
}) => {
  const [code, setCode] = useState('');
  const [useBackupCode, setUseBackupCode] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    await onVerify(code, useBackupCode);
  };

  const getInstructions = () => {
    if (useBackupCode) {
      return 'Enter one of your backup codes';
    }
    
    switch (challengeResult.method) {
      case 'totp':
        return 'Enter the 6-digit code from your authenticator app';
      case 'sms':
        return `Enter the verification code sent to ${challengeResult.maskedPhone}`;
      case 'email':
        return `Enter the verification code sent to ${challengeResult.maskedEmail}`;
      default:
        return 'Enter your verification code';
    }
  };

  return (
    <div className={styles.mfaContainer}>
      <form onSubmit={handleSubmit} className={styles.mfaForm}>
        <h2>Two-Factor Authentication</h2>
        
        <p className={styles.instructions}>
          {getInstructions()}
        </p>
        
        {error && (
          <div className={styles.errorMessage} role="alert">
            {error}
          </div>
        )}

        <div className={styles.formGroup}>
          <label htmlFor="mfaCode">
            {useBackupCode ? 'Backup Code' : 'Verification Code'}
          </label>
          <input
            id="mfaCode"
            type="text"
            value={code}
            onChange={(e) => setCode(e.target.value.replace(/\D/g, ''))} // Only digits
            maxLength={useBackupCode ? 10 : 6}
            required
            disabled={loading}
            autoComplete="one-time-code"
            className={styles.codeInput}
            placeholder={useBackupCode ? 'XXXX-XXXX' : '000000'}
          />
        </div>

        <div className={styles.formActions}>
          <button
            type="submit"
            disabled={loading || !code || (useBackupCode ? code.length < 8 : code.length !== 6)}
            className={styles.submitButton}
          >
            {loading ? 'Verifying...' : 'Verify'}
          </button>
          
          <button
            type="button"
            onClick={onCancel}
            disabled={loading}
            className={styles.cancelButton}
          >
            Cancel
          </button>
        </div>

        <div className={styles.alternativeOptions}>
          <button
            type="button"
            onClick={() => {
              setUseBackupCode(!useBackupCode);
              setCode('');
            }}
            className={styles.linkButton}
            disabled={loading}
          >
            {useBackupCode ? 'Use authenticator code' : 'Use backup code'}
          </button>
        </div>
      </form>
    </div>
  );
};
```

## Authentication Best Practices Checklist

### Token Security
- [ ] **JWT Security**: Secure JWT implementation with proper signing
- [ ] **Token Storage**: Secure client-side token storage
- [ ] **Token Rotation**: Automatic access token refresh
- [ ] **Token Revocation**: Server-side token revocation capability
- [ ] **Token Validation**: Comprehensive token validation

### Session Management
- [ ] **Session Security**: Secure session configuration
- [ ] **Session Timeout**: Appropriate session timeout values
- [ ] **Concurrent Sessions**: Control over concurrent session limits
- [ ] **Session Monitoring**: Active session monitoring and management
- [ ] **Session Revocation**: Ability to revoke all user sessions

### Multi-Factor Authentication
- [ ] **MFA Implementation**: Comprehensive MFA support
- [ ] **Multiple Methods**: Support for TOTP, SMS, email
- [ ] **Backup Codes**: Secure backup code generation and validation
- [ ] **Recovery Process**: Account recovery procedures
- [ ] **MFA Enforcement**: Conditional MFA based on risk

### Security Controls
- [ ] **Rate Limiting**: Login attempt rate limiting
- [ ] **Account Lockout**: Temporary account lockout after failed attempts
- [ ] **Password Security**: Strong password requirements
- [ ] **Encryption**: Data encryption in transit and at rest
- [ ] **Audit Logging**: Comprehensive authentication audit logging

---

## Navigation

- ← Back to: [Frontend Security Best Practices](./README.md)
- → Next: [Testing Security Implementations](./testing-security-implementations.md)
- → Previous: [Security Considerations](./security-considerations.md)
- → Related: [Best Practices](./best-practices.md)