# Turborepo Implementation Guide

## Overview

Turborepo is a high-performance build system for JavaScript and TypeScript codebases. This guide provides a comprehensive implementation strategy for setting up the Expense Tracker monorepo using Turborepo as an alternative to Nx.

## Initial Setup

### 1. Project Initialization

```bash
# Create new monorepo with Turborepo
npx create-turbo@latest expense-tracker-monorepo

# Or add Turborepo to existing project
npm install -g turbo
cd expense-tracker-monorepo
turbo init
```

### 2. Directory Structure

```text
expense-tracker-monorepo/
├── turbo.json                 # Turborepo configuration
├── package.json              # Root package.json
├── tsconfig.json             # Root TypeScript config
├── apps/
│   ├── web-pwa/              # React PWA application
│   ├── mobile/               # React Native app
│   ├── api-gateway/          # Express.js API gateway
│   ├── user-service/         # User microservice
│   ├── expense-service/      # Expense microservice
│   └── admin-dashboard/      # Admin interface
├── packages/
│   ├── ui/                   # Shared UI components
│   ├── config/               # Shared configurations
│   ├── tsconfig/             # TypeScript configurations
│   ├── eslint-config/        # ESLint configurations
│   ├── expense-core/         # Business logic
│   ├── api-client/           # HTTP client utilities
│   └── utils/                # Utility functions
└── tools/
    ├── scripts/              # Build and deployment scripts
    └── generators/           # Code generators
```

## Core Configuration

### 1. Root Package.json

```json
{
  "name": "expense-tracker-monorepo",
  "private": true,
  "scripts": {
    "build": "turbo run build",
    "dev": "turbo run dev --parallel",
    "lint": "turbo run lint",
    "test": "turbo run test",
    "clean": "turbo run clean",
    "type-check": "turbo run type-check",
    "format": "prettier --write .",
    "changeset": "changeset",
    "version-packages": "changeset version",
    "release": "turbo run build --filter=./packages/* && changeset publish"
  },
  "devDependencies": {
    "@changesets/cli": "^2.27.1",
    "prettier": "^3.1.1",
    "turbo": "^1.11.2",
    "typescript": "^5.3.3"
  },
  "workspaces": [
    "apps/*",
    "packages/*"
  ],
  "packageManager": "npm@10.2.4"
}
```

### 2. Turborepo Configuration

```json
// turbo.json
{
  "$schema": "https://turbo.build/schema.json",
  "globalDependencies": ["**/.env.*local"],
  "pipeline": {
    "build": {
      "dependsOn": ["^build"],
      "outputs": ["dist/**", ".next/**", "!.next/cache/**"],
      "env": ["NODE_ENV", "NEXT_PUBLIC_*", "REACT_APP_*"]
    },
    "dev": {
      "cache": false,
      "persistent": true,
      "env": ["NODE_ENV", "PORT", "DATABASE_URL", "REDIS_URL"]
    },
    "lint": {
      "dependsOn": ["^build"],
      "outputs": []
    },
    "test": {
      "dependsOn": ["^build"],
      "outputs": ["coverage/**"],
      "inputs": ["src/**/*.tsx", "src/**/*.ts", "test/**/*.ts", "test/**/*.tsx"]
    },
    "type-check": {
      "dependsOn": ["^build"],
      "outputs": []
    },
    "clean": {
      "cache": false,
      "outputs": []
    },
    "docker-build": {
      "dependsOn": ["build"],
      "inputs": ["Dockerfile", "package.json", "dist/**"],
      "outputs": []
    },
    "deploy": {
      "dependsOn": ["build", "test", "lint"],
      "outputs": []
    }
  },
  "remoteCache": {
    "enabled": true
  }
}
```

## Application Setup

### 1. Web PWA Configuration

```json
// apps/web-pwa/package.json
{
  "name": "web-pwa",
  "private": true,
  "version": "0.0.0",
  "scripts": {
    "dev": "vite",
    "build": "tsc && vite build",
    "lint": "eslint . --ext ts,tsx --report-unused-disable-directives --max-warnings 0",
    "preview": "vite preview",
    "type-check": "tsc --noEmit",
    "clean": "rm -rf dist"
  },
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-router-dom": "^6.20.1",
    "@expense-tracker/ui": "workspace:*",
    "@expense-tracker/expense-core": "workspace:*",
    "@expense-tracker/api-client": "workspace:*",
    "@expense-tracker/utils": "workspace:*"
  },
  "devDependencies": {
    "@types/react": "^18.2.37",
    "@types/react-dom": "^18.2.15",
    "@vitejs/plugin-react": "^4.1.1",
    "eslint": "^8.53.0",
    "eslint-config-custom": "workspace:*",
    "typescript": "^5.2.2",
    "vite": "^5.0.0"
  }
}
```

