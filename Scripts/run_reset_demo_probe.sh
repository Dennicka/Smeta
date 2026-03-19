#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODULE_MAP="${ROOT_DIR}/Scripts/sqlite3.modulemap"
BIN_PATH="${ROOT_DIR}/.tmp_reset_demo_probe"

OS_NAME="$(uname -s)"
if [[ "${OS_NAME}" == "Darwin" ]]; then
  SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"
  SQLITE3_HEADER="${SDK_PATH}/usr/include/sqlite3.h"
elif [[ "${OS_NAME}" == "Linux" ]]; then
  SQLITE3_HEADER="/usr/include/sqlite3.h"
else
  echo "Unsupported OS for reset probe runner: ${OS_NAME}" >&2
  exit 1
fi

if [[ ! -f "${SQLITE3_HEADER}" ]]; then
  echo "sqlite3 header not found at ${SQLITE3_HEADER}" >&2
  exit 1
fi

cat > "${MODULE_MAP}" <<'EOF'
module SQLite3 [system] {
  header "SQLITE3_HEADER_PLACEHOLDER"
  link "sqlite3"
  export *
}
EOF
sed -i.bak "s|SQLITE3_HEADER_PLACEHOLDER|${SQLITE3_HEADER}|g" "${MODULE_MAP}"
rm -f "${MODULE_MAP}.bak"

swiftc \
  -Xcc -fmodule-map-file="${MODULE_MAP}" \
  "${ROOT_DIR}/Sources/SmetaApp/Data/SQLiteHelpers.swift" \
  "${ROOT_DIR}/Sources/SmetaApp/Data/SQLiteDatabase.swift" \
  "${ROOT_DIR}/Sources/SmetaApp/Models/Entities.swift" \
  "${ROOT_DIR}/Sources/SmetaApp/Repositories/AppRepository.swift" \
  "${ROOT_DIR}/Sources/SmetaApp/Repositories/AppRepository+Stage2.swift" \
  "${ROOT_DIR}/Scripts/reset_demo_probe.swift" \
  -o "${BIN_PATH}"

"${BIN_PATH}"

rm -f "${BIN_PATH}" "${MODULE_MAP}"
