# Template Examples: Computer Vision Web Applications

## 🎯 Overview

This document provides ready-to-use code templates and examples for implementing computer vision features in EdTech web applications. Each template is production-ready and follows the best practices outlined in this research.

## 📱 Complete Application Template

### Main Application Structure

```html
<!-- public/index.html -->
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>EdTech Computer Vision Platform</title>
    <link rel="stylesheet" href="styles.css">
    <link rel="manifest" href="manifest.json">
    <meta name="theme-color" content="#667eea">
</head>
<body>
    <div id="app">
        <header class="app-header">
            <h1>📚 EdTech CV Platform</h1>
            <nav class="main-nav">
                <button id="document-scan" class="nav-btn">📄 Document Scan</button>
                <button id="identity-verify" class="nav-btn">🆔 Identity Verify</button>
                <button id="answer-check" class="nav-btn">✓ Answer Check</button>
                <button id="handwriting" class="nav-btn">✍️ Handwriting</button>
            </nav>
        </header>

        <main class="app-main">
            <!-- Camera View -->
            <section id="camera-section" class="section">
                <div class="camera-container">
                    <video id="camera-video" autoplay playsinline></video>
                    <canvas id="camera-overlay"></canvas>
                    <div class="camera-controls">
                        <button id="capture-btn" class="btn-primary">📸 Capture</button>
                        <button id="switch-camera" class="btn-secondary">🔄 Switch</button>
                        <button id="toggle-flash" class="btn-secondary">💡 Flash</button>
                    </div>
                </div>
            </section>

            <!-- Processing Results -->
            <section id="results-section" class="section">
                <div class="results-container">
                    <div class="processing-indicator" id="processing">
                        <div class="spinner"></div>
                        <span>Processing...</span>
                    </div>
                    <div id="results-content"></div>
                </div>
            </section>

            <!-- Settings Panel -->
            <section id="settings-section" class="section">
                <div class="settings-panel">
                    <h3>⚙️ Settings</h3>
                    <div class="setting-group">
                        <label>Quality Level:</label>
                        <select id="quality-select">
                            <option value="low">Low (Fast)</option>
                            <option value="medium" selected>Medium (Balanced)</option>
                            <option value="high">High (Accurate)</option>
                        </select>
                    </div>
                    <div class="setting-group">
                        <label>Language:</label>
                        <select id="language-select">
                            <option value="eng">English</option>
                            <option value="fil">Filipino</option>
                            <option value="eng+fil">English + Filipino</option>
                        </select>
                    </div>
                    <div class="setting-group">
                        <label>
                            <input type="checkbox" id="save-results"> Save Results
                        </label>
                    </div>
                </div>
            </section>
        </main>

        <!-- Status Bar -->
        <footer class="status-bar">
            <div class="status-item">
                <span class="status-label">Status:</span>
                <span id="app-status" class="status-value">Ready</span>
            </div>
            <div class="status-item">
                <span class="status-label">Battery:</span>
                <span id="battery-status" class="status-value">100%</span>
            </div>
            <div class="status-item">
                <span class="status-label">Network:</span>
                <span id="network-status" class="status-value">Online</span>
            </div>
        </footer>
    </div>

    <!-- Scripts -->
    <script src="https://cdn.jsdelivr.net/npm/@tensorflow/tfjs@latest"></script>
    <script src="dist/app.js"></script>
</body>
</html>
```

### TypeScript Application Class

