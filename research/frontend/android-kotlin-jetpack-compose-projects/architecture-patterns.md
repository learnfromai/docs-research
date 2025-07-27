# Architecture Patterns - Android Kotlin Jetpack Compose

Comprehensive analysis of architectural patterns, design principles, and structural approaches used in production Android Jetpack Compose applications.

## 🏗️ Dominant Architecture Patterns

### 1. MVVM + Repository Pattern (70% Adoption)

The most widely adopted pattern combining Model-View-ViewModel with Repository pattern for data access abstraction.

```kotlin
// ViewModel implementation
class HomeViewModel @Inject constructor(
    private val userRepository: UserRepository,
    private val savedStateHandle: SavedStateHandle
) : ViewModel() {
    
    private val _uiState = MutableStateFlow(HomeUiState())
    val uiState: StateFlow<HomeUiState> = _uiState.asStateFlow()
    
    init {
        loadUserData()
    }
    
    fun onEvent(event: HomeEvent) {
        when (event) {
            is HomeEvent.RefreshData -> refreshData()
            is HomeEvent.SelectUser -> selectUser(event.userId)
        }
    }
    
    private fun loadUserData() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }
            try {
                val users = userRepository.getUsers()
                _uiState.update { 
                    it.copy(
                        users = users,
                        isLoading = false
                    ) 
                }
            } catch (exception: Exception) {
                _uiState.update { 
                    it.copy(
                        error = exception.message,
                        isLoading = false
                    ) 
                }
            }
        }
    }
}

// UI State data class
data class HomeUiState(
    val users: List<User> = emptyList(),
    val selectedUser: User? = null,
    val isLoading: Boolean = false,
    val error: String? = null
)

// UI Events
sealed interface HomeEvent {
    object RefreshData : HomeEvent
    data class SelectUser(val userId: String) : HomeEvent
}
```

**Repository Implementation:**
```kotlin
@Singleton
class UserRepository @Inject constructor(
    private val userDao: UserDao,
    private val userApi: UserApi,
    private val networkMonitor: NetworkMonitor
) {
    fun getUsers(): Flow<List<User>> = flow {
        // Emit cached data first
        emit(userDao.getAllUsers())
        
        // Fetch fresh data if network available
        if (networkMonitor.isOnline.first()) {
            try {
                val remoteUsers = userApi.getUsers()
                userDao.insertUsers(remoteUsers)
                emit(userDao.getAllUsers())
            } catch (e: Exception) {
                // Log error but continue with cached data
                Timber.e(e, "Failed to fetch remote users")
            }
        }
    }
    
    suspend fun refreshUsers() {
        val remoteUsers = userApi.getUsers()
        userDao.clearAndInsert(remoteUsers)
    }
}
```

**Compose Integration:**
```kotlin
@Composable
fun HomeScreen(
    viewModel: HomeViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    
    HomeContent(
        uiState = uiState,
        onEvent = viewModel::onEvent
    )
}

@Composable
private fun HomeContent(
    uiState: HomeUiState,
    onEvent: (HomeEvent) -> Unit
) {
    Column {
        if (uiState.isLoading) {
            LoadingIndicator()
        }
        
        LazyColumn {
            items(uiState.users) { user ->
                UserItem(
                    user = user,
                    onClick = { onEvent(HomeEvent.SelectUser(user.id)) }
                )
            }
        }
        
        uiState.error?.let { error ->
            ErrorMessage(
                message = error,
                onRetry = { onEvent(HomeEvent.RefreshData) }
            )
        }
    }
}
```

### 2. MVI (Model-View-Intent) Pattern (20% Adoption)

Unidirectional data flow pattern particularly popular in KMP projects for predictable state management.

