#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PATCHED_LIB="$ROOT_DIR/build/libglfw-dualsense-fix.dylib"

PZ_APP="$HOME/Library/Application Support/Steam/steamapps/common/ProjectZomboid/Project Zomboid.app"
PZ_JAR="$PZ_APP/Contents/Java/projectzomboid.jar"

BACKUP_DIR="$ROOT_DIR/backups"
BACKUP_JAR="$BACKUP_DIR/projectzomboid.jar.backup"

TMP_PATCH_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_PATCH_DIR"' EXIT

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "This installer only supports macOS."
    exit 1
fi

if [[ "$(uname -m)" != "arm64" ]]; then
    echo "This installer currently supports Apple Silicon (arm64) only."
    exit 1
fi

if [[ ! -f "$PZ_JAR" ]]; then
    echo "Project Zomboid was not found at:"
    echo "$PZ_JAR"
    echo
    echo "If your Steam library is installed elsewhere, edit PZ_APP in this script."
    exit 1
fi

if [[ ! -f "$PATCHED_LIB" ]]; then
    echo "Patched GLFW library not found."
    echo "Run:"
    echo
    echo "  ./scripts/build-glfw.sh"
    echo
    echo "before installing."
    exit 1
fi

mkdir -p "$BACKUP_DIR"

if [[ ! -f "$BACKUP_JAR" ]]; then
    echo "==> Backing up original projectzomboid.jar"
    cp "$PZ_JAR" "$BACKUP_JAR"
else
    echo "==> Existing backup found, keeping it:"
    echo "$BACKUP_JAR"
fi

echo "==> Patching projectzomboid.jar"

python3 - "$PZ_JAR" "$PATCHED_LIB" <<'PY'
import sys
import os
import zipfile
import hashlib

jar = sys.argv[1]
patched = sys.argv[2]

dylib_entry = "macos/arm64/org/lwjgl/glfw/libglfw.dylib"
sha_entry = "META-INF/macos/arm64/org/lwjgl/glfw/libglfw.dylib.sha1"

with open(patched, "rb") as f:
    dylib_data = f.read()

sha1_data = hashlib.sha1(dylib_data).hexdigest().encode("ascii") + b"\n"

tmp = jar + ".pz-dualsense-patched"

with zipfile.ZipFile(jar, "r") as zin:
    names = set(zin.namelist())

    if dylib_entry not in names:
        raise SystemExit(
            f"Expected GLFW entry not found in projectzomboid.jar:\n{dylib_entry}"
        )

    if sha_entry not in names:
        raise SystemExit(
            f"Expected SHA1 entry not found in projectzomboid.jar:\n{sha_entry}"
        )

    with zipfile.ZipFile(tmp, "w") as zout:
        for item in zin.infolist():
            data = zin.read(item.filename)

            if item.filename == dylib_entry:
                print("Replacing:", dylib_entry)
                data = dylib_data

            elif item.filename == sha_entry:
                print("Updating:", sha_entry)
                data = sha1_data

            zout.writestr(item, data)

os.replace(tmp, jar)

print("Patched SHA1:", hashlib.sha1(dylib_data).hexdigest())
PY

echo "==> Clearing LWJGL native cache"

rm -rf "$TMPDIR/lwjgl_$USER" 2>/dev/null || true

echo
echo "Installation complete."
echo
echo "Start Project Zomboid normally through Steam."
echo "If Steam verifies or updates the game, the patch may need to be reinstalled."
