# State Management Patterns in React/Next.js Projects

## 🎯 Overview

Analysis of state management patterns used in production React/Next.js applications, covering client state, server state, and state synchronization strategies.

## 📊 State Management Landscape

### **Classification of State Types**

```typescript
// Client State - Application UI state
interface ClientState {
  theme: 'light' | 'dark';
  sidebarOpen: boolean;
  currentUser: User | null;
  notifications: Notification[];
}

// Server State - Remote data from APIs
interface ServerState {
  users: User[];
  posts: Post[];
  settings: Settings;
  // Often cached and synchronized
}

// Component State - Local component state
interface ComponentState {
  isLoading: boolean;
  inputValue: string;
  modalOpen: boolean;
}
```

## 🛠️ State Management Solutions Analysis

### **1. React Query / TanStack Query**

**Used by**: Refine, Supabase Dashboard, React Admin  
**Best for**: Server state management, data fetching, caching

#### **Core Patterns**

```typescript
// Basic Query Pattern
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';

const useUsers = () => {
  return useQuery({
    queryKey: ['users'],
    queryFn: async () => {
      const response = await api.get('/users');
      return response.data;
    },
    staleTime: 5 * 60 * 1000, // 5 minutes
    cacheTime: 10 * 60 * 1000, // 10 minutes
  });
};

// Mutation with Optimistic Updates
const useCreateUser = () => {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (userData: CreateUserData) => {
      const response = await api.post('/users', userData);
      return response.data;
    },
    onMutate: async (newUser) => {
      // Cancel outgoing refetches
      await queryClient.cancelQueries({ queryKey: ['users'] });

      // Snapshot the previous value
      const previousUsers = queryClient.getQueryData(['users']);

      // Optimistically update to the new value
      queryClient.setQueryData(['users'], (old: User[]) => [
        ...(old || []),
        { ...newUser, id: 'temp-id' }
      ]);

      return { previousUsers };
    },
    onError: (err, newUser, context) => {
      // Rollback on error
      queryClient.setQueryData(['users'], context?.previousUsers);
    },
    onSettled: () => {
      // Always refetch after error or success
      queryClient.invalidateQueries({ queryKey: ['users'] });
    },
  });
};

// Advanced Pattern: Infinite Queries
const usePaginatedPosts = () => {
  return useInfiniteQuery({
    queryKey: ['posts'],
    queryFn: async ({ pageParam = 0 }) => {
      const response = await api.get(`/posts?page=${pageParam}`);
      return response.data;
    },
    getNextPageParam: (lastPage, pages) => {
      return lastPage.hasMore ? pages.length : undefined;
    },
  });
};
```

#### **Best Practices from Production Apps**

```typescript
// Refine's Data Provider Pattern with React Query
export const useList = <TData = BaseRecord>({
  resource,
  config,
  queryOptions,
}: UseListProps<TData>) => {
  const { dataProvider } = useContext(DataContext);

  const queryResponse = useQuery({
    queryKey: [dataProvider.name, resource, 'list', config],
    queryFn: () => dataProvider.getList({ resource, ...config }),
    ...queryOptions,
  });

  return queryResponse;
};

// Error Boundary Integration
const QueryErrorBoundary: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  return (
    <QueryErrorResetBoundary>
      {({ reset }) => (
        <ErrorBoundary
          onReset={reset}
          fallbackRender={({ resetErrorBoundary }) => (
            <div>
              There was an error!
              <button onClick={resetErrorBoundary}>Try again</button>
            </div>
          )}
        >
          {children}
        </ErrorBoundary>
      )}
    </QueryErrorResetBoundary>
  );
};
```

### **2. Zustand**

**Used by**: Medusa, many modern React apps  
**Best for**: Lightweight global state, simple state management

#### **Core Patterns**

