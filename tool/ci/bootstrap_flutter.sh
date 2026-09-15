#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Use the official source tag so Arm64 hosts bootstrap matching SDK artifacts.
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <x64|arm64> <flutter-sdk-directory>" >&2
  exit 64
fi

expected_arch="$1"
flutter_root="$2"
case "$(uname -m)" in
  x86_64) actual_arch=x64 ;;
  aarch64|arm64) actual_arch=arm64 ;;
  *) echo "Unsupported native architecture: $(uname -m)" >&2; exit 1 ;;
esac
[[ "$actual_arch" == "$expected_arch" ]] || {
  echo "Runner is $actual_arch; expected native $expected_arch." >&2
  exit 1
}

git clone --depth 1 --branch 3.47.4 https://github.com/flutter/flutter.git "$flutter_root"
expected_revision=9584c6713b324636289d067944a46fd6b49df14b
actual_revision="$(git -C "$flutter_root" rev-parse HEAD)"
[[ "$actual_revision" == "$expected_revision" ]] || {
  echo "Flutter revision $actual_revision does not match $expected_revision." >&2
  exit 1
}

"$flutter_root/bin/flutter" --version
dart_binary="$flutter_root/bin/cache/dart-sdk/bin/dart"
[[ -x "$dart_binary" ]] || { echo "Native Dart SDK was not bootstrapped." >&2; exit 1; }
case "$expected_arch" in
  x64) file "$dart_binary" | grep -Eqi 'x86[-_ ]64|x86_64' ;;
  arm64) file "$dart_binary" | grep -Eqi 'aarch64|arm64' ;;
esac || { echo "Dart binary architecture does not match $expected_arch." >&2; exit 1; }

echo "$flutter_root/bin" >> "${GITHUB_PATH:?GITHUB_PATH is required in CI}"
