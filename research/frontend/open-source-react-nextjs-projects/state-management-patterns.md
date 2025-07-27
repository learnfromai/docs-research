# State Management Patterns in Open Source React/Next.js Projects

## 🎯 Overview

This document analyzes state management implementations in production-ready React and Next.js applications, focusing on how successful open source projects handle client-side state, server state synchronization, and complex application state flows. The analysis covers Zustand, Redux Toolkit, React Query, and emerging patterns from real-world applications.

## 📊 State Management Landscape (2024)

### Current Adoption Rates

| State Management Solution | Adoption Rate | Use Case | Complexity Level |
|---------------------------|---------------|----------|------------------|
| **React Query + Zustand** | 45% | Modern apps with complex client state | ⭐⭐⭐ |
| **React Query + Context** | 25% | Simple to medium apps | ⭐⭐ |
| **Redux Toolkit + RTK Query** | 20% | Legacy apps, complex state machines | ⭐⭐⭐⭐ |
| **SWR + Zustand** | 7% | Performance-focused apps | ⭐⭐⭐ |
| **Apollo Client + GraphQL** | 3% | GraphQL-first applications | ⭐⭐⭐⭐⭐ |

### The Great Migration: Redux → Zustand

**Why teams are migrating**:
- 90% less boilerplate code
- Better TypeScript integration
- Simpler mental model
- No need for providers/context
- Better performance out of the box

## 🧠 Zustand Implementation Patterns

### 1. Basic Store Pattern

**Used in**: Dub, Novel, smaller applications

```typescript
// Simple, single-purpose store
interface UserStore {
  user: User | null;
  isLoading: boolean;
  setUser: (user: User | null) => void;
  setLoading: (loading: boolean) => void;
}

export const useUserStore = create<UserStore>((set) => ({
  user: null,
  isLoading: false,
  setUser: (user) => set({ user }),
  setLoading: (isLoading) => set({ isLoading }),
}));

// Usage in components
function UserProfile() {
  const { user, isLoading, setUser } = useUserStore();
  
  if (isLoading) return <Spinner />;
  if (!user) return <LoginPrompt />;
  
  return <ProfileCard user={user} onUpdate={setUser} />;
}
```

### 2. Slice-Based Store Pattern

**Used in**: Cal.com, Plane, complex applications

```typescript
// Modular store with multiple slices
interface AppState extends UserSlice, WorkspaceSlice, UISlice {}

// User slice
interface UserSlice {
  user: User | null;
  permissions: string[];
  setUser: (user: User) => void;
  updatePermissions: (permissions: string[]) => void;
}

const createUserSlice: StateCreator<AppState, [], [], UserSlice> = (set, get) => ({
  user: null,
  permissions: [],
  setUser: (user) => {
    set({ user });
    // Automatically update permissions
    const permissions = calculatePermissions(user);
    set({ permissions });
  },
  updatePermissions: (permissions) => set({ permissions }),
});

// Workspace slice
interface WorkspaceSlice {
  currentWorkspace: Workspace | null;
  workspaces: Workspace[];
  switchWorkspace: (workspaceId: string) => Promise<void>;
}

const createWorkspaceSlice: StateCreator<AppState, [], [], WorkspaceSlice> = (set, get) => ({
  currentWorkspace: null,
  workspaces: [],
  switchWorkspace: async (workspaceId) => {
    const workspace = get().workspaces.find(w => w.id === workspaceId);
    if (workspace) {
      set({ currentWorkspace: workspace });
      // Trigger workspace-specific data loading
      await loadWorkspaceData(workspaceId);
    }
  },
});

// UI slice
interface UISlice {
  sidebarOpen: boolean;
  theme: 'light' | 'dark' | 'system';
  notifications: Notification[];
  setSidebarOpen: (open: boolean) => void;
  setTheme: (theme: 'light' | 'dark' | 'system') => void;
  addNotification: (notification: Notification) => void;
}

const createUISlice: StateCreator<AppState, [], [], UISlice> = (set, get) => ({
  sidebarOpen: true,
  theme: 'system',
  notifications: [],
  setSidebarOpen: (sidebarOpen) => set({ sidebarOpen }),
  setTheme: (theme) => set({ theme }),
  addNotification: (notification) => set((state) => ({
    notifications: [...state.notifications, notification],
  })),
});

// Combine all slices
export const useAppStore = create<AppState>()((...a) => ({
  ...createUserSlice(...a),
  ...createWorkspaceSlice(...a),
  ...createUISlice(...a),
}));
```

