#!/bin/bash
set -e

ABIS="arm64-v8a armeabi-v7a x86_64 x86"

ANDROID_STL="c++_static"
ANDROID_PLATFORM="android-33"
ANDROID_NDK_VERSION="30.0.16248370"

ANDROID_SDK_ROOT="$ANDROID_HOME"
ANDROID_NDK_ROOT="$ANDROID_SDK_ROOT/ndk/$ANDROID_NDK_VERSION"

OUTPUT_DIR=$(realpath ${OUTPUT_DIR:-build})

prepare_td() {
  pushd td

  mkdir -p build-native
  cmake -S example/android -B build-native -DTD_GENERATE_SOURCE_FILES=ON
  cmake --build build-native
  cmake --build build-native --target tl_generate_java
  cp example/java/org/drinkless/tdlib/Client.java \
    example/android/org/drinkless/tdlib/TdApi.java \
    ../build

  popd td
}

prepare_libressl() {
  pushd libressl
  
  if [ ! -f ./configure ]; then ./autogen.sh; fi

  popd libressl
}

build_td() {
  ABI=$1
  LIBRESSL_INSTALL_DIR="${OUTPUT_DIR}/${ABI}/libressl"
  INSTALL_DIR="${OUTPUT_DIR}/${ABI}/tdlib"
  
  pushd td

  mkdir -p build-$ABI "$INSTALL_DIR"
  
  cmake -S example/android -B build-$ABI \
    -DCMAKE_TOOLCHAIN_FILE="$ANDROID_NDK_ROOT/build/cmake/android.toolchain.cmake" \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -GNinja \
    -DANDROID_ABI="$ABI" \
    -DANDROID_STL="$ANDROID_STL" \
    -DANDROID_PLATFORM="$ANDROID_PLATFORM" \
    -DBUILD_SHARED_LIBS=ON \
    -DOPENSSL_ROOT_DIR="$LIBRESSL_INSTALL_DIR" \
    -DOPENSSL_INCLUDE_DIR="$LIBRESSL_INSTALL_DIR/include" \
    -DOPENSSL_CRYPTO_LIBRARY="$LIBRESSL_INSTALL_DIR/lib/libcrypto.so" \
    -DOPENSSL_SSL_LIBRARY="$LIBRESSL_INSTALL_DIR/lib/libssl.so"
  cmake --build build-$ABI --target tdjni
  cp -p build-$ABI/libtdjni.so "$INSTALL_DIR"

  popd
}

build_libressl() {
  ABI=$1
  INSTALL_DIR="${OUTPUT_DIR}/${ABI}/libressl"
  
  pushd libressl

  mkdir -p build-$ABI "$INSTALL_DIR"

  cmake -S . -B build-$ABI \
    -DCMAKE_TOOLCHAIN_FILE="$ANDROID_NDK_ROOT/build/cmake/android.toolchain.cmake" \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -GNinja \
    -DANDROID_ABI="$ABI" \
    -DANDROID_STL="$ANDROID_STL" \
    -DANDROID_PLATFORM="$ANDROID_PLATFORM" \
    -DBUILD_SHARED_LIBS=ON \
    -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR"
  cmake --build build-$ABI
  cmake --build build-$ABI --target ssl crypto
  cmake --install build-$ABI
  
  rm -rf "${INSTALL_DIR}"/{bin,etc,share,lib/{cmake,pkgconfig,libtls.so}}

  popd
}

prepare_libressl
prepare_td

for ABI in $ABIS; do
  build_libressl $ABI
  build_td $ABI
done
