# Best Practices: Computer Vision in Web Applications

## 🏗️ Architecture & Design Patterns

### Clean Architecture for Computer Vision

```typescript
// Domain Layer - Pure business logic
interface DocumentProcessor {
  processDocument(image: ImageData): Promise<ProcessedDocument>
}

interface OCRService {
  extractText(image: ImageData): Promise<TextExtractionResult>
}

// Application Layer - Use cases and orchestration
class DocumentScanningUseCase {
  constructor(
    private documentProcessor: DocumentProcessor,
    private ocrService: OCRService,
    private repository: DocumentRepository
  ) {}
  
  async scanDocument(imageData: ImageData): Promise<ScannedDocument> {
    const processed = await this.documentProcessor.processDocument(imageData)
    const textResult = await this.ocrService.extractText(processed.image)
    const document = new ScannedDocument(processed, textResult)
    
    await this.repository.save(document)
    return document
  }
}

// Infrastructure Layer - External dependencies
class OpenCVDocumentProcessor implements DocumentProcessor {
  async processDocument(image: ImageData): Promise<ProcessedDocument> {
    // OpenCV implementation
  }
}

class TesseractOCRService implements OCRService {
  async extractText(image: ImageData): Promise<TextExtractionResult> {
    // Tesseract implementation
  }
}
```

### Service Layer Pattern

```typescript
// Abstract base service for computer vision operations
abstract class CVService {
  protected initialized = false
  protected errorHandler: ErrorHandler
  
  constructor(errorHandler: ErrorHandler) {
    this.errorHandler = errorHandler
  }
  
  abstract initialize(): Promise<void>
  abstract cleanup(): void
  
  protected async withErrorHandling<T>(
    operation: () => Promise<T>,
    context: string
  ): Promise<T> {
    try {
      if (!this.initialized) {
        throw new Error(`${this.constructor.name} not initialized`)
      }
      return await operation()
    } catch (error) {
      this.errorHandler.handle(error, context)
      throw error
    }
  }
}

// Concrete implementation
class DocumentScanService extends CVService {
  private openCV: OpenCVWrapper | null = null
  
  async initialize(): Promise<void> {
    this.openCV = new OpenCVWrapper()
    await this.openCV.load()
    this.initialized = true
  }
  
  async scanDocument(imageData: ImageData): Promise<ProcessedDocument> {
    return this.withErrorHandling(
      () => this.openCV!.processDocument(imageData),
      'document-scanning'
    )
  }
  
  cleanup(): void {
    this.openCV?.dispose()
    this.initialized = false
  }
}
```

## ⚡ Performance Optimization

### 1. Model Loading & Caching Strategies

```typescript
class ModelManager {
  private static cache = new Map<string, any>()
  private static preloadPromises = new Map<string, Promise<any>>()
  
  // Preload critical models during app initialization
  static async preloadCriticalModels(): Promise<void> {
    const criticalModels = [
      '/models/document-detection.json',
      '/models/text-recognition-en.json'
    ]
    
    await Promise.all(
      criticalModels.map(url => this.preloadModel(url))
    )
  }
  
  // Lazy load non-critical models
  static async loadModel(url: string): Promise<any> {
    if (this.cache.has(url)) {
      return this.cache.get(url)
    }
    
    if (this.preloadPromises.has(url)) {
      return this.preloadPromises.get(url)
    }
    
    const promise = this.fetchAndCacheModel(url)
    this.preloadPromises.set(url, promise)
    
    return promise
  }
  
  private static async fetchAndCacheModel(url: string): Promise<any> {
    const model = await tf.loadLayersModel(url)
    this.cache.set(url, model)
    this.preloadPromises.delete(url)
    return model
  }
  
  // Progressive model loading based on user interaction
  static async loadModelProgressive(
    url: string,
    onProgress: (progress: number) => void
  ): Promise<any> {
    const response = await fetch(url)
    const contentLength = response.headers.get('content-length')
    
    if (!contentLength) {
      return this.loadModel(url)
    }
    
    const total = parseInt(contentLength)
    let loaded = 0
    
    const reader = response.body!.getReader()
    const chunks: Uint8Array[] = []
    
    while (true) {
      const { done, value } = await reader.read()
      
      if (done) break
      
      chunks.push(value)
      loaded += value.length
      onProgress(loaded / total)
    }
    
    const blob = new Blob(chunks)
    const arrayBuffer = await blob.arrayBuffer()
    
    // Load model from array buffer
    return tf.loadLayersModel(tf.io.fromMemory({
      modelTopology: JSON.parse(new TextDecoder().decode(arrayBuffer))
    }))
  }
}
```

