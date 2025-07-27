# UI Component Strategies in Open Source React/Next.js Projects

## 🎯 Overview

This document analyzes UI component architectures, design system implementations, and styling strategies across production-ready open source React and Next.js applications. It examines how successful projects organize components, implement design systems, and maintain visual consistency at scale.

## 🎨 Component Architecture Landscape

### UI Library Adoption (2024)

| Approach | Adoption Rate | Maintenance | Flexibility | Learning Curve |
|----------|---------------|-------------|-------------|----------------|
| **Tailwind CSS + shadcn/ui** | 45% | Low | High | ⭐⭐ |
| **Tailwind CSS + Custom Components** | 35% | Medium | High | ⭐⭐⭐ |
| **Custom Design System** | 15% | High | Maximum | ⭐⭐⭐⭐ |
| **Material-UI/Mantine** | 3% | Low | Medium | ⭐⭐ |
| **Chakra UI** | 2% | Low | Medium | ⭐⭐ |

### The shadcn/ui Revolution

**Why shadcn/ui is gaining massive adoption**:
- ✅ Copy-paste components (no package dependency)
- ✅ Built on Radix UI primitives (accessibility)
- ✅ Tailwind CSS integration
- ✅ TypeScript-first approach
- ✅ Customizable and extensible
- ✅ Consistent design tokens

## 🏗️ Component Organization Patterns

### 1. Atomic Design Structure

**Used in**: Cal.com, Supabase Dashboard

```
src/components/
├── ui/                    # Atoms - Basic building blocks
│   ├── button.tsx
│   ├── input.tsx
│   ├── card.tsx
│   ├── badge.tsx
│   └── avatar.tsx
├── forms/                 # Molecules - Form components
│   ├── login-form.tsx
│   ├── user-form.tsx
│   └── search-input.tsx
├── layout/                # Organisms - Layout components
│   ├── header.tsx
│   ├── sidebar.tsx
│   ├── footer.tsx
│   └── navigation.tsx
├── features/              # Templates - Feature-specific components
│   ├── auth/
│   ├── dashboard/
│   └── profile/
└── pages/                 # Pages - Full page components
    ├── dashboard-page.tsx
    └── profile-page.tsx
```

### 2. Feature-Based Component Organization

**Used in**: Plane, Dub

```
src/
├── components/
│   ├── ui/                # Shared UI components
│   └── layout/            # Layout components
├── features/
│   ├── auth/
│   │   ├── components/    # Auth-specific components
│   │   │   ├── login-form.tsx
│   │   │   ├── signup-form.tsx
│   │   │   └── auth-guard.tsx
│   │   ├── hooks/
│   │   └── types/
│   ├── dashboard/
│   │   ├── components/
│   │   │   ├── dashboard-stats.tsx
│   │   │   ├── recent-activity.tsx
│   │   │   └── quick-actions.tsx
│   │   └── hooks/
│   └── projects/
│       ├── components/
│       │   ├── project-card.tsx
│       │   ├── project-list.tsx
│       │   └── project-form.tsx
│       └── hooks/
```

## 🎨 Design System Implementation

### 1. shadcn/ui Based Design System

**Used in**: Dub, Novel, modern applications

```typescript
// lib/utils.ts - Utility functions
import { type ClassValue, clsx } from "clsx";
import { twMerge } from "tailwind-merge";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

// components/ui/button.tsx - Base button component
import * as React from "react";
import { Slot } from "@radix-ui/react-slot";
import { cva, type VariantProps } from "class-variance-authority";
import { cn } from "@/lib/utils";

const buttonVariants = cva(
  // Base styles
  "inline-flex items-center justify-center whitespace-nowrap rounded-md text-sm font-medium ring-offset-background transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:pointer-events-none disabled:opacity-50",
  {
    variants: {
      variant: {
        default: "bg-primary text-primary-foreground hover:bg-primary/90",
        destructive: "bg-destructive text-destructive-foreground hover:bg-destructive/90",
        outline: "border border-input bg-background hover:bg-accent hover:text-accent-foreground",
        secondary: "bg-secondary text-secondary-foreground hover:bg-secondary/80",
        ghost: "hover:bg-accent hover:text-accent-foreground",
        link: "text-primary underline-offset-4 hover:underline",
      },
      size: {
        default: "h-10 px-4 py-2",
        sm: "h-9 rounded-md px-3",
        lg: "h-11 rounded-md px-8",
        icon: "h-10 w-10",
      },
    },
    defaultVariants: {
      variant: "default",
      size: "default",
    },
  }
);

export interface ButtonProps
  extends React.ButtonHTMLAttributes<HTMLButtonElement>,
    VariantProps<typeof buttonVariants> {
  asChild?: boolean;
}

const Button = React.forwardRef<HTMLButtonElement, ButtonProps>(
  ({ className, variant, size, asChild = false, ...props }, ref) => {
    const Comp = asChild ? Slot : "button";
    return (
      <Comp
        className={cn(buttonVariants({ variant, size, className }))}
        ref={ref}
        {...props}
      />
    );
  }
);
Button.displayName = "Button";

export { Button, buttonVariants };
```

