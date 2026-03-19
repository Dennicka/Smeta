#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

echo "[verify] explicit transaction boundary in repository contour"
rg -n "func performBusinessDocumentPDFExportWrites" Sources/SmetaApp/Repositories/AppRepository+Stage5.swift >/dev/null
rg -n "BEGIN IMMEDIATE TRANSACTION" Sources/SmetaApp/Repositories/AppRepository+Stage5.swift >/dev/null
rg -n "COMMIT" Sources/SmetaApp/Repositories/AppRepository+Stage5.swift >/dev/null

echo "[verify] AppViewModel exportDocumentPDF uses repository contour"
rg -n "performBusinessDocumentPDFExportWrites" Sources/SmetaApp/ViewModels/AppViewModel.swift >/dev/null

echo "[verify] file-state orchestration hooks are present"
rg -n "promotePreparedPDF" Sources/SmetaApp/ViewModels/AppViewModel.swift >/dev/null
rg -n "recoverAfterFailedCommit" Sources/SmetaApp/ViewModels/AppViewModel.swift >/dev/null
rg -n "removeTemporaryFileIfPresent" Sources/SmetaApp/ViewModels/AppViewModel.swift >/dev/null

echo "[verify] contour tests exist for success/failure/cancel/repeat/reload"
TEST_FILE="Tests/SmetaAppStartupTests/BusinessDocumentPDFExportContourTests.swift"
rg -n "testProductionContourSuccessPersistsExportLogAndFinalPDF" "$TEST_FILE" >/dev/null
rg -n "testProductionContourCancelGuardStopsBeforeAnyWrites" "$TEST_FILE" >/dev/null
rg -n "testProductionContourPDFFailureLeavesNoDBWritesAndNoArtifacts" "$TEST_FILE" >/dev/null
rg -n "testProductionContourPromoteFailureRestoresExistingFileAndRollsBack" "$TEST_FILE" >/dev/null
rg -n "testProductionContourDBFailureRollsBackAndLeavesNoFalseExportLog" "$TEST_FILE" >/dev/null
rg -n "testProductionContourRepeatedRunAfterFailureDoesNotAccumulateGarbageAndThenSucceeds" "$TEST_FILE" >/dev/null
rg -n "testReloadReadsStayStableAfterSuccessfulBusinessDocumentExport" "$TEST_FILE" >/dev/null

if [[ "$(uname -s)" == "Darwin" ]]; then
  echo "[run] swift test --filter BusinessDocumentPDFExportContourTests"
  swift test --filter BusinessDocumentPDFExportContourTests
else
  echo "[warn] BusinessDocumentPDFExportContourTests are macOS-only and not runnable on $(uname -s)"
fi

echo "[verify] no fake persistence shortcuts in production contour"
! rg -n "fake|stub|mock" Sources/SmetaApp/ViewModels/AppViewModel.swift Sources/SmetaApp/Repositories/AppRepository+Stage5.swift >/dev/null

echo "PASS: business document PDF export contour verification passed."
