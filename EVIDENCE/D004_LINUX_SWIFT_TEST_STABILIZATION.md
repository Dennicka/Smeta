# D-004 — Linux `swift test` stabilization (`SQLite3` module error)

Дата: 2026-03-18 (UTC)

## Вердикт
`D-004 = RESOLVED`.

## Root cause (реальная причина)
- В Linux-контейнере отсутствует Swift module `SQLite3` (прямой `import SQLite3` падает).
- До фикса `swift test` пытался собирать `SmetaApp` target, где есть прямой `import SQLite3` в `Sources/SmetaApp/Data/SQLiteDatabase.swift`, что и ломало весь test path.
- При этом сами unit-тесты (`SmetaAppTests`) зависят от `SmetaCore`, а не от `SmetaApp`, поэтому корректный Linux scope — это сборка/тесты core-части без macOS app target.

## Fix
- В `Package.swift` сделано platform-aware wiring:
  - `SmetaCore` + `SmetaAppTests` остаются доступными на всех платформах.
  - `SmetaApp` product/target объявляется только на macOS (`#if os(macOS)`).
- Результат: в Linux `swift test` больше не тянет `SmetaApp`, и путь становится стабильным и воспроизводимым.

## Exact commands + full raw outputs + exit codes

```bash
$ swift package dump-package | python3 -c "import json,sys;d=json.load(sys.stdin);print([t[\"name\"] for t in d[\"targets\"]])"
['SmetaCore', 'SmetaAppTests']
[exit_code]=0

$ swift -e 'import SQLite3; print("ok")'
-e:1:8: error: no such module 'SQLite3'
1 | #sourceLocation(file: "-", line: 1)
2 | import SQLite3; print("ok")
  |        `- error: no such module 'SQLite3'
3 |
[exit_code]=1

$ swift test
[0/1] Planning build
Building for debugging...
[0/2] Write swift-version--3B11F490242A1EB0.txt
Build complete! (0.29s)
Test Suite 'All tests' started at 2026-03-18 19:22:21.418
Test Suite 'debug.xctest' started at 2026-03-18 19:22:21.421
Test Suite 'DocumentDraftBuilderTests' started at 2026-03-18 19:22:21.421
Test Case 'DocumentDraftBuilderTests.testBuildAtaUsesEstimateDataWithoutManualLines' started at 2026-03-18 19:22:21.421
Test Case 'DocumentDraftBuilderTests.testBuildAtaUsesEstimateDataWithoutManualLines' passed (0.005 seconds)
Test Case 'DocumentDraftBuilderTests.testBuildAvtalUsesFinalizedOffertLines' started at 2026-03-18 19:22:21.426
Test Case 'DocumentDraftBuilderTests.testBuildAvtalUsesFinalizedOffertLines' passed (0.0 seconds)
Test Case 'DocumentDraftBuilderTests.testBuildFakturaUsesRealEstimateDataAndTaxMode' started at 2026-03-18 19:22:21.426
Test Case 'DocumentDraftBuilderTests.testBuildFakturaUsesRealEstimateDataAndTaxMode' passed (0.001 seconds)
Test Case 'DocumentDraftBuilderTests.testBuildKreditfakturaUsesFinalizedInvoiceAndNegativeLines' started at 2026-03-18 19:22:21.427
Test Case 'DocumentDraftBuilderTests.testBuildKreditfakturaUsesFinalizedInvoiceAndNegativeLines' passed (0.0 seconds)
Test Case 'DocumentDraftBuilderTests.testBuildOffertMapsEstimateLinesFromRealData' started at 2026-03-18 19:22:21.427
Test Case 'DocumentDraftBuilderTests.testBuildOffertMapsEstimateLinesFromRealData' passed (0.0 seconds)
Test Case 'DocumentDraftBuilderTests.testBuildPaminnelseUsesOutstandingInvoiceBalance' started at 2026-03-18 19:22:21.427
Test Case 'DocumentDraftBuilderTests.testBuildPaminnelseUsesOutstandingInvoiceBalance' passed (0.0 seconds)
Test Case 'DocumentDraftBuilderTests.testNoFakeFallbackWhenDataIsEmpty' started at 2026-03-18 19:22:21.427
Test Case 'DocumentDraftBuilderTests.testNoFakeFallbackWhenDataIsEmpty' passed (0.0 seconds)
Test Case 'DocumentDraftBuilderTests.testTotalsVatAndRotSplitArePreservedInPayload' started at 2026-03-18 19:22:21.428
Test Case 'DocumentDraftBuilderTests.testTotalsVatAndRotSplitArePreservedInPayload' passed (0.0 seconds)
Test Suite 'DocumentDraftBuilderTests' passed at 2026-03-18 19:22:21.428
         Executed 8 tests, with 0 failures (0 unexpected) in 0.007 (0.007) seconds
