# Styling Extraction Methods: Mining Design Patterns from Component Libraries

## 🎯 Overview

This guide provides systematic methodologies for extracting, analyzing, and adapting styling patterns from **Mantine** and **Ant Design** component libraries for integration with **shadcn/ui**. Learn how to reverse-engineer design systems and translate visual patterns into reusable code.

## 🔍 Analysis Methodology

### **Step 1: Component Inventory & Mapping**

#### **Target Component Identification**
```markdown
## High-Priority Components for Styling Extraction

### Core Components (Extract First)
- **Button** - Most visible, high impact
- **Input/TextInput** - Frequent usage, brand touchpoint
- **Card** - Layout foundation, visual hierarchy
- **Badge/Chip** - Information density, micro-interactions

### Secondary Components (Extract Second)  
- **Select/Dropdown** - Complex interactions, accessibility
- **Modal/Dialog** - Overlay patterns, focus management
- **Tabs** - Navigation patterns, state management
- **Table** - Data presentation, responsive patterns

### Advanced Components (Extract Later)
- **DatePicker** - Complex state, calendar interactions
- **Tooltip** - Positioning, timing, content overflow
- **AutoComplete** - Search patterns, filtering
- **Drawer/Sidebar** - Layout shifts, responsive behavior
```

#### **Component State Analysis**
```typescript
// Systematic state enumeration for each target component
interface ComponentStateAnalysis {
  component: string
  states: {
    visual: string[]      // hover, focus, active, disabled, loading
    semantic: string[]    // success, error, warning, info
    size: string[]        // xs, sm, md, lg, xl
    variant: string[]     // filled, outline, light, subtle, ghost
  }
  interactions: string[]  // click, keydown, drag, scroll
  animations: string[]    // enter, exit, loading, state transitions
}

// Example: Button analysis
const buttonAnalysis: ComponentStateAnalysis = {
  component: 'Button',
  states: {
    visual: ['default', 'hover', 'focus', 'active', 'disabled', 'loading'],
    semantic: ['primary', 'secondary', 'success', 'error', 'warning'],
    size: ['xs', 'sm', 'md', 'lg', 'xl'],
    variant: ['filled', 'outline', 'light', 'subtle', 'gradient']
  },
  interactions: ['click', 'keydown', 'focus', 'blur'],
  animations: ['hover-scale', 'press-scale', 'loading-spin', 'focus-ring']
}
```

### **Step 2: Design Token Extraction**

#### **Automated Token Extraction with Browser DevTools**
```javascript
// Browser console script for extracting Mantine design tokens
function extractMantineTokens() {
  const tokens = {}
  
  // Extract CSS custom properties from Mantine components
  const mantineElements = document.querySelectorAll('[class*="mantine-"]')
  
  mantineElements.forEach(element => {
    const computedStyle = getComputedStyle(element)
    const classNames = element.className.split(' ')
    
    classNames.forEach(className => {
      if (className.includes('mantine-')) {
        tokens[className] = {
          backgroundColor: computedStyle.backgroundColor,
          color: computedStyle.color,
          borderRadius: computedStyle.borderRadius,
          padding: computedStyle.padding,
          fontSize: computedStyle.fontSize,
          fontWeight: computedStyle.fontWeight,
          boxShadow: computedStyle.boxShadow,
          border: computedStyle.border
        }
      }
    })
  })
  
  return tokens
}

// Run extraction
const mantineTokens = extractMantineTokens()
console.table(mantineTokens)

// Export for analysis
copy(JSON.stringify(mantineTokens, null, 2))
```

#### **Design Token Analysis Workflow**
```bash
# 1. Create analysis workspace
mkdir design-token-analysis
cd design-token-analysis

# 2. Setup extraction tools
npm init -y
npm install playwright puppeteer css-tree postcss

# 3. Run automated extraction
node extract-mantine-tokens.js
node extract-antd-tokens.js

# 4. Generate comparison report
node compare-design-systems.js
```

#### **Mantine Color Palette Extraction**
```typescript
// scripts/extract-mantine-colors.ts
import { load } from 'cheerio'
import axios from 'axios'

async function extractMantineColors() {
  // Fetch Mantine documentation
  const response = await axios.get('https://mantine.dev/theming/colors/')
  const $ = load(response.data)
  
  const colorPalettes: Record<string, string[]> = {}
  
  // Extract color swatches from documentation
  $('.mantine-ColorPalette-color').each((index, element) => {
    const colorName = $(element).attr('data-color')
    const colorValue = $(element).css('background-color')
    
    if (colorName && colorValue) {
      if (!colorPalettes[colorName]) {
        colorPalettes[colorName] = []
      }
      colorPalettes[colorName].push(colorValue)
    }
  })
  
  return colorPalettes
}

// Extract spacing scale
async function extractMantineSpacing() {
  const spacingScale = {
    xs: '0.625rem',   // 10px
    sm: '0.75rem',    // 12px  
    md: '1rem',       // 16px
    lg: '1.25rem',    // 20px
    xl: '1.5rem',     // 24px
    xxl: '2rem'       // 32px
  }
  
  return spacingScale
}

// Usage
extractMantineColors().then(colors => {
  console.log('Mantine Color Palettes:', colors)
})
```

