pluginManagement {
    // ✅ Flutter toolchain (ทำให้เจอ dev.flutter.flutter-gradle-plugin)
    val flutterSdkPath = run {
        val props = java.util.Properties()
        file("local.properties").inputStream().use { props.load(it) }
        val path = props.getProperty("flutter.sdk")
        require(!path.isNullOrBlank()) {
            "flutter.sdk not set in local.properties"
        }
        path
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    // ✅ ต้องมี loader ตัวนี้
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"

    // ✅ AGP / Kotlin versions
    id("com.android.application") version "8.9.1" apply false
    id("com.android.library") version "8.9.1" apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
}

include(":app")
