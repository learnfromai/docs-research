# Performance Optimization in React & Next.js Applications

## 🎯 Overview

Comprehensive analysis of performance optimization techniques, strategies, and tools used in production React and Next.js applications to achieve optimal loading times and user experience.

## 📊 Performance Landscape

### **Key Metrics Focus**
- **Core Web Vitals**: LCP, FID, CLS compliance
- **Time to Interactive (TTI)**: <3 seconds target
- **Bundle Size**: <1MB initial load target
- **Performance Budget**: Lighthouse score >90

## 🚀 Next.js Performance Features

### **Built-in Optimizations**

```typescript
// next.config.js - Production optimization
/** @type {import('next').NextConfig} */
const nextConfig = {
  // Compiler optimizations
  swcMinify: true,
  compiler: {
    removeConsole: process.env.NODE_ENV === 'production',
  },
  
  // Image optimization
  images: {
    domains: ['example.com', 'cdn.example.com'],
    formats: ['image/webp', 'image/avif'],
    dangerouslyAllowSVG: true,
    contentSecurityPolicy: "default-src 'self'; script-src 'none'; sandbox;",
  },
  
  // Bundle optimization
  experimental: {
    optimizeCss: true,
    gzipSize: true,
    serverComponentsExternalPackages: ['@prisma/client'],
  },
  
  // Headers for caching
  async headers() {
    return [
      {
        source: '/_next/static/:path*',
        headers: [
          {
            key: 'Cache-Control',
            value: 'public, max-age=31536000, immutable',
          },
        ],
      },
      {
        source: '/api/:path*',
        headers: [
          {
            key: 'Cache-Control',
            value: 'public, max-age=300, s-maxage=300',
          },
        ],
      },
    ];
  },
  
  // Rewrites for optimization
  async rewrites() {
    return [
      {
        source: '/js/:path*',
        destination: '/_next/static/chunks/:path*',
      },
    ];
  },
};

module.exports = nextConfig;
```

### **Image Optimization Patterns**

```typescript
// components/OptimizedImage.tsx
import Image from 'next/image';
import { useState } from 'react';
import { cn } from '@/lib/utils';

interface OptimizedImageProps {
  src: string;
  alt: string;
  width?: number;
  height?: number;
  className?: string;
  priority?: boolean;
  placeholder?: 'blur' | 'empty';
  blurDataURL?: string;
}

export function OptimizedImage({
  src,
  alt,
  width,
  height,
  className,
  priority = false,
  placeholder = 'blur',
  blurDataURL,
}: OptimizedImageProps) {
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState(false);

  return (
    <div className={cn('overflow-hidden', className)}>
      {!error ? (
        <Image
          src={src}
          alt={alt}
          width={width}
          height={height}
          priority={priority}
          placeholder={placeholder}
          blurDataURL={blurDataURL || 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAYEBQYFBAYGBQYHBwYIChAKCgkJChQODwwQFxQYGBcUFhYaHSUfGhsjHBYWICwgIyYnKSopGR8tMC0oMCUoKSj/2wBDAQcHBwoIChMKChMoGhYaKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCj/wAARCAAIAAoDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAv/xAAhEAACAQMDBQAAAAAAAAAAAAABAgMABAUGIWGRkqGx0f/EABUBAQEAAAAAAAAAAAAAAAAAAAMF/8QAGhEAAgIDAAAAAAAAAAAAAAAAAAECEgMRkf/aAAwDAQACEQMRAD8AltJagyeH0AthI5xdrLcNM91BF5pX2HaH9bcfaSXWGaRmknyJckliyjqTzSlT54b6bk+h0R//2Q=='}
          className={cn(
            'duration-700 ease-in-out group-hover:opacity-75',
            isLoading
              ? 'scale-110 blur-2xl grayscale'
              : 'scale-100 blur-0 grayscale-0'
          )}
          onLoad={() => setIsLoading(false)}
          onError={() => setError(true)}
        />
      ) : (
        <div className="flex items-center justify-center bg-gray-300 rounded">
          <span className="text-gray-500">Failed to load</span>
        </div>
      )}
    </div>
  );
}

// utils/image-blur.ts - Generate blur placeholders
import { getPlaiceholder } from 'plaiceholder';

export async function getBase64(src: string): Promise<string> {
  try {
    const res = await fetch(src);
    
    if (!res.ok) {
      throw new Error(`Failed to fetch image: ${res.status} ${res.statusText}`);
    }
    
    const buffer = await res.arrayBuffer();
    const { base64 } = await getPlaiceholder(Buffer.from(buffer));
    
    return base64;
  } catch (error) {
    console.error('Error generating blur placeholder:', error);
    return 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAYEBQYFBAYGBQYHBwYIChAKCgkJChQODwwQFxQYGBcUFhYaHSUfGhsjHBYWICwgIyYnKSopGR8tMC0oMCUoKSj/2wBDAQcHBwoIChMKChMoGhYaKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCj/wAARCAAIAAoDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAv/xAAhEAACAQMDBQAAAAAAAAAAAAABAgMABAUGIWGRkqGx0f/EABUBAQEAAAAAAAAAAAAAAAAAAAMF/8QAGhEAAgIDAAAAAAAAAAAAAAAAAAECEgMRkf/aAAwDAQACEQMRAD8AltJagyeH0AthI5xdrLcNM91BF5pX2HaH9bcfaSXWGaRmknyJckliyjqTzSlT54b6bk+h0R//2Q==';
  }
}
```