### **Step 3: Visual Pattern Analysis**

#### **Screenshot-Based Comparison**
```typescript
// scripts/visual-comparison.ts
import { chromium } from 'playwright'

async function captureComponentScreenshots() {
  const browser = await chromium.launch()
  const page = await browser.newPage()
  
  const components = [
    { name: 'button', url: 'https://mantine.dev/core/button/' },
    { name: 'input', url: 'https://mantine.dev/core/text-input/' },
    { name: 'card', url: 'https://mantine.dev/core/card/' }
  ]
  
  for (const component of components) {
    await page.goto(component.url)
    
    // Wait for component to load
    await page.waitForSelector('.mantine-Button-root')
    
    // Capture different states
    const states = ['default', 'hover', 'focus', 'disabled']
    
    for (const state of states) {
      if (state === 'hover') {
        await page.hover('.mantine-Button-root')
      } else if (state === 'focus') {
        await page.focus('.mantine-Button-root')
      }
      
      await page.screenshot({
        path: `screenshots/mantine-${component.name}-${state}.png`,
        clip: { x: 0, y: 0, width: 200, height: 100 }
      })
    }
  }
  
  await browser.close()
}

captureComponentScreenshots()
```

#### **CSS Property Extraction**
```javascript
// Browser console script for comprehensive style extraction
function extractComponentStyles(selector) {
  const element = document.querySelector(selector)
  if (!element) return null
  
  const computedStyle = getComputedStyle(element)
  const pseudoStyles = {}
  
  // Extract pseudo-element styles
  const pseudoElements = [':before', ':after', ':hover', ':focus', ':active']
  pseudoElements.forEach(pseudo => {
    try {
      const pseudoStyle = getComputedStyle(element, pseudo)
      pseudoStyles[pseudo] = {
        content: pseudoStyle.content,
        display: pseudoStyle.display,
        position: pseudoStyle.position,
        transform: pseudoStyle.transform
      }
    } catch (e) {
      // Pseudo-element might not exist
    }
  })
  
  return {
    // Layout properties
    display: computedStyle.display,
    position: computedStyle.position,
    width: computedStyle.width,
    height: computedStyle.height,
    
    // Box model
    margin: computedStyle.margin,
    padding: computedStyle.padding,
    border: computedStyle.border,
    borderRadius: computedStyle.borderRadius,
    
    // Visual properties
    backgroundColor: computedStyle.backgroundColor,
    color: computedStyle.color,
    boxShadow: computedStyle.boxShadow,
    
    // Typography
    fontFamily: computedStyle.fontFamily,
    fontSize: computedStyle.fontSize,
    fontWeight: computedStyle.fontWeight,
    lineHeight: computedStyle.lineHeight,
    
    // Interaction
    cursor: computedStyle.cursor,
    transition: computedStyle.transition,
    transform: computedStyle.transform,
    
    // Pseudo elements
    pseudoStyles
  }
}

// Extract Mantine button styles
const mantineButtonStyles = extractComponentStyles('.mantine-Button-filled')
console.log('Mantine Button Styles:', mantineButtonStyles)

// Extract Ant Design button styles  
const antdButtonStyles = extractComponentStyles('.ant-btn-primary')
console.log('Ant Design Button Styles:', antdButtonStyles)
```

## 🎨 Pattern Translation Techniques

### **Step 4: Design Pattern Mapping**

