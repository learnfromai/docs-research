# State Management Patterns in React/Next.js Applications

Comprehensive analysis of state management approaches used in production React and Next.js applications, from traditional Redux to modern solutions like Zustand and React Query.

## State Management Evolution Timeline

### Era 1: Redux Dominance (2015-2020)
- **Redux + React-Redux**: Global state management standard
- **Redux-Saga/Redux-Thunk**: Side effect management
- **Challenges**: Boilerplate code, complexity for simple use cases

### Era 2: Context API Rise (2018-2021)
- **React Context**: Built-in global state solution
- **useReducer + Context**: Redux-like patterns without external dependencies
- **Challenges**: Performance issues with frequent updates

### Era 3: Specialized Solutions (2020-Present)
- **React Query/SWR**: Server state management
- **Zustand/Jotai**: Lightweight client state
- **Form Libraries**: React Hook Form for form-specific state

## Modern State Management Architecture

### State Classification Framework

```typescript
// 1. Server State (Remote data)
interface ServerState {
  users: User[];
  posts: Post[];
  // Managed by React Query/SWR
}

// 2. Client State (UI state)
interface ClientState {
  theme: 'light' | 'dark';
  sidebarOpen: boolean;
  // Managed by Zustand/Context
}

// 3. URL State (Navigation state)
interface URLState {
  currentPage: string;
  filters: FilterParams;
  // Managed by Next.js Router
}

// 4. Form State (Form-specific state)
interface FormState {
  values: FormValues;
  errors: FormErrors;
  // Managed by React Hook Form
}
```

## Server State Management Patterns

### React Query (TanStack Query) - The Modern Standard

**Adoption**: 85% of analyzed projects use React Query for server state

#### Basic Implementation
```typescript
// API service function
const fetchUsers = async (): Promise<User[]> => {
  const response = await fetch('/api/users');
  if (!response.ok) throw new Error('Failed to fetch users');
  return response.json();
};

// React Query hook
const useUsers = () => {
  return useQuery({
    queryKey: ['users'],
    queryFn: fetchUsers,
    staleTime: 5 * 60 * 1000, // 5 minutes
    cacheTime: 10 * 60 * 1000, // 10 minutes
  });
};

// Component usage
const UserList = () => {
  const { data: users, isLoading, error } = useUsers();
  
  if (isLoading) return <div>Loading...</div>;
  if (error) return <div>Error: {error.message}</div>;
  
  return (
    <ul>
      {users?.map(user => (
        <li key={user.id}>{user.name}</li>
      ))}
    </ul>
  );
};
```

#### Advanced Patterns from Cal.com
```typescript
// Optimistic updates
const useUpdateUser = () => {
  const queryClient = useQueryClient();
  
  return useMutation({
    mutationFn: updateUser,
    onMutate: async (newUser) => {
      // Cancel outgoing refetches
      await queryClient.cancelQueries(['users', newUser.id]);
      
      // Snapshot previous value
      const previousUser = queryClient.getQueryData(['users', newUser.id]);
      
      // Optimistically update
      queryClient.setQueryData(['users', newUser.id], newUser);
      
      return { previousUser };
    },
    onError: (err, newUser, context) => {
      // Rollback on error
      queryClient.setQueryData(['users', newUser.id], context?.previousUser);
    },
    onSettled: () => {
      // Refetch after error or success
      queryClient.invalidateQueries(['users']);
    },
  });
};
```

#### Infinite Queries Pattern
```typescript
// Infinite scroll implementation
const useInfiniteUsers = () => {
  return useInfiniteQuery({
    queryKey: ['users', 'infinite'],
    queryFn: ({ pageParam = 0 }) => fetchUsers(pageParam),
    getNextPageParam: (lastPage, pages) => lastPage.nextCursor,
    staleTime: 5 * 60 * 1000,
  });
};

const InfiniteUserList = () => {
  const {
    data,
    fetchNextPage,
    hasNextPage,
    isFetchingNextPage,
  } = useInfiniteUsers();

  return (
    <div>
      {data?.pages.map((group, i) => (
        <React.Fragment key={i}>
          {group.users.map(user => (
            <UserCard key={user.id} user={user} />
          ))}
        </React.Fragment>
      ))}
      
      <button
        onClick={() => fetchNextPage()}
        disabled={!hasNextPage || isFetchingNextPage}
      >
        {isFetchingNextPage ? 'Loading more...' : 'Load More'}
      </button>
    </div>
  );
};
```

### SWR - Alternative Server State Solution

**Adoption**: 15% of projects, popular in Plane and other applications

