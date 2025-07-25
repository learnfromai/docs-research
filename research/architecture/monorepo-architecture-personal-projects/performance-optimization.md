# Performance Optimization for Monorepo

## Overview

Performance optimization in monorepos requires careful attention to build times, bundle sizes, runtime performance, and development experience while maintaining the benefits of code sharing and unified tooling.

## Build Performance Optimization

### 1. Nx Caching and Computation Memoization

```typescript
// nx.json - Advanced caching configuration
{
  "tasksRunnerOptions": {
    "default": {
      "runner": "@nx/workspace/tasks-runners/default",
      "options": {
        "cacheableOperations": [
          "build",
          "test",
          "lint",
          "e2e",
          "typecheck",
          "docker-build"
        ],
        "parallel": 3,
        "maxParallel": 8,
        "captureStderr": true,
        "skipNxCache": false,
        "cacheDirectory": ".nx/cache",
        "useDaemonProcess": true
      }
    }
  },
  "targetDefaults": {
    "build": {
      "cache": true,
      "inputs": [
        "default",
        "^default",
        {
          "externalDependencies": ["webpack", "esbuild", "rollup"]
        }
      ],
      "outputs": ["{options.outputPath}"],
      "dependsOn": [
        {
          "target": "build",
          "projects": "dependencies"
        }
      ]
    },
    "test": {
      "cache": true,
      "inputs": [
        "default",
        "^default",
        "{workspaceRoot}/jest.preset.js"
      ],
      "outputs": [
        "{workspaceRoot}/coverage/{projectRoot}",
        "{workspaceRoot}/junit.xml"
      ]
    }
  },
  "namedInputs": {
    "default": [
      "{projectRoot}/**/*",
      "!{projectRoot}/node_modules/**/*",
      "!{projectRoot}/dist/**/*",
      "!{projectRoot}/coverage/**/*"
    ],
    "production": [
      "default",
      "!{projectRoot}/**/*.spec.ts",
      "!{projectRoot}/**/*.test.ts",
      "!{projectRoot}/**/*.stories.ts"
    ]
  }
}
```

### 2. Advanced Build Configuration

```typescript
// tools/webpack/webpack.performance.config.js
const { composePlugins, withNx } = require('@nx/webpack');
const { BundleAnalyzerPlugin } = require('webpack-bundle-analyzer');
const CompressionPlugin = require('compression-webpack-plugin');
const TerserPlugin = require('terser-webpack-plugin');

module.exports = composePlugins(withNx(), (config, { options, context }) => {
  if (options.optimization) {
    // Advanced optimization for production builds
    config.optimization = {
      ...config.optimization,
      usedExports: true,
      sideEffects: false,
      splitChunks: {
        chunks: 'all',
        cacheGroups: {
          vendor: {
            test: /[\\/]node_modules[\\/]/,
            name: 'vendors',
            chunks: 'all',
            priority: 10,
            reuseExistingChunk: true
          },
          shared: {
            test: /[\\/]packages[\\/]shared[\\/]/,
            name: 'shared',
            chunks: 'all',
            priority: 5,
            reuseExistingChunk: true,
            minChunks: 2
          },
          common: {
            name: 'common',
            chunks: 'all',
            priority: 1,
            reuseExistingChunk: true,
            minChunks: 2,
            maxSize: 50000
          }
        }
      },
      minimizer: [
        new TerserPlugin({
          terserOptions: {
            parse: {
              ecma: 8,
            },
            compress: {
              ecma: 5,
              warnings: false,
              comparisons: false,
              inline: 2,
              drop_console: true,
              drop_debugger: true,
              pure_funcs: ['console.log', 'console.debug']
            },
            mangle: {
              safari10: true,
            },
            output: {
              ecma: 5,
              comments: false,
              ascii_only: true,
            },
          },
          parallel: true,
          extractComments: false,
        })
      ]
    };

    // Add compression for production
    config.plugins = config.plugins || [];
    config.plugins.push(
      new CompressionPlugin({
        algorithm: 'gzip',
        test: /\.(js|css|html|svg)$/,
        threshold: 8192,
        minRatio: 0.8
      })
    );
  }

  // Bundle analysis for performance monitoring
  if (process.env.ANALYZE_BUNDLE) {
    config.plugins.push(
      new BundleAnalyzerPlugin({
        analyzerMode: 'static',
        reportFilename: `../../../dist/bundle-reports/${context.projectName}.html`,
        openAnalyzer: false,
        generateStatsFile: true,
        statsFilename: `../../../dist/bundle-reports/${context.projectName}-stats.json`
      })
    );
  }

  return config;
});
```

