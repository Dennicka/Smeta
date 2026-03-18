#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "ERROR: macos_package_dmg.sh нужно запускать только на macOS."
  exit 1
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

app_path="${1:-release/Smeta.app}"
dmg_path="${2:-release/Smeta.dmg}"
staging_dir="release/dmg-staging"

if [[ ! -d "$app_path" ]]; then
  echo "ERROR: не найден app bundle: $app_path"
  echo "Сначала соберите приложение: ./Scripts/macos_build.sh"
  exit 1
fi

if ! command -v hdiutil >/dev/null 2>&1; then
  echo "ERROR: hdiutil не найден (ожидается на macOS)."
  exit 1
fi

rm -rf "$staging_dir"
mkdir -p "$staging_dir"
cp -R "$app_path" "$staging_dir/"
ln -s /Applications "$staging_dir/Applications"
rm -f "$dmg_path"

hdiutil create \
  -volname "Smeta" \
  -srcfolder "$staging_dir" \
  -ov \
  -format UDZO \
  "$dmg_path"

echo "==> DMG created: $repo_root/$dmg_path"
