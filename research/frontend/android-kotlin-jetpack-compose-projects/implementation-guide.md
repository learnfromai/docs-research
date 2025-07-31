# Implementation Guide: Setting Up Android Jetpack Compose Projects

## 📋 Overview

This comprehensive guide provides step-by-step instructions for setting up a production-ready Android Jetpack Compose project based on best practices observed across 15+ open source applications.

## 🚀 Project Setup

### 1. **Prerequisites & Environment Setup**

#### **Required Tools**
- **Android Studio**: Giraffe (2022.3.1) or later
- **JDK**: Java 17 (recommended)
- **Android SDK**: API level 34 (Android 14)
- **Gradle**: 8.0 or later
- **Kotlin**: 1.9.20 or later

#### **Android Studio Configuration**
```bash
# Set JVM heap size for better performance
# Add to android-studio/bin/studio64.vmoptions
-Xmx4g
-XX:MaxMetaspaceSize=1g
-XX:+UseG1GC
```

### 2. **Project Creation**

#### **Step 1: Create New Project**
```bash
# Using Android Studio or command line
# Choose "Empty Activity" template with Compose
# Set minimum SDK to API 24 (Android 7.0)
```

#### **Step 2: Configure Project Structure**
```
my-compose-app/
├── app/                    # Main application module
├── feature/               # Feature modules
│   ├── home/
│   ├── profile/
│   └── settings/
├── core/                  # Core modules
│   ├── common/           # Shared utilities
│   ├── data/             # Data layer
│   ├── database/         # Local database
│   ├── datastore/        # Preferences storage
│   ├── designsystem/     # Design system
│   ├── domain/           # Business logic
│   ├── model/            # Data models
│   ├── network/          # Network layer
│   ├── testing/          # Test utilities
│   └── ui/               # Shared UI components
├── gradle/               # Gradle configuration
│   └── libs.versions.toml
├── build.gradle.kts
├── settings.gradle.kts
└── gradle.properties
```

---

## ⚙️ Gradle Configuration

### 1. **Root Level Configuration**

#### **settings.gradle.kts**
```kotlin
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "MyComposeApp"

// Include all modules
include(":app")

// Feature modules
include(":feature:home")
include(":feature:profile")
include(":feature:settings")

// Core modules
include(":core:common")
include(":core:data")
include(":core:database")
include(":core:datastore")
include(":core:designsystem")
include(":core:domain")
include(":core:model")
include(":core:network")
include(":core:testing")
include(":core:ui")
```

#### **gradle.properties**
```properties
# Gradle optimizations
org.gradle.caching=true
org.gradle.parallel=true
org.gradle.configureondemand=true
org.gradle.daemon=true
org.gradle.jvmargs=-Xmx4g -XX:MaxMetaspaceSize=1g -XX:+HeapDumpOnOutOfMemoryError

# Kotlin optimizations
kotlin.compiler.execution.strategy=in-process
kotlin.incremental=true
kotlin.incremental.android=true

# Android optimizations
android.useAndroidX=true
android.enableJetifier=false
android.nonTransitiveRClass=true
android.nonFinalResIds=true
android.experimental.enableResourceOptimizations=true

# Compose optimizations
android.enableResourceOptimizations=true
```

