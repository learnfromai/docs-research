# Implementation Guide: Micro-Frontend Architecture

Step-by-step guide for implementing micro-frontend architecture using Module Federation, with specific focus on educational technology platforms and modern development practices.

{% hint style="info" %}
**Implementation Focus**: Webpack 5 Module Federation with React ecosystem
**Target Platform**: Educational technology platform for Philippine licensure exam reviews
**Development Context**: Modern TypeScript, CI/CD integration, mobile-first optimization
{% endhint %}

## Prerequisites & Environment Setup

### Development Environment Requirements
```bash
# Node.js and Package Manager
Node.js: >= 18.0.0 (LTS recommended)
npm: >= 8.0.0 or yarn >= 1.22.0 or pnpm >= 7.0.0

# Development Tools
Git: >= 2.30.0
Docker: >= 20.10.0 (for containerized deployment)
VS Code: Latest (recommended IDE)
```

### Required Knowledge
- **JavaScript/TypeScript**: Advanced proficiency
- **React**: Hooks, Context API, component patterns
- **Webpack**: Basic configuration knowledge helpful
- **Git**: Branching strategies, CI/CD concepts
- **Docker**: Basic containerization concepts

## Project Structure Overview

```
edtech-platform/
├── apps/
│   ├── container/                 # Shell application
│   ├── auth/                     # Authentication micro-frontend
│   ├── dashboard/                # User dashboard
│   ├── exam-modules/             # Subject-specific exam modules
│   │   ├── nursing/
│   │   ├── engineering/
│   │   └── accounting/
│   └── admin/                    # Administrative interface
├── packages/
│   ├── ui-components/            # Shared design system
│   ├── utils/                    # Shared utilities
│   └── types/                    # Shared TypeScript types
├── tools/
│   ├── webpack-configs/          # Shared webpack configurations
│   └── deployment/               # Deployment scripts and configurations
└── docs/                         # Documentation
```

## Phase 1: Container Application Setup

### 1.1 Initialize Container Application

```bash
# Create container application
mkdir edtech-platform && cd edtech-platform
mkdir apps/container && cd apps/container

# Initialize with npm and TypeScript
npm init -y
npm install react react-dom react-router-dom
npm install -D @types/react @types/react-dom typescript webpack webpack-cli webpack-dev-server html-webpack-plugin @module-federation/webpack
```

### 1.2 Container Webpack Configuration

Create `apps/container/webpack.config.js`:

```javascript
const ModuleFederationPlugin = require('@module-federation/webpack');
const HtmlWebpackPlugin = require('html-webpack-plugin');

module.exports = {
  mode: 'development',
  devServer: {
    port: 3000,
    historyApiFallback: true,
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
      {
        test: /\.css$/,
        use: ['style-loader', 'css-loader'],
      },
    ],
  },
  resolve: {
    extensions: ['.js', '.jsx', '.ts', '.tsx'],
  },
  plugins: [
    new ModuleFederationPlugin({
      name: 'container',
      remotes: {
        auth: 'auth@http://localhost:3001/remoteEntry.js',
        dashboard: 'dashboard@http://localhost:3002/remoteEntry.js',
        nursing: 'nursing@http://localhost:3003/remoteEntry.js',
        uiComponents: 'uiComponents@http://localhost:3010/remoteEntry.js',
      },
      shared: {
        react: { singleton: true, eager: true },
        'react-dom': { singleton: true, eager: true },
        'react-router-dom': { singleton: true },
      },
    }),
    new HtmlWebpackPlugin({
      template: './public/index.html',
    }),
  ],
};
```

### 1.3 Container Application Code

Create `apps/container/src/App.tsx`:

