# CI/CD Integration and Project Setup Guide

## Overview

This guide provides comprehensive instructions for integrating E2E testing frameworks into CI/CD pipelines and setting up projects for optimal automated testing workflows. It covers setup strategies for popular platforms and provides templates for immediate implementation.

## Project Setup Strategies

### Framework-Agnostic Project Structure

```
project-root/
├── src/                          # Application source code
├── tests/
│   ├── e2e/                     # E2E test files
│   │   ├── specs/               # Test specifications
│   │   │   ├── auth/            # Authentication tests
│   │   │   ├── user-management/ # User management tests
│   │   │   └── critical-flows/  # Critical business flows
│   │   ├── pages/               # Page Object Models
│   │   ├── fixtures/            # Test data and fixtures
│   │   ├── helpers/             # Test utilities and helpers
│   │   └── config/              # Test configuration files
│   ├── unit/                    # Unit tests
│   └── integration/             # Integration tests
├── .github/
│   └── workflows/               # GitHub Actions workflows
├── docker-compose.test.yml      # Test environment setup
├── package.json
└── README.md
```

### TypeScript Configuration for Testing

```typescript
// tsconfig.test.json
{
  "extends": "./tsconfig.json",
  "compilerOptions": {
    "target": "ES2020",
    "module": "commonjs",
    "lib": ["ES2020", "DOM", "DOM.Iterable"],
    "moduleResolution": "node",
    "allowSyntheticDefaultImports": true,
    "esModuleInterop": true,
    "strict": true,
    "skipLibCheck": true,
    "resolveJsonModule": true,
    "types": ["node", "jest", "@playwright/test", "cypress"]
  },
  "include": [
    "tests/**/*",
    "src/**/*"
  ],
  "exclude": [
    "node_modules",
    "dist",
    "build"
  ]
}
```

### Environment Configuration

```typescript
// tests/config/environment.ts
export interface TestEnvironment {
  baseUrl: string;
  apiUrl: string;
  database: {
    host: string;
    port: number;
    name: string;
  };
  credentials: {
    admin: { username: string; password: string };
    user: { username: string; password: string };
  };
  timeouts: {
    default: number;
    long: number;
    short: number;
  };
}

const environments: Record<string, TestEnvironment> = {
  local: {
    baseUrl: 'http://localhost:3000',
    apiUrl: 'http://localhost:3001/api',
    database: {
      host: 'localhost',
      port: 5432,
      name: 'test_db'
    },
    credentials: {
      admin: { username: 'admin@local.com', password: 'local123' },
      user: { username: 'user@local.com', password: 'local123' }
    },
    timeouts: {
      default: 10000,
      long: 30000,
      short: 5000
    }
  },
  staging: {
    baseUrl: 'https://staging.example.com',
    apiUrl: 'https://api-staging.example.com',
    database: {
      host: 'staging-db.example.com',
      port: 5432,
      name: 'staging_db'
    },
    credentials: {
      admin: { username: process.env.STAGING_ADMIN_USER!, password: process.env.STAGING_ADMIN_PASS! },
      user: { username: process.env.STAGING_USER!, password: process.env.STAGING_USER_PASS! }
    },
    timeouts: {
      default: 15000,
      long: 45000,
      short: 7000
    }
  },
  production: {
    baseUrl: 'https://example.com',
    apiUrl: 'https://api.example.com',
    database: {
      host: 'prod-db.example.com',
      port: 5432,
      name: 'prod_db'
    },
    credentials: {
      admin: { username: process.env.PROD_ADMIN_USER!, password: process.env.PROD_ADMIN_PASS! },
      user: { username: process.env.PROD_USER!, password: process.env.PROD_USER_PASS! }
    },
    timeouts: {
      default: 20000,
      long: 60000,
      short: 10000
    }
  }
};

export function getEnvironment(): TestEnvironment {
  const env = process.env.TEST_ENV || 'local';
  return environments[env] || environments.local;
}
```

## Playwright CI/CD Setup

### Complete Playwright Configuration

