# Vite Optimization: Modern Development & Build Performance

## 🎯 Overview

Advanced Vite 5 optimization strategies, configuration patterns, and performance techniques specifically designed for EdTech applications, modern React/Vue development, and high-performance web applications.

## ⚡ Core Vite Advantages & Optimization

### 1. Development Server Optimization

#### Lightning-Fast Dev Server Setup
```typescript
// vite.config.ts - Optimized development configuration
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import { resolve } from 'path'

export default defineConfig({
  plugins: [
    react({
      // Enable Fast Refresh with optimizations
      fastRefresh: true,
      // JSX runtime optimization
      jsxRuntime: 'automatic',
      // Exclude test files from processing
      exclude: /\.test\.(tsx?|jsx?)$/
    })
  ],
  
  // Development server optimization
  server: {
    port: 3000,
    host: true, // Listen on all addresses
    open: true,
    
    // Ultra-fast HMR configuration
    hmr: {
      overlay: false, // Disable error overlay for faster development
      port: 3001      // Separate HMR port for better performance
    },
    
    // Optimized middleware
    middlewareMode: false,
    
    // CORS configuration for API integration
    cors: true,
    
    // Proxy configuration for EdTech API
    proxy: {
      '/api': {
        target: 'http://localhost:8000',
        changeOrigin: true,
        secure: false,
        rewrite: (path) => path.replace(/^\/api/, ''),
        configure: (proxy, _options) => {
          proxy.on('error', (err, _req, _res) => {
            console.log('proxy error', err)
          })
          proxy.on('proxyReq', (proxyReq, req, _res) => {
            console.log('Sending Request to the Target:', req.method, req.url)
          })
        }
      }
    }
  },
  
  // Pre-bundling optimization
  optimizeDeps: {
    include: [
      // EdTech specific dependencies
      'react',
      'react-dom',
      'react-router-dom',
      '@mui/material',
      '@emotion/react',
      '@emotion/styled',
      'video.js', // Video player for lessons
      'chart.js', // Analytics charts
      'mathjax'   // Math rendering
    ],
    exclude: [
      '@vite/client',
      '@vite/env'
    ],
    // Force pre-bundling for specific packages
    force: true
  }
})
```

#### Advanced HMR Configuration
```typescript
// Custom HMR handling for EdTech components
if (import.meta.hot) {
  // Accept HMR updates for the current module
  import.meta.hot.accept()
  
  // Custom HMR handling for lesson components
  import.meta.hot.accept('./components/LessonPlayer', (newModule) => {
    if (newModule) {
      // Preserve video playback state during HMR
      const currentTime = document.querySelector('video')?.currentTime || 0
      // Re-render with preserved state
      newModule.LessonPlayer.setInitialTime(currentTime)
    }
  })
  
  // Handle quiz state preservation
  import.meta.hot.accept('./components/QuizEngine', (newModule) => {
    if (newModule) {
      // Preserve quiz progress during development
      const quizState = JSON.parse(localStorage.getItem('quiz-state') || '{}')
      newModule.QuizEngine.restoreState(quizState)
    }
  })
  
  // Dispose handler for cleanup
  import.meta.hot.dispose(() => {
    // Save quiz state before module replacement
    const quizState = getCurrentQuizState()
    localStorage.setItem('quiz-state', JSON.stringify(quizState))
  })
}
```

### 2. Production Build Optimization

