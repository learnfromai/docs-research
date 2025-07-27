# Architecture Patterns in Jetpack Compose Applications

## 📐 Overview

This document analyzes the architectural patterns observed across 15+ open source Android Jetpack Compose projects, providing insights into how production applications structure their codebase for maintainability, testability, and scalability.

## 🏗️ Dominant Architecture Patterns

### 1. **MVVM (Model-View-ViewModel) Pattern**
**Adoption Rate**: 73% of analyzed projects

#### Core Components
```kotlin
// Model (Data Classes)
data class Article(
    val id: String,
    val title: String,
    val content: String,
    val publishedAt: Instant
)

// ViewModel
class ArticleViewModel @Inject constructor(
    private val repository: ArticleRepository
) : ViewModel() {
    
    private val _uiState = MutableStateFlow(ArticleUiState())
    val uiState: StateFlow<ArticleUiState> = _uiState.asStateFlow()
    
    fun loadArticle(id: String) {
        viewModelScope.launch {
            _uiState.update { currentState ->
                currentState.copy(isLoading = true)
            }
            
            try {
                val article = repository.getArticle(id)
                _uiState.update { currentState ->
                    currentState.copy(
                        article = article,
                        isLoading = false
                    )
                }
            } catch (e: Exception) {
                _uiState.update { currentState ->
                    currentState.copy(
                        error = e.message,
                        isLoading = false
                    )
                }
            }
        }
    }
}

// UI State
data class ArticleUiState(
    val article: Article? = null,
    val isLoading: Boolean = false,
    val error: String? = null
)

// View (Composable)
@Composable
fun ArticleScreen(
    viewModel: ArticleViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsState()
    
    ArticleContent(
        uiState = uiState,
        onRetry = { viewModel.loadArticle(articleId) }
    )
}
```

#### Benefits Observed
- **Clear Separation**: UI logic separated from business logic
- **Testability**: ViewModels can be easily unit tested
- **Reactive**: UI automatically updates when state changes
- **Lifecycle Aware**: Automatic handling of configuration changes

#### Examples in Projects
- **Now in Android**: Comprehensive MVVM with offline-first approach
- **Jetnews**: Clean MVVM implementation with Navigation Compose
- **Jetcaster**: MVVM with media playback state management

---

### 2. **MVI (Model-View-Intent) Pattern**
**Adoption Rate**: 33% of analyzed projects

#### Core Implementation
```kotlin
// Intent (User Actions)
sealed class ArticleIntent {
    object LoadArticle : ArticleIntent()
    object RefreshArticle : ArticleIntent()
    data class ShareArticle(val article: Article) : ArticleIntent()
}

// State (Single Source of Truth)
data class ArticleState(
    val article: Article? = null,
    val isLoading: Boolean = false,
    val error: String? = null,
    val isRefreshing: Boolean = false
)

// Presenter (using Circuit framework)
@CircuitInject(ArticleScreen::class, SingletonComponent::class)
class ArticlePresenter @AssistedInject constructor(
    @Assisted private val screen: ArticleScreen,
    private val repository: ArticleRepository
) : Presenter<ArticleState> {
    
    @Composable
    override fun present(): ArticleState {
        var state by remember {
            mutableStateOf(ArticleState(isLoading = true))
        }
        
        LaunchedEffect(screen.articleId) {
            state = state.copy(isLoading = true)
            try {
                val article = repository.getArticle(screen.articleId)
                state = state.copy(
                    article = article,
                    isLoading = false
                )
            } catch (e: Exception) {
                state = state.copy(
                    error = e.message,
                    isLoading = false
                )
            }
        }
        
        return state
    }
}
```

