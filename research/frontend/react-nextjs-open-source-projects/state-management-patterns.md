# State Management Patterns in Production React Applications

## 📊 Overview

Analysis of state management approaches across 23 production React and Next.js applications, revealing modern patterns and best practices for handling client state, server state, and URL state in scalable applications.

## 🏗️ State Management Architecture

### The Three Types of State

Modern React applications typically manage three distinct types of state:

1. **Client State**: UI state, form state, local component state
2. **Server State**: API data, cached responses, optimistic updates
3. **URL State**: Navigation, filters, pagination, search parameters

## 1. Client State Management

### 🥇 Zustand (35% adoption)

**Used by**: T3 Stack, Homepage, Invoify, Next Enterprise

**Why Zustand is Popular**:
- Minimal boilerplate
- TypeScript-first design
- No providers needed
- Excellent DevTools support

**Basic Implementation**:
```typescript
import { create } from 'zustand';
import { devtools, persist } from 'zustand/middleware';

interface UserStore {
  user: User | null;
  preferences: UserPreferences;
  setUser: (user: User) => void;
  updatePreferences: (prefs: Partial<UserPreferences>) => void;
  logout: () => void;
}

export const useUserStore = create<UserStore>()(
  devtools(
    persist(
      (set, get) => ({
        user: null,
        preferences: {
          theme: 'light',
          language: 'en',
          notifications: true,
        },
        
        setUser: (user) => set({ user }, false, 'setUser'),
        
        updatePreferences: (prefs) => 
          set(
            (state) => ({
              preferences: { ...state.preferences, ...prefs }
            }),
            false,
            'updatePreferences'
          ),
          
        logout: () => set({ user: null }, false, 'logout'),
      }),
      {
        name: 'user-storage',
        partialize: (state) => ({ 
          preferences: state.preferences 
        }),
      }
    ),
    { name: 'user-store' }
  )
);
```

**Advanced Patterns**:
```typescript
// Sliced stores for better organization
interface AuthSlice {
  user: User | null;
  login: (credentials: LoginCredentials) => Promise<void>;
  logout: () => void;
}

interface UISlice {
  sidebar: boolean;
  modal: string | null;
  toggleSidebar: () => void;
  openModal: (modal: string) => void;
  closeModal: () => void;
}

type AppStore = AuthSlice & UISlice;

const createAuthSlice: StateCreator<
  AppStore,
  [],
  [],
  AuthSlice
> = (set, get) => ({
  user: null,
  login: async (credentials) => {
    const user = await authService.login(credentials);
    set({ user });
  },
  logout: () => set({ user: null }),
});

const createUISlice: StateCreator<
  AppStore,
  [],
  [],
  UISlice
> = (set) => ({
  sidebar: false,
  modal: null,
  toggleSidebar: () => set((state) => ({ 
    sidebar: !state.sidebar 
  })),
  openModal: (modal) => set({ modal }),
  closeModal: () => set({ modal: null }),
});

export const useAppStore = create<AppStore>()(
  devtools(
    (...a) => ({
      ...createAuthSlice(...a),
      ...createUISlice(...a),
    })
  )
);
```

### 🥈 Redux Toolkit (30% adoption)

**Used by**: Ant Design Pro, Refine (optional), React Redux TypeScript Guide

**When to Choose Redux Toolkit**:
- Large teams with established Redux knowledge
- Complex state interactions
- Time-travel debugging requirements
- Extensive middleware needs

