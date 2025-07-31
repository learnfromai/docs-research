# Webpack Optimization: Advanced Configuration & Performance

## 🎯 Overview

Advanced Webpack 5 optimization techniques, configuration patterns, and performance strategies specifically tailored for EdTech applications, enterprise systems, and complex frontend architectures.

## ⚡ Core Performance Optimizations

### 1. Build Performance Optimization

#### Persistent Caching Strategy
```javascript
// webpack.config.js - Advanced caching configuration
const path = require('path')

module.exports = {
  cache: {
    type: 'filesystem',
    cacheDirectory: path.resolve(__dirname, '.webpack-cache'),
    buildDependencies: {
      config: [__filename],
      // Include package.json to invalidate on dependency changes
      dependencies: ['package.json']
    },
    // Cache compression for faster disk I/O
    compression: 'gzip',
    // Cache versioning
    version: '1.0'
  },
  
  // Parallel processing optimization
  optimization: {
    minimize: true,
    minimizer: [
      new TerserPlugin({
        parallel: true,
        terserOptions: {
          compress: {
            drop_console: process.env.NODE_ENV === 'production',
            drop_debugger: true,
            pure_funcs: ['console.log', 'console.info']
          }
        }
      })
    ]
  }
}
```

#### Module Resolution Optimization
```javascript
// Optimized resolve configuration
module.exports = {
  resolve: {
    // Reduce resolve attempts
    extensions: ['.tsx', '.ts', '.js', '.jsx'],
    
    // Optimize module resolution
    modules: [
      path.resolve(__dirname, 'src'),
      'node_modules'
    ],
    
    // Alias for faster resolution
    alias: {
      '@': path.resolve(__dirname, 'src'),
      '@components': path.resolve(__dirname, 'src/components'),
      '@utils': path.resolve(__dirname, 'src/utils'),
      '@hooks': path.resolve(__dirname, 'src/hooks'),
      '@services': path.resolve(__dirname, 'src/services'),
      // Replace heavy libraries with lighter alternatives in development
      'react-dom$': process.env.NODE_ENV === 'development' 
        ? '@hot-loader/react-dom' 
        : 'react-dom'
    },
    
    // Symlinks optimization
    symlinks: false,
    
    // Reduce file system calls
    cacheWithContext: false
  }
}
```

### 2. Advanced Code Splitting Strategies

#### Feature-Based Splitting for EdTech
```javascript
// Advanced code splitting for educational platform
module.exports = {
  optimization: {
    splitChunks: {
      chunks: 'all',
      cacheGroups: {
        // React and core libraries
        react: {
          test: /[\\/]node_modules[\\/](react|react-dom|react-router)[\\/]/,
          name: 'react',
          chunks: 'all',
          priority: 40,
          enforce: true
        },
        
        // UI framework chunk
        ui: {
          test: /[\\/]node_modules[\\/](@mui|@emotion|styled-components)[\\/]/,
          name: 'ui',
          chunks: 'all',
          priority: 35
        },
        
        // Math rendering libraries (EdTech specific)
        math: {
          test: /[\\/]node_modules[\\/](mathjax|katex)[\\/]/,
          name: 'math',
          chunks: 'all',
          priority: 30
        },
        
        // Media handling libraries
        media: {
          test: /[\\/]node_modules[\\/](video\.js|hls\.js|wavesurfer\.js)[\\/]/,
          name: 'media',
          chunks: 'all',
          priority: 25
        },
        
        // Feature-based chunks
        lessons: {
          test: /[\\/]src[\\/]features[\\/]lessons[\\/]/,
          name: 'lessons',
          chunks: 'all',
          priority: 20,
          minChunks: 1
        },
        
        quiz: {
          test: /[\\/]src[\\/]features[\\/]quiz[\\/]/,
          name: 'quiz',
          chunks: 'all',
          priority: 20,
          minChunks: 1
        },
        
        analytics: {
          test: /[\\/]src[\\/]features[\\/]analytics[\\/]/,
          name: 'analytics',
          chunks: 'all',
          priority: 20,
          minChunks: 1
        },
        
        // Shared utilities
        utils: {
          test: /[\\/]src[\\/](utils|helpers|hooks)[\\/]/,
          name: 'utils',
          chunks: 'all',
          priority: 15,
          minChunks: 2
        },
        
        // Vendor fallback
        vendor: {
          test: /[\\/]node_modules[\\/]/,
          name: 'vendor',
          chunks: 'all',
          priority: 10
        }
      }
    },
    
    // Runtime chunk optimization
    runtimeChunk: {
      name: entrypoint => `runtime-${entrypoint.name}`
    }
  }
}
```

