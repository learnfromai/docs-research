# Implementation Guide: Complete Nx Setup

Step-by-step instructions for setting up Nx workspace with React Vite, Express.js, and shared libraries.

## 📋 Prerequisites

### System Requirements
- **Node.js** 18+ (LTS recommended)
- **npm** 9+ or **yarn** 1.22+ or **pnpm** 8+
- **Git** for version control
- **VS Code** (recommended IDE)

### Verify Installation
```bash
# Check Node.js version
node --version
# Should output: v18.0.0 or higher

# Check npm version
npm --version
# Should output: 9.0.0 or higher

# Check Git
git --version
```

## 🚀 Phase 1: Workspace Creation

### Step 1: Create New Nx Workspace

```bash
# Create new workspace with integrated setup
npx create-nx-workspace@latest my-workspace

# Follow the interactive prompts:
# ✔ Which stack do you want to use? · react
# ✔ What framework would you like to use? · react
# ✔ Bundler · vite
# ✔ Test runner · jest
# ✔ Default stylesheet format · css
# ✔ Enable distributed caching to make your CI faster · Yes
```

### Step 2: Navigate to Workspace
```bash
cd my-workspace
```

### Step 3: Explore Initial Structure
```bash
# View workspace structure
tree -L 2 -I node_modules

# Expected output:
# my-workspace/
# ├── apps/
# │   ├── my-workspace/       # Main React app
# │   └── my-workspace-e2e/   # E2E tests
# ├── libs/                   # Shared libraries
# ├── tools/                  # Custom scripts
# ├── nx.json                 # Nx configuration
# ├── package.json            # Dependencies
# ├── tsconfig.base.json      # TypeScript config
# └── README.md
```

### Step 4: Install Additional Dependencies
```bash
# Install development tools
npm install -D @nx/express @nx/node @nx/storybook @nx/cypress

# Install runtime dependencies for full-stack development
npm install express cors helmet morgan
npm install -D @types/express @types/cors @types/morgan
```

## 🎯 Phase 2: React Vite Application Setup

### Step 1: Create Additional React App (if needed)
```bash
# Generate new React app with Vite
nx g @nx/react:app frontend-app --bundler=vite --style=css --routing=true

# With additional options
nx g @nx/react:app admin-dashboard \
  --bundler=vite \
  --style=scss \
  --routing=true \
  --unitTestRunner=jest \
  --e2eTestRunner=cypress
```

### Step 2: Configure React App Structure
```bash
# Navigate to your app directory
cd apps/my-workspace/src

# Create recommended folder structure
mkdir -p components/ui
mkdir -p pages
mkdir -p hooks
mkdir -p services
mkdir -p utils
mkdir -p types
```

### Step 3: Update React App Entry Point
```typescript
// apps/my-workspace/src/main.tsx
import { StrictMode } from 'react';
import * as ReactDOM from 'react-dom/client';
import { BrowserRouter } from 'react-router-dom';

import App from './app/app';

const root = ReactDOM.createRoot(
  document.getElementById('root') as HTMLElement
);

root.render(
  <StrictMode>
    <BrowserRouter>
      <App />
    </BrowserRouter>
  </StrictMode>
);
```

### Step 4: Test React Application
```bash
# Start development server
nx serve my-workspace

# Open browser to http://localhost:4200
# Verify hot reloading works by editing components
```

## 🖥️ Phase 3: Express.js Backend Setup

### Step 1: Generate Express.js Application
```bash
# Create Express.js API server
nx g @nx/express:app api-server --frontendProject=my-workspace

# This creates:
# - apps/api-server/ directory
# - Express.js app with TypeScript
# - Proxy configuration in frontend
```

### Step 2: Configure Express.js Application
```typescript
// apps/api-server/src/main.ts
import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';

const app = express();

// Middleware
app.use(helmet());
app.use(cors());
app.use(morgan('combined'));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Routes
app.get('/api', (req, res) => {
  res.json({ message: 'Welcome to API Server!' });
});

app.get('/api/health', (req, res) => {
  res.json({ status: 'OK', timestamp: new Date().toISOString() });
});

// Error handling
app.use((err: Error, req: express.Request, res: express.Response, next: express.NextFunction) => {
  console.error(err.stack);
  res.status(500).json({ error: 'Something went wrong!' });
});

const port = process.env['PORT'] || 3000;
const server = app.listen(port, () => {
  console.log(`🚀 Server ready at http://localhost:${port}`);
});

server.on('error', console.error);
```

### Step 3: Add API Routes Structure
```bash
# Create routes directory
mkdir -p apps/api-server/src/routes