```typescript
// playwright.config.ts
import { defineConfig, devices } from '@playwright/test';
import { getEnvironment } from './tests/config/environment';

const env = getEnvironment();

export default defineConfig({
  testDir: './tests/e2e/specs',
  outputDir: './test-results',
  
  // Parallel execution
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 2 : undefined,
  
  // Reporters
  reporter: [
    ['html', { outputFolder: 'playwright-report', open: 'never' }],
    ['junit', { outputFile: 'test-results/results.xml' }],
    ['json', { outputFile: 'test-results/results.json' }],
    process.env.CI ? ['github'] : ['list']
  ],
  
  // Global test settings
  use: {
    baseURL: env.baseUrl,
    
    // Browser settings
    headless: !!process.env.CI,
    viewport: { width: 1280, height: 720 },
    
    // Debugging and artifacts
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
    
    // Network settings
    actionTimeout: env.timeouts.default,
    navigationTimeout: env.timeouts.long,
    
    // Context settings
    ignoreHTTPSErrors: true,
    colorScheme: 'light'
  },
  
  // Test timeout
  timeout: env.timeouts.long,
  expect: {
    timeout: env.timeouts.short
  },
  
  // Projects for different browsers
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
      testMatch: '**/*.spec.ts'
    },
    {
      name: 'firefox',
      use: { ...devices['Desktop Firefox'] },
      testMatch: '**/*.spec.ts'
    },
    {
      name: 'webkit',
      use: { ...devices['Desktop Safari'] },
      testMatch: '**/*.spec.ts'
    },
    {
      name: 'mobile-chrome',
      use: { ...devices['Pixel 5'] },
      testMatch: '**/mobile/*.spec.ts'
    },
    {
      name: 'mobile-safari',
      use: { ...devices['iPhone 12'] },
      testMatch: '**/mobile/*.spec.ts'
    }
  ],
  
  // Web server for testing
  webServer: process.env.CI ? undefined : {
    command: 'npm start',
    url: env.baseUrl,
    reuseExistingServer: !process.env.CI,
    timeout: 120000
  }
});
```

### GitHub Actions for Playwright

```yaml
# .github/workflows/e2e-tests.yml
name: E2E Tests with Playwright

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]
  schedule:
    - cron: '0 6 * * *' # Daily at 6 AM UTC

env:
  NODE_VERSION: '18'
  
jobs:
  e2e-tests:
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        browser: [chromium, firefox, webkit]
        shard: [1/4, 2/4, 3/4, 4/4]
    
    services:
      postgres:
        image: postgres:13
        env:
          POSTGRES_DB: test_db
          POSTGRES_USER: test_user
          POSTGRES_PASSWORD: test_pass
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 5432:5432
    
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
      
      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: 'npm'
      
      - name: Install dependencies
        run: npm ci
      
      - name: Install Playwright browsers
        run: npx playwright install --with-deps ${{ matrix.browser }}
      
      - name: Setup test database
        run: |
          npm run db:migrate
          npm run db:seed:test
        env:
          DATABASE_URL: postgres://test_user:test_pass@localhost:5432/test_db
      
      - name: Build application
        run: npm run build
      
      - name: Start application server
        run: |
          npm start &
          npx wait-on http://localhost:3000 --timeout 60000
        env:
          NODE_ENV: test
          DATABASE_URL: postgres://test_user:test_pass@localhost:5432/test_db
      
      - name: Run E2E tests
        run: npx playwright test --project=${{ matrix.browser }} --shard=${{ matrix.shard }}
        env:
          TEST_ENV: ci
          CI: true
      
      - name: Upload test artifacts
        uses: actions/upload-artifact@v4
        if: failure()
        with:
          name: playwright-report-${{ matrix.browser }}-${{ matrix.shard }}
          path: |
            playwright-report/
            test-results/
          retention-days: 7
      
      - name: Upload coverage reports
        uses: codecov/codecov-action@v3
        if: matrix.browser == 'chromium' && matrix.shard == '1/4'
        with:
          files: ./coverage/lcov.info
          flags: e2e
  
  # Aggregate results from all shards
  test-results:
    if: always()
    needs: e2e-tests
    runs-on: ubuntu-latest
    steps:
      - name: Download all artifacts
        uses: actions/download-artifact@v4
      
      - name: Publish test results
        uses: dorny/test-reporter@v1
        if: success() || failure()
        with:
          name: E2E Test Results
          path: '**/results.xml'
          reporter: java-junit
      
      - name: Comment PR with results
        if: github.event_name == 'pull_request'
        uses: actions/github-script@v7
        with:
          script: |
            const fs = require('fs');
            const path = require('path');
            
            let totalPassed = 0;
            let totalFailed = 0;
            let totalSkipped = 0;
            
            // Aggregate results from all shards
            const resultFiles = fs.readdirSync('.')
              .filter(dir => dir.includes('playwright-report'))
              .map(dir => path.join(dir, 'results.json'))
              .filter(file => fs.existsSync(file));
            
            resultFiles.forEach(file => {
              const results = JSON.parse(fs.readFileSync(file));
              totalPassed += results.passed || 0;
              totalFailed += results.failed || 0;
              totalSkipped += results.skipped || 0;
            });
            
            const body = `## 🎭 E2E Test Results
            
            | Status | Count |
            |--------|-------|
            | ✅ Passed | ${totalPassed} |
            | ❌ Failed | ${totalFailed} |
            | ⏭️ Skipped | ${totalSkipped} |
            
            ${totalFailed > 0 ? '❌ Some tests failed. Check the workflow logs for details.' : '✅ All tests passed!'}`;
            
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: body
            });
```

