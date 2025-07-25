# Nx Monorepo Open Source Setup

## 📋 Overview

**Nx monorepos** offer unique advantages for **open source projects**, including **code sharing**, **consistent tooling**, and **scalable project structure**. However, they also present specific challenges around **package management**, **publishing**, and **contributor workflows**. This guide provides comprehensive setup instructions and best practices for creating successful open source Nx monorepos.

## 🚀 Initial Project Setup

### 1. **Create Nx Workspace**

```bash
# Create new Nx workspace
npx create-nx-workspace@latest my-open-source-project --preset=empty

cd my-open-source-project

# Initialize git repository
git init
git add .
git commit -m "chore: initialize Nx workspace"
```

### 2. **Configure Package.json for Open Source**

```json
{
  "name": "@your-org/nx-monorepo-starter",
  "version": "0.0.0",
  "description": "Production-ready Nx monorepo starter with clean architecture",
  "author": "Your Name <your.email@example.com> (https://yoursite.dev)",
  "license": "MIT",
  "private": false,
  "repository": {
    "type": "git",
    "url": "https://github.com/yourusername/nx-monorepo-starter"
  },
  "homepage": "https://yourusername.github.io/nx-monorepo-starter",
  "bugs": {
    "url": "https://github.com/yourusername/nx-monorepo-starter/issues"
  },
  "keywords": [
    "nx",
    "monorepo", 
    "typescript",
    "open-source",
    "starter-template",
    "clean-architecture"
  ],
  "engines": {
    "node": ">=18.0.0",
    "npm": ">=8.0.0"
  },
  "workspaces": [
    "apps/*",
    "libs/*"
  ],
  "scripts": {
    "build": "nx build",
    "test": "nx test",
    "lint": "nx lint",
    "format": "nx format:write",
    "affected:build": "nx affected:build",
    "affected:test": "nx affected:test",
    "affected:lint": "nx affected:lint",
    "dep-graph": "nx dep-graph",
    "help": "nx help"
  },
  "devDependencies": {
    "@nx/workspace": "17.2.8",
    "@nx/js": "17.2.8",
    "@nx/react": "17.2.8",
    "@nx/node": "17.2.8",
    "@nx/web": "17.2.8",
    "@nx/jest": "17.2.8",
    "@nx/cypress": "17.2.8",
    "@nx/eslint-plugin": "17.2.8",
    "typescript": "~5.2.2",
    "jest": "^29.4.1",
    "cypress": "^13.0.0",
    "eslint": "~8.48.0",
    "prettier": "^2.6.2"
  }
}
```

### 3. **Create PROJECT_MANIFEST.json**

```json
{
  "project": {
    "name": "nx-monorepo-starter",
    "displayName": "Nx Monorepo Open Source Starter",
    "description": "Production-ready Nx monorepo with clean architecture, TypeScript, and comprehensive tooling",
    "created": "2025-01-15",
    "version": "0.0.0",
    "type": "nx-monorepo",
    "architecture": "clean-architecture",
    "license": "MIT"
  },
  "metadata": {
    "initialCommit": "chore: initialize Nx workspace",
    "repository": "https://github.com/yourusername/nx-monorepo-starter",
    "documentation": "https://yourusername.github.io/nx-monorepo-starter",
    "author": {
      "name": "Your Name",
      "email": "your.email@example.com",
      "url": "https://yoursite.dev"
    }
  },
  "structure": {
    "monorepo": true,
    "workspaceType": "nx",
    "packageManager": "npm",
    "language": "typescript",
    "testing": "jest",
    "e2e": "cypress"
  },
  "compliance": {
    "openSource": true,
    "security": "standard", 
    "accessibility": "wcag-2.1",
    "testing": "comprehensive",
    "documentation": "complete"
  },
  "nx": {
    "version": "17.2.8",
    "preset": "empty",
    "packageManager": "npm"
  }
}
```

## 🏗️ Recommended Nx Configuration

