# Best Practices for Jetpack Compose Development

## 🎯 Core Development Principles

Based on analysis of 50+ production Jetpack Compose applications, these best practices emerge as essential for building maintainable, performant, and scalable Android applications.

## 🏗️ Architecture Best Practices

### 1. Separation of Concerns
**Principle**: Keep UI logic separate from business logic

```kotlin
// ❌ Bad: Business logic mixed with UI
@Composable
fun UserScreen() {
    var users by remember { mutableStateOf<List<User>>(emptyList()) }
    var isLoading by remember { mutableStateOf(false) }
    
    LaunchedEffect(Unit) {
        isLoading = true
        // Direct API call in Composable - BAD!
        users = ApiService.getUsers()
        isLoading = false
    }
    
    // UI code...
}

// ✅ Good: Business logic in ViewModel
@HiltViewModel
class UserViewModel @Inject constructor(
    private val userRepository: UserRepository
) : ViewModel() {
    
    private val _uiState = MutableStateFlow(UserUiState())
    val uiState: StateFlow<UserUiState> = _uiState.asStateFlow()
    
    init {
        loadUsers()
    }
    
    private fun loadUsers() {
        viewModelScope.launch {
            // Business logic properly isolated
        }
    }
}

@Composable
fun UserScreen(viewModel: UserViewModel = hiltViewModel()) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    UserContent(uiState = uiState)
}
```

### 2. State Hoisting Pattern
**Principle**: Lift state up to make components reusable and testable

```kotlin
// ❌ Bad: Stateful component
@Composable
fun SearchBox() {
    var query by remember { mutableStateOf("") }
    
    OutlinedTextField(
        value = query,
        onValueChange = { query = it },
        // Hard to test and reuse
    )
}

// ✅ Good: Stateless component
@Composable
fun SearchBox(
    query: String,
    onQueryChange: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    OutlinedTextField(
        value = query,
        onValueChange = onQueryChange,
        modifier = modifier
    )
}

// Usage in stateful parent
@Composable
fun SearchScreen() {
    var query by remember { mutableStateOf("") }
    
    SearchBox(
        query = query,
        onQueryChange = { query = it }
    )
}
```

### 3. Unidirectional Data Flow
**Principle**: Data flows down, events flow up

```kotlin
// UI State flows down
data class PostsUiState(
    val posts: List<Post> = emptyList(),
    val isLoading: Boolean = false,
    val error: String? = null
)

// Events flow up
sealed class PostsEvent {
    object LoadPosts : PostsEvent()
    object RefreshPosts : PostsEvent()
    data class SharePost(val postId: String) : PostsEvent()
}

@Composable
fun PostsScreen(
    uiState: PostsUiState,
    onEvent: (PostsEvent) -> Unit
) {
    when {
        uiState.isLoading -> LoadingIndicator()
        uiState.error != null -> ErrorMessage(uiState.error)
        else -> PostsList(
            posts = uiState.posts,
            onRefresh = { onEvent(PostsEvent.RefreshPosts) },
            onSharePost = { postId -> onEvent(PostsEvent.SharePost(postId)) }
        )
    }
}
```

## 🎨 UI/UX Best Practices

### 1. Material Design 3 Implementation
**Principle**: Follow Material Design guidelines for consistency

```kotlin
// Define proper color scheme
private val LightColorScheme = lightColorScheme(
    primary = Color(0xFF6750A4),
    onPrimary = Color(0xFFFFFFFF),
    primaryContainer = Color(0xFFEADDFF),
    onPrimaryContainer = Color(0xFF21005D),
    // ... complete color scheme
)

@Composable
fun MyAppTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    dynamicColor: Boolean = true,
    content: @Composable () -> Unit
) {
    val colorScheme = when {
        dynamicColor && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
            val context = LocalContext.current
            if (darkTheme) dynamicDarkColorScheme(context) 
            else dynamicLightColorScheme(context)
        }
        darkTheme -> DarkColorScheme
        else -> LightColorScheme
    }

    MaterialTheme(
        colorScheme = colorScheme,
        typography = Typography,
        content = content
    )
}
```

### 2. Responsive Design
**Principle**: Design for different screen sizes and orientations