### 3. Incremental Build Strategy

```typescript
// tools/scripts/incremental-build.ts
import { execSync } from 'child_process';
import { existsSync, readFileSync, writeFileSync } from 'fs';
import { createHash } from 'crypto';

interface BuildCache {
  lastBuild: string;
  projectHashes: Record<string, string>;
  buildOrder: string[];
}

export class IncrementalBuilder {
  private cacheFile = '.nx/incremental-build-cache.json';
  private cache: BuildCache;

  constructor() {
    this.loadCache();
  }

  async buildAffected(): Promise<void> {
    console.log('🔍 Analyzing affected projects...');
    
    const affectedProjects = await this.getAffectedProjects();
    const projectsNeedingRebuild = await this.getProjectsNeedingRebuild(affectedProjects);
    
    if (projectsNeedingRebuild.length === 0) {
      console.log('✅ No projects need rebuilding');
      return;
    }

    console.log(`🔨 Building ${projectsNeedingRebuild.length} projects...`);
    
    // Build in dependency order
    const buildOrder = await this.getBuildOrder(projectsNeedingRebuild);
    
    for (const project of buildOrder) {
      await this.buildProject(project);
      await this.updateProjectHash(project);
    }

    this.saveCache();
    console.log('✅ Incremental build completed');
  }

  private async getAffectedProjects(): Promise<string[]> {
    try {
      const output = execSync('npx nx print-affected --type=app,lib --select=projects', { 
        encoding: 'utf8' 
      });
      return output.split('\n').filter(Boolean);
    } catch (error) {
      console.warn('Could not determine affected projects, building all');
      return await this.getAllProjects();
    }
  }

  private async getProjectsNeedingRebuild(affectedProjects: string[]): Promise<string[]> {
    const projectsNeedingRebuild: string[] = [];

    for (const project of affectedProjects) {
      const currentHash = await this.calculateProjectHash(project);
      const cachedHash = this.cache.projectHashes[project];

      if (currentHash !== cachedHash) {
        projectsNeedingRebuild.push(project);
      }
    }

    return projectsNeedingRebuild;
  }

  private async calculateProjectHash(project: string): Promise<string> {
    try {
      // Get project files hash
      const output = execSync(`find apps/${project} packages/shared -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" | xargs cat | shasum -a 256`, {
        encoding: 'utf8'
      });
      return output.split(' ')[0];
    } catch (error) {
      return Math.random().toString(36);
    }
  }

  private async getBuildOrder(projects: string[]): Promise<string[]> {
    // Simplified dependency resolution
    const dependencyMap = await this.buildDependencyMap(projects);
    return this.topologicalSort(projects, dependencyMap);
  }

  private async buildProject(project: string): Promise<void> {
    console.log(`📦 Building ${project}...`);
    
    const startTime = Date.now();
    
    try {
      execSync(`npx nx build ${project} --configuration=production`, {
        stdio: 'inherit'
      });
      
      const duration = Date.now() - startTime;
      console.log(`✅ Built ${project} in ${duration}ms`);
    } catch (error) {
      console.error(`❌ Failed to build ${project}:`, error);
      throw error;
    }
  }

  private loadCache(): void {
    if (existsSync(this.cacheFile)) {
      try {
        this.cache = JSON.parse(readFileSync(this.cacheFile, 'utf8'));
      } catch (error) {
        this.cache = this.createEmptyCache();
      }
    } else {
      this.cache = this.createEmptyCache();
    }
  }

  private saveCache(): void {
    this.cache.lastBuild = new Date().toISOString();
    writeFileSync(this.cacheFile, JSON.stringify(this.cache, null, 2));
  }

  private createEmptyCache(): BuildCache {
    return {
      lastBuild: '',
      projectHashes: {},
      buildOrder: []
    };
  }
}
```

## Runtime Performance Optimization

### 1. Lazy Loading and Code Splitting

```typescript
// apps/web-pwa/src/app/routing/lazy-routes.tsx
import { lazy, Suspense } from 'react';
import { LoadingSpinner } from '@expense-tracker/ui-components';