```typescript
// SWR usage pattern
const useProjects = () => {
  const { data, error, mutate } = useSWR(
    '/api/projects',
    fetcher,
    {
      refreshInterval: 5000, // Auto-refresh every 5 seconds
      revalidateOnFocus: true,
      dedupingInterval: 2000,
    }
  );

  return {
    projects: data,
    isLoading: !error && !data,
    isError: error,
    mutate,
  };
};

// Real-time updates with SWR
const useRealtimeProjects = () => {
  const { data, mutate } = useSWR('/api/projects', fetcher);
  
  useEffect(() => {
    const ws = new WebSocket('ws://localhost:8000/projects');
    
    ws.onmessage = (event) => {
      const update = JSON.parse(event.data);
      // Trigger revalidation on WebSocket updates
      mutate();
    };
    
    return () => ws.close();
  }, [mutate]);
  
  return data;
};
```

## Client State Management Patterns

### Zustand - The Lightweight Champion

**Adoption**: 60% of projects for client state management

#### Basic Store Implementation
```typescript
// Store definition
interface AppState {
  // State
  theme: 'light' | 'dark';
  sidebarOpen: boolean;
  user: User | null;
  
  // Actions
  setTheme: (theme: 'light' | 'dark') => void;
  toggleSidebar: () => void;
  setUser: (user: User | null) => void;
  
  // Computed values
  isAuthenticated: boolean;
}

const useAppStore = create<AppState>((set, get) => ({
  // Initial state
  theme: 'light',
  sidebarOpen: false,
  user: null,
  
  // Actions
  setTheme: (theme) => set({ theme }),
  toggleSidebar: () => set((state) => ({ 
    sidebarOpen: !state.sidebarOpen 
  })),
  setUser: (user) => set({ user }),
  
  // Computed state
  get isAuthenticated() {
    return get().user !== null;
  },
}));
```

#### Advanced Zustand Patterns from T3 Stack
```typescript
// Slices pattern for large stores
interface UserSlice {
  user: User | null;
  setUser: (user: User | null) => void;
  clearUser: () => void;
}

interface UISlice {
  theme: Theme;
  sidebarOpen: boolean;
  setTheme: (theme: Theme) => void;
  toggleSidebar: () => void;
}

const createUserSlice: StateCreator<UserSlice> = (set) => ({
  user: null,
  setUser: (user) => set({ user }),
  clearUser: () => set({ user: null }),
});

const createUISlice: StateCreator<UISlice> = (set) => ({
  theme: 'light',
  sidebarOpen: false,
  setTheme: (theme) => set({ theme }),
  toggleSidebar: () => set((state) => ({ 
    sidebarOpen: !state.sidebarOpen 
  })),
});

// Combine slices
const useStore = create<UserSlice & UISlice>()((...a) => ({
  ...createUserSlice(...a),
  ...createUISlice(...a),
}));
```

#### Persistence and Middleware
```typescript
// Persistent store with localStorage
const usePersistedStore = create<AppState>()(
  persist(
    (set, get) => ({
      theme: 'light',
      setTheme: (theme) => set({ theme }),
    }),
    {
      name: 'app-storage',
      partialize: (state) => ({ theme: state.theme }), // Only persist theme
    }
  )
);

// DevTools integration
const useDevToolsStore = create<AppState>()(
  devtools(
    (set, get) => ({
      count: 0,
      increment: () => set((state) => ({ count: state.count + 1 })),
    }),
    {
      name: 'app-store',
    }
  )
);
```

### Redux Toolkit - Enterprise Standard

**Adoption**: 40% of projects, primarily in enterprise applications

#### Modern Redux Implementation
```typescript
// Slice definition
const userSlice = createSlice({
  name: 'user',
  initialState: {
    currentUser: null,
    preferences: {},
    loading: false,
  } as UserState,
  reducers: {
    setUser: (state, action) => {
      state.currentUser = action.payload;
    },
    updatePreferences: (state, action) => {
      state.preferences = { ...state.preferences, ...action.payload };
    },
    setLoading: (state, action) => {
      state.loading = action.payload;
    },
  },
  extraReducers: (builder) => {
    builder
      .addCase(fetchUser.pending, (state) => {
        state.loading = true;
      })
      .addCase(fetchUser.fulfilled, (state, action) => {
        state.currentUser = action.payload;
        state.loading = false;
      });
  },
});

// Async thunk
const fetchUser = createAsyncThunk(
  'user/fetchUser',
  async (userId: string) => {
    const response = await api.get(`/users/${userId}`);
    return response.data;
  }
);

// Store configuration
const store = configureStore({
  reducer: {
    user: userSlice.reducer,
    // other slices...
  },
  middleware: (getDefaultMiddleware) =>
    getDefaultMiddleware({
      serializableCheck: {
        ignoredActions: [FLUSH, REHYDRATE, PAUSE, PERSIST, PURGE, REGISTER],
      },
    }),
});
```

