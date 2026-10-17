#!/bin/bash
set -e

. ./env.sh

pushd td

mkdir -p build-native
cmake -S example/android -B build-native -DTD_GENERATE_SOURCE_FILES=ON
cmake --build build-native
cmake --build build-native --target tl_generate_java
cp example/java/org/drinkless/tdlib/Client.java \
  example/android/org/drinkless/tdlib/TdApi.java \
  ../build

for ABI in $ABIS; do
  INSTALL_DIR=${PWD}/../build/${ABI}/tdlib
  LIBRESSL_INSTALL_DIR=${PWD}/../build/${ABI}/libressl

  mkdir -p build-$ABI $INSTALL_DIR
  
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
  cp -p build-$ABI/libtdjni.so $INSTALL_DIR
done

popd