### 2. Custom Design System with Tokens

**Used in**: Cal.com, enterprise applications

```typescript
// design-system/tokens.ts - Design tokens
export const tokens = {
  colors: {
    primary: {
      50: "#eff6ff",
      100: "#dbeafe",
      500: "#3b82f6",
      600: "#2563eb",
      900: "#1e3a8a",
    },
    gray: {
      50: "#f9fafb",
      100: "#f3f4f6",
      500: "#6b7280",
      900: "#111827",
    },
    semantic: {
      success: "#10b981",
      warning: "#f59e0b",
      error: "#ef4444",
      info: "#3b82f6",
    },
  },
  spacing: {
    xs: "0.25rem",
    sm: "0.5rem",
    md: "1rem",
    lg: "1.5rem",
    xl: "2rem",
    "2xl": "3rem",
  },
  typography: {
    fontFamily: {
      sans: ["Inter", "system-ui", "sans-serif"],
      mono: ["JetBrains Mono", "monospace"],
    },
    fontSize: {
      xs: ["0.75rem", { lineHeight: "1rem" }],
      sm: ["0.875rem", { lineHeight: "1.25rem" }],
      base: ["1rem", { lineHeight: "1.5rem" }],
      lg: ["1.125rem", { lineHeight: "1.75rem" }],
      xl: ["1.25rem", { lineHeight: "1.75rem" }],
    },
  },
  borderRadius: {
    none: "0",
    sm: "0.125rem",
    base: "0.25rem",
    md: "0.375rem",
    lg: "0.5rem",
    full: "9999px",
  },
} as const;

// design-system/components/Button.tsx - Token-based component
import { cva } from "class-variance-authority";
import { tokens } from "../tokens";

const buttonStyles = cva(
  [
    "inline-flex items-center justify-center",
    "font-medium transition-colors",
    "focus:outline-none focus:ring-2 focus:ring-offset-2",
    "disabled:opacity-50 disabled:pointer-events-none",
  ],
  {
    variants: {
      variant: {
        primary: [
          "bg-primary-500 text-white",
          "hover:bg-primary-600",
          "focus:ring-primary-500",
        ],
        secondary: [
          "bg-gray-100 text-gray-900",
          "hover:bg-gray-200",
          "focus:ring-gray-500",
        ],
        outline: [
          "border border-gray-300 bg-white text-gray-700",
          "hover:bg-gray-50",
          "focus:ring-primary-500",
        ],
      },
      size: {
        sm: ["text-sm px-3 py-1.5", `rounded-${tokens.borderRadius.sm}`],
        md: ["text-base px-4 py-2", `rounded-${tokens.borderRadius.md}`],
        lg: ["text-lg px-6 py-3", `rounded-${tokens.borderRadius.lg}`],
      },
    },
    defaultVariants: {
      variant: "primary",
      size: "md",
    },
  }
);

interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: "primary" | "secondary" | "outline";
  size?: "sm" | "md" | "lg";
  isLoading?: boolean;
  leftIcon?: React.ReactNode;
  rightIcon?: React.ReactNode;
}

export function Button({
  variant,
  size,
  isLoading,
  leftIcon,
  rightIcon,
  children,
  className,
  disabled,
  ...props
}: ButtonProps) {
  return (
    <button
      className={cn(buttonStyles({ variant, size }), className)}
      disabled={disabled || isLoading}
      {...props}
    >
      {isLoading ? (
        <Spinner className="mr-2" />
      ) : (
        leftIcon && <span className="mr-2">{leftIcon}</span>
      )}
      {children}
      {rightIcon && <span className="ml-2">{rightIcon}</span>}
    </button>
  );
}
```

### 3. Compound Component Pattern

**Used in**: Advanced design systems

