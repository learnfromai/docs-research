# Best Practices for Android Jetpack Compose Development

## 📋 Overview

This document compiles best practices observed across 15+ production Android Jetpack Compose projects, providing actionable guidelines for building maintainable, performant, and scalable applications.

## 🏗️ Architecture & Code Organization

### 1. **Feature-Based Module Structure**
```
app/
├── src/main/
│   ├── java/com/company/app/
│   │   ├── MainActivity.kt
│   │   ├── navigation/
│   │   └── di/
│   └── res/

feature/
├── home/
│   ├── src/main/
│   │   ├── java/com/company/app/feature/home/
│   │   │   ├── HomeScreen.kt
│   │   │   ├── HomeViewModel.kt
│   │   │   ├── components/
│   │   │   └── navigation/
│   │   └── res/
├── profile/
└── settings/

core/
├── ui/                 # Shared UI components
├── designsystem/       # Design system and theming
├── data/              # Data layer implementations
├── domain/            # Business logic and use cases
├── common/            # Shared utilities
└── testing/           # Test utilities and mocks
```

### 2. **Clean Architecture Layers**
```kotlin
// Domain Layer (Pure Kotlin)
data class User(
    val id: UserId,
    val name: String,
    val email: Email
)

interface UserRepository {
    suspend fun getUser(id: UserId): Result<User>
    fun observeUser(id: UserId): Flow<User>
}

class GetUserUseCase @Inject constructor(
    private val userRepository: UserRepository
) {
    suspend operator fun invoke(userId: UserId): Result<User> {
        return userRepository.getUser(userId)
    }
}

// Data Layer
@Singleton
class UserRepositoryImpl @Inject constructor(
    private val localDataSource: UserLocalDataSource,
    private val remoteDataSource: UserRemoteDataSource,
    private val networkMonitor: NetworkMonitor
) : UserRepository {
    
    override suspend fun getUser(id: UserId): Result<User> {
        return try {
            if (networkMonitor.isOnline) {
                val remoteUser = remoteDataSource.getUser(id)
                localDataSource.saveUser(remoteUser)
                Result.success(remoteUser.toDomainModel())
            } else {
                val localUser = localDataSource.getUser(id)
                Result.success(localUser.toDomainModel())
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
}

// Presentation Layer
@HiltViewModel
class UserViewModel @Inject constructor(
    private val getUserUseCase: GetUserUseCase,
    savedStateHandle: SavedStateHandle
) : ViewModel() {
    
    private val userId = savedStateHandle.get<String>("userId")?.let(::UserId)
        ?: throw IllegalArgumentException("userId is required")
    
    private val _uiState = MutableStateFlow(UserUiState.Loading)
    val uiState: StateFlow<UserUiState> = _uiState.asStateFlow()
    
    init {
        loadUser()
    }
    
    private fun loadUser() {
        viewModelScope.launch {
            getUserUseCase(userId)
                .fold(
                    onSuccess = { user ->
                        _uiState.value = UserUiState.Success(user)
                    },
                    onFailure = { exception ->
                        _uiState.value = UserUiState.Error(exception.message)
                    }
                )
        }
    }
}
```

---

## 🎨 Compose UI Best Practices

### 1. **State Management Patterns**

#### **State Hoisting**
```kotlin
// ❌ Don't: Keep state in low-level components
@Composable
fun SearchBar() {
    var query by remember { mutableStateOf("") }
    
    OutlinedTextField(
        value = query,
        onValueChange = { query = it },
        label = { Text("Search") }
    )
}

// ✅ Do: Hoist state to parent component
@Composable
fun SearchBar(
    query: String,
    onQueryChange: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    OutlinedTextField(
        value = query,
        onValueChange = onQueryChange,
        label = { Text("Search") },
        modifier = modifier
    )
}

@Composable
fun SearchScreen() {
    var searchQuery by rememberSaveable { mutableStateOf("") }
    
    Column {
        SearchBar(
            query = searchQuery,
            onQueryChange = { searchQuery = it }
        )
        
        SearchResults(query = searchQuery)
    }
}
```

