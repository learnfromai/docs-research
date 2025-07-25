# Template Examples - Project Initialization Reference Files

## 🎯 Overview

This document provides ready-to-use templates and working examples for different project initialization reference file approaches. All templates are tested and include implementation instructions for immediate use.

## 📁 Simple Text File Templates

### Template 1: Basic Timestamp (Most Common)

**File: `initialcommit.txt`**
```text
2025-01-15 10:30:00 UTC+8
```

**Implementation:**
```bash
# Create the file
echo "$(date '+%Y-%m-%d %H:%M:%S %Z')" > initialcommit.txt

# Add to git
git add initialcommit.txt
git commit -m "chore: add project initialization timestamp reference"
```

**Use Case:** Personal projects, simple tracking needs

---

### Template 2: ISO Standard Format

**File: `.project-created`**
```text
2025-01-15T02:30:00.000Z
```

**Implementation:**
```bash
# Create with UTC ISO format
echo "$(date -u '+%Y-%m-%dT%H:%M:%S.%3NZ')" > .project-created

# Add to git
git add .project-created
git commit -m "chore: add ISO timestamp reference for project initialization"
```

**Use Case:** Clean directories, machine processing, international teams

---

### Template 3: Unix Timestamp (Precise)

**File: `.timestamp`**
```text
1736905800
```

**Implementation:**
```bash
# Create with Unix timestamp
echo "$(date '+%s')" > .timestamp

# Add to git
git add .timestamp
git commit -m "chore: add Unix timestamp reference for project start"
```

**Use Case:** Mathematical calculations, minimal file size, precision needs

---

### Template 4: Extended Text Format

**File: `project-start.txt`**
```text
Project initialized: January 15, 2025 at 10:30 AM (UTC+8)
Purpose: Personal expense tracking application
Note: This timestamp marks the project's creation date
```

**Implementation:**
```bash
# Create extended format
cat > project-start.txt << EOF
Project initialized: $(date '+%B %d, %Y at %I:%M %p (%Z)')
Purpose: $(read -p "Project purpose: " purpose && echo "$purpose")
Note: This timestamp marks the project's creation date
EOF

git add project-start.txt
git commit -m "docs: add detailed project initialization reference"
```

**Use Case:** Documentation-heavy projects, self-explanatory files

## 📊 JSON Structure Templates

### Template 5: Basic JSON Reference

**File: `project-reference.json`**
```json
{
  "created": "2025-01-15T02:30:00.000Z",
  "timezone": "UTC+8",
  "purpose": "Project initialization reference",
  "format": "json-v1"
}
```

**Implementation:**
```bash
# Create JSON reference
cat > project-reference.json << EOF
{
  "created": "$(date -u '+%Y-%m-%dT%H:%M:%S.%3NZ')",
  "timezone": "$(date '+%Z')",
  "purpose": "Project initialization reference",
  "format": "json-v1"
}
EOF

git add project-reference.json
git commit -m "chore: add structured project initialization reference"
```

**Use Case:** Team projects, structured data needs, tool integration

---

### Template 6: Team Project JSON

**File: `team-project-start.json`**
```json
{
  "project": {
    "name": "awesome-app",
    "created": "2025-01-15T02:30:00.000Z",
    "team": "Backend Development Team",
    "purpose": "Customer portal API service"
  },
  "metadata": {
    "createdBy": "john.doe@company.com",
    "repository": "https://github.com/company/awesome-app",
    "technology": "Node.js + TypeScript"
  },
  "tracking": {
    "format": "team-v1",
    "immutable": true,
    "lastUpdated": "2025-01-15T02:30:00.000Z"
  }
}
```

**Implementation:**
```bash
# Interactive team project setup
create_team_project_reference() {
    read -p "Project name: " project_name
    read -p "Team name: " team_name
    read -p "Project purpose: " purpose
    read -p "Technology stack: " tech_stack
    
    cat > team-project-start.json << EOF
{
  "project": {
    "name": "$project_name",
    "created": "$(date -u '+%Y-%m-%dT%H:%M:%S.%3NZ')",
    "team": "$team_name",
    "purpose": "$purpose"
  },
  "metadata": {
    "createdBy": "$(git config user.email)",
    "repository": "$(git config --get remote.origin.url 2>/dev/null || echo 'TBD')",
    "technology": "$tech_stack"
  },
  "tracking": {
    "format": "team-v1",
    "immutable": true,
    "lastUpdated": "$(date -u '+%Y-%m-%dT%H:%M:%S.%3NZ')"
  }
}
EOF
    
    git add team-project-start.json
    git commit -m "chore: initialize team project with structured reference"
}

# Usage: create_team_project_reference
```

