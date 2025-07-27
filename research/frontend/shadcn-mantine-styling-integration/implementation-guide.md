# Implementation Guide: shadcn/ui with Mantine & Ant Design Styling

## 🎯 Overview

This comprehensive guide provides step-by-step instructions for integrating **Mantine** and **Ant Design** styling approaches into **shadcn/ui** components while maintaining the flexibility and copy-paste simplicity that makes shadcn/ui attractive.

## 🛠️ Prerequisites

### **Required Knowledge**
- React and TypeScript fundamentals
- Tailwind CSS configuration and utilities
- Basic understanding of CSS custom properties
- Familiarity with shadcn/ui component structure

### **Development Environment**
```bash
# Required dependencies
npm install @radix-ui/react-* # Core primitives
npm install tailwindcss @tailwindcss/forms @tailwindcss/typography
npm install class-variance-authority clsx tailwind-merge
npm install lucide-react # Icons

# Development tools (recommended)
npm install --save-dev storybook @storybook/react-vite
npm install --save-dev @types/node
```

## 📋 Phase 1: Design Token Extraction & Setup

### **Step 1: Analyze Target Design Systems**

#### **Mantine Color System Analysis**
```javascript
// Extract Mantine's color palette
const mantineColors = {
  blue: [
    '#e7f5ff', // 0
    '#d0ebff', // 1
    '#a5d8ff', // 2
    '#74c0fc', // 3
    '#339af0', // 4
    '#228be6', // 5 - Primary
    '#1c7ed6', // 6
    '#1971c2', // 7
    '#1864ab', // 8
    '#0b5394'  // 9
  ],
  gray: [
    '#f8f9fa', // 0
    '#f1f3f4', // 1
    '#e9ecef', // 2
    '#dee2e6', // 3
    '#ced4da', // 4
    '#adb5bd', // 5
    '#6c757d', // 6
    '#495057', // 7
    '#343a40', // 8
    '#212529'  // 9
  ]
};

// Extract spacing system
const mantineSpacing = {
  xs: '0.625rem',  // 10px
  sm: '0.75rem',   // 12px
  md: '1rem',      // 16px
  lg: '1.25rem',   // 20px
  xl: '1.5rem',    // 24px
};
```

#### **Ant Design Token Analysis**
```javascript
// Ant Design's design tokens
const antdTokens = {
  colorPrimary: '#1890ff',
  colorSuccess: '#52c41a',
  colorWarning: '#faad14',
  colorError: '#ff4d4f',
  colorInfo: '#1890ff',
  borderRadius: '6px',
  controlHeight: '32px',
  fontSize: '14px',
  fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto',
};
```

### **Step 2: Configure Tailwind CSS Extensions**

Create or update your `tailwind.config.js`:

```javascript
/** @type {import('tailwindcss').Config} */
module.exports = {
  darkMode: ["class"],
  content: [
    './pages/**/*.{ts,tsx}',
    './components/**/*.{ts,tsx}',
    './app/**/*.{ts,tsx}',
    './src/**/*.{ts,tsx}',
  ],
  theme: {
    container: {
      center: true,
      padding: "2rem",
      screens: {
        "2xl": "1400px",
      },
    },
    extend: {
      colors: {
        // Mantine-inspired color palette
        mantine: {
          blue: {
            50: '#e7f5ff',
            100: '#d0ebff', 
            200: '#a5d8ff',
            300: '#74c0fc',
            400: '#339af0',
            500: '#228be6', // Primary
            600: '#1c7ed6',
            700: '#1971c2',
            800: '#1864ab',
            900: '#0b5394',
          },
          gray: {
            50: '#f8f9fa',
            100: '#f1f3f4',
            200: '#e9ecef',
            300: '#dee2e6',
            400: '#ced4da',
            500: '#adb5bd',
            600: '#6c757d',
            700: '#495057',
            800: '#343a40',
            900: '#212529',
          }
        },
        // Ant Design color scheme
        antd: {
          primary: '#1890ff',
          success: '#52c41a',
          warning: '#faad14',
          error: '#ff4d4f',
          info: '#1890ff',
        },
        // Unified design system
        border: "hsl(var(--border))",
        input: "hsl(var(--input))",
        ring: "hsl(var(--ring))",
        background: "hsl(var(--background))",
        foreground: "hsl(var(--foreground))",
        primary: {
          DEFAULT: "hsl(var(--primary))",
          foreground: "hsl(var(--primary-foreground))",
        },
        secondary: {
          DEFAULT: "hsl(var(--secondary))",
          foreground: "hsl(var(--secondary-foreground))",
        },
        destructive: {
          DEFAULT: "hsl(var(--destructive))",
          foreground: "hsl(var(--destructive-foreground))",
        },
        muted: {
          DEFAULT: "hsl(var(--muted))",
          foreground: "hsl(var(--muted-foreground))",
        },
        accent: {
          DEFAULT: "hsl(var(--accent))",
          foreground: "hsl(var(--accent-foreground))",
        },
        popover: {
          DEFAULT: "hsl(var(--popover))",
          foreground: "hsl(var(--popover-foreground))",
        },
        card: {
          DEFAULT: "hsl(var(--card))",
          foreground: "hsl(var(--card-foreground))",
        },
      },
      spacing: {
        // Mantine spacing scale
        'mantine-xs': '0.625rem',
        'mantine-sm': '0.75rem', 
        'mantine-md': '1rem',
        'mantine-lg': '1.25rem',
        'mantine-xl': '1.5rem',
      },
      borderRadius: {
        lg: "var(--radius)",
        md: "calc(var(--radius) - 2px)",
        sm: "calc(var(--radius) - 4px)",
        // Mantine border radius
        'mantine-xs': '2px',
        'mantine-sm': '4px',
        'mantine-md': '8px',
        'mantine-lg': '16px',
        'mantine-xl': '32px',
      },
      fontFamily: {
        sans: ['Inter', 'ui-sans-serif', 'system-ui'],
        'mantine': ['-apple-system', 'BlinkMacSystemFont', 'Segoe UI', 'Roboto'],
        'antd': ['-apple-system', 'BlinkMacSystemFont', 'Segoe UI', 'Roboto'],
      },
      fontSize: {
        'antd-sm': ['12px', '20px'],
        'antd-base': ['14px', '22px'],
        'antd-lg': ['16px', '24px'],
      },
      boxShadow: {
        'mantine-xs': '0 1px 3px rgba(0, 0, 0, 0.05), 0 1px 2px rgba(0, 0, 0, 0.1)',
        'mantine-sm': '0 1px 3px rgba(0, 0, 0, 0.05), 0 1px 2px rgba(0, 0, 0, 0.1)',
        'mantine-md': '0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06)',
        'mantine-lg': '0 10px 15px -3px rgba(0, 0, 0, 0.1), 0 4px 6px -2px rgba(0, 0, 0, 0.05)',
        'antd': '0 2px 8px rgba(0, 0, 0, 0.15)',
      },
      keyframes: {
        "accordion-down": {
          from: { height: 0 },
          to: { height: "var(--radix-accordion-content-height)" },
        },
        "accordion-up": {
          from: { height: "var(--radix-accordion-content-height)" },
          to: { height: 0 },
        },
        // Mantine-inspired animations
        "mantine-fade-in": {
          from: { opacity: 0 },
          to: { opacity: 1 },
        },
        "mantine-scale-in": {
          from: { opacity: 0, transform: "scale(0.95)" },
          to: { opacity: 1, transform: "scale(1)" },
        },
      },
      animation: {
        "accordion-down": "accordion-down 0.2s ease-out",
        "accordion-up": "accordion-up 0.2s ease-out",
        "mantine-fade-in": "mantine-fade-in 0.2s ease-out",
        "mantine-scale-in": "mantine-scale-in 0.2s ease-out",
      },
    },
  },
  plugins: [require("tailwindcss-animate")],
}
```

### **Step 3: CSS Custom Properties Setup**

Create `globals.css` with enhanced design tokens:

```css
@tailwind base;
@tailwind components;
@tailwind utilities;

@layer base {
  :root {
    /* shadcn/ui base variables */
    --background: 0 0% 100%;
    --foreground: 222.2 84% 4.9%;
    --card: 0 0% 100%;
    --card-foreground: 222.2 84% 4.9%;
    --popover: 0 0% 100%;
    --popover-foreground: 222.2 84% 4.9%;
    --primary: 221.2 83.2% 53.3%;
    --primary-foreground: 210 40% 98%;
    --secondary: 210 40% 96%;
    --secondary-foreground: 222.2 84% 4.9%;
    --muted: 210 40% 96%;
    --muted-foreground: 215.4 16.3% 46.9%;
    --accent: 210 40% 96%;
    --accent-foreground: 222.2 84% 4.9%;
    --destructive: 0 84.2% 60.2%;
    --destructive-foreground: 210 40% 98%;
    --border: 214.3 31.8% 91.4%;
    --input: 214.3 31.8% 91.4%;
    --ring: 221.2 83.2% 53.3%;
    --radius: 0.5rem;

    /* Mantine-inspired variables */
    --mantine-primary-color: 221.2 83.2% 53.3%;
    --mantine-gray-0: 0 0% 97%;
    --mantine-gray-1: 0 0% 95%;
    --mantine-gray-2: 0 0% 91%;
    --mantine-gray-3: 0 0% 87%;
    --mantine-gray-4: 0 0% 81%;
    --mantine-gray-5: 0 0% 68%;
    --mantine-gray-6: 0 0% 42%;
    --mantine-gray-7: 0 0% 29%;
    --mantine-gray-8: 0 0% 21%;
    --mantine-gray-9: 0 0% 13%;

    /* Ant Design variables */
    --antd-primary: 204 100% 56%;
    --antd-success: 98 69% 44%;
    --antd-warning: 38 100% 52%;
    --antd-error: 5 100% 65%;
  }

  .dark {
    --background: 222.2 84% 4.9%;
    --foreground: 210 40% 98%;
    --card: 222.2 84% 4.9%;
    --card-foreground: 210 40% 98%;
    --popover: 222.2 84% 4.9%;
    --popover-foreground: 210 40% 98%;
    --primary: 217.2 91.2% 59.8%;
    --primary-foreground: 222.2 84% 4.9%;
    --secondary: 217.2 32.6% 17.5%;
    --secondary-foreground: 210 40% 98%;
    --muted: 217.2 32.6% 17.5%;
    --muted-foreground: 215 20.2% 65.1%;
    --accent: 217.2 32.6% 17.5%;
    --accent-foreground: 210 40% 98%;
    --destructive: 0 62.8% 30.6%;
    --destructive-foreground: 210 40% 98%;
    --border: 217.2 32.6% 17.5%;
    --input: 217.2 32.6% 17.5%;
    --ring: 224.3 76.3% 94.1%;
  }
}

@layer base {
  * {
    @apply border-border;
  }
  body {
    @apply bg-background text-foreground;
  }
}

/* Mantine-inspired component styles */
@layer components {
  .mantine-button-enhance {
    @apply transition-all duration-200 ease-in-out;
    @apply hover:transform hover:scale-[1.02];
    @apply active:transform active:scale-[0.98];
    @apply focus:ring-2 focus:ring-mantine-blue-300 focus:ring-offset-2;
  }

  .mantine-input-enhance {
    @apply transition-all duration-200;
    @apply focus:border-mantine-blue-500 focus:ring-1 focus:ring-mantine-blue-500;
    @apply hover:border-mantine-gray-400;
  }

  .antd-shadow {
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.15);
  }

  .mantine-card {
    @apply bg-white dark:bg-gray-800 rounded-mantine-md shadow-mantine-sm;
    @apply border border-mantine-gray-200 dark:border-mantine-gray-700;
    @apply transition-shadow duration-200;
    @apply hover:shadow-mantine-md;
  }
}
```

## 📋 Phase 2: Component Enhancement

### **Step 4: Enhanced Button Component**

Create `components/ui/button-enhanced.tsx`:

```typescript
import * as React from "react"
import { Slot } from "@radix-ui/react-slot"
import { cva, type VariantProps } from "class-variance-authority"
import { cn } from "@/lib/utils"

const buttonVariants = cva(
  "inline-flex items-center justify-center rounded-md text-sm font-medium ring-offset-background transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:pointer-events-none disabled:opacity-50",
  {
    variants: {
      variant: {
        default: "bg-primary text-primary-foreground hover:bg-primary/90",
        destructive: "bg-destructive text-destructive-foreground hover:bg-destructive/90",
        outline: "border border-input bg-background hover:bg-accent hover:text-accent-foreground",
        secondary: "bg-secondary text-secondary-foreground hover:bg-secondary/80",
        ghost: "hover:bg-accent hover:text-accent-foreground",
        link: "text-primary underline-offset-4 hover:underline",
        
        // Mantine-inspired variants
        "mantine-filled": [
          "bg-mantine-blue-500 text-white font-medium",
          "hover:bg-mantine-blue-600 active:bg-mantine-blue-700",
          "focus:ring-2 focus:ring-mantine-blue-300 focus:ring-offset-2",
          "transition-all duration-200 ease-in-out",
          "hover:transform hover:scale-[1.02] active:transform active:scale-[0.98]"
        ],
        "mantine-light": [
          "bg-mantine-blue-50 text-mantine-blue-700 border border-mantine-blue-200",
          "hover:bg-mantine-blue-100 active:bg-mantine-blue-200",
          "transition-all duration-200"
        ],
        "mantine-outline": [
          "border-2 border-mantine-blue-500 text-mantine-blue-500 bg-transparent",
          "hover:bg-mantine-blue-500 hover:text-white",
          "transition-all duration-200"
        ],
        "mantine-subtle": [
          "text-mantine-blue-600 bg-transparent",
          "hover:bg-mantine-blue-50 active:bg-mantine-blue-100",
          "transition-all duration-200"
        ],
        
        // Ant Design-inspired variants
        "antd-primary": [
          "bg-antd-primary text-white font-medium",
          "hover:bg-blue-600 active:bg-blue-700",
          "shadow-antd hover:shadow-lg transition-all duration-200"
        ],
        "antd-default": [
          "bg-white text-gray-700 border border-gray-300",
          "hover:border-antd-primary hover:text-antd-primary",
          "transition-all duration-200"
        ],
        "antd-dashed": [
          "bg-white text-gray-700 border border-dashed border-gray-300",
          "hover:border-antd-primary hover:text-antd-primary",
          "transition-all duration-200"
        ]
      },
      size: {
        default: "h-10 px-4 py-2",
        sm: "h-9 rounded-md px-3",
        lg: "h-11 rounded-md px-8",
        icon: "h-10 w-10",
        
        // Mantine sizes
        "mantine-xs": "h-7 px-2 text-xs rounded-mantine-xs",
        "mantine-sm": "h-8 px-3 text-sm rounded-mantine-sm", 
        "mantine-md": "h-9 px-4 text-sm rounded-mantine-md",
        "mantine-lg": "h-11 px-6 text-base rounded-mantine-lg",
        "mantine-xl": "h-12 px-8 text-lg rounded-mantine-xl",
      },
    },
    defaultVariants: {
      variant: "default",
      size: "default",
    },
  }
)

export interface ButtonProps
  extends React.ButtonHTMLAttributes<HTMLButtonElement>,
    VariantProps<typeof buttonVariants> {
  asChild?: boolean
  loading?: boolean
  leftIcon?: React.ReactNode
  rightIcon?: React.ReactNode
}

const Button = React.forwardRef<HTMLButtonElement, ButtonProps>(
  ({ className, variant, size, asChild = false, loading, leftIcon, rightIcon, children, ...props }, ref) => {
    const Comp = asChild ? Slot : "button"
    
    return (
      <Comp
        className={cn(
          buttonVariants({ variant, size, className }),
          loading && "cursor-not-allowed opacity-70"
        )}
        ref={ref}
        disabled={loading || props.disabled}
        {...props}
      >
        {loading && (
          <svg
            className="mr-2 h-4 w-4 animate-spin"
            xmlns="http://www.w3.org/2000/svg"
            fill="none"
            viewBox="0 0 24 24"
          >
            <circle
              className="opacity-25"
              cx="12"
              cy="12"
              r="10"
              stroke="currentColor"
              strokeWidth="4"
            />
            <path
              className="opacity-75"
              fill="currentColor"
              d="m4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
            />
          </svg>
        )}
        {!loading && leftIcon && <span className="mr-2">{leftIcon}</span>}
        {children}
        {!loading && rightIcon && <span className="ml-2">{rightIcon}</span>}
      </Comp>
    )
  }
)
Button.displayName = "Button"

export { Button, buttonVariants }
```

