# React Interview Questions & Answers

## Basic React Concepts

### 1. What is React and what are its key features?

**Answer:**
React is a JavaScript library for building user interfaces, particularly single-page applications. It was developed by Facebook and focuses on creating reusable UI components.

**Key Features:**

```jsx
// 1. Component-Based Architecture
function UserCard({ user }) {
  return (
    <div className="user-card">
      <h3>{user.name}</h3>
      <p>{user.email}</p>
    </div>
  );
}

// 2. Virtual DOM
// React creates a virtual representation of the DOM in memory
// and efficiently updates only the parts that changed

// 3. JSX - JavaScript XML
function App() {
  const name = "World";
  return (
    <div>
      <h1>Hello, {name}!</h1>
      <UserCard user={{ name: "John", email: "john@example.com" }} />
    </div>
  );
}

// 4. Unidirectional Data Flow
function Parent() {
  const [count, setCount] = useState(0);
  
  return (
    <div>
      <Child count={count} onIncrement={() => setCount(count + 1)} />
    </div>
  );
}

function Child({ count, onIncrement }) {
  return (
    <div>
      <p>Count: {count}</p>
      <button onClick={onIncrement}>Increment</button>
    </div>
  );
}

// 5. State Management with Hooks
function Counter() {
  const [count, setCount] = useState(0);
  
  useEffect(() => {
    document.title = `Count: ${count}`;
  }, [count]);
  
  return (
    <div>
      <p>You clicked {count} times</p>
      <button onClick={() => setCount(count + 1)}>
        Click me
      </button>
    </div>
  );
}

// 6. Reusability
function Button({ variant, children, onClick }) {
  return (
    <button 
      className={`btn btn-${variant}`} 
      onClick={onClick}
    >
      {children}
    </button>
  );
}

// Usage
<Button variant="primary" onClick={handleSubmit}>Submit</Button>
<Button variant="secondary" onClick={handleCancel}>Cancel</Button>

// 7. Ecosystem and Tooling
// - React Router for routing
// - Redux/Zustand for state management
// - React Testing Library for testing
// - Next.js for full-stack development
```

**Benefits:**

- **Declarative**: Describe what the UI should look like
- **Component-based**: Encapsulated components managing their own state
- **Learn once, write anywhere**: React Native for mobile
- **Large ecosystem**: Extensive library support
- **Performance**: Virtual DOM optimizations
- **Developer tools**: Excellent debugging tools

### 2. What is JSX and how does it work?

**Answer:**
JSX (JavaScript XML) is a syntax extension for JavaScript that allows you to write HTML-like code within JavaScript. It's compiled to JavaScript by tools like Babel.

```jsx
// JSX Example
const element = <h1>Hello, World!</h1>;

// Compiles to:
const element = React.createElement('h1', null, 'Hello, World!');

// JSX with Expressions
function Greeting({ name }) {
  const timeOfDay = new Date().getHours() < 12 ? 'morning' : 'afternoon';
  
  return (
    <div>
      <h1>Good {timeOfDay}, {name}!</h1>
      <p>Today is {new Date().toDateString()}</p>
    </div>
  );
}

// JSX Rules and Best Practices

// 1. Must return a single parent element (or Fragment)
function ValidComponent() {
  return (
    <div>
      <h1>Title</h1>
      <p>Content</p>
    </div>
  );
}

// Using React Fragment
function FragmentExample() {
  return (
    <>
      <h1>Title</h1>
      <p>Content</p>
    </>
  );
}

// 2. Use className instead of class
function StyledComponent() {
  return (
    <div className="container">
      <button className="btn btn-primary">Click me</button>
    </div>
  );
}

// 3. Use camelCase for HTML attributes
function FormExample() {
  return (
    <form>
      <label htmlFor="email">Email:</label>
      <input 
        type="email" 
        id="email" 
        autoComplete="email"
        tabIndex={1}
      />
    </form>
  );
}

// 4. Self-closing tags must be closed
function ImageComponent() {
  return (
    <div>
      <img src="image.jpg" alt="Description" />
      <br />
      <input type="text" />
    </div>
  );
}

// 5. JavaScript expressions in curly braces
function DynamicContent() {
  const items = ['apple', 'banana', 'orange'];
  const isLoggedIn = true;
  
  return (
    <div>
      {/* Conditional rendering */}
      {isLoggedIn ? <p>Welcome back!</p> : <p>Please log in</p>}
      
      {/* List rendering */}
      <ul>
        {items.map((item, index) => (
          <li key={index}>{item}</li>
        ))}
      </ul>
      
      {/* Inline styles */}
      <div style={{ color: 'red', fontSize: '16px' }}>
        Styled text
      </div>
    </div>
  );
}

// 6. Event Handlers
function InteractiveComponent() {
  const [count, setCount] = useState(0);
  
  const handleClick = (event) => {
    event.preventDefault();
    setCount(count + 1);
  };
  
  const handleChange = (event) => {
    console.log(event.target.value);
  };
  
  return (
    <div>
      <button onClick={handleClick}>Count: {count}</button>
      <input onChange={handleChange} placeholder="Type something" />
      
      {/* Inline event handler */}
      <button onClick={() => alert('Hello!')}>Alert</button>
    </div>
  );
}

// 7. Advanced JSX Patterns

// Conditional rendering with logical operators
function ConditionalComponent({ user, loading, error }) {
  return (
    <div>
      {loading && <div>Loading...</div>}
      {error && <div className="error">Error: {error.message}</div>}
      {user && (
        <div>
          <h1>Welcome, {user.name}!</h1>
          {user.isAdmin && <button>Admin Panel</button>}
        </div>
      )}
    </div>
  );
}

// JSX with children
function Container({ children, title }) {
  return (
    <div className="container">
      <h2>{title}</h2>
      <div className="content">
        {children}
      </div>
    </div>
  );
}

// Usage
<Container title="My Content">
  <p>This is the content inside the container</p>
  <button>Action</button>
</Container>

// Spread operator with props
function Button(props) {
  return <button {...props} className={`btn ${props.className || ''}`} />;
}

// Usage
<Button type="submit" disabled onClick={handleSubmit} className="primary">
  Submit
</Button>

// JSX with complex expressions
function DataTable({ data }) {
  return (
    <table>
      <thead>
        <tr>
          {Object.keys(data[0] || {}).map(header => (
            <th key={header}>{header}</th>
          ))}
        </tr>
      </thead>
      <tbody>
        {data.map((row, index) => (
          <tr key={index}>
            {Object.values(row).map((cell, cellIndex) => (
              <td key={cellIndex}>{cell}</td>
            ))}
          </tr>
        ))}
      </tbody>
    </table>
  );
}

// JSX compilation examples
const jsx = (
  <div className="container">
    <h1>{title}</h1>
    <Button onClick={handleClick}>Click me</Button>
  </div>
);

// Compiles to:
const compiled = React.createElement(
  'div',
  { className: 'container' },
  React.createElement('h1', null, title),
  React.createElement(Button, { onClick: handleClick }, 'Click me')
);
```

