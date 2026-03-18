# D-009 Repository Finalization Evidence

Date (UTC): 2026-03-18

## 1. Exact commands

1. `rg -n "finalizeDocument\(documentId:.*snapshotJSON|func finalizeDocument\(" Sources Scripts Tests`
2. `rg -n "finalizeDocumentWithSnapshot\(" Sources Scripts Tests`
3. `swiftc Sources/SmetaApp/Models/Entities.swift Sources/SmetaApp/Data/SQLiteHelpers.swift Sources/SmetaApp/Data/SQLiteDatabase.swift Sources/SmetaApp/Repositories/AppRepository.swift Sources/SmetaApp/Repositories/AppRepository+Stage2.swift Sources/SmetaApp/Services/DocumentSnapshotBuilder.swift Scripts/verify_finalize_document_with_snapshot.swift -o /tmp/verify_finalize_document_with_snapshot`
4. `swift test --filter DocumentSnapshotBuilderTests`
5. `swiftc Sources/SmetaCore/Models/Entities.swift Sources/SmetaCore/Services/DocumentSnapshotBuilder.swift Scripts/verify_document_snapshot_builder.swift -o /tmp/verify_document_snapshot_builder_3b && /tmp/verify_document_snapshot_builder_3b`

## 2. Full raw outputs

### Command 1+2 output (grep old/new finalize paths)
```text
--- grep old finalizeDocument path ---
Sources/SmetaApp/ViewModels/AppViewModel.swift:355:    func finalizeDocument(_ doc: BusinessDocument) {
EXIT_CODE:0
--- grep new finalizeDocumentWithSnapshot path ---
Scripts/verify_finalize_document_with_snapshot.swift:75:            try repository.finalizeDocumentWithSnapshot(documentId: draftId, templateId: nil) { finalizedDocument, finalizedLines in
Scripts/verify_finalize_document_with_snapshot.swift:146:                try repository.finalizeDocumentWithSnapshot(documentId: secondDraftId, templateId: nil) { _, _ in
Sources/SmetaApp/Repositories/AppRepository+Stage2.swift:82:    func finalizeDocumentWithSnapshot(
Sources/SmetaApp/ViewModels/AppViewModel.swift:360:            try repository.finalizeDocumentWithSnapshot(documentId: doc.id, templateId: templateId) { finalizedDoc, finalizedLines in
EXIT_CODE:0
```

### Command 3 output (repository-level verification script compile/run)
```text
Sources/SmetaApp/Data/SQLiteHelpers.swift:2:8: error: no such module 'SQLite3'
1 | import Foundation
2 | import SQLite3
  |        `- error: no such module 'SQLite3'
