# Implementation Guide: Getting Started with Jetpack Compose

## 🚀 Quick Start Setup

This guide provides step-by-step instructions for setting up a production-ready Jetpack Compose project based on patterns from successful open source applications.

## 📋 Prerequisites

### Development Environment
- **Android Studio**: Hedgehog (2023.1.1) or later
- **JDK**: 17 or later
- **Kotlin**: 1.9.22 or later
- **Gradle**: 8.4 or later
- **Minimum SDK**: 24 (Android 7.0)
- **Target SDK**: 34 (Android 14)

### Recommended System Specs
- **RAM**: 16GB minimum, 32GB recommended
- **Storage**: 50GB free space for Android SDK and emulators
- **CPU**: Multi-core processor for faster builds

## 🏗️ Project Setup

### 1. Create New Project

```bash
# Option 1: Android Studio
# File → New → New Project → Empty Activity (Compose)

# Option 2: Command Line (if using gradle)
mkdir MyComposeApp
cd MyComposeApp
gradle init --type basic --dsl kotlin
```

### 2. Configure Build Scripts

#### Project-level `build.gradle.kts`:
```kotlin
// Top-level build file
plugins {
    id("com.android.application") version "8.2.2" apply false
    id("org.jetbrains.kotlin.android") version "1.9.22" apply false
    id("com.google.dagger.hilt.android") version "2.48" apply false
}
```

#### App-level `build.gradle.kts`:
```kotlin
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("kotlin-kapt")
    id("dagger.hilt.android.plugin")
    kotlin("plugin.serialization") version "1.9.22"
}

android {
    namespace = "com.yourcompany.yourapp"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.yourcompany.yourapp"
        minSdk = 24
        targetSdk = 34
        versionCode = 1
        versionName = "1.0"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        vectorDrawables {
            useSupportLibrary = true
        }
    }

    buildTypes {
        debug {
            isMinifyEnabled = false
            applicationIdSuffix = ".debug"
            isDebuggable = true
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
    }
    
    kotlinOptions {
        jvmTarget = "17"
    }
    
    buildFeatures {
        compose = true
        buildConfig = true
    }
    
    composeOptions {
        kotlinCompilerExtensionVersion = "1.5.8"
    }
    
    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }
}

dependencies {
    // Compose BOM for version alignment
    implementation(platform("androidx.compose:compose-bom:2024.02.00"))
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-graphics")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material3:material3-window-size-class")
    
    // Core Android
    implementation("androidx.core:core-ktx:1.12.0")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.7.0")
    implementation("androidx.activity:activity-compose:1.8.2")
    
    // Architecture Components
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.7.0")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.7.0")
    
    // Navigation
    implementation("androidx.navigation:navigation-compose:2.7.6")
    
    // Dependency Injection
    implementation("com.google.dagger:hilt-android:2.48")
    implementation("androidx.hilt:hilt-navigation-compose:1.1.0")
    kapt("com.google.dagger:hilt-compiler:2.48")
    
    // Networking
    implementation("com.squareup.retrofit2:retrofit:2.9.0")
    implementation("com.squareup.retrofit2:converter-gson:2.9.0")
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    implementation("com.squareup.okhttp3:logging-interceptor:4.12.0")
    
    // Database
    implementation("androidx.room:room-runtime:2.6.1")
    implementation("androidx.room:room-ktx:2.6.1")
    kapt("androidx.room:room-compiler:2.6.1")
    
    // Image Loading
    implementation("io.coil-kt:coil-compose:2.5.0")
    
    // Serialization
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.6.0")
    
    // Testing
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.7.3")
    androidTestImplementation("androidx.test.ext:junit:1.1.5")
    androidTestImplementation("androidx.test.espresso:espresso-core:3.5.1")
    androidTestImplementation(platform("androidx.compose:compose-bom:2024.02.00"))
    androidTestImplementation("androidx.compose.ui:ui-test-junit4")
    debugImplementation("androidx.compose.ui:ui-tooling")
    debugImplementation("androidx.compose.ui:ui-test-manifest")
}
```

### 3. Configure Version Catalog (Recommended)

