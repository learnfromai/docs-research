# Clean Architecture for Open Source Projects

## 📋 Overview

**Clean Architecture** principles become even more critical in **open source projects** where **code maintainability**, **contributor onboarding**, and **long-term sustainability** are paramount. This guide provides specific architectural patterns and practices tailored for **open source development** using **Nx monorepo** structure.

## 🏛️ Clean Architecture Fundamentals for Open Source

### Core Principles Applied to Open Source

#### 1. **Dependency Inversion Principle**
**Open Source Benefit**: Contributors can easily understand and modify business logic without being coupled to frameworks or external libraries.

```typescript
// ❌ Poor: Business logic coupled to framework
export class UserService {
  constructor(private httpClient: AxiosInstance) {}
  
  async createUser(userData: any) {
    // Business logic mixed with HTTP concerns
    return this.httpClient.post('/users', userData);
  }
}

// ✅ Good: Business logic independent
export interface UserRepository {
  save(user: User): Promise<void>;
  findById(id: string): Promise<User | null>;
}

export class CreateUserUseCase {
  constructor(private userRepo: UserRepository) {}
  
  async execute(userData: CreateUserRequest): Promise<User> {
    // Pure business logic - easy to test and understand
    const user = new User(userData);
    await this.userRepo.save(user);
    return user;
  }
}
```

#### 2. **Single Responsibility Principle**
**Open Source Benefit**: Smaller, focused modules are easier for new contributors to understand and modify.

#### 3. **Open-Closed Principle**
**Open Source Benefit**: New features can be added without modifying existing code, reducing merge conflicts.

#### 4. **Interface Segregation Principle**
**Open Source Benefit**: Contributors work with minimal, focused interfaces rather than large, complex ones.

## 🏗️ Nx Monorepo Clean Architecture Structure

### Recommended Directory Structure
```text
apps/
├── web-app/                    # Presentation Layer
│   ├── src/
│   │   ├── app/               # React components & pages
│   │   ├── adapters/          # External service adapters
│   │   └── main.tsx           # Application entry point
│   └── project.json
├── api-gateway/               # API Layer
│   ├── src/
│   │   ├── controllers/       # HTTP request handlers
│   │   ├── middleware/        # Cross-cutting concerns
│   │   └── main.ts           # Server entry point
│   └── project.json
└── admin-dashboard/           # Admin Interface
    └── src/
        ├── features/          # Feature-based organization
        └── shared/           # Shared components

libs/
├── domain/                    # Business Logic (Core)
│   ├── entities/             # Domain entities
│   ├── use-cases/           # Business use cases
│   ├── value-objects/       # Domain value objects
│   └── interfaces/          # Domain interfaces
├── infrastructure/           # External Concerns
│   ├── database/            # Database implementations
│   ├── messaging/           # Message queues
│   ├── external-apis/       # Third-party API clients
│   └── file-storage/        # File storage implementations
├── shared/                   # Cross-cutting Concerns
│   ├── ui-components/       # Reusable UI components
│   ├── utilities/           # Pure functions & helpers
│   ├── types/              # Shared TypeScript definitions
│   └── constants/          # Application constants
└── application/             # Application Services
    ├── services/            # Application services
    ├── dto/                # Data transfer objects
    └── mappers/            # Data transformation
```

### Layer Responsibilities

#### Domain Layer (`libs/domain/`)
**Purpose**: Core business logic and rules
**Dependencies**: None (innermost layer)
**Open Source Benefits**:
- ✅ **Framework Independent**: Easy to test and understand
- ✅ **Stable API**: Rarely changes, reducing contributor confusion
- ✅ **Clear Boundaries**: New contributors understand business rules quickly

```typescript
// libs/domain/entities/user.entity.ts
export class User {
  private constructor(
    private readonly id: UserId,
    private readonly email: Email,
    private readonly profile: UserProfile,
    private readonly createdAt: Date
  ) {}

  static create(data: CreateUserData): User {
    // Business validation logic
    if (!data.email || !data.name) {
      throw new Error('Email and name are required');
    }
    
    return new User(
      UserId.generate(),
      Email.from(data.email),
      UserProfile.create(data),
      new Date()
    );
  }

  updateProfile(profileData: UpdateProfileData): void {
    // Business logic for profile updates
    this.profile.update(profileData);
  }

  // Getters for accessing private data
  getId(): string { return this.id.value; }
  getEmail(): string { return this.email.value; }
}
```