### 1. **nx.json Configuration**

```json
{
  "$schema": "./node_modules/nx/schemas/nx-schema.json",
  "namedInputs": {
    "default": ["{projectRoot}/**/*", "sharedGlobals"],
    "production": [
      "default",
      "!{projectRoot}/**/?(*.)+(spec|test).[jt]s?(x)?(.snap)",
      "!{projectRoot}/tsconfig.spec.json",
      "!{projectRoot}/jest.config.[jt]s",
      "!{projectRoot}/.eslintrc.json",
      "!{projectRoot}/src/test-setup.[jt]s"
    ],
    "sharedGlobals": []
  },
  "targetDefaults": {
    "build": {
      "dependsOn": ["^build"],
      "inputs": ["production", "^production"],
      "cache": true
    },
    "test": {
      "inputs": ["default", "^production", "{workspaceRoot}/jest.preset.js"],
      "cache": true
    },
    "e2e": {
      "inputs": ["default", "^production"],
      "cache": true
    },
    "lint": {
      "inputs": ["default", "{workspaceRoot}/.eslintrc.json"],
      "cache": true
    },
    "publish": {
      "dependsOn": ["build"],
      "cache": false
    }
  },
  "generators": {
    "@nx/react": {
      "application": {
        "style": "css",
        "linter": "eslint",
        "bundler": "vite",
        "e2eTestRunner": "cypress"
      },
      "library": {
        "style": "css",
        "linter": "eslint",
        "unitTestRunner": "jest"
      }
    },
    "@nx/node": {
      "application": {
        "linter": "eslint"
      },
      "library": {
        "linter": "eslint"
      }
    }
  },
  "tasksRunnerOptions": {
    "default": {
      "runner": "nx/tasks-runners/default",
      "options": {
        "cacheableOperations": [
          "build",
          "test",
          "lint",
          "e2e"
        ]
      }
    }
  }
}
```

### 2. **TypeScript Base Configuration**

```json
// tsconfig.base.json
{
  "compileOnSave": false,
  "compilerOptions": {
    "rootDir": ".",
    "sourceMap": true,
    "declaration": false,
    "moduleResolution": "node",
    "emitDecoratorMetadata": true,
    "experimentalDecorators": true,
    "importHelpers": true,
    "target": "es2015",
    "module": "esnext",
    "lib": ["es2020", "dom"],
    "skipLibCheck": true,
    "skipDefaultLibCheck": true,
    "baseUrl": ".",
    "strict": true,
    "noImplicitOverride": true,
    "noPropertyAccessFromIndexSignature": true,
    "noImplicitReturns": true,
    "noFallthroughCasesInSwitch": true,
    "paths": {
      "@myorg/domain": ["libs/domain/src/index.ts"],
      "@myorg/application": ["libs/application/src/index.ts"],
      "@myorg/infrastructure": ["libs/infrastructure/src/index.ts"],
      "@myorg/shared-ui": ["libs/shared/ui/src/index.ts"],
      "@myorg/shared-utilities": ["libs/shared/utilities/src/index.ts"],
      "@myorg/shared-types": ["libs/shared/types/src/index.ts"]
    }
  },
  "exclude": ["node_modules", "tmp"]
}
```

## 📦 Application and Library Setup

### 1. **Create Applications**

```bash
# Web application
nx g @nx/react:app web-app --routing --style=css --bundler=vite

# API gateway
nx g @nx/node:app api-gateway --framework=express

# Admin dashboard (optional)
nx g @nx/react:app admin-dashboard --routing --style=css --bundler=vite
```

### 2. **Create Core Libraries**

