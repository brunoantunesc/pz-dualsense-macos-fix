#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PZ_APP="$HOME/Library/Application Support/Steam/steamapps/common/ProjectZomboid/Project Zomboid.app"
PZ_JAR="$PZ_APP/Contents/Java/projectzomboid.jar"

BACKUP_JAR="$ROOT_DIR/backups/projectzomboid.jar.backup"

if [[ ! -f "$BACKUP_JAR" ]]; then
    echo "No backup was found at:"
    echo "$BACKUP_JAR"
    exit 1
fi

if [[ ! -d "$PZ_APP" ]]; then
    echo "Project Zomboid installation not found."
    exit 1
fi

echo "==> Restoring original projectzomboid.jar"

cp "$BACKUP_JAR" "$PZ_JAR"

echo "==> Clearing LWJGL native cache"

rm -rf "$TMPDIR/lwjgl_$USER" 2>/dev/null || true

echo
echo "Uninstall complete."
