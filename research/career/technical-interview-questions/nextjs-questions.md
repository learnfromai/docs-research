# Next.js Interview Questions & Answers

## 📋 Table of Contents

1. [Next.js Fundamentals](#nextjs-fundamentals)
2. [App Router vs Pages Router](#app-router-vs-pages-router)
3. [Server-Side Rendering (SSR)](#server-side-rendering-ssr)
4. [Static Site Generation (SSG)](#static-site-generation-ssg)
5. [API Routes](#api-routes)
6. [Performance & Optimization](#performance--optimization)
7. [Deployment & Production](#deployment--production)

---

## Next.js Fundamentals

### 1. What is Next.js and what problems does it solve?

**Answer:**
Next.js is a React framework that provides production-ready features like server-side rendering, static site generation, API routes, and automatic code splitting out of the box.

**Problems Next.js Solves:**

```typescript
// 1. SEO and Performance - Server-side rendering
export default function ProductPage({ product }: { product: Product }) {
  return (
    <div>
      <h1>{product.title}</h1>
      <p>{product.description}</p>
      {/* Content is rendered on server for SEO */}
    </div>
  );
}

export async function getServerSideProps(context: GetServerSidePropsContext) {
  const { id } = context.params!;
  const product = await fetchProduct(id as string);
  
  return {
    props: { product }
  };
}

// 2. Routing - File-based routing system
// pages/products/[id].tsx automatically creates /products/:id route

// 3. API Development - Built-in API routes
// pages/api/users.ts
export default function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.method === 'GET') {
    const users = await getUsers();
    res.status(200).json(users);
  }
}

// 4. Code Splitting - Automatic optimization
import dynamic from 'next/dynamic';

const DynamicComponent = dynamic(() => import('../components/heavy-component'), {
  loading: () => <p>Loading...</p>,
});

// 5. Built-in CSS Support
import styles from './Home.module.css';

export default function Home() {
  return <div className={styles.container}>Hello World</div>;
}
```

### 2. What are the different rendering methods in Next.js?

**Answer:**
Next.js supports multiple rendering strategies:

```typescript
// 1. Static Site Generation (SSG) - Build time
export async function getStaticProps() {
  const posts = await fetchPosts();
  
  return {
    props: { posts },
    revalidate: 3600, // ISR - regenerate every hour
  };
}

// For dynamic routes
export async function getStaticPaths() {
  const posts = await fetchPosts();
  const paths = posts.map((post) => ({
    params: { id: post.id.toString() }
  }));
  
  return {
    paths,
    fallback: 'blocking' // or true, false
  };
}

// 2. Server-Side Rendering (SSR) - Request time
export async function getServerSideProps(context: GetServerSidePropsContext) {
  const { req, res, params, query } = context;
  const user = await authenticateUser(req);
  
  if (!user) {
    return {
      redirect: {
        destination: '/login',
        permanent: false,
      },
    };
  }
  
  return {
    props: { user }
  };
}

// 3. Client-Side Rendering (CSR) - Browser
import { useEffect, useState } from 'react';

export default function Dashboard() {
  const [data, setData] = useState(null);
  
  useEffect(() => {
    // Fetch data after component mounts
    fetchUserData().then(setData);
  }, []);
  
  if (!data) return <div>Loading...</div>;
  
  return <div>{/* Render data */}</div>;
}

// 4. Incremental Static Regeneration (ISR)
export async function getStaticProps() {
  const data = await fetchData();
  
  return {
    props: { data },
    revalidate: 60, // Regenerate page at most once every 60 seconds
  };
}
```

### 3. How does Next.js routing work?

**Answer:**
Next.js uses file-based routing in both Pages Router and App Router:

```typescript
// Pages Router Structure
pages/
  index.tsx           // Route: /
  about.tsx          // Route: /about
  products/
    index.tsx        // Route: /products
    [id].tsx         // Route: /products/:id
    [...slug].tsx    // Route: /products/* (catch-all)
  api/
    users.ts         // API: /api/users
    auth/
      login.ts       // API: /api/auth/login

// App Router Structure (Next.js 13+)
app/
  page.tsx           // Route: /
  about/
    page.tsx         // Route: /about
  products/
    page.tsx         // Route: /products
    [id]/
      page.tsx       // Route: /products/:id
    layout.tsx       // Layout for /products/*
  api/
    users/
      route.ts       // API: /api/users

// Dynamic routing examples
// pages/posts/[id].tsx
import { useRouter } from 'next/router';

export default function Post() {
  const router = useRouter();
  const { id } = router.query;
  
  return <div>Post ID: {id}</div>;
}

// Programmatic navigation
import { useRouter } from 'next/router';

export default function Component() {
  const router = useRouter();
  
  const handleClick = () => {
    router.push('/products/123');
    // or
    router.push({
      pathname: '/products/[id]',
      query: { id: '123' }
    });
  };
  
  return <button onClick={handleClick}>Go to Product</button>;
}

// App Router navigation
import { useRouter } from 'next/navigation';

export default function Component() {
  const router = useRouter();
  
  const handleClick = () => {
    router.push('/products/123');
    router.refresh(); // Refresh current route
    router.back(); // Go back
  };
  
  return <button onClick={handleClick}>Navigate</button>;
}
```

---

## App Router vs Pages Router

### 4. What are the differences between App Router and Pages Router?

**Answer:**
Next.js 13 introduced the App Router as a new paradigm:

```typescript
// Pages Router (Legacy)
// pages/products/[id].tsx
import { GetServerSideProps } from 'next';

interface Props {
  product: Product;
}

export default function ProductPage({ product }: Props) {
  return <div>{product.name}</div>;
}

export const getServerSideProps: GetServerSideProps = async (context) => {
  const product = await fetchProduct(context.params!.id as string);
  return { props: { product } };
};

// App Router (New)
// app/products/[id]/page.tsx
interface Props {
  params: { id: string };
}

export default async function ProductPage({ params }: Props) {
  const product = await fetchProduct(params.id);
  return <div>{product.name}</div>;
}

// Key Differences:

// 1. Server Components by default (App Router)
// app/components/ServerComponent.tsx
export default async function ServerComponent() {
  const data = await fetch('https://api.example.com/data');
  return <div>{/* Rendered on server */}</div>;
}

// Client components explicitly marked
'use client';
import { useState } from 'react';

export default function ClientComponent() {
  const [count, setCount] = useState(0);
  return <button onClick={() => setCount(count + 1)}>{count}</button>;
}

// 2. Nested Layouts (App Router)
// app/layout.tsx - Root layout
export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body>
        <header>Global Header</header>
        {children}
        <footer>Global Footer</footer>
      </body>
    </html>
  );
}

// app/dashboard/layout.tsx - Nested layout
export default function DashboardLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <div className="dashboard">
      <nav>Dashboard Navigation</nav>
      <main>{children}</main>
    </div>
  );
}

// 3. Data Fetching (App Router)
// app/posts/page.tsx
async function getPosts() {
  const res = await fetch('https://api.example.com/posts', {
    next: { revalidate: 3600 } // ISR
  });
  return res.json();
}

export default async function PostsPage() {
  const posts = await getPosts();
  
  return (
    <div>
      {posts.map(post => (
        <article key={post.id}>{post.title}</article>
      ))}
    </div>
  );
}
```

### 5. How do you handle loading and error states in App Router?

**Answer:**
App Router provides special files for handling loading and error states:

```typescript
// app/products/loading.tsx - Loading UI
export default function Loading() {
  return (
    <div className="animate-pulse">
      <div className="h-6 bg-gray-200 rounded mb-4"></div>
      <div className="h-4 bg-gray-200 rounded mb-2"></div>
      <div className="h-4 bg-gray-200 rounded mb-2"></div>
    </div>
  );
}

// app/products/error.tsx - Error UI
'use client';

export default function Error({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  return (
    <div className="error-container">
      <h2>Something went wrong!</h2>
      <p>{error.message}</p>
      <button onClick={() => reset()}>Try again</button>
    </div>
  );
}

// app/products/not-found.tsx - 404 UI
export default function NotFound() {
  return (
    <div>
      <h2>Product Not Found</h2>
      <p>Could not find the requested product.</p>
    </div>
  );
}

// In page component - trigger not-found
import { notFound } from 'next/navigation';

async function getProduct(id: string) {
  const res = await fetch(`/api/products/${id}`);
  if (!res.ok) return null;
  return res.json();
}

export default async function ProductPage({ params }: { params: { id: string } }) {
  const product = await getProduct(params.id);
  
  if (!product) {
    notFound(); // Triggers not-found.tsx
  }
  
  return <div>{product.name}</div>;
}

// Error boundaries for specific errors
// app/products/[id]/error.tsx
'use client';

import { useEffect } from 'react';

export default function Error({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    // Log the error to an error reporting service
    console.error('Product page error:', error);
  }, [error]);
  
  return (
    <div className="min-h-screen flex items-center justify-center">
      <div className="text-center">
        <h2 className="text-2xl font-bold mb-4">Failed to load product</h2>
        <p className="text-gray-600 mb-4">
          {error.message || 'An unexpected error occurred'}
        </p>
        <button
          onClick={reset}
          className="px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-600"
        >
          Try again
        </button>
      </div>
    </div>
  );
}
```

---

## Server-Side Rendering (SSR)

### 6. How does Server-Side Rendering work in Next.js?

**Answer:**
SSR renders pages on the server for each request:

```typescript
// Pages Router SSR
// pages/user/[id].tsx
import { GetServerSideProps } from 'next';

interface Props {
  user: User;
  timestamp: string;
}

export default function UserProfile({ user, timestamp }: Props) {
  return (
    <div>
      <h1>{user.name}</h1>
      <p>Profile loaded at: {timestamp}</p>
      {/* This content is rendered on server and sent to client */}
    </div>
  );
}

export const getServerSideProps: GetServerSideProps = async (context) => {
  const { req, res, params, query } = context;
  
  // Access to request/response objects
  const userAgent = req.headers['user-agent'];
  
  // Set custom headers
  res.setHeader('Cache-Control', 'public, s-maxage=10, stale-while-revalidate=59');
  
  try {
    const user = await fetchUser(params!.id as string);
    
    return {
      props: {
        user,
        timestamp: new Date().toISOString(),
      },
    };
  } catch (error) {
    return {
      notFound: true,
    };
  }
};

// App Router SSR (Server Components)
// app/user/[id]/page.tsx
async function getUser(id: string) {
  const res = await fetch(`${process.env.API_URL}/users/${id}`, {
    headers: {
      'Authorization': `Bearer ${process.env.API_TOKEN}`,
    },
    // No caching - always fetch fresh data (SSR behavior)
    cache: 'no-store'
  });
  
  if (!res.ok) {
    throw new Error('Failed to fetch user');
  }
  
  return res.json();
}

export default async function UserProfile({ 
  params 
}: { 
  params: { id: string } 
}) {
  const user = await getUser(params.id);
  
  return (
    <div>
      <h1>{user.name}</h1>
      <p>Profile loaded at: {new Date().toISOString()}</p>
    </div>
  );
}

// When to use SSR:
// 1. User-specific content
// 2. Data that changes frequently
// 3. Content that depends on request (cookies, headers)
// 4. Real-time data
// 5. Personalized experiences

// Authentication with SSR
export const getServerSideProps: GetServerSideProps = async (context) => {
  const { req } = context;
  
  // Check authentication
  const token = req.cookies.token;
  
  if (!token) {
    return {
      redirect: {
        destination: '/login',
        permanent: false,
      },
    };
  }
  
  try {
    const user = await verifyToken(token);
    const dashboardData = await fetchDashboardData(user.id);
    
    return {
      props: {
        user,
        dashboardData,
      },
    };
  } catch (error) {
    return {
      redirect: {
        destination: '/login',
        permanent: false,
      },
    };
  }
};
```

### 7. How do you implement authentication with SSR?

**Answer:**
Authentication patterns for server-side rendering:

```typescript
// 1. Cookie-based authentication
// lib/auth.ts
import { GetServerSidePropsContext } from 'next';
import jwt from 'jsonwebtoken';

export function getTokenFromRequest(context: GetServerSidePropsContext) {
  const { req } = context;
  return req.cookies.token || req.headers.authorization?.replace('Bearer ', '');
}

export async function verifyAuth(context: GetServerSidePropsContext) {
  const token = getTokenFromRequest(context);
  
  if (!token) {
    return { isAuthenticated: false, user: null };
  }
  
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET!) as any;
    const user = await getUserById(decoded.userId);
    return { isAuthenticated: true, user };
  } catch (error) {
    return { isAuthenticated: false, user: null };
  }
}

// pages/dashboard.tsx
export const getServerSideProps: GetServerSideProps = async (context) => {
  const { isAuthenticated, user } = await verifyAuth(context);
  
  if (!isAuthenticated) {
    return {
      redirect: {
        destination: '/login',
        permanent: false,
      },
    };
  }
  
  const dashboardData = await fetchDashboardData(user.id);
  
  return {
    props: {
      user,
      dashboardData,
    },
  };
};

// 2. HOC for authentication
// hoc/withAuth.tsx
export function withAuth<T>(
  WrappedComponent: React.ComponentType<T>,
  options: { requireAuth: boolean } = { requireAuth: true }
) {
  return function AuthenticatedComponent(props: T) {
    return <WrappedComponent {...props} />;
  };
}

export const getServerSideProps = (
  innerGetServerSideProps?: GetServerSideProps
) => {
  return async (context: GetServerSidePropsContext) => {
    const { isAuthenticated, user } = await verifyAuth(context);
    
    if (!isAuthenticated) {
      return {
        redirect: {
          destination: '/login',
          permanent: false,
        },
      };
    }
    
    if (innerGetServerSideProps) {
      const result = await innerGetServerSideProps(context);
      
      if ('props' in result) {
        return {
          props: {
            ...result.props,
            user,
          },
        };
      }
      
      return result;
    }
    
    return {
      props: { user },
    };
  };
};

// Usage
// pages/protected-page.tsx
export default withAuth(function ProtectedPage({ user, data }) {
  return <div>Welcome, {user.name}!</div>;
});

export const getServerSideProps = getServerSideProps(async (context) => {
  const data = await fetchProtectedData();
  return { props: { data } };
});

// 3. App Router authentication
// app/dashboard/page.tsx
import { cookies } from 'next/headers';
import { redirect } from 'next/navigation';

async function getUser() {
  const cookieStore = cookies();
  const token = cookieStore.get('token');
  
  if (!token) {
    redirect('/login');
  }
  
  try {
    const user = await verifyToken(token.value);
    return user;
  } catch (error) {
    redirect('/login');
  }
}

export default async function Dashboard() {
  const user = await getUser();
  
  return (
    <div>
      <h1>Dashboard</h1>
      <p>Welcome, {user.name}!</p>
    </div>
  );
}
```

---

## Static Site Generation (SSG)

### 8. How does Static Site Generation work in Next.js?

**Answer:**
SSG pre-renders pages at build time for optimal performance:

```typescript
// Basic SSG
// pages/blog/index.tsx
import { GetStaticProps } from 'next';

interface Props {
  posts: BlogPost[];
}

export default function BlogIndex({ posts }: Props) {
  return (
    <div>
      <h1>Blog Posts</h1>
      {posts.map(post => (
        <article key={post.id}>
          <h2>{post.title}</h2>
          <p>{post.excerpt}</p>
        </article>
      ))}
    </div>
  );
}

export const getStaticProps: GetStaticProps = async () => {
  // This runs at build time
  const posts = await fetchBlogPosts();
  
  return {
    props: {
      posts,
    },
    // Optional: regenerate the page at most once every hour
    revalidate: 3600,
  };
};

// Dynamic SSG with getStaticPaths
// pages/blog/[slug].tsx
interface Props {
  post: BlogPost;
}

export default function BlogPost({ post }: Props) {
  return (
    <article>
      <h1>{post.title}</h1>
      <div dangerouslySetInnerHTML={{ __html: post.content }} />
    </article>
  );
}

export const getStaticPaths: GetStaticPaths = async () => {
  // Get all blog post slugs
  const posts = await fetchBlogPosts();
  
  const paths = posts.map(post => ({
    params: { slug: post.slug }
  }));
  
  return {
    paths,
    fallback: 'blocking', // or true, false
  };
};

export const getStaticProps: GetStaticProps = async ({ params }) => {
  const post = await fetchBlogPost(params!.slug as string);
  
  if (!post) {
    return {
      notFound: true,
    };
  }
  
  return {
    props: {
      post,
    },
    revalidate: 86400, // Regenerate once per day
  };
};

// Fallback strategies
export const getStaticPaths: GetStaticPaths = async () => {
  // Only pre-render most popular posts
  const popularPosts = await fetchPopularPosts();
  
  const paths = popularPosts.map(post => ({
    params: { slug: post.slug }
  }));
  
  return {
    paths,
    fallback: 'blocking', // Generate other pages on-demand
  };
};

// fallback: false - Only pre-rendered paths are valid
// fallback: true - Show loading state while generating
// fallback: 'blocking' - Wait for generation before showing page

// App Router SSG
// app/blog/page.tsx
async function getBlogPosts() {
  const res = await fetch('https://api.example.com/posts', {
    // Static generation (build time)
    cache: 'force-cache'
  });
  return res.json();
}

export default async function BlogPage() {
  const posts = await getBlogPosts();
  
  return (
    <div>
      {posts.map(post => (
        <article key={post.id}>
          <h2>{post.title}</h2>
        </article>
      ))}
    </div>
  );
}

// Dynamic SSG with generateStaticParams
// app/blog/[slug]/page.tsx
export async function generateStaticParams() {
  const posts = await fetchBlogPosts();
  
  return posts.map(post => ({
    slug: post.slug,
  }));
}

export default async function BlogPost({ 
  params 
}: { 
  params: { slug: string } 
}) {
  const post = await fetchBlogPost(params.slug);
  
  return (
    <article>
      <h1>{post.title}</h1>
      <div dangerouslySetInnerHTML={{ __html: post.content }} />
    </article>
  );
}
```

### 9. What is Incremental Static Regeneration (ISR)?

**Answer:**
ISR allows you to update static content without rebuilding the entire site:

```typescript
// Basic ISR
// pages/products/[id].tsx
export const getStaticProps: GetStaticProps = async ({ params }) => {
  const product = await fetchProduct(params!.id as string);
  
  return {
    props: {
      product,
    },
    // Regenerate the page at most once every 60 seconds
    revalidate: 60,
  };
};

// On-demand revalidation
// pages/api/revalidate.ts
import { NextApiRequest, NextApiResponse } from 'next';

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  // Check for secret to confirm this is a valid request
  if (req.query.secret !== process.env.REVALIDATE_SECRET) {
    return res.status(401).json({ message: 'Invalid token' });
  }
  
  try {
    // Revalidate specific paths
    await res.revalidate('/');
    await res.revalidate('/products');
    await res.revalidate(`/products/${req.query.id}`);
    
    return res.json({ revalidated: true });
  } catch (err) {
    return res.status(500).send('Error revalidating');
  }
}

// Webhook integration for automatic revalidation
// pages/api/webhook/product-updated.ts
export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.method !== 'POST') {
    return res.status(405).json({ message: 'Method not allowed' });
  }
  
  // Verify webhook signature
  const signature = req.headers['x-signature'];
  if (!verifyWebhookSignature(req.body, signature)) {
    return res.status(401).json({ message: 'Invalid signature' });
  }
  
  const { productId, action } = req.body;
  
  try {
    if (action === 'updated' || action === 'created') {
      // Revalidate product page
      await res.revalidate(`/products/${productId}`);
      // Revalidate product list
      await res.revalidate('/products');
    } else if (action === 'deleted') {
      // Revalidate list but not individual page
      await res.revalidate('/products');
    }
    
    return res.json({ revalidated: true });
  } catch (err) {
    return res.status(500).json({ error: 'Failed to revalidate' });
  }
}

// App Router ISR
// app/products/[id]/page.tsx
async function getProduct(id: string) {
  const res = await fetch(`https://api.example.com/products/${id}`, {
    next: { 
      revalidate: 3600, // Revalidate every hour
      tags: ['product', `product-${id}`] // For targeted revalidation
    }
  });
  return res.json();
}

export default async function ProductPage({ 
  params 
}: { 
  params: { id: string } 
}) {
  const product = await getProduct(params.id);
  
  return (
    <div>
      <h1>{product.name}</h1>
      <p>{product.description}</p>
      <p>Last updated: {new Date().toISOString()}</p>
    </div>
  );
}

// On-demand revalidation with tags
// app/api/revalidate/route.ts
import { revalidateTag, revalidatePath } from 'next/cache';
import { NextRequest } from 'next/server';

export async function POST(request: NextRequest) {
  const { tag, path } = await request.json();
  
  if (tag) {
    revalidateTag(tag);
  }
  
  if (path) {
    revalidatePath(path);
  }
  
  return Response.json({ revalidated: true, now: Date.now() });
}

// ISR with fallback handling
export const getStaticPaths: GetStaticPaths = async () => {
  // Pre-generate only the most popular products
  const popularProducts = await fetchPopularProducts();
  
  const paths = popularProducts.map(product => ({
    params: { id: product.id.toString() }
  }));
  
  return {
    paths,
    fallback: 'blocking', // Generate other products on first request
  };
};

export const getStaticProps: GetStaticProps = async ({ params }) => {
  try {
    const product = await fetchProduct(params!.id as string);
    
    return {
      props: {
        product,
      },
      revalidate: 300, // 5 minutes
    };
  } catch (error) {
    // If product doesn't exist, show 404
    return {
      notFound: true,
      revalidate: 60, // Try again in 1 minute
    };
  }
};
```

---

## API Routes

### 10. How do you create and handle API routes in Next.js?

**Answer:**
Next.js provides built-in API routes for backend functionality:

```typescript
// Pages Router API Routes
// pages/api/users.ts
import { NextApiRequest, NextApiResponse } from 'next';

interface User {
  id: number;
  name: string;
  email: string;
}

export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse
) {
  const { method } = req;
  
  switch (method) {
    case 'GET':
      try {
        const users = await getUsers();
        res.status(200).json(users);
      } catch (error) {
        res.status(500).json({ error: 'Failed to fetch users' });
      }
      break;
      
    case 'POST':
      try {
        const { name, email } = req.body;
        
        // Validation
        if (!name || !email) {
          return res.status(400).json({ error: 'Name and email are required' });
        }
        
        const user = await createUser({ name, email });
        res.status(201).json(user);
      } catch (error) {
        res.status(500).json({ error: 'Failed to create user' });
      }
      break;
      
    default:
      res.setHeader('Allow', ['GET', 'POST']);
      res.status(405).end(`Method ${method} Not Allowed`);
  }
}

// Dynamic API routes
// pages/api/users/[id].ts
export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse
) {
  const { id, method } = req;
  const userId = Array.isArray(id) ? id[0] : id;
  
  switch (method) {
    case 'GET':
      const user = await getUserById(userId);
      if (!user) {
        return res.status(404).json({ error: 'User not found' });
      }
      res.status(200).json(user);
      break;
      
    case 'PUT':
      const updatedUser = await updateUser(userId, req.body);
      res.status(200).json(updatedUser);
      break;
      
    case 'DELETE':
      await deleteUser(userId);
      res.status(204).end();
      break;
      
    default:
      res.setHeader('Allow', ['GET', 'PUT', 'DELETE']);
      res.status(405).end(`Method ${method} Not Allowed`);
  }
}

// App Router API Routes
// app/api/users/route.ts
import { NextRequest, NextResponse } from 'next/server';

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url);
    const page = searchParams.get('page') || '1';
    const limit = searchParams.get('limit') || '10';
    
    const users = await getUsers({
      page: parseInt(page),
      limit: parseInt(limit)
    });
    
    return NextResponse.json(users);
  } catch (error) {
    return NextResponse.json(
      { error: 'Failed to fetch users' },
      { status: 500 }
    );
  }
}

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const { name, email } = body;
    
    // Validation
    if (!name || !email) {
      return NextResponse.json(
        { error: 'Name and email are required' },
        { status: 400 }
      );
    }
    
    const user = await createUser({ name, email });
    
    return NextResponse.json(user, { status: 201 });
  } catch (error) {
    return NextResponse.json(
      { error: 'Failed to create user' },
      { status: 500 }
    );
  }
}

