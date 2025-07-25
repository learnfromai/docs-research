# Practical Examples: Login and Registration Requirements Conversion

## Original Requirements Analysis

The user provided two high-level requirements that need conversion into properly structured user stories, acceptance criteria, and EARS notation:

### Original Requirement 1
```
"I want to have a login feature where user can log in with email/username and password."
```

### Original Requirement 2  
```
"I want to have a register feature where user can create new account with first name, last name, email and password, and the username is by default the username of the email so it won't be included in the register form."
```

## Converted Requirements Structure

### Epic Level Organization
```yaml
Epic: User Authentication System
Description: Complete user authentication functionality including account creation and login
Business_Value: Enable secure user access and account management
Estimated_Effort: 15-20 story points across 2-3 sprints

Components:
  - User Registration Functionality
  - User Login Functionality  
  - Account Management Features
  - Security and Validation Features
```

## User Registration Feature Conversion

### User Story 1: Account Creation
```markdown
As a new website visitor
I want to create an account with my personal information
So that I can access personalized features and services

Story Points: 5
Priority: High
Epic: User Authentication System
```

### Acceptance Criteria - Registration
```gherkin
Scenario: Successful account registration
  Given I am on the registration page
  When I enter valid first name, last name, email, and password
  And I click the "Create Account" button
  Then my account should be created successfully
  And my username should be automatically set to the part before @ in my email
  And I should receive a confirmation email
  And I should be redirected to a welcome page

Scenario: Registration with existing email
  Given I am on the registration page
  When I enter an email address that already exists in the system
  And I complete the rest of the form
  And I click "Create Account"
  Then I should see an error message "An account with this email already exists"
  And I should be given the option to log in instead
  And my form data should be preserved except for the password

Scenario: Registration with invalid email format
  Given I am on the registration page
  When I enter an invalid email format (missing @, domain, etc.)
  And I complete the rest of the form
  And I click "Create Account"
  Then I should see an error message "Please enter a valid email address"
  And the form should not be submitted
  And the email field should be highlighted

Scenario: Registration with weak password
  Given I am on the registration page
  When I enter a password that doesn't meet security requirements
  And I complete the rest of the form
  And I click "Create Account"
  Then I should see specific password requirements
  And examples of what makes a strong password
  And the form should not be submitted until requirements are met

Scenario: Registration form validation
  Given I am on the registration page
  When I attempt to submit the form with missing required fields
  Then all missing fields should be highlighted in red
  And specific error messages should appear for each missing field
  And the form should not be submitted
  And I should remain on the registration page
```

### EARS Notation - Registration Requirements

#### Core Registration Functionality
```
1. WHEN a user submits the registration form with valid first name, last name, email, and password
   THE system SHALL create a new user account in the database
   AND generate a unique user ID
   AND set the username to the local part of the email address (before @)
   AND hash the password using bcrypt with minimum 12 rounds

2. WHEN a new account is successfully created
   THE system SHALL send a welcome email to the registered email address
   AND redirect the user to a welcome/confirmation page
   AND log the registration event with timestamp

3. WHEN the system generates a username from email
   THE system SHALL extract the portion before the @ symbol
   AND validate that the resulting username is unique
   AND append a numeric suffix if the username already exists

4. The system SHALL require all registration fields (first name, last name, email, password)
   AND validate each field according to specified criteria
   AND prevent form submission if any validation fails
```

#### Validation Requirements
```
5. IF a user attempts to register with an email that already exists
   THEN the system SHALL display error message "An account with this email already exists"
   AND offer a "Sign In Instead" link
   AND preserve all form data except the password field

6. IF a user enters an invalid email format
   THEN the system SHALL display error message "Please enter a valid email address"
   AND highlight the email field with red border
   AND prevent form submission until corrected

7. IF a user enters a password that doesn't meet security requirements
   THEN the system SHALL display specific password requirements
   AND show real-time validation feedback as user types
   AND prevent form submission until requirements are met

8. The system SHALL validate password requirements:
   - Minimum 8 characters length
   - At least one uppercase letter
   - At least one lowercase letter  
   - At least one number
   - At least one special character
```