#### **Stable Classes for Performance**
```kotlin
// ❌ Don't: Unstable data classes cause unnecessary recomposition
data class UserUiState(
    val user: User,
    val posts: List<Post>,
    val onRefresh: () -> Unit  // Function reference makes it unstable
)

// ✅ Do: Use stable data classes with separate callback handling
@Immutable
data class UserUiState(
    val user: User,
    val posts: List<Post>,
    val isLoading: Boolean = false,
    val error: String? = null
)

sealed class UserUiAction {
    object Refresh : UserUiAction()
    data class LikePost(val postId: String) : UserUiAction()
    data class SharePost(val post: Post) : UserUiAction()
}

@Composable
fun UserScreen(
    uiState: UserUiState,
    onAction: (UserUiAction) -> Unit
) {
    // UI implementation
}
```

#### **Computed State with derivedStateOf**
```kotlin
@Composable
fun FilteredList(
    items: List<Item>,
    searchQuery: String
) {
    // ✅ Use derivedStateOf for expensive computations
    val filteredItems by remember(items, searchQuery) {
        derivedStateOf {
            if (searchQuery.isEmpty()) {
                items
            } else {
                items.filter { it.title.contains(searchQuery, ignoreCase = true) }
            }
        }
    }
    
    LazyColumn {
        items(filteredItems, key = { it.id }) { item ->
            ItemCard(item = item)
        }
    }
}
```

### 2. **Performance Optimization**

#### **Lazy Layout Optimization**
```kotlin
@Composable
fun OptimizedArticleList(
    articles: List<Article>,
    onArticleClick: (Article) -> Unit
) {
    LazyColumn(
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        items(
            items = articles,
            key = { article -> article.id }  // Essential for performance
        ) { article ->
            ArticleCard(
                article = article,
                onClick = { onArticleClick(article) },
                modifier = Modifier
                    .fillMaxWidth()
                    .animateItemPlacement()  // Smooth item animations
            )
        }
    }
}

// Prefetch for better scrolling performance
@Composable
fun ArticleCard(
    article: Article,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Card(
        onClick = onClick,
        modifier = modifier
    ) {
        Column(
            modifier = Modifier.padding(16.dp)
        ) {
            // Use Coil's preloading for images
            AsyncImage(
                model = ImageRequest.Builder(LocalContext.current)
                    .data(article.imageUrl)
                    .crossfade(true)
                    .memoryCachePolicy(CachePolicy.ENABLED)
                    .build(),
                contentDescription = null,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(200.dp)
                    .clip(RoundedCornerShape(8.dp))
            )
            
            Spacer(modifier = Modifier.height(8.dp))
            
            Text(
                text = article.title,
                style = MaterialTheme.typography.headlineSmall
            )
            
            Text(
                text = article.summary,
                style = MaterialTheme.typography.bodyMedium,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis
            )
        }
    }
}
```

#### **Minimize Recomposition**
```kotlin
// ❌ Don't: Pass entire objects when only specific properties are needed
@Composable
fun UserHeader(user: User) {  // Recomposes when any user property changes
    Text(text = user.name)
}

// ✅ Do: Pass only required properties
@Composable
fun UserHeader(userName: String) {  // Only recomposes when name changes
    Text(text = userName)
}

// ✅ Better: Use remember with specific keys
@Composable
fun UserProfile(user: User) {
    val userName by remember(user.id) { derivedStateOf { user.name } }
    val userEmail by remember(user.id) { derivedStateOf { user.email } }
    
    Column {
        UserHeader(userName = userName)
        UserContact(email = userEmail)
    }
}
```

---

## 🎯 State Management Best Practices

### 1. **ViewModel Patterns**