#### Dynamic Import Optimization
```typescript
// EdTech-specific lazy loading patterns
class ComponentLoader {
  // Lesson content lazy loading
  static LessonContent = lazy(() => 
    import('./components/LessonContent').then(module => ({
      default: module.LessonContent
    }))
  )
  
  // Quiz engine with preloading
  static QuizEngine = lazy(() => {
    const componentImport = import('./components/QuizEngine')
    
    // Preload related resources
    import('./components/QuizResults')
    import('./utils/quizAnalytics')
    
    return componentImport.then(module => ({
      default: module.QuizEngine
    }))
  })
  
  // Progressive enhancement for slow connections
  static InteractiveContent = lazy(() => {
    const connection = (navigator as any).connection
    
    if (connection && connection.effectiveType === '2g') {
      // Load lightweight version for 2G
      return import('./components/LightweightContent')
    }
    
    // Load full interactive version
    return import('./components/InteractiveContent')
  })
}
```

### 3. Asset Optimization Strategies

#### Advanced Image Optimization
```javascript
// webpack.config.js - Image optimization
const ImageMinimizerPlugin = require('image-minimizer-webpack-plugin')

module.exports = {
  module: {
    rules: [
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
        },
        use: [
          {
            loader: 'responsive-loader',
            options: {
              adapter: require('responsive-loader/sharp'),
              sizes: [320, 640, 960, 1200, 1800, 2400],
              placeholder: true,
              placeholderSize: 40,
              // Generate WebP versions
              format: 'webp',
              quality: 85
            }
          }
        ]
      }
    ]
  },
  
  plugins: [
    new ImageMinimizerPlugin({
      minimizer: {
        implementation: ImageMinimizerPlugin.sharpMinify,
        options: {
          encodeOptions: {
            jpeg: { quality: 85, progressive: true },
            png: { compressionLevel: 9, progressive: true },
            webp: { quality: 85 }
          }
        }
      },
      
      generator: [
        {
          type: 'asset',
          preset: 'webp-custom-name',
          implementation: ImageMinimizerPlugin.sharpGenerate,
          options: {
            encodeOptions: {
              webp: { quality: 85 }
            }
          }
        }
      ]
    })
  ]
}
```

#### Font Optimization
```javascript
// Font loading optimization
module.exports = {
  module: {
    rules: [
      {
        test: /\.(woff|woff2|eot|ttf|otf)$/i,
        type: 'asset/resource',
        generator: {
          filename: 'assets/fonts/[name].[hash:8][ext]'
        }
      }
    ]
  },
  
  plugins: [
    new HtmlWebpackPlugin({
      template: './src/index.html',
      minify: {
        removeComments: true,
        collapseWhitespace: true
      },
      // Inject font preload links
      templateParameters: {
        fontPreloads: [
          '<link rel="preload" href="/assets/fonts/Inter-Regular.woff2" as="font" type="font/woff2" crossorigin>',
          '<link rel="preload" href="/assets/fonts/Inter-Medium.woff2" as="font" type="font/woff2" crossorigin>'
        ].join('\n')
      }
    })
  ]
}
```

## 🚀 Development Experience Optimization

### 1. Fast Development Server Setup