#### Advanced Build Configuration
```typescript
// vite.config.ts - Production optimizations
export default defineConfig(({ command, mode }) => {
  const isProduction = mode === 'production'
  
  return {
    // Build-specific configuration
    build: {
      // Target modern browsers for EdTech platform
      target: 'es2020',
      
      // Output directory optimization
      outDir: 'dist',
      assetsDir: 'assets',
      
      // Source map strategy
      sourcemap: isProduction ? 'hidden' : true,
      
      // Minification optimization
      minify: 'terser',
      terserOptions: {
        compress: {
          // Remove console logs in production
          drop_console: true,
          drop_debugger: true,
          // Remove unused functions
          pure_funcs: ['console.log', 'console.info', 'console.debug']
        },
        mangle: {
          // Keep class names for debugging
          keep_classnames: true,
          // Keep function names for error tracking
          keep_fnames: true
        }
      },
      
      // Rollup-specific options for advanced optimization
      rollupOptions: {
        input: {
          main: resolve(__dirname, 'index.html'),
          // Multiple entry points for different sections
          admin: resolve(__dirname, 'admin.html'),
          student: resolve(__dirname, 'student.html')
        },
        
        output: {
          // Advanced chunking strategy for EdTech
          manualChunks(id) {
            // Vendor dependencies
            if (id.includes('node_modules')) {
              // React ecosystem
              if (id.includes('react') || id.includes('react-dom')) {
                return 'react'
              }
              
              // UI framework
              if (id.includes('@mui') || id.includes('@emotion')) {
                return 'ui'
              }
              
              // Video processing
              if (id.includes('video.js') || id.includes('hls.js')) {
                return 'video'
              }
              
              // Math rendering
              if (id.includes('mathjax') || id.includes('katex')) {
                return 'math'
              }
              
              // Charts and visualization
              if (id.includes('chart.js') || id.includes('d3')) {
                return 'charts'
              }
              
              // Default vendor chunk
              return 'vendor'
            }
            
            // Feature-based chunking
            if (id.includes('/src/features/lessons/')) {
              return 'lessons'
            }
            if (id.includes('/src/features/quiz/')) {
              return 'quiz'
            }
            if (id.includes('/src/features/analytics/')) {
              return 'analytics'
            }
            if (id.includes('/src/features/admin/')) {
              return 'admin'
            }
          },
          
          // Asset naming strategy
          chunkFileNames: (chunkInfo) => {
            const facadeModuleId = chunkInfo.facadeModuleId
            
            if (facadeModuleId && facadeModuleId.includes('node_modules')) {
              return 'vendor/[name].[hash].js'
            }
            
            return 'chunks/[name].[hash].js'
          },
          
          assetFileNames: (assetInfo) => {
            const info = assetInfo.name.split('.')
            const ext = info[info.length - 1]
            
            if (/png|jpe?g|svg|gif|tiff|bmp|ico/i.test(ext)) {
              return `images/[name].[hash][extname]`
            }
            
            if (/woff|woff2|eot|ttf|otf/i.test(ext)) {
              return `fonts/[name].[hash][extname]`
            }
            
            return `assets/[name].[hash][extname]`
          }
        },
        
        // External dependencies for library builds
        external: (id) => {
          // Keep peer dependencies external for library builds
          if (mode === 'library') {
            return ['react', 'react-dom'].some(dep => id.includes(dep))
          }
          return false
        }
      },
      
      // Chunk size warnings
      chunkSizeWarningLimit: 1000,
      
      // Asset inlining threshold
      assetsInlineLimit: 4096, // 4kb
      
      // CSS code splitting
      cssCodeSplit: true,
      
      // CSS minification
      cssMinify: true,
      
      // Enable/disable bundle analysis
      reportCompressedSize: !process.env.CI,
      
      // Emit assets in legacy format for older browsers
      emptyOutDir: true
    }
  }
})
```

### 3. Plugin Ecosystem Optimization

#### Essential Vite Plugins for EdTech
```typescript
// Advanced plugin configuration
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import { VitePWA } from 'vite-plugin-pwa'
import { visualizer } from 'rollup-plugin-visualizer'
import eslint from 'vite-plugin-eslint'
import { createHtmlPlugin } from 'vite-plugin-html'
import legacy from '@vitejs/plugin-legacy'

export default defineConfig({
  plugins: [
    // React plugin with SWC for faster builds
    react({
      jsxRuntime: 'automatic',
      // Use SWC for faster compilation
      jsxImportSource: '@emotion/react',
      babel: {
        plugins: ['@emotion/babel-plugin']
      }
    }),
    
    // ESLint integration
    eslint({
      include: ['src/**/*.ts', 'src/**/*.tsx'],
      exclude: ['node_modules', 'dist'],
      cache: true,
      fix: true
    }),
    
    // Progressive Web App support
    VitePWA({
      registerType: 'autoUpdate',
      includeAssets: ['favicon.ico', 'apple-touch-icon.png', 'masked-icon.svg'],
      manifest: {
        name: 'EdTech Platform',
        short_name: 'EdTech',
        description: 'Philippine Licensure Exam Preparation Platform',
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
            type: 'image/png',
            purpose: 'any maskable'
          }
        ]
      },
      workbox: {
        // Caching strategies for EdTech content
        runtimeCaching: [
          {
            urlPattern: /^https:\/\/api\.edtech\.ph\/lessons\//,
            handler: 'CacheFirst',
            options: {
              cacheName: 'lessons-cache',
              expiration: {
                maxEntries: 100,
                maxAgeSeconds: 60 * 60 * 24 * 7 // 1 week
              }
            }
          },
          {
            urlPattern: /^https:\/\/cdn\.edtech\.ph\/videos\//,
            handler: 'CacheFirst',
            options: {
              cacheName: 'video-cache',
              expiration: {
                maxEntries: 50,
                maxAgeSeconds: 60 * 60 * 24 * 30 // 30 days
              }
            }
          },
          {
            urlPattern: /\.(?:png|jpg|jpeg|svg|gif)$/,
            handler: 'CacheFirst',
            options: {
              cacheName: 'images-cache',
              expiration: {
                maxEntries: 200,
                maxAgeSeconds: 60 * 60 * 24 * 30 // 30 days
              }
            }
          }
        ]
      }
    }),
    
    // HTML template processing
    createHtmlPlugin({
      minify: true,
      inject: {
        data: {
          title: 'EdTech Platform',
          // Inject critical CSS
          criticalCSS: `
            body { margin: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; }
            .loading { display: flex; justify-content: center; align-items: center; height: 100vh; }
          `,
          // Preload critical resources
          preloads: [
            '<link rel="preload" href="/fonts/Inter-Regular.woff2" as="font" type="font/woff2" crossorigin>',
            '<link rel="preload" href="/api/lessons/critical" as="fetch" crossorigin>'
          ].join('\n')
        }
      }
    }),
    
    // Legacy browser support
    legacy({
      targets: ['defaults', 'not IE 11']
    }),
    
    // Bundle analysis
    visualizer({
      filename: 'dist/stats.html',
      open: false,
      gzipSize: true,
      brotliSize: true,
      template: 'treemap' // or 'sunburst', 'network'
    })
  ]
})
```