```typescript
// components/ui/dropdown.tsx - Compound component pattern
import { createContext, useContext, useState } from "react";

// Context for sharing state
interface DropdownContextType {
  isOpen: boolean;
  toggle: () => void;
  close: () => void;
}

const DropdownContext = createContext<DropdownContextType | null>(null);

function useDropdownContext() {
  const context = useContext(DropdownContext);
  if (!context) {
    throw new Error("Dropdown components must be used within Dropdown");
  }
  return context;
}

// Main compound component
interface DropdownProps {
  children: React.ReactNode;
  onOpenChange?: (open: boolean) => void;
}

function Dropdown({ children, onOpenChange }: DropdownProps) {
  const [isOpen, setIsOpen] = useState(false);

  const toggle = () => {
    const newState = !isOpen;
    setIsOpen(newState);
    onOpenChange?.(newState);
  };

  const close = () => {
    setIsOpen(false);
    onOpenChange?.(false);
  };

  return (
    <DropdownContext.Provider value={{ isOpen, toggle, close }}>
      <div className="relative inline-block text-left">
        {children}
      </div>
    </DropdownContext.Provider>
  );
}

// Sub-components
function DropdownTrigger({ children, asChild }: { children: React.ReactNode; asChild?: boolean }) {
  const { toggle } = useDropdownContext();

  if (asChild) {
    return React.cloneElement(children as React.ReactElement, {
      onClick: toggle,
    });
  }

  return (
    <button onClick={toggle} className="dropdown-trigger">
      {children}
    </button>
  );
}

function DropdownContent({ children, align = "left" }: { children: React.ReactNode; align?: "left" | "right" }) {
  const { isOpen, close } = useDropdownContext();

  if (!isOpen) return null;

  return (
    <>
      <div className="fixed inset-0 z-10" onClick={close} />
      <div
        className={cn(
          "absolute z-20 mt-2 w-56 rounded-md bg-white shadow-lg ring-1 ring-black ring-opacity-5",
          align === "right" ? "right-0" : "left-0"
        )}
      >
        <div className="py-1">{children}</div>
      </div>
    </>
  );
}

function DropdownItem({ children, onClick }: { children: React.ReactNode; onClick?: () => void }) {
  const { close } = useDropdownContext();

  const handleClick = () => {
    onClick?.();
    close();
  };

  return (
    <button
      className="block w-full px-4 py-2 text-left text-sm text-gray-700 hover:bg-gray-100"
      onClick={handleClick}
    >
      {children}
    </button>
  );
}

// Attach sub-components to main component
Dropdown.Trigger = DropdownTrigger;
Dropdown.Content = DropdownContent;
Dropdown.Item = DropdownItem;

export { Dropdown };

// Usage
function UserMenu() {
  return (
    <Dropdown>
      <Dropdown.Trigger asChild>
        <Button variant="ghost">
          <Avatar src={user.avatar} />
        </Button>
      </Dropdown.Trigger>
      <Dropdown.Content align="right">
        <Dropdown.Item onClick={() => router.push('/profile')}>
          Profile
        </Dropdown.Item>
        <Dropdown.Item onClick={() => router.push('/settings')}>
          Settings
        </Dropdown.Item>
        <Dropdown.Item onClick={handleSignOut}>
          Sign Out
        </Dropdown.Item>
      </Dropdown.Content>
    </Dropdown>
  );
}
```

## 📱 Responsive Design Patterns

### 1. Container Query Pattern

**Used in**: Modern responsive applications

```typescript
// components/ui/responsive-card.tsx
import { cn } from "@/lib/utils";

interface ResponsiveCardProps {
  children: React.ReactNode;
  className?: string;
}

export function ResponsiveCard({ children, className }: ResponsiveCardProps) {
  return (
    <div
      className={cn(
        // Container queries for responsive behavior
        "@container/card rounded-lg border bg-card text-card-foreground shadow-sm",
        className
      )}
    >
      <div className="@xs/card:p-4 @sm/card:p-6 @md/card:p-8 p-3">
        {children}
      </div>
    </div>
  );
}

// components/dashboard/stats-grid.tsx
export function StatsGrid({ stats }: { stats: Stat[] }) {
  return (
    <div className="@container">
      <div className="grid @xs:grid-cols-2 @lg:grid-cols-3 @xl:grid-cols-4 gap-4">
        {stats.map((stat) => (
          <ResponsiveCard key={stat.id}>
            <StatCard stat={stat} />
          </ResponsiveCard>
        ))}
      </div>
    </div>
  );
}
```

