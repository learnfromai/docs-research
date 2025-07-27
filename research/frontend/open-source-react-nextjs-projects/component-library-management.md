# Component Library Management in Open Source React/Next.js Projects

## Overview

This comprehensive analysis examines how successful open source React and Next.js projects organize, manage, and scale their UI component libraries. The research covers design system architecture, component composition patterns, theming strategies, and maintenance approaches from production applications.

## Design System Architecture Patterns

### 1. Atomic Design Implementation

**Mantine - Comprehensive Component Library**

Mantine demonstrates a sophisticated atomic design system with over 120 components organized in a hierarchical structure.

```typescript
// Component hierarchy structure
src/
├── core/                    # Atomic components
│   ├── Button/
│   ├── Input/
│   ├── Text/
│   └── Paper/
├── dates/                   # Date-related molecules
│   ├── Calendar/
│   ├── DatePicker/
│   └── TimeInput/
├── dropzone/               # File upload organisms
├── notifications/          # Notification system
├── spotlight/             # Command palette
└── modals/               # Modal management

// Component API design pattern
interface ButtonProps extends React.ComponentPropsWithoutRef<'button'> {
  /** Button content */
  children?: React.ReactNode;
  
  /** Controls button appearance */
  variant?: 'filled' | 'light' | 'outline' | 'subtle' | 'default';
  
  /** Button size */
  size?: 'xs' | 'sm' | 'md' | 'lg' | 'xl';
  
  /** Button color from theme */
  color?: MantineColor;
  
  /** Controls button width */
  fullWidth?: boolean;
  
  /** Controls gradient settings */
  gradient?: MantineGradient;
  
  /** Controls loading state */
  loading?: boolean;
  
  /** Left section of button */
  leftSection?: React.ReactNode;
  
  /** Right section of button */
  rightSection?: React.ReactNode;
}

export const Button = polymorphicFactory<'button', ButtonProps>((props, ref) => {
  const {
    variant = 'filled',
    size = 'sm',
    color,
    fullWidth,
    gradient,
    loading,
    leftSection,
    rightSection,
    children,
    className,
    style,
    vars,
    ...others
  } = useProps('Button', defaultProps, props);

  const theme = useMantineTheme();
  const classes = useStyles();
  
  return (
    <UnstyledButton
      ref={ref}
      className={clsx(classes.root, className)}
      data-loading={loading || undefined}
      data-variant={variant}
      data-size={size}
      style={[
        {
          '--button-gradient': gradient ? `linear-gradient(${gradient.deg}deg, ${gradient.from} 0%, ${gradient.to} 100%)` : undefined,
        },
        style,
      ]}
      vars={getButtonVars(theme, { color, size, variant })}
      {...others}
    >
      {leftSection && <span className={classes.section}>{leftSection}</span>}
      <span className={classes.label}>{children}</span>
      {rightSection && <span className={classes.section}>{rightSection}</span>}
      {loading && <Loader className={classes.loader} size={getLoaderSize(size)} />}
    </UnstyledButton>
  );
});
```

**Key Mantine Patterns:**
- **Polymorphic components** with `as` prop for flexible element rendering
- **Consistent API design** across all components
- **CSS-in-JS with CSS variables** for theming
- **Comprehensive TypeScript support** with strict typing
- **Modular architecture** allowing tree-shaking

### 2. Primitive-Based Component Systems

**Cal.com - Radix UI Composition**

Cal.com builds sophisticated components by composing Radix UI primitives with custom styling.