// Lazy load feature modules
const ExpensesDashboard = lazy(() => 
  import('../features/expenses/ExpensesDashboard').then(module => ({
    default: module.ExpensesDashboard
  }))
);

const ReportsModule = lazy(() => 
  import('../features/reports/ReportsModule').then(module => ({
    default: module.ReportsModule
  }))
);

const SettingsModule = lazy(() => 
  import('../features/settings/SettingsModule').then(module => ({
    default: module.SettingsModule
  }))
);

// Route component with suspense boundary
export const LazyRoute: React.FC<{ children: React.ReactNode }> = ({ children }) => (
  <Suspense fallback={<LoadingSpinner />}>
    {children}
  </Suspense>
);

// Route configuration with preloading
export const routes = [
  {
    path: '/expenses',
    element: (
      <LazyRoute>
        <ExpensesDashboard />
      </LazyRoute>
    ),
    preload: () => import('../features/expenses/ExpensesDashboard')
  },
  {
    path: '/reports',
    element: (
      <LazyRoute>
        <ReportsModule />
      </LazyRoute>
    ),
    preload: () => import('../features/reports/ReportsModule')
  },
  {
    path: '/settings',
    element: (
      <LazyRoute>
        <SettingsModule />
      </LazyRoute>
    ),
    preload: () => import('../features/settings/SettingsModule')
  }
];

// Preloading utility
export class RoutePreloader {
  private preloadedRoutes = new Set<string>();

  preloadRoute(path: string): void {
    const route = routes.find(r => r.path === path);
    if (route && route.preload && !this.preloadedRoutes.has(path)) {
      route.preload();
      this.preloadedRoutes.add(path);
    }
  }

  preloadOnHover(path: string): void {
    // Preload route when user hovers over link
    setTimeout(() => this.preloadRoute(path), 100);
  }

  preloadCriticalRoutes(): void {
    // Preload most commonly accessed routes
    const criticalRoutes = ['/expenses', '/reports'];
    criticalRoutes.forEach(route => this.preloadRoute(route));
  }
}
```

### 2. Optimized Data Fetching

```typescript
// packages/shared/data-access/src/caching/query-cache.ts
export interface CacheConfig {
  ttl: number; // Time to live in seconds
  maxSize: number; // Maximum cache size
  staleWhileRevalidate: boolean;
}

export class QueryCache {
  private cache = new Map<string, {
    data: any;
    timestamp: number;
    ttl: number;
  }>();

  private config: CacheConfig = {
    ttl: 300, // 5 minutes default
    maxSize: 1000,
    staleWhileRevalidate: true
  };

  async get<T>(
    key: string, 
    fetcher: () => Promise<T>, 
    options?: Partial<CacheConfig>
  ): Promise<T> {
    const cacheKey = this.generateKey(key);
    const cached = this.cache.get(cacheKey);
    const now = Date.now();
    const ttl = (options?.ttl || this.config.ttl) * 1000;

    // Return cached data if fresh
    if (cached && (now - cached.timestamp) < ttl) {
      return cached.data;
    }

    // Stale-while-revalidate pattern
    if (cached && this.config.staleWhileRevalidate) {
      // Return stale data immediately
      const staleData = cached.data;
      
      // Revalidate in background
      this.revalidateInBackground(cacheKey, fetcher, options);
      
      return staleData;
    }

    // Fetch fresh data
    const data = await fetcher();
    this.set(cacheKey, data, options);
    
    return data;
  }

