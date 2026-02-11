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

// FIXES FOR BUILD ERRORS
subprojects {
    // 1. Fix Namespace (for plugins like on_audio_query)
    val fixNamespace = {
        val android = extensions.findByName("android")
        if (android != null) {
            try {
                val getNamespace = android.javaClass.getMethod("getNamespace")
                val currentNamespace = getNamespace.invoke(android)
                
                if (currentNamespace == null) {
                    val setNamespace = android.javaClass.getMethod("setNamespace", String::class.java)
                    setNamespace.invoke(android, project.group.toString())
                }
            } catch (e: Exception) {
                // Safely ignore
            }
        }
    }

    // 2. Fix JVM Target
    val fixJvmTarget = {
        try {
            project.tasks.withType(org.jetbrains.kotlin.gradle.tasks.KotlinCompile::class.java).configureEach {
                compilerOptions {
                    // Robust check for the App module
                    val isApp = project.name == "app" || project.path == ":app" || project.path.endsWith(":app")
                    
                    if (isApp) {
                        // The App module matches the Java version defined in android/app/build.gradle (usually 17)
                        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
                    } else {
                        // Plugins like on_audio_query often rely on Java 1.8
                        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_1_8)
                    }
                }
            }
        } catch (e: Exception) {
            // Ignore
        }
    }

    // 3. Apply
    if (state.executed) {
        fixNamespace()
        fixJvmTarget()
    } else {
        afterEvaluate {
            fixNamespace()
            fixJvmTarget()
        }
    }
}