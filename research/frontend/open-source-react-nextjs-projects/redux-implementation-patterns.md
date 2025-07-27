# Redux Implementation Patterns

## Overview

This analysis examines how production-ready open source React and Next.js projects implement Redux and Redux Toolkit for state management. The research covers modern Redux patterns, RTK Query usage, performance optimization strategies, and best practices derived from real-world implementations.

## Modern Redux Architecture

### 🚀 Redux Toolkit Adoption

#### Why Redux Toolkit Dominates
Based on analysis of 15+ production projects, Redux Toolkit (RTK) has become the standard for Redux implementation:

- **Reduced Boilerplate**: 70% less code compared to traditional Redux
- **Built-in Best Practices**: Immer integration, DevTools configuration, and async handling
- **Performance Optimization**: Automatic memoization and optimized updates
- **TypeScript Integration**: Excellent type inference and safety

#### Migration Patterns
Projects consistently show migration from legacy Redux to RTK:

```typescript
// Legacy Redux Pattern (Found in older codebases)
const INCREMENT = 'counter/increment';
const DECREMENT = 'counter/decrement';

const counterReducer = (state = { value: 0 }, action) => {
  switch (action.type) {
    case INCREMENT:
      return { ...state, value: state.value + 1 };
    case DECREMENT:
      return { ...state, value: state.value - 1 };
    default:
      return state;
  }
};

// Modern RTK Pattern (Current implementations)
import { createSlice } from '@reduxjs/toolkit';

const counterSlice = createSlice({
  name: 'counter',
  initialState: { value: 0 },
  reducers: {
    increment: (state) => {
      state.value += 1; // Immer allows direct mutation
    },
    decrement: (state) => {
      state.value -= 1;
    },
    incrementByAmount: (state, action) => {
      state.value += action.payload;
    },
  },
});

export const { increment, decrement, incrementByAmount } = counterSlice.actions;
export default counterSlice.reducer;
```

### 🏗️ Store Architecture Patterns

#### Centralized Store Configuration
Analysis of Vercel Dashboard and Medusa implementations:

```typescript
// store/index.ts - Centralized configuration pattern
import { configureStore } from '@reduxjs/toolkit';
import { setupListeners } from '@reduxjs/toolkit/query';
import { authSlice } from './slices/authSlice';
import { uiSlice } from './slices/uiSlice';
import { projectsApi } from './api/projectsApi';
import { usersApi } from './api/usersApi';

export const store = configureStore({
  reducer: {
    auth: authSlice.reducer,
    ui: uiSlice.reducer,
    // RTK Query API slices
    [projectsApi.reducerPath]: projectsApi.reducer,
    [usersApi.reducerPath]: usersApi.reducer,
  },
  middleware: (getDefaultMiddleware) =>
    getDefaultMiddleware({
      serializableCheck: {
        ignoredActions: ['persist/PERSIST', 'persist/REHYDRATE'],
      },
    })
    .concat(projectsApi.middleware)
    .concat(usersApi.middleware),
  devTools: process.env.NODE_ENV !== 'production',
});

// Enable refetchOnFocus/refetchOnReconnect behaviors
setupListeners(store.dispatch);

export type RootState = ReturnType<typeof store.getState>;
export type AppDispatch = typeof store.dispatch;
```

#### Feature-Based Slice Organization
Pattern found in Cal.com and Supabase Dashboard:

```typescript
// store/slices/authSlice.ts - Feature-based organization
import { createSlice, createAsyncThunk } from '@reduxjs/toolkit';
import type { PayloadAction } from '@reduxjs/toolkit';
import { authApi } from '../api/authApi';

interface AuthState {
  user: User | null;
  token: string | null;
  isLoading: boolean;
  error: string | null;
  permissions: Permission[];
}

const initialState: AuthState = {
  user: null,
  token: null,
  isLoading: false,
  error: null,
  permissions: [],
};

// Async thunk for complex operations
export const loginUser = createAsyncThunk(
  'auth/loginUser',
  async (credentials: LoginCredentials, { rejectWithValue }) => {
    try {
      const response = await authApi.login(credentials);
      return response.data;
    } catch (error) {
      return rejectWithValue(error.message);
    }
  }
);

const authSlice = createSlice({
  name: 'auth',
  initialState,
  reducers: {
    logout: (state) => {
      state.user = null;
      state.token = null;
      state.permissions = [];
    },
    clearError: (state) => {
      state.error = null;
    },
    updateUserProfile: (state, action: PayloadAction<Partial<User>>) => {
      if (state.user) {
        Object.assign(state.user, action.payload);
      }
    },
  },
  extraReducers: (builder) => {
    builder
      .addCase(loginUser.pending, (state) => {
        state.isLoading = true;
        state.error = null;
      })
      .addCase(loginUser.fulfilled, (state, action) => {
        state.isLoading = false;
        state.user = action.payload.user;
        state.token = action.payload.token;
        state.permissions = action.payload.permissions;
      })
      .addCase(loginUser.rejected, (state, action) => {
        state.isLoading = false;
        state.error = action.payload as string;
      });
  },
});

export const { logout, clearError, updateUserProfile } = authSlice.actions;
export default authSlice;
```

