# Template Examples: RxJS Reactive Programming

Production-ready code templates and examples for implementing reactive patterns in educational technology applications. These templates provide complete, testable implementations that can be adapted for your specific use cases.

## EdTech Application Templates

### 1. Real-Time Quiz System

#### Complete Quiz Service Implementation
```typescript
import { 
  Observable, 
  BehaviorSubject, 
  Subject, 
  WebSocketSubject, 
  combineLatest, 
  timer 
} from 'rxjs';
import { 
  map, 
  filter, 
  switchMap, 
  takeUntil, 
  share, 
  tap, 
  catchError 
} from 'rxjs/operators';

export interface QuizQuestion {
  id: string;
  text: string;
  options: string[];
  correctAnswer: number;
  timeLimit: number;
  points: number;
}

export interface QuizState {
  quizId: string;
  currentQuestion: QuizQuestion | null;
  questionIndex: number;
  totalQuestions: number;
  timeRemaining: number;
  score: number;
  participants: number;
  isActive: boolean;
}

export interface AnswerSubmission {
  userId: string;
  questionId: string;
  answer: number;
  timeSpent: number;
  timestamp: number;
}

export class LiveQuizService {
  private socket$: WebSocketSubject<any>;
  private quizStateSubject = new BehaviorSubject<QuizState | null>(null);
  private answersSubject = new Subject<AnswerSubmission>();
  private destroy$ = new Subject<void>();
  
  // Public observables
  public quizState$ = this.quizStateSubject.asObservable();
  public answers$ = this.answersSubject.asObservable();
  
  // Derived observables
  public currentQuestion$ = this.quizState$.pipe(
    map(state => state?.currentQuestion || null)
  );
  
  public timeRemaining$ = this.quizState$.pipe(
    map(state => state?.timeRemaining || 0)
  );
  
  public isQuizActive$ = this.quizState$.pipe(
    map(state => state?.isActive || false)
  );
  
  public progress$ = this.quizState$.pipe(
    map(state => {
      if (!state) return 0;
      return (state.questionIndex / state.totalQuestions) * 100;
    })
  );
  
  constructor(private quizId: string) {
    this.socket$ = new WebSocketSubject({
      url: `wss://quiz-api.example.com/quiz/${quizId}`,
      openObserver: {
        next: () => console.log('Connected to quiz WebSocket')
      },
      closeObserver: {
        next: () => console.log('Disconnected from quiz WebSocket')
      }
    });
    
    this.setupWebSocketHandlers();
  }
  
  private setupWebSocketHandlers(): void {
    this.socket$.pipe(
      takeUntil(this.destroy$),
      share()
    ).subscribe({
      next: message => this.handleWebSocketMessage(message),
      error: error => console.error('WebSocket error:', error)
    });
  }
  
  private handleWebSocketMessage(message: any): void {
    switch (message.type) {
      case 'QUIZ_STATE_UPDATE':
        this.quizStateSubject.next(message.data);
        break;
        
      case 'ANSWER_SUBMITTED':
        this.answersSubject.next(message.data);
        break;
        
      case 'QUIZ_ENDED':
        const currentState = this.quizStateSubject.value;
        if (currentState) {
          this.quizStateSubject.next({
            ...currentState,
            isActive: false
          });
        }
        break;
    }
  }
  
  // Join quiz
  joinQuiz(userId: string): Observable<QuizState> {
    this.socket$.next({
      type: 'JOIN_QUIZ',
      data: { userId, quizId: this.quizId }
    });
    
    return this.quizState$.pipe(
      filter(state => state !== null),
      map(state => state!),
      take(1)
    );
  }
  
  // Submit answer
  submitAnswer(userId: string, questionId: string, answer: number): void {
    const timestamp = Date.now();
    const currentState = this.quizStateSubject.value;
    
    if (!currentState || !currentState.isActive) {
      console.warn('Cannot submit answer: Quiz is not active');
      return;
    }
    
    const submission: AnswerSubmission = {
      userId,
      questionId,
      answer,
      timeSpent: 0, // Calculate based on question start time
      timestamp
    };
    
    this.socket$.next({
      type: 'SUBMIT_ANSWER',
      data: submission
    });
  }
  
  // Disconnect and cleanup
  disconnect(): void {
    this.destroy$.next();
    this.destroy$.complete();
    this.socket$.complete();
  }
}

// Usage Example
const quizService = new LiveQuizService('quiz-123');

// Join quiz and start listening for updates
quizService.joinQuiz('user-456').subscribe(initialState => {
  console.log('Joined quiz:', initialState);
});

// Subscribe to quiz state changes
quizService.quizState$.subscribe(state => {
  if (state) {
    updateQuizUI(state);
  }
});

// Submit answers on button click
document.getElementById('submitAnswer')?.addEventListener('click', () => {
  quizService.submitAnswer('user-456', 'question-1', 2);
});
```

#### Quiz Timer Component (React)
```typescript
import React, { useEffect, useState } from 'react';
import { interval, takeWhile, map } from 'rxjs';