```typescript
import { create } from 'zustand';
import { devtools, persist } from 'zustand/middleware';

// Basic Store Pattern
interface AppStore {
  user: User | null;
  theme: 'light' | 'dark';
  setUser: (user: User | null) => void;
  toggleTheme: () => void;
}

const useAppStore = create<AppStore>()(
  devtools(
    persist(
      (set, get) => ({
        user: null,
        theme: 'light',
        setUser: (user) => set({ user }),
        toggleTheme: () => set((state) => ({ 
          theme: state.theme === 'light' ? 'dark' : 'light' 
        })),
      }),
      { name: 'app-store' }
    )
  )
);

// Advanced Pattern: Immer Integration
import { immer } from 'zustand/middleware/immer';

interface CartStore {
  items: CartItem[];
  total: number;
  addItem: (item: CartItem) => void;
  updateQuantity: (id: string, quantity: number) => void;
  removeItem: (id: string) => void;
}

const useCartStore = create<CartStore>()(
  immer((set) => ({
    items: [],
    total: 0,
    addItem: (item) => set((state) => {
      const existingItem = state.items.find(i => i.id === item.id);
      if (existingItem) {
        existingItem.quantity += item.quantity;
      } else {
        state.items.push(item);
      }
      state.total = state.items.reduce((sum, i) => sum + i.price * i.quantity, 0);
    }),
    updateQuantity: (id, quantity) => set((state) => {
      const item = state.items.find(i => i.id === id);
      if (item) {
        item.quantity = quantity;
        state.total = state.items.reduce((sum, i) => sum + i.price * i.quantity, 0);
      }
    }),
    removeItem: (id) => set((state) => {
      state.items = state.items.filter(i => i.id !== id);
      state.total = state.items.reduce((sum, i) => sum + i.price * i.quantity, 0);
    }),
  }))
);

// Slice Pattern for Large Apps
const createUserSlice = (set, get) => ({
  user: null,
  isAuthenticated: false,
  login: async (credentials) => {
    const user = await authAPI.login(credentials);
    set({ user, isAuthenticated: true });
  },
  logout: () => set({ user: null, isAuthenticated: false }),
});

const createCartSlice = (set, get) => ({
  items: [],
  addToCart: (item) => set((state) => ({
    items: [...state.items, item]
  })),
});

const useStore = create()((...a) => ({
  ...createUserSlice(...a),
  ...createCartSlice(...a),
}));
```

#### **Medusa's E-commerce Patterns**

```typescript
// Store for Cart Management
interface MedusaCartStore {
  cart: Cart | null;
  items: LineItem[];
  isLoading: boolean;
  addItem: (variantId: string, quantity: number) => Promise<void>;
  updateItem: (lineId: string, quantity: number) => Promise<void>;
  removeItem: (lineId: string) => Promise<void>;
  createCart: () => Promise<void>;
}

const useMedusaCartStore = create<MedusaCartStore>((set, get) => ({
  cart: null,
  items: [],
  isLoading: false,
  
  addItem: async (variantId, quantity) => {
    set({ isLoading: true });
    try {
      const { cart } = get();
      if (!cart) await get().createCart();
      
      const updatedCart = await medusaClient.carts.lineItems.create(cart.id, {
        variant_id: variantId,
        quantity,
      });
      
      set({ cart: updatedCart.cart, items: updatedCart.cart.items });
    } catch (error) {
      console.error('Failed to add item:', error);
    } finally {
      set({ isLoading: false });
    }
  },
  
  createCart: async () => {
    const { cart } = await medusaClient.carts.create();
    set({ cart });
  },
}));
```

### **3. Redux Toolkit**

**Used by**: Mattermost, large enterprise applications  
**Best for**: Complex state logic, time-travel debugging, large teams

#### **Modern Redux Patterns**

