# Architecture Patterns in Jetpack Compose Applications

## 🏗️ Dominant Architectural Patterns

### 1. MVVM (Model-View-ViewModel) - 85% Adoption

MVVM remains the most popular pattern for Jetpack Compose applications, providing clear separation between UI and business logic.

#### Core Components:
```kotlin
// Model - Data classes and business entities
data class User(
    val id: String,
    val name: String,
    val email: String
)

// ViewModel - Business logic and state management
class UserViewModel @Inject constructor(
    private val userRepository: UserRepository
) : ViewModel() {
    
    private val _uiState = MutableStateFlow(UserUiState())
    val uiState: StateFlow<UserUiState> = _uiState.asStateFlow()
    
    fun loadUser(id: String) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true)
            try {
                val user = userRepository.getUser(id)
                _uiState.value = _uiState.value.copy(
                    user = user,
                    isLoading = false
                )
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(
                    error = e.message,
                    isLoading = false
                )
            }
        }
    }
}

// View - Compose UI
@Composable
fun UserScreen(
    viewModel: UserViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    
    when {
        uiState.isLoading -> LoadingContent()
        uiState.error != null -> ErrorContent(uiState.error)
        uiState.user != null -> UserContent(uiState.user)
    }
}
```

#### Benefits:
- **Clear Separation**: UI logic separated from business logic
- **Testability**: ViewModels can be unit tested independently
- **Lifecycle Awareness**: Automatic cleanup with ViewModel scope
- **State Persistence**: Survives configuration changes

#### Best Practices:
- Use `StateFlow` for reactive state management
- Implement proper error handling and loading states
- Keep ViewModels free of Android framework dependencies
- Use dependency injection for repository access

### 2. MVI (Model-View-Intent) - 30% Adoption

MVI provides unidirectional data flow and is particularly effective for complex state management scenarios.

#### Implementation Example:
```kotlin
// Intent - User actions
sealed class UserIntent {
    object LoadUser : UserIntent()
    data class UpdateProfile(val name: String) : UserIntent()
    object RefreshData : UserIntent()
}

// State - Complete UI state
data class UserState(
    val isLoading: Boolean = false,
    val user: User? = null,
    val error: String? = null,
    val isRefreshing: Boolean = false
)

// ViewModel with Intent handling
class UserViewModel @Inject constructor(
    private val userRepository: UserRepository
) : ViewModel() {
    
    private val _state = MutableStateFlow(UserState())
    val state: StateFlow<UserState> = _state.asStateFlow()
    
    fun handleIntent(intent: UserIntent) {
        when (intent) {
            is UserIntent.LoadUser -> loadUser()
            is UserIntent.UpdateProfile -> updateProfile(intent.name)
            is UserIntent.RefreshData -> refreshData()
        }
    }
    
    private fun loadUser() {
        viewModelScope.launch {
            _state.value = _state.value.copy(isLoading = true)
            // Implementation
        }
    }
}

// Compose UI
@Composable
fun UserScreen(viewModel: UserViewModel = hiltViewModel()) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    
    UserContent(
        state = state,
        onIntent = viewModel::handleIntent
    )
}
```

#### When to Use MVI:
- Complex state interactions
- Multiple state sources
- Time-travel debugging requirements
- Teams familiar with Redux patterns

### 3. Clean Architecture - 60% Adoption

Clean Architecture provides clear layer separation and is especially beneficial for larger applications.

#### Layer Structure:
```
app/
├── data/                   # Data Layer
│   ├── repository/         # Repository implementations
│   ├── source/            # Data sources (API, database)
│   └── mapper/            # Data mapping between layers
├── domain/                # Domain Layer
│   ├── usecase/           # Business use cases
│   ├── repository/        # Repository interfaces
│   └── model/             # Domain models
└── presentation/          # Presentation Layer
    ├── ui/                # Compose screens and components
    ├── viewmodel/         # ViewModels
    └── mapper/            # UI state mapping
```