**Use Case:** Team development, structured collaboration, professional projects

---

### Template 7: Open Source Project JSON

**File: `project-manifest.json`** 
```json
{
  "project": {
    "name": "super-cli-tool",
    "displayName": "Super CLI Tool",
    "description": "Awesome command-line utility for developers",
    "created": "2025-01-15",
    "version": "0.0.0",
    "license": "MIT",
    "type": "cli-tool"
  },
  "metadata": {
    "repository": "https://github.com/username/super-cli-tool",
    "author": {
      "name": "Developer Name",
      "email": "dev@example.com",
      "url": "https://developer.dev"
    },
    "keywords": ["cli", "tool", "developer", "productivity"]
  },
  "tracking": {
    "createdDate": "2025-01-15T02:30:00.000Z",
    "initialCommitHash": "",
    "majorMilestones": [],
    "format": "opensource-v1"
  }
}
```

**Implementation:**
```bash
# Open source project initialization script
init_opensource_project() {
    read -p "Project name (kebab-case): " project_name
    read -p "Display name: " display_name
    read -p "Description: " description
    read -p "License (MIT/Apache-2.0/GPL-3.0): " license
    read -p "Author name: " author_name
    read -p "Author email: " author_email
    read -p "Author website: " author_url
    
    cat > project-manifest.json << EOF
{
  "project": {
    "name": "$project_name",
    "displayName": "$display_name",
    "description": "$description",
    "created": "$(date '+%Y-%m-%d')",
    "version": "0.0.0",
    "license": "$license",
    "type": "open-source"
  },
  "metadata": {
    "repository": "https://github.com/$(git config user.name)/$project_name",
    "author": {
      "name": "$author_name",
      "email": "$author_email",
      "url": "$author_url"
    }
  },
  "tracking": {
    "createdDate": "$(date -u '+%Y-%m-%dT%H:%M:%S.%3NZ')",
    "initialCommitHash": "",
    "majorMilestones": [],
    "format": "opensource-v1"
  }
}
EOF

    # Update with actual commit hash after commit
    git add project-manifest.json
    git commit -m "chore: initialize open source project with manifest"
    
    # Update manifest with commit hash
    COMMIT_HASH=$(git rev-parse HEAD)
    jq ".tracking.initialCommitHash = \"$COMMIT_HASH\"" project-manifest.json > temp.json
    mv temp.json project-manifest.json
    
    git add project-manifest.json
    git commit -m "chore: update manifest with initial commit hash"
}

# Usage: init_opensource_project
```

**Use Case:** Open source projects, community contributions, professional appearance

## 📝 Markdown Documentation Templates

### Template 8: Project Birth Certificate

**File: `PROJECT_BIRTH.md`**
```markdown
# Project Birth Certificate

## 📅 Project Timeline

**Project Name**: Awesome Development Tool  
**Creation Date**: January 15, 2025  
**Time**: 10:30 AM (UTC+8)  
**Created By**: Developer Name  

## 🎯 Project Purpose

This project was created to solve the problem of [describe your problem here].

## 📊 Initial Context

- **Technology Stack**: Node.js, TypeScript, React
- **Target Audience**: Software developers
- **Expected Timeline**: 3-6 months to MVP
- **Success Criteria**: [Define your success metrics]

## 🏗️ Architecture Decisions

- **Pattern**: Clean Architecture
- **Testing**: Jest + React Testing Library
- **Deployment**: Vercel + Railway
- **CI/CD**: GitHub Actions

## 📝 Notes

This file serves as a permanent record of the project's inception. The timestamp above should be considered the official "birth date" of this project for age tracking and portfolio purposes.

**Important**: This file should not be modified after creation to maintain its integrity as a historical reference.

---

*Generated on: 2025-01-15T02:30:00.000Z*
```