```typescript
import { createSlice, createAsyncThunk, createSelector } from '@reduxjs/toolkit';

// Async Thunk Pattern
export const fetchUsers = createAsyncThunk(
  'users/fetchUsers',
  async (params: FetchUsersParams, { rejectWithValue }) => {
    try {
      const response = await api.get('/users', { params });
      return response.data;
    } catch (error) {
      return rejectWithValue(error.response.data);
    }
  }
);

// Slice with Normalized State
interface UsersState {
  byId: Record<string, User>;
  allIds: string[];
  loading: boolean;
  error: string | null;
  pagination: {
    page: number;
    totalPages: number;
    totalItems: number;
  };
}

const usersSlice = createSlice({
  name: 'users',
  initialState: {
    byId: {},
    allIds: [],
    loading: false,
    error: null,
    pagination: { page: 1, totalPages: 1, totalItems: 0 },
  } as UsersState,
  reducers: {
    userUpdated: (state, action) => {
      const { id, changes } = action.payload;
      if (state.byId[id]) {
        state.byId[id] = { ...state.byId[id], ...changes };
      }
    },
    userRemoved: (state, action) => {
      const id = action.payload;
      delete state.byId[id];
      state.allIds = state.allIds.filter(userId => userId !== id);
    },
  },
  extraReducers: (builder) => {
    builder
      .addCase(fetchUsers.pending, (state) => {
        state.loading = true;
        state.error = null;
      })
      .addCase(fetchUsers.fulfilled, (state, action) => {
        state.loading = false;
        const { users, pagination } = action.payload;
        
        // Normalize data
        users.forEach(user => {
          state.byId[user.id] = user;
        });
        state.allIds = users.map(user => user.id);
        state.pagination = pagination;
      })
      .addCase(fetchUsers.rejected, (state, action) => {
        state.loading = false;
        state.error = action.payload as string;
      });
  },
});

// Selector Patterns
const selectUsersState = (state: RootState) => state.users;

export const selectAllUsers = createSelector(
  [selectUsersState],
  (users) => users.allIds.map(id => users.byId[id])
);

export const selectUserById = createSelector(
  [selectUsersState, (state: RootState, userId: string) => userId],
  (users, userId) => users.byId[userId]
);

export const selectActiveUsers = createSelector(
  [selectAllUsers],
  (users) => users.filter(user => user.isActive)
);
```

#### **Mattermost's Large-Scale Redux Architecture**

```typescript
// Entity Adapter Pattern
import { createEntityAdapter, createSlice } from '@reduxjs/toolkit';

const postsAdapter = createEntityAdapter<Post>({
  selectId: (post) => post.id,
  sortComparer: (a, b) => b.create_at - a.create_at,
});

const postsSlice = createSlice({
  name: 'posts',
  initialState: postsAdapter.getInitialState({
    loading: false,
    error: null,
  }),
  reducers: {
    postAdded: postsAdapter.addOne,
    postUpdated: postsAdapter.updateOne,
    postRemoved: postsAdapter.removeOne,
    postsReceived: postsAdapter.setAll,
  },
});

// RTK Query for API Management
import { createApi, fetchBaseQuery } from '@reduxjs/toolkit/query/react';

export const postsApi = createApi({
  reducerPath: 'postsApi',
  baseQuery: fetchBaseQuery({
    baseUrl: '/api/',
    prepareHeaders: (headers, { getState }) => {
      const token = (getState() as RootState).auth.token;
      if (token) {
        headers.set('authorization', `Bearer ${token}`);
      }
      return headers;
    },
  }),
  tagTypes: ['Post', 'User'],
  endpoints: (builder) => ({
    getPosts: builder.query<Post[], string>({
      query: (channelId) => `channels/${channelId}/posts`,
      providesTags: ['Post'],
    }),
    createPost: builder.mutation<Post, CreatePostData>({
      query: (post) => ({
        url: 'posts',
        method: 'POST',
        body: post,
      }),
      invalidatesTags: ['Post'],
    }),
  }),
});
```

### **4. Recoil**

**Used by**: Twenty CRM, Facebook internal tools  
**Best for**: Atomic state management, complex derived state

#### **Atomic State Patterns**