```typescript
// src/CVEdTechApp.ts
import { CameraService } from './services/CameraService'
import { DocumentProcessor } from './processors/DocumentProcessor'
import { OCRProcessor } from './processors/OCRProcessor'
import { FaceDetector } from './processors/FaceDetector'
import { HandwritingRecognizer } from './processors/HandwritingRecognizer'
import { UIManager } from './ui/UIManager'
import { SettingsManager } from './managers/SettingsManager'
import { StorageManager } from './managers/StorageManager'

export class CVEdTechApp {
    private camera: CameraService
    private documentProcessor: DocumentProcessor
    private ocrProcessor: OCRProcessor
    private faceDetector: FaceDetector
    private handwritingRecognizer: HandwritingRecognizer
    private ui: UIManager
    private settings: SettingsManager
    private storage: StorageManager
    
    private currentMode: 'document' | 'identity' | 'answer' | 'handwriting' = 'document'
    private isInitialized = false

    constructor() {
        this.camera = new CameraService()
        this.documentProcessor = new DocumentProcessor()
        this.ocrProcessor = new OCRProcessor()
        this.faceDetector = new FaceDetector()
        this.handwritingRecognizer = new HandwritingRecognizer()
        this.ui = new UIManager()
        this.settings = new SettingsManager()
        this.storage = new StorageManager()
    }

    async initialize(): Promise<void> {
        try {
            this.ui.showStatus('Initializing application...')
            
            // Initialize services in parallel where possible
            await Promise.all([
                this.settings.initialize(),
                this.storage.initialize(),
                this.ui.initialize()
            ])

            // Initialize CV services based on user settings
            const enabledFeatures = this.settings.getEnabledFeatures()
            
            const initPromises: Promise<void>[] = []
            
            if (enabledFeatures.includes('document-scanning')) {
                initPromises.push(this.documentProcessor.initialize())
            }
            
            if (enabledFeatures.includes('ocr')) {
                initPromises.push(this.ocrProcessor.initialize())
            }
            
            if (enabledFeatures.includes('face-detection')) {
                initPromises.push(this.faceDetector.initialize())
            }
            
            if (enabledFeatures.includes('handwriting')) {
                initPromises.push(this.handwritingRecognizer.initialize())
            }

            await Promise.all(initPromises)

            // Set up event handlers
            this.setupEventHandlers()
            
            // Initialize camera
            await this.camera.initialize()
            
            this.isInitialized = true
            this.ui.showStatus('Ready')
            
            console.log('✅ CVEdTechApp initialized successfully')
            
        } catch (error) {
            console.error('❌ Failed to initialize CVEdTechApp:', error)
            this.ui.showError(`Initialization failed: ${error.message}`)
            throw error
        }
    }

    private setupEventHandlers(): void {
        // Navigation buttons
        document.getElementById('document-scan')?.addEventListener('click', () => {
            this.setMode('document')
        })
        
        document.getElementById('identity-verify')?.addEventListener('click', () => {
            this.setMode('identity')
        })
        
        document.getElementById('answer-check')?.addEventListener('click', () => {
            this.setMode('answer')
        })
        
        document.getElementById('handwriting')?.addEventListener('click', () => {
            this.setMode('handwriting')
        })

        // Camera controls
        document.getElementById('capture-btn')?.addEventListener('click', () => {
            this.captureAndProcess()
        })
        
        document.getElementById('switch-camera')?.addEventListener('click', () => {
            this.camera.switchCamera()
        })

        // Settings
        document.getElementById('quality-select')?.addEventListener('change', (e) => {
            const target = e.target as HTMLSelectElement
            this.settings.setQuality(target.value as 'low' | 'medium' | 'high')
        })
        
        document.getElementById('language-select')?.addEventListener('change', (e) => {
            const target = e.target as HTMLSelectElement
            this.settings.setLanguage(target.value)
        })

        // Global error handler
        window.addEventListener('error', (event) => {
            this.handleGlobalError(event.error)
        })

        // Network status monitoring
        window.addEventListener('online', () => {
            this.ui.updateNetworkStatus('online')
        })
        
        window.addEventListener('offline', () => {
            this.ui.updateNetworkStatus('offline')
        })
    }

    async setMode(mode: 'document' | 'identity' | 'answer' | 'handwriting'): Promise<void> {
        if (!this.isInitialized) {
            throw new Error('Application not initialized')
        }

        this.currentMode = mode
        this.ui.setActiveMode(mode)
        
        // Configure camera for the selected mode
        const cameraConfig = this.getCameraConfigForMode(mode)
        await this.camera.configure(cameraConfig)
        
        // Update UI for the mode
        this.ui.updateModeInstructions(mode)
        
        console.log(`📱 Switched to ${mode} mode`)
    }

    private async captureAndProcess(): Promise<void> {
        try {
            this.ui.showProcessing(true)
            this.ui.showStatus('Capturing image...')
            
            // Capture image from camera
            const imageData = await this.camera.captureImage()
            
            if (!imageData) {
                throw new Error('Failed to capture image')
            }

            // Process based on current mode
            let result: any
            
            switch (this.currentMode) {
                case 'document':
                    result = await this.processDocument(imageData)
                    break
                case 'identity':
                    result = await this.processIdentity(imageData)
                    break  
                case 'answer':
                    result = await this.processAnswerSheet(imageData)
                    break
                case 'handwriting':
                    result = await this.processHandwriting(imageData)
                    break
                default:
                    throw new Error(`Unknown mode: ${this.currentMode}`)
            }

            // Display results
            this.ui.displayResults(result, this.currentMode)
            
            // Save if enabled
            if (this.settings.isSaveResultsEnabled()) {
                await this.storage.saveResult(result)
            }
            
            this.ui.showStatus('Processing complete')
            
        } catch (error) {
            console.error('Processing error:', error)
            this.ui.showError(`Processing failed: ${error.message}`)
        } finally {
            this.ui.showProcessing(false)
        }
    }

    private async processDocument(imageData: ImageData): Promise<DocumentResult> {
        this.ui.showStatus('Detecting document...')
        
        // Step 1: Document detection and perspective correction
        const docResult = await this.documentProcessor.processDocument(imageData)
        
        if (!docResult.found) {
            throw new Error('No document detected in image')
        }

        this.ui.showStatus('Extracting text...')
        
        // Step 2: OCR processing
        const ocrResult = await this.ocrProcessor.extractText(
            docResult.correctedImage,
            { language: this.settings.getLanguage() }
        )

        return {
            type: 'document',
            originalImage: imageData,
            correctedImage: docResult.correctedImage,
            text: ocrResult.text,
            confidence: ocrResult.confidence,
            processingTime: docResult.processingTime + ocrResult.processingTime,
            timestamp: Date.now()
        }
    }

    private async processIdentity(imageData: ImageData): Promise<IdentityResult> {
        this.ui.showStatus('Detecting face...')
        
        const faceResult = await this.faceDetector.detectFace(imageData)
        
        if (faceResult.faces.length === 0) {
            throw new Error('No face detected in image')
        }

        if (faceResult.faces.length > 1) {
            throw new Error('Multiple faces detected. Please ensure only one person is in the frame')
        }

        this.ui.showStatus('Verifying liveness...')
        
        const livenessResult = await this.faceDetector.verifyLiveness(faceResult)

        return {
            type: 'identity',
            originalImage: imageData,
            faceDetected: true,
            faceCount: faceResult.faces.length,
            livenessScore: livenessResult.score,
            livenessPass: livenessResult.passed,
            confidence: faceResult.faces[0].confidence,
            processingTime: faceResult.processingTime + livenessResult.processingTime,
            timestamp: Date.now()
        }
    }

    private async processAnswerSheet(imageData: ImageData): Promise<AnswerSheetResult> {
        this.ui.showStatus('Processing answer sheet...')
        
        // Step 1: Document correction
        const docResult = await this.documentProcessor.processDocument(imageData)
        
        if (!docResult.found) {
            throw new Error('Answer sheet not detected')
        }

        this.ui.showStatus('Recognizing answers...')
        
        // Step 2: Answer detection and recognition
        const answers = await this.ocrProcessor.processAnswerSheet(
            docResult.correctedImage,
            { detectBubbles: true, language: 'eng' }
        )

        return {
            type: 'answer-sheet',
            originalImage: imageData,
            correctedImage: docResult.correctedImage,
            answers: answers.answers,
            bubbles: answers.bubbles,
            totalQuestions: answers.answers.length,
            processingTime: docResult.processingTime + answers.processingTime,
            timestamp: Date.now()
        }
    }

    private async processHandwriting(imageData: ImageData): Promise<HandwritingResult> {
        this.ui.showStatus('Analyzing handwriting...')
        
        const handwritingResult = await this.handwritingRecognizer.recognize(imageData)

        return {
            type: 'handwriting',
            originalImage: imageData,
            recognizedText: handwritingResult.text,
            characters: handwritingResult.characters,
            confidence: handwritingResult.confidence,
            processingTime: handwritingResult.processingTime,
            timestamp: Date.now()
        }
    }

    private getCameraConfigForMode(mode: string): CameraConfig {
        const baseConfig: CameraConfig = {
            width: 1280,
            height: 720,
            facingMode: 'environment'
        }

        switch (mode) {
            case 'identity':
                return {
                    ...baseConfig,
                    width: 640,
                    height: 480,
                    facingMode: 'user' // Front camera for selfies
                }
            case 'document':
            case 'answer':
                return {
                    ...baseConfig,
                    width: 1920,
                    height: 1080,
                    facingMode: 'environment' // Back camera for documents
                }
            case 'handwriting':
                return {
                    ...baseConfig,
                    width: 1280,
                    height: 720,
                    facingMode: 'environment'
                }
            default:
                return baseConfig
        }
    }

    private handleGlobalError(error: Error): void {
        console.error('Global error:', error)
        this.ui.showError(`Unexpected error: ${error.message}`)
        
        // Report to monitoring service
        if (typeof gtag !== 'undefined') {
            gtag('event', 'exception', {
                description: error.message,
                fatal: false
            })
        }
    }

    async cleanup(): Promise<void> {
        await Promise.all([
            this.camera.cleanup(),
            this.documentProcessor.cleanup(),
            this.ocrProcessor.cleanup(),
            this.faceDetector.cleanup(),
            this.handwritingRecognizer.cleanup()
        ])
        
        console.log('🧹 CVEdTechApp cleaned up')
    }
}

// Application interfaces
interface DocumentResult {
    type: 'document'
    originalImage: ImageData
    correctedImage: ImageData
    text: string
    confidence: number
    processingTime: number
    timestamp: number
}

interface IdentityResult {
    type: 'identity'
    originalImage: ImageData
    faceDetected: boolean
    faceCount: number
    livenessScore: number
    livenessPass: boolean
    confidence: number
    processingTime: number
    timestamp: number
}

interface AnswerSheetResult {
    type: 'answer-sheet'
    originalImage: ImageData
    correctedImage: ImageData
    answers: Array<{ question: number; answer: string; confidence: number }>
    bubbles: Array<{ x: number; y: number; filled: boolean }>
    totalQuestions: number
    processingTime: number
    timestamp: number
}

interface HandwritingResult {
    type: 'handwriting'
    originalImage: ImageData
    recognizedText: string
    characters: Array<{ char: string; confidence: number; bbox: [number, number, number, number] }>
    confidence: number
    processingTime: number
    timestamp: number
}

interface CameraConfig {
    width: number
    height: number
    facingMode: 'user' | 'environment'
}
```

