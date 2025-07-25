# Nx Setup Guide and Best Practices

Complete guide for setting up Nx monorepo with React Vite, Express.js apps, and reusable libraries.

## 📚 Table of Contents

### 1. **[Executive Summary](./executive-summary.md)**
   High-level overview of Nx setup, benefits, and recommendations for modern monorepo development

### 2. **[Implementation Guide](./implementation-guide.md)** 
   Step-by-step instructions for setting up Nx from scratch with complete examples

### 3. **[Best Practices](./best-practices.md)**
   Proven patterns for React Vite apps, Express.js services, and shared libraries

### 4. **[CLI Commands Reference](./cli-commands-reference.md)**
   Comprehensive list of useful Nx CLI commands from start to finish

### 5. **[Template Examples](./template-examples.md)**
   Working code examples and project templates for common use cases

### 6. **[Troubleshooting Guide](./troubleshooting.md)**
   Common issues and solutions for Nx development

## 🎯 Research Scope

This research focuses on modern Nx setup (v21.3+) with specific emphasis on:
- **React Vite Applications** - Modern React apps with Vite bundler and TypeScript
- **Express.js Backend Services** - Node.js API services and microservices  
- **Reusable Libraries** - Shared components, utilities, and business logic
- **Development Workflow** - Efficient development practices and tooling
- **Build & Deployment** - Production-ready build configurations

## 📊 Quick Reference

### Technology Stack
| Technology | Version | Purpose |
|------------|---------|---------|
| **Nx** | 21.3+ | Monorepo build system |
| **React** | 18+ | Frontend framework |
| **Vite** | 5+ | Frontend bundler |
| **TypeScript** | 5+ | Type safety |
| **Express.js** | 4+ | Backend framework |
| **Jest** | 29+ | Testing framework |
| **ESLint** | 8+ | Code linting |

### Project Structure
```
my-workspace/
├── apps/
│   ├── web-app/           # React Vite app
│   ├── mobile-app/        # React Native app
│   └── api-server/        # Express.js server
├── libs/
│   ├── shared-ui/         # React components
│   ├── shared-utils/      # Utilities
│   └── api-interfaces/    # TypeScript interfaces
├── tools/
├── nx.json
├── package.json
└── tsconfig.base.json
```

### Essential Commands
```bash
# Create workspace
npx create-nx-workspace@latest

# Add React app with Vite
nx g @nx/react:app my-app --bundler=vite

# Add Express.js app  
nx g @nx/express:app api-server

# Add shared library
nx g @nx/js:lib shared-utils

# Run development server
nx serve my-app

# Build for production
nx build my-app

# Run all tests
nx test

# View dependency graph
nx graph
```

## ✅ Goals Achieved

- ✅ **Complete Setup Guide**: Comprehensive instructions for Nx workspace creation
- ✅ **React Vite Integration**: Best practices for modern React applications with Vite bundler
- ✅ **Express.js Backend Setup**: Full guide for Node.js API development in Nx
- ✅ **Shared Libraries Architecture**: Patterns for reusable components and utilities
- ✅ **CLI Reference**: Complete command reference from initialization to deployment
- ✅ **Real-world Examples**: Working templates and practical use cases
- ✅ **Performance Optimization**: Nx caching, affected builds, and CI/CD strategies
- ✅ **TypeScript Best Practices**: Strong typing across the entire monorepo
- ✅ **Testing Strategies**: Unit testing, e2e testing, and test organization
- ✅ **Troubleshooting Guide**: Common issues and proven solutions

## 🔗 Navigation

**Previous**: N/A | **Next**: [Executive Summary →](./executive-summary.md)

---

### Related Research
- [Open Source Project Creation](../../open-source-project-creation/README.md)
- [Express.js Testing Frameworks](../../backend/express-testing-frameworks-comparison/README.md)
- [Clean Architecture Analysis](../../architecture/clean-architecture-analysis/README.md)

### External Resources
- [Official Nx Documentation](https://nx.dev)
- [Nx Community Plugins](https://nx.dev/plugin-registry)
- [Nx GitHub Repository](https://github.com/nrwl/nx)
- [Nx Examples Repository](https://github.com/nrwl/nx-examples)