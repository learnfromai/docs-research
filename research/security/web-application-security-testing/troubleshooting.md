# Troubleshooting - Common Security Testing Issues and Solutions

## 🎯 Overview

This troubleshooting guide addresses common issues encountered during web application security testing for EdTech platforms. It provides practical solutions, workarounds, and best practices for resolving security testing challenges while maintaining compliance with FERPA and international regulations.

## 🔧 Tool-Specific Troubleshooting

### OWASP ZAP Issues

#### Issue: ZAP Scan Fails with Authentication Errors
**Symptoms**:
- Authentication context not properly set
- Sessions expire during scanning
- 401/403 errors in scan results

**Solution**:
```bash
# Configure ZAP authentication properly
docker run -v $(pwd):/zap/wrk/:rw -t owasp/zap2docker-stable zap-baseline.py \
  -t https://edtech-platform.com \
  -c auth-config.conf \
  --auth-url https://edtech-platform.com/login \
  --auth-username test@student.com \
  --auth-password testpassword123 \
  --auth-loginform "username={%username%}&password={%password%}" \
  --auth-exclude "logout,signout"
```

**Auth Configuration File** (`auth-config.conf`):
```
# Authentication configuration for EdTech platform
context.name = EdTech Platform
context.include = https://edtech-platform.com.*
context.exclude = https://edtech-platform.com/static.*

# Session management
session.method = cookie
session.name = sessionid

# Authentication
auth.method = form
auth.loginurl = https://edtech-platform.com/login
auth.username = username
auth.password = password
auth.usernamefield = email
auth.passwordfield = password
auth.loginform = email={%username%}&password={%password%}&csrf_token={%csrf_token%}
```

#### Issue: ZAP Produces Too Many False Positives
**Symptoms**:
- High number of low-severity findings
- False positives in legitimate functionality
- Scan reports are overwhelming

**Solution**:
```bash
# Create custom rules file to reduce false positives
# .zap/rules.tsv
IGNORE	https://edtech\.platform\.com/static/.*	.*	Static files
IGNORE	https://edtech\.platform\.com/health	.*	Health check endpoint
IGNORE	https://edtech\.platform\.com/metrics	.*	Monitoring endpoint
WARN	https://edtech\.platform\.com/api/public/.*	10021	Public API warnings only
FAIL	https://edtech\.platform\.com/api/students/.*	.*	Student data endpoints
FAIL	https://edtech\.platform\.com/admin/.*	.*	Admin endpoints
```

#### Issue: ZAP Scan Takes Too Long
**Symptoms**:
- Scans running for hours without completion
- CI/CD pipeline timeouts
- Resource exhaustion

**Solution**:
```python
# zap_optimization.py - Optimized ZAP scanning
import time
from zapv2 import ZAPv2

def configure_optimized_zap_scan():
    zap = ZAPv2(proxies={'http': 'http://127.0.0.1:8080', 'https': 'http://127.0.0.1:8080'})
    
    # Optimize spider settings
    zap.spider.set_option_max_depth(3)  # Limit crawl depth
    zap.spider.set_option_max_children(50)  # Limit pages per directory
    zap.spider.set_option_max_duration(10)  # 10 minutes max for spidering
    
    # Optimize active scan settings
    zap.ascan.set_option_thread_per_host(3)  # Reduce concurrent threads
    zap.ascan.set_option_max_rule_duration_in_mins(5)  # Limit rule execution time
    zap.ascan.set_option_delay_in_ms(100)  # Add delay between requests
    
    # Exclude time-consuming tests for quick scans
    zap.ascan.disable_scanners('90019,90020,90021')  # Disable slow scanners
    
    return zap

# Quick scan implementation
def run_quick_security_scan(target_url):
    zap = configure_optimized_zap_scan()
    
    # Start spider with timeout
    spider_id = zap.spider.scan(target_url)
    
    # Monitor spider progress with timeout
    start_time = time.time()
    timeout = 600  # 10 minutes
    
    while int(zap.spider.status(spider_id)) < 100:
        if time.time() - start_time > timeout:
            zap.spider.stop(spider_id)
            break
        time.sleep(5)
    
    # Run focused active scan
    ascan_id = zap.ascan.scan(target_url)
    
    # Monitor active scan with timeout
    start_time = time.time()
    timeout = 1800  # 30 minutes
    
    while int(zap.ascan.status(ascan_id)) < 100:
        if time.time() - start_time > timeout:
            zap.ascan.stop(ascan_id)
            break
        time.sleep(10)
    
    # Get results
    alerts = zap.core.alerts()
    return alerts
```

