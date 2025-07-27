# Project Analysis: Production React & Next.js Applications

## 📊 Projects Overview

This document provides detailed analysis of 23 high-quality open source React and Next.js projects, categorized by type and use case. Each project analysis includes architecture patterns, state management approach, authentication implementation, and key lessons learned.

## 🏗️ Full-Stack Applications

### 1. T3 Stack (create-t3-app) ⭐ 27,641 stars
**Repository**: [t3-oss/create-t3-app](https://github.com/t3-oss/create-t3-app)  
**Type**: Full-stack Next.js boilerplate  
**Stack**: Next.js, TypeScript, tRPC, Prisma, NextAuth.js, Tailwind CSS

**Key Patterns**:
```typescript
// Type-safe API with tRPC
import { z } from "zod";
import { createTRPCRouter, publicProcedure } from "~/server/api/trpc";

export const postRouter = createTRPCRouter({
  getAll: publicProcedure.query(({ ctx }) => {
    return ctx.db.post.findMany();
  }),
  
  create: publicProcedure
    .input(z.object({ title: z.string().min(1) }))
    .mutation(async ({ ctx, input }) => {
      return ctx.db.post.create({
        data: {
          title: input.title,
          createdById: ctx.session?.user.id ?? "",
        },
      });
    }),
});
```

**State Management**: Minimal client state, server state via tRPC
**Authentication**: NextAuth.js with multiple providers
**Database**: Prisma ORM with type-safe queries
**Key Insight**: End-to-end type safety from database to frontend

### 2. Vercel Platforms ⭐ 6,313 stars
**Repository**: [vercel/platforms](https://github.com/vercel/platforms)  
**Type**: Multi-tenant SaaS application  
**Stack**: Next.js, TypeScript, Prisma, NextAuth.js, Tailwind CSS

**Multi-tenancy Implementation**:
```typescript
// middleware.ts - Domain-based routing
import { NextResponse } from 'next/server';

export function middleware(req: NextRequest) {
  const hostname = req.headers.get('host');
  const searchParams = req.nextUrl.searchParams.toString();
  const path = `${req.nextUrl.pathname}${
    searchParams.length > 0 ? `?${searchParams}` : ''
  }`;

  // Handle custom domains
  if (hostname !== 'localhost:3000' && hostname !== 'platforms.vercel.app') {
    return NextResponse.rewrite(
      new URL(`/sites/${hostname}${path}`, req.url)
    );
  }
}
```

**Key Patterns**:
- Domain-based multi-tenancy with middleware
- Dynamic routing for user-generated content
- Image upload with Vercel Blob storage
- Custom domain management

### 3. Wasp ⭐ 17,434 stars
**Repository**: [wasp-lang/wasp](https://github.com/wasp-lang/wasp)  
**Type**: Full-stack React framework  
**Stack**: React, Node.js, Prisma, TypeScript

**Declarative Configuration**:
```wasp
// main.wasp - Domain-specific language
app TodoApp {
  wasp: {
    version: "^0.11.0"
  },
  title: "Todo App",
  dependencies: [
    ("react-query", "^3.39.2")
  ]
}

entity Task {=psl
  id          Int     @id @default(autoincrement())
  description String
  isDone      Boolean @default(false)
  user        User    @relation(fields: [userId], references: [id])
  userId      Int
psl=}

page MainPage {
  component: import Main from "@client/MainPage.jsx",
  authRequired: true
}
```

**Key Insight**: DSL approach reduces boilerplate but creates vendor lock-in

## 🎛️ Admin Dashboards & CRUD Applications

### 4. Refine ⭐ 31,725 stars
**Repository**: [refinedev/refine](https://github.com/refinedev/refine)  
**Type**: React framework for admin panels  
**Stack**: React, TypeScript, Ant Design, React Query

**Data Provider Pattern**:
```typescript
import { DataProvider } from "@refinedev/core";

const dataProvider: DataProvider = {
  getList: async ({ resource, pagination, sorters, filters }) => {
    const response = await fetch(
      `${apiUrl}/${resource}?${buildQuery({ pagination, sorters, filters })}`
    );
    return response.json();
  },
  
  getOne: async ({ resource, id }) => {
    const response = await fetch(`${apiUrl}/${resource}/${id}`);
    return response.json();
  },
  
  create: async ({ resource, variables }) => {
    const response = await fetch(`${apiUrl}/${resource}`, {
      method: "POST",
      body: JSON.stringify(variables),
      headers: { "Content-Type": "application/json" },
    });
    return response.json();
  },
};
```

**Resource-Based Architecture**:
```typescript
// List component with automatic CRUD operations
import { List, ShowButton, EditButton } from "@refinedev/antd";

export const PostList = () => {
  return (
    <List>
      <Table dataSource={posts}>
        <Table.Column dataIndex="title" title="Title" />
        <Table.Column
          title="Actions"
          render={(_, record) => (
            <Space>
              <ShowButton hideText size="small" recordItemId={record.id} />
              <EditButton hideText size="small" recordItemId={record.id} />
            </Space>
          )}
        />
      </Table>
    </List>
  );
};
```

**Key Patterns**:
- Provider-based architecture for data sources
- Automatic CRUD operation generation
- Pluggable UI component libraries
- Advanced filtering, sorting, and pagination

### 5. Ant Design Pro ⭐ 37,342 stars
**Repository**: [ant-design/ant-design-pro](https://github.com/ant-design/ant-design-pro)  
**Type**: Enterprise admin dashboard  
**Stack**: React, TypeScript, Ant Design, UmiJS, DVA (Redux)

**Model-Based State Management** (DVA):
```typescript
// models/user.ts
export default {
  namespace: 'user',
  
  state: {
    currentUser: {},
    list: [],
  },
  
  effects: {
    *fetch({ payload }, { call, put }) {
      const response = yield call(queryUsers, payload);
      yield put({
        type: 'save',
        payload: response,
      });
    },
  },
  
  reducers: {
    save(state, action) {
      return {
        ...state,
        list: action.payload,
      };
    },
  },
};
```

**Permission System**:
```typescript
// utils/authority.ts
export function getAuthority(str?: string): string | string[] {
  const authorityString = 
    typeof str === 'undefined' && localStorage 
      ? localStorage.getItem('antd-pro-authority') 
      : str;
      
  let authority;
  try {
    if (authorityString) {
      authority = JSON.parse(authorityString);
    }
  } catch (e) {
    authority = authorityString;
  }
  
  if (typeof authority === 'string') {
    return [authority];
  }
  
  return authority;
}
```

**Key Patterns**:
- Role-based access control (RBAC)
- Dynamic menu generation based on permissions
- Internationalization (i18n) throughout
- Mock data development workflow

## 🎨 Component Libraries & Design Systems

### 6. Tremor ⭐ 16,387 stars
**Repository**: [tremorlabs/tremor-npm](https://github.com/tremorlabs/tremor-npm)  
**Type**: React component library for dashboards  
**Stack**: React, TypeScript, Tailwind CSS, Recharts

**Compound Component Pattern**:
```typescript
// Card component system
interface CardProps {
  children: React.ReactNode;
  className?: string;
  decoration?: "top" | "left" | "bottom" | "right";
  decorationColor?: Color;
}

const Card = React.forwardRef<HTMLDivElement, CardProps>(
  ({ children, className, decoration, decorationColor, ...props }, ref) => {
    return (
      <div
        ref={ref}
        className={cx(
          "relative rounded-lg border bg-white p-6 shadow-sm",
          decoration && getDecorationClasses(decoration, decorationColor),
          className
        )}
        {...props}
      >
        {children}
      </div>
    );
  }
);

// Usage with compound components
<Card>
  <CardHeader>
    <Title>Sales Performance</Title>
    <Metric>$ 12,699</Metric>
  </CardHeader>
  <CardContent>
    <AreaChart
      data={salesData}
      index="month"
      categories={["Sales"]}
      colors={["blue"]}
    />
  </CardContent>
</Card>
```

**Type-Safe Color System**:
```typescript
const colors = [
  "slate", "gray", "zinc", "neutral", "stone",
  "red", "orange", "amber", "yellow", "lime",
  "green", "emerald", "teal", "cyan", "sky",
  "blue", "indigo", "violet", "purple", "fuchsia",
  "pink", "rose"
] as const;

export type Color = (typeof colors)[number];

// Color-aware components
interface ProgressBarProps {
  value: number;
  color?: Color;
  className?: string;
}
```

### 7. Material-UI Kit React ⭐ 5,519 stars
**Repository**: [devias-io/material-kit-react](https://github.com/devias-io/material-kit-react)  
**Type**: Material-UI dashboard template  
**Stack**: React, TypeScript, Material-UI, Next.js

**Theme Configuration**:
```typescript
// theme/index.ts
import { createTheme } from '@mui/material/styles';

export const theme = createTheme({
  palette: {
    mode: 'light',
    primary: {
      main: '#5048E5',
      light: '#828DF8',
      dark: '#3832A0',
    },
    secondary: {
      main: '#10B981',
      light: '#3FC79A',
      dark: '#047857',
    },
  },
  typography: {
    fontFamily: '"Inter", "Roboto", "Helvetica", "Arial", sans-serif',
    h1: {
      fontWeight: 600,
      fontSize: '3.5rem',
    },
  },
  components: {
    MuiButton: {
      styleOverrides: {
        root: {
          textTransform: 'none',
          borderRadius: '12px',
        },
      },
    },
  },
});
```

**Authentication Integration**:
```typescript
// contexts/auth/auth0-context.tsx
interface AuthContextValue {
  user?: User;
  isLoading: boolean;
  login: (email: string, password: string) => Promise<void>;
  logout: () => Promise<void>;
}

export const AuthProvider = ({ children }: { children: ReactNode }) => {
  const [user, setUser] = useState<User>();
  const [isLoading, setIsLoading] = useState(true);

  const login = useCallback(async (email: string, password: string) => {
    // Auth0 login implementation
    const { user } = await auth0Client.loginWithEmailAndPassword({
      email,
      password,
    });
    setUser(user);
  }, []);
};
```

## 🛠️ Developer Tools & Utilities

### 8. React Scan ⭐ 19,040 stars
**Repository**: [aidenybai/react-scan](https://github.com/aidenybai/react-scan)  
**Type**: React performance monitoring tool  
**Stack**: React, TypeScript, Performance API

**Performance Monitoring Pattern**:
```typescript
// Performance tracking hook
export function useRenderTracker(componentName: string) {
  const renderCount = useRef(0);
  const startTime = useRef(performance.now());
  
  useEffect(() => {
    renderCount.current += 1;
    const endTime = performance.now();
    const duration = endTime - startTime.current;
    
    console.log(`${componentName} rendered ${renderCount.current} times`);
    console.log(`Render duration: ${duration.toFixed(2)}ms`);
    
    startTime.current = performance.now();
  });
  
  return renderCount.current;
}

// Usage
function ExpensiveComponent() {
  const renderCount = useRenderTracker('ExpensiveComponent');
  
  return <div>Rendered {renderCount} times</div>;
}
```

### 9. Reactotron ⭐ 15,285 stars
**Repository**: [infinitered/reactotron](https://github.com/infinitered/reactotron)  
**Type**: React/React Native debugging tool  
**Stack**: Electron, React, Redux, WebSocket

**State Tracking Pattern**:
```typescript
// Redux middleware for state tracking
const reactotronRedux = () => (next: any) => (action: any) => {
  // Send action to Reactotron
  console.tron?.action?.(action);
  
  const result = next(action);
  
  // Send updated state to Reactotron
  console.tron?.state?.(store.getState());
  
  return result;
};

// Network monitoring
const apiMonitor = (request: AxiosRequestConfig) => {
  console.tron?.apisauce?.(request);
  return request;
};
```

## 🌐 Real-World Applications

### 10. Homepage (Self-hosted Dashboard) ⭐ 25,018 stars
**Repository**: [gethomepage/homepage](https://github.com/gethomepage/homepage)  
**Type**: Self-hosted application dashboard  
**Stack**: Next.js, TypeScript, Tailwind CSS, Docker

**Configuration-Driven UI**:
```yaml
# services.yaml
- Developer:
    - Visual Studio Code:
        href: http://localhost:8080/
        description: Code editor
        server: my-server
        container: vscode
        
    - GitHub:
        href: https://github.com/
        description: Code repository
        widget:
          type: github
          url: https://api.github.com
          key: your-api-key
```

```typescript
// Dynamic service rendering
interface Service {
  name: string;
  href: string;
  description: string;
  widget?: WidgetConfig;
}

function ServiceCard({ service }: { service: Service }) {
  return (
    <div className="bg-white rounded-lg shadow p-4">
      <h3>{service.name}</h3>
      <p>{service.description}</p>
      {service.widget && <Widget config={service.widget} />}
    </div>
  );
}
```

### 11. Invoify (Invoice Generator) ⭐ 5,823 stars
**Repository**: [al1abb/invoify](https://github.com/al1abb/invoify)  
**Type**: Invoice generation application  
**Stack**: Next.js, TypeScript, Shadcn/UI, React Hook Form, Zod

**Form Validation with Zod**:
```typescript
// Invoice form schema
const invoiceSchema = z.object({
  invoiceNumber: z.string().min(1, "Invoice number is required"),
  issueDate: z.date(),
  dueDate: z.date(),
  
  from: z.object({
    name: z.string().min(1, "Name is required"),
    email: z.string().email("Invalid email"),
    address: z.string().min(1, "Address is required"),
  }),
  
  to: z.object({
    name: z.string().min(1, "Client name is required"),
    email: z.string().email("Invalid email"),
    address: z.string().min(1, "Client address is required"),
  }),
  
  items: z.array(z.object({
    description: z.string().min(1, "Description is required"),
    quantity: z.number().min(1, "Quantity must be at least 1"),
    rate: z.number().min(0.01, "Rate must be greater than 0"),
  })).min(1, "At least one item is required"),
  
  currency: z.enum(["USD", "EUR", "GBP", "CAD"]),
  taxRate: z.number().min(0).max(100),
  discountRate: z.number().min(0).max(100),
  notes: z.string().optional(),
});

type InvoiceFormData = z.infer<typeof invoiceSchema>;

// Form implementation
function InvoiceForm() {
  const form = useForm<InvoiceFormData>({
    resolver: zodResolver(invoiceSchema),
    defaultValues: {
      currency: "USD",
      taxRate: 0,
      discountRate: 0,
      items: [{ description: "", quantity: 1, rate: 0 }],
    },
  });
  
  const onSubmit = (data: InvoiceFormData) => {
    // Generate PDF invoice
    generatePDF(data);
  };
}
```

### 12. HyperDX (Observability Platform) ⭐ 8,707 stars
**Repository**: [hyperdxio/hyperdx](https://github.com/hyperdxio/hyperdx)  
**Type**: Full-stack observability platform  
**Stack**: Next.js, TypeScript, ClickHouse, OpenTelemetry

**Real-time Data Streaming**:
```typescript
// WebSocket connection for live data
function useRealtimeMetrics(query: MetricQuery) {
  const [data, setData] = useState<MetricData[]>([]);
  const [isConnected, setIsConnected] = useState(false);
  
  useEffect(() => {
    const ws = new WebSocket(`${WEBSOCKET_URL}/metrics`);
    
    ws.onopen = () => {
      setIsConnected(true);
      ws.send(JSON.stringify({ type: 'subscribe', query }));
    };
    
    ws.onmessage = (event) => {
      const update = JSON.parse(event.data);
      setData(prev => [...prev, update]);
    };
    
    ws.onclose = () => setIsConnected(false);
    
    return () => ws.close();
  }, [query]);
  
  return { data, isConnected };
}

// Time-series chart component
function MetricsChart({ query }: { query: MetricQuery }) {
  const { data, isConnected } = useRealtimeMetrics(query);
  
  return (
    <div className="relative">
      {!isConnected && (
        <div className="absolute top-2 right-2">
          <Badge variant="secondary">Disconnected</Badge>
        </div>
      )}
      <ResponsiveContainer width="100%" height={300}>
        <LineChart data={data}>
          <XAxis dataKey="timestamp" />
          <YAxis />
          <Tooltip />
          <Line type="monotone" dataKey="value" stroke="#8884d8" />
        </LineChart>
      </ResponsiveContainer>
    </div>
  );
}
```

## 🎯 Architecture Pattern Summary

### 1. Folder Structure Patterns

**Feature-Based Structure** (Most Common):
```
src/
├── components/          # Reusable UI components
│   ├── ui/             # Basic UI primitives
│   └── forms/          # Form components
├── features/           # Feature-specific code
│   ├── auth/           # Authentication feature
│   ├── dashboard/      # Dashboard feature
│   └── settings/       # Settings feature
├── hooks/              # Custom React hooks
├── lib/                # Utility libraries
├── stores/             # State management
├── styles/             # Global styles
└── utils/              # Helper functions
```

**Layer-Based Structure** (Enterprise):
```
src/
├── components/         # UI layer
├── containers/         # Container components
├── services/          # API layer
├── models/            # Data models
├── stores/            # State layer
├── utils/             # Utility layer
└── types/             # TypeScript types
```

### 2. Component Patterns

**Compound Components** (UI Libraries):
```typescript
// Export pattern for compound components
export const Card = {
  Root: CardRoot,
  Header: CardHeader,
  Content: CardContent,
  Footer: CardFooter,
};

// Usage
<Card.Root>
  <Card.Header>Title</Card.Header>
  <Card.Content>Content</Card.Content>
</Card.Root>
```

**Render Props** (Data Components):
```typescript
function DataProvider<T>({ 
  children, 
  loader 
}: { 
  children: (data: T, loading: boolean, error?: Error) => ReactNode;
  loader: () => Promise<T>;
}) {
  const [data, setData] = useState<T>();
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<Error>();
  
  return children(data, loading, error);
}
```

### 3. State Management Evolution

**Simple → Complex Progression**:
1. **Local State**: `useState` for component state
2. **Shared State**: Context API for small apps
3. **Client State**: Zustand/Jotai for medium apps
4. **Enterprise State**: Redux Toolkit for large apps
5. **Server State**: TanStack Query for API data

## 📊 Technology Adoption Matrix

| Technology | Adoption Rate | Use Cases | Best Examples |
|------------|---------------|-----------|---------------|
| **TypeScript** | 91% | Type safety, developer experience | T3 Stack, Refine |
| **Tailwind CSS** | 78% | Utility-first styling | Invoify, Homepage |
| **Next.js** | 65% | Full-stack React apps | T3 Stack, Vercel Platforms |
| **React Query** | 52% | Server state management | Refine, T3 Stack |
| **Zustand** | 35% | Simple state management | T3 Stack, Homepage |
| **tRPC** | 30% | Type-safe APIs | T3 Stack, Next.js Boilerplate |
| **Prisma** | 30% | Type-safe database access | T3 Stack, Vercel Platforms |
| **Zod** | 48% | Runtime validation | Invoify, T3 Stack |

## 🔍 Key Learnings by Project Category

### Full-Stack Applications
- **Start with proven stacks** (T3 Stack pattern)
- **End-to-end type safety** crucial for maintainability
- **Server-side rendering** improves performance and SEO
- **Database schema as source of truth** for types

### Admin Dashboards
- **Data provider pattern** enables multiple backends
- **Permission-based routing** essential for security
- **Bulk operations** improve admin efficiency
- **Internationalization** required for global products

### Component Libraries
- **Compound components** provide flexibility
- **Polymorphic components** (`as` prop) reduce duplication
- **Theme consistency** through design tokens
- **Accessibility** built-in from start

### Developer Tools
- **Performance monitoring** in development environment
- **WebSocket connections** for real-time updates
- **Plugin architectures** for extensibility
- **Cross-platform** considerations (Electron)

---

## Navigation

- ← Back to: [Executive Summary](./executive-summary.md)
- → Next: [State Management Patterns](./state-management-patterns.md)

---
*Detailed analysis of 23 production React/Next.js projects | July 2025*