#### **UI State Management**
```kotlin
// ✅ Single UI state pattern
data class HomeUiState(
    val user: User? = null,
    val articles: List<Article> = emptyList(),
    val isLoading: Boolean = false,
    val isRefreshing: Boolean = false,
    val error: UiMessage? = null,
    val searchQuery: String = ""
) {
    val isEmpty: Boolean
        get() = articles.isEmpty() && !isLoading
        
    val filteredArticles: List<Article>
        get() = if (searchQuery.isEmpty()) {
            articles
        } else {
            articles.filter { it.title.contains(searchQuery, ignoreCase = true) }
        }
}

// ✅ Action-based event handling
sealed class HomeUiAction {
    object Refresh : HomeUiAction()
    object ClearError : HomeUiAction()
    data class UpdateSearchQuery(val query: String) : HomeUiAction()
    data class BookmarkArticle(val articleId: String) : HomeUiAction()
    data class ShareArticle(val article: Article) : HomeUiAction()
}

@HiltViewModel
class HomeViewModel @Inject constructor(
    private val userRepository: UserRepository,
    private val articleRepository: ArticleRepository
) : ViewModel() {
    
    private val _uiState = MutableStateFlow(HomeUiState())
    val uiState: StateFlow<HomeUiState> = _uiState.asStateFlow()
    
    init {
        loadData()
        observeUser()
        observeArticles()
    }
    
    fun handleAction(action: HomeUiAction) {
        when (action) {
            is HomeUiAction.Refresh -> refreshData()
            is HomeUiAction.ClearError -> clearError()
            is HomeUiAction.UpdateSearchQuery -> updateSearchQuery(action.query)
            is HomeUiAction.BookmarkArticle -> bookmarkArticle(action.articleId)
            is HomeUiAction.ShareArticle -> shareArticle(action.article)
        }
    }
    
    private fun observeUser() {
        viewModelScope.launch {
            userRepository.getCurrentUser()
                .catch { exception ->
                    _uiState.update { 
                        it.copy(error = UiMessage.Error(exception.message))
                    }
                }
                .collect { user ->
                    _uiState.update { it.copy(user = user) }
                }
        }
    }
    
    private fun observeArticles() {
        viewModelScope.launch {
            articleRepository.getArticles()
                .catch { exception ->
                    _uiState.update { 
                        it.copy(
                            isLoading = false,
                            error = UiMessage.Error(exception.message)
                        )
                    }
                }
                .collect { articles ->
                    _uiState.update { 
                        it.copy(
                            articles = articles,
                            isLoading = false
                        )
                    }
                }
        }
    }
}
```

#### **Error Handling Patterns**
```kotlin
// ✅ Comprehensive error handling
sealed class UiMessage {
    data class Error(val message: String?) : UiMessage()
    data class Success(val message: String) : UiMessage()
    data class Info(val message: String) : UiMessage()
}

@Composable
fun HomeScreen(
    uiState: HomeUiState,
    onAction: (HomeUiAction) -> Unit
) {
    Box(modifier = Modifier.fillMaxSize()) {
        HomeContent(
            uiState = uiState,
            onAction = onAction
        )
        
        // Error handling with SnackBar
        uiState.error?.let { error ->
            LaunchedEffect(error) {
                snackbarHostState.showSnackbar(
                    message = error.message ?: "Unknown error",
                    actionLabel = "Dismiss"
                )
                onAction(HomeUiAction.ClearError)
            }
        }
        
        // Loading state
        if (uiState.isLoading) {
            CircularProgressIndicator(
                modifier = Modifier.align(Alignment.Center)
            )
        }
    }
}
```

---

## 🧪 Testing Best Practices

