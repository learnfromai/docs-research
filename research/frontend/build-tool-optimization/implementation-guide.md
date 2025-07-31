# Implementation Guide: Frontend Build Tool Setup & Optimization

## 🎯 Overview

Step-by-step implementation guide for setting up and optimizing Webpack, Vite, and Rollup for EdTech applications and modern web development workflows.

## 🚀 Quick Start Setups

### Vite Setup (Recommended for New Projects)

#### 1. Project Initialization
```bash
# Create new Vite project
npm create vite@latest my-edtech-app --template react-ts
cd my-edtech-app
npm install

# Additional EdTech-specific dependencies
npm install -D @vitejs/plugin-react
npm install -D vite-plugin-pwa
npm install -D rollup-plugin-visualizer
npm install -D vite-plugin-eslint
npm install web-vitals
```

#### 2. Vite Configuration (`vite.config.ts`)
```typescript
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import { VitePWA } from 'vite-plugin-pwa'
import { visualizer } from 'rollup-plugin-visualizer'
import eslint from 'vite-plugin-eslint'

export default defineConfig({
  plugins: [
    react(),
    eslint(),
    VitePWA({
      registerType: 'autoUpdate',
      workbox: {
        globPatterns: ['**/*.{js,css,html,ico,png,svg}']
      }
    }),
    visualizer({
      filename: 'dist/stats.html',
      open: true,
      gzipSize: true
    })
  ],
  
  // Performance optimizations
  build: {
    target: 'es2015',
    minify: 'terser',
    terserOptions: {
      compress: {
        drop_console: true,
        drop_debugger: true
      }
    },
    rollupOptions: {
      output: {
        manualChunks: {
          vendor: ['react', 'react-dom'],
          ui: ['@mui/material', '@emotion/react', '@emotion/styled']
        }
      }
    },
    chunkSizeWarningLimit: 1000
  },
  
  // Development optimizations
  server: {
    port: 3000,
    open: true,
    hmr: {
      overlay: false
    }
  },
  
  // Asset optimization
  assetsInclude: ['**/*.md'],
  
  // Path resolution
  resolve: {
    alias: {
      '@': '/src',
      '@components': '/src/components',
      '@utils': '/src/utils',
      '@assets': '/src/assets'
    }
  }
})
```

#### 3. Performance Monitoring Setup
```typescript
// src/utils/performance.ts
import { getCLS, getFID, getFCP, getLCP, getTTFB } from 'web-vitals'

export function reportWebVitals(onPerfEntry?: (metric: any) => void) {
  if (onPerfEntry && onPerfEntry instanceof Function) {
    getCLS(onPerfEntry)
    getFID(onPerfEntry)
    getFCP(onPerfEntry)
    getLCP(onPerfEntry)
    getTTFB(onPerfEntry)
  }
}

// Usage in main.tsx
import { reportWebVitals } from './utils/performance'

// Report performance metrics
reportWebVitals(console.log)
```

### Webpack 5 Setup (Enterprise/Legacy Projects)

#### 1. Project Setup
```bash
# Initialize project
npm init -y
npm install --save-dev webpack webpack-cli webpack-dev-server
npm install --save-dev html-webpack-plugin mini-css-extract-plugin
npm install --save-dev babel-loader @babel/core @babel/preset-react @babel/preset-typescript
npm install --save-dev css-loader sass-loader sass
npm install --save-dev webpack-bundle-analyzer terser-webpack-plugin
npm install --save-dev @typescript-eslint/parser @typescript-eslint/eslint-plugin
```

