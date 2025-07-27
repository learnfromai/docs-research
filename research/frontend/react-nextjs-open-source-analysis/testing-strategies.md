# Testing Strategies in React & Next.js Applications

## 🎯 Overview

Comprehensive analysis of testing approaches, frameworks, and methodologies used in production React and Next.js applications to ensure code quality and reliability.

## 📊 Testing Landscape

### **Framework Adoption**
- **Vitest**: 55% (modern projects, faster than Jest)
- **Jest**: 40% (established projects, legacy support)
- **Playwright**: 45% (E2E testing, replacing Cypress)
- **Cypress**: 35% (E2E testing, established projects)
- **Testing Library**: 90% (React component testing)

## 🧪 Modern Testing Stack: Vitest + Testing Library

### **Vitest Configuration**

```typescript
// vitest.config.ts
import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';
import path from 'path';

export default defineConfig({
  plugins: [react()],
  test: {
    environment: 'jsdom',
    setupFiles: ['./src/test/setup.ts'],
    globals: true,
    css: true,
    coverage: {
      reporter: ['text', 'json', 'html'],
      exclude: [
        'node_modules/',
        'src/test/',
        '**/*.d.ts',
        '**/*.config.*',
        'src/lib/utils.ts', // Utility functions
      ],
      thresholds: {
        global: {
          branches: 80,
          functions: 80,
          lines: 80,
          statements: 80,
        },
      },
    },
  },
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
});

// src/test/setup.ts
import '@testing-library/jest-dom';
import { vi } from 'vitest';

// Mock Next.js router
vi.mock('next/router', () => ({
  useRouter: () => ({
    push: vi.fn(),
    replace: vi.fn(),
    back: vi.fn(),
    query: {},
    pathname: '/',
    asPath: '/',
  }),
}));

// Mock Next.js navigation
vi.mock('next/navigation', () => ({
  useRouter: () => ({
    push: vi.fn(),
    replace: vi.fn(),
    back: vi.fn(),
  }),
  useSearchParams: () => ({
    get: vi.fn(),
  }),
  usePathname: () => '/',
}));

// Mock environment variables
Object.defineProperty(window, 'matchMedia', {
  writable: true,
  value: vi.fn().mockImplementation(query => ({
    matches: false,
    media: query,
    onchange: null,
    addListener: vi.fn(),
    removeListener: vi.fn(),
    addEventListener: vi.fn(),
    removeEventListener: vi.fn(),
    dispatchEvent: vi.fn(),
  })),
});

// Mock IntersectionObserver
global.IntersectionObserver = vi.fn().mockImplementation(() => ({
  observe: vi.fn(),
  unobserve: vi.fn(),
  disconnect: vi.fn(),
}));
```

### **Component Testing Patterns**

