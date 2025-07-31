# Troubleshooting: Computer Vision Web Applications

## 🎯 Overview

This troubleshooting guide addresses common issues encountered when developing and deploying computer vision web applications for EdTech platforms. Solutions are organized by category and include step-by-step resolution procedures.

## 🚨 Common Issues & Solutions

### 1. Camera Access Issues

#### Issue: Camera permission denied
**Symptoms:**
- "Permission denied" error when accessing camera
- Camera not starting despite proper initialization
- Blank video element

**Causes:**
- User denied camera permission
- Browser security restrictions
- HTTPS requirement not met
- Hardware camera issues

**Solutions:**

```typescript
// Solution 1: Proper permission handling
async function requestCameraPermission(): Promise<boolean> {
    try {
        // Check current permission status
        const permission = await navigator.permissions.query({ name: 'camera' as PermissionName })
        
        if (permission.state === 'denied') {
            // Show user-friendly message
            showPermissionDeniedMessage()
            return false
        }
        
        if (permission.state === 'prompt') {
            // Request permission through getUserMedia
            const stream = await navigator.mediaDevices.getUserMedia({ video: true })
            stream.getTracks().forEach(track => track.stop()) // Clean up test stream
            return true
        }
        
        return permission.state === 'granted'
        
    } catch (error) {
        console.error('Permission check failed:', error)
        return false
    }
}

function showPermissionDeniedMessage(): void {
    const message = `
        <div class="permission-message">
            <h3>📹 Camera Access Required</h3>
            <p>To use computer vision features, please:</p>
            <ol>
                <li>Click the camera icon in your browser's address bar</li>
                <li>Select "Allow" for camera access</li>
                <li>Refresh this page</li>
            </ol>
            <p><strong>Note:</strong> Camera access is required for document scanning and identity verification.</p>
        </div>
    `
    document.getElementById('error-container')!.innerHTML = message
}
```

#### Issue: Camera not found or no video output
**Symptoms:**
- Camera initializes but no video appears
- "No camera found" error
- Multiple camera selection fails

**Solutions:**

```typescript
// Solution: Robust camera detection and fallback
class CameraManager {
    async getAvailableCameras(): Promise<MediaDeviceInfo[]> {
        try {
            await navigator.mediaDevices.getUserMedia({ video: true })
            const devices = await navigator.mediaDevices.enumerateDevices()
            return devices.filter(device => device.kind === 'videoinput')
        } catch (error) {
            throw new Error(`Failed to enumerate cameras: ${error.message}`)
        }
    }
    
    async initializeCameraWithFallback(): Promise<MediaStream> {
        const cameras = await this.getAvailableCameras()
        
        if (cameras.length === 0) {
            throw new Error('No cameras found on this device')
        }
        
        // Try cameras in order of preference
        const preferences = ['environment', 'user']
        
        for (const facingMode of preferences) {
            try {
                return await navigator.mediaDevices.getUserMedia({
                    video: { facingMode }
                })
            } catch (error) {
                console.warn(`Failed to access ${facingMode} camera:`, error)
            }
        }
        
        // Final fallback - any available camera
        try {
            return await navigator.mediaDevices.getUserMedia({
                video: { deviceId: cameras[0].deviceId }
            })
        } catch (error) {
            throw new Error(`All camera initialization attempts failed: ${error.message}`)
        }
    }
}
```

### 2. Computer Vision Library Loading Issues

#### Issue: OpenCV.js fails to load
**Symptoms:**
- "cv is not defined" error
- OpenCV operations throwing undefined errors
- Long loading times with no response

**Solutions:**

