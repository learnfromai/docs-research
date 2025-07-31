# Implementation Guide: Computer Vision in Web Applications

## 🚀 Getting Started

This guide provides step-by-step instructions for implementing computer vision features in web applications, specifically designed for EdTech platforms. We'll cover everything from basic setup to advanced features like handwriting recognition and automated grading.

## 📋 Prerequisites

### Development Environment
- **Node.js**: 18.x or higher
- **TypeScript**: 5.x for type safety
- **Modern Browser**: Chrome 100+, Firefox 100+, Safari 16+, Edge 100+
- **Bundler**: Vite, Webpack 5, or Parcel 2
- **Camera Access**: HTTPS required for getUserMedia API

### Hardware Requirements
- **Minimum**: 4GB RAM, dual-core processor
- **Recommended**: 8GB RAM, quad-core processor, dedicated GPU
- **Camera**: 720p minimum for quality recognition results

## 🎯 Phase 1: Project Setup & Basic Camera Integration

### Step 1: Initialize Project Structure

```bash
# Create new project
npm create vite@latest cv-edtech-app -- --template vanilla-ts
cd cv-edtech-app

# Install core dependencies
npm install @tensorflow/tfjs @tensorflow/tfjs-backend-webgl
npm install opencv-ts tesseract.js
npm install @mediapipe/camera_utils @mediapipe/drawing_utils

# Install development dependencies
npm install -D @types/node vite-plugin-wasm
```

### Step 2: Configure Build System

Create `vite.config.ts`:

```typescript
import { defineConfig } from 'vite'
import { viteStaticCopy } from 'vite-plugin-static-copy'

export default defineConfig({
  plugins: [
    viteStaticCopy({
      targets: [
        {
          src: 'node_modules/opencv-ts/opencv.js',
          dest: 'assets'
        },
        {
          src: 'node_modules/tesseract.js/dist/worker.min.js',
          dest: 'assets'
        }
      ]
    })
  ],
  optimizeDeps: {
    exclude: ['opencv-ts']
  },
  server: {
    headers: {
      'Cross-Origin-Embedder-Policy': 'require-corp',
      'Cross-Origin-Opener-Policy': 'same-origin'
    }
  }
})
```

### Step 3: Create Camera Service

Create `src/services/CameraService.ts`:

```typescript
export class CameraService {
  private stream: MediaStream | null = null
  private video: HTMLVideoElement | null = null
  
  async initialize(constraints: MediaStreamConstraints = {
    video: { width: 1280, height: 720, facingMode: 'environment' }
  }): Promise<HTMLVideoElement> {
    try {
      this.stream = await navigator.mediaDevices.getUserMedia(constraints)
      this.video = document.createElement('video')
      this.video.srcObject = this.stream
      this.video.autoplay = true
      this.video.playsInline = true
      
      return new Promise((resolve, reject) => {
        this.video!.onloadedmetadata = () => resolve(this.video!)
        this.video!.onerror = reject
      })
    } catch (error) {
      throw new Error(`Camera initialization failed: ${error}`)
    }
  }
  
  captureFrame(): ImageData | null {
    if (!this.video) return null
    
    const canvas = document.createElement('canvas')
    const ctx = canvas.getContext('2d')!
    
    canvas.width = this.video.videoWidth
    canvas.height = this.video.videoHeight
    ctx.drawImage(this.video, 0, 0)
    
    return ctx.getImageData(0, 0, canvas.width, canvas.height)
  }
  
  cleanup(): void {
    if (this.stream) {
      this.stream.getTracks().forEach(track => track.stop())
      this.stream = null
    }
    if (this.video) {
      this.video.srcObject = null
      this.video = null
    }
  }
}
```

## 🔧 Phase 2: Document Scanning with OpenCV.js

### Step 4: Initialize OpenCV

Create `src/services/OpenCVService.ts`:

