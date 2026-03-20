# D-009 Repository Finalization Evidence

Date (UTC): 2026-03-20

## 1. Exact commands

1. `rg -n "finalizeDocument\(documentId:.*snapshotJSON|func finalizeDocument\(" Sources Scripts Tests`
2. `rg -n "finalizeDocumentWithSnapshot\(" Sources Scripts Tests`
3. `cat > /tmp/sqlite3.modulemap <<'EOM'\nmodule SQLite3 [system] {\n  header \"/usr/include/sqlite3.h\"\n  link \"sqlite3\"\n  export *\n}\nEOM`
4. `swiftc -Xcc -fmodule-map-file=/tmp/sqlite3.modulemap Sources/SmetaApp/Models/Entities.swift Sources/SmetaApp/Data/SQLiteHelpers.swift Sources/SmetaApp/Data/SQLiteDatabase.swift Sources/SmetaApp/Repositories/AppRepository.swift Sources/SmetaApp/Repositories/AppRepository+Stage2.swift Sources/SmetaApp/Services/DocumentSnapshotBuilder.swift Sources/SmetaApp/Services/EstimateLineIdentityValidator.swift Sources/SmetaApp/Services/EstimateCalculator.swift Scripts/verify_finalize_document_with_snapshot.swift -o /tmp/verify_finalize_document_with_snapshot`
5. `/tmp/verify_finalize_document_with_snapshot`

## 2. Full raw outputs

### Command 1 output (grep old finalize path)
```text
Sources/SmetaApp/ViewModels/AppViewModel.swift:1247:    func finalizeDocument(_ doc: BusinessDocument) {
```

### Command 2 output (grep new finalize path)
```text
Tests/SmetaAppStartupTests/DocumentSeriesActivationMigrationDirtyDataTests.swift:32:        try repo.finalizeDocumentWithSnapshot(documentId: draftId, templateId: nil) { _, _ in
Tests/SmetaAppStartupTests/DocumentSeriesActivationMigrationDirtyDataTests.swift:63:        try repo.finalizeDocumentWithSnapshot(documentId: draftId, templateId: nil) { _, _ in
Tests/SmetaAppStartupTests/DocumentSeriesActivationMigrationDirtyDataTests.swift:139:        try repo.finalizeDocumentWithSnapshot(documentId: draftId, templateId: nil) { _, _ in
Tests/SmetaAppStartupTests/DocumentFinalizationContourTests.swift:16:        try repo.finalizeDocumentWithSnapshot(documentId: draftId, templateId: nil) { _, _ in
Tests/SmetaAppStartupTests/DocumentFinalizationContourTests.swift:35:        try repo.finalizeDocumentWithSnapshot(documentId: draftId, templateId: nil) { _, _ in
Tests/SmetaAppStartupTests/DocumentFinalizationContourTests.swift:42:        try repo.finalizeDocumentWithSnapshot(documentId: draftId, templateId: nil) { _, _ in
Tests/SmetaAppStartupTests/DocumentFinalizationContourTests.swift:88:            try repo.finalizeDocumentWithSnapshot(documentId: draftId, templateId: nil) { _, _ in "{\"kind\":\"missing\"}" }
Tests/SmetaAppStartupTests/DocumentFinalizationContourTests.swift:107:        try repo.finalizeDocumentWithSnapshot(documentId: draftId, templateId: nil) { _, _ in "{\"kind\":\"active\"}" }
Tests/SmetaAppStartupTests/DocumentFinalizationContourTests.swift:132:            try repo.finalizeDocumentWithSnapshot(documentId: id, templateId: nil) { _, _ in "{\"kind\":\"types\"}" }
Tests/SmetaAppStartupTests/DocumentFinalizationContourTests.swift:148:        try repo.finalizeDocumentWithSnapshot(documentId: draftId, templateId: nil) { _, _ in "{\"kind\":\"reload\"}" }
Scripts/verify_finalize_document_with_snapshot.swift:75:            try repository.finalizeDocumentWithSnapshot(documentId: draftId, templateId: nil) { finalizedDocument, finalizedLines in
Scripts/verify_finalize_document_with_snapshot.swift:146:                try repository.finalizeDocumentWithSnapshot(documentId: secondDraftId, templateId: nil) { _, _ in
Sources/SmetaApp/Repositories/AppRepository+Stage2.swift:152:    func finalizeDocumentWithSnapshot(
Sources/SmetaApp/ViewModels/AppViewModel.swift:1256:            try repository.finalizeDocumentWithSnapshot(documentId: doc.id, templateId: templateId) { finalizedDoc, finalizedLines in
```

### Command 3 output (create Linux SQLite3 module map)
```text
(no stdout)
```

### Command 4 output (compile repository-level verification)
```text
(no stdout)
```

### Command 5 output (runtime verification script)
```text
[PASS] document status set to finalized
[PASS] document number assigned
[PASS] snapshot stores assigned final number
[PASS] snapshot stores finalized status
[PASS] snapshot stores lines
[PASS] snapshot meta populated
[PASS] snapshot totals populated
[PASS] snapshot builder failure throws and triggers rollback
[PASS] rollback keeps document in draft status
[PASS] rollback prevents snapshot insertion
[PASS] legacy snapshot parse still works
RESULT: PASS
```

## 3. Exit codes

- Command 1: `0`
- Command 2: `0`
- Command 3: `0`
- Command 4: `0`
- Command 5: `0`

## 4. PASS/FAIL per check (repository-level)

1. `document status becomes finalized` — **PASS**
2. `document number assigned` — **PASS**
3. `snapshot stores assigned final number` — **PASS**
4. `snapshot stores finalized status` — **PASS**
5. `snapshot rows are persisted` — **PASS** (`snapshot stores lines` check in runtime output)
6. `rollback works when snapshotBuilder throws` — **PASS**
7. `legacy snapshot parse still works` — **PASS**

Additional flow integrity checks:
- Legacy dangerous repository finalize API `finalizeDocument(documentId:templateId:snapshotJSON:)` is absent from repository paths — **PASS**.
- Active repository finalization usage is `finalizeDocumentWithSnapshot(...)` — **PASS**.

## 5. Root cause and fix for D-009 reproducibility mismatch

- Root cause of non-reproducibility: the previous `swiftc` evidence command omitted repository dependencies required by `AppRepository.swift`.
- Confirmed missing dependency chain in current tree:
  - `AppRepository.swift` references `EstimateLineDraft`.
  - `EstimateLineDraft` is declared in `Sources/SmetaApp/Services/EstimateLineIdentityValidator.swift`.
  - That file also depends on `CalculationRow`, declared in `Sources/SmetaApp/Services/EstimateCalculator.swift`.
- Fix applied in evidence command: added both required source files to the compile command so it is now honestly reproducible on the current repository tree.

## 6. Final verdict

- Repository-level runtime evidence for `finalizeDocumentWithSnapshot(...)` is **reproduced and passing** with a compile command that matches current source dependencies.
- Honest status after rerun on current tree: **D-009 = RESOLVED**.