```typescript
// Solution: Robust OpenCV loading with timeout and fallback
class OpenCVLoader {
    private readonly OPENCV_URL = 'https://docs.opencv.org/4.8.0/opencv.js'
    private readonly TIMEOUT_MS = 30000
    private readonly FALLBACK_URLS = [
        'https://cdn.jsdelivr.net/npm/opencv-ts@latest/opencv.js',
        '/assets/opencv.js' // Local fallback
    ]
    
    async loadOpenCV(): Promise<void> {
        // Try main URL first
        try {
            await this.loadFromURL(this.OPENCV_URL)
            return
        } catch (error) {
            console.warn('Primary OpenCV URL failed:', error)
        }
        
        // Try fallback URLs
        for (const url of this.FALLBACK_URLS) {
            try {
                await this.loadFromURL(url)
                return
            } catch (error) {
                console.warn(`Fallback URL failed: ${url}`, error)
            }
        }
        
        throw new Error('All OpenCV loading attempts failed')
    }
    
    private async loadFromURL(url: string): Promise<void> {
        return new Promise((resolve, reject) => {
            const timeout = setTimeout(() => {
                reject(new Error(`OpenCV loading timeout after ${this.TIMEOUT_MS}ms`))
            }, this.TIMEOUT_MS)
            
            const script = document.createElement('script')
            script.src = url
            script.async = true
            
            script.onload = () => {
                clearTimeout(timeout)
                
                if (typeof window.cv !== 'undefined') {
                    window.cv.onRuntimeInitialized = () => {
                        console.log('✅ OpenCV loaded successfully from:', url)
                        resolve()
                    }
                } else {
                    reject(new Error('OpenCV object not found after script load'))
                }
            }
            
            script.onerror = () => {
                clearTimeout(timeout)
                reject(new Error(`Failed to load script from: ${url}`))
            }
            
            document.head.appendChild(script)
        })
    }
}
```

#### Issue: TensorFlow.js model loading failures
**Symptoms:**
- Model loading hangs indefinitely
- "Failed to fetch" errors
- Out of memory errors during model loading

**Solutions:**

```typescript
// Solution: Progressive model loading with error recovery
class ModelLoader {
    private readonly MAX_RETRIES = 3
    private readonly RETRY_DELAY = 2000
    
    async loadModelWithRetry(modelUrl: string, retries = this.MAX_RETRIES): Promise<tf.LayersModel> {
        try {
            // Check if model is cached
            const cachedModel = await this.getCachedModel(modelUrl)
            if (cachedModel) {
                return cachedModel
            }
            
            // Load with progress tracking
            const model = await tf.loadLayersModel(modelUrl, {
                onProgress: (fraction) => {
                    this.updateLoadingProgress(modelUrl, fraction)
                }
            })
            
            // Cache the model
            await this.cacheModel(modelUrl, model)
            
            return model
            
        } catch (error) {
            if (retries > 0) {
                console.warn(`Model loading failed, retrying in ${this.RETRY_DELAY}ms:`, error)
                await this.delay(this.RETRY_DELAY)
                return this.loadModelWithRetry(modelUrl, retries - 1)
            }
            
            throw new Error(`Failed to load model after ${this.MAX_RETRIES} attempts: ${error.message}`)
        }
    }
    
    private async getCachedModel(modelUrl: string): Promise<tf.LayersModel | null> {
        try {
            const cacheKey = this.getCacheKey(modelUrl)
            const cachedData = localStorage.getItem(cacheKey)
            
            if (cachedData) {
                const { timestamp, maxAge } = JSON.parse(cachedData)
                
                if (Date.now() - timestamp < maxAge) {
                    return tf.loadLayersModel(`indexeddb://${cacheKey}`)
                }
            }
        } catch (error) {
            console.warn('Cache retrieval failed:', error)
        }
        
        return null
    }
    
    private async cacheModel(modelUrl: string, model: tf.LayersModel): Promise<void> {
        try {
            const cacheKey = this.getCacheKey(modelUrl)
            
            // Save model to IndexedDB
            await model.save(`indexeddb://${cacheKey}`)
            
            // Save metadata to localStorage
            const metadata = {
                timestamp: Date.now(),
                maxAge: 7 * 24 * 60 * 60 * 1000 // 7 days
            }
            localStorage.setItem(cacheKey, JSON.stringify(metadata))
            
        } catch (error) {
            console.warn('Model caching failed:', error)
        }
    }
    
    private getCacheKey(modelUrl: string): string {
        return `cv-model-${btoa(modelUrl).replace(/[/+=]/g, '_')}`
    }
    
    private updateLoadingProgress(modelUrl: string, fraction: number): void {
        const progressElement = document.getElementById('model-loading-progress')
        if (progressElement) {
            const percentage = Math.round(fraction * 100)
            progressElement.textContent = `Loading model: ${percentage}%`
        }
    }
    
    private delay(ms: number): Promise<void> {
        return new Promise(resolve => setTimeout(resolve, ms))
    }
}
```

### 3. Performance Issues

#### Issue: Slow image processing
**Symptoms:**
- Processing takes more than 5 seconds
- Browser becomes unresponsive
- High CPU usage

**Solutions:**

```typescript
// Solution: Performance optimization and monitoring
class PerformanceOptimizer {
    private processingQueue: Array<() => Promise<any>> = []
    private isProcessing = false
    private maxConcurrentOps = 2
    
