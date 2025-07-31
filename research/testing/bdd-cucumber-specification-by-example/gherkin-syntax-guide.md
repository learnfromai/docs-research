# Gherkin Syntax Guide - Language Specification & Best Practices

## 📝 Gherkin Language Overview

Gherkin is a business-readable, domain-specific language that describes software behavior without detailing implementation. It serves as documentation, automated tests, and development aid—all in one format.

### Core Design Principles

1. **Human-Readable**: Non-technical stakeholders can read and understand
2. **Structured**: Consistent format that machines can parse
3. **Collaborative**: Common language for business, development, and QA teams
4. **Living**: Documentation that stays current with the software

## 🎯 Fundamental Keywords

### Primary Structure Keywords

#### Feature
Defines a software feature with business context and value proposition.

```gherkin
Feature: Student Progress Tracking
  As an EdTech platform administrator
  I want to track student progress across multiple courses
  So that I can provide personalized learning recommendations

  Additional business context and rules can be documented here.
  This section is free-form text that provides context to the team.
```

**Best Practices:**
- Use clear, business-focused titles
- Include business value with As-a/I-want/So-that format
- Add relevant business rules or context
- Keep feature scope focused and cohesive

#### Background
Defines common steps that run before each scenario in the feature.

```gherkin
Feature: Course Assessment Management

  Background:
    Given the EdTech platform is operational
    And I am logged in as an instructor
    And I have permission to manage assessments
    And the "Advanced JavaScript" course exists with 25 enrolled students
```

**Best Practices:**
- Use for common setup across all scenarios
- Keep background steps minimal (3-5 steps maximum)
- Avoid test data creation in background
- Focus on essential context only

#### Scenario
Describes a specific behavior or business rule with concrete examples.

```gherkin
Scenario: Instructor creates timed assessment
  Given I am on the course assessment page
  And no assessments exist for this course
  When I create a new assessment with:
    | title          | JavaScript Fundamentals Quiz |
    | time_limit     | 45 minutes                  |
    | question_count | 20                          |
    | passing_score  | 70%                         |
  Then the assessment should be saved successfully
  And students should see the new assessment in their dashboard
  And the assessment should show "Draft" status
```

#### Scenario Outline
Template for data-driven scenarios with multiple examples.

```gherkin
Scenario Outline: Student assessment results calculation
  Given a student has completed an assessment
  And their score is <raw_score> out of <total_points>
  When the final grade is calculated
  Then their percentage should be <percentage>
  And their letter grade should be <letter_grade>
  And their status should be <pass_fail>

  Examples: Comprehensive scoring scenarios
    | raw_score | total_points | percentage | letter_grade | pass_fail |
    | 85        | 100         | 85%        | B            | Pass      |
    | 92        | 100         | 92%        | A-           | Pass      |
    | 65        | 100         | 65%        | D+           | Fail      |
    | 78        | 100         | 78%        | C+           | Pass      |
    | 95        | 100         | 95%        | A            | Pass      |

  Examples: Edge cases
    | raw_score | total_points | percentage | letter_grade | pass_fail |
    | 0         | 100         | 0%         | F            | Fail      |
    | 100       | 100         | 100%       | A+           | Pass      |
    | 69.5      | 100         | 70%        | C-           | Pass      |
```

### Step Keywords

#### Given
Establishes the initial context or preconditions.

```gherkin
# System state
Given the EdTech platform is running
Given the database contains 1000 student records

# User context
Given I am logged in as a premium student
Given I have completed 5 out of 10 course modules

# Data setup
Given the following courses are available:
  | name                 | price | duration |
  | JavaScript Basics    | $99   | 6 weeks  |
  | Advanced React       | $149  | 8 weeks  |
  | Node.js Fundamentals | $129  | 7 weeks  |

# Time context
Given it is currently 2:30 PM on a weekday
Given the course enrollment deadline is tomorrow
```

#### When
Describes the action or event that triggers the behavior.

