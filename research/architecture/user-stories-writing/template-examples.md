# Template Examples: Ready-to-Use User Story Formats

## Core User Story Templates

### Basic User Story Template
```markdown
# User Story: [Descriptive Title]

**As a** [specific user role/persona]
**I want** [clear, actionable capability]
**So that** [concrete business value or benefit]

**Story Points:** [estimation]
**Priority:** [High/Medium/Low]
**Epic:** [epic name if applicable]
**Dependencies:** [other stories this depends on]

## Acceptance Criteria

### Happy Path Scenarios
[Given-When-Then scenarios for successful outcomes]

### Error Path Scenarios
[Given-When-Then scenarios for error conditions]

### Performance Criteria
[Response time, throughput, and other performance requirements]

### Security Criteria
[Authentication, authorization, and data protection requirements]

## Definition of Done
- [ ] All acceptance criteria implemented and tested
- [ ] Code reviewed and meets quality standards
- [ ] Security requirements validated
- [ ] Performance requirements verified
- [ ] Accessibility requirements met
- [ ] Documentation updated
```

### Enhanced User Story Template with Context
```markdown
# User Story: [Descriptive Title]

## Story Definition
**As a** [specific user persona with context]
**I want** [clear, actionable capability]
**So that** [concrete business value or benefit]

**Persona Details:**
- Role: [specific job title or user type]
- Experience Level: [novice/intermediate/expert]
- Context: [when/where they use this feature]
- Goals: [what they're trying to accomplish]

**Business Context:**
- Strategic Objective: [how this supports business goals]
- Success Metrics: [how we'll measure success]
- Priority Rationale: [why this is important now]

## Story Metadata
- **Story Points:** [estimation]
- **Priority:** [High/Medium/Low with rationale]
- **Epic:** [epic name and link]
- **Sprint:** [target sprint if planned]
- **Dependencies:** [blocking/blocked by other stories]
- **Assumptions:** [key assumptions being made]

## Acceptance Criteria

### Scenario 1: [Primary Happy Path]
```gherkin
Given [specific preconditions]
When [user performs specific action]
Then [expected outcome with measurable criteria]
And [additional verification points]
```

### Scenario 2: [Alternative Success Path]
```gherkin
Given [different preconditions]
When [alternative action approach]
Then [alternative successful outcome]
```

### Scenario 3: [Error Handling]
```gherkin
Given [error condition setup]
When [action that triggers error]
Then [specific error response]
And [recovery options provided]
```

### Non-Functional Requirements
**Performance:**
- Response time: [specific timing requirements]
- Throughput: [volume requirements if applicable]
- Scalability: [concurrent user requirements]

**Security:**
- Authentication: [auth requirements]
- Authorization: [permission requirements]
- Data protection: [encryption/privacy requirements]

**Accessibility:**
- Keyboard navigation: [navigation requirements]
- Screen reader: [assistive technology requirements]
- Visual design: [contrast and readability requirements]

## EARS Requirements Summary
[High-level summary of technical requirements that will be detailed separately]

## Testing Strategy
**Unit Tests:** [key unit testing scenarios]
**Integration Tests:** [integration points to validate]
**E2E Tests:** [end-to-end workflows to verify]
**Performance Tests:** [performance validation approach]

## Definition of Done
- [ ] All acceptance criteria scenarios pass
- [ ] Code meets quality standards (review, tests, coverage)
- [ ] Performance requirements validated
- [ ] Security requirements verified
- [ ] Accessibility standards met
- [ ] Documentation updated (user, API, technical)
- [ ] Stakeholder acceptance received
```

## Context-Specific Templates