### 2. Adaptive Layout Components

**Used in**: Supabase Dashboard, responsive interfaces

```typescript
// components/layout/adaptive-layout.tsx
import { useBreakpoint } from "@/hooks/use-breakpoint";

interface AdaptiveLayoutProps {
  sidebar: React.ReactNode;
  main: React.ReactNode;
  header?: React.ReactNode;
}

export function AdaptiveLayout({ sidebar, main, header }: AdaptiveLayoutProps) {
  const { isMobile, isTablet } = useBreakpoint();

  if (isMobile) {
    return <MobileLayout sidebar={sidebar} main={main} header={header} />;
  }

  if (isTablet) {
    return <TabletLayout sidebar={sidebar} main={main} header={header} />;
  }

  return <DesktopLayout sidebar={sidebar} main={main} header={header} />;
}

// Mobile layout with drawer
function MobileLayout({ sidebar, main, header }: AdaptiveLayoutProps) {
  const [sidebarOpen, setSidebarOpen] = useState(false);

  return (
    <div className="h-screen flex flex-col">
      {header && (
        <header className="border-b bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60">
          <div className="flex h-14 items-center px-4">
            <Button
              variant="ghost"
              size="icon"
              onClick={() => setSidebarOpen(true)}
            >
              <MenuIcon />
            </Button>
            {header}
          </div>
        </header>
      )}
      
      <div className="flex-1 overflow-hidden">
        <main className="h-full overflow-auto p-4">
          {main}
        </main>
      </div>

      {/* Mobile drawer */}
      <Sheet open={sidebarOpen} onOpenChange={setSidebarOpen}>
        <SheetContent side="left" className="w-72">
          {sidebar}
        </SheetContent>
      </Sheet>
    </div>
  );
}

// Desktop layout with persistent sidebar
function DesktopLayout({ sidebar, main, header }: AdaptiveLayoutProps) {
  return (
    <div className="h-screen flex">
      <aside className="w-64 border-r bg-background/95 backdrop-blur">
        {sidebar}
      </aside>
      
      <div className="flex-1 flex flex-col">
        {header && (
          <header className="border-b bg-background/95 backdrop-blur h-14 flex items-center px-6">
            {header}
          </header>
        )}
        
        <main className="flex-1 overflow-auto p-6">
          {main}
        </main>
      </div>
    </div>
  );
}
```

## 🎭 Animation and Interaction Patterns

### 1. Framer Motion Integration

**Used in**: Novel, interactive applications

```typescript
// components/ui/animated-card.tsx
import { motion, AnimatePresence } from "framer-motion";

interface AnimatedCardProps {
  children: React.ReactNode;
  isVisible?: boolean;
  delay?: number;
}

export function AnimatedCard({ children, isVisible = true, delay = 0 }: AnimatedCardProps) {
  return (
    <AnimatePresence>
      {isVisible && (
        <motion.div
          initial={{ opacity: 0, y: 20, scale: 0.95 }}
          animate={{ opacity: 1, y: 0, scale: 1 }}
          exit={{ opacity: 0, y: -20, scale: 0.95 }}
          transition={{
            duration: 0.3,
            delay,
            ease: [0.22, 1, 0.36, 1], // Custom easing
          }}
          className="card"
        >
          {children}
        </motion.div>
      )}
    </AnimatePresence>
  );
}

// components/dashboard/animated-list.tsx
export function AnimatedList({ items }: { items: any[] }) {
  return (
    <div className="space-y-2">
      {items.map((item, index) => (
        <AnimatedCard key={item.id} delay={index * 0.1}>
          <ItemCard item={item} />
        </AnimatedCard>
      ))}
    </div>
  );
}

// Page transitions
export function PageTransition({ children }: { children: React.ReactNode }) {
  return (
    <motion.div
      initial={{ opacity: 0, x: 20 }}
      animate={{ opacity: 1, x: 0 }}
      exit={{ opacity: 0, x: -20 }}
      transition={{ duration: 0.3 }}
    >
      {children}
    </motion.div>
  );
}
```

### 2. CSS-Based Animations

**Used in**: Performance-critical applications

