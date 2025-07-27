# State Management Patterns in Open Source React/Next.js Projects

## Overview

This comprehensive analysis examines state management patterns used in production React and Next.js applications, focusing on Zustand, Redux Toolkit, Context API, and server state management solutions. The patterns are extracted from successful open source projects and demonstrate real-world implementation strategies.

## Client State vs Server State Separation

### Modern Approach: Separate Concerns

**Client State**: UI state, form data, temporary user preferences
**Server State**: API data, cached responses, real-time subscriptions

| Project | Client State Solution | Server State Solution | Separation Strategy |
|---------|----------------------|----------------------|-------------------|
| **Cal.com** | Zustand | TanStack Query | Clear domain boundaries |
| **Plane** | Zustand + MobX-State-Tree | Custom API layer | Feature-based stores |
| **Supabase** | Context API | React Query | Minimal client state |
| **Vercel Commerce** | Context API | SWR | Commerce-specific patterns |

## Zustand Patterns and Best Practices

### 1. Store Organization Patterns

**Single Store Approach** (Simple applications):
```typescript
interface AppStore {
  // User state
  user: User | null;
  isAuthenticated: boolean;
  
  // UI state
  sidebarOpen: boolean;
  theme: 'light' | 'dark';
  
  // Actions
  setUser: (user: User | null) => void;
  toggleSidebar: () => void;
  setTheme: (theme: 'light' | 'dark') => void;
}

const useAppStore = create<AppStore>((set, get) => ({
  user: null,
  isAuthenticated: false,
  sidebarOpen: false,
  theme: 'light',
  
  setUser: (user) => set({ user, isAuthenticated: !!user }),
  toggleSidebar: () => set((state) => ({ sidebarOpen: !state.sidebarOpen })),
  setTheme: (theme) => set({ theme }),
}));
```

**Multiple Store Approach** (Cal.com pattern):
```typescript
// User Store
interface UserStore {
  user: User | null;
  preferences: UserPreferences;
  setUser: (user: User) => void;
  updatePreferences: (prefs: Partial<UserPreferences>) => void;
}

export const useUserStore = create<UserStore>()(
  devtools(
    persist(
      (set, get) => ({
        user: null,
        preferences: {},
        setUser: (user) => set({ user }),
        updatePreferences: (prefs) => 
          set((state) => ({ 
            preferences: { ...state.preferences, ...prefs } 
          })),
      }),
      { name: 'user-storage' }
    ),
    { name: 'user-store' }
  )
);

// Booking Store (Feature-specific)
interface BookingStore {
  selectedDate: Date | null;
  selectedSlot: TimeSlot | null;
  bookingForm: BookingFormData;
  setSelectedDate: (date: Date) => void;
  setSelectedSlot: (slot: TimeSlot) => void;
  updateBookingForm: (data: Partial<BookingFormData>) => void;
  resetBooking: () => void;
}

export const useBookingStore = create<BookingStore>()(
  devtools(
    (set, get) => ({
      selectedDate: null,
      selectedSlot: null,
      bookingForm: {},
      
      setSelectedDate: (date) => set({ selectedDate: date }),
      setSelectedSlot: (slot) => set({ selectedSlot: slot }),
      updateBookingForm: (data) =>
        set((state) => ({ 
          bookingForm: { ...state.bookingForm, ...data } 
        })),
      resetBooking: () => set({
        selectedDate: null,
        selectedSlot: null,
        bookingForm: {},
      }),
    }),
    { name: 'booking-store' }
  )
);
```

### 2. Advanced Zustand Patterns

