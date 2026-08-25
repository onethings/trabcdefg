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

// Some Flutter plugins (e.g. flutter_native_splash) hardcode an old
// compileSdkVersion (31) in their own build.gradle. With newer AGP versions,
// dependency compileSdk validation fails because transitive AndroidX
// dependencies require SDK 33+. Force every Android library subproject to
// compile against the app's compileSdk (flutter.compileSdkVersion) so the
// build satisfies that check.
// NOTE: This must be registered BEFORE the `evaluationDependsOn(":app")` block
// below, otherwise subprojects are already evaluated and afterEvaluate throws.
subprojects {
    afterEvaluate {
        extensions.findByType(com.android.build.api.dsl.LibraryExtension::class.java)?.let { lib ->
            lib.compileSdk = 36
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