#### Optimized DevServer Configuration
```javascript
module.exports = {
  devServer: {
    port: 3000,
    host: '0.0.0.0', // Allow external connections
    
    // Hot reloading optimization
    hot: true,
    liveReload: false, // Disable in favor of HMR
    
    // Faster builds in development
    devMiddleware: {
      writeToDisk: false,
      stats: 'errors-warnings'
    },
    
    // Compression for faster loading
    compress: true,
    
    // History API fallback for SPA
    historyApiFallback: {
      disableDotRule: true,
      // Custom fallbacks for different routes
      rewrites: [
        { from: /^\/lesson\/.*$/, to: '/index.html' },
        { from: /^\/quiz\/.*$/, to: '/index.html' },
        { from: /^\/admin\/.*$/, to: '/index.html' }
      ]
    },
    
    // Proxy API calls
    proxy: {
      '/api': {
        target: process.env.API_BASE_URL || 'http://localhost:8000',
        changeOrigin: true,
        pathRewrite: {
          '^/api': ''
        }
      }
    },
    
    // Client configuration
    client: {
      overlay: {
        errors: true,
        warnings: false
      },
      progress: true
    }
  }
}
```

### 2. Advanced TypeScript Integration

#### Optimized TypeScript Configuration
```javascript
// webpack.config.js - TypeScript optimization
module.exports = {
  module: {
    rules: [
      {
        test: /\.tsx?$/,
        exclude: /node_modules/,
        use: [
          {
            loader: 'ts-loader',
            options: {
              // Speed up compilation
              transpileOnly: true,
              experimentalWatchApi: true,
              // Use project references for faster builds
              projectReferences: true,
              // Compiler options override
              compilerOptions: {
                sourceMap: process.env.NODE_ENV === 'development',
                declaration: false, // Skip in development
                declarationMap: false
              }
            }
          }
        ]
      }
    ]
  },
  
  plugins: [
    // Type checking in separate process
    new ForkTsCheckerWebpackPlugin({
      typescript: {
        diagnosticOptions: {
          semantic: true,
          syntactic: true
        }
      },
      eslint: {
        files: './src/**/*.{ts,tsx,js,jsx}',
        options: {
          cache: true
        }
      }
    })
  ]
}
```

## 🎓 EdTech-Specific Optimizations

### 1. Interactive Content Optimization

#### Math Rendering Optimization
```javascript
// Webpack configuration for MathJax/KaTeX optimization
module.exports = {
  module: {
    rules: [
      {
        test: /\.tex$/,
        use: [
          {
            loader: 'raw-loader'
          },
          {
            loader: 'katex-loader',
            options: {
              trust: true,
              strict: false
            }
          }
        ]
      }
    ]
  },
  
  plugins: [
    new webpack.ProvidePlugin({
      // Global MathJax configuration
      MathJax: ['mathjax', 'MathJax']
    })
  ],
  
  optimization: {
    splitChunks: {
      cacheGroups: {
        // Separate math libraries to allow caching
        math: {
          test: /[\\/]node_modules[\\/](mathjax|katex)[\\/]/,
          name: 'math-renderer',
          chunks: 'all',
          priority: 30
        }
      }
    }
  }
}
```

#### Video Content Optimization
```javascript
// Video.js and HLS optimization
module.exports = {
  module: {
    rules: [
      {
        test: /\.vtt$/,
        use: 'file-loader',
        options: {
          name: 'captions/[name].[hash:8].[ext]'
        }
      }
    ]
  },
  
  plugins: [
    new webpack.DefinePlugin({
      // Enable video.js optimizations
      'process.env.VJS_CONTRIB_HLS': JSON.stringify(true),
      'process.env.VJS_CONTRIB_DASH': JSON.stringify(true)
    })
  ],
  
  optimization: {
    splitChunks: {
      cacheGroups: {
        // Video libraries chunk
        video: {
          test: /[\\/]node_modules[\\/](video\.js|videojs|hls\.js)[\\/]/,
          name: 'video-player',
          chunks: 'all',
          priority: 25
        }
      }
    }
  }
}
```

### 2. Performance Monitoring Integration

