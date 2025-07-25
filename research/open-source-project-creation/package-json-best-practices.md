# Package.json Best Practices for Open Source Projects

## 📋 Overview

The `package.json` file serves as the **project's primary metadata source** and is crucial for **npm publishing**, **dependency management**, and **project discovery**. This guide provides comprehensive best practices for configuring `package.json` files in open source projects, with specific considerations for **Nx monorepo architecture**.

## 🔧 Essential Fields Configuration

### 1. **Project Identity Fields**

#### `name`
```json
{
  "name": "@your-org/project-name",
  "name": "project-name"
}
```

**Best Practices:**
- ✅ Use **kebab-case** (lowercase with hyphens)
- ✅ Include **organization scope** for npm organizations: `@your-org/package-name`
- ✅ Keep it **concise but descriptive** (max 50 characters)
- ✅ Avoid trademarked names or confusing similarities

**Examples from Popular Projects:**
```json
// Good examples
"name": "@angular/core"
"name": "create-react-app"
"name": "@nestjs/common"
"name": "nx"

// Avoid
"name": "MyAwesome-Project_2024"  // Mixed case, underscore
"name": "a"                       // Too short
"name": "super-long-name-that-describes-everything-about-project"  // Too long
```

#### `version`
```json
{
  "version": "0.0.0"
}
```

**Semantic Versioning (SemVer) Strategy:**
- ✅ Start with **`0.0.0`** for initial development
- ✅ Use **`0.1.0`** for first functional version
- ✅ Follow **MAJOR.MINOR.PATCH** format
- ✅ Increment **MAJOR** for breaking changes
- ✅ Increment **MINOR** for new features
- ✅ Increment **PATCH** for bug fixes

#### `description`
```json
{
  "description": "A clean architecture Nx monorepo starter template with TypeScript, React, and Node.js"
}
```

**Guidelines:**
- ✅ **One sentence** that clearly explains the project
- ✅ Include **key technologies** and **use case**
- ✅ **50-150 characters** for optimal display
- ✅ Avoid marketing language, focus on functionality

### 2. **Author and Maintainer Information**

#### `author`
```json
{
  "author": "John Doe <john.doe@example.com> (https://johndoe.dev)"
}
```

**Alternative Object Format:**
```json
{
  "author": {
    "name": "John Doe",
    "email": "john.doe@example.com",
    "url": "https://johndoe.dev"
  }
}
```

**Best Practices:**
- ✅ Include **full name** for professional credibility
- ✅ Use **professional email** (avoid personal emails)
- ✅ Add **personal website or portfolio** URL
- ✅ Consider using **GitHub profile** URL if no personal site

#### `contributors` (for team projects)
```json
{
  "contributors": [
    "Jane Smith <jane.smith@example.com>",
    "Mike Johnson <mike@example.com> (https://mikejohnson.dev)"
  ]
}
```

### 3. **Legal and Licensing**

#### `license`
```json
{
  "license": "MIT"
}
```

**Common Open Source Licenses:**
```json
// Most permissive (recommended for open source)
"license": "MIT"

// Good for corporate environments
"license": "Apache-2.0"

// Copyleft requirement
"license": "GPL-3.0"

// Simple attribution
"license": "BSD-3-Clause"

// Custom or proprietary
"license": "SEE LICENSE IN LICENSE.txt"
```

**License Selection Guide:**

| License | Best For | Permissions | Limitations |
|---------|----------|-------------|-------------|
| **MIT** | Maximum adoption, portfolio projects | Commercial use, modification, distribution | Must include license |
| **Apache 2.0** | Corporate projects, patent protection | Commercial use, patent use | Must include license, state changes |
| **GPL 3.0** | Copyleft projects | Commercial use, modification | Must disclose source, same license |
| **BSD 3-Clause** | Academic/research projects | Commercial use, modification | Must include license, no endorsement |

### 4. **Repository and Links**

#### `repository`
```json
{
  "repository": {
    "type": "git",
    "url": "https://github.com/username/repository-name"
  }
}
```

**Alternative String Format:**
```json
{
  "repository": "github:username/repository-name"
}
```

