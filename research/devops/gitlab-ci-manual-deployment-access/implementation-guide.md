# Implementation Guide: GitLab CI Manual Deployment Access

## 🚀 Overview

Step-by-step guide to configure manual deployment access in GitLab CI/CD pipelines, addressing the common confusion between project roles and actual deployment permissions.

## 🔧 Prerequisites

Before configuring manual deployment access:

- [ ] **GitLab Project Access**: Maintainer or Owner role on the project
- [ ] **Understanding of Current Setup**: Review existing protected branches and environments
- [ ] **Team Permissions**: Know which users need deployment access
- [ ] **Environment Strategy**: Identify which environments need manual approval

## 📋 Implementation Steps

### Step 1: Audit Current Permission Setup

#### 1.1 Check Project Roles
```bash
# Navigate to Project → Members
# Document current role assignments
```

| User | Project Role | Expected Deploy Access | Actual Deploy Access |
|------|--------------|------------------------|---------------------|
| user1 | Maintainer | ✅ | ❓ (Need to check) |
| user2 | Developer | ❌ | ❓ (Need to check) |

#### 1.2 Review Protected Branches
```bash
# Navigate to Settings → Repository → Protected Branches
# Check merge access rules
```

#### 1.3 Review Protected Environments
```bash
# Navigate to Settings → CI/CD → Protected Environments
# Check deployment access rules
```

### Step 2: Configure Protected Environments

#### 2.1 Basic Environment Protection
```yaml
# In GitLab UI: Settings → CI/CD → Protected Environments
Environment name: production
Deploy access levels:
  - Maintainers + Developers  # Role-based approach
  
# OR user-specific approach:
Deploy access levels:
  - user: john.doe
  - user: jane.smith
  - access_level: maintainer  # Plus role-based
```

#### 2.2 Advanced Environment Rules
```yaml
# For high-security environments
Environment name: production
Deploy access levels:
  - user: senior.developer
  - user: devops.lead
Required approvals: 2
Prevent deployments to environment: false
Restrict access by environment: true
```

### Step 3: Configure Pipeline Manual Jobs

#### 3.1 Basic Manual Job Configuration
```yaml
# .gitlab-ci.yml
deploy_production:
  stage: deploy
  script:
    - echo "Deploying to production..."
    - ./deploy-production.sh
  environment:
    name: production
    url: https://prod.example.com
  when: manual
  only:
    - main
```

#### 3.2 Manual Job with Conditions
```yaml
deploy_production:
  stage: deploy
  script:
    - echo "Deploying to production..."
  environment:
    name: production
  when: manual
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
      when: manual
      allow_failure: false
    - when: never
```

#### 3.3 Manual Job with User Restrictions
```yaml
deploy_production:
  stage: deploy
  script:
    - echo "Deploying to production..."
  environment:
    name: production
  when: manual
  rules:
    - if: $CI_COMMIT_BRANCH == "main" && $GITLAB_USER_LOGIN =~ /^(john\.doe|jane\.smith|devops\.lead)$/
      when: manual
    - when: never
```

### Step 4: Configure Branch Protection Rules

#### 4.1 Protected Branch Setup
```bash
# Navigate to Settings → Repository → Protected Branches
Branch: main
Allowed to push: Maintainers
Allowed to merge: Maintainers + Developers
Require approval from code owners: Yes (optional)
```

#### 4.2 User-Specific Branch Rules
```bash
# For projects with specific merge requirements
Branch: main
Allowed to push: 
  - user: senior.developer
  - user: devops.lead
Allowed to merge:
  - user: john.doe
  - user: jane.smith
  - access_level: maintainer
```

### Step 5: Implement Approval Workflows

#### 5.1 Basic Approval Configuration
```yaml
# .gitlab-ci.yml with approval gates
stages:
  - test
  - build
  - approve
  - deploy

run_tests:
  stage: test
  script:
    - npm test

build_app:
  stage: build
  script:
    - npm run build
  artifacts:
    paths:
      - dist/

request_approval:
  stage: approve
  script:
    - echo "Requesting production deployment approval..."
  when: manual
  environment:
    name: production-approval
  only:
    - main

deploy_production:
  stage: deploy
  script:
    - ./deploy-production.sh
  environment:
    name: production
  needs:
    - job: request_approval
  when: manual
  only:
    - main
```