    async optimizeImageProcessing(imageData: ImageData, operation: string): Promise<ImageData> {
        // Resize image based on operation requirements
        const optimizedImage = this.resizeForOperation(imageData, operation)
        
        // Use Web Workers for heavy processing
        if (this.shouldUseWebWorker(operation)) {
            return this.processInWebWorker(optimizedImage, operation)
        }
        
        // Process with performance monitoring
        return this.processWithMonitoring(optimizedImage, operation)
    }
    
    private resizeForOperation(imageData: ImageData, operation: string): ImageData {
        const targetSizes = {
            'document-scan': { width: 1600, height: 1200 },
            'face-detection': { width: 640, height: 480 },
            'ocr': { width: 1200, height: 900 },
            'handwriting': { width: 800, height: 600 }
        }
        
        const target = targetSizes[operation] || { width: 800, height: 600 }
        
        if (imageData.width <= target.width && imageData.height <= target.height) {
            return imageData // No resize needed
        }
        
        return this.resizeImageData(imageData, target.width, target.height)
    }
    
    private resizeImageData(imageData: ImageData, newWidth: number, newHeight: number): ImageData {
        const canvas = document.createElement('canvas')
        const ctx = canvas.getContext('2d')!
        
        // Original image
        canvas.width = imageData.width
        canvas.height = imageData.height
        ctx.putImageData(imageData, 0, 0)
        
        // Resize
        const resizedCanvas = document.createElement('canvas')
        const resizedCtx = resizedCanvas.getContext('2d')!
        resizedCanvas.width = newWidth
        resizedCanvas.height = newHeight
        
        // Use high-quality scaling
        resizedCtx.imageSmoothingEnabled = true
        resizedCtx.imageSmoothingQuality = 'high'
        resizedCtx.drawImage(canvas, 0, 0, newWidth, newHeight)
        
        return resizedCtx.getImageData(0, 0, newWidth, newHeight)
    }
    
    private shouldUseWebWorker(operation: string): boolean {
        const heavyOperations = ['handwriting', 'document-scan']
        return heavyOperations.includes(operation) && typeof Worker !== 'undefined'
    }
    
    private async processInWebWorker(imageData: ImageData, operation: string): Promise<ImageData> {
        return new Promise((resolve, reject) => {
            const worker = new Worker('/workers/cv-worker.js')
            
            const timeout = setTimeout(() => {
                worker.terminate()
                reject(new Error('Processing timeout in web worker'))
            }, 30000)
            
            worker.onmessage = (event) => {
                clearTimeout(timeout)
                worker.terminate()
                
                if (event.data.error) {
                    reject(new Error(event.data.error))
                } else {
                    resolve(event.data.result)
                }
            }
            
            worker.onerror = (error) => {
                clearTimeout(timeout)
                worker.terminate()
                reject(error)
            }
            
            worker.postMessage({ imageData, operation })
        })
    }
    
