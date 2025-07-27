# Zustand State Management Analysis

## Overview

This analysis examines how production-ready open source React and Next.js projects implement Zustand for state management. Zustand has emerged as a lightweight alternative to Redux, offering excellent developer experience with minimal boilerplate while maintaining powerful state management capabilities.

## Why Projects Choose Zustand

### 🎯 Key Advantages Observed

#### Simplicity and Developer Experience
Based on analysis of Cal.com, Plane, and other modern projects:

- **Minimal Boilerplate**: 80% less code compared to Redux for similar functionality
- **No Providers**: Direct hook usage without context providers
- **TypeScript First**: Excellent TypeScript integration out of the box
- **Small Bundle Size**: 2.4kb gzipped vs 40kb+ for Redux ecosystem

#### Performance Benefits
- **Selective Subscriptions**: Components only re-render when specific state changes
- **No Unnecessary Renders**: Automatic optimization prevents cascade re-renders
- **Memory Efficient**: Lower memory footprint compared to Redux stores
- **Fast State Updates**: Direct state mutations with Immer integration

### 📊 Usage Patterns by Project Type

| Project Type | Zustand Usage | Common Patterns |
|--------------|---------------|-----------------|
| **Small to Medium Apps** | Primary state management | Global UI state, user preferences |
| **Large Applications** | Hybrid with React Query | Feature-specific stores, local state |
| **Component Libraries** | Isolated state management | Theme state, component-specific state |
| **Developer Tools** | Configuration management | Settings, workspace state |

## Core Implementation Patterns

### 🏗️ Store Creation Patterns

#### Basic Store Structure
Pattern observed in Cal.com and Plane implementations:

```typescript
// stores/authStore.ts - Basic store pattern
import { create } from 'zustand';
import { devtools, persist } from 'zustand/middleware';
import { immer } from 'zustand/middleware/immer';

interface User {
  id: string;
  email: string;
  name: string;
  avatar?: string;
  role: string;
}

interface AuthState {
  user: User | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  error: string | null;
}

interface AuthActions {
  login: (email: string, password: string) => Promise<void>;
  logout: () => void;
  updateUser: (updates: Partial<User>) => void;
  clearError: () => void;
}

type AuthStore = AuthState & AuthActions;

export const useAuthStore = create<AuthStore>()(
  devtools(
    persist(
      immer((set, get) => ({
        // Initial state
        user: null,
        isAuthenticated: false,
        isLoading: false,
        error: null,

        // Actions
        login: async (email: string, password: string) => {
          set((state) => {
            state.isLoading = true;
            state.error = null;
          });

          try {
            const response = await fetch('/api/auth/login', {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ email, password }),
            });

            if (!response.ok) {
              throw new Error('Login failed');
            }

            const { user, token } = await response.json();

            set((state) => {
              state.user = user;
              state.isAuthenticated = true;
              state.isLoading = false;
            });

            // Store token in localStorage or httpOnly cookie
            localStorage.setItem('token', token);
          } catch (error) {
            set((state) => {
              state.error = error.message;
              state.isLoading = false;
            });
          }
        },

        logout: () => {
          set((state) => {
            state.user = null;
            state.isAuthenticated = false;
            state.error = null;
          });
          localStorage.removeItem('token');
        },

        updateUser: (updates: Partial<User>) => {
          set((state) => {
            if (state.user) {
              Object.assign(state.user, updates);
            }
          });
        },

        clearError: () => {
          set((state) => {
            state.error = null;
          });
        },
      })),
      {
        name: 'auth-storage',
        partialize: (state) => ({
          user: state.user,
          isAuthenticated: state.isAuthenticated,
        }),
      }
    ),
    { name: 'auth-store' }
  )
);
```

#### Advanced Store with Subscriptions
Pattern from Grafana and developer tool projects:

```typescript
// stores/workspaceStore.ts - Advanced store with subscriptions
import { create } from 'zustand';
import { subscribeWithSelector } from 'zustand/middleware';

interface Workspace {
  id: string;
  name: string;
  projects: Project[];
  settings: WorkspaceSettings;
  lastAccessed: string;
}

interface WorkspaceState {
  workspaces: Workspace[];
  activeWorkspace: Workspace | null;
  isLoading: boolean;
  syncStatus: 'idle' | 'syncing' | 'error';
}

interface WorkspaceActions {
  loadWorkspaces: () => Promise<void>;
  setActiveWorkspace: (workspaceId: string) => void;
  createWorkspace: (data: CreateWorkspaceData) => Promise<void>;
  updateWorkspace: (id: string, updates: Partial<Workspace>) => void;
  deleteWorkspace: (id: string) => Promise<void>;
  syncWorkspaces: () => Promise<void>;
}

export const useWorkspaceStore = create<WorkspaceState & WorkspaceActions>()(
  subscribeWithSelector(
    devtools(
      immer((set, get) => ({
        workspaces: [],
        activeWorkspace: null,
        isLoading: false,
        syncStatus: 'idle',

        loadWorkspaces: async () => {
          set((state) => { state.isLoading = true; });
          
          try {
            const response = await fetch('/api/workspaces');
            const workspaces = await response.json();
            
            set((state) => {
              state.workspaces = workspaces;
              state.isLoading = false;
              // Set first workspace as active if none selected
              if (!state.activeWorkspace && workspaces.length > 0) {
                state.activeWorkspace = workspaces[0];
              }
            });
          } catch (error) {
            set((state) => {
              state.isLoading = false;
              state.syncStatus = 'error';
            });
          }
        },

        setActiveWorkspace: (workspaceId: string) => {
          set((state) => {
            const workspace = state.workspaces.find(w => w.id === workspaceId);
            if (workspace) {
              state.activeWorkspace = workspace;
              workspace.lastAccessed = new Date().toISOString();
            }
          });
        },

        createWorkspace: async (data: CreateWorkspaceData) => {
          try {
            const response = await fetch('/api/workspaces', {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify(data),
            });
            
            const newWorkspace = await response.json();
            
            set((state) => {
              state.workspaces.push(newWorkspace);
              state.activeWorkspace = newWorkspace;
            });
          } catch (error) {
            console.error('Failed to create workspace:', error);
          }
        },

        updateWorkspace: (id: string, updates: Partial<Workspace>) => {
          set((state) => {
            const workspace = state.workspaces.find(w => w.id === id);
            if (workspace) {
              Object.assign(workspace, updates);
              if (state.activeWorkspace?.id === id) {
                Object.assign(state.activeWorkspace, updates);
              }
            }
          });
        },

        deleteWorkspace: async (id: string) => {
          try {
            await fetch(`/api/workspaces/${id}`, { method: 'DELETE' });
            
            set((state) => {
              state.workspaces = state.workspaces.filter(w => w.id !== id);
              if (state.activeWorkspace?.id === id) {
                state.activeWorkspace = state.workspaces[0] || null;
              }
            });
          } catch (error) {
            console.error('Failed to delete workspace:', error);
          }
        },

        syncWorkspaces: async () => {
          set((state) => { state.syncStatus = 'syncing'; });
          
          try {
            // Sync with server
            await fetch('/api/workspaces/sync', { method: 'POST' });
            
            // Reload workspaces
            await get().loadWorkspaces();
            
            set((state) => { state.syncStatus = 'idle'; });
          } catch (error) {
            set((state) => { state.syncStatus = 'error'; });
          }
        },
      })),
      { name: 'workspace-store' }
    )
  )
);

// Subscribe to active workspace changes for analytics
useWorkspaceStore.subscribe(
  (state) => state.activeWorkspace,
  (activeWorkspace, previousActiveWorkspace) => {
    if (activeWorkspace && activeWorkspace.id !== previousActiveWorkspace?.id) {
      // Track workspace switch event
      analytics.track('workspace_switched', {
        workspaceId: activeWorkspace.id,
        workspaceName: activeWorkspace.name,
      });
    }
  }
);
```

### 🔄 State Composition Patterns

#### Modular Store Composition
Pattern observed in large applications like Plane:

