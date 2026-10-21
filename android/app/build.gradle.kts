import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Conditional on purpose. A committed placeholder google-services.json does
// not degrade -- it breaks the Gradle plugin with an error that reads like a
// build bug -- and a fake file that looks like a credential is the class of
// thing that once shipped a live ArcGIS token (see pubspec.yaml, config/).
// There is no Firebase project yet (docs/push-setup.md), so this file is
// absent on every machine and in CI today, and the build must still succeed.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

// ── Release signing (S1-2) ──────────────────────────────────────────────────
//
// `android/key.properties` holds the upload-key details. It is gitignored and
// MUST stay that way — losing control of it is the same as losing the keystore.
// Shape in `android/key.properties.example`.
//
// The file is optional at CONFIGURE time so that debug builds, `flutter test`
// and IDE syncs keep working on a machine that has never seen the keystore.
// It is mandatory at ASSEMBLE time for a release variant — see the task-graph
// check at the bottom of this file.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        keystorePropertiesFile.inputStream().use { load(it) }
    }
}
val hasReleaseKeystore = keystorePropertiesFile.exists()

android {
    // Reverse-DNS of minelink.org, the domain that owns the product (client
    // ruling, 2026-08-13). PERMANENT: Play keys a listing on this string, so it
    // can never change after first publish without shipping a second, separate
    // app that no existing install will ever update to.
    //
    // Unrelated to the Dart package name, which stays `flutter_application_1`
    // (CLAUDE.md §1) — the two namespaces do not interact.
    namespace = "org.minelink"
    // NOTE: `namespace` stays `org.minelink` deliberately — it is the Kotlin
    // package of MainActivity.kt and changing it would mean moving the source
    // file. Only `applicationId` below differs, and that is the value Android
    // actually uses to decide whether two installs are the same app.
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // M3 REDESIGN PROJECT — distinct from the shipping app's
        // `org.minelink` on purpose. Android treats applicationId as the
        // installed app's identity, so sharing it would make installing this
        // build *uninstall and replace* the real MineLink on the device.
        // The two must sit side by side for the redesign to be comparable.
        applicationId = "org.minelink.m3"

        // ── PINNED, not inherited (S10-3) ───────────────────────────────────
        //
        // These were `flutter.minSdkVersion` / `flutter.targetSdkVersion`,
        // whose values live in the Flutter SDK rather than in this repo. The
        // SDK's own comment on the latter reads *"targetSdkVersion should
        // always be the latest available stable version"* — so upgrading
        // Flutter silently moves the app's target, and Android keys real
        // runtime behaviour off it: permission prompts, background-location
        // rules and foreground-service requirements all change with the
        // target. That is a decision about how the app behaves on a driver's
        // phone, and it must not arrive as a side effect of a toolchain bump.
        //
        // The numbers are the values the SDK resolved to when they were pinned
        // (Flutter's FlutterExtension.kt, 2026-08-16), so behaviour is
        // unchanged by the pinning itself.
        minSdk = 24 // Android 7.0. ACCESS_BACKGROUND_LOCATION needs 29+ and is
        // requested at runtime; the app degrades on older devices rather than
        // excluding them.
        targetSdk = 36

        // From `version:` in pubspec.yaml (`1.0.0+1` → versionName 1.0.0,
        // versionCode 1). Kept on the Flutter values deliberately: pubspec is
        // the single place the release number is set, and hardcoding it here
        // would give the build two sources for one number.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (hasReleaseKeystore) {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storePassword = keystoreProperties.getProperty("storePassword")
                storeFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }
            }
        }
    }

    buildTypes {
        release {
            // Was `signingConfigs.getByName("debug")` — the stock
            // `flutter create` TODO, still in place. A release APK signed with
            // the debug key cannot be published (Play rejects it) and, if it
            // ever escaped, is signed with a key that is not secret and is
            // identical on every machine. The failure mode was silent: the
            // build succeeded and produced something that merely looked
            // shippable.
            //
            // With no keystore, `-PallowDebugSigning=true` must still SIGN —
            // with the debug key. Falling through to `null` produced an
            // unsigned APK that every Android installer rejects with a bare
            // "App not installed" (2026-10-19 build, found 2026-10-21).
            val allowDebugSigning =
                (project.findProperty("allowDebugSigning") as String?)?.toBoolean() ?: false
            signingConfig = when {
                hasReleaseKeystore -> signingConfigs.getByName("release")
                allowDebugSigning -> signingConfigs.getByName("debug")
                else -> null
            }
        }
    }
}

// Fail LOUDLY, and only when it matters.
//
// Checked on the task graph rather than at configure time so that debug builds,
// `flutter test` and IDE syncs are untouched on a machine with no keystore —
// this fires only when a release APK/AAB is actually being assembled.
//
// `-PallowDebugSigning=true` is the deliberate escape hatch for
// `flutter run --release` on a developer machine. It has to be typed, so an
// unsigned or debug-signed artifact can never be produced by accident.
gradle.taskGraph.whenReady {
    val assemblingRelease = allTasks.any { task ->
        (task.name.startsWith("assemble") || task.name.startsWith("bundle")) &&
            task.name.contains("Release")
    }
    val allowDebugSigning =
        (project.findProperty("allowDebugSigning") as String?)?.toBoolean() ?: false

    if (assemblingRelease && !hasReleaseKeystore && !allowDebugSigning) {
        throw GradleException(
            """
            |Release build refused: android/key.properties is missing.
            |
            |A release APK/AAB must be signed with the real upload key. This used
            |to fall back to the DEBUG key, which Play rejects and which is not
            |secret — and it did so silently, producing an artifact that looked
            |shippable and was not.
            |
            |To build a real release:
            |  1. create the upload keystore (see docs, and keep it safe — losing
            |     it means this app can never be updated again);
            |  2. copy android/key.properties.example to android/key.properties
            |     and fill it in.
            |
            |For a LOCAL release-mode run only, and never for anything you intend
            |to distribute:
            |  flutter build apk --release -PallowDebugSigning=true
            """.trimMargin()
        )
    }
}

flutter {
    source = "../.."
}
