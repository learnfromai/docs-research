# E2E Testing Best Practices and Implementation Guide

## Overview

This guide consolidates best practices for implementing E2E testing that effectively simulates QA tester workflows while maintaining test reliability, maintainability, and execution speed. These practices apply across all major E2E testing frameworks but include specific examples for Playwright, Cypress, and other tools.

## Test Strategy and Planning

### Acceptance Criteria Mapping

Transform user stories and acceptance criteria into structured test scenarios:

```typescript
// Example: User Story Mapping
interface UserStory {
  id: string;
  title: string;
  description: string;
  acceptanceCriteria: AcceptanceCriteria[];
}

interface AcceptanceCriteria {
  id: string;
  given: string;
  when: string;
  then: string;
  priority: 'high' | 'medium' | 'low';
}

// Test Implementation
describe('User Story: Password Reset Functionality', () => {
  const userStory: UserStory = {
    id: 'US-123',
    title: 'Password Reset via Email',
    description: 'As a user, I want to reset my password via email so I can regain access to my account',
    acceptanceCriteria: [
      {
        id: 'AC-123-1',
        given: 'User is on the forgot password page',
        when: 'User enters a valid registered email address',
        then: 'System sends password reset email and shows confirmation message',
        priority: 'high'
      },
      {
        id: 'AC-123-2',
        given: 'User receives password reset email',
        when: 'User clicks on the reset link within 24 hours',
        then: 'User is directed to password reset form',
        priority: 'high'
      }
    ]
  };

  userStory.acceptanceCriteria.forEach(ac => {
    test(`${ac.id}: ${ac.given} -> ${ac.when} -> ${ac.then}`, async ({ page }) => {
      // Implementation based on acceptance criteria
    });
  });
});
```

### Test Pyramid for E2E

Structure E2E tests to complement other testing layers:

```typescript
// High-Level User Journeys (Small number, high value)
describe('Critical User Journeys', () => {
  test('Complete user onboarding flow', async ({ page }) => {
    // Registration -> Email verification -> Profile setup -> First login
  });
  
  test('End-to-end purchase workflow', async ({ page }) => {
    // Product selection -> Add to cart -> Checkout -> Payment -> Confirmation
  });
});

// Feature-Specific Workflows (Medium number, focused scope)
describe('Authentication Features', () => {
  test('Login with valid credentials', async ({ page }) => {
    // Focused on login functionality
  });
  
  test('Password reset workflow', async ({ page }) => {
    // Focused on password reset
  });
});

// Edge Cases and Error Handling (Targeted scenarios)
describe('Error Handling', () => {
  test('Network failure during checkout', async ({ page }) => {
    // Specific error scenario testing
  });
});
```

## Test Organization and Structure

### Page Object Model (POM) Implementation

Create maintainable and reusable page objects:

```typescript
// Base Page Object
abstract class BasePage {
  constructor(protected page: Page) {}
  
  /**
   * Navigate to the page
   */
  abstract navigate(): Promise<void>;
  
  /**
   * Wait for page to be ready
   */
  async waitForPageReady(): Promise<void> {
    await this.page.waitForLoadState('networkidle');
  }
  
  /**
   * Take screenshot for debugging
   */
  async takeScreenshot(name: string): Promise<void> {
    await this.page.screenshot({ 
      path: `screenshots/${name}-${Date.now()}.png`,
      fullPage: true 
    });
  }
  
  /**
   * Wait for element with timeout
   */
  async waitForElement(selector: string, timeout: number = 10000): Promise<void> {
    await this.page.waitForSelector(selector, { timeout });
  }
}

// Specific Page Implementation
class LoginPage extends BasePage {
  // Locator constants for maintainability
  private readonly selectors = {
    usernameField: '[data-testid="username"]',
    passwordField: '[data-testid="password"]',
    loginButton: '[data-testid="login-button"]',
    errorMessage: '[data-testid="error-message"]',
    forgotPasswordLink: '[data-testid="forgot-password"]',
    rememberMeCheckbox: '[data-testid="remember-me"]'
  } as const;
  
  async navigate(): Promise<void> {
    await this.page.goto('/login');
    await this.waitForPageReady();
  }
  
  /**
   * Perform login with credentials
   */
  async login(username: string, password: string, rememberMe: boolean = false): Promise<void> {
    await this.page.fill(this.selectors.usernameField, username);
    await this.page.fill(this.selectors.passwordField, password);
    
    if (rememberMe) {
      await this.page.check(this.selectors.rememberMeCheckbox);
    }
    
    await this.page.click(this.selectors.loginButton);
  }
  
  /**
   * Verify login error message
   */
  async expectErrorMessage(expectedMessage: string): Promise<void> {
    await expect(this.page.locator(this.selectors.errorMessage))
      .toBeVisible();
    await expect(this.page.locator(this.selectors.errorMessage))
      .toContainText(expectedMessage);
  }
  
  /**
   * Check if login form is visible
   */
  async isLoginFormVisible(): Promise<boolean> {
    const usernameVisible = await this.page.locator(this.selectors.usernameField).isVisible();
    const passwordVisible = await this.page.locator(this.selectors.passwordField).isVisible();
    const buttonVisible = await this.page.locator(this.selectors.loginButton).isVisible();
    
    return usernameVisible && passwordVisible && buttonVisible;
  }
}

// Component Objects for Reusable UI Elements
class NavigationComponent {
  constructor(private page: Page) {}
  
  private readonly selectors = {
    userMenu: '[data-testid="user-menu"]',
    logoutButton: '[data-testid="logout-button"]',
    profileLink: '[data-testid="profile-link"]',
    settingsLink: '[data-testid="settings-link"]'
  } as const;
  
  async openUserMenu(): Promise<void> {
    await this.page.click(this.selectors.userMenu);
  }
  
  async logout(): Promise<void> {
    await this.openUserMenu();
    await this.page.click(this.selectors.logoutButton);
  }
  
  async navigateToProfile(): Promise<void> {
    await this.openUserMenu();
    await this.page.click(this.selectors.profileLink);
  }
}
```

### Test Data Management

Implement robust test data strategies:

```typescript
// Test Data Factory
class TestDataFactory {
  static createUser(overrides: Partial<User> = {}): User {
    return {
      id: faker.datatype.uuid(),
      firstName: faker.name.firstName(),
      lastName: faker.name.lastName(),
      email: faker.internet.email(),
      password: 'TestPassword123!',
      role: 'user',
      createdAt: new Date(),
      ...overrides
    };
  }
  
  static createValidRegistrationData(): RegistrationData {
    return {
      firstName: faker.name.firstName(),
      lastName: faker.name.lastName(),
      email: faker.internet.email(),
      password: 'SecurePass123!',
      confirmPassword: 'SecurePass123!',
      agreeToTerms: true
    };
  }
  
  static createInvalidEmailFormats(): string[] {
    return [
      'invalid-email',
      '@example.com',
      'user@',
      'user.example.com',
      'user@.com'
    ];
  }
}

// Test Data Fixtures
const testUsers = {
  validUser: {
    username: 'valid.user@example.com',
    password: 'ValidPass123!'
  },
  adminUser: {
    username: 'admin@example.com',
    password: 'AdminPass123!'
  },
  lockedUser: {
    username: 'locked.user@example.com',
    password: 'LockedPass123!'
  }
} as const;

// Database Seeding for Test Isolation
class DatabaseHelper {
  static async seedTestData(): Promise<void> {
    // Create test users in database
    await this.createUser(testUsers.validUser);
    await this.createUser(testUsers.adminUser);
    await this.createUser({ ...testUsers.lockedUser, status: 'locked' });
  }
  
  static async cleanupTestData(): Promise<void> {
    // Remove test data after tests
    await this.deleteUserByEmail(testUsers.validUser.username);
    await this.deleteUserByEmail(testUsers.adminUser.username);
    await this.deleteUserByEmail(testUsers.lockedUser.username);
  }
  
  private static async createUser(userData: any): Promise<void> {
    // Database insertion logic
  }
  
  private static async deleteUserByEmail(email: string): Promise<void> {
    // Database cleanup logic
  }
}

// Usage in tests
test.describe('User Authentication', () => {
  test.beforeAll(async () => {
    await DatabaseHelper.seedTestData();
  });
  
  test.afterAll(async () => {
    await DatabaseHelper.cleanupTestData();
  });
  
  test('login with valid user', async ({ page }) => {
    const loginPage = new LoginPage(page);
    await loginPage.navigate();
    await loginPage.login(testUsers.validUser.username, testUsers.validUser.password);
    
    // Verify successful login
    await expect(page).toHaveURL('/dashboard');
  });
});
```

## Selector Strategies and Element Interaction

### Robust Selector Hierarchy