#### Security Requirements
```
9. WHEN processing registration data
   THE system SHALL sanitize all input fields
   AND validate against SQL injection attempts
   AND validate against XSS attacks

10. The system SHALL never store passwords in plain text
    AND SHALL hash all passwords using bcrypt with salt
    AND SHALL clear password from memory after processing

11. WHEN a registration attempt fails due to validation errors
    THE system SHALL log the attempt (without password data)
    AND implement rate limiting for repeated failed attempts from same IP
```

## User Login Feature Conversion

### User Story 2: User Authentication
```markdown
As a returning user
I want to log in to my account using my email/username and password
So that I can access my personalized account features and data

Story Points: 3
Priority: High
Epic: User Authentication System
Dependencies: User Registration (for test accounts)
```

### Acceptance Criteria - Login
```gherkin
Scenario: Successful login with email
  Given I have a registered account
  And I am on the login page
  When I enter my email address and correct password
  And I click the "Login" button
  Then I should be authenticated successfully
  And I should be redirected to my account dashboard
  And I should see a personalized welcome message
  And my session should be active for 24 hours

Scenario: Successful login with username
  Given I have a registered account
  And I am on the login page
  When I enter my username (generated from email) and correct password
  And I click the "Login" button
  Then I should be authenticated successfully
  And I should be redirected to my account dashboard

Scenario: Failed login with incorrect password
  Given I have a registered account
  And I am on the login page
  When I enter my correct email/username but incorrect password
  And I click the "Login" button
  Then I should see an error message "Invalid email/username or password"
  And I should remain on the login page
  And the password field should be cleared
  And a failed login attempt should be recorded

Scenario: Failed login with non-existent account
  Given I am on the login page
  When I enter an email/username that doesn't exist in the system
  And I enter any password
  And I click the "Login" button
  Then I should see an error message "Invalid email/username or password"
  And I should be given an option to create an account
  And no sensitive information should be revealed about account existence

Scenario: Account lockout after multiple failed attempts
  Given I have made 4 consecutive failed login attempts
  When I make a 5th failed login attempt
  Then my account should be temporarily locked for 15 minutes
  And I should see a message "Account temporarily locked. Please try again in 15 minutes."
  And I should be given information about password reset options

Scenario: Login form usability
  Given I am on the login page
  When the page loads
  Then the email/username field should be automatically focused
  And I should be able to navigate the form using Tab key
  And I should be able to submit the form by pressing Enter
  And password field should show/hide toggle option
```

### EARS Notation - Login Requirements

#### Core Authentication Functionality
```
1. WHEN a user enters valid credentials (email or username and password) and clicks "Login"
   THE system SHALL authenticate the credentials against the stored user database
   AND compare the entered password against the stored hash using bcrypt
   AND redirect to the user dashboard within 2 seconds upon success

2. WHEN a user enters their email address as the login identifier
   THE system SHALL accept it as equivalent to their stored username
   AND process authentication using the same validation logic

3. WHEN authentication is successful
   THE system SHALL create a secure session token
   AND set session cookie with appropriate security flags (HttpOnly, Secure, SameSite)
   AND set session expiration to 24 hours from login time
   AND record successful login event with timestamp

4. WHEN the login page loads
   THE system SHALL render the form within 1 second
   AND automatically focus the email/username input field
   AND enable form submission via Enter key press
```

#### Error Handling and Security
```
5. IF user credentials are invalid (email/username not found or password incorrect)
   THEN the system SHALL display generic error message "Invalid email/username or password"
   AND clear the password field for security
   AND increment the failed attempt counter for the IP address
   AND log the failed attempt (without password data)

6. IF a user makes 5 consecutive failed login attempts within 30 minutes
   THEN the system SHALL temporarily lock the account for 15 minutes
   AND display message "Account temporarily locked. Please try again in 15 minutes"
   AND provide password reset link
   AND log the security event for review

7. IF an account lockout occurs
   THEN the system SHALL send email notification to the account owner
   AND include information about when the lockout will expire
   AND provide secure password reset link if needed

8. The system SHALL rate limit login attempts by IP address
   AND block IP addresses with excessive failed attempts
   AND implement CAPTCHA after 3 failed attempts from same IP
```