  set<T>(key: string, data: T, options?: Partial<CacheConfig>): void {
    const cacheKey = this.generateKey(key);
    const ttl = options?.ttl || this.config.ttl;

    // Evict oldest entries if cache is full
    if (this.cache.size >= this.config.maxSize) {
      this.evictOldest();
    }

    this.cache.set(cacheKey, {
      data,
      timestamp: Date.now(),
      ttl: ttl * 1000
    });
  }

  invalidate(pattern: string): void {
    const regex = new RegExp(pattern);
    for (const key of this.cache.keys()) {
      if (regex.test(key)) {
        this.cache.delete(key);
      }
    }
  }

  clear(): void {
    this.cache.clear();
  }

  private generateKey(key: string): string {
    return `query:${key}`;
  }

  private async revalidateInBackground<T>(
    key: string, 
    fetcher: () => Promise<T>, 
    options?: Partial<CacheConfig>
  ): Promise<void> {
    try {
      const data = await fetcher();
      this.set(key.replace('query:', ''), data, options);
    } catch (error) {
      console.warn('Background revalidation failed:', error);
    }
  }

  private evictOldest(): void {
    let oldestKey = '';
    let oldestTime = Date.now();

    for (const [key, value] of this.cache.entries()) {
      if (value.timestamp < oldestTime) {
        oldestTime = value.timestamp;
        oldestKey = key;
      }
    }

    if (oldestKey) {
      this.cache.delete(oldestKey);
    }
  }
}

// Usage in service
export class OptimizedExpenseService {
  private queryCache = new QueryCache();

  async getExpenses(userId: string, filters?: ExpenseFilters): Promise<Expense[]> {
    const cacheKey = `expenses:${userId}:${JSON.stringify(filters)}`;
    
    return this.queryCache.get(
      cacheKey,
      () => this.repository.findByUserId(userId, filters),
      { ttl: 60, staleWhileRevalidate: true } // 1 minute cache
    );
  }

  async getExpenseStatistics(userId: string): Promise<ExpenseStatistics> {
    const cacheKey = `stats:${userId}`;
    
    return this.queryCache.get(
      cacheKey,
      () => this.calculateStatistics(userId),
      { ttl: 300 } // 5 minute cache for statistics
    );
  }

  async createExpense(input: CreateExpenseInput): Promise<Expense> {
    const expense = await this.repository.create(input);
    
    // Invalidate related caches
    this.queryCache.invalidate(`expenses:${input.userId}`);
    this.queryCache.invalidate(`stats:${input.userId}`);
    
    return expense;
  }
}
```

### 3. Database Query Optimization

```typescript
// packages/shared/data-access/src/repositories/optimized-expense.repository.ts
export class OptimizedExpenseRepository extends BaseRepository<Expense> {
  async findByUserIdWithPagination(
    userId: string,
    options: PaginationOptions,
    filters?: ExpenseFilters
  ): Promise<PaginatedResponse<Expense>> {
    const queryBuilder = this.createQueryBuilder();
    
    // Base query with proper indexing
    queryBuilder
      .select([
        'e.id',
        'e.user_id',
        'e.amount',
        'e.currency',
        'e.category',
        'e.description',
        'e.date',
        'e.tags',
        'e.created_at'
      ])
      .from('expenses', 'e')
      .where('e.user_id = :userId', { userId })
      .andWhere('e.deleted_at IS NULL'); // Soft delete support

    // Apply filters with proper indexing
    if (filters?.category) {
      queryBuilder.andWhere('e.category = :category', { category: filters.category });
    }

    if (filters?.dateRange) {
      queryBuilder.andWhere('e.date BETWEEN :startDate AND :endDate', {
        startDate: filters.dateRange.start,
        endDate: filters.dateRange.end
      });
    }

    if (filters?.amountRange) {
      queryBuilder.andWhere('e.amount BETWEEN :minAmount AND :maxAmount', {
        minAmount: filters.amountRange.min,
        maxAmount: filters.amountRange.max
      });
    }

    if (filters?.tags && filters.tags.length > 0) {
      queryBuilder.andWhere('e.tags ?| array[:...tags]', { tags: filters.tags });
    }

    // Count query for pagination (optimized)
    const countQuery = queryBuilder.clone().select('COUNT(*)');
    const total = await countQuery.getRawOne().then(result => parseInt(result.count));

    // Apply sorting and pagination
    queryBuilder
      .orderBy(`e.${options.sortBy || 'date'}`, options.sortOrder || 'DESC')
      .limit(options.limit)
      .offset((options.page - 1) * options.limit);

    const expenses = await queryBuilder.getMany();

    return {
      data: expenses,
      pagination: {
        page: options.page,
        limit: options.limit,
        total,
        totalPages: Math.ceil(total / options.limit),
        hasNext: options.page * options.limit < total,
        hasPrev: options.page > 1
      }
    };
  }