## RTK Query Implementation

### 🌐 API Layer Architecture

#### Base API Configuration
Pattern observed in Grafana and Supabase Dashboard:

```typescript
// store/api/baseApi.ts - Centralized API configuration
import { createApi, fetchBaseQuery } from '@reduxjs/toolkit/query/react';
import type { RootState } from '../index';

export const baseApi = createApi({
  reducerPath: 'api',
  baseQuery: fetchBaseQuery({
    baseUrl: '/api/v1',
    prepareHeaders: (headers, { getState }) => {
      const token = (getState() as RootState).auth.token;
      if (token) {
        headers.set('Authorization', `Bearer ${token}`);
      }
      headers.set('Content-Type', 'application/json');
      return headers;
    },
  }),
  tagTypes: ['User', 'Project', 'Organization', 'Billing'],
  endpoints: () => ({}),
});
```

#### Feature-Specific API Slices
Implementation pattern from Medusa and Cal.com:

```typescript
// store/api/projectsApi.ts - Feature-specific API slice
import { baseApi } from './baseApi';
import type { Project, CreateProjectRequest, UpdateProjectRequest } from '@/types/project';

export const projectsApi = baseApi.injectEndpoints({
  endpoints: (builder) => ({
    getProjects: builder.query<Project[], void>({
      query: () => '/projects',
      providesTags: ['Project'],
    }),
    getProject: builder.query<Project, string>({
      query: (id) => `/projects/${id}`,
      providesTags: (result, error, id) => [{ type: 'Project', id }],
    }),
    createProject: builder.mutation<Project, CreateProjectRequest>({
      query: (newProject) => ({
        url: '/projects',
        method: 'POST',
        body: newProject,
      }),
      invalidatesTags: ['Project'],
      // Optimistic update pattern
      async onQueryStarted(arg, { dispatch, queryFulfilled }) {
        const patchResult = dispatch(
          projectsApi.util.updateQueryData('getProjects', undefined, (draft) => {
            draft.push({
              id: `temp-${Date.now()}`,
              ...arg,
              createdAt: new Date().toISOString(),
              updatedAt: new Date().toISOString(),
            } as Project);
          })
        );
        try {
          await queryFulfilled;
        } catch {
          patchResult.undo();
        }
      },
    }),
    updateProject: builder.mutation<Project, { id: string; updates: UpdateProjectRequest }>({
      query: ({ id, updates }) => ({
        url: `/projects/${id}`,
        method: 'PATCH',
        body: updates,
      }),
      invalidatesTags: (result, error, { id }) => [{ type: 'Project', id }],
    }),
    deleteProject: builder.mutation<void, string>({
      query: (id) => ({
        url: `/projects/${id}`,
        method: 'DELETE',
      }),
      invalidatesTags: ['Project'],
    }),
  }),
});

export const {
  useGetProjectsQuery,
  useGetProjectQuery,
  useCreateProjectMutation,
  useUpdateProjectMutation,
  useDeleteProjectMutation,
} = projectsApi;
```

### 🔄 Caching and Synchronization

#### Cache Management Strategies
Advanced patterns from Vercel Dashboard:

```typescript
// Advanced cache management
export const advancedProjectsApi = projectsApi.injectEndpoints({
  endpoints: (builder) => ({
    getProjectsWithPagination: builder.query<
      { projects: Project[]; total: number; hasMore: boolean },
      { page: number; limit: number }
    >({
      query: ({ page, limit }) => `/projects?page=${page}&limit=${limit}`,
      // Merge strategy for pagination
      serializeQueryArgs: ({ endpointName }) => {
        return endpointName;
      },
      merge: (currentCache, newItems, { arg }) => {
        if (arg.page === 1) {
          return newItems;
        }
        return {
          ...newItems,
          projects: [...currentCache.projects, ...newItems.projects],
        };
      },
      forceRefetch({ currentArg, previousArg }) {
        return currentArg?.page !== previousArg?.page;
      },
    }),
    
    // Real-time subscription pattern
    getProjectUpdates: builder.query<Project, string>({
      query: (projectId) => `/projects/${projectId}/updates`,
      async onCacheEntryAdded(
        projectId,
        { updateCachedData, cacheDataLoaded, cacheEntryRemoved }
      ) {
        // WebSocket connection for real-time updates
        const ws = new WebSocket(`ws://localhost:8080/projects/${projectId}`);
        
        try {
          await cacheDataLoaded;
          
          const listener = (event: MessageEvent) => {
            const data = JSON.parse(event.data);
            updateCachedData((draft) => {
              Object.assign(draft, data);
            });
          };
          
          ws.addEventListener('message', listener);
        } catch {
          // no-op in case cacheEntryRemoved resolves before cacheDataLoaded
        }
        
        await cacheEntryRemoved;
        ws.close();
      },
    }),
  }),
});
```

## Performance Optimization Patterns

### 🎯 Selector Optimization

#### Memoized Selectors
Pattern from GitLab Web IDE and Grafana:

```typescript
// store/selectors/projectSelectors.ts - Optimized selectors
import { createSelector } from '@reduxjs/toolkit';
import type { RootState } from '../index';

// Basic selector
export const selectProjects = (state: RootState) => state.projects.items;
export const selectProjectsLoading = (state: RootState) => state.projects.loading;

// Memoized computed selector
export const selectActiveProjects = createSelector(
  [selectProjects],
  (projects) => projects.filter(project => project.status === 'active')
);

// Complex memoized selector with multiple inputs
export const selectProjectsByOwner = createSelector(
  [selectProjects, (state: RootState, ownerId: string) => ownerId],
  (projects, ownerId) => projects.filter(project => project.ownerId === ownerId)
);

// Performance-optimized selector for component-specific data
export const selectProjectSummary = createSelector(
  [selectActiveProjects],
  (activeProjects) => ({
    total: activeProjects.length,
    byStatus: activeProjects.reduce((acc, project) => {
      acc[project.status] = (acc[project.status] || 0) + 1;
      return acc;
    }, {} as Record<string, number>),
    recentlyUpdated: activeProjects
      .sort((a, b) => new Date(b.updatedAt).getTime() - new Date(a.updatedAt).getTime())
      .slice(0, 5),
  })
);
```

#### Component-Level Optimization
Hook patterns from Storybook and Docusaurus:

```typescript
// hooks/useTypedSelector.ts - Type-safe selector hooks
import { useSelector, TypedUseSelectorHook } from 'react-redux';
import type { RootState } from '../store';

export const useAppSelector: TypedUseSelectorHook<RootState> = useSelector;

// Custom hooks with optimized selectors
export const useProjectSummary = () => {
  return useAppSelector(selectProjectSummary);
};

export const useProjectById = (projectId: string) => {
  return useAppSelector(
    useCallback(
      (state: RootState) => state.projects.items.find(p => p.id === projectId),
      [projectId]
    )
  );
};

// Hook with automatic refetch logic
export const useProjectWithRefresh = (projectId: string) => {
  const { data, error, isLoading, refetch } = useGetProjectQuery(projectId);
  
  // Auto-refetch on window focus
  useEffect(() => {
    const handleFocus = () => refetch();
    window.addEventListener('focus', handleFocus);
    return () => window.removeEventListener('focus', handleFocus);
  }, [refetch]);
  
  return { project: data, error, isLoading, refetch };
};
```

### 🔄 Update Optimization

#### Batch Updates and Immer Integration
Advanced patterns from Medusa and Cal.com:

```typescript
// Batch update patterns for performance
const projectSlice = createSlice({
  name: 'projects',
  initialState,
  reducers: {
    // Batch update multiple projects
    updateMultipleProjects: (state, action: PayloadAction<{ id: string; updates: Partial<Project> }[]>) => {
      action.payload.forEach(({ id, updates }) => {
        const project = state.items.find(p => p.id === id);
        if (project) {
          Object.assign(project, updates);
        }
      });
    },
    
    // Optimized array operations with Immer
    reorderProjects: (state, action: PayloadAction<{ fromIndex: number; toIndex: number }>) => {
      const { fromIndex, toIndex } = action.payload;
      const [removed] = state.items.splice(fromIndex, 1);
      state.items.splice(toIndex, 0, removed);
    },
    
    // Complex nested state updates
    updateProjectSettings: (state, action: PayloadAction<{ projectId: string; settings: ProjectSettings }>) => {
      const project = state.items.find(p => p.id === action.payload.projectId);
      if (project) {
        project.settings = {
          ...project.settings,
          ...action.payload.settings,
        };
        project.updatedAt = new Date().toISOString();
      }
    },
  },
});
```

## TypeScript Integration

### 🛡️ Type Safety Patterns

#### Comprehensive Type Definitions
Pattern from Supabase Dashboard and Vercel:

```typescript
// types/store.ts - Comprehensive type definitions
export interface User {
  id: string;
  email: string;
  name: string;
  avatar?: string;
  role: UserRole;
  permissions: Permission[];
  preferences: UserPreferences;
  createdAt: string;
  updatedAt: string;
}

