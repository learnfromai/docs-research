# Template Examples - Ready-to-Use BDD Scenarios

## 🎯 Overview

This collection provides ready-to-use BDD scenario templates specifically designed for EdTech platforms and educational software development. Each template includes context, implementation examples, and customization guidance.

## 📚 EdTech Core Feature Templates

### User Authentication & Account Management

#### Template 1: Student Registration
```gherkin
Feature: Student Account Registration
  As a prospective student
  I want to create an account on the EdTech platform
  So that I can access courses and track my learning progress

  Background:
    Given the registration system is operational
    And email verification service is available

  @registration @happy-path
  Scenario: Successful student registration
    Given I am on the registration page
    When I provide valid registration information:
      | field           | value                    |
      | first_name      | [STUDENT_FIRST_NAME]     |
      | last_name       | [STUDENT_LAST_NAME]      |
      | email           | [VALID_EMAIL]            |
      | password        | [SECURE_PASSWORD]        |
      | program         | [ACADEMIC_PROGRAM]       |
      | year_level      | [ACADEMIC_YEAR]          |
    And I agree to the terms and conditions
    Then my account should be created successfully
    And I should receive a verification email
    And I should be redirected to the email verification page

  @registration @validation
  Scenario Outline: Registration validation errors
    Given I am on the registration page
    When I submit registration with <field> as "<invalid_value>"
    Then I should see error message "<error_message>"
    And my account should not be created

    Examples:
      | field      | invalid_value        | error_message                |
      | email      | invalid-email        | Please enter a valid email   |
      | password   | 123                  | Password must be at least 8 characters |
      | first_name | ""                   | First name is required       |
      | program    | ""                   | Please select a program      |

  @registration @duplicate
  Scenario: Registration with existing email
    Given a student account exists with email "[EXISTING_EMAIL]"
    When I attempt to register with the same email
    Then I should see "An account with this email already exists"
    And I should be offered options to login or reset password
```

**Customization Guide**:
- Replace bracketed placeholders with your specific values
- Adjust academic programs to match your institution
- Modify validation rules based on your requirements
- Add institution-specific fields (student ID format, campus selection)

#### Template 2: Password Reset Flow
```gherkin
Feature: Password Reset
  As a registered student
  I want to reset my forgotten password
  So that I can regain access to my account

  @password-reset @email-flow
  Scenario: Password reset via email
    Given I am a registered student with email "[STUDENT_EMAIL]"
    And I have forgotten my password
    When I request a password reset for "[STUDENT_EMAIL]"
    Then I should receive a password reset email within 5 minutes
    And the email should contain a secure reset link
    And the reset link should expire in 24 hours

  @password-reset @secure-reset
  Scenario: Complete password reset process
    Given I received a valid password reset email
    When I click the reset link
    And I enter a new secure password
    And I confirm the new password
    Then my password should be updated successfully
    And I should be automatically logged in
    And the reset link should become invalid
    And I should receive a confirmation email about the password change
```

### Course Management & Enrollment

#### Template 3: Course Enrollment Process
```gherkin
Feature: Course Enrollment
  As a qualified student
  I want to enroll in courses
  So that I can begin my learning journey

  Background:
    Given I am a registered and verified student
    And the course catalog is available

  @enrollment @prerequisites
  Scenario: Enroll in course with prerequisites met
    Given the course "[COURSE_NAME]" requires "[PREREQUISITE_COURSE]"
    And I have completed "[PREREQUISITE_COURSE]" with grade "[MINIMUM_GRADE]" or better
    And the course has available enrollment spots
    When I enroll in "[COURSE_NAME]"
    Then my enrollment should be approved immediately
    And I should receive enrollment confirmation
    And the course should appear in my enrolled courses list
    And I should have access to course materials

  @enrollment @capacity-limits
  Scenario: Course enrollment capacity management
    Given the "[POPULAR_COURSE]" has only 1 spot remaining
    And 50 students are already enrolled
    When I successfully enroll in the course
    Then the available spots should show 0
    And the course should display as "Full" to other students
    And new enrollment attempts should add students to waiting list

  @enrollment @payment-required
  Scenario Outline: Paid course enrollment
    Given I want to enroll in a course costing <amount>
    When I proceed with enrollment using <payment_method>
    Then the payment should be <payment_status>
    And my enrollment should be <enrollment_status>
    And I should receive <confirmation_type>

    Examples:
      | amount | payment_method | payment_status | enrollment_status | confirmation_type    |
      | $299   | valid_card    | processed      | confirmed        | payment_receipt      |
      | $299   | expired_card  | declined       | pending          | payment_failure_notice |
      | $0     | n/a           | n/a            | confirmed        | enrollment_confirmation |
```

