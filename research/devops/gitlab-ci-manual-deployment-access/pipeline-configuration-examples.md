# Pipeline Configuration Examples: GitLab CI Manual Deployment Access

## 🎯 Overview

Practical GitLab CI/CD pipeline configurations demonstrating various manual deployment access patterns, from simple role-based setups to complex approval workflows with security controls.

## 🚀 Basic Manual Deployment Configurations

### 1. Simple Manual Deploy

```yaml
# .gitlab-ci.yml - Basic manual deployment
stages:
  - build
  - deploy

build_app:
  stage: build
  script:
    - echo "Building application..."
    - npm run build
  artifacts:
    paths:
      - dist/
    expire_in: 1 hour

deploy_production:
  stage: deploy
  script:
    - echo "Deploying to production..."
    - ./deploy-script.sh
  environment:
    name: production
    url: https://prod.example.com
  when: manual
  only:
    - main
  needs:
    - build_app
```

### 2. Manual Deploy with Environment Protection

```yaml
# .gitlab-ci.yml - With protected environment
deploy_production:
  stage: deploy
  image: alpine:latest
  script:
    - echo "Deploying by: $GITLAB_USER_LOGIN"
    - echo "Commit: $CI_COMMIT_SHORT_SHA"
    - ./deploy-production.sh
  environment:
    name: production  # Must be configured as protected environment
    url: https://prod.example.com
    deployment_tier: production
  when: manual
  allow_failure: false
  timeout: 30 minutes
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
      when: manual
```

## 🔐 Role-Based Access Examples

### 3. Multi-Environment Role-Based

```yaml
# .gitlab-ci.yml - Role-based access for different environments
stages:
  - test
  - build
  - deploy-dev
  - deploy-staging
  - deploy-prod

variables:
  DOCKER_IMAGE: $CI_REGISTRY_IMAGE:$CI_COMMIT_SHORT_SHA

build:
  stage: build
  script:
    - docker build -t $DOCKER_IMAGE .
    - docker push $DOCKER_IMAGE

# Auto-deploy to development (Developer+)
deploy_development:
  stage: deploy-dev
  script:
    - ./deploy.sh development $DOCKER_IMAGE
  environment:
    name: development
    url: https://dev.example.com
  rules:
    - if: $CI_COMMIT_BRANCH != "main"
      when: on_success

# Manual deploy to staging (Maintainer+)
deploy_staging:
  stage: deploy-staging
  script:
    - ./deploy.sh staging $DOCKER_IMAGE
  environment:
    name: staging
    url: https://staging.example.com
  when: manual
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
      when: manual
  needs:
    - build

# Manual deploy to production (Protected environment)
deploy_production:
  stage: deploy-prod
  script:
    - ./deploy.sh production $DOCKER_IMAGE
  environment:
    name: production
    url: https://prod.example.com
  when: manual
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
      when: manual
  needs:
    - build
```

### 4. Role-Based with Approval Gates

```yaml
# .gitlab-ci.yml - Role-based with approval workflow
stages:
  - build
  - approve
  - deploy

build_app:
  stage: build
  script:
    - npm run build
  artifacts:
    paths:
      - dist/

# Approval gate (Maintainer+ can approve)
approve_production:
  stage: approve
  image: alpine:latest
  script:
    - echo "Production deployment approved by $GITLAB_USER_NAME"
    - echo "Commit: $CI_COMMIT_MESSAGE"
    - echo "Approver: $GITLAB_USER_LOGIN" > approval.txt
  artifacts:
    paths:
      - approval.txt
    expire_in: 1 hour
  environment:
    name: production-approval
  when: manual
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
      when: manual
  needs:
    - build_app

deploy_production:
  stage: deploy
  script:
    - echo "Deploying with approval from $(cat approval.txt)"
    - ./deploy-production.sh
  environment:
    name: production
  needs:
    - approve_production
  when: on_success
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
```

## 👤 User-Specific Access Examples

### 5. User-Specific Manual Deploy

