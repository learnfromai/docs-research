# Module Federation Deep Dive Guide

Comprehensive guide to Webpack 5 Module Federation for micro-frontend architecture, covering advanced configurations, optimization strategies, and production-ready implementations.

{% hint style="info" %}
**Focus**: Webpack 5 Module Federation advanced patterns and configurations
**Target**: Production-ready educational technology platforms
**Optimization**: Mobile-first performance for Philippine market
{% endhint %}

## Module Federation Core Concepts

### Architecture Overview
Module Federation enables JavaScript applications to dynamically import code from other independently deployed applications at runtime. This creates a distributed system where each micro-frontend can be developed, deployed, and scaled independently.

```mermaid
graph TB
    Container[Container Application]
    Container --> Auth[Auth Micro-frontend]
    Container --> Dashboard[Dashboard Micro-frontend]
    Container --> Nursing[Nursing Exam Module]
    Container --> UI[Shared UI Components]
    
    Auth --> UI
    Dashboard --> UI
    Nursing --> UI
    
    Container -.->|Runtime Loading| RemoteAuth[auth@http://cdn.example.com/remoteEntry.js]
    Container -.->|Runtime Loading| RemoteDashboard[dashboard@http://cdn.example.com/remoteEntry.js]
```

### Key Components

#### 1. Host Application (Container)
The main application that consumes remote modules from other micro-frontends.

#### 2. Remote Application (Micro-frontend)
Independent applications that expose modules for consumption by host applications.

#### 3. Shared Dependencies
Libraries and modules shared between host and remote applications to avoid duplication.

#### 4. Federation Runtime
Webpack's runtime that handles module loading, dependency resolution, and version management.

## Advanced Module Federation Configuration

### 1. Production-Ready Container Configuration

```javascript
// apps/container/webpack.config.js
const ModuleFederationPlugin = require('@module-federation/webpack');
const HtmlWebpackPlugin = require('html-webpack-plugin');
const { DefinePlugin } = require('webpack');

const dependencies = require('./package.json').dependencies;

module.exports = (env, argv) => {
  const isProduction = argv.mode === 'production';
  
  return {
    mode: isProduction ? 'production' : 'development',
    devtool: isProduction ? 'source-map' : 'eval-source-map',
    
    entry: './src/index.ts',
    
    devServer: {
      port: 3000,
      historyApiFallback: true,
      hot: true,
      headers: {
        'Access-Control-Allow-Origin': '*',
      },
    },
    
    module: {
      rules: [
        {
          test: /\.(js|jsx|ts|tsx)$/,
          exclude: /node_modules/,
          use: {
            loader: 'babel-loader',
            options: {
              presets: [
                ['@babel/preset-env', { targets: { browsers: ['last 2 versions'] } }],
                '@babel/preset-react',
                '@babel/preset-typescript'
              ],
              plugins: [
                '@babel/plugin-transform-runtime',
                isProduction && 'babel-plugin-transform-remove-console'
              ].filter(Boolean),
            },
          },
        },
        {
          test: /\.css$/,
          use: ['style-loader', 'css-loader', 'postcss-loader'],
        },
        {
          test: /\.(png|jpe?g|gif|svg)$/i,
          type: 'asset/resource',
        },
      ],
    },
    
    resolve: {
      extensions: ['.js', '.jsx', '.ts', '.tsx'],
      alias: {
        '@': path.resolve(__dirname, 'src'),
      },
    },
    
    plugins: [
      new ModuleFederationPlugin({
        name: 'container',
        remotes: {
          // Dynamic remote loading based on environment
          auth: `auth@${getRemoteUrl('auth', isProduction)}/remoteEntry.js`,
          dashboard: `dashboard@${getRemoteUrl('dashboard', isProduction)}/remoteEntry.js`,
          nursing: `nursing@${getRemoteUrl('nursing', isProduction)}/remoteEntry.js`,
          uiComponents: `uiComponents@${getRemoteUrl('uiComponents', isProduction)}/remoteEntry.js`,
        },
        shared: {
          // Shared dependencies with version management
          react: {
            singleton: true,
            eager: true,
            requiredVersion: dependencies.react,
          },
          'react-dom': {
            singleton: true,
            eager: true,
            requiredVersion: dependencies['react-dom'],
          },
          'react-router-dom': {
            singleton: true,
            requiredVersion: dependencies['react-router-dom'],
          },
          '@emotion/react': {
            singleton: true,
            requiredVersion: dependencies['@emotion/react'],
          },
          '@emotion/styled': {
            singleton: true,
            requiredVersion: dependencies['@emotion/styled'],
          },
        },
      }),
      
      new HtmlWebpackPlugin({
        template: './public/index.html',
        minify: isProduction,
      }),
      
      new DefinePlugin({
        'process.env.NODE_ENV': JSON.stringify(isProduction ? 'production' : 'development'),
        'process.env.MICRO_FRONTEND_URLS': JSON.stringify({
          auth: getRemoteUrl('auth', isProduction),
          dashboard: getRemoteUrl('dashboard', isProduction),
          nursing: getRemoteUrl('nursing', isProduction),
          uiComponents: getRemoteUrl('uiComponents', isProduction),
        }),
      }),
    ],
    
    optimization: {
      splitChunks: {
        chunks: 'all',
        cacheGroups: {
          vendor: {
            test: /[\\/]node_modules[\\/]/,
            name: 'vendors',
            chunks: 'all',
          },
        },
      },
    },
  };
};

function getRemoteUrl(appName, isProduction) {
  if (isProduction) {
    return `https://cdn.edtech-platform.com/${appName}`;
  }
  
  const devPorts = {
    auth: 3001,
    dashboard: 3002,
    nursing: 3003,
    uiComponents: 3010,
  };
  
  return `http://localhost:${devPorts[appName]}`;
}
```

### 2. Advanced Remote Application Configuration

```javascript
// apps/auth/webpack.config.js
const ModuleFederationPlugin = require('@module-federation/webpack');
const dependencies = require('./package.json').dependencies;