```bash
# Domain layer (business logic)
nx g @nx/js:lib domain --directory=libs/domain --buildable --publishable --importPath=@myorg/domain

# Application layer (use cases)
nx g @nx/js:lib application --directory=libs/application --buildable --publishable --importPath=@myorg/application

# Infrastructure layer (external adapters)
nx g @nx/js:lib infrastructure --directory=libs/infrastructure --buildable --publishable --importPath=@myorg/infrastructure

# Shared libraries
nx g @nx/react:lib shared-ui --directory=libs/shared/ui --buildable --publishable --importPath=@myorg/shared-ui
nx g @nx/js:lib shared-utilities --directory=libs/shared/utilities --buildable --publishable --importPath=@myorg/shared-utilities
nx g @nx/js:lib shared-types --directory=libs/shared/types --buildable --publishable --importPath=@myorg/shared-types
```

### 3. **Configure Library Project.json Templates**

```json
// libs/domain/project.json
{
  "name": "domain",
  "$schema": "../../node_modules/nx/schemas/project-schema.json",
  "sourceRoot": "libs/domain/src",
  "projectType": "library",
  "targets": {
    "build": {
      "executor": "@nx/js:tsc",
      "outputs": ["{options.outputPath}"],
      "options": {
        "outputPath": "dist/libs/domain",
        "main": "libs/domain/src/index.ts",
        "tsConfig": "libs/domain/tsconfig.lib.json",
        "assets": ["libs/domain/*.md"]
      }
    },
    "test": {
      "executor": "@nx/jest:jest",
      "outputs": ["{workspaceRoot}/coverage/{projectRoot}"],
      "options": {
        "jestConfig": "libs/domain/jest.config.ts",
        "passWithNoTests": true
      },
      "configurations": {
        "ci": {
          "ci": true,
          "coverageReporters": ["text"]
        }
      }
    },
    "lint": {
      "executor": "@nx/eslint:lint",
      "outputs": ["{options.outputFile}"],
      "options": {
        "lintFilePatterns": ["libs/domain/**/*.ts"]
      }
    },
    "publish": {
      "executor": "nx:run-commands",
      "dependsOn": ["build"],
      "options": {
        "command": "npm publish dist/libs/domain --access public"
      }
    }
  },
  "tags": ["domain", "scope:shared", "type:business-logic"]
}
```

## 🔧 Development Workflow Configuration

### 1. **ESLint Configuration for Monorepo**

```javascript
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
                "sourceTag": "domain",
                "onlyDependOnLibsWithTags": []
              },
              {
                "sourceTag": "application",
                "onlyDependOnLibsWithTags": ["domain", "shared"]
              },
              {
                "sourceTag": "infrastructure", 
                "onlyDependOnLibsWithTags": ["domain", "application", "shared"]
              },
              {
                "sourceTag": "scope:app",
                "onlyDependOnLibsWithTags": ["domain", "application", "infrastructure", "shared"]
              }
            ]
          }
        ]
      }
    }
  ]
}
```

### 2. **Jest Configuration**

```javascript
// jest.preset.js
const nxPreset = require('@nx/jest/preset').default;

module.exports = {
  ...nxPreset,
  collectCoverageFrom: [
    'libs/**/*.{ts,tsx}',
    'apps/**/*.{ts,tsx}',
    '!**/*.d.ts',
    '!**/*.config.ts',
    '!**/node_modules/**'
  ],
  coverageThreshold: {
    global: {
      branches: 80,
      functions: 80,
      lines: 80,
      statements: 80
    }
  }
};
```

### 3. **Prettier Configuration**

```json
// .prettierrc
{
  "singleQuote": true,
  "trailingComma": "es5",
  "tabWidth": 2,
  "semi": true,
  "printWidth": 100,
  "arrowParens": "avoid",
  "endOfLine": "lf"
}
```

## 🚀 Publishing Strategy

### 1. **Individual Package Publishing**

Each library can be published separately:

```bash
# Build and publish domain library
nx build domain
cd dist/libs/domain
npm publish --access public

# Or use Nx command
nx publish domain
```

### 2. **Automated Publishing with GitHub Actions**