**Store Slicing and Composition** (Plane pattern):
```typescript
// Base slice creator
interface StateCreator<T> {
  (set: SetState<T>, get: GetState<T>): T;
}

// User slice
interface UserSlice {
  user: User | null;
  setUser: (user: User) => void;
}

const createUserSlice: StateCreator<UserSlice> = (set) => ({
  user: null,
  setUser: (user) => set({ user }),
});

// Project slice
interface ProjectSlice {
  projects: Project[];
  currentProject: Project | null;
  setProjects: (projects: Project[]) => void;
  setCurrentProject: (project: Project) => void;
}

const createProjectSlice: StateCreator<ProjectSlice> = (set) => ({
  projects: [],
  currentProject: null,
  setProjects: (projects) => set({ projects }),
  setCurrentProject: (project) => set({ currentProject: project }),
});

// Combined store
type AppState = UserSlice & ProjectSlice;

export const useAppStore = create<AppState>()(
  devtools(
    (...args) => ({
      ...createUserSlice(...args),
      ...createProjectSlice(...args),
    }),
    { name: 'app-store' }
  )
);
```

**Computed Values and Selectors**:
```typescript
interface TaskStore {
  tasks: Task[];
  filters: TaskFilters;
  addTask: (task: Task) => void;
  updateFilters: (filters: Partial<TaskFilters>) => void;
}

export const useTaskStore = create<TaskStore>((set, get) => ({
  tasks: [],
  filters: { status: 'all', priority: 'all' },
  
  addTask: (task) => set((state) => ({ 
    tasks: [...state.tasks, task] 
  })),
  updateFilters: (filters) => set((state) => ({ 
    filters: { ...state.filters, ...filters } 
  })),
}));

// Selectors for computed values
export const useFilteredTasks = () => {
  return useTaskStore((state) => {
    const { tasks, filters } = state;
    return tasks.filter(task => {
      if (filters.status !== 'all' && task.status !== filters.status) {
        return false;
      }
      if (filters.priority !== 'all' && task.priority !== filters.priority) {
        return false;
      }
      return true;
    });
  });
};

export const useTaskStats = () => {
  return useTaskStore((state) => {
    const tasks = state.tasks;
    return {
      total: tasks.length,
      completed: tasks.filter(t => t.status === 'completed').length,
      pending: tasks.filter(t => t.status === 'pending').length,
    };
  });
};
```

### 3. Persistence and Hydration

**Selective Persistence**:
```typescript
export const useSettingsStore = create<SettingsStore>()(
  persist(
    (set, get) => ({
      theme: 'light',
      language: 'en',
      notifications: true,
      temporaryData: null, // Won't be persisted
      
      setTheme: (theme) => set({ theme }),
      setLanguage: (language) => set({ language }),
      setNotifications: (notifications) => set({ notifications }),
    }),
    {
      name: 'settings-storage',
      partialize: (state) => ({
        theme: state.theme,
        language: state.language,
        notifications: state.notifications,
        // temporaryData is excluded
      }),
    }
  )
);
```

**Hydration Handling in Next.js**:
```typescript
import { useEffect, useState } from 'react';

export const useHydratedStore = <T>(
  store: UseBoundStore<StoreApi<T>>,
  callback: (state: T) => unknown
) => {
  const result = store(callback);
  const [hydrated, setHydrated] = useState(false);

  useEffect(() => {
    setHydrated(true);
  }, []);

  return hydrated ? result : undefined;
};

// Usage
function Component() {
  const user = useHydratedStore(useUserStore, (state) => state.user);
  
  if (user === undefined) {
    return <div>Loading...</div>;
  }
  
  return <div>Welcome, {user.name}</div>;
}
```

## Redux Toolkit Patterns

### 1. Modern Redux Structure (Storybook pattern)

**Store Configuration**:
```typescript
import { configureStore } from '@reduxjs/toolkit';
import { setupListeners } from '@reduxjs/toolkit/query';
import { apiSlice } from './api/apiSlice';
import authSlice from './slices/authSlice';
import uiSlice from './slices/uiSlice';

export const store = configureStore({
  reducer: {
    auth: authSlice,
    ui: uiSlice,
    api: apiSlice.reducer,
  },
  middleware: (getDefaultMiddleware) =>
    getDefaultMiddleware({
      serializableCheck: {
        ignoredActions: ['persist/PERSIST', 'persist/REHYDRATE'],
      },
    }).concat(apiSlice.middleware),
});

setupListeners(store.dispatch);

export type RootState = ReturnType<typeof store.getState>;
export type AppDispatch = typeof store.dispatch;
```

