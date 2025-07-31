# Template Examples: Working Code Samples & Implementation Patterns

> Complete collection of production-ready code examples for mobile-first responsive design implementation

## 🎯 Template Collection Overview

This document provides comprehensive, ready-to-use code examples for implementing mobile-first responsive designs. Each template includes HTML, CSS, and JavaScript implementations with detailed explanations and customization options.

## 📱 Complete Mobile-First Page Template

### Full-Featured Responsive Page

**HTML Structure:**
```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=5.0">
    <meta name="theme-color" content="#1976d2">
    <meta name="apple-mobile-web-app-capable" content="yes">
    <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
    
    <title>Mobile-First Responsive Template</title>
    
    <!-- Critical CSS inline -->
    <style>
        /* Critical above-the-fold styles */
        *{box-sizing:border-box;margin:0;padding:0}
        body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;line-height:1.6;color:#333}
        .container{max-width:100%;padding:0 1rem;margin:0 auto}
        @media(min-width:768px){.container{max-width:768px;padding:0 2rem}}
        @media(min-width:1200px){.container{max-width:1200px}}
        .header{background:#1976d2;color:white;padding:1rem 0}
        .hero{min-height:50vh;display:flex;align-items:center;justify-content:center;text-align:center;background:linear-gradient(135deg,#667eea 0%,#764ba2 100%);color:white}
        .btn{display:inline-block;background:#1976d2;color:white;padding:0.75rem 1.5rem;text-decoration:none;border-radius:8px;font-weight:500;min-height:44px;border:none;cursor:pointer;transition:all 0.2s ease;touch-action:manipulation}
        .btn:hover{background:#1565c0;transform:translateY(-1px)}
    </style>
    
    <!-- Preload non-critical CSS -->
    <link rel="preload" href="styles.css" as="style" onload="this.onload=null;this.rel='stylesheet'">
    <noscript><link rel="stylesheet" href="styles.css"></noscript>
    
    <!-- Performance optimizations -->
    <link rel="dns-prefetch" href="//fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
</head>
<body>
    <!-- Skip to content for accessibility -->
    <a class="skip-link" href="#main-content">Skip to main content</a>
    
    <!-- Mobile-first header -->
    <header class="header" role="banner">
        <div class="container">
            <nav class="navbar" role="navigation" aria-label="Main navigation">
                <div class="navbar-brand">
                    <a href="/" class="brand-link">
                        <h1 class="brand-title">EdTech Platform</h1>
                    </a>
                </div>
                
                <button 
                    class="nav-toggle" 
                    aria-expanded="false" 
                    aria-controls="nav-menu"
                    aria-label="Toggle navigation menu"
                    data-nav-toggle
                >
                    <span class="hamburger-line"></span>
                    <span class="hamburger-line"></span>
                    <span class="hamburger-line"></span>
                </button>
                
                <div class="nav-menu" id="nav-menu" data-nav-menu>
                    <ul class="nav-list" role="menubar">
                        <li role="none">
                            <a href="/" class="nav-link" role="menuitem">Home</a>
                        </li>
                        <li role="none">
                            <a href="/courses" class="nav-link" role="menuitem">Courses</a>
                        </li>
                        <li role="none">
                            <a href="/exams" class="nav-link" role="menuitem">Practice Exams</a>
                        </li>
                        <li role="none">
                            <a href="/about" class="nav-link" role="menuitem">About</a>
                        </li>
                        <li role="none">
                            <a href="/contact" class="nav-link" role="menuitem">Contact</a>
                        </li>
                    </ul>
                </div>
            </nav>
        </div>
    </header>
    
    <!-- Hero section -->
    <section class="hero" role="banner">
        <div class="container">
            <div class="hero-content">
                <h2 class="hero-title">Master Your Licensure Exams</h2>
                <p class="hero-description">
                    Comprehensive review materials and practice tests for Philippine professional licensure examinations.
                </p>
                <div class="hero-actions">
                    <a href="/signup" class="btn btn-primary">Get Started</a>
                    <a href="/demo" class="btn btn-secondary">Try Demo</a>
                </div>
            </div>
        </div>
    </section>
    
    <!-- Main content -->
    <main id="main-content" role="main">
        <!-- Features section -->
        <section class="features" aria-labelledby="features-heading">
            <div class="container">
                <h2 id="features-heading" class="section-title">Platform Features</h2>
                <div class="features-grid">
                    <article class="feature-card">
                        <div class="feature-icon" aria-hidden="true">📚</div>
                        <h3 class="feature-title">Comprehensive Content</h3>
                        <p class="feature-description">
                            Extensive review materials covering all major licensure exam topics.
                        </p>
                    </article>
                    
                    <article class="feature-card">
                        <div class="feature-icon" aria-hidden="true">📝</div>
                        <h3 class="feature-title">Practice Tests</h3>
                        <p class="feature-description">
                            Realistic practice exams with detailed explanations and scoring.
                        </p>
                    </article>
                    
                    <article class="feature-card">
                        <div class="feature-icon" aria-hidden="true">📊</div>
                        <h3 class="feature-title">Progress Tracking</h3>
                        <p class="feature-description">
                            Monitor your learning progress with detailed analytics and insights.
                        </p>
                    </article>
                    
                    <article class="feature-card">
                        <div class="feature-icon" aria-hidden="true">📱</div>
                        <h3 class="feature-title">Mobile Learning</h3>
                        <p class="feature-description">
                            Study anywhere, anytime with our mobile-optimized platform.
                        </p>
                    </article>
                </div>
            </div>
        </section>
        
        <!-- CTA section -->
        <section class="cta" aria-labelledby="cta-heading">
            <div class="container">
                <div class="cta-content">
                    <h2 id="cta-heading" class="cta-title">Ready to Start Your Journey?</h2>
                    <p class="cta-description">
                        Join thousands of successful professionals who achieved their licensure goals with our platform.
                    </p>
                    <a href="/signup" class="btn btn-large">Start Learning Today</a>
                </div>
            </div>
        </section>
    </main>
    
    <!-- Footer -->
    <footer class="footer" role="contentinfo">
        <div class="container">
            <div class="footer-content">
                <div class="footer-section">
                    <h3 class="footer-title">EdTech Platform</h3>
                    <p class="footer-description">
                        Empowering Filipino professionals through comprehensive exam preparation.
                    </p>
                </div>
                
                <div class="footer-section">
                    <h4 class="footer-heading">Quick Links</h4>
                    <ul class="footer-links">
                        <li><a href="/courses">Courses</a></li>
                        <li><a href="/exams">Practice Exams</a></li>
                        <li><a href="/pricing">Pricing</a></li>
                        <li><a href="/support">Support</a></li>
                    </ul>
                </div>
                
                <div class="footer-section">
                    <h4 class="footer-heading">Contact</h4>
                    <ul class="footer-links">
                        <li><a href="mailto:info@edtech.ph">info@edtech.ph</a></li>
                        <li><a href="tel:+639123456789">+63 912 345 6789</a></li>
                    </ul>
                </div>
            </div>
            
            <div class="footer-bottom">
                <p>&copy; 2025 EdTech Platform. All rights reserved.</p>
            </div>
        </div>
    </footer>
    
    <!-- JavaScript -->
    <script src="app.js" defer></script>
</body>
</html>
```