## Cypress CI/CD Setup

### Cypress Configuration

```typescript
// cypress.config.ts
import { defineConfig } from 'cypress';
import { getEnvironment } from './tests/config/environment';

const env = getEnvironment();

export default defineConfig({
  e2e: {
    baseUrl: env.baseUrl,
    supportFile: 'tests/e2e/support/e2e.ts',
    specPattern: 'tests/e2e/specs/**/*.cy.ts',
    fixturesFolder: 'tests/e2e/fixtures',
    screenshotsFolder: 'test-results/screenshots',
    videosFolder: 'test-results/videos',
    downloadsFolder: 'test-results/downloads',
    
    // Viewport settings
    viewportWidth: 1280,
    viewportHeight: 720,
    
    // Timeouts
    defaultCommandTimeout: env.timeouts.default,
    requestTimeout: env.timeouts.long,
    responseTimeout: env.timeouts.long,
    pageLoadTimeout: env.timeouts.long,
    
    // Retry settings
    retries: {
      runMode: 2,
      openMode: 0
    },
    
    // Video and screenshot settings
    video: false,
    screenshotOnRunFailure: true,
    
    // Security settings
    chromeWebSecurity: false,
    
    setupNodeEvents(on, config) {
      // Environment-specific configuration
      config.env = {
        ...config.env,
        apiUrl: env.apiUrl,
        adminUser: env.credentials.admin.username,
        adminPass: env.credentials.admin.password
      };
      
      // Task definitions
      on('task', {
        seedDatabase() {
          // Database seeding logic
          return null;
        },
        
        cleanDatabase() {
          // Database cleanup logic
          return null;
        },
        
        log(message) {
          console.log(message);
          return null;
        }
      });
      
      // Plugin configurations
      require('cypress-terminal-report/src/installLogsPrinter')(on);
      
      return config;
    },
  },
  
  component: {
    devServer: {
      framework: 'react',
      bundler: 'vite',
    },
    specPattern: 'src/**/*.cy.ts',
    supportFile: 'tests/component/support/component.ts'
  },
  
  // Reporter configuration
  reporter: 'mochawesome',
  reporterOptions: {
    reportDir: 'test-results',
    overwrite: false,
    html: false,
    json: true
  }
});
```

### GitHub Actions for Cypress