  async getExpenseStatistics(userId: string, dateRange?: DateRange): Promise<ExpenseStatistics> {
    // Use database aggregation for better performance
    const query = `
      SELECT 
        COUNT(*) as total_count,
        SUM(amount) as total_amount,
        AVG(amount) as average_amount,
        category,
        DATE_TRUNC('month', date) as month,
        SUM(amount) as monthly_amount,
        COUNT(*) as monthly_count
      FROM expenses 
      WHERE user_id = $1 
        AND deleted_at IS NULL
        ${dateRange ? 'AND date BETWEEN $2 AND $3' : ''}
      GROUP BY category, DATE_TRUNC('month', date)
      ORDER BY month DESC, category
    `;

    const params = dateRange 
      ? [userId, dateRange.start, dateRange.end]
      : [userId];

    const results = await this.connection.query(query, params);
    
    return this.aggregateStatistics(results.rows);
  }

  async bulkCreate(expenses: CreateExpenseInput[]): Promise<Expense[]> {
    // Optimized bulk insert
    const values = expenses.map((expense, index) => {
      const baseIndex = index * 8;
      return `($${baseIndex + 1}, $${baseIndex + 2}, $${baseIndex + 3}, $${baseIndex + 4}, $${baseIndex + 5}, $${baseIndex + 6}, $${baseIndex + 7}, $${baseIndex + 8})`;
    }).join(', ');

    const flatParams = expenses.flatMap(expense => [
      generateId(),
      expense.userId,
      expense.amount,
      expense.currency,
      expense.category,
      expense.description,
      expense.date,
      JSON.stringify(expense.tags || [])
    ]);

    const query = `
      INSERT INTO expenses (id, user_id, amount, currency, category, description, date, tags)
      VALUES ${values}
      RETURNING *
    `;

    const result = await this.connection.query(query, flatParams);
    return result.rows.map(row => this.mapToEntity(row));
  }

  private aggregateStatistics(rows: any[]): ExpenseStatistics {
    let totalAmount = 0;
    let totalCount = 0;
    const categoryBreakdown: Record<string, any> = {};
    const monthlyTrends: any[] = [];

    for (const row of rows) {
      totalAmount += parseFloat(row.total_amount || 0);
      totalCount += parseInt(row.total_count || 0);

      // Category breakdown
      if (!categoryBreakdown[row.category]) {
        categoryBreakdown[row.category] = { amount: 0, count: 0, percentage: 0 };
      }
      categoryBreakdown[row.category].amount += parseFloat(row.total_amount || 0);
      categoryBreakdown[row.category].count += parseInt(row.total_count || 0);

      // Monthly trends
      const monthKey = row.month;
      let monthlyTrend = monthlyTrends.find(t => t.month === monthKey);
      if (!monthlyTrend) {
        monthlyTrend = { month: monthKey, amount: 0, count: 0 };
        monthlyTrends.push(monthlyTrend);
      }
      monthlyTrend.amount += parseFloat(row.monthly_amount || 0);
      monthlyTrend.count += parseInt(row.monthly_count || 0);
    }

    // Calculate percentages
    Object.keys(categoryBreakdown).forEach(category => {
      categoryBreakdown[category].percentage = 
        totalAmount > 0 ? (categoryBreakdown[category].amount / totalAmount) * 100 : 0;
    });

    return {
      totalAmount,
      totalCount,
      averageAmount: totalCount > 0 ? totalAmount / totalCount : 0,
      categoryBreakdown,
      monthlyTrends: monthlyTrends.sort((a, b) => a.month.localeCompare(b.month))
    };
  }
}
```

## Development Performance

### 1. Fast Refresh and Hot Module Replacement

```typescript
// tools/webpack/webpack.dev.config.js
const ReactRefreshWebpackPlugin = require('@pmmmwh/react-refresh-webpack-plugin');