// Dynamic API routes
// app/api/users/[id]/route.ts
interface RouteParams {
  params: { id: string };
}

export async function GET(
  request: NextRequest,
  { params }: RouteParams
) {
  try {
    const user = await getUserById(params.id);
    
    if (!user) {
      return NextResponse.json(
        { error: 'User not found' },
        { status: 404 }
      );
    }
    
    return NextResponse.json(user);
  } catch (error) {
    return NextResponse.json(
      { error: 'Failed to fetch user' },
      { status: 500 }
    );
  }
}

export async function PUT(
  request: NextRequest,
  { params }: RouteParams
) {
  try {
    const body = await request.json();
    const updatedUser = await updateUser(params.id, body);
    
    return NextResponse.json(updatedUser);
  } catch (error) {
    return NextResponse.json(
      { error: 'Failed to update user' },
      { status: 500 }
    );
  }
}

export async function DELETE(
  request: NextRequest,
  { params }: RouteParams
) {
  try {
    await deleteUser(params.id);
    return new NextResponse(null, { status: 204 });
  } catch (error) {
    return NextResponse.json(
      { error: 'Failed to delete user' },
      { status: 500 }
    );
  }
}

// Middleware for API routes
// middleware.ts
import { NextRequest, NextResponse } from 'next/server';