```typescript
import React, { Suspense } from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import { ErrorBoundary } from './components/ErrorBoundary';
import { LoadingSpinner } from './components/LoadingSpinner';
import { AuthProvider } from './context/AuthContext';
import { Header } from './components/Header';

// Lazy load micro-frontends
const AuthApp = React.lazy(() => import('auth/AuthApp'));
const Dashboard = React.lazy(() => import('dashboard/Dashboard'));
const NursingExam = React.lazy(() => import('nursing/NursingApp'));

function App() {
  return (
    <ErrorBoundary>
      <AuthProvider>
        <Router>
          <div className="app">
            <Header />
            <main className="main-content">
              <Suspense fallback={<LoadingSpinner />}>
                <Routes>
                  <Route path="/auth/*" element={<AuthApp />} />
                  <Route path="/dashboard/*" element={<Dashboard />} />
                  <Route path="/exams/nursing/*" element={<NursingExam />} />
                  <Route path="/" element={<Navigate to="/dashboard" replace />} />
                </Routes>
              </Suspense>
            </main>
          </div>
        </Router>
      </AuthProvider>
    </ErrorBoundary>
  );
}

export default App;
```

### 1.4 Error Boundary Component

Create `apps/container/src/components/ErrorBoundary.tsx`:

```typescript
import React, { Component, ErrorInfo, ReactNode } from 'react';

interface Props {
  children: ReactNode;
}

interface State {
  hasError: boolean;
  error: Error | null;
}

export class ErrorBoundary extends Component<Props, State> {
  public state: State = {
    hasError: false,
    error: null,
  };

  public static getDerivedStateFromError(error: Error): State {
    return { hasError: true, error };
  }

  public componentDidCatch(error: Error, errorInfo: ErrorInfo) {
    console.error('Micro-frontend error:', error, errorInfo);
    
    // Log to monitoring service
    if (process.env.NODE_ENV === 'production') {
      // Sentry, LogRocket, or similar service
      this.logErrorToService(error, errorInfo);
    }
  }

  private logErrorToService = (error: Error, errorInfo: ErrorInfo) => {
    // Implementation for error logging service
    console.error('Logging error to monitoring service:', { error, errorInfo });
  };

  public render() {
    if (this.state.hasError) {
      return (
        <div className="error-boundary">
          <h2>Something went wrong with this module</h2>
          <p>Please try refreshing the page or contact support if the problem persists.</p>
          <button onClick={() => this.setState({ hasError: false, error: null })}>
            Try Again
          </button>
        </div>
      );
    }

    return this.props.children;
  }
}
```

## Phase 2: Shared UI Components Library

### 2.1 Initialize Shared Components

```bash
# Create shared UI components package
mkdir -p packages/ui-components && cd packages/ui-components
npm init -y
npm install react react-dom
npm install -D @types/react @types/react-dom typescript webpack webpack-cli webpack-dev-server
```

### 2.2 UI Components Webpack Configuration

Create `packages/ui-components/webpack.config.js`:

```javascript
const ModuleFederationPlugin = require('@module-federation/webpack');

module.exports = {
  mode: 'development',
  devServer: {
    port: 3010,
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
      {
        test: /\.css$/,
        use: ['style-loader', 'css-loader'],
      },
    ],
  },
  resolve: {
    extensions: ['.js', '.jsx', '.ts', '.tsx'],
  },
  plugins: [
    new ModuleFederationPlugin({
      name: 'uiComponents',
      filename: 'remoteEntry.js',
      exposes: {
        './Button': './src/components/Button',
        './Input': './src/components/Input',
        './Card': './src/components/Card',
        './Modal': './src/components/Modal',
        './LoadingSpinner': './src/components/LoadingSpinner',
      },
      shared: {
        react: { singleton: true },
        'react-dom': { singleton: true },
      },
    }),
  ],
};
```

### 2.3 Shared Components Implementation

Create `packages/ui-components/src/components/Button.tsx`:

```typescript
import React from 'react';
import './Button.css';

export interface ButtonProps {
  variant?: 'primary' | 'secondary' | 'danger';
  size?: 'small' | 'medium' | 'large';
  disabled?: boolean;
  loading?: boolean;
  children: React.ReactNode;
  onClick?: () => void;
  type?: 'button' | 'submit' | 'reset';
}

export const Button: React.FC<ButtonProps> = ({
  variant = 'primary',
  size = 'medium',
  disabled = false,
  loading = false,
  children,
  onClick,
  type = 'button',
}) => {
  const className = `btn btn--${variant} btn--${size} ${loading ? 'btn--loading' : ''} ${disabled ? 'btn--disabled' : ''}`;

  return (
    <button
      type={type}
      className={className}
      disabled={disabled || loading}
      onClick={onClick}
    >
      {loading ? (
        <>
          <span className="btn__spinner" />
          Loading...
        </>
      ) : (
        children
      )}
    </button>
  );
};
```

## Phase 3: Authentication Micro-Frontend

### 3.1 Initialize Authentication App

```bash
# Create authentication micro-frontend
mkdir apps/auth && cd apps/auth
npm init -y
npm install react react-dom react-router-dom
npm install -D @types/react @types/react-dom typescript webpack webpack-cli webpack-dev-server
```

### 3.2 Authentication Webpack Configuration

Create `apps/auth/webpack.config.js`:

```javascript
const ModuleFederationPlugin = require('@module-federation/webpack');

module.exports = {
  mode: 'development',
  devServer: {
    port: 3001,
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
  resolve: {
    extensions: ['.js', '.jsx', '.ts', '.tsx'],
  },
  plugins: [
    new ModuleFederationPlugin({
      name: 'auth',
      filename: 'remoteEntry.js',
      exposes: {
        './AuthApp': './src/AuthApp',
        './authUtils': './src/utils/authUtils',
      },
      remotes: {
        uiComponents: 'uiComponents@http://localhost:3010/remoteEntry.js',
      },
      shared: {
        react: { singleton: true },
        'react-dom': { singleton: true },
        'react-router-dom': { singleton: true },
      },
    }),
  ],
};
```

### 3.3 Authentication App Implementation

Create `apps/auth/src/AuthApp.tsx`:

```typescript
import React from 'react';
import { Routes, Route } from 'react-router-dom';
import { LoginPage } from './pages/LoginPage';
import { RegisterPage } from './pages/RegisterPage';
import { ForgotPasswordPage } from './pages/ForgotPasswordPage';

const AuthApp: React.FC = () => {
  return (
    <div className="auth-app">
      <Routes>
        <Route path="/login" element={<LoginPage />} />
        <Route path="/register" element={<RegisterPage />} />
        <Route path="/forgot-password" element={<ForgotPasswordPage />} />
        <Route path="/" element={<LoginPage />} />
      </Routes>
    </div>
  );
};

export default AuthApp;
```

Create `apps/auth/src/pages/LoginPage.tsx`:

```typescript
import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
// @ts-ignore - Module federation types
import { Button } from 'uiComponents/Button';
// @ts-ignore - Module federation types
import { Input } from 'uiComponents/Input';

export const LoginPage: React.FC = () => {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const navigate = useNavigate();

  const handleLogin = async () => {
    setLoading(true);
    try {
      // Implement authentication logic
      const response = await fetch('/api/auth/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password }),
      });

      if (response.ok) {
        const { token, user } = await response.json();
        localStorage.setItem('authToken', token);
        
        // Notify container app of successful login
        window.dispatchEvent(new CustomEvent('auth:login', { 
          detail: { user, token } 
        }));
        
        navigate('/dashboard');
      } else {
        throw new Error('Login failed');
      }
    } catch (error) {
      console.error('Login error:', error);
      // Handle error state
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="login-page">
      <div className="login-form">
        <h1>EdTech Platform Login</h1>
        <Input
          type="email"
          placeholder="Email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
        />
        <Input
          type="password"
          placeholder="Password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
        />
        <Button
          variant="primary"
          loading={loading}
          onClick={handleLogin}
        >
          Login
        </Button>
      </div>
    </div>
  );
};
```