module.exports = {
  mode: 'development',
  devtool: 'eval-cheap-module-source-map',
  
  devServer: {
    hot: true,
    historyApiFallback: true,
    compress: true,
    port: 4200,
    open: false,
    client: {
      overlay: {
        errors: true,
        warnings: false
      }
    }
  },

  module: {
    rules: [
      {
        test: /\.[jt]sx?$/,
        exclude: /node_modules/,
        use: [
          {
            loader: 'babel-loader',
            options: {
              plugins: [
                require.resolve('react-refresh/babel'),
              ].filter(Boolean),
            },
          },
        ],
      },
    ],
  },

  plugins: [
    new ReactRefreshWebpackPlugin({
      overlay: false,
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
    runtimeChunk: true,
  },

  cache: {
    type: 'filesystem',
    buildDependencies: {
      config: [__filename],
    },
    cacheDirectory: '.nx/webpack-cache',
  },
};
```

### 2. TypeScript Performance Optimization

```json
// tsconfig.base.json - Optimized for monorepo
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
    "incremental": true,
    "tsBuildInfoFile": ".nx/tsbuildinfo.json",
    "composite": true,
    "paths": {
      "@expense-tracker/expense-core": ["packages/shared/expense-core/src/index.ts"],
      "@expense-tracker/ui-components": ["packages/shared/ui-components/src/index.ts"],
      "@expense-tracker/api-client": ["packages/shared/api-client/src/index.ts"],
      "@expense-tracker/validation": ["packages/shared/validation/src/index.ts"],
      "@expense-tracker/utils": ["packages/shared/utils/src/index.ts"]
    }
  },
  "exclude": ["node_modules", "tmp"],
  "ts-node": {
    "esm": true,
    "compilerOptions": {
      "module": "ESNext"
    }
  }
}
```

### 3. Jest Performance Configuration

```javascript
// jest.config.js - Optimized for monorepo
module.exports = {
  projects: [
    '<rootDir>/apps/web-pwa',
    '<rootDir>/apps/mobile',
    '<rootDir>/apps/microservices/user-service',
    '<rootDir>/apps/microservices/expense-service',
    '<rootDir>/packages/shared/expense-core',
    '<rootDir>/packages/shared/ui-components',
    '<rootDir>/packages/shared/api-client'
  ],
  
  // Performance optimizations
  maxWorkers: '50%', // Use half of available CPU cores
  cache: true,
  cacheDirectory: '.nx/jest-cache',
  
  // Coverage settings
  collectCoverageFrom: [
    'src/**/*.{ts,tsx}',
    '!src/**/*.d.ts',
    '!src/**/*.stories.{ts,tsx}',
    '!src/**/*.spec.{ts,tsx}',
    '!src/**/index.ts'
  ],
  
  coverageReporters: ['text', 'lcov', 'html'],
  coverageDirectory: 'coverage',
  
  // Module resolution
  moduleNameMapping: {
    '^@expense-tracker/(.*)$': '<rootDir>/packages/shared/$1/src'
  },
  
  // Transform configuration
  transform: {
    '^.+\\.(ts|tsx)$': ['@swc/jest', {
      jsc: {
        target: 'es2020',
        parser: {
          syntax: 'typescript',
          tsx: true,
          decorators: true,
        },
        transform: {
          react: {
            runtime: 'automatic',
          },
        },
      },
    }],
  },
  
  // Setup files
  setupFilesAfterEnv: ['<rootDir>/jest.setup.ts'],
  
  // Test environment
  testEnvironment: 'jsdom',
  
  // Ignore patterns
  testPathIgnorePatterns: [
    '<rootDir>/node_modules/',
    '<rootDir>/dist/',
    '<rootDir>/coverage/'
  ],
  
  // Watch mode optimizations
  watchPlugins: [
    'jest-watch-typeahead/filename',
    'jest-watch-typeahead/testname'
  ]
};
```

## Performance Monitoring

### 1. Build Performance Metrics

```typescript
// tools/scripts/performance-monitor.ts
import { execSync } from 'child_process';
import { writeFileSync } from 'fs';

