#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$project_dir"
./tool/build_macos.sh
app="$project_dir/dist/Mushagaeshi Binary Editor.app"
[[ -d "$app" ]] || { echo "Missing macOS application bundle." >&2; exit 1; }
file "$app/Contents/MacOS/Mushagaeshi Binary Editor" | grep -Eqi 'arm64' || { echo 'The macOS application is not Arm64.' >&2; exit 1; }
flutter_bin=${FLUTTER_BIN:-$project_dir/.tooling/flutter/bin/flutter}
stage=$(mktemp -d "$project_dir/dist/.macos-package.XXXXXX")
trap 'rm -rf "$stage"' EXIT HUP INT TERM
mkdir -p "$stage/Mushagaeshi Binary Editor"
/usr/bin/ditto "$app" "$stage/Mushagaeshi Binary Editor/Mushagaeshi Binary Editor.app"
dart run tool/ci/write_distribution_metadata.dart "$stage/Mushagaeshi Binary Editor" macos-arm64 "$flutter_bin"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$stage/Mushagaeshi Binary Editor" "$project_dir/dist/musha-bin-edit-macos.zip"
printf 'macOS package ready: %s\n' "$project_dir/dist/musha-bin-edit-macos.zip"
