# Project Initialization & Tracking

## 📋 Overview

**Proper project initialization** sets the foundation for long-term success in open source development. This guide addresses the specific need for **project age tracking**, **meaningful initial commits**, and **comprehensive project setup** that establishes professional standards from day one.

## 🎯 The "Initial Commit" Strategy

### Understanding the Problem
> "I want some file in a root directory that won't change as much as possible and will serve as date for the 'feat: initial commit' commit, so I can know how long the project is already"

### Why "feat: initial commit" is Not Ideal

#### ❌ Problems with "feat: initial commit"
- **Incorrect categorization**: Initial setup is infrastructure, not a feature
- **Conventional Commit violation**: Doesn't follow established standards
- **Misleading semantics**: Features imply user-facing functionality
- **Version confusion**: Features typically increment minor/major versions

#### ✅ Better Initial Commit Messages

```bash
# Recommended: Infrastructure/Setup focused
git commit -m "chore: initialize Nx workspace with clean architecture"

# Alternative options
git commit -m "chore: bootstrap project with TypeScript and Jest"
git commit -m "init: create Nx monorepo with clean architecture"
git commit -m "setup: initialize open source project structure"

# If you prefer more descriptive
git commit -m "chore: set up Nx workspace for expense tracker monorepo"
```

### Conventional Commit Types for Project Lifecycle

| Type | Usage | Example | Semantic Version Impact |
|------|--------|---------|------------------------|
| **chore** | Setup, maintenance, tooling | `chore: initialize project` | None |
| **init** | Initial project creation | `init: create workspace` | None |
| **feat** | New user-facing features | `feat: add user authentication` | Minor |
| **fix** | Bug fixes | `fix: resolve login validation` | Patch |
| **docs** | Documentation | `docs: add API reference` | None |
| **ci** | CI/CD configuration | `ci: add GitHub Actions` | None |

## 🏗️ Complete Project Initialization Process

### Phase 1: Foundation Setup

#### 1. **Create Repository Structure**
```bash
# Create project directory
mkdir nx-open-source-starter
cd nx-open-source-starter

# Initialize git repository
git init
git branch -M main

# Create initial structure
mkdir -p .github/workflows
mkdir -p .github/ISSUE_TEMPLATE
mkdir -p docs
mkdir -p tools/scripts
```

#### 2. **Create PROJECT_MANIFEST.json** (First File)
```json
{
  "project": {
    "name": "nx-open-source-starter",
    "displayName": "Nx Open Source Starter",
    "description": "Production-ready Nx monorepo starter with clean architecture",
    "created": "2025-01-15",
    "version": "0.0.0",
    "type": "nx-monorepo",
    "architecture": "clean-architecture",
    "license": "MIT"
  },
  "metadata": {
    "initialCommit": "chore: initialize project with manifest and license",
    "repository": "https://github.com/yourusername/nx-open-source-starter",
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
  "tracking": {
    "createdDate": "2025-01-15T10:30:00.000Z",
    "initialCommitHash": "",
    "majorMilestones": []
  }
}
```

#### 3. **Add LICENSE File** (Second File)
```text
MIT License

Copyright (c) 2025 Your Name

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software")...
```

#### 4. **Create Initial .gitignore**
```text
# Dependencies
node_modules/
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# Build outputs
dist/
build/
coverage/

# Environment files
.env
.env.local
.env.*.local

# IDE
.vscode/settings.json
.idea/

# OS
.DS_Store
Thumbs.db

# Nx
.nx/cache
```

#### 5. **First Commit - Foundation**
```bash
git add PROJECT_MANIFEST.json LICENSE .gitignore
git commit -m "chore: initialize project with manifest and license"

# Update manifest with commit hash
COMMIT_HASH=$(git rev-parse HEAD)
# Update PROJECT_MANIFEST.json with the commit hash
```

### Phase 2: Nx Workspace Setup

#### 6. **Initialize Nx Workspace**
```bash
# Initialize Nx workspace (this will modify/create package.json)
npx create-nx-workspace@latest . --preset=empty --name=nx-starter

# Second commit - Nx setup
git add .
git commit -m "chore: set up Nx workspace configuration"
```

#### 7. **Configure TypeScript**
```json
// tsconfig.base.json
{
  "compileOnSave": false,
  "compilerOptions": {
    "rootDir": ".",
    "sourceMap": true,
    "declaration": false,
    "moduleResolution": "node",
    "emitDecoratorMetadata": true,
    "experimentalDecorators": true,
    "importHelpers": true,
    "target": "es2015",
    "module": "esnext",
    "lib": ["es2020", "dom"],
    "skipLibCheck": true,
    "skipDefaultLibCheck": true,
    "baseUrl": ".",
    "strict": true,
    "paths": {}
  },
  "exclude": ["node_modules", "tmp"]
}
```

