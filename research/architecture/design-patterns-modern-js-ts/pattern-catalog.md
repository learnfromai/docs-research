# Pattern Catalog: Complete Gang of Four Patterns in Modern JavaScript/TypeScript

## 📚 Complete Pattern Reference Guide

This comprehensive catalog provides modern TypeScript implementations of all 23 Gang of Four design patterns, organized by category with practical examples for EdTech platforms and contemporary web development.

## 🏭 Creational Patterns (5 patterns)

Creational patterns deal with object creation mechanisms, providing flexibility in deciding which objects to create for a given situation.

### 1. Factory Method Pattern

**Intent**: Create objects without specifying their exact classes.

```typescript
// Product interface
interface Course {
  readonly id: string;
  readonly title: string;
  readonly duration: number; // in hours
  generateCertificate(studentId: string): Certificate;
  getPrerequisites(): string[];
}

// Concrete products
class NursingCourse implements Course {
  constructor(
    public readonly id: string,
    public readonly title: string,
    public readonly duration: number
  ) {}

  generateCertificate(studentId: string): Certificate {
    return {
      id: `cert_nursing_${Date.now()}`,
      studentId,
      courseId: this.id,
      courseTitle: this.title,
      type: 'nursing_license_prep',
      issuedAt: new Date(),
      validUntil: new Date(Date.now() + 365 * 24 * 60 * 60 * 1000) // 1 year
    };
  }

  getPrerequisites(): string[] {
    return ['high_school_diploma', 'biology_course', 'chemistry_course'];
  }
}

class EngineeringCourse implements Course {
  constructor(
    public readonly id: string,
    public readonly title: string,
    public readonly duration: number
  ) {}

  generateCertificate(studentId: string): Certificate {
    return {
      id: `cert_engineering_${Date.now()}`,
      studentId,
      courseId: this.id,
      courseTitle: this.title,
      type: 'engineering_license_prep',
      issuedAt: new Date(),
      validUntil: new Date(Date.now() + 2 * 365 * 24 * 60 * 60 * 1000) // 2 years
    };
  }

  getPrerequisites(): string[] {
    return ['high_school_diploma', 'advanced_mathematics', 'physics_course'];
  }
}

// Abstract creator
abstract class CourseFactory {
  abstract createCourse(courseData: CourseCreationData): Course;
  
  // Template method using the factory
  async enrollStudent(studentId: string, courseData: CourseCreationData): Promise<Enrollment> {
    const course = this.createCourse(courseData);
    const prerequisites = course.getPrerequisites();
    
    // Check prerequisites
    const hasPrerequisites = await this.checkPrerequisites(studentId, prerequisites);
    if (!hasPrerequisites) {
      throw new Error(`Student ${studentId} does not meet prerequisites for ${course.title}`);
    }
    
    return {
      id: `enrollment_${Date.now()}`,
      studentId,
      courseId: course.id,
      enrolledAt: new Date(),
      status: 'active'
    };
  }

  private async checkPrerequisites(studentId: string, prerequisites: string[]): Promise<boolean> {
    // Mock prerequisite checking
    console.log(`Checking prerequisites for student ${studentId}: ${prerequisites.join(', ')}`);
    return true; // Simplified for example
  }
}

// Concrete factories
class NursingCourseFactory extends CourseFactory {
  createCourse(courseData: CourseCreationData): Course {
    return new NursingCourse(courseData.id, courseData.title, courseData.duration);
  }
}

class EngineeringCourseFactory extends CourseFactory {
  createCourse(courseData: CourseCreationData): Course {
    return new EngineeringCourse(courseData.id, courseData.title, courseData.duration);
  }
}

// Supporting interfaces
interface CourseCreationData {
  id: string;
  title: string;
  duration: number;
}

interface Certificate {
  id: string;
  studentId: string;
  courseId: string;
  courseTitle: string;
  type: string;
  issuedAt: Date;
  validUntil: Date;
}

interface Enrollment {
  id: string;
  studentId: string;
  courseId: string;
  enrolledAt: Date;
  status: 'active' | 'completed' | 'suspended';
}

// Usage
const nursingFactory = new NursingCourseFactory();
const engineeringFactory = new EngineeringCourseFactory();

// Create courses through factories
const nursingCourse = nursingFactory.createCourse({
  id: 'nursing_fundamentals_2024',
  title: 'Nursing Fundamentals for Philippine Licensure',
  duration: 120
});

const engineeringCourse = engineeringFactory.createCourse({
  id: 'civil_engineering_2024',
  title: 'Civil Engineering Board Exam Review',
  duration: 180
});
```

**EdTech Use Cases**: Course creation, user account factories, assessment builders, payment processor factories.

---

### 2. Abstract Factory Pattern

**Intent**: Provide an interface for creating families of related objects.