**Feature Slice Pattern**:
```typescript
import { createSlice, PayloadAction } from '@reduxjs/toolkit';

interface AuthState {
  user: User | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  error: string | null;
}

const initialState: AuthState = {
  user: null,
  isAuthenticated: false,
  isLoading: false,
  error: null,
};

const authSlice = createSlice({
  name: 'auth',
  initialState,
  reducers: {
    loginStart: (state) => {
      state.isLoading = true;
      state.error = null;
    },
    loginSuccess: (state, action: PayloadAction<User>) => {
      state.isLoading = false;
      state.user = action.payload;
      state.isAuthenticated = true;
      state.error = null;
    },
    loginFailure: (state, action: PayloadAction<string>) => {
      state.isLoading = false;
      state.error = action.payload;
      state.isAuthenticated = false;
    },
    logout: (state) => {
      state.user = null;
      state.isAuthenticated = false;
      state.error = null;
    },
  },
});

export const { loginStart, loginSuccess, loginFailure, logout } = authSlice.actions;
export default authSlice.reducer;
```

### 2. RTK Query for Server State

**API Slice Definition**:
```typescript
import { createApi, fetchBaseQuery } from '@reduxjs/toolkit/query/react';

export const apiSlice = createApi({
  reducerPath: 'api',
  baseQuery: fetchBaseQuery({
    baseUrl: '/api',
    prepareHeaders: (headers, { getState }) => {
      const token = (getState() as RootState).auth.token;
      if (token) {
        headers.set('authorization', `Bearer ${token}`);
      }
      return headers;
    },
  }),
  tagTypes: ['Project', 'Task', 'User'],
  endpoints: (builder) => ({
    getProjects: builder.query<Project[], void>({
      query: () => '/projects',
      providesTags: ['Project'],
    }),
    getProject: builder.query<Project, string>({
      query: (id) => `/projects/${id}`,
      providesTags: (result, error, id) => [{ type: 'Project', id }],
    }),
    createProject: builder.mutation<Project, Partial<Project>>({
      query: (newProject) => ({
        url: '/projects',
        method: 'POST',
        body: newProject,
      }),
      invalidatesTags: ['Project'],
    }),
    updateProject: builder.mutation<Project, { id: string; data: Partial<Project> }>({
      query: ({ id, data }) => ({
        url: `/projects/${id}`,
        method: 'PUT',
        body: data,
      }),
      invalidatesTags: (result, error, { id }) => [{ type: 'Project', id }],
    }),
  }),
});

export const {
  useGetProjectsQuery,
  useGetProjectQuery,
  useCreateProjectMutation,
  useUpdateProjectMutation,
} = apiSlice;
```

## Context API Patterns

### 1. Theme Context (Mantine pattern)

```typescript
import { createContext, useContext, useReducer, ReactNode } from 'react';

interface ThemeState {
  colorScheme: 'light' | 'dark';
  primaryColor: string;
  fontSize: 'sm' | 'md' | 'lg';
}

type ThemeAction =
  | { type: 'SET_COLOR_SCHEME'; payload: 'light' | 'dark' }
  | { type: 'SET_PRIMARY_COLOR'; payload: string }
  | { type: 'SET_FONT_SIZE'; payload: 'sm' | 'md' | 'lg' };

const themeReducer = (state: ThemeState, action: ThemeAction): ThemeState => {
  switch (action.type) {
    case 'SET_COLOR_SCHEME':
      return { ...state, colorScheme: action.payload };
    case 'SET_PRIMARY_COLOR':
      return { ...state, primaryColor: action.payload };
    case 'SET_FONT_SIZE':
      return { ...state, fontSize: action.payload };
    default:
      return state;
  }
};

const ThemeContext = createContext<{
  state: ThemeState;
  dispatch: React.Dispatch<ThemeAction>;
} | null>(null);

export function ThemeProvider({ children }: { children: ReactNode }) {
  const [state, dispatch] = useReducer(themeReducer, {
    colorScheme: 'light',
    primaryColor: 'blue',
    fontSize: 'md',
  });

  return (
    <ThemeContext.Provider value={{ state, dispatch }}>
      {children}
    </ThemeContext.Provider>
  );
}

export function useTheme() {
  const context = useContext(ThemeContext);
  if (!context) {
    throw new Error('useTheme must be used within a ThemeProvider');
  }
  return context;
}

// Hook for specific theme actions
export function useThemeActions() {
  const { dispatch } = useTheme();
  
  return {
    setColorScheme: (scheme: 'light' | 'dark') =>
      dispatch({ type: 'SET_COLOR_SCHEME', payload: scheme }),
    setPrimaryColor: (color: string) =>
      dispatch({ type: 'SET_PRIMARY_COLOR', payload: color }),
    setFontSize: (size: 'sm' | 'md' | 'lg') =>
      dispatch({ type: 'SET_FONT_SIZE', payload: size }),
  };
}
```