interface QuizTimerProps {
  duration: number; // in seconds
  onTimeUp: () => void;
  isPaused?: boolean;
}

export const QuizTimer: React.FC<QuizTimerProps> = ({ 
  duration, 
  onTimeUp, 
  isPaused = false 
}) => {
  const [timeRemaining, setTimeRemaining] = useState(duration);
  const [progress, setProgress] = useState(100);
  
  useEffect(() => {
    if (isPaused) return;
    
    const startTime = Date.now();
    const endTime = startTime + (timeRemaining * 1000);
    
    const timer$ = interval(100).pipe(
      map(() => Math.max(0, Math.ceil((endTime - Date.now()) / 1000))),
      takeWhile(remaining => remaining > 0, true)
    );
    
    const subscription = timer$.subscribe({
      next: remaining => {
        setTimeRemaining(remaining);
        setProgress((remaining / duration) * 100);
      },
      complete: onTimeUp
    });
    
    return () => subscription.unsubscribe();
  }, [duration, onTimeUp, isPaused, timeRemaining]);
  
  const formatTime = (seconds: number): string => {
    const minutes = Math.floor(seconds / 60);
    const remainingSeconds = seconds % 60;
    return `${minutes}:${remainingSeconds.toString().padStart(2, '0')}`;
  };
  
  const getColorClass = (): string => {
    if (progress > 50) return 'text-green-600';
    if (progress > 20) return 'text-yellow-600';
    return 'text-red-600';
  };
  
  return (
    <div className="quiz-timer">
      <div className={`text-2xl font-bold ${getColorClass()}`}>
        {formatTime(timeRemaining)}
      </div>
      <div className="w-full bg-gray-200 rounded-full h-2 mt-2">
        <div 
          className={`h-2 rounded-full transition-all duration-100 ${
            progress > 50 ? 'bg-green-600' : 
            progress > 20 ? 'bg-yellow-600' : 'bg-red-600'
          }`}
          style={{ width: `${progress}%` }}
        />
      </div>
    </div>
  );
};
```

### 2. User Progress Tracking System

#### Progress Service Implementation
```typescript
import { 
  BehaviorSubject, 
  Observable, 
  from, 
  of, 
  combineLatest 
} from 'rxjs';
import { 
  map, 
  switchMap, 
  debounceTime, 
  distinctUntilChanged, 
  tap, 
  catchError 
} from 'rxjs/operators';

export interface UserProgress {
  userId: string;
  totalLessonsCompleted: number;
  totalTimeSpent: number; // in seconds
  currentStreak: number;
  longestStreak: number;
  level: number;
  experiencePoints: number;
  badges: Badge[];
  weeklyGoal: number;
  weeklyProgress: number;
  lastActivity: Date;
  completedLessons: LessonProgress[];
}

export interface LessonProgress {
  lessonId: string;
  completedAt: Date;
  timeSpent: number;
  score?: number;
  attempts: number;
}

export interface Badge {
  id: string;
  name: string;
  description: string;
  iconUrl: string;
  earnedAt: Date;
}

export class UserProgressService {
  private progressSubject = new BehaviorSubject<UserProgress>(this.getEmptyProgress());
  private syncingSubject = new BehaviorSubject<boolean>(false);
  private lastSyncTime = 0;
  
  // Public observables
  public progress$ = this.progressSubject.asObservable();
  public isSyncing$ = this.syncingSubject.asObservable();
  
  // Computed observables
  public level$ = this.progress$.pipe(
    map(progress => this.calculateLevel(progress.experiencePoints)),
    distinctUntilChanged()
  );
  
  public nextLevelProgress$ = this.progress$.pipe(
    map(progress => {
      const currentLevel = this.calculateLevel(progress.experiencePoints);
      const currentLevelXP = this.getXPForLevel(currentLevel);
      const nextLevelXP = this.getXPForLevel(currentLevel + 1);
      const progressXP = progress.experiencePoints - currentLevelXP;
      const totalNeeded = nextLevelXP - currentLevelXP;
      
      return {
        currentLevel,
        nextLevel: currentLevel + 1,
        progress: (progressXP / totalNeeded) * 100,
        xpNeeded: nextLevelXP - progress.experiencePoints
      };
    })
  );
  
  public weeklyGoalProgress$ = this.progress$.pipe(
    map(progress => ({
      completed: progress.weeklyProgress,
      total: progress.weeklyGoal,
      percentage: (progress.weeklyProgress / progress.weeklyGoal) * 100
    }))
  );
  
  public isStreakActive$ = this.progress$.pipe(
    map(progress => {
      const today = new Date();
      const lastActivity = new Date(progress.lastActivity);
      const daysDiff = Math.floor((today.getTime() - lastActivity.getTime()) / (1000 * 60 * 60 * 24));
      return daysDiff <= 1;
    })
  );
  