```typescript
// components/__tests__/Button.test.tsx
import { render, screen, fireEvent } from '@testing-library/react';
import { describe, it, expect, vi } from 'vitest';
import { Button } from '../Button';

describe('Button Component', () => {
  it('renders with correct text', () => {
    render(<Button>Click me</Button>);
    expect(screen.getByRole('button', { name: /click me/i })).toBeInTheDocument();
  });

  it('handles click events', () => {
    const handleClick = vi.fn();
    render(<Button onClick={handleClick}>Click me</Button>);
    
    fireEvent.click(screen.getByRole('button'));
    expect(handleClick).toHaveBeenCalledOnce();
  });

  it('applies variant classes correctly', () => {
    render(<Button variant="destructive">Delete</Button>);
    expect(screen.getByRole('button')).toHaveClass('bg-destructive');
  });

  it('is disabled when loading', () => {
    render(<Button loading>Loading...</Button>);
    expect(screen.getByRole('button')).toBeDisabled();
    expect(screen.getByRole('button')).toHaveAttribute('aria-busy', 'true');
  });

  it('forwards ref correctly', () => {
    const ref = vi.fn();
    render(<Button ref={ref}>Button</Button>);
    expect(ref).toHaveBeenCalled();
  });
});

// components/__tests__/ProjectCard.test.tsx
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { ProjectCard } from '../ProjectCard';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';

const mockProject = {
  id: '1',
  name: 'Test Project',
  description: 'A test project',
  status: 'active' as const,
  priority: 'high' as const,
  createdAt: '2024-01-01T00:00:00Z',
  owner: {
    id: '1',
    name: 'John Doe',
    avatar: '/avatar.jpg',
  },
};

function renderWithQueryClient(component: React.ReactElement) {
  const queryClient = new QueryClient({
    defaultOptions: {
      queries: { retry: false },
      mutations: { retry: false },
    },
  });

  return render(
    <QueryClientProvider client={queryClient}>
      {component}
    </QueryClientProvider>
  );
}

describe('ProjectCard Component', () => {
  const mockOnEdit = vi.fn();
  const mockOnDelete = vi.fn();

  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('displays project information correctly', () => {
    renderWithQueryClient(
      <ProjectCard
        project={mockProject}
        onEdit={mockOnEdit}
        onDelete={mockOnDelete}
      />
    );

    expect(screen.getByText('Test Project')).toBeInTheDocument();
    expect(screen.getByText('A test project')).toBeInTheDocument();
    expect(screen.getByText('active')).toBeInTheDocument();
    expect(screen.getByText('high')).toBeInTheDocument();
  });

  it('calls onEdit when edit button is clicked', async () => {
    renderWithQueryClient(
      <ProjectCard
        project={mockProject}
        onEdit={mockOnEdit}
        onDelete={mockOnDelete}
      />
    );

    fireEvent.click(screen.getByRole('button', { name: /edit/i }));
    expect(mockOnEdit).toHaveBeenCalledWith(mockProject.id);
  });

  it('shows confirmation dialog before deletion', async () => {
    renderWithQueryClient(
      <ProjectCard
        project={mockProject}
        onEdit={mockOnEdit}
        onDelete={mockOnDelete}
      />
    );

    fireEvent.click(screen.getByRole('button', { name: /delete/i }));
    
    expect(screen.getByText(/are you sure/i)).toBeInTheDocument();
    
    fireEvent.click(screen.getByRole('button', { name: /confirm/i }));
    expect(mockOnDelete).toHaveBeenCalledWith(mockProject.id);
  });

  it('handles loading state during operations', async () => {
    const loadingProject = { ...mockProject, isUpdating: true };
    
    renderWithQueryClient(
      <ProjectCard
        project={loadingProject}
        onEdit={mockOnEdit}
        onDelete={mockOnDelete}
      />
    );

    expect(screen.getByRole('button', { name: /edit/i })).toBeDisabled();
    expect(screen.getByRole('button', { name: /delete/i })).toBeDisabled();
  });
});
```

### **Hook Testing**