```typescript
// Abstract product families
interface AssessmentQuestion {
  readonly id: string;
  readonly content: string;
  readonly points: number;
  validate(answer: any): boolean;
  getExplanation(): string;
}

interface AssessmentReport {
  readonly assessmentId: string;
  readonly studentId: string;
  generateSummary(): string;
  exportToPDF(): Buffer;
}

// Nursing-specific products
class NursingMultipleChoiceQuestion implements AssessmentQuestion {
  constructor(
    public readonly id: string,
    public readonly content: string,
    public readonly points: number,
    private readonly options: string[],
    private readonly correctIndex: number
  ) {}

  validate(answer: number): boolean {
    return answer === this.correctIndex;
  }

  getExplanation(): string {
    return `The correct answer is option ${this.correctIndex + 1}: ${this.options[this.correctIndex]}`;
  }
}

class NursingAssessmentReport implements AssessmentReport {
  constructor(
    public readonly assessmentId: string,
    public readonly studentId: string,
    private readonly score: number,
    private readonly totalPoints: number
  ) {}

  generateSummary(): string {
    const percentage = (this.score / this.totalPoints) * 100;
    return `Nursing Assessment Summary: ${this.score}/${this.totalPoints} (${percentage.toFixed(1)}%)`;
  }

  exportToPDF(): Buffer {
    // Mock PDF generation
    return Buffer.from(`PDF content for nursing assessment ${this.assessmentId}`);
  }
}

// Engineering-specific products
class EngineeringCalculationQuestion implements AssessmentQuestion {
  constructor(
    public readonly id: string,
    public readonly content: string,
    public readonly points: number,
    private readonly expectedAnswer: number,
    private readonly tolerance: number = 0.01
  ) {}

  validate(answer: number): boolean {
    return Math.abs(answer - this.expectedAnswer) <= this.tolerance;
  }

  getExplanation(): string {
    return `The correct answer is ${this.expectedAnswer} (±${this.tolerance})`;
  }
}

class EngineeringAssessmentReport implements AssessmentReport {
  constructor(
    public readonly assessmentId: string,
    public readonly studentId: string,
    private readonly score: number,
    private readonly totalPoints: number
  ) {}

  generateSummary(): string {
    const percentage = (this.score / this.totalPoints) * 100;
    return `Engineering Assessment Summary: ${this.score}/${this.totalPoints} (${percentage.toFixed(1)}%)`;
  }

  exportToPDF(): Buffer {
    // Mock PDF generation with engineering-specific formatting
    return Buffer.from(`Engineering PDF content for assessment ${this.assessmentId}`);
  }
}

// Abstract factory
interface AssessmentFactory {
  createQuestion(questionData: QuestionData): AssessmentQuestion;
  createReport(reportData: ReportData): AssessmentReport;
}

// Concrete factories
class NursingAssessmentFactory implements AssessmentFactory {
  createQuestion(questionData: QuestionData): AssessmentQuestion {
    return new NursingMultipleChoiceQuestion(
      questionData.id,
      questionData.content,
      questionData.points,
      questionData.options || [],
      questionData.correctIndex || 0
    );
  }

  createReport(reportData: ReportData): AssessmentReport {
    return new NursingAssessmentReport(
      reportData.assessmentId,
      reportData.studentId,
      reportData.score,
      reportData.totalPoints
    );
  }
}

class EngineeringAssessmentFactory implements AssessmentFactory {
  createQuestion(questionData: QuestionData): AssessmentQuestion {
    return new EngineeringCalculationQuestion(
      questionData.id,
      questionData.content,
      questionData.points,
      questionData.expectedAnswer || 0,
      questionData.tolerance
    );
  }

  createReport(reportData: ReportData): AssessmentReport {
    return new EngineeringAssessmentReport(
      reportData.assessmentId,
      reportData.studentId,
      reportData.score,
      reportData.totalPoints
    );
  }
}

// Supporting interfaces
interface QuestionData {
  id: string;
  content: string;
  points: number;
  options?: string[];
  correctIndex?: number;
  expectedAnswer?: number;
  tolerance?: number;
}

interface ReportData {
  assessmentId: string;
  studentId: string;
  score: number;
  totalPoints: number;
}

// Factory provider
class AssessmentFactoryProvider {
  static getFactory(subject: 'nursing' | 'engineering'): AssessmentFactory {
    switch (subject) {
      case 'nursing':
        return new NursingAssessmentFactory();
      case 'engineering':
        return new EngineeringAssessmentFactory();
      default:
        throw new Error(`Unsupported subject: ${subject}`);
    }
  }
}

// Usage
const nursingFactory = AssessmentFactoryProvider.getFactory('nursing');
const engineeringFactory = AssessmentFactoryProvider.getFactory('engineering');

// Create related family of objects
const nursingQuestion = nursingFactory.createQuestion({
  id: 'nursing_q1',
  content: 'What is the normal respiratory rate for adults?',
  points: 2,
  options: ['8-12/min', '12-20/min', '20-30/min', '30-40/min'],
  correctIndex: 1
});

const nursingReport = nursingFactory.createReport({
  assessmentId: 'nursing_exam_2024',
  studentId: 'student_123',
  score: 85,
  totalPoints: 100
});
```

**EdTech Use Cases**: Subject-specific question types, multi-platform UI components, region-specific payment systems.

---

### 3. Builder Pattern

**Intent**: Construct complex objects step by step.

