# GitHub Interview Questions & Answers

## 📋 Table of Contents

1. **[Git Fundamentals](#git-fundamentals)** - Version control basics and commands
2. **[GitHub Features & Workflow](#github-features--workflow)** - Platform-specific features
3. **[Branching Strategies](#branching-strategies)** - Development workflows and patterns
4. **[Pull Requests & Code Review](#pull-requests--code-review)** - Collaboration processes
5. **[GitHub Actions & CI/CD](#github-actions--cicd)** - Automation and deployment
6. **[Repository Management](#repository-management)** - Organization and administration
7. **[Security & Best Practices](#security--best-practices)** - Secure development practices

---

## Git Fundamentals

### 1. Explain the difference between Git and GitHub

**Answer:**
**Git** and **GitHub** serve different but complementary purposes in version control and collaboration.

**Git (Version Control System):**

```bash
# Git is a distributed version control system
git init                    # Initialize repository
git add file.js            # Stage changes
git commit -m "message"     # Create commit
git branch feature         # Create branch
git merge feature          # Merge branches
git log --oneline          # View history
```

**Key Features:**
- **Local repository**: Works offline
- **Distributed**: Each clone is a full repository
- **Branching**: Lightweight branch creation
- **History tracking**: Complete change history
- **Command-line tool**: Core functionality via CLI

**GitHub (Cloud Platform):**

```bash
# GitHub provides hosting and collaboration features
git remote add origin https://github.com/user/repo.git
git push origin main       # Push to GitHub
git pull origin main       # Pull from GitHub
gh pr create              # Create pull request (GitHub CLI)
gh issue create          # Create issue
```

**Key Features:**
- **Remote hosting**: Cloud-based repository storage
- **Web interface**: Browser-based Git operations
- **Collaboration tools**: Issues, pull requests, discussions
- **CI/CD integration**: GitHub Actions
- **Project management**: Projects, milestones, labels

**Comparison Table:**

| Feature | Git | GitHub |
|---------|-----|--------|
| **Type** | Version control system | Cloud hosting platform |
| **Scope** | Local and distributed | Remote collaboration |
| **Interface** | Command-line primary | Web interface + CLI |
| **Collaboration** | Manual sharing | Built-in tools |
| **Hosting** | Self-hosted possible | Cloud-hosted |
| **Features** | Core version control | Enhanced project management |

---

### 2. What are the essential Git commands every developer should know?

**Answer:**
Essential Git commands cover **repository management**, **staging**, **committing**, **branching**, and **collaboration**.

**Repository Setup:**

```bash
# Initialize and clone repositories
git init                                    # Create new repository
git clone https://github.com/user/repo.git # Clone existing repository
git remote -v                              # View remote repositories
git remote add origin <url>                # Add remote repository
```

**Basic Workflow:**

```bash
# Check status and differences
git status                          # Show working directory status
git diff                           # Show unstaged changes
git diff --staged                  # Show staged changes
git diff HEAD~1                    # Compare with previous commit

# Staging and committing
git add file.js                    # Stage specific file
git add .                          # Stage all changes
git add -p                         # Interactive staging
git commit -m "feat: add feature"  # Commit with message
git commit --amend                 # Modify last commit
```

**Branching and Merging:**

```bash
# Branch management
git branch                         # List branches
git branch feature-name           # Create new branch
git checkout feature-name         # Switch to branch
git checkout -b feature-name      # Create and switch
git switch feature-name           # Modern way to switch (Git 2.23+)
git switch -c feature-name        # Create and switch (modern)

# Merging and rebasing
git merge feature-name            # Merge branch
git rebase main                   # Rebase current branch onto main
git rebase -i HEAD~3              # Interactive rebase
```

**History and Information:**

```bash
# View history
git log                           # Show commit history
git log --oneline                 # Condensed history
git log --graph --all             # Visual branch history
git show HEAD                     # Show last commit details
git blame file.js                 # Show line-by-line authors

# Search and inspect
git grep "search term"            # Search in repository
git reflog                        # Show reference log
git describe --tags               # Show nearest tag
```

**Remote Operations:**

```bash
# Synchronizing with remotes
git fetch                         # Download remote changes
git pull                          # Fetch and merge
git pull --rebase                 # Fetch and rebase
git push                          # Upload changes
git push -u origin feature        # Push and set upstream
git push --force-with-lease       # Safe force push
```

**Undoing Changes:**

```bash
# Unstage and revert
git reset file.js                 # Unstage file
git reset --soft HEAD~1           # Undo commit, keep changes staged
git reset --hard HEAD~1           # Undo commit, discard changes
git revert HEAD                   # Create commit that undoes changes
git checkout -- file.js          # Discard unstaged changes
git restore file.js               # Modern way to discard changes
```

**Advanced Operations:**

```bash
# Stashing
git stash                         # Stash current changes
git stash pop                     # Apply and remove latest stash
git stash list                    # Show all stashes
git stash apply stash@{0}         # Apply specific stash

# Tagging
git tag v1.0.0                    # Create lightweight tag
git tag -a v1.0.0 -m "Release"    # Create annotated tag
git push --tags                   # Push tags to remote

# Cleaning
git clean -n                      # Show what would be cleaned
git clean -f                      # Remove untracked files
git clean -fd                     # Remove untracked files and directories
```

---

### 3. How do you resolve merge conflicts in Git?

**Answer:**
Merge conflicts occur when Git cannot automatically merge changes. Resolution requires **manual intervention** and understanding of conflict markers.

**Understanding Conflict Markers:**

```javascript
// Example conflict in a JavaScript file
<<<<<<< HEAD
function calculateTotal(items) {
  return items.reduce((sum, item) => sum + item.price * item.quantity, 0);
}
=======
function calculateTotal(products) {
  let total = 0;
  for (const product of products) {
    total += product.cost * product.qty;
  }
  return total;
}
>>>>>>> feature-branch
```

**Conflict Resolution Process:**

**1. Identify Conflicted Files:**

```bash
# After failed merge
git status
# Shows:
# Unmerged paths:
#   both modified:   src/utils.js
#   both modified:   package.json

# View conflicted files
git diff --name-only --diff-filter=U
```

**2. Manual Resolution:**

```javascript
// Choose one version or combine both
function calculateTotal(items) {
  // Combined approach: use reduce but keep descriptive variable names
  return items.reduce((total, item) => {
    return total + (item.price || item.cost) * (item.quantity || item.qty);
  }, 0);
}
```

**3. Complete the Resolution:**

```bash
# After manually resolving conflicts
git add src/utils.js                # Mark as resolved
git status                          # Verify all conflicts resolved
git commit                          # Complete the merge
# Or if rebasing:
git rebase --continue               # Continue rebase
```

**Advanced Resolution Strategies:**

**1. Using Merge Tools:**

```bash
# Configure merge tool
git config --global merge.tool vscode
git config --global mergetool.vscode.cmd 'code --wait $MERGED'

# Launch merge tool
git mergetool                       # Opens configured tool
git mergetool src/utils.js          # Open specific file
```

**2. Three-Way Merge Understanding:**

```bash
# View three versions
git show :1:file.js                # Common ancestor
git show :2:file.js                # Current branch (HEAD)
git show :3:file.js                # Incoming branch

# Choose specific version
git checkout --ours file.js        # Keep current branch version
git checkout --theirs file.js      # Take incoming branch version
```

**3. Prevention Strategies:**

```bash
# Prevent conflicts with regular sync
git fetch origin                   # Fetch latest changes
git rebase origin/main             # Rebase instead of merge
git pull --rebase                  # Always rebase when pulling

# Use merge strategies
git merge -X ours feature-branch   # Prefer current branch
git merge -X theirs feature-branch # Prefer incoming branch
```

**Common Conflict Scenarios:**

**1. Package.json Dependencies:**

```json
// Conflict in package.json
<<<<<<< HEAD
{
  "dependencies": {
    "react": "^18.0.0",
    "lodash": "^4.17.21"
  }
}
=======
{
  "dependencies": {
    "react": "^18.2.0",
    "axios": "^1.0.0"
  }
}
>>>>>>> feature-branch

// Resolution: Keep both dependencies, choose higher React version
{
  "dependencies": {
    "react": "^18.2.0",
    "lodash": "^4.17.21",
    "axios": "^1.0.0"
  }
}
```

**2. Configuration Files:**

```javascript
// Conflict in config file
<<<<<<< HEAD
const config = {
  apiUrl: 'https://api.example.com',
  timeout: 5000
};
=======
const config = {
  apiUrl: 'https://api.example.com',
  retries: 3,
  debug: true
};
>>>>>>> feature-branch

// Resolution: Combine configurations
const config = {
  apiUrl: 'https://api.example.com',
  timeout: 5000,
  retries: 3,
  debug: process.env.NODE_ENV === 'development'
};
```

---

## GitHub Features & Workflow

### 4. Explain GitHub Issues and how to use them effectively

**Answer:**
GitHub Issues provide **project management** and **bug tracking** capabilities integrated with code repositories.

**Issue Types and Structure:**

**1. Bug Reports:**

```markdown
## Bug Report

**Description:**
Login form does not validate email format correctly

**Steps to Reproduce:**
1. Navigate to /login
2. Enter invalid email: "test@"
3. Click submit button
4. Form submits without validation

**Expected Behavior:**
Should show email validation error

**Actual Behavior:**
Form submits with invalid email

**Environment:**
- Browser: Chrome 120
- OS: macOS 14
- App Version: 1.2.3

**Screenshots:**
[Attach relevant screenshots]

**Additional Context:**
This affects user registration as well
```

**2. Feature Requests:**

```markdown
## Feature Request

**Is your feature request related to a problem?**
Users cannot sort the product list by price, making it difficult to find budget-friendly options.

**Describe the solution you'd like:**
Add sort dropdown with options:
- Price: Low to High
- Price: High to Low
- Name: A-Z
- Name: Z-A
- Newest First

**Describe alternatives you've considered:**
- Filter by price range (less flexible)
- Search by price (poor UX)

**Additional context:**
This feature is requested by 30% of users in feedback surveys.

**Acceptance Criteria:**
- [ ] Sort dropdown appears above product grid
- [ ] Sorting persists across page navigation
- [ ] Default sort is configurable
- [ ] Works on mobile devices
```

**Issue Management:**

**1. Labels and Organization:**

```bash
# Create label categories
Type Labels:
- bug (red)
- feature (blue)
- enhancement (green)
- documentation (yellow)

Priority Labels:
- priority: high (red)
- priority: medium (orange)
- priority: low (green)

Status Labels:
- status: blocked (black)
- status: in-progress (yellow)
- status: needs-review (orange)

Component Labels:
- frontend (purple)
- backend (blue)
- api (cyan)
- database (brown)
```

**2. Issue Templates:**

```yaml
# .github/ISSUE_TEMPLATE/bug_report.yml
name: Bug Report
description: File a bug report to help us improve
title: "[Bug]: "
labels: ["bug", "needs-triage"]
body:
  - type: markdown
    attributes:
      value: |
        Thanks for taking the time to fill out this bug report!
  
  - type: input
    id: contact
    attributes:
      label: Contact Details
      description: How can we get in touch with you if we need more info?
      placeholder: ex. email@example.com
    validations:
      required: false
  
  - type: textarea
    id: what-happened
    attributes:
      label: What happened?
      description: Also tell us, what did you expect to happen?
      placeholder: Tell us what you see!
    validations:
      required: true
  
  - type: dropdown
    id: browsers
    attributes:
      label: What browsers are you seeing the problem on?
      multiple: true
      options:
        - Firefox
        - Chrome
        - Safari
        - Microsoft Edge
```

**3. Automation with Issues:**

```yaml
# .github/workflows/issue-automation.yml
name: Issue Automation
on:
  issues:
    types: [opened, labeled]

jobs:
  auto-assign:
    runs-on: ubuntu-latest
    steps:
      - name: Auto-assign based on labels
        uses: actions/github-script@v6
        with:
          script: |
            const issue = context.payload.issue;
            const labels = issue.labels.map(label => label.name);
            
            let assignee = null;
            if (labels.includes('frontend')) {
              assignee = 'frontend-team-lead';
            } else if (labels.includes('backend')) {
              assignee = 'backend-team-lead';
            }
            
            if (assignee) {
              await github.rest.issues.addAssignees({
                owner: context.repo.owner,
                repo: context.repo.repo,
                issue_number: issue.number,
                assignees: [assignee]
              });
            }
```

**Linking Issues to Code:**

**1. Commit Messages:**

```bash
# Link commits to issues
git commit -m "fix: validate email format on login

Fixes #123
Closes #124
Resolves #125"

# Keywords that close issues:
# close, closes, closed
# fix, fixes, fixed
# resolve, resolves, resolved
```

**2. Pull Request Integration:**

```markdown
## Pull Request Description

This PR implements user authentication improvements.

**Changes:**
- Add email validation
- Improve error messaging
- Add loading states

**Related Issues:**
- Fixes #123 - Email validation bug
- Addresses #124 - UX improvements
- Part of #125 - Authentication overhaul

**Testing:**
- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Manual testing completed
```

---

### 5. How do you use GitHub Projects for project management?

**Answer:**
GitHub Projects provides **Kanban-style project management** integrated with repositories, issues, and pull requests.

**Project Setup and Configuration:**

**1. Creating Projects:**

```bash
# Via GitHub CLI
gh project create --title "Website Redesign" --body "Q1 2024 website overhaul"

# Project types:
- Board (Kanban style)
- Table (Spreadsheet style)
- Roadmap (Timeline view)
```

**2. Board Configuration:**

```yaml
# Example board columns
Columns:
  - Backlog
  - Sprint Planning
  - In Progress
  - In Review
  - Testing
  - Done

# Column automation rules
In Progress:
  - Auto-move when issue assigned
  - Auto-move when PR created
  
In Review:
  - Auto-move when PR ready for review
  - Auto-move when review requested

Done:
  - Auto-move when issue closed
  - Auto-move when PR merged
```

**Advanced Project Features:**

**1. Custom Fields:**

```yaml
# Custom field types
Fields:
  Priority:
    type: select
    options: [High, Medium, Low]
  
  Story Points:
    type: number
    
  Sprint:
    type: select
    options: [Sprint 1, Sprint 2, Sprint 3]
  
  Component:
    type: select
    options: [Frontend, Backend, API, Database]
  
  Due Date:
    type: date
    
  Assignee:
    type: assignee
```

**2. Views and Filtering:**

```yaml
# Example project views
Views:
  Sprint Board:
    filter: "sprint:current"
    group_by: "status"
    
  Bug Triage:
    filter: "label:bug"
    sort: "priority desc"
    
  Team Workload:
    group_by: "assignee"
    filter: "status:in-progress"
    
  Roadmap:
    type: roadmap
    date_field: "due_date"
    group_by: "milestone"
```

**Workflow Integration:**

**1. Automated Issue Management:**

```yaml
# .github/workflows/project-automation.yml
name: Project Automation
on:
  issues:
    types: [opened, closed, assigned]
  pull_request:
    types: [opened, closed, ready_for_review]

jobs:
  update-project:
    runs-on: ubuntu-latest
    steps:
      - name: Add to project
        uses: actions/add-to-project@v0.4.0
        with:
          project-url: https://github.com/users/username/projects/1
          github-token: ${{ secrets.ADD_TO_PROJECT_PAT }}
          
      - name: Set custom fields
        uses: actions/github-script@v6
        with:
          script: |
            const issue = context.payload.issue;
            const labels = issue.labels.map(l => l.name);
            
            // Set priority based on labels
            let priority = 'Medium';
            if (labels.includes('priority:high')) priority = 'High';
            if (labels.includes('priority:low')) priority = 'Low';
            
            // Update project item
            await github.graphql(`
              mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $value: String!) {
                updateProjectV2ItemFieldValue(
                  input: {
                    projectId: $projectId
                    itemId: $itemId
                    fieldId: $fieldId
                    value: { text: $value }
                  }
                ) {
                  projectV2Item {
                    id
                  }
                }
              }
            `, {
              projectId: 'PROJECT_ID',
              itemId: 'ITEM_ID',
              fieldId: 'PRIORITY_FIELD_ID',
              value: priority
            });
```

**2. Sprint Planning Automation:**

```javascript
// scripts/sprint-planning.js
const { Octokit } = require("@octokit/rest");

class SprintPlanner {
  constructor(token, owner, repo, projectId) {
    this.octokit = new Octokit({ auth: token });
    this.owner = owner;
    this.repo = repo;
    this.projectId = projectId;
  }
  
  async createSprint(sprintNumber, startDate, endDate) {
    // Create milestone
    const milestone = await this.octokit.rest.issues.createMilestone({
      owner: this.owner,
      repo: this.repo,
      title: `Sprint ${sprintNumber}`,
      description: `Sprint ${sprintNumber}: ${startDate} - ${endDate}`,
      due_on: endDate,
    });
    
    return milestone.data;
  }
  
  async moveToSprint(issueNumbers, sprintNumber) {
    for (const issueNumber of issueNumbers) {
      // Add to milestone
      await this.octokit.rest.issues.update({
        owner: this.owner,
        repo: this.repo,
        issue_number: issueNumber,
        milestone: sprintNumber,
      });
      
      // Update project field
      await this.updateProjectField(issueNumber, 'sprint', `Sprint ${sprintNumber}`);
    }
  }
  
  async generateSprintReport(sprintNumber) {
    const issues = await this.octokit.rest.issues.listForRepo({
      owner: this.owner,
      repo: this.repo,
      milestone: sprintNumber,
      state: 'all',
    });
    
    const completed = issues.data.filter(issue => issue.state === 'closed');
    const incomplete = issues.data.filter(issue => issue.state === 'open');
    
    return {
      total: issues.data.length,
      completed: completed.length,
      incomplete: incomplete.length,
      completionRate: (completed.length / issues.data.length) * 100,
    };
  }
}
```

**Reporting and Analytics:**

**1. Project Insights:**

```yaml
# Project metrics to track
Metrics:
  Velocity:
    - Story points completed per sprint
    - Issues completed per week
    
  Cycle Time:
    - Time from "To Do" to "Done"
    - Time in each column
    
  Lead Time:
    - Time from issue creation to completion
    
  Burndown:
    - Remaining work over time
    - Sprint progress tracking
    
  Team Performance:
    - Individual completion rates
    - Collaboration patterns
```

**2. Custom Dashboards:**

```javascript
// dashboard/project-metrics.js
async function getProjectMetrics(projectId, timeframe = '30d') {
  const query = `
    query($projectId: ID!) {
      node(id: $projectId) {
        ... on ProjectV2 {
          items(first: 100) {
            nodes {
              id
              content {
                ... on Issue {
                  number
                  title
                  state
                  createdAt
                  closedAt
                  assignees(first: 5) {
                    nodes {
                      login
                    }
                  }
                }
              }
              fieldValues(first: 10) {
                nodes {
                  ... on ProjectV2ItemFieldSingleSelectValue {
                    name
                    field {
                      ... on ProjectV2SingleSelectField {
                        name
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  `;
  
  const data = await github.graphql(query, { projectId });
  
  return {
    totalItems: data.node.items.nodes.length,
    completedItems: data.node.items.nodes.filter(item => 
      item.content.state === 'CLOSED'
    ).length,
    averageCycleTime: calculateAverageCycleTime(data.node.items.nodes),
    teamMetrics: generateTeamMetrics(data.node.items.nodes),
  };
}
```

---

## Branching Strategies

### 6. What are different Git branching strategies and when to use them?

**Answer:**
Different branching strategies suit different **team sizes**, **release cycles**, and **project requirements**.

**Git Flow:**

```bash
# Git Flow structure
main/master     # Production-ready code
develop         # Integration branch
feature/*       # Feature development
release/*       # Release preparation
hotfix/*        # Production fixes

# Git Flow commands
git flow init                          # Initialize git flow
git flow feature start feature-name   # Start feature
git flow feature finish feature-name  # Finish feature
git flow release start 1.0.0         # Start release
git flow hotfix start hotfix-name    # Emergency fix
```

**Workflow Example:**

```bash
# Feature development
git checkout develop
git flow feature start user-authentication
# Work on feature...
git add .
git commit -m "feat: implement user login"
git flow feature finish user-authentication

# Release process
git flow release start 1.0.0
# Bug fixes and final preparations...
git commit -m "chore: bump version to 1.0.0"
git flow release finish 1.0.0

# Hotfix for production
git flow hotfix start critical-security-fix
# Fix the issue...
git commit -m "fix: patch security vulnerability"
git flow hotfix finish critical-security-fix
```

**GitHub Flow:**

```bash
# GitHub Flow - simpler approach
main            # Always deployable
feature-branch  # Short-lived feature branches

# GitHub Flow workflow
git checkout main
git pull origin main
git checkout -b feature/add-payment-gateway

# Work on feature
git add .
git commit -m "feat: integrate Stripe payment"
git push origin feature/add-payment-gateway

# Create pull request via GitHub UI
# After review and approval, merge to main
git checkout main
git pull origin main
git branch -d feature/add-payment-gateway
```

**Comparison of Strategies:**

| Strategy | Complexity | Team Size | Release Frequency | Best For |
|----------|------------|-----------|-------------------|----------|
| **Git Flow** | High | Large (10+) | Scheduled releases | Enterprise, complex projects |
| **GitHub Flow** | Low | Small-Medium (2-10) | Continuous deployment | Startups, web applications |
| **GitLab Flow** | Medium | Medium (5-15) | Regular releases | Balanced approach |
| **Trunk-based** | Low | Any size | Multiple daily | High-velocity teams |

**Advanced Branching Patterns:**

**1. Feature Flags with Trunk-based:**

```javascript
// Feature flag implementation
const features = {
  newPaymentFlow: process.env.FEATURE_NEW_PAYMENT === 'true',
  experimentalUI: process.env.FEATURE_EXPERIMENTAL_UI === 'true',
};

// Usage in code
function PaymentComponent() {
  if (features.newPaymentFlow) {
    return <NewPaymentFlow />;
  }
  return <LegacyPaymentFlow />;
}

// Gradual rollout
const shouldShowNewFeature = (userId) => {
  // Show to 10% of users initially
  return (userId % 10) === 0;
};
```

**2. Environment-based Branching:**

```bash
# Environment branches
main            # Production
staging         # Staging environment
develop         # Development environment

# Promotion workflow
git checkout develop
# Development work...
git push origin develop

# Promote to staging
git checkout staging
git merge develop
git push origin staging

# After testing, promote to production
git checkout main
git merge staging
git tag v1.0.0
git push origin main --tags
```

**Branch Protection Rules:**

```yaml
# Branch protection configuration
Protection Rules:
  main:
    required_status_checks:
      - ci/build
      - ci/test
      - ci/lint
    required_pull_request_reviews:
      required_approving_review_count: 2
      dismiss_stale_reviews: true
      require_code_owner_reviews: true
    enforce_admins: true
    restrictions:
      users: []
      teams: ["core-team"]
    
  develop:
    required_status_checks:
      - ci/build
      - ci/test
    required_pull_request_reviews:
      required_approving_review_count: 1
```

---

## Pull Requests & Code Review

### 7. What makes a good pull request and code review process?

**Answer:**
Effective pull requests and code reviews require **clear communication**, **thorough review**, and **constructive feedback**.

**Pull Request Best Practices:**

**1. Structure and Content:**

```markdown
## Pull Request Template

### Description
Brief description of the changes and why they were made.

### Type of Change
- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update

### Changes Made
- Added user authentication middleware
- Updated API error handling
- Added comprehensive test coverage
- Updated documentation

### Related Issues
Fixes #123
Closes #456
Related to #789

### Testing
- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Manual testing completed
- [ ] Cross-browser testing (if applicable)

### Screenshots (if applicable)
[Add screenshots for UI changes]

### Checklist
- [ ] My code follows the project's style guidelines
- [ ] I have performed a self-review of my own code
- [ ] I have commented my code, particularly in hard-to-understand areas
- [ ] I have made corresponding changes to the documentation
- [ ] My changes generate no new warnings
- [ ] I have added tests that prove my fix is effective or that my feature works
- [ ] New and existing unit tests pass locally with my changes
```

**2. Code Quality Guidelines:**

```javascript
// Good PR - Small, focused change
// File: src/utils/validation.js
export function validateEmail(email) {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(email);
}

export function validatePassword(password) {
  // At least 8 characters, 1 uppercase, 1 lowercase, 1 number
  const passwordRegex = /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)[a-zA-Z\d@$!%*?&]{8,}$/;
  return passwordRegex.test(password);
}

// File: src/utils/validation.test.js
import { validateEmail, validatePassword } from './validation';

describe('Email Validation', () => {
  test('validates correct email formats', () => {
    expect(validateEmail('user@example.com')).toBe(true);
    expect(validateEmail('test.email+tag@domain.co.uk')).toBe(true);
  });
  
  test('rejects invalid email formats', () => {
    expect(validateEmail('invalid-email')).toBe(false);
    expect(validateEmail('@domain.com')).toBe(false);
    expect(validateEmail('user@')).toBe(false);
  });
});
```

**Code Review Process:**

**1. Review Checklist:**

```yaml
Code Review Checklist:
  Functionality:
    - [ ] Code does what it's supposed to do
    - [ ] Edge cases are handled
    - [ ] Error handling is appropriate
    
  Code Quality:
    - [ ] Code is readable and well-structured
    - [ ] Functions are appropriately sized
    - [ ] Variables and functions are well-named
    - [ ] No duplicate code
    
  Performance:
    - [ ] No obvious performance issues
    - [ ] Database queries are optimized
    - [ ] Caching is used where appropriate
    
  Security:
    - [ ] Input validation is present
    - [ ] No sensitive data in logs
    - [ ] Authentication/authorization checks
    
  Testing:
    - [ ] Tests cover new functionality
    - [ ] Tests are meaningful and comprehensive
    - [ ] Test names are descriptive
    
  Documentation:
    - [ ] Code is self-documenting or well-commented
    - [ ] API documentation is updated
    - [ ] README is updated if needed
```

**2. Review Comments Examples:**

```javascript
// Instead of: "This is wrong"
// Better: "Consider using async/await for better readability"

// Original code
function fetchUserData(userId) {
  return fetch(`/api/users/${userId}`)
    .then(response => response.json())
    .then(data => data.user)
    .catch(error => console.error(error));
}

// Suggested improvement
async function fetchUserData(userId) {
  try {
    const response = await fetch(`/api/users/${userId}`);
    const data = await response.json();
    return data.user;
  } catch (error) {
    console.error('Failed to fetch user data:', error);
    throw error; // Re-throw to allow caller to handle
  }
}
```

**Advanced Review Practices:**

**1. Automated Code Review:**

```yaml
# .github/workflows/code-review.yml
name: Automated Code Review
on:
  pull_request:
    types: [opened, synchronize]

jobs:
  code-quality:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'
          cache: 'npm'
      
      - name: Install dependencies
        run: npm ci
      
      - name: Run ESLint
        run: npm run lint
      
      - name: Run Prettier
        run: npm run format:check
      
      - name: Run Type Check
        run: npm run type-check
      
      - name: Run Tests
        run: npm run test:coverage
      
      - name: SonarCloud Scan
        uses: SonarSource/sonarcloud-github-action@master
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
```

**2. Review Assignment Automation:**

```yaml
# .github/CODEOWNERS
# Global owners
* @team-leads

# Frontend changes
/src/components/ @frontend-team
/src/styles/ @frontend-team
*.css @frontend-team
*.scss @frontend-team

# Backend changes
/src/api/ @backend-team
/src/services/ @backend-team
/src/models/ @backend-team

# Database changes
/migrations/ @database-team @backend-team
/scripts/db/ @database-team

# DevOps changes
/.github/workflows/ @devops-team
/docker/ @devops-team
/k8s/ @devops-team

# Documentation
/docs/ @technical-writers
README.md @technical-writers
```

**3. Review Metrics and Analytics:**

```javascript
// scripts/review-analytics.js
const { Octokit } = require("@octokit/rest");

class ReviewAnalytics {
  constructor(token, owner, repo) {
    this.octokit = new Octokit({ auth: token });
    this.owner = owner;
    this.repo = repo;
  }
  
  async getPRMetrics(timeframe = 30) {
    const since = new Date();
    since.setDate(since.getDate() - timeframe);
    
    const prs = await this.octokit.rest.pulls.list({
      owner: this.owner,
      repo: this.repo,
      state: 'closed',
      since: since.toISOString(),
    });
    
    const metrics = {
      totalPRs: prs.data.length,
      averageTimeToMerge: 0,
      reviewParticipation: {},
      approvalRates: {},
    };
    
    for (const pr of prs.data) {
      // Calculate time to merge
      const created = new Date(pr.created_at);
      const merged = new Date(pr.merged_at);
      const timeToMerge = (merged - created) / (1000 * 60 * 60); // hours
      
      metrics.averageTimeToMerge += timeToMerge;
      
      // Get reviews for this PR
      const reviews = await this.octokit.rest.pulls.listReviews({
        owner: this.owner,
        repo: this.repo,
        pull_number: pr.number,
      });
      
      // Track reviewer participation
      reviews.data.forEach(review => {
        const reviewer = review.user.login;
        if (!metrics.reviewParticipation[reviewer]) {
          metrics.reviewParticipation[reviewer] = 0;
        }
        metrics.reviewParticipation[reviewer]++;
      });
    }
    
    metrics.averageTimeToMerge /= prs.data.length;
    
    return metrics;
  }
}
```

---

## Navigation Links

⬅️ **[Previous: Vercel Questions](./vercel-questions.md)**  
➡️ **[Next: Stripe Questions](./stripe-questions.md)**  
🏠 **[Home: Interview Questions Index](./README.md)**

---

*This research covers GitHub platform features, Git version control fundamentals, and collaboration workflows for the Dev Partners Senior Full Stack Developer position.*
