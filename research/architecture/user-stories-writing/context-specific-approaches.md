# Context-Specific Approaches: API-First, UI-First, and Integration Development

## Understanding Development Context Impact

The user correctly identified that system requirements differ depending on whether you're creating the API first, building just the UI for frontend, or integrating systems. Each development context requires a different emphasis in user stories, acceptance criteria, and EARS notation while maintaining the core user value.

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   API-FIRST     │    │   UI-FIRST      │    │  INTEGRATION    │
│                 │    │                 │    │                 │
│ Backend Focus   │    │ Frontend Focus  │    │ System Focus    │
│ Data & Services │    │ User Experience │    │ Cross-Platform  │
│ Technical Specs │    │ Visual Design   │    │ Compatibility   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## API-First Development Context

### Philosophy and Approach
API-first development prioritizes building robust backend services before implementing user interfaces. This approach focuses on data models, business logic, service contracts, and system integration points.

### User Story Adaptations for API-First

#### Traditional vs. API-First Story Writing

**Traditional Story:**
```
As a user
I want to log in to my account
So that I can access my personal information
```

**API-First Adapted Story:**
```
As a frontend developer
I want a secure authentication API endpoint
So that I can implement login functionality in any client application

As a mobile app developer
I want consistent authentication responses
So that I can handle login states reliably across platforms

As a system integrator
I want well-documented authentication endpoints
So that I can integrate with third-party services securely
```

### API-First Acceptance Criteria Focus

#### Endpoint Behavior Specifications
```gherkin
Scenario: Authentication endpoint returns proper response format
  Given the API is running and accessible
  When I send POST /api/auth/login with valid JSON credentials
  Then I should receive HTTP 200 status
  And response should include JWT token with 24-hour expiration
  And response should include user data without password hash
  And response should include refresh token for session extension

Scenario: Authentication endpoint handles invalid requests
  Given the API is running and accessible
  When I send POST /api/auth/login with malformed JSON
  Then I should receive HTTP 400 status
  And response should include error details with field validation
  And response should follow consistent error format across all endpoints

Scenario: Authentication endpoint implements security measures
  Given the API is running and accessible
  When I make 5 consecutive failed authentication requests
  Then subsequent requests should be rate-limited
  And I should receive HTTP 429 status with retry-after header
  And security events should be logged for monitoring
```

#### Data Model Validation
```gherkin
Scenario: User registration creates proper data structure
  Given the registration API endpoint is available
  When I register a new user with complete valid data
  Then user record should be created with all required fields
  And username should be auto-generated from email local part
  And password should be hashed using bcrypt with appropriate salt rounds
  And created timestamp should be set to current UTC time
  And user ID should be generated as UUID

Scenario: User data retrieval excludes sensitive information
  Given a user exists in the database
  When I request user data via GET /api/users/:id
  Then response should include public user information
  And response should never include password hash
  And response should never include internal system fields
  And response should follow consistent data structure
```

### API-First EARS Requirements

#### Service-Level Requirements
```
1. WHEN the authentication API receives POST /api/auth/login with valid JSON payload
   THE system SHALL validate request structure against JSON schema
   AND authenticate credentials against user database within 500ms
   AND return HTTP 200 with JWT token and user data (excluding password)

2. WHEN generating JWT tokens for authenticated users
   THE system SHALL include user ID, username, email, and role claims
   AND set token expiration to 24 hours from generation time
   AND sign token using RS256 algorithm with private key
   AND include issuer and audience claims for token validation

3. IF the authentication API receives malformed JSON or missing required fields
   THEN the system SHALL return HTTP 400 status
   AND include specific field validation errors in response body
   AND follow RFC 7807 problem details format for error responses

4. The system SHALL implement rate limiting for authentication endpoints
   AND allow maximum 10 requests per minute per IP address
   AND return HTTP 429 with Retry-After header when limit exceeded
   AND maintain rate limit counters in Redis with TTL expiration
```

#### Data Persistence Requirements
```
5. WHEN creating new user accounts via registration API
   THE system SHALL validate email uniqueness before database insertion
   AND generate UUID as primary key for user records
   AND hash passwords using bcrypt with minimum 12 salt rounds
   AND store user data in normalized database structure

6. WHEN auto-generating usernames from email addresses
   THE system SHALL extract local part (before @) from email
   AND ensure username uniqueness by appending numeric suffix if needed
   AND validate generated username against allowed character set
   AND store both email and generated username for authentication options

7. The system SHALL maintain audit logs for all authentication events
   AND record successful logins with user ID, timestamp, and IP address
   AND record failed attempts with attempted identifier and IP address
   AND never log sensitive data (passwords, tokens) in audit records
```

