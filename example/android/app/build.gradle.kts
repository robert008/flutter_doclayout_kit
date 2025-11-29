plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val assetsDir = file("../../assets")
val releaseVersion = "v1.0.0"
val modelBaseUrl = "https://github.com/robert008/flutter_doclayout_kit/releases/download/$releaseVersion"

tasks.register("downloadAiModels") {
    doLast {
        assetsDir.mkdirs()

        val models = listOf("pp_doclayout_m.onnx", "pp_doclayout_l.onnx")

        models.forEach { modelName ->
            val modelFile = file("${assetsDir}/${modelName}")
            if (modelFile.exists()) {
                println("[$modelName] Already exists, skipping...")
            } else {
                println("[$modelName] Downloading...")
                val downloadUrl = "$modelBaseUrl/$modelName"
                ant.withGroovyBuilder {
                    "get"("src" to downloadUrl, "dest" to modelFile, "skipexisting" to "false")
                }
                println("[$modelName] Downloaded successfully")
            }
        }
    }
}

tasks.named("preBuild") {
    dependsOn("downloadAiModels")
}

android {
    namespace = "com.robert008.flutter_doclayout_kit_example"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "25.1.8937393"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.robert008.flutter_doclayout_kit_example"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
