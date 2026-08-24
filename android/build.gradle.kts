allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Some plugins (flutter_secure_storage 11.0.0) hardcode compileSdk = 37.
// This machine's Android SDK only distributes minor-versioned API 37
// packages (android-37.0, android-37.1, ...) whose metadata uses an SDK XML
// schema version this AGP release can't parse, so there is no working
// "android-37" target to resolve against. The plugins themselves only need
// stable Keystore/biometric APIs, not anything API-37-specific, so it's
// safe to clamp every subproject back down to the SDK platform this project
// actually has installed and builds against.
//
// ":app" is excluded: its own compileSdk already resolves correctly via
// flutter.compileSdkVersion, and by the time this block runs it may already
// be fully evaluated (the "evaluationDependsOn" above forces it to
// evaluate early as a side effect of configuring other subprojects), which
// would make calling afterEvaluate on it here throw.
subprojects {
    if (project.name == "app") return@subprojects
    afterEvaluate {
        extensions.findByName("android")?.let { androidExtension ->
            if (androidExtension is com.android.build.gradle.BaseExtension) {
                if (androidExtension.compileSdkVersion == "android-37") {
                    androidExtension.compileSdkVersion("android-36")
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