```yaml
# .gitlab-ci.yml - User-specific deployment access
deploy_production:
  stage: deploy
  script:
    - |
      # Validate authorized users
      AUTHORIZED_USERS="devops.lead senior.dev1 senior.dev2 product.owner"
      
      if echo "$AUTHORIZED_USERS" | grep -q "$GITLAB_USER_LOGIN"; then
        echo "✅ User $GITLAB_USER_LOGIN authorized for production deployment"
        ./deploy-production.sh
      else
        echo "❌ User $GITLAB_USER_LOGIN not authorized for production deployment"
        echo "Authorized users: $AUTHORIZED_USERS"
        exit 1
      fi
  environment:
    name: production
  when: manual
  rules:
    # Only show manual job for authorized users
    - if: $CI_COMMIT_BRANCH == "main" && $GITLAB_USER_LOGIN =~ /^(devops\.lead|senior\.dev[12]|product\.owner)$/
      when: manual
    - when: never
```

### 6. User-Specific with Time Restrictions

```yaml
# .gitlab-ci.yml - User-specific with business hours restriction
deploy_production:
  stage: deploy
  script:
    - |
      # Check business hours (UTC)
      HOUR=$(date -u +%H)
      DAY=$(date -u +%u)  # 1-7, Monday-Sunday
      
      # Allow deployments Mon-Fri 9-17 UTC, or for emergency users anytime
      EMERGENCY_USERS="devops.lead sre.oncall"
      
      if echo "$EMERGENCY_USERS" | grep -q "$GITLAB_USER_LOGIN"; then
        echo "✅ Emergency user - deployment allowed anytime"
      elif [ "$DAY" -le 5 ] && [ "$HOUR" -ge 9 ] && [ "$HOUR" -lt 17 ]; then
        echo "✅ Business hours - deployment allowed"
      else
        echo "❌ Outside business hours - emergency users only"
        exit 1
      fi
      
      ./deploy-production.sh
  environment:
    name: production
  when: manual
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
      when: manual
```

## 🔄 Hybrid Access Examples

### 7. Hybrid Role and User-Based

```yaml
# .gitlab-ci.yml - Hybrid approach
variables:
  PRODUCTION_ROLES: "owner maintainer"
  PRODUCTION_USERS: "devops.lead senior.architect"

deploy_production:
  stage: deploy
  script:
    - |
      # Check if user has required role or is in user list
      USER_ROLE=$(curl -s -H "PRIVATE-TOKEN: $API_TOKEN" \
        "$CI_API_V4_URL/projects/$CI_PROJECT_ID/members/$CI_USER_ID" | \
        jq -r '.access_level')
      
      # GitLab access levels: 50=Owner, 40=Maintainer, 30=Developer
      AUTHORIZED=false
      
      # Check role-based access
      if [ "$USER_ROLE" -ge 40 ]; then  # Maintainer or Owner
        AUTHORIZED=true
        echo "✅ Access granted via role (level: $USER_ROLE)"
      fi
      
      # Check user-specific access
      if echo "$PRODUCTION_USERS" | grep -q "$GITLAB_USER_LOGIN"; then
        AUTHORIZED=true
        echo "✅ Access granted via user whitelist"
      fi
      
      if [ "$AUTHORIZED" = "true" ]; then
        ./deploy-production.sh
      else
        echo "❌ Access denied - insufficient privileges"
        exit 1
      fi
  environment:
    name: production
  when: manual
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
      when: manual
```

## 🏗️ Advanced Approval Workflows

### 8. Multi-Stage Approval Process

```yaml
# .gitlab-ci.yml - Multi-stage approval workflow
stages:
  - build
  - security
  - approve-staging
  - deploy-staging
  - approve-prod
  - deploy-prod
  - verify

build:
  stage: build
  script: ./build.sh
  artifacts:
    paths: [dist/]

security_scan:
  stage: security
  script:
    - ./security-scan.sh
    - ./vulnerability-check.sh
  artifacts:
    reports:
      sast: security-report.json

# First approval: Staging deployment
approve_staging:
  stage: approve-staging
  script:
    - echo "Staging approved by $GITLAB_USER_NAME"
  environment:
    name: staging-approval
  when: manual
  needs: [build, security_scan]
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
      when: manual

deploy_staging:
  stage: deploy-staging
  script: ./deploy.sh staging
  environment:
    name: staging
    url: https://staging.example.com
  needs: [approve_staging]
  when: on_success

# Second approval: Production deployment (requires different approver)
approve_production:
  stage: approve-prod
  script:
    - |
      # Ensure different approver than staging
      STAGING_APPROVER=$(cat staging-approval.log || echo "unknown")
      if [ "$GITLAB_USER_LOGIN" = "$STAGING_APPROVER" ]; then
        echo "❌ Production approval requires different user than staging"
        exit 1
      fi
      echo "Production approved by $GITLAB_USER_NAME"
  environment:
    name: production-approval
  when: manual
  needs: [deploy_staging]
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
      when: manual

deploy_production:
  stage: deploy-prod
  script: ./deploy.sh production
  environment:
    name: production
    url: https://prod.example.com
  needs: [approve_production]
  when: on_success

verify_production:
  stage: verify
  script:
    - ./health-check.sh
    - ./smoke-tests.sh
  needs: [deploy_production]
  when: on_success
```