export function middleware(request: NextRequest) {
  // API routes middleware
  if (request.nextUrl.pathname.startsWith('/api/')) {
    // Add CORS headers
    const response = NextResponse.next();
    
    response.headers.set('Access-Control-Allow-Origin', '*');
    response.headers.set('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
    response.headers.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    
    // Handle preflight requests
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 200, headers: response.headers });
    }
    
    return response;
  }
}

export const config = {
  matcher: '/api/:path*',
};
```

### 11. How do you handle authentication in API routes?

**Answer:**
Authentication patterns for API routes:

```typescript
// JWT Authentication Middleware
// lib/auth-middleware.ts
import jwt from 'jsonwebtoken';
import { NextApiRequest, NextApiResponse } from 'next';

export interface AuthenticatedRequest extends NextApiRequest {
  user: {
    id: string;
    email: string;
    role: string;
  };
}

export function withAuth(
  handler: (req: AuthenticatedRequest, res: NextApiResponse) => Promise<void>
) {
  return async (req: NextApiRequest, res: NextApiResponse) => {
    try {
      const token = req.headers.authorization?.replace('Bearer ', '');
      
      if (!token) {
        return res.status(401).json({ error: 'No token provided' });
      }
      
      const decoded = jwt.verify(token, process.env.JWT_SECRET!) as any;
      const user = await getUserById(decoded.userId);
      
      if (!user) {
        return res.status(401).json({ error: 'Invalid token' });
      }
      
      (req as AuthenticatedRequest).user = user;
      return handler(req as AuthenticatedRequest, res);
    } catch (error) {
      return res.status(401).json({ error: 'Invalid token' });
    }
  };
}