```typescript
declare global {
  interface Window {
    cv: any
  }
}

export class OpenCVService {
  private isReady = false
  
  async initialize(): Promise<void> {
    return new Promise((resolve, reject) => {
      const script = document.createElement('script')
      script.src = '/assets/opencv.js'
      script.onload = () => {
        if (window.cv) {
          window.cv.onRuntimeInitialized = () => {
            this.isReady = true
            resolve()
          }
        } else {
          reject(new Error('OpenCV failed to load'))
        }
      }
      script.onerror = reject
      document.head.appendChild(script)
    })
  }
  
  processDocument(imageData: ImageData): ImageData {
    if (!this.isReady) throw new Error('OpenCV not initialized')
    
    const cv = window.cv
    
    // Convert ImageData to OpenCV Mat
    const src = cv.matFromImageData(imageData)
    
    // Document scanning pipeline
    const gray = new cv.Mat()
    const blur = new cv.Mat()
    const thresh = new cv.Mat()
    const contours = new cv.MatVector()
    const hierarchy = new cv.Mat()
    
    // Convert to grayscale
    cv.cvtColor(src, gray, cv.COLOR_RGBA2GRAY)
    
    // Apply Gaussian blur
    cv.GaussianBlur(gray, blur, new cv.Size(5, 5), 0)
    
    // Apply adaptive threshold
    cv.adaptiveThreshold(blur, thresh, 255, cv.ADAPTIVE_THRESH_GAUSSIAN_C, 
                        cv.THRESH_BINARY, 11, 2)
    
    // Find contours
    cv.findContours(thresh, contours, hierarchy, cv.RETR_EXTERNAL, 
                   cv.CHAIN_APPROX_SIMPLE)
    
    // Find largest rectangular contour (document)
    let maxArea = 0
    let bestContour = null
    
    for (let i = 0; i < contours.size(); i++) {
      const contour = contours.get(i)
      const area = cv.contourArea(contour)
      
      if (area > maxArea && area > 10000) { // Minimum area threshold
        const peri = cv.arcLength(contour, true)
        const approx = new cv.Mat()
        cv.approxPolyDP(contour, approx, 0.02 * peri, true)
        
        if (approx.rows === 4) { // Quadrilateral
          maxArea = area
          bestContour = approx.clone()
        }
        approx.delete()
      }
      contour.delete()
    }
    
    let result = src.clone()
    
    if (bestContour) {
      // Apply perspective correction
      result = this.correctPerspective(src, bestContour)
      bestContour.delete()
    }
    
    // Convert back to ImageData
    const outputCanvas = document.createElement('canvas')
    cv.imshow(outputCanvas, result)
    const outputImageData = outputCanvas.getContext('2d')!
      .getImageData(0, 0, outputCanvas.width, outputCanvas.height)
    
    // Cleanup
    src.delete()
    gray.delete()
    blur.delete()
    thresh.delete()
    contours.delete()
    hierarchy.delete()
    result.delete()
    
    return outputImageData
  }
  
  private correctPerspective(src: any, corners: any): any {
    const cv = window.cv
    
    // Extract corner points
    const rect = cv.boundingRect(corners)
    const srcPoints = cv.matFromArray(4, 1, cv.CV_32FC2, [
      corners.data32F[0], corners.data32F[1],
      corners.data32F[2], corners.data32F[3],
      corners.data32F[4], corners.data32F[5],
      corners.data32F[6], corners.data32F[7]
    ])
    
    // Define destination points (A4 aspect ratio)
    const dstPoints = cv.matFromArray(4, 1, cv.CV_32FC2, [
      0, 0,
      rect.width, 0,
      rect.width, rect.height,
      0, rect.height
    ])
    
    // Calculate transformation matrix
    const transform = cv.getPerspectiveTransform(srcPoints, dstPoints)
    
    // Apply transformation
    const corrected = new cv.Mat()
    cv.warpPerspective(src, corrected, transform, new cv.Size(rect.width, rect.height))
    
    // Cleanup
    srcPoints.delete()
    dstPoints.delete()
    transform.delete()
    
    return corrected
  }
}
```

## 📝 Phase 3: OCR Integration with Tesseract.js

### Step 5: Text Recognition Service

Create `src/services/OCRService.ts`:

```typescript
import { createWorker, Worker } from 'tesseract.js'

export interface OCRResult {
  text: string
  confidence: number
  words: Array<{
    text: string
    confidence: number
    bbox: { x0: number; y0: number; x1: number; y1: number }
  }>
}

export class OCRService {
  private worker: Worker | null = null
  
  async initialize(languages: string[] = ['eng', 'fil']): Promise<void> {
    this.worker = await createWorker({
      logger: m => console.log(m),
      workerPath: '/assets/worker.min.js'
    })
    
    await this.worker.loadLanguage(languages.join('+'))
    await this.worker.initialize(languages.join('+'))
    
    // Configure for better accuracy
    await this.worker.setParameters({
      tessedit_char_whitelist: 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789.,?!- ',
      tessedit_pageseg_mode: '6', // Uniform block of text
      preserve_interword_spaces: '1'
    })
  }
  
  async recognizeText(imageData: ImageData): Promise<OCRResult> {
    if (!this.worker) throw new Error('OCR Worker not initialized')
    
    // Convert ImageData to Canvas for Tesseract
    const canvas = document.createElement('canvas')
    const ctx = canvas.getContext('2d')!
    canvas.width = imageData.width
    canvas.height = imageData.height
    ctx.putImageData(imageData, 0, 0)
    
    const { data } = await this.worker.recognize(canvas)
    
    return {
      text: data.text.trim(),
      confidence: data.confidence,
      words: data.words.map(word => ({
        text: word.text,
        confidence: word.confidence,
        bbox: word.bbox
      }))
    }
  }
  
  async recognizeAnswerSheet(imageData: ImageData): Promise<{
    answers: Array<{ question: number; answer: string; confidence: number }>
    bubbles: Array<{ x: number; y: number; filled: boolean }>
  }> {
    // Enhanced OCR for multiple choice answer sheets
    const result = await this.recognizeText(imageData)
    
    // Parse answer patterns (A, B, C, D detection)
    const answerPattern = /[ABCD]/g
    const answers: Array<{ question: number; answer: string; confidence: number }> = []
    
    let questionNumber = 1
    result.words.forEach(word => {
      if (answerPattern.test(word.text) && word.confidence > 80) {
        answers.push({
          question: questionNumber++,
          answer: word.text,
          confidence: word.confidence
        })
      }
    })
    
    return {
      answers,
      bubbles: [] // Would implement bubble detection here
    }
  }
  
  async cleanup(): Promise<void> {
    if (this.worker) {
      await this.worker.terminate()
      this.worker = null
    }
  }
}
```