### SonarQube Issues

#### Issue: SonarQube Analysis Fails with Memory Errors
**Symptoms**:
- OutOfMemoryError during analysis
- Analysis fails on large codebases
- CI/CD pipeline crashes

**Solution**:
```bash
# Increase memory allocation for SonarQube scanner
export SONAR_SCANNER_OPTS="-Xmx4096m -XX:MaxPermSize=512m"

# For Maven projects
mvn sonar:sonar -Dsonar.java.jvmArgs="-Xmx2048m"

# For Gradle projects
./gradlew sonarqube -Dorg.gradle.jvmargs="-Xmx2048m"

# Docker configuration with increased memory
docker run --rm \
  -v $(pwd):/usr/src \
  -e SONAR_HOST_URL="http://sonarqube:9000" \
  -e SONAR_LOGIN="your-token" \
  --memory=4g \
  sonarsource/sonar-scanner-cli
```

#### Issue: SonarQube False Positives for EdTech Patterns
**Symptoms**:
- Security hotspots on legitimate educational data handling
- False positives on student ID patterns
- Incorrect vulnerability classification

**Solution**:
```properties
# sonar-project.properties - Custom rules for EdTech
sonar.projectKey=edtech-platform
sonar.sources=src
sonar.exclusions=**/node_modules/**,**/test/**,**/spec/**

# Exclude test files and mock data
sonar.coverage.exclusions=**/*test*/**,**/*mock*/**,**/*fixture*/**

# Custom quality profile for EdTech
sonar.profile=EdTech-Security-Profile

# Suppress false positives for student data patterns
sonar.issue.ignore.multicriteria=e1,e2,e3

# Suppress student ID pattern false positives
sonar.issue.ignore.multicriteria.e1.ruleKey=javascript:S4784
sonar.issue.ignore.multicriteria.e1.resourceKey=**/student-service.js

# Suppress educational content sanitization warnings
sonar.issue.ignore.multicriteria.e2.ruleKey=javascript:S5122
sonar.issue.ignore.multicriteria.e2.resourceKey=**/content-sanitizer.js

# Suppress FERPA compliance logging patterns
sonar.issue.ignore.multicriteria.e3.ruleKey=javascript:S2068
sonar.issue.ignore.multicriteria.e3.resourceKey=**/audit-logger.js
```

### Dependency Scanning Issues

#### Issue: High Volume of Dependency Vulnerabilities
**Symptoms**:
- Hundreds of vulnerability alerts
- Unable to prioritize critical issues
- Overwhelming security reports

**Solution**:
```yaml
# .github/dependabot.yml - Automated dependency management
version: 2
updates:
  - package-ecosystem: "npm"
    directory: "/"
    schedule:
      interval: "weekly"
    reviewers:
      - "security-team"
    assignees:
      - "lead-developer"
    commit-message:
      prefix: "security"
      include: "scope"
    # Only create PRs for security updates
    open-pull-requests-limit: 5
    # Group dependency updates
    groups:
      security-updates:
        patterns:
          - "*"
        update-types:
          - "security-update"
```