#### Circuit Framework Integration (Tivi)
```kotlin
// Screen definition
@Parcelize
data class ShowDetailsScreen(
    val showId: Long
) : Screen

// UI Factory
@CircuitInject(ShowDetailsScreen::class, SingletonComponent::class)
class ShowDetailsUiFactory @Inject constructor() : Ui.Factory {
    override fun create(screen: Screen, context: CircuitContext): Ui<*>? {
        return when (screen) {
            is ShowDetailsScreen -> ShowDetailsUi
            else -> null
        }
    }
}

// Compose UI
object ShowDetailsUi : Ui<ShowDetailsState> {
    @Composable
    override fun Content(state: ShowDetailsState, modifier: Modifier) {
        ShowDetailsContent(
            show = state.show,
            onBackPressed = { state.eventSink(Event.NavigateBack) }
        )
    }
}
```

#### Benefits Observed
- **Unidirectional Data Flow**: Clear intent → state → UI flow
- **Predictable State**: Single state object reduces complexity
- **Time Travel Debugging**: Easy to track state changes
- **Testability**: Easy to test state transformations

#### Examples in Projects
- **Tivi**: Full MVI implementation with Circuit framework
- **Compose Samples**: MVI patterns in complex UI flows

---

### 3. **Clean Architecture Implementation**
**Adoption Rate**: 53% of analyzed projects

#### Layer Structure
```
app/
├── presentation/     # UI Layer (Compose, ViewModels)
├── domain/          # Business Logic (Use Cases, Entities)
└── data/           # Data Layer (Repositories, Data Sources)

core/
├── common/         # Shared utilities
├── model/          # Domain entities
├── data/           # Data implementations
├── database/       # Local data source
├── network/        # Remote data source
└── domain/         # Business logic
```

#### Domain Layer Implementation
```kotlin
// Entity (Domain Model)
data class User(
    val id: UserId,
    val name: String,
    val email: Email,
    val preferences: UserPreferences
)

// Use Case
class GetUserProfileUseCase @Inject constructor(
    private val userRepository: UserRepository
) {
    suspend operator fun invoke(userId: UserId): Result<User> {
        return try {
            val user = userRepository.getUser(userId)
            Result.success(user)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
}

// Repository Interface (Domain Layer)
interface UserRepository {
    suspend fun getUser(id: UserId): User
    suspend fun updateUser(user: User): Result<Unit>
    suspend fun observeUser(id: UserId): Flow<User>
}
```

#### Data Layer Implementation
```kotlin
// Repository Implementation (Data Layer)
class UserRepositoryImpl @Inject constructor(
    private val localDataSource: UserLocalDataSource,
    private val remoteDataSource: UserRemoteDataSource,
    private val networkMonitor: NetworkMonitor
) : UserRepository {
    
    override suspend fun getUser(id: UserId): User {
        return if (networkMonitor.isOnline) {
            try {
                val remoteUser = remoteDataSource.getUser(id)
                localDataSource.saveUser(remoteUser)
                remoteUser.toDomainModel()
            } catch (e: Exception) {
                localDataSource.getUser(id).toDomainModel()
            }
        } else {
            localDataSource.getUser(id).toDomainModel()
        }
    }
}

// Data Source
interface UserLocalDataSource {
    suspend fun getUser(id: UserId): UserEntity
    suspend fun saveUser(user: UserNetworkModel)
}

@Entity(tableName = "users")
data class UserEntity(
    @PrimaryKey val id: String,
    val name: String,
    val email: String,
    val preferencesJson: String
)
```

#### Benefits in Compose Projects
- **Testability**: Each layer can be tested independently
- **Separation of Concerns**: Clear boundaries between layers
- **Flexibility**: Easy to swap implementations
- **Maintainability**: Changes in one layer don't affect others

#### Examples in Projects
- **Now in Android**: Full Clean Architecture with feature modules
- **Tivi**: Clean Architecture with sophisticated data synchronization

---

### 4. **Repository Pattern**
**Adoption Rate**: 100% of analyzed projects

