# Project Showcase: Production-Ready React & Next.js Applications

Detailed analysis of 15+ carefully selected open source React and Next.js projects, showcasing real-world implementation patterns, architecture decisions, and production-ready code quality.

## 🎯 Selection Criteria

Projects were selected based on:
- **Active Maintenance**: Regular commits and updates
- **Production Usage**: Real users and business applications
- **Code Quality**: Well-structured, documented, and tested
- **Learning Value**: Demonstrates best practices and patterns
- **Diversity**: Different domains and complexity levels

---

## 🛒 E-commerce & Marketplace

### 1. Medusa - Headless Commerce Platform
**GitHub**: `medusajs/medusa` | **Stars**: 20k+ | **Stack**: Next.js, React, Node.js

#### Key Learning Areas
- **Complex State Management**: Redux Toolkit for admin dashboard
- **API Integration**: Custom hooks for API calls with optimistic updates
- **Component Architecture**: Atomic design with clear separation of concerns
- **Performance**: Code splitting by admin sections

#### Notable Patterns
```typescript
// Custom hook for API integration
export const useAdminProducts = (query?: AdminGetProductsParams) => {
  const { data, ...rest } = useQuery(
    ['admin_products', query],
    () => client.admin.products.list(query),
    {
      staleTime: 30000,
      cacheTime: 60000,
    }
  )
  
  return { products: data?.products, ...rest }
}

// Optimistic updates pattern
const useUpdateProduct = () => {
  const queryClient = useQueryClient()
  
  return useMutation(updateProduct, {
    onMutate: async (variables) => {
      await queryClient.cancelQueries(['admin_products'])
      const previous = queryClient.getQueryData(['admin_products'])
      
      queryClient.setQueryData(['admin_products'], (old: any) => ({
        ...old,
        products: old.products.map((p: Product) =>
          p.id === variables.id ? { ...p, ...variables } : p
        ),
      }))
      
      return { previous }
    },
    onError: (err, variables, context) => {
      queryClient.setQueryData(['admin_products'], context?.previous)
    },
    onSettled: () => {
      queryClient.invalidateQueries(['admin_products'])
    },
  })
}
```

#### Architecture Highlights
- **Modular Admin**: Separate packages for different admin sections
- **Plugin System**: Extensible architecture with React components
- **State Normalization**: Efficient state structure for complex product data
- **Error Handling**: Comprehensive error boundaries and user feedback

### 2. Saleor Storefront - PWA E-commerce
**GitHub**: `saleor/storefront` | **Stars**: 2k+ | **Stack**: Next.js, Apollo GraphQL, TypeScript

#### Key Learning Areas
- **GraphQL Integration**: Apollo Client with sophisticated caching
- **PWA Implementation**: Service workers, offline support, push notifications
- **Performance Optimization**: Image optimization, lazy loading, code splitting
- **Internationalization**: Multi-language and multi-currency support

#### Notable Patterns
```typescript
// GraphQL with optimistic updates
const [updateUserMutation] = useUpdateUserMutation({
  optimisticResponse: (variables) => ({
    accountUpdate: {
      __typename: 'AccountUpdate',
      user: {
        ...currentUser,
        ...variables.input,
      },
      errors: [],
    },
  }),
  update: (cache, { data }) => {
    if (data?.accountUpdate?.user) {
      cache.writeFragment({
        id: cache.identify(data.accountUpdate.user),
        fragment: USER_FRAGMENT,
        data: data.accountUpdate.user,
      })
    }
  },
})

// Shopping cart context with persistence
export const CartProvider: React.FC = ({ children }) => {
  const [cart, setCart] = useLocalStorage<CartItem[]>('cart', [])
  
  const addToCart = useCallback((product: Product, quantity = 1) => {
    setCart(prevCart => {
      const existingItem = prevCart.find(item => item.id === product.id)
      if (existingItem) {
        return prevCart.map(item =>
          item.id === product.id
            ? { ...item, quantity: item.quantity + quantity }
            : item
        )
      }
      return [...prevCart, { ...product, quantity }]
    })
  }, [setCart])
  
  return (
    <CartContext.Provider value={{ cart, addToCart, removeFromCart }}>
      {children}
    </CartContext.Provider>
  )
}
```

---

## 🛠️ Developer Tools & Platforms

### 3. Supabase Dashboard
**GitHub**: `supabase/supabase` | **Stars**: 50k+ | **Stack**: Next.js, Zustand, Tailwind CSS