#### 8. **Third Commit - Development Configuration**
```bash
git add tsconfig.base.json jest.preset.js .eslintrc.json
git commit -m "chore: configure TypeScript, Jest, and ESLint"
```

### Phase 3: Documentation and Community

#### 9. **Create Comprehensive README.md**
```markdown
# Nx Open Source Starter

Production-ready Nx monorepo starter template with clean architecture principles.

## 🚀 Quick Start

```bash
# Clone repository
git clone https://github.com/yourusername/nx-open-source-starter.git
cd nx-open-source-starter

# Install dependencies
npm install

# Start development
npm run dev
```

## 📋 Features

- ✅ Nx Monorepo architecture
- ✅ Clean Architecture patterns
- ✅ TypeScript configuration
- ✅ Jest testing framework
- ✅ ESLint and Prettier
- ✅ GitHub Actions CI/CD
- ✅ Comprehensive documentation

## 🏗️ Project Structure

```text
apps/          # Applications
libs/          # Reusable libraries
tools/         # Build tools and scripts
docs/          # Documentation
```

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 📚 Documentation

For detailed documentation, visit [project documentation](docs/).
```

#### 10. **Add Community Files**
```bash
# Create CONTRIBUTING.md, CODE_OF_CONDUCT.md, etc.
# Fourth commit
git add README.md CONTRIBUTING.md CODE_OF_CONDUCT.md
git commit -m "docs: add project documentation and community guidelines"
```

## 📊 Project Age Tracking Implementation

### 1. **Automated Age Calculation Script**

```javascript
// tools/scripts/project-age.js
const fs = require('fs');
const path = require('path');

class ProjectAgeTracker {
  constructor() {
    this.manifestPath = path.join(process.cwd(), 'PROJECT_MANIFEST.json');
    this.manifest = this.loadManifest();
  }

  loadManifest() {
    if (!fs.existsSync(this.manifestPath)) {
      throw new Error('PROJECT_MANIFEST.json not found');
    }
    return JSON.parse(fs.readFileSync(this.manifestPath, 'utf8'));
  }

  calculateAge() {
    const createdDate = new Date(this.manifest.project.created);
    const now = new Date();
    
    const diffTime = Math.abs(now - createdDate);
    const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
    const diffWeeks = Math.floor(diffDays / 7);
    const diffMonths = Math.floor(diffDays / 30.44); // Average days per month
    const diffYears = Math.floor(diffDays / 365.25); // Account for leap years

    return {
      days: diffDays,
      weeks: diffWeeks,
      months: diffMonths,
      years: diffYears,
      createdDate: createdDate.toISOString(),
      currentDate: now.toISOString()
    };
  }

  generateReport() {
    const age = this.calculateAge();
    const project = this.manifest.project;

    console.log(`
🔍 Project Age Report
=====================
Project: ${project.displayName}
Created: ${age.createdDate}
Current: ${age.currentDate}

📅 Age Breakdown:
- ${age.days} days
- ${age.weeks} weeks  
- ${age.months} months
- ${age.years} years

🏷️ Project Details:
- Type: ${project.type}
- Architecture: ${project.architecture}
- License: ${project.license}
- Version: ${project.version}
`);

    return age;
  }

  addMilestone(milestone) {
    if (!this.manifest.tracking.majorMilestones) {
      this.manifest.tracking.majorMilestones = [];
    }

    this.manifest.tracking.majorMilestones.push({
      ...milestone,
      date: new Date().toISOString(),
      daysSinceStart: this.calculateAge().days
    });

    fs.writeFileSync(this.manifestPath, JSON.stringify(this.manifest, null, 2));
    console.log(`✅ Milestone added: ${milestone.title}`);
  }
}

// CLI Usage
const tracker = new ProjectAgeTracker();

if (process.argv.includes('--report')) {
  tracker.generateReport();
}

if (process.argv.includes('--add-milestone')) {
  const title = process.argv[process.argv.indexOf('--add-milestone') + 1];
  const description = process.argv[process.argv.indexOf('--add-milestone') + 2] || '';
  
  tracker.addMilestone({
    title,
    description,
    version: tracker.manifest.project.version
  });
}

module.exports = ProjectAgeTracker;
```

### 2. **Package.json Scripts Integration**

```json
{
  "scripts": {
    "project:age": "node tools/scripts/project-age.js --report",
    "project:milestone": "node tools/scripts/project-age.js --add-milestone",
    "project:info": "node -e \"const m=require('./PROJECT_MANIFEST.json'); console.log(`${m.project.displayName} v${m.project.version} - Created ${m.project.created}`);\"",
    "project:validate": "node tools/scripts/validate-project.js"
  }
}
```

### 3. **GitHub Actions Integration**

