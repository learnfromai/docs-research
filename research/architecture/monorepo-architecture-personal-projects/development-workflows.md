# Development Workflows for Monorepo

## Overview

Efficient development workflows are crucial for monorepo success, enabling multiple developers to work on different services while maintaining code quality, consistency, and rapid feedback loops.

## Git Workflow Strategy

### Branch Strategy

```bash
# Main branches
main                    # Production-ready code
develop                 # Integration branch for features
release/v1.2.0         # Release preparation
hotfix/critical-bug    # Emergency fixes

# Feature branches (per service/shared library)
feature/expense-service/add-categories
feature/shared/ui-components/expense-card
feature/web-pwa/dashboard-redesign
feature/mobile/offline-sync

# Bug fix branches
bugfix/expense-service/validation-error
bugfix/shared/api-client/timeout-handling
```

### Commit Message Convention

```bash
# Format: <type>(<scope>): <description>
feat(expense-service): add expense categorization
fix(shared/ui): resolve ExpenseCard rendering issue
docs(monorepo): update development workflow guide
refactor(user-service): improve authentication logic
test(e2e): add expense creation workflow tests
chore(deps): update dependencies across workspace

# Breaking changes
feat(api)!: change expense API response format

BREAKING CHANGE: The expense API now returns amounts as integers (cents) instead of floats
```

### Pre-commit Hooks

```json
// .husky/pre-commit
#!/usr/bin/env sh
. "$(dirname -- "$0")/_/husky.sh"

# Run affected tests and linting
npx nx affected:test --parallel=3
npx nx affected:lint --parallel=3

# Type checking
npx nx run-many --target=typecheck --projects=tag:type:app,tag:type:lib

# Format check
npx prettier --check "**/*.{ts,tsx,js,jsx,json,md}"
```

```json
// .husky/commit-msg
#!/usr/bin/env sh
. "$(dirname -- "$0")/_/husky.sh"

# Validate commit message format
npx commitlint --edit $1
```

## Development Environment Setup

### Local Development Script

```bash
#!/bin/bash
# scripts/dev-setup.sh

echo "🚀 Setting up Expense Tracker development environment..."

# Install dependencies
echo "📦 Installing dependencies..."
npm install

# Setup environment variables
echo "🔧 Setting up environment variables..."
cp .env.example .env.local

# Start local services
echo "🐳 Starting local services with Docker..."
docker-compose -f docker-compose.dev.yml up -d

# Wait for services to be ready
echo "⏳ Waiting for services to start..."
sleep 30

# Run database migrations
echo "🗄️ Running database migrations..."
npx nx run user-service:migrate
npx nx run expense-service:migrate

# Seed development data
echo "🌱 Seeding development data..."
npx nx run user-service:seed
npx nx run expense-service:seed

# Start development servers
echo "🔥 Starting development servers..."
npx nx run-many --target=serve --projects=web-pwa,mobile,api-gateway --parallel

echo "✅ Development environment ready!"
echo "🌐 Web PWA: http://localhost:4200"
echo "📱 Mobile (Expo): http://localhost:8081"
echo "🚪 API Gateway: http://localhost:3000"
```

### VS Code Configuration

```json
// .vscode/settings.json
{
  "typescript.preferences.importModuleSpecifier": "relative",
  "typescript.suggest.autoImports": true,
  "editor.formatOnSave": true,
  "editor.codeActionsOnSave": {
    "source.fixAll.eslint": true,
    "source.organizeImports": true
  },
  "eslint.workingDirectories": [
    "apps/web-pwa",
    "apps/mobile",
    "apps/microservices/user-service",
    "apps/microservices/expense-service",
    "packages/shared"
  ],
  "jest.jestCommandLine": "npx nx test",
  "jest.autoRun": "off",
  "nx.enableCodeLens": true
}
```

```json
// .vscode/launch.json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Debug User Service",
      "type": "node",
      "request": "launch",
      "program": "${workspaceFolder}/dist/apps/microservices/user-service/main.js",
      "env": {
        "NODE_ENV": "development"
      },
      "console": "integratedTerminal",
      "internalConsoleOptions": "neverOpen"
    },
    {
      "name": "Debug Expense Service",
      "type": "node",
      "request": "launch",
      "program": "${workspaceFolder}/dist/apps/microservices/expense-service/main.js",
      "env": {
        "NODE_ENV": "development"
      },
      "console": "integratedTerminal"
    },
    {
      "name": "Debug Web PWA",
      "type": "node",
      "request": "launch",
      "program": "${workspaceFolder}/node_modules/.bin/nx",
      "args": ["serve", "web-pwa", "--port=4200"],
      "console": "integratedTerminal"
    }
  ],
  "compounds": [
    {
      "name": "Debug All Services",
      "configurations": ["Debug User Service", "Debug Expense Service"]
    }
  ]
}
```

