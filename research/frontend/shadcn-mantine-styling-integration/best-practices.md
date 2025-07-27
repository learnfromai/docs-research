# Best Practices: shadcn/ui with Mantine & Ant Design Styling Integration

## 🎯 Overview

This document outlines proven best practices for successfully integrating **Mantine** and **Ant Design** styling approaches with **shadcn/ui** while maintaining code quality, performance, and long-term maintainability.

## 🏗️ Architecture & Organization

### **1. Component Structure Best Practices**

#### **Maintain Single Source of Truth**
```typescript
// ✅ GOOD: Centralized variant definitions
const buttonVariants = cva(
  "base-styles",
  {
    variants: {
      variant: {
        default: "shadcn-default-styles",
        "mantine-filled": "mantine-specific-styles", 
        "antd-primary": "antd-specific-styles"
      }
    }
  }
)

// ❌ AVOID: Scattered styling across multiple files
const mantineButtonStyles = "scattered-styles"
const antdButtonStyles = "different-file-styles"
```

#### **Use Semantic Naming Conventions**
```typescript
// ✅ GOOD: Clear, descriptive variant names
variant: "mantine-filled" | "mantine-light" | "mantine-outline"
size: "mantine-xs" | "mantine-sm" | "mantine-md"

// ❌ AVOID: Generic or confusing names  
variant: "blue" | "big" | "style1" | "type2"
```

#### **Component Composition Patterns**
```typescript
// ✅ GOOD: Extensible component design
interface ButtonProps extends VariantProps<typeof buttonVariants> {
  loading?: boolean
  leftIcon?: React.ReactNode
  rightIcon?: React.ReactNode
  // Allow for future extensions
  [key: string]: any
}

// ✅ GOOD: Compound component pattern for complex components
const Card = {
  Root: CardRoot,
  Header: CardHeader, 
  Body: CardBody,
  Footer: CardFooter
}
```

### **2. Design Token Management**

#### **CSS Custom Properties Strategy**
```css
/* ✅ GOOD: Hierarchical token organization */
:root {
  /* Base design tokens */
  --ds-color-primary: #228be6;
  --ds-color-secondary: #495057;
  
  /* Component-specific tokens */
  --ds-button-height-sm: 32px;
  --ds-button-height-md: 36px;
  --ds-button-height-lg: 44px;
  
  /* Semantic tokens */
  --ds-color-success: #52c41a;
  --ds-color-error: #ff4d4f;
  --ds-color-warning: #faad14;
}

/* ❌ AVOID: Flat token structure without hierarchy */
:root {
  --blue: #228be6;
  --red: #ff4d4f;
  --buttonheight: 36px;
  --bordercolor: #dee2e6;
}
```

#### **Tailwind Configuration Best Practices**
```javascript
// ✅ GOOD: Organized theme extension
module.exports = {
  theme: {
    extend: {
      colors: {
        // Namespace colors by source
        mantine: {
          blue: { /* scale */ },
          gray: { /* scale */ }
        },
        antd: {
          primary: '#1890ff',
          success: '#52c41a'
        },
        // Keep semantic naming
        brand: {
          primary: 'var(--brand-primary)',
          secondary: 'var(--brand-secondary)'
        }
      }
    }
  }
}

// ❌ AVOID: Direct color values without organization
module.exports = {
  theme: {
    extend: {
      colors: {
        blue500: '#228be6',
        blue600: '#1c7ed6',
        antdblue: '#1890ff'
      }
    }
  }
}
```

## 🎨 Styling Guidelines

### **3. CSS Architecture Patterns**

#### **Layer-Based Styling Approach**
```css
/* ✅ GOOD: Organized CSS layers */
@layer base {
  /* Base styles and resets */
  * { @apply border-border; }
  body { @apply bg-background text-foreground; }
}

@layer components {
  /* Reusable component styles */
  .mantine-button-enhance {
    @apply transition-all duration-200 ease-in-out;
    @apply hover:transform hover:scale-[1.02];
  }
  
  .antd-shadow {
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.15);
  }
}

@layer utilities {
  /* Custom utility classes */
  .text-mantine-blue { @apply text-mantine-blue-500; }
}
```

