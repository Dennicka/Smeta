#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

OS_NAME="$(uname -s)"
if [[ "${OS_NAME}" != "Darwin" ]]; then
  echo "BLOCKED: macOS app build contour can only be verified on Darwin (current: ${OS_NAME})" >&2
  exit 2
fi

CANONICAL_BUILD_SCRIPT="${ROOT_DIR}/Scripts/macos_build.sh"
if [[ ! -x "${CANONICAL_BUILD_SCRIPT}" ]]; then
  echo "FAIL: canonical build script is missing or not executable: ${CANONICAL_BUILD_SCRIPT}" >&2
  exit 1
fi

echo "[cmd] BUILD_CONFIG=release ${CANONICAL_BUILD_SCRIPT}"
BUILD_CONFIG=release "${CANONICAL_BUILD_SCRIPT}"

APP_BUNDLE="${ROOT_DIR}/release/Smeta.app"
APP_EXECUTABLE="${APP_BUNDLE}/Contents/MacOS/SmetaApp"
APP_INFO_PLIST="${APP_BUNDLE}/Contents/Info.plist"

[[ -d "${APP_BUNDLE}" ]] || { echo "FAIL: app bundle not found: ${APP_BUNDLE}" >&2; exit 1; }
[[ -f "${APP_EXECUTABLE}" ]] || { echo "FAIL: app executable not found: ${APP_EXECUTABLE}" >&2; exit 1; }
[[ -x "${APP_EXECUTABLE}" ]] || { echo "FAIL: app executable is not executable: ${APP_EXECUTABLE}" >&2; exit 1; }
[[ -f "${APP_INFO_PLIST}" ]] || { echo "FAIL: Info.plist not found: ${APP_INFO_PLIST}" >&2; exit 1; }

echo "PASS: macOS app build contour verified"
echo "PASS: artifact exists -> ${APP_BUNDLE}"
echo "PASS: artifact exists -> ${APP_EXECUTABLE}"
echo "PASS: artifact exists -> ${APP_INFO_PLIST}"
