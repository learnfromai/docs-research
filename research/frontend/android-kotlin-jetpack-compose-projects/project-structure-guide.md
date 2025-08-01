# Project Structure Guide for Jetpack Compose Applications

## 🏗️ Recommended Project Architecture

Based on analysis of successful open source Jetpack Compose projects, here are proven project structure patterns.

## 📂 Single Module Structure (Small Projects)

For projects with less than 20 screens and simple requirements:

```
app/src/main/java/com/company/app/
├── data/                           # Data layer
│   ├── local/                      # Local data sources
│   │   ├── database/               # Room database
│   │   ├── datastore/              # DataStore preferences
│   │   └── cache/                  # In-memory cache
│   ├── remote/                     # Remote data sources
│   │   ├── api/                    # API interfaces
│   │   ├── dto/                    # Data transfer objects
│   │   └── interceptor/            # Network interceptors
│   └── repository/                 # Repository implementations
├── domain/                         # Domain layer (optional for simple apps)
│   ├── model/                      # Domain models
│   ├── repository/                 # Repository interfaces
│   └── usecase/                    # Business use cases
├── presentation/                   # Presentation layer
│   ├── ui/                         # Compose UI
│   │   ├── components/             # Reusable components
│   │   │   ├── common/             # Generic components (buttons, cards)
│   │   │   └── specific/           # Feature-specific components
│   │   ├── screens/                # Screen composables
│   │   │   ├── home/               # Home screen components
│   │   │   ├── profile/            # Profile screen components
│   │   │   └── settings/           # Settings screen components
│   │   └── theme/                  # Material Design theme
│   │       ├── Color.kt
│   │       ├── Theme.kt
│   │       ├── Type.kt
│   │       └── Dimension.kt
│   ├── viewmodel/                  # ViewModels
│   └── navigation/                 # Navigation setup
├── di/                             # Dependency injection
│   ├── NetworkModule.kt
│   ├── DatabaseModule.kt
│   └── RepositoryModule.kt
└── util/                           # Utilities and extensions
    ├── extension/                  # Kotlin extensions
    ├── constant/                   # App constants
    └── helper/                     # Helper classes
```

## 📦 Multi-Module Structure (Large Projects)

For projects with 20+ screens and complex requirements:

```
project/
├── app/                            # Main application module
│   ├── src/main/java/
│   │   ├── MainActivity.kt
│   │   ├── MyApplication.kt
│   │   └── di/                     # App-level DI
├── core/                           # Core shared modules
│   ├── common/                     # Common utilities
│   │   ├── src/main/java/
│   │   │   ├── util/
│   │   │   ├── extension/
│   │   │   └── constant/
│   ├── design-system/              # UI design system
│   │   ├── src/main/java/
│   │   │   ├── component/          # Reusable components
│   │   │   ├── theme/              # Theme configuration
│   │   │   └── icon/               # App icons
│   ├── data/                       # Shared data layer
│   │   ├── src/main/java/
│   │   │   ├── database/           # Room database
│   │   │   ├── network/            # Network setup
│   │   │   └── repository/         # Base repository
│   ├── domain/                     # Shared domain layer
│   │   ├── src/main/java/
│   │   │   ├── model/              # Domain models
│   │   │   └── repository/         # Repository interfaces
│   └── navigation/                 # Navigation utilities
│       ├── src/main/java/
│       │   ├── NavigationDestination.kt
│       │   └── NavigationComponent.kt
├── feature/                        # Feature modules
│   ├── authentication/             # Auth feature
│   │   ├── src/main/java/
│   │   │   ├── data/               # Auth-specific data
│   │   │   ├── domain/             # Auth business logic
│   │   │   ├── presentation/       # Auth UI
│   │   │   │   ├── ui/
│   │   │   │   │   ├── login/
│   │   │   │   │   └── register/
│   │   │   │   ├── viewmodel/
│   │   │   │   └── navigation/
│   │   │   └── di/                 # Auth DI module
│   ├── home/                       # Home feature
│   ├── profile/                    # Profile feature
│   └── settings/                   # Settings feature
└── shared/                         # Shared business modules
    ├── analytics/                  # Analytics module
    ├── testing/                    # Testing utilities
    └── benchmark/                  # Performance benchmarks
```