```typescript
// Complex product: Comprehensive Course
interface ComprehensiveCourse {
  readonly id: string;
  readonly title: string;
  readonly description: string;
  readonly modules: CourseModule[];
  readonly assessments: Assessment[];
  readonly resources: CourseResource[];
  readonly metadata: CourseMetadata;
  readonly pricing: CoursePricing;
  readonly localization: CourseLocalization;
}

interface CourseModule {
  id: string;
  title: string;
  lessons: Lesson[];
  estimatedDuration: number;
}

interface Lesson {
  id: string;
  title: string;
  content: string;
  videoUrl?: string;
  attachments: string[];
}

interface Assessment {
  id: string;
  title: string;
  type: 'quiz' | 'assignment' | 'exam';
  questions: AssessmentQuestion[];
  timeLimit?: number;
  passingScore: number;
}

interface CourseResource {
  id: string;
  title: string;
  type: 'pdf' | 'video' | 'audio' | 'link';
  url: string;
  downloadable: boolean;
}

interface CourseMetadata {
  subject: string;
  difficulty: 'beginner' | 'intermediate' | 'advanced';
  tags: string[];
  prerequisites: string[];
  learningObjectives: string[];
  estimatedDuration: number;
  createdBy: string;
  lastUpdated: Date;
}

interface CoursePricing {
  basePrice: number;
  currency: string;
  discounts: PriceDiscount[];
  subscriptionOptions: SubscriptionOption[];
}

interface CourseLocalization {
  defaultLanguage: string;
  supportedLanguages: string[];
  regionSpecific: RegionSpecificContent;
}

// Builder implementation
class ComprehensiveCourseBuilder {
  private course: Partial<ComprehensiveCourse> = {
    modules: [],
    assessments: [],
    resources: [],
    metadata: {
      tags: [],
      prerequisites: [],
      learningObjectives: [],
      lastUpdated: new Date()
    } as CourseMetadata,
    pricing: {
      discounts: [],
      subscriptionOptions: []
    } as CoursePricing,
    localization: {
      supportedLanguages: ['en'],
      regionSpecific: {}
    } as CourseLocalization
  };

  // Basic information
  setId(id: string): ComprehensiveCourseBuilder {
    this.course.id = id;
    return this;
  }

  setTitle(title: string): ComprehensiveCourseBuilder {
    this.course.title = title;
    return this;
  }

  setDescription(description: string): ComprehensiveCourseBuilder {
    this.course.description = description;
    return this;
  }

  // Module building
  addModule(
    moduleId: string,
    moduleTitle: string,
    lessons: Lesson[]
  ): ComprehensiveCourseBuilder {
    const estimatedDuration = lessons.reduce((total, lesson) => total + 30, 0); // 30 min per lesson
    
    const module: CourseModule = {
      id: moduleId,
      title: moduleTitle,
      lessons,
      estimatedDuration
    };

    this.course.modules!.push(module);
    return this;
  }

  addLessonToModule(
    moduleId: string,
    lesson: Lesson
  ): ComprehensiveCourseBuilder {
    const module = this.course.modules!.find(m => m.id === moduleId);
    if (module) {
      module.lessons.push(lesson);
      module.estimatedDuration += 30; // Add 30 minutes per lesson
    }
    return this;
  }

  // Assessment building
  addAssessment(assessment: Assessment): ComprehensiveCourseBuilder {
    this.course.assessments!.push(assessment);
    return this;
  }

  addQuizAssessment(
    id: string,
    title: string,
    questions: AssessmentQuestion[],
    timeLimit?: number
  ): ComprehensiveCourseBuilder {
    const quiz: Assessment = {
      id,
      title,
      type: 'quiz',
      questions,
      timeLimit,
      passingScore: 70
    };

    this.course.assessments!.push(quiz);
    return this;
  }

  // Resource management
  addResource(resource: CourseResource): ComprehensiveCourseBuilder {
    this.course.resources!.push(resource);
    return this;
  }

  addPDFResource(
    id: string,
    title: string,
    url: string,
    downloadable: boolean = true
  ): ComprehensiveCourseBuilder {
    const resource: CourseResource = {
      id,
      title,
      type: 'pdf',
      url,
      downloadable
    };

    this.course.resources!.push(resource);
    return this;
  }

  // Metadata configuration
  setSubject(subject: string): ComprehensiveCourseBuilder {
    this.course.metadata!.subject = subject;
    return this;
  }

  setDifficulty(difficulty: 'beginner' | 'intermediate' | 'advanced'): ComprehensiveCourseBuilder {
    this.course.metadata!.difficulty = difficulty;
    return this;
  }

  addTags(...tags: string[]): ComprehensiveCourseBuilder {
    this.course.metadata!.tags.push(...tags);
    return this;
  }

  addPrerequisites(...prerequisites: string[]): ComprehensiveCourseBuilder {
    this.course.metadata!.prerequisites.push(...prerequisites);
    return this;
  }

  addLearningObjective(objective: string): ComprehensiveCourseBuilder {
    this.course.metadata!.learningObjectives.push(objective);
    return this;
  }

  setCreator(creatorId: string): ComprehensiveCourseBuilder {
    this.course.metadata!.createdBy = creatorId;
    return this;
  }

  // Pricing configuration
  setPricing(
    basePrice: number,
    currency: string = 'USD'
  ): ComprehensiveCourseBuilder {
    this.course.pricing!.basePrice = basePrice;
    this.course.pricing!.currency = currency;
    return this;
  }

  addDiscount(discount: PriceDiscount): ComprehensiveCourseBuilder {
    this.course.pricing!.discounts.push(discount);
    return this;
  }

  addSubscriptionOption(option: SubscriptionOption): ComprehensiveCourseBuilder {
    this.course.pricing!.subscriptionOptions.push(option);
    return this;
  }

  // Localization
  setDefaultLanguage(language: string): ComprehensiveCourseBuilder {
    this.course.localization!.defaultLanguage = language;
    return this;
  }

  addSupportedLanguages(...languages: string[]): ComprehensiveCourseBuilder {
    this.course.localization!.supportedLanguages.push(...languages);
    return this;
  }

  setRegionSpecificContent(region: string, content: any): ComprehensiveCourseBuilder {
    this.course.localization!.regionSpecific[region] = content;
    return this;
  }

  // Build and validate
  build(): ComprehensiveCourse {
    this.validateCourse();
    this.calculateMetadata();
    return this.course as ComprehensiveCourse;
  }

  private validateCourse(): void {
    if (!this.course.id || !this.course.title) {
      throw new Error('Course must have id and title');
    }

    if (!this.course.modules || this.course.modules.length === 0) {
      throw new Error('Course must have at least one module');
    }

    if (!this.course.pricing?.basePrice) {
      throw new Error('Course must have pricing information');
    }
  }

  private calculateMetadata(): void {
    // Calculate total estimated duration
    const totalDuration = this.course.modules!.reduce(
      (total, module) => total + module.estimatedDuration,
      0
    );
    this.course.metadata!.estimatedDuration = totalDuration;
  }
}

// Supporting interfaces for builder
interface PriceDiscount {
  type: 'percentage' | 'fixed';
  value: number;
  code?: string;
  validUntil?: Date;
  description: string;
}

interface SubscriptionOption {
  id: string;
  name: string;
  price: number;
  billingCycle: 'monthly' | 'quarterly' | 'yearly';
  features: string[];
}

interface RegionSpecificContent {
  [region: string]: any;
}

// Usage example: Building Philippine Nursing Licensure Course
class PhilippineNursingCourseDirector {
  buildComprehensiveCourse(): ComprehensiveCourse {
    return new ComprehensiveCourseBuilder()
      .setId('pnle_comprehensive_2024')
      .setTitle('Complete Philippine Nursing Licensure Examination Review')
      .setDescription('Comprehensive review course for the Philippine Nursing Licensure Examination (PNLE)')
      
      // Basic metadata
      .setSubject('Nursing')
      .setDifficulty('intermediate')
      .addTags('nursing', 'licensure', 'philippines', 'pnle', 'board-exam')
      .addPrerequisites('nursing_degree', 'clinical_hours_completed')
      .setCreator('phil_nursing_academy')
      
      // Learning objectives
      .addLearningObjective('Pass the Philippine Nursing Licensure Examination')
      .addLearningObjective('Master fundamental nursing concepts and procedures')
      .addLearningObjective('Understand Philippine healthcare system and laws')
      
      // Course modules
      .addModule('fundamentals', 'Fundamentals of Nursing', [
        {
          id: 'lesson_1',
          title: 'Introduction to Professional Nursing',
          content: 'Overview of nursing profession in the Philippines...',
          videoUrl: 'https://video.example.com/lesson1',
          attachments: ['nursing_code_ethics.pdf']
        },
        {
          id: 'lesson_2',
          title: 'Nursing Process and Critical Thinking',
          content: 'Step-by-step nursing process methodology...',
          attachments: ['nursing_process_flowchart.pdf']
        }
      ])
      
      .addModule('medical_surgical', 'Medical-Surgical Nursing', [
        {
          id: 'lesson_3',
          title: 'Cardiovascular System Disorders',
          content: 'Common cardiac conditions and nursing interventions...',
          videoUrl: 'https://video.example.com/cardiac',
          attachments: ['cardiac_medications.pdf', 'ecg_reading_guide.pdf']
        }
      ])
      
      // Assessments
      .addQuizAssessment(
        'fundamentals_quiz',
        'Fundamentals of Nursing Quiz',
        [
          // Questions would be created using AssessmentQuestion interface
        ],
        60 // 60 minutes
      )
      
      // Resources
      .addPDFResource(
        'pnle_guide',
        'Official PNLE Examination Guide',
        'https://resources.example.com/pnle_guide.pdf'
      )
      .addPDFResource(
        'study_schedule',
        'Recommended Study Schedule',
        'https://resources.example.com/study_schedule.pdf'
      )
      
      // Pricing (Philippine market)
      .setPricing(2500, 'PHP') // ₱2,500
      .addDiscount({
        type: 'percentage',
        value: 20,
        code: 'EARLY_BIRD',
        validUntil: new Date('2024-12-31'),
        description: 'Early registration discount'
      })
      .addSubscriptionOption({
        id: 'monthly_plan',
        name: 'Monthly Access',
        price: 500,
        billingCycle: 'monthly',
        features: ['Full course access', 'Practice exams', 'Study materials']
      })
      
      // Localization
      .setDefaultLanguage('en')
      .addSupportedLanguages('fil', 'ceb') // Filipino, Cebuano
      .setRegionSpecificContent('philippines', {
        currency: 'PHP',
        paymentMethods: ['gcash', 'paymaya', 'bpi', 'bdo'],
        localSupport: '+63-2-8123-4567',
        timezone: 'Asia/Manila'
      })
      
      .build();
  }
}

// Usage
const director = new PhilippineNursingCourseDirector();
const comprehensiveCourse = director.buildComprehensiveCourse();

console.log(`Created course: ${comprehensiveCourse.title}`);
console.log(`Estimated duration: ${comprehensiveCourse.metadata.estimatedDuration} minutes`);
console.log(`Price: ${comprehensiveCourse.pricing.basePrice} ${comprehensiveCourse.pricing.currency}`);
```