3 | 
4 | let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
EXIT_CODE:1
```

### Command 4 output (`swift test --filter DocumentSnapshotBuilderTests`)
```text
Building for debugging...
[0/17] Write sources
[3/17] Write swift-version--3B11F490242A1EB0.txt
error: emit-module command failed with exit code 1 (use -v to see invocation)
[5/40] Emitting module SmetaApp
/workspace/Smeta/Sources/SmetaApp/Data/SQLiteDatabase.swift:2:8: error: no such module 'SQLite3'
  1 | import Foundation
  2 | import SQLite3
    |        `- error: no such module 'SQLite3'
  3 | 
  4 | enum DatabaseError: Error {
[6/49] Compiling SmetaApp MaterialsView.swift
/workspace/Smeta/Sources/SmetaApp/Data/SQLiteDatabase.swift:2:8: error: no such module 'SQLite3'
  1 | import Foundation
  2 | import SQLite3
    |        `- error: no such module 'SQLite3'
  3 | 
  4 | enum DatabaseError: Error {
[7/49] Compiling SmetaApp ProjectsView.swift
/workspace/Smeta/Sources/SmetaApp/Data/SQLiteDatabase.swift:2:8: error: no such module 'SQLite3'
  1 | import Foundation
  2 | import SQLite3
    |        `- error: no such module 'SQLite3'
  3 | 
  4 | enum DatabaseError: Error {
[8/49] Compiling SmetaApp RoomsView.swift
/workspace/Smeta/Sources/SmetaApp/Data/SQLiteDatabase.swift:2:8: error: no such module 'SQLite3'
  1 | import Foundation
  2 | import SQLite3
    |        `- error: no such module 'SQLite3'
  3 | 
  4 | enum DatabaseError: Error {
[9/49] Compiling SmetaApp RootView.swift
/workspace/Smeta/Sources/SmetaApp/Data/SQLiteDatabase.swift:2:8: error: no such module 'SQLite3'
  1 | import Foundation
  2 | import SQLite3
    |        `- error: no such module 'SQLite3'
  3 | 
  4 | enum DatabaseError: Error {
[10/49] Compiling SmetaApp SettingsView.swift
/workspace/Smeta/Sources/SmetaApp/Data/SQLiteDatabase.swift:2:8: error: no such module 'SQLite3'
  1 | import Foundation
  2 | import SQLite3
    |        `- error: no such module 'SQLite3'
  3 | 
  4 | enum DatabaseError: Error {
[11/49] Compiling SmetaApp Stage2Views.swift
/workspace/Smeta/Sources/SmetaApp/Data/SQLiteDatabase.swift:2:8: error: no such module 'SQLite3'
  1 | import Foundation
  2 | import SQLite3
    |        `- error: no such module 'SQLite3'
  3 | 
  4 | enum DatabaseError: Error {
[12/49] Compiling SmetaApp Stage5OperationsView.swift
/workspace/Smeta/Sources/SmetaApp/Data/SQLiteDatabase.swift:2:8: error: no such module 'SQLite3'
  1 | import Foundation
  2 | import SQLite3
    |        `- error: no such module 'SQLite3'
  3 | 
  4 | enum DatabaseError: Error {
[13/49] Compiling SmetaApp WizardView.swift
/workspace/Smeta/Sources/SmetaApp/Data/SQLiteDatabase.swift:2:8: error: no such module 'SQLite3'
  1 | import Foundation
  2 | import SQLite3
    |        `- error: no such module 'SQLite3'
  3 | 
  4 | enum DatabaseError: Error {
[14/49] Compiling SmetaApp WorksView.swift
/workspace/Smeta/Sources/SmetaApp/Data/SQLiteDatabase.swift:2:8: error: no such module 'SQLite3'
  1 | import Foundation
  2 | import SQLite3
    |        `- error: no such module 'SQLite3'
  3 | 
  4 | enum DatabaseError: Error {
[15/49] Compiling SmetaApp DocumentSnapshotBuilder.swift
/workspace/Smeta/Sources/SmetaApp/Data/SQLiteDatabase.swift:2:8: error: no such module 'SQLite3'
  1 | import Foundation
  2 | import SQLite3
    |        `- error: no such module 'SQLite3'
  3 | 
  4 | enum DatabaseError: Error {
[16/49] Compiling SmetaApp EstimateCalculator.swift
/workspace/Smeta/Sources/SmetaApp/Data/SQLiteDatabase.swift:2:8: error: no such module 'SQLite3'
  1 | import Foundation
  2 | import SQLite3
    |        `- error: no such module 'SQLite3'
  3 | 
  4 | enum DatabaseError: Error {
[17/49] Compiling SmetaApp PDFDocumentService.swift
/workspace/Smeta/Sources/SmetaApp/Data/SQLiteDatabase.swift:2:8: error: no such module 'SQLite3'
  1 | import Foundation
  2 | import SQLite3
    |        `- error: no such module 'SQLite3'
  3 | 
  4 | enum DatabaseError: Error {
[18/49] Compiling SmetaApp Stage5Service.swift
/workspace/Smeta/Sources/SmetaApp/Data/SQLiteDatabase.swift:2:8: error: no such module 'SQLite3'
  1 | import Foundation
  2 | import SQLite3
    |        `- error: no such module 'SQLite3'
  3 | 
  4 | enum DatabaseError: Error {
[19/49] Compiling SmetaApp AppViewModel.swift
/workspace/Smeta/Sources/SmetaApp/Data/SQLiteDatabase.swift:2:8: error: no such module 'SQLite3'
  1 | import Foundation
  2 | import SQLite3
    |        `- error: no such module 'SQLite3'
  3 | 
  4 | enum DatabaseError: Error {
[20/49] Compiling SmetaApp CalculationView.swift
/workspace/Smeta/Sources/SmetaApp/Data/SQLiteDatabase.swift:2:8: error: no such module 'SQLite3'
  1 | import Foundation
  2 | import SQLite3
    |        `- error: no such module 'SQLite3'
  3 | 
  4 | enum DatabaseError: Error {
[21/49] Compiling SmetaApp ClientsView.swift
/workspace/Smeta/Sources/SmetaApp/Data/SQLiteDatabase.swift:2:8: error: no such module 'SQLite3'
  1 | import Foundation
  2 | import SQLite3
    |        `- error: no such module 'SQLite3'
  3 | 
  4 | enum DatabaseError: Error {
[22/49] Compiling SmetaApp DashboardView.swift
/workspace/Smeta/Sources/SmetaApp/Data/SQLiteDatabase.swift:2:8: error: no such module 'SQLite3'
  1 | import Foundation
  2 | import SQLite3
    |        `- error: no such module 'SQLite3'
  3 | 
  4 | enum DatabaseError: Error {
[23/49] Compiling SmetaApp DocumentsView.swift
/workspace/Smeta/Sources/SmetaApp/Data/SQLiteDatabase.swift:2:8: error: no such module 'SQLite3'
  1 | import Foundation
  2 | import SQLite3
    |        `- error: no such module 'SQLite3'
  3 | 
  4 | enum DatabaseError: Error {
[24/49] Emitting module SmetaCore
[27/49] Compiling SmetaCore DocumentSnapshotBuilder.swift
[28/50] Compiling SmetaCore Stage5Service.swift
[29/51] Wrapping AST for SmetaCore for debugging
[31/54] Compiling SmetaAppTests DocumentSnapshotBuilderTests.swift
[32/55] Compiling SmetaAppTests Stage5ServiceTests.swift
[33/55] Compiling SmetaApp SmetaApp.swift
/workspace/Smeta/Sources/SmetaApp/Data/SQLiteDatabase.swift:2:8: error: no such module 'SQLite3'
  1 | import Foundation
  2 | import SQLite3
    |        `- error: no such module 'SQLite3'
  3 | 
  4 | enum DatabaseError: Error {
[34/55] Compiling SmetaApp SQLiteDatabase.swift
/workspace/Smeta/Sources/SmetaApp/Data/SQLiteDatabase.swift:2:8: error: no such module 'SQLite3'
  1 | import Foundation
  2 | import SQLite3
    |        `- error: no such module 'SQLite3'
  3 | 
  4 | enum DatabaseError: Error {
[35/55] Compiling SmetaApp SQLiteHelpers.swift
/workspace/Smeta/Sources/SmetaApp/Data/SQLiteDatabase.swift:2:8: error: no such module 'SQLite3'
  1 | import Foundation
  2 | import SQLite3
    |        `- error: no such module 'SQLite3'
  3 | 
  4 | enum DatabaseError: Error {
[36/55] Compiling SmetaApp Entities.swift
/workspace/Smeta/Sources/SmetaApp/Data/SQLiteDatabase.swift:2:8: error: no such module 'SQLite3'
  1 | import Foundation
  2 | import SQLite3
    |        `- error: no such module 'SQLite3'
  3 | 
  4 | enum DatabaseError: Error {
[37/55] Compiling SmetaApp AppRepository+Stage2.swift
/workspace/Smeta/Sources/SmetaApp/Data/SQLiteDatabase.swift:2:8: error: no such module 'SQLite3'
  1 | import Foundation
  2 | import SQLite3
    |        `- error: no such module 'SQLite3'
  3 | 
  4 | enum DatabaseError: Error {
[38/55] Compiling SmetaApp AppRepository+Stage5.swift
/workspace/Smeta/Sources/SmetaApp/Data/SQLiteDatabase.swift:2:8: error: no such module 'SQLite3'
  1 | import Foundation
  2 | import SQLite3
    |        `- error: no such module 'SQLite3'
  3 | 
  4 | enum DatabaseError: Error {
[39/55] Compiling SmetaApp AppRepository.swift
/workspace/Smeta/Sources/SmetaApp/Data/SQLiteDatabase.swift:2:8: error: no such module 'SQLite3'
  1 | import Foundation
  2 | import SQLite3
    |        `- error: no such module 'SQLite3'
  3 | 
  4 | enum DatabaseError: Error {
[40/55] Compiling SmetaApp BackupService.swift
/workspace/Smeta/Sources/SmetaApp/Data/SQLiteDatabase.swift:2:8: error: no such module 'SQLite3'
  1 | import Foundation
  2 | import SQLite3
    |        `- error: no such module 'SQLite3'
  3 | 
  4 | enum DatabaseError: Error {
[41/55] Compiling SmetaApp DocumentDraftBuilder.swift
/workspace/Smeta/Sources/SmetaApp/Data/SQLiteDatabase.swift:2:8: error: no such module 'SQLite3'
  1 | import Foundation
  2 | import SQLite3
    |        `- error: no such module 'SQLite3'
  3 | 
  4 | enum DatabaseError: Error {
[42/55] Emitting module SmetaAppTests
error: fatalError
EXIT_CODE:1
```

### Command 5 output (builder-level verification script)
```text
[PASS] schema version is full snapshot v2
[PASS] document meta included
[PASS] snapshot stores assigned final number
[PASS] snapshot final number is not empty
[PASS] snapshot stores finalized status
[PASS] company display data included
[PASS] client display data included
[PASS] project/object context included
[PASS] frozen lines included
[PASS] line totals frozen
[PASS] totals/tax values included
[PASS] references included
[PASS] new snapshot recognized as full format
[PASS] legacy snapshot still readable
[PASS] serialized JSON contains lines block
[PASS] serialized JSON contains financials block
[PASS] serialized JSON contains references block
RESULT: PASS
EXIT_CODE:0
```

## 3. Exit codes
- Command 1 (old path grep): `0`
- Command 2 (new path grep): `0`
- Command 3 (repository-level script compile/run): `1`
- Command 4 (`swift test --filter DocumentSnapshotBuilderTests`): `1`
- Command 5 (builder-level script): `0`

## 4. PASS checks
- Old dangerous `finalizeDocument(documentId:templateId:snapshotJSON:)` method removed from repository code path.
- Active runtime flow uses `finalizeDocumentWithSnapshot(...)` from `AppViewModel`.
- Builder-level snapshot verification passes (final number/status + legacy/full parse).

## 5. FAIL checks
- Repository-level runtime verification script cannot be executed in current Linux environment because `SQLite3` Swift module is unavailable.
- Full `swift test` remains blocked by same `SQLite3` issue (D-004).

## 6. Was old finalizeDocument path used?
- No. The old repository method `finalizeDocument(documentId:templateId:snapshotJSON:)` has been removed.

## 7. Grep results for old path
- `rg -n "finalizeDocument\(documentId:.*snapshotJSON|func finalizeDocument\(" Sources Scripts Tests`
- Result: only `AppViewModel.finalizeDocument(_ doc: BusinessDocument)` (UI handler) remains; no old repository finalize API found.

## 8. Final verdict
- **not ready for merge** as full D-009 closeout evidence, because repository-level runtime proof for `finalizeDocumentWithSnapshot(...)` is not yet executable in this environment.
- Current honest state: **D-009 = PARTIAL** until repository-level script can be run in environment with working `SQLite3` Swift module.
