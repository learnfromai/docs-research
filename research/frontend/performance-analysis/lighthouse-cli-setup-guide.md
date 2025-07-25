# Lighthouse CLI Setup Guide for Local Development

A comprehensive guide to installing and configuring Lighthouse CLI for local performance testing that matches PageSpeed Insights accuracy.

{% hint style="info" %}
**Purpose**: Set up Lighthouse CLI for local development with HTML report generation and configuration matching PageSpeed Insights for maximum accuracy.
{% endhint %}

## Table of Contents

1. [Installation](#installation)
2. [Basic Usage](#basic-usage)
3. [HTML Report Generation](#html-report-generation)
4. [Advanced Configuration](#advanced-configuration)
5. [Development Workflow](#development-workflow)
6. [Automation Scripts](#automation-scripts)
7. [Best Practices](#best-practices)

## Installation

### Global Installation (Recommended)

```bash
# Install Lighthouse CLI globally
npm install -g lighthouse

# Verify installation
lighthouse --version

# Check available options
lighthouse --help
```

### Project-Specific Installation

```bash
# Install as dev dependency
npm install --save-dev lighthouse

# Run with npx
npx lighthouse --version
```

### Requirements

- **Node.js**: Version 18.20 or later
- **Chrome/Chromium**: Automatically detected or specify with `CHROME_PATH`

## Basic Usage

### Simple HTML Report Generation

```bash
# Generate HTML report for local development server
lighthouse http://localhost:3000

# Generates: localhost_3000_<timestamp>.report.html

# Specify custom output location
lighthouse http://localhost:3000 --output-path ./performance-report.html

# Open report automatically after generation
lighthouse http://localhost:3000 --view
```

### Multiple Output Formats

```bash
# Generate both HTML and JSON reports
lighthouse http://localhost:3000 \
  --output html \
  --output json \
  --output-path ./reports/my-test

# Results in:
# - my-test.report.html
# - my-test.report.json
```

## HTML Report Generation

### Report Features

The HTML reports include:

- **Interactive Performance Metrics**: Core Web Vitals with explanations
- **Opportunities Section**: Specific optimization recommendations
- **Diagnostics**: Additional performance insights
- **Accessibility Audits**: WCAG compliance checks
- **SEO Analysis**: Search engine optimization recommendations
- **Best Practices**: Modern web development standards

### Report Storage and Sharing

```bash
# Create organized report structure
mkdir -p lighthouse-reports/$(date +%Y-%m-%d)

# Generate timestamped reports
lighthouse http://localhost:3000 \
  --output-path "./lighthouse-reports/$(date +%Y-%m-%d)/report-$(date +%H-%M-%S).html" \
  --view
```

## Advanced Configuration

### 1. PageSpeed Insights Matching Configuration

Create `lighthouse-config.js`:

```javascript
// lighthouse-config.js - Matches PageSpeed Insights settings
module.exports = {
  extends: 'lighthouse:default',
  settings: {
    // Match PageSpeed Insights throttling
    throttling: {
      rttMs: 150,                    // Round-trip time
      throughputKbps: 1638.4,        // ~1.6 Mbps download
      uploadThroughputKbps: 675,     // Upload speed
      cpuSlowdownMultiplier: 4       // CPU throttling
    },
    
    // Mobile emulation (matches PageSpeed Insights default)
    emulatedFormFactor: 'mobile',
    screenEmulation: {
      mobile: true,
      width: 360,
      height: 640,
      deviceScaleFactor: 2,
      disabled: false
    },
    
    // Additional settings for accuracy
    onlyCategories: ['performance', 'accessibility', 'best-practices', 'seo'],
    skipAudits: [],
    
    // Ensure consistent results
    disableStorageReset: false,
    clearStorageTypes: ['cookies', 'localstorage', 'websql', 'indexeddb']
  }
};
```

### 2. Performance Budget Configuration

Create `lighthouse-budget.json`:

```json
{
  "resourceSizes": [
    {
      "resourceType": "script",
      "budget": 170
    },
    {
      "resourceType": "image", 
      "budget": 500
    },
    {
      "resourceType": "stylesheet",
      "budget": 50
    },
    {
      "resourceType": "font",
      "budget": 100
    },
    {
      "resourceType": "total",
      "budget": 1000
    }
  ],
  "timings": [
    {
      "metric": "interactive",
      "budget": 5000
    },
    {
      "metric": "first-contentful-paint",
      "budget": 2000
    },
    {
      "metric": "largest-contentful-paint", 
      "budget": 2500
    },
    {
      "metric": "total-blocking-time",
      "budget": 300
    },
    {
      "metric": "cumulative-layout-shift",
      "budget": 0.1
    }
  ]
}
```

### 3. Running with Custom Configuration

```bash
# Use custom configuration
lighthouse http://localhost:3000 \
  --config-path=./lighthouse-config.js \
  --budget-path=./lighthouse-budget.json \
  --output-path=./report.html \
  --view

# Desktop testing configuration
lighthouse http://localhost:3000 \
  --preset=desktop \
  --config-path=./lighthouse-config.js \
  --view
```

## Development Workflow

### 1. Pre-Build Testing

```bash
# Test development server
npm start & 
sleep 5  # Wait for server to start
lighthouse http://localhost:3000 --view
kill %1  # Stop background npm start
```

### 2. Production Build Testing

```bash
# Build and test production bundle locally
npm run build

# Serve production build
npx serve build/ -l 5000 &
sleep 3

# Test production build
lighthouse http://localhost:5000 \
  --output-path="./reports/production-$(date +%Y%m%d-%H%M%S).html" \
  --view

# Cleanup
kill %1
```

### 3. Comparative Testing

```bash
# Test multiple environments
lighthouse http://localhost:3000 --output-path ./reports/dev.html
lighthouse http://localhost:5000 --output-path ./reports/prod.html
lighthouse https://your-staging-site.com --output-path ./reports/staging.html

# Open all reports for comparison
open ./reports/dev.html ./reports/prod.html ./reports/staging.html
```

## Automation Scripts

### 1. Performance Testing Script

Create `scripts/lighthouse-test.sh`:

```bash
#!/bin/bash

# lighthouse-test.sh - Automated performance testing

set -e

# Configuration
LOCAL_URL="http://localhost:3000"
REPORT_DIR="./lighthouse-reports"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# Create report directory
mkdir -p "$REPORT_DIR"

echo "🚀 Starting Lighthouse performance test..."

# Check if local server is running
if ! curl -s "$LOCAL_URL" > /dev/null; then
    echo "❌ Local server not running at $LOCAL_URL"
    echo "💡 Start your development server first: npm start"
    exit 1
fi

# Run Lighthouse test
echo "📊 Running Lighthouse analysis..."
lighthouse "$LOCAL_URL" \
    --config-path=./lighthouse-config.js \
    --budget-path=./lighthouse-budget.json \
    --output html \
    --output json \
    --output-path="$REPORT_DIR/report-$TIMESTAMP" \
    --chrome-flags="--headless --no-sandbox" \
    --quiet

echo "✅ Performance test completed!"
echo "📄 HTML Report: $REPORT_DIR/report-$TIMESTAMP.report.html"
echo "📊 JSON Data: $REPORT_DIR/report-$TIMESTAMP.report.json"

# Open report automatically
open "$REPORT_DIR/report-$TIMESTAMP.report.html"
```

### 2. Package.json Scripts

Add to your `package.json`:

```json
{
  "scripts": {
    "lighthouse": "lighthouse http://localhost:3000 --view",
    "lighthouse:prod": "npm run build && npx serve build/ -l 5000 & sleep 3 && lighthouse http://localhost:5000 --view && kill %1",
    "lighthouse:config": "lighthouse http://localhost:3000 --config-path=./lighthouse-config.js --view",
    "lighthouse:budget": "lighthouse http://localhost:3000 --budget-path=./lighthouse-budget.json --view",
    "lighthouse:ci": "lighthouse http://localhost:3000 --output json --output-path ./lighthouse-results.json --chrome-flags='--headless --no-sandbox'"
  }
}
```

### 3. Multiple Run Analysis

Create `scripts/lighthouse-multi-run.sh`:

```bash
#!/bin/bash

# Run Lighthouse multiple times for average results
URL="http://localhost:3000"
RUNS=5
REPORT_DIR="./lighthouse-reports/multi-run-$(date +%Y%m%d-%H%M%S)"

mkdir -p "$REPORT_DIR"

echo "🔄 Running Lighthouse $RUNS times for statistical accuracy..."

for i in $(seq 1 $RUNS); do
    echo "📊 Run $i of $RUNS..."
    lighthouse "$URL" \
        --output json \
        --output-path="$REPORT_DIR/run-$i.json" \
        --chrome-flags="--headless --no-sandbox" \
        --quiet
    
    sleep 2  # Brief pause between runs
done

echo "✅ Multi-run analysis completed!"
echo "📁 Results saved to: $REPORT_DIR"

# Generate final HTML report from last run
lighthouse "$URL" \
    --output html \
    --output-path="$REPORT_DIR/final-report.html" \
    --view
```

## Best Practices

### 1. Environment Consistency

```bash
# Optimal Lighthouse environment
lighthouse http://localhost:3000 \
    --chrome-flags="--headless --no-sandbox --disable-gpu --disable-dev-shm-usage" \
    --throttling-method=simulate \
    --view
```

### 2. CI/CD Integration

For automated testing in CI/CD:

```bash
# Headless mode for CI
lighthouse http://localhost:3000 \
    --chrome-flags="--headless --no-sandbox --disable-gpu" \
    --output json \
    --output-path ./lighthouse-results.json
```

### 3. Report Organization

```bash
# Organized report structure
PROJECT_NAME="my-app"
DATE=$(date +%Y-%m-%d)
TIME=$(date +%H-%M-%S)

mkdir -p "./lighthouse-reports/$PROJECT_NAME/$DATE"

lighthouse http://localhost:3000 \
    --output-path="./lighthouse-reports/$PROJECT_NAME/$DATE/$TIME-report.html" \
    --view
```

### 4. Performance Monitoring

```bash
# Track performance over time
echo "$(date), $(lighthouse http://localhost:3000 --output json | jq '.categories.performance.score')" >> performance-log.csv
```

## Advanced Features

### 1. Custom Audits

You can extend Lighthouse with custom audits specific to your application.

### 2. Lighthouse Viewer

Access the online [Lighthouse Viewer](https://googlechrome.github.io/lighthouse/viewer/) to:

- View JSON reports online
- Share reports via GitHub Gists
- Compare multiple reports

### 3. Lighthouse CI

For advanced CI/CD integration:

```bash
npm install -g @lhci/cli

# Initialize Lighthouse CI
lhci autorun
```

## Troubleshooting

### Common Issues

1. **Chrome not found**: Set `CHROME_PATH` environment variable
2. **Port conflicts**: Ensure your dev server is running on the expected port
3. **Memory issues**: Use `--chrome-flags="--max_old_space_size=4096"`

### Debug Mode

```bash
# Run with debug information
lighthouse http://localhost:3000 --verbose --view
```

## Related Topics

- [PageSpeed Insights vs Lighthouse Analysis](./pagespeed-insights-vs-lighthouse-analysis.md) - Understanding the relationship between tools
- [React/Vite Performance Optimization](./react-vite-performance-optimization.md) - Practical optimization techniques
- [Performance Testing Automation](../../tools/configurations/lighthouse-ci-setup.md) - Advanced CI/CD integration

---

## Navigation

- ← Previous: [PageSpeed Insights vs Lighthouse Analysis](./pagespeed-insights-vs-lighthouse-analysis.md)
- → Next: [Performance Testing Automation](../../tools/configurations/lighthouse-ci-setup.md)
- ↑ Back to: [Frontend Research](./README.md)