### API-First Development Template
```markdown
# API Story: [Endpoint/Service Name]

**As a** [frontend developer/API consumer/system integrator]
**I want** [specific API capability or endpoint]
**So that** [integration capability or client application benefit]

## API Specification
**Endpoint:** [HTTP method and URL]
**Authentication:** [auth requirements]
**Rate Limiting:** [request limits]
**Versioning:** [API version strategy]

## Request/Response Contract

### Request Format
```json
{
  "field1": "string (required)",
  "field2": "integer (optional)",
  "field3": {
    "nested_field": "string (required)"
  }
}
```

### Success Response (200)
```json
{
  "status": "success",
  "data": {
    "id": "uuid",
    "created_at": "ISO8601 timestamp",
    "field1": "processed value"
  },
  "metadata": {
    "request_id": "uuid",
    "processing_time_ms": 150
  }
}
```

### Error Response (4xx/5xx)
```json
{
  "status": "error",
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Human readable error message",
    "details": [
      {
        "field": "field1",
        "message": "Field is required"
      }
    ]
  },
  "metadata": {
    "request_id": "uuid",
    "timestamp": "ISO8601 timestamp"
  }
}
```

## Acceptance Criteria (API Focus)

### Scenario: Successful API Request
```gherkin
Given the API is available and I have valid authentication
When I send a POST request to [endpoint] with valid JSON payload
Then I should receive HTTP 200 status
And response should match the success schema
And response time should be under 500ms
And request should be logged with correlation ID
```

### Scenario: Input Validation Error
```gherkin
Given the API is available and I have valid authentication
When I send a POST request with invalid/missing required fields
Then I should receive HTTP 400 status
And response should include specific field validation errors
And error format should match API error schema
And no data should be persisted
```

### Scenario: Authentication/Authorization Error
```gherkin
Given I have invalid or missing authentication credentials
When I send any request to the protected endpoint
Then I should receive HTTP 401 or 403 status
And response should include appropriate error message
And no sensitive information should be disclosed
```

## EARS Requirements (API Focus)
1. WHEN the API receives [HTTP method] [endpoint] with valid authentication and payload
   THE system SHALL validate input against JSON schema within 100ms
   AND process the request according to business logic
   AND return appropriate HTTP status code and response body within 500ms

2. IF the API receives malformed JSON or invalid field values
   THEN the system SHALL return HTTP 400 with field-specific error messages
   AND follow RFC 7807 problem details format
   AND log validation errors (excluding sensitive data)

3. The system SHALL implement rate limiting of [X] requests per minute per API key
   AND return HTTP 429 with Retry-After header when exceeded
   AND provide rate limit status in response headers
```

### UI-First Development Template
```markdown
# UI Story: [Interface/Component Name]

**As a** [specific user persona]
**I want** [interface capability or user experience]
**So that** [user goal or experience improvement]

## User Experience Context
**User Journey Step:** [where this fits in user workflow]
**Device Context:** [desktop/tablet/mobile considerations]
**Usage Frequency:** [how often user will use this]
**Time Constraints:** [typical time user has for this task]

## Interface Requirements

### Visual Design
- **Layout:** [responsive behavior and visual hierarchy]
- **Interaction:** [buttons, forms, navigation elements]
- **Feedback:** [loading states, success/error messaging]
- **Accessibility:** [keyboard nav, screen readers, contrast]

### User Workflow
```
1. User arrives at [page/component] from [previous step]
2. User sees [initial state/default view]
3. User performs [primary action]
4. System provides [immediate feedback]
5. User proceeds to [next step] or [alternative path]
```

## Acceptance Criteria (UI Focus)

### Scenario: Interface Loading and Initial State
```gherkin
Given I navigate to [page/component]
When the interface loads
Then I should see [specific UI elements] within 2 seconds
And the [primary action element] should be clearly visible
And the interface should be responsive on mobile devices
And keyboard focus should start on [appropriate element]
```

### Scenario: User Interaction and Feedback
```gherkin
Given I am on [page/component] with [specific state/data]
When I [perform specific user action]
Then I should see [immediate visual feedback]
And [specific UI changes] should occur
And appropriate ARIA announcements should be made for screen readers
```

### Scenario: Error States and Recovery
```gherkin
Given I am using [interface component]
When [error condition occurs or invalid action performed]
Then I should see [specific error message] near [relevant UI element]
And the error styling should be clear but not alarming
And I should be provided with [specific recovery action]
And my previous input should be preserved where appropriate
```

### Responsive Design Scenarios
```gherkin
Scenario: Mobile device usage (viewport < 768px)
  Given I am using a mobile device
  When I access [interface]
  Then the layout should adapt to single-column design
  And all interactive elements should be at least 44px touch targets
  And text should remain readable without horizontal scrolling

