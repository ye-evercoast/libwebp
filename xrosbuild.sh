#!/bin/bash
#
# NOTE: Run this script on a Intel Mac. Silicon Mac won't work as configure will report error
#
# This script generates 'WebP.framework' and 'WebPDecoder.framework',
# 'WebPDemux.framework' and 'WebPMux.framework'.
# An visionOS app can decode WebP images by including 'WebPDecoder.framework' and
# both encode and decode WebP images by including 'WebP.framework'.
#
# Run ./xrosbuild.sh to generate the frameworks under the current directory
# (the previous build will be erased if it exists).
#
# This script is inspired by the build script written by Carson McDonald.
# (https://www.ioncannon.net/programming/1483/using-webp-to-reduce-native-ios-app-size/).

set -e

# Set this variable based on the desired minimum deployment target.
readonly XROS_MIN_VERSION=1.0

# Extract the latest SDK version from the final field of the form: iphoneosX.Y
readonly SDK=$(xcodebuild -showsdks \
  | grep xros | sort | tail -n 1 | awk '{print substr($NF, 5)}'
)

# Extract Xcode version.
readonly XCODE=$(xcodebuild -version | grep Xcode | cut -d " " -f2)
if [[ -z "${XCODE}" ]]; then
  echo "Xcode not available"
  exit 1
fi

if [[ -z "${SDK}" ]]; then
  echo "XROS SDK not available"
  exit 1
fi

echo "XROS SDK: ${SDK}"

if [[ $(uname -m) == 'arm64' ]]; then
  echo "This script still does't support Mac Silicon. Use Mac x86_64 to build."
  exit 1
fi

readonly OLDPATH=${PATH}

PLATFORMS="XROS-arm64 XRSimulator-arm64"
readonly SRCDIR=$(dirname $0)
readonly TOPDIR=$(pwd)

for PLATFORM in ${PLATFORMS}; do
  BUILDDIR="${TOPDIR}/xrosbuild/${PLATFORM}"
  TARGETDIR="${BUILDDIR}/WebP.framework"
  DECTARGETDIR="${BUILDDIR}/WebPDecoder.framework"
  MUXTARGETDIR="${BUILDDIR}/WebPMux.framework"
  DEMUXTARGETDIR="${BUILDDIR}/WebPDemux.framework"
  SHARPYUVTARGETDIR="${BUILDDIR}/SharpYuv.framework"
  DEVELOPER=$(xcode-select --print-path)
  PLATFORMSROOT="${DEVELOPER}/Platforms"
  LIPO=$(xcrun -sdk xros${SDK} -find lipo)
  LIBLIST=''
  DECLIBLIST=''
  MUXLIBLIST=''
  DEMUXLIBLIST=''
  SHARPYUVLIBLIST=''


  EXTRA_CFLAGS="-fembed-bitcode"

  echo "Xcode Version: ${XCODE}"
  echo "XROS SDK Version: ${SDK}"

  if [[ -e "${BUILDDIR}" || -e "${TARGETDIR}" || -e "${DECTARGETDIR}" \
        || -e "${MUXTARGETDIR}" || -e "${DEMUXTARGETDIR}" \
        || -e "${SHARPYUVTARGETDIR}" ]]; then
    cat << EOF
WARNING: The following directories will be deleted:
WARNING:   ${BUILDDIR}
WARNING:   ${TARGETDIR}
WARNING:   ${DECTARGETDIR}
WARNING:   ${MUXTARGETDIR}
WARNING:   ${DEMUXTARGETDIR}
WARNING:   ${SHARPYUVTARGETDIR}

EOF
  fi

  rm -rf ${BUILDDIR} ${TARGETDIR} ${DECTARGETDIR} \
      ${MUXTARGETDIR} ${DEMUXTARGETDIR} ${SHARPYUVTARGETDIR}
  mkdir -p ${BUILDDIR} ${TARGETDIR}/Headers/ ${DECTARGETDIR}/Headers/ \
      ${MUXTARGETDIR}/Headers/ ${DEMUXTARGETDIR}/Headers/ \
      ${SHARPYUVTARGETDIR}/Headers/

  if [[ ! -e ${SRCDIR}/configure ]]; then
    if ! (cd ${SRCDIR} && sh autogen.sh); then
      cat << EOF