```typescript
// Compound component pattern using Radix primitives
import * as Dialog from '@radix-ui/react-dialog';
import * as DropdownMenu from '@radix-ui/react-dropdown-menu';
import { cn } from '@/lib/utils';

// Base Dialog composition
const Modal = Dialog.Root;
const ModalTrigger = Dialog.Trigger;

const ModalContent = React.forwardRef<
  React.ElementRef<typeof Dialog.Content>,
  React.ComponentPropsWithoutRef<typeof Dialog.Content>
>(({ className, children, ...props }, ref) => (
  <Dialog.Portal>
    <Dialog.Overlay className="fixed inset-0 z-50 bg-background/80 backdrop-blur-sm" />
    <Dialog.Content
      ref={ref}
      className={cn(
        "fixed left-[50%] top-[50%] z-50 grid w-full max-w-lg translate-x-[-50%] translate-y-[-50%] gap-4 border bg-background p-6 shadow-lg duration-200",
        "data-[state=open]:animate-in data-[state=closed]:animate-out",
        "data-[state=closed]:fade-out-0 data-[state=open]:fade-in-0",
        "data-[state=closed]:zoom-out-95 data-[state=open]:zoom-in-95",
        "data-[state=closed]:slide-out-to-left-1/2 data-[state=closed]:slide-out-to-top-[48%]",
        "data-[state=open]:slide-in-from-left-1/2 data-[state=open]:slide-in-from-top-[48%]",
        "sm:rounded-lg md:w-full",
        className
      )}
      {...props}
    >
      {children}
    </Dialog.Content>
  </Dialog.Portal>
));

const ModalHeader = ({ className, ...props }: React.HTMLAttributes<HTMLDivElement>) => (
  <div className={cn("flex flex-col space-y-1.5 text-center sm:text-left", className)} {...props} />
);

const ModalTitle = React.forwardRef<
  React.ElementRef<typeof Dialog.Title>,
  React.ComponentPropsWithoutRef<typeof Dialog.Title>
>(({ className, ...props }, ref) => (
  <Dialog.Title
    ref={ref}
    className={cn("text-lg font-semibold leading-none tracking-tight", className)}
    {...props}
  />
));

const ModalDescription = React.forwardRef<
  React.ElementRef<typeof Dialog.Description>,
  React.ComponentPropsWithoutRef<typeof Dialog.Description>
>(({ className, ...props }, ref) => (
  <Dialog.Description
    ref={ref}
    className={cn("text-sm text-muted-foreground", className)}
    {...props}
  />
));

const ModalFooter = ({ className, ...props }: React.HTMLAttributes<HTMLDivElement>) => (
  <div className={cn("flex flex-col-reverse sm:flex-row sm:justify-end sm:space-x-2", className)} {...props} />
);

// Export as compound component
export {
  Modal,
  ModalTrigger,
  ModalContent,
  ModalHeader,
  ModalTitle,
  ModalDescription,
  ModalFooter,
};

// Usage pattern
function BookingModal() {
  return (
    <Modal>
      <ModalTrigger asChild>
        <Button>Book Appointment</Button>
      </ModalTrigger>
      <ModalContent>
        <ModalHeader>
          <ModalTitle>Schedule Appointment</ModalTitle>
          <ModalDescription>
            Choose your preferred time slot for the appointment.
          </ModalDescription>
        </ModalHeader>
        <BookingForm />
        <ModalFooter>
          <Button variant="outline">Cancel</Button>
          <Button>Confirm Booking</Button>
        </ModalFooter>
      </ModalContent>
    </Modal>
  );
}
```

### 3. Theme-First Component Design

**Chakra UI - Style Props System**

Chakra UI demonstrates a theme-first approach where components accept style props directly.

```typescript
// Theme configuration
const theme = {
  colors: {
    brand: {
      50: '#f7fafc',
      100: '#edf2f7',
      500: '#4299e1',
      900: '#1a365d',
    },
  },
  components: {
    Button: {
      baseStyle: {
        fontWeight: 'bold',
        textTransform: 'uppercase',
        borderRadius: 'base',
      },
      sizes: {
        sm: {
          fontSize: 'sm',
          px: 4,
          py: 3,
        },
        md: {
          fontSize: 'md',
          px: 6,
          py: 4,
        },
      },
      variants: {
        solid: (props) => ({
          bg: `${props.colorScheme}.500`,
          color: 'white',
          _hover: {
            bg: `${props.colorScheme}.600`,
          },
        }),
        outline: (props) => ({
          border: '2px solid',
          borderColor: `${props.colorScheme}.500`,
          color: `${props.colorScheme}.500`,
        }),
      },
      defaultProps: {
        size: 'md',
        variant: 'solid',
        colorScheme: 'brand',
      },
    },
  },
};

// Component with style props
interface ButtonProps extends ChakraButtonProps {
  /** Loading state */
  isLoading?: boolean;
  /** Loading text */
  loadingText?: string;
  /** Left icon */
  leftIcon?: React.ReactElement;
  /** Right icon */
  rightIcon?: React.ReactElement;
}

const Button = forwardRef<ButtonProps, 'button'>((props, ref) => {
  const {
    isLoading,
    loadingText,
    leftIcon,
    rightIcon,
    children,
    ...rest
  } = props;

  return (
    <ChakraButton
      ref={ref}
      isLoading={isLoading}
      loadingText={loadingText}
      leftIcon={leftIcon}
      rightIcon={rightIcon}
      {...rest}
    >
      {children}
    </ChakraButton>
  );
});

// Usage with style props
function Example() {
  return (
    <Button
      colorScheme="brand"
      size="lg"
      bg="brand.500"
      color="white"
      _hover={{ bg: 'brand.600' }}
      _active={{ bg: 'brand.700' }}
      px={8}
      py={4}
      borderRadius="md"
      boxShadow="lg"
    >
      Click me
    </Button>
  );
}
```