Create `gradle/libs.versions.toml`:
```toml
[versions]
compileSdk = "34"
minSdk = "24"
targetSdk = "34"

kotlin = "1.9.22"
compose-bom = "2024.02.00"
compose-compiler = "1.5.8"
activity-compose = "1.8.2"
navigation-compose = "2.7.6"
hilt = "2.48"
hilt-navigation = "1.1.0"
retrofit = "2.9.0"
room = "2.6.1"
coil = "2.5.0"

[libraries]
# Compose
compose-bom = { group = "androidx.compose", name = "compose-bom", version.ref = "compose-bom" }
compose-ui = { group = "androidx.compose.ui", name = "ui" }
compose-ui-graphics = { group = "androidx.compose.ui", name = "ui-graphics" }
compose-ui-tooling = { group = "androidx.compose.ui", name = "ui-tooling" }
compose-ui-tooling-preview = { group = "androidx.compose.ui", name = "ui-tooling-preview" }
compose-material3 = { group = "androidx.compose.material3", name = "material3" }
compose-material3-window-size = { group = "androidx.compose.material3", name = "material3-window-size-class" }

# Core
core-ktx = { group = "androidx.core", name = "core-ktx", version = "1.12.0" }
lifecycle-runtime-ktx = { group = "androidx.lifecycle", name = "lifecycle-runtime-ktx", version = "2.7.0" }
activity-compose = { group = "androidx.activity", name = "activity-compose", version.ref = "activity-compose" }

# Architecture
lifecycle-viewmodel-compose = { group = "androidx.lifecycle", name = "lifecycle-viewmodel-compose", version = "2.7.0" }
lifecycle-runtime-compose = { group = "androidx.lifecycle", name = "lifecycle-runtime-compose", version = "2.7.0" }
navigation-compose = { group = "androidx.navigation", name = "navigation-compose", version.ref = "navigation-compose" }

# Dependency Injection
hilt-android = { group = "com.google.dagger", name = "hilt-android", version.ref = "hilt" }
hilt-compiler = { group = "com.google.dagger", name = "hilt-compiler", version.ref = "hilt" }
hilt-navigation-compose = { group = "androidx.hilt", name = "hilt-navigation-compose", version.ref = "hilt-navigation" }

[bundles]
compose = ["compose-ui", "compose-ui-graphics", "compose-ui-tooling-preview", "compose-material3"]
```

### 4. Application Class Setup

Create `Application.kt`:
```kotlin
package com.yourcompany.yourapp

import android.app.Application
import dagger.hilt.android.HiltAndroidApp

@HiltAndroidApp
class MyApplication : Application()
```

Update `AndroidManifest.xml`:
```xml
<application
    android:name=".MyApplication"
    android:allowBackup="true"
    android:dataExtractionRules="@xml/data_extraction_rules"
    android:fullBackupContent="@xml/backup_rules"
    android:icon="@mipmap/ic_launcher"
    android:label="@string/app_name"
    android:theme="@style/Theme.MyComposeApp">
    
    <activity
        android:name=".MainActivity"
        android:exported="true"
        android:theme="@style/Theme.MyComposeApp">
        <intent-filter>
            <action android:name="android.intent.action.MAIN" />
            <category android:name="android.intent.category.LAUNCHER" />
        </intent-filter>
    </activity>
</application>
```

## 🏛️ Project Structure Setup

### Recommended Directory Structure:
```
app/src/main/java/com/yourcompany/yourapp/
├── data/                   # Data layer
│   ├── local/              # Local data sources (Room, DataStore)
│   ├── remote/             # Remote data sources (API)
│   └── repository/         # Repository implementations
├── domain/                 # Domain layer (optional for small projects)
│   ├── model/              # Domain models
│   ├── repository/         # Repository interfaces
│   └── usecase/            # Use cases
├── presentation/           # Presentation layer
│   ├── ui/                 # Compose UI components
│   │   ├── components/     # Reusable components
│   │   ├── screens/        # Screen composables
│   │   └── theme/          # Material Design theme
│   ├── viewmodel/          # ViewModels
│   └── navigation/         # Navigation configuration
├── di/                     # Dependency injection modules
└── util/                   # Utility classes and extensions
```

## 🎨 Theme Setup