#### 2. Webpack Configuration (`webpack.config.js`)
```javascript
const path = require('path')
const HtmlWebpackPlugin = require('html-webpack-plugin')
const MiniCssExtractPlugin = require('mini-css-extract-plugin')
const TerserPlugin = require('terser-webpack-plugin')
const { BundleAnalyzerPlugin } = require('webpack-bundle-analyzer')

const isProduction = process.env.NODE_ENV === 'production'

module.exports = {
  mode: isProduction ? 'production' : 'development',
  
  entry: {
    app: './src/index.tsx'
  },
  
  output: {
    path: path.resolve(__dirname, 'dist'),
    filename: isProduction 
      ? '[name].[contenthash:8].js' 
      : '[name].js',
    chunkFilename: isProduction 
      ? '[name].[contenthash:8].chunk.js' 
      : '[name].chunk.js',
    clean: true,
    publicPath: '/'
  },
  
  resolve: {
    extensions: ['.tsx', '.ts', '.js', '.jsx'],
    alias: {
      '@': path.resolve(__dirname, 'src'),
      '@components': path.resolve(__dirname, 'src/components'),
      '@utils': path.resolve(__dirname, 'src/utils'),
      '@assets': path.resolve(__dirname, 'src/assets')
    }
  },
  
  module: {
    rules: [
      {
        test: /\.(ts|tsx)$/,
        exclude: /node_modules/,
        use: {
          loader: 'babel-loader',
          options: {
            presets: [
              '@babel/preset-env',
              '@babel/preset-react',
              '@babel/preset-typescript'
            ]
          }
        }
      },
      {
        test: /\.css$/,
        use: [
          isProduction ? MiniCssExtractPlugin.loader : 'style-loader',
          'css-loader'
        ]
      },
      {
        test: /\.scss$/,
        use: [
          isProduction ? MiniCssExtractPlugin.loader : 'style-loader',
          'css-loader',
          'sass-loader'
        ]
      },
      {
        test: /\.(png|jpe?g|gif|svg|webp)$/i,
        type: 'asset',
        parser: {
          dataUrlCondition: {
            maxSize: 8 * 1024 // 8kb
          }
        },
        generator: {
          filename: 'assets/images/[name].[hash:8][ext]'
        }
      }
    ]
  },
  
  plugins: [
    new HtmlWebpackPlugin({
      template: './public/index.html',
      minify: isProduction
    }),
    
    ...(isProduction ? [
      new MiniCssExtractPlugin({
        filename: '[name].[contenthash:8].css',
        chunkFilename: '[name].[contenthash:8].chunk.css'
      })
    ] : []),
    
    ...(process.env.ANALYZE ? [
      new BundleAnalyzerPlugin({
        analyzerMode: 'static',
        openAnalyzer: false
      })
    ] : [])
  ],
  
  optimization: {
    minimize: isProduction,
    minimizer: [
      new TerserPlugin({
        terserOptions: {
          compress: {
            drop_console: isProduction,
            drop_debugger: isProduction
          }
        }
      })
    ],
    
    splitChunks: {
      chunks: 'all',
      cacheGroups: {
        vendor: {
          test: /[\\/]node_modules[\\/]/,
          name: 'vendors',
          chunks: 'all',
          priority: 20
        },
        common: {
          name: 'common',
          minChunks: 2,
          chunks: 'all',
          priority: 10,
          reuseExistingChunk: true
        }
      }
    },
    
    runtimeChunk: {
      name: 'runtime'
    }
  },
  
  devServer: {
    port: 3000,
    hot: true,
    open: true,
    historyApiFallback: true,
    compress: true
  },
  
  devtool: isProduction ? 'source-map' : 'eval-source-map'
}
```

### Rollup Setup (Library Development)

#### 1. Library Project Setup
```bash
# Initialize library project
npm init -y
npm install --save-dev rollup
npm install --save-dev @rollup/plugin-node-resolve @rollup/plugin-commonjs
npm install --save-dev @rollup/plugin-typescript rollup-plugin-terser
npm install --save-dev rollup-plugin-postcss rollup-plugin-peer-deps-external
npm install --save-dev typescript tslib
```

