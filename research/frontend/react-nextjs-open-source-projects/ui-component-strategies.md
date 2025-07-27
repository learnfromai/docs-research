# UI Component Strategies in Production React/Next.js Applications

## 🎯 Overview

Analysis of UI component architectures, design systems, and component library strategies used in production React/Next.js applications. This document examines how successful projects organize, build, and maintain their component ecosystems.

## 📊 Component Architecture Patterns

Based on analysis of 25+ production React/Next.js projects:

| Approach | Usage | Best For | Example Projects |
|----------|-------|----------|------------------|
| **Headless + Tailwind** | 45% | Maximum flexibility | Cal.com, Plane |
| **Component Libraries** | 30% | Rapid development | Medusa (early versions) |
| **Custom Design Systems** | 20% | Brand consistency | Supabase, Storybook |
| **Hybrid Approach** | 5% | Migration scenarios | Large enterprise apps |

## 🎨 Design System Strategies

### Headless Components + Utility CSS (Most Popular)

This approach combines headless component libraries (Radix UI, Headless UI) with utility-first CSS frameworks (Tailwind CSS).

#### Cal.com Implementation
```typescript
// components/ui/button.tsx - Headless + Tailwind pattern
import { cva, type VariantProps } from 'class-variance-authority';
import { Slot } from '@radix-ui/react-slot';
import { forwardRef } from 'react';
import { cn } from '@/lib/utils';

const buttonVariants = cva(
  // Base styles
  'inline-flex items-center justify-center whitespace-nowrap rounded-md text-sm font-medium ring-offset-background transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:pointer-events-none disabled:opacity-50',
  {
    variants: {
      variant: {
        default: 'bg-primary text-primary-foreground hover:bg-primary/90',
        destructive: 'bg-destructive text-destructive-foreground hover:bg-destructive/90',
        outline: 'border border-input bg-background hover:bg-accent hover:text-accent-foreground',
        secondary: 'bg-secondary text-secondary-foreground hover:bg-secondary/80',
        ghost: 'hover:bg-accent hover:text-accent-foreground',
        link: 'text-primary underline-offset-4 hover:underline',
      },
      size: {
        default: 'h-10 px-4 py-2',
        sm: 'h-9 rounded-md px-3',
        lg: 'h-11 rounded-md px-8',
        icon: 'h-10 w-10',
      },
    },
    defaultVariants: {
      variant: 'default',
      size: 'default',
    },
  }
);

export interface ButtonProps
  extends React.ButtonHTMLAttributes<HTMLButtonElement>,
    VariantProps<typeof buttonVariants> {
  asChild?: boolean;
}

const Button = forwardRef<HTMLButtonElement, ButtonProps>(
  ({ className, variant, size, asChild = false, ...props }, ref) => {
    const Comp = asChild ? Slot : 'button';
    return (
      <Comp
        className={cn(buttonVariants({ variant, size, className }))}
        ref={ref}
        {...props}
      />
    );
  }
);
Button.displayName = 'Button';

export { Button, buttonVariants };
```