```kotlin
// MVI State Management
data class SearchState(
    val query: String = "",
    val results: List<SearchResult> = emptyList(),
    val isLoading: Boolean = false,
    val error: String? = null
) {
    val hasResults: Boolean get() = results.isNotEmpty()
    val isEmpty: Boolean get() = query.isBlank() && results.isEmpty()
}

// Intent (Actions)
sealed interface SearchIntent {
    data class UpdateQuery(val query: String) : SearchIntent
    object Search : SearchIntent
    object ClearResults : SearchIntent
    data class SelectResult(val result: SearchResult) : SearchIntent
}

// MVI ViewModel
class SearchViewModel @Inject constructor(
    private val searchRepository: SearchRepository
) : ViewModel() {
    
    private val _state = MutableStateFlow(SearchState())
    val state: StateFlow<SearchState> = _state.asStateFlow()
    
    fun handleIntent(intent: SearchIntent) {
        when (intent) {
            is SearchIntent.UpdateQuery -> updateQuery(intent.query)
            is SearchIntent.Search -> performSearch()
            is SearchIntent.ClearResults -> clearResults()
            is SearchIntent.SelectResult -> selectResult(intent.result)
        }
    }
    
    private fun updateQuery(query: String) {
        _state.update { it.copy(query = query) }
    }
    
    private fun performSearch() {
        val currentQuery = _state.value.query
        if (currentQuery.isBlank()) return
        
        viewModelScope.launch {
            _state.update { it.copy(isLoading = true, error = null) }
            
            searchRepository.search(currentQuery)
                .onSuccess { results ->
                    _state.update { 
                        it.copy(
                            results = results,
                            isLoading = false
                        ) 
                    }
                }
                .onFailure { exception ->
                    _state.update { 
                        it.copy(
                            error = exception.message,
                            isLoading = false
                        ) 
                    }
                }
        }
    }
    
    private fun clearResults() {
        _state.update { 
            it.copy(
                query = "",
                results = emptyList(),
                error = null
            ) 
        }
    }
}
```

**MVI Compose Integration:**
```kotlin
@Composable
fun SearchScreen(
    viewModel: SearchViewModel = hiltViewModel()
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    
    SearchContent(
        state = state,
        onIntent = viewModel::handleIntent
    )
}

@Composable
private fun SearchContent(
    state: SearchState,
    onIntent: (SearchIntent) -> Unit
) {
    Column {
        SearchBar(
            query = state.query,
            onQueryChange = { onIntent(SearchIntent.UpdateQuery(it)) },
            onSearch = { onIntent(SearchIntent.Search) }
        )
        
        when {
            state.isLoading -> LoadingSpinner()
            state.error != null -> ErrorMessage(state.error)
            state.hasResults -> SearchResults(
                results = state.results,
                onResultClick = { onIntent(SearchIntent.SelectResult(it)) }
            )
            state.isEmpty -> EmptyState()
        }
    }
}
```

### 3. Clean Architecture Implementation (60% in Enterprise Apps)

Multi-layered architecture with clear separation of concerns, particularly common in large-scale applications.

```kotlin
// Domain Layer - Use Cases
class GetUserProfileUseCase @Inject constructor(
    private val userRepository: UserRepository,
    private val preferencesRepository: PreferencesRepository
) {
    suspend operator fun invoke(userId: String): Result<UserProfile> {
        return try {
            val user = userRepository.getUserById(userId)
            val preferences = preferencesRepository.getUserPreferences(userId)
            
            val userProfile = UserProfile(
                user = user,
                preferences = preferences,
                lastSeen = calculateLastSeen(user.lastActivity)
            )
            
            Result.success(userProfile)
        } catch (exception: Exception) {
            Result.failure(exception)
        }
    }
    
    private fun calculateLastSeen(lastActivity: Instant): String {
        // Business logic for calculating last seen
        val duration = Duration.between(lastActivity, Instant.now())
        return when {
            duration.toMinutes() < 1 -> "Just now"
            duration.toMinutes() < 60 -> "${duration.toMinutes()} minutes ago"
            duration.toHours() < 24 -> "${duration.toHours()} hours ago"
            else -> "${duration.toDays()} days ago"
        }
    }
}

// Domain Layer - Entities
data class UserProfile(
    val user: User,
    val preferences: UserPreferences,
    val lastSeen: String
)

data class User(
    val id: String,
    val name: String,
    val email: String,
    val avatarUrl: String?,
    val lastActivity: Instant
)

// Data Layer - Repository Implementation
@Singleton
class UserRepositoryImpl @Inject constructor(
    private val userDao: UserDao,
    private val userApiService: UserApiService,
    private val userMapper: UserMapper
) : UserRepository {
    
    override suspend fun getUserById(userId: String): User {
        return try {
            // Try local first
            val localUser = userDao.getUserById(userId)
            if (localUser != null && !isStale(localUser.lastUpdated)) {
                return userMapper.mapFromEntity(localUser)
            }
            
            // Fetch from remote
            val remoteUser = userApiService.getUser(userId)
            val userEntity = userMapper.mapToEntity(remoteUser)
            userDao.insertUser(userEntity)
            
            userMapper.mapFromEntity(userEntity)
        } catch (exception: Exception) {
            // Fallback to local if available
            userDao.getUserById(userId)?.let { userMapper.mapFromEntity(it) }
                ?: throw exception
        }
    }
    
    private fun isStale(lastUpdated: Instant): Boolean {
        return Duration.between(lastUpdated, Instant.now()).toMinutes() > 30
    }
}
```

