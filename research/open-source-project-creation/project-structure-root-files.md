# Project Structure & Root Files for Open Source Projects

## 📋 Overview

Establishing a **well-organized project structure** with **appropriate root files** is crucial for open source success. This guide addresses the specific need for **project age tracking** through unchanging root files while providing comprehensive coverage of essential project structure elements for **Nx monorepo** projects.

## 🎯 Project Age Tracking Solution

### The Challenge
> "I want some file in a root directory that won't change as much as possible and will serve as date for the 'feat: initial commit' commit, so I can know how long the project is already"

### The Solution: PROJECT_MANIFEST.json

**Purpose**: A **machine-readable manifest** that captures essential project metadata and rarely changes after initial creation.

#### Complete PROJECT_MANIFEST.json Template
```json
{
  "project": {
    "name": "nx-starter-clean-architecture",
    "displayName": "Nx Clean Architecture Starter",
    "description": "A production-ready Nx monorepo starter with clean architecture principles",
    "created": "2025-01-15",
    "type": "nx-monorepo",
    "architecture": "clean-architecture",
    "license": "MIT",
    "version": "0.0.0"
  },
  "metadata": {
    "initialCommit": "feat: initialize Nx workspace with clean architecture",
    "repository": "https://github.com/yourusername/nx-starter",
    "documentation": "https://yourusername.github.io/nx-starter",
    "author": {
      "name": "Your Name",
      "email": "your.email@example.com",
      "url": "https://yoursite.dev"
    }
  },
  "structure": {
    "monorepo": true,
    "workspaceType": "nx",
    "packageManager": "npm",
    "language": "typescript"
  },
  "compliance": {
    "openSource": true,
    "security": "standard",
    "accessibility": "wcag-2.1",
    "testing": "comprehensive"
  }
}
```

### Benefits of PROJECT_MANIFEST.json

#### ✅ Unchanging Reference
- **Rarely modified** after initial creation
- **Machine-readable** for automation
- **Version controlled** with exact creation date
- **Immutable metadata** for project tracking

#### ✅ Project Intelligence
- **Age calculation**: `Date.now() - new Date(manifest.project.created)`
- **Architecture documentation**: Clear architectural decisions
- **Compliance tracking**: Standards and requirements
- **Automation support**: CI/CD can read project metadata

#### ✅ Professional Appearance
- **Standardized format** across projects
- **Complete metadata** in one place
- **Easy to parse** for tools and scripts
- **Portfolio enhancement** for professional projects

### Usage Examples

#### Age Calculation Script
```javascript
// scripts/project-age.js
const fs = require('fs');
const manifest = JSON.parse(fs.readFileSync('PROJECT_MANIFEST.json', 'utf8'));

const createdDate = new Date(manifest.project.created);
const now = new Date();
const ageInDays = Math.floor((now - createdDate) / (1000 * 60 * 60 * 24));

console.log(`Project "${manifest.project.displayName}" is ${ageInDays} days old`);
```

#### README Generation
```javascript
// scripts/update-readme.js
const manifest = require('../PROJECT_MANIFEST.json');

const readmeContent = `
# ${manifest.project.displayName}

${manifest.project.description}

**Created**: ${manifest.project.created}
**Architecture**: ${manifest.structure.architecture}
**License**: ${manifest.project.license}
`;
```

## 🏗️ Complete Root Directory Structure

### Recommended Root Structure
```text
nx-monorepo/
├── 📄 PROJECT_MANIFEST.json      # Project metadata & age tracking
├── 📄 LICENSE                    # Open source license
├── 📄 README.md                  # Project overview & setup
├── 📄 CHANGELOG.md              # Version history
├── 📄 CONTRIBUTING.md           # Contribution guidelines
├── 📄 CODE_OF_CONDUCT.md        # Community standards
├── 📄 SECURITY.md               # Security policy
├── 📄 package.json              # Workspace configuration
├── 📄 nx.json                   # Nx workspace configuration
├── 📄 workspace.json            # Legacy Nx config (if needed)
├── 📄 tsconfig.base.json        # TypeScript base configuration
├── 📄 .gitignore                # Git ignore rules
├── 📄 .npmrc                    # NPM configuration
├── 📁 .github/                  # GitHub configuration
│   ├── 📁 ISSUE_TEMPLATE/       # Issue templates
│   ├── 📁 workflows/            # GitHub Actions
│   ├── 📄 pull_request_template.md
│   ├── 📄 CODEOWNERS
│   └── 📄 FUNDING.yml
├── 📁 .vscode/                  # VS Code settings
├── 📁 apps/                     # Nx applications
├── 📁 libs/                     # Nx libraries
├── 📁 tools/                    # Build tools & scripts
├── 📁 docs/                     # Additional documentation
└── 📁 dist/                     # Build output (gitignored)
```

