# Template Examples for EARS Notation

## Complete Project Examples

### E-commerce Platform Requirements

This section demonstrates how EARS notation applies to a complete e-commerce platform, showing the integration of all six templates in a cohesive requirements specification.

#### User Registration and Authentication

```yaml
# User Registration Module - EARS Requirements

# Ubiquitous Requirements
REQ-001:
  template: ubiquitous
  requirement: "The system shall encrypt all user passwords using bcrypt with a minimum cost factor of 12."
  acceptance_criteria:
    - given: "A new user password is submitted"
      when: "The system processes the registration"
      then: "The password is hashed using bcrypt with cost factor 12 or higher"

REQ-002:
  template: ubiquitous
  requirement: "The system shall require passwords to contain at least 8 characters including uppercase, lowercase, numbers, and special characters."
  acceptance_criteria:
    - given: "A user submits a password during registration"
      when: "The system validates the password"
      then: "The password meets all complexity requirements"

# Event-driven Requirements
REQ-003:
  template: event_driven
  requirement: "WHEN a user submits a valid registration form, the system shall create a new user account within 3 seconds."
  acceptance_criteria:
    - given: "A valid registration form is submitted"
      when: "The user clicks the register button"
      then: "A new user account is created within 3 seconds"

REQ-004:
  template: event_driven
  requirement: "WHEN a new user account is created, the system shall send a verification email within 1 minute."
  acceptance_criteria:
    - given: "A new user account has been successfully created"
      when: "The account creation process completes"
      then: "A verification email is queued and sent within 1 minute"

# Unwanted Behavior Requirements
REQ-005:
  template: unwanted_behavior
  requirement: "IF a user attempts to register with an email address already in use, THEN the system shall display an error message and prevent account creation."
  acceptance_criteria:
    - given: "An email address already exists in the system"
      when: "A user attempts to register with that email"
      then: "Registration is blocked and appropriate error message is displayed"

REQ-006:
  template: unwanted_behavior
  requirement: "IF email verification is not completed within 24 hours, THEN the system shall automatically delete the unverified account."
  acceptance_criteria:
    - given: "A user account was created but not verified"
      when: "24 hours have passed since account creation"
      then: "The unverified account is automatically deleted"

# State-driven Requirements
REQ-007:
  template: state_driven
  requirement: "WHILE a user session is active, the system shall refresh the authentication token every 30 minutes."
  acceptance_criteria:
    - given: "A user has an active session"
      when: "30 minutes have passed since last token refresh"
      then: "A new authentication token is generated and updated"

# Optional Requirements
REQ-008:
  template: optional
  requirement: "WHERE social media integration is enabled, the system shall allow registration using Google or Facebook OAuth providers."
  acceptance_criteria:
    - given: "Social media integration feature is enabled"
      when: "A user chooses social media registration option"
      then: "OAuth flow is initiated with selected provider"

# Complex Requirements
REQ-009:
  template: complex
  requirement: "IF the user account has administrative privileges, THEN WHEN the user attempts to delete another user account, the system shall require two-factor authentication confirmation."
  acceptance_criteria:
    - given: "A user has administrative privileges"
      when: "The user attempts to delete another user account"
      then: "Two-factor authentication is required before proceeding"
```

#### Shopping Cart and Checkout Process