```yaml
# .github/workflows/project-tracking.yml
name: Project Tracking

on:
  push:
    branches: [main]
  release:
    types: [published]

jobs:
  track-project:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'
      
      - name: Generate Project Age Report
        run: |
          npm run project:age
          
      - name: Track Milestone on Release
        if: github.event_name == 'release'
        run: |
          npm run project:milestone "Release ${{ github.event.release.tag_name }}" "Released version ${{ github.event.release.tag_name }}"
          
      - name: Commit Milestone Update
        if: github.event_name == 'release'
        run: |
          git config --local user.email "action@github.com"
          git config --local user.name "GitHub Action"
          git add PROJECT_MANIFEST.json
          git diff --staged --quiet || git commit -m "chore: update milestone for release ${{ github.event.release.tag_name }}"
          git push
```

## 🎯 Milestone Tracking System

### 1. **Predefined Milestones**

```javascript
// tools/scripts/milestone-templates.js
const MILESTONE_TEMPLATES = {
  FIRST_COMMIT: {
    title: 'Project Initialized',
    description: 'First commit with project structure'
  },
  FIRST_FEATURE: {
    title: 'First Feature Implemented',
    description: 'Core functionality completed'
  },
  FIRST_CONTRIBUTOR: {
    title: 'First External Contribution',
    description: 'Community engagement milestone'
  },
  FIRST_RELEASE: {
    title: 'Version 1.0.0 Released',
    description: 'Production-ready release'
  },
  FIRST_100_STARS: {
    title: '100 GitHub Stars',
    description: 'Community adoption milestone'
  }
};

function suggestMilestone(currentState) {
  const age = new ProjectAgeTracker().calculateAge();
  const suggestions = [];

  if (age.days >= 1 && !hasMilestone('FIRST_COMMIT')) {
    suggestions.push(MILESTONE_TEMPLATES.FIRST_COMMIT);
  }

  if (age.days >= 7 && !hasMilestone('FIRST_FEATURE')) {
    suggestions.push(MILESTONE_TEMPLATES.FIRST_FEATURE);
  }

  return suggestions;
}
```

### 2. **Automated Milestone Detection**

```javascript
// tools/scripts/detect-milestones.js
const { execSync } = require('child_process');

function detectMilestones() {
  const tracker = new ProjectAgeTracker();
  
  // Check for first feature commit
  try {
    const featCommits = execSync('git log --oneline --grep="^feat:"').toString();
    if (featCommits && !hasMilestone(tracker, 'FIRST_FEATURE')) {
      tracker.addMilestone({
        title: 'First Feature Implemented',
        description: 'First feature commit detected',
        automatic: true
      });
    }
  } catch (e) {
    // No feature commits yet
  }

  // Check for external contributors
  try {
    const authors = execSync('git log --format="%ae" | sort | uniq').toString().split('\n');
    const manifest = tracker.manifest;
    const authorEmail = manifest.metadata.author.email;
    const externalAuthors = authors.filter(email => email && email !== authorEmail);
    
    if (externalAuthors.length > 0 && !hasMilestone(tracker, 'FIRST_CONTRIBUTOR')) {
      tracker.addMilestone({
        title: 'First External Contribution',
        description: `Contribution from ${externalAuthors[0]}`,
        automatic: true
      });
    }
  } catch (e) {
    // Git log failed
  }
}

function hasMilestone(tracker, milestoneTitle) {
  return tracker.manifest.tracking.majorMilestones?.some(m => m.title.includes(milestoneTitle));
}
```

## 🔄 Version Control Best Practices

### 1. **Commit Message Templates**

```bash
# .gitmessage template
# <type>(<scope>): <description>
#
# <body>
#
# <footer>

# Types: feat, fix, docs, style, refactor, test, chore
# Scopes: domain, ui, api, docs, ci
# 
# Examples:
# feat(auth): add user authentication
# fix(api): resolve CORS configuration
# docs(readme): update installation guide
# chore(deps): update dependencies
```

### 2. **Branch Naming Strategy**

```text
# Feature branches
feature/user-authentication
feature/expense-tracking
feature/reporting-dashboard

# Bug fix branches  
fix/login-validation
fix/cors-configuration

# Chore branches
chore/update-dependencies
chore/improve-documentation

# Release branches
release/v1.0.0
release/v1.1.0
```

### 3. **Git Hooks for Quality**

```bash
#!/bin/sh
# .git/hooks/commit-msg

# Ensure commit follows conventional commits
commit_regex='^(feat|fix|docs|style|refactor|test|chore|ci)(\(.+\))?: .{1,50}'

error_msg="❌ Invalid commit message format. Use: type(scope): description"

if ! grep -qE "$commit_regex" "$1"; then
  echo "$error_msg"
  echo "Examples:"
  echo "  feat(auth): add user login"
  echo "  fix(api): resolve validation error"
  echo "  chore: update dependencies"
  exit 1
fi
```

## 📊 Project Health Monitoring