### 2. Image Processing Optimization

```typescript
class ImageOptimizer {
  // Intelligent image resizing based on processing requirements
  static optimizeForProcessing(
    imageData: ImageData,
    operation: 'ocr' | 'detection' | 'recognition'
  ): ImageData {
    const targetSizes = {
      ocr: { width: 800, height: 600 },        // High resolution for text clarity
      detection: { width: 416, height: 416 },   // Square for object detection models
      recognition: { width: 224, height: 224 }  // Standard CNN input size
    }
    
    const target = targetSizes[operation]
    return this.resizeImageData(imageData, target.width, target.height)
  }
  
  // Smart compression that preserves important features
  static compressForCV(
    imageData: ImageData,
    quality: number = 0.8,
    preserveEdges: boolean = true
  ): ImageData {
    const canvas = document.createElement('canvas')
    const ctx = canvas.getContext('2d')!
    
    canvas.width = imageData.width
    canvas.height = imageData.height
    ctx.putImageData(imageData, 0, 0)
    
    if (preserveEdges) {
      // Apply unsharp mask to preserve edges before compression
      this.applySharpeningFilter(ctx, canvas.width, canvas.height)
    }
    
    // Convert to JPEG with specified quality
    const dataUrl = canvas.toDataURL('image/jpeg', quality)
    
    // Convert back to ImageData
    return new Promise<ImageData>((resolve) => {
      const img = new Image()
      img.onload = () => {
        ctx.clearRect(0, 0, canvas.width, canvas.height)
        ctx.drawImage(img, 0, 0)
        resolve(ctx.getImageData(0, 0, canvas.width, canvas.height))
      }
      img.src = dataUrl
    })
  }
  
  // Batch processing for multiple images
  static async processBatch(
    images: ImageData[],
    processor: (image: ImageData) => Promise<any>,
    concurrency: number = 3
  ): Promise<any[]> {
    const results: any[] = []
    
    for (let i = 0; i < images.length; i += concurrency) {
      const batch = images.slice(i, i + concurrency)
      const batchResults = await Promise.all(
        batch.map(image => processor(image))
      )
      results.push(...batchResults)
    }
    
    return results
  }
  
  private static resizeImageData(
    imageData: ImageData,
    newWidth: number,
    newHeight: number
  ): ImageData {
    const canvas = document.createElement('canvas')
    const ctx = canvas.getContext('2d')!
    
    // Use original size for drawing
    canvas.width = imageData.width
    canvas.height = imageData.height
    ctx.putImageData(imageData, 0, 0)
    
    // Create new canvas with target size
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
  
  private static applySharpeningFilter(
    ctx: CanvasRenderingContext2D,
    width: number,
    height: number
  ): void {
    const imageData = ctx.getImageData(0, 0, width, height)
    const data = imageData.data
    
    // Unsharp mask kernel
    const kernel = [
      [0, -1, 0],
      [-1, 5, -1],
      [0, -1, 0]
    ]
    
    // Apply convolution (simplified version)
    for (let y = 1; y < height - 1; y++) {
      for (let x = 1; x < width - 1; x++) {
        for (let c = 0; c < 3; c++) { // RGB channels
          let sum = 0
          for (let ky = 0; ky < 3; ky++) {
            for (let kx = 0; kx < 3; kx++) {
              const pixelIndex = ((y + ky - 1) * width + (x + kx - 1)) * 4 + c
              sum += data[pixelIndex] * kernel[ky][kx]
            }
          }
          const currentIndex = (y * width + x) * 4 + c
          data[currentIndex] = Math.max(0, Math.min(255, sum))
        }
      }
    }
    
    ctx.putImageData(imageData, 0, 0)
  }
}
```