#### **gradle/libs.versions.toml**
```toml
[versions]
kotlin = "1.9.20"
android-gradle-plugin = "8.1.2"
compose-bom = "2023.10.01"
compose-compiler = "1.5.4"
hilt = "2.48"
retrofit = "2.9.0"
room = "2.6.0"
navigation = "2.7.5"
lifecycle = "2.7.0"
coil = "2.5.0"
kotlinx-serialization = "1.6.0"
coroutines = "1.7.3"
okhttp = "4.12.0"

[libraries]
# Android
android-gradle-plugin = { group = "com.android.tools.build", name = "gradle", version.ref = "android-gradle-plugin" }
kotlin-gradle-plugin = { group = "org.jetbrains.kotlin", name = "kotlin-gradle-plugin", version.ref = "kotlin" }

# Compose BOM
compose-bom = { group = "androidx.compose", name = "compose-bom", version.ref = "compose-bom" }
compose-ui = { group = "androidx.compose.ui", name = "ui" }
compose-ui-tooling = { group = "androidx.compose.ui", name = "ui-tooling" }
compose-ui-tooling-preview = { group = "androidx.compose.ui", name = "ui-tooling-preview" }
compose-ui-test-junit4 = { group = "androidx.compose.ui", name = "ui-test-junit4" }
compose-ui-test-manifest = { group = "androidx.compose.ui", name = "ui-test-manifest" }
compose-material3 = { group = "androidx.compose.material3", name = "material3" }
compose-activity = { group = "androidx.activity", name = "activity-compose", version = "1.8.0" }

# Navigation
navigation-compose = { group = "androidx.navigation", name = "navigation-compose", version.ref = "navigation" }

# Lifecycle
lifecycle-viewmodel-compose = { group = "androidx.lifecycle", name = "lifecycle-viewmodel-compose", version.ref = "lifecycle" }
lifecycle-runtime-compose = { group = "androidx.lifecycle", name = "lifecycle-runtime-compose", version.ref = "lifecycle" }

# Dependency Injection
hilt-android = { group = "com.google.dagger", name = "hilt-android", version.ref = "hilt" }
hilt-compiler = { group = "com.google.dagger", name = "hilt-compiler", version.ref = "hilt" }
hilt-navigation-compose = { group = "androidx.hilt", name = "hilt-navigation-compose", version = "1.1.0" }

# Networking
retrofit = { group = "com.squareup.retrofit2", name = "retrofit", version.ref = "retrofit" }
retrofit-converter-kotlinx-serialization = { group = "com.jakewharton.retrofit", name = "retrofit2-kotlinx-serialization-converter", version = "1.0.0" }
okhttp = { group = "com.squareup.okhttp3", name = "okhttp", version.ref = "okhttp" }
okhttp-logging-interceptor = { group = "com.squareup.okhttp3", name = "logging-interceptor", version.ref = "okhttp" }

# Serialization
kotlinx-serialization-json = { group = "org.jetbrains.kotlinx", name = "kotlinx-serialization-json", version.ref = "kotlinx-serialization" }

# Coroutines
kotlinx-coroutines-core = { group = "org.jetbrains.kotlinx", name = "kotlinx-coroutines-core", version.ref = "coroutines" }
kotlinx-coroutines-android = { group = "org.jetbrains.kotlinx", name = "kotlinx-coroutines-android", version.ref = "coroutines" }

# Database
room-runtime = { group = "androidx.room", name = "room-runtime", version.ref = "room" }
room-compiler = { group = "androidx.room", name = "room-compiler", version.ref = "room" }
room-ktx = { group = "androidx.room", name = "room-ktx", version.ref = "room" }

# DataStore
datastore-preferences = { group = "androidx.datastore", name = "datastore-preferences", version = "1.0.0" }

# Image Loading
coil-compose = { group = "io.coil-kt", name = "coil-compose", version.ref = "coil" }

# Testing
junit = { group = "junit", name = "junit", version = "4.13.2" }
mockk = { group = "io.mockk", name = "mockk", version = "1.13.8" }
kotlinx-coroutines-test = { group = "org.jetbrains.kotlinx", name = "kotlinx-coroutines-test", version.ref = "coroutines" }
turbine = { group = "app.cash.turbine", name = "turbine", version = "1.0.0" }
androidx-test-ext-junit = { group = "androidx.test.ext", name = "junit", version = "1.1.5" }
androidx-test-espresso-core = { group = "androidx.test.espresso", name = "espresso-core", version = "3.5.1" }
hilt-android-testing = { group = "com.google.dagger", name = "hilt-android-testing", version.ref = "hilt" }

[plugins]
android-application = { id = "com.android.application", version.ref = "android-gradle-plugin" }
android-library = { id = "com.android.library", version.ref = "android-gradle-plugin" }
kotlin-android = { id = "org.jetbrains.kotlin.android", version.ref = "kotlin" }
kotlin-serialization = { id = "org.jetbrains.kotlin.plugin.serialization", version.ref = "kotlin" }
hilt = { id = "com.google.dagger.hilt.android", version.ref = "hilt" }
```

### 2. **App Module Configuration**