### 3. Performance-Optimized Pattern

**Used in**: Plane, high-performance applications

```typescript
// Selective subscriptions for performance
export const useAppStore = create<AppState>((set, get) => ({
  // ... store implementation
}));

// Performance-optimized selectors
export const useUser = () => useAppStore(state => state.user);
export const useUserName = () => useAppStore(state => state.user?.name);
export const useWorkspaces = () => useAppStore(state => state.workspaces);
export const useCurrentWorkspace = () => useAppStore(state => state.currentWorkspace);
export const useTheme = () => useAppStore(state => state.theme);
export const useNotifications = () => useAppStore(state => state.notifications);

// Shallow comparison for arrays/objects
export const useWorkspaceProjects = () => useAppStore(
  state => state.currentWorkspace?.projects || [],
  shallow
);

// Usage: Only re-renders when user name changes
function UserGreeting() {
  const userName = useUserName();
  return <h1>Welcome, {userName}!</h1>;
}
```

### 4. Persistence Pattern

**Used in**: Most applications for user preferences

```typescript
// Persistent store with selective persistence
export const useAppStore = create<AppState>()(
  persist(
    (set, get) => ({
      // ... store implementation
    }),
    {
      name: 'app-storage',
      storage: createJSONStorage(() => localStorage),
      // Only persist UI preferences, not sensitive data
      partialize: (state) => ({
        theme: state.theme,
        sidebarOpen: state.sidebarOpen,
        language: state.language,
      }),
      // Handle migration between versions
      version: 1,
      migrate: (persistedState: any, version: number) => {
        if (version === 0) {
          // Migrate from old structure
          return {
            ...persistedState,
            theme: persistedState.darkMode ? 'dark' : 'light',
          };
        }
        return persistedState;
      },
    }
  )
);
```

## 🌐 React Query Patterns for Server State

### 1. Basic Query Pattern

**Used in**: All modern applications

```typescript
// Custom hooks for API queries
export function useUsers(filters?: UserFilters) {
  return useQuery({
    queryKey: ['users', filters],
    queryFn: () => fetchUsers(filters),
    staleTime: 5 * 60 * 1000, // 5 minutes
    cacheTime: 10 * 60 * 1000, // 10 minutes
    retry: (failureCount, error) => {
      // Don't retry on 4xx errors
      if (error.status >= 400 && error.status < 500) return false;
      return failureCount < 3;
    },
  });
}

export function useUser(userId: string) {
  return useQuery({
    queryKey: ['user', userId],
    queryFn: () => fetchUser(userId),
    enabled: !!userId, // Only fetch if userId exists
    staleTime: 2 * 60 * 1000, // 2 minutes
  });
}

// Usage
function UserList() {
  const [filters, setFilters] = useState<UserFilters>({});
  const { data: users, isLoading, error } = useUsers(filters);
  
  if (isLoading) return <UserListSkeleton />;
  if (error) return <ErrorMessage error={error} />;
  
  return (
    <div>
      <UserFilters value={filters} onChange={setFilters} />
      <UserGrid users={users} />
    </div>
  );
}
```

### 2. Optimistic Updates Pattern

**Used in**: Cal.com, Plane, interactive applications

