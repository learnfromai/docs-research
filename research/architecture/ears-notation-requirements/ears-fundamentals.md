# EARS Fundamentals

## Introduction to EARS Notation

EARS (Easy Approach to Requirements Syntax) is a structured notation system developed by Alistair Mavin and his colleagues at Rolls-Royce to address common problems in requirements engineering. The approach provides six fundamental templates that help authors write clear, unambiguous, and testable requirements.

## The Problem EARS Solves

### Common Requirements Issues
- **Ambiguity**: Requirements that can be interpreted in multiple ways
- **Incompleteness**: Missing essential information or conditions
- **Untestability**: Requirements that cannot be verified objectively
- **Inconsistency**: Requirements that contradict each other
- **Complexity**: Overly complex sentences that obscure meaning

### Traditional vs. EARS Approach

**Traditional Requirement:**
```
The system should handle user authentication efficiently and securely.
```
*Issues: What does "efficiently" mean? What constitutes "securely"? When does this apply?*

**EARS Requirement:**
```
WHEN a user submits valid login credentials,
the system shall authenticate the user within 2 seconds
AND grant access to the authorized areas of the application.

IF a user submits invalid login credentials,
THEN the system shall display an error message
AND log the failed attempt for security monitoring.
```

## The Six EARS Templates

### 1. Ubiquitous Requirements
**Pattern**: `The system shall [requirement]`

**Purpose**: For requirements that apply universally, without specific conditions or triggers.

**Examples**:
```
The system shall encrypt all stored user passwords using SHA-256 hashing.
The system shall maintain a backup of all transaction data.
The system shall support concurrent access by up to 1000 users.
```

**When to Use**:
- System-wide constraints or capabilities
- Non-functional requirements (performance, security, reliability)
- Basic functional capabilities that always apply

### 2. Event-driven Requirements
**Pattern**: `WHEN [trigger] the system shall [response]`

**Purpose**: For requirements that specify system behavior in response to specific events or conditions.

**Examples**:
```
WHEN a user clicks the "Save" button, the system shall store the form data to the database.
WHEN the system detects disk usage above 90%, the system shall send an alert to administrators.
WHEN a new user registers, the system shall send a welcome email within 5 minutes.
```

**When to Use**:
- User-initiated actions
- System-generated events
- Time-based triggers
- External system interactions

### 3. Unwanted Behavior Requirements
**Pattern**: `IF [condition] THEN the system shall [response]`

**Purpose**: For specifying how the system should handle error conditions, edge cases, or exceptional situations.

**Examples**:
```
IF a user enters an invalid email format, THEN the system shall display a validation error message.
IF the database connection is lost, THEN the system shall retry the connection every 30 seconds.
IF a user attempts to access restricted content, THEN the system shall redirect to the login page.
```

**When to Use**:
- Error handling scenarios
- Security violations
- Resource constraints
- Invalid input conditions

### 4. State-driven Requirements
**Pattern**: `WHILE [state] the system shall [requirement]`

**Purpose**: For requirements that apply continuously during specific system states or conditions.

**Examples**:
```
WHILE a user session is active, the system shall refresh the authentication token every 15 minutes.
WHILE the system is in maintenance mode, the system shall display a maintenance message to all users.
WHILE a backup is in progress, the system shall disable write operations to the database.
```

**When to Use**:
- Continuous monitoring requirements
- State-dependent behaviors
- Resource management during specific conditions
- Background processes

### 5. Optional Requirements
**Pattern**: `WHERE [feature] is available, the system shall [requirement]`

**Purpose**: For requirements that apply only when certain features, configurations, or capabilities are present.

**Examples**:
```
WHERE two-factor authentication is enabled, the system shall require SMS verification for login.
WHERE the premium subscription is active, the system shall provide access to advanced analytics.
WHERE GPS capability is available, the system shall record location data for delivery tracking.
```

**When to Use**:
- Feature-dependent functionality
- Configuration-based requirements
- Hardware-dependent capabilities
- Subscription or license-based features

### 6. Complex Requirements
**Pattern**: `IF [condition] THEN WHEN [trigger] the system shall [response]`

**Purpose**: For requirements involving multiple conditions and triggers, combining conditional logic with event-driven responses.

**Examples**:
```
IF the user has administrative privileges, THEN WHEN the user selects "Delete All", 
the system shall require additional confirmation before proceeding.

IF the system is operating in high-security mode, THEN WHEN a user attempts to download files, 
the system shall scan for malware before allowing the download.

IF the account balance is below $10, THEN WHEN a user attempts a transaction, 
the system shall decline the transaction and notify the user of insufficient funds.
```

**When to Use**:
- Multi-step conditional logic
- Security-sensitive operations
- Complex business rules
- Cascading system behaviors

## EARS Syntax Rules and Guidelines

### Core Principles

1. **One Requirement Per Statement**: Each EARS requirement should express a single, testable behavior
2. **Active Voice**: Use active voice with the system as the subject
3. **Measurable Outcomes**: Include specific, measurable criteria when possible
4. **Clear Triggers**: Precisely define when, where, and under what conditions requirements apply
5. **Consistent Terminology**: Use standardized terms throughout all requirements