```gherkin
# User actions
When I click the "Enroll Now" button
When I submit the assessment form
When I navigate to the student dashboard

# System events
When the payment processing completes
When the enrollment deadline passes
When a new student registers

# API interactions
When I send a POST request to "/api/courses" with course data
When the external grade sync service is triggered

# Time-based events
When 30 minutes have elapsed
When the assignment due date arrives
```

#### Then
Specifies the expected outcome or result.

```gherkin
# UI verification
Then I should see "Enrollment Successful" on the page
Then the course should appear in my enrolled courses list
Then the progress bar should show 60% completion

# System state verification
Then the student should be enrolled in the course
Then an enrollment confirmation email should be sent
Then the available course slots should decrease by 1

# Data verification
Then the database should contain the new enrollment record
Then the student's progress should be saved
Then the course analytics should be updated

# Error conditions
Then I should see "Payment failed" error message
Then the enrollment should not be processed
Then I should remain on the payment page
```

#### And/But
Connect multiple conditions or outcomes for better readability.

```gherkin
Scenario: Complete course module with video and quiz
  Given I am enrolled in "JavaScript Fundamentals"
  And I have completed the previous module
  And I am on the current module page
  When I watch the entire video lesson
  And I complete the practice exercises
  And I pass the module quiz with 80% or higher
  Then the module should be marked as complete
  And my overall course progress should increase
  And the next module should be unlocked
  But the final exam should remain locked until all modules are complete
```

## 🎨 Advanced Gherkin Patterns

### Data Tables

#### Simple Data Tables
```gherkin
Scenario: Create multiple student accounts
  Given I am an administrator
  When I create the following student accounts:
    | first_name | last_name | email              | program          |
    | Maria      | Santos    | maria@example.com  | Nursing          |
    | Juan       | Cruz      | juan@example.com   | Engineering      |
    | Ana        | Reyes     | ana@example.com    | Education        |
  Then all accounts should be created successfully
  And welcome emails should be sent to each student
```

#### Complex Data Structures
```gherkin
Scenario: Configure comprehensive course structure
  Given I am creating a new course
  When I set up the course with the following structure:
    | module | title                    | lessons | assessments | duration |
    | 1      | Introduction to Python   | 5       | 1           | 1 week   |
    | 2      | Variables and Data Types | 8       | 2           | 2 weeks  |
    | 3      | Control Structures       | 10      | 2           | 2 weeks  |
    | 4      | Functions and Modules    | 12      | 3           | 3 weeks  |
    | 5      | Final Project           | 3       | 1           | 1 week   |
  Then the course should have 5 modules
  And the total course duration should be 9 weeks
  And students should see a clear learning progression
```

### Doc Strings (Multi-line Text)

```gherkin
Scenario: Student submits essay assignment
  Given I am enrolled in "Creative Writing 101"
  And an essay assignment is available
  When I submit my essay with the following content:
    """
    The Impact of Technology on Modern Education
    
    Technology has revolutionized the way we approach education in the 21st century.
    From online learning platforms to interactive simulations, digital tools have
    made education more accessible, engaging, and personalized than ever before.
    
    In the context of EdTech platforms, we see unprecedented opportunities for
    learners to access high-quality educational content regardless of their
    geographical location or economic circumstances.
    """
  Then my submission should be recorded
  And the instructor should receive a notification
  And the plagiarism check should be automatically triggered
```

### Parameterized Steps

```gherkin
# Using {string} for text parameters
Given I am logged in as a "{string}" user
When I search for "{string}" in the course catalog
Then I should see courses related to "{string}"

# Using {int} for integer parameters  
Given there are {int} students enrolled in the course
When {int} more students enroll
Then the total enrollment should be {int}

# Using {float} for decimal parameters
Given the course has a rating of {float} stars
When I rate it {float} stars
Then the average rating should be {float}

# Custom parameter types
Given the course starts on {date}
And the enrollment deadline is {date}
When I check course availability on {date}
Then enrollment should be {availability-status}
```

### Tags for Organization

#### Functional Tags
```gherkin
@smoke @critical-path
Scenario: User can log in successfully

@regression @authentication  
Scenario: Password reset functionality

@integration @payment-gateway
Scenario: Process course payment

@slow @comprehensive
Scenario: Complete end-to-end learning journey
```