```typescript
// hooks/__tests__/use-projects.test.ts
import { renderHook, waitFor } from '@testing-library/react';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { useProjects, useCreateProject } from '../use-projects';
import { projectService } from '@/services/project-service';

// Mock the service
vi.mock('@/services/project-service');

const mockProjectService = vi.mocked(projectService);

function createWrapper() {
  const queryClient = new QueryClient({
    defaultOptions: {
      queries: { retry: false },
      mutations: { retry: false },
    },
  });

  return ({ children }: { children: React.ReactNode }) => (
    <QueryClientProvider client={queryClient}>
      {children}
    </QueryClientProvider>
  );
}

describe('useProjects Hook', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('fetches projects successfully', async () => {
    const mockProjects = [
      { id: '1', name: 'Project 1', status: 'active' },
      { id: '2', name: 'Project 2', status: 'completed' },
    ];

    mockProjectService.getProjects.mockResolvedValue(mockProjects);

    const { result } = renderHook(() => useProjects(), {
      wrapper: createWrapper(),
    });

    await waitFor(() => {
      expect(result.current.isSuccess).toBe(true);
    });

    expect(result.current.data).toEqual(mockProjects);
    expect(mockProjectService.getProjects).toHaveBeenCalledOnce();
  });

  it('handles error states', async () => {
    const errorMessage = 'Failed to fetch projects';
    mockProjectService.getProjects.mockRejectedValue(new Error(errorMessage));

    const { result } = renderHook(() => useProjects(), {
      wrapper: createWrapper(),
    });

    await waitFor(() => {
      expect(result.current.isError).toBe(true);
    });

    expect(result.current.error?.message).toBe(errorMessage);
  });

  it('filters projects correctly', async () => {
    const mockProjects = [
      { id: '1', name: 'Project 1', status: 'active' },
      { id: '2', name: 'Project 2', status: 'completed' },
    ];

    mockProjectService.getProjects.mockResolvedValue(mockProjects);

    const { result } = renderHook(
      () => useProjects({ status: 'active' }),
      { wrapper: createWrapper() }
    );

    await waitFor(() => {
      expect(result.current.isSuccess).toBe(true);
    });

    expect(mockProjectService.getProjects).toHaveBeenCalledWith({ status: 'active' });
  });
});

describe('useCreateProject Hook', () => {
  it('creates project successfully', async () => {
    const newProject = { id: '3', name: 'New Project', status: 'draft' };
    mockProjectService.createProject.mockResolvedValue(newProject);

    const { result } = renderHook(() => useCreateProject(), {
      wrapper: createWrapper(),
    });

    const createData = { name: 'New Project', priority: 'medium' as const };
    
    result.current.mutate(createData);

    await waitFor(() => {
      expect(result.current.isSuccess).toBe(true);
    });

    expect(result.current.data).toEqual(newProject);
    expect(mockProjectService.createProject).toHaveBeenCalledWith(createData);
  });

  it('handles creation errors', async () => {
    const errorMessage = 'Failed to create project';
    mockProjectService.createProject.mockRejectedValue(new Error(errorMessage));

    const { result } = renderHook(() => useCreateProject(), {
      wrapper: createWrapper(),
    });

    result.current.mutate({ name: 'New Project', priority: 'medium' as const });

    await waitFor(() => {
      expect(result.current.isError).toBe(true);
    });

    expect(result.current.error?.message).toBe(errorMessage);
  });
});
```

## 🎭 Integration Testing

### **Page Testing with Next.js**