  constructor(
    private userId: string,
    private apiService: ApiService,
    private storageService: StorageService
  ) {
    this.initializeProgress();
    this.setupAutoSync();
  }
  
  private async initializeProgress(): Promise<void> {
    try {
      // Try to load from local storage first
      const cachedProgress = await this.storageService.getProgress(this.userId);
      if (cachedProgress) {
        this.progressSubject.next(cachedProgress);
      }
      
      // Then sync with server
      await this.syncProgress();
    } catch (error) {
      console.error('Failed to initialize progress:', error);
    }
  }
  
  private setupAutoSync(): void {
    // Auto-sync every 30 seconds when there are changes
    this.progress$.pipe(
      debounceTime(30000),
      distinctUntilChanged((prev, curr) => JSON.stringify(prev) === JSON.stringify(curr)),
      switchMap(() => this.performSync())
    ).subscribe({
      error: error => console.error('Auto-sync failed:', error)
    });
  }
  
  // Complete a lesson
  completeLesson(
    lessonId: string, 
    timeSpent: number, 
    score?: number
  ): Observable<UserProgress> {
    const currentProgress = this.progressSubject.value;
    const now = new Date();
    
    // Check if lesson already completed today
    const alreadyCompleted = currentProgress.completedLessons.some(
      lesson => lesson.lessonId === lessonId && 
      this.isSameDay(new Date(lesson.completedAt), now)
    );
    
    const lessonProgress: LessonProgress = {
      lessonId,
      completedAt: now,
      timeSpent,
      score,
      attempts: 1
    };
    
    const updatedProgress: UserProgress = {
      ...currentProgress,
      totalLessonsCompleted: alreadyCompleted ? 
        currentProgress.totalLessonsCompleted : 
        currentProgress.totalLessonsCompleted + 1,
      totalTimeSpent: currentProgress.totalTimeSpent + timeSpent,
      experiencePoints: currentProgress.experiencePoints + this.calculateXP(score, timeSpent),
      currentStreak: this.calculateStreak(currentProgress, now),
      weeklyProgress: this.calculateWeeklyProgress(currentProgress, now),
      lastActivity: now,
      completedLessons: [...currentProgress.completedLessons, lessonProgress]
    };
    
    // Check for new badges
    const newBadges = this.checkForNewBadges(currentProgress, updatedProgress);
    if (newBadges.length > 0) {
      updatedProgress.badges = [...updatedProgress.badges, ...newBadges];
    }
    
    this.progressSubject.next(updatedProgress);
    this.saveToLocalStorage(updatedProgress);
    
    return of(updatedProgress);
  }
  
  // Manual sync with server
  syncProgress(): Observable<UserProgress> {
    return this.performSync();
  }
  
  private performSync(): Observable<UserProgress> {
    this.syncingSubject.next(true);
    
    return from(this.apiService.syncUserProgress(this.userId, this.progressSubject.value)).pipe(
      tap(serverProgress => {
        this.progressSubject.next(serverProgress);
        this.saveToLocalStorage(serverProgress);
        this.lastSyncTime = Date.now();
      }),
      catchError(error => {
        console.error('Sync failed:', error);
        return of(this.progressSubject.value);
      }),
      tap(() => this.syncingSubject.next(false))
    );
  }
  
  private calculateLevel(experiencePoints: number): number {
    // Simple level calculation: 100 XP per level
    return Math.floor(experiencePoints / 100) + 1;
  }
  
  private getXPForLevel(level: number): number {
    return (level - 1) * 100;
  }
  
  private calculateXP(score?: number, timeSpent?: number): number {
    let xp = 10; // Base XP for completion
    
    if (score) {
      xp += Math.floor(score * 0.5); // Bonus XP based on score
    }
    
    if (timeSpent && timeSpent < 300) { // Less than 5 minutes
      xp += 5; // Speed bonus
    }
    
    return xp;
  }
  
  private calculateStreak(currentProgress: UserProgress, now: Date): number {
    const lastActivity = new Date(currentProgress.lastActivity);
    const daysDiff = Math.floor((now.getTime() - lastActivity.getTime()) / (1000 * 60 * 60 * 24));
    
    if (daysDiff <= 1) {
      return currentProgress.currentStreak + (daysDiff === 1 ? 1 : 0);
    } else {
      return 1; // Reset streak
    }
  }
  
  private calculateWeeklyProgress(currentProgress: UserProgress, now: Date): number {
    const weekStart = this.getWeekStart(now);
    const weeklyLessons = currentProgress.completedLessons.filter(
      lesson => new Date(lesson.completedAt) >= weekStart
    );
    
    return weeklyLessons.length;
  }
  