```yaml
# .github/workflows/cypress-tests.yml
name: E2E Tests with Cypress

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  cypress-run:
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        browser: [chrome, firefox, edge]
        containers: [1, 2, 3, 4]
    
    services:
      postgres:
        image: postgres:13
        env:
          POSTGRES_DB: test_db
          POSTGRES_USER: test_user
          POSTGRES_PASSWORD: test_pass
        ports:
          - 5432:5432
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
    
    steps:
      - name: Checkout
        uses: actions/checkout@v4
      
      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '18'
          cache: 'npm'
      
      - name: Install dependencies
        run: npm ci
      
      - name: Setup test database
        run: |
          npm run db:migrate
          npm run db:seed:test
        env:
          DATABASE_URL: postgres://test_user:test_pass@localhost:5432/test_db
      
      - name: Build application
        run: npm run build
      
      - name: Cypress run
        uses: cypress-io/github-action@v6
        with:
          start: npm start
          wait-on: 'http://localhost:3000'
          wait-on-timeout: 120
          browser: ${{ matrix.browser }}
          record: true
          parallel: true
          group: 'E2E Tests'
        env:
          CYPRESS_RECORD_KEY: ${{ secrets.CYPRESS_RECORD_KEY }}
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          TEST_ENV: ci
      
      - name: Upload screenshots
        uses: actions/upload-artifact@v4
        if: failure()
        with:
          name: cypress-screenshots-${{ matrix.browser }}-${{ matrix.containers }}
          path: test-results/screenshots
      
      - name: Upload videos
        uses: actions/upload-artifact@v4
        if: failure()
        with:
          name: cypress-videos-${{ matrix.browser }}-${{ matrix.containers }}
          path: test-results/videos
      
      - name: Merge test results
        run: npm run test:merge-reports
      
      - name: Generate HTML report
        run: npm run test:generate-report
      
      - name: Upload test report
        uses: actions/upload-artifact@v4
        with:
          name: cypress-report-${{ matrix.browser }}-${{ matrix.containers }}
          path: test-results/html
```

## Docker Integration

### Multi-Stage Dockerfile for Testing

```dockerfile
# Dockerfile.test
# Stage 1: Base image with dependencies
FROM node:18-alpine AS base
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

# Stage 2: Development dependencies
FROM base AS dev-deps
RUN npm ci

# Stage 3: Build application
FROM dev-deps AS build
COPY . .
RUN npm run build

# Stage 4: Test environment
FROM mcr.microsoft.com/playwright:v1.40.0-jammy AS test
WORKDIR /app

# Install Node.js
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && \
    apt-get install -y nodejs

# Copy application files
COPY --from=dev-deps /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
COPY . .

# Set environment variables
ENV CI=true
ENV NODE_ENV=test

# Install additional dependencies for testing
RUN npx playwright install --with-deps

# Default command
CMD ["npm", "run", "test:e2e"]
```

### Docker Compose for Testing

```yaml
# docker-compose.test.yml
version: '3.8'

services:
  # Test database
  test-db:
    image: postgres:13
    environment:
      POSTGRES_DB: test_db
      POSTGRES_USER: test_user
      POSTGRES_PASSWORD: test_pass
    ports:
      - "5433:5432"
    volumes:
      - test_db_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U test_user -d test_db"]
      interval: 10s
      timeout: 5s
      retries: 5
  
  # Application server
  app:
    build:
      context: .
      dockerfile: Dockerfile.test
      target: build
    ports:
      - "3000:3000"
    environment:
      NODE_ENV: test
      DATABASE_URL: postgres://test_user:test_pass@test-db:5432/test_db
    depends_on:
      test-db:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 10s
      timeout: 5s
      retries: 5
  
  # E2E test runner
  e2e-tests:
    build:
      context: .
      dockerfile: Dockerfile.test
      target: test
    environment:
      NODE_ENV: test
      TEST_ENV: docker
      BASE_URL: http://app:3000
    depends_on:
      app:
        condition: service_healthy
    volumes:
      - ./test-results:/app/test-results
    command: npm run test:e2e
  
  # Cypress test runner (alternative)
  cypress-tests:
    image: cypress/included:latest
    working_dir: /app
    environment:
      CYPRESS_baseUrl: http://app:3000
      TEST_ENV: docker
    depends_on:
      app:
        condition: service_healthy
    volumes:
      - .:/app
      - ./test-results:/app/test-results
    command: npx cypress run

volumes:
  test_db_data:
```

## Cloud CI/CD Platforms

### Azure DevOps Pipeline