```typescript
// styles/animations.css
@keyframes slideIn {
  from {
    opacity: 0;
    transform: translateX(-10px);
  }
  to {
    opacity: 1;
    transform: translateX(0);
  }
}

@keyframes fadeIn {
  from { opacity: 0; }
  to { opacity: 1; }
}

@keyframes pulse {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.5; }
}

.animate-slide-in {
  animation: slideIn 0.3s ease-out;
}

.animate-fade-in {
  animation: fadeIn 0.2s ease-out;
}

.animate-pulse {
  animation: pulse 2s cubic-bezier(0.4, 0, 0.6, 1) infinite;
}

// components/ui/skeleton.tsx
export function Skeleton({ className }: { className?: string }) {
  return (
    <div
      className={cn(
        "animate-pulse rounded-md bg-muted",
        className
      )}
    />
  );
}

// Usage
function LoadingCard() {
  return (
    <div className="p-4 space-y-3">
      <Skeleton className="h-4 w-[250px]" />
      <Skeleton className="h-4 w-[200px]" />
      <Skeleton className="h-4 w-[150px]" />
    </div>
  );
}
```

## 🖼️ Icon and Asset Management

### 1. SVG Icon System

**Used in**: Most modern applications

```typescript
// components/ui/icon.tsx
import { cn } from "@/lib/utils";

interface IconProps extends React.SVGProps<SVGSVGElement> {
  name: string;
  size?: number;
}

// Icon registry
const icons = {
  chevronDown: (props: React.SVGProps<SVGSVGElement>) => (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" {...props}>
      <polyline points="6,9 12,15 18,9" />
    </svg>
  ),
  user: (props: React.SVGProps<SVGSVGElement>) => (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" {...props}>
      <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2" />
      <circle cx="12" cy="7" r="4" />
    </svg>
  ),
  settings: (props: React.SVGProps<SVGSVGElement>) => (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" {...props}>
      <circle cx="12" cy="12" r="3" />
      <path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1 1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z" />
    </svg>
  ),
} as const;

export function Icon({ name, size = 24, className, ...props }: IconProps) {
  const IconComponent = icons[name as keyof typeof icons];
  
  if (!IconComponent) {
    console.warn(`Icon "${name}" not found`);
    return null;
  }

  return (
    <IconComponent
      className={cn("inline-block", className)}
      width={size}
      height={size}
      {...props}
    />
  );
}

// Type-safe icon names
export type IconName = keyof typeof icons;

// Usage
function UserMenu() {
  return (
    <div>
      <Icon name="user" className="mr-2" />
      <span>Profile</span>
      <Icon name="chevronDown" size={16} />
    </div>
  );
}
```

### 2. Lucide React Integration

**Used in**: shadcn/ui applications

```typescript
// components/ui/icon-button.tsx
import { LucideIcon } from "lucide-react";
import { Button, ButtonProps } from "./button";

interface IconButtonProps extends Omit<ButtonProps, "children"> {
  icon: LucideIcon;
  label: string;
  iconSize?: number;
}

export function IconButton({ 
  icon: Icon, 
  label, 
  iconSize = 16, 
  ...props 
}: IconButtonProps) {
  return (
    <Button {...props} aria-label={label}>
      <Icon size={iconSize} />
    </Button>
  );
}

// Usage with Lucide icons
import { Settings, User, ChevronDown } from "lucide-react";

function Toolbar() {
  return (
    <div className="flex gap-2">
      <IconButton 
        icon={Settings} 
        label="Settings" 
        variant="ghost" 
        size="sm"
      />
      <IconButton 
        icon={User} 
        label="Profile" 
        variant="ghost" 
        size="sm"
      />
    </div>
  );
}
```

## 🔧 Component Development Tools

### 1. Storybook Integration

```typescript
// stories/Button.stories.tsx
import type { Meta, StoryObj } from '@storybook/react';
import { Button } from '@/components/ui/button';

const meta: Meta<typeof Button> = {
  title: 'UI/Button',
  component: Button,
  parameters: {
    layout: 'centered',
  },
  tags: ['autodocs'],
  argTypes: {
    variant: {
      control: { type: 'select' },
      options: ['default', 'destructive', 'outline', 'secondary', 'ghost', 'link'],
    },
    size: {
      control: { type: 'select' },
      options: ['default', 'sm', 'lg', 'icon'],
    },
  },
};

export default meta;
type Story = StoryObj<typeof meta>;

export const Primary: Story = {
  args: {
    children: 'Button',
    variant: 'default',
  },
};

export const Secondary: Story = {
  args: {
    children: 'Button',
    variant: 'secondary',
  },
};

export const Outline: Story = {
  args: {
    children: 'Button',
    variant: 'outline',
  },
};

export const WithIcon: Story = {
  args: {
    children: (
      <>
        <Icon name="user" className="mr-2" />
        Button with Icon
      </>
    ),
  },
};
```