#### 5.2 Multi-Stage Approval Process
```yaml
approve_staging:
  stage: approve-staging
  script:
    - echo "Approved for staging"
  when: manual
  environment:
    name: staging-approval

deploy_staging:
  stage: deploy-staging
  script:
    - ./deploy-staging.sh
  environment:
    name: staging
  needs:
    - job: approve_staging
  when: manual

approve_production:
  stage: approve-production
  script:
    - echo "Approved for production"
  when: manual
  environment:
    name: production-approval
  needs:
    - job: deploy_staging
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
      when: manual

deploy_production:
  stage: deploy-production
  script:
    - ./deploy-production.sh
  environment:
    name: production
  needs:
    - job: approve_production
  when: manual
```

## 🔐 Security Implementation

### Security-First Approach
```yaml
# High-security manual deployment
deploy_production:
  stage: deploy
  script:
    - |
      # Verify deployer identity
      echo "Deployer: $GITLAB_USER_NAME ($GITLAB_USER_LOGIN)"
      echo "Commit: $CI_COMMIT_SHA by $CI_COMMIT_AUTHOR"
      
      # Security checks
      ./security-scan.sh
      ./compliance-check.sh
      
      # Actual deployment
      ./deploy-production.sh
      
      # Notification
      ./notify-team.sh "Production deployed by $GITLAB_USER_NAME"
  environment:
    name: production
    url: https://prod.example.com
  when: manual
  timeout: 30 minutes
  allow_failure: false
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
      when: manual
```

## 🧪 Testing Your Configuration

### Test Checklist
- [ ] **Role-based Access**: Verify users with correct roles can trigger manual jobs
- [ ] **User-specific Access**: Confirm allowlisted users have deployment access
- [ ] **Negative Testing**: Ensure unauthorized users cannot trigger deployments
- [ ] **Environment Protection**: Verify protected environments enforce rules
- [ ] **Pipeline Flow**: Test complete manual approval workflow

### Testing Commands
```bash
# Test pipeline trigger (as different users)
git push origin main

# Check pipeline permissions
# Navigate to CI/CD → Pipelines → [Pipeline] → Manual jobs section

# Verify environment access
# Navigate to Deployments → Environments → [Environment]
```

## 🛠️ Common Configuration Scenarios

### Scenario 1: Small Team with Role-based Access
```yaml
# Simple role-based deployment
protected_environments:
  production:
    deploy_access_levels:
      - access_level: maintainer

# Pipeline configuration
deploy_production:
  when: manual
  environment: production
  only: [main]
```

### Scenario 2: Large Team with User-specific Access
```yaml
# User-specific deployment access
protected_environments:
  production:
    deploy_access_levels:
      - user: devops.lead
      - user: senior.developer1
      - user: senior.developer2

# Pipeline with user validation
deploy_production:
  when: manual
  environment: production
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
      when: manual
```

### Scenario 3: Mixed Approach with Escalation
```yaml
# Staging: Role-based, Production: User-specific
protected_environments:
  staging:
    deploy_access_levels:
      - access_level: developer
  production:
    deploy_access_levels:
      - user: devops.lead
      - user: product.owner
      - access_level: owner
```

## ⚡ Quick Fix for Common Issues

### Issue: "Manual job not visible to maintainer"
```yaml
# Solution: Check protected environment rules
# If environment uses user-specific rules, add the maintainer:
protected_environments:
  production:
    deploy_access_levels:
      - user: maintainer-username
      - access_level: maintainer  # Keep role-based as fallback
```

### Issue: "Manual job appears but can't be triggered"
```yaml
# Solution: Check pipeline rules and environment protection
deploy_production:
  rules:
    - if: $CI_COMMIT_BRANCH == "main"  # Ensure branch matches
      when: manual
      allow_failure: false  # Prevent skipping
```

## 🎯 Validation Steps

After implementation, verify:
1. [ ] Target users can see manual deployment jobs
2. [ ] Manual jobs can be successfully triggered
3. [ ] Unauthorized users cannot access manual jobs
4. [ ] Environment deployments are properly tracked
5. [ ] Approval workflows function as expected

---

## 📚 References

- GitLab CI/CD Configuration Reference
- Protected Environments Documentation
- Manual Jobs and Approval Workflows
- GitLab User Permissions Model

---

## 🧭 Navigation

← [Back to Executive Summary](./executive-summary.md) | [Next: Best Practices](./best-practices.md) →