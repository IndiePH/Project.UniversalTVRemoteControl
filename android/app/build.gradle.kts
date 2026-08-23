import java.io.FileInputStream
import java.util.Properties

// AdMob app ID is build-time config. Test vs live ad units are toggled at runtime
// via Firebase Remote Config (`test_ads_enabled`) in Dart — see AdConfig.
val productionAdMobAppId = "ca-app-pub-4297882562709937~9516353394"

// personal-build branch only — see references/guide-personal-build.md.
// Firebase Analytics/Crashlytics auto-init before Dart's main() runs, so the
// --dart-define=PERSONAL_BUILD flag (Dart-only, invisible to Gradle) can't stop
// their native pre-init collection window. This env var closes that gap at the
// manifest level. Defaults to false, so a plain `flutter build apk --release`
// (no env var) is byte-for-byte the same as `main` — must NEVER be merged there.
val personalBuild = (System.getenv("PERSONAL_BUILD") ?: "false").toBoolean()

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
        manifestPlaceholders["admobAppId"] = productionAdMobAppId
        manifestPlaceholders["analyticsCollectionDeactivated"] = personalBuild.toString()
        manifestPlaceholders["crashlyticsCollectionEnabled"] = (!personalBuild).toString()
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
}
