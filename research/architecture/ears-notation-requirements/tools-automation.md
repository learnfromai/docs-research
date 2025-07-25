# Tools and Automation for EARS Notation

## Overview

This guide covers the tools, automation strategies, and technical implementations that support EARS (Easy Approach to Requirements Syntax) notation in software development workflows. From validation scripts to integrated development environments, these tools enhance the efficiency and quality of EARS requirements implementation.

## Validation and Quality Assurance Tools

### EARS Syntax Validator

#### Command Line Validator

```javascript
#!/usr/bin/env node
// ears-validator.js

const fs = require('fs');
const path = require('path');
const yaml = require('js-yaml');

class EarsValidator {
  constructor() {
    this.templates = {
      ubiquitous: {
        pattern: /^The system shall .+$/i,
        description: 'Universal requirements that always apply'
      },
      eventDriven: {
        pattern: /^WHEN .+ the system shall .+$/i,
        description: 'System responses to specific events'
      },
      unwantedBehavior: {
        pattern: /^IF .+ THEN the system shall .+$/i,
        description: 'Error conditions and exceptional handling'
      },
      stateDriven: {
        pattern: /^WHILE .+ the system shall .+$/i,
        description: 'Continuous behaviors during specific states'
      },
      optional: {
        pattern: /^WHERE .+ the system shall .+$/i,
        description: 'Conditional functionality based on configuration'
      },
      complex: {
        pattern: /^IF .+ THEN WHEN .+ the system shall .+$/i,
        description: 'Multi-condition requirements with cascading logic'
      }
    };

    this.qualityRules = [
      this.checkAmbiguousTerms,
      this.checkMeasurability,
      this.checkAtomicity,
      this.checkConsistency
    ];

    this.ambiguousTerms = [
      'appropriate', 'reasonable', 'adequate', 'suitable', 'proper',
      'correctly', 'efficiently', 'effectively', 'quickly', 'slowly',
      'often', 'sometimes', 'usually', 'generally', 'normally'
    ];
  }

  validateFile(filePath) {
    try {
      const content = fs.readFileSync(filePath, 'utf8');
      const requirements = this.parseRequirements(content, filePath);
      const results = requirements.map(req => this.validateRequirement(req));
      
      return {
        file: filePath,
        totalRequirements: requirements.length,
        results: results,
        summary: this.generateSummary(results)
      };
    } catch (error) {
      return {
        file: filePath,
        error: error.message
      };
    }
  }

  parseRequirements(content, filePath) {
    const ext = path.extname(filePath).toLowerCase();
    
    if (ext === '.yaml' || ext === '.yml') {
      return this.parseYamlRequirements(content);
    } else if (ext === '.md') {
      return this.parseMarkdownRequirements(content);
    } else {
      throw new Error(`Unsupported file format: ${ext}`);
    }
  }

  parseYamlRequirements(content) {
    const doc = yaml.safeLoad(content);
    const requirements = [];

    if (Array.isArray(doc)) {
      requirements.push(...doc);
    } else if (typeof doc === 'object') {
      // Handle different YAML structures
      Object.keys(doc).forEach(key => {
        if (doc[key].requirement || doc[key].ears) {
          requirements.push({ id: key, ...doc[key] });
        }
      });
    }

    return requirements;
  }

  parseMarkdownRequirements(content) {
    const requirements = [];
    const lines = content.split('\n');
    
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i].trim();
      
      // Look for EARS patterns in markdown
      if (this.isEarsRequirement(line)) {
        requirements.push({
          id: `MD-${i + 1}`,
          requirement: line,
          line: i + 1,
          type: 'markdown'
        });
      }
    }

    return requirements;
  }

  validateRequirement(req) {
    const issues = [];
    const requirement = req.requirement || req.ears?.response || '';
    
    // Template validation
    const templateMatch = this.validateTemplate(requirement);
    if (!templateMatch) {
      issues.push({
        type: 'error',
        code: 'INVALID_TEMPLATE',
        message: 'Requirement does not match any EARS template pattern',
        suggestion: 'Use one of the six EARS templates: ubiquitous, event-driven, unwanted behavior, state-driven, optional, or complex'
      });
    }

    // Quality rule validation
    this.qualityRules.forEach(rule => {
      const ruleIssues = rule.call(this, req, requirement);
      issues.push(...ruleIssues);
    });

    return {
      id: req.id,
      requirement: requirement,
      template: templateMatch?.name,
      isValid: issues.filter(i => i.type === 'error').length === 0,
      issues: issues,
      score: this.calculateQualityScore(issues)
    };
  }

  validateTemplate(text) {
    const cleanText = text.trim();
    
    for (const [name, template] of Object.entries(this.templates)) {
      if (template.pattern.test(cleanText)) {
        return { name, ...template };
      }
    }
    
    return null;
  }

  checkAmbiguousTerms(req, requirement) {
    const issues = [];
    const lowerReq = requirement.toLowerCase();
    
    this.ambiguousTerms.forEach(term => {
      if (lowerReq.includes(term)) {
        issues.push({
          type: 'warning',
          code: 'AMBIGUOUS_TERM',
          message: `Ambiguous term found: "${term}"`,
          suggestion: 'Replace with specific, measurable criteria'
        });
      }
    });

    return issues;
  }

  checkMeasurability(req, requirement) {
    const issues = [];
    const measurementPatterns = [
      /\d+\s*(second|minute|hour|day|week|month|year)s?/i,
      /\d+\s*(ms|millisecond)s?/i,
      /\d+\s*(kb|mb|gb|tb)/i,
      /\d+\s*(%|percent)/i,
      /within\s+\d+/i,
      /less\s+than\s+\d+/i,
      /greater\s+than\s+\d+/i,
      /exactly\s+\d+/i,
      /at\s+least\s+\d+/i,
      /no\s+more\s+than\s+\d+/i
    ];

    const hasMeasurement = measurementPatterns.some(pattern => 
      pattern.test(requirement)
    );

    // Check for performance, time, or quantity-related requirements
    const performanceIndicators = [
      'response', 'process', 'complete', 'execute', 'load', 'save',
      'validate', 'calculate', 'generate', 'update', 'retrieve'
    ];

    const hasPerformanceContext = performanceIndicators.some(indicator =>
      requirement.toLowerCase().includes(indicator)
    );

    if (hasPerformanceContext && !hasMeasurement) {
      issues.push({
        type: 'warning',
        code: 'UNMEASURABLE',
        message: 'Performance-related requirement lacks measurable criteria',
        suggestion: 'Add specific metrics (time, size, percentage, etc.)'
      });
    }

    return issues;
  }

  checkAtomicity(req, requirement) {
    const issues = [];
    const multipleActionIndicators = [
      ' and ', ' then ', ' also ', ' plus ', ' additionally ',
      ' furthermore ', ' moreover ', ' as well as '
    ];

    const hasMultipleActions = multipleActionIndicators.some(indicator =>
      requirement.toLowerCase().includes(indicator)
    );

    if (hasMultipleActions) {
      issues.push({
        type: 'info',
        code: 'NON_ATOMIC',
        message: 'Requirement may contain multiple actions',
        suggestion: 'Consider splitting into separate atomic requirements'
      });
    }

    return issues;
  }

  checkConsistency(req, requirement) {
    const issues = [];
    
    // Check for consistent subject usage
    if (!requirement.toLowerCase().includes('the system shall')) {
      issues.push({
        type: 'warning',
        code: 'INCONSISTENT_SUBJECT',
        message: 'Requirement should use "the system shall" as subject',
        suggestion: 'Use consistent subject format across all requirements'
      });
    }

    return issues;
  }

  calculateQualityScore(issues) {
    const weights = { error: -20, warning: -5, info: -1 };
    const deduction = issues.reduce((total, issue) => 
      total + (weights[issue.type] || 0), 0
    );
    return Math.max(0, 100 + deduction);
  }

  generateSummary(results) {
    const total = results.length;
    const valid = results.filter(r => r.isValid).length;
    const averageScore = results.reduce((sum, r) => sum + r.score, 0) / total;
    
    const templateDistribution = {};
    results.forEach(r => {
      if (r.template) {
        templateDistribution[r.template] = (templateDistribution[r.template] || 0) + 1;
      }
    });

    return {
      totalRequirements: total,
      validRequirements: valid,
      validationRate: (valid / total * 100).toFixed(1),
      averageQualityScore: averageScore.toFixed(1),
      templateDistribution: templateDistribution
    };
  }

  isEarsRequirement(text) {
    return Object.values(this.templates).some(template => 
      template.pattern.test(text.trim())
    );
  }
}

// CLI Interface
function main() {
  const args = process.argv.slice(2);
  
  if (args.length === 0) {
    console.log('Usage: ears-validator <file1> [file2] [file3] ...');
    console.log('Supported formats: .yaml, .yml, .md');
    process.exit(1);
  }

  const validator = new EarsValidator();
  const results = [];

  args.forEach(filePath => {
    if (!fs.existsSync(filePath)) {
      console.error(`Error: File not found: ${filePath}`);
      return;
    }

    const result = validator.validateFile(filePath);
    results.push(result);
    
    console.log(`\n📋 Validating: ${filePath}`);
    
    if (result.error) {
      console.log(`❌ Error: ${result.error}`);
      return;
    }

    const summary = result.summary;
    console.log(`📊 Results: ${summary.validRequirements}/${summary.totalRequirements} valid (${summary.validationRate}%)`);
    console.log(`🎯 Average Quality Score: ${summary.averageQualityScore}/100`);
    
    if (Object.keys(summary.templateDistribution).length > 0) {
      console.log('📈 Template Distribution:');
      Object.entries(summary.templateDistribution).forEach(([template, count]) => {
        console.log(`   ${template}: ${count}`);
      });
    }

    // Show detailed issues for invalid requirements
    const invalidRequirements = result.results.filter(r => !r.isValid);
    if (invalidRequirements.length > 0) {
      console.log('\n⚠️  Issues Found:');
      invalidRequirements.forEach(req => {
        console.log(`\n   ID: ${req.id}`);
        console.log(`   Requirement: "${req.requirement}"`);
        req.issues.filter(i => i.type === 'error').forEach(issue => {
          console.log(`   ❌ ${issue.message}`);
          if (issue.suggestion) {
            console.log(`      💡 ${issue.suggestion}`);
          }
        });
      });
    }
  });

  // Overall summary
  if (results.length > 1) {
    const overallValid = results.reduce((sum, r) => sum + (r.summary?.validRequirements || 0), 0);
    const overallTotal = results.reduce((sum, r) => sum + (r.summary?.totalRequirements || 0), 0);
    
    console.log(`\n📊 Overall Summary:`);
    console.log(`   Total Files: ${results.length}`);
    console.log(`   Total Requirements: ${overallTotal}`);
    console.log(`   Valid Requirements: ${overallValid}`);
    console.log(`   Overall Validation Rate: ${(overallValid / overallTotal * 100).toFixed(1)}%`);
  }
}

if (require.main === module) {
  main();
}

module.exports = { EarsValidator };
```