## Component Organization Strategies

### 1. Feature-Based Organization

**Plane - Feature-Driven Component Structure**

Plane organizes components by feature domains, making it easier to maintain and locate related functionality.

```typescript
// Feature-based component organization
src/components/
├── ui/                     # Base UI components
│   ├── Button/
│   ├── Input/
│   ├── Modal/
│   └── index.ts
├── forms/                  # Form-related components
│   ├── LoginForm/
│   ├── ProjectForm/
│   └── index.ts
├── layout/                 # Layout components
│   ├── Sidebar/
│   ├── Header/
│   ├── AppLayout/
│   └── index.ts
├── projects/               # Project feature components
│   ├── ProjectCard/
│   ├── ProjectList/
│   ├── ProjectSettings/
│   └── index.ts
├── issues/                 # Issue management components
│   ├── IssueCard/
│   ├── IssueBoard/
│   ├── IssueFilters/
│   └── index.ts
└── common/                 # Shared components
    ├── LoadingSpinner/
    ├── ErrorBoundary/
    └── index.ts

// Barrel export pattern for clean imports
// components/ui/index.ts
export { Button } from './Button';
export { Input } from './Input';
export { Modal } from './Modal';
export type { ButtonProps, InputProps, ModalProps } from './types';

// Usage
import { Button, Input } from '@/components/ui';
import { ProjectCard } from '@/components/projects';
```

### 2. Layered Component Architecture

**Storybook - Tool Component Layers**

Storybook demonstrates a sophisticated layered architecture for complex tool development.

```typescript
// Layered component architecture
src/components/
├── primitives/             # Base HTML-like components
│   ├── Box/
│   ├── Flex/
│   ├── Text/
│   └── Icon/
├── controls/               # Interactive controls
│   ├── Button/
│   ├── Input/
│   ├── Select/
│   └── Slider/
├── patterns/               # Common UI patterns
│   ├── SearchBox/
│   ├── Toolbar/
│   ├── Tabs/
│   └── Tree/
├── containers/             # Complex containers
│   ├── Panel/
│   ├── Preview/
│   ├── Sidebar/
│   └── Canvas/
└── features/               # Feature-specific components
    ├── Stories/
    ├── Addons/
    ├── Controls/
    └── Documentation/

// Layered component composition
const StoryPanel = ({ story, controls, documentation }) => (
  <Panel>
    <Toolbar>
      <SearchBox placeholder="Search stories..." />
      <Button variant="primary">Run</Button>
    </Toolbar>
    <Flex direction="column">
      <Preview story={story} />
      <Tabs>
        <Tab label="Controls">
          <Controls data={controls} />
        </Tab>
        <Tab label="Docs">
          <Documentation content={documentation} />
        </Tab>
      </Tabs>
    </Flex>
  </Panel>
);
```

## Theming and Customization Patterns

### 1. CSS Variables + Tailwind Approach

**Vercel Commerce - Design Token System**

Vercel Commerce uses CSS variables combined with Tailwind CSS for flexible theming.