Create `ui/theme/Color.kt`:
```kotlin
package com.yourcompany.yourapp.presentation.ui.theme

import androidx.compose.ui.graphics.Color

val Purple80 = Color(0xFFD0BCFF)
val PurpleGrey80 = Color(0xFFCCC2DC)
val Pink80 = Color(0xFFEFB8C8)

val Purple40 = Color(0xFF6650a4)
val PurpleGrey40 = Color(0xFF625b71)
val Pink40 = Color(0xFF7D5260)
```

Create `ui/theme/Type.kt`:
```kotlin
package com.yourcompany.yourapp.presentation.ui.theme

import androidx.compose.material3.Typography
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp

val Typography = Typography(
    bodyLarge = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.Normal,
        fontSize = 16.sp,
        lineHeight = 24.sp,
        letterSpacing = 0.5.sp
    )
)
```

Create `ui/theme/Theme.kt`:
```kotlin
package com.yourcompany.yourapp.presentation.ui.theme

import android.app.Activity
import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.SideEffect
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.core.view.WindowCompat

private val DarkColorScheme = darkColorScheme(
    primary = Purple80,
    secondary = PurpleGrey80,
    tertiary = Pink80
)

private val LightColorScheme = lightColorScheme(
    primary = Purple40,
    secondary = PurpleGrey40,
    tertiary = Pink40
)

@Composable
fun MyComposeAppTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    dynamicColor: Boolean = true,
    content: @Composable () -> Unit
) {
    val colorScheme = when {
        dynamicColor && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
            val context = LocalContext.current
            if (darkTheme) dynamicDarkColorScheme(context) else dynamicLightColorScheme(context)
        }
        darkTheme -> DarkColorScheme
        else -> LightColorScheme
    }
    
    val view = LocalView.current
    if (!view.isInEditMode) {
        SideEffect {
            val window = (view.context as Activity).window
            window.statusBarColor = colorScheme.primary.toArgb()
            WindowCompat.getInsetsController(window, view).isAppearanceLightStatusBars = darkTheme
        }
    }

    MaterialTheme(
        colorScheme = colorScheme,
        typography = Typography,
        content = content
    )
}
```

## 🚀 Basic App Implementation

### 1. MainActivity Setup

```kotlin
package com.yourcompany.yourapp

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.ui.Modifier
import com.yourcompany.yourapp.presentation.navigation.AppNavigation
import com.yourcompany.yourapp.presentation.ui.theme.MyComposeAppTheme
import dagger.hilt.android.AndroidEntryPoint

@AndroidEntryPoint
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            MyComposeAppTheme {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colorScheme.background
                ) {
                    AppNavigation()
                }
            }
        }
    }
}
```

### 2. Navigation Setup

Create `presentation/navigation/AppNavigation.kt`:
```kotlin
package com.yourcompany.yourapp.presentation.navigation

import androidx.compose.runtime.Composable
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.yourcompany.yourapp.presentation.ui.screens.HomeScreen
import com.yourcompany.yourapp.presentation.ui.screens.ProfileScreen

@Composable
fun AppNavigation(
    navController: NavHostController = rememberNavController()
) {
    NavHost(
        navController = navController,
        startDestination = "home"
    ) {
        composable("home") {
            HomeScreen(
                onNavigateToProfile = {
                    navController.navigate("profile")
                }
            )
        }
        
        composable("profile") {
            ProfileScreen(
                onNavigateBack = {
                    navController.popBackStack()
                }
            )
        }
    }
}
```

### 3. Sample Screen Implementation

Create `presentation/ui/screens/HomeScreen.kt`:
```kotlin
package com.yourcompany.yourapp.presentation.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle

@Composable
fun HomeScreen(
    onNavigateToProfile: () -> Unit,
    viewModel: HomeViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    
    HomeContent(
        uiState = uiState,
        onNavigateToProfile = onNavigateToProfile,
        onRefresh = viewModel::refresh
    )
}

@Composable
private fun HomeContent(
    uiState: HomeUiState,
    onNavigateToProfile: () -> Unit,
    onRefresh: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text(
            text = "Welcome to Jetpack Compose!",
            style = MaterialTheme.typography.headlineMedium
        )
        
        Spacer(modifier = Modifier.height(16.dp))
        
        Button(onClick = onNavigateToProfile) {
            Text("Go to Profile")
        }
        
        Spacer(modifier = Modifier.height(16.dp))
        
        Button(onClick = onRefresh) {
            Text("Refresh")
        }
        
        if (uiState.isLoading) {
            Spacer(modifier = Modifier.height(16.dp))
            CircularProgressIndicator()
        }
    }
}
```

