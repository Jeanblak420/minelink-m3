// google-services Gradle plugin -- classpath only, applied conditionally in
// android/app/build.gradle.kts on whether google-services.json exists. That
// file does not exist on any machine or in CI today (no Firebase project
// yet -- see docs/push-setup.md), and a committed placeholder would break
// this plugin with an error that reads like a build bug rather than
// degrading, so the classpath is unconditional but the `apply` is not.
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.google.gms:google-services:4.4.2")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
