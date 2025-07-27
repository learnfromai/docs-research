# Component Customization Strategies: Practical Implementation Approaches

## 🎯 Overview

This guide provides hands-on strategies for customizing **shadcn/ui** components with **Mantine** and **Ant Design** styling patterns. Learn practical techniques for achieving professional visual design while maintaining the flexibility and copy-paste simplicity of shadcn/ui.

## 🏗️ Customization Architecture

### **Strategy 1: Variant Extension Pattern** ⭐ *Most Recommended*

This approach extends existing shadcn/ui components with additional variants inspired by Mantine and Ant Design, preserving backward compatibility while adding new styling options.

#### **Enhanced Button Implementation**
```typescript
// components/ui/button-enhanced.tsx
import * as React from "react"
import { Slot } from "@radix-ui/react-slot"
import { cva, type VariantProps } from "class-variance-authority"
import { cn } from "@/lib/utils"

const buttonVariants = cva(
  // Base classes - shared across all variants
  [
    "inline-flex items-center justify-center rounded-md text-sm font-medium",
    "ring-offset-background transition-colors focus-visible:outline-none",
    "focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2",
    "disabled:pointer-events-none disabled:opacity-50"
  ],
  {
    variants: {
      variant: {
        // Original shadcn/ui variants (preserved)
        default: "bg-primary text-primary-foreground hover:bg-primary/90",
        destructive: "bg-destructive text-destructive-foreground hover:bg-destructive/90",
        outline: "border border-input bg-background hover:bg-accent hover:text-accent-foreground",
        secondary: "bg-secondary text-secondary-foreground hover:bg-secondary/80",
        ghost: "hover:bg-accent hover:text-accent-foreground",
        link: "text-primary underline-offset-4 hover:underline",
        
        // Mantine-inspired variants
        "mantine-filled": [
          "bg-blue-500 text-white font-medium",
          "hover:bg-blue-600 active:bg-blue-700",
          "focus:ring-2 focus:ring-blue-300 focus:ring-offset-2",
          "transition-all duration-200 ease-in-out",
          "hover:transform hover:scale-[1.02]",
          "active:transform active:scale-[0.98]",
          "shadow-sm hover:shadow-md"
        ],
        "mantine-light": [
          "bg-blue-50 text-blue-700 border border-blue-200",
          "hover:bg-blue-100 active:bg-blue-200",
          "focus:ring-2 focus:ring-blue-300 focus:ring-offset-1",
          "transition-all duration-200"
        ],
        "mantine-outline": [
          "border-2 border-blue-500 text-blue-500 bg-transparent",
          "hover:bg-blue-500 hover:text-white",
          "focus:bg-blue-50 focus:ring-2 focus:ring-blue-300",
          "transition-all duration-200"
        ],
        "mantine-subtle": [
          "text-blue-600 bg-transparent",
          "hover:bg-blue-50 active:bg-blue-100",
          "focus:bg-blue-50 focus:ring-2 focus:ring-blue-300",
          "transition-all duration-200"
        ],
        "mantine-gradient": [
          "bg-gradient-to-r from-blue-500 to-purple-600 text-white",
          "hover:from-blue-600 hover:to-purple-700",
          "focus:ring-2 focus:ring-blue-300 focus:ring-offset-2",
          "transition-all duration-300"
        ],
        
        // Ant Design-inspired variants
        "antd-primary": [
          "bg-blue-500 text-white font-medium",
          "hover:bg-blue-600 active:bg-blue-700",
          "focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2",
          "shadow-sm hover:shadow-md",
          "transition-all duration-200 cubic-bezier(0.645, 0.045, 0.355, 1)"
        ],
        "antd-default": [
          "bg-white text-gray-700 border border-gray-300",
          "hover:border-blue-500 hover:text-blue-500",
          "focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20",
          "active:bg-gray-50",
          "transition-all duration-200"
        ],
        "antd-dashed": [
          "bg-white text-gray-700 border border-dashed border-gray-300",
          "hover:border-blue-500 hover:text-blue-500",
          "focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20",
          "transition-all duration-200"
        ],
        "antd-text": [
          "text-gray-700 bg-transparent",
          "hover:bg-gray-100 active:bg-gray-200",
          "focus:bg-gray-100 focus:ring-2 focus:ring-gray-300",
          "transition-all duration-200"
        ],
        "antd-link": [
          "text-blue-500 bg-transparent",
          "hover:text-blue-600 active:text-blue-700",
          "focus:ring-2 focus:ring-blue-300 focus:ring-offset-1",
          "transition-colors duration-200"
        ]
      },
      size: {
        // Original sizes (preserved)
        default: "h-10 px-4 py-2",
        sm: "h-9 rounded-md px-3",
        lg: "h-11 rounded-md px-8",
        icon: "h-10 w-10",
        
        // Mantine-inspired sizes
        "mantine-xs": "h-7 px-2 text-xs rounded-sm",
        "mantine-sm": "h-8 px-3 text-sm rounded",
        "mantine-md": "h-9 px-4 text-sm rounded-md",
        "mantine-lg": "h-11 px-6 text-base rounded-md",
        "mantine-xl": "h-12 px-8 text-lg rounded-lg",
        
        // Ant Design-inspired sizes
        "antd-small": "h-8 px-3 text-sm",
        "antd-middle": "h-9 px-4 text-sm", 
        "antd-large": "h-11 px-6 text-base"
      }
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
  block?: boolean // Full width
  danger?: boolean // Ant Design danger state
}

const Button = React.forwardRef<HTMLButtonElement, ButtonProps>(
  ({ 
    className, 
    variant, 
    size, 
    asChild = false, 
    loading, 
    leftIcon, 
    rightIcon, 
    block,
    danger,
    children, 
    disabled,
    ...props 
  }, ref) => {
    const Comp = asChild ? Slot : "button"
    
    // Apply danger state styling
    const dangerVariant = danger && variant?.includes('antd') 
      ? variant.replace('antd-', 'antd-danger-')
      : variant
    
    return (
      <Comp
        className={cn(
          buttonVariants({ variant: dangerVariant, size }),
          loading && "cursor-not-allowed relative",
          block && "w-full",
          danger && !variant?.includes('antd') && "border-red-500 text-red-500 hover:bg-red-50",
          className
        )}
        ref={ref}
        disabled={loading || disabled}
        {...props}
      >
        {loading && (
          <div className="absolute inset-0 flex items-center justify-center">
            <div className="h-4 w-4 animate-spin rounded-full border-2 border-current border-t-transparent" />
          </div>
        )}
        
        <div className={cn("flex items-center", loading && "invisible")}>
          {leftIcon && <span className="mr-2">{leftIcon}</span>}
          {children}
          {rightIcon && <span className="ml-2">{rightIcon}</span>}
        </div>
      </Comp>
    )
  }
)
Button.displayName = "Button"

export { Button, buttonVariants }
```