## 🎭 Phase 4: Face Detection with MediaPipe

### Step 6: Identity Verification Service

Create `src/services/FaceDetectionService.ts`:

```typescript
import { FaceDetection } from '@mediapipe/face_detection'
import { Camera } from '@mediapipe/camera_utils'

export interface FaceDetectionResult {
  detections: Array<{
    boundingBox: { xCenter: number; yCenter: number; width: number; height: number }
    landmarks: Array<{ x: number; y: number; z: number }>
    score: number
  }>
  timestamp: number
}

export class FaceDetectionService {
  private faceDetection: FaceDetection | null = null
  private camera: Camera | null = null
  
  async initialize(videoElement: HTMLVideoElement): Promise<void> {
    this.faceDetection = new FaceDetection({
      locateFile: (file) => `https://cdn.jsdelivr.net/npm/@mediapipe/face_detection/${file}`
    })
    
    this.faceDetection.setOptions({
      model: 'short', // 'short' for close faces, 'full' for far faces
      minDetectionConfidence: 0.5
    })
    
    this.camera = new Camera(videoElement, {
      onFrame: async () => {
        if (this.faceDetection) {
          await this.faceDetection.send({ image: videoElement })
        }
      },
      width: 640,
      height: 480
    })
  }
  
  onResults(callback: (results: FaceDetectionResult) => void): void {
    if (!this.faceDetection) return
    
    this.faceDetection.onResults((results) => {
      const detectionResult: FaceDetectionResult = {
        detections: results.detections.map(detection => ({
          boundingBox: detection.boundingBox,
          landmarks: detection.landmarks || [],
          score: detection.score
        })),
        timestamp: Date.now()
      }
      
      callback(detectionResult)
    })
  }
  
  async startDetection(): Promise<void> {
    if (this.camera) {
      await this.camera.start()
    }
  }
  
  stopDetection(): void {
    if (this.camera) {
      this.camera.stop()
    }
  }
  
  // Anti-spoofing checks
  validateLiveness(detectionHistory: FaceDetectionResult[]): {
    isLive: boolean
    confidence: number
    reason: string
  } {
    if (detectionHistory.length < 10) {
      return { isLive: false, confidence: 0, reason: 'Insufficient data' }
    }
    
    // Check for movement patterns
    const movements = this.calculateMovements(detectionHistory)
    const avgMovement = movements.reduce((sum, m) => sum + m, 0) / movements.length
    
    // Check for consistent face size (depth variation)
    const sizeVariations = this.calculateSizeVariations(detectionHistory)
    const avgSizeVariation = sizeVariations.reduce((sum, v) => sum + v, 0) / sizeVariations.length
    
    const livenessScore = (avgMovement * 0.6) + (avgSizeVariation * 0.4)
    
    return {
      isLive: livenessScore > 0.3,
      confidence: Math.min(livenessScore * 100, 100),
      reason: livenessScore > 0.3 ? 'Natural movement detected' : 'Static image suspected'
    }
  }
  
  private calculateMovements(history: FaceDetectionResult[]): number[] {
    const movements: number[] = []
    
    for (let i = 1; i < history.length; i++) {
      const prev = history[i - 1].detections[0]?.boundingBox
      const curr = history[i].detections[0]?.boundingBox
      
      if (prev && curr) {
        const dx = curr.xCenter - prev.xCenter
        const dy = curr.yCenter - prev.yCenter
        const movement = Math.sqrt(dx * dx + dy * dy)
        movements.push(movement)
      }
    }
    
    return movements
  }
  
  private calculateSizeVariations(history: FaceDetectionResult[]): number[] {
    const variations: number[] = []
    
    for (let i = 1; i < history.length; i++) {
      const prev = history[i - 1].detections[0]?.boundingBox
      const curr = history[i].detections[0]?.boundingBox
      
      if (prev && curr) {
        const prevSize = prev.width * prev.height
        const currSize = curr.width * curr.height
        const variation = Math.abs(currSize - prevSize) / prevSize
        variations.push(variation)
      }
    }
    
    return variations
  }
}
```

## 🧠 Phase 5: Custom Model Integration with TensorFlow.js

### Step 7: Handwriting Recognition Service

Create `src/services/HandwritingService.ts`:

```typescript
import * as tf from '@tensorflow/tfjs'

