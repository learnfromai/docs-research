# Template Examples: Working Code Samples & Reusable Patterns

## 🎯 Overview

This document provides complete, working examples of **shadcn/ui** components enhanced with **Mantine** and **Ant Design** styling patterns. All examples are production-ready and demonstrate best practices for real-world implementations.

## 🚀 Complete Component Examples

### **Example 1: Enhanced Dashboard Cards**

#### **Dashboard Card Component**
```typescript
// components/templates/dashboard-card.tsx
import * as React from "react"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card-enhanced"
import { Button } from "@/components/ui/button-enhanced"
import { Badge } from "@/components/ui/badge"
import { Progress } from "@/components/ui/progress"
import { TrendingUp, TrendingDown, Users, DollarSign, ShoppingCart, Activity } from "lucide-react"

interface DashboardCardProps {
  title: string
  value: string | number
  description?: string
  trend?: {
    value: number
    isPositive: boolean
  }
  icon?: React.ReactNode
  variant?: 'default' | 'mantine' | 'antd'
  progress?: {
    value: number
    max: number
    label?: string
  }
  actions?: React.ReactNode
}

export function DashboardCard({
  title,
  value,
  description,
  trend,
  icon,
  variant = 'default',
  progress,
  actions
}: DashboardCardProps) {
  const TrendIcon = trend?.isPositive ? TrendingUp : TrendingDown
  
  return (
    <Card variant={variant} className="relative overflow-hidden">
      {/* Background gradient for Mantine variant */}
      {variant === 'mantine' && (
        <div className="absolute inset-0 bg-gradient-to-br from-blue-50 to-transparent opacity-50" />
      )}
      
      <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
        <CardTitle className="text-sm font-medium">
          {title}
        </CardTitle>
        {icon && (
          <div className={`
            p-2 rounded-lg
            ${variant === 'mantine' ? 'bg-blue-100 text-blue-600' : ''}
            ${variant === 'antd' ? 'bg-blue-50 text-blue-500' : ''}
            ${variant === 'default' ? 'bg-muted text-muted-foreground' : ''}
          `}>
            {icon}
          </div>
        )}
      </CardHeader>
      
      <CardContent>
        <div className="flex items-center justify-between">
          <div className="flex-1">
            <div className="text-2xl font-bold">{value}</div>
            {description && (
              <CardDescription className="mt-1">
                {description}
              </CardDescription>
            )}
          </div>
          
          {trend && (
            <div className={`
              flex items-center text-sm
              ${trend.isPositive ? 'text-green-600' : 'text-red-600'}
            `}>
              <TrendIcon className="h-4 w-4 mr-1" />
              {Math.abs(trend.value)}%
            </div>
          )}
        </div>
        
        {progress && (
          <div className="mt-4 space-y-2">
            <div className="flex justify-between text-sm">
              <span className="text-muted-foreground">
                {progress.label || 'Progress'}
              </span>
              <span>{progress.value}/{progress.max}</span>
            </div>
            <Progress 
              value={(progress.value / progress.max) * 100} 
              className={
                variant === 'mantine' ? 'bg-blue-100' :
                variant === 'antd' ? 'bg-gray-200' : ''
              }
            />
          </div>
        )}
        
        {actions && (
          <div className="mt-4 pt-4 border-t">
            {actions}
          </div>
        )}
      </CardContent>
    </Card>
  )
}

// Usage Example Component
export function DashboardExample() {
  return (
    <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-4">
      {/* Default shadcn/ui styling */}
      <DashboardCard
        title="Total Revenue"
        value="$45,231.89"
        description="20.1% from last month"
        trend={{ value: 20.1, isPositive: true }}
        icon={<DollarSign className="h-4 w-4" />}
        variant="default"
        actions={
          <Button size="sm" variant="outline">
            View Details
          </Button>
        }
      />
      
      {/* Mantine-inspired styling */}
      <DashboardCard
        title="Active Users"
        value="2,350"
        description="180 new users today"
        trend={{ value: 12.5, isPositive: true }}
        icon={<Users className="h-4 w-4" />}
        variant="mantine"
        progress={{ value: 2350, max: 3000, label: "Goal: 3000" }}
        actions={
          <Button size="mantine-sm" variant="mantine-light">
            Manage Users
          </Button>
        }
      />
      
      {/* Ant Design-inspired styling */}
      <DashboardCard
        title="Total Orders"
        value="12,234"
        description="8 orders pending"
        trend={{ value: 5.2, isPositive: false }}
        icon={<ShoppingCart className="h-4 w-4" />}
        variant="antd"
        actions={
          <Button size="antd-small" variant="antd-primary">
            Process Orders
          </Button>
        }
      />
      
      {/* Mixed styling with custom enhancements */}
      <DashboardCard
        title="Conversion Rate"
        value="3.24%"
        description="Tracking pixel performance"
        trend={{ value: 8.7, isPositive: true }}
        icon={<Activity className="h-4 w-4" />}
        variant="mantine"
        progress={{ value: 324, max: 500, label: "Target: 5%" }}
        actions={
          <div className="flex space-x-2">
            <Button size="mantine-sm" variant="mantine-outline">
              Analyze
            </Button>
            <Badge variant="secondary">Live</Badge>
          </div>
        }
      />
    </div>
  )
}
```