### 1. **Health Check Script**

```javascript
// tools/scripts/project-health.js
const ProjectAgeTracker = require('./project-age');

class ProjectHealthMonitor {
  constructor() {
    this.tracker = new ProjectAgeTracker();
  }

  checkHealth() {
    const age = this.tracker.calculateAge();
    const manifest = this.tracker.manifest;
    
    const health = {
      age: age,
      lastCommit: this.getLastCommitInfo(),
      contributors: this.getContributorCount(),
      releases: this.getReleaseCount(),
      issues: this.getIssueStats(),
      score: 0
    };

    // Calculate health score
    health.score = this.calculateHealthScore(health);
    
    return health;
  }

  calculateHealthScore(health) {
    let score = 0;
    
    // Age factor (projects gain credibility over time)
    if (health.age.days > 365) score += 30;
    else if (health.age.days > 90) score += 20;
    else if (health.age.days > 30) score += 10;
    
    // Activity factor
    if (health.lastCommit.daysAgo < 7) score += 25;
    else if (health.lastCommit.daysAgo < 30) score += 15;
    else if (health.lastCommit.daysAgo < 90) score += 5;
    
    // Community factor
    if (health.contributors > 10) score += 25;
    else if (health.contributors > 5) score += 15;
    else if (health.contributors > 1) score += 10;
    
    // Release factor
    if (health.releases > 5) score += 20;
    else if (health.releases > 0) score += 10;
    
    return Math.min(score, 100);
  }

  generateReport() {
    const health = this.checkHealth();
    
    console.log(`
🏥 Project Health Report
========================
Overall Health Score: ${health.score}/100

📅 Project Age: ${health.age.days} days
📝 Last Commit: ${health.lastCommit.daysAgo} days ago
👥 Contributors: ${health.contributors}
🚀 Releases: ${health.releases}

${this.getHealthRecommendations(health)}
`);
  }

  getHealthRecommendations(health) {
    const recommendations = [];
    
    if (health.lastCommit.daysAgo > 30) {
      recommendations.push('🔄 Consider making recent commits to show activity');
    }
    
    if (health.contributors <= 1) {
      recommendations.push('👥 Encourage community contributions');
    }
    
    if (health.releases === 0) {
      recommendations.push('🚀 Consider creating your first release');
    }
    
    return recommendations.length > 0 
      ? '\n💡 Recommendations:\n' + recommendations.join('\n')
      : '\n✅ Project health looks good!';
  }
}
```

## ✅ Implementation Checklist

### Foundation Setup
- [ ] **Create PROJECT_MANIFEST.json** with creation date
- [ ] **Add LICENSE file** with proper copyright
- [ ] **Set up .gitignore** with appropriate exclusions
- [ ] **Make initial commit** with proper conventional message
- [ ] **Update manifest** with initial commit hash

### Nx Configuration
- [ ] **Initialize Nx workspace** with empty preset
- [ ] **Configure TypeScript** with strict settings
- [ ] **Set up testing framework** (Jest)
- [ ] **Configure linting** (ESLint + Prettier)
- [ ] **Add dependency constraints** for clean architecture

### Documentation
- [ ] **Create comprehensive README**
- [ ] **Add CONTRIBUTING.md** with development guidelines
- [ ] **Set up CODE_OF_CONDUCT.md** 
- [ ] **Write SECURITY.md** for vulnerability reporting
- [ ] **Create CHANGELOG.md** for version history

### Automation
- [ ] **Set up project age tracking** scripts
- [ ] **Configure milestone detection**
- [ ] **Add GitHub Actions** for CI/CD
- [ ] **Set up health monitoring**
- [ ] **Configure automated publishing**

### Quality Assurance
- [ ] **Add git hooks** for commit message validation
- [ ] **Set up pre-commit checks** (lint, test)
- [ ] **Configure branch protection** rules
- [ ] **Add code coverage** thresholds
- [ ] **Set up security scanning**

---

**Navigation**
- ← Previous: [Nx Monorepo Open Source Setup](./nx-monorepo-open-source-setup.md)
- → Next: [Community & Documentation Standards](./community-documentation-standards.md)
- ↑ Back to: [Main Guide](./README.md)

## 📚 References

- [Conventional Commits Specification](https://www.conventionalcommits.org/)
- [Semantic Versioning](https://semver.org/)
- [Git Commit Message Guidelines](https://tbaggery.com/2008/04/19/a-note-about-git-commit-messages.html)
- [GitHub Flow](https://docs.github.com/en/get-started/quickstart/github-flow)
- [Nx Workspace Configuration](https://nx.dev/reference/project-configuration)
- [Git Hooks Documentation](https://git-scm.com/book/en/v2/Customizing-Git-Git-Hooks)
- [npm Scripts Guide](https://docs.npmjs.com/cli/v8/using-npm/scripts)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)