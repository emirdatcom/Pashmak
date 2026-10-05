import java.util.Properties

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

// Single source of truth for the app identity (docs/40 §9): android/brand.properties.
val brand = Properties().apply { file("../brand.properties").inputStream().use { load(it) } }
val brandId: String = brand.getProperty("applicationId")
val brandName: String = brand.getProperty("appName")
val brandScheme: String = brand.getProperty("appScheme")

// Release signing comes from CI secrets (env) or an untracked android/key.properties; never from the repo.
val keyProps = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
fun signingValue(env: String, prop: String): String? = System.getenv(env) ?: keyProps.getProperty(prop)
val releaseStore: String? = signingValue("RELEASE_KEYSTORE_PATH", "storeFile")

android {
    namespace = "ir.example.pashmak_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true // required by flutter_local_notifications
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildFeatures {
        resValues = true // AGP 9 disables generated resValue() by default
    }

    defaultConfig {
        applicationId = brandId
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["appScheme"] = brandScheme
        resValue("string", "app_name", brandName)
        resValue("string", "widget_scheme", brandScheme)
    }

    flavorDimensions += "market"
    productFlavors {
        create("bazaar") {
            dimension = "market"
            resValue("string", "market_name", "bazaar")
        }
        create("myket") {
            dimension = "market"
            resValue("string", "market_name", "myket")
        }
    }

    signingConfigs {
        if (releaseStore != null) {
            create("release") {
                storeFile = file(releaseStore)
                storePassword = signingValue("RELEASE_KEYSTORE_PASSWORD", "storePassword")
                keyAlias = signingValue("RELEASE_KEY_ALIAS", "keyAlias")
                keyPassword = signingValue("RELEASE_KEY_PASSWORD", "keyPassword")
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            // Without a keystore the release build is signed with the debug key: fine for CI/smoke builds,
            // NOT publishable. The release workflow supplies the real keystore (docs/80 §7).
            signingConfig = if (releaseStore != null) signingConfigs.getByName("release") else signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    // Each market flavor links only its own billing SDK.
    "bazaarImplementation"("com.github.cafebazaar.Poolakey:poolakey:2.2.0")
    "myketImplementation"("com.github.myketstore:myket-billing-client:1.19")
    "myketImplementation"("com.google.code.gson:gson:2.10.1")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