#### Key Learning Areas
- **Zustand for Complex State**: Multiple stores for different features
- **Real-time Data**: WebSocket integration with React Query
- **Code Editor Integration**: Monaco Editor with custom themes
- **Database Management UI**: Complex forms and data visualization

#### Notable Patterns
```typescript
// Zustand store with immer for immutable updates
export const useProjectStore = create<ProjectStore>()(
  immer((set, get) => ({
    projects: [],
    selectedProject: null,
    
    setProjects: (projects) => set((state) => {
      state.projects = projects
    }),
    
    selectProject: (projectId) => set((state) => {
      state.selectedProject = state.projects.find(p => p.id === projectId)
    }),
    
    updateProject: (projectId, updates) => set((state) => {
      const project = state.projects.find(p => p.id === projectId)
      if (project) {
        Object.assign(project, updates)
      }
    }),
  }))
)

// Real-time subscription pattern
export const useRealtimeSubscription = (tableName: string) => {
  const [data, setData] = useState([])
  
  useEffect(() => {
    const subscription = supabase
      .channel(`public:${tableName}`)
      .on('postgres_changes', {
        event: '*',
        schema: 'public',
        table: tableName,
      }, (payload) => {
        setData(prevData => {
          switch (payload.eventType) {
            case 'INSERT':
              return [...prevData, payload.new]
            case 'UPDATE':
              return prevData.map(item =>
                item.id === payload.old.id ? { ...item, ...payload.new } : item
              )
            case 'DELETE':
              return prevData.filter(item => item.id !== payload.old.id)
            default:
              return prevData
          }
        })
      })
      .subscribe()
    
    return () => {
      subscription.unsubscribe()
    }
  }, [tableName])
  
  return data
}
```

#### Architecture Highlights
- **Feature-Based Structure**: Each major feature in its own directory
- **Shared UI Components**: Comprehensive design system with Storybook
- **Performance**: Virtualization for large data sets
- **Authentication**: Row-level security with Supabase Auth

### 4. Vercel Dashboard Clone
**GitHub**: Multiple community implementations | **Stack**: Next.js 13+, Server Components

#### Key Learning Areas
- **App Router Patterns**: Server and Client Components optimization
- **Streaming SSR**: Progressive page loading
- **Edge Runtime**: API routes optimized for edge deployment
- **Deployment Integration**: Git-based deployment workflows

#### Notable Patterns
```typescript
// Server Component with data fetching
export default async function ProjectsPage({
  searchParams,
}: {
  searchParams: { [key: string]: string | string[] | undefined }
}) {
  const projects = await getProjects({
    search: searchParams.search as string,
    page: Number(searchParams.page) || 1,
  })
  
  return (
    <div className="space-y-6">
      <ProjectsHeader />
      <Suspense fallback={<ProjectsSkeleton />}>
        <ProjectsList projects={projects} />
      </Suspense>
    </div>
  )
}

// Client component for interactive features
'use client'
export function ProjectCard({ project }: { project: Project }) {
  const [isDeploying, setIsDeploying] = useState(false)
  
  const deployProject = async () => {
    setIsDeploying(true)
    try {
      await fetch('/api/deploy', {
        method: 'POST',
        body: JSON.stringify({ projectId: project.id }),
      })
      toast.success('Deployment started')
    } catch (error) {
      toast.error('Deployment failed')
    } finally {
      setIsDeploying(false)
    }
  }
  
  return (
    <Card>
      <CardHeader>
        <CardTitle>{project.name}</CardTitle>
      </CardHeader>
      <CardContent>
        <Button onClick={deployProject} disabled={isDeploying}>
          {isDeploying ? 'Deploying...' : 'Deploy'}
        </Button>
      </CardContent>
    </Card>
  )
}
```

---

## 📱 Social Media & Communication

### 5. Mastodon Web Interface
**GitHub**: `mastodon/mastodon` | **Stack**: React, Redux, Ruby on Rails API

#### Key Learning Areas
- **Real-time Feeds**: WebSocket integration for live updates
- **Infinite Scrolling**: Virtualized lists for performance
- **Media Handling**: Image/video upload and processing
- **Accessibility**: Comprehensive screen reader support

