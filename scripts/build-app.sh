#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
binary_dir="$(swift build -c release --show-bin-path)"
app_dir="$PWD/dist/PalmGuard.app"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$binary_dir/PalmGuard" "$app_dir/Contents/MacOS/PalmGuard"
cp Resources/Info.plist "$app_dir/Contents/Info.plist"
codesign --force --sign "${PALMGUARD_SIGNING_IDENTITY:--}" "$app_dir"
codesign --verify --strict "$app_dir"
ditto -c -k --sequesterRsrc --keepParent "$app_dir" "$PWD/dist/PalmGuard.zip"
echo "$app_dir"