```yaml
# .github/workflows/publish-packages.yml
name: Publish Packages

on:
  release:
    types: [published]

jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
        with:
          fetch-depth: 0
      
      - uses: actions/setup-node@v3
        with:
          node-version: '18'
          registry-url: 'https://registry.npmjs.org/'
      
      - name: Install dependencies
        run: npm ci
      
      - name: Build affected libraries
        run: npx nx affected:build --parallel=3
      
      - name: Test affected libraries
        run: npx nx affected:test --parallel=3
      
      - name: Publish packages
        run: |
          for dir in dist/libs/*/; do
            if [ -f "$dir/package.json" ]; then
              echo "Publishing $(basename $dir)..."
              cd "$dir"
              npm publish --access public
              cd "$GITHUB_WORKSPACE"
            fi
          done
        env:
          NODE_AUTH_TOKEN: ${{ secrets.NPM_TOKEN }}
```

### 3. **Version Management Strategy**

```json
// tools/scripts/version-packages.js
const fs = require('fs');
const path = require('path');

function updatePackageVersions(newVersion) {
  const libsDir = path.join(__dirname, '../../libs');
  const libraries = fs.readdirSync(libsDir, { withFileTypes: true })
    .filter(dirent => dirent.isDirectory())
    .map(dirent => dirent.name);

  libraries.forEach(lib => {
    const packageJsonPath = path.join(libsDir, lib, 'package.json');
    if (fs.existsSync(packageJsonPath)) {
      const packageJson = JSON.parse(fs.readFileSync(packageJsonPath, 'utf8'));
      packageJson.version = newVersion;
      fs.writeFileSync(packageJsonPath, JSON.stringify(packageJson, null, 2));
      console.log(`Updated ${lib} to version ${newVersion}`);
    }
  });
}

// Usage: node tools/scripts/version-packages.js 1.0.0
const newVersion = process.argv[2];
if (newVersion) {
  updatePackageVersions(newVersion);
} else {
  console.error('Please provide a version number');
}
```

## 👥 Contributor Workflow

### 1. **Development Scripts**

```json
// package.json scripts for contributors
{
  "scripts": {
    "start:web": "nx serve web-app",
    "start:api": "nx serve api-gateway", 
    "dev": "concurrently \"nx serve web-app\" \"nx serve api-gateway\"",
    "build:all": "nx build-many --targets=build --all",
    "test:all": "nx test-many --targets=test --all",
    "test:affected": "nx affected:test",
    "lint:all": "nx lint-many --targets=lint --all",
    "lint:affected": "nx affected:lint",
    "format": "nx format:write",
    "format:check": "nx format:check",
    "dep-graph": "nx dep-graph",
    "affected:dep-graph": "nx affected:dep-graph",
    "clean": "nx reset"
  }
}
```

### 2. **Pre-commit Hooks with Husky**

```bash
# Install husky and lint-staged
npm install --save-dev husky lint-staged

# Initialize husky
npx husky install
npx husky add .husky/pre-commit "npx lint-staged"
```

```json
// package.json
{
  "lint-staged": {
    "*.{ts,tsx,js,jsx}": [
      "nx affected:lint --fix",
      "nx format:write --uncommitted"
    ],
    "*.{md,json,yml,yaml}": [
      "nx format:write --uncommitted"
    ]
  }
}
```

### 3. **Contributor Documentation**

```markdown
// docs/DEVELOPMENT.md
# Development Guide

## Quick Start

1. Clone the repository
2. Install dependencies: `npm install`
3. Start development servers: `npm run dev`
4. Run tests: `npm run test:all`

## Project Structure

- `apps/` - Applications (web-app, api-gateway)
- `libs/` - Reusable libraries organized by layer
- `tools/` - Build scripts and utilities

## Architecture

This project follows Clean Architecture principles:

- **Domain** (`libs/domain/`) - Business logic and entities
- **Application** (`libs/application/`) - Use cases and services  
- **Infrastructure** (`libs/infrastructure/`) - External adapters
- **Shared** (`libs/shared/`) - Common utilities and types

## Development Workflow

1. Create feature branch: `git checkout -b feature/new-feature`
2. Make changes following architecture guidelines
3. Add tests for new functionality
4. Run affected tests: `npm run test:affected`
5. Format code: `npm run format`
6. Commit with conventional commits
7. Push and create pull request

## Testing

- Unit tests: `nx test <project-name>`
- All tests: `npm run test:all`
- E2E tests: `nx e2e <app-name>-e2e`

## Building

- Single project: `nx build <project-name>`
- All projects: `npm run build:all`
- Affected only: `nx affected:build`
```