export interface Project {
  id: string;
  name: string;
  description?: string;
  ownerId: string;
  organizationId: string;
  status: ProjectStatus;
  settings: ProjectSettings;
  metadata: Record<string, any>;
  createdAt: string;
  updatedAt: string;
}

// API response types
export interface ApiResponse<T> {
  data: T;
  message?: string;
  status: number;
}

export interface PaginatedResponse<T> {
  data: T[];
  pagination: {
    page: number;
    limit: number;
    total: number;
    hasMore: boolean;
  };
}

// RTK Query type definitions
export interface GetProjectsRequest {
  organizationId?: string;
  status?: ProjectStatus;
  page?: number;
  limit?: number;
  search?: string;
}

export interface CreateProjectRequest {
  name: string;
  description?: string;
  organizationId: string;
  settings?: Partial<ProjectSettings>;
}
```

#### Type-Safe Action Creators
Advanced TypeScript patterns:

```typescript
// store/types.ts - Advanced type safety
import { store } from './index';

export type RootState = ReturnType<typeof store.getState>;
export type AppDispatch = typeof store.dispatch;

// Typed hooks
export const useAppDispatch = () => useDispatch<AppDispatch>();
export const useAppSelector: TypedUseSelectorHook<RootState> = useSelector;

// Typed async thunk
export const createAppAsyncThunk = createAsyncThunk.withTypes<{
  state: RootState;
  dispatch: AppDispatch;
  rejectValue: string;
}>();

// Type-safe slice creation
export interface SliceConfig<T> {
  name: string;
  initialState: T;
  reducers: any;
}

export const createTypedSlice = <T>(config: SliceConfig<T>) => {
  return createSlice(config);
};
```

## Error Handling Patterns

### 🚨 Comprehensive Error Management

#### Error State Management
Pattern from Grafana and GitLab Web IDE:

```typescript
// Error handling slice
interface ErrorState {
  global: string | null;
  api: Record<string, string>;
  validation: Record<string, string[]>;
}

const errorSlice = createSlice({
  name: 'errors',
  initialState: {
    global: null,
    api: {},
    validation: {},
  } as ErrorState,
  reducers: {
    setGlobalError: (state, action: PayloadAction<string>) => {
      state.global = action.payload;
    },
    clearGlobalError: (state) => {
      state.global = null;
    },
    setApiError: (state, action: PayloadAction<{ key: string; error: string }>) => {
      state.api[action.payload.key] = action.payload.error;
    },
    clearApiError: (state, action: PayloadAction<string>) => {
      delete state.api[action.payload];
    },
    setValidationErrors: (state, action: PayloadAction<{ field: string; errors: string[] }>) => {
      state.validation[action.payload.field] = action.payload.errors;
    },
    clearValidationErrors: (state, action: PayloadAction<string>) => {
      delete state.validation[action.payload];
    },
    clearAllErrors: (state) => {
      state.global = null;
      state.api = {};
      state.validation = {};
    },
  },
});

// RTK Query error handling
export const projectsApiWithErrorHandling = projectsApi.injectEndpoints({
  endpoints: (builder) => ({
    createProjectWithErrorHandling: builder.mutation<Project, CreateProjectRequest>({
      query: (newProject) => ({
        url: '/projects',
        method: 'POST',
        body: newProject,
      }),
      async onQueryStarted(arg, { dispatch, queryFulfilled }) {
        try {
          await queryFulfilled;
          dispatch(errorSlice.actions.clearApiError('createProject'));
        } catch (error: any) {
          dispatch(errorSlice.actions.setApiError({
            key: 'createProject',
            error: error.error?.message || 'Failed to create project',
          }));
        }
      },
    }),
  }),
});
```

## Testing Patterns

### 🧪 Redux Testing Strategies

#### Store Testing Setup
Pattern from Storybook and Docusaurus:

```typescript
// test-utils/store-utils.ts - Testing utilities
import { configureStore } from '@reduxjs/toolkit';
import { render, RenderOptions } from '@testing-library/react';
import { Provider } from 'react-redux';
import { authSlice } from '../store/slices/authSlice';
import { projectsApi } from '../store/api/projectsApi';