### **Example 2: Advanced Form Components**

#### **Enhanced Form Implementation**
```typescript
// components/templates/contact-form.tsx
import * as React from "react"
import { useForm } from "react-hook-form"
import { zodResolver } from "@hookform/resolvers/zod"
import * as z from "zod"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card-enhanced"
import { Button } from "@/components/ui/button-enhanced"
import { Input } from "@/components/ui/input-enhanced"
import { Textarea } from "@/components/ui/textarea"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Checkbox } from "@/components/ui/checkbox"
import { Label } from "@/components/ui/label"
import { Alert, AlertDescription } from "@/components/ui/alert"
import { Mail, Phone, MapPin, Send, CheckCircle } from "lucide-react"

const contactSchema = z.object({
  firstName: z.string().min(2, "First name must be at least 2 characters"),
  lastName: z.string().min(2, "Last name must be at least 2 characters"),
  email: z.string().email("Please enter a valid email address"),
  phone: z.string().min(10, "Please enter a valid phone number"),
  company: z.string().optional(),
  inquiryType: z.string().min(1, "Please select an inquiry type"),
  message: z.string().min(10, "Message must be at least 10 characters"),
  newsletter: z.boolean().default(false),
  terms: z.boolean().refine(val => val === true, "You must accept the terms")
})

type ContactFormData = z.infer<typeof contactSchema>

interface ContactFormProps {
  variant?: 'default' | 'mantine' | 'antd'
  onSubmit?: (data: ContactFormData) => Promise<void>
}

export function ContactForm({ variant = 'default', onSubmit }: ContactFormProps) {
  const [isSubmitting, setIsSubmitting] = React.useState(false)
  const [isSubmitted, setIsSubmitted] = React.useState(false)
  
  const form = useForm<ContactFormData>({
    resolver: zodResolver(contactSchema),
    defaultValues: {
      firstName: "",
      lastName: "",
      email: "",
      phone: "",
      company: "",
      inquiryType: "",
      message: "",
      newsletter: false,
      terms: false
    }
  })
  
  const handleSubmit = async (data: ContactFormData) => {
    setIsSubmitting(true)
    try {
      await onSubmit?.(data)
      setIsSubmitted(true)
      form.reset()
    } catch (error) {
      console.error('Form submission error:', error)
    } finally {
      setIsSubmitting(false)
    }
  }
  
  if (isSubmitted) {
    return (
      <Card variant={variant} className="max-w-2xl mx-auto">
        <CardContent className="pt-6">
          <div className="text-center space-y-4">
            <CheckCircle className="h-16 w-16 text-green-500 mx-auto" />
            <h3 className="text-xl font-semibold">Thank you for your message!</h3>
            <p className="text-muted-foreground">
              We'll get back to you within 24 hours.
            </p>
            <Button
              variant={
                variant === 'mantine' ? 'mantine-light' :
                variant === 'antd' ? 'antd-default' : 'outline'
              }
              onClick={() => setIsSubmitted(false)}
            >
              Send Another Message
            </Button>
          </div>
        </CardContent>
      </Card>
    )
  }
  
  return (
    <Card variant={variant} className="max-w-2xl mx-auto">
      <CardHeader>
        <CardTitle className={
          variant === 'mantine' ? 'text-xl text-gray-900' :
          variant === 'antd' ? 'text-lg text-gray-800' :
          'text-2xl'
        }>
          Get in Touch
        </CardTitle>
        <CardDescription>
          Fill out the form below and we'll get back to you as soon as possible.
        </CardDescription>
      </CardHeader>
      
      <CardContent>
        <form onSubmit={form.handleSubmit(handleSubmit)} className="space-y-6">
          {/* Personal Information Section */}
          <div className="space-y-4">
            <h4 className="text-sm font-medium text-muted-foreground uppercase tracking-wide">
              Personal Information
            </h4>
            
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <Input
                variant={variant}
                label="First Name"
                placeholder="John"
                withAsterisk
                error={form.formState.errors.firstName?.message}
                {...form.register("firstName")}
              />
              
              <Input
                variant={variant}
                label="Last Name"
                placeholder="Doe"
                withAsterisk
                error={form.formState.errors.lastName?.message}
                {...form.register("lastName")}
              />
            </div>
            
            <Input
              variant={variant}
              label="Email Address"
              type="email"
              placeholder="john.doe@example.com"
              withAsterisk
              leftSection={<Mail className="h-4 w-4" />}
              error={form.formState.errors.email?.message}
              {...form.register("email")}
            />
            
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <Input
                variant={variant}
                label="Phone Number"
                type="tel"
                placeholder="+1 (555) 000-0000"
                withAsterisk
                leftSection={<Phone className="h-4 w-4" />}
                error={form.formState.errors.phone?.message}
                {...form.register("phone")}
              />
              
              <Input
                variant={variant}
                label="Company"
                placeholder="Acme Inc."
                leftSection={<MapPin className="h-4 w-4" />}
                error={form.formState.errors.company?.message}
                {...form.register("company")}
              />
            </div>
          </div>
          
          {/* Inquiry Details Section */}
          <div className="space-y-4">
            <h4 className="text-sm font-medium text-muted-foreground uppercase tracking-wide">
              Inquiry Details
            </h4>
            
            <div className="space-y-2">
              <Label htmlFor="inquiryType" className="text-sm font-medium">
                Inquiry Type *
              </Label>
              <Select onValueChange={(value) => form.setValue("inquiryType", value)}>
                <SelectTrigger className={
                  variant === 'mantine' ? 'border-gray-300 focus:border-blue-500' :
                  variant === 'antd' ? 'border-gray-300 focus:border-blue-500' :
                  ''
                }>
                  <SelectValue placeholder="Select an inquiry type" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="general">General Inquiry</SelectItem>
                  <SelectItem value="support">Technical Support</SelectItem>
                  <SelectItem value="sales">Sales Question</SelectItem>
                  <SelectItem value="partnership">Partnership</SelectItem>
                  <SelectItem value="other">Other</SelectItem>
                </SelectContent>
              </Select>
              {form.formState.errors.inquiryType && (
                <p className="text-sm text-red-600">
                  {form.formState.errors.inquiryType.message}
                </p>
              )}
            </div>
            
            <div className="space-y-2">
              <Label htmlFor="message" className="text-sm font-medium">
                Message *
              </Label>
              <Textarea
                id="message"
                placeholder="Tell us more about your inquiry..."
                className={`min-h-[120px] ${
                  variant === 'mantine' ? 'border-gray-300 focus:border-blue-500 focus:ring-1 focus:ring-blue-500' :
                  variant === 'antd' ? 'border-gray-300 focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20' :
                  ''
                }`}
                {...form.register("message")}
              />
              {form.formState.errors.message && (
                <p className="text-sm text-red-600">
                  {form.formState.errors.message.message}
                </p>
              )}
            </div>
          </div>
          
          {/* Preferences Section */}
          <div className="space-y-4">
            <h4 className="text-sm font-medium text-muted-foreground uppercase tracking-wide">
              Preferences
            </h4>
            
            <div className="space-y-3">
              <div className="flex items-center space-x-2">
                <Checkbox
                  id="newsletter"
                  checked={form.watch("newsletter")}
                  onCheckedChange={(checked) => 
                    form.setValue("newsletter", checked as boolean)
                  }
                />
                <Label htmlFor="newsletter" className="text-sm">
                  Subscribe to our newsletter for updates and tips
                </Label>
              </div>
              
              <div className="flex items-center space-x-2">
                <Checkbox
                  id="terms"
                  checked={form.watch("terms")}
                  onCheckedChange={(checked) => 
                    form.setValue("terms", checked as boolean)
                  }
                />
                <Label htmlFor="terms" className="text-sm">
                  I agree to the{" "}
                  <a href="#" className="text-blue-600 hover:underline">
                    Terms of Service
                  </a>{" "}
                  and{" "}
                  <a href="#" className="text-blue-600 hover:underline">
                    Privacy Policy
                  </a>
                  *
                </Label>
              </div>
              {form.formState.errors.terms && (
                <p className="text-sm text-red-600">
                  {form.formState.errors.terms.message}
                </p>
              )}
            </div>
          </div>
          
          {/* Form Errors Alert */}
          {Object.keys(form.formState.errors).length > 0 && (
            <Alert className="border-red-200 bg-red-50">
              <AlertDescription className="text-red-800">
                Please fix the errors above before submitting the form.
              </AlertDescription>
            </Alert>
          )}
          
          {/* Submit Button */}
          <div className="flex justify-end space-x-4">
            <Button
              type="button"
              variant={
                variant === 'mantine' ? 'mantine-subtle' :
                variant === 'antd' ? 'antd-default' : 'outline'
              }
              onClick={() => form.reset()}
              disabled={isSubmitting}
            >
              Reset Form
            </Button>
            
            <Button
              type="submit"
              variant={
                variant === 'mantine' ? 'mantine-filled' :
                variant === 'antd' ? 'antd-primary' : 'default'
              }
              size={
                variant === 'mantine' ? 'mantine-md' :
                variant === 'antd' ? 'antd-middle' : 'default'
              }
              loading={isSubmitting}
              leftIcon={<Send className="h-4 w-4" />}
            >
              {isSubmitting ? 'Sending...' : 'Send Message'}
            </Button>
          </div>
        </form>
      </CardContent>
    </Card>
  )
}

// Usage Examples
export function ContactFormExamples() {
  const handleFormSubmit = async (data: ContactFormData) => {
    // Simulate API call
    await new Promise(resolve => setTimeout(resolve, 2000))
    console.log('Form submitted:', data)
  }
  
  return (
    <div className="space-y-8">
      <div>
        <h3 className="text-lg font-semibold mb-4">Default shadcn/ui Style</h3>
        <ContactForm variant="default" onSubmit={handleFormSubmit} />
      </div>
      
      <div>
        <h3 className="text-lg font-semibold mb-4">Mantine-Inspired Style</h3>
        <ContactForm variant="mantine" onSubmit={handleFormSubmit} />
      </div>
      
      <div>
        <h3 className="text-lg font-semibold mb-4">Ant Design-Inspired Style</h3>
        <ContactForm variant="antd" onSubmit={handleFormSubmit} />
      </div>
    </div>
  )
}
```