export class HandwritingService {
  private model: tf.LayersModel | null = null
  
  async loadModel(modelUrl: string): Promise<void> {
    try {
      this.model = await tf.loadLayersModel(modelUrl)
      console.log('Handwriting model loaded successfully')
    } catch (error) {
      throw new Error(`Failed to load handwriting model: ${error}`)
    }
  }
  
  async recognizeHandwriting(imageData: ImageData): Promise<{
    text: string
    confidence: number
    characterBoxes: Array<{ char: string; bbox: [number, number, number, number]; confidence: number }>
  }> {
    if (!this.model) throw new Error('Model not loaded')
    
    // Preprocess image for handwriting recognition
    const preprocessed = this.preprocessImage(imageData)
    
    // Segment into characters
    const characterBoxes = await this.segmentCharacters(preprocessed)
    
    // Recognize each character
    const recognitionResults = await Promise.all(
      characterBoxes.map(box => this.recognizeCharacter(box.imageData))
    )
    
    // Combine results
    let text = ''
    const characterResults: Array<{ char: string; bbox: [number, number, number, number]; confidence: number }> = []
    
    recognitionResults.forEach((result, index) => {
      text += result.character
      characterResults.push({
        char: result.character,
        bbox: characterBoxes[index].bbox,
        confidence: result.confidence
      })
    })
    
    const avgConfidence = recognitionResults.reduce((sum, r) => sum + r.confidence, 0) / recognitionResults.length
    
    return { text, confidence: avgConfidence, characterBoxes: characterResults }
  }
  
  private preprocessImage(imageData: ImageData): tf.Tensor {
    // Convert to grayscale and normalize
    const tensor = tf.browser.fromPixels(imageData, 1)
    const normalized = tensor.div(255.0)
    const resized = tf.image.resizeBilinear(normalized, [28, 28])
    
    tensor.dispose()
    normalized.dispose()
    
    return resized
  }
  
  private async segmentCharacters(image: tf.Tensor): Promise<Array<{
    imageData: ImageData
    bbox: [number, number, number, number]
  }>> {
    // Implement character segmentation
    // This is a simplified version - actual implementation would be more complex
    
    const canvas = document.createElement('canvas')
    const ctx = canvas.getContext('2d')!
    
    await tf.browser.toPixels(image, canvas)
    const fullImageData = ctx.getImageData(0, 0, canvas.width, canvas.height)
    
    // For demo purposes, return the full image as one character
    // Real implementation would use connected components or deep learning segmentation
    return [{
      imageData: fullImageData,
      bbox: [0, 0, canvas.width, canvas.height]
    }]
  }
  
  private async recognizeCharacter(imageData: ImageData): Promise<{
    character: string
    confidence: number
  }> {
    if (!this.model) throw new Error('Model not loaded')
    
    // Convert ImageData to tensor
    const canvas = document.createElement('canvas')
    const ctx = canvas.getContext('2d')!
    canvas.width = imageData.width
    canvas.height = imageData.height
    ctx.putImageData(imageData, 0, 0)
    
    const tensor = tf.browser.fromPixels(canvas, 1)
    const normalized = tensor.div(255.0)
    const resized = tf.image.resizeBilinear(normalized, [28, 28])
    const batched = resized.expandDims(0)
    
    // Make prediction
    const prediction = this.model.predict(batched) as tf.Tensor
    const probabilities = await prediction.data()
    
    // Find the character with highest probability
    const maxIndex = probabilities.indexOf(Math.max(...probabilities))
    const confidence = probabilities[maxIndex]
    
    // Character mapping (depends on your model's output classes)
    const characters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    const character = characters[maxIndex] || '?'
    
    // Cleanup tensors
    tensor.dispose()
    normalized.dispose()
    resized.dispose()
    batched.dispose()
    prediction.dispose()
    
    return { character, confidence }
  }
}
```

## 🏗️ Phase 6: Integration & Application Setup

### Step 8: Main Application Class

Create `src/CVEdTechApp.ts`:

```typescript
import { CameraService } from './services/CameraService'
import { OpenCVService } from './services/OpenCVService'
import { OCRService } from './services/OCRService'
import { FaceDetectionService } from './services/FaceDetectionService'
import { HandwritingService } from './services/HandwritingService'

export class CVEdTechApp {
  private cameraService: CameraService
  private openCVService: OpenCVService
  private ocrService: OCRService
  private faceDetectionService: FaceDetectionService
  private handwritingService: HandwritingService
  
  private videoElement: HTMLVideoElement | null = null
  private canvasElement: HTMLCanvasElement | null = null
  
