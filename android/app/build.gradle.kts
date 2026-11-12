import java.util.Base64
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val entriesDartDefines = providers.gradleProperty("dart-defines").orNull.orEmpty()
    .split(",")
    .filter { it.isNotEmpty() }
    .map { String(Base64.getDecoder().decode(it), Charsets.UTF_8) }
    .associate { it.substringBefore("=") to it.substringAfter("=", "") }

val releaseProperties = Properties()
val releasePropertiesFile = rootProject.file(
    providers.gradleProperty("entriesSigningProperties").orElse("key.properties").get()
)
if (releasePropertiesFile.isFile) {
    releasePropertiesFile.inputStream().use { releaseProperties.load(it) }
}
val releaseKeyFile = releaseProperties.getProperty("storeFile")
    ?.takeIf { it.isNotBlank() }
    ?.let { rootProject.file(it) }
val releaseSigningConfigured = releaseKeyFile?.isFile == true &&
    listOf("storePassword", "keyAlias", "keyPassword").all {
        !releaseProperties.getProperty(it).isNullOrBlank()
    }

android {
    namespace = "com.example.flutter_application_1"
    compileSdk = flutter.compileSdkVersion
   // ndkVersion = flutter.ndkVersion 

    compileOptions {
        isCoreLibraryDesugaringEnabled = true

        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        manifestPlaceholders["entriesAdMobAppId"] =
            entriesDartDefines["ENTRIES_ADMOB_ANDROID_APP_ID"]
                ?.takeIf { Regex("ca-app-pub-[0-9]+~[0-9]+").matches(it) }
                ?: "ca-app-pub-3940256099942544~3347511713"
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.flutter_application_1"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (releaseSigningConfigured) {
            create("release") {
                storeFile = releaseKeyFile
                storePassword = releaseProperties.getProperty("storePassword")
                keyAlias = releaseProperties.getProperty("keyAlias")
                keyPassword = releaseProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release")
        }
    }
}

tasks.matching { it.name == "preReleaseBuild" }.configureEach {
    doFirst {
        check(releaseSigningConfigured) {
            "Set up android/key.properties and a valid upload keystore before building a release."
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
    implementation("androidx.biometric:biometric:1.1.0")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