#### 2. Rollup Configuration (`rollup.config.js`)
```javascript
import resolve from '@rollup/plugin-node-resolve'
import commonjs from '@rollup/plugin-commonjs'
import typescript from '@rollup/plugin-typescript'
import { terser } from 'rollup-plugin-terser'
import postcss from 'rollup-plugin-postcss'
import peerDepsExternal from 'rollup-plugin-peer-deps-external'
import { visualizer } from 'rollup-plugin-visualizer'

const packageJson = require('./package.json')

export default {
  input: 'src/index.ts',
  
  output: [
    {
      file: packageJson.main,
      format: 'cjs',
      sourcemap: true
    },
    {
      file: packageJson.module,
      format: 'esm',
      sourcemap: true
    },
    {
      file: 'dist/index.umd.js',
      format: 'umd',
      name: 'EdTechComponents',
      sourcemap: true,
      globals: {
        react: 'React',
        'react-dom': 'ReactDOM'
      }
    }
  ],
  
  plugins: [
    peerDepsExternal(),
    
    resolve({
      browser: true,
      preferBuiltins: false
    }),
    
    commonjs(),
    
    typescript({
      tsconfig: './tsconfig.json',
      declaration: true,
      declarationDir: './dist/types'
    }),
    
    postcss({
      extract: true,
      minimize: true
    }),
    
    terser({
      compress: {
        drop_console: true,
        drop_debugger: true
      }
    }),
    
    visualizer({
      filename: 'dist/bundle-analysis.html',
      open: false
    })
  ],
  
  external: ['react', 'react-dom']
}
```

## 🎯 EdTech-Specific Optimizations

### 1. Progressive Loading Implementation

#### Vite + React Implementation
```typescript
// src/components/LazyLessonContent.tsx
import { lazy, Suspense } from 'react'
import { LoadingSpinner } from './LoadingSpinner'

const LessonVideo = lazy(() => import('./LessonVideo'))
const InteractiveQuiz = lazy(() => import('./InteractiveQuiz'))
const StudyMaterials = lazy(() => import('./StudyMaterials'))

export function LazyLessonContent({ lessonType }: { lessonType: string }) {
  const renderComponent = () => {
    switch (lessonType) {
      case 'video':
        return <LessonVideo />
      case 'quiz':
        return <InteractiveQuiz />
      case 'materials':
        return <StudyMaterials />
      default:
        return <div>Unknown lesson type</div>
    }
  }

  return (
    <Suspense fallback={<LoadingSpinner />}>
      {renderComponent()}
    </Suspense>
  )
}

// Route-based code splitting
const HomePage = lazy(() => import('../pages/HomePage'))
const LessonPage = lazy(() => import('../pages/LessonPage'))
const QuizPage = lazy(() => import('../pages/QuizPage'))
```

### 2. Asset Optimization Strategies

#### Image Optimization (Vite)
```typescript
// vite.config.ts - Image optimization plugin
import { defineConfig } from 'vite'
import { imageOptimize } from 'vite-plugin-imagemin'

export default defineConfig({
  plugins: [
    imageOptimize({
      gifsicle: { optimizationLevel: 7 },
      mozjpeg: { quality: 80 },
      optipng: { optimizationLevel: 7 },
      pngquant: {
        quality: [0.65, 0.8],
        speed: 4
      },
      svgo: {
        plugins: [
          { name: 'removeViewBox', active: false },
          { name: 'removeEmptyAttrs', active: false }
        ]
      }
    })
  ]
})

// Progressive image loading component
export function ProgressiveImage({ 
  src, 
  placeholder, 
  alt, 
  className 
}: ProgressiveImageProps) {
  const [imageSrc, setImageSrc] = useState(placeholder)
  const [imageRef, setImageRef] = useState<HTMLImageElement>()

  useEffect(() => {
    const img = new Image()
    img.src = src
    img.onload = () => {
      setImageSrc(src)
    }
    setImageRef(img)
  }, [src])

  return (
    <img
      src={imageSrc}
      alt={alt}
      className={className}
      loading="lazy"
      decoding="async"
    />
  )
}
```

### 3. Performance Monitoring Integration