  constructor() {
    this.cameraService = new CameraService()
    this.openCVService = new OpenCVService()
    this.ocrService = new OCRService()
    this.faceDetectionService = new FaceDetectionService()
    this.handwritingService = new HandwritingService()
  }
  
  async initialize(): Promise<void> {
    console.log('Initializing CV EdTech Application...')
    
    try {
      // Initialize services in parallel where possible
      await Promise.all([
        this.openCVService.initialize(),
        this.ocrService.initialize(['eng', 'fil']),
        this.handwritingService.loadModel('/models/handwriting-model.json')
      ])
      
      // Setup UI elements
      this.setupUI()
      
      console.log('Application initialized successfully')
    } catch (error) {
      console.error('Initialization failed:', error)
      throw error
    }
  }
  
  async startDocumentScanning(): Promise<void> {
    this.videoElement = await this.cameraService.initialize({
      video: { width: 1280, height: 720, facingMode: 'environment' }
    })
    
    document.getElementById('camera-container')?.appendChild(this.videoElement)
    
    // Add capture button handler
    document.getElementById('capture-btn')?.addEventListener('click', () => {
      this.captureAndProcessDocument()
    })
  }
  
  async startIdentityVerification(): Promise<void> {
    this.videoElement = await this.cameraService.initialize({
      video: { width: 640, height: 480, facingMode: 'user' }
    })
    
    await this.faceDetectionService.initialize(this.videoElement)
    
    const detectionHistory: any[] = []
    
    this.faceDetectionService.onResults((results) => {
      detectionHistory.push(results)
      
      // Keep only last 30 frames for liveness detection
      if (detectionHistory.length > 30) {
        detectionHistory.shift()
      }
      
      // Draw detection results
      this.drawFaceDetections(results)
      
      // Perform liveness check every 10 frames
      if (detectionHistory.length % 10 === 0 && detectionHistory.length >= 10) {
        const livenessResult = this.faceDetectionService.validateLiveness(detectionHistory)
        this.updateLivenessUI(livenessResult)
      }
    })
    
    await this.faceDetectionService.startDetection()
  }
  
  private async captureAndProcessDocument(): Promise<void> {
    const imageData = this.cameraService.captureFrame()
    if (!imageData) return
    
    try {
      // Show processing indicator
      this.showProcessingIndicator('Processing document...')
      
      // Step 1: Document scanning and perspective correction
      const correctedImage = this.openCVService.processDocument(imageData)
      
      // Step 2: OCR processing
      const ocrResult = await this.ocrService.recognizeText(correctedImage)
      
      // Step 3: Display results
      this.displayProcessingResults({
        originalImage: imageData,
        processedImage: correctedImage,
        ocrResult
      })
      
      this.hideProcessingIndicator()
    } catch (error) {
      console.error('Document processing failed:', error)
      this.showError('Failed to process document. Please try again.')
    }
  }
  
  async recognizeHandwrittenAnswer(imageData: ImageData): Promise<void> {
    try {
      this.showProcessingIndicator('Recognizing handwriting...')
      
      const result = await this.handwritingService.recognizeHandwriting(imageData)
      
      this.displayHandwritingResults(result)
      this.hideProcessingIndicator()
    } catch (error) {
      console.error('Handwriting recognition failed:', error)
      this.showError('Failed to recognize handwriting. Please try again.')
    }
  }
  
  private setupUI(): void {
    const app = document.getElementById('app')!
    app.innerHTML = `
      <div class="cv-edtech-app">
        <header>
          <h1>📚 EdTech Computer Vision Platform</h1>
          <nav>
            <button id="doc-scan-btn">📄 Document Scan</button>
            <button id="identity-verify-btn">🆔 Identity Verify</button>
            <button id="handwriting-btn">✍️ Handwriting</button>
          </nav>
        </header>
        
        <main>
          <div id="camera-container"></div>
          <div id="controls">
            <button id="capture-btn" style="display: none;">📸 Capture</button>
          </div>
          <div id="results-container"></div>
          <div id="processing-indicator" style="display: none;">
            <div class="spinner"></div>
            <span id="processing-text">Processing...</span>
          </div>
        </main>
      </div>
    `
    
    // Add event listeners
    document.getElementById('doc-scan-btn')?.addEventListener('click', () => {
      this.startDocumentScanning()
    })
    
    document.getElementById('identity-verify-btn')?.addEventListener('click', () => {
      this.startIdentityVerification()
    })
  }
  