**Key Points:**

- JSX is **syntactic sugar** for `React.createElement()`
- **Expressions only**: Use `{expression}` not `{statement}`
- **Type safety**: Works well with TypeScript
- **Performance**: No runtime overhead after compilation
- **Developer experience**: Better readability than vanilla JS

### 3. What are React hooks and why were they introduced?

**Answer:**
React Hooks are functions that let you use state and other React features in functional components. They were introduced in React 16.8 to solve several problems with class components.

**Problems Hooks Solve:**

```jsx
// BEFORE HOOKS - Class Components

class UserProfile extends React.Component {
  constructor(props) {
    super(props);
    this.state = {
      user: null,
      loading: true,
      error: null
    };
    
    // Binding methods
    this.handleUpdate = this.handleUpdate.bind(this);
  }
  
  async componentDidMount() {
    try {
      const user = await fetchUser(this.props.userId);
      this.setState({ user, loading: false });
    } catch (error) {
      this.setState({ error, loading: false });
    }
  }
  
  async componentDidUpdate(prevProps) {
    if (prevProps.userId !== this.props.userId) {
      this.setState({ loading: true });
      try {
        const user = await fetchUser(this.props.userId);
        this.setState({ user, loading: false });
      } catch (error) {
        this.setState({ error, loading: false });
      }
    }
  }
  
  handleUpdate(userData) {
    this.setState({ user: userData });
  }
  
  render() {
    const { user, loading, error } = this.state;
    
    if (loading) return <div>Loading...</div>;
    if (error) return <div>Error: {error.message}</div>;
    
    return (
      <div>
        <h1>{user.name}</h1>
        <button onClick={() => this.handleUpdate({...user, active: !user.active})}>
          Toggle Active
        </button>
      </div>
    );
  }
}

// AFTER HOOKS - Functional Components

function UserProfile({ userId }) {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  
  useEffect(() => {
    const fetchUserData = async () => {
      setLoading(true);
      try {
        const userData = await fetchUser(userId);
        setUser(userData);
        setError(null);
      } catch (err) {
        setError(err);
      } finally {
        setLoading(false);
      }
    };
    
    fetchUserData();
  }, [userId]); // Dependency array
  
  const handleUpdate = (userData) => {
    setUser(userData);
  };
  
  if (loading) return <div>Loading...</div>;
  if (error) return <div>Error: {error.message}</div>;
  
  return (
    <div>
      <h1>{user.name}</h1>
      <button onClick={() => handleUpdate({...user, active: !user.active})}>
        Toggle Active
      </button>
    </div>
  );
}
```

**Built-in Hooks:**