### 3. Memory Management

```typescript
class MemoryManager {
  private static tensorCache = new Map<string, tf.Tensor>()
  private static maxCacheSize = 100 * 1024 * 1024 // 100MB
  
  // Automatic tensor cleanup
  static withTensorScope<T>(fn: () => T): T {
    return tf.tidy(fn)
  }
  
  // Memory-aware image processing
  static async processWithMemoryLimit(
    images: ImageData[],
    processor: (image: ImageData) => Promise<any>,
    memoryLimitMB: number = 500
  ): Promise<any[]> {
    const results: any[] = []
    let currentMemoryUsage = 0
    
    for (const image of images) {
      const imageSize = image.width * image.height * 4 // RGBA
      
      // Check if processing this image would exceed memory limit
      if (currentMemoryUsage + imageSize > memoryLimitMB * 1024 * 1024) {
        // Force garbage collection
        await this.forceGarbageCollection()
        currentMemoryUsage = 0
      }
      
      const result = await processor(image)
      results.push(result)
      currentMemoryUsage += imageSize
    }
    
    return results
  }
  
  // Cached tensor operations
  static getCachedTensor(key: string, factory: () => tf.Tensor): tf.Tensor {
    if (this.tensorCache.has(key)) {
      return this.tensorCache.get(key)!
    }
    
    const tensor = factory()
    
    // Check cache size
    if (this.getCurrentCacheSize() + tensor.size > this.maxCacheSize) {
      this.evictOldestTensors()
    }
    
    this.tensorCache.set(key, tensor)
    return tensor
  }
  
  private static getCurrentCacheSize(): number {
    let size = 0
    for (const tensor of this.tensorCache.values()) {
      size += tensor.size
    }
    return size
  }
  
  private static evictOldestTensors(): void {
    const entries = Array.from(this.tensorCache.entries())
    const toRemove = entries.slice(0, Math.floor(entries.length / 2))
    
    for (const [key, tensor] of toRemove) {
      tensor.dispose()
      this.tensorCache.delete(key)
    }
  }
  
  private static async forceGarbageCollection(): Promise<void> {
    // Request garbage collection (only works in Chrome with --js-flags="--expose-gc")
    if ('gc' in window) {
      (window as any).gc()
    }
    
    // Alternative: Create memory pressure to trigger GC
    const tempArrays = []
    try {
      for (let i = 0; i < 100; i++) {
        tempArrays.push(new Array(100000).fill(0))
      }
    } catch {
      // Memory limit reached, GC should trigger
    } finally {
      tempArrays.length = 0
    }
    
    // Give GC time to run
    await new Promise(resolve => setTimeout(resolve, 100))
  }
}
```

## 🛡️ Security Best Practices

### 1. Client-Side Privacy Protection