  private checkForNewBadges(oldProgress: UserProgress, newProgress: UserProgress): Badge[] {
    const badges: Badge[] = [];
    const now = new Date();
    
    // First lesson badge
    if (oldProgress.totalLessonsCompleted === 0 && newProgress.totalLessonsCompleted === 1) {
      badges.push({
        id: 'first-lesson',
        name: 'First Steps',
        description: 'Complete your first lesson',
        iconUrl: '/badges/first-lesson.png',
        earnedAt: now
      });
    }
    
    // Streak badges
    if (newProgress.currentStreak >= 7 && oldProgress.currentStreak < 7) {
      badges.push({
        id: 'week-streak',
        name: 'Week Warrior',
        description: 'Study for 7 days in a row',
        iconUrl: '/badges/week-streak.png',
        earnedAt: now
      });
    }
    
    // Level up badges
    const oldLevel = this.calculateLevel(oldProgress.experiencePoints);
    const newLevel = this.calculateLevel(newProgress.experiencePoints);
    
    if (newLevel > oldLevel && newLevel % 5 === 0) {
      badges.push({
        id: `level-${newLevel}`,
        name: `Level ${newLevel} Master`,
        description: `Reach level ${newLevel}`,
        iconUrl: `/badges/level-${newLevel}.png`,
        earnedAt: now
      });
    }
    
    return badges;
  }
  
  private isSameDay(date1: Date, date2: Date): boolean {
    return date1.toDateString() === date2.toDateString();
  }
  
  private getWeekStart(date: Date): Date {
    const start = new Date(date);
    const day = start.getDay();
    const diff = start.getDate() - day;
    return new Date(start.setDate(diff));
  }
  
  private async saveToLocalStorage(progress: UserProgress): Promise<void> {
    try {
      await this.storageService.saveProgress(this.userId, progress);
    } catch (error) {
      console.error('Failed to save progress to local storage:', error);
    }
  }
  
  private getEmptyProgress(): UserProgress {
    return {
      userId: this.userId,
      totalLessonsCompleted: 0,
      totalTimeSpent: 0,
      currentStreak: 0,
      longestStreak: 0,
      level: 1,
      experiencePoints: 0,
      badges: [],
      weeklyGoal: 5,
      weeklyProgress: 0,
      lastActivity: new Date(),
      completedLessons: []
    };
  }
}

// Usage Example with React Hook
export function useUserProgress(userId: string) {
  const [progressService] = useState(() => 
    new UserProgressService(userId, apiService, storageService)
  );
  
  const [progress, setProgress] = useState<UserProgress | null>(null);
  const [levelInfo, setLevelInfo] = useState<any>(null);
  const [weeklyGoal, setWeeklyGoal] = useState<any>(null);
  
  useEffect(() => {
    const subscriptions = [
      progressService.progress$.subscribe(setProgress),
      progressService.nextLevelProgress$.subscribe(setLevelInfo),
      progressService.weeklyGoalProgress$.subscribe(setWeeklyGoal)
    ];
    
    return () => subscriptions.forEach(sub => sub.unsubscribe());
  }, [progressService]);
  
  const completeLesson = useCallback(
    (lessonId: string, timeSpent: number, score?: number) => {
      return progressService.completeLesson(lessonId, timeSpent, score);
    },
    [progressService]
  );
  
  return {
    progress,
    levelInfo,
    weeklyGoal,
    completeLesson,
    syncProgress: () => progressService.syncProgress()
  };
}
```

### 3. Real-Time Search with Debouncing

#### Smart Search Service
```typescript
import { 
  Observable, 
  Subject, 
  BehaviorSubject, 
  combineLatest, 
  of 
} from 'rxjs';
import { 
  debounceTime, 
  distinctUntilChanged, 
  switchMap, 
  map, 
  startWith, 
  catchError, 
  share, 
  filter 
} from 'rxjs/operators';

export interface SearchResult {
  id: string;
  title: string;
  description: string;
  type: 'course' | 'lesson' | 'quiz' | 'user';
  relevanceScore: number;
  thumbnail?: string;
  url: string;
}

export interface SearchFilters {
  type?: string[];
  difficulty?: string[];
  duration?: {
    min?: number;
    max?: number;
  };
  rating?: number;
}

export interface SearchState {
  query: string;
  filters: SearchFilters;
  results: SearchResult[];
  loading: boolean;
  hasMore: boolean;
  totalCount: number;
  error: string | null;
}

export class SmartSearchService {
  private searchQuerySubject = new Subject<string>();
  private searchFiltersSubject = new BehaviorSubject<SearchFilters>({});
  private loadingSubject = new BehaviorSubject<boolean>(false);
  private resultsSubject = new BehaviorSubject<SearchResult[]>([]);
  private errorSubject = new BehaviorSubject<string | null>(null);
  
  // Public observables
  public searchState$: Observable<SearchState>;
  public suggestions$: Observable<string[]>;
  public recentSearches$: Observable<string[]>;
  
  constructor(
    private searchApi: SearchApiService,
    private storageService: StorageService
  ) {
    this.setupSearchStream();
    this.setupSuggestions();
    this.setupRecentSearches();
    this.setupSearchState();
  }
  
