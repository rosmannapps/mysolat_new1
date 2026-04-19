pluginManagement {
    val props = java.util.Properties()
    val propsFile = file("local.properties")
    if (propsFile.exists()) {
        java.io.FileInputStream(propsFile).use { fis -> props.load(fis) }
    }

    val flutterSdkPath = props.getProperty("flutter.sdk")
        ?: error("flutter.sdk not set in android/local.properties")

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

// IMPORTANT: do NOT force PREFER_SETTINGS here (it triggers repo conflict with Flutter plugin loader)

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
}

include(":app")