#### **app/build.gradle.kts**
```kotlin
plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.serialization)
    alias(libs.plugins.hilt)
    kotlin("kapt")
}

android {
    namespace = "com.company.mycomposeapp"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.company.mycomposeapp"
        minSdk = 24
        targetSdk = 34
        versionCode = 1
        versionName = "1.0"

        testInstrumentationRunner = "com.company.mycomposeapp.core.testing.HiltTestRunner"
        vectorDrawables {
            useSupportLibrary = true
        }
    }

    buildTypes {
        debug {
            isDebuggable = true
            isMinifyEnabled = false
            applicationIdSuffix = ".debug"
            versionNameSuffix = "-debug"
        }
        
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
    
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }
    
    kotlinOptions {
        jvmTarget = "17"
        freeCompilerArgs += listOf(
            "-opt-in=kotlin.RequiresOptIn",
            "-opt-in=androidx.compose.material3.ExperimentalMaterial3Api",
            "-opt-in=androidx.compose.foundation.ExperimentalFoundationApi"
        )
    }
    
    buildFeatures {
        compose = true
        buildConfig = true
    }
    
    composeOptions {
        kotlinCompilerExtensionVersion = libs.versions.compose.compiler.get()
    }
    
    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }
}

dependencies {
    val composeBom = platform(libs.compose.bom)
    implementation(composeBom)
    androidTestImplementation(composeBom)

    // Core modules
    implementation(project(":core:common"))
    implementation(project(":core:data"))
    implementation(project(":core:designsystem"))
    implementation(project(":core:domain"))
    implementation(project(":core:model"))
    implementation(project(":core:ui"))

    // Feature modules
    implementation(project(":feature:home"))
    implementation(project(":feature:profile"))
    implementation(project(":feature:settings"))

    // Core Android
    implementation(libs.compose.ui)
    implementation(libs.compose.ui.tooling.preview)
    implementation(libs.compose.material3)
    implementation(libs.compose.activity)
    implementation(libs.lifecycle.viewmodel.compose)
    implementation(libs.lifecycle.runtime.compose)

    // Navigation
    implementation(libs.navigation.compose)

    // Dependency Injection
    implementation(libs.hilt.android)
    implementation(libs.hilt.navigation.compose)
    kapt(libs.hilt.compiler)

    // Testing
    testImplementation(libs.junit)
    testImplementation(libs.mockk)
    testImplementation(libs.kotlinx.coroutines.test)
    testImplementation(project(":core:testing"))
    
    androidTestImplementation(libs.androidx.test.ext.junit)
    androidTestImplementation(libs.androidx.test.espresso.core)
    androidTestImplementation(libs.compose.ui.test.junit4)
    androidTestImplementation(libs.hilt.android.testing)
    kaptAndroidTest(libs.hilt.compiler)
    
    debugImplementation(libs.compose.ui.tooling)
    debugImplementation(libs.compose.ui.test.manifest)
    
    // Desugaring
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}

kapt {
    correctErrorTypes = true
    useBuildCache = true
}
```

---

## 🏗️ Core Module Implementation

### 1. **Create Core Modules**

#### **Step 1: Core Common Module**
```bash
# Create core/common module
mkdir -p core/common/src/main/java/com/company/mycomposeapp/core/common
```

#### **core/common/build.gradle.kts**
```kotlin
plugins {
    alias(libs.plugins.android.library)
    alias(libs.plugins.kotlin.android)
}

android {
    namespace = "com.company.mycomposeapp.core.common"
    compileSdk = 34

    defaultConfig {
        minSdk = 24
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }
}

dependencies {
    implementation(libs.kotlinx.coroutines.core)
    api(libs.kotlinx.coroutines.android)
}
```

#### **Common utilities**
```kotlin
// core/common/src/main/java/com/company/mycomposeapp/core/common/Result.kt
sealed interface Result<out T> {
    data class Success<T>(val data: T) : Result<T>
    data class Error(val exception: Throwable) : Result<Nothing>
    object Loading : Result<Nothing>
}

inline fun <T> Result<T>.onSuccess(action: (value: T) -> Unit): Result<T> {
    if (this is Result.Success) action(data)
    return this
}

inline fun <T> Result<T>.onError(action: (exception: Throwable) -> Unit): Result<T> {
    if (this is Result.Error) action(exception)
    return this
}

// core/common/src/main/java/com/company/mycomposeapp/core/common/NetworkMonitor.kt
interface NetworkMonitor {
    val isOnline: Flow<Boolean>
}

// core/common/src/main/java/com/company/mycomposeapp/core/common/Dispatcher.kt
@Qualifier
@Retention(AnnotationRetention.RUNTIME)
annotation class Dispatcher(val dispatcher: AppDispatchers)

enum class AppDispatchers {
    Default,
    IO,
    Main,
    Unconfined
}
```