### 9. Emergency Hotfix Pipeline

```yaml
# .gitlab-ci.yml - Emergency hotfix with special permissions
.hotfix_rules: &hotfix_rules
  rules:
    - if: $CI_COMMIT_MESSAGE =~ /\[HOTFIX\]/i && $CI_COMMIT_BRANCH == "main"
      when: manual
      allow_failure: false

emergency_hotfix:
  stage: deploy
  script:
    - |
      echo "🚨 EMERGENCY HOTFIX DEPLOYMENT 🚨"
      echo "Deployer: $GITLAB_USER_NAME ($GITLAB_USER_LOGIN)"
      echo "Commit: $CI_COMMIT_SHORT_SHA"
      echo "Message: $CI_COMMIT_MESSAGE"
      
      # Validate emergency deployers
      EMERGENCY_USERS="devops.lead sre.oncall platform.lead"
      if ! echo "$EMERGENCY_USERS" | grep -q "$GITLAB_USER_LOGIN"; then
        echo "❌ User not authorized for emergency deployments"
        exit 1
      fi
      
      # Quick validation
      ./quick-tests.sh
      
      # Deploy
      ./emergency-deploy.sh
      
      # Immediate notification
      ./notify-emergency-deployment.sh
  environment:
    name: production
    url: https://prod.example.com
  timeout: 15 minutes
  <<: *hotfix_rules

# Follow-up verification job
verify_hotfix:
  stage: verify
  script:
    - sleep 60  # Wait for deployment to stabilize
    - ./comprehensive-health-check.sh
    - ./create-incident-report.sh
  needs: [emergency_hotfix]
  when: on_success
  <<: *hotfix_rules
```

## 🔒 Security-Enhanced Examples

### 10. High-Security Production Deploy

```yaml
# .gitlab-ci.yml - High-security deployment with full audit trail
deploy_production:
  stage: deploy
  image: secure-deploy:latest
  script:
    - |
      # Comprehensive pre-deployment checks
      echo "=== PRODUCTION DEPLOYMENT SECURITY PROTOCOL ==="
      
      # 1. Validate deployer
      ./validate-deployer.sh "$GITLAB_USER_LOGIN"
      
      # 2. Security scan
      ./security-scan.sh
      
      # 3. Compliance check
      ./compliance-check.sh
      
      # 4. Create audit record
      cat << EOF > deployment-audit.json
      {
        "timestamp": "$(date -Iseconds)",
        "deployer": {
          "login": "$GITLAB_USER_LOGIN", 
          "name": "$GITLAB_USER_NAME",
          "email": "$GITLAB_USER_EMAIL"
        },
        "commit": {
          "sha": "$CI_COMMIT_SHA",
          "author": "$CI_COMMIT_AUTHOR",
          "message": "$CI_COMMIT_MESSAGE"
        },
        "pipeline": {
          "id": "$CI_PIPELINE_ID",
          "url": "$CI_PIPELINE_URL"
        },
        "environment": "production",
        "security_scan": "passed",
        "compliance_check": "passed"
      }
      EOF
      
      # 5. Send to audit system
      ./send-audit-log.sh deployment-audit.json
      
      # 6. Execute deployment
      ./deploy-production.sh
      
      # 7. Post-deployment verification
      ./verify-deployment.sh
      
      # 8. Notification
      ./notify-stakeholders.sh
  environment:
    name: production
    url: https://prod.example.com
  artifacts:
    reports:
      audit: deployment-audit.json
    expire_in: 7 days
  when: manual
  timeout: 45 minutes
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
      when: manual
```

### 11. Deployment with External Approval