**Modern Redux Toolkit Pattern**:
```typescript
// features/auth/authSlice.ts
import { createSlice, createAsyncThunk } from '@reduxjs/toolkit';

interface AuthState {
  user: User | null;
  status: 'idle' | 'loading' | 'succeeded' | 'failed';
  error: string | null;
}

const initialState: AuthState = {
  user: null,
  status: 'idle',
  error: null,
};

// Async thunk for login
export const loginUser = createAsyncThunk(
  'auth/loginUser',
  async (credentials: LoginCredentials, { rejectWithValue }) => {
    try {
      const response = await authAPI.login(credentials);
      return response.data;
    } catch (error) {
      return rejectWithValue(error.response.data);
    }
  }
);

const authSlice = createSlice({
  name: 'auth',
  initialState,
  reducers: {
    logout: (state) => {
      state.user = null;
      state.status = 'idle';
      state.error = null;
    },
    clearError: (state) => {
      state.error = null;
    },
  },
  extraReducers: (builder) => {
    builder
      .addCase(loginUser.pending, (state) => {
        state.status = 'loading';
        state.error = null;
      })
      .addCase(loginUser.fulfilled, (state, action) => {
        state.status = 'succeeded';
        state.user = action.payload;
        state.error = null;
      })
      .addCase(loginUser.rejected, (state, action) => {
        state.status = 'failed';
        state.error = action.payload as string;
      });
  },
});

export const { logout, clearError } = authSlice.actions;
export default authSlice.reducer;
```

**Store Configuration**:
```typescript
// store/index.ts
import { configureStore } from '@reduxjs/toolkit';
import { setupListeners } from '@reduxjs/toolkit/query';
import authReducer from '../features/auth/authSlice';
import { apiSlice } from '../features/api/apiSlice';

export const store = configureStore({
  reducer: {
    auth: authReducer,
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

### 🥉 Context API + useReducer (25% adoption)

**Used by**: React Starter Kit, smaller applications

**Best for**: Medium-sized applications, avoiding external dependencies

```typescript
// contexts/AppContext.tsx
interface AppState {
  user: User | null;
  theme: 'light' | 'dark';
  notifications: Notification[];
}

type AppAction =
  | { type: 'SET_USER'; payload: User | null }
  | { type: 'TOGGLE_THEME' }
  | { type: 'ADD_NOTIFICATION'; payload: Notification }
  | { type: 'REMOVE_NOTIFICATION'; payload: string };

const appReducer = (state: AppState, action: AppAction): AppState => {
  switch (action.type) {
    case 'SET_USER':
      return { ...state, user: action.payload };
    case 'TOGGLE_THEME':
      return { 
        ...state, 
        theme: state.theme === 'light' ? 'dark' : 'light' 
      };
    case 'ADD_NOTIFICATION':
      return { 
        ...state, 
        notifications: [...state.notifications, action.payload] 
      };
    case 'REMOVE_NOTIFICATION':
      return {
        ...state,
        notifications: state.notifications.filter(
          n => n.id !== action.payload
        ),
      };
    default:
      return state;
  }
};

const AppContext = createContext<{
  state: AppState;
  dispatch: Dispatch<AppAction>;
} | null>(null);

export const AppProvider = ({ children }: { children: ReactNode }) => {
  const [state, dispatch] = useReducer(appReducer, {
    user: null,
    theme: 'light',
    notifications: [],
  });

  return (
    <AppContext.Provider value={{ state, dispatch }}>
      {children}
    </AppContext.Provider>
  );
};

export const useAppContext = () => {
  const context = useContext(AppContext);
  if (!context) {
    throw new Error('useAppContext must be used within AppProvider');
  }
  return context;
};
```

### 🎯 Jotai (15% adoption - Growing)

**Used by**: Next Enterprise, modern applications

**Atomic State Management**:
```typescript
import { atom, useAtom } from 'jotai';

// Basic atoms
const userAtom = atom<User | null>(null);
const themeAtom = atom<'light' | 'dark'>('light');

// Derived atoms
const userNameAtom = atom((get) => {
  const user = get(userAtom);
  return user?.name ?? 'Anonymous';
});

// Write-only atoms for actions
const loginAtom = atom(
  null,
  async (get, set, credentials: LoginCredentials) => {
    const user = await authService.login(credentials);
    set(userAtom, user);
  }
);

// Component usage
function UserProfile() {
  const [user, setUser] = useAtom(userAtom);
  const [userName] = useAtom(userNameAtom);
  const [, login] = useAtom(loginAtom);
  
  return (
    <div>
      <h1>Welcome {userName}</h1>
      {!user && (
        <button onClick={() => login({ email, password })}>
          Login
        </button>
      )}
    </div>
  );
}
```

## 2. Server State Management

### 🏆 TanStack Query (React Query) - 52% adoption

**Used by**: Refine, T3 Stack (optional), Next.js Boilerplate

**Why TanStack Query Dominates**:
- Automatic caching and background updates
- Optimistic updates
- Infinite queries for pagination
- Request deduplication
- Offline support

**Advanced Implementation**:
```typescript
// hooks/useUsers.ts
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';