**Vulnerability Triage Script**:
```python
# vulnerability_triage.py - Automated vulnerability prioritization
import json
import requests
from typing import List, Dict

class VulnerabilityTriager:
    def __init__(self):
        self.edtech_critical_packages = [
            'express', 'mongoose', 'jsonwebtoken', 'bcrypt',
            'passport', 'multer', 'helmet', 'cors'
        ]
        
        self.ferpa_sensitive_packages = [
            'crypto', 'node-forge', 'sqlite3', 'mysql2',
            'pg', 'redis', 'aws-sdk'
        ]
    
    def prioritize_vulnerabilities(self, vulnerabilities: List[Dict]) -> List[Dict]:
        """Prioritize vulnerabilities based on EdTech context"""
        prioritized = []
        
        for vuln in vulnerabilities:
            priority_score = self.calculate_priority_score(vuln)
            vuln['priority_score'] = priority_score
            vuln['edtech_context'] = self.get_edtech_context(vuln)
            prioritized.append(vuln)
        
        # Sort by priority score (highest first)
        return sorted(prioritized, key=lambda x: x['priority_score'], reverse=True)
    
    def calculate_priority_score(self, vuln: Dict) -> int:
        """Calculate priority score for vulnerability"""
        score = 0
        
        # Base score from CVSS
        cvss_score = vuln.get('cvss_score', 0)
        score += cvss_score * 10
        
        # EdTech-specific adjustments
        package_name = vuln.get('package_name', '')
        
        # Critical EdTech packages get higher priority
        if package_name in self.edtech_critical_packages:
            score += 30
        
        # FERPA-sensitive packages get higher priority
        if package_name in self.ferpa_sensitive_packages:
            score += 25
        
        # Adjust based on vulnerability type
        vuln_type = vuln.get('vulnerability_type', '').lower()
        if 'remote code execution' in vuln_type:
            score += 40
        elif 'sql injection' in vuln_type:
            score += 35
        elif 'cross-site scripting' in vuln_type:
            score += 30
        elif 'authentication bypass' in vuln_type:
            score += 35
        elif 'data exposure' in vuln_type:
            score += 30
        
        # Adjust based on exploitability
        if vuln.get('exploitability', '').lower() == 'high':
            score += 20
        elif vuln.get('exploitability', '').lower() == 'functional':
            score += 15
        
        return min(score, 100)  # Cap at 100
    
    def get_edtech_context(self, vuln: Dict) -> str:
        """Get EdTech-specific context for vulnerability"""
        package_name = vuln.get('package_name', '')
        
        if package_name in self.edtech_critical_packages:
            return f"Critical EdTech dependency: {package_name} handles core platform functionality"
        elif package_name in self.ferpa_sensitive_packages:
            return f"FERPA-sensitive package: {package_name} may handle student data"
        else:
            return "Standard dependency"
    
    def generate_remediation_plan(self, vulnerabilities: List[Dict]) -> Dict:
        """Generate remediation plan based on priorities"""
        plan = {
            'immediate_action': [],
            'short_term': [],
            'long_term': [],
            'monitoring': []
        }
        
        for vuln in vulnerabilities:
            priority_score = vuln.get('priority_score', 0)
            
            if priority_score >= 80:
                plan['immediate_action'].append({
                    'package': vuln['package_name'],
                    'vulnerability': vuln['vulnerability_type'],
                    'action': 'Update immediately or find alternative',
                    'timeline': '24 hours'
                })
            elif priority_score >= 60:
                plan['short_term'].append({
                    'package': vuln['package_name'],
                    'vulnerability': vuln['vulnerability_type'],
                    'action': 'Schedule update in next sprint',
                    'timeline': '1-2 weeks'
                })
            elif priority_score >= 40:
                plan['long_term'].append({
                    'package': vuln['package_name'],
                    'vulnerability': vuln['vulnerability_type'],
                    'action': 'Plan update in upcoming release',
                    'timeline': '1 month'
                })
            else:
                plan['monitoring'].append({
                    'package': vuln['package_name'],
                    'vulnerability': vuln['vulnerability_type'],
                    'action': 'Monitor for exploit development',
                    'timeline': 'Ongoing'
                })
        
        return plan

# Usage example
def process_vulnerability_report(report_file: str):
    with open(report_file, 'r') as f:
        vulnerabilities = json.load(f)
    
    triager = VulnerabilityTriager()
    prioritized_vulns = triager.prioritize_vulnerabilities(vulnerabilities)
    remediation_plan = triager.generate_remediation_plan(prioritized_vulns)
    
    # Save prioritized report
    with open('prioritized_vulnerabilities.json', 'w') as f:
        json.dump(prioritized_vulns, f, indent=2)
    
    with open('remediation_plan.json', 'w') as f:
        json.dump(remediation_plan, f, indent=2)
    
    print(f"Processed {len(vulnerabilities)} vulnerabilities")
    print(f"Immediate action required: {len(remediation_plan['immediate_action'])}")
    print(f"Short-term planning: {len(remediation_plan['short_term'])}")
```

## 🚨 CI/CD Pipeline Issues

### Issue: Security Pipeline Timeouts
**Symptoms**:
- Pipeline exceeds maximum execution time
- Scans don't complete in CI environment
- Resource limitations in cloud runners