### **Example 3: Data Display Components**

#### **Enhanced Data Table with Multiple Styling Options**
```typescript
// components/templates/enhanced-data-table.tsx
import * as React from "react"
import {
  ColumnDef,
  flexRender,
  getCoreRowModel,
  getFilteredRowModel,
  getPaginationRowModel,
  getSortedRowModel,
  useReactTable,
} from "@tanstack/react-table"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card-enhanced"
import { Button } from "@/components/ui/button-enhanced"
import { Input } from "@/components/ui/input-enhanced"
import { Badge } from "@/components/ui/badge"
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table"
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"
import { 
  ChevronDown, 
  ChevronUp, 
  Search, 
  MoreHorizontal, 
  Edit,
  Trash2,
  Eye,
  Filter
} from "lucide-react"

interface User {
  id: string
  name: string
  email: string
  role: 'admin' | 'user' | 'moderator'
  status: 'active' | 'inactive' | 'pending'
  joinDate: string
  lastActive: string
}

interface EnhancedDataTableProps {
  data: User[]
  variant?: 'default' | 'mantine' | 'antd'
  onEdit?: (user: User) => void
  onDelete?: (user: User) => void
  onView?: (user: User) => void
}

export function EnhancedDataTable({ 
  data, 
  variant = 'default',
  onEdit,
  onDelete,
  onView
}: EnhancedDataTableProps) {
  const [globalFilter, setGlobalFilter] = React.useState("")
  
  const columns: ColumnDef<User>[] = [
    {
      accessorKey: "name",
      header: ({ column }) => (
        <Button
          variant="ghost"
          onClick={() => column.toggleSorting(column.getIsSorted() === "asc")}
          className={`
            -ml-3 h-8 data-[state=open]:bg-accent
            ${variant === 'mantine' ? 'hover:bg-blue-50 text-gray-700' : ''}
            ${variant === 'antd' ? 'hover:bg-gray-50' : ''}
          `}
        >
          Name
          {column.getIsSorted() === "asc" ? (
            <ChevronUp className="ml-2 h-4 w-4" />
          ) : column.getIsSorted() === "desc" ? (
            <ChevronDown className="ml-2 h-4 w-4" />
          ) : (
            <div className="ml-2 h-4 w-4" />
          )}
        </Button>
      ),
      cell: ({ row }) => (
        <div className="font-medium">{row.getValue("name")}</div>
      ),
    },
    {
      accessorKey: "email",
      header: "Email",
      cell: ({ row }) => (
        <div className="text-muted-foreground">{row.getValue("email")}</div>
      ),
    },
    {
      accessorKey: "role",
      header: "Role",
      cell: ({ row }) => {
        const role = row.getValue("role") as string
        return (
          <Badge 
            variant={
              role === 'admin' ? 'destructive' :
              role === 'moderator' ? 'default' : 'secondary'
            }
            className={
              variant === 'mantine' ? 'rounded-full' :
              variant === 'antd' ? 'rounded-sm' : ''
            }
          >
            {role}
          </Badge>
        )
      },
    },
    {
      accessorKey: "status",
      header: "Status",
      cell: ({ row }) => {
        const status = row.getValue("status") as string
        return (
          <div className="flex items-center">
            <div className={`
              w-2 h-2 rounded-full mr-2
              ${status === 'active' ? 'bg-green-500' : 
                status === 'inactive' ? 'bg-red-500' : 'bg-yellow-500'}
            `} />
            <span className="capitalize">{status}</span>
          </div>
        )
      },
    },
    {
      accessorKey: "joinDate",
      header: "Join Date",
      cell: ({ row }) => (
        <div className="text-sm">
          {new Date(row.getValue("joinDate")).toLocaleDateString()}
        </div>
      ),
    },
    {
      id: "actions",
      header: "Actions",
      cell: ({ row }) => {
        const user = row.original
        
        return (
          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button 
                variant="ghost" 
                className={`
                  h-8 w-8 p-0
                  ${variant === 'mantine' ? 'hover:bg-blue-50' : ''}
                  ${variant === 'antd' ? 'hover:bg-gray-50' : ''}
                `}
              >
                <MoreHorizontal className="h-4 w-4" />
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end">
              <DropdownMenuItem onClick={() => onView?.(user)}>
                <Eye className="mr-2 h-4 w-4" />
                View
              </DropdownMenuItem>
              <DropdownMenuItem onClick={() => onEdit?.(user)}>
                <Edit className="mr-2 h-4 w-4" />
                Edit
              </DropdownMenuItem>
              <DropdownMenuItem 
                className="text-destructive"
                onClick={() => onDelete?.(user)}
              >
                <Trash2 className="mr-2 h-4 w-4" />
                Delete
              </DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
        )
      },
    },
  ]
  
  const table = useReactTable({
    data,
    columns,
    getCoreRowModel: getCoreRowModel(),
    getPaginationRowModel: getPaginationRowModel(),
    getSortedRowModel: getSortedRowModel(),
    getFilteredRowModel: getFilteredRowModel(),
    globalFilterFn: "includesString",
    state: {
      globalFilter,
    },
    onGlobalFilterChange: setGlobalFilter,
  })
  
  return (
    <Card variant={variant}>
      <CardHeader>
        <div className="flex items-center justify-between">
          <div>
            <CardTitle className={
              variant === 'mantine' ? 'text-xl text-gray-900' :
              variant === 'antd' ? 'text-lg text-gray-800' :
              'text-2xl'
            }>
              Team Members
            </CardTitle>
            <CardDescription>
              Manage your team members and their account permissions here.
            </CardDescription>
          </div>
          
          <div className="flex items-center space-x-2">
            <div className="relative">
              <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-muted-foreground" />
              <Input
                placeholder="Search users..."
                value={globalFilter}
                onChange={(e) => setGlobalFilter(e.target.value)}
                className={`
                  pl-9 w-64
                  ${variant === 'mantine' ? 'border-gray-300 focus:border-blue-500' : ''}
                  ${variant === 'antd' ? 'border-gray-300 focus:border-blue-500' : ''}
                `}
              />
            </div>
            
            <Button
              variant={
                variant === 'mantine' ? 'mantine-light' :
                variant === 'antd' ? 'antd-default' : 'outline'
              }
              size="sm"
            >
              <Filter className="mr-2 h-4 w-4" />
              Filter
            </Button>
            
            <Button
              variant={
                variant === 'mantine' ? 'mantine-filled' :
                variant === 'antd' ? 'antd-primary' : 'default'
              }
              size="sm"
            >
              Add User
            </Button>
          </div>
        </div>
      </CardHeader>
      
      <CardContent>
        <div className={`
          rounded-md border
          ${variant === 'mantine' ? 'border-gray-200' : ''}
          ${variant === 'antd' ? 'border-gray-300' : ''}
        `}>
          <Table>
            <TableHeader>
              {table.getHeaderGroups().map((headerGroup) => (
                <TableRow 
                  key={headerGroup.id}
                  className={
                    variant === 'mantine' ? 'bg-gray-50 hover:bg-gray-50' :
                    variant === 'antd' ? 'bg-gray-50 hover:bg-gray-50' : ''
                  }
                >
                  {headerGroup.headers.map((header) => (
                    <TableHead key={header.id}>
                      {header.isPlaceholder
                        ? null
                        : flexRender(
                            header.column.columnDef.header,
                            header.getContext()
                          )}
                    </TableHead>
                  ))}
                </TableRow>
              ))}
            </TableHeader>
            <TableBody>
              {table.getRowModel().rows?.length ? (
                table.getRowModel().rows.map((row) => (
                  <TableRow
                    key={row.id}
                    data-state={row.getIsSelected() && "selected"}
                    className={`
                      ${variant === 'mantine' ? 'hover:bg-blue-50' : ''}
                      ${variant === 'antd' ? 'hover:bg-gray-50' : ''}
                    `}
                  >
                    {row.getVisibleCells().map((cell) => (
                      <TableCell key={cell.id}>
                        {flexRender(
                          cell.column.columnDef.cell,
                          cell.getContext()
                        )}
                      </TableCell>
                    ))}
                  </TableRow>
                ))
              ) : (
                <TableRow>
                  <TableCell 
                    colSpan={columns.length} 
                    className="h-24 text-center"
                  >
                    No results.
                  </TableCell>
                </TableRow>
              )}
            </TableBody>
          </Table>
        </div>
        
        {/* Pagination */}
        <div className="flex items-center justify-between space-x-2 py-4">
          <div className="text-sm text-muted-foreground">
            Showing {table.getState().pagination.pageIndex * table.getState().pagination.pageSize + 1} to{" "}
            {Math.min(
              (table.getState().pagination.pageIndex + 1) * table.getState().pagination.pageSize,
              table.getFilteredRowModel().rows.length
            )}{" "}
            of {table.getFilteredRowModel().rows.length} results
          </div>
          
          <div className="flex items-center space-x-2">
            <Button
              variant={
                variant === 'mantine' ? 'mantine-outline' :
                variant === 'antd' ? 'antd-default' : 'outline'
              }
              size="sm"
              onClick={() => table.previousPage()}
              disabled={!table.getCanPreviousPage()}
            >
              Previous
            </Button>
            
            <div className="flex items-center space-x-1">
              {Array.from({ length: Math.min(5, table.getPageCount()) }, (_, i) => {
                const page = i + Math.max(0, table.getState().pagination.pageIndex - 2)
                if (page >= table.getPageCount()) return null
                
                return (
                  <Button
                    key={page}
                    variant={
                      page === table.getState().pagination.pageIndex 
                        ? variant === 'mantine' ? 'mantine-filled' :
                          variant === 'antd' ? 'antd-primary' : 'default'
                        : 'ghost'
                    }
                    size="sm"
                    onClick={() => table.setPageIndex(page)}
                  >
                    {page + 1}
                  </Button>
                )
              })}
            </div>
            
            <Button
              variant={
                variant === 'mantine' ? 'mantine-outline' :
                variant === 'antd' ? 'antd-default' : 'outline'
              }
              size="sm"
              onClick={() => table.nextPage()}
              disabled={!table.getCanNextPage()}
            >
              Next
            </Button>
          </div>
        </div>
      </CardContent>
    </Card>
  )
}

// Sample data for demonstration
export const sampleUsers: User[] = [
  {
    id: "1",
    name: "John Doe",
    email: "john@example.com",
    role: "admin",
    status: "active",
    joinDate: "2023-01-15",
    lastActive: "2024-01-10"
  },
  {
    id: "2",
    name: "Jane Smith",
    email: "jane@example.com",
    role: "user",
    status: "active",
    joinDate: "2023-03-20",
    lastActive: "2024-01-09"
  },
  {
    id: "3",
    name: "Bob Johnson",
    email: "bob@example.com",
    role: "moderator",
    status: "pending",
    joinDate: "2023-12-01",
    lastActive: "2024-01-08"
  },
  {
    id: "4",
    name: "Alice Brown",
    email: "alice@example.com",
    role: "user",
    status: "inactive",
    joinDate: "2023-06-10",
    lastActive: "2023-12-15"
  }
]

// Usage Example
export function DataTableExamples() {
  const handleEdit = (user: User) => {
    console.log('Edit user:', user)
  }
  
  const handleDelete = (user: User) => {
    console.log('Delete user:', user)
  }
  
  const handleView = (user: User) => {
    console.log('View user:', user)
  }
  
  return (
    <div className="space-y-8">
      <div>
        <h3 className="text-lg font-semibold mb-4">Default shadcn/ui Style</h3>
        <EnhancedDataTable
          data={sampleUsers}
          variant="default"
          onEdit={handleEdit}
          onDelete={handleDelete}
          onView={handleView}
        />
      </div>
      
      <div>
        <h3 className="text-lg font-semibold mb-4">Mantine-Inspired Style</h3>
        <EnhancedDataTable
          data={sampleUsers}
          variant="mantine"
          onEdit={handleEdit}
          onDelete={handleDelete}
          onView={handleView}
        />
      </div>
      
      <div>
        <h3 className="text-lg font-semibold mb-4">Ant Design-Inspired Style</h3>
        <EnhancedDataTable
          data={sampleUsers}
          variant="antd"
          onEdit={handleEdit}
          onDelete={handleDelete}
          onView={handleView}
        />
      </div>
    </div>
  )
}
```

