plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "vn.thanhtaxixanh.car98g00107"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "vn.thanhtaxixanh.car98g00107"
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

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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
    constraints {
        implementation("com.google.guava:guava:33.7.2-android") {
            because("Patch temporary-file disclosures and unsafe collection deserialization advisories")
        }
    }
    implementation("androidx.car.app:app:1.7.0")
    implementation("org.maplibre.gl:android-sdk-opengl:13.5.0")
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.robolectric:robolectric:4.16.1")
    testImplementation("com.google.zxing:core:3.5.3")
}
android.testOptions.unitTests.isIncludeAndroidResources = true

// AGP 9 packages host tests from merged assets. Flutter augments that directory
// after merge, so host-test packaging must also wait for Flutter's copy task.
tasks.configureEach {
    if (name.startsWith("package") && name.endsWith("UnitTestForUnitTest")) {
        val variant = name.removePrefix("package").removeSuffix("UnitTestForUnitTest")
        dependsOn("copyFlutterAssets$variant")
    }
}
