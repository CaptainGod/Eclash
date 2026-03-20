import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// 从 android/key.properties 读取签名配置（本地开发 & CI 都走同一套逻辑）
val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties().apply {
    if (keyPropertiesFile.exists()) load(FileInputStream(keyPropertiesFile))
}

android {
    namespace = "com.captaingod.eclash"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.captaingod.eclash"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            storeFile = keyProperties["storeFile"]?.let { file(it) }
            storePassword = keyProperties["storePassword"] as? String
            keyAlias = keyProperties["keyAlias"] as? String
            keyPassword = keyProperties["keyPassword"] as? String
        }
    }

    buildTypes {
        release {
            // key.properties 存在则用正式签名，否则 fallback 到 debug 签名（本地快速运行用）
            signingConfig = if (keyPropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