Scenario: Tablet device usage (viewport 768px-1024px)
  Given I am using a tablet device
  When I access [interface] in portrait and landscape modes
  Then the layout should optimize for both orientations
  And all functionality should remain accessible via touch
```

## EARS Requirements (UI Focus)
1. WHEN the [page/component] loads in a web browser
   THE system SHALL render all critical elements within 2 seconds on 3G connection
   AND apply appropriate responsive styles based on viewport size
   AND ensure keyboard accessibility for all interactive elements

2. WHEN a user interacts with [specific UI element]
   THE system SHALL provide immediate visual feedback within 100ms
   AND update UI state according to interaction requirements
   AND announce changes to assistive technologies via ARIA live regions

3. IF form validation errors occur
   THEN the system SHALL highlight invalid fields with clear visual indicators
   AND display specific, actionable error messages
   AND maintain focus management for keyboard users
```

### Integration Development Template
```markdown
# Integration Story: [System Integration Name]

**As a** [system administrator/business user/system integrator]
**I want** [cross-system capability or data synchronization]
**So that** [business process improvement or system harmony benefit]

## Integration Context
**Source System:** [system providing data/functionality]
**Target System:** [system receiving data/functionality]
**Integration Pattern:** [API calls/webhooks/batch processing/event streaming]
**Data Flow Direction:** [unidirectional/bidirectional]
**Frequency:** [real-time/scheduled/event-driven]

## Data Mapping
### Source Data Format
```json
{
  "source_field_1": "value type and description",
  "source_field_2": "value type and description",
  "nested_object": {
    "sub_field": "value type and description"
  }
}
```

### Target Data Format
```json
{
  "target_field_1": "mapped from source_field_1",
  "target_field_2": "calculated from source data",
  "additional_field": "enriched or default value"
}
```

### Field Mapping Table
| Source Field | Target Field | Transformation | Required | Default |
|--------------|--------------|----------------|----------|---------|
| source_field_1 | target_field_1 | Direct mapping | Yes | N/A |
| source_field_2 | target_field_2 | Format conversion | No | "default_value" |

## Acceptance Criteria (Integration Focus)

### Scenario: Successful Data Synchronization
```gherkin
Given [source system] has updated data
When the integration process runs (scheduled/triggered)
Then data should be synchronized to [target system] within [time limit]
And data integrity should be maintained across systems
And synchronization status should be logged with timestamps
```

### Scenario: Data Conflict Resolution
```gherkin
Given conflicting data exists in both systems
When synchronization process encounters conflicts
Then conflicts should be identified and flagged for resolution
And business rules should determine conflict resolution strategy
And audit trail should record all conflict resolution actions
```

### Scenario: Integration Failure Handling
```gherkin
Given [external system] is unavailable or returns errors
When integration process attempts synchronization
Then failures should be logged with specific error details
And retry mechanism should attempt synchronization according to policy
And system administrators should be notified of persistent failures
```

## EARS Requirements (Integration Focus)
1. WHEN [source system] publishes data changes via [integration method]
   THE system SHALL receive and validate data within 30 seconds
   AND apply business rules for data transformation and mapping
   AND update [target system] maintaining transactional consistency

2. IF data conflicts are detected during synchronization
   THEN the system SHALL apply conflict resolution rules based on [business logic]
   AND flag unresolvable conflicts for manual review
   AND maintain audit trail of all conflict resolution actions

3. WHILE integration services are running
   THE system SHALL monitor connectivity to all external systems
   AND implement exponential backoff retry strategy for temporary failures
   AND alert administrators when systems are unavailable for more than [time threshold]
```