// Role-based authorization
export function withRole(roles: string[]) {
  return function (
    handler: (req: AuthenticatedRequest, res: NextApiResponse) => Promise<void>
  ) {
    return withAuth(async (req, res) => {
      if (!roles.includes(req.user.role)) {
        return res.status(403).json({ error: 'Insufficient permissions' });
      }
      
      return handler(req, res);
    });
  };
}

// Usage in API routes
// pages/api/admin/users.ts
export default withRole(['admin'])(async (req, res) => {
  switch (req.method) {
    case 'GET':
      const users = await getAllUsers();
      res.status(200).json(users);
      break;
      
    case 'DELETE':
      const { userId } = req.body;
      await deleteUser(userId);
      res.status(204).end();
      break;
      
    default:
      res.status(405).json({ error: 'Method not allowed' });
  }
});

// App Router Authentication
// lib/auth.ts
import { NextRequest } from 'next/server';
import { headers } from 'next/headers';

export async function getAuthUser() {
  const headersList = headers();
  const authorization = headersList.get('authorization');
  
  if (!authorization) {
    throw new Error('No authorization header');
  }
  
  const token = authorization.replace('Bearer ', '');
  const decoded = jwt.verify(token, process.env.JWT_SECRET!) as any;
  const user = await getUserById(decoded.userId);
  
  if (!user) {
    throw new Error('Invalid token');
  }
  
  return user;
}