#### Standard Implementation
```kotlin
// Repository Interface
interface ArticleRepository {
    fun getArticles(): Flow<List<Article>>
    suspend fun getArticle(id: String): Article
    suspend fun refreshArticles()
    suspend fun bookmarkArticle(id: String)
}

// Repository Implementation
class ArticleRepositoryImpl @Inject constructor(
    private val networkDataSource: ArticleNetworkDataSource,
    private val localDataSource: ArticleLocalDataSource,
    private val networkMonitor: NetworkMonitor
) : ArticleRepository {
    
    override fun getArticles(): Flow<List<Article>> {
        return localDataSource.getArticles()
            .map { entities -> entities.map { it.toDomainModel() } }
    }
    
    override suspend fun getArticle(id: String): Article {
        return localDataSource.getArticle(id).toDomainModel()
    }
    
    override suspend fun refreshArticles() {
        if (networkMonitor.isOnline) {
            try {
                val networkArticles = networkDataSource.getArticles()
                localDataSource.saveArticles(networkArticles)
            } catch (e: Exception) {
                // Handle network error
            }
        }
    }
}
```

#### Offline-First Repository Pattern
```kotlin
class OfflineFirstArticleRepository @Inject constructor(
    private val articleDao: ArticleDao,
    private val network: ArticleNetworkDataSource,
    private val syncManager: SyncManager
) : ArticleRepository {
    
    override fun getArticles(): Flow<List<Article>> = 
        articleDao.getArticles()
            .map { entities -> entities.map(ArticleEntity::asExternalModel) }
    
    override suspend fun syncWith(synchronizer: Synchronizer): Boolean =
        synchronizer.changeListSync(
            versionReader = ChangeListVersions::articleVersion,
            changeListFetcher = { currentVersion ->
                network.getArticleChangeList(after = currentVersion)
            },
            versionUpdater = { latestVersion ->
                copy(articleVersion = latestVersion)
            },
            modelDeleter = articleDao::deleteArticles,
            modelUpdater = { changedIds ->
                val networkArticles = network.getArticles(ids = changedIds)
                articleDao.upsertArticles(
                    networkArticles.map(NetworkArticle::asEntity)
                )
            }
        )
}
```

---

## 🔄 State Management Patterns

### 1. **StateFlow + ViewModel Pattern**
```kotlin
class HomeViewModel @Inject constructor(
    private val userRepository: UserRepository,
    private val articleRepository: ArticleRepository
) : ViewModel() {
    
    private val _uiState = MutableStateFlow(HomeUiState.Loading)
    val uiState: StateFlow<HomeUiState> = _uiState.asStateFlow()
    
    init {
        viewModelScope.launch {
            combine(
                userRepository.getCurrentUser(),
                articleRepository.getArticles()
            ) { user, articles ->
                HomeUiState.Success(
                    user = user,
                    articles = articles
                )
            }.catch { throwable ->
                _uiState.value = HomeUiState.Error(throwable.message)
            }.collect { successState ->
                _uiState.value = successState
            }
        }
    }
}

sealed interface HomeUiState {
    object Loading : HomeUiState
    data class Success(
        val user: User,
        val articles: List<Article>
    ) : HomeUiState
    data class Error(val message: String?) : HomeUiState
}
```

### 2. **Compose State Management**
```kotlin
@Composable
fun ArticleScreen() {
    var searchQuery by rememberSaveable { mutableStateOf("") }
    val articles by viewModel.articles.collectAsState()
    
    val filteredArticles by remember(searchQuery, articles) {
        derivedStateOf {
            if (searchQuery.isEmpty()) {
                articles
            } else {
                articles.filter { it.title.contains(searchQuery, ignoreCase = true) }
            }
        }
    }
    
    Column {
        SearchBar(
            query = searchQuery,
            onQueryChange = { searchQuery = it }
        )
        
        LazyColumn {
            items(filteredArticles, key = { it.id }) { article ->
                ArticleCard(article = article)
            }
        }
    }
}
```

---

## 🏛️ Module Architecture Patterns

### 1. **Feature-Based Modularization**
```
app/
├── build.gradle.kts
└── src/main/

feature/
├── bookmarks/
│   ├── build.gradle.kts
│   └── src/main/
├── foryou/
├── interests/
└── search/

core/
├── common/
├── data/
├── database/
├── datastore/
├── designsystem/
├── domain/
├── model/
├── network/
├── notifications/
├── testing/
└── ui/
```

