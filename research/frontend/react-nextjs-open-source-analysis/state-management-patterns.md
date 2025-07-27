# State Management Patterns in React & Next.js Applications

## 🎯 Overview

Analysis of state management approaches used in production React and Next.js applications, covering Zustand, Redux Toolkit, Context API, and server state patterns.

## 📊 State Management Landscape

### **Adoption Analysis**
- **Zustand**: 80% of analyzed projects
- **Redux Toolkit**: 15% (mostly legacy projects)
- **Context API**: 5% (component-specific state)
- **No external state**: Modern apps with server state focus

## 🏆 Zustand: The Clear Winner

### **Why Zustand Dominates**

```typescript
// ✅ Clean, minimal API
interface UserStore {
  user: User | null;
  setUser: (user: User) => void;
  logout: () => void;
}

export const useUserStore = create<UserStore>((set) => ({
  user: null,
  setUser: (user) => set({ user }),
  logout: () => set({ user: null }),
}));

// ✅ Easy to use in components
function ProfileCard() {
  const { user, logout } = useUserStore();
  
  if (!user) return <LoginPrompt />;
  
  return (
    <Card>
      <h2>{user.name}</h2>
      <Button onClick={logout}>Logout</Button>
    </Card>
  );
}
```

### **Advanced Zustand Patterns**

**🔄 Async Actions with Error Handling**
```typescript
interface TaskStore {
  tasks: Task[];
  isLoading: boolean;
  error: string | null;
  fetchTasks: () => Promise<void>;
  createTask: (title: string) => Promise<void>;
  updateTask: (id: string, updates: Partial<Task>) => Promise<void>;
  deleteTask: (id: string) => Promise<void>;
}

export const useTaskStore = create<TaskStore>((set, get) => ({
  tasks: [],
  isLoading: false,
  error: null,

  fetchTasks: async () => {
    set({ isLoading: true, error: null });
    try {
      const tasks = await taskService.getTasks();
      set({ tasks, isLoading: false });
    } catch (error) {
      set({ 
        error: error instanceof Error ? error.message : 'Failed to fetch tasks',
        isLoading: false 
      });
    }
  },

  createTask: async (title) => {
    try {
      const newTask = await taskService.createTask({ title });
      set((state) => ({ 
        tasks: [...state.tasks, newTask],
        error: null 
      }));
    } catch (error) {
      set({ error: 'Failed to create task' });
      throw error; // Re-throw for component handling
    }
  },

  updateTask: async (id, updates) => {
    try {
      const updatedTask = await taskService.updateTask(id, updates);
      set((state) => ({
        tasks: state.tasks.map(task => 
          task.id === id ? updatedTask : task
        ),
        error: null
      }));
    } catch (error) {
      set({ error: 'Failed to update task' });
      throw error;
    }
  },

  deleteTask: async (id) => {
    try {
      await taskService.deleteTask(id);
      set((state) => ({
        tasks: state.tasks.filter(task => task.id !== id),
        error: null
      }));
    } catch (error) {
      set({ error: 'Failed to delete task' });
      throw error;
    }
  },
}));
```

**🎯 Computed Values with Selectors**
```typescript
interface ProjectStore {
  projects: Project[];
  filters: ProjectFilters;
  setFilters: (filters: Partial<ProjectFilters>) => void;
}

export const useProjectStore = create<ProjectStore>((set) => ({
  projects: [],
  filters: { status: 'all', priority: 'all', assignee: 'all' },
  setFilters: (newFilters) => 
    set((state) => ({ 
      filters: { ...state.filters, ...newFilters } 
    })),
}));

// Computed selectors
export const useFilteredProjects = () => {
  return useProjectStore((state) => {
    const { projects, filters } = state;
    
    return projects.filter((project) => {
      if (filters.status !== 'all' && project.status !== filters.status) {
        return false;
      }
      if (filters.priority !== 'all' && project.priority !== filters.priority) {
        return false;
      }
      if (filters.assignee !== 'all' && project.assigneeId !== filters.assignee) {
        return false;
      }
      return true;
    });
  });
};

export const useProjectStats = () => {
  return useProjectStore((state) => {
    const projects = state.projects;
    
    return {
      total: projects.length,
      completed: projects.filter(p => p.status === 'completed').length,
      inProgress: projects.filter(p => p.status === 'in-progress').length,
      pending: projects.filter(p => p.status === 'pending').length,
    };
  });
};
```