module.exports = (env, argv) => {
  const isProduction = argv.mode === 'production';
  
  return {
    mode: isProduction ? 'production' : 'development',
    
    entry: './src/index.ts',
    
    devServer: {
      port: 3001,
      headers: {
        'Access-Control-Allow-Origin': '*',
      },
    },
    
    module: {
      rules: [
        {
          test: /\.(js|jsx|ts|tsx)$/,
          exclude: /node_modules/,
          use: {
            loader: 'babel-loader',
            options: {
              presets: [
                '@babel/preset-env',
                '@babel/preset-react',
                '@babel/preset-typescript'
              ],
            },
          },
        },
      ],
    },
    
    plugins: [
      new ModuleFederationPlugin({
        name: 'auth',
        filename: 'remoteEntry.js',
        
        // Expose multiple modules
        exposes: {
          './AuthApp': './src/AuthApp',
          './LoginForm': './src/components/LoginForm',
          './authUtils': './src/utils/authUtils',
          './authHooks': './src/hooks/authHooks',
          './AuthProvider': './src/context/AuthProvider',
        },
        
        // Consume shared UI components
        remotes: {
          uiComponents: `uiComponents@${getRemoteUrl('uiComponents', isProduction)}/remoteEntry.js`,
        },
        
        shared: {
          react: {
            singleton: true,
            requiredVersion: dependencies.react,
          },
          'react-dom': {
            singleton: true,
            requiredVersion: dependencies['react-dom'],
          },
          'react-router-dom': {
            singleton: true,
            requiredVersion: dependencies['react-router-dom'],
          },
          // Share utilities without eager loading
          'date-fns': {
            singleton: false,
            requiredVersion: dependencies['date-fns'],
          },
        },
      }),
    ],
  };
};
```

## Dynamic Remote Loading

### 1. Runtime Remote Loading

```typescript
// apps/container/src/utils/dynamicRemoteLoader.ts
interface RemoteModule {
  name: string;
  url: string;
  module: string;
  version?: string;
}

export class DynamicRemoteLoader {
  private static loadedRemotes = new Map<string, any>();
  
  static async loadRemote({ name, url, module }: RemoteModule): Promise<any> {
    const cacheKey = `${name}/${module}`;
    
    if (this.loadedRemotes.has(cacheKey)) {
      return this.loadedRemotes.get(cacheKey);
    }
    
    try {
      // Load the remote container
      await this.loadScript(url);
      
      // Get the container
      const container = (window as any)[name];
      
      if (!container) {
        throw new Error(`Remote container ${name} not found`);
      }
      
      // Initialize the container
      await container.init(__webpack_share_scopes__.default);
      
      // Load the specific module
      const factory = await container.get(module);
      const Module = factory();
      
      this.loadedRemotes.set(cacheKey, Module);
      return Module;
      
    } catch (error) {
      console.error(`Failed to load remote ${name}/${module}:`, error);
      throw error;
    }
  }
  
  private static loadScript(url: string): Promise<void> {
    return new Promise((resolve, reject) => {
      const existingScript = document.querySelector(`script[src="${url}"]`);
      
      if (existingScript) {
        resolve();
        return;
      }
      
      const script = document.createElement('script');
      script.src = url;
      script.type = 'text/javascript';
      
      script.onload = () => resolve();
      script.onerror = (error) => reject(error);
      
      document.head.appendChild(script);
    });
  }
  
