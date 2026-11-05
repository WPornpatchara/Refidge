plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.re"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8

        // ✅ FIX: required by flutter_local_notifications (desugaring)
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    defaultConfig {
        applicationId = "com.example.re"
        minSdk = flutter.minSdkVersion // ✅ FIX: ML Kit and other plugins require at least API 21
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    // ✅ FIX: desugaring library
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")

    // ✅ FIX: เพิ่ม Dependencies สำหรับ ML Kit Text Recognition (Latin & Thai)
    // This ensures the models are available for download on the device.
    implementation("com.google.android.gms:play-services-mlkit-text-recognition:19.0.0")
}

flutter {
    source = "../.."
}