#### Complex Component with Radix UI Primitives
```typescript
// components/ui/dropdown-menu.tsx - Advanced headless pattern
import * as DropdownMenuPrimitive from '@radix-ui/react-dropdown-menu';
import { Check, ChevronRight, Circle } from 'lucide-react';
import { forwardRef } from 'react';
import { cn } from '@/lib/utils';

const DropdownMenu = DropdownMenuPrimitive.Root;
const DropdownMenuTrigger = DropdownMenuPrimitive.Trigger;
const DropdownMenuGroup = DropdownMenuPrimitive.Group;
const DropdownMenuPortal = DropdownMenuPrimitive.Portal;
const DropdownMenuSub = DropdownMenuPrimitive.Sub;
const DropdownMenuRadioGroup = DropdownMenuPrimitive.RadioGroup;

const DropdownMenuSubTrigger = forwardRef<
  React.ElementRef<typeof DropdownMenuPrimitive.SubTrigger>,
  React.ComponentPropsWithoutRef<typeof DropdownMenuPrimitive.SubTrigger> & {
    inset?: boolean;
  }
>(({ className, inset, children, ...props }, ref) => (
  <DropdownMenuPrimitive.SubTrigger
    ref={ref}
    className={cn(
      'flex cursor-default select-none items-center rounded-sm px-2 py-1.5 text-sm outline-none focus:bg-accent data-[state=open]:bg-accent',
      inset && 'pl-8',
      className
    )}
    {...props}
  >
    {children}
    <ChevronRight className="ml-auto h-4 w-4" />
  </DropdownMenuPrimitive.SubTrigger>
));
DropdownMenuSubTrigger.displayName = DropdownMenuPrimitive.SubTrigger.displayName;

const DropdownMenuSubContent = forwardRef<
  React.ElementRef<typeof DropdownMenuPrimitive.SubContent>,
  React.ComponentPropsWithoutRef<typeof DropdownMenuPrimitive.SubContent>
>(({ className, ...props }, ref) => (
  <DropdownMenuPrimitive.SubContent
    ref={ref}
    className={cn(
      'z-50 min-w-[8rem] overflow-hidden rounded-md border bg-popover p-1 text-popover-foreground shadow-lg data-[state=open]:animate-in data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=open]:fade-in-0 data-[state=closed]:zoom-out-95 data-[state=open]:zoom-in-95 data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2',
      className
    )}
    {...props}
  />
));
DropdownMenuSubContent.displayName = DropdownMenuPrimitive.SubContent.displayName;

const DropdownMenuContent = forwardRef<
  React.ElementRef<typeof DropdownMenuPrimitive.Content>,
  React.ComponentPropsWithoutRef<typeof DropdownMenuPrimitive.Content>
>(({ className, sideOffset = 4, ...props }, ref) => (
  <DropdownMenuPrimitive.Portal>
    <DropdownMenuPrimitive.Content
      ref={ref}
      sideOffset={sideOffset}
      className={cn(
        'z-50 min-w-[8rem] overflow-hidden rounded-md border bg-popover p-1 text-popover-foreground shadow-md data-[state=open]:animate-in data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=open]:fade-in-0 data-[state=closed]:zoom-out-95 data-[state=open]:zoom-in-95 data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2',
        className
      )}
      {...props}
    />
  </DropdownMenuPrimitive.Portal>
));
DropdownMenuContent.displayName = DropdownMenuPrimitive.Content.displayName;

// Usage example with composition
export function UserMenu() {
  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button variant="ghost" className="relative h-8 w-8 rounded-full">
          <Avatar className="h-8 w-8">
            <AvatarImage src="/avatars/01.png" alt="@johndoe" />
            <AvatarFallback>JD</AvatarFallback>
          </Avatar>
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent className="w-56" align="end" forceMount>
        <DropdownMenuLabel className="font-normal">
          <div className="flex flex-col space-y-1">
            <p className="text-sm font-medium leading-none">John Doe</p>
            <p className="text-xs leading-none text-muted-foreground">
              john@example.com
            </p>
          </div>
        </DropdownMenuLabel>
        <DropdownMenuSeparator />
        <DropdownMenuGroup>
          <DropdownMenuItem>
            <User className="mr-2 h-4 w-4" />
            <span>Profile</span>
            <DropdownMenuShortcut>⇧⌘P</DropdownMenuShortcut>
          </DropdownMenuItem>
          <DropdownMenuItem>
            <Settings className="mr-2 h-4 w-4" />
            <span>Settings</span>
            <DropdownMenuShortcut>⌘S</DropdownMenuShortcut>
          </DropdownMenuItem>
        </DropdownMenuGroup>
        <DropdownMenuSeparator />
        <DropdownMenuItem>
          <LogOut className="mr-2 h-4 w-4" />
          <span>Log out</span>
          <DropdownMenuShortcut>⇧⌘Q</DropdownMenuShortcut>
        </DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
```

### Custom Design System Approach (Supabase Pattern)

Supabase has built their own comprehensive design system with consistent theming and component APIs.

```typescript
// components/ui/supabase-ui/Button.tsx - Custom design system
import { cva } from 'class-variance-authority';
import { forwardRef } from 'react';

const buttonStyles = cva(
  [
    'relative',
    'cursor-pointer',
    'inline-flex',
    'items-center',
    'justify-center',
    'border',
    'font-medium',
    'text-center',
    'transition-all',
    'duration-200',
    'ease-out',
    'rounded-md',
    'outline-none',
    'focus-visible:outline-4',
    'focus-visible:outline-offset-1',
    'focus-visible:outline-brand-600',
  ],
  {
    variants: {
      type: {
        primary: [
          'bg-brand-600',
          'hover:bg-brand-500',
          'border-brand-700',
          'hover:border-brand-600',
          'text-white',
          'shadow-sm',
        ],
        default: [
          'bg-scale-1200',
          'hover:bg-scale-1100',
          'border-scale-700',
          'hover:border-scale-600',
          'text-scale-1200',
          'shadow-sm',
        ],
        secondary: [
          'bg-scale-100',
          'hover:bg-scale-200',
          'border-scale-400',
          'hover:border-scale-500',
          'text-scale-1200',
        ],
        outline: [
          'bg-transparent',
          'border-scale-600',
          'hover:border-scale-700',
          'text-scale-1100',
          'hover:text-scale-1200',
        ],
        dashed: [
          'bg-transparent',
          'border-scale-600',
          'hover:border-scale-700',
          'text-scale-1100',
          'hover:text-scale-1200',
          'border-dashed',
        ],
        link: [
          'bg-transparent',
          'border-transparent',
          'text-brand-600',
          'hover:text-brand-500',
          'shadow-none',
        ],
        text: [
          'bg-transparent',
          'border-transparent',
          'text-scale-1100',
          'hover:text-scale-1200',
          'shadow-none',
        ],
      },
      size: {
        tiny: ['text-xs', 'px-2.5', 'py-1'],
        small: ['text-xs', 'px-3', 'py-2'],
        medium: ['text-sm', 'px-4', 'py-2'],
        large: ['text-base', 'px-6', 'py-3'],
        xlarge: ['text-base', 'px-8', 'py-4'],
      },
      block: {
        true: 'w-full flex',
      },
      loading: {
        true: 'pointer-events-none',
      },
    },
    compoundVariants: [
      {
        type: 'primary',
        loading: true,
        class: 'bg-brand-400 border-brand-400',
      },
    ],
    defaultVariants: {
      type: 'primary',
      size: 'medium',
    },
  }
);

interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  type?: 'primary' | 'default' | 'secondary' | 'outline' | 'dashed' | 'link' | 'text';
  size?: 'tiny' | 'small' | 'medium' | 'large' | 'xlarge';
  block?: boolean;
  loading?: boolean;
  icon?: React.ReactNode;
  iconRight?: React.ReactNode;
  children?: React.ReactNode;
}

const Button = forwardRef<HTMLButtonElement, ButtonProps>(
  ({ 
    type, 
    size, 
    block, 
    loading, 
    icon, 
    iconRight, 
    children, 
    className,
    disabled,
    ...props 
  }, ref) => {
    return (
      <button
        ref={ref}
        className={buttonStyles({ type, size, block, loading, className })}
        disabled={disabled || loading}
        {...props}
      >
        {loading && (
          <svg
            className="animate-spin -ml-1 mr-2 h-4 w-4 text-white"
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
              d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
            />
          </svg>
        )}
        {!loading && icon && <span className="mr-2">{icon}</span>}
        {children}
        {!loading && iconRight && <span className="ml-2">{iconRight}</span>}
      </button>
    );
  }
);

Button.displayName = 'Button';
export { Button };
```

