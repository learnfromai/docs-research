# PostgreSQL Interview Questions & Answers

## Basic PostgreSQL Concepts

### 1. What is PostgreSQL and what are its key features?

**Answer:**
PostgreSQL is an advanced, open-source object-relational database management system (ORDBMS) that emphasizes extensibility and SQL compliance. It's known for its reliability, feature robustness, and performance.

**Key Features:**

```sql
-- 1. ACID Compliance (Atomicity, Consistency, Isolation, Durability)
BEGIN;
    INSERT INTO users (name, email) VALUES ('John Doe', 'john@example.com');
    UPDATE accounts SET balance = balance - 100 WHERE user_id = 1;
    UPDATE accounts SET balance = balance + 100 WHERE user_id = 2;
COMMIT; -- All operations succeed or all fail

-- 2. Complex Data Types
CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    tags TEXT[], -- Array type
    metadata JSONB, -- JSON Binary type
    price NUMERIC(10,2),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    coordinates POINT, -- Geometric type
    search_vector TSVECTOR -- Full-text search type
);

-- 3. Advanced Indexing
CREATE INDEX idx_products_tags ON products USING GIN(tags); -- Array index
CREATE INDEX idx_products_metadata ON products USING GIN(metadata); -- JSON index
CREATE INDEX idx_products_search ON products USING GIN(search_vector); -- Text search
CREATE INDEX idx_products_location ON products USING GIST(coordinates); -- Spatial index

-- 4. Window Functions
SELECT 
    name,
    price,
    AVG(price) OVER (PARTITION BY category) as avg_category_price,
    ROW_NUMBER() OVER (ORDER BY price DESC) as price_rank,
    LAG(price) OVER (ORDER BY created_at) as previous_price
FROM products;

-- 5. Common Table Expressions (CTEs) and Recursive Queries
WITH RECURSIVE employee_hierarchy AS (
    -- Base case
    SELECT id, name, manager_id, 1 as level
    FROM employees 
    WHERE manager_id IS NULL
    
    UNION ALL
    
    -- Recursive case
    SELECT e.id, e.name, e.manager_id, eh.level + 1
    FROM employees e
    INNER JOIN employee_hierarchy eh ON e.manager_id = eh.id
)
SELECT * FROM employee_hierarchy ORDER BY level, name;

-- 6. Custom Functions and Stored Procedures
CREATE OR REPLACE FUNCTION calculate_age(birth_date DATE)
RETURNS INTEGER AS $$
BEGIN
    RETURN EXTRACT(YEAR FROM AGE(birth_date));
END;
$$ LANGUAGE plpgsql;

-- Usage
SELECT name, calculate_age(birth_date) as age FROM users;

-- 7. Triggers
CREATE OR REPLACE FUNCTION update_modified_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_modified_column();
```

**Advantages:**

- **ACID compliance** with strong consistency
- **Extensible** with custom functions, operators, and data types
- **Standards compliant** with comprehensive SQL support
- **High performance** with advanced query optimization
- **Concurrent access** with Multi-Version Concurrency Control (MVCC)
- **Cross-platform** support
- **Strong community** and extensive documentation

**Common Use Cases:**

- **Web applications** requiring complex queries
- **Data warehousing** and analytics
- **Geographic information systems** (PostGIS extension)
- **Financial applications** requiring ACID compliance
- **Content management systems**
- **Time-series data** analysis

### 2. Explain different types of relationships in PostgreSQL with examples

**Answer:**
PostgreSQL supports various relationship types that define how tables connect to each other through foreign keys and constraints.