**Complete CSS (styles.css):**
```css
/* CSS Custom Properties */
:root {
  /* Color system */
  --color-primary: #1976d2;
  --color-primary-dark: #1565c0;
  --color-primary-light: #42a5f5;
  --color-secondary: #dc004e;
  --color-background: #ffffff;
  --color-surface: #f5f5f5;
  --color-text: #212121;
  --color-text-secondary: #757575;
  --color-border: #e0e0e0;
  --color-success: #4caf50;
  --color-warning: #ff9800;
  --color-error: #f44336;
  
  /* Typography */
  --font-family-base: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
  --font-size-xs: 0.75rem;
  --font-size-sm: 0.875rem;
  --font-size-base: 1rem;
  --font-size-lg: 1.125rem;
  --font-size-xl: 1.25rem;
  --font-size-2xl: 1.5rem;
  --font-size-3xl: 1.875rem;
  --font-size-4xl: 2.25rem;
  
  /* Spacing */
  --space-xs: 0.25rem;
  --space-sm: 0.5rem;
  --space-md: 1rem;
  --space-lg: 1.5rem;
  --space-xl: 2rem;
  --space-2xl: 3rem;
  --space-3xl: 4rem;
  
  /* Layout */
  --container-max-width: 1200px;
  --container-padding: var(--space-md);
  --border-radius: 8px;
  --border-radius-lg: 12px;
  --box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
  --box-shadow-lg: 0 4px 12px rgba(0, 0, 0, 0.15);
  
  /* Animation */
  --transition-fast: 150ms ease;
  --transition-base: 300ms ease;
  --transition-slow: 500ms ease;
  
  /* Touch targets */
  --touch-target-min: 44px;
}

/* Dark theme support */
@media (prefers-color-scheme: dark) {
  :root {
    --color-background: #121212;
    --color-surface: #1e1e1e;
    --color-text: #ffffff;
    --color-text-secondary: #b3b3b3;
    --color-border: #333333;
  }
}

/* Responsive typography scaling */
@media (min-width: 768px) {
  :root {
    --font-size-2xl: 2rem;
    --font-size-3xl: 2.5rem;
    --font-size-4xl: 3rem;
    --container-padding: var(--space-xl);
  }
}

@media (min-width: 1024px) {
  :root {
    --font-size-3xl: 3rem;
    --font-size-4xl: 3.5rem;
    --container-padding: var(--space-2xl);
  }
}

/* Reset and base styles */
*,
*::before,
*::after {
  box-sizing: border-box;
}

* {
  margin: 0;
  padding: 0;
}

html {
  scroll-behavior: smooth;
  overflow-x: hidden;
}

body {
  font-family: var(--font-family-base);
  font-size: var(--font-size-base);
  line-height: 1.6;
  color: var(--color-text);
  background: var(--color-background);
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}

/* Skip link for accessibility */
.skip-link {
  position: absolute;
  top: -40px;
  left: 6px;
  background: var(--color-primary);
  color: white;
  padding: 8px 16px;
  border-radius: var(--border-radius);
  text-decoration: none;
  font-weight: 500;
  z-index: 1000;
  transition: top var(--transition-base);
}

.skip-link:focus {
  top: 6px;
}

/* Container */
.container {
  width: 100%;
  max-width: var(--container-max-width);
  padding: 0 var(--container-padding);
  margin: 0 auto;
}

/* Header and Navigation */
.header {
  background: var(--color-primary);
  color: white;
  padding: var(--space-md) 0;
  position: sticky;
  top: 0;
  z-index: 100;
  box-shadow: var(--box-shadow);
}

.navbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.brand-link {
  text-decoration: none;
  color: inherit;
}

.brand-title {
  font-size: var(--font-size-xl);
  font-weight: 700;
  margin: 0;
}

.nav-toggle {
  display: flex;
  flex-direction: column;
  justify-content: center;
  gap: 4px;
  width: var(--touch-target-min);
  height: var(--touch-target-min);
  background: none;
  border: none;
  cursor: pointer;
  padding: 8px;
  border-radius: var(--border-radius);
  transition: background-color var(--transition-fast);
}

.nav-toggle:hover,
.nav-toggle:focus {
  background: rgba(255, 255, 255, 0.1);
  outline: none;
}

.hamburger-line {
  display: block;
  width: 24px;
  height: 2px;
  background: white;
  transition: all var(--transition-base);
  transform-origin: center;
}

.nav-toggle[aria-expanded="true"] .hamburger-line:nth-child(1) {
  transform: rotate(45deg) translate(5px, 5px);
}

.nav-toggle[aria-expanded="true"] .hamburger-line:nth-child(2) {
  opacity: 0;
}

.nav-toggle[aria-expanded="true"] .hamburger-line:nth-child(3) {
  transform: rotate(-45deg) translate(7px, -6px);
}

.nav-menu {
  position: absolute;
  top: 100%;
  left: 0;
  right: 0;
  background: var(--color-primary);
  border-top: 1px solid rgba(255, 255, 255, 0.1);
  box-shadow: var(--box-shadow-lg);
  max-height: 0;
  overflow: hidden;
  transition: max-height var(--transition-base);
}

.nav-menu[aria-expanded="true"] {
  max-height: 400px;
}

.nav-list {
  display: flex;
  flex-direction: column;
  list-style: none;
  padding: var(--space-sm) 0;
}

.nav-link {
  display: block;
  padding: var(--space-md) var(--space-lg);
  color: white;
  text-decoration: none;
  font-weight: 500;
  transition: background-color var(--transition-fast);
  min-height: var(--touch-target-min);
  display: flex;
  align-items: center;
}

.nav-link:hover,
.nav-link:focus {
  background: rgba(255, 255, 255, 0.1);
  outline: none;
}

/* Desktop navigation */
@media (min-width: 768px) {
  .nav-toggle {
    display: none;
  }
  
  .nav-menu {
    position: static;
    max-height: none;
    background: transparent;
    border: none;
    box-shadow: none;
  }
  
  .nav-list {
    flex-direction: row;
    padding: 0;
    gap: var(--space-sm);
  }
  
  .nav-link {
    padding: var(--space-sm) var(--space-md);
    border-radius: var(--border-radius);
    min-height: auto;
  }
}

/* Hero section */
.hero {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
  padding: var(--space-3xl) 0;
  text-align: center;
  min-height: 60vh;
  display: flex;
  align-items: center;
}

.hero-content {
  max-width: 600px;
  margin: 0 auto;
}

.hero-title {
  font-size: var(--font-size-3xl);
  font-weight: 700;
  margin-bottom: var(--space-lg);
  line-height: 1.2;
}

.hero-description {
  font-size: var(--font-size-lg);
  margin-bottom: var(--space-2xl);
  opacity: 0.9;
}

.hero-actions {
  display: flex;
  flex-direction: column;
  gap: var(--space-md);
  align-items: center;
}

@media (min-width: 480px) {
  .hero-actions {
    flex-direction: row;
    justify-content: center;
  }
}

/* Buttons */
.btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: var(--space-sm);
  padding: var(--space-md) var(--space-xl);
  font-size: var(--font-size-base);
  font-weight: 500;
  text-decoration: none;
  border-radius: var(--border-radius);
  border: 2px solid transparent;
  cursor: pointer;
  transition: all var(--transition-fast);
  min-height: var(--touch-target-min);
  min-width: var(--touch-target-min);
  touch-action: manipulation;
  -webkit-tap-highlight-color: transparent;
}

.btn-primary {
  background: var(--color-primary);
  color: white;
  border-color: var(--color-primary);
}

.btn-primary:hover,
.btn-primary:focus {
  background: var(--color-primary-dark);
  border-color: var(--color-primary-dark);
  transform: translateY(-1px);
  outline: none;
}

.btn-secondary {
  background: transparent;
  color: white;
  border-color: white;
}

.btn-secondary:hover,
.btn-secondary:focus {
  background: white;
  color: var(--color-primary);
  outline: none;
}

.btn-large {
  padding: var(--space-lg) var(--space-2xl);
  font-size: var(--font-size-lg);
  min-height: 56px;
}

/* Mobile button adjustments */
@media (max-width: 479px) {
  .btn {
    width: 100%;
    justify-content: center;
  }
}

/* Sections */
.section-title {
  font-size: var(--font-size-2xl);
  font-weight: 700;
  text-align: center;
  margin-bottom: var(--space-2xl);
  color: var(--color-text);
}

/* Features section */
.features {
  padding: var(--space-3xl) 0;
  background: var(--color-surface);
}

.features-grid {
  display: grid;
  gap: var(--space-xl);
  grid-template-columns: 1fr;
}

@media (min-width: 480px) {
  .features-grid {
    grid-template-columns: repeat(2, 1fr);
  }
}

@media (min-width: 1024px) {
  .features-grid {
    grid-template-columns: repeat(4, 1fr);
  }
}

.feature-card {
  background: white;
  padding: var(--space-xl);
  border-radius: var(--border-radius-lg);
  box-shadow: var(--box-shadow);
  text-align: center;
  transition: transform var(--transition-base), box-shadow var(--transition-base);
}

.feature-card:hover {
  transform: translateY(-4px);
  box-shadow: var(--box-shadow-lg);
}

.feature-icon {
  font-size: 3rem;
  margin-bottom: var(--space-lg);
}

.feature-title {
  font-size: var(--font-size-xl);
  font-weight: 600;
  margin-bottom: var(--space-md);
  color: var(--color-text);
}

.feature-description {
  color: var(--color-text-secondary);
  line-height: 1.6;
}

/* CTA section */
.cta {
  background: var(--color-primary);
  color: white;
  padding: var(--space-3xl) 0;
  text-align: center;
}

.cta-title {
  font-size: var(--font-size-2xl);
  font-weight: 700;
  margin-bottom: var(--space-lg);
}

.cta-description {
  font-size: var(--font-size-lg);
  margin-bottom: var(--space-2xl);
  opacity: 0.9;
  max-width: 600px;
  margin-left: auto;
  margin-right: auto;
}

/* Footer */
.footer {
  background: var(--color-text);
  color: white;
  padding: var(--space-2xl) 0 var(--space-lg);
}

.footer-content {
  display: grid;
  gap: var(--space-xl);
  grid-template-columns: 1fr;
  margin-bottom: var(--space-xl);
}

@media (min-width: 768px) {
  .footer-content {
    grid-template-columns: 2fr 1fr 1fr;
  }
}

.footer-title {
  font-size: var(--font-size-xl);
  font-weight: 700;
  margin-bottom: var(--space-md);
}

.footer-heading {
  font-size: var(--font-size-lg);
  font-weight: 600;
  margin-bottom: var(--space-md);
}

.footer-description {
  opacity: 0.8;
  line-height: 1.6;
}

.footer-links {
  list-style: none;
}

.footer-links li {
  margin-bottom: var(--space-sm);
}

.footer-links a {
  color: white;
  text-decoration: none;
  opacity: 0.8;
  transition: opacity var(--transition-fast);
}

.footer-links a:hover,
.footer-links a:focus {
  opacity: 1;
  outline: none;
}

.footer-bottom {
  border-top: 1px solid rgba(255, 255, 255, 0.2);
  padding-top: var(--space-lg);
  text-align: center;
  opacity: 0.6;
}

/* Responsive utilities */
@media (prefers-reduced-motion: reduce) {
  *,
  *::before,
  *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
    scroll-behavior: auto !important;
  }
}

/* Focus styles for accessibility */
*:focus-visible {
  outline: 2px solid var(--color-primary);
  outline-offset: 2px;
}

/* High contrast mode support */
@media (prefers-contrast: high) {
  .btn {
    border-width: 3px;
  }
  
  .feature-card {
    border: 2px solid var(--color-border);
  }
}

/* Print styles */
@media print {
  .nav-toggle,
  .hero-actions,
  .cta {
    display: none;
  }
  
  .hero {
    background: none;
    color: black;
    min-height: auto;
    padding: var(--space-lg) 0;
  }
  
  .footer {
    background: none;
    color: black;
  }
}
```

