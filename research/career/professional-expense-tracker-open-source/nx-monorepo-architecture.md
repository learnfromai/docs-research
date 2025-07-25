# Nx Monorepo Architecture

## 🏗️ Workspace Structure & Organization

### Core Nx Monorepo Benefits

**Why Nx for Expense Tracker?**

- **Scalability**: Support multiple applications (web, mobile, admin) in single repository
- **Code Sharing**: Reusable libraries for UI components, utilities, and business logic
- **Developer Experience**: Intelligent build system with caching and task orchestration
- **Modern Tooling**: Integrated testing, linting, and code generation capabilities
- **Performance**: Only build and test affected projects on changes

### Recommended Workspace Structure

```text
expense-tracker/
├── apps/
│   ├── web-app/                    # Next.js web application
│   ├── mobile-app/                 # React Native mobile app
│   ├── api-server/                 # Express.js backend API
│   ├── admin-dashboard/            # Administrative interface
│   └── docs-site/                  # Docusaurus documentation
├── libs/
│   ├── shared/
│   │   ├── ui/                     # Shared UI components
│   │   ├── utils/                  # Common utilities
│   │   ├── types/                  # TypeScript type definitions
│   │   ├── constants/              # Application constants
│   │   └── config/                 # Configuration management
│   ├── api/
│   │   ├── core/                   # Core API logic
│   │   ├── auth/                   # Authentication services
│   │   ├── expenses/               # Expense management
│   │   ├── users/                  # User management
│   │   └── reports/                # Reporting services
│   ├── database/
│   │   ├── schema/                 # Database schemas
│   │   ├── migrations/             # Database migrations
│   │   └── seeders/                # Test data seeders
│   └── features/
│       ├── expense-tracking/       # Expense tracking feature
│       ├── budget-management/      # Budget management feature
│       ├── analytics/              # Analytics and reporting
│       └── user-settings/          # User preferences
├── tools/
│   ├── scripts/                    # Custom build scripts
│   ├── generators/                 # Code generators
│   ├── eslint-rules/               # Custom ESLint rules
│   └── webpack-plugins/            # Custom webpack plugins
├── dist/                           # Build outputs
├── node_modules/                   # Dependencies
├── .nx/                           # Nx cache and metadata
├── nx.json                        # Nx workspace configuration
├── package.json                   # Root package.json
├── tsconfig.base.json             # Base TypeScript configuration
└── workspace.json                 # Workspace projects configuration
```

## 🔧 Nx Configuration Files

### 1. **nx.json** - Workspace Configuration

```json
{
  "tasksRunnerOptions": {
    "default": {
      "runner": "nx/tasks-runners/default",
      "options": {
        "cacheableOperations": ["build", "lint", "test", "e2e"]
      }
    }
  },
  "targetDefaults": {
    "build": {
      "dependsOn": ["^build"],
      "inputs": ["production", "^production"]
    },
    "test": {
      "inputs": ["default", "^production", "{workspaceRoot}/jest.preset.js"]
    },
    "lint": {
      "inputs": [
        "default", 
        "{workspaceRoot}/.eslintrc.json",
        "{workspaceRoot}/.eslintignore"
      ]
    }
  },
  "namedInputs": {
    "default": ["{projectRoot}/**/*", "sharedGlobals"],
    "production": [
      "default",
      "!{projectRoot}/**/?(*.)+(spec|test).[jt]s?(x)?(.snap)",
      "!{projectRoot}/tsconfig.spec.json",
      "!{projectRoot}/jest.config.[jt]s",
      "!{projectRoot}/.eslintrc.json"
    ],
    "sharedGlobals": []
  },
  "generators": {
    "@nx/react": {
      "application": {
        "style": "styled-components",
        "linter": "eslint",
        "bundler": "vite"
      },
      "component": {
        "style": "styled-components"
      },
      "library": {
        "style": "styled-components",
        "linter": "eslint"
      }
    },
    "@nx/next": {
      "application": {
        "style": "styled-components",
        "linter": "eslint"
      }
    }
  }
}
```

### 2. **project.json** Example - Web App