Error creating configure script!
This script requires the autoconf/automake and libtool to build. MacPorts can
be used to obtain these:
https://www.macports.org/install.php
EOF
      exit 1
    fi
  fi


  if [[ "${PLATFORM}" == "XROS-arm64" ]]; then
    PLATFORM="XROS"
    ARCH="arm64"
    EXTRA_CFLAGS+=" -target arm64-apple-xros${XROS_MIN_VERSION}"
  elif [[ "${PLATFORM}" == "XRSimulator-arm64" ]]; then
    PLATFORM="XRSimulator"
    ARCH="arm64"
    EXTRA_CFLAGS+=" -target arm64-apple-xros${XROS_MIN_VERSION}-simulator"
  else
    ARCH=""
  fi

  ROOTDIR="${BUILDDIR}/${PLATFORM}-${SDK}-${ARCH}"
  mkdir -p "${ROOTDIR}"

  DEVROOT="${DEVELOPER}/Toolchains/XcodeDefault.xctoolchain"
  SDKROOT="${PLATFORMSROOT}/"
  SDKROOT+="${PLATFORM}.platform/Developer/SDKs/${PLATFORM}${SDK}.sdk/"
  CFLAGS="-arch ${ARCH} -pipe -isysroot ${SDKROOT} -O3 -DNDEBUG"
  #CFLAGS+=" -miphoneos-version-min=${IOS_MIN_VERSION} ${EXTRA_CFLAGS}"
  CFLAGS+=" ${EXTRA_CFLAGS}"

  echo "CFLAGS: ${CFLAGS}"
  echo "SDKROOT: ${SDKROOT}"

  set -x
  export PATH="${DEVROOT}/usr/bin:${OLDPATH}"
  ${SRCDIR}/configure --host=${ARCH}-apple-darwin --prefix=${ROOTDIR} \
    --build=$(${SRCDIR}/config.guess) \
    --disable-shared --enable-static \
    --enable-libwebpdecoder --enable-swap-16bit-csp \
    --enable-libwebpmux \
    CFLAGS="${CFLAGS}"
  set +x

  # Build only the libraries, skip the examples.
  make V=0 -C sharpyuv install
  make V=0 -C src install

  LIBLIST+=" ${ROOTDIR}/lib/libwebp.a"
  DECLIBLIST+=" ${ROOTDIR}/lib/libwebpdecoder.a"
  MUXLIBLIST+=" ${ROOTDIR}/lib/libwebpmux.a"
  DEMUXLIBLIST+=" ${ROOTDIR}/lib/libwebpdemux.a"
  SHARPYUVLIBLIST+=" ${ROOTDIR}/lib/libsharpyuv.a"

  make clean

  export PATH=${OLDPATH}

  echo "LIBLIST = ${LIBLIST}"
  cp -a ${SRCDIR}/src/webp/{decode,encode,types}.h ${TARGETDIR}/Headers/
  cp -a ${SRCDIR}/plist/xros/Info_WebP.plist ${TARGETDIR}/Info.plist
  cp -a ${SRCDIR}/PrivacyInfo.xcprivacy ${TARGETDIR}/
  ${LIPO} -create ${LIBLIST} -output ${TARGETDIR}/WebP

  echo "DECLIBLIST = ${DECLIBLIST}"
  cp -a ${SRCDIR}/src/webp/{decode,types}.h ${DECTARGETDIR}/Headers/
  cp -a ${SRCDIR}/plist/xros/Info_WebPDecoder.plist ${DECTARGETDIR}/Info.plist
  cp -a ${SRCDIR}/PrivacyInfo.xcprivacy ${DECTARGETDIR}/
  ${LIPO} -create ${DECLIBLIST} -output ${DECTARGETDIR}/WebPDecoder

  echo "MUXLIBLIST = ${MUXLIBLIST}"
  cp -a ${SRCDIR}/src/webp/{types,mux,mux_types}.h \
      ${MUXTARGETDIR}/Headers/
  cp -a ${SRCDIR}/plist/xros/Info_WebPMux.plist ${MUXTARGETDIR}/Info.plist
  cp -a ${SRCDIR}/PrivacyInfo.xcprivacy ${MUXTARGETDIR}/
  ${LIPO} -create ${MUXLIBLIST} -output ${MUXTARGETDIR}/WebPMux

  echo "DEMUXLIBLIST = ${DEMUXLIBLIST}"
  cp -a ${SRCDIR}/src/webp/{decode,types,mux_types,demux}.h \
      ${DEMUXTARGETDIR}/Headers/
  cp -a ${SRCDIR}/plist/xros/Info_WebPDemux.plist ${DEMUXTARGETDIR}/Info.plist
  cp -a ${SRCDIR}/PrivacyInfo.xcprivacy ${DEMUXTARGETDIR}/
  ${LIPO} -create ${DEMUXLIBLIST} -output ${DEMUXTARGETDIR}/WebPDemux

  echo "SHARPYUVLIBLIST = ${SHARPYUVLIBLIST}"
  cp -a ${SRCDIR}/sharpyuv/{sharpyuv,sharpyuv_csp}.h \
      ${SHARPYUVTARGETDIR}/Headers/
  cp -a ${SRCDIR}/plist/xros/Info_SharpYuv.plist ${SHARPYUVTARGETDIR}/Info.plist
  cp -a ${SRCDIR}/PrivacyInfo.xcprivacy ${SHARPYUVTARGETDIR}/
  ${LIPO} -create ${SHARPYUVLIBLIST} -output ${SHARPYUVTARGETDIR}/SharpYuv

done
echo  "SUCCESS"
