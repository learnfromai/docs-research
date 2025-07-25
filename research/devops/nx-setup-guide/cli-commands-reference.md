# Nx CLI Commands Reference

Complete reference guide for essential Nx commands from workspace creation to deployment.

## 📋 Table of Contents

- [Workspace Management](#workspace-management)
- [Project Generation](#project-generation)  
- [Development Commands](#development-commands)
- [Build and Test](#build-and-test)
- [Code Quality](#code-quality)
- [Dependency Management](#dependency-management)
- [CI/CD Commands](#cicd-commands)
- [Advanced Commands](#advanced-commands)
- [Troubleshooting Commands](#troubleshooting-commands)

## 🏗️ Workspace Management

### Creating Workspaces

#### Interactive Workspace Creation
```bash
# Create new workspace with guided setup
npx create-nx-workspace@latest my-workspace

# Create with specific preset
npx create-nx-workspace@latest my-workspace --preset=react
npx create-nx-workspace@latest my-workspace --preset=angular
npx create-nx-workspace@latest my-workspace --preset=node
npx create-nx-workspace@latest my-workspace --preset=empty

# Create with additional options
npx create-nx-workspace@latest my-workspace \
  --preset=react \
  --bundler=vite \
  --packageManager=npm \
  --style=css \
  --nx-cloud=true
```

#### Add Nx to Existing Repository
```bash
# Initialize Nx in existing project
npx nx@latest init

# Add Nx to existing repo with automatic migration
npx nx@latest init --integrated

# Add Nx to existing monorepo (npm workspaces, lerna)
npx nx@latest init --package-based
```

### Workspace Information

#### View Workspace Configuration
```bash
# Show workspace information
nx report

# View workspace dependency graph
nx graph

# Show project information
nx show project my-app

# List all projects in workspace
nx list

# View workspace configuration
cat nx.json
```

## 🎯 Project Generation

### Applications

#### React Applications
```bash
# Basic React app
nx g @nx/react:app my-app

# React app with specific bundler
nx g @nx/react:app my-app --bundler=vite
nx g @nx/react:app my-app --bundler=webpack

# React app with additional options
nx g @nx/react:app web-app \
  --style=scss \
  --routing=true \
  --bundler=vite \
  --e2eTestRunner=cypress \
  --unitTestRunner=jest

# React app with directory structure
nx g @nx/react:app my-app --directory=apps/frontend
```

#### Express.js Applications
```bash
# Basic Express.js app
nx g @nx/express:app api-server

# Express.js app with frontend proxy
nx g @nx/express:app api-server --frontendProject=my-app

# Express.js app with additional options
nx g @nx/express:app backend-api \
  --linter=eslint \
  --unitTestRunner=jest \
  --directory=apps/backend
```

#### Other Application Types
```bash
# Next.js application
nx g @nx/next:app next-app --style=css

# Angular application
nx g @nx/angular:app angular-app --routing=true

# Node.js application
nx g @nx/node:app node-app

# React Native application
nx g @nx/react-native:app mobile-app

# Nest.js application
nx g @nx/nest:app nest-api
```

### Libraries

#### JavaScript/TypeScript Libraries
```bash
# Basic TypeScript library
nx g @nx/js:lib shared-utils

# Library with specific bundler
nx g @nx/js:lib shared-utils --bundler=tsc
nx g @nx/js:lib shared-utils --bundler=rollup

# Library with testing setup
nx g @nx/js:lib shared-utils \
  --unitTestRunner=jest \
  --linter=eslint

# Publishable library
nx g @nx/js:lib shared-ui \
  --publishable \
  --importPath=@my-workspace/shared-ui
```

#### React Component Libraries
```bash
# React component library
nx g @nx/react:lib shared-ui

# React library with Storybook
nx g @nx/react:lib ui-components \
  --buildable \
  --publishable \
  --importPath=@my-workspace/ui-components

# Generate components in library
nx g @nx/react:component button --project=shared-ui
nx g @nx/react:component modal --project=shared-ui --export=true

# React library with specific styling
nx g @nx/react:lib design-system \
  --style=scss \
  --bundler=rollup
```

#### Specialized Libraries
```bash
# Data access library
nx g @nx/js:lib data-access-users --tags=type:data-access

# Feature library
nx g @nx/react:lib feature-auth --tags=type:feature,scope:shared

# Utility library
nx g @nx/js:lib utils --tags=type:util,scope:shared

# Interface library
nx g @nx/js:lib api-interfaces --tags=type:interface,scope:shared
```

## 🚀 Development Commands

### Serving Applications

#### Single Application
```bash
# Serve React application
nx serve my-app

# Serve with specific port
nx serve my-app --port=3000

# Serve with host configuration
nx serve my-app --host=0.0.0.0 --port=4200

# Serve Express.js API
nx serve api-server

# Serve with environment variables
NODE_ENV=development nx serve my-app
```

#### Multiple Applications
```bash
# Serve multiple applications
nx run-many --target=serve --projects=my-app,api-server

# Serve all applications
nx run-many --target=serve --all

# Serve affected applications only
nx affected --target=serve
```

### Development Tools

#### File Watching and Hot Reload
```bash
# Serve with file watching
nx serve my-app --watch

# Serve with live reload
nx serve my-app --live-reload

# Serve with hmr (Hot Module Replacement)
nx serve my-app --hmr
```

#### Development Environment
```bash
# Run in development mode
NODE_ENV=development nx serve my-app

# Run with debug information
DEBUG=true nx serve my-app

# Run with verbose logging
nx serve my-app --verbose
```

## 🔨 Build and Test

### Building Applications

#### Single Project Build
```bash
# Build application
nx build my-app

# Build for production
nx build my-app --prod
nx build my-app --configuration=production

# Build with source maps
nx build my-app --source-map=true

# Build with bundle analysis
nx build my-app --stats-json
```

#### Multiple Projects Build
```bash
# Build all projects
nx run-many --target=build --all

# Build specific projects
nx run-many --target=build --projects=my-app,api-server

# Build affected projects only
nx affected --target=build

# Build with parallel execution
nx run-many --target=build --all --parallel=3
```

#### Build Configurations
```bash
# Build with custom configuration
nx build my-app --configuration=staging

# Build with environment-specific settings
nx build my-app --configuration=production --optimization=true

# Build libraries
nx build shared-ui
nx build shared-utils
```

### Testing Commands

#### Unit Testing
```bash
# Run tests for single project
nx test my-app

# Run tests with coverage
nx test my-app --coverage

# Run tests in watch mode
nx test my-app --watch

# Run specific test files
nx test my-app --testPathPattern=user

# Run tests with verbose output
nx test my-app --verbose
```

#### Multiple Project Testing
```bash
# Run all tests
nx run-many --target=test --all

# Run tests for specific projects
nx run-many --target=test --projects=my-app,shared-ui

# Run affected tests only
nx affected --target=test

# Run tests in parallel
nx run-many --target=test --all --parallel=3
```

#### End-to-End Testing
```bash
# Run e2e tests
nx e2e my-app-e2e

# Run e2e tests with specific browser
nx e2e my-app-e2e --browser=chrome

# Run e2e tests headlessly
nx e2e my-app-e2e --headless

# Run specific e2e test file
nx e2e my-app-e2e --spec=login.cy.ts
```

### Advanced Testing
```bash
# Run tests with custom Jest config
nx test my-app --config=jest.custom.config.js

# Run tests matching pattern
nx test my-app --testNamePattern="should login"

# Generate test coverage report
nx test my-app --coverage --coverageDirectory=coverage

# Run tests and update snapshots
nx test my-app --updateSnapshot
```

## 🔍 Code Quality

### Linting

#### Single Project Linting
```bash
# Lint project
nx lint my-app

# Lint with auto-fix
nx lint my-app --fix

# Lint specific files
nx lint my-app --files="src/**/*.ts"

# Lint with custom configuration
nx lint my-app --config=.eslintrc.custom.json
```

#### Multiple Projects Linting
```bash
# Lint all projects
nx run-many --target=lint --all

# Lint affected projects
nx affected --target=lint

# Lint with parallel execution
nx run-many --target=lint --all --parallel=3
```

### Code Formatting

#### Format Code
```bash
# Format all files
nx format

# Format specific files
nx format --files="apps/my-app/src/**/*.ts"

# Check formatting without fixing
nx format:check

# Write formatted files
nx format:write

# Format with specific patterns
nx format --files="*.{js,ts,tsx}" --write
```

## 📦 Dependency Management

### Nx Plugin Management

#### Install Nx Plugins
```bash
# Install React plugin
npm install --save-dev @nx/react

# Install Express plugin  
npm install --save-dev @nx/express

# Install testing plugins
npm install --save-dev @nx/cypress @nx/jest

# Install Storybook plugin
npm install --save-dev @nx/storybook

# Install Node.js plugin
npm install --save-dev @nx/node
```

#### List Available Plugins
```bash
# List installed plugins
nx list

# List available community plugins
nx list --type=community

# Show plugin capabilities
nx list @nx/react
nx list @nx/express
```

### Migration and Updates

#### Update Nx and Dependencies
```bash
# Update to latest Nx version
nx migrate latest

# Update to specific version
nx migrate 21.3.0

# Run migrations after update
nx migrate --run-migrations

# Update specific plugin
nx migrate @nx/react@latest
```

#### Dependency Analysis
```bash
# Show project dependencies
nx show project my-app --web

# Generate dependency graph
nx graph

# Show circular dependencies
nx graph --focus=my-app

# Export dependency graph
nx graph --file=output.json
```

## 🔄 CI/CD Commands

### Affected Commands for CI

#### Determine Affected Projects
```bash
# Show affected projects
nx affected:apps
nx affected:libs

# Show what will be affected by specific target
nx print-affected --target=build
nx print-affected --target=test

# Run affected with base comparison
nx affected:test --base=main
nx affected:build --base=origin/main
```

#### CI Optimizations
```bash
# Run affected tests in CI
nx affected --target=test --base=origin/main --head=HEAD

# Run affected builds
nx affected --target=build --base=origin/main --head=HEAD

# Run with parallel execution for CI
nx affected --target=test --parallel=3 --maxParallel=3

# Skip cache in CI
nx affected --target=test --skip-nx-cache
```

### Nx Cloud Integration

#### Connect to Nx Cloud
```bash
# Connect workspace to Nx Cloud
nx connect-to-nx-cloud

# Generate access token
nx connect

# Set up distributed caching
nx connect-to-nx-cloud --create-org="my-org"
```

#### Remote Caching Commands
```bash
# Enable remote caching
nx config nxCloudAccessToken your-token

# Disable remote caching temporarily
NX_CLOUD_NO_TIMEOUTS=true nx build my-app

# View cache statistics
nx reset

# Clear local cache
nx reset --onlyCache
```

## 🔧 Advanced Commands

### Workspace Analysis

#### Project Structure Analysis
```bash
# Generate workspace report
nx report

# Analyze bundle size
nx bundle-analyzer my-app

# Show workspace lint results
nx workspace-lint

# View task runner configuration
nx show runner-options
```

#### Performance Analysis
```bash
# Run with performance profiling
nx build my-app --verbose

# Measure build performance
time nx build my-app

# Profile task execution
NX_PROFILE=profile.json nx build my-app
```

### Custom Commands and Scripts

#### Running Custom Scripts
```bash
# Run custom npm script
nx run my-app:custom-script

# Run script with arguments
nx run my-app:build --args="--watch"

# Execute script in project directory
nx exec -- echo "Running in $(pwd)"
```

#### Workspace Scripts
```bash
# Run workspace script
npm run custom-workspace-script

# Execute command in all projects
nx run-many --target=custom-script --all

# Run command with custom parameters
nx run my-app:build --configuration=development --verbose=true
```

### Environment and Configuration

#### Environment Management
```bash
# Set environment variables
NX_VERBOSE=true nx build my-app
NODE_ENV=production nx build my-app

# Load environment from file
nx build my-app --env=.env.production

# Show resolved configuration
nx show project my-app --config
```

## 🔧 Troubleshooting Commands

### Debugging and Diagnostics

#### Cache Issues
```bash
# Clear Nx cache
nx reset

# Reset only build cache
nx reset --onlyCache

# View cache location
nx report | grep "Cache directory"

# Run without cache
nx build my-app --skip-nx-cache
```

#### Dependency Issues
```bash
# Check for circular dependencies
nx graph --show-affected

# Validate workspace structure
nx workspace-lint

# Check import boundaries
nx lint --rules=@nx/enforce-module-boundaries

# Analyze bundle duplicates
nx bundle-analyzer my-app
```

#### Build Issues
```bash
# Build with verbose output
nx build my-app --verbose

# Build without optimizations
nx build my-app --optimization=false

# Build with source maps for debugging
nx build my-app --source-map=true

# Clean and rebuild
nx reset && nx build my-app
```

### Performance Debugging

#### Slow Builds
```bash
# Profile build performance
NX_PROFILE=profile.json nx build my-app

# Run with timing information
time nx build my-app

# Enable verbose logging
NX_VERBOSE=true nx build my-app

# Check cache hit rate
nx reset && nx build my-app && nx build my-app
```

#### Memory Issues
```bash
# Increase Node.js memory limit
NODE_OPTIONS="--max-old-space-size=4096" nx build my-app

# Run with memory profiling
NODE_OPTIONS="--inspect" nx build my-app

# Build with reduced parallelism
nx build my-app --maxParallel=1
```

## 📊 Monitoring and Reporting

### Build Monitoring
```bash
# Generate build report
nx build my-app --stats-json

# Analyze webpack bundle
nx webpack-bundle-analyzer my-app

# Monitor build cache usage
nx report --verbose

# Track affected changes over time
nx print-affected --base=main~1 --head=main
```

### Team Collaboration
```bash
# Share dependency graph
nx graph --file=dep-graph.html

# Generate project documentation
nx run my-app:compodoc

# Export workspace configuration
nx export --output=workspace-config.json

# Create workspace backup
nx print-affected --all --target=build > build-targets.txt
```

## 🚀 Quick Reference Cheat Sheet

### Daily Development
```bash
# Start development
nx serve my-app                    # Serve React app
nx serve api-server               # Serve Express API

# Code quality
nx lint my-app                    # Lint single project
nx test my-app                    # Test single project
nx format                         # Format all code

# Build
nx build my-app                   # Build single project
nx build my-app --prod            # Production build
```

### Team Development
```bash
# Affected commands
nx affected --target=test         # Test only affected
nx affected --target=build        # Build only affected
nx affected --target=lint         # Lint only affected

# Multiple projects
nx run-many --target=test --all   # Test all projects
nx run-many --target=build --projects=app1,app2
```

### CI/CD Pipeline
```bash
# Typical CI workflow
nx format:check                   # Check formatting
nx affected --target=lint --base=origin/main
nx affected --target=test --base=origin/main --parallel=3
nx affected --target=build --base=origin/main --parallel=3
nx affected --target=e2e --base=origin/main
```

### Troubleshooting
```bash
# Common fixes
nx reset                          # Clear cache
nx report                         # System info
nx graph                          # View dependencies
nx workspace-lint                 # Check workspace structure
```

This comprehensive CLI reference covers all essential Nx commands for efficient development workflow. Bookmark this guide for quick access to the commands you need most frequently.

---

**Previous**: [← Best Practices](./best-practices.md) | **Next**: [Template Examples →](./template-examples.md)