```css
/* styles/globals.css */
:root {
  /* Color tokens */
  --primary: 0 0% 9%;
  --primary-foreground: 0 0% 98%;
  --secondary: 0 0% 96%;
  --secondary-foreground: 0 0% 9%;
  --muted: 0 0% 96%;
  --muted-foreground: 0 0% 45%;
  --accent: 0 0% 96%;
  --accent-foreground: 0 0% 9%;
  --destructive: 0 84% 60%;
  --destructive-foreground: 0 0% 98%;
  --border: 0 0% 90%;
  --input: 0 0% 90%;
  --ring: 0 0% 9%;
  
  /* Spacing tokens */
  --radius: 0.5rem;
  --spacing-xs: 0.25rem;
  --spacing-sm: 0.5rem;
  --spacing-md: 1rem;
  --spacing-lg: 1.5rem;
  --spacing-xl: 3rem;
}

.dark {
  --primary: 0 0% 98%;
  --primary-foreground: 0 0% 9%;
  --secondary: 0 0% 15%;
  --secondary-foreground: 0 0% 98%;
  /* ... other dark mode tokens */
}
```

```typescript
// tailwind.config.js
module.exports = {
  theme: {
    extend: {
      colors: {
        border: 'hsl(var(--border))',
        input: 'hsl(var(--input))',
        ring: 'hsl(var(--ring))',
        background: 'hsl(var(--background))',
        foreground: 'hsl(var(--foreground))',
        primary: {
          DEFAULT: 'hsl(var(--primary))',
          foreground: 'hsl(var(--primary-foreground))',
        },
        secondary: {
          DEFAULT: 'hsl(var(--secondary))',
          foreground: 'hsl(var(--secondary-foreground))',
        },
      },
      borderRadius: {
        lg: 'var(--radius)',
        md: 'calc(var(--radius) - 2px)',
        sm: 'calc(var(--radius) - 4px)',
      },
    },
  },
};

// Theme provider component
interface ThemeProviderProps {
  children: React.ReactNode;
  defaultTheme?: string;
  storageKey?: string;
}

export function ThemeProvider({
  children,
  defaultTheme = 'light',
  storageKey = 'theme',
}: ThemeProviderProps) {
  const [theme, setTheme] = useState<string>(defaultTheme);

  useEffect(() => {
    const savedTheme = localStorage.getItem(storageKey);
    if (savedTheme) {
      setTheme(savedTheme);
    }
  }, [storageKey]);

  useEffect(() => {
    const root = window.document.documentElement;
    root.classList.remove('light', 'dark');
    root.classList.add(theme);
  }, [theme]);

  const value = {
    theme,
    setTheme: (theme: string) => {
      localStorage.setItem(storageKey, theme);
      setTheme(theme);
    },
  };

  return (
    <ThemeContext.Provider value={value}>
      {children}
    </ThemeContext.Provider>
  );
}
```

### 2. Runtime Theme System

**React Flow - Dynamic Theme Configuration**

React Flow implements a runtime theme system for complex visualization components.

```typescript
// Theme configuration system
interface FlowTheme {
  colorMode: 'light' | 'dark';
  colors: {
    primary: string;
    secondary: string;
    background: string;
    text: string;
    border: string;
    node: {
      default: string;
      selected: string;
      error: string;
    };
    edge: {
      default: string;
      selected: string;
      animated: string;
    };
  };
  spacing: {
    xs: number;
    sm: number;
    md: number;
    lg: number;
    xl: number;
  };
  borderRadius: {
    sm: number;
    md: number;
    lg: number;
  };
  shadows: {
    sm: string;
    md: string;
    lg: string;
  };
}

const lightTheme: FlowTheme = {
  colorMode: 'light',
  colors: {
    primary: '#1a192b',
    secondary: '#2d3748',
    background: '#ffffff',
    text: '#2d3748',
    border: '#e2e8f0',
    node: {
      default: '#ffffff',
      selected: '#e53e3e',
      error: '#f56565',
    },
    edge: {
      default: '#b7b7b7',
      selected: '#e53e3e',
      animated: '#3182ce',
    },
  },
  spacing: {
    xs: 4,
    sm: 8,
    md: 16,
    lg: 24,
    xl: 32,
  },
  borderRadius: {
    sm: 4,
    md: 8,
    lg: 12,
  },
  shadows: {
    sm: '0 1px 3px rgba(0, 0, 0, 0.1)',
    md: '0 4px 6px rgba(0, 0, 0, 0.1)',
    lg: '0 10px 15px rgba(0, 0, 0, 0.1)',
  },
};

// Theme provider with runtime switching
export function FlowThemeProvider({ children, theme = lightTheme }: FlowThemeProviderProps) {
  const themeVars = useMemo(() => ({
    '--flow-primary': theme.colors.primary,
    '--flow-secondary': theme.colors.secondary,
    '--flow-background': theme.colors.background,
    '--flow-text': theme.colors.text,
    '--flow-border': theme.colors.border,
    '--flow-node-default': theme.colors.node.default,
    '--flow-node-selected': theme.colors.node.selected,
    '--flow-edge-default': theme.colors.edge.default,
    '--flow-edge-selected': theme.colors.edge.selected,
    '--flow-spacing-sm': `${theme.spacing.sm}px`,
    '--flow-spacing-md': `${theme.spacing.md}px`,
    '--flow-border-radius': `${theme.borderRadius.md}px`,
  }), [theme]);

  return (
    <div style={themeVars} className="flow-theme-provider">
      <FlowThemeContext.Provider value={theme}>
        {children}
      </FlowThemeContext.Provider>
    </div>
  );
}

// Component using theme
const FlowNode = ({ data, selected }) => {
  const theme = useFlowTheme();
  
  return (
    <div
      style={{
        backgroundColor: selected ? theme.colors.node.selected : theme.colors.node.default,
        border: `2px solid ${selected ? theme.colors.primary : theme.colors.border}`,
        borderRadius: theme.borderRadius.md,
        padding: theme.spacing.md,
        boxShadow: selected ? theme.shadows.md : theme.shadows.sm,
      }}
    >
      {data.label}
    </div>
  );
};
```