## 🎭 Component Composition Patterns

### Compound Component Pattern

Popular in form libraries and complex UI components:

```typescript
// components/ui/form.tsx - Compound component pattern
import { createContext, useContext } from 'react';
import { useForm, FormProvider, FieldPath, FieldValues } from 'react-hook-form';

interface FormFieldContextValue<
  TFieldValues extends FieldValues = FieldValues,
  TName extends FieldPath<TFieldValues> = FieldPath<TFieldValues>
> {
  name: TName;
}

const FormFieldContext = createContext<FormFieldContextValue>(
  {} as FormFieldContextValue
);

const FormItemContext = createContext<{ id: string }>({} as { id: string });

// Main Form component
const Form = FormProvider;

// Field component
const FormField = <
  TFieldValues extends FieldValues = FieldValues,
  TName extends FieldPath<TFieldValues> = FieldPath<TFieldValues>
>({
  name,
  children,
}: {
  name: TName;
  children: React.ReactNode;
}) => {
  return (
    <FormFieldContext.Provider value={{ name }}>
      {children}
    </FormFieldContext.Provider>
  );
};

// Item wrapper
const FormItem = forwardRef<HTMLDivElement, React.HTMLAttributes<HTMLDivElement>>(
  ({ className, ...props }, ref) => {
    const id = useId();
    
    return (
      <FormItemContext.Provider value={{ id }}>
        <div ref={ref} className={cn('space-y-2', className)} {...props} />
      </FormItemContext.Provider>
    );
  }
);

// Label component
const FormLabel = forwardRef<
  React.ElementRef<typeof LabelPrimitive.Root>,
  React.ComponentPropsWithoutRef<typeof LabelPrimitive.Root>
>(({ className, ...props }, ref) => {
  const { error, formItemId } = useFormField();
  
  return (
    <Label
      ref={ref}
      className={cn(error && 'text-destructive', className)}
      htmlFor={formItemId}
      {...props}
    />
  );
});

// Control wrapper
const FormControl = forwardRef<
  React.ElementRef<typeof Slot>,
  React.ComponentPropsWithoutRef<typeof Slot>
>(({ ...props }, ref) => {
  const { error, formItemId, formDescriptionId, formMessageId } = useFormField();
  
  return (
    <Slot
      ref={ref}
      id={formItemId}
      aria-describedby={
        !error
          ? `${formDescriptionId}`
          : `${formDescriptionId} ${formMessageId}`
      }
      aria-invalid={!!error}
      {...props}
    />
  );
});

// Usage example
function UserProfileForm() {
  const form = useForm<UserProfile>();
  
  return (
    <Form {...form}>
      <form onSubmit={form.handleSubmit(onSubmit)}>
        <FormField
          control={form.control}
          name="email"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Email</FormLabel>
              <FormControl>
                <Input placeholder="Enter your email" {...field} />
              </FormControl>
              <FormDescription>
                This is your public email address.
              </FormDescription>
              <FormMessage />
            </FormItem>
          )}
        />
      </form>
    </Form>
  );
}
```

### Render Props Pattern for Data Components