#### **Color System Translation**
```typescript
// Design system color mapping utility
interface ColorScale {
  50: string;  100: string;  200: string;  300: string;  400: string;
  500: string; 600: string;  700: string;  800: string;  900: string;
}

function translateColorScale(
  sourceColors: string[], 
  targetFormat: 'hsl' | 'rgb' | 'hex'
): ColorScale {
  // Convert Mantine color array to standard scale
  return {
    50: sourceColors[0] || '#f8fafc',
    100: sourceColors[1] || '#f1f5f9', 
    200: sourceColors[2] || '#e2e8f0',
    300: sourceColors[3] || '#cbd5e1',
    400: sourceColors[4] || '#94a3b8',
    500: sourceColors[5] || '#64748b', // Primary shade
    600: sourceColors[6] || '#475569',
    700: sourceColors[7] || '#334155',
    800: sourceColors[8] || '#1e293b',
    900: sourceColors[9] || '#0f172a'
  }
}

// Example: Mantine blue to Tailwind format
const mantineBlue = [
  '#e7f5ff', '#d0ebff', '#a5d8ff', '#74c0fc', '#339af0',
  '#228be6', '#1c7ed6', '#1971c2', '#1864ab', '#0b5394'
]

const tailwindBlueScale = translateColorScale(mantineBlue, 'hex')
```

#### **Spacing System Translation**
```typescript
// Spacing scale conversion utility
interface SpacingSystem {
  xs: string; sm: string; md: string; 
  lg: string; xl: string; xxl?: string;
}

function normalizeSpacingSystem(
  mantineSpacing: SpacingSystem,
  antdSpacing: Record<string, string>
): Record<string, string> {
  
  // Create unified spacing scale
  return {
    // Map Mantine sizes to Tailwind equivalents
    'spacing-xs': mantineSpacing.xs,    // 10px -> 2.5
    'spacing-sm': mantineSpacing.sm,    // 12px -> 3
    'spacing-md': mantineSpacing.md,    // 16px -> 4
    'spacing-lg': mantineSpacing.lg,    // 20px -> 5
    'spacing-xl': mantineSpacing.xl,    // 24px -> 6
    
    // Add Ant Design specific spacings
    'spacing-antd-sm': antdSpacing.sm || '8px',
    'spacing-antd-md': antdSpacing.md || '16px',
    'spacing-antd-lg': antdSpacing.lg || '24px',
  }
}
```

#### **Component Variant Mapping**
```typescript
// Systematic variant translation
interface VariantMappingConfig {
  source: 'mantine' | 'antd'
  component: string
  variants: {
    [sourceVariant: string]: {
      tailwindClasses: string[]
      cssProperties?: Record<string, string>
      description: string
    }
  }
}

const buttonVariantMapping: VariantMappingConfig = {
  source: 'mantine',
  component: 'Button',
  variants: {
    'filled': {
      tailwindClasses: [
        'bg-mantine-blue-500',
        'text-white',
        'hover:bg-mantine-blue-600',
        'focus:ring-2',
        'focus:ring-mantine-blue-300',
        'transition-all',
        'duration-200'
      ],
      description: 'Solid background with hover and focus states'
    },
    'light': {
      tailwindClasses: [
        'bg-mantine-blue-50',
        'text-mantine-blue-700',
        'hover:bg-mantine-blue-100',
        'border',
        'border-mantine-blue-200'
      ],
      description: 'Light background with subtle border'
    },
    'outline': {
      tailwindClasses: [
        'border-2',
        'border-mantine-blue-500',
        'text-mantine-blue-500',
        'bg-transparent',
        'hover:bg-mantine-blue-500',
        'hover:text-white'
      ],
      description: 'Outlined button with fill on hover'
    },
    'subtle': {
      tailwindClasses: [
        'text-mantine-blue-600',
        'bg-transparent',
        'hover:bg-mantine-blue-50',
        'focus:bg-mantine-blue-50'
      ],
      description: 'Text-only button with subtle hover'
    }
  }
}
```

### **Step 5: Animation Pattern Extraction**

#### **Micro-interaction Analysis**
```css
/* Extracted Mantine button hover animation */
.mantine-button-enhance {
  /* Base state */
  transform: translateZ(0); /* Force GPU layer */
  transition: 
    background-color 150ms ease,
    border-color 150ms ease,
    transform 150ms ease,
    box-shadow 150ms ease;
}

.mantine-button-enhance:hover {
  /* Subtle lift effect */
  transform: translateZ(0) translateY(-1px);
  box-shadow: 
    0 4px 8px rgba(0, 0, 0, 0.12),
    0 2px 4px rgba(0, 0, 0, 0.08);
}

.mantine-button-enhance:active {
  /* Press down effect */
  transform: translateZ(0) translateY(0);
  box-shadow: 
    0 2px 4px rgba(0, 0, 0, 0.12),
    0 1px 2px rgba(0, 0, 0, 0.08);
}

/* Focus state with ring */
.mantine-button-enhance:focus-visible {
  outline: none;
  box-shadow: 
    0 0 0 2px var(--mantine-blue-300),
    0 4px 8px rgba(0, 0, 0, 0.12);
}
```