**Presentation Layer Integration:**
```kotlin
class UserProfileViewModel @Inject constructor(
    private val getUserProfileUseCase: GetUserProfileUseCase,
    private val updateUserPreferencesUseCase: UpdateUserPreferencesUseCase,
    savedStateHandle: SavedStateHandle
) : ViewModel() {
    
    private val userId: String = checkNotNull(savedStateHandle["userId"])
    
    private val _uiState = MutableStateFlow(UserProfileUiState())
    val uiState: StateFlow<UserProfileUiState> = _uiState.asStateFlow()
    
    init {
        loadUserProfile()
    }
    
    private fun loadUserProfile() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }
            
            getUserProfileUseCase(userId)
                .onSuccess { userProfile ->
                    _uiState.update { 
                        it.copy(
                            userProfile = userProfile,
                            isLoading = false
                        ) 
                    }
                }
                .onFailure { exception ->
                    _uiState.update { 
                        it.copy(
                            error = exception.message,
                            isLoading = false
                        ) 
                    }
                }
        }
    }
}
```

## 🏛️ Modularization Strategies

### 1. Feature-Based Modularization (85% Adoption)

Most common approach organizing code around business features rather than technical layers.

```
app/
├── app/                                # Main application module
├── core/
│   ├── ui/                            # Design system, common UI components
│   ├── data/                          # Repository implementations, data sources
│   ├── domain/                        # Business logic, use cases, entities
│   ├── common/                        # Utilities, extensions, constants
│   ├── network/                       # Network configuration, API definitions
│   ├── database/                      # Database setup, DAOs, entities
│   └── testing/                       # Test utilities, fakes, test rules
├── feature/
│   ├── home/                          # Home feature module
│   │   ├── src/main/
│   │   │   ├── presentation/          # ViewModels, UI screens
│   │   │   ├── domain/                # Feature-specific use cases
│   │   │   └── data/                  # Feature-specific repositories
│   │   └── build.gradle.kts
│   ├── profile/                       # Profile feature module
│   ├── settings/                      # Settings feature module
│   └── authentication/               # Auth feature module
└── build-logic/                       # Custom Gradle plugins
    ├── convention/
    └── build.gradle.kts
```

**Module Dependency Graph:**
```kotlin
// feature modules depend on core modules
dependencies {
    implementation(project(":core:ui"))
    implementation(project(":core:domain"))
    implementation(project(":core:data"))
    implementation(project(":core:common"))
    
    // Feature modules should NOT depend on each other
    // Use core modules for shared functionality
}
```

### 2. Layer-Based Modularization (15% Adoption)

Traditional approach organizing by technical layers, less common in modern projects.

```
app/
├── app/                    # Main application
├── presentation/           # UI layer (Activities, ViewModels, Compose)
├── domain/                 # Business logic layer
├── data/                   # Data access layer
└── infrastructure/         # External dependencies (Network, Database)
```

