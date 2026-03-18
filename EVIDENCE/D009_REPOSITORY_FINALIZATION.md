# D-009 Repository Finalization Evidence

Date (UTC): 2026-03-18

## 1. Exact commands

1. `rg -n "finalizeDocument\(documentId:.*snapshotJSON|func finalizeDocument\(" Sources Scripts Tests`
2. `rg -n "finalizeDocumentWithSnapshot\(" Sources Scripts Tests`
3. `cat > /tmp/sqlite3.modulemap <<'EOM'\nmodule SQLite3 [system] {\n  header \"/usr/include/sqlite3.h\"\n  link \"sqlite3\"\n  export *\n}\nEOM`
4. `swiftc -Xcc -fmodule-map-file=/tmp/sqlite3.modulemap Sources/SmetaApp/Models/Entities.swift Sources/SmetaApp/Data/SQLiteHelpers.swift Sources/SmetaApp/Data/SQLiteDatabase.swift Sources/SmetaApp/Repositories/AppRepository.swift Sources/SmetaApp/Repositories/AppRepository+Stage2.swift Sources/SmetaApp/Services/DocumentSnapshotBuilder.swift Scripts/verify_finalize_document_with_snapshot.swift -o /tmp/verify_finalize_document_with_snapshot`
5. `/tmp/verify_finalize_document_with_snapshot`

## 2. Full raw outputs

### Command 1 output (grep old finalize path)
```text
Sources/SmetaApp/ViewModels/AppViewModel.swift:355:    func finalizeDocument(_ doc: BusinessDocument) {
```

### Command 2 output (grep new finalize path)
```text
Scripts/verify_finalize_document_with_snapshot.swift:75:            try repository.finalizeDocumentWithSnapshot(documentId: draftId, templateId: nil) { finalizedDocument, finalizedLines in
Scripts/verify_finalize_document_with_snapshot.swift:146:                try repository.finalizeDocumentWithSnapshot(documentId: secondDraftId, templateId: nil) { _, _ in
Sources/SmetaApp/ViewModels/AppViewModel.swift:360:            try repository.finalizeDocumentWithSnapshot(documentId: doc.id, templateId: templateId) { finalizedDoc, finalizedLines in
Sources/SmetaApp/Repositories/AppRepository+Stage2.swift:82:    func finalizeDocumentWithSnapshot(
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

## 5. Final verdict

- Repository-level runtime evidence for `finalizeDocumentWithSnapshot(...)` is now **real and passing** in a valid Linux environment with working Swift `SQLite3` module map.
- Honest status after this evidence: **D-009 = RESOLVED**.
- For D-009 scope, this is **ready for merge**.