#### **Usage Examples**
```tsx
// Original shadcn/ui usage (still works)
<Button variant="default">Default Button</Button>

// Mantine-style buttons
<Button variant="mantine-filled" size="mantine-md">
  Mantine Filled
</Button>

<Button variant="mantine-gradient" size="mantine-lg">
  Gradient Button
</Button>

// Ant Design-style buttons
<Button variant="antd-primary" size="antd-middle">
  Primary Action
</Button>

<Button variant="antd-default" danger>
  Danger Action
</Button>

// With icons and loading
<Button 
  variant="mantine-light" 
  size="mantine-md"
  leftIcon={<Mail className="h-4 w-4" />}
  loading={isSubmitting}
>
  Send Email
</Button>
```

### **Strategy 2: Theme-Based Component Switching**

This approach uses a design system context to dynamically apply different styling patterns based on the selected theme.

#### **Design System Context Implementation**
```typescript
// contexts/design-system-context.tsx
import React, { createContext, useContext, useState } from 'react'

export type DesignSystemTheme = 'shadcn' | 'mantine' | 'antd'

interface DesignSystemContextValue {
  theme: DesignSystemTheme
  setTheme: (theme: DesignSystemTheme) => void
  getVariant: (baseVariant: string) => string
  getSize: (baseSize: string) => string
}

const DesignSystemContext = createContext<DesignSystemContextValue | undefined>(undefined)

const variantMapping: Record<DesignSystemTheme, Record<string, string>> = {
  shadcn: {
    primary: 'default',
    secondary: 'secondary',
    outline: 'outline'
  },
  mantine: {
    primary: 'mantine-filled',
    secondary: 'mantine-light',
    outline: 'mantine-outline'
  },
  antd: {
    primary: 'antd-primary',
    secondary: 'antd-default',
    outline: 'antd-dashed'
  }
}

const sizeMapping: Record<DesignSystemTheme, Record<string, string>> = {
  shadcn: {
    small: 'sm',
    medium: 'default',
    large: 'lg'
  },
  mantine: {
    small: 'mantine-sm',
    medium: 'mantine-md', 
    large: 'mantine-lg'
  },
  antd: {
    small: 'antd-small',
    medium: 'antd-middle',
    large: 'antd-large'
  }
}

export function DesignSystemProvider({ 
  children, 
  defaultTheme = 'shadcn' 
}: { 
  children: React.ReactNode
  defaultTheme?: DesignSystemTheme 
}) {
  const [theme, setTheme] = useState<DesignSystemTheme>(defaultTheme)
  
  const getVariant = (baseVariant: string) => {
    return variantMapping[theme][baseVariant] || baseVariant
  }
  
  const getSize = (baseSize: string) => {
    return sizeMapping[theme][baseSize] || baseSize
  }
  
  return (
    <DesignSystemContext.Provider value={{ theme, setTheme, getVariant, getSize }}>
      <div data-design-system={theme} className={`theme-${theme}`}>
        {children}
      </div>
    </DesignSystemContext.Provider>
  )
}

export function useDesignSystem() {
  const context = useContext(DesignSystemContext)
  if (!context) {
    throw new Error('useDesignSystem must be used within a DesignSystemProvider')
  }
  return context
}
```

