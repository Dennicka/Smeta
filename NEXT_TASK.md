# NEXT_TASK

## Следующая инженерная задача (одна)
Defect Fix 6 — углубить D-010 от service-level до macOS runtime evidence по AppKit PDF export.

## Scope
- Провести macOS runtime e2e для export PDF (NSSavePanel + фактическая запись файлов) по Avtal/Faktura/Kreditfaktura/ÄTA/Påminnelse.
- Для каждого типа приложить runtime evidence: скриншоты/видео, сохранённые PDF, журнал шагов и итог PASS/FAIL.
- Обновить D-010 статус честно: оставить `PARTIAL`, если хотя бы часть типов не подтверждена в macOS runtime.

## Out of scope
- Packaging/signing/release задачи macOS (`D-001..D-003`).
- D-011 CSV upsert redesign.
- D-012/D-013 архитектурные переработки вне export/runtime контура.

## Acceptance criteria
1. Для всех 5 типов D-010 есть macOS runtime evidence фактического экспорта PDF (не только code/service level).
2. Evidence pack содержит exact commands/шаги, raw outputs, пути к файлам, exit codes и визуальные артефакты.
3. `CURRENT_STATE.md` и `DEFECT_BACKLOG.md` синхронизированы со статусом D-010 без завышения.

## Evidence requirements
- Exact commands + full raw outputs + exit codes.
- Обновлённые `CURRENT_STATE.md`, `DEFECT_BACKLOG.md`, `NEXT_TASK.md`.
- Отдельный evidence-файл под runtime D-010 с трассировкой тип документа → macOS proof.