```yaml
# azure-pipelines.yml
trigger:
  branches:
    include:
      - main
      - develop

pr:
  branches:
    include:
      - main

pool:
  vmImage: 'ubuntu-latest'

variables:
  nodeVersion: '18.x'
  testResultsDir: '$(System.DefaultWorkingDirectory)/test-results'

stages:
  - stage: Test
    displayName: 'E2E Testing'
    jobs:
      - job: PlaywrightTests
        displayName: 'Playwright E2E Tests'
        strategy:
          matrix:
            Chrome:
              browserName: 'chromium'
            Firefox:
              browserName: 'firefox'
            Safari:
              browserName: 'webkit'
        
        services:
          postgres:
            image: postgres:13
            env:
              POSTGRES_DB: test_db
              POSTGRES_USER: test_user
              POSTGRES_PASSWORD: test_pass
            ports:
              - 5432:5432
        
        steps:
          - task: NodeTool@0
            inputs:
              versionSpec: '$(nodeVersion)'
            displayName: 'Install Node.js'
          
          - script: npm ci
            displayName: 'Install dependencies'
          
          - script: npx playwright install --with-deps $(browserName)
            displayName: 'Install Playwright browsers'
          
          - script: |
              npm run db:migrate
              npm run db:seed:test
            displayName: 'Setup test database'
            env:
              DATABASE_URL: postgres://test_user:test_pass@localhost:5432/test_db
          
          - script: npm run build
            displayName: 'Build application'
          
          - script: |
              npm start &
              npx wait-on http://localhost:3000 --timeout 60000
            displayName: 'Start application'
            env:
              NODE_ENV: test
              DATABASE_URL: postgres://test_user:test_pass@localhost:5432/test_db
          
          - script: npx playwright test --project=$(browserName)
            displayName: 'Run E2E tests'
            env:
              TEST_ENV: azure
              CI: true
          
          - task: PublishTestResults@2
            inputs:
              testResultsFormat: 'JUnit'
              testResultsFiles: '$(testResultsDir)/results.xml'
              testRunTitle: 'E2E Tests - $(browserName)'
            condition: always()
          
          - task: PublishHtmlReport@1
            inputs:
              reportDir: '$(testResultsDir)/playwright-report'
              tabName: 'E2E Test Report'
            condition: always()
          
          - task: PublishBuildArtifacts@1
            inputs:
              pathToPublish: '$(testResultsDir)'
              artifactName: 'test-results-$(browserName)'
            condition: failed()
```

### Jenkins Pipeline

```groovy
// Jenkinsfile
pipeline {
    agent any
    
    environment {
        NODE_VERSION = '18'
        TEST_ENV = 'jenkins'
        DATABASE_URL = 'postgres://test_user:test_pass@postgres:5432/test_db'
    }
    
    stages {
        stage('Setup') {
            parallel {
                stage('Install Dependencies') {
                    steps {
                        script {
                            sh 'nvm use ${NODE_VERSION}'
                            sh 'npm ci'
                        }
                    }
                }
                
                stage('Start Services') {
                    steps {
                        script {
                            sh 'docker-compose -f docker-compose.test.yml up -d test-db'
                            sh 'docker-compose -f docker-compose.test.yml exec -T test-db pg_isready -U test_user'
                        }
                    }
                }
            }
        }
        
        stage('Build') {
            steps {
                sh 'npm run build'
            }
        }
        
        stage('Database Setup') {
            steps {
                sh 'npm run db:migrate'
                sh 'npm run db:seed:test'
            }
        }
        
        stage('Start Application') {
            steps {
                script {
                    sh 'npm start &'
                    sh 'npx wait-on http://localhost:3000 --timeout 60000'
                }
            }
        }
        
        stage('E2E Tests') {
            parallel {
                stage('Playwright - Chrome') {
                    steps {
                        script {
                            sh 'npx playwright install --with-deps chromium'
                            sh 'npx playwright test --project=chromium'
                        }
                    }
                    post {
                        always {
                            publishHTML([
                                allowMissing: false,
                                alwaysLinkToLastBuild: true,
                                keepAll: true,
                                reportDir: 'playwright-report',
                                reportFiles: 'index.html',
                                reportName: 'Playwright Report - Chrome'
                            ])
                        }
                    }
                }
                
                stage('Playwright - Firefox') {
                    steps {
                        script {
                            sh 'npx playwright install --with-deps firefox'
                            sh 'npx playwright test --project=firefox'
                        }
                    }
                }
                
                stage('Cypress Tests') {
                    steps {
                        script {
                            sh 'npx cypress run --browser chrome'
                        }
                    }
                    post {
                        always {
                            publishHTML([
                                allowMissing: false,
                                alwaysLinkToLastBuild: true,
                                keepAll: true,
                                reportDir: 'cypress/reports',
                                reportFiles: 'index.html',
                                reportName: 'Cypress Report'
                            ])
                        }
                    }
                }
            }
        }
    }
    
    post {
        always {
            // Cleanup
            sh 'docker-compose -f docker-compose.test.yml down -v'
            
            // Archive artifacts
            archiveArtifacts artifacts: 'test-results/**/*', allowEmptyArchive: true
            
            // Publish test results
            publishTestResults testResultsPattern: 'test-results/results.xml'
        }
        
        failure {
            // Send notifications
            emailext (
                subject: "E2E Tests Failed: ${env.JOB_NAME} - ${env.BUILD_NUMBER}",
                body: "The E2E tests have failed. Please check the build logs for details.",
                to: "${env.CHANGE_AUTHOR_EMAIL ?: env.DEFAULT_RECIPIENTS}"
            )
        }
    }
}
```