**Solution**:
```yaml
# Optimized pipeline with timeouts and parallel execution
name: Optimized Security Pipeline

jobs:
  security-scan:
    runs-on: ubuntu-latest
    timeout-minutes: 45  # Set reasonable timeout
    strategy:
      matrix:
        test-category: [secrets, dependencies, sast, dast-quick]
      fail-fast: false  # Continue other tests if one fails
    
    steps:
      - name: Checkout with depth limit
        uses: actions/checkout@v4
        with:
          fetch-depth: 10  # Limit git history for faster checkout
      
      - name: Cache dependencies
        uses: actions/cache@v3
        with:
          path: |
            ~/.npm
            ~/.cache
            node_modules
          key: ${{ runner.os }}-deps-${{ hashFiles('**/package-lock.json') }}
      
      - name: Run security scan with timeout
        timeout-minutes: 30
        run: |
          case "${{ matrix.test-category }}" in
            secrets)
              gitleaks detect --source . --report-format json --report-path gitleaks-report.json
              ;;
            dependencies)
              npm audit --audit-level high --production
              ;;
            sast)
              semgrep --config=p/security-audit --json --output semgrep-report.json src/
              ;;
            dast-quick)
              docker run --rm -v $(pwd):/zap/wrk/:rw owasp/zap2docker-stable \
                zap-baseline.py -t ${{ env.TARGET_URL }} -d -J zap-report.json \
                -c .zap/baseline-rules.conf --hook=/zap/wrk/zap-hooks.py
              ;;
          esac
```

### Issue: Security Scan Results Not Properly Reported
**Symptoms**:
- Scan results don't appear in GitHub Security tab
- Missing vulnerability notifications
- Inconsistent reporting formats

**Solution**:
```yaml
# Proper security reporting configuration
- name: Upload SARIF results
  uses: github/codeql-action/upload-sarif@v3
  if: always()
  with:
    sarif_file: |
      semgrep-report.sarif
      trivy-results.sarif
      codeql-results.sarif

- name: Create security summary
  if: always()
  run: |
    echo "## 🔒 Security Scan Summary" >> $GITHUB_STEP_SUMMARY
    echo "| Tool | Status | Critical | High | Medium |" >> $GITHUB_STEP_SUMMARY
    echo "|------|--------|----------|------|--------|" >> $GITHUB_STEP_SUMMARY
    
    # Process each scan result
    if [ -f "semgrep-report.json" ]; then
      CRITICAL=$(jq '[.results[] | select(.extra.severity=="ERROR")] | length' semgrep-report.json)
      HIGH=$(jq '[.results[] | select(.extra.severity=="WARNING")] | length' semgrep-report.json)
      MEDIUM=$(jq '[.results[] | select(.extra.severity=="INFO")] | length' semgrep-report.json)
      echo "| Semgrep | ✅ | $CRITICAL | $HIGH | $MEDIUM |" >> $GITHUB_STEP_SUMMARY
    fi
    
    if [ -f "trivy-results.json" ]; then
      CRITICAL=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity=="CRITICAL")] | length' trivy-results.json)
      HIGH=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity=="HIGH")] | length' trivy-results.json)
      MEDIUM=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity=="MEDIUM")] | length' trivy-results.json)
      echo "| Trivy | ✅ | $CRITICAL | $HIGH | $MEDIUM |" >> $GITHUB_STEP_SUMMARY
    fi

- name: Comment on PR
  if: github.event_name == 'pull_request'
  uses: actions/github-script@v7
  with:
    script: |
      const fs = require('fs');
      let comment = '## 🔒 Security Testing Results\n\n';
      
      // Read and process security results
      const scanResults = [];
      
      if (fs.existsSync('semgrep-report.json')) {
        const report = JSON.parse(fs.readFileSync('semgrep-report.json'));
        const critical = report.results.filter(r => r.extra.severity === 'ERROR').length;
        const high = report.results.filter(r => r.extra.severity === 'WARNING').length;
        scanResults.push({ tool: 'Semgrep (SAST)', critical, high });
      }
      
      if (scanResults.length > 0) {
        comment += '| Tool | Critical Issues | High Issues | Status |\n';
        comment += '|------|----------------|-------------|--------|\n';
        
        scanResults.forEach(result => {
          const status = result.critical > 0 ? '❌ FAIL' : result.high > 0 ? '⚠️ WARN' : '✅ PASS';
          comment += `| ${result.tool} | ${result.critical} | ${result.high} | ${status} |\n`;
        });
        
        if (scanResults.some(r => r.critical > 0)) {
          comment += '\n⚠️ **Critical security issues detected. Please review and fix before merging.**\n';
        }
      }
      
      github.rest.issues.createComment({
        issue_number: context.issue.number,
        owner: context.repo.owner,
        repo: context.repo.repo,
        body: comment
      });
```

