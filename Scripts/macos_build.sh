#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "ERROR: macos_build.sh нужно запускать только на macOS."
  exit 1
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

build_config="${BUILD_CONFIG:-release}"
if [[ "$build_config" != "debug" && "$build_config" != "release" ]]; then
  echo "ERROR: BUILD_CONFIG должен быть debug или release (сейчас: $build_config)."
  exit 1
fi

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "ERROR: xcodebuild не найден. Установите Xcode и Command Line Tools."
  exit 1
fi

if ! command -v swift >/dev/null 2>&1; then
  echo "ERROR: swift не найден. Установите Xcode и Command Line Tools."
  exit 1
fi

if ! xcode-select -p >/dev/null 2>&1; then
  echo "ERROR: Command Line Tools не активированы (xcode-select -p)."
  echo "Подсказка: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
  exit 1
fi

mkdir -p release/build-logs

build_args=(build)
if [[ "$build_config" == "release" ]]; then
  build_args+=(--configuration release)
fi

echo "==> Swift build ($build_config)"
swift "${build_args[@]}" 2>&1 | tee "release/build-logs/swift-build-${build_config}.log"

binary_path=".build/${build_config}/SmetaApp"
if [[ ! -f "$binary_path" ]]; then
  echo "ERROR: бинарник не найден: $binary_path"
  exit 1
fi

app_dir="release/Smeta.app"
contents_dir="$app_dir/Contents"
macos_dir="$contents_dir/MacOS"
resources_dir="$contents_dir/Resources"

echo "==> Bundle layout"
rm -rf "$app_dir"
mkdir -p "$macos_dir" "$resources_dir"
cp "$binary_path" "$macos_dir/SmetaApp"
chmod +x "$macos_dir/SmetaApp"

cat > "$contents_dir/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>
  <string>Smeta</string>
  <key>CFBundleDisplayName</key>
  <string>Smeta</string>
  <key>CFBundleIdentifier</key>
  <string>com.smeta.app</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleExecutable</key>
  <string>SmetaApp</string>
  <key>LSMinimumSystemVersion</key>
  <string>12.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

echo "==> Build completed"
echo "App bundle: $repo_root/$app_dir"
echo "Build log:  $repo_root/release/build-logs/swift-build-${build_config}.log"