#### **Theme-Aware Button Component**
```typescript
// components/ui/button-adaptive.tsx
import React from 'react'
import { Button as BaseButton, ButtonProps as BaseButtonProps } from './button-enhanced'
import { useDesignSystem } from '@/contexts/design-system-context'

interface AdaptiveButtonProps extends Omit<BaseButtonProps, 'variant' | 'size'> {
  intent?: 'primary' | 'secondary' | 'outline' | 'danger'
  size?: 'small' | 'medium' | 'large'
}

export function Button({ 
  intent = 'primary', 
  size = 'medium', 
  ...props 
}: AdaptiveButtonProps) {
  const { getVariant, getSize } = useDesignSystem()
  
  const variant = getVariant(intent)
  const buttonSize = getSize(size)
  
  return (
    <BaseButton 
      variant={variant as any}
      size={buttonSize as any}
      {...props} 
    />
  )
}
```

#### **Usage with Theme Switching**
```tsx
// App.tsx
function App() {
  return (
    <DesignSystemProvider defaultTheme="mantine">
      <ThemeSelector />
      <ButtonShowcase />
    </DesignSystemProvider>
  )
}

function ThemeSelector() {
  const { theme, setTheme } = useDesignSystem()
  
  return (
    <select value={theme} onChange={(e) => setTheme(e.target.value as any)}>
      <option value="shadcn">shadcn/ui</option>
      <option value="mantine">Mantine Style</option>
      <option value="antd">Ant Design Style</option>
    </select>
  )
}

function ButtonShowcase() {
  return (
    <div className="space-y-4">
      <Button intent="primary" size="medium">Primary Button</Button>
      <Button intent="secondary" size="medium">Secondary Button</Button>
      <Button intent="outline" size="medium">Outline Button</Button>
    </div>
  )
}
```

