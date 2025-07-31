# Troubleshooting: Common Issues & Solutions

## 🎯 Overview

Comprehensive troubleshooting guide for common issues encountered with Webpack, Vite, and Rollup build tools, including diagnostic procedures, error resolution strategies, and optimization tips for EdTech applications.

## 🚨 Common Build Tool Issues

### Issue Priority Matrix

| Issue Type | Frequency | Impact | Urgency | Common In |
|------------|-----------|--------|---------|-----------|
| **Memory Issues** | High | High | Medium | Webpack, Large Projects |
| **Slow Build Times** | High | Medium | Low | All Tools |
| **Module Resolution** | Medium | High | High | All Tools |
| **HMR Failures** | Medium | Medium | High | Webpack, Vite |
| **Bundle Size Issues** | Medium | Medium | Medium | All Tools |
| **TypeScript Errors** | High | Medium | Medium | All Tools |
| **Plugin Conflicts** | Low | High | High | All Tools |

## 🔧 Webpack Troubleshooting

### 1. Memory Issues

#### Problem: Out of Memory Errors
```bash
# Common error messages
FATAL ERROR: Ineffective mark-compacts near heap limit Allocation failed - JavaScript heap out of memory
FATAL ERROR: MarkCompactCollector: young object promotion failed Allocation failed - JavaScript heap out of memory
```

#### Solution: Memory Optimization
```javascript
// webpack.config.js - Memory optimization
module.exports = {
  // Reduce memory usage
  optimization: {
    removeAvailableModules: false,
    removeEmptyChunks: false,
    splitChunks: false, // Disable in development
  },
  
  // Use faster source maps in development
  devtool: process.env.NODE_ENV === 'development' 
    ? 'eval-cheap-module-source-map' 
    : 'source-map',
  
  // Limit parallel jobs
  plugins: [
    new TerserPlugin({
      parallel: Math.max(1, require('os').cpus().length - 1)
    })
  ]
}

// package.json - Increase Node.js memory limit
{
  "scripts": {
    "build": "node --max-old-space-size=4096 node_modules/.bin/webpack",
    "dev": "node --max-old-space-size=2048 node_modules/.bin/webpack serve"
  }
}
```

#### Diagnostic Script
```bash
#!/bin/bash
# scripts/webpack-memory-debug.sh

echo "🔍 Webpack Memory Diagnostic"

# Check current memory usage
echo "System memory:"
free -h

# Check Node.js version
echo "Node.js version: $(node --version)"

# Check webpack version
echo "Webpack version: $(npx webpack --version)"

# Build with memory profiling
node --inspect --max-old-space-size=4096 node_modules/.bin/webpack --profile

# Analyze heap usage
echo "Heap usage during build:"
node -e "console.log(process.memoryUsage())"
```

### 2. Slow Build Performance

#### Problem: Long Build Times
```typescript
// Symptoms
interface BuildPerformanceSymptoms {
  coldStart: string        // > 30 seconds
  hmrUpdate: string        // > 3 seconds
  productionBuild: string  // > 2 minutes
  cpuUsage: string         // 100% for extended periods
}
```

#### Solution: Performance Optimization
```javascript
// webpack.config.js - Performance optimizations
const path = require('path')

module.exports = {
  // Enable persistent caching
  cache: {
    type: 'filesystem',
    buildDependencies: {
      config: [__filename]
    }
  },
  
  // Optimize module resolution
  resolve: {
    // Reduce resolve attempts
    extensions: ['.tsx', '.ts', '.js'],
    modules: [
      path.resolve(__dirname, 'src'),
      'node_modules'
    ],
    // Disable symlinks resolution
    symlinks: false,
    // Cache resolution results
    cacheWithContext: false
  },
  
  // Exclude large directories from file watching
  watchOptions: {
    ignored: /node_modules/,
    aggregateTimeout: 300,
    poll: 1000
  },
  
  // Use faster loaders
  module: {
    rules: [
      {
        test: /\.tsx?$/,
        use: [
          {
            loader: 'ts-loader',
            options: {
              transpileOnly: true, // Skip type checking
              experimentalWatchApi: true
            }
          }
        ]
      }
    ]
  }
}
```

