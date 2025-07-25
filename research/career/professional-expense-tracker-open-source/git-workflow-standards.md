# Git Workflow & Commit Standards

## 🔄 Git Branching Strategy

### GitFlow for Professional Development

#### Branch Structure

```
main (production)
├── develop (integration)
│   ├── feature/expense-tracking
│   ├── feature/budget-management
│   ├── feature/analytics-dashboard
│   └── feature/mobile-app
├── release/v1.0.0
├── hotfix/security-patch
└── hotfix/critical-bug-fix
```

**Branch Types & Purposes**

| Branch Type | Purpose | Naming Convention | Lifetime |
|-------------|---------|-------------------|----------|
| `main` | Production-ready code | `main` | Permanent |
| `develop` | Integration branch | `develop` | Permanent |
| `feature/*` | New features | `feature/feature-name` | Temporary |
| `release/*` | Release preparation | `release/v1.0.0` | Temporary |
| `hotfix/*` | Critical production fixes | `hotfix/issue-description` | Temporary |
| `bugfix/*` | Bug fixes for develop | `bugfix/issue-description` | Temporary |

### Branch Management Rules

#### Feature Branch Workflow

**Creating Feature Branches**

```bash
# Start new feature from develop
git checkout develop
git pull origin develop
git checkout -b feature/expense-categorization

# Work on feature
git add .
git commit -m "feat(expenses): add category selection interface"

# Push feature branch
git push -u origin feature/expense-categorization
```

**Feature Branch Guidelines**

- **Single Responsibility**: One feature per branch
- **Small Scope**: Keep features focused and manageable
- **Regular Sync**: Merge develop regularly to avoid conflicts
- **Clean History**: Squash commits before merging if needed
- **Testing**: Ensure all tests pass before PR creation

#### Release Branch Workflow

**Release Preparation**

```bash
# Create release branch from develop
git checkout develop
git pull origin develop
git checkout -b release/v1.0.0

# Finalize release (version bumps, changelog, etc.)
git add .
git commit -m "chore(release): prepare v1.0.0"

# Merge to main and tag
git checkout main
git merge --no-ff release/v1.0.0
git tag -a v1.0.0 -m "Release version 1.0.0"

# Merge back to develop
git checkout develop
git merge --no-ff release/v1.0.0

# Cleanup
git branch -d release/v1.0.0
```

## 📝 Conventional Commits Standard

### Commit Message Format

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

#### Commit Types

| Type | Purpose | Example |
|------|---------|---------|
| `feat` | New features | `feat(auth): add two-factor authentication` |
| `fix` | Bug fixes | `fix(api): resolve expense validation error` |
| `docs` | Documentation changes | `docs(readme): update installation guide` |
| `style` | Code style changes | `style(ui): apply consistent spacing` |
| `refactor` | Code refactoring | `refactor(utils): extract currency helpers` |
| `perf` | Performance improvements | `perf(db): optimize expense queries` |
| `test` | Test additions/modifications | `test(expenses): add integration tests` |
| `build` | Build system changes | `build(nx): update workspace configuration` |
| `ci` | CI/CD changes | `ci(github): add security scanning` |
| `chore` | Maintenance tasks | `chore(deps): update dependencies` |
| `revert` | Revert previous commit | `revert: "feat(auth): add oauth login"` |

#### Scope Guidelines

**Recommended Scopes for Expense Tracker**

```
- auth (authentication/authorization)
- expenses (expense management)
- budgets (budget functionality)
- analytics (reporting/analytics)
- ui (user interface components)
- api (backend API)
- db (database changes)
- mobile (mobile app specific)
- docs (documentation)
- tests (testing)
- deps (dependencies)
- config (configuration)
```

### Commit Message Examples

#### Good Commit Messages