#### `homepage`
```json
{
  "homepage": "https://username.github.io/project-name"
}
```

#### `bugs`
```json
{
  "bugs": {
    "url": "https://github.com/username/repository-name/issues",
    "email": "support@example.com"
  }
}
```

### 5. **Project Discovery and SEO**

#### `keywords`
```json
{
  "keywords": [
    "nx",
    "monorepo",
    "typescript",
    "react",
    "nodejs",
    "clean-architecture",
    "starter-template",
    "open-source"
  ]
}
```

**Keyword Strategy:**
- ✅ **5-15 keywords** for optimal discovery
- ✅ Include **primary technologies** (nx, react, typescript)
- ✅ Add **architectural patterns** (clean-architecture, monorepo)
- ✅ Include **project type** (starter, template, library)
- ✅ Use **lowercase** and **common terms**

### 6. **Runtime and Environment**

#### `engines`
```json
{
  "engines": {
    "node": ">=18.0.0",
    "npm": ">=8.0.0"
  }
}
```

**Best Practices:**
- ✅ Specify **minimum Node.js version** your project supports
- ✅ Include **npm/yarn version** if specific features needed
- ✅ Test with **multiple Node.js versions** in CI
- ✅ Update regularly to **latest LTS versions**

#### `os` (if platform-specific)
```json
{
  "os": ["darwin", "linux", "win32"]
}
```

### 7. **Publishing Configuration**

#### `publishConfig`
```json
{
  "publishConfig": {
    "access": "public",
    "registry": "https://registry.npmjs.org/"
  }
}
```

#### `files`
```json
{
  "files": [
    "dist/",
    "lib/",
    "README.md",
    "LICENSE",
    "CHANGELOG.md"
  ]
}
```

**Include in Published Package:**
- ✅ Built **output directories** (dist/, lib/, build/)
- ✅ **Documentation files** (README.md, CHANGELOG.md)
- ✅ **Legal files** (LICENSE, NOTICE)
- ❌ Source files (src/ unless needed)
- ❌ Development files (.gitignore, .eslintrc)
- ❌ Test files (tests/, __tests__)

## 📁 Nx Monorepo Considerations

### Root Package.json Template
```json
{
  "name": "@your-org/nx-monorepo",
  "version": "0.0.0",
  "description": "Nx monorepo starter with clean architecture and TypeScript",
  "author": "Your Name <your.email@example.com> (https://yoursite.dev)",
  "license": "MIT",
  "repository": {
    "type": "git",
    "url": "https://github.com/yourusername/nx-monorepo"
  },
  "homepage": "https://yourusername.github.io/nx-monorepo",
  "keywords": [
    "nx",
    "monorepo",
    "typescript",
    "clean-architecture",
    "starter-template"
  ],
  "engines": {
    "node": ">=18.0.0",
    "npm": ">=8.0.0"
  },
  "private": true,
  "workspaces": [
    "apps/*",
    "libs/*"
  ],
  "scripts": {
    "build": "nx build",
    "test": "nx test",
    "lint": "nx lint",
    "affected:build": "nx affected:build",
    "affected:test": "nx affected:test"
  },
  "devDependencies": {
    "@nx/workspace": "latest",
    "typescript": "latest"
  }
}
```

### Application Package.json Template
```json
{
  "name": "@your-org/web-app",
  "version": "0.0.0",
  "description": "Web application built with React and clean architecture",
  "author": "Your Name <your.email@example.com>",
  "license": "MIT",
  "private": false,
  "keywords": [
    "react",
    "typescript",
    "web-app"
  ],
  "main": "src/main.tsx",
  "dependencies": {
    "react": "^18.0.0",
    "react-dom": "^18.0.0"
  }
}
```

### Library Package.json Template
```json
{
  "name": "@your-org/ui-components",
  "version": "0.0.0",
  "description": "Reusable UI components library",
  "author": "Your Name <your.email@example.com>",
  "license": "MIT",
  "main": "./index.js",
  "types": "./index.d.ts",
  "exports": {
    ".": {
      "import": "./esm/index.js",
      "require": "./cjs/index.js",
      "types": "./index.d.ts"
    }
  },
  "keywords": [
    "ui-components",
    "react",
    "typescript",
    "component-library"
  ],
  "peerDependencies": {
    "react": ">=16.8.0",
    "react-dom": ">=16.8.0"
  }
}
```