```sql
-- 1. ONE-TO-ONE RELATIONSHIP
-- Each user has exactly one profile, and each profile belongs to one user

CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE user_profiles (
    id SERIAL PRIMARY KEY,
    user_id INTEGER UNIQUE NOT NULL, -- UNIQUE ensures one-to-one
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    bio TEXT,
    avatar_url VARCHAR(500),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Query one-to-one relationship
SELECT u.email, p.first_name, p.last_name, p.bio
FROM users u
LEFT JOIN user_profiles p ON u.id = p.user_id;

-- 2. ONE-TO-MANY RELATIONSHIP
-- One user can have many posts, but each post belongs to one user

CREATE TABLE posts (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    title VARCHAR(255) NOT NULL,
    content TEXT,
    published BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT NOW(),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Query one-to-many with aggregation
SELECT 
    u.email,
    COUNT(p.id) as total_posts,
    COUNT(CASE WHEN p.published THEN 1 END) as published_posts
FROM users u
LEFT JOIN posts p ON u.id = p.user_id
GROUP BY u.id, u.email;

-- 3. MANY-TO-MANY RELATIONSHIP
-- Users can belong to many groups, and groups can have many users
-- Requires a junction/bridge table

CREATE TABLE groups (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE user_groups (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    group_id INTEGER NOT NULL,
    role VARCHAR(50) DEFAULT 'member', -- Additional relationship data
    joined_at TIMESTAMP DEFAULT NOW(),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (group_id) REFERENCES groups(id) ON DELETE CASCADE,
    UNIQUE(user_id, group_id) -- Prevent duplicate memberships
);

-- Query many-to-many relationship
SELECT 
    u.email,
    g.name as group_name,
    ug.role,
    ug.joined_at
FROM users u
JOIN user_groups ug ON u.id = ug.user_id
JOIN groups g ON ug.group_id = g.id
ORDER BY u.email, g.name;

-- 4. SELF-REFERENCING RELATIONSHIP
-- Hierarchical data where records reference other records in the same table

CREATE TABLE categories (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    parent_id INTEGER,
    level INTEGER DEFAULT 0,
    path VARCHAR(500), -- Materialized path for faster queries
    FOREIGN KEY (parent_id) REFERENCES categories(id) ON DELETE SET NULL
);

-- Insert hierarchical data
INSERT INTO categories (name, parent_id, level, path) VALUES
('Electronics', NULL, 0, '/electronics'),
('Computers', 1, 1, '/electronics/computers'),
('Laptops', 2, 2, '/electronics/computers/laptops'),
('Gaming Laptops', 3, 3, '/electronics/computers/laptops/gaming');

-- Query hierarchy with CTE
WITH RECURSIVE category_tree AS (
    -- Root categories
    SELECT id, name, parent_id, 0 as depth, name as full_path
    FROM categories 
    WHERE parent_id IS NULL
    
    UNION ALL
    
    -- Child categories
    SELECT c.id, c.name, c.parent_id, ct.depth + 1, 
           ct.full_path || ' > ' || c.name
    FROM categories c
    JOIN category_tree ct ON c.parent_id = ct.id
)
SELECT id, name, depth, full_path FROM category_tree ORDER BY full_path;

-- 5. POLYMORPHIC RELATIONSHIPS
-- One table relates to multiple other tables

CREATE TABLE comments (
    id SERIAL PRIMARY KEY,
    content TEXT NOT NULL,
    commentable_type VARCHAR(50) NOT NULL, -- 'post' or 'product'
    commentable_id INTEGER NOT NULL,
    user_id INTEGER NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    FOREIGN KEY (user_id) REFERENCES users(id),
    INDEX (commentable_type, commentable_id)
);

CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    price DECIMAL(10,2),
    description TEXT
);

-- Query polymorphic relationships
SELECT 
    c.content,
    c.commentable_type,
    CASE 
        WHEN c.commentable_type = 'post' THEN p.title
        WHEN c.commentable_type = 'product' THEN pr.name
    END as item_name,
    u.email as commenter
FROM comments c
JOIN users u ON c.user_id = u.id
LEFT JOIN posts p ON c.commentable_type = 'post' AND c.commentable_id = p.id
LEFT JOIN products pr ON c.commentable_type = 'product' AND c.commentable_id = pr.id;

-- 6. ADVANCED RELATIONSHIP PATTERNS

-- Temporal relationships (tracking changes over time)
CREATE TABLE user_roles (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    role VARCHAR(50) NOT NULL,
    valid_from TIMESTAMP NOT NULL DEFAULT NOW(),
    valid_to TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id),
    CHECK (valid_to IS NULL OR valid_to > valid_from)
);

-- Query current roles
SELECT u.email, ur.role
FROM users u
JOIN user_roles ur ON u.id = ur.user_id
WHERE ur.valid_from <= NOW() 
  AND (ur.valid_to IS NULL OR ur.valid_to > NOW());

-- Weighted relationships
CREATE TABLE friendships (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    friend_id INTEGER NOT NULL,
    strength DECIMAL(3,2) DEFAULT 1.0, -- Relationship strength
    created_at TIMESTAMP DEFAULT NOW(),
    FOREIGN KEY (user_id) REFERENCES users(id),
    FOREIGN KEY (friend_id) REFERENCES users(id),
    CHECK (user_id != friend_id), -- Users can't be friends with themselves
    UNIQUE(user_id, friend_id)
);

-- Bidirectional friendship query
WITH mutual_friendships AS (
    SELECT LEAST(user_id, friend_id) as user1,
           GREATEST(user_id, friend_id) as user2,
           AVG(strength) as avg_strength
    FROM friendships
    GROUP BY LEAST(user_id, friend_id), GREATEST(user_id, friend_id)
    HAVING COUNT(*) = 2 -- Both users must have friended each other
)
SELECT 
    u1.email as user1_email,
    u2.email as user2_email,
    mf.avg_strength
FROM mutual_friendships mf
JOIN users u1 ON mf.user1 = u1.id
JOIN users u2 ON mf.user2 = u2.id;

-- 7. FOREIGN KEY CONSTRAINTS AND REFERENTIAL INTEGRITY

-- Cascade operations
ALTER TABLE posts 
ADD CONSTRAINT fk_posts_user 
FOREIGN KEY (user_id) REFERENCES users(id) 
ON DELETE CASCADE    -- Delete posts when user is deleted
ON UPDATE CASCADE;   -- Update post.user_id when user.id changes

-- Restrict operations
ALTER TABLE user_profiles 
ADD CONSTRAINT fk_profiles_user 
FOREIGN KEY (user_id) REFERENCES users(id) 
ON DELETE RESTRICT   -- Prevent user deletion if profile exists
ON UPDATE RESTRICT;

-- Set null on delete
ALTER TABLE posts 
ADD CONSTRAINT fk_posts_category 
FOREIGN KEY (category_id) REFERENCES categories(id) 
ON DELETE SET NULL;  -- Set category_id to NULL if category is deleted

-- Set default on delete
ALTER TABLE posts 
ADD CONSTRAINT fk_posts_status 
FOREIGN KEY (status_id) REFERENCES post_statuses(id) 
ON DELETE SET DEFAULT; -- Set to default status if current status is deleted
```