```typescript
import { atom, selector, useRecoilState, useRecoilValue } from 'recoil';

// Atom Pattern
const currentUserState = atom({
  key: 'currentUserState',
  default: null as User | null,
});

const notificationsState = atom({
  key: 'notificationsState',
  default: [] as Notification[],
});

// Selector for Derived State
const unreadNotificationsSelector = selector({
  key: 'unreadNotificationsSelector',
  get: ({ get }) => {
    const notifications = get(notificationsState);
    return notifications.filter(n => !n.isRead);
  },
});

const unreadCountSelector = selector({
  key: 'unreadCountSelector',
  get: ({ get }) => {
    const unreadNotifications = get(unreadNotificationsSelector);
    return unreadNotifications.length;
  },
});

// Async Selector
const userDataSelector = selector({
  key: 'userDataSelector',
  get: async ({ get }) => {
    const currentUser = get(currentUserState);
    if (!currentUser) return null;
    
    const response = await api.get(`/users/${currentUser.id}`);
    return response.data;
  },
});

// Component Usage
const NotificationBadge: React.FC = () => {
  const unreadCount = useRecoilValue(unreadCountSelector);
  
  if (unreadCount === 0) return null;
  
  return <span className="badge">{unreadCount}</span>;
};
```

#### **Twenty's CRM State Architecture**

```typescript
// Entity State Pattern
const companiesState = atom({
  key: 'companiesState',
  default: [] as Company[],
});

const selectedCompanyIdState = atom({
  key: 'selectedCompanyIdState',
  default: null as string | null,
});

const selectedCompanySelector = selector({
  key: 'selectedCompanySelector',
  get: ({ get }) => {
    const companies = get(companiesState);
    const selectedId = get(selectedCompanyIdState);
    return companies.find(company => company.id === selectedId) || null;
  },
});

// Filter State
const companyFiltersState = atom({
  key: 'companyFiltersState',
  default: {
    search: '',
    industry: null,
    status: 'active',
  } as CompanyFilters,
});

const filteredCompaniesSelector = selector({
  key: 'filteredCompaniesSelector',
  get: ({ get }) => {
    const companies = get(companiesState);
    const filters = get(companyFiltersState);
    
    return companies.filter(company => {
      if (filters.search && !company.name.toLowerCase().includes(filters.search.toLowerCase())) {
        return false;
      }
      if (filters.industry && company.industry !== filters.industry) {
        return false;
      }
      if (filters.status && company.status !== filters.status) {
        return false;
      }
      return true;
    });
  },
});
```

### **5. SWR (Stale-While-Revalidate)**

**Used by**: Plane, many Next.js applications  
**Best for**: Data fetching with automatic revalidation

#### **Core SWR Patterns**

```typescript
import useSWR, { mutate } from 'swr';

// Basic Pattern
const useUser = (id: string) => {
  const { data, error, mutate } = useSWR(
    id ? `/api/users/${id}` : null,
    fetcher,
    {
      revalidateOnFocus: false,
      revalidateOnReconnect: true,
      refreshInterval: 30000, // 30 seconds
    }
  );

  return {
    user: data,
    isLoading: !error && !data,
    isError: error,
    mutate,
  };
};

// Conditional Fetching
const useProjects = (workspaceId?: string) => {
  const shouldFetch = !!workspaceId;
  
  const { data, error } = useSWR(
    shouldFetch ? `/api/workspaces/${workspaceId}/projects` : null,
    fetcher
  );

  return {
    projects: data || [],
    isLoading: shouldFetch && !error && !data,
    isError: error,
  };
};

// Pagination Pattern
const useIssues = (projectId: string, page: number) => {
  const { data, error, size, setSize } = useSWRInfinite(
    (index) => `/api/projects/${projectId}/issues?page=${index + 1}`,
    fetcher
  );

  const issues = data ? data.flat() : [];
  const isLoadingInitial = !data && !error;
  const isLoadingMore = isLoadingInitial || (size > 0 && data && typeof data[size - 1] === 'undefined');
  const isEmpty = data?.[0]?.length === 0;
  const isReachingEnd = isEmpty || (data && data[data.length - 1]?.length < 20);

  return {
    issues,
    isLoadingMore,
    isReachingEnd,
    loadMore: () => setSize(size + 1),
  };
};
```