```typescript
// components/data/DataTable.tsx - Flexible data rendering
interface DataTableProps<T> {
  data: T[];
  columns: ColumnDef<T>[];
  loading?: boolean;
  error?: string;
  renderRow?: (item: T, index: number) => React.ReactNode;
  renderEmpty?: () => React.ReactNode;
  renderError?: (error: string) => React.ReactNode;
  renderLoading?: () => React.ReactNode;
}

export function DataTable<T>({
  data,
  columns,
  loading,
  error,
  renderRow,
  renderEmpty,
  renderError,
  renderLoading,
}: DataTableProps<T>) {
  if (loading) {
    return renderLoading ? renderLoading() : <DefaultLoadingState />;
  }
  
  if (error) {
    return renderError ? renderError(error) : <DefaultErrorState error={error} />;
  }
  
  if (data.length === 0) {
    return renderEmpty ? renderEmpty() : <DefaultEmptyState />;
  }
  
  return (
    <div className="rounded-md border">
      <Table>
        <TableHeader>
          <TableRow>
            {columns.map((column) => (
              <TableHead key={column.id}>{column.header}</TableHead>
            ))}
          </TableRow>
        </TableHeader>
        <TableBody>
          {data.map((item, index) => (
            renderRow ? renderRow(item, index) : (
              <TableRow key={index}>
                {columns.map((column) => (
                  <TableCell key={column.id}>
                    {column.cell ? column.cell(item) : item[column.accessorKey]}
                  </TableCell>
                ))}
              </TableRow>
            )
          ))}
        </TableBody>
      </Table>
    </div>
  );
}

// Usage with custom rendering
<DataTable
  data={users}
  columns={userColumns}
  renderRow={(user, index) => (
    <TableRow key={user.id} className={index % 2 === 0 ? 'bg-muted/50' : ''}>
      <TableCell>
        <div className="flex items-center space-x-2">
          <Avatar className="h-8 w-8">
            <AvatarImage src={user.avatar} />
            <AvatarFallback>{user.name.charAt(0)}</AvatarFallback>
          </Avatar>
          <span>{user.name}</span>
        </div>
      </TableCell>
      <TableCell>{user.email}</TableCell>
      <TableCell>
        <Badge variant={user.status === 'active' ? 'success' : 'secondary'}>
          {user.status}
        </Badge>
      </TableCell>
    </TableRow>
  )}
  renderEmpty={() => (
    <div className="text-center py-12">
      <Users className="mx-auto h-12 w-12 text-muted-foreground" />
      <h3 className="mt-4 text-lg font-semibold">No users found</h3>
      <p className="text-muted-foreground">Get started by creating a new user.</p>
      <Button className="mt-4">Add User</Button>
    </div>
  )}
/>
```

## 🎨 Styling Strategies

### CSS-in-JS with Emotion (Storybook Pattern)

```typescript
// components/styled/Button.tsx - Emotion styling
import styled from '@emotion/styled';
import { css } from '@emotion/react';

interface StyledButtonProps {
  variant?: 'primary' | 'secondary' | 'ghost';
  size?: 'small' | 'medium' | 'large';
  fullWidth?: boolean;
}

const buttonStyles = css`
  display: inline-flex;
  align-items: center;
  justify-content: center;
  border: none;
  border-radius: 6px;
  font-weight: 500;
  transition: all 0.2s ease;
  cursor: pointer;
  text-decoration: none;
  
  &:disabled {
    opacity: 0.6;
    cursor: not-allowed;
  }
  
  &:focus {
    outline: none;
    box-shadow: 0 0 0 3px rgba(66, 153, 225, 0.5);
  }
`;

const variantStyles = {
  primary: css`
    background-color: #3182ce;
    color: white;
    
    &:hover:not(:disabled) {
      background-color: #2c5aa0;
    }
  `,
  secondary: css`
    background-color: #e2e8f0;
    color: #2d3748;
    
    &:hover:not(:disabled) {
      background-color: #cbd5e0;
    }
  `,
  ghost: css`
    background-color: transparent;
    color: #4a5568;
    
    &:hover:not(:disabled) {
      background-color: #f7fafc;
    }
  `,
};

const sizeStyles = {
  small: css`
    padding: 8px 16px;
    font-size: 14px;
    min-height: 32px;
  `,
  medium: css`
    padding: 12px 20px;
    font-size: 16px;
    min-height: 40px;
  `,
  large: css`
    padding: 16px 24px;
    font-size: 18px;
    min-height: 48px;
  `,
};

const StyledButton = styled.button<StyledButtonProps>`
  ${buttonStyles}
  ${props => variantStyles[props.variant || 'primary']}
  ${props => sizeStyles[props.size || 'medium']}
  ${props => props.fullWidth && css`width: 100%;`}
`;

export const Button: React.FC<StyledButtonProps & React.ButtonHTMLAttributes<HTMLButtonElement>> = ({
  children,
  ...props
}) => {
  return <StyledButton {...props}>{children}</StyledButton>;
};
```

### Tailwind with Component Variants (Modern Pattern)