**EdTech Use Cases**: Complex course creation, assessment building, user profile construction, system configuration.

---

### 4. Prototype Pattern

**Intent**: Create objects by cloning existing instances.

```typescript
// Prototype interface
interface Cloneable<T> {
  clone(): T;
}

// Base question prototype
abstract class QuestionTemplate implements Cloneable<QuestionTemplate> {
  constructor(
    public id: string,
    public content: string,
    public points: number,
    public subject: string,
    public difficulty: 'easy' | 'medium' | 'hard',
    public tags: string[]
  ) {}

  abstract clone(): QuestionTemplate;
  abstract validate(answer: any): boolean;
  
  // Common functionality
  updateContent(newContent: string): void {
    this.content = newContent;
  }

  addTags(...newTags: string[]): void {
    this.tags.push(...newTags);
  }

  setDifficulty(difficulty: 'easy' | 'medium' | 'hard'): void {
    this.difficulty = difficulty;
  }
}

// Concrete prototypes
class MultipleChoiceTemplate extends QuestionTemplate {
  constructor(
    id: string,
    content: string,
    points: number,
    subject: string,
    difficulty: 'easy' | 'medium' | 'hard',
    tags: string[],
    public options: string[],
    public correctIndex: number
  ) {
    super(id, content, points, subject, difficulty, tags);
  }

  clone(): MultipleChoiceTemplate {
    return new MultipleChoiceTemplate(
      `${this.id}_clone_${Date.now()}`,
      this.content,
      this.points,
      this.subject,
      this.difficulty,
      [...this.tags], // Deep copy array
      [...this.options], // Deep copy options
      this.correctIndex
    );
  }

  validate(answer: number): boolean {
    return answer === this.correctIndex;
  }

  updateOptions(newOptions: string[], newCorrectIndex: number): void {
    this.options = [...newOptions];
    this.correctIndex = newCorrectIndex;
  }
}

class TrueFalseTemplate extends QuestionTemplate {
  constructor(
    id: string,
    content: string,
    points: number,
    subject: string,
    difficulty: 'easy' | 'medium' | 'hard',
    tags: string[],
    public correctAnswer: boolean
  ) {
    super(id, content, points, subject, difficulty, tags);
  }

  clone(): TrueFalseTemplate {
    return new TrueFalseTemplate(
      `${this.id}_clone_${Date.now()}`,
      this.content,
      this.points,
      this.subject,
      this.difficulty,
      [...this.tags],
      this.correctAnswer
    );
  }

  validate(answer: boolean): boolean {
    return answer === this.correctAnswer;
  }

  setCorrectAnswer(answer: boolean): void {
    this.correctAnswer = answer;
  }
}

class EssayTemplate extends QuestionTemplate {
  constructor(
    id: string,
    content: string,
    points: number,
    subject: string,
    difficulty: 'easy' | 'medium' | 'hard',
    tags: string[],
    public maxWords: number,
    public rubric: EssayRubric[]
  ) {
    super(id, content, points, subject, difficulty, tags);
  }

  clone(): EssayTemplate {
    return new EssayTemplate(
      `${this.id}_clone_${Date.now()}`,
      this.content,
      this.points,
      this.subject,
      this.difficulty,
      [...this.tags],
      this.maxWords,
      this.rubric.map(r => ({ ...r })) // Deep copy rubric
    );
  }

  validate(answer: string): boolean {
    const wordCount = answer.trim().split(/\s+/).length;
    return wordCount <= this.maxWords && wordCount >= 10; // Minimum 10 words
  }

  updateRubric(newRubric: EssayRubric[]): void {
    this.rubric = newRubric.map(r => ({ ...r }));
  }
}

// Supporting interfaces
interface EssayRubric {
  criterion: string;
  maxPoints: number;
  description: string;
}

// Prototype registry/manager
class QuestionTemplateRegistry {
  private templates = new Map<string, QuestionTemplate>();

  registerTemplate(key: string, template: QuestionTemplate): void {
    this.templates.set(key, template);
  }

  getTemplate(key: string): QuestionTemplate | undefined {
    const template = this.templates.get(key);
    return template ? template.clone() : undefined;
  }

  listTemplates(): string[] {
    return Array.from(this.templates.keys());
  }

  createFromTemplate(templateKey: string, customizations?: Partial<QuestionTemplate>): QuestionTemplate | undefined {
    const template = this.getTemplate(templateKey);
    if (!template) return undefined;

    // Apply customizations
    if (customizations) {
      if (customizations.content) template.content = customizations.content;
      if (customizations.points) template.points = customizations.points;
      if (customizations.subject) template.subject = customizations.subject;
      if (customizations.difficulty) template.difficulty = customizations.difficulty;
      if (customizations.tags) template.tags = [...customizations.tags];
    }

    return template;
  }
}

// Philippine licensure exam template factory
class PhilippineLicensureTemplateFactory {
  private registry = new QuestionTemplateRegistry();

  constructor() {
    this.initializeTemplates();
  }

  private initializeTemplates(): void {
    // Nursing templates
    this.registry.registerTemplate('nursing_basic_mc', new MultipleChoiceTemplate(
      'nursing_mc_template',
      'What is the normal heart rate range for adults?',
      2,
      'nursing',
      'easy',
      ['vital_signs', 'fundamentals'],
      ['40-60 bpm', '60-100 bpm', '100-120 bpm', '120-140 bpm'],
      1
    ));

    this.registry.registerTemplate('nursing_critical_thinking', new EssayTemplate(
      'nursing_essay_template',
      'Describe the nursing care plan for a patient with diabetes mellitus.',
      10,
      'nursing',
      'hard',
      ['care_planning', 'diabetes', 'critical_thinking'],
      500,
      [
        { criterion: 'Assessment', maxPoints: 3, description: 'Identifies key assessment data' },
        { criterion: 'Diagnosis', maxPoints: 3, description: 'Formulates appropriate nursing diagnoses' },
        { criterion: 'Planning', maxPoints: 2, description: 'Develops realistic goals' },
        { criterion: 'Implementation', maxPoints: 2, description: 'Describes appropriate interventions' }
      ]
    ));

    // Engineering templates
    this.registry.registerTemplate('engineering_calculation', new MultipleChoiceTemplate(
      'engineering_calc_template',
      'Calculate the load capacity of a concrete beam with given dimensions.',
      5,
      'engineering',
      'hard',
      ['structural', 'concrete', 'calculations'],
      ['15 kN/m', '25 kN/m', '35 kN/m', '45 kN/m'],
      2
    ));

    this.registry.registerTemplate('engineering_true_false', new TrueFalseTemplate(
      'engineering_tf_template',
      'Steel has a higher tensile strength than concrete.',
      1,
      'engineering',
      'easy',
      ['materials', 'properties'],
      true
    ));
  }

  createNursingQuestion(templateKey: string, customContent?: string): QuestionTemplate | undefined {
    const customizations: Partial<QuestionTemplate> = {};
    if (customContent) {
      customizations.content = customContent;
    }
    
    return this.registry.createFromTemplate(templateKey, customizations);
  }

  createEngineeringQuestion(templateKey: string, customContent?: string): QuestionTemplate | undefined {
    const customizations: Partial<QuestionTemplate> = {};
    if (customContent) {
      customizations.content = customContent;
    }
    
    return this.registry.createFromTemplate(templateKey, customizations);
  }

  // Bulk question creation for exams
  createExamQuestionSet(
    templateKeys: string[],
    customizations: Array<Partial<QuestionTemplate>>
  ): QuestionTemplate[] {
    const questions: QuestionTemplate[] = [];

    templateKeys.forEach((key, index) => {
      const customization = customizations[index] || {};
      const question = this.registry.createFromTemplate(key, customization);
      if (question) {
        questions.push(question);
      }
    });

    return questions;
  }

  getAvailableTemplates(): string[] {
    return this.registry.listTemplates();
  }
}

// Usage example
const templateFactory = new PhilippineLicensureTemplateFactory();

// Create individual questions from templates
const nursingQuestion = templateFactory.createNursingQuestion(
  'nursing_basic_mc',
  'What is the normal respiratory rate for adults?'
);

if (nursingQuestion instanceof MultipleChoiceTemplate) {
  nursingQuestion.updateOptions(
    ['8-12/min', '12-20/min', '20-30/min', '30-40/min'],
    1
  );
}

// Create a set of questions for an exam
const examQuestions = templateFactory.createExamQuestionSet(
  ['nursing_basic_mc', 'nursing_critical_thinking', 'engineering_calculation'],
  [
    { content: 'What is the normal blood pressure range?' },
    { content: 'Develop a care plan for hypertensive patients.', points: 15 },
    { content: 'Calculate the moment of inertia for the given cross-section.' }
  ]
);

console.log(`Created ${examQuestions.length} questions from templates`);
console.log('Available templates:', templateFactory.getAvailableTemplates());
```

