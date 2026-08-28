import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing material comes from android/key.properties locally, or from the
// CM_* environment variables Codemagic injects for the uploaded keystore.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

fun signingValue(key: String, env: String): String? =
    keystoreProperties.getProperty(key) ?: System.getenv(env)

val releaseStoreFile = signingValue("storeFile", "CM_KEYSTORE_PATH")
val hasReleaseSigning = releaseStoreFile != null && file(releaseStoreFile).exists()

android {
    namespace = "com.vipgo.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                keyAlias = signingValue("keyAlias", "CM_KEY_ALIAS")
                keyPassword = signingValue("keyPassword", "CM_KEY_PASSWORD")
                storeFile = file(releaseStoreFile!!)
                storePassword = signingValue("storePassword", "CM_KEYSTORE_PASSWORD")
            }
        }
    }

    defaultConfig {
        applicationId = "com.vipgo.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Native multidex support. Harmless on minSdk >= 21 (ART splits dex natively),
        // required once the app + Firebase/ML Kit exceed the 64K method limit.
        multiDexEnabled = true
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                // Lets `flutter build apk --release` work on a machine without the
                // keystore. Such a build is NOT uploadable to Play.
                logger.warn("WARNING: no release keystore found - signing release with the debug key.")
                signingConfigs.getByName("debug")
            }

            // Shrink, obfuscate and strip unused resources with R8.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )

            // Upload native debug symbols so Play Console can symbolicate NDK crashes.
            ndk {
                debugSymbolLevel = "SYMBOL_TABLE"
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // Material Components - required by the MaterialComponents launch/normal themes.
    implementation("com.google.android.material:material:1.12.0")
    implementation("androidx.multidex:multidex:2.0.1")
}