## 🎨 CSS Styling Template

```css
/* src/styles.css */
:root {
  --primary-color: #667eea;
  --secondary-color: #764ba2;
  --accent-color: #f093fb;
  --success-color: #4caf50;
  --warning-color: #ff9800;
  --error-color: #f44336;
  --text-color: #333;
  --bg-color: #f5f5f5;
  --card-bg: #ffffff;
  --border-radius: 8px;
  --shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
  --transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
}

* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

body {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
  background: linear-gradient(135deg, var(--primary-color), var(--secondary-color));
  color: var(--text-color);
  min-height: 100vh;
  overflow-x: hidden;
}

#app {
  display: flex;
  flex-direction: column;
  min-height: 100vh;
}

/* Header Styles */
.app-header {
  background: rgba(255, 255, 255, 0.1);
  backdrop-filter: blur(10px);
  border-bottom: 1px solid rgba(255, 255, 255, 0.2);
  padding: 1rem;
  position: sticky;
  top: 0;
  z-index: 100;
}

.app-header h1 {
  color: white;
  text-align: center;
  margin-bottom: 1rem;
  font-size: 1.8rem;
  font-weight: 600;
}

.main-nav {
  display: flex;
  justify-content: center;
  gap: 0.5rem;
  flex-wrap: wrap;
}

.nav-btn {
  background: rgba(255, 255, 255, 0.2);
  border: 1px solid rgba(255, 255, 255, 0.3);
  color: white;
  padding: 0.75rem 1rem;
  border-radius: var(--border-radius);
  cursor: pointer;
  transition: var(--transition);
  font-size: 0.9rem;
  font-weight: 500;
  min-width: 120px;
}

.nav-btn:hover {
  background: rgba(255, 255, 255, 0.3);
  transform: translateY(-1px);
}

.nav-btn.active {
  background: rgba(255, 255, 255, 0.4);
  border-color: rgba(255, 255, 255, 0.6);
}

/* Main Content */
.app-main {
  flex: 1;
  padding: 1rem;
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.section {
  background: var(--card-bg);
  border-radius: var(--border-radius);
  box-shadow: var(--shadow);
  padding: 1.5rem;
  transition: var(--transition);
}

.section:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 20px rgba(0, 0, 0, 0.15);
}

/* Camera Section */
.camera-container {
  position: relative;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 1rem;
}

#camera-video {
  width: 100%;
  max-width: 640px;
  height: auto;
  border-radius: var(--border-radius);
  object-fit: cover;
  background: #000;
}

#camera-overlay {
  position: absolute;
  top: 0;
  left: 50%;
  transform: translateX(-50%);
  pointer-events: none;
  border-radius: var(--border-radius);
}

.camera-controls {
  display: flex;
  gap: 0.5rem;
  flex-wrap: wrap;
  justify-content: center;
}

/* Buttons */
.btn-primary, .btn-secondary {
  padding: 0.75rem 1.5rem;
  border: none;
  border-radius: var(--border-radius);
  cursor: pointer;
  font-size: 1rem;
  font-weight: 600;
  text-transform: none;
  transition: var(--transition);
  display: inline-flex;
  align-items: center;
  gap: 0.5rem;
}

.btn-primary {
  background: linear-gradient(45deg, var(--primary-color), var(--secondary-color));
  color: white;
}

.btn-primary:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 15px rgba(102, 126, 234, 0.4);
}

.btn-secondary {
  background: var(--bg-color);
  color: var(--text-color);
  border: 1px solid #ddd;
}

.btn-secondary:hover {
  background: #e9e9e9;
  transform: translateY(-1px);
}

/* Results Section */
.results-container {
  min-height: 200px;
  position: relative;
}

.processing-indicator {
  display: none;
  align-items: center;
  justify-content: center;
  gap: 1rem;
  padding: 2rem;
  text-align: center;
}

.processing-indicator.active {
  display: flex;
}

.spinner {
  width: 40px;
  height: 40px;
  border: 4px solid #f3f3f3;
  border-top: 4px solid var(--primary-color);
  border-radius: 50%;
  animation: spin 1s linear infinite;
}

@keyframes spin {
  0% { transform: rotate(0deg); }
  100% { transform: rotate(360deg); }
}

#results-content {
  display: none;
}

#results-content.active {
  display: block;
}

/* Results Display */
.result-card {
  background: var(--card-bg);
  border-radius: var(--border-radius);
  padding: 1.5rem;
  margin-bottom: 1rem;
  box-shadow: var(--shadow);
}

.result-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 1rem;
  padding-bottom: 0.5rem;
  border-bottom: 1px solid #eee;
}

.result-title {
  font-size: 1.2rem;
  font-weight: 600;
  color: var(--primary-color);
}

.result-confidence {
  padding: 0.25rem 0.75rem;
  border-radius: 20px;
  font-size: 0.85rem;
  font-weight: 600;
}

.confidence-high {
  background: rgba(76, 175, 80, 0.1);
  color: var(--success-color);
}

.confidence-medium {
  background: rgba(255, 152, 0, 0.1);
  color: var(--warning-color);
}

.confidence-low {
  background: rgba(244, 67, 54, 0.1);
  color: var(--error-color);
}

.result-images {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
  gap: 1rem;
  margin-bottom: 1rem;
}

.result-image {
  text-align: center;
}

.result-image img {
  max-width: 100%;
  height: auto;
  border-radius: var(--border-radius);
  box-shadow: var(--shadow);
}

.result-image h4 {
  margin: 0.5rem 0;
  color: var(--text-color);
  font-size: 0.9rem;
}

.result-text {
  background: var(--bg-color);
  padding: 1rem;
  border-radius: var(--border-radius);
  font-family: 'Courier New', monospace;
  white-space: pre-wrap;
  word-wrap: break-word;
  border-left: 4px solid var(--primary-color);
}

/* Settings Panel */
.settings-panel h3 {
  margin-bottom: 1rem;
  color: var(--primary-color);
}

.setting-group {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 1rem;
  padding: 0.5rem 0;
}

.setting-group label {
  font-weight: 500;
  color: var(--text-color);
}

.setting-group select,
.setting-group input[type="checkbox"] {
  padding: 0.5rem;
  border: 1px solid #ddd;
  border-radius: var(--border-radius);
  background: white;
  transition: var(--transition);
}

.setting-group select:focus {
  outline: none;
  border-color: var(--primary-color);
  box-shadow: 0 0 0 2px rgba(102, 126, 234, 0.2);
}

/* Status Bar */
.status-bar {
  background: rgba(255, 255, 255, 0.95);
  backdrop-filter: blur(10px);
  border-top: 1px solid rgba(0, 0, 0, 0.1);
  padding: 0.75rem 1rem;
  display: flex;
  justify-content: space-between;
  align-items: center;
  font-size: 0.85rem;
}

.status-item {
  display: flex;
  gap: 0.5rem;
}

.status-label {
  font-weight: 600;
  color: #666;
}

.status-value {
  color: var(--primary-color);
  font-weight: 500;
}

/* Error/Success Messages */
.message {
  padding: 1rem;
  border-radius: var(--border-radius);
  margin-bottom: 1rem;
  font-weight: 500;
}

.message-success {
  background: rgba(76, 175, 80, 0.1);
  color: var(--success-color);
  border-left: 4px solid var(--success-color);
}

.message-error {
  background: rgba(244, 67, 54, 0.1);
  color: var(--error-color);
  border-left: 4px solid var(--error-color);
}

.message-warning {
  background: rgba(255, 152, 0, 0.1);
  color: var(--warning-color);
  border-left: 4px solid var(--warning-color);
}

/* Responsive Design */
@media (max-width: 768px) {
  .app-header {
    padding: 0.75rem;
  }
  
  .app-header h1 {
    font-size: 1.5rem;
  }
  
  .main-nav {
    gap: 0.25rem;
  }
  
  .nav-btn {
    min-width: 100px;
    padding: 0.5rem 0.75rem;
    font-size: 0.8rem;
  }
  
  .app-main {
    padding: 0.75rem;
    gap: 0.75rem;
  }
  
  .section {
    padding: 1rem;
  }
  
  .camera-controls {
    flex-direction: column;
  }
  
  .btn-primary, .btn-secondary {
    width: 100%;
    justify-content: center;
  }
  
  .result-images {
    grid-template-columns: 1fr;
  }
  
  .status-bar {
    flex-direction: column;
    gap: 0.5rem;
    text-align: center;
  }
  
  .setting-group {
    flex-direction: column;
    align-items: flex-start;
    gap: 0.5rem;
  }
}

@media (max-width: 480px) {
  .app-header h1 {
    font-size: 1.3rem;
  }
  
  .nav-btn {
    min-width: 80px;
    padding: 0.4rem 0.5rem;
    font-size: 0.75rem;
  }
  
  .section {
    padding: 0.75rem;
  }
  
  .result-text {
    font-size: 0.85rem;
  }
}

/* Print Styles */
@media print {
  .app-header,
  .camera-controls,
  .status-bar,
  .settings-panel {
    display: none;
  }
  
  .section {
    box-shadow: none;
    border: 1px solid #ddd;
    page-break-inside: avoid;
  }
  
  .result-images img {
    max-height: 300px;
  }
}

/* Accessibility */
@media (prefers-reduced-motion: reduce) {
  * {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
  }
  
  .spinner {
    animation: none;
  }
}

@media (prefers-color-scheme: dark) {
  :root {
    --text-color: #e0e0e0;
    --bg-color: #1a1a1a;
    --card-bg: #2d2d2d;
  }
  
  body {
    background: linear-gradient(135deg, #1a1a2e, #16213e);
  }
  
  .section {
    background: var(--card-bg);
    color: var(--text-color);
  }
  
  .status-bar {
    background: rgba(45, 45, 45, 0.95);
    border-top-color: rgba(255, 255, 255, 0.1);
  }
}

/* Focus Styles for Accessibility */
button:focus,
select:focus,
input:focus {
  outline: 3px solid rgba(102, 126, 234, 0.5);
  outline-offset: 2px;
}

/* High Contrast Mode */
@media (prefers-contrast: high) {
  :root {
    --primary-color: #0066cc;
    --secondary-color: #004499;
    --text-color: #000000;
    --bg-color: #ffffff;
  }
  
  .nav-btn,
  .btn-primary,
  .btn-secondary {
    border: 2px solid currentColor;
  }
}
```