```bash
# Feature additions
feat(expenses): implement recurring expense automation
feat(analytics): add spending trend visualization
feat(mobile): integrate camera for receipt capture

# Bug fixes
fix(auth): resolve session timeout issue
fix(budget): correct calculation for monthly limits
fix(ui): fix mobile responsive layout

# Documentation
docs(api): add OpenAPI specification examples
docs(deployment): update Docker setup instructions

# Refactoring
refactor(expenses): extract validation logic to shared library
refactor(ui): convert class components to hooks

# Performance
perf(db): add indexes for expense queries
perf(frontend): implement lazy loading for charts

# Breaking changes
feat(api)!: restructure expense endpoint response format

BREAKING CHANGE: The expense API now returns normalized data structure.
Migration guide available in docs/migration.md
```

#### Bad Commit Messages (Avoid)

```bash
# Too vague
fix: bug fix
update: changes
docs: update

# No type prefix
add login functionality
remove old code
update README

# Inconsistent formatting
Fix: authentication Bug
FEAT: Add new feature
docs:update documentation (missing space)
```

### Commit Message Tools

#### Commitizen Setup

```bash
# Install commitizen globally
npm install -g commitizen cz-conventional-changelog

# Configure in package.json
{
  "config": {
    "commitizen": {
      "path": "./node_modules/cz-conventional-changelog"
    }
  }
}

# Use commitizen for commits
git add .
git cz  # Instead of git commit
```

#### Commit Validation

**commitlint Configuration**

```javascript
// commitlint.config.js
module.exports = {
  extends: ['@commitlint/config-conventional'],
  rules: {
    'type-enum': [
      2,
      'always',
      [
        'feat',
        'fix',
        'docs',
        'style',
        'refactor',
        'perf',
        'test',
        'build',
        'ci',
        'chore',
        'revert'
      ]
    ],
    'scope-enum': [
      2,
      'always',
      [
        'auth',
        'expenses',
        'budgets',
        'analytics',
        'ui',
        'api',
        'db',
        'mobile',
        'docs',
        'tests',
        'deps',
        'config'
      ]
    ],
    'subject-max-length': [2, 'always', 72],
    'subject-case': [2, 'always', 'lower-case'],
    'header-max-length': [2, 'always', 100]
  }
};
```

**Husky Pre-commit Hooks**

```json
{
  "husky": {
    "hooks": {
      "commit-msg": "commitlint -E HUSKY_GIT_PARAMS",
      "pre-commit": "lint-staged"
    }
  },
  "lint-staged": {
    "*.{ts,tsx,js,jsx}": [
      "eslint --fix",
      "prettier --write",
      "git add"
    ],
    "*.{md,json}": [
      "prettier --write",
      "git add"
    ]
  }
}
```

## 🔀 Pull Request Process

### PR Creation Guidelines

#### PR Title Format

```
<type>[scope]: <description>
```

**Examples**

```
feat(expenses): implement expense categorization system
fix(auth): resolve JWT token expiration handling
docs(api): add comprehensive endpoint documentation
```

#### PR Description Template

```markdown
## 📋 Description

Brief summary of changes and motivation.

## 🔗 Related Issue

Closes #123

## 🧪 Testing

- [ ] Unit tests added/updated
- [ ] Integration tests added/updated
- [ ] E2E tests added/updated
- [ ] Manual testing completed

## 📱 Screenshots/Demo

[Include screenshots for UI changes]

## ✅ Checklist

- [ ] Code follows project style guidelines
- [ ] Self-review completed
- [ ] Documentation updated
- [ ] No breaking changes (or documented)
- [ ] Tests pass locally
- [ ] Security considerations addressed

## 🚀 Deployment Notes

Any special deployment considerations or database migrations needed.
```

### Code Review Standards

#### Review Checklist

**Code Quality**

- [ ] **Readability**: Code is clear and well-commented
- [ ] **Maintainability**: Follows SOLID principles
- [ ] **Performance**: No obvious performance issues
- [ ] **Security**: No security vulnerabilities
- [ ] **Testing**: Adequate test coverage

