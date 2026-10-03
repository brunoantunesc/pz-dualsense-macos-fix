#!/usr/bin/env bash
set -euo pipefail

GLFW_REPO="https://github.com/glfw/glfw.git"
GLFW_COMMIT="92dcf4ce74f2e2554a98fea09be7c705c17daa5a"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PATCH_FILE="$ROOT_DIR/patches/glfw-dualsense-bluetooth-macos.patch"
WORK_DIR="$ROOT_DIR/.work"
SRC_DIR="$WORK_DIR/glfw"
BUILD_DIR="$SRC_DIR/build"
OUT_DIR="$ROOT_DIR/build"

echo "==> Checking dependencies"

for cmd in git cmake clang python3; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Missing dependency: $cmd"
        exit 1
    fi
done

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "This build script is intended for macOS."
    exit 1
fi

ARCH="$(uname -m)"
if [[ "$ARCH" != "arm64" ]]; then
    echo "Unsupported architecture: $ARCH"
    echo "This version currently targets Apple Silicon (arm64)."
    exit 1
fi

if [[ ! -f "$PATCH_FILE" ]]; then
    echo "Patch not found:"
    echo "$PATCH_FILE"
    exit 1
fi

echo "==> Preparing clean GLFW source"

rm -rf "$SRC_DIR"
mkdir -p "$WORK_DIR"

git clone --quiet "$GLFW_REPO" "$SRC_DIR"

cd "$SRC_DIR"
git checkout --quiet "$GLFW_COMMIT"

echo "==> Applying DualSense Bluetooth patch"

git apply "$PATCH_FILE"

echo "==> Building GLFW"

cmake -S . -B "$BUILD_DIR" \
    -DGLFW_BUILD_EXAMPLES=OFF \
    -DGLFW_BUILD_TESTS=OFF \
    -DGLFW_BUILD_DOCS=OFF \
    -DGLFW_INSTALL=OFF \
    -DGLFW_LIBRARY_TYPE=SHARED

cmake --build "$BUILD_DIR" -j

DYLIB="$BUILD_DIR/src/libglfw.3.dylib"

if [[ ! -f "$DYLIB" ]]; then
    echo "Build completed, but expected dylib was not found:"
    echo "$DYLIB"
    exit 1
fi

echo "==> Verifying architecture"

if ! file "$DYLIB" | grep -q "arm64"; then
    echo "Built library does not appear to contain arm64 code:"
    file "$DYLIB"
    exit 1
fi

mkdir -p "$OUT_DIR"

cp "$DYLIB" "$OUT_DIR/libglfw-dualsense-fix.dylib"

echo
echo "Build complete."
echo "Output:"
echo "$OUT_DIR/libglfw-dualsense-fix.dylib"
echo
shasum -a 256 "$OUT_DIR/libglfw-dualsense-fix.dylib"
