plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.vectevo.deep_sky"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.vectevo.deep_sky"
        // Minimum Android 8.0 Oreo (API 26) per ADR-0003.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Pass -Punsigned=true in CI release workflows (CI-02, PD-10) to emit an unsigned APK
            // for offline promoter signing via scripts/sign-release.*.
            if (!project.hasProperty("unsigned")) {
                signingConfig = signingConfigs.getByName("debug")
            }
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
    // Runtime-configured FCM without build-time google-services.json (SP-01, TC-04).
    implementation("com.google.firebase:firebase-messaging:24.1.0")
    implementation("androidx.core:core-ktx:1.15.0")
}