```yaml
# Shopping Cart Module - EARS Requirements

# Ubiquitous Requirements
REQ-101:
  template: ubiquitous
  requirement: "The system shall persist shopping cart contents for logged-in users across browser sessions."
  acceptance_criteria:
    - given: "A logged-in user has items in their cart"
      when: "The user closes and reopens the browser"
      then: "Cart contents are preserved and displayed"

REQ-102:
  template: ubiquitous
  requirement: "The system shall support a maximum of 50 items per shopping cart."
  acceptance_criteria:
    - given: "A user attempts to add items to cart"
      when: "The cart already contains 50 items"
      then: "Additional items are rejected with appropriate message"

# Event-driven Requirements
REQ-103:
  template: event_driven
  requirement: "WHEN a user adds an item to the cart, the system shall update the cart total and item count within 1 second."
  acceptance_criteria:
    - given: "A user clicks 'Add to Cart' for a product"
      when: "The item is successfully added"
      then: "Cart total and count are updated within 1 second"

REQ-104:
  template: event_driven
  requirement: "WHEN a user proceeds to checkout, the system shall validate all cart items for availability and current pricing."
  acceptance_criteria:
    - given: "A user clicks 'Proceed to Checkout'"
      when: "The checkout process begins"
      then: "All cart items are validated for stock and price accuracy"

# Unwanted Behavior Requirements
REQ-105:
  template: unwanted_behavior
  requirement: "IF an item in the cart becomes out of stock, THEN the system shall remove the item and notify the user immediately."
  acceptance_criteria:
    - given: "An item in the user's cart goes out of stock"
      when: "The system detects the inventory change"
      then: "Item is removed from cart and user is notified"

REQ-106:
  template: unwanted_behavior
  requirement: "IF the cart remains inactive for 60 minutes, THEN the system shall display an abandonment warning to logged-in users."
  acceptance_criteria:
    - given: "A logged-in user has items in cart but no activity"
      when: "60 minutes have passed since last cart interaction"
      then: "Cart abandonment warning is displayed"

# State-driven Requirements
REQ-107:
  template: state_driven
  requirement: "WHILE checkout is in progress, the system shall reserve all cart items to prevent overselling."
  acceptance_criteria:
    - given: "A user has initiated the checkout process"
      when: "Checkout is in progress"
      then: "All cart items are temporarily reserved in inventory"

# Optional Requirements
REQ-108:
  template: optional
  requirement: "WHERE guest checkout is enabled, the system shall allow users to complete purchases without creating an account."
  acceptance_criteria:
    - given: "Guest checkout feature is enabled"
      when: "An unauthenticated user proceeds to checkout"
      then: "Checkout process continues with guest information collection"

# Complex Requirements
REQ-109:
  template: complex
  requirement: "IF the cart total exceeds $500, THEN WHEN the user applies a discount code, the system shall verify the code validity and apply the maximum allowable discount."
  acceptance_criteria:
    - given: "Cart total is over $500 and user enters a discount code"
      when: "The discount code is submitted"
      then: "Code validity is checked and appropriate discount is applied"
```

### Healthcare Management System

#### Patient Record Management

```yaml
# Patient Records Module - EARS Requirements

# Ubiquitous Requirements  
REQ-201:
  template: ubiquitous
  requirement: "The system shall encrypt all patient health information using AES-256 encryption both at rest and in transit."
  acceptance_criteria:
    - given: "Patient health information is stored or transmitted"
      when: "Data is processed by the system"
      then: "AES-256 encryption is applied consistently"

REQ-202:
  template: ubiquitous
  requirement: "The system shall maintain complete audit logs of all patient record access for a minimum of 7 years."
  acceptance_criteria:
    - given: "Any user accesses patient records"
      when: "Record access occurs"
      then: "Comprehensive audit entry is created and retained for 7+ years"

# Event-driven Requirements
REQ-203:
  template: event_driven
  requirement: "WHEN a healthcare provider searches for patient records, the system shall return results within 2 seconds."
  acceptance_criteria:
    - given: "A healthcare provider enters search criteria"
      when: "Search is executed"
      then: "Relevant patient records are displayed within 2 seconds"

REQ-204:
  template: event_driven
  requirement: "WHEN a patient record is updated, the system shall create a timestamped version history entry."
  acceptance_criteria:
    - given: "Patient record information is modified"
      when: "Changes are saved"
      then: "Version history entry with timestamp and user ID is created"

# Unwanted Behavior Requirements
REQ-205:
  template: unwanted_behavior
  requirement: "IF a user attempts to access patient records without proper authorization, THEN the system shall deny access and log the security violation."
  acceptance_criteria:
    - given: "A user lacks proper authorization for specific patient records"
      when: "Access is attempted"
      then: "Access is denied and security violation is logged"

REQ-206:
  template: unwanted_behavior
  requirement: "IF the system detects unusual access patterns, THEN the system shall automatically lock the user account and notify security administrators."
  acceptance_criteria:
    - given: "Unusual access patterns are detected"
      when: "Pattern analysis triggers security alert"
      then: "Account is locked and security team is notified immediately"

# State-driven Requirements
REQ-207:
  template: state_driven
  requirement: "WHILE patient records are displayed on screen, the system shall automatically lock the session after 10 minutes of inactivity."
  acceptance_criteria:
    - given: "Patient records are currently displayed"
      when: "10 minutes pass without user interaction"
      then: "Session is automatically locked and screen is secured"

# Optional Requirements
REQ-208:
  template: optional
  requirement: "WHERE voice recognition is available, the system shall support dictated clinical notes with 95% accuracy."
  acceptance_criteria:
    - given: "Voice recognition capability is enabled"
      when: "Healthcare provider dictates clinical notes"
      then: "Notes are transcribed with 95% or higher accuracy"

# Complex Requirements
REQ-209:
  template: complex
  requirement: "IF the patient has restricted access flags, THEN WHEN any user attempts to view the record, the system shall require additional authentication and log the elevated access."
  acceptance_criteria:
    - given: "Patient record has restricted access flags set"
      when: "Any user attempts to access the record"
      then: "Additional authentication is required and access is logged as elevated"
```

