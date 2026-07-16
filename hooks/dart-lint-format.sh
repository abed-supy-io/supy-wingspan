#!/usr/bin/env bash
# PostToolUse (Edit|Write) hook: format and analyze the edited Dart file so
# every write lands already-formatted and any analyzer issue surfaces immediately.
#
# Flutter-gated and fail-safe by design — it is a no-op (silent exit 0) unless the
# edited file is a .dart file living inside a package (a pubspec.yaml ancestor) AND
# the Dart SDK is installed. That way it never disrupts a non-Flutter session even
# though the plugin registers it globally.
set -uo pipefail

# Need the Dart toolchain — degrade silently if absent (non-Flutter machine/CI).
command -v dart >/dev/null 2>&1 || exit 0

# Parse file_path from the PostToolUse JSON payload on stdin.
FILE_PATH=$(python3 -c "
import json, sys
try:
    print(json.load(sys.stdin).get('tool_input', {}).get('file_path', ''))
except Exception:
    print('')
" 2>/dev/null)

# Only act on existing .dart files.
[[ -z "$FILE_PATH" || "$FILE_PATH" != *.dart || ! -f "$FILE_PATH" ]] && exit 0

# Flutter gate: the file must sit inside a Dart/Flutter package (pubspec.yaml ancestor).
PACKAGE_DIR="$(dirname "$FILE_PATH")"
while [[ "$PACKAGE_DIR" != "/" && ! -f "$PACKAGE_DIR/pubspec.yaml" ]]; do
  PACKAGE_DIR="$(dirname "$PACKAGE_DIR")"
done
[[ ! -f "$PACKAGE_DIR/pubspec.yaml" ]] && exit 0

# Format in place, quietly — don't spam the session with "Formatted 1 file".
dart format "$FILE_PATH" >/dev/null 2>&1

# Surface analyzer findings only. A non-zero exit lets Claude see and fix the issues.
dart analyze "$FILE_PATH"