```jsx
// 1. useState - State management
function Counter() {
  const [count, setCount] = useState(0);
  const [name, setName] = useState('');
  
  return (
    <div>
      <p>Count: {count}</p>
      <button onClick={() => setCount(count + 1)}>+</button>
      <button onClick={() => setCount(count - 1)}>-</button>
      
      <input 
        value={name} 
        onChange={(e) => setName(e.target.value)} 
        placeholder="Enter name"
      />
    </div>
  );
}

// 2. useEffect - Side effects
function DataFetcher({ url }) {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  
  useEffect(() => {
    // Effect function
    const fetchData = async () => {
      setLoading(true);
      try {
        const response = await fetch(url);
        const result = await response.json();
        setData(result);
      } catch (error) {
        console.error('Fetch error:', error);
      } finally {
        setLoading(false);
      }
    };
    
    fetchData();
    
    // Cleanup function (optional)
    return () => {
      // Cancel requests, clear timeouts, etc.
    };
  }, [url]); // Dependencies
  
  return loading ? <div>Loading...</div> : <div>{JSON.stringify(data)}</div>;
}

// 3. useContext - Context consumption
const ThemeContext = createContext();

function App() {
  const [theme, setTheme] = useState('light');
  
  return (
    <ThemeContext.Provider value={{ theme, setTheme }}>
      <Header />
      <Main />
    </ThemeContext.Provider>
  );
}

function Header() {
  const { theme, setTheme } = useContext(ThemeContext);
  
  return (
    <header className={`header-${theme}`}>
      <button onClick={() => setTheme(theme === 'light' ? 'dark' : 'light')}>
        Toggle Theme
      </button>
    </header>
  );
}

// 4. useReducer - Complex state management
const initialState = { count: 0, step: 1 };

function reducer(state, action) {
  switch (action.type) {
    case 'increment':
      return { ...state, count: state.count + state.step };
    case 'decrement':
      return { ...state, count: state.count - state.step };
    case 'setStep':
      return { ...state, step: action.payload };
    case 'reset':
      return initialState;
    default:
      throw new Error('Unknown action type');
  }
}

function Counter() {
  const [state, dispatch] = useReducer(reducer, initialState);
  
  return (
    <div>
      <p>Count: {state.count}</p>
      <p>Step: {state.step}</p>
      
      <button onClick={() => dispatch({ type: 'increment' })}>+</button>
      <button onClick={() => dispatch({ type: 'decrement' })}>-</button>
      <button onClick={() => dispatch({ type: 'reset' })}>Reset</button>
      
      <input 
        type="number" 
        value={state.step}
        onChange={(e) => dispatch({ 
          type: 'setStep', 
          payload: parseInt(e.target.value) 
        })}
      />
    </div>
  );
}

// 5. useMemo - Memoization for expensive calculations
function ExpensiveComponent({ items, filter }) {
  const filteredItems = useMemo(() => {
    console.log('Filtering items...'); // Only runs when dependencies change
    return items.filter(item => item.category === filter);
  }, [items, filter]);
  
  const expensiveValue = useMemo(() => {
    console.log('Calculating expensive value...');
    return filteredItems.reduce((sum, item) => sum + item.price, 0);
  }, [filteredItems]);
  
  return (
    <div>
      <p>Total: ${expensiveValue}</p>
      <ul>
        {filteredItems.map(item => (
          <li key={item.id}>{item.name} - ${item.price}</li>
        ))}
      </ul>
    </div>
  );
}

// 6. useCallback - Memoization for functions
function TodoList({ todos, onToggle, onDelete }) {
  const [filter, setFilter] = useState('all');
  
  // Without useCallback, this function is recreated on every render
  const handleToggle = useCallback((id) => {
    onToggle(id);
  }, [onToggle]);
  
  const handleDelete = useCallback((id) => {
    onDelete(id);
  }, [onDelete]);
  
  const filteredTodos = useMemo(() => {
    switch (filter) {
      case 'completed':
        return todos.filter(todo => todo.completed);
      case 'active':
        return todos.filter(todo => !todo.completed);
      default:
        return todos;
    }
  }, [todos, filter]);
  
  return (
    <div>
      <select value={filter} onChange={(e) => setFilter(e.target.value)}>
        <option value="all">All</option>
        <option value="active">Active</option>
        <option value="completed">Completed</option>
      </select>
      
      {filteredTodos.map(todo => (
        <TodoItem 
          key={todo.id}
          todo={todo}
          onToggle={handleToggle}
          onDelete={handleDelete}
        />
      ))}
    </div>
  );
}

// 7. useRef - Direct DOM access and mutable values
function FocusInput() {
  const inputRef = useRef(null);
  const countRef = useRef(0);
  
  useEffect(() => {
    // Focus input on mount
    inputRef.current.focus();
  }, []);
  
  const handleClick = () => {
    countRef.current += 1;
    console.log('Click count:', countRef.current);
    inputRef.current.focus();
  };
  
  return (
    <div>
      <input ref={inputRef} placeholder="This will be focused" />
      <button onClick={handleClick}>Focus Input</button>
    </div>
  );
}

// 8. Custom Hooks - Reusable logic
function useLocalStorage(key, initialValue) {
  const [storedValue, setStoredValue] = useState(() => {
    try {
      const item = window.localStorage.getItem(key);
      return item ? JSON.parse(item) : initialValue;
    } catch (error) {
      console.error('Error reading localStorage:', error);
      return initialValue;
    }
  });
  
  const setValue = (value) => {
    try {
      setStoredValue(value);
      window.localStorage.setItem(key, JSON.stringify(value));
    } catch (error) {
      console.error('Error setting localStorage:', error);
    }
  };
  
  return [storedValue, setValue];
}

// Usage of custom hook
function Settings() {
  const [theme, setTheme] = useLocalStorage('theme', 'light');
  const [language, setLanguage] = useLocalStorage('language', 'en');
  
  return (
    <div>
      <select value={theme} onChange={(e) => setTheme(e.target.value)}>
        <option value="light">Light</option>
        <option value="dark">Dark</option>
      </select>
      
      <select value={language} onChange={(e) => setLanguage(e.target.value)}>
        <option value="en">English</option>
        <option value="es">Spanish</option>
      </select>
    </div>
  );
}

// Advanced Custom Hook Example
function useApi(url) {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  
  const refetch = useCallback(async () => {
    setLoading(true);
    setError(null);
    
    try {
      const response = await fetch(url);
      if (!response.ok) throw new Error('Failed to fetch');
      const result = await response.json();
      setData(result);
    } catch (err) {
      setError(err);
    } finally {
      setLoading(false);
    }
  }, [url]);
  
  useEffect(() => {
    refetch();
  }, [refetch]);
  
  return { data, loading, error, refetch };
}

// Usage
function UserList() {
  const { data: users, loading, error, refetch } = useApi('/api/users');
  
  if (loading) return <div>Loading...</div>;
  if (error) return <div>Error: {error.message}</div>;
  
  return (
    <div>
      <button onClick={refetch}>Refresh</button>
      <ul>
        {users.map(user => (
          <li key={user.id}>{user.name}</li>
        ))}
      </ul>
    </div>
  );
}
```

**Benefits of Hooks:**

1. **Reusable Logic**: Custom hooks allow sharing stateful logic
2. **Simpler Components**: No class boilerplate
3. **Better Testing**: Easier to test pure functions
4. **Performance**: Better optimization opportunities
5. **Developer Experience**: Cleaner, more readable code
6. **Composition**: Easy to combine multiple hooks

**Hook Rules:**

1. **Only call hooks at the top level** (not inside loops, conditions, or nested functions)
2. **Only call hooks from React functions** (components or custom hooks)

### 4. What is the difference between `useState` and `useReducer`?

**Answer:**
Both `useState` and `useReducer` are hooks for managing state, but they're suited for different scenarios.