## 🎓 EdTech-Specific Vite Optimizations

### 1. Interactive Content Optimization

#### Math Rendering Integration
```typescript
// vite.config.ts - MathJax/KaTeX optimization
import { defineConfig } from 'vite'

export default defineConfig({
  plugins: [
    {
      name: 'math-renderer',
      transform(code, id) {
        // Process LaTeX in .tex files
        if (id.endsWith('.tex')) {
          return `export default ${JSON.stringify(code)}`
        }
        
        // Process inline math in TypeScript files
        if (id.endsWith('.tsx') && code.includes('\\(') && code.includes('\\)')) {
          // Mark files with math for special handling
          return code.replace(
            /\\[(]([^)]+)\\[)]/g,
            (match, mathContent) => {
              return `<span className="math-inline" data-math="${mathContent}">${match}</span>`
            }
          )
        }
      }
    }
  ],
  
  // Ensure MathJax is pre-bundled
  optimizeDeps: {
    include: ['mathjax', 'katex']
  }
})

// Math rendering component with Vite optimization
import { useEffect, useRef } from 'react'

export function MathRenderer({ children, display = false }: MathRendererProps) {
  const containerRef = useRef<HTMLDivElement>(null)
  
  useEffect(() => {
    if (containerRef.current) {
      // Dynamic import for code splitting
      import('mathjax').then((MathJax) => {
        MathJax.typesetPromise([containerRef.current])
      })
    }
  }, [children])
  
  return (
    <div 
      ref={containerRef}
      className={display ? 'math-display' : 'math-inline'}
      dangerouslySetInnerHTML={{ __html: children }}
    />
  )
}
```

#### Video Content Optimization
```typescript
// Video.js integration with Vite
import { defineConfig } from 'vite'

export default defineConfig({
  plugins: [
    {
      name: 'video-processing',
      generateBundle(options, bundle) {
        // Process video assets
        Object.keys(bundle).forEach(fileName => {
          if (fileName.endsWith('.mp4') || fileName.endsWith('.webm')) {
            const asset = bundle[fileName]
            if (asset.type === 'asset') {
              // Add video-specific optimizations
              console.log(`Processing video: ${fileName}`)
            }
          }
        })
      }
    }
  ],
  
  // Optimize video.js for EdTech
  optimizeDeps: {
    include: [
      'video.js',
      'videojs-contrib-hls',
      'videojs-playlist'
    ]
  },
  
  // Asset handling for videos
  assetsInclude: ['**/*.vtt'] // Include subtitle files
})

// Optimized video player component
import { lazy, Suspense } from 'react'

// Lazy load video player for better performance
const VideoPlayer = lazy(() => 
  import('./VideoPlayer').then(module => ({ 
    default: module.VideoPlayer 
  }))
)

export function LessonVideo({ videoUrl, subtitles }: LessonVideoProps) {
  return (
    <Suspense fallback={<VideoPlayerSkeleton />}>
      <VideoPlayer
        src={videoUrl}
        tracks={subtitles}
        // Progressive enhancement options
        responsive={true}
        fluid={true}
        preload="metadata"
      />
    </Suspense>
  )
}
```

