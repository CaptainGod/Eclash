#!/bin/bash
# 下载对应平台的 mihomo 内核
set -e

PLATFORM=$1
MIHOMO_VERSION="v1.19.6"
BASE_URL="https://github.com/MetaCubeX/mihomo/releases/download/${MIHOMO_VERSION}"

case $PLATFORM in
  android)
    echo "Downloading mihomo for Android (linux-arm64)..."
    mkdir -p assets/mihomo
    curl -L --fail \
      "${BASE_URL}/mihomo-linux-arm64-${MIHOMO_VERSION}.gz" \
      -o mihomo.gz
    gunzip mihomo.gz
    mv mihomo assets/mihomo/mihomo-android
    chmod +x assets/mihomo/mihomo-android
    echo "Done: mihomo-android -> assets/mihomo/"
    ;;

  windows)
    echo "Downloading mihomo for Windows (amd64)..."
    mkdir -p assets/mihomo
    curl -L --fail \
      "${BASE_URL}/mihomo-windows-amd64-${MIHOMO_VERSION}.zip" \
      -o mihomo.zip
    unzip -o mihomo.zip -d mihomo_tmp/
    find mihomo_tmp/ -name "mihomo*.exe" -exec mv {} assets/mihomo/mihomo.exe \;
    rm -rf mihomo_tmp/ mihomo.zip
    echo "Done: mihomo.exe -> assets/mihomo/"
    ;;

  macos)
    echo "Downloading mihomo for macOS (amd64)..."
    mkdir -p assets/mihomo
    curl -L --fail \
      "${BASE_URL}/mihomo-darwin-amd64-${MIHOMO_VERSION}.gz" \
      -o mihomo.gz
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
