#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "[check] explicit transactional boundary for Offert persistent writes"
rg -n "func performOffertGenerationWrites" Sources/SmetaApp/Repositories/AppRepository.swift >/dev/null
rg -n "BEGIN IMMEDIATE TRANSACTION" Sources/SmetaApp/Repositories/AppRepository.swift >/dev/null
rg -n "ROLLBACK" Sources/SmetaApp/Repositories/AppRepository.swift >/dev/null
rg -n "COMMIT" Sources/SmetaApp/Repositories/AppRepository.swift >/dev/null

echo "[check] save contour uses repository transaction and file promotion before commit"
rg -n "performOffertGenerationWrites" Sources/SmetaApp/ViewModels/AppViewModel.swift >/dev/null
rg -n "offertPDFGenerator\\.generateOffertSwedish" Sources/SmetaApp/ViewModels/AppViewModel.swift >/dev/null
rg -n "pdfService\\.generateBusinessDocumentPDF" Sources/SmetaApp/ViewModels/AppViewModel.swift >/dev/null
rg -n "promotePreparedPDF" Sources/SmetaApp/ViewModels/AppViewModel.swift >/dev/null
rg -n "recoverAfterFailedCommit" Sources/SmetaApp/ViewModels/AppViewModel.swift >/dev/null
rg -n "removeTemporaryFileIfPresent" Sources/SmetaApp/ViewModels/AppViewModel.swift >/dev/null
if rg -n "estimateId:\\s*0" Sources/SmetaApp/ViewModels/AppViewModel.swift >/dev/null; then
  echo "[fail] fake estimateId=0 is still used in production contour"
  exit 1
fi

echo "[check] contour tests cover success/failure/cancel/repeat/reload"
rg -n "testProductionContourSuccessPersistsEstimateLinesGeneratedDocumentAndFinalPDF" Tests/SmetaAppStartupTests/OffertGenerationContourTests.swift >/dev/null
rg -n "testProductionContourDBFailureRollsBackDatabaseAndLeavesNoFinalArtifacts" Tests/SmetaAppStartupTests/OffertGenerationContourTests.swift >/dev/null
rg -n "testProductionContourPDFFailureBeforeWritesLeavesNoDBStateAndNoArtifacts" Tests/SmetaAppStartupTests/OffertGenerationContourTests.swift >/dev/null
rg -n "testProductionContourPromoteFailureRestoresExistingFileAndRollsBackDB" Tests/SmetaAppStartupTests/OffertGenerationContourTests.swift >/dev/null
rg -n "testProductionContourRepeatedRunAfterFailureDoesNotAccumulateGarbageAndThenSucceeds" Tests/SmetaAppStartupTests/OffertGenerationContourTests.swift >/dev/null
rg -n "testCancelGuardPathStopsContourBeforeAnyWrites" Tests/SmetaAppStartupTests/OffertGenerationContourTests.swift >/dev/null
rg -n "offert-pending|\\.backup-" Tests/SmetaAppStartupTests/OffertGenerationContourTests.swift >/dev/null

if [[ "$(uname -s)" == "Darwin" ]]; then
  echo "[run] swift test --filter OffertGenerationContourTests"
  swift test --filter OffertGenerationContourTests
else
  echo "[warn] OffertGenerationContourTests are macOS-only and not runnable on $(uname -s)"
fi

echo "PASS: offert generation contour verified"