### 2. Microservice Configuration

```json
// apps/expense-service/package.json
{
  "name": "expense-service",
  "private": true,
  "version": "0.0.0",
  "scripts": {
    "dev": "nodemon src/index.ts",
    "build": "tsc && tsc-alias",
    "start": "node dist/index.js",
    "lint": "eslint src --ext .ts",
    "test": "jest",
    "type-check": "tsc --noEmit",
    "clean": "rm -rf dist",
    "docker-build": "docker build -t expense-service ."
  },
  "dependencies": {
    "express": "^4.18.2",
    "cors": "^2.8.5",
    "helmet": "^7.1.0",
    "@expense-tracker/expense-core": "workspace:*",
    "@expense-tracker/utils": "workspace:*",
    "@expense-tracker/config": "workspace:*"
  },
  "devDependencies": {
    "@types/express": "^4.17.21",
    "@types/cors": "^2.8.17",
    "nodemon": "^3.0.1",
    "ts-node": "^10.9.1",
    "tsc-alias": "^1.8.8",
    "typescript": "^5.2.2",
    "eslint-config-custom": "workspace:*",
    "jest": "^29.7.0",
    "@types/jest": "^29.5.8"
  }
}
```

## Shared Packages Setup

### 1. UI Components Package

```json
// packages/ui/package.json
{
  "name": "@expense-tracker/ui",
  "version": "0.0.0",
  "main": "./dist/index.js",
  "module": "./dist/index.mjs",
  "types": "./dist/index.d.ts",
  "exports": {
    ".": {
      "types": "./dist/index.d.ts",
      "import": "./dist/index.mjs",
      "module": "./dist/index.mjs",
      "require": "./dist/index.js"
    }
  },
  "scripts": {
    "build": "tsup src/index.tsx --format esm,cjs --dts --external react",
    "dev": "tsup src/index.tsx --format esm,cjs --dts --external react --watch",
    "lint": "eslint src/",
    "clean": "rm -rf dist",
    "type-check": "tsc --noEmit"
  },
  "devDependencies": {
    "@types/react": "^18.2.37",
    "@types/react-dom": "^18.2.15",
    "eslint": "^8.53.0",
    "eslint-config-custom": "workspace:*",
    "react": "^18.2.0",
    "tsconfig": "workspace:*",
    "tsup": "^8.0.1",
    "typescript": "^5.2.2"
  },
  "peerDependencies": {
    "react": "^18.2.0"
  }
}
```

### 2. Business Logic Package

```json
// packages/expense-core/package.json
{
  "name": "@expense-tracker/expense-core",
  "version": "0.0.0",
  "main": "./dist/index.js",
  "module": "./dist/index.mjs",
  "types": "./dist/index.d.ts",
  "exports": {
    ".": {
      "types": "./dist/index.d.ts",
      "import": "./dist/index.mjs",
      "module": "./dist/index.mjs",
      "require": "./dist/index.js"
    }
  },
  "scripts": {
    "build": "tsup src/index.ts --format esm,cjs --dts",
    "dev": "tsup src/index.ts --format esm,cjs --dts --watch",
    "lint": "eslint src/",
    "test": "jest",
    "clean": "rm -rf dist",
    "type-check": "tsc --noEmit"
  },
  "dependencies": {
    "zod": "^3.22.4"
  },
  "devDependencies": {
    "eslint": "^8.53.0",
    "eslint-config-custom": "workspace:*",
    "jest": "^29.7.0",
    "tsconfig": "workspace:*",
    "tsup": "^8.0.1",
    "typescript": "^5.2.2"
  }
}
```

## Development Workflow

### 1. Local Development Commands