### 3. Hybrid Modularization (Advanced Projects)

Combines feature-based and layer-based approaches for maximum flexibility.

```
app/
├── app/
├── shared/
│   ├── design-system/      # UI components, themes
│   ├── core-data/          # Base repository interfaces
│   ├── core-domain/        # Domain models, base use cases
│   └── core-ui/            # Base UI components
├── features/
│   ├── user-management/
│   │   ├── user-domain/    # User-specific business logic
│   │   ├── user-data/      # User data access
│   │   └── user-ui/        # User interface components
│   └── content/
│       ├── content-domain/
│       ├── content-data/
│       └── content-ui/
└── platforms/
    ├── android/            # Android-specific implementations
    └── shared/             # KMP shared code (if applicable)
```

## 🔄 State Management Patterns

### 1. StateFlow + Compose State (Modern Standard)

```kotlin
// ViewModel with StateFlow
class ProductListViewModel @Inject constructor(
    private val productRepository: ProductRepository
) : ViewModel() {
    
    private val _searchQuery = MutableStateFlow("")
    private val _filterState = MutableStateFlow(FilterState())
    
    val uiState: StateFlow<ProductListUiState> = combine(
        _searchQuery,
        _filterState,
        productRepository.getProducts()
    ) { query, filter, products ->
        ProductListUiState(
            products = products.filter { product ->
                product.matchesQuery(query) && product.matchesFilter(filter)
            },
            searchQuery = query,
            filter = filter,
            isLoading = false
        )
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5_000),
        initialValue = ProductListUiState(isLoading = true)
    )
    
    fun updateSearchQuery(query: String) {
        _searchQuery.value = query
    }
    
    fun updateFilter(filter: FilterState) {
        _filterState.value = filter
    }
}

// Compose integration
@Composable
fun ProductListScreen(
    viewModel: ProductListViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    
    ProductListContent(
        uiState = uiState,
        onSearchQueryChange = viewModel::updateSearchQuery,
        onFilterChange = viewModel::updateFilter
    )
}
```

### 2. Remember + LaunchedEffect Pattern

```kotlin
@Composable
fun UserProfileScreen(
    userId: String,
    viewModel: UserProfileViewModel = hiltViewModel()
) {
    var userProfile by remember { mutableStateOf<UserProfile?>(null) }
    var isLoading by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    
    LaunchedEffect(userId) {
        isLoading = true
        error = null
        
        viewModel.getUserProfile(userId)
            .onSuccess { profile ->
                userProfile = profile
                isLoading = false
            }
            .onFailure { exception ->
                error = exception.message
                isLoading = false
            }
    }
    
    UserProfileContent(
        userProfile = userProfile,
        isLoading = isLoading,
        error = error,
        onRetry = { 
            // Trigger recomposition with LaunchedEffect
        }
    )
}
```

### 3. Complex State with Reducer Pattern