```yaml
# .gitlab-ci.yml - External approval system integration
request_approval:
  stage: approve
  script:
    - |
      # Submit approval request to external system
      APPROVAL_ID=$(./request-external-approval.sh \
        --deployer "$GITLAB_USER_LOGIN" \
        --commit "$CI_COMMIT_SHA" \
        --environment "production")
      
      echo "Approval request submitted: $APPROVAL_ID"
      echo "APPROVAL_ID=$APPROVAL_ID" > approval.env
  artifacts:
    reports:
      dotenv: approval.env
  environment:
    name: production-approval-request
  when: manual
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
      when: manual

deploy_production:
  stage: deploy
  script:
    - |
      # Check approval status
      if ! ./check-approval-status.sh "$APPROVAL_ID"; then
        echo "❌ External approval not granted"
        exit 1
      fi
      
      echo "✅ External approval confirmed: $APPROVAL_ID"
      ./deploy-production.sh
  environment:
    name: production
  needs:
    - job: request_approval
      artifacts: true
  when: manual
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
      when: manual
```

## 📊 Monitoring and Metrics Examples

### 12. Deployment with Metrics Collection

```yaml
# .gitlab-ci.yml - Deployment with comprehensive metrics
deploy_production:
  stage: deploy
  script:
    - |
      # Start metrics collection
      DEPLOY_START=$(date +%s)
      
      # Collect deployment context
      ./collect-deployment-context.sh
      
      # Execute deployment with progress tracking
      ./deploy-with-metrics.sh
      
      # Calculate deployment duration
      DEPLOY_END=$(date +%s)
      DEPLOY_DURATION=$((DEPLOY_END - DEPLOY_START))
      
      # Send metrics
      ./send-metric.sh "deployment_duration" "$DEPLOY_DURATION"
      ./send-metric.sh "deployment_user" "$GITLAB_USER_LOGIN" 
      ./send-metric.sh "deployment_success" "1"
      
      echo "Deployment completed in ${DEPLOY_DURATION}s"
  after_script:
    - |
      # Always send completion metric, even on failure
      if [ "$CI_JOB_STATUS" = "failed" ]; then
        ./send-metric.sh "deployment_success" "0"
        ./send-alert.sh "Production deployment failed"
      fi
  environment:
    name: production
  when: manual
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
      when: manual
```

## 🔧 Configuration Templates

### Environment Protection Template

```bash
#!/bin/bash
# setup-protected-environment.sh
# Script to configure protected environment via GitLab API

PROJECT_ID="$1"
ENV_NAME="$2"
ACCESS_LEVEL="$3"  # maintainer, developer, or user:username

curl --request POST \
     --header "PRIVATE-TOKEN: $GITLAB_ACCESS_TOKEN" \
     --header "Content-Type: application/json" \
     --data '{
       "name": "'$ENV_NAME'",
       "deploy_access_levels": [
         {"access_level": "'$ACCESS_LEVEL'"}
       ],
       "required_approval_count": 1
     }' \
     "https://gitlab.example.com/api/v4/projects/$PROJECT_ID/protected_environments"
```

### User Permission Validation Script

```bash
#!/bin/bash
# validate-user-permissions.sh
# Validate user has required permissions for deployment

USER_LOGIN="$1"
ENVIRONMENT="$2"
PROJECT_ID="$3"

# Check user's project role
USER_ROLE=$(curl -s -H "PRIVATE-TOKEN: $GITLAB_ACCESS_TOKEN" \
  "https://gitlab.example.com/api/v4/projects/$PROJECT_ID/members/all" | \
  jq -r ".[] | select(.username == \"$USER_LOGIN\") | .access_level")

# Check environment protection rules
ENV_RULES=$(curl -s -H "PRIVATE-TOKEN: $GITLAB_ACCESS_TOKEN" \
  "https://gitlab.example.com/api/v4/projects/$PROJECT_ID/protected_environments" | \
  jq -r ".[] | select(.name == \"$ENVIRONMENT\")")

echo "User: $USER_LOGIN"
echo "Role Level: $USER_ROLE"
echo "Environment: $ENVIRONMENT"
echo "Rules: $ENV_RULES"

# Validation logic here...
```

---

## 📚 References

- GitLab CI/CD Pipeline Configuration Reference
- GitLab API Documentation for Protected Environments
- Security Best Practices for CI/CD Pipelines
- Deployment Automation Patterns

---

## 🧭 Navigation

← [Back to Permission Models Analysis](./permission-models-analysis.md) | [Next: Security Considerations](./security-considerations.md) →