**🔧 Store Composition & Modularity**
```typescript
// stores/user.store.ts
export interface UserSlice {
  user: User | null;
  setUser: (user: User) => void;
  logout: () => void;
}

export const createUserSlice: StateCreator<
  UserSlice & NotificationSlice,
  [],
  [],
  UserSlice
> = (set) => ({
  user: null,
  setUser: (user) => set({ user }),
  logout: () => set({ user: null }),
});

// stores/notification.store.ts
export interface NotificationSlice {
  notifications: Notification[];
  addNotification: (notification: Omit<Notification, 'id'>) => void;
  removeNotification: (id: string) => void;
  clearNotifications: () => void;
}

export const createNotificationSlice: StateCreator<
  UserSlice & NotificationSlice,
  [],
  [],
  NotificationSlice
> = (set) => ({
  notifications: [],
  addNotification: (notification) => 
    set((state) => ({
      notifications: [
        ...state.notifications,
        { ...notification, id: nanoid() }
      ]
    })),
  removeNotification: (id) =>
    set((state) => ({
      notifications: state.notifications.filter(n => n.id !== id)
    })),
  clearNotifications: () => set({ notifications: [] }),
});

// stores/index.ts
export const useAppStore = create<UserSlice & NotificationSlice>()(
  (...a) => ({
    ...createUserSlice(...a),
    ...createNotificationSlice(...a),
  })
);
```

**🎪 Persistence with localStorage**
```typescript
interface SettingsStore {
  theme: 'light' | 'dark' | 'system';
  language: string;
  notifications: boolean;
  setTheme: (theme: 'light' | 'dark' | 'system') => void;
  setLanguage: (language: string) => void;
  toggleNotifications: () => void;
}

export const useSettingsStore = create<SettingsStore>()(
  persist(
    (set) => ({
      theme: 'system',
      language: 'en',
      notifications: true,
      
      setTheme: (theme) => set({ theme }),
      setLanguage: (language) => set({ language }),
      toggleNotifications: () => 
        set((state) => ({ notifications: !state.notifications })),
    }),
    {
      name: 'app-settings',
      storage: createJSONStorage(() => localStorage),
    }
  )
);
```

## 🔄 Server State Management

### **React Query (TanStack Query) Integration**

```typescript
// hooks/use-projects.ts
export const useProjects = (filters?: ProjectFilters) => {
  return useQuery({
    queryKey: ['projects', filters],
    queryFn: () => projectService.getProjects(filters),
    staleTime: 5 * 60 * 1000, // 5 minutes
    gcTime: 10 * 60 * 1000, // 10 minutes
  });
};

export const useProject = (id: string) => {
  return useQuery({
    queryKey: ['project', id],
    queryFn: () => projectService.getProject(id),
    enabled: !!id,
  });
};

export const useCreateProject = () => {
  const queryClient = useQueryClient();
  
  return useMutation({
    mutationFn: projectService.createProject,
    onSuccess: (newProject) => {
      // Update projects list
      queryClient.setQueryData(
        ['projects'],
        (old: Project[] | undefined) => 
          old ? [...old, newProject] : [newProject]
      );
      
      // Set individual project cache
      queryClient.setQueryData(['project', newProject.id], newProject);
    },
    onError: (error) => {
      toast.error('Failed to create project');
    },
  });
};

export const useUpdateProject = () => {
  const queryClient = useQueryClient();
  
  return useMutation({
    mutationFn: ({ id, updates }: { id: string; updates: Partial<Project> }) =>
      projectService.updateProject(id, updates),
    onSuccess: (updatedProject) => {
      // Update projects list
      queryClient.setQueryData(
        ['projects'],
        (old: Project[] | undefined) =>
          old?.map(project => 
            project.id === updatedProject.id ? updatedProject : project
          )
      );
      
      // Update individual project cache
      queryClient.setQueryData(['project', updatedProject.id], updatedProject);
    },
  });
};
```