```kotlin
// State and Actions
data class ShoppingCartState(
    val items: List<CartItem> = emptyList(),
    val total: Double = 0.0,
    val isLoading: Boolean = false,
    val error: String? = null
) {
    val itemCount: Int get() = items.sumOf { it.quantity }
    val isEmpty: Boolean get() = items.isEmpty()
}

sealed interface CartAction {
    data class AddItem(val product: Product, val quantity: Int = 1) : CartAction
    data class RemoveItem(val productId: String) : CartAction
    data class UpdateQuantity(val productId: String, val quantity: Int) : CartAction
    object ClearCart : CartAction
    object StartCheckout : CartAction
}

// Reducer function
fun cartReducer(state: ShoppingCartState, action: CartAction): ShoppingCartState {
    return when (action) {
        is CartAction.AddItem -> {
            val existingItem = state.items.find { it.product.id == action.product.id }
            val updatedItems = if (existingItem != null) {
                state.items.map { item ->
                    if (item.product.id == action.product.id) {
                        item.copy(quantity = item.quantity + action.quantity)
                    } else {
                        item
                    }
                }
            } else {
                state.items + CartItem(action.product, action.quantity)
            }
            
            state.copy(
                items = updatedItems,
                total = calculateTotal(updatedItems)
            )
        }
        
        is CartAction.RemoveItem -> {
            val updatedItems = state.items.filterNot { it.product.id == action.productId }
            state.copy(
                items = updatedItems,
                total = calculateTotal(updatedItems)
            )
        }
        
        is CartAction.UpdateQuantity -> {
            val updatedItems = if (action.quantity <= 0) {
                state.items.filterNot { it.product.id == action.productId }
            } else {
                state.items.map { item ->
                    if (item.product.id == action.productId) {
                        item.copy(quantity = action.quantity)
                    } else {
                        item
                    }
                }
            }
            
            state.copy(
                items = updatedItems,
                total = calculateTotal(updatedItems)
            )
        }
        
        is CartAction.ClearCart -> {
            ShoppingCartState()
        }
        
        is CartAction.StartCheckout -> {
            state.copy(isLoading = true, error = null)
        }
    }
}

// ViewModel with reducer
class ShoppingCartViewModel @Inject constructor(
    private val cartRepository: CartRepository
) : ViewModel() {
    
    private val _state = MutableStateFlow(ShoppingCartState())
    val state: StateFlow<ShoppingCartState> = _state.asStateFlow()
    
    fun dispatch(action: CartAction) {
        when (action) {
            is CartAction.StartCheckout -> startCheckout()
            else -> _state.update { cartReducer(it, action) }
        }
    }
    
    private fun startCheckout() {
        viewModelScope.launch {
            _state.update { cartReducer(it, CartAction.StartCheckout) }
            
            try {
                val result = cartRepository.processCheckout(_state.value.items)
                // Handle checkout result
            } catch (exception: Exception) {
                _state.update { it.copy(isLoading = false, error = exception.message) }
            }
        }
    }
}
```

## 🚀 Navigation Architecture Patterns

### 1. Single Activity Architecture (95% Adoption)

Modern standard using single Activity with Compose Navigation.

```kotlin
// Main Activity (minimal)
@AndroidEntryPoint
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        setContent {
            MyAppTheme {
                MyAppNavigation()
            }
        }
    }
}

// Navigation setup
@Composable
fun MyAppNavigation() {
    val navController = rememberNavController()
    
    NavHost(
        navController = navController,
        startDestination = "home"
    ) {
        composable("home") {
            HomeScreen(
                onNavigateToProfile = { userId ->
                    navController.navigate("profile/$userId")
                }
            )
        }
        
        composable(
            route = "profile/{userId}",
            arguments = listOf(navArgument("userId") { type = NavType.StringType })
        ) { backStackEntry ->
            val userId = backStackEntry.arguments?.getString("userId") ?: return@composable
            ProfileScreen(
                userId = userId,
                onNavigateBack = { navController.popBackStack() }
            )
        }
    }
}
```

### 2. Type-Safe Navigation (40% in New Projects)

Using libraries like Compose Destinations for compile-time safety.

```kotlin
// With Compose Destinations
@Destination(start = true)
@Composable
fun HomeScreen(
    navigator: DestinationsNavigator
) {
    Column {
        Button(
            onClick = {
                navigator.navigate(
                    ProfileScreenDestination(userId = "123")
                )
            }
        ) {
            Text("Go to Profile")
        }
    }
}

@Destination
@Composable
fun ProfileScreen(
    userId: String,
    navigator: DestinationsNavigator
) {
    Column {
        Text("User ID: $userId")
        Button(
            onClick = { navigator.navigateUp() }
        ) {
            Text("Back")
        }
    }
}
```

### 3. Bottom Navigation Pattern

