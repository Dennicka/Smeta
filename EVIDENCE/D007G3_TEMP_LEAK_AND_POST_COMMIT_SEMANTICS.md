# D-007g3 — close temp-leak + post-commit false-failure semantics

Дата: 2026-03-18 (UTC)
Среда: Linux container (без macOS AppKit runtime)

## 1) Exact commands / raw outputs / exit codes

### Command 1 — scenario-based semantics verifier
```bash
swiftc Sources/SmetaApp/Services/PDFFileStateOrchestrator.swift Scripts/verify_d007g3_semantics.swift -o /tmp/verify_d007g3 && /tmp/verify_d007g3
```
Exit code: `0`
Raw output:
```text
D007G3_RESULTS
C1 PASS
C2 PASS
C3 PASS
C4 PASS
TOTAL=4
```

### Command 2 — regression check
```bash
swift test
```
Exit code: `0`
Raw output (tail):
```text
Test Suite 'All tests' passed at 2026-03-18 21:11:02.369
    Executed 16 tests, with 0 failures (0 unexpected) in 0.036 (0.036) seconds
```

### Command 3 — AppViewModel code-path proof (Offert flow)
```bash
nl -ba Sources/SmetaApp/ViewModels/AppViewModel.swift | sed -n '230,330p'
```
Exit code: `0`

### Command 4 — AppViewModel code-path proof (export flow)
```bash
nl -ba Sources/SmetaApp/ViewModels/AppViewModel.swift | sed -n '560,670p'
```
Exit code: `0`

## 2) Covered scenarios (required)

| Case | What is validated | Result |
|---|---|---|
| C1 | PDF generation fails before transaction; temp cleanup still executed | PASS |
| C2 | BEGIN transaction fails; temp cleanup still executed | PASS |
| C3 | Commit succeeds but refresh fails; operation remains success with warning (no false failure) | PASS |
| C4 | Export succeeds with post-commit issue path (backup cleanup warning branch) | PASS |

## 3) What changed in code

- `saveEstimateAndGenerateDocument()` и `exportDocumentPDF(_:)` теперь удаляют temp PDF не только в transaction-error ветке, но и в pre-transaction fail path (generation/BEGIN fail), через unified cleanup in outer catch.
- Recovery (`ROLLBACK` + file restore) выполняется только если transaction реально началась (`beganTransaction`), чтобы pre-BEGIN fail path не пропускал cleanup.
- Post-commit `reloadAll()` вынесен в warning-path: ошибка refresh больше не превращает успешно завершённую операцию в общий failure.
- Post-commit backup cleanup failures остаются не-silent и показываются пользователю как warning/info.

## 4) Runtime vs code-path vs blocked_env

- **Runtime confirmed (Linux):** `verify_d007g3_semantics.swift` (C1..C4) + `swift test`.
- **Code-path confirmed:** integration in `AppViewModel` around commit/reload/warning separation.
- **Blocked_env:** macOS AppKit UI runtime verification (NSSavePanel + visual UX).

## Verdict

- D-007g3 code-level fix: **выполнен**.
- D-007 overall: **PARTIAL** до macOS runtime UX verification.