  private setupSearchStream(): void {
    // Main search stream with debouncing and deduplication
    this.searchQuerySubject.pipe(
      debounceTime(300), // Wait 300ms after user stops typing
      distinctUntilChanged(), // Only search if query actually changed
      filter(query => query.length >= 2 || query.length === 0), // Min 2 chars or empty
      switchMap(query => this.performSearch(query)), // Cancel previous search
      share() // Share the result among multiple subscribers
    ).subscribe({
      next: results => {
        this.resultsSubject.next(results);
        this.loadingSubject.next(false);
        this.errorSubject.next(null);
      },
      error: error => {
        this.errorSubject.next(error.message);
        this.loadingSubject.next(false);
        this.resultsSubject.next([]);
      }
    });
  }
  
  private setupSuggestions(): void {
    this.suggestions$ = this.searchQuerySubject.pipe(
      debounceTime(150), // Faster for suggestions
      distinctUntilChanged(),
      filter(query => query.length >= 1),
      switchMap(query => this.getSuggestions(query)),
      startWith([]),
      catchError(() => of([]))
    );
  }
  
  private setupRecentSearches(): void {
    this.recentSearches$ = from(this.storageService.getRecentSearches()).pipe(
      startWith([])
    );
  }
  
  private setupSearchState(): void {
    this.searchState$ = combineLatest([
      this.searchQuerySubject.pipe(startWith('')),
      this.searchFiltersSubject,
      this.resultsSubject,
      this.loadingSubject,
      this.errorSubject
    ]).pipe(
      map(([query, filters, results, loading, error]) => ({
        query,
        filters,
        results,
        loading,
        hasMore: results.length > 0 && results.length % 20 === 0, // Assume 20 per page
        totalCount: results.length,
        error
      }))
    );
  }
  
  // Public methods
  search(query: string): void {
    this.loadingSubject.next(true);
    this.searchQuerySubject.next(query);
    
    // Save to recent searches
    if (query.length >= 2) {
      this.saveRecentSearch(query);
    }
  }
  
  updateFilters(filters: SearchFilters): void {
    this.searchFiltersSubject.next(filters);
    
    // Re-trigger search with current query
    const currentQuery = this.getCurrentQuery();
    if (currentQuery) {
      this.search(currentQuery);
    }
  }
  
  clearSearch(): void {
    this.searchQuerySubject.next('');
    this.resultsSubject.next([]);
    this.errorSubject.next(null);
  }
  
  loadMore(): Observable<SearchResult[]> {
    const currentResults = this.resultsSubject.value;
    const currentQuery = this.getCurrentQuery();
    const currentFilters = this.searchFiltersSubject.value;
    
    if (!currentQuery) {
      return of([]);
    }
    
    return this.searchApi.search(currentQuery, {
      ...currentFilters,
      offset: currentResults.length,
      limit: 20
    }).pipe(
      tap(newResults => {
        const combinedResults = [...currentResults, ...newResults];
        this.resultsSubject.next(combinedResults);
      }),
      catchError(error => {
        this.errorSubject.next(error.message);
        return of([]);
      })
    );
  }
  
  private performSearch(query: string): Observable<SearchResult[]> {
    if (!query) {
      return of([]);
    }
    
    const filters = this.searchFiltersSubject.value;
    
    return this.searchApi.search(query, {
      ...filters,
      offset: 0,
      limit: 20
    }).pipe(
      catchError(error => {
        console.error('Search failed:', error);
        throw error;
      })
    );
  }
  
  private getSuggestions(query: string): Observable<string[]> {
    return this.searchApi.getSuggestions(query).pipe(
      catchError(() => of([]))
    );
  }
  
  private async saveRecentSearch(query: string): Promise<void> {
    try {
      const recent = await this.storageService.getRecentSearches();
      const updated = [query, ...recent.filter(q => q !== query)].slice(0, 10);
      await this.storageService.saveRecentSearches(updated);
    } catch (error) {
      console.error('Failed to save recent search:', error);
    }
  }
  
  private getCurrentQuery(): string {
    // This would need to be implemented based on your state management
    return '';
  }
}

// React Hook for Search
export function useSmartSearch() {
  const [searchService] = useState(() => 
    new SmartSearchService(searchApiService, storageService)
  );
  
  const [searchState, setSearchState] = useState<SearchState>({
    query: '',
    filters: {},
    results: [],
    loading: false,
    hasMore: false,
    totalCount: 0,
    error: null
  });
  
  const [suggestions, setSuggestions] = useState<string[]>([]);
  const [recentSearches, setRecentSearches] = useState<string[]>([]);
  
  useEffect(() => {
    const subscriptions = [
      searchService.searchState$.subscribe(setSearchState),
      searchService.suggestions$.subscribe(setSuggestions),
      searchService.recentSearches$.subscribe(setRecentSearches)
    ];
    
    return () => subscriptions.forEach(sub => sub.unsubscribe());
  }, [searchService]);
  
  const search = useCallback(
    (query: string) => searchService.search(query),
    [searchService]
  );
  
  const updateFilters = useCallback(
    (filters: SearchFilters) => searchService.updateFilters(filters),
    [searchService]
  );
  
  const loadMore = useCallback(
    () => searchService.loadMore(),
    [searchService]
  );
  
  const clearSearch = useCallback(
    () => searchService.clearSearch(),
    [searchService]
  );
  
  return {
    searchState,
    suggestions,
    recentSearches,
    search,
    updateFilters,
    loadMore,
    clearSearch
  };
}