**JavaScript (app.js):**
```javascript
// Mobile-first responsive JavaScript
class ResponsiveApp {
    constructor() {
        this.init();
    }
    
    init() {
        this.setupNavigation();
        this.setupResponsiveImages();
        this.setupIntersectionObserver();
        this.setupTouchEnhancements();
        this.setupPerformanceMonitoring();
    }
    
    setupNavigation() {
        const navToggle = document.querySelector('[data-nav-toggle]');
        const navMenu = document.querySelector('[data-nav-menu]');
        
        if (navToggle && navMenu) {
            navToggle.addEventListener('click', () => {
                const isExpanded = navToggle.getAttribute('aria-expanded') === 'true';
                
                navToggle.setAttribute('aria-expanded', !isExpanded);
                navMenu.setAttribute('aria-expanded', !isExpanded);
                
                // Focus management
                if (!isExpanded) {
                    const firstLink = navMenu.querySelector('a');
                    if (firstLink) {
                        setTimeout(() => firstLink.focus(), 100);
                    }
                }
            });
            
            // Close menu when clicking outside
            document.addEventListener('click', (e) => {
                if (!navToggle.contains(e.target) && !navMenu.contains(e.target)) {
                    navToggle.setAttribute('aria-expanded', 'false');
                    navMenu.setAttribute('aria-expanded', 'false');
                }
            });
            
            // Close menu on escape key
            document.addEventListener('keydown', (e) => {
                if (e.key === 'Escape') {
                    navToggle.setAttribute('aria-expanded', 'false');
                    navMenu.setAttribute('aria-expanded', 'false');
                    navToggle.focus();
                }
            });
            
            // Handle resize events
            window.addEventListener('resize', () => {
                if (window.innerWidth >= 768) {
                    navToggle.setAttribute('aria-expanded', 'false');
                    navMenu.setAttribute('aria-expanded', 'false');
                }
            });
        }
    }
    
    setupResponsiveImages() {
        // Lazy loading with Intersection Observer
        if ('IntersectionObserver' in window) {
            const imageObserver = new IntersectionObserver((entries) => {
                entries.forEach(entry => {
                    if (entry.isIntersecting) {
                        const img = entry.target;
                        const src = img.dataset.src;
                        
                        if (src) {
                            img.src = src;
                            img.removeAttribute('data-src');
                            img.classList.add('loaded');
                            imageObserver.unobserve(img);
                        }
                    }
                });
            }, {
                rootMargin: '50px 0px'
            });
            
            document.querySelectorAll('img[data-src]').forEach(img => {
                imageObserver.observe(img);
            });
        }
    }
    
    setupIntersectionObserver() {
        // Animate elements on scroll
        if ('IntersectionObserver' in window) {
            const animateObserver = new IntersectionObserver((entries) => {
                entries.forEach(entry => {
                    if (entry.isIntersecting) {
                        entry.target.classList.add('animate-in');
                        animateObserver.unobserve(entry.target);
                    }
                });
            }, {
                threshold: 0.1
            });
            
            document.querySelectorAll('.feature-card').forEach(card => {
                animateObserver.observe(card);
            });
        }
    }
    
    setupTouchEnhancements() {
        // Add touch feedback for buttons
        const buttons = document.querySelectorAll('.btn, .nav-link');
        
        buttons.forEach(button => {
            button.addEventListener('touchstart', () => {
                button.style.transform = 'scale(0.95)';
            }, { passive: true });
            
            button.addEventListener('touchend', () => {
                setTimeout(() => {
                    button.style.transform = '';
                }, 100);
            }, { passive: true });
        });
        
        // Prevent iOS zoom on input focus
        const inputs = document.querySelectorAll('input, textarea, select');
        
        inputs.forEach(input => {
            // Ensure font size is at least 16px to prevent zoom
            const computedStyle = window.getComputedStyle(input);
            const fontSize = parseFloat(computedStyle.fontSize);
            
            if (fontSize < 16) {
                input.style.fontSize = '16px';
            }
        });
    }
    
    setupPerformanceMonitoring() {
        // Monitor Core Web Vitals
        if ('PerformanceObserver' in window) {
            // Largest Contentful Paint
            new PerformanceObserver((list) => {
                const entries = list.getEntries();
                const lastEntry = entries[entries.length - 1];
                console.log('LCP:', lastEntry.startTime);
            }).observe({ entryTypes: ['largest-contentful-paint'] });
            
            // First Input Delay
            new PerformanceObserver((list) => {
                const entries = list.getEntries();
                entries.forEach((entry) => {
                    const fid = entry.processingStart - entry.startTime;
                    console.log('FID:', fid);
                });
            }).observe({ entryTypes: ['first-input'] });
            
            // Cumulative Layout Shift
            let clsValue = 0;
            new PerformanceObserver((list) => {
                for (const entry of list.getEntries()) {
                    if (!entry.hadRecentInput) {
                        clsValue += entry.value;
                    }
                }
                console.log('CLS:', clsValue);
            }).observe({ entryTypes: ['layout-shift'] });
        }
    }
}

// Initialize app when DOM is ready
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => {
        new ResponsiveApp();
    });
} else {
    new ResponsiveApp();
}

// Service Worker registration for PWA capabilities
if ('serviceWorker' in navigator) {
    window.addEventListener('load', () => {
        navigator.serviceWorker.register('/sw.js')
            .then((registration) => {
                console.log('SW registered: ', registration);
            })
            .catch((registrationError) => {
                console.log('SW registration failed: ', registrationError);
            });
    });
}
```