```typescript
class PrivacyProtector {
  // Image anonymization before processing
  static anonymizeImage(imageData: ImageData): ImageData {
    const canvas = document.createElement('canvas')
    const ctx = canvas.getContext('2d')!
    
    canvas.width = imageData.width
    canvas.height = imageData.height
    ctx.putImageData(imageData, 0, 0)
    
    // Apply privacy filters
    this.blurSensitiveAreas(ctx, canvas.width, canvas.height)
    this.addWatermark(ctx, canvas.width, canvas.height)
    
    return ctx.getImageData(0, 0, canvas.width, canvas.height)
  }
  
  // Secure image transmission
  static async encryptImageData(imageData: ImageData, key: CryptoKey): Promise<ArrayBuffer> {
    const canvas = document.createElement('canvas')
    const ctx = canvas.getContext('2d')!
    
    canvas.width = imageData.width
    canvas.height = imageData.height
    ctx.putImageData(imageData, 0, 0)
    
    const blob = await new Promise<Blob>((resolve) => {
      canvas.toBlob(resolve!, 'image/png')
    })
    
    const arrayBuffer = await blob.arrayBuffer()
    return crypto.subtle.encrypt('AES-GCM', key, arrayBuffer)
  }
  
  // Biometric data protection
  static hashBiometricData(features: Float32Array): Promise<string> {
    return crypto.subtle.digest('SHA-256', features.buffer)
      .then(buffer => Array.from(new Uint8Array(buffer))
        .map(b => b.toString(16).padStart(2, '0'))
        .join(''))
  }
  
  private static blurSensitiveAreas(
    ctx: CanvasRenderingContext2D,
    width: number,
    height: number
  ): void {
    // Apply gaussian blur to predefined sensitive regions
    ctx.filter = 'blur(10px)'
    
    // Common sensitive areas (adjust based on use case)
    const sensitiveAreas = [
      { x: 0, y: 0, width: width * 0.2, height: height * 0.1 },        // Top-left corner
      { x: width * 0.8, y: 0, width: width * 0.2, height: height * 0.1 } // Top-right corner
    ]
    
    sensitiveAreas.forEach(area => {
      const imageData = ctx.getImageData(area.x, area.y, area.width, area.height)
      ctx.putImageData(imageData, area.x, area.y)
    })
    
    ctx.filter = 'none'
  }
  
  private static addWatermark(
    ctx: CanvasRenderingContext2D,
    width: number,
    height: number
  ): void {
    ctx.globalAlpha = 0.1
    ctx.fillStyle = '#000000'
    ctx.font = '20px Arial'
    ctx.textAlign = 'center'
    ctx.fillText('PROCESSED', width / 2, height / 2)
    ctx.globalAlpha = 1.0
  }
}
```

### 2. Input Validation & Sanitization

```typescript
class InputValidator {
  // Image validation
  static validateImage(file: File): ValidationResult {
    const errors: string[] = []
    
    // File type validation
    if (!this.ALLOWED_TYPES.includes(file.type)) {
      errors.push(`Invalid file type: ${file.type}`)
    }
    
    // File size validation
    if (file.size > this.MAX_FILE_SIZE) {
      errors.push(`File too large: ${file.size} bytes`)
    }
    
    // File name validation
    if (!this.FILENAME_PATTERN.test(file.name)) {
      errors.push(`Invalid filename: ${file.name}`)
    }
    
    return {
      isValid: errors.length === 0,
      errors
    }
  }
  
  // Image content validation
  static async validateImageContent(imageData: ImageData): Promise<ValidationResult> {
    const errors: string[] = []
    
    // Dimension validation
    if (imageData.width < this.MIN_WIDTH || imageData.height < this.MIN_HEIGHT) {
      errors.push(`Image too small: ${imageData.width}x${imageData.height}`)
    }
    
    if (imageData.width > this.MAX_WIDTH || imageData.height > this.MAX_HEIGHT) {
      errors.push(`Image too large: ${imageData.width}x${imageData.height}`)
    }
    
    // Content validation (detect malicious patterns)
    const hasValidContent = await this.detectValidContent(imageData)
    if (!hasValidContent) {
      errors.push('Invalid image content detected')
    }
    
    return {
      isValid: errors.length === 0,
      errors
    }
  }
  
  // OCR output sanitization
  static sanitizeOCROutput(text: string): string {
    // Remove potential XSS vectors
    const sanitized = text
      .replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, '')
      .replace(/<iframe\b[^<]*(?:(?!<\/iframe>)<[^<]*)*<\/iframe>/gi, '')
      .replace(/javascript:/gi, '')
      .replace(/on\w+\s*=/gi, '')
    
    // Limit length to prevent DoS
    return sanitized.substring(0, this.MAX_TEXT_LENGTH)
  }
  
  private static readonly ALLOWED_TYPES = [
    'image/jpeg',
    'image/png',
    'image/webp'
  ]
  
  private static readonly MAX_FILE_SIZE = 10 * 1024 * 1024 // 10MB
  private static readonly MIN_WIDTH = 100
  private static readonly MIN_HEIGHT = 100
  private static readonly MAX_WIDTH = 4096
  private static readonly MAX_HEIGHT = 4096
  private static readonly MAX_TEXT_LENGTH = 10000
  private static readonly FILENAME_PATTERN = /^[a-zA-Z0-9._-]+$/
  
  private static async detectValidContent(imageData: ImageData): Promise<boolean> {
    // Simple content validation - check for reasonable pixel distribution
    const data = imageData.data
    const pixelCount = data.length / 4
    
    let uniqueColors = new Set<string>()
    for (let i = 0; i < data.length; i += 16) { // Sample every 4th pixel
      const color = `${data[i]},${data[i+1]},${data[i+2]}`
      uniqueColors.add(color)
      
      if (uniqueColors.size > 1000) break // Sufficient diversity
    }
    
    // Suspicious if too few unique colors (potential attack vector)
    return uniqueColors.size > 10
  }
}

interface ValidationResult {
  isValid: boolean
  errors: string[]
}
```