// Search Component Example
export const SearchComponent: React.FC = () => {
  const {
    searchState,
    suggestions,
    recentSearches,
    search,
    updateFilters,
    loadMore,
    clearSearch
  } = useSmartSearch();
  
  const [showSuggestions, setShowSuggestions] = useState(false);
  const [inputValue, setInputValue] = useState('');
  
  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const value = e.target.value;
    setInputValue(value);
    search(value);
    setShowSuggestions(value.length > 0);
  };
  
  const handleSuggestionClick = (suggestion: string) => {
    setInputValue(suggestion);
    search(suggestion);
    setShowSuggestions(false);
  };
  
  return (
    <div className="search-container">
      {/* Search Input */}
      <div className="relative">
        <input
          type="text"
          value={inputValue}
          onChange={handleInputChange}
          placeholder="Search courses, lessons, quizzes..."
          className="w-full p-3 border rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
        />
        
        {searchState.loading && (
          <div className="absolute right-3 top-3">
            <div className="animate-spin h-5 w-5 border-2 border-blue-500 border-t-transparent rounded-full" />
          </div>
        )}
        
        {/* Suggestions Dropdown */}
        {showSuggestions && (suggestions.length > 0 || recentSearches.length > 0) && (
          <div className="absolute top-full left-0 right-0 bg-white border rounded-lg shadow-lg mt-1 z-10">
            {suggestions.length > 0 && (
              <div>
                <div className="px-3 py-2 text-sm font-semibold text-gray-600">Suggestions</div>
                {suggestions.map(suggestion => (
                  <button
                    key={suggestion}
                    onClick={() => handleSuggestionClick(suggestion)}
                    className="w-full text-left px-3 py-2 hover:bg-gray-100"
                  >
                    {suggestion}
                  </button>
                ))}
              </div>
            )}
            
            {recentSearches.length > 0 && inputValue === '' && (
              <div>
                <div className="px-3 py-2 text-sm font-semibold text-gray-600 border-t">Recent Searches</div>
                {recentSearches.map(recent => (
                  <button
                    key={recent}
                    onClick={() => handleSuggestionClick(recent)}
                    className="w-full text-left px-3 py-2 hover:bg-gray-100"
                  >
                    {recent}
                  </button>
                ))}
              </div>
            )}
          </div>
        )}
      </div>
      
      {/* Search Results */}
      <div className="mt-4">
        {searchState.error && (
          <div className="text-red-600 mb-4">
            Error: {searchState.error}
          </div>
        )}
        
        {searchState.results.length > 0 && (
          <div>
            <div className="text-sm text-gray-600 mb-4">
              Found {searchState.totalCount} results for "{searchState.query}"
            </div>
            
            <div className="space-y-4">
              {searchState.results.map(result => (
                <div key={result.id} className="border rounded-lg p-4 hover:shadow-md">
                  <h3 className="font-semibold text-lg">{result.title}</h3>
                  <p className="text-gray-600 mt-1">{result.description}</p>
                  <div className="flex items-center mt-2 space-x-2">
                    <span className="text-xs bg-blue-100 text-blue-800 px-2 py-1 rounded">
                      {result.type}
                    </span>
                    <span className="text-xs text-gray-500">
                      Score: {result.relevanceScore.toFixed(2)}
                    </span>
                  </div>
                </div>
              ))}
            </div>
            
            {searchState.hasMore && (
              <button
                onClick={() => loadMore()}
                className="mt-4 px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-600"
              >
                Load More
              </button>
            )}
          </div>
        )}
        
        {searchState.query && searchState.results.length === 0 && !searchState.loading && (
          <div className="text-center py-8 text-gray-500">
            No results found for "{searchState.query}"
          </div>
        )}
      </div>
    </div>
  );
};
```

### 4. Offline-First Data Synchronization

#### Offline Sync Service
```typescript
import { 
  Observable, 
  BehaviorSubject, 
  Subject, 
  merge, 
  from, 
  of, 
  timer 
} from 'rxjs';
import { 
  switchMap, 
  catchError, 
  filter, 
  map, 
  tap, 
  retry, 
  delayWhen 
} from 'rxjs/operators';

export interface SyncableData {
  id: string;
  data: any;
  lastModified: number;
  syncStatus: 'pending' | 'syncing' | 'synced' | 'conflict' | 'error';
  version: number;
}

export interface SyncOperation {
  id: string;
  type: 'CREATE' | 'UPDATE' | 'DELETE';
  entity: string;
  data: any;
  timestamp: number;
  retryCount: number;
}

