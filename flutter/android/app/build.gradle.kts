import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "cl.baqueanonatales"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    buildFeatures {
        resValues = true
    }

    flavorDimensions += "app"

    productFlavors {
        create("clientDev") {
            dimension = "app"
            applicationId = "cl.baqueanonatales.dev"
            resValue("string", "app_name", "Baqueano DEV")
        }
        create("clientStaging") {
            dimension = "app"
            applicationId = "cl.baqueanonatales.staging"
            resValue("string", "app_name", "Baqueano Staging")
        }
        create("clientProd") {
            dimension = "app"
            applicationId = "cl.baqueanonatales"
            resValue("string", "app_name", "Baqueano Natales")
        }
        create("adminDev") {
            dimension = "app"
            applicationId = "cl.baqueanonatales.admin.dev"
            resValue("string", "app_name", "Baqueano Admin DEV")
        }
        create("adminStaging") {
            dimension = "app"
            applicationId = "cl.baqueanonatales.admin.staging"
            resValue("string", "app_name", "Baqueano Admin Staging")
        }
        create("adminProd") {
            dimension = "app"
            applicationId = "cl.baqueanonatales.admin"
            resValue("string", "app_name", "Baqueano Admin")
        }
    }

    defaultConfig {
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // Solo creamos la config si el keystore existe (evita NPE en build.yml sin keystore)
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Solo firmamos si hay keystore disponible
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            }
            // Desactivar ofuscacion para que MethodChannel funcione en release
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("androidx.credentials:credentials:1.3.0")
    implementation("androidx.credentials:credentials-play-services-auth:1.3.0")
    implementation("com.google.android.libraries.identity.googleid:googleid:1.1.1")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}