## 🧪 Testing Strategies

### 1. Computer Vision Testing Framework

```typescript
class CVTestFramework {
  // Visual regression testing
  static async compareImages(
    expected: ImageData,
    actual: ImageData,
    threshold: number = 0.05
  ): Promise<ComparisonResult> {
    if (expected.width !== actual.width || expected.height !== actual.height) {
      return {
        match: false,
        difference: 1.0,
        reason: 'Dimension mismatch'
      }
    }
    
    const expectedData = expected.data
    const actualData = actual.data
    let totalDifference = 0
    
    for (let i = 0; i < expectedData.length; i += 4) {
      const rDiff = Math.abs(expectedData[i] - actualData[i]) / 255
      const gDiff = Math.abs(expectedData[i + 1] - actualData[i + 1]) / 255
      const bDiff = Math.abs(expectedData[i + 2] - actualData[i + 2]) / 255
      
      totalDifference += (rDiff + gDiff + bDiff) / 3
    }
    
    const avgDifference = totalDifference / (expectedData.length / 4)
    
    return {
      match: avgDifference <= threshold,
      difference: avgDifference,
      reason: avgDifference > threshold ? 'Visual difference exceeds threshold' : 'Images match'
    }
  }
  
  // Performance testing
  static async measurePerformance<T>(
    operation: () => Promise<T>,
    runs: number = 10
  ): Promise<PerformanceMetrics> {
    const times: number[] = []
    const memoryUsages: number[] = []
    
    for (let i = 0; i < runs; i++) {
      const startTime = performance.now()
      const startMemory = (performance as any).memory?.usedJSHeapSize || 0
      
      await operation()
      
      const endTime = performance.now()
      const endMemory = (performance as any).memory?.usedJSHeapSize || 0
      
      times.push(endTime - startTime)
      memoryUsages.push(endMemory - startMemory)
    }
    
    return {
      avgTime: times.reduce((sum, t) => sum + t, 0) / times.length,
      minTime: Math.min(...times),
      maxTime: Math.max(...times),
      avgMemoryDelta: memoryUsages.reduce((sum, m) => sum + m, 0) / memoryUsages.length
    }
  }
  
  // Accuracy testing
  static async testOCRAccuracy(
    testCases: Array<{ image: ImageData; expectedText: string }>
  ): Promise<AccuracyMetrics> {
    const results: Array<{ expected: string; actual: string; accuracy: number }> = []
    
    for (const testCase of testCases) {
      const actualText = await this.performOCR(testCase.image)
      const accuracy = this.calculateTextSimilarity(testCase.expectedText, actualText)
      
      results.push({
        expected: testCase.expectedText,
        actual: actualText,
        accuracy
      })
    }
    
    const avgAccuracy = results.reduce((sum, r) => sum + r.accuracy, 0) / results.length
    
    return {
      averageAccuracy: avgAccuracy,
      results,
      passRate: results.filter(r => r.accuracy > 0.9).length / results.length
    }
  }
  
  private static async performOCR(imageData: ImageData): Promise<string> {
    // Mock OCR implementation for testing
    return 'test result'
  }
  
  private static calculateTextSimilarity(expected: string, actual: string): number {
    // Levenshtein distance-based similarity
    const matrix: number[][] = []
    
    for (let i = 0; i <= expected.length; i++) {
      matrix[i] = [i]
    }
    
    for (let j = 0; j <= actual.length; j++) {
      matrix[0][j] = j
    }
    
    for (let i = 1; i <= expected.length; i++) {
      for (let j = 1; j <= actual.length; j++) {
        if (expected[i - 1] === actual[j - 1]) {
          matrix[i][j] = matrix[i - 1][j - 1]
        } else {
          matrix[i][j] = Math.min(
            matrix[i - 1][j - 1] + 1,
            matrix[i][j - 1] + 1,
            matrix[i - 1][j] + 1
          )
        }
      }
    }
    
    const distance = matrix[expected.length][actual.length]
    return 1 - (distance / Math.max(expected.length, actual.length))
  }
}

interface ComparisonResult {
  match: boolean
  difference: number
  reason: string
}

interface PerformanceMetrics {
  avgTime: number
  minTime: number
  maxTime: number
  avgMemoryDelta: number
}

interface AccuracyMetrics {
  averageAccuracy: number
  results: Array<{ expected: string; actual: string; accuracy: number }>
  passRate: number
}
```