#### **Loading State Animations**
```css
/* Mantine-inspired loading animation */
@keyframes mantine-loading-pulse {
  0%, 100% {
    opacity: 1;
  }
  50% {
    opacity: 0.5;
  }
}

.mantine-button-loading {
  position: relative;
  color: transparent;
  pointer-events: none;
}

.mantine-button-loading::after {
  content: '';
  position: absolute;
  top: 50%;
  left: 50%;
  width: 16px;
  height: 16px;
  margin: -8px 0 0 -8px;
  border: 2px solid currentColor;
  border-radius: 50%;
  border-top-color: transparent;
  animation: spin 0.8s linear infinite;
}

@keyframes spin {
  to {
    transform: rotate(360deg);
  }
}
```

## 🛠️ Automated Extraction Tools

### **Step 6: Building Extraction Scripts**

#### **Node.js Design Token Extractor**
```typescript
// tools/design-token-extractor.ts
import puppeteer from 'puppeteer'
import fs from 'fs'
import path from 'path'

interface ExtractedTokens {
  colors: Record<string, Record<string, string>>
  spacing: Record<string, string>
  typography: Record<string, Record<string, string>>
  shadows: Record<string, string>
  borderRadius: Record<string, string>
}

class DesignTokenExtractor {
  private browser: puppeteer.Browser | null = null
  
  async init() {
    this.browser = await puppeteer.launch({ headless: false })
  }
  
  async extractFromMantine(): Promise<ExtractedTokens> {
    if (!this.browser) throw new Error('Browser not initialized')
    
    const page = await this.browser.newPage()
    await page.goto('https://mantine.dev/theming/default-theme/')
    
    // Execute extraction script in browser context
    const tokens = await page.evaluate(() => {
      const extractedTokens: ExtractedTokens = {
        colors: {},
        spacing: {},
        typography: {},
        shadows: {},
        borderRadius: {}
      }
      
      // Extract color swatches
      document.querySelectorAll('[data-testid="color-swatch"]').forEach(swatch => {
        const colorName = swatch.getAttribute('data-color-name')
        const colorValue = swatch.getAttribute('data-color-value')
        const shadeIndex = swatch.getAttribute('data-shade')
        
        if (colorName && colorValue && shadeIndex) {
          if (!extractedTokens.colors[colorName]) {
            extractedTokens.colors[colorName] = {}
          }
          extractedTokens.colors[colorName][shadeIndex] = colorValue
        }
      })
      
      // Extract spacing tokens
      document.querySelectorAll('[data-testid="spacing-demo"]').forEach(demo => {
        const size = demo.getAttribute('data-size')
        const value = getComputedStyle(demo).getPropertyValue('--spacing-' + size)
        if (size && value) {
          extractedTokens.spacing[size] = value.trim()
        }
      })
      
      return extractedTokens
    })
    
    return tokens
  }
  
  async extractFromAntDesign(): Promise<ExtractedTokens> {
    if (!this.browser) throw new Error('Browser not initialized')
    
    const page = await this.browser.newPage()
    await page.goto('https://ant.design/components/button')
    
    const tokens = await page.evaluate(() => {
      const extractedTokens: ExtractedTokens = {
        colors: {},
        spacing: {},
        typography: {},
        shadows: {},
        borderRadius: {}
      }
      
      // Extract button variants and their styles
      const buttons = document.querySelectorAll('.ant-btn')
      buttons.forEach(button => {
        const variant = button.className.match(/ant-btn-(\w+)/)?.[1] || 'default'
        const computedStyle = getComputedStyle(button)
        
        extractedTokens.colors[variant] = {
          background: computedStyle.backgroundColor,
          color: computedStyle.color,
          border: computedStyle.borderColor
        }
      })
      
      return extractedTokens
    })
    
    return tokens
  }
  
  async generateTailwindConfig(
    mantineTokens: ExtractedTokens,
    antdTokens: ExtractedTokens
  ) {
    const tailwindConfig = {
      theme: {
        extend: {
          colors: {
            mantine: mantineTokens.colors,
            antd: antdTokens.colors
          },
          spacing: {
            ...Object.entries(mantineTokens.spacing).reduce((acc, [key, value]) => {
              acc[`mantine-${key}`] = value
              return acc
            }, {} as Record<string, string>)
          },
          boxShadow: {
            'mantine-xs': '0 1px 3px rgba(0, 0, 0, 0.05)',
            'mantine-sm': '0 1px 3px rgba(0, 0, 0, 0.05), 0 1px 2px rgba(0, 0, 0, 0.1)',
            'antd': '0 2px 8px rgba(0, 0, 0, 0.15)'
          }
        }
      }
    }
    
    // Write to file
    fs.writeFileSync(
      path.join(process.cwd(), 'tailwind.extracted.config.js'),
      `module.exports = ${JSON.stringify(tailwindConfig, null, 2)}`
    )
  }
  
  async close() {
    if (this.browser) {
      await this.browser.close()
    }
  }
}

// Usage
async function main() {
  const extractor = new DesignTokenExtractor()
  await extractor.init()
  
  const mantineTokens = await extractor.extractFromMantine()
  const antdTokens = await extractor.extractFromAntDesign()
  
  await extractor.generateTailwindConfig(mantineTokens, antdTokens)
  await extractor.close()
  
  console.log('Design tokens extracted successfully!')
}

main().catch(console.error)
```