### Syntax Guidelines

#### Subject Consistency
- Always use "the system" as the subject (or specify the specific component)
- Avoid passive voice constructions
- Be specific about which part of the system is responsible

```
✅ Good: "The authentication module shall validate user credentials"
❌ Poor: "User credentials should be validated"
```

#### Action Verbs
- Use "shall" for mandatory requirements
- Use "should" for recommendations (sparingly)
- Avoid weak verbs like "support," "handle," or "manage"

```
✅ Good: "The system shall encrypt data using AES-256"
❌ Poor: "The system should handle data encryption"
```

#### Quantifiable Criteria
- Include specific numbers, timeframes, or measurable outcomes
- Define performance criteria clearly
- Specify error rates, response times, and capacity limits

```
✅ Good: "WHEN a user submits a search query, the system shall return results within 3 seconds"
❌ Poor: "The system shall provide fast search results"
```

## Quality Attributes Integration

### Non-Functional Requirements with EARS

**Performance**:
```
The system shall process payment transactions within 5 seconds under normal load conditions.
WHEN system load exceeds 80% capacity, the system shall maintain response times under 10 seconds.
```

**Security**:
```
The system shall require HTTPS for all client-server communications.
IF a user fails authentication 3 times, THEN the system shall lock the account for 15 minutes.
```

**Reliability**:
```
The system shall maintain 99.9% uptime during business hours.
WHEN a server fails, the system shall automatically failover to backup servers within 30 seconds.
```

**Usability**:
```
WHEN a user hovers over an interactive element, the system shall provide visual feedback within 100ms.
IF a user remains inactive for 30 minutes, THEN the system shall display a session timeout warning.
```

## Common Patterns and Anti-Patterns

### Effective EARS Patterns

**Cascading Requirements**:
```
WHEN a user initiates checkout, the system shall validate the shopping cart contents.
IF any items are out of stock, THEN the system shall notify the user and update the cart.
WHEN cart validation is complete, the system shall proceed to payment processing.
```

**Error Recovery Chains**:
```
IF a payment transaction fails, THEN the system shall retry the transaction once after 5 seconds.
IF the retry also fails, THEN the system shall log the error and notify the user.
WHEN the user acknowledges the error, the system shall return to the payment selection screen.
```

### Anti-Patterns to Avoid

**Vague Triggers**:
```
❌ Poor: "WHEN appropriate, the system shall send notifications"
✅ Good: "WHEN a user's subscription expires within 7 days, the system shall send a renewal notification"
```

**Multiple Requirements in One Statement**:
```
❌ Poor: "The system shall validate input and store data and send confirmations"
✅ Good: Three separate EARS requirements for validation, storage, and confirmation
```

**Ambiguous Conditions**:
```
❌ Poor: "IF there are problems, THEN the system shall handle them appropriately"
✅ Good: "IF the database response time exceeds 10 seconds, THEN the system shall display a timeout message"
```

## Integration with Development Practices

### Test-Driven Development
EARS requirements naturally support TDD by providing clear, testable conditions:

```
Requirement: WHEN a user submits a valid registration form, 
the system shall create a new user account and send a confirmation email.

Test Cases:
- Given a valid registration form, when submitted, then user account is created
- Given a valid registration form, when submitted, then confirmation email is sent
- Given an invalid registration form, when submitted, then no account is created
```

### Behavior-Driven Development (BDD)
EARS templates align well with Gherkin syntax:

```
EARS: WHEN a user logs in with valid credentials, the system shall redirect to the dashboard.

Gherkin:
Scenario: Successful login
  Given a user with valid credentials
  When the user logs in
  Then the system redirects to the dashboard
```

### Agile User Stories
EARS requirements complement user stories by providing technical precision:

```
User Story: As a customer, I want to track my order so that I know when to expect delivery.

EARS Requirements:
- WHEN a customer enters a valid order number, the system shall display current order status.
- IF an order number is invalid, THEN the system shall display an error message.
- WHILE an order is in transit, the system shall update the tracking information every 4 hours.
```

## Tools and Validation

### Automated Syntax Checking
Regular expressions for basic EARS template validation:

```regex
Ubiquitous: ^The system shall .+$
Event-driven: ^WHEN .+ the system shall .+$
Unwanted Behavior: ^IF .+ THEN the system shall .+$
State-driven: ^WHILE .+ the system shall .+$
Optional: ^WHERE .+ the system shall .+$
Complex: ^IF .+ THEN WHEN .+ the system shall .+$
```

### Quality Metrics
- **Template Coverage**: Percentage of requirements using EARS templates
- **Ambiguity Score**: Number of ambiguous terms per requirement
- **Testability Index**: Percentage of requirements with measurable criteria
- **Completeness Ratio**: Requirements covering all identified scenarios

## Navigation

← [Executive Summary](executive-summary.md) | [Implementation Guide →](implementation-guide.md)

---

*EARS fundamentals based on original research by Mavin et al. and practical implementations across multiple industries and organizations.*