## 🔍 Monitoring and Analytics

### 1. **Dependency Graph Analysis**

```bash
# Generate dependency graph
nx dep-graph

# View affected projects
nx affected:dep-graph

# Analyze circular dependencies
nx lint --fix
```

### 2. **Bundle Analysis for Apps**

```bash
# Analyze web app bundle
nx build web-app --analyze

# Check bundle size
npx bundlesize
```

### 3. **Performance Monitoring**

```json
// tools/scripts/analyze-build.js
const { execSync } = require('child_process');
const fs = require('fs');

function analyzeBuild() {
  const buildStart = Date.now();
  
  try {
    execSync('nx build-many --targets=build --all', { stdio: 'inherit' });
    const buildTime = Date.now() - buildStart;
    
    const results = {
      timestamp: new Date().toISOString(),
      buildTime: buildTime,
      status: 'success'
    };
    
    fs.appendFileSync('build-analytics.json', JSON.stringify(results) + '\n');
    console.log(`Build completed in ${buildTime}ms`);
  } catch (error) {
    console.error('Build failed:', error.message);
  }
}

analyzeBuild();
```

## ✅ Setup Checklist

### Initial Setup
- [ ] **Create Nx workspace** with empty preset
- [ ] **Configure package.json** with open source metadata
- [ ] **Add PROJECT_MANIFEST.json** with project metadata
- [ ] **Set up LICENSE** and legal files
- [ ] **Configure TypeScript** with strict settings

### Project Structure
- [ ] **Create applications** (web, api, admin)
- [ ] **Set up domain library** for business logic
- [ ] **Create application library** for use cases
- [ ] **Add infrastructure library** for external adapters
- [ ] **Configure shared libraries** for common code

### Development Tools
- [ ] **Set up ESLint** with Nx module boundaries
- [ ] **Configure Prettier** for code formatting
- [ ] **Add Jest** for unit testing
- [ ] **Set up Cypress** for E2E testing
- [ ] **Configure Husky** for pre-commit hooks

### CI/CD Pipeline
- [ ] **Create GitHub Actions** for CI/CD
- [ ] **Set up automated testing** for all projects
- [ ] **Configure package publishing** workflow
- [ ] **Add dependency analysis** checks
- [ ] **Set up security scanning**

### Documentation
- [ ] **Write comprehensive README**
- [ ] **Create development guide**
- [ ] **Document architecture decisions**
- [ ] **Add API documentation**
- [ ] **Set up contributor guidelines**

---

**Navigation**
- ← Previous: [Clean Architecture for Open Source](./clean-architecture-open-source.md)
- → Next: [Project Initialization & Tracking](./project-initialization-tracking.md)
- ↑ Back to: [Main Guide](./README.md)

## 📚 References

- [Nx Official Documentation](https://nx.dev/)
- [Nx Monorepo Setup Guide](https://nx.dev/getting-started/intro)
- [Nx Publishing Packages](https://nx.dev/recipes/advanced-plugins/publish-packages)
- [Nx Module Boundaries](https://nx.dev/core-features/enforce-project-boundaries)
- [TypeScript Project Configuration](https://www.typescriptlang.org/docs/handbook/project-config.html)
- [npm Publishing Guide](https://docs.npmjs.com/cli/v8/commands/npm-publish)
- [Semantic Versioning](https://semver.org/)
- [Conventional Commits](https://www.conventionalcommits.org/)