## Feature-Specific Templates

### Authentication Feature Template
```markdown
# Authentication Story: [Specific Auth Feature]

**As a** [user persona]
**I want** [authentication capability]
**So that** [security and access benefit]

## Security Context
**Authentication Method:** [password/OAuth/SSO/MFA]
**Session Management:** [duration/renewal/termination]
**Security Standards:** [compliance requirements]
**Integration Requirements:** [external auth providers]

## Acceptance Criteria

### Scenario: Successful Authentication
```gherkin
Given I am on the login page
And I have valid credentials for an active account
When I enter my [username/email] and password
And I click the "Login" button
Then I should be authenticated successfully
And redirected to [appropriate landing page] within 3 seconds
And my session should be established with [duration] expiration
And last login time should be recorded and displayed
```

### Scenario: Failed Authentication
```gherkin
Given I am on the login page
When I enter invalid credentials
And I click the "Login" button
Then I should see error message "Invalid username/email or password"
And I should remain on the login page
And the password field should be cleared for security
And failed attempt should be logged (without password data)
```

### Scenario: Account Security Protection
```gherkin
Given I have made [X] consecutive failed login attempts
When I make another failed attempt
Then my account should be temporarily locked for [duration]
And I should see lockout message with clear instructions
And account owner should receive security notification email
```

## EARS Requirements (Authentication)
1. WHEN a user submits login credentials via the authentication form
   THE system SHALL validate credentials against user database within 2 seconds
   AND create secure session token using [encryption standard]
   AND redirect to appropriate dashboard based on user role

2. IF user credentials are invalid (username/email not found or password incorrect)
   THEN the system SHALL display generic error message to prevent user enumeration
   AND increment failed attempt counter for security monitoring
   AND log authentication failure with IP address and timestamp

3. IF a user account exceeds [X] failed login attempts within [time window]
   THEN the system SHALL temporarily lock the account for [duration]
   AND send security notification to registered email address
   AND require additional verification for account unlock
```

### Data Management Feature Template
```markdown
# Data Management Story: [Specific Data Feature]

**As a** [user persona]
**I want** [data manipulation capability]
**So that** [information management benefit]

## Data Context
**Data Type:** [customer records/products/transactions/etc.]
**Data Volume:** [expected records/size/growth rate]
**Data Relationships:** [connections to other data entities]
**Compliance Requirements:** [GDPR/HIPAA/other regulations]

## Acceptance Criteria

### Scenario: Successful Data Creation
```gherkin
Given I have permission to create [data type]
And I am on the [data creation interface]
When I enter valid data in all required fields
And I click "Save" or submit the form
Then the new record should be created with unique identifier
And I should see confirmation of successful creation
And the record should appear in relevant listings within 5 seconds
```

### Scenario: Data Validation and Error Handling
```gherkin
Given I am creating or editing [data type]
When I enter invalid data or leave required fields empty
And I attempt to save the record
Then specific validation errors should be displayed for each field
And the form should highlight invalid fields clearly
And my valid data should be preserved for correction
```

### Scenario: Data Relationship Management
```gherkin
Given I am working with [data type] that relates to [other data entities]
When I create or update relationships between records
Then relationship integrity should be maintained
And dependent records should be updated appropriately
And relationship changes should be reflected in all related views
```

## EARS Requirements (Data Management)
1. WHEN a user creates a new [data type] record with valid data
   THE system SHALL generate unique identifier using [ID strategy]
   AND validate all field data according to business rules
   AND persist the record to database with audit timestamp

2. IF data validation fails during record creation or update
   THEN the system SHALL provide field-specific error messages
   AND highlight invalid fields with appropriate visual indicators
   AND preserve valid field data to minimize user re-entry

3. WHEN [data type] records are deleted
   THE system SHALL check for dependent relationships
   AND prevent deletion if dependencies exist with appropriate error message
   AND perform soft delete with audit trail for data recovery
```

## Testing Templates