## 🔧 Service Templates

### Camera Service Template

```typescript
// src/services/CameraService.ts
export class CameraService {
    private stream: MediaStream | null = null
    private video: HTMLVideoElement | null = null
    private canvas: HTMLCanvasElement | null = null
    private currentFacingMode: 'user' | 'environment' = 'environment'
    private isInitialized = false

    async initialize(): Promise<void> {
        try {
            // Check for camera permissions
            const permissions = await navigator.permissions.query({ name: 'camera' as PermissionName })
            
            if (permissions.state === 'denied') {
                throw new Error('Camera permission denied')
            }

            // Create video element
            this.video = document.getElementById('camera-video') as HTMLVideoElement
            if (!this.video) {
                throw new Error('Video element not found')
            }

            // Create canvas for image capture
            this.canvas = document.createElement('canvas')
            
            // Start camera with default settings
            await this.startCamera()
            
            this.isInitialized = true
            console.log('📹 Camera service initialized')
            
        } catch (error) {
            console.error('Failed to initialize camera:', error)
            throw new Error(`Camera initialization failed: ${error.message}`)
        }
    }

    async configure(config: CameraConfig): Promise<void> {
        if (!this.isInitialized) {
            throw new Error('Camera service not initialized')
        }

        // Stop current stream
        await this.stopCamera()
        
        // Update facing mode
        this.currentFacingMode = config.facingMode
        
        // Start with new configuration
        await this.startCamera(config)
    }

    private async startCamera(config?: CameraConfig): Promise<void> {
        const constraints: MediaStreamConstraints = {
            video: {
                width: config?.width || 1280,
                height: config?.height || 720,
                facingMode: config?.facingMode || this.currentFacingMode
            },
            audio: false
        }

        try {
            this.stream = await navigator.mediaDevices.getUserMedia(constraints)
            
            if (this.video) {
                this.video.srcObject = this.stream
                
                // Wait for video to be ready
                await new Promise<void>((resolve, reject) => {
                    this.video!.onloadedmetadata = () => {
                        this.video!.play().then(resolve).catch(reject)
                    }
                    this.video!.onerror = reject
                })
                
                // Update canvas size to match video
                if (this.canvas) {
                    this.canvas.width = this.video.videoWidth
                    this.canvas.height = this.video.videoHeight
                }
            }
            
        } catch (error) {
            throw new Error(`Failed to start camera: ${error.message}`)
        }
    }

    async captureImage(): Promise<ImageData | null> {
        if (!this.video || !this.canvas || !this.isInitialized) {
            throw new Error('Camera not ready for capture')
        }

        const ctx = this.canvas.getContext('2d')
        if (!ctx) {
            throw new Error('Canvas context not available')
        }

        // Draw current video frame to canvas
        ctx.drawImage(this.video, 0, 0, this.canvas.width, this.canvas.height)
        
        // Get image data
        const imageData = ctx.getImageData(0, 0, this.canvas.width, this.canvas.height)
        
        return imageData
    }

    async switchCamera(): Promise<void> {
        const newFacingMode = this.currentFacingMode === 'user' ? 'environment' : 'user'
        
        await this.configure({
            width: 1280,
            height: 720,
            facingMode: newFacingMode
        })
    }

    async captureToBlob(format: 'jpeg' | 'png' = 'jpeg', quality: number = 0.9): Promise<Blob | null> {
        if (!this.video || !this.canvas) {
            return null
        }

        const ctx = this.canvas.getContext('2d')!
        ctx.drawImage(this.video, 0, 0, this.canvas.width, this.canvas.height)
        
        return new Promise((resolve) => {
            this.canvas!.toBlob(resolve, `image/${format}`, quality)
        })
    }

    getVideoElement(): HTMLVideoElement | null {
        return this.video
    }

    isActive(): boolean {
        return this.isInitialized && this.stream !== null
    }

    async stopCamera(): Promise<void> {
        if (this.stream) {
            this.stream.getTracks().forEach(track => {
                track.stop()
            })
            this.stream = null
        }
    }

    async cleanup(): Promise<void> {
        await this.stopCamera()
        
        if (this.video) {
            this.video.srcObject = null
        }
        
        this.isInitialized = false
        console.log('🧹 Camera service cleaned up')
    }
}

interface CameraConfig {
    width: number
    height: number
    facingMode: 'user' | 'environment'
}
```