## 🔐 Compliance and Regulatory Issues

### Issue: FERPA Compliance Validation Failures
**Symptoms**:
- Student data exposure in logs
- Inadequate access controls
- Missing audit trails

**Solution**:
```python
# ferpa_compliance_validator.py
import re
import json
from typing import List, Dict, Any

class FERPAComplianceValidator:
    def __init__(self):
        self.pii_patterns = [
            r'\b\d{3}-\d{2}-\d{4}\b',  # SSN
            r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b',  # Email
            r'\b\d{3}-\d{3}-\d{4}\b',  # Phone
            r'\bstudent[_-]?id[:\s]*[A-Za-z0-9]+\b',  # Student ID
        ]
        
        self.sensitive_fields = [
            'social_security_number', 'ssn', 'birth_date', 'home_address',
            'parent_income', 'disciplinary_record', 'health_record',
            'gpa', 'grades', 'test_scores'
        ]
    
    def validate_log_files(self, log_directory: str) -> Dict[str, List[str]]:
        """Validate log files for PII exposure"""
        violations = {'files': [], 'patterns': []}
        
        import os
        for root, dirs, files in os.walk(log_directory):
            for file in files:
                if file.endswith(('.log', '.txt')):
                    file_path = os.path.join(root, file)
                    with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                        content = f.read()
                        
                        for pattern in self.pii_patterns:
                            matches = re.findall(pattern, content, re.IGNORECASE)
                            if matches:
                                violations['files'].append(file_path)
                                violations['patterns'].extend(matches)
        
        return violations
    
    def validate_api_responses(self, api_responses: List[Dict]) -> List[Dict]:
        """Validate API responses for inappropriate data exposure"""
        violations = []
        
        for response in api_responses:
            endpoint = response.get('endpoint', 'unknown')
            data = response.get('data', {})
            
            # Check for sensitive fields in response
            exposed_fields = []
            for field in self.sensitive_fields:
                if self._contains_field(data, field):
                    exposed_fields.append(field)
            
            if exposed_fields:
                violations.append({
                    'endpoint': endpoint,
                    'violation_type': 'sensitive_data_exposure',
                    'exposed_fields': exposed_fields,
                    'severity': 'critical',
                    'recommendation': 'Remove sensitive fields or implement proper authorization'
                })
        
        return violations
    
    def validate_access_controls(self, access_logs: List[Dict]) -> List[Dict]:
        """Validate access control implementation"""
        violations = []
        
        # Group access logs by user
        user_access = {}
        for log in access_logs:
            user_id = log.get('user_id')
            if user_id not in user_access:
                user_access[user_id] = []
            user_access[user_id].append(log)
        
        # Check for suspicious access patterns
        for user_id, logs in user_access.items():
            # Check if student is accessing other students' data
            if self._is_student(user_id):
                accessed_students = set()
                for log in logs:
                    if 'student_id' in log and log['student_id'] != user_id:
                        accessed_students.add(log['student_id'])
                
                if accessed_students:
                    violations.append({
                        'user_id': user_id,
                        'violation_type': 'unauthorized_student_data_access',
                        'accessed_students': list(accessed_students),
                        'severity': 'critical',
                        'recommendation': 'Implement proper access controls for student data'
                    })
        
        return violations
    
    def generate_compliance_report(self, violations: Dict[str, Any]) -> str:
        """Generate FERPA compliance report"""
        report = {
            'compliance_status': 'NON_COMPLIANT' if violations else 'COMPLIANT',
            'total_violations': sum(len(v) if isinstance(v, list) else 1 for v in violations.values()),
            'critical_violations': len([v for v in violations.get('api_violations', []) if v.get('severity') == 'critical']),
            'violations_by_category': violations,
            'remediation_steps': self._generate_remediation_steps(violations),
            'compliance_checklist': self._generate_compliance_checklist()
        }
        
        return json.dumps(report, indent=2)
    
    def _contains_field(self, data: Any, field: str) -> bool:
        """Check if field exists in nested data structure"""
        if isinstance(data, dict):
            if field.lower() in [k.lower() for k in data.keys()]:
                return True
            return any(self._contains_field(v, field) for v in data.values())
        elif isinstance(data, list):
            return any(self._contains_field(item, field) for item in data)
        return False
    
    def _is_student(self, user_id: str) -> bool:
        """Check if user is a student (simplified)"""
        # This would check user role in your system
        return user_id.startswith('STU')
    
    def _generate_remediation_steps(self, violations: Dict) -> List[str]:
        """Generate remediation steps based on violations"""
        steps = []
        
        if violations.get('log_violations'):
            steps.append("Remove PII from log files and implement log sanitization")
        
        if violations.get('api_violations'):
            steps.append("Implement data minimization in API responses")
            steps.append("Add proper authorization checks for sensitive endpoints")
        
        if violations.get('access_violations'):
            steps.append("Implement role-based access controls")
            steps.append("Add audit logging for all student data access")
        
        return steps
    
    def _generate_compliance_checklist(self) -> List[Dict]:
        """Generate FERPA compliance checklist"""
        return [
            {'requirement': 'Student consent for disclosure', 'status': 'pending'},
            {'requirement': 'Directory information designation', 'status': 'pending'},
            {'requirement': 'Access controls for educational records', 'status': 'pending'},
            {'requirement': 'Audit logging of record access', 'status': 'pending'},
            {'requirement': 'Data retention policies', 'status': 'pending'},
            {'requirement': 'Breach notification procedures', 'status': 'pending'}
        ]

# Usage in CI/CD pipeline
def run_ferpa_compliance_check():
    validator = FERPAComplianceValidator()
    
    violations = {}
    
    # Check log files
    log_violations = validator.validate_log_files('./logs')
    if log_violations['files']:
        violations['log_violations'] = log_violations
    
    # Check API responses (mock data for example)
    api_responses = [
        {
            'endpoint': '/api/students',
            'data': {'students': [{'name': 'John Doe', 'ssn': '123-45-6789', 'gpa': 3.5}]}
        }
    ]
    api_violations = validator.validate_api_responses(api_responses)
    if api_violations:
        violations['api_violations'] = api_violations
    
    # Generate compliance report
    report = validator.generate_compliance_report(violations)
    
    with open('ferpa-compliance-report.json', 'w') as f:
        f.write(report)
    
    # Return exit code based on compliance status
    return 1 if violations else 0
```