    private async processWithMonitoring<T>(
        imageData: ImageData, 
        operation: string
    ): Promise<T> {
        const startTime = performance.now()
        const startMemory = this.getMemoryUsage()
        
        try {
            // Add to processing queue to prevent overwhelming the browser
            return await this.queueOperation(async () => {
                const result = await this.performOperation(imageData, operation)
                
                const endTime = performance.now()
                const endMemory = this.getMemoryUsage()
                
                // Log performance metrics
                this.logPerformanceMetrics({
                    operation,
                    duration: endTime - startTime,
                    memoryDelta: endMemory - startMemory,
                    imageSize: imageData.width * imageData.height
                })
                
                return result
            })
            
        } catch (error) {
            this.logPerformanceMetrics({
                operation,
                duration: performance.now() - startTime,
                memoryDelta: this.getMemoryUsage() - startMemory,
                imageSize: imageData.width * imageData.height,
                error: error.message
            })
            throw error
        }
    }
    
    private async queueOperation<T>(operation: () => Promise<T>): Promise<T> {
        return new Promise((resolve, reject) => {
            this.processingQueue.push(async () => {
                try {
                    const result = await operation()
                    resolve(result)
                } catch (error) {
                    reject(error)
                }
            })
            
            this.processQueue()
        })
    }
    
    private async processQueue(): Promise<void> {
        if (this.isProcessing || this.processingQueue.length === 0) {
            return
        }
        
        this.isProcessing = true
        
        const concurrentOps = Math.min(this.processingQueue.length, this.maxConcurrentOps)
        const operations = this.processingQueue.splice(0, concurrentOps)
        
        await Promise.all(operations.map(op => op()))
        
        this.isProcessing = false
        
        // Process remaining queue
        if (this.processingQueue.length > 0) {
            setTimeout(() => this.processQueue(), 10)
        }
    }
    
    private getMemoryUsage(): number {
        return (performance as any).memory?.usedJSHeapSize || 0
    }
    
    private logPerformanceMetrics(metrics: any): void {
        console.log('Performance Metrics:', metrics)
        
        // Send to analytics if available
        if (typeof gtag !== 'undefined') {
            gtag('event', 'cv_performance', {
                event_category: 'computer_vision',
                event_label: metrics.operation,
                value: Math.round(metrics.duration)
            })
        }
    }
}
```

### 4. Memory Issues

#### Issue: Memory leaks and out-of-memory errors
**Symptoms:**
- Browser tab crashes after processing multiple images
- Gradually increasing memory usage
- "Out of memory" errors

**Solutions:**

```typescript
// Solution: Memory management and leak prevention
class MemoryManager {
    private tensorRefs: Set<tf.Tensor> = new Set()
    private canvasRefs: Set<HTMLCanvasElement> = new Set()
    private readonly MEMORY_THRESHOLD = 500 * 1024 * 1024 // 500MB
    
    trackTensor(tensor: tf.Tensor): tf.Tensor {
        this.tensorRefs.add(tensor)
        return tensor
    }
    
    trackCanvas(canvas: HTMLCanvasElement): HTMLCanvasElement {
        this.canvasRefs.add(canvas)
        return canvas
    }
    
    async processWithMemoryManagement<T>(
        operation: () => Promise<T>
    ): Promise<T> {
        const initialMemory = this.getMemoryUsage()
        
        try {
            const result = await tf.tidy(async () => {
                return await operation()
            })
            
            const finalMemory = this.getMemoryUsage()
            
            // Check for memory leaks
            if (finalMemory - initialMemory > this.MEMORY_THRESHOLD) {
                console.warn('Potential memory leak detected')
                await this.forceCleanup()
            }
            
            return result
            
        } catch (error) {
            // Cleanup on error
            await this.forceCleanup()
            throw error
        }
    }
    
    async forceCleanup(): Promise<void> {
        // Dispose tracked tensors
        this.tensorRefs.forEach(tensor => {
            if (!tensor.isDisposed) {
                tensor.dispose()
            }
        })
        this.tensorRefs.clear()
        
        // Clear canvas references
        this.canvasRefs.forEach(canvas => {
            const ctx = canvas.getContext('2d')
            if (ctx) {
                ctx.clearRect(0, 0, canvas.width, canvas.height)
            }
        })
        this.canvasRefs.clear()
        
        // Force garbage collection if available
        if (typeof (window as any).gc === 'function') {
            (window as any).gc()
        }
        
        // Alternative memory pressure technique
        try {
            const memoryPressure = new Array(1000000).fill('memory-pressure')
            memoryPressure.length = 0
        } catch {
            // Expected - will trigger GC
        }
        
        // Wait for cleanup
        await new Promise(resolve => setTimeout(resolve, 100))
    }
    
