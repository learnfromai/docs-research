# React/Vite Performance Optimization for First Load Time

A comprehensive guide to optimizing React applications built with Vite for faster first load times that scale as projects grow.

{% hint style="info" %}
**Research Focus**: Performance optimization techniques specifically for React/Vite applications to achieve minimal first load times even as the project scales
{% endhint %}

## Table of Contents

1. [Overview](#overview)
2. [Vite-Specific Optimizations](#vite-specific-optimizations)
3. [React Performance Patterns](#react-performance-patterns)
4. [Bundle Analysis & Monitoring](#bundle-analysis--monitoring)
5. [Code Splitting Strategies](#code-splitting-strategies)
6. [Resource Loading Optimization](#resource-loading-optimization)
7. [Build Configuration](#build-configuration)
8. [Performance Monitoring](#performance-monitoring)
9. [Best Practices Summary](#best-practices-summary)
10. [Related Topics](#related-topics)

## Overview

Modern React applications built with Vite can achieve excellent performance, but require strategic optimization as they scale. This research covers proven techniques to maintain fast first load times regardless of project size.

### Key Performance Metrics

- **First Contentful Paint (FCP)**: < 1.8s
- **Largest Contentful Paint (LCP)**: < 2.5s
- **Cumulative Layout Shift (CLS)**: < 0.1
- **Time to Interactive (TTI)**: < 3.8s
- **First Input Delay (FID)**: < 100ms

## Vite-Specific Optimizations

### 1. Dependency Pre-Bundling

Vite automatically pre-bundles dependencies to improve performance:

```javascript
// vite.config.js
export default defineConfig({
  optimizeDeps: {
    include: [
      // Force pre-bundle large dependencies
      'lodash-es',
      'date-fns',
      // Include dynamically imported dependencies
      'react-router-dom',
    ],
    exclude: [
      // Exclude small, already optimized ESM packages
      '@vueuse/core',
    ]
  }
})
```

**Benefits:**

- Reduces HTTP request waterfall
- Converts CommonJS/UMD to ESM
- Bundles many small modules into single requests

### 2. Build Performance Configuration

```javascript
// vite.config.js
export default defineConfig({
  build: {
    // Use Rolldown for faster builds (experimental)
    rollupOptions: {
      output: {
        // Manual chunking strategy
        manualChunks: {
          'react-vendor': ['react', 'react-dom'],
          'router': ['react-router-dom'],
          'ui-vendor': ['@mui/material', '@emotion/react'],
          'utils': ['lodash-es', 'date-fns']
        }
      }
    },
    // Increase chunk size warning limit for large apps
    chunkSizeWarningLimit: 1000,
    // Enable source maps for bundle analysis
    sourcemap: true
  },
  // Optimize server performance
  server: {
    warmup: {
      clientFiles: [
        './src/App.tsx',
        './src/main.tsx',
        './src/components/Layout.tsx'
      ]
    }
  }
})
```

### 3. Performance Plugins

```javascript
// vite.config.js
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react-swc' // Faster than @vitejs/plugin-react
import { visualizer } from 'rollup-plugin-visualizer'

export default defineConfig({
  plugins: [
    react(), // SWC is faster than Babel
    // Bundle analyzer
    visualizer({
      filename: 'dist/stats.html',
      open: true,
      gzipSize: true,
      brotliSize: true
    })
  ]
})
```

## React Performance Patterns

### 1. Component-Level Code Splitting

```typescript
// Lazy load route components
import { lazy, Suspense } from 'react'
import { Routes, Route } from 'react-router-dom'

const HomePage = lazy(() => import('./pages/HomePage'))
const DashboardPage = lazy(() => import('./pages/DashboardPage'))
const ProfilePage = lazy(() => import('./pages/ProfilePage'))

function App() {
  return (
    <Suspense fallback={<div>Loading...</div>}>
      <Routes>
        <Route path="/" element={<HomePage />} />
        <Route path="/dashboard" element={<DashboardPage />} />
        <Route path="/profile" element={<ProfilePage />} />
      </Routes>
    </Suspense>
  )
}
```

### 2. Feature-Based Code Splitting

```typescript
// Split by feature modules
const AdminModule = lazy(() => 
  import('./features/admin').then(module => ({
    default: module.AdminModule
  }))
)

const ReportsModule = lazy(() =>
  import('./features/reports').then(module => ({
    default: module.ReportsModule
  }))
)

// Component-level splitting for heavy components
const DataVisualization = lazy(() => 
  import('./components/DataVisualization')
)

function Dashboard() {
  return (
    <div>
      <h1>Dashboard</h1>
      <Suspense fallback={<Skeleton />}>
        <DataVisualization />
      </Suspense>
    </div>
  )
}
```

### 3. React 18 Concurrent Features

```typescript
import { useTransition, useDeferredValue, startTransition } from 'react'

function SearchResults({ query }: { query: string }) {
  const [isPending, startTransition] = useTransition()
  const deferredQuery = useDeferredValue(query)
  const [results, setResults] = useState([])

  useEffect(() => {
    // Use transitions for non-urgent updates
    startTransition(() => {
      searchAPI(deferredQuery).then(setResults)
    })
  }, [deferredQuery])

  return (
    <div>
      {isPending && <div>Searching...</div>}
      {results.map(result => (
        <ResultItem key={result.id} {...result} />
      ))}
    </div>
  )
}
```

### 4. Optimize Heavy Operations

```typescript
import { memo, useMemo, useCallback } from 'react'

// Memoize expensive calculations
const ExpensiveComponent = memo(({ data, filters }) => {
  const processedData = useMemo(() => {
    return data
      .filter(filters.filterFn)
      .sort(filters.sortFn)
      .slice(0, 100) // Limit initial render
  }, [data, filters.filterFn, filters.sortFn])

  return (
    <div>
      {processedData.map(item => (
        <ItemComponent key={item.id} item={item} />
      ))}
    </div>
  )
})

// Virtualize large lists
import { FixedSizeList as List } from 'react-window'

function VirtualizedList({ items }) {
  const Row = useCallback(({ index, style }) => (
    <div style={style}>
      <ItemComponent item={items[index]} />
    </div>
  ), [items])

  return (
    <List
      height={600}
      itemCount={items.length}
      itemSize={50}
      width="100%"
    >
      {Row}
    </List>
  )
}
```

## Bundle Analysis & Monitoring

### 1. Bundle Visualization Tools

#### Rollup Plugin Visualizer (Recommended for Vite)

```bash
npm install --save-dev rollup-plugin-visualizer
```

```javascript
// vite.config.js
import { visualizer } from 'rollup-plugin-visualizer'

export default defineConfig({
  plugins: [
    visualizer({
      filename: 'dist/stats.html',
      open: true,
      template: 'treemap', // or 'sunburst', 'network'
      gzipSize: true,
      brotliSize: true
    })
  ]
})
```

#### Vite Bundle Analyzer

```bash
npm install --save-dev vite-bundle-analyzer
```

```javascript
// vite.config.js
import { analyzer } from 'vite-bundle-analyzer'

export default defineConfig({
  plugins: [
    analyzer({
      analyzerMode: 'server',
      openAnalyzer: true,
      reportTitle: 'Bundle Analysis',
      defaultSizes: 'gzip'
    })
  ]
})
```

### 2. Bundle Analysis Best Practices

{% tabs %}
{% tab title="Bundle Monitoring" %}

```bash
# Generate bundle analysis on each build
npm run build && npx vite-bundle-analyzer

# Monitor bundle size changes
npm install --save-dev bundlewatch

```

{% endtab %}

{% tab title="CI/CD Integration" %}

```yaml
# .github/workflows/bundle-size.yml
name: Bundle Size
on: [pull_request]
jobs:
  bundle-size:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - run: npm ci
      - run: npm run build
      - run: npx bundlewatch

```

{% endtab %}
{% endtabs %}

### 3. Bundle Optimization Targets

| Bundle Type | Target Size (Gzipped) | Action Required |
|-------------|----------------------|-----------------|
| Main Bundle | < 100KB | ✅ Optimal |
| Vendor Bundle | < 200KB | ⚠️ Monitor |
| Route Chunks | < 50KB each | ✅ Good |
| Total Initial | < 300KB | 🎯 Target |

## Code Splitting Strategies

### 1. Route-Based Splitting (Primary)

```typescript
// App.tsx - Split by routes first
import { lazy } from 'react'
import { createBrowserRouter } from 'react-router-dom'

const HomePage = lazy(() => import('./pages/HomePage'))
const ProductsPage = lazy(() => import('./pages/ProductsPage'))
const CheckoutPage = lazy(() => import('./pages/CheckoutPage'))

export const router = createBrowserRouter([
  {
    path: '/',
    element: <HomePage />,
  },
  {
    path: '/products',
    element: <ProductsPage />,
  },
  {
    path: '/checkout',
    element: <CheckoutPage />,
  }
])
```

### 2. Feature-Based Splitting

```typescript
// features/dashboard/index.ts
export const DashboardFeature = lazy(() => import('./Dashboard'))
export const AnalyticsFeature = lazy(() => import('./Analytics'))
export const ReportsFeature = lazy(() => import('./Reports'))

// Load features conditionally
function AdminPanel({ userPermissions }) {
  return (
    <div>
      {userPermissions.includes('dashboard') && (
        <Suspense fallback={<Skeleton />}>
          <DashboardFeature />
        </Suspense>
      )}
      {userPermissions.includes('analytics') && (
        <Suspense fallback={<Skeleton />}>
          <AnalyticsFeature />
        </Suspense>
      )}
    </div>
  )
}
```

### 3. Library Splitting

```typescript
// utils/chartLibrary.ts - Split heavy libraries
export const loadChartLibrary = () => {
  return import('chart.js').then(chartjs => {
    // Configure chart.js
    return chartjs
  })
}

// components/Chart.tsx
function Chart({ data }) {
  const [chartLib, setChartLib] = useState(null)
  
  useEffect(() => {
    loadChartLibrary().then(setChartLib)
  }, [])

  if (!chartLib) {
    return <ChartSkeleton />
  }

  return <canvas ref={chartRef} />
}
```

### 4. Error Boundaries for Code Splitting

```typescript
import { ErrorBoundary } from 'react-error-boundary'

function ChunkErrorFallback({ error, resetErrorBoundary }) {
  return (
    <div role="alert">
      <h2>Something went wrong loading this section:</h2>
      <pre>{error.message}</pre>
      <button onClick={resetErrorBoundary}>
        Try again
      </button>
    </div>
  )
}

function App() {
  return (
    <ErrorBoundary
      FallbackComponent={ChunkErrorFallback}
      onError={(error, errorInfo) => {
        console.error('Chunk loading error:', error, errorInfo)
      }}
    >
      <Suspense fallback={<AppSkeleton />}>
        <Routes>
          {/* Your routes */}
        </Routes>
      </Suspense>
    </ErrorBoundary>
  )
}
```

## Resource Loading Optimization

### 1. Preloading Critical Resources

```html
<!-- index.html -->
<head>
  <!-- Preload critical CSS -->
  <link rel="preload" href="/src/styles/critical.css" as="style">
  
  <!-- Preload critical fonts -->
  <link rel="preload" href="/fonts/inter-var.woff2" as="font" type="font/woff2" crossorigin>
  
  <!-- Preload hero image -->
  <link rel="preload" href="/images/hero.webp" as="image">
</head>
```

### 2. Dynamic Preloading

```typescript
// utils/preloader.ts
export function preloadRoute(routePath: string) {
  const routeMap = {
    '/dashboard': () => import('../pages/Dashboard'),
    '/profile': () => import('../pages/Profile'),
    '/settings': () => import('../pages/Settings')
  }

  if (routeMap[routePath]) {
    routeMap[routePath]()
  }
}

// components/Navigation.tsx
function Navigation() {
  const handleMouseEnter = (routePath: string) => {
    // Preload on hover
    preloadRoute(routePath)
  }

  return (
    <nav>
      <Link 
        to="/dashboard" 
        onMouseEnter={() => handleMouseEnter('/dashboard')}
      >
        Dashboard
      </Link>
    </nav>
  )
}
```

### 3. Image Optimization

```typescript
// components/OptimizedImage.tsx
interface OptimizedImageProps {
  src: string
  alt: string
  width?: number
  height?: number
  priority?: boolean
}

function OptimizedImage({ src, alt, width, height, priority }: OptimizedImageProps) {
  const [isLoaded, setIsLoaded] = useState(false)
  const [imageSrc, setImageSrc] = useState('')

  useEffect(() => {
    const img = new Image()
    img.onload = () => {
      setImageSrc(src)
      setIsLoaded(true)
    }
    img.src = src
  }, [src])

  return (
    <div className="image-container">
      {!isLoaded && <div className="image-skeleton" />}
      {imageSrc && (
        <img
          src={imageSrc}
          alt={alt}
          width={width}
          height={height}
          loading={priority ? 'eager' : 'lazy'}
          style={{ opacity: isLoaded ? 1 : 0 }}
        />
      )}
    </div>
  )
}
```

## Build Configuration

### 1. Advanced Vite Configuration

```javascript
// vite.config.js
export default defineConfig({
  build: {
    rollupOptions: {
      output: {
        // Optimize chunking strategy
        manualChunks: (id) => {
          // Vendor chunks
          if (id.includes('node_modules')) {
            if (id.includes('react') || id.includes('react-dom')) {
              return 'react-vendor'
            }
            if (id.includes('lodash') || id.includes('date-fns')) {
              return 'utils-vendor'
            }
            if (id.includes('@mui') || id.includes('emotion')) {
              return 'ui-vendor'
            }
            return 'vendor'
          }
          
          // Feature-based chunks
          if (id.includes('src/features/admin')) {
            return 'admin-feature'
          }
          if (id.includes('src/features/dashboard')) {
            return 'dashboard-feature'
          }
        },
        // Optimize asset names
        chunkFileNames: 'js/[name]-[hash].js',
        entryFileNames: 'js/[name]-[hash].js',
        assetFileNames: (assetInfo) => {
          const info = assetInfo.name.split('.')
          const ext = info[info.length - 1]
          if (/\.(png|jpe?g|gif|svg|webp|ico)$/.test(assetInfo.name)) {
            return `images/[name]-[hash].${ext}`
          }
          if (/\.(css)$/.test(assetInfo.name)) {
            return `css/[name]-[hash].${ext}`
          }
          return `assets/[name]-[hash].${ext}`
        }
      }
    },
    // Target modern browsers for smaller bundles
    target: 'es2020',
    // Enable minification
    minify: 'esbuild',
    // Generate source maps for debugging
    sourcemap: true
  },
  
  // Use native tooling for better performance
  esbuild: {
    target: 'es2020',
    legalComments: 'none'
  },
  
  // CSS optimization
  css: {
    modules: {
      localsConvention: 'camelCase'
    }
  }
})
```

### 2. Environment-Specific Optimization

```javascript
// vite.config.js
export default defineConfig(({ mode }) => {
  const isDev = mode === 'development'
  const isProd = mode === 'production'
  
  return {
    plugins: [
      react(),
      // Only add analyzer in development
      isDev && analyzer({ analyzerMode: 'server' }),
      // Production optimizations
      isProd && visualizer({
        filename: 'dist/stats.html',
        gzipSize: true,
        brotliSize: true
      })
    ].filter(Boolean),
    
    build: {
      // Development: faster builds
      ...(isDev && {
        sourcemap: true,
        minify: false
      }),
      
      // Production: optimized builds
      ...(isProd && {
        sourcemap: false,
        minify: 'esbuild',
        rollupOptions: {
          output: {
            manualChunks: {
              'react-vendor': ['react', 'react-dom'],
              'router-vendor': ['react-router-dom']
            }
          }
        }
      })
    }
  }
})
```

## Performance Monitoring

### 1. Core Web Vitals Monitoring

```typescript
// utils/performance.ts
export function measureWebVitals() {
  // Measure FCP, LCP, FID, CLS
  import('web-vitals').then(({ getCLS, getFID, getFCP, getLCP, getTTFB }) => {
    getCLS(console.log)
    getFID(console.log)
    getFCP(console.log)
    getLCP(console.log)
    getTTFB(console.log)
  })
}

// main.tsx
measureWebVitals()
```

### 2. Bundle Size Monitoring

```javascript
// scripts/bundle-monitor.js
const fs = require('fs')
const path = require('path')
const gzipSize = require('gzip-size')

async function analyzeBundle() {
  const distPath = path.join(__dirname, '../dist')
  const files = fs.readdirSync(distPath)
  
  const jsFiles = files.filter(file => file.endsWith('.js'))
  
  for (const file of jsFiles) {
    const filePath = path.join(distPath, file)
    const content = fs.readFileSync(filePath)
    const originalSize = content.length
    const gzipped = await gzipSize(content)
    
    console.log(`${file}: ${originalSize} bytes (${gzipped} gzipped)`)
  }
}

analyzeBundle()
```

### 3. Performance Budget

```json
// package.json
{
  "bundlewatch": {
    "files": [
      {
        "path": "./dist/js/index-*.js",
        "maxSize": "100kb"
      },
      {
        "path": "./dist/js/vendor-*.js",
        "maxSize": "200kb"
      },
      {
        "path": "./dist/css/*.css",
        "maxSize": "50kb"
      }
    ]
  }
}
```

## Best Practices Summary

### ✅ Do's

1. **Use Route-Based Code Splitting First**

   ```typescript
   const HomePage = lazy(() => import('./pages/HomePage'))
   ```

2. **Implement Progressive Loading**

   ```typescript
   // Load critical content first, defer non-critical
   <Suspense fallback={<Skeleton />}>
     <NonCriticalComponent />
   </Suspense>
   ```

3. **Optimize Bundle Chunks**

   ```javascript
   // Manual chunking for vendors
   manualChunks: {
     'react-vendor': ['react', 'react-dom'],
     'ui-vendor': ['@mui/material']
   }
   ```

4. **Monitor Bundle Size**

   ```bash
   # Regular bundle analysis
   npx vite-bundle-analyzer
   ```

5. **Use React 18 Concurrent Features**

   ```typescript
   const deferredValue = useDeferredValue(expensiveValue)
   ```

### ❌ Don'ts

1. **Don't Over-Split Small Components**
   - Only split components > 50KB
   - Avoid splitting frequently used shared components

2. **Don't Import Entire Libraries**

   ```typescript
   // ❌ Imports entire lodash
   import _ from 'lodash'
   
   // ✅ Tree-shakeable import
   import { debounce } from 'lodash-es'
   ```

3. **Don't Use Barrel Exports for Large Modules**

   ```typescript
   // ❌ Barrel file loads everything
   export * from './heavyModule'
   
   // ✅ Direct imports
   import { specificFunction } from './heavyModule/specificFunction'
   ```

4. **Don't Ignore Bundle Analysis**
   - Run bundle analysis regularly
   - Set up automated bundle size monitoring

### Performance Checklist

- [ ] Route-based code splitting implemented
- [ ] Bundle analysis configured
- [ ] Critical resources preloaded
- [ ] Images optimized and lazy loaded
- [ ] Large libraries split or lazy loaded
- [ ] React.memo used for expensive components
- [ ] useMemo/useCallback for expensive operations
- [ ] Virtual scrolling for large lists
- [ ] Error boundaries for chunk failures
- [ ] Performance monitoring in place
- [ ] Bundle size budgets defined
- [ ] CI/CD bundle size checks enabled

## Related Topics

- [React Performance Patterns](../react-performance-patterns.md)
- [Vite Configuration Guide](../../tools/configurations/vite-advanced-config.md)
- [Bundle Analysis Best Practices](../../tools/comparisons/bundle-analyzers.md)
- [Web Performance Fundamentals](../performance/web-performance-fundamentals.md)

## Citations

1. [Vite Build Guide](https://vitejs.dev/guide/build.html) - Official Vite build documentation
2. [Vite Performance Guide](https://vitejs.dev/guide/performance.html) - Vite performance optimization
3. [React Code Splitting with Suspense](https://web.dev/code-splitting-suspense/) - Web.dev guide on React code splitting
4. [React 18 Features](https://react.dev/blog/2022/03/29/react-v18) - Official React 18 announcement
5. [Preload Critical Assets](https://web.dev/preload-critical-assets/) - Web.dev resource optimization guide
6. [Rollup Plugin Visualizer](https://github.com/btd/rollup-plugin-visualizer) - Bundle visualization tool
7. [Vite Bundle Analyzer](https://www.npmjs.com/package/vite-bundle-analyzer) - Alternative bundle analysis tool

---

## Navigation

- ← Previous: [Modern React Stack](./modern-react-stack.md)
- → Next: [React Performance Patterns](./react-performance-patterns.md)
- ↑ Back to: [Frontend Research](./README.md)