## Performance Optimization in CI/CD

### Caching Strategies

```yaml
# GitHub Actions with advanced caching
- name: Cache dependencies
  uses: actions/cache@v3
  with:
    path: |
      ~/.npm
      ~/.cache/ms-playwright
      node_modules
    key: ${{ runner.os }}-npm-playwright-${{ hashFiles('**/package-lock.json') }}
    restore-keys: |
      ${{ runner.os }}-npm-playwright-
      ${{ runner.os }}-npm-

- name: Cache test artifacts
  uses: actions/cache@v3
  with:
    path: |
      test-results
      playwright-report
    key: test-artifacts-${{ github.sha }}
    restore-keys: test-artifacts-
```

### Parallel Execution Optimization

```typescript
// playwright.config.ts - CI optimization
export default defineConfig({
  // Optimize for CI environment
  workers: process.env.CI ? '50%' : undefined,
  
  // Reduce retries for faster feedback
  retries: process.env.CI ? 1 : 0,
  
  // Optimize timeouts for CI
  timeout: 30000,
  expect: { timeout: 5000 },
  
  use: {
    // Disable slow features in CI
    video: 'retain-on-failure',
    trace: 'retain-on-failure',
    
    // Optimize for headless execution
    launchOptions: {
      args: [
        '--no-sandbox',
        '--disable-setuid-sandbox',
        '--disable-dev-shm-usage',
        '--disable-background-timer-throttling',
        '--disable-backgrounding-occluded-windows',
        '--disable-renderer-backgrounding'
      ]
    }
  }
});
```

## Monitoring and Reporting

### Test Result Aggregation

```typescript
// scripts/aggregate-results.ts
import fs from 'fs';
import path from 'path';

interface TestResult {
  passed: number;
  failed: number;
  skipped: number;
  total: number;
  duration: number;
  browser: string;
  shard?: string;
}

function aggregateTestResults(): void {
  const resultsDir = './test-results';
  const resultFiles = fs.readdirSync(resultsDir)
    .filter(file => file.endsWith('results.json'))
    .map(file => path.join(resultsDir, file));
  
  const aggregatedResults: TestResult[] = [];
  let totalPassed = 0;
  let totalFailed = 0;
  let totalSkipped = 0;
  let totalDuration = 0;
  
  resultFiles.forEach(file => {
    const results = JSON.parse(fs.readFileSync(file, 'utf8'));
    
    const testResult: TestResult = {
      passed: results.passed || 0,
      failed: results.failed || 0,
      skipped: results.skipped || 0,
      total: results.total || 0,
      duration: results.duration || 0,
      browser: results.browser || 'unknown',
      shard: results.shard
    };
    
    aggregatedResults.push(testResult);
    totalPassed += testResult.passed;
    totalFailed += testResult.failed;
    totalSkipped += testResult.skipped;
    totalDuration += testResult.duration;
  });
  
  const summary = {
    overview: {
      totalPassed,
      totalFailed,
      totalSkipped,
      totalTests: totalPassed + totalFailed + totalSkipped,
      totalDuration,
      successRate: totalPassed / (totalPassed + totalFailed) * 100
    },
    breakdown: aggregatedResults
  };
  
  fs.writeFileSync(
    path.join(resultsDir, 'summary.json'),
    JSON.stringify(summary, null, 2)
  );
  
  console.log('Test Results Summary:', summary.overview);
}

aggregateTestResults();
```

