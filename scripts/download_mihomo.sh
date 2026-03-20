#!/bin/bash
set -e

PLATFORM=$1
MIHOMO_VERSION="v1.19.6"
MIHOMO_URL="https://github.com/MetaCubeX/mihomo/releases/download/${MIHOMO_VERSION}"

case $PLATFORM in
  android)
    echo "Downloading mihomo for Android (arm64)..."
    mkdir -p android/app/src/main/jniLibs/arm64-v8a

    curl -L --fail "${MIHOMO_URL}/mihomo-linux-arm64-${MIHOMO_VERSION}.gz" -o mihomo.gz
    gunzip mihomo.gz
    mv mihomo android/app/src/main/jniLibs/arm64-v8a/libmihomo.so

    echo "Done: libmihomo.so -> jniLibs/arm64-v8a/"
    ;;

  windows)
    echo "Downloading mihomo for Windows (amd64)..."
    mkdir -p assets/mihomo
    curl -L --fail "${MIHOMO_URL}/mihomo-windows-amd64-${MIHOMO_VERSION}.zip" -o mihomo.zip
    unzip -o mihomo.zip -d mihomo_tmp/
    find mihomo_tmp/ -name "mihomo*.exe" -exec mv {} assets/mihomo/mihomo.exe \;
    rm -rf mihomo_tmp/ mihomo.zip
    echo "Done: mihomo.exe -> assets/mihomo/"
    ;;

  macos)
    echo "Downloading mihomo for macOS (amd64)..."
    mkdir -p assets/mihomo
    curl -L --fail "${MIHOMO_URL}/mihomo-darwin-amd64-${MIHOMO_VERSION}.gz" -o mihomo.gz
    gunzip mihomo.gz
    mv mihomo assets/mihomo/mihomo
    chmod +x assets/mihomo/mihomo
    echo "Done: mihomo -> assets/mihomo/"
    ;;

  *)
    echo "Unknown platform: $PLATFORM"
    exit 1
    ;;
esac