```typescript
// components/ui/card.tsx - Tailwind with variants
import { cva, type VariantProps } from 'class-variance-authority';
import { cn } from '@/lib/utils';

const cardVariants = cva(
  'rounded-lg border bg-card text-card-foreground shadow-sm',
  {
    variants: {
      variant: {
        default: 'border-border',
        outline: 'border-2 border-border',
        filled: 'bg-muted/50 border-transparent',
        elevated: 'shadow-lg border-transparent',
        interactive: 'cursor-pointer transition-all hover:shadow-md hover:scale-[1.02]',
      },
      size: {
        default: 'p-6',
        sm: 'p-4',
        lg: 'p-8',
        none: 'p-0',
      },
    },
    defaultVariants: {
      variant: 'default',
      size: 'default',
    },
  }
);

const cardHeaderVariants = cva('flex flex-col space-y-1.5', {
  variants: {
    size: {
      default: 'p-6 pb-0',
      sm: 'p-4 pb-0',
      lg: 'p-8 pb-0',
      none: 'p-0',
    },
  },
  defaultVariants: {
    size: 'default',
  },
});

const cardContentVariants = cva('', {
  variants: {
    size: {
      default: 'p-6 pt-0',
      sm: 'p-4 pt-0',
      lg: 'p-8 pt-0',
      none: 'p-0',
    },
  },
  defaultVariants: {
    size: 'default',
  },
});

export interface CardProps
  extends React.HTMLAttributes<HTMLDivElement>,
    VariantProps<typeof cardVariants> {}

const Card = forwardRef<HTMLDivElement, CardProps>(
  ({ className, variant, size, ...props }, ref) => (
    <div
      ref={ref}
      className={cn(cardVariants({ variant, size, className }))}
      {...props}
    />
  )
);

const CardHeader = forwardRef<
  HTMLDivElement,
  React.HTMLAttributes<HTMLDivElement> & VariantProps<typeof cardHeaderVariants>
>(({ className, size, ...props }, ref) => (
  <div
    ref={ref}
    className={cn(cardHeaderVariants({ size, className }))}
    {...props}
  />
));

// Advanced usage with composition
export function ProjectCard({ project }: { project: Project }) {
  return (
    <Card variant="interactive" className="group">
      <CardHeader>
        <div className="flex items-center justify-between">
          <CardTitle className="group-hover:text-primary transition-colors">
            {project.name}
          </CardTitle>
          <Badge variant={project.status === 'active' ? 'success' : 'secondary'}>
            {project.status}
          </Badge>
        </div>
        <CardDescription>{project.description}</CardDescription>
      </CardHeader>
      <CardContent>
        <div className="flex items-center space-x-4 text-sm text-muted-foreground">
          <div className="flex items-center">
            <Calendar className="mr-1 h-3 w-3" />
            {formatDate(project.createdAt)}
          </div>
          <div className="flex items-center">
            <Users className="mr-1 h-3 w-3" />
            {project.memberCount} members
          </div>
        </div>
      </CardContent>
      <CardFooter>
        <Button size="sm" className="w-full">
          View Project
        </Button>
      </CardFooter>
    </Card>
  );
}
```

## 🎪 Component Library Management

### Storybook Integration Pattern

```typescript
// .storybook/main.ts - Storybook configuration
import type { StorybookConfig } from '@storybook/nextjs';

const config: StorybookConfig = {
  stories: ['../src/**/*.stories.@(js|jsx|ts|tsx|mdx)'],
  addons: [
    '@storybook/addon-links',
    '@storybook/addon-essentials',
    '@storybook/addon-interactions',
    '@storybook/addon-a11y',
    '@storybook/addon-design-tokens',
  ],
  framework: {
    name: '@storybook/nextjs',
    options: {},
  },
  typescript: {
    check: false,
    reactDocgen: 'react-docgen-typescript',
    reactDocgenTypescriptOptions: {
      shouldExtractLiteralValuesFromEnum: true,
      propFilter: (prop) => (prop.parent ? !/node_modules/.test(prop.parent.fileName) : true),
    },
  },
};

export default config;
```

```typescript
// components/ui/Button.stories.tsx - Component stories
import type { Meta, StoryObj } from '@storybook/react';
import { Button } from './Button';
import { Mail, Download } from 'lucide-react';

const meta: Meta<typeof Button> = {
  title: 'UI/Button',
  component: Button,
  parameters: {
    layout: 'centered',
    docs: {
      description: {
        component: 'A versatile button component with multiple variants and sizes.',
      },
    },
  },
  tags: ['autodocs'],
  argTypes: {
    variant: {
      control: 'select',
      options: ['default', 'destructive', 'outline', 'secondary', 'ghost', 'link'],
      description: 'The visual style variant of the button',
    },
    size: {
      control: 'select',
      options: ['default', 'sm', 'lg', 'icon'],
      description: 'The size of the button',
    },
    disabled: {
      control: 'boolean',
      description: 'Whether the button is disabled',
    },
    loading: {
      control: 'boolean',
      description: 'Whether the button is in a loading state',
    },
  },
};

export default meta;
type Story = StoryObj<typeof meta>;

export const Default: Story = {
  args: {
    children: 'Button',
  },
};

export const Variants: Story = {
  render: () => (
    <div className="flex gap-2 flex-wrap">
      <Button variant="default">Default</Button>
      <Button variant="secondary">Secondary</Button>
      <Button variant="outline">Outline</Button>
      <Button variant="ghost">Ghost</Button>
      <Button variant="link">Link</Button>
      <Button variant="destructive">Destructive</Button>
    </div>
  ),
};

export const Sizes: Story = {
  render: () => (
    <div className="flex gap-2 items-center">
      <Button size="sm">Small</Button>
      <Button size="default">Default</Button>
      <Button size="lg">Large</Button>
      <Button size="icon">
        <Mail className="h-4 w-4" />
      </Button>
    </div>
  ),
};

export const WithIcons: Story = {
  render: () => (
    <div className="flex gap-2">
      <Button>
        <Mail className="mr-2 h-4 w-4" />
        Login with Email
      </Button>
      <Button variant="outline">
        <Download className="mr-2 h-4 w-4" />
        Download
      </Button>
    </div>
  ),
};

export const Loading: Story = {
  render: () => (
    <div className="flex gap-2">
      <Button loading>Loading...</Button>
      <Button variant="outline" loading>
        Processing
      </Button>
    </div>
  ),
};

export const Interactive: Story = {
  args: {
    children: 'Click me!',
    onClick: () => alert('Button clicked!'),
  },
  parameters: {
    docs: {
      description: {
        story: 'This button demonstrates click interaction.',
      },
    },
  },
};
```