### **Strategy 3: CSS-in-JS Integration**

For more complex components that require dynamic styling based on props or state, this approach integrates CSS-in-JS libraries while maintaining the shadcn/ui foundation.

#### **Styled Components Integration**
```typescript
// components/ui/button-styled.tsx
import styled, { css } from 'styled-components'
import { Button as BaseButton } from './button'

interface StyledButtonProps {
  $variant?: 'mantine' | 'antd'
  $loading?: boolean
  $size?: 'small' | 'medium' | 'large'
}

const mantineStyles = css<StyledButtonProps>`
  /* Mantine-inspired styling */
  background: linear-gradient(135deg, #228be6 0%, #1c7ed6 100%);
  border: none;
  border-radius: 8px;
  color: white;
  font-weight: 600;
  transition: all 200ms ease;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.12);
  
  &:hover {
    transform: translateY(-1px);
    box-shadow: 0 4px 12px rgba(34, 139, 230, 0.4);
    background: linear-gradient(135deg, #1c7ed6 0%, #1971c2 100%);
  }
  
  &:active {
    transform: translateY(0);
    box-shadow: 0 2px 6px rgba(34, 139, 230, 0.4);
  }
  
  ${props => props.$loading && css`
    pointer-events: none;
    opacity: 0.7;
    
    &::after {
      content: '';
      position: absolute;
      top: 50%;
      left: 50%;
      width: 16px;
      height: 16px;
      margin: -8px 0 0 -8px;
      border: 2px solid transparent;
      border-top: 2px solid currentColor;
      border-radius: 50%;
      animation: spin 1s linear infinite;
    }
  `}
`

const antdStyles = css<StyledButtonProps>`
  /* Ant Design-inspired styling */
  background: #1890ff;
  border: 1px solid #1890ff;
  border-radius: 6px;
  color: white;
  font-weight: 400;
  transition: all 0.3s cubic-bezier(0.645, 0.045, 0.355, 1);
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.15);
  
  &:hover {
    background: #40a9ff;
    border-color: #40a9ff;
    transform: translateY(-2px);
    box-shadow: 0 4px 12px rgba(24, 144, 255, 0.4);
  }
  
  &:active {
    background: #096dd9;
    border-color: #096dd9;
    transform: translateY(0);
  }
  
  &:focus {
    outline: none;
    box-shadow: 0 0 0 2px rgba(24, 144, 255, 0.2);
  }
`

const StyledButton = styled(BaseButton)<StyledButtonProps>`
  position: relative;
  overflow: hidden;
  
  ${props => props.$variant === 'mantine' && mantineStyles}
  ${props => props.$variant === 'antd' && antdStyles}
  
  ${props => props.$size === 'small' && css`
    height: 32px;
    padding: 0 12px;
    font-size: 14px;
  `}
  
  ${props => props.$size === 'large' && css`
    height: 44px;
    padding: 0 24px;
    font-size: 16px;
  `}
  
  @keyframes spin {
    to {
      transform: rotate(360deg);
    }
  }
`

export { StyledButton }
```

### **Strategy 4: Compound Component Pattern**

This approach creates compound components that combine multiple elements with coordinated styling, useful for complex components like Cards, Forms, or Navigation.