## 🎨 Complete Page Templates

### **Example 4: Admin Dashboard Template**

```typescript
// templates/admin-dashboard.tsx
import * as React from "react"
import { DashboardCard } from "@/components/templates/dashboard-card"
import { EnhancedDataTable, sampleUsers } from "@/components/templates/enhanced-data-table"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card-enhanced"
import { Button } from "@/components/ui/button-enhanced"
import { Badge } from "@/components/ui/badge"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { 
  Users, 
  DollarSign, 
  ShoppingCart, 
  Activity, 
  Bell,
  Settings,
  Search,
  Plus
} from "lucide-react"

interface AdminDashboardProps {
  variant?: 'default' | 'mantine' | 'antd'
}

export function AdminDashboard({ variant = 'default' }: AdminDashboardProps) {
  return (
    <div className="min-h-screen bg-background">
      {/* Header */}
      <header className={`
        border-b px-6 py-4
        ${variant === 'mantine' ? 'bg-white border-gray-200' : ''}
        ${variant === 'antd' ? 'bg-white border-gray-300' : ''}
      `}>
        <div className="flex items-center justify-between">
          <div>
            <h1 className={`
              text-2xl font-bold
              ${variant === 'mantine' ? 'text-gray-900' : ''}
              ${variant === 'antd' ? 'text-gray-800' : ''}
            `}>
              Admin Dashboard
            </h1>
            <p className="text-muted-foreground">
              Welcome back! Here's what's happening with your business today.
            </p>
          </div>
          
          <div className="flex items-center space-x-4">
            <Button
              variant={
                variant === 'mantine' ? 'mantine-subtle' :
                variant === 'antd' ? 'antd-text' : 'ghost'
              }
              size="sm"
            >
              <Bell className="h-4 w-4" />
            </Button>
            
            <Button
              variant={
                variant === 'mantine' ? 'mantine-subtle' :
                variant === 'antd' ? 'antd-text' : 'ghost'
              }
              size="sm"
            >
              <Settings className="h-4 w-4" />
            </Button>
            
            <Button
              variant={
                variant === 'mantine' ? 'mantine-filled' :
                variant === 'antd' ? 'antd-primary' : 'default'
              }
              size="sm"
            >
              <Plus className="h-4 w-4 mr-2" />
              New Project
            </Button>
          </div>
        </div>
      </header>
      
      {/* Main Content */}
      <main className="p-6 space-y-6">
        {/* Metrics Cards */}
        <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-4">
          <DashboardCard
            title="Total Revenue"
            value="$45,231.89"
            description="20.1% from last month"
            trend={{ value: 20.1, isPositive: true }}
            icon={<DollarSign className="h-4 w-4" />}
            variant={variant}
          />
          
          <DashboardCard
            title="Active Users"
            value="2,350"
            description="180 new users today"
            trend={{ value: 12.5, isPositive: true }}
            icon={<Users className="h-4 w-4" />}
            variant={variant}
            progress={{ value: 2350, max: 3000, label: "Goal: 3000" }}
          />
          
          <DashboardCard
            title="Total Orders"
            value="12,234"
            description="8 orders pending"
            trend={{ value: 5.2, isPositive: false }}
            icon={<ShoppingCart className="h-4 w-4" />}
            variant={variant}
          />
          
          <DashboardCard
            title="Conversion Rate"
            value="3.24%"
            description="Tracking pixel performance"
            trend={{ value: 8.7, isPositive: true }}
            icon={<Activity className="h-4 w-4" />}
            variant={variant}
          />
        </div>
        
        {/* Main Content Tabs */}
        <Tabs defaultValue="overview" className="space-y-4">
          <TabsList variant={variant === 'default' ? 'default' : variant}>
            <TabsTrigger variant={variant === 'default' ? 'default' : variant} value="overview">
              Overview
            </TabsTrigger>
            <TabsTrigger variant={variant === 'default' ? 'default' : variant} value="users">
              Users
            </TabsTrigger>
            <TabsTrigger variant={variant === 'default' ? 'default' : variant} value="analytics">
              Analytics
            </TabsTrigger>
            <TabsTrigger variant={variant === 'default' ? 'default' : variant} value="reports">
              Reports
            </TabsTrigger>
          </TabsList>
          
          <TabsContent value="overview" className="space-y-6">
            <div className="grid gap-6 md:grid-cols-2">
              {/* Recent Activity */}
              <Card variant={variant}>
                <CardHeader>
                  <CardTitle>Recent Activity</CardTitle>
                  <CardDescription>
                    Latest user activities and system events
                  </CardDescription>
                </CardHeader>
                <CardContent>
                  <div className="space-y-4">
                    {[
                      {
                        user: "John Doe",
                        action: "Created new project",
                        time: "2 minutes ago",
                        status: "success"
                      },
                      {
                        user: "Jane Smith", 
                        action: "Updated team settings",
                        time: "1 hour ago",
                        status: "info"
                      },
                      {
                        user: "Bob Johnson",
                        action: "Failed login attempt",
                        time: "3 hours ago", 
                        status: "warning"
                      }
                    ].map((activity, index) => (
                      <div key={index} className="flex items-center justify-between">
                        <div className="flex items-center space-x-3">
                          <div className={`
                            w-2 h-2 rounded-full
                            ${activity.status === 'success' ? 'bg-green-500' :
                              activity.status === 'warning' ? 'bg-yellow-500' : 'bg-blue-500'}
                          `} />
                          <div>
                            <p className="text-sm font-medium">{activity.user}</p>
                            <p className="text-xs text-muted-foreground">{activity.action}</p>
                          </div>
                        </div>
                        <span className="text-xs text-muted-foreground">{activity.time}</span>
                      </div>
                    ))}
                  </div>
                </CardContent>
              </Card>
              
              {/* Quick Actions */}
              <Card variant={variant}>
                <CardHeader>
                  <CardTitle>Quick Actions</CardTitle>
                  <CardDescription>
                    Common tasks and shortcuts
                  </CardDescription>
                </CardHeader>
                <CardContent>
                  <div className="grid gap-3">
                    <Button
                      variant={
                        variant === 'mantine' ? 'mantine-light' :
                        variant === 'antd' ? 'antd-default' : 'outline'
                      }
                      className="justify-start"
                    >
                      <Users className="mr-2 h-4 w-4" />
                      Invite Team Members
                    </Button>
                    
                    <Button
                      variant={
                        variant === 'mantine' ? 'mantine-light' :
                        variant === 'antd' ? 'antd-default' : 'outline'
                      }
                      className="justify-start"
                    >
                      <Settings className="mr-2 h-4 w-4" />
                      System Settings
                    </Button>
                    
                    <Button
                      variant={
                        variant === 'mantine' ? 'mantine-light' :
                        variant === 'antd' ? 'antd-default' : 'outline'
                      }
                      className="justify-start"
                    >
                      <Activity className="mr-2 h-4 w-4" />
                      View Analytics
                    </Button>
                  </div>
                </CardContent>
              </Card>
            </div>
          </TabsContent>
          
          <TabsContent value="users">
            <EnhancedDataTable
              data={sampleUsers}
              variant={variant}
              onEdit={(user) => console.log('Edit:', user)}
              onDelete={(user) => console.log('Delete:', user)}
              onView={(user) => console.log('View:', user)}
            />
          </TabsContent>
          
          <TabsContent value="analytics">
            <Card variant={variant}>
              <CardHeader>
                <CardTitle>Analytics Dashboard</CardTitle>
                <CardDescription>
                  Detailed analytics and performance metrics
                </CardDescription>
              </CardHeader>
              <CardContent>
                <div className="h-64 flex items-center justify-center text-muted-foreground">
                  Analytics chart placeholder
                </div>
              </CardContent>
            </Card>
          </TabsContent>
          
          <TabsContent value="reports">
            <Card variant={variant}>
              <CardHeader>
                <CardTitle>Reports & Exports</CardTitle>
                <CardDescription>
                  Generate and download system reports
                </CardDescription>
              </CardHeader>
              <CardContent>
                <div className="grid gap-4 md:grid-cols-2">
                  <Button
                    variant={
                      variant === 'mantine' ? 'mantine-outline' :
                      variant === 'antd' ? 'antd-default' : 'outline'
                    }
                  >
                    User Activity Report
                  </Button>
                  
                  <Button
                    variant={
                      variant === 'mantine' ? 'mantine-outline' :
                      variant === 'antd' ? 'antd-default' : 'outline'
                    }
                  >
                    Financial Summary
                  </Button>
                  
                  <Button
                    variant={
                      variant === 'mantine' ? 'mantine-outline' :
                      variant === 'antd' ? 'antd-default' : 'outline'
                    }
                  >
                    Performance Metrics
                  </Button>
                  
                  <Button
                    variant={
                      variant === 'mantine' ? 'mantine-outline' :
                      variant === 'antd' ? 'antd-default' : 'outline'
                    }
                  >
                    System Health
                  </Button>
                </div>
              </CardContent>
            </Card>
          </TabsContent>
        </Tabs>
      </main>
    </div>
  )
}

// Usage Examples
export function AdminDashboardExamples() {
  return (
    <div className="space-y-8">
      <AdminDashboard variant="default" />
      <AdminDashboard variant="mantine" />
      <AdminDashboard variant="antd" />
    </div>
  )
}
```