Implement a selector strategy that prioritizes maintainability:

```typescript
// Selector Priority (Best to Worst)
class SelectorStrategy {
  /**
   * 1. Test-specific data attributes (Best)
   * Most stable, designed specifically for testing
   */
  static testId(id: string): string {
    return `[data-testid="${id}"]`;
  }
  
  /**
   * 2. Accessible roles and labels (Good)
   * Aligns with accessibility best practices
   */
  static role(role: string, name?: string): string {
    return name ? `role=${role}[name="${name}"]` : `role=${role}`;
  }
  
  /**
   * 3. Text content (Context-dependent)
   * Good for user-facing text, but fragile for dynamic content
   */
  static text(text: string): string {
    return `text="${text}"`;
  }
  
  /**
   * 4. CSS selectors (Use sparingly)
   * Only when above options aren't available
   */
  static css(selector: string): string {
    return selector;
  }
  
  /**
   * 5. XPath (Last resort)
   * Avoid unless absolutely necessary
   */
  static xpath(expression: string): string {
    return `xpath=${expression}`;
  }
}

// Usage in Page Objects
class FormPage extends BasePage {
  private readonly selectors = {
    // Preferred: Test-specific attributes
    emailField: SelectorStrategy.testId('email-input'),
    submitButton: SelectorStrategy.testId('submit-button'),
    
    // Alternative: Accessible selectors
    emailFieldAlt: SelectorStrategy.role('textbox', 'Email Address'),
    submitButtonAlt: SelectorStrategy.role('button', 'Submit Form'),
    
    // Fallback: Text-based selectors
    submitButtonText: SelectorStrategy.text('Submit'),
    
    // Last resort: CSS selectors
    emailFieldCss: SelectorStrategy.css('input[type="email"]')
  } as const;
}
```

### Advanced Element Interaction Patterns

```typescript
// Robust Element Interaction Helper
class ElementInteraction {
  constructor(private page: Page) {}
  
  /**
   * Safe click with retry logic
   */
  async safeClick(selector: string, options: { timeout?: number; retries?: number } = {}): Promise<void> {
    const { timeout = 10000, retries = 3 } = options;
    
    for (let attempt = 1; attempt <= retries; attempt++) {
      try {
        await this.page.waitForSelector(selector, { timeout, state: 'visible' });
        await this.page.click(selector, { timeout });
        return;
      } catch (error) {
        if (attempt === retries) {
          throw new Error(`Failed to click element "${selector}" after ${retries} attempts: ${error.message}`);
        }
        await this.page.waitForTimeout(1000); // Wait before retry
      }
    }
  }
  
  /**
   * Type text with validation
   */
  async typeAndVerify(selector: string, text: string): Promise<void> {
    await this.page.fill(selector, text);
    
    // Verify the text was entered correctly
    const actualValue = await this.page.inputValue(selector);
    if (actualValue !== text) {
      throw new Error(`Text input failed. Expected: "${text}", Actual: "${actualValue}"`);
    }
  }
  
  /**
   * Select dropdown option with fallback
   */
  async selectOption(selector: string, option: string | { label?: string; value?: string; index?: number }): Promise<void> {
    if (typeof option === 'string') {
      await this.page.selectOption(selector, option);
    } else if (option.value) {
      await this.page.selectOption(selector, { value: option.value });
    } else if (option.label) {
      await this.page.selectOption(selector, { label: option.label });
    } else if (option.index !== undefined) {
      await this.page.selectOption(selector, { index: option.index });
    }
  }
  
  /**
   * Handle dynamic content loading
   */
  async waitForDynamicContent(
    triggerSelector: string, 
    contentSelector: string, 
    expectedContent?: string
  ): Promise<void> {
    await this.page.click(triggerSelector);
    
    if (expectedContent) {
      await expect(this.page.locator(contentSelector)).toContainText(expectedContent);
    } else {
      await expect(this.page.locator(contentSelector)).toBeVisible();
    }
  }
}

// Usage in tests
test('complex form interaction', async ({ page }) => {
  const interaction = new ElementInteraction(page);
  const formPage = new FormPage(page);
  
  await formPage.navigate();
  
  // Safe interactions with retry logic
  await interaction.typeAndVerify('[data-testid="email"]', 'user@example.com');
  await interaction.selectOption('[data-testid="country"]', { label: 'United States' });
  await interaction.safeClick('[data-testid="submit"]');
  
  // Verify dynamic content loading
  await interaction.waitForDynamicContent(
    '[data-testid="load-more"]',
    '[data-testid="additional-content"]',
    'More content loaded'
  );
});
```