  static preloadRemote(remote: RemoteModule): void {
    // Preload remote for faster subsequent loading
    const link = document.createElement('link');
    link.rel = 'preload';
    link.href = remote.url;
    link.as = 'script';
    document.head.appendChild(link);
  }
}
```

### 2. Dynamic Component Loading

```typescript
// apps/container/src/components/DynamicRemoteComponent.tsx
import React, { Suspense, useState, useEffect } from 'react';
import { DynamicRemoteLoader } from '../utils/dynamicRemoteLoader';
import { ErrorBoundary } from './ErrorBoundary';
import { LoadingSpinner } from './LoadingSpinner';

interface DynamicRemoteComponentProps {
  remote: {
    name: string;
    url: string;
    module: string;
  };
  fallback?: React.ComponentType;
  props?: Record<string, any>;
}

export const DynamicRemoteComponent: React.FC<DynamicRemoteComponentProps> = ({
  remote,
  fallback: Fallback,
  props = {},
}) => {
  const [Component, setComponent] = useState<React.ComponentType | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);
  
  useEffect(() => {
    let mounted = true;
    
    const loadComponent = async () => {
      try {
        setLoading(true);
        setError(null);
        
        const RemoteComponent = await DynamicRemoteLoader.loadRemote(remote);
        
        if (mounted) {
          setComponent(() => RemoteComponent.default || RemoteComponent);
        }
      } catch (err) {
        if (mounted) {
          setError(err as Error);
        }
      } finally {
        if (mounted) {
          setLoading(false);
        }
      }
    };
    
    loadComponent();
    
    return () => {
      mounted = false;
    };
  }, [remote.name, remote.url, remote.module]);
  
  if (loading) {
    return <LoadingSpinner />;
  }
  
  if (error) {
    if (Fallback) {
      return <Fallback />;
    }
    return (
      <div className="remote-error">
        <p>Failed to load component: {error.message}</p>
        <button onClick={() => window.location.reload()}>
          Retry
        </button>
      </div>
    );
  }
  
  if (!Component) {
    return Fallback ? <Fallback /> : null;
  }
  
  return (
    <ErrorBoundary>
      <Suspense fallback={<LoadingSpinner />}>
        <Component {...props} />
      </Suspense>
    </ErrorBoundary>
  );
};
```

## Advanced Shared Dependency Management

### 1. Selective Sharing Strategy

```javascript
// Shared configuration for optimal bundle splitting
const createSharedConfig = (dependencies) => ({
  // Critical runtime dependencies - always shared
  react: {
    singleton: true,
    eager: true,
    requiredVersion: dependencies.react,
  },
  'react-dom': {
    singleton: true,
    eager: true,
    requiredVersion: dependencies['react-dom'],
  },
  
  // Router - shared but not eager (loaded when needed)
  'react-router-dom': {
    singleton: true,
    eager: false,
    requiredVersion: dependencies['react-router-dom'],
  },
  
  // UI libraries - shared to maintain consistency
  '@emotion/react': {
    singleton: true,
    eager: false,
    requiredVersion: dependencies['@emotion/react'],
  },
  
  // Utility libraries - not shared to allow version flexibility
  'date-fns': {
    singleton: false,
    eager: false,
    requiredVersion: false, // Allow any version
  },
  
  // Large libraries - shared to reduce bundle size
  'lodash': {
    singleton: true,
    eager: false,
    requiredVersion: dependencies.lodash,
  },
  
  // State management - shared for global state
  'zustand': {
    singleton: true,
    eager: false,
    requiredVersion: dependencies.zustand,
  },
});
```

### 2. Version Conflict Resolution

```typescript
// apps/container/src/utils/versionManager.ts
interface VersionInfo {
  name: string;
  version: string;
  requiredVersion?: string;
  loaded?: boolean;
}

export class VersionManager {
  private static sharedVersions = new Map<string, VersionInfo>();
  
  static registerSharedDependency(name: string, version: string, requiredVersion?: string) {
    const existing = this.sharedVersions.get(name);
    
    if (existing && existing.version !== version) {
      console.warn(
        `Version conflict for ${name}: loaded ${existing.version}, required ${version}`
      );
      
      // Strategy: Use the higher version
      if (this.compareVersions(version, existing.version) > 0) {
        this.sharedVersions.set(name, { name, version, requiredVersion, loaded: true });
      }
    } else {
      this.sharedVersions.set(name, { name, version, requiredVersion, loaded: true });
    }
  }
  
  static getSharedVersion(name: string): string | undefined {
    return this.sharedVersions.get(name)?.version;
  }
  