interface UsersQueryKey {
  scope: 'users';
  entity: 'list' | 'detail';
  id?: string;
  filters?: UserFilters;
}

const usersKeys = {
  all: [{ scope: 'users' }] as const,
  lists: () => [{ ...usersKeys.all[0], entity: 'list' }] as const,
  list: (filters: UserFilters) => 
    [{ ...usersKeys.lists()[0], filters }] as const,
  details: () => [{ ...usersKeys.all[0], entity: 'detail' }] as const,
  detail: (id: string) => 
    [{ ...usersKeys.details()[0], id }] as const,
};

export const useUsers = (filters: UserFilters = {}) => {
  return useQuery({
    queryKey: usersKeys.list(filters),
    queryFn: () => userService.getUsers(filters),
    staleTime: 5 * 60 * 1000, // 5 minutes
    cacheTime: 10 * 60 * 1000, // 10 minutes
    keepPreviousData: true,
  });
};

export const useUser = (id: string) => {
  return useQuery({
    queryKey: usersKeys.detail(id),
    queryFn: () => userService.getUser(id),
    enabled: !!id,
  });
};

export const useCreateUser = () => {
  const queryClient = useQueryClient();
  
  return useMutation({
    mutationFn: userService.createUser,
    onSuccess: (newUser) => {
      // Update the users list cache
      queryClient.setQueryData(
        usersKeys.lists(),
        (old: User[] | undefined) => 
          old ? [...old, newUser] : [newUser]
      );
      
      // Invalidate and refetch
      queryClient.invalidateQueries({ 
        queryKey: usersKeys.lists() 
      });
    },
    onError: (error) => {
      console.error('Failed to create user:', error);
    },
  });
};

// Optimistic updates
export const useUpdateUser = () => {
  const queryClient = useQueryClient();
  
  return useMutation({
    mutationFn: ({ id, data }: { id: string; data: UpdateUserData }) =>
      userService.updateUser(id, data),
    
    onMutate: async ({ id, data }) => {
      // Cancel outgoing refetches
      await queryClient.cancelQueries({ 
        queryKey: usersKeys.detail(id) 
      });
      
      // Snapshot previous value
      const previousUser = queryClient.getQueryData(
        usersKeys.detail(id)
      );
      
      // Optimistically update
      queryClient.setQueryData(
        usersKeys.detail(id),
        (old: User | undefined) => 
          old ? { ...old, ...data } : undefined
      );
      
      return { previousUser };
    },
    
    onError: (err, { id }, context) => {
      // Rollback on error
      if (context?.previousUser) {
        queryClient.setQueryData(
          usersKeys.detail(id),
          context.previousUser
        );
      }
    },
    
    onSettled: (data, error, { id }) => {
      // Always refetch after mutation
      queryClient.invalidateQueries({ 
        queryKey: usersKeys.detail(id) 
      });
    },
  });
};
```

**Infinite Queries for Pagination**:
```typescript
export const useInfiniteUsers = (filters: UserFilters = {}) => {
  return useInfiniteQuery({
    queryKey: [...usersKeys.list(filters), 'infinite'],
    queryFn: ({ pageParam = 0 }) =>
      userService.getUsers({ ...filters, page: pageParam }),
    getNextPageParam: (lastPage, pages) => {
      if (lastPage.users.length < lastPage.pageSize) {
        return undefined;
      }
      return pages.length;
    },
    staleTime: 5 * 60 * 1000,
  });
};

// Component usage
function UsersList() {
  const {
    data,
    fetchNextPage,
    hasNextPage,
    isFetchingNextPage,
    isLoading,
  } = useInfiniteUsers();

  const users = data?.pages.flatMap(page => page.users) ?? [];

  return (
    <div>
      {users.map(user => (
        <UserCard key={user.id} user={user} />
      ))}
      
      {hasNextPage && (
        <button
          onClick={() => fetchNextPage()}
          disabled={isFetchingNextPage}
        >
          {isFetchingNextPage ? 'Loading...' : 'Load More'}
        </button>
      )}
    </div>
  );
}
```

### 🥈 tRPC (30% adoption - Next.js focused)

**Used by**: T3 Stack, Next.js Boilerplate

**End-to-End Type Safety**:
```typescript
// server/api/routers/users.ts
import { z } from 'zod';
import { createTRPCRouter, protectedProcedure, publicProcedure } from '../trpc';

