# D-007g2 — hard recovery semantics без silent restore failure

Дата: 2026-03-18 (UTC)
Среда: Linux container (без macOS AppKit runtime)

## Цель
Убрать best-effort `try?` в критичном file-recovery path и гарантировать явный сигнал при неполном восстановлении состояния PDF.

## 1) Exact commands / raw outputs / exit codes

### Command 1 — scenario-based file recovery verification (реальные файловые сценарии)
```bash
swiftc Sources/SmetaApp/Services/PDFFileStateOrchestrator.swift Scripts/verify_d007g2_file_recovery.swift -o /tmp/verify_d007g2 && /tmp/verify_d007g2
```
Exit code: `0`
Raw output:
```text
D007G2_FILE_RECOVERY_RESULTS
S1 PASS
S2 PASS
S3 PASS
S4 PASS
S5 PASS
S6 PASS (expected failure: Не удалось полностью восстановить состояние PDF. final=/tmp/.../missing-parent/s6-final.pdf, backup=/tmp/.../s6-backup.pdf, проблемы: не удалось восстановить backup ...)
TOTAL=6
```

### Command 2 — Linux regression check
```bash
swift test
```
Exit code: `0`
Raw output (tail):
```text
Test Suite 'All tests' passed at 2026-03-18 20:51:32.985
    Executed 16 tests, with 0 failures (0 unexpected) in 0.365 (0.365) seconds
```

### Command 3 — code-path proof (AppViewModel orchestration)
```bash
nl -ba Sources/SmetaApp/ViewModels/AppViewModel.swift | sed -n '228,320p'
```
Exit code: `0`

### Command 4 — code-path proof (export flow + helper)
```bash
nl -ba Sources/SmetaApp/ViewModels/AppViewModel.swift | sed -n '548,625p'
```
Exit code: `0`

## 2) Что изменено

- Критичный file-state orchestration вынесен в отдельный helper `PDFFileStateOrchestrator` (без AppKit), чтобы гонять реальные файловые сценарии в Linux.
- Recovery path теперь **throwing**, без `try?`-swallow:
  - `recoverAfterFailedCommit(...)` возвращает success только при полной нормализации состояния;
  - при неполной нормализации бросает `PDFFileStateError.incompleteRecovery(...)` с деталями и backup path.
- Backup cleanup после commit также **throwing** (`cleanupBackupAfterCommit`), не silent.
- В `AppViewModel` recovery errors агрегируются и поднимаются в явную ошибку с пользовательским текстом о неполном восстановлении.
- Для post-commit backup cleanup failure добавлен явный warning/info path пользователю (не silent).

## 3) Scenario table (обязательное покрытие)

| Scenario | Existing file | Failure point | Expected behavior | Verified by script |
|---|---:|---|---|---|
| S1 | No | fail before move | final path absent, temp cleaned | PASS |
| S2 | No | fail after move / before commit | new final removed | PASS |
| S3 | Yes | fail before move (after backup) | backup restored to final | PASS |
| S4 | Yes | fail after move / before commit | new final removed + backup restored | PASS |
| S5 | Yes | success path | final=new, backup cleanup done | PASS |
| S6 | Yes | forced recovery failure | explicit thrown error with backup/final context | PASS (expected failure observed) |

## 4) Честная классификация подтверждений

- **Runtime confirmed (Linux):** файловые сценарии recovery helper (S1..S6) + `swift test` Linux graph.
- **Code-path confirmed:** интеграция helper в `AppViewModel` для `saveEstimateAndGenerateDocument` и `exportDocumentPDF`.
- **Blocked_env:** macOS AppKit runtime UX validation (NSSavePanel + визуальные сообщения).

## Verdict

- D-007g2 code-level fix: **выполнен**.
- D-007 остаётся **PARTIAL** до macOS runtime UX/e2e verification.