  private static compareVersions(a: string, b: string): number {
    const aParts = a.split('.').map(Number);
    const bParts = b.split('.').map(Number);
    
    for (let i = 0; i < Math.max(aParts.length, bParts.length); i++) {
      const aPart = aParts[i] || 0;
      const bPart = bParts[i] || 0;
      
      if (aPart > bPart) return 1;
      if (aPart < bPart) return -1;
    }
    
    return 0;
  }
  
  static validateCompatibility(): boolean {
    let compatible = true;
    
    this.sharedVersions.forEach((info, name) => {
      if (info.requiredVersion && info.version !== info.requiredVersion) {
        console.error(
          `Incompatible version for ${name}: loaded ${info.version}, required ${info.requiredVersion}`
        );
        compatible = false;
      }
    });
    
    return compatible;
  }
}
```

## Cross-Application Communication

### 1. Event-Based Communication

```typescript
// packages/utils/src/eventBus.ts
type EventHandler<T = any> = (data: T) => void;

export class MicroFrontendEventBus {
  private static instance: MicroFrontendEventBus;
  private eventHandlers = new Map<string, Set<EventHandler>>();
  
  static getInstance(): MicroFrontendEventBus {
    if (!MicroFrontendEventBus.instance) {
      MicroFrontendEventBus.instance = new MicroFrontendEventBus();
    }
    return MicroFrontendEventBus.instance;
  }
  
  subscribe<T>(event: string, handler: EventHandler<T>): () => void {
    if (!this.eventHandlers.has(event)) {
      this.eventHandlers.set(event, new Set());
    }
    
    this.eventHandlers.get(event)!.add(handler);
    
    // Return unsubscribe function
    return () => {
      const handlers = this.eventHandlers.get(event);
      if (handlers) {
        handlers.delete(handler);
        if (handlers.size === 0) {
          this.eventHandlers.delete(event);
        }
      }
    };
  }
  
  emit<T>(event: string, data?: T): void {
    const handlers = this.eventHandlers.get(event);
    if (handlers) {
      handlers.forEach(handler => {
        try {
          handler(data);
        } catch (error) {
          console.error(`Error in event handler for ${event}:`, error);
        }
      });
    }
    
    // Also emit as custom DOM event for maximum compatibility
    window.dispatchEvent(new CustomEvent(`mf:${event}`, { detail: data }));
  }
  
  once<T>(event: string, handler: EventHandler<T>): void {
    const unsubscribe = this.subscribe(event, (data) => {
      handler(data);
      unsubscribe();
    });
  }
}

// Usage examples for educational platform
export const eventBus = MicroFrontendEventBus.getInstance();

// Events for educational platform
export const Events = {
  USER_LOGGED_IN: 'user:logged-in',
  USER_LOGGED_OUT: 'user:logged-out',
  EXAM_STARTED: 'exam:started',
  EXAM_COMPLETED: 'exam:completed',
  PROGRESS_UPDATED: 'progress:updated',
  SUBSCRIPTION_CHANGED: 'subscription:changed',
} as const;
```

### 2. Shared State Management

```typescript
// packages/utils/src/sharedState.ts
import { create } from 'zustand';
import { subscribeWithSelector } from 'zustand/middleware';

interface User {
  id: string;
  email: string;
  name: string;
  subscriptions: string[];
  role: 'student' | 'admin' | 'instructor';
}

interface ExamProgress {
  examId: string;
  progress: number;
  score?: number;
  completed: boolean;
  timeRemaining?: number;
}

interface SharedState {
  // User state
  user: User | null;
  isAuthenticated: boolean;
  
  // Exam state
  currentExam: ExamProgress | null;
  examHistory: ExamProgress[];
  
  // UI state
  sidebarOpen: boolean;
  theme: 'light' | 'dark';
  
  // Actions
  setUser: (user: User | null) => void;
  setCurrentExam: (exam: ExamProgress | null) => void;
  updateExamProgress: (progress: Partial<ExamProgress>) => void;
  toggleSidebar: () => void;
  setTheme: (theme: 'light' | 'dark') => void;
}