## 🎭 Code Splitting & Lazy Loading

### **Dynamic Imports Pattern**

```typescript
// components/DynamicComponents.tsx
import dynamic from 'next/dynamic';
import { Suspense } from 'react';

// Lazy load heavy components
const ChartComponent = dynamic(() => import('./Chart'), {
  loading: () => <ChartSkeleton />,
  ssr: false, // Disable SSR for client-only components
});

const DataTable = dynamic(() => import('./DataTable'), {
  loading: () => <TableSkeleton />,
});

const RichTextEditor = dynamic(() => import('./RichTextEditor'), {
  loading: () => <EditorSkeleton />,
  ssr: false,
});

// Feature-based code splitting
const AdminPanel = dynamic(() => import('@/features/admin/AdminPanel'), {
  loading: () => <div>Loading admin panel...</div>,
});

// Conditional loading based on user role
export function ConditionalComponents({ user }: { user: User }) {
  return (
    <div>
      {user.role === 'admin' && (
        <Suspense fallback={<AdminSkeleton />}>
          <AdminPanel />
        </Suspense>
      )}
      
      {user.isPremium && (
        <Suspense fallback={<PremiumSkeleton />}>
          <PremiumFeatures />
        </Suspense>
      )}
    </div>
  );
}

// Modal lazy loading
const Modal = dynamic(() => import('@/components/ui/modal'), {
  ssr: false,
});

export function LazyModal({ isOpen, onClose, children }: ModalProps) {
  if (!isOpen) return null;
  
  return (
    <Modal onClose={onClose}>
      {children}
    </Modal>
  );
}
```

### **Route-Based Code Splitting**

```typescript
// app/dashboard/loading.tsx
export default function DashboardLoading() {
  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <Skeleton className="h-8 w-48" />
        <Skeleton className="h-10 w-32" />
      </div>
      
      <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-4">
        {Array.from({ length: 4 }).map((_, i) => (
          <Card key={i}>
            <CardHeader>
              <Skeleton className="h-4 w-24" />
            </CardHeader>
            <CardContent>
              <Skeleton className="h-8 w-16" />
            </CardContent>
          </Card>
        ))}
      </div>
      
      <div className="grid gap-6 md:grid-cols-2">
        <Card>
          <CardHeader>
            <Skeleton className="h-6 w-32" />
          </CardHeader>
          <CardContent>
            <Skeleton className="h-64 w-full" />
          </CardContent>
        </Card>
        
        <Card>
          <CardHeader>
            <Skeleton className="h-6 w-32" />
          </CardHeader>
          <CardContent>
            <div className="space-y-3">
              {Array.from({ length: 5 }).map((_, i) => (
                <div key={i} className="flex items-center space-x-3">
                  <Skeleton className="h-10 w-10 rounded-full" />
                  <div className="space-y-2">
                    <Skeleton className="h-4 w-32" />
                    <Skeleton className="h-3 w-24" />
                  </div>
                </div>
              ))}
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}

// components/skeletons/Skeleton.tsx
import { cn } from '@/lib/utils';

interface SkeletonProps extends React.HTMLAttributes<HTMLDivElement> {}

export function Skeleton({ className, ...props }: SkeletonProps) {
  return (
    <div
      className={cn(
        'animate-pulse rounded-md bg-muted',
        className
      )}
      {...props}
    />
  );
}
```

## ⚡ React Performance Optimizations

### **Memoization Strategies**