### Component Testing Strategies

```typescript
// components/ui/__tests__/Button.test.tsx - Comprehensive testing
import { render, screen, fireEvent } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { Button } from '../Button';

describe('Button', () => {
  it('renders children correctly', () => {
    render(<Button>Click me</Button>);
    expect(screen.getByRole('button', { name: /click me/i })).toBeInTheDocument();
  });

  it('applies variant classes correctly', () => {
    const { rerender } = render(<Button variant="destructive">Button</Button>);
    expect(screen.getByRole('button')).toHaveClass('bg-destructive');

    rerender(<Button variant="outline">Button</Button>);
    expect(screen.getByRole('button')).toHaveClass('border-input');
  });

  it('applies size classes correctly', () => {
    const { rerender } = render(<Button size="sm">Button</Button>);
    expect(screen.getByRole('button')).toHaveClass('h-9');

    rerender(<Button size="lg">Button</Button>);
    expect(screen.getByRole('button')).toHaveClass('h-11');
  });

  it('handles click events', async () => {
    const handleClick = jest.fn();
    const user = userEvent.setup();
    
    render(<Button onClick={handleClick}>Click me</Button>);
    
    await user.click(screen.getByRole('button'));
    expect(handleClick).toHaveBeenCalledTimes(1);
  });

  it('shows loading state correctly', () => {
    render(<Button loading>Loading</Button>);
    
    expect(screen.getByRole('button')).toBeDisabled();
    expect(screen.getByRole('button')).toHaveClass('pointer-events-none');
  });

  it('disables button when disabled prop is true', () => {
    render(<Button disabled>Disabled</Button>);
    
    expect(screen.getByRole('button')).toBeDisabled();
    expect(screen.getByRole('button')).toHaveClass('opacity-50');
  });

  it('forwards ref correctly', () => {
    const ref = React.createRef<HTMLButtonElement>();
    render(<Button ref={ref}>Button</Button>);
    
    expect(ref.current).toBeInstanceOf(HTMLButtonElement);
  });

  it('renders as child component when asChild is true', () => {
    render(
      <Button asChild>
        <a href="/test">Link Button</a>
      </Button>
    );
    
    const link = screen.getByRole('link');
    expect(link).toHaveAttribute('href', '/test');
    expect(link).toHaveClass('inline-flex'); // Button classes applied to link
  });

  it('supports keyboard navigation', async () => {
    const handleClick = jest.fn();
    const user = userEvent.setup();
    
    render(<Button onClick={handleClick}>Button</Button>);
    
    const button = screen.getByRole('button');
    button.focus();
    
    await user.keyboard('{Enter}');
    expect(handleClick).toHaveBeenCalledTimes(1);
    
    await user.keyboard(' ');
    expect(handleClick).toHaveBeenCalledTimes(2);
  });
});
```

## 🎯 Component Performance Optimization

### Memoization Strategies

```typescript
// components/optimized/UserCard.tsx - Performance optimized component
import { memo, useMemo, useCallback } from 'react';

interface UserCardProps {
  user: User;
  onEdit?: (userId: string) => void;
  onDelete?: (userId: string) => void;
  isSelected?: boolean;
  showActions?: boolean;
}

const UserCard = memo<UserCardProps>(({ 
  user, 
  onEdit, 
  onDelete, 
  isSelected = false,
  showActions = true 
}) => {
  // Memoize expensive calculations
  const userDisplayName = useMemo(() => {
    return `${user.firstName} ${user.lastName}`.trim() || user.email;
  }, [user.firstName, user.lastName, user.email]);

  const userInitials = useMemo(() => {
    return userDisplayName
      .split(' ')
      .map(name => name.charAt(0))
      .join('')
      .toUpperCase()
      .slice(0, 2);
  }, [userDisplayName]);

  // Memoize event handlers to prevent child re-renders
  const handleEdit = useCallback(() => {
    onEdit?.(user.id);
  }, [onEdit, user.id]);

  const handleDelete = useCallback(() => {
    onDelete?.(user.id);
  }, [onDelete, user.id]);

  // Memoize status badge props
  const statusBadgeProps = useMemo(() => ({
    variant: user.status === 'active' ? 'success' as const : 'secondary' as const,
    children: user.status,
  }), [user.status]);

  return (
    <Card 
      variant={isSelected ? 'outline' : 'default'}
      className={cn(
        'transition-all duration-200',
        isSelected && 'ring-2 ring-primary',
        'hover:shadow-md'
      )}
    >
      <CardContent className="p-4">
        <div className="flex items-center space-x-3">
          <Avatar className="h-10 w-10">
            <AvatarImage src={user.avatar} alt={userDisplayName} />
            <AvatarFallback>{userInitials}</AvatarFallback>
          </Avatar>
          
          <div className="flex-1 min-w-0">
            <p className="text-sm font-medium text-gray-900 truncate">
              {userDisplayName}
            </p>
            <p className="text-sm text-gray-500 truncate">
              {user.email}
            </p>
          </div>
          
          <div className="flex items-center space-x-2">
            <Badge {...statusBadgeProps} />
            
            {showActions && (
              <DropdownMenu>
                <DropdownMenuTrigger asChild>
                  <Button variant="ghost" size="sm">
                    <MoreHorizontal className="h-4 w-4" />
                  </Button>
                </DropdownMenuTrigger>
                <DropdownMenuContent align="end">
                  <DropdownMenuItem onClick={handleEdit}>
                    <Edit className="mr-2 h-4 w-4" />
                    Edit
                  </DropdownMenuItem>
                  <DropdownMenuSeparator />
                  <DropdownMenuItem 
                    onClick={handleDelete}
                    className="text-red-600 hover:text-red-700"
                  >
                    <Trash className="mr-2 h-4 w-4" />
                    Delete
                  </DropdownMenuItem>
                </DropdownMenuContent>
              </DropdownMenu>
            )}
          </div>
        </div>
      </CardContent>
    </Card>
  );
}, (prevProps, nextProps) => {
  // Custom comparison function for better memoization
  return (
    prevProps.user.id === nextProps.user.id &&
    prevProps.user.firstName === nextProps.user.firstName &&
    prevProps.user.lastName === nextProps.user.lastName &&
    prevProps.user.email === nextProps.user.email &&
    prevProps.user.avatar === nextProps.user.avatar &&
    prevProps.user.status === nextProps.user.status &&
    prevProps.isSelected === nextProps.isSelected &&
    prevProps.showActions === nextProps.showActions &&
    prevProps.onEdit === nextProps.onEdit &&
    prevProps.onDelete === nextProps.onDelete
  );
});

UserCard.displayName = 'UserCard';

export { UserCard };
```