#### **Consistent Animation Patterns**
```typescript
// ✅ GOOD: Standardized animation durations and easings
const ANIMATION_CONFIG = {
  duration: {
    fast: '150ms',
    normal: '200ms', 
    slow: '300ms'
  },
  easing: {
    default: 'ease-in-out',
    enter: 'ease-out',
    exit: 'ease-in'
  }
} as const

// Usage in components
className="transition-all duration-200 ease-in-out"

// ❌ AVOID: Inconsistent animation values
className="transition-all duration-150 ease-out" // Different duration
className="transition-all duration-300 ease-in"  // Different easing
```

### **4. Responsive Design Patterns**

#### **Mobile-First Approach**
```typescript
// ✅ GOOD: Mobile-first responsive variants
const buttonVariants = cva(
  "px-3 py-2 text-sm", // Mobile default
  {
    variants: {
      size: {
        default: "px-3 py-2 md:px-4 md:py-2 md:text-base",
        lg: "px-4 py-3 md:px-6 md:py-3 md:text-lg"
      }
    }
  }
)

// ❌ AVOID: Desktop-first approach
const buttonVariants = cva(
  "px-6 py-3 text-lg max-md:px-3 max-md:py-2 max-md:text-sm"
)
```

#### **Consistent Breakpoint Usage**
```javascript
// ✅ GOOD: Standardized breakpoints in Tailwind config
module.exports = {
  theme: {
    screens: {
      sm: '640px',
      md: '768px', 
      lg: '1024px',
      xl: '1280px',
      '2xl': '1536px'
    }
  }
}
```

## 🔧 Development Workflow

### **5. Component Development Process**

#### **Iterative Enhancement Strategy**
```markdown
1. **Start with shadcn/ui base** - Use existing component as foundation
2. **Add design tokens** - Extend Tailwind config with target system tokens
3. **Create variants** - Add new styling variants while preserving originals
4. **Test thoroughly** - Validate across different states and viewports
5. **Document usage** - Provide clear examples and guidelines
6. **Iterate based on feedback** - Refine based on team usage patterns
```

#### **Code Review Checklist**
```markdown
- [ ] Component maintains accessibility standards (ARIA attributes, keyboard navigation)
- [ ] All variants are properly typed with TypeScript
- [ ] CSS custom properties are used for dynamic values
- [ ] Component is responsive across all defined breakpoints
- [ ] Animation performance is optimized (transform, opacity only)
- [ ] Bundle size impact is measured and documented
- [ ] Storybook stories cover all major use cases
- [ ] Unit tests validate component behavior
- [ ] Documentation includes practical examples
```

### **6. Testing Strategies**

#### **Visual Regression Testing**
```typescript
// ✅ GOOD: Comprehensive visual testing setup
// tests/visual.spec.ts
import { test, expect } from '@playwright/test'

test.describe('Button Variants', () => {
  test('should render all Mantine variants correctly', async ({ page }) => {
    await page.goto('/storybook/?path=/story/button--all-variants')
    
    // Test different states
    await expect(page.locator('[data-testid="mantine-filled"]')).toHaveScreenshot()
    await expect(page.locator('[data-testid="mantine-outline"]')).toHaveScreenshot()
    
    // Test hover states
    await page.hover('[data-testid="mantine-filled"]')
    await expect(page.locator('[data-testid="mantine-filled"]')).toHaveScreenshot()
  })
})
```

#### **Accessibility Testing**
```typescript
// ✅ GOOD: Automated accessibility validation
import { axe, toHaveNoViolations } from 'jest-axe'

expect.extend(toHaveNoViolations)

test('Button component meets accessibility standards', async () => {
  const { container } = render(
    <Button variant="mantine-filled">Accessible Button</Button>
  )
  
  const results = await axe(container)
  expect(results).toHaveNoViolations()
})
```

#### **Performance Testing**
```typescript
// ✅ GOOD: Bundle size monitoring
// scripts/bundle-monitor.js
const { execSync } = require('child_process')

function monitorBundleSize() {
  const baselinePath = './baseline-bundle-size.json'
  const currentSize = getBundleSize()
  const baseline = JSON.parse(fs.readFileSync(baselinePath, 'utf8'))
  
  const increase = ((currentSize - baseline.size) / baseline.size) * 100
  
  if (increase > 10) { // 10% increase threshold
    throw new Error(`Bundle size increased by ${increase.toFixed(2)}%`)
  }
  
  console.log(`✅ Bundle size within acceptable range: ${increase.toFixed(2)}% change`)
}
```