### Test Case Template (Derived from Acceptance Criteria)
```markdown
# Test Case: [Test Case Name]

**Story Reference:** [Link to user story]
**Acceptance Criteria:** [Reference to specific criteria being tested]
**Test Type:** [Unit/Integration/E2E/Performance/Security]

## Test Setup
**Preconditions:**
- [System state requirements]
- [Test data requirements]
- [User permissions/roles needed]
- [Environment configuration]

**Test Data:**
- [Specific test data values]
- [Edge case values]
- [Invalid data examples]

## Test Steps
1. [Specific action to perform]
2. [Next action with expected state]
3. [Verification step]
4. [Cleanup actions if needed]

## Expected Results
**Success Criteria:**
- [Observable outcome 1]
- [Measurable result 2]
- [System state verification 3]

**Performance Criteria:**
- Response time: [specific timing]
- Resource usage: [memory/CPU limits]
- Throughput: [volume requirements]

## Error Cases
**Invalid Input Testing:**
- [Test with invalid data]
- [Expected error messages]
- [Recovery behavior verification]

**Boundary Testing:**
- [Minimum/maximum values]
- [Empty/null data handling]
- [Concurrent access scenarios]
```

### Automated Test Template (BDD Style)
```javascript
// Feature: [Feature Name from User Story]
// Story: [User Story Reference]

describe('[Feature Name]', () => {
  beforeEach(() => {
    // Test setup and data preparation
  });

  describe('Happy Path Scenarios', () => {
    test('should [expected behavior from acceptance criteria]', async () => {
      // Given: Setup test conditions
      // When: Perform the action
      // Then: Verify the expected outcome
      
      expect(result).toBe(expectedValue);
      expect(systemState).toMatchObject(expectedState);
    });
  });

  describe('Error Scenarios', () => {
    test('should handle [specific error condition] appropriately', async () => {
      // Given: Error condition setup
      // When: Action that triggers error
      // Then: Verify error handling
      
      expect(errorMessage).toContain('Expected error text');
      expect(systemState).toBe('recovered_state');
    });
  });

  describe('Performance Requirements', () => {
    test('should meet response time requirements', async () => {
      const startTime = Date.now();
      
      // Perform action
      
      const responseTime = Date.now() - startTime;
      expect(responseTime).toBeLessThan(3000); // 3 second requirement
    });
  });
});
```

## Documentation Templates

### Feature Documentation Template
```markdown
# Feature Documentation: [Feature Name]

## Overview
[Brief description of the feature and its purpose]

## User Stories Implemented
- [Link to Story 1]: [Brief description]
- [Link to Story 2]: [Brief description]
- [Link to Story 3]: [Brief description]

## User Guide

### Getting Started
1. [First step users need to take]
2. [Second step with screenshots if helpful]
3. [Completion and success indicators]

### Common Use Cases
#### Use Case 1: [Common Scenario]
[Step-by-step instructions]

#### Use Case 2: [Alternative Scenario]
[Step-by-step instructions]

### Troubleshooting
**Problem:** [Common issue users might encounter]
**Solution:** [Step-by-step resolution]

**Problem:** [Another common issue]
**Solution:** [Resolution steps]

## Technical Documentation

### API Endpoints (if applicable)
[Generated from EARS requirements]

### Database Schema Changes
[Tables/fields added or modified]

### Configuration Changes
[Environment variables or settings updated]

## Testing Coverage
- Unit Tests: [Coverage percentage and key test scenarios]
- Integration Tests: [Integration points validated]
- E2E Tests: [User workflows verified]
- Performance Tests: [Performance requirements validated]

## Deployment Notes
[Special considerations for deploying this feature]

## Monitoring and Metrics
[Key metrics to monitor for feature health and success]
```

## Navigation

← [Best Practices](best-practices.md) | [Comparison Analysis →](comparison-analysis.md)

---

*Comprehensive template collection providing ready-to-use formats for user stories, acceptance criteria, EARS requirements, and supporting documentation across different development contexts.*