// app/api/protected/route.ts
export async function GET() {
  try {
    const user = await getAuthUser();
    
    const data = await getProtectedData(user.id);
    
    return NextResponse.json(data);
  } catch (error) {
    return NextResponse.json(
      { error: 'Unauthorized' },
      { status: 401 }
    );
  }
}

// Session-based authentication
// pages/api/auth/login.ts
import { serialize } from 'cookie';

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }
  
  const { email, password } = req.body;
  
  try {
    const user = await authenticateUser(email, password);
    
    if (!user) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }
    
    // Create session
    const sessionId = await createSession(user.id);
    
    // Set HTTP-only cookie
    const cookie = serialize('sessionId', sessionId, {
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'strict',
      maxAge: 60 * 60 * 24 * 7, // 1 week
      path: '/',
    });
    
    res.setHeader('Set-Cookie', cookie);
    res.status(200).json({ user: { id: user.id, email: user.email } });
  } catch (error) {
    res.status(500).json({ error: 'Login failed' });
  }
}

// Session validation middleware
export function withSession(
  handler: (req: AuthenticatedRequest, res: NextApiResponse) => Promise<void>
) {
  return async (req: NextApiRequest, res: NextApiResponse) => {
    const sessionId = req.cookies.sessionId;
    
    if (!sessionId) {
      return res.status(401).json({ error: 'No session' });
    }
    
    try {
      const session = await getSession(sessionId);
      
      if (!session || session.expiresAt < new Date()) {
        return res.status(401).json({ error: 'Invalid session' });
      }
      
      const user = await getUserById(session.userId);
      (req as AuthenticatedRequest).user = user;
      
      return handler(req as AuthenticatedRequest, res);
    } catch (error) {
      return res.status(401).json({ error: 'Invalid session' });
    }
  };
}
```

---

## Performance & Optimization

### 12. How do you optimize performance in Next.js applications?

**Answer:**
Multiple strategies for optimizing Next.js performance:

```typescript
// 1. Image Optimization
import Image from 'next/image';