### Financial Trading Platform

#### Trading Operations and Risk Management

```yaml
# Trading Operations Module - EARS Requirements

# Ubiquitous Requirements
REQ-301:
  template: ubiquitous
  requirement: "The system shall process all trades with microsecond-level timestamp accuracy."
  acceptance_criteria:
    - given: "A trade is executed in the system"
      when: "Trade processing occurs"
      then: "Timestamp accuracy is within microsecond precision"

REQ-302:
  template: ubiquitous
  requirement: "The system shall maintain real-time portfolio values with 99.99% accuracy."
  acceptance_criteria:
    - given: "Portfolio positions exist in the system"
      when: "Market prices change"
      then: "Portfolio values are updated with 99.99% accuracy"

# Event-driven Requirements
REQ-303:
  template: event_driven
  requirement: "WHEN a market order is submitted, the system shall execute the trade within 100 milliseconds during normal market conditions."
  acceptance_criteria:
    - given: "A valid market order is submitted"
      when: "Order processing begins"
      then: "Trade execution completes within 100 milliseconds"

REQ-304:
  template: event_driven
  requirement: "WHEN a trade is executed, the system shall immediately update the user's portfolio and send confirmation notification."
  acceptance_criteria:
    - given: "A trade execution is completed"
      when: "Trade settlement occurs"
      then: "Portfolio is updated and confirmation is sent immediately"

# Unwanted Behavior Requirements
REQ-305:
  template: unwanted_behavior
  requirement: "IF a trade order exceeds the user's risk limits, THEN the system shall reject the order and notify the risk management team."
  acceptance_criteria:
    - given: "A trade order violates established risk limits"
      when: "Order validation is performed"
      then: "Order is rejected and risk team receives immediate notification"

REQ-306:
  template: unwanted_behavior
  requirement: "IF market connectivity is lost, THEN the system shall immediately halt all trading activity and activate emergency protocols."
  acceptance_criteria:
    - given: "Market data feed or trading connection is lost"
      when: "Connectivity failure is detected"
      then: "All trading is halted and emergency procedures are activated"

# State-driven Requirements
REQ-307:
  template: state_driven
  requirement: "WHILE the market is open, the system shall continuously monitor risk exposure and update risk metrics every second."
  acceptance_criteria:
    - given: "Trading markets are currently open"
      when: "System is operational"
      then: "Risk metrics are calculated and updated every second"

# Optional Requirements
REQ-308:
  template: optional
  requirement: "WHERE algorithmic trading is enabled, the system shall support custom trading strategies with backtesting capabilities."
  acceptance_criteria:
    - given: "Algorithmic trading feature is enabled for user"
      when: "User uploads a custom trading strategy"
      then: "Strategy can be backtested against historical data"

# Complex Requirements
REQ-309:
  template: complex
  requirement: "IF portfolio loss exceeds 2% in a single day, THEN WHEN any new trade is attempted, the system shall require additional risk manager approval."
  acceptance_criteria:
    - given: "Daily portfolio loss has exceeded 2%"
      when: "User attempts to place any new trade"
      then: "Additional risk manager approval is required before trade execution"
```

