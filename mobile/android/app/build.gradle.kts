import java.util.Properties
import org.gradle.api.GradleException

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

val signingPropertiesFile = rootProject.file("key.properties")
val signingProperties = Properties()
if (signingPropertiesFile.exists()) {
    signingPropertiesFile.inputStream().use(signingProperties::load)
}
val requestedReleaseBuild = gradle.startParameter.taskNames.any { it.contains("release", ignoreCase = true) }
val configuredKeystoreName = signingProperties.getProperty("storeFile")
val configuredKeystore = configuredKeystoreName?.let(rootProject::file)
if (requestedReleaseBuild && (!signingPropertiesFile.exists() || configuredKeystore == null || !configuredKeystore.exists())) {
    throw GradleException(
        "A release AAB must be signed with the operator-owned upload key. " +
            "Create android/key.properties from key.properties.example and place its ignored keystore at the configured path."
    )
}

android {
    namespace = "org.schememitra.app"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    defaultConfig {
        applicationId = "org.schememitra.app"
        minSdk = 23
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    signingConfigs {
        create("release") {
            if (configuredKeystore != null) {
                storeFile = configuredKeystore
                storePassword = signingProperties.getProperty("storePassword")
                keyAlias = signingProperties.getProperty("keyAlias")
                keyPassword = signingProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
            isDebuggable = false
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

flutter {
    source = "../.."
}
