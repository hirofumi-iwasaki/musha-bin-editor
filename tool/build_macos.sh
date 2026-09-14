#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
set -eu
project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$project_dir"
if [ -x .tooling/flutter/bin/flutter ]; then
  flutter_bin="$project_dir/.tooling/flutter/bin/flutter"
else
  flutter_bin=$(command -v flutter) || { echo 'Flutter 3.47.4 is required to build this app.' >&2; exit 1; }
fi
"$flutter_bin" build macos --release
app_name='Mushaaeshi Binary Editor.app'
built_app="$project_dir/build/macos/Build/Products/Release/$app_name"
mkdir -p "$project_dir/dist"
package_dir=$(mktemp -d "$project_dir/dist/.package.XXXXXX")
trap 'rm -rf "$package_dir"' EXIT HUP INT TERM
/usr/bin/ditto "$built_app" "$package_dir/$app_name"
/usr/bin/codesign --verify --deep --strict "$package_dir/$app_name"
# Only replace this script's generated application bundle.
rm -rf "$project_dir/dist/$app_name"
mv "$package_dir/$app_name" "$project_dir/dist/$app_name"
printf 'Application ready: %s\n' "$project_dir/dist/$app_name"