## 📊 Performance and Resource Issues

### Issue: Security Scans Consuming Too Many Resources
**Symptoms**:
- High CPU/memory usage during scans
- System becomes unresponsive
- Other processes affected

**Solution**:
```bash
#!/bin/bash
# resource_aware_scanning.sh

# Resource monitoring function
check_system_resources() {
    local cpu_threshold=70
    local memory_threshold=80
    
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//')
    local memory_usage=$(free | grep Mem | awk '{printf("%.1f"), $3/$2 * 100.0}')
    
    if (( $(echo "$cpu_usage > $cpu_threshold" | bc -l) )) || \
       (( $(echo "$memory_usage > $memory_threshold" | bc -l) )); then
        echo "System resources too high (CPU: $cpu_usage%, Memory: $memory_usage%)"
        return 1
    fi
    
    return 0
}

# Adaptive scanning based on resources
run_adaptive_scan() {
    local target_url=$1
    local scan_type=$2
    
    if ! check_system_resources; then
        echo "Reducing scan intensity due to high resource usage"
        export SCAN_INTENSITY="low"
    else
        export SCAN_INTENSITY="normal"
    fi
    
    case $scan_type in
        "zap")
            if [ "$SCAN_INTENSITY" = "low" ]; then
                # Low-intensity ZAP scan
                docker run --rm --memory=1g --cpus=1 \
                    -v $(pwd):/zap/wrk/:rw owasp/zap2docker-stable \
                    zap-baseline.py -t $target_url -d \
                    -c .zap/low-intensity.conf
            else
                # Normal ZAP scan
                docker run --rm --memory=2g --cpus=2 \
                    -v $(pwd):/zap/wrk/:rw owasp/zap2docker-stable \
                    zap-full-scan.py -t $target_url -d
            fi
            ;;
        "nuclei")
            if [ "$SCAN_INTENSITY" = "low" ]; then
                nuclei -u $target_url -c 5 -timeout 30s -severity critical,high
            else
                nuclei -u $target_url -c 15 -timeout 60s -severity critical,high,medium
            fi
            ;;
    esac
}

# Scan queue management
manage_scan_queue() {
    local queue_file="/tmp/scan_queue"
    local max_concurrent=2
    local current_scans=0
    
    while IFS= read -r scan_job; do
        # Wait if too many concurrent scans
        while [ $current_scans -ge $max_concurrent ]; do
            sleep 30
            current_scans=$(pgrep -c "zap\|nuclei\|trivy" || echo 0)
        done
        
        # Wait for resources to be available
        while ! check_system_resources; do
            echo "Waiting for system resources to become available..."
            sleep 60
        done
        
        # Run scan in background
        IFS='|' read -r scan_type target_url <<< "$scan_job"
        run_adaptive_scan "$target_url" "$scan_type" &
        
        ((current_scans++))
        sleep 10  # Brief delay between scan starts
        
    done < "$queue_file"
}
```

