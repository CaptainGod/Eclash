#!/bin/bash
set -e

PLATFORM=$1
MIHOMO_VERSION="v1.19.6"
TUN2SOCKS_VERSION="v2.5.2"
MIHOMO_URL="https://github.com/MetaCubeX/mihomo/releases/download/${MIHOMO_VERSION}"
TUN2SOCKS_URL="https://github.com/xjasonlyu/tun2socks/releases/download/${TUN2SOCKS_VERSION}"

case $PLATFORM in
  android)
    echo "Downloading mihomo + tun2socks for Android (arm64)..."
    mkdir -p android/app/src/main/jniLibs/arm64-v8a

    # mihomo
    curl -L --fail "${MIHOMO_URL}/mihomo-linux-arm64-${MIHOMO_VERSION}.gz" -o mihomo.gz
    gunzip mihomo.gz
    mv mihomo android/app/src/main/jniLibs/arm64-v8a/libmihomo.so

    # tun2socks
    curl -L --fail "${TUN2SOCKS_URL}/tun2socks-linux-arm64.zip" -o tun2socks.zip
    unzip -o tun2socks.zip -d tun2socks_tmp/
    mv tun2socks_tmp/tun2socks android/app/src/main/jniLibs/arm64-v8a/libtun2socks.so
    rm -rf tun2socks_tmp/ tun2socks.zip

    echo "Done: libmihomo.so + libtun2socks.so -> jniLibs/arm64-v8a/"
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