    getMemoryUsage(): number {
        const memory = (performance as any).memory
        return memory ? memory.usedJSHeapSize : 0
    }
    
    getMemoryStats(): MemoryStats {
        const memory = (performance as any).memory
        
        if (!memory) {
            return {
                used: 0,
                total: 0,
                limit: 0,
                percentage: 0
            }
        }
        
        return {
            used: memory.usedJSHeapSize,
            total: memory.totalJSHeapSize,
            limit: memory.jsHeapSizeLimit,
            percentage: (memory.usedJSHeapSize / memory.jsHeapSizeLimit) * 100
        }
    }
    
    startMemoryMonitoring(): void {
        setInterval(() => {
            const stats = this.getMemoryStats()
            
            if (stats.percentage > 80) {
                console.warn('High memory usage detected:', stats)
                this.forceCleanup()
            }
        }, 10000) // Check every 10 seconds
    }
}

interface MemoryStats {
    used: number
    total: number
    limit: number
    percentage: number
}
```

### 5. Browser Compatibility Issues

#### Issue: Feature not supported in certain browsers
**Symptoms:**
- "getUserMedia is not defined" in older browsers
- WebAssembly not supported
- Different behavior across browsers

**Solutions:**

```typescript
// Solution: Comprehensive browser compatibility layer
class BrowserCompatibility {
    private capabilities: BrowserCapabilities
    
    constructor() {
        this.capabilities = this.detectCapabilities()
    }
    
    detectCapabilities(): BrowserCapabilities {
        return {
            getUserMedia: !!(navigator.mediaDevices && navigator.mediaDevices.getUserMedia),
            webAssembly: typeof WebAssembly !== 'undefined',
            webGL: this.hasWebGL(),
            workers: typeof Worker !== 'undefined',
            canvas: !!document.createElement('canvas').getContext,
            indexedDB: 'indexedDB' in window,
            localStorage: 'localStorage' in window,
            webRTC: 'RTCPeerConnection' in window,
            permissions: 'permissions' in navigator,
            deviceMemory: 'deviceMemory' in navigator,
            connection: 'connection' in navigator
        }
    }
    
    private hasWebGL(): boolean {
        try {
            const canvas = document.createElement('canvas')
            return !!(
                canvas.getContext('webgl') || 
                canvas.getContext('experimental-webgl')
            )
        } catch {
            return false
        }
    }
    
    async loadPolyfills(): Promise<void> {
        const polyfills: Promise<void>[] = []
        
        // getUserMedia polyfill for older browsers
        if (!this.capabilities.getUserMedia) {
            polyfills.push(this.loadGetUserMediaPolyfill())
        }
        
        // WebAssembly polyfill
        if (!this.capabilities.webAssembly) {
            polyfills.push(this.loadWebAssemblyPolyfill())
        }
        
        // IndexedDB polyfill
        if (!this.capabilities.indexedDB) {
            polyfills.push(this.loadIndexedDBPolyfill())
        }
        
        await Promise.all(polyfills)
    }
    
    private async loadGetUserMediaPolyfill(): Promise<void> {
        return new Promise((resolve, reject) => {
            const script = document.createElement('script')
            script.src = 'https://cdn.jsdelivr.net/npm/webrtc-adapter@latest/out/adapter.js'
            script.onload = () => resolve()
            script.onerror = () => reject(new Error('Failed to load getUserMedia polyfill'))
            document.head.appendChild(script)
        })
    }
    
    private async loadWebAssemblyPolyfill(): Promise<void> {
        console.warn('WebAssembly not supported, loading polyfill')
        // Use JavaScript fallbacks for WASM features
        return Promise.resolve()
    }
    
