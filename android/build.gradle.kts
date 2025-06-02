// Top-level build file where you can add configuration options common to all sub-projects/modules.
plugins {
    // Apply the Android Application plugin (usually for the 'app' module)
    id("com.android.application") version "8.7.0" apply false 
    // Apply the Kotlin Android plugin
    id("org.jetbrains.kotlin.android") version "1.8.22" apply false 
    // Apply the Google Services plugin (for Firebase)
    id("com.google.gms.google-services") version "4.3.15" apply false 
    // Apply the Flutter Gradle plugin
    id("dev.flutter.flutter-gradle-plugin") apply false
}

allprojects {
    repositories {
        // Google's Maven repository
        google()
        // Maven Central repository
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