### 3. Module Resolution Issues

#### Problem: Cannot Resolve Module
```bash
# Common error
Module not found: Error: Can't resolve 'module-name' in '/path/to/project'
```

#### Solution: Debug Resolution
```javascript
// webpack.config.js - Debug module resolution
module.exports = {
  resolve: {
    // Add detailed logging
    plugins: [
      new webpack.ProgressPlugin({
        entries: true,
        modules: true,
        modulesCount: 5000,
        profile: false,
        handler(percentage, message, ...args) {
          console.info(percentage, message, ...args);
        }
      })
    ]
  },
  
  // Enable resolution stats
  stats: {
    errorDetails: true,
    logging: 'verbose'
  }
}

// Debug script
const webpack = require('webpack')
const config = require('./webpack.config.js')

const compiler = webpack(config)
compiler.resolverFactory.plugin('resolver normal', resolver => {
  resolver.plugin('resolve', (context, callback) => {
    console.log('Resolving:', context.request)
    callback()
  })
})
```

## ⚡ Vite Troubleshooting

### 1. Pre-bundling Issues

#### Problem: Slow Initial Start
```bash
# Vite gets stuck on pre-bundling
Pre-bundling dependencies:
  react
  react-dom
  @mui/material
(this will be run only when your dependencies or config have changed)
```

#### Solution: Optimize Pre-bundling
```typescript
// vite.config.ts - Pre-bundling optimization
export default defineConfig({
  optimizeDeps: {
    // Explicitly include dependencies
    include: [
      'react',
      'react-dom',
      'react-router-dom',
      '@mui/material',
      '@emotion/react',
      '@emotion/styled'
    ],
    
    // Exclude problematic packages
    exclude: [
      '@vite/client',
      '@vite/env'
    ],
    
    // Force re-bundling
    force: true,
    
    // Reduce entries for faster scanning
    entries: ['./src/main.tsx']
  },
  
  // Clear dependency cache
  server: {
    force: true // Force dependency pre-bundling
  }
})
```

#### Clear Vite Cache
```bash
#!/bin/bash
# scripts/clear-vite-cache.sh

echo "🧹 Clearing Vite cache..."

# Remove Vite cache directories
rm -rf node_modules/.vite
rm -rf dist

# Clear npm cache
npm cache clean --force

# Reinstall dependencies
npm install

# Force pre-bundling
npm run dev -- --force

echo "✅ Vite cache cleared"
```

### 2. Import Resolution Issues

#### Problem: ESM Import Errors
```bash
# Common errors
Failed to resolve import "./Component" from "src/App.tsx"
The requested module './utils' does not provide an export named 'default'
```

#### Solution: Fix Import Patterns
```typescript
// ❌ Bad: Missing file extensions
import Component from './Component'
import { utils } from './utils'

// ✅ Good: Explicit imports for Vite
import Component from './Component.tsx'
import { utils } from './utils.ts'

// vite.config.ts - Configure resolution
export default defineConfig({
  resolve: {
    // Add extensions for resolution
    extensions: ['.mjs', '.js', '.ts', '.jsx', '.tsx', '.json'],
    
    // Configure alias for cleaner imports
    alias: {
      '@': path.resolve(__dirname, './src'),
      '@components': path.resolve(__dirname, './src/components'),
      '@utils': path.resolve(__dirname, './src/utils')
    }
  }
})

// Use import.meta.glob for dynamic imports
const modules = import.meta.glob('./components/*.tsx')
Object.entries(modules).forEach(([path, mod]) => {
  // Handle dynamic component loading
})
```

### 3. HMR Issues

