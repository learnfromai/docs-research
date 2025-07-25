# Requirements Hierarchy: User Stories → Acceptance Criteria → EARS Notation

## Understanding the Three-Tier Requirements Hierarchy

The user's intuition is correct: user stories serve as the starting point for requirements engineering, providing a foundation that progressively becomes more detailed and technical. This hierarchy ensures that business value remains clear while providing the technical detail necessary for implementation.

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   USER STORIES  │───▶│ ACCEPTANCE      │───▶│ EARS NOTATION   │
│                 │    │ CRITERIA        │    │                 │
│ Business Focus  │    │ Behavioral      │    │ Technical       │
│ User Perspective│    │ Focus           │    │ Focus           │
│ High Level      │    │ Testable        │    │ Implementation  │
│                 │    │ Conditions      │    │ Specific        │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## Tier 1: User Stories - The Foundation

### Purpose and Audience
- **Primary Audience**: Product owners, stakeholders, and business users
- **Purpose**: Capture business value and user needs in understandable terms
- **Detail Level**: High-level capability description
- **Language**: Business and user-focused terminology

### Characteristics
- Written from user perspective
- Focus on "what" and "why" rather than "how"
- Emphasize business value and user benefits
- Remain technology-agnostic
- Serve as conversation starters for detailed discussions

### Example Structure
```
As a [user role with context]
I want [clear capability]
So that [concrete business value]
```

### Quality Criteria for User Stories
- **Independent**: Can be developed separately from other stories
- **Negotiable**: Details can be discussed and refined
- **Valuable**: Provides clear business or user value
- **Estimable**: Development effort can be reasonably estimated
- **Small**: Completable within a single sprint
- **Testable**: Success can be objectively verified

## Tier 2: Acceptance Criteria - The Bridge

### Purpose and Audience
- **Primary Audience**: Developers, testers, and product owners
- **Purpose**: Define testable conditions that specify when a story is complete
- **Detail Level**: Behavioral specifications and scenarios
- **Language**: Business logic with technical considerations

### Characteristics
- Written in Given-When-Then format (BDD style)
- Focus on observable behaviors and outcomes
- Include both happy path and error scenarios
- Define boundaries and constraints
- Provide objective completion criteria

### BDD Format Structure
```
Given [initial context or preconditions]
When [specific action or event occurs]
Then [expected outcome or system response]
```

### Types of Acceptance Criteria

#### Functional Criteria
```
Given I am on the login page
When I enter valid credentials and click "Login"
Then I should be redirected to my dashboard
And I should see a welcome message with my name
```

#### Non-Functional Criteria
```
Given I am logging in during peak hours
When I submit my credentials
Then the system should authenticate me within 3 seconds
And display appropriate loading indicators
```

#### Error Handling Criteria
```
Given I am on the login page
When I enter invalid credentials and click "Login"
Then I should see an error message "Invalid email or password"
And the password field should be cleared
And I should remain on the login page
```

## Tier 3: EARS Notation - The Implementation Detail

### Purpose and Audience
- **Primary Audience**: Developers, system architects, and technical teams
- **Purpose**: Provide unambiguous, implementation-ready system requirements
- **Detail Level**: Technical specifications with precise behavior definitions
- **Language**: Technical terminology with system-focused perspective

### EARS Template Integration

#### Event-Driven Requirements (Most Common)
```
WHEN [specific trigger occurs] 
THE system SHALL [precise system response] 
[within specified constraints]
```

#### Unwanted Behavior Requirements (Error Handling)
```
IF [error condition exists]
THEN the system SHALL [error response]
[with specific recovery actions]
```

#### State-Driven Requirements (Continuous Behavior)
```
WHILE [system state persists]
THE system SHALL [ongoing behavior]
[maintaining specified conditions]
```

#### Ubiquitous Requirements (Always True)
```
The system SHALL [consistent behavior]
[across all applicable scenarios]
```