export const useSharedStore = create<SharedState>()(
  subscribeWithSelector((set, get) => ({
    // Initial state
    user: null,
    isAuthenticated: false,
    currentExam: null,
    examHistory: [],
    sidebarOpen: false,
    theme: 'light',
    
    // Actions
    setUser: (user) => {
      set({ user, isAuthenticated: !!user });
      
      // Emit event for other micro-frontends
      if (user) {
        eventBus.emit(Events.USER_LOGGED_IN, user);
      } else {
        eventBus.emit(Events.USER_LOGGED_OUT);
      }
    },
    
    setCurrentExam: (exam) => {
      set({ currentExam: exam });
      
      if (exam) {
        eventBus.emit(Events.EXAM_STARTED, exam);
      }
    },
    
    updateExamProgress: (progress) => {
      const { currentExam } = get();
      if (currentExam) {
        const updatedExam = { ...currentExam, ...progress };
        set({ currentExam: updatedExam });
        
        eventBus.emit(Events.PROGRESS_UPDATED, updatedExam);
        
        if (updatedExam.completed) {
          eventBus.emit(Events.EXAM_COMPLETED, updatedExam);
        }
      }
    },
    
    toggleSidebar: () => set((state) => ({ sidebarOpen: !state.sidebarOpen })),
    
    setTheme: (theme) => {
      set({ theme });
      document.documentElement.setAttribute('data-theme', theme);
      localStorage.setItem('theme', theme);
    },
  }))
);

// Subscribe to state changes for cross-app synchronization
useSharedStore.subscribe(
  (state) => state.user,
  (user) => {
    // Sync user state across all micro-frontends
    localStorage.setItem('user', JSON.stringify(user));
  }
);
```

## Performance Optimization Strategies

### 1. Lazy Loading and Code Splitting

```typescript
// apps/container/src/components/LazyMicroFrontend.tsx
import React, { Suspense, lazy } from 'react';
import { ErrorBoundary } from './ErrorBoundary';
import { LoadingSpinner } from './LoadingSpinner';

// Lazy load micro-frontends with retry mechanism
const createLazyMicroFrontend = (importFn: () => Promise<any>, retries = 3) => {
  return lazy(() => 
    importFn().catch((error) => {
      if (retries > 0) {
        console.warn(`Retrying micro-frontend load, ${retries} attempts remaining`);
        return new Promise((resolve) => {
          setTimeout(() => resolve(createLazyMicroFrontend(importFn, retries - 1)), 1000);
        });
      }
      throw error;
    })
  );
};

// Lazy-loaded micro-frontends
export const AuthApp = createLazyMicroFrontend(() => import('auth/AuthApp'));
export const Dashboard = createLazyMicroFrontend(() => import('dashboard/Dashboard'));
export const NursingExam = createLazyMicroFrontend(() => import('nursing/NursingApp'));

// Wrapper component with optimization
interface LazyMicroFrontendProps {
  children: React.ReactNode;
  fallback?: React.ComponentType;
}

export const LazyMicroFrontend: React.FC<LazyMicroFrontendProps> = ({
  children,
  fallback: Fallback = LoadingSpinner,
}) => {
  return (
    <ErrorBoundary>
      <Suspense fallback={<Fallback />}>
        {children}
      </Suspense>
    </ErrorBoundary>
  );
};
```

### 2. Bundle Size Optimization

```javascript
// webpack.optimization.js - Shared optimization configuration
const createOptimizationConfig = (isProduction) => ({
  splitChunks: {
    chunks: 'all',
    minSize: 20000,
    maxSize: 244000,
    cacheGroups: {
      // Vendor libraries
      vendor: {
        test: /[\\/]node_modules[\\/]/,
        name: 'vendors',
        chunks: 'all',
        priority: 10,
      },
      
      // React ecosystem
      react: {
        test: /[\\/]node_modules[\\/](react|react-dom|react-router-dom)[\\/]/,
        name: 'react',
        chunks: 'all',
        priority: 20,
      },
      
      // UI libraries
      ui: {
        test: /[\\/]node_modules[\\/](@emotion|@mui|styled-components)[\\/]/,
        name: 'ui',
        chunks: 'all',
        priority: 15,
      },
      
      // Common utilities
      utils: {
        test: /[\\/]node_modules[\\/](lodash|date-fns|ramda)[\\/]/,
        name: 'utils',
        chunks: 'all',
        priority: 5,
      },
    },
  },
  
  runtimeChunk: {
    name: 'runtime',
  },
  
  minimize: isProduction,
  minimizer: isProduction ? [
    new TerserPlugin({
      terserOptions: {
        compress: {
          drop_console: true,
          drop_debugger: true,
        },
      },
    }),
    new CssMinimizerPlugin(),
  ] : [],
});
```

### 3. Resource Preloading

```typescript
// apps/container/src/utils/resourcePreloader.ts
interface PreloadResource {
  url: string;
  type: 'script' | 'style' | 'font' | 'image';
  crossorigin?: boolean;
}

export class ResourcePreloader {
  private static preloadedResources = new Set<string>();
  
  static preloadMicroFrontends(microFrontends: string[]): void {
    microFrontends.forEach(mf => {
      const remoteUrl = process.env.MICRO_FRONTEND_URLS?.[mf];
      if (remoteUrl && !this.preloadedResources.has(remoteUrl)) {
        this.preloadScript(`${remoteUrl}/remoteEntry.js`);
        this.preloadedResources.add(remoteUrl);
      }
    });
  }
  