### 2. Component Testing

```typescript
// __tests__/Button.test.tsx
import { render, screen, fireEvent } from '@testing-library/react';
import { Button } from '@/components/ui/button';

describe('Button', () => {
  it('renders correctly', () => {
    render(<Button>Click me</Button>);
    expect(screen.getByRole('button', { name: /click me/i })).toBeInTheDocument();
  });

  it('applies variant styles', () => {
    render(<Button variant="destructive">Delete</Button>);
    const button = screen.getByRole('button');
    expect(button).toHaveClass('bg-destructive');
  });

  it('handles click events', () => {
    const handleClick = jest.fn();
    render(<Button onClick={handleClick}>Click me</Button>);
    
    fireEvent.click(screen.getByRole('button'));
    expect(handleClick).toHaveBeenCalledTimes(1);
  });

  it('disables when loading', () => {
    render(<Button disabled>Loading</Button>);
    const button = screen.getByRole('button');
    expect(button).toBeDisabled();
    expect(button).toHaveClass('opacity-50');
  });
});
```

## 📊 Performance Optimization

### 1. Component Lazy Loading

```typescript
// components/lazy-components.tsx
import { lazy, Suspense } from 'react';

// Lazy load heavy components
const DataVisualization = lazy(() => import('./DataVisualization'));
const RichTextEditor = lazy(() => import('./RichTextEditor'));
const VideoPlayer = lazy(() => import('./VideoPlayer'));

// Loading wrapper
function LazyComponent({ 
  component: Component, 
  fallback = <ComponentSkeleton />,
  ...props 
}: {
  component: React.ComponentType<any>;
  fallback?: React.ReactNode;
  [key: string]: any;
}) {
  return (
    <Suspense fallback={fallback}>
      <Component {...props} />
    </Suspense>
  );
}

// Usage
function Dashboard() {
  const [showChart, setShowChart] = useState(false);

  return (
    <div>
      <h1>Dashboard</h1>
      
      {showChart && (
        <LazyComponent 
          component={DataVisualization}
          fallback={<ChartSkeleton />}
          data={chartData}
        />
      )}
      
      <Button onClick={() => setShowChart(true)}>
        Show Chart
      </Button>
    </div>
  );
}
```

### 2. Virtualization for Large Lists

```typescript
// components/ui/virtual-list.tsx
import { FixedSizeList as List } from 'react-window';

interface VirtualListProps<T> {
  items: T[];
  height: number;
  itemHeight: number;
  renderItem: (item: T, index: number) => React.ReactNode;
}

export function VirtualList<T>({ 
  items, 
  height, 
  itemHeight, 
  renderItem 
}: VirtualListProps<T>) {
  const Row = ({ index, style }: { index: number; style: React.CSSProperties }) => (
    <div style={style}>
      {renderItem(items[index], index)}
    </div>
  );

  return (
    <List
      height={height}
      itemCount={items.length}
      itemSize={itemHeight}
      className="virtual-list"
    >
      {Row}
    </List>
  );
}

// Usage
function UserList({ users }: { users: User[] }) {
  return (
    <VirtualList
      items={users}
      height={400}
      itemHeight={60}
      renderItem={(user, index) => (
        <UserCard key={user.id} user={user} />
      )}
    />
  );
}
```

## 🎯 Component Strategy Recommendations

### By Application Size

**Small Applications** (< 20 components):
- Use shadcn/ui components directly
- Minimal customization
- Focus on rapid development

**Medium Applications** (20-100 components):
- Build on shadcn/ui foundation
- Create custom variants and compositions
- Implement basic design tokens

**Large Applications** (100+ components):
- Custom design system with tokens
- Component library with Storybook
- Automated testing and documentation
- Design system team and governance

### By Team Size

**Solo Developer**:
- shadcn/ui + minimal customization
- Copy-paste approach for speed

**Small Team** (2-5 developers):
- shadcn/ui + shared component library
- Basic documentation and patterns

**Large Team** (5+ developers):
- Full design system implementation
- Component library with strict guidelines
- Design tokens and automated testing
- Design system team

The key to successful UI component strategy is starting simple and evolving based on your application's needs and team structure. shadcn/ui provides an excellent foundation that can grow with your project.