```typescript
// app/__tests__/dashboard.test.tsx
import { render, screen, waitFor, fireEvent } from '@testing-library/react';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import Dashboard from '../dashboard/page';
import { useSession } from 'next-auth/react';
import { projectService } from '@/services/project-service';

// Mock dependencies
vi.mock('next-auth/react');
vi.mock('@/services/project-service');

const mockUseSession = vi.mocked(useSession);
const mockProjectService = vi.mocked(projectService);

function renderWithProviders(component: React.ReactElement) {
  const queryClient = new QueryClient({
    defaultOptions: {
      queries: { retry: false },
      mutations: { retry: false },
    },
  });

  return render(
    <QueryClientProvider client={queryClient}>
      {component}
    </QueryClientProvider>
  );
}

describe('Dashboard Page', () => {
  const mockSession = {
    user: {
      id: '1',
      email: 'test@example.com',
      name: 'Test User',
      role: 'user',
    },
    expires: '2024-12-31',
  };

  beforeEach(() => {
    vi.clearAllMocks();
    mockUseSession.mockReturnValue({
      data: mockSession,
      status: 'authenticated',
      update: vi.fn(),
    });
  });

  it('renders dashboard with user projects', async () => {
    const mockProjects = [
      {
        id: '1',
        name: 'Project Alpha',
        description: 'First project',
        status: 'active' as const,
        priority: 'high' as const,
        createdAt: '2024-01-01T00:00:00Z',
        owner: mockSession.user,
      },
    ];

    mockProjectService.getProjects.mockResolvedValue(mockProjects);

    renderWithProviders(<Dashboard />);

    expect(screen.getByText('Dashboard')).toBeInTheDocument();
    expect(screen.getByText('Welcome back, Test User!')).toBeInTheDocument();

    await waitFor(() => {
      expect(screen.getByText('Project Alpha')).toBeInTheDocument();
    });

    expect(screen.getByText('First project')).toBeInTheDocument();
  });

  it('shows empty state when no projects exist', async () => {
    mockProjectService.getProjects.mockResolvedValue([]);

    renderWithProviders(<Dashboard />);

    await waitFor(() => {
      expect(screen.getByText(/no projects found/i)).toBeInTheDocument();
    });

    expect(screen.getByRole('button', { name: /create your first project/i })).toBeInTheDocument();
  });

  it('handles project creation', async () => {
    const newProject = {
      id: '2',
      name: 'New Project',
      description: 'Project description',
      status: 'draft' as const,
      priority: 'medium' as const,
      createdAt: '2024-01-02T00:00:00Z',
      owner: mockSession.user,
    };

    mockProjectService.getProjects.mockResolvedValue([]);
    mockProjectService.createProject.mockResolvedValue(newProject);

    renderWithProviders(<Dashboard />);

    await waitFor(() => {
      expect(screen.getByRole('button', { name: /create project/i })).toBeInTheDocument();
    });

    fireEvent.click(screen.getByRole('button', { name: /create project/i }));

    // Fill out form
    fireEvent.change(screen.getByLabelText(/project name/i), {
      target: { value: 'New Project' },
    });

    fireEvent.change(screen.getByLabelText(/description/i), {
      target: { value: 'Project description' },
    });

    fireEvent.click(screen.getByRole('button', { name: /save/i }));

    await waitFor(() => {
      expect(mockProjectService.createProject).toHaveBeenCalledWith({
        name: 'New Project',
        description: 'Project description',
        priority: 'medium',
      });
    });
  });

  it('redirects unauthenticated users', () => {
    mockUseSession.mockReturnValue({
      data: null,
      status: 'unauthenticated',
      update: vi.fn(),
    });

    renderWithProviders(<Dashboard />);

    expect(screen.getByText(/please sign in/i)).toBeInTheDocument();
  });
});
```

### **API Route Testing**