```bash
# Install dependencies
npm install

# Start all applications in development mode
turbo dev

# Start specific applications
turbo dev --filter=web-pwa
turbo dev --filter=expense-service

# Build all packages and applications
turbo build

# Build only shared packages
turbo build --filter=./packages/*

# Run tests across all projects
turbo test

# Run linting
turbo lint

# Type checking
turbo type-check

# Clean all build artifacts
turbo clean
```

### 2. Filtering and Scoping

```bash
# Run commands for specific workspace
turbo build --filter=web-pwa

# Run commands for workspace and its dependencies
turbo build --filter=web-pwa...

# Run commands for workspace and its dependents
turbo build --filter=...web-pwa

# Run commands for changed packages (since last commit)
turbo build --filter=[HEAD^1]

# Run commands for specific directory pattern
turbo test --filter=./packages/*

# Exclude specific packages
turbo build --filter=!web-pwa
```

### 3. Environment Configuration

```bash
# .env.example
NODE_ENV=development
DATABASE_URL=postgresql://localhost:5432/expense_tracker
REDIS_URL=redis://localhost:6379
JWT_SECRET=your-jwt-secret
NEXT_PUBLIC_API_URL=http://localhost:3000/api
REACT_APP_API_URL=http://localhost:3000/api
```

## Pipeline Optimization

### 1. Task Dependencies

```json
// turbo.json - Advanced pipeline configuration
{
  "pipeline": {
    "build": {
      "dependsOn": ["^build"],
      "outputs": ["dist/**", ".next/**", "!.next/cache/**"],
      "inputs": [
        "src/**/*.tsx",
        "src/**/*.ts",
        "public/**",
        "package.json",
        "tsconfig.json",
        "next.config.js",
        "vite.config.ts"
      ]
    },
    "test": {
      "dependsOn": ["^build"],
      "outputs": ["coverage/**"],
      "inputs": [
        "src/**/*.tsx",
        "src/**/*.ts",
        "test/**/*.ts",
        "jest.config.js",
        "package.json"
      ]
    },
    "lint": {
      "outputs": [],
      "inputs": [
        "src/**/*.tsx",
        "src/**/*.ts",
        ".eslintrc.js",
        "package.json"
      ]
    },
    "type-check": {
      "dependsOn": ["^build"],
      "outputs": [],
      "inputs": [
        "src/**/*.tsx",
        "src/**/*.ts",
        "tsconfig.json",
        "package.json"
      ]
    }
  }
}
```

### 2. Remote Caching Setup

```bash
# Link to Vercel Remote Cache
npx turbo login
npx turbo link

# Or use Turborepo Cloud
# Create account at https://turbo.build/
# Add TURBO_TOKEN to environment variables
```

```json
// turbo.json - Remote cache configuration
{
  "remoteCache": {
    "enabled": true,
    "signature": true
  },
  "ui": "tui"
}
```

## Build and Deployment

### 1. Docker Configuration

```dockerfile
# apps/expense-service/Dockerfile
FROM node:18-alpine AS base

# Install dependencies only when needed
FROM base AS deps
RUN apk add --no-cache libc6-compat
WORKDIR /app

# Install Turborepo globally
RUN npm install -g turbo

# Copy package files
COPY package.json package-lock.json* ./
COPY turbo.json ./

# Copy package.json files for all workspaces
COPY apps/expense-service/package.json ./apps/expense-service/package.json
COPY packages/expense-core/package.json ./packages/expense-core/package.json
COPY packages/utils/package.json ./packages/utils/package.json
COPY packages/config/package.json ./packages/config/package.json

# Install dependencies
RUN npm ci

# Build the app
FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Build the application
RUN turbo build --filter=expense-service...

# Production image
FROM base AS runner
WORKDIR /app

ENV NODE_ENV production

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 expressjs

# Copy built application
COPY --from=builder --chown=expressjs:nodejs /app/apps/expense-service/dist ./apps/expense-service/dist
COPY --from=builder --chown=expressjs:nodejs /app/packages/expense-core/dist ./packages/expense-core/dist
COPY --from=builder --chown=expressjs:nodejs /app/packages/utils/dist ./packages/utils/dist
COPY --from=builder --chown=expressjs:nodejs /app/node_modules ./node_modules

USER expressjs

EXPOSE 3000

ENV PORT 3000
ENV HOSTNAME "0.0.0.0"

CMD ["node", "apps/expense-service/dist/index.js"]
```

### 2. CI/CD Integration