#### Problem: Hot Reload Not Working
```typescript
// Symptoms
interface HMRIssues {
  symptom: string
  cause: string
  solution: string
}

const hmrProblems: HMRIssues[] = [
  {
    symptom: 'Full page reload on changes',
    cause: 'React Fast Refresh boundary violation',
    solution: 'Check component export patterns'
  },
  {
    symptom: 'State lost during updates',
    cause: 'Non-preservable component structure',
    solution: 'Use proper React hooks patterns'
  },
  {
    symptom: 'CSS changes not reflecting',
    cause: 'CSS module import issues',
    solution: 'Check CSS import statements'
  }
]
```

#### Solution: Fix HMR Configuration
```typescript
// vite.config.ts - HMR configuration
export default defineConfig({
  plugins: [
    react({
      // Configure Fast Refresh
      fastRefresh: true,
      // Include specific files
      include: "**/*.tsx",
      // Exclude test files
      exclude: /\.test\.(tsx?|jsx?)$/
    })
  ],
  
  server: {
    hmr: {
      // Configure HMR port
      port: 3001,
      // Disable overlay for better DX
      overlay: false
    }
  }
})

// Component HMR best practices
export function MyComponent() {
  // ✅ Good: Preservable state
  const [count, setCount] = useState(0)
  
  // ✅ Good: Memoized values
  const expensiveValue = useMemo(() => 
    computeExpensiveValue(count), [count]
  )
  
  return <div>{/* JSX */}</div>
}

// ✅ Good: Named export for HMR
export { MyComponent }

// Enable HMR acceptance
if (import.meta.hot) {
  import.meta.hot.accept()
}
```

## 🎲 Rollup Troubleshooting

### 1. Tree-Shaking Issues

#### Problem: Unused Code Not Eliminated
```typescript
// Example: Large bundle despite minimal imports
import { debounce } from 'lodash' // Imports entire lodash library
```

#### Solution: Optimize Tree-Shaking
```javascript
// rollup.config.js - Tree-shaking optimization
export default {
  // Enable aggressive tree-shaking
  treeshake: {
    propertyReadSideEffects: false,
    pureExternalModules: true,
    moduleSideEffects: false
  },
  
  // Configure external dependencies
  external: (id) => {
    // Mark all node_modules as external for libraries
    return /node_modules/.test(id)
  },
  
  plugins: [
    // Analyze bundle for tree-shaking effectiveness
    {
      name: 'tree-shake-analyzer',
      generateBundle(opts, bundle) {
        Object.keys(bundle).forEach(fileName => {
          const chunk = bundle[fileName]
          if (chunk.type === 'chunk') {
            console.log(`📦 ${fileName}: ${chunk.code.length} bytes`)
            
            // Warn about large chunks
            if (chunk.code.length > 50000) {
              console.warn(`⚠️  Large chunk detected: ${fileName}`)
            }
          }
        })
      }
    }
  ]
}

// Fix import patterns
// ❌ Bad: Imports entire library
import _ from 'lodash'
import * as utils from './utils'

// ✅ Good: Specific imports
import { debounce } from 'lodash'
import { specificUtil } from './utils'

// ✅ Good: Tree-shakable library alternatives
import debounce from 'lodash.debounce' // Individual package
import { debounce } from 'lodash-es'   // ES module version
```

### 2. CommonJS Compatibility Issues

#### Problem: CommonJS Module Import Errors
```bash
# Common error
'default' is not exported by node_modules/some-package/index.js
```

#### Solution: Configure CommonJS Plugin
```javascript
// rollup.config.js - CommonJS handling
import commonjs from '@rollup/plugin-commonjs'
import { nodeResolve } from '@rollup/plugin-node-resolve'

export default {
  plugins: [
    // Resolve node modules
    nodeResolve({
      // Prefer ES modules
      preferBuiltins: false,
      browser: true
    }),
    
    // Handle CommonJS modules
    commonjs({
      // Include specific packages
      include: /node_modules/,
      
      // Transform mixed ES/CommonJS modules
      transformMixedEsModules: true,
      
      // Strict require handling
      strictRequires: true,
      
      // Default export handling
      defaultIsModuleExports: true,
      
      // Named exports detection
      namedExports: {
        // Manually specify exports for problematic packages
        'react': ['createElement', 'Component', 'Fragment'],
        'react-dom': ['render', 'createPortal']
      }
    })
  ]
}
```