Test Suite 'DocumentSnapshotBuilderTests' started at 2026-03-18 19:22:21.428
Test Case 'DocumentSnapshotBuilderTests.testBuildFullSnapshotForOffertLikeDocument' started at 2026-03-18 19:22:21.428
Test Case 'DocumentSnapshotBuilderTests.testBuildFullSnapshotForOffertLikeDocument' passed (0.0 seconds)
Test Case 'DocumentSnapshotBuilderTests.testFinalizedSnapshotUsesAssignedFinalNumberNotDraftNumber' started at 2026-03-18 19:22:21.428
Test Case 'DocumentSnapshotBuilderTests.testFinalizedSnapshotUsesAssignedFinalNumberNotDraftNumber' passed (0.0 seconds)
Test Case 'DocumentSnapshotBuilderTests.testSnapshotFreezesLinesTotalsAndTax' started at 2026-03-18 19:22:21.428
Test Case 'DocumentSnapshotBuilderTests.testSnapshotFreezesLinesTotalsAndTax' passed (0.0 seconds)
Test Case 'DocumentSnapshotBuilderTests.testSnapshotSerializationAndParseDistinguishesFormats' started at 2026-03-18 19:22:21.428
Test Case 'DocumentSnapshotBuilderTests.testSnapshotSerializationAndParseDistinguishesFormats' passed (0.002 seconds)
Test Suite 'DocumentSnapshotBuilderTests' passed at 2026-03-18 19:22:21.430
         Executed 4 tests, with 0 failures (0 unexpected) in 0.002 (0.002) seconds
Test Suite 'Stage5ServiceTests' started at 2026-03-18 19:22:21.430
Test Case 'Stage5ServiceTests.testClientImportReportSeparatesCreateUpdateSkipInvalid' started at 2026-03-18 19:22:21.430
Test Case 'Stage5ServiceTests.testClientImportReportSeparatesCreateUpdateSkipInvalid' passed (0.001 seconds)
Test Case 'Stage5ServiceTests.testClientImportValidationDetectsMissingName' started at 2026-03-18 19:22:21.432
Test Case 'Stage5ServiceTests.testClientImportValidationDetectsMissingName' passed (0.0 seconds)
Test Case 'Stage5ServiceTests.testManifestHasSchema' started at 2026-03-18 19:22:21.432
Test Case 'Stage5ServiceTests.testManifestHasSchema' passed (0.002 seconds)
Test Case 'Stage5ServiceTests.testReceivablesBuckets' started at 2026-03-18 19:22:21.434
Test Case 'Stage5ServiceTests.testReceivablesBuckets' passed (0.001 seconds)
Test Suite 'Stage5ServiceTests' passed at 2026-03-18 19:22:21.435
         Executed 4 tests, with 0 failures (0 unexpected) in 0.005 (0.005) seconds
Test Suite 'debug.xctest' passed at 2026-03-18 19:22:21.435
         Executed 16 tests, with 0 failures (0 unexpected) in 0.014 (0.014) seconds
Test Suite 'All tests' passed at 2026-03-18 19:22:21.435
         Executed 16 tests, with 0 failures (0 unexpected) in 0.014 (0.014) seconds
◇ Test run started.
↳ Testing Library Version: 6.1.3 (1d1f7e489c9c606)
↳ Target Platform: x86_64-unknown-linux-gnu
✔ Test run with 0 tests passed after 0.001 seconds.
[exit_code]=0
```

## Stable PASS command for current Linux container
```bash
swift test
```

Команда детерминированно проходит в текущем контейнере и не падает по `no such module 'SQLite3'` в целевом Linux test path.