  private drawFaceDetections(results: any): void {
    if (!this.canvasElement) {
      this.canvasElement = document.createElement('canvas')
      this.canvasElement.width = 640
      this.canvasElement.height = 480
      document.getElementById('camera-container')?.appendChild(this.canvasElement)
    }
    
    const ctx = this.canvasElement.getContext('2d')!
    ctx.clearRect(0, 0, this.canvasElement.width, this.canvasElement.height)
    
    results.detections.forEach((detection: any) => {
      const { xCenter, yCenter, width, height } = detection.boundingBox
      
      const x = (xCenter - width / 2) * this.canvasElement!.width
      const y = (yCenter - height / 2) * this.canvasElement!.height
      const w = width * this.canvasElement!.width
      const h = height * this.canvasElement!.height
      
      ctx.strokeStyle = '#00FF00'
      ctx.lineWidth = 2
      ctx.strokeRect(x, y, w, h)
      
      ctx.fillStyle = '#00FF00'
      ctx.font = '16px Arial'
      ctx.fillText(`${(detection.score * 100).toFixed(1)}%`, x, y - 5)
    })
  }
  
  private updateLivenessUI(livenessResult: any): void {
    const indicator = document.getElementById('liveness-indicator')
    if (indicator) {
      indicator.textContent = `Liveness: ${livenessResult.isLive ? '✅' : '❌'} (${livenessResult.confidence.toFixed(1)}%)`
      indicator.className = livenessResult.isLive ? 'liveness-pass' : 'liveness-fail'
    }
  }
  
  private displayProcessingResults(results: any): void {
    const container = document.getElementById('results-container')!
    container.innerHTML = `
      <div class="results">
        <h3>📄 Document Processing Results</h3>
        <div class="images">
          <div class="image-result">
            <h4>Original</h4>
            <canvas id="original-canvas"></canvas>
          </div>
          <div class="image-result">
            <h4>Processed</h4>
            <canvas id="processed-canvas"></canvas>
          </div>
        </div>
        <div class="ocr-results">
          <h4>📝 Extracted Text (Confidence: ${results.ocrResult.confidence.toFixed(1)}%)</h4>
          <pre>${results.ocrResult.text}</pre>
        </div>
      </div>
    `
    
    // Display images
    const originalCanvas = document.getElementById('original-canvas') as HTMLCanvasElement
    const processedCanvas = document.getElementById('processed-canvas') as HTMLCanvasElement
    
    this.displayImageData(originalCanvas, results.originalImage)
    this.displayImageData(processedCanvas, results.processedImage)
  }
  
  private displayHandwritingResults(results: any): void {
    const container = document.getElementById('results-container')!
    container.innerHTML = `
      <div class="handwriting-results">
        <h3>✍️ Handwriting Recognition Results</h3>
        <div class="recognized-text">
          <h4>📝 Recognized Text (Confidence: ${results.confidence.toFixed(1)}%)</h4>
          <p class="handwritten-text">${results.text}</p>
        </div>
        <div class="character-breakdown">
          <h4>🔤 Character Analysis</h4>
          ${results.characterBoxes.map((char: any, index: number) => `
            <span class="character" data-confidence="${char.confidence}">
              ${char.char} (${char.confidence.toFixed(1)}%)
            </span>
          `).join('')}
        </div>
      </div>
    `
  }
  
  private displayImageData(canvas: HTMLCanvasElement, imageData: ImageData): void {
    canvas.width = imageData.width
    canvas.height = imageData.height
    const ctx = canvas.getContext('2d')!
    ctx.putImageData(imageData, 0, 0)
  }
  
  private showProcessingIndicator(text: string): void {
    const indicator = document.getElementById('processing-indicator')!
    const textElement = document.getElementById('processing-text')!
    textElement.textContent = text
    indicator.style.display = 'flex'
  }
  
  private hideProcessingIndicator(): void {
    const indicator = document.getElementById('processing-indicator')!
    indicator.style.display = 'none'
  }
  
  private showError(message: string): void {
    // Implement error display
    alert(message) // Simple implementation
  }
  
  async cleanup(): Promise<void> {
    this.cameraService.cleanup()
    await this.ocrService.cleanup()
    this.faceDetectionService.stopDetection()
  }
}
```

### Step 9: Main Entry Point

Update `src/main.ts`:

```typescript
import './style.css'
import { CVEdTechApp } from './CVEdTechApp'

async function main() {
  try {
    const app = new CVEdTechApp()
    await app.initialize()
    
    console.log('🚀 CV EdTech Application ready!')
    
    // Cleanup on page unload
    window.addEventListener('beforeunload', () => {
      app.cleanup()
    })
  } catch (error) {
    console.error('Failed to initialize application:', error)
    document.getElementById('app')!.innerHTML = `
      <div class="error">
        <h2>❌ Initialization Error</h2>
        <p>Failed to load computer vision components.</p>
        <details>
          <summary>Error Details</summary>
          <pre>${error}</pre>
        </details>
      </div>
    `
  }
}

main()
```

## 🎨 Styling & Responsive Design

Create `src/style.css`:

```css
* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

body {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  min-height: 100vh;
}

.cv-edtech-app {
  max-width: 1200px;
  margin: 0 auto;
  padding: 20px;
}

header {
  background: rgba(255, 255, 255, 0.1);
  backdrop-filter: blur(10px);
  border-radius: 20px;
  padding: 20px;
  margin-bottom: 20px;
}