#### Environment Tags
```gherkin
@staging-only
Scenario: Test external API integration

@production-safe
Scenario: Verify read-only operations

@requires-premium-account
Scenario: Access premium course content
```

#### Team Ownership Tags
```gherkin
@team-frontend @ui
Scenario: Course catalog display

@team-backend @api
Scenario: Student data synchronization

@team-qa @automation
Scenario: Automated testing verification
```

## 📋 EdTech-Specific Gherkin Patterns

### Learning Management Scenarios

```gherkin
Feature: Adaptive Learning Path Management
  As an EdTech platform
  I want to adapt learning paths based on student performance
  So that each student receives personalized education

  Background:
    Given the adaptive learning engine is operational
    And student performance data is being tracked
    And learning paths are configured with difficulty levels

  @adaptive-learning @personalization
  Scenario: Struggling student receives additional support
    Given a student named "Maria" has failed 3 consecutive quizzes
    And her average score is below 60%
    And she is in the "Algebra Fundamentals" course
    When the adaptive engine analyzes her performance
    Then additional practice exercises should be recommended
    And remedial video content should be suggested
    And a tutor session should be automatically scheduled
    And her learning path should be extended by 2 weeks

  @adaptive-learning @acceleration
  Scenario: High-performing student gets advanced content
    Given a student named "Carlos" has scored 95%+ on all assessments
    And he completes modules 40% faster than average
    And he is in the "Basic Programming" course
    When the adaptive engine evaluates his progress
    Then advanced challenge problems should be unlocked
    And the next course in the sequence should be recommended
    And accelerated completion options should be presented
```

### Assessment and Grading Scenarios

```gherkin
Feature: Comprehensive Assessment Engine
  As an educational institution
  I want to provide varied assessment types
  So that student learning can be evaluated comprehensively

  Rule: Different assessment types have different scoring mechanisms

    @assessment @multiple-choice
    Scenario: Automatic scoring for multiple choice questions
      Given an assessment with 20 multiple choice questions
      And each question is worth 5 points
      And the student answers 16 questions correctly
      When the assessment is submitted
      Then the score should be calculated as 80 points
      And the percentage should be 80%
      And the grade should be "B"
      And the results should be immediately available

    @assessment @essay @manual-grading
    Scenario: Essay questions require manual grading
      Given an assessment with 3 essay questions
      And each essay is worth 10 points
      And the student submits all essays
      When the assessment is submitted
      Then the essays should be queued for manual grading
      And the student should see "Pending instructor review"
      And the instructor should receive a grading notification
      And the final score should remain "In Progress"

    @assessment @mixed-format
    Scenario Outline: Mixed assessment with various question types
      Given an assessment with the following structure:
        | question_type    | count | points_each |
        | multiple_choice  | 15    | 2          |
        | true_false      | 10    | 1          |
        | short_answer    | 5     | 4          |
      And the student scores <mc_correct> multiple choice, <tf_correct> true/false, and <sa_score> short answer points
      When the final grade is calculated
      Then the total score should be <total_score>
      And the percentage should be <percentage>

      Examples:
        | mc_correct | tf_correct | sa_score | total_score | percentage |
        | 12         | 8          | 15       | 53          | 88.3%      |
        | 10         | 6          | 12       | 38          | 63.3%      |
        | 15         | 10         | 20       | 60          | 100%       |
```

### Student Progress and Analytics

```gherkin
Feature: Student Progress Analytics
  As a student
  I want to track my learning progress
  So that I can stay motivated and identify areas for improvement

  @analytics @progress-tracking
  Scenario: Comprehensive progress dashboard
    Given I am enrolled in 3 courses:
      | course                 | completion | current_grade |
      | JavaScript Fundamentals| 75%        | A-           |
      | Database Design        | 45%        | B+           |
      | Web Development        | 90%        | A            |
    And I have been active for 6 weeks
    When I view my progress dashboard
    Then I should see my overall completion rate of 70%
    And my average grade should be "A-"
    And my weekly study time should be displayed
    And suggested study plans should be recommended
    And upcoming deadlines should be highlighted

  @analytics @performance-insights
  Scenario: Detailed performance insights
    Given I have completed 50 assignments across all courses
    And my performance data shows:
      | metric           | value |
      | avg_score        | 87%   |
      | time_per_module  | 2.5h  |
      | completion_rate  | 92%   |
      | help_requests    | 3     |
    When I access my learning analytics
    Then I should see performance trends over time
    And my strongest subject areas should be identified
    And areas needing improvement should be highlighted
    And personalized study recommendations should be provided
```