```typescript
// hooks/use-memoization.ts
import { useMemo, useCallback, useRef } from 'react';

// Expensive calculations
export function useExpensiveCalculation(data: any[], filterCriteria: FilterCriteria) {
  return useMemo(() => {
    console.log('Performing expensive calculation...');
    
    return data
      .filter(item => {
        if (filterCriteria.status && item.status !== filterCriteria.status) {
          return false;
        }
        if (filterCriteria.category && item.category !== filterCriteria.category) {
          return false;
        }
        if (filterCriteria.search) {
          const searchLower = filterCriteria.search.toLowerCase();
          return item.name.toLowerCase().includes(searchLower) ||
                 item.description.toLowerCase().includes(searchLower);
        }
        return true;
      })
      .sort((a, b) => {
        switch (filterCriteria.sortBy) {
          case 'name':
            return a.name.localeCompare(b.name);
          case 'date':
            return new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime();
          case 'priority':
            const priorityOrder = { high: 3, medium: 2, low: 1 };
            return priorityOrder[b.priority] - priorityOrder[a.priority];
          default:
            return 0;
        }
      });
  }, [data, filterCriteria]);
}

// Stable references for callbacks
export function useStableCallbacks() {
  const callbackCache = useRef<Map<string, Function>>(new Map());
  
  const createStableCallback = useCallback(<T extends Function>(
    key: string,
    callback: T,
    deps: any[]
  ): T => {
    const depsKey = `${key}-${JSON.stringify(deps)}`;
    
    if (!callbackCache.current.has(depsKey)) {
      callbackCache.current.set(depsKey, callback);
    }
    
    return callbackCache.current.get(depsKey) as T;
  }, []);
  
  return createStableCallback;
}

// components/OptimizedList.tsx
interface ListItem {
  id: string;
  name: string;
  description: string;
  status: string;
  priority: 'low' | 'medium' | 'high';
  createdAt: string;
}

interface OptimizedListProps {
  items: ListItem[];
  onItemClick: (item: ListItem) => void;
  onItemEdit: (id: string) => void;
  onItemDelete: (id: string) => void;
}

const ListItemComponent = React.memo<{
  item: ListItem;
  onItemClick: (item: ListItem) => void;
  onItemEdit: (id: string) => void;
  onItemDelete: (id: string) => void;
}>(({ item, onItemClick, onItemEdit, onItemDelete }) => {
  const handleClick = useCallback(() => {
    onItemClick(item);
  }, [item, onItemClick]);
  
  const handleEdit = useCallback(() => {
    onItemEdit(item.id);
  }, [item.id, onItemEdit]);
  
  const handleDelete = useCallback(() => {
    onItemDelete(item.id);
  }, [item.id, onItemDelete]);
  
  return (
    <Card className="cursor-pointer hover:bg-accent" onClick={handleClick}>
      <CardContent className="p-4">
        <div className="flex items-center justify-between">
          <div>
            <h3 className="font-semibold">{item.name}</h3>
            <p className="text-sm text-muted-foreground">{item.description}</p>
            <div className="flex items-center gap-2 mt-2">
              <Badge variant="outline">{item.status}</Badge>
              <Badge variant={item.priority === 'high' ? 'destructive' : 'secondary'}>
                {item.priority}
              </Badge>
            </div>
          </div>
          <div className="flex gap-2">
            <Button size="sm" variant="ghost" onClick={handleEdit}>
              Edit
            </Button>
            <Button size="sm" variant="ghost" onClick={handleDelete}>
              Delete
            </Button>
          </div>
        </div>
      </CardContent>
    </Card>
  );
});

export function OptimizedList({ items, onItemClick, onItemEdit, onItemDelete }: OptimizedListProps) {
  // Memoize callbacks to prevent unnecessary re-renders
  const stableOnItemClick = useCallback(onItemClick, []);
  const stableOnItemEdit = useCallback(onItemEdit, []);
  const stableOnItemDelete = useCallback(onItemDelete, []);
  
  return (
    <div className="space-y-4">
      {items.map((item) => (
        <ListItemComponent
          key={item.id}
          item={item}
          onItemClick={stableOnItemClick}
          onItemEdit={stableOnItemEdit}
          onItemDelete={stableOnItemDelete}
        />
      ))}
    </div>
  );
}
```

### **Virtual Scrolling Implementation**