#### Application Layer (`libs/application/`)
**Purpose**: Orchestrate domain objects and external services
**Dependencies**: Domain layer only
**Open Source Benefits**:
- ✅ **Use Case Focused**: Clear feature boundaries
- ✅ **Testable**: Easy to mock dependencies
- ✅ **Documented Intent**: Use cases serve as living documentation

```typescript
// libs/application/use-cases/create-user.use-case.ts
export class CreateUserUseCase {
  constructor(
    private readonly userRepo: UserRepository,
    private readonly emailService: EmailService,
    private readonly logger: Logger
  ) {}

  async execute(request: CreateUserRequest): Promise<CreateUserResponse> {
    this.logger.info('Creating new user', { email: request.email });

    // Domain logic
    const user = User.create({
      email: request.email,
      name: request.name,
      preferences: request.preferences
    });

    // Infrastructure concerns
    await this.userRepo.save(user);
    await this.emailService.sendWelcomeEmail(user.getEmail());

    this.logger.info('User created successfully', { userId: user.getId() });

    return CreateUserResponse.from(user);
  }
}
```

#### Infrastructure Layer (`libs/infrastructure/`)
**Purpose**: External dependencies and framework-specific code
**Dependencies**: Domain and Application layers
**Open Source Benefits**:
- ✅ **Swappable Implementations**: Contributors can easily change databases, APIs
- ✅ **Clear Contracts**: Interfaces define exactly what's needed
- ✅ **Testing Support**: Easy to create test doubles

```typescript
// libs/infrastructure/database/postgres-user.repository.ts
export class PostgresUserRepository implements UserRepository {
  constructor(private readonly db: Database) {}

  async save(user: User): Promise<void> {
    await this.db.query(
      'INSERT INTO users (id, email, profile, created_at) VALUES ($1, $2, $3, $4)',
      [user.getId(), user.getEmail(), user.getProfile(), user.getCreatedAt()]
    );
  }

  async findById(id: string): Promise<User | null> {
    const result = await this.db.query(
      'SELECT * FROM users WHERE id = $1',
      [id]
    );
    
    return result.rows[0] ? User.fromDatabase(result.rows[0]) : null;
  }
}
```

#### Presentation Layer (`apps/`)
**Purpose**: User interfaces and external APIs
**Dependencies**: Application layer only
**Open Source Benefits**:
- ✅ **Framework Agnostic**: Business logic isn't tied to UI framework
- ✅ **Multiple Interfaces**: Easy to add new apps (mobile, CLI, etc.)
- ✅ **Clear Separation**: UI concerns separate from business logic

```typescript
// apps/web-app/src/components/CreateUserForm.tsx
export const CreateUserForm: React.FC = () => {
  const [formData, setFormData] = useState<CreateUserFormData>(initialState);
  const { mutate: createUser, isLoading } = useCreateUser();

  const handleSubmit = (e: FormEvent) => {
    e.preventDefault();
    
    // Simple data transformation, no business logic
    createUser({
      email: formData.email,
      name: formData.name,
      preferences: formData.preferences
    });
  };

  return (
    <form onSubmit={handleSubmit}>
      {/* Form JSX */}
    </form>
  );
};
```

## 🔧 Dependency Management in Nx

### Project.json Configuration for Clean Architecture
```json
// libs/domain/project.json
{
  "name": "domain",
  "type": "library",
  "implicitDependencies": [],
  "targets": {
    "build": {
      "executor": "@nx/js:tsc"
    },
    "test": {
      "executor": "@nx/jest:jest"
    }
  },
  "tags": ["domain", "scope:shared", "type:business-logic"]
}

// libs/application/project.json
{
  "name": "application",
  "type": "library",
  "implicitDependencies": ["domain"],
  "tags": ["application", "scope:shared", "type:use-cases"]
}

// libs/infrastructure/project.json
{
  "name": "infrastructure",
  "type": "library",
  "implicitDependencies": ["domain", "application"],
  "tags": ["infrastructure", "scope:shared", "type:adapters"]
}
```