**Technical Standards**

- [ ] **TypeScript**: Proper type definitions
- [ ] **Error Handling**: Comprehensive error handling
- [ ] **Documentation**: Updated documentation
- [ ] **Dependencies**: No unnecessary dependencies
- [ ] **API Design**: RESTful and consistent

#### Review Comments Guidelines

**Constructive Feedback Examples**

```markdown
# ✅ Good feedback
Consider extracting this logic into a separate function for better testability:

```typescript
// Suggested refactor
const calculateTaxAmount = (amount: number, rate: number): number => {
  return amount * rate;
};
```

# ✅ Security suggestion
This endpoint should include rate limiting to prevent abuse:

```typescript
app.use('/api/auth', rateLimiter({ max: 5, windowMs: 60000 }));
```

# ❌ Poor feedback
This is wrong.
Needs improvement.
Bad code.
```

### Version Control Best Practices

#### Git Configuration

```bash
# Set up Git user information
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"

# Configure line ending handling
git config --global core.autocrlf true  # Windows
git config --global core.autocrlf input # macOS/Linux

# Set default branch name
git config --global init.defaultBranch main

# Enable rebase by default for pulls
git config --global pull.rebase true

# Set up credential caching
git config --global credential.helper cache
```

#### Gitignore Best Practices

```gitignore
# Dependencies
node_modules/
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# Production builds
dist/
build/
.next/

# Environment variables
.env
.env.local
.env.production

# IDE files
.vscode/
.idea/
*.swp
*.swo

# OS files
.DS_Store
Thumbs.db

# Logs
logs/
*.log

# Runtime data
pids/
*.pid
*.seed
*.pid.lock

# Coverage directory used by tools like istanbul
coverage/
.nyc_output/

# Database
*.sqlite
*.db

# Cache directories
.cache/
.nx/cache/

# Temporary files
tmp/
temp/
```

## 🏷️ Release Management

### Semantic Versioning

**Version Format**: `MAJOR.MINOR.PATCH`

- **MAJOR**: Breaking changes
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes (backward compatible)

#### Version Examples

```
1.0.0 - Initial release
1.1.0 - Add budget management features
1.1.1 - Fix expense calculation bug
1.2.0 - Add mobile app
2.0.0 - API restructure (breaking changes)
```

### Release Process

#### Automated Release with GitHub Actions

```yaml
name: Release

on:
  push:
    branches: [main]

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
          
      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          
      - name: Install dependencies
        run: npm ci
        
      - name: Run tests
        run: npm test
        
      - name: Build application
        run: npm run build
        
      - name: Generate changelog
        run: npx conventional-changelog-cli -p angular -i CHANGELOG.md -s
        
      - name: Create release
        uses: semantic-release/semantic-release@v22
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          NPM_TOKEN: ${{ secrets.NPM_TOKEN }}
```

#### Manual Release Checklist

- [ ] All features tested and documented
- [ ] Version number updated in package.json
- [ ] CHANGELOG.md updated with release notes
- [ ] All tests passing
- [ ] Security scan completed
- [ ] Performance benchmarks met
- [ ] Documentation updated
- [ ] Migration guides created (if needed)

---

## 🔗 Navigation

| Previous | Current | Next |
|----------|---------|------|
| [← Implementation Roadmap](./implementation-roadmap.md) | **Git Workflow Standards** | [Main Guide →](./README.md) |

---

## 📚 References

- [Conventional Commits Specification](https://www.conventionalcommits.org/)
- [Git Flow Workflow](https://www.atlassian.com/git/tutorials/comparing-workflows/gitflow-workflow)
- [Semantic Versioning](https://semver.org/)
- [GitHub Flow Guide](https://guides.github.com/introduction/flow/)
- [Angular Commit Message Guidelines](https://github.com/angular/angular/blob/main/CONTRIBUTING.md#-commit-message-format)
