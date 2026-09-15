#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
architecture=${1:-}
case "$(uname -m)" in
  x86_64) native_arch=x64 ;;
  aarch64|arm64) native_arch=arm64 ;;
  *) echo "Unsupported Linux host architecture: $(uname -m)" >&2; exit 1 ;;
esac
architecture=${architecture:-$native_arch}
[[ "$architecture" == "$native_arch" ]] || { echo "Native Linux host required (host=$native_arch target=$architecture)." >&2; exit 1; }
flutter_bin=${FLUTTER_BIN:-}
if [[ -z "$flutter_bin" ]]; then
  if [[ -x "$project_dir/.tooling/flutter/bin/flutter" ]]; then flutter_bin="$project_dir/.tooling/flutter/bin/flutter"; else flutter_bin=$(command -v flutter); fi
fi
[[ -x "$flutter_bin" ]] || { echo "Flutter 3.47.4 is required." >&2; exit 1; }

cd "$project_dir"
"$flutter_bin" pub get
"$flutter_bin" build linux --release
bundle="$project_dir/build/linux/$architecture/release/bundle"
[[ -x "$bundle/mushagaeshi_binary_editor" ]] || { echo "Missing complete Linux bundle: $bundle" >&2; exit 1; }
expected_pattern='x86-64'
[[ "$architecture" == arm64 ]] && expected_pattern='aarch64|ARM aarch64'
while IFS= read -r -d '' binary; do
  file "$binary" | grep -Eqi "ELF 64-bit.*($expected_pattern)" || { echo "Unexpected architecture: $(file "$binary")" >&2; exit 1; }
done < <(find "$bundle" -type f \( -perm -0100 -o -name '*.so*' \) -print0)

dist="$project_dir/dist"
mkdir -p "$dist"
stage=$(mktemp -d "$dist/.linux-package.XXXXXX")
trap 'rm -rf "$stage"' EXIT HUP INT TERM
cp -a "$bundle" "$stage/mushagaeshi_binary_editor"
dart run tool/ci/write_distribution_metadata.dart "$stage/mushagaeshi_binary_editor" "linux-$architecture" "$flutter_bin"
tar -C "$stage" -czf "$dist/musha-bin-edit-linux-$architecture.tar.gz" mushagaeshi_binary_editor
printf 'Linux package ready: %s\n' "$dist/musha-bin-edit-linux-$architecture.tar.gz"