#### API Contract Requirements
```
8. The system SHALL maintain consistent API response formats across all endpoints
   AND include standardized metadata (timestamp, version, request ID)
   AND implement HATEOAS links for resource navigation where applicable
   AND provide comprehensive OpenAPI specification for all endpoints

9. WHEN API versioning is required for backward compatibility
   THE system SHALL support version specification via Accept header
   AND maintain support for previous major version during transition
   AND provide deprecation warnings with timeline for older versions

10. The system SHALL implement proper HTTP status codes for all scenarios
    AND use 2xx for successful operations
    AND use 4xx for client errors with descriptive messages
    And use 5xx for server errors with error tracking correlation IDs
```

## UI-First Development Context

### Philosophy and Approach
UI-first development prioritizes user experience and interface design, focusing on user workflows, visual design, accessibility, and frontend functionality before backend implementation.

### User Story Adaptations for UI-First

#### Experience-Focused Story Writing

**API-First Story:**
```
As a frontend developer
I want a login API endpoint
So that I can authenticate users programmatically
```

**UI-First Adapted Story:**
```
As a website visitor
I want an intuitive and accessible login form
So that I can quickly and easily access my account

As a mobile user
I want the login form to work well on my device
So that I can log in comfortably without zooming or scrolling

As a user with visual impairments
I want the login form to work with my screen reader
So that I can access the application independently
```

### UI-First Acceptance Criteria Focus

#### User Experience Specifications
```gherkin
Scenario: Login form provides excellent user experience
  Given I am on the login page
  When the page loads
  Then the email field should be automatically focused
  And I should see clear, helpful placeholder text
  And the form should be visually well-organized and professional
  And all interactive elements should have adequate touch targets (44px minimum)

Scenario: Login form provides real-time feedback
  Given I am filling out the login form
  When I enter text in the email field
  Then invalid email format should show immediate feedback
  And valid email should show confirmation indicator
  When I enter text in the password field
  Then password strength should be indicated visually
  And show/hide password toggle should be available

Scenario: Login form handles errors gracefully
  Given I have entered invalid credentials
  When I submit the login form
  Then error messages should appear near relevant fields
  And error styling should be clear but not alarming
  And I should receive helpful guidance on how to resolve the issue
  And the form should remain usable for correction attempts
```

#### Accessibility and Responsiveness
```gherkin
Scenario: Login form meets accessibility standards
  Given I am using assistive technology
  When I navigate the login form with keyboard only
  Then all form elements should be reachable via Tab key
  And focus indicators should be clearly visible
  And form labels should be properly associated with inputs
  And error messages should be announced by screen readers

Scenario: Login form works across devices and browsers
  Given I am using various devices (desktop, tablet, mobile)
  When I access the login form
  Then the layout should adapt appropriately to screen size
  And all functionality should work consistently
  And performance should be acceptable on slower connections
  And the form should work in all major browsers (Chrome, Firefox, Safari, Edge)
```

### UI-First EARS Requirements

#### Interface Behavior Requirements
```
1. WHEN the login page loads in a web browser
   THE system SHALL render the complete form within 2 seconds on 3G connections
   AND automatically set focus to the email/username input field
   AND display the form with proper semantic HTML structure for accessibility

2. WHEN a user interacts with form input fields
   THE system SHALL provide immediate visual feedback for validation states
   AND display field-specific error messages below each input
   AND update ARIA live regions for screen reader announcements
   AND maintain form state during interaction to prevent data loss

3. WHEN a user submits the login form
   THE system SHALL display loading state with appropriate animation
   AND disable the submit button to prevent double submission
   AND show progress feedback during authentication process
   AND provide clear success or error messaging upon completion

4. IF form validation errors occur
   THEN the system SHALL highlight invalid fields with red border and error icon
   AND display specific, actionable error messages in user-friendly language
   AND focus on the first invalid field for keyboard navigation
   AND ensure error messages are accessible to screen readers
```