## 📊 Performance Optimization

### **7. Bundle Size Management**

#### **Tree Shaking Optimization**
```typescript
// ✅ GOOD: Selective imports and tree-shaking friendly exports
// components/ui/index.ts
export { Button } from './button-enhanced'
export { Input } from './input-enhanced'
export type { ButtonProps, InputProps } from './types'

// Usage
import { Button } from '@/components/ui'

// ❌ AVOID: Barrel exports that prevent tree shaking
export * from './button-enhanced'
export * from './input-enhanced'
export * from './all-other-components'
```

#### **Dynamic Imports for Large Components**
```typescript
// ✅ GOOD: Code splitting for heavy components
const DataTable = lazy(() => import('./data-table-enhanced'))
const RichTextEditor = lazy(() => import('./rich-text-editor'))

function MyApp() {
  return (
    <Suspense fallback={<ComponentSkeleton />}>
      <DataTable />
    </Suspense>
  )
}

// ❌ AVOID: Importing large components statically
import { DataTable } from './data-table-enhanced'
import { RichTextEditor } from './rich-text-editor'
```

### **8. Runtime Performance**

#### **Optimized Animation Patterns**
```css
/* ✅ GOOD: GPU-accelerated animations */
.mantine-button-enhance {
  transform: translateZ(0); /* Force GPU layer */
  transition: transform 200ms ease-in-out;
}

.mantine-button-enhance:hover {
  transform: translateZ(0) scale(1.02);
}

/* ❌ AVOID: Layout-triggering animations */
.button-bad-animation {
  transition: width 200ms, height 200ms, padding 200ms;
}
```

#### **Efficient CSS Variable Usage**
```typescript
// ✅ GOOD: Minimal CSS variable updates
const updateTheme = useCallback((theme: DesignSystemTheme) => {
  const root = document.documentElement
  const config = designSystemConfigs[theme]
  
  // Batch DOM updates
  requestAnimationFrame(() => {
    Object.entries(config.tokens).forEach(([key, value]) => {
      root.style.setProperty(`--${key}`, value)
    })
  })
}, [])

// ❌ AVOID: Multiple synchronous DOM updates
const updateTheme = (theme: DesignSystemTheme) => {
  Object.entries(config.tokens).forEach(([key, value]) => {
    document.documentElement.style.setProperty(`--${key}`, value) // Each call triggers reflow
  })
}
```

## 🔒 Maintenance & Scalability

### **9. Version Management**

#### **Semantic Component Versioning**
```json
// package.json
{
  "name": "@company/design-system",
  "version": "1.2.0",
  "peerDependencies": {
    "react": ">=18.0.0",
    "tailwindcss": ">=3.3.0"
  }
}
```

#### **Migration Guides**
```markdown
# Migration Guide: v1.1 to v1.2

## Breaking Changes
- `Button` prop `variant="primary"` renamed to `variant="mantine-filled"`
- Removed deprecated `size="large"` (use `size="mantine-lg"`)

## Migration Steps
1. Replace variant names:
   ```diff
   - <Button variant="primary">
   + <Button variant="mantine-filled">
   ```

2. Update size properties:
   ```diff
   - <Button size="large">
   + <Button size="mantine-lg">
   ```

## Automated Migration
Run: `npx @company/design-system-migrate v1.1-to-v1.2`
```

### **10. Documentation Standards**

#### **Comprehensive Component Documentation**
```markdown
# Button Component

## API Reference

### Props
| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `variant` | `ButtonVariant` | `"default"` | Visual style variant |
| `size` | `ButtonSize` | `"default"` | Button size |
| `loading` | `boolean` | `false` | Shows loading spinner |
| `leftIcon` | `ReactNode` | - | Icon before text |
| `rightIcon` | `ReactNode` | - | Icon after text |

### Variants
- `default` - Standard shadcn/ui styling
- `mantine-filled` - Mantine's filled button style
- `mantine-outline` - Mantine's outline button style
- `antd-primary` - Ant Design primary button style

### Examples
[Include practical code examples for each variant]

### Accessibility
- Supports keyboard navigation
- Screen reader compatible
- High contrast mode compatible
- WCAG 2.1 AA compliant
```