## Phase 4: Educational Module Implementation

### 4.1 Nursing Exam Module Setup

```bash
# Create nursing exam micro-frontend
mkdir apps/exam-modules/nursing && cd apps/exam-modules/nursing
npm init -y
npm install react react-dom react-router-dom
npm install -D @types/react @types/react-dom typescript webpack webpack-cli webpack-dev-server
```

### 4.2 Nursing Module Implementation

Create `apps/exam-modules/nursing/src/NursingApp.tsx`:

```typescript
import React from 'react';
import { Routes, Route } from 'react-router-dom';
import { ExamList } from './components/ExamList';
import { ExamTaking } from './components/ExamTaking';
import { ExamResults } from './components/ExamResults';
import { StudyMaterials } from './components/StudyMaterials';

const NursingApp: React.FC = () => {
  return (
    <div className="nursing-app">
      <Routes>
        <Route path="/" element={<ExamList />} />
        <Route path="/study" element={<StudyMaterials />} />
        <Route path="/exam/:examId" element={<ExamTaking />} />
        <Route path="/results/:examId" element={<ExamResults />} />
      </Routes>
    </div>
  );
};

export default NursingApp;
```

## Phase 5: Development Workflow & Tools

### 5.1 Development Scripts

Create root `package.json` with workspace scripts:

```json
{
  "name": "edtech-platform",
  "version": "1.0.0",
  "private": true,
  "workspaces": [
    "apps/*",
    "apps/exam-modules/*",
    "packages/*"
  ],
  "scripts": {
    "start": "concurrently \"npm run start:container\" \"npm run start:auth\" \"npm run start:ui\"",
    "start:container": "cd apps/container && npm start",
    "start:auth": "cd apps/auth && npm start",
    "start:dashboard": "cd apps/dashboard && npm start",
    "start:nursing": "cd apps/exam-modules/nursing && npm start",
    "start:ui": "cd packages/ui-components && npm start",
    "build": "npm run build:ui && npm run build:auth && npm run build:dashboard && npm run build:nursing && npm run build:container",
    "build:container": "cd apps/container && npm run build",
    "build:auth": "cd apps/auth && npm run build",
    "build:ui": "cd packages/ui-components && npm run build",
    "test": "npm run test --workspaces",
    "lint": "npm run lint --workspaces"
  },
  "devDependencies": {
    "concurrently": "^7.6.0"
  }
}
```

### 5.2 TypeScript Configuration

Create root `tsconfig.json`:

```json
{
  "compilerOptions": {
    "target": "es5",
    "lib": ["dom", "dom.iterable", "esnext"],
    "allowJs": true,
    "skipLibCheck": true,
    "esModuleInterop": true,
    "allowSyntheticDefaultImports": true,
    "strict": true,
    "forceConsistentCasingInFileNames": true,
    "noFallthroughCasesInSwitch": true,
    "module": "esnext",
    "moduleResolution": "node",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "noEmit": true,
    "jsx": "react-jsx"
  },
  "include": [
    "apps/*/src",
    "packages/*/src"
  ]
}
```

### 5.3 ESLint Configuration

Create `.eslintrc.js`:

```javascript
module.exports = {
  root: true,
  parser: '@typescript-eslint/parser',
  plugins: ['@typescript-eslint', 'react', 'react-hooks'],
  extends: [
    'eslint:recommended',
    '@typescript-eslint/recommended',
    'plugin:react/recommended',
    'plugin:react-hooks/recommended',
  ],
  settings: {
    react: {
      version: 'detect',
    },
  },
  rules: {
    'react/react-in-jsx-scope': 'off',
    '@typescript-eslint/no-unused-vars': ['error', { argsIgnorePattern: '^_' }],
  },
};
```

## Phase 6: Testing Strategy Implementation