```kotlin
@Composable
fun AdaptiveLayout(
    content: @Composable (WindowSizeClass) -> Unit
) {
    val windowSizeClass = calculateWindowSizeClass(LocalContext.current as Activity)
    
    content(windowSizeClass)
}

@Composable
fun HomeScreen() {
    AdaptiveLayout { windowSizeClass ->
        when (windowSizeClass.widthSizeClass) {
            WindowWidthSizeClass.Compact -> CompactLayout()
            WindowWidthSizeClass.Medium -> MediumLayout()
            WindowWidthSizeClass.Expanded -> ExpandedLayout()
        }
    }
}
```

### 3. Accessibility Implementation
**Principle**: Make apps accessible to all users

```kotlin
@Composable
fun AccessibleButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Button(
        onClick = onClick,
        modifier = modifier.semantics {
            contentDescription = text
            role = Role.Button
        }
    ) {
        Text(text)
    }
}

@Composable
fun AccessibleImage(
    imageUrl: String,
    contentDescription: String,
    modifier: Modifier = Modifier
) {
    AsyncImage(
        model = imageUrl,
        contentDescription = contentDescription,
        modifier = modifier.semantics {
            // Provide meaningful content description
            this.contentDescription = contentDescription
        }
    )
}
```

## ⚡ Performance Best Practices

### 1. Minimize Recomposition
**Principle**: Optimize composable functions to reduce unnecessary recompositions

```kotlin
// ❌ Bad: Unstable parameters cause recomposition
@Composable
fun UserList(users: List<User>) {
    LazyColumn {
        items(users) { user ->
            UserItem(user = user) // Recomposes on every list change
        }
    }
}

// ✅ Good: Stable parameters with key
@Composable
fun UserList(users: List<User>) {
    LazyColumn {
        items(
            items = users,
            key = { user -> user.id } // Stable key prevents unnecessary recomposition
        ) { user ->
            UserItem(user = user)
        }
    }
}

// Make data classes stable
@Immutable
data class User(
    val id: String,
    val name: String,
    val email: String
)
```

### 2. Efficient State Management
**Principle**: Use appropriate state holders for different scenarios

```kotlin
// ✅ Use remember for UI state
@Composable
fun SearchScreen() {
    var query by remember { mutableStateOf("") }
    var isSearching by remember { mutableStateOf(false) }
    
    // UI state that doesn't need to survive process death
}

// ✅ Use ViewModel for business state
@HiltViewModel
class SearchViewModel @Inject constructor(
    private val repository: SearchRepository
) : ViewModel() {
    
    private val _searchResults = MutableStateFlow<List<SearchResult>>(emptyList())
    val searchResults = _searchResults.asStateFlow()
    
    // State that survives configuration changes
}

// ✅ Use rememberSaveable for state that should survive process death
@Composable
fun FormScreen() {
    var userName by rememberSaveable { mutableStateOf("") }
    var userEmail by rememberSaveable { mutableStateOf("") }
    
    // Form state preserved across process death
}
```

### 3. Lazy Loading Implementation
**Principle**: Load content efficiently for large datasets

```kotlin
@Composable
fun ProductsList(
    products: LazyPagingItems<Product>
) {
    LazyColumn {
        items(products) { product ->
            product?.let { ProductCard(it) }
        }
        
        // Handle loading states
        when (products.loadState.append) {
            is LoadState.Loading -> {
                item {
                    Box(
                        modifier = Modifier.fillMaxWidth(),
                        contentAlignment = Alignment.Center
                    ) {
                        CircularProgressIndicator()
                    }
                }
            }
            is LoadState.Error -> {
                item {
                    ErrorMessage(
                        message = "Failed to load more items",
                        onRetry = { products.retry() }
                    )
                }
            }
            else -> {}
        }
    }
}
```

## 🧪 Testing Best Practices

### 1. Compose UI Testing
**Principle**: Test UI behavior and user interactions