## 🎨 Component Templates

### Responsive Card Component

**React Component Example:**
```jsx
// ResponsiveCard.jsx
import React, { useState, useRef, useEffect } from 'react';
import './ResponsiveCard.css';

const ResponsiveCard = ({ 
  title, 
  description, 
  image, 
  action, 
  layout = 'auto',
  priority = 'normal'
}) => {
  const [isInView, setIsInView] = useState(false);
  const cardRef = useRef(null);
  
  useEffect(() => {
    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) {
          setIsInView(true);
          observer.unobserve(entry.target);
        }
      },
      { threshold: 0.1 }
    );
    
    if (cardRef.current) {
      observer.observe(cardRef.current);
    }
    
    return () => observer.disconnect();
  }, []);
  
  return (
    <article 
      ref={cardRef}
      className={`responsive-card ${layout} ${priority} ${isInView ? 'animate-in' : ''}`}
      data-testid="responsive-card"
    >
      {image && (
        <div className="card-image">
          <img 
            src={image} 
            alt={title}
            loading={priority === 'high' ? 'eager' : 'lazy'}
            decoding="async"
          />
        </div>
      )}
      
      <div className="card-content">
        <h3 className="card-title">{title}</h3>
        <p className="card-description">{description}</p>
        
        {action && (
          <div className="card-actions">
            <button className="btn btn-primary">
              {action}
            </button>
          </div>
        )}
      </div>
    </article>
  );
};

export default ResponsiveCard;
```