**Best Practices for Relationships:**

1. **Use appropriate foreign key constraints** to maintain data integrity
2. **Choose the right relationship type** based on business requirements
3. **Index foreign key columns** for better join performance
4. **Consider cascade operations carefully** to avoid unintended data loss
5. **Use junction tables** for many-to-many relationships with additional attributes
6. **Plan for hierarchical data** with recursive CTEs or materialized paths
7. **Document relationship rules** and constraints clearly

### 3. What are PostgreSQL indexes and how do you optimize them?

**Answer:**
Indexes are database objects that improve query performance by creating shortcuts to data. PostgreSQL supports multiple index types, each optimized for different use cases.

```sql
-- 1. B-TREE INDEXES (Default)
-- Best for equality and range queries, sorting

CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    order_date TIMESTAMP NOT NULL,
    total_amount DECIMAL(10,2),
    status VARCHAR(20) DEFAULT 'pending'
);

-- Single column B-tree index
CREATE INDEX idx_orders_user_id ON orders(user_id);
CREATE INDEX idx_orders_order_date ON orders(order_date);
CREATE INDEX idx_orders_status ON orders(status);

-- Composite B-tree index (column order matters!)
CREATE INDEX idx_orders_user_status ON orders(user_id, status);
CREATE INDEX idx_orders_date_status ON orders(order_date, status);

-- Queries that benefit from B-tree indexes
SELECT * FROM orders WHERE user_id = 123; -- Uses idx_orders_user_id
SELECT * FROM orders WHERE order_date > '2023-01-01'; -- Uses idx_orders_order_date
SELECT * FROM orders WHERE user_id = 123 AND status = 'completed'; -- Uses idx_orders_user_status

-- 2. HASH INDEXES
-- Best for equality comparisons only (PostgreSQL 10+)

CREATE INDEX idx_orders_status_hash ON orders USING HASH(status);

-- Only helps with equality
SELECT * FROM orders WHERE status = 'pending'; -- Can use hash index
-- SELECT * FROM orders WHERE status > 'pending'; -- Cannot use hash index

-- 3. GIN INDEXES (Generalized Inverted Indexes)
-- Best for array, JSON, and full-text search data

CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    tags TEXT[],
    metadata JSONB,
    description TEXT
);

-- Array index
CREATE INDEX idx_products_tags ON products USING GIN(tags);

-- JSON index
CREATE INDEX idx_products_metadata ON products USING GIN(metadata);

-- Full-text search index
CREATE INDEX idx_products_fts ON products USING GIN(to_tsvector('english', description));

-- Queries that benefit from GIN indexes
SELECT * FROM products WHERE tags @> ARRAY['electronics']; -- Array contains
SELECT * FROM products WHERE metadata @> '{"category": "laptop"}'; -- JSON contains
SELECT * FROM products WHERE to_tsvector('english', description) @@ to_tsquery('fast & computer');

-- 4. GIST INDEXES (Generalized Search Tree)
-- Best for geometric data, full-text search, and custom data types

-- Geometric data
CREATE TABLE locations (
    id SERIAL PRIMARY KEY,
    name TEXT,
    coordinates POINT
);

CREATE INDEX idx_locations_coords ON locations USING GIST(coordinates);

-- Find nearby locations
SELECT * FROM locations 
WHERE coordinates <-> POINT(40.7128, -74.0060) < 10; -- Within 10 units

-- 5. PARTIAL INDEXES
-- Index only rows that meet specific conditions

-- Only index active orders
CREATE INDEX idx_orders_active_user ON orders(user_id) 
WHERE status IN ('pending', 'processing');

-- Only index recent orders
CREATE INDEX idx_orders_recent ON orders(order_date) 
WHERE order_date > '2023-01-01';

-- Only index high-value orders
CREATE INDEX idx_orders_high_value ON orders(total_amount) 
WHERE total_amount > 1000;

-- 6. EXPRESSION INDEXES
-- Index based on expressions or function results

-- Index on computed values
CREATE INDEX idx_orders_year ON orders(EXTRACT(YEAR FROM order_date));
CREATE INDEX idx_orders_total_rounded ON orders(ROUND(total_amount));

-- Case-insensitive text search
CREATE INDEX idx_products_name_lower ON products(LOWER(name));

-- Query using expression index
SELECT * FROM orders WHERE EXTRACT(YEAR FROM order_date) = 2023;
SELECT * FROM products WHERE LOWER(name) = 'macbook pro';

-- 7. UNIQUE INDEXES
-- Enforce uniqueness while providing index benefits

CREATE UNIQUE INDEX idx_users_email ON users(email);
CREATE UNIQUE INDEX idx_products_sku ON products(sku) WHERE active = true;

-- Composite unique constraint
CREATE UNIQUE INDEX idx_user_groups_membership ON user_groups(user_id, group_id);

-- 8. INDEX OPTIMIZATION STRATEGIES

-- Analyze query performance
EXPLAIN (ANALYZE, BUFFERS) 
SELECT * FROM orders 
WHERE user_id = 123 AND status = 'completed' 
ORDER BY order_date DESC;

-- Monitor index usage
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_tup_read,
    idx_tup_fetch,
    idx_scan
FROM pg_stat_user_indexes 
ORDER BY idx_scan DESC;

-- Find unused indexes
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan
FROM pg_stat_user_indexes 
WHERE idx_scan = 0;

-- Check index sizes
SELECT 
    indexname,
    pg_size_pretty(pg_relation_size(indexname::regclass)) as size
FROM pg_indexes 
WHERE tablename = 'orders';

-- 9. ADVANCED INDEX TECHNIQUES

-- Covering indexes (include additional columns)
CREATE INDEX idx_orders_user_covering ON orders(user_id) 
INCLUDE (total_amount, order_date);

-- This query can be satisfied entirely from the index
SELECT user_id, total_amount, order_date 
FROM orders 
WHERE user_id = 123;

-- Concurrent index creation (doesn't block table)
CREATE INDEX CONCURRENTLY idx_orders_concurrent ON orders(status);

-- Index with custom operator class
CREATE INDEX idx_products_name_pattern ON products(name text_pattern_ops);

-- Better for LIKE queries with leading wildcards
SELECT * FROM products WHERE name LIKE 'Mac%';

-- 10. INDEX MAINTENANCE

-- Rebuild index if bloated
REINDEX INDEX idx_orders_user_id;

-- Rebuild all indexes on a table
REINDEX TABLE orders;

-- Update table statistics for better query planning
ANALYZE orders;

-- Auto-vacuum configuration for index maintenance
ALTER TABLE orders SET (
    autovacuum_vacuum_scale_factor = 0.1,
    autovacuum_analyze_scale_factor = 0.05
);

-- 11. PERFORMANCE TESTING AND MONITORING

-- Function to test index performance
CREATE OR REPLACE FUNCTION test_index_performance()
RETURNS TABLE(
    query_type TEXT,
    execution_time INTERVAL
) AS $$
DECLARE
    start_time TIMESTAMP;
    end_time TIMESTAMP;
BEGIN
    -- Test without index
    DROP INDEX IF EXISTS idx_test;
    
    start_time := clock_timestamp();
    PERFORM COUNT(*) FROM orders WHERE user_id = 123;
    end_time := clock_timestamp();
    
    query_type := 'Without Index';
    execution_time := end_time - start_time;
    RETURN NEXT;
    
    -- Test with index
    CREATE INDEX idx_test ON orders(user_id);
    
    start_time := clock_timestamp();
    PERFORM COUNT(*) FROM orders WHERE user_id = 123;
    end_time := clock_timestamp();
    
    query_type := 'With Index';
    execution_time := end_time - start_time;
    RETURN NEXT;
    
    DROP INDEX idx_test;
END;
$$ LANGUAGE plpgsql;

-- Monitor index efficiency
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_tup_read,
    idx_tup_fetch,
    ROUND(idx_tup_fetch::NUMERIC / NULLIF(idx_tup_read, 0) * 100, 2) as efficiency_percent
FROM pg_stat_user_indexes 
WHERE idx_tup_read > 0
ORDER BY efficiency_percent DESC;
```