#### Notable Patterns
```typescript
// Infinite scroll with React Query
export const useInfiniteTimeline = (timelineType: string) => {
  return useInfiniteQuery({
    queryKey: ['timeline', timelineType],
    queryFn: ({ pageParam = null }) => fetchTimeline(timelineType, pageParam),
    getNextPageParam: (lastPage) => lastPage.nextCursor,
    staleTime: 30000,
  })
}

// Virtualized list component
export const VirtualizedTimeline: React.FC<{ posts: Post[] }> = ({ posts }) => {
  const parentRef = useRef<HTMLDivElement>(null)
  
  const rowVirtualizer = useVirtualizer({
    count: posts.length,
    getScrollElement: () => parentRef.current,
    estimateSize: () => 200,
  })
  
  return (
    <div ref={parentRef} className="h-screen overflow-auto">
      <div
        style={{
          height: `${rowVirtualizer.getTotalSize()}px`,
          width: '100%',
          position: 'relative',
        }}
      >
        {rowVirtualizer.getVirtualItems().map((virtualItem) => (
          <div
            key={virtualItem.index}
            style={{
              position: 'absolute',
              top: 0,
              left: 0,
              width: '100%',
              height: `${virtualItem.size}px`,
              transform: `translateY(${virtualItem.start}px)`,
            }}
          >
            <PostCard post={posts[virtualItem.index]} />
          </div>
        ))}
      </div>
    </div>
  )
}
```

### 6. Discord Clone (Community Projects)
**GitHub**: Various implementations | **Stack**: Next.js, Socket.io, Prisma

#### Key Learning Areas
- **Real-time Messaging**: Socket.io integration patterns
- **Voice/Video Chat**: WebRTC implementation
- **File Uploads**: Drag-and-drop with progress tracking
- **Role-Based Permissions**: Complex authorization logic

#### Notable Patterns
```typescript
// Real-time messaging hook
export const useSocket = (serverUrl: string) => {
  const [socket, setSocket] = useState<Socket | null>(null)
  
  useEffect(() => {
    const socketInstance = io(serverUrl, {
      transports: ['websocket'],
    })
    
    setSocket(socketInstance)
    
    return () => {
      socketInstance.close()
    }
  }, [serverUrl])
  
  return socket
}

// Message state management with Zustand
export const useMessageStore = create<MessageStore>((set, get) => ({
  messages: [],
  addMessage: (message) => set((state) => ({
    messages: [...state.messages, message],
  })),
  updateMessage: (messageId, updates) => set((state) => ({
    messages: state.messages.map(msg =>
      msg.id === messageId ? { ...msg, ...updates } : msg
    ),
  })),
  deleteMessage: (messageId) => set((state) => ({
    messages: state.messages.filter(msg => msg.id !== messageId),
  })),
}))

// File upload with progress
export const useFileUpload = () => {
  const [progress, setProgress] = useState<Record<string, number>>({})
  
  const uploadFile = async (file: File, onComplete: (url: string) => void) => {
    const formData = new FormData()
    formData.append('file', file)
    
    const xhr = new XMLHttpRequest()
    
    xhr.upload.addEventListener('progress', (event) => {
      if (event.lengthComputable) {
        const percentage = (event.loaded / event.total) * 100
        setProgress(prev => ({ ...prev, [file.name]: percentage }))
      }
    })
    
    xhr.addEventListener('load', () => {
      const response = JSON.parse(xhr.responseText)
      onComplete(response.url)
      setProgress(prev => {
        const { [file.name]: removed, ...rest } = prev
        return rest
      })
    })
    
    xhr.open('POST', '/api/upload')
    xhr.send(formData)
  }
  
  return { uploadFile, progress }
}
```

---

## 📝 Content Management & Blogging

### 7. Ghost Admin Interface
**GitHub**: `TryGhost/Ghost` | **Stack**: Ember.js (insights for React patterns)

#### Key Learning Areas (Adapted to React)
- **Rich Text Editing**: Complex editor state management
- **Draft System**: Auto-save and conflict resolution
- **Media Management**: Drag-and-drop image handling
- **Publishing Workflows**: Status management and scheduling