## 📦 Component Library Package Structure

### **Example 5: NPM Package Setup**

```json
// package.json
{
  "name": "@yourcompany/enhanced-ui",
  "version": "1.0.0",
  "description": "Enhanced shadcn/ui components with Mantine and Ant Design styling",
  "main": "dist/index.js",
  "module": "dist/index.mjs",
  "types": "dist/index.d.ts",
  "files": [
    "dist",
    "README.md"
  ],
  "scripts": {
    "build": "tsup",
    "dev": "tsup --watch",
    "lint": "eslint src --ext .ts,.tsx",
    "type-check": "tsc --noEmit",
    "storybook": "storybook dev -p 6006",
    "build-storybook": "storybook build"
  },
  "keywords": [
    "react",
    "components",
    "ui",
    "shadcn",
    "mantine",
    "antd",
    "tailwind"
  ],
  "peerDependencies": {
    "react": ">=18.0.0",
    "react-dom": ">=18.0.0",
    "tailwindcss": ">=3.3.0"
  },
  "dependencies": {
    "@radix-ui/react-accordion": "^1.1.2",
    "@radix-ui/react-alert-dialog": "^1.0.5",
    "@radix-ui/react-avatar": "^1.0.4",
    "class-variance-authority": "^0.7.0",
    "clsx": "^2.0.0",
    "lucide-react": "^0.294.0",
    "tailwind-merge": "^2.0.0"
  },
  "devDependencies": {
    "@types/react": "^18.2.0",
    "@types/react-dom": "^18.2.0",
    "typescript": "^5.0.0",
    "tsup": "^8.0.0",
    "eslint": "^8.0.0",
    "@storybook/react": "^7.0.0"
  }
}
```