### 2. **Layer-Based Modularization**
```
app/
├── build.gradle.kts
└── src/main/

data/
├── repository/
├── local/
└── remote/

domain/
├── usecase/
├── model/
└── repository/

presentation/
├── ui/
├── viewmodel/
└── navigation/
```

### 3. **Gradle Dependency Configuration**
```kotlin
// feature module build.gradle.kts
dependencies {
    implementation(project(":core:ui"))
    implementation(project(":core:designsystem"))
    implementation(project(":core:data"))
    implementation(project(":core:common"))
    implementation(project(":core:model"))
    
    implementation(libs.androidx.hilt.navigation.compose)
    implementation(libs.androidx.lifecycle.viewmodel.compose)
    implementation(libs.androidx.navigation.compose)
    
    testImplementation(project(":core:testing"))
    testImplementation(libs.junit4)
    testImplementation(libs.androidx.compose.ui.test)
    
    androidTestImplementation(project(":core:testing"))
    androidTestImplementation(libs.androidx.compose.ui.test)
}
```

---

## 🎯 Architecture Decision Factors

### **Project Size & Complexity**
| Project Type | Recommended Architecture | Reasoning |
|--------------|-------------------------|-----------|
| Small/Medium | MVVM + Repository | Simple, well-understood |
| Large/Complex | Clean Architecture + MVI | Better separation, scalability |
| Multi-platform | Clean Architecture | Shared business logic |

### **Team Size & Experience**
| Team Size | Recommended Pattern | Benefits |
|-----------|-------------------|----------|
| 1-3 developers | MVVM | Fast development, low overhead |
| 4-8 developers | Clean Architecture | Clear boundaries, parallel work |
| 8+ developers | Modular Clean Architecture | Independent feature teams |

### **Performance Requirements**
| Requirement | Pattern Choice | Implementation |
|-------------|---------------|----------------|
| Fast startup | Lazy loading modules | Feature-based modularization |
| Memory efficiency | MVI with immutable state | Structural sharing |
| Smooth animations | State hoisting | Minimal recomposition |

## 📈 Evolution Trends

### **From XML to Compose**
- **State Management**: Moving from LiveData to StateFlow
- **Navigation**: Migration to Navigation Compose
- **Dependency Injection**: Increased Hilt adoption
- **Testing**: Compose Testing API integration

### **Architectural Maturity**
- **Modularization**: Feature-based module organization
- **Offline-First**: Repository pattern with sync mechanisms
- **Type Safety**: Kotlin type system leveraging
- **Reactive Programming**: Coroutines and Flow adoption

## 🔮 Future Directions

### **Emerging Patterns**
- **Multiplatform Architecture**: Shared ViewModels with Compose Multiplatform
- **Server-Driven UI**: Dynamic UI composition from backend
- **AI Integration**: ML models in app architecture
- **Edge Computing**: Local processing with cloud sync

### **Tooling Evolution**
- **Code Generation**: Increased automation with KSP
- **Build Optimization**: Gradle configuration caching
- **Testing**: Screenshot testing standardization
- **Performance**: Baseline profiles for startup optimization

## 🏁 Recommendations

### **For New Projects**
1. **Start Simple**: Begin with MVVM + Repository pattern
2. **Plan for Growth**: Design with modularization in mind
3. **Choose Modern Tools**: Use Hilt, Navigation Compose, StateFlow
4. **Implement Testing**: Set up testing infrastructure early

### **For Existing Projects**
1. **Gradual Migration**: Migrate screen by screen to Compose
2. **Architectural Refactoring**: Extract business logic to ViewModels
3. **Dependency Updates**: Move to modern dependency injection
4. **Testing Addition**: Add Compose Testing alongside existing tests

### **Architecture Selection Criteria**
- **Team expertise** with chosen patterns
- **Project complexity** and expected growth
- **Performance requirements** and constraints
- **Maintenance timeline** and team stability

---

### 📄 Navigation

**Previous:** [Project Analysis](./project-analysis.md) | **Next:** [Build Optimization](./build-optimization.md)

**Related:** [Library Ecosystem](./library-ecosystem.md) | [Performance Optimization](./performance-optimization.md)