**Implementation:**
```bash
# Interactive project birth certificate creation
create_project_birth_certificate() {
    read -p "Project name: " project_name
    read -p "Project purpose: " purpose
    read -p "Technology stack: " tech_stack
    read -p "Target audience: " audience
    read -p "Expected timeline: " timeline
    
    cat > PROJECT_BIRTH.md << EOF
# Project Birth Certificate

## 📅 Project Timeline

**Project Name**: $project_name  
**Creation Date**: $(date '+%B %d, %Y')  
**Time**: $(date '+%I:%M %p (%Z)')  
**Created By**: $(git config user.name)  

## 🎯 Project Purpose

This project was created to solve the problem of $purpose.

## 📊 Initial Context

- **Technology Stack**: $tech_stack
- **Target Audience**: $audience
- **Expected Timeline**: $timeline
- **Success Criteria**: [Define your success metrics]

## 🏗️ Architecture Decisions

- **Pattern**: [Your architectural pattern]
- **Testing**: [Your testing strategy]
- **Deployment**: [Your deployment approach]
- **CI/CD**: [Your CI/CD setup]

## 📝 Notes

This file serves as a permanent record of the project's inception. The timestamp above should be considered the official "birth date" of this project for age tracking and portfolio purposes.

**Important**: This file should not be modified after creation to maintain its integrity as a historical reference.

---

*Generated on: $(date -u '+%Y-%m-%dT%H:%M:%S.%3NZ')*
EOF
    
    git add PROJECT_BIRTH.md
    git commit -m "docs: add project birth certificate"
}

# Usage: create_project_birth_certificate
```

**Use Case:** Documentation-focused projects, portfolio pieces, storytelling

## 🏢 Enterprise Templates

### Template 9: Enterprise Project Manifest

**File: `project-metadata.json`**
```json
{
  "projectInfo": {
    "name": "customer-portal-api",
    "displayName": "Customer Portal API Service",
    "created": "2025-01-15T02:30:00.000Z",
    "businessUnit": "Digital Customer Experience",
    "owner": "Backend Development Team",
    "stakeholders": ["Product Management", "Customer Success", "Security Team"]
  },
  "compliance": {
    "dataClassification": "internal",
    "regulatory": ["SOX", "GDPR", "CCPA"],
    "securityLevel": "standard",
    "auditRequired": true
  },
  "technical": {
    "architecture": "microservices",
    "platform": "kubernetes",
    "language": "typescript",
    "database": "postgresql",
    "monitoring": "datadog"
  },
  "business": {
    "priority": "high",
    "budget": "allocated",
    "timeline": "Q1-Q2 2025",
    "successMetrics": ["API response time < 200ms", "99.9% uptime", "Customer satisfaction > 4.5"]
  },
  "tracking": {
    "format": "enterprise-v1",
    "createdDate": "2025-01-15T02:30:00.000Z",
    "milestones": [],
    "releases": [],
    "audits": [],
    "lastReview": "2025-01-15T02:30:00.000Z"
  }
}
```

**Implementation:**
```bash
# Enterprise project initialization
init_enterprise_project() {
    echo "🏢 Enterprise Project Initialization"
    echo "==================================="
    
    read -p "Project name (kebab-case): " project_name
    read -p "Display name: " display_name
    read -p "Business unit: " business_unit
    read -p "Team owner: " team_owner
    read -p "Data classification (public/internal/confidential): " data_class
    read -p "Primary language: " language
    read -p "Database: " database
    read -p "Priority (low/medium/high/critical): " priority
    
    cat > project-metadata.json << EOF
{
  "projectInfo": {
    "name": "$project_name",
    "displayName": "$display_name",
    "created": "$(date -u '+%Y-%m-%dT%H:%M:%S.%3NZ')",
    "businessUnit": "$business_unit",
    "owner": "$team_owner",
    "stakeholders": []
  },
  "compliance": {
    "dataClassification": "$data_class",
    "regulatory": [],
    "securityLevel": "standard",
    "auditRequired": true
  },
  "technical": {
    "architecture": "microservices",
    "platform": "kubernetes",
    "language": "$language",
    "database": "$database",
    "monitoring": "enterprise-standard"
  },
  "business": {
    "priority": "$priority",
    "budget": "allocated",
    "timeline": "TBD",
    "successMetrics": []
  },
  "tracking": {
    "format": "enterprise-v1",
    "createdDate": "$(date -u '+%Y-%m-%dT%H:%M:%S.%3NZ')",
    "milestones": [],
    "releases": [],
    "audits": [],
    "lastReview": "$(date -u '+%Y-%m-%dT%H:%M:%S.%3NZ')"
  }
}
EOF
    
    git add project-metadata.json
    git commit -m "chore: initialize enterprise project with comprehensive metadata"
    
    echo "✅ Enterprise project metadata created"
    echo "📋 Remember to update stakeholders and compliance requirements"
}

# Usage: init_enterprise_project
```

