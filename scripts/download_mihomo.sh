#!/bin/bash
# 下载对应平台的 mihomo 内核
set -e

PLATFORM=$1
MIHOMO_VERSION="v1.19.6"
BASE_URL="https://github.com/MetaCubeX/mihomo/releases/download/${MIHOMO_VERSION}"

case $PLATFORM in
  android)
    echo "Downloading mihomo for Android (arm64-v8a)..."
    # 放入 jniLibs：Android 会自动解压到可执行目录，绕过 W^X 限制
    mkdir -p android/app/src/main/jniLibs/arm64-v8a
    curl -L --fail \
      "${BASE_URL}/mihomo-linux-arm64-${MIHOMO_VERSION}.gz" \
      -o mihomo.gz
    gunzip mihomo.gz
    # 重命名为 .so 让 Android 将其视为 native library 并正确提取
    mv mihomo android/app/src/main/jniLibs/arm64-v8a/libmihomo.so
    echo "Done: libmihomo.so -> android/app/src/main/jniLibs/arm64-v8a/"
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