### **SWR Patterns**

```typescript
// hooks/use-swr-projects.ts
export const useProjects = (filters?: ProjectFilters) => {
  const { data, error, mutate } = useSWR(
    ['projects', filters],
    () => projectService.getProjects(filters),
    {
      revalidateOnFocus: false,
      revalidateOnReconnect: true,
      refreshInterval: 30000, // 30 seconds
    }
  );

  return {
    projects: data,
    isLoading: !error && !data,
    isError: error,
    mutate,
  };
};

export const useOptimisticUpdate = () => {
  const { mutate } = useProjects();
  
  const updateProject = async (id: string, updates: Partial<Project>) => {
    // Optimistic update
    mutate(
      (currentProjects) =>
        currentProjects?.map(project =>
          project.id === id ? { ...project, ...updates } : project
        ),
      false // Don't revalidate immediately
    );
    
    try {
      await projectService.updateProject(id, updates);
      // Revalidate to get fresh data
      mutate();
    } catch (error) {
      // Revert on error
      mutate();
      throw error;
    }
  };
  
  return { updateProject };
};
```

## 🏛️ Redux Toolkit (Legacy Projects)

### **Modern Redux Toolkit Pattern**

```typescript
// store/projectSlice.ts
import { createSlice, createAsyncThunk, PayloadAction } from '@reduxjs/toolkit';

export const fetchProjects = createAsyncThunk(
  'projects/fetchProjects',
  async (filters?: ProjectFilters) => {
    const response = await projectService.getProjects(filters);
    return response;
  }
);

export const createProject = createAsyncThunk(
  'projects/createProject',
  async (projectData: CreateProjectInput) => {
    const response = await projectService.createProject(projectData);
    return response;
  }
);

interface ProjectState {
  projects: Project[];
  loading: boolean;
  error: string | null;
  filters: ProjectFilters;
}

const initialState: ProjectState = {
  projects: [],
  loading: false,
  error: null,
  filters: { status: 'all', priority: 'all' },
};

const projectSlice = createSlice({
  name: 'projects',
  initialState,
  reducers: {
    setFilters: (state, action: PayloadAction<Partial<ProjectFilters>>) => {
      state.filters = { ...state.filters, ...action.payload };
    },
    clearError: (state) => {
      state.error = null;
    },
  },
  extraReducers: (builder) => {
    builder
      .addCase(fetchProjects.pending, (state) => {
        state.loading = true;
        state.error = null;
      })
      .addCase(fetchProjects.fulfilled, (state, action) => {
        state.loading = false;
        state.projects = action.payload;
      })
      .addCase(fetchProjects.rejected, (state, action) => {
        state.loading = false;
        state.error = action.error.message || 'Failed to fetch projects';
      })
      .addCase(createProject.fulfilled, (state, action) => {
        state.projects.push(action.payload);
      });
  },
});

export const { setFilters, clearError } = projectSlice.actions;
export default projectSlice.reducer;
```

## 🎭 Context API (Component-Specific State)

### **Theme Context Pattern**

```typescript
// contexts/ThemeContext.tsx
interface ThemeContextValue {
  theme: 'light' | 'dark';
  toggleTheme: () => void;
}

const ThemeContext = createContext<ThemeContextValue | undefined>(undefined);

export const ThemeProvider: FC<{ children: ReactNode }> = ({ children }) => {
  const [theme, setTheme] = useState<'light' | 'dark'>('light');
  
  const toggleTheme = useCallback(() => {
    setTheme(prev => prev === 'light' ? 'dark' : 'light');
  }, []);
  
  useEffect(() => {
    document.documentElement.setAttribute('data-theme', theme);
  }, [theme]);
  
  return (
    <ThemeContext.Provider value={{ theme, toggleTheme }}>
      {children}
    </ThemeContext.Provider>
  );
};

export const useTheme = () => {
  const context = useContext(ThemeContext);
  if (!context) {
    throw new Error('useTheme must be used within a ThemeProvider');
  }
  return context;
};
```