### 4. ViewModel Implementation

Create `presentation/viewmodel/HomeViewModel.kt`:
```kotlin
package com.yourcompany.yourapp.presentation.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

data class HomeUiState(
    val isLoading: Boolean = false,
    val message: String = "Hello, World!"
)

@HiltViewModel
class HomeViewModel @Inject constructor() : ViewModel() {
    
    private val _uiState = MutableStateFlow(HomeUiState())
    val uiState: StateFlow<HomeUiState> = _uiState.asStateFlow()
    
    fun refresh() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true)
            // Simulate API call
            delay(2000)
            _uiState.value = _uiState.value.copy(isLoading = false)
        }
    }
}
```

## 🔧 Build Optimization Setup

### 1. Gradle Properties

Create/update `gradle.properties`:
```properties
# Gradle optimization
org.gradle.jvmargs=-Xmx4g -XX:+UseParallelGC -XX:+HeapDumpOnOutOfMemoryError
org.gradle.caching=true
org.gradle.configuration-cache=true
org.gradle.parallel=true
org.gradle.daemon=true

# Android optimization
android.useAndroidX=true
android.enableJetifier=true
android.nonTransitiveRClass=true
android.nonFinalResIds=true

# Kotlin optimization
kotlin.code.style=official
```

### 2. ProGuard Rules

Create `proguard-rules.pro`:
```proguard
# Keep Compose runtime
-keep class androidx.compose.** { *; }
-dontwarn androidx.compose.**

# Keep Hilt components
-keep class dagger.hilt.** { *; }
-keep class javax.inject.** { *; }
-keep class * extends dagger.hilt.android.lifecycle.HiltViewModel { *; }

# Keep Retrofit interfaces
-keep interface * {
    @retrofit2.http.* <methods>;
}

# Remove debug logs in release
-assumenosideeffects class android.util.Log {
    public static boolean isLoggable(java.lang.String, int);
    public static int v(...);
    public static int d(...);
    public static int i(...);
    public static int w(...);
    public static int e(...);
}
```

## 🧪 Testing Setup

### 1. Unit Test Example

Create `test/java/.../HomeViewModelTest.kt`:
```kotlin
package com.yourcompany.yourapp.presentation.viewmodel

import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.runTest
import org.junit.Assert.*
import org.junit.Test

@ExperimentalCoroutinesApi
class HomeViewModelTest {
    
    @Test
    fun `refresh updates loading state correctly`() = runTest {
        // Given
        val viewModel = HomeViewModel()
        
        // When
        viewModel.refresh()
        
        // Then
        val uiState = viewModel.uiState.value
        assertFalse(uiState.isLoading) // Should be false after completion
    }
}
```

### 2. Compose UI Test Example

Create `androidTest/java/.../HomeScreenTest.kt`:
```kotlin
package com.yourcompany.yourapp.presentation.ui.screens

import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.yourcompany.yourapp.presentation.ui.theme.MyComposeAppTheme
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class HomeScreenTest {
    
    @get:Rule
    val composeTestRule = createComposeRule()
    
    @Test
    fun homeScreen_displaysWelcomeMessage() {
        composeTestRule.setContent {
            MyComposeAppTheme {
                HomeScreen(onNavigateToProfile = {})
            }
        }
        
        composeTestRule
            .onNodeWithText("Welcome to Jetpack Compose!")
            .assertIsDisplayed()
    }
}
```

## 🚀 Next Steps

After completing this setup, you should have a working Jetpack Compose application. Here are recommended next steps:

### 1. Add Core Features
- Implement data layer with Repository pattern
- Add networking with Retrofit
- Set up local database with Room
- Implement proper state management

### 2. Enhance UI/UX
- Add more screens and navigation
- Implement Material Design components
- Add animations and transitions
- Ensure accessibility compliance

### 3. Production Readiness
- Set up CI/CD pipeline
- Add comprehensive testing
- Implement error handling
- Add analytics and crash reporting

### 4. Performance Optimization
- Implement lazy loading
- Optimize Compose performance
- Add baseline profiles
- Monitor and improve build times

---

*Implementation guide based on best practices from successful open source Jetpack Compose projects as of January 2025.*