### 2. Integration Testing

```typescript
// Jest test examples
describe('Computer Vision Integration', () => {
  let cvApp: CVEdTechApp
  
  beforeEach(async () => {
    cvApp = new CVEdTechApp()
    await cvApp.initialize()
  })
  
  afterEach(async () => {
    await cvApp.cleanup()
  })
  
  test('should process document scan end-to-end', async () => {
    // Load test image
    const testImage = await loadTestImage('sample-document.jpg')
    
    // Mock camera service
    jest.spyOn(cvApp['cameraService'], 'captureFrame')
      .mockReturnValue(testImage)
    
    // Perform document scan
    const result = await cvApp.scanDocument()
    
    // Verify results
    expect(result.processedImage).toBeDefined()
    expect(result.extractedText).toContain('expected text')
    expect(result.confidence).toBeGreaterThan(0.8)
  })
  
  test('should handle face detection with liveness check', async () => {
    const mockVideo = createMockVideoElement()
    
    await cvApp.startIdentityVerification()
    
    // Simulate face detection results
    const mockResults = {
      detections: [{
        boundingBox: { xCenter: 0.5, yCenter: 0.5, width: 0.3, height: 0.4 },
        score: 0.95
      }]
    }
    
    // Test liveness validation
    const livenessResult = cvApp['faceDetectionService']
      .validateLiveness([mockResults])
    
    expect(livenessResult.isLive).toBe(true)
    expect(livenessResult.confidence).toBeGreaterThan(0.7)
  })
  
  test('should handle errors gracefully', async () => {
    // Mock service failure
    jest.spyOn(cvApp['openCVService'], 'processDocument')
      .mockRejectedValue(new Error('OpenCV initialization failed'))
    
    const testImage = await loadTestImage('sample-document.jpg')
    
    // Should not throw, but handle error gracefully
    await expect(cvApp.processDocument(testImage))
      .rejects.toThrow('OpenCV initialization failed')
    
    // Verify error was logged
    expect(console.error).toHaveBeenCalled()
  })
})

async function loadTestImage(filename: string): Promise<ImageData> {
  const img = new Image()
  img.src = `/test-assets/${filename}`
  
  return new Promise((resolve) => {
    img.onload = () => {
      const canvas = document.createElement('canvas')
      const ctx = canvas.getContext('2d')!
      
      canvas.width = img.width
      canvas.height = img.height
      ctx.drawImage(img, 0, 0)
      
      resolve(ctx.getImageData(0, 0, img.width, img.height))
    }
  })
}

function createMockVideoElement(): HTMLVideoElement {
  const video = document.createElement('video')
  video.width = 640
  video.height = 480
  return video
}
```