## 🔍 Debugging and Diagnostics

### Security Scan Debug Mode
```python
# security_debug.py - Enhanced debugging for security scans
import logging
import subprocess
import json
import time
from pathlib import Path

class SecurityScanDebugger:
    def __init__(self, debug_level='INFO'):
        self.setup_logging(debug_level)
        self.debug_dir = Path('./debug')
        self.debug_dir.mkdir(exist_ok=True)
    
    def setup_logging(self, level):
        logging.basicConfig(
            level=getattr(logging, level),
            format='%(asctime)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler('security-debug.log'),
                logging.StreamHandler()
            ]
        )
        self.logger = logging.getLogger(__name__)
    
    def debug_zap_scan(self, target_url: str):
        """Debug ZAP scanning issues"""
        self.logger.info(f"Starting ZAP debug for {target_url}")
        
        # Test connectivity
        if not self._test_connectivity(target_url):
            self.logger.error(f"Cannot connect to {target_url}")
            return False
        
        # Check ZAP daemon
        if not self._check_zap_daemon():
            self.logger.error("ZAP daemon not accessible")
            return False
        
        # Test authentication
        auth_result = self._test_zap_authentication(target_url)
        if not auth_result:
            self.logger.warning("Authentication test failed")
        
        # Run debug scan
        self._run_debug_zap_scan(target_url)
        
        return True
    
    def _test_connectivity(self, url: str) -> bool:
        """Test basic connectivity to target"""
        try:
            import requests
            response = requests.get(url, timeout=10)
            self.logger.info(f"Connectivity test: {response.status_code}")
            return response.status_code < 500
        except Exception as e:
            self.logger.error(f"Connectivity test failed: {e}")
            return False
    
    def _check_zap_daemon(self) -> bool:
        """Check if ZAP daemon is running"""
        try:
            import requests
            response = requests.get('http://localhost:8080/JSON/core/view/version/')
            self.logger.info(f"ZAP daemon version: {response.json()}")
            return True
        except Exception as e:
            self.logger.error(f"ZAP daemon check failed: {e}")
            return False
    
    def _test_zap_authentication(self, target_url: str) -> bool:
        """Test ZAP authentication configuration"""
        try:
            from zapv2 import ZAPv2
            zap = ZAPv2(proxies={'http': 'http://127.0.0.1:8080'})
            
            # Check authentication configuration
            contexts = zap.context.context_list
            self.logger.info(f"ZAP contexts: {contexts}")
            
            if contexts:
                context_id = contexts[0]
                auth_method = zap.authentication.get_authentication_method(context_id)
                self.logger.info(f"Auth method: {auth_method}")
                
                users = zap.users.users_list(context_id)
                self.logger.info(f"Configured users: {len(users)}")
            
            return True
        except Exception as e:
            self.logger.error(f"ZAP authentication test failed: {e}")
            return False
    
    def _run_debug_zap_scan(self, target_url: str):
        """Run ZAP scan with detailed debugging"""
        debug_config = {
            'target': target_url,
            'spider_options': {
                'maxDepth': 2,
                'maxChildren': 10,
                'maxDuration': 5
            },
            'scan_options': {
                'threadPerHost': 2,
                'maxRuleDurationInMins': 2
            }
        }
        
        # Save debug configuration
        with open(self.debug_dir / 'zap-debug-config.json', 'w') as f:
            json.dump(debug_config, f, indent=2)
        
        self.logger.info("Starting debug ZAP scan with reduced settings")
        
        try:
            from zapv2 import ZAPv2
            zap = ZAPv2(proxies={'http': 'http://127.0.0.1:8080'})
            
            # Configure spider
            zap.spider.set_option_max_depth(debug_config['spider_options']['maxDepth'])
            zap.spider.set_option_max_children(debug_config['spider_options']['maxChildren'])
            
            # Start spider
            spider_id = zap.spider.scan(target_url)
            self.logger.info(f"Spider started with ID: {spider_id}")
            
            # Monitor spider progress
            while int(zap.spider.status(spider_id)) < 100:
                progress = zap.spider.status(spider_id)
                self.logger.info(f"Spider progress: {progress}%")
                time.sleep(5)
            
            # Get spider results
            spider_results = zap.spider.results(spider_id)
            self.logger.info(f"Spider found {len(spider_results)} URLs")
            
            # Save spider results for debugging
            with open(self.debug_dir / 'spider-results.json', 'w') as f:
                json.dump(spider_results, f, indent=2)
            
            # Start active scan on limited scope
            if spider_results:
                sample_urls = spider_results[:5]  # Limit to first 5 URLs for debugging
                for url in sample_urls:
                    scan_id = zap.ascan.scan(url)
                    self.logger.info(f"Active scan started for {url} with ID: {scan_id}")
                    
                    # Wait a bit then check results
                    time.sleep(30)
                    alerts = zap.core.alerts(baseurl=url)
                    self.logger.info(f"Found {len(alerts)} alerts for {url}")
            
        except Exception as e:
            self.logger.error(f"Debug ZAP scan failed: {e}")
    
    def generate_debug_report(self):
        """Generate comprehensive debug report"""
        report = {
            'timestamp': time.strftime('%Y-%m-%d %H:%M:%S'),
            'system_info': self._get_system_info(),
            'network_info': self._get_network_info(),
            'tool_versions': self._get_tool_versions(),
            'debug_files': list(self.debug_dir.glob('*'))
        }
        
        with open(self.debug_dir / 'debug-report.json', 'w') as f:
            json.dump(report, f, indent=2, default=str)
        
        self.logger.info("Debug report generated")
        return report
    
    def _get_system_info(self):
        """Get system information"""
        import platform
        import psutil
        
        return {
            'platform': platform.platform(),
            'python_version': platform.python_version(),
            'cpu_count': psutil.cpu_count(),
            'memory_total': psutil.virtual_memory().total,
            'disk_usage': psutil.disk_usage('/').percent
        }
    
    def _get_network_info(self):
        """Get network configuration"""
        try:
            result = subprocess.run(['curl', '-s', 'httpbin.org/ip'], 
                                  capture_output=True, text=True, timeout=10)
            return {'external_ip': result.stdout.strip()}
        except:
            return {'external_ip': 'unknown'}
    
    def _get_tool_versions(self):
        """Get security tool versions"""
        versions = {}
        
        tools = {
            'docker': ['docker', '--version'],
            'zap': ['docker', 'run', '--rm', 'owasp/zap2docker-stable', 'zap.sh', '-version'],
            'nuclei': ['nuclei', '-version'],
            'trivy': ['trivy', '--version']
        }
        
        for tool, cmd in tools.items():
            try:
                result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
                versions[tool] = result.stdout.strip()
            except:
                versions[tool] = 'not available'
        
        return versions

# Usage
if __name__ == "__main__":
    debugger = SecurityScanDebugger(debug_level='DEBUG')
    debugger.debug_zap_scan('https://staging.edtech-platform.com')
    debugger.generate_debug_report()
```