### 6.1 Jest Configuration

Create `jest.config.js`:

```javascript
module.exports = {
  projects: [
    {
      displayName: 'container',
      testMatch: ['<rootDir>/apps/container/src/**/*.test.{js,jsx,ts,tsx}'],
      testEnvironment: 'jsdom',
      setupFilesAfterEnv: ['<rootDir>/jest.setup.js'],
    },
    {
      displayName: 'auth',
      testMatch: ['<rootDir>/apps/auth/src/**/*.test.{js,jsx,ts,tsx}'],
      testEnvironment: 'jsdom',
      setupFilesAfterEnv: ['<rootDir>/jest.setup.js'],
    },
    {
      displayName: 'ui-components',
      testMatch: ['<rootDir>/packages/ui-components/src/**/*.test.{js,jsx,ts,tsx}'],
      testEnvironment: 'jsdom',
      setupFilesAfterEnv: ['<rootDir>/jest.setup.js'],
    },
  ],
  collectCoverageFrom: [
    'apps/*/src/**/*.{js,jsx,ts,tsx}',
    'packages/*/src/**/*.{js,jsx,ts,tsx}',
    '!**/*.d.ts',
  ],
};
```

### 6.2 Component Testing

Create test for shared Button component:

```typescript
// packages/ui-components/src/components/Button.test.tsx
import React from 'react';
import { render, fireEvent, screen } from '@testing-library/react';
import { Button } from './Button';

describe('Button Component', () => {
  it('renders with correct text', () => {
    render(<Button>Click me</Button>);
    expect(screen.getByText('Click me')).toBeInTheDocument();
  });

  it('calls onClick when clicked', () => {
    const handleClick = jest.fn();
    render(<Button onClick={handleClick}>Click me</Button>);
    
    fireEvent.click(screen.getByText('Click me'));
    expect(handleClick).toHaveBeenCalledTimes(1);
  });

  it('shows loading state', () => {
    render(<Button loading>Click me</Button>);
    expect(screen.getByText('Loading...')).toBeInTheDocument();
  });

  it('disables button when disabled prop is true', () => {
    render(<Button disabled>Click me</Button>);
    expect(screen.getByRole('button')).toBeDisabled();
  });
});
```

## Phase 7: CI/CD Pipeline Setup

### 7.1 GitHub Actions Workflow

Create `.github/workflows/ci-cd.yml`:

```yaml
name: CI/CD Pipeline

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
        with:
          node-version: '18'
          cache: 'npm'
      
      - name: Install dependencies
        run: npm ci
      
      - name: Run linting
        run: npm run lint
      
      - name: Run tests
        run: npm test
      
      - name: Build all applications
        run: npm run build

  deploy-staging:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/develop'
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
        with:
          node-version: '18'
          cache: 'npm'
      
      - name: Install dependencies
        run: npm ci
      
      - name: Build applications
        run: npm run build
      
      - name: Deploy to staging
        run: |
          # Deploy each micro-frontend independently
          npm run deploy:staging:container
          npm run deploy:staging:auth
          npm run deploy:staging:dashboard
          npm run deploy:staging:nursing

  deploy-production:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
        with:
          node-version: '18'
          cache: 'npm'
      
      - name: Install dependencies
        run: npm ci
      
      - name: Build applications
        run: npm run build
      
      - name: Deploy to production
        run: |
          npm run deploy:production:container
          npm run deploy:production:auth
          npm run deploy:production:dashboard
          npm run deploy:production:nursing
```

### 7.2 Docker Configuration

Create `apps/container/Dockerfile`:

```dockerfile
FROM node:18-alpine as builder

WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

COPY . .
RUN npm run build

FROM nginx:alpine
COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/nginx.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

## Phase 8: Monitoring & Observability

### 8.1 Error Tracking Setup

```typescript
// apps/container/src/utils/monitoring.ts
interface ErrorLog {
  error: Error;
  errorInfo?: any;
  microFrontend: string;
  userId?: string;
  timestamp: Date;
}

