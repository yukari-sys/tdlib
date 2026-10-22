
cmake_minimum_required(VERSION 3.22)

project(tdlib_android_build LANGUAGES C CXX)

include(ExternalProject)

# -------------------------------------------------------------------
# Paths and configuration
# -------------------------------------------------------------------

set(CMAKE_BUILD_TYPE RelWithDebInfo CACHE STRING "Build type")

set(TD_SOURCE_DIR "${CMAKE_SOURCE_DIR}/td")
set(LIBRESSL_SOURCE_DIR "${CMAKE_SOURCE_DIR}/libressl")

set(OUTPUT_DIR "${CMAKE_BINARY_DIR}/output"
    CACHE PATH "Output directory")

set(TD_JAVA_OUTPUT_DIR
    "${CMAKE_BINARY_DIR}/generated/tdlib/java"
    CACHE PATH "Generated Java source root")

# Gradle packages native libraries from this directory.
set(TD_JNI_OUTPUT_DIR
    "${CMAKE_BINARY_DIR}/generated/tdlib/jniLibs"
    CACHE PATH "Generated Android JNI library directory")

set(LIBRESSL_INSTALL_DIR "${OUTPUT_DIR}/libressl")
set(LIBRESSL_INCLUDE_DIR "${LIBRESSL_INSTALL_DIR}/include")
set(LIBRESSL_LIBRARY_DIR "${LIBRESSL_INSTALL_DIR}/lib")

set(TD_BUILD_DIR "${CMAKE_BINARY_DIR}/td-build")

file(MAKE_DIRECTORY
    "${OUTPUT_DIR}"
    "${TD_JAVA_OUTPUT_DIR}/org/drinkless/tdlib"
    "${TD_JNI_OUTPUT_DIR}"
)

# -------------------------------------------------------------------
# Propagate Android configuration into nested CMake projects.
# -------------------------------------------------------------------

set(ANDROID_FORWARD_ARGS)

if(CMAKE_TOOLCHAIN_FILE)
    list(APPEND ANDROID_FORWARD_ARGS
        "-DCMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE}")
endif()

if(ANDROID)
    list(APPEND ANDROID_FORWARD_ARGS
        "-DANDROID=ON"
        "-DANDROID_PLATFORM=${ANDROID_PLATFORM}"
        "-DANDROID_ABI=${ANDROID_ABI}"
        "-DANDROID_STL=${ANDROID_STL}")
endif()

# -------------------------------------------------------------------
# LibreSSL
# -------------------------------------------------------------------

set(LIBRESSL_CMAKE_ARGS
    ${ANDROID_FORWARD_ARGS}
    "-DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}"
    "-DCMAKE_INSTALL_PREFIX=${LIBRESSL_INSTALL_DIR}"
    "-DCMAKE_POSITION_INDEPENDENT_CODE=ON"
    "-DBUILD_SHARED_LIBS=ON"
)

ExternalProject_Add(libressl_external
    SOURCE_DIR "${LIBRESSL_SOURCE_DIR}"
    BINARY_DIR "${CMAKE_BINARY_DIR}/libressl-build"

    CMAKE_ARGS ${LIBRESSL_CMAKE_ARGS}

    BUILD_COMMAND
        "${CMAKE_COMMAND}" --build <BINARY_DIR> --parallel

    INSTALL_COMMAND
        "${CMAKE_COMMAND}" --install <BINARY_DIR>

    BUILD_ALWAYS TRUE
    UPDATE_COMMAND ""
)

# -------------------------------------------------------------------
# TDLib Android JNI project
# -------------------------------------------------------------------

set(TD_CMAKE_ARGS
    ${ANDROID_FORWARD_ARGS}
    "-DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}"
    "-DBUILD_SHARED_LIBS=ON"
    "-DTD_GENERATE_SOURCE_FILES=ON"
    "-DOPENSSL_ROOT_DIR=${LIBRESSL_INSTALL_DIR}"
    "-DOPENSSL_INCLUDE_DIR=${LIBRESSL_INCLUDE_DIR}"
    "-DOPENSSL_CRYPTO_LIBRARY=${LIBRESSL_LIBRARY_DIR}/libcrypto.so"
    "-DOPENSSL_SSL_LIBRARY=${LIBRESSL_LIBRARY_DIR}/libssl.so"
)

ExternalProject_Add(td_external
    SOURCE_DIR "${TD_SOURCE_DIR}/example/android"
    BINARY_DIR "${TD_BUILD_DIR}"

    CMAKE_ARGS ${TD_CMAKE_ARGS}

    DEPENDS libressl_external

    BUILD_COMMAND
        "${CMAKE_COMMAND}" --build <BINARY_DIR>
            --target tdjni --parallel

    COMMAND
        "${CMAKE_COMMAND}" --build <BINARY_DIR>
            --target tl_generate_java --parallel

    INSTALL_COMMAND ""

    BUILD_ALWAYS TRUE
    UPDATE_COMMAND ""
)

# -------------------------------------------------------------------
# Stage Java bindings for Gradle
# -------------------------------------------------------------------

set(TD_JAVA_CLIENT
    "${TD_SOURCE_DIR}/example/java/org/drinkless/tdlib/Client.java")

set(TD_JAVA_API
    "${TD_SOURCE_DIR}/example/android/org/drinkless/tdlib/TdApi.java")

add_custom_target(td_java_sources
    COMMAND "${CMAKE_COMMAND}" -E make_directory
        "${TD_JAVA_OUTPUT_DIR}/org/drinkless/tdlib"

    COMMAND "${CMAKE_COMMAND}" -E copy_if_different
        "${TD_JAVA_CLIENT}"
        "${TD_JAVA_OUTPUT_DIR}/org/drinkless/tdlib/Client.java"

    COMMAND "${CMAKE_COMMAND}" -E copy_if_different
        "${TD_JAVA_API}"
        "${TD_JAVA_OUTPUT_DIR}/org/drinkless/tdlib/TdApi.java"

    DEPENDS td_external
    VERBATIM
)

# -------------------------------------------------------------------
# Stage JNI library
# -------------------------------------------------------------------

# The Android Gradle Plugin packages .so files from jniLibs/<ABI>/.
# This project is configured for a single ABI per Android native build.

set(TD_JNI_LIBRARY "${TD_BUILD_DIR}/libtdjni.so")

add_custom_target(td_stage_jni
    COMMAND "${CMAKE_COMMAND}" -E make_directory
        "${TD_JNI_OUTPUT_DIR}/$<IF:$<BOOL:${ANDROID_ABI}>,${ANDROID_ABI},unknown>"

    COMMAND "${CMAKE_COMMAND}" -E copy_if_different
        "${TD_JNI_LIBRARY}"
        "${TD_JNI_OUTPUT_DIR}/$<IF:$<BOOL:${ANDROID_ABI}>,${ANDROID_ABI},unknown>/libtdjni.so"

    DEPENDS td_external
    VERBATIM
)

add_custom_target(android_tdlib
    DEPENDS td_java_sources td_stage_jni
)