## 🎯 Module Dependencies

### Dependency Rules:
- **App module**: Can depend on all feature modules and core modules
- **Feature modules**: Can depend on core modules, NOT on other feature modules
- **Core modules**: Can depend on other core modules with careful consideration
- **Shared modules**: Can be depended on by any module

### Gradle Dependency Example:
```kotlin
// feature/home/build.gradle.kts
dependencies {
    implementation(project(":core:common"))
    implementation(project(":core:design-system"))
    implementation(project(":core:data"))
    implementation(project(":core:domain"))
    implementation(project(":shared:analytics"))
    
    // ❌ Don't do this - feature to feature dependency
    // implementation(project(":feature:profile"))
}
```

## 📱 Feature Module Structure

Each feature module follows consistent internal structure:

```
feature/home/
├── build.gradle.kts
├── src/
│   ├── main/
│   │   ├── java/com/app/feature/home/
│   │   │   ├── data/               # Feature-specific data
│   │   │   │   ├── repository/     # Repository implementation
│   │   │   │   ├── source/         # Data sources
│   │   │   │   └── mapper/         # Data mapping
│   │   │   ├── domain/             # Feature business logic
│   │   │   │   ├── model/          # Domain models
│   │   │   │   ├── usecase/        # Use cases
│   │   │   │   └── repository/     # Repository interface
│   │   │   ├── presentation/       # UI layer
│   │   │   │   ├── ui/             # Compose screens
│   │   │   │   │   ├── HomeScreen.kt
│   │   │   │   │   ├── components/ # Screen-specific components
│   │   │   │   │   └── model/      # UI state models
│   │   │   │   ├── viewmodel/      # ViewModels
│   │   │   │   └── navigation/     # Feature navigation
│   │   │   └── di/                 # Feature DI module
│   │   │       └── HomeModule.kt
│   │   └── res/                    # Feature resources
│   └── test/                       # Unit tests
│       └── androidTest/            # Instrumented tests
```

## 🎨 Design System Module Structure

Centralized design system for consistent UI:

```
core/design-system/
├── src/main/java/
│   ├── component/                  # Reusable components
│   │   ├── button/
│   │   │   ├── AppButton.kt
│   │   │   ├── AppIconButton.kt
│   │   │   └── AppTextButton.kt
│   │   ├── card/
│   │   │   ├── AppCard.kt
│   │   │   └── AppOutlinedCard.kt
│   │   ├── input/
│   │   │   ├── AppTextField.kt
│   │   │   └── AppSearchField.kt
│   │   ├── navigation/
│   │   │   ├── AppTopBar.kt
│   │   │   ├── AppBottomBar.kt
│   │   │   └── AppNavigationRail.kt
│   │   └── layout/
│   │       ├── AppScaffold.kt
│   │       └── AppColumn.kt
│   ├── theme/                      # Theme system
│   │   ├── AppTheme.kt
│   │   ├── Color.kt
│   │   ├── Typography.kt
│   │   ├── Spacing.kt
│   │   └── Shape.kt
│   ├── icon/                       # App icons
│   │   ├── AppIcons.kt
│   │   └── IconPack.kt
│   └── preview/                    # Preview utilities
│       ├── PreviewTheme.kt
│       └── PreviewData.kt
└── src/main/res/
    ├── values/
    │   ├── colors.xml
    │   ├── dimens.xml
    │   └── strings.xml
    └── drawable/                   # Vector drawables
```

## 💾 Data Layer Structure

Organized data access and management:

```
core/data/
├── src/main/java/
│   ├── database/                   # Room database
│   │   ├── AppDatabase.kt
│   │   ├── dao/                    # Data access objects
│   │   │   ├── UserDao.kt
│   │   │   └── PostDao.kt
│   │   ├── entity/                 # Database entities
│   │   │   ├── UserEntity.kt
│   │   │   └── PostEntity.kt
│   │   └── migration/              # Database migrations
│   │       └── DatabaseMigrations.kt
│   ├── network/                    # Network layer
│   │   ├── api/                    # API interfaces
│   │   │   ├── UserApi.kt
│   │   │   └── PostApi.kt
│   │   ├── dto/                    # Data transfer objects
│   │   │   ├── UserDto.kt
│   │   │   └── PostDto.kt
│   │   ├── interceptor/            # Network interceptors
│   │   │   ├── AuthInterceptor.kt
│   │   │   └── LoggingInterceptor.kt
│   │   └── NetworkClient.kt
│   ├── repository/                 # Repository base classes
│   │   ├── BaseRepository.kt
│   │   └── NetworkBoundResource.kt
│   ├── datastore/                  # DataStore preferences
│   │   ├── UserPreferences.kt
│   │   └── AppPreferences.kt
│   └── mapper/                     # Data mapping utilities
│       ├── EntityMapper.kt
│       └── DtoMapper.kt
```

## 🧪 Testing Structure

Organized testing across modules:

```
feature/home/
├── src/
│   ├── test/                       # Unit tests
│   │   ├── data/
│   │   │   └── repository/
│   │   │       └── HomeRepositoryTest.kt
│   │   ├── domain/
│   │   │   └── usecase/
│   │   │       └── GetHomeDataUseCaseTest.kt
│   │   └── presentation/
│   │       └── viewmodel/
│   │           └── HomeViewModelTest.kt
│   ├── androidTest/                # Instrumented tests
│   │   ├── ui/
│   │   │   └── HomeScreenTest.kt
│   │   └── integration/
│   │       └── HomeIntegrationTest.kt
│   └── sharedTest/                 # Shared test utilities
│       ├── factory/
│       │   └── TestDataFactory.kt
│       └── rule/
│           └── TestCoroutineRule.kt
```

## 🔧 Build Script Organization

Consistent build configuration:

```
project/
├── build.gradle.kts                # Root build script
├── gradle/
│   ├── libs.versions.toml          # Version catalog
│   └── wrapper/
├── buildSrc/                       # Build logic
│   ├── src/main/kotlin/
│   │   ├── AndroidLibraryConventionPlugin.kt
│   │   ├── AndroidFeatureConventionPlugin.kt
│   │   └── AndroidComposeConventionPlugin.kt
│   └── build.gradle.kts
└── gradle.properties               # Global properties
```

## 📊 Module Size Guidelines

### Recommended Module Sizes:
- **Core modules**: 100-500 source files
- **Feature modules**: 50-200 source files
- **Shared modules**: 20-100 source files

### When to Split Modules:
- Feature becomes too complex (200+ files)
- Clear domain boundaries exist
- Different teams work on different features
- Build performance improvement needed

## 🎯 Best Practices

### 1. Naming Conventions
```kotlin
// Modules
:app
:core:common
:core:design-system
:feature:authentication
:feature:home

// Packages
com.app.core.common
com.app.feature.home.presentation.ui
```

### 2. Resource Organization
```kotlin
// Strings
core_common_error_network = "Network error"
feature_home_title = "Home"
feature_profile_edit_button = "Edit Profile"

// Layouts
core_design_system_component_button
feature_home_screen_main
```

### 3. Dependency Injection
```kotlin
// Each module has its own DI module
@Module
@InstallIn(SingletonComponent::class)
object HomeModule {
    // Feature-specific dependencies
}
```

---

*Project structure guide based on analysis of scalable Jetpack Compose applications and Android development best practices as of January 2025.*