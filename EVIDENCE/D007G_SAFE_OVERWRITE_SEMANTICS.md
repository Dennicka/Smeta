# D-007g — safe overwrite semantics для PDF export/generation без потери pre-existing user file

Дата: 2026-03-18 (UTC)
Среда: Linux container (без macOS AppKit runtime)

## Historical status note (2026-03-18)
- Этот документ фиксирует **исторический переход** от destructive overwrite к backup/restore.
- Он **не должен читаться** как свежий runtime-proof всей текущей цепочки после orchestrator-рефакторинга.
- Актуальный throwing recovery + post-commit semantics подтверждаются отдельными evidence-паками: `EVIDENCE/D007G2_HARD_RECOVERY_SEMANTICS.md` и `EVIDENCE/D007G3_TEMP_LEAK_AND_POST_COMMIT_SEMANTICS.md`.

## Update note (D-007g2 sync)
- D-007g safe-overwrite contract сохранён, но после D-007g2 recovery path больше не best-effort: он реализован через throwing `PDFFileStateOrchestrator` и отдельно подтверждён scenario-based пакетом `EVIDENCE/D007G2_HARD_RECOVERY_SEMANTICS.md`.
- Этот файл фиксирует именно переход от destructive overwrite к backup/restore, а D-007g2 добавляет жёсткий error signaling при неполном restore.

## Цель
Устранить destructive delete-before-replace и обеспечить безопасное поведение при overwrite существующего `finalURL` в:
- `saveEstimateAndGenerateDocument()`
- `exportDocumentPDF(_:)`

## 1) Exact commands / raw outputs / exit codes

### Command 1 — code-path proof: Offert flow
```bash
nl -ba Sources/SmetaApp/ViewModels/AppViewModel.swift | sed -n '228,305p'
```
Exit code: `0`
Raw output (ключевое):
```text
236  let tempURL = temporaryPDFURL(near: finalURL, ...)
242  BEGIN IMMEDIATE TRANSACTION
259  backupURL = try backupExistingFileIfNeeded(at: finalURL)
260  try promotePreparedPDF(from: tempURL, to: finalURL)
262  COMMIT
...
247  recoverFileStateAfterFailedCommit(finalURL: finalURL, backupURL: backupURL, didMoveToFinal: didMoveToFinal)
```

### Command 2 — code-path proof: business export flow + helpers
```bash
nl -ba Sources/SmetaApp/ViewModels/AppViewModel.swift | sed -n '545,625p'
```
Exit code: `0`
Raw output (ключевое):
```text
557  let tempURL = temporaryPDFURL(near: finalURL, ...)
563  BEGIN IMMEDIATE TRANSACTION
572  backupURL = try backupExistingFileIfNeeded(at: finalURL)
573  try promotePreparedPDF(from: tempURL, to: finalURL)
575  COMMIT
...
587  temporaryPDFURL(near: finalURL, ...)
593  backupExistingFileIfNeeded(at: destinationURL)
607  recoverFileStateAfterFailedCommit(finalURL:backupURL:didMoveToFinal:)
```

### Command 3 — runtime regression check (Linux graph)
```bash
swift test
```
Exit code: `0`
Raw output (tail):
```text
Test Suite 'All tests' passed at 2026-03-18 20:32:11.500
    Executed 16 tests, with 0 failures (0 unexpected) in 0.362 (0.362) seconds
```

### Command 4 — graph scope proof (честное ограничение)
```bash
sed -n '1,90p' Package.swift
```
Exit code: `0`
Raw output (ключевое):
```text
var products: [Product] = [ .library(name: "SmetaCore", ...) ]
#if os(macOS)
products.insert(.executable(name: "SmetaApp", targets: ["SmetaApp"]), at: 0)
#endif
```

## 2) Что изменено в flow

### A) Same-directory temp / same-volume semantics
- Temp PDF теперь создаётся рядом с `finalURL` (`temporaryPDFURL(near:finalURL, ...)`), а не в global `temporaryDirectory`.
- Это убирает cross-volume риск и делает move/rename сценарий корректным для target path директории.

### B) Safe overwrite без destructive delete-before-replace
- Удалён старый `replacePDFAtomically` с delete+move.
- Введена схема backup/restore:
  1. если `finalURL` существует — файл сначала переносится в backup рядом (`backupExistingFileIfNeeded`);
  2. затем новый PDF переносится на `finalURL` (`promotePreparedPDF`);
  3. после успешного `COMMIT` backup удаляется.

### C) Failure recovery
- На fail до commit: `ROLLBACK` + `recoverFileStateAfterFailedCommit(...)`.
- Recovery делает:
  - удаление нового final файла (если уже moved);
  - восстановление backup в исходный `finalURL` (если backup был).

## 3) Требуемые сценарии (contract table)

| Scenario | Path state | Failure point | Expected result by code-path |
|---|---|---|---|
| S1 | `finalURL` не существовал | fail до move | rollback, temp cleanup, `finalURL` отсутствует |
| S2 | `finalURL` не существовал | fail после move / до commit | rollback, новый `finalURL` удаляется |
| S3 | `finalURL` уже существовал | fail до move (после backup) | rollback, backup возвращается в `finalURL` |
| S4 | `finalURL` уже существовал | fail после move / до commit | rollback, новый `finalURL` удаляется, backup восстанавливается |
| S5 | `finalURL` уже существовал | success | commit, backup удаляется, новый файл на `finalURL` |

## 4) Acceptance mapping D-007g

- **AC1 (старый файл не теряется при fail):** покрыто backup/restore ветками.
- **AC2 (same-directory/same-volume temp):** покрыто `temporaryPDFURL(near:)`.
- **AC3 (нет delete-before-safe-replace):** старый delete-before-move удалён, заменён на backup-first.
- **AC4 (exact commands/raw/exit codes):** см. секцию 1.
- **AC5 (разбор required paths):** см. contract table в секции 3.

## 5) Честная классификация подтверждений

- **Runtime confirmed (Linux):** `swift test`.
- **Code-path confirmed:** safe overwrite / recovery ветки в `AppViewModel` для обоих flow.
- **Blocked_env:** реальная AppKit UI проверка на macOS (NSSavePanel runtime interactions).

## Verdict
- D-007g code-level fix: **выполнен**.
- D-007 остаётся **PARTIAL** до macOS runtime UX/e2e verification.