### 2. **Model Module**

#### **core/model/build.gradle.kts**
```kotlin
plugins {
    alias(libs.plugins.android.library)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.serialization)
}

android {
    namespace = "com.company.mycomposeapp.core.model"
    compileSdk = 34
    
    defaultConfig {
        minSdk = 24
    }
}

dependencies {
    implementation(libs.kotlinx.serialization.json)
}
```

#### **Domain Models**
```kotlin
// core/model/src/main/java/com/company/mycomposeapp/core/model/User.kt
@Serializable
data class User(
    val id: String,
    val name: String,
    val email: String,
    val avatarUrl: String? = null,
    val createdAt: String
)

// core/model/src/main/java/com/company/mycomposeapp/core/model/Article.kt
@Serializable
data class Article(
    val id: String,
    val title: String,
    val content: String,
    val summary: String,
    @SerialName("published_at")
    val publishedAt: String,
    @SerialName("image_url")
    val imageUrl: String? = null,
    val author: User
)
```

### 3. **Network Module**

#### **core/network/build.gradle.kts**
```kotlin
plugins {
    alias(libs.plugins.android.library)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.serialization)
    alias(libs.plugins.hilt)
    kotlin("kapt")
}

android {
    namespace = "com.company.mycomposeapp.core.network"
    compileSdk = 34
    
    defaultConfig {
        minSdk = 24
        
        buildConfigField("String", "API_BASE_URL", "\"https://api.example.com/\"")
    }
    
    buildFeatures {
        buildConfig = true
    }
}

dependencies {
    implementation(project(":core:common"))
    implementation(project(":core:model"))
    
    implementation(libs.retrofit)
    implementation(libs.retrofit.converter.kotlinx.serialization)
    implementation(libs.okhttp)
    implementation(libs.okhttp.logging.interceptor)
    implementation(libs.kotlinx.serialization.json)
    
    implementation(libs.hilt.android)
    kapt(libs.hilt.compiler)
}
```

#### **Network Implementation**
```kotlin
// core/network/src/main/java/com/company/mycomposeapp/core/network/di/NetworkModule.kt
@Module
@InstallIn(SingletonComponent::class)
object NetworkModule {
    
    @Provides
    @Singleton
    fun provideJson(): Json = Json {
        ignoreUnknownKeys = true
        coerceInputValues = true
        encodeDefaults = true
    }
    
    @Provides
    @Singleton
    fun provideOkHttpClient(): OkHttpClient {
        return OkHttpClient.Builder()
            .addInterceptor(
                HttpLoggingInterceptor().apply {
                    level = if (BuildConfig.DEBUG) {
                        HttpLoggingInterceptor.Level.BODY
                    } else {
                        HttpLoggingInterceptor.Level.NONE
                    }
                }
            )
            .connectTimeout(30, TimeUnit.SECONDS)
            .readTimeout(30, TimeUnit.SECONDS)
            .build()
    }
    
    @Provides
    @Singleton
    fun provideRetrofit(
        okHttpClient: OkHttpClient,
        json: Json
    ): Retrofit {
        return Retrofit.Builder()
            .baseUrl(BuildConfig.API_BASE_URL)
            .client(okHttpClient)
            .addConverterFactory(json.asConverterFactory("application/json".toMediaType()))
            .build()
    }
    
    @Provides
    @Singleton
    fun provideApiService(retrofit: Retrofit): ApiService = retrofit.create()
}

// API Service
interface ApiService {
    @GET("users/{id}")
    suspend fun getUser(@Path("id") id: String): User
    
    @GET("articles")
    suspend fun getArticles(
        @Query("page") page: Int = 1,
        @Query("limit") limit: Int = 20
    ): List<Article>
}
```

### 4. **Database Module**

#### **core/database/build.gradle.kts**
```kotlin
plugins {
    alias(libs.plugins.android.library)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.hilt)
    kotlin("kapt")
}

android {
    namespace = "com.company.mycomposeapp.core.database"
    compileSdk = 34
    
    defaultConfig {
        minSdk = 24
    }
}

dependencies {
    implementation(project(":core:model"))
    
    implementation(libs.room.runtime)
    implementation(libs.room.ktx)
    kapt(libs.room.compiler)
    
    implementation(libs.hilt.android)
    kapt(libs.hilt.compiler)
}
```