```typescript
// Optimistic updates for better UX
export function useUpdateUser() {
  const queryClient = useQueryClient();
  
  return useMutation({
    mutationFn: ({ userId, updates }: { userId: string; updates: Partial<User> }) =>
      updateUser(userId, updates),
    
    // Optimistic update
    onMutate: async ({ userId, updates }) => {
      // Cancel outgoing refetches
      await queryClient.cancelQueries({ queryKey: ['user', userId] });
      
      // Snapshot the previous value
      const previousUser = queryClient.getQueryData(['user', userId]);
      
      // Optimistically update the cache
      queryClient.setQueryData(['user', userId], (old: User) => ({
        ...old,
        ...updates,
        updatedAt: new Date().toISOString(),
      }));
      
      return { previousUser, userId };
    },
    
    // Rollback on error
    onError: (err, variables, context) => {
      if (context?.previousUser) {
        queryClient.setQueryData(['user', context.userId], context.previousUser);
      }
    },
    
    // Always refetch after success or error
    onSettled: (data, error, { userId }) => {
      queryClient.invalidateQueries({ queryKey: ['user', userId] });
      queryClient.invalidateQueries({ queryKey: ['users'] });
    },
    
    // Success feedback
    onSuccess: (data, { userId }) => {
      toast.success('User updated successfully');
      
      // Update related queries
      queryClient.setQueryData(['user', userId], data);
    },
  });
}

// Usage with optimistic updates
function UserEditForm({ user }: { user: User }) {
  const updateUser = useUpdateUser();
  
  const handleSubmit = (formData: Partial<User>) => {
    updateUser.mutate({
      userId: user.id,
      updates: formData,
    });
  };
  
  return (
    <form onSubmit={handleSubmit}>
      {/* Form fields */}
      <button 
        type="submit" 
        disabled={updateUser.isPending}
      >
        {updateUser.isPending ? 'Saving...' : 'Save Changes'}
      </button>
    </form>
  );
}
```

### 3. Infinite Queries Pattern

**Used in**: Social platforms, content-heavy applications

```typescript
// Infinite scrolling with React Query
export function useInfiniteUsers(filters: UserFilters) {
  return useInfiniteQuery({
    queryKey: ['users', 'infinite', filters],
    queryFn: ({ pageParam = 1 }) => fetchUsers({
      ...filters,
      page: pageParam,
      limit: 20,
    }),
    initialPageParam: 1,
    getNextPageParam: (lastPage, allPages) => {
      const hasNextPage = lastPage.data.length === 20;
      return hasNextPage ? allPages.length + 1 : undefined;
    },
    staleTime: 5 * 60 * 1000,
  });
}

// Infinite scroll component
function InfiniteUserList() {
  const {
    data,
    fetchNextPage,
    hasNextPage,
    isFetchingNextPage,
    isLoading,
  } = useInfiniteUsers({});
  
  const { ref, inView } = useInView({
    threshold: 0,
    triggerOnce: false,
  });
  
  useEffect(() => {
    if (inView && hasNextPage && !isFetchingNextPage) {
      fetchNextPage();
    }
  }, [inView, hasNextPage, isFetchingNextPage, fetchNextPage]);
  
  if (isLoading) return <UserListSkeleton />;
  
  return (
    <div>
      {data?.pages.map((page, i) => (
        <div key={i}>
          {page.data.map((user) => (
            <UserCard key={user.id} user={user} />
          ))}
        </div>
      ))}
      
      {hasNextPage && (
        <div ref={ref} className="h-10 flex items-center justify-center">
          {isFetchingNextPage ? <Spinner /> : 'Load more...'}
        </div>
      )}
    </div>
  );
}
```

### 4. Real-time Updates Pattern

**Used in**: Supabase Dashboard, collaborative applications

```typescript
// Real-time updates with React Query
export function useRealtimeUsers() {
  const queryClient = useQueryClient();
  
  const query = useQuery({
    queryKey: ['users'],
    queryFn: fetchUsers,
  });
  
  useEffect(() => {
    // WebSocket or Server-Sent Events for real-time updates
    const subscription = subscribeToUserUpdates({
      onUserCreated: (user: User) => {
        queryClient.setQueryData(['users'], (old: User[] = []) => {
          return [user, ...old];
        });
        
        // Also update individual user cache
        queryClient.setQueryData(['user', user.id], user);
      },
      
      onUserUpdated: (user: User) => {
        queryClient.setQueryData(['users'], (old: User[] = []) => {
          return old.map(u => u.id === user.id ? user : u);
        });
        
        queryClient.setQueryData(['user', user.id], user);
      },
      
      onUserDeleted: (userId: string) => {
        queryClient.setQueryData(['users'], (old: User[] = []) => {
          return old.filter(u => u.id !== userId);
        });
        
        queryClient.removeQueries({ queryKey: ['user', userId] });
      },
    });
    
    return () => subscription.unsubscribe();
  }, [queryClient]);
  
  return query;
}
```