## Task Automation with Nx

### Custom Executors

```typescript
// tools/executors/docker-build/executor.ts
import { ExecutorContext } from '@nx/devkit';
import { execSync } from 'child_process';

export interface DockerBuildExecutorSchema {
  dockerfile: string;
  tag: string;
  context: string;
  buildArgs?: Record<string, string>;
}

export default async function runExecutor(
  options: DockerBuildExecutorSchema,
  context: ExecutorContext
) {
  const projectName = context.projectName;
  const tag = options.tag.replace('{projectName}', projectName);
  
  console.log(`🐳 Building Docker image for ${projectName}...`);
  
  let buildCommand = `docker build -f ${options.dockerfile} -t ${tag} ${options.context}`;
  
  if (options.buildArgs) {
    const buildArgs = Object.entries(options.buildArgs)
      .map(([key, value]) => `--build-arg ${key}=${value}`)
      .join(' ');
    buildCommand += ` ${buildArgs}`;
  }
  
  try {
    execSync(buildCommand, { stdio: 'inherit' });
    console.log(`✅ Successfully built ${tag}`);
    return { success: true };
  } catch (error) {
    console.error(`❌ Failed to build ${tag}:`, error);
    return { success: false };
  }
}
```

### Project Configuration Templates

```json
// tools/generators/microservice/files/project.json
{
  "name": "<%= name %>",
  "type": "application",
  "root": "apps/microservices/<%= name %>",
  "sourceRoot": "apps/microservices/<%= name %>/src",
  "targets": {
    "serve": {
      "executor": "@nx/node:execute",
      "options": {
        "buildTarget": "<%= name %>:build",
        "watch": true,
        "inspect": true
      },
      "configurations": {
        "development": {
          "buildTarget": "<%= name %>:build:development"
        }
      }
    },
    "build": {
      "executor": "@nx/webpack:webpack",
      "outputs": ["{options.outputPath}"],
      "options": {
        "target": "node",
        "compiler": "tsc",
        "outputPath": "dist/apps/microservices/<%= name %>",
        "main": "apps/microservices/<%= name %>/src/main.ts",
        "tsConfig": "apps/microservices/<%= name %>/tsconfig.app.json",
        "externalDependencies": "none"
      },
      "configurations": {
        "development": {
          "optimization": false,
          "extractLicenses": false,
          "inspect": false,
          "sourceMap": true
        },
        "production": {
          "optimization": true,
          "extractLicenses": true,
          "inspect": false,
          "fileReplacements": [
            {
              "replace": "apps/microservices/<%= name %>/src/environments/environment.ts",
              "with": "apps/microservices/<%= name %>/src/environments/environment.prod.ts"
            }
          ]
        }
      }
    },
    "test": {
      "executor": "@nx/jest:jest",
      "outputs": ["{workspaceRoot}/coverage/apps/microservices/<%= name %>"],
      "options": {
        "jestConfig": "apps/microservices/<%= name %>/jest.config.ts"
      }
    },
    "lint": {
      "executor": "@nx/linter:eslint",
      "outputs": ["{options.outputFile}"],
      "options": {
        "lintFilePatterns": ["apps/microservices/<%= name %>/**/*.ts"]
      }
    },
    "docker-build": {
      "executor": "@expense-tracker/docker-build",
      "options": {
        "dockerfile": "apps/microservices/<%= name %>/Dockerfile",
        "tag": "expense-tracker/<%= name %>:latest",
        "context": "."
      }
    },
    "e2e": {
      "executor": "@nx/playwright:playwright",
      "outputs": ["{workspaceRoot}/dist/.playwright"],
      "options": {
        "config": "apps/microservices/<%= name %>/playwright.config.ts"
      }
    }
  },
  "tags": ["type:service", "scope:<%= name %>"]
}
```

## Development Scripts

### Package.json Scripts