**Responsive Card CSS:**
```css
/* ResponsiveCard.css */
.responsive-card {
  background: white;
  border-radius: var(--border-radius-lg);
  box-shadow: var(--box-shadow);
  overflow: hidden;
  transition: all var(--transition-base);
  display: flex;
  flex-direction: column;
  height: 100%;
  
  /* Animation preparation */
  opacity: 0;
  transform: translateY(20px);
}

.responsive-card.animate-in {
  opacity: 1;
  transform: translateY(0);
}

.responsive-card:hover {  
  transform: translateY(-4px);
  box-shadow: var(--box-shadow-lg);
}

.card-image {
  aspect-ratio: 16 / 9;
  overflow: hidden;
  background: var(--color-surface);
}

.card-image img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  object-position: center;
  transition: transform var(--transition-slow);
}

.card-image img:hover {
  transform: scale(1.05);
}

.card-content {
  padding: var(--space-lg);
  display: flex;
  flex-direction: column;
  flex-grow: 1;
}

.card-title {
  font-size: var(--font-size-xl);
  font-weight: 600;
  margin-bottom: var(--space-md);
  color: var(--color-text);
  line-height: 1.3;
}

.card-description {
  color: var(--color-text-secondary);
  line-height: 1.6;
  flex-grow: 1;
  margin-bottom: var(--space-lg);
}

.card-actions {
  margin-top: auto;
}

/* Responsive layouts */
@media (min-width: 768px) {
  .responsive-card.horizontal {
    flex-direction: row;
    align-items: stretch;
  }
  
  .responsive-card.horizontal .card-image {
    flex: 0 0 40%;
    aspect-ratio: auto;
  }
  
  .responsive-card.horizontal .card-content {
    flex: 1;
  }
}

@media (min-width: 1024px) {
  .responsive-card.horizontal {
    flex-direction: column;
  }
  
  .responsive-card.horizontal .card-image {
    flex: none;
    aspect-ratio: 16 / 9;
  }
}

/* Priority-based loading */
.responsive-card.high img {
  loading: eager;
}

.responsive-card.normal img {
  loading: lazy;
}

/* Touch optimizations */
@media (hover: none) and (pointer: coarse) {
  .responsive-card:hover {
    transform: none;
  }
  
  .responsive-card:active {
    transform: scale(0.98);
  }
}

/* Reduced motion support */
@media (prefers-reduced-motion: reduce) {
  .responsive-card {
    opacity: 1;
    transform: none;
    transition: none;
  }
  
  .responsive-card.animate-in {
    animation: none;
  }
}
```