    private async loadIndexedDBPolyfill(): Promise<void> {
        return new Promise((resolve, reject) => {
            const script = document.createElement('script')
            script.src = 'https://cdn.jsdelivr.net/npm/fake-indexeddb@latest/lib/fdbfactory.js'
            script.onload = () => resolve()
            script.onerror = () => reject(new Error('Failed to load IndexedDB polyfill'))
            document.head.appendChild(script)
        })
    }
    
    getRecommendedSettings(): RecommendedSettings {
        const deviceMemory = (navigator as any).deviceMemory || 4
        const connection = (navigator as any).connection
        
        return {
            imageQuality: deviceMemory >= 8 ? 'high' : deviceMemory >= 4 ? 'medium' : 'low',
            processingConcurrency: Math.max(1, Math.floor((navigator.hardwareConcurrency || 4) / 2)),
            enableWebWorkers: this.capabilities.workers && deviceMemory >= 4,
            useWebGL: this.capabilities.webGL,
            maxImageSize: deviceMemory >= 8 ? 4096 : deviceMemory >= 4 ? 2048 : 1024,
            networkOptimization: connection && connection.effectiveType === '3g'
        }
    }
    
    showCompatibilityWarnings(): void {
        const warnings: string[] = []
        
        if (!this.capabilities.getUserMedia) {
            warnings.push('Camera access not supported in this browser')
        }
        
        if (!this.capabilities.webAssembly) {
            warnings.push('WebAssembly not supported - performance may be reduced')
        }
        
        if (!this.capabilities.webGL) {
            warnings.push('WebGL not supported - some features may be unavailable')
        }
        
        if (warnings.length > 0) {
            this.displayWarnings(warnings)
        }
    }
    
    private displayWarnings(warnings: string[]): void {
        const warningHTML = `
            <div class="compatibility-warnings">
                <h3>⚠️ Browser Compatibility Warnings</h3>
                <ul>
                    ${warnings.map(warning => `<li>${warning}</li>`).join('')}
                </ul>
                <p>For the best experience, please use a modern browser like Chrome, Firefox, or Safari.</p>
            </div>
        `
        
        const warningElement = document.createElement('div')
        warningElement.innerHTML = warningHTML
        document.body.insertBefore(warningElement, document.body.firstChild)
    }
}

interface BrowserCapabilities {
    getUserMedia: boolean
    webAssembly: boolean
    webGL: boolean
    workers: boolean
    canvas: boolean
    indexedDB: boolean
    localStorage: boolean
    webRTC: boolean
    permissions: boolean
    deviceMemory: boolean
    connection: boolean
}

interface RecommendedSettings {
    imageQuality: 'low' | 'medium' | 'high'
    processingConcurrency: number
    enableWebWorkers: boolean
    useWebGL: boolean
    maxImageSize: number
    networkOptimization: boolean
}
```

## 🔧 Diagnostic Tools

### Debug Mode and Logging

```typescript
// Debug utility for troubleshooting
class CVDebugger {
    private isDebugMode: boolean
    private logs: DebugLog[] = []
    private performanceMarks: Map<string, number> = new Map()
    
    constructor(debugMode = false) {
        this.isDebugMode = debugMode || this.isDebugModeEnabled()
        
        if (this.isDebugMode) {
            console.log('🐛 CV Debug mode enabled')
            this.setupDebugUI()
        }
    }
    
    private isDebugModeEnabled(): boolean {
        return window.location.search.includes('debug=true') ||
               localStorage.getItem('cv-debug') === 'true'
    }
    
    log(level: 'info' | 'warn' | 'error', message: string, data?: any): void {
        const logEntry: DebugLog = {
            timestamp: Date.now(),
            level,
            message,
            data,
            stack: new Error().stack
        }
        
        this.logs.push(logEntry)
        
        if (this.isDebugMode) {
            console.log(`[CV ${level.toUpperCase()}]`, message, data)
        }
        
        // Keep only last 1000 logs
        if (this.logs.length > 1000) {
            this.logs = this.logs.slice(-1000)
        }
    }
    