export const createTestStore = (initialState?: Partial<RootState>) => {
  return configureStore({
    reducer: {
      auth: authSlice.reducer,
      [projectsApi.reducerPath]: projectsApi.reducer,
    },
    preloadedState: initialState,
    middleware: (getDefaultMiddleware) =>
      getDefaultMiddleware().concat(projectsApi.middleware),
  });
};

interface ExtendedRenderOptions extends Omit<RenderOptions, 'wrapper'> {
  initialState?: Partial<RootState>;
  store?: ReturnType<typeof createTestStore>;
}

export const renderWithProviders = (
  ui: React.ReactElement,
  {
    initialState,
    store = createTestStore(initialState),
    ...renderOptions
  }: ExtendedRenderOptions = {}
) => {
  const Wrapper: React.FC<{ children: React.ReactNode }> = ({ children }) => (
    <Provider store={store}>{children}</Provider>
  );

  return { store, ...render(ui, { wrapper: Wrapper, ...renderOptions }) };
};

// Mock API responses for testing
export const createMockApiResponse = <T>(data: T, delay = 0) => {
  return new Promise<{ data: T }>((resolve) => {
    setTimeout(() => resolve({ data }), delay);
  });
};
```

#### Component Testing with Redux
Testing patterns for Redux-connected components:

```typescript
// __tests__/ProjectList.test.tsx
import { screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { renderWithProviders } from '../test-utils/store-utils';
import { ProjectList } from '../components/ProjectList';

describe('ProjectList', () => {
  const mockProjects = [
    { id: '1', name: 'Project 1', status: 'active' },
    { id: '2', name: 'Project 2', status: 'inactive' },
  ];

  it('renders projects from Redux store', async () => {
    renderWithProviders(<ProjectList />, {
      initialState: {
        projects: {
          items: mockProjects,
          loading: false,
          error: null,
        },
      },
    });

    expect(screen.getByText('Project 1')).toBeInTheDocument();
    expect(screen.getByText('Project 2')).toBeInTheDocument();
  });

  it('handles project creation', async () => {
    const user = userEvent.setup();
    const { store } = renderWithProviders(<ProjectList />);

    const createButton = screen.getByRole('button', { name: /create project/i });
    await user.click(createButton);

    const nameInput = screen.getByLabelText(/project name/i);
    await user.type(nameInput, 'New Project');

    const submitButton = screen.getByRole('button', { name: /submit/i });
    await user.click(submitButton);

    await waitFor(() => {
      const state = store.getState();
      expect(state.projects.items).toHaveLength(mockProjects.length + 1);
    });
  });
});
```

## Best Practices Summary

### ✅ Recommended Patterns

#### 1. Store Architecture
- Use Redux Toolkit for all new projects
- Organize slices by feature, not by data type
- Implement RTK Query for API state management
- Configure proper middleware for development and production

#### 2. Performance Optimization
- Use memoized selectors for computed state
- Implement proper cache invalidation strategies
- Avoid unnecessary re-renders with selector optimization
- Use RTK Query for automatic background refetching

#### 3. Type Safety
- Define comprehensive TypeScript interfaces
- Use typed hooks and selectors
- Implement proper error type definitions
- Leverage RTK's built-in TypeScript support

#### 4. Error Handling
- Centralize error state management
- Implement retry logic for failed requests
- Provide user-friendly error messages
- Log errors for debugging and monitoring

### ❌ Anti-Patterns to Avoid

#### 1. Common Mistakes
- Using Redux for all state (prefer local state when appropriate)
- Not implementing proper loading states
- Ignoring cache invalidation in RTK Query
- Over-normalizing simple data structures

#### 2. Performance Issues
- Not using memoized selectors for expensive computations
- Subscribing to unnecessary state updates
- Not implementing proper code splitting for large stores
- Ignoring bundle size impact of Redux DevTools in production

## Conclusion

Modern Redux implementation with Redux Toolkit provides powerful state management capabilities when properly implemented. The analyzed projects demonstrate consistent patterns for store organization, API integration, performance optimization, and type safety that can be applied to projects of any scale.

Key takeaways:
- Redux Toolkit significantly reduces boilerplate while maintaining Redux benefits
- RTK Query eliminates most custom API logic and provides excellent caching
- Proper TypeScript integration is essential for maintainable Redux code
- Performance optimization through selectors and caching strategies is crucial for large applications

---

**Navigation**
- ← Back to: [Project Overview & Selection Criteria](project-overview-selection-criteria.md)
- → Next: [Zustand State Management Analysis](zustand-state-management-analysis.md)
- → Related: [State Optimization Techniques](state-optimization-techniques.md)