## 🎯 Business-Readable Language Patterns

### User Story Integration

```gherkin
Feature: Course Recommendation Engine
  As a student looking to advance my career
  I want to receive personalized course recommendations
  So that I can efficiently plan my learning journey

  # User Story: EDTECH-123
  # Epic: Personalized Learning Experience
  @user-story-123 @personalization
  Scenario: Career-focused course recommendations
    Given I am a student with the following profile:
      | field              | value                    |
      | career_goal        | Full Stack Developer     |
      | current_skills     | HTML, CSS, Basic JavaScript |
      | available_time     | 10 hours per week        |
      | preferred_duration | 6 months                 |
    And the platform has analyzed my learning patterns
    When I request course recommendations
    Then I should see a personalized learning path
    And the first recommended course should be "Advanced JavaScript"
    And the path should include "React Fundamentals" and "Node.js Basics"
    And each course should show expected time commitment
    And career relevance scores should be displayed
```

### Acceptance Criteria Translation

```gherkin
# Business Requirement: Students must be able to retake failed assessments
# Acceptance Criteria:
# - Students can retake assessments up to 3 times
# - There must be a 24-hour waiting period between attempts
# - The highest score is recorded
# - Premium students have unlimited retakes

Feature: Assessment Retake Policy
  As a student who didn't pass an assessment
  I want to retake the assessment to improve my score
  So that I can demonstrate my learning progress

  Rule: Standard students have limited retake attempts
  
    @retake-policy @standard-student
    Scenario: Standard student retakes assessment within limits
      Given I am a standard student
      And I failed an assessment with a score of 65%
      And I have used 1 of 3 allowed retakes
      And 24 hours have passed since my last attempt
      When I retake the assessment
      And I score 85%
      Then my recorded grade should be 85%
      And I should have 1 retake remaining
      And my course progress should reflect the passing grade

    @retake-policy @attempt-limit
    Scenario: Standard student exceeds retake limit
      Given I am a standard student
      And I have used all 3 allowed retakes
      And my highest score is 65% (failing)
      When I attempt to retake the assessment
      Then I should see "Maximum retakes exceeded" message
      And the retake button should be disabled
      And I should be directed to contact instructor

  Rule: Premium students have unlimited retakes
  
    @retake-policy @premium-student
    Scenario: Premium student has unlimited retakes
      Given I am a premium student
      And I have already retaken an assessment 5 times
      And my current score is 70%
      When I retake the assessment again
      And I score 95%
      Then my recorded grade should be 95%
      And I should still be able to retake if desired
```

## 🔧 Technical Implementation Patterns

### API Testing Scenarios

```gherkin
Feature: Student Enrollment API
  As a client application
  I want to enroll students via API
  So that integrations can manage enrollments programmatically

  @api @enrollment
  Scenario: Successful student enrollment via API
    Given the enrollment API is available
    And a course "Data Science 101" exists with 10 available spots
    And a valid student record exists for ID "student-123"
    When I send a POST request to "/api/enrollments" with:
      """json
      {
        "student_id": "student-123",
        "course_id": "data-science-101",
        "enrollment_type": "standard",
        "payment_method": "credit_card"
      }
      """
    Then the response status should be 201
    And the response should contain:
      """json
      {
        "enrollment_id": "@string@",
        "student_id": "student-123",
        "course_id": "data-science-101",
        "status": "enrolled",
        "enrollment_date": "@datetime@"
      }
      """
    And the course available spots should decrease to 9
```

### Database State Verification