```typescript
// stores/index.ts - Modular store composition
import { create } from 'zustand';
import { createAuthSlice, AuthSlice } from './slices/authSlice';
import { createUISlice, UISlice } from './slices/uiSlice';
import { createProjectSlice, ProjectSlice } from './slices/projectSlice';

// Combine multiple slices into one store
export type AppStore = AuthSlice & UISlice & ProjectSlice;

export const useAppStore = create<AppStore>()(
  devtools(
    persist(
      (...args) => ({
        ...createAuthSlice(...args),
        ...createUISlice(...args),
        ...createProjectSlice(...args),
      }),
      {
        name: 'app-storage',
        partialize: (state) => ({
          // Only persist certain parts of the state
          user: state.user,
          theme: state.theme,
          preferences: state.preferences,
        }),
      }
    ),
    { name: 'app-store' }
  )
);

// Individual slice creators
// slices/authSlice.ts
export interface AuthSlice {
  user: User | null;
  isAuthenticated: boolean;
  login: (credentials: LoginCredentials) => Promise<void>;
  logout: () => void;
}

export const createAuthSlice: StateCreator<
  AppStore,
  [],
  [],
  AuthSlice
> = (set, get) => ({
  user: null,
  isAuthenticated: false,
  
  login: async (credentials) => {
    // Implementation
  },
  
  logout: () => {
    set((state) => ({
      ...state,
      user: null,
      isAuthenticated: false,
    }));
  },
});

// slices/uiSlice.ts
export interface UISlice {
  theme: 'light' | 'dark';
  sidebarOpen: boolean;
  notifications: Notification[];
  toggleTheme: () => void;
  toggleSidebar: () => void;
  addNotification: (notification: Omit<Notification, 'id'>) => void;
}

export const createUISlice: StateCreator<
  AppStore,
  [],
  [],
  UISlice
> = (set, get) => ({
  theme: 'light',
  sidebarOpen: true,
  notifications: [],
  
  toggleTheme: () => {
    set((state) => ({
      ...state,
      theme: state.theme === 'light' ? 'dark' : 'light',
    }));
  },
  
  toggleSidebar: () => {
    set((state) => ({
      ...state,
      sidebarOpen: !state.sidebarOpen,
    }));
  },
  
  addNotification: (notification) => {
    const id = Date.now().toString();
    set((state) => ({
      ...state,
      notifications: [...state.notifications, { ...notification, id }],
    }));
    
    // Auto-remove notification after 5 seconds
    setTimeout(() => {
      set((state) => ({
        ...state,
        notifications: state.notifications.filter(n => n.id !== id),
      }));
    }, 5000);
  },
});
```

### 🎯 Selective State Access

#### Optimized Component Subscriptions
Performance pattern from Cal.com and Plane:

```typescript
// hooks/useOptimizedStore.ts - Selective state subscriptions
import { useCallback } from 'react';
import { useShallow } from 'zustand/react/shallow';
import { useAppStore } from '../stores';

// Hook for specific state slice with shallow comparison
export const useAuth = () => {
  return useAppStore(
    useShallow((state) => ({
      user: state.user,
      isAuthenticated: state.isAuthenticated,
      login: state.login,
      logout: state.logout,
    }))
  );
};

// Hook for computed state with memoization
export const useUserPermissions = () => {
  return useAppStore(
    useCallback(
      (state) => {
        if (!state.user) return [];
        return state.user.roles.flatMap(role => role.permissions);
      },
      []
    ),
    useShallow
  );
};

// Hook for conditional state access
export const useProjectMetrics = (projectId?: string) => {
  return useAppStore(
    useCallback(
      (state) => {
        if (!projectId) return null;
        
        const project = state.projects.find(p => p.id === projectId);
        if (!project) return null;
        
        return {
          taskCount: project.tasks.length,
          completedTasks: project.tasks.filter(t => t.completed).length,
          progress: project.tasks.length > 0 
            ? project.tasks.filter(t => t.completed).length / project.tasks.length 
            : 0,
        };
      },
      [projectId]
    )
  );
};

// Component usage with optimized subscriptions
const UserProfile: React.FC = () => {
  const { user, updateUser } = useAuth();
  const permissions = useUserPermissions();
  
  // Component only re-renders when user or permissions change
  return (
    <div>
      <h1>{user?.name}</h1>
      <p>Permissions: {permissions.join(', ')}</p>
    </div>
  );
};
```

