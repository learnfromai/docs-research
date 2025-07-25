# GitHub Copilot Instructions - Docs Personal

## 0.1 Important!!
1. We have a local copy of the documentations repository at:
~/Documents/vilmarcabanero/code/personal/copilot/docs-context/
Always use this local copy to double check or verify any code, documentation or any output that you generate.
2. There might be symlinks created in the `target` directory:
   - `./target/docs-context`
You can refer to them too for easier access.
3. Always try to look for the documentation in the `./target/docs-context` directory first as there might be separate
documentations for the same tool but with different version.
---

## Project Context
This workspace is a **GitBook-compatible personal documentation space** that serves as a comprehensive knowledge base containing:

### Main Categories
- **📚 Research** - Technical research and analysis on various topics
- **📋 How-Tos** - Step-by-step instructions and implementation guides
- **📝 Notes** - Quick references, learnings, and insights
- **🛠️ Tools** - Tool comparisons, setup guides, and configurations
- **📖 References** - Documentation context and external resources
- Include more categories as needed

### Research Subcategories
- **Frontend** - React, Vue, Angular, modern web technologies
- **Backend** - Node.js, APIs, databases, server architecture
- **Cloud** - AWS, Azure, GCP, serverless, infrastructure
- **SRE** - Site reliability, monitoring, observability, DevOps
- **Testing** - E2E, unit testing, performance testing frameworks
- **Networking** - Protocols, security, load balancing, CDNs
- **Security** - Authentication, authorization, encryption, best practices
- Include more subcategories as needed

## GitBook Sync Compatibility

### File Structure Requirements
This workspace **MUST** maintain GitBook sync compatibility:

#### Required Root Files
- `.gitbook.yaml` - GitBook configuration
- `README.md` - Homepage/landing page
- `SUMMARY.md` - Table of contents for GitBook navigation

#### Directory Organization
```text
docs-personal/
├── .gitbook.yaml              # GitBook config
├── README.md                  # Homepage
├── SUMMARY.md                 # Navigation structure
├── research/                  # Research documentation
│   ├── frontend/             # Frontend technologies
│   ├── backend/              # Backend technologies
│   ├── cloud/                # Cloud platforms & services
│   ├── sre/                  # Site reliability engineering
│   ├── testing/              # Testing frameworks & strategies
│   ├── networking/           # Network technologies
│   └── security/             # Security practices
├── how-tos/                  # Implementation guides
│   ├── installations/        # Setup & installation guides
│   ├── configurations/       # Configuration guides
│   ├── implementations/      # Architecture implementations
│   └── migrations/           # Migration guides
├── notes/                    # Quick references & learnings
│   ├── quick-reference/      # Cheat sheets
│   ├── troubleshooting/      # Common issues & solutions
│   └── learnings/            # Personal insights
├── tools/                    # Tool documentation
│   ├── comparisons/          # Tool comparison analyses
│   ├── setups/               # Tool setup guides
│   └── configurations/       # Tool configurations
└── references/               # External resources & context
    └── docs-context/         # Local documentation context
```

## For how-tos, notes, tools include more subcategories as needed

## GitBook Markdown Guidelines

### Page Structure
Every page should follow GitBook markdown conventions:

#### Required Elements
1. **Clear H1 Title** - Page title that matches navigation
2. **Brief Description** - 1-2 sentence overview
3. **Table of Contents** - For longer documents
4. **Structured Content** - Use proper heading hierarchy (H1 → H6)

#### GitBook-Specific Features
Use GitBook markdown extensions when appropriate:

```markdown
{% hint style="info" %}
This is an info hint for important information
{% endhint %}

{% hint style="warning" %}
This is a warning for potential issues
{% endhint %}

{% hint style="danger" %}
This is for critical warnings
{% endhint %}

{% tabs %}
{% tab title="JavaScript" %}
```javascript
// JavaScript code example
```
{% endtab %}

{% tab title="TypeScript" %}
```typescript
// TypeScript code example
```
{% endtab %}
{% endtabs %}
```

### SUMMARY.md Management
**CRITICAL**: Always update `SUMMARY.md` when creating new content:

#### Structure Format
```markdown
# Table of Contents

## Getting Started
* [Welcome](README.md)

## 📚 Research
* [Frontend Technologies](research/frontend/README.md)
  * [React MVVM Architecture](research/frontend/react-mvvm-clean-architecture.md)
  * [Modern React Stack](research/frontend/modern-react-stack.md)
* [Backend Technologies](research/backend/README.md)
  * [Express MVVM Pattern](research/backend/express-mvvm-clean-architecture.md)
* [Cloud Platforms](research/cloud/README.md)
* [SRE & DevOps](research/sre/README.md)
* [Testing Frameworks](research/testing/README.md)
  * [E2E Testing Analysis](research/testing/ui-webapp-e2e-frameworks.md)
  * [API Testing with Supertest](research/testing/supertest-jest-api-testing.md)
* [Networking](research/networking/README.md)
* [Security](research/security/README.md)

## 📋 How-Tos
* [Installation Guides](how-tos/installations/README.md)
  * [Dual Boot Linux Setup](how-tos/installations/dual-boot-linux-complete-guide.md)
* [Configuration Guides](how-tos/configurations/README.md)
* [Implementation Guides](how-tos/implementations/README.md)
  * [Clean Architecture Setup](how-tos/implementations/clean-architecture-implementation.md)

## 📝 Notes
* [Quick References](notes/quick-reference/README.md)
* [Troubleshooting](notes/troubleshooting/README.md)
* [Personal Learnings](notes/learnings/README.md)

## 🛠️ Tools
* [Tool Comparisons](tools/comparisons/README.md)
* [Setup Guides](tools/setups/README.md)
* [Configurations](tools/configurations/README.md)

## 📖 References
* [Documentation Context](references/docs-context/README.md)
```

## Content Creation Guidelines

### Research Documents
When creating research documents, follow this enhanced structure:

#### Required Sections for Research
1. **Title & Overview** - Clear title with 1-2 sentence summary
2. **Table of Contents** - Navigation for multi-page research
3. **Research Scope** - What was researched and methodology
4. **Quick Reference** - Summary tables and key findings
5. **Detailed Analysis** - In-depth content with subsections
6. **Implementation Examples** - Practical code examples
7. **Best Practices** - Recommendations and patterns
8. **Related Topics** - Links to related research
9. **Citations** - Source references and links
10. **Navigation** - Previous/Next links to related content

#### GitBook Research Template
```markdown
# Research Topic Title

Brief 1-2 sentence overview of what this research covers.

{% hint style="info" %}
**Research Focus**: Specific area or problem this research addresses
{% endhint %}

## Table of Contents

1. [Overview](#overview)
2. [Research Methodology](#research-methodology)
3. [Key Findings](#key-findings)
4. [Implementation Guide](#implementation-guide)
5. [Best Practices](#best-practices)
6. [Related Topics](#related-topics)

## Research Methodology

Explain how the research was conducted, sources used, and approach taken.

## Key Findings

### Quick Reference Table

| Technology | Score | Best For | Use Case |
|------------|-------|----------|----------|
| Tool A     | 9/10  | Feature X | Scenario Y |
| Tool B     | 8/10  | Feature Y | Scenario Z |

### Technology Stack Recommendations

{% tabs %}
{% tab title="Recommended Stack" %}
- **Primary Tool**: Tool A
- **Alternative**: Tool B
- **Supporting Tools**: Tool C, Tool D
{% endtab %}

{% tab title="Enterprise Stack" %}
- **Primary Tool**: Enterprise Tool A
- **Alternative**: Enterprise Tool B
- **Supporting Tools**: Enterprise Tool C
{% endtab %}
{% endtabs %}

## Implementation Guide

Step-by-step implementation with code examples.

{% hint style="warning" %}
Important considerations before implementation
{% endhint %}

## Best Practices

Key recommendations and patterns to follow.

## Related Topics

- [Related Research 1](../category/related-topic-1.md)
- [Related Research 2](../category/related-topic-2.md)
- [Implementation Guide](../../how-tos/implementations/related-implementation.md)

## Citations

1. [Source Title](https://example.com) - Brief description
2. [Another Source](https://example.com) - Brief description

---

**Navigation**
- ← Previous: [Previous Topic](../previous-topic.md)
- → Next: [Next Topic](../next-topic.md)
- ↑ Back to: [Category Overview](./README.md)
```

### How-To Documents
Follow this structure for implementation guides:

#### Required Sections for How-Tos
1. **Title & Purpose** - What you'll accomplish
2. **Prerequisites** - Required knowledge/tools
3. **Overview** - High-level steps
4. **Step-by-Step Instructions** - Detailed implementation
5. **Verification** - How to confirm success
6. **Troubleshooting** - Common issues and solutions
7. **Next Steps** - What to do after completion
8. **Related Guides** - Links to related how-tos

#### GitBook How-To Template
```markdown
# How to [Accomplish Task]

Learn how to [brief description of what you'll accomplish].

{% hint style="info" %}
**Estimated Time**: X minutes
**Difficulty Level**: Beginner/Intermediate/Advanced
{% endhint %}

## Prerequisites

Before starting, ensure you have:
- [ ] Requirement 1
- [ ] Requirement 2
- [ ] Requirement 3

## Overview

High-level overview of the process:
1. Step category 1
2. Step category 2
3. Step category 3

## Step-by-Step Instructions

### Step 1: [Step Name]

Detailed instructions for step 1.

```bash
# Command examples
command --option value
```

{% hint style="warning" %}
Important note about this step
{% endhint %}

### Step 2: [Step Name]

Continue with detailed instructions.

## Verification

How to verify the setup worked correctly:

```bash
# Verification commands
verification-command
```

Expected output:
```text
Expected output here
```

## Troubleshooting

Common issues and solutions:

### Issue 1: [Problem Description]

**Symptoms**: Description of the problem
**Solution**: How to fix it

### Issue 2: [Problem Description]

**Symptoms**: Description of the problem
**Solution**: How to fix it

## Next Steps

After completing this guide:
- [ ] Optional step 1
- [ ] Optional step 2
- [ ] Related configuration

## Related Guides

- [Related How-To 1](../category/related-guide-1.md)
- [Related How-To 2](../category/related-guide-2.md)
- [Background Research](../../research/category/related-research.md)

---

**Navigation**
- ← Previous: [Previous Guide](../previous-guide.md)
- → Next: [Next Guide](../next-guide.md)
- ↑ Back to: [How-Tos Overview](./README.md)
```