export class MonitoringService {
  private static instance: MonitoringService;
  
  static getInstance(): MonitoringService {
    if (!MonitoringService.instance) {
      MonitoringService.instance = new MonitoringService();
    }
    return MonitoringService.instance;
  }

  logError(errorLog: ErrorLog) {
    // Log to console in development
    if (process.env.NODE_ENV === 'development') {
      console.error('Micro-frontend error:', errorLog);
    }

    // Send to monitoring service in production
    if (process.env.NODE_ENV === 'production') {
      this.sendToMonitoringService(errorLog);
    }
  }

  private async sendToMonitoringService(errorLog: ErrorLog) {
    try {
      await fetch('/api/monitoring/errors', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(errorLog),
      });
    } catch (error) {
      console.error('Failed to send error to monitoring service:', error);
    }
  }
}
```

### 8.2 Performance Monitoring

```typescript
// packages/utils/src/performance.ts
export class PerformanceMonitor {
  static measureMicroFrontendLoad(name: string) {
    const startTime = performance.now();
    
    return {
      end: () => {
        const endTime = performance.now();
        const loadTime = endTime - startTime;
        
        // Log performance metrics
        console.log(`${name} loaded in ${loadTime.toFixed(2)}ms`);
        
        // Send to analytics service
        if (typeof gtag !== 'undefined') {
          gtag('event', 'micro_frontend_load', {
            micro_frontend_name: name,
            load_time: loadTime,
          });
        }
      }
    };
  }
}
```

## Next Steps & Advanced Topics

### Phase 9: Advanced Patterns (Future Implementation)
1. **Dynamic Remote Loading**: Load micro-frontends based on user permissions
2. **Shared State Management**: Implement Redux or Zustand across boundaries
3. **Advanced Security**: Implement CSP, CSRF protection, secure communication
4. **Progressive Enhancement**: Offline capabilities and service workers
5. **A/B Testing Framework**: Dynamic feature flags and experimentation

### Phase 10: Scale & Optimization
1. **CDN Integration**: Optimize asset delivery for Philippine mobile users
2. **Bundle Analysis**: Implement webpack-bundle-analyzer for optimization
3. **Performance Budgets**: Set and monitor performance budgets
4. **Automated Testing**: Implement E2E testing with Cypress or Playwright
5. **Documentation**: Create comprehensive API documentation

## Troubleshooting Common Issues

### Module Resolution Issues
```bash
# Clear node_modules and reinstall
rm -rf node_modules package-lock.json
npm install

# Check webpack configuration for correct remote URLs
# Verify that all micro-frontends are running on correct ports
```

### TypeScript Module Federation Types
```typescript
// Create types for module federation
declare module 'auth/AuthApp' {
  const AuthApp: React.ComponentType;
  export default AuthApp;
}

declare module 'uiComponents/Button' {
  export { Button, ButtonProps } from '@edtech/ui-components';
}
```

### CORS Issues in Development
```javascript
// Add to webpack devServer configuration
devServer: {
  headers: {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, PATCH, OPTIONS",
    "Access-Control-Allow-Headers": "X-Requested-With, content-type, Authorization"
  }
}
```

## Conclusion

This implementation guide provides a comprehensive foundation for building micro-frontend architecture using Module Federation. The approach emphasizes:

- **Incremental Implementation**: Start simple and add complexity gradually
- **Developer Experience**: Strong tooling and development workflows
- **Production Readiness**: Testing, monitoring, and deployment strategies
- **Educational Context**: Specific considerations for EdTech platforms

Follow the phases sequentially, adapting configurations and implementations to your specific educational platform requirements.

---

**Navigation**
- ← Back to: [Executive Summary](executive-summary.md)
- → Next: [Module Federation Guide](module-federation-guide.md)
- → Related: [Best Practices](best-practices.md)