export default function ProductGallery({ product }: { product: Product }) {
  return (
    <div>
      {/* Automatic optimization, lazy loading, WebP conversion */}
      <Image
        src={product.imageUrl}
        alt={product.name}
        width={600}
        height={400}
        priority={true} // Load immediately for above-fold content
        placeholder="blur"
        blurDataURL="data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD..."
      />
      
      {/* Responsive images */}
      <Image
        src={product.thumbnailUrl}
        alt={product.name}
        fill
        sizes="(max-width: 768px) 100vw, (max-width: 1200px) 50vw, 33vw"
        className="object-cover"
      />
    </div>
  );
}

// 2. Dynamic Imports and Code Splitting
import dynamic from 'next/dynamic';
import { Suspense } from 'react';

// Component-level code splitting
const DynamicChart = dynamic(() => import('../components/Chart'), {
  loading: () => <div>Loading chart...</div>,
  ssr: false, // Disable SSR for client-only components
});

// Feature-based splitting
const AdminPanel = dynamic(() => import('../components/AdminPanel'), {
  loading: () => <div>Loading admin panel...</div>,
});

export default function Dashboard({ user }: { user: User }) {
  return (
    <div>
      <h1>Dashboard</h1>
      
      {/* Always loaded */}
      <UserProfile user={user} />
      
      {/* Loaded when needed */}
      <Suspense fallback={<div>Loading chart...</div>}>
        <DynamicChart data={user.chartData} />
      </Suspense>
      
      {/* Conditional loading */}
      {user.role === 'admin' && <AdminPanel />}
    </div>
  );
}