#### **Database Implementation**
```kotlin
// core/database/src/main/java/com/company/mycomposeapp/core/database/entity/UserEntity.kt
@Entity(tableName = "users")
data class UserEntity(
    @PrimaryKey val id: String,
    val name: String,
    val email: String,
    @ColumnInfo(name = "avatar_url") val avatarUrl: String?,
    @ColumnInfo(name = "created_at") val createdAt: String
)

// Extension functions for mapping
fun UserEntity.toDomainModel(): User = User(
    id = id,
    name = name,
    email = email,
    avatarUrl = avatarUrl,
    createdAt = createdAt
)

fun User.toEntity(): UserEntity = UserEntity(
    id = id,
    name = name,
    email = email,
    avatarUrl = avatarUrl,
    createdAt = createdAt
)

// DAO
@Dao
interface UserDao {
    @Query("SELECT * FROM users WHERE id = :id")
    suspend fun getUser(id: String): UserEntity?
    
    @Query("SELECT * FROM users")
    fun observeUsers(): Flow<List<UserEntity>>
    
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertUser(user: UserEntity)
    
    @Update
    suspend fun updateUser(user: UserEntity)
    
    @Delete
    suspend fun deleteUser(user: UserEntity)
}

// Database
@Database(
    entities = [UserEntity::class, ArticleEntity::class],
    version = 1,
    exportSchema = true
)
abstract class AppDatabase : RoomDatabase() {
    abstract fun userDao(): UserDao
    abstract fun articleDao(): ArticleDao
}

// Database Module
@Module
@InstallIn(SingletonComponent::class)
object DatabaseModule {
    
    @Provides
    @Singleton
    fun provideAppDatabase(@ApplicationContext context: Context): AppDatabase {
        return Room.databaseBuilder(
            context,
            AppDatabase::class.java,
            "app-database"
        ).build()
    }
    
    @Provides
    fun provideUserDao(database: AppDatabase): UserDao = database.userDao()
    
    @Provides
    fun provideArticleDao(database: AppDatabase): ArticleDao = database.articleDao()
}
```

---

## 🎨 UI & Design System Setup

### 1. **Design System Module**

#### **core/designsystem/build.gradle.kts**
```kotlin
plugins {
    alias(libs.plugins.android.library)
    alias(libs.plugins.kotlin.android)
}

android {
    namespace = "com.company.mycomposeapp.core.designsystem"
    compileSdk = 34
    
    defaultConfig {
        minSdk = 24
    }
    
    buildFeatures {
        compose = true
    }
    
    composeOptions {
        kotlinCompilerExtensionVersion = libs.versions.compose.compiler.get()
    }
}

dependencies {
    val composeBom = platform(libs.compose.bom)
    implementation(composeBom)
    
    api(libs.compose.ui)
    api(libs.compose.ui.tooling.preview)
    api(libs.compose.material3)
    
    debugImplementation(libs.compose.ui.tooling)
}
```

#### **Theme Implementation**
```kotlin
// core/designsystem/src/main/java/com/company/mycomposeapp/core/designsystem/theme/Color.kt
val Primary = Color(0xFF6750A4)
val OnPrimary = Color(0xFFFFFFFF)
val PrimaryContainer = Color(0xFFEADDFF)
val OnPrimaryContainer = Color(0xFF21005D)

val Secondary = Color(0xFF625B71)
val OnSecondary = Color(0xFFFFFFFF)
val SecondaryContainer = Color(0xFFE8DEF8)
val OnSecondaryContainer = Color(0xFF1D192B)

// Define all Material Design 3 color tokens...

private val LightColorScheme = lightColorScheme(
    primary = Primary,
    onPrimary = OnPrimary,
    primaryContainer = PrimaryContainer,
    onPrimaryContainer = OnPrimaryContainer,
    // ... other colors
)

private val DarkColorScheme = darkColorScheme(
    primary = Color(0xFFD0BCFF),
    onPrimary = Color(0xFF381E72),
    primaryContainer = Color(0xFF4F378B),
    onPrimaryContainer = Color(0xFFEADDFF),
    // ... other colors
)

// Theme composable
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

### 2. **Shared UI Components**

#### **core/ui/build.gradle.kts**
```kotlin
plugins {
    alias(libs.plugins.android.library)
    alias(libs.plugins.kotlin.android)
}