## 🎓 EdTech-Specific Troubleshooting

### 1. Math Rendering Issues

#### Problem: MathJax/KaTeX Not Loading
```typescript
// Common issues
interface MathRenderingIssues {
  issue: string
  cause: string
  solution: string
}

const mathIssues: MathRenderingIssues[] = [
  {
    issue: 'LaTeX not rendering',
    cause: 'MathJax not loaded or configured',
    solution: 'Ensure proper async loading and configuration'
  },
  {
    issue: 'Fonts not loading',
    cause: 'CORS or path issues with math fonts',
    solution: 'Configure proper asset paths and CORS headers'
  },
  {
    issue: 'Performance issues',
    cause: 'Synchronous rendering blocking UI',
    solution: 'Use web workers or async rendering'
  }
]
```

#### Solution: Optimize Math Rendering
```typescript
// Math rendering optimization
class MathRenderer {
  private static mathJaxPromise: Promise<any> | null = null
  
  static async loadMathJax() {
    if (!this.mathJaxPromise) {
      this.mathJaxPromise = new Promise((resolve, reject) => {
        // Dynamic import for code splitting
        import('mathjax').then(MathJax => {
          // Configure MathJax
          window.MathJax = {
            tex: {
              inlineMath: [['$', '$'], ['\\(', '\\)']],
              displayMath: [['$$', '$$'], ['\\[', '\\]']]
            },
            svg: {
              fontCache: 'global'  // Optimize font loading
            },
            startup: {
              ready: () => {
                MathJax.startup.defaultReady()
                resolve(MathJax)
              }
            }
          }
        }).catch(reject)
      })
    }
    return this.mathJaxPromise
  }
  
  static async renderMath(element: HTMLElement) {
    try {
      await this.loadMathJax()
      // Use requestIdleCallback for better performance
      if (window.requestIdleCallback) {
        window.requestIdleCallback(() => {
          window.MathJax.typesetPromise([element])
        })
      } else {
        await window.MathJax.typesetPromise([element])
      }
    } catch (error) {
      console.error('Math rendering failed:', error)
      // Fallback to text display
      element.textContent = element.dataset.math || element.innerHTML
    }
  }
}

// Vite configuration for math libraries
export default defineConfig({
  optimizeDeps: {
    include: ['mathjax', 'katex']
  },
  
  // Handle math assets
  assetsInclude: ['**/*.woff', '**/*.woff2', '**/*.ttf'],
  
  build: {
    rollupOptions: {
      output: {
        // Separate math libraries
        manualChunks: {
          math: ['mathjax', 'katex']
        }
      }
    }
  }
})
```

### 2. Video Player Issues

#### Problem: Video.js Loading/Performance Issues
```typescript
interface VideoIssues {
  issue: string
  symptoms: string[]
  solutions: string[]
}

const videoProblems: VideoIssues = {
  issue: 'Video player performance',
  symptoms: [
    'Slow video loading',
    'Buffering issues',
    'Memory leaks',
    'Multiple player instances'
  ],
  solutions: [
    'Implement lazy loading',
    'Use HLS for better streaming',
    'Proper cleanup on unmount',
    'Singleton player pattern'
  ]
}
```