```json
{
  "scripts": {
    "dev": "./scripts/dev-setup.sh",
    "dev:clean": "nx reset && npm run dev",
    
    "build": "nx run-many --target=build --projects=tag:type:app",
    "build:affected": "nx affected:build",
    "build:prod": "nx run-many --target=build --configuration=production",
    
    "test": "nx run-many --target=test --parallel=3",
    "test:affected": "nx affected:test",
    "test:e2e": "nx run-many --target=e2e --parallel=1",
    "test:coverage": "nx run-many --target=test --coverage",
    
    "lint": "nx run-many --target=lint --parallel=3",
    "lint:fix": "nx run-many --target=lint --fix",
    "lint:affected": "nx affected:lint",
    
    "format": "prettier --write .",
    "format:check": "prettier --check .",
    
    "typecheck": "nx run-many --target=typecheck",
    
    "docker:build": "nx run-many --target=docker-build",
    "docker:dev": "docker-compose -f docker-compose.dev.yml up",
    "docker:prod": "docker-compose -f docker-compose.prod.yml up",
    
    "migration:create": "nx g @expense-tracker/migration",
    "migration:run": "nx run-many --target=migrate",
    
    "release": "nx release",
    "release:dry-run": "nx release --dry-run",
    
    "graph": "nx graph",
    "affected:graph": "nx affected:graph"
  }
}
```

### Makefile for Common Tasks

```makefile
# Makefile
.PHONY: help install dev build test lint clean docker-up docker-down

help: ## Show this help message
  @echo 'Usage: make [target]'
  @echo ''
  @echo 'Targets:'
  @awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

install: ## Install dependencies
  npm install

dev: ## Start development environment
  ./scripts/dev-setup.sh

build: ## Build all applications
  nx run-many --target=build --projects=tag:type:app

build-affected: ## Build only affected applications
  nx affected:build

test: ## Run all tests
  nx run-many --target=test --parallel=3

test-affected: ## Run tests for affected projects
  nx affected:test

lint: ## Lint all projects
  nx run-many --target=lint --parallel=3

lint-fix: ## Fix linting issues
  nx run-many --target=lint --fix

clean: ## Clean build artifacts and node_modules
  nx reset
  rm -rf node_modules
  rm -rf dist

docker-up: ## Start Docker services
  docker-compose -f docker-compose.dev.yml up -d

docker-down: ## Stop Docker services
  docker-compose -f docker-compose.dev.yml down

docker-logs: ## View Docker logs
  docker-compose -f docker-compose.dev.yml logs -f

migrate: ## Run database migrations
  nx run-many --target=migrate

seed: ## Seed development data
  nx run-many --target=seed

format: ## Format code
  prettier --write .

release: ## Create a release
  nx release

graph: ## Show dependency graph
  nx graph

affected-graph: ## Show affected projects graph
  nx affected:graph
```

## Development Workflow Automation

### GitHub Actions for Development

```yaml
# .github/workflows/development.yml
name: Development Workflow

on:
  push:
    branches-ignore: [main]
  pull_request:
    branches: [main, develop]

jobs:
  setup:
    runs-on: ubuntu-latest
    outputs:
      affected-apps: ${{ steps.affected.outputs.apps }}
      affected-libs: ${{ steps.affected.outputs.libs }}
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '18'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Get affected projects
        id: affected
        run: |
          echo "apps=$(npx nx print-affected --type=app --select=projects | tr '\n' ',' | sed 's/,$//')" >> $GITHUB_OUTPUT
          echo "libs=$(npx nx print-affected --type=lib --select=projects | tr '\n' ',' | sed 's/,$//')" >> $GITHUB_OUTPUT

  lint-and-test:
    needs: setup
    runs-on: ubuntu-latest
    if: needs.setup.outputs.affected-apps != '' || needs.setup.outputs.affected-libs != ''
    
    strategy:
      matrix:
        target: [lint, test, typecheck]

    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '18'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Run ${{ matrix.target }}
        run: npx nx affected:${{ matrix.target }} --parallel=3

  build:
    needs: setup
    runs-on: ubuntu-latest
    if: needs.setup.outputs.affected-apps != ''
    
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '18'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Build affected apps
        run: npx nx affected:build --parallel=3

      - name: Upload build artifacts
        uses: actions/upload-artifact@v4
        with:
          name: build-artifacts
          path: dist/

  e2e:
    needs: [setup, build]
    runs-on: ubuntu-latest
    if: needs.setup.outputs.affected-apps != ''
    
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '18'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Start services
        run: docker-compose -f docker-compose.ci.yml up -d

      - name: Wait for services
        run: sleep 30

      - name: Run E2E tests
        run: npx nx affected:e2e

      - name: Stop services
        run: docker-compose -f docker-compose.ci.yml down
```