  static preloadScript(url: string): void {
    const link = document.createElement('link');
    link.rel = 'modulepreload';
    link.href = url;
    document.head.appendChild(link);
  }
  
  static preloadStylesheet(url: string): void {
    const link = document.createElement('link');
    link.rel = 'preload';
    link.href = url;
    link.as = 'style';
    document.head.appendChild(link);
  }
  
  static preloadFont(url: string): void {
    const link = document.createElement('link');
    link.rel = 'preload';
    link.href = url;
    link.as = 'font';
    link.type = 'font/woff2';
    link.crossOrigin = 'anonymous';
    document.head.appendChild(link);
  }
  
  // Preload critical resources for educational platform
  static preloadCriticalResources(): void {
    // Preload authentication module (likely to be used first)
    this.preloadMicroFrontends(['auth', 'uiComponents']);
    
    // Preload fonts for better text rendering
    this.preloadFont('/fonts/inter-var.woff2');
    
    // Preload critical images
    this.preloadImage('/images/logo.svg');
    this.preloadImage('/images/hero-education.webp');
  }
  
  private static preloadImage(url: string): void {
    const link = document.createElement('link');
    link.rel = 'preload';
    link.href = url;
    link.as = 'image';
    document.head.appendChild(link);
  }
}
```

## Security Considerations

### 1. Content Security Policy (CSP)

```javascript
// CSP configuration for micro-frontends
const createCSPConfig = (isProduction) => {
  const allowedSources = isProduction
    ? [
        "'self'",
        'https://cdn.edtech-platform.com',
        'https://api.edtech-platform.com',
      ]
    : [
        "'self'",
        'http://localhost:*',
        'ws://localhost:*',
      ];
  
  return {
    'default-src': ["'self'"],
    'script-src': [
      ...allowedSources,
      "'unsafe-inline'", // Required for Module Federation runtime
      "'unsafe-eval'", // Required for dynamic imports
    ],
    'style-src': [
      ...allowedSources,
      "'unsafe-inline'", // Required for CSS-in-JS
    ],
    'connect-src': [
      ...allowedSources,
      'https://api.stripe.com', // Payment processing
    ],
    'img-src': [
      ...allowedSources,
      'data:', // For inline images
      'https://images.unsplash.com', // Educational images
    ],
    'font-src': [
      ...allowedSources,
      'https://fonts.gstatic.com',
    ],
    'worker-src': ["'self'"],
    'child-src': ["'self'"],
  };
};
```

### 2. Secure Communication

```typescript
// packages/utils/src/secureComm.ts
interface SecureMessage {
  id: string;
  timestamp: number;
  source: string;
  target: string;
  payload: any;
  signature?: string;
}

export class SecureMicroFrontendComm {
  private static instance: SecureMicroFrontendComm;
  private trustedOrigins = new Set<string>();
  private messageHandlers = new Map<string, (message: SecureMessage) => void>();
  
  static getInstance(): SecureMicroFrontendComm {
    if (!SecureMicroFrontendComm.instance) {
      SecureMicroFrontendComm.instance = new SecureMicroFrontendComm();
    }
    return SecureMicroFrontendComm.instance;
  }
  
  constructor() {
    window.addEventListener('message', this.handleMessage.bind(this));
  }
  
  addTrustedOrigin(origin: string): void {
    this.trustedOrigins.add(origin);
  }
  
  sendSecureMessage(
    target: string,
    type: string,
    payload: any,
    targetWindow?: Window
  ): void {
    const message: SecureMessage = {
      id: this.generateId(),
      timestamp: Date.now(),
      source: window.location.origin,
      target,
      payload: {
        type,
        data: payload,
      },
    };
    
    // Add signature for integrity
    message.signature = this.signMessage(message);
    
    const window = targetWindow || window.parent;
    window.postMessage(message, target);
  }
  
  onSecureMessage(type: string, handler: (data: any) => void): void {
    this.messageHandlers.set(type, handler);
  }
  
  private handleMessage(event: MessageEvent<SecureMessage>): void {
    // Verify origin
    if (!this.trustedOrigins.has(event.origin)) {
      console.warn('Received message from untrusted origin:', event.origin);
      return;
    }
    
    const message = event.data;
    
    // Verify message structure
    if (!this.isValidMessage(message)) {
      console.warn('Received invalid message:', message);
      return;
    }
    
    // Verify signature
    if (!this.verifySignature(message)) {
      console.warn('Message signature verification failed');
      return;
    }
    
    // Handle message
    const handler = this.messageHandlers.get(message.payload.type);
    if (handler) {
      handler(message.payload.data);
    }
  }
  
