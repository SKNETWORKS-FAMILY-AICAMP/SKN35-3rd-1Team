#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

# The version used by the app and lockfile. Override deliberately when upgrading.
ARTLOG_FLUTTER_VERSION="${ARTLOG_FLUTTER_VERSION:-3.47.2}"
ARTLOG_FLUTTER_ROOT="${ARTLOG_FLUTTER_ROOT:-$PWD/.vercel/cache/flutter}"
# Always use this project's pinned SDK. A cached launcher may also appear on
# PATH, so command -v alone cannot establish that its repository is intact.
# Vercel omits .git from its build cache, but Flutter needs that metadata.
if [ ! -x "$ARTLOG_FLUTTER_ROOT/bin/flutter" ] || [ ! -e "$ARTLOG_FLUTTER_ROOT/.git" ] ||
  ! git -C "$ARTLOG_FLUTTER_ROOT" cat-file -e 'HEAD^{commit}' 2>/dev/null; then
  mkdir -p "$(dirname "$ARTLOG_FLUTTER_ROOT")"
  ARTLOG_FLUTTER_STAGING="$(mktemp -d "${ARTLOG_FLUTTER_ROOT}.restore.XXXXXX")"
  trap 'rm -rf "$ARTLOG_FLUTTER_STAGING"' EXIT
  git clone --depth 1 --branch "$ARTLOG_FLUTTER_VERSION" https://github.com/flutter/flutter.git "$ARTLOG_FLUTTER_STAGING"
  mkdir -p "$ARTLOG_FLUTTER_ROOT"
  cp -R "$ARTLOG_FLUTTER_STAGING/." "$ARTLOG_FLUTTER_ROOT/"
fi
ARTLOG_FLUTTER_BIN="$ARTLOG_FLUTTER_ROOT/bin/flutter"
"$ARTLOG_FLUTTER_BIN" --version
"$ARTLOG_FLUTTER_BIN" precache --web
"$ARTLOG_FLUTTER_BIN" pub get --enforce-lockfile