#### Template 4: Course Progress Tracking
```gherkin
Feature: Course Progress Tracking
  As an enrolled student
  I want to track my progress through course materials
  So that I can monitor my learning advancement

  Background:
    Given I am enrolled in "[COURSE_NAME]"
    And the course has [TOTAL_MODULES] modules
    And each module contains lessons and assessments

  @progress @lesson-completion
  Scenario: Complete individual lesson
    Given I am on lesson [LESSON_NUMBER] of module [MODULE_NUMBER]
    And the lesson contains [CONTENT_TYPES] (video, reading, exercises)
    When I complete all lesson activities
    And I mark the lesson as complete
    Then my progress should update to show lesson completion
    And the next lesson should be unlocked
    And my overall course progress should increase

  @progress @module-completion
  Scenario: Complete entire module
    Given I am in module [MODULE_NUMBER] of "[COURSE_NAME]"
    And the module has [LESSONS_COUNT] lessons and [ASSESSMENT_COUNT] assessment
    When I complete all lessons with satisfactory understanding
    And I pass the module assessment with [PASSING_SCORE]% or higher
    Then the module should be marked as complete
    And I should earn [POINTS_EARNED] experience points
    And the next module should be unlocked
    And my transcript should reflect the module completion

  @progress @analytics
  Scenario: View detailed progress analytics
    Given I have been studying "[COURSE_NAME]" for [TIME_PERIOD]
    And I have completed [COMPLETED_MODULES] of [TOTAL_MODULES] modules
    When I view my progress dashboard
    Then I should see my completion percentage
    And I should see time spent studying per module
    And I should see my performance trends
    And I should see estimated time to completion
    And I should see areas that need improvement
```

### Assessment & Evaluation

#### Template 5: Online Quiz Assessment
```gherkin
Feature: Online Quiz Assessment
  As a student taking a course
  I want to complete quizzes to test my knowledge
  So that I can evaluate my understanding and receive feedback

  Background:
    Given I am enrolled in "[COURSE_NAME]"
    And a quiz is available for module "[MODULE_NAME]"
    And the quiz has [QUESTION_COUNT] questions
    And the time limit is [TIME_LIMIT] minutes

  @assessment @quiz-taking
  Scenario: Complete timed quiz successfully
    Given I start the "[QUIZ_NAME]" quiz
    And the timer begins counting down from [TIME_LIMIT] minutes
    When I answer all [QUESTION_COUNT] questions
    And I submit the quiz before time expires
    Then my answers should be saved successfully
    And my score should be calculated automatically
    And I should see immediate feedback on my performance
    And incorrect answers should show correct explanations

  @assessment @time-management
  Scenario: Quiz auto-submission at time limit
    Given I am taking a timed quiz with [TIME_LIMIT] minutes
    And I have answered [ANSWERED_COUNT] of [TOTAL_QUESTIONS] questions
    When the time limit expires
    Then the quiz should be automatically submitted
    And only answered questions should be scored
    And unanswered questions should be marked as incorrect
    And I should receive partial credit for completed work

  @assessment @retake-policy
  Scenario Outline: Quiz retake attempts
    Given I am a <student_type> student
    And I completed a quiz with score <initial_score>%
    And the passing score is <passing_score>%
    When I attempt to retake the quiz
    Then I should <retake_permission>
    And my <score_policy> should apply

    Examples:
      | student_type | initial_score | passing_score | retake_permission | score_policy        |
      | standard     | 65           | 70            | be allowed 2 more attempts | highest score recorded |
      | premium      | 65           | 70            | be allowed unlimited attempts | highest score recorded |
      | standard     | 85           | 70            | be allowed to retake for improvement | highest score recorded |
```