```json
{
  "name": "web-app",
  "$schema": "../../node_modules/nx/schemas/project-schema.json",
  "sourceRoot": "apps/web-app",
  "projectType": "application",
  "targets": {
    "build": {
      "executor": "@nx/next:build",
      "outputs": ["{options.outputPath}"],
      "defaultConfiguration": "production",
      "options": {
        "outputPath": "dist/apps/web-app"
      },
      "configurations": {
        "development": {
          "outputPath": "dist/apps/web-app"
        },
        "production": {
          "fileReplacements": [
            {
              "replace": "apps/web-app/environments/environment.ts",
              "with": "apps/web-app/environments/environment.prod.ts"
            }
          ]
        }
      }
    },
    "serve": {
      "executor": "@nx/next:dev",
      "defaultConfiguration": "development",
      "options": {
        "buildTarget": "web-app:build",
        "dev": true
      },
      "configurations": {
        "development": {
          "buildTarget": "web-app:build:development",
          "hmr": true
        },
        "production": {
          "buildTarget": "web-app:build:production",
          "hmr": false
        }
      }
    },
    "test": {
      "executor": "@nx/jest:jest",
      "outputs": ["{workspaceRoot}/coverage/{projectRoot}"],
      "options": {
        "jestConfig": "apps/web-app/jest.config.ts"
      }
    },
    "lint": {
      "executor": "@nx/eslint:lint",
      "outputs": ["{options.outputFile}"],
      "options": {
        "lintFilePatterns": ["apps/web-app/**/*.{ts,tsx,js,jsx}"]
      }
    }
  },
  "tags": ["scope:web", "type:app"]
}
```

## 🧩 Library Organization Strategy

### Shared Libraries

#### **@expense-tracker/shared-ui**

**Purpose**: Reusable UI components across all applications

```typescript
// libs/shared/ui/src/lib/button/button.tsx
export interface ButtonProps {
  variant: 'primary' | 'secondary' | 'danger';
  size: 'sm' | 'md' | 'lg';
  disabled?: boolean;
  onClick?: () => void;
  children: React.ReactNode;
}

export const Button: React.FC<ButtonProps> = ({ ... }) => {
  // Component implementation
};
```

#### **@expense-tracker/shared-types**

**Purpose**: TypeScript type definitions and interfaces

```typescript
// libs/shared/types/src/lib/expense.types.ts
export interface Expense {
  id: string;
  amount: number;
  currency: string;
  description: string;
  category: Category;
  date: Date;
  userId: string;
  receiptUrl?: string;
  tags: string[];
}

export interface Category {
  id: string;
  name: string;
  color: string;
  icon: string;
  parentId?: string;
}
```

#### **@expense-tracker/shared-utils**

**Purpose**: Common utility functions and helpers

```typescript
// libs/shared/utils/src/lib/currency.utils.ts
export const formatCurrency = (
  amount: number,
  currency: string,
  locale = 'en-US'
): string => {
  return new Intl.NumberFormat(locale, {
    style: 'currency',
    currency,
  }).format(amount);
};

export const convertCurrency = async (
  amount: number,
  fromCurrency: string,
  toCurrency: string
): Promise<number> => {
  // Currency conversion implementation
};
```

### Feature Libraries

#### **@expense-tracker/feature-expense-tracking**

**Purpose**: Complete expense tracking functionality

```typescript
// libs/features/expense-tracking/src/lib/hooks/use-expenses.ts
export const useExpenses = (filters?: ExpenseFilters) => {
  const [expenses, setExpenses] = useState<Expense[]>([]);
  const [loading, setLoading] = useState(false);
  
  // Hook implementation
  
  return {
    expenses,
    loading,
    addExpense,
    updateExpense,
    deleteExpense,
    refreshExpenses
  };
};
```

### API Libraries

#### **@expense-tracker/api-core**

**Purpose**: Core API functionality and middleware

```typescript
// libs/api/core/src/lib/middleware/auth.middleware.ts
export const authMiddleware = (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  // Authentication logic
};

// libs/api/core/src/lib/validation/schemas.ts
export const expenseSchema = z.object({
  amount: z.number().positive(),
  description: z.string().min(1).max(255),
  categoryId: z.string().uuid(),
  date: z.date(),
});
```

## 🏷️ Dependency Graph & Tags

### Project Tags Strategy

