#!/bin/bash
# 下载对应平台的 mihomo 内核
set -e

PLATFORM=$1
MIHOMO_VERSION="v1.19.0"
BASE_URL="https://github.com/MetaCubeX/mihomo/releases/download/${MIHOMO_VERSION}"

case $PLATFORM in
  android)
    echo "Downloading mihomo for Android..."
    mkdir -p android/app/src/main/jniLibs/arm64-v8a
    curl -L "${BASE_URL}/mihomo-android-arm64-${MIHOMO_VERSION}.gz" -o mihomo.gz
    gunzip mihomo.gz
    mv mihomo android/app/src/main/jniLibs/arm64-v8a/libclash.so
    ;;
  windows)
    echo "Downloading mihomo for Windows..."
    mkdir -p assets/mihomo
    curl -L "${BASE_URL}/mihomo-windows-amd64-${MIHOMO_VERSION}.zip" -o mihomo.zip
    unzip mihomo.zip -d assets/mihomo/
    mv assets/mihomo/mihomo*.exe assets/mihomo/mihomo.exe
    ;;
  macos)
    echo "Downloading mihomo for macOS..."
    mkdir -p assets/mihomo
    curl -L "${BASE_URL}/mihomo-darwin-amd64-${MIHOMO_VERSION}.gz" -o mihomo.gz
    gunzip mihomo.gz
    mv mihomo assets/mihomo/mihomo
    chmod +x assets/mihomo/mihomo
    ;;
  *)
    echo "Unknown platform: $PLATFORM"
    exit 1
    ;;
esac

echo "Done: mihomo downloaded for $PLATFORM"