```jsx
// useState - Simple State Management

// Basic counter with useState
function Counter() {
  const [count, setCount] = useState(0);
  
  return (
    <div>
      <p>Count: {count}</p>
      <button onClick={() => setCount(count + 1)}>+</button>
      <button onClick={() => setCount(count - 1)}>-</button>
      
      <input 
        value={name} 
        onChange={(e) => setName(e.target.value)} 
        placeholder="Enter name"
      />
    </div>
  );
}

// Multiple state variables
function UserForm() {
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [age, setAge] = useState(0);
  const [errors, setErrors] = useState({});
  
  const handleSubmit = () => {
    const newErrors = {};
    if (!name) newErrors.name = 'Name is required';
    if (!email) newErrors.email = 'Email is required';
    if (age < 18) newErrors.age = 'Must be 18 or older';
    
    setErrors(newErrors);
    
    if (Object.keys(newErrors).length === 0) {
      // Submit form
      console.log({ name, email, age });
    }
  };
  
  return (
    <form onSubmit={handleSubmit}>
      <input 
        value={name} 
        onChange={(e) => setName(e.target.value)}
        placeholder="Name"
      />
      {errors.name && <span className="error">{errors.name}</span>}
      
      <input 
        value={email} 
        onChange={(e) => setEmail(e.target.value)}
        placeholder="Email"
      />
      {errors.email && <span className="error">{errors.email}</span>}
      
      <input 
        type="number"
        value={age} 
        onChange={(e) => setAge(parseInt(e.target.value))}
        placeholder="Age"
      />
      {errors.age && <span className="error">{errors.age}</span>}
      
      <button type="submit">Submit</button>
    </form>
  );
}

// useReducer - Complex State Management

// Shopping cart with useReducer
const initialCartState = {
  items: [],
  total: 0,
  discount: 0,
  tax: 0,
  shipping: 0
};

function cartReducer(state, action) {
  switch (action.type) {
    case 'ADD_ITEM':
      const existingItemIndex = state.items.findIndex(
        item => item.id === action.payload.id
      );
      
      let newItems;
      if (existingItemIndex >= 0) {
        newItems = state.items.map((item, index) =>
          index === existingItemIndex 
            ? { ...item, quantity: item.quantity + 1 }
            : item
        );
      } else {
        newItems = [...state.items, { ...action.payload, quantity: 1 }];
      }
      
      return {
        ...state,
        items: newItems,
        total: calculateTotal(newItems)
      };
      
    case 'REMOVE_ITEM':
      const filteredItems = state.items.filter(item => item.id !== action.payload);
      return {
        ...state,
        items: filteredItems,
        total: calculateTotal(filteredItems)
      };
      
    case 'UPDATE_QUANTITY':
      const updatedItems = state.items.map(item =>
        item.id === action.payload.id 
          ? { ...item, quantity: action.payload.quantity }
          : item
      );
      return {
        ...state,
        items: updatedItems,
        total: calculateTotal(updatedItems)
      };
      
    case 'APPLY_DISCOUNT':
      return {
        ...state,
        discount: action.payload
      };
      
    case 'SET_TAX':
      return {
        ...state,
        tax: action.payload
      };
      
    case 'SET_SHIPPING':
      return {
        ...state,
        shipping: action.payload
      };
      
    case 'CLEAR_CART':
      return initialCartState;
      
    default:
      throw new Error(`Unknown action type: ${action.type}`);
  }
}

function calculateTotal(items) {
  return items.reduce((sum, item) => sum + (item.price * item.quantity), 0);
}

function ShoppingCart() {
  const [cartState, dispatch] = useReducer(cartReducer, initialCartState);
  
  const addItem = (product) => {
    dispatch({ type: 'ADD_ITEM', payload: product });
  };
  
  const removeItem = (productId) => {
    dispatch({ type: 'REMOVE_ITEM', payload: productId });
  };
  
  const updateQuantity = (productId, quantity) => {
    if (quantity <= 0) {
      removeItem(productId);
    } else {
      dispatch({ 
        type: 'UPDATE_QUANTITY', 
        payload: { id: productId, quantity } 
      });
    }
  };
  
  const applyDiscount = (discount) => {
    dispatch({ type: 'APPLY_DISCOUNT', payload: discount });
  };
  
  const finalTotal = cartState.total - cartState.discount + cartState.tax + cartState.shipping;
  
  return (
    <div>
      <h2>Shopping Cart</h2>
      
      {cartState.items.map(item => (
        <div key={item.id} className="cart-item">
          <span>{item.name}</span>
          <span>${item.price}</span>
          <input 
            type="number" 
            value={item.quantity}
            onChange={(e) => updateQuantity(item.id, parseInt(e.target.value))}
          />
          <button onClick={() => removeItem(item.id)}>Remove</button>
        </div>
      ))}
      
      <div className="cart-summary">
        <p>Subtotal: ${cartState.total}</p>
        <p>Discount: -${cartState.discount}</p>
        <p>Tax: ${cartState.tax}</p>
        <p>Shipping: ${cartState.shipping}</p>
        <h3>Total: ${finalTotal}</h3>
      </div>
      
      <button onClick={() => dispatch({ type: 'CLEAR_CART' })}>
        Clear Cart
      </button>
    </div>
  );
}

// COMPARISON: Same Logic with useState vs useReducer

// Complex form with useState (becomes unwieldy)
function ComplexFormWithUseState() {
  const [firstName, setFirstName] = useState('');
  const [lastName, setLastName] = useState('');
  const [email, setEmail] = useState('');
  const [phone, setPhone] = useState('');
  const [address, setAddress] = useState('');
  const [city, setCity] = useState('');
  const [state, setState] = useState('');
  const [zipCode, setZipCode] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [errors, setErrors] = useState({});
  const [touched, setTouched] = useState({});
  
  // Many separate functions for handling updates
  const handleFirstNameChange = (value) => {
    setFirstName(value);
    if (touched.firstName && errors.firstName) {
      setErrors(prev => ({ ...prev, firstName: undefined }));
    }
  };
  
  // ... many more similar functions
  
  return (
    // Complex JSX with many individual handlers
    <form>
      {/* Many individual inputs */}
    </form>
  );
}

// Same form with useReducer (more organized)
const initialFormState = {
  fields: {
    firstName: '',
    lastName: '',
    email: '',
    phone: '',
    address: '',
    city: '',
    state: '',
    zipCode: ''
  },
  errors: {},
  touched: {},
  isSubmitting: false
};

function formReducer(state, action) {
  switch (action.type) {
    case 'UPDATE_FIELD':
      return {
        ...state,
        fields: {
          ...state.fields,
          [action.field]: action.value
        },
        // Clear error when user starts typing
        errors: {
          ...state.errors,
          [action.field]: undefined
        }
      };
      
    case 'SET_FIELD_TOUCHED':
      return {
        ...state,
        touched: {
          ...state.touched,
          [action.field]: true
        }
      };
      
    case 'SET_ERRORS':
      return {
        ...state,
        errors: action.errors
      };
      
    case 'SET_SUBMITTING':
      return {
        ...state,
        isSubmitting: action.isSubmitting
      };
      
    case 'RESET_FORM':
      return initialFormState;
      
    default:
      return state;
  }
}

function ComplexFormWithUseReducer() {
  const [formState, dispatch] = useReducer(formReducer, initialFormState);
  
  const updateField = (field, value) => {
    dispatch({ type: 'UPDATE_FIELD', field, value });
  };
  
  const setFieldTouched = (field) => {
    dispatch({ type: 'SET_FIELD_TOUCHED', field });
  };
  
  const validateForm = () => {
    const errors = {};
    const { fields } = formState;
    
    if (!fields.firstName) errors.firstName = 'First name is required';
    if (!fields.lastName) errors.lastName = 'Last name is required';
    if (!fields.email) errors.email = 'Email is required';
    // ... more validations
    
    dispatch({ type: 'SET_ERRORS', errors });
    return Object.keys(errors).length === 0;
  };
  
  const handleSubmit = async (e) => {
    e.preventDefault();
    
    if (!validateForm()) return;
    
    dispatch({ type: 'SET_SUBMITTING', isSubmitting: true });
    
    try {
      await submitForm(formState.fields);
      dispatch({ type: 'RESET_FORM' });
    } catch (error) {
      dispatch({ type: 'SET_ERRORS', errors: { submit: error.message } });
    } finally {
      dispatch({ type: 'SET_SUBMITTING', isSubmitting: false });
    }
  };
  
  return (
    <form onSubmit={handleSubmit}>
      <input 
        value={formState.fields.firstName}
        onChange={(e) => updateField('firstName', e.target.value)}
        onBlur={() => setFieldTouched('firstName')}
        placeholder="First Name"
      />
      {formState.errors.firstName && (
        <span className="error">{formState.errors.firstName}</span>
      )}
      
      {/* More inputs... */}
      
      <button 
        type="submit" 
        disabled={formState.isSubmitting}
      >
        {formState.isSubmitting ? 'Submitting...' : 'Submit'}
      </button>
    </form>
  );
}

// WHEN TO USE WHICH

// Use useState when:
// 1. Simple state (primitives, simple objects)
// 2. Independent state variables
// 3. Direct state updates
// 4. Local component state

function SimpleComponent() {
  const [isVisible, setIsVisible] = useState(false);
  const [count, setCount] = useState(0);
  const [name, setName] = useState('');
  
  return (
    <div>
      {isVisible && <p>Count: {count}</p>}
      <button onClick={() => setIsVisible(!isVisible)}>Toggle</button>
      <button onClick={() => setCount(count + 1)}>Increment</button>
      <input value={name} onChange={(e) => setName(e.target.value)} />
    </div>
  );
}

// Use useReducer when:
// 1. Complex state logic
// 2. Multiple sub-values
// 3. Next state depends on previous state
// 4. State transitions are predictable

// Advanced useReducer with middleware-like pattern
function useReducerWithMiddleware(reducer, initialState, middleware) {
  const [state, dispatch] = useReducer(reducer, initialState);
  
  const enhancedDispatch = useCallback((action) => {
    if (middleware) {
      middleware(action, state);
    }
    dispatch(action);
  }, [middleware, state]);
  
  return [state, enhancedDispatch];
}

// Logging middleware
const loggingMiddleware = (action, state) => {
  console.log('Action:', action);
  console.log('Current State:', state);
};

function ComponentWithMiddleware() {
  const [state, dispatch] = useReducerWithMiddleware(
    cartReducer, 
    initialCartState, 
    loggingMiddleware
  );
  
  return <ShoppingCart state={state} dispatch={dispatch} />;
}
```