#### **Enhanced Card Component**
```typescript
// components/ui/card-enhanced.tsx
import * as React from "react"
import { cva, type VariantProps } from "class-variance-authority"
import { cn } from "@/lib/utils"

const cardVariants = cva(
  "rounded-lg border bg-card text-card-foreground shadow-sm",
  {
    variants: {
      variant: {
        default: "border-border",
        mantine: [
          "border-gray-200 shadow-sm hover:shadow-md",
          "transition-shadow duration-200",
          "bg-white"
        ],
        antd: [
          "border-gray-300 shadow-sm",
          "bg-white rounded-lg",
          "hover:shadow-lg transition-shadow duration-300"
        ]
      },
      padding: {
        none: "",
        sm: "p-4",
        md: "p-6", 
        lg: "p-8"
      }
    },
    defaultVariants: {
      variant: "default",
      padding: "md"
    }
  }
)

const cardHeaderVariants = cva(
  "flex flex-col space-y-1.5",
  {
    variants: {
      variant: {
        default: "p-6",
        mantine: "p-4 pb-2",
        antd: "p-6 pb-4 border-b border-gray-100"
      }
    },
    defaultVariants: {
      variant: "default"
    }
  }
)

const cardContentVariants = cva(
  "",
  {
    variants: {
      variant: {
        default: "p-6 pt-0",
        mantine: "p-4 pt-2",
        antd: "p-6 pt-4"
      }
    },
    defaultVariants: {
      variant: "default"
    }
  }
)

// Context for sharing variant across compound components
const CardContext = React.createContext<{
  variant: 'default' | 'mantine' | 'antd'
}>({ variant: 'default' })

interface CardProps
  extends React.HTMLAttributes<HTMLDivElement>,
    VariantProps<typeof cardVariants> {
  hover?: boolean
  bordered?: boolean
}

const Card = React.forwardRef<HTMLDivElement, CardProps>(
  ({ className, variant, padding, hover, bordered, ...props }, ref) => (
    <CardContext.Provider value={{ variant: variant || 'default' }}>
      <div
        ref={ref}
        className={cn(
          cardVariants({ variant, padding }),
          hover && "cursor-pointer hover:shadow-lg transition-shadow",
          bordered && variant === 'mantine' && "border-2",
          className
        )}
        {...props}
      />
    </CardContext.Provider>
  )
)
Card.displayName = "Card"

const CardHeader = React.forwardRef<
  HTMLDivElement,
  React.HTMLAttributes<HTMLDivElement>
>(({ className, ...props }, ref) => {
  const { variant } = React.useContext(CardContext)
  return (
    <div
      ref={ref}
      className={cn(cardHeaderVariants({ variant }), className)}
      {...props}
    />
  )
})
CardHeader.displayName = "CardHeader"

const CardTitle = React.forwardRef<
  HTMLParagraphElement,
  React.HTMLAttributes<HTMLHeadingElement>
>(({ className, ...props }, ref) => {
  const { variant } = React.useContext(CardContext)
  return (
    <h3
      ref={ref}
      className={cn(
        "text-2xl font-semibold leading-none tracking-tight",
        variant === 'mantine' && "text-xl font-medium text-gray-900",
        variant === 'antd' && "text-lg font-medium text-gray-800",
        className
      )}
      {...props}
    />
  )
})
CardTitle.displayName = "CardTitle"

const CardDescription = React.forwardRef<
  HTMLParagraphElement,
  React.HTMLAttributes<HTMLParagraphElement>
>(({ className, ...props }, ref) => {
  const { variant } = React.useContext(CardContext)
  return (
    <p
      ref={ref}
      className={cn(
        "text-sm text-muted-foreground",
        variant === 'mantine' && "text-gray-600",
        variant === 'antd' && "text-gray-500",
        className
      )}
      {...props}
    />
  )
})
CardDescription.displayName = "CardDescription"

const CardContent = React.forwardRef<
  HTMLDivElement,
  React.HTMLAttributes<HTMLDivElement>
>(({ className, ...props }, ref) => {
  const { variant } = React.useContext(CardContext)
  return (
    <div
      ref={ref}
      className={cn(cardContentVariants({ variant }), className)}
      {...props}
    />
  )
})
CardContent.displayName = "CardContent"

const CardFooter = React.forwardRef<
  HTMLDivElement,
  React.HTMLAttributes<HTMLDivElement>
>(({ className, ...props }, ref) => {
  const { variant } = React.useContext(CardContext)
  return (
    <div
      ref={ref}
      className={cn(
        "flex items-center p-6 pt-0",
        variant === 'mantine' && "p-4 pt-2",
        variant === 'antd' && "p-6 pt-4 border-t border-gray-100",
        className
      )}
      {...props}
    />
  )
})
CardFooter.displayName = "CardFooter"

export { 
  Card, 
  CardHeader, 
  CardFooter, 
  CardTitle, 
  CardDescription, 
  CardContent 
}
```