## Network and API Integration

### API Mocking and Stubbing

```typescript
// API Mock Manager
class ApiMockManager {
  constructor(private page: Page) {}
  
  /**
   * Mock successful API response
   */
  async mockSuccessResponse(endpoint: string, responseData: any): Promise<void> {
    await this.page.route(endpoint, route => {
      route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify(responseData)
      });
    });
  }
  
  /**
   * Mock API error response
   */
  async mockErrorResponse(endpoint: string, status: number, errorMessage: string): Promise<void> {
    await this.page.route(endpoint, route => {
      route.fulfill({
        status,
        contentType: 'application/json',
        body: JSON.stringify({ error: errorMessage })
      });
    });
  }
  
  /**
   * Mock slow API response
   */
  async mockSlowResponse(endpoint: string, delay: number, responseData: any): Promise<void> {
    await this.page.route(endpoint, async route => {
      await this.page.waitForTimeout(delay);
      route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify(responseData)
      });
    });
  }
  
  /**
   * Intercept and validate API calls
   */
  async interceptAndValidate(endpoint: string, expectedPayload: any): Promise<void> {
    await this.page.route(endpoint, route => {
      const request = route.request();
      const requestBody = JSON.parse(request.postData() || '{}');
      
      // Validate request payload
      expect(requestBody).toMatchObject(expectedPayload);
      
      // Continue with original request
      route.continue();
    });
  }
}

// Network Testing Scenarios
test.describe('API Integration Tests', () => {
  let apiMock: ApiMockManager;
  
  test.beforeEach(async ({ page }) => {
    apiMock = new ApiMockManager(page);
  });
  
  test('handles successful API response', async ({ page }) => {
    const mockUserData = { id: 1, name: 'John Doe', email: 'john@example.com' };
    
    await apiMock.mockSuccessResponse('/api/user/profile', mockUserData);
    
    await page.goto('/profile');
    
    // Verify UI displays mocked data correctly
    await expect(page.locator('[data-testid="user-name"]')).toContainText('John Doe');
    await expect(page.locator('[data-testid="user-email"]')).toContainText('john@example.com');
  });
  
  test('handles API error gracefully', async ({ page }) => {
    await apiMock.mockErrorResponse('/api/user/profile', 500, 'Internal Server Error');
    
    await page.goto('/profile');
    
    // Verify error handling
    await expect(page.locator('[data-testid="error-message"]')).toBeVisible();
    await expect(page.locator('[data-testid="error-message"]'))
      .toContainText('Unable to load profile');
  });
  
  test('shows loading state during slow API calls', async ({ page }) => {
    const mockData = { data: 'loaded' };
    
    await apiMock.mockSlowResponse('/api/dashboard-data', 3000, mockData);
    
    await page.goto('/dashboard');
    
    // Verify loading state appears
    await expect(page.locator('[data-testid="loading-spinner"]')).toBeVisible();
    
    // Verify loading state disappears after response
    await expect(page.locator('[data-testid="loading-spinner"]')).not.toBeVisible();
    await expect(page.locator('[data-testid="dashboard-content"]')).toBeVisible();
  });
});
```

## Error Handling and Debugging

### Comprehensive Error Handling