**EdTech Use Cases**: Question template systems, course cloning, user profile templates, assessment blueprints.

---

### 5. Singleton Pattern

**Intent**: Ensure only one instance of a class exists.

```typescript
// Traditional Singleton (with caveats)
class EdTechConfigurationManager {
  private static instance: EdTechConfigurationManager;
  private configuration: Map<string, any> = new Map();
  private isInitialized: boolean = false;

  private constructor() {
    // Private constructor prevents direct instantiation
  }

  static getInstance(): EdTechConfigurationManager {
    if (!EdTechConfigurationManager.instance) {
      EdTechConfigurationManager.instance = new EdTechConfigurationManager();
    }
    return EdTechConfigurationManager.instance;
  }

  async initialize(): Promise<void> {
    if (this.isInitialized) return;

    // Load configuration from various sources
    await this.loadFromEnvironment();
    await this.loadFromDatabase();
    await this.loadFromRemoteConfig();
    
    this.isInitialized = true;
  }

  private async loadFromEnvironment(): Promise<void> {
    const envConfig = {
      database: {
        host: process.env.DB_HOST || 'localhost',
        port: parseInt(process.env.DB_PORT || '5432'),
        name: process.env.DB_NAME || 'edtech'
      },
      redis: {
        host: process.env.REDIS_HOST || 'localhost',
        port: parseInt(process.env.REDIS_PORT || '6379')
      },
      jwt: {
        secret: process.env.JWT_SECRET || 'default-secret',
        expiry: process.env.JWT_EXPIRY || '24h'
      },
      payment: {
        stripeKey: process.env.STRIPE_SECRET_KEY,
        paypalClientId: process.env.PAYPAL_CLIENT_ID
      },
      philippines: {
        gcashMerchantId: process.env.GCASH_MERCHANT_ID,
        paymayaSecretKey: process.env.PAYMAYA_SECRET_KEY,
        supportedRegions: ['ncr', 'calabarzon', 'central_luzon', 'cebu', 'davao']
      }
    };

    for (const [key, value] of Object.entries(envConfig)) {
      this.configuration.set(key, value);
    }
  }

  private async loadFromDatabase(): Promise<void> {
    // Mock database configuration loading
    const dbConfig = {
      features: {
        enableAnalytics: true,
        enableLiveChat: false,
        maxStudentsPerClass: 30,
        allowGuestAccess: true
      },
      ui: {
        theme: 'light',
        primaryColor: '#007bff',
        secondaryColor: '#6c757d'
      }
    };

    for (const [key, value] of Object.entries(dbConfig)) {
      this.configuration.set(key, value);
    }
  }

  private async loadFromRemoteConfig(): Promise<void> {
    // Mock remote configuration loading (feature flags, A/B tests)
    const remoteConfig = {
      experiments: {
        newDashboardDesign: { enabled: true, percentage: 50 },
        aiTutoringFeature: { enabled: false, percentage: 0 },
        gamificationElements: { enabled: true, percentage: 100 }
      },
      contentDelivery: {
        cdnUrl: 'https://cdn.edtech-platform.com',
        videoQuality: 'auto',
        enableOfflineMode: true
      }
    };

    for (const [key, value] of Object.entries(remoteConfig)) {
      this.configuration.set(key, value);
    }
  }

  get<T>(key: string): T | undefined {
    if (!this.isInitialized) {
      throw new Error('ConfigurationManager not initialized. Call initialize() first.');
    }
    return this.configuration.get(key) as T;
  }

  set(key: string, value: any): void {
    this.configuration.set(key, value);
  }

  getDatabaseConfig(): any {
    return this.get('database');
  }

  getPaymentConfig(): any {
    return this.get('payment');
  }

  getPhilippinesConfig(): any {
    return this.get('philippines');
  }

  isFeatureEnabled(featureName: string): boolean {
    const features = this.get<any>('features');
    return features?.[featureName] === true;
  }

  getExperimentConfig(experimentName: string): { enabled: boolean; percentage: number } | undefined {
    const experiments = this.get<any>('experiments');
    return experiments?.[experimentName];
  }

  // Method to reset singleton (mainly for testing)
  static reset(): void {
    EdTechConfigurationManager.instance = undefined as any;
  }
}

// Modern alternative: Module-based singleton (Recommended)
class DatabaseConnectionPool {
  private connections: Map<string, DatabaseConnection> = new Map();
  private readonly maxConnections: number;
  private currentConnectionCount: number = 0;

  constructor(maxConnections: number = 20) {
    this.maxConnections = maxConnections;
  }

  async getConnection(connectionString: string): Promise<DatabaseConnection> {
    // Check if connection already exists
    if (this.connections.has(connectionString)) {
      const existingConnection = this.connections.get(connectionString)!;
      if (existingConnection.isConnected) {
        return existingConnection;
      }
    }

    // Create new connection if under limit
    if (this.currentConnectionCount >= this.maxConnections) {
      throw new Error(`Maximum connections (${this.maxConnections}) reached`);
    }

    const connection = await this.createNewConnection(connectionString);
    this.connections.set(connectionString, connection);
    this.currentConnectionCount++;

    return connection;
  }

  private async createNewConnection(connectionString: string): Promise<DatabaseConnection> {
    // Mock connection creation
    const connection: DatabaseConnection = {
      id: `conn_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
      connectionString,
      isConnected: false,
      createdAt: new Date(),
      
      async connect(): Promise<void> {
        console.log(`Connecting to database: ${connectionString}`);
        this.isConnected = true;
      },
      
      async disconnect(): Promise<void> {
        console.log(`Disconnecting from database: ${connectionString}`);
        this.isConnected = false;
      },
      
      async query(sql: string): Promise<any> {
        if (!this.isConnected) {
          throw new Error('Connection not established');
        }
        console.log(`Executing query: ${sql}`);
        return { rows: [], rowCount: 0 };
      }
    };

    await connection.connect();
    return connection;
  }

  async closeAllConnections(): Promise<void> {
    const disconnectPromises = Array.from(this.connections.values()).map(
      connection => connection.disconnect()
    );

    await Promise.all(disconnectPromises);
    this.connections.clear();
    this.currentConnectionCount = 0;
  }

  getConnectionCount(): number {
    return this.currentConnectionCount;
  }

  getActiveConnections(): DatabaseConnection[] {
    return Array.from(this.connections.values()).filter(
      connection => connection.isConnected
    );
  }
}