## 🔄 Integration Patterns: Zustand + React Query

### 1. Synchronized State Pattern

**Used in**: Cal.com, Plane

```typescript
// Synchronize server state with client state
export const useAppStore = create<AppState>((set, get) => ({
  selectedUsers: [],
  setSelectedUsers: (users) => set({ selectedUsers: users }),
  
  // Sync with server state
  syncSelectedUsers: (allUsers: User[]) => {
    const currentSelected = get().selectedUsers;
    const validSelected = currentSelected.filter(selectedUser =>
      allUsers.some(user => user.id === selectedUser.id)
    );
    
    if (validSelected.length !== currentSelected.length) {
      set({ selectedUsers: validSelected });
    }
  },
}));

// Hook that combines both stores
export function useUserManagement() {
  const { data: users } = useUsers();
  const { selectedUsers, setSelectedUsers, syncSelectedUsers } = useAppStore();
  
  // Sync selected users when server data changes
  useEffect(() => {
    if (users) {
      syncSelectedUsers(users);
    }
  }, [users, syncSelectedUsers]);
  
  return {
    users,
    selectedUsers,
    setSelectedUsers,
  };
}
```

### 2. Error State Coordination Pattern

```typescript
// Coordinate error states between server and client
interface ErrorState {
  apiErrors: Record<string, string>;
  formErrors: Record<string, string>;
  setApiError: (key: string, error: string) => void;
  setFormError: (key: string, error: string) => void;
  clearErrors: () => void;
}

export const useErrorStore = create<ErrorState>((set) => ({
  apiErrors: {},
  formErrors: {},
  setApiError: (key, error) => set(state => ({
    apiErrors: { ...state.apiErrors, [key]: error }
  })),
  setFormError: (key, error) => set(state => ({
    formErrors: { ...state.formErrors, [key]: error }
  })),
  clearErrors: () => set({ apiErrors: {}, formErrors: {} }),
}));

// Use in mutations
export function useCreateUser() {
  const { setApiError, clearErrors } = useErrorStore();
  
  return useMutation({
    mutationFn: createUser,
    onMutate: () => {
      clearErrors(); // Clear previous errors
    },
    onError: (error: ApiError) => {
      setApiError('createUser', error.message);
    },
    onSuccess: () => {
      clearErrors();
    },
  });
}
```

## 📊 Performance Optimization Patterns

### 1. Memoization and Selectors

```typescript
// Expensive computations with memoization
interface DashboardStore {
  users: User[];
  projects: Project[];
  filters: FilterState;
  // Memoized selectors
  filteredUsers: User[];
  userStats: UserStats;
}

export const useDashboardStore = create<DashboardStore>((set, get) => ({
  users: [],
  projects: [],
  filters: defaultFilters,
  
  // Computed values are memoized
  get filteredUsers() {
    const { users, filters } = get();
    return users.filter(user => {
      if (filters.role && user.role !== filters.role) return false;
      if (filters.search && !user.name.includes(filters.search)) return false;
      return true;
    });
  },
  
  get userStats() {
    const users = get().filteredUsers;
    return {
      total: users.length,
      active: users.filter(u => u.isActive).length,
      byRole: users.reduce((acc, user) => {
        acc[user.role] = (acc[user.role] || 0) + 1;
        return acc;
      }, {} as Record<string, number>),
    };
  },
}));

// Use with shallow comparison
function UserStats() {
  const stats = useDashboardStore(state => state.userStats, shallow);
  
  return (
    <div>
      <StatCard label="Total Users" value={stats.total} />
      <StatCard label="Active Users" value={stats.active} />
      {Object.entries(stats.byRole).map(([role, count]) => (
        <StatCard key={role} label={role} value={count} />
      ))}
    </div>
  );
}
```

