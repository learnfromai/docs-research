# Project Analysis: Open Source React/Next.js Applications

This document provides detailed analysis of 15+ high-quality open source React and Next.js projects, examining their architecture, technology choices, and implementation patterns.

## Tier 1 Projects (Production-Scale Applications)

### 1. Cal.com - Open Source Scheduling Platform

**Repository**: [github.com/calcom/cal.com](https://github.com/calcom/cal.com)
**Stars**: 30k+ | **Contributors**: 300+ | **Production**: Yes

#### Technology Stack
```yaml
Framework: Next.js 14 (App Router)
Language: TypeScript
State Management: React Query + Zustand
UI Library: Tailwind CSS + Radix UI
Authentication: NextAuth.js
Database: Prisma + PostgreSQL
API: tRPC
Deployment: Vercel
```

#### Architecture Highlights

**Monorepo Structure**: Uses Yarn workspaces for managing multiple packages
```
apps/
  web/          # Main Next.js application
  api/          # tRPC API routes
packages/
  ui/           # Shared UI components
  lib/          # Shared utilities
  prisma/       # Database schema
```

**State Management Pattern**:
- **Server State**: React Query for all external data fetching
- **Client State**: Zustand stores for UI state (modals, forms, preferences)
- **Form State**: React Hook Form with Zod validation

**Component Architecture**:
```typescript
// Headless component pattern
const DatePicker = ({ value, onChange, ...props }) => {
  return (
    <Popover>
      <PopoverTrigger asChild>
        <Button variant="outline">{formatDate(value)}</Button>
      </PopoverTrigger>
      <PopoverContent>
        <Calendar
          mode="single"
          selected={value}
          onSelect={onChange}
          {...props}
        />
      </PopoverContent>
    </Popover>
  );
};
```

**Authentication Implementation**:
- NextAuth.js with custom providers (Google, GitHub, SAML)
- Role-based access control (RBAC)
- API route protection with middleware

**Key Learning Points**:
1. **tRPC Integration**: End-to-end type safety from database to frontend
2. **Component Composition**: Heavy use of Radix UI primitives for accessibility
3. **Performance**: Strategic use of React.memo() and useMemo() for expensive operations
4. **Testing**: Comprehensive E2E testing with Playwright

---

### 2. Plane - Project Management Application

**Repository**: [github.com/makeplane/plane](https://github.com/makeplane/plane)
**Stars**: 25k+ | **Contributors**: 100+ | **Production**: Yes

#### Technology Stack
```yaml
Framework: Next.js 13 (Pages Router)
Language: TypeScript
State Management: SWR + Context API
UI Library: Tailwind CSS + Headless UI
Authentication: Custom JWT
Database: PostgreSQL + Django Backend
API: REST API
Deployment: Self-hosted/Cloud
```

#### Architecture Highlights

**Multi-Service Architecture**:
```
web/              # Next.js frontend
apiserver/        # Django backend
space/            # Public space interface
admin/            # Admin interface
```

**State Management Pattern**:
```typescript
// SWR for server state
const { data: projects, mutate } = useSWR(
  `/api/projects/`,
  fetcher
);

// Context for global UI state
const GlobalContext = createContext();
```

**Component Strategy**:
- Custom design system built with Tailwind CSS
- Compound component patterns for complex UI elements
- Strict TypeScript interfaces for component props

**Authentication Flow**:
```typescript
// Custom JWT implementation
const useAuth = () => {
  const [user, setUser] = useState(null);
  
  const login = async (credentials) => {
    const response = await api.post('/auth/login', credentials);
    const { token, user } = response.data;
    
    // Store token in httpOnly cookie
    setAuthToken(token);
    setUser(user);
  };
};
```

**Key Learning Points**:
1. **SWR Usage**: Effective server state management with built-in caching
2. **Custom Components**: Building complex UI without external component libraries
3. **Real-time Features**: WebSocket integration for live updates
4. **Workspace Management**: Multi-tenant architecture patterns

---

### 3. Supabase Dashboard

**Repository**: [github.com/supabase/supabase](https://github.com/supabase/supabase)
**Stars**: 65k+ | **Contributors**: 600+ | **Production**: Yes

#### Technology Stack
```yaml
Framework: Next.js 13 (App Router)
Language: TypeScript
State Management: React Query + Context
UI Library: Custom + Tailwind CSS
Authentication: Supabase Auth
Database: PostgreSQL (Supabase)
API: Supabase Client + REST
Deployment: Vercel
```

#### Architecture Highlights

**Dashboard Architecture**:
```
studio/
  components/       # Reusable UI components
  pages/           # Page components
  hooks/           # Custom hooks
  lib/             # Utilities and configurations
  types/           # TypeScript type definitions
```

**Component System**:
```typescript
// Custom UI component with Tailwind
const Button = ({ 
  variant = 'primary', 
  size = 'medium', 
  children, 
  ...props 
}) => {
  const baseClasses = 'inline-flex items-center justify-center rounded-md font-medium';
  const variantClasses = {
    primary: 'bg-green-600 text-white hover:bg-green-700',
    secondary: 'bg-gray-200 text-gray-900 hover:bg-gray-300',
  };
  
  return (
    <button 
      className={`${baseClasses} ${variantClasses[variant]}`}
      {...props}
    >
      {children}
    </button>
  );
};
```

**State Management**:
- React Query for all Supabase API calls
- Context API for global application state
- Local state for component-specific data

**Key Learning Points**:
1. **Supabase Integration**: Real-time database subscriptions
2. **Dashboard Patterns**: Complex data visualization and management interfaces
3. **Performance**: Efficient data fetching and caching strategies
4. **Accessibility**: Focus on keyboard navigation and screen reader support

---

### 4. Ant Design Pro

**Repository**: [github.com/ant-design/ant-design-pro](https://github.com/ant-design/ant-design-pro)
**Stars**: 35k+ | **Contributors**: 500+ | **Production**: Yes

#### Technology Stack
```yaml
Framework: React 18 + Umi
Language: TypeScript
State Management: Redux + dva
UI Library: Ant Design
Authentication: Custom
API: UmiRequest
Build Tool: Umi
```

#### Architecture Highlights

**Enterprise Application Structure**:
```
src/
  components/       # Global components
  pages/           # Page components with routes
  models/          # Redux models (dva)
  services/        # API service functions
  utils/           # Utility functions
  layouts/         # Layout components
```

**State Management with dva**:
```typescript
// Model definition (Redux + Redux-Saga)
export default {
  namespace: 'user',
  
  state: {
    currentUser: {},
    permissions: [],
  },
  
  effects: {
    *fetchCurrent(_, { call, put }) {
      const response = yield call(queryCurrentUser);
      yield put({
        type: 'saveCurrentUser',
        payload: response,
      });
    },
  },
  
  reducers: {
    saveCurrentUser(state, action) {
      return {
        ...state,
        currentUser: action.payload,
      };
    },
  },
};
```

**Enterprise Patterns**:
- Comprehensive permission system
- Multi-language internationalization
- Advanced table components with filtering and sorting
- Standardized form layouts and validation

**Key Learning Points**:
1. **Enterprise UI Patterns**: Standardized layouts and components for business applications
2. **dva Framework**: Simplified Redux usage with effects and models
3. **Internationalization**: Comprehensive i18n implementation
4. **Permission Management**: Role-based access control patterns

---

### 5. T3 Stack Examples

**Repository**: [github.com/t3-oss/create-t3-app](https://github.com/t3-oss/create-t3-app)
**Stars**: 20k+ | **Contributors**: 200+ | **Production**: Yes

#### Technology Stack
```yaml
Framework: Next.js 13+ (App Router)
Language: TypeScript
State Management: tRPC + Zustand
UI Library: Tailwind CSS
Authentication: NextAuth.js
Database: Prisma + PostgreSQL
API: tRPC
ORM: Prisma
```

#### Architecture Highlights

**T3 Stack Philosophy**:
- Type safety throughout the entire stack
- Minimal dependencies with maximum type safety
- Focus on developer experience and productivity

**tRPC Implementation**:
```typescript
// Server-side procedure
export const userRouter = createTRPCRouter({
  getProfile: protectedProcedure
    .input(z.object({ userId: z.string() }))
    .query(({ ctx, input }) => {
      return ctx.prisma.user.findUnique({
        where: { id: input.userId },
      });
    }),
    
  updateProfile: protectedProcedure
    .input(z.object({
      name: z.string(),
      email: z.string().email(),
    }))
    .mutation(({ ctx, input }) => {
      return ctx.prisma.user.update({
        where: { id: ctx.session.user.id },
        data: input,
      });
    }),
});

// Client-side usage
const { data: profile } = api.user.getProfile.useQuery({ 
  userId: session?.user?.id ?? "" 
});
```

**State Management Pattern**:
```typescript
// Zustand store for client state
interface AppState {
  theme: 'light' | 'dark';
  sidebarOpen: boolean;
  toggleTheme: () => void;
  toggleSidebar: () => void;
}

export const useAppStore = create<AppState>((set) => ({
  theme: 'light',
  sidebarOpen: false,
  toggleTheme: () => set((state) => ({ 
    theme: state.theme === 'light' ? 'dark' : 'light' 
  })),
  toggleSidebar: () => set((state) => ({ 
    sidebarOpen: !state.sidebarOpen 
  })),
}));
```

**Key Learning Points**:
1. **End-to-End Type Safety**: From database to UI with tRPC and Prisma
2. **Modern Stack**: Best practices for TypeScript-first development
3. **Developer Experience**: Excellent tooling and development workflow
4. **Scalability**: Patterns that scale from MVP to production

---

## Tier 2 Projects (Specialized Applications)

### 6. Storybook

**Repository**: [github.com/storybookjs/storybook](https://github.com/storybookjs/storybook)
**Focus**: Component development and documentation

#### Key Patterns
- **Component Isolation**: Developing components in isolation
- **Documentation-Driven Development**: Stories as living documentation
- **Add-on Architecture**: Extensible plugin system

### 7. React Admin

**Repository**: [github.com/marmelab/react-admin](https://github.com/marmelab/react-admin)
**Focus**: Admin interface framework

#### Key Patterns
- **Data Provider Pattern**: Abstract data layer for different APIs
- **Resource-Based Architecture**: CRUD operations as first-class citizens
- **Customizable Components**: Overridable default behaviors

### 8. Ghost (Admin Dashboard)

**Repository**: [github.com/TryGhost/Ghost](https://github.com/TryGhost/Ghost)
**Focus**: Content management system admin interface

#### Key Patterns
- **Ember.js to React Migration**: Lessons learned from framework migration
- **Rich Text Editing**: Complex editor implementation
- **Real-time Collaboration**: Live editing features

## Tier 3 Projects (Learning Resources)

### 9. React Query Examples

**Repository**: [github.com/tannerlinsley/react-query](https://github.com/tannerlinsley/react-query)

#### Key Patterns
- **Server State Management**: Caching, synchronization, and background updates
- **Optimistic Updates**: UI updates before server confirmation
- **Error Handling**: Comprehensive error boundary patterns

### 10. Next.js Examples

**Repository**: [github.com/vercel/next.js/tree/canary/examples](https://github.com/vercel/next.js/tree/canary/examples)

#### Key Patterns
- **File-based Routing**: App Router vs Pages Router patterns
- **Server-Side Rendering**: Static generation and incremental static regeneration
- **API Routes**: Full-stack development patterns

## Common Patterns Across Projects

### State Management Evolution

1. **Redux → Zustand**: Simpler state management for client state
2. **Manual Fetching → React Query**: Declarative server state management
3. **Prop Drilling → Context**: Strategic context usage for global state

### Component Architecture

1. **Compound Components**: Complex UI components with multiple parts
2. **Render Props → Hooks**: Logic reuse patterns evolution
3. **CSS-in-JS → Utility CSS**: Styling approach standardization

### Performance Optimization

1. **Code Splitting**: Route-based and component-based splitting
2. **Image Optimization**: Next.js Image component adoption
3. **Bundle Analysis**: Regular performance monitoring

### Security Practices

1. **Environment Variables**: Strict client/server separation
2. **Input Validation**: Zod for runtime type checking
3. **Authentication**: Standardized authentication flows

## Analysis Summary

The analysis reveals consistent patterns across successful React/Next.js applications:

1. **Type Safety First**: TypeScript adoption is universal in production applications
2. **Composable Architecture**: Component composition over inheritance
3. **Declarative Data Fetching**: React Query/SWR for server state management
4. **Performance by Default**: Built-in optimizations with manual fine-tuning
5. **Developer Experience**: Tooling that enhances productivity and reduces errors

These patterns provide a roadmap for building maintainable, scalable React applications that can grow from MVP to enterprise-scale solutions.

---

**Navigation**
- ← Back to: [Executive Summary](./executive-summary.md)
- → Next: [State Management Patterns](./state-management-patterns.md)
- → Related: [Implementation Guide](./implementation-guide.md)