// 3. Bundle Analysis and Optimization
// next.config.js
/** @type {import('next').NextConfig} */
const nextConfig = {
  // Bundle analyzer
  webpack: (config, { isServer }) => {
    if (process.env.ANALYZE === 'true') {
      const { BundleAnalyzerPlugin } = require('webpack-bundle-analyzer');
      config.plugins.push(
        new BundleAnalyzerPlugin({
          analyzerMode: 'static',
          openAnalyzer: false,
        })
      );
    }
    
    // Optimize bundle
    if (!isServer) {
      config.resolve.fallback = {
        ...config.resolve.fallback,
        fs: false,
        net: false,
        tls: false,
      };
    }
    
    return config;
  },
  
  // Experimental features for performance
  experimental: {
    optimizeCss: true,
    modularizeImports: {
      lodash: {
        transform: 'lodash/{{member}}',
      },
    },
  },
  
  // Compress responses
  compress: true,
  
  // Optimize fonts
  optimizeFonts: true,
};

// 4. Caching Strategies
// API route with caching
export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  // Set cache headers
  res.setHeader(
    'Cache-Control',
    'public, s-maxage=60, stale-while-revalidate=300'
  );
  
  const data = await fetchExpensiveData();
  res.status(200).json(data);
}

// App Router caching
async function getProducts() {
  const res = await fetch('https://api.example.com/products', {
    next: {
      revalidate: 3600, // Cache for 1 hour
      tags: ['products'],
    },
  });
  return res.json();
}

// 5. Database Query Optimization
// Parallel data fetching
export const getStaticProps: GetStaticProps = async () => {
  // Parallel execution instead of sequential
  const [posts, categories, tags] = await Promise.all([
    fetchPosts(),
    fetchCategories(),
    fetchTags(),
  ]);
  
  return {
    props: {
      posts,
      categories,
      tags,
    },
    revalidate: 3600,
  };
};

// 6. Font Optimization
// app/layout.tsx
import { Inter, Roboto_Mono } from 'next/font/google';

const inter = Inter({
  subsets: ['latin'],
  display: 'swap',
  variable: '--font-inter',
});

const robotoMono = Roboto_Mono({
  subsets: ['latin'],
  display: 'swap',
  variable: '--font-roboto-mono',
});

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en" className={`${inter.variable} ${robotoMono.variable}`}>
      <body className="font-sans">{children}</body>
    </html>
  );
}

// 7. Memory Management
// Cleanup in useEffect
useEffect(() => {
  const interval = setInterval(() => {
    // Some recurring task
  }, 1000);
  
  return () => {
    clearInterval(interval); // Cleanup
  };
}, []);

// Abort fetch requests
useEffect(() => {
  const abortController = new AbortController();
  
  fetch('/api/data', {
    signal: abortController.signal,
  })
    .then(res => res.json())
    .then(setData)
    .catch(error => {
      if (error.name !== 'AbortError') {
        console.error('Fetch error:', error);
      }
    });
  
  return () => {
    abortController.abort(); // Cancel ongoing requests
  };
}, []);

// 8. Preloading and Prefetching
import Link from 'next/link';
import { useRouter } from 'next/router';

export default function Navigation() {
  const router = useRouter();
  
  // Programmatic prefetching
  useEffect(() => {
    router.prefetch('/dashboard');
  }, [router]);
  
  return (
    <nav>
      {/* Automatic prefetching */}
      <Link href="/products" prefetch={true}>
        Products
      </Link>
      
      {/* Prefetch only on hover */}
      <Link href="/about" prefetch={false}>
        About
      </Link>
    </nav>
  );
}
```

---

## Deployment & Production

### 13. How do you deploy Next.js applications?

**Answer:**
Multiple deployment strategies for Next.js applications:

```typescript
// 1. Vercel Deployment (Recommended)
// vercel.json
{
  "version": 2,
  "build": {
    "env": {
      "NEXT_PUBLIC_API_URL": "https://api.example.com"
    }
  },
  "env": {
    "DATABASE_URL": "@database-url",
    "JWT_SECRET": "@jwt-secret"
  },
  "regions": ["sfo1", "lhr1"],
  "functions": {
    "app/api/**/*.ts": {
      "runtime": "nodejs18.x"
    }
  },
  "redirects": [
    {
      "source": "/old-path",
      "destination": "/new-path",
      "permanent": true
    }
  ],
  "headers": [
    {
      "source": "/api/(.*)",
      "headers": [
        {
          "key": "Access-Control-Allow-Origin",
          "value": "*"
        }
      ]
    }
  ]
}

// 2. Docker Deployment
// Dockerfile
FROM node:18-alpine AS base

# Install dependencies only when needed
FROM base AS deps
RUN apk add --no-cache libc6-compat
WORKDIR /app

# Install dependencies based on the preferred package manager
COPY package.json yarn.lock* package-lock.json* pnpm-lock.yaml* ./
RUN \
  if [ -f yarn.lock ]; then yarn --frozen-lockfile; \
  elif [ -f package-lock.json ]; then npm ci; \
  elif [ -f pnpm-lock.yaml ]; then yarn global add pnpm && pnpm i --frozen-lockfile; \
  else echo "Lockfile not found." && exit 1; \
  fi