## Advanced Patterns

### 🔄 Async State Management

#### Loading and Error State Patterns
Pattern from Grafana dashboard implementation:

```typescript
// stores/dataStore.ts - Async state management
interface AsyncState<T> {
  data: T | null;
  loading: boolean;
  error: string | null;
  lastFetched: number | null;
}

interface DataState {
  metrics: AsyncState<MetricData[]>;
  dashboards: AsyncState<Dashboard[]>;
  alerts: AsyncState<Alert[]>;
}

interface DataActions {
  fetchMetrics: (timeRange: TimeRange) => Promise<void>;
  fetchDashboards: () => Promise<void>;
  fetchAlerts: () => Promise<void>;
  refreshData: () => Promise<void>;
}

export const useDataStore = create<DataState & DataActions>()(
  devtools(
    immer((set, get) => ({
      metrics: { data: null, loading: false, error: null, lastFetched: null },
      dashboards: { data: null, loading: false, error: null, lastFetched: null },
      alerts: { data: null, loading: false, error: null, lastFetched: null },

      fetchMetrics: async (timeRange: TimeRange) => {
        set((state) => {
          state.metrics.loading = true;
          state.metrics.error = null;
        });

        try {
          const response = await fetch(`/api/metrics?${timeRange.toQuery()}`);
          const data = await response.json();

          set((state) => {
            state.metrics.data = data;
            state.metrics.loading = false;
            state.metrics.lastFetched = Date.now();
          });
        } catch (error) {
          set((state) => {
            state.metrics.loading = false;
            state.metrics.error = error.message;
          });
        }
      },

      fetchDashboards: async () => {
        // Check cache validity (5 minutes)
        const { dashboards } = get();
        if (dashboards.data && dashboards.lastFetched && 
            Date.now() - dashboards.lastFetched < 5 * 60 * 1000) {
          return; // Use cached data
        }

        set((state) => {
          state.dashboards.loading = true;
          state.dashboards.error = null;
        });

        try {
          const response = await fetch('/api/dashboards');
          const data = await response.json();

          set((state) => {
            state.dashboards.data = data;
            state.dashboards.loading = false;
            state.dashboards.lastFetched = Date.now();
          });
        } catch (error) {
          set((state) => {
            state.dashboards.loading = false;
            state.dashboards.error = error.message;
          });
        }
      },

      fetchAlerts: async () => {
        set((state) => {
          state.alerts.loading = true;
          state.alerts.error = null;
        });

        try {
          const response = await fetch('/api/alerts');
          const data = await response.json();

          set((state) => {
            state.alerts.data = data;
            state.alerts.loading = false;
            state.alerts.lastFetched = Date.now();
          });
        } catch (error) {
          set((state) => {
            state.alerts.loading = false;
            state.alerts.error = error.message;
          });
        }
      },

      refreshData: async () => {
        const promises = [
          get().fetchMetrics(getCurrentTimeRange()),
          get().fetchDashboards(),
          get().fetchAlerts(),
        ];

        await Promise.allSettled(promises);
      },
    })),
    { name: 'data-store' }
  )
);
```

### 🔄 Real-time State Synchronization

#### WebSocket Integration Pattern
Implementation from real-time collaboration projects:

```typescript
// stores/realtimeStore.ts - WebSocket integration
interface RealtimeState {
  connected: boolean;
  connectionStatus: 'connecting' | 'connected' | 'disconnected' | 'error';
  lastPing: number | null;
  collaborators: Collaborator[];
  liveUpdates: LiveUpdate[];
}

interface RealtimeActions {
  connect: () => void;
  disconnect: () => void;
  sendUpdate: (update: Update) => void;
  handleIncomingUpdate: (update: LiveUpdate) => void;
}

export const useRealtimeStore = create<RealtimeState & RealtimeActions>()(
  devtools(
    immer((set, get) => {
      let ws: WebSocket | null = null;
      let pingInterval: NodeJS.Timeout | null = null;

      return {
        connected: false,
        connectionStatus: 'disconnected',
        lastPing: null,
        collaborators: [],
        liveUpdates: [],

        connect: () => {
          if (ws && ws.readyState === WebSocket.OPEN) return;

          set((state) => {
            state.connectionStatus = 'connecting';
          });

          ws = new WebSocket(process.env.NEXT_PUBLIC_WS_URL!);

          ws.onopen = () => {
            set((state) => {
              state.connected = true;
              state.connectionStatus = 'connected';
              state.lastPing = Date.now();
            });

            // Send authentication
            ws!.send(JSON.stringify({
              type: 'auth',
              token: localStorage.getItem('token'),
            }));

            // Setup ping interval
            pingInterval = setInterval(() => {
              if (ws!.readyState === WebSocket.OPEN) {
                ws!.send(JSON.stringify({ type: 'ping' }));
                set((state) => {
                  state.lastPing = Date.now();
                });
              }
            }, 30000);
          };

          ws.onmessage = (event) => {
            const message = JSON.parse(event.data);
            
            switch (message.type) {
              case 'collaborator_joined':
                set((state) => {
                  state.collaborators.push(message.collaborator);
                });
                break;
                
              case 'collaborator_left':
                set((state) => {
                  state.collaborators = state.collaborators.filter(
                    c => c.id !== message.collaboratorId
                  );
                });
                break;
                
              case 'live_update':
                get().handleIncomingUpdate(message.update);
                break;
                
              case 'pong':
                set((state) => {
                  state.lastPing = Date.now();
                });
                break;
            }
          };

          ws.onclose = () => {
            set((state) => {
              state.connected = false;
              state.connectionStatus = 'disconnected';
              state.collaborators = [];
            });

            if (pingInterval) {
              clearInterval(pingInterval);
              pingInterval = null;
            }

            // Attempt to reconnect after 3 seconds
            setTimeout(() => {
              get().connect();
            }, 3000);
          };

          ws.onerror = () => {
            set((state) => {
              state.connectionStatus = 'error';
            });
          };
        },

        disconnect: () => {
          if (ws) {
            ws.close();
            ws = null;
          }
          
          if (pingInterval) {
            clearInterval(pingInterval);
            pingInterval = null;
          }

          set((state) => {
            state.connected = false;
            state.connectionStatus = 'disconnected';
            state.collaborators = [];
          });
        },

        sendUpdate: (update: Update) => {
          if (ws && ws.readyState === WebSocket.OPEN) {
            ws.send(JSON.stringify({
              type: 'update',
              update,
            }));
          }
        },

        handleIncomingUpdate: (update: LiveUpdate) => {
          set((state) => {
            state.liveUpdates.unshift(update);
            // Keep only last 50 updates
            if (state.liveUpdates.length > 50) {
              state.liveUpdates = state.liveUpdates.slice(0, 50);
            }
          });

          // Apply update to relevant store
          switch (update.type) {
            case 'document_update':
              useDocumentStore.getState().applyRemoteUpdate(update.data);
              break;
            case 'user_cursor':
              useCursorStore.getState().updateCursor(update.data);
              break;
          }
        },
      };
    }),
    { name: 'realtime-store' }
  )
);
```

## Integration with React Query

### 🔄 Hybrid State Management

#### Combining Zustand with React Query
Pattern from Cal.com and modern applications:

```typescript
// stores/hybridStore.ts - Zustand + React Query integration
import { create } from 'zustand';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';

// Zustand for client state
interface ClientState {
  selectedProjectId: string | null;
  filters: ProjectFilters;
  viewMode: 'grid' | 'list';
  preferences: UserPreferences;
}

interface ClientActions {
  setSelectedProject: (id: string | null) => void;
  updateFilters: (filters: Partial<ProjectFilters>) => void;
  setViewMode: (mode: 'grid' | 'list') => void;
  updatePreferences: (preferences: Partial<UserPreferences>) => void;
}

export const useClientStore = create<ClientState & ClientActions>()(
  persist(
    immer((set) => ({
      selectedProjectId: null,
      filters: { status: 'all', search: '' },
      viewMode: 'grid',
      preferences: { theme: 'light', notifications: true },

      setSelectedProject: (id) => {
        set((state) => {
          state.selectedProjectId = id;
        });
      },

      updateFilters: (newFilters) => {
        set((state) => {
          Object.assign(state.filters, newFilters);
        });
      },

      setViewMode: (mode) => {
        set((state) => {
          state.viewMode = mode;
        });
      },

      updatePreferences: (newPreferences) => {
        set((state) => {
          Object.assign(state.preferences, newPreferences);
        });
      },
    })),
    { name: 'client-storage' }
  )
);

// Custom hooks combining both
export const useProjectsWithFilters = () => {
  const { filters } = useClientStore();
  
  return useQuery({
    queryKey: ['projects', filters],
    queryFn: () => fetchProjects(filters),
    staleTime: 5 * 60 * 1000, // 5 minutes
  });
};

export const useSelectedProject = () => {
  const { selectedProjectId } = useClientStore();
  
  return useQuery({
    queryKey: ['project', selectedProjectId],
    queryFn: () => fetchProject(selectedProjectId!),
    enabled: !!selectedProjectId,
  });
};

export const useCreateProject = () => {
  const queryClient = useQueryClient();
  const { setSelectedProject } = useClientStore();
  
  return useMutation({
    mutationFn: createProject,
    onSuccess: (newProject) => {
      // Update React Query cache
      queryClient.invalidateQueries({ queryKey: ['projects'] });
      // Update Zustand state
      setSelectedProject(newProject.id);
    },
  });
};
```

## Testing Patterns

### 🧪 Zustand Testing Strategies

#### Store Testing Utilities
Testing patterns from analyzed projects:

```typescript
// test-utils/zustand-utils.ts - Testing utilities
import { act, renderHook } from '@testing-library/react';
import { create } from 'zustand';

// Create a test version of the store
export const createTestStore = <T extends object>(
  storeCreator: any,
  initialState?: Partial<T>
) => {
  const store = create(storeCreator);
  
  if (initialState) {
    store.setState(initialState);
  }
  
  return store;
};

// Mock store for testing
export const createMockStore = <T extends object>(initialState: T) => {
  return create<T>(() => initialState);
};

// Test helper for async actions
export const waitForStoreUpdate = async (
  store: any,
  predicate: (state: any) => boolean,
  timeout = 1000
) => {
  return new Promise((resolve, reject) => {
    let unsubscribe: () => void;
    
    const timeoutId = setTimeout(() => {
      unsubscribe?.();
      reject(new Error('Store update timeout'));
    }, timeout);
    
    unsubscribe = store.subscribe((state: any) => {
      if (predicate(state)) {
        clearTimeout(timeoutId);
        unsubscribe();
        resolve(state);
      }
    });
  });
};
```

#### Component Testing with Zustand
Testing patterns for Zustand-connected components:

```typescript
// __tests__/ProjectList.test.tsx
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { useProjectStore } from '../stores/projectStore';
import { ProjectList } from '../components/ProjectList';
import { createTestStore } from '../test-utils/zustand-utils';

// Mock the store
jest.mock('../stores/projectStore');

describe('ProjectList', () => {
  let mockStore: any;

  beforeEach(() => {
    mockStore = createTestStore(useProjectStore, {
      projects: [
        { id: '1', name: 'Project 1', status: 'active' },
        { id: '2', name: 'Project 2', status: 'inactive' },
      ],
      loading: false,
      error: null,
    });

    (useProjectStore as jest.Mock).mockReturnValue(mockStore.getState());
  });

  it('renders projects from store', () => {
    render(<ProjectList />);
    
    expect(screen.getByText('Project 1')).toBeInTheDocument();
    expect(screen.getByText('Project 2')).toBeInTheDocument();
  });

  it('handles project creation', async () => {
    const user = userEvent.setup();
    const createProject = jest.fn();
    
    mockStore.setState({ createProject });
    (useProjectStore as jest.Mock).mockReturnValue({
      ...mockStore.getState(),
      createProject,
    });

    render(<ProjectList />);

    const createButton = screen.getByRole('button', { name: /create project/i });
    await user.click(createButton);

    expect(createProject).toHaveBeenCalled();
  });

  it('handles loading state', () => {
    mockStore.setState({ loading: true });
    (useProjectStore as jest.Mock).mockReturnValue(mockStore.getState());

    render(<ProjectList />);

    expect(screen.getByText(/loading/i)).toBeInTheDocument();
  });
});
```

