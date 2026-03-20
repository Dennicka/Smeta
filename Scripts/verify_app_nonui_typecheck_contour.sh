#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

if ! command -v swiftc >/dev/null 2>&1; then
  echo "FAIL: swiftc is required but not found in PATH" >&2
  exit 1
fi

TMP_DIR="$(mktemp -d "${ROOT_DIR}/.tmp_app_nonui_typecheck.XXXXXX")"
trap 'rm -rf "${TMP_DIR}"' EXIT

SQLITE_MODULE_MAP="${TMP_DIR}/sqlite3.modulemap"
CORE_MODULE_DIR="${TMP_DIR}/core"
mkdir -p "${CORE_MODULE_DIR}"

OS_NAME="$(uname -s)"
if [[ "${OS_NAME}" == "Darwin" ]]; then
  SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"
  SQLITE3_HEADER="${SDK_PATH}/usr/include/sqlite3.h"
elif [[ "${OS_NAME}" == "Linux" ]]; then
  SQLITE3_HEADER="/usr/include/sqlite3.h"
else
  echo "FAIL: unsupported OS ${OS_NAME}" >&2
  exit 1
fi

if [[ ! -f "${SQLITE3_HEADER}" ]]; then
  echo "FAIL: sqlite3 header not found at ${SQLITE3_HEADER}" >&2
  exit 1
fi

cat > "${SQLITE_MODULE_MAP}" <<MAP
module SQLite3 [system] {
  header "${SQLITE3_HEADER}"
  link "sqlite3"
  export *
}
MAP

CORE_SOURCES=(
  "${ROOT_DIR}/Sources/SmetaCore/Models/Entities.swift"
  "${ROOT_DIR}/Sources/SmetaCore/Services/ProjectSpeedSyncResolver.swift"
  "${ROOT_DIR}/Sources/SmetaCore/Services/DocumentSnapshotBuilder.swift"
  "${ROOT_DIR}/Sources/SmetaCore/Services/ExportArtifactCoordinator.swift"
  "${ROOT_DIR}/Sources/SmetaCore/Services/DocumentDraftBuilder.swift"
  "${ROOT_DIR}/Sources/SmetaCore/Services/Stage5Service.swift"
  "${ROOT_DIR}/Sources/SmetaCore/Services/DocumentExportPipeline.swift"
  "${ROOT_DIR}/Sources/SmetaCore/Validation/RoomCreateInputValidator.swift"
)

APP_CONTOUR_SOURCES=(
  "${ROOT_DIR}/Sources/SmetaApp/App/SmokeRuntimeConfig.swift"
  "${ROOT_DIR}/Sources/SmetaApp/App/StartupBootstrap.swift"
  "${ROOT_DIR}/Sources/SmetaApp/App/RuntimeSmokeProbe.swift"
  "${ROOT_DIR}/Sources/SmetaApp/ViewModels/AppViewModel.swift"
)

while IFS= read -r file; do APP_CONTOUR_SOURCES+=("${ROOT_DIR}/${file}"); done < <(rg --files Sources/SmetaApp/Models Sources/SmetaApp/Data Sources/SmetaApp/Repositories Sources/SmetaApp/Services | sort)

echo "[step] building SmetaCore module for app contour import"
CORE_BUILD_CMD=(
  swiftc
  -parse-as-library
  -emit-module
  -emit-module-path "${CORE_MODULE_DIR}/SmetaCore.swiftmodule"
  -module-name SmetaCore
  -Xcc "-fmodule-map-file=${SQLITE_MODULE_MAP}"
)
CORE_BUILD_CMD+=("${CORE_SOURCES[@]}")
printf '[cmd]'; printf ' %q' "${CORE_BUILD_CMD[@]}"; echo
"${CORE_BUILD_CMD[@]}"

echo "[step] typechecking SmetaApp non-UI contour"
TYPECHECK_CMD=(
  swiftc
  -typecheck
  -module-name SmetaAppNonUIContour
  -I "${CORE_MODULE_DIR}"
  -Xcc "-fmodule-map-file=${SQLITE_MODULE_MAP}"
)
TYPECHECK_CMD+=("${APP_CONTOUR_SOURCES[@]}")
printf '[cmd]'; printf ' %q' "${TYPECHECK_CMD[@]}"; echo
"${TYPECHECK_CMD[@]}"

echo "PASS: non-UI app contour typecheck completed"