#### Session Management
```
9. WHILE a user session is active
   THE system SHALL validate the session token on each authenticated request
   AND extend session timeout with user activity (sliding window)
   AND maintain session data securely in server-side storage

10. WHEN a session expires or user logs out
    THE system SHALL invalidate the session token
    AND clear session cookies
    AND redirect to login page if accessing protected resources

11. WHERE multiple sessions are detected for the same user
    THE system SHALL allow concurrent sessions by default
    AND provide option for users to view and manage active sessions
```

## Context-Specific Implementation Variations

### API-First Development Context

For teams building the backend API first, the stories focus on endpoints and data handling:

#### API-Focused User Story - Registration
```markdown
As a frontend developer
I want a user registration API endpoint
So that I can create user accounts from any client application

Acceptance Criteria:
- POST /api/auth/register accepts JSON with firstName, lastName, email, password
- Returns 201 status with user data (excluding password) on success
- Returns 400 status with validation errors on invalid input
- Returns 409 status if email already exists
- Automatically generates username from email local part
```

#### API-Focused EARS Requirements
```
WHEN the API receives POST /api/auth/register with valid JSON payload
THE system SHALL validate all required fields (firstName, lastName, email, password)
AND return HTTP 400 with field-specific error messages if validation fails
AND return HTTP 409 with message "Email already exists" if email is taken
AND return HTTP 201 with user object (excluding password hash) on successful creation

WHEN generating username from email
THE system SHALL extract the local part (before @) from email address
AND ensure username uniqueness by appending numeric suffix if needed
AND include the generated username in the API response
```

### UI-First Development Context

For teams building the user interface first, stories emphasize user experience:

#### UI-Focused User Story - Login
```markdown
As a website visitor
I want an intuitive and accessible login interface
So that I can quickly and easily access my account

Acceptance Criteria:
- Clean, professional login form design
- Clear field labels and helpful placeholder text
- Real-time validation feedback
- Accessible via keyboard navigation
- Responsive design for mobile devices
- Loading states during authentication
```

#### UI-Focused EARS Requirements
```
WHEN the login form is displayed
THE system SHALL render input fields with clear labels and helpful placeholders
AND apply focus to the email/username field automatically
AND ensure all form elements are accessible via keyboard Tab navigation
AND provide sufficient color contrast for accessibility compliance

WHEN a user interacts with form fields
THE system SHALL provide real-time validation feedback
AND display field-specific error messages below each field
AND use appropriate ARIA labels for screen reader compatibility

WHEN form submission is in progress
THE system SHALL display loading spinner or progress indicator
AND disable the submit button to prevent double submission
AND provide clear feedback about the authentication process
```

### Integration Development Context

For teams working on system integration, stories focus on cross-system compatibility:

#### Integration-Focused User Story
```markdown
As a system administrator
I want user authentication to integrate with our existing identity management system
So that users can use single sign-on across all company applications

Acceptance Criteria:
- Login authentication checks both local database and LDAP
- User registration syncs with corporate directory
- Session tokens work across all integrated applications
- Failed authentication attempts are logged in central security system
```

#### Integration-Focused EARS Requirements
```
WHEN a user attempts to log in
THE system SHALL first check credentials against the local user database
AND if local authentication fails, SHALL attempt LDAP authentication
AND if LDAP succeeds, SHALL create or update local user record
AND SHALL generate federated session token valid across all integrated systems

WHEN user registration occurs
THE system SHALL create local user account
AND attempt to sync user data with corporate LDAP directory
AND handle LDAP sync failures gracefully without blocking registration
AND log integration events for monitoring and troubleshooting
```