```typescript
// components/VirtualList.tsx
import { FixedSizeList as List } from 'react-window';
import { useMemo } from 'react';

interface VirtualListProps<T> {
  items: T[];
  height: number;
  itemHeight: number;
  renderItem: (item: T, index: number) => React.ReactNode;
  className?: string;
}

export function VirtualList<T>({
  items,
  height,
  itemHeight,
  renderItem,
  className,
}: VirtualListProps<T>) {
  const ItemRenderer = useMemo(() => {
    return ({ index, style }: { index: number; style: React.CSSProperties }) => (
      <div style={style}>
        {renderItem(items[index], index)}
      </div>
    );
  }, [items, renderItem]);
  
  return (
    <List
      className={className}
      height={height}
      itemCount={items.length}
      itemSize={itemHeight}
      overscanCount={5} // Render 5 extra items outside viewport
    >
      {ItemRenderer}
    </List>
  );
}

// Usage example
export function LargeDataList({ data }: { data: Project[] }) {
  const renderProject = useCallback((project: Project, index: number) => (
    <ProjectCard key={project.id} project={project} />
  ), []);
  
  return (
    <VirtualList
      items={data}
      height={600}
      itemHeight={120}
      renderItem={renderProject}
      className="border rounded-md"
    />
  );
}
```

## 🔄 State Management Performance

### **Selective Subscriptions with Zustand**

```typescript
// stores/optimized-store.ts
import { create } from 'zustand';
import { subscribeWithSelector } from 'zustand/middleware';

interface AppState {
  // UI state
  sidebar: {
    isOpen: boolean;
    activeTab: string;
  };
  
  // Data state
  projects: Project[];
  tasks: Task[];
  users: User[];
  
  // Loading states
  loading: {
    projects: boolean;
    tasks: boolean;
    users: boolean;
  };
  
  // Actions
  toggleSidebar: () => void;
  setActiveTab: (tab: string) => void;
  setProjects: (projects: Project[]) => void;
  setTasks: (tasks: Task[]) => void;
  setLoading: (key: keyof AppState['loading'], value: boolean) => void;
}

export const useAppStore = create<AppState>()(
  subscribeWithSelector((set) => ({
    sidebar: {
      isOpen: false,
      activeTab: 'projects',
    },
    projects: [],
    tasks: [],
    users: [],
    loading: {
      projects: false,
      tasks: false,
      users: false,
    },
    
    toggleSidebar: () =>
      set((state) => ({
        sidebar: { ...state.sidebar, isOpen: !state.sidebar.isOpen },
      })),
      
    setActiveTab: (tab: string) =>
      set((state) => ({
        sidebar: { ...state.sidebar, activeTab: tab },
      })),
      
    setProjects: (projects: Project[]) => set({ projects }),
    setTasks: (tasks: Task[]) => set({ tasks }),
    
    setLoading: (key, value) =>
      set((state) => ({
        loading: { ...state.loading, [key]: value },
      })),
  }))
);

// Optimized selectors
export const useSidebar = () =>
  useAppStore((state) => state.sidebar);

export const useProjects = () =>
  useAppStore((state) => state.projects);

export const useProjectsLoading = () =>
  useAppStore((state) => state.loading.projects);

// Subscribe to specific changes
export function useProjectsEffect() {
  useEffect(() => {
    const unsubscribe = useAppStore.subscribe(
      (state) => state.projects,
      (projects) => {
        console.log('Projects changed:', projects);
        // Perform side effects
      }
    );
    
    return unsubscribe;
  }, []);
}
```

## 📦 Bundle Size Optimization

### **Tree Shaking and Import Analysis**

```typescript
// utils/bundle-analysis.ts
// ✅ Good: Import only what you need
import { format, formatDistance } from 'date-fns';
import { debounce } from 'lodash-es';

// ❌ Bad: Imports entire library
// import * as dateFns from 'date-fns';
// import _ from 'lodash';

// Bundle analyzer webpack plugin config
const withBundleAnalyzer = require('@next/bundle-analyzer')({
  enabled: process.env.ANALYZE === 'true',
});

// next.config.js
module.exports = withBundleAnalyzer({
  webpack: (config, { isServer }) => {
    // Ignore specific modules on client side
    if (!isServer) {
      config.resolve.fallback = {
        ...config.resolve.fallback,
        fs: false,
        net: false,
        tls: false,
      };
    }
    
    // Optimize imports
    config.optimization.usedExports = true;
    config.optimization.sideEffects = false;
    
    return config;
  },
});

// lib/optimized-imports.ts
// Create barrel exports for better tree shaking
export { Button } from './button';
export { Input } from './input';
export { Card, CardContent, CardHeader, CardTitle } from './card';
export { Badge } from './badge';

// Instead of importing everything:
// export * from './components';
```