## Template-Specific Examples by Industry

### SaaS Application Requirements

#### Authentication and Authorization

```markdown
# Ubiquitous Templates for SaaS
The system shall maintain user session state across all microservices using distributed session management.
The system shall enforce rate limiting of 100 API requests per minute per authenticated user.
The system shall backup all user data to geographically distributed storage every 4 hours.

# Event-driven Templates for SaaS
WHEN a user exceeds their subscription plan limits, the system shall restrict access to premium features within 1 minute.
WHEN a subscription payment fails, the system shall send notifications and retry payment processing 3 times over 7 days.
WHEN a new user signs up, the system shall provision their environment and send welcome instructions within 5 minutes.

# Unwanted Behavior Templates for SaaS
IF API rate limits are exceeded, THEN the system shall return HTTP 429 status and include retry-after headers.
IF subscription payment continues to fail after 3 attempts, THEN the system shall downgrade the account to free tier.
IF suspicious activity is detected, THEN the system shall temporarily freeze the account and require identity verification.

# State-driven Templates for SaaS
WHILE a user's subscription is in trial period, the system shall display remaining trial days on every login.
WHILE system maintenance is in progress, the system shall display status updates every 15 minutes.
WHILE data migration is running, the system shall prevent write operations to affected user accounts.

# Optional Templates for SaaS
WHERE enterprise SSO is configured, the system shall authenticate users through the corporate identity provider.
WHERE multi-factor authentication is enabled, the system shall require verification codes for sensitive operations.
WHERE advanced analytics are purchased, the system shall provide real-time dashboard updates every 30 seconds.

# Complex Templates for SaaS
IF the user account is on enterprise plan, THEN WHEN bulk data export is requested, the system shall prioritize the request and complete within 1 hour.
IF usage exceeds 90% of plan limits, THEN WHEN the user performs resource-intensive operations, the system shall display upgrade recommendations.
```

### IoT Device Management

#### Device Registration and Monitoring

```markdown
# Ubiquitous Templates for IoT
The system shall encrypt all device communication using TLS 1.3 with certificate-based authentication.
The system shall store device telemetry data with millisecond precision timestamps.
The system shall support simultaneous connections from up to 10,000 IoT devices per gateway.

# Event-driven Templates for IoT
WHEN an IoT device connects to the network, the system shall validate device certificates and register the device within 5 seconds.
WHEN device telemetry indicates critical thresholds, the system shall trigger alerts within 10 seconds.
WHEN a device fails to check in for 5 minutes, the system shall mark the device as potentially offline.

# Unwanted Behavior Templates for IoT
IF a device sends malformed data packets, THEN the system shall log the error and request data retransmission.
IF device authentication fails 3 times, THEN the system shall blacklist the device MAC address for 1 hour.
IF network bandwidth utilization exceeds 80%, THEN the system shall prioritize critical device communications.

# State-driven Templates for IoT
WHILE devices are in low-power mode, the system shall reduce polling frequency to preserve battery life.
WHILE firmware updates are in progress, the system shall maintain device availability and rollback capability.
WHILE device maintenance windows are active, the system shall defer non-critical operations.

# Optional Templates for IoT
WHERE edge computing capabilities are available, the system shall process sensor data locally to reduce latency.
WHERE cellular connectivity is configured, the system shall use cellular as backup when WiFi fails.
WHERE device grouping is enabled, the system shall apply configuration changes to all devices in the group simultaneously.

# Complex Templates for IoT
IF device battery level drops below 10%, THEN WHEN critical alerts are generated, the system shall prioritize immediate transmission over non-critical data.
IF device temperature exceeds safety thresholds, THEN WHEN emergency shutdown is triggered, the system shall notify all relevant stakeholders within 30 seconds.
```