## Component Testing Strategies

### 1. Component Library Testing

**Mantine - Comprehensive Component Testing**

```typescript
// Button.test.tsx
import { render, screen, userEvent } from '@testing-library/react';
import { MantineProvider } from '@mantine/core';
import { Button } from './Button';

const TestWrapper = ({ children }: { children: React.ReactNode }) => (
  <MantineProvider>{children}</MantineProvider>
);

describe('Button Component', () => {
  it('renders correctly', () => {
    render(<Button>Click me</Button>, { wrapper: TestWrapper });
    expect(screen.getByRole('button', { name: 'Click me' })).toBeInTheDocument();
  });

  it('applies variant styles correctly', () => {
    render(<Button variant="outline">Outline Button</Button>, { wrapper: TestWrapper });
    const button = screen.getByRole('button');
    expect(button).toHaveAttribute('data-variant', 'outline');
  });

  it('handles loading state', () => {
    render(<Button loading>Loading Button</Button>, { wrapper: TestWrapper });
    const button = screen.getByRole('button');
    expect(button).toHaveAttribute('data-loading');
    expect(screen.getByRole('presentation')).toBeInTheDocument(); // Loader
  });

  it('supports polymorphic rendering', () => {
    render(
      <Button component="a" href="/test">
        Link Button
      </Button>,
      { wrapper: TestWrapper }
    );
    expect(screen.getByRole('link')).toHaveAttribute('href', '/test');
  });

  it('handles click events', async () => {
    const handleClick = vi.fn();
    render(<Button onClick={handleClick}>Click me</Button>, { wrapper: TestWrapper });
    
    await userEvent.click(screen.getByRole('button'));
    expect(handleClick).toHaveBeenCalledTimes(1);
  });

  it('supports accessibility features', () => {
    render(
      <Button aria-label="Close dialog" aria-describedby="help-text">
        ×
      </Button>,
      { wrapper: TestWrapper }
    );
    
    const button = screen.getByRole('button');
    expect(button).toHaveAttribute('aria-label', 'Close dialog');
    expect(button).toHaveAttribute('aria-describedby', 'help-text');
  });
});

// Visual regression testing with Storybook
// Button.stories.tsx
export default {
  title: 'Components/Button',
  component: Button,
  parameters: {
    docs: {
      description: {
        component: 'Button component with multiple variants and sizes',
      },
    },
  },
  argTypes: {
    variant: {
      control: { type: 'select' },
      options: ['filled', 'light', 'outline', 'subtle'],
    },
    size: {
      control: { type: 'select' },
      options: ['xs', 'sm', 'md', 'lg', 'xl'],
    },
  },
} as Meta<typeof Button>;

export const Default: Story<ButtonProps> = {
  args: {
    children: 'Button',
  },
};

export const AllVariants: Story = {
  render: () => (
    <div style={{ display: 'flex', gap: 16 }}>
      <Button variant="filled">Filled</Button>
      <Button variant="light">Light</Button>
      <Button variant="outline">Outline</Button>
      <Button variant="subtle">Subtle</Button>
    </div>
  ),
};

export const WithIcons: Story = {
  render: () => (
    <div style={{ display: 'flex', gap: 16 }}>
      <Button leftSection={<PlusIcon />}>Add Item</Button>
      <Button rightSection={<ArrowRightIcon />}>Continue</Button>
    </div>
  ),
};

export const LoadingStates: Story = {
  render: () => (
    <div style={{ display: 'flex', gap: 16 }}>
      <Button loading>Loading</Button>
      <Button loading loadingText="Saving...">Save</Button>
    </div>
  ),
};
```