```gherkin
@database @state-verification
Scenario: Course completion updates student records
  Given the following student record exists:
    | field            | value           |
    | student_id       | STU-2024-001    |
    | courses_completed| 5               |
    | total_credits    | 15              |
    | gpa             | 3.2             |
  And the student is enrolled in "Advanced Analytics" worth 4 credits
  When the student completes the course with grade "A"
  Then the database should be updated with:
    | field            | expected_value  |
    | courses_completed| 6               |
    | total_credits    | 19              |
    | gpa             | 3.4             |
  And a course completion record should be created
  And the student's transcript should be updated
```

## 📊 Reporting and Analytics Integration

### Metrics-Driven Scenarios

```gherkin
Feature: Learning Analytics Dashboard
  As an educational administrator
  I want to view comprehensive learning analytics
  So that I can make data-driven decisions about course effectiveness

  @analytics @dashboard @metrics
  Scenario: Course performance metrics calculation
    Given the following course completion data:
      | student_count | completed | avg_score | satisfaction |
      | 100          | 85        | 87%       | 4.2/5       |
    And the course has been running for 12 weeks
    And 15 students dropped out before completion
    When I view the course analytics dashboard
    Then the completion rate should show 85%
    And the dropout rate should show 15%
    And the average satisfaction should show 4.2/5
    And the performance trend should be "Above Average"
    And improvement recommendations should be provided

  @analytics @predictive
  Scenario: At-risk student identification
    Given a student has the following performance indicators:
      | metric                    | value | threshold |
      | assignment_completion     | 60%   | 80%       |
      | avg_quiz_score           | 65%   | 70%       |
      | days_since_last_login    | 7     | 3         |
      | help_requests_per_week   | 0     | 1+        |
    When the at-risk analysis runs
    Then the student should be flagged as "high risk"
    And an automated intervention should be triggered
    And the instructor should receive a notification
    And additional support resources should be recommended
```

## 🎓 Language Quality Guidelines

### Writing Excellent Gherkin

**DO:**
- Use present tense for actions
- Be specific with data and outcomes
- Focus on business behavior, not implementation
- Use consistent vocabulary across scenarios
- Include both positive and negative scenarios

**DON'T:**
- Use technical jargon in scenario descriptions
- Write implementation-specific steps
- Create overly complex scenarios
- Duplicate functionality across multiple scenarios
- Use vague or ambiguous language

### Common Anti-Patterns to Avoid

```gherkin
# BAD: Too implementation-focused
Scenario: User clicks login button
  Given I navigate to "http://localhost:3000/login"
  When I type "user@example.com" in the field with id "email"
  And I type "password123" in the field with id "password"
  And I click the button with class "login-btn"
  Then the page should redirect to "/dashboard"

# GOOD: Business behavior focused
Scenario: Student logs into learning platform
  Given I am a registered student
  When I log in with valid credentials
  Then I should see my personalized dashboard
  And my current courses should be displayed
```

```gherkin
# BAD: Overly detailed, brittle
Scenario: Create course with all details
  Given I click the "Create Course" button
  And I fill in "Course Title" with "Introduction to Programming"
  And I select "Beginner" from "Difficulty Level" dropdown
  And I fill in "Duration" with "8 weeks"
  And I fill in "Price" with "$99.99"
  And I upload file "course-image.jpg" to "Course Image"
  And I fill in "Description" with a 200-word description
  When I click "Save Course"
  Then I should see "Course created successfully"

# GOOD: Focused on essential behavior
Scenario: Instructor creates new course
  Given I am an instructor with course creation permissions
  When I create a course with:
    | title      | Introduction to Programming |
    | difficulty | Beginner                   |
    | duration   | 8 weeks                    |
    | price      | $99.99                     |
  Then the course should be available in the catalog
  And students should be able to enroll
```

---

**Next Steps**: Review [Testing Strategies](./testing-strategies.md) for BDD implementation patterns or [Team Collaboration](./team-collaboration.md) for collaborative specification writing.

**Practice Resources**: Consider using online Gherkin editors and validators to practice writing well-structured scenarios before implementing them in your BDD framework.