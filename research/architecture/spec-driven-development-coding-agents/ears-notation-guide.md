# EARS Notation Guide: Easy Approach to Requirements Syntax

## 📋 Overview

EARS (Easy Approach to Requirements Syntax) is a structured format for writing clear, testable requirements that eliminates ambiguity and ensures every requirement can be directly translated into test cases. Developed for systems engineering, EARS has been adopted by AWS Kiro and other spec-driven development methodologies.

## 🎯 Core EARS Pattern

The fundamental EARS structure follows this pattern:

```text
WHEN [condition/event/trigger]
THE SYSTEM SHALL [expected behavior/response]
```

### Key Components

**WHEN Clause** - Defines the trigger condition
- Specific trigger event or system state
- User actions or external inputs
- Time-based conditions or scheduled events
- Error conditions or boundary cases

**THE SYSTEM SHALL Clause** - Defines expected behavior
- Observable system response
- Measurable outcomes
- Clear success criteria
- Specific error handling

## 📝 EARS Requirements Categories

### 1. Event-Driven Requirements

**Format**: `WHEN [event occurs] THE SYSTEM SHALL [response]`

**Examples:**
```text
WHEN a user clicks the "Submit" button
THE SYSTEM SHALL validate the form data and display any errors

WHEN a payment is processed successfully  
THE SYSTEM SHALL send a confirmation email to the user

WHEN the system detects invalid input
THE SYSTEM SHALL display an error message and retain the user's input
```

### 2. State-Based Requirements

**Format**: `WHEN [system is in state] THE SYSTEM SHALL [behavior]`

**Examples:**
```text
WHEN the user is not authenticated
THE SYSTEM SHALL redirect to the login page

WHEN the shopping cart contains items
THE SYSTEM SHALL display the checkout button

WHEN the database connection fails
THE SYSTEM SHALL retry the connection up to 3 times
```

### 3. Feature-Based Requirements

**Format**: `THE SYSTEM SHALL [capability] WHEN [condition]`

**Examples:**
```text
THE SYSTEM SHALL allow users to reset their password
WHEN they provide a valid email address

THE SYSTEM SHALL save draft messages automatically
WHEN the user has been typing for more than 30 seconds

THE SYSTEM SHALL display search results in less than 2 seconds
WHEN the search query contains fewer than 50 characters
```

### 4. Constraint Requirements

**Format**: `THE SYSTEM SHALL [maintain constraint] [condition]`

**Examples:**
```text
THE SYSTEM SHALL ensure password complexity requirements
WHEN users create or update passwords

THE SYSTEM SHALL maintain data consistency
WHEN multiple users edit the same document simultaneously

THE SYSTEM SHALL prevent duplicate email addresses
WHEN new users register for accounts
```

### 5. Performance Requirements

**Format**: `THE SYSTEM SHALL [performance criteria] WHEN [load condition]`

**Examples:**
```text
THE SYSTEM SHALL respond to API requests within 200ms
WHEN handling fewer than 1000 concurrent users

THE SYSTEM SHALL process file uploads of up to 10MB
WHEN users are on a premium plan

THE SYSTEM SHALL maintain 99.9% uptime
WHEN operating under normal load conditions
```

## ✅ EARS Best Practices

### Writing Effective WHEN Clauses

**Be Specific About Triggers**
- ❌ `WHEN the user wants to save`
- ✅ `WHEN the user clicks the "Save" button`

**Include All Relevant Context**
- ❌ `WHEN data is invalid`
- ✅ `WHEN the email field contains an invalid email format`

**Cover Edge Cases**
- ❌ `WHEN the user logs in`
- ✅ `WHEN the user enters correct credentials after 2 failed attempts`

### Writing Effective SHALL Clauses

**Use Measurable Outcomes**
- ❌ `THE SYSTEM SHALL work properly`
- ✅ `THE SYSTEM SHALL return results within 2 seconds`

**Be Precise About Behavior**
- ❌ `THE SYSTEM SHALL handle errors`
- ✅ `THE SYSTEM SHALL display a user-friendly error message and log the technical error`

**Include Success Criteria**
- ❌ `THE SYSTEM SHALL save data`
- ✅ `THE SYSTEM SHALL save data to the database and display a success confirmation`

## 🔄 Converting User Stories to EARS

### Traditional User Story Format

```text
As a registered user
I want to update my profile information
So that my account details are current
```

### EARS Conversion Process

**Step 1: Identify Actions and Triggers**
- User action: "update profile information"
- Trigger: Form submission, field changes, save button

**Step 2: Define System Responses**  
- Validation of input data
- Database updates
- User feedback
- Error handling

**Step 3: Write EARS Requirements**

```text
### Profile Update Feature

WHEN a user modifies profile fields and clicks "Save Changes"
THE SYSTEM SHALL validate all input fields and highlight any errors

WHEN all profile data is valid and the user clicks "Save Changes"  
THE SYSTEM SHALL update the database and display "Profile updated successfully"

WHEN the user enters an invalid email format
THE SYSTEM SHALL display "Please enter a valid email address" below the email field

WHEN the database update fails
THE SYSTEM SHALL display "Unable to save changes. Please try again." and retain the user's input

WHEN the user navigates away from unsaved changes
THE SYSTEM SHALL prompt "You have unsaved changes. Do you want to save before leaving?"
```

## 🧪 EARS to Test Cases Translation

### Requirement Example
```text
WHEN a user enters an incorrect password 3 times consecutively
THE SYSTEM SHALL lock the account for 15 minutes and display a lockout message
```

### Generated Test Cases