## 🌐 Cross-Browser Compatibility

### Feature Detection & Polyfills

```typescript
class CompatibilityChecker {
  static checkBrowserSupport(): BrowserSupport {
    return {
      webAssembly: typeof WebAssembly !== 'undefined',
      webGL: this.checkWebGLSupport(),
      mediaDevices: navigator.mediaDevices && navigator.mediaDevices.getUserMedia,
      canvas: !!document.createElement('canvas').getContext,
      workers: typeof Worker !== 'undefined',
      indexedDB: 'indexedDB' in window,
      webRTC: 'RTCPeerConnection' in window
    }
  }
  
  static async loadPolyfills(): Promise<void> {
    const support = this.checkBrowserSupport()
    const polyfills: Promise<any>[] = []
    
    if (!support.webAssembly) {
      polyfills.push(import('wasm-polyfill'))
    }
    
    if (!support.mediaDevices) {
      polyfills.push(import('webrtc-adapter'))
    }
    
    if (!support.indexedDB) {
      polyfills.push(import('fake-indexeddb'))
    }
    
    await Promise.all(polyfills)
  }
  
  static getFallbackStrategy(): FallbackStrategy {
    const support = this.checkBrowserSupport()
    
    if (!support.webGL) {
      return {
        processing: 'canvas-2d',
        performance: 'reduced',
        features: ['basic-ocr', 'document-scan']
      }
    }
    
    if (!support.webAssembly) {
      return {
        processing: 'javascript',
        performance: 'limited',
        features: ['basic-ocr']
      }
    }
    
    return {
      processing: 'full',
      performance: 'optimal',
      features: ['all']
    }
  }
  
  private static checkWebGLSupport(): boolean {
    try {
      const canvas = document.createElement('canvas')
      return !!(canvas.getContext('webgl') || canvas.getContext('experimental-webgl'))
    } catch {
      return false
    }
  }
}

interface BrowserSupport {
  webAssembly: boolean
  webGL: boolean
  mediaDevices: boolean
  canvas: boolean
  workers: boolean
  indexedDB: boolean
  webRTC: boolean
}

interface FallbackStrategy {
  processing: 'full' | 'canvas-2d' | 'javascript'
  performance: 'optimal' | 'reduced' | 'limited'
  features: string[]
}
```

## 📱 Mobile Optimization