## 📄 Essential Root Files Analysis

### 1. **PROJECT_MANIFEST.json** ⭐ (New Innovation)
**Purpose**: Project metadata and age tracking
**Frequency of Change**: Rarely (only for major project changes)
**Gitignore**: No - should be committed

### 2. **LICENSE**
**Purpose**: Legal framework for usage
**Frequency of Change**: Never (unless major license change)
**Gitignore**: No - critical for open source

### 3. **README.md**
**Purpose**: Primary project documentation
**Frequency of Change**: Regular updates
**Gitignore**: No - essential for users

### 4. **package.json**
**Purpose**: Workspace configuration and metadata
**Frequency of Change**: Regular (dependencies, scripts)
**Gitignore**: No - required for npm/node

### 5. **CHANGELOG.md**
**Purpose**: Version history tracking
**Frequency of Change**: Every release
**Gitignore**: No - important for users

### 6. **nx.json**
**Purpose**: Nx workspace configuration
**Frequency of Change**: Occasional (Nx updates)
**Gitignore**: No - required for Nx functionality

### 7. **tsconfig.base.json**
**Purpose**: TypeScript configuration
**Frequency of Change**: Rare (TS upgrades)
**Gitignore**: No - required for TypeScript compilation

## 🛡️ Root Files That Should NOT Change Often

### Ideal for Project Age Tracking

| File | Change Frequency | Age Tracking Score | Notes |
|------|------------------|-------------------|--------|
| **PROJECT_MANIFEST.json** | ⭐ Rarely | 10/10 | Designed specifically for this purpose |
| **LICENSE** | Never | 9/10 | Only changes for major license shifts |
| **Initial .gitignore** | Rarely | 8/10 | Core patterns rarely change |
| **tsconfig.base.json** | Rarely | 7/10 | Base config is stable |
| **Initial README structure** | Occasionally | 6/10 | Content changes, structure stable |

### Files That Change Frequently (Avoid for Age Tracking)

| File | Change Frequency | Age Tracking Score | Notes |
|------|------------------|-------------------|--------|
| **package.json** | Regular | 3/10 | Dependencies and scripts change often |
| **CHANGELOG.md** | Every release | 2/10 | Constantly updated |
| **README.md content** | Regular | 4/10 | Features and instructions evolve |
| **nx.json** | Occasional | 5/10 | Configuration evolves with project |

## 🎨 Root Directory Best Practices

### 1. **File Naming Conventions**
```text
✅ UPPERCASE for important docs: LICENSE, README.md, CHANGELOG.md
✅ lowercase for config: package.json, nx.json, .gitignore
✅ Descriptive names: PROJECT_MANIFEST.json, CONTRIBUTING.md
❌ Generic names: config.json, docs.md
```

### 2. **Directory Organization**
```text
✅ Logical grouping: .github/ for GitHub-specific files
✅ Tool-specific: .vscode/ for editor settings
✅ Clear purpose: docs/ for additional documentation
❌ Mixed purposes: config/ containing both build and git files
```

### 3. **Documentation Hierarchy**
```text
1. README.md          # Primary entry point
2. PROJECT_MANIFEST.json  # Project metadata
3. CONTRIBUTING.md    # Developer guide
4. docs/             # Extended documentation
5. Individual app/lib READMEs  # Specific documentation
```

## 🏭 Nx Monorepo Specific Structure

### Apps Directory Structure
```text
apps/
├── web-app/                    # Main web application
│   ├── project.json
│   ├── package.json
│   ├── README.md
│   └── src/
├── mobile-app/                 # Mobile application
│   ├── project.json
│   ├── package.json
│   └── src/
└── api-gateway/               # Backend API
    ├── project.json
    ├── package.json
    └── src/
```

### Libraries Directory Structure
```text
libs/
├── shared/
│   ├── ui-components/         # Shared UI components
│   ├── utilities/            # Pure functions & helpers
│   └── types/               # TypeScript definitions
├── domain/
│   ├── user-management/      # User domain logic
│   ├── expense-tracking/     # Business logic
│   └── reporting/           # Report generation
└── data-access/
    ├── api-client/          # API communication
    ├── database/            # Database access
    └── storage/             # Local storage
```

### Tools Directory Structure
```text
tools/
├── scripts/                  # Build & deployment scripts
│   ├── build.js
│   ├── deploy.js
│   └── test.js
├── eslint-rules/            # Custom ESLint rules
├── webpack-plugins/         # Custom Webpack plugins
└── generators/              # Nx generators & schematics
```

## 🔧 Automation Integration

### PROJECT_MANIFEST.json Automation Examples