### Progressive Web App Manifest

**manifest.json:**
```json
{
  "name": "EdTech Platform - Philippine Licensure Exam Review",
  "short_name": "EdTech PH",
  "description": "Comprehensive review platform for Philippine professional licensure examinations with mobile-first design.",
  "start_url": "/",
  "display": "standalone",
  "orientation": "portrait-primary",
  "theme_color": "#1976d2",
  "background_color": "#ffffff",
  "lang": "en",
  "scope": "/",
  "categories": ["education", "productivity"],
  "icons": [
    {
      "src": "/icons/icon-72x72.png",
      "sizes": "72x72",
      "type": "image/png",
      "purpose": "maskable any"
    },
    {
      "src": "/icons/icon-96x96.png",
      "sizes": "96x96",
      "type": "image/png",
      "purpose": "maskable any"
    },
    {
      "src": "/icons/icon-128x128.png",
      "sizes": "128x128",
      "type": "image/png",
      "purpose": "maskable any"
    },
    {
      "src": "/icons/icon-144x144.png",
      "sizes": "144x144",
      "type": "image/png",
      "purpose": "maskable any"
    },
    {
      "src": "/icons/icon-152x152.png",
      "sizes": "152x152",
      "type": "image/png",
      "purpose": "maskable any"
    },
    {
      "src": "/icons/icon-192x192.png",
      "sizes": "192x192",
      "type": "image/png",
      "purpose": "maskable any"
    },
    {
      "src": "/icons/icon-384x384.png",
      "sizes": "384x384",
      "type": "image/png",
      "purpose": "maskable any"
    },
    {
      "src": "/icons/icon-512x512.png",
      "sizes": "512x512",
      "type": "image/png",
      "purpose": "maskable any"
    }
  ],
  "screenshots": [
    {
      "src": "/screenshots/mobile-home.png",
      "sizes": "375x812",
      "type": "image/png",
      "form_factor": "narrow"
    },
    {
      "src": "/screenshots/desktop-home.png",
      "sizes": "1280x720",
      "type": "image/png",
      "form_factor": "wide"
    }
  ],
  "features": [
    "Cross-platform",
    "Offline support",
    "Touch optimized",
    "Responsive design"
  ],
  "prefer_related_applications": false
}
```