# Create route files
touch apps/api-server/src/routes/users.ts
touch apps/api-server/src/routes/products.ts
touch apps/api-server/src/routes/index.ts
```

```typescript
// apps/api-server/src/routes/users.ts
import { Router } from 'express';

const router = Router();

router.get('/', (req, res) => {
  res.json([
    { id: 1, name: 'John Doe', email: 'john@example.com' },
    { id: 2, name: 'Jane Smith', email: 'jane@example.com' }
  ]);
});

router.get('/:id', (req, res) => {
  const id = parseInt(req.params.id);
  res.json({ id, name: 'John Doe', email: 'john@example.com' });
});

export default router;
```

### Step 4: Test Express.js Application
```bash
# Start API server
nx serve api-server

# Test endpoints
curl http://localhost:3000/api
curl http://localhost:3000/api/health

# Start both frontend and backend
nx run-many --target=serve --projects=my-workspace,api-server
```

## 📚 Phase 4: Shared Libraries Setup

### Step 1: Create Shared Interface Library
```bash
# Generate shared interfaces library
nx g @nx/js:lib api-interfaces --bundler=tsc

# Create interface files
mkdir -p libs/api-interfaces/src/lib
```

```typescript
// libs/api-interfaces/src/lib/user.interface.ts
export interface User {
  id: number;
  name: string;
  email: string;
  createdAt?: Date;
  updatedAt?: Date;
}

export interface CreateUserRequest {
  name: string;
  email: string;
}

export interface UpdateUserRequest extends Partial<CreateUserRequest> {
  id: number;
}
```

```typescript
// libs/api-interfaces/src/index.ts
export * from './lib/user.interface';
export * from './lib/product.interface';
export * from './lib/api-response.interface';
```

### Step 2: Create Shared UI Component Library
```bash
# Generate React component library
nx g @nx/react:lib shared-ui --bundler=vite --component=false

# Generate components
nx g @nx/react:component button --project=shared-ui --export=true
nx g @nx/react:component card --project=shared-ui --export=true
nx g @nx/react:component modal --project=shared-ui --export=true
```

```tsx
// libs/shared-ui/src/lib/button/button.tsx
import React from 'react';
import './button.css';

export interface ButtonProps {
  variant?: 'primary' | 'secondary' | 'danger';
  size?: 'sm' | 'md' | 'lg';
  disabled?: boolean;
  children: React.ReactNode;
  onClick?: () => void;
}

export function Button({
  variant = 'primary',
  size = 'md',
  disabled = false,
  children,
  onClick
}: ButtonProps) {
  return (
    <button
      className={`btn btn--${variant} btn--${size}`}
      disabled={disabled}
      onClick={onClick}
    >
      {children}
    </button>
  );
}

export default Button;
```

### Step 3: Create Shared Utilities Library
```bash
# Generate utilities library
nx g @nx/js:lib shared-utils --bundler=tsc

# Create utility functions
mkdir -p libs/shared-utils/src/lib
```

```typescript
// libs/shared-utils/src/lib/api-client.ts
export class ApiClient {
  private baseUrl: string;

  constructor(baseUrl: string = '/api') {
    this.baseUrl = baseUrl;
  }

  async get<T>(endpoint: string): Promise<T> {
    const response = await fetch(`${this.baseUrl}${endpoint}`);
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }
    return response.json();
  }

  async post<T>(endpoint: string, data: unknown): Promise<T> {
    const response = await fetch(`${this.baseUrl}${endpoint}`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(data),
    });
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }
    return response.json();
  }
}