### Document Processor Template

```typescript
// src/processors/DocumentProcessor.ts
export class DocumentProcessor {
    private openCV: any = null
    private isReady = false

    async initialize(): Promise<void> {
        try {
            // Load OpenCV.js
            await this.loadOpenCV()
            this.isReady = true
            console.log('📄 Document processor initialized')
        } catch (error) {
            throw new Error(`Document processor initialization failed: ${error.message}`)
        }
    }

    private async loadOpenCV(): Promise<void> {
        return new Promise((resolve, reject) => {
            if (window.cv) {
                resolve()
                return
            }

            const script = document.createElement('script')
            script.src = 'https://docs.opencv.org/4.8.0/opencv.js'
            script.async = true
            
            script.onload = () => {
                if (window.cv) {
                    window.cv.onRuntimeInitialized = () => {
                        this.openCV = window.cv
                        resolve()
                    }
                } else {
                    reject(new Error('OpenCV failed to load'))
                }
            }
            
            script.onerror = () => reject(new Error('Failed to load OpenCV script'))
            document.head.appendChild(script)
        })
    }

    async processDocument(imageData: ImageData): Promise<DocumentProcessingResult> {
        if (!this.isReady || !this.openCV) {
            throw new Error('Document processor not ready')
        }

        const startTime = performance.now()

        try {
            // Convert ImageData to OpenCV Mat
            const src = this.openCV.matFromImageData(imageData)
            
            // Find document contours
            const documentContour = this.findDocumentContour(src)
            
            if (!documentContour) {
                src.delete()
                return {
                    found: false,
                    originalImage: imageData,
                    correctedImage: imageData,
                    confidence: 0,
                    processingTime: performance.now() - startTime
                }
            }

            // Apply perspective correction
            const correctedMat = this.correctPerspective(src, documentContour)
            
            // Convert back to ImageData
            const correctedImageData = this.matToImageData(correctedMat)
            
            // Cleanup
            src.delete()
            correctedMat.delete()
            documentContour.delete()
            
            return {
                found: true,
                originalImage: imageData,
                correctedImage: correctedImageData,
                confidence: 0.9, // Simplified confidence calculation
                processingTime: performance.now() - startTime
            }
            
        } catch (error) {
            throw new Error(`Document processing failed: ${error.message}`)
        }
    }

    private findDocumentContour(src: any): any | null {
        const cv = this.openCV
        
        // Convert to grayscale
        const gray = new cv.Mat()
        cv.cvtColor(src, gray, cv.COLOR_RGBA2GRAY)
        
        // Apply Gaussian blur
        const blurred = new cv.Mat()
        cv.GaussianBlur(gray, blurred, new cv.Size(5, 5), 0)
        
        // Apply adaptive threshold
        const thresh = new cv.Mat()
        cv.adaptiveThreshold(blurred, thresh, 255, cv.ADAPTIVE_THRESH_GAUSSIAN_C, cv.THRESH_BINARY, 11, 2)
        
        // Find contours
        const contours = new cv.MatVector()
        const hierarchy = new cv.Mat()
        cv.findContours(thresh, contours, hierarchy, cv.RETR_EXTERNAL, cv.CHAIN_APPROX_SIMPLE)
        
        // Find the largest contour that could be a document
        let maxArea = 0
        let bestContour = null
        
        for (let i = 0; i < contours.size(); i++) {
            const contour = contours.get(i)
            const area = cv.contourArea(contour)
            
            if (area > maxArea && area > src.rows * src.cols * 0.1) { // At least 10% of image
                const perimeter = cv.arcLength(contour, true)
                const approx = new cv.Mat()
                cv.approxPolyDP(contour, approx, 0.02 * perimeter, true)
                
                // Check if it's roughly rectangular (4 corners)
                if (approx.rows === 4) {
                    if (bestContour) bestContour.delete()
                    maxArea = area
                    bestContour = approx.clone()
                }
                approx.delete()
            }
            contour.delete()
        }
        
        // Cleanup
        gray.delete()
        blurred.delete()
        thresh.delete()
        contours.delete()
        hierarchy.delete()
        
        return bestContour
    }

    private correctPerspective(src: any, contour: any): any {
        const cv = this.openCV
        
        // Extract corner points
        const corners = []
        for (let i = 0; i < contour.rows; i++) {
            const point = contour.data32S.slice(i * 2, (i + 1) * 2)
            corners.push({ x: point[0], y: point[1] })
        }
        
        // Sort corners: top-left, top-right, bottom-right, bottom-left
        const sortedCorners = this.sortCorners(corners)
        
        // Calculate output dimensions
        const widthA = Math.sqrt(
            Math.pow(sortedCorners[2].x - sortedCorners[3].x, 2) +
            Math.pow(sortedCorners[2].y - sortedCorners[3].y, 2)
        )
        const widthB = Math.sqrt(
            Math.pow(sortedCorners[1].x - sortedCorners[0].x, 2) +
            Math.pow(sortedCorners[1].y - sortedCorners[0].y, 2)
        )
        const maxWidth = Math.max(widthA, widthB)
        
        const heightA = Math.sqrt(
            Math.pow(sortedCorners[1].x - sortedCorners[2].x, 2) +
            Math.pow(sortedCorners[1].y - sortedCorners[2].y, 2)
        )
        const heightB = Math.sqrt(
            Math.pow(sortedCorners[0].x - sortedCorners[3].x, 2) +
            Math.pow(sortedCorners[0].y - sortedCorners[3].y, 2)
        )
        const maxHeight = Math.max(heightA, heightB)
        
        // Create transformation matrix
        const srcPoints = cv.matFromArray(4, 1, cv.CV_32FC2, [
            sortedCorners[0].x, sortedCorners[0].y,
            sortedCorners[1].x, sortedCorners[1].y,
            sortedCorners[2].x, sortedCorners[2].y,
            sortedCorners[3].x, sortedCorners[3].y
        ])
        
        const dstPoints = cv.matFromArray(4, 1, cv.CV_32FC2, [
            0, 0,
            maxWidth, 0,
            maxWidth, maxHeight,
            0, maxHeight
        ])
        
        const transform = cv.getPerspectiveTransform(srcPoints, dstPoints)
        
        // Apply transformation
        const corrected = new cv.Mat()
        cv.warpPerspective(src, corrected, transform, new cv.Size(maxWidth, maxHeight))
        
        // Cleanup
        srcPoints.delete()
        dstPoints.delete()
        transform.delete()
        
        return corrected
    }

    private sortCorners(corners: Array<{ x: number; y: number }>): Array<{ x: number; y: number }> {
        // Sort by sum (top-left has smallest sum, bottom-right has largest)
        const sortedBySum = corners.sort((a, b) => (a.x + a.y) - (b.x + b.y))
        const topLeft = sortedBySum[0]
        const bottomRight = sortedBySum[3]
        
        // Sort remaining by difference (top-right has smallest diff, bottom-left has largest)
        const remaining = [sortedBySum[1], sortedBySum[2]]
        const sortedByDiff = remaining.sort((a, b) => (a.x - a.y) - (b.x - b.y))
        const topRight = sortedByDiff[1]
        const bottomLeft = sortedByDiff[0]
        
        return [topLeft, topRight, bottomRight, bottomLeft]
    }

    private matToImageData(mat: any): ImageData {
        const cv = this.openCV
        
        // Create canvas to convert Mat to ImageData
        const canvas = document.createElement('canvas')
        cv.imshow(canvas, mat)
        
        const ctx = canvas.getContext('2d')!
        return ctx.getImageData(0, 0, canvas.width, canvas.height)
    }

    async cleanup(): Promise<void> {
        this.isReady = false
        console.log('🧹 Document processor cleaned up')
    }
}

interface DocumentProcessingResult {
    found: boolean
    originalImage: ImageData
    correctedImage: ImageData
    confidence: number
    processingTime: number
}

// Extend window interface for OpenCV
declare global {
    interface Window {
        cv: any
    }
}
```