### Local Development Helper Scripts

```bash
#!/bin/bash
# scripts/affected-tests.sh
# Run tests only for affected projects

echo "🧪 Running tests for affected projects..."

# Get affected projects
AFFECTED_PROJECTS=$(npx nx print-affected --type=app,lib --select=projects | tr '\n' ' ')

if [ -z "$AFFECTED_PROJECTS" ]; then
  echo "✅ No affected projects found"
  exit 0
fi

echo "📋 Affected projects: $AFFECTED_PROJECTS"

# Run tests in parallel
npx nx affected:test --parallel=3 --coverage

# Generate coverage report
echo "📊 Generating coverage report..."
npx nx run-many --target=test --coverage --projects=$AFFECTED_PROJECTS

echo "✅ Tests completed for affected projects"
```

```bash
#!/bin/bash
# scripts/service-logs.sh
# View logs for specific service

SERVICE_NAME=${1:-"all"}

if [ "$SERVICE_NAME" = "all" ]; then
  echo "📋 Showing logs for all services..."
  docker-compose -f docker-compose.dev.yml logs -f
else
  echo "📋 Showing logs for $SERVICE_NAME..."
  docker-compose -f docker-compose.dev.yml logs -f $SERVICE_NAME
fi
```

```bash
#!/bin/bash
# scripts/reset-dev-env.sh
# Reset development environment

echo "🔄 Resetting development environment..."

# Stop all services
docker-compose -f docker-compose.dev.yml down -v

# Clean Nx cache
npx nx reset

# Clean node_modules
rm -rf node_modules package-lock.json

# Reinstall dependencies
npm install

# Restart services
docker-compose -f docker-compose.dev.yml up -d

# Wait for services
sleep 30

# Run migrations and seed data
npx nx run-many --target=migrate
npx nx run-many --target=seed

echo "✅ Development environment reset complete!"
```

## Code Quality Automation

### ESLint Configuration for Monorepo

```javascript
// .eslintrc.js
module.exports = {
  root: true,
  ignorePatterns: ['**/*'],
  plugins: ['@nx'],
  overrides: [
    {
      files: ['*.ts', '*.tsx', '*.js', '*.jsx'],
      rules: {
        '@nx/enforce-module-boundaries': [
          'error',
          {
            enforceBuildableLibDependency: true,
            allow: [],
            depConstraints: [
              {
                sourceTag: 'scope:shared',
                onlyDependOnLibsWithTags: ['scope:shared']
              },
              {
                sourceTag: 'scope:user-service',
                onlyDependOnLibsWithTags: ['scope:shared', 'scope:user-service']
              },
              {
                sourceTag: 'scope:expense-service',
                onlyDependOnLibsWithTags: ['scope:shared', 'scope:expense-service']
              },
              {
                sourceTag: 'type:feature',
                onlyDependOnLibsWithTags: ['type:data-access', 'type:ui', 'type:util']
              }
            ]
          }
        ]
      }
    },
    {
      files: ['*.ts', '*.tsx'],
      extends: ['@nx/typescript'],
      rules: {
        '@typescript-eslint/no-explicit-any': 'warn',
        '@typescript-eslint/no-unused-vars': 'error'
      }
    },
    {
      files: ['*.js', '*.jsx'],
      extends: ['@nx/javascript'],
      rules: {}
    },
    {
      files: ['*.spec.ts', '*.spec.tsx', '*.spec.js', '*.spec.jsx'],
      env: {
        jest: true
      },
      rules: {}
    }
  ]
};
```

### Prettier Configuration

```json
// .prettierrc
{
  "singleQuote": true,
  "trailingComma": "es5",
  "tabWidth": 2,
  "semi": true,
  "printWidth": 100,
  "arrowParens": "avoid",
  "endOfLine": "lf",
  "overrides": [
    {
      "files": "*.md",
      "options": {
        "printWidth": 80,
        "proseWrap": "always"
      }
    }
  ]
}
```

This comprehensive development workflow ensures efficient, consistent, and high-quality development across your monorepo while providing the flexibility needed for multiple services and applications.