#### React Adaptation Patterns
```typescript
// Rich text editor state with Zustand
export const useEditorStore = create<EditorStore>((set, get) => ({
  content: '',
  isDirty: false,
  lastSaved: null,
  
  updateContent: (content) => set({
    content,
    isDirty: true,
  }),
  
  saveContent: async () => {
    const { content } = get()
    await api.saveDraft({ content })
    set({
      isDirty: false,
      lastSaved: new Date(),
    })
  },
  
  autoSave: debounce(() => {
    if (get().isDirty) {
      get().saveContent()
    }
  }, 2000),
}))

// Auto-save hook
export const useAutoSave = () => {
  const { content, autoSave } = useEditorStore()
  
  useEffect(() => {
    autoSave()
  }, [content, autoSave])
}
```

### 8. Strapi Admin Panel
**GitHub**: `strapi/strapi` | **Stack**: React, Redux, Styled Components

#### Key Learning Areas
- **Dynamic Forms**: Generated forms based on content types
- **Plugin Architecture**: Extensible React components
- **Permission Management**: Role-based UI rendering
- **API Documentation**: Interactive API explorer

#### Notable Patterns
```typescript
// Dynamic form generation
export const DynamicForm: React.FC<{ schema: FormSchema }> = ({ schema }) => {
  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm()
  
  const renderField = (field: FieldSchema) => {
    switch (field.type) {
      case 'text':
        return (
          <Input
            {...register(field.name, field.validation)}
            placeholder={field.placeholder}
          />
        )
      case 'richtext':
        return (
          <RichTextEditor
            {...register(field.name)}
            plugins={field.plugins}
          />
        )
      case 'relation':
        return (
          <RelationSelector
            {...register(field.name)}
            targetCollection={field.target}
          />
        )
      default:
        return null
    }
  }
  
  return (
    <form onSubmit={handleSubmit(onSubmit)}>
      {schema.fields.map((field) => (
        <div key={field.name} className="field-wrapper">
          <Label>{field.label}</Label>
          {renderField(field)}
          {errors[field.name] && (
            <ErrorMessage>{errors[field.name]?.message}</ErrorMessage>
          )}
        </div>
      ))}
      <Button type="submit">Save</Button>
    </form>
  )
}

// Permission-based rendering
export const ProtectedComponent: React.FC<{
  permission: string
  children: React.ReactNode
}> = ({ permission, children }) => {
  const { user } = useAuth()
  const hasPermission = user?.permissions?.includes(permission)
  
  if (!hasPermission) {
    return null
  }
  
  return <>{children}</>
}
```

---

## 💼 Business & Productivity Applications

### 9. Plane - Project Management
**GitHub**: `makeplane/plane` | **Stars**: 20k+ | **Stack**: Next.js, TypeScript, SWR

#### Key Learning Areas
- **Complex State Management**: Multiple interconnected data entities
- **Drag and Drop**: Kanban boards with React DnD
- **Real-time Collaboration**: WebSocket updates for team features
- **Keyboard Shortcuts**: Command palette and hotkey management

#### Notable Patterns
```typescript
// Complex state management with SWR
export const useIssues = (workspaceSlug: string, projectId: string) => {
  const { data: issues, mutate } = useSWR(
    workspaceSlug && projectId ? `PROJECT_ISSUES_${projectId}` : null,
    () => issuesService.getV3Issues(workspaceSlug, projectId),
    {
      revalidateOnFocus: false,
    }
  )
  
  const createIssue = async (issue: Partial<IIssue>) => {
    const newIssue = await issuesService.createIssue(
      workspaceSlug,
      projectId,
      issue
    )
    
    mutate((prevIssues) => [...(prevIssues || []), newIssue], false)
    return newIssue
  }
  
  const updateIssue = async (issueId: string, issue: Partial<IIssue>) => {
    mutate(
      (prevIssues) =>
        prevIssues?.map((i) =>
          i.id === issueId ? { ...i, ...issue } : i
        ) || [],
      false
    )
    
    await issuesService.patchIssue(workspaceSlug, projectId, issueId, issue)
    mutate()
  }
  
  return { issues, createIssue, updateIssue }
}

// Drag and drop with optimistic updates
export const KanbanBoard: React.FC = () => {
  const { issues, updateIssue } = useIssues(workspaceSlug, projectId)
  
  const onDragEnd = async (result: DropResult) => {
    if (!result.destination) return
    
    const { source, destination, draggableId } = result
    
    // Optimistic update
    const updatedIssue = {
      state: destination.droppableId,
      sort_order: destination.index,
    }
    
    await updateIssue(draggableId, updatedIssue)
  }
  
  return (
    <DragDropContext onDragEnd={onDragEnd}>
      {states.map((state) => (
        <Droppable key={state.id} droppableId={state.id}>
          {(provided) => (
            <div
              ref={provided.innerRef}
              {...provided.droppableProps}
              className="kanban-column"
            >
              {issues
                ?.filter((issue) => issue.state === state.id)
                .map((issue, index) => (
                  <Draggable
                    key={issue.id}
                    draggableId={issue.id}
                    index={index}
                  >
                    {(provided) => (
                      <IssueCard
                        ref={provided.innerRef}
                        {...provided.draggableProps}
                        {...provided.dragHandleProps}
                        issue={issue}
                      />
                    )}
                  </Draggable>
                ))}
              {provided.placeholder}
            </div>
          )}
        </Droppable>
      ))}
    </DragDropContext>
  )
}
```