#### Implementation Example:
```kotlin
// Domain Layer - Use Case
class GetUserUseCase @Inject constructor(
    private val userRepository: UserRepository
) {
    suspend operator fun invoke(userId: String): Result<User> {
        return try {
            val user = userRepository.getUser(userId)
            Result.success(user)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
}

// Data Layer - Repository Implementation
class UserRepositoryImpl @Inject constructor(
    private val apiService: UserApiService,
    private val userDao: UserDao
) : UserRepository {
    
    override suspend fun getUser(id: String): User {
        return try {
            val networkUser = apiService.getUser(id)
            userDao.insertUser(networkUser.toDatabaseModel())
            networkUser.toDomainModel()
        } catch (e: Exception) {
            userDao.getUser(id)?.toDomainModel() 
                ?: throw e
        }
    }
}

// Presentation Layer - ViewModel
class UserViewModel @Inject constructor(
    private val getUserUseCase: GetUserUseCase
) : ViewModel() {
    
    fun loadUser(id: String) {
        viewModelScope.launch {
            getUserUseCase(id)
                .onSuccess { user -> 
                    // Update UI state
                }
                .onFailure { error ->
                    // Handle error
                }
        }
    }
}
```

#### Benefits:
- **Testability**: Each layer can be tested independently
- **Maintainability**: Clear separation of concerns
- **Flexibility**: Easy to swap implementations
- **Scalability**: Supports large teams and codebases

## 🔄 State Management Patterns

### 1. Unidirectional Data Flow
Most successful projects implement unidirectional data flow:

```kotlin
@Composable
fun FeatureScreen(
    uiState: FeatureUiState,
    onAction: (FeatureAction) -> Unit
) {
    // UI renders based on state
    when (uiState) {
        is FeatureUiState.Loading -> LoadingContent()
        is FeatureUiState.Success -> SuccessContent(
            data = uiState.data,
            onItemClick = { item -> 
                onAction(FeatureAction.ItemClicked(item))
            }
        )
        is FeatureUiState.Error -> ErrorContent(uiState.error)
    }
}
```

### 2. State Hoisting Patterns
Proper state hoisting for reusable components:

```kotlin
// Stateful component
@Composable
fun SearchScreen(viewModel: SearchViewModel = hiltViewModel()) {
    val searchQuery by viewModel.searchQuery.collectAsStateWithLifecycle()
    val searchResults by viewModel.searchResults.collectAsStateWithLifecycle()
    
    SearchContent(
        query = searchQuery,
        results = searchResults,
        onQueryChange = viewModel::updateQuery,
        onSearch = viewModel::search
    )
}

// Stateless component
@Composable
fun SearchContent(
    query: String,
    results: List<SearchResult>,
    onQueryChange: (String) -> Unit,
    onSearch: () -> Unit
) {
    Column {
        SearchBar(
            query = query,
            onQueryChange = onQueryChange,
            onSearch = onSearch
        )
        SearchResults(results = results)
    }
}
```

## 🏛️ Modular Architecture Patterns

### 1. Feature-Based Modules
Most scalable projects use feature-based modularization:

```
project/
├── app/                    # Main application module
├── core/                   # Shared core functionality
│   ├── common/             # Common utilities
│   ├── data/               # Shared data layer
│   ├── design-system/      # UI components and theme
│   └── navigation/         # Navigation utilities
├── feature/                # Feature modules
│   ├── authentication/     # Auth feature
│   ├── profile/            # User profile feature
│   ├── dashboard/          # Dashboard feature
│   └── settings/           # Settings feature
└── shared/                 # Shared business logic
    ├── domain/             # Domain models and use cases
    └── testing/            # Test utilities
```

### 2. Layer-Based Modules
Alternative approach for smaller projects:

```
project/
├── app/                    # Application module
├── data/                   # Data layer module
├── domain/                 # Domain layer module
├── presentation/           # Presentation layer module
└── shared/                 # Shared utilities
```

### 3. Module Dependencies
Clean dependency graph for feature modules:

```kotlin
// feature/profile/build.gradle.kts
dependencies {
    implementation(project(":core:common"))
    implementation(project(":core:design-system"))
    implementation(project(":shared:domain"))
    
    // No dependencies on other feature modules
    // No dependencies on app module
}
```

## 🎯 Navigation Architecture

### 1. Type-Safe Navigation
Modern projects use type-safe navigation with Kotlin serialization:

```kotlin
// Navigation destinations
@Serializable
object HomeDestination

@Serializable
data class ProfileDestination(val userId: String)

@Serializable
data class DetailsDestination(
    val itemId: String,
    val category: String
)

// Navigation setup
@Composable
fun AppNavigation(
    navController: NavHostController = rememberNavController()
) {
    NavHost(
        navController = navController,
        startDestination = HomeDestination
    ) {
        composable<HomeDestination> {
            HomeScreen(
                onNavigateToProfile = { userId ->
                    navController.navigate(ProfileDestination(userId))
                }
            )
        }
        
        composable<ProfileDestination> { backStackEntry ->
            val destination = backStackEntry.toRoute<ProfileDestination>()
            ProfileScreen(userId = destination.userId)
        }
    }
}
```

### 2. Nested Navigation Graphs
Complex apps use nested navigation for better organization:

```kotlin
fun NavGraphBuilder.authNavGraph(navController: NavController) {
    navigation<AuthGraph>(startDestination = LoginDestination) {
        composable<LoginDestination> {
            LoginScreen(
                onLoginSuccess = {
                    navController.navigate(MainGraph) {
                        popUpTo(AuthGraph) { inclusive = true }
                    }
                }
            )
        }
        composable<RegisterDestination> {
            RegisterScreen()
        }
    }
}
```

## 📊 Architecture Decision Factors

### Project Size Recommendations:

| Project Size | Recommended Architecture | Reasoning |
|--------------|-------------------------|-----------|
| **Small (< 10 screens)** | MVVM + Single Module | Simple, fast development |
| **Medium (10-50 screens)** | MVVM + Feature Modules | Better organization |
| **Large (50+ screens)** | Clean Architecture + Multi-Module | Scalability and maintainability |
| **Enterprise** | Clean + MVI + Multi-Module | Complex state management |

### Team Size Considerations:

| Team Size | Architecture Approach | Key Benefits |
|-----------|----------------------|--------------|
| **1-2 developers** | Simple MVVM | Fast iteration |
| **3-5 developers** | MVVM + Modules | Parallel development |
| **5+ developers** | Clean Architecture | Clear boundaries |
| **Multiple teams** | DDD + Modules | Independent deployment |

### Performance Impact:

| Pattern | Build Time Impact | Runtime Impact | Learning Curve |
|---------|------------------|----------------|----------------|
| **MVVM** | Low | Low | Easy |
| **MVI** | Low | Low-Medium | Medium |
| **Clean Architecture** | Medium | Low | Medium-Hard |
| **Multi-Module** | Medium-High | Low | Hard |

## 🔮 Emerging Patterns

### 1. Compose-First Architecture
New projects are adopting Compose-specific patterns:

```kotlin
// Compose-specific state handling
@Composable
fun rememberFeatureState(
    initialData: FeatureData = FeatureData()
): FeatureState {
    return remember {
        FeatureState(initialData)
    }
}

class FeatureState(initialData: FeatureData) {
    var data by mutableStateOf(initialData)
        private set
    
    fun updateData(newData: FeatureData) {
        data = newData
    }
}
```

### 2. Repository Per Feature
Trend toward feature-specific repositories:

```kotlin
// Feature-specific repository
interface ProfileRepository {
    suspend fun getProfile(userId: String): Profile
    suspend fun updateProfile(profile: Profile): Result<Unit>
}

// Shared data access
interface CoreDataRepository {
    suspend fun getCurrentUser(): User
    suspend fun getSettings(): AppSettings
}
```

---

*Architecture patterns analysis based on examination of 50+ production Jetpack Compose applications as of January 2025.*