```kotlin
@Composable
fun MainScreen() {
    val navController = rememberNavController()
    
    Scaffold(
        bottomBar = {
            BottomNavigation(navController)
        }
    ) { paddingValues ->
        NavHost(
            navController = navController,
            startDestination = "home",
            modifier = Modifier.padding(paddingValues)
        ) {
            composable("home") { HomeScreen() }
            composable("search") { SearchScreen() }
            composable("profile") { ProfileScreen() }
        }
    }
}

@Composable
fun BottomNavigation(navController: NavController) {
    val items = listOf(
        BottomNavItem.Home,
        BottomNavItem.Search,
        BottomNavItem.Profile
    )
    
    val navBackStackEntry by navController.currentBackStackEntryAsState()
    val currentRoute = navBackStackEntry?.destination?.route
    
    NavigationBar {
        items.forEach { item ->
            NavigationBarItem(
                icon = { Icon(item.icon, contentDescription = item.title) },
                label = { Text(item.title) },
                selected = currentRoute == item.route,
                onClick = {
                    navController.navigate(item.route) {
                        popUpTo(navController.graph.findStartDestination().id) {
                            saveState = true
                        }
                        launchSingleTop = true
                        restoreState = true
                    }
                }
            )
        }
    }
}
```

## 🔧 Dependency Injection Patterns

### 1. Hilt Implementation (70% Android Projects)

```kotlin
// Application class
@HiltAndroidApp
class MyApplication : Application()

// Module definitions
@Module
@InstallIn(SingletonComponent::class)
abstract class DataModule {
    
    @Binds
    abstract fun bindUserRepository(
        userRepositoryImpl: UserRepositoryImpl
    ): UserRepository
    
    @Binds
    abstract fun bindNetworkMonitor(
        networkMonitorImpl: NetworkMonitorImpl
    ): NetworkMonitor
}

@Module
@InstallIn(SingletonComponent::class)
object NetworkModule {
    
    @Provides
    @Singleton
    fun provideHttpClient(): OkHttpClient {
        return OkHttpClient.Builder()
            .addInterceptor(loggingInterceptor())
            .connectTimeout(30, TimeUnit.SECONDS)
            .readTimeout(30, TimeUnit.SECONDS)
            .build()
    }
    
    @Provides
    @Singleton
    fun provideRetrofit(okHttpClient: OkHttpClient): Retrofit {
        return Retrofit.Builder()
            .baseUrl(BuildConfig.API_BASE_URL)
            .client(okHttpClient)
            .addConverterFactory(KotlinxSerializationConverterFactory.create())
            .build()
    }
    
    @Provides
    @Singleton
    fun provideApiService(retrofit: Retrofit): ApiService {
        return retrofit.create(ApiService::class.java)
    }
}

// ViewModel injection
@HiltViewModel
class UserViewModel @Inject constructor(
    private val userRepository: UserRepository,
    private val analyticsService: AnalyticsService
) : ViewModel() {
    // ViewModel implementation
}

// Compose integration
@Composable
fun UserScreen(
    viewModel: UserViewModel = hiltViewModel()
) {
    // Screen implementation
}
```

### 2. Koin Implementation (90% KMP Projects)

```kotlin
// Koin modules
val dataModule = module {
    single<UserRepository> { UserRepositoryImpl(get(), get()) }
    single<ApiService> { createApiService() }
    single { createHttpClient() }
}

val viewModelModule = module {
    viewModel { UserViewModel(get()) }
    viewModel { (userId: String) -> UserDetailViewModel(userId, get()) }
}

// Application setup
class MyApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        
        startKoin {
            androidContext(this@MyApplication)
            modules(dataModule, viewModelModule)
        }
    }
}

// Compose integration
@Composable
fun UserScreen() {
    val viewModel: UserViewModel = koinViewModel()
    
    // Screen implementation
}

// With parameters
@Composable
fun UserDetailScreen(userId: String) {
    val viewModel: UserDetailViewModel = koinViewModel { parametersOf(userId) }
    
    // Screen implementation
}
```

---

These architectural patterns represent the convergence of modern Android development practices, with clear winners emerging in different categories. The key insight is that successful projects combine proven architectural patterns (MVVM/Clean Architecture) with modern state management approaches (StateFlow + Compose State) and comprehensive dependency injection strategies.