### 10. Cal.com - Scheduling Platform
**GitHub**: `calcom/cal.com` | **Stars**: 25k+ | **Stack**: Next.js, Prisma, tRPC

#### Key Learning Areas
- **tRPC Integration**: Type-safe API calls
- **Calendar Integration**: Multiple calendar provider APIs
- **Time Zone Management**: Complex scheduling logic
- **Payment Integration**: Stripe with React hooks

#### Notable Patterns
```typescript
// tRPC with React Query
export const api = createTRPCNext<AppRouter>({
  config() {
    return {
      transformer: superjson,
      links: [
        httpBatchLink({
          url: `${getBaseUrl()}/api/trpc`,
        }),
      ],
    }
  },
  ssr: false,
})

// Calendar booking state
export const useBookingForm = () => {
  const [selectedDate, setSelectedDate] = useState<Date | null>(null)
  const [selectedTime, setSelectedTime] = useState<string | null>(null)
  
  const { data: availability } = api.availability.getAvailability.useQuery(
    {
      dateFrom: selectedDate?.toISOString(),
      dateTo: selectedDate?.toISOString(),
      eventTypeId: 1,
    },
    {
      enabled: !!selectedDate,
    }
  )
  
  const bookingMutation = api.bookings.create.useMutation({
    onSuccess: () => {
      toast.success('Booking confirmed!')
      router.push('/booking-confirmed')
    },
    onError: (error) => {
      toast.error(error.message)
    },
  })
  
  const createBooking = (data: BookingData) => {
    bookingMutation.mutate({
      ...data,
      start: new Date(`${selectedDate} ${selectedTime}`),
    })
  }
  
  return {
    selectedDate,
    setSelectedDate,
    selectedTime,
    setSelectedTime,
    availability,
    createBooking,
    isLoading: bookingMutation.isLoading,
  }
}
```

---

## 🎮 Interactive & Gaming

### 11. Chess.com Clone Projects
**GitHub**: Various community implementations | **Stack**: React, Socket.io, Canvas API

#### Key Learning Areas
- **Game State Management**: Complex turn-based logic
- **Real-time Multiplayer**: WebSocket game synchronization
- **Canvas Integration**: Board rendering and animations
- **AI Integration**: Chess engine integration

#### Notable Patterns
```typescript
// Game state with Zustand
export const useChessStore = create<ChessStore>((set, get) => ({
  board: initialBoard,
  currentPlayer: 'white',
  gameStatus: 'playing',
  moveHistory: [],
  
  makeMove: (from: Position, to: Position) => {
    const { board, currentPlayer } = get()
    
    if (!isValidMove(board, from, to, currentPlayer)) {
      return false
    }
    
    const newBoard = makeMove(board, from, to)
    const move = { from, to, player: currentPlayer, timestamp: Date.now() }
    
    set({
      board: newBoard,
      currentPlayer: currentPlayer === 'white' ? 'black' : 'white',
      moveHistory: [...get().moveHistory, move],
      gameStatus: checkGameStatus(newBoard),
    })
    
    return true
  },
  
  undoMove: () => {
    const { moveHistory } = get()
    if (moveHistory.length === 0) return
    
    const newHistory = moveHistory.slice(0, -1)
    const newBoard = reconstructBoard(newHistory)
    
    set({
      board: newBoard,
      moveHistory: newHistory,
      currentPlayer: moveHistory.length % 2 === 0 ? 'black' : 'white',
    })
  },
}))

// Real-time game synchronization
export const useGameSync = (gameId: string) => {
  const socket = useSocket()
  const { makeMove, board } = useChessStore()
  
  useEffect(() => {
    if (!socket) return
    
    socket.on('move', ({ from, to, player }) => {
      makeMove(from, to)
    })
    
    socket.on('game-state', (gameState) => {
      useChessStore.setState(gameState)
    })
    
    return () => {
      socket.off('move')
      socket.off('game-state')
    }
  }, [socket, makeMove])
  
  const sendMove = (from: Position, to: Position) => {
    if (makeMove(from, to)) {
      socket?.emit('move', { gameId, from, to })
    }
  }
  
  return { sendMove, board }
}
```

