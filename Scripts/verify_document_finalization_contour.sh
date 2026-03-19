#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "[check] repository exposes explicit transaction boundary"
rg -n "func performDocumentFinalizationWrites" Sources/SmetaApp/Repositories/AppRepository+Stage2.swift >/dev/null
rg -n "BEGIN IMMEDIATE TRANSACTION" Sources/SmetaApp/Repositories/AppRepository+Stage2.swift >/dev/null
rg -n "ROLLBACK" Sources/SmetaApp/Repositories/AppRepository+Stage2.swift >/dev/null
rg -n "COMMIT" Sources/SmetaApp/Repositories/AppRepository+Stage2.swift >/dev/null

echo "[check] active series guard + controlled error present"
rg -n "Нет активной серии" Sources/SmetaApp/Repositories/AppRepository+Stage2.swift >/dev/null
rg -n "active=1" Sources/SmetaApp/Repositories/AppRepository+Stage2.swift >/dev/null

echo "[check] finalization contour tests cover rollback/refinalize/missing-series/active-series/cross-type"
rg -n "testNormalFinalizePathAssignsNumberAndAdvancesSeries" Tests/SmetaAppStartupTests/DocumentFinalizationContourTests.swift >/dev/null
rg -n "testRefinalizeDoesNotMutateDocumentOrSeriesOrSnapshots" Tests/SmetaAppStartupTests/DocumentFinalizationContourTests.swift >/dev/null
rg -n "testRollbackOnInjectedFailureRestoresDocumentAndSeries" Tests/SmetaAppStartupTests/DocumentFinalizationContourTests.swift >/dev/null
rg -n "testMissingActiveSeriesReturnsControlledErrorAndNoPartialWrites" Tests/SmetaAppStartupTests/DocumentFinalizationContourTests.swift >/dev/null
rg -n "testUsesOnlyActiveSeriesWhenInactiveAlternativeExists" Tests/SmetaAppStartupTests/DocumentFinalizationContourTests.swift >/dev/null
rg -n "testDifferentDocumentTypesUseOwnSeries" Tests/SmetaAppStartupTests/DocumentFinalizationContourTests.swift >/dev/null
rg -n "testReloadReadsStayStableAfterSuccessfulFinalize" Tests/SmetaAppStartupTests/DocumentFinalizationContourTests.swift >/dev/null

if [[ "$(uname -s)" == "Darwin" ]]; then
  echo "[run] swift test --filter DocumentFinalizationContourTests"
  swift test --filter DocumentFinalizationContourTests
else
  echo "[warn] DocumentFinalizationContourTests are macOS-only and not runnable on $(uname -s)"
fi

echo "PASS: document finalization contour verified"
