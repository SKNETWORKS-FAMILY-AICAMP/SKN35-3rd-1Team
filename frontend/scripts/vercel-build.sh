#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
ARTLOG_FLUTTER_ROOT="${ARTLOG_FLUTTER_ROOT:-$PWD/.vercel/cache/flutter}"
ARTLOG_FLUTTER_BIN="$ARTLOG_FLUTTER_ROOT/bin/flutter"
node scripts/write-build-defines.mjs
"$ARTLOG_FLUTTER_BIN" build web --release --dart-define-from-file=.dart-defines.vercel.json
