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

android {
    namespace = "ir.example.pashmak_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true // required by flutter_local_notifications
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = brandId
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["appScheme"] = brandScheme
        resValue("string", "app_name", brandName)
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

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            // TODO(release): replace with the real upload keystore (docs/80 §7).
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
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