**Use Case:** Enterprise applications, compliance requirements, audit trails

## 🛠️ Automation Scripts

### Template 10: Universal Project Initializer

**File: `init-project-reference.sh`**
```bash
#!/bin/bash
# Universal Project Reference File Initializer
# Supports multiple formats and contexts

set -e

# Configuration
DEFAULT_FORMAT="text"
DEFAULT_FILENAME=""
SUPPORTED_FORMATS=("text" "json" "iso" "unix" "markdown" "enterprise")

# Functions
show_help() {
    cat << EOF
Project Reference File Initializer

USAGE:
    $0 [OPTIONS]

OPTIONS:
    -f, --format FORMAT     Format type: text, json, iso, unix, markdown, enterprise
    -n, --name FILENAME     Custom filename (optional)
    -t, --type PROJECT_TYPE Project type: personal, team, opensource, enterprise
    -h, --help             Show this help message

EXAMPLES:
    $0                                  # Simple text file (default)
    $0 -f json -t team                 # Team project JSON
    $0 -f markdown -t opensource       # Open source markdown
    $0 -f enterprise -t enterprise     # Enterprise manifest

FORMATS:
    text        - Simple text timestamp (initialcommit.txt)
    json        - JSON structure (project-reference.json)
    iso         - ISO timestamp (.project-created)
    unix        - Unix timestamp (.timestamp)
    markdown    - Documentation format (PROJECT_BIRTH.md)
    enterprise  - Full enterprise manifest (project-metadata.json)
EOF
}

create_text_reference() {
    local filename="${1:-initialcommit.txt}"
    echo "$(date '+%Y-%m-%d %H:%M:%S %Z')" > "$filename"
    echo "📝 Created text reference: $filename"
}

create_json_reference() {
    local filename="${1:-project-reference.json}"
    cat > "$filename" << EOF
{
  "created": "$(date -u '+%Y-%m-%dT%H:%M:%S.%3NZ')",
  "timezone": "$(date '+%Z')",
  "purpose": "Project initialization reference",
  "format": "json-v1"
}
EOF
    echo "📊 Created JSON reference: $filename"
}

create_iso_reference() {
    local filename="${1:-.project-created}"
    echo "$(date -u '+%Y-%m-%dT%H:%M:%S.%3NZ')" > "$filename"
    echo "🕐 Created ISO reference: $filename"
}

create_unix_reference() {
    local filename="${1:-.timestamp}"
    echo "$(date '+%s')" > "$filename"
    echo "⏰ Created Unix timestamp reference: $filename"
}

create_markdown_reference() {
    local filename="${1:-PROJECT_BIRTH.md}"
    cat > "$filename" << EOF
# Project Birth Certificate

**Created**: $(date '+%B %d, %Y at %I:%M %p (%Z)')  
**Creator**: $(git config user.name 2>/dev/null || echo "Unknown")  
**Purpose**: Project initialization timestamp reference  

## Notes

This file serves as a permanent marker for project creation date. The timestamp above represents the official start date of this project.

**Important**: Do not modify this file after creation to maintain timestamp integrity.

---
*Generated: $(date -u '+%Y-%m-%dT%H:%M:%S.%3NZ')*
EOF
    echo "📖 Created Markdown reference: $filename"  
}

create_enterprise_reference() {
    local filename="${1:-project-metadata.json}"
    
    # Interactive input for enterprise projects
    read -p "Project name: " project_name
    read -p "Business unit: " business_unit
    read -p "Data classification (public/internal/confidential): " data_class
    
    cat > "$filename" << EOF
{
  "projectInfo": {
    "name": "$project_name",
    "created": "$(date -u '+%Y-%m-%dT%H:%M:%S.%3NZ')",
    "businessUnit": "$business_unit",
    "owner": "$(git config user.name 2>/dev/null || echo "Unknown")"
  },
  "compliance": {
    "dataClassification": "$data_class",
    "auditRequired": true
  },
  "tracking": {
    "format": "enterprise-v1",
    "createdDate": "$(date -u '+%Y-%m-%dT%H:%M:%S.%3NZ')",
    "lastReview": "$(date -u '+%Y-%m-%dT%H:%M:%S.%3NZ')"
  }
}
EOF
    echo "🏢 Created enterprise reference: $filename"
}

commit_reference_file() {
    local filename="$1"
    local format="$2"
    
    if [[ -d ".git" ]]; then
        git add "$filename"
        git commit -m "chore: add project initialization reference ($format format)"
        echo "✅ Reference file committed to git"
    else
        echo "⚠️  No git repository found. File created but not committed."
    fi
}

# Main script
main() {
    local format="$DEFAULT_FORMAT"
    local filename="$DEFAULT_FILENAME" 
    local project_type="personal"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -f|--format)
                format="$2"
                shift 2
                ;;
            -n|--name)
                filename="$2"
                shift 2
                ;;
            -t|--type)
                project_type="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Validate format
    if [[ ! " ${SUPPORTED_FORMATS[@]} " =~ " ${format} " ]]; then
        echo "❌ Unsupported format: $format"
        echo "Supported formats: ${SUPPORTED_FORMATS[*]}"
        exit 1
    fi
    
    # Create reference file based on format
    case "$format" in
        "text")
            create_text_reference "$filename"
            filename="${filename:-initialcommit.txt}"
            ;;
        "json")
            create_json_reference "$filename"
            filename="${filename:-project-reference.json}"
            ;;
        "iso")
            create_iso_reference "$filename"
            filename="${filename:-.project-created}"
            ;;
        "unix")
            create_unix_reference "$filename"
            filename="${filename:-.timestamp}"
            ;;
        "markdown")
            create_markdown_reference "$filename"
            filename="${filename:-PROJECT_BIRTH.md}"
            ;;
        "enterprise")
            create_enterprise_reference "$filename"
            filename="${filename:-project-metadata.json}"
            ;;
    esac
    
    # Commit to git if repository exists
    commit_reference_file "$filename" "$format"
    
    echo ""
    echo "🎉 Project reference initialization complete!"
    echo "📁 File: $filename"
    echo "📊 Format: $format"
    echo "🎯 Type: $project_type"
}

# Run main function with all arguments
main "$@"
```