android {
    namespace = "com.company.mycomposeapp.core.ui"
    compileSdk = 34
    
    defaultConfig {
        minSdk = 24
    }
    
    buildFeatures {
        compose = true
    }
    
    composeOptions {
        kotlinCompilerExtensionVersion = libs.versions.compose.compiler.get()
    }
}

dependencies {
    implementation(project(":core:designsystem"))
    implementation(project(":core:model"))
    
    val composeBom = platform(libs.compose.bom)
    implementation(composeBom)
    
    api(libs.compose.ui)
    api(libs.compose.ui.tooling.preview)
    api(libs.compose.material3)
    implementation(libs.coil.compose)
    
    debugImplementation(libs.compose.ui.tooling)
}
```

#### **Reusable Components**
```kotlin
// core/ui/src/main/java/com/company/mycomposeapp/core/ui/components/UserAvatar.kt
@Composable
fun UserAvatar(
    imageUrl: String?,
    contentDescription: String?,
    modifier: Modifier = Modifier,
    size: Dp = 40.dp
) {
    AsyncImage(
        model = ImageRequest.Builder(LocalContext.current)
            .data(imageUrl)
            .crossfade(true)
            .build(),
        contentDescription = contentDescription,
        modifier = modifier
            .size(size)
            .clip(CircleShape),
        contentScale = ContentScale.Crop,
        placeholder = painterResource(R.drawable.ic_person_placeholder),
        error = painterResource(R.drawable.ic_person_placeholder)
    )
}

// core/ui/src/main/java/com/company/mycomposeapp/core/ui/components/LoadingButton.kt
@Composable
fun LoadingButton(
    onClick: () -> Unit,
    text: String,
    modifier: Modifier = Modifier,
    isLoading: Boolean = false,
    enabled: Boolean = true
) {
    Button(
        onClick = onClick,
        modifier = modifier,
        enabled = enabled && !isLoading
    ) {
        if (isLoading) {
            CircularProgressIndicator(
                modifier = Modifier.size(16.dp),
                strokeWidth = 2.dp,
                color = MaterialTheme.colorScheme.onPrimary
            )
        } else {
            Text(text)
        }
    }
}
```

---

## 🏠 Feature Module Implementation

### 1. **Home Feature Module**

#### **feature/home/build.gradle.kts**
```kotlin
plugins {
    alias(libs.plugins.android.library)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.hilt)
    kotlin("kapt")
}

android {
    namespace = "com.company.mycomposeapp.feature.home"
    compileSdk = 34
    
    defaultConfig {
        minSdk = 24
    }
    
    buildFeatures {
        compose = true
    }
    
    composeOptions {
        kotlinCompilerExtensionVersion = libs.versions.compose.compiler.get()
    }
}

dependencies {
    implementation(project(":core:common"))
    implementation(project(":core:data"))
    implementation(project(":core:designsystem"))
    implementation(project(":core:domain"))
    implementation(project(":core:model"))
    implementation(project(":core:ui"))
    
    val composeBom = platform(libs.compose.bom)
    implementation(composeBom)
    
    implementation(libs.compose.ui)
    implementation(libs.compose.ui.tooling.preview)
    implementation(libs.compose.material3)
    implementation(libs.lifecycle.viewmodel.compose)
    implementation(libs.lifecycle.runtime.compose)
    
    implementation(libs.hilt.android)
    implementation(libs.hilt.navigation.compose)
    kapt(libs.hilt.compiler)
    
    debugImplementation(libs.compose.ui.tooling)
}
```

#### **Home Feature Implementation**
```kotlin
// feature/home/src/main/java/com/company/mycomposeapp/feature/home/HomeViewModel.kt
@HiltViewModel
class HomeViewModel @Inject constructor(
    private val getUserUseCase: GetUserUseCase,
    private val getArticlesUseCase: GetArticlesUseCase
) : ViewModel() {
    
    private val _uiState = MutableStateFlow(HomeUiState())
    val uiState: StateFlow<HomeUiState> = _uiState.asStateFlow()
    
    init {
        loadData()
    }
    
    fun handleAction(action: HomeUiAction) {
        when (action) {
            is HomeUiAction.Refresh -> refreshData()
            is HomeUiAction.LoadMore -> loadMoreArticles()
        }
    }
    
    private fun loadData() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }
            
            try {
                combine(
                    getUserUseCase(currentUserId),
                    getArticlesUseCase()
                ) { userResult, articlesResult ->
                    _uiState.update {
                        it.copy(
                            user = userResult.getOrNull(),
                            articles = articlesResult.getOrElse { emptyList() },
                            isLoading = false,
                            error = null
                        )
                    }
                }.collect()
            } catch (e: Exception) {
                _uiState.update {
                    it.copy(
                        isLoading = false,
                        error = e.message
                    )
                }
            }
        }
    }
}