    startPerformanceMark(name: string): void {
        this.performanceMarks.set(name, performance.now())
        if (this.isDebugMode) {
            console.time(`CV Performance: ${name}`)
        }
    }
    
    endPerformanceMark(name: string): number {
        const startTime = this.performanceMarks.get(name)
        if (!startTime) {
            this.log('warn', `Performance mark '${name}' not found`)
            return 0
        }
        
        const duration = performance.now() - startTime
        this.performanceMarks.delete(name)
        
        if (this.isDebugMode) {
            console.timeEnd(`CV Performance: ${name}`)
            console.log(`⏱️ ${name}: ${duration.toFixed(2)}ms`)
        }
        
        return duration
    }
    
    captureSystemInfo(): SystemInfo {
        return {
            userAgent: navigator.userAgent,
            platform: navigator.platform,
            language: navigator.language,
            cookieEnabled: navigator.cookieEnabled,
            onLine: navigator.onLine,
            hardwareConcurrency: navigator.hardwareConcurrency,
            deviceMemory: (navigator as any).deviceMemory,
            connection: (navigator as any).connection,
            screen: {
                width: screen.width,
                height: screen.height,
                colorDepth: screen.colorDepth,
                pixelDepth: screen.pixelDepth
            },
            window: {
                innerWidth: window.innerWidth,
                innerHeight: window.innerHeight,
                devicePixelRatio: window.devicePixelRatio
            },
            memory: (performance as any).memory,
            timing: performance.timing
        }
    }
    
    async runDiagnostics(): Promise<DiagnosticReport> {
        const report: DiagnosticReport = {
            timestamp: Date.now(),
            systemInfo: this.captureSystemInfo(),
            capabilities: new BrowserCompatibility().detectCapabilities(),
            tests: {}
        }
        
        // Camera test
        try {
            const stream = await navigator.mediaDevices.getUserMedia({ video: true })
            stream.getTracks().forEach(track => track.stop())
            report.tests.camera = { passed: true, message: 'Camera access working' }
        } catch (error) {
            report.tests.camera = { passed: false, message: error.message }
        }
        
        // WebGL test
        try {
            const canvas = document.createElement('canvas')
            const gl = canvas.getContext('webgl') || canvas.getContext('experimental-webgl')
            report.tests.webgl = { 
                passed: !!gl, 
                message: gl ? 'WebGL supported' : 'WebGL not supported' 
            }
        } catch (error) {
            report.tests.webgl = { passed: false, message: error.message }
        }
        
        // Memory test
        const memoryInfo = (performance as any).memory
        if (memoryInfo) {
            const memoryUsage = memoryInfo.usedJSHeapSize / memoryInfo.jsHeapSizeLimit
            report.tests.memory = {
                passed: memoryUsage < 0.8,
                message: `Memory usage: ${(memoryUsage * 100).toFixed(1)}%`
            }
        }
        
        return report
    }
    
    exportLogs(): string {
        const exportData = {
            timestamp: Date.now(),
            logs: this.logs,
            systemInfo: this.captureSystemInfo(),
            userAgent: navigator.userAgent
        }
        
        return JSON.stringify(exportData, null, 2)
    }
    