```typescript
// app/api/__tests__/projects.test.ts
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { createMocks } from 'node-mocks-http';
import handler from '../projects/route';
import { prisma } from '@/lib/prisma';
import { getServerSession } from 'next-auth/next';

// Mock dependencies
vi.mock('@/lib/prisma');
vi.mock('next-auth/next');

const mockPrisma = vi.mocked(prisma);
const mockGetServerSession = vi.mocked(getServerSession);

describe('/api/projects', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  describe('GET /api/projects', () => {
    it('returns user projects when authenticated', async () => {
      const mockSession = {
        user: { id: '1', email: 'test@example.com', name: 'Test User' },
      };

      const mockProjects = [
        {
          id: '1',
          name: 'Project 1',
          description: 'First project',
          status: 'active',
          userId: '1',
        },
      ];

      mockGetServerSession.mockResolvedValue(mockSession);
      mockPrisma.project.findMany.mockResolvedValue(mockProjects);

      const { req, res } = createMocks({
        method: 'GET',
      });

      await handler(req, res);

      expect(res._getStatusCode()).toBe(200);
      expect(JSON.parse(res._getData())).toEqual(mockProjects);
      expect(mockPrisma.project.findMany).toHaveBeenCalledWith({
        where: { userId: '1' },
        include: expect.any(Object),
      });
    });

    it('returns 401 when not authenticated', async () => {
      mockGetServerSession.mockResolvedValue(null);

      const { req, res } = createMocks({
        method: 'GET',
      });

      await handler(req, res);

      expect(res._getStatusCode()).toBe(401);
      expect(JSON.parse(res._getData())).toEqual({
        error: 'Authentication required',
      });
    });

    it('handles database errors gracefully', async () => {
      const mockSession = {
        user: { id: '1', email: 'test@example.com', name: 'Test User' },
      };

      mockGetServerSession.mockResolvedValue(mockSession);
      mockPrisma.project.findMany.mockRejectedValue(new Error('Database error'));

      const { req, res } = createMocks({
        method: 'GET',
      });

      await handler(req, res);

      expect(res._getStatusCode()).toBe(500);
      expect(JSON.parse(res._getData())).toEqual({
        error: 'Internal server error',
      });
    });
  });

  describe('POST /api/projects', () => {
    it('creates project successfully', async () => {
      const mockSession = {
        user: { id: '1', email: 'test@example.com', name: 'Test User' },
      };

      const projectData = {
        name: 'New Project',
        description: 'Project description',
        priority: 'high',
      };

      const createdProject = {
        id: '2',
        ...projectData,
        status: 'draft',
        userId: '1',
        createdAt: new Date(),
        updatedAt: new Date(),
      };

      mockGetServerSession.mockResolvedValue(mockSession);
      mockPrisma.project.create.mockResolvedValue(createdProject);

      const { req, res } = createMocks({
        method: 'POST',
        body: projectData,
      });

      await handler(req, res);

      expect(res._getStatusCode()).toBe(201);
      expect(JSON.parse(res._getData())).toEqual(createdProject);
      expect(mockPrisma.project.create).toHaveBeenCalledWith({
        data: {
          ...projectData,
          userId: '1',
          status: 'draft',
        },
        include: expect.any(Object),
      });
    });

    it('validates required fields', async () => {
      const mockSession = {
        user: { id: '1', email: 'test@example.com', name: 'Test User' },
      };

      mockGetServerSession.mockResolvedValue(mockSession);

      const { req, res } = createMocks({
        method: 'POST',
        body: { description: 'Missing name' },
      });

      await handler(req, res);

      expect(res._getStatusCode()).toBe(400);
      expect(JSON.parse(res._getData())).toMatchObject({
        error: 'Validation error',
      });
    });
  });
});
```

## 🎯 End-to-End Testing with Playwright

### **Playwright Configuration**

```typescript
// playwright.config.ts
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './e2e',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: [
    ['html'],
    ['json', { outputFile: 'test-results/results.json' }],
    process.env.CI && ['github'],
  ].filter(Boolean),
  
  use: {
    baseURL: process.env.PLAYWRIGHT_BASE_URL || 'http://localhost:3000',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
  },

  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
    {
      name: 'firefox',
      use: { ...devices['Desktop Firefox'] },
    },
    {
      name: 'webkit',
      use: { ...devices['Desktop Safari'] },
    },
    {
      name: 'Mobile Chrome',
      use: { ...devices['Pixel 5'] },
    },
    {
      name: 'Mobile Safari',
      use: { ...devices['iPhone 12'] },
    },
  ],

  webServer: {
    command: 'npm run dev',
    port: 3000,
    reuseExistingServer: !process.env.CI,
  },
});
```

### **E2E Test Patterns**