---

**Navigation**: [Previous: Automated Testing Strategies](./automated-testing-strategies.md) | **Next**: [README](./README.md)

---

## 📖 References and Citations

1. [OWASP ZAP User Guide](https://www.zaproxy.org/docs/)
2. [SonarQube Troubleshooting Guide](https://docs.sonarqube.org/latest/setup/troubleshooting/)
3. [GitHub Actions Troubleshooting](https://docs.github.com/en/actions/monitoring-and-troubleshooting-workflows)
4. [Docker Security Best Practices](https://docs.docker.com/develop/security-best-practices/)
5. [CI/CD Security Best Practices](https://owasp.org/www-project-devsecops-guideline/)
6. [FERPA Technical Safeguards Guide](https://studentprivacy.ed.gov/resources/ferpa-and-disclosure-student-information-related-emergencies-and-disasters)
7. [Nuclei Template Guide](https://nuclei.projectdiscovery.io/templating-guide/)
8. [Trivy Troubleshooting](https://aquasecurity.github.io/trivy/latest/docs/troubleshooting/)
9. [Semgrep Rule Writing Guide](https://semgrep.dev/docs/writing-rules/overview/)
10. [GitLeaks Configuration](https://github.com/zricethezav/gitleaks#configuration)

*This troubleshooting guide provides practical solutions for common security testing issues encountered in EdTech platforms with specific focus on FERPA compliance and international regulatory requirements.*