// feature/home/src/main/java/com/company/mycomposeapp/feature/home/HomeScreen.kt
@Composable
fun HomeScreen(
    onNavigateToProfile: (String) -> Unit,
    onNavigateToArticle: (String) -> Unit,
    viewModel: HomeViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    
    HomeContent(
        uiState = uiState,
        onAction = viewModel::handleAction,
        onNavigateToProfile = onNavigateToProfile,
        onNavigateToArticle = onNavigateToArticle
    )
}

@Composable
private fun HomeContent(
    uiState: HomeUiState,
    onAction: (HomeUiAction) -> Unit,
    onNavigateToProfile: (String) -> Unit,
    onNavigateToArticle: (String) -> Unit
) {
    Column(modifier = Modifier.fillMaxSize()) {
        // User header
        uiState.user?.let { user ->
            UserHeader(
                user = user,
                onProfileClick = { onNavigateToProfile(user.id) }
            )
        }
        
        // Articles list
        LazyColumn(
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            items(
                items = uiState.articles,
                key = { it.id }
            ) { article ->
                ArticleCard(
                    article = article,
                    onClick = { onNavigateToArticle(article.id) },
                    modifier = Modifier.animateItemPlacement()
                )
            }
        }
        
        // Loading state
        if (uiState.isLoading) {
            Box(
                modifier = Modifier.fillMaxWidth(),
                contentAlignment = Alignment.Center
            ) {
                CircularProgressIndicator()
            }
        }
    }
}
```

---

## 🧪 Testing Setup

### 1. **Core Testing Module**

#### **core/testing/build.gradle.kts**
```kotlin
plugins {
    alias(libs.plugins.android.library)
    alias(libs.plugins.kotlin.android)
}

android {
    namespace = "com.company.mycomposeapp.core.testing"
    compileSdk = 34
    
    defaultConfig {
        minSdk = 24
    }
}

dependencies {
    api(libs.junit)
    api(libs.mockk)
    api(libs.kotlinx.coroutines.test)
    api(libs.turbine)
    api(libs.androidx.test.ext.junit)
    api(libs.compose.ui.test.junit4)
    api(libs.hilt.android.testing)
    
    implementation(project(":core:common"))
    implementation(project(":core:model"))
}
```

#### **Test Utilities**
```kotlin
// core/testing/src/main/java/com/company/mycomposeapp/core/testing/TestData.kt
object TestData {
    val mockUser = User(
        id = "1",
        name = "John Doe",
        email = "john@example.com",
        avatarUrl = "https://example.com/avatar.jpg",
        createdAt = "2023-01-01T00:00:00Z"
    )
    
    val mockArticle = Article(
        id = "1",
        title = "Test Article",
        content = "This is a test article content.",
        summary = "Test summary",
        publishedAt = "2023-01-01T00:00:00Z",
        imageUrl = "https://example.com/image.jpg",
        author = mockUser
    )
}

// core/testing/src/main/java/com/company/mycomposeapp/core/testing/HiltTestRunner.kt
class HiltTestRunner : AndroidJUnitRunner() {
    override fun newApplication(
        cl: ClassLoader?,
        className: String?,
        context: Context?
    ): Application {
        return super.newApplication(cl, HiltTestApplication::class.java.name, context)
    }
}

@HiltAndroidApp
class HiltTestApplication : Application()
```

### 2. **Writing Tests**

#### **ViewModel Tests**
```kotlin
// feature/home/src/test/java/com/company/mycomposeapp/feature/home/HomeViewModelTest.kt
@ExperimentalCoroutinesTest
class HomeViewModelTest {
    
    @get:Rule
    val mainDispatcherRule = MainDispatcherRule()
    
    @MockK
    private lateinit var getUserUseCase: GetUserUseCase
    
