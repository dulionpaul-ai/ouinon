import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Clé de signature (même principe que Trousse à Pharma) : android/key.properties
// est écrit par Codemagic à partir du trousseau rangé dans ses réglages, jamais
// commité (clé d'envoi Play Store, à créer plus tard). Sans ce fichier,
// l'appli est signée avec la clé de test du dépôt (app/cle-test.jks) :
// toujours la même, pour que chaque nouvel APK de test s'installe
// par-dessus le précédent sans effacer les réponses. Cette clé n'est pas un
// secret et ne sert jamais pour les stores.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasKeystoreProperties = keystorePropertiesFile.exists()
if (hasKeystoreProperties) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}

android {
    namespace = "fr.ouinon.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Exigé par flutter_local_notifications (notifications programmées).
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "fr.ouinon.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("test") {
            storeFile = file("cle-test.jks")
            storePassword = "ouinon-test"
            keyAlias = "test"
            keyPassword = "ouinon-test"
        }
        if (hasKeystoreProperties) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    // Bibliothèques natives compressées dans l'APK : plus léger à
    // télécharger (l'appli les décompresse à l'installation).
    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasKeystoreProperties) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("test")
            }
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
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
