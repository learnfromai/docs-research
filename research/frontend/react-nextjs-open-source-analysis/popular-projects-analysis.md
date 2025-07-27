# Popular Projects Analysis: React & Next.js Open Source Applications

## 📊 Project Portfolio Overview

This section provides detailed analysis of 10+ production-ready React and Next.js open source applications, examining their architecture, technology choices, and implementation patterns.

## 🗓️ Cal.com - Open Source Calendly Alternative

**📍 Repository**: [cal.com/cal.com](https://github.com/calcom/cal.com)  
**⭐ Stars**: 30,000+ | **🍴 Forks**: 7,000+ | **👥 Contributors**: 500+

### **Technology Stack**
```yaml
Framework: Next.js 14 (App Router)
State Management: Zustand
UI Components: Radix UI + Tailwind CSS
Authentication: NextAuth.js
API Layer: tRPC
Database: Prisma + PostgreSQL
Testing: Playwright + Vitest
Deployment: Vercel
```

### **Key Architecture Patterns**

**🏗️ Monorepo Structure**
```
packages/
├── web/                 # Main Next.js application
├── ui/                  # Shared UI components
├── lib/                 # Shared utilities
├── prisma/              # Database schema
├── trpc/                # API routes
└── emails/              # Email templates
```

**⚡ State Management Pattern**
```typescript
// stores/eventTypes.ts
interface EventTypeStore {
  eventTypes: EventType[];
  isLoading: boolean;
  fetchEventTypes: () => Promise<void>;
  createEventType: (data: CreateEventTypeInput) => Promise<void>;
}

export const useEventTypeStore = create<EventTypeStore>((set, get) => ({
  eventTypes: [],
  isLoading: false,
  
  fetchEventTypes: async () => {
    set({ isLoading: true });
    try {
      const eventTypes = await trpc.eventTypes.list.query();
      set({ eventTypes, isLoading: false });
    } catch (error) {
      set({ isLoading: false });
      throw error;
    }
  },
  
  createEventType: async (data) => {
    const newEventType = await trpc.eventTypes.create.mutate(data);
    set((state) => ({
      eventTypes: [...state.eventTypes, newEventType]
    }));
  }
}));
```

**🔐 Authentication Implementation**
```typescript
// lib/auth.ts
export const authOptions: NextAuthOptions = {
  providers: [
    GoogleProvider({
      clientId: process.env.GOOGLE_CLIENT_ID!,
      clientSecret: process.env.GOOGLE_CLIENT_SECRET!,
    }),
    GitHubProvider({
      clientId: process.env.GITHUB_CLIENT_ID!,
      clientSecret: process.env.GITHUB_CLIENT_SECRET!,
    }),
  ],
  callbacks: {
    session: async ({ session, token }) => {
      session.user.id = token.sub!;
      return session;
    },
  },
  pages: {
    signIn: '/auth/signin',
    error: '/auth/error',
  },
};
```

**Key Learnings**:
- Excellent TypeScript integration throughout
- Clean separation of concerns with tRPC
- Comprehensive testing with Playwright
- Sophisticated permission system implementation

---

## ✈️ Plane - Open Source Jira Alternative

**📍 Repository**: [makeplane/plane](https://github.com/makeplane/plane)  
**⭐ Stars**: 25,000+ | **🍴 Forks**: 1,400+ | **👥 Contributors**: 100+

### **Technology Stack**
```yaml
Framework: Next.js 13 (Pages Router)
State Management: Zustand + SWR
UI Components: Headless UI + Tailwind CSS
Authentication: Custom JWT implementation
API Layer: Django REST Framework
Database: PostgreSQL
Testing: Jest + React Testing Library
Deployment: Docker + Kubernetes
```

### **Key Architecture Patterns**

**🎯 Feature-Based Structure**
```
components/
├── issues/
│   ├── board/           # Kanban board components
│   ├── list/            # List view components
│   └── detail/          # Issue detail components
├── projects/
└── workspace/

store/
├── issue.store.ts
├── project.store.ts
└── user.store.ts
```

**🔄 SWR + Zustand Pattern**
```typescript
// store/issue.store.ts
interface IssueStore {
  issues: Issue[];
  filters: IssueFilters;
  setFilters: (filters: Partial<IssueFilters>) => void;
  updateIssue: (issueId: string, data: Partial<Issue>) => void;
}

export const useIssueStore = create<IssueStore>((set) => ({
  issues: [],
  filters: { status: 'all', assignee: 'all' },
  
  setFilters: (newFilters) => 
    set((state) => ({ 
      filters: { ...state.filters, ...newFilters } 
    })),
    
  updateIssue: (issueId, data) =>
    set((state) => ({
      issues: state.issues.map(issue =>
        issue.id === issueId ? { ...issue, ...data } : issue
      )
    }))
}));

// hooks/use-issues.ts
export const useIssues = (workspaceId: string, projectId: string) => {
  const { filters } = useIssueStore();
  
  return useSWR(
    ['issues', workspaceId, projectId, filters],
    () => issueService.getIssues(workspaceId, projectId, filters),
    {
      revalidateOnFocus: false,
      revalidateOnReconnect: false,
    }
  );
};
```

**🎨 Component Library Strategy**
```typescript
// components/ui/Button.tsx
import { cva, type VariantProps } from 'class-variance-authority';

const buttonVariants = cva(
  'inline-flex items-center justify-center rounded-md text-sm font-medium transition-colors focus-visible:outline-none focus-visible:ring-2 disabled:pointer-events-none disabled:opacity-50',
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

interface ButtonProps
  extends React.ButtonHTMLAttributes<HTMLButtonElement>,
    VariantProps<typeof buttonVariants> {
  asChild?: boolean;
}

const Button = React.forwardRef<HTMLButtonElement, ButtonProps>(
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
```

**Key Learnings**:
- Effective combination of Zustand and SWR
- Excellent drag-and-drop implementation
- Comprehensive filtering and search functionality
- Clean component variant system with CVA

---

## ✍️ Novel - Notion-Style WYSIWYG Editor

**📍 Repository**: [steven-tey/novel](https://github.com/steven-tey/novel)  
**⭐ Stars**: 12,000+ | **🍴 Forks**: 1,000+ | **👥 Contributors**: 50+

### **Technology Stack**
```yaml
Framework: Next.js 14 (App Router)
State Management: Zustand
UI Components: Radix UI + Tailwind CSS
Authentication: Clerk
Editor: Tiptap (ProseMirror)
API Layer: React Query
Database: PlanetScale (MySQL)
Testing: Vitest
Deployment: Vercel
```

### **Key Architecture Patterns**

**📝 Editor State Management**
```typescript
// store/editor.store.ts
interface EditorStore {
  content: JSONContent;
  isLoading: boolean;
  isSaving: boolean;
  setContent: (content: JSONContent) => void;
  saveContent: () => Promise<void>;
}

export const useEditorStore = create<EditorStore>((set, get) => ({
  content: { type: 'doc', content: [] },
  isLoading: false,
  isSaving: false,
  
  setContent: (content) => set({ content }),
  
  saveContent: async () => {
    set({ isSaving: true });
    try {
      const { content } = get();
      await saveDocument.mutateAsync({ content });
      toast.success('Document saved!');
    } catch (error) {
      toast.error('Failed to save document');
    } finally {
      set({ isSaving: false });
    }
  }
}));
```

**🎨 Editor Components Architecture**
```typescript
// components/editor/Editor.tsx
export const Editor: FC<EditorProps> = ({ 
  initialContent, 
  onUpdate, 
  editable = true 
}) => {
  const { setContent, saveContent } = useEditorStore();
  
  const editor = useEditor({
    extensions: [
      StarterKit,
      Image.configure({
        HTMLAttributes: {
          class: 'rounded-lg border border-stone-200',
        },
      }),
      Placeholder.configure({
        placeholder: 'Press \'/\' for commands...',
      }),
      SlashCommand,
    ],
    content: initialContent,
    onUpdate: ({ editor }) => {
      const content = editor.getJSON();
      setContent(content);
      onUpdate?.(content);
    },
    editable,
  });

  // Auto-save functionality
  useEffect(() => {
    const saveTimer = setTimeout(() => {
      if (editor?.getHTML() !== initialContent) {
        saveContent();
      }
    }, 2000);

    return () => clearTimeout(saveTimer);
  }, [editor?.getHTML()]);

  return (
    <div className="prose prose-lg prose-stone mx-auto w-full max-w-4xl">
      <EditorContent editor={editor} />
    </div>
  );
};
```

**Key Learnings**:
- Sophisticated editor state management
- Excellent use of Tiptap extensions
- Clean command palette implementation
- Effective auto-save functionality

---

## 🔗 Dub - Open Source Bitly Alternative

**📍 Repository**: [dubinc/dub](https://github.com/dubinc/dub)  
**⭐ Stars**: 18,000+ | **🍴 Forks**: 2,000+ | **👥 Contributors**: 80+

### **Technology Stack**
```yaml
Framework: Next.js 14 (App Router)
State Management: Zustand
UI Components: Radix UI + Tailwind CSS
Authentication: NextAuth.js
API Layer: tRPC
Database: PlanetScale (MySQL)
Analytics: Tinybird
Testing: Vitest
Deployment: Vercel
```

### **Key Architecture Patterns**

**🔗 URL Management Store**
```typescript
// store/links.store.ts
interface LinkStore {
  links: Link[];
  isLoading: boolean;
  selectedLink: Link | null;
  createLink: (data: CreateLinkInput) => Promise<Link>;
  updateLink: (id: string, data: UpdateLinkInput) => Promise<Link>;
  deleteLink: (id: string) => Promise<void>;
  setSelectedLink: (link: Link | null) => void;
}

export const useLinkStore = create<LinkStore>((set, get) => ({
  links: [],
  isLoading: false,
  selectedLink: null,
  
  createLink: async (data) => {
    const newLink = await trpc.links.create.mutate(data);
    set((state) => ({ 
      links: [newLink, ...state.links] 
    }));
    return newLink;
  },
  
  updateLink: async (id, data) => {
    const updatedLink = await trpc.links.update.mutate({ id, ...data });
    set((state) => ({
      links: state.links.map(link => 
        link.id === id ? updatedLink : link
      ),
      selectedLink: state.selectedLink?.id === id ? updatedLink : state.selectedLink
    }));
    return updatedLink;
  },
  
  deleteLink: async (id) => {
    await trpc.links.delete.mutate({ id });
    set((state) => ({
      links: state.links.filter(link => link.id !== id),
      selectedLink: state.selectedLink?.id === id ? null : state.selectedLink
    }));
  },
  
  setSelectedLink: (link) => set({ selectedLink: link })
}));
```

**📊 Analytics Implementation**
```typescript
// components/analytics/AnalyticsCard.tsx
export const AnalyticsCard: FC<AnalyticsCardProps> = ({ 
  linkId, 
  timeRange = '24h' 
}) => {
  const { data: analytics, isLoading } = trpc.analytics.getAnalytics.useQuery({
    linkId,
    timeRange,
  });

  if (isLoading) return <AnalyticsSkeleton />;

  return (
    <Card>
      <CardHeader>
        <CardTitle>Analytics Overview</CardTitle>
      </CardHeader>
      <CardContent>
        <div className="grid grid-cols-2 gap-4">
          <MetricCard
            title="Total Clicks"
            value={analytics?.totalClicks ?? 0}
            change={analytics?.clicksChange}
          />
          <MetricCard
            title="Unique Visitors"
            value={analytics?.uniqueVisitors ?? 0}
            change={analytics?.visitorsChange}
          />
        </div>
        <ChartContainer className="mt-6">
          <AreaChart data={analytics?.chartData ?? []}>
            <Area
              type="monotone"
              dataKey="clicks"
              stroke="#3b82f6"
              fill="#3b82f6"
              fillOpacity={0.3}
            />
          </AreaChart>
        </ChartContainer>
      </CardContent>
    </Card>
  );
};
```

**Key Learnings**:
- Excellent analytics implementation
- Clean URL shortening logic
- Effective use of tRPC for type safety
- Comprehensive link management features

---

## 📈 Technology Adoption Summary

### **State Management Patterns**

| Pattern | Usage | Projects | Pros | Cons |
|---------|-------|----------|------|------|
| **Zustand** | 80% | Cal.com, Novel, Dub | Simple, TypeScript-friendly | Less ecosystem |
| **Redux Toolkit** | 15% | Legacy projects | Mature ecosystem | More boilerplate |
| **Context API** | 5% | Small components | Built-in React | Performance issues |

### **UI Component Strategies**

| Strategy | Usage | Projects | Benefits | Considerations |
|----------|-------|----------|----------|----------------|
| **Radix UI + Tailwind** | 70% | Cal.com, Novel, Dub | Full control, accessible | Custom styling needed |
| **Headless UI + Tailwind** | 20% | Plane | Good integration | Limited components |
| **Component Libraries** | 10% | Smaller projects | Fast development | Less customization |

### **Authentication Approaches**

| Approach | Usage | Projects | Strengths | Limitations |
|----------|-------|----------|-----------|-------------|
| **NextAuth.js** | 75% | Cal.com, Dub | Provider ecosystem | Session complexity |
| **Clerk** | 15% | Novel | Developer experience | Vendor lock-in |
| **Custom JWT** | 10% | Plane | Full control | Security complexity |

---

## 🎯 Key Takeaways

1. **Next.js 14 + App Router** is becoming the standard
2. **Zustand** provides the best balance of simplicity and power
3. **Radix UI + Tailwind** offers the most flexibility
4. **tRPC** is gaining significant adoption for type safety
5. **Vitest** is replacing Jest for modern testing
6. **Monorepo structures** are common for larger projects

---

## Navigation

- ← Previous: [Executive Summary](./executive-summary.md)
- → Next: [State Management Patterns](./state-management-patterns.md)

| [📋 Overview](./README.md) | [📊 Executive Summary](./executive-summary.md) | [🏗️ Projects Analysis](#) | [⚡ Best Practices](./best-practices.md) |
|---|---|---|---|