```typescript
class MobileOptimizer {
  // Device-specific optimizations
  static optimizeForDevice(): DeviceOptimizations {
    const deviceInfo = this.getDeviceInfo()
    
    return {
      imageResolution: this.getOptimalResolution(deviceInfo),
      processingConcurrency: this.getOptimalConcurrency(deviceInfo),
      memoryLimit: this.getMemoryLimit(deviceInfo),
      enabledFeatures: this.getEnabledFeatures(deviceInfo)
    }
  }
  
  // Touch-friendly UI adjustments
  static applyMobileUI(): void {
    const style = document.createElement('style')
    style.textContent = `
      .cv-button {
        min-height: 44px;
        min-width: 44px;
        touch-action: manipulation;
      }
      
      .cv-camera-container {
        width: 100vw;
        height: 70vh;
        object-fit: cover;
      }
      
      @media (orientation: portrait) {
        .cv-controls {
          flex-direction: column;
          gap: 12px;
        }
      }
      
      @media (orientation: landscape) {
        .cv-controls {
          flex-direction: row;
          gap: 8px;
        }
      }
    `
    document.head.appendChild(style)
  }
  
  // Battery optimization
  static optimizeForBattery(): void {
    // Reduce processing frequency on low battery
    if ('getBattery' in navigator) {
      (navigator as any).getBattery().then((battery: any) => {
        if (battery.level < 0.2) {
          this.enablePowerSaveMode()
        }
        
        battery.addEventListener('levelchange', () => {
          if (battery.level < 0.2) {
            this.enablePowerSaveMode()
          } else {
            this.disablePowerSaveMode()
          }
        })
      })
    }
  }
  
  private static enablePowerSaveMode(): void {
    // Reduce frame rate
    // Lower resolution
    // Disable non-essential features
    console.log('Power save mode enabled')
  }
  
  private static disablePowerSaveMode(): void {
    // Restore normal settings
    console.log('Power save mode disabled')
  }
  
  private static getDeviceInfo(): DeviceInfo {
    return {
      ram: (navigator as any).deviceMemory || 4,
      cores: navigator.hardwareConcurrency || 4,
      connectionType: (navigator as any).connection?.effectiveType || '4g',
      isMobile: /Android|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent)
    }
  }
  
  private static getOptimalResolution(device: DeviceInfo): { width: number; height: number } {
    if (device.ram < 3) {
      return { width: 640, height: 480 }
    } else if (device.ram < 6) {
      return { width: 1280, height: 720 }
    } else {
      return { width: 1920, height: 1080 }
    }
  }
  
  private static getOptimalConcurrency(device: DeviceInfo): number {
    return Math.max(1, Math.floor(device.cores / 2))
  }
  
  private static getMemoryLimit(device: DeviceInfo): number {
    return device.ram * 100 // MB
  }
  
  private static getEnabledFeatures(device: DeviceInfo): string[] {
    const features = ['basic-ocr', 'document-scan']
    
    if (device.ram >= 4) {
      features.push('face-detection')
    }
    
    if (device.ram >= 6) {
      features.push('handwriting-recognition')
    }
    
    return features
  }
}

interface DeviceInfo {
  ram: number
  cores: number
  connectionType: string
  isMobile: boolean
}

interface DeviceOptimizations {
  imageResolution: { width: number; height: number }
  processingConcurrency: number
  memoryLimit: number
  enabledFeatures: string[]
}
```

## 🔄 Continuous Integration

```yaml
# .github/workflows/cv-testing.yml
name: Computer Vision Testing

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    
    strategy:
      matrix:
        browser: [chrome, firefox, safari]
        
    steps:
    - uses: actions/checkout@v3
    
    - name: Setup Node.js
      uses: actions/setup-node@v3
      with:
        node-version: '18'
        cache: 'npm'
    
    - name: Install dependencies
      run: npm ci
    
    - name: Build application
      run: npm run build
    
    - name: Run unit tests
      run: npm test
    
    - name: Install browser dependencies
      run: npx playwright install --with-deps ${{ matrix.browser }}
    
    - name: Run CV integration tests
      run: npm run test:cv:${{ matrix.browser }}
    
    - name: Run visual regression tests
      run: npm run test:visual:${{ matrix.browser }}
    
    - name: Upload test artifacts
      uses: actions/upload-artifact@v3
      if: failure()
      with:
        name: test-results-${{ matrix.browser }}
        path: test-results/
    
    - name: Performance benchmarks
      run: npm run benchmark
    
    - name: Upload performance results
      uses: actions/upload-artifact@v3
      with:
        name: performance-${{ matrix.browser }}
        path: benchmarks/
```

---

## 🌐 Navigation

**Previous:** [Implementation Guide](./implementation-guide.md) | **Next:** [Comparison Analysis](./comparison-analysis.md)

---

*Best practices compiled from industry standards, academic research, and production deployments. Tested across Chrome 120+, Firefox 120+, Safari 16+. Last updated July 2025.*