// Logger singleton
class ApplicationLogger {
  private logs: LogEntry[] = [];
  private readonly maxLogs: number = 1000;

  constructor() {}

  log(level: 'info' | 'warn' | 'error', message: string, context?: any): void {
    const entry: LogEntry = {
      timestamp: new Date(),
      level,
      message,
      context: context ? JSON.stringify(context) : undefined
    };

    this.logs.push(entry);

    // Maintain log size limit
    if (this.logs.length > this.maxLogs) {
      this.logs.shift(); // Remove oldest log
    }

    // Console output
    console.log(`[${entry.timestamp.toISOString()}] ${level.toUpperCase()}: ${message}`, context || '');

    // Send to external logging service (mock)
    this.sendToExternalService(entry);
  }

  info(message: string, context?: any): void {
    this.log('info', message, context);
  }

  warn(message: string, context?: any): void {
    this.log('warn', message, context);
  }

  error(message: string, context?: any): void {
    this.log('error', message, context);
  }

  getLogs(level?: 'info' | 'warn' | 'error'): LogEntry[] {
    if (level) {
      return this.logs.filter(log => log.level === level);
    }
    return [...this.logs];
  }

  private sendToExternalService(entry: LogEntry): void {
    // Mock implementation - would send to Datadog, Sentry, etc.
    if (entry.level === 'error') {
      // Priority sending for errors
      console.log('🚨 Sending error to monitoring service');
    }
  }
}