**Index Best Practices:**

1. **Create indexes based on query patterns**, not just intuition
2. **Use composite indexes** with the most selective column first
3. **Consider partial indexes** for frequently filtered subsets
4. **Monitor index usage** and remove unused indexes
5. **Use EXPLAIN ANALYZE** to verify index effectiveness
6. **Balance read performance vs. write overhead**
7. **Maintain indexes** with regular VACUUM and ANALYZE
8. **Consider index-only scans** with covering indexes

### 4. How do you write complex queries with JOINs, subqueries, and CTEs?

**Answer:**
Complex queries in PostgreSQL involve combining multiple tables, filtering data with subqueries, and organizing logic with Common Table Expressions (CTEs).

```sql
-- Sample database schema for examples
CREATE TABLE customers (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(255) UNIQUE,
    registration_date DATE DEFAULT CURRENT_DATE,
    country VARCHAR(50),
    status VARCHAR(20) DEFAULT 'active'
);

CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    customer_id INTEGER REFERENCES customers(id),
    order_date DATE DEFAULT CURRENT_DATE,
    total_amount DECIMAL(10,2),
    status VARCHAR(20) DEFAULT 'pending',
    shipping_country VARCHAR(50)
);

CREATE TABLE order_items (
    id SERIAL PRIMARY KEY,
    order_id INTEGER REFERENCES orders(id),
    product_id INTEGER,
    quantity INTEGER,
    unit_price DECIMAL(10,2),
    discount_percent DECIMAL(5,2) DEFAULT 0
);

CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    category VARCHAR(100),
    price DECIMAL(10,2),
    stock_quantity INTEGER DEFAULT 0
);

-- 1. BASIC JOINS

-- INNER JOIN - Only matching records
SELECT 
    c.name as customer_name,
    o.order_date,
    o.total_amount,
    o.status
FROM customers c
INNER JOIN orders o ON c.id = o.customer_id
WHERE o.order_date >= '2023-01-01';

-- LEFT JOIN - All customers, even without orders
SELECT 
    c.name,
    c.email,
    COUNT(o.id) as total_orders,
    COALESCE(SUM(o.total_amount), 0) as total_spent
FROM customers c
LEFT JOIN orders o ON c.id = o.customer_id
GROUP BY c.id, c.name, c.email
ORDER BY total_spent DESC;

-- RIGHT JOIN - All orders, even with deleted customers
SELECT 
    COALESCE(c.name, 'Deleted Customer') as customer_name,
    o.order_date,
    o.total_amount
FROM customers c
RIGHT JOIN orders o ON c.id = o.customer_id;

-- FULL OUTER JOIN - All customers and all orders
SELECT 
    c.name,
    o.order_date,
    o.total_amount
FROM customers c
FULL OUTER JOIN orders o ON c.id = o.customer_id;

-- 2. MULTIPLE TABLE JOINS

-- Complex join with multiple tables
SELECT 
    c.name as customer_name,
    o.order_date,
    p.name as product_name,
    p.category,
    oi.quantity,
    oi.unit_price,
    (oi.quantity * oi.unit_price * (100 - oi.discount_percent) / 100) as line_total
FROM customers c
JOIN orders o ON c.id = o.customer_id
JOIN order_items oi ON o.id = oi.order_id
JOIN products p ON oi.product_id = p.id
WHERE o.status = 'completed'
  AND o.order_date >= '2023-01-01'
ORDER BY o.order_date DESC, c.name;

-- Self join - Find customers from the same country
SELECT 
    c1.name as customer1,
    c2.name as customer2,
    c1.country
FROM customers c1
JOIN customers c2 ON c1.country = c2.country AND c1.id < c2.id
WHERE c1.country IS NOT NULL
ORDER BY c1.country, c1.name;

-- 3. SUBQUERIES

-- Scalar subquery - Single value
SELECT 
    name,
    email,
    (SELECT COUNT(*) FROM orders WHERE customer_id = c.id) as order_count,
    (SELECT MAX(total_amount) FROM orders WHERE customer_id = c.id) as highest_order
FROM customers c
WHERE status = 'active';

-- EXISTS subquery - Check for existence
SELECT c.name, c.email
FROM customers c
WHERE EXISTS (
    SELECT 1 FROM orders o 
    WHERE o.customer_id = c.id 
      AND o.total_amount > 1000
);

-- NOT EXISTS - Customers without orders
SELECT c.name, c.email, c.registration_date
FROM customers c
WHERE NOT EXISTS (
    SELECT 1 FROM orders o WHERE o.customer_id = c.id
);

-- IN subquery - Multiple values
SELECT name, category, price
FROM products
WHERE category IN (
    SELECT DISTINCT category 
    FROM products 
    WHERE price > 100
);

-- Correlated subquery - References outer query
SELECT 
    c.name,
    c.email,
    (SELECT COUNT(*) 
     FROM orders o 
     WHERE o.customer_id = c.id 
       AND o.order_date > c.registration_date + INTERVAL '30 days'
    ) as orders_after_first_month
FROM customers c;

-- 4. COMMON TABLE EXPRESSIONS (CTEs)

-- Simple CTE
WITH high_value_customers AS (
    SELECT customer_id, SUM(total_amount) as total_spent
    FROM orders
    WHERE status = 'completed'
    GROUP BY customer_id
    HAVING SUM(total_amount) > 5000
)
SELECT 
    c.name,
    c.email,
    hvc.total_spent
FROM high_value_customers hvc
JOIN customers c ON hvc.customer_id = c.id
ORDER BY hvc.total_spent DESC;

-- Multiple CTEs
WITH monthly_sales AS (
    SELECT 
        DATE_TRUNC('month', order_date) as month,
        SUM(total_amount) as monthly_total,
        COUNT(*) as order_count
    FROM orders
    WHERE status = 'completed'
    GROUP BY DATE_TRUNC('month', order_date)
),
avg_monthly AS (
    SELECT AVG(monthly_total) as avg_monthly_sales
    FROM monthly_sales
)
SELECT 
    ms.month,
    ms.monthly_total,
    ms.order_count,
    ROUND(ms.monthly_total / am.avg_monthly_sales * 100, 2) as percent_of_average
FROM monthly_sales ms
CROSS JOIN avg_monthly am
ORDER BY ms.month;

-- Recursive CTE - Hierarchical data
WITH RECURSIVE date_series AS (
    -- Base case
    SELECT DATE '2023-01-01' as date
    
    UNION ALL
    
    -- Recursive case
    SELECT date + INTERVAL '1 day'
    FROM date_series
    WHERE date < DATE '2023-12-31'
)
SELECT 
    ds.date,
    COALESCE(daily_stats.order_count, 0) as orders,
    COALESCE(daily_stats.daily_total, 0) as revenue
FROM date_series ds
LEFT JOIN (
    SELECT 
        order_date,
        COUNT(*) as order_count,
        SUM(total_amount) as daily_total
    FROM orders
    WHERE status = 'completed'
    GROUP BY order_date
) daily_stats ON ds.date = daily_stats.order_date
ORDER BY ds.date;

-- 5. WINDOW FUNCTIONS WITH COMPLEX QUERIES

-- Running totals and rankings
SELECT 
    c.name,
    o.order_date,
    o.total_amount,
    SUM(o.total_amount) OVER (
        PARTITION BY c.id 
        ORDER BY o.order_date 
        ROWS UNBOUNDED PRECEDING
    ) as running_total,
    ROW_NUMBER() OVER (
        PARTITION BY c.id 
        ORDER BY o.total_amount DESC
    ) as order_rank_by_amount,
    DENSE_RANK() OVER (
        ORDER BY o.total_amount DESC
    ) as overall_rank
FROM customers c
JOIN orders o ON c.id = o.customer_id
WHERE o.status = 'completed'
ORDER BY c.name, o.order_date;

-- Lead and lag for comparison
SELECT 
    customer_id,
    order_date,
    total_amount,
    LAG(total_amount) OVER (
        PARTITION BY customer_id 
        ORDER BY order_date
    ) as previous_order_amount,
    LEAD(order_date) OVER (
        PARTITION BY customer_id 
        ORDER BY order_date
    ) as next_order_date,
    total_amount - LAG(total_amount) OVER (
        PARTITION BY customer_id 
        ORDER BY order_date
    ) as amount_change
FROM orders
WHERE status = 'completed'
ORDER BY customer_id, order_date;

-- 6. ADVANCED AGGREGATIONS

-- ROLLUP and CUBE for multi-dimensional aggregations
SELECT 
    COALESCE(c.country, 'ALL COUNTRIES') as country,
    COALESCE(p.category, 'ALL CATEGORIES') as category,
    SUM(oi.quantity * oi.unit_price) as total_sales,
    COUNT(DISTINCT o.id) as order_count
FROM customers c
JOIN orders o ON c.id = o.customer_id
JOIN order_items oi ON o.id = oi.order_id
JOIN products p ON oi.product_id = p.id
WHERE o.status = 'completed'
GROUP BY ROLLUP(c.country, p.category)
ORDER BY c.country, p.category;

-- GROUPING SETS for custom aggregation combinations
SELECT 
    c.country,
    DATE_TRUNC('month', o.order_date) as month,
    SUM(o.total_amount) as total_sales
FROM customers c
JOIN orders o ON c.id = o.customer_id
WHERE o.status = 'completed'
GROUP BY GROUPING SETS (
    (c.country),
    (DATE_TRUNC('month', o.order_date)),
    (c.country, DATE_TRUNC('month', o.order_date)),
    ()
)
ORDER BY c.country, month;

-- 7. COMPLEX FILTERING AND CASE STATEMENTS

-- Customer segmentation with complex logic
SELECT 
    c.id,
    c.name,
    c.email,
    customer_stats.total_orders,
    customer_stats.total_spent,
    customer_stats.avg_order_value,
    customer_stats.days_since_last_order,
    CASE 
        WHEN customer_stats.total_spent > 10000 THEN 'VIP'
        WHEN customer_stats.total_spent > 5000 AND customer_stats.days_since_last_order < 30 THEN 'High Value'
        WHEN customer_stats.total_orders > 10 THEN 'Frequent'
        WHEN customer_stats.days_since_last_order > 90 THEN 'At Risk'
        WHEN customer_stats.total_orders = 0 THEN 'New'
        ELSE 'Regular'
    END as customer_segment
FROM customers c
LEFT JOIN (
    SELECT 
        customer_id,
        COUNT(*) as total_orders,
        SUM(total_amount) as total_spent,
        AVG(total_amount) as avg_order_value,
        CURRENT_DATE - MAX(order_date) as days_since_last_order
    FROM orders
    WHERE status = 'completed'
    GROUP BY customer_id
) customer_stats ON c.id = customer_stats.customer_id
ORDER BY customer_stats.total_spent DESC NULLS LAST;

-- 8. PIVOT-LIKE QUERIES

-- Monthly sales by category (pivot simulation)
SELECT 
    category,
    SUM(CASE WHEN month = '2023-01' THEN monthly_sales END) as jan_2023,
    SUM(CASE WHEN month = '2023-02' THEN monthly_sales END) as feb_2023,
    SUM(CASE WHEN month = '2023-03' THEN monthly_sales END) as mar_2023,
    SUM(monthly_sales) as total_sales
FROM (
    SELECT 
        p.category,
        TO_CHAR(o.order_date, 'YYYY-MM') as month,
        SUM(oi.quantity * oi.unit_price) as monthly_sales
    FROM orders o
    JOIN order_items oi ON o.id = oi.order_id
    JOIN products p ON oi.product_id = p.id
    WHERE o.status = 'completed'
      AND o.order_date >= '2023-01-01'
      AND o.order_date < '2023-04-01'
    GROUP BY p.category, TO_CHAR(o.order_date, 'YYYY-MM')
) monthly_data
GROUP BY category
ORDER BY total_sales DESC;

-- 9. PERFORMANCE OPTIMIZATION

-- Query with proper indexing hints and optimization
EXPLAIN (ANALYZE, BUFFERS)
WITH recent_customers AS (
    SELECT id, name, email
    FROM customers 
    WHERE registration_date >= CURRENT_DATE - INTERVAL '1 year'
      AND status = 'active'
),
customer_metrics AS (
    SELECT 
        rc.id,
        rc.name,
        rc.email,
        COUNT(o.id) as order_count,
        SUM(o.total_amount) as total_spent,
        MAX(o.order_date) as last_order_date
    FROM recent_customers rc
    LEFT JOIN orders o ON rc.id = o.customer_id AND o.status = 'completed'
    GROUP BY rc.id, rc.name, rc.email
)
SELECT 
    cm.*,
    CASE 
        WHEN cm.order_count = 0 THEN 'No Orders'
        WHEN cm.last_order_date > CURRENT_DATE - INTERVAL '30 days' THEN 'Active'
        WHEN cm.last_order_date > CURRENT_DATE - INTERVAL '90 days' THEN 'Moderate'
        ELSE 'Inactive'
    END as activity_status
FROM customer_metrics cm
ORDER BY cm.total_spent DESC NULLS LAST
LIMIT 100;
```

**Query Optimization Tips:**

1. **Use appropriate JOIN types** based on data relationships
2. **Filter early** with WHERE clauses before JOINs when possible
3. **Use CTEs** for complex logic readability and reusability
4. **Leverage indexes** on JOIN and WHERE clause columns
5. **Use EXPLAIN ANALYZE** to understand query execution plans
6. **Consider materialized views** for frequently-used complex queries
7. **Partition large tables** for better performance
8. **Use window functions** instead of self-joins when possible

---

## Navigation

⬅️ **[Previous: Node.js Questions](./nodejs-questions.md)**  
➡️ **[Next: API Integration Questions](./api-integration-questions.md)**  
🏠 **[Home: Research Index](../README.md)**

---

*These PostgreSQL questions cover database fundamentals, query optimization, and advanced SQL techniques essential for the Dev Partners Senior Full Stack Developer position.*