```typescript
// Test Error Handler
class TestErrorHandler {
  static async handleTestFailure(page: Page, testInfo: any): Promise<void> {
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    const screenshotPath = `screenshots/failure-${testInfo.title}-${timestamp}.png`;
    
    // Take screenshot on failure
    await page.screenshot({ 
      path: screenshotPath, 
      fullPage: true 
    });
    
    // Capture console logs
    const logs = await page.evaluate(() => {
      return (window as any).testLogs || [];
    });
    
    // Capture network activity
    const networkActivity = await page.evaluate(() => {
      return (window as any).networkRequests || [];
    });
    
    // Create failure report
    const failureReport = {
      test: testInfo.title,
      timestamp,
      screenshot: screenshotPath,
      url: page.url(),
      consoleLogs: logs,
      networkActivity,
      error: testInfo.error?.message
    };
    
    // Save failure report
    await fs.writeFileSync(
      `reports/failure-${timestamp}.json`, 
      JSON.stringify(failureReport, null, 2)
    );
  }
  
  static setupErrorCapture(page: Page): void {
    // Capture console logs
    page.on('console', msg => {
      const logs = (window as any).testLogs || [];
      logs.push({
        type: msg.type(),
        text: msg.text(),
        timestamp: new Date().toISOString()
      });
      (window as any).testLogs = logs;
    });
    
    // Capture network requests
    page.on('request', request => {
      const requests = (window as any).networkRequests || [];
      requests.push({
        url: request.url(),
        method: request.method(),
        timestamp: new Date().toISOString()
      });
      (window as any).networkRequests = requests;
    });
    
    // Capture JavaScript errors
    page.on('pageerror', error => {
      console.error('Page error:', error.message);
    });
  }
}

// Enhanced Test Structure with Error Handling
test.describe('Error Handling Tests', () => {
  test.beforeEach(async ({ page }) => {
    TestErrorHandler.setupErrorCapture(page);
  });
  
  test.afterEach(async ({ page }, testInfo) => {
    if (testInfo.status === 'failed') {
      await TestErrorHandler.handleTestFailure(page, testInfo);
    }
  });
  
  test('recovers from network failures', async ({ page }) => {
    // Simulate network failure
    await page.route('/api/data', route => route.abort('failed'));
    
    await page.goto('/data-page');
    
    // Verify error handling and retry mechanism
    await expect(page.locator('[data-testid="error-banner"]')).toBeVisible();
    await page.click('[data-testid="retry-button"]');
    
    // Remove network failure and verify recovery
    await page.unroute('/api/data');
    await page.route('/api/data', route => {
      route.fulfill({
        status: 200,
        body: JSON.stringify({ data: 'success' })
      });
    });
    
    await page.click('[data-testid="retry-button"]');
    await expect(page.locator('[data-testid="data-content"]')).toBeVisible();
  });
});
```

## Performance and Optimization

### Test Performance Optimization

```typescript
// Performance Monitor
class PerformanceMonitor {
  constructor(private page: Page) {}
  
  async measurePageLoad(url: string): Promise<PerformanceMetrics> {
    const startTime = Date.now();
    
    await this.page.goto(url, { waitUntil: 'networkidle' });
    
    const endTime = Date.now();
    const loadTime = endTime - startTime;
    
    // Get performance metrics
    const metrics = await this.page.evaluate(() => {
      const navigation = performance.getEntriesByType('navigation')[0] as PerformanceNavigationTiming;
      return {
        domContentLoaded: navigation.domContentLoadedEventEnd - navigation.domContentLoadedEventStart,
        loadComplete: navigation.loadEventEnd - navigation.loadEventStart,
        firstContentfulPaint: performance.getEntriesByName('first-contentful-paint')[0]?.startTime || 0,
        largestContentfulPaint: performance.getEntriesByName('largest-contentful-paint')[0]?.startTime || 0
      };
    });
    
    return {
      totalLoadTime: loadTime,
      ...metrics
    };
  }
  
  async measureUserInteraction(action: () => Promise<void>): Promise<number> {
    const startTime = Date.now();
    await action();
    const endTime = Date.now();
    return endTime - startTime;
  }
}

interface PerformanceMetrics {
  totalLoadTime: number;
  domContentLoaded: number;
  loadComplete: number;
  firstContentfulPaint: number;
  largestContentfulPaint: number;
}

// Performance-aware tests
test.describe('Performance Tests', () => {
  test('page load performance meets thresholds', async ({ page }) => {
    const monitor = new PerformanceMonitor(page);
    
    const metrics = await monitor.measurePageLoad('/dashboard');
    
    // Assert performance thresholds
    expect(metrics.totalLoadTime).toBeLessThan(3000); // 3 seconds
    expect(metrics.firstContentfulPaint).toBeLessThan(1500); // 1.5 seconds
    expect(metrics.largestContentfulPaint).toBeLessThan(2500); // 2.5 seconds
  });
  
  test('user interaction responsiveness', async ({ page }) => {
    const monitor = new PerformanceMonitor(page);
    
    await page.goto('/interactive-page');
    
    const interactionTime = await monitor.measureUserInteraction(async () => {
      await page.click('[data-testid="complex-button"]');
      await page.waitForSelector('[data-testid="result"]');
    });
    
    expect(interactionTime).toBeLessThan(500); // 500ms for interaction
  });
});
```

### Parallel Test Execution