**Test Case 1: Account Lockout Trigger**
- **Setup**: Valid user account, no previous failed attempts
- **Action**: Enter incorrect password 3 times in succession
- **Expected**: Account locked, lockout message displayed
- **Verify**: User cannot login even with correct password

**Test Case 2: Lockout Duration**
- **Setup**: Account locked from previous test
- **Action**: Wait 15 minutes, then attempt login with correct password
- **Expected**: Login succeeds, account unlocked
- **Verify**: User can access their account normally

**Test Case 3: Lockout Message Content**
- **Setup**: Account about to be locked (2 failed attempts)
- **Action**: Enter incorrect password
- **Expected**: Message displays lockout information
- **Verify**: Message includes duration and next steps

## 📊 EARS Quality Checklist

### Requirement Completeness

**✅ Trigger Clarity**
- [ ] The WHEN clause specifies exact trigger conditions
- [ ] All relevant context is included
- [ ] Edge cases are covered with separate requirements

**✅ Response Specification** 
- [ ] The SHALL clause defines observable behavior
- [ ] Success criteria are measurable
- [ ] Error conditions are handled

**✅ Testability**
- [ ] Requirement can be directly converted to test case
- [ ] Pass/fail criteria are unambiguous
- [ ] All scenarios can be automated

### Common EARS Anti-Patterns

**Vague Triggers**
- ❌ `WHEN the user wants to...`
- ❌ `WHEN the system needs to...` 
- ❌ `WHEN it's appropriate to...`

**Ambiguous Responses**
- ❌ `THE SYSTEM SHALL work correctly`
- ❌ `THE SYSTEM SHALL be user-friendly`
- ❌ `THE SYSTEM SHALL perform well`

**Missing Error Cases**
- ❌ Only happy path covered
- ❌ No network failure scenarios
- ❌ No validation error handling

## 🔧 EARS in Practice: Complete Example

### Feature: User Registration System

```markdown
# User Registration Requirements

## Registration Form Validation

WHEN a user submits the registration form with all required fields completed
THE SYSTEM SHALL create a new user account and redirect to the welcome page

WHEN a user submits the registration form with missing required fields
THE SYSTEM SHALL display "This field is required" below each empty required field

WHEN a user enters an email that is already registered
THE SYSTEM SHALL display "This email address is already in use" below the email field

WHEN a user enters a password shorter than 8 characters
THE SYSTEM SHALL display "Password must be at least 8 characters long" below the password field

WHEN a user enters a password without uppercase, lowercase, number, and special character
THE SYSTEM SHALL display "Password must contain uppercase, lowercase, number, and special character"

## Email Verification

WHEN a new user account is created successfully
THE SYSTEM SHALL send a verification email to the provided email address

WHEN a user clicks the verification link in their email
THE SYSTEM SHALL mark the account as verified and display "Email verified successfully"

WHEN a user clicks an expired verification link (older than 24 hours)
THE SYSTEM SHALL display "Verification link expired" and offer to resend verification email

WHEN a user attempts to login with an unverified email address
THE SYSTEM SHALL display "Please verify your email address" and provide option to resend verification

## Security Requirements

WHEN a user registers with a common password (from known password lists)
THE SYSTEM SHALL display "This password is too common. Please choose a stronger password"

WHEN more than 5 registration attempts are made from the same IP address within 1 hour
THE SYSTEM SHALL temporarily block registration attempts from that IP for 15 minutes

WHEN a user successfully registers
THE SYSTEM SHALL log the registration event with timestamp and IP address for security monitoring
```

## 🔗 Integration with Coding Agents

### Claude Code Integration

**Requirements Analysis Phase:**
```text
Analyze this feature request and convert it to EARS notation:
"Users should be able to search for products and see results quickly"

Output format:
- Identify all user actions and system states
- Define measurable success criteria  
- Include error conditions and edge cases
- Write complete EARS requirements
```

**Example Claude Prompt:**
```text
Convert this user story to EARS notation:

"As a customer, I want to filter search results by price range so that I can find products within my budget"

Requirements:
1. Use proper EARS format (WHEN/THE SYSTEM SHALL)
2. Cover happy path, error cases, and edge cases
3. Include specific, measurable criteria
4. Make each requirement testable
```

### GitHub Copilot Integration

**From EARS to Implementation:**
```text
Given this EARS requirement:

"WHEN a user enters a search query and applies price filters
THE SYSTEM SHALL return filtered results within 2 seconds"

Generate:
1. API endpoint specification
2. Database query optimization
3. Unit test cases
4. Performance test scenarios
```

## 📈 EARS Success Metrics

### Quality Indicators

**Clarity Score**
- 100% of requirements use proper EARS format
- 0% ambiguous or vague language
- All requirements are independently understandable

**Testability Score**  
- 100% of requirements can be converted to automated tests
- All pass/fail criteria are measurable
- No subjective acceptance criteria

**Completeness Score**
- Happy path scenarios covered
- Error conditions specified
- Edge cases identified and handled
- Non-functional requirements included

### Implementation Benefits

**Reduced Clarification Requests**
- Target: <5% of requirements need clarification during implementation
- Measure: Developer questions about requirement meaning
- Goal: Coding agents can implement without human interpretation

**Test Coverage Alignment**
- Target: 1:1 ratio between EARS requirements and test cases
- Measure: Requirements traceability to tests
- Goal: 100% requirement coverage in automated test suites

---

## 🔗 Navigation

### Previous: [Executive Summary](./executive-summary.md)

### Next: [Requirements Template](./requirements-template.md)

---

*EARS Notation Guide completed on July 20, 2025*  
*Based on systems engineering best practices and AWS Kiro implementation patterns*