#### Usage Examples

```bash
# Validate single file
./ears-validator requirements.yaml

# Validate multiple files
./ears-validator requirements.yaml user-stories.md acceptance-criteria.yml

# Validate entire directory
find ./requirements -name "*.yaml" -o -name "*.md" | xargs ./ears-validator

# Generate JSON report
./ears-validator requirements.yaml --format json > validation-report.json
```

### JSON Schema Validation

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "EARS Requirement Schema",
  "type": "object",
  "properties": {
    "id": {
      "type": "string",
      "pattern": "^REQ-[A-Z0-9]+-[0-9]+$",
      "description": "Unique requirement identifier"
    },
    "title": {
      "type": "string",
      "minLength": 10,
      "maxLength": 100,
      "description": "Brief requirement description"
    },
    "category": {
      "type": "string",
      "enum": ["functional", "non-functional", "business-rule", "constraint"],
      "description": "Requirement category"
    },
    "priority": {
      "type": "string",
      "enum": ["critical", "high", "medium", "low"],
      "description": "Business priority level"
    },
    "ears": {
      "type": "object",
      "properties": {
        "template": {
          "type": "string",
          "enum": ["ubiquitous", "event-driven", "unwanted-behavior", "state-driven", "optional", "complex"],
          "description": "EARS template type"
        },
        "condition": {
          "type": "string",
          "description": "WHEN/IF/WHILE condition clause"
        },
        "trigger": {
          "type": "string",
          "description": "Specific event or state that initiates the requirement"
        },
        "response": {
          "type": "string",
          "description": "System behavior or action in response to the trigger"
        }
      },
      "required": ["template", "response"],
      "allOf": [
        {
          "if": {
            "properties": { "template": { "const": "event-driven" } }
          },
          "then": {
            "required": ["condition"],
            "properties": {
              "response": {
                "pattern": "^WHEN .+ the system shall .+$"
              }
            }
          }
        },
        {
          "if": {
            "properties": { "template": { "const": "unwanted-behavior" } }
          },
          "then": {
            "required": ["condition"],
            "properties": {
              "response": {
                "pattern": "^IF .+ THEN the system shall .+$"
              }
            }
          }
        },
        {
          "if": {
            "properties": { "template": { "const": "state-driven" } }
          },
          "then": {
            "required": ["condition"],
            "properties": {
              "response": {
                "pattern": "^WHILE .+ the system shall .+$"
              }
            }
          }
        },
        {
          "if": {
            "properties": { "template": { "const": "optional" } }
          },
          "then": {
            "required": ["condition"],
            "properties": {
              "response": {
                "pattern": "^WHERE .+ the system shall .+$"
              }
            }
          }
        },
        {
          "if": {
            "properties": { "template": { "const": "complex" } }
          },
          "then": {
            "required": ["condition", "trigger"],
            "properties": {
              "response": {
                "pattern": "^IF .+ THEN WHEN .+ the system shall .+$"
              }
            }
          }
        },
        {
          "if": {
            "properties": { "template": { "const": "ubiquitous" } }
          },
          "then": {
            "properties": {
              "response": {
                "pattern": "^The system shall .+$"
              }
            }
          }
        }
      ]
    },
    "acceptance_criteria": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "given": {
            "type": "string",
            "description": "Precondition for the test scenario"
          },
          "when": {
            "type": "string",
            "description": "Action or event that triggers the scenario"
          },
          "then": {
            "type": "string",
            "description": "Expected outcome or system response"
          }
        },
        "required": ["given", "when", "then"]
      },
      "minItems": 1,
      "description": "BDD-style acceptance criteria"
    },
    "metadata": {
      "type": "object",
      "properties": {
        "created_date": {
          "type": "string",
          "format": "date",
          "description": "Requirement creation date"
        },
        "author": {
          "type": "string",
          "description": "Requirement author"
        },
        "stakeholders": {
          "type": "array",
          "items": { "type": "string" },
          "description": "List of stakeholders"
        },
        "related_requirements": {
          "type": "array",
          "items": {
            "type": "string",
            "pattern": "^REQ-[A-Z0-9]+-[0-9]+$"
          },
          "description": "Related requirement IDs"
        },
        "user_story": {
          "type": "string",
          "description": "Associated user story ID or text"
        }
      },
      "required": ["created_date", "author"]
    }
  },
  "required": ["id", "title", "category", "priority", "ears", "acceptance_criteria", "metadata"]
}
```

## CI/CD Integration

### GitHub Actions Workflow

```yaml
# .github/workflows/ears-validation.yml
name: EARS Requirements Validation