### **Code Splitting Strategies**

```typescript
// lib/feature-flags.ts
export const FEATURE_FLAGS = {
  ADVANCED_ANALYTICS: process.env.NEXT_PUBLIC_FEATURE_ANALYTICS === 'true',
  BETA_FEATURES: process.env.NEXT_PUBLIC_FEATURE_BETA === 'true',
  AI_ASSISTANCE: process.env.NEXT_PUBLIC_FEATURE_AI === 'true',
} as const;

// components/FeatureGated.tsx
interface FeatureGatedProps {
  feature: keyof typeof FEATURE_FLAGS;
  children: React.ReactNode;
  fallback?: React.ReactNode;
}

export function FeatureGated({ feature, children, fallback }: FeatureGatedProps) {
  if (!FEATURE_FLAGS[feature]) {
    return fallback || null;
  }
  
  return <>{children}</>;
}

// app/dashboard/page.tsx
const AdvancedAnalytics = dynamic(
  () => import('@/components/AdvancedAnalytics'),
  { ssr: false }
);

const AIAssistant = dynamic(
  () => import('@/components/AIAssistant'),
  { ssr: false }
);

export default function Dashboard() {
  return (
    <div>
      <h1>Dashboard</h1>
      
      <FeatureGated feature="ADVANCED_ANALYTICS">
        <AdvancedAnalytics />
      </FeatureGated>
      
      <FeatureGated feature="AI_ASSISTANCE">
        <AIAssistant />
      </FeatureGated>
    </div>
  );
}
```

## 🌐 Network Performance

### **Request Optimization**

```typescript
// lib/request-optimization.ts
// Request batching
class RequestBatcher {
  private batches = new Map<string, any[]>();
  private timeouts = new Map<string, NodeJS.Timeout>();
  
  batch<T>(
    key: string,
    request: T,
    batchFn: (requests: T[]) => Promise<any[]>,
    delay = 50
  ): Promise<any> {
    return new Promise((resolve, reject) => {
      // Add request to batch
      if (!this.batches.has(key)) {
        this.batches.set(key, []);
      }
      
      const batch = this.batches.get(key)!;
      batch.push({ request, resolve, reject });
      
      // Clear existing timeout
      if (this.timeouts.has(key)) {
        clearTimeout(this.timeouts.get(key)!);
      }
      
      // Set new timeout
      const timeout = setTimeout(async () => {
        const currentBatch = this.batches.get(key) || [];
        this.batches.delete(key);
        this.timeouts.delete(key);
        
        if (currentBatch.length === 0) return;
        
        try {
          const requests = currentBatch.map(item => item.request);
          const results = await batchFn(requests);
          
          currentBatch.forEach((item, index) => {
            item.resolve(results[index]);
          });
        } catch (error) {
          currentBatch.forEach(item => {
            item.reject(error);
          });
        }
      }, delay);
      
      this.timeouts.set(key, timeout);
    });
  }
}

export const requestBatcher = new RequestBatcher();

// Usage example
export async function getUserById(id: string): Promise<User> {
  return requestBatcher.batch(
    'users',
    id,
    async (userIds: string[]) => {
      const { data } = await apiClient.post('/users/batch', { ids: userIds });
      return data;
    }
  );
}
```

### **Caching Strategies**

```typescript
// lib/cache-manager.ts
interface CacheOptions {
  ttl?: number; // Time to live in milliseconds
  maxSize?: number; // Maximum cache size
}

class CacheManager {
  private cache = new Map<string, { value: any; timestamp: number; ttl: number }>();
  private maxSize: number;
  
  constructor(options: CacheOptions = {}) {
    this.maxSize = options.maxSize || 1000;
  }
  
  set(key: string, value: any, ttl = 5 * 60 * 1000): void {
    // Remove oldest entries if cache is full
    if (this.cache.size >= this.maxSize) {
      const oldestKey = this.cache.keys().next().value;
      this.cache.delete(oldestKey);
    }
    
    this.cache.set(key, {
      value,
      timestamp: Date.now(),
      ttl,
    });
  }
  
  get(key: string): any | null {
    const entry = this.cache.get(key);
    
    if (!entry) return null;
    
    // Check if expired
    if (Date.now() - entry.timestamp > entry.ttl) {
      this.cache.delete(key);
      return null;
    }
    
    return entry.value;
  }
  
  clear(): void {
    this.cache.clear();
  }
  
  size(): number {
    return this.cache.size;
  }
}

export const cacheManager = new CacheManager({ maxSize: 500 });

// HTTP cache headers
export function withCache(handler: NextApiHandler, maxAge = 300): NextApiHandler {
  return async (req, res) => {
    // Set cache headers
    res.setHeader(
      'Cache-Control',
      `public, max-age=${maxAge}, s-maxage=${maxAge}, stale-while-revalidate=86400`
    );
    
    return handler(req, res);
  };
}
```