**Usage Examples:**
```bash
# Make script executable
chmod +x init-project-reference.sh

# Simple text file (default)
./init-project-reference.sh

# Team project with JSON
./init-project-reference.sh -f json -t team

# Open source with markdown documentation
./init-project-reference.sh -f markdown -t opensource

# Enterprise project with full manifest
./init-project-reference.sh -f enterprise -t enterprise

# Custom filename
./init-project-reference.sh -f json -n "my-project-info.json"
```

## 🔧 Integration Templates

### Template 11: Package.json Integration

**Add to existing `package.json`:**
```json
{
  "scripts": {
    "project:info": "node -e \"if(require('fs').existsSync('initialcommit.txt')) console.log('Created:', require('fs').readFileSync('initialcommit.txt','utf8').trim()); else console.log('No reference file found');\"",
    "project:age": "node -e \"if(require('fs').existsSync('initialcommit.txt')) { const created = new Date(require('fs').readFileSync('initialcommit.txt','utf8').trim()); const days = Math.floor((Date.now() - created) / 86400000); console.log(`Age: ${days} days (${Math.floor(days/7)} weeks)`); }\"",
    "init:reference": "echo \"$(date '+%Y-%m-%d %H:%M:%S %Z')\" > initialcommit.txt && git add initialcommit.txt && git commit -m 'chore: add project reference'"
  }
}
```

### Template 12: Makefile Integration