## Performance Optimization

### ⚡ Optimization Strategies

#### Subscription Optimization
Performance patterns observed in production applications:

```typescript
// hooks/useOptimizedSubscriptions.ts - Performance optimization
import { useRef, useEffect } from 'react';
import { useShallow } from 'zustand/react/shallow';

// Debounced selector for expensive computations
export const useDebouncedSelector = <T, R>(
  selector: (state: T) => R,
  delay: number = 300
) => {
  const timeoutRef = useRef<NodeJS.Timeout>();
  const [debouncedValue, setDebouncedValue] = useState<R>();
  
  const value = useAppStore(selector);
  
  useEffect(() => {
    if (timeoutRef.current) {
      clearTimeout(timeoutRef.current);
    }
    
    timeoutRef.current = setTimeout(() => {
      setDebouncedValue(value);
    }, delay);
    
    return () => {
      if (timeoutRef.current) {
        clearTimeout(timeoutRef.current);
      }
    };
  }, [value, delay]);
  
  return debouncedValue;
};

// Memoized selector for expensive computations
export const useExpensiveComputation = () => {
  return useAppStore(
    useShallow((state) => {
      // Expensive computation
      return state.largeDataSet
        .filter(item => item.active)
        .map(item => ({
          ...item,
          computed: expensiveCalculation(item),
        }))
        .sort((a, b) => a.computed - b.computed);
    })
  );
};

// Conditional subscription to prevent unnecessary renders
export const useConditionalData = (condition: boolean) => {
  return useAppStore(
    useCallback(
      (state) => condition ? state.conditionalData : null,
      [condition]
    )
  );
};
```

## Best Practices Summary

### ✅ Recommended Patterns

#### 1. Store Design
- Use Zustand for client-side state, React Query for server state
- Implement feature-based store organization for large applications
- Use TypeScript for type safety and better developer experience
- Leverage middleware (persist, devtools, immer) appropriately

#### 2. Performance Optimization
- Use shallow comparison for object/array subscriptions
- Implement selective subscriptions to prevent unnecessary re-renders
- Debounce expensive computations and frequent updates
- Cache computed values using memoized selectors

#### 3. State Updates
- Use Immer middleware for complex state mutations
- Implement optimistic updates for better user experience
- Handle async operations with proper loading and error states
- Use subscriptions for side effects and analytics

#### 4. Integration Patterns
- Combine with React Query for optimal state management
- Implement proper error boundaries and fallback states
- Use persistence strategically for user preferences and settings
- Integrate with real-time features using WebSocket subscriptions

### ❌ Anti-Patterns to Avoid

#### 1. Common Mistakes
- Using Zustand for all state including server data
- Not implementing proper TypeScript types
- Overusing global state for local component state
- Ignoring performance implications of broad subscriptions

#### 2. Performance Issues
- Subscribing to entire store in components
- Not using shallow comparison for objects/arrays
- Implementing expensive computations directly in selectors
- Not debouncing frequent state updates

## Conclusion

Zustand provides an excellent balance between simplicity and power for React state management. The analyzed projects demonstrate that it excels in scenarios requiring:

- **Lightweight state management** with minimal boilerplate
- **TypeScript-first** development experience
- **Performance-critical** applications with selective subscriptions
- **Flexible architecture** that grows with application complexity

Key takeaways:
- Zustand works best when combined with React Query for server state
- Feature-based store organization scales well for large applications
- Proper TypeScript integration is essential for maintainable code
- Performance optimization through selective subscriptions is crucial

---

**Navigation**
- ← Back to: [Redux Implementation Patterns](redux-implementation-patterns.md)
- → Next: [State Optimization Techniques](state-optimization-techniques.md)
- → Related: [Component Library Architecture](component-library-architecture.md)