### Custom Reporting Dashboard

```typescript
// scripts/generate-dashboard.ts
import fs from 'fs';
import path from 'path';

function generateDashboard(): void {
  const summaryFile = './test-results/summary.json';
  
  if (!fs.existsSync(summaryFile)) {
    console.error('Summary file not found. Run aggregate-results first.');
    return;
  }
  
  const summary = JSON.parse(fs.readFileSync(summaryFile, 'utf8'));
  
  const html = `
<!DOCTYPE html>
<html>
<head>
    <title>E2E Test Dashboard</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .metric { display: inline-block; margin: 10px; padding: 20px; border: 1px solid #ddd; border-radius: 5px; }
        .passed { background-color: #d4edda; }
        .failed { background-color: #f8d7da; }
        .chart-container { width: 400px; height: 400px; margin: 20px; }
    </style>
</head>
<body>
    <h1>E2E Test Results Dashboard</h1>
    
    <div class="metrics">
        <div class="metric passed">
            <h3>Passed Tests</h3>
            <p>${summary.overview.totalPassed}</p>
        </div>
        <div class="metric failed">
            <h3>Failed Tests</h3>
            <p>${summary.overview.totalFailed}</p>
        </div>
        <div class="metric">
            <h3>Success Rate</h3>
            <p>${summary.overview.successRate.toFixed(2)}%</p>
        </div>
        <div class="metric">
            <h3>Total Duration</h3>
            <p>${(summary.overview.totalDuration / 1000).toFixed(2)}s</p>
        </div>
    </div>
    
    <div class="chart-container">
        <canvas id="resultsChart"></canvas>
    </div>
    
    <script>
        const ctx = document.getElementById('resultsChart').getContext('2d');
        new Chart(ctx, {
            type: 'pie',
            data: {
                labels: ['Passed', 'Failed', 'Skipped'],
                datasets: [{
                    data: [${summary.overview.totalPassed}, ${summary.overview.totalFailed}, ${summary.overview.totalSkipped}],
                    backgroundColor: ['#28a745', '#dc3545', '#ffc107']
                }]
            },
            options: {
                responsive: true,
                plugins: {
                    title: {
                        display: true,
                        text: 'Test Results Distribution'
                    }
                }
            }
        });
    </script>
</body>
</html>`;
  
  fs.writeFileSync('./test-results/dashboard.html', html);
  console.log('Dashboard generated: test-results/dashboard.html');
}

generateDashboard();
```

## Citations

1. GitHub. (2024). *GitHub Actions Documentation*. Retrieved from <https://docs.github.com/en/actions>
2. Microsoft. (2024). *Azure DevOps Pipeline Documentation*. Retrieved from <https://docs.microsoft.com/en-us/azure/devops/pipelines/>
3. Jenkins. (2024). *Jenkins Pipeline Documentation*. Retrieved from <https://www.jenkins.io/doc/book/pipeline/>
4. Docker. (2024). *Docker Compose Documentation*. Retrieved from <https://docs.docker.com/compose/>
5. Playwright. (2024). *Continuous Integration Guide*. Retrieved from <https://playwright.dev/docs/ci>
6. Cypress. (2024). *Continuous Integration Documentation*. Retrieved from <https://docs.cypress.io/guides/continuous-integration/introduction>
7. Sauce Labs. (2024). *CI/CD Best Practices for Test Automation*. Retrieved from <https://saucelabs.com/resources/continuous-integration>
8. CircleCI. (2024). *Testing in CI/CD Pipelines*. Retrieved from <https://circleci.com/docs/testing/>