#### Solution: Optimize Video Loading
```typescript
// Optimized video player component
import { useEffect, useRef, useCallback } from 'react'

interface VideoPlayerProps {
  src: string
  poster?: string
  autoplay?: boolean
}

export function VideoPlayer({ src, poster, autoplay = false }: VideoPlayerProps) {
  const videoRef = useRef<HTMLVideoElement>(null)
  const playerRef = useRef<any>(null)
  
  const initializePlayer = useCallback(async () => {
    if (!videoRef.current) return
    
    try {
      // Dynamic import for code splitting
      const videojs = await import('video.js')
      
      // Initialize player with optimized settings
      playerRef.current = videojs.default(videoRef.current, {
        controls: true,
        responsive: true,
        fluid: true,
        preload: 'metadata', // Don't preload full video
        playbackRates: [0.5, 1, 1.25, 1.5, 2],
        // HLS configuration for better streaming
        html5: {
          hls: {
            enableLowInitialPlaylist: true,
            smoothQualityChange: true
          }
        }
      })
      
      // Handle errors gracefully
      playerRef.current.on('error', (error: any) => {
        console.error('Video player error:', error)
        // Implement fallback or retry logic
      })
      
    } catch (error) {
      console.error('Failed to load video player:', error)
      // Fallback to native video element
    }
  }, [])
  
  useEffect(() => {
    initializePlayer()
    
    // Cleanup function
    return () => {
      if (playerRef.current) {
        playerRef.current.dispose()
        playerRef.current = null
      }
    }
  }, [initializePlayer])
  
  return (
    <div className="video-container">
      <video
        ref={videoRef}
        poster={poster}
        autoPlay={autoplay}
        className="video-js vjs-default-skin"
        data-src={src}
      />
    </div>
  )
}
```

## 🔍 Diagnostic Tools & Scripts

### 1. Universal Build Diagnostics

#### Comprehensive Diagnostic Script
```bash
#!/bin/bash
# scripts/build-diagnostics.sh

echo "🔍 Build Tool Diagnostics"
echo "=========================="

# System information
echo "System Information:"
echo "OS: $(uname -a)"
echo "Node.js: $(node --version)"
echo "npm: $(npm --version)"
echo "Memory: $(free -h | grep '^Mem:' | awk '{print $2}')"
echo "CPU: $(nproc) cores"
echo ""

# Project information
echo "Project Information:"
echo "Directory: $(pwd)"
echo "Package manager: $([ -f "yarn.lock" ] && echo "Yarn" || echo "npm")"

# Detect build tool
if [ -f "webpack.config.js" ] || grep -q "webpack" package.json; then
  BUILD_TOOL="webpack"
elif [ -f "vite.config.ts" ] || [ -f "vite.config.js" ]; then
  BUILD_TOOL="vite"
elif grep -q "react-scripts" package.json; then
  BUILD_TOOL="cra"
else
  BUILD_TOOL="unknown"
fi

echo "Build tool: $BUILD_TOOL"
echo ""

# Build tool specific diagnostics
case $BUILD_TOOL in
  "webpack")
    echo "Webpack Diagnostics:"
    npx webpack --version
    echo "Config file exists: $([ -f "webpack.config.js" ] && echo "Yes" || echo "No")"
    ;;
  "vite")
    echo "Vite Diagnostics:"
    npx vite --version
    echo "Config file exists: $([ -f "vite.config.ts" ] && echo "Yes" || echo "No")"
    echo "Cache directory: $([ -d "node_modules/.vite" ] && echo "Exists" || echo "Missing")"
    ;;
  "cra")
    echo "Create React App Diagnostics:"
    npm list react-scripts
    ;;
esac

# Dependencies analysis
echo ""
echo "Dependencies Analysis:"
echo "Total dependencies: $(npm list --depth=0 2>/dev/null | grep -c "├\|└")"
echo "Development dependencies: $(npm list --depth=0 --dev 2>/dev/null | grep -c "├\|└")"

# Performance check
echo ""
echo "Performance Check:"
echo "Node modules size: $(du -sh node_modules 2>/dev/null | cut -f1)"
echo "Project size: $(du -sh . --exclude=node_modules | cut -f1)"

# Common issues check
echo ""
echo "Common Issues Check:"
[ -d "node_modules/.cache" ] && echo "⚠️  Build cache exists (may need clearing)"
[ -f "package-lock.json" ] && [ -f "yarn.lock" ] && echo "⚠️  Multiple lock files detected"
[ ! -f ".gitignore" ] && echo "⚠️  No .gitignore file found"

echo ""
echo "✅ Diagnostics complete"
```