### Nx Dependency Constraints
```json
// nx.json
{
  "namedInputs": {
    "default": ["{projectRoot}/**/*", "sharedGlobals"],
    "production": ["default"]
  },
  "targetDefaults": {
    "build": {
      "dependsOn": ["^build"]
    }
  },
  "tasksRunnerOptions": {
    "default": {
      "runner": "nx/tasks-runners/default",
      "options": {
        "cacheableOperations": ["build", "test", "lint"]
      }
    }
  },
  "generators": {
    "@nx/react": {
      "application": {
        "style": "css",
        "linter": "eslint",
        "bundler": "vite"
      }
    }
  }
}
```

## 📏 ESLint Rules for Clean Architecture

### Custom ESLint Configuration
```javascript
// .eslintrc.js
module.exports = {
  extends: ["@nx/eslint-plugin-nx/recommended"],
  overrides: [
    {
      files: ["*.ts", "*.tsx"],
      rules: {
        // Enforce dependency constraints
        "@nx/enforce-module-boundaries": [
          "error",
          {
            allow: [],
            depConstraints: [
              // Domain layer can't depend on anything
              {
                sourceTag: "domain",
                onlyDependOnLibsWithTags: []
              },
              // Application can only depend on domain
              {
                sourceTag: "application", 
                onlyDependOnLibsWithTags: ["domain"]
              },
              // Infrastructure can depend on domain & application
              {
                sourceTag: "infrastructure",
                onlyDependOnLibsWithTags: ["domain", "application"]
              },
              // Apps can depend on all layers
              {
                sourceTag: "scope:app",
                onlyDependOnLibsWithTags: ["domain", "application", "infrastructure", "shared"]
              }
            ]
          }
        ]
      }
    }
  ]
};
```

## 🧪 Testing Strategy for Clean Architecture

### Layer-Specific Testing Approaches

#### Domain Layer Testing
```typescript
// libs/domain/entities/__tests__/user.entity.spec.ts
describe('User Entity', () => {
  describe('create', () => {
    it('should create user with valid data', () => {
      // No mocking needed - pure business logic
      const userData = {
        email: 'test@example.com',
        name: 'Test User'
      };

      const user = User.create(userData);

      expect(user.getEmail()).toBe('test@example.com');
      expect(user.getName()).toBe('Test User');
    });

    it('should throw error for invalid email', () => {
      const userData = { email: 'invalid-email', name: 'Test User' };

      expect(() => User.create(userData)).toThrow('Invalid email format');
    });
  });
});
```

#### Application Layer Testing
```typescript
// libs/application/use-cases/__tests__/create-user.use-case.spec.ts
describe('CreateUserUseCase', () => {
  let useCase: CreateUserUseCase;
  let mockUserRepo: jest.Mocked<UserRepository>;
  let mockEmailService: jest.Mocked<EmailService>;

  beforeEach(() => {
    mockUserRepo = {
      save: jest.fn(),
      findById: jest.fn()
    };
    mockEmailService = {
      sendWelcomeEmail: jest.fn()
    };
    
    useCase = new CreateUserUseCase(mockUserRepo, mockEmailService);
  });

  it('should create user and send welcome email', async () => {
    const request = {
      email: 'test@example.com',
      name: 'Test User'
    };

    const result = await useCase.execute(request);

    expect(mockUserRepo.save).toHaveBeenCalledWith(expect.any(User));
    expect(mockEmailService.sendWelcomeEmail).toHaveBeenCalledWith('test@example.com');
    expect(result.userId).toBeDefined();
  });
});
```

#### Infrastructure Layer Testing
```typescript
// libs/infrastructure/database/__tests__/postgres-user.repository.spec.ts
describe('PostgresUserRepository', () => {
  let repository: PostgresUserRepository;
  let mockDb: jest.Mocked<Database>;

  beforeEach(() => {
    mockDb = {
      query: jest.fn()
    };
    repository = new PostgresUserRepository(mockDb);
  });

  it('should save user to database', async () => {
    const user = User.create({
      email: 'test@example.com',
      name: 'Test User'
    });

    await repository.save(user);

    expect(mockDb.query).toHaveBeenCalledWith(
      expect.stringContaining('INSERT INTO users'),
      expect.arrayContaining([user.getId(), user.getEmail()])
    );
  });
});
```