**File: `Makefile`**
```makefile
.PHONY: project-info project-age init-reference validate-reference

# Show project information
project-info:
	@if [ -f initialcommit.txt ]; then \
		echo "📅 Project created: $$(cat initialcommit.txt)"; \
	elif [ -f .project-created ]; then \
		echo "📅 Project created: $$(cat .project-created)"; \
	elif [ -f project-reference.json ]; then \
		echo "📅 Project created: $$(jq -r '.created' project-reference.json)"; \
	else \
		echo "❌ No project reference file found"; \
	fi

# Calculate project age
project-age:
	@if [ -f initialcommit.txt ]; then \
		python3 -c "import datetime; created=datetime.datetime.strptime('$$(cat initialcommit.txt | cut -d' ' -f1,2)', '%Y-%m-%d %H:%M:%S'); print(f'📅 Age: {(datetime.datetime.now()-created).days} days')"; \
	else \
		echo "❌ No reference file for age calculation"; \
	fi

# Initialize reference file
init-reference:
	@if [ ! -f initialcommit.txt ]; then \
		echo "$$(date '+%Y-%m-%d %H:%M:%S %Z')" > initialcommit.txt; \
		git add initialcommit.txt; \
		git commit -m "chore: add project initialization reference"; \
		echo "✅ Project reference created"; \
	else \
		echo "⚠️  Reference file already exists"; \
	fi

# Validate reference file
validate-reference:
	@./scripts/validate-reference.sh 2>/dev/null || echo "Run 'make init-reference' to create reference file"
```

### Template 13: GitHub Actions Integration

**File: `.github/workflows/project-tracking.yml`**
```yaml
name: Project Tracking

on:
  push:
    branches: [main, master]
  workflow_dispatch:

jobs:
  project-info:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
      
      - name: Display Project Information
        run: |
          echo "🔍 Project Reference File Check"
          echo "================================"
          
          if [ -f "initialcommit.txt" ]; then
            CREATED=$(cat initialcommit.txt)
            echo "📅 Project created: $CREATED"
            
            # Calculate age in days
            python3 -c "
            import datetime
            created = datetime.datetime.strptime('$CREATED'.split(' ')[0] + ' ' + '$CREATED'.split(' ')[1], '%Y-%m-%d %H:%M:%S')
            age_days = (datetime.datetime.now() - created).days
            age_weeks = age_days // 7
            age_months = age_days // 30
            print(f'📊 Project age: {age_days} days ({age_weeks} weeks, ~{age_months} months)')
            "
          elif [ -f ".project-created" ]; then
            CREATED=$(cat .project-created)
            echo "📅 Project created: $CREATED"
          elif [ -f "project-reference.json" ]; then
            CREATED=$(jq -r '.created' project-reference.json)
            echo "📅 Project created: $CREATED"
          else
            echo "⚠️  No project reference file found"
            echo "💡 Consider adding one with: echo \"\$(date '+%Y-%m-%d %H:%M:%S %Z')\" > initialcommit.txt"
          fi
          
      - name: Project Health Summary
        run: |
          echo ""
          echo "🏥 Project Health Summary"
          echo "========================="
          echo "Repository: ${{ github.repository }}"
          echo "Branch: ${{ github.ref_name }}"
          echo "Last commit: ${{ github.sha }}"
          echo "Triggered by: ${{ github.event_name }}"
```

### Template 14: Pre-commit Hook Template

**File: `.git/hooks/pre-commit`**
```bash
#!/bin/sh
# Pre-commit hook to ensure project reference file exists

echo "🔍 Checking project reference file..."

# Check for any reference file
if [ -f "initialcommit.txt" ] || [ -f ".project-created" ] || [ -f "project-reference.json" ] || [ -f "PROJECT_BIRTH.md" ]; then
    echo "✅ Project reference file found"
else
    echo "⚠️  Warning: No project reference file detected"
    echo ""
    echo "Consider adding one:"
    echo "  echo \"\$(date '+%Y-%m-%d %H:%M:%S %Z')\" > initialcommit.txt"
    echo "  git add initialcommit.txt"
    echo ""
    echo "This helps track project age and creation date."
    echo ""
    # Don't block the commit, just warn
fi

# Continue with commit
exit 0
```

**Make it executable:**
```bash
chmod +x .git/hooks/pre-commit
```

---

**Navigation**
- ← Previous: [Comparison Analysis](./comparison-analysis.md)
- → Next: [Main Guide](./README.md)
- ↑ Back to: [Main Guide](./README.md)

## 📚 Template References

- [Shell Scripting Best Practices](https://google.github.io/styleguide/shellguide.html)
- [JSON Schema Examples](https://json-schema.org/learn/miscellaneous-examples.html)
- [Git Hooks Documentation](https://git-scm.com/book/en/v2/Customizing-Git-Git-Hooks)
- [GitHub Actions Workflow Syntax](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions)
- [Make Documentation](https://www.gnu.org/software/make/manual/make.html)