#### Bundle Analysis Automation
```javascript
// Automated bundle analysis
const { BundleAnalyzerPlugin } = require('webpack-bundle-analyzer')
const path = require('path')

module.exports = {
  plugins: [
    // Generate bundle report automatically
    new BundleAnalyzerPlugin({
      analyzerMode: process.env.ANALYZE ? 'server' : 'static',
      openAnalyzer: process.env.ANALYZE === 'true',
      reportFilename: path.resolve(__dirname, 'reports/bundle-report.html'),
      generateStatsFile: true,
      statsFilename: path.resolve(__dirname, 'reports/bundle-stats.json'),
      
      // Exclude small modules from analysis
      excludeAssets: (name) => {
        return name.endsWith('.map') || name.includes('chunk') && name.length < 1000
      }
    })
  ]
}
```

#### Performance Budget Enforcement
```javascript
// Performance budget configuration
module.exports = {
  performance: {
    // Asset size hints
    maxAssetSize: 250000, // 250kb
    maxEntrypointSize: 400000, // 400kb
    
    // Performance hint level
    hints: process.env.NODE_ENV === 'production' ? 'error' : 'warning',
    
    // Filter which files to consider
    assetFilter: function(assetFilename) {
      // Exclude source maps and images from performance budget
      return !assetFilename.endsWith('.map') && !assetFilename.match(/\.(png|jpe?g|gif|svg)$/)
    }
  }
}
```

## 🔧 Advanced Configuration Patterns

### 1. Multi-Environment Configuration

#### Environment-Specific Optimizations
```javascript
// webpack.config.js - Multi-environment setup
const path = require('path')
const webpack = require('webpack')

module.exports = (env, argv) => {
  const isProduction = argv.mode === 'production'
  const isDevelopment = !isProduction
  const isAnalyze = env && env.analyze
  
  const config = {
    mode: argv.mode,
    
    // Environment-specific entry points
    entry: {
      app: './src/index.tsx',
      ...(isProduction && {
        // Service worker for production only
        sw: './src/serviceWorker.ts'
      })
    },
    
    // Environment-specific optimizations
    optimization: {
      minimize: isProduction,
      sideEffects: false,
      
      ...(isDevelopment && {
        // Development-only optimizations
        removeAvailableModules: false,
        removeEmptyChunks: false,
        splitChunks: false
      }),
      
      ...(isProduction && {
        // Production-only optimizations
        usedExports: true,
        concatenateModules: true,
        splitChunks: {
          // Production chunk strategy
          chunks: 'all',
          cacheGroups: {
            // Detailed production chunking
            default: false,
            vendors: false,
            react: {
              test: /[\\/]node_modules[\\/](react|react-dom)[\\/]/,
              name: 'react',
              chunks: 'all',
              priority: 40
            }
          }
        }
      })
    },
    
    plugins: [
      // Environment variables
      new webpack.DefinePlugin({
        'process.env.NODE_ENV': JSON.stringify(argv.mode),
        'process.env.DEBUG': JSON.stringify(isDevelopment),
        'process.env.API_BASE_URL': JSON.stringify(
          process.env.API_BASE_URL || 'http://localhost:8000'
        )
      }),
      
      // Development plugins
      ...(isDevelopment ? [
        new webpack.HotModuleReplacementPlugin()
      ] : []),
      
      // Production plugins
      ...(isProduction ? [
        new webpack.ids.HashedModuleIdsPlugin({
          context: path.resolve(__dirname, 'src'),
          hashFunction: 'sha256',
          hashDigest: 'hex',
          hashDigestLength: 20
        })
      ] : []),
      
      // Analysis plugins
      ...(isAnalyze ? [
        new BundleAnalyzerPlugin({
          analyzerMode: 'static',
          openAnalyzer: true
        })
      ] : [])
    ],
    
    // Environment-specific dev server
    ...(isDevelopment && {
      devServer: {
        hot: true,
        port: 3000,
        compress: true,
        historyApiFallback: true
      }
    })
  }
  
  return config
}
```

### 2. Micro-Frontend Architecture