### 2. Performance Monitoring

#### Real-time Performance Monitor
```typescript
// Performance monitoring utility
class BuildPerformanceMonitor {
  private metrics: Map<string, number> = new Map()
  private startTime: number = Date.now()
  
  startPhase(name: string) {
    this.metrics.set(`${name}_start`, Date.now())
    console.log(`📊 Starting ${name}...`)
  }
  
  endPhase(name: string) {
    const startTime = this.metrics.get(`${name}_start`)
    if (startTime) {
      const duration = Date.now() - startTime
      this.metrics.set(`${name}_duration`, duration)
      console.log(`✅ ${name} completed in ${duration}ms`)
    }
  }
  
  logSummary() {
    console.log('\n📈 Performance Summary:')
    console.log('======================')
    
    const phases = Array.from(this.metrics.keys())
      .filter(key => key.endsWith('_duration'))
      .map(key => key.replace('_duration', ''))
    
    phases.forEach(phase => {
      const duration = this.metrics.get(`${phase}_duration`)
      console.log(`${phase}: ${duration}ms`)
    })
    
    const totalTime = Date.now() - this.startTime
    console.log(`\nTotal time: ${totalTime}ms`)
  }
  
  getRecommendations() {
    const recommendations: string[] = []
    
    // Analyze metrics and provide recommendations
    phases.forEach(phase => {
      const duration = this.metrics.get(`${phase}_duration`) || 0
      
      if (phase === 'build' && duration > 30000) {
        recommendations.push('Consider enabling persistent caching')
      }
      
      if (phase === 'optimization' && duration > 60000) {
        recommendations.push('Review terser configuration')
      }
    })
    
    return recommendations
  }
}

// Usage in build scripts
const monitor = new BuildPerformanceMonitor()

// Webpack plugin integration
class PerformancePlugin {
  apply(compiler: any) {
    const monitor = new BuildPerformanceMonitor()
    
    compiler.hooks.compile.tap('PerformancePlugin', () => {
      monitor.startPhase('compilation')
    })
    
    compiler.hooks.done.tap('PerformancePlugin', () => {
      monitor.endPhase('compilation')
      monitor.logSummary()
      
      const recommendations = monitor.getRecommendations()
      if (recommendations.length > 0) {
        console.log('\n💡 Recommendations:')
        recommendations.forEach(rec => console.log(`  - ${rec}`))
      }
    })
  }
}
```

## 📋 Troubleshooting Checklist

### Quick Resolution Checklist
```markdown
# Build Tool Troubleshooting Checklist

## Initial Diagnostics
- [ ] Check Node.js version (LTS recommended)
- [ ] Verify build tool version
- [ ] Check available system memory
- [ ] Review error logs for specific messages
- [ ] Confirm configuration file syntax

## Common Quick Fixes
- [ ] Clear cache and node_modules
- [ ] Update dependencies to latest versions
- [ ] Check for conflicting global packages
- [ ] Verify environment variables
- [ ] Test with minimal configuration

## Memory Issues
- [ ] Increase Node.js memory limit
- [ ] Disable source maps in development
- [ ] Reduce parallel jobs
- [ ] Enable persistent caching
- [ ] Split large bundles

## Performance Issues
- [ ] Enable build caching
- [ ] Optimize file watching
- [ ] Use faster source maps
- [ ] Exclude unnecessary files
- [ ] Parallelize build tasks

## Module Resolution
- [ ] Check import/export syntax
- [ ] Verify file extensions
- [ ] Review alias configuration
- [ ] Check module paths
- [ ] Test with absolute imports

## Plugin/Loader Issues
- [ ] Update plugin versions
- [ ] Check plugin configuration
- [ ] Test with plugins disabled
- [ ] Review plugin order
- [ ] Check for plugin conflicts
```

---

**Navigation**
- ← Back to: [Migration Strategies](./migration-strategies.md)
- → Next: [Template Examples](./template-examples.md)
- → Related: [Best Practices](./best-practices.md)