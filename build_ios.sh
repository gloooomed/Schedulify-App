#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# build_ios.sh — Schedulify iOS build script
#
# Reads dart_defines.json and passes all key-value pairs to Flutter via
# --dart-define-from-file, mirroring the Android build approach.
# Never reads from .env.
#
# Usage:
#   ./build_ios.sh                          # run debug on booted simulator
#   ./build_ios.sh run   [device-id]        # flutter run on specific device
#   ./build_ios.sh debug [device-id]        # alias for run
#   ./build_ios.sh build                    # flutter build ipa (release)
#   ./build_ios.sh build --no-codesign      # build ipa without signing
#
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFINES_FILE="$SCRIPT_DIR/dart_defines.json"
DEFINES_FLAG="--dart-define-from-file=$DEFINES_FILE"

# ── Validate dart_defines.json ───────────────────────────────────────────────
if [[ ! -f "$DEFINES_FILE" ]]; then
  echo ""
  echo "  ❌  dart_defines.json not found at: $DEFINES_FILE"
  echo ""
  echo "  Create it from the template:"
  echo "    cp .env.example dart_defines.json"
  echo "  Then fill in your real values."
  echo ""
  exit 1
fi

# ── Parse command ────────────────────────────────────────────────────────────
COMMAND="${1:-run}"
shift || true          # remove $1 so remaining args are forwarded

echo ""
echo "  ▶  Schedulify iOS — $COMMAND"
echo "  ▶  Using defines: $DEFINES_FILE"
echo ""

# ── Dispatch ─────────────────────────────────────────────────────────────────
case "$COMMAND" in

  run|debug)
    # Forward any extra args (e.g. device id passed as "-d <id>")
    # Default: let flutter pick the booted simulator
    flutter run \
      "$DEFINES_FLAG" \
      "$@"
    ;;

  build)
    # Release IPA — pass remaining args (e.g. --no-codesign)
    flutter build ipa \
      "$DEFINES_FLAG" \
      "$@"
    echo ""
    echo "  ✅  IPA built → build/ios/ipa/"
    ;;

  *)
    echo "  Unknown command: $COMMAND"
    echo "  Valid commands: run | debug | build"
    exit 1
    ;;
esac