  private isValidMessage(message: any): message is SecureMessage {
    return (
      message &&
      typeof message.id === 'string' &&
      typeof message.timestamp === 'number' &&
      typeof message.source === 'string' &&
      typeof message.target === 'string' &&
      message.payload &&
      typeof message.payload.type === 'string'
    );
  }
  
  private signMessage(message: SecureMessage): string {
    // Simple signature - in production, use proper cryptographic signing
    const payload = JSON.stringify({
      id: message.id,
      timestamp: message.timestamp,
      source: message.source,
      target: message.target,
      payload: message.payload,
    });
    
    return btoa(payload); // Base64 encode as simple signature
  }
  
  private verifySignature(message: SecureMessage): boolean {
    const expectedSignature = this.signMessage({
      ...message,
      signature: undefined,
    });
    
    return message.signature === expectedSignature;
  }
  
  private generateId(): string {
    return Math.random().toString(36).substr(2, 9);
  }
}
```

## Deployment and CDN Optimization

### 1. Multi-CDN Deployment Strategy

```javascript
// deployment/cdn-deployment.js
const deploymentConfig = {
  production: {
    cdnUrls: {
      primary: 'https://cdn.edtech-platform.com',
      fallback: 'https://backup-cdn.edtech-platform.com',
      regional: {
        asia: 'https://asia.cdn.edtech-platform.com',
        us: 'https://us.cdn.edtech-platform.com',
        eu: 'https://eu.cdn.edtech-platform.com',
      },
    },
    microFrontends: {
      container: { path: '/container', version: '1.2.0' },
      auth: { path: '/auth', version: '1.1.5' },
      dashboard: { path: '/dashboard', version: '1.3.2' },
      nursing: { path: '/nursing', version: '2.0.1' },
      uiComponents: { path: '/ui-components', version: '1.4.0' },
    },
  },
};

// Dynamic CDN selection based on user location
function selectOptimalCDN(userRegion) {
  const config = deploymentConfig.production;
  
  // Use regional CDN if available
  if (config.cdnUrls.regional[userRegion]) {
    return config.cdnUrls.regional[userRegion];
  }
  
  // Fallback to primary CDN
  return config.cdnUrls.primary;
}

// Generate remote URLs with CDN optimization
function generateRemoteUrls(userRegion = 'global') {
  const baseCDN = selectOptimalCDN(userRegion);
  const config = deploymentConfig.production;
  
  return Object.entries(config.microFrontends).reduce((urls, [name, info]) => {
    urls[name] = `${baseCDN}${info.path}/v${info.version}/remoteEntry.js`;
    return urls;
  }, {});
}
```

### 2. Versioning and Rollback Strategy

```typescript
// deployment/version-manager.ts
interface DeploymentVersion {
  version: string;
  timestamp: Date;
  remoteUrl: string;
  healthCheck: string;
  rollbackUrl?: string;
}

export class MicroFrontendVersionManager {
  private static deploymentHistory = new Map<string, DeploymentVersion[]>();
  
  static async deployVersion(
    microFrontendName: string,
    version: string,
    remoteUrl: string
  ): Promise<boolean> {
    try {
      // Health check before deployment
      const isHealthy = await this.performHealthCheck(remoteUrl);
      if (!isHealthy) {
        throw new Error('Health check failed');
      }
      
      // Record deployment
      const deployment: DeploymentVersion = {
        version,
        timestamp: new Date(),
        remoteUrl,
        healthCheck: `${remoteUrl}/health`,
      };
      
      const history = this.deploymentHistory.get(microFrontendName) || [];
      history.push(deployment);
      this.deploymentHistory.set(microFrontendName, history);
      
      // Update active version
      await this.updateActiveVersion(microFrontendName, deployment);
      
      return true;
    } catch (error) {
      console.error(`Deployment failed for ${microFrontendName}:`, error);
      return false;
    }
  }
  
  static async rollback(microFrontendName: string): Promise<boolean> {
    const history = this.deploymentHistory.get(microFrontendName);
    if (!history || history.length < 2) {
      console.error('No previous version available for rollback');
      return false;
    }
    
    // Get previous version (second to last)
    const previousVersion = history[history.length - 2];
    
    try {
      // Health check previous version
      const isHealthy = await this.performHealthCheck(previousVersion.remoteUrl);
      if (!isHealthy) {
        throw new Error('Previous version health check failed');
      }
      
      // Update active version to previous
      await this.updateActiveVersion(microFrontendName, previousVersion);
      
      console.log(`Rolled back ${microFrontendName} to version ${previousVersion.version}`);
      return true;
    } catch (error) {
      console.error(`Rollback failed for ${microFrontendName}:`, error);
      return false;
    }
  }
  