### Enterprise Resource Planning (ERP)

#### Inventory Management and Financial Controls

```markdown
# Ubiquitous Templates for ERP
The system shall maintain audit trails for all financial transactions with immutable timestamps.
The system shall enforce role-based access controls across all modules and business units.
The system shall synchronize inventory levels across all warehouses in real-time.

# Event-driven Templates for ERP
WHEN inventory levels fall below reorder points, the system shall automatically generate purchase requisitions.
WHEN a financial period is closed, the system shall generate standard financial reports within 2 hours.
WHEN an employee submits an expense report, the system shall route it for approval based on defined workflows.

# Unwanted Behavior Templates for ERP
IF purchase order amounts exceed approval limits, THEN the system shall escalate to the next approval level.
IF inventory adjustments lack proper documentation, THEN the system shall reject the adjustment and require justification.
IF financial data integrity checks fail, THEN the system shall prevent period closing and alert finance team.

# State-driven Templates for ERP
WHILE month-end processing is active, the system shall restrict transaction posting except for corrections.
WHILE inventory audits are in progress, the system shall lock affected item records from modifications.
WHILE system integration is synchronizing data, the system shall display sync status and prevent conflicting operations.

# Optional Templates for ERP
WHERE multi-currency operations are enabled, the system shall automatically convert amounts using current exchange rates.
WHERE advanced analytics modules are licensed, the system shall provide predictive insights for demand planning.
WHERE mobile access is configured, the system shall support field operations through responsive interfaces.

# Complex Templates for ERP
IF budget variance exceeds 10%, THEN WHEN new expenditures are requested, the system shall require budget reallocation approval.
IF inventory shrinkage patterns indicate potential theft, THEN WHEN security reviews are triggered, the system shall provide detailed audit trails and access logs.
```

## User Story Integration Examples

### Complete User Story with EARS Requirements

```markdown
# Epic: Customer Order Management
## User Story 1: Order Placement

**As a** customer
**I want** to place orders for products online
**So that** I can purchase items conveniently from home

**Story Points:** 8
**Priority:** High
**Sprint:** 2024-Sprint-05

### EARS Requirements

#### Primary Flow Requirements
1. **Event-driven:** WHEN a customer adds products to cart and clicks "Place Order", the system shall validate inventory availability within 2 seconds.

2. **Event-driven:** WHEN order validation succeeds, the system shall calculate total cost including taxes and shipping within 1 second.

3. **Event-driven:** WHEN payment processing completes successfully, the system shall generate an order confirmation number and send confirmation email within 30 seconds.

#### Business Rules Requirements
4. **Ubiquitous:** The system shall apply applicable taxes based on customer shipping address according to current tax regulations.

5. **Ubiquitous:** The system shall calculate shipping costs based on package weight, dimensions, and delivery location.

#### Error Handling Requirements
6. **Unwanted Behavior:** IF any ordered item is out of stock, THEN the system shall remove unavailable items from the order and notify the customer with alternatives.

7. **Unwanted Behavior:** IF payment processing fails, THEN the system shall preserve the order for 24 hours and provide payment retry options.

8. **Unwanted Behavior:** IF shipping address validation fails, THEN the system shall highlight address errors and suggest corrections.

#### Optional Features
9. **Optional:** WHERE express shipping is available, the system shall offer next-day delivery options with premium pricing.

10. **Optional:** WHERE customer has loyalty membership, the system shall apply member discounts automatically.

#### Complex Business Logic
11. **Complex:** IF order total exceeds $100, THEN WHEN customer selects standard shipping, the system shall upgrade to free expedited shipping automatically.

### Acceptance Criteria (BDD Format)

```gherkin
Feature: Order Placement
  As a customer
  I want to place orders online
  So that I can purchase products conveniently

  Background:
    Given I am a registered customer
    And I have items in my shopping cart
    And the items are in stock

  Scenario: Successful order placement
    When I click "Place Order"
    Then the system should validate inventory within 2 seconds
    And calculate the total cost within 1 second
    And when payment completes, generate confirmation within 30 seconds

  Scenario: Out of stock item handling
    Given one item in my cart is out of stock
    When I attempt to place the order
    Then the system should remove the unavailable item
    And notify me with alternative suggestions
    And allow me to proceed with remaining items

  Scenario: Payment failure recovery
    Given my payment method fails during processing
    When the payment failure occurs
    Then the system should preserve my order for 24 hours
    And provide options to retry payment
    And send me an email with retry instructions

  Scenario: Free shipping upgrade
    Given my order total is over $100
    When I select standard shipping
    Then the system should automatically upgrade to free expedited shipping
    And display the upgrade confirmation