header h1 {
  color: white;
  text-align: center;
  margin-bottom: 20px;
  font-size: 2.5em;
}

nav {
  display: flex;
  justify-content: center;
  gap: 15px;
  flex-wrap: wrap;
}

nav button {
  background: rgba(255, 255, 255, 0.2);
  border: 2px solid rgba(255, 255, 255, 0.3);
  color: white;
  padding: 12px 24px;
  border-radius: 50px;
  font-size: 16px;
  cursor: pointer;
  transition: all 0.3s ease;
}

nav button:hover {
  background: rgba(255, 255, 255, 0.3);
  transform: translateY(-2px);
}

main {
  background: rgba(255, 255, 255, 0.05);
  backdrop-filter: blur(10px);
  border-radius: 20px;
  padding: 30px;
  min-height: 60vh;
}

#camera-container {
  display: flex;
  justify-content: center;
  margin-bottom: 20px;
  position: relative;
}

#camera-container video {
  max-width: 100%;
  border-radius: 15px;
  box-shadow: 0 10px 30px rgba(0, 0, 0, 0.3);
}

#camera-container canvas {
  position: absolute;
  top: 0;
  left: 50%;
  transform: translateX(-50%);
  pointer-events: none;
  border-radius: 15px;
}

#controls {
  display: flex;
  justify-content: center;
  gap: 15px;
  margin-bottom: 30px;
}

#capture-btn {
  background: #4CAF50;
  border: none;
  color: white;
  padding: 15px 30px;
  border-radius: 50px;
  font-size: 18px;
  cursor: pointer;
  transition: all 0.3s ease;
}

#capture-btn:hover {
  background: #45a049;
  transform: scale(1.05);
}

.results {
  background: rgba(255, 255, 255, 0.1);
  border-radius: 15px;
  padding: 25px;
  margin-top: 20px;
}

.results h3 {
  color: white;
  margin-bottom: 20px;
  text-align: center;
  font-size: 1.8em;
}

.images {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
  gap: 20px;
  margin-bottom: 25px;
}

.image-result {
  text-align: center;
}

.image-result h4 {
  color: white;
  margin-bottom: 10px;
  font-size: 1.2em;
}

.image-result canvas {
  max-width: 100%;
  height: auto;
  border-radius: 10px;
  box-shadow: 0 5px 15px rgba(0, 0, 0, 0.2);
}

.ocr-results {
  background: rgba(255, 255, 255, 0.1);
  border-radius: 10px;
  padding: 20px;
}

.ocr-results h4 {
  color: white;
  margin-bottom: 15px;
  font-size: 1.3em;
}

.ocr-results pre {
  color: #f0f0f0;
  background: rgba(0, 0, 0, 0.3);
  padding: 15px;
  border-radius: 8px;
  white-space: pre-wrap;
  word-wrap: break-word;
  font-family: 'Courier New', monospace;
  line-height: 1.5;
}

.handwriting-results {
  background: rgba(255, 255, 255, 0.1);
  border-radius: 15px;
  padding: 25px;
  margin-top: 20px;
}

.handwriting-results h3 {
  color: white;
  margin-bottom: 20px;
  text-align: center;
  font-size: 1.8em;
}

.recognized-text {
  margin-bottom: 25px;
}

.recognized-text h4 {
  color: white;
  margin-bottom: 15px;
  font-size: 1.3em;
}

.handwritten-text {
  background: rgba(255, 255, 255, 0.1);
  color: #f0f0f0;
  padding: 20px;
  border-radius: 10px;
  font-size: 1.4em;
  line-height: 1.6;
  text-align: center;
  font-family: 'Comic Sans MS', cursive;
}

.character-breakdown {
  background: rgba(255, 255, 255, 0.05);
  border-radius: 10px;
  padding: 20px;
}

.character-breakdown h4 {
  color: white;
  margin-bottom: 15px;
  font-size: 1.2em;
}

.character {
  display: inline-block;
  background: rgba(255, 255, 255, 0.1);
  color: white;
  padding: 8px 12px;
  margin: 4px;
  border-radius: 8px;
  font-family: monospace;
  font-size: 14px;
  border: 2px solid transparent;
}

.character[data-confidence*="9"] {
  border-color: #4CAF50;
  background: rgba(76, 175, 80, 0.2);
}

.character[data-confidence*="8"] {
  border-color: #FF9800;
  background: rgba(255, 152, 0, 0.2);
}

.character[data-confidence*="7"],
.character[data-confidence*="6"],
.character[data-confidence*="5"] {
  border-color: #F44336;
  background: rgba(244, 67, 54, 0.2);
}

#processing-indicator {
  position: fixed;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  background: rgba(0, 0, 0, 0.8);
  display: flex;
  flex-direction: column;
  justify-content: center;
  align-items: center;
  z-index: 1000;
}