  private static async performHealthCheck(remoteUrl: string): Promise<boolean> {
    try {
      const response = await fetch(`${remoteUrl}/health`, {
        method: 'GET',
        timeout: 5000,
      });
      
      return response.ok;
    } catch (error) {
      console.error('Health check failed:', error);
      return false;
    }
  }
  
  private static async updateActiveVersion(
    microFrontendName: string,
    deployment: DeploymentVersion
  ): Promise<void> {
    // Update container application configuration
    await fetch('/api/micro-frontends/update-version', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        name: microFrontendName,
        version: deployment.version,
        remoteUrl: deployment.remoteUrl,
      }),
    });
  }
}
```

## Monitoring and Observability

### 1. Performance Monitoring

```typescript
// packages/utils/src/monitoring.ts
interface PerformanceMetrics {
  microFrontendName: string;
  loadTime: number;
  bundleSize: number;
  renderTime: number;
  errorCount: number;
  userInteractions: number;
}

export class MicroFrontendMonitoring {
  private static metrics = new Map<string, PerformanceMetrics>();
  
  static trackLoadTime(microFrontendName: string, startTime: number): void {
    const loadTime = performance.now() - startTime;
    
    const existing = this.metrics.get(microFrontendName) || {
      microFrontendName,
      loadTime: 0,
      bundleSize: 0,
      renderTime: 0,
      errorCount: 0,
      userInteractions: 0,
    };
    
    existing.loadTime = loadTime;
    this.metrics.set(microFrontendName, existing);
    
    // Send to analytics
    this.sendMetrics(microFrontendName, { loadTime });
    
    // Performance budget alerts
    if (loadTime > 3000) { // 3 seconds threshold
      console.warn(`${microFrontendName} load time exceeded budget: ${loadTime}ms`);
    }
  }
  
  static trackBundleSize(microFrontendName: string, size: number): void {
    const existing = this.metrics.get(microFrontendName);
    if (existing) {
      existing.bundleSize = size;
      this.metrics.set(microFrontendName, existing);
    }
    
    // Bundle size budget alerts
    if (size > 500000) { // 500KB threshold
      console.warn(`${microFrontendName} bundle size exceeded budget: ${size} bytes`);
    }
  }
  
  static trackError(microFrontendName: string, error: Error): void {
    const existing = this.metrics.get(microFrontendName);
    if (existing) {
      existing.errorCount++;
      this.metrics.set(microFrontendName, existing);
    }
    
    // Send error to monitoring service
    this.sendError(microFrontendName, error);
  }
  
  private static sendMetrics(microFrontendName: string, metrics: Partial<PerformanceMetrics>): void {
    // Send to analytics service (Google Analytics, DataDog, etc.)
    if (typeof gtag !== 'undefined') {
      gtag('event', 'micro_frontend_performance', {
        micro_frontend: microFrontendName,
        ...metrics,
      });
    }
  }
  
  private static sendError(microFrontendName: string, error: Error): void {
    // Send to error tracking service (Sentry, Bugsnag, etc.)
    if (typeof Sentry !== 'undefined') {
      Sentry.captureException(error, {
        tags: {
          microFrontend: microFrontendName,
        },
      });
    }
  }
  
  static getMetrics(): Map<string, PerformanceMetrics> {
    return new Map(this.metrics);
  }
}
```

## Conclusion

Module Federation provides a powerful foundation for building scalable micro-frontend architectures. Key takeaways:

### Best Practices Summary
1. **Start Simple**: Begin with basic configuration, add complexity gradually
2. **Performance First**: Implement performance monitoring and budgets from day one
3. **Security by Design**: Implement CSP and secure communication patterns
4. **Version Management**: Plan for deployment, rollback, and version conflicts
5. **Monitoring**: Comprehensive observability across all micro-frontends

### Common Pitfalls to Avoid
- Over-sharing dependencies leading to version conflicts
- Ignoring bundle size budgets and performance implications
- Insufficient error handling and fallback strategies
- Poor communication patterns between micro-frontends
- Lack of proper security boundaries

### Next Steps
1. Implement basic Module Federation setup
2. Add comprehensive testing strategy
3. Set up CI/CD pipelines for independent deployments
4. Implement monitoring and observability
5. Optimize for mobile performance (Philippine market focus)

Module Federation enables the architectural foundation needed for building scalable educational platforms that can compete globally while serving the specific needs of the Philippine market.

---

**Navigation**
- ← Back to: [Implementation Guide](implementation-guide.md)
- → Next: [Best Practices](best-practices.md)
- → Related: [Performance Considerations](performance-considerations.md)