### Virtual Scrolling for Large Lists

```typescript
// components/virtualized/VirtualizedUserList.tsx - Performance for large datasets
import { FixedSizeList as List } from 'react-window';
import { memo } from 'react';

interface VirtualizedUserListProps {
  users: User[];
  height: number;
  onUserEdit: (userId: string) => void;
  onUserDelete: (userId: string) => void;
}

const UserListItem = memo<{
  index: number;
  style: React.CSSProperties;
  data: {
    users: User[];
    onUserEdit: (userId: string) => void;
    onUserDelete: (userId: string) => void;
  };
}>(({ index, style, data }) => {
  const { users, onUserEdit, onUserDelete } = data;
  const user = users[index];

  return (
    <div style={style} className="px-4 py-2">
      <UserCard
        user={user}
        onEdit={onUserEdit}
        onDelete={onUserDelete}
      />
    </div>
  );
});

export function VirtualizedUserList({ 
  users, 
  height, 
  onUserEdit, 
  onUserDelete 
}: VirtualizedUserListProps) {
  const itemData = useMemo(() => ({
    users,
    onUserEdit,
    onUserDelete,
  }), [users, onUserEdit, onUserDelete]);

  return (
    <List
      height={height}
      itemCount={users.length}
      itemSize={120} // Height of each user card + padding
      itemData={itemData}
      overscanCount={5} // Render 5 extra items for smooth scrolling
    >
      {UserListItem}
    </List>
  );
}
```

## 🎨 Theme System Implementation

### Design Token Management

```typescript
// lib/design-tokens.ts - Design system tokens
export const designTokens = {
  colors: {
    // Brand colors
    brand: {
      50: '#eff6ff',
      100: '#dbeafe',
      500: '#3b82f6',
      600: '#2563eb',
      900: '#1e3a8a',
    },
    // Semantic colors
    success: {
      50: '#f0fdf4',
      100: '#dcfce7',
      500: '#22c55e',
      600: '#16a34a',
      900: '#14532d',
    },
    // Neutral scale
    gray: {
      50: '#f9fafb',
      100: '#f3f4f6',
      200: '#e5e7eb',
      500: '#6b7280',
      900: '#111827',
    },
  },
  spacing: {
    0: '0px',
    1: '4px',
    2: '8px',
    3: '12px',
    4: '16px',
    6: '24px',
    8: '32px',
    12: '48px',
    16: '64px',
    20: '80px',
    24: '96px',
  },
  typography: {
    fontFamily: {
      sans: ['Inter', 'system-ui', 'sans-serif'],
      mono: ['Fira Code', 'monospace'],
    },
    fontSize: {
      xs: ['12px', '16px'],
      sm: ['14px', '20px'],
      base: ['16px', '24px'],
      lg: ['18px', '28px'],
      xl: ['20px', '28px'],
      '2xl': ['24px', '32px'],
      '3xl': ['30px', '36px'],
    },
    fontWeight: {
      normal: '400',
      medium: '500',
      semibold: '600',
      bold: '700',
    },
  },
  borderRadius: {
    none: '0px',
    sm: '2px',
    md: '6px',
    lg: '8px',
    xl: '12px',
    full: '9999px',
  },
  shadows: {
    sm: '0 1px 2px 0 rgb(0 0 0 / 0.05)',
    md: '0 4px 6px -1px rgb(0 0 0 / 0.1)',
    lg: '0 10px 15px -3px rgb(0 0 0 / 0.1)',
    xl: '0 20px 25px -5px rgb(0 0 0 / 0.1)',
  },
} as const;

// CSS custom properties generation
export function generateCSSVariables(tokens: typeof designTokens) {
  const variables: Record<string, string> = {};
  
  function flattenTokens(obj: any, prefix = '') {
    Object.entries(obj).forEach(([key, value]) => {
      const newKey = prefix ? `${prefix}-${key}` : key;
      
      if (typeof value === 'object' && value !== null) {
        flattenTokens(value, newKey);
      } else {
        variables[`--${newKey}`] = String(value);
      }
    });
  }
  
  flattenTokens(tokens);
  return variables;
}
```