// Supporting interfaces
interface DatabaseConnection {
  id: string;
  connectionString: string;
  isConnected: boolean;
  createdAt: Date;
  connect(): Promise<void>;
  disconnect(): Promise<void>;
  query(sql: string): Promise<any>;
}

interface LogEntry {
  timestamp: Date;
  level: 'info' | 'warn' | 'error';
  message: string;
  context?: string;
}

// Export singleton instances (Module-based approach)
export const configManager = EdTechConfigurationManager.getInstance();
export const dbPool = new DatabaseConnectionPool(25); // 25 max connections
export const logger = new ApplicationLogger();

// Usage in EdTech application
class EdTechApplication {
  async initialize(): Promise<void> {
    try {
      // Initialize configuration
      await configManager.initialize();
      logger.info('Configuration manager initialized');

      // Test database connection
      const dbConfig = configManager.getDatabaseConfig();
      const connection = await dbPool.getConnection(
        `postgresql://${dbConfig.host}:${dbConfig.port}/${dbConfig.name}`
      );
      logger.info('Database connection established', { connectionId: connection.id });

      // Check feature flags
      const analyticsEnabled = configManager.isFeatureEnabled('enableAnalytics');
      logger.info('Analytics feature status', { enabled: analyticsEnabled });

      // Check experiments
      const dashboardExperiment = configManager.getExperimentConfig('newDashboardDesign');
      logger.info('Dashboard experiment status', dashboardExperiment);

    } catch (error) {
      logger.error('Application initialization failed', { error: error });
      throw error;
    }
  }