### 2. Accessibility Testing

**Automated Accessibility Testing**:

```typescript
// accessibility.test.tsx
import { render } from '@testing-library/react';
import { axe, toHaveNoViolations } from 'jest-axe';
import { Button } from './Button';

expect.extend(toHaveNoViolations);

describe('Button Accessibility', () => {
  it('should not have accessibility violations', async () => {
    const { container } = render(<Button>Click me</Button>);
    const results = await axe(container);
    expect(results).toHaveNoViolations();
  });

  it('supports keyboard navigation', async () => {
    render(<Button>Focusable Button</Button>);
    const button = screen.getByRole('button');
    
    button.focus();
    expect(button).toHaveFocus();
    
    await userEvent.keyboard('{Enter}');
    expect(handleClick).toHaveBeenCalled();
  });

  it('announces loading state to screen readers', () => {
    render(<Button loading aria-label="Save document">Save</Button>);
    const button = screen.getByRole('button');
    expect(button).toHaveAttribute('aria-busy', 'true');
  });
});
```

## Documentation and Storybook Integration

### 1. Interactive Documentation

**Storybook Configuration for Component Libraries**:

```typescript
// .storybook/main.ts
import type { StorybookConfig } from '@storybook/react-vite';

const config: StorybookConfig = {
  stories: ['../src/**/*.stories.@(js|jsx|ts|tsx|mdx)'],
  addons: [
    '@storybook/addon-essentials',
    '@storybook/addon-interactions',
    '@storybook/addon-a11y',
    '@storybook/addon-design-tokens',
    '@storybook/addon-docs',
  ],
  framework: {
    name: '@storybook/react-vite',
    options: {},
  },
  features: {
    buildStoriesJson: true,
  },
  docs: {
    autodocs: 'tag',
  },
};

export default config;

// Component documentation with MDX
// Button.stories.mdx
import { Meta, Story, Canvas, ArgsTable } from '@storybook/addon-docs';
import { Button } from './Button';

<Meta title="Components/Button" component={Button} />

# Button

The Button component is a fundamental interactive element used throughout the application.

## Usage

<Canvas>
  <Story name="Basic">
    <Button>Click me</Button>
  </Story>
</Canvas>

## API

<ArgsTable of={Button} />

## Examples

### Variants

<Canvas>
  <Story name="Variants">
    <div style={{ display: 'flex', gap: 16 }}>
      <Button variant="primary">Primary</Button>
      <Button variant="secondary">Secondary</Button>
      <Button variant="outline">Outline</Button>
    </div>
  </Story>
</Canvas>

### Sizes

<Canvas>
  <Story name="Sizes">
    <div style={{ display: 'flex', gap: 16, alignItems: 'center' }}>
      <Button size="sm">Small</Button>
      <Button size="md">Medium</Button>
      <Button size="lg">Large</Button>
    </div>
  </Story>
</Canvas>

## Accessibility

- Supports keyboard navigation
- Proper ARIA attributes
- Focus management
- Screen reader announcements
```

## Component Library Maintenance

### 1. Version Management and Breaking Changes