#### Template 6: Comprehensive Final Exam
```gherkin
Feature: Comprehensive Final Examination
  As a student completing a course
  I want to take a comprehensive final exam
  So that I can demonstrate my mastery of course materials

  Background:
    Given I have completed all course modules
    And I have met the prerequisites for final exam eligibility
    And the final exam is available for "[EXAM_PERIOD]"

  @final-exam @eligibility
  Scenario: Final exam eligibility verification
    Given I am enrolled in "[COURSE_NAME]"
    When I attempt to start the final exam
    Then the system should verify I have completed [REQUIRED_MODULES]% of modules
    And I should have achieved minimum [REQUIRED_AVERAGE]% average on module quizzes
    And I should have no outstanding assignments
    And if eligible, I should be able to start the exam
    And if ineligible, I should see specific requirements not met

  @final-exam @proctored
  Scenario: Proctored online final exam
    Given I am taking a proctored final exam
    And identity verification is required
    When I start the exam session
    Then I should verify my identity using [VERIFICATION_METHOD]
    And the proctor should confirm my testing environment
    And screen monitoring should be activated
    And I should receive exam instructions and honor code
    And the exam timer should start only after all verifications

  @final-exam @technical-issues
  Scenario: Handle technical difficulties during exam
    Given I am 30 minutes into a 120-minute final exam
    And I have completed 25 of 100 questions
    When I experience a technical issue (network disruption, browser crash)
    Then my progress should be automatically saved every 2 minutes
    And I should be able to resume the exam after issue resolution
    And my remaining time should be preserved
    And technical support should be immediately available
    And the incident should be logged for review
```

### Learning Analytics & Reporting

#### Template 7: Student Performance Dashboard
```gherkin
Feature: Student Performance Dashboard
  As a student
  I want to view comprehensive analytics of my learning performance
  So that I can identify strengths, weaknesses, and improvement opportunities

  Background:
    Given I am an active student with course enrollment history
    And I have completed assessments and learning activities
    And analytics data is available for the past [TIME_PERIOD]

  @analytics @overview
  Scenario: View overall performance summary
    Given I access my performance dashboard
    When the dashboard loads
    Then I should see my overall GPA across all courses
    And I should see my total completed courses and credits
    And I should see my current active courses and progress
    And I should see my learning streak and study habits
    And I should see upcoming deadlines and scheduled activities

  @analytics @course-specific
  Scenario: Drill down into specific course performance
    Given I select "[SPECIFIC_COURSE]" from my course list
    When I view detailed course analytics
    Then I should see my progress through course modules
    And I should see my scores on all assessments and quizzes
    And I should see time spent on different learning activities
    And I should see my performance compared to course averages
    And I should see personalized recommendations for improvement

  @analytics @predictive
  Scenario: Receive predictive insights and recommendations
    Given my learning data shows specific patterns
    When the analytics engine processes my performance data
    Then I should receive predictions about my likely success in current courses
    And I should see recommendations for additional study time
    And I should be alerted to courses where I'm at risk of falling behind
    And I should receive suggestions for optimal study schedules
    And I should see recommended resources for challenging topics
```

### Communication & Support