---

## 📊 Analytics & Data Visualization

### 12. PostHog Dashboard Clone
**GitHub**: Community implementations inspired by PostHog | **Stack**: React, D3.js, Next.js

#### Key Learning Areas
- **Data Visualization**: Complex charts with D3 and React
- **Real-time Dashboards**: Live data updates
- **Performance**: Large dataset handling
- **Filtering Systems**: Complex query builders

#### Notable Patterns
```typescript
// Chart component with D3 integration
export const TimeSeriesChart: React.FC<{
  data: DataPoint[]
  width: number
  height: number
}> = ({ data, width, height }) => {
  const svgRef = useRef<SVGSVGElement>(null)
  
  useEffect(() => {
    if (!svgRef.current || !data.length) return
    
    const svg = d3.select(svgRef.current)
    svg.selectAll('*').remove()
    
    const margin = { top: 20, right: 30, bottom: 40, left: 40 }
    const innerWidth = width - margin.left - margin.right
    const innerHeight = height - margin.top - margin.bottom
    
    const xScale = d3
      .scaleTime()
      .domain(d3.extent(data, (d) => new Date(d.timestamp)) as [Date, Date])
      .range([0, innerWidth])
    
    const yScale = d3
      .scaleLinear()
      .domain([0, d3.max(data, (d) => d.value) || 0])
      .range([innerHeight, 0])
    
    const line = d3
      .line<DataPoint>()
      .x((d) => xScale(new Date(d.timestamp)))
      .y((d) => yScale(d.value))
      .curve(d3.curveMonotoneX)
    
    const g = svg
      .append('g')
      .attr('transform', `translate(${margin.left},${margin.top})`)
    
    g.append('path')
      .datum(data)
      .attr('fill', 'none')
      .attr('stroke', '#3b82f6')
      .attr('stroke-width', 2)
      .attr('d', line)
    
    g.append('g')
      .attr('transform', `translate(0,${innerHeight})`)
      .call(d3.axisBottom(xScale))
    
    g.append('g').call(d3.axisLeft(yScale))
  }, [data, width, height])
  
  return <svg ref={svgRef} width={width} height={height} />
}

// Dashboard with real-time updates
export const AnalyticsDashboard: React.FC = () => {
  const [timeRange, setTimeRange] = useState('7d')
  const [filters, setFilters] = useState<Record<string, any>>({})
  
  const { data: metrics, isLoading } = useQuery({
    queryKey: ['analytics', timeRange, filters],
    queryFn: () => fetchAnalytics({ timeRange, filters }),
    refetchInterval: 30000, // Refetch every 30 seconds
  })
  
  const { data: liveData } = useSubscription(['live-analytics'], {
    onData: (newData) => {
      // Update charts with new data
      queryClient.setQueryData(['analytics'], (oldData: any) => ({
        ...oldData,
        realtime: newData,
      }))
    },
  })
  
  return (
    <div className="dashboard-grid">
      <MetricCard
        title="Page Views"
        value={metrics?.pageViews}
        trend={metrics?.pageViewsTrend}
      />
      <TimeSeriesChart
        data={metrics?.pageViewsOverTime || []}
        width={800}
        height={400}
      />
      <FilterPanel filters={filters} onChange={setFilters} />
    </div>
  )
}
```

---

## 🎓 Educational & Learning Platforms

### 13. Coursera/Udemy Clone Projects
**GitHub**: Various educational platform implementations | **Stack**: Next.js, Video.js, Stripe

#### Key Learning Areas
- **Video Player Integration**: Custom video controls and progress tracking
- **Progress Tracking**: Course completion and learning analytics
- **Payment Processing**: Subscription and one-time payment handling
- **Content Delivery**: Video streaming optimization

