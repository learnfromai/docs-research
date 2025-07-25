# GitHub Copilot Instructions

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
This workspace contains research documentation and guides for various technical topics including:

- **Dual-boot Linux installations** - Comprehensive guides for setting up Ubuntu/Lubuntu alongside existing systems
- **Clean Architecture implementations** - Research on MVVM patterns for Express.js and React applications  
- **E2E Testing frameworks** - Analysis of Cypress, Playwright and other testing solutions
- **Clinic Management System features** - Healthcare software feature specifications
- **Development best practices** - Modern tooling, CI/CD, and architectural patterns

## Coding Style Preferences
- Use TypeScript for JavaScript projects
- Follow clean architecture principles
- Implement comprehensive testing strategies
- Use modern tooling (ESLint, Prettier, etc.)
- Document all public APIs and complex logic

## Project Structure
- Each major topic has its own directory with detailed markdown documentation
- Research includes citations and references where applicable
- Implementation guides include practical examples and best practices
- Executive summaries provide high-level overviews

## When providing suggestions:
1. Consider the specific domain context (healthcare, testing, architecture, etc.)
2. Reference existing documentation patterns used in this workspace
3. Maintain consistency with established markdown formatting
4. Include practical examples and implementation details
5. Provide citations for technical recommendations when appropriate

## README.md Structure Requirements

### Every new research topic MUST include a README.md file that serves as the main documentation hub

#### Required Sections

1. **Project Title & Overview** - Clear, descriptive title with concise project summary
2. **Table of Contents** - Organized links to all related markdown files with brief descriptions
3. **Research Scope/Methodology** - What was researched and how (sources, approach)
4. **Quick Reference** - Summary tables, technology stacks, or key recommendations
5. **Goals Achieved** - Checkmarked list of research objectives completed

#### Table of Contents Format

- Use numbered list (1. 2. 3.) for main documents
- Include file links: `[Document Title](./filename.md)`
- Add brief descriptions explaining each document's purpose
- Group related documents under thematic headings with emojis for visual organization

#### Quick Reference Section

- Include comparison tables for frameworks/tools/options
- Provide technology stack recommendations
- Add decision-making guides or selection criteria
- Include folder structure examples when relevant

#### Goals Achieved Section

- Use checkmark format: `✅ **Goal Name**: Description`
- Focus on concrete outcomes and deliverables
- Highlight key metrics, compliance standards, or technical achievements
- Summarize the value and impact of the research

### Examples from Existing Research

- **Express MVVM**: Features detailed technology stack table, implementation checklist, and architectural benefits
- **E2E Testing**: Includes framework comparison table, selection guide with code examples
- **Clinic Management**: Shows compliance standards table, component overview, research methodology
- **Dual-Boot Linux**: Organized by installation types, includes safety guides, uses emoji sections

### File Organization Pattern

```text
research-topic/
├── README.md                 # Main hub with TOC and overview
├── executive-summary.md      # High-level summary for stakeholders
├── implementation-guide.md   # Step-by-step instructions
├── best-practices.md        # Recommendations and patterns
├── [specific-topic].md      # Detailed research documents
└── prompt.txt              # Original research prompt
```

### README.md Link Verification

**CRITICAL**: Before finalizing any research topic, verify that all files referenced in README.md actually exist in the directory. If any files are missing:

1. **Create the missing files** with appropriate content, OR
2. **Update the README.md** to remove or correct the broken links

This ensures documentation consistency and prevents broken links that confuse users navigating the research.

## Commit Message Requirements

### At the end of each research session, provide a git commit message in the following format:

```bash
git commit -m "[research] document-title"
```

#### And give a text for Chat/Conversation Name Format:

```text
[research] document-title
```

#### Examples:
- `git commit -m "[research] clinic-management-system-features"`
- `git commit -m "[research] express-mvvm-clean-architecture"`
- `git commit -m "[research] k6-load-testing-ssr"`
- `git commit -m "[research] dual-boot-linux-with-citations"`

#### Guidelines:
- Use the main folder/topic name as the document title
- Convert to lowercase with hyphens instead of spaces
- Use the format: `[research] topic-name`
- Always prefix with "[research]" to clearly identify research commits
- Provide this after completing all documentation and file creation

#### Always use the current related research as reference for every user query.

#### Provide navigation feature from other links. Also back and forward navigation should be available.
Also at the bottom something like pagination even if just arrangend vertically and each link is the title itself. See existing research directories for reference.

#### Important!! Always try to search the internet as much as possible and include citations at the end of the documents.