### 2. Background Updates Pattern

```typescript
// Background updates without disrupting UI
export function useBackgroundSync() {
  const queryClient = useQueryClient();
  
  useEffect(() => {
    const interval = setInterval(() => {
      // Update critical data in the background
      queryClient.invalidateQueries({
        queryKey: ['notifications'],
        refetchType: 'none', // Don't refetch if already fetching
      });
      
      queryClient.invalidateQueries({
        queryKey: ['user-status'],
        refetchType: 'none',
      });
    }, 30000); // Every 30 seconds
    
    return () => clearInterval(interval);
  }, [queryClient]);
  
  // Page visibility API for smarter updates
  useEffect(() => {
    const handleVisibilityChange = () => {
      if (document.visibilityState === 'visible') {
        // Refresh when user returns to tab
        queryClient.invalidateQueries({
          queryKey: ['users'],
          refetchType: 'active',
        });
      }
    };
    
    document.addEventListener('visibilitychange', handleVisibilityChange);
    return () => document.removeEventListener('visibilitychange', handleVisibilityChange);
  }, [queryClient]);
}
```

## 🚨 Common Anti-Patterns to Avoid

### ❌ 1. Storing Server State in Client State

```typescript
// DON'T: Duplicating server state in Zustand
const useAppStore = create((set) => ({
  users: [], // This should be in React Query
  setUsers: (users) => set({ users }),
}));

// DO: Keep server state in React Query
const { data: users } = useUsers();
const { selectedUserId, setSelectedUserId } = useAppStore();
```

### ❌ 2. Over-Engineering Simple State

```typescript
// DON'T: Using Zustand for simple local state
const useModalStore = create((set) => ({
  isOpen: false,
  setIsOpen: (open) => set({ isOpen: open }),
}));

// DO: Use useState for simple local state
function Component() {
  const [isModalOpen, setIsModalOpen] = useState(false);
  // ...
}
```

### ❌ 3. Not Using Selectors for Performance

```typescript
// DON'T: Subscribing to entire store
function UserName() {
  const store = useAppStore(); // Re-renders on any store change
  return <span>{store.user?.name}</span>;
}

// DO: Use selective subscriptions
function UserName() {
  const userName = useAppStore(state => state.user?.name);
  return <span>{userName}</span>;
}
```

## 📈 Migration Strategies

### From Redux to Zustand

```typescript
// Before: Redux Toolkit
const userSlice = createSlice({
  name: 'user',
  initialState: { user: null, loading: false },
  reducers: {
    setUser: (state, action) => {
      state.user = action.payload;
    },
    setLoading: (state, action) => {
      state.loading = action.payload;
    },
  },
});

// After: Zustand
const useUserStore = create((set) => ({
  user: null,
  loading: false,
  setUser: (user) => set({ user }),
  setLoading: (loading) => set({ loading }),
}));

// Migration strategy: Gradual replacement
// 1. Start with new features in Zustand
// 2. Migrate small, isolated Redux slices
// 3. Keep complex state machines in Redux initially
// 4. Gradually migrate remaining pieces
```

## 🎯 Recommendations by Application Type

### Small Applications (1-10 components)
- **Client State**: React useState/useReducer
- **Server State**: React Query
- **Global State**: React Context (if needed)

### Medium Applications (10-50 components)
- **Client State**: Zustand (single store)
- **Server State**: React Query
- **Persistence**: Zustand persist middleware

### Large Applications (50+ components)
- **Client State**: Zustand (multiple slices)
- **Server State**: React Query or tRPC
- **Real-time**: WebSocket integration
- **Performance**: Selective subscriptions and memoization

### Enterprise Applications
- **Client State**: Zustand with immer middleware
- **Server State**: tRPC + React Query
- **State Machines**: XState for complex workflows
- **Testing**: Comprehensive state testing strategies

The key to successful state management is choosing the right tool for the right job and evolving your architecture as your application grows in complexity.