#### **Design Token Documentation**
```markdown
# Design Tokens

## Color Palette

### Mantine Blue Scale
- `mantine-blue-50`: #e7f5ff (Lightest)
- `mantine-blue-500`: #228be6 (Primary)
- `mantine-blue-900`: #0b5394 (Darkest)

### Usage Guidelines
- Use `mantine-blue-500` for primary actions
- Use `mantine-blue-50` for subtle backgrounds
- Maintain 4.5:1 contrast ratio for text
```

## 🚀 Deployment & Distribution

### **11. Build Pipeline Best Practices**

#### **Automated Quality Gates**
```yaml
# .github/workflows/quality-check.yml
name: Quality Check
on: [push, pull_request]

jobs:
  quality:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Install dependencies
        run: npm ci
      
      - name: Type checking
        run: npm run type-check
        
      - name: Linting
        run: npm run lint
        
      - name: Unit tests
        run: npm run test
        
      - name: Visual regression tests
        run: npm run test:visual
        
      - name: Bundle size check
        run: npm run bundle:analyze
        
      - name: Accessibility audit
        run: npm run a11y:test
```

#### **Release Automation**
```json
// package.json
{
  "scripts": {
    "release": "semantic-release",
    "release:preview": "semantic-release --dry-run"
  },
  "release": {
    "branches": ["main"],
    "plugins": [
      "@semantic-release/commit-analyzer",
      "@semantic-release/release-notes-generator",
      "@semantic-release/changelog",
      "@semantic-release/npm",
      "@semantic-release/github"
    ]
  }
}
```

## ⚠️ Common Pitfalls & Solutions

### **12. Avoiding Anti-Patterns**

#### **CSS Specificity Issues**
```css
/* ❌ AVOID: High specificity that's hard to override */
.mantine-button.filled.large.primary {
  background: blue !important;
}

/* ✅ GOOD: Use CSS layers and moderate specificity */
@layer components {
  .mantine-button-filled {
    @apply bg-mantine-blue-500 hover:bg-mantine-blue-600;
  }
}
```

#### **Theme Inconsistencies**
```typescript
// ❌ AVOID: Hardcoded values that break theming
const buttonStyle = {
  backgroundColor: '#228be6', // Fixed color
  padding: '8px 16px'        // Fixed spacing
}

// ✅ GOOD: Theme-aware styling
const buttonStyle = {
  backgroundColor: 'var(--mantine-primary-color)',
  padding: 'var(--mantine-spacing-sm) var(--mantine-spacing-md)'
}
```

#### **Performance Anti-Patterns**
```typescript
// ❌ AVOID: Expensive operations in render
function Button({ variant }: ButtonProps) {
  const theme = calculateThemeFromVariant(variant) // Expensive calculation
  const styles = generateDynamicStyles(theme)      // Creates new object each render
  
  return <button style={styles}>Button</button>
}

// ✅ GOOD: Memoized calculations and static styles
const Button = memo(({ variant }: ButtonProps) => {
  const styles = useMemo(
    () => getPrecomputedStyles(variant),
    [variant]
  )
  
  return <button className={styles}>Button</button>
})
```

## 📈 Success Metrics & Monitoring

### **13. Key Performance Indicators**

#### **Technical Metrics**
- **Bundle Size Impact**: < 15% increase from baseline
- **Lighthouse Performance Score**: > 90
- **First Contentful Paint**: < 1.5s
- **Cumulative Layout Shift**: < 0.1
- **Time to Interactive**: < 3s

#### **Developer Experience Metrics**
- **Component Adoption Rate**: Track usage across projects
- **Development Velocity**: Feature delivery speed
- **Bug Reports**: UI-related issues over time
- **Documentation Usage**: Most accessed guides

#### **Monitoring Implementation**
```typescript
// Performance monitoring
import { getCLS, getFID, getFCP, getLCP, getTTFB } from 'web-vitals'

function sendToAnalytics(metric: Metric) {
  // Send to your analytics service
  analytics.track('Performance Metric', {
    name: metric.name,
    value: metric.value,
    component: 'design-system'
  })
}

getCLS(sendToAnalytics)
getFID(sendToAnalytics)
getFCP(sendToAnalytics)
getLCP(sendToAnalytics)
getTTFB(sendToAnalytics)
```

---

## 🔗 Navigation

**Previous**: [Implementation Guide](./implementation-guide.md)  
**Next**: [Comparison Analysis](./comparison-analysis.md)

---

*Last updated: [Current Date] | Best practices version: 1.0*