#### Module Federation Setup
```javascript
// Host application configuration
const ModuleFederationPlugin = require('@module-federation/webpack')

module.exports = {
  mode: 'development',
  
  plugins: [
    new ModuleFederationPlugin({
      name: 'edtech_host',
      
      // Expose host components
      exposes: {
        './UserProfile': './src/components/UserProfile',
        './Navigation': './src/components/Navigation'
      },
      
      // Remote applications
      remotes: {
        lessons: 'lessons@http://localhost:3001/remoteEntry.js',
        quiz: 'quiz@http://localhost:3002/remoteEntry.js',
        analytics: 'analytics@http://localhost:3003/remoteEntry.js'
      },
      
      // Shared dependencies
      shared: {
        react: {
          singleton: true,
          requiredVersion: '^18.0.0'
        },
        'react-dom': {
          singleton: true,
          requiredVersion: '^18.0.0'
        },
        '@mui/material': {
          singleton: true,
          requiredVersion: '^5.0.0'
        },
        // EdTech specific shared libraries
        'react-player': {
          singleton: true,
          requiredVersion: '^2.0.0'
        }
      }
    })
  ]
}

// Remote application configuration (lessons module)
module.exports = {
  mode: 'development',
  
  plugins: [
    new ModuleFederationPlugin({
      name: 'lessons',
      filename: 'remoteEntry.js',
      
      // Expose lesson components
      exposes: {
        './LessonPlayer': './src/components/LessonPlayer',
        './LessonList': './src/components/LessonList',
        './ProgressTracker': './src/components/ProgressTracker'
      },
      
      // Shared dependencies from host
      shared: {
        react: { singleton: true },
        'react-dom': { singleton: true },
        '@mui/material': { singleton: true }
      }
    })
  ]
}
```

## 📊 Performance Monitoring & Analytics

### 1. Build Performance Tracking

#### Custom Performance Plugin
```javascript
// BuildPerformancePlugin.js
class BuildPerformancePlugin {
  constructor(options = {}) {
    this.options = {
      outputPath: './reports/build-performance.json',
      ...options
    }
  }
  
  apply(compiler) {
    const startTime = Date.now()
    const metrics = {
      phases: {},
      chunks: {},
      assets: {}
    }
    
    // Compilation start
    compiler.hooks.compile.tap('BuildPerformancePlugin', () => {
      metrics.phases.compilationStart = Date.now() - startTime
    })
    
    // Compilation finish
    compiler.hooks.done.tap('BuildPerformancePlugin', (stats) => {
      metrics.phases.compilationEnd = Date.now() - startTime
      metrics.totalTime = Date.now() - startTime
      
      // Analyze chunks
      stats.compilation.chunks.forEach(chunk => {
        metrics.chunks[chunk.name] = {
          size: chunk.size(),
          modules: chunk.getNumberOfModules()
        }
      })
      
      // Analyze assets
      Object.keys(stats.compilation.assets).forEach(assetName => {
        const asset = stats.compilation.assets[assetName]
        metrics.assets[assetName] = {
          size: asset.size()
        }
      })
      
      // Save metrics
      const fs = require('fs')
      const path = require('path')
      
      fs.writeFileSync(
        path.resolve(this.options.outputPath),
        JSON.stringify(metrics, null, 2)
      )
      
      console.log(`📊 Build completed in ${metrics.totalTime}ms`)
      this.logRecommendations(metrics)
    })
  }
  
  logRecommendations(metrics) {
    const recommendations = []
    
    if (metrics.totalTime > 60000) {
      recommendations.push('⚠️  Consider enabling persistent caching')
    }
    
    const largeAssets = Object.entries(metrics.assets)
      .filter(([_, asset]) => asset.size > 500000)
    
    if (largeAssets.length > 0) {
      recommendations.push('⚠️  Large assets detected, consider code splitting')
    }
    
    if (recommendations.length > 0) {
      console.log('\n🔍 Optimization Recommendations:')
      recommendations.forEach(rec => console.log(rec))
    }
  }
}

module.exports = BuildPerformancePlugin
```

### 2. Runtime Performance Integration