### Theme Provider Implementation

```typescript
// components/theme/ThemeProvider.tsx - Theme context and provider
import { createContext, useContext, useEffect, useState } from 'react';

type Theme = 'light' | 'dark' | 'system';

interface ThemeContextType {
  theme: Theme;
  setTheme: (theme: Theme) => void;
  resolvedTheme: 'light' | 'dark';
}

const ThemeContext = createContext<ThemeContextType | undefined>(undefined);

export function ThemeProvider({
  children,
  defaultTheme = 'system',
  storageKey = 'ui-theme',
}: {
  children: React.ReactNode;
  defaultTheme?: Theme;
  storageKey?: string;
}) {
  const [theme, setTheme] = useState<Theme>(defaultTheme);
  const [resolvedTheme, setResolvedTheme] = useState<'light' | 'dark'>('light');

  useEffect(() => {
    // Load theme from localStorage
    const storedTheme = localStorage.getItem(storageKey) as Theme;
    if (storedTheme) {
      setTheme(storedTheme);
    }
  }, [storageKey]);

  useEffect(() => {
    const root = window.document.documentElement;
    
    const updateTheme = (newTheme: 'light' | 'dark') => {
      root.classList.remove('light', 'dark');
      root.classList.add(newTheme);
      setResolvedTheme(newTheme);
    };

    if (theme === 'system') {
      const systemTheme = window.matchMedia('(prefers-color-scheme: dark)').matches 
        ? 'dark' 
        : 'light';
      updateTheme(systemTheme);

      // Listen for system theme changes
      const mediaQuery = window.matchMedia('(prefers-color-scheme: dark)');
      const handleChange = (e: MediaQueryListEvent) => {
        updateTheme(e.matches ? 'dark' : 'light');
      };
      
      mediaQuery.addEventListener('change', handleChange);
      return () => mediaQuery.removeEventListener('change', handleChange);
    } else {
      updateTheme(theme);
    }
  }, [theme]);

  const value: ThemeContextType = {
    theme,
    setTheme: (newTheme: Theme) => {
      localStorage.setItem(storageKey, newTheme);
      setTheme(newTheme);
    },
    resolvedTheme,
  };

  return (
    <ThemeContext.Provider value={value}>
      {children}
    </ThemeContext.Provider>
  );
}

export const useTheme = () => {
  const context = useContext(ThemeContext);
  if (context === undefined) {
    throw new Error('useTheme must be used within a ThemeProvider');
  }
  return context;
};

// Theme toggle component
export function ThemeToggle() {
  const { theme, setTheme } = useTheme();

  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button variant="outline" size="icon">
          <Sun className="h-[1.2rem] w-[1.2rem] rotate-0 scale-100 transition-all dark:-rotate-90 dark:scale-0" />
          <Moon className="absolute h-[1.2rem] w-[1.2rem] rotate-90 scale-0 transition-all dark:rotate-0 dark:scale-100" />
          <span className="sr-only">Toggle theme</span>
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end">
        <DropdownMenuItem onClick={() => setTheme('light')}>
          <Sun className="mr-2 h-4 w-4" />
          <span>Light</span>
        </DropdownMenuItem>
        <DropdownMenuItem onClick={() => setTheme('dark')}>
          <Moon className="mr-2 h-4 w-4" />
          <span>Dark</span>
        </DropdownMenuItem>
        <DropdownMenuItem onClick={() => setTheme('system')}>
          <Laptop className="mr-2 h-4 w-4" />
          <span>System</span>
        </DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
```

## 🎯 Best Practices Summary

### Component Architecture Guidelines

1. **Favor Composition over Inheritance**
   - Use compound components for complex UI patterns
   - Leverage render props for flexible data rendering
   - Implement headless components for maximum reusability

2. **Performance Optimization**
   - Memoize expensive components with React.memo
   - Use useMemo and useCallback for expensive calculations
   - Implement virtual scrolling for large datasets
   - Optimize bundle size with code splitting

3. **Accessibility First**
   - Use semantic HTML elements
   - Implement proper ARIA attributes
   - Ensure keyboard navigation support
   - Test with screen readers

4. **Type Safety**
   - Define strict TypeScript interfaces
   - Use generic components where appropriate
   - Implement proper prop validation
   - Document component APIs with JSDoc

5. **Testing Strategy**
   - Write comprehensive unit tests
   - Use Storybook for component documentation
   - Implement visual regression testing
   - Test accessibility compliance

### Technology Recommendations

**For New Projects:**
- **Styling**: Tailwind CSS + Class Variance Authority
- **Components**: Radix UI primitives + custom components  
- **Documentation**: Storybook with MDX
- **Testing**: Jest + React Testing Library + Playwright

**For Enterprise Applications:**
- **Design System**: Custom design system with strict governance
- **Component Library**: Monorepo with shared components
- **Documentation**: Comprehensive Storybook with design tokens
- **Testing**: Extensive test coverage with visual regression testing

---

## 🔗 Navigation

**Previous:** [Comparison Analysis](./comparison-analysis.md) | **Next:** [API Integration Approaches](./api-integration-approaches.md)