#### Optional Requirements (Conditional Features)
```
WHERE [feature is available]
THE system SHALL [conditional behavior]
[when conditions are met]
```

#### Complex Requirements (Multi-Condition)
```
IF [condition A] 
THEN WHEN [trigger B occurs]
THE system SHALL [complex response]
[with multiple coordinated actions]
```

## Practical Progression Example: Login Feature

### Starting Point (User's Original Requirement)
```
"I want to have a login feature where user can log in with email/username and password."
```

### Tier 1: User Story
```
As a returning customer
I want to log in to my account using my email and password
So that I can access my personal information and order history
```

### Tier 2: Acceptance Criteria
```
Scenario: Successful login with email
  Given I am on the login page
  When I enter a valid email address and correct password
  And I click the "Login" button
  Then I should be redirected to my account dashboard
  And I should see a personalized welcome message
  And my session should be established for 24 hours

Scenario: Successful login with username  
  Given I am on the login page
  When I enter a valid username and correct password
  And I click the "Login" button
  Then I should be redirected to my account dashboard
  And I should see a personalized welcome message

Scenario: Failed login attempt
  Given I am on the login page
  When I enter invalid credentials
  And I click the "Login" button
  Then I should see an error message "Invalid email/username or password"
  And I should remain on the login page
  And the password field should be cleared for security

Scenario: Account lockout protection
  Given I have made 4 consecutive failed login attempts
  When I make a 5th failed attempt
  Then my account should be temporarily locked for 15 minutes
  And I should see a message explaining the lockout
```

### Tier 3: EARS Notation Requirements
```
Functional Requirements:

1. WHEN a user enters valid credentials (email/username and password) and clicks "Login"
   THE system SHALL authenticate the credentials against the stored user database
   AND redirect to the user dashboard within 2 seconds

2. WHEN a user enters a valid email address as username
   THE system SHALL accept it as equivalent to the stored username
   AND process authentication normally

3. IF user credentials are invalid (email/username or password incorrect)
   THEN the system SHALL display error message "Invalid email/username or password"
   AND clear the password field
   AND increment failed attempt counter

4. IF a user makes 5 consecutive failed login attempts within 30 minutes
   THEN the system SHALL lock the account for 15 minutes
   AND display message "Account temporarily locked. Please try again in 15 minutes"
   AND log the security event

Security Requirements:

5. The system SHALL hash all passwords using bcrypt with minimum 12 rounds
   AND never store passwords in plain text

6. WHEN authentication is successful
   THE system SHALL create a secure session token
   AND set appropriate secure cookie flags (HttpOnly, Secure, SameSite)

7. WHILE a user session is active
   THE system SHALL validate the session token on each request
   AND extend session timeout with user activity

Performance Requirements:

8. The system SHALL complete authentication processing within 2 seconds
   AND display loading indicators during processing

9. WHEN the login page loads
   THE system SHALL render the form within 1 second
   AND focus on the email/username input field
```

## Hierarchy Relationship Principles

### Traceability
Each EARS requirement should trace back through acceptance criteria to a specific user story, ensuring that technical implementation serves user needs.

```yaml
Traceability_Example:
  User_Story: "Access account functionality"
  
  Acceptance_Criteria:
    - "Login with valid credentials"
    - "Handle invalid credentials gracefully"
    - "Maintain session security"
  
  EARS_Requirements:
    - "WHEN valid credentials → authenticate within 2s"
    - "IF invalid credentials → display error message"  
    - "WHILE session active → validate token on requests"
```

### Progressive Detail
Each tier adds appropriate detail without losing sight of the user value:

- **Stories**: Focus on user value and business outcomes
- **Criteria**: Add behavioral specifications and test conditions
- **EARS**: Provide technical implementation requirements

### Consistency Validation
Regular validation ensures alignment across all three tiers:

```
Validation Questions:
- Do EARS requirements fulfill all acceptance criteria?
- Do acceptance criteria fully define story completion?
- Does the story provide clear business value?
- Can we trace implementation back to user needs?
```

## Context-Specific Adaptations

### API-First Development Context

**User Story Focus:**
```
As a mobile app developer
I want to authenticate users via API
So that I can provide secure access to user data
```

**Acceptance Criteria Focus:**
```
Given I send a POST request to /api/auth/login
When the request includes valid JSON with email and password
Then I should receive a 200 status with JWT token
And the token should be valid for 24 hours
```

**EARS Requirements Focus:**
```
WHEN the API receives POST /api/auth/login with valid JSON payload
THE system SHALL validate credentials against user database
AND return HTTP 200 with JWT token in response body
AND set token expiration to 24 hours from creation time
```

### UI-First Development Context

**User Story Focus:**
```
As a website visitor
I want an intuitive login interface
So that I can quickly access my account
```

**Acceptance Criteria Focus:**
```
Given I visit the login page
When the page loads
Then I should see clearly labeled email and password fields
And the email field should be focused automatically
And I should see a prominent "Login" button
```

**EARS Requirements Focus:**
```
WHEN the login page loads
THE system SHALL display form with email and password input fields
AND apply auto-focus to the email input field
AND render the login button with primary visual styling
AND ensure form is accessible via keyboard navigation
```

### Integration Development Context

**User Story Focus:**
```
As a system administrator
I want user authentication to work across all connected applications
So that users have a seamless single sign-on experience
```

**Acceptance Criteria Focus:**
```
Given a user logs in to the main application
When they navigate to a connected sub-application
Then they should be automatically authenticated
And not need to log in again
```

**EARS Requirements Focus:**
```
WHEN a user successfully authenticates in the primary application
THE system SHALL generate a federated identity token
AND propagate authentication status to all registered sub-applications
AND maintain session synchronization across all connected systems
```

## Quality Assurance Across Tiers

### Story Quality Checklist
- [ ] Clear user role and persona defined
- [ ] Specific capability articulated  
- [ ] Concrete business value stated
- [ ] Story size appropriate for sprint
- [ ] Independent of other stories
- [ ] Estimation possible by development team

### Acceptance Criteria Quality Checklist
- [ ] All scenarios use Given-When-Then format
- [ ] Happy path scenarios included
- [ ] Error conditions addressed
- [ ] Performance expectations specified
- [ ] Security considerations included
- [ ] Objective verification possible

### EARS Requirements Quality Checklist
- [ ] Appropriate EARS template used
- [ ] Unambiguous language employed
- [ ] Measurable conditions specified
- [ ] Technical constraints included
- [ ] Integration points addressed
- [ ] Error handling detailed

## Common Pitfalls and Solutions

### Pitfall 1: Skipping Tiers
**Problem**: Going directly from user story to EARS requirements
**Solution**: Always create acceptance criteria as the bridge
**Example**: This ensures testable conditions exist before technical implementation

### Pitfall 2: Misaligned Detail Levels
**Problem**: Technical details in user stories or business language in EARS
**Solution**: Maintain appropriate abstraction at each tier
**Example**: Keep user stories business-focused, EARS technically precise

### Pitfall 3: Poor Traceability
**Problem**: EARS requirements that don't connect to user value
**Solution**: Regular validation sessions to ensure alignment
**Example**: Every EARS requirement should trace to acceptance criteria and user stories

### Pitfall 4: Over-Engineering Simple Features
**Problem**: Complex EARS for straightforward functionality
**Solution**: Scale detail to feature complexity
**Example**: Simple display features need fewer EARS requirements than complex workflows

## Navigation

← [User Stories Fundamentals](user-stories-fundamentals.md) | [Implementation Guide →](implementation-guide.md)

---

*Requirements hierarchy guide demonstrating the progressive refinement from user-focused stories through testable acceptance criteria to detailed technical EARS notation requirements.*