#### Template 8: Student Support System
```gherkin
Feature: Student Support and Help System
  As a student facing challenges
  I want to access support resources and get help
  So that I can overcome obstacles and succeed in my studies

  Background:
    Given I am a registered student with active enrollment
    And support resources are available 24/7
    And multiple support channels exist (chat, email, phone, forums)

  @support @help-request
  Scenario: Submit general help request
    Given I am experiencing a problem with "[PROBLEM_CATEGORY]"
    When I submit a help request through the support portal
    And I provide detailed description of my issue
    And I select appropriate priority level
    Then I should receive an immediate acknowledgment with ticket number
    And I should receive estimated response time based on priority
    And I should be able to track the status of my request
    And I should receive updates as my ticket progresses

  @support @live-chat
  Scenario: Use live chat for immediate assistance
    Given I need immediate help during business hours
    When I initiate a live chat session
    Then I should be connected to a support agent within [RESPONSE_TIME] minutes
    And the agent should have access to my student profile and course history
    And the agent should be able to screen-share for technical issues
    And our conversation should be saved for future reference
    And I should receive a chat transcript via email after the session

  @support @peer-forums
  Scenario: Participate in peer support forums
    Given I have a course-related question
    When I post my question in the appropriate course forum
    Then other students and instructors should be able to respond
    And I should receive notifications when replies are posted
    And helpful answers should be marked as solutions
    And forum participation should contribute to my engagement score
    And moderators should ensure discussions remain constructive
```

## 🔧 Technical Integration Templates

### API Testing Templates

#### Template 9: RESTful API Course Management
```gherkin
Feature: Course Management API
  As a client application
  I want to manage courses via REST API
  So that integrations can handle course data programmatically

  Background:
    Given the Course Management API is available at "[API_BASE_URL]"
    And I have valid API authentication credentials
    And API rate limiting allows [REQUESTS_PER_MINUTE] requests per minute

  @api @course-creation
  Scenario: Create new course via API
    Given I have instructor privileges
    When I send a POST request to "/api/courses" with:
      """json
      {
        "title": "[COURSE_TITLE]",
        "description": "[COURSE_DESCRIPTION]",
        "duration_weeks": [DURATION],
        "max_students": [CAPACITY],
        "price": [COST],
        "category": "[CATEGORY]",
        "difficulty_level": "[LEVEL]"
      }
      """
    Then the response status should be 201
    And the response should contain the new course ID
    And the course should be retrievable via GET request
    And the course should appear in the course catalog

  @api @course-enrollment
  Scenario: Enroll student via API
    Given a course with ID "[COURSE_ID]" exists
    And a student with ID "[STUDENT_ID]" exists
    And the course has available capacity
    When I send a POST request to "/api/enrollments" with:
      """json
      {
        "student_id": "[STUDENT_ID]",
        "course_id": "[COURSE_ID]",
        "enrollment_type": "standard"
      }
      """
    Then the response status should be 201
    And the enrollment should be confirmed
    And the student should appear in the course roster
    And the course capacity should decrease by 1

  @api @error-handling
  Scenario Outline: API error handling
    Given the API is operational
    When I send a <method> request to "<endpoint>" with <data_condition>
    Then the response status should be <status_code>
    And the response should contain error message "<error_message>"
    And the response should include error code "<error_code>"

    Examples:
      | method | endpoint          | data_condition     | status_code | error_message              | error_code |
      | POST   | /api/courses      | invalid_data       | 400         | Validation failed          | INVALID_DATA |
      | GET    | /api/courses/999  | non_existent_id    | 404         | Course not found          | RESOURCE_NOT_FOUND |
      | POST   | /api/enrollments  | duplicate_enrollment| 409         | Student already enrolled  | DUPLICATE_ENROLLMENT |
```

### Mobile Application Templates