```

### Definition of Done
- [ ] All EARS requirements implemented and tested
- [ ] Inventory validation completes within 2 seconds
- [ ] Cost calculation completes within 1 second
- [ ] Order confirmation generated within 30 seconds
- [ ] Out of stock items handled gracefully
- [ ] Payment failure recovery working
- [ ] Address validation functioning
- [ ] Free shipping upgrade logic implemented
- [ ] All acceptance criteria verified through automated tests
- [ ] User experience tested and approved
- [ ] Performance requirements validated under load
- [ ] Error handling tested for all scenarios
```

## Domain-Specific Templates

### Regulatory Compliance (Healthcare/Finance)

```yaml
# HIPAA Compliance Requirements
REQ-HIPAA-001:
  template: ubiquitous
  requirement: "The system shall encrypt all Protected Health Information (PHI) using FIPS 140-2 Level 2 validated encryption."
  acceptance_criteria:
    - given: "PHI data is processed or stored"
      when: "Encryption is applied"
      then: "FIPS 140-2 Level 2 validated encryption is used"

REQ-HIPAA-002:
  template: unwanted_behavior
  requirement: "IF unauthorized access to PHI is attempted, THEN the system shall deny access, log the violation, and notify the HIPAA security officer within 1 hour."
  acceptance_criteria:
    - given: "User lacks authorization for specific PHI"
      when: "Access is attempted"
      then: "Access denied, violation logged, and security officer notified within 1 hour"

# SOX Compliance Requirements
REQ-SOX-001:
  template: ubiquitous
  requirement: "The system shall maintain immutable audit logs of all financial data modifications for 7 years."
  acceptance_criteria:
    - given: "Financial data is modified"
      when: "Changes are saved"
      then: "Immutable audit log entry is created and retained for 7+ years"

REQ-SOX-002:
  template: complex
  requirement: "IF financial data changes exceed $10,000 in value, THEN WHEN the change is submitted, the system shall require dual approval before committing the transaction."
  acceptance_criteria:
    - given: "Financial change exceeds $10,000"
      when: "Change is submitted"
      then: "Dual approval is required before transaction commits"
```

### Real-time Systems (Gaming/Trading)

```yaml
# Real-time Gaming Requirements
REQ-GAME-001:
  template: ubiquitous
  requirement: "The system shall maintain server tick rate of 128 Hz for competitive gameplay."
  acceptance_criteria:
    - given: "Game server is running competitive mode"
      when: "Server processes game updates"
      then: "Tick rate is consistently 128 Hz or higher"

REQ-GAME-002:
  template: event_driven
  requirement: "WHEN a player action is received, the system shall process and broadcast the action to all relevant clients within 16 milliseconds."
  acceptance_criteria:
    - given: "Player action is received by server"
      when: "Action processing begins"
      then: "Action is processed and broadcast within 16ms"

# High-frequency Trading Requirements
REQ-HFT-001:
  template: ubiquitous
  requirement: "The system shall maintain order processing latency below 10 microseconds for market orders."
  acceptance_criteria:
    - given: "Market order is received"
      when: "Order processing occurs"
      then: "Total latency is below 10 microseconds"

REQ-HFT-002:
  template: unwanted_behavior
  requirement: "IF market data latency exceeds 1 millisecond, THEN the system shall immediately halt algorithmic trading and alert risk management."
  acceptance_criteria:
    - given: "Market data latency exceeds 1ms"
      when: "Latency threshold is breached"
      then: "Algorithmic trading halts and risk management is alerted immediately"
```