#### Responsive Design Requirements
```
5. WHEN the login form is displayed on mobile devices (< 768px width)
   THE system SHALL adapt layout to single-column design
   AND ensure input fields are at least 44px high for touch accessibility
   AND prevent zoom on input focus by setting appropriate viewport meta tag
   AND maintain readable text size without horizontal scrolling

6. WHEN the login form is displayed on tablet devices (768px - 1024px width)
   THE system SHALL optimize layout for portrait and landscape orientations
   AND maintain visual hierarchy and spacing appropriate for touch interaction
   AND ensure all interactive elements are easily accessible

7. WHEN the login form is displayed on desktop devices (> 1024px width)
   THE system SHALL present optimized layout with appropriate max-width
   AND support keyboard shortcuts and tab navigation patterns
   AND provide hover states for interactive elements
   AND optimize for mouse and keyboard interaction patterns
```

#### Visual Design Requirements
```
8. The system SHALL implement consistent visual design throughout the login interface
   AND use appropriate color contrast ratios (4.5:1 minimum for normal text)
   AND provide clear visual hierarchy with typography and spacing
   AND include loading animations that don't cause seizures or vestibular disorders

9. WHEN displaying form validation states
   THE system SHALL use color, icons, and text together (not color alone)
   AND provide positive feedback for successful field completion
   AND use calm, helpful messaging for error states rather than aggressive warnings

10. The system SHALL support both light and dark theme modes
    AND automatically detect user's system preference where available
    AND provide manual theme toggle option for user preference
    AND maintain appropriate contrast and readability in both modes
```

## Integration Development Context

### Philosophy and Approach
Integration development focuses on connecting multiple systems, ensuring data consistency, handling cross-system authentication, and maintaining compatibility across different platforms and services.

### User Story Adaptations for Integration

#### System-Level Story Writing

**Single System Story:**
```
As a user
I want to log in to the application
So that I can access my account features
```

**Integration-Focused Adapted Story:**
```
As a corporate employee
I want to use my company credentials to access all business applications
So that I don't need to remember multiple passwords

As a system administrator
I want user authentication to synchronize across all connected systems
So that user access is consistent and secure across the organization

As a security auditor
I want comprehensive authentication logs across all integrated systems
So that I can ensure compliance and detect security issues
```

### Integration Acceptance Criteria Focus

#### Cross-System Compatibility
```gherkin
Scenario: Single sign-on works across integrated applications
  Given I have logged in to the main application
  When I navigate to any connected sub-application
  Then I should be automatically authenticated
  And not need to enter credentials again
  And my user context should be properly established in the new system

Scenario: User data synchronization across systems
  Given I update my profile information in one application
  When I access other connected applications
  Then my updated information should be reflected consistently
  And the synchronization should complete within 5 minutes
  And any sync failures should be logged and retried automatically

Scenario: Authentication failure handling across systems
  Given authentication fails in the primary system
  When I attempt to access connected applications
  Then I should be redirected to the primary login system
  And error messages should be consistent across all applications
  And I should be able to regain access by fixing the primary authentication issue
```

#### Data Consistency and Migration
```gherkin
Scenario: Legacy system user migration
  Given users exist in the legacy authentication system
  When they first log in to the new integrated system
  Then their accounts should be automatically migrated
  And all historical data should be preserved and accessible
  And migration should be transparent to the user experience

Scenario: Conflicting user data resolution
  Given the same user exists in multiple systems with different information
  When integrating the systems
  Then conflicts should be identified and flagged for resolution
  And a clear conflict resolution process should be available
  And data integrity should be maintained throughout the process
```

### Integration EARS Requirements

#### Cross-System Authentication Requirements
```
1. WHEN a user successfully authenticates in the primary system
   THE system SHALL generate a federated identity token (SAML or JWT)
   AND propagate authentication status to all registered sub-applications within 30 seconds
   AND maintain session synchronization across all connected systems

2. WHEN a user accesses a connected sub-application
   THE system SHALL validate the federated token against the primary authentication service
   AND establish local session context with appropriate user permissions
   AND redirect to primary authentication if token is invalid or expired

3. IF authentication fails in the primary system
   THEN all connected systems SHALL invalidate existing sessions for that user
   AND redirect authentication requests to the primary login interface
   AND maintain session data temporarily for restoration after successful authentication

4. WHEN user profile data is updated in any connected system
   THE system SHALL propagate changes to all other systems within 5 minutes
   AND maintain audit trail of all data synchronization events
   AND handle sync failures with automatic retry mechanism and escalation
```

