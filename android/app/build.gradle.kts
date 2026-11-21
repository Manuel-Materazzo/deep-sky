import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.isFile) {
        FileInputStream(keystorePropertiesFile).use { load(it) }
    }
}

fun releaseSigningProp(propName: String, envName: String): String? =
    keystoreProperties.getProperty(propName)?.trim()?.takeIf { it.isNotEmpty() }
        ?: System.getenv(envName)?.trim()?.takeIf { it.isNotEmpty() }

val releaseStoreFilePath = releaseSigningProp("storeFile", "DEEPSKY_KEYSTORE_PATH")
val releaseStorePassword = releaseSigningProp("storePassword", "DEEPSKY_KEYSTORE_PASSWORD")
val releaseKeyAlias = releaseSigningProp("keyAlias", "DEEPSKY_KEY_ALIAS")
val releaseKeyPassword = releaseSigningProp("keyPassword", "DEEPSKY_KEY_PASSWORD")
val hasReleaseSigningConfig = listOf(
    releaseStoreFilePath,
    releaseStorePassword,
    releaseKeyAlias,
    releaseKeyPassword,
).all { it != null }
val isUnsignedReleaseBuild = project.hasProperty("unsigned") &&
    project.property("unsigned").toString().equals("true", ignoreCase = true)

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

    signingConfigs {
        if (hasReleaseSigningConfig) {
            create("release") {
                storeFile = rootProject.file(releaseStoreFilePath!!)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            // AU-13: Never silently fall back to the debug signing key for release builds.
            // Pass -Punsigned=true in CI release workflows (CI-02, PD-10) to emit an unsigned APK
            // for offline promoter signing via scripts/sign-release.*, or configure release signing
            // via android/key.properties or DEEPSKY_KEYSTORE_* environment variables.
            if (!isUnsignedReleaseBuild && hasReleaseSigningConfig) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

gradle.taskGraph.whenReady {
    val wantsRelease = allTasks.any { task ->
        val name = task.name.lowercase()
        (name.contains("release") && (name.contains("assemble") || name.contains("bundle") || name.contains("package")))
    }
    if (wantsRelease && !isUnsignedReleaseBuild && !hasReleaseSigningConfig) {
        throw GradleException(
            "Release builds require either -Punsigned=true (for offline promoter signing) " +
                "or a release signing config via android/key.properties / DEEPSKY_KEYSTORE_* env vars (AU-13)."
        )
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
    implementation("androidx.activity:activity-ktx:1.10.1")
    // Open-source Apache-2.0 CameraX + ZXing QR scanning (`S1-D06`, `S1-D10`, SEC-02).
    implementation("androidx.camera:camera-core:1.4.2")
    implementation("androidx.camera:camera-camera2:1.4.2")
    implementation("androidx.camera:camera-lifecycle:1.4.2")
    implementation("androidx.camera:camera-view:1.4.2")
    implementation("com.google.zxing:core:3.5.3")
}