### Manufacturing and Process Control

```yaml
# Manufacturing Control Requirements
REQ-MFG-001:
  template: state_driven
  requirement: "WHILE production line is operational, the system shall monitor sensor readings every 100 milliseconds and maintain quality control parameters."
  acceptance_criteria:
    - given: "Production line is running"
      when: "System monitoring is active"
      then: "Sensor readings captured every 100ms and quality parameters maintained"

REQ-MFG-002:
  template: unwanted_behavior
  requirement: "IF any safety sensor indicates hazardous conditions, THEN the system shall immediately execute emergency shutdown procedures and alert safety personnel."
  acceptance_criteria:
    - given: "Safety sensor detects hazardous condition"
      when: "Sensor alarm is triggered"
      then: "Emergency shutdown executes immediately and safety personnel are alerted"

REQ-MFG-003:
  template: complex
  requirement: "IF production quality metrics fall below acceptable thresholds, THEN WHEN the next quality checkpoint is reached, the system shall isolate affected products and adjust process parameters automatically."
  acceptance_criteria:
    - given: "Quality metrics below threshold"
      when: "Quality checkpoint is reached"
      then: "Affected products isolated and process parameters adjusted automatically"
```

## Template Combination Patterns

### Workflow-based Requirements

```markdown
# Multi-step Process Example: Loan Application Processing

## Primary Workflow
1. **Event-driven:** WHEN a customer submits a loan application, the system shall validate required documents within 30 seconds.

2. **Unwanted Behavior:** IF required documents are missing, THEN the system shall notify the customer and pause application processing.

3. **Event-driven:** WHEN document validation succeeds, the system shall initiate credit score verification within 1 minute.

4. **Unwanted Behavior:** IF credit score is below minimum threshold, THEN the system shall automatically decline the application and send notification.

5. **Complex:** IF credit score is marginal (620-680), THEN WHEN additional income verification is provided, the system shall escalate to manual underwriting review.

6. **State-driven:** WHILE application is under manual review, the system shall send status updates to the customer every 48 hours.

7. **Event-driven:** WHEN final approval decision is made, the system shall generate loan documents and send to customer within 2 hours.

## Supporting Requirements
8. **Ubiquitous:** The system shall encrypt all loan application data using AES-256 encryption.

9. **Optional:** WHERE electronic signature capability is available, the system shall enable digital document signing.

10. **Unwanted Behavior:** IF loan documents are not signed within 30 days, THEN the system shall expire the approval and archive the application.
```

### State Machine Requirements

```markdown
# Order State Management Example

## State Transitions
1. **Event-driven:** WHEN a customer places an order, the system shall create the order in "Pending" state within 2 seconds.

2. **Event-driven:** WHEN payment is confirmed, the system shall transition the order to "Processing" state and notify fulfillment center.

3. **State-driven:** WHILE order is in "Processing" state, the system shall prevent any customer modifications to order contents.

4. **Event-driven:** WHEN items are shipped, the system shall transition order to "Shipped" state and send tracking information to customer.

5. **Unwanted Behavior:** IF shipment tracking shows delivery failure, THEN the system shall transition to "Delivery Failed" state and initiate customer contact.

6. **Complex:** IF order is in "Shipped" state, THEN WHEN customer requests return, the system shall generate return authorization and transition to "Return Initiated" state.

## State-specific Rules
7. **Ubiquitous:** The system shall maintain complete state transition history for all orders.

8. **Optional:** WHERE express processing is available, the system shall prioritize express orders in fulfillment queue.

9. **Unwanted Behavior:** IF order remains in "Pending" state for more than 24 hours, THEN the system shall escalate to customer service for investigation.
```

## Navigation

← [Best Practices](best-practices.md) | [User Stories Integration →](user-stories-integration.md)

---

*Template examples based on real-world implementations across multiple industries, demonstrating practical application of EARS notation in diverse business contexts.*