#### **Card Usage Examples**
```tsx
// Default shadcn/ui card
<Card>
  <CardHeader>
    <CardTitle>Card Title</CardTitle>
    <CardDescription>Card description</CardDescription>
  </CardHeader>
  <CardContent>
    <p>Card content goes here</p>
  </CardContent>
</Card>

// Mantine-style card
<Card variant="mantine" hover>
  <CardHeader>
    <CardTitle>Mantine Card</CardTitle>
    <CardDescription>With hover effects</CardDescription>
  </CardHeader>
  <CardContent>
    <p>Mantine-styled content</p>
  </CardContent>
  <CardFooter>
    <Button variant="mantine-filled">Action</Button>
  </CardFooter>
</Card>

// Ant Design-style card
<Card variant="antd" bordered>
  <CardHeader>
    <CardTitle>Professional Card</CardTitle>
    <CardDescription>Enterprise styling</CardDescription>
  </CardHeader>
  <CardContent>
    <p>Clean, professional appearance</p>
  </CardContent>
</Card>
```

## 🎯 Component-Specific Customization Guides

### **Form Components Enhancement**

#### **Enhanced Input Component**
```typescript
// components/ui/input-enhanced.tsx
import * as React from "react"
import { cva, type VariantProps } from "class-variance-authority"
import { cn } from "@/lib/utils"

const inputVariants = cva(
  [
    "flex w-full rounded-md border bg-background text-sm",
    "ring-offset-background file:border-0 file:bg-transparent",
    "file:text-sm file:font-medium placeholder:text-muted-foreground",
    "focus-visible:outline-none disabled:cursor-not-allowed disabled:opacity-50"
  ],
  {
    variants: {
      variant: {
        default: [
          "border-input px-3 py-2",
          "focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2"
        ],
        mantine: [
          "border-gray-300 px-3 py-2 rounded-md",
          "focus:border-blue-500 focus:ring-1 focus:ring-blue-500",
          "hover:border-gray-400 transition-all duration-200",
          "placeholder:text-gray-500"
        ],
        antd: [
          "border-gray-300 px-3 py-2 rounded",
          "focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20",
          "hover:border-blue-500 transition-all duration-200",
          "placeholder:text-gray-400"
        ]
      },
      inputSize: {
        sm: "h-8 px-2 text-sm",
        default: "h-10 px-3",
        lg: "h-12 px-4 text-base"
      },
      state: {
        default: "",
        error: "border-red-500 focus:border-red-500 focus:ring-red-500/20",
        success: "border-green-500 focus:border-green-500 focus:ring-green-500/20",
        warning: "border-yellow-500 focus:border-yellow-500 focus:ring-yellow-500/20"
      }
    },
    defaultVariants: {
      variant: "default",
      inputSize: "default",
      state: "default"
    }
  }
)

interface InputProps
  extends React.InputHTMLAttributes<HTMLInputElement>,
    VariantProps<typeof inputVariants> {
  label?: string
  description?: string
  error?: string
  success?: string
  leftSection?: React.ReactNode
  rightSection?: React.ReactNode
  withAsterisk?: boolean
}

const Input = React.forwardRef<HTMLInputElement, InputProps>(
  ({ 
    className, 
    variant, 
    inputSize, 
    state,
    label,
    description,
    error,
    success,
    leftSection,
    rightSection,
    withAsterisk,
    id,
    ...props 
  }, ref) => {
    const inputId = id || React.useId()
    const inputState = error ? 'error' : success ? 'success' : state
    
    return (
      <div className="space-y-2">
        {label && (
          <label 
            htmlFor={inputId}
            className={cn(
              "text-sm font-medium leading-none",
              variant === 'mantine' && "text-gray-700 font-medium",
              variant === 'antd' && "text-gray-800 font-medium"
            )}
          >
            {label}
            {withAsterisk && <span className="text-red-500 ml-1">*</span>}
          </label>
        )}
        
        {description && (
          <p className={cn(
            "text-sm text-muted-foreground",
            variant === 'mantine' && "text-gray-600",
            variant === 'antd' && "text-gray-500"
          )}>
            {description}
          </p>
        )}
        
        <div className="relative">
          {leftSection && (
            <div className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-500">
              {leftSection}
            </div>
          )}
          
          <input
            id={inputId}
            className={cn(
              inputVariants({ variant, inputSize, state: inputState }),
              leftSection && "pl-10",
              rightSection && "pr-10",
              className
            )}
            ref={ref}
            {...props}
          />
          
          {rightSection && (
            <div className="absolute right-3 top-1/2 transform -translate-y-1/2 text-gray-500">
              {rightSection}
            </div>
          )}
        </div>
        
        {error && (
          <p className="text-sm text-red-600 flex items-center">
            <svg className="w-4 h-4 mr-1" fill="currentColor" viewBox="0 0 20 20">
              <path fillRule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-9a1 1 0 00-1 1v4a1 1 0 102 0V6a1 1 0 00-1-1z" clipRule="evenodd" />
            </svg>
            {error}
          </p>
        )}
        
        {success && (
          <p className="text-sm text-green-600 flex items-center">
            <svg className="w-4 h-4 mr-1" fill="currentColor" viewBox="0 0 20 20">
              <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
            </svg>
            {success}
          </p>
        )}
      </div>
    )
  }
)
Input.displayName = "Input"

export { Input, inputVariants }
```