## 📊 Performance Monitoring

### **Core Web Vitals Tracking**

```typescript
// lib/performance-monitoring.ts
export function reportWebVitals(metric: NextWebVitalsMetric) {
  // Log to console in development
  if (process.env.NODE_ENV === 'development') {
    console.log(metric);
  }
  
  // Send to analytics in production
  if (process.env.NODE_ENV === 'production') {
    switch (metric.name) {
      case 'FCP':
        // First Contentful Paint
        gtag('event', 'web_vitals', {
          event_category: 'performance',
          event_label: 'FCP',
          value: metric.value,
        });
        break;
      case 'LCP':
        // Largest Contentful Paint
        gtag('event', 'web_vitals', {
          event_category: 'performance',
          event_label: 'LCP',
          value: metric.value,
        });
        break;
      case 'CLS':
        // Cumulative Layout Shift
        gtag('event', 'web_vitals', {
          event_category: 'performance',
          event_label: 'CLS',
          value: metric.value,
        });
        break;
      case 'FID':
        // First Input Delay
        gtag('event', 'web_vitals', {
          event_category: 'performance',
          event_label: 'FID',
          value: metric.value,
        });
        break;
      case 'TTFB':
        // Time to First Byte
        gtag('event', 'web_vitals', {
          event_category: 'performance',
          event_label: 'TTFB',
          value: metric.value,
        });
        break;
    }
  }
}

// Custom performance hooks
export function usePerformanceObserver() {
  useEffect(() => {
    if (typeof window !== 'undefined' && 'PerformanceObserver' in window) {
      const observer = new PerformanceObserver((list) => {
        list.getEntries().forEach((entry) => {
          if (entry.entryType === 'navigation') {
            const navEntry = entry as PerformanceNavigationTiming;
            console.log('Navigation timing:', {
              domContentLoaded: navEntry.domContentLoadedEventEnd - navEntry.domContentLoadedEventStart,
              loadComplete: navEntry.loadEventEnd - navEntry.loadEventStart,
              totalTime: navEntry.loadEventEnd - navEntry.fetchStart,
            });
          }
        });
      });
      
      observer.observe({ entryTypes: ['navigation', 'paint', 'largest-contentful-paint'] });
      
      return () => observer.disconnect();
    }
  }, []);
}
```

## 🎯 Performance Decision Matrix

| Optimization | When to Use | Impact | Complexity |
|--------------|-------------|---------|------------|
| **Image Optimization** | Always | High | Low |
| **Code Splitting** | Bundle > 1MB | High | Medium |
| **Memoization** | Expensive calculations | Medium | Medium |
| **Virtual Scrolling** | Large lists (>1000 items) | High | High |
| **Service Workers** | Offline functionality | High | High |
| **CDN** | Global audience | High | Low |

## 🏆 Performance Best Practices

### **✅ Performance Do's**
1. **Implement Core Web Vitals** monitoring from day one
2. **Use Next.js Image component** for automatic optimization
3. **Lazy load non-critical components** and routes
4. **Memoize expensive calculations** and stable callbacks
5. **Implement proper caching strategies** at multiple levels
6. **Monitor bundle size** regularly with webpack-bundle-analyzer
7. **Use performance budgets** in CI/CD pipeline

### **❌ Performance Don'ts**
1. **Don't ignore loading states** - always show progress indicators
2. **Don't import entire libraries** - use tree shaking and selective imports
3. **Don't skip image optimization** - always use next/image
4. **Don't over-memoize** - profile before optimizing
5. **Don't ignore accessibility** - performance includes screen readers
6. **Don't forget mobile performance** - test on slower devices
7. **Don't skip performance monitoring** - measure real user metrics

---

## Navigation

- ← Previous: [API Integration Patterns](./api-integration-patterns.md)
- → Next: [Testing Strategies](./testing-strategies.md)

| [📋 Overview](./README.md) | [🔗 API Integration](./api-integration-patterns.md) | [⚡ Performance](#) | [🧪 Testing](./testing-strategies.md) |
|---|---|---|---|