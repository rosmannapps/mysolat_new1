pluginManagement {
    val props = java.util.Properties()
    val propsFile = file("local.properties")
    if (propsFile.exists()) {
        java.io.FileInputStream(propsFile).use { fis ->
            props.load(fis)
        }
    }

    val flutterSdkPath = props.getProperty("flutter.sdk")
        ?: error("flutter.sdk not set in android/local.properties")

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }

    // ✅ Stable versions
    plugins {
        id("com.android.application") version "8.3.2"
        id("com.android.library") version "8.3.2"
        id("org.jetbrains.kotlin.android") version "1.9.22"
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
}

dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
    }
}

include(":app")