### 2. Performance Optimization with Context

**Split Context for Performance**:
```typescript
// Separate contexts for values that change at different frequencies
const UserContext = createContext<User | null>(null);
const UserActionsContext = createContext<{
  updateUser: (user: User) => void;
  logout: () => void;
} | null>(null);

export function UserProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  
  const actions = useMemo(() => ({
    updateUser: (user: User) => setUser(user),
    logout: () => setUser(null),
  }), []);

  return (
    <UserContext.Provider value={user}>
      <UserActionsContext.Provider value={actions}>
        {children}
      </UserActionsContext.Provider>
    </UserContext.Provider>
  );
}

// Separate hooks to avoid unnecessary re-renders
export const useUser = () => useContext(UserContext);
export const useUserActions = () => useContext(UserActionsContext);
```

## Server State Management Patterns

### 1. TanStack Query Patterns (Cal.com & Supabase)

**Basic Query Setup**:
```typescript
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';

// Query with proper error handling
export function useProjects() {
  return useQuery({
    queryKey: ['projects'],
    queryFn: async () => {
      const response = await fetch('/api/projects');
      if (!response.ok) {
        throw new Error('Failed to fetch projects');
      }
      return response.json();
    },
    staleTime: 5 * 60 * 1000, // 5 minutes
    gcTime: 10 * 60 * 1000, // 10 minutes
    retry: (failureCount, error) => {
      if (error.message.includes('404')) return false;
      return failureCount < 3;
    },
  });
}

// Mutation with optimistic updates
export function useCreateProject() {
  const queryClient = useQueryClient();
  
  return useMutation({
    mutationFn: async (newProject: Partial<Project>) => {
      const response = await fetch('/api/projects', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(newProject),
      });
      return response.json();
    },
    onMutate: async (newProject) => {
      // Cancel outgoing refetches
      await queryClient.cancelQueries({ queryKey: ['projects'] });
      
      // Snapshot previous value
      const previousProjects = queryClient.getQueryData(['projects']);
      
      // Optimistically update
      queryClient.setQueryData(['projects'], (old: Project[] = []) => [
        ...old,
        { ...newProject, id: Date.now().toString() },
      ]);
      
      return { previousProjects };
    },
    onError: (err, newProject, context) => {
      // Rollback on error
      queryClient.setQueryData(['projects'], context?.previousProjects);
    },
    onSettled: () => {
      // Always refetch after error or success
      queryClient.invalidateQueries({ queryKey: ['projects'] });
    },
  });
}
```