## 🚀 Open Source Specific Benefits

### 1. **Contributor Onboarding**
```typescript
// Clear, focused interfaces make it easy for new contributors
export interface PaymentGateway {
  processPayment(amount: Money, card: CreditCard): Promise<PaymentResult>;
}

// Contributors can implement new payment providers easily
export class StripePaymentGateway implements PaymentGateway {
  async processPayment(amount: Money, card: CreditCard): Promise<PaymentResult> {
    // Stripe-specific implementation
  }
}

export class PayPalPaymentGateway implements PaymentGateway {
  async processPayment(amount: Money, card: CreditCard): Promise<PaymentResult> {
    // PayPal-specific implementation
  }
}
```

### 2. **Feature Development Independence**
```text
# Multiple contributors can work simultaneously
Contributor A: Adding new domain entity (User Profile)
Contributor B: Adding new use case (Export Data)
Contributor C: Adding new infrastructure adapter (Redis Cache)
Contributor D: Adding new UI component (Data Visualization)

# No conflicts because layers are independent
```

### 3. **Documentation Through Code**
```typescript
// Use cases serve as living documentation
export class ExportUserDataUseCase {
  /**
   * Exports all user data in compliance with GDPR requirements.
   * 
   * @param userId - The ID of the user requesting data export
   * @param format - Export format (JSON, CSV, XML)
   * @returns Promise containing export file path and metadata
   */
  async execute(request: ExportDataRequest): Promise<ExportDataResponse> {
    // Implementation shows exactly what the feature does
  }
}
```

### 4. **Easy Technology Migration**
```typescript
// Swapping databases is straightforward
// Old: PostgreSQL
const userRepo = new PostgresUserRepository(postgresDb);

// New: MongoDB  
const userRepo = new MongoUserRepository(mongoDb);

// Business logic remains unchanged
const createUserUseCase = new CreateUserUseCase(userRepo, emailService);
```

## 📋 Implementation Checklist

### Project Setup
- [ ] **Create domain library** with entities and value objects
- [ ] **Create application library** with use cases and DTOs
- [ ] **Create infrastructure library** with external adapters
- [ ] **Set up Nx dependency constraints** to enforce architecture
- [ ] **Configure ESLint rules** for layer boundaries

### Code Organization
- [ ] **Define domain interfaces** for all external dependencies
- [ ] **Implement use cases** with clear input/output contracts
- [ ] **Create infrastructure adapters** implementing domain interfaces
- [ ] **Separate presentation logic** from business logic
- [ ] **Add comprehensive test coverage** for each layer

### Documentation
- [ ] **Document architecture decisions** in ADRs
- [ ] **Create contributor guide** explaining layer structure
- [ ] **Add code examples** for each architectural pattern
- [ ] **Maintain architecture diagrams** showing dependencies
- [ ] **Write testing guidelines** for each layer

### Quality Assurance
- [ ] **Set up automated architecture tests** using ArchUnit or similar
- [ ] **Configure dependency analysis** in CI/CD pipeline
- [ ] **Add performance benchmarks** for critical use cases
- [ ] **Implement security scanning** for each layer
- [ ] **Set up code coverage thresholds** per layer

---

**Navigation**
- ← Previous: [Project Structure & Root Files](./project-structure-root-files.md)
- → Next: [Nx Monorepo Open Source Setup](./nx-monorepo-open-source-setup.md)
- ↑ Back to: [Main Guide](./README.md)

## 📚 References

- [Clean Architecture by Robert Martin](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)
- [Nx Dependency Management](https://nx.dev/core-features/enforce-project-boundaries)
- [Domain-Driven Design](https://martinfowler.com/bliki/DomainDrivenDesign.html)
- [Hexagonal Architecture](https://alistair.cockburn.us/hexagonal-architecture/)
- [Testing Strategies for Clean Architecture](https://blog.cleancoder.com/uncle-bob/2014/05/14/TheLittleMocker.html)
- [SOLID Principles](https://web.archive.org/web/20150906155800/http://www.objectmentor.com/resources/articles/Principles_and_Patterns.pdf)
- [Onion Architecture](https://jeffreypalermo.com/2008/07/the-onion-architecture-part-1/)
- [Nx Monorepo Best Practices](https://nx.dev/concepts/more-concepts)