on:
  pull_request:
    paths:
      - 'requirements/**/*.md'
      - 'requirements/**/*.yaml'
      - 'requirements/**/*.yml'
      - 'docs/requirements/**/*'
  push:
    branches: [ main, develop ]
    paths:
      - 'requirements/**/*.md'
      - 'requirements/**/*.yaml'
      - 'requirements/**/*.yml'

jobs:
  validate-ears:
    runs-on: ubuntu-latest
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v3
      
    - name: Setup Node.js
      uses: actions/setup-node@v3
      with:
        node-version: '18'
        
    - name: Install dependencies
      run: |
        npm install -g js-yaml
        chmod +x ./tools/ears-validator.js
        
    - name: Validate EARS syntax
      id: validation
      run: |
        echo "VALIDATION_RESULTS<<EOF" >> $GITHUB_OUTPUT
        find requirements -name "*.yaml" -o -name "*.yml" -o -name "*.md" | xargs ./tools/ears-validator.js || true
        echo "EOF" >> $GITHUB_OUTPUT
        
    - name: Generate quality report
      run: |
        ./tools/ears-validator.js requirements/*.yaml > ears-report.txt
        
    - name: Upload validation report
      uses: actions/upload-artifact@v3
      with:
        name: ears-validation-report
        path: ears-report.txt
        
    - name: Comment PR with results
      if: github.event_name == 'pull_request'
      uses: actions/github-script@v6
      with:
        script: |
          const fs = require('fs');
          try {
            const report = fs.readFileSync('ears-report.txt', 'utf8');
            const body = `## 📋 EARS Requirements Validation Report
            
            \`\`\`
            ${report}
            \`\`\`
            
            ### Quality Guidelines
            - ✅ **Good**: Quality score 80+
            - ⚠️ **Needs improvement**: Quality score 60-79
            - ❌ **Poor**: Quality score below 60
            
            Please review and address any issues before merging.`;
            
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: body
            });
          } catch (error) {
            console.log('Could not read report file:', error.message);
          }
          
    - name: Fail build on critical issues
      run: |
        if grep -q "❌" ears-report.txt; then
          echo "Critical EARS validation issues found. Please fix before merging."
          exit 1
        fi
```

### Jenkins Pipeline

```groovy
pipeline {
    agent any
    
    environment {
        EARS_VALIDATOR = './tools/ears-validator.js'
        REQUIREMENTS_DIR = 'requirements'
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        
        stage('Setup') {
            steps {
                sh 'npm install -g js-yaml'
                sh 'chmod +x ${EARS_VALIDATOR}'
            }
        }
        
        stage('EARS Validation') {
            steps {
                script {
                    def validationResult = sh(
                        script: "find ${REQUIREMENTS_DIR} -name '*.yaml' -o -name '*.yml' -o -name '*.md' | xargs ${EARS_VALIDATOR}",
                        returnStatus: true
                    )
                    
                    if (validationResult != 0) {
                        currentBuild.result = 'UNSTABLE'
                        error "EARS validation found issues"
                    }
                }
            }
            post {
                always {
                    archiveArtifacts artifacts: 'ears-validation-*.txt', allowEmptyArchive: true
                }
            }
        }
        
        stage('Quality Gate') {
            steps {
                script {
                    def qualityReport = readFile('ears-validation-report.txt')
                    def averageScore = (qualityReport =~ /Average Quality Score: (\d+\.\d+)/)[0][1] as Double
                    
                    if (averageScore < 75.0) {
                        currentBuild.result = 'FAILURE'
                        error "EARS quality score ${averageScore} below threshold of 75.0"
                    }
                    
                    echo "EARS quality score: ${averageScore}/100 - PASSED"
                }
            }
        }
    }
    
    post {
        failure {
            emailext(
                subject: "EARS Validation Failed: ${env.JOB_NAME} - ${env.BUILD_NUMBER}",
                body: "EARS requirements validation failed. Please check the build logs and fix the issues.",
                to: "${env.CHANGE_AUTHOR_EMAIL}"
            )
        }
    }
}
```

## IDE Integration

### VS Code Extension

```json
{
  "name": "ears-notation",
  "displayName": "EARS Notation Support",
  "description": "Support for Easy Approach to Requirements Syntax",
  "version": "1.0.0",
  "engines": {
    "vscode": "^1.60.0"
  },
  "categories": ["Other"],
  "main": "./out/extension.js",
  "contributes": {
    "languages": [
      {
        "id": "ears",
        "aliases": ["EARS", "ears"],
        "extensions": [".ears"],
        "configuration": "./language-configuration.json"
      }
    ],
    "grammars": [
      {
        "language": "ears",
        "scopeName": "text.ears",
        "path": "./syntaxes/ears.tmLanguage.json"
      }
    ],
    "snippets": [
      {
        "language": "ears",
        "path": "./snippets/ears-snippets.json"
      },
      {
        "language": "yaml",
        "path": "./snippets/ears-yaml-snippets.json"
      },
      {
        "language": "markdown",
        "path": "./snippets/ears-markdown-snippets.json"
      }
    ],
    "commands": [
      {
        "command": "ears.validateRequirement",
        "title": "Validate EARS Requirement"
      },
      {
        "command": "ears.generateAcceptanceCriteria",
        "title": "Generate Acceptance Criteria from EARS"
      },
      {
        "command": "ears.insertTemplate",
        "title": "Insert EARS Template"
      }
    ],
    "menus": {
      "editor/context": [
        {
          "when": "editorTextFocus",
          "command": "ears.validateRequirement",
          "group": "ears"
        }
      ]
    },
    "configuration": {
      "title": "EARS Notation",
      "properties": {
        "ears.validation.enabled": {
          "type": "boolean",
          "default": true,
          "description": "Enable EARS syntax validation"
        },
        "ears.validation.strictMode": {
          "type": "boolean",
          "default": false,
          "description": "Enable strict EARS validation mode"
        },
        "ears.templates.autoComplete": {
          "type": "boolean",
          "default": true,
          "description": "Enable EARS template auto-completion"
        }
      }
    }
  }
}
```

#### EARS Snippets for VS Code

```json
{
  "EARS Event-driven Requirement": {
    "prefix": "ears-when",
    "body": [
      "WHEN ${1:trigger condition} the system shall ${2:response action} ${3:within timeframe}.",
      "",
      "Acceptance Criteria:",
      "- Given: ${4:precondition}",
      "- When: ${5:action}",
      "- Then: ${6:expected outcome}"
    ],
    "description": "Event-driven EARS requirement template"
  },
  
  "EARS Unwanted Behavior Requirement": {
    "prefix": "ears-if",
    "body": [
      "IF ${1:error condition} THEN the system shall ${2:error response} ${3:and notification}.",
      "",
      "Acceptance Criteria:",
      "- Given: ${4:error condition exists}",
      "- When: ${5:error trigger}",
      "- Then: ${6:error handling behavior}"
    ],
    "description": "Unwanted behavior EARS requirement template"
  },
  
  "EARS State-driven Requirement": {
    "prefix": "ears-while",
    "body": [
      "WHILE ${1:system state} the system shall ${2:continuous behavior} ${3:with frequency}.",
      "",
      "Acceptance Criteria:",
      "- Given: ${4:system is in specified state}",
      "- When: ${5:state condition exists}",
      "- Then: ${6:continuous behavior is maintained}"
    ],
    "description": "State-driven EARS requirement template"
  },
  
  "EARS Optional Requirement": {
    "prefix": "ears-where",
    "body": [
      "WHERE ${1:feature/configuration} is available, the system shall ${2:conditional behavior}.",
      "",
      "Acceptance Criteria:",
      "- Given: ${3:feature is enabled/available}",
      "- When: ${4:activation condition}",
      "- Then: ${5:conditional functionality works}"
    ],
    "description": "Optional feature EARS requirement template"
  },
  
  "EARS Complex Requirement": {
    "prefix": "ears-complex",
    "body": [
      "IF ${1:condition} THEN WHEN ${2:trigger} the system shall ${3:response} ${4:additional actions}.",
      "",
      "Acceptance Criteria:",
      "- Given: ${5:complex precondition}",
      "- When: ${6:cascading trigger}",
      "- Then: ${7:multi-step response}"
    ],
    "description": "Complex multi-condition EARS requirement template"
  },
  
  "EARS Ubiquitous Requirement": {
    "prefix": "ears-shall",
    "body": [
      "The system shall ${1:system behavior/constraint} ${2:with measurable criteria}.",
      "",
      "Acceptance Criteria:",
      "- Given: ${3:system operational state}",
      "- When: ${4:any relevant condition}",
      "- Then: ${5:consistent system behavior}"
    ],
    "description": "Ubiquitous EARS requirement template"
  },
  
  "Complete EARS Requirement Block": {
    "prefix": "ears-complete",
    "body": [
      "## ${1:Requirement Title}",
      "",
      "**ID:** REQ-${2:PROJECT}-${3:NUMBER}",
      "**Category:** ${4|functional,non-functional,business-rule,constraint|}",
      "**Priority:** ${5|critical,high,medium,low|}",
      "",
      "### EARS Requirement",
      "${6:EARS requirement statement}",
      "",
      "### Acceptance Criteria",
      "1. **Given:** ${7:precondition}",
      "   **When:** ${8:action}",
      "   **Then:** ${9:expected outcome}",
      "",
      "2. **Given:** ${10:error condition}",
      "   **When:** ${11:error trigger}",
      "   **Then:** ${12:error handling}",
      "",
      "### Metadata",
      "- **Author:** ${13:author name}",
      "- **Created:** ${14:YYYY-MM-DD}",
      "- **Stakeholders:** ${15:stakeholder list}",
      "- **Related Requirements:** ${16:REQ-IDs}"
    ],
    "description": "Complete EARS requirement documentation block"
  }
}
```

### IntelliJ IDEA Plugin Structure

```kotlin
// EarsLanguageSupport.kt
class EarsLanguageSupport : LanguageExtension {
    companion object {
        val EARS_LANGUAGE = Language.create("EARS")
    }
}

// EarsAnnotator.kt
class EarsAnnotator : Annotator {
    override fun annotate(element: PsiElement, holder: AnnotationHolder) {
        if (element is EarsRequirement) {
            validateEarsRequirement(element, holder)
        }
    }
    
    private fun validateEarsRequirement(element: EarsRequirement, holder: AnnotationHolder) {
        val text = element.text
        val validator = EarsValidator()
        
        if (!validator.isValidTemplate(text)) {
            holder.createErrorAnnotation(element, "Invalid EARS template pattern")
        }
        
        validator.checkQuality(text).forEach { issue ->
            when (issue.severity) {
                "error" -> holder.createErrorAnnotation(element, issue.message)
                "warning" -> holder.createWarningAnnotation(element, issue.message)
                "info" -> holder.createInfoAnnotation(element, issue.message)
            }
        }
    }
}

// EarsCompletionContributor.kt
class EarsCompletionContributor : CompletionContributor() {
    init {
        extend(
            CompletionType.BASIC,
            PlatformPatterns.psiElement(),
            EarsTemplateProvider()
        )
    }
}

class EarsTemplateProvider : CompletionProvider<CompletionParameters>() {
    override fun addCompletions(
        parameters: CompletionParameters,
        context: ProcessingContext,
        result: CompletionResultSet
    ) {
        val templates = listOf(
            "WHEN {trigger} the system shall {response}",
            "IF {condition} THEN the system shall {response}",
            "WHILE {state} the system shall {behavior}",
            "WHERE {feature} is available, the system shall {behavior}",
            "The system shall {requirement}",
            "IF {condition} THEN WHEN {trigger} the system shall {response}"
        )
        
        templates.forEach { template ->
            result.addElement(
                LookupElementBuilder.create(template)
                    .withIcon(EarsIcons.TEMPLATE)
                    .withTypeText("EARS Template")
            )
        }
    }
}
```

## Project Management Integration

### JIRA Integration

#### Custom Field Configuration

```javascript
// jira-ears-integration.js
class JiraEarsIntegration {
    constructor(jiraConfig) {
        this.jira = new JiraApi(jiraConfig);
        this.earsValidator = new EarsValidator();
    }

    async createEarsRequirement(projectKey, earsData) {
        const issue = {
            fields: {
                project: { key: projectKey },
                summary: earsData.title,
                description: this.formatEarsDescription(earsData),
                issuetype: { name: 'Requirement' },
                customfield_10001: earsData.ears.template, // EARS Template
                customfield_10002: earsData.ears.condition, // EARS Condition
                customfield_10003: earsData.ears.response, // EARS Response
                customfield_10004: JSON.stringify(earsData.acceptance_criteria) // Acceptance Criteria
            }
        };

        const validation = this.earsValidator.validateRequirement(earsData);
        if (!validation.isValid) {
            throw new Error(`EARS validation failed: ${validation.issues.map(i => i.message).join(', ')}`);
        }

        return await this.jira.addNewIssue(issue);
    }

    formatEarsDescription(earsData) {
        return `
h2. EARS Requirement
{code}
${earsData.ears.response}
{code}

h2. Acceptance Criteria
${earsData.acceptance_criteria.map((criteria, index) => 
    `${index + 1}. *Given:* ${criteria.given}
       *When:* ${criteria.when}
       *Then:* ${criteria.then}`
).join('\n\n')}

h2. Quality Score
Quality Score: ${earsData.qualityScore || 'Not calculated'}

h2. Metadata
* Template: ${earsData.ears.template}
* Category: ${earsData.category}
* Priority: ${earsData.priority}
* Author: ${earsData.metadata.author}
* Created: ${earsData.metadata.created_date}
        `.trim();
    }

    async validateAllRequirements(projectKey) {
        const jql = `project = ${projectKey} AND issuetype = Requirement`;
        const issues = await this.jira.searchJira(jql);
        
        const validationResults = [];
        
        for (const issue of issues.issues) {
            const earsText = issue.fields.customfield_10003; // EARS Response
            if (earsText) {
                const validation = this.earsValidator.validateRequirement({
                    requirement: earsText,
                    template: issue.fields.customfield_10001
                });
                
                validationResults.push({
                    issueKey: issue.key,
                    summary: issue.fields.summary,
                    validation: validation
                });
            }
        }
        
        return validationResults;
    }
}

// Usage
const jiraIntegration = new JiraEarsIntegration({
    protocol: 'https',
    host: 'your-domain.atlassian.net',
    username: 'your-email',
    password: 'your-api-token',
    apiVersion: '2',
    strictSSL: true
});

// Create EARS requirement in JIRA
const earsRequirement = {
    title: "User Authentication Response Time",
    category: "non-functional",
    priority: "high",
    ears: {
        template: "event-driven",
        condition: "WHEN a user submits valid login credentials",
        response: "WHEN a user submits valid login credentials, the system shall authenticate within 2 seconds"
    },
    acceptance_criteria: [
        {
            given: "A user has valid credentials",
            when: "The user submits the login form",
            then: "Authentication completes within 2 seconds"
        }
    ],
    metadata: {
        author: "Requirements Analyst",
        created_date: "2024-01-15"
    }
};

jiraIntegration.createEarsRequirement('PROJ', earsRequirement)
    .then(issue => console.log('Created issue:', issue.key))
    .catch(error => console.error('Error:', error));
```

### Azure DevOps Integration

```csharp
// AzureDevOpsEarsIntegration.cs
using Microsoft.TeamFoundation.WorkItemTracking.WebApi;
using Microsoft.TeamFoundation.WorkItemTracking.WebApi.Models;
using Microsoft.VisualStudio.Services.Common;
using Microsoft.VisualStudio.Services.WebApi;

public class AzureDevOpsEarsIntegration
{
    private readonly WorkItemTrackingHttpClient _workItemClient;
    private readonly EarsValidator _earsValidator;

    public AzureDevOpsEarsIntegration(string organizationUrl, string personalAccessToken)
    {
        var connection = new VssConnection(new Uri(organizationUrl), new VssBasicCredential(string.Empty, personalAccessToken));
        _workItemClient = connection.GetClient<WorkItemTrackingHttpClient>();
        _earsValidator = new EarsValidator();
    }

    public async Task<WorkItem> CreateEarsRequirementAsync(string projectName, EarsRequirementData earsData)
    {
        var validation = _earsValidator.ValidateRequirement(earsData);
        if (!validation.IsValid)
        {
            throw new ArgumentException($"EARS validation failed: {string.Join(", ", validation.Issues.Select(i => i.Message))}");
        }

        var patchDocument = new JsonPatchDocument
        {
            new JsonPatchOperation
            {
                Operation = Operation.Add,
                Path = "/fields/System.Title",
                Value = earsData.Title
            },
            new JsonPatchOperation
            {
                Operation = Operation.Add,
                Path = "/fields/System.Description",
                Value = FormatEarsDescription(earsData)
            },
            new JsonPatchOperation
            {
                Operation = Operation.Add,
                Path = "/fields/Custom.EarsTemplate",
                Value = earsData.Ears.Template
            },
            new JsonPatchOperation
            {
                Operation = Operation.Add,
                Path = "/fields/Custom.EarsCondition",
                Value = earsData.Ears.Condition
            },
            new JsonPatchOperation
            {
                Operation = Operation.Add,
                Path = "/fields/Custom.EarsResponse",
                Value = earsData.Ears.Response
            },
            new JsonPatchOperation
            {
                Operation = Operation.Add,
                Path = "/fields/Custom.AcceptanceCriteria",
                Value = JsonSerializer.Serialize(earsData.AcceptanceCriteria)
            },
            new JsonPatchOperation
            {
                Operation = Operation.Add,
                Path = "/fields/Custom.QualityScore",
                Value = validation.Score
            }
        };

        return await _workItemClient.CreateWorkItemAsync(patchDocument, projectName, "Requirement");
    }

    private string FormatEarsDescription(EarsRequirementData earsData)
    {
        var sb = new StringBuilder();
        sb.AppendLine("## EARS Requirement");
        sb.AppendLine($"```");
        sb.AppendLine(earsData.Ears.Response);
        sb.AppendLine($"```");
        sb.AppendLine();
        
        sb.AppendLine("## Acceptance Criteria");
        for (int i = 0; i < earsData.AcceptanceCriteria.Count; i++)
        {
            var criteria = earsData.AcceptanceCriteria[i];
            sb.AppendLine($"{i + 1}. **Given:** {criteria.Given}");
            sb.AppendLine($"   **When:** {criteria.When}");
            sb.AppendLine($"   **Then:** {criteria.Then}");
            sb.AppendLine();
        }

        sb.AppendLine("## Metadata");
        sb.AppendLine($"- **Template:** {earsData.Ears.Template}");
        sb.AppendLine($"- **Category:** {earsData.Category}");
        sb.AppendLine($"- **Priority:** {earsData.Priority}");
        
        return sb.ToString();
    }

    public async Task<List<EarsValidationResult>> ValidateAllRequirementsAsync(string projectName)
    {
        var wiql = new Wiql
        {
            Query = $"SELECT [System.Id], [System.Title], [Custom.EarsResponse] FROM WorkItems WHERE [System.TeamProject] = '{projectName}' AND [System.WorkItemType] = 'Requirement'"
        };

        var workItemQueryResult = await _workItemClient.QueryByWiqlAsync(wiql);
        var workItemIds = workItemQueryResult.WorkItems.Select(wi => wi.Id).ToArray();

        if (!workItemIds.Any()) return new List<EarsValidationResult>();

        var workItems = await _workItemClient.GetWorkItemsAsync(workItemIds, expand: WorkItemExpand.Fields);
        var validationResults = new List<EarsValidationResult>();

        foreach (var workItem in workItems)
        {
            var earsResponse = workItem.Fields.GetValueOrDefault("Custom.EarsResponse")?.ToString();
            if (!string.IsNullOrEmpty(earsResponse))
            {
                var validation = _earsValidator.ValidateRequirement(new EarsRequirementData
                {
                    Ears = new EarsData { Response = earsResponse }
                });

                validationResults.Add(new EarsValidationResult
                {
                    WorkItemId = workItem.Id.Value,
                    Title = workItem.Fields["System.Title"].ToString(),
                    Validation = validation
                });
            }
        }

        return validationResults;
    }
}

// Data Models
public class EarsRequirementData
{
    public string Title { get; set; }
    public string Category { get; set; }
    public string Priority { get; set; }
    public EarsData Ears { get; set; }
    public List<AcceptanceCriterion> AcceptanceCriteria { get; set; }
    public RequirementMetadata Metadata { get; set; }
}

public class EarsData
{
    public string Template { get; set; }
    public string Condition { get; set; }
    public string Response { get; set; }
}

public class AcceptanceCriterion
{
    public string Given { get; set; }
    public string When { get; set; }
    public string Then { get; set; }
}

public class EarsValidationResult
{
    public int WorkItemId { get; set; }
    public string Title { get; set; }
    public ValidationResult Validation { get; set; }
}
```

## Automated Report Generation

### Quality Dashboard

```python
# ears_dashboard.py
import os
import json
import yaml
from datetime import datetime, timedelta
import matplotlib.pyplot as plt
import pandas as pd
from jinja2 import Template

class EarsDashboard:
    def __init__(self, requirements_dir):
        self.requirements_dir = requirements_dir
        self.validator = EarsValidator()
        
    def generate_quality_report(self, output_dir='reports'):
        """Generate comprehensive EARS quality report"""
        
        # Collect all requirements
        requirements = self._collect_requirements()
        
        # Validate all requirements
        validation_results = []
        for req_file, reqs in requirements.items():
            for req in reqs:
                result = self.validator.validate_requirement(req)
                result['file'] = req_file
                result['timestamp'] = datetime.now().isoformat()
                validation_results.append(result)
        
        # Generate analytics
        analytics = self._generate_analytics(validation_results)
        
        # Create visualizations
        charts = self._create_charts(analytics, output_dir)
        
        # Generate HTML report
        html_report = self._generate_html_report(analytics, charts, output_dir)
        
        # Generate executive summary
        exec_summary = self._generate_executive_summary(analytics)
        
        return {
            'html_report': html_report,
            'executive_summary': exec_summary,
            'analytics': analytics,
            'charts': charts
        }
    
    def _collect_requirements(self):
        """Collect all requirements from the requirements directory"""
        requirements = {}
        
        for root, dirs, files in os.walk(self.requirements_dir):
            for file in files:
                if file.endswith(('.yaml', '.yml', '.md')):
                    file_path = os.path.join(root, file)
                    try:
                        reqs = self._parse_requirements_file(file_path)
                        if reqs:
                            requirements[file_path] = reqs
                    except Exception as e:
                        print(f"Error parsing {file_path}: {e}")
        
        return requirements
    
    def _parse_requirements_file(self, file_path):
        """Parse requirements from a file"""
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        if file_path.endswith('.md'):
            return self._parse_markdown_requirements(content)
        else:
            return self._parse_yaml_requirements(content)
    
    def _generate_analytics(self, validation_results):
        """Generate analytics from validation results"""
        df = pd.DataFrame(validation_results)
        
        analytics = {
            'total_requirements': len(validation_results),
            'valid_requirements': len(df[df['is_valid'] == True]),
            'validation_rate': len(df[df['is_valid'] == True]) / len(validation_results) * 100,
            'average_quality_score': df['score'].mean(),
            'template_distribution': df['template'].value_counts().to_dict(),
            'quality_distribution': self._categorize_quality_scores(df['score']),
            'common_issues': self._analyze_common_issues(validation_results),
            'file_statistics': self._analyze_by_file(validation_results),
            'trend_data': self._generate_trend_data(validation_results)
        }
        
        return analytics
    
    def _categorize_quality_scores(self, scores):
        """Categorize quality scores into ranges"""
        categories = {
            'excellent': len(scores[scores >= 90]),
            'good': len(scores[(scores >= 75) & (scores < 90)]),
            'fair': len(scores[(scores >= 60) & (scores < 75)]),
            'poor': len(scores[scores < 60])
        }
        return categories
    
    def _analyze_common_issues(self, validation_results):
        """Analyze most common validation issues"""
        issue_counts = {}
        
        for result in validation_results:
            for issue in result.get('issues', []):
                issue_code = issue.get('code', 'unknown')
                issue_counts[issue_code] = issue_counts.get(issue_code, 0) + 1
        
        return dict(sorted(issue_counts.items(), key=lambda x: x[1], reverse=True))
    
    def _create_charts(self, analytics, output_dir):
        """Create visualization charts"""
        os.makedirs(output_dir, exist_ok=True)
        charts = {}
        
        # Template distribution pie chart
        plt.figure(figsize=(10, 6))
        plt.pie(analytics['template_distribution'].values(), 
                labels=analytics['template_distribution'].keys(), 
                autopct='%1.1f%%')
        plt.title('EARS Template Distribution')
        template_chart = os.path.join(output_dir, 'template_distribution.png')
        plt.savefig(template_chart)
        plt.close()
        charts['template_distribution'] = template_chart
        
        # Quality score distribution
        plt.figure(figsize=(10, 6))
        quality_cats = analytics['quality_distribution']
        plt.bar(quality_cats.keys(), quality_cats.values(), color=['green', 'yellow', 'orange', 'red'])
        plt.title('Quality Score Distribution')
        plt.xlabel('Quality Category')
        plt.ylabel('Number of Requirements')
        quality_chart = os.path.join(output_dir, 'quality_distribution.png')
        plt.savefig(quality_chart)
        plt.close()
        charts['quality_distribution'] = quality_chart
        
        # Common issues chart
        if analytics['common_issues']:
            plt.figure(figsize=(12, 8))
            issues = list(analytics['common_issues'].keys())[:10]  # Top 10
            counts = [analytics['common_issues'][issue] for issue in issues]
            plt.barh(issues, counts)
            plt.title('Top 10 Most Common Issues')
            plt.xlabel('Frequency')
            plt.tight_layout()
            issues_chart = os.path.join(output_dir, 'common_issues.png')
            plt.savefig(issues_chart)
            plt.close()
            charts['common_issues'] = issues_chart
        
        return charts
    
    def _generate_html_report(self, analytics, charts, output_dir):
        """Generate HTML report"""
        
        html_template = """
        <!DOCTYPE html>
        <html>
        <head>
            <title>EARS Quality Report</title>
            <style>
                body { font-family: Arial, sans-serif; margin: 40px; }
                .header { text-align: center; color: #333; }
                .metric { display: inline-block; margin: 20px; padding: 20px; 
                         border: 1px solid #ddd; border-radius: 5px; text-align: center; }
                .metric h3 { margin: 0; color: #666; }
                .metric .value { font-size: 2em; font-weight: bold; color: #333; }
                .chart { text-align: center; margin: 30px 0; }
                .excellent { color: #4CAF50; }
                .good { color: #8BC34A; }
                .fair { color: #FF9800; }
                .poor { color: #F44336; }
                table { width: 100%; border-collapse: collapse; margin: 20px 0; }
                th, td { border: 1px solid #ddd; padding: 12px; text-align: left; }
                th { background-color: #f2f2f2; }
            </style>
        </head>
        <body>
            <div class="header">
                <h1>EARS Requirements Quality Report</h1>
                <p>Generated on {{ timestamp }}</p>
            </div>
            
            <div class="metrics">
                <div class="metric">
                    <h3>Total Requirements</h3>
                    <div class="value">{{ analytics.total_requirements }}</div>
                </div>
                <div class="metric">
                    <h3>Validation Rate</h3>
                    <div class="value">{{ "%.1f"|format(analytics.validation_rate) }}%</div>
                </div>
                <div class="metric">
                    <h3>Average Quality Score</h3>
                    <div class="value">{{ "%.1f"|format(analytics.average_quality_score) }}/100</div>
                </div>
            </div>
            
            <div class="chart">
                <h2>Template Distribution</h2>
                <img src="{{ charts.template_distribution }}" alt="Template Distribution" style="max-width: 800px;">
            </div>
            
            <div class="chart">
                <h2>Quality Score Distribution</h2>
                <img src="{{ charts.quality_distribution }}" alt="Quality Distribution" style="max-width: 800px;">
            </div>
            
            {% if charts.common_issues %}
            <div class="chart">
                <h2>Most Common Issues</h2>
                <img src="{{ charts.common_issues }}" alt="Common Issues" style="max-width: 800px;">
            </div>
            {% endif %}
            
            <h2>File Statistics</h2>
            <table>
                <thead>
                    <tr>
                        <th>File</th>
                        <th>Requirements</th>
                        <th>Valid</th>
                        <th>Validation Rate</th>
                        <th>Average Score</th>
                    </tr>
                </thead>
                <tbody>
                    {% for file_path, stats in analytics.file_statistics.items() %}
                    <tr>
                        <td>{{ file_path }}</td>
                        <td>{{ stats.total }}</td>
                        <td>{{ stats.valid }}</td>
                        <td>{{ "%.1f"|format(stats.validation_rate) }}%</td>
                        <td>{{ "%.1f"|format(stats.average_score) }}</td>
                    </tr>
                    {% endfor %}
                </tbody>
            </table>
            
            <h2>Recommendations</h2>
            <ul>
                {% if analytics.validation_rate < 90 %}
                <li>Focus on improving EARS template compliance - current rate is {{ "%.1f"|format(analytics.validation_rate) }}%</li>
                {% endif %}
                
                {% if analytics.average_quality_score < 80 %}
                <li>Address common quality issues to improve average score from {{ "%.1f"|format(analytics.average_quality_score) }}</li>
                {% endif %}
                
                {% for issue, count in analytics.common_issues.items() %}
                {% if loop.index <= 3 %}
                <li>Address {{ issue }} which affects {{ count }} requirements</li>
                {% endif %}
                {% endfor %}
            </ul>
        </body>
        </html>
        """
        
        template = Template(html_template)
        html_content = template.render(
            analytics=analytics,
            charts=charts,
            timestamp=datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        )
        
        html_file = os.path.join(output_dir, 'ears_quality_report.html')
        with open(html_file, 'w', encoding='utf-8') as f:
            f.write(html_content)
        
        return html_file
    
    def _generate_executive_summary(self, analytics):
        """Generate executive summary"""
        summary = {
            'overall_health': self._assess_overall_health(analytics),
            'key_metrics': {
                'total_requirements': analytics['total_requirements'],
                'validation_rate': analytics['validation_rate'],
                'average_quality_score': analytics['average_quality_score']
            },
            'top_issues': list(analytics['common_issues'].keys())[:5],
            'recommendations': self._generate_recommendations(analytics)
        }
        return summary
    
    def _assess_overall_health(self, analytics):
        """Assess overall requirements health"""
        score = analytics['average_quality_score']
        validation_rate = analytics['validation_rate']
        
        if score >= 85 and validation_rate >= 95:
            return 'excellent'
        elif score >= 75 and validation_rate >= 85:
            return 'good'
        elif score >= 65 and validation_rate >= 75:
            return 'fair'
        else:
            return 'poor'

# Usage
dashboard = EarsDashboard('./requirements')
report = dashboard.generate_quality_report('./reports')
print(f"Report generated: {report['html_report']}")
```

This comprehensive tools and automation suite provides everything needed to effectively implement and maintain EARS notation in software development projects. The tools cover validation, IDE integration, CI/CD automation, project management integration, and quality reporting.

## Navigation

← [Comparison Analysis](comparison-analysis.md) | [Quality Assurance →](quality-assurance.md)

---

*Tools and automation guide based on practical implementations and industry best practices for EARS notation support in development workflows.*