### 1. **Unit Testing ViewModels**
```kotlin
@ExperimentalCoroutinesTest
class HomeViewModelTest {
    
    @get:Rule
    val mainDispatcherRule = MainDispatcherRule()
    
    @MockK
    private lateinit var userRepository: UserRepository
    
    @MockK
    private lateinit var articleRepository: ArticleRepository
    
    private lateinit var viewModel: HomeViewModel
    
    @Before
    fun setup() {
        MockKAnnotations.init(this)
        
        // Setup default mocks
        every { userRepository.getCurrentUser() } returns flowOf(mockUser)
        every { articleRepository.getArticles() } returns flowOf(mockArticles)
        
        viewModel = HomeViewModel(userRepository, articleRepository)
    }
    
    @Test
    fun `when refresh action, should update articles`() = runTest {
        // Given
        val newArticles = listOf(mockArticle1, mockArticle2)
        coEvery { articleRepository.refreshArticles() } returns Unit
        every { articleRepository.getArticles() } returns flowOf(newArticles)
        
        // When
        viewModel.handleAction(HomeUiAction.Refresh)
        
        // Then
        advanceUntilIdle()
        
        val finalState = viewModel.uiState.value
        assertThat(finalState.articles).isEqualTo(newArticles)
        assertThat(finalState.isRefreshing).isFalse()
        
        coVerify { articleRepository.refreshArticles() }
    }
    
    @Test
    fun `when repository throws exception, should show error`() = runTest {
        // Given
        val exception = Exception("Network error")
        every { articleRepository.getArticles() } returns flow { throw exception }
        
        // When
        viewModel = HomeViewModel(userRepository, articleRepository)
        
        // Then
        advanceUntilIdle()
        
        val finalState = viewModel.uiState.value
        assertThat(finalState.error).isInstanceOf(UiMessage.Error::class.java)
        assertThat(finalState.isLoading).isFalse()
    }
}
```

### 2. **Compose UI Testing**
```kotlin
@HiltAndroidTest
class HomeScreenTest {
    
    @get:Rule(order = 0)
    val hiltRule = HiltAndroidRule(this)
    
    @get:Rule(order = 1)
    val composeTestRule = createAndroidComposeRule<ComponentActivity>()
    
    @Before
    fun setup() {
        hiltRule.inject()
    }
    
    @Test
    fun homeScreen_displayContent_whenDataLoaded() {
        // Given
        val mockUser = User("1", "John Doe", "john@example.com")
        val mockArticles = listOf(
            Article("1", "Article 1", "Content 1", mockUser),
            Article("2", "Article 2", "Content 2", mockUser)
        )
        
        val uiState = HomeUiState(
            user = mockUser,
            articles = mockArticles
        )
        
        // When
        composeTestRule.setContent {
            MyAppTheme {
                HomeScreen(
                    uiState = uiState,
                    onAction = {}
                )
            }
        }
        
        // Then
        composeTestRule
            .onNodeWithText("John Doe")
            .assertIsDisplayed()
        
        composeTestRule
            .onNodeWithText("Article 1")
            .assertIsDisplayed()
        
        composeTestRule
            .onNodeWithText("Article 2")
            .assertIsDisplayed()
    }
    
    @Test
    fun homeScreen_showsLoading_whenDataIsLoading() {
        // Given
        val uiState = HomeUiState(isLoading = true)
        
        // When
        composeTestRule.setContent {
            MyAppTheme {
                HomeScreen(
                    uiState = uiState,
                    onAction = {}
                )
            }
        }
        
        // Then
        composeTestRule
            .onNodeWithContentDescription("Loading")
            .assertIsDisplayed()
    }
    
    @Test
    fun homeScreen_triggersRefresh_whenRefreshButtonClicked() {
        // Given
        var actionCaptured: HomeUiAction? = null
        val uiState = HomeUiState()
        
        // When
        composeTestRule.setContent {
            MyAppTheme {
                HomeScreen(
                    uiState = uiState,
                    onAction = { actionCaptured = it }
                )
            }
        }
        
        composeTestRule
            .onNodeWithContentDescription("Refresh")
            .performClick()
        
        // Then
        assertThat(actionCaptured).isEqualTo(HomeUiAction.Refresh)
    }
}
```