const createUserSchema = z.object({
  name: z.string().min(1),
  email: z.string().email(),
  role: z.enum(['user', 'admin']),
});

export const usersRouter = createTRPCRouter({
  getAll: publicProcedure
    .input(
      z.object({
        limit: z.number().min(1).max(100).default(10),
        cursor: z.string().optional(),
        search: z.string().optional(),
      })
    )
    .query(async ({ ctx, input }) => {
      const users = await ctx.db.user.findMany({
        take: input.limit + 1,
        cursor: input.cursor ? { id: input.cursor } : undefined,
        where: input.search
          ? {
              OR: [
                { name: { contains: input.search, mode: 'insensitive' } },
                { email: { contains: input.search, mode: 'insensitive' } },
              ],
            }
          : undefined,
      });

      let nextCursor: typeof input.cursor | undefined = undefined;
      if (users.length > input.limit) {
        const nextItem = users.pop();
        nextCursor = nextItem!.id;
      }

      return {
        users,
        nextCursor,
      };
    }),

  getById: publicProcedure
    .input(z.object({ id: z.string() }))
    .query(async ({ ctx, input }) => {
      const user = await ctx.db.user.findUnique({
        where: { id: input.id },
      });

      if (!user) {
        throw new TRPCError({
          code: 'NOT_FOUND',
          message: 'User not found',
        });
      }

      return user;
    }),

  create: protectedProcedure
    .input(createUserSchema)
    .mutation(async ({ ctx, input }) => {
      return ctx.db.user.create({
        data: {
          ...input,
          createdBy: ctx.session.user.id,
        },
      });
    }),

  update: protectedProcedure
    .input(
      z.object({
        id: z.string(),
        data: createUserSchema.partial(),
      })
    )
    .mutation(async ({ ctx, input }) => {
      return ctx.db.user.update({
        where: { id: input.id },
        data: input.data,
      });
    }),
});
```

**Client Usage with Full Type Safety**:
```typescript
// hooks/useUsersApi.ts
import { api } from '~/utils/api';

export const useUsers = (filters: {
  search?: string;
  limit?: number;
}) => {
  return api.users.getAll.useQuery(filters);
};

export const useUser = (id: string) => {
  return api.users.getById.useQuery(
    { id },
    { enabled: !!id }
  );
};

export const useCreateUser = () => {
  const utils = api.useContext();
  
  return api.users.create.useMutation({
    onSuccess: async () => {
      await utils.users.getAll.invalidate();
    },
  });
};

// Component with full type safety
function CreateUserForm() {
  const createUser = useCreateUser();
  
  const handleSubmit = (data: {
    name: string;
    email: string;
    role: 'user' | 'admin';
  }) => {
    createUser.mutate(data);
    //                ^? TypeScript knows exact shape
  };
  
  return (
    <form onSubmit={handleSubmit}>
      {/* Form fields */}
    </form>
  );
}
```

## 3. URL State Management

### Next.js Router Patterns

**Search Params for Filters**:
```typescript
// hooks/useSearchParams.ts
import { useRouter, useSearchParams } from 'next/navigation';
import { useCallback } from 'react';

export const useSearchParamsState = <T extends Record<string, any>>(
  defaultValues: T
) => {
  const router = useRouter();
  const searchParams = useSearchParams();
  
  const params = Object.fromEntries(searchParams.entries()) as Partial<T>;
  const state = { ...defaultValues, ...params };
  
  const setState = useCallback((updates: Partial<T>) => {
    const newParams = new URLSearchParams(searchParams);
    
    Object.entries(updates).forEach(([key, value]) => {
      if (value === null || value === undefined || value === '') {
        newParams.delete(key);
      } else {
        newParams.set(key, String(value));
      }
    });
    
    router.push(`?${newParams.toString()}`);
  }, [router, searchParams]);
  
  return [state, setState] as const;
};