#### Core Web Vitals Tracking
```typescript
// src/utils/analytics.ts
import { getCLS, getFID, getFCP, getLCP, getTTFB } from 'web-vitals'

interface PerformanceMetric {
  name: string
  value: number
  rating: 'good' | 'needs-improvement' | 'poor'
  timestamp: number
}

class PerformanceTracker {
  private metrics: PerformanceMetric[] = []

  init() {
    getCLS(this.handleMetric.bind(this))
    getFID(this.handleMetric.bind(this))
    getFCP(this.handleMetric.bind(this))
    getLCP(this.handleMetric.bind(this))
    getTTFB(this.handleMetric.bind(this))
  }

  private handleMetric(metric: any) {
    const performanceMetric: PerformanceMetric = {
      name: metric.name,
      value: metric.value,
      rating: metric.rating,
      timestamp: Date.now()
    }

    this.metrics.push(performanceMetric)
    
    // Send to analytics service
    this.sendToAnalytics(performanceMetric)
    
    // Log poor performance
    if (metric.rating === 'poor') {
      console.warn(`Poor ${metric.name} performance:`, metric.value)
    }
  }

  private sendToAnalytics(metric: PerformanceMetric) {
    // Implementation for your analytics service
    // Google Analytics, Mixpanel, custom endpoint, etc.
  }

  getMetrics() {
    return this.metrics
  }
}

export const performanceTracker = new PerformanceTracker()
```

## 🔧 Advanced Configuration Examples

### 1. Multi-Environment Build Setup

#### Environment-specific Vite Configuration
```typescript
// vite.config.ts
import { defineConfig, loadEnv } from 'vite'

export default defineConfig(({ command, mode }) => {
  const env = loadEnv(mode, process.cwd(), '')
  
  const baseConfig = {
    // Common configuration
    plugins: [react()],
    resolve: {
      alias: {
        '@': '/src'
      }
    }
  }

  if (mode === 'development') {
    return {
      ...baseConfig,
      server: {
        port: 3000,
        proxy: {
          '/api': {
            target: env.VITE_API_BASE_URL || 'http://localhost:8000',
            changeOrigin: true
          }
        }
      }
    }
  }

  if (mode === 'staging') {
    return {
      ...baseConfig,
      base: '/staging/',
      build: {
        sourcemap: true,
        minify: 'terser'
      }
    }
  }

  if (mode === 'production') {
    return {
      ...baseConfig,
      build: {
        sourcemap: false,
        minify: 'terser',
        rollupOptions: {
          output: {
            manualChunks: {
              vendor: ['react', 'react-dom'],
              ui: ['@mui/material']
            }
          }
        }
      }
    }
  }

  return baseConfig
})
```

### 2. Package.json Scripts Setup
```json
{
  "scripts": {
    "dev": "vite",
    "build": "tsc && vite build",
    "build:staging": "tsc && vite build --mode staging",
    "build:analyze": "tsc && vite build --mode production && npx vite-bundle-analyzer dist/stats.html",
    "preview": "vite preview",
    "test": "vitest",
    "test:coverage": "vitest run --coverage",
    "lint": "eslint src --ext ts,tsx --report-unused-disable-directives --max-warnings 0",
    "lint:fix": "eslint src --ext ts,tsx --fix",
    "type-check": "tsc --noEmit",
    "perf:audit": "lighthouse http://localhost:3000 --output=json --output=html --output-path=./reports/lighthouse",
    "perf:build-size": "npm run build && du -sh dist/*"
  }
}
```

## 📱 Mobile & Network Optimization

### 1. Progressive Web App Setup
```typescript
// vite.config.ts - PWA Configuration
import { VitePWA } from 'vite-plugin-pwa'

export default defineConfig({
  plugins: [
    VitePWA({
      registerType: 'autoUpdate',
      includeAssets: ['favicon.ico', 'apple-touch-icon.png', 'masked-icon.svg'],
      manifest: {
        name: 'Philippine Licensure Exam Prep',
        short_name: 'ExamPrep',
        description: 'Comprehensive exam preparation for Philippine professional licensure',
        theme_color: '#ffffff',
        background_color: '#ffffff',
        display: 'standalone',
        scope: '/',
        start_url: '/',
        icons: [
          {
            src: 'pwa-192x192.png',
            sizes: '192x192',
            type: 'image/png'
          },
          {
            src: 'pwa-512x512.png',
            sizes: '512x512',
            type: 'image/png'
          }
        ]
      },
      workbox: {
        runtimeCaching: [
          {
            urlPattern: /^https:\/\/api\.examprep\.ph\//,
            handler: 'CacheFirst',
            options: {
              cacheName: 'api-cache',
              expiration: {
                maxEntries: 100,
                maxAgeSeconds: 60 * 60 * 24 // 24 hours
              }
            }
          }
        ]
      }
    })
  ]
})
```