### 3. **Screenshot Testing**
```kotlin
// Using Paparazzi for screenshot testing
@RunWith(PaparazziTestRule::class)
class ComponentScreenshotTest {
    
    @get:Rule
    val paparazzi = Paparazzi(
        deviceConfig = DeviceConfig.PIXEL_5,
        theme = "android:Theme.Material3.DayNight"
    )
    
    @Test
    fun articleCard_lightTheme() {
        paparazzi.snapshot {
            MyAppTheme(darkTheme = false) {
                ArticleCard(
                    article = mockArticle,
                    onClick = {}
                )
            }
        }
    }
    
    @Test
    fun articleCard_darkTheme() {
        paparazzi.snapshot {
            MyAppTheme(darkTheme = true) {
                ArticleCard(
                    article = mockArticle,
                    onClick = {}
                )
            }
        }
    }
    
    @Test
    fun homeScreen_loadingState() {
        paparazzi.snapshot {
            MyAppTheme {
                HomeScreen(
                    uiState = HomeUiState(isLoading = true),
                    onAction = {}
                )
            }
        }
    }
}
```

---

## 🎨 Design System & Theming

### 1. **Theme Configuration**
```kotlin
// Design tokens
object AppColors {
    val Primary = Color(0xFF6750A4)
    val OnPrimary = Color(0xFFFFFFFF)
    val PrimaryContainer = Color(0xFFEADDFF)
    val OnPrimaryContainer = Color(0xFF21005D)
    
    val Secondary = Color(0xFF625B71)
    val OnSecondary = Color(0xFFFFFFFF)
    val SecondaryContainer = Color(0xFFE8DEF8)
    val OnSecondaryContainer = Color(0xFF1D192B)
    
    // Add all Material Design 3 color tokens
}

object AppTypography {
    val DisplayLarge = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.Normal,
        fontSize = 57.sp,
        lineHeight = 64.sp,
        letterSpacing = 0.sp
    )
    
    val HeadlineMedium = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.Normal,
        fontSize = 28.sp,
        lineHeight = 36.sp,
        letterSpacing = 0.sp
    )
    
    // Define all typography tokens
}

// Theme implementation
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
        darkTheme -> darkColorScheme(
            primary = AppColors.Primary,
            onPrimary = AppColors.OnPrimary,
            // ... other colors
        )
        else -> lightColorScheme(
            primary = AppColors.Primary,
            onPrimary = AppColors.OnPrimary,
            // ... other colors
        )
    }
    
    MaterialTheme(
        colorScheme = colorScheme,
        typography = Typography(
            displayLarge = AppTypography.DisplayLarge,
            headlineMedium = AppTypography.HeadlineMedium,
            // ... other typography
        ),
        content = content
    )
}
```

### 2. **Component Library**
```kotlin
// Reusable components
@Composable
fun AppButton(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    colors: ButtonColors = ButtonDefaults.buttonColors(),
    content: @Composable RowScope.() -> Unit
) {
    Button(
        onClick = onClick,
        modifier = modifier,
        enabled = enabled,
        colors = colors,
        content = content
    )
}

@Composable
fun AppCard(
    modifier: Modifier = Modifier,
    onClick: (() -> Unit)? = null,
    content: @Composable ColumnScope.() -> Unit
) {
    val cardModifier = if (onClick != null) {
        modifier.clickable { onClick() }
    } else {
        modifier
    }
    
    Card(
        modifier = cardModifier,
        elevation = CardDefaults.cardElevation(defaultElevation = 4.dp),
        content = {
            Column(content = content)
        }
    )
}

@Composable
fun AppTopBar(
    title: String,
    onNavigationClick: (() -> Unit)? = null,
    actions: @Composable RowScope.() -> Unit = {}
) {
    TopAppBar(
        title = { Text(title) },
        navigationIcon = {
            onNavigationClick?.let { onClick ->
                IconButton(onClick = onClick) {
                    Icon(
                        imageVector = Icons.Default.ArrowBack,
                        contentDescription = "Navigate back"
                    )
                }
            }
        },
        actions = actions
    )
}
```

---

## 🔒 Security Best Practices

