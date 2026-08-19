import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Load keystore properties
// key.properties and the keystore are generated in android/ by CI. Resolving
// both paths from the Android root also makes the same configuration work
// locally and prevents an accidental debug-signed release APK.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}
val releaseKeystoreFile = keystoreProperties.getProperty("storeFile")?.let {
    rootProject.file(it)
}

// Android décide si un APK peut remplacer une installation existante avec
// versionCode, et non avec versionName. Le suffixe après "+" seul était utilisé
// auparavant : 1.0.5+2 et 1.0.6+2 avaient donc tous les deux le code 2.
// Chaque partie est réservée sur deux chiffres, ce qui conserve un ordre
// strictement croissant quand une version sémantique progresse.
fun androidVersionCode(versionName: String, buildNumber: String): Int {
    val match = Regex("^(\\d+)\\.(\\d+)\\.(\\d+)$").matchEntire(versionName)
        ?: error("Version Android invalide : '$versionName'. Format attendu : X.Y.Z")
    val values = (match.groupValues.drop(1) + buildNumber).map {
        it.toIntOrNull() ?: error("Numéro de build Android invalide : '$it'.")
    }
    require(values.all { it in 0..99 }) {
        "Chaque composant de version Android doit être compris entre 0 et 99."
    }

    val (major, minor, patch, build) = values
    return major * 1_000_000 + minor * 10_000 + patch * 100 + build
}

val pubspecVersion = rootProject.file("../pubspec.yaml").readText()
val pubspecBuildNumber = Regex(
    "(?m)^version:\\s*\\d+\\.\\d+\\.\\d+\\+(\\d+)\\s*$",
).find(pubspecVersion)?.groupValues?.get(1)
    ?: error("Impossible de lire le numéro de build dans pubspec.yaml.")

android {
    namespace = "com.recettebox.recette_box"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.recettebox.recette_box"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // L'application cible Android 15 et les versions ultérieures.
        minSdk = 35
        targetSdk = flutter.targetSdkVersion
        versionCode = androidVersionCode(
            flutter.versionName,
            pubspecBuildNumber,
        )
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (releaseKeystoreFile?.exists() == true) {
                storeFile = releaseKeystoreFile
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Never publish a release APK signed with the debug certificate:
            // Android rejects it as an update of an existing installation.
            signingConfig = signingConfigs.getByName("release")
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