export interface BuildMetrics {
  timestamp: string;
  totalBuildTime: number;
  projectBuildTimes: Record<string, number>;
  cacheHitRate: number;
  bundleSizes: Record<string, number>;
  memoryUsage: {
    peak: number;
    average: number;
  };
}

export class PerformanceMonitor {
  private metrics: BuildMetrics[] = [];

  async measureBuild(projects: string[]): Promise<BuildMetrics> {
    const startTime = Date.now();
    const projectTimes: Record<string, number> = {};
    
    console.log('📊 Starting performance measurement...');

    // Measure individual project builds
    for (const project of projects) {
      const projectStart = Date.now();
      
      try {
        execSync(`npx nx build ${project} --configuration=production`, {
          stdio: 'pipe'
        });
        
        projectTimes[project] = Date.now() - projectStart;
        console.log(`✅ ${project}: ${projectTimes[project]}ms`);
      } catch (error) {
        console.error(`❌ ${project} build failed`);
        projectTimes[project] = -1;
      }
    }

    const totalBuildTime = Date.now() - startTime;

    // Measure cache hit rate
    const cacheHitRate = await this.calculateCacheHitRate();

    // Measure bundle sizes
    const bundleSizes = await this.measureBundleSizes(projects);

    // Measure memory usage
    const memoryUsage = await this.measureMemoryUsage();

    const metrics: BuildMetrics = {
      timestamp: new Date().toISOString(),
      totalBuildTime,
      projectBuildTimes: projectTimes,
      cacheHitRate,
      bundleSizes,
      memoryUsage
    };

    this.metrics.push(metrics);
    this.saveMetrics();

    return metrics;
  }

  private async calculateCacheHitRate(): Promise<number> {
    try {
      const output = execSync('npx nx report', { encoding: 'utf8' });
      const cacheMatch = output.match(/Cache hit rate: (\d+(?:\.\d+)?)%/);
      return cacheMatch ? parseFloat(cacheMatch[1]) : 0;
    } catch (error) {
      return 0;
    }
  }

  private async measureBundleSizes(projects: string[]): Promise<Record<string, number>> {
    const bundleSizes: Record<string, number> = {};

    for (const project of projects) {
      try {
        const statsPath = `dist/apps/${project}/stats.json`;
        if (require('fs').existsSync(statsPath)) {
          const stats = JSON.parse(require('fs').readFileSync(statsPath, 'utf8'));
          bundleSizes[project] = stats.assets.reduce((total: number, asset: any) => 
            total + asset.size, 0
          );
        }
      } catch (error) {
        bundleSizes[project] = -1;
      }
    }

    return bundleSizes;
  }

  private async measureMemoryUsage(): Promise<{ peak: number; average: number }> {
    const memInfo = process.memoryUsage();
    return {
      peak: memInfo.heapUsed,
      average: memInfo.heapUsed // Simplified for example
    };
  }

  private saveMetrics(): void {
    const metricsFile = 'performance-metrics.json';
    writeFileSync(metricsFile, JSON.stringify(this.metrics, null, 2));
  }