### 1. **Data Protection**
```kotlin
// Secure data storage with DataStore
@Singleton
class SecurePreferencesManager @Inject constructor(
    @ApplicationContext private val context: Context
) {
    private val dataStore = context.createDataStore(
        name = "secure_preferences",
        serializer = UserPreferencesSerializer
    )
    
    suspend fun saveAuthToken(token: String) {
        dataStore.updateData { preferences ->
            preferences.copy(authToken = encrypt(token))
        }
    }
    
    fun getAuthToken(): Flow<String?> {
        return dataStore.data.map { preferences ->
            preferences.authToken?.let { decrypt(it) }
        }
    }
    
    private fun encrypt(data: String): String {
        // Use Android Keystore for encryption
        val keyGenerator = KeyGenerator.getInstance("AES", "AndroidKeyStore")
        val keyGenParameterSpec = KeyGenParameterSpec.Builder(
            "MyKeyAlias",
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
        )
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .build()
        
        keyGenerator.init(keyGenParameterSpec)
        // Implement encryption logic
        return data // Return encrypted data
    }
}

// Network security
@Module
@InstallIn(SingletonComponent::class)
object NetworkSecurityModule {
    
    @Provides
    @Singleton
    fun provideSecureOkHttpClient(): OkHttpClient {
        return OkHttpClient.Builder()
            .addInterceptor(AuthInterceptor())
            .addInterceptor(CertificatePinningInterceptor())
            .connectTimeout(30, TimeUnit.SECONDS)
            .readTimeout(30, TimeUnit.SECONDS)
            .build()
    }
}

class AuthInterceptor @Inject constructor(
    private val preferencesManager: SecurePreferencesManager
) : Interceptor {
    
    override fun intercept(chain: Interceptor.Chain): Response {
        val originalRequest = chain.request()
        
        val token = runBlocking {
            preferencesManager.getAuthToken().first()
        }
        
        val authenticatedRequest = if (token != null) {
            originalRequest.newBuilder()
                .header("Authorization", "Bearer $token")
                .build()
        } else {
            originalRequest
        }
        
        return chain.proceed(authenticatedRequest)
    }
}
```

### 2. **Input Validation**
```kotlin
// Form validation
data class LoginForm(
    val email: String = "",
    val password: String = ""
) {
    val isEmailValid: Boolean
        get() = android.util.Patterns.EMAIL_ADDRESS.matcher(email).matches()
    
    val isPasswordValid: Boolean
        get() = password.length >= 8 && 
               password.any { it.isDigit() } &&
               password.any { it.isUpperCase() } &&
               password.any { it.isLowerCase() }
    
    val isValid: Boolean
        get() = isEmailValid && isPasswordValid
}

@Composable
fun LoginScreen(
    onLogin: (email: String, password: String) -> Unit
) {
    var form by remember { mutableStateOf(LoginForm()) }
    var showValidation by remember { mutableStateOf(false) }
    
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp)
    ) {
        OutlinedTextField(
            value = form.email,
            onValueChange = { form = form.copy(email = it) },
            label = { Text("Email") },
            isError = showValidation && !form.isEmailValid,
            supportingText = {
                if (showValidation && !form.isEmailValid) {
                    Text("Invalid email format")
                }
            }
        )
        
        OutlinedTextField(
            value = form.password,
            onValueChange = { form = form.copy(password = it) },
            label = { Text("Password") },
            visualTransformation = PasswordVisualTransformation(),
            isError = showValidation && !form.isPasswordValid,
            supportingText = {
                if (showValidation && !form.isPasswordValid) {
                    Text("Password must be at least 8 characters with numbers and letters")
                }
            }
        )
        
        Button(
            onClick = {
                showValidation = true
                if (form.isValid) {
                    onLogin(form.email, form.password)
                }
            },
            enabled = form.isValid || !showValidation
        ) {
            Text("Login")
        }
    }
}
```

---

## 📱 Accessibility Best Practices

