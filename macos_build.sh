#!/bin/bash

# Seems SharpYuv will complain about Mac Universal build so we build them separately

PLATFORMS="MAC MAC_ARM64"

readonly TOPDIR=$(pwd)
readonly TOOLCHAIN_FILE="${TOPDIR}/cmake/ios.toolchain.cmake"

for PLATFORM in ${PLATFORMS}; do
	echo "Building platform ${PLATFORM}"
	BUILDDIR="${TOPDIR}/build_${PLATFORM}"
	rm -rf "${BUILDDIR}"
	mkdir -p "${BUILDDIR}"
	cd "${BUILDDIR}"
	cmake .. -DCMAKE_TOOLCHAIN_FILE=${TOOLCHAIN_FILE} -DBUILD_SHARED_LIBS=1 -DPLATFORM=${PLATFORM}
	make
done


echo "Merging dylibs into Mac Universal dylibs"

cd "${TOPDIR}"

WEBP_LIB="libwebp.dylib"
WEBPDECODER_LIB="libwebpdecoder.dylib"
WEBPMUX_LIB="libwebpmux.dylib"
WEBPDEMUX_LIB="libwebpdemux.dylib"
SHARPYUV_LIB="libsharpyuv.dylib"

rm -rf ${WEBP_LIB} ${WEBPDECODER_LIB} ${WEBPMUX_LIB} ${WEBPDEMUX_LIB} ${SHARPYUV_LIB}

lipo -create -arch x86_64 "${TOPDIR}/build_MAC/${WEBP_LIB}" -arch arm64 "${TOPDIR}/build_MAC_ARM64/${WEBP_LIB}" -output ${WEBP_LIB}
lipo -create -arch x86_64 "${TOPDIR}/build_MAC/${WEBPDECODER_LIB}" -arch arm64 "${TOPDIR}/build_MAC_ARM64/${WEBPDECODER_LIB}" -output ${WEBPDECODER_LIB}
lipo -create -arch x86_64 "${TOPDIR}/build_MAC/${WEBPMUX_LIB}" -arch arm64 "${TOPDIR}/build_MAC_ARM64/${WEBPMUX_LIB}" -output ${WEBPMUX_LIB}
lipo -create -arch x86_64 "${TOPDIR}/build_MAC/${WEBPDEMUX_LIB}" -arch arm64 "${TOPDIR}/build_MAC_ARM64/${WEBPDEMUX_LIB}" -output ${WEBPDEMUX_LIB}
lipo -create -arch x86_64 "${TOPDIR}/build_MAC/${SHARPYUV_LIB}" -arch arm64 "${TOPDIR}/build_MAC_ARM64/${SHARPYUV_LIB}" -output ${SHARPYUV_LIB}

echo "Done"