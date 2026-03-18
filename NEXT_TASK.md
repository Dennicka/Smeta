# NEXT_TASK

## Следующая инженерная задача (одна)
D-010 — выполнить настоящий macOS runtime E2E для AppKit PDF export по business documents (Avtal/Faktura/Kreditfaktura/ÄTA/Påminnelse) после закрытия D-010a compile-blocker.

## Scope
- Выполнить прогон именно на macOS runtime (не code-audit и не Linux substitute).
- Для каждого из 5 document types отдельно подтвердить:
  - открывается export flow;
  - сохраняется PDF;
  - файл реально создаётся и не пустой;
  - нет падения;
  - path идёт через зафиксированный export pipeline, без fake/demo fallback.
- Собрать и приложить отдельный evidence pack: exact commands/steps, raw logs, список PDF-файлов, размеры файлов, скриншоты/честное runtime-подтверждение, type-by-type PASS/FAIL.

## Preconditions
- D-010a (compile-time blocker в `PDFDocumentService.swift`) уже устранён и подтверждён evidence-командой `swiftc -typecheck ...` с `EXIT_CODE:0`.

## Out of scope
- `.app/.dmg` packaging и notarization.
- Clean install/restart lifecycle.
- Новые фичи вне export path.
- Рефакторинг бизнес-логики, не необходимый для прохождения D-010 acceptance.

## Acceptance criteria
1. Для каждого из 5 типов есть отдельный macOS runtime result.
2. В evidence присутствуют реальные PDF-файлы и их размеры.
3. Есть честный type-by-type verdict (`PASS/FAIL`) без сокрытия failure point.
4. После прогона синхронизированы документы: `DEFECT_BACKLOG.md`, `CURRENT_STATE.md`, `NEXT_TASK.md`.
5. Если все 5 проходят — `D-010 = RESOLVED`; иначе — `D-010 = PARTIAL` с явной разбивкой по failing subtype/scenario.
