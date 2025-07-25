# Troubleshooting Guide

Common issues and solutions for Nx development with React Vite, Express.js, and shared libraries.

## 📋 Table of Contents

- [Installation Issues](#installation-issues)
- [Build Problems](#build-problems)
- [Development Server Issues](#development-server-issues)
- [Library and Import Issues](#library-and-import-issues)
- [Testing Problems](#testing-problems)
- [Performance Issues](#performance-issues)
- [TypeScript Errors](#typescript-errors)
- [CI/CD Issues](#cicd-issues)
- [Advanced Troubleshooting](#advanced-troubleshooting)

## 🚧 Installation Issues

### Node Version Compatibility

**Problem**: Nx installation fails with Node.js version errors
```bash
Error: Nx requires Node.js version 18 or higher
```

**Solution**:
```bash
# Check current Node.js version
node --version

# Install Node.js 18+ using nvm
nvm install 18
nvm use 18

# Or update using your package manager
# For macOS with Homebrew:
brew upgrade node

# For Ubuntu/Debian:
sudo apt update && sudo apt upgrade nodejs npm
```

### NPM/Yarn Package Manager Issues

**Problem**: Package installation fails or conflicts occur
```bash
npm ERR! peer dep missing: @nx/devkit@>=16.0.0
```

**Solutions**:
```bash
# Clear package manager cache
npm cache clean --force
yarn cache clean
pnpm store prune

# Delete node_modules and reinstall
rm -rf node_modules package-lock.json
npm install

# Use specific package manager consistently
npx create-nx-workspace@latest my-workspace --packageManager=npm
npx create-nx-workspace@latest my-workspace --packageManager=yarn
npx create-nx-workspace@latest my-workspace --packageManager=pnpm
```

### Permission Issues

**Problem**: EACCES permission denied errors on macOS/Linux
```bash
npm ERR! Error: EACCES: permission denied
```

**Solutions**:
```bash
# Option 1: Use npx instead of global installation
npx create-nx-workspace@latest my-workspace

# Option 2: Fix npm permissions
mkdir ~/.npm-global
npm config set prefix '~/.npm-global'
echo 'export PATH=~/.npm-global/bin:$PATH' >> ~/.bashrc
source ~/.bashrc

# Option 3: Use Node version manager
# Install nvm and use it to manage Node.js versions
```

## 🔨 Build Problems

### Vite Build Failures

**Problem**: React Vite app fails to build
```bash
ERROR: Could not resolve "@ecommerce/shared-ui"
```

**Solution**: Check TypeScript path mapping
```json
// tsconfig.base.json
{
  "compilerOptions": {
    "paths": {
      "@ecommerce/shared-ui": ["libs/shared-ui/src/index.ts"],
      "@ecommerce/api-interfaces": ["libs/api-interfaces/src/index.ts"]
    }
  }
}

// Verify library exports
// libs/shared-ui/src/index.ts
export * from './lib/button/button';
export * from './lib/modal/modal';
```

### Express.js Build Issues

**Problem**: Express.js app build fails with missing dependencies
```bash
Module not found: Can't resolve 'express'
```

**Solutions**:
```bash
# Install missing dependencies
npm install express cors helmet morgan
npm install -D @types/express @types/cors @types/morgan

# Verify project.json build configuration
# apps/api-server/project.json
{
  "targets": {
    "build": {
      "executor": "@nx/webpack:webpack",
      "options": {
        "target": "node",
        "compiler": "tsc"
      }
    }
  }
}
```

### Library Build Dependencies

**Problem**: Library fails to build due to circular dependencies
```bash
ERROR: Circular dependency detected
```

**Solutions**:
```bash
# View dependency graph to identify cycles
nx graph

# Fix circular dependencies by:
# 1. Moving shared types to separate interface library
# 2. Using dependency injection patterns
# 3. Restructuring import hierarchy

# Example fix:
# Before (circular):
# lib-a imports lib-b
# lib-b imports lib-a

# After (acyclic):
# lib-a imports shared-interfaces
# lib-b imports shared-interfaces
```

### Build Cache Issues

**Problem**: Stale build cache causing inconsistent builds
```bash
# Build outputs don't reflect code changes
```

**Solutions**:
```bash
# Clear Nx cache
nx reset

# Clear specific project cache
nx reset --project=my-app

# Build with fresh cache
nx build my-app --skip-nx-cache

# Verify cache configuration
# nx.json
{
  "namedInputs": {
    "production": [
      "default",
      "!{projectRoot}/**/?(*.)+(spec|test).[jt]s?(x)?(.snap)"
    ]
  }
}
```

## 🚀 Development Server Issues

### Port Conflicts

**Problem**: Port already in use error
```bash
Error: listen EADDRINUSE: address already in use :::4200
```

**Solutions**:
```bash
# Use different port
nx serve my-app --port=4201

# Kill process using the port (macOS/Linux)
lsof -ti:4200 | xargs kill -9

# Kill process using the port (Windows)
netstat -ano | findstr :4200
taskkill /PID <PID> /F

# Configure default port in project.json
{
  "targets": {
    "serve": {
      "options": {
        "port": 4201
      }
    }
  }
}
```

### Hot Reload Not Working

**Problem**: Changes not reflecting in development server

**Solutions**:
```bash
# Verify file watching is enabled
nx serve my-app --watch

# Check if files are in .gitignore preventing watch
# Remove from .gitignore if necessary

# For Docker development, enable polling
# vite.config.ts
export default defineConfig({
  server: {
    watch: {
      usePolling: true,
      interval: 1000
    }
  }
});
```

### Proxy Configuration Issues

**Problem**: API calls fail with CORS errors in development

**Solutions**:
```typescript
// vite.config.ts - Configure proxy correctly
export default defineConfig({
  server: {
    proxy: {
      '/api': {
        target: 'http://localhost:3000',
        changeOrigin: true,
        secure: false,
        configure: (proxy, _options) => {
          proxy.on('error', (err) => {
            console.log('proxy error', err);
          });
        }
      }
    }
  }
});

// Express.js CORS configuration
app.use(cors({
  origin: ['http://localhost:4200', 'http://localhost:4201'],
  credentials: true
}));
```

## 📚 Library and Import Issues

### Module Resolution Problems

**Problem**: TypeScript cannot find library modules
```bash
Cannot find module '@my-workspace/shared-ui'
```

**Solutions**:
```json
// tsconfig.base.json - Verify path mapping
{
  "compilerOptions": {
    "baseUrl": ".",
    "paths": {
      "@my-workspace/shared-ui": ["libs/shared-ui/src/index.ts"]
    }
  }
}

// Verify library index file exists and exports correctly
// libs/shared-ui/src/index.ts
export * from './lib/button/button';
export * from './lib/modal/modal';

// Check project.json has correct name
// libs/shared-ui/project.json
{
  "name": "shared-ui"
}
```

### Import Boundary Violations

**Problem**: ESLint errors about import boundaries
```bash
Projects cannot depend on libraries with the given tags
```

**Solutions**:
```json
// .eslintrc.json - Update dependency constraints
{
  "rules": {
    "@nx/enforce-module-boundaries": [
      "error",
      {
        "depConstraints": [
          {
            "sourceTag": "scope:web-app",
            "onlyDependOnLibsWithTags": [
              "scope:shared",
              "type:ui",
              "type:util"
            ]
          }
        ]
      }
    ]
  }
}

// Update project tags
// libs/shared-ui/project.json
{
  "tags": ["scope:shared", "type:ui"]
}
```

### Library Build Issues

**Problem**: Publishable library fails to build
```bash
Cannot find module when importing built library
```

**Solutions**:
```json
// libs/my-lib/project.json - Configure build options
{
  "targets": {
    "build": {
      "executor": "@nx/rollup:rollup",
      "options": {
        "outputPath": "dist/libs/my-lib",
        "tsConfig": "libs/my-lib/tsconfig.lib.json",
        "project": "libs/my-lib/package.json",
        "entryFile": "libs/my-lib/src/index.ts",
        "external": ["react", "react-dom"],
        "rollupConfig": "@nx/react/plugins/bundle-rollup"
      }
    }
  }
}

// libs/my-lib/package.json
{
  "name": "@my-workspace/my-lib",
  "version": "1.0.0",
  "main": "./src/index.js",
  "types": "./src/index.d.ts",
  "peerDependencies": {
    "react": ">=18.0.0"
  }
}
```

## 🧪 Testing Problems

### Jest Configuration Issues

**Problem**: Jest tests fail to run or find modules
```bash
Cannot find module '@my-workspace/shared-ui' from test file
```

**Solutions**:
```javascript
// jest.preset.js - Update module name mapping
const { workspaceRoot } = require('@nx/devkit');

module.exports = {
  displayName: 'my-app',
  preset: `${workspaceRoot}/jest.preset.js`,
  setupFilesAfterEnv: ['<rootDir>/src/test-setup.ts'],
  moduleNameMapper: {
    '^@my-workspace/(.*)$': '<rootDir>/../../libs/$1/src'
  },
  transform: {
    '^.+\\.[tj]sx?$': ['babel-jest', { presets: ['@nx/react/babel'] }]
  }
};
```

### React Testing Library Issues

**Problem**: Component tests fail with rendering errors
```bash
TypeError: Cannot read property 'ReactCurrentDispatcher' of null
```

**Solutions**:
```typescript
// src/test-setup.ts - Configure testing environment
import '@testing-library/jest-dom';
import { configure } from '@testing-library/react';

configure({ testIdAttribute: 'data-cy' });

// Mock IntersectionObserver
global.IntersectionObserver = class IntersectionObserver {
  constructor() {}
  disconnect() {}
  observe() {}
  unobserve() {}
};

// Mock ResizeObserver
global.ResizeObserver = class ResizeObserver {
  constructor() {}
  disconnect() {}
  observe() {}
  unobserve() {}
};
```

### E2E Testing Issues

**Problem**: Cypress tests fail to run or find application
```bash
Timed out retrying: Expected to find element
```

**Solutions**:
```typescript
// apps/my-app-e2e/cypress.config.ts
import { defineConfig } from 'cypress';
import { nxE2EPreset } from '@nx/cypress/plugins/cypress-preset';

export default defineConfig({
  e2e: {
    ...nxE2EPreset(__filename, { cypressDir: 'src' }),
    baseUrl: 'http://localhost:4200',
    defaultCommandTimeout: 10000,
    viewportWidth: 1280,
    viewportHeight: 720,
    video: false,
    screenshotOnRunFailure: true
  }
});

// Use proper data-cy attributes for reliable selection
// Component
<button data-cy="submit-button">Submit</button>

// Test
cy.get('[data-cy=submit-button]').click();
```

## ⚡ Performance Issues

### Slow Build Times

**Problem**: Builds take too long to complete

**Solutions**:
```bash
# Enable Nx Cloud for remote caching
nx connect-to-nx-cloud

# Use parallel builds
nx run-many --target=build --all --parallel=3

# Optimize TypeScript configuration
# tsconfig.json
{
  "compilerOptions": {
    "incremental": true,
    "tsBuildInfoFile": ".tsbuildinfo"
  }
}

# Use affected commands in CI
nx affected --target=build --base=origin/main
```

### Memory Issues

**Problem**: Build process runs out of memory
```bash
FATAL ERROR: Ineffective mark-compacts near heap limit
```

**Solutions**:
```bash
# Increase Node.js heap size
NODE_OPTIONS="--max-old-space-size=8192" nx build my-app

# Reduce parallel execution
nx build my-app --maxParallel=1

# Use swap memory (Linux)
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

### Large Bundle Sizes

**Problem**: Production bundles are too large

**Solutions**:
```typescript
// vite.config.ts - Optimize bundle splitting
export default defineConfig({
  build: {
    rollupOptions: {
      output: {
        manualChunks: {
          vendor: ['react', 'react-dom'],
          router: ['react-router-dom'],
          ui: ['@my-workspace/shared-ui']
        }
      }
    }
  }
});

# Analyze bundle size
nx build my-app --analyze
npx webpack-bundle-analyzer dist/apps/my-app

# Use dynamic imports for code splitting
const LazyComponent = lazy(() => import('./lazy-component'));
```

## 🔧 TypeScript Errors

### Configuration Conflicts

**Problem**: TypeScript compilation errors across projects
```bash
Cannot redeclare block-scoped variable
```

**Solutions**:
```json
// tsconfig.base.json - Configure consistent settings
{
  "compilerOptions": {
    "strict": true,
    "noImplicitAny": true,
    "exactOptionalPropertyTypes": true,
    "noImplicitReturns": true,
    "noFallthroughCasesInSwitch": true
  },
  "exclude": ["node_modules", "tmp"]
}

// Individual project tsconfig.json should extend base
{
  "extends": "../../tsconfig.base.json",
  "compilerOptions": {
    "jsx": "react-jsx",
    "allowJs": true,
    "esModuleInterop": true
  }
}
```

### Type Import Issues

**Problem**: Type imports fail between libraries
```bash
Module '"@my-workspace/api-interfaces"' has no exported member 'User'
```

**Solutions**:
```typescript
// libs/api-interfaces/src/index.ts - Ensure proper exports
export * from './lib/user.interface';
export * from './lib/product.interface';
export type { User } from './lib/user.interface';

// Use type-only imports when appropriate
import type { User } from '@my-workspace/api-interfaces';
import { UserRole } from '@my-workspace/api-interfaces';
```

## 🔄 CI/CD Issues

### GitHub Actions Configuration

**Problem**: CI pipeline fails with Nx commands
```yaml
# .github/workflows/ci.yml - Working configuration
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  main:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: 18
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Set up Nx SHAs
        uses: nrwl/nx-set-shas@v4

      - name: Format check
        run: npx nx format:check

      - name: Lint
        run: npx nx affected --target=lint --parallel=3

      - name: Test
        run: npx nx affected --target=test --parallel=3 --ci --code-coverage

      - name: Build
        run: npx nx affected --target=build --parallel=3

      - name: E2E
        run: npx nx affected --target=e2e --parallel=1
```

### Docker Build Issues

**Problem**: Docker builds fail with Nx projects
```dockerfile
# Dockerfile - Multi-stage build for Nx
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force

COPY . .
RUN npx nx build my-app --prod

FROM nginx:alpine
COPY --from=builder /app/dist/apps/my-app /usr/share/nginx/html
COPY nginx.conf /etc/nginx/nginx.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

### Nx Cloud Issues

**Problem**: Remote caching not working properly
```bash
# Verify Nx Cloud connection
nx report

# Reset and reconnect to Nx Cloud
nx reset
nx connect-to-nx-cloud

# Check access token configuration
# nx.json
{
  "nxCloudAccessToken": "your-token-here"
}
```

## 🔧 Advanced Troubleshooting

### Debug Mode

**Problem**: Need detailed debugging information
```bash
# Enable verbose logging
NX_VERBOSE=true nx build my-app

# Enable debug mode
DEBUG=nx:* nx build my-app

# Profile performance
NX_PROFILE=profile.json nx build my-app
```

### Workspace Corruption

**Problem**: Workspace appears corrupted or inconsistent
```bash
# Reset workspace state
nx reset

# Reinstall dependencies
rm -rf node_modules package-lock.json
npm install

# Verify workspace integrity
nx workspace-lint

# Regenerate lock file
rm package-lock.json
npm install
```

### Plugin Issues

**Problem**: Nx plugins not working correctly
```bash
# List installed plugins
nx list

# Check plugin versions compatibility
npm list @nx/react @nx/express

# Update plugins to compatible versions
nx migrate @nx/react@latest
nx migrate --run-migrations
```

## 🆘 Emergency Recovery

### Complete Reset Procedure

When all else fails, follow this complete reset procedure:

```bash
# 1. Backup important files
cp -r apps/my-app/src /tmp/backup-src
cp -r libs /tmp/backup-libs

# 2. Clean everything
rm -rf node_modules package-lock.json
nx reset
git clean -fdx

# 3. Reinstall from scratch
npm install

# 4. Verify basic functionality
nx build my-app
nx test my-app
nx serve my-app

# 5. Restore custom code if needed
# Compare and merge from backup
```

### Getting Help

When troubleshooting fails:

1. **Check Nx Documentation**: https://nx.dev/troubleshooting
2. **Search GitHub Issues**: https://github.com/nrwl/nx/issues
3. **Community Discord**: https://go.nx.dev/community
4. **Stack Overflow**: Tag questions with `nrwl-nx`
5. **Create Minimal Reproduction**: Use `npx create-nx-workspace@latest` to isolate issues

### Common Log Files and Debugging

```bash
# Check Nx cache directory
ls ~/.nx/cache

# View build logs
cat dist/apps/my-app/.nx-helpers.log

# Check dependency graph
nx graph --file=graph.json

# Validate project configuration
nx show project my-app --web
```

Remember: Most issues are configuration-related. Start with the basics (Node.js version, package installation, TypeScript configuration) before moving to advanced troubleshooting.

---

**Previous**: [← Template Examples](./template-examples.md) | **Next**: N/A (End of guide)