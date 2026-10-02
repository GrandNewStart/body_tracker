import java.io.File
import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties").takeIf { it.exists() }
    ?: rootProject.file("keys.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

val pubspecFile = rootProject.projectDir.parentFile.resolve("pubspec.yaml")
var parsedVersionCode = flutter.versionCode
var parsedVersionName = flutter.versionName

if (pubspecFile.exists()) {
    val versionLine = pubspecFile.readLines().firstOrNull { it.trim().startsWith("version:") }
    if (versionLine != null) {
        val versionStr = versionLine.substringAfter("version:").trim()
        val parts = versionStr.split("+")
        if (parts.isNotEmpty()) {
            parsedVersionName = parts[0]
        }
        if (parts.size > 1) {
            parts[1].toIntOrNull()?.let { parsedVersionCode = it }
        }
    }
}

android {
    namespace = "dev.bluelemonade.bodytracker"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "dev.bluelemonade.bodytracker"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = parsedVersionCode ?: 2
        versionName = parsedVersionName ?: "1.0.0"

        val admobAppId = (project.findProperty("ADMOB_ANDROID_APP_ID") as? String)?.takeIf { it.isNotBlank() }
            ?: System.getenv("ADMOB_ANDROID_APP_ID")?.takeIf { it.isNotBlank() }
            ?: "ca-app-pub-3940256099942544~3347511713"
        manifestPlaceholders["admobAppId"] = admobAppId
    }

    signingConfigs {
        create("release") {
            val keyPath = keystoreProperties["storeFile"] as? String
            if (keyPath != null) {
                val rawFile = File(keyPath)
                storeFile = when {
                    rawFile.isAbsolute && rawFile.exists() -> rawFile
                    keystorePropertiesFile.parentFile.resolve(keyPath).normalize().exists() -> keystorePropertiesFile.parentFile.resolve(keyPath).normalize()
                    rootProject.file(keyPath).exists() -> rootProject.file(keyPath)
                    rootProject.projectDir.parentFile.resolve(keyPath).normalize().exists() -> rootProject.projectDir.parentFile.resolve(keyPath).normalize()
                    file(keyPath).exists() -> file(keyPath)
                    else -> rawFile
                }
            }
            storePassword = keystoreProperties["storePassword"] as? String
            keyAlias = keystoreProperties["keyAlias"] as? String
            keyPassword = keystoreProperties["keyPassword"] as? String
        }
    }

    buildTypes {
        release {
            val releaseSigning = signingConfigs.findByName("release")
            signingConfig = if (releaseSigning?.storeFile?.exists() == true) {
                releaseSigning
            } else {
                signingConfigs.getByName("debug")
            }
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
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
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