#### **CSS Variable Generator**
```typescript
// tools/css-variable-generator.ts
interface DesignTokens {
  colors: Record<string, Record<string, string>>
  spacing: Record<string, string>
  typography: Record<string, any>
}

function generateCSSVariables(tokens: DesignTokens): string {
  let css = ':root {\n'
  
  // Generate color variables
  Object.entries(tokens.colors).forEach(([colorName, shades]) => {
    Object.entries(shades).forEach(([shade, value]) => {
      css += `  --${colorName}-${shade}: ${value};\n`
    })
  })
  
  // Generate spacing variables
  Object.entries(tokens.spacing).forEach(([size, value]) => {
    css += `  --spacing-${size}: ${value};\n`
  })
  
  css += '}\n'
  
  return css
}

// Generate theme-specific CSS
function generateThemeCSS(mantineTokens: DesignTokens, antdTokens: DesignTokens) {
  const baseCSS = generateCSSVariables(mantineTokens)
  
  const themeCSS = `
/* Base design tokens from Mantine */
${baseCSS}

/* Ant Design overrides */
[data-theme="antd"] {
${generateCSSVariables(antdTokens).replace(':root {', '').replace('}', '')}
}

/* Component-specific enhancements */
.mantine-button-enhance {
  --button-bg: var(--blue-5);
  --button-hover-bg: var(--blue-6);
  --button-focus-ring: var(--blue-3);
}

.antd-button-enhance {
  --button-bg: var(--blue-500);
  --button-hover-bg: var(--blue-600);
  --button-shadow: 0 2px 8px rgba(0, 0, 0, 0.15);
}
`
  
  return themeCSS
}
```

## 📊 Quality Validation

### **Step 7: Validation & Testing**

#### **Visual Regression Testing**
```typescript
// tests/visual-regression.spec.ts
import { test, expect } from '@playwright/test'

test.describe('Styled Component Visual Regression', () => {
  const components = ['button', 'input', 'card']
  const variants = ['mantine', 'antd', 'default']
  const states = ['default', 'hover', 'focus', 'disabled']
  
  components.forEach(component => {
    variants.forEach(variant => {
      states.forEach(state => {
        test(`${component}-${variant}-${state}`, async ({ page }) => {
          await page.goto(`/storybook/?path=/story/${component}--${variant}`)
          
          const selector = `[data-testid="${component}-${variant}"]`
          
          if (state === 'hover') {
            await page.hover(selector)
          } else if (state === 'focus') {
            await page.focus(selector)
          }
          
          await expect(page.locator(selector)).toHaveScreenshot(
            `${component}-${variant}-${state}.png`
          )
        })
      })
    })
  })
})
```

#### **Design Token Validation**
```typescript
// tests/design-token-validation.test.ts
import { validateDesignTokens } from '../tools/token-validator'

describe('Design Token Validation', () => {
  test('Mantine color tokens have correct contrast ratios', () => {
    const mantineColors = {
      blue: ['#e7f5ff', '#d0ebff', /* ... */]
    }
    
    const results = validateDesignTokens(mantineColors)
    
    expect(results.contrastRatios.every(ratio => ratio >= 4.5)).toBe(true)
    expect(results.accessibilityCompliant).toBe(true)
  })
  
  test('Spacing tokens follow consistent scale', () => {
    const spacingTokens = {
      xs: '0.625rem',
      sm: '0.75rem', 
      md: '1rem',
      lg: '1.25rem',
      xl: '1.5rem'
    }
    
    const results = validateSpacingScale(spacingTokens)
    
    expect(results.isConsistent).toBe(true)
    expect(results.scaleRatio).toBeCloseTo(1.25, 1) // ~25% increase per step
  })
})
```

---

## 🔗 Navigation

**Previous**: [Comparison Analysis](./comparison-analysis.md)  
**Next**: [Component Customization Strategies](./component-customization-strategies.md)

---

*Last updated: [Current Date] | Extraction methodology version: 1.0*