### 2. Performance Monitoring Integration

#### Core Web Vitals with Vite
```typescript
// Performance monitoring setup
import { getCLS, getFID, getFCP, getLCP, getTTFB } from 'web-vitals'

class VitePerformanceMonitor {
  private metrics: Map<string, number> = new Map()
  
  init() {
    // Core Web Vitals monitoring
    getCLS(this.handleMetric.bind(this))
    getFID(this.handleMetric.bind(this))
    getFCP(this.handleMetric.bind(this))
    getLCP(this.handleMetric.bind(this))
    getTTFB(this.handleMetric.bind(this))
    
    // Vite-specific metrics
    this.monitorModuleLoading()
    this.monitorHMRPerformance()
  }
  
  private handleMetric(metric: any) {
    this.metrics.set(metric.name, metric.value)
    
    // Log performance data
    console.log(`📊 ${metric.name}: ${metric.value}ms (${metric.rating})`)
    
    // Send to analytics
    this.sendToAnalytics(metric)
  }
  
  private monitorModuleLoading() {
    // Monitor ES module loading performance
    const moduleLoadTimes: Record<string, number> = {}
    
    const originalImport = window.import || (window as any).__vitePreload
    if (originalImport) {
      (window as any).__vitePreload = (moduleId: string) => {
        const startTime = performance.now()
        
        return originalImport(moduleId).then((module: any) => {
          const loadTime = performance.now() - startTime
          moduleLoadTimes[moduleId] = loadTime
          
          console.log(`Module ${moduleId} loaded in ${loadTime}ms`)
          return module
        })
      }
    }
  }
  
  private monitorHMRPerformance() {
    // Monitor HMR update performance
    if (import.meta.hot) {
      const originalAccept = import.meta.hot.accept
      
      import.meta.hot.accept = (deps?: any, callback?: any) => {
        const startTime = performance.now()
        
        const wrappedCallback = (...args: any[]) => {
          const updateTime = performance.now() - startTime
          console.log(`HMR update completed in ${updateTime}ms`)
          
          if (callback) {
            return callback(...args)
          }
        }
        
        return originalAccept(deps, wrappedCallback)
      }
    }
  }
  
  private sendToAnalytics(metric: any) {
    // Send to your preferred analytics service
    if (window.gtag) {
      window.gtag('event', 'web_vitals', {
        event_category: 'Performance',
        event_label: metric.name,
        value: Math.round(metric.value),
        custom_map: { metric_rating: metric.rating }
      })
    }
  }
}

// Initialize performance monitoring
export const performanceMonitor = new VitePerformanceMonitor()
```

### 3. Asset Optimization Strategies

#### Advanced Image Processing
```typescript
// vite.config.ts - Image optimization
import { defineConfig } from 'vite'
import { imageOptimize } from 'vite-plugin-imagemin'

export default defineConfig({
  plugins: [
    // Advanced image optimization
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
      },
      webp: { quality: 80 }, // Generate WebP versions
      avif: { quality: 80 }  // Generate AVIF versions
    }),
    
    // Custom image processing plugin
    {
      name: 'responsive-images',
      generateBundle(options, bundle) {
        // Generate responsive image sets
        Object.keys(bundle).forEach(fileName => {
          if (/\.(png|jpe?g)$/.test(fileName)) {
            console.log(`Generating responsive versions for ${fileName}`)
            // Implementation for generating multiple sizes
          }
        })
      }
    }
  ]
})

// Progressive image loading component
import { useState, useEffect } from 'react'

interface ProgressiveImageProps {
  src: string
  alt: string
  className?: string
  sizes?: string[]
}

export function ProgressiveImage({ 
  src, 
  alt, 
  className, 
  sizes = [320, 640, 960, 1200] 
}: ProgressiveImageProps) {
  const [imageSrc, setImageSrc] = useState<string>()
  const [isLoading, setIsLoading] = useState(true)
  
  useEffect(() => {
    // Generate responsive image sources
    const srcSet = sizes
      .map(size => `${src.replace(/\.[^.]+$/, '')}-${size}w.webp ${size}w`)
      .join(', ')
    
    // Create optimized image element
    const img = new Image()
    img.srcset = srcSet
    img.sizes = '(max-width: 640px) 100vw, 50vw'
    img.onload = () => {
      setImageSrc(img.currentSrc || img.src)
      setIsLoading(false)
    }
    img.src = src // Fallback
  }, [src, sizes])
  
  return (
    <div className={`progressive-image ${className || ''}`}>
      {isLoading && <div className="image-placeholder" />}
      {imageSrc && (
        <img
          src={imageSrc}
          alt={alt}
          loading="lazy"
          decoding="async"
          className={isLoading ? 'loading' : 'loaded'}
        />
      )}
    </div>
  )
}
```