### **Navigation Components**

#### **Enhanced Tabs Component**
```typescript
// components/ui/tabs-enhanced.tsx
import * as React from "react"
import * as TabsPrimitive from "@radix-ui/react-tabs"
import { cva, type VariantProps } from "class-variance-authority"
import { cn } from "@/lib/utils"

const tabsListVariants = cva(
  "inline-flex items-center justify-center rounded-md text-muted-foreground",
  {
    variants: {
      variant: {
        default: "bg-muted p-1",
        mantine: [
          "bg-transparent border-b border-gray-200",
          "rounded-none p-0 space-x-8"
        ],
        antd: [
          "bg-transparent border-b border-gray-200",
          "rounded-none p-0"
        ]
      }
    },
    defaultVariants: {
      variant: "default"
    }
  }
)

const tabsTriggerVariants = cva(
  [
    "inline-flex items-center justify-center whitespace-nowrap rounded-sm",
    "px-3 py-1.5 text-sm font-medium ring-offset-background",
    "transition-all focus-visible:outline-none focus-visible:ring-2",
    "focus-visible:ring-ring focus-visible:ring-offset-2",
    "disabled:pointer-events-none disabled:opacity-50"
  ],
  {
    variants: {
      variant: {
        default: [
          "data-[state=active]:bg-background data-[state=active]:text-foreground",
          "data-[state=active]:shadow-sm"
        ],
        mantine: [
          "rounded-none border-b-2 border-transparent px-4 py-3",
          "data-[state=active]:border-blue-500 data-[state=active]:text-blue-600",
          "hover:text-blue-600 hover:border-blue-300 transition-colors"
        ],
        antd: [
          "rounded-none border-b-2 border-transparent px-4 py-3",
          "data-[state=active]:border-blue-500 data-[state=active]:text-blue-600",
          "hover:text-blue-600 transition-colors"
        ]
      }
    },
    defaultVariants: {
      variant: "default"
    }
  }
)

const tabsContentVariants = cva(
  "ring-offset-background focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2",
  {
    variants: {
      variant: {
        default: "mt-2",
        mantine: "mt-4 pt-4",
        antd: "mt-4 pt-6"
      }
    },
    defaultVariants: {
      variant: "default"
    }
  }
)

interface TabsProps
  extends React.ComponentPropsWithoutRef<typeof TabsPrimitive.Root>,
    VariantProps<typeof tabsListVariants> {}

const Tabs = React.forwardRef<
  React.ElementRef<typeof TabsPrimitive.Root>,
  TabsProps
>(({ variant, ...props }, ref) => (
  <TabsPrimitive.Root ref={ref} {...props} />
))
Tabs.displayName = TabsPrimitive.Root.displayName

interface TabsListProps
  extends React.ComponentPropsWithoutRef<typeof TabsPrimitive.List>,
    VariantProps<typeof tabsListVariants> {}

const TabsList = React.forwardRef<
  React.ElementRef<typeof TabsPrimitive.List>,
  TabsListProps
>(({ className, variant, ...props }, ref) => (
  <TabsPrimitive.List
    ref={ref}
    className={cn(tabsListVariants({ variant }), className)}
    {...props}
  />
))
TabsList.displayName = TabsPrimitive.List.displayName

interface TabsTriggerProps
  extends React.ComponentPropsWithoutRef<typeof TabsPrimitive.Trigger>,
    VariantProps<typeof tabsTriggerVariants> {}

const TabsTrigger = React.forwardRef<
  React.ElementRef<typeof TabsPrimitive.Trigger>,
  TabsTriggerProps
>(({ className, variant, ...props }, ref) => (
  <TabsPrimitive.Trigger
    ref={ref}
    className={cn(tabsTriggerVariants({ variant }), className)}
    {...props}
  />
))
TabsTrigger.displayName = TabsPrimitive.Trigger.displayName

interface TabsContentProps
  extends React.ComponentPropsWithoutRef<typeof TabsPrimitive.Content>,
    VariantProps<typeof tabsContentVariants> {}

const TabsContent = React.forwardRef<
  React.ElementRef<typeof TabsPrimitive.Content>,
  TabsContentProps
>(({ className, variant, ...props }, ref) => (
  <TabsPrimitive.Content
    ref={ref}
    className={cn(tabsContentVariants({ variant }), className)}
    {...props}
  />
))
TabsContent.displayName = TabsPrimitive.Content.displayName

export { Tabs, TabsList, TabsTrigger, TabsContent }
```