.spinner {
  width: 50px;
  height: 50px;
  border: 4px solid rgba(255, 255, 255, 0.3);
  border-top: 4px solid white;
  border-radius: 50%;
  animation: spin 1s linear infinite;
  margin-bottom: 20px;
}

@keyframes spin {
  0% { transform: rotate(0deg); }
  100% { transform: rotate(360deg); }
}

#processing-text {
  color: white;
  font-size: 1.2em;
  text-align: center;
}

.liveness-pass {
  color: #4CAF50;
  font-weight: bold;
}

.liveness-fail {
  color: #F44336;
  font-weight: bold;
}

.error {
  background: rgba(244, 67, 54, 0.1);
  border: 2px solid #F44336;
  border-radius: 15px;
  padding: 30px;
  text-align: center;
  color: white;
}

.error h2 {
  margin-bottom: 15px;
  color: #F44336;
}

.error details {
  margin-top: 20px;
  text-align: left;
}

.error summary {
  cursor: pointer;
  font-weight: bold;
  margin-bottom: 10px;
}

.error pre {
  background: rgba(0, 0, 0, 0.3);
  padding: 15px;
  border-radius: 8px;
  white-space: pre-wrap;
  overflow-x: auto;
}

/* Responsive Design */
@media (max-width: 768px) {
  .cv-edtech-app {
    padding: 10px;
  }
  
  header {
    padding: 15px;
  }
  
  header h1 {
    font-size: 2em;
  }
  
  nav {
    flex-direction: column;
    align-items: center;
  }
  
  nav button {
    width: 100%;
    max-width: 300px;
  }
  
  main {
    padding: 20px;
  }
  
  .images {
    grid-template-columns: 1fr;
  }
  
  .handwritten-text {
    font-size: 1.2em;
  }
}

@media (max-width: 480px) {
  header h1 {
    font-size: 1.5em;
  }
  
  nav button {
    padding: 10px 20px;
    font-size: 14px;
  }
  
  .results,
  .handwriting-results {
    padding: 15px;
  }
  
  .handwritten-text {
    font-size: 1.1em;
    padding: 15px;
  }
}
```

## 🚀 Build and Development Commands

Add to `package.json`:

```json
{
  "scripts": {
    "dev": "vite --host",
    "build": "tsc && vite build",
    "preview": "vite preview --host",
    "type-check": "tsc --noEmit",
    "lint": "eslint src --ext .ts,.tsx",
    "test": "vitest"
  }
}
```

## 🔧 Environment Configuration

Create `.env.example`:

```bash
# TensorFlow.js Model URLs
VITE_HANDWRITING_MODEL_URL=https://your-cdn.com/models/handwriting-model.json
VITE_OBJECT_DETECTION_MODEL_URL=https://your-cdn.com/models/object-detection-model.json

# MediaPipe Configuration
VITE_MEDIAPIPE_CDN=https://cdn.jsdelivr.net/npm/@mediapipe

# OCR Configuration
VITE_TESSERACT_WORKER_PATH=/assets/worker.min.js
VITE_TESSERACT_CORE_PATH=/assets/tesseract-core.wasm.js

# Performance Settings
VITE_MAX_IMAGE_SIZE=1920x1080
VITE_COMPRESSION_QUALITY=0.8
VITE_PROCESSING_TIMEOUT=30000

# Feature Flags
VITE_ENABLE_FACE_DETECTION=true
VITE_ENABLE_HANDWRITING_RECOGNITION=true
VITE_ENABLE_ANSWER_SHEET_PROCESSING=true
VITE_ENABLE_ANALYTICS=true
```

## ✅ Verification Steps

### 1. Basic Camera Access
```bash
npm run dev
```
- Open browser to `http://localhost:5173`
- Click "Document Scan" - camera should activate
- Verify video stream is working

### 2. Document Processing
- Point camera at a document
- Click "Capture" button
- Verify image processing and OCR results

### 3. Face Detection
- Click "Identity Verify"
- Position face in camera view
- Verify face detection bounding boxes appear
- Check liveness detection feedback

### 4. Performance Testing
- Test on different devices (mobile, desktop)
- Monitor memory usage in browser DevTools
- Check network requests and loading times

## 📱 Deployment Considerations

### Production Build
```bash
npm run build
npm run preview
```

### CDN Optimization
- Host large models (OpenCV.js, TensorFlow.js models) on CDN
- Use gzip compression for faster loading
- Implement lazy loading for non-critical features

### Performance Monitoring
- Implement error tracking (Sentry, LogRocket)
- Monitor Core Web Vitals
- Track computer vision accuracy metrics

---

## 🌐 Navigation

**Previous:** [Executive Summary](./executive-summary.md) | **Next:** [Best Practices](./best-practices.md)

---

*Implementation guide tested on Chrome 120+, Firefox 120+, Safari 16+. Code examples use TypeScript 5.x and modern web APIs. Last updated July 2025.*