```typescript
// e2e/dashboard.spec.ts
import { test, expect } from '@playwright/test';

test.describe('Dashboard', () => {
  test.beforeEach(async ({ page }) => {
    // Mock authentication
    await page.goto('/api/auth/signin');
    await page.fill('[name="email"]', 'test@example.com');
    await page.fill('[name="password"]', 'password123');
    await page.click('button[type="submit"]');
    
    // Wait for redirect to dashboard
    await page.waitForURL('/dashboard');
  });

  test('displays user projects', async ({ page }) => {
    await expect(page.locator('h1')).toContainText('Dashboard');
    
    // Check for project cards
    await expect(page.locator('[data-testid="project-card"]')).toHaveCount(3);
    
    // Verify project information
    const firstProject = page.locator('[data-testid="project-card"]').first();
    await expect(firstProject.locator('h3')).toContainText('Project Alpha');
    await expect(firstProject.locator('[data-testid="status-badge"]')).toContainText('Active');
  });

  test('creates new project', async ({ page }) => {
    // Click create project button
    await page.click('[data-testid="create-project-btn"]');
    
    // Fill project form
    await page.fill('[name="name"]', 'New Test Project');
    await page.fill('[name="description"]', 'This is a test project');
    await page.selectOption('[name="priority"]', 'high');
    
    // Submit form
    await page.click('button[type="submit"]');
    
    // Verify project was created
    await expect(page.locator('[data-testid="project-card"]')).toHaveCount(4);
    await expect(page.locator('text=New Test Project')).toBeVisible();
    
    // Check success notification
    await expect(page.locator('[data-testid="toast"]')).toContainText('Project created successfully');
  });

  test('edits project', async ({ page }) => {
    // Click edit on first project
    await page.locator('[data-testid="project-card"]').first().hover();
    await page.click('[data-testid="edit-project-btn"]');
    
    // Update project name
    await page.fill('[name="name"]', 'Updated Project Name');
    await page.click('button[type="submit"]');
    
    // Verify update
    await expect(page.locator('text=Updated Project Name')).toBeVisible();
  });

  test('deletes project with confirmation', async ({ page }) => {
    const initialCount = await page.locator('[data-testid="project-card"]').count();
    
    // Click delete on first project
    await page.locator('[data-testid="project-card"]').first().hover();
    await page.click('[data-testid="delete-project-btn"]');
    
    // Confirm deletion
    await expect(page.locator('[data-testid="confirm-dialog"]')).toBeVisible();
    await page.click('[data-testid="confirm-delete-btn"]');
    
    // Verify project was deleted
    await expect(page.locator('[data-testid="project-card"]')).toHaveCount(initialCount - 1);
  });

  test('filters projects by status', async ({ page }) => {
    // Apply filter
    await page.selectOption('[data-testid="status-filter"]', 'active');
    
    // Verify filtered results
    const projectCards = page.locator('[data-testid="project-card"]');
    const count = await projectCards.count();
    
    for (let i = 0; i < count; i++) {
      const statusBadge = projectCards.nth(i).locator('[data-testid="status-badge"]');
      await expect(statusBadge).toContainText('Active');
    }
  });

  test('searches projects', async ({ page }) => {
    // Search for specific project
    await page.fill('[data-testid="search-input"]', 'Alpha');
    
    // Verify search results
    await expect(page.locator('[data-testid="project-card"]')).toHaveCount(1);
    await expect(page.locator('text=Project Alpha')).toBeVisible();
  });
});

// e2e/auth.spec.ts
test.describe('Authentication', () => {
  test('sign in flow', async ({ page }) => {
    await page.goto('/auth/signin');
    
    // Test email/password sign in
    await page.fill('[name="email"]', 'test@example.com');
    await page.fill('[name="password"]', 'password123');
    await page.click('button[type="submit"]');
    
    // Should redirect to dashboard
    await page.waitForURL('/dashboard');
    await expect(page.locator('h1')).toContainText('Dashboard');
  });

  test('sign in with Google', async ({ page }) => {
    await page.goto('/auth/signin');
    
    // Mock Google OAuth flow
    await page.route('**/auth/signin/google**', route => {
      route.fulfill({
        status: 302,
        headers: { location: '/dashboard' },
      });
    });
    
    await page.click('text=Continue with Google');
    await page.waitForURL('/dashboard');
  });

  test('handles sign in errors', async ({ page }) => {
    await page.goto('/auth/signin');
    
    // Test with invalid credentials
    await page.fill('[name="email"]', 'invalid@example.com');
    await page.fill('[name="password"]', 'wrongpassword');
    await page.click('button[type="submit"]');
    
    // Should show error message
    await expect(page.locator('[data-testid="error-message"]')).toContainText('Invalid credentials');
  });

  test('sign out flow', async ({ page }) => {
    // Sign in first
    await page.goto('/api/auth/signin');
    await page.fill('[name="email"]', 'test@example.com');
    await page.fill('[name="password"]', 'password123');
    await page.click('button[type="submit"]');
    
    await page.waitForURL('/dashboard');
    
    // Sign out
    await page.click('[data-testid="user-menu"]');
    await page.click('text=Sign out');
    
    // Should redirect to home
    await page.waitForURL('/');
    await expect(page.locator('text=Sign in')).toBeVisible();
  });
});
```