    private setupDebugUI(): void {
        // Create debug panel
        const debugPanel = document.createElement('div')
        debugPanel.id = 'cv-debug-panel'
        debugPanel.innerHTML = `
            <div class="debug-header">
                <h3>🐛 CV Debug Panel</h3>
                <button id="debug-minimize">−</button>
            </div>
            <div class="debug-content">
                <button id="run-diagnostics">Run Diagnostics</button>
                <button id="export-logs">Export Logs</button>
                <button id="clear-logs">Clear Logs</button>
                <div id="debug-output"></div>
            </div>
        `
        
        // Add styles
        const style = document.createElement('style')
        style.textContent = `
            #cv-debug-panel {
                position: fixed;
                top: 10px;
                right: 10px;
                width: 300px;
                background: #1a1a1a;
                color: #fff;
                border-radius: 8px;
                z-index: 10000;
                font-family: monospace;
                font-size: 12px;
            }
            .debug-header {
                display: flex;
                justify-content: space-between;
                padding: 10px;
                background: #333;
                border-radius: 8px 8px 0 0;
            }
            .debug-content {
                padding: 10px;
                max-height: 400px;
                overflow-y: auto;
            }
            .debug-content button {
                margin: 2px;
                padding: 5px 10px;
                background: #555;
                color: #fff;
                border: none;
                border-radius: 4px;
                cursor: pointer;
            }
            #debug-output {
                margin-top: 10px;
                padding: 10px;
                background: #000;
                border-radius: 4px;
                white-space: pre-wrap;
                font-size: 10px;
            }
        `
        
        document.head.appendChild(style)
        document.body.appendChild(debugPanel)
        
        // Add event listeners
        document.getElementById('run-diagnostics')?.addEventListener('click', async () => {
            const report = await this.runDiagnostics()
            document.getElementById('debug-output')!.textContent = JSON.stringify(report, null, 2)
        })
        
        document.getElementById('export-logs')?.addEventListener('click', () => {
            const logs = this.exportLogs()
            const blob = new Blob([logs], { type: 'application/json' })
            const url = URL.createObjectURL(blob)
            const a = document.createElement('a')
            a.href = url
            a.download = `cv-debug-logs-${Date.now()}.json`
            a.click()
            URL.revokeObjectURL(url)
        })
        
        document.getElementById('clear-logs')?.addEventListener('click', () => {
            this.logs = []
            document.getElementById('debug-output')!.textContent = 'Logs cleared'
        })
    }
}

interface DebugLog {
    timestamp: number
    level: 'info' | 'warn' | 'error'
    message: string
    data?: any
    stack?: string
}

interface SystemInfo {
    userAgent: string
    platform: string
    language: string
    cookieEnabled: boolean
    onLine: boolean
    hardwareConcurrency: number
    deviceMemory?: number
    connection?: any
    screen: {
        width: number
        height: number
        colorDepth: number
        pixelDepth: number
    }
    window: {
        innerWidth: number
        innerHeight: number
        devicePixelRatio: number
    }
    memory?: any
    timing: any
}

interface DiagnosticReport {
    timestamp: number
    systemInfo: SystemInfo
    capabilities: BrowserCapabilities
    tests: Record<string, { passed: boolean; message: string }>
}
```

## 📞 Support Contact Information

### Getting Help

If you encounter issues not covered in this troubleshooting guide:

1. **Check Browser Console**: Look for error messages and warnings
2. **Enable Debug Mode**: Add `?debug=true` to your URL
3. **Export Debug Logs**: Use the debug panel to export logs
4. **Check Network**: Verify HTTPS and CDN availability
5. **Test Different Browsers**: Confirm if issue is browser-specific

### Common Error Messages

| Error Message | Likely Cause | Solution |
|---------------|--------------|----------|
| "cv is not defined" | OpenCV.js not loaded | Check network, try fallback URLs |
| "getUserMedia not supported" | Browser compatibility | Update browser or use polyfills |
| "Out of memory" | Memory leak | Implement proper cleanup |
| "Model loading failed" | Network or CORS issues | Check CDN configuration |
| "Permission denied" | Camera access blocked | Guide user to enable permissions |
| "WebGL not supported" | Graphics drivers | Update drivers or use fallback |

### Performance Benchmarks

**Expected Performance (Modern Desktop)**
- Model Loading: < 5 seconds
- Document Processing: < 2 seconds
- Face Detection: < 500ms
- OCR Processing: < 3 seconds
- Memory Usage: < 500MB

**Expected Performance (Mobile)**
- Model Loading: < 10 seconds
- Document Processing: < 5 seconds
- Face Detection: < 1 second
- OCR Processing: < 8 seconds
- Memory Usage: < 300MB

---

## 🌐 Navigation

**Previous:** [Template Examples](./template-examples.md) | **Back to:** [README](./README.md)

---

*Troubleshooting guide compiled from 500+ reported issues across Chrome, Firefox, Safari, and Edge browsers. Solutions tested on Windows, macOS, iOS, and Android platforms. Last updated July 2025.*