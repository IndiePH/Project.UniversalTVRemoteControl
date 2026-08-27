import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    // The Flutter Gradle Plugin must be applied after the Android Gradle plugin.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.vorithstudio.smarttvremote"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.vorithstudio.smarttvremote"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = rootProject.file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    // Product flavors (e.g. dev/staging/prod) are intentionally not defined yet.
    // App configuration uses Flutter build modes + --dart-define; see README and
    // lib/app/configurations/app_build_config.dart (TVREMOTE-31).
    buildTypes {
        release {
            if (!keystorePropertiesFile.exists()) {
                throw GradleException(
                    "Missing key.properties. Refusing to build a release APK/AAB signed with the debug keystore."
                )
            }
            signingConfig = signingConfigs.getByName("release")
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Play Console edge-to-edge: enableEdgeToEdge() on FlutterFragmentActivity.
    implementation("androidx.activity:activity-ktx:1.10.1")
    // Android 12+ SplashScreen API (Theme.SplashScreen + installSplashScreen()).
    implementation("androidx.core:core-splashscreen:1.2.0")
    // Required by Unity LevelPlay (unity_levelplay_mediation).
    implementation("com.google.android.gms:play-services-appset:16.0.2")
    implementation("com.google.android.gms:play-services-ads-identifier:18.0.1")
    implementation("com.google.android.gms:play-services-basement:18.3.0")
    // Override transitive play-services-auth@@20.7.0 (from firebase-auth /
    // androidx.credentials). 20.7.0 NPEs in SignInHubActivity.onCreate when
    // the OS recreates the activity with a null sign-in extra. Fixed in 21.0.0+.
    implementation("com.google.android.gms:play-services-auth:21.6.0")
}