#### Data Integration and Consistency Requirements
```
5. WHEN integrating with existing authentication systems (LDAP, Active Directory, etc.)
   THE system SHALL map user attributes consistently across all platforms
   AND maintain backward compatibility with existing user identifiers
   AND provide migration path for users with conflicting data

6. WHEN user registration occurs in any integrated system
   THE system SHALL create user accounts in all connected systems where appropriate
   AND ensure username uniqueness across the entire integrated environment
   AND handle registration failures gracefully with rollback capabilities

7. IF data conflicts are detected during system integration
   THEN the system SHALL flag conflicts for administrative review
   AND provide tools for conflict resolution and data merging
   AND maintain data integrity throughout the resolution process
   AND log all conflict resolution actions for audit purposes
```

#### System Interoperability Requirements
```
8. The system SHALL support multiple authentication protocols (OAuth 2.0, SAML 2.0, OpenID Connect)
   AND provide protocol adapters for legacy system integration
   AND maintain security standards compliance across all protocol implementations

9. WHEN communicating with external authentication services
   THE system SHALL implement proper error handling and timeout management
   AND provide fallback authentication mechanisms if external services are unavailable
   AND maintain service health monitoring with alerting for integration failures

10. The system SHALL provide comprehensive API documentation for all integration points
    AND include authentication flow diagrams and sequence specifications
    AND offer SDKs or client libraries for common integration scenarios
    AND maintain versioning strategy for API compatibility during updates
```

## Context Comparison Matrix

### Requirements Focus by Context

| Aspect | API-First | UI-First | Integration |
|--------|-----------|----------|-------------|
| **Primary Concern** | Data & Service Contracts | User Experience | System Compatibility |
| **Story Persona** | Developers & Integrators | End Users | System Administrators |
| **Acceptance Criteria Focus** | Endpoint Behavior | Interface Usability | Cross-System Flow |
| **EARS Emphasis** | Technical Specifications | Interface Behavior | Integration Protocols |
| **Error Handling** | HTTP Status Codes | User-Friendly Messages | System Coordination |
| **Performance Metrics** | Response Time & Throughput | Page Load & Interaction | Sync Time & Reliability |
| **Testing Strategy** | API Testing & Unit Tests | E2E & Accessibility Tests | Integration & System Tests |

### Development Timeline Considerations

#### API-First Timeline
```yaml
Phase_1: "Core API Development (4-6 weeks)"
  - Data model design and implementation
  - Authentication endpoint development
  - Security implementation and testing
  - API documentation and contract definition

Phase_2: "Client Implementation (2-4 weeks)"
  - Frontend integration with APIs
  - Error handling and user feedback
  - Performance optimization

Phase_3: "Integration and Polish (1-2 weeks)"  
  - Cross-platform testing
  - Security audits
  - Performance monitoring setup
```

#### UI-First Timeline
```yaml
Phase_1: "Interface Design and Prototyping (3-4 weeks)"
  - User experience design
  - Accessibility implementation
  - Responsive design development
  - User testing and iteration

Phase_2: "Backend Integration (2-3 weeks)"
  - API development to support UI requirements
  - Data persistence implementation
  - Security integration

Phase_3: "Testing and Optimization (1-2 weeks)"
  - Cross-browser testing
  - Performance optimization
  - Accessibility validation
```

#### Integration-First Timeline
```yaml
Phase_1: "System Analysis and Planning (2-3 weeks)"
  - Legacy system assessment
  - Integration architecture design
  - Data mapping and migration planning

Phase_2: "Integration Development (4-6 weeks)"
  - Protocol implementation
  - Data synchronization development
  - Conflict resolution mechanisms

Phase_3: "Testing and Migration (3-4 weeks)"
  - Integration testing
  - User migration execution
  - System monitoring setup
```

## Choosing the Right Context

### Decision Factors

#### Choose API-First When:
- Multiple client applications will consume the same backend services
- Strong separation between frontend and backend teams
- Need for high scalability and performance
- Complex business logic that benefits from service-oriented architecture
- Integration with multiple third-party services is required

#### Choose UI-First When:
- User experience is the primary differentiator
- Rapid prototyping and user feedback are essential
- Single application with tightly coupled frontend and backend
- Strong design requirements that drive technical implementation
- Need for quick market validation of user interface concepts

#### Choose Integration-First When:
- Working with existing legacy systems
- Corporate environment with multiple existing applications
- Compliance requirements for unified authentication
- Complex organizational requirements across multiple systems
- Need for gradual migration from legacy to modern systems

## Navigation

← [Practical Examples](practical-examples.md) | [Implementation Guide →](implementation-guide.md)

---

*Context-specific approaches guide demonstrating how development context (API-first, UI-first, integration) influences user story writing, acceptance criteria, and EARS notation requirements while maintaining user value focus.*