**Key Differences:**

| Aspect | useState | useReducer |
|--------|----------|------------|
| **Complexity** | Simple state updates | Complex state logic |
| **State Structure** | Primitives, simple objects | Complex objects, multiple fields |
| **Updates** | Direct state setting | Action-based updates |
| **Predictability** | Less predictable | More predictable |
| **Testing** | Harder to test logic | Easier to test reducer |
| **Performance** | Good for simple cases | Better for complex updates |
| **Code Organization** | Scattered update logic | Centralized update logic |

**Performance Considerations:**

- `useReducer` can be more performant for complex state updates
- `useState` might trigger more re-renders with multiple state variables
- `useReducer` with `useCallback` can optimize child component renders

### 5. What is the React Component Lifecycle and how do you handle it with hooks?

**Answer:**
The React component lifecycle describes the phases a component goes through from creation to destruction. With hooks, lifecycle methods are replaced by `useEffect`.

```jsx
// CLASS COMPONENT LIFECYCLE (Traditional)

class LifecycleExample extends React.Component {
  constructor(props) {
    super(props);
    this.state = { count: 0, data: null };
    console.log('1. Constructor');
  }
  
  static getDerivedStateFromProps(props, state) {
    console.log('2. getDerivedStateFromProps');
    // Return null if no state update needed
    return null;
  }
  
  componentDidMount() {
    console.log('3. componentDidMount');
    // API calls, subscriptions, timers
    this.fetchData();
    this.timer = setInterval(() => {
      this.setState(prev => ({ count: prev.count + 1 }));
    }, 1000);
  }
  
  shouldComponentUpdate(nextProps, nextState) {
    console.log('4. shouldComponentUpdate');
    // Performance optimization
    return nextState.count !== this.state.count;
  }
  
  getSnapshotBeforeUpdate(prevProps, prevState) {
    console.log('5. getSnapshotBeforeUpdate');
    // Capture some information from DOM before update
    return { scrollPosition: window.scrollY };
  }
  
  componentDidUpdate(prevProps, prevState, snapshot) {
    console.log('6. componentDidUpdate');
    if (prevProps.userId !== this.props.userId) {
      this.fetchData();
    }
    
    if (snapshot) {
      console.log('Previous scroll position:', snapshot.scrollPosition);
    }
  }
  
  componentWillUnmount() {
    console.log('7. componentWillUnmount');
    // Cleanup
    clearInterval(this.timer);
    this.abortController?.abort();
  }
  
  fetchData = async () => {
    try {
      this.abortController = new AbortController();
      const response = await fetch(`/api/user/${this.props.userId}`, {
        signal: this.abortController.signal
      });
      const data = await response.json();
      this.setState({ data });
    } catch (error) {
      if (error.name !== 'AbortError') {
        console.error('Fetch error:', error);
      }
    }
  }
  
  render() {
    console.log('Render');
    return (
      <div>
        <h1>Count: {this.state.count}</h1>
        {this.state.data && <p>User: {this.state.data.name}</p>}
      </div>
    );
  }
}

// FUNCTIONAL COMPONENT WITH HOOKS (Modern)

function LifecycleWithHooks({ userId }) {
  const [count, setCount] = useState(0);
  const [data, setData] = useState(null);
  const [error, setError] = useState(null);
  const abortControllerRef = useRef(null);
  
  // ComponentDidMount equivalent
  useEffect(() => {
    console.log('Component mounted');
    
    // Timer setup
    const timer = setInterval(() => {
      setCount(prev => prev + 1);
    }, 1000);
    
    // Cleanup function (componentWillUnmount equivalent)
    return () => {
      console.log('Component will unmount');
      clearInterval(timer);
    };
  }, []); // Empty dependency array = runs once on mount
  
  // ComponentDidUpdate equivalent for userId changes
  useEffect(() => {
    const fetchData = async () => {
      try {
        console.log('Fetching data for user:', userId);
        
        // Cancel previous request
        if (abortControllerRef.current) {
          abortControllerRef.current.abort();
        }
        
        abortControllerRef.current = new AbortController();
        
        const response = await fetch(`/api/user/${userId}`, {
          signal: abortControllerRef.current.signal
        });
        
        if (!response.ok) throw new Error('Failed to fetch');
        
        const userData = await response.json();
        setData(userData);
        setError(null);
      } catch (err) {
        if (err.name !== 'AbortError') {
          setError(err.message);
        }
      }
    };
    
    if (userId) {
      fetchData();
    }
    
    // Cleanup on dependency change or unmount
    return () => {
      if (abortControllerRef.current) {
        abortControllerRef.current.abort();
      }
    };
  }, [userId]); // Runs when userId changes
  
  // ComponentDidUpdate equivalent for specific state changes
  useEffect(() => {
    console.log('Count updated:', count);
    document.title = `Count: ${count}`;
  }, [count]); // Runs when count changes
  
  // Combination of multiple effects
  useEffect(() => {
    console.log('Either count or data changed');
  }, [count, data]);
  
  if (error) {
    return <div className="error">Error: {error}</div>;
  }
  
  return (
    <div>
      <h1>Count: {count}</h1>
      {data ? <p>User: {data.name}</p> : <p>Loading...</p>}
    </div>
  );
}

// ADVANCED USEEFFECT PATTERNS

// 1. Conditional Effects
function ConditionalEffect({ shouldFetch, url }) {
  const [data, setData] = useState(null);
  
  useEffect(() => {
    if (!shouldFetch) return;
    
    fetch(url)
      .then(res => res.json())
      .then(setData);
  }, [shouldFetch, url]);
  
  return <div>{data ? JSON.stringify(data) : 'No data'}</div>;
}

// 2. Effect with Dependencies
function UserProfile({ userId, refreshTrigger }) {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(false);
  
  useEffect(() => {
    setLoading(true);
    
    const fetchUser = async () => {
      try {
        const response = await fetch(`/api/users/${userId}`);
        const userData = await response.json();
        setUser(userData);
      } catch (error) {
        console.error('Failed to fetch user:', error);
      } finally {
        setLoading(false);
      }
    };
    
    fetchUser();
  }, [userId, refreshTrigger]); // Re-run when either changes
  
  return loading ? <div>Loading...</div> : <div>{user?.name}</div>;
}

// 3. Custom Hook for Lifecycle Management
function useLifecycle() {
  useEffect(() => {
    console.log('Component mounted');
    
    return () => {
      console.log('Component unmounted');
    };
  }, []);
}

function useAsyncEffect(asyncFn, deps) {
  useEffect(() => {
    let cancelled = false;
    
    (async () => {
      try {
        const result = await asyncFn();
        if (!cancelled) {
          // Handle result
        }
      } catch (error) {
        if (!cancelled) {
          console.error('Async effect error:', error);
        }
      }
    })();
    
    return () => {
      cancelled = true;
    };
  }, deps);
}

// 4. Window Event Listeners
function useWindowSize() {
  const [size, setSize] = useState({ width: 0, height: 0 });
  
  useEffect(() => {
    function updateSize() {
      setSize({ width: window.innerWidth, height: window.innerHeight });
    }
    
    updateSize(); // Set initial size
    window.addEventListener('resize', updateSize);
    
    return () => window.removeEventListener('resize', updateSize);
  }, []);
  
  return size;
}

function ResponsiveComponent() {
  const { width, height } = useWindowSize();
  
  return (
    <div>
      <p>Window size: {width} x {height}</p>
      {width < 768 ? <MobileView /> : <DesktopView />}
    </div>
  );
}

// 5. WebSocket Connection Management
function useWebSocket(url) {
  const [socket, setSocket] = useState(null);
  const [lastMessage, setLastMessage] = useState(null);
  const [connectionStatus, setConnectionStatus] = useState('Connecting');
  
  useEffect(() => {
    const ws = new WebSocket(url);
    
    ws.onopen = () => {
      setConnectionStatus('Open');
      setSocket(ws);
    };
    
    ws.onmessage = (event) => {
      setLastMessage(event.data);
    };
    
    ws.onclose = () => {
      setConnectionStatus('Closed');
      setSocket(null);
    };
    
    ws.onerror = (error) => {
      setConnectionStatus('Error');
      console.error('WebSocket error:', error);
    };
    
    return () => {
      ws.close();
    };
  }, [url]);
  
  const sendMessage = useCallback((message) => {
    if (socket && socket.readyState === WebSocket.OPEN) {
      socket.send(message);
    }
  }, [socket]);
  
  return { lastMessage, connectionStatus, sendMessage };
}

// 6. Interval Management
function useInterval(callback, delay) {
  const savedCallback = useRef(callback);
  
  // Remember the latest callback
  useEffect(() => {
    savedCallback.current = callback;
  }, [callback]);
  
  // Set up the interval
  useEffect(() => {
    if (delay === null) return;
    
    const tick = () => savedCallback.current();
    
    const id = setInterval(tick, delay);
    return () => clearInterval(id);
  }, [delay]);
}

function Timer() {
  const [count, setCount] = useState(0);
  const [isRunning, setIsRunning] = useState(true);
  
  useInterval(() => {
    setCount(count + 1);
  }, isRunning ? 1000 : null);
  
  return (
    <div>
      <h1>{count}</h1>
      <button onClick={() => setIsRunning(!isRunning)}>
        {isRunning ? 'Pause' : 'Start'}
      </button>
    </div>
  );
}

// LIFECYCLE COMPARISON TABLE
/*
Class Component          | Hooks Equivalent
-------------------------|------------------
constructor              | useState
componentDidMount        | useEffect(() => {}, [])
componentDidUpdate       | useEffect(() => {})
componentWillUnmount     | useEffect(() => { return () => {} }, [])
shouldComponentUpdate    | React.memo()
getDerivedStateFromProps | useState + useEffect
getSnapshotBeforeUpdate  | useRef + useEffect
componentDidCatch        | Error Boundary (no hook equivalent)
*/

// Performance Optimization with useEffect
function OptimizedComponent({ userId, posts }) {
  const [userData, setUserData] = useState(null);
  
  // Only fetch when userId changes, not when posts change
  useEffect(() => {
    fetchUserData(userId).then(setUserData);
  }, [userId]); // Don't include posts in dependencies
  
  // Separate effect for posts-related logic
  useEffect(() => {
    console.log('Posts updated:', posts.length);
  }, [posts]);
  
  return (
    <div>
      {userData && <h1>{userData.name}</h1>}
      <PostList posts={posts} />
    </div>
  );
}
```