#### **Plane's Project Management Patterns**

```typescript
// Global Configuration
const swrConfig = {
  errorRetryCount: 3,
  errorRetryInterval: 5000,
  onError: (error) => {
    console.error('SWR Error:', error);
    if (error.status === 401) {
      // Redirect to login
      router.push('/login');
    }
  },
};

// Optimistic Updates Pattern
const useCreateIssue = (projectId: string) => {
  const { mutate } = useSWR(`/api/projects/${projectId}/issues`);

  const createIssue = async (issueData: CreateIssueData) => {
    const optimisticIssue = {
      ...issueData,
      id: `temp-${Date.now()}`,
      created_at: new Date().toISOString(),
    };

    // Optimistic update
    mutate(
      (currentIssues: Issue[]) => [...(currentIssues || []), optimisticIssue],
      false
    );

    try {
      const newIssue = await api.post(`/projects/${projectId}/issues`, issueData);
      
      // Replace optimistic issue with real one
      mutate(
        (currentIssues: Issue[]) =>
          currentIssues?.map(issue =>
            issue.id === optimisticIssue.id ? newIssue.data : issue
          ),
        false
      );

      return newIssue.data;
    } catch (error) {
      // Remove optimistic issue on error
      mutate(
        (currentIssues: Issue[]) =>
          currentIssues?.filter(issue => issue.id !== optimisticIssue.id),
        false
      );
      throw error;
    }
  };

  return { createIssue };
};
```

## 📊 State Management Decision Matrix

### **Choosing the Right Solution**

| Criteria | React Query/SWR | Zustand | Redux Toolkit | Recoil |
|----------|-----------------|---------|---------------|---------|
| **Server State** | ✅ Excellent | ❌ No | ⚠️ With RTK Query | ⚠️ With selectors |
| **Client State** | ❌ No | ✅ Excellent | ✅ Excellent | ✅ Excellent |
| **Learning Curve** | Low | Very Low | Medium | Medium |
| **Bundle Size** | Small | Very Small | Medium | Small |
| **DevTools** | ✅ Yes | ✅ Yes | ✅ Excellent | ✅ Yes |
| **TypeScript** | ✅ Excellent | ✅ Excellent | ✅ Excellent | ✅ Good |
| **Time Travel** | ❌ No | ❌ No | ✅ Yes | ❌ No |
| **Real-time** | ⚠️ Manual | ⚠️ Manual | ✅ With middleware | ⚠️ Manual |

### **Recommended Combinations**

```typescript
// Small to Medium Apps
// React Query + Zustand
const useApp = () => {
  // Server state with React Query
  const { data: user } = useQuery({
    queryKey: ['user'],
    queryFn: fetchUser,
  });

  // Client state with Zustand
  const { theme, toggleTheme } = useAppStore();

  return { user, theme, toggleTheme };
};

// Large Apps
// Redux Toolkit + RTK Query
const store = configureStore({
  reducer: {
    auth: authSlice.reducer,
    ui: uiSlice.reducer,
    api: apiSlice.reducer,
  },
});

// Complex Derived State
// Recoil for atomic state management
const useComplexState = () => {
  const currentUser = useRecoilValue(currentUserState);
  const permissions = useRecoilValue(userPermissionsSelector);
  const filteredData = useRecoilValue(filteredDataSelector);

  return { currentUser, permissions, filteredData };
};
```

## 🔗 Navigation

← [Project Showcases](./project-showcases.md) | [UI Component Libraries →](./ui-component-libraries.md)

---

## 📚 References

1. [React Query Documentation](https://tanstack.com/query/latest)
2. [Zustand Documentation](https://zustand-demo.pmnd.rs/)
3. [Redux Toolkit Documentation](https://redux-toolkit.js.org/)
4. [Recoil Documentation](https://recoiljs.org/)
5. [SWR Documentation](https://swr.vercel.app/)
6. [State Management Comparison](https://github.com/reduxjs/redux/issues/3657)

*Last updated: January 2025*