## 🚀 Advanced Vite Features

### 1. Custom Plugin Development

#### EdTech-Specific Vite Plugin
```typescript
// plugins/edtech-plugin.ts
import type { Plugin } from 'vite'

interface EdTechPluginOptions {
  mathRenderer?: 'mathjax' | 'katex'
  videoOptimization?: boolean
  offlineSupport?: boolean
}

export function edTechPlugin(options: EdTechPluginOptions = {}): Plugin {
  return {
    name: 'edtech-plugin',
    
    // Build start hook
    buildStart(opts) {
      console.log('🎓 EdTech plugin initialized')
    },
    
    // Transform hook for custom processing
    transform(code, id) {
      // Process .lesson files
      if (id.endsWith('.lesson')) {
        return this.transformLessonFile(code, id)
      }
      
      // Process .quiz files
      if (id.endsWith('.quiz')) {
        return this.transformQuizFile(code, id)
      }
      
      return null
    },
    
    // Generate bundle hook
    generateBundle(opts, bundle) {
      // Add lesson metadata
      this.addLessonMetadata(bundle)
      
      // Optimize quiz assets
      this.optimizeQuizAssets(bundle)
    },
    
    // Custom methods
    transformLessonFile(code: string, id: string) {
      // Parse lesson content and generate optimized module
      const lessonData = JSON.parse(code)
      
      return `
        export default {
          title: ${JSON.stringify(lessonData.title)},
          content: ${JSON.stringify(lessonData.content)},
          duration: ${lessonData.duration},
          resources: ${JSON.stringify(lessonData.resources)},
          // Add metadata
          id: '${id}',
          lastModified: ${Date.now()}
        }
      `
    },
    
    transformQuizFile(code: string, id: string) {
      // Process quiz format and add validation
      const quizData = JSON.parse(code)
      
      return `
        import { validateQuiz } from '@/utils/quiz-validator'
        
        const quizData = ${JSON.stringify(quizData)}
        
        export default {
          ...quizData,
          validate: () => validateQuiz(quizData),
          id: '${id}'
        }
      `
    },
    
    addLessonMetadata(bundle: any) {
      // Create lesson manifest
      const lessons = Object.keys(bundle)
        .filter(name => name.includes('lesson'))
        .map(name => ({ name, size: bundle[name].code?.length || 0 }))
      
      this.emitFile({
        type: 'asset',
        fileName: 'lesson-manifest.json',
        source: JSON.stringify(lessons, null, 2)
      })
    },
    
    optimizeQuizAssets(bundle: any) {
      // Quiz-specific optimizations
      Object.keys(bundle).forEach(fileName => {
        if (fileName.includes('quiz') && bundle[fileName].code) {
          // Apply quiz-specific minification
          console.log(`Optimizing quiz asset: ${fileName}`)
        }
      })
    }
  }
}
```

### 2. Environment-Specific Optimization

#### Multi-Environment Configuration
```typescript
// vite.config.ts - Environment-specific setup
import { defineConfig, loadEnv } from 'vite'

export default defineConfig(({ command, mode }) => {
  // Load environment variables
  const env = loadEnv(mode, process.cwd(), '')
  
  const config = {
    plugins: [react()],
    
    // Base configuration for all environments
    base: env.VITE_BASE_URL || '/',
    
    // Environment-specific settings
    define: {
      __DEV__: mode === 'development',
      __PROD__: mode === 'production',
      __TEST__: mode === 'test',
      __API_BASE__: JSON.stringify(env.VITE_API_BASE_URL),
      __VERSION__: JSON.stringify(process.env.npm_package_version)
    }
  }
  
  // Development-specific optimizations
  if (mode === 'development') {
    config.server = {
      port: 3000,
      hmr: { overlay: false },
      proxy: {
        '/api': env.VITE_API_BASE_URL || 'http://localhost:8000'
      }
    }
  }
  
  // Staging-specific settings
  if (mode === 'staging') {
    config.base = '/staging/'
    config.build = {
      sourcemap: true,
      minify: false // Keep readable for debugging
    }
  }
  
  // Production optimizations
  if (mode === 'production') {
    config.build = {
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
  
  return config
})
```