### 6. How do you optimize React performance?

**Answer:**
React performance optimization involves preventing unnecessary re-renders, optimizing expensive operations, and efficiently managing state updates.

```jsx
// 1. REACT.MEMO - Prevent Unnecessary Re-renders

// Without React.memo (re-renders every time parent re-renders)
function ExpensiveChild({ name, age }) {
  console.log('ExpensiveChild rendered');
  
  // Simulate expensive calculation
  const expensiveValue = useMemo(() => {
    let result = 0;
    for (let i = 0; i < 1000000; i++) {
      result += i;
    }
    return result;
  }, []);
  
  return (
    <div>
      <h3>{name}</h3>
      <p>Age: {age}</p>
      <p>Expensive calculation: {expensiveValue}</p>
    </div>
  );
}

// With React.memo (only re-renders when props change)
const OptimizedChild = React.memo(function OptimizedChild({ name, age }) {
  console.log('OptimizedChild rendered');
  
  const expensiveValue = useMemo(() => {
    let result = 0;
    for (let i = 0; i < 1000000; i++) {
      result += i;
    }
    return result;
  }, []);
  
  return (
    <div>
      <h3>{name}</h3>
      <p>Age: {age}</p>
      <p>Expensive calculation: {expensiveValue}</p>
    </div>
  );
});

// Custom comparison function for React.memo
const UserCard = React.memo(function UserCard({ user, onUpdate }) {
  return (
    <div>
      <h3>{user.name}</h3>
      <p>{user.email}</p>
      <button onClick={() => onUpdate(user.id)}>Update</button>
    </div>
  );
}, (prevProps, nextProps) => {
  // Custom comparison - only re-render if user data changed
  return (
    prevProps.user.id === nextProps.user.id &&
    prevProps.user.name === nextProps.user.name &&
    prevProps.user.email === nextProps.user.email
  );
});

// 2. USEMEMO - Memoize Expensive Calculations

function ProductList({ products, filter, sortBy }) {
  // Expensive filtering and sorting
  const processedProducts = useMemo(() => {
    console.log('Processing products...');
    
    let filtered = products.filter(product => {
      return product.category.toLowerCase().includes(filter.toLowerCase());
    });
    
    return filtered.sort((a, b) => {
      if (sortBy === 'price') return a.price - b.price;
      if (sortBy === 'name') return a.name.localeCompare(b.name);
      return 0;
    });
  }, [products, filter, sortBy]); // Only recalculate when these change
  
  const totalValue = useMemo(() => {
    return processedProducts.reduce((sum, product) => sum + product.price, 0);
  }, [processedProducts]);
  
  return (
    <div>
      <h2>Total Value: ${totalValue}</h2>
      {processedProducts.map(product => (
        <ProductItem key={product.id} product={product} />
      ))}
    </div>
  );
}

// 3. USECALLBACK - Memoize Functions

function TodoList({ todos, onToggle, onDelete }) {
  const [filter, setFilter] = useState('all');
  
  // Without useCallback - new function on every render
  // const handleToggle = (id) => onToggle(id);
  
  // With useCallback - same function reference if dependencies don't change
  const handleToggle = useCallback((id) => {
    onToggle(id);
  }, [onToggle]);
  
  const handleDelete = useCallback((id) => {
    onDelete(id);
  }, [onDelete]);
  
  // Filter logic memoized
  const filteredTodos = useMemo(() => {
    switch (filter) {
      case 'completed':
        return todos.filter(todo => todo.completed);
      case 'active':
        return todos.filter(todo => !todo.completed);
      default:
        return todos;
    }
  }, [todos, filter]);
  
  return (
    <div>
      <FilterButtons filter={filter} onFilterChange={setFilter} />
      {filteredTodos.map(todo => (
        <TodoItem
          key={todo.id}
          todo={todo}
          onToggle={handleToggle}
          onDelete={handleDelete}
        />
      ))}
    </div>
  );
}

// Memoized TodoItem to prevent unnecessary re-renders
const TodoItem = React.memo(function TodoItem({ todo, onToggle, onDelete }) {
  return (
    <div className={`todo ${todo.completed ? 'completed' : ''}`}>
      <span onClick={() => onToggle(todo.id)}>{todo.text}</span>
      <button onClick={() => onDelete(todo.id)}>Delete</button>
    </div>
  );
});

// 4. LAZY LOADING AND CODE SPLITTING

// Lazy loading components
const LazyDashboard = React.lazy(() => import('./Dashboard'));
const LazySettings = React.lazy(() => import('./Settings'));
const LazyProfile = React.lazy(() => import('./Profile'));

function App() {
  const [currentPage, setCurrentPage] = useState('dashboard');
  
  const renderPage = () => {
    switch (currentPage) {
      case 'dashboard':
        return <LazyDashboard />;
      case 'settings':
        return <LazySettings />;
      case 'profile':
        return <LazyProfile />;
      default:
        return <div>Page not found</div>;
    }
  };
  
  return (
    <div>
      <nav>
        <button onClick={() => setCurrentPage('dashboard')}>Dashboard</button>
        <button onClick={() => setCurrentPage('settings')}>Settings</button>
        <button onClick={() => setCurrentPage('profile')}>Profile</button>
      </nav>
      
      <main>
        <Suspense fallback={<div>Loading page...</div>}>
          {renderPage()}
        </Suspense>
      </main>
    </div>
  );
}

// Dynamic imports for conditional loading
function ConditionalLoader({ shouldLoadHeavyComponent }) {
  const [HeavyComponent, setHeavyComponent] = useState(null);
  
  useEffect(() => {
    if (shouldLoadHeavyComponent && !HeavyComponent) {
      import('./HeavyComponent').then(module => {
        setHeavyComponent(() => module.default);
      });
    }
  }, [shouldLoadHeavyComponent, HeavyComponent]);
  
  return (
    <div>
      {HeavyComponent ? <HeavyComponent /> : <div>Heavy component not loaded</div>}
    </div>
  );
}

// 5. VIRTUALIZATION FOR LONG LISTS

// Simple virtualization example (in real apps, use react-window or react-virtualized)
function VirtualizedList({ items, itemHeight = 50 }) {
  const [scrollTop, setScrollTop] = useState(0);
  const containerHeight = 400;
  const visibleItems = Math.ceil(containerHeight / itemHeight);
  const startIndex = Math.floor(scrollTop / itemHeight);
  const endIndex = Math.min(startIndex + visibleItems, items.length);
  
  const visibleItemsData = items.slice(startIndex, endIndex);
  
  return (
    <div
      style={{ height: containerHeight, overflow: 'auto' }}
      onScroll={(e) => setScrollTop(e.target.scrollTop)}
    >
      <div style={{ height: items.length * itemHeight, position: 'relative' }}>
        {visibleItemsData.map((item, index) => (
          <div
            key={startIndex + index}
            style={{
              position: 'absolute',
              top: (startIndex + index) * itemHeight,
              height: itemHeight,
              width: '100%'
            }}
          >
            <ListItem item={item} />
          </div>
        ))}
      </div>
    </div>
  );
}

// 6. STATE OPTIMIZATION

// Avoid objects in useState for better performance
function BadPerformanceComponent() {
  // Creates new object reference on every update
  const [state, setState] = useState({ count: 0, name: '' });
  
  const incrementCount = () => {
    setState({ ...state, count: state.count + 1 }); // Recreates entire object
  };
  
  return <div>{state.count}</div>;
}

// Better approach - separate state variables
function BetterPerformanceComponent() {
  const [count, setCount] = useState(0);
  const [name, setName] = useState('');
  
  const incrementCount = () => {
    setCount(prev => prev + 1); // Only updates count
  };
  
  return <div>{count}</div>;
}

// Or use useReducer for complex state
function OptimalPerformanceComponent() {
  const [state, dispatch] = useReducer((state, action) => {
    switch (action.type) {
      case 'INCREMENT':
        return { ...state, count: state.count + 1 };
      case 'SET_NAME':
        return { ...state, name: action.payload };
      default:
        return state;
    }
  }, { count: 0, name: '' });
  
  return <div>{state.count}</div>;
}

// 7. DEBOUNCING FOR PERFORMANCE

function useDebounce(value, delay) {
  const [debouncedValue, setDebouncedValue] = useState(value);
  
  useEffect(() => {
    const handler = setTimeout(() => {
      setDebouncedValue(value);
    }, delay);
    
    return () => {
      clearTimeout(handler);
    };
  }, [value, delay]);
  
  return debouncedValue;
}

function SearchComponent() {
  const [searchTerm, setSearchTerm] = useState('');
  const [results, setResults] = useState([]);
  const debouncedSearchTerm = useDebounce(searchTerm, 300);
  
  useEffect(() => {
    if (debouncedSearchTerm) {
      // API call only happens after user stops typing for 300ms
      searchAPI(debouncedSearchTerm).then(setResults);
    }
  }, [debouncedSearchTerm]);
  
  return (
    <div>
      <input
        type="text"
        value={searchTerm}
        onChange={(e) => setSearchTerm(e.target.value)}
        placeholder="Search..."
      />
      <SearchResults results={results} />
    </div>
  );
}

// 8. PROFILING AND MONITORING

// Performance measurement hook
function usePerformance(name) {
  useEffect(() => {
    performance.mark(`${name}-start`);
    
    return () => {
      performance.mark(`${name}-end`);
      performance.measure(name, `${name}-start`, `${name}-end`);
      
      const measures = performance.getEntriesByName(name);
      const lastMeasure = measures[measures.length - 1];
      console.log(`${name} took ${lastMeasure.duration}ms`);
    };
  });
}

function MonitoredComponent() {
  usePerformance('MonitoredComponent');
  
  // Component logic
  const expensiveCalculation = useMemo(() => {
    // Some expensive operation
    return Array.from({ length: 10000 }, (_, i) => i * 2);
  }, []);
  
  return <div>Monitored component with {expensiveCalculation.length} items</div>;
}

// React DevTools Profiler integration
function ProfiledApp() {
  return (
    <Profiler
      id="App"
      onRender={(id, phase, actualDuration, baseDuration, startTime, commitTime) => {
        console.log('Profiler:', {
          id,
          phase,
          actualDuration,
          baseDuration,
          startTime,
          commitTime
        });
      }}
    >
      <App />
    </Profiler>
  );
}

// 9. BUNDLE SIZE OPTIMIZATION

// Tree shaking friendly imports
import { debounce } from 'lodash-es'; // Better than import _ from 'lodash'

// Dynamic imports for reducing initial bundle size
const Chart = React.lazy(() =>
  import('recharts').then(module => ({
    default: module.LineChart
  }))
);

// 10. PERFORMANCE CHECKLIST
/*
✅ Use React.memo() for pure components
✅ Use useMemo() for expensive calculations  
✅ Use useCallback() for event handlers passed to children
✅ Implement lazy loading for routes and heavy components
✅ Use virtualization for long lists
✅ Debounce user inputs
✅ Optimize bundle size with code splitting
✅ Profile components with React DevTools
✅ Avoid creating objects/functions in render
✅ Use proper key props in lists
✅ Implement error boundaries
✅ Optimize images and assets
✅ Use service workers for caching
✅ Monitor performance metrics
*/
```

**Key Performance Principles:**

1. **Minimize Re-renders**: Use React.memo, useMemo, useCallback
2. **Code Splitting**: Load only what's needed
3. **State Optimization**: Keep state minimal and localized
4. **List Optimization**: Use keys and virtualization
5. **Bundle Optimization**: Tree shaking and dynamic imports
6. **Measurement**: Profile and monitor performance

---

## Navigation

⬅️ **[Previous: TypeScript Questions](./typescript-questions.md)**  
➡️ **[Next: Node.js Questions](./nodejs-questions.md)**  
🏠 **[Home: Research Index](../README.md)**

---

*These React questions cover fundamental concepts, hooks, performance optimization, and modern patterns essential for the Dev Partners Senior Full Stack Developer position.*
