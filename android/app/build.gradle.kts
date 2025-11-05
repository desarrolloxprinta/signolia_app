// build.gradle.kts (Kotlin DSL)
import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        load(FileInputStream(keystorePropertiesFile))
    }
}

android {
    namespace = "com.signolia.signolia_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }
    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.signolia.app"
        minSdk = flutter.minSdkVersion
        targetSdk = 35
        versionCode = 6
        versionName = "1.0"
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // 🔄 Sustituimos librerías incompatibles con Android 14:
    implementation("com.google.android.play:core-common:2.0.4")
    implementation("com.google.android.play:asset-delivery:2.2.2")
    implementation("com.google.android.play:app-update:2.1.0")
    implementation("com.google.android.play:app-update-ktx:2.1.0")

    // Desugaring para Java 17
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}

// 🔧 Forzamos resolución para evitar conflictos con plugins Flutter antiguos
configurations.all {
    resolutionStrategy {
        force("com.google.android.play:core-common:2.0.4")
        force("com.google.android.play:asset-delivery:2.2.2")
        force("com.google.android.play:app-update:2.1.0")
        force("com.google.android.play:app-update-ktx:2.1.0")
    }
}