## Quality Validation Checklist

### Story Quality Validation
- [ ] Each story follows "As a [role], I want [capability], So that [value]" format
- [ ] User roles are specific and realistic (not generic "user")
- [ ] Capabilities are clear and actionable
- [ ] Business value is concrete and measurable
- [ ] Stories are appropriately sized for sprint completion
- [ ] Dependencies between stories are clearly identified

### Acceptance Criteria Quality Validation
- [ ] All scenarios use Given-When-Then format consistently
- [ ] Happy path scenarios are comprehensive
- [ ] Error conditions and edge cases are covered
- [ ] Performance expectations are specified where relevant
- [ ] Security considerations are included
- [ ] Accessibility requirements are addressed

### EARS Requirements Quality Validation
- [ ] Appropriate EARS templates are used (WHEN, IF, WHILE, etc.)
- [ ] Language is unambiguous and technically precise
- [ ] Measurable conditions and constraints are specified
- [ ] Error handling is detailed and comprehensive
- [ ] Security requirements are explicitly stated
- [ ] Integration points and dependencies are addressed

## Testing Strategy Alignment

### Unit Testing Focus (from EARS Requirements)
```javascript
// Example unit tests derived from EARS requirements
describe('User Registration', () => {
  test('should generate username from email local part', () => {
    const email = 'john.doe@example.com';
    const username = generateUsernameFromEmail(email);
    expect(username).toBe('john.doe');
  });

  test('should hash password with bcrypt', () => {
    const password = 'securePassword123!';
    const hash = hashPassword(password);
    expect(bcrypt.compareSync(password, hash)).toBe(true);
  });

  test('should validate email format', () => {
    expect(validateEmail('valid@example.com')).toBe(true);
    expect(validateEmail('invalid-email')).toBe(false);
  });
});
```

### Integration Testing Focus (from Acceptance Criteria)
```javascript
// Example integration tests derived from acceptance criteria
describe('Login Flow Integration', () => {
  test('successful login redirects to dashboard', async () => {
    const response = await request(app)
      .post('/api/auth/login')
      .send({ email: 'test@example.com', password: 'password123' });
    
    expect(response.status).toBe(200);
    expect(response.body.redirectUrl).toBe('/dashboard');
  });

  test('failed login returns appropriate error', async () => {
    const response = await request(app)
      .post('/api/auth/login')
      .send({ email: 'test@example.com', password: 'wrongpassword' });
    
    expect(response.status).toBe(401);
    expect(response.body.error).toBe('Invalid email/username or password');
  });
});
```

### End-to-End Testing Focus (from User Stories)
```javascript
// Example E2E tests derived from user stories
describe('User Authentication E2E', () => {
  test('new user can register and login successfully', async () => {
    // Navigate to registration
    await page.goto('/register');
    
    // Fill registration form
    await page.fill('#firstName', 'John');
    await page.fill('#lastName', 'Doe');
    await page.fill('#email', 'john.doe@example.com');
    await page.fill('#password', 'SecurePass123!');
    
    // Submit registration
    await page.click('#registerButton');
    
    // Verify redirect to welcome page
    await expect(page).toHaveURL('/welcome');
    
    // Navigate to login
    await page.goto('/login');
    
    // Login with created account
    await page.fill('#email', 'john.doe@example.com');
    await page.fill('#password', 'SecurePass123!');
    await page.click('#loginButton');
    
    // Verify successful login and dashboard access
    await expect(page).toHaveURL('/dashboard');
    await expect(page.locator('#welcomeMessage')).toContainText('Welcome, John');
  });
});
```

## Navigation

← [Requirements Hierarchy](requirements-hierarchy.md) | [Context-Specific Approaches →](context-specific-approaches.md)

---

*Practical conversion examples demonstrating the transformation of high-level requirements into structured user stories, acceptance criteria, and EARS notation requirements for login and registration functionality.*