## 📊 Performance Optimization

### **Zustand Performance Tips**

```typescript
// ✅ Use selectors to prevent unnecessary re-renders
const user = useUserStore(state => state.user);
const userName = useUserStore(state => state.user?.name);

// ✅ Memoize complex selectors
const filteredProjects = useProjectStore(
  useCallback(
    state => state.projects.filter(p => p.status === 'active'),
    []
  )
);

// ✅ Split large stores into smaller ones
const useUIStore = create(() => ({
  sidebar: { isOpen: false },
  modal: { isOpen: false, content: null },
}));

const useDataStore = create(() => ({
  projects: [],
  tasks: [],
  users: [],
}));
```

### **React Query Optimization**

```typescript
// ✅ Use prefetching for better UX
export const usePrefetchProject = () => {
  const queryClient = useQueryClient();
  
  return (id: string) => {
    queryClient.prefetchQuery({
      queryKey: ['project', id],
      queryFn: () => projectService.getProject(id),
      staleTime: 10 * 1000, // 10 seconds
    });
  };
};

// ✅ Implement optimistic updates
export const useOptimisticProjectUpdate = () => {
  const queryClient = useQueryClient();
  
  return useMutation({
    mutationFn: updateProject,
    onMutate: async (variables) => {
      await queryClient.cancelQueries({ queryKey: ['project', variables.id] });
      
      const previousProject = queryClient.getQueryData(['project', variables.id]);
      
      queryClient.setQueryData(['project', variables.id], {
        ...previousProject,
        ...variables.updates,
      });
      
      return { previousProject };
    },
    onError: (err, variables, context) => {
      queryClient.setQueryData(
        ['project', variables.id],
        context?.previousProject
      );
    },
    onSettled: (data, error, variables) => {
      queryClient.invalidateQueries({ queryKey: ['project', variables.id] });
    },
  });
};
```

## 🎯 State Management Decision Matrix

| Use Case | Recommendation | Reason |
|----------|----------------|---------|
| **Global UI State** | Zustand | Simple, performant, TypeScript-friendly |
| **Server State** | React Query/SWR | Caching, background updates, error handling |
| **Component State** | useState/useReducer | Built-in, no external dependencies |
| **Theme/Settings** | Zustand + Persist | Global access, localStorage integration |
| **Complex Forms** | React Hook Form | Performance, validation, minimal re-renders |
| **Legacy Projects** | Redux Toolkit | Migration path, existing ecosystem |

## 🏆 Best Practices Summary

### **✅ Do's**
1. **Use Zustand** for new projects requiring global state
2. **Combine with React Query** for server state management
3. **Keep stores focused** - single responsibility principle
4. **Use TypeScript** for better DX and fewer bugs
5. **Implement error handling** in async actions
6. **Use selectors** to prevent unnecessary re-renders

### **❌ Don'ts**
1. **Don't put everything in global state** - prefer local state when possible
2. **Don't mix server and client state** in the same store
3. **Don't ignore error states** - always handle loading/error scenarios
4. **Don't over-engineer** - start simple and evolve
5. **Don't forget persistence** for user preferences

---

## Navigation

- ← Previous: [Popular Projects Analysis](./popular-projects-analysis.md)
- → Next: [Component Library Strategies](./component-library-strategies.md)

| [📋 Overview](./README.md) | [📊 Executive Summary](./executive-summary.md) | [🏗️ Projects Analysis](./popular-projects-analysis.md) | [⚡ State Management](#) |
|---|---|---|---|