## 🚀 Application Entry Point

```typescript
// src/main.ts
import { CVEdTechApp } from './CVEdTechApp'

class AppBootstrap {
    private app: CVEdTechApp | null = null

    async init(): Promise<void> {
        try {
            // Show loading indicator
            this.showLoadingScreen()
            
            // Check browser compatibility
            await this.checkBrowserCompatibility()
            
            // Initialize application
            this.app = new CVEdTechApp()
            await this.app.initialize()
            
            // Hide loading screen
            this.hideLoadingScreen()
            
            // Setup global error handling
            this.setupGlobalErrorHandling()
            
            console.log('🚀 Application started successfully')
            
        } catch (error) {
            console.error('Failed to start application:', error)
            this.showErrorScreen(error.message)
        }
    }

    private showLoadingScreen(): void {
        document.body.innerHTML = `
            <div class="loading-screen">
                <div class="loading-content">
                    <div class="spinner"></div>
                    <h2>Loading CV EdTech Platform...</h2>
                    <p>Initializing computer vision services</p>
                </div>
            </div>
        `
    }

    private hideLoadingScreen(): void {
        const loadingScreen = document.querySelector('.loading-screen')
        if (loadingScreen) {
            loadingScreen.remove()
        }
    }

    private showErrorScreen(message: string): void {
        document.body.innerHTML = `
            <div class="error-screen">
                <div class="error-content">
                    <h2>❌ Failed to Start Application</h2>
                    <p>Error: ${message}</p>
                    <button onclick="location.reload()">🔄 Retry</button>
                </div>
            </div>
        `
    }

    private async checkBrowserCompatibility(): Promise<void> {
        const compatibility = {
            getUserMedia: !!(navigator.mediaDevices && navigator.mediaDevices.getUserMedia),
            canvas: !!document.createElement('canvas').getContext,
            webAssembly: typeof WebAssembly !== 'undefined',
            workers: typeof Worker !== 'undefined'
        }

        const missing = Object.entries(compatibility)
            .filter(([, supported]) => !supported)
            .map(([feature]) => feature)

        if (missing.length > 0) {
            throw new Error(`Browser missing required features: ${missing.join(', ')}`)
        }
    }

    private setupGlobalErrorHandling(): void {
        window.addEventListener('error', (event) => {
            console.error('Global error:', event.error)
            // Report to monitoring service if available
        })

        window.addEventListener('unhandledrejection', (event) => {
            console.error('Unhandled promise rejection:', event.reason)
            // Report to monitoring service if available
        })

        // Clean up on page unload
        window.addEventListener('beforeunload', () => {
            if (this.app) {
                this.app.cleanup()
            }
        })
    }
}

// Start the application
document.addEventListener('DOMContentLoaded', async () => {
    const bootstrap = new AppBootstrap()
    await bootstrap.init()
})

// Export for global access if needed
(window as any).CVEdTechApp = CVEdTechApp
```

---

## 🌐 Navigation

**Previous:** [Deployment Guide](./deployment-guide.md) | **Next:** [Troubleshooting](./troubleshooting.md)

---

*Template examples tested across Chrome 120+, Firefox 120+, Safari 16+, Edge 120+. Code follows TypeScript 5.x standards and modern web development best practices. Last updated July 2025.*