## 🔍 Advanced Configuration

### 1. **Module System Support**

#### Dual Package Support (ESM + CommonJS)
```json
{
  "main": "./dist/cjs/index.js",
  "module": "./dist/esm/index.js",
  "types": "./dist/types/index.d.ts",
  "exports": {
    ".": {
      "import": "./dist/esm/index.js",
      "require": "./dist/cjs/index.js",
      "types": "./dist/types/index.d.ts"
    },
    "./package.json": "./package.json"
  }
}
```

### 2. **TypeScript Configuration**
```json
{
  "types": "./dist/index.d.ts",
  "typesVersions": {
    "*": {
      "*": ["./dist/types/*"]
    }
  }
}
```

### 3. **Browser Compatibility**
```json
{
  "browser": "./dist/browser/index.js",
  "unpkg": "./dist/umd/index.min.js",
  "jsdelivr": "./dist/umd/index.min.js"
}
```

### 4. **Funding and Sponsorship**
```json
{
  "funding": [
    {
      "type": "github",
      "url": "https://github.com/sponsors/yourusername"
    },
    {
      "type": "patreon",
      "url": "https://patreon.com/yourusername"
    }
  ]
}
```

## ✅ Validation Checklist

### Pre-Publish Checklist
- [ ] **Name** - Unique, descriptive, follows npm naming conventions
- [ ] **Version** - Follows semantic versioning
- [ ] **Description** - Clear, concise, includes key technologies
- [ ] **Author** - Complete contact information
- [ ] **License** - Matches LICENSE file content
- [ ] **Repository** - Correct GitHub URL
- [ ] **Keywords** - Relevant, discoverable terms
- [ ] **Engines** - Minimum Node.js version specified
- [ ] **Files** - Only necessary files included in package

### Quality Assurance
- [ ] **Dependencies** - All listed dependencies are used
- [ ] **Peer Dependencies** - Correctly specified for libraries
- [ ] **Scripts** - All scripts work correctly
- [ ] **Exports** - Module exports work in both ESM and CJS
- [ ] **Types** - TypeScript declarations included

## 🚨 Common Mistakes to Avoid

### Critical Errors
- ❌ **Missing license field** - Prevents legal usage
- ❌ **Incorrect repository URL** - Breaks npm/GitHub integration
- ❌ **Version not following SemVer** - Confuses dependency management
- ❌ **Private: true with intended publishing** - Prevents npm publish

### Quality Issues
- ❌ **Generic description** - Reduces discoverability
- ❌ **No keywords** - Poor SEO and discovery
- ❌ **Missing author information** - Unprofessional appearance
- ❌ **Outdated engines** - Compatibility issues

### Publishing Problems
- ❌ **Including source files** - Bloats package size
- ❌ **Missing main entry** - Package won't load
- ❌ **Incorrect file paths** - Broken imports
- ❌ **Missing peer dependencies** - Runtime errors

---

**Navigation**
- ← Previous: [Executive Summary](./executive-summary.md)
- → Next: [LICENSE File Analysis](./license-file-analysis.md)
- ↑ Back to: [Main Guide](./README.md)

## 📚 References

- [npm Package.json Documentation](https://docs.npmjs.com/cli/v8/configuring-npm/package-json)
- [Semantic Versioning Specification](https://semver.org/)
- [Node.js Package.json Guide](https://nodejs.org/en/knowledge/getting-started/npm/what-is-the-file-package-json/)
- [TypeScript Package.json Configuration](https://www.typescriptlang.org/docs/handbook/declaration-files/publishing.html)
- [Nx Package.json Best Practices](https://nx.dev/reference/project-configuration)
- [Open Source License Chooser](https://choosealicense.com/)
- [NPM Registry Search Algorithm](https://github.blog/2013-09-16-how-we-made-github-fast/)
- [Package.json Validator Tool](https://www.npmjs.com/package/package-json-validator)