```json
{
  "projects": {
    "web-app": {
      "tags": ["scope:web", "type:app"]
    },
    "api-server": {
      "tags": ["scope:api", "type:app"]
    },
    "shared-ui": {
      "tags": ["scope:shared", "type:lib", "platform:web"]
    },
    "feature-expense-tracking": {
      "tags": ["scope:features", "type:lib", "domain:expenses"]
    }
  }
}
```

### Dependency Rules

```json
{
  "depConstraints": [
    {
      "sourceTag": "type:app",
      "onlyDependOnLibsWithTags": ["type:lib"]
    },
    {
      "sourceTag": "scope:shared",
      "notDependOnLibsWithTags": ["scope:features", "scope:api"]
    },
    {
      "sourceTag": "scope:api",
      "onlyDependOnLibsWithTags": ["scope:shared", "scope:api"]
    },
    {
      "sourceTag": "domain:expenses",
      "onlyDependOnLibsWithTags": ["scope:shared", "domain:expenses"]
    }
  ]
}
```

## 🚀 Development Workflow

### Common Nx Commands

```bash
# Generate new application
nx g @nx/next:app web-app

# Generate new library
nx g @nx/js:lib shared-utils --directory=libs/shared

# Generate new component in library
nx g @nx/react:component button --project=shared-ui

# Build specific project
nx build web-app

# Test specific project
nx test api-server

# Lint all projects
nx lint

# Run affected tests (only projects affected by changes)
nx affected:test

# Build affected projects
nx affected:build

# View dependency graph
nx graph

# Reset Nx cache
nx reset
```

### Development Scripts

```json
{
  "scripts": {
    "start": "nx serve web-app",
    "start:api": "nx serve api-server",
    "build": "nx build web-app",
    "build:api": "nx build api-server",
    "test": "nx test",
    "test:affected": "nx affected:test",
    "lint": "nx workspace-lint && nx lint",
    "lint:fix": "nx lint --fix",
    "format": "nx format:write",
    "format:check": "nx format:check",
    "dep-graph": "nx graph",
    "clean": "nx reset && rm -rf dist"
  }
}
```

## ⚙️ Build and Optimization

### Nx Cloud Integration

```json
{
  "tasksRunnerOptions": {
    "default": {
      "runner": "@nrwl/nx-cloud",
      "options": {
        "cacheableOperations": [
          "build",
          "test",
          "lint",
          "e2e"
        ],
        "accessToken": "your-nx-cloud-token"
      }
    }
  }
}
```

### Performance Optimizations

- **Incremental Builds**: Only rebuild affected projects
- **Smart Rebuilds**: Skip builds when inputs haven't changed
- **Distributed Caching**: Share build cache across team
- **Parallel Execution**: Run tasks in parallel when possible
- **Code Splitting**: Automatic code splitting for web applications

## 📦 Package Management

### Workspace Dependencies

```json
{
  "devDependencies": {
    "@nx/cypress": "^18.0.0",
    "@nx/eslint": "^18.0.0",
    "@nx/jest": "^18.0.0",
    "@nx/js": "^18.0.0",
    "@nx/next": "^18.0.0",
    "@nx/node": "^18.0.0",
    "@nx/react": "^18.0.0",
    "@nx/vite": "^18.0.0",
    "@nx/workspace": "^18.0.0",
    "nx": "^18.0.0"
  }
}
```

### Library Publishing (Future)

```json
{
  "targets": {
    "publish": {
      "executor": "@nx/js:npm",
      "options": {
        "buildTarget": "shared-ui:build",
        "packageRoot": "dist/libs/shared/ui"
      }
    }
  }
}
```

---

## 🔗 Navigation

| Previous | Current | Next |
|----------|---------|------|
| [← Open Source Requirements](./open-source-requirements.md) | **Nx Monorepo Architecture** | [Expense Tracker Features →](./expense-tracker-features.md) |

---

## 📚 References

- [Nx.dev Official Documentation](https://nx.dev/)
- [Nx Workspace Configuration](https://nx.dev/reference/nx-json)
- [Nx Project Configuration](https://nx.dev/reference/project-configuration)
- [Nx Dependency Management](https://nx.dev/features/enforce-module-boundaries)
- [Nx Performance Guide](https://nx.dev/recipes/running-tasks/run-tasks-in-parallel)