### 2. Network-Aware Loading
```typescript
// src/hooks/useNetworkAware.ts
import { useState, useEffect } from 'react'

interface NetworkState {
  online: boolean
  effectiveType: string
  saveData: boolean
}

export function useNetworkAware() {
  const [networkState, setNetworkState] = useState<NetworkState>({
    online: navigator.onLine,
    effectiveType: (navigator as any).connection?.effectiveType || 'unknown',
    saveData: (navigator as any).connection?.saveData || false
  })

  useEffect(() => {
    const updateNetworkState = () => {
      setNetworkState({
        online: navigator.onLine,
        effectiveType: (navigator as any).connection?.effectiveType || 'unknown',
        saveData: (navigator as any).connection?.saveData || false
      })
    }

    window.addEventListener('online', updateNetworkState)
    window.addEventListener('offline', updateNetworkState)
    
    if ((navigator as any).connection) {
      (navigator as any).connection.addEventListener('change', updateNetworkState)
    }

    return () => {
      window.removeEventListener('online', updateNetworkState)
      window.removeEventListener('offline', updateNetworkState)
      if ((navigator as any).connection) {
        (navigator as any).connection.removeEventListener('change', updateNetworkState)
      }
    }
  }, [])

  return networkState
}

// Usage in component
function AdaptiveContent() {
  const { effectiveType, saveData } = useNetworkAware()
  
  const shouldLoadHighQuality = 
    effectiveType === '4g' && !saveData
  
  return (
    <div>
      {shouldLoadHighQuality ? (
        <HighQualityVideoPlayer />
      ) : (
        <LightweightContentPlayer />
      )}
    </div>
  )
}
```

## ✅ Verification & Testing

### 1. Performance Testing Script
```bash
#!/bin/bash
# scripts/performance-test.sh

echo "🚀 Starting performance tests..."

# Build the project
npm run build

# Start preview server in background
npm run preview &
SERVER_PID=$!

# Wait for server to start
sleep 5

# Run Lighthouse audit
npx lighthouse http://localhost:4173 \
  --output=json \
  --output=html \
  --output-path=./reports/lighthouse-$(date +%Y%m%d-%H%M%S)

# Bundle size analysis
echo "📦 Bundle size analysis:"
du -sh dist/*

# Kill preview server
kill $SERVER_PID

echo "✅ Performance tests completed!"
```

### 2. Build Verification Checklist
```typescript
// scripts/build-verification.ts
import fs from 'fs'
import path from 'path'

interface BuildMetrics {
  bundleSize: number
  chunkCount: number
  hasSourceMaps: boolean
  hasServiceWorker: boolean
}

function analyzeBuild(): BuildMetrics {
  const distPath = path.join(process.cwd(), 'dist')
  const files = fs.readdirSync(distPath)
  
  const jsFiles = files.filter(f => f.endsWith('.js'))
  const mapFiles = files.filter(f => f.endsWith('.map'))
  const swFile = files.find(f => f.includes('sw.js'))
  
  const totalSize = jsFiles.reduce((total, file) => {
    const stats = fs.statSync(path.join(distPath, file))
    return total + stats.size
  }, 0)

  return {
    bundleSize: totalSize,
    chunkCount: jsFiles.length,
    hasSourceMaps: mapFiles.length > 0,
    hasServiceWorker: !!swFile
  }
}

const metrics = analyzeBuild()
console.log('📊 Build Analysis:', metrics)

// Assertions
if (metrics.bundleSize > 1024 * 1024) { // 1MB
  console.warn('⚠️  Bundle size exceeds 1MB')
}

if (metrics.chunkCount < 3) {
  console.warn('⚠️  Consider implementing more code splitting')
}

console.log('✅ Build verification completed!')
```

---

**Navigation**
- ← Back to: [Executive Summary](./executive-summary.md)
- → Next: [Best Practices](./best-practices.md)
- → Related: [Template Examples](./template-examples.md)