# Rebuild the source code only when needed
FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

ENV NEXT_TELEMETRY_DISABLED 1

RUN yarn build

# Production image, copy all the files and run next
FROM base AS runner
WORKDIR /app

ENV NODE_ENV production
ENV NEXT_TELEMETRY_DISABLED 1

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

COPY --from=builder /app/public ./public

# Set the correct permission for prerender cache
RUN mkdir .next
RUN chown nextjs:nodejs .next

# Automatically leverage output traces to reduce image size
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs

EXPOSE 3000

ENV PORT 3000
ENV HOSTNAME "0.0.0.0"

CMD ["node", "server.js"]

// docker-compose.yml
version: '3.8'

services:
  nextjs:
    build:
      context: .
      dockerfile: Dockerfile
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
      - DATABASE_URL=${DATABASE_URL}
      - JWT_SECRET=${JWT_SECRET}
    depends_on:
      - postgres
    restart: unless-stopped

  postgres:
    image: postgres:15
    environment:
      - POSTGRES_DB=myapp
      - POSTGRES_USER=user
      - POSTGRES_PASSWORD=password
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  postgres_data:

// 3. Static Export
// next.config.js
/** @type {import('next').NextConfig} */
const nextConfig = {
  output: 'export',
  trailingSlash: true,
  images: {
    unoptimized: true, // Required for static export
  },
};

module.exports = nextConfig;

// Build script for static export
// package.json
{
  "scripts": {
    "build": "next build",
    "export": "next build && next export",
    "deploy": "npm run export && aws s3 sync out/ s3://my-bucket --delete"
  }
}

// 4. Environment Configuration
// next.config.js
/** @type {import('next').NextConfig} */
const nextConfig = {
  env: {
    CUSTOM_KEY: process.env.CUSTOM_KEY,
  },
  publicRuntimeConfig: {
    staticFolder: '/static',
  },
  serverRuntimeConfig: {
    mySecret: 'secret',
    secondSecret: process.env.SECOND_SECRET,
  },
};

// .env.local (development)
NEXT_PUBLIC_API_URL=http://localhost:3001
DATABASE_URL=postgresql://user:password@localhost:5432/myapp
JWT_SECRET=your-secret-key

// .env.production (production)
NEXT_PUBLIC_API_URL=https://api.myapp.com
DATABASE_URL=postgresql://user:password@prod-host:5432/myapp
JWT_SECRET=production-secret-key

// Environment validation
// lib/env.ts
import { z } from 'zod';

const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'production', 'test']),
  DATABASE_URL: z.string().url(),
  JWT_SECRET: z.string().min(32),
  NEXT_PUBLIC_API_URL: z.string().url(),
});

export const env = envSchema.parse(process.env);

// 5. CI/CD Pipeline
// .github/workflows/deploy.yml
name: Deploy to Production

on:
  push:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'
          cache: 'npm'
      
      - name: Install dependencies
        run: npm ci
      
      - name: Run tests
        run: npm test
      
      - name: Run linting
        run: npm run lint
      
      - name: Type check
        run: npm run type-check

  build-and-deploy:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'
          cache: 'npm'
      
      - name: Install dependencies
        run: npm ci
      
      - name: Build application
        run: npm run build
        env:
          NEXT_PUBLIC_API_URL: ${{ secrets.NEXT_PUBLIC_API_URL }}
      
      - name: Deploy to Vercel
        uses: amondnet/vercel-action@v20
        with:
          vercel-token: ${{ secrets.VERCEL_TOKEN }}
          vercel-org-id: ${{ secrets.ORG_ID }}
          vercel-project-id: ${{ secrets.PROJECT_ID }}
          vercel-args: '--prod'

// 6. Performance Monitoring
// lib/analytics.ts
export function reportWebVitals(metric: any) {
  // Send to analytics service
  if (process.env.NODE_ENV === 'production') {
    console.log(metric);
    
    // Example: Send to Google Analytics
    if (typeof window !== 'undefined' && window.gtag) {
      window.gtag('event', metric.name, {
        event_category: 'Web Vitals',
        event_label: metric.id,
        value: Math.round(metric.name === 'CLS' ? metric.value * 1000 : metric.value),
        non_interaction: true,
      });
    }
  }
}

// pages/_app.tsx
import { reportWebVitals } from '../lib/analytics';

export { reportWebVitals };

// 7. Health Checks and Monitoring
// pages/api/health.ts
export default function handler(req: NextApiRequest, res: NextApiResponse) {
  // Check database connection
  const dbStatus = checkDatabaseConnection();
  
  // Check external services
  const serviceStatuses = checkExternalServices();
  
  const healthCheck = {
    status: 'ok',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    environment: process.env.NODE_ENV,
    version: process.env.npm_package_version,
    database: dbStatus,
    services: serviceStatuses,
  };
  
  const statusCode = healthCheck.status === 'ok' ? 200 : 503;
  res.status(statusCode).json(healthCheck);
}
```

---

## Navigation Links

⬅️ **[Previous: React Questions](./react-questions.md)**  
➡️ **[Next: Node.js Questions](./nodejs-questions.md)**  
🏠 **[Home: Dev Partners Interview Questions](./README.md)**

---

*Next.js interview questions compiled for Dev Partners Senior Full Stack Developer position - focusing on SSR, SSG, API routes, performance optimization, and deployment strategies.*
