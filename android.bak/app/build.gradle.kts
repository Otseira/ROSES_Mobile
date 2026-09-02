android {
    namespace = "com.ropanasuri.sirom"
    compileSdk = 36  // ✅ Android 16 stable (tersedia & support plugin baru)
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    defaultConfig {
        applicationId = "com.ropanasuri.sirom"
        minSdk = 21              // ✅ Android 5.0+ → mencakup Android 9 karyawan
        targetSdk = 36           // ✅ Target Android 16 (HP Anda)
        versionCode = flutter.versionCode
        versionName = flutter.versionName
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
            isMinifyEnabled = false      // Sementara off (hindari error package.xml)
            isShrinkResources = false
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
        debug { isMinifyEnabled = false }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11)
    }
}

flutter { source = "../.." }

dependencies {
    implementation("androidx.multidex:multidex:2.0.1")
}