```typescript
// CHANGELOG.md structure
## [2.0.0] - 2024-01-15

### Breaking Changes
- **Button**: Removed deprecated `color` prop, use `variant` instead
- **Input**: Changed default size from `md` to `sm`
- **Modal**: Renamed `isOpen` to `open` for consistency

### Added
- **Button**: New `loading` prop with built-in spinner
- **Input**: Added `error` state styling
- **Toast**: New notification component

### Fixed
- **Button**: Fixed focus ring in Safari
- **Modal**: Fixed scroll lock on mobile
- **Input**: Fixed placeholder color in dark mode

### Migration Guide

#### Button Component
```typescript
// Before (v1.x)
<Button color="primary" variant="solid">Click me</Button>

// After (v2.x)
<Button variant="primary">Click me</Button>
```

// Release automation script
// scripts/release.js
const { execSync } = require('child_process');
const semver = require('semver');
const packageJson = require('../package.json');

function release(type = 'patch') {
  const currentVersion = packageJson.version;
  const newVersion = semver.inc(currentVersion, type);
  
  console.log(`Releasing version ${newVersion}...`);
  
  // Run tests
  execSync('npm run test', { stdio: 'inherit' });
  
  // Build components
  execSync('npm run build', { stdio: 'inherit' });
  
  // Update version
  execSync(`npm version ${newVersion}`, { stdio: 'inherit' });
  
  // Build Storybook
  execSync('npm run build-storybook', { stdio: 'inherit' });
  
  // Publish to npm
  execSync('npm publish', { stdio: 'inherit' });
  
  // Create git tag
  execSync(`git tag v${newVersion}`, { stdio: 'inherit' });
  execSync('git push --tags', { stdio: 'inherit' });
  
  console.log(`Successfully released version ${newVersion}!`);
}

module.exports = { release };
```

### 2. Performance Monitoring

```typescript
// Component performance monitoring
// utils/performance.ts
export function measureComponentRender(componentName: string) {
  return function <P extends {}>(Component: React.ComponentType<P>) {
    return React.forwardRef<any, P>((props, ref) => {
      const renderStart = performance.now();
      
      useEffect(() => {
        const renderEnd = performance.now();
        const renderTime = renderEnd - renderStart;
        
        if (renderTime > 16) { // > 1 frame at 60fps
          console.warn(`Slow render detected: ${componentName} took ${renderTime.toFixed(2)}ms`);
        }
        
        // Send to analytics
        if (window.gtag) {
          window.gtag('event', 'component_render', {
            component_name: componentName,
            render_time: renderTime,
          });
        }
      });
      
      return <Component ref={ref} {...props} />;
    });
  };
}

// Usage
export const Button = measureComponentRender('Button')(ButtonComponent);

// Bundle size monitoring
// scripts/analyze-bundle.js
const { BundleAnalyzerPlugin } = require('webpack-bundle-analyzer');
const fs = require('fs');

function analyzeBundleSize() {
  const stats = JSON.parse(fs.readFileSync('./dist/stats.json', 'utf8'));
  const componentSizes = {};
  
  stats.modules.forEach(module => {
    if (module.name.includes('/components/')) {
      const componentName = module.name.split('/components/')[1].split('/')[0];
      componentSizes[componentName] = (componentSizes[componentName] || 0) + module.size;
    }
  });
  
  // Alert on size increases
  Object.entries(componentSizes).forEach(([component, size]) => {
    if (size > 50000) { // 50KB threshold
      console.warn(`Large component detected: ${component} is ${(size / 1024).toFixed(2)}KB`);
    }
  });
  
  return componentSizes;
}
```

## Comparison: Component Library Approaches

| Approach | Pros | Cons | Best For |
|----------|------|------|----------|
| **Atomic Design (Mantine)** | Clear hierarchy, Comprehensive, Great TypeScript | Learning curve, Large bundle | Design systems, Enterprise |
| **Primitive Composition (Cal.com)** | Flexible, Small bundle, Accessible | More setup, Manual composition | Custom designs, Performance-critical |
| **Style Props (Chakra)** | Quick prototyping, Consistent API | Runtime overhead, Large HTML | Rapid development, Consistent designs |
| **CSS Variables (Vercel)** | Performance, SSR-friendly, Small bundle | Limited runtime theming | Production apps, Performance-first |

---

## Navigation

- ← Back to: [Authentication Strategies](authentication-strategies.md)
- → Next: [API Integration Patterns](api-integration-patterns.md)
- 🏠 Home: [Research Overview](../../README.md)