### **Step 5: Enhanced Input Component**

Create `components/ui/input-enhanced.tsx`:

```typescript
import * as React from "react"
import { cva, type VariantProps } from "class-variance-authority"
import { cn } from "@/lib/utils"

const inputVariants = cva(
  "flex w-full rounded-md border bg-background px-3 py-2 text-sm ring-offset-background file:border-0 file:bg-transparent file:text-sm file:font-medium placeholder:text-muted-foreground focus-visible:outline-none disabled:cursor-not-allowed disabled:opacity-50",
  {
    variants: {
      variant: {
        default: [
          "border-input",
          "focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2"
        ],
        
        // Mantine-inspired variants
        mantine: [
          "border-mantine-gray-300 rounded-mantine-sm",
          "focus:border-mantine-blue-500 focus:ring-1 focus:ring-mantine-blue-500",
          "hover:border-mantine-gray-400",
          "transition-all duration-200",
          "placeholder:text-mantine-gray-500"
        ],
        
        // Ant Design-inspired variants  
        antd: [
          "border-gray-300 rounded-antd",
          "focus:border-antd-primary focus:ring-1 focus:ring-antd-primary",
          "hover:border-antd-primary",
          "transition-all duration-200",
          "placeholder:text-gray-400"
        ]
      },
      inputSize: {
        default: "h-10 px-3 py-2",
        sm: "h-8 px-2 py-1 text-sm",
        lg: "h-12 px-4 py-3",
        
        // Mantine sizes
        "mantine-xs": "h-7 px-2 py-1 text-xs",
        "mantine-sm": "h-8 px-3 py-1 text-sm",
        "mantine-md": "h-9 px-3 py-2 text-sm",
        "mantine-lg": "h-11 px-4 py-2 text-base",
        "mantine-xl": "h-12 px-5 py-3 text-lg",
      }
    },
    defaultVariants: {
      variant: "default",
      inputSize: "default",
    },
  }
)

export interface InputProps
  extends React.InputHTMLAttributes<HTMLInputElement>,
    VariantProps<typeof inputVariants> {
  leftIcon?: React.ReactNode
  rightIcon?: React.ReactNode
  error?: boolean
  errorMessage?: string
  label?: string
  description?: string
}

const Input = React.forwardRef<HTMLInputElement, InputProps>(
  ({ 
    className, 
    variant, 
    inputSize, 
    type, 
    leftIcon, 
    rightIcon, 
    error, 
    errorMessage, 
    label, 
    description,
    ...props 
  }, ref) => {
    const inputId = React.useId()
    
    return (
      <div className="w-full">
        {label && (
          <label 
            htmlFor={inputId}
            className="block text-sm font-medium text-gray-700 mb-1"
          >
            {label}
          </label>
        )}
        
        {description && (
          <p className="text-sm text-muted-foreground mb-2">
            {description}
          </p>
        )}
        
        <div className="relative">
          {leftIcon && (
            <div className="absolute left-3 top-1/2 transform -translate-y-1/2 text-muted-foreground">
              {leftIcon}
            </div>
          )}
          
          <input
            id={inputId}
            type={type}
            className={cn(
              inputVariants({ variant, inputSize }),
              leftIcon && "pl-10",
              rightIcon && "pr-10",
              error && "border-red-500 focus:border-red-500 focus:ring-red-500",
              className
            )}
            ref={ref}
            {...props}
          />
          
          {rightIcon && (
            <div className="absolute right-3 top-1/2 transform -translate-y-1/2 text-muted-foreground">
              {rightIcon}
            </div>
          )}
        </div>
        
        {error && errorMessage && (
          <p className="mt-1 text-sm text-red-600">
            {errorMessage}
          </p>
        )}
      </div>
    )
  }
)
Input.displayName = "Input"

export { Input, inputVariants }
```

## 📋 Phase 3: Advanced Integration

### **Step 6: Create Design System Hook**

Create `hooks/use-design-system.ts`:

```typescript
import { useState, useEffect } from 'react'

type DesignSystemTheme = 'default' | 'mantine' | 'antd'

interface DesignSystemConfig {
  theme: DesignSystemTheme
  primaryColor: string
  borderRadius: string
  spacing: Record<string, string>
  shadows: Record<string, string>
}

const designSystemConfigs: Record<DesignSystemTheme, DesignSystemConfig> = {
  default: {
    theme: 'default',
    primaryColor: 'hsl(221.2 83.2% 53.3%)',
    borderRadius: '0.5rem',
    spacing: {
      xs: '0.5rem',
      sm: '0.75rem',
      md: '1rem',
      lg: '1.25rem',
      xl: '1.5rem',
    },
    shadows: {
      sm: '0 1px 2px 0 rgb(0 0 0 / 0.05)',
      md: '0 4px 6px -1px rgb(0 0 0 / 0.1)',
      lg: '0 10px 15px -3px rgb(0 0 0 / 0.1)',
    }
  },
  mantine: {
    theme: 'mantine',
    primaryColor: '#228be6',
    borderRadius: '8px',
    spacing: {
      xs: '0.625rem',
      sm: '0.75rem',
      md: '1rem',
      lg: '1.25rem',
      xl: '1.5rem',
    },
    shadows: {
      sm: '0 1px 3px rgba(0, 0, 0, 0.05), 0 1px 2px rgba(0, 0, 0, 0.1)',
      md: '0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06)',
      lg: '0 10px 15px -3px rgba(0, 0, 0, 0.1), 0 4px 6px -2px rgba(0, 0, 0, 0.05)',
    }
  },
  antd: {
    theme: 'antd',
    primaryColor: '#1890ff',
    borderRadius: '6px',
    spacing: {
      xs: '8px',
      sm: '12px',
      md: '16px',
      lg: '24px',
      xl: '32px',
    },
    shadows: {
      sm: '0 2px 8px rgba(0, 0, 0, 0.15)',
      md: '0 4px 12px rgba(0, 0, 0, 0.15)',
      lg: '0 8px 24px rgba(0, 0, 0, 0.15)',
    }
  }
}

export function useDesignSystem(initialTheme: DesignSystemTheme = 'default') {
  const [currentTheme, setCurrentTheme] = useState<DesignSystemTheme>(initialTheme)
  const [config, setConfig] = useState<DesignSystemConfig>(designSystemConfigs[initialTheme])

  useEffect(() => {
    setConfig(designSystemConfigs[currentTheme])
    
    // Apply CSS custom properties
    const root = document.documentElement
    const newConfig = designSystemConfigs[currentTheme]
    
    root.style.setProperty('--ds-primary-color', newConfig.primaryColor)
    root.style.setProperty('--ds-border-radius', newConfig.borderRadius)
    
    Object.entries(newConfig.spacing).forEach(([key, value]) => {
      root.style.setProperty(`--ds-spacing-${key}`, value)
    })
    
    Object.entries(newConfig.shadows).forEach(([key, value]) => {
      root.style.setProperty(`--ds-shadow-${key}`, value)
    })
    
  }, [currentTheme])

  const switchTheme = (theme: DesignSystemTheme) => {
    setCurrentTheme(theme)
  }

  const getVariantForTheme = (variants: Record<DesignSystemTheme, string>) => {
    return variants[currentTheme] || variants.default
  }

  return {
    theme: currentTheme,
    config,
    switchTheme,
    getVariantForTheme,
    availableThemes: Object.keys(designSystemConfigs) as DesignSystemTheme[]
  }
}
```

### **Step 7: Component Story Examples**

Create `stories/Button.stories.tsx` for Storybook:

```typescript
import type { Meta, StoryObj } from '@storybook/react'
import { Button } from '@/components/ui/button-enhanced'
import { Mail, Download } from 'lucide-react'

const meta = {
  title: 'Components/Button Enhanced',
  component: Button,
  parameters: {
    layout: 'centered',
  },
  tags: ['autodocs'],
  argTypes: {
    variant: {
      control: { type: 'select' },
      options: [
        'default', 'destructive', 'outline', 'secondary', 'ghost', 'link',
        'mantine-filled', 'mantine-light', 'mantine-outline', 'mantine-subtle',
        'antd-primary', 'antd-default', 'antd-dashed'
      ],
    },
    size: {
      control: { type: 'select' },
      options: [
        'default', 'sm', 'lg', 'icon',
        'mantine-xs', 'mantine-sm', 'mantine-md', 'mantine-lg', 'mantine-xl'
      ],
    },
  },
} satisfies Meta<typeof Button>

export default meta
type Story = StoryObj<typeof meta>

export const Default: Story = {
  args: {
    children: 'Button',
  },
}

export const MantineFilled: Story = {
  args: {
    variant: 'mantine-filled',
    size: 'mantine-md',
    children: 'Mantine Button',
  },
}

export const MantineWithIcons: Story = {
  args: {
    variant: 'mantine-filled',
    size: 'mantine-md',
    leftIcon: <Mail className="h-4 w-4" />,
    children: 'Send Email',
  },
}

export const AntDesignPrimary: Story = {
  args: {
    variant: 'antd-primary',
    children: 'Ant Design Button',
  },
}

export const Loading: Story = {
  args: {
    variant: 'mantine-filled',
    loading: true,
    children: 'Loading...',
  },
}

export const AllVariants: Story = {
  render: () => (
    <div className="grid grid-cols-3 gap-4 p-8">
      {/* shadcn/ui variants */}
      <div className="space-y-2">
        <h3 className="font-semibold text-sm text-gray-600">shadcn/ui</h3>
        <Button variant="default">Default</Button>
        <Button variant="outline">Outline</Button>
        <Button variant="ghost">Ghost</Button>
      </div>
      
      {/* Mantine variants */}
      <div className="space-y-2">
        <h3 className="font-semibold text-sm text-gray-600">Mantine Style</h3>
        <Button variant="mantine-filled">Filled</Button>
        <Button variant="mantine-light">Light</Button>
        <Button variant="mantine-outline">Outline</Button>
        <Button variant="mantine-subtle">Subtle</Button>
      </div>
      
      {/* Ant Design variants */}
      <div className="space-y-2">
        <h3 className="font-semibold text-sm text-gray-600">Ant Design Style</h3>
        <Button variant="antd-primary">Primary</Button>
        <Button variant="antd-default">Default</Button>
        <Button variant="antd-dashed">Dashed</Button>
      </div>
    </div>
  ),
}
```

## 🔧 Phase 4: Testing & Validation

### **Step 8: Component Testing**

Create `__tests__/button-enhanced.test.tsx`:

```typescript
import { render, screen, fireEvent } from '@testing-library/react'
import { Button } from '@/components/ui/button-enhanced'
import { Mail } from 'lucide-react'

describe('Enhanced Button Component', () => {
  test('renders with default variant', () => {
    render(<Button>Test Button</Button>)
    const button = screen.getByRole('button', { name: /test button/i })
    expect(button).toBeInTheDocument()
  })

  test('renders with Mantine variant', () => {
    render(<Button variant="mantine-filled">Mantine Button</Button>)
    const button = screen.getByRole('button', { name: /mantine button/i })
    expect(button).toHaveClass('bg-mantine-blue-500')
  })

  test('renders with Ant Design variant', () => {
    render(<Button variant="antd-primary">Ant Button</Button>)
    const button = screen.getByRole('button', { name: /ant button/i })
    expect(button).toHaveClass('bg-antd-primary')
  })

  test('shows loading state', () => {
    render(<Button loading>Loading Button</Button>)
    const button = screen.getByRole('button', { name: /loading button/i })
    expect(button).toBeDisabled()
    expect(button).toHaveClass('cursor-not-allowed')
  })

  test('renders with icons', () => {
    render(
      <Button leftIcon={<Mail data-testid="mail-icon" />}>
        Email Button
      </Button>
    )
    expect(screen.getByTestId('mail-icon')).toBeInTheDocument()
  })

  test('handles click events', () => {
    const handleClick = jest.fn()
    render(<Button onClick={handleClick}>Click Me</Button>)
    
    fireEvent.click(screen.getByRole('button', { name: /click me/i }))
    expect(handleClick).toHaveBeenCalledTimes(1)
  })

  test('applies size variants correctly', () => {
    render(<Button size="mantine-lg">Large Button</Button>)
    const button = screen.getByRole('button', { name: /large button/i })
    expect(button).toHaveClass('h-11')
  })
})
```