```typescript
// src/index.ts - Main export file
// Enhanced Components
export { Button } from './components/button-enhanced'
export type { ButtonProps } from './components/button-enhanced'

export { Input } from './components/input-enhanced' 
export type { InputProps } from './components/input-enhanced'

export { 
  Card, 
  CardContent, 
  CardDescription, 
  CardFooter, 
  CardHeader, 
  CardTitle 
} from './components/card-enhanced'

export {
  Tabs,
  TabsContent,
  TabsList,
  TabsTrigger
} from './components/tabs-enhanced'

// Templates
export { DashboardCard } from './templates/dashboard-card'
export { ContactForm } from './templates/contact-form'
export { EnhancedDataTable } from './templates/enhanced-data-table'
export { AdminDashboard } from './templates/admin-dashboard'

// Contexts & Hooks
export { 
  DesignSystemProvider, 
  useDesignSystem 
} from './contexts/design-system-context'
export type { DesignSystemTheme } from './contexts/design-system-context'

// Utilities
export { cn } from './lib/utils'
```

```typescript
// tsup.config.ts - Build configuration
import { defineConfig } from 'tsup'

export default defineConfig({
  entry: ['src/index.ts'],
  format: ['cjs', 'esm'],
  dts: true,
  splitting: false,
  sourcemap: true,
  clean: true,
  external: ['react', 'react-dom'],
  banner: {
    js: '"use client";'
  }
})
```

---

## 🔗 Navigation

**Previous**: [Component Customization Strategies](./component-customization-strategies.md)  
**Next**: [README](./README.md)

---

*Last updated: [Current Date] | Template examples version: 1.0*