### Notes Documents
For quick references and personal learnings:

#### Note Types
1. **Quick Reference** - Cheat sheets and command references
2. **Troubleshooting** - Common issues and solutions
3. **Personal Learnings** - Insights and lessons learned

## Coding Style Preferences
- Use TypeScript for JavaScript projects
- Follow clean architecture principles
- Implement comprehensive testing strategies
- Use modern tooling (ESLint, Prettier, etc.)
- Document all public APIs and complex logic
- Provide GitBook-compatible markdown with proper formatting

## Content Creation Workflow

### When Creating New Content:

#### 1. Determine Category and Location
- **Research**: Technical analysis and comparison
- **How-To**: Step-by-step implementation guides
- **Notes**: Quick references and learnings
- **Tools**: Tool-specific documentation

#### 2. Create Directory Structure
```bash
# For research topic
mkdir -p research/[category]/[topic-name]
# For how-to guide  
mkdir -p how-tos/[category]/[topic-name]
# For notes
mkdir -p notes/[category]/[topic-name]
```

#### 3. Create Required Files
- `README.md` - Main content or overview
- Additional `.md` files as needed
- Update `SUMMARY.md` with new content

#### 4. Follow GitBook Conventions
- Use proper heading hierarchy
- Include GitBook hints and tabs where appropriate
- Add navigation links between related content
- Ensure all links work in GitBook environment

#### 5. Validate GitBook Compatibility
- Test that all internal links work
- Verify proper heading structure
- Ensure GitBook markdown extensions are valid
- Check that images and assets are properly referenced

### Cross-References and Navigation

#### Link Patterns
```markdown
# Internal links (relative to current file)
[Related Topic](../category/related-topic.md)

# Links to other categories
[Research Background](../../research/category/topic.md)
[Implementation Guide](../../how-tos/category/guide.md)

# External links with descriptions
[Official Documentation](https://example.com) - Official project docs
```

#### Navigation Footers
Always include navigation at the bottom of pages:
```markdown
---

**Navigation**
- ← Previous: [Previous Topic](../previous-topic.md)
- → Next: [Next Topic](../next-topic.md)  
- ↑ Back to: [Category Overview](./README.md)
```

## Commit Message Requirements

### Use GitBook-friendly commit messages:

```bash
git commit -m "[docs] category: topic-name"
```

#### Examples:
- `git commit -m "[docs] research: react-mvvm-clean-architecture"`
- `git commit -m "[docs] how-to: dual-boot-linux-setup"`
- `git commit -m "[docs] notes: typescript-troubleshooting"`
- `git commit -m "[docs] tools: playwright-configuration"`

#### For Chat/Conversation Names:
```text
[docs] category: topic-name
```

## GitBook Sync Considerations

### File Naming Conventions
- Use lowercase with hyphens: `topic-name.md`
- Avoid special characters that GitBook doesn't handle well
- Keep file names descriptive but concise
- Match folder names with content category

### Image and Asset Management
- Store images in appropriate subdirectories
- Use relative paths for GitBook compatibility
- Include alt text for all images
- Optimize image sizes for web viewing

### Link Management
- Always use relative links for internal content
- Test links work in both GitHub and GitBook
- Include descriptive link text
- Update `SUMMARY.md` when adding new pages

### Content Organization Best Practices
1. **Logical Hierarchy**: Organize content in a way that makes sense for both GitBook navigation and GitHub browsing
2. **Consistent Structure**: Use the same document templates across similar content types
3. **Cross-References**: Link related content across different categories
4. **Search-Friendly**: Use descriptive headings and include relevant keywords
5. **Mobile-Friendly**: Ensure content displays well on mobile devices in GitBook

### GitBook-Specific Features to Use
- **Hints**: For important information, warnings, and tips
- **Tabs**: For code examples in multiple languages
- **Expandable Sections**: For optional or advanced content
- **Table of Contents**: For long documents
- **Page Links**: For navigation between related topics

#### Important!! Always try to search the internet as much as possible and include citations at the end of the documents.

#### Always ensure GitBook sync compatibility by testing changes in both GitHub markdown preview and GitBook environment.
