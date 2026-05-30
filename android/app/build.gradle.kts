import java.io.FileInputStream
import java.util.Properties

// AdMob app ID is build-time config. Test vs live ad units are toggled at runtime
// via Firebase Remote Config (`test_ads_enabled`) in Dart — see AdConfig.
val productionAdMobAppId = "ca-app-pub-4297882562709937~9516353394"

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
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

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.vorithstudio.smarttvremote"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["admobAppId"] = productionAdMobAppId
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

flutter {
    source = "../.."
}

dependencies {
    // Play Console edge-to-edge: enableEdgeToEdge() on FlutterFragmentActivity.
    implementation("androidx.activity:activity-ktx:1.10.1")
}
