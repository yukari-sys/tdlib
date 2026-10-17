#!/bin/bash
set -e

. ./env.sh

pushd libressl

if [ ! -f ./configure ]; then ./autogen.sh; fi

for ABI in $ABIS; do
  INSTALL_DIR=${PWD}/../build/${ABI}/libressl

  mkdir -p build-$ABI $INSTALL_DIR

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
  
  rm -rf ${INSTALL_DIR}/{bin,etc,share,lib/{cmake,pkgconfig,libtls.so}}
done

popd