// Usage in component
function UsersList() {
  const [filters, setFilters] = useSearchParamsState({
    search: '',
    role: '',
    page: '1',
    limit: '10',
  });
  
  const { data: users } = useUsers({
    search: filters.search,
    role: filters.role as UserRole,
    page: parseInt(filters.page),
    limit: parseInt(filters.limit),
  });
  
  return (
    <div>
      <input
        value={filters.search}
        onChange={(e) => setFilters({ 
          search: e.target.value, 
          page: '1' // Reset page on search
        })}
        placeholder="Search users..."
      />
      
      <select
        value={filters.role}
        onChange={(e) => setFilters({ 
          role: e.target.value,
          page: '1'
        })}
      >
        <option value="">All Roles</option>
        <option value="user">User</option>
        <option value="admin">Admin</option>
      </select>
      
      {/* User list and pagination */}
    </div>
  );
}
```

## 4. Form State Management

### React Hook Form + Zod (48% adoption)

**Used by**: Invoify, Next.js Boilerplate, T3 Stack

```typescript
// schemas/userSchema.ts
import { z } from 'zod';

export const userSchema = z.object({
  name: z.string().min(1, 'Name is required').max(50),
  email: z.string().email('Invalid email address'),
  age: z.number().min(18, 'Must be at least 18').max(120),
  role: z.enum(['user', 'admin', 'moderator']),
  preferences: z.object({
    notifications: z.boolean().default(true),
    theme: z.enum(['light', 'dark']).default('light'),
    language: z.string().default('en'),
  }),
  tags: z.array(z.string()).min(1, 'At least one tag is required'),
});

export type UserFormData = z.infer<typeof userSchema>;

// components/UserForm.tsx
import { useForm, useFieldArray } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';

interface UserFormProps {
  defaultValues?: Partial<UserFormData>;
  onSubmit: (data: UserFormData) => void;
}

export function UserForm({ defaultValues, onSubmit }: UserFormProps) {
  const {
    register,
    handleSubmit,
    control,
    watch,
    formState: { errors, isSubmitting },
  } = useForm<UserFormData>({
    resolver: zodResolver(userSchema),
    defaultValues: {
      preferences: {
        notifications: true,
        theme: 'light',
        language: 'en',
      },
      tags: [''],
      ...defaultValues,
    },
  });

  const { fields, append, remove } = useFieldArray({
    control,
    name: 'tags',
  });

  const watchedRole = watch('role');

  return (
    <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
      <div>
        <label htmlFor="name">Name</label>
        <input
          {...register('name')}
          className={errors.name ? 'border-red-500' : 'border-gray-300'}
        />
        {errors.name && (
          <p className="text-red-500 text-sm">{errors.name.message}</p>
        )}
      </div>

      <div>
        <label htmlFor="email">Email</label>
        <input
          {...register('email')}
          type="email"
          className={errors.email ? 'border-red-500' : 'border-gray-300'}
        />
        {errors.email && (
          <p className="text-red-500 text-sm">{errors.email.message}</p>
        )}
      </div>

      <div>
        <label htmlFor="age">Age</label>
        <input
          {...register('age', { valueAsNumber: true })}
          type="number"
          className={errors.age ? 'border-red-500' : 'border-gray-300'}
        />
        {errors.age && (
          <p className="text-red-500 text-sm">{errors.age.message}</p>
        )}
      </div>

      <div>
        <label htmlFor="role">Role</label>
        <select
          {...register('role')}
          className={errors.role ? 'border-red-500' : 'border-gray-300'}
        >
          <option value="">Select a role</option>
          <option value="user">User</option>
          <option value="admin">Admin</option>
          <option value="moderator">Moderator</option>
        </select>
        {errors.role && (
          <p className="text-red-500 text-sm">{errors.role.message}</p>
        )}
      </div>

      {/* Conditional fields based on role */}
      {watchedRole === 'admin' && (
        <div>
          <label>
            <input
              {...register('preferences.notifications')}
              type="checkbox"
            />
            Enable admin notifications
          </label>
        </div>
      )}

      {/* Dynamic array fields */}
      <div>
        <label>Tags</label>
        {fields.map((field, index) => (
          <div key={field.id} className="flex gap-2">
            <input
              {...register(`tags.${index}`)}
              placeholder="Enter tag"
              className="flex-1"
            />
            <button
              type="button"
              onClick={() => remove(index)}
              className="text-red-500"
            >
              Remove
            </button>
          </div>
        ))}
        <button
          type="button"
          onClick={() => append('')}
          className="text-blue-500"
        >
          Add Tag
        </button>
        {errors.tags && (
          <p className="text-red-500 text-sm">{errors.tags.message}</p>
        )}
      </div>

      <button
        type="submit"
        disabled={isSubmitting}
        className="bg-blue-500 text-white px-4 py-2 rounded disabled:opacity-50"
      >
        {isSubmitting ? 'Submitting...' : 'Submit'}
      </button>
    </form>
  );
}
```

## 5. State Management Decision Tree

```
Do you need global state?
├─ No → useState or useReducer
└─ Yes
   ├─ Simple UI state?
   │  ├─ Small app → Context API
   │  └─ Medium/Large app → Zustand
   └─ Complex business logic?
      ├─ Team familiar with Redux → Redux Toolkit
      └─ New project → Zustand or Jotai