```yaml
# .github/workflows/turborepo-ci.yml
name: Turborepo CI

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

env:
  TURBO_TOKEN: ${{ secrets.TURBO_TOKEN }}
  TURBO_TEAM: ${{ vars.TURBO_TEAM }}

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: 18
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Build
        run: turbo build

      - name: Test
        run: turbo test

      - name: Lint
        run: turbo lint

      - name: Type check
        run: turbo type-check

      - name: Build Docker images
        if: github.ref == 'refs/heads/main'
        run: turbo docker-build
```

## Package Management

### 1. Versioning with Changesets

```bash
# Install changesets
npm install -D @changesets/cli
npx changeset init
```

```json
// .changeset/config.json
{
  "changelog": "@changesets/cli/changelog",
  "commit": false,
  "fixed": [],
  "linked": [],
  "access": "restricted",
  "baseBranch": "main",
  "updateInternalDependencies": "patch",
  "ignore": []
}
```

### 2. Creating and Publishing Releases

```bash
# Create a changeset
npx changeset

# Version packages
npx changeset version

# Publish packages
turbo build --filter=./packages/*
npx changeset publish
```

## Performance Optimization

### 1. Cache Configuration

```json
// turbo.json - Optimized cache settings
{
  "globalDependencies": [
    "**/.env.*local",
    "tsconfig.json",
    "package-lock.json"
  ],
  "pipeline": {
    "build": {
      "dependsOn": ["^build"],
      "outputs": ["dist/**"],
      "inputs": [
        "src/**",
        "public/**",
        "package.json",
        "tsconfig.json",
        "vite.config.ts",
        "next.config.js"
      ]
    }
  }
}
```

### 2. Parallel Execution

```bash
# Run tasks in parallel
turbo dev --parallel

# Control concurrency
turbo build --concurrency=4

# Skip cache for development
turbo dev --no-cache
```

## Comparison with Nx

### Turborepo Advantages

1. **Simplicity**: Minimal configuration required
2. **Performance**: Extremely fast incremental builds
3. **Remote Caching**: Built-in Vercel integration
4. **Zero Configuration**: Works out of the box with existing projects

### Turborepo Limitations

1. **Ecosystem**: Smaller plugin ecosystem compared to Nx
2. **Generators**: No built-in code generation tools
3. **Advanced Features**: Fewer advanced development tools
4. **Language Support**: Primarily focused on JavaScript/TypeScript

### When to Choose Turborepo

- **Simple Projects**: When you need minimal configuration
- **JavaScript/TypeScript Focus**: Pure JS/TS monorepos
- **Performance Priority**: Maximum build speed is critical
- **Vercel Integration**: Using Vercel for deployment

### Migration from Nx to Turborepo

```bash
# Remove Nx dependencies
npm uninstall @nx/workspace @nx/devkit

# Install Turborepo
npm install -D turbo

# Convert nx.json to turbo.json
# Manual configuration migration required

# Update scripts in package.json
# Replace 'nx' commands with 'turbo' commands
```

## Troubleshooting

### Common Issues

1. **Cache Issues**

   ```bash
   # Clear Turborepo cache
   turbo clean
   rm -rf .turbo
   ```

2. **Dependency Issues**

   ```bash
   # Clean and reinstall
   rm -rf node_modules package-lock.json
   npm install
   ```

3. **Build Failures**

   ```bash
   # Build with verbose output
   turbo build --verbose
   
   # Build without cache
   turbo build --no-cache
   ```

### Performance Debugging

```bash
# Profile task execution
turbo build --profile=profile.json

# Analyze profile with Chrome DevTools
# Upload profile.json to chrome://tracing
```

## Best Practices

### 1. Package Organization

- Keep shared packages small and focused
- Use semantic versioning for internal packages
- Implement proper TypeScript configurations
- Set up consistent linting and formatting

### 2. Development Workflow

- Use changesets for version management
- Implement proper CI/CD pipelines
- Leverage remote caching for team collaboration
- Monitor build performance regularly

### 3. Performance Optimization

- Configure task dependencies correctly
- Use appropriate cache inputs and outputs
- Leverage parallel execution where possible
- Monitor and optimize bundle sizes

This Turborepo implementation provides a solid foundation for building and scaling the Expense Tracker monorepo with excellent performance characteristics and minimal configuration overhead.