    @MockK
    private lateinit var getArticlesUseCase: GetArticlesUseCase
    
    private lateinit var viewModel: HomeViewModel
    
    @Before
    fun setup() {
        MockKAnnotations.init(this)
        
        every { getUserUseCase(any()) } returns flowOf(Result.Success(TestData.mockUser))
        every { getArticlesUseCase() } returns flowOf(Result.Success(listOf(TestData.mockArticle)))
        
        viewModel = HomeViewModel(getUserUseCase, getArticlesUseCase)
    }
    
    @Test
    fun `when initialized, should load user and articles`() = runTest {
        // When
        val uiStates = mutableListOf<HomeUiState>()
        val job = launch(UnconfinedTestDispatcher()) {
            viewModel.uiState.toList(uiStates)
        }
        
        // Then
        assertThat(uiStates.last().user).isEqualTo(TestData.mockUser)
        assertThat(uiStates.last().articles).containsExactly(TestData.mockArticle)
        assertThat(uiStates.last().isLoading).isFalse()
        
        job.cancel()
    }
}
```

---

## 🚀 App Integration

### 1. **Main Application**

#### **Application Class**
```kotlin
// app/src/main/java/com/company/mycomposeapp/MyApplication.kt
@HiltAndroidApp
class MyApplication : Application(), ImageLoaderFactory {
    
    override fun newImageLoader(): ImageLoader {
        return ImageLoader.Builder(this)
            .memoryCache {
                MemoryCache.Builder(this)
                    .maxSizePercent(0.25)
                    .build()
            }
            .diskCache {
                DiskCache.Builder()
                    .directory(cacheDir.resolve("image_cache"))
                    .maxSizeBytes(100 * 1024 * 1024) // 100MB
                    .build()
            }
            .respectCacheHeaders(false)
            .build()
    }
}
```

#### **MainActivity**
```kotlin
// app/src/main/java/com/company/mycomposeapp/MainActivity.kt
@AndroidEntryPoint
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        enableEdgeToEdge()
        
        setContent {
            MyAppTheme {
                MyApp()
            }
        }
    }
}

@Composable
fun MyApp() {
    val navController = rememberNavController()
    
    NavHost(
        navController = navController,
        startDestination = "home"
    ) {
        composable("home") {
            HomeScreen(
                onNavigateToProfile = { userId ->
                    navController.navigate("profile/$userId")
                },
                onNavigateToArticle = { articleId ->
                    navController.navigate("article/$articleId")
                }
            )
        }
        
        composable(
            "profile/{userId}",
            arguments = listOf(navArgument("userId") { type = NavType.StringType })
        ) { backStackEntry ->
            val userId = backStackEntry.arguments?.getString("userId") ?: ""
            ProfileScreen(
                userId = userId,
                onNavigateBack = { navController.popBackStack() }
            )
        }
    }
}
```

---

## 🎯 Final Steps & Verification

### 1. **Build & Test**
```bash
# Clean and build project
./gradlew clean build

# Run unit tests
./gradlew testDebugUnitTest

# Run instrumented tests
./gradlew connectedDebugAndroidTest

# Run lint checks
./gradlew lintDebug

# Generate test coverage report
./gradlew jacocoTestReport
```

### 2. **Performance Verification**
```bash
# Build with optimizations
./gradlew assembleRelease

# Check APK size
./gradlew analyzeReleaseBundle

# Generate baseline profile
./gradlew generateBaselineProfile
```

### 3. **Documentation & CI/CD**
- Set up GitHub Actions or GitLab CI
- Configure automated testing
- Add dependency updates with Renovate
- Set up code quality checks with SonarQube

## 🏁 Success Checklist

- ✅ Project structure with proper modularization
- ✅ Gradle configuration optimized for build performance
- ✅ Core modules (network, database, UI) implemented
- ✅ Feature modules with MVVM pattern
- ✅ Dependency injection with Hilt
- ✅ Testing infrastructure set up
- ✅ Design system and theming implemented
- ✅ Navigation and state management configured
- ✅ Build optimizations and ProGuard rules
- ✅ CI/CD pipeline ready for deployment

---

### 📄 Navigation

**Previous:** [Best Practices](./best-practices.md) | **Next:** [Performance Optimization](./performance-optimization.md)

**Related:** [Build Optimization](./build-optimization.md) | [Testing Strategies](./testing-strategies.md)