### Service Worker for Offline Support

**sw.js:**
```javascript
// Service Worker for PWA capabilities
const CACHE_NAME = 'edtech-v1.0.0';
const STATIC_CACHE_URLS = [
  '/',
  '/styles.css',
  '/app.js',
  '/manifest.json',
  '/icons/icon-192x192.png',
  '/icons/icon-512x512.png',
  '/offline.html'
];

// Install event - cache static assets
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then((cache) => {
        console.log('Caching static assets');
        return cache.addAll(STATIC_CACHE_URLS);
      })
      .then(() => {
        console.log('Service worker installed');
        return self.skipWaiting();
      })
  );
});

// Activate event - clean up old caches
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys()
      .then((cacheNames) => {
        return Promise.all(
          cacheNames.map((cacheName) => {
            if (cacheName !== CACHE_NAME) {
              console.log('Deleting old cache:', cacheName);
              return caches.delete(cacheName);
            }
          })
        );
      })
      .then(() => {
        console.log('Service worker activated');
        return self.clients.claim();
      })
  );
});

// Fetch event - serve from cache with network fallback
self.addEventListener('fetch', (event) => {
  // Skip non-HTTP requests
  if (!event.request.url.startsWith('http')) {
    return;
  }
  
  event.respondWith(
    caches.match(event.request)
      .then((cachedResponse) => {
        // Return cached version if available
        if (cachedResponse) {
          // Update cache in background for dynamic content
          if (!STATIC_CACHE_URLS.includes(event.request.url)) {
            fetch(event.request)
              .then((response) => {
                if (response.status === 200) {
                  caches.open(CACHE_NAME)
                    .then((cache) => {
                      cache.put(event.request, response.clone());
                    });
                }
              })
              .catch(() => {
                // Network request failed, keep using cached version
              });
          }
          
          return cachedResponse;
        }
        
        // Not in cache, fetch from network
        return fetch(event.request)
          .then((response) => {
            // Only cache successful responses
            if (response.status === 200) {
              const responseClone = response.clone();
              caches.open(CACHE_NAME)
                .then((cache) => {
                  cache.put(event.request, responseClone);
                });
            }
            
            return response;
          })
          .catch(() => {
            // Network request failed, show offline page for navigation requests
            if (event.request.mode === 'navigate') {
              return caches.match('/offline.html');
            }
            
            // For other requests, return a generic error response
            return new Response('Network error', { 
              status: 408,
              headers: { 'Content-Type': 'text/plain' }
            });
          });
      })
  );
});

// Background sync for offline actions
self.addEventListener('sync', (event) => {
  if (event.tag === 'background-sync') {
    event.waitUntil(
      // Handle background sync logic
      console.log('Background sync triggered')
    );
  }
});

// Push notifications
self.addEventListener('push', (event) => {
  const options = {
    body: event.data ? event.data.text() : 'New update available',
    icon: '/icons/icon-192x192.png',
    badge: '/icons/badge-72x72.png',
    vibrate: [100, 50, 100],
    data: {
      dateOfArrival: Date.now(),
      primaryKey: 1
    },
    actions: [
      {
        action: 'explore',
        title: 'Open App',
        icon: '/icons/checkmark.png'
      },
      {
        action: 'close',
        title: 'Close',
        icon: '/icons/xmark.png'
      }
    ]
  };
  
  event.waitUntil(
    self.registration.showNotification('EdTech Platform', options)
  );
});

// Notification click handling
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  
  if (event.action === 'explore') {
    event.waitUntil(
      clients.openWindow('/')
    );
  }
});
```