**Real-time Subscriptions** (Supabase pattern):
```typescript
import { useEffect } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { supabase } from '@/lib/supabase';

export function useProjectSubscription() {
  const queryClient = useQueryClient();
  
  useEffect(() => {
    const subscription = supabase
      .channel('projects')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'projects' },
        (payload) => {
          // Update cache based on the event
          if (payload.eventType === 'INSERT') {
            queryClient.setQueryData(['projects'], (old: Project[] = []) => [
              ...old,
              payload.new as Project,
            ]);
          } else if (payload.eventType === 'UPDATE') {
            queryClient.setQueryData(['projects'], (old: Project[] = []) =>
              old.map(project =>
                project.id === payload.new.id ? payload.new as Project : project
              )
            );
          } else if (payload.eventType === 'DELETE') {
            queryClient.setQueryData(['projects'], (old: Project[] = []) =>
              old.filter(project => project.id !== payload.old.id)
            );
          }
        }
      )
      .subscribe();

    return () => {
      subscription.unsubscribe();
    };
  }, [queryClient]);
}
```

### 2. SWR Patterns (Vercel Commerce)

**Basic SWR with Error Handling**:
```typescript
import useSWR from 'swr';

const fetcher = async (url: string) => {
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error('Failed to fetch');
  }
  return response.json();
};

export function useProducts() {
  const { data, error, mutate } = useSWR('/api/products', fetcher, {
    revalidateOnFocus: false,
    revalidateOnReconnect: true,
    refreshInterval: 0,
    errorRetryCount: 3,
  });

  return {
    products: data,
    isLoading: !error && !data,
    isError: error,
    mutate,
  };
}

// Infinite loading pattern
export function useInfiniteProducts() {
  const { data, error, size, setSize } = useSWRInfinite(
    (index) => `/api/products?page=${index + 1}`,
    fetcher
  );

  const products = data ? data.flat() : [];
  const isLoadingInitial = !data && !error;
  const isLoadingMore = data && typeof data[size - 1] === 'undefined';
  const isEmpty = data?.[0]?.length === 0;
  const isReachingEnd = isEmpty || (data && data[data.length - 1]?.length < 20);

  return {
    products,
    error,
    isLoadingInitial,
    isLoadingMore,
    isEmpty,
    isReachingEnd,
    loadMore: () => setSize(size + 1),
  };
}
```

## State Management Decision Tree

### Choosing the Right Solution

```
Start Here: What type of state?
│
├── Server State (API data, cache)
│   ├── Complex real-time needs → TanStack Query + Subscriptions
│   ├── Simple data fetching → SWR
│   └── Heavy caching needs → RTK Query
│
└── Client State (UI, forms, preferences)
    ├── Simple global state → Context API
    ├── Medium complexity → Zustand
    ├── Complex enterprise app → Redux Toolkit
    └── Performance critical → Multiple Zustand stores
```

### Complexity vs Solution Matrix

| Complexity Level | Client State | Server State | Example Projects |
|-----------------|-------------|--------------|------------------|
| **Simple** | Context API | SWR | Landing pages, blogs |
| **Medium** | Zustand | TanStack Query | Dashboards, SaaS apps |
| **Complex** | Redux Toolkit | RTK Query | Enterprise apps, IDEs |
| **Mixed** | Zustand + Context | TanStack Query | Cal.com, Plane |

## Performance Considerations

### 1. Re-render Optimization

**Zustand Selectors**:
```typescript
// Bad: Component re-renders on any store change
const { user, projects, settings } = useAppStore();

// Good: Component only re-renders when user changes
const user = useAppStore((state) => state.user);
```

**React Query Select**:
```typescript
// Bad: Re-renders on any data change
const { data } = useProjectsQuery();

// Good: Only re-renders when specific field changes
const projectNames = useProjectsQuery({
  select: (data) => data.map(project => project.name),
});
```

### 2. Memory Management

**Cleanup Patterns**:
```typescript
export const useProjectStore = create<ProjectStore>((set, get) => ({
  projects: [],
  cleanup: () => set({ projects: [] }),
}));

// In component
useEffect(() => {
  return () => {
    // Cleanup when component unmounts
    useProjectStore.getState().cleanup();
  };
}, []);
```

---

## Navigation

- ← Back to: [Implementation Guide](implementation-guide.md)
- → Next: [Authentication Strategies](authentication-strategies.md)
- 🏠 Home: [Research Overview](../../README.md)