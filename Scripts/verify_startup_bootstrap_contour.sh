#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "[check] scanning startup/bootstrap contour for hard crash primitives"
if rg -n "fatalError|preconditionFailure|try!" \
    Sources/SmetaApp/App \
    Sources/SmetaApp/ViewModels \
    Sources/SmetaApp/Repositories \
    Sources/SmetaApp/Data; then
  echo "FAIL: hard crash primitive found in startup/bootstrap contour"
  exit 1
fi

echo "[check] reloadAll snapshot rollback guard present"
rg -n "let snapshot = StateSnapshot.capture\(from: self\)" Sources/SmetaApp/ViewModels/AppViewModel.swift >/dev/null
rg -n "snapshot\.restore\(to: self\)" Sources/SmetaApp/ViewModels/AppViewModel.swift >/dev/null

echo "[check] launch bootstrap write contour uses explicit transaction"
rg -n "func performLaunchBootstrapWrites" Sources/SmetaApp/Repositories/AppRepository.swift >/dev/null
rg -n "BEGIN IMMEDIATE TRANSACTION;" Sources/SmetaApp/Repositories/AppRepository.swift >/dev/null
rg -n "ROLLBACK;" Sources/SmetaApp/Repositories/AppRepository.swift >/dev/null
rg -n "COMMIT;" Sources/SmetaApp/Repositories/AppRepository.swift >/dev/null

echo "[check] macOS startup integration tests exist"
rg -n "final class StartupPersistentBootstrapTests" Tests/SmetaAppStartupTests/StartupPersistentBootstrapTests.swift >/dev/null
rg -n "performLaunchBootstrapWrites" Tests/SmetaAppStartupTests/StartupPersistentBootstrapTests.swift >/dev/null

if [[ "$(uname -s)" == "Darwin" ]]; then
  echo "[run] swift test --filter StartupPersistentBootstrapTests"
  swift test --filter StartupPersistentBootstrapTests
else
  echo "[warn] macOS-only startup integration tests are not runnable on $(uname -s)"
fi

echo "All checks PASS"
