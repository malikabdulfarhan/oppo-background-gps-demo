import com.android.build.api.dsl.LibraryExtension
import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import org.jetbrains.kotlin.gradle.tasks.KotlinJvmCompile

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

listOf(
    ":atomic_x_core",
    ":rtc_room_engine_impl",
    ":tencent_calls_uikit",
    ":tencent_cloud_uikit_core",
    ":tencent_rtc_sdk",
    ":tuikit_atomic_x",
).forEach { projectPath ->
    project(projectPath) {
        afterEvaluate {
            extensions.configure<LibraryExtension> {
                compileSdk = 36
            }
        }
    }
}

// rtc_room_engine_impl publishes Java 8 bytecode but does not declare a
// Kotlin target. AGP otherwise inherits the host JDK (21), which Gradle rejects
// as an inconsistent target for this vendor module.
project(":rtc_room_engine_impl") {
    tasks.withType<KotlinJvmCompile>().configureEach {
        compilerOptions.jvmTarget.set(JvmTarget.JVM_1_8)
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