#### RTK Query Integration
```typescript
// API slice
const apiSlice = createApi({
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
  tagTypes: ['User', 'Post'],
  endpoints: (builder) => ({
    getUsers: builder.query<User[], void>({
      query: () => 'users',
      providesTags: ['User'],
    }),
    updateUser: builder.mutation<User, Partial<User> & Pick<User, 'id'>>({
      query: ({ id, ...patch }) => ({
        url: `users/${id}`,
        method: 'PATCH',
        body: patch,
      }),
      invalidatesTags: (result, error, arg) => [{ type: 'User', id: arg.id }],
    }),
  }),
});

export const { useGetUsersQuery, useUpdateUserMutation } = apiSlice;
```

## Form State Management

### React Hook Form - Universal Adoption

**Adoption**: 90% of projects use React Hook Form for form management

#### Basic Form Implementation
```typescript
interface FormData {
  email: string;
  password: string;
  rememberMe: boolean;
}

const LoginForm = () => {
  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
    watch,
  } = useForm<FormData>({
    defaultValues: {
      email: '',
      password: '',
      rememberMe: false,
    },
  });

  const onSubmit = async (data: FormData) => {
    try {
      await login(data);
    } catch (error) {
      console.error('Login failed:', error);
    }
  };

  return (
    <form onSubmit={handleSubmit(onSubmit)}>
      <input
        {...register('email', {
          required: 'Email is required',
          pattern: {
            value: /^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$/i,
            message: 'Invalid email address',
          },
        })}
        placeholder="Email"
      />
      {errors.email && <span>{errors.email.message}</span>}
      
      <input
        type="password"
        {...register('password', {
          required: 'Password is required',
          minLength: {
            value: 8,
            message: 'Password must be at least 8 characters',
          },
        })}
        placeholder="Password"
      />
      {errors.password && <span>{errors.password.message}</span>}
      
      <button type="submit" disabled={isSubmitting}>
        {isSubmitting ? 'Logging in...' : 'Login'}
      </button>
    </form>
  );
};
```

#### Advanced Form Patterns with Zod Validation
```typescript
// Zod schema
const loginSchema = z.object({
  email: z.string().email('Invalid email address'),
  password: z.string().min(8, 'Password must be at least 8 characters'),
  rememberMe: z.boolean().optional(),
});

type LoginFormData = z.infer<typeof loginSchema>;

const LoginForm = () => {
  const {
    register,
    handleSubmit,
    formState: { errors },
    control,
  } = useForm<LoginFormData>({
    resolver: zodResolver(loginSchema),
  });

  // Controlled components integration
  const { field: rememberMeField } = useController({
    name: 'rememberMe',
    control,
    defaultValue: false,
  });

  return (
    <form onSubmit={handleSubmit(onSubmit)}>
      {/* form fields */}
      
      <Switch
        checked={rememberMeField.value}
        onCheckedChange={rememberMeField.onChange}
      />
    </form>
  );
};
```

## State Management Decision Matrix

### Project Size vs State Management Solution

| Project Size | Server State | Client State | Form State | Reasoning |
|-------------|--------------|-------------|------------|-----------|
| **Small** (< 10 components) | Fetch + useState | useState/useReducer | React Hook Form | Minimal complexity |
| **Medium** (10-50 components) | React Query | Zustand | React Hook Form | Balanced complexity |
| **Large** (50+ components) | React Query + RTK Query | Redux Toolkit | React Hook Form + Complex validation | Enterprise features |
| **Enterprise** | React Query + Custom | Redux Toolkit | React Hook Form + Zod | Full control and auditability |

### Use Case Recommendations

#### Choose React Query When:
- ✅ Server state management is primary concern
- ✅ Need automatic caching and synchronization
- ✅ Want optimistic updates
- ✅ Real-time data requirements

#### Choose Zustand When:
- ✅ Simple client state management
- ✅ Want minimal boilerplate
- ✅ Need TypeScript-first approach
- ✅ Small to medium applications

#### Choose Redux Toolkit When:
- ✅ Enterprise applications
- ✅ Complex state logic
- ✅ Time-travel debugging requirements
- ✅ Large team collaboration