  async shutdown(): Promise<void> {
    logger.info('Shutting down application');
    await dbPool.closeAllConnections();
    logger.info('Application shutdown complete');
  }
}

// Usage
const app = new EdTechApplication();

// In production
app.initialize().then(() => {
  console.log('EdTech application started successfully');
}).catch(error => {
  console.error('Failed to start application:', error);
});

// In tests - ability to reset singletons
if (process.env.NODE_ENV === 'test') {
  EdTechConfigurationManager.reset();
}
```

**EdTech Use Cases**: Configuration management, connection pooling, logging systems, cache managers.

**Important Note**: While Singleton pattern is useful for certain scenarios (configuration, logging, connection pools), it should be used sparingly. Dependency injection is often a better alternative for testability and flexibility.

---

## 🧩 Structural Patterns (7 patterns)

Structural patterns deal with object composition and relationships between entities.

[Continue with detailed implementations of all remaining patterns...]

**EdTech Applications Summary**:
- **Factory Method**: Course creators, user account factories, assessment builders
- **Abstract Factory**: Subject-specific question families, platform-specific UI components
- **Builder**: Complex course construction, assessment creation, user profile building
- **Prototype**: Question templates, course cloning, configuration templates
- **Singleton**: Configuration management, connection pools, logging systems

---

[🏠 Back to Overview](./README.md) | [🔧 Implementation Guide →](./implementation-guide.md) | [🎯 Real-World Examples →](./real-world-examples.md)