## 📋 Implementation Checklist

### Template Usage Checklist

**Mobile-First Setup:**
- [ ] Viewport meta tag properly configured
- [ ] CSS custom properties defined for responsive design
- [ ] Mobile-first media queries implemented
- [ ] Touch-friendly interactive elements (44px minimum)
- [ ] Performance optimizations applied

**Accessibility Compliance:**
- [ ] Semantic HTML structure used
- [ ] Skip links implemented
- [ ] ARIA attributes properly applied
- [ ] Focus management working
- [ ] Color contrast meets WCAG standards

**Performance Optimization:**
- [ ] Critical CSS inlined
- [ ] Non-critical CSS loaded asynchronously
- [ ] Images optimized and responsive
- [ ] Service worker implemented
- [ ] PWA manifest configured

**Cross-Device Testing:**
- [ ] Tested on multiple mobile devices
- [ ] Desktop layout verified
- [ ] Tablet experience optimized
- [ ] Touch interactions validated
- [ ] Keyboard navigation confirmed

**SEO & PWA Features:**
- [ ] Meta tags properly configured
- [ ] Structured data implemented
- [ ] PWA manifest complete
- [ ] Service worker registered
- [ ] Offline functionality working

---

## 🔗 Navigation

**[← Testing Strategies](./testing-strategies.md)** | **[🏠 Main Research Hub](../README.md)**

### Related Documents
- [Implementation Guide](./implementation-guide.md) - Step-by-step implementation
- [Best Practices](./best-practices.md) - Industry recommendations  
- [Performance Analysis](./performance-analysis.md) - Performance optimization strategies

---

*Template Examples | Working Code Samples & Implementation Patterns*
*Production-ready templates for mobile-first responsive design | January 2025*