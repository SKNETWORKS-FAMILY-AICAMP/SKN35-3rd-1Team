#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

# The version used by the app and lockfile. Override deliberately when upgrading.
ARTLOG_FLUTTER_VERSION="${ARTLOG_FLUTTER_VERSION:-3.47.2}"
ARTLOG_FLUTTER_ROOT="${ARTLOG_FLUTTER_ROOT:-$PWD/.vercel/cache/flutter}"
if command -v flutter >/dev/null 2>&1; then
  ARTLOG_FLUTTER_BIN="$(command -v flutter)"
else
  if [ ! -x "$ARTLOG_FLUTTER_ROOT/bin/flutter" ]; then
    git clone --depth 1 --branch "$ARTLOG_FLUTTER_VERSION" https://github.com/flutter/flutter.git "$ARTLOG_FLUTTER_ROOT"
  fi
  ARTLOG_FLUTTER_BIN="$ARTLOG_FLUTTER_ROOT/bin/flutter"
fi
"$ARTLOG_FLUTTER_BIN" --version
"$ARTLOG_FLUTTER_BIN" precache --web
"$ARTLOG_FLUTTER_BIN" pub get --enforce-lockfile