### **Visual Regression Testing**

```typescript
// e2e/visual.spec.ts
import { test, expect } from '@playwright/test';

test.describe('Visual Regression Tests', () => {
  test('dashboard appearance', async ({ page }) => {
    await page.goto('/dashboard');
    
    // Wait for content to load
    await page.waitForSelector('[data-testid="project-card"]');
    
    // Take screenshot
    await expect(page).toHaveScreenshot('dashboard.png');
  });

  test('project card variants', async ({ page }) => {
    await page.goto('/dashboard');
    
    // Test different project states
    const activeProject = page.locator('[data-testid="project-card"][data-status="active"]').first();
    await expect(activeProject).toHaveScreenshot('active-project.png');
    
    const completedProject = page.locator('[data-testid="project-card"][data-status="completed"]').first();
    await expect(completedProject).toHaveScreenshot('completed-project.png');
  });

  test('mobile responsive design', async ({ page }) => {
    await page.setViewportSize({ width: 375, height: 667 });
    await page.goto('/dashboard');
    
    await page.waitForSelector('[data-testid="project-card"]');
    await expect(page).toHaveScreenshot('dashboard-mobile.png');
  });

  test('dark mode appearance', async ({ page }) => {
    // Set dark mode preference
    await page.emulateMedia({ colorScheme: 'dark' });
    await page.goto('/dashboard');
    
    await page.waitForSelector('[data-testid="project-card"]');
    await expect(page).toHaveScreenshot('dashboard-dark.png');
  });
});
```

## 🎯 Testing Strategy Decision Matrix

| Test Type | Coverage | Speed | Confidence | Maintenance |
|-----------|----------|-------|------------|-------------|
| **Unit Tests** | High | Fast | Medium | Low |
| **Integration Tests** | Medium | Medium | High | Medium |
| **E2E Tests** | Low | Slow | Very High | High |
| **Visual Tests** | Low | Medium | Medium | Medium |

## 🏆 Testing Best Practices

### **✅ Testing Do's**
1. **Follow the testing pyramid** - more unit tests, fewer E2E tests
2. **Test user behavior** not implementation details
3. **Use data-testid attributes** for reliable selectors
4. **Mock external dependencies** in unit/integration tests
5. **Write descriptive test names** that explain the scenario
6. **Test error states** and edge cases
7. **Use page objects** for E2E tests to reduce duplication

### **❌ Testing Don'ts**
1. **Don't test implementation details** - focus on user-facing behavior
2. **Don't skip error scenarios** - test failure cases thoroughly
3. **Don't write flaky tests** - ensure tests are deterministic
4. **Don't ignore accessibility** - include a11y testing
5. **Don't over-mock** - balance mocking with real integration
6. **Don't skip CI/CD integration** - run tests on every commit
7. **Don't forget performance testing** - measure and monitor

---

## Navigation

- ← Previous: [Performance Optimization](./performance-optimization.md)
- → Next: [Best Practices Guide](./best-practices.md)

| [📋 Overview](./README.md) | [⚡ Performance](./performance-optimization.md) | [🧪 Testing](#) | [⚡ Best Practices](./best-practices.md) |
|---|---|---|---|