#### GitHub Actions Integration
```yaml
# .github/workflows/project-info.yml
name: Project Information

on: [push]

jobs:
  project-info:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Display Project Age
        run: |
          PROJECT_CREATED=$(node -p "require('./PROJECT_MANIFEST.json').project.created")
          echo "Project created: $PROJECT_CREATED"
          node -e "
            const manifest = require('./PROJECT_MANIFEST.json');
            const created = new Date(manifest.project.created);
            const now = new Date();
            const days = Math.floor((now - created) / (1000 * 60 * 60 * 24));
            console.log(\`Project age: \${days} days\`);
          "
```

#### Package.json Script Integration
```json
{
  "scripts": {
    "project:info": "node -e \"const m=require('./PROJECT_MANIFEST.json'); console.log(`${m.project.displayName} - ${m.project.description}`);\"",
    "project:age": "node -e \"const m=require('./PROJECT_MANIFEST.json'); const age=Math.floor((Date.now()-new Date(m.project.created))/(1000*60*60*24)); console.log(`Project age: ${age} days`);\"",
    "project:validate": "node tools/scripts/validate-manifest.js"
  }
}
```

### Validation Script Example
```javascript
// tools/scripts/validate-manifest.js
const fs = require('fs');
const path = require('path');

const manifestPath = path.join(process.cwd(), 'PROJECT_MANIFEST.json');

if (!fs.existsSync(manifestPath)) {
  console.error('❌ PROJECT_MANIFEST.json not found');
  process.exit(1);
}

const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));

// Validate required fields
const required = [
  'project.name',
  'project.created',
  'project.license',
  'metadata.author.name'
];

let valid = true;
for (const field of required) {
  const value = field.split('.').reduce((obj, key) => obj?.[key], manifest);
  if (!value) {
    console.error(`❌ Missing required field: ${field}`);
    valid = false;
  }
}

if (valid) {
  console.log('✅ PROJECT_MANIFEST.json is valid');
  
  // Calculate and display project age
  const created = new Date(manifest.project.created);
  const age = Math.floor((Date.now() - created) / (1000 * 60 * 60 * 24));
  console.log(`📅 Project "${manifest.project.displayName}" is ${age} days old`);
} else {
  process.exit(1);
}
```

## 📊 Project Structure Templates

### Minimal Open Source Nx Project
```text
nx-minimal/
├── PROJECT_MANIFEST.json
├── LICENSE
├── README.md
├── package.json
├── nx.json
├── .gitignore
├── apps/
│   └── web-app/
└── libs/
    └── shared/
```

### Complete Open Source Nx Project
```text
nx-complete/
├── PROJECT_MANIFEST.json
├── LICENSE
├── README.md
├── CHANGELOG.md
├── CONTRIBUTING.md
├── CODE_OF_CONDUCT.md
├── SECURITY.md
├── package.json
├── nx.json
├── tsconfig.base.json
├── .gitignore
├── .npmrc
├── .github/
├── .vscode/
├── apps/
├── libs/
├── tools/
├── docs/
└── dist/
```

## ✅ Implementation Checklist

### Project Initialization
- [ ] **Create PROJECT_MANIFEST.json** with complete metadata
- [ ] **Add LICENSE file** matching project needs
- [ ] **Set up root README.md** with project overview
- [ ] **Configure package.json** with workspace settings
- [ ] **Initialize Nx configuration** (nx.json)
- [ ] **Create .gitignore** with appropriate rules

### Community Files
- [ ] **Add CONTRIBUTING.md** with development guidelines
- [ ] **Create CODE_OF_CONDUCT.md** with community standards
- [ ] **Set up SECURITY.md** with vulnerability reporting
- [ ] **Configure issue templates** in .github/
- [ ] **Add pull request template**

### Development Infrastructure
- [ ] **Set up TypeScript configuration**
- [ ] **Configure linting and formatting**
- [ ] **Add testing framework**
- [ ] **Create build scripts**
- [ ] **Set up CI/CD pipeline**

### Documentation
- [ ] **Write comprehensive README**
- [ ] **Document API interfaces**
- [ ] **Create usage examples**
- [ ] **Add architecture diagrams**
- [ ] **Set up documentation site** (optional)

---

**Navigation**
- ← Previous: [LICENSE File Analysis](./license-file-analysis.md)
- → Next: [Clean Architecture for Open Source](./clean-architecture-open-source.md)
- ↑ Back to: [Main Guide](./README.md)

## 📚 References

- [Nx Workspace Configuration](https://nx.dev/reference/project-configuration)
- [GitHub Community Standards](https://docs.github.com/en/communities/setting-up-your-project-for-healthy-contributions)
- [Open Source Project Structure Guide](https://opensource.guide/starting-a-project/)
- [Semantic Versioning](https://semver.org/)
- [Keep a Changelog](https://keepachangelog.com/)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [TypeScript Project Configuration](https://www.typescriptlang.org/docs/handbook/project-config.html)
- [NPM Package.json Fields](https://docs.npmjs.com/cli/v8/configuring-npm/package-json)