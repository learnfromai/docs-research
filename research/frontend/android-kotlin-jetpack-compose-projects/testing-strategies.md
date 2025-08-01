# Testing Strategies for Jetpack Compose Applications

## 🧪 Testing Pyramid for Compose

Based on successful open source projects, a balanced testing approach includes:
- **70% Unit Tests**: ViewModels, repositories, use cases
- **20% Integration Tests**: Feature-level testing with real dependencies
- **10% UI Tests**: Critical user journeys and interactions

## 🎯 Unit Testing

### ViewModel Testing
```kotlin
@ExperimentalCoroutinesApi
class HomeViewModelTest {
    
    @get:Rule
    val mainDispatcherRule = MainDispatcherRule()
    
    private val testRepository = FakeHomeRepository()
    private lateinit var viewModel: HomeViewModel
    
    @Before
    fun setup() {
        viewModel = HomeViewModel(testRepository)
    }
    
    @Test
    fun `loadPosts updates uiState with posts`() = runTest {
        // Given
        val expectedPosts = listOf(
            Post(id = "1", title = "Test Post 1"),
            Post(id = "2", title = "Test Post 2")
        )
        testRepository.setPosts(expectedPosts)
        
        // When
        viewModel.loadPosts()
        
        // Then
        val uiState = viewModel.uiState.value
        assertEquals(expectedPosts, uiState.posts)
        assertFalse(uiState.isLoading)
    }
}
```

## 🎨 Compose UI Testing

### Screen Testing
```kotlin
@RunWith(AndroidJUnit4::class)
class HomeScreenTest {
    
    @get:Rule
    val composeTestRule = createComposeRule()
    
    @Test
    fun homeScreen_displaysPostsCorrectly() {
        val testPosts = listOf(
            Post(id = "1", title = "Test Post 1"),
            Post(id = "2", title = "Test Post 2")
        )
        
        composeTestRule.setContent {
            HomeScreen(
                uiState = HomeUiState(posts = testPosts),
                onEvent = {}
            )
        }
        
        composeTestRule
            .onNodeWithText("Test Post 1")
            .assertIsDisplayed()
        
        composeTestRule
            .onNodeWithText("Test Post 2")
            .assertIsDisplayed()
    }
    
    @Test
    fun homeScreen_clickingPost_triggersNavigation() {
        var clickedPostId: String? = null
        
        composeTestRule.setContent {
            HomeScreen(
                uiState = HomeUiState(posts = testPosts),
                onEvent = { event ->
                    if (event is HomeEvent.PostClicked) {
                        clickedPostId = event.postId
                    }
                }
            )
        }
        
        composeTestRule
            .onNodeWithText("Test Post 1")
            .performClick()
        
        assertEquals("1", clickedPostId)
    }
}
```

## 🔄 Integration Testing

### Repository Testing
```kotlin
@RunWith(AndroidJUnit4::class)
class PostRepositoryTest {
    
    @get:Rule
    val hiltRule = HiltAndroidRule(this)
    
    @Inject
    lateinit var database: AppDatabase
    
    @Inject
    lateinit var repository: PostRepository
    
    @Before
    fun setup() {
        hiltRule.inject()
    }
    
    @Test
    fun repository_cachesPostsFromNetwork() = runTest {
        // Given
        val networkPosts = listOf(
            Post(id = "1", title = "Network Post")
        )
        mockWebServer.enqueue(
            MockResponse()
                .setBody(gson.toJson(networkPosts))
                .setResponseCode(200)
        )
        
        // When
        val result = repository.getPosts(forceRefresh = true)
        
        // Then
        assertEquals(networkPosts, result)
        
        // Verify cached in database
        val cachedPosts = database.postDao().getAllPosts().first()
        assertEquals(1, cachedPosts.size)
    }
}
```

## 📱 End-to-End Testing

### User Journey Testing
```kotlin
@RunWith(AndroidJUnit4::class)
@LargeTest
class LoginUserJourneyTest {
    
    @get:Rule
    val composeTestRule = createAndroidComposeRule<MainActivity>()
    
    @Test
    fun completeLoginFlow_navigatesToHome() {
        // Start at login screen
        composeTestRule
            .onNodeWithText("Email")
            .performTextInput("test@example.com")
        
        composeTestRule
            .onNodeWithText("Password")
            .performTextInput("password123")
        
        composeTestRule
            .onNodeWithText("Login")
            .performClick()
        
        // Verify navigation to home
        composeTestRule
            .onNodeWithText("Welcome to Home")
            .assertIsDisplayed()
    }
}
```

---

*Testing strategies compiled from analysis of well-tested Jetpack Compose projects as of January 2025.*