### **Step 9: Performance Testing**

Create `scripts/bundle-analysis.js`:

```javascript
const { execSync } = require('child_process')
const fs = require('fs')
const path = require('path')

// Build and analyze bundle size
function analyzeBundleSize() {
  console.log('Building for production...')
  execSync('npm run build', { stdio: 'inherit' })
  
  const buildDir = path.join(process.cwd(), 'dist')
  const files = fs.readdirSync(buildDir, { recursive: true })
  
  const jsFiles = files.filter(file => file.endsWith('.js'))
  let totalSize = 0
  
  console.log('\n📦 Bundle Analysis:')
  console.log('=' .repeat(50))
  
  jsFiles.forEach(file => {
    const filePath = path.join(buildDir, file)
    const stats = fs.statSync(filePath)
    const sizeKB = (stats.size / 1024).toFixed(2)
    totalSize += stats.size
    
    console.log(`${file}: ${sizeKB} KB`)
  })
  
  console.log('=' .repeat(50))
  console.log(`Total JavaScript: ${(totalSize / 1024).toFixed(2)} KB`)
  
  // Warn if bundle is too large
  if (totalSize > 500 * 1024) { // 500KB threshold
    console.warn('⚠️  Bundle size exceeds 500KB. Consider code splitting.')
  } else {
    console.log('✅ Bundle size is within acceptable limits.')
  }
}

analyzeBundleSize()
```

## 🚀 Phase 5: Documentation & Deployment

### **Step 10: Usage Documentation**

Create `docs/component-usage-guide.md`:

```markdown
# Component Usage Guide

## Quick Start

### Basic Button Usage

```tsx
import { Button } from '@/components/ui/button-enhanced'

// Default shadcn/ui style
<Button>Default Button</Button>

// Mantine-inspired style
<Button variant="mantine-filled" size="mantine-md">
  Mantine Button
</Button>

// Ant Design-inspired style
<Button variant="antd-primary">
  Ant Design Button
</Button>
```

### Advanced Button Features

```tsx
import { Button } from '@/components/ui/button-enhanced'
import { Mail, Download } from 'lucide-react'

// With icons
<Button 
  variant="mantine-filled" 
  leftIcon={<Mail />}
>
  Send Email
</Button>

// Loading state
<Button 
  variant="mantine-filled" 
  loading={isSubmitting}
>
  {isSubmitting ? 'Submitting...' : 'Submit'}
</Button>

// Size variants
<Button size="mantine-xs">Extra Small</Button>
<Button size="mantine-lg">Large</Button>
```

### Theme Switching

```tsx
import { useDesignSystem } from '@/hooks/use-design-system'

function ThemeSelector() {
  const { theme, switchTheme, availableThemes } = useDesignSystem()
  
  return (
    <select 
      value={theme}
      onChange={(e) => switchTheme(e.target.value as any)}
    >
      {availableThemes.map(t => (
        <option key={t} value={t}>{t}</option>
      ))}
    </select>
  )
}
```

## Component Variants Reference

### Button Variants

| Variant | Description | Best Use Case |
|---------|-------------|---------------|
| `default` | Standard shadcn/ui button | General purpose |
| `mantine-filled` | Mantine's filled button style | Primary actions |
| `mantine-light` | Mantine's light variant | Secondary actions |
| `mantine-outline` | Mantine's outline style | Tertiary actions |
| `antd-primary` | Ant Design primary button | Enterprise applications |
| `antd-default` | Ant Design default style | General actions |

### Size Reference

| Size | Height | Padding | Font Size |
|------|--------|---------|-----------|
| `mantine-xs` | 28px | 8px | 12px |
| `mantine-sm` | 32px | 12px | 14px |
| `mantine-md` | 36px | 16px | 14px |
| `mantine-lg` | 44px | 24px | 16px |
| `mantine-xl` | 48px | 32px | 18px |
```

---

## 🔗 Navigation

**Previous**: [Executive Summary](./executive-summary.md)  
**Next**: [Best Practices](./best-practices.md)

---

*Last updated: [Current Date] | Implementation guide version: 1.0*