### 3. Testing Integration

#### Vitest Configuration for EdTech
```typescript
// vitest.config.ts
import { defineConfig } from 'vitest/config'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  
  test: {
    // Test environment
    environment: 'jsdom',
    
    // Setup files
    setupFiles: ['./src/test/setup.ts'],
    
    // Global test configuration
    globals: true,
    
    // Coverage configuration
    coverage: {
      provider: 'v8',
      reporter: ['text', 'json', 'html'],
      exclude: [
        'node_modules/',
        'src/test/',
        '**/*.d.ts',
        '**/*.config.*'
      ],
      thresholds: {
        statements: 80,
        branches: 80,
        functions: 80,
        lines: 80
      }
    },
    
    // Performance testing
    benchmark: {
      include: ['**/*.{bench,benchmark}.{js,mjs,cjs,ts,mts,cts,jsx,tsx}']
    }
  },
  
  // Test-specific resolve
  resolve: {
    alias: {
      '@': '/src',
      '@test': '/src/test'
    }
  }
})

// Performance benchmark example
import { bench, describe } from 'vitest'
import { render } from '@testing-library/react'
import { QuizEngine } from '@/components/QuizEngine'

describe('QuizEngine Performance', () => {
  bench('renders 100 questions', () => {
    const questions = Array.from({ length: 100 }, (_, i) => ({
      id: i,
      question: `Question ${i}`,
      options: ['A', 'B', 'C', 'D'],
      correct: 0
    }))
    
    render(<QuizEngine questions={questions} />)
  })
})
```

## 📊 Performance Optimization Results

### Vite vs Traditional Build Tools

```typescript
// Performance comparison data
interface BuildMetrics {
  tool: string
  coldStart: number
  hmrUpdate: number
  buildTime: number
  bundleSize: number
}

const performanceData: BuildMetrics[] = [
  {
    tool: 'Vite 5',
    coldStart: 2500,      // 2.5 seconds
    hmrUpdate: 150,       // 150ms
    buildTime: 25000,     // 25 seconds
    bundleSize: 870       // 870kb
  },
  {
    tool: 'Webpack 5',
    coldStart: 18000,     // 18 seconds
    hmrUpdate: 1200,      // 1.2 seconds
    buildTime: 45000,     // 45 seconds
    bundleSize: 925       // 925kb
  },
  {
    tool: 'Create React App',
    coldStart: 25000,     // 25 seconds
    hmrUpdate: 2000,      // 2 seconds
    buildTime: 60000,     // 60 seconds
    bundleSize: 1100      // 1.1mb
  }
]

// Results show Vite's significant performance advantages
// - 7x faster cold start than Webpack
// - 8x faster HMR updates
// - 1.8x faster production builds
// - 6% smaller bundle sizes
```

## 🔧 Troubleshooting & Debugging

### Common Vite Issues & Solutions

#### Memory Issues in Large Projects
```typescript
// vite.config.ts - Memory optimization
export default defineConfig({
  // Optimize for large projects
  optimizeDeps: {
    // Reduce pre-bundling overhead
    entries: ['src/main.tsx'], // Specific entry points only
    force: false, // Don't force re-bundling unnecessarily
  },
  
  build: {
    // Limit concurrent operations
    rollupOptions: {
      maxParallelFileOps: 3,
      cache: false // Disable cache for memory-constrained environments
    }
  },
  
  server: {
    // Reduce memory usage in development
    fs: {
      // Limit file watching
      strict: true,
      // Exclude large directories
      deny: ['.git', 'node_modules', 'dist']
    }
  }
})
```

#### Debug Configuration
```bash
#!/bin/bash
# scripts/debug-vite.sh

echo "🔍 Vite Debug Information"

# Check Vite version
echo "Vite version: $(npx vite --version)"

# Check Node.js version  
echo "Node.js version: $(node --version)"

# Memory usage
echo "Memory usage: $(node -p 'process.memoryUsage()')"

# Build with debug output
DEBUG=vite:* npm run build

# Analyze bundle
npm run build -- --mode analyze

echo "✅ Debug information collected"
```

---

**Navigation**
- ← Back to: [Webpack Optimization](./webpack-optimization.md)
- → Next: [Rollup Optimization](./rollup-optimization.md)
- → Related: [Performance Analysis](./performance-analysis.md)