#### Template 10: Mobile Learning App
```gherkin
Feature: Mobile Learning Application
  As a student using a mobile device
  I want to access course content on my smartphone
  So that I can learn anywhere, anytime

  Background:
    Given I have the EdTech mobile app installed
    And I am logged into my student account
    And I have internet connectivity

  @mobile @offline-sync
  Scenario: Download content for offline access
    Given I am connected to WiFi
    And I am enrolled in "[COURSE_NAME]"
    When I select "Download for Offline" for the course
    Then the course videos should download to my device
    And reading materials should be cached locally
    And quiz questions should be available offline
    And I should see download progress indicators
    And downloaded content should be accessible without internet

  @mobile @responsive-design
  Scenario: Responsive course content on mobile
    Given I am viewing course content on a [DEVICE_SIZE] screen
    When I navigate through lessons and materials
    Then text should be readable without horizontal scrolling
    And videos should resize appropriately for the screen
    And interactive elements should be touch-friendly
    And navigation should be accessible with one hand
    And loading times should be optimized for mobile networks

  @mobile @push-notifications
  Scenario: Receive learning reminders and updates
    Given I have enabled push notifications
    And I have personalized my notification preferences
    When scheduled study time arrives
    Or assignment deadlines approach
    Or new course content is available
    Then I should receive relevant push notifications
    And notifications should include actionable quick links
    And I should be able to snooze or dismiss notifications
    And notification frequency should respect my preferences
```

## 🎯 Specialized EdTech Scenarios

### Compliance & Accessibility Templates

#### Template 11: WCAG Accessibility Compliance
```gherkin
Feature: Web Content Accessibility Guidelines (WCAG) Compliance
  As a student with disabilities
  I want the platform to be fully accessible
  So that I can participate equally in online learning

  Background:
    Given the platform aims for WCAG 2.1 AA compliance
    And accessibility features are enabled by default

  @accessibility @screen-reader
  Scenario: Screen reader navigation
    Given I am using a screen reader
    When I navigate through course content
    Then all content should be announced clearly
    And headings should be properly structured (H1, H2, H3)
    And images should have descriptive alt text
    And form fields should have associated labels
    And focus indicators should be clearly visible
    And skip links should be available for main content

  @accessibility @keyboard-navigation
  Scenario: Keyboard-only navigation
    Given I cannot use a mouse or touch interface
    When I navigate using only keyboard controls
    Then all interactive elements should be reachable via Tab key
    And the tab order should be logical and predictable
    And I should be able to activate buttons with Enter or Space
    And dropdown menus should be accessible with arrow keys
    And I should be able to escape modal dialogs with Esc key

  @accessibility @visual-impairments
  Scenario: Support for visual impairments
    Given I have low vision or color blindness
    When I access course materials
    Then text should maintain 4.5:1 contrast ratio with background
    And I should be able to zoom content up to 200% without horizontal scrolling
    And color should not be the only way to convey information
    And focus indicators should have sufficient contrast
    And essential graphics should have high-contrast alternatives
```

#### Template 12: Data Privacy & FERPA Compliance
```gherkin
Feature: Student Data Privacy and FERPA Compliance
  As an educational institution
  I want to protect student privacy according to FERPA regulations
  So that we maintain legal compliance and student trust

  Background:
    Given the platform handles personally identifiable student information
    And FERPA regulations apply to all student data
    And privacy controls are implemented at all system levels

  @privacy @ferpa @consent
  Scenario: Directory information disclosure consent
    Given a student is creating their profile
    When they reach the privacy settings section
    Then they should see clear explanation of directory information
    And they should be able to opt-out of directory information sharing
    And their choice should be clearly recorded and timestamped
    And they should be able to change their preference at any time
    And opt-out should be honored within 24 hours

  @privacy @data-access
  Scenario: Student right to access personal data
    Given I am a registered student
    When I request access to my personal data held by the institution
    Then I should receive a complete report within 30 days
    And the report should include all categories of personal information
    And it should show who has accessed my data and when
    And it should explain how my data is used
    And it should provide instructions for corrections or deletions

  @privacy @audit-trail
  Scenario: Maintain comprehensive audit trail
    Given student data is accessed by authorized personnel
    When any personal information is viewed, modified, or exported
    Then the action should be logged with:
      | field              | requirement                    |
      | user_id           | Staff member or system ID      |
      | timestamp         | Exact date and time            |
      | action_type       | View/Edit/Export/Delete        |
      | data_category     | Type of information accessed   |
      | justification     | Educational purpose code       |
      | ip_address        | Source of access               |
    And logs should be tamper-proof and encrypted
    And logs should be retained for required legal period
    And unauthorized access attempts should trigger alerts
```