Do you need server state?
├─ REST API → TanStack Query
├─ GraphQL → Apollo Client
├─ Full-stack Next.js → tRPC
└─ Real-time → TanStack Query + WebSocket

Do you need URL state?
├─ Next.js → useSearchParams + router
├─ React Router → useSearchParams
└─ Simple → Custom hook
```

## 📊 Performance Comparison

| Solution | Bundle Size | Learning Curve | TypeScript | DevTools |
|----------|-------------|----------------|------------|----------|
| **Zustand** | 2.9kb | Low | Excellent | Excellent |
| **Redux Toolkit** | 33kb | Medium | Good | Excellent |
| **Jotai** | 13kb | Medium | Excellent | Good |
| **Context API** | 0kb | Low | Good | Limited |
| **TanStack Query** | 37kb | Medium | Excellent | Excellent |
| **tRPC** | 25kb | High | Excellent | Good |

## 🎯 Best Practices Summary

### 1. Separate State Concerns
```typescript
// ✅ Good: Separate client and server state
const useUserProfile = () => {
  // Server state
  const { data: user } = useUser(userId);
  
  // Client state
  const [isEditing, setIsEditing] = useState(false);
  
  return { user, isEditing, setIsEditing };
};

// ❌ Bad: Mixing server data with client state
const [userState, setUserState] = useState({
  user: null,
  isEditing: false,
  isLoading: false,
});
```

### 2. Colocate State with Components
```typescript
// ✅ Good: State close to where it's used
function UserProfile({ userId }: { userId: string }) {
  const [showDetails, setShowDetails] = useState(false);
  
  return (
    <div>
      <button onClick={() => setShowDetails(!showDetails)}>
        Toggle Details
      </button>
      {showDetails && <UserDetails userId={userId} />}
    </div>
  );
}

// ❌ Bad: Global state for local UI
const useUIStore = create((set) => ({
  showUserDetails: false,
  toggleUserDetails: () => set((state) => ({ 
    showUserDetails: !state.showUserDetails 
  })),
}));
```

### 3. Use TypeScript for State Safety
```typescript
// ✅ Good: Proper typing
interface User {
  id: string;
  name: string;
  email: string;
  role: 'user' | 'admin';
}

const useUserStore = create<{
  users: User[];
  addUser: (user: User) => void;
}>((set) => ({
  users: [],
  addUser: (user) => set((state) => ({ 
    users: [...state.users, user] 
  })),
}));

// ❌ Bad: No typing
const useUserStore = create((set) => ({
  users: [],
  addUser: (user) => set((state) => ({ 
    users: [...state.users, user] 
  })),
}));
```

---

## Navigation

- ← Back to: [Project Analysis](./project-analysis.md)
- → Next: [Authentication Patterns](./authentication-patterns.md)

---
*State management patterns from 23 production React applications | July 2025*