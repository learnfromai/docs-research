# Project Showcases - Open Source React/Next.js Analysis

## 🎯 Overview

This document provides detailed analysis of production-ready open source projects built with React and Next.js, examining their architecture, technology choices, and implementation patterns.

## 📊 Featured Projects Database

### **Admin Dashboards & Enterprise Tools**

#### **1. Refine** ⭐ 29.8k stars
**Repository**: [refinedev/refine](https://github.com/refinedev/refine)  
**Tech Stack**: React, TypeScript, Ant Design, React Query, React Router  
**Use Case**: Enterprise admin panel framework

**Key Learnings**:
- **State Management**: Heavy use of React Query for server state, minimal global client state
- **Architecture**: Plugin-based architecture with data providers and auth providers
- **Component Strategy**: Comprehensive component abstraction for CRUD operations
- **TypeScript**: Extensive use with strict typing for data providers and hooks
- **Code Organization**: Modular package structure with separate core, UI, and data provider packages

```typescript
// Example: Data Provider Pattern from Refine
import { DataProvider } from "@refinedev/core";

const dataProvider: DataProvider = {
    getList: async ({ resource, pagination, filters, sorters, meta }) => {
        // Implementation for fetching list data
        const response = await api.get(`/${resource}`, {
            params: { ...pagination, ...filters, ...sorters }
        });
        return {
            data: response.data,
            total: response.total,
        };
    },
    // Other CRUD methods...
};
```

#### **2. React Admin** ⭐ 24.5k stars
**Repository**: [marmelab/react-admin](https://github.com/marmelab/react-admin)  
**Tech Stack**: React, Material-UI, React Hook Form, React Query  
**Use Case**: Admin interface framework

**Key Learnings**:
- **Form Management**: Sophisticated form handling with React Hook Form integration
- **Data Provider**: Clean abstraction for different API patterns (REST, GraphQL)
- **Permission System**: Role-based access control with fine-grained permissions
- **Customization**: Highly customizable with theme and component override patterns

```typescript
// Example: Resource Definition Pattern
<Admin dataProvider={dataProvider}>
    <Resource 
        name="users" 
        list={UserList} 
        edit={UserEdit} 
        create={UserCreate}
        show={UserShow}
    />
</Admin>
```

#### **3. Twenty** ⭐ 23.1k stars
**Repository**: [twentyhq/twenty](https://github.com/twentyhq/twenty)  
**Tech Stack**: Next.js, TypeScript, GraphQL, Recoil, Styled Components  
**Use Case**: Modern CRM platform

**Key Learnings**:
- **State Management**: Recoil for complex state management with atomic state design
- **GraphQL Integration**: Full GraphQL stack with code generation and type safety
- **Component Architecture**: Atomic design principles with comprehensive design system
- **Performance**: Optimized queries and efficient re-rendering patterns

```typescript
// Example: Recoil State Pattern
const currentUserState = atom({
  key: 'currentUserState',
  default: null,
});

const useCurrentUser = () => {
  return useRecoilValue(currentUserState);
};
```

### **E-commerce & SaaS Platforms**

#### **4. Medusa** ⭐ 25.2k stars
**Repository**: [medusajs/medusa](https://github.com/medusajs/medusa)  
**Tech Stack**: Next.js, TypeScript, Tailwind CSS, Zustand  
**Use Case**: Composable commerce platform

**Key Learnings**:
- **State Management**: Zustand for lightweight state management
- **API Integration**: RESTful API with comprehensive TypeScript SDK
- **Component Design**: Headless commerce patterns with flexible UI components
- **Performance**: Optimized for e-commerce with product catalog optimization

```typescript
// Example: Zustand Store Pattern
import { create } from 'zustand';

interface CartStore {
  items: CartItem[];
  addItem: (item: CartItem) => void;
  removeItem: (id: string) => void;
  clearCart: () => void;
}

const useCartStore = create<CartStore>((set) => ({
  items: [],
  addItem: (item) => set((state) => ({ 
    items: [...state.items, item] 
  })),
  removeItem: (id) => set((state) => ({ 
    items: state.items.filter(item => item.id !== id) 
  })),
  clearCart: () => set({ items: [] }),
}));
```

#### **5. Cal.com** ⭐ 32.1k stars
**Repository**: [calcom/cal.com](https://github.com/calcom/cal.com)  
**Tech Stack**: Next.js, TypeScript, Prisma, Tailwind CSS, React Hook Form  
**Use Case**: Scheduling infrastructure

**Key Learnings**:
- **Database Integration**: Prisma ORM with type-safe database operations
- **Form Validation**: Zod schema validation with React Hook Form
- **API Design**: tRPC for end-to-end type safety
- **Authentication**: NextAuth.js with multiple provider support

```typescript
// Example: tRPC Router Pattern
import { z } from 'zod';
import { router, publicProcedure } from '../trpc';

export const bookingRouter = router({
  create: publicProcedure
    .input(z.object({
      eventTypeId: z.number(),
      startTime: z.date(),
      endTime: z.date(),
    }))
    .mutation(async ({ input, ctx }) => {
      return await ctx.prisma.booking.create({
        data: input,
      });
    }),
});
```

### **Developer Tools & Platforms**

#### **6. Supabase Dashboard** ⭐ 73k stars
**Repository**: [supabase/supabase](https://github.com/supabase/supabase)  
**Tech Stack**: Next.js, TypeScript, Tailwind CSS, React Query  
**Use Case**: Database platform dashboard

**Key Learnings**:
- **Real-time Features**: WebSocket integration for live data updates
- **Database UI**: Complex table and query builder interfaces
- **Performance**: Virtualized lists for large datasets
- **User Experience**: Sophisticated loading states and error handling

#### **7. Plane** ⭐ 30.2k stars
**Repository**: [makeplane/plane](https://github.com/makeplane/plane)  
**Tech Stack**: Next.js, TypeScript, Tailwind CSS, SWR  
**Use Case**: Project management tool

**Key Learnings**:
- **SWR Usage**: Comprehensive data fetching with SWR for optimistic updates
- **Drag & Drop**: Complex interaction patterns with react-beautiful-dnd
- **Real-time Collaboration**: WebSocket integration for collaborative features
- **State Synchronization**: Sophisticated offline/online state management

```typescript
// Example: SWR with Optimistic Updates
import useSWR, { mutate } from 'swr';

const useIssues = (projectId: string) => {
  const { data, error } = useSWR(
    `/api/projects/${projectId}/issues`,
    fetcher
  );

  const createIssue = async (issueData: CreateIssueData) => {
    // Optimistic update
    mutate(
      `/api/projects/${projectId}/issues`,
      (current) => [...(current || []), { ...issueData, id: 'temp' }],
      false
    );

    try {
      const newIssue = await api.post(`/projects/${projectId}/issues`, issueData);
      mutate(`/api/projects/${projectId}/issues`);
      return newIssue;
    } catch (error) {
      // Revert on error
      mutate(`/api/projects/${projectId}/issues`);
      throw error;
    }
  };

  return { issues: data, error, createIssue };
};
```

### **Content & Community Platforms**

#### **8. Docusaurus** ⭐ 56.3k stars
**Repository**: [facebook/docusaurus](https://github.com/facebook/docusaurus)  
**Tech Stack**: React, TypeScript, MDX  
**Use Case**: Documentation platform

**Key Learnings**:
- **Static Generation**: Optimized static site generation with React hydration
- **Plugin Architecture**: Extensible plugin system for documentation features
- **Theming**: Sophisticated theming system with CSS custom properties
- **Performance**: Optimized bundle splitting and lazy loading

#### **9. Mattermost** ⭐ 30.5k stars
**Repository**: [mattermost/mattermost](https://github.com/mattermost/mattermost)  
**Tech Stack**: React, Redux, TypeScript  
**Use Case**: Team communication platform

**Key Learnings**:
- **Redux Architecture**: Large-scale Redux implementation with normalized state
- **Real-time Communication**: WebSocket integration for chat features
- **Performance Optimization**: Virtual scrolling for message lists
- **Modular Architecture**: Plugin system for extending functionality

```typescript
// Example: Redux Toolkit Slice Pattern
import { createSlice, createAsyncThunk } from '@reduxjs/toolkit';

export const fetchPosts = createAsyncThunk(
  'posts/fetchPosts',
  async (channelId: string) => {
    const response = await api.get(`/channels/${channelId}/posts`);
    return response.data;
  }
);

const postsSlice = createSlice({
  name: 'posts',
  initialState: {
    byId: {},
    loading: false,
    error: null,
  },
  reducers: {
    addPost: (state, action) => {
      state.byId[action.payload.id] = action.payload;
    },
  },
  extraReducers: (builder) => {
    builder
      .addCase(fetchPosts.pending, (state) => {
        state.loading = true;
      })
      .addCase(fetchPosts.fulfilled, (state, action) => {
        state.loading = false;
        action.payload.forEach(post => {
          state.byId[post.id] = post;
        });
      });
  },
});
```

### **Design & Creative Tools**

#### **10. Penpot** ⭐ 33.1k stars
**Repository**: [penpot/penpot](https://github.com/penpot/penpot)  
**Tech Stack**: ClojureScript, React (via Rum)  
**Use Case**: Design and prototyping platform

**Key Learnings**:
- **Canvas Performance**: High-performance canvas rendering for design tools
- **State Management**: Immutable state management for undo/redo functionality
- **Real-time Collaboration**: Operational transformation for collaborative editing
- **Complex UI**: Sophisticated design tool interface patterns

## 📈 Project Analysis Summary

### **State Management Patterns**

| Pattern | Projects Using | Best For |
|---------|---------------|----------|
| **React Query/SWR** | Refine, Supabase, Plane | Server state management |
| **Redux Toolkit** | Mattermost, Large apps | Complex client state |
| **Zustand** | Medusa, Medium apps | Lightweight global state |
| **Recoil** | Twenty | Atomic state management |
| **Context API** | Smaller projects | Simple shared state |

### **UI/Component Strategies**

| Approach | Projects | Benefits |
|----------|----------|----------|
| **Design System** | Twenty, Plane | Consistency, scalability |
| **Component Library** | React Admin, Refine | Rapid development |
| **Utility-First CSS** | Cal.com, Medusa | Flexibility, performance |
| **CSS-in-JS** | Twenty, Styled components | Dynamic styling |

### **Authentication Patterns**

| Pattern | Projects | Use Cases |
|---------|----------|-----------|
| **NextAuth.js** | Cal.com, Many Next.js apps | Social login, JWT |
| **Custom JWT** | Medusa, API-first apps | Flexibility, control |
| **Third-party (Auth0)** | Enterprise apps | Enterprise features |
| **Database sessions** | Traditional apps | Simple, secure |

## 🔗 Navigation

← [README](./README.md) | [State Management Patterns →](./state-management-patterns.md)

---

## 📚 References

1. [Refine Documentation](https://refine.dev/docs/)
2. [React Admin Documentation](https://marmelab.com/react-admin/)
3. [Twenty Architecture Guide](https://twenty.com/developers)
4. [Medusa Development Guide](https://medusajs.com/learn/)
5. [Cal.com Contributing Guide](https://cal.com/docs/contributing)
6. [Supabase Dashboard Source](https://github.com/supabase/supabase/tree/master/studio)
7. [Plane Development Docs](https://docs.plane.so/)
8. [Docusaurus Architecture](https://docusaurus.io/docs/architecture)

*Last updated: January 2025*