#### Notable Patterns
```typescript
// Video player with progress tracking
export const VideoPlayer: React.FC<{
  videoUrl: string
  courseId: string
  lessonId: string
}> = ({ videoUrl, courseId, lessonId }) => {
  const playerRef = useRef<VideoJsPlayer | null>(null)
  const [progress, setProgress] = useState(0)
  
  const { mutate: updateProgress } = useMutation({
    mutationFn: ({ courseId, lessonId, progress }: any) =>
      api.updateProgress(courseId, lessonId, progress),
  })
  
  useEffect(() => {
    if (!playerRef.current) {
      const player = videojs('video-player', {
        controls: true,
        responsive: true,
        playbackRates: [0.5, 1, 1.25, 1.5, 2],
      })
      
      player.on('timeupdate', () => {
        const currentTime = player.currentTime()
        const duration = player.duration()
        const newProgress = (currentTime / duration) * 100
        
        setProgress(newProgress)
        
        // Auto-save progress every 10%
        if (newProgress > 0 && newProgress % 10 < 1) {
          updateProgress({ courseId, lessonId, progress: newProgress })
        }
      })
      
      playerRef.current = player
    }
    
    return () => {
      if (playerRef.current) {
        playerRef.current.dispose()
      }
    }
  }, [])
  
  return (
    <div className="video-container">
      <video
        id="video-player"
        className="video-js vjs-default-skin"
        data-setup="{}"
      >
        <source src={videoUrl} type="video/mp4" />
      </video>
      <ProgressBar progress={progress} />
    </div>
  )
}

// Course progress context
export const CourseProgressProvider: React.FC<{
  courseId: string
  children: React.ReactNode
}> = ({ courseId, children }) => {
  const [progress, setProgress] = useState<Record<string, number>>({})
  const [completedLessons, setCompletedLessons] = useState<string[]>([])
  
  const markLessonComplete = (lessonId: string) => {
    setCompletedLessons(prev => [...prev, lessonId])
    setProgress(prev => ({ ...prev, [lessonId]: 100 }))
  }
  
  const updateLessonProgress = (lessonId: string, progress: number) => {
    setProgress(prev => ({ ...prev, [lessonId]: progress }))
    
    if (progress >= 95) {
      markLessonComplete(lessonId)
    }
  }
  
  return (
    <CourseProgressContext.Provider
      value={{
        progress,
        completedLessons,
        markLessonComplete,
        updateLessonProgress,
      }}
    >
      {children}
    </CourseProgressContext.Provider>
  )
}
```

---

## 🔍 Key Patterns Summary

### Common Architecture Patterns
1. **Feature-Based Structure**: 80% organize by features, not technical layers
2. **Compound Components**: Complex UI components with sub-components
3. **Custom Hooks**: Business logic extraction into reusable hooks
4. **Context + Hooks**: Theme, auth, and global state management
5. **Error Boundaries**: Strategic placement for UX resilience

### State Management Evolution
- **Simple Apps**: Context API + useReducer
- **Medium Apps**: Zustand + React Query
- **Complex Apps**: Redux Toolkit + RTK Query
- **Real-time Apps**: Zustand/Redux + WebSocket integration

### Performance Optimization
- **Code Splitting**: Route-based and component-based splitting
- **Image Optimization**: Next.js Image component adoption
- **Memoization**: Strategic React.memo, useMemo, useCallback usage
- **Virtual Lists**: @tanstack/react-virtual for large datasets
- **Streaming**: React 18 Suspense and Next.js streaming

### Authentication Patterns
- **NextAuth.js**: Most popular for Next.js applications
- **Supabase Auth**: Growing adoption in modern projects
- **Custom JWT**: Enterprise applications with specific requirements
- **OAuth Integration**: GitHub, Google, Discord providers

---

## 📈 Project Quality Metrics

| Project | GitHub Stars | Code Quality | Test Coverage | Performance | Learning Value |
|---------|--------------|--------------|---------------|-------------|----------------|
| Medusa | ⭐⭐⭐⭐⭐ | A+ | 85% | A | Excellent |
| Supabase | ⭐⭐⭐⭐⭐ | A+ | 75% | A+ | Excellent |
| Plane | ⭐⭐⭐⭐⭐ | A | 60% | A | Very Good |
| Cal.com | ⭐⭐⭐⭐⭐ | A+ | 70% | A | Excellent |
| Saleor | ⭐⭐⭐⭐ | A | 80% | A | Very Good |

*These projects represent the current state of the art in React/Next.js development as of January 2025.*