#### Web Vitals Monitoring
```typescript
// Performance monitoring integration
import { getCLS, getFID, getFCP, getLCP, getTTFB } from 'web-vitals'

class WebpackPerformanceMonitor {
  private metrics: Map<string, number> = new Map()
  
  init() {
    // Core Web Vitals
    getCLS(this.recordMetric.bind(this))
    getFID(this.recordMetric.bind(this))
    getFCP(this.recordMetric.bind(this))
    getLCP(this.recordMetric.bind(this))
    getTTFB(this.recordMetric.bind(this))
    
    // Webpack-specific metrics
    this.recordBundleMetrics()
    this.recordChunkLoadingTimes()
  }
  
  private recordMetric(metric: any) {
    this.metrics.set(metric.name, metric.value)
    
    // Log poor performance
    if (metric.rating === 'poor') {
      console.warn(`Poor ${metric.name}: ${metric.value}ms`)
    }
    
    // Send to analytics
    this.sendToAnalytics(metric)
  }
  
  private recordBundleMetrics() {
    // Record initial bundle sizes
    const initialBundles = document.querySelectorAll('script[src*="js"]')
    let totalSize = 0
    
    initialBundles.forEach(script => {
      const src = script.getAttribute('src')
      if (src) {
        fetch(src, { method: 'HEAD' })
          .then(response => {
            const size = parseInt(response.headers.get('content-length') || '0')
            totalSize += size
            this.metrics.set('initialBundleSize', totalSize)
          })
      }
    })
  }
  
  private recordChunkLoadingTimes() {
    // Monitor dynamic import performance
    const originalImport = window.__webpack_require__.e
    
    if (originalImport) {
      window.__webpack_require__.e = function(chunkId: string) {
        const startTime = performance.now()
        
        return originalImport.call(this, chunkId).then(
          (result: any) => {
            const loadTime = performance.now() - startTime
            console.log(`Chunk ${chunkId} loaded in ${loadTime}ms`)
            return result
          }
        )
      }
    }
  }
  
  private sendToAnalytics(metric: any) {
    // Send to your analytics service
    if (window.gtag) {
      window.gtag('event', 'web_vitals', {
        event_category: 'Performance',
        event_label: metric.name,
        value: Math.round(metric.value),
        custom_map: {
          metric_rating: metric.rating
        }
      })
    }
  }
}

// Initialize performance monitoring
const performanceMonitor = new WebpackPerformanceMonitor()
performanceMonitor.init()
```

## 🔍 Debugging & Troubleshooting

### Common Webpack Issues & Solutions

#### Memory Issues
```javascript
// webpack.config.js - Memory optimization
module.exports = {
  // Increase Node.js memory limit
  node: {
    // Increase max memory
    global: false,
    __filename: false,
    __dirname: false
  },
  
  optimization: {
    // Reduce memory usage during builds
    removeAvailableModules: true,
    removeEmptyChunks: true,
    mergeDuplicateChunks: true,
    
    // Limit concurrent processing
    minimizer: [
      new TerserPlugin({
        parallel: Math.max(1, require('os').cpus().length - 1)
      })
    ]
  }
}
```

#### Build Performance Debug Script
```bash
#!/bin/bash
# scripts/debug-webpack-performance.sh

echo "🔍 Webpack Performance Debug"

# Check Node.js version
echo "Node.js version: $(node --version)"

# Check memory usage
echo "Available memory: $(free -h | grep '^Mem:' | awk '{print $7}')"

# Build with detailed stats
npx webpack --profile --json > webpack-stats.json

# Analyze with webpack-bundle-analyzer
npx webpack-bundle-analyzer webpack-stats.json

# Check for common issues
echo "Checking for common performance issues..."

# Large dependencies
echo "Large dependencies:"
npx bundlesize

# Duplicate dependencies
echo "Duplicate dependencies:"
npx duplicate-package-checker-webpack-plugin

echo "✅ Performance debug completed!"
```

---

**Navigation**
- ← Back to: [Comparison Analysis](./comparison-analysis.md)
- → Next: [Vite Optimization](./vite-optimization.md)
- → Related: [Performance Analysis](./performance-analysis.md)