```kotlin
class UserScreenTest {
    
    @get:Rule
    val composeTestRule = createComposeRule()
    
    @Test
    fun userScreen_displaysUserInformation() {
        val testUser = User(
            id = "1",
            name = "John Doe",
            email = "john@example.com"
        )
        
        composeTestRule.setContent {
            UserScreen(user = testUser)
        }
        
        // Verify UI elements
        composeTestRule
            .onNodeWithText("John Doe")
            .assertIsDisplayed()
        
        composeTestRule
            .onNodeWithText("john@example.com")
            .assertIsDisplayed()
    }
    
    @Test
    fun userScreen_clickingEditButton_navigatesToEditScreen() {
        var editClicked = false
        
        composeTestRule.setContent {
            UserScreen(
                user = testUser,
                onEditClick = { editClicked = true }
            )
        }
        
        composeTestRule
            .onNodeWithText("Edit")
            .performClick()
        
        assert(editClicked)
    }
}
```

### 2. ViewModel Testing
**Principle**: Test business logic independently of UI

```kotlin
class UserViewModelTest {
    
    @get:Rule
    val mainDispatcherRule = MainDispatcherRule()
    
    private val testRepository = FakeUserRepository()
    private lateinit var viewModel: UserViewModel
    
    @Before
    fun setup() {
        viewModel = UserViewModel(testRepository)
    }
    
    @Test
    fun `loadUser updates uiState with user data`() = runTest {
        // Given
        val expectedUser = User(id = "1", name = "John", email = "john@test.com")
        testRepository.setUser(expectedUser)
        
        // When
        viewModel.loadUser("1")
        
        // Then
        val uiState = viewModel.uiState.value
        assertEquals(expectedUser, uiState.user)
        assertFalse(uiState.isLoading)
    }
}
```

### 3. Repository Testing
**Principle**: Test data layer with proper mocking

```kotlin
class UserRepositoryTest {
    
    private val mockApiService = mockk<UserApiService>()
    private val mockUserDao = mockk<UserDao>()
    private val repository = UserRepositoryImpl(mockApiService, mockUserDao)
    
    @Test
    fun `getUser returns cached data when network fails`() = runTest {
        // Given
        val cachedUser = UserEntity(id = "1", name = "John", email = "john@test.com")
        every { mockApiService.getUser("1") } throws NetworkException()
        every { mockUserDao.getUser("1") } returns cachedUser
        
        // When
        val result = repository.getUser("1")
        
        // Then
        assertEquals(cachedUser.toDomainModel(), result)
    }
}
```

## 🔒 Security Best Practices

### 1. Secure Data Handling
**Principle**: Protect sensitive user data

```kotlin
// ✅ Use encrypted SharedPreferences for sensitive data
@Module
@InstallIn(SingletonComponent::class)
object SecurityModule {
    
    @Provides
    @Singleton
    fun provideEncryptedSharedPreferences(
        @ApplicationContext context: Context
    ): SharedPreferences {
        val masterKey = MasterKey.Builder(context)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()
        
        return EncryptedSharedPreferences.create(
            context,
            "secure_prefs",
            masterKey,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
        )
    }
}

// ✅ Secure network communication
@Provides
@Singleton
fun provideOkHttpClient(): OkHttpClient {
    return OkHttpClient.Builder()
        .certificatePinner(
            CertificatePinner.Builder()
                .add("api.example.com", "sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=")
                .build()
        )
        .build()
}
```

### 2. Permission Handling
**Principle**: Request permissions responsibly

```kotlin
@Composable
fun CameraPermissionHandler(
    onPermissionGranted: () -> Unit,
    onPermissionDenied: () -> Unit
) {
    val cameraPermissionState = rememberPermissionState(
        android.Manifest.permission.CAMERA
    )
    
    LaunchedEffect(cameraPermissionState.status) {
        when (cameraPermissionState.status) {
            PermissionStatus.Granted -> onPermissionGranted()
            is PermissionStatus.Denied -> {
                if (cameraPermissionState.status.shouldShowRationale) {
                    // Show rationale
                } else {
                    onPermissionDenied()
                }
            }
        }
    }
    
    Button(
        onClick = { cameraPermissionState.launchPermissionRequest() }
    ) {
        Text("Grant Camera Permission")
    }
}
```

## 📱 Platform Best Practices

### 1. Lifecycle Awareness
**Principle**: Respect Android lifecycle in Compose