export const apiClient = new ApiClient();
```

### Step 4: Configure Library Dependencies
```typescript
// Update tsconfig.base.json to include library paths
{
  "compilerOptions": {
    "paths": {
      "@my-workspace/api-interfaces": ["libs/api-interfaces/src/index.ts"],
      "@my-workspace/shared-ui": ["libs/shared-ui/src/index.ts"],
      "@my-workspace/shared-utils": ["libs/shared-utils/src/index.ts"]
    }
  }
}
```

## 🔧 Phase 5: Configuration and Integration

### Step 1: Update Nx Configuration
```json
// nx.json - Add target defaults and plugin configuration
{
  "$schema": "./node_modules/nx/schemas/nx-schema.json",
  "targetDefaults": {
    "build": {
      "cache": true,
      "dependsOn": ["^build"],
      "inputs": ["production", "^production"]
    },
    "test": {
      "cache": true,
      "inputs": ["default", "^production", "{workspaceRoot}/jest.preset.js"]
    }
  },
  "namedInputs": {
    "default": ["{projectRoot}/**/*", "sharedGlobals"],
    "production": [
      "default",
      "!{projectRoot}/**/?(*.)+(spec|test).[jt]s?(x)?(.snap)",
      "!{projectRoot}/tsconfig.spec.json",
      "!{projectRoot}/jest.config.[jt]s"
    ],
    "sharedGlobals": ["{workspaceRoot}/babel.config.json"]
  }
}
```

### Step 2: Set up ESLint Configuration
```json
// .eslintrc.json
{
  "root": true,
  "ignorePatterns": ["**/*"],
  "plugins": ["@nx"],
  "overrides": [
    {
      "files": ["*.ts", "*.tsx", "*.js", "*.jsx"],
      "rules": {
        "@nx/enforce-module-boundaries": [
          "error",
          {
            "enforceBuildableLibDependency": true,
            "allow": [],
            "depConstraints": [
              {
                "sourceTag": "*",
                "onlyDependOnLibsWithTags": ["*"]
              }
            ]
          }
        ]
      }
    }
  ]
}
```

### Step 3: Configure Development Environment
```bash
# Install VS Code extensions
# - Nx Console (essential)
# - TypeScript Hero
# - ESLint
# - Prettier
# - Auto Rename Tag

# Create .vscode/settings.json
mkdir -p .vscode
```

```json
// .vscode/settings.json
{
  "typescript.preferences.importModuleSpecifier": "relative",
  "editor.formatOnSave": true,
  "editor.codeActionsOnSave": {
    "source.fixAll.eslint": true
  },
  "files.associations": {
    "*.css": "tailwindcss"
  }
}
```

## ✅ Phase 6: Testing and Validation

### Step 1: Run All Tests
```bash
# Run unit tests for all projects
nx test

# Run e2e tests
nx e2e my-workspace-e2e

# Run tests for specific project
nx test shared-ui
nx test api-server
```

### Step 2: Build All Projects
```bash
# Build all projects
nx build

# Build specific projects
nx build my-workspace
nx build api-server
nx build shared-ui
```

### Step 3: Verify Library Integration
```tsx
// Test shared libraries in React app
// apps/my-workspace/src/app/app.tsx
import { Button } from '@my-workspace/shared-ui';
import { apiClient } from '@my-workspace/shared-utils';
import { User } from '@my-workspace/api-interfaces';
import { useEffect, useState } from 'react';

export function App() {
  const [users, setUsers] = useState<User[]>([]);

  useEffect(() => {
    apiClient.get<User[]>('/users')
      .then(setUsers)
      .catch(console.error);
  }, []);

  return (
    <div>
      <h1>My Nx Workspace</h1>
      <Button onClick={() => console.log('Button clicked!')}>
        Click me
      </Button>
      <ul>
        {users.map(user => (
          <li key={user.id}>{user.name} - {user.email}</li>
        ))}
      </ul>
    </div>
  );
}

export default App;
```

### Step 4: View Dependency Graph
```bash
# Generate and view project dependency graph
nx graph

# This opens a browser window showing:
# - Project relationships
# - Library dependencies
# - Circular dependency warnings
```

## 🚀 Production Readiness

### Step 1: Build for Production
```bash
# Build all projects for production
nx build --prod

# Build specific projects
nx build my-workspace --prod
nx build api-server --prod
```

### Step 2: Create Docker Configuration
```dockerfile
# Dockerfile.frontend
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

COPY . .
RUN npx nx build my-workspace --prod

FROM nginx:alpine
COPY --from=builder /app/dist/apps/my-workspace /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

```dockerfile
# Dockerfile.backend
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

COPY . .
RUN npx nx build api-server --prod

EXPOSE 3000
CMD ["node", "dist/apps/api-server/main.js"]
```

## ✅ Verification Checklist

- [ ] Nx workspace created successfully
- [ ] React app runs on `nx serve my-workspace`
- [ ] Express.js API runs on `nx serve api-server`
- [ ] Shared libraries compile without errors
- [ ] TypeScript interfaces shared between frontend and backend
- [ ] UI components render correctly
- [ ] API endpoints return expected data
- [ ] Tests pass for all projects
- [ ] Production builds complete successfully
- [ ] Dependency graph shows proper relationships

## 🔗 Next Steps

After completing this implementation guide:

1. **Review Best Practices** - Learn optimization patterns and conventions
2. **Explore CLI Commands** - Master essential Nx commands for daily development
3. **Study Template Examples** - Examine working code patterns
4. **Set up CI/CD** - Configure automated testing and deployment
5. **Add Nx Cloud** - Enable remote caching for team collaboration

---

**Previous**: [← Executive Summary](./executive-summary.md) | **Next**: [Best Practices →](./best-practices.md)