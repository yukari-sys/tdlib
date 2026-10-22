
plugins {
    id("com.android.application")
}

android {
    namespace = "org.drinkless.tdlib"
    compileSdk = 35

    defaultConfig {
        applicationId = "org.drinkless.tdlib"
        minSdk = 23
        targetSdk = 35

        externalNativeBuild {
            cmake {
                arguments += listOf(
                    "-DCMAKE_BUILD_TYPE=RelWithDebInfo",
                    "-DTD_GENERATE_SOURCE_FILES=ON",
                    "-DTD_JAVA_OUTPUT_DIR=${layout.buildDirectory.get().dir("generated/tdlib/java").asFile}"
                )
            }
        }
    }

    sourceSets {
        getByName("main") {
            java.srcDir(
                layout.buildDirectory.dir("generated/tdlib/java")
            )
        }
    }

    externalNativeBuild {
        cmake {
            path = file("../CMakeLists.txt")
            version = "3.22.1"
        }
    }

    buildFeatures {
        buildConfig = false
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    packaging {
        jniLibs {
            useLegacyPackaging = false
        }
    }
}

// Ensure generated bindings exist before Java compilation.
// The CMake target must generate and copy them into the configured
// TD_JAVA_OUTPUT_DIR.
tasks.named("preBuild") {
    dependsOn("buildTdLibNative")
}

tasks.register("buildTdLibNative") {
    group = "build"
    description = "Build TDLib native libraries and generate Java bindings."

    dependsOn("externalNativeBuildDebug")
}