```kotlin
@Composable
fun LocationTrackingScreen() {
    val lifecycleOwner = LocalLifecycleOwner.current
    
    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            when (event) {
                Lifecycle.Event.ON_START -> startLocationTracking()
                Lifecycle.Event.ON_STOP -> stopLocationTracking()
                else -> {}
            }
        }
        
        lifecycleOwner.lifecycle.addObserver(observer)
        
        onDispose {
            lifecycleOwner.lifecycle.removeObserver(observer)
        }
    }
}
```

### 2. Configuration Changes
**Principle**: Handle configuration changes gracefully

```kotlin
@HiltViewModel
class MediaPlayerViewModel @Inject constructor(
    private val mediaPlayer: MediaPlayer
) : ViewModel() {
    
    private val _isPlaying = MutableStateFlow(false)
    val isPlaying = _isPlaying.asStateFlow()
    
    // State survives configuration changes
    fun togglePlayback() {
        if (_isPlaying.value) {
            mediaPlayer.pause()
        } else {
            mediaPlayer.play()
        }
        _isPlaying.value = !_isPlaying.value
    }
    
    override fun onCleared() {
        super.onCleared()
        mediaPlayer.release()
    }
}
```

## 🚀 Build and Deployment Best Practices

### 1. Build Configuration
**Principle**: Optimize builds for different environments

```kotlin
android {
    buildTypes {
        debug {
            isMinifyEnabled = false
            applicationIdSuffix = ".debug"
            buildConfigField("String", "API_URL", "\"https://api-dev.example.com\"")
        }
        
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            buildConfigField("String", "API_URL", "\"https://api.example.com\"")
        }
        
        create("staging") {
            initWith(release)
            applicationIdSuffix = ".staging"
            buildConfigField("String", "API_URL", "\"https://api-staging.example.com\"")
        }
    }
}
```

### 2. Dependency Management
**Principle**: Use version catalogs for consistent dependency management

```toml
# gradle/libs.versions.toml
[versions]
compose-bom = "2024.02.00"
hilt = "2.48"
retrofit = "2.9.0"

[libraries]
compose-bom = { group = "androidx.compose", name = "compose-bom", version.ref = "compose-bom" }
compose-ui = { group = "androidx.compose.ui", name = "ui" }
compose-material3 = { group = "androidx.compose.material3", name = "material3" }

[bundles]
compose = ["compose-ui", "compose-material3", "compose-ui-tooling-preview"]
```

## 📊 Code Quality Best Practices

### 1. Static Analysis
**Principle**: Use automated tools for code quality

```kotlin
// build.gradle.kts
plugins {
    id("io.gitlab.arturbosch.detekt") version "1.23.4"
}

detekt {
    config.setFrom(file("$projectDir/config/detekt.yml"))
    buildUponDefaultConfig = true
}

dependencies {
    detektPlugins("io.gitlab.arturbosch.detekt:detekt-formatting:1.23.4")
}
```

### 2. Documentation
**Principle**: Document public APIs and complex logic

```kotlin
/**
 * A composable that displays a list of posts with pagination support.
 * 
 * @param posts The paginated list of posts to display
 * @param onPostClick Callback invoked when a post is clicked
 * @param onRefresh Callback invoked when user pulls to refresh
 * @param modifier Modifier to be applied to the root component
 */
@Composable
fun PostsList(
    posts: LazyPagingItems<Post>,
    onPostClick: (Post) -> Unit,
    onRefresh: () -> Unit,
    modifier: Modifier = Modifier
) {
    // Implementation
}
```

## 🎯 Team Collaboration Best Practices

### 1. Code Review Guidelines
- **Focus on Architecture**: Review architectural decisions and patterns
- **Performance Impact**: Check for potential performance issues
- **Accessibility**: Ensure accessibility standards are met
- **Testing**: Verify adequate test coverage
- **Documentation**: Ensure public APIs are documented

### 2. Git Workflow
```bash
# Feature branch naming
feature/user-profile-screen
bugfix/navigation-crash
hotfix/security-vulnerability

# Commit message format
feat(auth): add biometric authentication
fix(ui): resolve crash in user profile screen
docs(readme): update setup instructions
```

---

*Best practices compiled from analysis of 50+ production Jetpack Compose applications and industry standards as of January 2025.*