  generateReport(): string {
    if (this.metrics.length === 0) {
      return 'No performance metrics available';
    }

    const latest = this.metrics[this.metrics.length - 1];
    const previous = this.metrics.length > 1 ? this.metrics[this.metrics.length - 2] : null;

    let report = '📊 Performance Report\n';
    report += '===================\n\n';
    
    report += `📅 Timestamp: ${latest.timestamp}\n`;
    report += `⏱️  Total Build Time: ${latest.totalBuildTime}ms\n`;
    
    if (previous) {
      const timeDiff = latest.totalBuildTime - previous.totalBuildTime;
      const changeIcon = timeDiff > 0 ? '📈' : '📉';
      report += `${changeIcon} Change: ${timeDiff > 0 ? '+' : ''}${timeDiff}ms\n`;
    }
    
    report += `🎯 Cache Hit Rate: ${latest.cacheHitRate}%\n`;
    report += `💾 Memory Peak: ${(latest.memoryUsage.peak / 1024 / 1024).toFixed(2)}MB\n\n`;

    report += '📦 Project Build Times:\n';
    Object.entries(latest.projectBuildTimes).forEach(([project, time]) => {
      if (time > 0) {
        report += `  ${project}: ${time}ms\n`;
      }
    });

    report += '\n📏 Bundle Sizes:\n';
    Object.entries(latest.bundleSizes).forEach(([project, size]) => {
      if (size > 0) {
        report += `  ${project}: ${(size / 1024).toFixed(2)}KB\n`;
      }
    });

    return report;
  }
}
```

### 2. Runtime Performance Monitoring

```typescript
// packages/shared/monitoring/src/performance-tracker.ts
export class PerformanceTracker {
  private static instance: PerformanceTracker;
  private metrics: Map<string, number[]> = new Map();

  static getInstance(): PerformanceTracker {
    if (!PerformanceTracker.instance) {
      PerformanceTracker.instance = new PerformanceTracker();
    }
    return PerformanceTracker.instance;
  }

  measureAsync<T>(name: string, fn: () => Promise<T>): Promise<T> {
    const start = performance.now();
    
    return fn().then(
      result => {
        this.recordMetric(name, performance.now() - start);
        return result;
      },
      error => {
        this.recordMetric(`${name}_error`, performance.now() - start);
        throw error;
      }
    );
  }

  measureSync<T>(name: string, fn: () => T): T {
    const start = performance.now();
    try {
      const result = fn();
      this.recordMetric(name, performance.now() - start);
      return result;
    } catch (error) {
      this.recordMetric(`${name}_error`, performance.now() - start);
      throw error;
    }
  }

  private recordMetric(name: string, duration: number): void {
    if (!this.metrics.has(name)) {
      this.metrics.set(name, []);
    }
    
    const measurements = this.metrics.get(name)!;
    measurements.push(duration);
    
    // Keep only last 100 measurements
    if (measurements.length > 100) {
      measurements.shift();
    }
  }

  getMetrics(name: string): {
    count: number;
    average: number;
    min: number;
    max: number;
    p95: number;
  } | null {
    const measurements = this.metrics.get(name);
    if (!measurements || measurements.length === 0) {
      return null;
    }

    const sorted = [...measurements].sort((a, b) => a - b);
    const count = measurements.length;
    const sum = measurements.reduce((a, b) => a + b, 0);

    return {
      count,
      average: sum / count,
      min: sorted[0],
      max: sorted[sorted.length - 1],
      p95: sorted[Math.floor(sorted.length * 0.95)]
    };
  }

  exportMetrics(): Record<string, any> {
    const result: Record<string, any> = {};
    
    for (const [name, _] of this.metrics) {
      result[name] = this.getMetrics(name);
    }
    
    return result;
  }
}

// Usage decorator
export function Measure(name?: string) {
  return function(target: any, propertyName: string, descriptor: PropertyDescriptor) {
    const method = descriptor.value;
    const metricName = name || `${target.constructor.name}.${propertyName}`;

    descriptor.value = function(...args: any[]) {
      const tracker = PerformanceTracker.getInstance();
      
      if (method.constructor.name === 'AsyncFunction') {
        return tracker.measureAsync(metricName, () => method.apply(this, args));
      } else {
        return tracker.measureSync(metricName, () => method.apply(this, args));
      }
    };
  };
}
```

This comprehensive performance optimization strategy ensures your monorepo maintains excellent performance across build times, runtime execution, and development experience while scaling with your project's growth.
