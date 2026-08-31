import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// ===== Signing release: baca dari android/key.properties =====
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.ropanasuri.sirom"
    compileSdk = 34  // ✅ DINAikkan dari flutter.compileSdkVersion → 34 (wajib untuk permission_handler)
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    defaultConfig {
        applicationId = "com.ropanasuri.sirom"
        minSdk = 21            // ✅ MINIMAL 21 (Android 5.0) — wajib untuk camera + permission_handler
        targetSdk = 34         // ✅ Target Android 14
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        // ✅ FIX: MultiDex untuk mencegah crash di Android 9 dengan banyak dependency
        multiDexEnabled = true
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            // Minify & shrink resource untuk ukuran APK lebih kecil
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
        
        debug {
            isMinifyEnabled = false
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11)
    }
}

flutter {
    source = "../.."
}

// ✅ Tambahan: Pastikan dependency MultiDex terpasang untuk Android 9
dependencies {
    implementation("androidx.multidex:multidex:2.0.1")
}