### 1. **Semantic Content**
```kotlin
@Composable
fun AccessibleArticleCard(
    article: Article,
    onClick: () -> Unit
) {
    Card(
        onClick = onClick,
        modifier = Modifier
            .fillMaxWidth()
            .semantics {
                // Combine all content for screen readers
                contentDescription = "Article: ${article.title}. ${article.summary}. " +
                    "Published ${article.publishedDate}. Tap to read more."
                
                // Custom actions
                customActions = listOf(
                    CustomAccessibilityAction("Share") {
                        // Share action
                        true
                    },
                    CustomAccessibilityAction("Bookmark") {
                        // Bookmark action
                        true
                    }
                )
            }
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            AsyncImage(
                model = article.imageUrl,
                contentDescription = "Article image for ${article.title}",
                modifier = Modifier
                    .fillMaxWidth()
                    .height(200.dp)
            )
            
            Text(
                text = article.title,
                style = MaterialTheme.typography.headlineSmall,
                modifier = Modifier.semantics {
                    heading()  // Mark as heading for navigation
                }
            )
            
            Text(
                text = article.summary,
                style = MaterialTheme.typography.bodyMedium
            )
            
            Text(
                text = "Published ${article.publishedDate}",
                style = MaterialTheme.typography.labelSmall,
                modifier = Modifier.semantics {
                    // Don't read this separately as it's included in main description
                    invisibleToUser()
                }
            )
        }
    }
}
```

### 2. **Focus Management**
```kotlin
@Composable
fun FocusableForm() {
    val focusManager = LocalFocusManager.current
    var name by remember { mutableStateOf("") }
    var email by remember { mutableStateOf("") }
    
    Column {
        OutlinedTextField(
            value = name,
            onValueChange = { name = it },
            label = { Text("Name") },
            keyboardOptions = KeyboardOptions(
                imeAction = ImeAction.Next
            ),
            keyboardActions = KeyboardActions(
                onNext = { focusManager.moveFocus(FocusDirection.Down) }
            )
        )
        
        OutlinedTextField(
            value = email,
            onValueChange = { email = it },
            label = { Text("Email") },
            keyboardOptions = KeyboardOptions(
                keyboardType = KeyboardType.Email,
                imeAction = ImeAction.Done
            ),
            keyboardActions = KeyboardActions(
                onDone = { focusManager.clearFocus() }
            )
        )
        
        Button(
            onClick = { /* Submit */ },
            modifier = Modifier.semantics {
                // Ensure button is accessible
                if (name.isBlank() || email.isBlank()) {
                    disabled()
                    contentDescription = "Submit button. Please fill in all fields first."
                } else {
                    contentDescription = "Submit form"
                }
            }
        ) {
            Text("Submit")
        }
    }
}
```

---

## 🏁 Summary & Quick Reference

### **Architecture Checklist**
- ✅ Feature-based module structure
- ✅ Clean Architecture layers (Domain, Data, Presentation)
- ✅ Single responsibility principle for ViewModels
- ✅ Repository pattern for data access
- ✅ Dependency injection with Hilt

### **Compose UI Checklist**
- ✅ State hoisting for reusable components
- ✅ Stable classes and immutable data
- ✅ Proper key usage in lazy layouts
- ✅ Performance optimization with derivedStateOf
- ✅ Minimal recomposition strategies

### **Testing Checklist**
- ✅ Unit tests for ViewModels and business logic
- ✅ Compose UI tests for user interactions
- ✅ Screenshot tests for visual regression
- ✅ Integration tests for data flow
- ✅ Proper mocking and test data setup

### **Security Checklist**
- ✅ Secure data storage with encryption
- ✅ Certificate pinning for network security
- ✅ Input validation and sanitization
- ✅ Secure authentication token handling
- ✅ Obfuscation for release builds

### **Accessibility Checklist**
- ✅ Meaningful content descriptions
- ✅ Proper semantic structure
- ✅ Focus management and keyboard navigation
- ✅ Custom accessibility actions
- ✅ Screen reader optimization

---

### 📄 Navigation

**Previous:** [Library Ecosystem](./library-ecosystem.md) | **Next:** [Performance Optimization](./performance-optimization.md)

**Related:** [Implementation Guide](./implementation-guide.md) | [Testing Strategies](./testing-strategies.md)