### International & Localization Templates

#### Template 13: Multi-Language Support
```gherkin
Feature: Multi-Language Learning Platform
  As a non-native English speaker
  I want to access course content in my preferred language
  So that I can learn more effectively

  Background:
    Given the platform supports multiple languages
    And content is available in [SUPPORTED_LANGUAGES]
    And my preferred language is set to "[USER_LANGUAGE]"

  @localization @content-translation
  Scenario: Access course content in preferred language
    Given I have selected "[PREFERRED_LANGUAGE]" as my interface language
    And course "[COURSE_NAME]" is available in "[PREFERRED_LANGUAGE]"
    When I access the course materials
    Then the course interface should display in "[PREFERRED_LANGUAGE]"
    And lesson content should be in "[PREFERRED_LANGUAGE]"
    And assessment questions should be translated
    And system messages should appear in "[PREFERRED_LANGUAGE]"
    And help documentation should be localized

  @localization @cultural-adaptation
  Scenario: Culturally appropriate content presentation
    Given I am from "[COUNTRY/REGION]"
    And cultural adaptation is enabled
    When I view course examples and case studies
    Then examples should include local context where appropriate
    And cultural references should be relevant to my region
    And date/time formats should match local conventions
    And currency should be displayed in local format
    And names and scenarios should reflect cultural diversity

  @localization @rtl-languages
  Scenario: Right-to-left language support
    Given I have selected a right-to-left language like Arabic or Hebrew
    When I navigate through the platform
    Then the entire interface should be mirrored appropriately
    And text should flow from right to left
    And navigation elements should be repositioned
    And progress indicators should move right to left
    And all functionality should work correctly in RTL mode
```

## 🚀 Performance & Scalability Templates

#### Template 14: Load Testing Scenarios
```gherkin
Feature: Platform Performance Under Load
  As a platform administrator
  I want to ensure the system performs well under high load
  So that students have consistent access during peak times

  Background:
    Given the platform is deployed in production environment
    And monitoring tools are active
    And baseline performance metrics are established

  @performance @concurrent-users
  Scenario: Handle peak concurrent user load
    Given normal usage is [NORMAL_CONCURRENT_USERS] concurrent users
    When peak enrollment period brings [PEAK_CONCURRENT_USERS] concurrent users
    Then response times should remain under [MAX_RESPONSE_TIME] seconds
    And all user sessions should remain stable
    And no data should be lost or corrupted
    And error rates should stay below [MAX_ERROR_RATE]%
    And auto-scaling should activate additional resources

  @performance @video-streaming
  Scenario: Video content delivery under load
    Given [CONCURRENT_VIEWERS] students are watching video lectures simultaneously
    When videos are streamed at different quality levels
    Then all students should receive smooth playback
    And buffering should be less than [MAX_BUFFER_PERCENTAGE]% of viewing time
    And video quality should adapt to available bandwidth
    And CDN should efficiently distribute content globally
    And server resources should remain within acceptable limits

  @performance @assessment-submission
  Scenario: Handle simultaneous assessment submissions
    Given [STUDENTS_COUNT] students are taking the same timed exam
    When all students submit their answers within a [TIME_WINDOW]-minute window
    Then all submissions should be processed successfully
    And no submissions should be lost
    And response times should remain acceptable
    And database performance should not degrade
    And students should receive immediate confirmation
```

---

**Usage Instructions**: 
1. Copy the relevant template to your feature files
2. Replace bracketed placeholders with your specific values
3. Customize scenarios based on your business rules
4. Add or remove examples as needed for your context
5. Implement corresponding step definitions

**Next Steps**: Review [Tools Ecosystem](./tools-ecosystem.md) for implementation tools or [Framework Integration](./framework-integration.md) for technical setup guidance.