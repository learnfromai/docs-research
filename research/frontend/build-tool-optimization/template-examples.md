# Template Examples: Ready-to-Use Configurations

## 🎯 Overview

Complete collection of production-ready configuration templates for Webpack, Vite, and Rollup optimized for EdTech applications, including project setup, build configurations, and deployment-ready examples.

## 🚀 Quick Start Templates

### Project Type Matrix

| Project Type | Recommended Tool | Template | Features |
|-------------|------------------|----------|----------|
| **New EdTech Platform** | Vite + React | [EdTech Vite](#edtech-vite-template) | PWA, Math, Video |
| **Component Library** | Rollup | [Library Rollup](#library-rollup-template) | Multi-format, TypeScript |
| **Enterprise Migration** | Webpack 5 | [Enterprise Webpack](#enterprise-webpack-template) | Module Federation |
| **Learning Management** | Vite + Vue | [LMS Vite](#lms-vite-template) | Real-time, Analytics |
| **Mobile-First EdTech** | Vite + React | [Mobile Vite](#mobile-vite-template) | PWA, Offline |

## 📱 EdTech Vite Template

### Complete Project Setup
```bash
#!/bin/bash
# create-edtech-app.sh - Complete EdTech platform setup

echo "🎓 Creating EdTech Platform with Vite"

# Create project
npm create vite@latest edtech-platform -- --template react-ts
cd edtech-platform

# Install core dependencies
npm install react-router-dom @mui/material @emotion/react @emotion/styled
npm install @mui/icons-material @mui/lab date-fns

# Install EdTech specific dependencies
npm install video.js @videojs/themes react-player
npm install mathjax katex react-katex
npm install chart.js react-chartjs-2
npm install react-hook-form yup @hookform/resolvers

# Install development dependencies
npm install -D @vitejs/plugin-react vite-plugin-pwa
npm install -D rollup-plugin-visualizer vite-plugin-eslint
npm install -D @types/video.js @types/katex
npm install -D cypress vitest @testing-library/react

echo "✅ Dependencies installed"

# Create directory structure
mkdir -p src/{components,features,hooks,services,utils,types,assets}
mkdir -p src/features/{lessons,quiz,analytics,auth,dashboard}
mkdir -p src/components/{ui,forms,media,charts}
mkdir -p public/{icons,images,videos}

echo "✅ Directory structure created"
```

### Vite Configuration
```typescript
// vite.config.ts - Production-ready EdTech configuration
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import { VitePWA } from 'vite-plugin-pwa'
import { visualizer } from 'rollup-plugin-visualizer'
import eslint from 'vite-plugin-eslint'
import { resolve } from 'path'

export default defineConfig(({ command, mode }) => {
  const isProduction = mode === 'production'
  
  return {
    plugins: [
      // React plugin with Fast Refresh
      react({
        jsxRuntime: 'automatic',
        fastRefresh: true
      }),
      
      // ESLint integration
      eslint({
        include: ['src/**/*.ts', 'src/**/*.tsx'],
        exclude: ['node_modules', 'dist'],
        cache: true
      }),
      
      // Progressive Web App
      VitePWA({
        registerType: 'autoUpdate',
        includeAssets: ['favicon.ico', 'apple-touch-icon.png'],
        manifest: {
          name: 'EdTech Platform - Philippine Licensure Exam Prep',
          short_name: 'EdTech PH',
          description: 'Comprehensive exam preparation for Philippine professional licensure',
          theme_color: '#1976d2',
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
          runtimeCaching: [
            // API caching
            {
              urlPattern: /^https:\/\/api\.edtech\.ph\//,
              handler: 'CacheFirst',
              options: {
                cacheName: 'api-cache',
                expiration: {
                  maxEntries: 100,
                  maxAgeSeconds: 60 * 60 * 24 // 24 hours
                }
              }
            },
            // Video content caching
            {
              urlPattern: /^https:\/\/cdn\.edtech\.ph\/videos\//,
              handler: 'CacheFirst',
              options: {
                cacheName: 'video-cache',
                expiration: {
                  maxEntries: 50,
                  maxAgeSeconds: 60 * 60 * 24 * 7 // 1 week
                }
              }
            },
            // Image caching
            {
              urlPattern: /\.(?:png|jpg|jpeg|svg|gif|webp)$/,
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
      
      // Bundle analysis
      isProduction && visualizer({
        filename: 'dist/stats.html',
        open: false,
        gzipSize: true,
        brotliSize: true
      })
    ].filter(Boolean),
    
    // Development server configuration
    server: {
      port: 3000,
      host: true,
      open: true,
      proxy: {
        '/api': {
          target: process.env.VITE_API_BASE_URL || 'http://localhost:8000',
          changeOrigin: true,
          secure: false
        }
      }
    },
    
    // Pre-bundling optimization
    optimizeDeps: {
      include: [
        'react',
        'react-dom',
        'react-router-dom',
        '@mui/material',
        '@emotion/react',
        '@emotion/styled',
        'video.js',
        'mathjax',
        'chart.js'
      ]
    },
    
    // Build configuration
    build: {
      target: 'es2020',
      outDir: 'dist',
      sourcemap: !isProduction,
      minify: 'terser',
      terserOptions: {
        compress: {
          drop_console: isProduction,
          drop_debugger: true
        }
      },
      rollupOptions: {
        output: {
          manualChunks: {
            // Core React
            'react': ['react', 'react-dom', 'react-router-dom'],
            
            // UI Framework
            'ui': ['@mui/material', '@emotion/react', '@emotion/styled'],
            
            // Educational features
            'lessons': [resolve(__dirname, 'src/features/lessons')],
            'quiz': [resolve(__dirname, 'src/features/quiz')],
            'analytics': [resolve(__dirname, 'src/features/analytics')],
            
            // Media libraries
            'media': ['video.js', 'react-player'],
            
            // Math rendering
            'math': ['mathjax', 'katex', 'react-katex'],
            
            // Charts and visualization
            'charts': ['chart.js', 'react-chartjs-2']
          }
        }
      },
      chunkSizeWarningLimit: 1000
    },
    
    // Path resolution
    resolve: {
      alias: {
        '@': resolve(__dirname, './src'),
        '@components': resolve(__dirname, './src/components'),
        '@features': resolve(__dirname, './src/features'),
        '@hooks': resolve(__dirname, './src/hooks'),
        '@services': resolve(__dirname, './src/services'),
        '@utils': resolve(__dirname, './src/utils'),
        '@types': resolve(__dirname, './src/types'),
        '@assets': resolve(__dirname, './src/assets')
      }
    },
    
    // Environment variables
    define: {
      __APP_VERSION__: JSON.stringify(process.env.npm_package_version),
      __BUILD_TIME__: JSON.stringify(new Date().toISOString())
    }
  }
})
```

### Package.json Template
```json
{
  "name": "edtech-platform",
  "version": "1.0.0",
  "description": "Philippine Licensure Exam Preparation Platform",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "tsc && vite build",
    "build:analyze": "tsc && vite build --mode analyze",
    "build:staging": "tsc && vite build --mode staging",
    "preview": "vite preview",
    "test": "vitest",
    "test:ui": "vitest --ui",
    "test:coverage": "vitest run --coverage",
    "test:e2e": "cypress open",
    "test:e2e:ci": "cypress run",
    "lint": "eslint src --ext ts,tsx --report-unused-disable-directives --max-warnings 0",
    "lint:fix": "eslint src --ext ts,tsx --fix",
    "type-check": "tsc --noEmit",
    "perf:lighthouse": "lighthouse http://localhost:3000 --output=json --output=html --output-path=./reports/lighthouse",
    "perf:build-size": "npm run build && du -sh dist/*",
    "clean": "rm -rf dist node_modules/.vite",
    "prepare": "husky install"
  },
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-router-dom": "^6.8.0",
    "@mui/material": "^5.11.0",
    "@emotion/react": "^11.10.0",
    "@emotion/styled": "^11.10.0",
    "@mui/icons-material": "^5.11.0",
    "@mui/lab": "^5.0.0-alpha.120",
    "video.js": "^8.0.0",
    "react-player": "^2.11.0",
    "mathjax": "^3.2.0",
    "katex": "^0.16.0",
    "react-katex": "^3.0.0",
    "chart.js": "^4.2.0",
    "react-chartjs-2": "^5.2.0",
    "react-hook-form": "^7.43.0",
    "yup": "^1.0.0",
    "@hookform/resolvers": "^2.9.0",
    "date-fns": "^2.29.0",
    "web-vitals": "^3.1.0"
  },
  "devDependencies": {
    "@vitejs/plugin-react": "^4.0.0",
    "vite": "^5.0.0",
    "vite-plugin-pwa": "^0.17.0",
    "rollup-plugin-visualizer": "^5.9.0",
    "vite-plugin-eslint": "^1.8.0",
    "typescript": "^5.0.0",
    "@types/react": "^18.0.0",
    "@types/react-dom": "^18.0.0",
    "@types/video.js": "^7.3.0",
    "@types/katex": "^0.16.0",
    "eslint": "^8.35.0",
    "@typescript-eslint/eslint-plugin": "^5.54.0",
    "@typescript-eslint/parser": "^5.54.0",
    "eslint-plugin-react-hooks": "^4.6.0",
    "eslint-plugin-react-refresh": "^0.3.4",
    "vitest": "^1.0.0",
    "cypress": "^13.0.0",
    "@testing-library/react": "^14.0.0",
    "@testing-library/jest-dom": "^6.0.0",
    "husky": "^8.0.0",
    "lint-staged": "^13.0.0"
  },
  "lint-staged": {
    "src/**/*.{ts,tsx}": [
      "eslint --fix",
      "prettier --write"
    ]
  },
  "engines": {
    "node": ">=18.0.0",
    "npm": ">=8.0.0"
  }
}
```

## 📚 Component Library Rollup Template

### Library Project Setup
```bash
#!/bin/bash
# create-edtech-library.sh - EdTech component library setup

echo "📚 Creating EdTech Component Library"

# Initialize project
npm init -y

# Update package.json for library
npm pkg set name="@edtech/components"
npm pkg set version="1.0.0"
npm pkg set description="EdTech React Components Library"
npm pkg set main="dist/index.cjs.js"
npm pkg set module="dist/index.esm.js"
npm pkg set types="dist/types/index.d.ts"
npm pkg set files='["dist"]'

# Install dependencies
npm install --save-dev rollup typescript
npm install --save-dev @rollup/plugin-node-resolve @rollup/plugin-commonjs
npm install --save-dev @rollup/plugin-typescript rollup-plugin-terser
npm install --save-dev rollup-plugin-postcss rollup-plugin-peer-deps-external
npm install --save-dev rollup-plugin-visualizer @rollup/plugin-json

# Install peer dependencies as dev dependencies
npm install --save-dev react react-dom @types/react @types/react-dom

# EdTech specific dependencies
npm install --save-dev @types/video.js @types/katex

# Create directory structure
mkdir -p src/{components,utils,types,styles}
mkdir -p src/components/{ui,forms,media,charts,math}

echo "✅ Library setup complete"
```

### Rollup Configuration
```javascript
// rollup.config.js - Multi-format library build
import { defineConfig } from 'rollup'
import resolve from '@rollup/plugin-node-resolve'
import commonjs from '@rollup/plugin-commonjs'
import typescript from '@rollup/plugin-typescript'
import { terser } from 'rollup-plugin-terser'
import postcss from 'rollup-plugin-postcss'
import peerDepsExternal from 'rollup-plugin-peer-deps-external'
import { visualizer } from 'rollup-plugin-visualizer'
import json from '@rollup/plugin-json'

const packageJson = require('./package.json')

const createConfig = (format, file, additionalPlugins = []) => ({
  input: 'src/index.ts',
  output: {
    file,
    format,
    sourcemap: true,
    exports: format === 'cjs' ? 'auto' : 'named',
    ...(format === 'umd' && {
      name: 'EdTechComponents',
      globals: {
        react: 'React',
        'react-dom': 'ReactDOM',
        'video.js': 'videojs',
        'katex': 'katex'
      }
    })
  },
  external: ['react', 'react-dom', 'video.js', 'katex', 'chart.js'],
  plugins: [
    // Externalize peer dependencies
    peerDepsExternal(),
    
    // Resolve node modules
    resolve({
      browser: format === 'umd',
      preferBuiltins: false
    }),
    
    // Handle CommonJS modules
    commonjs(),
    
    // Handle JSON imports
    json(),
    
    // TypeScript compilation
    typescript({
      tsconfig: './tsconfig.json',
      declaration: format === 'esm', // Only generate types once
      declarationDir: format === 'esm' ? 'dist/types' : undefined,
      exclude: ['**/*.test.*', '**/*.stories.*']
    }),
    
    // Process CSS
    postcss({
      extract: true,
      minimize: true,
      sourceMap: true
    }),
    
    // Additional plugins
    ...additionalPlugins
  ],
  
  // Tree-shaking optimization
  treeshake: {
    propertyReadSideEffects: false,
    pureExternalModules: true
  }
})

export default defineConfig([
  // ES Module build
  createConfig('esm', packageJson.module),
  
  // CommonJS build
  createConfig('cjs', packageJson.main),
  
  // UMD build for browsers
  createConfig('umd', 'dist/index.umd.js', [
    terser({
      compress: {
        drop_console: true,
        drop_debugger: true
      }
    })
  ]),
  
  // Individual component builds for tree-shaking
  {
    input: {
      'LessonCard': 'src/components/ui/LessonCard/index.ts',
      'QuizEngine': 'src/components/forms/QuizEngine/index.ts',
      'VideoPlayer': 'src/components/media/VideoPlayer/index.ts',
      'MathRenderer': 'src/components/math/MathRenderer/index.ts',
      'AnalyticsChart': 'src/components/charts/AnalyticsChart/index.ts'
    },
    output: {
      dir: 'dist/components',
      format: 'esm',
      sourcemap: true,
      preserveModules: true,
      preserveModulesRoot: 'src/components'
    },
    external: ['react', 'react-dom', 'video.js', 'katex', 'chart.js'],
    plugins: [
      peerDepsExternal(),
      resolve(),
      commonjs(),
      typescript(),
      postcss({ extract: false, inject: false }),
      // Bundle analysis
      visualizer({
        filename: 'dist/components-analysis.html',
        open: false
      })
    ]
  }
])
```

### Library Package.json
```json
{
  "name": "@edtech/components",
  "version": "1.0.0",
  "description": "EdTech React Components Library for Philippine Education",
  "main": "dist/index.cjs.js",
  "module": "dist/index.esm.js",
  "types": "dist/types/index.d.ts",
  "files": ["dist"],
  "exports": {
    ".": {
      "import": "./dist/index.esm.js",
      "require": "./dist/index.cjs.js",
      "types": "./dist/types/index.d.ts"
    },
    "./components/*": {
      "import": "./dist/components/*/index.js",
      "types": "./dist/components/*/index.d.ts"
    },
    "./styles": "./dist/styles.css"
  },
  "sideEffects": ["**/*.css"],
  "scripts": {
    "build": "rollup -c",
    "build:watch": "rollup -c -w",
    "build:analyze": "rollup -c --environment ANALYZE:true",
    "test": "jest",
    "test:watch": "jest --watch",
    "test:coverage": "jest --coverage",
    "lint": "eslint src --ext .ts,.tsx",
    "lint:fix": "eslint src --ext .ts,.tsx --fix",
    "type-check": "tsc --noEmit",
    "storybook": "storybook dev -p 6006",
    "build-storybook": "storybook build",
    "prepublishOnly": "npm run build && npm run test",
    "size-limit": "size-limit",
    "size": "bundlesize"
  },
  "peerDependencies": {
    "react": ">=17.0.0",
    "react-dom": ">=17.0.0"
  },
  "devDependencies": {
    "rollup": "^4.0.0",
    "@rollup/plugin-node-resolve": "^15.0.0",
    "@rollup/plugin-commonjs": "^25.0.0",
    "@rollup/plugin-typescript": "^11.0.0",
    "rollup-plugin-terser": "^7.0.0",
    "rollup-plugin-postcss": "^4.0.0",
    "rollup-plugin-peer-deps-external": "^2.2.0",
    "rollup-plugin-visualizer": "^5.9.0",
    "typescript": "^5.0.0",
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "@types/react": "^18.0.0",
    "@types/react-dom": "^18.0.0"
  },
  "keywords": [
    "react",
    "components",
    "edtech",
    "education",
    "philippines",
    "typescript",
    "ui-library"
  ],
  "repository": {
    "type": "git",
    "url": "https://github.com/your-org/edtech-components"
  },
  "license": "MIT",
  "bundlesize": [
    {
      "path": "./dist/index.esm.js",
      "maxSize": "50 kB"
    }
  ]
}
```

## 🏢 Enterprise Webpack Template

### Webpack 5 Configuration
```javascript
// webpack.config.js - Enterprise-grade configuration
const path = require('path')
const HtmlWebpackPlugin = require('html-webpack-plugin')
const MiniCssExtractPlugin = require('mini-css-extract-plugin')
const { ModuleFederationPlugin } = require('@module-federation/webpack')
const TerserPlugin = require('terser-webpack-plugin')
const { BundleAnalyzerPlugin } = require('webpack-bundle-analyzer')
const ForkTsCheckerWebpackPlugin = require('fork-ts-checker-webpack-plugin')

module.exports = (env, argv) => {
  const isProduction = argv.mode === 'production'
  const isDevelopment = !isProduction
  
  return {
    mode: argv.mode,
    
    // Multiple entry points for micro-frontend architecture
    entry: {
      shell: './src/shell/index.tsx',
      vendor: './src/vendor.ts'
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
      publicPath: 'auto'
    },
    
    resolve: {
      extensions: ['.tsx', '.ts', '.js', '.jsx'],
      alias: {
        '@': path.resolve(__dirname, 'src'),
        '@shell': path.resolve(__dirname, 'src/shell'),
        '@shared': path.resolve(__dirname, 'src/shared'),
        '@components': path.resolve(__dirname, 'src/components'),
        '@services': path.resolve(__dirname, 'src/services'),
        '@utils': path.resolve(__dirname, 'src/utils')
      }
    },
    
    module: {
      rules: [
        // TypeScript/JavaScript
        {
          test: /\.(ts|tsx|js|jsx)$/,
          exclude: /node_modules/,
          use: [
            {
              loader: 'ts-loader',
              options: {
                transpileOnly: true,
                experimentalWatchApi: true
              }
            }
          ]
        },
        
        // CSS/SCSS
        {
          test: /\.(css|scss)$/,
          use: [
            isProduction ? MiniCssExtractPlugin.loader : 'style-loader',
            {
              loader: 'css-loader',
              options: {
                modules: {
                  auto: true,
                  localIdentName: isProduction 
                    ? '[hash:base64:8]'
                    : '[local]--[hash:base64:5]'
                }
              }
            },
            'sass-loader'
          ]
        },
        
        // Assets
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
        },
        
        // Fonts
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
      // HTML template
      new HtmlWebpackPlugin({
        template: './public/index.html',
        inject: true,
        minify: isProduction
      }),
      
      // Module Federation for micro-frontends
      new ModuleFederationPlugin({
        name: 'shell',
        
        // Expose shell components
        exposes: {
          './Navigation': './src/shell/components/Navigation',
          './Layout': './src/shell/components/Layout',
          './AuthProvider': './src/shell/providers/AuthProvider'
        },
        
        // Consume remote modules
        remotes: {
          lessons: 'lessons@http://localhost:3001/remoteEntry.js',
          quiz: 'quiz@http://localhost:3002/remoteEntry.js',
          analytics: 'analytics@http://localhost:3003/remoteEntry.js',
          admin: 'admin@http://localhost:3004/remoteEntry.js'
        },
        
        // Shared dependencies
        shared: {
          react: {
            singleton: true,
            requiredVersion: '^18.2.0'
          },
          'react-dom': {
            singleton: true,
            requiredVersion: '^18.2.0'
          },
          'react-router-dom': {
            singleton: true,
            requiredVersion: '^6.8.0'
          },
          '@mui/material': {
            singleton: true,
            requiredVersion: '^5.11.0'
          }
        }
      }),
      
      // Type checking in separate process
      new ForkTsCheckerWebpackPlugin({
        typescript: {
          diagnosticOptions: {
            semantic: true,
            syntactic: true
          }
        },
        eslint: {
          files: './src/**/*.{ts,tsx}'
        }
      }),
      
      // Production plugins
      ...(isProduction ? [
        new MiniCssExtractPlugin({
          filename: '[name].[contenthash:8].css',
          chunkFilename: '[name].[contenthash:8].chunk.css'
        })
      ] : []),
      
      // Bundle analysis
      ...(env.ANALYZE ? [
        new BundleAnalyzerPlugin({
          analyzerMode: 'static',
          openAnalyzer: false,
          reportFilename: 'bundle-report.html'
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
              drop_debugger: true
            }
          }
        })
      ],
      
      splitChunks: {
        chunks: 'all',
        cacheGroups: {
          // React ecosystem
          react: {
            test: /[\\/]node_modules[\\/](react|react-dom|react-router)[\\/]/,
            name: 'react',
            chunks: 'all',
            priority: 40
          },
          
          // UI framework
          ui: {
            test: /[\\/]node_modules[\\/](@mui|@emotion)[\\/]/,
            name: 'ui',
            chunks: 'all',
            priority: 35
          },
          
          // Shared utilities
          shared: {
            test: /[\\/]src[\\/]shared[\\/]/,
            name: 'shared',
            chunks: 'all',
            priority: 30,
            minChunks: 2
          },
          
          // Vendor libraries
          vendor: {
            test: /[\\/]node_modules[\\/]/,
            name: 'vendor',
            chunks: 'all',
            priority: 20
          }
        }
      },
      
      runtimeChunk: {
        name: entrypoint => `runtime-${entrypoint.name}`
      }
    },
    
    // Performance budgets
    performance: {
      maxAssetSize: 250000,
      maxEntrypointSize: 400000,
      hints: isProduction ? 'error' : 'warning'
    },
    
    // Development server
    devServer: isDevelopment ? {
      port: 3000,
      hot: true,
      compress: true,
      historyApiFallback: true,
      client: {
        overlay: {
          errors: true,
          warnings: false
        }
      }
    } : undefined,
    
    // Source maps
    devtool: isProduction 
      ? 'source-map'
      : 'eval-cheap-module-source-map',
    
    // Enable persistent caching
    cache: {
      type: 'filesystem',
      buildDependencies: {
        config: [__filename]
      }
    }
  }
}
```

## 📱 Mobile-First EdTech Template

### Mobile-Optimized Vite Config
```typescript
// vite.config.ts - Mobile-first EdTech configuration
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import { VitePWA } from 'vite-plugin-pwa'
import legacy from '@vitejs/plugin-legacy'

export default defineConfig({
  plugins: [
    react(),
    
    // PWA with offline-first approach
    VitePWA({
      registerType: 'autoUpdate',
      strategies: 'injectManifest',
      srcDir: 'src',
      filename: 'sw.ts',
      manifest: {
        name: 'Mobile EdTech - Offline Learning',
        short_name: 'EdTech Mobile',
        description: 'Offline-capable education platform',
        theme_color: '#1976d2',
        background_color: '#ffffff',
        display: 'standalone',
        orientation: 'portrait-primary',
        start_url: '/',
        scope: '/',
        categories: ['education', 'productivity'],
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
        // Offline-first strategy
        runtimeCaching: [
          // Essential app shell
          {
            urlPattern: /^https:\/\/fonts\.googleapis\.com/,
            handler: 'StaleWhileRevalidate',
            options: {
              cacheName: 'google-fonts-stylesheets'
            }
          },
          // Lesson content for offline access
          {
            urlPattern: /^https:\/\/api\.edtech\.ph\/lessons/,
            handler: 'CacheFirst',
            options: {
              cacheName: 'lessons-cache',
              expiration: {
                maxEntries: 100,
                maxAgeSeconds: 60 * 60 * 24 * 7 // 1 week
              }
            }
          }
        ]
      }
    }),
    
    // Legacy browser support
    legacy({
      targets: ['defaults', 'not IE 11']
    })
  ],
  
  build: {
    // Mobile-optimized build
    target: 'es2015',
    rollupOptions: {
      output: {
        manualChunks: {
          // Critical path
          'critical': ['react', 'react-dom'],
          
          // Route-based chunks for better loading
          'home': ['./src/pages/Home'],
          'lesson': ['./src/pages/Lesson'],
          'quiz': ['./src/pages/Quiz'],
          'offline': ['./src/pages/Offline']
        }
      }
    },
    // Aggressive minification for mobile
    minify: 'terser',
    terserOptions: {
      compress: {
        drop_console: true,
        drop_debugger: true,
        pure_funcs: ['console.log']
      }
    }
  },
  
  // Mobile-specific optimizations
  server: {
    host: '0.0.0.0', // Allow mobile device access
    port: 3000
  }
})
```

## 🔧 Development Scripts Collection

### Universal Build Scripts
```bash
#!/bin/bash
# scripts/universal-build.sh - Works with any build tool

echo "🔧 Universal Build Script"

# Detect build tool
detect_build_tool() {
  if [ -f "webpack.config.js" ]; then
    echo "webpack"
  elif [ -f "vite.config.ts" ] || [ -f "vite.config.js" ]; then
    echo "vite"
  elif grep -q "react-scripts" package.json; then
    echo "cra"
  else
    echo "unknown"
  fi
}

BUILD_TOOL=$(detect_build_tool)
echo "Detected build tool: $BUILD_TOOL"

# Build based on detected tool
case $BUILD_TOOL in
  "webpack")
    echo "Building with Webpack..."
    npm run build
    ;;
  "vite")
    echo "Building with Vite..."
    npm run build
    ;;
  "cra")
    echo "Building with Create React App..."
    npm run build
    ;;
  *)
    echo "Unknown build tool, trying npm run build..."
    npm run build
    ;;
esac

# Post-build analysis
echo "📊 Build Analysis:"
echo "Output directory size: $(du -sh dist build 2>/dev/null | cut -f1)"
echo "Number of files: $(find dist build -type f 2>/dev/null | wc -l)"

echo "✅ Build complete!"
```

### Performance Testing Script
```bash
#!/bin/bash
# scripts/performance-test.sh - Universal performance testing

echo "🚀 Performance Testing"

# Start dev server in background
case $(detect_build_tool) in
  "webpack")
    npm run start &
    ;;
  "vite")
    npm run dev &
    ;;
  "cra")
    npm run start &
    ;;
esac

SERVER_PID=$!
echo "Started server with PID: $SERVER_PID"

# Wait for server to start
sleep 10

# Run Lighthouse audit
echo "Running Lighthouse audit..."
npx lighthouse http://localhost:3000 \
  --output=json \
  --output=html \
  --output-path=./reports/lighthouse-$(date +%Y%m%d-%H%M%S) \
  --chrome-flags="--headless --no-sandbox"

# Bundle size analysis
echo "Analyzing bundle size..."
npm run build
du -sh dist build 2>/dev/null

# Kill server
kill $SERVER_PID

echo "✅ Performance testing complete!"
```

---

**Navigation**
- ← Back to: [Troubleshooting](./troubleshooting.md)
- → Next: Update SUMMARY.md
- → Related: [Implementation Guide](./implementation-guide.md)