#### Choose Context API When:
- ✅ Simple global state (theme, auth status)
- ✅ No external dependencies preferred
- ✅ Infrequent state updates
- ✅ Educational projects

## Performance Optimization Patterns

### Selector Patterns
```typescript
// Zustand selectors to prevent unnecessary re-renders
const useUser = () => useStore((state) => state.user);
const useTheme = () => useStore((state) => state.theme);

// Complex selectors with equality function
const useFilteredUsers = (filter: string) =>
  useStore(
    (state) => state.users.filter(user => 
      user.name.toLowerCase().includes(filter.toLowerCase())
    ),
    shallow // Use shallow comparison for arrays
  );
```

### Memoization Strategies
```typescript
// React.memo for expensive components
const UserCard = React.memo(({ user }: { user: User }) => {
  return (
    <div>
      <h3>{user.name}</h3>
      <p>{user.email}</p>
    </div>
  );
});

// useMemo for expensive calculations
const ExpensiveComponent = ({ users }: { users: User[] }) => {
  const sortedUsers = useMemo(
    () => users.sort((a, b) => a.name.localeCompare(b.name)),
    [users]
  );

  return (
    <div>
      {sortedUsers.map(user => (
        <UserCard key={user.id} user={user} />
      ))}
    </div>
  );
};
```

## Testing Strategies

### React Query Testing
```typescript
// Test wrapper with React Query
const createWrapper = () => {
  const queryClient = new QueryClient({
    defaultOptions: {
      queries: {
        retry: false,
      },
    },
  });
  
  return ({ children }: { children: React.ReactNode }) => (
    <QueryClientProvider client={queryClient}>
      {children}
    </QueryClientProvider>
  );
};

// Test component with React Query
test('displays users', async () => {
  render(<UserList />, { wrapper: createWrapper() });
  
  await waitFor(() => {
    expect(screen.getByText('John Doe')).toBeInTheDocument();
  });
});
```

### Zustand Testing
```typescript
// Mock store for testing
const createMockStore = (initialState?: Partial<AppState>) =>
  create<AppState>(() => ({
    theme: 'light',
    user: null,
    setTheme: jest.fn(),
    setUser: jest.fn(),
    ...initialState,
  }));

test('theme toggle works', () => {
  const store = createMockStore();
  
  act(() => {
    store.getState().setTheme('dark');
  });
  
  expect(store.getState().theme).toBe('dark');
});
```

## Migration Strategies

### From Redux to Modern Stack
```typescript
// 1. Start with server state migration
// Replace Redux async actions with React Query
const useUsers = () => {
  return useQuery(['users'], fetchUsers);
};

// 2. Migrate simple client state to Zustand
// Replace Redux slices with Zustand stores
const useUIStore = create((set) => ({
  sidebarOpen: false,
  toggleSidebar: () => set((state) => ({ 
    sidebarOpen: !state.sidebarOpen 
  })),
}));

// 3. Keep complex business logic in Redux Toolkit
// Maintain Redux for complex state machines
```

### From Class Components to Hooks
```typescript
// Before: Class component with state
class UserProfile extends Component {
  state = { user: null, loading: true };
  
  componentDidMount() {
    this.fetchUser();
  }
}

// After: Functional component with hooks
const UserProfile = () => {
  const { data: user, isLoading } = useQuery(['user'], fetchUser);
  
  if (isLoading) return <div>Loading...</div>;
  
  return <div>{user?.name}</div>;
};
```

## Best Practices Summary

### State Management Principles
1. **Separate Concerns**: Different state types need different solutions
2. **Start Simple**: Begin with built-in solutions, evolve as needed
3. **Optimize for Developer Experience**: Choose tools that enhance productivity
4. **Type Safety**: Prefer TypeScript-first solutions
5. **Testing**: Ensure state management is easily testable

### Common Anti-Patterns to Avoid
1. **Over-Engineering**: Using Redux for simple state
2. **Global State Abuse**: Putting all state in global stores
3. **Premature Optimization**: Complex state solutions for simple use cases
4. **Missing Normalization**: Duplicate data in different parts of the store
5. **Ignoring Performance**: Not using selectors or memoization

The modern React ecosystem provides excellent tools for state management. The key is choosing the right tool for each type of state and understanding the trade-offs involved in each decision.

---

**Navigation**
- ← Back to: [Project Analysis](./project-analysis.md)
- → Next: [Component Library Strategies](./component-library-strategies.md)
- → Related: [Implementation Guide](./implementation-guide.md)