```typescript
// playwright.config.ts - Optimal parallel configuration
import { defineConfig } from '@playwright/test';

export default defineConfig({
  // Run tests in parallel
  fullyParallel: true,
  
  // Number of workers
  workers: process.env.CI ? 2 : 4,
  
  // Retry failed tests
  retries: process.env.CI ? 2 : 0,
  
  // Timeout configuration
  timeout: 30000,
  expect: { timeout: 5000 },
  
  // Test isolation
  testDir: './tests',
  testIgnore: '**/node_modules/**',
  
  use: {
    // Browser context options
    actionTimeout: 0,
    navigationTimeout: 30000,
    
    // Tracing and screenshots
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
  },
  
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
    {
      name: 'firefox',
      use: { ...devices['Desktop Firefox'] },
    },
    {
      name: 'webkit',
      use: { ...devices['Desktop Safari'] },
    },
    {
      name: 'mobile-chrome',
      use: { ...devices['Pixel 5'] },
    }
  ],
});

// Test grouping for efficient execution
test.describe.configure({ mode: 'parallel' });

test.describe('Authentication Tests - Parallel', () => {
  // These tests can run in parallel
  test('login with valid credentials', async ({ page }) => {
    // Test implementation
  });
  
  test('login with invalid credentials', async ({ page }) => {
    // Test implementation
  });
  
  test('password reset workflow', async ({ page }) => {
    // Test implementation
  });
});

test.describe.configure({ mode: 'serial' });

test.describe('Data-Dependent Tests - Serial', () => {
  // These tests must run in order
  test('create user account', async ({ page }) => {
    // Creates test data
  });
  
  test('modify user account', async ({ page }) => {
    // Depends on previous test
  });
  
  test('delete user account', async ({ page }) => {
    // Cleanup - depends on previous tests
  });
});
```

## CI/CD Integration Best Practices

### GitHub Actions Configuration

```yaml
name: E2E Tests

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        browser: [chromium, firefox, webkit]
        shard: [1/4, 2/4, 3/4, 4/4]
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '18'
          cache: 'npm'
      
      - name: Install dependencies
        run: npm ci
      
      - name: Install Playwright
        run: npx playwright install --with-deps ${{ matrix.browser }}
      
      - name: Build application
        run: npm run build
      
      - name: Start application
        run: |
          npm start &
          npx wait-on http://localhost:3000 --timeout 60000
      
      - name: Run E2E tests
        run: npx playwright test --project=${{ matrix.browser }} --shard=${{ matrix.shard }}
        env:
          CI: true
      
      - name: Upload test results
        uses: actions/upload-artifact@v4
        if: failure()
        with:
          name: test-results-${{ matrix.browser }}-${{ matrix.shard }}
          path: |
            test-results/
            playwright-report/
          retention-days: 30
      
      - name: Comment PR with results
        if: github.event_name == 'pull_request'
        uses: actions/github-script@v7
        with:
          script: |
            const fs = require('fs');
            if (fs.existsSync('test-results/results.json')) {
              const results = JSON.parse(fs.readFileSync('test-results/results.json'));
              github.rest.issues.createComment({
                issue_number: context.issue.number,
                owner: context.repo.owner,
                repo: context.repo.repo,
                body: `## E2E Test Results\\n\\nPassed: ${results.passed}\\nFailed: ${results.failed}`
              });
            }
```

## Citations

1. Fowler, M. (2023). *Testing Strategies for Microservices*. Retrieved from <https://martinfowler.com/articles/microservice-testing/>
2. Microsoft. (2024). *Playwright Best Practices Documentation*. Retrieved from <https://playwright.dev/docs/best-practices>
3. Cypress.io. (2024). *Best Practices for Writing Tests*. Retrieved from <https://docs.cypress.io/guides/references/best-practices>
4. Google Web Fundamentals. (2024). *Web Performance Testing*. Retrieved from <https://web.dev/performance/>
5. W3C. (2024). *Web Content Accessibility Guidelines*. Retrieved from <https://www.w3.org/WAI/WCAG21/quickref/>
6. Mozilla. (2024). *Writing Cross-Browser Tests*. Retrieved from <https://developer.mozilla.org/en-US/docs/Learn/Tools_and_testing/Cross_browser_testing>
7. TestingBot. (2024). *Automated Testing Best Practices*. Retrieved from <https://testingbot.com/support/getting-started/automated-testing-best-practices>
8. Sauce Labs. (2024). *Continuous Testing Best Practices*. Retrieved from <https://saucelabs.com/blog/test-automation-best-practices>