export class OfflineFirstSyncService {
  private onlineSubject = new BehaviorSubject<boolean>(navigator.onLine);
  private syncQueueSubject = new BehaviorSubject<SyncOperation[]>([]);
  private syncingSubject = new BehaviorSubject<boolean>(false);
  
  // Public observables
  public isOnline$ = this.onlineSubject.asObservable();
  public syncQueue$ = this.syncQueueSubject.asObservable();
  public isSyncing$ = this.syncingSubject.asObservable();
  
  // Connection status
  public connectionStatus$ = this.isOnline$.pipe(
    map(online => online ? 'online' : 'offline')
  );
  
  constructor(
    private localStorageService: LocalStorageService,
    private apiService: ApiService
  ) {
    this.setupNetworkListeners();
    this.setupAutoSync();
    this.loadSyncQueue();
  }
  
  private setupNetworkListeners(): void {
    window.addEventListener('online', () => {
      this.onlineSubject.next(true);
      this.triggerSync();
    });
    
    window.addEventListener('offline', () => {
      this.onlineSubject.next(false);
    });
  }
  
  private setupAutoSync(): void {
    // Auto-sync when coming online
    this.isOnline$.pipe(
      filter(online => online),
      switchMap(() => this.performSync())
    ).subscribe({
      error: error => console.error('Auto-sync failed:', error)
    });
    
    // Periodic sync when online
    timer(0, 30000).pipe( // Every 30 seconds
      filter(() => this.onlineSubject.value),
      switchMap(() => this.performSync())
    ).subscribe({
      error: error => console.error('Periodic sync failed:', error)
    });
  }
  
  // Save data locally and queue for sync
  saveData<T>(entity: string, data: T & { id: string }): Observable<T> {
    const operation: SyncOperation = {
      id: this.generateId(),
      type: 'CREATE',
      entity,
      data,
      timestamp: Date.now(),
      retryCount: 0
    };
    
    return from(this.localStorageService.save(entity, data)).pipe(
      tap(() => this.addToSyncQueue(operation)),
      map(() => data),
      tap(() => {
        if (this.onlineSubject.value) {
          this.triggerSync();
        }
      })
    );
  }
  
  // Update data locally and queue for sync
  updateData<T>(entity: string, data: T & { id: string }): Observable<T> {
    const operation: SyncOperation = {
      id: this.generateId(),
      type: 'UPDATE',
      entity,
      data,
      timestamp: Date.now(),
      retryCount: 0
    };
    
    return from(this.localStorageService.update(entity, data)).pipe(
      tap(() => this.addToSyncQueue(operation)),
      map(() => data),
      tap(() => {
        if (this.onlineSubject.value) {
          this.triggerSync();
        }
      })
    );
  }
  
  // Delete data locally and queue for sync
  deleteData(entity: string, id: string): Observable<void> {
    const operation: SyncOperation = {
      id: this.generateId(),
      type: 'DELETE',
      entity,
      data: { id },
      timestamp: Date.now(),
      retryCount: 0
    };
    
    return from(this.localStorageService.delete(entity, id)).pipe(
      tap(() => this.addToSyncQueue(operation)),
      map(() => void 0),
      tap(() => {
        if (this.onlineSubject.value) {
          this.triggerSync();
        }
      })
    );
  }
  
  // Get data (always from local storage)
  getData<T>(entity: string, id?: string): Observable<T | T[]> {
    if (id) {
      return from(this.localStorageService.get<T>(entity, id));
    } else {
      return from(this.localStorageService.getAll<T>(entity));
    }
  }
  
  // Manual sync trigger
  syncNow(): Observable<void> {
    return this.performSync();
  }
  
  private performSync(): Observable<void> {
    if (!this.onlineSubject.value || this.syncingSubject.value) {
      return of(void 0);
    }
    
    this.syncingSubject.next(true);
    const currentQueue = this.syncQueueSubject.value;
    
    if (currentQueue.length === 0) {
      this.syncingSubject.next(false);
      return of(void 0);
    }
    
    return from(this.processSyncQueue(currentQueue)).pipe(
      tap(() => this.syncingSubject.next(false)),
      catchError(error => {
        this.syncingSubject.next(false);
        console.error('Sync failed:', error);
        return of(void 0);
      })
    );
  }
  
  private async processSyncQueue(operations: SyncOperation[]): Promise<void> {
    const successfulOperations: string[] = [];
    
    for (const operation of operations) {
      try {
        await this.syncOperation(operation);
        successfulOperations.push(operation.id);
      } catch (error) {
        console.error(`Failed to sync operation ${operation.id}:`, error);
        
        // Increment retry count
        operation.retryCount++;
        
        // Remove operation if max retries reached
        if (operation.retryCount >= 3) {
          successfulOperations.push(operation.id);
          console.error(`Max retries reached for operation ${operation.id}, removing from queue`);
        }
      }
    }
    
    // Remove successful operations from queue
    if (successfulOperations.length > 0) {
      const newQueue = operations.filter(op => !successfulOperations.includes(op.id));
      this.syncQueueSubject.next(newQueue);
      await this.saveSyncQueue(newQueue);
    }
  }
  