#### **Tabs Usage Examples**
```tsx
// Default shadcn/ui tabs
<Tabs defaultValue="tab1">
  <TabsList>
    <TabsTrigger value="tab1">Tab 1</TabsTrigger>
    <TabsTrigger value="tab2">Tab 2</TabsTrigger>
  </TabsList>
  <TabsContent value="tab1">Content 1</TabsContent>
  <TabsContent value="tab2">Content 2</TabsContent>
</Tabs>

// Mantine-style tabs
<Tabs defaultValue="overview">
  <TabsList variant="mantine">
    <TabsTrigger variant="mantine" value="overview">Overview</TabsTrigger>
    <TabsTrigger variant="mantine" value="analytics">Analytics</TabsTrigger>
    <TabsTrigger variant="mantine" value="reports">Reports</TabsTrigger>
  </TabsList>
  <TabsContent variant="mantine" value="overview">
    <Card variant="mantine">
      <CardContent>Overview content</CardContent>
    </Card>
  </TabsContent>
</Tabs>

// Ant Design-style tabs
<Tabs defaultValue="details">
  <TabsList variant="antd">
    <TabsTrigger variant="antd" value="details">Details</TabsTrigger>
    <TabsTrigger variant="antd" value="settings">Settings</TabsTrigger>
  </TabsList>
  <TabsContent variant="antd" value="details">
    Professional content layout
  </TabsContent>
</Tabs>
```

---

## 🔗 Navigation

**Previous**: [Styling Extraction Methods](./styling-extraction-methods.md)  
**Next**: [Template Examples](./template-examples.md)

---

*Last updated: [Current Date] | Customization strategies version: 1.0*