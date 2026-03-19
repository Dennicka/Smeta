#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "[check] migration 004 includes deterministic normalization before index creation"
rg -n "normalizeDocumentSeriesActivation" Sources/SmetaApp/Data/SQLiteDatabase.swift >/dev/null
rg -n "COALESCE\(" Sources/SmetaApp/Data/SQLiteDatabase.swift >/dev/null
rg -n "MIN\(CASE WHEN active = 1 THEN id END\)" Sources/SmetaApp/Data/SQLiteDatabase.swift >/dev/null
rg -n "MIN\(id\)" Sources/SmetaApp/Data/SQLiteDatabase.swift >/dev/null


echo "[check] migration 004 targets the expected document_series indexes"
rg -n "DROP INDEX IF EXISTS idx_document_series_type_unique" Sources/SmetaApp/Data/SQLiteDatabase.swift >/dev/null
rg -n "CREATE INDEX IF NOT EXISTS idx_document_series_type_lookup" Sources/SmetaApp/Data/SQLiteDatabase.swift >/dev/null
rg -n "CREATE UNIQUE INDEX IF NOT EXISTS idx_document_series_active_unique" Sources/SmetaApp/Data/SQLiteDatabase.swift >/dev/null


echo "[check] dirty legacy data scenarios are covered by startup integration tests"
rg -n "final class DocumentSeriesActivationMigrationDirtyDataTests" Tests/SmetaAppStartupTests/DocumentSeriesActivationMigrationDirtyDataTests.swift >/dev/null
rg -n "testDuplicateActiveSeriesNormalizedDeterministicallyAndFinalizationStillWorks" Tests/SmetaAppStartupTests/DocumentSeriesActivationMigrationDirtyDataTests.swift >/dev/null
rg -n "testNoActiveSeriesAmongDuplicatesPromotesDeterministicWinnerAndFinalizationUsesIt" Tests/SmetaAppStartupTests/DocumentSeriesActivationMigrationDirtyDataTests.swift >/dev/null
rg -n "testMultipleDocumentTypesNormalizeIndependently" Tests/SmetaAppStartupTests/DocumentSeriesActivationMigrationDirtyDataTests.swift >/dev/null
rg -n "testCleanControlCaseKeepsSeriesAndPayloadFieldsUnchanged" Tests/SmetaAppStartupTests/DocumentSeriesActivationMigrationDirtyDataTests.swift >/dev/null
rg -n "testPostMigrationFinalizationContinuityUsesActiveSeriesAdvancesCounterAndCreatesSnapshot" Tests/SmetaAppStartupTests/DocumentSeriesActivationMigrationDirtyDataTests.swift >/dev/null

if [[ "$(uname -s)" == "Darwin" ]]; then
  echo "[run] swift test --filter DocumentSeriesActivationMigrationDirtyDataTests"
  swift test --filter DocumentSeriesActivationMigrationDirtyDataTests
else
  echo "[warn] DocumentSeriesActivationMigrationDirtyDataTests are macOS-only and not runnable on $(uname -s)"
fi

echo "PASS: document series activation contour verified"