  private async syncOperation(operation: SyncOperation): Promise<void> {
    switch (operation.type) {
      case 'CREATE':
        await this.apiService.create(operation.entity, operation.data);
        break;
      case 'UPDATE':
        await this.apiService.update(operation.entity, operation.data);
        break;
      case 'DELETE':
        await this.apiService.delete(operation.entity, operation.data.id);
        break;
    }
  }
  
  private addToSyncQueue(operation: SyncOperation): void {
    const currentQueue = this.syncQueueSubject.value;
    const newQueue = [...currentQueue, operation];
    this.syncQueueSubject.next(newQueue);
    this.saveSyncQueue(newQueue);
  }
  
  private async loadSyncQueue(): Promise<void> {
    try {
      const savedQueue = await this.localStorageService.getSyncQueue();
      if (savedQueue) {
        this.syncQueueSubject.next(savedQueue);
      }
    } catch (error) {
      console.error('Failed to load sync queue:', error);
    }
  }
  
  private async saveSyncQueue(queue: SyncOperation[]): Promise<void> {
    try {
      await this.localStorageService.saveSyncQueue(queue);
    } catch (error) {
      console.error('Failed to save sync queue:', error);
    }
  }
  
  private triggerSync(): void {
    setTimeout(() => this.performSync().subscribe(), 1000);
  }
  
  private generateId(): string {
    return `${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
  }
}

// Usage Example
const syncService = new OfflineFirstSyncService(localStorageService, apiService);

// Save lesson progress (works offline)
syncService.saveData('lesson-progress', {
  id: 'lesson-123',
  userId: 'user-456',
  completed: true,
  score: 85,
  timeSpent: 300
}).subscribe(progress => {
  console.log('Progress saved locally:', progress);
});

// Monitor sync status
syncService.isSyncing$.subscribe(syncing => {
  if (syncing) {
    showSyncingIndicator();
  } else {
    hideSyncingIndicator();
  }
});

// Monitor connection status
syncService.isOnline$.subscribe(online => {
  updateConnectionIndicator(online);
});
```

## Testing Templates

### RxJS Marble Testing Setup
```typescript
import { TestScheduler } from 'rxjs/testing';
import { of, throwError } from 'rxjs';
import { delay, map, catchError } from 'rxjs/operators';

describe('RxJS Marble Testing Examples', () => {
  let testScheduler: TestScheduler;
  
  beforeEach(() => {
    testScheduler = new TestScheduler((actual, expected) => {
      expect(actual).toEqual(expected);
    });
  });
  
  it('should test debounced search', () => {
    testScheduler.run(({ cold, hot, expectObservable }) => {
      // Simulate user typing
      const searchInput$ = hot('a-bc-d-e-f|', {
        a: 'h',
        b: 'he',
        c: 'hel',
        d: 'hell',
        e: 'hello',
        f: 'hello'
      });
      
      // Apply debouncing
      const result$ = searchInput$.pipe(
        debounceTime(300, testScheduler),
        distinctUntilChanged()
      );
      
      // Expected output (only 'hello' after 300ms of silence)
      const expectedMarble = '------e|';
      const expectedValues = { e: 'hello' };
      
      expectObservable(result$).toBe(expectedMarble, expectedValues);
    });
  });
  
  it('should test quiz timer countdown', () => {
    testScheduler.run(({ cold, expectObservable }) => {
      const timer$ = cold('a-b-c-d-e|', {
        a: 5,
        b: 4,
        c: 3,
        d: 2,
        e: 1
      });
      
      const result$ = timer$.pipe(
        map(time => ({
          timeRemaining: time,
          progress: ((5 - time) / 5) * 100,
          isExpired: time <= 0
        }))
      );
      
      expectObservable(result$).toBe('a-b-c-d-e|', {
        a: { timeRemaining: 5, progress: 0, isExpired: false },
        b: { timeRemaining: 4, progress: 20, isExpired: false },
        c: { timeRemaining: 3, progress: 40, isExpired: false },
        d: { timeRemaining: 2, progress: 60, isExpired: false },
        e: { timeRemaining: 1, progress: 80, isExpired: false }
      });
    });
  });
  
  it('should test error handling with retry', () => {
    testScheduler.run(({ cold, expectObservable }) => {
      const source$ = cold('#', null, new Error('Network error'));
      
      const result$ = source$.pipe(
        retry(2),
        catchError(() => of('fallback'))
      );
      
      expectObservable(result$.toBe('(f|)', { f: 'fallback' });
    });
  });
});
```

---

## Navigation

- ← Previous: [Testing Strategies](testing-strategies.md)
- → Next: [Troubleshooting Guide](troubleshooting-guide.md)
- ↑ Back to: [RxJS Research Overview](README.md)

---

*These templates provide production-ready implementations that can be directly adapted for educational technology applications.*